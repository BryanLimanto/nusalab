"""POST /api/proposal and the proposal service behind it."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from api.services import proposal_service
from api.services.proposal_prompt import (
    CLARIFY_QUESTION,
    build_system_prompt,
)

CANNED_RISET_DRAFT = """## 1. Judul
Deteksi Kecurangan Ujian Online dengan Eye Tracking dan Random Forest

## 2. Latar Belakang Masalah
Ujian daring makin rentan kecurangan [1]. Penelitian terdahulu memakai sidik jari [2].

## 3. Rumusan Masalah
Bagaimana pola eye tracking memprediksi kecurangan?

## 9. Metodologi Penelitian
1. Kumpulkan data rekaman mata
2. Latih classifier random forest

## 11. Daftar Pustaka
[1] Smith, J. Eye tracking in exams. Journal of EdTech, 2023.
[2] Doe, A. Fingerprint authentication review. ACM Computing Surveys, 2022.
"""


@pytest.fixture(autouse=True)
def _stub_llm(monkeypatch: pytest.MonkeyPatch) -> list[str]:
    """Stub the provider so the suite never calls Groq or Gemini."""
    calls: list[str] = []

    def _complete(system_prompt: str, user_prompt: str, max_tokens: int = 0) -> str | None:
        calls.append(system_prompt)
        return CANNED_RISET_DRAFT

    monkeypatch.setattr(proposal_service.llm_client, "complete", _complete)
    return calls


def test_first_turn_always_asks_which_track(client: TestClient) -> None:
    # Even though the idea contains "aplikasi", the track must not be inferred.
    response = client.post(
        "/api/proposal",
        json={"message": "aplikasi mobile untuk absensi siswa"},
    ).json()

    assert response["stage"] == "clarify"
    assert response["answer"].startswith("Apakah Tugas Akhir ini mengambil jalur RISET atau PROYEK?")
    assert response["sections"] == []
    assert response["path"] is None
    assert response["idea"] == "aplikasi mobile untuk absensi siswa"


def test_clarify_question_explains_both_tracks(client: TestClient) -> None:
    response = client.post("/api/proposal", json={"message": "deteksi kecurangan"}).json()
    assert "RISET" in response["answer"] and "PROYEK" in response["answer"]
    assert CLARIFY_QUESTION.splitlines()[0] in response["answer"]


def test_explicit_path_skips_the_clarification(client: TestClient) -> None:
    response = client.post(
        "/api/proposal",
        json={"message": "aplikasi mobile absensi siswa", "path": "proyek"},
    ).json()

    assert response["stage"] == "draft"
    assert response["path"] == "proyek"


def test_text_answer_after_the_question_resolves_the_track(client: TestClient) -> None:
    response = client.post(
        "/api/proposal",
        json={
            "message": "RISET",
            "history": [{"role": "user", "content": "aplikasi mobile absensi siswa"}],
        },
    ).json()

    assert response["stage"] == "draft"
    assert response["path"] == "riset"


def test_proyek_answer_resolves_to_proyek(client: TestClient) -> None:
    response = client.post(
        "/api/proposal",
        json={
            "message": "saya mau jalur proyek",
            "history": [{"role": "user", "content": "aplikasi mobile absensi siswa"}],
        },
    ).json()
    assert response["path"] == "proyek"


def test_ambiguous_answer_asks_again(client: TestClient) -> None:
    response = client.post(
        "/api/proposal",
        json={
            "message": "entahlah",
            "history": [{"role": "user", "content": "aplikasi mobile absensi siswa"}],
        },
    ).json()
    assert response["stage"] == "clarify"


def test_draft_uses_the_idea_from_history_not_the_latest_answer(client: TestClient) -> None:
    response = client.post(
        "/api/proposal",
        json={
            "message": "RISET",
            "history": [{"role": "user", "content": "deteksi plagiarisme judul proposal"}],
        },
    ).json()
    assert response["idea"] == "deteksi plagiarisme judul proposal"


def test_draft_returns_parsed_sections_and_references(client: TestClient) -> None:
    response = client.post(
        "/api/proposal",
        json={
            "message": "riset",
            "history": [{"role": "user", "content": "eye tracking"}],
        },
    ).json()

    titles = [section["title"] for section in response["sections"]]
    assert titles[0] == "Judul"
    assert any("Metodologi" in title for title in titles)
    assert len(response["references"]) == 2
    assert response["references"][0].startswith("Smith, J.")


def test_draft_collects_inline_citations(client: TestClient) -> None:
    response = client.post(
        "/api/proposal",
        json={"message": "riset", "history": [{"role": "user", "content": "eye tracking"}]},
    ).json()
    background = response["sections"][1]
    assert background["citations"] == [1, 2]


def test_draft_grounds_on_published_theses(client: TestClient) -> None:
    response = client.post(
        "/api/proposal",
        json={"message": "riset", "history": [{"role": "user", "content": "eye tracking"}]},
    ).json()
    assert len(response["grounded_on"]) == 5


def test_llm_failure_returns_a_notice_instead_of_a_500(
    client: TestClient, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(proposal_service.llm_client, "complete", lambda *a, **k: None)

    response = client.post(
        "/api/proposal",
        json={"message": "proyek", "path": "proyek"},
    ).json()

    assert response["stage"] == "draft"
    assert response["notice"] == "llm_unavailable"
    assert response["sections"] == []
    assert response["answer"]


def test_whitespace_message_returns_guidance(client: TestClient) -> None:
    response = client.post("/api/proposal", json={"message": "   "}).json()
    assert response["stage"] == "clarify"
    assert "Tuliskan judul" in response["answer"]


def test_invalid_payloads_are_rejected(client: TestClient) -> None:
    assert client.post("/api/proposal", json={"message": ""}).status_code == 422
    assert client.post(
        "/api/proposal", json={"message": "x", "path": "kelompok"}
    ).status_code == 422


def test_system_prompt_encodes_the_official_guidelines() -> None:
    riset = build_system_prompt("riset")
    proyek = build_system_prompt("proyek")

    assert "11 bagian" in riset and "minimal 10 referensi" in riset
    assert "10 bagian" in proyek and "minimal 5 referensi" in proyek
    for expected in (
        "Latarar Belakang".replace("ar ", " "),  # Latar Belakang
        "Rumusan Masalah",
        "Ruang Lingkup",
        "Jadwal Kegiatan",
        "Daftar Pustaka",
    ):
        assert expected in riset and expected in proyek
    assert "State-of-the-Art" in riset
    assert "UAT" in proyek


def test_build_system_prompt_rejects_unknown_track() -> None:
    with pytest.raises(ValueError):
        build_system_prompt("lain")


class TestPathDetection:
    def test_no_history_never_infers_a_track(self) -> None:
        assert proposal_service.detect_track("aplikasi mobile", [], None) is None

    def test_explicit_path_wins_over_text(self) -> None:
        assert (
            proposal_service.detect_track("aplikasi", [{"role": "user", "content": "x"}], "riset")
            == proposal_service.TRACK_RISET
        )

    def test_latest_answer_is_used(self) -> None:
        history = [{"role": "user", "content": "ide awal"}]
        assert proposal_service.detect_track("PROYEK", history, None) == proposal_service.TRACK_PROYEK
        assert proposal_service.detect_track("penelitian", history, None) == proposal_service.TRACK_RISET

    def test_both_words_is_ambiguous(self) -> None:
        history = [{"role": "user", "content": "ide awal"}]
        assert proposal_service.detect_track("aplikasi untuk penelitian", history, None) is None


class TestSectionParsing:
    def test_numbered_headers_become_sections(self) -> None:
        sections, references = proposal_service.parse_sections(CANNED_RISET_DRAFT)
        assert [section.number for section in sections] == [1, 2, 3, 9, 11]
        assert sections[0].title == "Judul"

    def test_numbered_steps_outside_references_are_not_references(self) -> None:
        sections, references = proposal_service.parse_sections(CANNED_RISET_DRAFT)
        assert references == [
            "Smith, J. Eye tracking in exams. Journal of EdTech, 2023.",
            "Doe, A. Fingerprint authentication review. ACM Computing Surveys, 2022.",
        ]

    def test_unstructured_text_becomes_one_section(self) -> None:
        sections, references = proposal_service.parse_sections("Draf bebas tanpa header.")
        assert len(sections) == 1
        assert sections[0].body == "Draf bebas tanpa header."
        assert references == []

    def test_reference_section_title_variants(self) -> None:
        text = "## 1. Referensi\n[1] Satu.\n"
        _, references = proposal_service.parse_sections(text)
        assert references == ["Satu."]