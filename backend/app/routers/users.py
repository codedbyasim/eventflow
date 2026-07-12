"""
Users Router — POST /users/fcm-token
Registers or updates the FCM token for the currently authenticated user
(either customer or vendor) in Postgres.
"""
from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import update, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import FirebaseUser, verify_token
from app.db import get_db
from app.models.user import User
from app.models.vendor import Vendor

logger = logging.getLogger(__name__)
router = APIRouter()


class FCMTokenRequest(BaseModel):
    fcm_token: str = Field(..., min_length=1, max_length=512)


@router.post("/fcm-token", status_code=status.HTTP_200_OK)
async def register_fcm_token(
    body: FCMTokenRequest,
    db: AsyncSession = Depends(get_db),
    user: FirebaseUser = Depends(verify_token),
):
    """
    Register or update the FCM device token for the current user.
    Handles both 'customer' and 'vendor' roles.
    """
    if user.role == "customer":
        # Check if user exists in Postgres. If not, create them
        result = await db.execute(select(User).where(User.firebase_uid == user.uid))
        pg_user = result.scalar_one_or_none()
        if pg_user is None:
            pg_user = User(
                firebase_uid=user.uid,
                role="customer",
                email=user.email,
                fcm_token=body.fcm_token,
            )
            db.add(pg_user)
        else:
            pg_user.fcm_token = body.fcm_token
        await db.commit()
        logger.info("Updated FCM token for customer: %s", user.uid)
        return {"status": "ok", "message": "Customer FCM token updated successfully"}

    elif user.role == "vendor":
        # Look up vendor by firebase_uid in Postgres
        result = await db.execute(select(Vendor).where(Vendor.firebase_uid == user.uid))
        pg_vendor = result.scalar_one_or_none()
        if pg_vendor is None:
            # Vendor might not have completed onboarding in Postgres yet,
            # but has Firebase credentials. We can create a placeholder or update it when they onboard.
            # To be safe, we allow creating a shell Vendor or raise error if they should exist.
            # Usually, vendors onboard first.
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Vendor profile not found. Please onboard first.",
            )
        pg_vendor.fcm_token = body.fcm_token
        await db.commit()
        logger.info("Updated FCM token for vendor: %s", user.uid)
        return {"status": "ok", "message": "Vendor FCM token updated successfully"}

    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unknown or unsupported user role: {user.role}",
        )


import uuid
from app.auth import get_firestore_client

class VendorOnboardRequest(BaseModel):
    business_name: str
    category: str
    city: str
    base_price: float
    min_price: float


