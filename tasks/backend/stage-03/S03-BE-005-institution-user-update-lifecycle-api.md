# Codex Task: Institution User Update and Lifecycle API

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-BE-005` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Backend` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Depends on | `S03-BE-004 — Accepted / PASS / Delivered` |
| Blocks | `S03-BE-006`, `S03-FE-007`, `S03-INT-002` |

This pair may be prepared before its dependency is accepted, but execution must
not start until S03-BE-004 is `Accepted / PASS / Delivered` on `origin/main`.

## 2. Goal

Allow an eligible Institution Admin to update only approved profile/contact
fields and idempotently activate or deactivate own-Institution Teacher,
Student, and Parent accounts without changing identity, role, credentials,
first-login state, stored tokens, relationships, or historical learning data.

Endpoints:

```text
PATCH /api/v1/institution/users/{user}
POST  /api/v1/institution/users/{user}/activate
POST  /api/v1/institution/users/{user}/deactivate
```

## 3. Current Context

S03-BE-003 owns the Institution User controller, exact shared User resource,
read routes, and tenant/eligible-role lookup contract. S03-BE-004 owns account
creation and server-derived first-login state. This task extends the existing
controller/resource boundary with profile update and explicit lifecycle
commands only.

The accepted Stage 2 Platform Institution Admin update/lifecycle actions,
requests, and tests are the implementation reference for strict request
handling, row locking, no-op writes, timestamp behavior, token retention,
rollback, and active-account enforcement. Stage 3 must add the stricter
authenticated-Institution plus Teacher/Student/Parent target predicate.

## 4. Included Scope

- Register the exact PATCH/activate/deactivate routes once in the existing
  Institution Admin middleware group.
- Add thin `update`, `activate`, and `deactivate` controller methods.
- Add one strict PATCH Form Request and one strict lifecycle Form Request.
- Add one focused update action and one lifecycle action.
- Resolve and lock a fresh target inside each mutation transaction using the
  authenticated actor's Institution and exact eligible roles.
- Reuse the S03-BE-003 shared Institution User resource byte-for-byte.
- Preserve all target Sanctum token rows during every update/lifecycle command.
- Add exact validation, tenant, authorization, no-op, timestamp, concurrency,
  rollback, preservation, disclosure, and regression tests.
- During Phase 1, mark only the S03-BE-005 Stage 3 index row as
  `In Progress / Not started / Not started`.
- After Phase 2 PASS, perform only the exact acceptance/delivery bookkeeping in
  Section 13.

## 5. Exact API Contract

### 5.1 Middleware, Actor Authority, and Target Scope

All three routes use this exact middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:institution_admin
```

The authenticated actor's non-null `institution_id` is the only tenant
authority. No route, query, body, or header value may choose or override an
Institution.

An eligible target must satisfy all of:

```text
id = raw {user} UUID
institution_id = authenticated actor.institution_id
role in (teacher, student, parent)
```

The `{user}` parameter remains a raw string. Do not add implicit User model
binding or a route UUID constraint. Middleware runs first, then the applicable
Form Request validates input, then the mutation action validates UUID syntax
and resolves the target inside its transaction and row lock.

A clean request for a malformed UUID, unknown User, foreign-Institution User,
Platform Owner, or Institution Admin returns the same centralized scope-safe:

```text
404 resource_not_found
```

The response must not reveal whether a hidden User exists, its role, or its
Institution. Invalid request input is rejected before target lookup, so invalid
input plus a hidden/missing target remains the normal `422 validation_failed`
request result after middleware passes.

### 5.2 PATCH Transport and Body Shape

`PATCH /api/v1/institution/users/{user}` requires JSON with
`Content-Type: application/json`; an optional charset parameter is allowed.
The top-level value must be a non-empty JSON object containing at least one of:

```text
full_name
email
phone
```

Body-shape rules:

- absent raw body, whitespace-only body, malformed JSON, scalar, array, or JSON
  `null` returns `422 validation_failed` with `errors.body`;
- form-encoded, multipart, text, or any other non-JSON media body returns
  `422` with `errors.body`;
- `{}` returns `422` with `errors.body` because at least one allowed profile
  field is required;
- every query key is rejected with a field-level validation error;
- every unknown/protected JSON key rejects the entire request with a
  field-level error;
- no validation failure may partially mutate the target or any other row.

Protected-key tests must include at least:

```text
id
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
remember_token
permissions
abilities
token
tokens
institution
creator
relationships
groups
settings
learning_data
```

Any other non-allowlisted key is also rejected.

### 5.3 PATCH Field Validation and Normalization

```text
full_name: when present, required string; trim before validation/persistence;
           non-empty after trimming; max 200
