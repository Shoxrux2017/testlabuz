# Codex Task: Atomic Platform Institution Creation API

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-BE-002` |
| Roadmap stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Backend / platform institution creation` |
| Status | `Accepted` |
| Approved on | `2026-08-10` |
| Depends on | `S02-BE-001 — Platform Institution List & Detail API (Accepted and delivered to origin/main)` |
| Blocks | `S02-BE-003`; `S02-BE-006`; `S02-FE-005` |

This task is approved for Codex execution only after its accepted dependency is
present on current `origin/main`.

Codex must still enforce every dependency, Git preflight, scope, testing,
read-only acceptance, and GitHub delivery gate defined below.

---

## 2. Goal

Implement the Stage 2 backend mutation that lets an authenticated, active,
password-complete Platform Owner create one educational institution.

The accepted result must provide this real PostgreSQL-backed endpoint:

```text
POST /api/v1/platform/institutions
```

One valid request must atomically create:

1. one `institutions` row containing only the approved platform-level fields;
2. one `institution_settings` row for the same institution UUID;
3. the locked safe operational settings defaults; and
4. the authenticated Platform Owner as `created_by_user_id`.

The institution and settings row are one business operation. If either write
fails, neither row may remain committed.

Every non-Platform-Owner role must be denied by the backend. The client must
not be able to choose ownership/actor fields, settings defaults, educational
policy, timestamps, or identifiers.

This task creates institutions only. It does not edit an existing institution,
activate/deactivate it after creation, create Institution Admin accounts, or
add frontend behavior.

---

## 3. Current Accepted Context

Repository:

```text
G:\project\testlabuz
```

Approved GitHub remote:

```text
https://github.com/Shoxrux2017/testlabuz.git
```

Verified preparation-time baseline:

- Stage 1 is `Closed` and Stage DoD is `PASS`;
- all 13 Stage 1 tasks are accepted and delivered;
- Stage 1 closure merge was observed on `main` at
  `b6c840a9dc935f6a9b2a87a63e5fc99352782ed8`;
- `S02-BE-001` had been prepared but was not yet present on GitHub `main` when
  this contract was authored;
- no Stage 2 product implementation was present on that preparation-time
  `main`.

The accepted Stage 1 backend already contains:

- Laravel 13 under `backend/`;
- PostgreSQL-backed runtime and tests;
- UUID `institutions`, `users`, and `institution_settings` persistence;
- exact `InstitutionType`, `InstitutionStatus`, and `UserRole` enums;
- the `Institution`, `InstitutionSetting`, and `User` models/relationships;
- database constraints for institution types/statuses and settings values;
- `institutions.created_by_user_id` as a nullable FK to `users.id`;
- one settings row per institution through
  `institution_settings.institution_id` PK/FK;
- Sanctum Bearer authentication;
- active-account and first-login password gates;
- reusable role middleware;
- centralized API error envelopes.

At execution time, accepted `S02-BE-001` must additionally provide the platform
institution route group and read API foundation that this task extends.

Codex must independently fetch and inspect actual current `origin/main`. The
preparation-time facts and hash are evidence only; they are not permission to
skip dependency verification or assume the repository has not moved.

---

## 4. Dependency and Stage-Control Gate

Before production-code changes, Codex must prove all of the following from
repository evidence:

- `S02-BE-001` status is `Accepted`;
- its review result is `PASS`;
- its accepted implementation is merged into `origin/main`;
- `tasks/STAGE_02_TASK_INDEX.md` exists and matches the approved 17-task
  decomposition;
- the index records `S02-BE-001` as accepted/delivered;
- the two `S02-BE-001` GET routes and their accepted tests are green;
- no conflicting create-institution implementation already exists.

If any dependency proof is missing, return a blocker. Do not implement
`S02-BE-001` inside this task and do not silently combine the tasks.

This approved contract permits the Stage 2 index to record `S02-BE-002` as
`Approved` while it is executing. It does not authorize execution of any later
task. Preserve the truthful status of all other rows.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

Before implementation:

1. Read root `AGENTS.md` completely.
2. Read `backend/AGENTS.md` completely.
3. Read `tasks/README.md`.
4. Read this complete approved task.
5. Read the exact locked specification sections referenced in Section 8.
6. Read `tasks/STAGE_02_TASK_INDEX.md` and accepted `S02-BE-001` artifacts.
7. Inspect accepted platform institution routes/controllers/requests/resources,
   models, enums, migrations, middleware, error handling, and tests.
8. Verify approved `origin` exactly.
9. Fetch remote state safely.
10. Verify local `main == origin/main` through a safe fast-forward-only flow.
11. Verify the accepted PostgreSQL backend test runtime is usable.
12. Verify no unrelated or unsafe dirty state exists.

