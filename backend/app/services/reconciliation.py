"""
Reconciliation Service — Safety net for Option B vendor-reply webhook (feedback point #2).

Problem: Flutter client writes vendor reply to Firestore, then calls backend.
If the app is killed between those two steps, the Negotiation Agent never learns
the vendor replied — the negotiation stalls silently.

Solution: A periodic background job scans Firestore for negotiations where
  - isVendorTurn = False  (backend should have processed this already)
  - status is still "negotiating" or "counter_offer"  (not terminal)
  - lastActivity > STALE_THRESHOLD_SECS ago
  - The last message in the sub-collection has sender = "vendor"

If found, re-trigger the Negotiation Agent for that negotiation.
This satisfies NFR-REL-01 (retry/backoff) and NFR-REL-02 (idempotency via
last_processed_message_id ensures no duplicate offers).
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone

from apscheduler.schedulers.asyncio import AsyncIOScheduler

from app.agents.negotiation_agent import run_negotiation_agent
from app.auth import get_firestore_client
from app.config import get_settings
from app.db import db_session
from app.models.negotiation import Negotiation

logger = logging.getLogger(__name__)

_scheduler: AsyncIOScheduler | None = None

# A negotiation is "stale" if the backend hasn't processed a vendor reply
# within this many seconds of it being written
STALE_THRESHOLD_SECS = 90


def start_reconciliation_scheduler() -> None:
    """Start the APScheduler background job. Called from app lifespan."""
    global _scheduler
    settings = get_settings()
    _scheduler = AsyncIOScheduler()
    _scheduler.add_job(
        reconcile_stale_negotiations,
        "interval",
        seconds=settings.reconciliation_interval_secs,
        id="reconciliation",
        replace_existing=True,
        max_instances=1,   # never run two reconciliation jobs simultaneously
    )
    _scheduler.start()
    logger.info(
        "Reconciliation scheduler started (interval=%ds, stale_threshold=%ds)",
        settings.reconciliation_interval_secs,
        STALE_THRESHOLD_SECS,
    )


def stop_reconciliation_scheduler() -> None:
    global _scheduler
    if _scheduler and _scheduler.running:
        _scheduler.shutdown(wait=False)


async def reconcile_stale_negotiations() -> None:
    """
    Scan Firestore for negotiations that have a pending vendor reply the
    backend hasn't processed yet, and re-invoke the Negotiation Agent.
    """
    logger.debug("Reconciliation job: scanning for stale negotiations...")
    db_client = get_firestore_client()
    stale_cutoff = datetime.now(timezone.utc) - timedelta(seconds=STALE_THRESHOLD_SECS)

    try:
        # Query Firestore for negotiations where:
        #   isVendorTurn = false (backend's turn)
        #   status in [negotiating, counter_offer]
        # We can't filter lastActivity server-side efficiently without a composite index,
        # so we fetch candidates and filter locally.
        query = (
            db_client.collection("negotiations")
            .where("isVendorTurn", "==", False)
            .where("status", "in", ["negotiating", "counter_offer"])
            .limit(50)   # process at most 50 per cycle
        )
        docs = query.stream()

        stale_count = 0
        for doc in docs:
            data = doc.to_dict()
            last_activity = data.get("lastActivity")

            # Check staleness
            if last_activity is None:
                continue
            # Firestore timestamps are already datetime-like
            if hasattr(last_activity, "timestamp"):
                last_activity_dt = datetime.fromtimestamp(
                    last_activity.timestamp(), tz=timezone.utc
                )
            else:
                continue

            if last_activity_dt > stale_cutoff:
                continue  # Updated recently — not stale

            # Check if last message was from vendor
            messages = (
                db_client.collection("negotiations")
                .document(doc.id)
                .collection("messages")
                .order_by("timestamp", direction="DESCENDING")
                .limit(1)
                .stream()
            )
            last_msg = next(messages, None)
            if last_msg is None:
                continue

            last_msg_data = last_msg.to_dict()
            if last_msg_data.get("sender") != "vendor":
                continue

            # This negotiation has a vendor reply the backend hasn't processed
            logger.warning(
                "Reconciliation: found stale negotiation %s (last activity: %s). Re-triggering agent.",
                doc.id, last_activity_dt,
            )

            # Look up Postgres negotiation_id from firestore_id
            async with db_session() as db:
                from sqlalchemy import select
                result = await db.execute(
                    select(
                        Negotiation.id,
                        Negotiation.last_processed_message_id,
                        Negotiation.processing_locked_at,
                    )
                    .where(Negotiation.firestore_id == doc.id)
                )
                row = result.one_or_none()

            if row is None:
                logger.warning("No Postgres record for firestore negotiation %s", doc.id)
                continue

            neg_id, last_processed, processing_locked_at = row

            # Claim check: if locked and not expired, skip reconciliation
            if processing_locked_at is not None:
                lock_age = datetime.now(timezone.utc) - processing_locked_at.astimezone(timezone.utc)
                if lock_age.total_seconds() < 300:
                    logger.debug("Negotiation %s is currently locked by another task — skipping reconciliation", doc.id)
                    continue

            # Idempotency check: if last message is already processed, skip
            if last_processed == last_msg.id:
                logger.debug("Negotiation %s already processed message %s — skipping", doc.id, last_msg.id)
                continue

            # Re-invoke the agent
            try:
                await run_negotiation_agent(
                    negotiation_id=neg_id,
                    vendor_message_id=last_msg.id,
                    vendor_message_content=last_msg_data.get("content"),
                    vendor_offer_amount=last_msg_data.get("offerAmount"),
                    vendor_message_type=last_msg_data.get("messageType"),
                )
                stale_count += 1
            except Exception as exc:
                logger.error("Reconciliation failed to re-invoke agent for %s: %s", doc.id, exc)

        if stale_count > 0:
            logger.info("Reconciliation recovered %d stale negotiation(s)", stale_count)

    except Exception as exc:
        logger.error("Reconciliation job error: %s", exc)
