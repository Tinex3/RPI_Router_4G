import os
import logging
from logging.handlers import RotatingFileHandler

def setup_logging(log_path: str = "/var/log/ec25-router/app.log") -> None:
    """Configura logging rotativo para evitar llenar el disco"""
    os.makedirs(os.path.dirname(log_path), exist_ok=True)

    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    # Handler rotativo: 1MB max, 5 backups
    handler = RotatingFileHandler(log_path, maxBytes=1_000_000, backupCount=5)
    fmt = logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s")
    handler.setFormatter(fmt)
    logger.addHandler(handler)
    
    # También a consola para desarrollo
    console = logging.StreamHandler()
    console.setFormatter(fmt)
    logger.addHandler(console)
