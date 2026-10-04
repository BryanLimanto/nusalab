"""GET /api/search, /api/filters, /api/health."""

from __future__ import annotations

from fastapi.testclient import TestClient


def test_health_reports_ok_and_record_count(client: TestClient) -> None:
    payload = client.get("/api/health").json()
    assert payload["status"] == "ok"
    assert payload["records"] > 0
    assert payload["llm"] in {"groq", "gemini", "none"}
    assert payload["store"] in {"hosted", "in-memory"}


def test_filters_lists_distinct_values_newest_year_first(client: TestClient) -> None:
    payload = client.get("/api/filters").json()
    assert payload["years"] == sorted(payload["years"], reverse=True)
    assert payload["programs"] == sorted(payload["programs"])
    assert "Informatika" in payload["programs"]
    assert payload["concentrations"]


def test_search_without_query_returns_records_newest_first(client: TestClient) -> None:
    payload = client.get("/api/search").json()
    assert payload["total"] > 0
    years = [item["year"] for item in payload["items"]]
    assert years == sorted(years, reverse=True)
    assert payload["offset"] == 0
    assert payload["limit"] == 20


def test_search_item_shape_matches_contract(client: TestClient) -> None:
    item = client.get("/api/search").json()["items"][0]
    assert set(item) >= {
        "id",
        "title",
        "authors",
        "program",
        "concentration",
        "year",
        "keywords",
        "tags",
        "abstract",
        "url",
        "score",
    }
    assert isinstance(item["year"], int)
    assert isinstance(item["keywords"], list)


def test_search_rejects_out_of_range_limit(client: TestClient) -> None:
    assert client.get("/api/search", params={"limit": 0}).status_code == 422
    assert client.get("/api/search", params={"limit": 51}).status_code == 422


def test_search_filters_by_program(client: TestClient) -> None:
    payload = client.get("/api/search", params={"program": "Informatika", "limit": 50}).json()
    assert payload["items"]
    assert all(item["program"] == "Informatika" for item in payload["items"])


def test_search_filters_by_multiple_years(client: TestClient) -> None:
    response = client.get("/api/search", params=[("years", 2024), ("years", 2025), ("limit", 50)])
    payload = response.json()
    assert payload["items"]
    assert {item["year"] for item in payload["items"]} <= {2024, 2025}


def test_search_filters_by_concentration(client: TestClient) -> None:
    payload = client.get("/api/search", params={"concentration": "Cyber Security"}).json()
    assert payload["total"] == 1
    assert payload["items"][0]["concentration"] == "Cyber Security"


def test_search_keyword_ranks_relevant_record_first(client: TestClient) -> None:
    payload = client.get("/api/search", params={"q": "absensi siswa QR code"}).json()
    assert payload["items"], "keyword search returned nothing"
    assert "absensi" in payload["items"][0]["title"].lower()


def test_search_keyword_returns_scored_items(client: TestClient) -> None:
    payload = client.get("/api/search", params={"q": "chatbot"}).json()
    scores = [item["score"] for item in payload["items"]]
    assert scores == sorted(scores, reverse=True)
    assert all(0.0 <= score <= 1.0 for score in scores)


def test_search_impossible_filter_returns_empty_result(client: TestClient) -> None:
    payload = client.get("/api/search", params={"program": "Program Yang Tidak Ada"}).json()
    assert payload["total"] == 0
    assert payload["items"] == []


def test_search_pagination_walks_through_records(client: TestClient) -> None:
    first = client.get("/api/search", params={"limit": 5, "offset": 0}).json()
    second = client.get("/api/search", params={"limit": 5, "offset": 5}).json()
    assert first["total"] == second["total"]
    assert len(first["items"]) == len(second["items"]) == 5
    assert {item["id"] for item in first["items"]}.isdisjoint(
        {item["id"] for item in second["items"]}
    )
