"""Chat completion client.

Provider order: Groq (`openai/gpt-oss-120b` by default), then Gemini. When no key is
configured — or when every provider call fails — `complete` returns None and the RAG
service falls back to an extractive answer built from the retrieved records.

Keys are read from the environment here and are never logged or returned.
"""

from __future__ import annotations

import logging

import httpx

from . import config

logger = logging.getLogger(__name__)

_GROQ_ENDPOINT = "https://api.groq.com/openai/v1/chat/completions"
_GEMINI_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models"
MAX_TOKENS = 1200
LONG_MAX_TOKENS = 6000


def complete(system_prompt: str, user_prompt: str, max_tokens: int = MAX_TOKENS) -> str | None:
    """Return generated text, or None when no provider could answer.

    `max_tokens` must be raised for long structured output: a full proposal draft needs
    several thousand tokens, and truncation would silently drop later sections.
    """
    if config.GROQ_API_KEY:
        text = _groq(system_prompt, user_prompt, max_tokens)
        if text:
            return text
        logger.warning("Groq completion failed; trying the next provider.")
    if config.GEMINI_API_KEY:
        text = _gemini(system_prompt, user_prompt, max_tokens)
        if text:
            return text
        logger.warning("Gemini completion failed; falling back to an extractive answer.")
    return None


def _groq(system_prompt: str, user_prompt: str, max_tokens: int) -> str | None:
    try:
        with httpx.Client(timeout=120.0) as client:
            response = client.post(
                _GROQ_ENDPOINT,
                headers={"Authorization": f"Bearer {config.GROQ_API_KEY}"},
                json={
                    "model": config.GROQ_MODEL,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt},
                    ],
                    "temperature": 0.2,
                    "max_tokens": max_tokens,
                },
            )
            response.raise_for_status()
            message = response.json()["choices"][0]["message"]
    except (httpx.HTTPError, KeyError, IndexError, ValueError, TypeError) as exc:
        logger.warning("Groq request failed (%s).", type(exc).__name__)
        return None
    # Reasoning models such as gpt-oss may expose only `reasoning` when the turn is cut short.
    return _first_text(message.get("content"), message.get("reasoning"))


def _gemini(system_prompt: str, user_prompt: str, max_tokens: int) -> str | None:
    model = config.GEMINI_MODEL
    try:
        with httpx.Client(timeout=120.0) as client:
            response = client.post(
                f"{_GEMINI_ENDPOINT}/{model}:generateContent",
                # Key in a header: query strings end up in logs and browser history.
                headers={"x-goog-api-key": config.GEMINI_API_KEY},
                json={
                    "systemInstruction": {"parts": [{"text": system_prompt}]},
                    "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
                    "generationConfig": {"temperature": 0.2, "maxOutputTokens": max_tokens},
                },
            )
            response.raise_for_status()
            candidates = response.json()["candidates"]
            parts = candidates[0]["content"]["parts"]
    except (httpx.HTTPError, KeyError, IndexError, ValueError, TypeError) as exc:
        logger.warning("Gemini request failed (%s).", type(exc).__name__)
        return None
    return _first_text(*[part.get("text", "") for part in parts])


def _first_text(*candidates: str | None) -> str | None:
    for candidate in candidates:
        if candidate and candidate.strip():
            return candidate.strip()
    return None
