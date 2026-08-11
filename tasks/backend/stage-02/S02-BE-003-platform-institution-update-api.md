# Codex Task: Platform Institution Basic-Profile Update API

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-BE-003` |
| Status | `Accepted` |
| Stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Backend / platform institution basic-profile update` |
| Priority | `High` |
| Depends on | `S02-BE-002` accepted, delivered, and present on current `origin/main` |
| Unblocks | `S02-BE-004`; later `S02-FE-006` integration |
| Repository | `https://github.com/Shoxrux2017/testlabuz.git` |
| Target branch | `task/s02-be-003-update-institution` |
| Execution model | One focused implementation task followed by read-only acceptance and safe GitHub delivery |

---

## 2. Goal

Implement the approved Platform Owner endpoint for editing the basic
platform-level profile of one existing educational institution:

```text
PATCH /api/v1/platform/institutions/{institution}
```

The endpoint must let an active, password-complete `platform_owner` update only:

```text
name
type
contact_email
contact_phone
address
description
```

It must preserve every field outside that allowlist, including institution
lifecycle state, creator attribution, settings, user data, and timestamps that
are not naturally managed by Eloquent.

This task is complete only when authorization, strict request validation,
partial-update semantics, persistence isolation, explicit API serialization,
PostgreSQL-backed tests, and the accepted Git workflow all pass.

### Scope boundary

This task updates basic profile metadata only. It does not:

- activate or deactivate an institution;
- change `status` or `deactivated_at`;
- update `institution_settings`;
- create or manage Institution Admin accounts;
- add dashboard/statistics behavior;
- update institution users or educational records;
- add a generic platform-owner bypass to institution-scoped APIs;
- add hard deletion, audit infrastructure, billing, support, or impersonation.

---

## 3. Current Accepted Context

Treat current `origin/main` as the implementation source of truth. Do not rely
on this planning snapshot where the repository can be inspected directly.

The closed Stage 1 baseline already provides:

- Laravel REST API under `/api/v1`;
- PostgreSQL runtime and UUID identity persistence;
- `institutions`, `users`, and `institution_settings` tables/models/factories;
- `InstitutionType` and `InstitutionStatus` enums;
- Laravel Sanctum authentication;
- active-account and mandatory-password-change gates;
- role middleware for `platform_owner`;
- centralized API success/error conventions;
- PostgreSQL-backed automated tests;
- accepted task/review/delivery workflow.

The current accepted institution schema contains:

```text
id                    uuid, primary key
name                  varchar(200), not null
type                  varchar(40), not null, constrained
status                varchar(20), not null, active|inactive
contact_email         varchar(254), nullable
contact_phone         varchar(50), nullable
address               text, nullable
description           text, nullable
created_by_user_id    uuid, nullable
deactivated_at        timestamptz, nullable
created_at            timestamptz, not null
updated_at            timestamptz, not null
```

Accepted Stage 2 dependencies must provide:

- `S02-BE-001`: Platform Institution list/detail route group, authorization,
  lookup/query style, and explicit institution Resources;
- `S02-BE-002`: atomic Institution creation, validated public profile fields,
  safe creator attribution, and automatic settings initialization.

Reuse accepted patterns when they own the same responsibility. Do not create a
second competing institution namespace, serializer, or authorization style.

---

## 4. Dependency and Stage-Control Gate

Before implementation, verify all of the following from the repository and
remote state:

1. Stage 1 is `Closed` and its closure review is `PASS`.
2. `S02-BE-001` is `Accepted`, delivered, and present on `origin/main`.
3. `S02-BE-002` is `Accepted`, delivered, and present on `origin/main`.
4. `tasks/STAGE_02_TASK_INDEX.md` exists and contains the approved 17-task
   Stage 2 decomposition.
5. This detailed task exists at:

   ```text
   tasks/backend/stage-02/S02-BE-003-platform-institution-update-api.md
   ```

6. The task status is `Approved` before implementation begins.
7. No conflicting institution-update implementation is already present.

If any dependency is not accepted/delivered, if `main` is not synchronized, or
if repository state contradicts this task, stop and report `BLOCKED` with exact
evidence. The only permitted preparation-time worktree changes are the exact
two approved `S02-BE-003` files named below; any other unexplained change is a
blocker. Do not implement on top of an unaccepted predecessor.

