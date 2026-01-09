# quotesh - Terminal Greeter

## Project Overview

A fast, offline-capable terminal greeter that displays random quotes from TV shows/movies. Designed for minimal startup overhead by using a local SQLite database with background API fetching.

## Architecture

```
quotesh/
├── quotesh.sh          # Main POSIX shell script (sourced by .zshrc)
├── fetcher/            # Python package for API fetching
│   ├── __init__.py     # Package exports
│   ├── __main__.py     # Entry point (python -m fetcher)
│   ├── models.py       # Quote dataclass, exceptions
│   ├── config.py       # Configuration management
│   ├── database.py     # SQLite operations
│   ├── base.py         # QuoteFetcher abstract base class
│   ├── fetchers.py     # Concrete fetcher implementations
│   └── orchestrator.py # Coordinates multiple fetchers
├── install.sh          # Installation script
├── lib/                # Shell library functions (future)
├── config/             # Default config templates
├── data/               # Runtime data (gitignored)
└── logs/               # Log files (gitignored)
```

**Runtime Data Locations (XDG compliant):**
- Database: `~/.local/share/quotesh/quotes.db`
- Logs: `~/.local/share/quotesh/logs/fetcher.log`
- Config: `~/.config/quotesh/quotesh.conf`

## Key Components

### quotesh.sh
- POSIX-compliant shell script sourced at terminal startup
- Functions prefixed with `_quotesh_` are internal
- `quotesh()` is the main entry point, auto-called on source
- Uses SQLite directly via `sqlite3` command
- Spawns fetcher package in background (fully detached)

### fetcher/ (Python Package)
- Modular Python 3 package, runs detached in background
- `models.py` - Quote dataclass and custom exceptions
- `config.py` - Configuration with XDG-compliant defaults
- `database.py` - SQLite operations (insert, query, metadata)
- `base.py` - Abstract `QuoteFetcher` base class
- `fetchers.py` - Concrete API implementations (add yours here)
- `orchestrator.py` - Coordinates fetchers, handles rate limits
- `__main__.py` - CLI entry point

### Database Schema
```sql
quotes(id, show, character, quote, source_api, added_at)
display_history(id, quote_id, displayed_at)
fetch_metadata(api_name, last_fetch, fetch_count)
```

## Coding Conventions

### Shell (quotesh.sh)
- POSIX sh compatible (no bashisms)
- Functions: `_quotesh_<name>` for internal, `quotesh` for public
- Variables: `QUOTESH_<NAME>` for configuration
- Use `local` keyword sparingly (dash/ash compatible)
- Quote all variable expansions

### Python (fetcher/)
- Python 3.8+ compatible
- Type hints where practical
- Dataclasses for data models
- Abstract base classes for extensibility
- No external dependencies (stdlib only)

## Adding New API Fetchers

1. Open `fetcher/fetchers.py`
2. Create a new class inheriting from `QuoteFetcher`
3. Set the `name` class attribute (used for rate limit tracking)
4. Implement the `fetch(count: int) -> list[Quote]` method
5. Add instance to `FetcherOrchestrator.fetchers` in `orchestrator.py`

Example:
```python
# In fetcher/fetchers.py
class MyApiFetcher(QuoteFetcher):
    name = "my_api"
    BASE_URL = "https://api.example.com/quotes"

    def fetch(self, count: int = 10) -> list[Quote]:
        data = self._make_request(f"{self.BASE_URL}?limit={count}")
        if not data:
            return []
        return [
            Quote(
                show=item["show"],
                character=item["character"],
                quote=item["text"],
                source_api=self.name
            )
            for item in data
        ]
```

Then in `fetcher/orchestrator.py`:
```python
from .fetchers import PlaceholderFetcher, MyApiFetcher

self.fetchers: list[QuoteFetcher] = [
    PlaceholderFetcher(logger, config.REQUEST_TIMEOUT),
    MyApiFetcher(logger, config.REQUEST_TIMEOUT),
]
```

## Configuration

All config vars can be set in `~/.config/quotesh/quotesh.conf` (sourced by shell):

| Variable | Default | Description |
|----------|---------|-------------|
| `QUOTESH_ENABLED` | `1` | Enable/disable greeter |
| `QUOTESH_FETCH_ON_START` | `1` | Run fetcher on terminal open |
| `QUOTESH_BOX_STYLE` | `rounded` | Box style: simple, double, rounded |
| `QUOTESH_MAX_WIDTH` | `80` | Max quote box width |
| `QUOTESH_PYTHON` | `python3` | Python interpreter path |

## Weighted Random Algorithm

Quotes are selected using weighted random with recency decay:
- Never shown quotes: weight 100
- Shown 30+ days ago: weight 80
- Shown 7+ days ago: weight 50
- Shown 1+ days ago: weight 20
- Shown today: weight 5
- Weight divided by (1 + display_count)

## Testing

```sh
# Test shell script directly
. ./quotesh.sh

# Test fetcher manually
python3 -m fetcher --db ./test.db --log ./test.log --debug

# Check database
sqlite3 ~/.local/share/quotesh/quotes.db "SELECT * FROM quotes LIMIT 5;"
```

## Common Tasks

- **Disable greeter temporarily**: `export QUOTESH_ENABLED=0`
- **Force refresh quotes**: `rm ~/.local/share/quotesh/quotes.db && quotesh`
- **Check fetcher logs**: `tail -f ~/.local/share/quotesh/logs/fetcher.log`
- **Add manual quote**:
  ```sql
  INSERT INTO quotes (show, character, quote) VALUES ('Show', 'Character', 'Quote text');
  ```
