from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select

from app.deps import CurrentUser, DbSession, get_current_doctor_profile, require_roles
from app.models import DoctorProfile, DoctorReview, User, UserRole
from app.schemas import DoctorProfileCreate, DoctorProfilePublic, DoctorProfileUpdate


router = APIRouter()


@router.get("", response_model=list[DoctorProfilePublic])
async def list_doctors(
    db: DbSession,
    city: str | None = Query(default=None),
    specialty: str | None = Query(default=None),
    only_online: bool = False,
    sort: str = Query(default="rating"),
) -> list[DoctorProfile]:
    query = select(DoctorProfile)
    if city:
        query = query.where(DoctorProfile.city.ilike(f"%{city.strip()}%"))
    if specialty:
        query = query.where(DoctorProfile.specialty.ilike(f"%{specialty.strip()}%"))
    if only_online:
        query = query.where(DoctorProfile.is_online.is_(True))

    if sort == "price_asc":
        query = query.order_by(DoctorProfile.consultation_fee.asc())
    elif sort == "price_desc":
        query = query.order_by(DoctorProfile.consultation_fee.desc())
    elif sort == "experience":
        query = query.order_by(DoctorProfile.years_of_experience.desc())
    else:
        query = query.order_by(DoctorProfile.rating.desc(), DoctorProfile.review_count.desc())

    result = await db.execute(query)
    return list(result.scalars().all())


@router.get("/me", response_model=DoctorProfilePublic)
async def my_doctor_profile(
    profile: DoctorProfile = Depends(get_current_doctor_profile),
) -> DoctorProfile:
    return profile


@router.patch("/me", response_model=DoctorProfilePublic)
async def update_my_doctor_profile(
    payload: DoctorProfileUpdate,
    db: DbSession,
    profile: DoctorProfile = Depends(get_current_doctor_profile),
) -> DoctorProfile:
    data = payload.model_dump(exclude_unset=True)
    for field, value in data.items():
        if value is not None:
            setattr(profile, field, value.strip() if isinstance(value, str) else value)
    await db.commit()
    await db.refresh(profile)
    return profile


@router.post("", response_model=DoctorProfilePublic, status_code=201)
async def create_doctor(
    payload: DoctorProfileCreate,
    db: DbSession,
    user: CurrentUser,
) -> DoctorProfile:
    if user.role not in {UserRole.admin, UserRole.doctor}:
        raise HTTPException(status_code=403, detail="not enough permissions")

    user_id = payload.user_id if user.role == UserRole.admin else user.id
    if user_id:
        existing = await db.execute(
            select(DoctorProfile).where(DoctorProfile.user_id == user_id),
        )
        if existing.scalar_one_or_none() is not None:
            raise HTTPException(status_code=409, detail="doctor profile already exists")

    profile = DoctorProfile(**payload.model_dump())
    if user.role == UserRole.doctor:
        profile.user_id = user.id
        profile.name = payload.name or user.name
    db.add(profile)
    await db.commit()
    await db.refresh(profile)
    return profile


@router.get("/{doctor_id}", response_model=DoctorProfilePublic)
async def get_doctor(doctor_id: str, db: DbSession) -> DoctorProfile:
    doctor = await db.get(DoctorProfile, doctor_id)
    if doctor is None:
        raise HTTPException(status_code=404, detail="doctor not found")
    return doctor


async def refresh_doctor_rating(db: DbSession, doctor_id: str) -> None:
    result = await db.execute(
        select(
            func.coalesce(func.avg(DoctorReview.rating), 0),
            func.count(DoctorReview.id),
        ).where(DoctorReview.doctor_id == doctor_id),
    )
    rating, count = result.one()
    doctor = await db.get(DoctorProfile, doctor_id)
    if doctor is not None:
        doctor.rating = round(float(rating or 0), 2)
        doctor.review_count = int(count or 0)
