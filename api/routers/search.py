"""Repository search endpoint."""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Query

from ..models.schemas import SearchResponse, Thesis
from ..services.chroma_store import get_store
from ..services.embeddings import EmbeddingError, tokenize
from ..services.filters import (
    has_topic,
    in_year_range,
    keyword_hits,
    matches,
    where_clause,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["search"])

_LEXICAL_BOOST = 0.25


@router.get("/search", response_model=SearchResponse, summary="Search published TAs")
def search_theses(
    q: str = Query("", description="Kata kunci: judul, penulis, kata kunci, abstrak"),
    year: int | None = Query(None, description="Tahun tunggal (alternatif dari `years`)"),
    years: list[int] = Query(default_factory=list, description="Tahun yang dipilih"),
    year_from: int | None = Query(None, ge=1900, le=2100, description="Batas bawah slider tahun"),
    year_to: int | None = Query(None, ge=1900, le=2100, description="Batas atas slider tahun"),
    program: str | None = Query(None, description="Program studi"),
    concentration: str | None = Query(None, description="Konsentrasi"),
    topic: str | None = Query(None, description="Topik / kata kunci"),
    limit: int = Query(20, ge=1, le=50),
    offset: int = Query(0, ge=0),
) -> SearchResponse:
    """Keyword search when `q` is set, otherwise a filtered browse ordered newest first."""
    store = get_store()
    selected_years = set(years)
    if year:
        selected_years.add(year)
    keyword = q.strip()

    def keep(record: dict[str, Any]) -> bool:
        return (
            matches(record, years=selected_years, program=program, concentration=concentration)
            and in_year_range(record, year_from, year_to)
            and has_topic(record, topic)
        )

    if keyword:
        tokens = tokenize(keyword)
        try:
            hits = store.similarity(
                keyword,
                n_results=max(limit * 4, 50),
                where=where_clause(selected_years, program, concentration),
            )
        except EmbeddingError:
            # Vector provider is unreachable: degrade to literal keyword matching.
            logger.warning("Embedding unavailable; falling back to literal keyword search.")
            hits = [
                (record, 0.0)
                for record in store.all_records()
                if keep(record) and keyword_hits(record, tokens)
            ]
        ranked = [
            (record, min(1.0, score + _LEXICAL_BOOST * min(len(keyword_hits(record, tokens)), 3)))
            for record, score in hits
            if keep(record)
        ]
        ranked.sort(key=lambda item: item[1], reverse=True)
    else:
        ranked = [(record, None) for record in store.all_records() if keep(record)]

    page = ranked[offset : offset + limit]
    return SearchResponse(
        total=len(ranked),
        limit=limit,
        offset=offset,
        items=[Thesis(**record, score=score) for record, score in page],
    )