# Codex Task: Laravel API Scaffold & Backend Quality Foundation

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S01-BE-001` |
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Area | `Backend` |
| Status | `Accepted` |
| Depends on | `S01-INT-002 — GitHub Remote, Repository Baseline & Stage 1 Control (Accepted)` |
| Blocks | `S01-INT-003 — Local Backend Runtime & PostgreSQL Foundation` |

This detailed task is approved by the project owner for Codex execution.
Codex must still enforce all dependency, preflight, acceptance, scope, and
GitHub delivery gates defined below.

## 2. Goal

Create the real Laravel backend application inside `backend/` and establish the
smallest production-quality API foundation required by later Stage 1 backend
tasks.

The accepted result must provide:

- a clean Laravel 13 application scaffold;
- Laravel Sanctum installed as the approved API-authentication package
  foundation, without implementing login/session business behavior yet;
- the public client API rooted at `/api/v1`;
- JSON API error rendering that matches the locked TestLabUz contract;
- backend testing and formatting/style quality gates;
- a clean task branch ready for later PostgreSQL/runtime integration.

This task must not implement Institution/User persistence, authentication
endpoints, first-login password change, role authorization, Flutter, Docker
runtime, or later product features.

## 3. Current Context

The repository root is:

`G:\project\testlabuz`

`S01-INT-002` is accepted. The shared Git baseline is on `origin/main`.

Baseline commit reported by the accepted task:

`c4a913ae916ad37a09c1a3b8c14cc8806711d80f`

At the start of this task, Codex must independently verify the actual current
`main` / `origin/main` state rather than trusting this recorded hash blindly.

Current backend state before scaffolding is intentionally minimal:

```text
backend/
  AGENTS.md
