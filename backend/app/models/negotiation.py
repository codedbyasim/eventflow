"""
Negotiation model — SRS Section 6.1
Table: negotiations
One row per (event × vendor) pair.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Negotiation(Base):
    __tablename__ = "negotiations"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    # Firestore negotiation document ID (for realtime sync)
    firestore_id: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True, index=True)

    event_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("events.id", ondelete="CASCADE"), nullable=False, index=True
    )
    vendor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("vendors.id", ondelete="CASCADE"), nullable=False, index=True
    )

    status: Mapped[str] = mapped_column(
        Enum(
            "connecting", "negotiating", "counter_offer",
            "deal", "no_deal", "expired",
            name="negotiation_status_enum",
        ),
        nullable=False,
        default="connecting",
    )

    asking_price: Mapped[int] = mapped_column(Integer, nullable=False)  # vendor's listed price (PKR)
    floor_price: Mapped[int] = mapped_column(Integer, nullable=False, server_default="0", default=0)
    current_offer: Mapped[int | None] = mapped_column(Integer, nullable=True)   # latest agent offer
    final_price: Mapped[int | None] = mapped_column(Integer, nullable=True)     # agreed price on deal

    rounds_used: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    max_rounds: Mapped[int] = mapped_column(Integer, nullable=False, default=5)

    # Idempotency: tracks the last processed message ID (NFR-REL-02)
    last_processed_message_id: Mapped[str | None] = mapped_column(String(128), nullable=True)

    is_vendor_turn: Mapped[bool] = mapped_column(
        # Reuse negotiation_status_enum context via a boolean column
        # True = waiting for vendor, False = agent's turn / terminal
        nullable=False,
        default=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_activity: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    processing_locked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Relationships
    event: Mapped["Event"] = relationship(back_populates="negotiations")  # type: ignore[name-defined]
    vendor: Mapped["Vendor"] = relationship(back_populates="negotiations")  # type: ignore[name-defined]
    booking: Mapped["Booking | None"] = relationship(back_populates="negotiation", uselist=False)  # type: ignore[name-defined]

    def __repr__(self) -> str:
        return f"<Negotiation event={self.event_id} vendor={self.vendor_id} status={self.status}>"
