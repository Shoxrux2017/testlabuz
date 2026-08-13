# Codex Task: Stage 2 Windows Real-Stack End-to-End Verification

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-INT-001` |
| Roadmap stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Integration / Windows end-to-end verification` |
| Status | `Accepted` |
| Review status | `PASS` |
| Delivery status | `Delivered` |
| Accepted commit | `4f2c4a16f43a0958312441a9b8b3af6d2c9c84a6` |
| Main before S02-INT-001 | `31193e557c1a2be87bbe2a9deea4430c1062d4f6` |
| Pull request | `#40` |
| Merge commit | `aa223890c26bb9a5f4704c7d2efe1bd92e7786e8` |
| Depends on | `S02-BE-007 — Platform Institution Admin Update/Lifecycle API (Accepted)`; `S02-FE-009 — Platform Institution Admin Update/Lifecycle UI (Accepted)` |
| Blocks | `Stage 2 Closure Review` |

This task passed its corrected, strictly read-only Phase 2 acceptance gate on
2026-08-13. Delivery completed separately through PR #40 and does not close
Stage 2.

This is the seventeenth and final Stage 2 implementation/verification task. It
does **not** close Stage 2. A separate Stage 2 closure review must run only after
this task is `Accepted` and delivered to `origin/main`.

---

## 2. Goal

Verify the complete real Stage 2 Platform Owner vertical on Windows:

```text
Flutter Windows UI
→ Riverpod feature/session state
→ repository/data-source layer
→ Dio
→ Laravel /api/v1/platform/**
→ Sanctum and protected middleware
→ PostgreSQL testlabuz_testing
```

The accepted result must prove, through repeatable automated evidence and a
human-observable Windows smoke:

- an active, password-complete Platform Owner reaches the accepted desktop
  shell and only the approved Stage 2 navigation;
- the dashboard displays real bounded platform aggregates and recent
  Institutions without invented metrics;
- Institution list search, status/type filters, sorting, and pagination are
  server-driven and correct;
- Institution detail exposes only approved platform fields and basic user
  counts;
- Institution creation atomically initializes safe Institution settings;
- allowed Institution fields can be edited without changing protected state;
- Institution activate/deactivate commands are confirmed, idempotent, and
  preserve historical data;
- deactivated Institutions block normal Institution-user access and
  reactivation restores only otherwise-eligible access;
- Institution Admin list/create/update/activate/deactivate works only inside
  the approved Platform Owner boundary;
- administrator-created Institution Admin accounts retain the mandatory
  first-login password-change gate;
- Platform Owner API routes remain protected from all four Institution roles;
- no protected learning data, credentials, tokens, password hashes, creator
  identities, settings policies, or unrelated tenant records leak through the
  Stage 2 API/UI;
- account switching, logout, direct URLs, stale requests, and reload/restart
  cannot expose previous Platform Owner data to another session;
- accepted state remains persisted after the dedicated Laravel E2E runtime is
  restarted;
- the full backend and frontend regression/quality suites remain green;
- no Stage 3+ feature is implemented to make Stage 2 appear complete.

This task may add verification-only assets and sanitized evidence. It must not
silently repair an earlier accepted product contract during verification.

---

## 3. Current Accepted Context

Repository:

`G:\project\testlabuz`

Approved remote:

`https://github.com/Shoxrux2017/testlabuz.git`

Direct dependencies must be accepted and delivered:

```text
S02-BE-007 = Accepted
S02-FE-009 = Accepted
```

Those dependencies imply all earlier Stage 2 tasks are accepted, but Codex must
verify every row in `tasks/STAGE_02_TASK_INDEX.md` and every accepted result on
`origin/main`; implication is not evidence.

### 3.1 Accepted Stage 2 API surface

The real-stack verification covers exactly:

```text
GET   /api/v1/platform/dashboard

GET   /api/v1/platform/institutions
POST  /api/v1/platform/institutions
GET   /api/v1/platform/institutions/{institution}
PATCH /api/v1/platform/institutions/{institution}
POST  /api/v1/platform/institutions/{institution}/activate
POST  /api/v1/platform/institutions/{institution}/deactivate

GET   /api/v1/platform/institutions/{institution}/admins
POST  /api/v1/platform/institutions/{institution}/admins
PATCH /api/v1/platform/institution-admins/{user}
POST  /api/v1/platform/institution-admins/{user}/activate
POST  /api/v1/platform/institution-admins/{user}/deactivate
```

