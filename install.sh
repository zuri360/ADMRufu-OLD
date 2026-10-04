#!/bin/bash
# ============================================================
#  ADRFBOT - Instalador (solo lo necesario)
#  Pide: Bot Token, Owner ID (opcional) y puerto.
#  El resto se configura solo con defaults editables en
#  config.json despues.
# ============================================================

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'
msg(){ echo -e "${GREEN}[ADRFBOT]${NC} $1"; }
err(){ echo -e "${RED}[ADRFBOT] ERROR:${NC} $1"; }
ask(){ echo -e -n "${YELLOW}  > $1${NC} "; }

# ---------------------------------------------------------- detectar OS
if [[ -d /data/data/com.termux ]]; then
  OS="termux"
else
  OS="linux"
fi
msg "Sistema: $OS"

# ---------------------------------------------------------- python + deps
if ! command -v python3 >/dev/null 2>&1; then
  msg "Instalando python3..."
  if [[ "$OS" == "termux" ]]; then
    pkg update -y && pkg install -y python git
  else
    apt update -y && apt install -y python3 python3-pip git
  fi
fi
msg "Instalando dependencias..."
pip3 install -q -r requirements.txt

# ---------------------------------------------------------- config previa
OLD_TOKEN=$(python3 - <<'PY' 2>/dev/null || echo ""
import json
try:
    c = json.load(open("config.json"))
    print(c.get("bot_token",""))
except Exception:
    print("")
PY
)
OLD_OWNER=$(python3 - <<'PY' 2>/dev/null || echo 0
import json
try:
    c = json.load(open("config.json"))
    print(c.get("owner_id",0))
except Exception:
    print(0)
PY
)

# ---------------------------------------------------------- bot token
TOKEN="$OLD_TOKEN"
BOTNAME=""
while [[ -z "$BOTNAME" ]]; do
  if [[ -z "$TOKEN" || "$TOKEN" == "TU_BOT_TOKEN" ]]; then
    ask "Bot Token de @BotFather:"
    read -r TOKEN
  fi
  if [[ -z "$TOKEN" ]]; then
    err "Token vacio"
    continue
  fi
  BOTNAME=$(curl -s --max-time 10 "https://api.telegram.org/bot${TOKEN}/getMe" \
    | python3 -c "import sys,json
try:
    d=json.load(sys.stdin)
    print(d['result']['username'] if d.get('ok') else '')
except Exception:
    print('')" 2>/dev/null || true)
  if [[ -z "$BOTNAME" ]]; then
    err "Token invalido o sin internet. Revisa y pegalo de nuevo:"
    TOKEN=""
  else
    msg "Bot OK -> @${BOTNAME}"
  fi
done

# ---------------------------------------------------------- owner id
OWNER="$OLD_OWNER"
ask "Owner ID (Enter = el primero que use el bot sera owner):"
read -r OW
if [[ -n "$OW" ]]; then
  while ! [[ "$OW" =~ ^[0-9]+$ ]]; do
    err "Owner ID debe ser numerico"
    ask "Owner ID (Enter = auto):"
    read -r OW
    [[ -z "$OW" ]] && break
  done
  OWNER="$OW"
fi
[[ -z "$OWNER" || "$OWNER" == "0" ]] && OWNER=0 && msg "Owner en AUTO: el primero que hable sera owner"

# ---------------------------------------------------------- ip publica
IP=$(curl -s --max-time 5 http://ip1.dynupdate.no-ip.com 2>/dev/null | tr -d '[:space:]')
if [[ -z "$IP" ]]; then
  IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null | tr -d '[:space:]')
fi
if [[ -z "$IP" ]]; then
  ask "No se pudo detectar tu IP publica, escribela:"
  read -r IP
fi
msg "IP publica: ${IP:-0.0.0.0}"

# ---------------------------------------------------------- puerto
ask "Puerto del validador (Enter = 8080):"
read -r PORT
[[ -z "$PORT" ]] && PORT=8080
if command -v ss >/dev/null 2>&1 && ss -tln 2>/dev/null | grep -q ":${PORT} "; then
  err "El puerto ${PORT} ya esta en uso"
fi

# ---------------------------------------------------------- escribir config
msg "Guardando config.json..."
python3 - "$TOKEN" "$OWNER" "$IP" "$PORT" "$BOTNAME" <<'PY'
import json, sys
tok, owner, ip, port, bname = sys.argv[1:6]
cfg = {
    "bot_token": tok,
    "owner_id": int(owner or 0),
    "contact": "@BlackHanzoX",
    "brand": "@BlackHanzoX",
    "default_reseller": "@BlackHanzoX",
    "bot_username": ("@" + bname) if bname else "",
    "server_host": "0.0.0.0",
    "server_port": int(port),
    "public_ip": ip or "0.0.0.0",
    "password": "VnBjMnTlL",
    "key_expire_hours": 4,
    "max_keys_per_day": 0,
    "max_fail_attempts": 5,
    "block_minutes": 30,
    "verify_server": True,
    "single_use": True,
    "notify": "user",
    "install_url": "https://raw.githubusercontent.com/rudi9999/ADMRufu/main/install",
    "db_path": "adrfbot.db",
    "log_chat": 0,
}
with open("config.json", "w", encoding="utf-8") as fh:
    json.dump(cfg, fh, indent=2, ensure_ascii=False)
print("OK")
PY

# ---------------------------------------------------------- arranque
chmod +x run.sh
if [[ "$OS" == "linux" ]] && command -v systemctl >/dev/null 2>&1 && [[ $(id -u) -eq 0 ]]; then
  msg "Creando servicios systemd..."
  cat > /etc/systemd/system/adrfbot-bot.service <<EOF
[Unit]
Description=ADRFBOT Telegram Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=$DIR
ExecStart=/usr/bin/python3 $DIR/bot.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  cat > /etc/systemd/system/adrfbot-server.service <<EOF
[Unit]
Description=ADRFBOT Key Validator Server
After=network.target

[Service]
Type=simple
WorkingDirectory=$DIR
ExecStart=/usr/bin/python3 $DIR/server.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable adrfbot-bot adrfbot-server >/dev/null 2>&1 || true
  systemctl restart adrfbot-bot adrfbot-server
  msg "Servicios: adrfbot-bot + adrfbot-server"
else
  msg "Arrancando con nohup..."
  pkill -f "bot.py" 2>/dev/null || true
  pkill -f "server.py" 2>/dev/null || true
  nohup python3 "$DIR/bot.py" >> "$DIR/bot.log" 2>&1 &
  nohup python3 "$DIR/server.py" >> "$DIR/server.log" 2>&1 &
  sleep 2
fi

msg "=============================================================="
msg "  ADRFBOT listo"
msg "  Bot:      @${BOTNAME}"
msg "  Validador: http://${IP:-0.0.0.0}:${PORT}/server.php"
msg "  Owner:    ${OWNER:-AUTO (el primero que hable)}"
msg "  Logs:     bot.log / server.log   (config: config.json)"
msg "=============================================================="
