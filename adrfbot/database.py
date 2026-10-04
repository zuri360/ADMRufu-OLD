"""ADRFBOT — capa de datos SQLite (optimizada y segura).

Mejoras respecto a la version previa:
  * Modo WAL  -> lecturas concurrentes sin bloqueo del writer.
  * Una sola conexion compartida protegida por lock (sin abrir/cerrar por
    consulta) -> mucha menos latencia.
  * row_factory = sqlite3.Row para acceso por nombre.
  * Migracion automatica de tablas (users, keys, blocked_ips) + nuevas
    (coupons, banned) sin perder datos.
"""

import datetime
import os
import sqlite3
import threading

LOCK = threading.Lock()


def _now() -> str:
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def _expire(days: int) -> str:
    return (datetime.datetime.now() + datetime.timedelta(days=days)).strftime(
        "%Y-%m-%d %H:%M:%S"
    )


class Database:
    def __init__(self, db_path: str = "adrfbot.db"):
        self.db_path = db_path
        self.conn = sqlite3.connect(db_path, check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        # WAL: permite que el validador y el bot lean concurrentemente
        self.conn.execute("PRAGMA journal_mode=WAL")
        self.conn.execute("PRAGMA synchronous=NORMAL")
        self.conn.execute("PRAGMA foreign_keys=OFF")
        self.conn.execute("PRAGMA busy_timeout=5000")
        self._migrate()

    # ---------------------------------------------------------- migracion
    def _migrate(self):
        with LOCK, self.conn:
            self.conn.execute(
                """
                CREATE TABLE IF NOT EXISTS users (
                    user_id    INTEGER PRIMARY KEY,
                    username   TEXT DEFAULT '',
                    name       TEXT DEFAULT '',
                    reseller   TEXT DEFAULT '',
                    expire_at  TEXT DEFAULT '',
                    created_at TEXT DEFAULT ''
                )
                """
            )
            self.conn.execute(
                """
                CREATE TABLE IF NOT EXISTS keys (
                    id           INTEGER PRIMARY KEY AUTOINCREMENT,
                    short_id     TEXT UNIQUE,
                    token        TEXT UNIQUE,
                    key_public   TEXT DEFAULT '',
                    server       TEXT DEFAULT '',
                    cloudrun     TEXT DEFAULT '',
                    user_id      INTEGER DEFAULT 0,
                    username_bot TEXT DEFAULT '',
                    used_ip      TEXT DEFAULT '',
                    used         INTEGER DEFAULT 0,
                    used_at      TEXT DEFAULT '',
                    created_at   TEXT DEFAULT ''
                )
                """
            )
            self.conn.execute(
                """
                CREATE TABLE IF NOT EXISTS blocked_ips (
                    ip         TEXT PRIMARY KEY,
                    reason     TEXT DEFAULT '',
                    blocked_at TEXT DEFAULT ''
                )
                """
            )
            # nuevas tablas (BOTChumo)
            self.conn.execute(
                """
                CREATE TABLE IF NOT EXISTS banned (
                    user_id    INTEGER PRIMARY KEY,
                    reason     TEXT DEFAULT '',
                    banned_at  TEXT DEFAULT ''
                )
                """
            )
            self.conn.execute(
                """
                CREATE TABLE IF NOT EXISTS coupons (
                    code      TEXT PRIMARY KEY,
                    days      INTEGER DEFAULT 30,
                    max_uses  INTEGER DEFAULT 1,
                    uses      INTEGER DEFAULT 0,
                    created_by INTEGER DEFAULT 0,
                    created_at TEXT DEFAULT ''
                )
                """
            )
            # indices para acelerar busquedas frecuentes
            self.conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_keys_token ON keys(token)"
            )
            self.conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_keys_public ON keys(key_public)"
            )
            self.conn.execute(
                "CREATE INDEX IF NOT EXISTS idx_keys_user ON keys(user_id)"
            )

    # ------------------------------------------------------------ usuarios
    def register_user(self, user_id, username="", name="") -> bool:
        """Registra si es nuevo. Devuelve True si fue creado."""
        with LOCK:
            row = self.conn.execute(
                "SELECT 1 FROM users WHERE user_id=?", (user_id,)
            ).fetchone()
            if row:
                # actualiza username/name si cambiaron
                self.conn.execute(
                    "UPDATE users SET username=?, name=? WHERE user_id=?",
                    (username or "", name or "", user_id),
                )
                return False
            self.conn.execute(
                "INSERT INTO users(user_id,username,name,created_at) VALUES(?,?,?,?)",
                (user_id, username or "", name or "", _now()),
            )
            self.conn.commit()
            return True

    def add_user(self, user_id, days, username="", name="", reseller="") -> bool:
        with LOCK:
            row = self.conn.execute(
                "SELECT 1 FROM users WHERE user_id=?", (user_id,)
            ).fetchone()
            if row:
                # extiende: si ya vencio, cuenta desde hoy
                cur = self.conn.execute(
                    "SELECT expire_at FROM users WHERE user_id=?", (user_id,)
                ).fetchone()
                base = datetime.datetime.now()
                if cur and cur[0]:
                    try:
                        exp = datetime.datetime.strptime(cur[0], "%Y-%m-%d %H:%M:%S")
                        if exp > base:
                            base = exp
                    except Exception:
                        pass
                new_exp = (base + datetime.timedelta(days=days)).strftime(
                    "%Y-%m-%d %H:%M:%S"
                )
                self.conn.execute(
                    "UPDATE users SET expire_at=?, username=COALESCE(NULLIF(?,''),username), "
                    "name=COALESCE(NULLIF(?,''),name), reseller=COALESCE(NULLIF(?,''),reseller) "
                    "WHERE user_id=?",
                    (new_exp, username, name, reseller, user_id),
                )
            else:
                self.conn.execute(
                    "INSERT INTO users(user_id,username,name,reseller,expire_at,created_at) "
                    "VALUES(?,?,?,?,?,?)",
                    (user_id, username or "", name or "", reseller,
                     _expire(days), _now()),
                )
            self.conn.commit()
            return True

    def extend_days(self, user_id, days) -> bool:
        with LOCK:
            row = self.conn.execute(
                "SELECT 1 FROM users WHERE user_id=?", (user_id,)
            ).fetchone()
            if not row:
                return False
            return self.add_user(user_id, days)

    def remove_user(self, user_id) -> bool:
        with LOCK:
            cur = self.conn.execute(
                "DELETE FROM users WHERE user_id=?", (user_id,)
            )
            self.conn.commit()
            return cur.rowcount > 0

    def get_user(self, user_id):
        with LOCK:
            return self.conn.execute(
                "SELECT * FROM users WHERE user_id=?", (user_id,)
            ).fetchone()

    def has_access(self, user_id) -> bool:
        """Acceso valido si existe y no ha vencido."""
        with LOCK:
            row = self.conn.execute(
                "SELECT expire_at FROM users WHERE user_id=?", (user_id,)
            ).fetchone()
        if not row:
            return False
        exp = row[0]
        if not exp:
            return False
        try:
            return datetime.datetime.strptime(exp, "%Y-%m-%d %H:%M:%S") > datetime.datetime.now()
        except Exception:
            return False

    def days_left(self, user_id):
        with LOCK:
            row = self.conn.execute(
                "SELECT expire_at FROM users WHERE user_id=?", (user_id,)
            ).fetchone()
        if not row or not row[0]:
            return 0
        try:
            exp = datetime.datetime.strptime(row[0], "%Y-%m-%d %H:%M:%S")
        except Exception:
            return 0
        d = (exp - datetime.datetime.now()).days
        return max(d, 0)

    def set_reseller(self, user_id, reseller) -> bool:
        with LOCK:
            cur = self.conn.execute(
                "UPDATE users SET reseller=? WHERE user_id=?", (reseller, user_id)
            )
            self.conn.commit()
            return cur.rowcount > 0

    def list_users(self):
        with LOCK:
            return [dict(r) for r in self.conn.execute(
                "SELECT * FROM users ORDER BY created_at DESC"
            ).fetchall()]

    def all_user_ids(self):
        with LOCK:
            return [r[0] for r in self.conn.execute(
                "SELECT user_id FROM users"
            ).fetchall()]

    def find_user(self, query):
        """Busca por id (exacto) o username/name (LIKE). Devuelve lista dicts."""
        q = str(query).strip()
        with LOCK:
            if q.isdigit():
                rows = self.conn.execute(
                    "SELECT * FROM users WHERE user_id=?", (int(q),)
                ).fetchall()
                if rows:
                    return [dict(r) for r in rows]
            like = f"%{q}%"
            return [dict(r) for r in self.conn.execute(
                "SELECT * FROM users WHERE username LIKE ? OR name LIKE ? "
                "OR CAST(user_id AS TEXT) LIKE ? ORDER BY created_at DESC LIMIT 20",
                (like, like, like),
            ).fetchall()]

    # --------------------------------------------------------------- keys
    def create_key(self, user_id, short_id, token, cloudrun_enc,
                   key_public="", server="", username_bot=""):
        with LOCK:
            self.conn.execute(
                "INSERT INTO keys(short_id,token,key_public,server,cloudrun,user_id,"
                "username_bot,created_at) VALUES(?,?,?,?,?,?,?,?)",
                (short_id, token, key_public, server, cloudrun_enc, user_id,
                 username_bot, _now()),
            )
            self.conn.commit()

    def get_key_by_token(self, value):
        """Busca por token, key_public o short_id (robusto)."""
        if not value:
            return None
        with LOCK:
            for col in ("token", "key_public", "short_id"):
                row = self.conn.execute(
                    f"SELECT * FROM keys WHERE {col}=?", (value,)
                ).fetchone()
                if row:
                    return dict(row)
        return None

    def list_keys(self, limit=50):
        with LOCK:
            return [dict(r) for r in self.conn.execute(
                "SELECT * FROM keys ORDER BY id DESC LIMIT ?", (limit,)
            ).fetchall()]

    def reset_key(self, token_or_id) -> bool:
        """Reactivar una key (la marca como no usada)."""
        with LOCK:
            cur = self.conn.execute(
                "UPDATE keys SET used=0, used_ip='', used_at='' "
                "WHERE token=? OR key_public=? OR short_id=?", 
                (token_or_id, token_or_id, token_or_id),
            )
            self.conn.commit()
            return cur.rowcount > 0

    def mark_used(self, key_id, ip=""):
        with LOCK:
            self.conn.execute(
                "UPDATE keys SET used=1, used_ip=?, used_at=? WHERE id=?",
                (ip, _now(), key_id),
            )
            self.conn.commit()

    def keys_today(self, user_id) -> int:
        today = datetime.datetime.now().strftime("%Y-%m-%d")
        with LOCK:
            row = self.conn.execute(
                "SELECT COUNT(*) FROM keys WHERE user_id=? AND created_at LIKE ?",
                (user_id, today + "%"),
            ).fetchone()
            return row[0] if row else 0

    def user_stats(self, user_id):
        with LOCK:
            g = self.conn.execute(
                "SELECT COUNT(*) FROM keys WHERE user_id=?", (user_id,)
            ).fetchone()[0]
            u = self.conn.execute(
                "SELECT COUNT(*) FROM keys WHERE user_id=? AND used=1", (user_id,)
            ).fetchone()[0]
            return g, u

    # ------------------------------------------------------- bloqueo IP
    def block_ip(self, ip, reason=""):
        with LOCK:
            self.conn.execute(
                "INSERT OR REPLACE INTO blocked_ips(ip,reason,blocked_at) VALUES(?,?,?)",
                (ip, reason, _now()),
            )
            self.conn.commit()

    def unblock_ip(self, ip) -> bool:
        with LOCK:
            cur = self.conn.execute("DELETE FROM blocked_ips WHERE ip=?", (ip,))
            self.conn.commit()
            return cur.rowcount > 0

    def is_blocked(self, ip) -> bool:
        with LOCK:
            return self.conn.execute(
                "SELECT 1 FROM blocked_ips WHERE ip=?", (ip,)
            ).fetchone() is not None

    def list_blocked(self):
        with LOCK:
            return [dict(r) for r in self.conn.execute(
                "SELECT * FROM blocked_ips ORDER BY blocked_at DESC"
            ).fetchall()]

    # ----------------------------------------------------- ban de usuarios
    def ban_user(self, user_id, reason=""):
        with LOCK:
            self.conn.execute(
                "INSERT OR REPLACE INTO banned(user_id,reason,banned_at) VALUES(?,?,?)",
                (user_id, reason, _now()),
            )
            self.conn.commit()

    def unban_user(self, user_id) -> bool:
        with LOCK:
            cur = self.conn.execute("DELETE FROM banned WHERE user_id=?", (user_id,))
            self.conn.commit()
            return cur.rowcount > 0

    def is_user_banned(self, user_id) -> bool:
        with LOCK:
            return self.conn.execute(
                "SELECT 1 FROM banned WHERE user_id=?", (user_id,)
            ).fetchone() is not None

    def list_banned(self):
        with LOCK:
            return [dict(r) for r in self.conn.execute(
                "SELECT * FROM banned ORDER BY banned_at DESC"
            ).fetchall()]

    # ------------------------------------------------------------- cupones
    def create_coupon(self, code, days=30, max_uses=1, created_by=0) -> bool:
        with LOCK:
            try:
                self.conn.execute(
                    "INSERT INTO coupons(code,days,max_uses,created_by,created_at) "
                    "VALUES(?,?,?,?,?)",
                    (code, days, max_uses, created_by, _now()),
                )
                self.conn.commit()
                return True
            except sqlite3.IntegrityError:
                return False

    def redeem_coupon(self, code, user_id):
        """Canjea un cupon. Devuelve dias otorgados o 0 si invalido/agotado."""
        with LOCK:
            row = self.conn.execute(
                "SELECT * FROM coupons WHERE code=?", (code,)
            ).fetchone()
            if not row:
                return 0
            if row["uses"] >= row["max_uses"]:
                return -1  # agotado
            days = row["days"]
            self.conn.execute(
                "UPDATE coupons SET uses=uses+1 WHERE code=?", (code,)
            )
            self.conn.commit()
            return days

    def list_coupons(self):
        with LOCK:
            return [dict(r) for r in self.conn.execute(
                "SELECT * FROM coupons ORDER BY created_at DESC"
            ).fetchall()]

    # ------------------------------------------------------------ stats
    def global_stats(self):
        with LOCK:
            users = self.conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
            keys = self.conn.execute("SELECT COUNT(*) FROM keys").fetchone()[0]
            used = self.conn.execute(
                "SELECT COUNT(*) FROM keys WHERE used=1"
            ).fetchone()[0]
            return {"users_total": users, "keys_total": keys, "keys_used": used}

    def optimize(self):
        """VACUUM + reindex para mantener la BD rapida. Devuelve bytes ahorrados."""
        before = os.path.getsize(self.db_path) if os.path.exists(self.db_path) else 0
        with LOCK:
            self.conn.execute("VACUUM")
            self.conn.execute("REINDEX")
            self.conn.commit()
        after = os.path.getsize(self.db_path) if os.path.exists(self.db_path) else 0
        return max(before - after, 0)
