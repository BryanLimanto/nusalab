"""FastAPI application — the Vercel serverless entrypoint for `/api/*`.

This module only wires things up: CORS, routers, and startup logging. Route handlers
live in `routers/`, logic in `services/`.

Import style note: Vercel imports this file as a top-level module, while tests and
`uvicorn api.main:app` import it as part of the `api` package. Both paths are supported.
"""

from __future__ import annotations

import logging
import sys
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any, AsyncIterator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

try:  # package import: `uvicorn api.main:app`, pytest
    from .routers import chat, meta, proposal, search
    from .services import config
except ImportError:  # top-level import: Vercel serverless function
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from routers import chat, meta, proposal, search  # type: ignore[no-redef]
    from services import config  # type: ignore[no-redef]

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("api")


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncIterator[None]:
    """Log the effective configuration only — no key is ever logged."""
    logger.info(
        "API ready | llm=%s | store=%s | origins=%s",
        config.llm_provider(),
        "hosted" if config.CHROMA_HOST else "in-memory",
        config.allowed_origins(),
    )
    yield


app = FastAPI(
    title="UKP TA Repository API",
    version="1.0.0",
    description="Pencarian repository Tugas Akhir dan chatbot RAG similarity UKP.",
    lifespan=lifespan,
)

_origins = config.allowed_origins()
app.add_middleware(
    CORSMiddleware,
    allow_origins=_origins,
    # Browsers reject credentialed requests combined with a wildcard origin.
    allow_credentials="*" not in _origins,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

app.include_router(meta.router)
app.include_router(search.router)
app.include_router(chat.router)
app.include_router(proposal.router)


@app.get("/", include_in_schema=False)
def root() -> dict[str, Any]:
    return {"service": "UKP TA Repository API", "docs": "/docs", "health": "/api/health"}
