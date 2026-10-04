#!/bin/bash
# =====================================================================
#  menu.sh - Menu principal ADMRufu (fork) en bash, sin binarios ni licencia
#  Basado en ADMRufu/old/menu
#
#  Los archivos de old/ se descargan de:
#    https://github.com/vpsnet360/ADMRufu/tree/main/ADMRufu/old
#
#  Uso:
#    ./menu.sh                  abre el menu (baja lo que falte)
#    ./menu.sh --actualizar     vuelve a bajar todos los archivos de old/
#    ./menu.sh --set-menu       los comandos "menu" y "adm" abren este script
#    ./menu.sh --instalar <dir> copia old/ desde una carpeta local
# =====================================================================

# ======================= MODULE (reemplazo) =======================
# Funciones de pantalla que el panel original cargaba desde el
# archivo "module" (no incluido en el fork).

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

menu_func(){
  local n=0 opt after
  for opt in "$@"; do
    let n++; after=""
    if [[ $opt == -bar3\ * ]]; then opt="${opt#-bar3 }"; after=1
    elif [[ $opt == -bar\ * ]]; then opt="${opt#-bar }"; after=1; fi
    echo -e " $(msg -verd "[$n]") $(msg -verm2 ">") $(msg -azu "$opt")"
    [[ -n $after ]] && msg -bar3
  done
}

