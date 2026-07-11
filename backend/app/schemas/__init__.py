"""
Pydantic schemas for request/response validation.
"""
from __future__ import annotations

from datetime import date
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field


# ── Event schemas ─────────────────────────────────────────────────────────────

class EventCreateRequest(BaseModel):
    event_type: str = Field(..., examples=["Wedding"])
    event_date: date | None = None
    city: str | None = None
    guest_count: int = Field(default=50, ge=1)
    indoor_outdoor: str | None = Field(None, pattern="^(Indoor|Outdoor)$")
    categories: list[str] = Field(..., min_length=1)
    total_budget: int = Field(..., gt=0, description="Total budget in PKR")
    per_category_max: dict[str, int] | None = None
    negotiation_flexibility: float = Field(default=0.15, ge=0.0, le=0.30, description="Negotiation flexibility range")


class EventCreateResponse(BaseModel):
    event_id: str
    firestore_id: str
    status: str
    message: str


# ── Vendor reply webhook ──────────────────────────────────────────────────────

class VendorReplyRequest(BaseModel):
    message_id: str = Field(..., description="Firestore message document ID of the vendor's reply")
    message_type: str = Field(..., pattern="^(counter|accept|reject)$")
    content: str | None = None
    offer_amount: int | None = None


class VendorReplyResponse(BaseModel):
    negotiation_id: str
    agent_action: str
    message: str


# ── Booking schemas ───────────────────────────────────────────────────────────

class BookingVendorItem(BaseModel):
    negotiation_id: str
    vendor_id: str


class BookingConfirmRequest(BaseModel):
    event_id: str
    vendors: list[BookingVendorItem] = Field(..., min_length=1)


class BookingConfirmResponse(BaseModel):
    booking_ids: list[str]
    total_amount: int
    message: str


# ── Generic ───────────────────────────────────────────────────────────────────

class ErrorResponse(BaseModel):
    detail: str
