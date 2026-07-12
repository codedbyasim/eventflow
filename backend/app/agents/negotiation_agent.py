"""
Negotiation Agent — FR-NEG-01 to FR-NEG-07
One instance per vendor. Called initially by the orchestrator and re-invoked
each time a vendor submits a manual reply (FR-VND-03).

Key design decisions:
- Idempotent per round: last_processed_message_id prevents re-processing (NFR-REL-02).
- Each task is wrapped in asyncio.wait_for() by the orchestrator so a stalled
  vendor cannot block the Aggregator Agent (FR-NEG-06, FR-AGG-01).
- Writes every action to Firestore via state_sync.append_negotiation_message
  so the live dashboard updates in real time (FR-NEG-04, NFR-PERF-03).
"""
from __future__ import annotations

import logging
import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.agents.fireworks_client import FireworksError, call_fireworks
from app.agents.prompts import NEGOTIATION_SYSTEM_PROMPT, NEGOTIATION_TOOLS
from app.config import get_settings
from app.db import db_session
from app.models.negotiation import Negotiation
from app.services.state_sync import (
    append_negotiation_message,
    increment_negotiation_round,
    update_negotiation_status,
)

logger = logging.getLogger(__name__)


def _normalize_offer_amount(amount: Any, asking_price: int, allocated_budget: int, max_budget: int, current_round: int) -> int:
    """Clamp negotiation offers to the customer's spending envelope and keep early rounds conservative."""
    try:
        raw_value = int(amount)
    except (TypeError, ValueError):
        raw_value = asking_price

    hard_cap = min(max_budget, allocated_budget)
    if hard_cap <= 0:
        return 0

    # Make initial rounds more conservative, then allow a modest step-up toward the cap.
    if current_round <= 1:
        target = min(raw_value, int(hard_cap * 0.9))
    elif current_round == 2:
        target = min(raw_value, int(hard_cap * 0.95))
    else:
        target = min(raw_value, hard_cap)

    return max(0, min(target, hard_cap))


def should_accept_vendor_price(vendor_amount: Any, allocated_budget: int, max_budget: int) -> bool:
    """Return True when the vendor's price fits inside the customer's allowed envelope."""
    try:
        numeric_amount = int(vendor_amount)
    except (TypeError, ValueError):
        return False

    hard_cap = min(max_budget, allocated_budget)
    return hard_cap > 0 and 0 <= numeric_amount <= hard_cap


