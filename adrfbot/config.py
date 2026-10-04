"""ADRFBOT — carga/guardado de configuracion y helpers de server/instalador."""

import json
import os
import socket
import urllib.request

# BASE_DIR = raiz del proyecto (el padre de la carpeta adrfbot/)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# Valores por defecto (se mezclan con config.json si existe).
DEFAULTS = {
    "bot_token": "TU_BOT_TOKEN",
    "owner_id": 0,
    "contact": "@BlackHanzoX",
    "brand": "@BlackHanzoX",
    "default_reseller": "@BlackHanzoX",
    "bot_username": "",
    "server_host": "0.0.0.0",
    "server_port": 8080,
    "public_ip": "0.0.0.0",
    "password": "VnBjMnTlL",
    "key_expire_hours": 4,
    "max_keys_per_day": 0,
    "max_fail_attempts": 5,
    "block_minutes": 30,
    "verify_server": True,
    "single_use": True,
    "notify": "user",
    "install_url": "https://raw.githubusercontent.com/rudi9999/ADMRufu/main/install",
    "install_source": "github",
    "install_vps_path": "",
    "install_port": 9999,
    "db_path": "adrfbot.db",
    "log_chat": 0,
    # --- nuevos (BOTChumo) ---
    "donate": "@BlackHanzoX",
    "prices": {
        "30": "$5  (1 mes)",
        "180": "$20 (6 meses)",
        "365": "$35 (1 año)",
    },
    "max_requests_per_min": 120,
}


def config_path():
    return os.path.join(BASE_DIR, "config.json")


def _detect_ip() -> str:
    """Detecta la IP publica de forma rapida y segura (sin dependencias)."""
    # 1) intento local (sin red)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    except Exception:
        pass
    finally:
        s.close()
    # 2) servicio externo (timeout corto, falla silenciosa)
    try:
        with urllib.request.urlopen("https://api.ipify.org", timeout=4) as r:
            return r.read().decode().strip()
    except Exception:
        return "127.0.0.1"


def load_config():
    cfg = dict(DEFAULTS)
    path = config_path()
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                cfg.update(json.load(f))
        except Exception:
            pass
    # normaliza precios a dict si viene como lista/str
    if not isinstance(cfg.get("prices"), dict):
        cfg["prices"] = dict(DEFAULTS["prices"])
    return cfg


def save_config(cfg):
    """Escribe config.json de forma atomica (tmp + rename)."""
    path = config_path()
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def my_server(cfg) -> str:
    """Devuelve 'IP:PUERTO' para el que se crean las keys."""
    ip = cfg.get("public_ip", "0.0.0.0")
    port = int(cfg.get("server_port", 8080))
    if not ip or ip in ("0.0.0.0", "auto", ""):
        ip = _detect_ip()
    return f"{ip}:{port}"


def install_cmd(cfg) -> str:
    """Devuelve el comando de instalacion mostrado en /keygen.

    - github: wget -qO- <url> | bash
    - vps:    wget -qO- http://IP:PUERTO/install | bash  (el validador sirve
             el archivo ADMRufu/install encontrado en la VPS)
    """
    source = cfg.get("install_source", "github")
    if source == "vps":
        ip = cfg.get("public_ip", "0.0.0.0")
        if not ip or ip in ("0.0.0.0", "auto", ""):
            ip = _detect_ip()
        port = int(cfg.get("install_port", 9999))
        return (f"apt update -y && apt upgrade -y && "
                f"wget -qO- http://{ip}:{port}/install | bash")
    url = cfg.get("install_url", "")
    if not url:
        return "⚠️ Script de instalacion no configurado (/script <url>)"
    return f"apt update -y && apt upgrade -y && wget -qO- {url} | bash"


def resolve_vps_install(max_depth: int = 4, roots=None) -> str:
    """Busca ADMRufu/install en la VPS. Devuelve la ruta absoluta o ''.

    Busca en ubicaciones comunes y con un os.walk acotado en profundidad
    para no colgarse en discos grandes.
    """
    if roots is None:
        roots = [
            os.getcwd(),
            os.path.expanduser("~"),
            "/root",
            "/etc",
            "/opt",
            os.path.dirname(BASE_DIR),
        ]
    found = []
    for root in roots:
        if not os.path.isdir(root):
            continue
        try:
            for dp, dns, fns in os.walk(root):
                depth = dp[len(root):].count(os.sep)
                if depth > max_depth:
                    dns[:] = []
                    continue
                if os.path.basename(dp) == "ADMRufu" and "install" in fns:
                    p = os.path.join(dp, "install")
                    if os.path.isfile(p) and not os.path.islink(p):
                        found.append(os.path.abspath(p))
                        break
        except Exception:
            continue
        if found:
            break
    return found[0] if found else ""
