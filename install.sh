#!/bin/bash
# =====================================================================
#  install.sh - Instalador ADMRufu (fork) de vpsnet360
#
#  Solo instala: dependencias del sistema + archivos del panel desde
#  https://github.com/vpsnet360/ADMRufu/tree/main/ADMRufu/old
#  El menu esta en ADMRufu/old/menu.sh y se instala en /etc/ADMRufu/menu
#
#  Uso:
#    ./install.sh                  instala dependencias y baja lo que falte
#    ./install.sh --actualizar     vuelve a bajar todos los archivos (menu incluido)
#    ./install.sh --instalar <dir> copia old/ desde una carpeta local
# =====================================================================

msg(){
  local R='\e[0m' B='\e[1m'
  local RED='\e[31m' GRN='\e[32m' YEL='\e[33m' BLU='\e[34m' WHT='\033[1;97m' TEAL='\e[36m'
  local BAR='======================================================'
  local BAR3='------------------------------------------------------'
  case $1 in
    -ne)    echo -ne "${RED}${B}${2}${R}";;
    -nama)  echo -ne "${YEL}${B}${2}${R}";;
    -nazu)  echo -ne "${WHT}${2}${R}";;
    -nverd) echo -ne "${GRN}${B}${2}${R}";;
    -ama)   echo -e  "${YEL}${B}${2}${R}";;
    -verm)  echo -e  "${YEL}${B}[!] ${RED}${2}${R}";;
    -verm2) echo -e  "${RED}${B}${2}${R}";;
    -verm3) echo -e  "${RED}${2}${R}";;
    -azu)   echo -e  "${WHT}${2}${R}";;
    -verd)  echo -e  "${GRN}${B}${2}${R}";;
    -teal)  echo -e  "${TEAL}${B}${2}${R}";;
    -blu)   echo -e  "${BLU}${B}${2}${R}";;
    -bra)   echo -e  "\033[1;37m${2}${R}";;
    -bar|-bar2) echo -e "${RED}${BAR}${R}";;
    -bar3)  echo -e  "${RED}${BAR3}${R}";;
    *)      echo -e  "$*";;
  esac
}

