# Codex Task: Institution User Create API

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-BE-004` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Backend` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Depends on | `S03-BE-003 — Accepted / PASS / Delivered` |
| Blocks | `S03-BE-005`, `S03-FE-006`, `S03-INT-002` |

The pair may be prepared before its dependency is accepted, but execution must
not start until S03-BE-003 is `Accepted / PASS / Delivered` on `origin/main`.

## 2. Goal

Allow an eligible Institution Admin to create exactly one active Teacher,
Student, or Parent account in the authenticated Institution with a securely
hashed initial password and mandatory first-login password change.

Endpoint:

```text
POST /api/v1/institution/users
```

## 3. Current Context

S03-BE-003 owns the stable Institution User controller, read routes, exact
shared resource, and tenant-scoped lookup behavior. Stage 2 provides an
accepted Platform Owner Institution Admin create pattern, including strict JSON
validation, hashing, transaction behavior, and concurrent global login-name
conflict handling.

This task adds only Teacher/Student/Parent creation to the existing S03-BE-003
boundary. Institution, creator, UUID, lifecycle, and first-login state remain
backend-authoritative.

## 4. Included Scope

- Register the exact POST route once in the existing Institution Admin group.
- Add the `store` method to the S03-BE-003 Institution User controller.
- Add one strict create Form Request with exact JSON/query/allowlist behavior.
- Add one focused transactional create action using trusted actor scope,
  approved role enum values, and Laravel password hashing.
- Map validation-time and concurrent database global `login_name` conflicts to
  the same safe field-level validation contract.
- Return the unchanged S03-BE-003 Institution User resource.
- Add contract, tenant, authorization, atomicity, first-login, disclosure,
  safe-error, and regression tests.
- During Phase 1, mark only the S03-BE-004 Stage 3 index row as
  `In Progress / Not started / Not started`.
- After Phase 2 PASS, perform only the exact acceptance/delivery bookkeeping in
  Section 13.

## 5. Exact API Contract

### 5.1 Middleware and Tenant Authority

Middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:institution_admin
```

The authenticated Institution Admin's `institution_id` and `id` are the only
tenant and creator authorities. No route, query, body, or header value may
select another Institution or creator.

### 5.2 Request Transport and Body Shape

The request uses JSON with `Content-Type: application/json` (an optional charset
parameter is allowed). The top-level value must be a JSON object. Exactly these
keys are allowed:

```text
role
full_name
login_name
email
phone
password
```

Example:

```json
{
  "role": "teacher",
  "full_name": "Teacher Name",
  "login_name": "teacher01",
  "email": null,
  "phone": "+998901234567",
  "password": "initial-password"
}
```

Body-shape rules:

- absent raw body, whitespace-only body, malformed JSON, scalar, array, or JSON
  `null` returns `422 validation_failed` with `errors.body`;
- form-encoded, multipart, or text content is not accepted as this JSON-object
  contract and returns `422` with `errors.body`;
- `{}` is a syntactically valid JSON object but fails with field-level errors
  for the missing required fields, not a fabricated success;
- every query key is rejected with a field-level validation error;
- every unknown/protected JSON key rejects the complete request with a
  field-level error;
- validation failure creates no User or Sanctum token and causes no partial
  side effect.

### 5.3 Exact Field Validation and Normalization

```text
role: required string; exactly teacher|student|parent
full_name: required string; trim before validation/persistence; non-empty; max 200
login_name: required string; trim before validation/persistence; non-empty; max 191; globally unique
email: optional; nullable string; valid email when non-null; max 254
phone: optional; nullable string; trim before validation/persistence; non-empty when non-null; max 50
password: required string; min 8; max 255
```

Additional exact rules:

- `platform_owner` and `institution_admin` role values are rejected;
- role is not silently trimmed, lowercased, or converted;
- an omitted or explicit-null `email` persists as `null`; empty/whitespace email
  is not a valid non-null email and is rejected;
- an omitted or explicit-null `phone` persists as `null`; an empty/whitespace
  phone is rejected after trimming;
- password is never trimmed, normalized, generated, echoed, or altered before
  hashing; hash the exact validated string;
- email and phone are not unique; duplicate/shared values are allowed;
- `login_name` uniqueness is global across all roles and Institutions after the
  required trimming.

Protected-key tests must include at least:

```text
id
institution_id
created_by_user_id
is_active
must_change_password
last_login_at
deactivated_at
created_at
updated_at
password_confirmation
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

