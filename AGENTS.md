# AGENTS.md — UKP TA Repository & RAG Chatbot

Public web app for browsing published Tugas Akhir (TA) theses and asking a RAG chatbot
how similar a proposal is to existing TAs. Flutter Web frontend, Python FastAPI backend,
ChromaDB retrieval, deployed on Vercel. No authentication.

Read `ARCHITECTURE.md` for structure and `CONSTRAINTS.md` for hard rules before changing code.

## Implementation rules

1. Inspect before editing. Read the surrounding Dart widget/service or Python
   route/service and the matching test before changing it. Match existing naming,
   file layout, and idioms instead of introducing a new style.
2. Keep Flutter and Python strictly separated. Dart never imports Python logic and
   Python never emits Dart. The only contract is the JSON API in
   `ARCHITECTURE.md` → API endpoints. Shared vocabulary (query params, response keys,
   filter names) must match that contract exactly on both sides.
3. Reuse existing widgets and API patterns. Extend an existing card, filter widget,
   repository method, or FastAPI router before creating a new one. Match the
   established state-management pattern (e.g. provider/`ChangeNotifier`) rather than
   adding a second mechanism.
4. Minimal dependencies. Do not add packages to `pubspec.yaml` or modules to
   `requirements.txt` unless the feature is impossible with what is already there.
   Prefer the standard library, `http`/`dart:convert`, and existing utils.
5. Graceful API handling. CORS middleware must stay configured in FastAPI, and the
   Flutter HTTP layer must surface loading, empty, and error states — never an
   unhandled exception or a blank screen. Use the existing error-handling helper and
   keep user-visible messages short and non-technical.
6. Secrets stay in the backend. LLM and embedding keys come from environment
   variables read in Python only. Never place a key, token, or secret in Dart,
   `vercel.json`, or any committed file.
7. Focused changes only. No drive-by refactors, renames, reformatting, or dependency
   bumps in files unrelated to the task. Match the diff to the request.
8. Verify before finishing. Run `flutter analyze` and `flutter test` for Dart changes,
   and `.\.venv\Scripts\python.exe -m pytest api\tests` for backend changes. State what
   you ran. The Python suite must stay runnable without keys or network access.

## Domain vocabulary

- TA / Tugas Akhir — final thesis. Keep UI copy in Indonesian-English mix used by the
  existing screens; do not invent new terminology in code.
- Filters — year, program studi, konsentrasi, keyword search. Applied server-side via
  `GET /api/search`.
- Similarity check — chatbot query returning the top 5 matching TAs with scores.
- Topic mapping — chatbot query grouping retrieved TAs into popular topics.

## File placement

| Change | Goes in |
| --- | --- |
| Screen, widget, theme | `lib/` (`screens/`, `widgets/`, `theme/`) |
| HTTP client, models, state | `lib/services`, `lib/models`, `lib/state` |
| Route, service, RAG logic | `api/` (`routers/`, `services/`) |
| TA corpus | `api/data/ta_metadata.json` |
| Tests | `test/` (Dart), `api/tests/` (Python) |
| Deployment config | `vercel.json`, `web/`, `api/requirements.txt` |

Never place application logic in `api/main.py` beyond CORS, router registration, and
lifespan logging; route handlers belong in `api/routers/`, logic in `api/services/`.

## Local commands

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
.\.venv\Scripts\python.exe -m uvicorn api.main:app --reload --port 8000
```

Secrets live in `.env` (git-ignored) and are read by `api/services/config.py`. Set
`GROQ_API_KEY` for the LLM and `GEMINI_API_KEY` for embeddings; with neither, the app
still runs on the local hashing embedder and extractive answers.