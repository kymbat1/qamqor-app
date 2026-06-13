import smtplib
from email.message import EmailMessage

from app.core.config import get_settings


class EmailDeliveryError(Exception):
    pass


async def send_verification_email(email: str, code: str) -> str | None:
    settings = get_settings()
    mode = settings.email_delivery_mode.lower().strip()

    if mode == "debug":
        print(f"[email-verification] {email}: {code}")
        return code

    if mode != "smtp":
        raise EmailDeliveryError("unsupported email delivery mode")

    if not settings.smtp_host:
        raise EmailDeliveryError("SMTP_HOST is required")

    message = EmailMessage()
    message["Subject"] = "Код подтверждения Qamqor"
    message["From"] = settings.smtp_from_email
    message["To"] = email
    message.set_content(
        "\n".join(
            [
                "Здравствуйте!",
                "",
                f"Ваш код подтверждения Qamqor: {code}",
                "Он действует несколько минут и может быть использован только один раз.",
                "",
                "Если вы не регистрировались в Qamqor, просто проигнорируйте это письмо.",
            ],
        ),
    )

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as server:
            if settings.smtp_use_tls:
                server.starttls()
            if settings.smtp_username and settings.smtp_password:
                server.login(settings.smtp_username, settings.smtp_password)
            server.send_message(message)
    except Exception as exc:
        raise EmailDeliveryError("failed to send verification email") from exc

    return None
