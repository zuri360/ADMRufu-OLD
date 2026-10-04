# ADRFBOT

Sistema de **generación y validación de keys ADMRufu** — réplica del ecosistema
original (bot Telegram + servidor de validación), con los mismos mensajes y el
mismo formato de keys, pero con base de código propia (Python).

```
┌─────────────┐   /menu, KeyGen    ┌──────────────┐
│  Comprador  │ ──────────────────▶│  Bot Telegram│  (bot.py)
└─────────────┘                    └──────┬───────┘
      │                                  │ genera key:
      │  key = base64(XOR(["IP:PUERTO",  │  ["IP:PUERTO","TOKEN"])
      │        "TOKEN"], "VnBjMnTlL"))   ▼
      ▼                             ┌──────────────┐
┌─────────────┐   POST /server.php  │  Validador   │  (server.py)
│ install-LIC │ ───────────────────▶│  (IP:PUERTO) │
│  (VPS del   │   key=<TOKEN>       └──────┬───────┘
│  comprador) │ ◀───────────────────       │ responde JSON cifrado:
└─────────────┘   {status, response, token, chatid, keyid, reseller}
                                        │ marca key usada
                                        │ notifica "✅ key usada!!! ✅"
                                        ▼
                                  ┌──────────────┐
                                  │  Telegram    │
                                  └──────────────┘
```

## Estructura

```
ADRFBOT/
├── install.sh            instalador (dependencias + config + servicios)
├── run.sh                arranque rapido (bot + servidor)
├── bot.py                bot de telegram (telebot)
├── server.py             servidor de validacion POST /server.php
├── config.json           configuracion (generada por install.sh)
├── config.example.json   plantilla de configuracion
├── requirements.txt      dependencias python
└── adrfbot/
    ├── crypto.py         cifrado XOR+base64 (VnBjMnTlL) y generadores
    ├── database.py       sqlite3 (usuarios + keys)
    ├── msgs.py           mensajes exactos del bot ADMRufu
    └── config.py         carga de configuracion
```

## Instalación

```bash
cd ADRFBOT
chmod +x install.sh
./install.sh
```

El instalador pide:

| Dato | Descripción | Default |
|---|---|---|
| Bot Token | De @BotFather | — |
| Owner ID | Tu ID de telegram (el que administra) | — |
| Reseller | Nombre que sale en "Reseller: ..." de las keys | @BlackHanzoX |
| Contacto | Usuario para el mensaje de pago de /ID | @BlackHanzoX |
| IP pública | Donde corre el validador (auto-detectada) | auto |
| Puerto | Puerto del validador | 8080 |
| Límite keys/día | Máx keys por usuario por día (0 = sin límite) | 0 |
| Intentos fallidos | Anti fuerza bruta (fallos antes de bloquear) | 5 |
| Bloqueo IP | Minutos de bloqueo temporal | 30 |
| Verificar ip:puerto | Protección: la key solo sirve en este server | s |
| URL instalador | Comando de instalación de las keys | github ADMRufu |

En Linux crea servicios `systemd` (`adrfbot-bot`, `adrfbot-server`).
En Termux usa `nohup` con logs en `bot.log` y `server.log`.

## Uso

**Comprador:**
- `/start` — bienvenida (sin acceso) o menú directo (si ya es premium)
- `/ID` — su ID (con botones `Menu` / `🗑 del msg` / `📨 Enviar al admin`)
- `/menu` — estadísticas + botones `Reseller` / `Menu` / `KeyGen`
- `KeyGen` — genera una key; botón único `KeyGen | Menu`
- `/reseller <nombre>` — el usuario cambia **su propio** reseller

**Owner (además de todo lo del comprador):**
- `/add <id> <dias>` — dar acceso a un comprador
- `/dias <id> <dias>` — extender días
- `/remove <id>` — quitar acceso
- `/reseller <id> <nombre>` — asignar reseller a otro
- `/script` · `/script <url>` · `/script vps` · `/script github <url>` —
  origen del instalador (botón en el Panel Admin): **GitHub** (URL) o **VPS**
  (busca `ADMRufu/install` en la VPS y lo sirve por HTTP en el puerto
  `install_port`, default **9999**).
- `/users` · `/keys` · `/rekey` · `/stats`
- `/block <ip>` · `/unblock <ip>` · `/blocked`
- `/broadcast <msg>` — enviar mensaje a todos
- `/resellers` — lista de resellers y nº de usuarios
- `/banid <id>` · `/uban <id>` — banear/desbanear usuario
- `/buscar <q>` — buscar usuario por ID/alias/nombre
- `/cprecios <dias> <precio>` — editar precios
- `/cache` — optimizar la BD (VACUUM + page cache)
- `/infosys` — info del VPS (RAM/CPU/disco)
- `/notify <id> <msg>` — enviar mensaje a un usuario
- `/cupon crear <cod> <dias> [max]` · `/cupon list` — cupones

