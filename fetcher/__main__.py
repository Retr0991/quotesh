"""
Entry point for running the fetcher as a module.

Usage:
    python -m fetcher --db /path/to/quotes.db --log /path/to/fetcher.log
"""

import argparse
import logging
import sys
from pathlib import Path

from .config import Config
from .orchestrator import FetcherOrchestrator


def setup_logging(log_path: Path, debug: bool = False) -> logging.Logger:
    """Configure logging to file."""
    logger = logging.getLogger("quotesh.fetcher")
    logger.setLevel(logging.DEBUG if debug else logging.INFO)

    handler = logging.FileHandler(log_path)
    handler.setFormatter(
        logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
    )
    logger.addHandler(handler)

    return logger


def main():
    parser = argparse.ArgumentParser(
        description="quotesh quote fetcher",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument(
        "--db",
        type=Path,
        help="Database path",
        default=Config.DEFAULT_DB_PATH,
    )
    parser.add_argument(
        "--log",
        type=Path,
        help="Log file path",
        default=Config.DEFAULT_LOG_PATH,
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug logging",
    )
    args = parser.parse_args()

    config = Config(db_path=args.db, log_path=args.log)
    logger = setup_logging(config.log_path, args.debug)

    try:
        orchestrator = FetcherOrchestrator(config, logger)
        orchestrator.run()
    except Exception as e:
        logger.critical(f"Fatal error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
