from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncEngine, async_sessionmaker

from app.core.config import get_settings
from app.core.security import hash_password
from app.models import (
    Appointment,
    Base,
    Chat,
    CycleEntry,
    DoctorProfile,
    DoctorReview,
    EmailVerificationCode,
    ForumComment,
    ForumPost,
    Message,
    User,
    UserRole,
)


DOCTORS = [
    {
        "email": "asel.satova@qamqor.kz",
        "legacy_email": "asel.satova@qamqor.local",
        "name": "Асель Сатова",
        "specialty": "Гинеколог-репродуктолог",
        "university": "КазНМУ им. Асфендиярова",
        "hospital": "Центр женского здоровья Аяла",
        "description": "Помогает с планированием беременности, нарушениями цикла и подготовкой к ЭКО.",
        "city": "Алматы",
        "address": "ул. Байтурсынова, 96",
        "latitude": 43.2389,
        "longitude": 76.9287,
        "years_of_experience": 15,
        "consultation_fee": 7500,
        "rating": 4.9,
        "review_count": 128,
        "avatar_color": "#FF1493",
    },
    {
        "email": "lyazzat.kuanysheva@qamqor.kz",
        "legacy_email": "lyazzat.kuanysheva@qamqor.local",
        "name": "Ляззат Куанышева",
        "specialty": "Маммолог",
        "university": "Казахстанско-Российский медуниверситет",
        "hospital": "Клиника Мейірім",
        "description": "Специализируется на диагностике молочных желез и профилактике.",
        "city": "Алматы",
        "address": "пр. Абая, 52",
        "latitude": 43.2416,
        "longitude": 76.9098,
        "years_of_experience": 10,
        "consultation_fee": 6500,
        "rating": 4.8,
        "review_count": 94,
        "avatar_color": "#FF69B4",
    },
    {
        "email": "amina.omarova@qamqor.kz",
        "legacy_email": "amina.omarova@qamqor.local",
        "name": "Амина Омарова",
        "specialty": "Эндокринолог",
        "university": "Медицинский университет Астана",
        "hospital": "Qamqor Medical",
        "description": "Работает с гормональным балансом, усталостью и изменениями веса.",
        "city": "Астана",
        "address": "пр. Кабанбай батыра, 48",
        "latitude": 51.0907,
        "longitude": 71.4187,
        "years_of_experience": 8,
        "consultation_fee": 6000,
        "rating": 4.7,
        "review_count": 73,
        "avatar_color": "#C71585",
    },
    {
        "email": "dana.ergalieva@qamqor.kz",
        "legacy_email": "dana.ergalieva@qamqor.local",
        "name": "Дана Ергалиева",
        "specialty": "Акушер-гинеколог",
        "university": "КазНМУ им. Асфендиярова",
        "hospital": "Женская клиника Sana",
        "description": "Принимает по вопросам цикла, контрацепции, беременности и профилактических осмотров.",
        "city": "Шымкент",
        "address": "ул. Рыскулова, 18",
        "latitude": 42.3417,
        "longitude": 69.5901,
        "years_of_experience": 6,
        "consultation_fee": 5500,
        "rating": 5.0,
        "review_count": 61,
        "avatar_color": "#FF1493",
    },
]


async def initialize_database(engine: AsyncEngine) -> None:
    await _ensure_existing_enum_values(engine)
    async with engine.begin() as connection:
        await connection.run_sync(Base.metadata.create_all)
        await _ensure_legacy_columns(connection)


async def seed_core_data(session_factory: async_sessionmaker) -> None:
    settings = get_settings()
    async with session_factory() as session:
        admin_user = await _find_or_upgrade_user_email(
            session,
            new_email=settings.admin_email.lower(),
            legacy_email="admin@qamqor.local",
        )
        if admin_user is None:
            session.add(
                User(
                    name=settings.admin_name,
                    email=settings.admin_email.lower(),
                    role=UserRole.admin,
                    password_hash=hash_password(settings.admin_password),
                ),
            )

        for item in DOCTORS:
            email = item["email"].lower()
            doctor_user = await _find_or_upgrade_user_email(
                session,
                new_email=email,
                legacy_email=item.get("legacy_email"),
            )
            if doctor_user is None:
                doctor_user = User(
                    name=item["name"],
                    email=email,
                    role=UserRole.doctor,
                    password_hash=hash_password(settings.doctor_password),
                )
                session.add(doctor_user)
                await session.flush()
            elif doctor_user.role != UserRole.admin:
                doctor_user.role = UserRole.doctor

            existing = await session.execute(
                select(DoctorProfile).where(DoctorProfile.name == item["name"]),
            )
            profile = existing.scalar_one_or_none()
            profile_data = {
                key: value
                for key, value in item.items()
                if key not in {"email", "legacy_email"}
            }
            if profile is None:
                session.add(DoctorProfile(**profile_data, user_id=doctor_user.id))
            elif profile.user_id is None:
                profile.user_id = doctor_user.id

        await session.commit()


