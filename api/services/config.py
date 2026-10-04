"""Environment configuration.

Every secret is read here, from the process environment or from a git-ignored `.env`
file. Nothing in this module ever returns a key to a caller.
"""

from __future__ import annotations

import logging
import os
from pathlib import Path

from dotenv import load_dotenv

API_DIR = Path(__file__).resolve().parents[1]
BASE_DIR = API_DIR.parent
DATA_FILE = API_DIR / "data" / "ta_metadata.json"

load_dotenv(BASE_DIR / ".env")
load_dotenv(API_DIR / ".env")


def _env(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


GROQ_API_KEY = _env("GROQ_API_KEY")
GROQ_MODEL = _env("GROQ_MODEL", "openai/gpt-oss-120b")
GEMINI_API_KEY = _env("GEMINI_API_KEY")
GEMINI_EMBED_MODEL = _env("GEMINI_EMBED_MODEL", "gemini-embedding-001")
GEMINI_MODEL = _env("GEMINI_MODEL", "gemini-2.0-flash")
CHROMA_HOST = _env("CHROMA_HOST")
CHROMA_PORT = int(_env("CHROMA_PORT", "8000") or 8000)
CHROMA_COLLECTION = _env("CHROMA_COLLECTION", "ukp_ta")
ALLOWED_ORIGINS = _env("ALLOWED_ORIGINS", "*")


def allowed_origins() -> list[str]:
    """Allowed CORS origins. `*` keeps the public single-origin deployment simple."""
    if not ALLOWED_ORIGINS or ALLOWED_ORIGINS == "*":
        return ["*"]
    return [origin.strip() for origin in ALLOWED_ORIGINS.split(",") if origin.strip()]


def has_llm() -> bool:
    """True when a chat provider is configured; otherwise the RAG flow stays extractive."""
    return bool(GROQ_API_KEY or GEMINI_API_KEY)


def llm_provider() -> str:
    if GROQ_API_KEY:
        return "groq"
    if GEMINI_API_KEY:
        return "gemini"
    return "none"


# Provider keys travel in headers, never in query strings, but keep httpx from logging
# request URLs at INFO as a second line of defence.
logging.getLogger("httpx").setLevel(logging.WARNING)
logging.getLogger("httpcore").setLevel(logging.WARNING)
