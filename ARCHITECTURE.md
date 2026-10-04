# ARCHITECTURE.md — TA Repository & RAG Chatbot

## Stack

| Layer | Choice |
| --- | --- |
| Frontend | Flutter Web (Dart), static build served by Vercel |
| Backend | Python 3 FastAPI, entirely inside `api/` for Vercel serverless routing |
| Database | ChromaDB (Python) holding published TA metadata + embeddings |
| Embeddings | Gemini `gemini-embedding-001`, or a local hashing embedder as fallback |
| LLM | Groq `openai/gpt-oss-120b`, with Gemini and an extractive fallback |
| Hosting | Vercel (static Flutter output + one serverless Python function) |

No auth, no login, no user accounts. All endpoints are public.

## Repository layout

```
lib/                      Flutter app
  main.dart               app entry, providers, routes
  config.dart             API base URL, request timeouts
  theme/app_theme.dart    colors, typography, shared spacing
  models/                 thesis, search_result, search_filters, filter_options,
                          chat_message, proposal_draft
  services/api_client.dart HTTP client + ApiException
  state/                  repository_search_controller.dart, chat_controller.dart,
                          proposal_controller.dart
  screens/                home_screen.dart, publications_screen.dart
  widgets/                search_header, filter_sidebar, thesis_card, chat_panel,
                          proposal_panel, chat_overlay, state_views
api/                      FastAPI serverless app
  main.py                 Vercel entrypoint: app, CORS, routers, lifespan
  routers/                meta.py (health, filters), search.py, chat.py, proposal.py
  services/               config, embeddings, chroma_store, filters, llm_client,
                          rag_service, proposal_prompt, proposal_service
  data/ta_metadata.json   committed sample dataset (24 TAs)
  tests/                  pytest suite
test/                     Flutter tests
web/                      generated Flutter Web shell (index.html, manifest, icons)
vercel.json               build config + rewrite routing
.env / .env.example       local secrets (git-ignored)
```

## Configuration

Secrets are read in `api/services/config.py` from the environment, with `.env` at the
repo root loaded for local development. `.env` is git-ignored and must never be committed.

| Variable | Purpose | Default |
| --- | --- | --- |
| `GROQ_API_KEY` | LLM key for Groq | empty (LLM disabled) |
| `GROQ_MODEL` | Groq model id | `openai/gpt-oss-120b` |
| `GEMINI_API_KEY` | Embeddings, and LLM fallback | empty (local hashing embedder) |
| `GEMINI_EMBED_MODEL` | Gemini embedding model | `gemini-embedding-001` |
| `GEMINI_MODEL` | Gemini chat model | `gemini-2.0-flash` |
| `CHROMA_HOST` / `CHROMA_PORT` / `CHROMA_COLLECTION` | Hosted ChromaDB | empty → in-memory |
| `ALLOWED_ORIGINS` | Comma-separated CORS origins | `*` |

Keys travel in request headers (`Authorization` for Groq, `x-goog-api-key` for Gemini),
never in query strings.

## Frontend (Flutter Web)

- Material 3, academic and list-first: neutral palette, thin separators, no shadows.
- State: `provider` + `ChangeNotifier`.
  `RepositorySearchController` owns filters, options, and the current result page;
  `ChatController` owns the similarity conversation; `ProposalController` owns the
  proposal generator conversation. Note the `Repository` prefix — a bare
  `SearchController` collides with Material's own class.
- Networking: `http` + `dart:convert` in `services/api_client.dart`. Base URL comes from
  `String.fromEnvironment('API_BASE_URL', defaultValue: '/api')`, so the same build works
  on Vercel and against a local server:
  `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api`.
- Timeouts: `AppConfig.requestTimeout` (25 s) for repository and chatbot calls,
  `AppConfig.proposalTimeout` (120 s) for the generator, whose draft runs to several
  thousand tokens and would be cut off by the short budget.
- Models map 1:1 to the JSON contract; parsing is null-safe with sensible defaults.
- Keyword input is debounced (350 ms); filter changes and pagination refetch at once.
- Every remote view models four states: loading, empty, error, data (`widgets/state_views.dart`).

## Backend (FastAPI in `api/`)

- `api/main.py` builds `FastAPI`, adds `CORSMiddleware`, includes routers, and logs the
  effective configuration through a lifespan hook. It is the Vercel function entrypoint.
  Import works both as a package (`api.main`) and as a top-level module (`main`).
- Routers stay thin: validate with pydantic, call a service, return a schema.
- Services hold all logic: config, embeddings, ChromaDB access, filtering, LLM, RAG.
- Failure handling: provider errors are caught in the service layer, logged server-side,
  and degraded to a usable response. Clients never receive stack traces or provider detail.

