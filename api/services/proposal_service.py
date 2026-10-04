"""Proposal TA generation flow.

Serverless-safe: nothing is stored between requests. The client resends the short
conversation, so the service decides purely from the payload whether it must still ask
which track applies or can already draft the proposal.

Retrieval reuses the ChromaDB store, so the State-of-the-Art section is grounded in real
UKP theses instead of invented ones.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field

from . import llm_client
from .embeddings import EmbeddingError
from .proposal_prompt import build_system_prompt
from .rag_service import build_context, retrieve

logger = logging.getLogger(__name__)

TRACK_RISET = "riset"
TRACK_PROYEK = "proyek"
MAX_HISTORY = 6
DRAFT_MAX_TOKENS = llm_client.LONG_MAX_TOKENS

_SECTION_RE = re.compile(r"^\s{0,3}#{2,4}\s*(\d{1,2})\s*[.)\-:]\s*(.+?)\s*$")
_REFERENCE_RE = re.compile(r"^\s*(?:\[(\d{1,3})\]|(\d{1,2})[.)])\s+(\S.*?)\s*$")
_CITATION_RE = re.compile(r"\[(\d{1,3})\]")
_REFERENCES_TITLE_RE = re.compile(r"daftar\s+pustaka|referensi", re.IGNORECASE)

_RISET_HINTS = ("riset", "research", "penelitian", "ilmiah", "eksperimen", "hipotesis")
_PROYEK_HINTS = ("proyek", "project", "aplikasi", "implementasi", "sistem", "produk")


@dataclass(frozen=True)
class ProposalSection:
    number: int
    title: str
    body: str
    citations: list[int] = field(default_factory=list)


def detect_track(message: str, history: list[dict], explicit: str | None) -> str | None:
    """Return `riset`/`proyek` once the track is settled, otherwise None.

    Precedence: an explicit choice from the UI, then the student's latest answer. On the
    very first turn there is no history, so the track is always unresolved and the
    clarification question is asked — the idea itself often contains words like
    "aplikasi" or "penelitian" and must not be mistaken for a choice.
    """
    if explicit in {TRACK_RISET, TRACK_PROYEK}:
        return explicit
    if not history:
        return None

    latest = message.strip().lower()
    if not latest:
        return None
    has_riset = any(hint in latest for hint in _RISET_HINTS)
    has_proyek = any(hint in latest for hint in _PROYEK_HINTS)
    if has_riset and not has_proyek:
        return TRACK_RISET
    if has_proyek and not has_riset:
        return TRACK_PROYEK
    return None


def research_idea(history: list[dict], fallback: str) -> str:
    """First substantive user message: the idea the draft is built from."""
    for entry in history:
        content = (entry.get("content") or "").strip()
        if entry.get("role") == "user" and content:
            return content
    return fallback


def draft(
    message: str,
    track: str,
    history: list[dict],
    concentration: str | None = None,
) -> str | None:
    """Ask the LLM for the full draft. Returns None when no provider answered."""
    idea = research_idea(history, message)
    focus = f"\nKonsentrasi yang dituju: {concentration}." if concentration else ""
    user_prompt = (
        f"{_conversation_block(history)}"
        f"Ide/judul Tugas Akhir dari mahasiswa:\n\"\"\"\n{idea}\n\"\"\"{focus}\n\n"
        f"{_context_block(idea)}\n\n"
        f"Gunakan struktur draf jalur {track.upper()} secara lengkap dan berurutan. "
        "Setiap bagian ditulis sebagai draf siap disunting mahasiswa."
    )
    return llm_client.complete(build_system_prompt(track), user_prompt, DRAFT_MAX_TOKENS)


def parse_sections(text: str) -> tuple[list[ProposalSection], list[str]]:
    """Split the draft into `## N. Title` sections and pull out the reference list.

    Falls back to a single section when the model ignored the output contract, so the
    draft is still readable in the UI instead of being dropped.
    """
    sections: list[ProposalSection] = []
    references: list[str] = []
    number = 0
    title = ""
    buffer: list[str] = []
    in_references = False

    def flush() -> None:
        if number == 0:
            return
        body = "\n".join(buffer).strip()
        sections.append(
            ProposalSection(
                number=number,
                title=title,
                body=body,
                citations=sorted({int(c) for c in _CITATION_RE.findall(body)}),
            )
        )

    for line in text.splitlines():
        header = _SECTION_RE.match(line)
        if header:
            flush()
            number = int(header.group(1))
            title = header.group(2).strip()
            buffer = []
            # Only the reference list is harvested; numbered step lists elsewhere
            # ("1. Kumpulkan data…") must not be mistaken for citations.
            in_references = bool(_REFERENCES_TITLE_RE.search(title))
            continue
        reference = _REFERENCE_RE.match(line) if in_references else None
        if reference:
            references.append(reference.group(3))
        buffer.append(line)

    flush()

    if not sections:
        return [ProposalSection(number=1, title="Draf Proposal", body=text.strip())], references
    return sections, references


def _context_block(idea: str) -> str:
    """Compact context of similar published TAs so the SOTA section stays grounded."""
    try:
        hits = retrieve(idea, None, n_results=5)
    except EmbeddingError:
        logger.warning("Embedding unavailable; drafting proposal without TA context.")
        return "KONTEKS TA UKP: (tidak tersedia)"
    if not hits:
        return "KONTEKS TA UKP: (tidak ada TA yang mirip)"
    return (
        "KONTEKS TA UKP yang paling mirip. WAJIB dirujuk pada bagian Penelitian "
        "Terdahulu dengan menyebut judul dan tahun yang sebenarnya:\n"
        + build_context([record for record, _ in hits])
    )


def _conversation_block(history: list[dict]) -> str:
    if not history:
        return ""
    lines = [
        f"- {entry.get('role', 'user')}: {entry.get('content', '')}"
        for entry in history[-MAX_HISTORY:]
    ]
    return "Percakapan sebelumnya:\n" + "\n".join(lines) + "\n\n"