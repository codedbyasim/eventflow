"""
Analyzer Agent — FR-ANL-01 to FR-ANL-05
Parses event requirements and produces a per-category budget allocation.
Persists the result to Postgres (event_vendor_allocations) and mirrors to Firestore.
"""
from __future__ import annotations

import json
import logging
import uuid
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.agents.fireworks_client import call_fireworks
from app.agents.prompts import ANALYZER_SYSTEM_PROMPT, ANALYZER_TOOLS
from app.db import db_session
from app.models.event import Event
from app.models.event_vendor_allocation import EventVendorAllocation
from app.services.state_sync import update_event_status

logger = logging.getLogger(__name__)


async def run_analyzer_agent(
    event_id: uuid.UUID,
    event_type: str,
    guest_count: int,
    indoor_outdoor: str | None,
    categories: list[str],
    total_budget: int,
    per_category_max: dict[str, int] | None = None,  # FR-ANL-04
) -> dict[str, float]:
    """
    Run the Analyzer Agent for a given event.

    Returns: dict mapping category → allocated amount (PKR)
    Side-effects:
      - Sets event status to 'analyzing' then 'matching' via state_sync
      - Writes EventVendorAllocation rows to Postgres
      - Persists reasoning to Event.analyzer_reasoning
    """
    logger.info("Analyzer Agent starting for event %s", event_id)

    async with db_session() as db:
        # FR-ANL-05: mark event as 'analyzing'
        await update_event_status(db, event_id, "analyzing")
        await db.commit()

    # Build the user message
    per_max_note = ""
    if per_category_max:
        per_max_note = "\nPer-category maximum budgets (hard ceiling, FR-ANL-04):\n"
        for cat, max_amt in per_category_max.items():
            per_max_note += f"  {cat}: {max_amt:,} PKR max\n"

    user_message = (
        f"Event type: {event_type}\n"
        f"Guest count: {guest_count}\n"
        f"Venue preference: {indoor_outdoor or 'Not specified'}\n"
        f"Required vendor categories: {', '.join(categories)}\n"
        f"Total budget: {total_budget:,} PKR\n"
        f"{per_max_note}"
        f"\nPlease call allocate_budget with a fair distribution."
    )

    result = await call_fireworks(
        messages=[
            {"role": "system", "content": ANALYZER_SYSTEM_PROMPT},
            {"role": "user", "content": user_message},
        ],
        tools=ANALYZER_TOOLS,
        agent_type="analyzer",
        event_id=event_id,
    )

    allocations: dict[str, float] = result.get("allocations", {})
    reasoning: str = result.get("reasoning", "")

    # Validate: allocations must not exceed total_budget (FR-ANL-02)
    total_allocated = sum(allocations.values())
    if total_allocated > total_budget * 1.01:  # 1% tolerance for float rounding
        logger.warning(
            "Analyzer over-allocated: %s > %s. Scaling down.", total_allocated, total_budget
        )
        scale = total_budget / total_allocated
        allocations = {k: v * scale for k, v in allocations.items()}

    # Enforce per-category ceilings (FR-ANL-04)
    if per_category_max:
        for cat, cap in per_category_max.items():
            if cat in allocations and allocations[cat] > cap:
                allocations[cat] = float(cap)

    # Persist to Postgres
    async with db_session() as db:
        # Save reasoning on the Event record
        from sqlalchemy import update
        from app.models.event import Event as EventModel
        await db.execute(
            update(EventModel)
            .where(EventModel.id == event_id)
            .values(analyzer_reasoning=json.dumps({
                "reasoning": reasoning,
                "raw_allocations": allocations,
            }))
        )

        # Write one row per category
        for category, amount in allocations.items():
            max_val = per_category_max.get(category) if per_category_max else None
            db.add(EventVendorAllocation(
                id=uuid.uuid4(),
                event_id=event_id,
                category=category,
                allocated_amount=int(amount),
                max_budget=max_val,
            ))

        # FR-ANL-05: mark event as 'matching'
        await update_event_status(db, event_id, "matching")
        await db.commit()

    logger.info(
        "Analyzer Agent done for event %s. Allocations: %s",
        event_id,
        {k: int(v) for k, v in allocations.items()},
    )
    return allocations
