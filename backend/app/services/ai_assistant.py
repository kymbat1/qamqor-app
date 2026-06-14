import asyncio
import json
import re
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import date, datetime, timedelta

from sqlalchemy import select

from app.core.config import get_settings
from app.models import CycleEntry, DoctorProfile, User


@dataclass
class CycleSnapshot:
    today: date
    latest_entry: CycleEntry | None
    recent_entries: list[CycleEntry]
    phase: str
    cycle_day: int | None
    period_now: bool
    pain_level: int | None
    energy_level: int | None
    stress_level: int | None
    symptoms: list[str]
    details: dict


@dataclass
class AiAssistantResult:
    answer: str
    source: str
    used_cycle_context: bool
    needs_doctor: bool


DOMAIN_KEYWORDS = {
    "цикл",
    "месяч",
    "менстру",
    "овуля",
    "пмс",
    "беремен",
    "гинек",
    "гормон",
    "боль",
    "живот",
    "выдел",
    "спорт",
    "трен",
    "трениров",
    "упражнен",
    "зал",
    "фитнес",
    "кардио",
    "cardio",
    "силов",
    "сон",
    "стресс",
    "энерг",
    "аппетит",
    "вес",
    "температур",
    "контрац",
    "врач",
    "прием",
    "запис",
}

RED_FLAG_KEYWORDS = {
    "обморок",
    "потеряла сознание",
    "сильное кровотечение",
    "очень обиль",
    "кровь сгуст",
    "беременна",
    "положительный тест",
    "резкая боль",
    "невыносимая боль",
    "температура",
    "лихорад",
    "рвота",
    "гной",
    "запах",
    "после секса",
    "инфекц",
}


async def build_cycle_snapshot(db, user: User) -> CycleSnapshot:
    today = date.today()
    since = today - timedelta(days=120)
    result = await db.execute(
        select(CycleEntry)
        .where(
            CycleEntry.user_id == user.id,
            CycleEntry.day_key >= since.isoformat(),
            CycleEntry.day_key <= today.isoformat(),
        )
        .order_by(CycleEntry.day_key.desc()),
    )
    entries = list(result.scalars().all())
    latest = entries[0] if entries else None
    details = _load_details(latest) if latest else {}
    symptoms = _load_symptoms(latest) if latest else []
    cycle_day = latest.cycle_day if latest else None
    phase = _phase_for(latest, details)
    return CycleSnapshot(
        today=today,
        latest_entry=latest,
        recent_entries=entries[:12],
        phase=phase,
        cycle_day=cycle_day,
        period_now=bool(latest and latest.is_period_day),
        pain_level=_as_int(details.get("pain_level")),
        energy_level=_as_int(details.get("energy_level")),
        stress_level=_as_int(details.get("stress_level")),
        symptoms=symptoms,
        details=details,
    )


async def answer_with_cycle_context(
    *,
    question: str,
    snapshot: CycleSnapshot,
    doctors: list[DoctorProfile],
) -> AiAssistantResult:
    normalized = question.lower().strip()
    if not _is_domain_question(normalized):
        return AiAssistantResult(
            answer=(
                "Я могу отвечать только на вопросы, связанные с женским здоровьем, "
                "циклом, самонаблюдением, симптомами, тренировками с учетом цикла "
                "и записью к специалистам в Qamqor."
            ),
            source="rules",
            used_cycle_context=bool(snapshot.latest_entry),
            needs_doctor=False,
        )

    if _has_red_flags(normalized, snapshot):
        return AiAssistantResult(
            answer=_doctor_first_answer(snapshot, doctors),
            source="rules",
            used_cycle_context=bool(snapshot.latest_entry),
            needs_doctor=True,
        )

    settings = get_settings()
    if settings.ai_provider.lower() == "local":
        prompt = _system_prompt(snapshot, doctors)
        try:
            answer = await _ask_local_model(prompt, question)
            if answer:
                return AiAssistantResult(
                    answer=_with_safety_footer(answer),
                    source="local_llm",
                    used_cycle_context=bool(snapshot.latest_entry),
                    needs_doctor=False,
                )
        except Exception:
            if not settings.ai_allow_fallback:
                raise

    return AiAssistantResult(
        answer=_fallback_answer(question, snapshot, doctors),
        source="rules",
        used_cycle_context=bool(snapshot.latest_entry),
        needs_doctor=False,
    )


def _is_domain_question(question: str) -> bool:
    return any(keyword in question for keyword in DOMAIN_KEYWORDS)


