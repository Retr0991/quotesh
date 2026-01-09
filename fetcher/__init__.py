"""
quotesh fetcher - Background quote fetching package.
Fetches quotes from APIs and stores them in SQLite database.
"""

from .models import Quote, RateLimitError, FetchError
from .config import Config
from .database import Database
from .base import QuoteFetcher
from .orchestrator import FetcherOrchestrator

__all__ = [
    "Quote",
    "RateLimitError",
    "FetchError",
    "Config",
    "Database",
    "QuoteFetcher",
    "FetcherOrchestrator",
]

__version__ = "1.0.0"
