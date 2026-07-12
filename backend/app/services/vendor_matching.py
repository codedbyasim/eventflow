"""
Vendor Matching Service — FR-MTC-01 to FR-MTC-04
Selects candidate vendors per category before negotiation begins.
"""
from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import date

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.vendor import Vendor

logger = logging.getLogger(__name__)


@dataclass
class MatchedVendor:
    vendor_id: uuid.UUID
    business_name: str
    category: str
    listed_price: int
    floor_price: int
    rating: float
    firebase_uid: str | None
    score: float


async def match_vendors(
    db: AsyncSession,
    category: str,
    city: str,
    event_date: date | None,
    allocated_budget: int,
    guest_count: int,
    venue_pref: str | None = None,
) -> list[MatchedVendor]:
    """
    FR-MTC-01: Query verified vendors filtered by category and city.
    FR-MTC-02: Rank by composite score (rating + budget proximity).
    FR-MTC-03: Return top N (configurable via settings.vendors_per_category).

    Args:
        category: Vendor category string (e.g. "Caterer")
        city: Event city
        event_date: Used for future availability filtering (FR-MTC-01)
        allocated_budget: Category budget — used in composite score
        guest_count: Event guest count
        venue_pref: Venue setting preference (Indoor/Outdoor)

    Returns:
        List of MatchedVendor sorted by composite score (best first), max N.
    """
    settings = get_settings()

    # FR-MTC-01: filter by category, city, verified
    result = await db.execute(
        select(Vendor).where(
            and_(
                Vendor.category == category,
                Vendor.city.ilike(city),   # case-insensitive city match
                Vendor.verified == True,   # noqa: E712 — SQLAlchemy requires ==
            )
        )
    )
    vendors = result.scalars().all()

    if not vendors:
        logger.info("No verified vendors found for %s in %s", category, city)
        return []

    # FR-MTC-02: composite score
    # Score = 0.5 * (rating/5.0) + 0.5 * (1 - abs(price - budget) / max(price, budget))
    # Higher is better. Price proximity rewards vendors whose price is close to budget.
    scored: list[MatchedVendor] = []
    for v in vendors:
        rating_score = min(float(v.rating), 5.0) / 5.0

        # Calculate dynamic asking price exactly once at matching time
        from app.services.pricing_calculator import calculate_vendor_event_price
        raw_asking = float(v.listed_price or v.base_price_max or 0.0)
        raw_floor = float(v.base_price_min or 0.0)

        price, floor_price = calculate_vendor_event_price(
            vendor_category=v.category,
            base_price=raw_asking,
            min_price=raw_floor,
            guest_count=guest_count,
            venue_pref=venue_pref
        )

        price = int(price)
        floor_price = int(floor_price)

        if floor_price > allocated_budget:
            logger.info(
                "Skipping vendor %s for %s because floor price %s exceeds category budget %s",
                v.business_name,
                category,
                floor_price,
                allocated_budget,
            )
            continue

        budget_delta = abs(price - allocated_budget)
        price_proximity = 1.0 - min(budget_delta / max(price, allocated_budget, 1), 1.0)
        composite = 0.5 * rating_score + 0.5 * price_proximity

        scored.append(MatchedVendor(
            vendor_id=v.id,
            business_name=v.business_name,
            category=v.category,
            listed_price=price,
            floor_price=floor_price,
            rating=float(v.rating),
            firebase_uid=v.firebase_uid,
            score=composite,
        ))

    # FR-MTC-03: top N by score
    scored.sort(key=lambda x: x.score, reverse=True)
    top_n = scored[: settings.vendors_per_category]

    logger.info(
        "Matched %d vendors for %s in %s (returned top %d)",
        len(vendors), category, city, len(top_n),
    )
    return top_n


async def match_all_categories(
    db: AsyncSession,
    categories: list[str],
    city: str,
    event_date: date | None,
    allocations: dict[str, float],
    guest_count: int,
    venue_pref: str | None = None,
) -> dict[str, list[MatchedVendor]]:
    """
    Run vendor matching for all categories. Returns a dict of category → matched vendors.
    FR-MTC-04: categories with zero matches are included with an empty list
               (caller should notify customer and not block other categories).
    """
    results: dict[str, list[MatchedVendor]] = {}
    for category in categories:
        budget = int(allocations.get(category, 0))
        matched = await match_vendors(
            db=db,
            category=category,
            city=city,
            event_date=event_date,
            allocated_budget=budget,
            guest_count=guest_count,
            venue_pref=venue_pref,
        )
        results[category] = matched
        if not matched:
            logger.warning("FR-MTC-04: No vendors matched for category '%s'", category)
    return results
