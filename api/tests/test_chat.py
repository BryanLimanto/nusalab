"""POST /api/chat and the RAG services behind it."""

from __future__ import annotations

from fastapi.testclient import TestClient

from api.services import rag_service
from api.services import embeddings as EmbeddingsModule
from api.services.embeddings import EmbeddingError, local_embedding, tokenize
from api.services.filters import where_clause


def test_chat_similarity_returns_at_most_five_ordered_matches(client: TestClient) -> None:
    response = client.post(
        "/api/chat",
        json={"message": "aplikasi mobile untuk absensi siswa", "mode": "similarity"},
    )
    assert response.status_code == 200
    payload = response.json()
    assert payload["mode"] == "similarity"
    assert 0 < len(payload["matches"]) <= 5
    scores = [match["score"] for match in payload["matches"]]
    assert scores == sorted(scores, reverse=True)
    assert payload["answer"]
    assert payload["matches"][0]["why"]
    assert payload["topics"] == []


def test_chat_similarity_finds_the_most_similar_thesis(client: TestClient) -> None:
    payload = client.post(
        "/api/chat",
        json={"message": "aplikasi mobile absensi siswa dengan QR code", "mode": "similarity"},
    ).json()
    assert "absensi" in payload["matches"][0]["title"].lower()


def test_chat_similarity_respects_program_filter(client: TestClient) -> None:
    payload = client.post(
        "/api/chat",
        json={
            "message": "aplikasi mobile absensi",
            "mode": "similarity",
            "filters": {"program": "Sistem Informasi"},
        },
    ).json()
    assert payload["matches"]
    assert all(match["program"] == "Sistem Informasi" for match in payload["matches"])


def test_chat_similarity_respects_year_filter(client: TestClient) -> None:
    payload = client.post(
        "/api/chat",
        json={"message": "machine learning", "mode": "similarity", "filters": {"year": 2020}},
    ).json()
    assert payload["matches"]
    assert all(match["year"] == 2020 for match in payload["matches"])


def test_chat_topics_mode_groups_retrieved_theses(client: TestClient) -> None:
    payload = client.post(
        "/api/chat",
        json={"message": "topik apa yang paling sering diteliti?", "mode": "topics"},
    ).json()
    assert payload["mode"] == "topics"
    assert payload["topics"]
    assert payload["matches"] == []
    counts = [topic["count"] for topic in payload["topics"]]
    assert counts == sorted(counts, reverse=True)
    for topic in payload["topics"]:
        assert topic["label"]
        assert len(topic["thesis_ids"]) == topic["count"]


def test_chat_blank_message_returns_guidance(client: TestClient) -> None:
    payload = client.post("/api/chat", json={"message": "   "}).json()
    assert payload["answer"]
    assert payload["matches"] == []


def test_chat_rejects_empty_message_and_unknown_mode(client: TestClient) -> None:
    assert client.post("/api/chat", json={"message": ""}).status_code == 422
    assert client.post("/api/chat", json={"message": "hi", "mode": "lain"}).status_code == 422


def test_chat_falls_back_to_extractive_answer_without_llm(
    client: TestClient, monkeypatch
) -> None:
    monkeypatch.setattr(rag_service.llm_client, "complete", lambda *_: None)
    payload = client.post(
        "/api/chat",
        json={"message": "aplikasi mobile absensi siswa", "mode": "similarity"},
    ).json()
    assert payload["notice"]
    assert payload["matches"]
    assert "mirip" in payload["answer"].lower()


def test_chat_topics_falls_back_without_llm(client: TestClient, monkeypatch) -> None:
    monkeypatch.setattr(rag_service.llm_client, "complete", lambda *_: None)
    payload = client.post("/api/chat", json={"message": "tren riset", "mode": "topics"}).json()
    assert payload["notice"]
    assert payload["topics"]
    assert "Topik" in payload["answer"]


def test_chat_reports_embedding_failure_without_matches(client: TestClient, monkeypatch) -> None:
    def _raise(*_args, **_kwargs):
        raise EmbeddingError("query embedding unavailable")

    monkeypatch.setattr(rag_service, "retrieve", _raise)
    payload = client.post("/api/chat", json={"message": "aplikasi absensi"}).json()
    assert payload["notice"] == "embedding_unavailable"
    assert payload["matches"] == []
    assert payload["answer"]


def test_search_falls_back_to_literal_keywords_when_embedding_fails(
    client: TestClient, monkeypatch
) -> None:
    def _raise(*_args, **_kwargs):
        raise EmbeddingError("query embedding unavailable")

    monkeypatch.setattr(EmbeddingsModule, "embed_query", _raise)
    payload = client.get("/api/search", params={"q": "absensi"}).json()
    assert payload["items"]
    assert "absensi" in payload["items"][0]["title"].lower()


def test_local_embedding_is_deterministic_and_normalized() -> None:
    first = local_embedding("aplikasi absensi siswa")
    second = local_embedding("aplikasi absensi siswa")
    assert first == second
    assert len(first) == 256
    assert abs(sum(value * value for value in first) - 1.0) < 1e-6


def test_local_embedding_handles_text_without_meaningful_tokens() -> None:
    assert local_embedding("   ") == [0.0] * 256


def test_tokenize_drops_stopwords_and_punctuation() -> None:
    assert tokenize("Aplikasi, Mobile untuk Absensi!") == ["aplikasi", "mobile", "absensi"]


def test_where_clause_builds_chroma_metadata_filter() -> None:
    assert where_clause() is None
    assert where_clause(program="Informatika") == {"program": "Informatika"}
    assert where_clause([2024, 2023]) == {"year": {"$in": [2023, 2024]}}
    clause = where_clause([2024], "Informatika", "Cyber Security")
    assert clause is not None and clause["$and"]


def test_build_context_numbers_each_record() -> None:
    hits = rag_service.retrieve("aplikasi mobile absensi")
    context = rag_service.build_context([record for record, _ in hits])
    assert context.startswith("[1] Judul:")
    assert "    Kata kunci:" in context


def test_similarity_matches_never_exceed_the_limit() -> None:
    assert len(rag_service.similarity_matches("machine learning", limit=5)) <= 5
    assert len(rag_service.similarity_matches("machine learning", limit=2)) <= 2


def test_topic_clusters_count_members_per_topic() -> None:
    hits = rag_service.retrieve("data mining")
    topics = rag_service.topic_clusters(hits)
    assert topics
    for topic in topics:
        assert topic.count == len(topic.thesis_ids)
        assert len(set(topic.thesis_ids)) == topic.count
