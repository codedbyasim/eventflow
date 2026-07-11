"""
Database reset utility.
Drops and recreates the public schema to ensure a clean slate,
allowing migrations to run from scratch.
"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

import dotenv
import asyncpg
from app.config import get_settings
from app.db import clean_db_url_for_asyncpg


async def main():
    dotenv.load_dotenv()
    settings = get_settings()
    raw_url = settings.direct_database_url or settings.database_url
    url, conn_args = clean_db_url_for_asyncpg(raw_url)
    
    url = url.replace("postgresql+asyncpg://", "postgresql://")
    print("Connecting to Supabase to reset public schema...")
    try:
        conn = await asyncpg.connect(url, **conn_args)
        
        # Reset public schema
        print("Dropping public schema (cascade)...")
        await conn.execute("DROP SCHEMA public CASCADE;")
        
        print("Creating public schema...")
        await conn.execute("CREATE SCHEMA public;")
        await conn.execute("GRANT ALL ON SCHEMA public TO postgres;")
        await conn.execute("GRANT ALL ON SCHEMA public TO public;")
        
        await conn.close()
        print("[OK] Database public schema reset successfully!")
    except Exception as exc:
        print(f"[ERROR] Error resetting database: {exc}")


if __name__ == "__main__":
    asyncio.run(main())
