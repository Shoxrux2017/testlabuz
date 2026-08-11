# Codex Task: Platform Institution Lifecycle and Access Enforcement

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-BE-004` |
| Status | `Accepted` |
| Stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Backend / platform institution lifecycle and institution-user access enforcement` |
| Priority | `High` |
| Depends on | `S02-BE-003` accepted, delivered, and present on current `origin/main` |
| Unblocks | `S02-BE-005`; later `S02-FE-007` integration |
| Repository | `https://github.com/Shoxrux2017/testlabuz.git` |
| Target branch | `task/s02-be-004-institution-lifecycle` |
| Execution model | One focused implementation task followed by read-only acceptance and safe GitHub delivery |

---

## 2. Goal

Implement the two approved Platform Owner institution lifecycle endpoints:

```text
POST /api/v1/platform/institutions/{institution}/activate
POST /api/v1/platform/institutions/{institution}/deactivate
```

Both commands must be idempotent by target state. A real state transition must
update `institutions.status` and `institutions.deactivated_at` consistently,
while a retry against the already-current state must return the current public
Institution resource with `200 OK` and perform no duplicate lifecycle write.

Institution deactivation must immediately block normal platform access for all
Institution Admin, Teacher, Student, and Parent accounts belonging to that
institution through the already accepted backend authentication and
`active.account` enforcement. Reactivation must restore eligibility only
according to each user's own active state, first-login gate, role, relationships,
and permissions.

This task is complete only when lifecycle authorization, exact transition and
retry semantics, access blocking/reactivation behavior, data retention,
explicit API serialization, PostgreSQL-backed tests, and the accepted Git
workflow all pass.

### Scope boundary

This task owns Institution lifecycle only. It does not:

- edit Institution basic-profile fields;
- create, update, activate, or deactivate individual users;
- create or manage Institution Admin accounts;
- build the Platform Owner dashboard;
- update `institution_settings`;
- revoke or delete Sanctum tokens merely because an Institution is inactive;
- add Flutter UI, confirmation dialogs, or client-side refresh behavior;
- introduce hard delete, archive, suspend, billing, audit-log, support, or
  impersonation behavior;
- add a generic Platform Owner bypass to normal institution-scoped APIs;
- change Student submissions, scores, Teacher content, or other learning data.

---

## 3. Current Accepted Context

Treat current `origin/main` as the implementation source of truth. Do not rely
on this planning snapshot where the repository can be inspected directly.

The closed Stage 1 baseline already provides:

- Laravel REST API under `/api/v1`;
- PostgreSQL runtime and UUID identity persistence;
- `institutions`, `users`, `institution_settings`, and Sanctum token storage;
- `InstitutionStatus` with `active` and `inactive` values;
- `UserRole` with `platform_owner`, `institution_admin`, `teacher`, `student`,
  and `parent`;
- Laravel Sanctum login/session behavior;
- dynamic institution-status enforcement during login and protected requests;
- `active.account`, `password.changed`, and role middleware;
- stable `403 institution_inactive`, `403 user_inactive`,
  `403 password_change_required`, and `403 forbidden` envelopes;
- logout availability after user or institution deactivation;
- PostgreSQL-backed authentication and authorization regression tests;
- accepted task/review/delivery workflow.

The accepted Institution persistence fields relevant to this task are:

```text
id                    uuid, primary key
status                varchar(20), active|inactive
deactivated_at        timestamptz, nullable
updated_at            timestamptz, not null
```

Accepted Stage 2 dependencies must provide:

- `S02-BE-001`: Platform Institution list/detail route group, authorization,
  route-model lookup, public Resources, and read tests;
- `S02-BE-002`: atomic Institution creation with valid initial lifecycle state;
- `S02-BE-003`: basic-profile update using the same namespace, protected route
  group, focused action style, and mutation resource contract.

Reuse accepted patterns when they own the same responsibility. Do not create a
second platform institution namespace, lifecycle serializer, authentication
guard, or authorization style.

---

## 4. Dependency and Stage-Control Gate

Before implementation, verify all of the following from the repository and
remote state:

1. Stage 1 is `Closed` and its closure review is `PASS`.
2. `S02-BE-001` is `Accepted`, delivered, and present on `origin/main`.
3. `S02-BE-002` is `Accepted`, delivered, and present on `origin/main`.
4. `S02-BE-003` is `Accepted`, delivered, and present on `origin/main`.
5. `tasks/STAGE_02_TASK_INDEX.md` exists and contains the approved 17-task
   Stage 2 decomposition.
6. This detailed task exists at:

   ```text
   tasks/backend/stage-02/S02-BE-004-platform-institution-lifecycle-access-enforcement.md
   ```