All endpoints remain under the accepted middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:platform_owner
```

### 3.2 Accepted Stage 2 Flutter surface

The accepted desktop route family is:

```text
/platform-owner
/platform-owner/institutions
/platform-owner/institutions/:institutionId
/platform-owner/institutions/:institutionId/edit
```

The Platform Owner shell navigation contains exactly:

```text
Dashboard
Institutions
```

Institution Admin management is embedded in Institution detail and introduces
no separate Stage 2 route.

### 3.3 Exact accepted public behavior

The E2E suite must consume the accepted backend as public authority. It must not
recompute counts, lifecycle rules, role eligibility, settings initialization,
or first-login state in Flutter.

Key accepted contracts include:

- dashboard Institution counts: `total`, `active`, `inactive`;
- dashboard User counts: `total`, `active`;
- at most five `recent_institutions`, ordered by `created_at DESC, id DESC`;
- Institution list/detail `user_counts.total` and `user_counts.active`;
- Institution list page sizes `20`, `50`, and `100` in the UI, with backend
  maximum `100`;
- Institution create fields: `name`, `type`, `contact_email`,
  `contact_phone`, `address`, `description`, `status`;
- Institution update fields: `name`, `type`, `contact_email`,
  `contact_phone`, `address`, `description`;
- Institution lifecycle commands have empty bodies and return the current
  server resource;
- Institution Admin create fields: `full_name`, `login_name`, `email`,
  `phone`, `password`;
- Institution Admin update fields: `full_name`, `email`, `phone`;
- new Institution Admin: `role = institution_admin`, `is_active = true`,
  `must_change_password = true`, server-derived Institution and creator;
- lifecycle commands never change login name, role, Institution, password,
  first-login state, last-login state, tokens, or historical rows.

---

## 4. Dependency and Stage-Control Gate

Before any file change or test-fixture mutation, Codex must:

1. read root `AGENTS.md`, `backend/AGENTS.md`, and `frontend/AGENTS.md`;
2. read this complete approved task and its matching execution prompt;
3. read `tasks/STAGE_02_TASK_INDEX.md` and every Stage 2 task status;
4. read the locked Stage 2 sections referenced in Section 20;
5. verify all sixteen preceding Stage 2 tasks are `Accepted`;
6. verify each accepted result is reachable from current `origin/main`;
7. verify `S02-BE-007` and `S02-FE-009` are specifically accepted and
   delivered;
8. verify no unresolved `NOT ACCEPTED`, `DELIVERY BLOCKED`, `Fix Required`, or
   equivalent Stage 2 state exists;
9. verify Stage 1 remains `Closed` and its regression baseline remains present;
10. verify the repository is clean except the two owner-prepared S02-INT-001
    files when applicable;
11. verify local `main == origin/main` after safe fetch/fast-forward-only sync;
12. create the required task branch before carrying out task work.

Required branch:

`task/s02-int-001-stage2-windows-e2e`

If the owner pre-saved only these approved preparation files:

```text
tasks/integration/stage-02/S02-INT-001-stage-02-windows-real-stack-e2e-verification.md
tasks/integration/stage-02/S02-INT-001-CODEX-PROMPT.md
```

they are the only permitted additions on local `main`. Do not commit them on
`main`; create the task branch immediately and carry them into it.

Any missing/unaccepted predecessor is a stop condition. Do not use this final
integration task to implement the missing earlier task.

---

## 5. Verification Strategy

Stage 2 verification uses four evidence layers.

### Layer A — Full backend regression

Run the complete accepted Laravel suite against PostgreSQL. This proves API
contracts, authorization, validation, lifecycle idempotency, concurrency,
transactional settings initialization, first-login enforcement, and leakage
boundaries.

### Layer B — Full Flutter regression

Run the complete accepted Flutter unit/widget suite. This proves DTO parsing,
repositories, controllers, route/session guards, view states, validation,
mutation in-flight protection, stale-response suppression, and uncertain
mutation reconciliation deterministically.

### Layer C — Real Windows integration test

Run Flutter SDK `integration_test` against a dedicated real Laravel API and
real PostgreSQL `testlabuz_testing`. The test launches the real application and
uses the accepted Dio/repository/session/router/UI layers. Mock HTTP, fake
repositories, direct controller injection, and manually constructed session
state cannot replace this layer.

### Layer D — Human-observable Windows smoke

Complete the checklist in Section 18 and record truthful owner/operator
attestation. Automated E2E does not authorize Codex to claim that a human
observed the UI.

All four layers are required. A PASS in one layer cannot erase a failure or
missing mandatory result in another.

---

## 6. Git and Runtime Preflight

Before verification assets are added:

1. verify Docker Desktop and Docker Compose are available;
2. verify the accepted Laravel/PHP container runtime is available;
3. verify PostgreSQL is healthy;
4. verify the test database is exactly `testlabuz_testing`;
5. verify the accepted Flutter/Dart SDK (including FVM when repository-owned)
   is available;
6. verify Windows desktop development and test target are available;
7. verify the existing Stage 1 `integration_test` infrastructure and dependency;
8. verify a dedicated loopback-only E2E backend port can be used;
9. record tool/runtime versions without environment dumps or secrets;
10. do not start destructive fixture work until the environment/database guards
    have been proven.

Stage 2 requires Windows E2E only because Platform Owner is desktop-only in the
locked MVP role/device model. A real Android E2E run is not part of this task.
Android unit/build regression remains required only when it is already part of
the repository's accepted final quality workflow.

If Windows integration testing cannot run, report the environment blocker. Do
not replace it with widget tests or a web/browser target.

---

## 7. Flutter Integration-Test Assets

Reuse the official Flutter SDK `integration_test` package already accepted by
Stage 1. Do not add another E2E framework or a second test runner.

Create the focused test:

```text
frontend/integration_test/stage2_platform_management_flow_test.dart
```

Small reusable support files under `frontend/integration_test/` are allowed
only when they remove real duplication and remain test-only.

Requirements:

- launch the real accepted application entrypoint;
- use the real `API_BASE_URL` configuration;
- use real secure-session behavior appropriate to the Windows test target;
- interact through visible widgets for product actions;
- allow direct HTTP only for independent postcondition/security assertions
  that cannot be observed safely through UI, using the same real backend;
- never bypass product login by injecting an authenticated provider;
- never replace repository/data source implementations with fakes;
- fail clearly when required local E2E values are absent;
- use bounded waits tied to observable application state, not long arbitrary
  sleeps;
- keep test ordering/reset explicit so one failure does not produce a false
  success in later scenarios;
- do not log request bodies containing passwords or Authorization headers.

Do not modify production UI solely to expose hidden test hooks. Stable widget
keys or semantics may be added only when they also improve accessibility or
legitimate testability without exposing protected data.

---

## 8. Dedicated E2E Database Safety

All Stage 2 E2E fixture work must use:

```text
APP_ENV=testing
DB_DATABASE=testlabuz_testing
```

Before any reset or seed operation, query the active PostgreSQL connection and
prove:

```text
current_database() = testlabuz_testing
```

The guard must fail closed for:

```text
testlabuz
any other database name
APP_ENV != testing
missing required transient E2E input
```

Never run Stage 2 fixture reset against the development database. Never
truncate the complete database merely because its name contains `testing`.

The verification must preserve accepted Stage 1 schema/constraints and must not
create a production database, production test endpoint, or public testing
server.

---

## 9. Stage 2 E2E Fixture Seeder

Create one guarded test-only seeder, for example:

```text
backend/database/seeders/Stage2E2eSeeder.php
```

Reuse an accepted Stage 1 E2E fixture support abstraction only when the
resulting ownership and cleanup boundaries stay clear. Do not widen the Stage 1
seeder into an unsafe generic database reset.

### 9.1 Environment and secret guards

The seeder must refuse to run unless Section 8 is satisfied.

Credential values must come only from transient local input, for example:

```text
STAGE2_E2E_PASSWORD
STAGE2_E2E_ADMIN_INITIAL_PASSWORD
STAGE2_E2E_ADMIN_NEW_PASSWORD
```

Exact variable names may follow an existing safe repository convention, but
their values must never be:

- committed;
- printed;
- recorded in evidence;
- written to a tracked `.env` file;
- returned by an API;
- preserved in screenshots or logs.

### 9.2 Repeatable ownership boundary

Every Stage 2 E2E record must be unmistakably test-owned, using reserved names
or identifiers such as:

```text
E2E S02 ...
e2e_s02_...
```

The seeder may reset only its own Stage 2 fixtures and directly owned dependent
rows in safe foreign-key order. It must not delete unrelated Stage 1 fixtures,
manual developer data, or future Stage 3+ records.

Repeated execution must create the same logical starting state without
duplicate login names, orphan settings, uncontrolled timestamp drift, or
unbounded row growth.

### 9.3 Required fixture world

Prepare at minimum:

- one active, password-complete Platform Owner;
- one active target Institution with settings;
- one inactive Institution with settings;
- one unaffected active control Institution;
- enough additional deterministic Institutions to prove page `1`/`2`, page
  size `20`, and stable sorting;
- Institution names/statuses/types that prove combined filters and literal
  `%`/`_` search handling;
- deterministic `created_at` values that prove the five-item recent ordering;
- enough Institution Admin rows under the target Institution to prove list
  search, active/inactive filter, sorting, pagination, and path scoping;
- at least one active password-complete Institution Admin in the target
  Institution;
- at least one inactive Institution Admin;
- at least one active Institution Admin in the inactive Institution;
- at least one active Institution Admin in the unaffected Institution;
- one non-admin Institution role target so specialized admin routes can prove
  scope-safe `404` without mutation;
- known user-count distributions for Institution list/detail/dashboard
  assertions.

All fixtures must satisfy the accepted UUID, role, Institution ownership,
login-name uniqueness, active-state, settings, and password constraints.

Do not seed learning content merely to test its absence from responses. The
response allowlists and automated leakage tests are authoritative for that
boundary.

---

## 10. Dedicated Real Backend Runtime

Run Laravel in testing mode against `testlabuz_testing` on a dedicated host
loopback port, conceptually:

```text
http://127.0.0.1:<stage2-e2e-port>/api/v1
```

Requirements:

- bind only to `127.0.0.1`, not all host interfaces;
- use a non-secret configurable port;
- do not reuse an unknown development server;
- confirm `APP_ENV=testing` and database identity from inside the serving
  runtime;
- clear only relevant framework caches when needed for a truthful testing
  runtime;
- never expose the testing backend publicly;
- never change production deployment configuration.

The evidence must record the redacted base URL/port and active database name,
not a complete environment dump.

---

## 11. Required Real Windows E2E Matrix

### 11.1 Platform Owner authentication and shell

Through the real UI:

```text
login
→ /platform-owner
→ desktop shell
→ Dashboard / Institutions navigation
```

Prove:

- no Stage 2 data is visible before authenticated `/auth/me` reconciliation;
- only accepted navigation items render;
- direct route reload preserves correct shell after server bootstrap;
- logout returns to `/login` and removes Platform Owner data from view.

### 11.2 Dashboard

With the seeded fixture world:

- open Dashboard through navigation and direct `/platform-owner` URL;
- verify real Institution `total/active/inactive` values;
- verify real User `total/active` values using accepted account-state semantics;
- verify the exact five newest Institutions and order;
- verify no fabricated chart, attention, billing, activity-event, role-count,
  learning, or health metric appears;
- verify navigation away/back or refresh does not duplicate requests or show
  another session's cached data.

Loading/error/empty/partial-empty states remain mandatory in deterministic
Flutter tests. The real E2E must prove the normal populated server state and at
least one real Retry/reload recovery when the harness can safely induce a
temporary loopback failure without corrupting mutation outcomes.

### 11.3 Institution list

Through visible controls, prove:

- default server-side ordering and page size;
- search by case-insensitive name substring;
- literal `%` and `_` behavior;
- status filter;
- type filter;
- combined search/status/type filter;
- each approved sort/direction exposed by the accepted UI;
- page-size changes for `20`, `50`, and `100`;
- Previous/Next behavior and truthful result counts;
- changing query inputs returns to the correct page;
- a late prior response cannot overwrite the newest visible query;
- clearing filters restores the unfiltered server result;
- list rows expose only approved fields.

The E2E test must not assert by reproducing the same client-side filter logic.
Expected fixture identities/order must be independently known.

### 11.4 Institution detail and not-found

Prove:

- row selection opens `/platform-owner/institutions/:institutionId`;
- a direct known UUID loads the same resource;
- public fields and `user_counts.total/active` match PostgreSQL/API authority;
- status and nullable fields render correctly;
- an unknown well-formed UUID produces the accepted safe not-found UI;
- rapid target changes cannot render the previous Institution under the new
  URL;
- users, settings, creator data, credentials, tokens, and learning data are
  absent.

### 11.5 Create Institution

Through the accepted form:

1. enter all seven allowed fields;
2. submit exactly once despite repeated click/Enter attempts;
3. receive confirmed server success;
4. return to the accepted list/detail flow;
5. verify the created server resource through detail;
6. verify list and dashboard reflect the new Institution after refresh/
   invalidation;
7. independently verify exactly one related settings row exists with:

```text
timezone = Asia/Tashkent
learning_material_max_mb = 25
student_submission_max_mb = 15
acceptable_score_difference = null
blitz_timer_start_mode = null
student_result_release_mode = null
parent_result_release_mode = null
updated_by_user_id = null
```

Verify no admin/user, token, category, or educational record is implicitly
created. Password or settings inputs must not appear in the form.

### 11.6 Edit Institution

Prove:

- edit route loads current server data;
- each of the six allowed basic fields can be changed/cleared according to its
  contract;
- the UI sends only changed allowlisted fields;
- no-change submit produces no PATCH;
- protected `status`, UUID, creator, lifecycle, settings, and count fields are
  not editable or sent;
- confirmed `200` returns to/refetches server-authoritative detail;
- list and dashboard are invalidated correctly;
- edited inactive Institution remains inactive and blocked.

### 11.7 Institution lifecycle

For both deactivate and activate:

- only the state-appropriate action is shown;
- canceling confirmation sends no mutation;
- confirming sends one body-less POST;
- repeated user input cannot issue a duplicate in-flight command;
- no optimistic status is displayed before server confirmation;
- confirmed success refreshes detail and invalidates list/dashboard;
- no-op idempotency and timestamp preservation remain covered by backend
  automated tests;
- a temporary uncertain client outcome is reconciled through safe GET without
  automatic mutation replay in deterministic frontend tests.

After Institution deactivation prove through real API/UI where applicable:

- target Institution users cannot log in (`institution_inactive`);
- an existing target-user token cannot access normal protected endpoints;
- target users, settings, tokens, profiles, roles, password state, and
  historical rows remain stored;
- another active Institution remains unaffected.

After reactivation prove:

- individually active users regain only normal eligibility;
- individually inactive users remain `user_inactive`;
- `must_change_password` state remains unchanged;
- roles, passwords, tokens, settings, and profile data remain unchanged.

### 11.8 Institution Admin list and create

Inside the selected Institution detail prove:

- list scope is always the path Institution and role `institution_admin`;
- search covers only accepted public fields;
- active/inactive filter, sorting, `20/50/100` pagination, and Previous/Next
  produce real server results;
- an admin from another Institution never appears;
- public rows contain no Institution ID, role, creator, password/hash, tokens,
  permissions, or learning data;
- create form accepts exactly `full_name`, `login_name`, `email`, `phone`, and
  `password`;
- a single confirmed submission creates exactly one active
  `institution_admin` bound server-side to the path Institution;
- the password is cleared from UI memory after success and never re-rendered,
  returned, logged, or placed in evidence;
- admin list/detail counts refresh according to the accepted invalidation
  contract;
- dashboard/list hidden data is only invalidated, not unnecessarily fetched.

Then log out and use the newly created admin through the real login UI:

```text
initial password
→ /change-password
→ normal Platform routes remain unavailable
```

Complete the accepted password-change flow using transient local values, prove
the old password fails and the new password succeeds, then restore the
Platform Owner session for remaining scenarios.

### 11.9 Institution Admin edit and lifecycle

Prove:

- edit dialog shows `login_name`, role/Institution meaning, password state,
  and first-login state only as protected/read-only context where designed;
- only `full_name`, `email`, and `phone` are submitted;
- no-change submit sends no PATCH;
- profile update preserves login name, role, Institution, password,
  `must_change_password`, `last_login_at`, tokens, and lifecycle state;
- deactivate/activate each requires confirmation and one body-less POST;
- cancellation performs no mutation;
- no optimistic row state is shown;
- list/server data refreshes after confirmed success;
- deactivated admin cannot log in or use a normal protected token;
- activation does not reset password or first-login state;
- activation while the parent Institution is inactive does not bypass
  `institution_inactive`;
- another admin and another Institution remain unchanged.

### 11.10 Authorization and disclosure

The complete accepted backend tests plus focused real requests must prove:

- unauthenticated access to every Platform route is `401`;
- active, password-complete Institution Admin, Teacher, Student, and Parent are
  each denied Platform endpoints with `403 forbidden` after applicable gates;
- inactive user, inactive Institution, and password-change middleware
  precedence remain exact;
- malformed/unknown resource targets use scope-safe `404` for authorized
  Platform Owner;
- specialized Institution Admin routes return the same safe `404` for a User
  of another role;
- unknown/protected query/body keys return `422 validation_failed` without
  mutation;
- neither API nor UI exposes protected resource existence or hidden fields.

Do not create a production debug endpoint to make assertions easier.

### 11.11 Session isolation and account switching

Prove through real UI:

```text
Platform Owner
→ load dashboard/detail/admin data
→ logout
→ Institution Admin login
```

Assert:

- Platform Owner shell and navigation are absent;
- prior KPI, Institution, and admin data are absent;
- direct Platform URLs cannot render cached protected content;
- browser/window back navigation cannot restore protected content;
- stale responses from the previous session are ignored;
- returning later as Platform Owner performs a fresh authoritative load.

### 11.12 Persistence after restart

After create/edit/lifecycle scenarios:

1. record only non-secret expected UUIDs/state in test memory/evidence;
2. stop and restart the dedicated Laravel E2E runtime safely;
3. keep PostgreSQL data intact;
4. relaunch/rebootstrap the Flutter Windows test session;
5. verify created Institution/Admin rows, edited profiles, final lifecycle
   states, settings, and counts persist;
6. verify authentication/authorization still works after restart;
7. verify no duplicated mutation was replayed during recovery.

This is persistence/restart evidence, not authorization to test production
deployment or crash recovery infrastructure.

---

## 12. Automated Backend Verification

Run the complete configured backend workflow against PostgreSQL, including at
minimum when still repository-valid:

```text
php artisan test
vendor/bin/pint --test
composer validate --strict
```

Also run any accepted configured static analysis/security command present on
`origin/main`. Do not invent an unconfigured quality tool.

The suite must include or preserve focused coverage for:

- all twelve Platform endpoints and middleware precedence;
- exact request/query allowlists and response allowlists;
- Institution search/filter/sort/pagination/counts;
- dashboard aggregates/recent ordering/empty state;
- atomic Institution + settings creation and rollback;
- Institution partial update protected-state preservation;
- Institution lifecycle idempotency, row locking, access enforcement, and
  data retention;
- Institution Admin path/role scope, search/filter/sort/pagination;
- admin creation uniqueness/concurrency and first-login gate;
- admin update/lifecycle row locking, no-op, access enforcement, and retention;
- unauthorized, wrong-role, missing-resource, validation, and failure paths;
- absence of hard-delete behavior and cross-Institution mutation/leakage;
- accepted Stage 1 regression behavior.

Any skipped, incomplete, flaky, or non-PostgreSQL substitute for a required
test is a finding, not a PASS.

---

## 13. Automated Frontend Verification

From `frontend/`, run at minimum:

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test integration_test
flutter build windows --debug
```

