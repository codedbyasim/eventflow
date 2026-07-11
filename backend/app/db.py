"""
SQLAlchemy async engine + session factory.
All database I/O uses async sessions to keep FastAPI non-blocking.
"""
from __future__ import annotations

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from sqlalchemy.pool import NullPool

from app.config import get_settings


class Base(DeclarativeBase):
    """Shared declarative base for all ORM models."""
    pass


def clean_db_url_for_asyncpg(url: str) -> tuple[str, dict]:
    """
    Strips 'sslmode' query param from the connection URL (which asyncpg doesn't support)
    and returns the cleaned URL along with connect_args containing ssl configuration.
    """
    import urllib.parse
    if not url:
        return "", {}

    # Trim whitespaces and newlines
    url = url.strip()

    # Validate database URL format and convert scheme to postgresql+asyncpg
    if "://" in url:
        scheme, rest = url.split("://", 1)
        if scheme == "postgresql":
            scheme = "postgresql+asyncpg"
            
        if "@" not in rest:
            raise ValueError(
                "Invalid database connection URL: Missing '@' separator. "
                "Ensure your DATABASE_URL is a complete connection string (e.g. postgresql://user:password@host:port/dbname), "
                "not just a password."
            )
            
        credentials, host_and_query = rest.rsplit("@", 1)
        if ":" in credentials:
            user, password = credentials.split(":", 1)
            # URL-encode the password to escape special characters like @, :, # etc.
            # Unquote first to avoid double-escaping if already escaped.
            unquoted_pass = urllib.parse.unquote(password)
            escaped_pass = urllib.parse.quote(unquoted_pass, safe="")
            url = f"{scheme}://{user}:{escaped_pass}@{host_and_query}"
        else:
            url = f"{scheme}://{rest}"
            
    parsed = urllib.parse.urlparse(url)
    query_params = urllib.parse.parse_qs(parsed.query)
    
    # Strip sslmode if present
    ssl_required = False
    if "sslmode" in query_params:
        sslmode_vals = query_params.pop("sslmode")
        if any(v in ("require", "prefer") for v in sslmode_vals):
            ssl_required = True
            
    # Rebuild query string
    new_query = urllib.parse.urlencode(query_params, doseq=True)
    cleaned_url = urllib.parse.urlunparse((
        parsed.scheme,
        parsed.netloc,
        parsed.path,
        parsed.params,
        new_query,
        parsed.fragment
    ))
    
    connect_args = {}
    if ssl_required:
        import ssl
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        connect_args["ssl"] = ctx
        
    return cleaned_url, connect_args


def _create_engine():
    settings = get_settings()
    url, conn_args = clean_db_url_for_asyncpg(settings.database_url)
    connect_args = {
        "statement_cache_size": 0,  # Fix asyncpg + PgBouncer transaction pool clash
        **conn_args
    }
    return create_async_engine(
        url,
        echo=(settings.app_env == "development"),  # SQL logging in dev
        poolclass=NullPool,  # Disable local pooling; PgBouncer handles it
        connect_args=connect_args,
    )


# Module-level singletons (created once at startup)
engine = _create_engine()
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
    autocommit=False,
)


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency: yields an async DB session, rolls back on error."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


@asynccontextmanager
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Context-manager variant for use outside FastAPI dependency injection (agents, tasks)."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