**Usuario:**
- `/precios` · `/cupon <codigo>` — ver costos / canjear cupón
- `/donar` — apoyar el proyecto

El menu del owner tiene botones rediseñados: `🔑 KeyGen`,
`♻️ Reseller`, `📊 Stats`, `➕ Add`, `➖ Del`, `♻️ Cambiar Reseller`,
`📜 Script`, `🎟️ Cupón`, `💰 Precios`, `👥 Resellers`, `📢 Broadcast` y
`⚙️ Panel Admin` (con `🚫 Ban ID`, `✅ Unban`, `🔍 Buscar`, `🧹 Cache`,
`🖥️ SysInfo`, `🔔 Notify`, `🚫 Bloq IP`, `🔓 Desbl IP`, `📋 IPs`).

En el `/menu` del owner aparecen botones extra: `➕ Add Premium`,
`➖ Del Premium` y `📜 Cambiar Script` (flujo guiado: el bot pide los datos).
Al llegar a **0 días**, el usuario pierde el acceso automáticamente.

## Formato de keys (idéntico al original)

```
DUx2X2NYZ0J9YkBzU35UbF1uekwYOyYYPiQ4J0wf
```

Se genera como `base64(XOR(json(["IP:PUERTO","TOKEN"]), "VnBjMnTlL"))`.
El `install-LIC` reconstruido (ver `ADMRufu/install-LIC.go`) valida la key
haciendo `POST http://IP:PUERTO/server.php` con `key=TOKEN`. El validador
responde el mismo JSON cifrado del original:

```json
{"status":true,"response":"OK","token":"<bot_token>",
 "chatid":<quien_genero_la_key>,"keyid":"LW0J","reseller":"<reseller>"}
```

Al validarse, la key se marca como usada (guardando la **IP del VPS** que la
usó). El `chatid` del JSON es **quien generó la key**, así el binario manda su
notificación (SO + ip) solo al comprador; después el validador manda la
notificación "✅ key usada!!!" + key CloudRun (encriptada) al mismo usuario.
**El owner NO ve las keys usadas por otros** (`notify: user`).

**Reuso de keys**: por defecto **1 key = 1 uso** (`single_use: true`) — una vez
validada queda usada (`KEY YA USADA`). Si quieres reutilizarla (reinstalaciones
con la misma key), pon `single_use: false` en `config.json` y reactiva keys con
`/rekey <id>`.

## Base de datos (SQLite)

Tabla `keys` guarda por cada key generada:

| Columna | Contenido |
|---|---|
| `key_public` | la key completa mostrada al comprador |
| `server` | el ip:puerto que viene DENTRO de la key |
| `user_id` | quién creó la key (ID de telegram) |
| `username_bot` | username del bot que la generó |
| `used_ip` | IP del VPS que la usó (capturada en la validación) |
| `cloudrun` | key CloudRun **encriptada** (XOR+base64) |
| `used` / `used_at` | estado de uso |

Tabla `blocked_ips`: IPs bloqueadas manualmente por el owner.

## Protección

- **Verificación del ip:puerto de la key**: la key trae dentro el
  `ip:puerto` para el que fue creada; el validador la rechaza si no
  coincide con el server actual (`KEY DE OTRO SERVIDOR`).
- **Anti fuerza bruta**: N intentos con key inexistente en 60s bloquean
  la IP temporalmente (`max_fail_attempts` / `block_minutes`).
- **Límite global de peticiones**: `max_requests_per_min` (default 120)
  por IP evita flood/DoS al endpoint.
- **Bloqueo manual**: `/block <ip>` y `/unblock <ip>` (owner).
- **Límite diario opcional**: `max_keys_per_day` (0 = sin límite, el
  default).
- **Acceso por expiración**: las keys vencen a las `key_expire_hours` hs
  y los usuarios dejan de tener acceso al vencer sus días (0 días = sin
  premium).
- **Sin confianza en X-Forwarded-For**: la IP se toma de la conexión real,
  no del header (evita saltarse el bloqueo falsificando cabeceras).
- **Tope de cuerpo (64KB) + timeout de lectura**: mitiga slowloris y
  agotamiento de memoria; las líneas de petición enormes se rechazan.
- **Semaforo de concurrencia (64)**: limita validaciones simultáneas
  para no colapsar CPU/threads bajo ataque.
- **Cabeceras de seguridad + versión ofuscada**: `X-Content-Type-Options`,
  `X-Frame-Options`, `Connection: close`, y `Server: ADRFBOT`.
- **Logs sanitizados**: sin inyección de CRLF en los registros.
- **Notificación en hilo aparte**: la alerta "key usada" no bloquea la
  respuesta del validador (más rápido bajo carga).

## Notas

- La password `VnBjMnTlL` es la del sistema ADMRufu original; si la cambias
  en `config.json`, recompila `install-LIC.go` con la nueva.
- El validador usa solo la librería estándar (sin Flask).
- Base de datos: `adrfbot.db` (SQLite, con migración automática).
