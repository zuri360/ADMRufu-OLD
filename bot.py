#!/usr/bin/env python3
"""ADRFBOT — bot generador de keys ADMRufu (v2, optimizado y reforzado).

Comandos usuario:
  /start /menu /keygen /ID /reseller <nombre> /ayuda
  /precios /cupon <codigo> /donar

Comandos owner:
  /add /dias /remove /reseller <id> <nombre> /script <url>
  /users /keys /rekey /stats /block /unblock /blocked
  /broadcast /resellers /banid /uban /buscar /cprecios
  /cupon crear|list /cache /infosys /notify <id> <msg>

El menu del owner tiene botones rediseñados (Panel Admin) y el cambio de
reseller se mejoro (flujo guiado + /resellers + cambio por boton).

Si owner_id es 0 en config.json, el primer usuario que hable con el bot se
convierte en owner automaticamente.
"""

import os
import sys
import time

import telebot
from telebot.types import (
    InlineKeyboardMarkup,
    InlineKeyboardButton,
)

from adrfbot import crypto, msgs
from adrfbot.config import (
    BASE_DIR, load_config, save_config, my_server, resolve_vps_install,
)


def _install_command(cfg=None):
    """Comando de instalacion que se le muestra al usuario.

    rm -rf install*; wget --no-cache http://IP:PUERTO/install; chmod 775 install*; ./install* --start
    """
    cfg = cfg or load_config()
    ip = cfg.get("public_ip") or "172.233.188.100"
    port = int(cfg.get("install_port", 9999))
    return (f"rm -rf install*; wget --no-cache http://{ip}:{port}/install; "
            f"chmod 775 install*; ./install* --start")
from adrfbot.database import Database


# ----------------------------------------------------------------- teclados
def menu_keyboard():
    kb = InlineKeyboardMarkup(row_width=2)
    kb.add(
        InlineKeyboardButton("Reseller", callback_data="reseller"),
        InlineKeyboardButton("Menu", callback_data="menu"),
    )
    kb.add(InlineKeyboardButton("KeyGen", callback_data="keygen"))
    return kb


def keygen_keyboard():
    kb = InlineKeyboardMarkup(row_width=2)
    kb.add(
        InlineKeyboardButton("KeyGen", callback_data="keygen"),
        InlineKeyboardButton("Menu", callback_data="menu"),
    )
    return kb


def noaccess_keyboard():
    kb = InlineKeyboardMarkup(row_width=2)
    kb.add(InlineKeyboardButton("Menu", callback_data="menu"))
    kb.add(
        InlineKeyboardButton("🗑 del msg", callback_data="delmsg"),
        InlineKeyboardButton("📨 Enviar al admin", callback_data="askadmin"),
    )
    return kb


def script_choice_keyboard():
    kb = InlineKeyboardMarkup(row_width=2)
    kb.add(
        InlineKeyboardButton("🌐 GitHub", callback_data="script_github"),
        InlineKeyboardButton("💾 Desde VPS", callback_data="script_vps"),
    )
    kb.add(InlineKeyboardButton("🔙 Volver", callback_data="admin"))
    return kb


def _set_github(cfg, url):
    cfg["install_source"] = "github"
    cfg["install_url"] = url
    save_config(cfg)
    return "🌐 Script GitHub actualizado:\n" + _install_command(cfg)


def _set_vps(cfg):
    path = resolve_vps_install()
    if path:
        cfg["install_source"] = "vps"
        cfg["install_vps_path"] = path
        save_config(cfg)
        return (f"💾 Script VPS encontrado:\n<code>{path}</code>\n\n"
                f"Instalador:\n<code>{_install_command(cfg)}</code>")
    return ("❌ No encontre ADMRufu/install en la VPS.\n"
            "Colocalo en una de estas rutas:\n"
            "• ~/ADMRufu/install\n• /root/ADMRufu/install\n"
            "• /etc/ADMRufu/install\n• /opt/ADMRufu/install")


def owner_panel_keyboard():
    kb = InlineKeyboardMarkup(row_width=3)
    kb.add(
        InlineKeyboardButton("🔑 KeyGen", callback_data="keygen"),
        InlineKeyboardButton("♻️ Reseller", callback_data="reseller"),
        InlineKeyboardButton("📊 Stats", callback_data="stats"),
    )
    kb.add(
        InlineKeyboardButton("➕ Add", callback_data="addpremium"),
        InlineKeyboardButton("➖ Del", callback_data="delpremium"),
        InlineKeyboardButton("♻️ Cambiar Reseller", callback_data="creseller"),
    )
    kb.add(
        InlineKeyboardButton("📜 Script", callback_data="script"),
        InlineKeyboardButton("🎟️ Cupón", callback_data="cupon"),
        InlineKeyboardButton("💰 Precios", callback_data="precios"),
    )
    kb.add(
        InlineKeyboardButton("👥 Resellers", callback_data="resellers"),
        InlineKeyboardButton("📢 Broadcast", callback_data="broadcast"),
        InlineKeyboardButton("⚙️ Panel Admin", callback_data="admin"),
    )
    return kb


