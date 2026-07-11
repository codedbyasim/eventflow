from __future__ import annotations

import logging
from app.config import get_settings

logger = logging.getLogger(__name__)

def calculate_vendor_event_price(
    vendor_category: str,
    base_price: float,
    min_price: float,
    guest_count: int,
    venue_pref: str | None = None
) -> tuple[float, float]:
    """
    Dynamically computes (asking_price, min_floor_price) for a vendor
    based on their category-specific criteria and configuration settings.
    
    Returns:
        tuple[float, float]: (calculated_asking_price, calculated_min_floor_price)
    """
    settings = get_settings()
    category_lower = vendor_category.lower()
    
    # Ensure guest count is positive
    guests = max(1, guest_count)
    venue = venue_pref or "Indoor"

    if "caterer" in category_lower:
        # Catering: Per-person pricing
        # base_price and min_price are treated as per-person rates (e.g. 2000 and 1500)
        asking = base_price * guests
        floor = min_price * guests
        logger.debug(
            "Catering price calculated per head: guests=%d, base=%s -> asking=%s, floor=%s",
            guests, base_price, asking, floor
        )
        return float(asking), float(floor)
        
    elif "decorator" in category_lower:
        # Decoration: Flat base price scaled by outdoor factor & guest area threshold
        # Multipliers read from settings
        venue_mult = settings.decor_outdoor_multiplier if venue == "Outdoor" else 1.0
        
        size_mult = 1.0
        if guests > settings.decor_guest_threshold:
            excess_guests = guests - settings.decor_guest_threshold
            size_mult += (excess_guests / 100.0) * settings.decor_guest_multiplier_rate
        
        size_mult = max(1.0, size_mult)
            
        asking = base_price * venue_mult * size_mult
        floor = min_price * venue_mult * size_mult
        logger.debug(
            "Decorator price calculated: base=%s, venue_mult=%s, size_mult=%s -> asking=%s, floor=%s",
            base_price, venue_mult, size_mult, asking, floor
        )
        return float(asking), float(floor)
        
    elif "tent" in category_lower or "marquee" in category_lower:
        # Tent/Marquee: Flat space base price + per-head seating rental
        seating_cost = settings.caterer_tent_seating_cost * guests
        asking = base_price + seating_cost
        floor = min_price + seating_cost
        logger.debug(
            "Tent price calculated: base=%s, seating_cost=%s -> asking=%s, floor=%s",
            base_price, seating_cost, asking, floor
        )
        return float(asking), float(floor)
        
    elif "flowers" in category_lower:
        # Flowers: Scale base price proportionally by guest count (table count multiplier)
        table_multiplier = guests / float(settings.flowers_guest_threshold)
        # Cap multiplier to never fall below 1.0 (base price is the minimum)
        table_multiplier = max(1.0, table_multiplier)
        
        asking = base_price * table_multiplier
        floor = min_price * table_multiplier
        logger.debug(
            "Flowers price calculated: base=%s, table_multiplier=%s -> asking=%s, floor=%s",
            base_price, table_multiplier, asking, floor
        )
        return float(asking), float(floor)
        
    else:
        # Flat rates for Photographer, DJ, Music, Sound, Transport, Security, etc.
        logger.debug("Flat-rate price returned for category '%s'", vendor_category)
        return float(base_price), float(min_price)
