# Codex Task: Institution User List and Detail API

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-BE-003` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Backend` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Depends on | `S03-INT-001`, `S03-BE-001`, and `S03-BE-002` — all `Accepted / PASS / Delivered` |
| Blocks | `S03-BE-004`, `S03-FE-004`, `S03-FE-005`, `S03-INT-002` |

The pair may be prepared before its dependencies are accepted, but execution
must not start until every dependency is `Accepted / PASS / Delivered` on
`origin/main`.

## 2. Goal

Give an eligible Institution Admin a safe, exact, paginated read API for
Teacher, Student, and Parent accounts belonging only to the authenticated
Institution.

Endpoints:

```text
GET /api/v1/institution/users
GET /api/v1/institution/users/{user}
```

## 3. Current Context

S03-INT-001 defines the exact shared Institution User resource, list contract,
and scope-safe detail behavior. Stage 2 provides a Platform Owner Institution
Admin list pattern, but this task differs because one own-tenant list supports
three roles and direct detail must hide foreign or disallowed-role existence.

No User mutation, schema change, relationship, or learning behavior belongs in
this task. S03-BE-004 and S03-BE-005 will reuse the stable resource/controller
boundary delivered here.

## 4. Included Scope

- Register the exact list/detail routes once under the Institution Admin
  middleware group.
- Add separate strict list and detail GET request boundaries.
- Add one exact reusable Institution User resource and one exact paginated
  collection.
- Add a tenant-first list action with role/status filters, literal search,
  whitelisted sorting, deterministic UUID tie-break, and length-aware
  pagination.
- Add scope-safe detail loading for an own Teacher, Student, or Parent only.
- Add focused contract, authorization, tenant, disclosure, query-quality,
  safe-error, and no-side-effect tests.
- Preserve accepted authentication and Platform Institution/Admin behavior.
- During Phase 1, mark only the S03-BE-003 Stage 3 index row as
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

The authenticated User's `institution_id` is the only tenant authority. No
route, query, body, or header value may select or replace Institution scope.
Eligible target roles are exactly:

```text
teacher
student
parent
```

### 5.2 Exact Shared User Resource

The public resource contains exactly these keys in this order:

```json
{
  "id": "user-uuid",
  "role": "teacher",
  "full_name": "Teacher Name",
  "login_name": "teacher01",
  "email": null,
  "phone": "+998...",
  "is_active": true,
  "must_change_password": true,
  "last_login_at": null,
  "deactivated_at": null,
  "created_at": "2026-08-07T15:00:00Z",
  "updated_at": "2026-08-07T15:00:00Z"
}
```

`role` is the backed enum string. Boolean fields are JSON booleans. Nullable
fields remain present with JSON `null`. All non-null timestamps use the
accepted UTC representation.

Never serialize `institution_id`, `created_by_user_id`, creator resources,
password/hash, remember token, Sanctum tokens, permissions, Institution
settings, relationship graphs, learning records, answers, scores, or results.

### 5.3 List — `GET /api/v1/institution/users`

Accepted query keys only:

```text
role
status
search
page
per_page
sort
direction
```

Values and defaults:

```text
role = teacher | student | parent | omitted
status = active | inactive | omitted
search = optional trimmed string, max 254 after trimming
page = integer >= 1, default 1
per_page = integer 1..100, default 20
sort = full_name | login_name | created_at | updated_at, default full_name
direction = asc | desc, default asc
```

Rules:

- omitted `role` includes all three eligible roles;
- omitted `status` includes active and inactive accounts;
- `active` maps to `is_active = true`; `inactive` maps to
  `is_active = false`;
- blank `search` after trimming behaves as no search filter;
- non-blank search is a case-insensitive literal substring match across
  `full_name`, `login_name`, `email`, and `phone`;
- implement PostgreSQL matching with bound parameters and
  `ILIKE ? ESCAPE '!'`; escape literal `!`, `%`, and `_` as `!!`, `!%`, and
  `!_` respectively before surrounding the value with `%`;
