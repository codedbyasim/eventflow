"""Seed a test vendor for debugging."""
import asyncio
import uuid
from app.db import db_session
from app.models.vendor import Vendor
from app.models.user import User

async def main():
    async with db_session() as db:
        # Create test user
        user_id = uuid.uuid4()
        test_user = User(
            id=user_id,
            firebase_uid="test_vendor_uid_" + user_id.hex[:8],
            email="test.vendor@example.com",
            role="vendor",
        )
        db.add(test_user)
        
        # Create test vendor
        vendor = Vendor(
            id=uuid.uuid4(),
            user_id=user_id,
            firebase_uid=test_user.firebase_uid,
            business_name="Test Caterer Lahore",
            category="Caterer",
            city="lahore",
            base_price=12000,  # 240 per head for 50 guests
            min_price=10000,   # 200 per head floor
            is_verified=True,
        )
        db.add(vendor)
        
        await db.commit()
        print(f"✅ Created test vendor:")
        print(f"   Business: {vendor.business_name}")
        print(f"   Category: {vendor.category}")
        print(f"   City: {vendor.city}")
        print(f"   Base Price: PKR {vendor.base_price:,}")
        print(f"   Min Price: PKR {vendor.min_price:,}")

if __name__ == "__main__":
    asyncio.run(main())
