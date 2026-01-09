"""Data models and exceptions for the fetcher package."""

from dataclasses import dataclass


@dataclass
class Quote:
    """Represents a single quote."""

    show: str
    character: str
    quote: str
    source_api: str


class RateLimitError(Exception):
    """Raised when API rate limit is hit."""

    pass


class FetchError(Exception):
    """Raised when fetching fails."""

    pass