def _has_red_flags(question: str, snapshot: CycleSnapshot) -> bool:
    if any(keyword in question for keyword in RED_FLAG_KEYWORDS):
        return True
    if snapshot.pain_level is not None and snapshot.pain_level >= 8:
        return True
    temperature = snapshot.details.get("temperature_c")
    try:
        if temperature is not None and float(temperature) >= 38:
            return True
    except (TypeError, ValueError):
        pass
    return False


def _doctor_first_answer(snapshot: CycleSnapshot, doctors: list[DoctorProfile]) -> str:
    suggestions = _doctor_lines(doctors)
    context = _cycle_context_text(snapshot)
    return (
        "По описанию есть признаки, с которыми лучше не ограничиваться советами от ИИ. "
        "Пожалуйста, обратитесь к врачу, а при резкой боли, обмороке, температуре, "
        "очень обильном кровотечении или подозрении на беременность — за срочной помощью.\n\n"
        f"Что я вижу по календарю: {context}\n\n"
        f"В приложении можно начать с этих специалистов:\n{suggestions}"
    )


def _fallback_answer(
    question: str,
    snapshot: CycleSnapshot,
    doctors: list[DoctorProfile],
) -> str:
    lower = question.lower()
    if any(word in lower for word in ["кардио", "силов", "трен", "спорт"]):
        return _exercise_answer(snapshot)
    if any(word in lower for word in ["болит", "боль", "спазм", "живот"]):
        return (
            f"С учетом календаря: {snapshot.phase}, день цикла: "
            f"{snapshot.cycle_day or 'неизвестно'}. Если боль похожа на обычные "
            "спазмы во время месячных, можно попробовать отдых, воду, тепло на низ "
            "живота и легкую активность без перегруза. Если боль сильная, необычная, "
            "нарастает или есть температура/обильное кровотечение, лучше обратиться "
            f"к врачу.\n\n{_doctor_hint(doctors)}"
        )
    return (
        f"Я учла данные календаря: {snapshot.phase}, день цикла: "
        f"{snapshot.cycle_day or 'неизвестно'}. Могу помочь с самонаблюдением, "
        "подготовкой вопросов врачу и мягкими wellness-рекомендациями, но не ставлю "
        "диагнозы и не назначаю лечение. Опишите симптом, длительность и силу по шкале 0-10."
    )


def _exercise_answer(snapshot: CycleSnapshot) -> str:
    phase = snapshot.phase.lower()
    pain = snapshot.pain_level or 0
    energy = snapshot.energy_level
    if snapshot.period_now or "менстру" in phase:
        if pain >= 5:
            return (
                "Сегодня лучше выбрать мягкую нагрузку: прогулку, растяжку, йогу, "
                "дыхание или легкое кардио 15-25 минут. Силовые и интенсивные интервалы "
                "лучше отложить, особенно если боль заметная. Если боль необычная или "
                "очень сильная — лучше обсудить это с врачом."
            )
        return (
            "Если самочувствие нормальное, можно легкое кардио или облегченные силовые "
            "без рекордов. Ориентируйся на ощущения: при усилении боли снизь интенсивность."
        )
    if "фоллик" in phase:
        return (
            "В фолликулярной фазе часто легче переносится активность. Если энергия нормальная, "
            "можно силовую тренировку или умеренное кардио. Начни с разминки и не игнорируй "
            "боль/головокружение."
        )
    if "овуля" in phase:
        return (
            "В овуляторной фазе можно кардио или силовые, но аккуратно с максимальными весами, "
            "если есть тянущие ощущения внизу живота. Хороший вариант — умеренная силовая "
            "и контроль техники."
        )
    if "лютеин" in phase:
        return (
            "В лютеиновой фазе часто падает энергия и выше чувствительность к стрессу. "
            f"Если энергия {energy or 'не отмечена'}, выбирай умеренное кардио, пилатес "
            "или силовую с меньшим объемом. При ПМС лучше снизить интенсивность."
        )
    return (
        "Я не вижу точной фазы цикла, поэтому выбери нагрузку по самочувствию: если есть боль "
        "или усталость — легкое кардио/растяжка; если энергии достаточно — умеренные силовые. "
        "Добавь отметки в календарь, и советы станут точнее."
    )


async def _ask_local_model(system_prompt: str, question: str) -> str:
    settings = get_settings()
    base_url = settings.ai_local_base_url.rstrip("/")
    if settings.ai_local_format.lower() == "openai":
        url = f"{base_url}/v1/chat/completions"
        payload = {
            "model": settings.ai_local_model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": question},
            ],
            "temperature": 0.3,
        }
        data = await asyncio.to_thread(
            _post_json,
            url,
            payload,
            settings.ai_timeout_seconds,
        )
        return (
            data.get("choices", [{}])[0]
            .get("message", {})
            .get("content", "")
            .strip()
        )

    url = f"{base_url}/api/chat"
    payload = {
        "model": settings.ai_local_model,
        "stream": False,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": question},
        ],
        "options": {"temperature": 0.3},
    }
    data = await asyncio.to_thread(_post_json, url, payload, settings.ai_timeout_seconds)
    return str(data.get("message", {}).get("content", "")).strip()