Also run any repository-accepted build/regression command still required by
the current `AGENTS.md`/CI configuration. Do not add a new formatter or linter.

The deterministic Flutter suite must preserve coverage for:

- all DTO/envelope/query/request mappings;
- route, role, device, first-login, and direct-URL guards;
- dashboard/list/detail loading, empty, partial-empty, error, Retry, and data
  states;
- form validation and exact changed-fields-only requests;
- lifecycle confirmations and cancellation;
- mutation in-flight duplicate suppression;
- no automatic mutation retry;
- ambiguous-outcome read-only reconciliation;
- stale response/target/session isolation;
- safe `401`, `403`, `404`, `409`, `422`, transport, timeout, and server-error
  mapping;
- accessibility/keyboard/focus behavior for the desktop UI;
- Stage 1 authentication/session regressions.

Then run the real Windows integration test against the dedicated real backend.

---

## 14. Evidence Artifact

Create only after verification begins:

```text
tasks/integration/stage-02/S02-INT-001-stage-02-e2e-evidence.md
```

The evidence must record:

- UTC date/time;
- task branch and pre-delivery base commit;
- current local/origin hashes at the appropriate phase;
- Docker, Compose, PHP, Laravel, Composer, PostgreSQL, Flutter, Dart, and
  Windows versions;