- apply authenticated Institution and eligible-role predicates before role/
  status/search/order/pagination construction;
- `full_name` and `login_name` ordering is case-insensitive;
- every primary sort uses the requested direction;
- UUID `id` is the final deterministic tie-break in the same direction;
- raw client values never enter SQL identifiers or direction fragments;
- unknown query keys, arrays/unsupported types, invalid values, or invalid
  pagination return `422 validation_failed` with field-level errors.

Accepted body:

```text
none
```

Only zero raw body bytes are accepted. Whitespace-only content, `{}`, a keyed
object, `[]`, a scalar, JSON `null`, malformed JSON, raw text, or form-encoded
content returns `422 validation_failed` with `errors.body`.

Success is `200 OK` with exactly:

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

The four pagination values are integers. `total` and `last_page` are computed
after tenant, eligible-role, filter, and search predicates. Foreign and
disallowed-role rows never affect data or metadata. An out-of-range page is a
successful empty `data` array with the requested `page` and truthful
`last_page`. No `message`, `links`, raw Laravel pagination block, or other
top-level key is returned.

At the list-action level, normal length-aware pagination issues exactly two
queries against `users`: one scoped count and one scoped current-page select.
Select only the fields required by Section 5.2. Do not hydrate unbounded rows,
load relationships, or query once per role.

### 5.4 Detail — `GET /api/v1/institution/users/{user}`

The raw path value is the only accepted input. No query key is accepted, and
only zero raw body bytes are accepted. Every query key returns
`422 validation_failed` with a field-level error. Every transmitted body form
listed in Section 5.3 returns `422` with `errors.body`.

Do not use implicit User model binding or a route UUID constraint. Keeping the
raw `{user}` route value allows the required middleware and Form Request to run
before scope-safe resolution. Precedence is therefore:

1. authentication, active-account/Institution, password, and role middleware;
2. detail query/body validation;
3. UUID syntax and tenant/eligible-role target resolution.

For an otherwise valid request, a malformed UUID, unknown UUID, foreign-
Institution UUID, Platform Owner UUID, or Institution Admin UUID returns the
same `404 resource_not_found` contract without revealing the reason.

After UUID syntax validation, resolve in exactly one `users` query containing
all predicates:

```text
id = requested UUID
AND institution_id = authenticated actor.institution_id
AND role in (teacher, student, parent)
```

Success is `200 OK` with exactly the normal single-resource `data` envelope
containing Section 5.2. No `message`, `meta`, `links`, or related resource is
returned.

Both GET endpoints and every success/error path perform no database/timestamp/
token mutation.

## 6. Exact Files and Responsibilities

Codex must inspect current patterns but use these exact task paths:

| File | Expected action | Responsibility |
|---|---|---|
| `backend/routes/api.php` | Modify | Register exact list/detail routes once |
| `backend/app/Http/Controllers/Api/V1/Institution/InstitutionUserController.php` | Create | Thin `index`/`show` HTTP adapter |
| `backend/app/Http/Requests/Institution/InstitutionUserIndexRequest.php` | Create | Exact list query/body validation |
| `backend/app/Http/Requests/Institution/InstitutionUserShowRequest.php` | Create | Reject detail query/body input |
| `backend/app/Actions/Institution/ListInstitutionUsers.php` | Create | Tenant-first filtering/search/sort/pagination |
| `backend/app/Actions/Institution/ShowInstitutionUser.php` | Create | UUID and scope-safe detail resolution |
| `backend/app/Http/Resources/Institution/InstitutionUserResource.php` | Create | Exact shared serialization |
| `backend/app/Http/Resources/Institution/InstitutionUserCollection.php` | Create | Exact pagination envelope |
| `backend/tests/Feature/Institution/InstitutionUserReadApiTest.php` | Create | Full read-contract/security evidence |
| `backend/app/Models/User.php`, `backend/app/Enums/UserRole.php` | Inspect and preserve | Existing model/enum are sufficient |
| accepted Stage 2 Platform Admin list code/tests | Inspect and preserve | Reuse safe patterns without changing contract |
| `tasks/STAGE_03_TASK_INDEX.md` | Modify only as Section 13 permits | Truthful execution/review/delivery state |
| `tasks/README.md` | Modify only after Phase 2 PASS | Truthful Stage 3 current/next gate |
| this detailed task | Status metadata only after Phase 2 PASS | Final accepted lifecycle state |
| paired Codex prompt | Preserve byte-for-byte | Approved execution authority |