async def _find_or_upgrade_user_email(
    session,
    *,
    new_email: str,
    legacy_email: str | None = None,
) -> User | None:
    emails = [new_email]
    if legacy_email and legacy_email != new_email:
        emails.append(legacy_email)

    result = await session.execute(select(User).where(User.email.in_(emails)))
    users = result.scalars().all()
    if not users:
        return None

    current = next((user for user in users if user.email == new_email), users[0])
    if current.email != new_email and len(users) == 1:
        current.email = new_email
    return current


async def database_summary(session_factory: async_sessionmaker) -> dict[str, int]:
    models = {
        "users": User,
        "email_verification_codes": EmailVerificationCode,
        "doctor_profiles": DoctorProfile,
        "appointments": Appointment,
        "chats": Chat,
        "messages": Message,
        "doctor_reviews": DoctorReview,
        "cycle_entries": CycleEntry,
        "forum_posts": ForumPost,
        "forum_comments": ForumComment,
    }
    async with session_factory() as session:
        summary: dict[str, int] = {}
        for name, model in models.items():
            summary[name] = int(await session.scalar(select(func.count(model.id))) or 0)
        return summary


async def _ensure_existing_enum_values(engine: AsyncEngine) -> None:
    async with engine.begin() as connection:
        await _ensure_enum_values(connection, "userrole", ["admin", "doctor", "client"])
        await _ensure_enum_values(
            connection,
            "appointmentstatus",
            ["scheduled", "confirmed", "completed", "cancelled"],
        )


async def _ensure_enum_values(connection, enum_name: str, values: list[str]) -> None:
    exists = await connection.scalar(
        text("SELECT EXISTS (SELECT 1 FROM pg_type WHERE typname = :enum_name)"),
        {"enum_name": enum_name},
    )
    if not exists:
        return

    for value in values:
        has_value = await connection.scalar(
            text(
                "SELECT EXISTS ("
                "SELECT 1 FROM pg_enum "
                "JOIN pg_type ON pg_enum.enumtypid = pg_type.oid "
                "WHERE pg_type.typname = :enum_name AND pg_enum.enumlabel = :value"
                ")",
            ),
            {"enum_name": enum_name, "value": value},
        )
        if has_value:
            continue

        await connection.execute(text(f"ALTER TYPE {enum_name} ADD VALUE '{value}'"))


async def _ensure_legacy_columns(connection) -> None:
    statements = [
        "ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS phone VARCHAR(32)",
        "ALTER TABLE IF EXISTS users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT TRUE NOT NULL",
        "ALTER TABLE IF EXISTS doctor_profiles ADD COLUMN IF NOT EXISTS university VARCHAR(200) DEFAULT '' NOT NULL",
        "ALTER TABLE IF EXISTS doctor_profiles ADD COLUMN IF NOT EXISTS description TEXT DEFAULT '' NOT NULL",
        "ALTER TABLE IF EXISTS doctor_profiles ADD COLUMN IF NOT EXISTS gender VARCHAR(32) DEFAULT 'female' NOT NULL",
        "ALTER TABLE IF EXISTS doctor_profiles ADD COLUMN IF NOT EXISTS city VARCHAR(120) DEFAULT '' NOT NULL",
        "ALTER TABLE IF EXISTS doctor_profiles ADD COLUMN IF NOT EXISTS address VARCHAR(255) DEFAULT '' NOT NULL",
        "ALTER TABLE IF EXISTS doctor_profiles ADD COLUMN IF NOT EXISTS latitude FLOAT",
        "ALTER TABLE IF EXISTS doctor_profiles ADD COLUMN IF NOT EXISTS longitude FLOAT",
        "ALTER TABLE IF EXISTS doctor_profiles ADD COLUMN IF NOT EXISTS years_of_experience INTEGER DEFAULT 0 NOT NULL",
        "ALTER TABLE IF EXISTS doctor_profiles ADD COLUMN IF NOT EXISTS consultation_fee FLOAT DEFAULT 0 NOT NULL",
        "ALTER TABLE IF EXISTS doctor_profiles ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT TRUE NOT NULL",
        "ALTER TABLE IF EXISTS doctor_profiles ADD COLUMN IF NOT EXISTS avatar_color VARCHAR(32) DEFAULT '#FF1493'",
        "ALTER TABLE IF EXISTS doctor_profiles ADD COLUMN IF NOT EXISTS rating FLOAT DEFAULT 0 NOT NULL",
        "ALTER TABLE IF EXISTS doctor_profiles ADD COLUMN IF NOT EXISTS review_count INTEGER DEFAULT 0 NOT NULL",
        "ALTER TABLE IF EXISTS cycle_entries ADD COLUMN IF NOT EXISTS details TEXT DEFAULT '{}' NOT NULL",
    ]
    for statement in statements:
        await connection.execute(text(statement))