Required task branch:

```text
task/s02-be-002-create-institution
```

If the project owner saved only these two approved preparation files on an
otherwise clean local `main`:

```text
tasks/backend/stage-02/S02-BE-002-platform-institution-create-api.md
tasks/backend/stage-02/S02-BE-002-CODEX-PROMPT.md
```

they are permitted pre-task additions. Do not commit them directly on `main`.
Create the task branch immediately and carry them into the task branch.

Any other unexplained change is a blocker.

### 5.2 Route and authorization contract

Add only this route to the accepted Platform Owner institution route group:

```text
POST /api/v1/platform/institutions
```

Required middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:platform_owner
```

Requirements:

- reuse the exact group/middleware aliases accepted in `S02-BE-001`;
- authenticate and authorize before executing any write;
- use persisted `UserRole` authority only;
- never accept role, institution ownership, or actor authority from payload,
  headers, or query parameters;
- do not add a Platform Owner bypass to normal institution-scoped endpoints;
- do not weaken accepted account/password/role gates;
- do not add test-only production routes.

### 5.3 Exact request contract

Content type:

```http
Content-Type: application/json
Accept: application/json
```

Allowed JSON object:

```json
{
  "name": "Example School",
  "type": "school",
  "contact_email": "info@example.uz",
  "contact_phone": "+998...",
  "address": "Samarkand",
  "description": "Optional notes",
  "status": "active"
}
```

Only these seven top-level keys are allowed:

```text
name
type
contact_email
contact_phone
address
description
status
```

Unknown keys must return `422 validation_failed`; they must not be silently
ignored. This includes attempted client control of:

```text
id
institution_id
created_by_user_id
deactivated_at
created_at
updated_at
settings
timezone
learning_material_max_mb
student_submission_max_mb
acceptable_score_difference
blitz_timer_start_mode
student_result_release_mode
parent_result_release_mode
role
user_counts
```

Validation contract:

| Field | Presence | Validation and normalization |
|---|---|---|
| `name` | required | string; trim outer whitespace; non-empty after trimming; maximum 200 characters |
| `type` | required | exact value from current `InstitutionType` enum |
| `contact_email` | optional/nullable | valid email string; maximum 254 characters |
| `contact_phone` | optional/nullable | string; maximum 50 characters; do not invent an E.164-only rule |
| `address` | optional/nullable | string; use accepted request-size protection; do not invent a narrower undocumented business limit for the PostgreSQL `text` column |
| `description` | optional/nullable | string; use accepted request-size protection; do not invent a narrower undocumented business limit for the PostgreSQL `text` column |
| `status` | required | exact `active` or `inactive` from current `InstitutionStatus` enum |

Further rules:

- the body must be a JSON object, not an array/scalar;
- optional absent/null fields persist as `null`;
- reject arrays/objects/booleans for optional string fields;
- do not accept a client-generated institution UUID;
- do not add institution-name or contact uniqueness not present in locked
  specification/schema;
- do not add an idempotency-key requirement: Create Institution is not in the
  locked MVP list of mutations that require `Idempotency-Key`;
- do not accept educational settings in this endpoint, even when values equal
  the locked defaults.

### 5.4 Atomic application operation

Implement one focused application action/service for the create operation.

Inside one database transaction it must:

1. derive the authenticated Platform Owner actor server-side;
2. create a UUID-backed `Institution` with the validated platform fields;
3. set `created_by_user_id` to that actor's persisted UUID;
4. derive `deactivated_at` from the initial status as Section 5.5 defines;
5. create exactly one related `InstitutionSetting` row with the exact values
   in Section 5.6;
6. return the committed institution for explicit response serialization.

Atomicity is mandatory:

```text
institution insert succeeds
settings insert fails
→ transaction rolls back
→ zero new institution rows
→ zero new settings rows
```

Do not dispatch external side effects, seed users, or create a first
Institution Admin in this task.

### 5.5 Initial lifecycle and actor fields

Server-derived persistence rules:

| Field | Required value |
|---|---|
| `id` | Generated by the accepted UUID model behavior |
| `created_by_user_id` | Authenticated Platform Owner UUID |
| `status = active` | `deactivated_at = null` |
| `status = inactive` | `deactivated_at = authoritative server time` |
| `created_at` / `updated_at` | Server-generated authoritative timestamps |

The client must not provide or override any field in this table.

Creating an institution initially as `inactive` is an initial-state choice
already allowed by the locked Create request/status enum. It does not authorize
the separate activate/deactivate command behavior assigned to `S02-BE-004`.

### 5.6 Exact automatic settings initialization

For the new institution UUID, create exactly one `institution_settings` row in
the same transaction:

```text
institution_id = newly created institution UUID
timezone = Asia/Tashkent
learning_material_max_mb = 25
student_submission_max_mb = 15
acceptable_score_difference = null
blitz_timer_start_mode = null
student_result_release_mode = null
parent_result_release_mode = null
updated_by_user_id = null
```

Requirements:

- use explicit application values for this business initialization; do not
  rely only on database column defaults as the product operation's proof;
- do not invent educational-policy defaults;
- do not create understanding-category rows in this task;
- do not persist configurable Homework/Blitz attempt-count fields;
- do not accept any of these values from the request;
- do not make the settings row optional or defer it to a later job/event;
- retain the accepted one-to-one PK/FK relationship and all DB constraints.

### 5.7 Exact success response

On success return HTTP `201 Created`:

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
    "updated_at": "2026-08-07T15:00:00Z"
  },
  "message": "Institution created successfully."
}
```

