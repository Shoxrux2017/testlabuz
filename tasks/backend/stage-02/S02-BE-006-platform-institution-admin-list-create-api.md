# Codex Task: Platform Institution Admin List and Create API

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-BE-006` |
| Status | `Accepted` |
| Approved on | `2026-08-10` |
| Stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Backend / Platform Institution Admin management` |
| Priority | `High` |
| Depends on | `S02-BE-005` accepted, delivered, and present on current `origin/main` |
| Unblocks | `S02-BE-007`; `S02-FE-008` |
| Repository | `https://github.com/Shoxrux2017/testlabuz.git` |
| Target branch | `task/s02-be-006-institution-admin-list-create` |
| Execution model | One focused implementation task followed by read-only acceptance and safe GitHub delivery |

---

## Correction Cycle Addendum

| Date | Scope | Bookkeeping note |
|---|---|---|
| `2026-08-11` | GET admin-list request body rejection | Delivery-integrity verification found that `GET /api/v1/platform/institutions/{institution}/admins` accepted non-empty request bodies through Laravel's merged input. This correction cycle records the narrow fix and re-verification required before the existing `Accepted` / `PASS` / `Delivered` state remains authoritative. `S02-BE-007` remains not started. |

---

## 2. Goal

Implement the approved Platform Owner endpoints for listing and creating
Institution Admin accounts inside one path-selected Institution:

```text
GET  /api/v1/platform/institutions/{institution}/admins
POST /api/v1/platform/institutions/{institution}/admins
```

The list endpoint must return only `institution_admin` users belonging to the
selected Institution, with deterministic server-side search, status filtering,
sorting, and pagination.

The create endpoint must atomically create one active Institution Admin whose
Institution, role, creator, lifecycle state, and first-login state are derived
by Laravel rather than trusted from the client. The initial password must be
hashed and must never appear in a response or log. The accepted Stage 1
first-login gate remains authoritative: the new account can authenticate but
cannot use normal protected functionality until it changes the initial
password through the existing authenticated password-change flow.

This task is complete only when tenant binding, role integrity, creator
attribution, credential safety, list/query semantics, exact serialization,
authorization, PostgreSQL-backed tests, full regression verification,
read-only acceptance, and GitHub delivery all pass.

### Scope boundary

This task owns only Institution Admin list/create behavior. It does not:

- update an Institution Admin;
- activate or deactivate an Institution Admin;
- reset or reveal an Institution Admin password;
- email, SMS, print, generate, or otherwise distribute credentials;
- create Teacher, Student, Parent, or Platform Owner accounts;
- manage Institution learning settings, groups, relationships, or reports;
- change Institution profile or lifecycle behavior;
- add frontend UI;
- add bulk import/export, invitations, self-registration, impersonation,
  audit-report UI, custom roles, permissions, or hard deletion;
- revise locked `docs/01–09`.

---

## 3. Current Accepted Context

Treat current `origin/main` as the implementation source of truth. Inspect it
at execution time rather than relying on this preparation snapshot.

The closed Stage 1 baseline provides:

- Laravel REST API under `/api/v1` and PostgreSQL UUID persistence;
- `institutions`, `users`, `institution_settings`, and Sanctum tokens;
- one primary `UserRole` with canonical `institution_admin` value;
- globally unique `users.login_name`;
- nullable, non-unique contact `email` and `phone` in the accepted Stage 1
  database baseline;
- hashed User password casting;
- `is_active`, `must_change_password`, `last_login_at`, `deactivated_at`, and
  `created_by_user_id` fields;
- Sanctum authentication plus `active.account`, `password.changed`, and role
  middleware;
- mandatory backend first-login enforcement and the authenticated
  `/auth/change-password` flow;
- stable success/error envelopes and PostgreSQL-backed tests.

Accepted Stage 2 predecessors must additionally provide:

- `S02-BE-001`: Platform Institution list/detail patterns and Platform route
  namespace;
- `S02-BE-002`: atomic Institution creation;
- `S02-BE-003`: Institution profile mutation patterns;
- `S02-BE-004`: Institution lifecycle and access enforcement;
- `S02-BE-005`: Platform dashboard read patterns.

Reuse accepted Platform authorization, Resource, pagination, validation,
timestamp, query/action, and test patterns where they own the same concern. Do
not create parallel middleware, a second Platform API namespace, or a second
password-change system.

Preparation-time `main` contained the closed Stage 1 baseline only. Codex must
prove every predecessor is accepted and delivered before implementation. This
contract does not authorize combining missing predecessor work into this task.

---

## 4. Dependency and Stage-Control Gate

