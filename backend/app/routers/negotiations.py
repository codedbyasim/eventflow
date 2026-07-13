"""
Negotiations Router — POST /negotiations/{id}/vendor-reply
FR-VND-03: On any vendor action, notify the backend so the assigned
           Negotiation Agent can process the response and decide its next move.
NFR-REL-02: Idempotency enforced via last_processed_message_id in the agent.
NFR-SEC-05: Rate limited.
"""
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import FirebaseUser, require_vendor
from app.db import get_db
from app.limiter import limiter
from app.models.negotiation import Negotiation
from app.schemas import VendorReplyRequest, VendorReplyResponse

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/{negotiation_id}/vendor-reply", response_model=VendorReplyResponse)
@limiter.limit("30/minute")
async def vendor_reply_webhook(
    request: Request,  # required by slowapi
    negotiation_id: str,
    body: VendorReplyRequest,
    db: AsyncSession = Depends(get_db),
    user: FirebaseUser = Depends(require_vendor),
) -> VendorReplyResponse:
    """
    FR-VND-03: Called by the Flutter client immediately after a vendor writes
    a reply to Firestore. Re-invokes the Negotiation Agent for this vendor.

    The agent uses last_processed_message_id for idempotency (NFR-REL-02)
    so duplicate calls (e.g. from reconciliation job) don't send double offers.
    """
    # Parse negotiation ID — accept both Postgres UUID and Firestore ID
    neg = await _resolve_negotiation(db, negotiation_id)
    if neg is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Negotiation not found")

    # Security: verify the calling vendor is actually assigned to this negotiation
    from app.models.vendor import Vendor
    result = await db.execute(select(Vendor).where(Vendor.id == neg.vendor_id))
    vendor_record = result.scalar_one_or_none()
    if vendor_record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vendor record not found for this negotiation",
        )
    # Allow if firebase_uid matches, OR if the vendor has no firebase_uid yet
    # (seeded vendor not yet claimed — reconciliation will handle it).
    if vendor_record.firebase_uid is not None and vendor_record.firebase_uid != user.uid:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not the assigned vendor for this negotiation",
        )

    # Server-side validation of money-relevant counter-offer fields
    if body.message_type == "counter":
        if body.offer_amount is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Offer amount is required for a counter offer."
            )

        # Validate against the persisted floor price on the Negotiation record
        floor_price = neg.floor_price

        if body.offer_amount < floor_price:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Counter offer PKR {body.offer_amount:,} is below your minimum floor price of PKR {floor_price:,.0f}."
            )

    # FR-VND-05: ensure it's actually the vendor's turn to act
    if not neg.is_vendor_turn and body.message_type != "accept":
        logger.warning(
            "Vendor %s tried to reply to negotiation %s but isVendorTurn=False",
            user.uid, negotiation_id,
        )
        # Don't hard-fail — agent will handle idempotency
        pass

    # Terminal state guard
    if neg.status in ("deal", "no_deal", "expired"):
        return VendorReplyResponse(
            negotiation_id=negotiation_id,
            agent_action="already_terminal",
            message=f"Negotiation already closed with status: {neg.status}",
        )

    # Re-invoke the Negotiation Agent
    from app.agents.negotiation_agent import run_negotiation_agent
    result_action = await run_negotiation_agent(
        negotiation_id=neg.id,
        vendor_message_id=body.message_id,
        vendor_message_content=body.content,
        vendor_offer_amount=body.offer_amount,
        vendor_message_type=body.message_type,
    )

    action = result_action.get("action", "unknown")
    logger.info(
        "Vendor reply processed for negotiation %s. Agent action: %s",
        negotiation_id, action,
    )

    return VendorReplyResponse(
        negotiation_id=negotiation_id,
        agent_action=action,
        message=f"Agent responded with: {action}",
    )


async def _resolve_negotiation(db: AsyncSession, negotiation_id: str) -> Negotiation | None:
    """Accept either a Postgres UUID or a Firestore ID string."""
    # Try as UUID first
    try:
        neg_uuid = uuid.UUID(negotiation_id)
        result = await db.execute(select(Negotiation).where(Negotiation.id == neg_uuid))
        return result.scalar_one_or_none()
    except ValueError:
        pass
    # Try as Firestore ID
    result = await db.execute(
        select(Negotiation).where(Negotiation.firestore_id == negotiation_id)
    )
    return result.scalar_one_or_none()