back(){
  msg -bar
  echo -e " $(msg -verd "[0]") $(msg -verm2 ">") $(msg -bra "\033[1;41m VOLVER \033[0m")"
  msg -bar
}

# opcion=$(selection_fun [-color] N) : el prompt va a stderr
selection_fun(){
  local sel max
  [[ $1 == -* ]] && shift
  max=$1
  while :; do
    echo -ne "\e[33m\e[1m Seleccione una opcion: \e[0m" >&2
    read sel
    if [[ $sel =~ ^[0-9]+$ ]] && (( sel >= 0 && sel <= max )); then
      echo "$sel"; return
    fi
    tput cuu1 >&2; tput dl1 >&2
  done
}

del(){ local i; for ((i=0; i<${1:-1}; i++)); do tput cuu1; tput dl1; done; }

enter(){
  msg -bar
  print_center -ama "►► Presione enter para continuar ◄◄"
  read
}

in_opcion(){
  local color="-ne"
  if [[ $1 == -* ]]; then color=$1; shift; fi
  [[ $color == -ne || $color == -nama || $color == -nazu ]] || color=-nama
  msg $color " $1: "
  read opcion
}

in_opcion_down(){
  echo -e " $(msg -verm3 "╭╼╼╼╼╼╼╼╼╼[")$(msg -azu "$1")$(msg -verm3 "]")"
  echo -ne " $(msg -verm3 "╰╼")\033[37;1m> " && read opcion
}

# lolcat es opcional
command -v lolcat &>/dev/null || lolcat(){ cat; }

export -f msg print_center title menu_func back selection_fun del enter in_opcion in_opcion_down
type lolcat 2>/dev/null | grep -q function && export -f lolcat

# locale UTF-8 para que funcionen los sed con acentos de los scripts
locale -a 2>/dev/null | grep -qiE '^(c|en_us)\.utf-?8$' && export LC_ALL=C.UTF-8

# ======================= DESCARGA DESDE TU REPOSITORIO =======================
# Archivos de ADMRufu/old que usa el menu (igual que el install original)
REPO_BASE="https://raw.githubusercontent.com/vpsnet360/ADMRufu/main/ADMRufu"
REPO_OLD="${REPO_BASE}/old"

ARCHIVOS_OLD="bashrc budp.sh cert.sh chekup.sh chekuser.sh confDNS.sh domain.sh
filebrowser.sh limitador.sh menu_inst.sh PDirect.py PGet.py POpen.py
PPriv.py PPub.py slowdns.sh sockspy.sh swapfile.sh tcpbbr.sh
tool_extras.sh userHWID userSSH userTOKEN userWG.sh
ws-cdn.sh WS-Proxy.js"

# destino de cada archivo (mismas reglas que verificar_arq del install.sh)
ruta_arq(){
  case $1 in
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

# ======== comandos que menu_inst.sh llama por nombre ========
# En el original eran binarios de Utils/ instalados en /etc/ADMRufu/sbin
# y enlazados en /usr/bin. Aca:
#  - si existe version bash en tu repo, se usa esa
#  - si no, se baja el binario de tu repo (Utils/...) la primera vez

# usar_bin <nombre> <ruta en repo> [extra:ruta ...]
usar_bin(){
  local name=$1 src=$2 dst=/etc/ADMRufu/sbin/$1 ex n p
  shift 2
  if [[ ! -x $dst ]]; then
    clear; msg -bar
    print_center -ama "DESCARGANDO $name"
    msg -bar
    if ! bajar_url "${REPO_BASE}/${src}" "$dst"; then
      print_center -verm2 "No se pudo descargar:\n${REPO_BASE}/${src}"
      enter; return 1
    fi
    ln -sf "$dst" /usr/bin/$name
    for ex in "$@"; do
      n=${ex%%:*}; p=${ex#*:}
      [[ -x /etc/ADMRufu/sbin/$n ]] || { bajar_url "${REPO_BASE}/${p}" /etc/ADMRufu/sbin/$n && ln -sf /etc/ADMRufu/sbin/$n /usr/bin/$n; }
    done
    del 1
  fi
  "$dst"
}

# [2] SOCKS PYTHON -> old/sockspy.sh (bash)
socksPY(){ run_file ${ADM_inst}/sockspy.sh; return 1; }
# [9] SLOWDNS -> old/slowdns.sh (bash)
Slowdns(){ run_file ${ADM_inst}/slowdns.sh; return 1; }
# [3] SSL -> online/ssl.sh (bash, stunnel)
Stunnel(){
  [[ -e ${ADM_inst}/ssl.sh ]] || bajar_url "${REPO_BASE}/online/ssl.sh" ${ADM_inst}/ssl.sh
  run_file ${ADM_inst}/ssl.sh; return 1
}
# [16] BANNER SSH -> funcion baner_fun de menu_inst.sh (bash)
banner(){
  if declare -F baner_fun &>/dev/null; then baner_fun; else usar_bin banner Utils/banner/banner; fi
  return 1
}
# sin version bash: binarios de tu repo
dropBear(){ usar_bin dropBear Utils/dropBear/dropBear; return 1; }
epro-ws(){ usar_bin epro-ws Utils/epro-ws/epro-ws; return 1; }
aToken-mng(){ usar_bin aToken-mng Utils/aToken/aToken-mng; return 1; }

export -f bajar_url usar_bin socksPY Slowdns Stunnel banner dropBear epro-ws aToken-mng


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
             node:nodejs npm:npm; do
    cmd=${par%%:*}; pkg=${par#*:}
    command -v $cmd &>/dev/null || falta+=($pkg)
  done
  [[ ${#falta[@]} -eq 0 ]] && return
  clear; msg -bar
  print_center -ama "INSTALANDO DEPENDENCIAS"
  msg -bar
  apt-get update -y &>/dev/null
  for pkg in "${falta[@]}"; do
    msg -nazu " $(printf '%-18s' "$pkg")"
    if DEBIAN_FRONTEND=noninteractive apt-get install -y $pkg &>/dev/null; then msg -verd "OK"; else msg -verm2 "FALLO"; fi
  done
  systemctl enable --now atd cron &>/dev/null
  sleep 1
}

# ======== [9] PROTOCOLOS UDP (version bash) ========
# El binario protocolsUDP original exige licencia (/etc/ADMRufuLIC) y se
# cierra al instante. Esta version instala UDP-CUSTOM (ePro) con el
# servidor de tu repo: Utils/udp-custom/dev/udp-custom
# Usa las mismas cuentas SSH del panel (usuario/contraseña).
protocolsUDP(){
  local dir=/etc/ADMRufu/bin
  local bin=$dir/udp-custom conf=$dir/config.json
  local excl=$dir/udpcustom.exclude
  local svc=/etc/systemd/system/udpcustom.service

  udp_estado(){
    if [[ $(systemctl is-active udpcustom 2>/dev/null) = active ]]; then msg -verd "[ON]"; else msg -verm2 "[OFF]"; fi
  }

  udp_instalar(){
    title -ama "INSTALADOR UDP-CUSTOM"
    msg -nazu " Descargando servidor udp-custom... "
    if bajar_url "${REPO_BASE}/Utils/udp-custom/dev/udp-custom" $bin; then
      msg -verd "OK"
    else
      msg -verm2 "FALLO"
      print_center -ama "${REPO_BASE}/Utils/udp-custom/dev/udp-custom"
      enter; return
    fi
    cat > $conf <<CONF
{
  "listen": ":36712",
  "stream_buffer": 33554432,
  "receive_buffer": 83886080,
  "auth": {
    "mode": "passwords"
  }
}
CONF
    # udp-custom crea su propia regla iptables; aca solo se excluyen puertos
    [[ -s $excl ]] || echo "53,5300" > $excl
    cat > $svc <<SVC
[Unit]
Description=UDP-Custom (ePro Dev. Team)
After=network.target

[Service]
User=root
Type=simple
WorkingDirectory=$dir/
ExecStart=/bin/bash -c '$bin server --exclude "\$\$(cat $excl)"'
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVC
    systemctl daemon-reload
    systemctl enable udpcustom &>/dev/null
    systemctl restart udpcustom
    sleep 2
    msg -bar
    if [[ $(systemctl is-active udpcustom) = active ]]; then
      print_center -verd "UDP-CUSTOM INSTALADO E INICIADO"
      msg -bar
      print_center -ama "En HTTP Custom usa:\nIP:1-65535@usuario:contraseña\n(las cuentas SSH del panel)"
    else
      print_center -verm2 "EL SERVICIO NO INICIO"
      print_center -ama "Revisa con: journalctl -u udpcustom -n 30"
    fi
    enter
  }

  udp_excluir(){
    title -ama "PUERTOS EXCLUIDOS DE UDP-CUSTOM"
    print_center -azu "Actual: $(cat $excl)"
    msg -bar
    print_center -ama "UDP-Custom toma todos los puertos UDP\nmenos estos. Ej: 53,5300,7300"
    msg -bar
    in_opcion_down "Puertos separados por coma (enter = no cambiar)"
    [[ -z $opcion ]] && return
    if [[ ! $opcion =~ ^[0-9]+(,[0-9]+)*$ ]]; then
      print_center -verm2 "Formato invalido"; enter; return
    fi
    echo "$opcion" > $excl
    systemctl restart udpcustom
    print_center -verd "Puertos excluidos actualizados"; enter
  }

  udp_desinstalar(){
    title -verm "DESINSTALAR UDP-CUSTOM"
    in_opcion -nama "Seguro? [S/N]"
    [[ $opcion != @(s|S|y|Y) ]] && return
    systemctl stop udpcustom &>/dev/null
    systemctl disable udpcustom &>/dev/null
    rm -f $svc $bin $conf $excl
    systemctl daemon-reload
    print_center -verd "UDP-CUSTOM DESINSTALADO"; enter
  }

  while :; do
    title -ama "MENU DE PROTOCOLOS UDP"
    if [[ ! -e $svc ]]; then
      echo -e " $(msg -verd "[1]") $(msg -verm2 ">") $(msg -azu "INSTALAR UDP-CUSTOM (HTTP Custom)")"
      back
      case $(selection_fun 1) in
        1) udp_instalar;;
        0) return 1;;
      esac
      continue
    fi
    echo -e " $(msg -azu "UDP-CUSTOM:") $(udp_estado)  $(msg -azu "PUERTO:") $(msg -verd "36712")"
    echo -e " $(msg -azu "EXCLUIDOS:") $(msg -ama "$(cat $excl 2>/dev/null)")"
    msg -bar
    menu_func "INICIAR / DETENER" "REINICIAR" "PUERTOS EXCLUIDOS" "EDITAR CONFIG (NANO)" "$(msg -verm2 "DESINSTALAR UDP-CUSTOM")"
    back
    case $(selection_fun 5) in
      1) if [[ $(systemctl is-active udpcustom) = active ]]; then systemctl stop udpcustom; else systemctl start udpcustom; fi; sleep 1;;
      2) systemctl restart udpcustom; sleep 1;;
      3) udp_excluir;;
      4) nano $conf; systemctl restart udpcustom;;
      5) udp_desinstalar;;
      0) return 1;;
    esac
  done
}
export -f protocolsUDP

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

set_menu(){
  local self=/etc/ADMRufu/menu
  [[ "$(readlink -f "$0")" != "$self" ]] && cp -f "$(readlink -f "$0")" $self && chmod +x $self
  for c in menu adm; do
    [[ -e /usr/bin/$c && ! -e /usr/bin/$c.original ]] && mv -f /usr/bin/$c /usr/bin/$c.original
    rm -f /usr/bin/$c; ln -s $self /usr/bin/$c
  done
  [[ $1 != -q ]] && echo "Ahora los comandos 'menu' y 'adm' abren $self"
  [[ $1 != -q ]] && echo "(los anteriores quedaron como /usr/bin/menu.original y /usr/bin/adm.original)"
}

