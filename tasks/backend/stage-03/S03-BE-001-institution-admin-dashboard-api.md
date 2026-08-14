# Codex Task: Institution Admin Dashboard API

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-BE-001` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Backend` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Depends on | `S03-INT-001 — Accepted / PASS / Delivered` |
| Blocks | `S03-BE-002`, `S03-FE-002`, `S03-INT-002` |

The file may be prepared before its dependency is accepted, but implementation
must not start until the dependency is `Accepted / PASS / Delivered` on
`origin/main`.

## 2. Goal

Implement the authenticated Institution Admin dashboard endpoint so it returns
exactly three server-authoritative Teacher, Student, and Parent total account
counts for the authenticated Institution.

Endpoint:

```text
GET /api/v1/institution/dashboard
```

## 3. Current Context

Stage 2 already provides Sanctum authentication, active-account/Institution
enforcement, first-login password gate, role middleware, UUID User/Institution
models, API envelopes, and a Platform dashboard implementation pattern.

`S03-INT-001` makes the Stage 3 dashboard response exact. No Institution Admin
backend route exists yet. Group and Learning records are later-stage scope and
must not be approximated or fabricated.

## 4. Included Scope

- Add the `/institution` route group with the approved middleware order if it
  does not yet exist.
- Add the Institution Admin dashboard GET route.
- Add a focused request boundary that rejects every query key and any request
  body.
- Add a thin controller, focused application action/query, and exact API
  resource/DTO response.
- Count Teacher, Student, and Parent accounts inside the authenticated
  Institution, including both active and inactive accounts in each total.
- Add focused feature/security tests and required regression coverage.
- During Phase 1, mark only the S03-BE-001 Stage 3 index row as
  `In Progress / Not started / Not started`.
- After Phase 2 PASS, perform only the exact acceptance/delivery bookkeeping in
  Section 13.

## 5. Exact API Contract

### 5.1 Authorization

Middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:institution_admin
```

The Institution is derived from the authenticated User. The endpoint accepts no
Institution UUID or `institution_id` input.

### 5.2 Input

Accepted query keys:

```text
none
```

Accepted body:

```text
none
```

Only a request with zero raw body bytes is accepted. Any transmitted body
content returns the existing `422 validation_failed` contract with a
field-level `errors.body` entry, including whitespace-only content, `{}`, an
object with keys, `[]`, a scalar, JSON `null`, or malformed JSON. Every query
key is likewise rejected with a field-level error. Route/body/query/header
input must not influence tenant scope.

### 5.3 Success — 200

```json
{
  "data": {
    "users": {
      "teachers": 30,
      "students": 600,
      "parents": 450
    }
  }
}
```

Counting rules:

- each number includes active and inactive accounts of the named role;
- Platform Owner and Institution Admin accounts are excluded;
- accounts from every other Institution are excluded before aggregation;
- activating or deactivating an eligible account does not change these totals;
- empty roles return numeric zeroes;
- no recent users, identities, contact data, Group, Topic, task, score, result,
  settings, or protected learning data is returned.

## 6. Relevant Files

Codex must inspect actual paths before creating files.

| File or directory | Expected action | Reason |
|---|---|---|
| `backend/routes/api.php` | Modify | Register exact Institution route group/endpoint |
| `backend/app/Http/Controllers/Api/V1/Institution/InstitutionDashboardController.php` | Create | Thin HTTP adapter |
| `backend/app/Http/Requests/Institution/InstitutionDashboardRequest.php` | Create | Reject body/query input |
| `backend/app/Actions/Institution/ShowInstitutionDashboard.php` | Create | Own-tenant aggregation |
| `backend/app/Http/Resources/Institution/InstitutionDashboardResource.php` | Create | Stable exact response boundary |
| `backend/app/Enums/UserRole.php` | Inspect/preserve | Approved role values |
| `backend/app/Models/User.php` | Inspect and preserve | Existing fields/casts are sufficient for the aggregate |
| `backend/tests/Feature/Institution/InstitutionDashboardApiTest.php` | Create | Contract/security/tenant regression |
| accepted Platform dashboard files/tests | Inspect/reuse patterns, do not duplicate blindly | Established architecture and response conventions |
| `tasks/STAGE_03_TASK_INDEX.md` | Modify in Phase 1 and Phase 3 only as specified | Truthful execution/review/delivery state |
| `tasks/README.md` | Modify only after Phase 2 PASS | Truthful Stage 3 current/next gate |
| this detailed task | Status metadata only after Phase 2 PASS | Final accepted lifecycle state |
| paired Codex prompt | Preserve byte-for-byte | Approved execution authority |

No frontend, migration, settings, category, or locked-doc change belongs here.

## 7. Authoritative References

| Document | Exact section | Requirement |
|---|---|---|
| `docs/02-user-roles.md` | Institution Admin | Own-Institution administrative scope |
| `docs/03-features.md` | Institution Admin dashboard | Basic Institution overview |
| `docs/05-business-rules.md` | Institution/data separation; access | Strict tenant isolation and backend authority |
| `docs/06-roadmap.md` | `8. Stage 3` → Institution Admin Desktop Dashboard | Required counts and boundary |
| `docs/07-architecture.md` | tenancy, API, authorization, testing | Layering and enforcement |
| `docs/08-database.md` | Users and Roles | Institution/role/status fields |
| `docs/09-api-contracts.md` | general conventions; Section 31.1 after S03-INT-001 | Exact endpoint/response/errors |
| `backend/AGENTS.md` | entire applicable file | Backend organization, security, quality gates |

## 8. Requirements

### 8.1 Architecture

- Controller contains no query/business logic.
- Request owns strict input rejection.
- Action/query service owns tenant-scoped aggregation.
- Resource/DTO owns exact public serialization.
- Reuse existing enums and API response conventions.
- Do not reuse Platform Owner authorization or make a universal admin bypass.
- `ShowInstitutionDashboard` must issue exactly one aggregate query against
  `users`, scoped first by authenticated `institution_id` and then limited to
  the three allowed roles. Use conditional PostgreSQL counts for the three role
  totals.
- Do not hydrate User models, load collections, query once per role, or add N+1
  behavior.
- Deterministic integer casting is required for all counts.

### 8.2 Security and Tenant Isolation

- Resolve actor through the authenticated request only.
- Apply `institution_id = actor.institution_id` before allowed-role
  aggregation.
- Never accept tenant scope from route, query, header, or body.
- Preserve middleware precedence for unauthenticated, inactive account,
  inactive Institution, first-login password gate, and wrong role.
- Response must not permit inference of another tenant's counts.

### 8.3 Errors and Observability

- `401` unauthenticated.
- Existing lifecycle error for inactive User/Institution according to accepted
  middleware precedence.
- Existing password-change-required behavior before role authorization.
- `403` for authenticated eligible non-Institution-Admin roles.
- `422 validation_failed` for body/query input.
- No sensitive logs or raw SQL/user data logging.

## 9. Acceptance Criteria

- [ ] Exact GET route and middleware order exist.
- [ ] Eligible Institution Admin receives exact resource shape and integer
      counts.
- [ ] Exactly three total counts are correct for all allowed roles and include
      both active and inactive accounts.
- [ ] Institution Admin and Platform Owner roles are excluded.
- [ ] Foreign-Institution users do not affect any count.
- [ ] Empty data returns zeroes, not null/missing keys.
- [ ] Every query parameter and every transmitted body, including `{}` and
      malformed/non-object bodies, is rejected with `422`; an absent body is
      accepted.
- [ ] `401`, lifecycle/password-gate, and `403` precedence match accepted auth
      contracts.
- [ ] No Group/Learning/protected-user data is serialized.
- [ ] Controller/request/action/resource responsibilities remain focused.
- [ ] The action uses exactly one tenant-first User aggregate query and avoids
      row hydration/N+1 behavior.
- [ ] Success, validation failures, and authorization failures do not mutate
      Institution, User, or Sanctum token rows.
- [ ] Unexpected failures use the centralized `500 server_error` envelope and
      expose no SQL, exception, stack, tenant, or user detail.
- [ ] Full backend regression remains green.
- [ ] No unrelated behavior or later-stage scope changed.

## 10. Tests and Verification

### 10.1 Required Feature Tests

- eligible Institution Admin exact success envelope/keys/types;
- mixed active/inactive Teacher, Student, Parent totals where both account
  states contribute equally;
- activate/deactivate fixture changes preserve all three totals;
- zero-count Institution;
- same-role users in a second Institution excluded;
- Institution Admin and Platform Owner excluded;
- unauthenticated `401`;
- Platform Owner, Teacher, Student, Parent wrong-role `403` where earlier gates
  do not supersede it;
- inactive User and inactive Institution behavior;
- `must_change_password = true` gate precedence;
- unknown query key rejected;
- absent raw body accepted; whitespace, `{}`, keyed object, array, scalar,
  JSON `null`, and malformed body rejected;
- response disclosure negative assertions;
- an action-level query-log assertion proving exactly one scoped User aggregate
  query with no model hydration or per-role query;
- no-write snapshots for Institutions, Users, and Sanctum tokens on success and
  rejected requests;
- controlled unexpected exception mapped to safe `500 server_error` without
  internal details.

### 10.2 Quality Gates

From `backend/`, run current repository-valid equivalents of:

```text
vendor/bin/pint --test
php artisan test --filter=InstitutionDashboardApiTest
php artisan test
composer validate --strict
```

Run configured security/static checks required by `backend/AGENTS.md`. Any
required failure blocks acceptance.

### 10.3 Manual Smoke

Using a controlled testing backend:

1. Authenticate an eligible Institution Admin.
2. Call the endpoint and compare counts with known own-Institution fixtures.
3. Add an eligible fixture and confirm its role total increases; activate or
   deactivate it and confirm all three totals remain unchanged.
4. Confirm another Institution's fixtures never affect the response.

If the controlled backend is available, smoke must PASS. A smoke `FAIL` always
blocks acceptance. `NOT RUN` is non-blocking only when the environment is
genuinely unavailable, the reason is reported explicitly, and all equivalent
automated contract/tenant/count tests pass; do not use `NOT RUN` to hide a
startup, configuration, or implementation failure.

## 11. Explicit Non-Goals

- Institution profile API or UI.
- User list/detail/create/update/lifecycle APIs or UI.
- Settings/categories API or UI.
- Group or Learning metrics.
- Stage 4 relationships or any learning workflow.
- Caching/background jobs/analytics/report exports.
- Frontend work.
- Schema changes.
- Refactoring Platform Owner dashboard unrelated to safe reuse.

## 12. Stop Conditions

Stop if the accepted S03-INT-001 contract is absent/contradictory, the
dependency is not delivered, safe tenant scope cannot be derived, middleware
precedence would require changing Stage 1 behavior, or completion requires
schema/later-stage/material scope expansion.

## 13. Required Workflow and Delivery

### Phase 0 — Git Preflight

1. Read the paired execution prompt authority order completely.
2. Verify this task is `Approved` and `S03-INT-001` is
   `Accepted / PASS / Delivered` on `origin/main`.
3. Verify the exact approved remote and safely fetch it.
4. Verify local `main == origin/main` and the only owner-prepared untracked
   files are this task and its paired prompt.
5. Create/switch to `task/s03-be-001-institution-dashboard`.
6. Preserve unrelated user work and stop on an unsafe/dirty/conflicting state.
7. Do not commit, push, create a PR, or merge before Phase 2 PASS.

### Phase 1 — Implementation

Implement only this task. The only application/test paths allowed to change are:

```text
backend/routes/api.php
backend/app/Http/Controllers/Api/V1/Institution/InstitutionDashboardController.php
backend/app/Http/Requests/Institution/InstitutionDashboardRequest.php
backend/app/Actions/Institution/ShowInstitutionDashboard.php
backend/app/Http/Resources/Institution/InstitutionDashboardResource.php
backend/tests/Feature/Institution/InstitutionDashboardApiTest.php
```

Also update only the `S03-BE-001` row in `tasks/STAGE_03_TASK_INDEX.md` to
`In Progress / Not started / Not started`. Keep this detailed task's status
`Approved` and preserve the paired prompt byte-for-byte before Phase 2.

Run all required automated checks, scope/secret checks, and the manual smoke
rule from Section 10. Inspect the complete diff including the owner-prepared
task/prompt. Do not commit or push.

### Phase 2 — Read-Only Acceptance Gate

Re-read the authority task, accepted S03-INT-001 contract, locked references,
complete diff, implementation, tests, tenant/error/query evidence, and smoke
result. Phase 2 is strictly read-only:

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
- `P2`: material response/count/input/error mismatch, missing tenant coverage,
  architecture/query-quality defect, missing required test, scope drift, or
  workflow/bookkeeping inconsistency;
- `P3`: non-blocking observation that does not affect correctness, security,
  required evidence, or maintainability acceptance.

Any unresolved P1 or P2 results in:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start `S03-BE-002`. Report all P3 findings;
P3 alone does not block acceptance.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 PASS with no unresolved P1/P2.

1. Change only this detailed task's metadata status from `Approved` to
   `Accepted`; do not rewrite its approved behavior.
2. Prepare only the `S03-BE-001` index row as
   `Accepted / PASS / Delivered` in the delivery commit.
3. Update `tasks/README.md` truthfully: Stage 3 remains `In Progress`,
   S03-BE-001 is the delivered task, and `S03-BE-002` is the next execution
   gate.
4. Preserve every later task's current truthful status; do not mark
   `S03-BE-002` Approved unless its own reviewed pair is already present and
   separately approved.
5. Keep the paired Codex prompt byte-for-byte unchanged and include both
   owner-prepared authority files in the focused delivery commit.
6. Keep Stage 3 not closed and Stage 4 not started.
7. Re-run final non-writing diff, scope, secret, and consistency checks.
8. Stage only the approved implementation/test files, this task, its unchanged
   prompt, `tasks/STAGE_03_TASK_INDEX.md`, and `tasks/README.md`.
9. Commit:

   ```text
   feat(institution): add admin dashboard aggregates
   ```

   Body:

   ```text
   Task: S03-BE-001
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
changed file, exact three-count response evidence, every acceptance criterion,
all commands/results, tenant/security/input/error/disclosure/no-write cases,
exact one-query evidence, P1/P2/P3 findings, smoke status and its blocking
decision, scope/secret confirmation, bookkeeping result, and full Git/PR/merge/
local-remote-clean delivery evidence.

Explicitly state:

```text
No Group or Learning dashboard metrics were implemented.
Next implementation gate: S03-BE-002.
```
