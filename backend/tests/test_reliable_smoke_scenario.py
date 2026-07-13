import sys
import types
import uuid
from pathlib import Path

import pytest
from starlette.requests import Request

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.agents.analyzer_agent import run_analyzer_agent
from app.agents.negotiation_agent import run_negotiation_agent
from app.routers.events import create_event
from app.schemas import EventCreateRequest
from app.services.vendor_matching import match_all_categories


class FakeSession:
    def __init__(self, allocation=None):
        self.allocation = allocation
        self.added = []

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc, tb):
        return False

    async def commit(self):
        return None

    def add(self, obj):
        self.added.append(obj)

    async def execute(self, stmt):
        return types.SimpleNamespace(scalar_one_or_none=lambda: self.allocation)


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
                        listed_price=1000,
                        base_price_max=1000,
                        base_price_min=800,
                        rating=4.8,
                        firebase_uid="vendor-1",
                    )
                ]
            )
        )


class FakeEventDB:
    def __init__(self):
        self.added = []
        self.flush_calls = 0
        self.commit_calls = 0

    def add(self, obj):
        self.added.append(obj)

    async def flush(self):
        self.flush_calls += 1

    async def commit(self):
        self.commit_calls += 1


@pytest.mark.asyncio
async def test_reliable_wedding_smoke_scenario(monkeypatch):
    """Recommended smoke scenario for a Lahore wedding with a realistic budget."""
    event_id = uuid.uuid4()
    negotiation_id = uuid.uuid4()
    fake_db = FakeEventDB()
    user = types.SimpleNamespace(uid="customer-smoke", email="smoke@example.com")

    async def fake_fireworks(*, messages, tools, agent_type, event_id=None, negotiation_id=None, **kwargs):
        if agent_type == "analyzer":
            return {
                "allocations": {"Caterer": 250000, "Photography": 100000},
                "reasoning": "Keep catering as the priority and stay within the overall budget.",
            }
        return {"amount": 240000, "message": "A budget-friendly package is possible within your allocation."}

    async def fake_update_event_status(*args, **kwargs):
        return None

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
            floor_price=180000,
            rounds_used=0,
            max_rounds=5,
            event_id=event_id,
            last_processed_message_id=None,
            processing_locked_at=None,
            vendor=types.SimpleNamespace(category="Caterer"),
            event=types.SimpleNamespace(id=event_id),
        )

    async def fake_get_or_create_user(db, user):
        return types.SimpleNamespace(id=uuid.uuid4(), firebase_uid=user.uid, role="customer", email=user.email)

    async def fake_firestore_update(*args, **kwargs):
        return None

    def fake_db_session_factory(*args, **kwargs):
        allocation = types.SimpleNamespace(allocated_amount=250000, max_budget=275000)
        return FakeSession(allocation=allocation)

    monkeypatch.setattr("app.agents.analyzer_agent.call_fireworks", fake_fireworks)
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

    assert allocations["Caterer"] == 250000
    assert allocations["Photography"] == 100000
    assert sum(allocations.values()) <= 400000

    matched = await match_all_categories(
        db=FakeMatchingSession(),
        categories=["Caterer"],
        city="Lahore",
        event_date=None,
        allocations=allocations,
        guest_count=220,
        venue_pref="Indoor",
    )

    assert matched["Caterer"][0].business_name == "Lahore Grand Catering"
    assert matched["Caterer"][0].listed_price == 220000

    monkeypatch.setattr("app.agents.negotiation_agent.call_fireworks", fake_fireworks)
    monkeypatch.setattr("app.agents.negotiation_agent.db_session", fake_db_session_factory)
    monkeypatch.setattr("app.agents.negotiation_agent._fetch_negotiation", fake_fetch_negotiation)
    monkeypatch.setattr("app.agents.negotiation_agent.append_negotiation_message", fake_append_negotiation_message)
    monkeypatch.setattr("app.agents.negotiation_agent.increment_negotiation_round", fake_increment_negotiation_round)
    monkeypatch.setattr("app.agents.negotiation_agent.update_negotiation_status", fake_update_negotiation_status)
    monkeypatch.setattr("app.services.notifications.notify_customer_on_negotiation_update", fake_notify_customer)
    monkeypatch.setattr("app.services.notifications.notify_vendor_on_negotiation_update", fake_notify_vendor)

    result = await run_negotiation_agent(
        negotiation_id=negotiation_id,
        vendor_message_content="We can offer a package within your budget.",
        vendor_offer_amount=240000,
        vendor_message_type="counter",
    )

    assert result["action"] == "accept_vendor_price"
    assert result["amount"] == 240000
    assert result["amount"] >= 180000
    assert result["amount"] <= 250000

    class FakeBackgroundTasks:
        def __init__(self):
            self.tasks = []

        def add_task(self, func, *args, **kwargs):
            self.tasks.append((func, args, kwargs))

    monkeypatch.setattr("app.routers.events._get_or_create_user", fake_get_or_create_user)
    monkeypatch.setattr("app.routers.events._firestore_update", fake_firestore_update)

    request = Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/events",
            "headers": [],
            "query_string": b"",
            "client": ("testclient", 123),
            "server": ("testserver", 80),
            "scheme": "http",
            "http_version": "1.1",
            "root_path": "",
        }
    )
    body = EventCreateRequest(
        event_type="Wedding",
        city="Lahore",
        guest_count=220,
        indoor_outdoor="Indoor",
        categories=["Caterer", "Photography"],
        total_budget=400000,
    )

    response = await create_event(
        request=request,
        body=body,
        background_tasks=FakeBackgroundTasks(),
        db=fake_db,
        user=user,
    )

    assert response.status == "draft"
    assert response.firestore_id.startswith("evt_")
    assert fake_db.flush_calls == 1
    assert fake_db.commit_calls == 1