### 5.4 Atomic Server-Derived Persistence

Inside one database transaction, derive and persist exactly one User:

```text
id = server-generated UUID
institution_id = authenticated actor.institution_id
created_by_user_id = authenticated actor.id
role = validated teacher|student|parent enum value
full_name = validated trimmed value
login_name = validated trimmed value
email = validated value or null
phone = validated trimmed value or null
password = Hash::make(exact validated password)
is_active = true
must_change_password = true
last_login_at = null
deactivated_at = null
created_at = authoritative server time
updated_at = authoritative server time
```

Pass the authenticated actor to the action. Do not resolve or pass an arbitrary
Institution model/ID from request data. Refresh and return the committed User.

The normal validation check and database unique constraint both protect global
`login_name`. A concurrent loser on SQLSTATE `23505` for the existing
`users_login_name_unique` constraint returns `422 validation_failed` with
`errors.login_name`, no database/constraint detail, and no row/token created by
the losing request. Do not translate unrelated database failures into a fake
login-name error; they roll back and use centralized safe `500 server_error`.

Creation itself must not:

- authenticate or log in the new User;
- create/revoke/change a Sanctum token or session;
- generate, return, log, or notify the password;
- create invitations, emails, permissions, relationships, Groups, settings,
  categories, or learning records;
- modify the actor, Institution, existing Users, or any unrelated row.

### 5.5 Success — `201 Created`

Return exactly these top-level keys:

```json
{
  "data": {
    "id": "user-uuid",
    "role": "teacher",
    "full_name": "Teacher Name",
    "login_name": "teacher01",
    "email": null,
    "phone": "+998901234567",
    "is_active": true,
    "must_change_password": true,
    "last_login_at": null,
    "deactivated_at": null,
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-07T15:00:00Z"
  },
  "message": "Institution user created successfully."
}
```

The `data` object is the unchanged exact S03-BE-003 shared User resource. No
`meta`, `links`, Institution/creator data, password/hash, token, permission,
relationship, or learning field is returned.

## 6. Exact Files and Responsibilities

Codex must inspect current accepted patterns but use only these exact task
paths:

| File | Expected action | Responsibility |
|---|---|---|
| `backend/routes/api.php` | Modify | Register exact POST route once |
| `backend/app/Http/Controllers/Api/V1/Institution/InstitutionUserController.php` | Modify | Add thin `store` adapter |
| `backend/app/Http/Requests/Institution/InstitutionUserCreateRequest.php` | Create | JSON shape, normalization, allowlist, validation |
| `backend/app/Actions/Institution/CreateInstitutionUser.php` | Create | Trusted-scope transactional creation/hashing/race mapping |
| `backend/app/Http/Resources/Institution/InstitutionUserResource.php` | Inspect/reuse unchanged | Stable S03-BE-003 output contract |
| `backend/tests/Feature/Institution/InstitutionUserCreateApiTest.php` | Create | Complete create/security/atomicity evidence |
| `backend/app/Models/User.php`, `backend/app/Enums/UserRole.php`, `backend/database/factories/UserFactory.php` | Inspect and preserve | Existing support is sufficient |
| accepted Stage 2 Platform Admin create code/tests | Inspect and preserve | Reuse safe primitives without widening scope |
| `tasks/STAGE_03_TASK_INDEX.md` | Modify only as Section 13 permits | Truthful execution/review/delivery state |
| `tasks/README.md` | Modify only after Phase 2 PASS | Truthful Stage 3 current/next gate |
| this detailed task | Status metadata only after Phase 2 PASS | Final accepted lifecycle state |
| paired Codex prompt | Preserve byte-for-byte | Approved execution authority |

