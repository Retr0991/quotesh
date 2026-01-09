"""Abstract base class for quote fetchers."""

import json
import logging
from abc import ABC, abstractmethod
from typing import Optional
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from .models import Quote, RateLimitError


class QuoteFetcher(ABC):
    """
    Abstract base class for quote fetchers.

    To implement a new fetcher:
    1. Create a new class inheriting from QuoteFetcher
    2. Set the `name` class attribute (used for rate limit tracking)
    3. Implement the `fetch()` method
    4. Add instance to FetcherOrchestrator.fetchers list
    """

    name: str = "base"

    def __init__(self, logger: logging.Logger, timeout: int = 10):
        self.logger = logger
        self.timeout = timeout

    @abstractmethod
    def fetch(self, count: int = 10) -> list[Quote]:
        """
        Fetch quotes from the API.

        Args:
            count: Number of quotes to fetch

        Returns:
            List of Quote objects

        Raises:
            RateLimitError: If API rate limit is hit
        """
        pass

    def _make_request(
        self, url: str, headers: Optional[dict] = None
    ) -> Optional[dict | list]:
        """
        Make HTTP request with error handling.

        Args:
            url: The URL to fetch
            headers: Optional additional headers

        Returns:
            Parsed JSON response or None on error

        Raises:
            RateLimitError: If HTTP 429 is received
        """
        default_headers = {"User-Agent": "quotesh/1.0"}
        if headers:
            default_headers.update(headers)

        try:
            req = Request(url, headers=default_headers)
            with urlopen(req, timeout=self.timeout) as response:
                return json.loads(response.read().decode())
        except HTTPError as e:
            if e.code == 429:
                self.logger.warning(f"Rate limited by {self.name}")
                raise RateLimitError(f"Rate limited: {e}")
            self.logger.error(f"HTTP error from {self.name}: {e.code} {e.reason}")
            return None
        except URLError as e:
            self.logger.error(f"Network error fetching from {self.name}: {e}")
            return None
        except json.JSONDecodeError as e:
            self.logger.error(f"Invalid JSON from {self.name}: {e}")
            return None
        except Exception as e:
            self.logger.error(f"Unexpected error fetching from {self.name}: {e}")
            return None