This task may update only the truthful `S02-BE-003` lifecycle state in the
Stage 2 index. It must not approve, create detailed contracts for, implement,
or change the state of later tasks.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

1. Read root `AGENTS.md`.
2. Read `backend/AGENTS.md` and any nearer applicable instructions.
3. Read `tasks/README.md` and `tasks/STAGE_02_TASK_INDEX.md`.
4. Read this task completely.
5. Read the accepted `S02-BE-001` and `S02-BE-002` task contracts and evidence.
6. Read only the referenced locked sections from `docs/01–09`.
7. Inspect current institution routes, controllers, requests, Resources,
   actions, model, enums, factories, migrations, and focused tests.
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
    tasks/backend/stage-02/S02-BE-003-platform-institution-update-api.md
    tasks/backend/stage-02/S02-BE-003-CODEX-PROMPT.md
    ```

    No other modified, staged, deleted, renamed, or untracked path is allowed.
    Do not commit either preparation file on `main`.

11. Create/switch to exactly:

    ```text
    task/s02-be-003-update-institution
    ```

12. Carry the two approved preparation files onto the task branch, then verify
    that `main` itself was not changed.
13. Use the accepted PostgreSQL-capable runtime. Do not substitute SQLite.
14. Do not commit or push during implementation or the read-only review.

### 5.2 Route and middleware contract

Add only this route to the accepted Platform Owner institution route group:

```text
PATCH /api/v1/platform/institutions/{institution}
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
- any authenticated non-Platform-Owner role whose own account and Institution
  gates pass returns `403 forbidden`;
- an otherwise active Institution user from an inactive Institution returns
  the accepted `403 institution_inactive` before role authorization;
- active, password-complete Platform Owner may target an active or inactive
  institution through this explicit platform route;
- missing or malformed institution UUID returns `404 resource_not_found` for
  an authorized actor;
- unauthenticated/wrong-role requests preserve the accepted middleware
  precedence and must not disclose whether the target Institution exists;
- failure responses must not leak SQL, model internals, or hidden record data.

Do not:

- add an ordinary institution-scoped update route;
- add a Platform Owner universal bypass to normal tenant routes;
- trust a client-supplied role or institution ownership value;
- hide authorization only in Flutter;
- return HTML redirects for API authorization failures.

### 5.3 Exact PATCH request contract

Content type:

```http
Content-Type: application/json
Accept: application/json
```

Example partial request:

```json
{
  "name": "Updated Name",
  "contact_email": "updated@example.uz",
  "description": null
}
```

Only these six top-level keys are allowed:

```text
name
type
contact_email
contact_phone
address
description
```

Unknown or protected keys must return `422 validation_failed`; they must not be
silently ignored. This includes attempts to send:

```text
id
institution_id
status
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
users
user_counts
```

The request body must be a JSON object and must contain at least one allowed
field. An empty object, array, or scalar is invalid.

### 5.4 Field validation and partial-update semantics

| Field | Presence | Validation and update semantics |
|---|---|---|
| `name` | optional; non-null when present | string; trim outer whitespace; non-empty after trimming; maximum 200 characters |
| `type` | optional; non-null when present | exact current value from `InstitutionType` |
| `contact_email` | optional/nullable | `null` clears; otherwise valid email string, maximum 254 characters |
| `contact_phone` | optional/nullable | `null` clears; otherwise string, maximum 50 characters; do not invent an E.164-only rule |
| `address` | optional/nullable | `null` clears; otherwise string using accepted request-size protection; do not invent a narrower business limit for the PostgreSQL `text` column |
| `description` | optional/nullable | `null` clears; otherwise string using accepted request-size protection; do not invent a narrower business limit for the PostgreSQL `text` column |

Required PATCH semantics:

- omitted fields remain exactly unchanged;
- explicit JSON `null` clears only the four nullable public fields;
- `name: null` and `type: null` are invalid;
- arrays, objects, and booleans are invalid for string fields;
- the enum allowlist comes from the accepted `InstitutionType` authority rather
  than duplicated drifting literals where the current code pattern permits;
