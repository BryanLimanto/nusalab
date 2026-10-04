"""Health and filter metadata endpoints."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter

from ..models.schemas import FilterOptions
from ..services import config
from ..services.chroma_store import get_store
from ..services.filters import filter_options

router = APIRouter(prefix="/api", tags=["meta"])


@router.get("/health", summary="Liveness probe")
def health() -> dict[str, Any]:
    """Never raises: a failing store must not make the probe itself fail."""
    try:
        records = get_store().count()
    except Exception:  # noqa: BLE001 - probe must stay non-fatal
        records = -1
    return {
        "status": "ok",
        "records": records,
        "llm": config.llm_provider(),
        "store": "hosted" if config.CHROMA_HOST else "in-memory",
    }


@router.get("/filters", response_model=FilterOptions, summary="Distinct filter values")
def filters() -> FilterOptions:
    """Powers the sidebar checkboxes for year, program studi, and konsentrasi."""
    return filter_options(get_store().all_records())
