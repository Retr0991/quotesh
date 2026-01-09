"""
Concrete fetcher implementations.

Add your custom API fetchers here by inheriting from QuoteFetcher.
"""

import logging

from .base import QuoteFetcher
from .models import Quote


class PlaceholderFetcher(QuoteFetcher):
    """
    Placeholder fetcher for development/testing.
    Returns no quotes - replace with your actual API implementation.
    """

    name = "placeholder"

    def fetch(self, count: int = 10) -> list[Quote]:
        """Return empty list - placeholder only."""
        return []


class ExampleApiFetcher(QuoteFetcher):
    """
    Example API fetcher template.

    To implement your own fetcher:
    1. Copy this class and rename it
    2. Set `name` and `BASE_URL`
    3. Implement `fetch()` to parse your API's response format
    4. Add instance to FetcherOrchestrator.fetchers in orchestrator.py

    Example API response format this template expects:
    [
        {"show": "...", "character": "...", "quote": "..."},
        ...
    ]
    """

    name = "example_api"
    BASE_URL = "https://api.example.com/quotes"

    def fetch(self, count: int = 10) -> list[Quote]:
        """
        Fetch quotes from API.

        Uncomment and modify the code below for your API:
        """
        quotes = []

        # url = f"{self.BASE_URL}?count={count}"
        # data = self._make_request(url)
        #
        # if data and isinstance(data, list):
        #     for item in data:
        #         quotes.append(Quote(
        #             show=item.get("show", "Unknown"),
        #             character=item.get("character", "Unknown"),
        #             quote=item.get("quote", ""),
        #             source_api=self.name
        #         ))

        return quotes


# =============================================================================
# Add your custom fetchers below
# =============================================================================

# class MyCustomFetcher(QuoteFetcher):
#     name = "my_api"
#     BASE_URL = "https://api.myservice.com/quotes"
#
#     def fetch(self, count: int = 10) -> list[Quote]:
#         data = self._make_request(f"{self.BASE_URL}?limit={count}")
#         if not data:
#             return []
#
#         return [
#             Quote(
#                 show=item["show"],
#                 character=item["character"],
#                 quote=item["text"],
#                 source_api=self.name
#             )
#             for item in data
#         ]


class AnimeQuotesFetcher(QuoteFetcher):
    name = "anime_quotes"
    BASE_URL = "https://api.animechan.io/v1"

    def fetch(self, count: int = 10) -> list[Quote]:
        data = self._make_request(f"{self.BASE_URL}/quotes/random")
        if not data or data.get("status") != "success":
            return []
        
        data = data.get("data")
        anime = data.get("anime", {}).get("name", "Unknown")
        character = data.get("character", {}).get("name", "Unknown")
        quote = data.get("content")

        if not (data or anime or character or quote):
            return []

        return [
            Quote(show=anime, character=character, quote=quote, source_api=self.name)
        ]