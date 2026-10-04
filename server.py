#!/usr/bin/env python3
"""ADRFBOT — servidor de validacion de keys (replica de server.php).

Endpoint:  POST /server.php   form: key=<TOKEN>
Responde JSON cifrado (base64+XOR, password VnBjMnTlL):
  {"status": bool, "response": str, "token": bot_token,
   "chatid": owner_id, "keyid": short_id, "reseller": str}

PROTECCION (reforzada en v2):
  - rate limit por IP (anti fuerza bruta) + limite global de peticiones/IP.
  - bloqueo manual de IPs (tabla blocked_ips, persistente).
  - verificacion del ip:puerto guardado dentro de la key.
  - registro de la IP del VPS que uso la key (IP real, NO X-Forwarded-For).
  - key CloudRun guardada encriptada en la DB.
  - limite de tamaño de cuerpo (anti slowloris / memoria).
  - timeout de lectura por conexion (anti slowloris).
  - semaforo de concurrencia (anti agotamiento de CPU/threads).
  - validacion estricta de entradas y longitud de key.
  - cabeceras de seguridad + version de server ofuscada.
  - logs sanitizados (sin inyeccion de CRLF).
"""

import collections
import datetime
import json
import os
import re
import sys
import threading
import time
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from adrfbot import config as cfgmod
from adrfbot import crypto, msgs
from adrfbot.config import load_config, my_server, _detect_ip, save_config
from adrfbot.database import Database


# ----------------------------------------------------------- constantes
MAX_BODY = 64 * 1024            # max 64KB de cuerpo (evita memoria/DoS)
REQUEST_TIMEOUT = 10            # segundos de inactividad por conexion
MAX_KEY_LEN = 512              # longitud maxima aceptable de 'key'
MAX_REQ_LINE = 8192            # linea de peticion maximo
GLOBAL_RPM = 120               # peticiones/min por IP (todas las POST)
CONCURRENCY = 64               # validaciones concurrentes maximo

_CRLF = re.compile(r"[\r\n]")


def _san(s) -> str:
    """Quita CRLF para evitar inyeccion en los logs."""
    return _CRLF.sub(" ", str(s))[:200]


def tg_send(token, chat_id, text):
    """Envia un mensaje via la API de Telegram (sin dependencias)."""
    url = f"https://api.telegram.org/bot{token}/sendMessage"
    data = urllib.parse.urlencode(
        {"chat_id": chat_id, "text": text, "parse_mode": "HTML"}
    ).encode()
    req = urllib.request.Request(url, data=data)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status == 200
    except Exception:
        return False


class Guard:
    """Rate limit por IP: N fallos en 60s -> bloqueo temporal.
    Ademas limita el total de peticiones por minuto (anti-flood)."""

    def __init__(self, max_fail=5, window=60, block_minutes=30, rpm=GLOBAL_RPM):
        self.max_fail = max_fail
        self.window = window
        self.block_minutes = block_minutes
        self.rpm = rpm
        self.fails = {}
        self.banned = {}
        self.hits = {}
        self.lock = threading.Lock()

    def banned_until(self, ip):
        with self.lock:
            until = self.banned.get(ip, 0)
            if until and time.time() >= until:
                self.banned.pop(ip, None)
                return 0
            return until

    def fail(self, ip):
        """Registra un intento fallido. True si ahora queda bloqueada."""
        with self.lock:
            now = time.time()
            q = self.fails.setdefault(ip, collections.deque())
            while q and now - q[0] > self.window:
                q.popleft()
            q.append(now)
            if len(q) >= self.max_fail:
                self.banned[ip] = now + self.block_minutes * 60
                self.fails.pop(ip, None)
                return True
            return False

    def ok(self, ip):
        with self.lock:
            self.fails.pop(ip, None)

    def rate_ok(self, ip):
        """True si la IP esta dentro del limite global de peticiones/min."""
        with self.lock:
            now = time.time()
            q = self.hits.setdefault(ip, collections.deque())
            cutoff = now - 60
            while q and q[0] < cutoff:
                q.popleft()
            if len(q) >= self.rpm:
                return False
            q.append(now)
            return True