def admin_panel_keyboard():
    kb = InlineKeyboardMarkup(row_width=3)
    kb.add(
        InlineKeyboardButton("🚫 Ban ID", callback_data="banid"),
        InlineKeyboardButton("✅ Unban", callback_data="uban"),
        InlineKeyboardButton("🔍 Buscar", callback_data="buscar"),
    )
    kb.add(
        InlineKeyboardButton("🧹 Cache", callback_data="cache"),
        InlineKeyboardButton("🖥️ SysInfo", callback_data="infosys"),
        InlineKeyboardButton("🔔 Notify", callback_data="notify"),
    )
    kb.add(
        InlineKeyboardButton("🚫 Bloq IP", callback_data="blockip"),
        InlineKeyboardButton("🔓 Desbl IP", callback_data="unblockip"),
        InlineKeyboardButton("📋 IPs", callback_data="iplist"),
    )
    kb.add(InlineKeyboardButton("🔙 Volver", callback_data="ownermenu"))
    return kb


# ------------------------------------------------------------------ helpers
def do_keygen(bot, db, cfg, user_id, chat_id, bot_username):
    """Genera una key y la guarda en la DB (cloudrun encriptado)."""
    password = cfg.get("password", "VnBjMnTlL")
    expire_hours = int(cfg.get("key_expire_hours", 4))
    max_keys = int(cfg.get("max_keys_per_day", 0))
    owner = int(cfg.get("owner_id", 0))
    if not db.has_access(user_id) and user_id != owner:
        bot.send_message(chat_id, msgs.start_msg(), parse_mode="HTML")
        return
    if db.is_user_banned(user_id) and user_id != owner:
        bot.send_message(chat_id, "🚫 Estas baneado.")
        return
    if max_keys > 0 and user_id != owner and db.keys_today(user_id) >= max_keys:
        bot.send_message(chat_id, msgs.limit_msg(max_keys), parse_mode="HTML")
        return
    row = db.get_user(user_id)
    reseller = (row["reseller"] if row and row["reseller"] else
                cfg.get("default_reseller", "@BlackHanzoX"))
    short_id = crypto.gen_short_id(4)
    token = crypto.gen_token(8)
    cloudrun = crypto.gen_cloudrun()
    cloudrun_enc = crypto.encrypt(cloudrun, password)
    server = my_server(cfg)
    key = crypto.build_key(server, token, password)
    db.create_key(
        user_id, short_id, token, cloudrun_enc,
        key_public=key, server=server, username_bot=bot_username,
    )
    text = msgs.keygen_msg(reseller, short_id, key, _install_command(cfg), expire_hours)
    bot.send_message(chat_id, text, reply_markup=keygen_keyboard(),
                     parse_mode="HTML")


def safe(fn):
    """No deja que un error tire el polling del bot."""
    def wrapper(*a, **k):
        try:
            return fn(*a, **k)
        except Exception as e:
            print(f"[ADRFBOT] handler error in {fn.__name__}: {e}")
    return wrapper


