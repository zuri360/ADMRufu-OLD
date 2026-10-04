"""ADRFBOT — mensajes centralizados (parse_mode=HTML).

Se mantiene el estilo original para los usuarios normales (KeyGen, Menu,
ID, Reseller). El panel del OWNER se rediseña con botones y texto mas
limpios; el resto del diseno se conserva "asi igual".
"""

LINE = "▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰▰"


# --------------------------------------------------------- usuario normal
def start_msg() -> str:
    return (
        f"{LINE}\n"
        "🔐 <b>ADMRufu • Generador Oficial</b>\n"
        f"{LINE}\n"
        "👋 Hola, aun no tienes acceso al sistema.\n\n"
        "🔑 Usa <b>/menu</b> para ver tu panel.\n"
        "🆔 Tu ID con <b>/ID</b> (enviaselo al admin para acceso).\n"
        "📜 Terminos y soporte en el contacto del admin.\n"
        f"{LINE}"
    )


def limit_msg(max_keys: int) -> str:
    return (
        f"⚠️ <b>Limite diario alcanzado</b>\n"
        f"Has generado el maximo de <code>{max_keys}</code> keys hoy.\n"
        "Intenta de nuevo manana."
    )


def menu_msg(user_id, dias, generated, used) -> str:
    return (
        f"{LINE}\n"
        "🧩 <b>MENU PRINCIPAL</b>\n"
        f"{LINE}\n"
        f"🆔 ID: <code>{user_id}</code>\n"
        f"⏳ Dias restantes: <b>{dias}</b>\n"
        f"🗝️ Keys generadas: <b>{generated}</b>\n"
        f"✅ Keys usadas: <b>{used}</b>\n"
        f"{LINE}\n"
        "🔑 <b>/keygen</b> — genera una key\n"
        "♻️ <b>Reseller</b> — tu reseller actual\n"
        "📜 <b>/menu</b> — este panel\n"
        f"{LINE}"
    )


def keygen_msg(reseller, short_id, key, install_cmd, expire_hours) -> str:
    return (
        f"{LINE}\n"
        f"🗝️ <b>KEY GENERADA</b> [{short_id}]\n"
        f"{LINE}\n"
        f"🏷️ Reseller: {reseller}\n"
        f"⏳ Expira en <b>{expire_hours}h</b> o al usarla\n"
        f"{LINE}\n"
        f"🔑 <code>{key}</code>\n"
        f"{LINE}\n"
        "📥 <b>Instalador:</b>\n"
        f"<code>{install_cmd}</code>\n"
        f"{LINE}"
    )


def id_msg(uid) -> str:
    return (
        f"{LINE}\n"
        "🔰 <b>TU ID</b>\n"
        f"{LINE}\n"
        f"🆔 <code>{uid}</code>\n"
        f"{LINE}\n"
        "Envia este ID al admin para solicitar acceso.\n"
        f"{LINE}"
    )


def no_access_id_msg(uid, contact) -> str:
    return (
        f"{LINE}\n"
        "🔰 <b>TU ID</b>\n"
        f"{LINE}\n"
        f"🆔 <code>{uid}</code>\n"
        f"{LINE}\n"
        f"⚠️ Sin acceso. Contacta al admin: {contact}\n"
        "Usa <b>📨 Enviar al admin</b> para solicitar.\n"
        f"{LINE}"
    )


def reseller_msg(reseller) -> str:
    return (
        f"{LINE}\n"
        "♻️ <b>TU RESELLER</b>\n"
        f"{LINE}\n"
        f"🏷️ {reseller}\n"
        f"{LINE}\n"
        "Para cambiarlo usa: <code>/reseller &lt;nombre&gt;</code>\n"
        f"{LINE}"
    )


def used_msg(short_id, cloudrun) -> str:
    return (
        "✅ <b>KEY USADA!!!</b> ✅\n"
        f"🆔 Key: <code>{short_id}</code>\n"
        f"☁️ CloudRun: <code>{cloudrun}</code>"
    )


def invalido_msg() -> str:
    return (
        f"{LINE}\n"
        "⚠️ <b>Comando no reconocido</b>\n"
        "Usa /menu o /ayuda para ver opciones.\n"
        f"{LINE}"
    )


# -------------------------------------------------------------- ayuda
def help_msg(is_owner: bool) -> str:
    t = (
        "📖 <b>AYUDA</b>\n\n"
        "/menu — tu panel\n"
        "/keygen — genera una key\n"
        "/ID — tu ID de telegram\n"
        "/reseller &lt;nombre&gt; — cambia tu reseller\n"
        "/precios — costos de acceso\n"
        "/cupon &lt;codigo&gt; — canjea un cupon\n"
        "/donar — apoyar al proyecto\n"
    )
    if is_owner:
        t += (
            "\n👑 <b>OWNER:</b>\n"
            "/add / dias / remove — gestion de acceso\n"
            "/reseller &lt;id&gt; &lt;nom&gt; — reseller de otro\n"
            "/resellers — lista de resellers\n"
            "/script &lt;url&gt; — script de instalacion\n"
            "/users / keys / stats\n"
            "/banid / uban — banear usuarios\n"
            "/buscar &lt;q&gt; — buscar usuario\n"
            "/block / unblock / blocked — IPs\n"
            "/cupon crear / cupones — cupones\n"
            "/cprecios &lt;dias&gt; &lt;precio&gt; — precios\n"
            "/cache — optimizar BD\n"
            "/infosys — info del VPS\n"
            "/notify &lt;id&gt; &lt;msg&gt; — mensaje a usuario\n"
            "/broadcast &lt;msg&gt; — a todos\n"
        )
    return t


