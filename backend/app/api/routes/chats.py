from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.deps import CurrentUser, DbSession
from app.models import Appointment, Chat, DoctorProfile, Message, UserRole
from app.schemas import ChatPublic, MessageCreate, MessagePublic


router = APIRouter()


def can_access_chat(chat: Chat, user_id: str, role: UserRole) -> bool:
    if role == UserRole.admin:
        return True
    if role == UserRole.client:
        return chat.client_id == user_id
    if role == UserRole.doctor and chat.doctor:
        return chat.doctor.user_id == user_id
    return False


def serialize_chat(chat: Chat) -> dict:
    client = chat.client
    doctor = chat.doctor
    appointment = chat.appointment
    return {
        "id": chat.id,
        "appointment_id": chat.appointment_id,
        "client_id": chat.client_id,
        "client_name": client.name if client else None,
        "client_contact": (client.email or client.phone) if client else None,
        "doctor_id": chat.doctor_id,
        "doctor_name": doctor.name if doctor else None,
        "doctor_specialty": doctor.specialty if doctor else None,
        "appointment_starts_at": appointment.starts_at if appointment else None,
        "appointment_status": appointment.status if appointment else None,
        "last_message": chat.last_message,
        "created_at": chat.created_at,
        "updated_at": chat.updated_at,
    }


@router.get("", response_model=list[ChatPublic])
async def list_chats(db: DbSession, user: CurrentUser) -> list[dict]:
    query = select(Chat).options(
        selectinload(Chat.client),
        selectinload(Chat.doctor),
        selectinload(Chat.appointment).selectinload(Appointment.doctor),
        selectinload(Chat.appointment).selectinload(Appointment.client),
    )
    if user.role == UserRole.client:
        query = query.where(Chat.client_id == user.id)
    elif user.role == UserRole.doctor:
        query = query.join(DoctorProfile, Chat.doctor_id == DoctorProfile.id).where(
            DoctorProfile.user_id == user.id,
        )
    elif user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="not enough permissions")

    result = await db.execute(query.order_by(Chat.updated_at.desc()))
    return [serialize_chat(chat) for chat in result.scalars().all()]


@router.get("/{chat_id}/messages", response_model=list[MessagePublic])
async def list_messages(chat_id: str, db: DbSession, user: CurrentUser) -> list[Message]:
    chat = await _get_chat_for_user(chat_id, db, user)
    result = await db.execute(
        select(Message)
        .where(Message.chat_id == chat.id)
        .order_by(Message.created_at.asc()),
    )
    return list(result.scalars().all())


@router.post("/{chat_id}/messages", response_model=MessagePublic, status_code=201)
async def send_message(
    chat_id: str,
    payload: MessageCreate,
    db: DbSession,
    user: CurrentUser,
) -> Message:
    chat = await _get_chat_for_user(chat_id, db, user)
    text = payload.text.strip()
    if not text:
        raise HTTPException(status_code=422, detail="message is empty")

    message = Message(
        chat_id=chat.id,
        sender_id=user.id,
        sender_role=user.role,
        text=text,
    )
    chat.last_message = message.text
    db.add(message)
    await db.commit()
    await db.refresh(message)
    return message


async def _get_chat_for_user(chat_id: str, db: DbSession, user: CurrentUser) -> Chat:
    result = await db.execute(
        select(Chat)
        .options(
            selectinload(Chat.client),
            selectinload(Chat.doctor),
            selectinload(Chat.appointment).selectinload(Appointment.doctor),
            selectinload(Chat.appointment).selectinload(Appointment.client),
        )
        .where(Chat.id == chat_id),
    )
    chat = result.scalar_one_or_none()
    if chat is None:
        raise HTTPException(status_code=404, detail="chat not found")
    if not can_access_chat(chat, user.id, user.role):
        raise HTTPException(status_code=403, detail="not enough permissions")
    return chat