- no institution-name, email, phone, or address uniqueness may be invented;
- do not accept a client-generated UUID;
- do not add status as a convenience field;
- do not update lifecycle fields indirectly;
- do not add an `Idempotency-Key`, ETag, `If-Match`, version, or optimistic-lock
  requirement not present in the locked contract;
- do not introduce extra normalization that changes product data beyond the
  accepted Laravel middleware/request conventions and the required name trim.

Supplying values equal to the current stored values is a valid request. It may
return the current resource without forcing an artificial timestamp change.

### 5.5 Focused update operation

Implement one focused application action/use case for the update.

The operation must:

1. receive the already authorized target Institution;
2. receive only validated allowlisted input;
3. apply only keys actually present in the PATCH payload;
4. persist the Institution once;
5. return the refreshed/current Institution for explicit serialization.

Never use raw request data such as:

```php
$institution->update($request->all());
```

Never infer allowed fields only from model fillable configuration. The HTTP
request allowlist is narrower and must be explicit.

A database transaction is not required for this single-row update unless the
accepted repository pattern safely uses one. Do not add unrelated multi-record
side effects merely to justify a transaction.

### 5.6 Protected-state preservation

For every successful update, preserve:

```text
id
status
created_by_user_id
deactivated_at
created_at
```

Allow Eloquent to maintain `updated_at` only when a real dirty write occurs.

Also preserve all related data:

- the existing `institution_settings` row and every value in it;
- all Institution Admin, Teacher, Student, and Parent rows;
- all user active/inactive and password-change state;
- all future institution-owned educational/history records;
- basic user counts exposed by accepted read endpoints.

Updating the profile of an inactive institution must not reactivate it, clear
`deactivated_at`, or restore institution-user access. Updating an active
institution must not deactivate it or populate `deactivated_at`.

### 5.7 Exact success response

On success return HTTP `200 OK`:

```json
{
  "data": {
    "id": "uuid",
    "name": "Updated Name",
    "type": "school",
    "status": "active",
    "contact_email": "updated@example.uz",
    "contact_phone": "+998...",
    "address": "Updated address",
    "description": null,
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-10T12:00:00Z"
  },
  "message": "Institution updated successfully."
}
```

Response rules:

- use exactly the public fields above and no additional fields;
- serialize UUID and enum values as strings;
- serialize nullable public fields as JSON `null` when cleared/absent;
- serialize timestamps as RFC 3339 / ISO 8601 UTC;
- return the complete current public profile, not only changed keys;
- do not expose `created_by_user_id`, creator details, or `deactivated_at`;
- do not expose settings, user identities, user counts, tokens, or learning data;
- do not return pagination metadata;
- use the exact success message above.

If accepted list/detail Resources expose different summary/detail data, do not
widen this mutation response merely for serializer reuse. Reuse an accepted
Resource only if it preserves this exact mutation contract cleanly.

### 5.8 Failure atomicity

All validation and authorization failures must occur before persistence.

For any failed request:

- none of the six profile fields may change;
- no protected institution field may change;
- no settings/user/related row may change;
- no partial response may claim success;
- centralized error handling must hide internal details.

Unexpected persistence errors return the accepted `500 server_error` envelope
without leaking SQL, constraints, paths, or stack traces.

---

## 6. Architecture and Code Organization

### 6.1 Thin HTTP layer

The controller/invokable endpoint should only:

1. receive the authorized route-bound Institution;
2. receive validated input;
3. call one focused update action;
4. return the explicit mutation Resource/envelope.

Do not place allowlist logic, persistence branching, or future lifecycle logic
inside an oversized controller.

### 6.2 Dedicated validation boundary

Use a focused Form Request or the established equivalent for:

- JSON object/at-least-one-field shape;
- exact top-level allowlist;
- present/nullable semantics;
- string/email/length validation;
- enum validation;
- normalized validated output.

Do not silently discard unknown or protected keys.

### 6.3 Focused action

Use one clearly named action/service such as the accepted project naming style
for `UpdateInstitution`. It must not absorb create, activate, deactivate,
settings, admin-account, dashboard, or generic repository responsibilities.

### 6.4 Explicit serialization

Use an API Resource or established explicit transformer. Do not return the
Eloquent model directly and do not expose fields based on future model changes.

### 6.5 Existing schema is sufficient

