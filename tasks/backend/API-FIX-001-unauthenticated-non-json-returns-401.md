# Focused Fix Contract: API-FIX-001 — Unauthenticated Non-JSON Requests Return 401

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `API-FIX-001` (platform-wide; not a Stage task) |
| Origin | Observation recorded at `S08-INT-001` readiness (index §19) and confirmed on the Stage 8 runtime (index §21) |
| Project Owner decision | `INT-D9` = option 1 (2026-09-28): a separate small fix task right after the Stage 8 closure |
| Area | Backend |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |
| Baseline | `origin/main` `746514335e7d53956e6e1d3e4e0fb2b68685cd80` (Stage 8 closed) |

## 2. Problem

An unauthenticated request to a protected `/api/v1` route that does not ask for JSON (no
`Accept: application/json`, for example a browser opening a file link or `curl`) returns
`500 server_error` instead of `401 authentication_required`.

Cause: `ApplicationBuilder::withMiddleware()` configures `redirectGuestsTo(fn () => route('login'))`.
When the request does not expect JSON, `Authenticate::unauthenticated()` calls that callback. The API
defines no `login` route, so `route('login')` throws, and the catch-all renderer in
`bootstrap/app.php` maps the exception to `500 server_error`. This has been present since the API
foundation (`792bb4c`). Requests with `Accept: application/json` (the Flutter clients) are not
affected, because the callback is not called for them.

## 3. Exact Contract

- `bootstrap/app.php` configures `redirectGuestsTo` to return `null`: the API never redirects an
  unauthenticated guest.
- Every unauthenticated request to a protected `/api/v1` route returns `401` with exactly
  `{"message": "Authentication is required.", "code": "authentication_required", "errors": {}}`
  (`docs/09` §2.5), whatever its `Accept` header.
- Requests with `Accept: application/json` behave exactly as before.

### Non-Goals

- No route, authorization, token or error-code change.
- No web UI or login route (`routes/web.php` exposes none).

## 4. Expected Files

```text
backend/bootstrap/app.php
backend/tests/Feature/ApiErrorContractTest.php
tasks/backend/API-FIX-001-unauthenticated-non-json-returns-401.md
tasks/README.md
```

## 5. Acceptance Criteria

- [ ] A regression test sends unauthenticated requests to real protected routes (`GET auth/me`, `GET teacher/blitz`, `GET files/{file}/download`, `GET` with `Accept: text/html`, `POST teacher/blitz/{blitz}/activate` with a JSON body and `Accept: */*`) and receives the exact 401 envelope; it fails with `500` before the fix.
- [ ] Authentication, authorization and file-download tests still pass.
- [ ] `pint --test` passes on the changed PHP files.

## 6. Focused Verification

```text
php artisan test tests/Feature/ApiErrorContractTest.php tests/Feature/Auth tests/Feature/Authorization tests/Feature/Files
vendor/bin/pint --test bootstrap/app.php tests/Feature/ApiErrorContractTest.php
git diff --check
```

The change affects only the unauthenticated path of requests that do not ask for JSON, so the full
backend suite and the integration evidence are not rerun.
