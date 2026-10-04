"""Embedding generation.

Serverless-safe by design: no model files are downloaded and no ONNX runtime is
required. Vectors come from Gemini (Groq serves no embedding endpoint) or, when no key is
configured or Gemini is unreachable, from a deterministic local hashing embedder — so a
Vercel cold start never waits on a multi-hundred-megabyte model.

The provider is resolved once per process and can only be downgraded, never switched
back mid-run: corpus and query vectors must always share one space and dimension, or
ChromaDB distances become meaningless.
"""

from __future__ import annotations

import hashlib
import logging
import re
import time

import httpx

from . import config

logger = logging.getLogger(__name__)

EMBEDDING_DIM = 256
_TOKEN_RE = re.compile(r"[a-z0-9]+")
_STOPWORDS = frozenset(
    """
    a an and are as at be by for from has have how in into is it its of on or that the
    this to was were will with
    adalah agar akan atau bagi bahwa dalam dan dari dengan dll dsb edited oleh pada
    namun sehingga serta tersebut tetapi tidak untuk yaitu yang
    """.split()
)

_GEMINI_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models"
_GEMINI_BATCH = 100
_RETRY_STATUS = frozenset({429, 500, 502, 503, 504})


class EmbeddingError(RuntimeError):
    """Raised when a query cannot be embedded with the provider the corpus was built with."""


def tokenize(text: str) -> list[str]:
    """Lowercase, strip punctuation, drop stopwords. Used for indexing and for queries."""
    tokens = _TOKEN_RE.findall(text.lower())
    return [token for token in tokens if token not in _STOPWORDS and len(token) > 1]


def embed_documents(texts: list[str]) -> list[list[float]]:
    """Embed a corpus. Runs first at store load, so it decides the provider."""
    if not texts:
        return []
    if _provider() == "gemini":
        vectors = _gemini_embed(texts)
        if vectors is not None:
            return vectors
        _downgrade("Gemini corpus embedding failed")
    return [local_embedding(text) for text in texts]


def embed_query(text: str) -> list[float]:
    """Embed a single query in the same space as the corpus."""
    if _provider() == "gemini":
        vectors = _gemini_embed([text])
        if vectors is None:
            raise EmbeddingError("query embedding unavailable")
        return vectors[0]
    return local_embedding(text)


def local_embedding(text: str, dim: int = EMBEDDING_DIM) -> list[float]:
    """Deterministic bag-of-words vector: hashed tokens, L2-normalized.

    Pure Python so it behaves identically in tests and in production and needs no numpy.
    """
    vector = [0.0] * dim
    tokens = tokenize(text)
    if not tokens:
        return vector
    for token in tokens:
        digest = hashlib.blake2b(token.encode("utf-8"), digest_size=8).digest()
        bucket = int.from_bytes(digest[:4], "big") % dim
        vector[bucket] += 1.0 if digest[4] % 2 == 0 else -1.0
    norm = sum(value * value for value in vector) ** 0.5
    if norm == 0.0:
        return vector
    return [value / norm for value in vector]


_provider_name: str | None = None


def _provider() -> str:
    """Sticky provider choice for this process."""
    global _provider_name
    if _provider_name is None:
        _provider_name = "gemini" if config.GEMINI_API_KEY else "local"
    return _provider_name


def _downgrade(reason: str) -> None:
    global _provider_name
    logger.warning("%s; using the local hashing embedder instead.", reason)
    _provider_name = "local"


def reset_provider() -> None:
    """Forget the resolved provider. Used by tests."""
    global _provider_name
    _provider_name = None


def _gemini_embed(texts: list[str], retries: int = 2) -> list[list[float]] | None:
    """Call Gemini batchEmbedContents. Returns None on failure so the caller can fall back."""
    model = config.GEMINI_EMBED_MODEL
    url = f"{_GEMINI_ENDPOINT}/{model}:batchEmbedContents"
    vectors: list[list[float]] = []
    try:
        with httpx.Client(timeout=20.0) as client:
            for start in range(0, len(texts), _GEMINI_BATCH):
                batch = texts[start : start + _GEMINI_BATCH]
                payload = {
                    "requests": [
                        {"model": f"models/{model}", "content": {"parts": [{"text": text}]}}
                        for text in batch
                    ]
                }
                response = _post_with_retry(client, url, payload, retries)
                if response is None:
                    return None
                # Gemini preserves request order and may omit `index` entirely.
                vectors.extend(item["values"] for item in response.json()["embeddings"])
    except (httpx.HTTPError, KeyError, ValueError, TypeError) as exc:
        logger.warning("Gemini embedding failed (%s).", type(exc).__name__)
        return None
    return vectors


def _post_with_retry(
    client: httpx.Client, url: str, payload: dict, retries: int
) -> httpx.Response | None:
    for attempt in range(retries + 1):
        try:
            response = client.post(
                url,
                # Key in a header: query strings leak into logs and browser history.
                headers={"x-goog-api-key": config.GEMINI_API_KEY},
                json=payload,
            )
            response.raise_for_status()
            return response
        except httpx.HTTPStatusError as exc:
            status = exc.response.status_code
            if status in _RETRY_STATUS and attempt < retries:
                time.sleep(1.5 * (attempt + 1))
                continue
            logger.warning("Gemini embedding rejected with HTTP %s.", status)
            return None
        except httpx.HTTPError as exc:
            logger.warning("Gemini embedding transport error (%s).", type(exc).__name__)
            return None
    return None