No migration, schema constraint, seed redesign, package, or dependency is
needed. If implementation appears to require one, stop and report the exact
reason instead of changing schema within this task.

### 6.6 Concurrency boundary

The locked MVP contract does not define optimistic locking for this endpoint.
Use normal PostgreSQL/Eloquent single-row update behavior. Do not invent row
versions, conflict codes, or client concurrency headers.

---

## 7. Relevant Files

Exact production filenames must follow the accepted repository structure after
inspection. The expected responsibility map is:

| Path / area | Action | Purpose |
|---|---|---|
| `tasks/backend/stage-02/S02-BE-003-platform-institution-update-api.md` | Preserve; mark Accepted only after Phase 2 PASS and delivery | Approved contract/audit trail |
| `tasks/STAGE_02_TASK_INDEX.md` | Update only truthful `S02-BE-003` state | Stage control |
| `backend/routes/api.php` or accepted split route file | Extend | Exact PATCH route under platform group |
| accepted Platform Institution controller namespace | Extend/create focused endpoint | Thin HTTP adapter |
| accepted Platform Institution request namespace | Add focused update request | Strict allowlist and PATCH validation |
| accepted institution action namespace | Add focused update action | Single-row profile mutation |
| accepted Institution mutation Resource | Reuse/extend only if exact | Public response contract |
| `backend/app/Models/Institution.php` | Change only if genuinely required | Existing persistence model; no fillable widening for protected fields |
| focused Platform Institution feature tests | Add/update | Authorization, validation, persistence, response, isolation |

Protected paths that must not change:

```text
docs/01–09
frontend/
docker/
backend/database/migrations/
backend/composer.json
backend/composer.lock
```

Do not create empty future-stage directories or unrelated abstractions.

---

## 8. Authoritative Specification References

| Source | Section | Authority for this task |
|---|---|---|
| `docs/01-business-overview.md` | `13. Multi-Institution Model`; `14. Platform Requirements` | Platform-level management must preserve institution separation and server-side authority |
| `docs/02-user-roles.md` | `1. Platform Owner / Super Admin` | Platform institution-management authority and daily-learning boundary |
| `docs/03-features.md` | `2. Platform Owner / Super Admin Features`; `14. MVP Feature Scope` | Edit basic Institution information only; advanced platform scope remains excluded |
| `docs/04-user-flows.md` | `Edit Institution Flow` | Select, edit, validate, persist, and show updated institution details |
| `docs/04-user-flows.md` | `Platform Owner / Super Admin Access Flow` | Explicit platform-only institution management |
| `docs/05-business-rules.md` | `BR-OV-007`, `BR-OV-012` | Historical preservation and server-side enforcement |
| `docs/05-business-rules.md` | `BR-INST-001`–`BR-INST-009` | Multi-institution ownership and separation |
| `docs/05-business-rules.md` | `BR-INST-010`–`BR-INST-015` | Lifecycle status and retention boundary |
| `docs/05-business-rules.md` | `BR-INST-019`–`BR-INST-021` | Basic platform-level edit authority; no daily-learning interference |
| `docs/06-roadmap.md` | `Stage 2 — Multi-Institution Platform Management` | Stage outcome and later-stage boundary |
| `docs/07-architecture.md` | `1.3`, `2.1`–`2.4`, `4.1`–`4.2` | Backend authority, REST/PostgreSQL, modular-monolith layering |
| `docs/08-database.md` | `3. Multi-Institution / Tenant Model` | Tenant root and Platform Owner exception |
| `docs/08-database.md` | `4.1 Table: institutions` | Exact columns, lengths, enums, constraints, and indexes |
| `docs/08-database.md` | `24.1 Institutions` | Deactivate; do not delete historical data |
| `docs/09-api-contracts.md` | `1`–`2` | Base URL, auth, envelopes, errors, timestamps, booleans, null |
| `docs/09-api-contracts.md` | `7. Super Admin Institution APIs` — `7.5` | Exact PATCH endpoint and platform-level allowlist |
| `docs/09-api-contracts.md` | Appendix B–C | Snake case, action endpoints, and client trust boundary |
| `tasks/README.md` | lifecycle/workflow | Required four-phase execution and delivery |
| root/backend `AGENTS.md` | applicable instructions | Clean architecture, validation, security, tests, scope control |