- dedicated loopback endpoint and `testlabuz_testing` identity;
- fixture guard tests and deterministic fixture summary;
- backend command names and exact pass/fail counts when available;
- frontend command names and exact pass/fail counts when available;
- every Section 11 scenario as explicit PASS/FAIL;
- API authorization/leakage matrix result;
- database settings/retention/restart evidence;
- human-observable Windows smoke attestation;
- Phase 2 findings and verdict;
- known non-blocking limitations.

Never include:

- passwords or password hints;
- bearer tokens or cookie/secure-storage contents;
- password hashes;
- private keys or credentials;
- complete request/response dumps containing sensitive input;
- full environment dumps;
- private developer-machine paths beyond the approved repository path;
- screenshots containing secrets.

The evidence file is a Stage 2 closure input. It is not the stage-closure
decision.

---

## 15. Relevant Files and Allowed Change Surface

Expected high-value verification change surface:

| Path | Expected action |
|---|---|
| `frontend/integration_test/stage2_platform_management_flow_test.dart` | Create real Windows full-stack E2E test |
| `frontend/integration_test/*` | Small shared E2E support only if genuinely required |
| `backend/database/seeders/Stage2E2eSeeder.php` | Create guarded Stage 2 testing-only fixtures |
| `backend/tests/*Stage2*E2e*` | Add focused seeder/environment/repeatability tests if needed |
| `tasks/integration/stage-02/S02-INT-001-stage-02-e2e-evidence.md` | Create sanitized evidence |
| `tasks/integration/stage-02/S02-INT-001-stage-02-windows-real-stack-e2e-verification.md` | Preserve, then lifecycle bookkeeping after PASS |
| `tasks/integration/stage-02/S02-INT-001-CODEX-PROMPT.md` | Preserve |
| `tasks/STAGE_02_TASK_INDEX.md` | Lifecycle bookkeeping only after PASS |
| `tasks/README.md` | Truthful next-action/lifecycle bookkeeping only after PASS |