No other application or test path may change. No model, enum, frontend,
migration, schema, factory, seeder, settings/category, Platform contract, or
locked-doc change belongs here.

## 7. Authoritative References

| Document | Exact area | Requirement |
|---|---|---|
| `docs/02-user-roles.md` | Institution Admin and managed roles | Read authority and target roles |
| `docs/03-features.md` / `docs/04-user-flows.md` | User list/view | Stage 3 behavior |
| `docs/05-business-rules.md` | tenant, role, disclosure, lifecycle | Scope and backend authority |
| `docs/06-roadmap.md` | `8. Stage 3` | Teacher/Student/Parent account scope |
| `docs/07-architecture.md` | API/tenant/security/testing | Required layering and enforcement |
| `docs/08-database.md` | Users and Roles | Existing fields, indexes, and role values |
| `docs/09-api-contracts.md` | Sections 2, 5, 6, 8.2/8.3/8.5, and 33 after S03-INT-001 | Resource, list, detail, errors, pagination |
| `backend/AGENTS.md` | entire applicable file | Backend organization, security, and gates |

## 8. Architecture, Security, and Error Requirements

- Pass the authenticated actor to each action; never pass a client-controlled
  Institution identifier.
- The list action starts with actor Institution and allowed-role predicates.
- The detail action validates UUID syntax, then applies UUID, tenant, and
  allowed-role predicates in the same query.
- Requests own input validation; controller stays thin; actions own queries;
  resource/collection own serialization.
- Do not add a universal admin bypass, unscoped helper, implicit binding, route
  UUID constraint, raw order input, or relationship eager load.
- Select only the exact resource fields, use bound search values, whitelist
  all sort/direction values, and avoid N+1/unbounded collections.
- Preserve accepted middleware precedence and scope-safe non-disclosure.
- Arbitrary tenant-like headers cannot affect list/detail scope.
- Unexpected list/detail failures use the centralized safe
  `500 server_error` envelope and expose no SQL, exception, stack, path, tenant,
  User, or secret detail.
- No sensitive input or data may be logged.

## 9. Acceptance Criteria

- [ ] Exact list/detail routes exist once with exact middleware order.
- [ ] Both endpoints accept only their specified input and reject every
      transmitted GET body with `422` and `errors.body`.
- [ ] Resource key order, values/types/nulls, role string, and UTC timestamps
      are exact.
- [ ] Default list contains only own Teacher/Student/Parent accounts, including
      active and inactive targets.
- [ ] Role/status/search filters work separately and together.
- [ ] Search is trimmed, case-insensitive, and literal for `!`, `%`, and `_`.
- [ ] All allowed sorts/directions and same-direction UUID tie-break are
      deterministic and injection-safe.
- [ ] Pagination defaults/limits/envelope/metadata are exact and foreign or
      disallowed rows never affect totals.
- [ ] List issues exactly two scoped User queries; detail issues exactly one;
      no relationship/N+1/unbounded load occurs.
- [ ] Detail preserves middleware/input/not-found precedence and returns the
      same safe `404` for every invalid/inaccessible target class.
- [ ] Success envelopes contain no extra keys and protected/sensitive/
      relationship/learning data never leaks.
- [ ] Success, validation, authorization, not-found, and unexpected-failure
      paths perform no write or timestamp/token mutation.
