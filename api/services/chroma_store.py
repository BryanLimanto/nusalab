"""ChromaDB access.

Two modes, both stateless from the caller's point of view:

* in-memory — an `EphemeralClient` collection built from the committed
  `api/data/ta_metadata.json` at first use. This is the demo default and needs no
  external service.
* hosted — when `CHROMA_HOST` is set, a `HttpClient` points at a persistent ChromaDB
  server. The same committed records are upserted by id, so the collection survives
  cold starts and stays idempotent.

Vectors are always supplied explicitly (`embeddings=`), never through a Chroma embedding
function: that keeps ChromaDB from downloading an ONNX model during a cold start, and
keeps corpus/query vectors produced by exactly the same embedder.
"""

from __future__ import annotations

import json
import logging
import threading
from typing import Any

import chromadb
from chromadb.config import Settings

from . import config
from .embeddings import embed_documents, embed_query

logger = logging.getLogger(__name__)


def load_records() -> list[dict[str, Any]]:
    """Read the committed TA dataset."""
    with config.DATA_FILE.open(encoding="utf-8") as handle:
        payload = json.load(handle)
    records = payload["records"] if isinstance(payload, dict) else payload
    return sorted(records, key=lambda record: (record["year"], record["title"]), reverse=True)


def document_text(record: dict[str, Any]) -> str:
    """Text embedded for retrieval: title, authors, keywords, concentration, abstract."""
    parts = [
        record["title"],
        " ".join(record.get("authors", [])),
        " ".join(record.get("keywords", [])),
        record.get("concentration", ""),
        record.get("abstract", ""),
    ]
    return ". ".join(part for part in parts if part)


class TaStore:
    """Records plus the ChromaDB collection used for vector search."""

    def __init__(self, records: list[dict[str, Any]], collection: Any, dimension: int) -> None:
        self._records = {record["id"]: record for record in records}
        self._order = [record["id"] for record in records]
        self._collection = collection
        self._dimension = dimension

    @classmethod
    def load(cls) -> "TaStore":
        records = load_records()
        collection = _open_collection()
        dimension = 0
        if records:
            documents = [document_text(record) for record in records]
            vectors = embed_documents(documents)
            dimension = len(vectors[0]) if vectors else 0
            collection.upsert(
                ids=[record["id"] for record in records],
                documents=documents,
                embeddings=vectors,
                metadatas=[
                    {
                        "year": int(record["year"]),
                        "program": record["program"],
                        "concentration": record.get("concentration", ""),
                    }
                    for record in records
                ],
            )
        logger.info("Store ready: %d records, dim=%d", len(records), dimension)
        return cls(records, collection, dimension)

    def count(self) -> int:
        return len(self._records)

    def all_records(self) -> list[dict[str, Any]]:
        return [self._records[thesis_id] for thesis_id in self._order]

    def record(self, thesis_id: str) -> dict[str, Any] | None:
        return self._records.get(thesis_id)

    def similarity(
        self,
        query: str,
        n_results: int,
        where: dict[str, Any] | None = None,
    ) -> list[tuple[dict[str, Any], float]]:
        """Vector search. Returns (record, score) with score in [0, 1]."""
        if not self._records:
            return []
        limit = max(1, min(n_results, len(self._records)))
        vector = embed_query(query)
        if self._dimension and len(vector) != self._dimension:
            raise RuntimeError(
                f"query embedding dim {len(vector)} != corpus dim {self._dimension}; "
                "the corpus and query must use the same embedding provider"
            )
        result = self._collection.query(
            query_embeddings=[vector],
            n_results=limit,
            where=where or None,
            include=["distances"],
        )
        ids = (result.get("ids") or [[]])[0]
        distances = (result.get("distances") or [[]])[0]
        hits: list[tuple[dict[str, Any], float]] = []
        for index, thesis_id in enumerate(ids):
            record = self._records.get(thesis_id)
            if record is None:
                continue
            distance = float(distances[index]) if index < len(distances) else 1.0
            hits.append((record, max(0.0, min(1.0, 1.0 - distance))))
        return hits


def _open_collection() -> Any:
    name = config.CHROMA_COLLECTION or "ukp_ta"
    metadata = {"hnsw:space": "cosine"}
    if config.CHROMA_HOST:
        client = chromadb.HttpClient(host=config.CHROMA_HOST, port=config.CHROMA_PORT)
        source = f"hosted {config.CHROMA_HOST}:{config.CHROMA_PORT}"
    else:
        client = chromadb.EphemeralClient(Settings(anonymized_telemetry=False))
        source = "in-memory"
    collection = client.get_or_create_collection(name=name, metadata=metadata)
    logger.info("ChromaDB %s, collection=%s", source, name)
    return collection


_store: TaStore | None = None
_lock = threading.Lock()


def get_store() -> TaStore:
    """Lazily build the store on first use so a cold start pays nothing at import time."""
    global _store
    if _store is None:
        with _lock:
            if _store is None:
                _store = TaStore.load()
    return _store


def reset_store() -> None:
    """Drop the cached store. Used by tests."""
    global _store
    with _lock:
        _store = None