def _post_json(url: str, payload: dict, timeout: int) -> dict:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except (
        urllib.error.HTTPError,
        urllib.error.URLError,
        TimeoutError,
        json.JSONDecodeError,
    ) as exc:
        raise RuntimeError("local-ai-unavailable") from exc


def _system_prompt(snapshot: CycleSnapshot, doctors: list[DoctorProfile]) -> str:
    return f"""
Ты wellness-ассистент Qamqor. Отвечай только на русском.

Темы: женское здоровье, цикл, симптомы, самонаблюдение, тренировки с учетом цикла,
подготовка к приему врача, запись к специалистам.

Запрещено: ставить диагноз, назначать лекарства/гормоны/дозировки, обещать точный прогноз.
При красных флагах советуй обратиться к врачу или срочно за медицинской помощью.

Контекст цикла пользовательницы:
{_cycle_context_text(snapshot)}

Доступные специалисты:
{_doctor_lines(doctors)}

Формат ответа:
- 1 короткий вывод с учетом фазы/симптомов.
- 2-4 практичных шага.
- Если вопрос медицински серьезный, мягко направь к врачу и назови подходящих специалистов.
""".strip()


def _cycle_context_text(snapshot: CycleSnapshot) -> str:
    if snapshot.latest_entry is None:
        return "пока нет отметок цикла в календаре"
    parts = [
        f"последняя отметка: {snapshot.latest_entry.day_key}",
        f"фаза: {snapshot.phase}",
        f"день цикла: {snapshot.cycle_day or 'неизвестно'}",
        f"месячные сейчас: {'да' if snapshot.period_now else 'нет'}",
    ]
    if snapshot.pain_level is not None:
        parts.append(f"боль: {snapshot.pain_level}/10")
    if snapshot.energy_level is not None:
        parts.append(f"энергия: {snapshot.energy_level}/5")
    if snapshot.stress_level is not None:
        parts.append(f"стресс: {snapshot.stress_level}/5")
    if snapshot.symptoms:
        parts.append("симптомы: " + ", ".join(snapshot.symptoms))
    if snapshot.latest_entry.note:
        parts.append(f"заметка: {snapshot.latest_entry.note}")
    return "; ".join(parts)


def _doctor_lines(doctors: list[DoctorProfile]) -> str:
    if not doctors:
        return "- В приложении пока нет доступных врачей."
    return "\n".join(
        f"- {doctor.name}, {doctor.specialty or 'специалист'}, "
        f"{doctor.city or 'город не указан'}, {doctor.hospital or 'клиника не указана'}, "
        f"рейтинг {doctor.rating:.1f}, прием {doctor.consultation_fee:.0f} ₸"
        for doctor in doctors[:5]
    )


def _doctor_hint(doctors: list[DoctorProfile]) -> str:
    return "Подходящие специалисты:\n" + _doctor_lines(doctors)


def _with_safety_footer(answer: str) -> str:
    if "врач" in answer.lower() or "специалист" in answer.lower():
        return answer
    return answer + "\n\nЕсли симптом сильный, необычный или повторяется, лучше обратиться к врачу."


def _load_details(entry: CycleEntry | None) -> dict:
    if entry is None:
        return {}
    try:
        details = json.loads(entry.details or "{}")
        return details if isinstance(details, dict) else {}
    except json.JSONDecodeError:
        return {}


def _load_symptoms(entry: CycleEntry | None) -> list[str]:
    if entry is None:
        return []
    try:
        symptoms = json.loads(entry.symptoms or "[]")
        return [str(item) for item in symptoms] if isinstance(symptoms, list) else []
    except json.JSONDecodeError:
        return []


def _phase_for(entry: CycleEntry | None, details: dict) -> str:
    if entry is None:
        return "неизвестно"
    explicit = str(details.get("cycle_phase") or "").strip()
    if explicit:
        return explicit
    if entry.is_period_day:
        return "менструальная фаза"
    day = entry.cycle_day
    if day <= 13:
        return "фолликулярная фаза"
    if 14 <= day <= 16:
        return "овуляторная фаза"
    return "лютеиновая фаза"


def _as_int(value) -> int | None:
    try:
        return int(value) if value is not None else None
    except (TypeError, ValueError):
        return None
