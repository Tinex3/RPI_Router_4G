from __future__ import annotations

from pathlib import Path
from typing import Literal

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    APP_ENV: Literal["development", "production"] = "development"
    APP_NAME: str = "RPI Router 4G"
    APP_VERSION: str = "2.0.0"
    DEBUG: bool = True

    SECRET_KEY: str = "change-this-secret-in-production-rpi-router-4g"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    DATABASE_URL: str = "sqlite+aiosqlite:///data/router.db"

    CORS_ORIGINS: list[str] = ["http://localhost:5173", "http://localhost:3000"]

    EC25_ENABLED: bool = True
    EC25_UPDATE_INTERVAL: float = 5.0

    BASE_DIR: Path = Path(__file__).resolve().parent.parent.parent

    @property
    def data_dir(self) -> Path:
        return self.BASE_DIR / "data"

    @property
    def config_dir(self) -> Path:
        return self.BASE_DIR / "config"

    @property
    def scripts_dir(self) -> Path:
        return self.BASE_DIR / "scripts"


settings = Settings()
