"""
Vendor model — SRS Section 6.1
Table: vendors
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Vendor(Base):
    __tablename__ = "vendors"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    # Firebase UID — set when vendor completes onboarding through the app (FR-AUTH-02)
    firebase_uid: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True, index=True)

    business_name: Mapped[str] = mapped_column(String(256), nullable=False)
    category: Mapped[str] = mapped_column(String(64), nullable=False, index=True)  # Caterer, Venue, …
    city: Mapped[str] = mapped_column(String(128), nullable=False, index=True)

    # Price range in PKR (FR-MTC-02: composite score includes proximity to budget)
    base_price_min: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    base_price_max: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    # The canonical listed price the Negotiation Agent uses as starting point
    listed_price: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    rating: Mapped[float] = mapped_column(Numeric(3, 2), nullable=False, default=0.0)
    verified: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    # Contact info for the vendor (used for notifications)
    fcm_token: Mapped[str | None] = mapped_column(String(512), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Relationships
    negotiations: Mapped[list["Negotiation"]] = relationship(back_populates="vendor")  # type: ignore[name-defined]
    bookings: Mapped[list["Booking"]] = relationship(back_populates="vendor")  # type: ignore[name-defined]

    def __repr__(self) -> str:
        return f"<Vendor {self.business_name!r} category={self.category} city={self.city}>"
