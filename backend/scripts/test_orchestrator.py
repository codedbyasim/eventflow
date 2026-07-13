"""Test if negotiation orchestrator is being called."""
import asyncio
from app.db import db_session
from app.models.event import Event
from app.models.negotiation import Negotiation
from sqlalchemy import select

async def main():
    async with db_session() as db:
        print("=" * 60)
        print("CHECKING POSTGRES DATABASE")
        print("=" * 60)
        
        # Check events
        result = await db.execute(select(Event).limit(5))
        events = result.scalars().all()
        
        if not events:
            print("❌ NO EVENTS in Postgres!")
            return
        
        print(f"✅ Found {len(events)} events:\n")
        for event in events:
            print(f"Event {event.id}:")
            print(f"  Type: {event.type}")
            print(f"  City: {event.city}")
            print(f"  Status: {event.status}")
            print(f"  Firestore ID: {event.firestore_id}")
            
            # Check negotiations
            neg_result = await db.execute(
                select(Negotiation).where(Negotiation.event_id == event.id)
            )
            negotiations = neg_result.scalars().all()
            
            if not negotiations:
                print(f"  ❌ NO NEGOTIATIONS created for this event!")
                print(f"     Orchestrator never ran or failed.")
            else:
                print(f"  ✅ {len(negotiations)} negotiations:")
                for neg in negotiations:
                    print(f"     - Vendor: {neg.vendor_id}")
                    print(f"       Status: {neg.status}")
                    print(f"       Asking: PKR {neg.asking_price:,}")
                    print(f"       Firestore ID: {neg.firestore_id}")
            print()

if __name__ == "__main__":
    asyncio.run(main())
