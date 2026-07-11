import pytest
from app.services.pricing_calculator import calculate_vendor_event_price
from app.config import get_settings

def test_caterer_pricing():
    # Caterer: per head pricing
    asking, floor = calculate_vendor_event_price(
        vendor_category="Caterer",
        base_price=2000.0,
        min_price=1500.0,
        guest_count=100
    )
    assert asking == 2000.0 * 100
    assert floor == 1500.0 * 100

def test_decorator_indoor_pricing():
    # Decorator: flat base price scaled by size multiplier
    # Above 100 guests, size multiplier is 1.0 + (excess_guests / 100) * 0.05
    # For 100 guests: size_mult = 1.0, venue_mult = 1.0
    asking, floor = calculate_vendor_event_price(
        vendor_category="Decorator",
        base_price=50000.0,
        min_price=40000.0,
        guest_count=100,
        venue_pref="Indoor"
    )
    assert asking == 50000.0
    assert floor == 40000.0

def test_decorator_outdoor_large_pricing():
    # For 300 guests (outdoor):
    # venue_mult = 1.25
    # excess_guests = 200 -> size_mult = 1.0 + (200 / 100) * 0.05 = 1.10
    # expected = base_price * 1.25 * 1.10
    asking, floor = calculate_vendor_event_price(
        vendor_category="Decorator",
        base_price=50000.0,
        min_price=40000.0,
        guest_count=300,
        venue_pref="Outdoor"
    )
    expected_asking = 50000.0 * 1.25 * 1.10
    expected_floor = 40000.0 * 1.25 * 1.10
    assert asking == pytest.approx(expected_asking)
    assert floor == pytest.approx(expected_floor)

def test_tent_pricing():
    # Tent/Marquee: flat space + per head seating rental (300.0 per head)
    # guest_count = 150
    # expected = base_price + 300.0 * 150
    asking, floor = calculate_vendor_event_price(
        vendor_category="Tent / Marquee",
        base_price=100000.0,
        min_price=80000.0,
        guest_count=150
    )
    expected_asking = 100000.0 + 300.0 * 150
    expected_floor = 80000.0 + 300.0 * 150
    assert asking == expected_asking
    assert floor == expected_floor

def test_flowers_pricing():
    # Flowers: scale base price proportionally by guest count (table count multiplier)
    # guest_count = 200, flowers_guest_threshold = 100 -> multiplier = 2.0
    asking, floor = calculate_vendor_event_price(
        vendor_category="Flowers",
        base_price=10000.0,
        min_price=8000.0,
        guest_count=200
    )
    assert asking == 10000.0 * 2.0
    assert floor == 8000.0 * 2.0

def test_flat_pricing():
    # Flat rate categories: Photographer, DJ, Sound System
    asking, floor = calculate_vendor_event_price(
        vendor_category="Photographer",
        base_price=35000.0,
        min_price=30000.0,
        guest_count=250
    )
    assert asking == 35000.0
    assert floor == 30000.0

def test_decorator_below_threshold_clamp_pricing():
    # Guest count = 50, which is below settings.decor_guest_threshold = 100.
    # The multiplier must not go below 1.0 (clamped).
    asking, floor = calculate_vendor_event_price(
        vendor_category="Decorator",
        base_price=50000.0,
        min_price=40000.0,
        guest_count=50,
        venue_pref="Indoor"
    )
    assert asking == 50000.0
    assert floor == 40000.0
