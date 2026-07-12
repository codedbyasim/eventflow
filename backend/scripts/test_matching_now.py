import asyncio
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

import dotenv
dotenv.load_dotenv()

from app.db import AsyncSessionLocal
from app.services.vendor_matching import match_vendors

async def main():
    async with AsyncSessionLocal() as db:
        print("Testing matchmaking for 'Caterer' in 'lahore'...")
        caterers = await match_vendors(
            db=db,
            category="Caterer",
            city="lahore",
            event_date=None,
            allocated_budget=175000,
            guest_count=100,
        )
        print(f"Matched caterers: {[c.business_name for c in caterers]}")

        print("\nTesting matchmaking for 'Decorator' in 'lahore'...")
        decorators = await match_vendors(
            db=db,
            category="Decorator",
            city="lahore",
            event_date=None,
            allocated_budget=175000,
            guest_count=100,
        )
        print(f"Matched decorators: {[d.business_name for d in decorators]}")

if __name__ == "__main__":
    asyncio.run(main())
