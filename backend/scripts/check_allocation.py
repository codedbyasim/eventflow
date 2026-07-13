"""Check event vendor allocations."""
import asyncio
from app.db import db_session
from app.models.event_vendor_allocation import EventVendorAllocation
from sqlalchemy import select

async def main():
    async with db_session() as db:
        result = await db.execute(
            select(EventVendorAllocation).limit(5)
        )
        allocations = result.scalars().all()
        
        if not allocations:
            print("❌ No allocations found")
            return
        
        print(f"✅ {len(allocations)} allocations found:\n")
        for alloc in allocations:
            print(f"Event {alloc.event_id} → {alloc.category}:")
            print(f"  Allocated: PKR {alloc.allocated_amount:,}")
            print(f"  Max Budget: PKR {alloc.max_budget:,}" if alloc.max_budget else "  Max Budget: None (will use 110% of allocated)")
            print()

if __name__ == "__main__":
    asyncio.run(main())
