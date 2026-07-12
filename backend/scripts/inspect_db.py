import asyncio
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import dotenv
dotenv.load_dotenv()

from app.db import AsyncSessionLocal
from app.models.vendor import Vendor
from app.models.event import Event
from app.models.event_vendor_allocation import EventVendorAllocation
from sqlalchemy import select

async def main():
    async with AsyncSessionLocal() as db:
        # 1. Print all vendors
        res = await db.execute(select(Vendor))
        vendors = res.scalars().all()
        print(f"--- VENDORS ({len(vendors)}) ---")
        for v in vendors:
            print(f"ID: {v.id}, Name: {v.business_name}, Category: {v.category}, City: {v.city}, Verified: {v.verified}, BasePrice: {v.listed_price or v.base_price_max}")

        # 2. Print all events
        res = await db.execute(select(Event))
        events = res.scalars().all()
        print(f"\n--- EVENTS ({len(events)}) ---")
        for e in events:
            print(f"ID: {e.id}, Type: {e.type}, City: {e.city}, Status: {e.status}, Budget: {e.total_budget}")

        # 3. Print all allocations
        res = await db.execute(select(EventVendorAllocation))
        allocs = res.scalars().all()
        print(f"\n--- ALLOCATIONS ({len(allocs)}) ---")
        for a in allocs:
            print(f"EventID: {a.event_id}, Category: {a.category}, Amount: {a.allocated_amount}")

if __name__ == "__main__":
    asyncio.run(main())
