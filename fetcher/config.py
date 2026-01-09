"""Configuration management for the fetcher package."""

from pathlib import Path
from typing import Optional


class Config:
    """Configuration management."""

    DEFAULT_DB_PATH = Path.home() / ".local/share/quotesh/quotes.db"
    DEFAULT_LOG_PATH = Path.home() / ".local/share/quotesh/logs/fetcher.log"
    FETCH_COOLDOWN_SECONDS = 0  # No cooldown - fetch every time
    FETCH_BATCH_SIZE = 10
    REQUEST_TIMEOUT = 10

    def __init__(
        self, db_path: Optional[Path] = None, log_path: Optional[Path] = None
    ):
        self.db_path = Path(db_path) if db_path else self.DEFAULT_DB_PATH
        self.log_path = Path(log_path) if log_path else self.DEFAULT_LOG_PATH
        self._ensure_directories()

    def _ensure_directories(self):
        """Ensure required directories exist."""
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.log_path.parent.mkdir(parents=True, exist_ok=True)
