import asyncio
from app.db import AsyncSessionLocal
from app.models.vendor import Vendor
from sqlalchemy import select

async def main():
    category_map = {
        "caterer": "Caterer",
        "decorator": "Decorator",
        "photographer": "Photographer",
        "dj_sound": "DJ / Music",
        "tent": "Tent / Marquee",
        "security": "Security",
        "flowers": "Flowers",
        "other": "Other"
    }
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(Vendor))
        vendors = result.scalars().all()
        count = 0
        for v in vendors:
            if v.category in category_map:
                old = v.category
                v.category = category_map[v.category]
                print(f"Updating Vendor '{v.business_name}' category: '{old}' -> '{v.category}'")
                count += 1
        if count > 0:
            await db.commit()
            print(f"Successfully normalized {count} vendor categories in Postgres database!")
        else:
            print("No vendor categories needed normalization.")

if __name__ == "__main__":
    asyncio.run(main())
