"""
Point 3: Raw asyncpg connection checker.
Checks both pooled and direct connection configurations independently
and prints the precise authentication / network results.
"""
from __future__ import annotations

import asyncio
import os
import sys
import ssl
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

import dotenv
import asyncpg
from app.db import clean_db_url_for_asyncpg


def mask_dsn(dsn: str) -> str:
    """Mask credentials in DSN for safe printing."""
    import urllib.parse
    parsed = urllib.parse.urlparse(dsn)
    if not parsed.netloc:
        return dsn
    netloc = parsed.netloc
    if "@" in netloc:
        creds, host = netloc.rsplit("@", 1)
        if ":" in creds:
            user = creds.split(":", 1)[0]
            netloc = f"{user}:***@{host}"
        else:
            netloc = f"***@{host}"
    return urllib.parse.urlunparse((
        parsed.scheme,
        netloc,
        parsed.path,
        parsed.params,
        parsed.query,
        parsed.fragment
    ))


async def try_connect(name: str, raw_url: str):
    print(f"\n--- Testing Connection: {name} ---")
    print(f"URL: {mask_dsn(raw_url)}")
    
    if not raw_url:
        print("[SKIP] URL is empty.")
        return False
        
    url, conn_args = clean_db_url_for_asyncpg(raw_url)
    url = url.replace("postgresql+asyncpg://", "postgresql://")
    
    try:
        conn = await asyncio.wait_for(
            asyncpg.connect(url, **conn_args),
            timeout=10.0
        )
        await conn.close()
        print(f"[SUCCESS] Connection '{name}' verified successfully!")
        return True
    except Exception as exc:
        print(f"[FAILURE] Connection '{name}' failed: {exc}")
        return False


async def main():
    dotenv.load_dotenv()
    
    # 1. Test DATABASE_URL (Pooled, port 6543)
    db_url = os.getenv("DATABASE_URL") or ""
    await try_connect("DATABASE_URL (Pooled)", db_url)
    
    # 2. Test DIRECT_DATABASE_URL (Direct/Session, port 5432)
    direct_url = os.getenv("DIRECT_DATABASE_URL") or ""
    await try_connect("DIRECT_DATABASE_URL (Direct/Session)", direct_url)


if __name__ == "__main__":
    asyncio.run(main())