7. The task status is `Approved` before implementation begins.
8. No conflicting lifecycle implementation is already present.

If any dependency is not accepted/delivered, if `main` is not synchronized, or
if repository state contradicts this task, stop and report `BLOCKED` with exact
evidence. The only permitted preparation-time worktree changes are the exact
two approved `S02-BE-004` files named below; any other unexplained change is a
blocker. Do not implement on top of an unaccepted predecessor.

This task may update only the truthful `S02-BE-004` lifecycle state in the
Stage 2 index. It must not approve, create detailed contracts for, implement,
or change the state of later tasks.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

1. Read root `AGENTS.md`.
2. Read `backend/AGENTS.md` and any nearer applicable instructions.
3. Read `tasks/README.md` and `tasks/STAGE_02_TASK_INDEX.md`.
4. Read this task completely.
5. Read the accepted `S02-BE-001`, `S02-BE-002`, and `S02-BE-003` contracts
   and acceptance/delivery evidence.
6. Read only the referenced locked sections from `docs/01–09`.
7. Inspect current platform Institution routes, controllers, Resources,
   actions, model, enums, factory, migration, auth middleware/actions, error
   mapping, and focused tests.
8. Verify:

   ```text
   git fetch origin
   git switch main
   git pull --ff-only origin main
   git status --short
   git rev-parse HEAD
   git rev-parse origin/main
   git remote -v
   ```

9. Confirm the committed Git state:

   ```text
   local main == origin/main
   origin is the approved TestLabUz repository
   ```

10. The worktree must be clean except, if the project owner saved this approved
    task pair before execution, these exact two preparation files:

    ```text
    tasks/backend/stage-02/S02-BE-004-platform-institution-lifecycle-access-enforcement.md
    tasks/backend/stage-02/S02-BE-004-CODEX-PROMPT.md
    ```

    No other modified, staged, deleted, renamed, or untracked path is allowed.
    Do not commit either preparation file on `main`.

11. Create/switch to exactly:

    ```text
    task/s02-be-004-institution-lifecycle
    ```

12. Carry the two approved preparation files onto the task branch, then verify
    that `main` itself was not changed.
13. Use the accepted PostgreSQL-capable runtime. Do not substitute SQLite.
14. Do not commit or push during implementation or the read-only review.

### 5.2 Route and middleware contract

Add only these routes to the accepted Platform Owner Institution route group:

```text
POST /api/v1/platform/institutions/{institution}/activate
POST /api/v1/platform/institutions/{institution}/deactivate
```