Existing app/test files may be touched only when strictly required to connect
verification infrastructure without changing accepted product behavior. If a
production contract defect is discovered, stop and report it as a finding;
do not absorb a product fix into this verification task.

Locked `docs/01–09`, Stage 1 accepted contracts, and the sixteen preceding
Stage 2 detailed contracts are read-only in this task except truthful task
status/index bookkeeping expressly allowed after Phase 2 PASS.

---

## 16. Data, Security, and Scope Invariants

Verification must independently prove:

- Platform Owner authority comes from `/auth/me` and backend middleware, not
  cached Flutter role or client payload;
- Institution IDs in platform paths select targets but never authorize an
  Institution user;
- Institution Admin paths cannot escape their selected Institution;
- no mutation accepts authoritative role, Institution, status, lifecycle
  timestamp, creator, password state, or settings values from the client;
- inactive Institution and inactive User gates remain distinct;
- activation never overrides the other gate;
- first-login password requirement remains distinct and preserved;
- no normal Stage 2 hard-delete endpoint or UI exists;
- settings and historical rows survive lifecycle actions;
- existing tokens are not bulk deleted by lifecycle actions;
- password values never appear in returned data, logs, evidence, or persistent
  Flutter state;
- no N+1 or unbounded in-memory list/aggregate behavior was introduced;
- no Stage 3 Institution user-management feature beyond Institution Admin is
  present;
