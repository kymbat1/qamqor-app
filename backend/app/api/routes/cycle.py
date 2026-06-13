import json
from datetime import date, datetime, timedelta
from io import BytesIO
from pathlib import Path

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse
from sqlalchemy import select

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

from app.deps import CurrentUser, DbSession
from app.models import CycleEntry, UserRole
from app.schemas import CycleEntryCreate, CycleEntryPublic


router = APIRouter()

DETAIL_FIELDS = (
    "cycle_phase",
    "weight_kg",
    "height_cm",
    "temperature_c",
    "sleep_hours",
    "pain_level",
    "energy_level",
    "stress_level",
    "discharge",
    "libido",
    "appetite",
    "activity",
    "medication",
)


def _load_details(entry: CycleEntry) -> dict:
    try:
        details = json.loads(entry.details or "{}")
        return details if isinstance(details, dict) else {}
    except json.JSONDecodeError:
        return {}


def serialize_entry(entry: CycleEntry) -> CycleEntryPublic:
    details = _load_details(entry)
    return CycleEntryPublic(
        id=entry.id,
        user_id=entry.user_id,
        day_key=entry.day_key,
        cycle_day=entry.cycle_day,
        is_period_day=entry.is_period_day,
        flow=entry.flow,
        mood=entry.mood,
        symptoms=json.loads(entry.symptoms or "[]"),
        cycle_phase=details.get("cycle_phase"),
        weight_kg=details.get("weight_kg"),
        height_cm=details.get("height_cm"),
        temperature_c=details.get("temperature_c"),
        sleep_hours=details.get("sleep_hours"),
        pain_level=details.get("pain_level"),
        energy_level=details.get("energy_level"),
        stress_level=details.get("stress_level"),
        discharge=details.get("discharge"),
        libido=details.get("libido"),
        appetite=details.get("appetite"),
        activity=details.get("activity"),
        medication=details.get("medication"),
        note=entry.note,
        created_at=entry.created_at,
        updated_at=entry.updated_at,
    )


@router.get("", response_model=list[CycleEntryPublic])
async def list_cycle_entries(db: DbSession, user: CurrentUser) -> list[CycleEntryPublic]:
    if user.role not in {UserRole.client, UserRole.admin}:
        raise HTTPException(status_code=403, detail="client role required")
    result = await db.execute(
        select(CycleEntry)
        .where(CycleEntry.user_id == user.id)
        .order_by(CycleEntry.day_key.asc()),
    )
    return [serialize_entry(entry) for entry in result.scalars().all()]


