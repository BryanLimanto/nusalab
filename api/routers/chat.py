"""RAG chatbot endpoint."""

from __future__ import annotations

import logging

from fastapi import APIRouter

from ..models.schemas import ChatRequest, ChatResponse
from ..services import rag_service
from ..services.embeddings import EmbeddingError

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["chat"])


@router.post("/chat", response_model=ChatResponse, summary="Similarity check and topic mapping")
def chat(payload: ChatRequest) -> ChatResponse:
    """`similarity` returns the top 5 matching TAs; `topics` maps popular topics.

    Retrieval and filtering failures degrade to an empty but well-formed response, so a
    client never sees a 500 for a bad proposal text.
    """
    message = payload.message.strip()
    if not message:
        return ChatResponse(
            answer="Pesan masih kosong. Tuliskan judul atau ringkasan proposal Anda.",
            mode=payload.mode,
        )

    try:
        hits = rag_service.retrieve(message, payload.filters)
    except EmbeddingError:
        logger.warning("Embedding unavailable; answering without retrieval context.")
        return ChatResponse(
            answer=(
                "Pencarian vektor sedang tidak tersedia, jadi kemiripan belum bisa dihitung. "
                "Coba lagi sebentar atau gunakan fitur pencarian di halaman repository."
            ),
            mode=payload.mode,
            notice="embedding_unavailable",
        )

    if payload.mode == "topics":
        topics = rag_service.topic_clusters(hits)
        answer, notice = rag_service.answer_topics(message, hits, topics)
        return ChatResponse(answer=answer, mode="topics", topics=topics, notice=notice)

    matches = rag_service.similarity_matches(message, payload.filters)
    answer, notice = rag_service.answer_similarity(message, hits, matches)
    return ChatResponse(answer=answer, mode="similarity", matches=matches, notice=notice)