- no educational content or score management is exposed to Platform Owner.

---

## 17. Required Quality and Secret Checks

Before Phase 2:

```text
git status --short
git diff --check
git diff main...HEAD -- docs
```

Locked docs must remain unchanged.

Inspect the complete branch diff and generated evidence for:

- `.env` files;
- passwords and password-like fixture literals;
- access/refresh tokens;
- Authorization headers;
- password hashes;
- private keys;
- database DSNs/credentials;
- screenshots/logs containing private data;
- production test/debug endpoints;
- unsafe seed/reset code;
- unapproved packages;
- unrelated refactors;
- Stage 3+ implementation.

Run the repository's configured secret/scope checks when present. Never print a
suspected secret merely to prove that it exists.

---

## 18. Human-Observable Windows Smoke

An operator/project owner must observe the real accepted Windows application
against the dedicated Laravel/PostgreSQL stack.

Minimum checklist:

```text
Platform Owner login
→ Dashboard real KPIs/recent Institutions
→ Institutions search/filter/page navigation
→ open Institution detail
→ create and edit one E2E Institution
→ cancel, then confirm Institution lifecycle action
→ list and create one Institution Admin
→ edit that Admin
→ cancel, then confirm Admin lifecycle action
→ logout
→ verify protected Platform data is absent
```

The operator must also observe one direct URL/reload and one validation/error
recovery path without exposing credentials.

Record:

- performer as `Project owner` or another truthful role label;
- UTC date;
- Windows result per checklist group;
- any limitation or failed observation.

Do not record credentials or claim Codex personally observed a smoke executed
by the owner. Missing mandatory human-observable evidence is a P2 blocker for
this task's acceptance; it cannot be silently deferred while reporting
`ACCEPTED`.

---

## 19. Explicit Non-Goals

- Stage 2 closure decision or closure-review execution.
- Stage 3 Institution-wide Teacher/Student/Parent management.
- Groups, relationships, Topics, Materials, Homework, Blitz, submissions,
  scoring, results, reports, or learning analytics.
- Platform Owner modification of learning content or scores.
- Institution settings editing UI/API.
- Replacing Institution Admin or Teacher ownership semantics beyond the
  approved admin account management surface.
- Institution hard-delete, archive, suspend, restore, merge, transfer, or
  ownership replacement.
- Billing, plans, licenses, quotas, revenue, subscriptions, or payments.
- Support tickets, health scores, attention queues, audit activity feeds, or
  advanced statistics.
- Android real-stack Stage 2 E2E.
- Web E2E, cloud device lab, production deployment, load testing, or chaos
  testing.
- Third-party E2E framework or new state/router/network package.
- Production test users, credentials, debug endpoint, or public test server.
- Silent correction of earlier accepted backend/frontend product behavior.
- Creation of Stage 3 tasks, prompts, code, or control files.
- Creation or execution of the separate Stage 2 closure review.

---

