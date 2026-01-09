"""Database operations for the fetcher package."""

import logging
import sqlite3
from datetime import datetime
from pathlib import Path

from .models import Quote


class Database:
    """SQLite database operations."""

    def __init__(self, db_path: Path, logger: logging.Logger):
        self.db_path = db_path
        self.logger = logger
        self._ensure_schema()

    def _ensure_schema(self):
        """Create tables if they don't exist."""
        with sqlite3.connect(self.db_path) as conn:
            conn.executescript(
                """
                CREATE TABLE IF NOT EXISTS quotes (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    show TEXT NOT NULL,
                    character TEXT NOT NULL,
                    quote TEXT NOT NULL,
                    source_api TEXT,
                    added_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(show, character, quote)
                );

                CREATE TABLE IF NOT EXISTS display_history (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    quote_id INTEGER NOT NULL,
                    displayed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (quote_id) REFERENCES quotes(id) ON DELETE CASCADE
                );

                CREATE INDEX IF NOT EXISTS idx_display_history_quote_id
                ON display_history(quote_id);

                CREATE TABLE IF NOT EXISTS fetch_metadata (
                    api_name TEXT PRIMARY KEY,
                    last_fetch TIMESTAMP,
                    fetch_count INTEGER DEFAULT 0
                );
            """
            )

    def insert_quote(self, quote: Quote) -> bool:
        """Insert a quote, return True if inserted (not duplicate)."""
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.execute(
                    """INSERT OR IGNORE INTO quotes
                       (show, character, quote, source_api)
                       VALUES (?, ?, ?, ?)""",
                    (quote.show, quote.character, quote.quote, quote.source_api),
                )
                return cursor.rowcount > 0
        except sqlite3.Error as e:
            self.logger.error(f"Database error inserting quote: {e}")
            return False

    def insert_quotes_batch(self, quotes: list[Quote]) -> int:
        """Insert multiple quotes, return count of new quotes inserted."""
        new_count = 0
        try:
            with sqlite3.connect(self.db_path) as conn:
                for quote in quotes:
                    cursor = conn.execute(
                        """INSERT OR IGNORE INTO quotes
                           (show, character, quote, source_api)
                           VALUES (?, ?, ?, ?)""",
                        (quote.show, quote.character, quote.quote, quote.source_api),
                    )
                    if cursor.rowcount > 0:
                        new_count += 1
                conn.commit()
        except sqlite3.Error as e:
            self.logger.error(f"Database error inserting quotes batch: {e}")
        return new_count

    def get_quote_count(self) -> int:
        """Get total number of quotes."""
        with sqlite3.connect(self.db_path) as conn:
            result = conn.execute("SELECT COUNT(*) FROM quotes").fetchone()
            return result[0] if result else 0

    def should_fetch(self, api_name: str, cooldown_seconds: int) -> bool:
        """Check if enough time has passed since last fetch."""
        if cooldown_seconds <= 0:
            return True

        with sqlite3.connect(self.db_path) as conn:
            result = conn.execute(
                """SELECT last_fetch FROM fetch_metadata
                   WHERE api_name = ?""",
                (api_name,),
            ).fetchone()

            if not result or not result[0]:
                return True

            last_fetch = datetime.fromisoformat(result[0])
            seconds_since = (datetime.now() - last_fetch).total_seconds()
            return seconds_since >= cooldown_seconds

    def record_fetch(self, api_name: str):
        """Record that a fetch was performed."""
        with sqlite3.connect(self.db_path) as conn:
            conn.execute(
                """INSERT INTO fetch_metadata (api_name, last_fetch, fetch_count)
                   VALUES (?, datetime('now'), 1)
                   ON CONFLICT(api_name) DO UPDATE SET
                   last_fetch = datetime('now'),
                   fetch_count = fetch_count + 1""",
                (api_name,),
            )
