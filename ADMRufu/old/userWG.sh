#!/bin/bash

cl_data(){
	local peer i n dias EXPTIME ext hora dow up E
	local -a ORDER=() _f=()
	local -A WG_VAL=() WG_PUB=() HORA=() DOW=() UP=() ECACHE=()
	local l cur name valid cpk hkey

	while IFS= read -r l; do
		case $l in
			"# BEGIN_PEER "*) name=${l#\# BEGIN_PEER }; name=${name%% *}; valid=${l##* }; WG_VAL[$name]=$valid; ORDER+=("$name"); cur=$name;;
			"PublicKey "*) [[ -n "$cur" ]] && WG_PUB[$cur]=${l##* };;
		esac
	done < /etc/wireguard/wg0.conf

	[[ ${#ORDER[@]} -eq 0 ]] && print_center -ama "no hay clientes wireguard!" && return

	peer=$(wg 2>/dev/null)
	if [[ -n "$peer" ]]; then
		cpk=""; hkey=""
		while IFS= read -r l; do
			if [[ "$l" == "peer: "* ]]; then
				cpk=${l#peer: }; hkey=""
			elif [[ "$l" == *"latest handshake:"* ]]; then
				_f=(); read -ra _f <<< "$l"
				hkey="${_f[2]}"
				[[ -n "${_f[4]}" ]] && hkey+=":${_f[4]}"
				[[ -n "${_f[6]}" ]] && hkey+=":${_f[6]}"
			elif [[ "$l" == *"transfer:"* ]]; then
				_f=(); read -ra _f <<< "$l"
				if [[ -n "$cpk" ]]; then
					HORA[$cpk]=${hkey:-00:00:00}
					UP[$cpk]="${_f[1]}${_f[2]}"
					DOW[$cpk]="${_f[4]}${_f[5]}"
				fi
			fi
		done <<< "$peer"
	fi

	local R=$'\e[0m' V Z BL A M2 _t now
	_t=$(msg -verd "");  V="${_t%$R}"
	_t=$(msg -azu "");   Z="${_t%$R}"
	_t=$(msg -blu "");   BL="${_t%$R}"
	_t=$(msg -ama "");   A="${_t%$R}"
	_t=$(msg -verm2 ""); M2="${_t%$R}"

	now=$(date +%s)

	local line="${Z}N°${R}-${Z}USUARIO${R}-${V}DOWNLOAD${R}-${M2}UPLOAD${R}-${A}LAST${R}-${Z}DAIS${R}\n"
	n=0
	for i in "${ORDER[@]}"; do
		let n++
		dias="${WG_VAL[$i]}"
		if [[ -n "${ECACHE[$dias]}" ]]; then E=${ECACHE[$dias]}; else E=$(date '+%s' -d "$dias"); ECACHE[$dias]=$E; fi
		EXPTIME=$(( (E - now) / 86400 ))
		if [[ $EXPTIME -lt 0 ]]; then ext="${M2}[EXP]${R}"; else ext="${V}[$EXPTIME]${R}"; fi
		cpk="${WG_PUB[$i]}"
		hora="${HORA[$cpk]:-00:00:00}"
		dow="${DOW[$cpk]:-00.00KiB}"
		up="${UP[$cpk]:-00.00KiB}"
		line+="${V}${n})${R}-${Z}${i}${R}-${BL}${dow}${R}-${BL}${up}${R}-${A}${hora}${R}-${ext}\n"
	done
	printf '%b' "$line" | column -t -s '-'
}

new_wg(){
	octet=2
	while grep AllowedIPs /etc/wireguard/wg0.conf | cut -d "." -f 4 | cut -d "/" -f 1 | grep -q "$octet"; do
		(( octet++ ))
	done

	if [[ "$octet" -eq 256 ]]; then
		title -ama "255 clientes configurados"
		print_center -verm2 "No se pueden configurar mas"
		enter
		return 0
	fi

	title -ama "NUEVO CLIENTE WIREGUARD"
	cl_data
	back
	while [[ -z "$client" ]]; do
		in_opcion -nazu "NOMBRE DE CLIENTE"
		unsanitized_client="${opcion}"
		client=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]/_/g' <<< "$unsanitized_client")
		if [[ ! $(grep "^# BEGIN_PEER $client$" /etc/wireguard/wg0.conf) = "" ]]; then
			tput cuu1 && tput dl1
			print_center -verm2 "El cliete ya existe!"
			sleep 2
			tput cuu1 && tput dl1
			unset client
			continue
		elif [[ ${#client} -gt 12 ]]; then
			tput cuu1 && tput dl1
			print_center -verm2 "Nombre con mas de 12 caracteres!"
			sleep 2
			tput cuu1 && tput dl1
			unset client
		fi
	done
	[[ $client = 0 ]] && return 0

	while [[ -z "$dias_wg" ]]; do
		in_opcion -nazu "Tiempo en dias"
		dias_wg=$(sed 's/[^0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_-]//g' <<< "$opcion")
		if [[ $dias_wg = 0 ]]; then
			tput cuu1 && tput dl1 && tput cuu1 && tput dl1
			print_center -ama "operacion canselada!"
			enter
			return 0
		elif [[ ! $dias_wg =~ $numero ]]; then
			tput cuu1 && tput dl1
			print_center -verm2 "ingresa solo numeros!"
			sleep 2
			tput cuu1 && tput dl1
			unset dias_wg
			continue
		elif [[ $dias_wg -gt 365 ]]; then
			tput cuu1 && tput dl1
			print_center -verm2 "no puedes exeder los 365 dias!"
			sleep 2
			tput cuu1 && tput dl1
			unset dias_wg
			continue
		fi
	done

	valid=$(date '+%C%y-%m-%d' -d " +$dias_wg days")

	dns=$(cat ${ADM_tmp}/wg_dns)
	key=$(wg genkey)
	psk=$(wg genpsk)

	cat << EOF >> /etc/wireguard/wg0.conf
# BEGIN_PEER $client $valid
[Peer]
PublicKey = $(wg pubkey <<< $key)
PresharedKey = $psk
AllowedIPs = 10.7.0.$octet/32$(grep -q 'fddd:2c4:2c4:2c4::1' /etc/wireguard/wg0.conf && echo ", fddd:2c4:2c4:2c4::$octet/128")
# END_PEER $client
EOF

	cat << EOF > ~/"$client".conf
[Interface]
Address = 10.7.0.$octet/24$(grep -q 'fddd:2c4:2c4:2c4::1' /etc/wireguard/wg0.conf && echo ", fddd:2c4:2c4:2c4::$octet/64")
DNS = $dns
PrivateKey = $key

[Peer]
PublicKey = $(grep PrivateKey /etc/wireguard/wg0.conf | cut -d " " -f 3 | wg pubkey)
PresharedKey = $psk
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = $(grep '^# ENDPOINT' /etc/wireguard/wg0.conf | cut -d " " -f 3):$(grep ListenPort /etc/wireguard/wg0.conf | cut -d " " -f 3)
PersistentKeepalive = 25
EOF

[[ ! -d ${ADM_tmp}/client_wg ]] && mkdir ${ADM_tmp}/client_wg && chmod -R +x ${ADM_tmp}/client_wg
cp -f ~/"$client".conf ${ADM_tmp}/client_wg/
	wg addconf wg0 <(sed -n "/^# BEGIN_PEER $client/,/^# END_PEER $client/p" /etc/wireguard/wg0.conf)
	title -ama "CLIENTE WIREGUARD CREADO CON EXITO!"
	print_center -verd "Su archivo de configuracion se encuentra en"
	dircfg=~/"$client.conf"
	print_center -verd "$dircfg"
	msg -bar
	print_center -ama "Quires ver el QR digita [QR]"
	in_opcion_down "Enter para salir"
	if [[ $opcion = @(QR|qr) ]]; then
		title -ama "CLIENTE QR WIREGUARD"
		qrencode -t ansiutf8 < ~/"$client.conf"
		msg -bar
		print_center -ama "CLIENTE QR WIREGUARD"
		enter
	fi
	return 0
}

del_wg(){
	number_of_clients=$(grep -c '^# BEGIN_PEER' /etc/wireguard/wg0.conf)
	if [[ "$number_of_clients" = 0 ]]; then
		title -verm2 "No hay clientes para eliminar"
		sleep 2
		return 0
	fi
	title "ELIMINAR CLIENTES WIREGUARD"
	cl_data
	back
	opcion=$(selection_fun $n)
	[[ $opcion = 0 ]] && return 0
	client=$(grep '^# BEGIN_PEER' /etc/wireguard/wg0.conf | cut -d ' ' -f 3 | sed -n "$opcion"p)
	wg set wg0 peer "$(sed "/^# BEGIN_PEER $client$/,\$p" /etc/wireguard/wg0.conf | grep -m 1 PublicKey | cut -d " " -f 3)" remove
	sed -i "/^# BEGIN_PEER $client/,/^# END_PEER $client/d" /etc/wireguard/wg0.conf
	rm -rf ~/"$client".conf
	rm -rf ${ADM_tmp}/client_wg/"$client".conf
	print_center -ama "Cliente $client eliminado!"
	enter
	return 0
}

view_wg(){
	number_of_clients=$(grep -c '^# BEGIN_PEER' /etc/wireguard/wg0.conf)
	if [[ "$number_of_clients" = 0 ]]; then
		title -ama "No hay clientes configurados"
		sleep 2
		return 0
	fi
	title "DATOS CLIENTES WIREGUARD"
	cl_data
	back
	opcion=$(selection_fun $n)
	[[ $opcion = 0 ]] && return 0
	client=$(grep '^# BEGIN_PEER' /etc/wireguard/wg0.conf | cut -d ' ' -f 3 | sed -n "$opcion"p)
	[[ ! -e ~/"$client.conf" ]] && cp -f ${ADM_tmp}/client_wg/"$client".conf ~/"$client".conf
	title -ama "CLIENTE QR WIREGUARD"
	print_center -verd "Su archivo de configuracion se encuentra en"
	dircfg=~/"$client.conf"
	print_center -verd "$dircfg"
	msg -bar
	print_center -ama "Quires ver el QR digita [QR]"
	in_opcion_down "Enter para salir"
	if [[ $opcion = @(QR|qr) ]]; then
		title -ama "CLIENTE QR WIREGUARD"
		qrencode -t ansiutf8 < ~/"$client.conf"
		msg -bar
		print_center -ama "CLIENTE QR WIREGUARD"
		enter
	fi
	return 0
}

menuWG(){
	unset client
	unset dias_wg
	if [[ ! $(dpkg --get-selections|grep -w 'wireguard'|head -1) ]]; then
		title -verm2 "WIREGUARD no esta instalado!"
		print_center -ama "Para administrar clientes\nprimero deve instalar wireguard"
		enter
		return 0
	elif [[ $(systemctl status wg-quick@wg0.service|grep -w 'Active'|awk -F ' ' '{print $2}') = "inactive" ]]; then
		title -verm2 "WIREGUARD no esta activo!"
		print_center -ama "Para administrar clientes\nprimero deve activar wireguard"
		enter
		return 0
	fi
	title "ADMINISTACION DE CUENTAS WIREGUARD"
	menu_func "NUEVO CLIENTE WG" \
	"ELIMINAR CLIENTE WG" \
	"VER DATOS DE CLIENTES"
	back
	opcion=$(selection_fun 3)
	case $opcion in
		1)new_wg;;
		2)del_wg;;
		3)view_wg;;
		0)return 1;;
	esac
}

while [[  $? -eq 0 ]]; do
	menuWG
done