class Validator:
    def __init__(self, cfg):
        self.cfg = cfg
        self.db = Database(cfg.get("db_path", "adrfbot.db"))
        self.password = cfg.get("password", "VnBjMnTlL")
        self.bot_token = cfg.get("bot_token", "")
        self.owner = int(cfg.get("owner_id", 0))
        self.expire_hours = int(cfg.get("key_expire_hours", 4))
        self.notify = cfg.get("notify", "both")
        self.verify_server = bool(cfg.get("verify_server", True))
        self.single_use = bool(cfg.get("single_use", False))
        self.my_server = my_server(cfg)
        self.guard = Guard(
            max_fail=int(cfg.get("max_fail_attempts", 5)),
            block_minutes=int(cfg.get("block_minutes", 30)),
            rpm=int(cfg.get("max_requests_per_min", GLOBAL_RPM)),
        )
        self._cfg_mtime = self._config_mtime()

    def _config_mtime(self):
        try:
            return os.path.getmtime(cfgmod.config_path())
        except Exception:
            return 0

    def reload(self):
        """Recarga config.json si cambio (owner dinamico, token, etc)."""
        mtime = self._config_mtime()
        if mtime != self._cfg_mtime:
            self._cfg_mtime = mtime
            try:
                cfg = load_config()
                self.cfg = cfg
                self.password = cfg.get("password", "VnBjMnTlL")
                self.bot_token = cfg.get("bot_token", "")
                self.owner = int(cfg.get("owner_id", 0))
                self.expire_hours = int(cfg.get("key_expire_hours", 4))
                self.notify = cfg.get("notify", "both")
                self.verify_server = bool(cfg.get("verify_server", True))
                self.single_use = bool(cfg.get("single_use", False))
                self.my_server = my_server(cfg)
                self.guard.rpm = int(cfg.get("max_requests_per_min", GLOBAL_RPM))
                print(f"[ADRFBOT] config recargada (owner {self.owner})")
            except Exception as e:
                print(f"[ADRFBOT] error recargando config: {e}")

    # ------------------------------------------------------------- validar
    def validate(self, token, ip=""):
        """Devuelve (payload, notify_info). notify_info None si no valida."""
        self.reload()
        if not token or len(token) > MAX_KEY_LEN:
            return {"status": False, "response": "KEY INVALIDA"}, None
        row = self.db.get_key_by_token(token)
        if not row:
            return {"status": False, "response": "KEY INVALIDA"}, None
        if row["used"] and self.single_use:
            return {"status": False, "response": "KEY YA USADA"}, None
        try:
            created = datetime.datetime.strptime(
                row["created_at"], "%Y-%m-%d %H:%M:%S"
            )
            limite = datetime.datetime.now() - datetime.timedelta(
                hours=self.expire_hours
            )
            if created < limite:
                return {"status": False, "response": "KEY EXPIRADA"}, None
        except ValueError:
            pass

        if self.verify_server and row["server"] and row["server"] != self.my_server:
            return {"status": False, "response": "KEY DE OTRO SERVIDOR"}, None

        user = self.db.get_user(row["user_id"])
        reseller = ""
        if user:
            reseller = user["reseller"] or self.cfg.get("default_reseller", "")
        payload = {
            "status": True,
            "response": "OK",
            "token": self.bot_token,
            "chatid": row["user_id"],
            "keyid": row["short_id"],
            "reseller": reseller,
        }

        self.db.mark_used(row["id"], ip)
        return payload, (row["user_id"], row["short_id"], row["cloudrun"])

    def notify_used(self, user_id, short_id, cloudrun):
        """Notificacion 'key usada' (CloudRun) — solo a quien genero la key."""
        text = msgs.used_msg(short_id, cloudrun)
        targets = []
        user = self.db.get_user(user_id)
        if self.notify in ("user", "both") and user:
            targets.append(user["user_id"])
        if self.notify in ("owner", "both") and self.owner:
            targets.append(self.owner)
        for chat in dict.fromkeys(targets):
            tg_send(self.bot_token, chat, text)


