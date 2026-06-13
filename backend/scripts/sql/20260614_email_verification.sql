ALTER TABLE IF EXISTS users
ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT TRUE NOT NULL;

CREATE TABLE IF NOT EXISTS email_verification_codes (
    id VARCHAR(36) PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(160) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role userrole NOT NULL,
    code_hash VARCHAR(255) NOT NULL,
    salt VARCHAR(64) NOT NULL,
    attempts INTEGER DEFAULT 0 NOT NULL,
    send_count INTEGER DEFAULT 1 NOT NULL,
    is_used BOOLEAN DEFAULT FALSE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    resend_available_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS ix_email_verification_codes_email
ON email_verification_codes (email);

CREATE INDEX IF NOT EXISTS ix_email_verification_email_used
ON email_verification_codes (email, is_used);

CREATE INDEX IF NOT EXISTS ix_email_verification_codes_expires_at
ON email_verification_codes (expires_at);
