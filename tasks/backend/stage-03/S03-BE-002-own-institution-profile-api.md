# Codex Task: Own Institution Profile API

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-BE-002` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Backend` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Depends on | `S03-INT-001 — Accepted / PASS / Delivered`; execution order also requires `S03-BE-001 — Accepted / PASS / Delivered` |
| Blocks | `S03-BE-003`, `S03-FE-003`, `S03-INT-002` |

The file may be prepared before its dependencies are accepted, but
implementation must not start until both dependencies are
`Accepted / PASS / Delivered` on `origin/main`.

## 2. Goal

Allow an eligible Institution Admin to view and partially update only the
approved public profile fields of the authenticated user's own Institution.

Endpoints:

```text
GET   /api/v1/institution/profile
PATCH /api/v1/institution/profile
```

## 3. Current Context

Stage 2 delivered Institution persistence and Platform Owner Institution
resource/update patterns. S03-INT-001 defines a narrower Institution Admin
profile contract: no route Institution UUID, no `institution_id` input, and no
ability to change Institution type or lifecycle status.

The accepted Platform Owner update request cannot be reused because it permits
the Platform-only `type` field. Existing low-level conventions may be reused
only when they preserve this narrower authorization, validation, persistence,
and disclosure boundary.

## 4. Included Scope

- Register the exact own-profile GET/PATCH routes in the Institution Admin
  route group.
- Resolve the Institution solely through the authenticated actor.
- Add separate focused GET and PATCH request validation boundaries.
- Add thin controller methods, focused load/update actions, and one exact
  Institution profile resource.
- Perform at most one single-row Institution update and return refreshed
  server state; an exact no-op performs no database write.
- Add tenant, authorization, validation, disclosure, safe-error, and
  no-side-effect tests.
- Preserve accepted Platform Owner Institution behavior.
- During Phase 1, mark only the S03-BE-002 Stage 3 index row as
  `In Progress / Not started / Not started`.
- After Phase 2 PASS, perform only the exact acceptance/delivery bookkeeping in
  Section 13.

## 5. Exact API Contract

### 5.1 Middleware and Ownership

Middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:institution_admin
```

The authenticated User's `institution_id` is the sole tenant authority. No
Institution identifier is accepted from a route, query, body, or header. An
arbitrary header must never replace or alter the authenticated tenant scope.

### 5.2 Exact Public Resource

The resource contains exactly these keys in this order:

```json
{
  "id": "institution-uuid",
  "name": "Example School",
  "type": "school",
  "status": "active",
  "contact_email": "info@example.uz",
  "contact_phone": "+998...",
  "address": "Samarkand",
  "description": "Optional notes",
  "created_at": "2026-08-07T15:00:00Z",
  "updated_at": "2026-08-07T15:00:00Z"
}
```

Nullable fields remain present with JSON `null`. Timestamps use the accepted
UTC API representation. Never serialize creator/deactivation metadata,
settings, counts, users, tokens, relationship graphs, or learning data.

### 5.3 GET `/api/v1/institution/profile`

Accepted query keys:

```text
none
```

Accepted body:

```text
none
```

Only a request with zero raw body bytes is accepted. Any transmitted content
returns the existing `422 validation_failed` envelope with a field-level
`errors.body` entry, including whitespace-only content, `{}`, a keyed object,
`[]`, a scalar, JSON `null`, or malformed JSON. Every query key is rejected
with a field-level validation error.

Success is `200 OK` with exactly the normal single-resource `data` envelope
containing the resource from Section 5.2. GET success has no `message`, `meta`,
`links`, counts, or other top-level block. GET and every rejected GET attempt
perform no database or token mutation.

### 5.4 PATCH `/api/v1/institution/profile`

The body must be a JSON object containing at least one allowed key. An absent,
empty, malformed, scalar, array, or JSON `null` body returns
`422 validation_failed` with a field-level `errors.body` entry.

Strict editable allowlist:

```text
name
contact_email
contact_phone
address
description
```

Validation:

- `name`: when present, required, trimmed, non-empty string, max 200;
- `contact_email`: nullable string, valid email when non-null, max 254;
- `contact_phone`: nullable string, max 50;
- `address`: nullable string;
- `description`: nullable string;
- explicit JSON `null` clears a nullable field;
- omitted allowed fields retain their current values;
- duplicate contact values are allowed because no uniqueness contract exists;
- every query key and every unknown or protected JSON key rejects the entire
  request with `422 validation_failed` and zero partial mutation.

Protected-key tests must include at least:

```text
id
institution_id
type
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

