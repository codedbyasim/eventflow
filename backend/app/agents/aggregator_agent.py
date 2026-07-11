"""
Aggregator Agent — FR-AGG-01 to FR-AGG-04
Runs once all negotiations for an event reach a terminal state.
Compiles the best vendor package and writes results to Firestore for the customer dashboard.
"""
from __future__ import annotations

import logging
import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.agents.fireworks_client import call_fireworks
from app.agents.prompts import AGGREGATOR_SYSTEM_PROMPT, AGGREGATOR_TOOLS
from app.db import db_session
from app.models.negotiation import Negotiation
from app.models.vendor import Vendor
from app.models.event_vendor_allocation import EventVendorAllocation
from app.services.state_sync import update_event_status, _firestore_update

logger = logging.getLogger(__name__)


async def run_aggregator_agent(
    event_id: uuid.UUID,
    event_firestore_id: str,
) -> dict[str, Any]:
    """
    Compile the best vendor package for the event.

    FR-AGG-01: Runs after all negotiations are terminal.
    FR-AGG-02: Computes best per-category deal, total cost, savings.
    FR-AGG-03: Flags categories where selected price > allocated budget.
    FR-AGG-04: Writes results to Firestore for the customer's 'Best Combination' screen.

    Returns the compiled package dict.
    """
    logger.info("Aggregator Agent starting for event %s", event_id)

    async with db_session() as db:
        # Fetch all negotiations for this event
        neg_result = await db.execute(
            select(Negotiation, Vendor)
            .join(Vendor, Negotiation.vendor_id == Vendor.id)
            .where(Negotiation.event_id == event_id)
        )
        negotiations = neg_result.all()  # list of (Negotiation, Vendor) tuples

        # Fetch allocations for budget comparison (FR-AGG-03)
        alloc_result = await db.execute(
            select(EventVendorAllocation).where(EventVendorAllocation.event_id == event_id)
        )
        allocations = {a.category: a.allocated_amount for a in alloc_result.scalars().all()}

        # Mark event as aggregating
        await update_event_status(db, event_id, "aggregating")
        await db.commit()

    if not negotiations:
        logger.warning("No negotiations found for event %s — skipping aggregation", event_id)
        empty_package = {
            "best_vendors": {},
            "total_cost": 0,
            "total_savings": 0,
            "savings_percentage": 0,
            "summary": "No verified vendors were matched for this event.",
        }
        await _firestore_update(
            f"events/{event_firestore_id}",
            {
                "package": empty_package,
                "status": "ready",
            },
        )
        async with db_session() as db:
            await update_event_status(db, event_id, "ready")
            await db.commit()
        return empty_package

    # Build context for the LLM
    nego_context_lines = []
    for neg, vendor in negotiations:
        nego_context_lines.append(
            f"Category: {vendor.category} | Vendor: {vendor.business_name} | "
            f"Status: {neg.status} | "
            f"Asking: {neg.asking_price:,} PKR | "
            f"Final price: {(neg.final_price or neg.asking_price):,} PKR | "
            f"Negotiation ID: {neg.id}"
        )
    nego_summary = "\n".join(nego_context_lines)

    alloc_lines = [f"  {cat}: {amt:,} PKR" for cat, amt in allocations.items()]
    alloc_summary = "\n".join(alloc_lines)

    user_message = (
        f"Negotiations for this event:\n{nego_summary}\n\n"
        f"Allocated budgets per category:\n{alloc_summary}\n\n"
        "Please call compile_package to select the best vendor per category."
    )

    result = await call_fireworks(
        messages=[
            {"role": "system", "content": AGGREGATOR_SYSTEM_PROMPT},
            {"role": "user", "content": user_message},
        ],
        tools=AGGREGATOR_TOOLS,
        agent_type="aggregator",
        event_id=event_id,
        max_tokens=4096,
    )

    # Mirror package to Firestore for the Flutter 'Best Combination' screen
    await _firestore_update(
        f"events/{event_firestore_id}",
        {
            "package": result,
            "status": "ready",
        },
    )

    # Update Postgres event status
    async with db_session() as db:
        await update_event_status(db, event_id, "ready")
        await db.commit()

    logger.info(
        "Aggregator done for event %s. Total cost: %s PKR, Savings: %s PKR (%.1f%%)",
        event_id,
        result.get("total_cost", 0),
        result.get("total_savings", 0),
        result.get("savings_percentage", 0),
    )

    return result