# -------------------------------------------------------------- precios
def prices_msg(prices: dict) -> str:
    t = f"{LINE}\n💰 <b>PRECIOS DE ACCESO</b>\n{LINE}\n"
    if not prices:
        t += "⚠️ Sin precios configurados.\n"
    else:
        for days, price in prices.items():
            t += f"🕓 {days} dias — {price}\n"
    t += f"{LINE}\n💳 Contacto: envia tu comprobante al admin."
    return t


# -------------------------------------------------------------- cupones
def coupon_msg(code, days) -> str:
    return (
        f"{LINE}\n"
        "🎟️ <b>CUPON CANJEADO</b>\n"
        f"{LINE}\n"
        f"🎫 Codigo: <code>{code}</code>\n"
        f"⏳ Dias otorgados: <b>{days}</b>\n"
        "Usa /menu para ver tu acceso.\n"
        f"{LINE}"
    )


def coupon_invalid_msg() -> str:
    return "❌ Cupon invalido o ya usado."


def coupon_used_msg() -> str:
    return "⚠️ Este cupon ya fue agotado."


# --------------------------------------------------------- ban / unban
def banned_user_msg(reason="") -> str:
    r = f"\n📝 Motivo: {reason}" if reason else ""
    return f"🚫 Tu acceso fue revocado por el admin.{r}"


def unbanned_user_msg() -> str:
    return "✅ Tu acceso fue restaurado por el admin."


# ------------------------------------------------------------- busqueda
def search_msg(rows) -> str:
    if not rows:
        return "🔍 Sin resultados."
    t = f"{LINE}\n🔍 <b>RESULTADOS</b>\n{LINE}\n"
    for r in rows[:20]:
        t += (
            f"• <code>{r['user_id']}</code> | "
            f"@{r.get('username') or '-'} | "
            f"reseller: {r.get('reseller') or '-'}\n"
        )
    t += LINE
    return t


# --------------------------------------------------------- resellers
def resellers_msg(rows) -> str:
    if not rows:
        return "♻️ No hay resellers asignados."
    t = f"{LINE}\n♻️ <b>RESELLERS</b>\n{LINE}\n"
    for r in rows:
        t += f"🏷️ {r['reseller']} — {r['cnt']} usuario(s)\n"
    t += LINE
    return t


# ------------------------------------------------------- IPs bloqueadas
def blocked_ips_msg(rows) -> str:
    if not rows:
        return "🚫 No hay IPs bloqueadas."
    t = f"{LINE}\n🚫 <b>IPS BLOQUEADAS</b>\n{LINE}\n"
    for r in rows:
        t += f"• {r['ip']} | {r.get('reason') or '-'} | {r.get('blocked_at')}\n"
    t += LINE
    return t


# ---------------------------------------------------------- estadisticas
def stats_msg(s: dict) -> str:
    return (
        f"{LINE}\n📊 <b>ESTADISTICAS</b>\n{LINE}\n"
        f"👤 Usuarios: <b>{s['users_total']}</b>\n"
        f"🗝️ Keys generadas: <b>{s['keys_total']}</b>\n"
        f"✅ Keys usadas: <b>{s['keys_used']}</b>\n"
        f"{LINE}"
    )


def broadcast_done(ok: int) -> str:
    return f"✅ Mensaje enviado a <b>{ok}</b> usuarios."


# ============================================================ OWNER
# Panel rediseñado: texto claro + botones (ver bot.py -> owner_keyboard)
def owner_panel_msg(s: dict, server: str) -> str:
    return (
        f"{LINE}\n"
        "👑 <b>PANEL DE CONTROL • OWNER</b>\n"
        f"{LINE}\n"
        f"🌐 Servidor: <code>{server}</code>\n"
        f"👤 Usuarios: <b>{s['users_total']}</b>\n"
        f"🗝️ Keys: <b>{s['keys_total']}</b> (usadas {s['keys_used']})\n"
        f"{LINE}\n"
        "🧩 Usa los botones para gestionar el bot.\n"
        "⚙️ <b>Panel Admin</b> abre las herramientas.\n"
        f"{LINE}"
    )


def owner_welcome_msg() -> str:
    return (
        "👑 <b>¡Eres el OWNER!</b>\n"
        "Te di acceso completo. Usa /menu para empezar."
    )
