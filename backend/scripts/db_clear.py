"""
Permanent DB cleaning script to clear Events and Negotiations tables.
This ensures E2E tests always start with a clean state.
"""
from __future__ import annotations

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.db import db_session
from app.models import Event, Negotiation


async def main():
    print("Clearing events and negotiations from Supabase...")
    async with db_session() as db:
        await db.execute(Negotiation.__table__.delete())
        await db.execute(Event.__table__.delete())
        await db.commit()
        print("Success: Database is now clean!")


if __name__ == "__main__":
    asyncio.run(main())
