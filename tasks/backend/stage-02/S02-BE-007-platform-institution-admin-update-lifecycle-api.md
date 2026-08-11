# Codex Task: Platform Institution Admin Update and Lifecycle API

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-BE-007` |
| Status | `Accepted` |
| Approved on | `2026-08-10` |
| Stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Backend / Platform Institution Admin profile and account lifecycle` |
| Priority | `High` |
| Depends on | `S02-BE-006` accepted, delivered, and present on current `origin/main` |
| Sequence next | `S02-FE-001` |
| API dependency for | `S02-FE-009` |
| Repository | `https://github.com/Shoxrux2017/testlabuz.git` |
| Target branch | `task/s02-be-007-institution-admin-update-lifecycle` |
| Execution model | One focused implementation task followed by read-only acceptance and safe GitHub delivery |

---

## 2. Goal

Implement the three approved Platform Owner endpoints for maintaining an
existing Institution Admin account:

```text
PATCH /api/v1/platform/institution-admins/{user}
POST  /api/v1/platform/institution-admins/{user}/activate
POST  /api/v1/platform/institution-admins/{user}/deactivate
```

The update endpoint must edit only the approved public profile fields:

```text
full_name
email
phone
```

The lifecycle endpoints must activate or deactivate only a target whose
persisted role is `institution_admin`. Deactivation must immediately block the
target account through the accepted Stage 1 `active.account` enforcement while
preserving its Institution binding, role, password state, tokens, creator,
timestamps/history, and all related data. Reactivation restores eligibility
only when the target Institution is active and every remaining first-login,
role, device, relationship, and permission gate passes.

The client must never be able to change the target's `login_name`, password,
role, Institution, creator, first-login flag, login metadata, or lifecycle
timestamps through the profile endpoint. Platform Owner support must remain an
explicit platform action and must not become a general bypass into ordinary
institution-scoped or educational data.

This task is complete only when exact authorization, target-role integrity,
profile allowlisting, lifecycle transitions, access enforcement, retention,
concurrency behavior, explicit serialization, PostgreSQL-backed verification,
read-only acceptance, and GitHub delivery all pass.

### Scope boundary

This task owns only Institution Admin profile update and account
activate/deactivate behavior. It does not:

- list or create Institution Admin accounts;
- provide a separate Institution Admin detail endpoint;
- change or reset passwords, reveal credentials, or distribute access data;
- change `login_name`, role, Institution, creator, or `must_change_password`;
- manage Teacher, Student, Parent, or Platform Owner accounts;
- change an Institution profile, lifecycle, or settings;
- revoke/delete Sanctum tokens merely because an account is inactive;
- hard-delete, archive, merge, move, or replace a User;
- inspect or mutate groups, relationships, learning content, submissions,
  scores, results, or reports;
- add frontend UI;
- add audit-log, notification, invitation, impersonation, or bulk behavior;
- revise locked `docs/01–09`.

---

## 3. Current Accepted Context

Treat current `origin/main` at execution time as the implementation source of
truth. Do not rely on this preparation snapshot when direct repository
evidence is available.

The closed Stage 1 baseline provides:

- Laravel REST API under `/api/v1` and PostgreSQL UUID persistence;
- `institutions`, `users`, `institution_settings`, and Sanctum token storage;
- canonical `UserRole::InstitutionAdmin` / `institution_admin` identity;
- globally unique `users.login_name`;
- nullable, non-unique `email` and `phone` contact fields;
- `is_active`, `must_change_password`, `last_login_at`, `deactivated_at`, and
  `created_by_user_id` fields;
- secure password hashing and hidden password serialization;
- Sanctum authentication plus `active.account`, `password.changed`, and role
  middleware;
- dynamic inactive-User and inactive-Institution enforcement;
- mandatory first-login password-change enforcement;
- stable API success/error envelopes and PostgreSQL-backed tests.

Accepted Stage 2 predecessors must additionally provide:

- `S02-BE-001`: Platform Institution route namespace, Platform Owner
  authorization, Resource, pagination, and not-found patterns;
- `S02-BE-002`: atomic Institution creation;
- `S02-BE-003`: strict partial-update patterns;
- `S02-BE-004`: idempotent lifecycle, authoritative timestamps, row locking,
  access enforcement, token retention, and no-op behavior;
- `S02-BE-005`: Platform dashboard aggregate API;
- `S02-BE-006`: path-scoped Institution Admin list/create endpoints, explicit
  public Institution Admin Resource, profile validation conventions,
  backend-owned role/Institution/creator state, and first-login integration.

