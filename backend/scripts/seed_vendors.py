#!/usr/bin/env python3
"""
Seed script — inserts realistic sample vendors into Postgres for Phase 3 testing.
Run: python scripts/seed_vendors.py

Adds verified vendors across all 8 categories in 4 Pakistani cities.
Without this data, vendor matching will always return empty results.
"""
import asyncio
import sys
import uuid
from pathlib import Path

# Make sure app package is importable when run from backend/
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.db import engine, AsyncSessionLocal
from app.models import Vendor
from sqlalchemy.ext.asyncio import AsyncSession


VENDORS: list[dict] = [
    # ── Lahore ──────────────────────────────────────────────────────────
    {"business_name": "Nadeem Caterers", "category": "Caterer", "city": "lahore",
     "base_price_min": 1500, "base_price_max": 2500, "listed_price": 2000,
     "rating": 4.7, "verified": True},

    {"business_name": "Bismillah Caterers", "category": "Caterer", "city": "lahore",
     "base_price_min": 1000, "base_price_max": 1800, "listed_price": 1500,
     "rating": 4.3, "verified": True},

    {"business_name": "Royal Caterers", "category": "Caterer", "city": "lahore",
     "base_price_min": 2000, "base_price_max": 4000, "listed_price": 3000,
     "rating": 4.9, "verified": True},

    {"business_name": "Al-Faisal Decor", "category": "Decorator", "city": "lahore",
     "base_price_min": 60000, "base_price_max": 150000, "listed_price": 120000,
     "rating": 4.5, "verified": True},

    {"business_name": "Dream Decorations", "category": "Decorator", "city": "lahore",
     "base_price_min": 40000, "base_price_max": 100000, "listed_price": 80000,
     "rating": 4.1, "verified": True},

    {"business_name": "Raza Photography", "category": "Photographer", "city": "lahore",
     "base_price_min": 50000, "base_price_max": 120000, "listed_price": 80000,
     "rating": 4.6, "verified": True},

    {"business_name": "Pixel Studio", "category": "Photographer", "city": "lahore",
     "base_price_min": 35000, "base_price_max": 90000, "listed_price": 65000,
     "rating": 4.2, "verified": True},

    {"business_name": "DJ Beats Lahore", "category": "DJ / Music", "city": "lahore",
     "base_price_min": 20000, "base_price_max": 60000, "listed_price": 45000,
     "rating": 4.4, "verified": True},

    {"business_name": "Star Sound System", "category": "Sound System", "city": "lahore",
     "base_price_min": 15000, "base_price_max": 50000, "listed_price": 35000,
     "rating": 4.0, "verified": True},

    {"business_name": "Lahore Marquee & Tent", "category": "Tent / Marquee", "city": "lahore",
     "base_price_min": 80000, "base_price_max": 200000, "listed_price": 150000,
     "rating": 4.3, "verified": True},

    {"business_name": "Gulshan Flowers", "category": "Flowers", "city": "lahore",
     "base_price_min": 20000, "base_price_max": 80000, "listed_price": 50000,
     "rating": 4.5, "verified": True},

    {"business_name": "Al-Ameen Transport", "category": "Transport", "city": "lahore",
     "base_price_min": 15000, "base_price_max": 50000, "listed_price": 30000,
     "rating": 4.1, "verified": True},

    # ── Islamabad ───────────────────────────────────────────────────────
    {"business_name": "Capital Caterers", "category": "Caterer", "city": "islamabad",
     "base_price_min": 1500, "base_price_max": 3000, "listed_price": 2400,
     "rating": 4.6, "verified": True},

    {"business_name": "Islamabad Feasts", "category": "Caterer", "city": "islamabad",
     "base_price_min": 1000, "base_price_max": 2200, "listed_price": 1800,
     "rating": 4.2, "verified": True},

    {"business_name": "Capital Decor", "category": "Decorator", "city": "islamabad",
     "base_price_min": 70000, "base_price_max": 180000, "listed_price": 130000,
     "rating": 4.4, "verified": True},

    {"business_name": "F-7 Photography", "category": "Photographer", "city": "islamabad",
     "base_price_min": 60000, "base_price_max": 140000, "listed_price": 95000,
     "rating": 4.7, "verified": True},

    {"business_name": "Twin City Sounds", "category": "Sound System", "city": "islamabad",
     "base_price_min": 20000, "base_price_max": 60000, "listed_price": 40000,
     "rating": 4.3, "verified": True},

    {"business_name": "Blue Area Flowers", "category": "Flowers", "city": "islamabad",
     "base_price_min": 25000, "base_price_max": 90000, "listed_price": 60000,
     "rating": 4.5, "verified": True},

    # ── Karachi ─────────────────────────────────────────────────────────
    {"business_name": "Karachi Cuisine", "category": "Caterer", "city": "karachi",
     "base_price_min": 1300, "base_price_max": 2800, "listed_price": 2200,
     "rating": 4.5, "verified": True},

    {"business_name": "Sea Breeze Caterers", "category": "Caterer", "city": "karachi",
     "base_price_min": 1100, "base_price_max": 2000, "listed_price": 1600,
     "rating": 4.3, "verified": True},

    {"business_name": "Clifton Decor", "category": "Decorator", "city": "karachi",
     "base_price_min": 55000, "base_price_max": 130000, "listed_price": 100000,
     "rating": 4.2, "verified": True},

    {"business_name": "Karachi Snapshots", "category": "Photographer", "city": "karachi",
     "base_price_min": 45000, "base_price_max": 110000, "listed_price": 75000,
     "rating": 4.4, "verified": True},

    {"business_name": "DJ Karachiite", "category": "DJ / Music", "city": "karachi",
     "base_price_min": 25000, "base_price_max": 70000, "listed_price": 50000,
     "rating": 4.6, "verified": True},

    {"business_name": "Port City Tents", "category": "Tent / Marquee", "city": "karachi",
     "base_price_min": 70000, "base_price_max": 180000, "listed_price": 130000,
     "rating": 4.1, "verified": True},

    # ── Rawalpindi ──────────────────────────────────────────────────────
    {"business_name": "Saddar Caterers", "category": "Caterer", "city": "rawalpindi",
     "base_price_min": 1000, "base_price_max": 2200, "listed_price": 1700,
     "rating": 4.3, "verified": True},

    {"business_name": "Pindi Decor House", "category": "Decorator", "city": "rawalpindi",
     "base_price_min": 50000, "base_price_max": 120000, "listed_price": 90000,
     "rating": 4.0, "verified": True},

    {"business_name": "Rawalpindi Lens", "category": "Photographer", "city": "rawalpindi",
     "base_price_min": 40000, "base_price_max": 100000, "listed_price": 70000,
     "rating": 4.2, "verified": True},

    {"business_name": "Garrison Sounds", "category": "Sound System", "city": "rawalpindi",
     "base_price_min": 12000, "base_price_max": 45000, "listed_price": 28000,
     "rating": 3.9, "verified": True},
]


async def seed() -> None:
    async with AsyncSessionLocal() as session:
        # Check if already seeded
        from sqlalchemy import select, func
        count_result = await session.execute(select(func.count()).select_from(Vendor))
        existing = count_result.scalar_one()

        if existing > 0:
            print(f"Database already has {existing} vendors. Skipping seed (use --force to override).")
            if "--force" not in sys.argv:
                return

        added = 0
        for v_data in VENDORS:
            vendor = Vendor(
                id=uuid.uuid4(),
                business_name=v_data["business_name"],
                category=v_data["category"],
                city=v_data["city"],
                base_price_min=v_data["base_price_min"],
                base_price_max=v_data["base_price_max"],
                listed_price=v_data["listed_price"],
                rating=v_data["rating"],
                verified=v_data["verified"],
            )
            session.add(vendor)
            added += 1

        await session.commit()
        print(f"[SUCCESS] Seeded {added} vendors across 4 cities and 8 categories.")
        print("   Cities: Lahore, Islamabad, Karachi, Rawalpindi")
        print("   Categories: Caterer, Decorator, Photographer, DJ/Music,")
        print("               Sound System, Tent/Marquee, Flowers, Transport")


if __name__ == "__main__":
    asyncio.run(seed())
