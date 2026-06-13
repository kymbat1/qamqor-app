from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.deps import CurrentUser, DbSession
from app.models import Appointment, AppointmentStatus, Chat, DoctorProfile, UserRole
from app.schemas import AppointmentCreate, AppointmentPublic, AppointmentStatusUpdate


router = APIRouter()


def serialize_appointment(appointment: Appointment) -> dict:
    client = appointment.client
    doctor = appointment.doctor
    return {
        "id": appointment.id,
        "client_id": appointment.client_id,
        "client_name": client.name if client else None,
        "client_contact": (client.email or client.phone) if client else None,
        "doctor_id": appointment.doctor_id,
        "doctor_name": doctor.name if doctor else None,
        "doctor_specialty": doctor.specialty if doctor else None,
        "starts_at": appointment.starts_at,
        "status": appointment.status,
        "reason": appointment.reason,
        "chat_id": appointment.chat_id,
        "created_at": appointment.created_at,
        "updated_at": appointment.updated_at,
    }


@router.post("", response_model=AppointmentPublic, status_code=201)
async def create_appointment(
    payload: AppointmentCreate,
    db: DbSession,
    user: CurrentUser,
) -> dict:
    if user.role != UserRole.client:
        raise HTTPException(status_code=403, detail="client role required")

    doctor = await db.get(DoctorProfile, payload.doctor_id)
    if doctor is None:
        raise HTTPException(status_code=404, detail="doctor not found")

    appointment = Appointment(
        client_id=user.id,
        doctor_id=doctor.id,
        starts_at=payload.starts_at,
        reason=payload.reason.strip(),
        status=AppointmentStatus.scheduled,
        chat_id="",
    )
    db.add(appointment)
    await db.flush()

    chat = Chat(
        appointment_id=appointment.id,
        client_id=user.id,
        doctor_id=doctor.id,
    )
    db.add(chat)
    await db.flush()
    appointment.chat_id = chat.id

    await db.commit()
    result = await db.execute(
        select(Appointment)
        .options(selectinload(Appointment.client), selectinload(Appointment.doctor))
        .where(Appointment.id == appointment.id),
    )
    return serialize_appointment(result.scalar_one())


@router.get("", response_model=list[AppointmentPublic])
async def list_appointments(db: DbSession, user: CurrentUser) -> list[dict]:
    query = (
        select(Appointment)
        .options(selectinload(Appointment.client), selectinload(Appointment.doctor))
        .order_by(Appointment.starts_at.asc())
    )
    if user.role == UserRole.client:
        query = query.where(Appointment.client_id == user.id)
    elif user.role == UserRole.doctor:
        doctor_result = await db.execute(
            select(DoctorProfile).where(DoctorProfile.user_id == user.id),
        )
        doctor = doctor_result.scalar_one_or_none()
        if doctor is None:
            return []
        query = query.where(Appointment.doctor_id == doctor.id)
    elif user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="not enough permissions")

    result = await db.execute(query)
    return [serialize_appointment(item) for item in result.scalars().all()]


@router.patch("/{appointment_id}/status", response_model=AppointmentPublic)
async def update_status(
    appointment_id: str,
    payload: AppointmentStatusUpdate,
    db: DbSession,
    user: CurrentUser,
) -> dict:
    result = await db.execute(
        select(Appointment)
        .options(selectinload(Appointment.client), selectinload(Appointment.doctor))
        .where(Appointment.id == appointment_id),
    )
    appointment = result.scalar_one_or_none()
    if appointment is None:
        raise HTTPException(status_code=404, detail="appointment not found")

    is_client_owner = user.role == UserRole.client and appointment.client_id == user.id
    is_doctor_owner = (
        user.role == UserRole.doctor and appointment.doctor.user_id == user.id
    )
    if user.role != UserRole.admin and not is_client_owner and not is_doctor_owner:
        raise HTTPException(status_code=403, detail="not enough permissions")

    if is_client_owner and payload.status != AppointmentStatus.cancelled:
        raise HTTPException(status_code=403, detail="client can only cancel")

    appointment.status = payload.status
    await db.commit()
    result = await db.execute(
        select(Appointment)
        .options(selectinload(Appointment.client), selectinload(Appointment.doctor))
        .where(Appointment.id == appointment.id),
    )
    return serialize_appointment(result.scalar_one())