Response rules:

- use exact field names and no additional fields;
- serialize UUID and enum values as strings;
- serialize nullable public fields as `null` when absent;
- serialize timestamps as RFC 3339 / ISO 8601 UTC;
- do not expose `created_by_user_id` or actor details;
- do not expose `deactivated_at` in this create response;
- do not expose settings or `updated_by_user_id`;
- do not expose user counts, users, tokens, private identities, or learning
  data;
- do not return pagination metadata;
- do not replace the locked message text.

If accepted `S02-BE-001` resources expose different list/detail-specific data,
do not widen this create response merely to reuse the wrong serializer. Reuse a
resource only when it can preserve this exact mutation contract cleanly.

### 5.8 Failure and rollback behavior

Expected validation/auth failures perform no database writes.

An unexpected database/application failure during either insert must:

- roll back the whole transaction;
- return the accepted centralized `500 server_error` envelope;
- avoid SQL/constraint/stack-trace details in the response;
- avoid logging secrets or the complete request body unnecessarily;
- leave no orphan institution and no partial settings state.

Do not convert an unexpected internal persistence failure into a false `201` or
generic successful partial result.

---

## 6. Architecture and Code Organization

### 6.1 Thin HTTP layer

The controller/invokable controller should only:

1. receive already validated input;
2. obtain the authenticated actor through the accepted auth boundary;
3. call the focused create action;
4. return the exact `201` resource/message envelope.

Do not place the transaction, settings policy, or actor rules directly in a
large route closure/controller method.

### 6.2 Dedicated validation boundary

Use a focused Form Request or the accepted equivalent in the same Platform
namespace introduced by `S02-BE-001`.

It must own:

- allowed-key enforcement;
- normalization needed before validation;
- exact required/nullable/type/length/enum rules;
- field-level validation errors.

Authorization still belongs to the route/middleware boundary; avoid duplicating
a divergent role system inside request validation.

### 6.3 Focused transactional action

Use one clearly named application action/service for institution plus settings
creation. It must make the transaction and fixed initialization visible during
review.

Avoid:

- generic repository layers with no project value;
- model observers/listeners whose hidden side effects make atomic behavior hard
  to review;
- factory use in production behavior;
- duplicated enum/default strings scattered across controller/tests;
- future admin/user/setup responsibilities.

Follow existing accepted Laravel project structure if `S02-BE-001` established
a more specific compatible convention.

### 6.4 Explicit serialization

Use an API Resource or accepted explicit serializer. Do not return the Eloquent
model directly and do not depend on `$hidden` as the only data-leak boundary.

### 6.5 Existing schema is sufficient

The accepted schema already supports the entire task. Do not add or modify:

- migrations;
- constraints/indexes;
- UUID strategy;
- Composer packages;
- database services.

If correct implementation genuinely requires a schema/dependency change, stop
and report the exact reason rather than expanding scope.

---

## 7. Relevant Files

Codex must inspect actual accepted `origin/main` before deciding final path
names.

| File or directory | Expected action | Reason |
|---|---|---|
| `AGENTS.md` | Read | Root authority/workflow |
| `backend/AGENTS.md` | Read | Backend rules |
| `tasks/README.md` | Inspect; lifecycle-only update after acceptance if required | Stage control |
| `tasks/STAGE_02_TASK_INDEX.md` | Verify; update only this task's lifecycle truth | Dependency/status control |
| accepted `S02-BE-001` contract/code/tests | Read and reuse | Required API foundation |
| `tasks/backend/stage-02/S02-BE-002-platform-institution-create-api.md` | Preserve; mark Accepted only after Phase 2 PASS | Approved contract/audit trail |
| `tasks/backend/stage-02/S02-BE-002-CODEX-PROMPT.md` | Preserve | Execution artifact |
| `backend/routes/api.php` | Modify | Register the protected POST route |
| accepted Platform institution controller/request/resource namespace | Extend/reuse where contract-compatible | Consistent API organization |
| focused Platform institution create action location under `backend/app/` | Create | Atomic business operation |
| `backend/app/Models/Institution.php` | Reuse; minimal change only if technically required | Accepted UUID model/relationships |
| `backend/app/Models/InstitutionSetting.php` | Reuse; minimal change only if technically required | Accepted settings model/relationship |
| `backend/app/Enums/InstitutionType.php` | Reuse | Canonical type values |
| `backend/app/Enums/InstitutionStatus.php` | Reuse | Canonical status values |
| `backend/tests/Feature/Platform/*` | Create/extend | Mutation, authorization, validation, transaction tests |
| `backend/tests/Unit/*` | Create only if a focused deterministic unit warrants it | Optional focused coverage |

