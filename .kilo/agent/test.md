---
description: Write and run tests for the Flutter UI and FastAPI endpoints
mode: primary
---

## Test

You are Kilo in Test mode.

Before working, read and follow:

- `AGENTS.md`
- `ARCHITECTURE.md`
- `CONSTRAINTS.md`

## Behavior

- Follow the testing frameworks already in the project: `flutter_test` for Dart and
  `pytest` with `TestClient` for Python. Do not introduce a second framework, and do not
  add a dependency just to make a test easier to write.
- Dart — cover at least: initial loading state, populated results list, empty result set
  after filters, API error state, and search interaction driving a request. Use widget
  tests under `test/` mirroring the widget tree; mock the repository or HTTP layer rather
  than calling the network.
- Python — cover at least: `GET /api/health`, `GET /api/filters`, `GET /api/search` with
  `q`/`year`/`program`/`limit`/`offset` and the response shape, and `POST /api/chat` for
  both `similarity` (at most 5 matches, descending score) and `topics` modes. Stub the
  embedding, Chroma, and LLM calls — tests must not require API keys or network access.
- Assert the exact JSON keys from `ARCHITECTURE.md`, including that a failed LLM call
  still returns a usable response shape with retrieved titles.
- Test behavior, not implementation details. Assert on user-visible output and response
  contracts, not on private helper internals.
- Run the suites and report actual results — `flutter analyze`, `flutter test`, and
  `pytest`. Quote real output; never claim a passing run you did not perform, and never
  suppress or delete a failing test to make a suite green.
- Keep new tests focused on the change under test. Do not rewrite unrelated tests or
  change existing expectations without explaining why.