Any other non-allowlisted key is also rejected.

For a real dirty update, persist only the validated present allowed fields,
allow Eloquent to update `updated_at`, reload the Institution, and return the
committed server state. This is one atomic single-row database update; do not
invent a multi-record transaction, optimistic-lock, or idempotency contract.

If submitted allowed values equal the current values after the required `name`
normalization, return `200 OK` without issuing an SQL update and without
changing `updated_at`. Return the current resource.

Every successful PATCH, including an exact no-op, returns the complete resource
from Section 5.2 and the exact message:

```text
Institution profile updated successfully.
```

No success or failure may alter UUID, Institution type/status/lifecycle,
creator data, settings, users, counts, tokens, or learning/history records.

## 6. Exact Files and Responsibilities

Codex must inspect current repository patterns but use these exact task paths:

| File | Expected action | Responsibility |
|---|---|---|
| `backend/routes/api.php` | Modify | Register exact GET/PATCH routes once |
| `backend/app/Http/Controllers/Api/V1/Institution/InstitutionProfileController.php` | Create | Thin `show`/`update` HTTP adapter |
| `backend/app/Http/Requests/Institution/InstitutionProfileShowRequest.php` | Create | Reject all GET query/body input |
| `backend/app/Http/Requests/Institution/InstitutionProfileUpdateRequest.php` | Create | PATCH body, allowlist, and validation boundary |
| `backend/app/Actions/Institution/ShowInstitutionProfile.php` | Create | Resolve the authenticated actor's Institution only |
| `backend/app/Actions/Institution/UpdateInstitutionProfile.php` | Create | Dirty-field/no-op-aware own-Institution update |
| `backend/app/Http/Resources/Institution/InstitutionProfileResource.php` | Create | Exact public serialization |
| `backend/tests/Feature/Institution/InstitutionProfileApiTest.php` | Create | Complete contract/security regression evidence |
| `backend/app/Models/Institution.php` | Inspect and preserve | Existing persistence is sufficient; do not modify |
| accepted Platform Institution code/tests | Inspect and preserve | Reuse safe conventions without broadening this contract |
| `tasks/STAGE_03_TASK_INDEX.md` | Modify only as Section 13 permits | Truthful execution/review/delivery state |
| `tasks/README.md` | Modify only after Phase 2 PASS | Truthful Stage 3 current/next gate |
| this detailed task | Status metadata only after Phase 2 PASS | Final accepted lifecycle state |
| paired Codex prompt | Preserve byte-for-byte | Approved execution authority |

No other application or test path may change. No frontend, migration, model,
settings/category, lifecycle, Platform contract, or locked-doc change belongs
in this task.

## 7. Authoritative References

| Document | Exact area | Requirement |
|---|---|---|
| `docs/02-user-roles.md` | Institution Admin | Own-Institution authority |
| `docs/03-features.md` and `docs/04-user-flows.md` | profile view/edit | Intended Stage 3 behavior |
| `docs/05-business-rules.md` | tenant/platform boundaries | Strict scope and backend authority |
| `docs/06-roadmap.md` | `8. Stage 3` | Institution profile scope |
| `docs/07-architecture.md` | API/authorization/testing | Required layering and enforcement |
| `docs/08-database.md` | Institutions | Existing fields and limits |
| `docs/09-api-contracts.md` | Section 8.1 after S03-INT-001 plus general conventions | Exact profile/envelope/error/timestamp contract |
| `backend/AGENTS.md` | entire applicable file | Backend organization, security, and quality gates |

## 8. Architecture, Security, and Error Requirements

- Do not route-bind or query an arbitrary Institution identifier.
- Pass the authenticated actor or its already-authorized Institution to the
  action; do not pass a raw client/request Institution ID.
- Do not accept `institution_id` or reuse a request that permits `type`.
- Request classes own input rejection; controller stays thin; actions own
  scoped loading/update behavior; the resource owns serialization.
- Never mass-assign raw request data. Update only validated present allowlisted
  values.
- No-op detection occurs before persistence and preserves the raw stored
  `updated_at` value.
- A real update uses the existing single-row Eloquent persistence behavior;
  no additional transaction or concurrency semantics are required.
- Preserve wrong-role/foreign-tenant non-disclosure and accepted middleware
  precedence.
- Arbitrary tenant-like headers are ignored for scope; they are not a new
  supported input contract.
- Unexpected load or update failures use the centralized safe
  `500 server_error` envelope and expose no SQL, exception, stack, path, tenant,
  or user detail.
- No sensitive values may be logged.

## 9. Acceptance Criteria

