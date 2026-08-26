"""Application configuration using pydantic-settings."""

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # App
    app_name: str = "FastAPI Example"
    app_version: str = "0.1.0"
    environment: str = Field(default="development", alias="APP_ENV")
    host: str = "0.0.0.0"
    port: int = 8000

    # Security
    secret_key: str = Field(..., alias="SECRET_KEY")
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 30

    # Database (optional)
    database_url: str | None = Field(default=None, alias="DATABASE_URL")

    # CORS
    cors_origins: list[str] = Field(
        default_factory=lambda: ["http://localhost:3000", "http://localhost:8080"],
        alias="CORS_ORIGINS",
    )


settings = Settings()