@router.post("/onboard-vendor", status_code=status.HTTP_200_OK)
async def onboard_vendor(
    body: VendorOnboardRequest,
    db: AsyncSession = Depends(get_db),
    user: FirebaseUser = Depends(verify_token),
):
    if user.role != "vendor":
        raise HTTPException(status_code=400, detail="Only vendors can onboard.")

    # Normalize category keys to match standard Postgres/matching categories
    category_map = {
        "caterer": "Caterer",
        "decorator": "Decorator",
        "photographer": "Photographer",
        "dj_sound": "DJ / Music",
        "tent": "Tent / Marquee",
        "security": "Security",
        "flowers": "Flowers",
        "other": "Other"
    }
    normalized_category = category_map.get(body.category.lower(), body.category)

    # 1. Check if this firebase_uid is already linked to a vendor in Postgres
    result = await db.execute(select(Vendor).where(Vendor.firebase_uid == user.uid))
    vendor = result.scalar_one_or_none()

    if vendor is None:
        # Try to find a seeded vendor in the same city and category with no firebase_uid
        # to "claim" it and preserve matching
        stmt = select(Vendor).where(
            Vendor.category == normalized_category,
            Vendor.city == body.city.lower(),
            Vendor.firebase_uid == None
        ).limit(1)
        res = await db.execute(stmt)
        vendor = res.scalar_one_or_none()

        if vendor is not None:
            # Claim this seeded vendor!
            vendor.firebase_uid = user.uid
            vendor.business_name = body.business_name
            vendor.base_price_min = body.min_price
            vendor.base_price_max = body.base_price
            vendor.listed_price = body.base_price
            logger.info("Firebase user %s claimed seeded vendor: %s", user.uid, vendor.business_name)
        else:
            # Create a brand new vendor in Postgres
            vendor = Vendor(
                id=uuid.uuid4(),
                firebase_uid=user.uid,
                business_name=body.business_name,
                category=normalized_category,
                city=body.city.lower(),
                base_price_min=body.min_price,
                base_price_max=body.base_price,
                listed_price=body.base_price,
                rating=5.0,
                verified=True
            )
            db.add(vendor)
            logger.info("Created new vendor in Postgres for firebase user %s", user.uid)
    else:
        # Update existing linked vendor
        vendor.business_name = body.business_name
        vendor.category = normalized_category
        vendor.city = body.city.lower()
        vendor.base_price_min = body.min_price
        vendor.base_price_max = body.base_price
        vendor.listed_price = body.base_price

    await db.commit()

    # 2. Sync existing negotiations in Firestore so that they get the vendor's firebase_uid!
    # This allows the newly registered vendor to see negotiations that were already matched to them!
    try:
        firestore_client = get_firestore_client()
        neg_ref = firestore_client.collection("negotiations")
        # Query negotiations where vendorId matches this vendor's Postgres UUID
        query = neg_ref.where("vendorId", "==", str(vendor.id)).stream()
        for doc in query:
            doc.reference.update({"vendorFirebaseUid": user.uid})
            logger.info("Updated negotiation %s with vendorFirebaseUid %s", doc.id, user.uid)
    except Exception as e:
        logger.error("Error updating Firestore negotiations for onboarded vendor: %s", e)

    # 3. Retroactive Event Matching for newly onboarded/linked vendor!
    # Look for any events in the same city that require this vendor's category,
    # are in 'matching' or 'negotiating' status, and don't have a negotiation with this vendor yet.
    try:
        from app.models.event import Event
        from app.models.event_vendor_allocation import EventVendorAllocation
        from app.models.negotiation import Negotiation
        from app.services.negotiation_orchestrator import _run_with_timeout
        from app.services.state_sync import create_negotiation_mirror
        from app.config import get_settings
        import asyncio
        settings = get_settings()

        # Find active events in the same city
        stmt = select(Event).where(
            Event.city == vendor.city,
            Event.status.in_(["matching", "negotiating"])
        )
        res = await db.execute(stmt)
        active_events = res.scalars().all()

        for event in active_events:
            # Check if this category was allocated for this event
            alloc_stmt = select(EventVendorAllocation).where(
                EventVendorAllocation.event_id == event.id,
                EventVendorAllocation.category == vendor.category
            )
            alloc_res = await db.execute(alloc_stmt)
            allocation = alloc_res.scalar_one_or_none()

            if allocation is not None:
                # Check if a negotiation already exists for this vendor and event
                neg_stmt = select(Negotiation).where(
                    Negotiation.event_id == event.id,
                    Negotiation.vendor_id == vendor.id
                )
                neg_res = await db.execute(neg_stmt)
                existing_neg = neg_res.scalar_one_or_none()

                if existing_neg is None:
                    # Spawn retroactive negotiation!
                    neg_id = uuid.uuid4()
                    neg_firestore_id = f"neg_{neg_id.hex[:16]}"
                    
                    # Estimate budget ceiling
                    allocated = int(allocation.allocated_amount)
                    flexibility = float(event.negotiation_flexibility or 0.15)
                    max_budget = int(allocated * (1.0 + flexibility))

                    # Calculate dynamic asking price and floor price
                    from app.services.pricing_calculator import calculate_vendor_event_price
                    raw_asking = float(vendor.listed_price or vendor.base_price_max or 0.0)
                    raw_floor = float(vendor.base_price_min or 0.0)

                    price, floor_price = calculate_vendor_event_price(
                        vendor_category=vendor.category,
                        base_price=raw_asking,
                        min_price=raw_floor,
                        guest_count=event.guest_count,
                        venue_pref=event.indoor_outdoor
                    )
                    price = int(price)
                    floor_price = int(floor_price)

                    new_neg = Negotiation(
                        id=neg_id,
                        firestore_id=neg_firestore_id,
                        event_id=event.id,
                        vendor_id=vendor.id,
                        status="connecting",
                        asking_price=price,
                        floor_price=floor_price,
                        max_rounds=settings.max_negotiation_rounds,
                        is_vendor_turn=False,
                    )
                    db.add(new_neg)
                    await db.flush()

                    # Mirror to Firestore using state_sync helper
                    await create_negotiation_mirror(
                        db=db,
                        negotiation_id=neg_id,
                        event=event,
                        vendor_id=vendor.id,
                        vendor_firebase_uid=user.uid,
                        vendor_name=vendor.business_name,
                        vendor_category=vendor.category,
                        neg_firestore_id=neg_firestore_id,
                        allocated_budget=allocated,
                        max_budget=max_budget,
                        asking_price=vendor.listed_price,
                        max_rounds=settings.max_negotiation_rounds,
                    )
                    logger.info("Retroactively spawned negotiation %s for vendor %s on event %s", neg_firestore_id, vendor.business_name, event.id)

                    # Trigger the background negotiation worker
                    asyncio.create_task(
                        _run_with_timeout(neg_id, settings.vendor_timeout_secs)
                    )
        await db.commit()
    except Exception as ex:
        logger.error("Error in retroactive event matching for vendor: %s", ex)

    return {"status": "ok", "vendor_id": str(vendor.id)}
