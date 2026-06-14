from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.models import AppointmentStatus, UserRole


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    name: str
    email: str | None = None
    phone: str | None = None
    role: UserRole
    is_active: bool
    email_verified: bool
    created_at: datetime


class RegisterRequest(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    email: EmailStr | None = None
    phone: str | None = Field(default=None, max_length=32)
    password: str = Field(min_length=8, max_length=72)
    role: UserRole = UserRole.client

    @field_validator("role")
    @classmethod
    def block_admin_self_registration(cls, value: UserRole) -> UserRole:
        if value == UserRole.admin:
            raise ValueError("admin cannot self-register")
        return value

    @field_validator("email", "phone")
    @classmethod
    def trim_optional(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, value: str | None) -> str | None:
        if value is None:
            return None
        allowed = "+0123456789"
        clean = "".join(ch for ch in value if ch in allowed)
        if len(clean) < 10:
            raise ValueError("invalid phone")
        return clean


class RegisterStartRequest(RegisterRequest):
    email: EmailStr
    phone: None = None
    website: str | None = Field(default=None, max_length=120)
    captcha_token: str | None = Field(default=None, max_length=2048)

    @field_validator("website")
    @classmethod
    def trim_honeypot(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None


class RegisterStartResponse(BaseModel):
    email: EmailStr
    expires_at: datetime
    resend_available_at: datetime
    message: str
    debug_code: str | None = None


class RegisterVerifyRequest(BaseModel):
    email: EmailStr
    code: str = Field(min_length=4, max_length=12)

    @field_validator("code")
    @classmethod
    def normalize_code(cls, value: str) -> str:
        clean = "".join(ch for ch in value.strip() if ch.isdigit())
        if len(clean) != 6:
            raise ValueError("code must contain 6 digits")
        return clean


class RegisterResendRequest(BaseModel):
    email: EmailStr
    website: str | None = Field(default=None, max_length=120)

    @field_validator("website")
    @classmethod
    def trim_resend_honeypot(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=160)
    phone: str | None = Field(default=None, max_length=32)


class DoctorProfileBase(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    specialty: str = Field(default="", max_length=160)
    university: str = Field(default="", max_length=200)
    hospital: str = Field(default="", max_length=200)
    description: str = ""
    gender: str = Field(default="female", max_length=32)
    city: str = Field(default="", max_length=120)
    address: str = Field(default="", max_length=255)
    latitude: float | None = None
    longitude: float | None = None
    years_of_experience: int = Field(default=0, ge=0, le=80)
    consultation_fee: float = Field(default=0, ge=0)
    is_online: bool = True
    avatar_color: str = "#FF1493"


class DoctorProfileCreate(DoctorProfileBase):
    user_id: str | None = None


class DoctorProfileUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=160)
    specialty: str | None = Field(default=None, max_length=160)
    university: str | None = Field(default=None, max_length=200)
    hospital: str | None = Field(default=None, max_length=200)
    description: str | None = None
    gender: str | None = Field(default=None, max_length=32)
    city: str | None = Field(default=None, max_length=120)
    address: str | None = Field(default=None, max_length=255)
    latitude: float | None = None
    longitude: float | None = None
    years_of_experience: int | None = Field(default=None, ge=0, le=80)
    consultation_fee: float | None = Field(default=None, ge=0)
    is_online: bool | None = None
    avatar_color: str | None = None


class DoctorProfilePublic(DoctorProfileBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str | None = None
    rating: float
    review_count: int
    created_at: datetime
    updated_at: datetime


class AppointmentCreate(BaseModel):
    doctor_id: str
    starts_at: datetime
    reason: str = ""


class AppointmentStatusUpdate(BaseModel):
    status: AppointmentStatus


class AppointmentPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    client_id: str
    client_name: str | None = None
    client_contact: str | None = None
    doctor_id: str
    doctor_name: str | None = None
    doctor_specialty: str | None = None
    starts_at: datetime
    status: AppointmentStatus
    reason: str
    chat_id: str
    created_at: datetime
    updated_at: datetime


class CycleEntryCreate(BaseModel):
    day_key: str = Field(pattern=r"^\d{4}-\d{2}-\d{2}$")
    cycle_day: int = Field(default=1, ge=1, le=120)
    is_period_day: bool = True
    flow: str | None = None
    mood: str | None = None
    symptoms: list[str] = Field(default_factory=list)
    cycle_phase: str | None = Field(default=None, max_length=80)
    weight_kg: float | None = Field(default=None, ge=20, le=300)
    height_cm: float | None = Field(default=None, ge=80, le=250)
    temperature_c: float | None = Field(default=None, ge=34, le=43)
    sleep_hours: float | None = Field(default=None, ge=0, le=24)
    pain_level: int | None = Field(default=None, ge=0, le=10)
    energy_level: int | None = Field(default=None, ge=1, le=5)
    stress_level: int | None = Field(default=None, ge=1, le=5)
    discharge: str | None = Field(default=None, max_length=120)
    libido: str | None = Field(default=None, max_length=80)
    appetite: str | None = Field(default=None, max_length=80)
    activity: str | None = Field(default=None, max_length=120)
    medication: str | None = Field(default=None, max_length=255)
    note: str | None = None


class CycleEntryPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    day_key: str
    cycle_day: int
    is_period_day: bool
    flow: str | None = None
    mood: str | None = None
    symptoms: list[str]
    cycle_phase: str | None = None
    weight_kg: float | None = None
    height_cm: float | None = None
    temperature_c: float | None = None
    sleep_hours: float | None = None
    pain_level: int | None = None
    energy_level: int | None = None
    stress_level: int | None = None
    discharge: str | None = None
    libido: str | None = None
    appetite: str | None = None
    activity: str | None = None
    medication: str | None = None
    note: str | None = None
    created_at: datetime
    updated_at: datetime


class ReviewCreate(BaseModel):
    rating: float = Field(ge=1, le=5)
    text: str = Field(default="", max_length=2000)


class ReviewPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    doctor_id: str
    client_id: str
    client_name: str | None = None
    rating: float
    text: str
    created_at: datetime


class ChatPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    appointment_id: str | None = None
    client_id: str
    client_name: str | None = None
    client_contact: str | None = None
    doctor_id: str
    doctor_name: str | None = None
    doctor_specialty: str | None = None
    appointment_starts_at: datetime | None = None
    appointment_status: AppointmentStatus | None = None
    last_message: str
    created_at: datetime
    updated_at: datetime


class MessageCreate(BaseModel):
    text: str = Field(min_length=1, max_length=4000)


class MessagePublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    chat_id: str
    sender_id: str
    sender_role: UserRole
    text: str
    created_at: datetime


class AiChatRequest(BaseModel):
    question: str = Field(min_length=2, max_length=1200)

    @field_validator("question")
    @classmethod
    def trim_question(cls, value: str) -> str:
        return value.strip()


class AiDoctorSuggestion(BaseModel):
    id: str
    name: str
    specialty: str
    city: str
    hospital: str
    rating: float
    consultation_fee: float


class AiChatResponse(BaseModel):
    answer: str
    source: str
    used_cycle_context: bool
    needs_doctor: bool
    doctors: list[AiDoctorSuggestion] = Field(default_factory=list)


class ForumPostCreate(BaseModel):
    title: str = Field(min_length=4, max_length=180)
    body: str = Field(min_length=10, max_length=5000)
    category: str = Field(default="Общее", min_length=2, max_length=80)
    is_anonymous: bool = False

    @field_validator("title", "body", "category", mode="before")
    @classmethod
    def trim_forum_text(cls, value: str) -> str:
        return value.strip() if isinstance(value, str) else value


class ForumPostPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    author_id: str
    author_name: str
    title: str
    body: str
    category: str
    is_anonymous: bool
    comments_count: int = 0
    created_at: datetime
    updated_at: datetime


class ForumCommentCreate(BaseModel):
    body: str = Field(min_length=1, max_length=2500)
    is_anonymous: bool = False
    parent_comment_id: str | None = None

    @field_validator("body", mode="before")
    @classmethod
    def trim_comment_body(cls, value: str) -> str:
        return value.strip() if isinstance(value, str) else value


class ForumCommentPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    post_id: str
    author_id: str
    author_name: str
    parent_comment_id: str | None = None
    body: str
    is_anonymous: bool
    created_at: datetime