## 20. Authoritative Specification References

| Document | Section | Governing requirement |
|---|---|---|
| `docs/06-roadmap.md` | `7. Stage 2 — Multi-Institution Platform Management` | Dashboard, Institution management/lifecycle, protected Super Admin boundary, required tests, acceptance criterion |
| `docs/06-roadmap.md` | `3. Stage Structure and Definition of Done` | Real data, permission enforcement, automated/manual tests, regression, documentation, explicit closure |
| `docs/07-architecture.md` | Authentication, authorization, Flutter, navigation, testing, local runtime sections applicable to Stage 2 | Layering, server authority, desktop boundary, real-stack testing |
| `docs/08-database.md` | Institutions, Users/Roles, Institution Settings, multi-Institution model | UUID/state/settings/ownership/history constraints |
| `docs/09-api-contracts.md` | Authentication, stable errors, Super Admin Dashboard, Institution APIs, Create Institution, Institution Admin management | Exact Stage 2 public API and client trust boundary |
| `tasks/STAGE_02_TASK_INDEX.md` | Approved task order and Stage-wide verification map | All 17 tasks, dependency state, closure boundary |
| `S02-BE-001` through `S02-BE-007` | Accepted backend contracts | Exact endpoints, middleware, query/request/response, concurrency and security |
| `S02-FE-001` through `S02-FE-009` | Accepted frontend contracts | Exact routes, UI states, forms, invalidation, session and mutation behavior |
| root/backend/frontend `AGENTS.md` | Current applicable instructions | One-task workflow, PostgreSQL, tests, quality, security, scope control |

Locked `docs/01–09` outrank task files. If an accepted Stage 2 task conflicts
with a locked document, that is a finding and this task must stop rather than
reinterpreting the product contract.

---

## 21. Stop Conditions

Stop and report if:

- any preceding Stage 2 task is not truly accepted and delivered;
- Stage 2 task/index status conflicts with repository history;
- local `main` cannot safely synchronize with `origin/main`;
- unrelated dirty state exists;
- the task branch cannot be created safely;
- Docker/PHP/PostgreSQL testing runtime is unavailable;
- active database cannot be proven exactly `testlabuz_testing`;
- the fixture reset cannot be strictly environment/database/ownership guarded;
- Windows Flutter integration test cannot run against the real stack;
- mandatory human-observable Windows smoke evidence is unavailable;
- accepted backend/frontend contracts materially disagree;
- a real scenario requires mocked HTTP or direct session injection to pass;
- a production behavior fix is required;
- Stage 3+ code is required;
- a password/token/secret would need to be committed or reported;
- a required test, build, formatting, static-analysis, or security check fails;
- P1/P2 findings remain at the read-only gate;
- safe delivery requires force push, history rewrite, destructive cleanup,
  bypassed hooks/checks, or direct production-task push to `main`.

Do not weaken real-stack, Windows, security, persistence, or manual-smoke
requirements merely to obtain PASS.

---

## 22. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git/environment preflight

1. Complete Sections 4 and 6.
2. Create/switch to `task/s02-int-001-stage2-windows-e2e`.
3. Carry only the approved task/prompt preparation files when applicable.
4. Prove the testing environment and database guards.
5. Do not commit or push.

### Phase 1 — Verification implementation and execution

1. Add only the guarded Stage 2 E2E fixtures/support.
2. Add only the real Windows integration test/support.
3. Run backend regression and quality checks.
4. Run Flutter regression, format, and build checks.
5. Seed/reset only owned fixtures.
6. Run the complete Section 11 real-stack matrix.
7. Run restart/persistence verification.
8. Complete the human-observable Windows smoke.
9. Create the sanitized evidence file.
10. Run diff, scope, and secret checks.
11. Do not commit or push.

If a product defect appears, preserve the evidence and stop. Do not edit the
accepted production contract inside this integration task.

### Phase 2 — Read-only acceptance gate

Re-read and inspect:

- this complete task and prompt;
- all applicable `AGENTS.md` files;
- locked Stage 2 specification sections;
- `tasks/STAGE_02_TASK_INDEX.md`;
- all sixteen predecessor statuses;
- complete branch diff including untracked files;
- backend and Flutter command output;
- real Windows scenario results;
- database/fixture/restart evidence;
- human-observable smoke attestation;
- sanitized evidence file;
- secret and scope checks.

Phase 2 is strictly read-only:

- no source/test/task/evidence edits;
- no auto-fix or formatter that writes;
- no fixture mutation;
- no staging;
- no commit/push/PR/merge;
- no self-fix after findings begin.

Severity:

- `P1` — authorization, tenant/data leakage, secret exposure, unsafe database
  handling, destructive lifecycle, or core real-stack failure;
- `P2` — material contract, test, state, reproducibility, persistence,
  evidence, manual-smoke, or scope mismatch;
- `P3` — non-blocking observation.

Any P1/P2 produces:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop with no GitHub delivery.

### Phase 3 — Post-PASS GitHub delivery

Only after Phase 2 PASS:

1. set this task status to `Accepted`;
2. update the Stage 2 index row to truthful `Accepted` / `PASS`, with delivery
   finalized only after merge;
3. update `tasks/README.md` so the next action is the separate Stage 2 Closure
   Review;
4. keep Stage 2 itself `In Progress`, `Verified / Not Closed`, or the exact
   existing equivalent; do **not** mark it `Closed`;