async def run_negotiation_agent(
    negotiation_id: uuid.UUID,
    vendor_message_id: str | None = None,  # ID of the vendor message that triggered this call
    vendor_message_content: str | None = None,
    vendor_offer_amount: int | None = None,
    vendor_message_type: str | None = None,   # "counter" | "accept" | "reject" | None (initial)
) -> dict[str, Any]:
    """
    Run one decision turn of the Negotiation Agent.

    On initial call (vendor_message_id=None): agent sends the first offer.
    On re-invocation (vendor replied): agent processes the vendor's response and acts.

    Returns a dict describing the action taken:
      {"action": "send_offer"|"accept_vendor_price"|"walk_away", ...}

    NFR-REL-02 idempotency:
      If vendor_message_id matches last_processed_message_id in Postgres, this
      is a duplicate invocation — return early without making any new LLM call.
    """
    settings = get_settings()

    async with db_session() as db:
        # Atomic lock claim (using compare-and-swap)
        from sqlalchemy import update, or_
        from datetime import datetime, timezone, timedelta
        
        five_minutes_ago = datetime.now(timezone.utc) - timedelta(minutes=5)
        
        result = await db.execute(
            update(Negotiation)
            .where(
                Negotiation.id == negotiation_id,
                or_(
                    Negotiation.processing_locked_at.is_(None),
                    Negotiation.processing_locked_at < five_minutes_ago
                )
            )
            .values(processing_locked_at=datetime.now(timezone.utc))
            .returning(Negotiation.id)
        )
        claimed = result.scalar_one_or_none()
        
        if claimed is None:
            logger.info("Negotiation %s is currently claimed/locked by another task. Skipping.", negotiation_id)
            return {"action": "locked_skipped"}

        # Load the negotiation record to verify details
        neg = await _fetch_negotiation(db, negotiation_id)
        if neg is None:
            logger.error("Negotiation %s not found", negotiation_id)
            return {"action": "error", "reason": "negotiation not found"}

        # ── Idempotency check (NFR-REL-02) ───────────────────────────────
        if vendor_message_id and neg.last_processed_message_id == vendor_message_id:
            logger.info(
                "Skipping duplicate invocation for negotiation %s, message %s",
                negotiation_id, vendor_message_id,
            )
            neg.processing_locked_at = None
            await db.commit()
            return {"action": "duplicate_skipped"}

        # ── Terminal state guard ──────────────────────────────────────────
        if neg.status in ("deal", "no_deal", "expired"):
            logger.info("Negotiation %s already terminal: %s", negotiation_id, neg.status)
            neg.processing_locked_at = None
            await db.commit()
            return {"action": "terminal", "status": neg.status}

        # ── Handle vendor accept / reject (no LLM call needed) ───────────
        if vendor_message_type == "accept":
            await update_negotiation_status(
                db, negotiation_id,
                status="deal",
                final_price=neg.current_offer or neg.asking_price,
                is_vendor_turn=False,
                last_processed_message_id=vendor_message_id,
            )
            neg.processing_locked_at = None
            await db.commit()
            logger.info("Negotiation %s: vendor accepted. Deal!", negotiation_id)
            from app.services.notifications import notify_customer_on_negotiation_update
            await notify_customer_on_negotiation_update(
                db, negotiation_id,
                title="Vendor Accepted Offer!",
                body=f"The vendor has accepted the offer of PKR {neg.current_offer or neg.asking_price:,}!",
                action_type="accept",
            )
            return {"action": "deal_confirmed", "final_price": neg.current_offer}

        if vendor_message_type == "reject":
            await update_negotiation_status(
                db, negotiation_id,
                status="no_deal",
                is_vendor_turn=False,
                last_processed_message_id=vendor_message_id,
            )
            await append_negotiation_message(
                db, negotiation_id,
                sender="system", content="Vendor rejected the offer.", message_type="system"
            )
            neg.processing_locked_at = None
            await db.commit()
            logger.info("Negotiation %s: vendor rejected. No deal.", negotiation_id)
            from app.services.notifications import notify_customer_on_negotiation_update
            await notify_customer_on_negotiation_update(
                db, negotiation_id,
                title="Vendor Rejected Offer",
                body="The vendor has rejected the negotiation.",
                action_type="reject",
            )
            return {"action": "no_deal", "reason": "vendor rejected"}

        # ── Prepare context for LLM ───────────────────────────────────────
        current_round = neg.rounds_used + 1
        max_rounds = neg.max_rounds

        if current_round > max_rounds:
            # Max rounds exceeded — walk away (FR-NEG-07)
            await _walk_away(db, negotiation_id, "Maximum negotiation rounds reached.", vendor_message_id)
            neg.processing_locked_at = None
            await db.commit()
            from app.services.notifications import notify_vendor_on_negotiation_update
            await notify_vendor_on_negotiation_update(
                db, negotiation_id,
                title="Negotiation Closed",
                body="Maximum negotiation rounds reached.",
                action_type="agent_walk_away",
            )
            return {"action": "walk_away", "reason": "max rounds reached"}

        from app.models.event_vendor_allocation import EventVendorAllocation
        
        allocation_stmt = select(EventVendorAllocation).where(
            EventVendorAllocation.event_id == neg.event_id,
            EventVendorAllocation.category == neg.vendor.category
        )
        allocation_res = await db.execute(allocation_stmt)
        allocation = allocation_res.scalar_one_or_none()
        
        if allocation:
            allocated_budget = allocation.allocated_amount
            max_budget = allocation.max_budget or int(allocation.allocated_amount * 1.1)
        else:
            allocated_budget = int(neg.asking_price * 0.85)
            max_budget = neg.asking_price

        system_prompt = NEGOTIATION_SYSTEM_PROMPT.format(
            allocated_budget=allocated_budget,
            max_budget=max_budget,
            asking_price=neg.asking_price,
            current_round=current_round,
            max_rounds=max_rounds,
        )

        # If the vendor's latest counter is already within budget, accept it immediately.
        if vendor_message_content and vendor_offer_amount is not None:
            if should_accept_vendor_price(vendor_offer_amount, allocated_budget, max_budget):
                amount = _normalize_offer_amount(vendor_offer_amount, neg.asking_price, allocated_budget, max_budget, current_round)
                await append_negotiation_message(
                    db, negotiation_id,
                    sender="agent", content=f"We accept your price of {amount:,} PKR.",
                    message_type="accept", offer_amount=amount,
                )
                await update_negotiation_status(
                    db, negotiation_id,
                    status="deal", final_price=amount,
                    is_vendor_turn=False, last_processed_message_id=vendor_message_id,
                )
                neg.processing_locked_at = None
                await db.commit()
                logger.info("Negotiation %s: accepted vendor counter %d PKR within budget", negotiation_id, amount)
                from app.services.notifications import notify_vendor_on_negotiation_update
                await notify_vendor_on_negotiation_update(
                    db, negotiation_id,
                    title="Agent Accepted Offer!",
                    body=f"The agent has accepted your counter-offer of PKR {amount:,}!",
                    action_type="agent_accept",
                )
                return {"action": "accept_vendor_price", "amount": amount}

        # Build message thread for context
        messages: list[dict] = [{"role": "system", "content": system_prompt}]

        # Add vendor's latest counter if applicable
        if vendor_message_content and vendor_offer_amount is not None:
            messages.append({
                "role": "user",
                "content": (
                    f"The vendor has countered with: {vendor_offer_amount:,} PKR\n"
                    f"Their message: {vendor_message_content}\n"
                    f"This is round {current_round} of {max_rounds}. Decide your next move."
                ),
            })
            from app.services.notifications import notify_customer_on_negotiation_update
            await notify_customer_on_negotiation_update(
                db, negotiation_id,
                title="Vendor counter-offer received",
                body=f"The vendor countered with PKR {vendor_offer_amount:,}.",
                action_type="vendor_counter",
            )
        else:
            # Initial offer turn
            messages.append({
                "role": "user",
                "content": (
                    f"Start the negotiation. The vendor's asking price is {neg.asking_price:,} PKR. "
                    f"This is round {current_round} of {max_rounds}. Send your opening offer."
                ),
            })

    # ── LLM call (outside db session to avoid holding connection during I/O) ──
    try:
        result = await call_fireworks(
            messages=messages,
            tools=NEGOTIATION_TOOLS,
            agent_type="negotiation",
            event_id=None,   # event_id resolved later; negotiation_id is sufficient
            negotiation_id=negotiation_id,
            max_tokens=4096,
        )
    except FireworksError as exc:
        logger.error("Fireworks AI error in negotiation %s: %s", negotiation_id, exc)
        # NFR-REL-01: mark as needing attention, not a hard failure
        async with db_session() as db:
            neg = await _fetch_negotiation(db, negotiation_id)
            if neg:
                neg.processing_locked_at = None
            await update_negotiation_status(
                db, negotiation_id, status="expired",
                is_vendor_turn=False, last_processed_message_id=vendor_message_id
            )
            await append_negotiation_message(
                db, negotiation_id, sender="system",
                content="AI service temporarily unavailable. Negotiation paused.",
                message_type="system",
            )
            await db.commit()
        return {"action": "error", "reason": str(exc)}

    # ── Parse and act on the tool call ───────────────────────────────────────
    async with db_session() as db:
        neg = await _fetch_negotiation(db, negotiation_id)
        if neg is None:
            return {"action": "error", "reason": "negotiation disappeared"}

        # Release processing lock
        neg.processing_locked_at = None

        # Determine which tool was called from the result keys
        if "amount" in result and "message" in result:
            action = "send_offer"
        elif "amount" in result:
            action = "accept_vendor_price"
        elif "reason" in result:
            action = "walk_away"
        else:
            action = "send_offer"  # fallback

        new_round = await increment_negotiation_round(db, negotiation_id)

        if action == "send_offer":
            offer_amount = _normalize_offer_amount(result.get("amount"), neg.asking_price, allocated_budget, max_budget, current_round)
            msg_content = result.get("message", f"We'd like to offer {offer_amount:,} PKR for your services.")
            msg_id = await append_negotiation_message(
                db, negotiation_id,
                sender="agent", content=msg_content,
                message_type="offer", offer_amount=offer_amount,
            )
            await update_negotiation_status(
                db, negotiation_id,
                status="negotiating" if new_round == 1 else "counter_offer",
                current_offer=offer_amount,
                is_vendor_turn=True,
                last_processed_message_id=vendor_message_id,
            )
            await db.commit()
            logger.info("Negotiation %s: agent sent offer %d PKR (round %d)", negotiation_id, offer_amount, new_round)
            from app.services.notifications import notify_vendor_on_negotiation_update
            await notify_vendor_on_negotiation_update(
                db, negotiation_id,
                title="New Offer from Agent",
                body=f"The agent has countered with PKR {offer_amount:,}.",
                action_type="agent_offer",
            )
            return {"action": "send_offer", "amount": offer_amount, "round": new_round}

        elif action == "accept_vendor_price":
            amount = _normalize_offer_amount(result.get("amount"), neg.asking_price, allocated_budget, max_budget, current_round)
            if not should_accept_vendor_price(amount, allocated_budget, max_budget):
                amount = _normalize_offer_amount(allocated_budget, neg.asking_price, allocated_budget, max_budget, current_round)
            await append_negotiation_message(
                db, negotiation_id,
                sender="agent", content=f"We accept your price of {amount:,} PKR.",
                message_type="accept", offer_amount=amount,
            )
            await update_negotiation_status(
                db, negotiation_id,
                status="deal", final_price=amount,
                is_vendor_turn=False, last_processed_message_id=vendor_message_id,
            )
            await db.commit()
            logger.info("Negotiation %s: agent accepted %d PKR. Deal!", negotiation_id, amount)
            from app.services.notifications import notify_vendor_on_negotiation_update
            await notify_vendor_on_negotiation_update(
                db, negotiation_id,
                title="Agent Accepted Offer!",
                body=f"The agent has accepted your counter-offer of PKR {amount:,}!",
                action_type="agent_accept",
            )
            return {"action": "accept_vendor_price", "amount": amount}

        else:  # walk_away
            reason = result.get("reason", "Budget not aligned.")
            await _walk_away(db, negotiation_id, reason, vendor_message_id)
            await db.commit()
            logger.info("Negotiation %s: agent walked away. Reason: %s", negotiation_id, reason)
            from app.services.notifications import notify_vendor_on_negotiation_update
            await notify_vendor_on_negotiation_update(
                db, negotiation_id,
                title="Negotiation Closed",
                body="The agent has decided to walk away.",
                action_type="agent_walk_away",
            )
            return {"action": "walk_away", "reason": reason}


# ─────────────────────────────────────────────────────────────────────────────

async def _fetch_negotiation(db: AsyncSession, negotiation_id: uuid.UUID) -> Negotiation | None:
    from sqlalchemy.orm import selectinload
    result = await db.execute(
        select(Negotiation)
        .options(
            selectinload(Negotiation.vendor),
            selectinload(Negotiation.event)
        )
        .where(Negotiation.id == negotiation_id)
    )
    return result.scalar_one_or_none()


async def _walk_away(
    db: AsyncSession,
    negotiation_id: uuid.UUID,
    reason: str,
    last_message_id: str | None,
) -> None:
    await append_negotiation_message(
        db, negotiation_id,
        sender="agent",
        content=f"We were unable to reach an agreement. {reason}",
        message_type="walk_away",
    )
    await update_negotiation_status(
        db, negotiation_id,
        status="no_deal",
        is_vendor_turn=False,
        last_processed_message_id=last_message_id,
    )