- [ ] Controlled unexpected failures return safe `500 server_error` without
      internal disclosure.
- [ ] Stage 1/2 auth and Platform Institution/Admin list regressions remain
      green.
- [ ] No mutation, schema, frontend, unrelated file, or later-stage scope is
      added.

## 10. Tests and Verification

### 10.1 Required Feature Tests

- routes registered once with exact methods, paths, and middleware order;
- default list exact top-level keys, resource key order/types/nulls/UTC values,
  role inclusion, and exact pagination keys/integer types;
- all three roles and active/inactive targets included by default while own
  Institution Admin, Platform Owner, and foreign-Institution rows are excluded
  from both `data` and `meta.pagination`;
- role and status filters separately and combined;
- search each approved nullable/non-null column, trimming, case behavior,
  254/255 boundaries, blank behavior, and literal `!`, `%`, `_` escaping;
- every sort/direction, case-insensitive text ordering, and duplicate-primary
  same-direction UUID tie-break;
- default page/per-page, boundaries `1` and `100`, pages 1/2, empty result, and
  out-of-range page with truthful metadata;
- unknown query keys, array/invalid enums/types/ranges/sorts/directions, SQL and
  raw-sort injection attempts, each returning field-level `422`;
- for both endpoints, absent raw body accepted; whitespace, `{}`, keyed object,
  array, scalar, JSON `null`, malformed JSON, raw text, and form-encoded body
  rejected with `errors.body`;
- own active and inactive target detail exact success resource and envelope;
- clean malformed, unknown, foreign, Institution Admin, and Platform Owner
  targets return the same safe `404` body/status/code;
- unauthenticated, inactive User, inactive Institution, password-change gate,
  and Platform Owner/Teacher/Student/Parent wrong-role precedence, including a
  malformed target or invalid extra input where needed to prove ordering;
- detail query/body validation occurs before UUID/not-found resolution for an
  otherwise eligible actor;
- fake tenant/Institution header cannot alter list or detail scope;
- disclosure-negative assertions cover every protected/sensitive area;
- action-level query-log evidence proves exactly two scoped `users` queries for
  list and one for detail, selected fields only, correct predicates/order, no
  per-role/relationship query, and no N+1;
- exact snapshots prove Institutions, settings, Users, and Sanctum tokens are
  unchanged for success and every error family;
- controlled list and detail action/query failures map to safe
  `500 server_error`, reveal no internal detail, and perform no writes;
- accepted Stage 1/2 auth and Platform Institution/Admin list regressions.

### 10.2 Quality Gates

From `backend/`, run current repository-valid equivalents of:

```text
vendor/bin/pint --test
php artisan test --filter=InstitutionUserReadApiTest
php artisan test
composer validate --strict
```

Run configured security/static checks required by `backend/AGENTS.md`. Any
required failure blocks acceptance.

### 10.3 Manual Smoke

Using a controlled testing backend:

1. Load the default own-Institution list and verify exact metadata.
2. Exercise role/status filters, literal search, sorting, and pagination.
3. Open an own eligible User detail.
4. Attempt foreign, disallowed-role, and malformed UUID details and confirm the
   same safe not-found behavior.
5. Confirm no foreign User appears or affects totals.

If the controlled backend is available, smoke must PASS. A smoke `FAIL` always
blocks acceptance. `NOT RUN` is non-blocking only when the environment is
genuinely unavailable, the reason is reported explicitly, and all equivalent
automated contract/tenant/query/no-write tests pass. Do not use `NOT RUN` to
hide a startup, configuration, or implementation failure.

## 11. Explicit Non-Goals

- Create, update, activate, deactivate, delete, or reset a User password.
- Role/login-name edit or bulk import/export.
- Institution Admin or Platform Owner management.
- Groups, relationships, learning, settings, or categories.
- Frontend, migration/schema/model/enum/factory/seeder changes.
- Caching, search indexes, analytics, reports, or later-stage behavior.

## 12. Stop Conditions