Changes outside this list require a concrete technical necessity inside the
approved scope and must be reported.

Do not modify:

- locked `docs/01–09`;
- `frontend/`;
- `docker/`;
- database migrations/schema;
- accepted `S02-BE-001` list/detail semantics;
- Stage 1 auth/session/error semantics;
- Composer dependencies;
- CI configuration.

---

## 8. Authoritative Specification References

Locked specifications remain authoritative over this task.

| Document | Exact section | Requirement used by this task |
|---|---|---|
| `docs/02-user-roles.md` | `1. Platform Owner / Super Admin` | Platform Owner may create/manage institutions; daily-learning boundary |
| `docs/04-user-flows.md` | Platform Owner `Create Institution Flow` | Basic create form, validation, creation, and list/detail continuation |
| `docs/05-business-rules.md` | `BR-INST-001`–`BR-INST-009` | Multi-institution ownership and separation |
| `docs/05-business-rules.md` | `BR-INST-010`–`BR-INST-016B` | Status values, lifecycle preservation, exact safe initialization, no silent policy defaults |
| `docs/05-business-rules.md` | `BR-INST-017`–`BR-INST-021` | Settings isolation and Platform Owner authority/boundary |
| `docs/06-roadmap.md` | `7. Stage 2 — Multi-Institution Platform Management` | Create Institution is Stage 2; no daily teaching mutation |
| `docs/07-architecture.md` | `6–9` and applicable API/testing sections | Thin Laravel boundaries, transaction/service placement, authorization |
| `docs/08-database.md` | `3. Multi-Institution / Tenant Model` | Institution tenant root and ownership |
| `docs/08-database.md` | `4. Institutions` | Exact fields, lengths, enums, UUID, actor/lifecycle columns |
| `docs/08-database.md` | `8. Institution Settings` | One settings row, exact defaults/nulls/limits, `updated_by_user_id = null` for system initialization |
| `docs/08-database.md` | `28. Security and Institution Data Isolation` | Server-controlled ownership and safe persistence |
| `docs/09-api-contracts.md` | `1–2. API Contract Overview / General API Conventions` | `/api/v1`, JSON, UUID, success/error envelopes, UTC timestamps |
| `docs/09-api-contracts.md` | `5. Error Response Contract` | Stable error envelopes |
| `docs/09-api-contracts.md` | `7. Super Admin Institution APIs` — `7.3 Create Institution` | Exact endpoint, request, `201`, message, and automatic settings initialization |
| `docs/09-api-contracts.md` | `12.1 Get Assessment Settings` initialization note | Exact new-institution defaults and four null policy fields |
| `docs/09-api-contracts.md` | `33. Security and Authorization Contract` | Account/password/role authority |
| `docs/09-api-contracts.md` | `34. Idempotency and Concurrency Rules` | Create Institution does not require the MVP idempotency header |
| `AGENTS.md` | Applicable workflow, initialization, security, tests, and delivery sections | Project-wide authority |
| `backend/AGENTS.md` | Entire applicable file, especially Institution Initialization | Backend authority and implementation guardrails |

If a heading moved on current `main`, use its current exact heading and report
the change without changing the locked rule.

---

## 9. Relevant Business and Security Rules

1. Only `platform_owner` may call this platform mutation.
2. Authentication, active account, password completion, then role authorization
   must execute before product writes.
3. Actor and ownership fields are server-derived.
4. The request cannot select a role, actor, UUID, timestamps, lifecycle
   timestamp, or settings.
5. One create operation produces exactly one Institution and one settings row.
6. Both rows commit or both roll back.
7. `created_by_user_id` identifies the authenticated Platform Owner.
8. New settings use `Asia/Tashkent`, 25 MB, and 15 MB.
9. The four educational-policy settings start `null`.
10. `updated_by_user_id` is `null` during automatic system initialization.
11. Settings are isolated to the newly created institution UUID.
12. Initial status is only `active` or `inactive`.
13. Initial inactive state receives a server-derived `deactivated_at`.
14. No hard delete is introduced.
15. No Institution Admin/user/category/content/result record is created.
16. The response exposes only the locked public Institution fields.
17. Duplicate institution names are not rejected without a locked/schema
    uniqueness rule.
