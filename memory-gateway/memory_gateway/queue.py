import json
import sqlite3
import threading
import time
from dataclasses import asdict
from datetime import datetime
from pathlib import Path

from .arms.base import IngestItem

MAX_AGE_S = 24 * 3600
MAX_BACKOFF_S = 3600.0

_SCHEMA = """
CREATE TABLE IF NOT EXISTS items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payload TEXT NOT NULL,
    created REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS deliveries (
    item_id INTEGER NOT NULL REFERENCES items(id),
    arm TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',  -- pending | done | failed
    attempts INTEGER NOT NULL DEFAULT 0,
    next_attempt REAL NOT NULL,
    last_error TEXT,
    PRIMARY KEY (item_id, arm)
);
CREATE INDEX IF NOT EXISTS deliveries_pending ON deliveries(arm, status, item_id);
"""


def _encode(item: IngestItem) -> str:
    d = asdict(item)
    d["timestamp"] = item.timestamp.isoformat()
    return json.dumps(d)


def _decode(payload: str) -> IngestItem:
    d = json.loads(payload)
    d["timestamp"] = datetime.fromisoformat(d["timestamp"])
    return IngestItem(**d)


class DurableQueue:
    """SQLite-backed ingest queue with one delivery row per (item, arm)."""

    def __init__(self, path: Path, backoff_base_s: float = 1.0):
        self._db = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
        self._db.execute("PRAGMA journal_mode=WAL")
        self._lock = threading.Lock()
        self._backoff_base_s = backoff_base_s
        self._db.executescript(_SCHEMA)

    def close(self) -> None:
        self._db.close()

    def enqueue(self, item: IngestItem, arms: list[str]) -> int:
        now = time.time()
        with self._lock:
            self._db.execute("BEGIN")
            cur = self._db.execute(
                "INSERT INTO items(payload, created) VALUES (?, ?)", (_encode(item), now)
            )
            item_id = cur.lastrowid
            self._db.executemany(
                "INSERT INTO deliveries(item_id, arm, next_attempt) VALUES (?, ?, ?)",
                [(item_id, arm, now) for arm in arms],
            )
            self._db.execute("COMMIT")
        return item_id

    def next_for(self, arm: str) -> tuple[int, IngestItem] | None:
        """Oldest undelivered item for the arm if due; None if none or still backing off.

        Head-of-line: a backing-off head blocks later items so order is preserved.
        """
        with self._lock:
            row = self._db.execute(
                "SELECT d.item_id, i.payload, d.next_attempt, i.created FROM deliveries d "
                "JOIN items i ON i.id = d.item_id "
                "WHERE d.arm = ? AND d.status = 'pending' ORDER BY d.item_id LIMIT 1",
                (arm,),
            ).fetchone()
        if row is None or row[2] > time.time():
            return None
        return row[0], _decode(row[1])

    def mark_done(self, item_id: int, arm: str) -> None:
        self._set(item_id, arm, "UPDATE deliveries SET status='done' WHERE item_id=? AND arm=?")

    def mark_failed_attempt(self, item_id: int, arm: str, error: str) -> None:
        """Schedule a retry with exponential backoff; give up after 24h."""
        now = time.time()
        with self._lock:
            created, attempts = self._db.execute(
                "SELECT i.created, d.attempts FROM deliveries d JOIN items i ON i.id=d.item_id "
                "WHERE d.item_id=? AND d.arm=?",
                (item_id, arm),
            ).fetchone()
            attempts += 1
            if now - created > MAX_AGE_S:
                status, delay = "failed", 0.0
            else:
                status = "pending"
                delay = min(self._backoff_base_s * 2 ** (attempts - 1), MAX_BACKOFF_S)
            self._db.execute(
                "UPDATE deliveries SET status=?, attempts=?, next_attempt=?, last_error=? "
                "WHERE item_id=? AND arm=?",
                (status, attempts, now + delay, error, item_id, arm),
            )

    def _set(self, item_id: int, arm: str, sql: str) -> None:
        with self._lock:
            self._db.execute(sql, (item_id, arm))

    def depth(self) -> int:
        with self._lock:
            return self._db.execute(
                "SELECT COUNT(*) FROM deliveries WHERE status='pending'"
            ).fetchone()[0]

    def failed(self) -> int:
        with self._lock:
            return self._db.execute(
                "SELECT COUNT(*) FROM deliveries WHERE status='failed'"
            ).fetchone()[0]
