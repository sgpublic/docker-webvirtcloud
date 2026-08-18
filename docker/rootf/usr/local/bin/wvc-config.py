#!/usr/bin/env python3
"""Generate webvirtcloud/settings.py overrides from environment / persisted state.

Reads the untouched settings.py.template (copied to settings.py by the
entrypoint) and replaces SECRET_KEY and DATABASES so that:
  * SECRET_KEY is stable across container restarts (persisted in a volume),
  * the database can be switched to PostgreSQL via POSTGRES_* env vars,
    otherwise a sqlite file inside the data volume is used as a fallback,
  * ALLOWED_HOSTS / DEBUG can be overridden via env vars.
"""
import os
import re
import secrets
from pathlib import Path

BASE = Path("/srv/webvirtcloud")
SETTINGS = BASE / "webvirtcloud" / "settings.py"
DATA_DIR = Path("/var/lib/webvirtcloud")
DATA_DIR.mkdir(parents=True, exist_ok=True)

text = SETTINGS.read_text()

# --- SECRET_KEY ---------------------------------------------------------
secret_file = DATA_DIR / "secret_key"
env_secret = os.environ.get("SECRET_KEY")
if env_secret:
    secret = env_secret
elif secret_file.exists():
    secret = secret_file.read_text().strip()
else:
    secret = secrets.token_urlsafe(50)
    secret_file.write_text(secret)

if 'SECRET_KEY = ""' in text:
    text = text.replace('SECRET_KEY = ""', "SECRET_KEY = {!r}".format(secret))

# --- DATABASES ----------------------------------------------------------
pg_host = os.environ.get("POSTGRES_HOST")
if pg_host:
    db_block = (
        "DATABASES = {\n"
        '    "default": {\n'
        '        "ENGINE": "django.db.backends.postgresql",\n'
        '        "NAME": ' + repr(os.environ.get("POSTGRES_DB", "webvirtcloud")) + ",\n"
        '        "USER": ' + repr(os.environ.get("POSTGRES_USER", "webvirtcloud")) + ",\n"
        '        "PASSWORD": ' + repr(os.environ.get("POSTGRES_PASSWORD", "")) + ",\n"
        '        "HOST": ' + repr(pg_host) + ",\n"
        '        "PORT": ' + repr(os.environ.get("POSTGRES_PORT", "5432")) + ",\n"
        "    }\n"
        "}\n"
    )
else:
    db_path = DATA_DIR / "db.sqlite3"
    db_block = (
        "DATABASES = {\n"
        '    "default": {\n'
        '        "ENGINE": "django.db.backends.sqlite3",\n'
        '        "NAME": ' + repr(str(db_path)) + ",\n"
        "    }\n"
        "}\n"
    )

text = re.sub(r"DATABASES = \{.*?\n\}", db_block, text, count=1, flags=re.DOTALL)

# --- ALLOWED_HOSTS ------------------------------------------------------
allowed = os.environ.get("ALLOWED_HOSTS")
if allowed:
    hosts = [h.strip() for h in allowed.split(",") if h.strip()]
    text = re.sub(
        r"ALLOWED_HOSTS = \[.*?\]",
        "ALLOWED_HOSTS = " + repr(hosts),
        text,
        count=1,
        flags=re.DOTALL,
    )

# --- DEBUG --------------------------------------------------------------
if os.environ.get("DEBUG", "").lower() in ("1", "true", "yes"):
    text = re.sub(r"DEBUG = .*", "DEBUG = True", text)

SETTINGS.write_text(text)
print("settings.py configured (db backend:", "postgresql" if pg_host else "sqlite3", ")")