### API endpoints

`GET /api/health`

```json
{ "status": "ok", "records": 24, "llm": "groq", "store": "in-memory" }
```

`GET /api/filters` — distinct values for the sidebar.

```json
{
  "years": [2026, 2025, 2024, 2023, 2022, 2021, 2020],
  "programs": ["Informatika", "Sistem Informasi", "Teknik Biomedik", "Teknik Elektro", "Teknik Industri"],
  "concentrations": ["Artificial Intelligence", "Cyber Security", "..."],
  "topics": ["computer vision", "nlp", "..."],
  "tags": ["Q1", "AI"]
}
```

`GET /api/search` — browse when `q` is empty, vector search when it is not.

| Query param | Type | Notes |
| --- | --- | --- |
| `q` | string | keyword query; blank means browse, newest year first |
| `year` | int | optional single year |
| `years` | int, repeatable | e.g. `?years=2024&years=2025` |
| `year_from` / `year_to` | int | inclusive bounds of the year range slider |
| `program` | string | program studi |
| `concentration` | string | konsentrasi |
| `topic` | string | topik / kata kunci, matched against keywords and tags |
| `limit` | int | 1–50, default 20 |
| `offset` | int | default 0 |

```json
{
  "total": 24,
  "limit": 20,
  "offset": 0,
  "items": [
    {
      "id": "ta-2025-0002",
      "title": "Aplikasi Mobile untuk Absensi Siswa Berbasis QR Code pada Madrasah Ibtidaiyah",
      "authors": ["R. Prasetyo", "N. Rahmawati"],
      "program": "Informatika",
      "concentration": "Mobile Engineering",
      "year": 2025,
      "keywords": ["mobile", "absensi", "qr code", "flutter"],
      "tags": ["Q1", "Mobile", "Web"],
      "abstract": "Dibangun aplikasi absensi siswa berbasis mobile…",
      "url": "https://repository.ukp.ac.id/ta/2025/0002",
      "score": 0.841
    }
  ]
}
```

`score` is `null` for browse results and set for keyword searches, where literal keyword
hits add a small lexical boost on top of the vector score.

`POST /api/chat` — `mode` is `similarity` (top 5 matching TAs) or `topics`.

```json
// request
{ "message": "aplikasi mobile untuk absensi siswa", "mode": "similarity",
  "filters": { "years": [2025], "program": "Informatika" } }

// response
{
  "answer": "Proposal ini sangat mirip dengan TA [1]…",
  "mode": "similarity",
  "matches": [
    { "id": "ta-2025-0002", "title": "Aplikasi Mobile untuk Absensi Siswa…",
      "authors": ["R. Prasetyo"], "year": 2025, "program": "Informatika",
      "score": 0.841, "why": "Irisan kata kunci: mobile, absensi, qr code" }
  ],
  "topics": [],
  "notice": null
}
```

`matches` is capped at 5 and sorted by descending score. `topics` is populated only in
`topics` mode (`label`, `count`, `thesis_ids`). `notice` is non-null when the answer was
degraded — no LLM, or no embedding provider.

`POST /api/proposal` — the Proposal TA generator. Stateless: the client resends the
conversation on every call, so nothing is stored between invocations.

```json
// request
{ "message": "deteksi kecurangan ujian online", "history": [{"role": "user", "content": "..."}],
  "path": "riset", "concentration": "Artificial Intelligence" }

// response — track still unknown
{
  "stage": "clarify",
  "answer": "Apakah Tugas Akhir ini mengambil jalur RISET atau PROYEK?…",
  "path": null,
  "idea": "deteksi kecurangan ujian online",
  "sections": [], "references": [], "grounded_on": [], "notice": null
}

// response — draft produced
{
  "stage": "draft",
  "answer": "Draf proposal jalur RISET berikut siap disunting.",
  "path": "riset",
  "idea": "deteksi kecurangan ujian online",
  "sections": [
    { "number": 1, "title": "Judul", "body": "…", "citations": [] },
    { "number": 2, "title": "Latar Belakang Masalah", "body": "…", "citations": [1, 2] }
  ],
  "references": ["Smith, J. Eye tracking in exams. Journal of EdTech, 2023."],
  "grounded_on": ["Aplikasi Mobile untuk Absensi Siswa Berbasis QR Code"],
  "notice": null
}
```