No other application or test path may change. If the accepted S03-BE-003
resource/controller contract is defective and cannot be reused unchanged, stop
and report the conflict instead of silently modifying read behavior. No model,
enum, factory, migration, schema, frontend, Platform contract, or locked-doc
change belongs here.

## 7. Authoritative References

| Document | Exact area | Requirement |
|---|---|---|
| `docs/02-user-roles.md` | Institution Admin and managed roles | Creator/target authority |
| `docs/03-features.md` / `docs/04-user-flows.md` | account creation | Stage 3 workflow |
| `docs/05-business-rules.md` | tenant, role, lifecycle, first login | Backend-derived ownership/state |
| `docs/06-roadmap.md` | `8. Stage 3` | Teacher/Student/Parent account scope |
| `docs/07-architecture.md` | auth/tenant/layer/transaction/testing | Required organization/security |
| `docs/08-database.md` | Users and Roles | Existing fields/limits/global login unique |
| `docs/09-api-contracts.md` | Sections 1–5, 8.2/8.4, and 33 after S03-INT-001 | JSON, resource, create, errors, first-login |
| `backend/AGENTS.md` | entire applicable file | Backend organization, secrets, and gates |

## 8. Architecture, Security, and Error Requirements

- Request owns raw JSON/query/allowlist/field validation and normalization.
- Controller receives validated values and the authenticated actor, calls one
  action, and returns the existing resource with exact status/message.
- Action owns server-derived fields, transaction, hashing, persistence, refresh,
  and unique-race translation.
- Never mass-assign raw request input or accept tenant/creator/lifecycle/
  first-login/timestamp state.
- Use `UserRole`, `Hash`, the existing User model, and the exact unique
  constraint. Do not add schema/index/role abstractions.
- Catch only the known global login-name unique violation as validation; every
  other unexpected failure rolls back and maps to safe `500 server_error`.
- Preserve middleware precedence for unauthenticated, inactive User,
  inactive Institution, first-login actor, and wrong role.
- No request/password/hash/token/SQL/exception/sensitive data in logs or errors.

## 9. Acceptance Criteria

- [ ] Exact POST route exists once with exact middleware order.
- [ ] Eligible Institution Admin creates Teacher, Student, and Parent accounts
      only in the actor's Institution.
- [ ] Request transport, top-level JSON-object rule, allowlist, query rejection,
      field validation, trimming, and null behavior are exact.
- [ ] Every protected/unknown key and invalid role is rejected with no partial
      side effect.
- [ ] Server UUID, actor Institution/creator, role, active/first-login state,
      null operational timestamps, and server timestamps are exact.
- [ ] Password hashes the exact validated string and never appears as plaintext
      or hash in response/logs.
- [ ] Missing/duplicate contacts behave correctly and are not unique.
- [ ] Validation-time and concurrent global login conflicts return
      field-level `422` without database disclosure or losing-request writes.
- [ ] Any unexpected post-insert failure rolls back fully and returns safe
      `500 server_error` without internal/secret disclosure.
- [ ] Success is exact `201` with only unchanged User resource plus exact
      message and no extra/protected keys.
- [ ] Creation itself creates no token/session/invitation/notification/
      permission/relationship/settings/learning side effect.
- [ ] Created accounts can authenticate, are blocked by the first-login gate,
      and after password change the old password fails and the new password
      succeeds with `must_change_password = false`.
- [ ] S03-BE-003 list/detail immediately sees the committed User.
- [ ] Existing auth/Platform/read APIs remain green.
- [ ] No schema/frontend/later-stage scope or unrelated file changed.

## 10. Tests and Verification

### 10.1 Required Feature Tests

- route registered once with exact method/path/middleware order;
- successful create for each Teacher/Student/Parent with exact `201`, top-level
  keys, ordered shared resource keys/types/nulls/UTC timestamps, and message;
