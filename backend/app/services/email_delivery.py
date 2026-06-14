import smtplib
from email.message import EmailMessage
from html import escape

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
    message["Subject"] = "Ваш код подтверждения Qamqor"
    message["From"] = settings.smtp_from_email
    message["To"] = email
    message.set_content(_plain_text_body(code, settings.verification_code_ttl_minutes))
    message.add_alternative(
        _html_body(code, settings.verification_code_ttl_minutes),
        subtype="html",
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


def _plain_text_body(code: str, ttl_minutes: int) -> str:
    return "\n".join(
        [
            "Здравствуйте!",
            "",
            "Вы начали регистрацию в Qamqor.",
            f"Код подтверждения: {code}",
            f"Код действует {ttl_minutes} минут и может быть использован только один раз.",
            "",
            "Если вы не регистрировались в Qamqor, просто проигнорируйте это письмо.",
            "Команда Qamqor",
        ],
    )


def _html_body(code: str, ttl_minutes: int) -> str:
    safe_code = escape(code)
    return f"""\
<!doctype html>
<html lang="ru">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Код подтверждения Qamqor</title>
  </head>
  <body style="margin:0;background:#fff7fb;font-family:Arial,Helvetica,sans-serif;color:#241b2f;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#fff7fb;padding:28px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border:1px solid #ffe1f2;border-radius:24px;overflow:hidden;">
            <tr>
              <td style="background:#ff1493;padding:28px 28px 22px;">
                <div style="font-size:28px;line-height:1;font-weight:800;color:#ffffff;">Qamqor</div>
                <div style="margin-top:10px;font-size:15px;line-height:1.45;color:#ffeaf6;">Подтверждение регистрации</div>
              </td>
            </tr>
            <tr>
              <td style="padding:30px 28px 10px;">
                <h1 style="margin:0;font-size:24px;line-height:1.2;color:#241b2f;">Ваш код подтверждения</h1>
                <p style="margin:14px 0 0;font-size:15px;line-height:1.6;color:#6f6072;">
                  Введите этот одноразовый код в приложении, чтобы завершить регистрацию.
                </p>
              </td>
            </tr>
            <tr>
              <td align="center" style="padding:18px 28px 22px;">
                <div style="display:inline-block;letter-spacing:10px;font-size:36px;line-height:1;font-weight:800;color:#c71585;background:#ffeaf6;border:1px solid #ffb8da;border-radius:18px;padding:20px 18px 20px 28px;">
                  {safe_code}
                </div>
              </td>
            </tr>
            <tr>
              <td style="padding:0 28px 28px;">
                <div style="background:#fff7fb;border:1px solid #ffe1f2;border-radius:18px;padding:16px 18px;color:#6f6072;font-size:14px;line-height:1.55;">
                  Код действует <strong style="color:#241b2f;">{ttl_minutes} минут</strong> и может быть использован только один раз.
                  Если вы не регистрировались в Qamqor, просто проигнорируйте это письмо.
                </div>
                <p style="margin:22px 0 0;font-size:13px;line-height:1.5;color:#837385;">
                  С заботой,<br>
                  команда Qamqor
                </p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>
"""