5. finalize only lifecycle/hash metadata in sanitized evidence when required;
6. rerun non-writing final diff/secret/scope checks;
7. stage only approved S02-INT-001 verification/task/bookkeeping files;
8. commit with:

```text
test(stage2): add platform management end-to-end verification
```

and body:

```text
Task: S02-INT-001
```

9. push the task branch;
10. create a PR to `main`;
11. wait for required checks and never bypass them;
12. merge only when safe and green;
13. synchronize local `main` by safe fast-forward-only operations;
14. verify local `main == origin/main` and the tree is clean;
15. do not start or execute the closure review.

If Phase 2 passes but delivery cannot safely complete:

```text
FINAL STATUS: DELIVERY BLOCKED
```

If all delivery steps succeed:

```text
FINAL STATUS: ACCEPTED
```

The next action is the separate Stage 2 Closure Review, not Stage 3.

---

## 23. Acceptance Criteria

- [ ] All sixteen predecessor tasks are `Accepted` and delivered on
  `origin/main`.
- [ ] Work occurs only on `task/s02-int-001-stage2-windows-e2e`.
- [ ] Only approved task preparation additions were carried from `main`.
- [ ] Real E2E uses `APP_ENV=testing` and exactly `testlabuz_testing`.
- [ ] Seeder refuses wrong environment, wrong database, and missing transient
  credentials.
- [ ] Seeder resets only deterministic Stage 2 E2E-owned records.
- [ ] No password/token/hash/secret is committed, logged, returned, or recorded.
- [ ] No third-party E2E framework or unapproved package is added.
- [ ] Real Flutter Windows E2E uses real Laravel/PostgreSQL and production
  client layers.
- [ ] Platform Owner login, `/auth/me`, desktop shell, navigation, reload, and
  logout pass.
- [ ] Dashboard exact aggregates and recent Institutions pass.
- [ ] Institution search/status/type/sort/pagination pass server-side.
- [ ] Institution detail, direct URL, user counts, and not-found pass.
- [ ] Institution create and atomic settings initialization pass.
- [ ] Institution edit allowlist/changed-fields/protected-state behavior passes.
- [ ] Institution activate/deactivate confirmation and server refresh pass.
- [ ] Institution lifecycle idempotency/concurrency tests pass.
- [ ] Institution-user blocking/reactivation behavior passes.
- [ ] Institution data/settings/users/tokens/history remain preserved.
- [ ] Institution Admin list scope/search/filter/sort/pagination pass.
- [ ] Institution Admin creation, password secrecy, and first-login gate pass.
- [ ] Institution Admin profile update allowlist/protected-state behavior passes.
- [ ] Institution Admin activate/deactivate and access enforcement pass.
- [ ] Wrong-role, unauthenticated, password-gated, and inactive-state denials
  pass with correct precedence.
- [ ] Scope-safe not-found and validation failures perform no mutation.
- [ ] Platform API/UI response allowlists expose no protected data.
- [ ] Platform Owner → Institution Admin account switch exposes no previous
  Platform data.
- [ ] Final state persists after dedicated Laravel runtime restart.
- [ ] Full backend tests pass on PostgreSQL.
- [ ] Backend style/validation/static checks pass.
- [ ] Flutter analyze, tests, formatting, and Windows build pass.
- [ ] Deterministic loading/error/empty/retry/stale/ambiguity tests pass.
- [ ] Human-observable Windows smoke is truthfully recorded and passes.
- [ ] Sanitized Stage 2 E2E evidence exists and is complete.
- [ ] Locked `docs/01–09` remain unchanged.
- [ ] No earlier accepted contract is silently repaired in this task.
- [ ] No Stage 3+ feature, task, or closure decision is included.
- [ ] Phase 2 finds no unresolved P1/P2.
- [ ] Accepted result is merged to `origin/main`, local `main` matches it, and
  the working tree is clean before final `ACCEPTED`.
- [ ] Stage 2 remains explicitly **not Closed** after this task.

---

## 24. Required Codex Final Report

Return exactly enough evidence to audit the result:

1. final status: `ACCEPTED`, `NOT ACCEPTED`, or `DELIVERY BLOCKED`;
2. all-sixteen-predecessor and Git preflight result;
3. environment/runtime versions and Windows target;
4. database identity and fixture safety guards;
5. verification assets created/changed;
6. backend regression/quality results with counts;
7. Flutter regression/format/build results with counts;
8. Windows E2E results for Sections 11.1–11.12;
9. Institution settings initialization/retention evidence;
10. Institution lifecycle access/reactivation evidence;
11. Institution Admin first-login/password-secrecy/lifecycle evidence;
12. authorization and protected-data disclosure matrix;
13. session/account-switch isolation result;
14. restart/persistence result;
15. human-observable Windows smoke result and truthful performer label;
16. sanitized evidence-file path;
17. Phase 2 findings grouped P1/P2/P3;
18. acceptance-criteria PASS/FAIL summary;
19. scope/secret/locked-doc evidence;
20. GitHub delivery evidence: commit, branch, PR, checks, merge, local/remote
    hashes, clean status;
21. explicit confirmation:
    `Stage 2 was NOT marked Closed by this task.`;
22. next action:
    `Run the separate Stage 2 Closure Review.`;
23. remaining blockers/deviations.

Do not start Stage 3.
Do not create or execute the Stage 2 closure review inside this task.