Reuse accepted routes, middleware, Form Requests, Resources, action/service
style, timestamp serialization, exception mapping, and test infrastructure
where they own the same responsibility. Do not create a second Platform
namespace, a second Institution Admin serializer, or a second authentication
or account-status system.

The accepted User fields relevant to this task are:

```text
id                     uuid, primary key
institution_id         uuid, non-null for institution_admin
role                   institution_admin
full_name              varchar(200), non-null
login_name             varchar(191), globally unique
email                  varchar(254), nullable
phone                  varchar(50), nullable
password               varchar(255), hidden hash
is_active              boolean
must_change_password   boolean
last_login_at          timestamptz, nullable
deactivated_at         timestamptz, nullable
created_by_user_id     uuid, nullable
created_at             timestamptz, non-null
updated_at             timestamptz, non-null
```

---

## 4. Dependency and Stage-Control Gate

Before implementation, verify:

1. Stage 1 is `Closed` and Stage DoD is `PASS`.
2. `S02-BE-001` through `S02-BE-006` are each `Accepted`, delivered, and
   present on current `origin/main`.
3. `tasks/STAGE_02_TASK_INDEX.md` exists and matches the approved 17-task
   decomposition.
4. This detailed task exists at:

   ```text
   tasks/backend/stage-02/S02-BE-007-platform-institution-admin-update-lifecycle-api.md
   ```

5. Its status is `Approved` before implementation.
6. No conflicting Institution Admin update/lifecycle implementation exists.

If a dependency is missing, local `main` differs from `origin/main`, or current
repository evidence materially contradicts this contract, stop and report
`FINAL STATUS: BLOCKED` with exact evidence. Do not repair or absorb
predecessor scope.

This task may update only the truthful `S02-BE-007` lifecycle state in the
Stage 2 index. It must not create, approve, implement, or change the state of
`S02-FE-001` or any later task.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

Before editing:

1. Read root `AGENTS.md`, `backend/AGENTS.md`, and any nearer instructions.
2. Read `tasks/README.md`, `tasks/STAGE_02_TASK_INDEX.md`, and this task.
3. Read accepted `S02-BE-001` through `S02-BE-006` artifacts and their
   acceptance/delivery evidence.
4. Read only the locked sections referenced in Section 10.
5. Inspect actual Platform routes, middleware, Requests, controllers,
   Resources, actions/services, models, enums, migrations, factories,
   exception mapping, and tests.
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

7. Confirm local `main == origin/main`, the remote is the approved repository,
   and the only permitted worktree changes are exactly these two approved
   preparation files:

   ```text
   tasks/backend/stage-02/S02-BE-007-platform-institution-admin-update-lifecycle-api.md
   tasks/backend/stage-02/S02-BE-007-CODEX-PROMPT.md
   ```

   No other modified, staged, deleted, renamed, or untracked path is allowed,
   and neither preparation file may be committed on `main`.
8. Create or switch to exactly:

   ```text
   task/s02-be-007-institution-admin-update-lifecycle
   ```

9. Carry the two approved files to the task branch if needed and verify that
   committed `main` was not changed.
10. Use the accepted PostgreSQL-capable runtime; never substitute SQLite.
11. Do not commit or push before the read-only acceptance gate passes.

Unrelated or unexplained changes are a blocker. Preserve user work and never
reset, discard, overwrite, or destructively clean it.

### 5.2 Route and middleware contract

Add exactly:

```text
PATCH /api/v1/platform/institution-admins/{user}
POST  /api/v1/platform/institution-admins/{user}/activate
POST  /api/v1/platform/institution-admins/{user}/deactivate
```

