"""Fetcher orchestrator - coordinates multiple API fetchers."""

import logging
import sys

from .config import Config
from .database import Database
from .models import RateLimitError
from .base import QuoteFetcher
from .fetchers import PlaceholderFetcher, AnimeQuotesFetcher


class FetcherOrchestrator:
    """Coordinates fetching from multiple APIs."""

    def __init__(self, config: Config, logger: logging.Logger):
        self.config = config
        self.logger = logger
        self.db = Database(config.db_path, logger)

        # Add your fetcher implementations here
        self.fetchers: list[QuoteFetcher] = [
            PlaceholderFetcher(logger, config.REQUEST_TIMEOUT),
            AnimeQuotesFetcher(logger, config.REQUEST_TIMEOUT)
            # Add more fetchers as you implement them:
            # MyCustomFetcher(logger, config.REQUEST_TIMEOUT),
        ]

    def run(self) -> int:
        """
        Run all fetchers that are not rate-limited.

        Returns:
            Total number of new quotes added
        """
        self.logger.info("Starting fetch cycle")
        total_new = 0

        for fetcher in self.fetchers:
            if not self.db.should_fetch(
                fetcher.name, self.config.FETCH_COOLDOWN_SECONDS
            ):
                self.logger.debug(f"Skipping {fetcher.name}: cooldown active")
                continue

            try:
                quotes = fetcher.fetch(self.config.FETCH_BATCH_SIZE)

                if quotes:
                    new_count = self.db.insert_quotes_batch(quotes)
                    total_new += new_count
                    self.logger.info(
                        f"Fetched {len(quotes)} quotes from {fetcher.name}, "
                        f"{new_count} new"
                    )

                self.db.record_fetch(fetcher.name)

            except RateLimitError:
                self.logger.warning(f"Rate limited by {fetcher.name}, exiting")
                # Exit gracefully on rate limit
                sys.exit(0)

            except Exception as e:
                self.logger.error(f"Error fetching from {fetcher.name}: {e}")
                continue

        self.logger.info(
            f"Fetch cycle complete. {total_new} new quotes. "
            f"Total in DB: {self.db.get_quote_count()}"
        )

        return total_new