If any source conflicts, the locked `docs/01–09` control product behavior.
Stop and report the exact conflict; do not reinterpret it in code.

---

## 9. Relevant Business and Security Rules

1. Only `platform_owner` may use this platform endpoint.
2. Platform Owner is platform-scoped and normally has `institution_id = null`.
3. The explicit platform route does not create a tenant bypass elsewhere.
4. Only the six approved public profile fields may be changed.
5. Lifecycle state is changed only by `S02-BE-004` action endpoints.
6. Institution settings remain Institution Admin/future-stage responsibility.
7. Historical and related institution data must be preserved.
8. Updating one Institution must never affect another Institution.
9. Knowing an Institution UUID does not bypass authentication or role checks.
10. Flutter visibility is not an authorization boundary.
11. Client input cannot control actor, ownership, timestamps, or server state.
12. No hard delete or replacement of the Institution row is permitted.
13. Server validation is authoritative.
14. API responses expose only contract-approved public metadata.
15. No daily-learning data may be read or mutated through this endpoint.

---

## 10. Functional Requirements

1. Add exactly one PATCH route at the approved path.
2. Enforce accepted middleware order.
3. Resolve target by UUID with scope-safe `404` behavior.
4. Accept active or inactive target institutions.
5. Require a JSON object with at least one allowed key.
6. Reject every unknown/protected key with `422` before persistence.
7. Validate each present field using Section 5.4.
8. Apply only fields present in the payload.
9. Preserve omitted fields.
10. Clear nullable public fields only when explicitly `null`.
11. Reject `null` for `name` and `type`.
12. Preserve lifecycle/actor/identity fields.
13. Preserve settings, users, counts, and educational data.
14. Persist through one focused action.
15. Return exact `200` mutation envelope/resource/message.
16. Return centralized API errors for all expected failures.
17. Add no schema/dependency/frontend changes.
18. Add focused PostgreSQL-backed tests.
19. Keep accepted Stage 1 and predecessor tests green.
20. Complete read-only acceptance before Git delivery.

---

## 11. Validation and Error Contract

| Case | HTTP | Stable code / result |
|---|---:|---|
| Missing/invalid token | `401` | `authentication_required` |
| Inactive Platform Owner | `403` | `user_inactive` |
| Wrong-role Institution user from inactive Institution | `403` | `institution_inactive` before role authorization |
| Password change required | `403` | `password_change_required` |
| Authenticated wrong role after earlier account/Institution gates pass | `403` | `forbidden` |
| Missing/malformed Institution UUID for authorized actor | `404` | `resource_not_found` |
| Non-object or empty object | `422` where request validation can process it | `validation_failed` |
| Unknown/protected top-level key | `422` | `validation_failed`; no write |
| Invalid/null/too-long `name` | `422` | `validation_failed` |
| Invalid/null `type` | `422` | `validation_failed` |
| Invalid optional field type/email/length | `422` | `validation_failed` |
| Valid partial update | `200` | Exact updated public resource and message |
| Unexpected persistence failure | `500` | `server_error`; no internal details; no related side effects |

Do not introduce endpoint-specific machine codes such as:

```text
institution_update_forbidden
invalid_institution_type
institution_profile_locked
institution_already_updated
```

Do not convert ordinary validation into `409`. The current business state does
not define a lifecycle conflict for editing an active or inactive Institution.

---

## 12. Required Automated Tests

All persistence tests must use the accepted PostgreSQL runtime.

### 12.1 Route and authorization

- [ ] PATCH route exists exactly under `/api/v1/platform/institutions/{institution}`.
- [ ] No equivalent unauthenticated or ordinary institution route exists.
- [ ] No token returns `401 authentication_required`.
- [ ] Inactive Platform Owner returns `403 user_inactive`.
- [ ] Password-incomplete Platform Owner returns `403 password_change_required`.
- [ ] Each active non-Platform-Owner MVP role in an active Institution returns
      `403 forbidden`.
- [ ] An otherwise active wrong-role user from an inactive Institution returns
      `403 institution_inactive` before role authorization.