```

The repository also contains the locked `docs/01–09`, task workflow, root
`AGENTS.md`, and Git/GitHub delivery rules.

### Framework version resolution

At task preparation time (`2026-08-09`), the official stable Laravel line is
Laravel `13.x`, which requires PHP `>= 8.3`.

For this task:

- use Laravel `13.x`;
- verify the installed PHP and Composer environment before scaffolding;
- do not silently downgrade Laravel because the local runtime is old;
- do not modify global PHP, Composer, Git, or system configuration;
- if PHP/Composer cannot safely create and run Laravel 13, stop and report the
  dependency blocker.

Use only official Laravel/Composer scaffolding mechanisms. Do not hand-build a
fake Laravel directory tree.

## 4. Included Scope

### 4.1 Git/task control

After confirming `S01-BE-001` is approved:

1. Start from clean, synchronized local `main`.
2. Verify:
   - `origin` is the approved TestLabUz remote;
   - local `main == origin/main`;
   - working tree is clean;
   - `S01-INT-002` is accepted.
3. Create one task branch from current `main`.

Required branch name:

`task/s01-be-001-laravel-api-foundation`

4. Materialize this approved task contract at:

`tasks/backend/stage-01/S01-BE-001-laravel-api-scaffold-quality-foundation.md`

inside the task branch.

5. Update only the relevant `S01-BE-001` row in
   `tasks/STAGE_01_TASK_INDEX.md` from `Draft` to `Approved` for the
   implementation/review lifecycle.

Do not modify `main` directly before the task branch exists.

### 4.2 Laravel scaffold

Create a genuine fresh Laravel 13 application under:

`backend/`

The existing:

`backend/AGENTS.md`

must be preserved exactly unless a conflict with the locked architecture is
discovered and explicitly reported.

Because `backend/` is already non-empty due to `AGENTS.md`, use a safe
scaffolding approach. Preferred concept:

1. create a fresh Laravel 13 application in a temporary directory outside the
   repository or another safe temporary path;
2. verify the generated application;
3. transfer the generated Laravel application into `backend/` without
   overwriting/removing `backend/AGENTS.md`;
4. delete the temporary scaffold after successful transfer if safe.

Do not temporarily delete the repository's approved backend instructions just
to make the installer accept the target directory.

Do not initialize a nested Git repository inside `backend/`.

Do not install a Laravel starter kit, Blade authentication UI, Livewire,
Inertia, React, Vue, WorkOS, Fortify application flows, or any other UI/auth
starter.

Framework-generated support files are allowed when they are part of the
official Laravel application skeleton. Do not add unrelated packages.

### 4.3 API installation / Sanctum foundation

Use Laravel's supported API installation mechanism for Laravel 13 so Sanctum
and the normal API route infrastructure are installed.

The resulting application must have Laravel Sanctum available for later Stage 1
authentication tasks.

However, this task must not implement:

- `POST /api/v1/auth/login`;
- `POST /api/v1/auth/logout`;
- `GET /api/v1/auth/me`;
- `POST /api/v1/auth/change-password`;
- token issuance business logic;
- token revocation business logic;
- account status enforcement;
- institution status enforcement.

Remove any framework/example API route such as a generated `/api/user` route
if it is not part of the locked TestLabUz contract.

### 4.4 API versioning

Configure the public TestLabUz client API to use:

`/api/v1`

All future Flutter-facing API routes must be registered beneath this base
prefix.

Do not create fake production endpoints merely to prove the prefix.

Operational/framework routes that are not Flutter client API contracts must not
be misrepresented as `/api/v1` product endpoints.

### 4.5 API error-contract foundation

For `/api/v1/*`, expected API errors must follow the locked contract in
`docs/09-api-contracts.md`.

Canonical expected error shape:

```json
{
  "message": "Human-readable message.",
  "code": "stable_machine_code",
  "errors": {},
  "request_id": "optional-correlation-id"
}
```

Rules:

- `errors` is always a JSON object.
- `request_id` is optional. Do not invent a correlation-ID subsystem merely to
  populate it in this task.
- Human-readable `message` is not client control flow.
- Stable machine-readable `code` is the control-flow contract.
- Production-safe 500 responses must not expose stack traces, SQL, filesystem
  paths, environment values, secrets, or tokens.

Establish centralized API rendering for the framework-level categories needed
by later tasks, including the applicable TestLabUz contract behavior for:

- `422 validation_failed`;
- `401 authentication_required`;
- `403 forbidden`;
- `404 resource_not_found`;
- `429 rate_limited`;
- `500 server_error`.

Do not invent new public stable error codes that are absent from the locked API
contract.

`409` domain/business conflicts will be implemented by focused later tasks when
an actual approved business conflict is introduced. This scaffold task must
not create speculative domain exception hierarchies for future features.

Laravel 13's framework exception facilities should be used cleanly; avoid a
parallel homemade HTTP kernel.

### 4.6 API-only boundary

The backend is a Laravel REST API.

This task must not introduce a product web UI or product frontend inside the
Laravel application.

Do not install or implement:

- Blade product pages;
- authentication web forms;
- Inertia/Livewire product UI;
- role dashboards;
- frontend application state.

A framework-generated support file may remain if removing it would be
unnecessary/destructive, but no generated demo route may become a TestLabUz
product contract.

Do not run/install Node/NPM dependencies merely for this backend API task.

### 4.7 Tests and quality foundation

Use the test framework generated/supported by the chosen Laravel 13 scaffold.
Do not add a second competing PHP test framework merely for preference.

Add focused backend tests proving at least:

1. `/api/v1` error responses are JSON contract responses.
2. Unknown `/api/v1/...` route returns:
   - HTTP 404;
   - `code = resource_not_found`;
   - `errors = {}`.
3. Validation failure returns:
   - HTTP 422;
   - `code = validation_failed`;
   - field errors as an object.
4. An authentication exception on an API request maps to:
   - HTTP 401;
   - `code = authentication_required`;
   - `errors = {}`.
5. An authorization exception on an API request maps to:
   - HTTP 403;
   - `code = forbidden`;
   - `errors = {}`.
6. Rate limiting maps to:
   - HTTP 429;
   - `code = rate_limited`;
   - `errors = {}`.
7. With production-safe debug behavior, an unexpected API failure returns:
   - HTTP 500;
   - `code = server_error`;
   - `errors = {}`;
   - no stack trace or sensitive exception detail.
8. No generated default `/api/user` endpoint remains as a public TestLabUz
   endpoint.
9. The expected API prefix is `/api/v1`.

Tests may register test-only routes within the test environment to exercise
framework exception behavior. Do not add production-only fake endpoints for
tests.

No cross-institution negative test is required in this task because no
institution-owned model/resource is implemented yet.

### 4.8 Composer / source-control quality

Commit dependency lock state required for reproducible PHP installation.

Do not commit:

- `backend/.env`;
- generated application secrets;
- credentials/tokens;
- `vendor/`;
- runtime cache/log files;
- local IDE/OS metadata.

`backend/.env.example` is allowed and expected when produced by the Laravel
application scaffold, provided it contains no real secret.

Do not change root `.gitignore` unless a concrete scaffold artifact exposes a
repository-level gap that cannot be correctly handled by the backend
`.gitignore`. Any such change must be minimal and reported.

## 5. Relevant Files

Expected change surface includes, but is not limited to, the normal Laravel
application files generated under `backend/`.

High-value paths:

| Path | Expected action | Reason |
|---|---|---|
| `backend/AGENTS.md` | Preserve | Approved backend Codex rules |
| `backend/composer.json` | Create via Laravel scaffold / API install | Backend dependencies |
| `backend/composer.lock` | Create and commit | Reproducible dependencies |
| `backend/artisan` | Create via scaffold | Laravel CLI |
| `backend/app/` | Create via scaffold; add only needed API foundation code | Laravel application |
| `backend/bootstrap/app.php` | Configure as needed | API routing/error rendering |
| `backend/config/` | Create via scaffold | Laravel configuration |
| `backend/database/` | Framework scaffold only | Actual TestLabUz identity schema belongs to `S01-BE-002` |
| `backend/routes/api.php` | Create/configure | `/api/v1` public API route file |
| `backend/routes/web.php` | Keep non-product/minimal | No Laravel product UI |
| `backend/tests/` | Create/add focused API foundation tests | Acceptance evidence |
| `backend/.env.example` | Framework baseline only; no secrets | Future runtime config |
| `backend/.gitignore` | Framework/backend hygiene | Prevent local/runtime artifacts |
| `tasks/backend/stage-01/S01-BE-001-laravel-api-scaffold-quality-foundation.md` | Create on task branch | Approved task audit trail |
| `tasks/STAGE_01_TASK_INDEX.md` | Update task lifecycle only | Stage control |

Locked `docs/01–09` must not be changed.

Do not modify `frontend/`.

Do not create Docker/PostgreSQL runtime configuration in `docker/`.

## 6. Authoritative Specification References

| Document | Exact section | Requirement used |
|---|---|---|
| `docs/06-roadmap.md` | `2.1 Vertical Development` | Stage work is delivered as one controlled capability, not an entire backend built ahead |
| `docs/06-roadmap.md` | `6. Stage 1 — Authentication and Role-Based Entry` | Current stage backend/API boundary and later authentication requirements |
| `docs/07-architecture.md` | `2.1 Backend` | Laravel REST API; backend authoritative for validation/security/business state |
| `docs/07-architecture.md` | `2.3 API Style` | Versioned JSON REST API under `/api/v1/...` |
| `docs/07-architecture.md` | `4.1 Backend Style` | Modular monolith; clear domain boundaries; no microservices |
| `docs/07-architecture.md` | `23. API Boundary Principles` | Versioning/server authority/error category rules |
| `docs/07-architecture.md` | `30. Logging Architecture` | Diagnostic logging without passwords/tokens/private sensitive content |
| `docs/07-architecture.md` | `32. Testing Architecture` | Testing is architecture; backend feature tests cover API validation/auth/authz |
| `docs/07-architecture.md` | `36. Deployment Architecture` | Separate local/testing/staging/production and no source-controlled production secrets |
| `docs/07-architecture.md` | `39. CI and Quality Gates` | Backend tests and configured style/static checks are merge gates |
| `docs/07-architecture.md` | `40. Codex Architecture Rules` | Small task, exact files/tests/non-goals, no unrelated package/refactor |
| `docs/09-api-contracts.md` | `1. API Contract Overview` | `/api/v1`, JSON transport, Sanctum bearer-token contract |
| `docs/09-api-contracts.md` | `2. General API Conventions` | Success/error envelopes and HTTP categories |
| `docs/09-api-contracts.md` | `5. Error Response Contract` | Stable machine-readable error-code vocabulary |
| `backend/AGENTS.md` | `1. Backend Baseline` | Laravel REST API, PostgreSQL, Sanctum, modular monolith |
| `backend/AGENTS.md` | `2. Recommended Backend Layering` | Create only needed directories; HTTP → application → domain → persistence flow |
| `backend/AGENTS.md` | `26. API Response Contract` | Exact API categories/envelopes and no sensitive disclosure |
| `backend/AGENTS.md` | `28. Logging` | Never log passwords/tokens/sensitive contents |
| `backend/AGENTS.md` | `29. Tests` | Feature tests cover API validation/auth/authz; cross-institution tests when applicable |
| `backend/AGENTS.md` | `30. Clean Code and Backend Quality Rules` | Focused responsibilities, stable constants, predictable exceptions, readable tests |
| `backend/AGENTS.md` | `31. Backend Completion Checklist` | Tests/style/contracts/scope must pass |
| `AGENTS.md` | Current task/Git workflow sections | Approved task branch, acceptance, delivery, and scope rules |
| `tasks/STAGE_01_TASK_INDEX.md` | `S01-BE-001` row | Approved Stage 1 decomposition and dependency order |

## 7. Relevant Business / Security Rules

No product business workflow is implemented yet.

Foundation rules that already apply:

- Laravel is the authoritative backend enforcement layer.
- Flutter-facing public API contract begins at `/api/v1`.
- Role and institution authority must never be inferred from client-selected
  values.
- API error codes are stable machine contract values.
- Sensitive details must not leak through errors/logs.
- Do not implement future Stage 1 behavior in the scaffold just because
  Laravel/Sanctum makes it convenient.
- No institution-owned data exists yet, so tenant-scoping implementation is not
  applicable in this task.

## 8. Requirements

### 8.1 Functional Requirements

1. A valid Laravel 13 application exists under `backend/`.
2. Existing `backend/AGENTS.md` remains present and unchanged.
3. No nested `.git/` exists in `backend/`.
4. Laravel Sanctum/API infrastructure is installed using Laravel's supported
   API installation path.
5. Public client API prefix is `/api/v1`.
6. No default generated `/api/user` product endpoint remains.
7. API expected errors use the locked TestLabUz JSON error envelope.
8. `errors` is always an object for error responses.
9. Framework-level stable codes implemented by this foundation use only locked
   TestLabUz codes.
10. Production-safe unexpected API errors do not expose stack traces/details.
11. Focused automated tests prove the API/error foundation.
12. Laravel tests pass.
13. Laravel Pint style check passes.
14. Composer metadata/lock state is valid and reproducible.
15. No authentication/product endpoint is implemented.
16. No real User/Institution schema implementation is performed.
17. No Docker/PostgreSQL runtime is added.
18. No Flutter change occurs.

### 8.2 Architecture / Code Organization

- Keep the framework scaffold recognizable; do not reorganize Laravel into a
  speculative custom architecture.
- Create `Actions/`, `Domain/`, `Services/`, etc. only if this task has a real
  need for a file in that location.
- Centralize API error response shaping enough to prevent duplicated envelope
  construction, but do not create a giant generic framework.
- Prefer framework-native Laravel 13 exception configuration.
- Do not place product business rules in `bootstrap/app.php`.
- Do not create repository interfaces, base services, base controllers, or
  generic "manager" classes without an actual use case.
- No microservices, queues, scheduler business jobs, cache strategy, file
  subsystem, reporting infrastructure, or event bus.

### 8.3 Security

- Never print/log/commit passwords, tokens, GitHub credentials, app keys, or
  `.env` values.
- `APP_DEBUG` must not be assumed safe for production behavior.
- Error tests must prove internal exception detail is absent from production
  API responses.
- No starter-kit registration/password-reset/authentication routes.
- No CORS/auth policy invention beyond what is required by the current locked
  contract and Laravel API scaffold.
- Do not weaken root/backend `.gitignore` secret protection.

### 8.4 Version / Dependency Safety

- Verify `php --version` satisfies Laravel 13.
- Verify Composer is available and functioning.
- Use Laravel 13 official package constraints.
- Do not install a different Laravel major version silently.
- Do not globally update Composer packages or Laravel installer as a side
  effect.
- Do not add Laravel Boost, Telescope, Horizon, Octane, Debugbar, Passport,
  Fortify, Socialite, third-party auth packages, static-analysis packages, or
  other non-required dependencies in this task.
- Laravel Sanctum is allowed/required because it is the locked authentication
  baseline.
- Laravel Pint/framework test dependencies produced by the official scaffold
  are allowed.

## 9. Acceptance Criteria

- [ ] Task work occurred on
      `task/s01-be-001-laravel-api-foundation`, not directly on `main`.
- [ ] Laravel 13 scaffold exists under `backend/`.
- [ ] `backend/AGENTS.md` is preserved.
- [ ] No nested Git repository exists.
- [ ] Sanctum/API infrastructure is installed but no TestLabUz auth endpoint is
      implemented.
- [ ] `/api/v1` is the public client API base.
- [ ] No generated `/api/user` route remains.
- [ ] API validation errors return `422 validation_failed`.
- [ ] API unauthenticated errors return `401 authentication_required`.
- [ ] API authorization errors return `403 forbidden`.
- [ ] API not-found errors return `404 resource_not_found`.
- [ ] API rate-limit errors return `429 rate_limited`.
- [ ] API unexpected server errors return `500 server_error` without sensitive
      details in production-safe mode.
- [ ] Every tested error response contains an object-valued `errors`.
- [ ] No unapproved stable public error code was invented.
- [ ] Focused API foundation tests pass.
- [ ] Full backend test suite passes.
- [ ] `vendor/bin/pint --test` passes.
- [ ] `composer validate` passes.
- [ ] Tracked dependency lock state is present.
- [ ] No `.env`, app key, credential, token, `vendor/`, or runtime log/cache
      artifact is committed.
- [ ] Locked `docs/01–09` are unchanged.
- [ ] `frontend/` is unchanged.
- [ ] No Docker/PostgreSQL runtime/CI is introduced.
- [ ] No Institution/User domain implementation, authentication flow,
      password-change flow, authorization role policy, or later-stage feature is
      introduced.

## 10. Tests and Verification

### 10.1 Preflight

At minimum:

```text
git rev-parse --show-toplevel
git status --short
git branch --show-current
git remote -v
git fetch origin
git rev-parse main
git rev-parse origin/main
php --version
composer --version
```

Before task branch creation:

- branch must be `main`;
- status must be clean;
- `main == origin/main`;
- origin URL must be the approved TestLabUz repository;
- dependency `S01-INT-002` must be `Accepted`.

### 10.2 Backend checks

Use safe equivalents appropriate to the generated Laravel 13 app:

```text
cd backend
composer validate --strict
php artisan --version
php artisan route:list
php artisan test
vendor/bin/pint --test
```

Verify route output does not expose a default `/api/user`.

Verify TestLabUz API route infrastructure uses `/api/v1`.

If `composer audit` is available and network access permits, run it and report
the result. A transient registry/network outage alone is not permission to
change dependencies.

### 10.3 Contract tests

Automated tests must assert the response status/body shape for the error
categories listed in Section 4.7.

Tests must inspect the JSON structure, not only HTTP status.

At minimum verify:

```text
message -> string
code -> expected stable string
errors -> object
```

For validation:

- field names map to arrays/lists of validation messages.

For 500:

- response does not contain exception class, trace, SQL, path, token, app key,
  or raw exception message.

### 10.4 Git/scope checks before acceptance gate

```text
git status --short
git diff --check
git diff --stat main...HEAD
git diff main...HEAD -- docs
git diff main...HEAD -- frontend
```

Before Phase 2 there must be:

- no locked docs change;
- no frontend change;
- no unexpected root infrastructure change;
- no secret-bearing tracked file.

## 11. Explicit Non-Goals

- PostgreSQL Docker/runtime setup.
- Docker Compose.
- GitHub Actions / CI configuration.
- Production/staging deployment.
- Institution migrations/schema implementation.
- Final TestLabUz User schema.
- Stage 1 seed/demo accounts.
- Login/logout/me/change-password endpoints.
- Token issuance/revocation behavior.
- Active user/institution enforcement.
- First-login password-change middleware.
- Role authorization policies.
- Flutter scaffold or UI.
- Stage 2 institution management.
- Groups/relationships/Topics/Materials/Homework/Blitz/results/reports.
- Custom auth starter kits.
- Two-factor auth/device management/SSO.
- New static-analysis dependency.
- Unrelated refactoring of task/docs infrastructure.

## 12. Stop Conditions

Stop and return a blocker instead of improvising if:

- `S01-INT-002` is not actually `Accepted`;
- local `main` is dirty or does not match `origin/main`;
- `origin` is wrong or cannot be safely verified;
- the required task branch cannot be created safely;
- PHP is below Laravel 13's minimum;
- Composer is unavailable/broken;
- Laravel 13 cannot be installed without changing global/system configuration;
- scaffolding would require overwriting/removing `backend/AGENTS.md`;
- a package/version conflict requires silent Laravel downgrade;
- locked docs conflict with the requested scaffold/error behavior;
- a correct implementation would require PostgreSQL/Docker runtime from
  `S01-INT-003`;
- a correct implementation would require User/Institution persistence from
  `S01-BE-002`;
- safe completion requires destructive Git operations, force-push, history
  rewrite, `--no-verify`, or credential exposure;
- material scope expansion is required.

## 13. Execution, Acceptance, and GitHub Delivery Workflow

### Phase 0 — Git Preflight and Task Materialization

1. Read root `AGENTS.md`.
2. Read `backend/AGENTS.md`.
3. Read the approved `S01-BE-001` contract supplied by the project owner.
4. Read only the locked sections referenced by this task.
5. Verify `S01-INT-002` is accepted.
6. Verify clean/synchronized `main`.
7. Create:
   `task/s01-be-001-laravel-api-foundation`
   from current `main`.
8. Materialize this approved task file in the planned repository path.
9. Update the Stage 1 index row to `Approved`.
10. Reconfirm scope before scaffold work.

Do not commit or push during Phase 0.

### Phase 1 — Implementation

Implement only this task.

Run all required tests, contract checks, formatting/style checks, Composer
checks, security checks, and scope checks.

Do not commit or push.

When implementation appears complete, move to Phase 2.

### Phase 2 — Read-Only Acceptance Gate

Re-read:

- this task;
- relevant locked contracts;
- root/backend `AGENTS.md`;
- complete task-branch diff.

Independently verify every acceptance criterion.

During Phase 2:

- no file edits;
- no automatic fixes;
- no staging of new changes;
- no commit;
- no push;
- no merge.

If any P1/P2 blocking or material finding exists:

```text
FINAL STATUS: NOT ACCEPTED
```

Return exact findings/evidence and stop.

Do not self-fix after the acceptance gate begins.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 passes.

1. Change this task status from `Approved` to `Accepted`.
2. Update its Stage 1 index row consistently:
   - Task status = `Accepted`;
   - Review status = `PASS`;
   - Delivery status should reflect completion after merge.
3. Re-run final:
   - tests if bookkeeping touched executable files unexpectedly;
   - `git diff --check`;
   - secret scan;
   - scope check.
4. Stage only this task's approved changes.
5. Create one focused commit.

Preferred commit subject:

`feat(backend): scaffold Laravel API foundation`

Commit body must include:

`Task: S01-BE-001`

6. Push the task branch to `origin`.
7. Open a Pull Request from the task branch to `main` when authenticated GitHub
   tooling permits.
8. Do not bypass branch protection or required checks.
9. Merge only when the PR is safely mergeable and all required checks pass.
10. Delete the remote task branch after successful merge if normal repository
    policy/tooling permits.
11. Synchronize local `main` with `origin/main` using fast-forward-safe
    operations.
12. Verify:
    - local `main == origin/main`;
    - final working tree clean;
    - accepted task/index bookkeeping exists on `origin/main`.

If Phase 2 passed but safe GitHub delivery cannot complete:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Do not start `S01-INT-003`.

If everything succeeds:

```text
FINAL STATUS: ACCEPTED
```

## 14. Required Codex Final Report

Return:

1. **Final status** — exactly one of:
   - `ACCEPTED`
   - `NOT ACCEPTED`
   - `DELIVERY BLOCKED`
2. **Phase 0 preflight**:
   - starting branch;
   - clean status;
   - main/origin synchronization;
   - dependency status;
   - PHP/Composer/Laravel version evidence;
   - task branch.
3. **Implementation summary**.
4. **Changed files** — grouped by scaffold, API foundation, tests, task
   bookkeeping.
5. **Acceptance gate findings** — no blocking/material findings or exact
   P1/P2/P3 findings.
6. **Acceptance criteria** — PASS/FAIL for each criterion.
7. **Tests/quality gates** — exact commands and results.
8. **API contract evidence** — tested statuses/codes/shapes.
9. **Security evidence** — secrets, debug leakage, tracked artifacts.
10. **Git delivery evidence**:
    - commit hash/subject;
    - pushed task branch;
    - PR reference if created;
    - merge result;
    - final local `main` hash;
    - final `origin/main` hash;
    - clean status.
11. **Scope confirmation** — explicit confirmation that auth/domain/PostgreSQL/
    Flutter/later features were not implemented.
12. **Manual smoke status**.
13. **Remaining risks/deviations/blockers**.

Do not start `S01-INT-003`.