Before implementation, verify:

1. Stage 1 is `Closed` and Stage DoD is `PASS`.
2. `S02-BE-001` through `S02-BE-005` are each `Accepted`, delivered, and
   present on current `origin/main`.
3. `tasks/STAGE_02_TASK_INDEX.md` exists and matches the approved 17-task
   decomposition.
4. This detailed task exists at:

   ```text
   tasks/backend/stage-02/S02-BE-006-platform-institution-admin-list-create-api.md
   ```

5. Its status is `Approved` before implementation.
6. No conflicting Institution Admin list/create implementation exists.

If a dependency is missing, local `main` differs from `origin/main`, or current
repository evidence materially contradicts this contract, stop and report
`BLOCKED` with exact evidence. Do not repair or absorb predecessor scope.

This task may update only the truthful `S02-BE-006` lifecycle state in the
Stage 2 index. It must not approve, create contracts/prompts for, implement, or
change later tasks.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

Before editing:

1. Read root `AGENTS.md`, `backend/AGENTS.md`, and any nearer instructions.
2. Read `tasks/README.md`, `tasks/STAGE_02_TASK_INDEX.md`, and this task.
3. Read relevant accepted `S02-BE-001` through `S02-BE-005` artifacts.
4. Read only the locked sections referenced in Section 9.
5. Inspect actual routes, middleware, models, enums, migrations, Resources,
   Requests, actions/queries, factories, exceptions, tests, and error mapping.
6. Run safe synchronization checks:

   ```text
   git fetch origin
   git switch main
   git pull --ff-only origin main
   git status --short
   git rev-parse HEAD
   git rev-parse origin/main
   git remote -v
   ```

7. Confirm local `main == origin/main`, the remote is approved, and the only
   permitted worktree changes are exactly these two approved preparation files:

   ```text
   tasks/backend/stage-02/S02-BE-006-platform-institution-admin-list-create-api.md
   tasks/backend/stage-02/S02-BE-006-CODEX-PROMPT.md
   ```

   No other modified, staged, deleted, renamed, or untracked path is allowed,
   and neither preparation file may be committed on `main`.
8. Create or switch to exactly:

   ```text
   task/s02-be-006-institution-admin-list-create
   ```

9. Carry the two approved files to the task branch if needed and verify that
   the committed `main` state was not changed.
10. Use the accepted PostgreSQL-capable runtime; never substitute SQLite.
11. Do not commit or push before read-only acceptance passes.

Unrelated or unexplained changes are a blocker. Preserve user work and never
reset, discard, overwrite, or destructively clean it.

### 5.2 Route and middleware contract

Add exactly:

```text
GET  /api/v1/platform/institutions/{institution}/admins
POST /api/v1/platform/institutions/{institution}/admins
```

