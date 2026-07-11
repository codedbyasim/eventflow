"""
LLMUsageLog model — SRS Section 6.1, FR-DAT-02, NFR-MNT-02
Table: llm_usage_log
One row written after every Fireworks AI call for cost auditing.
"""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class LLMUsageLog(Base):
    __tablename__ = "llm_usage_log"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    agent_type: Mapped[str] = mapped_column(
        Enum("analyzer", "negotiation", "aggregator", name="agent_type_enum"),
        nullable=False,
    )
    # event_id can be NULL if the call wasn't tied to a specific event
    event_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("events.id", ondelete="SET NULL"), nullable=True, index=True
    )
    # negotiation_id for per-round tracing (NFR-MNT-02)
    negotiation_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("negotiations.id", ondelete="SET NULL"), nullable=True
    )
    model_used: Mapped[str] = mapped_column(String(256), nullable=False)
    tokens_in: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    tokens_out: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    cost_usd: Mapped[float] = mapped_column(Numeric(10, 6), nullable=False, default=0.0)
    latency_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    success: Mapped[bool] = mapped_column(nullable=False, default=True)
    error_message: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    def __repr__(self) -> str:
        return f"<LLMUsageLog agent={self.agent_type} tokens={self.tokens_in}+{self.tokens_out}>"
