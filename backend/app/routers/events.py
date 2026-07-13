"""
Events Router — POST /events
FR-EVT-07: On submission, creates event record and triggers Analyzer Agent within 3 seconds.
NFR-SEC-05: Rate limited to 5 events/minute per user.
NFR-PERF-01: Analyzer returns within 5 seconds; kicked off as BackgroundTask.
"""
import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import FirebaseUser, require_customer
from app.db import get_db
from app.limiter import limiter
from app.models.event import Event
from app.models.user import User
from app.schemas import EventCreateRequest, EventCreateResponse
from app.services.state_sync import update_event_status, _firestore_update
from sqlalchemy import select

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("", response_model=EventCreateResponse, status_code=201)
@limiter.limit("5/minute")
async def create_event(
    request: Request,  # required by slowapi
    body: EventCreateRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    user: FirebaseUser = Depends(require_customer),
) -> EventCreateResponse:
    """
    FR-EVT-07: Customer submits event → create record → trigger Analyzer within 3s.

    Response returns immediately with event_id and firestore_id.
    The Analyzer Agent, vendor matching, and negotiation spawn run as a BackgroundTask.
    """
    from fastapi import HTTPException as FastAPIHTTPException

    # ── Ensure user exists in Postgres ────────────────────────────────────
    try:
        pg_user = await _get_or_create_user(db, user)
    except Exception as exc:
        logger.exception("Failed to upsert user %s: %s", user.uid, exc)
        raise FastAPIHTTPException(status_code=500, detail=f"User setup failed: {exc}")

    # ── Create event record ───────────────────────────────────────────────
    event_id = uuid.uuid4()
    firestore_id = f"evt_{event_id.hex[:16]}"

    try:
        event = Event(
            id=event_id,
            firestore_id=firestore_id,
            customer_id=pg_user.id,
            customer_firebase_uid=user.uid,
            type=body.event_type,
            event_date=body.event_date,
            city=body.city,
            guest_count=body.guest_count,
            indoor_outdoor=body.indoor_outdoor,
            total_budget=body.total_budget,
            negotiation_flexibility=body.negotiation_flexibility,
            status="draft",
        )
        db.add(event)
        await db.flush()
    except Exception as exc:
        logger.exception("Failed to create event record for user %s: %s", user.uid, exc)
        raise FastAPIHTTPException(status_code=500, detail=f"Event creation failed: {exc}")

    # Mirror event to Firestore immediately so client can listen
    try:
        await _firestore_update(
            f"events/{firestore_id}",
            {
                "customerId": user.uid,
                "type": body.event_type,
                "totalBudget": body.total_budget,
                "status": "draft",
                "city": body.city or "",
                "guestCount": body.guest_count,
                "categories": body.categories,
                "createdAt": datetime.now(timezone.utc).isoformat(),
            },
        )
    except Exception as exc:
        # Firestore mirror failure is non-fatal for the HTTP response
        logger.warning("Firestore mirror failed for event %s: %s", event_id, exc)

    try:
        await db.commit()
    except Exception as exc:
        logger.exception("DB commit failed for event %s: %s", event_id, exc)
        raise FastAPIHTTPException(status_code=500, detail=f"Database error: {exc}")

    logger.info("Event %s created (firestore_id=%s) for user %s", event_id, firestore_id, user.uid)

    # ── Kick off the full pipeline as a background task ───────────────────
    background_tasks.add_task(
        _run_full_pipeline,
        event_id=event_id,
        firestore_id=firestore_id,
        body=body,
        customer_firebase_uid=user.uid,
    )

    return EventCreateResponse(
        event_id=str(event_id),
        firestore_id=firestore_id,
        status="draft",
        message="Event created. AI analysis starting now — watch your dashboard.",
    )


async def _run_full_pipeline(
    event_id: uuid.UUID,
    firestore_id: str,
    body: EventCreateRequest,
    customer_firebase_uid: str,
) -> None:
    """
    Full pipeline: Analyzer → Vendor Matching → Negotiation Orchestrator.
    Runs as a FastAPI BackgroundTask (non-blocking).
    """
    from app.agents.analyzer_agent import run_analyzer_agent
    from app.db import db_session
    from app.services.vendor_matching import match_all_categories
    from app.services.negotiation_orchestrator import orchestrate_negotiations

    try:
        # Step 1: Analyzer Agent (FR-ANL-01–05)
        logger.info("Pipeline step 1: Analyzer Agent for event %s", event_id)
        allocations = await run_analyzer_agent(
            event_id=event_id,
            event_type=body.event_type,
            guest_count=body.guest_count,
            indoor_outdoor=body.indoor_outdoor,
            categories=body.categories,
            total_budget=body.total_budget,
            per_category_max=body.per_category_max,
        )

        # Step 2: Vendor Matching (FR-MTC-01–04)
        logger.info("Pipeline step 2: Vendor Matching for event %s", event_id)
        async with db_session() as db:
            category_vendors = await match_all_categories(
                db=db,
                categories=body.categories,
                city=body.city or "",
                event_date=body.event_date,
                allocations=allocations,
                guest_count=body.guest_count,
                venue_pref=body.indoor_outdoor,
            )

        # FR-MTC-04: notify customer about unmatched categories
        unmatched = [cat for cat, vendors in category_vendors.items() if not vendors]
        if unmatched:
            await _firestore_update(
                f"events/{firestore_id}",
                {
                    "unmatchedCategories": unmatched,
                    "customerNotice": "Some vendors were filtered out because their minimum price exceeds your budget. Please increase your budget to see more options.",
                },
            )
            logger.warning("Event %s: unmatched categories: %s", event_id, unmatched)

        # Step 3: Negotiation Orchestrator (FR-NEG-01, NFR-PERF-02)
        logger.info("Pipeline step 3: Negotiation Orchestrator for event %s", event_id)
        # Stamp customerFirebaseUid on all negotiation Firestore docs
        await orchestrate_negotiations(
            event_id=event_id,
            event_firestore_id=firestore_id,
            category_vendors=category_vendors,
            allocations=allocations,
            per_category_max=body.per_category_max,
        )

    except Exception as exc:
        logger.exception("Pipeline failed for event %s: %s", event_id, exc)
        await _firestore_update(
            f"events/{firestore_id}",
            {"status": "cancelled", "errorMessage": str(exc)},
        )


async def _get_or_create_user(db: AsyncSession, user: FirebaseUser) -> User:
    """Upsert a User record in Postgres from the Firebase token."""
    result = await db.execute(select(User).where(User.firebase_uid == user.uid))
    pg_user = result.scalar_one_or_none()
    if pg_user is None:
        # role can be None on very first call (Firestore write still in-flight).
        # Default to "customer" — only customers can reach this endpoint.
        pg_user = User(
            id=uuid.uuid4(),
            firebase_uid=user.uid,
            role=user.role or "customer",
            email=user.email,
        )
        db.add(pg_user)
        await db.flush()
    return pg_user
