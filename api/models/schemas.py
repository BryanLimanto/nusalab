"""Pydantic request/response schemas for the UKP TA Repository API."""

from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


class ChatTurn(BaseModel):
    """One prior conversation turn, resent by the client on every proposal call."""

    role: Literal["user", "assistant"] = "user"
    content: str = Field(min_length=1, max_length=4000)


class ProposalSection(BaseModel):
    number: int
    title: str
    body: str
    citations: list[int] = Field(default_factory=list)


class ProposalRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    history: list[ChatTurn] = Field(default_factory=list, max_length=10)
    path: Literal["riset", "proyek"] | None = None
    concentration: str | None = Field(default=None, max_length=120)


class ProposalResponse(BaseModel):
    """`stage` is `clarify` while the track is still unknown, `draft` afterwards."""

    stage: Literal["clarify", "draft"]
    answer: str
    path: Literal["riset", "proyek"] | None = None
    idea: str = ""
    sections: list[ProposalSection] = Field(default_factory=list)
    references: list[str] = Field(default_factory=list)
    grounded_on: list[str] = Field(default_factory=list)
    notice: str | None = None


class Thesis(BaseModel):
    """A published Tugas Akhir record."""

    id: str
    title: str
    authors: list[str] = Field(default_factory=list)
    program: str
    concentration: str
    year: int
    keywords: list[str] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)
    abstract: str = ""
    url: str | None = None
    score: float | None = None


class SearchResponse(BaseModel):
    total: int
    limit: int
    offset: int
    items: list[Thesis]


class FilterOptions(BaseModel):
    years: list[int]
    programs: list[str]
    concentrations: list[str]
    topics: list[str] = Field(default_factory=list)
    tags: list[str] = Field(default_factory=list)


class FilterSelection(BaseModel):
    year: int | None = None
    years: list[int] = Field(default_factory=list)
    program: str | None = None
    concentration: str | None = None
    topic: str | None = None
    year_from: int | None = None
    year_to: int | None = None


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=4000)
    mode: Literal["similarity", "topics"] = "similarity"
    filters: FilterSelection | None = None


class ChatMatch(BaseModel):
    id: str
    title: str
    authors: list[str] = Field(default_factory=list)
    year: int
    program: str
    score: float
    why: str


class ChatTopic(BaseModel):
    label: str
    count: int
    thesis_ids: list[str]


class ChatResponse(BaseModel):
    answer: str
    mode: Literal["similarity", "topics"]
    matches: list[ChatMatch] = Field(default_factory=list)
    topics: list[ChatTopic] = Field(default_factory=list)
    notice: str | None = None
