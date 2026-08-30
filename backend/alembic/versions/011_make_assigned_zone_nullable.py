"""make assigned_zone nullable

Revision ID: 011_make_assigned_zone_nullable
Revises: 010_officer_current_location
Create Date: 2026-08-30 10:14:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "011_make_assigned_zone_nullable"
down_revision: Union[str, None] = "010_officer_current_location"
branch_labels: Union[str, None] = None
depends_on: Union[str, None] = None


def upgrade() -> None:
    op.alter_column(
        "traffic_officers",
        "assigned_zone",
        existing_type=sa.String(255),
        nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "traffic_officers",
        "assigned_zone",
        existing_type=sa.String(255),
        nullable=False,
    )
