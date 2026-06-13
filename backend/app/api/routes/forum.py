from fastapi import APIRouter, HTTPException, Query
from sqlalchemy import func, or_, select
from sqlalchemy.orm import selectinload

from app.deps import CurrentUser, DbSession
from app.models import ForumComment, ForumPost, UserRole
from app.schemas import (
    ForumCommentCreate,
    ForumCommentPublic,
    ForumPostCreate,
    ForumPostPublic,
)


router = APIRouter()


def _author_name(entity: ForumPost | ForumComment) -> str:
    if entity.is_anonymous:
        return "Анонимно"
    if entity.author and entity.author.name:
        return entity.author.name
    return "Пользователь"


def _post_public(post: ForumPost, comments_count: int = 0) -> ForumPostPublic:
    return ForumPostPublic(
        id=post.id,
        author_id=post.author_id,
        author_name=_author_name(post),
        title=post.title,
        body=post.body,
        category=post.category,
        is_anonymous=post.is_anonymous,
        comments_count=comments_count,
        created_at=post.created_at,
        updated_at=post.updated_at,
    )


def _comment_public(comment: ForumComment) -> ForumCommentPublic:
    return ForumCommentPublic(
        id=comment.id,
        post_id=comment.post_id,
        author_id=comment.author_id,
        author_name=_author_name(comment),
        parent_comment_id=comment.parent_comment_id,
        body=comment.body,
        is_anonymous=comment.is_anonymous,
        created_at=comment.created_at,
    )


@router.get("/posts", response_model=list[ForumPostPublic])
async def list_posts(
    db: DbSession,
    category: str | None = None,
    search: str | None = Query(default=None, max_length=120),
) -> list[ForumPostPublic]:
    comments_count = (
        select(
            ForumComment.post_id,
            func.count(ForumComment.id).label("comments_count"),
        )
        .group_by(ForumComment.post_id)
        .subquery()
    )
    query = (
        select(ForumPost, func.coalesce(comments_count.c.comments_count, 0))
        .outerjoin(comments_count, comments_count.c.post_id == ForumPost.id)
        .options(selectinload(ForumPost.author))
        .order_by(ForumPost.created_at.desc())
    )

    if category and category != "Все":
        query = query.where(ForumPost.category == category)
    if search:
        pattern = f"%{search.strip()}%"
        query = query.where(
            or_(ForumPost.title.ilike(pattern), ForumPost.body.ilike(pattern)),
        )

    result = await db.execute(query)
    return [_post_public(post, count) for post, count in result.all()]


@router.post("/posts", response_model=ForumPostPublic, status_code=201)
async def create_post(
    payload: ForumPostCreate,
    db: DbSession,
    user: CurrentUser,
) -> ForumPostPublic:
    post = ForumPost(
        author_id=user.id,
        title=payload.title,
        body=payload.body,
        category=payload.category,
        is_anonymous=payload.is_anonymous,
    )
    db.add(post)
    await db.commit()
    await db.refresh(post)
    post.author = user
    return _post_public(post)


@router.get("/posts/{post_id}", response_model=ForumPostPublic)
async def get_post(post_id: str, db: DbSession) -> ForumPostPublic:
    result = await db.execute(
        select(ForumPost)
        .options(selectinload(ForumPost.author))
        .where(ForumPost.id == post_id),
    )
    post = result.scalar_one_or_none()
    if post is None:
        raise HTTPException(status_code=404, detail="post not found")

    count = await db.scalar(
        select(func.count(ForumComment.id)).where(ForumComment.post_id == post.id),
    )
    return _post_public(post, count or 0)


@router.delete("/posts/{post_id}", status_code=204)
async def delete_post(post_id: str, db: DbSession, user: CurrentUser) -> None:
    post = await db.get(ForumPost, post_id)
    if post is None:
        raise HTTPException(status_code=404, detail="post not found")
    if post.author_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="not enough permissions")

    await db.delete(post)
    await db.commit()


@router.get("/posts/{post_id}/comments", response_model=list[ForumCommentPublic])
async def list_comments(post_id: str, db: DbSession) -> list[ForumCommentPublic]:
    if await db.get(ForumPost, post_id) is None:
        raise HTTPException(status_code=404, detail="post not found")

    result = await db.execute(
        select(ForumComment)
        .options(selectinload(ForumComment.author))
        .where(ForumComment.post_id == post_id)
        .order_by(ForumComment.created_at.asc()),
    )
    return [_comment_public(comment) for comment in result.scalars().all()]


@router.post(
    "/posts/{post_id}/comments",
    response_model=ForumCommentPublic,
    status_code=201,
)
async def create_comment(
    post_id: str,
    payload: ForumCommentCreate,
    db: DbSession,
    user: CurrentUser,
) -> ForumCommentPublic:
    if await db.get(ForumPost, post_id) is None:
        raise HTTPException(status_code=404, detail="post not found")

    if payload.parent_comment_id:
        parent = await db.get(ForumComment, payload.parent_comment_id)
        if parent is None or parent.post_id != post_id:
            raise HTTPException(status_code=422, detail="invalid parent comment")

    comment = ForumComment(
        post_id=post_id,
        author_id=user.id,
        parent_comment_id=payload.parent_comment_id,
        body=payload.body,
        is_anonymous=payload.is_anonymous,
    )
    db.add(comment)
    await db.commit()
    await db.refresh(comment)
    comment.author = user
    return _comment_public(comment)
