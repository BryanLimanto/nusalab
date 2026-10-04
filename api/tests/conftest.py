"""Shared pytest fixtures.

Tests always run offline. Provider credentials are neutralised after import so neither
embeddings nor the LLM can reach the network, whether the keys come from the process
environment or from a developer's local `.env`.

Note: the keys are cleared as module attributes rather than asserted on, so a failing
assertion can never echo a secret into CI logs.
"""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from fastapi.testclient import TestClient  # noqa: E402

from api.main import app  # noqa: E402
from api.services import chroma_store, config  # noqa: E402

config.GROQ_API_KEY = ""
config.GEMINI_API_KEY = ""


@pytest.fixture(scope="session")
def client() -> TestClient:
    chroma_store.reset_store()
    with TestClient(app) as test_client:
        yield test_client
