"""
Bookings Router — POST /bookings/confirm
FR-BK-01: Customer accepts full package or individual vendors.
FR-BK-02: Creates booking records, updates negotiation status to 'deal'.
FR-BK-03: Notifies vendors on confirmation.
FR-BK-04: Returns booking confirmation summary.
"""
import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import FirebaseUser, require_customer
from app.db import get_db
from app.limiter import limiter
from app.models.booking import Booking
from app.models.negotiation import Negotiation
from app.models.vendor import Vendor
from app.schemas import BookingConfirmRequest, BookingConfirmResponse
from app.services.state_sync import update_event_status, _firestore_update

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/confirm", response_model=BookingConfirmResponse, status_code=201)
@limiter.limit("10/minute")
async def confirm_booking(
    request: Request,
    body: BookingConfirmRequest,
    db: AsyncSession = Depends(get_db),
    user: FirebaseUser = Depends(require_customer),
) -> BookingConfirmResponse:
    """
    FR-BK-01–04: Confirm one or more vendors from the aggregated package.
    Creates a Booking row per vendor in Postgres and mirrors to Firestore.
    """
    event_id = uuid.UUID(body.event_id)
    booking_ids: list[str] = []
    total_amount = 0

    for item in body.vendors:
        neg_id = uuid.UUID(item.negotiation_id)
        vendor_id = uuid.UUID(item.vendor_id)

        # Fetch negotiation
        result = await db.execute(select(Negotiation).where(Negotiation.id == neg_id))
        neg = result.scalar_one_or_none()
        if neg is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Negotiation {item.negotiation_id} not found",
            )
        if neg.status != "deal":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Negotiation {item.negotiation_id} is not in 'deal' state (status={neg.status})",
            )

        if neg.final_price is None:
            logger.error("Negotiation %s status is 'deal' but final_price is None (data integrity error)", neg_id)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Data integrity error: final negotiated price is missing for negotiation {item.negotiation_id}",
            )
        final_price = neg.final_price

        # FR-BK-02: create Booking record
        booking_id = uuid.uuid4()
        booking = Booking(
            id=booking_id,
            event_id=event_id,
            vendor_id=vendor_id,
            negotiation_id=neg_id,
            amount=final_price,
            payment_status="pending",
            confirmed_at=datetime.now(timezone.utc),
        )
        db.add(booking)
        booking_ids.append(str(booking_id))
        total_amount += final_price

        # Mirror booking to Firestore
        await _firestore_update(
            f"bookings/{booking_id}",
            {
                "eventId": body.event_id,
                "vendorId": item.vendor_id,
                "negotiationId": item.negotiation_id,
                "amount": final_price,
                "paymentStatus": "pending",
                "confirmedAt": datetime.now(timezone.utc).isoformat(),
                "customerFirebaseUid": user.uid,
            },
        )

        # FR-BK-03: send vendor and customer notifications
        await _notify_parties_booking_confirmed(db, user.uid, vendor_id, event_id, final_price)

    # Update event status to 'booked' if all vendors confirmed
    await update_event_status(db, event_id, "booked")
    await db.commit()

    logger.info(
        "Booking confirmed for event %s: %d vendors, total PKR %d",
        event_id, len(booking_ids), total_amount,
    )

    return BookingConfirmResponse(
        booking_ids=booking_ids,
        total_amount=total_amount,
        message=f"Successfully booked {len(booking_ids)} vendor(s). Total: PKR {total_amount:,}",
    )


async def _notify_parties_booking_confirmed(
    db: AsyncSession,
    customer_uid: str,
    vendor_id: uuid.UUID,
    event_id: uuid.UUID,
    amount: int,
) -> None:
    """
    FR-BK-03: Notify BOTH customer and vendor of confirmed booking.
    Writes a Firestore notification doc AND dispatches FCM pushes.
    """
    from app.services.notifications import send_fcm_notification
    from app.models.user import User

    # 1. Notify Customer
    try:
        cust_stmt = select(User.fcm_token).where(User.firebase_uid == customer_uid)
        cust_res = await db.execute(cust_stmt)
        cust_token = cust_res.scalar_one_or_none()
        if cust_token:
            await send_fcm_notification(
                token=cust_token,
                title="Booking Confirmed!",
                body=f"Your booking is confirmed for PKR {amount:,}.",
                data={
                    "type": "booking_confirmed",
                    "eventId": str(event_id),
                    "amount": str(amount),
                },
            )
    except Exception as exc:
        logger.warning("Could not send booking notification to customer: %s", exc)

    # 2. Notify Vendor
    try:
        result = await db.execute(select(Vendor).where(Vendor.id == vendor_id))
        vendor = result.scalar_one_or_none()
        if not vendor:
            return

        if vendor.firebase_uid:
            await _firestore_update(
                f"notifications/{uuid.uuid4()}",
                {
                    "recipientUid": vendor.firebase_uid,
                    "type": "booking_confirmed",
                    "eventId": str(event_id),
                    "amount": amount,
                    "read": False,
                    "createdAt": datetime.now(timezone.utc).isoformat(),
                },
            )

        if vendor.fcm_token:
            await send_fcm_notification(
                token=vendor.fcm_token,
                title="New Booking Confirmed!",
                body=f"You have been booked for an event! Total amount: PKR {amount:,}.",
                data={
                    "type": "booking_confirmed",
                    "eventId": str(event_id),
                    "amount": str(amount),
                },
            )
    except Exception as exc:
        logger.warning("Could not send booking notification to vendor %s: %s", vendor_id, exc)