class Handler(BaseHTTPRequestHandler):
    validator = None
    # Ocultar/ofuscar la version del server
    server_version = "ADRFBOT"
    sys_version = ""

    def version_string(self):
        return self.server_version

    # --------------------------------------------------------- red/timeout
    def setup(self):
        super().setup()
        try:
            self.connection.settimeout(REQUEST_TIMEOUT)
        except Exception:
            pass

    def _client_ip(self):
        # SOLO la IP real de la conexion: X-Forwarded-For puede falsificarse
        return self.client_address[0]

    def handle_one_request(self):
        # cap de la linea de peticion para evitar lineas enormes (DoS)
        try:
            line = self.rfile.readline(MAX_REQ_LINE + 1)
        except Exception:
            self.close_connection = True
            return
        if not line or len(line) > MAX_REQ_LINE:
            self.close_connection = True
            return
        self.raw_requestline = line
        if not self.parse_request():
            return
        mname = 'do_' + self.command
        if not hasattr(self, mname):
            try:
                self.send_error(501, "Metodo no soportado (%r)" % self.command)
            except Exception:
                pass
            return
        try:
            getattr(self, mname)()
        except Exception:
            pass

    # ------------------------------------------------------------- GET
    def do_GET(self):
        path = self.path.split("?")[0]
        if path in ("/", "/health"):
            self._reply(200, "ADRFBOT validator OK")
        elif path == "/install":
            self._serve_install()
        else:
            self._reply(404, "EL RECURSO SOLICITADO NO FUE ENCONTRADO")

    def _serve_install(self):
        """Sirve el script ADMRufu/install de la VPS cuando install_source=vps.

        Seguridad: solo se sirve el archivo encontrado por resolve_vps_install
        (se re-resuelve en cada peticion), debe ser un fichero regular (no
        symlink) y respetar un tope de tamaño. Se aplica el rate-limit por IP.
        """
        ip = self._client_ip()
        if self.validator.db.is_blocked(ip):
            self._reply(403, "IP BLOQUEADA")
            return
        if not self.validator.guard.rate_ok(ip):
            self._reply(429, "DEMASIADAS PETICIONES")
            return
        self.validator.reload()
        if self.validator.cfg.get("install_source") != "vps":
            self._reply(404, "SCRIPT NO DISPONIBLE")
            return
        # preferencia: ruta explicita en config (install_vps_path), si no,
        # buscarla en la VPS. Asi es deterministico y no depende del walk.
        explicit = (self.validator.cfg.get("install_vps_path") or "").strip()
        path = None
        if explicit:
            ap = os.path.abspath(explicit)
            if os.path.isfile(ap) and not os.path.islink(ap):
                path = ap
        if not path:
            path = cfgmod.resolve_vps_install()
        if not path or not os.path.isfile(path) or os.path.islink(path):
            self._reply(404, "SCRIPT NO ENCONTRADO")
            return
        try:
            size = os.path.getsize(path)
        except OSError:
            self._reply(500, "ERROR")
            return
        if size > 512 * 1024:
            self._reply(413, "SCRIPT DEMASIADO GRANDE")
            return
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                data = f.read(512 * 1024)
        except Exception:
            self._reply(500, "ERROR")
            return
        # cabecera que indica al instalador que es un script ejecutable
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(data.encode("utf-8", "replace"))))
        self.send_header("Connection", "close")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        try:
            self.wfile.write(data.encode("utf-8", "replace"))
        except Exception:
            pass

    # ------------------------------------------------------------- POST
    def do_POST(self):
        if self.path.split("?")[0] != "/server.php":
            self._reply(404, "EL RECURSO SOLICITADO NO FUE ENCONTRADO")
            return
        ip = self._client_ip()

        # bloqueo manual (persistente en DB)
        if self.validator.db.is_blocked(ip):
            self._reply_payload({"status": False, "response": "IP BLOQUEADA"})
            return
        # bloqueo temporal (rate limit de fallos)
        if self.validator.guard.banned_until(ip):
            self._reply_payload({"status": False, "response": "IP BLOQUEADA"})
            return
        # limite global de peticiones por minuto (anti-flood)
        if not self.validator.guard.rate_ok(ip):
            self._reply(429, "DEMASIADAS PETICIONES")
            return

        # leer cuerpo con tope estricto
        try:
            length = int(self.headers.get("Content-Length", 0) or 0)
        except ValueError:
            length = 0
        if length < 0 or length > MAX_BODY:
            self._reply(413, "CUERPO DEMASIADO GRANDE")
            return
        try:
            body = self.rfile.read(length).decode("utf-8", "replace")
        except Exception:
            self._reply(400, "CUERPO INVALIDO")
            return

        form = urllib.parse.parse_qs(body)
        key = (form.get("key") or [""])[0]

        with _CONCURRENCY:
            payload, info = self.validator.validate(key, ip)

        # solo los intentos con key inexistente cuentan como fuerza bruta
        if payload.get("response") == "KEY INVALIDA":
            if self.validator.guard.fail(ip):
                payload = {"status": False, "response": "IP BLOQUEADA"}
        else:
            self.validator.guard.ok(ip)

        self._reply_payload(payload)

        # notificacion CloudRun EN SEGUNDO PLANO (no bloquea la respuesta)
        if payload.get("status") and info:
            _notify_thread(self.validator, info)

    # --------------------------------------------------------------- utils
    def _reply_payload(self, payload):
        enc = crypto.encrypt(
            json.dumps(payload, separators=(",", ":"), ensure_ascii=False),
            self.validator.password,
        )
        self._reply(200, enc)

    def _reply(self, code, text):
        data = text.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        # cerramos la conexion para no acumular sockets abiertos (DoS)
        self.send_header("Connection", "close")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.close_connection = True  # libera el socket tras responder
        try:
            self.wfile.write(data)
        except Exception:
            pass

    def log_message(self, fmt, *args):
        try:
            sys.stdout.write("[server] %s\n" % _san(fmt % args))
        except Exception:
            pass


