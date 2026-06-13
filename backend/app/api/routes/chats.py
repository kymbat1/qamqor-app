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
    if role == UserRole.doctor and chat.appointment and chat.appointment.doctor:
        return chat.appointment.doctor.user_id == user_id
    return False


@router.get("", response_model=list[ChatPublic])
async def list_chats(db: DbSession, user: CurrentUser) -> list[Chat]:
    query = select(Chat).options(
        selectinload(Chat.appointment).selectinload(Appointment.doctor),
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
    return list(result.scalars().all())


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
    message = Message(
        chat_id=chat.id,
        sender_id=user.id,
        sender_role=user.role,
        text=payload.text.strip(),
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
            selectinload(Chat.appointment).selectinload(Appointment.doctor),
        )
        .where(Chat.id == chat_id),
    )
    chat = result.scalar_one_or_none()
    if chat is None:
        raise HTTPException(status_code=404, detail="chat not found")
    if not can_access_chat(chat, user.id, user.role):
        raise HTTPException(status_code=403, detail="not enough permissions")
    return chat