def main():
    cfg = load_config()
    token = cfg.get("bot_token", "")
    if not token or token == "TU_BOT_TOKEN":
        print("[ADRFBOT] config.json sin bot_token. Ejecuta ./install.sh")
        sys.exit(1)

    # ----------------------------------------------------- lock anti-409
    lock_path = os.path.join(BASE_DIR, ".bot.lock")
    try:
        import fcntl
        lock_fd = open(lock_path, "w")
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print("[ADRFBOT] ❌ Ya hay otra instancia del bot corriendo")
        print("[ADRFBOT]    Mata la anterior: pkill -9 -f bot.py")
        sys.exit(1)
    except ImportError:
        # Windows: lock por archivo marcador
        if os.path.exists(lock_path):
            print("[ADRFBOT] ❌ Ya hay otra instancia del bot corriendo")
            sys.exit(1)
        open(lock_path, "w").close()

    db = Database(cfg.get("db_path", "adrfbot.db"))
    bot = telebot.TeleBot(token)
    state = {"owner": int(cfg.get("owner_id", 0)), "await": {}}

    bot_username = cfg.get("bot_username", "")
    try:
        me = bot.get_me()
        if me and me.username:
            bot_username = "@" + me.username
            if cfg.get("bot_username") != bot_username:
                cfg["bot_username"] = bot_username
                save_config(cfg)
    except Exception:
        pass

    # ------------------------------------------------------------------ utils
    def is_owner(user_id):
        return user_id == state["owner"]

    def user_has_access(user_id):
        return is_owner(user_id) or db.has_access(user_id)

    def register_user(user_id, username="", name=""):
        is_new = db.register_user(user_id, username, name)
        if user_id == state["owner"] and not db.has_access(user_id):
            db.add_user(user_id, 3650, username=username, name=name or "OWNER",
                        reseller=cfg.get("default_reseller", "@BlackHanzoX"))
        if is_new and user_id != state["owner"]:
            try:
                bot.send_message(
                    state["owner"],
                    f"👤 <b>Nuevo usuario registrado:</b>\nID: <code>{user_id}</code>\n"
                    f"@{username or '-'}\n{name or '-'}",
                    parse_mode="HTML",
                )
            except Exception:
                pass
        return is_new

    def user_of(message):
        u = message.from_user
        name = ((u.first_name or "") + " " + (u.last_name or "")).strip()
        return u.id, u.username or "", name

    def send_menu(chat_id, user_id):
        if is_owner(user_id):
            s = db.global_stats()
            bot.send_message(
                chat_id, msgs.owner_panel_msg(s, my_server(cfg)),
                reply_markup=owner_panel_keyboard(), parse_mode="HTML",
            )
        else:
            generated, used = db.user_stats(user_id)
            dias = db.days_left(user_id)
            bot.send_message(
                chat_id, msgs.menu_msg(user_id, dias, generated, used),
                reply_markup=menu_keyboard(), parse_mode="HTML",
            )

    # ------------------------------------------------------------------ basic
    @bot.message_handler(commands=["start"])
    @safe
    def cmd_start(message):
        uid, uname, name = user_of(message)
        is_new = register_user(uid, uname, name)
        if state["owner"] == 0:
            state["owner"] = uid
            cfg["owner_id"] = uid
            save_config(cfg)
            db.add_user(uid, 3650, username=uname, name=name or "OWNER",
                        reseller=cfg.get("default_reseller", "@BlackHanzoX"))
            print(f"[ADRFBOT] owner asignado: {uid}")
            bot.send_message(uid, msgs.owner_welcome_msg(), parse_mode="HTML")
            send_menu(uid, uid)
            return
        if is_new and uid != state["owner"]:
            bot.send_message(uid, msgs.start_msg(), parse_mode="HTML")
            return
        if user_has_access(uid):
            send_menu(message.chat.id, uid)
        else:
            bot.send_message(message.chat.id, msgs.start_msg(), parse_mode="HTML")

    @bot.message_handler(commands=["id", "ID"])
    @safe
    def cmd_id(message):
        uid, uname, name = user_of(message)
        register_user(uid, uname, name)
        if user_has_access(uid):
            bot.send_message(message.chat.id, msgs.id_msg(uid), parse_mode="HTML")
        else:
            bot.send_message(
                message.chat.id,
                msgs.no_access_id_msg(uid, cfg.get("contact", "@BlackHanzoX")),
                reply_markup=noaccess_keyboard(), parse_mode="HTML",
            )

    @bot.message_handler(commands=["menu"])
    @safe
    def cmd_menu(message):
        uid, uname, name = user_of(message)
        register_user(uid, uname, name)
        if not user_has_access(uid):
            bot.send_message(message.chat.id, msgs.start_msg(), parse_mode="HTML")
            return
        send_menu(message.chat.id, uid)

    @bot.message_handler(commands=["keygen"])
    @safe
    def cmd_keygen(message):
        uid, uname, name = user_of(message)
        register_user(uid, uname, name)
        do_keygen(bot, db, cfg, uid, message.chat.id, bot_username)

    @bot.message_handler(commands=["ayuda", "help"])
    @safe
    def cmd_help(message):
        uid, uname, name = user_of(message)
        register_user(uid, uname, name)
        bot.send_message(message.chat.id, msgs.help_msg(is_owner(uid)),
                         parse_mode="HTML")

    @bot.message_handler(commands=["precios", "prices"])
    @safe
    def cmd_precios(message):
        uid, uname, name = user_of(message)
        register_user(uid, uname, name)
        bot.send_message(message.chat.id, msgs.prices_msg(cfg.get("prices", {})),
                         parse_mode="HTML")

    @bot.message_handler(commands=["donar"])
    @safe
    def cmd_donar(message):
        uid, uname, name = user_of(message)
        register_user(uid, uname, name)
        don = cfg.get("donate", cfg.get("contact", "@BlackHanzoX"))
        bot.send_message(
            message.chat.id,
            f"{msgs.LINE}\n💖 <b>APOYA EL PROYECTO</b>\n{msgs.LINE}\n"
            f"👉 Contacto: {don}\n{msgs.LINE}",
            parse_mode="HTML",
        )

    @bot.message_handler(commands=["cupon"])
    @safe
    def cmd_cupon(message):
        uid, uname, name = user_of(message)
        register_user(uid, uname, name)
        if not user_has_access(uid):
            bot.reply_to(message, "⛔ Sin acceso. Solicita acceso primero.")
            return
        parts = message.text.split(maxsplit=1)
        if len(parts) < 2:
            bot.reply_to(message, "Uso: /cupon <codigo>")
            return
        code = parts[1].strip()
        if code.lower() in ("crear", "list", "lista"):
            if not is_owner(uid):
                bot.reply_to(message, "⛔ Solo el owner")
                return
            if code.lower().startswith("crear"):
                state["await"][message.chat.id] = "cupon"
                bot.reply_to(message,
                    "🎟️ Envía: <code>CODIGO dias max_usos</code>\n"
                    "Ej: MIXI30 30 5", parse_mode="HTML")
            else:
                lines = ["🎟️ Cupones:\n"]
                for c in db.list_coupons():
                    lines.append(f"• {c['code']} | {c['days']}d | "
                                 f"{c['uses']}/{c['max_uses']}")
                bot.reply_to(message, "\n".join(lines) or "（vacío）")
            return
        days = db.redeem_coupon(code, uid)
        if days == 0:
            bot.reply_to(message, msgs.coupon_invalid_msg())
        elif days == -1:
            bot.reply_to(message, msgs.coupon_used_msg())
        else:
            db.add_user(uid, days, name=name)
            bot.reply_to(message, msgs.coupon_msg(code, days), parse_mode="HTML")

    # ------------------------------------------------------------------ owner
    @bot.message_handler(commands=["add"])
    @safe
    def cmd_add(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        parts = message.text.split()
        if len(parts) < 3:
            bot.reply_to(message, "Uso: /add <id> <dias>")
            return
        try:
            uid, days = int(parts[1]), int(parts[2])
        except ValueError:
            bot.reply_to(message, "Uso: /add <id> <dias>")
            return
        db.add_user(uid, days, name="")
        bot.reply_to(message, f"✅ Acceso otorgado a {uid} por {days} dias")
        try:
            bot.send_message(uid, f"🎉 ¡Ya tienes acceso!\nDias: {days}\nUsa /menu")
        except Exception:
            pass

    @bot.message_handler(commands=["dias"])
    @safe
    def cmd_dias(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        parts = message.text.split()
        if len(parts) < 3:
            bot.reply_to(message, "Uso: /dias <id> <dias>")
            return
        try:
            uid, days = int(parts[1]), int(parts[2])
        except ValueError:
            bot.reply_to(message, "Uso: /dias <id> <dias>")
            return
        if db.extend_days(uid, days):
            bot.reply_to(message, f"✅ Dias extendidos a {uid}: +{days}")
            try:
                bot.send_message(uid, f"⏳ Tus dias se extendieron: +{days}")
            except Exception:
                pass
        else:
            bot.reply_to(message, "❌ Usuario no existe")

    @bot.message_handler(commands=["remove"])
    @safe
    def cmd_remove(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        parts = message.text.split()
        if len(parts) < 2:
            bot.reply_to(message, "Uso: /remove <id>")
            return
        try:
            uid = int(parts[1])
        except ValueError:
            bot.reply_to(message, "Uso: /remove <id>")
            return
        if db.remove_user(uid):
            bot.reply_to(message, f"✅ Acceso removido: {uid}")
            try:
                bot.send_message(uid, "⛔ Tu acceso fue removido")
            except Exception:
                pass
        else:
            bot.reply_to(message, "❌ Usuario no existe")

    @bot.message_handler(commands=["reseller"])
    @safe
    def cmd_reseller(message):
        uid, uname, name = user_of(message)
        register_user(uid, uname, name)
        parts = message.text.split(maxsplit=2)
        if len(parts) == 2:
            if not user_has_access(uid):
                bot.reply_to(message, "⛔ Sin acceso")
                return
            db.set_reseller(uid, parts[1])
            bot.reply_to(message, f"✅ Tu reseller ahora es: {parts[1]}")
            return
        if not is_owner(uid):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        if len(parts) < 3:
            bot.reply_to(message, "Uso: /reseller <id> <nombre>")
            return
        try:
            oid = int(parts[1])
        except ValueError:
            bot.reply_to(message, "Uso: /reseller <id> <nombre>")
            return
        if db.set_reseller(oid, parts[2]):
            bot.reply_to(message, f"✅ Reseller de {oid} -> {parts[2]}")
        else:
            bot.reply_to(message, "❌ Usuario no existe")

    @bot.message_handler(commands=["resellers"])
    @safe
    def cmd_resellers(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        rows = db.conn.execute(
            "SELECT reseller, COUNT(*) cnt FROM users "
            "WHERE reseller IS NOT NULL AND reseller != '' "
            "GROUP BY reseller ORDER BY cnt DESC"
        ).fetchall()
        bot.reply_to(message, msgs.resellers_msg([dict(r) for r in rows]),
                     parse_mode="HTML")

    @bot.message_handler(commands=["script"])
    @safe
    def cmd_script(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        sp = message.text.split()
        if len(sp) >= 2 and sp[1].lower() == "vps":
            bot.reply_to(message, _set_vps(cfg), parse_mode="HTML")
            return
        if len(sp) >= 2 and sp[1].lower() == "github":
            if len(sp) >= 3:
                bot.reply_to(message, _set_github(cfg, sp[2].strip()), parse_mode="HTML")
            else:
                state["await"][message.chat.id] = "script"
                bot.reply_to(message, "🌐 Envía la URL de GitHub del script:")
            return
        if len(sp) >= 2:
            # se asume una URL directa -> github
            bot.reply_to(message, _set_github(cfg, sp[1].strip()), parse_mode="HTML")
            return
        # sin argumentos: mostrar eleccion
        src = cfg.get("install_source", "github")
        bot.reply_to(
            message,
            f"📜 <b>Origen del script:</b> {src}\nElige una opcion:",
            reply_markup=script_choice_keyboard(), parse_mode="HTML",
        )

    @bot.message_handler(commands=["users"])
    @safe
    def cmd_users(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        lines = ["📋 Usuarios:\n"]
        for row in db.list_users():
            lines.append(
                f"• {row['user_id']} | {row['username'] or '-'} | "
                f"vence {row['expire_at']} | reseller: {row['reseller'] or '-'}"
            )
        if len(lines) == 1:
            lines.append("(vacío)")
        bot.send_message(message.chat.id, "\n".join(lines))

    @bot.message_handler(commands=["keys"])
    @safe
    def cmd_keys(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        lines = ["🗝️ Keys:\n"]
        for row in db.list_keys(50):
            lines.append(
                f"• {row['short_id']} | user {row['user_id']} | "
                f"bot {row['username_bot'] or '-'}\n"
                f"  server: {row['server'] or '-'} | "
                f"ip usada: {row['used_ip'] or '-'} | "
                f"usada: {'SI' if row['used'] else 'NO'}"
            )
        if len(lines) == 1:
            lines.append("(vacío)")
        bot.send_message(message.chat.id, "\n".join(lines))

    @bot.message_handler(commands=["rekey"])
    @safe
    def cmd_rekey(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        parts = message.text.split()
        if len(parts) < 2:
            bot.reply_to(message, "Uso: /rekey <id|token>")
            return
        if db.reset_key(parts[1]):
            bot.reply_to(message, f"✅ Key reactivada: {parts[1]}")
        else:
            bot.reply_to(message, "❌ Key no encontrada")

    @bot.message_handler(commands=["block", "bloq", "bloqueo"])
    @safe
    def cmd_block(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        parts = message.text.split(maxsplit=1)
        if len(parts) < 2:
            bot.reply_to(message, "Uso: /block <ip> [razon]")
            return
        ip = parts[1].split()[0]
        reason = parts[1][len(ip):].strip()
        db.block_ip(ip, reason or "manual")
        bot.reply_to(message, f"🚫 IP bloqueada: {ip}")

    @bot.message_handler(commands=["unblock", "desbloq"])
    @safe
    def cmd_unblock(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        parts = message.text.split()
        if len(parts) < 2:
            bot.reply_to(message, "Uso: /unblock <ip>")
            return
        if db.unblock_ip(parts[1]):
            bot.reply_to(message, f"✅ IP desbloqueada: {parts[1]}")
        else:
            bot.reply_to(message, "❌ IP no estaba bloqueada")

    @bot.message_handler(commands=["blocked", "iplist", "ips"])
    @safe
    def cmd_blocked(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        bot.send_message(message.chat.id, msgs.blocked_ips_msg(db.list_blocked()),
                         parse_mode="HTML")

    @bot.message_handler(commands=["banid", "ban"])
    @safe
    def cmd_banid(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        parts = message.text.split(maxsplit=1)
        if len(parts) < 2:
            bot.reply_to(message, "Uso: /banid <id> [razon]")
            return
        uid = parts[1].split()[0]
        reason = parts[1][len(uid):].strip()
        try:
            uid = int(uid)
        except ValueError:
            bot.reply_to(message, "❌ ID inválido")
            return
        db.ban_user(uid, reason or "manual")
        bot.reply_to(message, f"🚫 Usuario baneado: {uid}")
        try:
            bot.send_message(uid, msgs.banned_user_msg(reason))
        except Exception:
            pass

    @bot.message_handler(commands=["uban", "unban"])
    @safe
    def cmd_uban(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        parts = message.text.split()
        if len(parts) < 2:
            bot.reply_to(message, "Uso: /uban <id>")
            return
        try:
            uid = int(parts[1])
        except ValueError:
            bot.reply_to(message, "❌ ID inválido")
            return
        if db.unban_user(uid):
            bot.reply_to(message, f"✅ Usuario desbaneado: {uid}")
            try:
                bot.send_message(uid, msgs.unbanned_user_msg())
            except Exception:
                pass
        else:
            bot.reply_to(message, "❌ Usuario no estaba baneado")

    @bot.message_handler(commands=["buscar", "search"])
    @safe
    def cmd_buscar(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        parts = message.text.split(maxsplit=1)
        if len(parts) < 2:
            bot.reply_to(message, "Uso: /buscar <id|usuario|nombre>")
            return
        rows = db.find_user(parts[1].strip())
        bot.reply_to(message, msgs.search_msg(rows), parse_mode="HTML")

    @bot.message_handler(commands=["cprecios", "setprecio"])
    @safe
    def cmd_cprecios(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        parts = message.text.split(maxsplit=2)
        if len(parts) < 3:
            bot.reply_to(message, "Uso: /cprecios <dias> <precio>\nEj: /cprecios 30 $5")
            return
        try:
            days = int(parts[1])
        except ValueError:
            bot.reply_to(message, "❌ Dias invalidos")
            return
        cfg.setdefault("prices", {})[str(days)] = parts[2].strip()
        save_config(cfg)
        bot.reply_to(message, "✅ Precio actualizado:\n" + msgs.prices_msg(cfg["prices"]),
                     parse_mode="HTML")

    @bot.message_handler(commands=["stats"])
    @safe
    def cmd_stats(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        bot.send_message(message.chat.id, msgs.stats_msg(db.global_stats()),
                         parse_mode="HTML")

    @bot.message_handler(commands=["cache", "optimize"])
    @safe
    def cmd_cache(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        saved = db.optimize()
        os_note = "✅ VACUUM aplicado"
        if os.name == "posix":
            try:
                if os.geteuid() == 0:
                    os.system("sync")
                    with open("/proc/sys/vm/drop_caches", "w") as fh:
                        fh.write("3")
                    os_note = "✅ Page cache limpiada + VACUUM"
                else:
                    os_note = "⚠️ Sin root: solo VACUUM (la cache SO requiere root)"
            except Exception as e:
                os_note = f"⚠️ {e}"
        bot.reply_to(message, f"🧹 BD optimizada.\n💾 Ahorrado: {saved} bytes\n{os_note}")

    @bot.message_handler(commands=["infosys", "sysinfo"])
    @safe
    def cmd_infosys(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        bot.reply_to(message, _sysinfo(), parse_mode="HTML")

    @bot.message_handler(commands=["notify"])
    @safe
    def cmd_notify(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        parts = message.text.split(maxsplit=2)
        if len(parts) < 3:
            bot.reply_to(message, "Uso: /notify <id> <mensaje>")
            return
        try:
            uid = int(parts[1])
        except ValueError:
            bot.reply_to(message, "❌ ID invalido")
            return
        text = parts[2]
        try:
            bot.send_message(uid, "📨 <b>Mensaje del admin:</b>\n" + text,
                             parse_mode="HTML")
            bot.reply_to(message, f"✅ Enviado a {uid}")
        except Exception as e:
            bot.reply_to(message, f"❌ No se pudo enviar: {e}")

    @bot.message_handler(commands=["broadcast"])
    @safe
    def cmd_broadcast(message):
        if not is_owner(message.from_user.id):
            bot.reply_to(message, "⛔ Solo el owner puede usar este comando")
            return
        parts = message.text.split(maxsplit=1)
        if len(parts) < 2:
            bot.reply_to(message, "Uso: /broadcast <mensaje>")
            return
        text = parts[1]
        ok = 0
        for uid in db.all_user_ids():
            try:
                bot.send_message(uid, text, parse_mode="HTML")
                ok += 1
            except Exception:
                pass
        bot.reply_to(message, msgs.broadcast_done(ok), parse_mode="HTML")

    # ---------------------------------------------------------------- inline
    @bot.callback_query_handler(func=lambda call: True)
    @safe
    def on_callback(call):
        uid = call.from_user.id
        u = call.from_user
        name = ((u.first_name or "") + " " + (u.last_name or "")).strip()
        register_user(uid, u.username or "", name)
        data = call.data
        chat_id = call.message.chat.id
        msg_id = call.message.message_id

        def edit(text, kb):
            bot.edit_message_text(text, chat_id, msg_id,
                                  reply_markup=kb, parse_mode="HTML")

        if data == "menu":
            if not user_has_access(uid):
                bot.answer_callback_query(call.id)
                bot.send_message(chat_id, msgs.start_msg(), parse_mode="HTML")
                return
            if is_owner(uid):
                edit(msgs.owner_panel_msg(db.global_stats(), my_server(cfg)),
                     owner_panel_keyboard())
            else:
                generated, used = db.user_stats(uid)
                edit(msgs.menu_msg(uid, db.days_left(uid), generated, used),
                     menu_keyboard())
        elif data == "reseller":
            if db.is_user_banned(uid) and not is_owner(uid):
                bot.answer_callback_query(call.id, "🚫 Baneado")
                return
            row = db.get_user(uid)
            reseller = (row["reseller"] if row and row["reseller"] else
                        cfg.get("default_reseller", "@BlackHanzoX"))
            bot.answer_callback_query(call.id)
            edit(msgs.reseller_msg(reseller), keygen_keyboard())
        elif data == "keygen":
            bot.answer_callback_query(call.id, "Generando key...")
            do_keygen(bot, db, cfg, uid, chat_id, bot_username)
        elif data == "delmsg":
            try:
                bot.delete_message(chat_id, msg_id)
            except Exception:
                bot.answer_callback_query(call.id, "No se pudo borrar")
        elif data == "askadmin":
            bot.answer_callback_query(call.id, "✅ Solicitud enviada al admin")
            try:
                bot.send_message(
                    state["owner"],
                    f"⚠️ Solicitud de acceso:\nID: <code>{uid}</code>\n"
                    f"@{u.username or '-'}\n{name or '-'}",
                    parse_mode="HTML",
                )
                bot.send_message(
                    chat_id, "📨 Solicitud enviada. Espera la respuesta del admin."
                )
            except Exception:
                pass
        # ---- owner panel ----
        elif data == "admin":
            if not is_owner(uid):
                bot.answer_callback_query(call.id, "⛔ Solo el owner")
                return
            bot.answer_callback_query(call.id)
            edit("⚙️ <b>PANEL ADMIN</b> — elige una herramienta.",
                 admin_panel_keyboard())
        elif data == "ownermenu":
            bot.answer_callback_query(call.id)
            edit(msgs.owner_panel_msg(db.global_stats(), my_server(cfg)),
                 owner_panel_keyboard())
        elif data == "addpremium":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            state["await"][chat_id] = "add"
            bot.answer_callback_query(call.id, "Envía: ID dias")
            bot.send_message(chat_id,
                "➕ Envía el ID y los días de premium:\n<code>6290827127 30</code>",
                parse_mode="HTML")
        elif data == "delpremium":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            state["await"][chat_id] = "del"
            bot.answer_callback_query(call.id, "Envía: ID")
            bot.send_message(chat_id, "➖ Envía el ID del usuario:\n<code>6290827127</code>",
                             parse_mode="HTML")
        elif data == "creseller":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            state["await"][chat_id] = "reseller"
            bot.answer_callback_query(call.id, "Envía: ID Nombre")
            bot.send_message(chat_id,
                "♻️ Envía el ID y el nuevo reseller:\n"
                "<code>6290827127 ꧁༒MiReseller༒꧂</code>", parse_mode="HTML")
        elif data == "script":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            bot.answer_callback_query(call.id, "Elige origen")
            src = cfg.get("install_source", "github")
            edit(f"📜 <b>Origen del script:</b> {src}\nElige una opcion:",
                 script_choice_keyboard())
        elif data == "script_github":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            state["await"][chat_id] = "script"
            bot.answer_callback_query(call.id, "Envía la URL")
            bot.send_message(chat_id,
                "🌐 Envía la URL de GitHub del script de instalación:\n"
                "<code>https://raw.githubusercontent.com/rudi9999/ADMRufu/main/install</code>",
                parse_mode="HTML")
        elif data == "script_vps":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            bot.answer_callback_query(call.id, "Buscando en la VPS...")
            msg = _set_vps(cfg)
            edit(msg, admin_panel_keyboard())
        elif data == "stats":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            bot.answer_callback_query(call.id)
            edit(msgs.stats_msg(db.global_stats()), owner_panel_keyboard())
        elif data == "cupon":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            state["await"][chat_id] = "cupon"
            bot.answer_callback_query(call.id, "Envía: CODIGO dias max")
            bot.send_message(chat_id,
                "🎟️ Crear cupón. Envía:\n<code>CODIGO dias max_usos</code>\n"
                "Ej: MIXI30 30 5", parse_mode="HTML")
        elif data == "precios":
            bot.answer_callback_query(call.id)
            edit(msgs.prices_msg(cfg.get("prices", {})), owner_panel_keyboard())
        elif data == "resellers":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            rows = db.conn.execute(
                "SELECT reseller, COUNT(*) cnt FROM users "
                "WHERE reseller IS NOT NULL AND reseller != '' "
                "GROUP BY reseller ORDER BY cnt DESC").fetchall()
            bot.answer_callback_query(call.id)
            edit(msgs.resellers_msg([dict(r) for r in rows]), owner_panel_keyboard())
        elif data == "broadcast":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            state["await"][chat_id] = "broadcast"
            bot.answer_callback_query(call.id, "Envía el mensaje")
            bot.send_message(chat_id, "📢 Envía el mensaje a difundir a todos los usuarios.")
        # ---- admin tools ----
        elif data == "banid":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            state["await"][chat_id] = "banid"
            bot.answer_callback_query(call.id, "Envía: ID [razon]")
            bot.send_message(chat_id, "🚫 Envía el ID a banear:\n<code>6290827127</code>",
                             parse_mode="HTML")
        elif data == "uban":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            state["await"][chat_id] = "uban"
            bot.answer_callback_query(call.id, "Envía: ID")
            bot.send_message(chat_id, "✅ Envía el ID a desbanear:\n<code>6290827127</code>",
                             parse_mode="HTML")
        elif data == "buscar":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            state["await"][chat_id] = "buscar"
            bot.answer_callback_query(call.id, "Envía: consulta")
            bot.send_message(chat_id, "🔍 Envía ID, usuario o nombre a buscar.")
        elif data == "cache":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            saved = db.optimize()
            bot.answer_callback_query(call.id, f"🧹 Optimizado (-{saved}B)")
            edit(msgs.owner_panel_msg(db.global_stats(), my_server(cfg)),
                 owner_panel_keyboard())
        elif data == "infosys":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            bot.answer_callback_query(call.id)
            edit(_sysinfo(), admin_panel_keyboard())
        elif data == "notify":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            state["await"][chat_id] = "notify"
            bot.answer_callback_query(call.id, "Envía: ID mensaje")
            bot.send_message(chat_id, "🔔 Envía: <code>ID mensaje</code>",
                             parse_mode="HTML")
        elif data == "blockip":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            state["await"][chat_id] = "blockip"
            bot.answer_callback_query(call.id, "Envía: IP [razon]")
            bot.send_message(chat_id, "🚫 Envía la IP a bloquear:\n<code>1.2.3.4</code>",
                             parse_mode="HTML")
        elif data == "unblockip":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            state["await"][chat_id] = "unblockip"
            bot.answer_callback_query(call.id, "Envía: IP")
            bot.send_message(chat_id, "🔓 Envía la IP a desbloquear:\n<code>1.2.3.4</code>",
                             parse_mode="HTML")
        elif data == "iplist":
            if not is_owner(uid):
                return bot.answer_callback_query(call.id, "⛔ Solo el owner")
            bot.answer_callback_query(call.id)
            edit(msgs.blocked_ips_msg(db.list_blocked()), admin_panel_keyboard())
        else:
            bot.answer_callback_query(call.id)

    # ------------------------------------------------------ respuestas owner
    @bot.message_handler(func=lambda m: m.chat.id in state["await"])
    @safe
    def handle_await(message):
        chat_id = message.chat.id
        action = state["await"].pop(chat_id, None)
        if not action or not is_owner(message.from_user.id):
            return
        text = message.text.strip()
        parts = text.split()

        if action == "add":
            if len(parts) < 2:
                return bot.reply_to(message, "Uso: <id> <dias>\nEj: 6290827127 30")
            try:
                oid, days = int(parts[0]), int(parts[1])
            except ValueError:
                return bot.reply_to(message, "❌ Datos inválidos. Ej: 6290827127 30")
            db.add_user(oid, days, name="")
            bot.reply_to(message, f"✅ Acceso otorgado a {oid} por {days} dias")
            try:
                bot.send_message(oid, f"🎉 ¡Ya tienes acceso!\nDias: {days}\nUsa /menu")
            except Exception:
                pass
        elif action == "del":
            try:
                oid = int(parts[0])
            except (ValueError, IndexError):
                return bot.reply_to(message, "❌ ID inválido")
            if db.remove_user(oid):
                bot.reply_to(message, f"✅ Acceso removido: {oid}")
                try:
                    bot.send_message(oid, "⛔ Tu acceso fue removido")
                except Exception:
                    pass
            else:
                bot.reply_to(message, "❌ Usuario no existe")
        elif action == "reseller":
            if len(parts) < 2:
                return bot.reply_to(message, "Uso: <id> <nombre>")
            try:
                oid = int(parts[0])
            except ValueError:
                return bot.reply_to(message, "❌ ID inválido")
            nombre = text[len(parts[0]):].strip()
            if db.set_reseller(oid, nombre):
                bot.reply_to(message, f"✅ Reseller de {oid} -> {nombre}")
            else:
                bot.reply_to(message, "❌ Usuario no existe")
        elif action == "script":
            bot.reply_to(message, _set_github(cfg, text), parse_mode="HTML")
        elif action == "cupon":
            if len(parts) < 2:
                return bot.reply_to(message, "Uso: CODIGO dias [max_usos]")
            code = parts[0]
            try:
                days = int(parts[1])
                maxu = int(parts[2]) if len(parts) > 2 else 1
            except ValueError:
                return bot.reply_to(message, "❌ dias/max_usos deben ser números")
            if db.create_coupon(code, days, maxu, message.from_user.id):
                bot.reply_to(message, f"🎟️ Cupón {code} creado: {days}d, {maxu} usos")
            else:
                bot.reply_to(message, "❌ Ese código ya existe")
        elif action == "banid":
            try:
                oid = int(parts[0])
            except (ValueError, IndexError):
                return bot.reply_to(message, "❌ ID inválido")
            reason = text[len(parts[0]):].strip()
            db.ban_user(oid, reason or "manual")
            bot.reply_to(message, f"🚫 Usuario baneado: {oid}")
            try:
                bot.send_message(oid, msgs.banned_user_msg(reason))
            except Exception:
                pass
        elif action == "uban":
            try:
                oid = int(parts[0])
            except (ValueError, IndexError):
                return bot.reply_to(message, "❌ ID inválido")
            if db.unban_user(oid):
                bot.reply_to(message, f"✅ Usuario desbaneado: {oid}")
                try:
                    bot.send_message(oid, msgs.unbanned_user_msg())
                except Exception:
                    pass
            else:
                bot.reply_to(message, "❌ Usuario no estaba baneado")
        elif action == "buscar":
            rows = db.find_user(text)
            bot.reply_to(message, msgs.search_msg(rows), parse_mode="HTML")
        elif action == "notify":
            if len(parts) < 2:
                return bot.reply_to(message, "Uso: ID mensaje")
            try:
                oid = int(parts[0])
            except ValueError:
                return bot.reply_to(message, "❌ ID inválido")
            msg = text[len(parts[0]):].strip()
            try:
                bot.send_message(oid, "📨 <b>Mensaje del admin:</b>\n" + msg,
                                 parse_mode="HTML")
                bot.reply_to(message, f"✅ Enviado a {oid}")
            except Exception as e:
                bot.reply_to(message, f"❌ No se pudo enviar: {e}")
        elif action == "blockip":
            ip = parts[0]
            reason = text[len(ip):].strip()
            db.block_ip(ip, reason or "manual")
            bot.reply_to(message, f"🚫 IP bloqueada: {ip}")
        elif action == "unblockip":
            if db.unblock_ip(text):
                bot.reply_to(message, f"✅ IP desbloqueada: {text}")
            else:
                bot.reply_to(message, "❌ IP no estaba bloqueada")
        elif action == "broadcast":
            ok = 0
            for oid in db.all_user_ids():
                try:
                    bot.send_message(oid, text, parse_mode="HTML")
                    ok += 1
                except Exception:
                    pass
            bot.reply_to(message, msgs.broadcast_done(ok), parse_mode="HTML")

    # ------------------------------------------------------- auto registro
    @bot.message_handler(func=lambda m: True)
    @safe
    def auto_register(message):
        uid, uname, name = user_of(message)
        register_user(uid, uname, name)

    print(f"[ADRFBOT] bot corriendo como {bot_username or '?'} "
          f"(owner {state['owner']}) — ctrl+c para salir")
    try:
        bot.infinity_polling(skip_pending=True,
                             allowed_updates=["message", "callback_query"])
    except KeyboardInterrupt:
        print("[ADRFBOT] deteniendo bot...")
    except telebot.apihelper.ApiTelegramException as e:
        if "409" in str(e):
            print("[ADRFBOT] ❌ Conflicto: otra instancia del bot esta corriendo")
            print("[ADRFBOT]    Mata la anterior: pkill -9 -f bot.py")
            sys.exit(1)
        raise
    finally:
        try:
            os.remove(os.path.join(BASE_DIR, ".bot.lock"))
        except Exception:
            pass


def _sysinfo() -> str:
    """Info del VPS (Linux). Degrada con gracia en otros SO."""
    try:
        import shutil
        info = []
        # carga
        try:
            with open("/proc/loadavg") as f:
                info.append("⚡ Carga: " + " ".join(f.read().split()[0:3]))
        except Exception:
            pass
        # RAM
        try:
            mem = {}
            with open("/proc/meminfo") as f:
                for line in f:
                    k, v = line.split(":", 1)
                    mem[k.strip()] = int(v.strip().split()[0])  # kB
            total = mem.get("MemTotal", 0) / 1024
            free = mem.get("MemAvailable", mem.get("MemFree", 0)) / 1024
            info.append(f"🧠 RAM: {free:.0f}/{total:.0f} MB libres")
        except Exception:
            pass
        # disco
        try:
            du = shutil.disk_usage("/")
            info.append(f"💽 Disco: {du.free/1e9:.1f}/{du.total/1e9:.1f} GB libres")
        except Exception:
            pass
        # uptime
        try:
            with open("/proc/uptime") as f:
                up = float(f.read().split()[0])
                info.append(f"⏱️ Uptime: {up/86400:.1f} días")
        except Exception:
            pass
        return f"{msgs.LINE}\n🖥️ <b>INFO DEL VPS</b>\n{msgs.LINE}\n" + \
               "\n".join(info) + f"\n{msgs.LINE}"
    except Exception as e:
        return f"⚠️ No se pudo obtener info del sistema: {e}"


if __name__ == "__main__":
    main()
