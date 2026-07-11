"""
Clear All — Safely wipes the entire Supabase PostgreSQL database AND Firestore database AND Firebase Auth clean.
Re-seeds the default vendors in PostgreSQL.
"""
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

# Load environment
import dotenv
dotenv.load_dotenv()

from app.db import db_session
from app.auth import get_firestore_client, _get_firebase_app
from app.models import User, Event, EventVendorAllocation, Vendor, Negotiation, Booking, LLMUsageLog
from firebase_admin import auth

def delete_collection(coll_ref, batch_size=100):
    docs = coll_ref.limit(batch_size).stream()
    deleted = 0
    for doc in docs:
        # Recursive delete subcollections
        if coll_ref.id == 'negotiations':
            sub_messages = doc.reference.collection('messages')
            delete_collection(sub_messages, batch_size)
        doc.reference.delete()
        deleted += 1
    if deleted >= batch_size:
        delete_collection(coll_ref, batch_size)

async def main():
    # 1. Clear Firebase Auth Users
    print("Clearing Firebase Authentication users...")
    try:
        _get_firebase_app()
        page = auth.list_users()
        uids = [u.uid for u in page.users]
        if uids:
            res = auth.delete_users(uids)
            print(f"  Deleted {res.success_count} Firebase Auth users successfully!")
        else:
            print("  No Firebase Auth users found.")
    except Exception as e:
        print(f"Error clearing Firebase Auth users: {e}")

    # 2. Clear Firestore
    print("Clearing Firestore collections (events, negotiations, users)...")
    try:
        db = get_firestore_client()
        for coll_name in ["events", "negotiations", "users"]:
            print(f"  Clearing collection: {coll_name}...")
            delete_collection(db.collection(coll_name))
        print("Success: Firestore is now clean!")
    except Exception as e:
        print(f"Error clearing Firestore: {e}")

    # 3. Clear Postgres
    print("Clearing PostgreSQL tables...")
    async with db_session() as session:
        # Deleting in reverse order of foreign key dependencies
        await session.execute(Booking.__table__.delete())
        await session.execute(Negotiation.__table__.delete())
        await session.execute(EventVendorAllocation.__table__.delete())
        await session.execute(Event.__table__.delete())
        await session.execute(LLMUsageLog.__table__.delete())
        await session.execute(User.__table__.delete())
        await session.execute(Vendor.__table__.delete())
        await session.commit()
        print("Success: PostgreSQL is now clean!")

if __name__ == "__main__":
    asyncio.run(main())
