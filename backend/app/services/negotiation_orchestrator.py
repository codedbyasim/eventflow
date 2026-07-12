"""
Negotiation Orchestrator — FR-NEG-01, NFR-PERF-02
Spawns all per-vendor Negotiation Agent tasks concurrently using asyncio.gather
with per-task timeouts so a stalled vendor cannot block the Aggregator Agent.

Key guarantees:
- NFR-PERF-02: ALL vendor tasks run in true parallel (not sequential)
- FR-NEG-06:   Each task is wrapped in asyncio.wait_for(timeout=VENDOR_TIMEOUT_SECS)
               — expired tasks are caught and marked, not propagated as exceptions
- FR-NEG-01:   One independent agent task per matched vendor
- FR-AGG-01:   Aggregator runs only after all tasks reach terminal state
"""
from __future__ import annotations

import asyncio
import logging
import uuid
from datetime import datetime, timezone

from sqlalchemy import update
from sqlalchemy.dialects.postgresql import insert as pg_insert

from app.agents.aggregator_agent import run_aggregator_agent
from app.agents.negotiation_agent import run_negotiation_agent
from app.config import get_settings
from app.db import db_session
from app.models.negotiation import Negotiation
from app.services.state_sync import (
    append_negotiation_message,
    update_event_status,
    update_negotiation_status,
)
from app.services.vendor_matching import MatchedVendor

logger = logging.getLogger(__name__)


async def orchestrate_negotiations(
    event_id: uuid.UUID,
    event_firestore_id: str,
    category_vendors: dict[str, list[MatchedVendor]],
    allocations: dict[str, float],
    per_category_max: dict[str, int] | None = None,
) -> None:
    """
    Main orchestration entry point.
    1. Creates Negotiation records in Postgres + Firestore for all matched vendors.
    2. Spawns one agent task per vendor, all running concurrently.
    3. Handles per-vendor timeouts (FR-NEG-06).
    4. Runs the Aggregator Agent once all tasks finish (FR-AGG-01).

    This function is called as a FastAPI BackgroundTask so it does not
    block the HTTP response to the client.
    """
    settings = get_settings()

    # ── Create negotiation records ────────────────────────────────────────
    negotiation_ids: list[uuid.UUID] = []

    async with db_session() as db:
        from app.models.event import Event
        from sqlalchemy import select
        event_res = await db.execute(select(Event).where(Event.id == event_id))
        event = event_res.scalar_one()

        await update_event_status(db, event_id, "negotiating")

        for category, vendors in category_vendors.items():
            if not vendors:
                logger.info("Skipping category '%s' — no vendors matched (FR-MTC-04)", category)
                continue

            for vendor in vendors:
                neg_id = uuid.uuid4()
                neg_firestore_id = f"neg_{neg_id.hex[:16]}"
                allocated = int(allocations.get(category, vendor.listed_price))
                explicit_max = (per_category_max or {}).get(category)
                flexibility = float(event.negotiation_flexibility or 0.15)

                if explicit_max is not None:
                    max_budget = int(min(allocated * (1.0 + flexibility), explicit_max))
                else:
                    max_budget = int(allocated * (1.0 + flexibility))

                db.add(Negotiation(
                    id=neg_id,
                    firestore_id=neg_firestore_id,
                    event_id=event_id,
                    vendor_id=vendor.vendor_id,
                    status="connecting",
                    asking_price=vendor.listed_price,
                    floor_price=vendor.floor_price,
                    max_rounds=settings.max_negotiation_rounds,
                    is_vendor_turn=False,
                ))
                negotiation_ids.append(neg_id)

                # Mirror to Firestore immediately using state_sync helper
                from app.services.state_sync import create_negotiation_mirror
                await create_negotiation_mirror(
                    db=db,
                    negotiation_id=neg_id,
                    event=event,
                    vendor_id=vendor.vendor_id,
                    vendor_firebase_uid=vendor.firebase_uid,
                    vendor_name=vendor.business_name,
                    vendor_category=category,
                    neg_firestore_id=neg_firestore_id,
                    allocated_budget=allocated,
                    max_budget=max_budget,
                    asking_price=vendor.listed_price,
                    max_rounds=settings.max_negotiation_rounds,
                )

        await db.commit()

    if not negotiation_ids:
        logger.warning("No negotiations created for event %s — running aggregator with empty results", event_id)
        await run_aggregator_agent(event_id, event_firestore_id)
        return

    # ── Spawn all negotiation tasks concurrently (NFR-PERF-02) ───────────
    logger.info(
        "Spawning %d parallel negotiation tasks for event %s",
        len(negotiation_ids), event_id,
    )

    tasks = [
        _run_with_timeout(neg_id, settings.vendor_timeout_secs)
        for neg_id in negotiation_ids
    ]

    # asyncio.gather: all tasks run truly concurrently; return_exceptions=True
    # means one failed task doesn't cancel the others
    results = await asyncio.gather(*tasks, return_exceptions=True)

    for neg_id, result in zip(negotiation_ids, results):
        if isinstance(result, Exception):
            logger.error("Negotiation task %s raised exception: %s", neg_id, result)

    # Initial offers have been sent. The event remains in "negotiating" status
    # until vendors reply and negotiations reach terminal states (deal/no_deal/expired).


async def _run_with_timeout(
    negotiation_id: uuid.UUID,
    timeout_secs: int,
) -> dict:
    """
    Run a single negotiation agent with a per-vendor timeout.
    FR-NEG-06: if timeout elapses, mark negotiation as expired.
    This does NOT raise — it returns a result dict describing what happened.
    """
    try:
        return await asyncio.wait_for(
            run_negotiation_agent(negotiation_id),
            timeout=float(timeout_secs),
        )
    except asyncio.TimeoutError:
        logger.warning(
            "Negotiation %s timed out after %ds — marking expired (FR-NEG-06)",
            negotiation_id, timeout_secs,
        )
        async with db_session() as db:
            await update_negotiation_status(
                db, negotiation_id,
                status="expired",
                is_vendor_turn=False,
            )
            await append_negotiation_message(
                db, negotiation_id,
                sender="system",
                content=f"Negotiation expired: vendor did not respond within {timeout_secs}s.",
                message_type="system",
            )
            await db.commit()
        return {"action": "expired", "negotiation_id": str(negotiation_id)}
    except Exception as exc:
        logger.exception("Unexpected error in negotiation task %s", negotiation_id)
        try:
            from sqlalchemy import update
            async with db_session() as db:
                await db.execute(
                    update(Negotiation)
                    .where(Negotiation.id == negotiation_id)
                    .values(processing_locked_at=None)
                )
                await db.commit()
        except Exception as db_exc:
            logger.warning("Could not clear lock on unexpected task error: %s", db_exc)
        return {"action": "error", "negotiation_id": str(negotiation_id), "error": str(exc)}
