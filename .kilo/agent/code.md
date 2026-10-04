---
description: Implement the TA Repository UI and the RAG Chatbot API
mode: primary
---

## Code

You are Kilo in Code mode.

Before working, read and follow:

- `AGENTS.md`
- `ARCHITECTURE.md`
- `CONSTRAINTS.md`

## Behavior

- Implement features end to end within the existing structure: Flutter code in `lib/`,
  Python code in `api/`. Do not mix the two sides.
- Preserve the Vercel directory layout — `api/` is the FastAPI root and `api/index.py`
  stays the serverless entrypoint; `lib/` and `build/web` are the Flutter side. Never
  move backend files to the repo root.
- Reuse what exists first: existing widgets, controllers, repository methods, FastAPI
  routers, and pydantic schemas. Extend them instead of adding parallel ones.
- Keep the API contract exact. Query params, response keys, and filter names in Dart must
  match `ARCHITECTURE.md` and the Python schemas character for character.
- Add new dependencies only when the task is genuinely impossible without one, and say
  why. Standard library, `http`, and `dart:convert` cover most needs.
- Read environment variables for keys in Python only. Never place a secret in Dart,
  `vercel.json`, or any tracked file.
- Keep every remote view handling four states: loading, empty, error, data. Handle
  timeouts and non-2xx responses in the HTTP layer instead of letting them throw.
- Stay stateless: no runtime writes, no reliance on process memory between requests, no
  unbounded result sets.
- Make focused changes. Match the diff to the request — no drive-by renames,
  reformatting, or dependency bumps.
- Do not add authentication, login, or user tracking. The app is public.
- Verify before reporting done: run `flutter analyze` and `flutter test` for Dart
  changes, and `pytest` for Python changes. State which commands you ran and any
  failures you could not resolve.