@router.get("/report.pdf")
async def cycle_report_pdf(
    db: DbSession,
    user: CurrentUser,
    start: date | None = Query(default=None),
    end: date | None = Query(default=None),
) -> StreamingResponse:
    if user.role not in {UserRole.client, UserRole.admin}:
        raise HTTPException(status_code=403, detail="client role required")

    today = date.today()
    end_date = end or today
    start_date = start or (end_date - timedelta(days=365))
    if start_date > end_date:
        raise HTTPException(status_code=422, detail="start must be before end")

    entries = await _entries_for_period(db, user.id, start_date, end_date)
    pdf = _build_cycle_report_pdf(user.name, start_date, end_date, entries)
    filename = f"cycle-report-{start_date.isoformat()}-{end_date.isoformat()}.pdf"
    return StreamingResponse(
        BytesIO(pdf),
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.post("", response_model=CycleEntryPublic, status_code=201)
async def upsert_cycle_entry(
    payload: CycleEntryCreate,
    db: DbSession,
    user: CurrentUser,
) -> CycleEntryPublic:
    if user.role != UserRole.client:
        raise HTTPException(status_code=403, detail="client role required")

    result = await db.execute(
        select(CycleEntry).where(
            CycleEntry.user_id == user.id,
            CycleEntry.day_key == payload.day_key,
        ),
    )
    entry = result.scalar_one_or_none()
    if entry is None:
        entry = CycleEntry(user_id=user.id, day_key=payload.day_key)
        db.add(entry)

    entry.cycle_day = payload.cycle_day
    entry.is_period_day = payload.is_period_day
    entry.flow = payload.flow
    entry.mood = payload.mood
    entry.symptoms = json.dumps(payload.symptoms, ensure_ascii=False)
    entry.details = json.dumps(
        {
            field: getattr(payload, field)
            for field in DETAIL_FIELDS
            if getattr(payload, field) is not None
        },
        ensure_ascii=False,
    )
    entry.note = payload.note.strip() if payload.note else None

    await db.commit()
    await db.refresh(entry)
    return serialize_entry(entry)


@router.delete("/{day_key}", status_code=204)
async def delete_cycle_entry(day_key: str, db: DbSession, user: CurrentUser) -> None:
    result = await db.execute(
        select(CycleEntry).where(
            CycleEntry.user_id == user.id,
            CycleEntry.day_key == day_key,
        ),
    )
    entry = result.scalar_one_or_none()
    if entry is not None:
        await db.delete(entry)
        await db.commit()


async def _entries_for_period(
    db: DbSession,
    user_id: str,
    start_date: date,
    end_date: date,
) -> list[CycleEntry]:
    result = await db.execute(
        select(CycleEntry)
        .where(
            CycleEntry.user_id == user_id,
            CycleEntry.day_key >= start_date.isoformat(),
            CycleEntry.day_key <= end_date.isoformat(),
        )
        .order_by(CycleEntry.day_key.asc()),
    )
    return list(result.scalars().all())


def _build_cycle_report_pdf(
    user_name: str,
    start_date: date,
    end_date: date,
    entries: list[CycleEntry],
) -> bytes:
    font_name = _register_pdf_font()
    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        rightMargin=14 * mm,
        leftMargin=14 * mm,
        topMargin=14 * mm,
        bottomMargin=14 * mm,
    )
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "CycleTitle",
        parent=styles["Title"],
        fontName=font_name,
        fontSize=20,
        textColor=colors.HexColor("#C71585"),
        spaceAfter=8,
    )
    body_style = ParagraphStyle(
        "CycleBody",
        parent=styles["BodyText"],
        fontName=font_name,
        fontSize=9,
        leading=12,
    )

    period_days = [entry for entry in entries if entry.is_period_day]
    average_cycle = _average_cycle_length([entry.day_key for entry in period_days])
    symptom_counts: dict[str, int] = {}
    for entry in entries:
        for symptom in json.loads(entry.symptoms or "[]"):
            symptom_counts[symptom] = symptom_counts.get(symptom, 0) + 1

    story = [
        Paragraph("Отчет по циклу для врача", title_style),
        Paragraph(f"Пациент: {user_name}", body_style),
        Paragraph(
            f"Период: {start_date.strftime('%d.%m.%Y')} - {end_date.strftime('%d.%m.%Y')}",
            body_style,
        ),
        Paragraph(f"Всего отметок: {len(entries)}", body_style),
        Paragraph(f"Дней месячных: {len(period_days)}", body_style),
        Paragraph(f"Средняя длина цикла: {average_cycle or 'недостаточно данных'}", body_style),
        Spacer(1, 8),
    ]

    if symptom_counts:
        top_symptoms = sorted(symptom_counts.items(), key=lambda item: item[1], reverse=True)[:8]
        story.append(
            Paragraph(
                "Частые симптомы: "
                + ", ".join(f"{name} ({count})" for name, count in top_symptoms),
                body_style,
            ),
        )
        story.append(Spacer(1, 8))

    table_data = [[
        "Дата",
        "День",
        "Фаза",
        "Показатели",
        "Симптомы/заметка",
    ]]
    for entry in entries:
        details = _load_details(entry)
        metrics = _metrics_summary(details, entry.flow, entry.mood)
        symptoms = ", ".join(json.loads(entry.symptoms or "[]"))
        note_parts = [part for part in [symptoms, entry.note] if part]
        table_data.append(
            [
                _format_day_key(entry.day_key),
                str(entry.cycle_day),
                details.get("cycle_phase") or "-",
                metrics or "-",
                "; ".join(note_parts) or "-",
            ],
        )

    table = Table(
        table_data if len(table_data) > 1 else table_data + [["-", "-", "-", "-", "Нет данных"]],
        colWidths=[22 * mm, 13 * mm, 31 * mm, 47 * mm, 68 * mm],
        repeatRows=1,
    )
    table.setStyle(
        TableStyle(
            [
                ("FONTNAME", (0, 0), (-1, -1), font_name),
                ("FONTSIZE", (0, 0), (-1, -1), 7),
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#FF1493")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#F2C5DE")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#FFF7FB")]),
            ],
        ),
    )
    story.append(table)
    story.append(Spacer(1, 8))
    story.append(
        Paragraph(
            "Отчет сформирован приложением Qamqor. Он не заменяет консультацию врача.",
            body_style,
        ),
    )

    doc.build(story)
    return buffer.getvalue()


def _register_pdf_font() -> str:
    font_candidates = [
        Path("C:/Windows/Fonts/arial.ttf"),
        Path("C:/Windows/Fonts/calibri.ttf"),
    ]
    for font_path in font_candidates:
        if font_path.exists():
            font_name = font_path.stem
            if font_name not in pdfmetrics.getRegisteredFontNames():
                pdfmetrics.registerFont(TTFont(font_name, str(font_path)))
            return font_name
    return "Helvetica"


def _average_cycle_length(period_day_keys: list[str]) -> int | None:
    if not period_day_keys:
        return None
    starts = [period_day_keys[0]]
    previous_day = datetime.fromisoformat(period_day_keys[0]).date()
    for day_key in period_day_keys[1:]:
        current = datetime.fromisoformat(day_key).date()
        if (current - previous_day).days > 1:
            starts.append(day_key)
        previous_day = current
    lengths = []
    for index in range(1, len(starts)):
        current = datetime.fromisoformat(starts[index]).date()
        previous = datetime.fromisoformat(starts[index - 1]).date()
        length = (current - previous).days
        if 20 <= length <= 45:
            lengths.append(length)
    if not lengths:
        return None
    return round(sum(lengths) / len(lengths))


def _metrics_summary(details: dict, flow: str | None, mood: str | None) -> str:
    labels = {
        "weight_kg": "вес",
        "height_cm": "рост",
        "temperature_c": "темп.",
        "sleep_hours": "сон",
        "pain_level": "боль",
        "energy_level": "энергия",
        "stress_level": "стресс",
        "discharge": "выделения",
        "libido": "либидо",
        "appetite": "аппетит",
        "activity": "активность",
        "medication": "лекарства",
    }
    parts = []
    if flow:
        parts.append(f"интенсивность: {flow}")
    if mood:
        parts.append(f"настроение: {mood}")
    for key, label in labels.items():
        value = details.get(key)
        if value is not None and value != "":
            parts.append(f"{label}: {value}")
    return "; ".join(parts)


def _format_day_key(day_key: str) -> str:
    try:
        return datetime.fromisoformat(day_key).strftime("%d.%m.%Y")
    except ValueError:
        return day_key
