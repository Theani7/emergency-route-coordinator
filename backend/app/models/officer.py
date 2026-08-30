"""Traffic officer profile model."""

from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database.base import Base


class TrafficOfficer(Base):
    """Extended profile for traffic officer with live location tracking."""

    __tablename__ = "traffic_officers"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    assigned_zone: Mapped[str | None] = mapped_column(String(255), nullable=True, default=None)
    zone_latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    zone_longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    zone_radius_km: Mapped[float] = mapped_column(Float, default=5.0, nullable=False)
    current_latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    current_longitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    location_updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    user = relationship("User", back_populates="officer_profile")
