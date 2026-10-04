"""Proposal generator endpoint: `POST /api/proposal`.

Two stages. `stage="clarify"` asks which track applies (riset or proyek); `stage="draft"`
returns the structured proposal. The client resends the conversation on every call, so no
state is kept between serverless invocations.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter

from ..models.schemas import ProposalRequest, ProposalResponse, ProposalSection
from ..services import proposal_service
from ..services.embeddings import EmbeddingError
from ..services.proposal_prompt import CLARIFY_QUESTION

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["proposal"])


@router.post(
    "/proposal",
    response_model=ProposalResponse,
    summary="Generate a TA proposal draft (RISET / PROYEK)",
)
def generate_proposal(payload: ProposalRequest) -> ProposalResponse:
    """First asks which track applies, then drafts the matching skeleton.

    Everything the model claims about previous work is grounded in the ChromaDB corpus, and
    a failed provider degrades to an explanation instead of a 500.
    """
    message = payload.message.strip()
    history = [turn.model_dump() for turn in payload.history]
    idea = proposal_service.research_idea(history, message)

    if not message:
        return ProposalResponse(
            stage="clarify",
            answer="Tuliskan judul atau ide Tugas Akhir Anda terlebih dahulu.",
            idea=idea,
        )

    track = proposal_service.detect_track(message, history, payload.path)
    if track is None:
        return ProposalResponse(stage="clarify", answer=CLARIFY_QUESTION, idea=idea)

    try:
        text = proposal_service.draft(message, track, history, payload.concentration)
    except EmbeddingError:
        logger.warning("Embedding unavailable; cannot ground the proposal draft.")
        text = None

    if not text:
        return ProposalResponse(
            stage="draft",
            answer=(
                "Draf belum dapat dibuat karena generator LLM sedang tidak tersedia. "
                "Coba lagi sebentar."
            ),
            path=track,
            idea=idea,
            notice="llm_unavailable",
        )

    parsed, references = proposal_service.parse_sections(text)
    return ProposalResponse(
        stage="draft",
        answer="Draf proposal jalur "
        + ("RISET" if track == proposal_service.TRACK_RISET else "PROYEK")
        + " berikut siap disunting.",
        path=track,
        idea=idea,
        sections=[
            ProposalSection(
                number=section.number,
                title=section.title,
                body=section.body,
                citations=section.citations,
            )
            for section in parsed
        ],
        references=references,
        grounded_on=_grounded_titles(idea),
    )


def _grounded_titles(idea: str) -> list[str]:
    """Titles of the published TAs injected as context, shown as a provenance note."""
    try:
        hits = proposal_service.retrieve(idea, None, n_results=5)
    except EmbeddingError:
        return []
    return [record["title"] for record, _ in hits]