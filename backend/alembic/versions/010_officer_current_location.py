"""add officer current location

Revision ID: 010_officer_current_location
Revises: 35ddd8a41e50
Create Date: 2026-08-30 09:19:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "010_officer_current_location"
down_revision: Union[str, None] = "35ddd8a41e50"
branch_labels: Union[str, None] = None
depends_on: Union[str, None] = None


def upgrade() -> None:
    op.add_column(
        "traffic_officers",
        sa.Column("current_latitude", sa.Float(), nullable=True),
    )
    op.add_column(
        "traffic_officers",
        sa.Column("current_longitude", sa.Float(), nullable=True),
    )
    op.add_column(
        "traffic_officers",
        sa.Column("location_updated_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("traffic_officers", "location_updated_at")
    op.drop_column("traffic_officers", "current_longitude")
    op.drop_column("traffic_officers", "current_latitude")
