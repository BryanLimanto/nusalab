"""RAG pipeline: retrieve, build context, inject into the prompt, answer.

Retrieval always over-fetches (CANDIDATE_K) and `similarity_matches` reduces to the top
five, so the five results are the best of a wider candidate set rather than the first five
ChromaDB happens to return.
"""

from __future__ import annotations

from typing import Any

from ..models.schemas import ChatMatch, ChatTopic, FilterSelection
from . import llm_client
from .chroma_store import get_store
from .embeddings import tokenize
from .filters import haystack, matches, selection_parts, where_clause

TOP_K = 5
CANDIDATE_K = 15
ABSTRACT_EXCERPT = 420

SYSTEM_PROMPT = (
    "Anda adalah asisten repository Tugas Akhir Universitas Kristen Petra (UKP). "
    "Jawab HANYA berdasarkan konteks TA yang disertakan pada pertanyaan. "
    "Jangan mengarang judul, penulis, tahun, atau angka hasil yang tidak ada di konteks. "
    "Jika konteks tidak memuat jawaban, katakan dengan jujur bahwa data tidak mencukupi. "
    "Gunakan bahasa Indonesia yang ringkas dan akademis."
)


def retrieve(
    message: str,
    selection: FilterSelection | None = None,
    n_results: int = CANDIDATE_K,
) -> list[tuple[dict[str, Any], float]]:
    """Vector retrieval narrowed by year/program/konsentrasi filters."""
    years, program, concentration = selection_parts(selection)
    hits = get_store().similarity(
        message,
        n_results=n_results,
        where=where_clause(years, program, concentration),
    )
    # Post-filter as well: a hosted collection may hold metadata the local dataset lacks.
    return [
        (record, score)
        for record, score in hits
        if matches(record, years=years, program=program, concentration=concentration)
    ]


def similarity_matches(
    message: str,
    selection: FilterSelection | None = None,
    limit: int = TOP_K,
) -> list[ChatMatch]:
    """Top `limit` matching TAs with the reason each one matched."""
    tokens = tokenize(message)
    hits = retrieve(message, selection, n_results=max(CANDIDATE_K, limit * 3))
    results: list[ChatMatch] = []
    for record, score in hits:
        results.append(
            ChatMatch(
                id=record["id"],
                title=record["title"],
                authors=record.get("authors", []),
                year=int(record["year"]),
                program=record["program"],
                score=round(score, 4),
                why=_reason(message, record, tokens, score),
            )
        )
        if len(results) >= limit:
            break
    return results


def topic_clusters(
    hits: list[tuple[dict[str, Any], float]],
    limit: int = 6,
) -> list[ChatTopic]:
    """Group retrieved TAs into popular topics by their keywords."""
    buckets: dict[str, list[str]] = {}
    labels: dict[str, str] = {}
    for record, _score in hits:
        terms = record.get("keywords") or [record.get("concentration", "")]
        for term in terms:
            key = term.strip().lower()
            if not key:
                continue
            buckets.setdefault(key, []).append(record["id"])
            labels.setdefault(key, term.strip())
    ordered = sorted(buckets.items(), key=lambda item: (-len(item[1]), item[0]))
    return [
        ChatTopic(label=labels[key], count=len(thesis_ids), thesis_ids=thesis_ids)
        for key, thesis_ids in ordered[:limit]
    ]


def build_context(records: list[dict[str, Any]]) -> str:
    """Numbered context block injected into the prompt."""
    blocks: list[str] = []
    for index, record in enumerate(records, start=1):
        abstract = record.get("abstract", "")
        if len(abstract) > ABSTRACT_EXCERPT:
            abstract = abstract[:ABSTRACT_EXCERPT].rstrip() + "…"
        blocks.append(
            f"[{index}] Judul: {record['title']}\n"
            f"    Penulis: {', '.join(record.get('authors', [])) or '-'}\n"
            f"    Program/Konsentrasi: {record['program']} - {record.get('concentration', '-')} ({record['year']})\n"
            f"    Kata kunci: {', '.join(record.get('keywords', [])) or '-'}\n"
            f"    Abstrak: {abstract or '-'}"
        )
    return "\n\n".join(blocks) if blocks else "(tidak ada TA yang cocok)"