# concurrencia + notificacion en hilo aparte
_CONCURRENCY = threading.Semaphore(CONCURRENCY)


def _notify_thread(validator, info):
    def _run():
        try:
            user_id, short_id, cloudrun = info
            validator.notify_used(user_id, short_id, cloudrun)
        except Exception:
            pass
    t = threading.Thread(target=_run, daemon=True)
    t.start()


class InstallHandler(Handler):
    """Servidor dedicado (puerto install_port, default 9999) que sirve el
    script ADMRufu/install de la VPS cuando install_source == 'vps'.

    Solo expone GET /install (y / para health). No valida keys.
    """
    validator = None

    def do_POST(self):
        self._reply(405, "METODO NO PERMITIDO")

    def do_GET(self):
        p = self.path.split("?")[0]
        if p == "/install":
            self._serve_install()
        elif p in ("/", "/health"):
            self._reply(200, "ADRFBOT install server OK")
        else:
            self._reply(404, "NO ENCONTRADO")

    def log_message(self, fmt, *args):
        try:
            sys.stdout.write("[install] %s\n" % _san(fmt % args))
        except Exception:
            pass


def main():
    cfg = load_config()
    token = cfg.get("bot_token", "")
    if not token or token == "TU_BOT_TOKEN":
        print("[ADRFBOT] config.json sin bot_token. Ejecuta ./install.sh")
        sys.exit(1)
    host = cfg.get("server_host", "0.0.0.0")
    port = int(cfg.get("server_port", 8080))
    Handler.validator = Validator(cfg)
    httpd = ThreadingHTTPServer((host, port), Handler)
    print(f"[ADRFBOT] servidor de validacion en http://{host}:{port}/server.php")
    # servidor de instalacion (VPS): intenta el puerto dedicado (install_port,
    # default 9999) y, si no puede abrirlo (ocupado/firewall), cae al puerto
    # principal del validador (que ya sirve /install y esta abierto).
    install_port = int(cfg.get("install_port", 9999))
    server_port = int(cfg.get("server_port", 8080))
    InstallHandler.validator = Handler.validator
    install_httpd = None
    try:
        install_httpd = ThreadingHTTPServer(("0.0.0.0", install_port), InstallHandler)
        threading.Thread(target=install_httpd.serve_forever, daemon=True).start()
    except OSError as e:
        print(f"[ADRFBOT] ⚠️ puerto {install_port} no disponible para el "
              f"instalador VPS: {e}")
        if server_port != install_port:
            print(f"[ADRFBOT] ℹ️ instalador VPS reubicado al puerto "
                  f"principal {server_port} (ya abierto)")
            cfg["install_port"] = server_port
            try:
                save_config(cfg)
            except Exception:
                pass
            install_port = server_port
        else:
            install_port = server_port
    ip_pub = cfg.get("public_ip", "0.0.0.0")
    if not ip_pub or ip_pub in ("0.0.0.0", "auto", ""):
        ip_pub = _detect_ip()
    print(f"[ADRFBOT] servidor de instalacion (VPS) en "
          f"http://{ip_pub}:{install_port}/install")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        httpd.shutdown()
        if install_httpd:
            install_httpd.shutdown()


if __name__ == "__main__":
    main()
