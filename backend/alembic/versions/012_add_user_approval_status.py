"""add user approval status and audit columns

Revision ID: 012_add_user_approval_status
Revises: 011_make_assigned_zone_nullable
Create Date: 2026-08-30 11:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "012_add_user_approval_status"
down_revision: Union[str, None] = "011_make_assigned_zone_nullable"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _column_exists(table: str, column: str) -> bool:
    return column in {
        c["name"] for c in sa.inspect(op.get_bind()).get_columns(table)
    }


def upgrade() -> None:
    if not _column_exists("users", "approval_status"):
        op.add_column(
            "users",
            sa.Column(
                "approval_status",
                sa.String(50),
                nullable=False,
                server_default="approved",
            ),
        )
        op.create_index("ix_users_approval_status", "users", ["approval_status"])
    if not _column_exists("users", "approved_at"):
        op.add_column(
            "users",
            sa.Column("approved_at", sa.DateTime(timezone=True), nullable=True),
        )
    if not _column_exists("users", "approved_by"):
        op.add_column(
            "users",
            sa.Column(
                "approved_by",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="SET NULL"),
                nullable=True,
            ),
        )


def downgrade() -> None:
    if _column_exists("users", "approved_by"):
        op.drop_column("users", "approved_by")
    if _column_exists("users", "approved_at"):
        op.drop_column("users", "approved_at")
    if _column_exists("users", "approval_status"):
        op.drop_index("ix_users_approval_status", table_name="users")
        op.drop_column("users", "approval_status")