18. No raw SQL concatenation or client-controlled column/value authority is
    allowed.

---

## 10. Functional Requirements

1. Add exactly one production POST route.
2. Preserve accepted `S02-BE-001` GET routes and their behavior.
3. Enforce the exact middleware order.
4. Accept only a JSON object.
5. Accept only the seven approved request keys.
6. Require valid `name`, `type`, and `status`.
7. Validate nullable public contact/address/description fields as specified.
8. Use current canonical Institution enums.
9. Trim outer whitespace from name before persistence.
10. Reject a whitespace-only name.
11. Generate Institution UUID server-side.
12. Set actor/lifecycle/timestamps server-side.
13. Create Institution and settings in one DB transaction.
14. Persist every exact settings initialization value.
15. Persist no invented educational default.
16. Return exact HTTP `201` envelope/message/fields.
17. Return centralized `401`, `403`, `422`, or `500` errors as applicable.
18. Perform no writes on auth or validation failure.
19. Roll back both records on a controlled settings-write failure.
20. Avoid model-wide serialization and hidden data leakage.
21. Keep HTTP, validation, transaction, and serialization responsibilities
    separated.
22. Do not change schema, dependencies, locked docs, frontend, Docker, or CI.
23. Do not implement any later Stage 2 behavior.
24. Keep all accepted prior tests green on PostgreSQL.

---

## 11. Validation and Error Contract

| Case | HTTP | Stable code / result |
|---|---:|---|
| Missing/invalid token | `401` | `authentication_required` |
| Inactive Platform Owner | `403` | `user_inactive` |
| Password change still required | `403` | `password_change_required` |
| Authenticated wrong role | `403` | `forbidden` |
| Non-object/malformed request body | `422` where Laravel can parse the request into validation | `validation_failed` with field errors |
| Missing `name`, `type`, or `status` | `422` | `validation_failed` with field errors |
| Whitespace-only/too-long `name` | `422` | `validation_failed` |
| Invalid `type` or `status` | `422` | `validation_failed` |
| Invalid optional field type/email/length | `422` | `validation_failed` |
| Unknown/disallowed field | `422` | `validation_failed`; no write |
| Valid request | `201` | Exact data/message response |
| Unexpected insert/transaction failure | `500` | `server_error`; full rollback; no internal details |

Do not introduce endpoint-specific machine codes such as:

```text
institution_create_forbidden
invalid_institution_type
institution_settings_create_failed
duplicate_institution_name
```

Do not turn normal validation into `409`. Do not reveal whether internal rows,
constraints, or transaction steps existed before failure.

---

## 12. Required Automated Tests

Use descriptive PostgreSQL-backed tests and focused fixtures. Follow accepted
test organization from `S02-BE-001` where compatible.

### 12.1 Route and authorization tests

- [ ] POST route exists exactly at `/api/v1/platform/institutions`.
- [ ] Route uses the accepted platform middleware order.
- [ ] Active/password-complete Platform Owner can create.
- [ ] Missing token returns `401 authentication_required` and creates nothing.
- [ ] Inactive Platform Owner returns `403 user_inactive` and creates nothing.
- [ ] Password-incomplete Platform Owner returns
      `403 password_change_required` and creates nothing.
- [ ] Institution Admin returns `403 forbidden` and creates nothing.
- [ ] Teacher returns `403 forbidden` and creates nothing.
- [ ] Student returns `403 forbidden` and creates nothing.
- [ ] Parent returns `403 forbidden` and creates nothing.
- [ ] Payload/header/query attempts to claim `platform_owner` or actor authority
      fail and create nothing.

### 12.2 Request-validation tests

- [ ] Valid complete payload succeeds.
- [ ] Valid minimal payload with optional fields absent succeeds.
- [ ] Missing `name`, `type`, and `status` each fail at field level.
- [ ] Null/array/object/bool invalid forms are rejected where applicable.
- [ ] Outer name whitespace is normalized.
- [ ] Whitespace-only name fails.
- [ ] Name length 200 succeeds and 201 fails.
- [ ] Every locked Institution type succeeds.
- [ ] Unknown type fails.
- [ ] Both locked statuses succeed.
- [ ] Unknown status fails.
- [ ] Valid nullable email succeeds; malformed or >254 email fails.
- [ ] Contact phone up to 50 succeeds; >50 fails; no invented E.164-only
      rejection occurs.
