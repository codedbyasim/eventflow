import sys
from pathlib import Path
import types
import uuid

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.agents.analyzer_agent import run_analyzer_agent
from app.agents.negotiation_agent import run_negotiation_agent
from app.services.vendor_matching import MatchedVendor, match_all_categories


class FakeSession:
    def __init__(self, allocation=None):
        self.allocation = allocation
        self.added = []
        self.commit_calls = 0
        self.execute_calls = 0

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    async def commit(self):
        self.commit_calls += 1

    async def execute(self, stmt):
        self.execute_calls += 1
        if self.execute_calls == 1:
            return types.SimpleNamespace(scalar_one_or_none=lambda: "claimed")
        return types.SimpleNamespace(scalar_one_or_none=lambda: self.allocation)

    def add(self, obj):
        self.added.append(obj)


class FakeMatchingSession:
    async def execute(self, stmt):
        return types.SimpleNamespace(
            scalars=lambda: types.SimpleNamespace(
                all=lambda: [
                    types.SimpleNamespace(
                        id=uuid.uuid4(),
                        business_name="Lahore Grand Catering",
                        category="Caterer",
                        city="Lahore",
                        verified=True,
                        listed_price=450000,
                        base_price_max=450000,
                        base_price_min=300000,
                        rating=4.8,
                        firebase_uid="vendor-1",
                    )
                ]
            )
        )


@pytest.mark.asyncio
async def test_full_pipeline_handles_hard_vendor_quote(monkeypatch):
    event_id = uuid.uuid4()
    negotiation_id = uuid.uuid4()

    async def fake_analyzer_fireworks(*, messages, tools, agent_type, event_id, **kwargs):
        return {
            "allocations": {"Caterer": 250000, "Photography": 100000},
            "reasoning": "Prioritize core catering and keep the rest modest under a tight budget.",
        }

    async def fake_update_event_status(*args, **kwargs):
        return None

    async def fake_negotiation_fireworks(*, messages, tools, agent_type, event_id, negotiation_id, **kwargs):
        return {"amount": 240000, "message": "We can offer a more budget-friendly package."}

    async def fake_append_negotiation_message(*args, **kwargs):
        return "msg-1"

    async def fake_increment_negotiation_round(*args, **kwargs):
        return 1

    async def fake_update_negotiation_status(*args, **kwargs):
        return None

    async def fake_notify_customer(*args, **kwargs):
        return None

    async def fake_notify_vendor(*args, **kwargs):
        return None

    async def fake_fetch_negotiation(db, negotiation_id):
        return types.SimpleNamespace(
            id=negotiation_id,
            status="connecting",
            current_offer=None,
            asking_price=450000,
            rounds_used=0,
            max_rounds=5,
            event_id=event_id,
            last_processed_message_id=None,
            processing_locked_at=None,
            vendor=types.SimpleNamespace(category="Caterer"),
            event=types.SimpleNamespace(id=event_id),
        )

    def fake_db_session_factory(*args, **kwargs):
        allocation = types.SimpleNamespace(allocated_amount=250000, max_budget=275000)
        return FakeSession(allocation=allocation)

    monkeypatch.setattr("app.agents.analyzer_agent.call_fireworks", fake_analyzer_fireworks)
    monkeypatch.setattr("app.agents.analyzer_agent.update_event_status", fake_update_event_status)
    monkeypatch.setattr("app.agents.analyzer_agent.db_session", fake_db_session_factory)

    allocations = await run_analyzer_agent(
        event_id=event_id,
        event_type="Wedding",
        guest_count=220,
        indoor_outdoor="Indoor",
        categories=["Caterer", "Photography"],
        total_budget=400000,
    )

    assert sum(allocations.values()) <= 400000
    assert allocations["Caterer"] == 250000
    assert allocations["Photography"] == 100000

    matched = await match_all_categories(
        db=FakeMatchingSession(),
        categories=["Caterer"],
        city="Lahore",
        event_date=None,
        allocations=allocations,
        guest_count=220,
        venue_pref="Indoor",
    )
    matched_vendor = matched["Caterer"][0]
    assert matched_vendor.business_name == "Lahore Grand Catering"
    assert matched_vendor.listed_price == 450000 * 220
    assert matched_vendor.floor_price == 300000 * 220

    monkeypatch.setattr("app.agents.negotiation_agent.call_fireworks", fake_negotiation_fireworks)
    monkeypatch.setattr("app.agents.negotiation_agent.db_session", fake_db_session_factory)
    monkeypatch.setattr("app.agents.negotiation_agent._fetch_negotiation", fake_fetch_negotiation)
    monkeypatch.setattr("app.agents.negotiation_agent.append_negotiation_message", fake_append_negotiation_message)
    monkeypatch.setattr("app.agents.negotiation_agent.increment_negotiation_round", fake_increment_negotiation_round)
    monkeypatch.setattr("app.agents.negotiation_agent.update_negotiation_status", fake_update_negotiation_status)
    monkeypatch.setattr("app.services.notifications.notify_customer_on_negotiation_update", fake_notify_customer)
    monkeypatch.setattr("app.services.notifications.notify_vendor_on_negotiation_update", fake_notify_vendor)
    monkeypatch.setattr("app.services.pricing_calculator.calculate_vendor_event_price", lambda **kwargs: (450000, 300000))

    result = await run_negotiation_agent(
        negotiation_id=negotiation_id,
        vendor_message_content="We can only do 450,000 PKR for this wedding.",
        vendor_offer_amount=450000,
        vendor_message_type="counter",
    )

    assert result["action"] == "send_offer"
    assert result["amount"] <= 250000
    assert result["amount"] < 450000 * 220
