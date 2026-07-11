"""
Initial schema — all 7 tables per SRS Section 6.1.
Revision: 0001
"""
from __future__ import annotations

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── users ─────────────────────────────────────────────────────────────
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("firebase_uid", sa.String(128), nullable=False, unique=True),
        sa.Column("role", sa.Enum("customer", "vendor", name="user_role_enum"), nullable=False),
        sa.Column("email", sa.String(320), nullable=True),
        sa.Column("phone", sa.String(32), nullable=True),
        sa.Column("display_name", sa.String(256), nullable=True),
        sa.Column("fcm_token", sa.String(512), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_users_firebase_uid", "users", ["firebase_uid"])

    # ── vendors ───────────────────────────────────────────────────────────
    op.create_table(
        "vendors",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("firebase_uid", sa.String(128), nullable=True, unique=True),
        sa.Column("business_name", sa.String(256), nullable=False),
        sa.Column("category", sa.String(64), nullable=False),
        sa.Column("city", sa.String(128), nullable=False),
        sa.Column("base_price_min", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("base_price_max", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("listed_price", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("rating", sa.Numeric(3, 2), nullable=False, server_default="0.0"),
        sa.Column("verified", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("fcm_token", sa.String(512), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_vendors_category", "vendors", ["category"])
    op.create_index("ix_vendors_city", "vendors", ["city"])
    op.create_index("ix_vendors_firebase_uid", "vendors", ["firebase_uid"])

    # ── events ────────────────────────────────────────────────────────────
    op.create_table(
        "events",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("firestore_id", sa.String(128), nullable=True, unique=True),
        sa.Column("customer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("customer_firebase_uid", sa.String(128), nullable=False),
        sa.Column("type", sa.String(64), nullable=False),
        sa.Column("event_date", sa.Date(), nullable=True),
        sa.Column("city", sa.String(128), nullable=True),
        sa.Column("guest_count", sa.Integer(), nullable=False, server_default="50"),
        sa.Column("indoor_outdoor", sa.Enum("Indoor", "Outdoor", name="venue_pref_enum"), nullable=True),
        sa.Column("total_budget", sa.Integer(), nullable=False),
        sa.Column("status", sa.Enum("draft", "analyzing", "matching", "negotiating", "aggregating", "ready", "booked", "cancelled", name="event_status_enum"), nullable=False, server_default="draft"),
        sa.Column("analyzer_reasoning", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_events_customer_id", "events", ["customer_id"])
    op.create_index("ix_events_customer_firebase_uid", "events", ["customer_firebase_uid"])
    op.create_index("ix_events_firestore_id", "events", ["firestore_id"])

    # ── event_vendor_allocations ─────────────────────────────────────────
    op.create_table(
        "event_vendor_allocations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("event_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("events.id", ondelete="CASCADE"), nullable=False),
        sa.Column("category", sa.String(64), nullable=False),
        sa.Column("allocated_amount", sa.Integer(), nullable=False),
        sa.Column("max_budget", sa.Integer(), nullable=True),
    )
    op.create_index("ix_allocations_event_id", "event_vendor_allocations", ["event_id"])

    # ── negotiations ──────────────────────────────────────────────────────
    op.create_table(
        "negotiations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("firestore_id", sa.String(128), nullable=True, unique=True),
        sa.Column("event_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("events.id", ondelete="CASCADE"), nullable=False),
        sa.Column("vendor_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("vendors.id", ondelete="CASCADE"), nullable=False),
        sa.Column("status", sa.Enum("connecting", "negotiating", "counter_offer", "deal", "no_deal", "expired", name="negotiation_status_enum"), nullable=False, server_default="connecting"),
        sa.Column("asking_price", sa.Integer(), nullable=False),
        sa.Column("current_offer", sa.Integer(), nullable=True),
        sa.Column("final_price", sa.Integer(), nullable=True),
        sa.Column("rounds_used", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("max_rounds", sa.Integer(), nullable=False, server_default="5"),
        sa.Column("last_processed_message_id", sa.String(128), nullable=True),
        sa.Column("is_vendor_turn", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_activity", sa.DateTime(timezone=True), nullable=True),
        sa.Column("processing_locked_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_negotiations_event_id", "negotiations", ["event_id"])
    op.create_index("ix_negotiations_vendor_id", "negotiations", ["vendor_id"])
    op.create_index("ix_negotiations_firestore_id", "negotiations", ["firestore_id"])

    # ── bookings ──────────────────────────────────────────────────────────
    op.create_table(
        "bookings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("event_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("events.id", ondelete="CASCADE"), nullable=False),
        sa.Column("vendor_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("vendors.id", ondelete="CASCADE"), nullable=False),
        sa.Column("negotiation_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("negotiations.id", ondelete="SET NULL"), nullable=True),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column("payment_status", sa.Enum("pending", "paid", "refunded", name="payment_status_enum"), nullable=False, server_default="pending"),
        sa.Column("confirmed_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_bookings_event_id", "bookings", ["event_id"])

    # ── llm_usage_log ─────────────────────────────────────────────────────
    op.create_table(
        "llm_usage_log",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("agent_type", sa.Enum("analyzer", "negotiation", "aggregator", name="agent_type_enum"), nullable=False),
        sa.Column("event_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("events.id", ondelete="SET NULL"), nullable=True),
        sa.Column("negotiation_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("negotiations.id", ondelete="SET NULL"), nullable=True),
        sa.Column("model_used", sa.String(256), nullable=False),
        sa.Column("tokens_in", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("tokens_out", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("cost_usd", sa.Numeric(10, 6), nullable=False, server_default="0.0"),
        sa.Column("latency_ms", sa.Integer(), nullable=True),
        sa.Column("success", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_llm_log_event_id", "llm_usage_log", ["event_id"])
    op.create_index("ix_llm_log_created_at", "llm_usage_log", ["created_at"])


def downgrade() -> None:
    op.drop_table("llm_usage_log")
    op.drop_table("bookings")
    op.drop_table("negotiations")
    op.drop_table("event_vendor_allocations")
    op.drop_table("events")
    op.drop_table("vendors")
    op.drop_table("users")
