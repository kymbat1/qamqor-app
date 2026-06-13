from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.api.routes.doctors import refresh_doctor_rating
from app.deps import CurrentUser, DbSession
from app.models import DoctorProfile, DoctorReview, UserRole
from app.schemas import ReviewCreate, ReviewPublic


router = APIRouter()


def serialize_review(review: DoctorReview) -> ReviewPublic:
    return ReviewPublic(
        id=review.id,
        doctor_id=review.doctor_id,
        client_id=review.client_id,
        client_name=review.client.name if review.client else None,
        rating=review.rating,
        text=review.text,
        created_at=review.created_at,
    )


@router.get("/doctors/{doctor_id}", response_model=list[ReviewPublic])
async def list_doctor_reviews(doctor_id: str, db: DbSession) -> list[ReviewPublic]:
    result = await db.execute(
        select(DoctorReview)
        .options(selectinload(DoctorReview.client))
        .where(DoctorReview.doctor_id == doctor_id)
        .order_by(DoctorReview.created_at.desc()),
    )
    return [serialize_review(review) for review in result.scalars().all()]


@router.post("/doctors/{doctor_id}", response_model=ReviewPublic, status_code=201)
async def add_review(
    doctor_id: str,
    payload: ReviewCreate,
    db: DbSession,
    user: CurrentUser,
) -> ReviewPublic:
    if user.role != UserRole.client:
        raise HTTPException(status_code=403, detail="client role required")
    if await db.get(DoctorProfile, doctor_id) is None:
        raise HTTPException(status_code=404, detail="doctor not found")

    existing = await db.execute(
        select(DoctorReview).where(
            DoctorReview.doctor_id == doctor_id,
            DoctorReview.client_id == user.id,
        ),
    )
    review = existing.scalar_one_or_none()
    if review is None:
        review = DoctorReview(doctor_id=doctor_id, client_id=user.id)
        db.add(review)

    review.rating = payload.rating
    review.text = payload.text.strip()
    await refresh_doctor_rating(db, doctor_id)
    await db.commit()
    await db.refresh(review)
    result = await db.execute(
        select(DoctorReview)
        .options(selectinload(DoctorReview.client))
        .where(DoctorReview.id == review.id),
    )
    return serialize_review(result.scalar_one())