- [ ] Exact GET/PATCH routes exist once with exact middleware order.
- [ ] GET returns only the authenticated actor's Institution.
- [ ] GET requires zero raw body bytes, rejects every query/body attempt with
      `422`, returns the exact data envelope, and has no `message`.
- [ ] Resource key order, types, nullable fields, and UTC timestamps match the
      exact contract.
- [ ] PATCH updates every allowed field independently and together, supports
      nullable clears, and retains omitted values.
- [ ] PATCH rejects invalid body shapes, query keys, and all unknown/protected
      keys with no partial mutation.
- [ ] An exact/normalized no-op returns `200`, the current resource and exact
      message, issues no SQL update, and preserves `updated_at` exactly.
- [ ] A real dirty update changes only provided allowed fields plus the
      backend-managed `updated_at`.
- [ ] No client-controlled Institution ID or tenant-selection header exists.
- [ ] Other Institution rows and all settings/users/tokens/history rows remain
      unchanged under every success/failure path.
- [ ] Unauthorized/inactive/password-gated cases follow accepted precedence.
- [ ] Controlled unexpected failures return safe `500 server_error` with no
      internal disclosure or write side effect.
- [ ] Platform Owner Institution APIs remain green and unchanged in behavior.
- [ ] No schema/frontend/later-stage scope or unrelated file changed.

## 10. Tests and Verification

### 10.1 Required Feature Tests

- routes registered once, correct verbs/paths, and exact middleware order;
- eligible Institution Admin GET exact envelope, ordered resource keys,
  values/types/nullability, and UTC timestamps;
- GET returns only own Institution and has no message/meta/links/counts,
  creator, settings, users, tokens, relationship, or learning data;
- GET with absent body accepted; whitespace, `{}`, keyed object, array, scalar,
  JSON `null`, and malformed body each rejected with `errors.body`;
- every GET query key rejected with a field-level error;
- PATCH each allowed field, combined fields, explicit nullable clears, and
  omitted-field retention;
- `name` trimming, blank/type/max boundaries; email and phone type/format/max
  boundaries; address/description type boundaries;
- PATCH absent/empty/malformed/scalar/array/JSON-null body rejection;
- unknown/protected-key matrix from Section 5.4 and query override attempts,
  each proving zero partial mutation;
- duplicate email/phone across Institutions remains allowed;
- exact no-op and trimmed-name no-op preserve the raw `updated_at`, issue no
  Institution update query, and change no row;
- real update changes only the selected allowed fields and `updated_at`;
- fake tenant/Institution header cannot change the returned or updated tenant;
- exact snapshots prove the second Institution, settings, users, tokens,
  creator/lifecycle/type/status, and unrelated data remain unchanged;
- unauthenticated, all wrong roles, inactive User, inactive Institution, and
  password-change gate follow accepted precedence;
- accepted Platform Institution update/lifecycle/resource regressions remain
  green;
- controlled unexpected load and update failures map to safe
  `500 server_error`, expose no internal details, and perform no writes.

### 10.2 Quality Gates

From `backend/`, run current repository-valid equivalents of:

```text
vendor/bin/pint --test
php artisan test --filter=InstitutionProfileApiTest
php artisan test
composer validate --strict
```

Run configured security/static checks required by `backend/AGENTS.md`. Any
required failure blocks acceptance.

### 10.3 Manual Smoke

Using a controlled testing backend:

1. Authenticate an eligible Institution Admin and GET the exact own profile.
2. PATCH one allowed field, reload, and verify the committed value.
3. Clear one nullable field with JSON `null`.
4. Submit an exact no-op and verify `updated_at` does not change.
5. Attempt Platform-only/protected input and verify rejection with no mutation.

If the controlled backend is available, smoke must PASS. A smoke `FAIL` always
blocks acceptance. `NOT RUN` is non-blocking only when the environment is
genuinely unavailable, the reason is reported explicitly, and all equivalent
automated contract/tenant/no-op/no-write tests pass. Do not use `NOT RUN` to
hide a startup, configuration, or implementation failure.

## 11. Explicit Non-Goals

- Institution type/status/lifecycle mutation.
- Settings or category editing.
- Dashboard or User Management UI/API beyond this profile.
- Institution selection/switching or tenant selection by header.
- Platform Owner contract refactor.
- Groups, relationships, learning, reports, or audit UI.
- Schema/model changes, hard delete, logo/media upload.
- Optimistic locking, idempotency keys, or new multi-record transaction rules.

## 12. Stop Conditions