All three routes must use the accepted Platform Owner middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:platform_owner
```

Required behavior:

- unauthenticated requests return accepted `401 authentication_required`;
- inactive Platform Owner returns `403 user_inactive`;
- password-incomplete Platform Owner returns
  `403 password_change_required`;
- authenticated Institution Admin, Teacher, Student, and Parent actors return
  `403 forbidden` after their own active-account/Institution gates pass;
- a tenant actor from an inactive Institution remains subject to accepted
  `403 institution_inactive` precedence;
- an active, password-complete Platform Owner may manage an Institution Admin
  from any active or inactive Institution through these explicit routes;
- malformed/unknown target UUID returns accepted `404 resource_not_found`;
- a UUID belonging to `platform_owner`, `teacher`, `student`, or `parent` is
  not a valid target for these specialized routes and returns the same
  scope-safe `404 resource_not_found` without mutation;
- authorization and target-role validation never come from request input.

Do not add a Platform Owner bypass to ordinary `/institution/**` endpoints,
authorize from Flutter state, or return HTML redirects.

### 5.3 Target identity and role-integrity contract

The `{user}` path value is the only target identity. After route lookup, every
operation must verify from persisted server state:

```text
target.role = institution_admin
target.institution_id is not null
```

The routes must never accept or use any client-supplied target replacement:

```text
id
user_id
institution_admin_id
institution_id
role
login_name
```

Role mismatch must perform no update, no lifecycle transition, no timestamp
touch, and no related read/write. Do not silently reinterpret another role as
an Institution Admin and do not modify the target role to make it eligible.

The Platform Owner is platform-scoped, so these endpoints do not derive target
Institution from the actor. They use the persisted Institution binding of the
eligible target only. That explicit capability does not authorize access to
the target Institution's educational records.

### 5.4 Exact profile update request

Accept only a non-empty partial JSON object containing one or more of:

```json
{
  "full_name": "Updated Institution Admin",
  "email": "admin@example.uz",
  "phone": "+998..."
}
```

Validation:

```text
full_name: sometimes, required when present, string, non-empty after trim, max 200
email: sometimes, nullable, valid email when non-null, max 254
phone: sometimes, nullable, string, non-empty after trim when non-null, max 50
```

PATCH semantics:

- at least one approved key is required;
- omitted approved fields retain their stored values;
- `email` and `phone` may be cleared explicitly with JSON `null`;
- `full_name` may not be `null` or empty after normalization;
- use the accepted project normalization convention; do not silently alter
  email/phone semantics beyond validation and trimming;
- contact values remain non-unique in the accepted Stage 1 schema;
- an exact no-op request returns current resource with `200` and performs no
  write or `updated_at` change;
- a real profile change updates only supplied approved profile fields and the
  normal Eloquent-managed `updated_at`.

Reject an empty object, scalar/array JSON root, every unknown key, and every
protected key with accepted `422 validation_failed` and field-level errors.
Protected keys include:

```text
id
user_id
institution_id
role
login_name
password
password_confirmation
is_active
must_change_password
last_login_at
deactivated_at
created_by_user_id
created_at
updated_at
permissions
```

Do not ignore protected keys and then partially apply allowed fields. The
whole request must fail with no mutation.

### 5.5 Profile update operation and concurrency

Implement a focused update action/use case. It must:

1. receive the authenticated Platform Owner and validated bound target;
2. execute the role check and mutation in a PostgreSQL transaction;
3. lock the target User row before final role/state verification and write;
4. modify only validated `full_name`, `email`, and/or `phone` values;
5. perform no write for an exact no-op;
6. return the current/refreshed target for explicit serialization.

Profile update is allowed whether the target User is active or inactive and
whether the target Institution is active or inactive. Editing contact/profile
data must not activate the account, clear first-login state, change login
eligibility, or update `last_login_at`.

Concurrent update and lifecycle requests must serialize on the same User row
so one operation cannot overwrite unrelated current fields from the other.
Do not introduce optimistic-lock request fields, distributed locks, queues, or
new packages.

### 5.6 Body-less lifecycle request contract

Activate/deactivate requests are body-less commands. Valid requests contain no
body or an empty JSON object:

```json
{}
```

Reject a non-empty object, array, or scalar JSON root with accepted
`422 validation_failed`; no lifecycle write may occur. In particular, never
trust:

```text
is_active
status
deactivated_at
user_id
institution_id
role
reason
force
must_change_password
```

Do not require `Idempotency-Key`, confirmation, reason, ETag, version, or a
client timestamp. UI confirmation belongs to `S02-FE-009`.

### 5.7 Exact account lifecycle state machine

Required transitions:

| Endpoint | Current state | Required result |
|---|---|---|
| `activate` | inactive | Set `is_active = true`; set `deactivated_at = null`; advance `updated_at` once |
| `activate` | active | Return current active resource with `200`; perform no write; preserve `updated_at` and lifecycle fields |
| `deactivate` | active | Set `is_active = false`; set `deactivated_at` to one authoritative backend timestamp; advance `updated_at` once |
| `deactivate` | inactive | Return current inactive resource with `200`; perform no write; preserve original `deactivated_at` and `updated_at` |

Lifecycle rules:

- commands are idempotent by target state;
- a retry against the already-current state is a successful no-op, not `409`;
- no-op success must not `touch()` the User;
- repeated deactivation must not replace the original `deactivated_at`;
- activation clears `deactivated_at` only on a real inactive-to-active
  transition;
- the backend clock is authoritative for a new `deactivated_at`;
- a real transition changes only `is_active`, `deactivated_at`, and the normal
  `updated_at`;
- no state such as suspended, archived, locked, deleted, or pending is added;
- do not invent `user_already_active` or `user_already_inactive` conflict
  codes.

This idempotent narrowing is consistent with the accepted platform lifecycle
pattern and does not change the locked active/inactive User model.

### 5.8 Lifecycle operation and concurrency

Use focused application action(s), not a generic client-driven status setter.
Each lifecycle operation must:

1. receive an already authorized, eligible target identity;
2. derive target state from the route/action, never request data;
3. run in a database transaction;
4. lock the target User row;
5. re-check `role = institution_admin` after locking;
6. write only if current state differs from requested state;
7. persist one consistent `is_active`/`deactivated_at` pair;
8. return the current/refreshed target Resource.

The row lock must serialize same-target update/activate/deactivate operations.
Concurrent duplicate commands must not produce multiple timestamp changes,
flip-flop from stale reads, or mutate another account. A no-op may take a lock
but must issue no User update.

### 5.9 Access-enforcement and reactivation integration

Reuse accepted Stage 1 authorities; do not add a second account gate.

After active-to-inactive transition:

- new login for the target returns accepted `403 user_inactive`;
- an existing target token cannot use normal protected endpoints and receives
  accepted `403 user_inactive`;
- denied login creates no token and does not update `last_login_at`;
- `/auth/logout` remains available under its accepted `auth:sanctum` contract;
- existing Sanctum tokens remain stored unless the user separately logs out;
- all other Users, including other admins in the same Institution, remain
  unchanged.

After inactive-to-active transition:

- if the target Institution is active, the User may regain only the normal
  access allowed by first-login, role, device, relationship, and permission
  gates;
- if the target Institution is inactive, login/protected access remains
  blocked with accepted `403 institution_inactive`;
- `must_change_password = true` remains true and normal protected actions
  still return `403 password_change_required` after the active-account gate;
- `must_change_password = false` remains false;
- preserved valid tokens resume only otherwise-authorized access;
- activation does not create a token, update `last_login_at`, reset a
  password, or elevate permissions.

Update and lifecycle commands must be available to an authorized Platform
Owner even while the target Institution is inactive; this management access
does not grant the target Institution User normal access.

### 5.10 Data-retention and no-side-effect contract

Every update/lifecycle request must preserve:

```text
target id
target institution_id
target role
target login_name
target password hash
target must_change_password
target last_login_at
target created_by_user_id and created_at
all Sanctum tokens except a token separately deleted by accepted logout
the target Institution and institution_settings
all other Users
all groups, relationships, learning content, submissions, scores, results,
reports, and historical records
all other Institutions and their data
```

Profile update additionally preserves `is_active` and `deactivated_at`.
Lifecycle commands additionally preserve `full_name`, `email`, and `phone`.

No record may be hard-deleted, transferred, merged, reassigned, anonymized,
or recreated. No lifecycle state may cascade into related rows.

### 5.11 Exact public Institution Admin Resource

All three success responses use the exact explicit Resource already accepted
by `S02-BE-006`:

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

- UUID and timestamps use accepted serialization conventions;
- nullable values remain JSON `null`;
- booleans remain JSON booleans;
- use explicit Resource serialization, never unrestricted model `toArray()`;
- do not return `institution_id`, `role`, creator data, password/hash, tokens,
  remember token, permissions, Institution data, or learning data.

### 5.12 Exact success responses

Profile update or no-op returns `200 OK`:

```json
{
  "data": {
    "id": "uuid",
    "full_name": "Updated Institution Admin",
    "login_name": "admin.school1",
    "email": "admin@example.uz",
    "phone": "+998...",
    "is_active": true,
    "must_change_password": false,
    "last_login_at": null,
    "deactivated_at": null,
    "created_at": "2026-08-10T10:00:00Z",
    "updated_at": "2026-08-10T12:00:00Z"
  },
  "message": "Institution admin updated successfully."
}
```

Activate transition or no-op returns `200 OK` with the current Resource and:

```text
message = Institution admin activated successfully.
```

Deactivate transition or no-op returns `200 OK` with the current Resource and:

```text
message = Institution admin deactivated successfully.
```

Use exactly top-level `data` and `message`. Do not return pagination metadata,
links, lifecycle-event data, Institution data, credentials, or tokens.

### 5.13 Failure and atomicity contract

Preserve accepted centralized outcomes and middleware precedence:

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

Authentication, actor authorization, target lookup/eligibility, and request
validation must complete before mutation. Role-mismatch and validation failure
perform no write. An unexpected database/application failure must roll back
the complete operation and return accepted `500 server_error`, not partial
success or an invented validation/lifecycle conflict.

No failure may expose SQL, constraint names, stack traces, password/hash,
tokens, private contact data from another User, or target Institution data.

### 5.14 Architecture and implementation quality

Use the narrowest project-consistent architecture, normally:

- route entries in the accepted Platform group;
- focused Form Requests for update and body-less commands;
- thin controllers;
- focused transactional update/lifecycle action(s);
- accepted explicit Institution Admin Resource;
- existing `User`, `UserRole`, middleware, clock, and error facilities;
- PostgreSQL-backed Feature tests.

Do not introduce a generic repository framework, arbitrary status service,
schema migration, package, queue, event bus, notification provider, audit-log
system, or credential-management subsystem.

### 5.15 Documentation and index updates

Do not edit locked `docs/01–09`.

During implementation, update only repository-local workflow documentation
required for truthful `S02-BE-007` task/review/delivery state. Do not create or
change the state of `S02-FE-001`, `S02-FE-009`, or any later task.

### 5.16 Relevant files and responsibility map

Inspect accepted layout before choosing exact production filenames. Expected
responsibility areas are:

```text
AGENTS.md
backend/AGENTS.md
tasks/README.md
tasks/STAGE_02_TASK_INDEX.md
tasks/backend/stage-02/S02-BE-001-*.md through S02-BE-006-*.md
backend/routes/api.php or accepted split Platform route file
backend/app/Enums/UserRole.php
backend/app/Models/User.php
backend/app/Http/Controllers/Api/V1/Platform/**
backend/app/Http/Requests/Api/V1/Platform/**
backend/app/Http/Resources/Api/V1/Platform/**
backend/app/Actions/Platform/**
backend/app/Support/ApiErrorResponse.php and accepted exception mapping
backend/database/factories/UserFactory.php
backend/tests/Feature/Platform/**
backend/tests/Feature/Auth/**
backend/tests/Feature/Authorization/**
```

These paths are discovery guidance, not permission to create every directory
or rename accepted code.

The following remain protected and must not change:

```text
docs/01–09
frontend/**
docker/**
backend/database/migrations/**
backend/composer.json
backend/composer.lock
```

### 5.17 Functional requirements summary

1. Register exactly the three approved endpoints once.
2. Preserve accepted four-middleware order and error precedence.
3. Resolve target only from `{user}` and require persisted
   `role = institution_admin`.
4. Return scope-safe `404` for missing/malformed/non-admin targets with no
   mutation.
5. PATCH accepts only non-empty partial `full_name`/`email`/`phone` input.
6. Reject all unknown/protected input rather than ignoring it.
7. Preserve immutable login, role, Institution, creator, credential,
   first-login, login metadata, and lifecycle fields during profile update.
8. Implement activate/deactivate as backend-owned idempotent state commands.
9. Maintain consistent `is_active`/`deactivated_at` values and authoritative
   transition time under row locking.
10. Preserve tokens/history and reuse current active-account enforcement.
11. Reactivation never bypasses inactive-Institution or first-login gates.
12. Reuse the exact `S02-BE-006` public Resource and exact endpoint messages.
13. Serialize concurrent same-target operations without lost unrelated fields
    or duplicate lifecycle writes.
14. Add no migration, dependency, frontend, password-support, learning-data,
    or later-task scope.

---

## 6. Business, Security, and Data-Protection Requirements

Required negative guarantees:

1. Only active, password-complete Platform Owner can call the endpoints.
2. Another MVP role cannot call them even with a known target UUID.
3. A non-`institution_admin` User can never be mutated through them.
4. Request input cannot move the admin to another Institution or role.
5. Update cannot change login, password, lifecycle, first-login, or login
   metadata.
6. Lifecycle cannot change profile, credential, role, or Institution data.
7. Inactive target User remains stored with complete history and tokens.
8. Reactivation respects target Institution and first-login state.
9. Multiple Institution Admins remain supported; no last-admin or
   one-admin-per-Institution rule is invented.
10. No User or Institution hard delete occurs.
11. No Student answers/submissions, Teacher content, scores, results, groups,
    relationships, settings, or reports are read or mutated.
12. Errors/logs/evidence never expose secrets or unrelated private data.

---

## 7. Explicit Non-Goals

Do not implement:

```text
GET/POST /api/v1/platform/institutions/{institution}/admins
Institution Admin detail endpoint
password reset/change/reveal/temporary credential delivery
login_name edit
role or institution reassignment
Teacher/Student/Parent/Platform Owner management
bulk lifecycle or bulk edit
hard delete/archive/suspend/lock
invitation/self-registration/impersonation
audit-log or notification infrastructure
Institution profile/lifecycle/settings changes
frontend UI
S02-FE-001, S02-FE-009, or any later task
```

---

## 8. Required Tests and Verification

All persistence, locking, lifecycle, and authentication tests must use the
accepted PostgreSQL runtime. SQLite is not an equivalent substitute.

### 8.1 Authorization and middleware precedence

Test all three endpoints for:

- no token → `401 authentication_required`;
- inactive Platform Owner → `403 user_inactive`;
- password-incomplete Platform Owner → `403 password_change_required`;
- active Institution Admin, Teacher, Student, and Parent in active
  Institutions → `403 forbidden`;
- otherwise active tenant actor in inactive Institution → accepted
  `403 institution_inactive` precedence;
- active, password-complete Platform Owner → authorized success;
- missing/malformed target UUID → `404 resource_not_found`;
- target UUID for Platform Owner/Teacher/Student/Parent → same `404`;
- every denial returns no protected data and changes no row/timestamp/token.

### 8.2 Update validation and persistence

Test at minimum:

- each approved field individually and all together;
- partial omission preserves stored fields;
- email/phone may be cleared with `null`;
- duplicate email/phone values across accounts are allowed;
- full-name required/type/empty/max boundary behavior;
- email type/format/max and phone type/empty/max behavior;
- empty object, array/scalar root, unknown keys, and every protected key return
  `422 validation_failed` with no partial update;
- real update changes only approved submitted fields plus `updated_at`;
- exact no-op returns `200` without advancing `updated_at`;
- update works for active/inactive target Users and active/inactive target
  Institutions without changing access state;
- role, Institution, login, password hash, first-login flag, lifecycle fields,
  login metadata, creator, creation time, tokens, and related data remain
  byte/value-equivalent as applicable.

### 8.3 Lifecycle state machine

Test at minimum:

- active → inactive writes false plus one backend `deactivated_at`;
- repeat deactivate returns `200` and preserves original `deactivated_at` and
  `updated_at`;
- inactive → active writes true and clears `deactivated_at`;
- repeat activate returns `200` and preserves `updated_at`;
- body-less and `{}` requests succeed; any non-empty/object-invalid body
  returns `422` with no mutation;
- lifecycle changes no profile/credential/role/Institution/creator/login data;
- multiple admins in the same Institution remain independent;
- lifecycle for an admin in inactive Institution is manageable by Platform
  Owner but does not restore tenant access;
- no hard delete, cascade update, or token deletion occurs.

### 8.4 Access enforcement and first-login regression

Test the target end to end:

- inactive User login returns `403 user_inactive`, creates no token, and does
  not change `last_login_at`;
- existing token is blocked from ordinary protected routes with
  `403 user_inactive`;
- accepted logout behavior remains available;
- after User activation inside active Institution, normal eligibility returns;
- after User activation inside inactive Institution, accepted
  `403 institution_inactive` still wins;
- individually active User with `must_change_password = true` remains blocked
  from normal routes with `403 password_change_required` after active-account
  and Institution gates pass;
- lifecycle never clears or sets `must_change_password`;
- other Users and Institutions remain unaffected.

### 8.5 Resource and leakage contract

For every success path, prove:

- exact Resource keys and top-level `data`/`message` only;
- exact endpoint-specific message;
- correct JSON booleans/nulls and UTC timestamps;
- update/no-op and lifecycle/no-op all return current persisted state;
- no `institution_id`, role, creator, password/hash, token, permissions,
  Institution data, or learning data appears;
- errors do not expose SQL, stack traces, secrets, or private target data.

### 8.6 Concurrency and failure atomicity

Use deterministic repository-compatible PostgreSQL tests, not sleep-only
assertions, to prove:

- simultaneous duplicate deactivate commands create one real transition and
  retain one authoritative `deactivated_at`;
- simultaneous duplicate activate commands create one real transition;
- overlapping update and lifecycle operations preserve both intended final
  profile and lifecycle fields without stale overwrite;
- a simulated failure rolls back all task-owned changes;
- no failure mutates another User, Institution, settings, tokens, or learning
  data;
- no production-only test route or unsafe hook is added.

### 8.7 Regression and quality commands

Run and report actual repository-equivalent commands:

```text
php artisan route:list --path=api/v1/platform/institution-admins
php artisan test --filter=PlatformInstitutionAdminUpdateLifecycle
php artisan test --filter=PlatformInstitutionAdmin
php artisan test --filter=AuthenticationSessionApiTest
php artisan test --filter=ChangePasswordApiTest
php artisan test --filter=RoleAuthorizationMiddlewareTest
php artisan test
vendor/bin/pint --test
composer validate --strict
```

Use/report actual focused test names if different. A filter that executes zero
tests is not a pass.

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
`git diff main...HEAD` as evidence for uncommitted implementation because it
omits working-tree and untracked files. Treat `git status --short` as the
complete path inventory, inspect the full tracked change set against `HEAD`,
and read every untracked file in full without staging it.

Inspect the complete change set for:

- route/middleware omission or ambiguity;
- actor authorization or target-role bypass;
- mass assignment of protected fields;
- lifecycle timestamp/no-op drift;
- token/history deletion;
- inactive-Institution or first-login bypass;
- raw model serialization or private-data leakage;
- ineffective concurrency tests;
- migration/dependency/frontend/locked-doc changes;
- implementation/state mutation of a later task.

---

## 9. Manual Smoke Check

Use controlled local/test data in the accepted Laravel/PostgreSQL runtime.
Never print passwords, Bearer tokens, hashes, SQL detail, or production data.

1. Authenticate an active, password-complete Platform Owner.
2. Prepare active and inactive Institutions, each with an Institution Admin;
   also prepare one User for every non-admin role.
3. PATCH one admin's name/email/phone and verify exact `200` Resource/message
   plus protected DB fields unchanged.
4. Clear nullable contacts, run an exact no-op, and verify correct values and
   no no-op timestamp write.
5. Submit unknown/protected fields and a non-admin target UUID; verify exact
   `422`/`404` behavior and zero mutation.
6. Deactivate the active admin; verify exact response, preserved profile,
   preserved token row, rejected login, and blocked existing-token access.
7. Repeat deactivation; verify same lifecycle timestamps and no duplicate
   write.
8. Activate the admin; verify exact response and normal eligibility according
   to current first-login state. Repeat and verify no-op behavior.
9. Activate an admin whose Institution remains inactive and verify
   `403 institution_inactive` still blocks that account.
10. Verify every non-target User, both Institutions/settings, contacts,
    tokens, and unrelated data remained unchanged.

If smoke cannot run, report `NOT RUN` with exact reason; do not claim
acceptance.

---

## 10. Contract Traceability

| Source | Relevant contract |
|---|---|
| `docs/01-business-overview.md` | Platform Owner support boundary; Institution Admin role and tenant ownership |
| `docs/02-user-roles.md` | Platform Owner support for Institution Admin access; one Institution per tenant role; desktop boundary |
| `docs/03-features.md` | Manage/support Institution Admin access; platform-management scope and MVP exclusions |
| `docs/04-user-flows.md` | Super Admin support flow; protected action flow; User activation/deactivation and retention |
| `docs/05-business-rules.md` | `BR-ROLE-004`–`BR-ROLE-009`; active/inactive restriction, retention, first-login gate, platform-authorized Institution Admin management |
| `docs/06-roadmap.md` | Stage 2 Institution control; active/inactive foundation; Stage 3 dependency boundary |
| `docs/07-architecture.md` | Sections 4, 8–9, 23, 29, 32, and 35; layering, explicit platform actions, auth, errors, security, tests |
| `docs/08-database.md` | Sections 3, 5.1, 23–28; User fields, role/Institution constraint, lifecycle fields, history, isolation |
| `docs/09-api-contracts.md` | Sections 1–7.8, 8.4–8.6, 33, Appendices A–C; exact endpoints, User update shape, errors, scope, trust boundaries |
| Accepted Stage 1 artifacts | Active-account enforcement, first-login gate, User persistence, role middleware, tokens, errors, tests |
| Accepted `S02-BE-001`–`S02-BE-006` | Platform routes/authorization, PATCH/lifecycle patterns, Institution Admin Resource and test/delivery conventions |

The locked `7.8` contract defines the three endpoints and target-role rule but
does not enumerate the Institution Admin update body or lifecycle retry
details. This task narrows them consistently with the locked common User
update fields in `8.4`, the active/inactive flow, and accepted Stage 2 patterns;
it does not authorize new product behavior. If an accepted predecessor or
current locked source materially conflicts, stop instead of silently
reinterpreting it.

---

## 11. Stop Conditions

Stop and report `FINAL STATUS: BLOCKED` before implementation when:

- Stage 1 closure is not PASS;
- any `S02-BE-001` through `S02-BE-006` predecessor is not Accepted and
  delivered on `origin/main`;
- local `main` is not synchronized with approved `origin`;
- worktree contains anything other than the exact two permitted preparation
  files;
- approved task/index is missing or contradictory;
- locked docs, applicable instructions, or accepted predecessor conflicts
  with this contract;
- a conflicting implementation already exists;
- correct implementation requires a migration, package, locked-doc revision,
  frontend change, password-support decision, or later-task scope;
- PostgreSQL verification or deterministic concurrency evidence cannot run;
- unrelated user work overlaps required files and cannot be preserved;
- safe repository/GitHub delivery is unavailable.

Do not guess a product decision, weaken target-role or access enforcement,
rewrite history, or destructively clean user work.

---

## 12. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git preflight

1. Complete Sections 4 and 5.1.
2. Create/switch to the exact task branch.
3. Carry only the approved task/prompt preparation files from local `main`.
4. Confirm no preparation file was committed directly on `main`.
5. Update only truthful `S02-BE-007` index state if needed.
6. Do not commit or push.

### Phase 1 — Implementation

Implement only this task. Run every focused/full test, quality command,
protected-path check, complete change-set review, and manual smoke check. Do
not commit or push.

### Phase 2 — Read-only acceptance gate

After implementation, re-read all authorities and inspect the complete
tracked/untracked result, routes/middleware, Requests, controllers, actions,
Resource, transaction/row-lock behavior, schema assumptions, tests, command
output, smoke evidence, security, and non-goals.

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

- `P1`: authorization/target-role bypass, secret exposure, destructive data
  loss, cross-account mutation, or access-enforcement blocker;
- `P2`: material update/lifecycle/validation/response/concurrency/retention,
  architecture, test, verification, or scope mismatch;
- `P3`: non-blocking observation.

If any P1/P2 remains, return:

```text
FINAL STATUS: NOT ACCEPTED
```

Then stop. Do not fix findings inside the gate and do not start frontend work.
A separate continuation may fix `S02-BE-007` and rerun the full gate.

Phase 2 succeeds only with reported `PASS`, no P1/P2, every required test and
quality/protected-path check passing, complete change-set review, and manual
smoke passing. `PASS` is not yet `FINAL STATUS: ACCEPTED`.

### Phase 3 — Post-acceptance Git delivery

Run only after Phase 2 reports `PASS`:

1. apply only truthful `S02-BE-007` task/index acceptance bookkeeping;
2. preserve all later task states and do not create/implement/state-mutate
   frontend tasks;
3. rerun final diff/status, protected-path, secret, format, test, and integrity
   checks;
4. stage only approved files and create one focused commit with task ID in its
   body;
5. push the exact branch without force;
6. open a non-draft PR to `main` with scope, contracts, tests, smoke, security,
   and non-goals;
7. verify base/head, changed files, checks, review, and mergeability;
8. merge only through approved policy with required checks passing;
9. fast-forward local `main` from `origin/main`;
10. prove:

    ```text
    local main == origin/main
    working tree clean
    S02-BE-007 = Accepted
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

- [ ] Dependencies and two-file preflight are proven.
- [ ] Three exact endpoints exist once in the accepted Platform route group.
- [ ] Only active, password-complete Platform Owner can call them.
- [ ] Middleware precedence and scope-safe not-found behavior remain accepted.
- [ ] Only persisted `institution_admin` targets are eligible.
- [ ] PATCH accepts only non-empty partial name/email/phone input.
- [ ] Unknown/protected fields fail atomically with `422`.
- [ ] Profile update preserves login, role, Institution, password,
      first-login, lifecycle, login metadata, creator, and related data.
- [ ] Nullable contacts and non-unique contact behavior remain correct.
- [ ] Activate/deactivate are idempotent and maintain consistent lifecycle
      fields with authoritative time.
- [ ] Exact no-op update/lifecycle requests do not advance `updated_at`.
- [ ] Same-target concurrency is serialized without stale overwrite.
- [ ] Deactivation immediately blocks login/current tokens through accepted
      active-account enforcement without deleting tokens/history.
- [ ] Reactivation still respects inactive Institution and first-login gates.
- [ ] All success responses reuse exact public Resource and messages.
- [ ] No secret, creator, role, Institution, token, or learning data leaks.
- [ ] No non-target row, Institution/settings, or related data changes.
- [ ] No migration, dependency, frontend, password reset, hard delete, or
      later-task scope is present.
- [ ] Focused/full PostgreSQL tests, Pint, Composer, diff, secret, and
      protected-path checks pass.
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
4. Exact PATCH validation, allowlist, no-op, persistence, and response.
5. Exact activate/deactivate state machine, idempotency, timestamps, and
   response.
6. Authorization, target-role, Institution/role/credential/first-login/token
   and retention security evidence.
7. PostgreSQL concurrency and rollback evidence.
8. Focused/full test and quality commands with real results/counts.
9. Protected-path, complete tracked/untracked change-set, secret, and scope
   review results.
10. Manual smoke result.
11. Phase 2 P1/P2/P3 findings and PASS/NOT ACCEPTED verdict.
12. Commit, PR, checks, merge, final `main` SHA, and clean-tree evidence when
    delivery succeeds.
13. Explicit confirmation that frontend and later tasks were not created,
    implemented, or state-mutated by this run.

If blocked, do not claim completion. State exact blocker, evidence, safe
branch/worktree state, and next action.