def answer_similarity(
    message: str,
    hits: list[tuple[dict[str, Any], float]],
    matches_out: list[ChatMatch],
) -> tuple[str, str | None]:
    """Narrative similarity assessment, or an extractive summary when no LLM is reachable."""
    context = build_context([record for record, _ in hits[:TOP_K]])
    user_prompt = (
        "Proposal atau ide penelitian dari mahasiswa:\n"
        f'"""\n{message}\n"""\n\n'
        "Konteks Tugas Akhir yang paling mirip:\n"
        f"{context}\n\n"
        "Tugasmu: dalam maksimal 4 kalimat, jelaskan seberapa mirip proposal ini dengan "
        "TA pada konteks, sebutkan TA yang paling berpotensi tumpang tindih topik, lalu beri "
        "satu saran agar topik proposal lebih berbeda."
    )
    text = llm_client.complete(SYSTEM_PROMPT, user_prompt)
    if text:
        return text, None
    return extractive_similarity(matches_out), (
        "Generator LLM tidak tersedia; jawaban disusun dari data repository."
    )


def answer_topics(
    message: str,
    hits: list[tuple[dict[str, Any], float]],
    topics_out: list[ChatTopic],
) -> tuple[str, str | None]:
    """Topic mapping and trend analysis over the retrieved TAs."""
    context = build_context([record for record, _ in hits[:CANDIDATE_K]])
    user_prompt = (
        "Konteks Tugas Akhir yang retrieved:\n"
        f"{context}\n\n"
        "Permintaan pengguna:\n"
        f'"""\n{message}\n"""\n\n'
        "Tugasmu: petakan topik yang populer pada konteks tersebut. Sebutkan topik utama, "
        "jumlah TA per topik, dan tren yang terlihat (naik, turun, atau stabil). "
        "Maksimal 5 kalimat."
    )
    text = llm_client.complete(SYSTEM_PROMPT, user_prompt)
    if text:
        return text, None
    return extractive_topics(topics_out), (
        "Generator LLM tidak tersedia; pemetaan topik disusun dari data repository."
    )


def extractive_similarity(matches_out: list[ChatMatch]) -> str:
    if not matches_out:
        return "Tidak ditemukan Tugas Akhir yang mirip pada repository ini."
    lines = [f"Ditemukan {len(matches_out)} TA yang paling mirip dengan proposal Anda:"]
    for match in matches_out:
        lines.append(
            f"- {match.title} ({match.year}, {match.program}) "
            f"— kemiripan {match.score:.2f}. {match.why}"
        )
    lines.append(
        "Ringkasan naratif membutuhkan LLM. Tinjau judul dan kata kunci di atas, lalu "
        "tulis bab proposal yang menegaskan perbedaan topik Anda."
    )
    return "\n".join(lines)


def extractive_topics(topics_out: list[ChatTopic]) -> str:
    if not topics_out:
        return "Belum ada pola topik yang dapat dipetakan dari data repository."
    lines = ["Topik yang paling banyak approches pada hasil retrieval:"]
    for topic in topics_out:
        lines.append(f"- {topic.label}: {topic.count} TA")
    lines.append("Analisis tren lanjutan membutuhkan LLM.")
    return "\n".join(lines)


def _reason(message: str, record: dict[str, Any], tokens: list[str], score: float) -> str:
    """Short, user-facing explanation of why a TA matched."""
    lowered = message.lower()
    terms: list[str] = []
    for keyword in record.get("keywords", []):
        if keyword.lower() in lowered and keyword not in terms:
            terms.append(keyword)
    text = haystack(record)
    for token in sorted(set(tokens)):
        if token in text and token not in {term.lower() for term in terms}:
            terms.append(token)
    if terms:
        return "Irisan kata kunci: " + ", ".join(terms[:4])
    return f"Kemiripan vektor {score:.2f} pada bidang yang sama."
