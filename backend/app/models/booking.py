"""
Booking model — SRS Section 6.1
Table: bookings
Created when a customer confirms a vendor from the aggregated package (FR-BK-02).
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Booking(Base):
    __tablename__ = "bookings"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    event_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("events.id", ondelete="CASCADE"), nullable=False, index=True
    )
    vendor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("vendors.id", ondelete="CASCADE"), nullable=False, index=True
    )
    negotiation_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("negotiations.id", ondelete="SET NULL"), nullable=True
    )

    amount: Mapped[int] = mapped_column(Integer, nullable=False)  # final confirmed price (PKR)
    payment_status: Mapped[str] = mapped_column(
        Enum("pending", "paid", "refunded", name="payment_status_enum"),
        nullable=False,
        default="pending",
    )
    confirmed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    event: Mapped["Event"] = relationship(back_populates="bookings")  # type: ignore[name-defined]
    vendor: Mapped["Vendor"] = relationship(back_populates="bookings")  # type: ignore[name-defined]
    negotiation: Mapped["Negotiation | None"] = relationship(back_populates="booking")  # type: ignore[name-defined]

    def __repr__(self) -> str:
        return f"<Booking event={self.event_id} vendor={self.vendor_id} amount={self.amount}>"
