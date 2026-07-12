# alembic/script.py.mako
# Alembic migration template
"""normalize_vendor_categories

Revision ID: d53fedc62a31
Revises: e47b9bbd0e74
Create Date: 2026-07-12 11:42:47.001231

"""
from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd53fedc62a31'
down_revision: Union[str, None] = 'e47b9bbd0e74'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Normalize category strings from lowercase keys to capitalized UI strings
    op.execute("UPDATE vendors SET category = 'Caterer' WHERE category = 'caterer'")
    op.execute("UPDATE vendors SET category = 'Decorator' WHERE category = 'decorator'")
    op.execute("UPDATE vendors SET category = 'Photographer' WHERE category = 'photographer'")
    op.execute("UPDATE vendors SET category = 'DJ / Music' WHERE category = 'dj_sound'")
    op.execute("UPDATE vendors SET category = 'Tent / Marquee' WHERE category = 'tent'")
    op.execute("UPDATE vendors SET category = 'Security' WHERE category = 'security'")
    op.execute("UPDATE vendors SET category = 'Flowers' WHERE category = 'flowers'")
    op.execute("UPDATE vendors SET category = 'Other' WHERE category = 'other'")


def downgrade() -> None:
    # Downgrade back to lowercase keys
    op.execute("UPDATE vendors SET category = 'caterer' WHERE category = 'Caterer'")
    op.execute("UPDATE vendors SET category = 'decorator' WHERE category = 'Decorator'")
    op.execute("UPDATE vendors SET category = 'photographer' WHERE category = 'Photographer'")
    op.execute("UPDATE vendors SET category = 'dj_sound' WHERE category = 'DJ / Music'")
    op.execute("UPDATE vendors SET category = 'tent' WHERE category = 'Tent / Marquee'")
    op.execute("UPDATE vendors SET category = 'security' WHERE category = 'Security'")
    op.execute("UPDATE vendors SET category = 'flowers' WHERE category = 'Flowers'")
    op.execute("UPDATE vendors SET category = 'other' WHERE category = 'Other'")
