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
    conn = await asyncpg.connect(url, **conn_args)
    
    rows = await conn.fetch("SELECT n.nspname, t.typname FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace WHERE t.typname = 'user_role_enum'")
    print("User role enum locations:", rows)
    
    # Let's check tables in public schema
    tables = await conn.fetch("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'")
    print("Tables in public schema:", [r['table_name'] for r in tables])
    
    await conn.close()

if __name__ == "__main__":
    asyncio.run(main())
