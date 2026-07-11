"""
Event model — SRS Section 6.1
Table: events
"""
from __future__ import annotations

import uuid
from datetime import date, datetime

from sqlalchemy import Date, DateTime, Enum, ForeignKey, Integer, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Event(Base):
    __tablename__ = "events"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    # Firestore event document ID — used to mirror status back to realtime layer
    firestore_id: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True, index=True)

    customer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    # Firebase UID of the customer (for fast Firestore lookups without joining users table)
    customer_firebase_uid: Mapped[str] = mapped_column(String(128), nullable=False, index=True)

    type: Mapped[str] = mapped_column(String(64), nullable=False)   # Wedding, Birthday, etc.
    event_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    city: Mapped[str | None] = mapped_column(String(128), nullable=True)
    guest_count: Mapped[int] = mapped_column(Integer, nullable=False, default=50)
    indoor_outdoor: Mapped[str | None] = mapped_column(
        Enum("Indoor", "Outdoor", name="venue_pref_enum"), nullable=True
    )
    total_budget: Mapped[int] = mapped_column(Integer, nullable=False)  # PKR
    negotiation_flexibility: Mapped[float] = mapped_column(Numeric(3, 2), nullable=False, server_default="0.15", default=0.15)

    status: Mapped[str] = mapped_column(
        Enum(
            "draft", "analyzing", "matching", "negotiating",
            "aggregating", "ready", "booked", "cancelled",
            name="event_status_enum",
        ),
        nullable=False,
        default="draft",
    )

    # JSON blob of Analyzer Agent's raw reasoning (stored as text for auditability)
    analyzer_reasoning: Mapped[str | None] = mapped_column(String, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    # Relationships
    customer: Mapped["User"] = relationship(back_populates="events")  # type: ignore[name-defined]
    allocations: Mapped[list["EventVendorAllocation"]] = relationship(back_populates="event", cascade="all, delete-orphan")  # type: ignore[name-defined]
    negotiations: Mapped[list["Negotiation"]] = relationship(back_populates="event", cascade="all, delete-orphan")  # type: ignore[name-defined]
    bookings: Mapped[list["Booking"]] = relationship(back_populates="event", cascade="all, delete-orphan")  # type: ignore[name-defined]

    def __repr__(self) -> str:
        return f"<Event id={self.id} type={self.type} status={self.status}>"