| Field | Notes |
| --- | --- |
| `message` | 1–4000 characters; the first user turn is the research idea |
| `history` | up to 10 resent turns of `{role, content}` |
| `path` | optional explicit `riset`/`proyek`; skips text detection |
| `concentration` | optional konsentrasi, used as extra drafting context |
| `stage` | `clarify` while the track is unresolved, `draft` afterwards |
| `citations` | inline `[n]` markers found in the section body |
| `grounded_on` | titles of the published TAs injected as context, shown as provenance |
| `notice` | non-null (`llm_unavailable`) when the provider produced nothing |

`GET /api/chat` and `POST /api/proposal` share the provider order in `llm_client`
(Groq, then Gemini, then a degraded response — never a 500).

## Proposal generator

`api/services/proposal_prompt.py` holds the system prompt and `proposal_service.py` the
flow around it. Both tracks from the official UKP AI-concentration guidelines are
transcribed there:

- **RISET** — 11 sections, ending with at least 10 references from the last 5 years.
- **PROYEK** — 10 sections, ending with at least 5 references from web documentation or
  papers; the Landasan Teori and Penelitian Terdahulu sections are marked optional.

The generator runs in two stages:

1. **Clarify** — on the first turn the track is always unresolved, even when the idea
   contains words like "aplikasi" or "penelitian", and `CLARIFY_QUESTION` is returned.
   `detect_track` resolves the track from an explicit `path` first, then from the
   student's latest answer.
2. **Draft** — `build_system_prompt(track)` assembles role, per-track section list, and a
   fixed output contract (`## N. Title` headers, inline `[n]` citations, ≥ minimum
   references). `llm_client.complete` is called with `LONG_MAX_TOKENS` because the short
   default would truncate the later sections.

Grounding: `_context_block` retrieves the 5 most similar published TAs from ChromaDB and
requires the Penelitian Terdahulu section to cite their real titles and years, so the
State-of-the-Art section cannot be invented. A failed embedding degrades to an explicit
"tidak tersedia" note rather than an exception.

`parse_sections` splits the answer on `## N. Title`, harvests the reference list only
inside the Daftar Pustaka block (so numbered step lists elsewhere are not mistaken for
citations), and falls back to a single section when the model ignores the contract.

## RAG pipeline

1. **Corpus** — `api/data/ta_metadata.json` holds published TA metadata: title, authors,
   program, konsentrasi, year, keywords, tags, abstract, URL. It is the source of truth for
   both the sidebar filters and the embedded text
   (`title + authors + keywords + konsentrasi + abstract`).
2. **Store** — `chroma_store.py` opens an ephemeral in-memory collection by default, or a
   hosted `HttpClient` collection when `CHROMA_HOST` is set, using cosine space. Records
   are upserted by id, so the operation is idempotent and safe on every cold start.
   Vectors are passed explicitly (`embeddings=`), which stops ChromaDB from downloading an
   ONNX model mid-request.
3. **Embeddings** — `embeddings.py` picks one provider for the whole process: Gemini when
   `GEMINI_API_KEY` is set, otherwise a pure-Python hashing embedder (L2-normalized hashed
   token bag, 256 dims). The choice is sticky and can only be downgraded, so corpus and
   query vectors always share one space and dimension. Gemini failures on 429/5xx are
   retried twice with a short backoff.
4. **Retrieval** — the query is embedded with the same provider, then queried with
   `n_results = max(15, 5 × 3)` so the top 5 are chosen from a wider candidate set. Year,
   program, and konsentrasi are passed as a Chroma `where` clause and re-checked in Python,
   because a hosted collection can hold rows the local dataset no longer has.
5. **Context injection** — `rag_service.build_context` renders retrieved records into a
   numbered block. The system prompt fixes the role (TA repository assistant), restricts
   answers to that block, and requires saying so when the data is insufficient.
6. **Generation** — `llm_client.complete` calls Groq, then Gemini. If neither answers, the
   service falls back to an extractive summary built from the retrieved titles, scores, and
   keyword overlaps, and sets `notice` so the UI can disclose the degradation.
7. **Failure paths** — if a query embedding fails outright, `/api/chat` returns a friendly
   message with `notice: "embedding_unavailable"`, and `/api/search` degrades from vector
   ranking to literal keyword matching. Neither path returns a 500.

## Routing (vercel.json)

