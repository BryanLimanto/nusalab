# CONSTRAINTS.md — Hard Rules

These are non-negotiable. If a task appears to require breaking one, stop and raise it
instead of working around it.

## Stack is fixed

1. Frontend stays **Flutter Web (Dart)**. Do not introduce React, Vue, plain HTML/CSS
   pages, or a second UI framework.
2. Backend stays **Python + FastAPI**, located entirely in `api/`. Do not move Python
   files to the repo root or to a `server/`, `functions/`, or `backend/` folder —
   `api/` is what Vercel routes to.
3. Retrieval stays **ChromaDB** accessed from Python. Do not swap in another vector
   store as part of an unrelated change.
4. Do not change the LLM/embedding providers or rewire the RAG flow without an explicit
   instruction. `ARCHITECTURE.md` → RAG pipeline is the agreed design.

## No authentication

5. Do not implement login, signup, sessions, tokens, cookies, roles, or protected
   routes. The app is public. Do not add a "sign in" affordance to the UI.
6. Do not add per-user state or personalization that requires identity.

## Secrets

7. LLM and embedding keys are read from environment variables in Python only
   (`os.environ` / `os.getenv`), with `.env` at the repo root for local development.
   Never hardcode a key, token, or `.env` value in Dart, `vercel.json`, `pubspec.yaml`,
   or any committed file.
8. Never return provider errors, stack traces, request URLs with keys, or internal
   config to the client. Log server-side, return a short user-safe message.
9. Do not commit `.env` or add one to the deployed bundle. It is git-ignored; keep it
   that way and document required variables in prose only.
10. Send provider keys in headers (`Authorization`, `x-goog-api-key`), never in query
    strings — query strings land in logs and proxies. Keep `httpx` logging at WARNING.
11. A test assertion must never be able to echo a secret. Tests neutralise credentials by
    assigning empty strings to the `config` module, never by comparing keys.

## Statelessness on Vercel

12. Vercel functions are stateless and may be recycled at any time. No reliance on
    process memory, local disk writes, background tasks, or files created at runtime.
13. Keep the ChromaDB implementation lightweight: an ephemeral in-memory collection
    built from the committed static dataset in `api/data/`, or an external persistent
    store via `CHROMA_HOST`. Never write to a persistent local Chroma directory at
    runtime and never assume state survives between invocations.
14. Load the corpus lazily on first use and keep initialization cheap. Records are
    upserted by id, so the operation stays idempotent across cold starts.
15. Return paginated, bounded results (`limit` max 50). No unbounded response payloads.
16. Corpus and query embeddings must come from the same provider and dimension. Pin the
    choice per process instead of deciding per call.

## Network

17. `CORSMiddleware` in `api/main.py` stays enabled and must cover the deployed
    frontend origin. Do not remove, reorder, or narrow it without an explicit reason.
18. Flutter must treat every API call as failure-capable: timeouts, non-2xx, and
    malformed JSON must produce a visible error state, never an unhandled exception.
    `/api/search` and `/api/chat` degrade gracefully instead of returning a 500.
19. API request and response shapes are the contract in `ARCHITECTURE.md`. Any change
    to a field name or query param must land in the same change on both sides. Note
    that `years` is a repeatable query parameter, not a comma-joined list.

## Scope

20. No unrelated refactors, renames, reformatting, or dependency bumps. Match the diff
    to the request.
21. Prefer existing code and dependencies. Adding to `pubspec.yaml` or
    `api/requirements.txt` needs a stated reason.
22. Leave `kilo.json` as-is (`{"$schema": …}` only). Agents and instructions live in
    `.kilo/` and the root Markdown docs; do not relocate them to `.kilocode/`,
    `.opencode/`, or `.kilo/modes/`.
23. Verify before reporting done: `flutter analyze` and `flutter test` for Dart,
    `.\.venv\Scripts\python.exe -m pytest api\tests` for Python, and state which
    commands you ran.