Stop on a missing accepted dependency, profile contract conflict, inability to
derive the authenticated actor's Institution safely, required schema/model/
Platform-contract change, unsafe Git state, or material scope expansion.

## 13. Required Workflow and Delivery

### Phase 0 — Git Preflight

1. Read the paired execution prompt and its authority order completely.
2. Verify this task is `Approved`.
3. Verify S03-INT-001 and S03-BE-001 are each
   `Accepted / PASS / Delivered` on `origin/main`.
4. Verify the exact approved remote, fetch it safely, and prove
   `local main == origin/main`.
5. Verify the working tree is clean except for only the owner-prepared
   S03-BE-002 detailed task and paired prompt.
6. Create/switch to `task/s03-be-002-own-institution-profile`.
7. Preserve unrelated user work and stop on an unsafe/dirty/conflicting state.
8. Do not commit, push, create a PR, or merge before Phase 2 PASS.

### Phase 1 — Implementation

Implement only this task. The only application/test paths allowed to change
are:

```text
backend/routes/api.php
backend/app/Http/Controllers/Api/V1/Institution/InstitutionProfileController.php
backend/app/Http/Requests/Institution/InstitutionProfileShowRequest.php
backend/app/Http/Requests/Institution/InstitutionProfileUpdateRequest.php
backend/app/Actions/Institution/ShowInstitutionProfile.php
backend/app/Actions/Institution/UpdateInstitutionProfile.php
backend/app/Http/Resources/Institution/InstitutionProfileResource.php
backend/tests/Feature/Institution/InstitutionProfileApiTest.php
```

Also update only the `S03-BE-002` row in `tasks/STAGE_03_TASK_INDEX.md` to
`In Progress / Not started / Not started`. Keep this detailed task's status
`Approved` and preserve the paired prompt byte-for-byte before Phase 2.

Run all required automated checks, scope/secret checks, and the manual smoke
rule from Section 10. Inspect the complete diff including the owner-prepared
task/prompt. Do not commit or push.

### Phase 2 — Read-Only Acceptance Gate

Re-read the authority task, accepted S03-INT-001 contract, locked references,
complete diff, implementation, tests, tenant/error/input/no-op/no-write
evidence, and smoke result. Phase 2 is strictly read-only:

```text
no edits or auto-fix/write-format
no task/index/README bookkeeping edits
no staging or commit
no push, PR, or merge
no self-fixing findings
```

Classify findings:

- `P1`: authorization/tenant disclosure, protected data or secret exposure,
  destructive Git, or violation of the read-only gate;
- `P2`: material GET/PATCH/resource/validation/no-op/error mismatch, missing
  tenant/no-write coverage, architecture defect, missing required test, scope
  drift, or workflow/bookkeeping inconsistency;
- `P3`: non-blocking observation that does not affect correctness, security,
  required evidence, or maintainability acceptance.

Any unresolved P1 or P2 results in:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start `S03-BE-003`. Report all P3 findings;
P3 alone does not block acceptance.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 PASS with no unresolved P1/P2.

1. Change only this detailed task's metadata status from `Approved` to
   `Accepted`; do not rewrite its approved behavior.
2. Prepare only the `S03-BE-002` index row as
   `Accepted / PASS / Delivered` in the delivery commit.
3. Update `tasks/README.md` truthfully: Stage 3 remains `In Progress`,
   S03-BE-002 is the delivered task, and `S03-BE-003` is the next execution
   gate.
4. Preserve every later task's current truthful status; do not mark
   `S03-BE-003` Approved unless its own reviewed pair is already present and
   separately approved.
5. Keep the paired Codex prompt byte-for-byte unchanged and include both
   owner-prepared authority files in the focused delivery commit.
6. Keep Stage 3 not closed and Stage 4 not started.
7. Re-run final non-writing diff, scope, secret, and consistency checks.
8. Stage only the approved implementation/test files, this task, its unchanged
   prompt, `tasks/STAGE_03_TASK_INDEX.md`, and `tasks/README.md`.
9. Commit:

   ```text
   feat(institution): add own profile management API
   ```

   Body:

   ```text
   Task: S03-BE-002
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
changed file, exact GET/PATCH/resource behavior, every acceptance criterion,
all commands/results, validation/protected/no-op/no-write/tenant/auth/error/
disclosure evidence, Platform regression, P1/P2/P3 findings, smoke status and
its blocking decision, scope/secret confirmation, bookkeeping result, and full
Git/PR/merge/local-remote-clean delivery evidence.

State:

```text
No Institution type/lifecycle mutation, settings, User Management, Group, or
Learning behavior was implemented.
Next implementation gate: S03-BE-003.
```
