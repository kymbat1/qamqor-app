from fastapi import APIRouter, HTTPException
from sqlalchemy import select

from app.deps import CurrentUser, DbSession
from app.models import DoctorProfile, UserRole
from app.schemas import AiChatRequest, AiChatResponse, AiDoctorSuggestion
from app.services.ai_assistant import (
    answer_with_cycle_context,
    build_cycle_snapshot,
)


router = APIRouter()


@router.post("/chat", response_model=AiChatResponse)
async def ai_chat(
    payload: AiChatRequest,
    db: DbSession,
    user: CurrentUser,
) -> AiChatResponse:
    if user.role not in {UserRole.client, UserRole.admin}:
        raise HTTPException(status_code=403, detail="client role required")

    doctors_result = await db.execute(
        select(DoctorProfile)
        .where(DoctorProfile.is_online.is_(True))
        .order_by(DoctorProfile.rating.desc(), DoctorProfile.review_count.desc())
        .limit(5),
    )
    doctors = list(doctors_result.scalars().all())
    snapshot = await build_cycle_snapshot(db, user)
    result = await answer_with_cycle_context(
        question=payload.question,
        snapshot=snapshot,
        doctors=doctors,
    )

    return AiChatResponse(
        answer=result.answer,
        source=result.source,
        used_cycle_context=result.used_cycle_context,
        needs_doctor=result.needs_doctor,
        doctors=[
            AiDoctorSuggestion(
                id=doctor.id,
                name=doctor.name,
                specialty=doctor.specialty,
                city=doctor.city,
                hospital=doctor.hospital,
                rating=doctor.rating,
                consultation_fee=doctor.consultation_fee,
            )
            for doctor in doctors
        ]
        if result.needs_doctor
        else [],
    )