- [ ] Address/description reject non-string values.
- [ ] Every representative disallowed system/settings/educational key returns
      `422` and creates nothing.
- [ ] Request array/scalar cannot create a record.
- [ ] Same-name institutions are not rejected by an invented uniqueness rule.

### 12.3 Persistence and initialization tests

- [ ] Created Institution ID is UUID.
- [ ] Every validated public field persists correctly.
- [ ] Nullable absent public fields persist `null`.
- [ ] `created_by_user_id` equals authenticated Platform Owner ID.
- [ ] Client cannot override `created_by_user_id`.
- [ ] Active initial status persists with `deactivated_at = null`.
- [ ] Inactive initial status persists with a non-null authoritative
      `deactivated_at`.
- [ ] Exactly one settings row exists for the Institution UUID.
- [ ] Settings `institution_id` matches created Institution ID.
- [ ] `timezone = Asia/Tashkent`.
- [ ] `learning_material_max_mb = 25`.
- [ ] `student_submission_max_mb = 15`.
- [ ] All four educational-policy values are `null`.
- [ ] `updated_by_user_id = null`.
- [ ] No Institution Admin, other user, category, group, or learning record is
      created.

### 12.4 Transaction and failure tests

- [ ] A controlled failure at settings persistence rolls back the Institution
      insert.
- [ ] Controlled failure leaves no settings row.
- [ ] Failure returns/flows through centralized `500 server_error` behavior
      without SQL/stack details.
- [ ] The rollback test uses no product-only test hook and leaves no persistent
      PostgreSQL trigger/function or global listener contamination.
- [ ] Validation/auth failures execute zero Institution/settings inserts.

The exact safe failure-injection technique may follow current test
architecture, but it must test the real transaction boundary. Do not weaken
production design merely to make rollback testing easy.

### 12.5 Response-contract tests

- [ ] HTTP status is exactly `201`.
- [ ] Message is exactly `Institution created successfully.`.
- [ ] `data` contains exactly the ten approved fields.
- [ ] UUID, enums, nulls, and UTC timestamps serialize correctly.
- [ ] Response omits actor IDs/details.
- [ ] Response omits `deactivated_at`.
- [ ] Response omits settings and policy values.
- [ ] Response omits user counts/users/learning data.
- [ ] Response omits pagination metadata.

### 12.6 Regression

All accepted prior behavior remains green, including:

- Stage 1 auth/session/status/password/role contracts;
- persistence/constraint tests;
- `S02-BE-001` list/detail/search/filter/sort/pagination/count contracts;
- centralized success/error conventions;
- PostgreSQL runtime behavior.

---

## 13. Quality Gates and Verification

Run inside the accepted PostgreSQL-capable backend runtime. If host PHP lacks
`pdo_pgsql`, use the accepted Docker runtime; never substitute SQLite.

Required equivalent checks:

```text
php artisan route:list --path=api/v1/platform/institutions
php artisan test --filter=PlatformInstitutionCreat
php artisan test
vendor/bin/pint --test
composer validate --strict
```

Use the actual focused test filter/name implemented by the repository and
report it exactly if it differs from the illustrative filter above.

Before the read-only acceptance gate:

```text
git status --short
git diff --check
git diff main...HEAD -- docs
git diff main...HEAD -- frontend
git diff main...HEAD -- docker
git diff main...HEAD -- backend/database/migrations
git diff main...HEAD -- backend/composer.json backend/composer.lock
```

Expected protected-path result:

- no locked docs change;
- no frontend change;
- no Docker change;
- no migration/schema change;
- no Composer dependency change.

Inspect the complete diff for:

- secrets, credentials, tokens, `.env` content, keys, certificates;
- direct model serialization;
- mass-assignment of unvalidated request data;
- client-controlled actor/UUID/settings fields;
- missing transaction boundary;
- partial writes or hidden observer/event side effects;
- invented educational defaults;
- wrong initial lifecycle timestamps;
- response leakage;
- unrelated refactors or later-task code.

---

## 14. Manual Smoke Check

Using controlled local/test data and the real Laravel/PostgreSQL runtime:

1. Authenticate an active, password-complete Platform Owner.
2. Submit a valid active-institution payload.
3. Verify exact `201` envelope/message/public fields.
4. Verify Institution actor UUID and `deactivated_at = null` directly in
   controlled database evidence.
5. Verify the matching settings row and every exact default/null value.
6. Create a second institution initially inactive and verify non-null
   `deactivated_at` plus identical settings initialization.
7. Confirm both institutions appear through accepted `S02-BE-001` list/detail.
8. Submit one disallowed settings/actor field and confirm `422` plus no row.
9. Repeat with one wrong role and confirm `403` plus no row.
10. Verify no Institution Admin/user/category record was created.

