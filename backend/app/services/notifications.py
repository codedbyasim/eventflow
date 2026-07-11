"""
FCM push notifications service.
Uses firebase_admin to send push notifications to vendors or customers.
"""
from __future__ import annotations

import logging
import uuid
from typing import Any

from firebase_admin import messaging
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.negotiation import Negotiation
from app.models.event import Event
from app.models.user import User
from app.models.vendor import Vendor

logger = logging.getLogger(__name__)


async def send_fcm_notification(
    token: str,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> bool:
    """
    Send a unicast FCM push notification to a device token.
    Safe-guarded: log exceptions and return success flag so it never crashes caller.
    """
    if not token:
        logger.warning("FCM: Cannot send notification, token is empty.")
        return False

    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=token,
        )
        response = messaging.send(message)
        logger.info("FCM: Successfully sent message: %s", response)
        return True
    except Exception as exc:
        logger.error("FCM: Failed to send push notification: %s", exc)
        return False


async def notify_customer_on_negotiation_update(
    db: AsyncSession,
    negotiation_id: uuid.UUID,
    title: str,
    body: str,
    action_type: str,
) -> None:
    """
    FR-NTF-01: Notify customer of vendor activity (accept / reject / counter).
    Queries the database to find the owner (customer) of the event and pushes notification.
    """
    try:
        # Query User fcm_token through Event relationship
        stmt = (
            select(User.fcm_token)
            .join(Event, Event.customer_id == User.id)
            .join(Negotiation, Negotiation.event_id == Event.id)
            .where(Negotiation.id == negotiation_id)
        )
        result = await db.execute(stmt)
        token = result.scalar_one_or_none()

        if token:
            await send_fcm_notification(
                token=token,
                title=title,
                body=body,
                data={
                    "type": "negotiation_update",
                    "negotiation_id": str(negotiation_id),
                    "action_type": action_type,
                },
            )
    except Exception as exc:
        logger.warning("Failed to notify customer for negotiation %s: %s", negotiation_id, exc)


async def notify_vendor_on_negotiation_update(
    db: AsyncSession,
    negotiation_id: uuid.UUID,
    title: str,
    body: str,
    action_type: str,
) -> None:
    """
    FR-NTF-02: Notify vendor of new agent activity (counter offer / acceptance / walk away).
    """
    try:
        stmt = (
            select(Vendor.fcm_token)
            .join(Negotiation, Negotiation.vendor_id == Vendor.id)
            .where(Negotiation.id == negotiation_id)
        )
        result = await db.execute(stmt)
        token = result.scalar_one_or_none()

        if token:
            await send_fcm_notification(
                token=token,
                title=title,
                body=body,
                data={
                    "type": "negotiation_update",
                    "negotiation_id": str(negotiation_id),
                    "action_type": action_type,
                },
            )
    except Exception as exc:
        logger.warning("Failed to notify vendor for negotiation %s: %s", negotiation_id, exc)