print_center(){
  local color="-azu" text line plain pad
  if [[ $1 == -* ]]; then color=$1; shift; fi
  text="$*"
  if [[ $color == -ne ]]; then echo -ne "$text"; return; fi
  while IFS= read -r line; do
    plain=$(echo -e "$line" | sed 's/\x1b\[[0-9;]*m//g')
    pad=$(( (54 - ${#plain}) / 2 )); (( pad < 0 )) && pad=0
    msg "$color" "$(printf '%*s' $pad '')$line"
  done <<< "$(echo -e "$text")"
}

title(){
  local color="-ama"
  if [[ $1 == -* ]]; then color=$1; shift; fi
  clear
  msg -bar
  print_center "$color" "$*"
  msg -bar
}

# locale UTF-8 para que funcionen los sed con acentos de los scripts
locale -a 2>/dev/null | grep -qiE '^(c|en_us)\.utf-?8$' && export LC_ALL=C.UTF-8

# ======================= DESCARGA DESDE TU REPOSITORIO =======================
# Archivos de ADMRufu/old que usa el menu (igual que el install original)
REPO_BASE="https://raw.githubusercontent.com/zuri360/ADMRufu/main/ADMRufu"
REPO_OLD="${REPO_BASE}/old"

ARCHIVOS_OLD="bashrc budp.sh cert.sh chekup.sh chekuser.sh confDNS.sh domain.sh
filebrowser.sh limitador.sh menu_inst.sh PDirect.py PGet.py POpen.py
PPriv.py PPub.py slowdns.sh sockspy.sh swapfile.sh tcpbbr.sh
tool_extras.sh userHWID userSSH userTOKEN userWG.sh
ws-cdn.sh WS-Proxy.js menu.sh"

# destino de cada archivo (mismas reglas que verificar_arq del install.sh)
ruta_arq(){
  case $1 in
    menu.sh) echo "/etc/ADMRufu/menu";;
    menu_inst.sh|tool_extras.sh|chekup.sh|bashrc) echo "/etc/ADMRufu/$1";;
    *) echo "/etc/ADMRufu/install/$1";;
  esac
}

bajar_arq(){
  local f=$1 dst tmp
  dst=$(ruta_arq "$f"); tmp="${dst}.tmp"
  mkdir -p "$(dirname "$dst")"
  if wget -q --no-cache -T 15 -t 2 -O "$tmp" "${REPO_OLD}/${f}" 2>/dev/null || curl -fsSL -m 20 -o "$tmp" "${REPO_OLD}/${f}" 2>/dev/null; then
    if [[ -s $tmp ]] && ! grep -qi '^404: Not Found' "$tmp"; then
      mv -f "$tmp" "$dst"; chmod +x "$dst"; redirigir_repo "$dst"; return 0
    fi
  fi
  rm -f "$tmp"; return 1
}

# descarga generica: bajar_url <url> <destino>
bajar_url(){
  local url=$1 dst=$2 tmp="${2}.tmp"
  mkdir -p "$(dirname "$dst")"
  if wget -q --no-cache -T 20 -t 2 -O "$tmp" "$url" 2>/dev/null || curl -fsSL -m 60 -o "$tmp" "$url" 2>/dev/null; then
    if [[ -s $tmp ]] && ! head -c 20 "$tmp" | grep -qi '404'; then
      mv -f "$tmp" "$dst"; chmod +x "$dst"; redirigir_repo "$dst"; return 0
    fi
  fi
  rm -f "$tmp"; return 1
}

# Los scripts de old/ traen enlaces al repo de rudi9999 (Utils/ y online/).
# Se cambian por tu repo para que las descargas internas
# (badvpn, slowdns, v2ray, etc.) salgan de github.com/vpsnet360/ADMRufu
redirigir_repo(){
  local f
  for f in "$@"; do
    [[ -f $f ]] && grep -Iq . "$f" 2>/dev/null || continue
    grep -q 'rudi9999/ADMRufu' "$f" || continue
    sed -i \
      -e "s#https://github.com/rudi9999/ADMRufu/raw/main/Utils/#${REPO_BASE}/Utils/#g" \
      -e "s#https://github.com/rudi9999/ADMRufu/raw/main/online/#${REPO_BASE}/online/#g" \
      -e "s#https://raw.githubusercontent.com/rudi9999/ADMRufu/main/Utils/#${REPO_BASE}/Utils/#g" \
      -e "s#https://raw.githubusercontent.com/rudi9999/ADMRufu/main/online/#${REPO_BASE}/online/#g" \
      "$f"
  done
}
export -f redirigir_repo

# Dependencias que instalaba el install.sh original (solo las que falten)
check_deps(){
  local cmd pkg falta=()
  for par in unzip:unzip zip:zip lsof:lsof at:at bc:bc jq:jq curl:curl wget:wget \
             nano:nano crontab:cron netstat:net-tools screen:screen socat:socat \
             python3:python3 iptables:iptables cmake:cmake make:make gcc:gcc \
             node:nodejs npm:npm rsyslogd:rsyslog; do
    cmd=${par%%:*}; pkg=${par#*:}
    command -v $cmd &>/dev/null || falta+=($pkg)
  done
  [[ ${#falta[@]} -eq 0 ]] && return
  clear; msg -bar
  print_center -ama "INSTALANDO DEPENDENCIAS"
  msg -bar
  apt-get -o DPkg::Lock::Timeout=300 update -y &>/dev/null
  for pkg in "${falta[@]}"; do
    # instala en segundo plano y muestra un spinner mientras corre
    ( DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y "$pkg" &>/dev/null ) &
    local apid=$! spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
    tput civis 2>/dev/null
    while kill -0 $apid 2>/dev/null; do
      printf "\r \033[1;37m%-14s\033[0m \033[1;33m%s\033[0m instalando..." "$pkg" "${spin:i++%${#spin}:1}"
      sleep 0.1
    done
    wait $apid; local rc=$?
    # reintento si fallo (p.ej. apt estaba ocupado)
    if [[ $rc -ne 0 ]]; then
      sleep 2
      ( DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y "$pkg" &>/dev/null ) &
      apid=$!
      while kill -0 $apid 2>/dev/null; do
        printf "\r \033[1;37m%-14s\033[0m \033[1;33m%s\033[0m reintentando..." "$pkg" "${spin:i++%${#spin}:1}"
        sleep 0.1
      done
      wait $apid; rc=$?
    fi
    tput cnorm 2>/dev/null
    printf "\r\033[K"
    if [[ $rc -eq 0 ]]; then
      printf " \033[1;37m%-14s\033[0m \033[1;32mOK\033[0m\n" "$pkg"
    else
      printf " \033[1;37m%-14s\033[0m \033[1;31mFALLO\033[0m\n" "$pkg"
    fi
  done
  systemctl enable --now atd cron &>/dev/null
  # /var/log/auth.log lo escribe rsyslog; sin el, ONLI no cuenta Dropbear
  systemctl enable --now rsyslog &>/dev/null
  [[ ! -e /var/log/auth.log ]] && touch /var/log/auth.log && chmod 640 /var/log/auth.log
  systemctl restart rsyslog &>/dev/null
  sleep 1
}

# $1 = "forzar" para volver a bajar todo; si no, baja solo lo que falta
descargar_old(){
  local f dst falta=() ok=0 fail=0
  for f in $ARCHIVOS_OLD; do
    dst=$(ruta_arq "$f")
    [[ $1 == forzar || ! -e $dst ]] && falta+=("$f")
  done
  [[ ${#falta[@]} -eq 0 ]] && return 0
  clear
  msg -bar
  print_center -ama "DESCARGANDO ARCHIVOS DEL PANEL"
  print_center -azu "github.com/vpsnet360/ADMRufu"
  msg -bar
  for f in "${falta[@]}"; do
    msg -nazu " $(printf '%-18s' "$f")"
    if bajar_arq "$f"; then msg -verd "OK"; let ok++; else msg -verm2 "FALLO"; let fail++; fi
  done
  msg -bar
  print_center -verd "Descargados: $ok"
  [[ $fail -gt 0 ]] && print_center -verm2 "Fallaron: $fail (revisa conexion o el repositorio)"
  sleep 2
}

instalar_desde(){
  local src="$1" f
  [[ ! -d $src ]] && echo "No existe la carpeta: $src" && exit 1
  for f in $ARCHIVOS_OLD; do
    [[ -e $src/$f ]] && cp -f "$src/$f" "$(ruta_arq "$f")" && chmod +x "$(ruta_arq "$f")" && echo " copiado: $(ruta_arq "$f")"
  done
}

# comandos "menu" y "adm" -> /etc/ADMRufu/menu
set_menu(){
  local menu=/etc/ADMRufu/menu c
  [[ ! -e $menu ]] && return 1
  chmod +x $menu
  for c in menu adm; do
    [[ -e /usr/bin/$c && ! -L /usr/bin/$c && ! -e /usr/bin/$c.original ]] && mv -f /usr/bin/$c /usr/bin/$c.original
    rm -f /usr/bin/$c; ln -s $menu /usr/bin/$c
  done
}

# ======================= INSTALACION =======================
if [[ $(id -u) -ne 0 ]]; then
  echo "Ejecute este instalador como root (sudo su)"
  exit 1
fi

mkdir -p /etc/ADMRufu/install /etc/ADMRufu/tmp /etc/ADMRufu/user /etc/ADMRufu/sbin /etc/ADMRufu/source

case $1 in
  --instalar)
    instalar_desde "$2"
    set_menu
    exit;;
  --actualizar)
    check_deps
    descargar_old forzar;;
  *)
    check_deps
    descargar_old;;
esac

# corrige tambien los archivos que ya estaban instalados
redirigir_repo /etc/ADMRufu/install/* /etc/ADMRufu/menu_inst.sh /etc/ADMRufu/tool_extras.sh

clear
msg -bar
if set_menu; then
  print_center -verd "INSTALACION COMPLETA"
  msg -bar
  print_center -ama "Para abrir el panel escriba: menu"
else
  print_center -verm2 "NO SE PUDO INSTALAR EL MENU"
  msg -bar
  print_center -azu "Revise que exista en su repositorio:\n${REPO_OLD}/menu.sh"
fi
msg -bar
