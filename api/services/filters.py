"""Filtering helpers shared by the search router and the RAG service."""

from __future__ import annotations

from typing import Any, Iterable

from ..models.schemas import FilterOptions, FilterSelection

MIN_YEAR = 2020
MAX_YEAR = 2026


def selection_parts(selection: FilterSelection | None) -> tuple[set[int], str | None, str | None]:
    """Normalize a chat filter payload into (years, program, concentration)."""
    if selection is None:
        return set(), None, None
    years = set(selection.years or [])
    if selection.year:
        years.add(selection.year)
    return years, selection.program, selection.concentration


def matches(
    record: dict[str, Any],
    years: Iterable[int] = (),
    program: str | None = None,
    concentration: str | None = None,
) -> bool:
    """True when a record satisfies every supplied filter. Empty filters always pass."""
    if years and int(record["year"]) not in years:
        return False
    if program and record["program"] != program:
        return False
    if concentration and record.get("concentration") != concentration:
        return False
    return True


def where_clause(
    years: Iterable[int] = (),
    program: str | None = None,
    concentration: str | None = None,
) -> dict[str, Any] | None:
    """ChromaDB metadata filter equivalent to `matches`."""
    clauses: list[dict[str, Any]] = []
    year_list = sorted({int(year) for year in years})
    if year_list:
        clauses.append({"year": {"$in": year_list}})
    if program:
        clauses.append({"program": program})
    if concentration:
        clauses.append({"concentration": concentration})
    if not clauses:
        return None
    return clauses[0] if len(clauses) == 1 else {"$and": clauses}


def filter_options(records: list[dict[str, Any]]) -> FilterOptions:
    """Distinct filter values for the sidebar, newest year first."""
    years = sorted({int(record["year"]) for record in records}, reverse=True)
    programs = sorted({record["program"] for record in records})
    concentrations = sorted({record.get("concentration", "") for record in records} - {""})
    topics = sorted({keyword for record in records for keyword in record.get("keywords", [])} - {""})
    tags = sorted({tag for record in records for tag in record.get("tags", [])} - {""})
    return FilterOptions(
        years=years,
        programs=programs,
        concentrations=concentrations,
        topics=topics,
        tags=tags,
    )


def in_year_range(record: dict[str, Any], year_from: int | None, year_to: int | None) -> bool:
    """True when the record's year falls inside the inclusive slider range."""
    year = int(record["year"])
    if year_from is not None and year < year_from:
        return False
    if year_to is not None and year > year_to:
        return False
    return True


def has_topic(record: dict[str, Any], topic: str | None) -> bool:
    """True when the topic keyword appears in keywords or tags (case-insensitive)."""
    if not topic:
        return True
    needle = topic.strip().lower()
    haystack_topics = [item.lower() for item in record.get("keywords", []) + record.get("tags", [])]
    return needle in haystack_topics


def haystack(record: dict[str, Any]) -> str:
    """Lowercased searchable text of a record."""
    parts = [
        record.get("title", ""),
        " ".join(record.get("authors", [])),
        " ".join(record.get("keywords", [])),
        " ".join(record.get("tags", [])),
        record.get("abstract", ""),
        record.get("program", ""),
        record.get("concentration", ""),
    ]
    return " ".join(parts).lower()


def keyword_hits(record: dict[str, Any], tokens: Iterable[str]) -> list[str]:
    """Query tokens literally present in the record. Used to boost lexical matches."""
    text = haystack(record)
    return [token for token in tokens if token in text]