- frozen server time proves UUID, created/updated timestamps, actor Institution,
  actor creator, active state, first-login state, and null operational fields;
- full_name/login_name/phone trimming and 200/191/50 boundaries;
- role required/type/exact allowed/disallowed values; email valid/type/254,
  empty/whitespace/invalid behavior; password type/8/255 boundaries and proof
  that leading/trailing characters are not trimmed or normalized;
- omitted/null/shared/duplicate email and phone behavior;
- missing every required field and `{}` field-level failures;
- absent/whitespace/malformed/scalar/array/JSON-null and non-JSON media body
  failures with `errors.body`;
- every protected key from Section 5.3 and representative arbitrary unknown key;
- every query key, including names matching allowed/protected body fields,
  rejected with field-level errors and no User/token write;
- pre-existing same- and foreign-Institution/other-role global login conflict;
- controlled concurrent unique race proves one winning row, losing request
  `errors.login_name`, complete rollback, and no SQL/constraint/password leak;
- controlled unexpected failure after attempted insert proves transaction
  rollback, safe `500 server_error`, and no internal/password/hash leakage;
- forged Institution/creator/lifecycle/first-login/timestamp/header attempts
  cannot alter authoritative values;
- unauthenticated, inactive actor, inactive actor Institution, actor
  `must_change_password = true`, and Platform Owner/Teacher/Student/Parent
  wrong-role precedence, including invalid input where needed to prove gates;
- exact before/after snapshots prove only the one expected User row changes on
  success and no existing User, Institution, settings, token, or unrelated row
  changes; creation itself adds no Sanctum token;
- each created role can authenticate with the exact initial password and sees
  `must_change_password = true`; at least one complete login → blocked normal
  endpoint → authenticated password change → old-password rejection → new-login
  success flow proves the accepted gate transition;
- S03-BE-003 list/detail immediately returns the committed resource;
- response/log disclosure matrix excludes plaintext/hash, Institution/creator,
  token/permission/relationship/settings/learning data;
- accepted Stage 1/2 auth, Platform Admin create, and S03-BE-003 read regressions.

### 10.2 Quality Gates

From `backend/`, run current repository-valid equivalents of:

```text
vendor/bin/pint --test
php artisan test --filter=InstitutionUserCreateApiTest
php artisan test
composer validate --strict
```

Run configured security/static checks required by `backend/AGENTS.md`. Any
required failure blocks acceptance.

### 10.3 Manual Smoke

Using controlled testing credentials that are never recorded in reports/logs:

1. Create one Teacher, Student, and Parent in the own Institution.
2. Confirm list/detail visibility and exact server-owned state.
3. Attempt a duplicate login and a forged Institution/lifecycle field.
4. Log in one created User, verify the mandatory password gate, change the
   password, and verify the old/new password behavior.
5. Confirm creation added no unrelated record or token.

If the controlled backend is available, smoke must PASS. A smoke `FAIL` always
blocks acceptance. `NOT RUN` is non-blocking only when the environment is
genuinely unavailable, the reason is reported explicitly, and all equivalent
automated contract/tenant/atomicity/first-login tests pass. Do not use
`NOT RUN` to hide a startup, configuration, or implementation failure.

## 11. Explicit Non-Goals

- User update, activate, deactivate, delete, password reset, role/login edit.
- Bulk import/export, invitation, email/SMS, notification, or credential
  generation/delivery.
- Institution Admin or Platform Owner creation.
- Group/relationship assignment or permission creation.
- Settings, categories, learning, reports, or frontend work.
- Model/enum/factory/migration/schema/index changes.
- Idempotency keys, optimistic locking, or new password-strength policy.

## 12. Stop Conditions

Stop on a missing accepted S03-BE-003 dependency/resource, contradictory
password/role contract, inability to derive trusted actor scope, required
schema/model/Platform/read-contract change, unsafe Git state, or material scope
expansion.

## 13. Required Workflow and Delivery

### Phase 0 — Git Preflight

