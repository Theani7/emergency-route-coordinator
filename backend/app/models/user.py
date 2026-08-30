"""User model with role-based access."""

import enum
from datetime import datetime, timezone

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class UserRole(str, enum.Enum):
    ADMIN = "admin"
    DRIVER = "driver"
    OFFICER = "officer"


class UserApprovalStatus(str, enum.Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"


class User(Base):
    """System user account."""

    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[UserRole] = mapped_column(
        Enum(
            UserRole,
            name="user_role",
            values_callable=lambda x: [e.value for e in x],
            native_enum=False,
        ),
        nullable=False,
        index=True,
    )
    approval_status: Mapped[UserApprovalStatus] = mapped_column(
        Enum(
            UserApprovalStatus,
            name="user_approval_status",
            values_callable=lambda x: [e.value for e in x],
            native_enum=False,
        ),
        default=UserApprovalStatus.APPROVED,
        server_default="approved",
        nullable=False,
        index=True,
    )
    approved_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, default=None
    )
    approved_by: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, default=None
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )
    failed_login_attempts: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )
    locked_until: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, default=None
    )
    fcm_token: Mapped[str | None] = mapped_column(String(512), nullable=True, default=None)

    ambulance = relationship("Ambulance", back_populates="driver", uselist=False)
    officer_profile = relationship(
        "TrafficOfficer", back_populates="user", uselist=False
    )
    notifications = relationship(
        "Notification",
        back_populates="officer",
        foreign_keys="Notification.officer_id",
    )
