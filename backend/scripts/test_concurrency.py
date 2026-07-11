"""
Point 4: Concurrency lock test.
Creates a test negotiation, fires two concurrent run_negotiation_agent calls,
and verifies that the CAS lock rejects the duplicate with "locked_skipped".
"""
from __future__ import annotations

import asyncio
import sys
import uuid
from pathlib import Path
from unittest.mock import patch, AsyncMock

sys.path.insert(0, str(Path(__file__).parent.parent))

import dotenv
dotenv.load_dotenv()

from app.db import db_session
from app.models.user import User
from app.models.vendor import Vendor
from app.models.event import Event
from app.models.negotiation import Negotiation
from app.agents.negotiation_agent import run_negotiation_agent


async def create_test_records():
    """Create temporary records for concurrency testing."""
    async with db_session() as db:
        # Check if test customer exists or create one
        customer = User(
            id=uuid.uuid4(),
            firebase_uid="test_customer_uid_concurrency",
            role="customer",
            email="test_cust_concurrency@example.com",
            phone="123456789",
            display_name="Test Customer Concurrency"
        )
        db.add(customer)
        
        vendor = Vendor(
            id=uuid.uuid4(),
            business_name="Test Vendor Concurrency",
            category="Caterer",
            city="lahore",
            base_price_min=100000,
            base_price_max=200000,
            listed_price=150000,
            rating=4.5,
            verified=True
        )
        db.add(vendor)
        await db.flush() # Populate IDs
        
        event = Event(
            id=uuid.uuid4(),
            firestore_id="test_event_firestore_concurrency",
            customer_id=customer.id,
            customer_firebase_uid=customer.firebase_uid,
            type="Wedding",
            city="lahore",
            guest_count=100,
            total_budget=500000,
            status="negotiating"
        )
        db.add(event)
        await db.flush()
        
        negotiation = Negotiation(
            id=uuid.uuid4(),
            firestore_id="test_neg_firestore_concurrency",
            event_id=event.id,
            vendor_id=vendor.id,
            status="connecting",
            asking_price=150000,
            current_offer=120000,
            rounds_used=0,
            max_rounds=5,
            is_vendor_turn=False
        )
        db.add(negotiation)
        await db.commit()
        
        return negotiation.id, event.id, vendor.id, customer.id


async def cleanup_test_records(neg_id, event_id, vendor_id, customer_id):
    """Delete the temporary records."""
    async with db_session() as db:
        await db.execute(
            Negotiation.__table__.delete().where(Negotiation.id == neg_id)
        )
        await db.execute(
            Event.__table__.delete().where(Event.id == event_id)
        )
        await db.execute(
            Vendor.__table__.delete().where(Vendor.id == vendor_id)
        )
        await db.execute(
            User.__table__.delete().where(User.id == customer_id)
        )
        await db.commit()


async def run_test():
    print("Creating temporary database records for concurrency test...")
    neg_id, event_id, vendor_id, customer_id = await create_test_records()
    print(f"Created Negotiation ID: {neg_id}")
    
    # We mock the Fireworks call and Firestore syncer so the agent does not block
    # and we can simulate a long running turn by adding a delay in the mock.
    async def delayed_mock_fireworks(*args, **kwargs):
        await asyncio.sleep(2.0) # Hold the lock for 2 seconds
        return '{"action": "send_offer", "amount": 130000, "reasoning": "Test counter-offer."}'

    mock_sync = AsyncMock()
    
    print("Launching two concurrent run_negotiation_agent calls...")
    with patch("app.agents.negotiation_agent.call_fireworks", new=delayed_mock_fireworks), \
         patch("app.agents.negotiation_agent.append_negotiation_message", new=mock_sync), \
         patch("app.agents.negotiation_agent.increment_negotiation_round", new=mock_sync), \
         patch("app.agents.negotiation_agent.update_negotiation_status", new=mock_sync):
         
        # Run them concurrently using asyncio.gather
        results = await asyncio.gather(
            run_negotiation_agent(neg_id, "msg_1", "Hello vendor", 140000, "counter"),
            run_negotiation_agent(neg_id, "msg_1", "Hello vendor", 140000, "counter"),
            return_exceptions=True
        )
        
    print("\nResults of concurrent execution:")
    for idx, res in enumerate(results):
        print(f"  Task {idx + 1}: {res}")
        
    # Check assertions
    actions = [r.get("action") if isinstance(r, dict) else str(r) for r in results]
    
    # Clean up test records first
    print("\nCleaning up temporary database records...")
    await cleanup_test_records(neg_id, event_id, vendor_id, customer_id)
    
    # Assert
    assert "locked_skipped" in actions, "One task should have skipped with 'locked_skipped'!"
    assert any(a != "locked_skipped" for a in actions), "One task should have processed!"
    print("\n[SUCCESS] Concurrency CAS atomic lock verification passed!")


if __name__ == "__main__":
    asyncio.run(run_test())