- [ ] Wrong-role denial changes no database value.
- [ ] Active/password-complete Platform Owner can update active Institution.
- [ ] Active/password-complete Platform Owner can update inactive Institution.
- [ ] Unknown/malformed UUID returns `404 resource_not_found` for an
      authorized actor without weakening denial precedence for other actors.

### 12.2 Request validation

- [ ] Empty JSON object is rejected.
- [ ] Array/scalar body is rejected where Laravel request validation can process it.
- [ ] Each allowed field succeeds independently with all others omitted.
- [ ] Multiple allowed fields succeed together.
- [ ] Whitespace-only, null, non-string, and over-200 `name` are rejected.
- [ ] Name is trimmed and persisted non-empty.
- [ ] Every current `InstitutionType` value is accepted.
- [ ] Unknown/null/non-string type is rejected.
- [ ] Valid email and explicit `null` are accepted.
- [ ] Invalid/over-254 email is rejected.
- [ ] Contact phone enforces nullable string and maximum 50 only.
- [ ] Address/description accept string or explicit `null`.
- [ ] Array/object/boolean optional fields are rejected.
- [ ] Every protected/unknown key is rejected, not ignored.
- [ ] No invented name/contact uniqueness blocks equal values across institutions.

### 12.3 Partial update and persistence

- [ ] Only supplied allowlisted fields change.
- [ ] Omitted public profile fields remain byte/value equivalent.
- [ ] Explicit `null` clears each nullable public field.
- [ ] Same-value request succeeds without requiring fake timestamp movement.
- [ ] Institution UUID remains unchanged.
- [ ] `created_by_user_id` remains unchanged.
- [ ] `status` and `deactivated_at` remain unchanged for active target.
- [ ] `status` and `deactivated_at` remain unchanged for inactive target.
- [ ] `created_at` remains unchanged.
- [ ] No second Institution row is created.
- [ ] Updating Institution A changes no field on Institution B.

### 12.4 Related-data isolation

- [ ] Existing settings row is unchanged across all columns.
- [ ] Existing Institution users are unchanged.
- [ ] User counts before/after remain correct through accepted read API.
- [ ] No Institution Admin or other user is created.
- [ ] No lifecycle, access-restoration, or account-status side effect occurs.
- [ ] No educational record is changed or exposed.

### 12.5 Response contract

- [ ] Success status is exactly `200`.
- [ ] `data` contains exactly the public mutation fields in Section 5.7.
- [ ] `message` is exactly `Institution updated successfully.`
- [ ] Complete current profile is returned, including omitted-but-preserved fields.
- [ ] Cleared nullable values serialize as JSON `null`.
- [ ] Enum and UUID values serialize as strings.
- [ ] Timestamps are RFC 3339/ISO 8601 UTC.
- [ ] Creator, deactivation timestamp, settings, counts, users, tokens, and learning data are absent.
- [ ] Error envelopes preserve accepted `message/code/errors/request_id` contract.

### 12.6 Regression

- [ ] Accepted institution list/detail behavior remains green.
- [ ] Accepted atomic create/settings initialization remains green.
- [ ] Accepted auth/session/password/role tests remain green.
- [ ] Full backend suite passes against PostgreSQL.

---

## 13. Quality Gates and Verification

Run inside the accepted PostgreSQL-capable backend runtime. If host PHP lacks
`pdo_pgsql`, use the accepted Docker runtime; never substitute SQLite.

Required equivalent checks:

```text
php artisan route:list --path=api/v1/platform/institutions
php artisan test --filter=PlatformInstitutionUpdat
php artisan test
vendor/bin/pint --test
composer validate --strict
```

Use and report the actual focused test class/filter implemented by the
repository if it differs from the illustrative filter above.

Before the read-only acceptance gate:

```text
git status --short
git diff HEAD --check
git diff HEAD --stat
git diff HEAD
git status --short -- docs frontend docker backend/database/migrations backend/composer.json backend/composer.lock
git diff HEAD -- docs frontend docker backend/database/migrations backend/composer.json backend/composer.lock
```

Expected protected-path result:

- no locked docs change;
- no frontend change;
- no Docker change;
- no migration/schema change;
- no Composer dependency change.