Do not intentionally break the shared development database to simulate the
rollback case; prove rollback through automated isolated-test evidence.

If manual verification cannot run, report `NOT RUN` with the exact reason. Do
not claim it passed.

---

## 15. Explicit Non-Goals

- Institution list/detail behavior beyond preserving accepted `S02-BE-001`.
- Institution profile update (`S02-BE-003`).
- Activate/deactivate command endpoints (`S02-BE-004`).
- Access restoration/blocking changes (`S02-BE-004`).
- Platform dashboard aggregates (`S02-BE-005`).
- Institution Admin account creation or management (`S02-BE-006/007`).
- Creating any user during Institution creation.
- Sending invitation/password/email/SMS.
- Frontend/Flutter Create Institution form (`S02-FE-005`).
- Institution learning-settings editing (Stage 3).
- Understanding-category initialization.
- Configurable attempt counts.
- User/group/topic/material/homework/blitz/submission/result/report data.
- Billing, subscription, license, storage-plan, support, or impersonation data.
- Global platform settings.
- Institution hard delete.
- Client-selected Institution UUID, creator, timestamps, or settings.
- Idempotency-key infrastructure for this endpoint.
- Duplicate-name prevention not present in locked schema.
- Schema/index/migration changes.
- Composer package/dependency additions.
- Docker/CI changes.
- Changes to locked `docs/01–09`.
- Refactoring accepted auth/session/role/read-API architecture unrelated to this
  mutation.
- Fixing the known Stage 1 non-blocking P3 for requests without
  `Accept: application/json`.
- Starting `S02-BE-003` or any later task.

---

## 16. Stop Conditions

Stop and report before product changes if:

- `S02-BE-001` is not accepted, PASS-reviewed, and delivered on
  `origin/main`;
- local `main` cannot safely synchronize with `origin/main`;
- `origin` is unexpected;
- unexplained dirty state exists;
- the task branch cannot be created safely;
- Stage 2 index is absent/conflicting or does not truthfully record the
  dependency;
- the accepted Platform route/read foundation is missing or materially broken;
- a conflicting create endpoint already exists;
- accepted Institution/Setting/User models, enums, relationships, or schema
  differ materially from the locked contract;
- the creator FK or settings PK/FK cannot support the operation;
- correct implementation requires a migration/schema/dependency change;
- locked documents conflict on request, defaults, initial status, response, or
  actor behavior;
- atomic creation cannot be guaranteed in the accepted PostgreSQL runtime;
- exact rollback cannot be tested safely without product-only hooks or
  destructive shared-database changes;
- safe authorization/error-envelope behavior cannot be preserved;
- correct work requires update/lifecycle/dashboard/admin/frontend scope;
- a pre-existing required quality gate fails materially;
- safe completion would require force-push, history rewrite, destructive
  cleanup, check bypass, or secret exposure.

Do not guess, weaken the contract, combine tasks, or modify locked docs to avoid
a stop condition.

---

## 17. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git Preflight

1. Complete Sections 4 and 5.1.
2. Create/switch to:

   ```text
   task/s02-be-002-create-institution
   ```

3. Ensure the approved task and prompt are on the task branch.
4. Update only the `S02-BE-002` lifecycle state in the Stage 2 index to
   `Approved` if needed; preserve all other truthful states.
5. Do not commit or push.

### Phase 1 — Implementation

Implement only this approved task.

Run focused mutation/authorization/validation/transaction/response tests, the
complete backend suite, accepted `S02-BE-001` regression, route inspection,
Pint, Composer validation, scope checks, security review, and manual smoke where
possible.

Do not commit or push during Phase 1.

### Phase 2 — Read-Only Acceptance Gate

After implementation is complete, re-read:

- this approved task;
- applicable `AGENTS.md` files;
- all referenced locked sections;
- accepted `S02-BE-001` contract and preserved behavior;
- complete diff;
- route/request/controller/action/resource implementation;
- transaction and settings initialization evidence;
- focused/full test results;
- authorization, validation, rollback, leakage, and protected-path evidence.

During Phase 2:

- make no file edits;
- run no auto-fix command;
- do not stage files;
- do not commit;
- do not push;
- do not merge;
- do not fix findings after the gate starts.

Finding severity:

- `P1`: security, authorization, partial-write/data-integrity, secret, or
  contract-breaking blocker;
- `P2`: material request/default/response/architecture/test/scope mismatch;
- `P3`: non-blocking observation.

If any P1/P2 remains, return:

```text
FINAL STATUS: NOT ACCEPTED
```

Then stop. Do not self-fix after the gate and do not start another task.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 passes with no P1/P2 finding.

