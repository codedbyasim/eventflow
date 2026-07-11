"""
Permanently deletes all users from the Supabase PostgreSQL database.
"""
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.db import db_session
from app.models.user import User
from app.models.event import Event
from app.models.negotiation import Negotiation
from app.models.booking import Booking

async def main():
    print("Deleting events, negotiations, bookings, and users from Supabase...")
    async with db_session() as db:
        # Delete children first to satisfy foreign key constraints
        await db.execute(Booking.__table__.delete())
        await db.execute(Negotiation.__table__.delete())
        await db.execute(Event.__table__.delete())
        await db.execute(User.__table__.delete())
        await db.commit()
        print("Success: All users, events, negotiations, and bookings deleted from the database!")

if __name__ == "__main__":
    asyncio.run(main())