`git diff main...HEAD` is not an acceptable substitute here: before Phase 3
there is intentionally no implementation commit, so that comparison would miss
the working-tree result. Treat `git status --short` as the authoritative path
inventory, inspect the complete `git diff HEAD`, and read every untracked file
listed by status in full. The Phase 2 reviewer must account for modified,
staged, deleted, renamed, and untracked files without staging them.

Inspect the complete diff for:

- secrets, credentials, tokens, `.env` content, private keys/certificates;
- raw model serialization;
- `$request->all()` or equivalent mass assignment;
- silent dropping of unknown/protected keys;
- client-controlled actor/lifecycle/settings/timestamp fields;
- write of omitted PATCH fields;
- unintended null clearing;
- create/lifecycle/settings/admin/dashboard scope creep;
- related-row side effects;
- duplicated enums or validation drift from accepted create behavior;
- direct changes to locked docs/schema/dependencies/frontend;
- unrelated refactors or later-task implementation.

---

## 14. Manual Smoke Check

Using controlled local/test data and the real Laravel/PostgreSQL runtime:

1. Authenticate an active, password-complete Platform Owner.
2. Select an Institution created through accepted `S02-BE-002`.
3. Record its full profile, lifecycle fields, settings, and user counts.
4. PATCH only `name` and verify exact `200` envelope/message.
5. Confirm every omitted profile field stayed unchanged.
6. PATCH one nullable field to `null` and confirm it clears.
7. Attempt to PATCH `status` and confirm `422` with zero database changes.
8. Attempt the same valid profile update as a wrong role and confirm `403`.
9. Open accepted Institution detail and verify the new profile appears.
10. Confirm lifecycle fields, settings, users, and user counts are unchanged.
11. Repeat one profile update on an inactive Institution and confirm it remains
    inactive with the same `deactivated_at` and no access restoration.

Use controlled data only. If manual verification cannot run, report `NOT RUN`
with the exact reason; do not claim it passed.

---

## 15. Explicit Non-Goals

Do not implement or change:

- Institution activate/deactivate (`S02-BE-004`);
- Platform dashboard aggregates (`S02-BE-005`);
- Institution Admin APIs (`S02-BE-006`/`S02-BE-007`);
- any Flutter UI/data integration (`S02-FE-*`);
- `institution_settings` or understanding categories;
- Institution user management;
- support tickets, support status, last-activity invention;
- billing, subscription, license, storage-plan fields;
- global settings;
- audit-log table or event subsystem;
- hard delete, merge, transfer, or replacement of Institution;
- optimistic locking, row version, ETag, or `Idempotency-Key` contract;
- advanced analytics, exports, reports, notifications;
- impersonation or Platform Owner access to daily learning data;
- schema/migration/enum expansion;
- package/dependency upgrades;
- unrelated cleanup/refactoring;
- creation of later detailed task files or Codex prompts.

---

## 16. Stop Conditions

Stop and report `BLOCKED` before implementation or delivery when:

- `S02-BE-001` or `S02-BE-002` is not Accepted/delivered on `origin/main`;
- local `main` is not synchronized or the working tree contains anything other
  than the exact two permitted `S02-BE-003` preparation files;
- `origin` is missing, unexpected, or unsafe;
- the approved task/index is missing or materially contradictory;
- locked `docs/01–09` conflict with this task;
- an existing update endpoint materially conflicts with this contract;
- exact behavior would require a product decision absent from locked sources;
- a schema/dependency/frontend/locked-doc change appears necessary;
- the task would require lifecycle/settings/user/admin/dashboard implementation;
- PostgreSQL verification cannot be run and no accepted equivalent exists;
- credentials, authorization, branch protection, or remote access block safe delivery.

Do not silently broaden scope, guess a business rule, rewrite shared history, or
work around a protected workflow.

---

## 17. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git Preflight

1. Complete Sections 4 and 5.1.
2. Create/switch to:

   ```text
   task/s02-be-003-update-institution
   ```

3. Ensure this approved task and prompt are on the task branch.
4. Confirm that no preparation file was committed directly on `main`.
5. Update only the `S02-BE-003` lifecycle state in the Stage 2 index to
   `Approved` if needed; preserve all other truthful states.
6. Do not commit or push.

### Phase 1 — Implementation

Implement only this approved task.

