# Alembic environment configuration
# Generated for EventFlow backend

from logging.config import fileConfig
from sqlalchemy import engine_from_config, pool
from sqlalchemy.ext.asyncio import AsyncEngine
from alembic import context
import asyncio

# Import all models so Alembic autogenerate can see them
from app.db import Base
import app.models  # noqa: F401 — registers all ORM models with Base.metadata

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    from app.config import get_settings
    from sqlalchemy.ext.asyncio import create_async_engine
    from app.db import clean_db_url_for_asyncpg
    
    settings = get_settings()
    # Migration needs direct connection, bypass transaction pooler
    raw_url = settings.direct_database_url or settings.database_url
    url, conn_args = clean_db_url_for_asyncpg(raw_url)
    
    direct_engine = create_async_engine(
        url,
        connect_args={
            "statement_cache_size": 0,  # Just in case they fall back to pooler
            **conn_args
        }
    )
    async with direct_engine.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await direct_engine.dispose()


def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
