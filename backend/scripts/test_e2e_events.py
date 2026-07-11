"""
Point 4: E2E Integration test.
Overrides FastAPI authentication to act as a test customer, submits a POST /events request,
and verifies the database state, agent executions, and LLM logs.
"""
from __future__ import annotations

import asyncio
import sys
import uuid
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

import dotenv
dotenv.load_dotenv()

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.main import create_app
from app.auth import FirebaseUser, verify_token, require_customer
from app.db import db_session
from app.models import User, Event, Negotiation, Vendor, LLMUsageLog


# ── Dependency Override ───────────────────────────────────────────────────────
class TestFirebaseUser(FirebaseUser):
    def __init__(self):
        super().__init__(
            uid="test_customer_uid_e2e",
            email="e2e_customer@example.com",
            role="customer"
        )


async def override_verify_token():
    return TestFirebaseUser()


async def override_require_customer():
    return TestFirebaseUser()


async def setup_test_customer():
    """Ensure test customer exists in database."""
    async with db_session() as db:
        res = await db.execute(
            select(User).where(User.firebase_uid == "test_customer_uid_e2e")
        )
        user = res.scalar_one_or_none()
        if not user:
            user = User(
                id=uuid.uuid4(),
                firebase_uid="test_customer_uid_e2e",
                role="customer",
                email="e2e_customer@example.com",
                phone="123456789",
                display_name="E2E Test Customer"
            )
            db.add(user)
            await db.commit()
            print("Created E2E Test Customer record.")
        else:
            print("E2E Test Customer record already exists.")


async def verify_db_results(event_id_str: str):
    """Query and print the resulting database entries after processing."""
    event_id = uuid.UUID(event_id_str)
    
    print("\n--- Database Verification Results ---")
    async with db_session() as db:
        # 1. Fetch Event
        res_evt = await db.execute(
            select(Event).where(Event.id == event_id)
        )
        evt = res_evt.scalar_one_or_none()
        if evt:
            print(f"Event found: ID={evt.id}, Status={evt.status}, City={evt.city}")
            print(f"Analyzer reasoning: {evt.analyzer_reasoning}")
        else:
            print("❌ Event record not found in database!")
            return
            
        # 2. Fetch Negotiations
        res_neg = await db.execute(
            select(Negotiation).where(Negotiation.event_id == event_id)
        )
        negs = res_neg.scalars().all()
        print(f"Negotiations spawned: {len(negs)}")
        for n in negs:
            # Load vendor name
            res_v = await db.execute(
                select(Vendor).where(Vendor.id == n.vendor_id)
            )
            v = res_v.scalar_one()
            print(f"  - Negotiation ID={n.id}, Status={n.status}, Vendor='{v.business_name}', Asking Price={n.asking_price}")
            
        # 3. Fetch LLM logs
        res_logs = await db.execute(
            select(LLMUsageLog).where(LLMUsageLog.event_id == event_id)
        )
        logs = res_logs.scalars().all()
        print(f"LLM usage logs generated: {len(logs)}")
        for l in logs:
            print(f"  - Log ID={l.id}, Agent={l.agent_type}, Model={l.model_used}, Success={l.success}")


async def main():
    import httpx
    # Setup test customer in Postgres
    await setup_test_customer()

    # Build FastAPI test client with dependency overrides
    app = create_app()
    app.dependency_overrides[verify_token] = override_verify_token
    app.dependency_overrides[require_customer] = override_require_customer

    # 150 guests, Lahor, total budget 500,000 PKR
    payload = {
        "event_type": "Wedding",
        "event_date": "2026-08-15",
        "city": "lahore",
        "guest_count": 150,
        "indoor_outdoor": "Indoor",
        "categories": ["Caterer", "Decorator"],
        "total_budget": 500000
    }

    print("\nSending POST /events request...")
    start_time = time.time()
    
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/events", json=payload)
        
    end_time = time.time()
    
    print(f"Response status: {response.status_code}")
    print(f"Response JSON: {response.json()}")
    print(f"Time taken: {end_time - start_time:.2f} seconds")

    if response.status_code == 201:
        event_id = response.json()["event_id"]
        # Give background tasks 5 seconds to settle just in case
        print("Waiting 5 seconds for background agents to complete...")
        await asyncio.sleep(5)
        # Verify db entries
        await verify_db_results(event_id)
    else:
        print("[ERROR] POST /events request failed!")


if __name__ == "__main__":
    asyncio.run(main())
