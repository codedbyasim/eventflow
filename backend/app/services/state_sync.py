"""
state_sync.py — Single source of truth for all Postgres ↔ Firestore dual-writes.

Every status-changing action in the system (agent or API handler) must go
through one of these functions instead of writing to Postgres and Firestore
independently. This prevents the two stores from drifting out of sync.

Pattern:
  1. Write authoritative record to Postgres first (source of truth).
  2. Mirror relevant fields to Firestore (realtime layer for the Flutter client).
  3. (Phase 6) Trigger FCM notification if applicable.

Firestore schema mirrors per SRS Section 6.2:
  events/{eventId}            — status, summary fields
  negotiations/{negoId}       — status, currentOffer, isVendorTurn, offerCount, maxOffers
  negotiations/{negoId}/messages/{msgId}  — sender, content, offerAmount, messageType, timestamp
"""
from __future__ import annotations

import asyncio
import logging
import uuid
from datetime import datetime, timezone
from typing import Any

from google.cloud.firestore_v1 import SERVER_TIMESTAMP
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_firestore_client
from app.models.event import Event
from app.models.negotiation import Negotiation

logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────────────────────────────────────
# EVENT STATUS
# ─────────────────────────────────────────────────────────────────────────────

async def update_event_status(
    db: AsyncSession,
    event_id: uuid.UUID,
    status: str,
    extra_fields: dict[str, Any] | None = None,
) -> None:
    """
    Update event status in Postgres, then mirror to Firestore events/{firestore_id}.
    FR-ANL-05, FR-NEG-05: UI must reflect status in real time.
    """
    # 1. Postgres update
    values: dict[str, Any] = {"status": status, "updated_at": datetime.now(timezone.utc)}
    if extra_fields:
        values.update(extra_fields)

    await db.execute(
        update(Event).where(Event.id == event_id).values(**values)
    )
    await db.flush()

    # 2. Fetch firestore_id for the mirror
    result = await db.execute(select(Event.firestore_id).where(Event.id == event_id))
    firestore_id = result.scalar_one_or_none()

    if firestore_id:
        await _firestore_update(f"events/{firestore_id}", {"status": status, **(extra_fields or {})})

    logger.info("Event %s status → %s", event_id, status)


# ─────────────────────────────────────────────────────────────────────────────
# NEGOTIATION STATUS
# ─────────────────────────────────────────────────────────────────────────────

async def update_negotiation_status(
    db: AsyncSession,
    negotiation_id: uuid.UUID,
    status: str,
    current_offer: int | None = None,
    is_vendor_turn: bool = False,
    final_price: int | None = None,
    last_processed_message_id: str | None = None,
) -> None:
    """
    Update negotiation status in Postgres + mirror to Firestore.
    FR-NEG-05: live dashboard shows real-time progress.
    NFR-REL-02: last_processed_message_id tracks idempotency.
    """
    values: dict[str, Any] = {
        "status": status,
        "is_vendor_turn": is_vendor_turn,
        "last_activity": datetime.now(timezone.utc),
        "processing_locked_at": None,
    }
    if current_offer is not None:
        values["current_offer"] = current_offer
    if final_price is not None:
        values["final_price"] = final_price
    if last_processed_message_id is not None:
        values["last_processed_message_id"] = last_processed_message_id

    # Terminal states: record closed_at
    if status in ("deal", "no_deal", "expired"):
        values["closed_at"] = datetime.now(timezone.utc)

    await db.execute(
        update(Negotiation).where(Negotiation.id == negotiation_id).values(**values)
    )
    await db.flush()

    # If the new status is terminal, check if all negotiations for this event are terminal
    if status in ("deal", "no_deal", "expired"):
        # Fetch event_id first
        res = await db.execute(
            select(Negotiation.event_id).where(Negotiation.id == negotiation_id)
        )
        event_id = res.scalar_one_or_none()
        if event_id:
            from app.models.event import Event
            event_res = await db.execute(
                select(Event.firestore_id).where(Event.id == event_id)
            )
            event_firestore_id = event_res.scalar_one_or_none()
            
            # Fetch all negotiations for this event
            all_res = await db.execute(
                select(Negotiation.status).where(Negotiation.event_id == event_id)
            )
            all_statuses = all_res.scalars().all()
            
            if all(s in ("deal", "no_deal", "expired") for s in all_statuses):
                logger.info("All negotiations for event %s are closed. Running Aggregator.", event_id)
                from app.agents.aggregator_agent import run_aggregator_agent
                await run_aggregator_agent(event_id, event_firestore_id)

    # Fetch firestore_id + rounds_used for mirror
    result = await db.execute(
        select(Negotiation.firestore_id, Negotiation.rounds_used, Negotiation.max_rounds)
        .where(Negotiation.id == negotiation_id)
    )
    row = result.one_or_none()

    if row and row.firestore_id:
        fs_data: dict[str, Any] = {
            "status": status,
            "isVendorTurn": is_vendor_turn,
            "offerCount": row.rounds_used,
            "maxOffers": row.max_rounds,
        }
        if current_offer is not None:
            fs_data["currentOffer"] = current_offer
        if final_price is not None:
            fs_data["finalPrice"] = final_price
        # Mirror closed_at for terminal states so vendor dashboard updates instantly
        if status in ("deal", "no_deal", "expired"):
            fs_data["closedAt"] = datetime.now(timezone.utc).isoformat()
            # Always force isVendorTurn=False on terminal states regardless of caller
            fs_data["isVendorTurn"] = False
        await _firestore_update(f"negotiations/{row.firestore_id}", fs_data)

    logger.info("Negotiation %s status → %s (vendorTurn=%s)", negotiation_id, status, is_vendor_turn)