Both routes must use the accepted Platform Owner middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:platform_owner
```

Required behavior:

- unauthenticated requests use accepted `401 authentication_required`;
- inactive Platform Owner uses `403 user_inactive`;
- password-incomplete Platform Owner uses `403 password_change_required`;
- authenticated non-Platform-Owner roles use `403 forbidden` after their own
  active-account and Institution gates pass;
- a tenant user from an inactive Institution remains subject to accepted
  `403 institution_inactive` precedence;
- a missing/malformed Institution route identity returns the accepted
  not-found behavior without leaking another resource;
- Institution status does not prevent an authorized Platform Owner from
  listing or creating its Institution Admin accounts; inactive Institution
  access remains blocked by the accepted login/session gate until Institution
  reactivation;
- client input never decides authorization, role, Institution, or creator.

Do not add Platform Owner bypasses to ordinary tenant endpoints and do not
return HTML redirects.

### 5.3 List query contract

The list endpoint accepts only:

```text
search
status
page
per_page
sort
direction
```

Defaults:

```text
page = 1
per_page = 20
sort = full_name
direction = asc
```

Maximum `per_page` is `100`.

Allowed values:

```text
status: active | inactive
sort: full_name | login_name | created_at | updated_at
direction: asc | desc
```

Search is trimmed, case-insensitive, and searches only the selected
Institution's Institution Admin rows across:

```text
full_name
login_name
email
phone
```

Search rules:

- an empty value after trimming behaves as no search filter;
- maximum accepted search length is 254 characters;
- `%` and `_` are treated as literal user text, not uncontrolled SQL wildcard
  operators;
- all values are parameter-bound; never concatenate search input into SQL;
- search cannot inspect passwords, tokens, creator data, learning data, or
  users outside the base path/role predicate.

Status semantics:

```text
active   → is_active = true
inactive → is_active = false
```

Unknown query keys, unsupported enum/sort/direction values, invalid page
numbers, or `per_page > 100` return `422 validation_failed` with field-level
errors. Never accept `institution_id`, `role`, password flags, raw column names,
SQL expressions, arbitrary includes, or learning-data filters.

All filtering must occur in PostgreSQL before pagination. The base predicate is
always both:

```text
institution_id = path Institution id
role = institution_admin
```

No UUID supplied through another field may widen or replace path scope.

### 5.4 List ordering and pagination

Apply the requested whitelisted primary order plus deterministic UUID tie-break:

```text
<allowed sort> <direction>, id <direction>
```

For case-insensitive textual ordering, follow the accepted `S02-BE-001`
PostgreSQL pattern for both `full_name` and `login_name`. Do not interpolate
unvalidated client strings into SQL.

Use the locked pagination envelope:

```json
{
  "data": [],
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 20,
      "total": 0,
      "last_page": 1
    }
  }
}
```

Do not add `message`, links, cursors, role summaries, or Institution metrics.
An empty or beyond-last page returns `data: []` with truthful pagination meta
according to the accepted project paginator behavior.

### 5.5 Public Institution Admin resource

Each list item and the create response `data` object must serialize exactly:

```json
{
  "id": "uuid",
  "full_name": "Institution Admin",
  "login_name": "admin.school1",
  "email": null,
  "phone": "+998...",
  "is_active": true,
  "must_change_password": true,
  "last_login_at": null,
  "deactivated_at": null,
  "created_at": "2026-08-10T10:00:00Z",
  "updated_at": "2026-08-10T10:00:00Z"
}
```

Rules:

- UUIDs and accepted UTC timestamps use existing serialization patterns;
- nullable values remain JSON `null`;
- booleans remain JSON booleans;
- never return `password`, password hash, Sanctum tokens, remember token, raw
  model internals, creator account data, or unrelated Institution/user data;
- do not add `role` or `institution_id`: both are fixed by this path-scoped
  endpoint and must not become client authority;
- use explicit Resource serialization, never unrestricted model `toArray()`.

### 5.6 Create request contract

Accept exactly the locked request fields:

```json
{
  "full_name": "Institution Admin",
  "login_name": "admin.school1",
  "email": null,
  "phone": "+998...",
  "password": "initial-password"
}
```

Validation baseline:

```text
full_name: required, string, trimmed/non-empty, max 200
login_name: required, string, trimmed/non-empty, max 191, globally unique
email: nullable, valid email, max 254
phone: nullable, string, trimmed/non-empty when present, max 50
password: required, string, minimum 8, maximum 255
```

The locked documents do not define a permanent password-composition policy.
Reuse the accepted Stage 1 technical length baseline and do not invent required
uppercase/lowercase/digit/symbol rules or network-based breach lookup.

Reject every unknown key with `422 validation_failed`, including:

```text
id
institution_id
role
is_active
must_change_password
last_login_at
deactivated_at
created_by_user_id
created_at
updated_at
password_confirmation
permissions
```

The create contract uses the locked `password` field and does not require a
confirmation field. Normalize only according to accepted project input rules;
never silently lowercase or otherwise change the authentication identifier if
the accepted login contract treats it as a stored value.

### 5.7 Backend-authoritative creation

Within one focused transaction, create exactly one User with:

```text
id = server-generated UUID
institution_id = path Institution id
role = institution_admin
full_name = validated request value
login_name = validated request value
email = validated nullable request value
phone = validated nullable request value
password = secure Laravel hash of request password
is_active = true
must_change_password = true
last_login_at = null
deactivated_at = null
created_by_user_id = authenticated Platform Owner id
created_at / updated_at = server timestamps
```

The client cannot override any authoritative field. The database role /
Institution constraint and global login-name uniqueness remain defense in
depth. If concurrent requests pass application validation for the same
`login_name`, the database constraint remains authoritative: exactly one row
may be created, and each losing request must return `422 validation_failed`
with a field-level `errors.login_name` entry. Do not leak SQL, constraint
names, stack traces, or database values.

Creation must not:

- alter the selected Institution or its settings;
- deactivate or replace an existing admin;
- enforce one-admin-per-Institution (no such MVP rule is locked);
- delete, merge, or update a conflicting account;
- create a Sanctum token or log the new user in;
- send or return the initial password;
- generate a password server-side;
- mutate any other User.

### 5.8 Create success contract

Return `201 Created`:

```json
{
  "data": {
    "id": "uuid",
    "full_name": "Institution Admin",
    "login_name": "admin.school1",
    "email": null,
    "phone": "+998...",
    "is_active": true,
    "must_change_password": true,
    "last_login_at": null,
    "deactivated_at": null,
    "created_at": "2026-08-10T10:00:00Z",
    "updated_at": "2026-08-10T10:00:00Z"
  },
  "message": "Institution admin created successfully."
}
```

Use exactly top-level `data` and `message`; do not return `meta`, tokens,
credentials, or the Institution resource.

### 5.9 First-login enforcement integration

The new admin must integrate with accepted Stage 1 behavior:

1. the stored password is hashed;
2. the initial password can authenticate only if both User and Institution are
   active;
3. successful login returns `must_change_password = true`;
4. while true, normal protected routes return accepted
   `403 password_change_required`;
5. only existing `/auth/me`, `/auth/change-password`, and `/auth/logout`
   allowances remain available;
6. successful authenticated password change atomically replaces the hash and
   sets `must_change_password = false`;
7. this task does not create a separate first-login endpoint or client-side
   substitute for the backend gate.

Add focused integration/regression coverage; do not rewrite accepted auth code
unless a genuine task-owned defect blocks this contract.

### 5.10 Architecture and implementation quality

Use the narrowest project-consistent architecture, normally:

- route entries in the accepted Platform group;
- dedicated Form Requests for list and create validation;
- thin controllers;
- a focused query for the list;
- a focused transactional action/service for creation;
- one explicit Institution Admin Resource;
- existing `User`, `Institution`, `UserRole`, hashing, middleware, and envelope
  facilities;
- PostgreSQL-backed Feature tests.

Do not introduce generic repository frameworks, premature abstractions, new
packages, schema migrations, queues, events, notification providers, or
credential-delivery infrastructure.

### 5.11 Documentation and index updates

Do not edit locked `docs/01–09`.

During implementation, update only repository-local documentation directly
required by accepted task workflow, such as truthful `S02-BE-006` status,
review evidence, and current-project status if existing conventions require it.
Do not mark `S02-BE-007` or frontend work as started or accepted.

### 5.12 Relevant files and responsibility map

Inspect the accepted repository layout before choosing exact production
filenames. Expected responsibility areas are:

```text
AGENTS.md
backend/AGENTS.md
tasks/README.md
tasks/STAGE_02_TASK_INDEX.md
tasks/backend/stage-02/S02-BE-001-*.md through S02-BE-005-*.md
backend/routes/api.php or the accepted split Platform route file
backend/app/Enums/UserRole.php
backend/app/Models/Institution.php
backend/app/Models/User.php
backend/app/Http/Controllers/Api/V1/Platform/**
backend/app/Http/Requests/Api/V1/Platform/**
backend/app/Http/Resources/Api/V1/Platform/**
backend/app/Actions/Platform/** or the accepted query/action namespaces
backend/app/Support/ApiErrorResponse.php and accepted exception mapping
backend/database/factories/InstitutionFactory.php
backend/database/factories/UserFactory.php
backend/tests/Feature/Platform/**
backend/tests/Feature/Auth/**
backend/tests/Feature/Authorization/**
```

These paths are discovery guidance, not permission to create every directory
or rename accepted code. Keep routes/controllers thin, validation in focused
Requests, list behavior in a query, creation/race handling in an action, and
public fields in an explicit Resource.

The following remain protected and must not change:

```text
docs/01–09
frontend/**
docker/**
backend/database/migrations/**
backend/composer.json
backend/composer.lock
```

### 5.13 Failure and atomicity contract

Preserve the accepted centralized outcomes and middleware precedence:

```text
401 authentication_required
403 user_inactive
403 institution_inactive
403 password_change_required
403 forbidden
404 resource_not_found
422 validation_failed
500 server_error
```

List denials and validation failures perform no write. Create authentication,
authorization, route lookup, and request validation must complete before the
create transaction. A recognized global `login_name` uniqueness race is mapped
only to the field-level `422` defined above; unrelated database/application
failures must roll back and return the accepted `500 server_error` rather than
being mislabeled as validation. No failure may expose request passwords,
hashes, SQL, constraint names, stack traces, other users, or private search
values.

### 5.14 Functional requirements summary

1. Register exactly the approved GET and POST paths once.
2. Preserve the accepted four-middleware order and error precedence.
3. Bind list/create scope only from the path Institution.
4. Always constrain list rows by path Institution and
   `role = institution_admin` before filtering or pagination.
5. Enforce the exact query allowlist, defaults, limits, search escaping,
   status semantics, case-insensitive sorts, and deterministic tie-break.
6. Return the exact list Resource and `meta.pagination` envelope.
7. Accept exactly the five approved create fields and reject protected input.
8. Derive UUID, Institution, role, creator, active state, first-login flag,
   operational nulls, and timestamps on the backend.
9. Hash the initial password and never return, log, or otherwise expose it.
10. Preserve global login-name uniqueness, including the exact concurrent
    loser outcome, without making email or phone unique.
11. Create only one User row transactionally and mutate no existing record.
12. Preserve accepted first-login, inactive-User, and inactive-Institution
    behavior end to end.
13. Keep list read-only and all queries bounded, deterministic, and
    PostgreSQL-backed.
14. Add no migration, dependency, frontend, locked-doc, credential-delivery,
    learning-data, or `S02-BE-007` scope.

---

## 6. Relevant Business, Security, and Data Protection Requirements

Required negative guarantees:

1. Only active, password-complete Platform Owner can list/create admins.
2. Path Institution is the sole tenant-binding authority.
3. The list can never include another Institution, another role, or Platform
   Owner account.
4. Create cannot produce another role or Institution through malicious input.
5. Password and hash never appear in JSON, errors, logs, snapshots, or diffs.
6. Unknown and protected fields are rejected, not ignored.
7. Search and validation errors do not echo secrets.
8. Direct UUID guessing cannot expose unrelated user records.
9. No SQL/client sort injection is possible.
10. Creation is safe under concurrent duplicate `login_name` requests.
11. Institution deactivation semantics from `S02-BE-004` remain intact.
12. No Student submissions, Teacher content, scores, results, groups, settings,
    or other learning data are read or mutated.

---

## 7. Explicit Non-Goals

Do not implement:

```text
PATCH /api/v1/platform/institution-admins/{user}
POST  /api/v1/platform/institution-admins/{user}/activate
POST  /api/v1/platform/institution-admins/{user}/deactivate
password reset/reveal/credential delivery
single-admin detail endpoint
Teacher/Student/Parent account management
bulk create/import/export
invites or self-registration
custom roles/permissions
Institution learning settings
Flutter Institution Admin UI
S02-BE-007 or any later task
```

---

## 8. Required Tests and Verification

All persistence, query, uniqueness, and authentication tests must use the
accepted PostgreSQL runtime. SQLite is not an equivalent substitute.

### 8.1 Authorization and middleware precedence

Test both endpoints for:

- no token → `401 authentication_required`;
- inactive Platform Owner → `403 user_inactive`;
- password-incomplete Platform Owner → `403 password_change_required`;
- active Institution Admin, Teacher, Student, and Parent in active
  Institutions → `403 forbidden`;
- an otherwise active tenant user in an inactive Institution → accepted
  `403 institution_inactive` precedence;
- active, password-complete Platform Owner → authorized success;
- missing and malformed path Institution UUID → `404 resource_not_found` for
  the authorized actor;
- every denial creates/changes no User row and returns no protected data.

### 8.2 List scope and query contract

Test at minimum:

- only path-Institution `institution_admin` rows are returned;
- another Institution, every other role, and Platform Owner are excluded;
- an inactive target Institution remains manageable by Platform Owner;
- default `full_name ASC, id ASC` ordering and pagination;
- each allowed sort/direction and deterministic UUID tie-break;
- `full_name` and `login_name` order case-insensitively according to the
  accepted PostgreSQL pattern;
- case-insensitive search across each approved field;
- surrounding whitespace is trimmed and empty search behaves as no filter;
- `%` and `_` search as literal characters rather than wildcard expansion;
- over-254 search is rejected;
- active/inactive filter and combined search/filter/sort/pagination;
- empty and beyond-last pages;
- exact pagination keys, including `page` rather than `current_page`;
- every unknown key and every invalid page/per-page/status/sort/direction
  returns `422 validation_failed` with field errors;
- query work is bounded and N+1-free.

### 8.3 Public Resource and leakage contract

For list and create responses, prove:

- exact Resource keys, JSON booleans/nulls, and UTC timestamp serialization;
- list has only `data` and `meta.pagination` at the top level;
- create has only `data` and the exact success `message`;
- `institution_id`, `role`, creator information, password/hash, tokens,
  remember token, private model fields, and unrelated data are absent;
- validation/auth/server errors use the accepted envelope and do not echo a
  password, private search value, SQL, or constraint name.

### 8.4 Create validation and persistence

Test at minimum:

- exact valid request returns `201` and the exact envelope/message;
- nullable email/phone and duplicate contacts across accounts are allowed;
- required/type/boundary/email/password rules are enforced;
- outer whitespace normalization follows the contract;
- duplicate `login_name` in the same or another Institution returns
  `422 validation_failed` with a `login_name` error;
- every unknown/protected key is rejected rather than ignored;
- backend derives UUID, path Institution, role, creator, active state,
  first-login flag, operational nulls, and timestamps;
- password hash verifies, while plaintext is not stored, returned, logged, or
  included in failure evidence;
- `last_login_at` and `deactivated_at` start as `null`;
- existing admins are not replaced and multiple admins remain allowed;
- invalid requests create no row and mutate no existing row;
- creating for an inactive Institution is allowed but does not bypass its
  login/session restriction.

### 8.5 Concurrent login-name uniqueness

Use a deterministic repository-compatible PostgreSQL test, not timing-only
sleep assertions, to prove:

- concurrent creates for the same new `login_name` produce exactly one User;
- every losing request returns `422 validation_failed` with a field-level
  `errors.login_name` entry;
- no `500`, SQL text, constraint name, partial second User, or mutation of the
  winning User is exposed;
- concurrent creates for different login names can both succeed.

### 8.6 First-login integration

Test the created account end to end:

- initial password authenticates when both User and Institution are active;
- login/session returns `must_change_password = true`;
- an ordinary protected route is blocked with
  `403 password_change_required` while the flag is true;
- `/auth/me`, `/auth/change-password`, and `/auth/logout` retain their accepted
  onboarding behavior;
- successful password change verifies the initial password, stores the new
  hash, and clears the flag;
- after the change, the password gate no longer blocks the account while role
  authorization still applies;
- inactive Institution and individually inactive User gates still win where
  applicable.

### 8.7 Read-only, transaction, and isolation checks

- list performs no write, timestamp touch, login update, or token mutation;
- failed create rolls back completely;
- create changes only the one new User row;
- selected Institution/settings and all existing Users remain unchanged;
- another Institution and its Users remain unchanged;
- no learning/group/report data is queried or mutated;
- no production-only test route or unsafe test hook is added.

### 8.8 Regression and quality commands

Run and report actual repository-equivalent commands:

```text
php artisan route:list --path=api/v1/platform/institutions
php artisan test --filter=PlatformInstitutionAdmin
php artisan test --filter=AuthenticationSessionApiTest
php artisan test --filter=ChangePasswordApiTest
php artisan test --filter=RoleAuthorizationMiddlewareTest
php artisan test
vendor/bin/pint --test
composer validate --strict
```

Use/report the actual focused test names if different. A filter that executes
zero tests is not a pass.

Before Phase 2, run:

```text
git status --short
git diff HEAD --check
git diff HEAD --stat
git diff HEAD
git status --short -- docs frontend docker backend/database/migrations backend/composer.json backend/composer.lock
git diff HEAD -- docs frontend docker backend/database/migrations backend/composer.json backend/composer.lock
```

Protected-path status and diff output must be empty. Do not use
`git diff main...HEAD` as evidence for the pre-commit implementation: it would
omit working-tree changes. Treat `git status --short` as the complete path
inventory, inspect the full tracked change set against `HEAD`, and read every
untracked file listed by status in full without staging it. Phase 2 must
account for modified, staged, deleted, renamed, and untracked paths.

Inspect the complete change set for:

- missing middleware or route ambiguity;
- path-scope/role leakage;
- raw sort/search SQL or wildcard mistakes;
- paginator/envelope drift;
- mass assignment of authoritative fields;
- duplicate-login race leakage or accidental `500`;
- plaintext/hash/token/log exposure;
- first-login bypass;
- migration/dependency/frontend/locked-doc changes;
- implementation of `S02-BE-007` or unrelated refactoring.

---

## 9. Contract Traceability

| Source | Relevant contract |
|---|---|
| `docs/01-business-overview.md` | Platform Owner / Institution Admin responsibilities; administrator-created first-login rule |
| `docs/02-user-roles.md` | Platform Owner support for Institution Admin; tenant and desktop boundaries |
| `docs/03-features.md` | Institution Admin support/management and MVP exclusions |
| `docs/04-user-flows.md` | Institution Admin Support Flow; authentication and first-login flow |
| `docs/05-business-rules.md` | `BR-ROLE-004`–`BR-ROLE-009`; active state, first-login gate, and authorized Institution Admin creation |
| `docs/06-roadmap.md` | Stage 2 platform management and the approved Institution Admin bridge into Stage 3 |
| `docs/07-architecture.md` | Sections 4, 8–9, 23, 29, 32, and 35; layering, platform actions, auth, API, errors, tests, security |
| `docs/08-database.md` | Sections 3, 5.1, 23–28; User fields, role/Institution constraint, unique login, indexes, retention, isolation |
| `docs/09-api-contracts.md` | Sections 1–7.8, 33, and Appendices A–C; endpoint, pagination, error, ownership, and trust-boundary contracts |
| Accepted Stage 1 artifacts | Auth, first-login, identity persistence, role middleware, envelopes, tests, and closure |
| Accepted `S02-BE-001`–`S02-BE-005` | Platform route, Resource, query, mutation, lifecycle, dashboard, and delivery patterns |

This task narrows underspecified list/query/serialization details without
changing locked product behavior. If accepted predecessor contracts already
establish a compatible convention, reuse it. If a material conflict exists,
stop rather than silently reinterpret it.

---

## 10. Manual Smoke Check

Use controlled local/test data in the accepted Laravel/PostgreSQL runtime.
Never print a password, Bearer token, password hash, SQL detail, or private
production data.

1. Authenticate an active, password-complete Platform Owner.
2. Prepare two Institutions, one active and one inactive, with Institution
   Admin and non-admin fixtures in each.
3. List admins for the active Institution and verify default scope/order,
   exact Resource keys, and pagination.
4. Exercise search on name/login/email/phone, including literal `%` and `_`,
   plus status, sorting, and one combined paginated request.
5. Verify another Institution's admins and all non-admin roles never appear.
6. Create one Institution Admin with nullable contact data and verify exact
   `201` response/message plus server-owned DB values and secure hash.
7. Repeat the same `login_name` and verify `422` with zero additional rows.
8. Authenticate the new admin, verify `must_change_password = true`, and verify
   a normal protected route returns `403 password_change_required`.
9. Complete the accepted password-change flow and verify the password gate no
   longer wins while role authorization still applies.
10. Create an admin for the inactive Institution, verify Platform Owner can
    list it, and verify its login remains `403 institution_inactive`.
11. Confirm Institutions, settings, existing Users, contacts, tokens, and all
    unrelated records remained unchanged.

If this smoke cannot run, report `NOT RUN` with the exact reason; do not claim
the task is accepted.

---

## 11. Stop Conditions

Stop and report `FINAL STATUS: BLOCKED` before implementation when:

- Stage 1 closure is not PASS;
- any `S02-BE-001` through `S02-BE-005` predecessor is not Accepted and
  delivered on `origin/main`;
- local `main` is not synchronized with the approved remote;
- the worktree contains anything other than the exact two permitted
  `S02-BE-006` preparation files;
- the approved task/index is missing or materially contradictory;
- locked `docs/01–09`, applicable `AGENTS.md`, or an accepted predecessor
  conflicts with this task;
- a conflicting Institution Admin implementation already exists;
- correct implementation requires a migration, package, locked-doc revision,
  frontend change, credential-delivery decision, or `S02-BE-007` scope;
- PostgreSQL verification or safe uniqueness-race evidence cannot be run;
- unrelated user changes overlap required files and cannot be preserved;
- remote credentials, branch protection, or GitHub state prevent safe work.

Do not guess a product decision, weaken uniqueness/security behavior, rewrite
history, or destructively clean user work.

---

## 12. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git Preflight

1. Complete Sections 4 and 5.1.
2. Create/switch to the exact task branch.
3. Carry only the approved task/prompt preparation files from local `main`.
4. Confirm no preparation file was committed directly on `main`.
5. Update only the truthful `S02-BE-006` index state if needed.
6. Do not commit or push.

### Phase 1 — Implementation

Implement only this task. Run every focused/full test, quality command,
protected-path check, complete change-set review, and manual smoke check.
Do not commit or push.

### Phase 2 — Read-Only Acceptance Gate

After implementation, re-read all authorities and inspect the complete tracked
and untracked result, routes/middleware, Requests, query/action/Resource code,
transaction and race handling, schema assumptions, tests, command output,
smoke evidence, security, and non-goals.

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

- `P1`: authorization/tenant leakage, credential/secret exposure, plaintext
  password, wrong authoritative ownership/role, destructive mutation, or
  uniqueness/data-integrity blocker;
- `P2`: material query/pagination/validation/response/first-login/concurrency,
  architecture, test, verification, or scope mismatch;
- `P3`: non-blocking observation.

If any P1/P2 remains, return:

```text
FINAL STATUS: NOT ACCEPTED
```

Then stop. Do not repair findings inside the gate and do not start
`S02-BE-007`. A separate continuation may fix the same task and rerun the
complete gate.

Phase 2 succeeds only with a reported `PASS`, no P1/P2, all required checks
and manual smoke passing, and the complete scope/security review clean.
`PASS` is not yet `FINAL STATUS: ACCEPTED`.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 reports `PASS`.

1. Apply only required `S02-BE-006` task/index acceptance bookkeeping.
2. Preserve every other task's truthful state; do not implement or change the
   lifecycle state of `S02-BE-007` or any frontend task.
3. Re-run final diff/status, protected-path, secret, format, test, and integrity
   checks appropriate after bookkeeping.
4. Stage only approved files.
5. Create one focused commit with repository convention and task ID in the
   commit body.
6. Push the exact task branch without force.
7. Open a non-draft PR to `main` with scope, contracts, tests, smoke, security,
   and explicit non-goals.
8. Verify PR base/head, changed files, required checks, review, and mergeability.
9. Merge only through approved repository policy with required checks passing.
10. Synchronize local `main` from `origin/main` using fast-forward only.
11. Verify:

    ```text
    local main == origin/main
    working tree clean
    S02-BE-006 = Accepted
    review = PASS
    delivery = Delivered
    ```

If Phase 2 passed but safe delivery cannot complete, return:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Only after delivery and final synchronization succeed return:

```text
FINAL STATUS: ACCEPTED
```

Never force-push, rewrite shared history, bypass hooks/checks, modify global
Git configuration, silently replace `origin`, or delete user work.

---

## 13. Acceptance Criteria

- [ ] All dependencies and preparation-file preflight rules are proven.
- [ ] Both exact endpoints exist once in the accepted Platform route group.
- [ ] Only an active, password-complete Platform Owner can use them.
- [ ] Middleware precedence and scope-safe not-found behavior remain accepted.
- [ ] List always enforces path Institution plus `institution_admin` role.
- [ ] Search trims correctly, treats `%`/`_` literally, and never widens scope.
- [ ] Status, pagination, whitelisted case-insensitive sorting, and deterministic
      ties work in PostgreSQL.
- [ ] Unknown/invalid query keys return exact `422` field errors.
- [ ] List Resource and pagination envelope match the exact contract.
- [ ] Create accepts only the five locked fields and rejects protected input.
- [ ] Backend derives UUID, Institution, role, creator, lifecycle, first-login,
      operational timestamps/nulls, and secure password hash.
- [ ] Contacts remain non-unique while `login_name` is globally unique.
- [ ] A concurrent duplicate-login race creates one User and returns exact
      `422 errors.login_name` validation to losing requests without leakage.
- [ ] Password/plaintext/hash/token data never leaks through response, error,
      log, diff, or report evidence.
- [ ] New account is active with `must_change_password = true` and Stage 1
      first-login behavior works end to end.
- [ ] Inactive Institution behavior remains enforced without blocking Platform
      Owner management.
- [ ] Multiple Institution Admins remain allowed; no existing User is replaced.
- [ ] List is read-only and create mutates only one intended User row.
- [ ] No migration, package, docs, frontend, credential-delivery, learning, or
      `S02-BE-007` implementation scope is present.
- [ ] Focused/full PostgreSQL tests, Pint, Composer, diff, secret, and protected
      path checks pass.
- [ ] Controlled manual smoke passes with redacted evidence.
- [ ] Phase 2 inventories every tracked/untracked path and reports no P1/P2.
- [ ] GitHub delivery completes; local `main == origin/main` and tree is clean.

---

## 14. Required Final Report

Report:

1. `FINAL STATUS`: `ACCEPTED`, `NOT ACCEPTED`, `DELIVERY BLOCKED`, or
   `BLOCKED`.
2. Dependency/preflight evidence and starting SHA.
3. Exact task branch and changed files grouped by responsibility.
4. Exact list query/scope/pagination/resource behavior.
5. Exact create validation/response/persistence behavior.
6. Authorization, tenant binding, role, creator, credential, and first-login
   security evidence.
7. Duplicate-login race outcome and safe `422` evidence.
8. Focused/full test and quality commands with real results/counts.
9. Protected-path, complete tracked/untracked change-set, secret, and scope
   review results.
10. Manual smoke result.
11. Phase 2 P1/P2/P3 findings and PASS/NOT ACCEPTED verdict.
12. Commit, PR, checks, merge, final `main` SHA, and clean-tree evidence when
    delivery succeeds.
13. Explicit confirmation that `S02-BE-007` and frontend work were not
    implemented or state-mutated by this run.

If blocked, do not claim completion. State the exact blocker, evidence, safe
branch/worktree state, and next action.
