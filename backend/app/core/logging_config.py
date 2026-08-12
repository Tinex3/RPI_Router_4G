import logging
import sys
from logging.handlers import RotatingFileHandler

from ..config import settings


def setup_logging() -> None:
    log_format = logging.Formatter(
        "%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(log_format)
    console_handler.setLevel(logging.DEBUG if settings.DEBUG else logging.INFO)

    root_logger = logging.getLogger()
    root_logger.setLevel(logging.DEBUG if settings.DEBUG else logging.INFO)
    root_logger.handlers.clear()
    root_logger.addHandler(console_handler)

    file_handler = RotatingFileHandler(
        settings.data_dir / "app.log",
        maxBytes=1_000_000,
        backupCount=5,
    )
    file_handler.setFormatter(log_format)
    file_handler.setLevel(logging.DEBUG if settings.DEBUG else logging.INFO)
    root_logger.addHandler(file_handler)

    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
