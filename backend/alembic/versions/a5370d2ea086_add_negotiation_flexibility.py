# alembic/script.py.mako
# Alembic migration template
"""add_negotiation_flexibility

Revision ID: a5370d2ea086
Revises: 0001
Create Date: 2026-07-11 20:42:41.631178

"""
from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a5370d2ea086'
down_revision: Union[str, None] = '0001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # bookings — add vendor_id index if missing
    op.create_index(op.f('ix_bookings_vendor_id'), 'bookings', ['vendor_id'],
                    unique=False, if_not_exists=True)

    # event_vendor_allocations — rename index (old name → new name)
    op.drop_index(op.f('ix_allocations_event_id'),
                  table_name='event_vendor_allocations', if_exists=True)
    op.create_index(op.f('ix_event_vendor_allocations_event_id'),
                    'event_vendor_allocations', ['event_id'],
                    unique=False, if_not_exists=True)

    # events — add negotiation_flexibility column (idempotent via server_default)
    with op.batch_alter_table('events') as batch_op:
        # Add column only if it doesn't already exist
        pass  # batch context opens DDL transaction

    op.execute("""
        ALTER TABLE events
        ADD COLUMN IF NOT EXISTS negotiation_flexibility NUMERIC(3,2)
            NOT NULL DEFAULT 0.15;
    """)
    # Check constraint — ignore if already exists (PostgreSQL ≥ 9.0)
    op.execute("""
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conname = 'check_negotiation_flexibility'
                  AND conrelid = 'events'::regclass
            ) THEN
                ALTER TABLE events
                ADD CONSTRAINT check_negotiation_flexibility
                CHECK (negotiation_flexibility >= 0.0 AND negotiation_flexibility <= 0.30);
            END IF;
        END$$;
    """)

    op.alter_column('events', 'analyzer_reasoning',
                    existing_type=sa.TEXT(),
                    type_=sa.String(),
                    existing_nullable=True)

    # events firestore_id — drop old unique constraint + index, recreate as
    # unique index (IF EXISTS guards protect against fresh-DB runs)
    op.drop_constraint(op.f('events_firestore_id_key'), 'events',
                       type_='unique', if_exists=True)
    op.drop_index(op.f('ix_events_firestore_id'),
                  table_name='events', if_exists=True)
    op.create_index(op.f('ix_events_firestore_id'), 'events', ['firestore_id'],
                    unique=True, if_not_exists=True)

    # Drop legacy negotiation_margin column if it exists (old schema only)
    op.drop_column('events', 'negotiation_margin', if_exists=True)

    # llm_usage_log
    op.alter_column('llm_usage_log', 'error_message',
                    existing_type=sa.TEXT(),
                    type_=sa.String(),
                    existing_nullable=True)
    op.drop_index(op.f('ix_llm_log_created_at'),
                  table_name='llm_usage_log', if_exists=True)
    op.drop_index(op.f('ix_llm_log_event_id'),
                  table_name='llm_usage_log', if_exists=True)
    op.create_index(op.f('ix_llm_usage_log_event_id'), 'llm_usage_log',
                    ['event_id'], unique=False, if_not_exists=True)

    # negotiations
    op.drop_constraint(op.f('negotiations_firestore_id_key'), 'negotiations',
                       type_='unique', if_exists=True)
    op.drop_index(op.f('ix_negotiations_firestore_id'),
                  table_name='negotiations', if_exists=True)
    op.create_index(op.f('ix_negotiations_firestore_id'), 'negotiations',
                    ['firestore_id'], unique=True, if_not_exists=True)

    # users
    op.drop_constraint(op.f('users_firebase_uid_key'), 'users',
                       type_='unique', if_exists=True)
    op.drop_index(op.f('ix_users_firebase_uid'),
                  table_name='users', if_exists=True)
    op.create_index(op.f('ix_users_firebase_uid'), 'users',
                    ['firebase_uid'], unique=True, if_not_exists=True)

    # vendors
    op.drop_constraint(op.f('vendors_firebase_uid_key'), 'vendors',
                       type_='unique', if_exists=True)
    op.drop_index(op.f('ix_vendors_firebase_uid'),
                  table_name='vendors', if_exists=True)
    op.create_index(op.f('ix_vendors_firebase_uid'), 'vendors',
                    ['firebase_uid'], unique=True, if_not_exists=True)


def downgrade() -> None:
    op.drop_index(op.f('ix_vendors_firebase_uid'), table_name='vendors', if_exists=True)
    op.create_index(op.f('ix_vendors_firebase_uid'), 'vendors', ['firebase_uid'], unique=False, if_not_exists=True)
    op.create_unique_constraint(op.f('vendors_firebase_uid_key'), 'vendors', ['firebase_uid'])
    op.drop_index(op.f('ix_users_firebase_uid'), table_name='users', if_exists=True)
    op.create_index(op.f('ix_users_firebase_uid'), 'users', ['firebase_uid'], unique=False, if_not_exists=True)
    op.create_unique_constraint(op.f('users_firebase_uid_key'), 'users', ['firebase_uid'])
    op.drop_index(op.f('ix_negotiations_firestore_id'), table_name='negotiations', if_exists=True)
    op.create_index(op.f('ix_negotiations_firestore_id'), 'negotiations', ['firestore_id'], unique=False, if_not_exists=True)
    op.create_unique_constraint(op.f('negotiations_firestore_id_key'), 'negotiations', ['firestore_id'])
    op.drop_index(op.f('ix_llm_usage_log_event_id'), table_name='llm_usage_log', if_exists=True)
    op.create_index(op.f('ix_llm_log_event_id'), 'llm_usage_log', ['event_id'], unique=False, if_not_exists=True)
    op.create_index(op.f('ix_llm_log_created_at'), 'llm_usage_log', ['created_at'], unique=False, if_not_exists=True)
    op.alter_column('llm_usage_log', 'error_message',
                    existing_type=sa.String(), type_=sa.TEXT(), existing_nullable=True)
    op.add_column('events', sa.Column('negotiation_margin', sa.INTEGER(),
                  server_default=sa.text('10'), autoincrement=False, nullable=False))
    op.drop_index(op.f('ix_events_firestore_id'), table_name='events', if_exists=True)
    op.create_index(op.f('ix_events_firestore_id'), 'events', ['firestore_id'], unique=False, if_not_exists=True)
    op.create_unique_constraint(op.f('events_firestore_id_key'), 'events', ['firestore_id'])
    op.alter_column('events', 'analyzer_reasoning',
                    existing_type=sa.String(), type_=sa.TEXT(), existing_nullable=True)
    op.drop_constraint('check_negotiation_flexibility', 'events', type_='check', if_exists=True)
    op.drop_column('events', 'negotiation_flexibility', if_exists=True)
    op.drop_index(op.f('ix_event_vendor_allocations_event_id'),
                  table_name='event_vendor_allocations', if_exists=True)
    op.create_index(op.f('ix_allocations_event_id'), 'event_vendor_allocations',
                    ['event_id'], unique=False, if_not_exists=True)
    op.drop_index(op.f('ix_bookings_vendor_id'), table_name='bookings', if_exists=True)
