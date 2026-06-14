from datetime import datetime
from enum import Enum
from uuid import uuid4

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum as SqlEnum,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


def new_id() -> str:
    return str(uuid4())


class Base(DeclarativeBase):
    pass


class UserRole(str, Enum):
    admin = "admin"
    doctor = "doctor"
    client = "client"


class AppointmentStatus(str, Enum):
    scheduled = "scheduled"
    confirmed = "confirmed"
    completed = "completed"
    cancelled = "cancelled"


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    email: Mapped[str | None] = mapped_column(String(255), unique=True, index=True)
    phone: Mapped[str | None] = mapped_column(String(32), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[UserRole] = mapped_column(SqlEnum(UserRole), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    email_verified: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    doctor_profile: Mapped["DoctorProfile | None"] = relationship(
        back_populates="user",
        uselist=False,
        cascade="all, delete-orphan",
    )
    cycle_entries: Mapped[list["CycleEntry"]] = relationship(
        back_populates="user",
        cascade="all, delete-orphan",
    )


class EmailVerificationCode(Base):
    __tablename__ = "email_verification_codes"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    email: Mapped[str] = mapped_column(String(255), index=True, nullable=False)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[UserRole] = mapped_column(SqlEnum(UserRole), nullable=False)
    code_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    salt: Mapped[str] = mapped_column(String(64), nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    send_count: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_used: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    resend_available_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    __table_args__ = (
        Index("ix_email_verification_email_used", "email", "is_used"),
    )


class DoctorProfile(Base):
    __tablename__ = "doctor_profiles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="SET NULL"),
        unique=True,
    )
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    specialty: Mapped[str] = mapped_column(String(160), default="", nullable=False)
    university: Mapped[str] = mapped_column(String(200), default="", nullable=False)
    hospital: Mapped[str] = mapped_column(String(200), default="", nullable=False)
    description: Mapped[str] = mapped_column(Text, default="", nullable=False)
    gender: Mapped[str] = mapped_column(String(32), default="female", nullable=False)
    city: Mapped[str] = mapped_column(String(120), default="", nullable=False)
    address: Mapped[str] = mapped_column(String(255), default="", nullable=False)
    latitude: Mapped[float | None] = mapped_column(Float)
    longitude: Mapped[float | None] = mapped_column(Float)
    years_of_experience: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    consultation_fee: Mapped[float] = mapped_column(Float, default=0, nullable=False)
    is_online: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    avatar_color: Mapped[str] = mapped_column(String(32), default="#FF1493")
    rating: Mapped[float] = mapped_column(Float, default=0, nullable=False)
    review_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    user: Mapped[User | None] = relationship(back_populates="doctor_profile")
    appointments: Mapped[list["Appointment"]] = relationship(back_populates="doctor")
    reviews: Mapped[list["DoctorReview"]] = relationship(
        back_populates="doctor",
        cascade="all, delete-orphan",
    )


class Appointment(Base):
    __tablename__ = "appointments"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    client_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    doctor_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("doctor_profiles.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    status: Mapped[AppointmentStatus] = mapped_column(
        SqlEnum(AppointmentStatus),
        default=AppointmentStatus.scheduled,
        nullable=False,
    )
    reason: Mapped[str] = mapped_column(Text, default="", nullable=False)
    chat_id: Mapped[str] = mapped_column(String(36), index=True, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    client: Mapped[User] = relationship()
    doctor: Mapped[DoctorProfile] = relationship(back_populates="appointments")
    chat: Mapped["Chat"] = relationship(back_populates="appointment", uselist=False)

    __table_args__ = (
        UniqueConstraint("doctor_id", "starts_at", name="uq_doctor_appointment_time"),
    )


class Chat(Base):
    __tablename__ = "chats"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    appointment_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("appointments.id", ondelete="SET NULL"),
        unique=True,
    )
    client_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    doctor_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("doctor_profiles.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    last_message: Mapped[str] = mapped_column(Text, default="", nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    appointment: Mapped[Appointment | None] = relationship(back_populates="chat")
    client: Mapped[User] = relationship(foreign_keys=[client_id])
    doctor: Mapped[DoctorProfile] = relationship(foreign_keys=[doctor_id])
    messages: Mapped[list["Message"]] = relationship(
        back_populates="chat",
        cascade="all, delete-orphan",
    )


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    chat_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("chats.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    sender_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    sender_role: Mapped[UserRole] = mapped_column(SqlEnum(UserRole), nullable=False)
    text: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        index=True,
        nullable=False,
    )

    chat: Mapped[Chat] = relationship(back_populates="messages")
    sender: Mapped[User] = relationship()


class DoctorReview(Base):
    __tablename__ = "doctor_reviews"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    doctor_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("doctor_profiles.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    client_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    rating: Mapped[float] = mapped_column(Float, nullable=False)
    text: Mapped[str] = mapped_column(Text, default="", nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    doctor: Mapped[DoctorProfile] = relationship(back_populates="reviews")
    client: Mapped[User] = relationship()

    __table_args__ = (
        UniqueConstraint("doctor_id", "client_id", name="uq_one_review_per_client"),
    )


class CycleEntry(Base):
    __tablename__ = "cycle_entries"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    day_key: Mapped[str] = mapped_column(String(10), nullable=False)
    cycle_day: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_period_day: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    flow: Mapped[str | None] = mapped_column(String(64))
    mood: Mapped[str | None] = mapped_column(String(64))
    symptoms: Mapped[str] = mapped_column(Text, default="", nullable=False)
    details: Mapped[str] = mapped_column(Text, default="{}", nullable=False)
    note: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    user: Mapped[User] = relationship(back_populates="cycle_entries")

    __table_args__ = (
        UniqueConstraint("user_id", "day_key", name="uq_user_cycle_day"),
        Index("ix_cycle_user_day", "user_id", "day_key"),
    )


class ForumPost(Base):
    __tablename__ = "forum_posts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    author_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String(180), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    category: Mapped[str] = mapped_column(String(80), default="Общее", index=True)
    is_anonymous: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    author: Mapped[User] = relationship()
    comments: Mapped[list["ForumComment"]] = relationship(
        back_populates="post",
        cascade="all, delete-orphan",
    )

    __table_args__ = (
        Index("ix_forum_posts_created_at", "created_at"),
        Index("ix_forum_posts_category_created_at", "category", "created_at"),
    )


class ForumComment(Base):
    __tablename__ = "forum_comments"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    post_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("forum_posts.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    author_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    parent_comment_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey("forum_comments.id", ondelete="CASCADE"),
        index=True,
    )
    body: Mapped[str] = mapped_column(Text, nullable=False)
    is_anonymous: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    post: Mapped[ForumPost] = relationship(back_populates="comments")
    author: Mapped[User] = relationship()