Run focused authorization/validation/PATCH/persistence/response/isolation
tests, predecessor regression tests, the complete backend suite, route
inspection, Pint, Composer validation, scope checks, security review, and
manual smoke where possible.

Do not commit or push during Phase 1.

### Phase 2 — Read-Only Acceptance Gate

After implementation is complete, re-read:

- this approved task;
- applicable `AGENTS.md` files;
- all referenced locked sections;
- accepted `S02-BE-001`/`S02-BE-002` contracts and preserved behavior;
- complete diff and protected-path checks;
- route/request/controller/action/resource implementation;
- focused/full test results;
- authorization, validation, protected-field, leakage, and isolation evidence.

During Phase 2:

- make no file edits;
- run no auto-fix command;
- do not stage files;
- do not commit;
- do not push;
- do not merge;
- do not fix findings after the gate starts.

Finding severity:

- `P1`: authorization, protected-field mutation, data-integrity, secret, or
  contract-breaking blocker;
- `P2`: material validation/PATCH/response/architecture/test/scope mismatch;
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
   - `S02-BE-003 = Accepted`;
   - review = `PASS`;
   - delivery finalizes only after merge;
   - preserve all other tasks' truthful state.
3. Apply only necessary lifecycle bookkeeping in `tasks/README.md`.
4. Re-run final diff, protected-path, security, format, tests, and secret checks.
5. Stage only approved files.
6. Create one focused commit:

   ```text
   feat(institutions): add platform institution update API
   ```

   Commit body:

   ```text
   Task: S02-BE-003
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

Do not start `S02-BE-004`.

---

## 18. Acceptance Criteria

- [ ] Preconditions and predecessor delivery are verified.
- [ ] Work uses the exact approved task branch.
- [ ] PATCH route exists at the exact approved path.
- [ ] Accepted middleware order is preserved.
- [ ] Only active/password-complete Platform Owner can update.
- [ ] Wrong-role and inactive-Institution middleware precedence is preserved.
- [ ] Active and inactive target institutions can receive profile updates.
- [ ] Unknown/malformed UUID returns accepted `404` envelope for an authorized
      actor without leaking target existence to denied actors.
- [ ] Only six public profile keys are accepted.
- [ ] At least one allowlisted key is required.
- [ ] Unknown/protected keys are rejected with `422`, not ignored.
- [ ] Partial-update and explicit-null semantics are correct.
- [ ] Validation matches schema/enum/accepted create behavior.
- [ ] Only supplied public fields change.
- [ ] Lifecycle, actor, identity, and creation timestamp are preserved.
- [ ] Settings, users, counts, and educational data are preserved.
- [ ] Update of Institution A cannot affect Institution B.
- [ ] Exact `200` response/resource/message is returned.
- [ ] No protected/private data leaks.
- [ ] Controller/request/action/resource responsibilities stay focused.
- [ ] No schema, dependency, docs, frontend, Docker, or later-task scope change.
- [ ] Phase 2 inventories and reviews every tracked and untracked changed path;
      it does not rely on a commit-range diff that omits working-tree changes.
- [ ] Required PostgreSQL-backed tests pass.
- [ ] Full backend/regression checks pass.
- [ ] Manual smoke passes or is truthfully reported `NOT RUN` with reason.
- [ ] Phase 2 is genuinely read-only and returns PASS with no P1/P2.
- [ ] Accepted delivery is merged to `origin/main`.
- [ ] Local `main == origin/main` and working tree is clean.

---

## 19. Required Codex Final Report

Return a concise evidence-backed report containing:

1. `FINAL STATUS: ACCEPTED`, `NOT ACCEPTED`, `DELIVERY BLOCKED`, or `BLOCKED`.
2. Task ID and task title.
3. Branch name and relevant commit/PR/merge evidence when delivered.
4. Changed files grouped by responsibility.
5. Exact route and accepted field allowlist.
6. Authorization/middleware evidence.
7. PATCH/nullable/protected-field behavior implemented.
8. Response and error contract summary.
9. Focused tests and exact results.
10. Full backend/style/composer results.
11. Protected-path/scope/security review result.
12. Manual smoke result.
13. Phase 2 findings by severity, even when none.
14. Delivery state and proof that local `main == origin/main` and tree is clean.
15. Explicit confirmation that `S02-BE-004` was not started.