1. Mark this task `Accepted`.
2. Update `tasks/STAGE_02_TASK_INDEX.md`:
   - `S02-BE-002 = Accepted`;
   - review = `PASS`;
   - delivery finalizes only after merge;
   - preserve other tasks' truthful status.
3. Apply only necessary lifecycle bookkeeping in `tasks/README.md`.
4. Re-run final diff, scope, security, format, tests, and secret checks.
5. Stage only approved files.
6. Create one focused commit:

   ```text
   feat(institutions): add atomic institution creation
   ```

   Commit body:

   ```text
   Task: S02-BE-002
   ```

7. Push the task branch to approved `origin`.
8. Open a Pull Request to `main` when tooling/authentication permits.
9. Never bypass required checks or branch protection.
10. Merge only when required checks pass and merge is permitted.
11. Synchronize local `main` from merged `origin/main` using safe
    fast-forward-only operations.
12. Verify local `main == origin/main`.
13. Verify `git status --short` is empty.

If Phase 2 passed but safe delivery cannot complete, return:

```text
FINAL STATUS: DELIVERY BLOCKED
```

If implementation, acceptance, and delivery all complete, return:

```text
FINAL STATUS: ACCEPTED
```

Never force-push, rewrite shared history, use `--no-verify`, modify global Git
configuration, silently replace `origin`, or commit credentials/tokens/private
keys/certificates/environment secrets.

Do not start `S02-BE-003`.

---

## 18. Acceptance Criteria

- [ ] `S02-BE-001` dependency and Git/runtime preflight pass.
- [ ] Stage 2 index truthfully records this task without authorizing later
      implementation.
- [ ] Exact POST route exists with the accepted middleware order.
- [ ] Only active/password-complete Platform Owner succeeds.
- [ ] Every wrong role/account/password case returns the stable accepted error
      and creates no data.
- [ ] Only the seven approved request keys are accepted.
- [ ] Required/nullable/type/length/enum validation matches Section 5.3.
- [ ] Client cannot control UUID, actor, lifecycle timestamp, settings, policy,
      or timestamps.
- [ ] Institution UUID and actor/lifecycle fields persist correctly.
- [ ] Institution and settings are created in one transaction.
- [ ] Exactly one settings row contains all exact defaults/nulls.
- [ ] Controlled settings failure proves complete rollback.
- [ ] Exact `201` data/message response is returned.
- [ ] Actor/settings/deactivation/user/learning data do not leak in response.
- [ ] No user, Institution Admin, category, or other future record is created.
- [ ] Accepted list/detail API and all Stage 1 behavior remain green.
- [ ] Controllers remain thin; validation/transaction/serialization boundaries
      are correctly placed.
- [ ] Focused and full PostgreSQL tests pass.
- [ ] Pint and strict Composer validation pass.
- [ ] Locked docs, frontend, Docker, schema, dependencies, and CI are unchanged.
- [ ] No adjacent Stage 2 behavior or unrelated refactor is included.
- [ ] Read-only acceptance gate reports no P1/P2 finding.
- [ ] Accepted result is delivered to `origin/main` and final Git state is
      clean.

---

## 19. Required Codex Final Report

Return all of the following:

1. **Final status** — exactly `ACCEPTED`, `NOT ACCEPTED`, or
   `DELIVERY BLOCKED`.
2. **Dependency/Git preflight** — `S02-BE-001` acceptance/delivery, remote,
   synchronized main, safe state, and branch evidence.
3. **Stage-control evidence** — index state before/after and no later-task
   execution.
4. **Implementation summary** — exact create operation now available.
5. **Changed files** — every changed file and why.
6. **Route/middleware evidence** — exact endpoint and security order.
7. **Request/validation evidence** — allowed keys, normalization, enums,
   negative cases, and no invented uniqueness/idempotency.
8. **Transaction evidence** — Institution/settings writes and controlled
   rollback proof.
9. **Initialization evidence** — actor, initial lifecycle, exact defaults,
   exact null policy values, and one-to-one linkage.
10. **Response evidence** — exact `201` fields/message and leakage exclusions.
11. **Authorization/security evidence** — positive Platform Owner and every
    negative role/account/password/client-authority case.
12. **Acceptance gate findings** — `No blocking or material findings` or exact
    P1/P2/P3 findings.
13. **Acceptance criteria** — PASS/FAIL evidence for every Section 18 item.
14. **Tests and quality gates** — exact commands, test counts, and results.
15. **Scope confirmation** — protected-path checks and every explicit non-goal.
16. **Manual smoke status** — passed, failed, or not run with exact reason.
17. **GitHub delivery evidence** — commit hash/subject, pushed branch, PR,
    checks/merge, local/main hashes, and final clean status.
18. **Risks, deviations, or blockers** — including pre-existing failures.

Do not start `S02-BE-003`.
