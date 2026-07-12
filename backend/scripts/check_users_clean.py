import asyncio
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import dotenv
dotenv.load_dotenv()

from app.db import AsyncSessionLocal
from app.models.user import User
from app.auth import _get_firebase_app
from firebase_admin import auth
from sqlalchemy import select

async def main():
    _get_firebase_app()
    # 1. Check Firebase Auth
    page = auth.list_users()
    fb_users = [u.email for u in page.users]
    print(f"--- FIREBASE AUTH USERS ({len(fb_users)}) ---")
    for email in fb_users:
        print(f"  - {email}")

    # 2. Check Postgres Users
    async with AsyncSessionLocal() as db:
        res = await db.execute(select(User))
        pg_users = res.scalars().all()
        print(f"\n--- POSTGRES USERS ({len(pg_users)}) ---")
        for u in pg_users:
            print(f"  - {u.email} ({u.role})")

if __name__ == "__main__":
    asyncio.run(main())
