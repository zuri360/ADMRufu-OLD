"""ADRFBOT — cripto y generadores.

Cifrado:  base64( XOR( texto, password ) )
Key:      base64( XOR( json(["IP:PUERTO","TOKEN"]), password ) )

La password por defecto ("VnBjMnTlL") es la del ecosistema ADMRufu original
y debe coincidir con la usada en install-LIC.go. Si la cambias en config.json
recompila install-LIC.go con la nueva.

Verificado contra la key de ejemplo del README:
  DUx2X2NYZ0J9YkBzU35UbF1uekwYOyYYPiQ4J0wf
  -> json(["45.63.14.193:81","ZQkvjHtq"])
"""

import base64
import json
import secrets
import string

DEFAULT_PASSWORD = "VnBjMnTlL"

_ALNUM = string.ascii_letters + string.digits
_SHORT = string.ascii_uppercase + string.digits


# ----------------------------------------------------------------- cifrado
def _xor(data: bytes, key: str) -> bytes:
    kb = key.encode("utf-8")
    if not kb:
        return data
    return bytes(b ^ kb[i % len(kb)] for i, b in enumerate(data))


def encrypt(text: str, password: str = DEFAULT_PASSWORD) -> str:
    """Texto -> base64(XOR(texto, password))."""
    raw = text.encode("utf-8")
    return base64.b64encode(_xor(raw, password)).decode("ascii")


def decrypt(b64: str, password: str = DEFAULT_PASSWORD) -> str:
    """base64(XOR) -> texto (plano)."""
    raw = base64.b64decode(b64)
    return _xor(raw, password).decode("utf-8", "replace")


def build_key(server: str, token: str, password: str = DEFAULT_PASSWORD) -> str:
    """Construye la key publica: base64(XOR(json([server, token]), pw))."""
    payload = json.dumps([server, token], separators=(",", ":"))
    return encrypt(payload, password)


def parse_key(key: str, password: str = DEFAULT_PASSWORD):
    """Decodifica una key publica -> (server, token). Si falla: ('', '')."""
    try:
        arr = json.loads(decrypt(key, password))
        if isinstance(arr, (list, tuple)) and len(arr) >= 2:
            return str(arr[0]), str(arr[1])
    except Exception:
        pass
    return "", ""


# ----------------------------------------------------------- generadores
# Usamos `secrets` (CSPRNG) en vez de `random` para tokens impredecibles.
def gen_token(n: int = 8) -> str:
    return "".join(secrets.choice(_ALNUM) for _ in range(n))


def gen_short_id(n: int = 4) -> str:
    return "".join(secrets.choice(_SHORT) for _ in range(n))


def gen_cloudrun(n: int = 16) -> str:
    return "".join(secrets.choice(_ALNUM) for _ in range(n))