```json
{
  "framework": null,
  "installCommand": "flutter pub get",
  "buildCommand": "flutter build web --release",
  "outputDirectory": "build/web",
  "functions": { "api/main.py": { "maxDuration": 60, "memory": 1024 } },
  "rewrites": [
    { "source": "/api/(.*)", "destination": "/api/main.py" },
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

- `/api/*` hits the Python serverless function; everything else falls back to
  `index.html`, so deep links and `/publications` survive a refresh.
- Python dependencies come from `api/requirements.txt`, which Vercel installs for the
  function automatically; `installCommand` therefore only fetches Dart packages.
- Any change to `api/requirements.txt`, the Chroma version, or the rewrite order is a
  deployment-affecting change — read `CONSTRAINTS.md` first.
- **Flutter is not in Vercel's build image.** That image is Amazon Linux 2023 with
  Node, Python, and Ruby, so `installCommand` clones the stable Flutter SDK into
  `flutter/` and `buildCommand` calls `flutter/bin/flutter` by that relative path.
  Anything that assumes a bare `flutter` on `$PATH` will fail here. The clone is cached
  between builds but still adds several minutes to the first one.
- `maxDuration: 60` also bounds `POST /api/proposal`. Measured locally against Groq, a
  full RISET draft takes roughly 10 s, so the cap leaves comfortable headroom; a provider
  fallback chain that stalls would surface as a gateway error rather than a draft.
- **Function bundle size is tight.** `chromadb` pulls in `onnxruntime` (~44 MB) and
  `numpy` (~31 MB), and the runtime dependencies total roughly 219 MB unzipped against
  Vercel's 250 MB limit for a Python function. `onnxruntime` is dead weight here because
  vectors are always passed explicitly, so the ONNX model is never loaded — pruning it is
  the obvious headroom if the build ever reports an oversized function.

## UI structure

**Repository screen** (`screens/home_screen.dart`)

- `AppBar` — UKP logo block, "Home", "Publications", "Chatbot Proposal AI", and "Chatbot"
  on wide viewports; a filter icon and two chatbot icons on narrow ones.
- `SearchHeader` — prominent search field plus a Cari button, result summary line, and
  removable chips for the active filters, including the year range and the topik.
- Left sidebar (`FilterSidebar`) — a year range `RangeSlider` bounded by the oldest and
  newest published year, checkboxes for Program Studi and Konsentrasi, a Topik dropdown,
  all populated from `/api/filters`, plus a Reset action. Fixed column at ≥ 900 px, a
  `Drawer` below that. Picking a program clears a konsentrasi that belongs to another
  program, and a full slider span reports itself as unset.
- Right list — `ListView` of `ThesisCard`: title, authors, program · konsentrasi · year,
  truncated abstract, tag and keyword chips, source link, and a score badge when the result
  came from a keyword search. A footer shows the current range and paging buttons.
- Empty state offers a filter reset; error state offers retry.
- Two stacked FABs at the bottom right — the accent-coloured one opens the proposal
  generator, the extended one opens the similarity chatbot.

**Publications screen** (`screens/publications_screen.dart`)

- The full catalogue grouped by year, reusing the same controller and cards.

**Chatbot** (`widgets/chat_panel.dart`)

- Opened from the FAB or the AppBar action, through the shared `ChatOverlay`: a right-hand
  sliding panel at ≥ 900 px, a bottom sheet below that, so results stay visible while asking.
- Mode switch (Cek Similarity / Pemetaan Topik), message list, and a composer.
- Assistant bubbles render the answer text, up to 5 match rows with score and `why`, topic
  chips with counts, and the `notice` line when the answer was degraded.

**Proposal generator** (`widgets/proposal_panel.dart`)

- Same `ChatOverlay` placement, opened from the FAB or the "Chatbot Proposal AI" action.
- Intro lists both official tracks with their section counts before anything is sent; the
  student's idea is the first turn.
- The clarification answer renders RISET / PROYEK quick replies, which send the track as an
  explicit `path`. Typing "RISET" or "PROYEK" works too.
- A draft renders as collapsible `ExpansionTile` sections (first one open, inline `[n]`
  citations in the trailing slot), a provenance note listing the retrieved TAs, the
  numbered reference list, and a "Salin draf" action that flattens everything to plain
  text on the clipboard. The clipboard write is fire-and-forget so the confirmation is
  immediate.
- `ProposalController` resends only prior *user* turns (clipped to the server's 4000
  characters and 10-turn limits): the clarification question is fixed and resending a
  multi-thousand-token draft would waste the context.
- Long generation shows "Menyusun draf proposal, mohon tunggu…"; a failed provider shows a
  short message plus the `notice` line instead of a stack trace.

## Verification

```powershell
flutter analyze
flutter test
.\.venv\Scripts\python.exe -m pytest api\tests
```

The Python suite runs fully offline: `api/tests/conftest.py` clears provider
credentials after import, so tests never reach Gemini or Groq.
