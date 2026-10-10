#!/bin/bash
#19/05/2020
clear
msg -bar

stop_all () {
    ck_py=$(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" |grep -v "COMMAND"|grep "python")

    if [[ -z $(echo "$ck_py" | awk '{print $1}' | head -n 1) ]]; then
        print_center -verm "Puertos PYTHON no encontrados"
        msg -bar
    else
        ck_port=$(echo "$ck_py" | awk '{print $9}' | awk -F ":" '{print $2}')
        for i in $ck_port; do
            systemctl stop python.${i} &>/dev/null
            systemctl disable python.${i} &>/dev/null
            rm /etc/systemd/system/python.${i}.service &>/dev/null
        done
        print_center -verd "Puertos PYTHON detenidos"
        msg -bar    
    fi
    sleep 3
 }

  stop_port () {
    clear
    STPY=$(lsof -V -i tcp -P -n | grep -v "ESTABLISHED" |grep -v "COMMAND"|grep "python" | awk '{print $9}' | awk -F ":" '{print $2}')

    msg -bar
    print_center -ama "DETENER UN PUERTO"
    msg -bar

    n=1
    for i in $STPY; do
        echo -e " \033[1;32m[$n] \033[1;31m> \033[1;37m$i\033[0m"
        pypr[$n]=$i
        let n++ 
    done

    msg -bar
    echo -ne "$(msg -verd "  [0]") $(msg -verm2 ">") " && msg -bra "\033[1;41mVOLVER"
    msg -bar
    echo -ne "\033[1;37m opcion: " && read prpy
    tput cuu1 && tput dl1

    [[ $prpy = "0" ]] && return

    systemctl stop python.${pypr[$prpy]} &>/dev/null
    systemctl disable python.${pypr[$prpy]} &>/dev/null
    rm /etc/systemd/system/python.${pypr[$prpy]}.service &>/dev/null

    print_center -verd "PUERTO PYTHON ${pypr[$prpy]} detenido"
    msg -bar
    sleep 3
 }

# FIX-SSH: habilita en OpenSSH los algoritmos viejos que usan muchas apps
# (ssh-rsa, group14-sha1, aes-cbc, hmac-sha1). Evita "Cannot negotiate, proposals do not match"
ssh_legacy(){
    [[ ! -d /etc/ssh ]] && return
    local conf=/etc/ssh/sshd_config.d/legacy.conf
    mkdir -p /etc/ssh/sshd_config.d
    cat > $conf << 'EOF'
HostKeyAlgorithms +ssh-rsa
PubkeyAcceptedAlgorithms +ssh-rsa
KexAlgorithms +diffie-hellman-group14-sha1,diffie-hellman-group1-sha1,diffie-hellman-group-exchange-sha1
Ciphers +aes128-cbc,aes256-cbc,3des-cbc
MACs +hmac-sha1,hmac-md5
EOF
    grep -q '^Include /etc/ssh/sshd_config.d' /etc/ssh/sshd_config || \
        sed -i '1i Include /etc/ssh/sshd_config.d/*.conf' /etc/ssh/sshd_config
    if sshd -t &>/dev/null; then
        systemctl restart ssh &>/dev/null || systemctl restart sshd &>/dev/null
        echo -e "\033[1;33m SSH legacy:\033[1;32m algoritmos habilitados OK"
    else
        rm -f $conf
        echo -e "\033[1;33m SSH legacy:\033[1;31m sshd -t fallo, no se aplico"
    fi
    msg -bar3
}

# FIX-SSH: prueba el proxy como lo haria la app (payload + SSH)
test_pdirect(){
    local r
    r=$(timeout 4 bash -c "exec 3<>/dev/tcp/127.0.0.1/$1; printf 'GET / HTTP/1.1\r\nHost: x\r\nUpgrade: websocket\r\n\r\nSSH-2.0-test\r\n' >&3; cat <&3" 2>/dev/null | tr -d '\0')
    if echo "$r" | grep -aq "SSH-2.0"; then
        print_center -verd "TEST WEBSOCKET -> SSH OK"
    else
        print_center -ama "TEST: sin banner SSH en el puerto $1"
    fi
}

colector(){
    clear
    msg -bar
    print_center -azu "Selecciona Puerto Principal, para Proxy"
    msg -bar

while [[ -z $porta_socket ]]; do
    echo -ne "\033[1;37m Digite el Puerto: " && read porta_socket
    tput cuu1 && tput dl1

        [[ $(mportas|grep -w "${porta_socket}") = "" ]] && {
            echo -e "\033[1;33m $(fun_trans  "Puerto python:")\033[1;32m ${porta_socket} OK"
            msg -bar3
        } || {
            echo -e "\033[1;33m $(fun_trans  "Puerto python:")\033[1;31m ${porta_socket} FAIL" && sleep 2
            tput cuu1 && tput dl1
            unset porta_socket
        }
 done

 if [[ $1 = "PDirect" ]]; then

     print_center -azu "Selec Puerto Local SSH/DROPBEAR/OPENVPN"
     msg -bar3

     while [[ -z $local ]]; do
        echo -ne "\033[1;97m Digite el Puerto: \033[0m" && read local
        tput cuu1 && tput dl1

        [[ $(mportas|grep -w "${local}") = "" ]] && {
            echo -e "\033[1;33m $(fun_trans  "Puerto local:")\033[1;31m ${local} FAIL" && sleep 2
            tput cuu1 && tput dl1
            unset local
        } || {
            echo -e "\033[1;33m $(fun_trans  "Puerto local:")\033[1;32m ${local} OK"
            msg -bar3
        }
    done
     print_center -azu "Response personalizado (enter por defecto 200)"
     print_center -ama "NOTA : Para OVER WEBSOCKET escribe (101)"
     msg -bar3
     echo -ne "\033[1;97m Digite un Response: \033[0m" && read response
     tput cuu1 && tput dl1
     if [[ -z $response ]]; then
        response="200"
        echo -e "\033[1;33m $(fun_trans  "Response:")\033[1;32m ${response} OK"
    else
        echo -e "\033[1;33m $(fun_trans  "Response:")\033[1;32m ${response} OK"
    fi
    msg -bar3
    ssh_legacy
 fi

    if [[ ! $1 = "PGet" ]] && [[ ! $1 = "POpen" ]]; then
        print_center -azu "Introdusca su Mini-Banner"
        msg -bar3
        print_center -azu "Introduzca un texto [Plano] o en [HTML]"
        echo ""
        read texto_soket
    fi

    if [[ $1 = "PPriv" ]]; then
        py="python3"
        IP=$(fun_ip)
    elif [[ $1 = "PDirect" ]]; then
        # PDirect.py fue portado a Python 3 (Ubuntu 22/24 ya no trae python2)
        py="python3"
    elif [[ $1 = "PGet" ]]; then
        echo "master=NetVPS" > ${ADM_tmp}/pwd.pwd
        while read service; do
            [[ -z $service ]] && break
            echo "127.0.0.1:$(echo $service|cut -d' ' -f2)=$(echo $service|cut -d' ' -f1)" >> ${ADM_tmp}/pwd.pwd
        done <<< "$(mportas)"
         porta_bind="0.0.0.0:$porta_socket"
         pass_file="${ADM_tmp}/pwd.pwd"
         py="python"
    else
        py="python"
    fi

    [[ ! -z $porta_bind ]] && conf="-b $porta_bind "|| conf="-p $porta_socket "
    [[ ! -z $pass_file ]] && conf+="-p $pass_file"
    [[ ! -z $local ]] && conf+="-l $local "
    [[ ! -z $response ]] && conf+="-r $response "
    [[ ! -z $IP ]] && conf+="-i $IP "
    [[ ! -z $texto_soket ]] && conf+="-t '$texto_soket'"

echo -e "[Unit]
Description=$1 Service by @Rufu99
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/bin/$py ${ADM_inst}/$1.py $conf
Restart=always
RestartSec=3s

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/python.$porta_socket.service

    systemctl enable python.$porta_socket &>/dev/null
    systemctl start python.$porta_socket &>/dev/null

    if [[ $1 = "PGet" ]]; then
        [[ "$(ps x | grep "PGet.py" | grep -v "grep" | awk -F "pts" '{print $1}')" ]] && {
            print_center -verd "$(fun_trans  "Gettunel Iniciado com Exito")" 
            print_center -azu "$(fun_trans  "Su Contraseña Gettunel es"): $(msg -ama "NetVPS")"
            msg -bar3
        } || {
            print_center -verm2 "$(fun_trans  "Gettunel no fue iniciado")"
            msg -bar3
        }
    fi
    for ufww in `echo $porta_socket`; do
        ufw allow $ufww/tcp > /dev/null 2>&1
    done
    msg -bar
    sleep 2
    if [[ $(systemctl is-active python.$porta_socket) = "active" ]]; then
        print_center -verd "PYTHON INICIADO CON EXITO!!!"
        [[ $1 = "PDirect" ]] && test_pdirect $porta_socket
    else
        print_center -verm2 "PYTHON NO PUDO INICIAR"
        [[ ! -x /usr/bin/$py ]] && print_center -ama "No existe /usr/bin/$py en este sistema"
        print_center -ama "Revisa con: journalctl -u python.$porta_socket -n 20"
        systemctl disable python.$porta_socket &>/dev/null
        systemctl stop python.$porta_socket &>/dev/null
        rm -f /etc/systemd/system/python.$porta_socket.service
        msg -bar
        enter
        return
    fi
    msg -bar
    sleep 3
}

iniciarsocks () {
pidproxy=$(ps x | grep -w "PPub.py" | grep -v "grep" | awk -F "pts" '{print $1}') && [[ ! -z $pidproxy ]] && P1="\033[1;32m[ON]" || P1="\033[1;31m[OFF]"
pidproxy2=$(ps x | grep -w  "PPriv.py" | grep -v "grep" | awk -F "pts" '{print $1}') && [[ ! -z $pidproxy2 ]] && P2="\033[1;32m[ON]" || P2="\033[1;31m[OFF]"
pidproxy3=$(ps x | grep -w  "PDirect.py" | grep -v "grep" | awk -F "pts" '{print $1}') && [[ ! -z $pidproxy3 ]] && P3="\033[1;32m[ON]" || P3="\033[1;31m[OFF]"
pidproxy4=$(ps x | grep -w  "POpen.py" | grep -v "grep" | awk -F "pts" '{print $1}') && [[ ! -z $pidproxy4 ]] && P4="\033[1;32m[ON]" || P4="\033[1;31m[OFF]"
pidproxy5=$(ps x | grep "PGet.py" | grep -v "grep" | awk -F "pts" '{print $1}') && [[ ! -z $pidproxy5 ]] && P5="\033[1;32m[ON]" || P5="\033[1;31m[OFF]"
pidproxy6=$(ps x | grep "scktcheck" | grep -v "grep" | awk -F "pts" '{print $1}') && [[ ! -z $pidproxy6 ]] && P6="\033[1;32m[ON]" || P6="\033[1;31m[OFF]"
print_center -ama "$(fun_trans  "INSTALADOR SOCKS PYTHON")"
msg -bar
echo -ne "$(msg -verd "  [1]") $(msg -verm2 ">") " && msg -azu "Socks Python SIMPLE      $P1"
echo -ne "$(msg -verd "  [2]") $(msg -verm2 ">") " && msg -azu "Socks Python SEGURO      $P2"
echo -ne "$(msg -verd "  [3]") $(msg -verm2 ">") " && msg -azu "Socks Python DIRETO      $P3"
echo -ne "$(msg -verd "  [4]") $(msg -verm2 ">") " && msg -azu "Socks Python OPENVPN     $P4"
echo -ne "$(msg -verd "  [5]") $(msg -verm2 ">") " && msg -azu "Socks Python GETTUNEL    $P5"
msg -bar

py=6
if [[ $(lsof -V -i tcp -P -n|grep -v "ESTABLISHED"|grep -v "COMMAND"|grep "python"|wc -l) -ge "2" ]]; then
    echo -e "$(msg -verd "  [6]") $(msg -verm2 ">") $(msg -azu "DETENER TODOS") $(msg -verd "  [7]") $(msg -verm2 ">") $(msg -azu "DETENER UN PUERTO")"
    py=7
else
    echo -e "$(msg -verd "  [6]") $(msg -verm2 ">") $(msg -azu "DETENER TODOS")"
fi

msg -bar
echo -ne "$(msg -verd "  [0]") $(msg -verm2 ">") " && msg -bra "   \033[1;41m VOLVER \033[0m"
msg -bar

selection=$(selection_fun ${py})
case ${selection} in
    1)colector PPub;;
    2)colector PPriv;;
    3)colector PDirect;;
    4)colector POpen;;
    5)colector PGet;;
    6)stop_all;;
    7)stop_port;;
    0)return 1;;
esac
return 1
}
iniciarsocks