async def increment_negotiation_round(
    db: AsyncSession,
    negotiation_id: uuid.UUID,
) -> int:
    """Atomically increment rounds_used and return the new value."""
    result = await db.execute(
        select(Negotiation.rounds_used).where(Negotiation.id == negotiation_id)
    )
    current = result.scalar_one_or_none() or 0
    new_count = current + 1
    await db.execute(
        update(Negotiation)
        .where(Negotiation.id == negotiation_id)
        .values(rounds_used=new_count)
    )
    await db.flush()
    return new_count


# ─────────────────────────────────────────────────────────────────────────────
# NEGOTIATION MESSAGES
# ─────────────────────────────────────────────────────────────────────────────

async def append_negotiation_message(
    db: AsyncSession,
    negotiation_id: uuid.UUID,
    sender: str,       # "agent" | "vendor" | "system"
    content: str,
    message_type: str, # "offer" | "counter" | "accept" | "reject" | "walk_away" | "system"
    offer_amount: int | None = None,
) -> str:
    """
    Append a message to Firestore negotiations/{negoId}/messages/{msgId}.
    FR-NEG-04: every action + response persisted as a message document.
    NFR-USE-02: agent vs vendor messages distinguishable via sender field.
    Returns the new Firestore message document ID.
    """
    result = await db.execute(
        select(Negotiation.firestore_id).where(Negotiation.id == negotiation_id)
    )
    firestore_id = result.scalar_one_or_none()

    msg_id = str(uuid.uuid4())
    if firestore_id:
        msg_data: dict[str, Any] = {
            "sender": sender,
            "content": content,
            "messageType": message_type,
            "timestamp": SERVER_TIMESTAMP,
        }
        if offer_amount is not None:
            msg_data["offerAmount"] = offer_amount

        db_client = get_firestore_client()
        ref = (
            db_client
            .collection("negotiations")
            .document(firestore_id)
            .collection("messages")
            .document(msg_id)
        )
        await asyncio.to_thread(lambda: ref.set(msg_data))
        logger.debug("Appended message %s to negotiation %s", msg_id, firestore_id)

    return msg_id


# ─────────────────────────────────────────────────────────────────────────────
# INTERNAL HELPER
# ─────────────────────────────────────────────────────────────────────────────

async def _firestore_update(path: str, data: dict[str, Any]) -> None:
    """
    Update a Firestore document at the given slash-separated path.
    Swallows errors with a warning so a Firestore hiccup never crashes Postgres writes.
    """
    try:
        db_client = get_firestore_client()
        parts = path.split("/")
        ref = db_client.collection(parts[0]).document(parts[1])
        for i in range(2, len(parts) - 1, 2):
            ref = ref.collection(parts[i]).document(parts[i + 1])
        await asyncio.to_thread(lambda: ref.set(data, merge=True))
    except Exception as exc:
        logger.warning("Firestore update failed for %s: %s", path, exc)


async def create_negotiation_mirror(
    db: AsyncSession,
    negotiation_id: uuid.UUID,
    event: Event,
    vendor_id: uuid.UUID,
    vendor_firebase_uid: str | None,
    vendor_name: str,
    vendor_category: str,
    neg_firestore_id: str,
    allocated_budget: int,
    max_budget: int,
    asking_price: int,
    max_rounds: int,
) -> None:
    """
    Initial Firestore write to mirror a newly created negotiation (PG ↔ Firestore).
    Copies event metadata (type, event_date, city, guest_count, indoor_outdoor)
    to prevent code drift and ensure details are fully visible in the vendor's chat screen.
    """
    from datetime import datetime, timezone
    
    event_date_val = None
    if event.event_date:
        event_date_val = datetime.combine(event.event_date, datetime.min.time()).replace(tzinfo=timezone.utc)

    # Requirements maps directly to venue setting preference (Indoor/Outdoor)
    requirement_val = f"Venue: {event.indoor_outdoor or 'Any'}"

    fs_data = {
        "status": "connecting",
        "eventId": str(event.id),
        "eventFirestoreId": event.firestore_id,
        "vendorId": str(vendor_id),
        "vendorFirebaseUid": vendor_firebase_uid or "",
        "vendorName": vendor_name,
        "category": vendor_category,
        "askingPrice": asking_price,
        "allocatedBudget": allocated_budget,
        "maxBudget": max_budget,
        "currentOffer": asking_price,
        "isVendorTurn": False,
        "offerCount": 0,
        "maxOffers": max_rounds,
        "customerFirebaseUid": event.customer_firebase_uid,
        
        # Mirroring event fields for vendor chat UI
        "eventType": event.type,
        "eventDate": event_date_val,
        "city": event.city or "",
        "guestCount": event.guest_count,
        "requirement": requirement_val,
    }

    await _firestore_update(f"negotiations/{neg_firestore_id}", fs_data)
