#!/bin/bash
# ADRFBOT - arranque rapido (bot + servidor)
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 no instalado. Ejecuta ./install.sh"
  exit 1
fi

if [[ ! -f config.json ]]; then
  echo "config.json no existe. Ejecuta ./install.sh"
  exit 1
fi

pkill -f "bot.py" 2>/dev/null || true
pkill -f "server.py" 2>/dev/null || true
sleep 1

nohup python3 "$DIR/bot.py" >> "$DIR/bot.log" 2>&1 &
nohup python3 "$DIR/server.py" >> "$DIR/server.log" 2>&1 &

sleep 2
echo "[ADRFBOT] bot y servidor corriendo"
echo "[ADRFBOT] logs: bot.log / server.log"