Stop on a missing accepted dependency, contract mismatch, unsafe tenant detail
loading, inability to preserve middleware/not-found precedence, required
schema/model/Platform-contract change, unsafe Git state, or material expansion.

## 13. Required Workflow and Delivery

### Phase 0 — Git Preflight

1. Read the paired execution prompt and its authority order completely.
2. Verify this detailed task is `Approved`.
3. Verify S03-INT-001, S03-BE-001, and S03-BE-002 are each
   `Accepted / PASS / Delivered` on `origin/main`.
4. Verify the exact approved remote, fetch safely, and prove
   `local main == origin/main`.
5. Verify the working tree is clean except for only the owner-prepared
   S03-BE-003 detailed task and paired prompt.
6. Create/switch to `task/s03-be-003-institution-user-read`.
7. Preserve unrelated user work and stop on an unsafe/dirty/conflicting state.
8. Do not commit, push, create a PR, or merge before Phase 2 PASS.

### Phase 1 — Implementation

Implement only this task. The only application/test paths allowed to change
are:

```text
backend/routes/api.php
backend/app/Http/Controllers/Api/V1/Institution/InstitutionUserController.php
backend/app/Http/Requests/Institution/InstitutionUserIndexRequest.php
backend/app/Http/Requests/Institution/InstitutionUserShowRequest.php
backend/app/Actions/Institution/ListInstitutionUsers.php
backend/app/Actions/Institution/ShowInstitutionUser.php
backend/app/Http/Resources/Institution/InstitutionUserResource.php
backend/app/Http/Resources/Institution/InstitutionUserCollection.php
backend/tests/Feature/Institution/InstitutionUserReadApiTest.php
```

Also update only the `S03-BE-003` row in `tasks/STAGE_03_TASK_INDEX.md` to
`In Progress / Not started / Not started`. Keep this detailed task's status
`Approved` and preserve the paired prompt byte-for-byte before Phase 2.

Run all required automated checks, scope/secret checks, and the manual smoke
rule from Section 10. Inspect the complete diff including the owner-prepared
task/prompt. Do not commit or push.

### Phase 2 — Read-Only Acceptance Gate

Re-read the authority task, accepted S03-INT-001 contract, locked references,
complete diff, code/tests, tenant/input/envelope/query/error/no-write evidence,
and smoke result. Phase 2 is strictly read-only:

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
- `P2`: material resource/list/detail/input/pagination/not-found/error/query/
  architecture/test mismatch, scope drift, or workflow/bookkeeping defect;
- `P3`: non-blocking observation that does not affect correctness, security,
  required evidence, or maintainability acceptance.

Any unresolved P1 or P2 results in:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start `S03-BE-004`. Report every P3 finding;
P3 alone does not block acceptance.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 PASS with no unresolved P1/P2.

1. Change only this detailed task's metadata status from `Approved` to
   `Accepted`; do not rewrite its approved behavior.
2. Prepare only the `S03-BE-003` index row as
   `Accepted / PASS / Delivered` in the delivery commit.
3. Update `tasks/README.md` truthfully: Stage 3 remains `In Progress`,
   S03-BE-003 is the delivered task, and `S03-BE-004` is the next execution
   gate.
4. Preserve every later task's truthful status; do not mark S03-BE-004
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
   feat(institution): add user read APIs
   ```

   Body:

   ```text
   Task: S03-BE-003
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
changed file, exact resource/list/detail/envelope behavior, all acceptance
criteria and commands/results, filter/search/sort/pagination/query/tenant/auth/
not-found/disclosure/no-write/safe-error evidence, Platform regressions,
P1/P2/P3 findings, smoke status and blocking decision, scope/secret checks,
bookkeeping result, and complete Git/PR/merge/local-remote-clean evidence.

State:

```text
No User mutation, Institution Admin/Platform Owner management, relationship,
Group, settings, category, or Learning behavior was implemented.
Next implementation gate: S03-BE-004.
```