email:     when present, nullable string; valid email when non-null; max 254
phone:     when present, nullable string; trim before validation/persistence;
           non-empty when non-null; max 50
```

Additional exact rules:

- omitted fields preserve their current committed values;
- explicit JSON `null` clears `email` or `phone`;
- empty/whitespace email is invalid when non-null and is not converted to null;
- empty/whitespace phone is invalid after trimming and is not converted to
  null;
- email and phone are not unique; shared values remain allowed;
- role, login name, password, lifecycle, first-login, Institution, creator,
  timestamps, token state, permissions, relationships, and learning data are
  never accepted or derived from PATCH input;
- an authorized actor may update either an active or inactive eligible target.

### 5.4 Atomic PATCH Persistence and Exact No-Op

Pass the authenticated actor, raw `{user}` string, and only validated normalized
profile attributes to `UpdateInstitutionUser`.

Inside one database transaction:

1. reject malformed UUID syntax with the safe not-found behavior;
2. select the target using UUID + actor Institution + eligible-role predicates
   and `FOR UPDATE`/Laravel `lockForUpdate()`;
3. apply only present `full_name`, `email`, and `phone` values to that fresh
   locked row;
4. if the normalized values are identical to the locked committed values,
   execute no User `UPDATE`, preserve the exact existing `updated_at`, and
   return the current resource;
5. otherwise persist one profile update, let authoritative server time advance
   `updated_at` once, refresh, and return committed state.

PATCH must never write `is_active`, `deactivated_at`, password/first-login
state, token rows, or any unrelated field/row. An unexpected failure rolls the
transaction back completely and uses the centralized safe
`500 server_error` without SQL, exception, stack, PII, credential, or token
detail.

Success is `200 OK`, exactly the unchanged S03-BE-003 shared User resource, and:

```text
Institution user updated successfully.
```

### 5.5 Lifecycle Request Contract

Both lifecycle endpoints accept:

- no request body; or
- an empty JSON object `{}` using JSON media type.

No query parameter is allowed. The accepted Stage 2 lifecycle parser behavior
for an effectively empty raw body must remain compatible.

Reject with `422 validation_failed` and zero mutation:

- every non-empty JSON object, with field-level errors for its keys;
- malformed JSON, scalar, array, or JSON `null`, with `errors.body`;
- non-empty form, multipart, text, or other non-JSON media input, with
  `errors.body`;
- every query key, including lifecycle- or force-like keys, with a field-level
  error.

Form Request validation runs after middleware and before target resolution.

### 5.6 Activate

`POST /api/v1/institution/users/{user}/activate` performs exactly:

| Current locked state | Required result |
|---|---|
| Inactive | Set `is_active = true`, clear `deactivated_at`, execute one User update, advance `updated_at` once using server time |
| Active | Idempotent `200`; execute no User update and preserve exact `deactivated_at = null` and `updated_at` |

Activation must not create, restore, replace, rotate, or delete a Sanctum token;
reset/change a password; clear `must_change_password`; change `last_login_at`;
or bypass inactive-Institution, role, permission, or first-login gates.

Success is `200 OK`, the exact shared User resource, and:

```text
Institution user activated successfully.
```

### 5.7 Deactivate

`POST /api/v1/institution/users/{user}/deactivate` performs exactly:

| Current locked state | Required result |
|---|---|
| Active | Set `is_active = false`, set `deactivated_at` to authoritative server time, execute one User update, and advance `updated_at` once |
| Inactive | Idempotent `200`; execute no User update and preserve the original `deactivated_at` and `updated_at` exactly |

Deactivation immediately blocks new login and protected existing-token access
through the accepted active-account middleware. It must not delete, update,
rotate, or otherwise mutate any stored Sanctum token row. It also preserves
password hash, `must_change_password`, `last_login_at`, identity, role,
Institution, creator, relationships, and historical/learning data.

Success is `200 OK`, the exact shared User resource, and:

```text
Institution user deactivated successfully.
```

### 5.8 Stored-Token and Reactivation Semantics

- Snapshot all target token rows before lifecycle operations; real and no-op
  activation/deactivation must leave the snapshot unchanged.
- While inactive, login returns the accepted `user_inactive` behavior and does
  not change `last_login_at` or token rows.
- While inactive, a retained token is rejected by `active.account` on protected
  routes.
- Reactivation does not create or restore a token. A retained, still-valid token
  may resume only otherwise-authorized access after reactivation.
- A token separately removed by explicit logout/expiry/revocation remains
  removed; lifecycle never reconstructs it.
- Institution inactivity, role/permission checks, and
  `must_change_password = true` continue to apply normally after reactivation.

These rules match the locked S03-INT-001 contract and the accepted Stage 2
account lifecycle convention.

### 5.9 Lifecycle Transactions and Cross-Operation Concurrency

Pass the actor and raw target ID to `ChangeInstitutionUserLifecycle`. Each
activate/deactivate call uses one transaction and the same scoped
`lockForUpdate()` target strategy as PATCH.

All same-target PATCH, activate, and deactivate operations must serialize on
the same User row. Every action must read and mutate the fresh locked state;
never save an unlocked/stale model loaded by the controller or S03-BE-003 read
action.

Required concurrency behavior:

- overlapping PATCH operations cannot overwrite an unrelated field committed
  by another operation;
- overlapping PATCH and lifecycle operations preserve both the committed
  profile change and the lifecycle result;
- same-direction lifecycle races produce at most one real transition and the
  later idempotent operation performs no duplicate update;
- opposite-direction lifecycle races finish in the valid state determined by
  lock/commit order, with state and `deactivated_at` internally consistent;
- no stale write may restore old profile/lifecycle values;
- no token, relationship, history, Institution, or unrelated User row is
  changed by any race;
- each response serializes the state committed by its own transaction.

PostgreSQL row-lock/concurrency evidence is mandatory; a purely mocked or
SQLite-only assertion is insufficient.

### 5.10 Exact Success Envelopes

Every successful endpoint returns exactly these top-level keys:

```text
data
message
```

`data` is the unchanged 12-key S03-BE-003 resource in its accepted order:

```text
id, role, full_name, login_name, email, phone, is_active,
must_change_password, last_login_at, deactivated_at, created_at, updated_at
```

No `meta`, `links`, Institution/creator, password/hash, token, permission,
relationship, answer, score, result, or learning field may appear.

## 6. Exact Files and Responsibilities

Codex must inspect current accepted patterns but change only these exact
application/test paths:

| File | Expected action | Responsibility |
|---|---|---|
| `backend/routes/api.php` | Modify | Register exact PATCH/activate/deactivate routes once |
| `backend/app/Http/Controllers/Api/V1/Institution/InstitutionUserController.php` | Modify | Add thin update/activate/deactivate adapters |
| `backend/app/Http/Requests/Institution/InstitutionUserUpdateRequest.php` | Create | PATCH JSON shape, allowlist, normalization, validation |
| `backend/app/Http/Requests/Institution/InstitutionUserLifecycleRequest.php` | Create | Exact empty lifecycle body/query validation |
| `backend/app/Actions/Institution/UpdateInstitutionUser.php` | Create | Scoped locked atomic profile mutation/no-op |
| `backend/app/Actions/Institution/ChangeInstitutionUserLifecycle.php` | Create | Scoped locked idempotent lifecycle mutation |
| `backend/tests/Feature/Institution/InstitutionUserUpdateLifecycleApiTest.php` | Create | Complete mutation/security/concurrency evidence |
| `backend/app/Http/Resources/Institution/InstitutionUserResource.php` | Inspect/reuse unchanged | Stable S03-BE-003 output contract |
| S03-BE-003 `ShowInstitutionUser`/read code | Inspect/preserve unchanged | Reuse predicate semantics, not unlocked model mutation |
| accepted Stage 2 Platform update/lifecycle code/tests | Inspect/preserve | Reuse safe request/lock/no-op/token conventions |
| User model/enum/factory and auth middleware | Inspect/preserve | Existing support is sufficient |
| `tasks/STAGE_03_TASK_INDEX.md` | Modify only as Section 13 permits | Truthful execution/review/delivery state |
| `tasks/README.md` | Modify only after Phase 2 PASS | Truthful Stage 3 current/next gate |
| this detailed task | Status metadata only after Phase 2 PASS | Final accepted lifecycle state |
| paired Codex prompt | Preserve byte-for-byte | Approved execution authority |

No other application or test path may change. No resource/read action, model,
enum, factory, migration, schema/index, auth middleware, frontend, Platform
contract, or locked document change belongs here. Stop instead of widening the
allowlist if accepted predecessors cannot support the task unchanged.

## 7. Authoritative References

| Document | Exact area | Requirement |
|---|---|---|
| `docs/02-user-roles.md` | Institution Admin and managed roles | Actor/target boundary |
| `docs/03-features.md` / `docs/04-user-flows.md` | Institution User management | Approved Stage 3 workflow |
| `docs/05-business-rules.md` | tenant/lifecycle/history rules | Scope and preservation |
| `docs/06-roadmap.md` | `8. Stage 3` | Update/lifecycle scope |
| `docs/07-architecture.md` | auth/tenant/layer/transaction/testing | Organization/security |
| `docs/08-database.md` | Users, timestamps, tokens/relations | Existing persistence |
| `docs/09-api-contracts.md` | Sections 1–5, 8.2/8.5–8.7, 33 after S03-INT-001 | Exact API and errors |
| accepted S03-INT-001 | Sections 4.3.5–4.3.7 | Locked update/lifecycle/token decisions |
| `backend/AGENTS.md` | entire applicable file | Backend rules and gates |

## 8. Architecture, Security, and Error Requirements

- Requests own raw body/media/query/allowlist/field validation and PATCH
  normalization.
- Controller gets the authenticated actor and raw target string, passes only
  validated values to actions, and returns the existing resource with exact
  status/message.
- Actions own UUID validation, scoped target resolution, transaction, row lock,
  dirty/no-op decision, persistence, refresh, and committed result.
- Never mass-assign raw request data, use unscoped binding, or mutate a model
  loaded before the transaction.
- Use existing `UserRole`, UUID, User casts, centralized error envelope, and
  PostgreSQL primitives; add no new abstraction or schema without authority.
- Unexpected update/lifecycle failures roll back fully and map to safe
  `500 server_error`; do not translate unrelated database failures to
  validation/not-found.
- Preserve middleware and validation/target precedence for unauthenticated,
  inactive User, inactive Institution, first-login actor, wrong role, invalid
  input, and hidden target cases.
- Do not log raw bodies, email/phone values, password/hash, tokens, SQL,
  exception internals, or hidden-target details.

## 9. Acceptance Criteria

- [ ] Exact three routes exist once with exact middleware order.
- [ ] Only own-Institution Teacher/Student/Parent targets are mutable; all
      malformed/unknown/foreign/disallowed targets share safe `404`.
- [ ] PATCH media, body shape, allowlist, query rejection, field validation,
      trimming, null clearing, shared contacts, and protected-key behavior are
      exact and atomic.
- [ ] PATCH may update active/inactive targets and never changes lifecycle or
      protected state.
- [ ] Exact PATCH no-op executes no User update and preserves `updated_at`.
- [ ] Lifecycle accepts no body or `{}` only, rejects all other input/query,
      and applies no mutation on validation failure.
- [ ] Real activate/deactivate transitions update exact fields once using
      server time; repeated commands perform no write and preserve timestamps.
- [ ] All stored target token rows remain unchanged through lifecycle; inactive
      login/existing-token access is blocked by accepted middleware behavior.
- [ ] Reactivation creates/restores no token, and a retained valid token may
      resume only otherwise-authorized access.
- [ ] Password/first-login/last-login/identity/role/Institution/creator,
      relationships, history, and learning data are preserved.
- [ ] PATCH and lifecycle share safe scoped PostgreSQL row-lock serialization
      and never stale-overwrite profile or lifecycle state.
- [ ] Controlled unexpected failures roll back fully and return safe
      `500 server_error` without internal/sensitive disclosure.
- [ ] Success returns exact `200`, unchanged 12-key resource, exact message,
      and only `data + message` at top level.
- [ ] Existing S03-BE-003/004, auth, Platform, Stage 1, and Stage 2 behavior
      remains green.
- [ ] No schema/frontend/password-reset/delete/relationship/later-stage or
      unrelated file change is introduced.

## 10. Tests and Verification

### 10.1 Required Feature and Action Tests

- routes registered once with exact methods, paths, names if current convention
  names them, and middleware order;
- PATCH success for each eligible role and active/inactive target; each field,
  combinations, omitted preservation, explicit null clears, shared contacts,
  normalization, 200/254/50 boundaries, and exact changed-row snapshot;
- exact PATCH no-op after normalization proves `FOR UPDATE`, zero User update,
  unchanged raw `updated_at`, and exact current response;
- absent/whitespace/malformed/scalar/array/JSON-null/empty-object and non-JSON
  PATCH body matrix with `errors.body`, zero mutation, and safe errors;
- invalid field types/lengths/email/blank name/blank phone, every protected key,
  arbitrary unknown keys, every query key, and combined valid+invalid input
  proving no partial mutation;
- lifecycle raw empty and `{}` successes; non-empty object, malformed,
  scalar/array/null, non-JSON media, and query rejection with zero mutation;
- frozen server time proves active→inactive, inactive→inactive,
  inactive→active, active→active, exact `deactivated_at` and `updated_at`, one
  update for real transition, and zero updates for no-op;
- exact top-level/resource key order, values/types/nulls/UTC timestamps/messages
  for all three endpoints and complete protected-data disclosure exclusions;
- target matrix for own Teacher/Student/Parent versus malformed/unknown,
  foreign Institution, Platform Owner, and Institution Admin, with identical
  404 envelope and no existence/role/tenant disclosure;
- fake tenant route/query/body/header attempts cannot select another
  Institution; request-validation-before-target precedence is proven;
- unauthenticated, inactive actor, inactive actor Institution,
  `must_change_password = true` actor, and every wrong role, including invalid
  request cases proving middleware precedence;
- exact pre/post snapshots for target password hash, first-login, login name,
  role, Institution, creator, `last_login_at`, tokens, relationships/history,
  and for all other Users, Institutions, settings, tokens, and related rows;
- real/no-op activate/deactivate token snapshots remain byte-for-byte equal;
  inactive login and retained-token protected access fail; reactivation creates
  no token and one retained valid token resumes only an otherwise-permitted
  request; explicit logout removal is not restored;
- active and inactive Institution plus first-login target cases prove
  reactivation does not bypass accepted gates or change `last_login_at`;
- PostgreSQL action evidence proves every mutation uses scoped `FOR UPDATE`;
  controlled same-PATCH, overlapping-profile, PATCH/lifecycle,
  same-lifecycle, and opposite-lifecycle races prove fresh-state serialization,
  no lost update, valid final timestamps/state, and no unrelated/token changes;
- controlled update and lifecycle database failures prove full rollback,
  centralized safe `500 server_error`, no internal/SQL/stack/PII/token leak,
  and no partial/secondary write;
- S03-BE-003 list/detail immediately reflects committed profile/lifecycle state
  and S03-BE-004 creation/auth/first-login plus Stage 1/2/Platform regressions
  remain green.

### 10.2 Quality Gates

From `backend/`, run current repository-valid equivalents of:

```text
vendor/bin/pint --test
php artisan test --filter=InstitutionUserUpdateLifecycleApiTest
php artisan test
composer validate --strict
```

Run all configured security/static checks required by `backend/AGENTS.md`. Any
required failure blocks acceptance.

### 10.3 Manual Smoke

Using controlled testing credentials that are never recorded in reports/logs:

1. Update one active User and one inactive User; verify list/detail and exact
   no-op timestamp behavior.
2. Attempt protected, unknown, query, and foreign-Institution mutations and
   prove zero change.
3. Snapshot a target token, deactivate the target, verify the token row remains
   stored while login and protected access are blocked.
4. Repeat deactivation and verify both lifecycle timestamps remain unchanged.
5. Reactivate the target, verify no token was created/restored and the retained
   valid token can resume only access permitted by all normal gates.
6. Confirm password/first-login/last-login, relationships/history, other Users,
   Institution, and settings remain unchanged.

If the controlled backend is available, smoke must PASS. A smoke `FAIL` always
blocks acceptance. `NOT RUN` is non-blocking only when the environment is
genuinely unavailable, the reason is reported explicitly, and all equivalent
automated contract/tenant/atomicity/concurrency/token-preservation tests pass.
Do not use `NOT RUN` to hide a startup, configuration, or implementation
failure.

## 11. Explicit Non-Goals

- Role/login/password/first-login edit or password reset/recovery.
- Token revoke/rotate/create/restore or session management by lifecycle.
- Hard delete, archive, suspend, transfer, merge, or bulk operations.
- Institution Admin or Platform Owner target management.
- Group/relationship creation/removal or learning/history mutation.
- Institution/profile/settings/category/report/frontend work.
- Model/enum/factory/migration/schema/index/auth-middleware changes.
- Optimistic version fields, idempotency keys, audit-event subsystem, or Stage 4
  behavior.

## 12. Stop Conditions

Stop on missing accepted S03-BE-004 dependency/resource, a contradiction with
the locked S03-INT-001 token/lifecycle contract, inability to scope and lock the
fresh target by actor Institution, required schema/model/resource/read/auth
change, inability to preserve tokens/history, unsafe Git state, or material
scope expansion.

## 13. Required Workflow and Delivery

### Phase 0 — Git Preflight

1. Read the paired execution prompt and its authority order completely.
2. Verify this detailed task is `Approved`.
3. Verify S03-INT-001 and S03-BE-001 through S03-BE-004 are each
   `Accepted / PASS / Delivered` on `origin/main`.
4. Verify the exact approved remote, fetch safely, and prove
   `local main == origin/main`.
5. Verify the working tree is clean except for only the owner-prepared
   S03-BE-005 detailed task and paired prompt.
6. Create/switch to `task/s03-be-005-institution-user-lifecycle`.
7. Preserve unrelated user work and stop on unsafe/dirty/conflicting state.
8. Do not commit, push, create a PR, or merge before Phase 2 PASS.

### Phase 1 — Implementation

Implement only this task. The only application/test paths allowed to change
are:

```text
backend/routes/api.php
backend/app/Http/Controllers/Api/V1/Institution/InstitutionUserController.php
backend/app/Http/Requests/Institution/InstitutionUserUpdateRequest.php
backend/app/Http/Requests/Institution/InstitutionUserLifecycleRequest.php
backend/app/Actions/Institution/UpdateInstitutionUser.php
backend/app/Actions/Institution/ChangeInstitutionUserLifecycle.php
backend/tests/Feature/Institution/InstitutionUserUpdateLifecycleApiTest.php
```

Reuse `backend/app/Http/Resources/Institution/InstitutionUserResource.php`
byte-for-byte unchanged. Preserve S03-BE-003 read actions and all model/enum/
factory/schema/auth/Platform/frontend code. Also update only the S03-BE-005 row
in `tasks/STAGE_03_TASK_INDEX.md` to
`In Progress / Not started / Not started`. Keep this detailed task's status
`Approved` and preserve the paired prompt byte-for-byte before Phase 2.

Run all required automated checks, scope/secret checks, and the manual smoke
rule from Section 10. Inspect the complete diff including the owner-prepared
task/prompt. Do not commit or push.

### Phase 2 — Read-Only Acceptance Gate

Re-read the authority task, accepted S03-INT-001/S03-BE-003/004 contracts,
locked references, complete diff, code/tests, request/resource/tenant/locking/
no-op/timestamp/token/concurrency/rollback/preservation/disclosure evidence,
and smoke result. Phase 2 is strictly read-only:

```text
no edits or auto-fix/write-format
no task/index/README bookkeeping edits
no staging or commit
no push, PR, or merge
no self-fixing findings
```

Classify findings:

- `P1`: authorization/tenant or secret/credential/token disclosure,
  protected-field control, destructive Git, or violation of the read-only gate;
- `P2`: material request/validation/resource/mutation/no-op/timestamp/token/
  transaction/concurrency/error/preservation/test mismatch, scope drift, or
  workflow/bookkeeping defect;
- `P3`: non-blocking observation that does not affect correctness, security,
  required evidence, or maintainability acceptance.

Any unresolved P1 or P2 results in:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start `S03-BE-006`. Report every P3 finding;
P3 alone does not block acceptance.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 PASS with no unresolved P1/P2.

1. Change only this detailed task's metadata status from `Approved` to
   `Accepted`; do not rewrite its approved behavior.
2. Prepare only the S03-BE-005 index row as
   `Accepted / PASS / Delivered` in the delivery commit.
3. Update `tasks/README.md` truthfully: Stage 3 remains `In Progress`,
   S03-BE-005 is the delivered task, and S03-BE-006 is the next execution gate.
4. Preserve every later task's truthful status; do not mark S03-BE-006
   Approved unless its own reviewed pair is already present and separately
   approved.
5. Keep the paired Codex prompt byte-for-byte unchanged and include both
   owner-prepared authority files in the focused delivery commit.
6. Keep Stage 3 not closed and Stage 4 not started.
7. Re-run final non-writing diff, scope, secret, and consistency checks.
8. Stage only the approved implementation/test files, this task, its unchanged
   prompt, `tasks/STAGE_03_TASK_INDEX.md`, and `tasks/README.md`.
9. Commit:

   ```text
   feat(institution): add user update and lifecycle APIs
   ```

   Body:

   ```text
   Task: S03-BE-005
   ```

10. Push the exact task branch, open a PR to `main`, verify base/head/diff, and
    merge only when required checks are safe/green and merge is permitted.
11. Fast-forward local `main` and verify local `main == origin/main` with a
    clean working tree.

The prepared `Accepted / PASS / Delivered` values become authoritative only
after the delivery commit is merged and local/remote/clean verification passes.
If Phase 2 passed but safe delivery cannot complete, return:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Only after complete delivery return:

```text
FINAL STATUS: ACCEPTED
```

## 14. Required Codex Final Report

Report final status, preflight/dependency evidence, implementation and every
changed file, exact PATCH/lifecycle/request/resource behavior, every acceptance
criterion and command/result, tenant/auth/validation/protected/no-op/timestamp/
token-retention/concurrency/rollback/preservation/disclosure/safe-error
evidence, S03-BE-003/004 and Platform regressions, P1/P2/P3 findings, smoke
status/blocking decision, scope/secret checks, bookkeeping result, and complete
Git/PR/merge/local-remote-clean evidence.

State:

```text
No User create/delete/password reset, token revocation, Institution Admin/
Platform Owner management, relationship, Group, settings, category, frontend,
or Learning behavior was implemented.
Next implementation gate: S03-BE-006.
```