Preserve the accepted protected middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:platform_owner
```

Required behavior:

- missing/invalid authentication returns the accepted `401` envelope;
- inactive Platform Owner returns `403 user_inactive`;
- Platform Owner with `must_change_password = true` returns
  `403 password_change_required`;
- every authenticated non-Platform-Owner role returns `403 forbidden` when
  its own account and institution gates pass;
- active, password-complete Platform Owner may activate or deactivate any
  existing institution through these explicit platform routes;
- missing or malformed target Institution UUID returns
  `404 resource_not_found` for an authorized actor;
- failure responses must not leak whether unrelated protected records exist,
  SQL details, model internals, or hidden Institution data.

Do not:

- add an ordinary institution-scoped lifecycle route;
- add a Platform Owner universal bypass to tenant queries;
- authorize from a request body, cached client role, or target Institution;
- hide authorization only in Flutter;
- return HTML redirects for API authorization failures.

### 5.3 Body-less command contract

These commands do not define client-controlled business fields.

Valid requests are either body-less or contain an empty JSON object:

```http
POST /api/v1/platform/institutions/{institution}/deactivate
Accept: application/json
```

```json
{}
```

The backend must not require or trust any of the following:

```text
status
is_active
deactivated_at
institution_id
user_id
reason
force
role
created_by_user_id
settings
```

If a non-empty JSON payload is supplied, reject it through the accepted
`422 validation_failed` contract rather than silently accepting unsupported
or protected fields. Arrays and scalar JSON roots are invalid. Validation
failure must perform no lifecycle write.

Do not introduce:

- an `Idempotency-Key` header requirement;
- a confirmation flag in the API request;
- a mandatory reason or note;
- ETag, version, `If-Match`, or optimistic-lock input;
- a client-supplied lifecycle timestamp.

UI confirmation belongs to `S02-FE-007`, not this backend command contract.

### 5.4 Exact lifecycle state machine

The only valid states are the accepted `InstitutionStatus` values:

```text
active
inactive
```

Required transitions:

| Endpoint | Current state | Required result |
|---|---|---|
| `activate` | `inactive` | Set `status = active`; set `deactivated_at = null`; update `updated_at` once |
| `activate` | `active` | Return current active resource with `200`; perform no write; preserve `updated_at` and `deactivated_at` |
| `deactivate` | `active` | Set `status = inactive`; set `deactivated_at` to one authoritative backend timestamp; update `updated_at` once |
| `deactivate` | `inactive` | Return current inactive resource with `200`; perform no write; preserve original `deactivated_at` and `updated_at` |

State rules:

- one real transition changes only `status`, `deactivated_at`, and the normal
  Eloquent-managed `updated_at`;
- a retry in the already-current state is a successful no-op;
- no-op success must not `touch()` the Institution;
- repeated deactivation must not replace the original `deactivated_at`;
- activation must clear `deactivated_at` only on the real inactive-to-active
  transition;
- `institution_already_active` and `institution_already_inactive` are not MVP
  conflict codes;
- already-current state must not return `409`;
- no extra lifecycle state such as `suspended`, `archived`, `deleted`, or
  `pending` may be added;
- the backend clock is authoritative for a new `deactivated_at` value.

### 5.5 Focused lifecycle operation and concurrency

Implement focused application operations/use cases for the two commands. A
single cohesive lifecycle service/action may expose explicit activate and
deactivate methods, or two small actions may be used if that matches the
accepted codebase pattern. Do not create a generic arbitrary-status updater.

The lifecycle operation must:

1. receive an already authorized Institution target;
2. derive the requested target state from the route/action, not request data;
3. execute the read/check/write in a database transaction;
4. lock the target Institution row while deciding whether a transition is
   needed, using the accepted PostgreSQL/Eloquent mechanism;
5. write only when the stored state differs from the target state;
6. persist one consistent `status`/`deactivated_at` pair;
7. return the refreshed/current Institution for explicit serialization.

The row lock must serialize same-Institution lifecycle commands sufficiently
to prevent stale checks from producing an inconsistent status/timestamp pair.
Do not add a distributed lock, queue, event bus, or new package.

A safe no-op may still enter the transaction and take the row lock; it must
not issue an Institution update or advance `updated_at`.

### 5.6 Institution-user access enforcement

Do not create a second access-control system. Reuse and regression-test the
accepted Stage 1 backend authorities:

- login rejects institution users whose Institution is not active;
- `active.account` checks current Institution state for protected requests;
- Platform Owner is institution-independent and remains governed by the
  Platform Owner's own account state;
- logout remains available with `auth:sanctum` after Institution deactivation.

After a successful `active → inactive` transition:

- Institution Admin, Teacher, Student, and Parent accounts belonging to the
  target Institution must fail new login with `403 institution_inactive`;
- an already-issued valid token from an otherwise active target-Institution
  user must fail normal protected access with `403 institution_inactive`;
- no new token or successful `last_login_at` update may be produced by a
  denied login;
- the user records themselves remain unchanged;
- existing Sanctum tokens remain stored and logout remains possible;
- users in every other active Institution remain unaffected.

After a successful `inactive → active` transition:

- an individually active user may regain normal eligibility according to the
  user's role, relationships, permissions, and first-login state;
- an individually inactive user must remain blocked with `403 user_inactive`;
- `must_change_password = true` must remain true and the accepted
  `password.changed` gate must still apply to normal protected endpoints;
- reactivation must not promote roles, change permissions, repair unrelated
  user data, or bypass authorization;
- preserved valid tokens may resume only the access those same users are
  otherwise authorized to use.

Do not bulk-update `users.is_active`, `users.deactivated_at`, roles,
permissions, passwords, login timestamps, or token rows as part of Institution
lifecycle.

### 5.7 Data-retention and isolation contract

A lifecycle request must preserve exactly:

```text
Institution id
name/type/contact fields/address/description
created_by_user_id and created_at
institution_settings and all setting values
all users and every user field
all Sanctum tokens except the one token intentionally deleted by a separately
invoked, accepted logout request
all relationships and historical records
all learning content, assignments, submissions, scores, results, and reports
all other Institutions and their related data
```

No record may be deleted, transferred, merged, reassigned, anonymized, or
recreated. Do not cascade lifecycle state into child rows. Institution status
is the enforcement authority.

### 5.8 Exact success responses

A real transition and a no-op retry both return HTTP `200 OK`.

Activate response:

```json
{
  "data": {
    "id": "uuid",
    "name": "Example School",
    "type": "school",
    "status": "active",
    "contact_email": "info@example.uz",
    "contact_phone": "+998...",
    "address": "Samarkand",
    "description": "Optional notes",
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-10T12:00:00Z"
  },
  "message": "Institution activated successfully."
}
```

Deactivate response:

```json
{
  "data": {
    "id": "uuid",
    "name": "Example School",
    "type": "school",
    "status": "inactive",
    "contact_email": "info@example.uz",
    "contact_phone": "+998...",
    "address": "Samarkand",
    "description": "Optional notes",
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-10T12:00:00Z"
  },
  "message": "Institution deactivated successfully."
}
```

Response rules:

- use exactly the public mutation fields above and no additional fields;
- serialize UUID and enum values as strings;
- serialize nullable public fields as JSON `null` when absent;
- serialize timestamps as RFC 3339 / ISO 8601 UTC;
- return the complete current public profile, not only lifecycle fields;
- return the endpoint-specific exact message above for both transition and
  no-op success;
- do not expose `created_by_user_id`, creator details, or `deactivated_at`;
- do not expose settings, user identities/counts, tokens, or learning data;
- do not return pagination metadata.

If accepted list/detail Resources expose different read-specific data, do not
widen lifecycle responses merely for serializer reuse. Reuse an accepted
mutation Resource only if it preserves this exact contract cleanly.

### 5.9 Failure atomicity

All authentication, authorization, and request-validation failures must occur
before persistence.

If an unexpected database/application failure occurs during a transition:

- roll back the complete transaction;
- preserve the previous consistent `status`/`deactivated_at` pair;
- return the accepted centralized `500 server_error` envelope;
- avoid SQL, constraint, stack-trace, hidden data, or token leakage;
- do not claim a successful partial transition.

Do not convert unexpected failures into `200`, `404`, or an invented
lifecycle conflict.

---

## 6. Architecture and Code Organization

### 6.1 Thin HTTP layer

Controllers must only coordinate validated request shape, authorized bound
Institution, lifecycle action, Resource, status, and message. Do not place
transaction, row-lock, or access-enforcement business logic in controllers.

### 6.2 Dedicated request boundary

Use a focused request/validation boundary or an equally explicit accepted
mechanism for the no-fields command contract. It must permit body-less/empty
object requests and reject non-empty or non-object payloads without turning
request input into lifecycle authority.

### 6.3 Focused lifecycle action

Place transaction, row lock, state comparison, and consistent field mutation
inside focused application action(s). Do not expose a generic
`setStatus($clientValue)` operation.

### 6.4 Existing access enforcement remains authoritative

Prefer no changes to accepted auth middleware/actions unless a proven defect
prevents this task. If a minimal change is necessary, preserve Stage 1 error
precedence, Platform Owner behavior, logout, and all accepted regression tests.
Do not duplicate Institution status checks in every future controller.

### 6.5 Explicit serialization

Use accepted explicit Resource patterns. Never return a raw Institution model,
relationship graph, or `$institution->toArray()` as the public contract.

### 6.6 Existing schema is sufficient

No migration is expected. The accepted schema already contains `status`,
`deactivated_at`, and `updated_at`. Do not add audit/reason/lifecycle-event
tables, token-revocation columns, or database triggers.

### 6.7 Time and testability

Use the accepted framework/backend clock so transition timestamps can be
tested deterministically. Do not trust device/client time and do not introduce
a second time format.

---

## 7. Relevant Files

Inspect actual accepted paths before editing. Expected relevant areas include:

```text
AGENTS.md
backend/AGENTS.md
tasks/README.md
tasks/STAGE_02_TASK_INDEX.md
tasks/backend/stage-02/S02-BE-001-*.md
tasks/backend/stage-02/S02-BE-002-*.md
tasks/backend/stage-02/S02-BE-003-*.md
backend/routes/api.php
backend/app/Enums/InstitutionStatus.php
backend/app/Enums/UserRole.php
backend/app/Models/Institution.php
backend/app/Models/User.php
backend/app/Http/Controllers/Api/V1/Platform/**
backend/app/Http/Requests/Api/V1/Platform/**
backend/app/Http/Resources/Api/V1/Platform/**
backend/app/Actions/Platform/**
backend/app/Http/Middleware/EnsureAccountIsActive.php
backend/app/Actions/Auth/AuthenticateUser.php
backend/app/Support/ApiErrorResponse.php
backend/database/factories/InstitutionFactory.php
backend/database/factories/UserFactory.php
backend/tests/Feature/Platform/**
backend/tests/Feature/Auth/**
backend/tests/Feature/Authorization/**
```

These are discovery guides, not permission to create every path or rename
accepted code. Follow actual `origin/main` organization.

Do not modify:

```text
docs/01–09
frontend/**
docker/**
backend/database/migrations/**
backend/composer.json
backend/composer.lock
```

unless an authority conflict makes the task `BLOCKED`; do not silently expand
scope.

---

## 8. Authoritative Specification References

| Source | Section | Binding behavior for this task |
|---|---|---|
| `docs/01-business-overview.md` | Platform Owner / Super Admin | Platform-level Institution management and lifecycle boundary |
| `docs/02-user-roles.md` | Platform Owner / Super Admin | Platform Owner may activate/deactivate Institutions without daily learning-data control |
| `docs/03-features.md` | Institution Management / Platform Owner | Active/inactive management and blocking target-Institution users |
| `docs/04-user-flows.md` | Activate Institution Flow; Deactivate Institution Flow; Institution Activation and Deactivation Flow | Confirmed lifecycle outcome, user restriction, and restoration boundary |
| `docs/05-business-rules.md` | `BR-INST-010`–`BR-INST-015`; `BR-ROLE-004`–`BR-ROLE-006` | Two states, inactive restriction, retention, reactivation by individual eligibility |
| `docs/06-roadmap.md` | Stage 2 — Institution Management / Institution Lifecycle | Stage scope, required lifecycle/access/retention tests |
| `docs/07-architecture.md` | Platform-Level Super Admin; Account / Institution Status | Explicit platform actions, idempotency by state, no tenant bypass |
| `docs/08-database.md` | Institutions; retention/deactivation rules | Existing `status`/`deactivated_at` fields and no historical deletion |
| `docs/09-api-contracts.md` | `7.6 Activate Institution`; `7.7 Deactivate Institution`; post-audit locked behaviors | Exact routes, `200`, idempotent behavior, no already-current conflicts |
| `backend/AGENTS.md` | Required Public Idempotency Contract | Lifecycle commands are state-idempotent; no public `Idempotency-Key` requirement |
| Accepted Stage 1 auth contracts and closure | Auth/account/institution gates | Stable login/session blocking, error codes, logout behavior |
| Accepted `S02-BE-001`–`S02-BE-003` | Platform Institution API foundation | Namespace, middleware, resource, action, and test patterns |

Authority order is:

```text
locked docs/01–09
→ applicable AGENTS.md
→ tasks/README.md and truthful stage index
→ this approved detailed task
→ current accepted origin/main patterns
→ execution prompt
```

If a material contradiction remains after checking the actual sources, stop as
`BLOCKED`. Do not choose product behavior by preference.

---

## 9. Relevant Business and Security Rules

1. Only an authenticated, active, password-complete `platform_owner` may use
   these endpoints.
2. Platform actions are explicit and do not create a universal tenant bypass.
3. Institution lifecycle supports only `active` and `inactive`.
4. Both commands are idempotent by state and return `200` for safe retries.
5. Real deactivation records an authoritative `deactivated_at`; real activation
   clears it.
6. No-op retries preserve timestamps and do not perform duplicate mutation.
7. Inactive Institution users cannot use normal Institution functionality.
8. Reactivation restores eligibility only according to each user's own state
   and authorization.
9. Deactivation does not mutate user accounts or revoke stored sessions.
10. Historical and related data must remain intact and tenant-isolated.
11. Lifecycle requests cannot contain client lifecycle authority.
12. Public responses expose only the approved Institution profile fields.

---

## 10. Functional Requirements

1. Add exactly two explicit POST routes.
2. Preserve accepted middleware order and error precedence.
3. Permit only authorized Platform Owner access.
4. Support body-less and empty-object requests.
5. Reject non-empty/non-object payloads with no write.
6. Derive target state from the route/action.
7. Activate inactive Institution atomically.
8. Deactivate active Institution atomically with server time.
9. Return successful no-op for already-current state.
10. Preserve no-op `updated_at` and `deactivated_at`.
11. Serialize exact public lifecycle response and message.
12. Immediately block new login for target-Institution users after deactivation.
13. Immediately block existing-token normal access after deactivation.
14. Preserve logout availability and stored tokens.
15. Restore only individually eligible access after reactivation.
16. Keep individually inactive users blocked after reactivation.
17. Preserve first-login, role, relationship, and permission gates.
18. Preserve all user, settings, history, and unrelated-Institution data.
19. Use PostgreSQL transactions/row locking for consistent same-row decisions.
20. Keep controllers thin and tests deterministic.

---

## 11. Validation and Error Contract

Use accepted centralized envelopes:

```text
401 authentication_required
403 user_inactive
403 password_change_required
403 forbidden
404 resource_not_found
422 validation_failed
500 server_error for unexpected failure
```

For Institution-user enforcement, preserve:

```text
403 institution_inactive
```

Rules:

- no already-active/already-inactive conflict code;
- no `409` for already-current lifecycle state;
- no invented lifecycle-state error;
- no raw Laravel HTML/redirect response;
- no SQL/model/token details;
- validation errors use the accepted field/error-map structure;
- authorization, lookup, validation, and persistence failures perform no write.

---

## 12. Required Automated Tests

All database-backed tests must run against the accepted PostgreSQL test
environment, never SQLite.

### 12.1 Route and authorization

Test at minimum:

1. Both exact POST routes are registered once.
2. Both routes have the accepted middleware stack/order.
3. Active, password-complete Platform Owner may call both routes.
4. No token returns `401 authentication_required`.
5. Inactive Platform Owner returns `403 user_inactive`.
6. Password-change-required Platform Owner returns
   `403 password_change_required`.
7. Active Institution Admin, Teacher, Student, and Parent actors each return
   `403 forbidden` for both routes.
8. Missing and malformed target UUID return `404 resource_not_found` for an
   authorized actor.
9. Denied requests do not change target lifecycle state.

### 12.2 Command input validation

Test at minimum:

1. No-body request succeeds.
2. Empty JSON object succeeds.
3. Every protected/unsupported key is rejected with `422` and no write.
4. Array and scalar JSON roots are rejected with `422` and no write.
5. No public `Idempotency-Key`, reason, or confirmation field is required.

### 12.3 Transition and idempotency

Test at minimum with deterministic time:

1. Inactive-to-active sets `status = active`, clears `deactivated_at`, and
   advances `updated_at` once.
2. Active-to-inactive sets `status = inactive`, stores authoritative
   `deactivated_at`, and advances `updated_at` once.
3. Activate on already-active returns `200`, preserves `deactivated_at = null`,
   and preserves the exact previous `updated_at`.
4. Deactivate on already-inactive returns `200`, preserves the original
   non-null `deactivated_at`, and preserves the exact previous `updated_at`.
5. Repeated same-state requests remain successful and stable.
6. No already-current `409` or conflict code is returned.
7. Opposite sequential transitions maintain a consistent
   `status`/`deactivated_at` pair.
8. Focused PostgreSQL concurrency/locking evidence proves that same-target
   decisions cannot write a stale inconsistent pair. Use a deterministic
   repository-compatible test; do not use timing-only sleeps.

### 12.4 Access enforcement and reactivation

Test at minimum:

1. Valid Institution Admin, Teacher, Student, and Parent credentials are each
   denied with `403 institution_inactive` after their Institution is
   deactivated.
2. Denied login creates no token and does not advance `last_login_at`.
3. A previously issued valid token returns `403 institution_inactive` on a
   normal protected endpoint while the Institution is inactive.
4. The same stored token can still use the accepted logout endpoint while the
   Institution is inactive.
5. Reactivation restores normal eligibility for an individually active user.
6. An individually inactive user remains `403 user_inactive` after Institution
   reactivation.
7. A password-change-required user remains subject to the accepted first-login
   gate after Institution reactivation.
8. Role and cross-role authorization remain enforced after reactivation.
9. Users in a different active Institution remain unaffected throughout.
10. Platform Owner's access remains independent of target Institution status.

### 12.5 Data retention and isolation

Test before/after snapshots proving:

- basic Institution fields and creator attribution are unchanged;
- settings row and every value are unchanged;
- all target-Institution user rows and fields are unchanged;
- token rows are not bulk-deleted or rewritten;
- related/historical fixture rows remain present and connected;
- Institution A lifecycle never changes Institution B or its users/data;
- no row is deleted, moved, merged, or reassigned.

Use the smallest truthful representative historical fixtures currently
available. Do not implement future learning modules merely to test retention.

### 12.6 Response contract

Test for both endpoints and both transition/no-op cases:

- exact `200` status;
- exact endpoint-specific message;
- exact public field set and values;
- correct target-state `status`;
- RFC 3339/ISO 8601 UTC timestamps;
- no `deactivated_at`, creator, settings, counts, users, tokens, or learning data;
- accepted centralized error-envelope structure and request ID behavior.

### 12.7 Regression

Run and preserve:

- accepted S02-BE-001 list/detail tests;
- accepted S02-BE-002 create tests;
- accepted S02-BE-003 update tests;
- Stage 1 login/session tests;
- active-account/institution middleware tests;
- first-login/password-change tests;
- role-authorization tests;
- full backend suite.

---

## 13. Quality Gates and Verification

Run the repository-equivalent of:

```text
php artisan route:list --path=api/v1/platform/institutions
php artisan test --filter=PlatformInstitutionLifecycle
php artisan test --filter=AuthenticationSessionApiTest
php artisan test --filter=RoleAuthorizationMiddlewareTest
php artisan test
vendor/bin/pint --test
composer validate --strict
```

Use/report actual focused test class/filter names if they differ.

Run scope checks:

```text
git status --short
git diff HEAD --check
git diff HEAD --stat
git diff HEAD
git status --short -- docs frontend docker backend/database/migrations backend/composer.json backend/composer.lock
git diff HEAD -- docs frontend docker backend/database/migrations backend/composer.json backend/composer.lock
```

Protected-path diffs must be empty.

`git diff main...HEAD` is not valid evidence for this pre-commit gate because
it omits the intended working-tree implementation. Use `git status --short` as
the complete path inventory, inspect the full tracked change set against
`HEAD`, and read every untracked file listed by status in full. Phase 2 must
account for modified, staged, deleted, renamed, and untracked files without
staging them.

Inspect the complete diff for:

- secrets or environment leakage;
- raw model serialization;
- request-controlled status/timestamps;
- non-idempotent same-state writes;
- timestamp drift on retries;
- missing transaction/row lock;
- token or user bulk mutation;
- duplicated auth enforcement;
- hidden hard delete/cascade behavior;
- tenant leakage or unrelated refactors;
- scope creep into later Stage 2 tasks.

Any required check not run must be reported as `NOT RUN` with exact reason.
Do not infer PASS from source inspection alone.

---

## 14. Manual Smoke Check

Using the accepted local PostgreSQL runtime and controlled non-production
fixtures:

1. Create/identify one active Platform Owner.
2. Create/identify one active Institution with settings, an active
   Institution user, an individually inactive user, and a preserved token for
   the active user.
3. Record Institution profile, lifecycle timestamps, settings, user rows,
   tokens, and available representative related-data identifiers.
4. Call deactivate and verify exact `200` response/message/public fields.
5. Verify database `status = inactive` and authoritative non-null
   `deactivated_at`.
6. Repeat deactivate and verify exact same `deactivated_at`/`updated_at`.
7. Verify new login and existing-token normal access return
   `403 institution_inactive` without user/token mutation.
8. Call activate and verify exact `200` response/message/public fields.
9. Verify database `status = active` and `deactivated_at = null`.
10. Repeat activate and verify `updated_at` remains unchanged.
11. Verify the active user is eligible again while the individually inactive
    user remains `403 user_inactive`.
12. Verify all recorded settings, users, tokens, history, and unrelated
    Institution data remain intact.

Use redacted evidence. Do not print passwords, bearer tokens, secrets, or
private user data. Do not use production data.

---

## 15. Explicit Non-Goals

Do not implement:

- `S02-BE-005` dashboard aggregates;
- `S02-BE-006`/`S02-BE-007` Institution Admin APIs;
- any Stage 2 Flutter task;
- profile edit or settings update behavior;
- user lifecycle operations;
- token revocation/rotation policy changes;
- lifecycle reasons, notes, events, notifications, emails, or audit logs;
- billing, subscription, license, support, suspend, archive, or impersonation;
- hard delete or restoration-from-delete;
- educational records/features not yet implemented;
- new public idempotency headers;
- migrations, packages, dependencies, queues, caches, or broad refactors;
- docs/01–09 revisions.

---

## 16. Stop Conditions

Stop and report `BLOCKED` before implementation if:

- Stage 1 closure is not PASS;
- any `S02-BE-001`–`S02-BE-003` predecessor is not Accepted/delivered;
- `origin/main` is unavailable/divergent, or the worktree contains anything
  other than the exact two permitted `S02-BE-004` preparation files;
- applicable `AGENTS.md`, locked docs, or accepted predecessor contracts
  materially conflict;
- the exact Stage 2 index/task contract is missing;
- accepted Institution Resources/routes/auth gates cannot be reused without a
  material redesign outside this task;
- the current schema lacks required lifecycle fields;
- PostgreSQL-capable test runtime is unavailable;
- unrelated user changes overlap required files and cannot be preserved safely;
- fulfilling the task would require a migration, docs rewrite, new package, or
  scope from a later task.

During implementation, an unexpected technical failure may be diagnosed and
fixed only within approved scope. During the read-only acceptance phase, do
not self-fix findings.

---

## 17. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git Preflight

1. Synchronize safely with `origin/main`.
2. Verify dependencies and clean state.
3. Create/switch to exact task branch.
4. Ensure approved task and prompt are present.
5. Confirm that neither preparation file was committed directly on `main`.
6. Update only truthful `S02-BE-004` index state if necessary.
7. Do not commit or push.

### Phase 1 — Implementation

1. Implement only this task.
2. Run focused and full verification.
3. Run protected-path/scope checks.
4. Perform the controlled smoke check.
5. Inspect the complete diff.
6. Do not commit or push.

### Phase 2 — Read-Only Acceptance Gate

After implementation is complete, re-read all authorities, predecessor
evidence, complete diff, code, tests, scope checks, and smoke evidence.

This phase is strictly read-only:

```text
no edits
no auto-fix
no staging
no commit
no push
no merge
no self-fix after findings
```

Classify findings:

- `P1`: authorization, lifecycle/data-integrity, tenant, secret, destructive,
  or access-enforcement blocker;
- `P2`: material idempotency, timestamp, response, architecture, test, or
  scope mismatch;
- `P3`: non-blocking observation.

Any remaining P1/P2 means:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop immediately. Do not fix findings inside the same acceptance gate and do
not start `S02-BE-005`.

Acceptance requires all of:

```text
no P1 findings
no P2 findings
focused tests PASS
full backend suite PASS
format/Composer checks PASS
protected-path checks clean
manual smoke PASS
task scope clean
```

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 returns PASS with no P1/P2.

1. Mark `S02-BE-004` Accepted and review PASS.
2. Preserve every other task's truthful index state.
3. Apply only necessary task/stage lifecycle bookkeeping.
4. Re-run required checks if bookkeeping changes executable behavior; otherwise
   run at least diff/status integrity checks.
5. Create one focused commit using repository convention.
6. Push exact task branch normally.
7. Open a non-draft PR to `main` with task summary, tests, smoke evidence, and
   scope statement.
8. Verify PR head/base, changed files, checks, and mergeability.
9. Merge only through the accepted repository workflow after all required
   checks pass.
10. Synchronize local `main` by fast-forward after merge.
11. Verify:

    ```text
    local main == origin/main
    working tree clean
    S02-BE-004 = Accepted
    S02-BE-005 remains not started/unapproved unless separately prepared
    ```

Never force-push, rewrite history, use `--no-verify`, modify global Git config,
or destructively clean unrelated work.

---

## 18. Acceptance Criteria

- [ ] Task began only after all three predecessors were Accepted/delivered.
- [ ] Exact activate and deactivate routes are implemented once.
- [ ] Accepted middleware order and Platform Owner-only authorization hold.
- [ ] No-body/empty-object commands work; unsupported payloads are rejected.
- [ ] Route/action, not request input, determines target state.
- [ ] Active-to-inactive transition sets server `deactivated_at` atomically.
- [ ] Inactive-to-active transition clears `deactivated_at` atomically.
- [ ] Both already-current requests return `200` without a write.
- [ ] No-op retries preserve `updated_at` and existing `deactivated_at`.
- [ ] No already-active/already-inactive conflict is introduced.
- [ ] Same-row lifecycle decisions use transaction and row lock.
- [ ] Deactivation blocks new login for all four Institution roles.
- [ ] Deactivation blocks existing-token normal protected access.
- [ ] Logout and stored-token behavior remain accepted.
- [ ] Reactivation restores only individually eligible access.
- [ ] Individually inactive and password-gated users remain restricted.
- [ ] Users, tokens, settings, history, and other Institutions are unchanged.
- [ ] Exact `200` public resources/messages are returned without leakage.
- [ ] PostgreSQL-focused concurrency/access/retention tests pass.
- [ ] Accepted predecessor/auth/authorization regressions pass.
- [ ] Full backend, Pint, Composer, diff, and scope checks pass.
- [ ] Controlled manual smoke check passes with redacted evidence.
- [ ] No migration, dependency, frontend, locked-doc, or later-task scope exists.
- [ ] Phase 2 inventories and reviews every tracked and untracked changed path;
      it does not rely on a commit-range diff that omits working-tree changes.
- [ ] Read-only acceptance reports no P1/P2.
- [ ] Accepted GitHub delivery completes and `main == origin/main` cleanly.

---

## 19. Required Codex Final Report

The final report must state:

1. `FINAL STATUS`: `ACCEPTED`, `NOT ACCEPTED`, `BLOCKED`, or
   `DELIVERY BLOCKED`.
2. Dependency/preflight evidence and starting commit SHA.
3. Exact routes and lifecycle architecture implemented.
4. Transition/no-op/timestamp behavior verified.
5. Institution-user block/reactivation behavior verified.
6. Data/token/settings/history isolation evidence.
7. Exact response/error contract evidence.
8. Focused/full tests and quality commands with real counts/results.
9. Manual smoke result or exact `NOT RUN` reason.
10. Protected-path and complete-diff scope result.
11. Changed files.
12. Branch, commit SHA, PR URL/number, merge result, and final synchronized
    `main` SHA when delivery succeeds.
13. Confirmation that no P1/P2 remains.
14. Confirmation that `S02-BE-005` was not started.

Do not claim `ACCEPTED` before the read-only gate and required GitHub delivery
both complete. If implementation passes but delivery cannot complete, use
`DELIVERY BLOCKED` with exact evidence and preserve the safe task branch.
