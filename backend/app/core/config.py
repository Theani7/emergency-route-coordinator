"""Application configuration loaded from environment variables."""

from functools import lru_cache
from typing import List

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Centralized application settings."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "Ambulance Coordination API"
    app_version: str = "1.0.0"
    debug: bool = False
    environment: str = "development"

    host: str = "0.0.0.0"
    port: int = 8000

    database_url: str = "sqlite+aiosqlite:///./ambulance.db"
    database_url_sync: str = "sqlite:///./ambulance.db"

    @property
    def is_sqlite(self) -> bool:
        return self.database_url.startswith("sqlite")

    secret_key: str = "change-this-to-a-long-random-secret-key-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440

    # Login hardening
    max_login_attempts: int = 5
    login_lockout_minutes: int = 15
    login_rate_limit_max: int = 10
    login_rate_limit_window_seconds: int = 60

    cors_origins: str = "http://localhost:5173,http://localhost:3000"

    osrm_base_url: str = "https://router.project-osrm.org"
    firebase_credentials_json: str = ""
    # Optional Google Directions API key. If set, server will prefer Google Directions for routing.
    google_directions_api_key: str = ""
    # Optional Redis URL for persistent caching (e.g. redis://localhost:6379/0)
    redis_url: str = ""

    # Email OTP (Gmail App Password)
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = ""
    smtp_from_name: str = "Sajiloroute"
    smtp_use_tls: bool = True

    # OTP settings
    otp_expire_minutes: int = 10
    otp_length: int = 6
    otp_max_attempts: int = 5
    otp_resend_cooldown_seconds: int = 60

    log_level: str = "INFO"

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors(cls, value: str | List[str]) -> str:
        if isinstance(value, list):
            return ",".join(value)
        return value

    @model_validator(mode="after")
    def _validate_secret_key(self) -> "Settings":
        default_keys = {
            "change-this-to-a-long-random-secret-key-in-production",
            "dev-demo-secret-key",
        }
        if self.environment != "development" and self.secret_key in default_keys:
            raise ValueError(
                "SECRET_KEY must be set to a strong random value in non-development environments"
            )
        return self

    @property
    def cors_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    """Cached settings instance."""
    return Settings()
