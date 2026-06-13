from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict
from sqlalchemy.engine import URL


BACKEND_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    app_name: str = "Qamqor API"
    environment: str = "development"
    api_prefix: str = "/api/v1"
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 7
    database_url: str | None = None
    postgres_host: str = "127.0.0.1"
    postgres_port: int = 5432
    postgres_db: str = "qamqor"
    postgres_user: str = "postgres"
    postgres_password: str | None = None
    admin_email: str = "admin@qamqor.kz"
    admin_password: str = "admin12345"
    admin_name: str = "Qamqor Admin"
    doctor_password: str = "doctor12345"
    email_delivery_mode: str = "debug"
    smtp_host: str | None = None
    smtp_port: int = 587
    smtp_username: str | None = None
    smtp_password: str | None = None
    smtp_from_email: str = "noreply@qamqor.kz"
    smtp_use_tls: bool = True
    verification_code_ttl_minutes: int = 10
    verification_code_resend_seconds: int = 60
    verification_code_max_attempts: int = 5
    verification_code_max_sends: int = 5

    model_config = SettingsConfigDict(
        env_file=BACKEND_DIR / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()


def get_database_url(settings: Settings | None = None) -> URL | str:
    settings = settings or get_settings()
    if settings.postgres_password:
        return URL.create(
            "postgresql+asyncpg",
            username=settings.postgres_user,
            password=settings.postgres_password,
            host=settings.postgres_host,
            port=settings.postgres_port,
            database=settings.postgres_db,
        )
    if settings.database_url:
        return settings.database_url
    raise ValueError("Set POSTGRES_PASSWORD or DATABASE_URL in backend/.env")
