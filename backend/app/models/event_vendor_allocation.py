"""
EventVendorAllocation model — SRS Section 6.1
Table: event_vendor_allocations
Produced by the Analyzer Agent (FR-ANL-02).
"""
from __future__ import annotations

import uuid

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class EventVendorAllocation(Base):
    __tablename__ = "event_vendor_allocations"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    event_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("events.id", ondelete="CASCADE"), nullable=False, index=True
    )
    category: Mapped[str] = mapped_column(String(64), nullable=False)   # Caterer, Venue, etc.
    allocated_amount: Mapped[int] = mapped_column(Integer, nullable=False)  # PKR
    # Optional per-vendor ceiling (FR-ANL-04)
    max_budget: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # Relationships
    event: Mapped["Event"] = relationship(back_populates="allocations")  # type: ignore[name-defined]

    def __repr__(self) -> str:
        return f"<Allocation event={self.event_id} category={self.category} amount={self.allocated_amount}>"