if [[ $(id -u) -eq 0 ]]; then
  mkdir -p /etc/ADMRufu/install /etc/ADMRufu/tmp /etc/ADMRufu/user
  case $1 in
    --actualizar) descargar_old forzar; exit;;
    --instalar)   instalar_desde "$2"; exit;;
    --set-menu)   set_menu; exit;;
  esac
  mkdir -p /etc/ADMRufu/sbin /etc/ADMRufu/source
  # fija el comando "menu"/"adm" la primera vez, sin pedir --set-menu aparte
  [[ ! -L /usr/bin/menu || "$(readlink -f /usr/bin/menu)" != /etc/ADMRufu/menu ]] && set_menu -q
  check_deps
  # al abrir el menu se descargan automaticamente los archivos que falten
  descargar_old
  # corrige tambien los archivos que ya estaban instalados
  redirigir_repo /etc/ADMRufu/install/* /etc/ADMRufu/menu_inst.sh /etc/ADMRufu/tool_extras.sh
fi

# ======================= FIN MODULE =======================

# ======================= MENU (old/menu) =======================
rm -rf instalscript.sh &>/dev/null

for i in $@; do
		case $i in
			-c|--comando) cmd=$2; shift 2; $cmd;;
		esac
done

export _hora=$(printf '%(%H:%M:%S)T') 
export _fecha=$(printf '%(%D)T')

export ADMRufu="/etc/ADMRufu" && [[ ! -d ${ADMRufu} ]] && mkdir ${ADMRufu}
export ADM_inst="${ADMRufu}/install" && [[ ! -d ${ADM_inst} ]] && mkdir ${ADM_inst}
export ADM_bin="${ADMRufu}/bin" && [[ ! -d ${ADM_bin} ]] && mkdir ${ADM_bin}
export ADM_src="${ADMRufu}/source" && [[ ! -d ${ADM_src} ]] && mkdir ${ADM_src}
export ADM_crt="${ADM_src}/cert" && [[ ! -d ${ADM_crt} ]] && mkdir ${ADM_crt}
export ADM_slow="${ADM_src}/slowdns" && [[ ! -d ${ADM_slow} ]] && mkdir ${ADM_slow}
export ADM_user="${ADMRufu}/user" && [[ ! -d ${ADM_user} ]] && mkdir ${ADM_user}
export ADM_tmp="${ADMRufu}/tmp" && [[ ! -d ${ADM_tmp} ]] && mkdir ${ADM_tmp}
export numero='^[0-9]+$'
export letra='^[A-Za-z]+$'
export tx_num='^[A-Za-z0-9]+$'

export v2rdir="${ADMRufu}/v2r" && [[ ! -d ${v2rdir} ]] && mkdir ${v2rdir}
export user_conf="${v2rdir}/user" && [[ ! -e $user_conf ]] && touch $user_conf
export backdir="${v2rdir}/back" && [[ ! -d ${backdir} ]] && mkdir ${backdir}
export tmpdir="$backdir/tmp"
export config="/etc/v2ray/config.json"
export temp="/etc/v2ray/temp.json"
export fstab="/etc/fstab"
export sysctl="/etc/sysctl.conf"
export swap="/swapfile"

#========================

#PROCESSADOR
export _core=$(printf '%-1s' "$(grep -c cpu[0-9] /proc/stat)")
export _usop=$(printf '%-1s' "$(top -bn1 | awk '/Cpu/ { cpu = "" 100 - $8 "%" }; END { print cpu }')")

#SISTEMA-USO DA CPU-MEMORIA RAM
export ram1=$(free -h | grep -i mem | awk {'print $2'})
export ram2=$(free -h | grep -i mem | awk {'print $4'})
export ram3=$(free -h | grep -i mem | awk {'print $3'})

export _ram=$(printf ' %-9s' "$(free -h | grep -i mem | awk {'print $2'})")
export _usor=$(printf '%-8s' "$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }')")

if [[ ! -f ${ADM_tmp}/style ]]; then
  echo -e "infsys 1\ninfsys2 0\nport 0\nport2 1\nresel 1\ncontador 1\nlimit 0" > ${ADM_tmp}/style
fi

if [[ ! $(id -u) = 0 ]]; then
	clear
	msg -bar
	print_center -ama "ERROR DE EJECUCION"
	msg -bar
	print_center -ama "DEVE EJECUTAR DESDE EL USUSRIO ROOT"
	echo ''
	print_center -ama 'TAMBIEN "sudo su"'
	print_center -ama 'O BIEN'
	print_center -ama '"sudo menu"'
	msg -bar
	exit
fi

if [[ ! $(cat '/etc/passwd'|grep 'root'|grep -v 'false'|grep -v 'sys-bin'|awk -F ':' '{print $2}') = 'x' ]]; then
	msg -bar
	print_center -ama 'CAMBIO DE CONTRASEÑA ROOT REQUERIDO'
	msg -bar
	msg -ne " Ingrese la Nueva Contraseña: "
	read opcion
	pwconv
	(echo "$opcion" ; echo "$opcion")|passwd root &>/dev/null
	tput cuu1 && tput dl1
	print_center -verd "SE CAMBIO LA CONTRASEÑA ROOT"
	enter
fi

[[ ! -e "/var/spool/cron/crontabs/root" ]] && touch /var/spool/cron/crontabs/root

#======BODY=========

 in_opcion2(){
 	msg -ne " $1: "
 	read opcion
 }

fun_trans(){ 
	local texto
	local retorno
	declare -A texto
	SCPidioma="${ADM_tmp}/idioma"
	[[ ! -e ${SCPidioma} ]] && touch ${SCPidioma}
	local LINGUAGE=$(cat ${SCPidioma})
	[[ -z $LINGUAGE ]] && LINGUAGE=es
	[[ $LINGUAGE = "es" ]] && echo "$@" && return
	[[ ! -e /usr/bin/trans ]] && wget -O /usr/bin/trans https://raw.githubusercontent.com/rudi9999/VPS-MX-8.0/master/ArchivosUtilitarios/trans &> /dev/null
	[[ ! -e ${ADM_tmp}/texto-adm ]] && touch ${ADM_tmp}/texto-adm
	source ${ADM_tmp}/texto-adm
	if [[ -z "$(echo ${texto[$@]})" ]]; then
		#ENGINES=(aspell google deepl bing spell hunspell apertium yandex)
		#NUM="$(($RANDOM%${#ENGINES[@]}))"
		retorno="$(source trans -e bing -b es:${LINGUAGE} "$@"|sed -e 's/[^a-z0-9 -]//ig' 2>/dev/null)"
		echo "texto[$@]='$retorno'"  >> ${ADM_tmp}/texto-adm
		echo "$retorno"
	else
		echo "${texto[$@]}"
	fi
}

# original: "cmd -p MOD" (binario con licencia). Version en bash:
mine_port(){
	local data
	data=$(ss -H -tlnp 2>/dev/null | awk '{for(f=1;f<=NF;f++) if($f ~ /:[0-9]+$/){n=split($f,a,":"); port=a[n]; break}; p="?"; if (match($0,/users:\(\("[^"]+"/)) {p=substr($0,RSTART+9,RLENGTH-10)} print p, port}' | sort -u -k1,1 -k2,2n)
	if [[ -z $data ]]; then
		data=$(lsof -V -i tcp -P -n 2>/dev/null | grep LISTEN | awk '{n=split($9,a,":"); print $1, a[n]}' | sort -u -k1,1 -k2,2n)
	fi
	[[ -z $data ]] && print_center -verm2 "SIN PUERTOS ACTIVOS" && return
	print_center -ama "PUERTOS ACTIVOS"
	echo "$data" | awk '{if(!s[$1]++) o[++k]=$1; p[$1]=p[$1] (p[$1]?" ":"") $2} END{for(i=1;i<=k;i++) print o[i], p[o[i]]}' | while read name ports; do
		echo -e " $(msg -verd "$(printf '%-12s' "${name:0:12}")") $(msg -verm2 ">") $(msg -azu "$ports")"
	done
}

ofus () {
  unset server
  server=$(echo ${txt_ofuscatw}|cut -d':' -f1)
  unset txtofus
  number=$(expr length $1)
  for((i=1; i<$number+1; i++)); do
    txt[$i]=$(echo "$1" | cut -b $i)
    case ${txt[$i]} in
      ".")txt[$i]="*";;
      "*")txt[$i]=".";;
      "_")txt[$i]="@";;
      "@")txt[$i]="_";;
      #"1")txt[$i]="@";;
      #"@")txt[$i]="1";;
      #"2")txt[$i]="?";;
      #"?")txt[$i]="2";;
      #"4")txt[$i]="%";;
      #"%")txt[$i]="4";;
      "-")txt[$i]="K";;
      "K")txt[$i]="-";;
      "1")txt[$i]="f";;
      "2")txt[$i]="e";;
      "3")txt[$i]="d";;
      "4")txt[$i]="c";;
      "5")txt[$i]="b";;
      "6")txt[$i]="a";;
      "7")txt[$i]="9";;
      "8")txt[$i]="8";;
      "9")txt[$i]="7";;
      "a")txt[$i]="6";;
      "b")txt[$i]="5";;
      "c")txt[$i]="4";;
      "d")txt[$i]="3";;
      "e")txt[$i]="2";;
      "f")txt[$i]="1";;
    esac
    txtofus+="${txt[$i]}"
  done
  echo "$txtofus" | rev
}

fun_bar(){
	comando="$1"
	txt="$2"
	_=$(
	$comando > /dev/null 2>&1
	) & > /dev/null
	pid=$!
	while [[ -d /proc/$pid ]]; do
		echo -ne " \033[1;33m$txt["
		for((i=0; i<10; i++)); do
			echo -ne "\033[1;31m##"
			sleep 0.2
		done
		echo -ne "\033[1;33m]"
		sleep 1s
		echo
		tput cuu1 && tput dl1
	done
	echo -e " \033[1;33m$txt[\033[1;31m####################\033[1;33m] - \033[1;32m100%\033[0m"
	sleep 1s
}

fun_ip(){
  if [[ -e ${ADM_tmp}/ip_nat && -e ${ADM_tmp}/ip_publica  ]]; then
  	case $1 in
  		nat)	echo "$(cat ${ADM_tmp}/ip_nat)";;
  			*)	echo "$(cat ${ADM_tmp}/ip_publica)";;
  	esac 
  else
  	ip_nat=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n 1p)	
		ip_publica=$(grep -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' <<< "$(wget -T 10 -t 1 -4qO- "http://ip1.dynupdate.no-ip.com/" || curl -m 10 -4Ls "http://ip1.dynupdate.no-ip.com/")")
		ip_publica=$([[ -n "$ip_publica" ]] && echo "$ip_publica" || echo "$ip_nat")
    echo "$ip_nat" > ${ADM_tmp}/ip_nat
    echo "$ip_publica" > ${ADM_tmp}/ip_publica
    case $1 in
  		nat)	echo "$ip_nat";;
  			*)	echo "$ip_publica";;
  	esac
  fi
}

fun_eth(){
	eth=$(ifconfig | grep -v inet6 | grep -v lo | grep -v 127.0.0.1 | grep "encap:Ethernet" | awk '{print $1}')
    [[ $eth != "" ]] && {
    	msg -bar
    	msg -ama " $(fun_trans "Aplicar el sistema para mejorar los paquetes SSH?")"
    	msg -ama " $(fun_trans "Opciones para usuarios avanzados")"
    	msg -bar
    	read -p " [S/N]: " -e -i n sshsn
    	[[ "$sshsn" = @(s|S|y|Y) ]] && {
    		echo -e "${cor[1]} $(fun_trans "Correccion de problemas de paquetes en SSH ...")"
            echo -e " $(fun_trans "¿Cual es la tasa RX?")"
            echo -ne "[ 1 - 999999999 ]: "; read rx
            [[ "$rx" = "" ]] && rx="999999999"
            echo -e " $(fun_trans "¿Cual es la tasa TX?")"
            echo -ne "[ 1 - 999999999 ]: "; read tx
            [[ "$tx" = "" ]] && tx="999999999"
            apt-get install ethtool -y > /dev/null 2>&1
            ethtool -G $eth rx $rx tx $tx > /dev/null 2>&1
        }
        msg -bar
    }
}

mportas2(){
	unset portas
	portas_var=$(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" |grep -v "COMMAND" | grep "LISTEN")
	while read port; do
		var1=$(echo $port | awk '{print $1}') && var2=$(echo $port | awk '{print $9}' | awk -F ":" '{print $2}')
		[[ "$(echo -e $portas|grep "$var1 $var2")" ]] || portas+="$var1 $var2\n"
	done <<< "$portas_var"
	i=1
	echo -e "$portas"
}

mportas(){
	unset portas
	portas_var=$(lsof -V -i -P -n | grep -v "ESTABLISHED" |grep -v "COMMAND")
	while read port; do
		var1=$(echo $port | awk '{print $1}') && var2=$(echo $port | awk '{print $9}' | awk -F ":" '{print $2}')
		[[ "$(echo -e $portas|grep "$var1 $var2")" ]] || portas+="$var1 $var2\n"
	done <<< "$portas_var"
	i=1
	echo -e "$portas"
}


os_system(){
	system=$(cat /etc/issue|grep 'Ubuntu\|Debian')
	distro=$(echo "$system"|awk '{print $1}')
	case $distro in
		Ubuntu)echo $system|awk '{print $1, $2}';;
		Debian)echo $system|awk '{print $1, $3}';;
			 *)echo $system|awk '{print $1}';;
	esac
}

reiniciar_vps () {
  echo -ne " \033[1;31m[ ! ] Sudo Reboot"
  sleep 3s
  echo -e "\033[1;32m [OK]"
  (
    sudo reboot
    ) > /dev/null 2>&1
  msg -bar
  return
}

# Menu Ferramentas
systen_info(){
  msg -ama "$(fun_trans "DETALLES DEL SISTEMA")"
  null="\033[1;31m"
  msg -bar
  if [ ! /proc/cpuinfo ]; then msg -verm "$(fun_trans "Sistema No Soportado")" && msg -bar; return 1; fi
  if [ ! /etc/issue.net ]; then msg -verm "$(fun_trans "Sistema No Soportado")" && msg -bar; return 1; fi
  if [ ! /proc/meminfo ]; then msg -verm "$(fun_trans "Sistema No Soportado")" && msg -bar; return 1; fi
  totalram=$(free | grep Mem | awk '{print $2}')
  usedram=$(free | grep Mem | awk '{print $3}')
  freeram=$(free | grep Mem | awk '{print $4}')
  swapram=$(cat /proc/meminfo | grep SwapTotal | awk '{print $2}')
  system=$(cat /etc/issue.net)
  clock=$(lscpu | grep "CPU MHz" | awk '{print $3}')
  based=$(cat /etc/*release | grep ID_LIKE | awk -F "=" '{print $2}')
  processor=$(cat /proc/cpuinfo | grep "model name" | uniq | awk -F ":" '{print $2}')
  cpus=$(cat /proc/cpuinfo | grep processor | wc -l)
  [[ "$system" ]] && msg -ama "$(fun_trans "Sistema"): ${null}$system" || msg -ama "$(fun_trans "Sistema"): ${null}???"
  [[ "$based" ]] && msg -ama "$(fun_trans "Base"): ${null}$based" || msg -ama "$(fun_trans "Base"): ${null}???"
  [[ "$processor" ]] && msg -ama "$(fun_trans "Procesador"): ${null}$processor x$cpus" || msg -ama "$(fun_trans "Procesador"): ${null}???"
  [[ "$clock" ]] && msg -ama "$(fun_trans "Frecuencia de Operacion"): ${null}$clock MHz" || msg -ama "$(fun_trans "Frecuencia de Operacion"): ${null}???"
  msg -ama "$(fun_trans "Uso del Procesador"): ${null}$(ps aux  | awk 'BEGIN { sum = 0 }  { sum += sprintf("%f",$3) }; END { printf " " "%.2f" "%%", sum}')"
  msg -ama "$(fun_trans "Memoria Virtual Total"): ${null}$(($totalram / 1024))"
  msg -ama "$(fun_trans "Memoria Virtual En Uso"): ${null}$(($usedram / 1024))"
  msg -ama "$(fun_trans "Memoria Virtual Libre"): ${null}$(($freeram / 1024))"
  msg -ama "$(fun_trans "Memoria Virtual Swap"): ${null}$(($swapram / 1024))MB"
  msg -ama "$(fun_trans "Tempo Online"): ${null}$(uptime)"
  msg -ama "$(fun_trans "Nombre De La Maquina"): ${null}$(hostname)"
  msg -ama "$(fun_trans "IP De La  Maquina"): ${null}$(ip addr | grep inet | grep -v inet6 | grep -v "host lo" | awk '{print $2}' | awk -F "/" '{print $1}')"
  msg -ama "$(fun_trans "Version de Kernel"): ${null}$(uname -r)"
  msg -ama "$(fun_trans "Arquitectura"): ${null}$(uname -m)"
  msg -bar
  return 0
}

# Menu Instalaciones
pid_inst(){
	[[ $1 = "" ]] && echo -e "\033[1;31m[OFF]" && return 0
	unset portas
	portas_var=$(lsof -V -i -P -n | grep -v "ESTABLISHED" |grep -v "COMMAND")
	i=0
	while read port; do
		var1=$(echo $port | awk '{print $1}') && var2=$(echo $port | awk '{print $9}' | awk -F ":" '{print $2}')
		[[ "$(echo -e ${portas[@]}|grep "$var1 $var2")" ]] || {
			portas[$i]="$var1 $var2\n"
			let i++
		}
	done <<< "$portas_var"
	[[ $(echo "${portas[@]}"|grep "$1") ]] && echo -e "\033[1;32m[ON]" || echo -e "\033[1;31m[OFF]"
}

info_sys(){
	#v=$(date '+%s' -d $(cat $ADMRufu/vercion)))
	info_so=$(printf '%-17s' "$(os_system)")
	info_ip=$(printf '%-18s' "$(fun_ip)")
	info_ram1=$(printf '%-7s' "${ram1}")
	info_ram2=$(printf '%-7s' "${ram2}")
	info_ram3=$(printf '%-7s' "${ram3}")
	info_fecha=$(printf '%-15s' "${_fecha}")
	info_hora=$(printf '%-15s' "${_hora}")

	systema=$(printf '%-23s' 'SISTEMA')
	systema+=$(printf '%-16s' 'MEMORIA')
	systema+='PROCESADOR'

	msg -verd " $systema"

	echo -e " $(msg -teal "S.O:") $(msg -azu "$info_so") $(msg -teal "RAM:")    $(msg -verd "$info_ram1") $(msg -teal "CPU:") $(msg -verd "$_core")"
	echo -e " $(msg -teal "IP:") $(msg -azu "$info_ip") $(msg -teal "USADA:")  $(msg -verd "$info_ram3") $(msg -teal "EN USO:")$(msg -verd "$_usop")"
	echo -e " $(msg -teal "FECHA:") $(msg -azu "$info_fecha") $(msg -teal "LIBRE:")  $(msg -verd "$info_ram2")"
	echo -e " $(msg -teal "HORA:")  $(msg -azu "$info_hora") $(msg -teal "EN USO:") $(msg -verd "$_usor")"
}

cabesera(){
	msg -bar
	print_center -azu "=====>>>> ADMRufu <<<<====="|lolcat
	msg -bar
}

droppids(){
  port_dropbear=`ps aux|grep 'dropbear'|awk NR==1|awk '{print $17;}'`

  log=/var/log/auth.log
  loginsukses='Password auth succeeded'

  pids=`ps ax|grep 'dropbear'|grep " $port_dropbear"|awk -F " " '{print $1}'`

  for pid in $pids; do
    pidlogs=`grep $pid $log |grep "$loginsukses" |awk -F" " '{print $3}'`

    i=0
    for pidend in $pidlogs; do
      let i=i+1
    done

    if [ $pidend ];then
       login=`grep $pid $log |grep "$pidend" |grep "$loginsukses"`
       PID=$pid
       user=`echo $login |awk -F" " '{print $10}' | sed -r "s/'/ /g"`
       waktu=`echo $login |awk -F" " '{print $2"-"$1,$3}'`
       while [ ${#waktu} -lt 13 ]; do
           waktu=$waktu" "
       done
       while [ ${#user} -lt 16 ]; do
           user=$user" "
       done
       while [ ${#PID} -lt 8 ]; do
           PID=$PID" "
       done
       echo "$user $PID $waktu"
    fi
done
}

contador(){
	users=$(cat /etc/passwd|grep 'home'|grep 'false'|grep -v 'syslog'|awk -F ':' '{print $1}')
	dpids=$(droppids)
	time=$(date +%s)
	[[ -e /etc/openvpn/openvpn-status.log ]] && ovpn_log=$(cat /etc/openvpn/openvpn-status.log)

	#n='0'
	#i='0'
	conect='0'
	for _user in $users; do
		[[ -z "$(ps -u $_user|grep sshd)" ]] && sqd=0 || sqd=1
		[[ -z "$(echo $ovpn_log|grep -E ,"$_user",)" ]] && ovp=0 || ovp=1
        [[ -z "$(echo $dpids|grep -w "$_user")" ]] && drop=0 || drop=1

        conex=$(($sqd + $ovp + $drop))
        [[ $conex -ne 0 ]] && let conect++

		#if [[ $(chage -l $_user |grep 'Account expires' |awk -F ': ' '{print $2}') != never ]]; then
		#	[[ $time -gt $(date '+%s' -d "$(chage -l $_user |grep "Account expires" |awk -F ': ' '{print $2}')") ]] && let n++
		#fi

		#[[ $(passwd --status $_user|cut -d ' ' -f2) = "L" ]] && let i++
	done

	# original: user-info -a (binario). Version en bash:
	n=0; i=0
	for _user in $users; do
		_exp=$(chage -l $_user 2>/dev/null|grep 'Account expires'|awk -F ': ' '{print $2}')
		if [[ -n $_exp && $_exp != never ]]; then
			[[ $time -gt $(date '+%s' -d "$_exp") ]] && let n++
		fi
		[[ $(passwd --status $_user|cut -d ' ' -f2) = "L" ]] && let i++
	done

	_onlin=$(printf '%-7s' "$conect")
	_userexp=$(printf '%-7s' "$n")
	_lok=$(printf '%-7s' "$i")
	_tuser=$(echo "$users"|sed '/^$/d'|wc -l)

	echo -e " $(msg -verd "ONLI:") $(msg -azu "$_onlin") $(msg -verm2 "EXP:") $(msg -azu "$_userexp") $(msg -teal "LOK:") $(msg -azu "$_lok") $(msg -ama "TOTAL:") $(msg -azu "$_tuser")"
}

lou(){
  source <(echo -e "$(cat /etc/bash.bashrc)\nTMOUT=1")
}

ULK_ALF(){
	title "Desactivar contraseñas Alfanumericas"
	msg -ama " Esto desactivara el uso de contraseñas Alfanumericas\n en vps de VULTR, y otros. Permitiendo usar cualquier\n combinacion de caracteres mayor a 4 digitos."
	msg -bar
	msg -ne " Continuar? [S/N]: "
	read opcion
	[[ "$opcion" != @(s|S|y|Y) ]] && return
	tput cuu1 && tput dl1
	apt-get install libpam-cracklib -y > /dev/null 2>&1
	echo -e '#
password [success=1 default=ignore] pam_unix.so obscure sha512
password requisite pam_deny.so
password required pam_permit.so' > /etc/pam.d/common-password
    chmod +x /etc/pam.d/common-password
    print_center -verd "Contraseña Alfanumerica Desactivada"
    msg -bar
    print_center -ama "►► Presione enter para continuar ◄◄"
    read
}

backup(){

	bkusr(){
    all_user=$(cat /etc/passwd|grep 'home'|grep 'false'|grep -v 'syslog')
    all_name=('' $(echo "$all_user"|awk -F ':' '{print $1}'))
		clear
		msg -bar
		if [[ -z ${all_name[@]} ]]; then
			print_center -ama "No se encontraron usuarios"
			msg -bar
			enter
			return
		fi
		print_center -ama "CREANDO COPIA DE SEGURIDAD"
		msg -bar
		sleep 2
		local userback
		for u in `echo ${all_name[@]}`; do
      dat=$(echo "$all_user"|grep -w "$u"|cut -d ':' -f5)
      Limit_mode=$(echo "$dat"|cut -d ',' -f1)
      case $Limit_mode in
        token)pass=$(cat ${ADM_user}/passwd_token);;
         hwid)pass="$u";;
            *)pass=$(echo "$dat"|cut -d ',' -f2);;
      esac
			fecha=$(chage -l "$u"|sed -n '4p'|awk -F ': ' '{print $2}')
			EXPTIME="$(($(($(date '+%s' -d "${fecha}") - $(date +%s))) / 86400))"
			stat=$(passwd --status $u|cut -d ' ' -f2)
      userback+="$u|$pass|$EXPTIME|$dat|$stat\n"
		done
		echo -e "$userback" > ${ADM_tmp}/userback.txt
    echo -e "$userback" > /root/userback.txt
		openssl enc -aes-128-cbc -salt -in ${ADM_tmp}/userback.txt -pass pass:ADMRufu -out ${ADM_tmp}/userback.enc > /dev/null 2>&1
		mv ${ADM_tmp}/userback.enc /root/user_$(printf '%(%d-%m-%y_%H:%M:%S)T').ADMRufu
		rm ${ADM_tmp}/userback.txt
		print_center -verd "Copia de seguridad creada."
		enter
		return
	}

  restor(){
    openssl enc -aes-128-cbc -d -in ${ADM_tmp}/userback.enc -pass pass:ADMRufu -out ${ADM_tmp}/userback.txt &>/dev/null 2>&1
    msg -nama " Eliminar todos los usuarios? [S/N]: " && read del_all
    [[ "$del_all" != @(S|s) ]] && msg -nama " Sobrescrivir usuarios exixtentes? [S/N]: " && read reset_user
    all_user=$(cat /etc/passwd|grep 'home'|grep 'false'|grep -v 'syslog')
    if [[ "$del_all" = @(S|s) ]]; then
      service dropbear stop &>/dev/null
      service sshd stop &>/dev/null
      service ssh stop &>/dev/null
      service stunnel4 stop &>/dev/null
      service squid stop &>/dev/null
      title -ama "ELIMINADO TODOS LO USUARIOS...."
      for user_d in `echo "$all_user"|awk -F ':' '{print $1}'`; do
        userpid=$(ps -u $user_d |awk {'print $1'})
        kill "$userpid" 2>/dev/null
        userdel --force $user_d
      done
      service sshd restart &>/dev/null
      service ssh restart &>/dev/null
      service dropbear start &>/dev/null
      service stunnel4 start &>/dev/null
      service squid restart &>/dev/null
    fi
    clear
    msg -bar
    print_center -ama "RESTAURANDO COPIA"
    msg -bar
    all_name=($(echo "$all_user"|awk -F ':' '{print $1}'))
    while read line; do
      user=$(echo $line|cut -d '|' -f1)
      pass=$(echo $line|cut -d '|' -f2)

      dias=$(( $(echo $line|cut -d '|' -f3) + 1 ))

      if [[ "$dias" -lt 1 ]]; then dias=0 ;fi

      dat=$(echo $line|cut -d '|' -f4)
      stat=$(echo $line|cut -d '|' -f5)

      if [[ $(echo "${all_name[@]}"|grep "$user") = "" ]]; then
        valid=$(date '+%C%y-%m-%d' -d " +$dias days")
        msg -nama " $user"
        if useradd -M -s /bin/false -e ${valid} -K PASS_MAX_DAYS=$dias -p $(openssl passwd -6 $pass) -c $dat $user ; then
          [[ "$stat" = "P" ]] && usermod -U $user || usermod -L $user
          msg -verd " $(fun_trans "Restaurado")"
        else
          msg -verm2 " $(fun_trans "NO, Usuario no Restaurado")"
        fi 
      else
        if [[ "$reset_user" = @(S|s) ]]; then
          userpid=$(ps -u $user |awk {'print $1'})
          kill "$userpid" 2>/dev/null
          userdel --force $user
          if useradd -M -s /bin/false -e ${valid} -K PASS_MAX_DAYS=$dias -p $(openssl passwd -6 $pass) -c $dat $user ; then
            [[ "$stat" = "P" ]] && usermod -U $user || usermod -L $user
            msg -verd " $(fun_trans "Restaurado")"
          else
            msg -verm2 " $(fun_trans "NO, Usuario no Restaurado")"
          fi
        else
            echo -e " $(msg -ama "$user") $(msg -verm2 "Ya Existe")"
        fi
      fi
    done <<< $(cat "${ADM_tmp}/userback.txt")

    rm ${ADM_tmp}/userback.enc
    rm ${ADM_tmp}/userback.txt
    enter

  }

	rsurs(){
		clear
		msg -bar
		print_center -ama "RESTAURAR COPIA DE SEGURIDAD"
		msg -bar
		n=0
		for i in ${backls[@]}; do
      let n++
			echo -e " $(msg -verd "[$n]") $(msg -verm2 ">") $(msg -azu "$i")"
		done
		back
    opcion=$(selection_fun $n)
		[[ "$opcion" = "0" ]] && return
		let opcion--
		cp /root/${backls[$opcion]} ${ADM_tmp}/userback.enc
    restor
    return
	}

	clbk(){
		rm -rf /root/*.ADMRufu
		clear
		msg -bar
		print_center -ama "REGITRO DE COPIAS ELIMINADO"
		enter
	}

  rest_online(){
    title -ama "URL DE COPIA EN LINEA"
    echo -e " $(msg -verm3 "╭╼╼╼╼╼╼╼╼╼╼╼╼╼╼╼╼[")$(msg -azu "INGRESA EL URL")$(msg -verm3 "]")"
    echo -ne " $(msg -verm3 "╰╼")\033[37;1m> " && read url
    [[ -z "$url" ]] && return
    wget -O ${ADM_tmp}/userback.enc "${url}" &>/dev/null; chmod +x ${ADM_tmp}/userback.enc
    restor
    return
  }

	backls=($(ls /root|grep '.ADMRufu'))
	var="${#backls[@]}"
	[[ ${var} = "0" ]] && bkusr && return
	title "RESPALDO DE USUARIOS"
	menu_func "CREAR NUEVO RESPALDO DE USUARIOS" "RESTAURAR RESPALDO DE USUARIOS" "RESPALDO EN LINEA $(msg -verm2 "beta")" "LIMPIAR REGISTRO DE COPIAS"
	back
	msg -ne " opcion: "
	read opcion
	case $opcion in
		1)bkusr;;
		2)rsurs;;
		3)rest_online;;
		4)clbk;;
		0)return;;
	esac
}

remove_script(){
	title "REMOVER SCRIPT ADMRufu"
	in_opcion "Remover script [S/N]"
	[[ "$opcion" != @(s|S|y|Y) ]] && return
	sed -i '/Rufu/d' /root/.bashrc
	sed -i '/Rufu/d' /etc/bash.bashrc
	local sbin=$(ls /etc/ADMRufu/sbin)	
	for i in `echo $sbin`; do
		rm -rf /usr/bin/$i
	done
	rm -rf /usr/bin/menu
	rm -rf /usr/bin/adm
	rm -rf /usr/bin/ADMRufu
	rm -rf /etc/ADMRufu
	rm -rf /etc/profile.d/rufu.sh
	echo "SCRIPT REMOVIDO, REINICIANDO VPS"
	sleep 5
	reboot
}

update2(){
	title "ESTA POR ACTUALIZAR ADMRufu"
	print_center -ama "Para actualizar ADMRufu, requiere de una key"
	msg -bar
	in_opcion "DESA CONTINUAR [S/N]"

	if [[ "$opcion" = @(s|S|y|Y) ]]; then
		rm -rf /root/install.sh*
		wget -O /root/install.sh https://raw.githubusercontent.com/rudi9999/ADMRufu/main/install.sh &>/dev/null
		chmod +x /root/install.sh*
		/root/install.sh --update
	fi
}

update(){
	title 'ACULIZACION ADMRufu'
	print_center -ama "VERCION ACTUAL: $v"
	print_center -verd "NUEVA  VERCION: $up"
	msg -bar
	print_center -blu "Detalles de la nueva vercion"
	echo
	print_center -ama 'Verficando detalles de actulizacion...' && sleep 1
	del 1
	echo "$(curl -sSL "https://raw.githubusercontent.com/rudi9999/ADMRufu/main/detail_UP")"
	msg -bar
	echo "         $(msg -verd '[0]') $(msg -verm2 '>') $(msg -azu 'Volver')       $(msg -verd '[1]') $(msg -verm2 '>') $(msg -azu 'Actualizar')"
	msg -bar
	opcion=$(selection_fun 1)
	case $opcion in
		1)  rm -rf /root/install*
				wget -O /root/instal https://raw.githubusercontent.com/rudi9999/ADMRufu/main/install &>/dev/null
				chmod +x /root/instal*
				/root/instal --update;;
	esac
}

vip_act(){
	vip_activa=$1
	if [[ "$vip_activa" = "" ]]; then
		[[ -e "${ADM_src}/vipbot" ]] && vip=$(cat "${ADM_src}/vipbot") && [[ ! -z "$vip" ]] && return
		vip_activa=1
	fi

	case $vip_activa in
		1)clear
		  msg -bar
		  print_center -ama "Funcion solo para usuarios con acceso al bot"
		  back
		  echo -e "  $(msg -verm3 "╭╼╼╼╼╼╼╼╼╼╼╼╼╼[")$(msg -azu "TOKEN DE ACTIVACION")$(msg -verm3 "]")"
		  echo -ne "  $(msg -verm3 "╰╼")\033[37;1m>\e[32m\e[1m " && read vip
		  [[ $vip = @(0|"") ]] && return 1
		  echo "$vip" > ${ADM_src}/vipbot ;;
		2)rm -f ${ADM_src}/vipbot
		  clear
		  msg -bar
		  print_center -verm2 "token incorrecto o vercion de script antigua\ningresa de nuevo el token o actuliza el script" ;;
	esac
}

# ejecuta un archivo del panel; si falta, avisa como instalarlo
run_file(){
	local f=$1; shift
	if [[ -e $f ]]; then
		[[ ! -x $f ]] && chmod +x "$f"
		"$f" "$@"
	else
		print_center -ama "Descargando $(basename "$f")..."
		if bajar_arq "$(basename "$f")" && [[ -e $f ]]; then
			"$f" "$@"
			return
		fi
		title -verm "NO SE PUDO DESCARGAR"
		print_center -ama "$f"
		msg -bar
		print_center -azu "Revisa que exista en tu repositorio:\n${REPO_OLD}/$(basename "$f")"
		enter
	fi
}

# original: llamaba a userSSH/userHWID/userTOKEN de /usr/bin, que en
# ADMRufu 2.0 son binarios con licencia. Aca se usan los scripts bash
# (old/userSSH, old/userHWID, old/userTOKEN) instalados en ${ADM_inst}.
acount_mode(){
	[[ ! -e ${ADM_user}/userMODE ]] && echo "userSSH" > ${ADM_user}/userMODE
	mode=$(cat ${ADM_user}/userMODE)
	[[ $mode != @(userSSH|userHWID|userTOKEN) ]] && mode=userSSH && echo "userSSH" > ${ADM_user}/userMODE
	if [[ ! -e ${ADM_inst}/limitador.sh ]]; then
		print_center -verm2 "Falta ${ADM_inst}/limitador.sh (el limitador no funcionara)"
		sleep 2
	fi
	run_file ${ADM_inst}/${mode} -m
}

# EXECUCION DE MENU
export -f fun_trans
export -f fun_ip
export -f info_sys
export -f mine_port
export -f os_system
export -f fun_bar
export -f fun_eth
export -f mportas
export -f in_opcion
export -f droppids
export -f backup
export -f ULK_ALF
export -f vip_act
export -f print_center msg title back menu_func selection_fun enter del in_opcion in_opcion_down
export -f contador pid_inst systen_info reiniciar_vps run_file bajar_arq ruta_arq
export REPO_OLD REPO_BASE
refresh_info(){
	export _hora=$(printf '%(%H:%M:%S)T')
	export _fecha=$(printf '%(%D)T')
	export _usop=$(printf '%-1s' "$(top -bn1 | awk '/Cpu/ { cpu = "" 100 - $8 "%" }; END { print cpu }')")
	export ram1=$(free -h | grep -i mem | awk {'print $2'})
	export ram2=$(free -h | grep -i mem | awk {'print $4'})
	export ram3=$(free -h | grep -i mem | awk {'print $3'})
	export _usor=$(printf '%-8s' "$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2 }')")
}

[[ ! -e ${ADM_tmp}/message.txt ]] && echo "@Rufu99" > ${ADM_tmp}/message.txt
[[ ! -e ${ADMRufu}/vercion ]] && date '+%Y-%m-%d' > ${ADMRufu}/vercion

while :; do
refresh_info
clear
#########VISUALIZACION DE MENU

if [[ $(cat ${ADM_tmp}/style|grep -w "resel"|awk '{print $2}') = "1" ]] ; then
	msg -bar
	print_center -azu "=====>>>> $(cat ${ADM_tmp}/message.txt) <<<<====="|lolcat
	msg -bar
else
	cabesera
fi

if [[ $(cat ${ADM_tmp}/style|grep -w "infsys"|awk '{print $2}') = "1" ]] ; then
  info_sys
  msg -bar
fi

if [[ $(cat ${ADM_tmp}/style|grep -w "port"|awk '{print $2}') = "1" ]] ; then
  mine_port
  msg -bar
fi

if [[ $(cat ${ADM_tmp}/style|grep -w "contador"|awk '{print $2}') = "1" ]] ; then
  contador
  msg -bar
fi

close=$(ps aux -u root|grep 'root@'|grep -v 'grep'|awk '{print $2}')

v=$(cat $ADMRufu/vercion 2>/dev/null)
up=$v && [[ -e "$ADMRufu/new_vercion" ]] && up=$(cat $ADMRufu/new_vercion)

nu='1'
echo " $(msg -verd "[$nu]") $(msg -verm2 ">") $(msg -azu "ADMINISTRAR CUENTAS (SSH/DROPBEAR)")" && ssh="$nu"
v2r="a"
if [[ $(systemctl is-active v2ray) = "active" ]]; then
	let nu++
	echo " $(msg -verd "[$nu]") $(msg -verm2 ">") $(msg -azu "ADMINISTRAR CUENTAS (V2ray)")" && v2r="$nu"
fi
wg="a"
if [[ $(systemctl is-active wg-quick@wg0.service) = "active" ]]; then
	let nu++
	echo " $(msg -verd "[$nu]") $(msg -verm2 ">") $(msg -azu "ADMINISTRAR CUENTAS (WIREGUARD)")" && wg="$nu"
fi
msg -bar3
let nu++
echo " $(msg -verd "[$nu]") $(msg -verm2 ">") $(msg -azu "\033[1;100mPREPARACION DEL SISTEMA\033[0m")" && inst="$nu"
msg -bar3
let nu++
echo " $(msg -verd "[$nu]") $(msg -verm2 ">") $(msg -ama "[!]") $(msg -verm2 "DESINSTALAR PANEL")" && dels="$nu"
let nu++
#r="$nu"
u='u'
if [[ "$(date '+%s' -d "$up")" -gt "$(date '+%s' -d "$v")" ]]; then
	msg -bar3
	echo -e "$(msg -verd " [$nu]") $(msg -verm2 ">") $(msg -azu "ACTUALIZACION DISPONIBLE") $(msg -verm2 ">>>") $(msg -verd "$up")"
	#echo -e "$(msg -verd " [$nu]") $(msg -verm2 ">") $(msg -azu "ACTUALIZAR:") $(msg -ama "$v") $(msg -verm2 ">>>") $(msg -verd "$up")"
	u="$nu"
	let nu++
	#r="$nu"
fi
#msg -bar && echo -ne "$(msg -verd " [0]") $(msg -verm2 ">") $(msg -bra "\033[1;41m SALIR DEL SCRIPT ")" && echo -e "$(msg -verd " [$r]") $(msg -verm2 ">") $(msg -bra "\033[1;44m REINICIAR VPS \033[0m")"
msg -bar
echo -ne " $(msg -verd "0)") $(msg -bra "\033[1;100mSALIR DEL VPS")"
echo -ne "  $(msg -verd "$nu)") $(msg -bra "\033[1;41mSALIR DEL SCRIPT")" && ext="$nu"
let nu++
echo -e "  $(msg -verd "$nu)") $(msg -bra "\033[1;44mREBOOT VPS\033[0m")" && r="$nu"
msg -bar
selection=$(selection_fun -nama $nu)

case ${selection} in
	"$ssh") acount_mode;;
	"$v2r") run_file ${ADM_inst}/userV2ray.sh;;
	 "$wg") run_file ${ADM_inst}/userWG.sh;;
   "$inst") run_file ${ADMRufu}/menu_inst.sh;;
   "$dels") remove_script;;
	  "$r") reiniciar_vps;;
	  "$u") update;;
	"$ext") clear && cd $HOME && exit 0;;
		 0) kill $close ;;
		 #0) pkill -KILL -u root ;;
esac
done