1. Read the paired execution prompt and its authority order completely.
2. Verify this detailed task is `Approved`.
3. Verify S03-INT-001 and S03-BE-001 through S03-BE-003 are each
   `Accepted / PASS / Delivered` on `origin/main`.
4. Verify the exact approved remote, fetch safely, and prove
   `local main == origin/main`.
5. Verify the working tree is clean except for only the owner-prepared
   S03-BE-004 detailed task and paired prompt.
6. Create/switch to `task/s03-be-004-institution-user-create`.
7. Preserve unrelated user work and stop on an unsafe/dirty/conflicting state.
8. Do not commit, push, create a PR, or merge before Phase 2 PASS.

### Phase 1 — Implementation

Implement only this task. The only application/test paths allowed to change
are:

```text
backend/routes/api.php
backend/app/Http/Controllers/Api/V1/Institution/InstitutionUserController.php
backend/app/Http/Requests/Institution/InstitutionUserCreateRequest.php
backend/app/Actions/Institution/CreateInstitutionUser.php
backend/tests/Feature/Institution/InstitutionUserCreateApiTest.php
```

Reuse `backend/app/Http/Resources/Institution/InstitutionUserResource.php`
byte-for-byte unchanged. Also update only the `S03-BE-004` row in
`tasks/STAGE_03_TASK_INDEX.md` to
`In Progress / Not started / Not started`. Keep this detailed task's status
`Approved` and preserve the paired prompt byte-for-byte before Phase 2.

Run all required automated checks, scope/secret checks, and the manual smoke
rule from Section 10. Inspect the complete diff including the owner-prepared
task/prompt. Do not commit or push.

### Phase 2 — Read-Only Acceptance Gate

Re-read the authority task, accepted S03-INT-001/S03-BE-003 contracts, locked
references, complete diff, code/tests, validation/tenant/atomicity/race/error/
first-login/no-side-effect evidence, and smoke result. Phase 2 is strictly
read-only:

```text
no edits or auto-fix/write-format
no task/index/README bookkeeping edits
no staging or commit
no push, PR, or merge
no self-fixing findings
```

Classify findings:

- `P1`: authorization/tenant or secret/password disclosure, protected-field
  control, destructive Git, or violation of the read-only gate;
- `P2`: material request/validation/resource/persistence/atomicity/race/error/
  first-login/test mismatch, scope drift, or workflow/bookkeeping defect;
- `P3`: non-blocking observation that does not affect correctness, security,
  required evidence, or maintainability acceptance.

Any unresolved P1 or P2 results in:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start `S03-BE-005`. Report every P3 finding;
P3 alone does not block acceptance.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 PASS with no unresolved P1/P2.

1. Change only this detailed task's metadata status from `Approved` to
   `Accepted`; do not rewrite its approved behavior.
2. Prepare only the `S03-BE-004` index row as
   `Accepted / PASS / Delivered` in the delivery commit.
3. Update `tasks/README.md` truthfully: Stage 3 remains `In Progress`,
   S03-BE-004 is the delivered task, and `S03-BE-005` is the next execution
   gate.
4. Preserve every later task's truthful status; do not mark S03-BE-005
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
   feat(institution): add user creation API
   ```

   Body:

   ```text
   Task: S03-BE-004
   ```

10. Push the exact task branch, open a PR to `main`, verify its base/head/diff,
    and merge only when required checks are safe/green and merge is permitted.
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
changed file, exact request/resource/persistence behavior, every acceptance
criterion and command/result, validation/protected/race/transaction/tenant/auth/
first-login/disclosure/no-side-effect/safe-error evidence, S03-BE-003 and
Platform regressions, P1/P2/P3 findings, smoke status/blocking decision,
scope/secret checks, bookkeeping result, and complete Git/PR/merge/local-
remote-clean evidence.

State:

```text
No User update/lifecycle/password reset, Institution Admin/Platform Owner
creation, relationship, Group, settings, category, or Learning behavior was
implemented.
Next implementation gate: S03-BE-005.
```
