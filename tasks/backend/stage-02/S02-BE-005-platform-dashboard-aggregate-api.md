# Codex Task: Platform Dashboard Aggregate API

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-BE-005` |
| Status | `Accepted` |
| Approved on | `2026-08-10` |
| Stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Backend / Platform Owner dashboard read model` |
| Priority | `High` |
| Depends on | `S02-BE-004` accepted, delivered, and present on current `origin/main` |
| Unblocks | `S02-BE-006`; `S02-FE-002` |
| Repository | `https://github.com/Shoxrux2017/testlabuz.git` |
| Target branch | `task/s02-be-005-platform-dashboard` |
| Execution model | One focused implementation task followed by read-only acceptance and safe GitHub delivery |

---

## 2. Goal

Implement the approved read-only Platform Owner dashboard endpoint:

```text
GET /api/v1/platform/dashboard
```

The endpoint must give an authenticated, active, password-complete
`platform_owner` a compact PostgreSQL-backed summary of the currently stored
platform state:

- total, active, and inactive Institution counts;
- total and individually active User account counts; and
- the five most recently created Institutions.

The dashboard is a focused operational read model. It must use aggregate
queries, return the exact public response contract, enforce backend
authorization, remain deterministic, and avoid protected Institution-user or
learning data.

This task is complete only when authorization, count semantics, recent-item
ordering, empty-state behavior, explicit serialization, PostgreSQL-backed
tests, full regression verification, read-only acceptance, and the accepted
GitHub delivery workflow all pass.

### Scope boundary

This task owns only the Stage 2 dashboard read endpoint. It does not:

- add `GET /api/v1/platform/statistics`;
- add dashboard filters, date ranges, search, sorting input, or pagination;
- expose per-Institution user records or role breakdowns;
- calculate login activity, online users, support health, issue status,
  storage, billing, educational progress, scores, or results;
- create or manage Institution Admin accounts;
- change Institution profile or lifecycle behavior;
- create global platform settings;
- add Flutter dashboard UI;
- add a cache, queue, event pipeline, analytics database, migration, index, or
  dependency;
- revise locked `docs/01–09`.

---

## 3. Current Accepted Context

Treat current `origin/main` as the implementation source of truth. Do not rely
on this preparation snapshot when the repository can be inspected directly.

The closed Stage 1 baseline already provides:

- Laravel REST API under `/api/v1`;
- PostgreSQL runtime and UUID identity persistence;
- `institutions`, `users`, `institution_settings`, and Sanctum token storage;
- canonical `InstitutionStatus`, `InstitutionType`, and `UserRole` enums;
- Sanctum Bearer authentication;
- `active.account`, `password.changed`, and role middleware;
- stable centralized JSON error envelopes;
- accepted Stage 1 authentication, authorization, testing, and delivery
  workflow.

The current locked persistence contract already provides dashboard source
fields:

```text
institutions.id
institutions.name
institutions.type
institutions.status
institutions.created_at

users.id
users.institution_id
users.role
users.is_active
```

At execution time, accepted Stage 2 predecessors must additionally provide:

- `S02-BE-001`: the protected Platform Owner route namespace and Institution
  read patterns;
- `S02-BE-002`: atomic Institution creation;
- `S02-BE-003`: approved Institution profile mutation patterns;
- `S02-BE-004`: idempotent Institution lifecycle and accepted access
  enforcement.

Reuse those accepted security, namespace, Resource, timestamp, and test
patterns where they own the same responsibility. Do not create a second
Platform Owner authorization system or a parallel platform API namespace.

Preparation-time GitHub `main` still contained only the closed Stage 1 product
baseline. Therefore, Codex must prove that all four predecessor implementations
are accepted and delivered before this task begins. This task contract does not
authorize combining missing predecessor work into `S02-BE-005`.

---

## 4. Dependency and Stage-Control Gate

Before implementation, verify all of the following from repository and remote
evidence:

1. Stage 1 is `Closed` and Stage DoD is `PASS`.
2. `S02-BE-001` is `Accepted`, delivered, and present on `origin/main`.
3. `S02-BE-002` is `Accepted`, delivered, and present on `origin/main`.
4. `S02-BE-003` is `Accepted`, delivered, and present on `origin/main`.
5. `S02-BE-004` is `Accepted`, delivered, and present on `origin/main`.
6. `tasks/STAGE_02_TASK_INDEX.md` exists and still matches the approved
   17-task Stage 2 decomposition.
7. This detailed task exists at:

   ```text
   tasks/backend/stage-02/S02-BE-005-platform-dashboard-aggregate-api.md
   ```

8. Its status is `Approved` before implementation begins.
9. No conflicting Platform dashboard implementation already exists.

If a dependency is missing or unaccepted, if local `main` is not synchronized
with `origin/main`, or if repository evidence contradicts this contract, stop
and report `BLOCKED` with exact evidence. Do not implement or repair a
predecessor inside this task.

This task may update only the truthful `S02-BE-005` lifecycle state in the
Stage 2 index. It must not approve, create contracts/prompts for, implement, or
change the state of later tasks.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

Before editing:

1. Read root `AGENTS.md` completely.
2. Read `backend/AGENTS.md` and any nearer applicable instructions completely.
3. Read `tasks/README.md` and `tasks/STAGE_02_TASK_INDEX.md`.
4. Read this approved task completely.
5. Read the accepted `S02-BE-001` through `S02-BE-004` contracts, reviews,
   and delivery evidence relevant to this endpoint.
6. Read only the locked specification sections referenced in Section 8.
7. Inspect current Platform routes, controllers, Resources, actions/queries,
   models, enums, migrations, middleware, error mapping, factories, and tests.
8. Verify safely:

   ```text
   git fetch origin
   git switch main
   git pull --ff-only origin main
   git status --short
   git rev-parse HEAD
   git rev-parse origin/main
   git remote -v
   ```

9. Confirm:

   ```text
   local main == origin/main
   working tree clean except the two approved S02-BE-005 preparation files
   origin is the approved TestLabUz repository
   ```

10. If the project owner saved the approved preparation pair before execution,
    the only permitted worktree changes are exactly:

    ```text
    tasks/backend/stage-02/S02-BE-005-platform-dashboard-aggregate-api.md
    tasks/backend/stage-02/S02-BE-005-CODEX-PROMPT.md
    ```

    No other modified, staged, deleted, renamed, or untracked path is allowed,
    and neither preparation file may be committed on `main`.

11. Create or switch to exactly:

    ```text
    task/s02-be-005-platform-dashboard
    ```

12. Carry the two approved task preparation files onto the task branch if the
    project owner placed them on otherwise clean local `main`.
13. Verify that the committed `main` state was not changed.
14. Use the accepted PostgreSQL-capable runtime. Do not substitute SQLite.
15. Do not commit or push during implementation or read-only acceptance.

Any unrelated or unexplained worktree change is a blocker. Preserve user work;
do not reset, discard, overwrite, or destructively clean it.

### 5.2 Route and middleware contract

Add exactly one route to the accepted Platform Owner route group:

```text
GET /api/v1/platform/dashboard
```

Preserve the accepted middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:platform_owner
```

Required behavior:

- unauthenticated or invalid-token requests return the accepted
  `401 authentication_required` envelope;
- an inactive Platform Owner returns `403 user_inactive`;
- a Platform Owner with `must_change_password = true` returns
  `403 password_change_required`;
- each authenticated non-Platform-Owner role returns `403 forbidden` when its
  own user and Institution status gates pass;
- an Institution user whose Institution is inactive remains subject to the
  accepted `active.account` precedence and returns `403 institution_inactive`
  before role authorization;
- only an active, password-complete Platform Owner may receive dashboard data;
- the endpoint is platform-scoped and must not accept an Institution identity
  from the client.

Do not:

- add the endpoint under an Institution-scoped route group;
- add a Platform Owner universal bypass to ordinary tenant routes;
- authorize from client state, request data, a target Institution, or Flutter
  navigation;
- weaken accepted authentication, status, password, or role gates;
- return HTML redirects for API failures.

### 5.3 No-input request contract

The endpoint has no approved query parameters.

Valid request:

```http
GET /api/v1/platform/dashboard
Accept: application/json
Authorization: Bearer <redacted-token>
```

Any query key must be rejected with:

```text
HTTP 422
code = validation_failed
```

Examples of unsupported keys include:

```text
institution_id
status
type
role
from
to
period
limit
page
per_page
include
```

Unknown query input must not silently change, filter, expand, or paginate the
dashboard. Field-level validation errors must identify the unsupported query
keys without echoing secrets or private values.

No request-body contract is introduced for this GET endpoint. Do not add
client-controlled metric lists, SQL expressions, aggregation modes, or sort
expressions.

### 5.4 Institution aggregate contract

The `data.institutions` object is:

```json
{
  "total": 20,
  "active": 18,
  "inactive": 2
}
```

Exact semantics:

- `total` counts every persisted row in `institutions`;
- `active` counts only `status = active`;
- `inactive` counts only `status = inactive`;
- no Institution is excluded because it has zero users or incomplete optional
  settings;
- no Institution is counted twice;
- with the accepted two-value status constraint,
  `total = active + inactive`;
- all three values are JSON integers and never strings or `null`;
- an empty table returns zeros for all three values.

Compute the three values through one bounded aggregate query or an equally
consistent server-side aggregate. Do not load Institution rows into PHP and
count them in memory.

### 5.5 User aggregate contract

The `data.users` object is:

```json
{
  "total": 2800,
  "active": 2720
}
```

Exact semantics:

- `total` counts every persisted row in `users` across all five approved
  roles, including Platform Owner accounts;
- `active` counts rows where `users.is_active = true` across all five roles;
- an individually active Institution user remains part of `active` even when
  their Institution is currently inactive;
- `must_change_password`, token presence, `last_login_at`, Institution status,
  and current relationship permissions do not alter this account-status
  metric;
- this is not an online-user, recently-active-user, successful-login, or
  effective-login-eligibility metric;
- no user identity, role breakdown, Institution breakdown, contact field,
  password state, token data, or login timestamp is returned;
- both values are JSON integers and never strings or `null`;
- an empty `users` table returns zeros.

This definition deliberately maps the word `active` to the authoritative
`users.is_active` account field. Do not silently derive a different metric from
Institution lifecycle, token state, or `last_login_at`.

Compute both values through one bounded aggregate query or an equally
consistent server-side aggregate. Do not load User models into PHP and do not
query once per Institution or role.

### 5.6 Recent Institutions contract

The `data.recent_institutions` array contains exactly the five newest
Institutions, or every Institution when fewer than five exist:

```json
[
  {
    "id": "uuid",
    "name": "Example School",
    "type": "school",
    "status": "active",
    "created_at": "2026-08-01T10:00:00Z"
  }
]
```

Selection and ordering rules:

- include active and inactive Institutions;
- order by `created_at DESC`;
- add `id DESC` as the deterministic tie-breaker;
- apply a fixed server-side limit of `5`;
- do not accept a client limit, page, date range, or sort;
- an empty Institution table returns `[]`;
- one Institution appears at most once;
- the list does not include a per-Institution user count.

Exact public item fields:

```text
id
name
type
status
created_at
```

Do not expose:

```text
contact_email
contact_phone
address
description
created_by_user_id
deactivated_at
updated_at
institution_settings
users
user_counts
```

UUID and enum values serialize as strings. `created_at` uses the accepted RFC
3339 / ISO 8601 UTC representation.

For Stage 2, `recent_institutions` is the exact approved representation of
recent/basic Institution activity. Do not invent activity events, audit data,
support status, issue queues, health scores, last-login summaries, or
educational activity.

### 5.7 Exact success response

Successful response is `200 OK`:

```json
{
  "data": {
    "institutions": {
      "total": 20,
      "active": 18,
      "inactive": 2
    },
    "users": {
      "total": 2800,
      "active": 2720
    },
    "recent_institutions": [
      {
        "id": "uuid",
        "name": "Example School",
        "type": "school",
        "status": "active",
        "created_at": "2026-08-01T10:00:00Z"
      }
    ]
  }
}
```

Response rules:

- use exactly one top-level `data` key;
- do not add `message`, `meta`, `pagination`, or `links`;
- use snake_case keys;
- return exact integer types for all count values;
- return the exact recent-item field allowlist;
- return no optional dashboard blocks in this task;
- never expose raw models, internal aggregate aliases, SQL, hidden fields, or
  relationship graphs;
- the empty state is a normal `200` response:

  ```json
  {
    "data": {
      "institutions": {
        "total": 0,
        "active": 0,
        "inactive": 0
      },
      "users": {
        "total": 0,
        "active": 0
      },
      "recent_institutions": []
    }
  }
  ```

### 5.8 Explicitly excluded optional dashboard metrics

The locked API contract permits optional dashboard metrics to evolve, but this
task intentionally approves none beyond the exact core response in Section
5.7.

Do not add:

- institutions requiring attention;
- support tickets or issue reports;
- storage or upload usage;
- user role counts;
- online/recently logged-in users;
- login trend charts;
- Institution growth charts;
- educational activity, groups, topics, materials, tasks, attempts,
  submissions, scores, results, or understanding categories;
- cross-Institution comparison or ranking;
- health, risk, performance, or engagement scores;
- global settings;
- billing, subscription, plan, license, quota, or revenue data.

The active/inactive Institution counts and `recent_institutions` list are the
complete Stage 2 attention/activity surface approved by this task. A later
approved contract may add metrics without retroactively widening this task.

### 5.9 Query and consistency requirements

Use a focused dashboard query/action that performs bounded server-side work.

Expected logical query shape:

1. one Institution conditional aggregate for `total`, `active`, and
   `inactive`;
2. one User conditional aggregate for `total` and `active`;
3. one ordered, projected, limited query for `recent_institutions`.

An equivalent or better implementation is acceptable if it preserves the
exact contract and remains clear. Requirements:

- no N+1 query pattern;
- no per-Institution or per-role count query;
- no loading full Institution/User tables into application memory;
- select only required recent-item columns;
- use canonical enum values, not duplicated string authorities where accepted
  enum access is appropriate;
- deterministic recent ordering;
- no raw client input in SQL;
- no strict cross-query historical snapshot guarantee is required, but each
  aggregate block must be internally consistent;
- no write, lock, token mutation, login timestamp update, or other side effect
  may occur;
- no cache is required or approved.

### 5.10 Failure behavior

Authentication, account/institution status, password, role, and request
validation failures must return the accepted centralized envelopes without
running the dashboard read model where the accepted middleware order prevents
it.

Unexpected database/application failure must:

- return the accepted `500 server_error` envelope;
- expose no SQL, table/column detail, model internals, stack trace, user data,
  or secret;
- perform no mutation;
- not return partial dashboard data as a successful response.

Do not invent a dashboard-specific conflict or error code.

---

## 6. Architecture and Code Organization

### 6.1 Thin HTTP layer

Use one focused invokable/small controller in the accepted Platform namespace.
It should coordinate only validated no-query input, the dashboard read
action/query, explicit Resource/read-model serialization, and the `200`
response.

Do not place complete aggregate SQL and field mapping directly inside a large
controller method.

### 6.2 Dedicated no-query boundary

Use a dedicated Form Request or an equally explicit accepted validation
boundary to reject unsupported query keys. It must not contain authorization
or business aggregates.

### 6.3 Focused dashboard read action/query

Place aggregate and recent-Institution retrieval in one focused Platform
dashboard query/action. Do not create:

- a generic repository framework;
- a broad `PlatformManagementService`;
- a reusable analytics engine;
- a global statistics module;
- a data warehouse abstraction.

### 6.4 Explicit response serialization

Use explicit Laravel Resource/read-model serialization for the dashboard and
recent Institution summaries. Reuse accepted Institution formatting only when
it preserves the exact five-field recent-item contract cleanly.

Never return raw Eloquent models or unrestricted `toArray()` output.

### 6.5 Read-only responsibility

No dashboard request may save, touch, dispatch mutation events, update
`last_login_at`, refresh timestamps, rotate/revoke tokens, or change any
Institution/User/settings row.

### 6.6 Existing schema and dependencies are sufficient

No migration, index, seed, package, Composer change, cache, queue, scheduler,
or environment variable is expected. Use the accepted PostgreSQL schema and
framework capabilities.

### 6.7 No duplicated business authority

Use accepted status/role enums and existing auth middleware. Dashboard code
must not become a second authority for whether a user can log in or whether an
Institution is usable.

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
tasks/backend/stage-02/S02-BE-004-*.md
backend/routes/api.php
backend/app/Enums/InstitutionStatus.php
backend/app/Enums/UserRole.php
backend/app/Models/Institution.php
backend/app/Models/User.php
backend/app/Http/Controllers/Api/V1/Platform/**
backend/app/Http/Requests/Api/V1/Platform/**
backend/app/Http/Resources/Api/V1/Platform/**
backend/app/Actions/Platform/**
backend/app/Queries/Platform/**
backend/app/Support/ApiErrorResponse.php
backend/database/factories/InstitutionFactory.php
backend/database/factories/UserFactory.php
backend/tests/Feature/Platform/**
backend/tests/Feature/Auth/**
backend/tests/Feature/Authorization/**
```

These are discovery guides, not permission to create every path, duplicate
accepted code, or rename accepted architecture.

Protected paths that must not change:

```text
docs/01–09
frontend/**
docker/**
backend/database/migrations/**
backend/composer.json
backend/composer.lock
```

Do not modify unrelated auth, lifecycle, settings, Institution Admin, learning,
or deployment code unless an exact in-scope defect blocks this endpoint. If a
material redesign or protected-path change is required, stop and report
`BLOCKED`.

---

## 8. Authoritative Specification References

Read these locked sources before implementation:

### `docs/01-business-overview.md`

- Platform Owner / Super Admin basic platform monitoring boundary;
- approved role/device model;
- multi-Institution data-separation requirement;
- basic—not advanced—MVP analytics boundary.

### `docs/02-user-roles.md`

- Section 1, `Platform Owner / Super Admin`;
- Section 7, `Access and Permissions Rules`;
- Section 8, desktop-only Platform Owner device boundary.

### `docs/03-features.md`

- Section 2, `Platform Owner / Super Admin Features`, especially basic
  platform statistics and dashboard behavior;
- advanced analytics and later-feature exclusions.

### `docs/04-user-flows.md`

- `Super Admin Dashboard Flow` and `Platform Statistics Flow`;
- recent/basic Institution activity and the daily-learning boundary;
- unauthorized users must be blocked from platform-management data.

### `docs/05-business-rules.md`

- `BR-INST-019` through `BR-INST-021`;
- `BR-ROLE-004` through `BR-ROLE-009`;
- `BR-ACL-001` through `BR-ACL-005`;
- `BR-ACL-014` through `BR-ACL-016`.

### `docs/06-roadmap.md`

- Stage 2, `Multi-Institution Platform Management`;
- `Super Admin Desktop Dashboard`;
- `Super Admin Boundary`;
- Stage 11 boundary for broader dashboards/reports.

### `docs/07-architecture.md`

- Section 8.3, `Platform-Level Super Admin`;
- Section 28, `Reporting Architecture`;
- Section 34, `Performance Architecture`;
- Section 35, `Security Architecture`;
- Section 22.1, Platform Owner role/device feature boundary.

### `docs/08-database.md`

- Institution fields/status/indexes;
- Section 5.1, `users` fields, roles, and role/Institution constraint;
- Section 27, query performance/index guidance.

### `docs/09-api-contracts.md`

- Sections 1–2, general transport, success, validation, authentication, and
  authorization contracts;
- Section 7, all Super Admin Institution endpoints require
  `role = platform_owner`;
- Section 7.1, exact `GET /api/v1/platform/dashboard` core response;
- Section 32 as an explicit separate endpoint not implemented here;
- Section 33, server authorization/scope order;
- Section 36, MVP endpoint inventory and exclusions.

Task-level precision in this file narrows ambiguous optional dashboard details
without overriding locked product behavior.

---

## 9. Relevant Business and Security Rules

The implementation must preserve:

- Platform Owner manages platform/institutions, not daily classroom work;
- backend authorization is authoritative;
- inactive users are blocked;
- first-login password gate remains enforced;
- Institution status enforcement keeps its accepted middleware precedence;
- aggregate reporting must not disclose private record-level data;
- report filters cannot widen scope—this endpoint accepts no filters;
- error messages must not reveal protected details;
- no request may mutate state;
- advanced analytics is outside MVP/Stage 2 scope.

---

## 10. Functional Requirements

1. Add exactly `GET /api/v1/platform/dashboard`.
2. Reuse the accepted Platform Owner route group and middleware order.
3. Reject all query keys with `422 validation_failed`.
4. Count all Institutions once.
5. Count active and inactive Institutions by canonical status.
6. Return internally consistent Institution totals.
7. Count all User rows across all five roles.
8. Count individually active User rows through `users.is_active` only.
9. Return no user identity or breakdown.
10. Return at most five recent Institutions.
11. Order recent Institutions by `created_at DESC, id DESC`.
12. Return only the five approved recent-item fields.
13. Return correct zero/empty values when no rows exist.
14. Use bounded aggregate/projected PostgreSQL queries.
15. Return the exact `200` envelope with no `message` or `meta`.
16. Preserve all accepted centralized error behavior.
17. Perform no write or side effect.
18. Do not implement any optional/later dashboard block.

---

## 11. Validation and Error Contract

Required expected errors:

| Condition | HTTP | Code | Required outcome |
|---|---:|---|---|
| Missing/invalid Bearer token | 401 | `authentication_required` | No dashboard data |
| Inactive Platform Owner | 403 | `user_inactive` | No dashboard data |
| Password-change-required Platform Owner | 403 | `password_change_required` | No dashboard data |
| Active Institution user in inactive Institution | 403 | `institution_inactive` | Preserve middleware precedence |
| Active/password-complete non-Platform-Owner | 403 | `forbidden` | No dashboard data |
| Any query key | 422 | `validation_failed` | Field errors; no filtered dashboard |
| Unexpected server/database failure | 500 | `server_error` | No partial success or internal leakage |

All errors must use the accepted centralized envelope with `errors` as an
object. Do not create a dashboard-specific `404`, `409`, or custom error code.

---

## 12. Required Automated Tests

Use the accepted PostgreSQL test runtime. Test names may follow repository
conventions, but coverage must prove every behavior below.

### 12.1 Route and authorization

- exact route and HTTP verb exist once;
- accepted middleware order is attached;
- unauthenticated and invalid-token requests return exact `401` contract;
- inactive Platform Owner returns `403 user_inactive`;
- password-gated Platform Owner returns `403 password_change_required`;
- Institution Admin, Teacher, Student, and Parent are each denied with
  `403 forbidden` when earlier gates pass;
- an Institution user in an inactive Institution preserves accepted
  `403 institution_inactive` precedence;
- active, password-complete Platform Owner receives `200`.

### 12.2 Request validation

- no-query request succeeds;
- representative unknown query keys return `422 validation_failed`;
- multiple unsupported keys are rejected together through field-level errors;
- query values do not appear in a successful response or influence counts;
- validation failure causes no database mutation.

### 12.3 Institution counts

- mixed active/inactive fixtures produce exact totals;
- `total = active + inactive`;
- Institutions with zero users are counted;
- optional-null profile/settings fields do not exclude an Institution;
- empty Institution table returns `0/0/0`;
- returned values are JSON integers.

### 12.4 User counts

- all five role types participate in `total`;
- Platform Owner accounts are included;
- active and inactive accounts produce exact counts;
- `active` depends only on `users.is_active`;
- individually active users in an inactive Institution remain counted as
  active accounts;
- `must_change_password`, tokens, and `last_login_at` do not change counts;
- no role/Institution/user identity breakdown leaks;
- returned values are JSON integers.

### 12.5 Recent Institutions

- newest Institutions are ordered by `created_at DESC`;
- equal timestamps use `id DESC` deterministically;
- more than five fixtures return exactly five;
- active and inactive Institutions are both eligible;
- fewer than five return all existing Institutions;
- no Institution returns `[]`;
- exact item fields are present and protected fields are absent;
- timestamps use accepted UTC serialization.

### 12.6 Exact response and empty state

- response contains exactly top-level `data`;
- `data` contains exactly `institutions`, `users`, and
  `recent_institutions`;
- `message`, `meta`, `pagination`, `links`, and optional metric blocks are
  absent;
- full empty-state response matches Section 5.7;
- no settings, contacts, creator, deactivation timestamp, user identity,
  token, support, issue, or learning data appears.

### 12.7 Read-only and query quality

- request does not change Institution/User timestamps or fields;
- request does not create/revoke/rotate tokens;
- dashboard execution uses bounded aggregate/projected queries independent of
  Institution/User row count;
- no N+1, per-Institution, or per-role count loop exists;
- unexpected query failure uses centralized `500` behavior where the accepted
  test style can exercise it without unsafe production hooks.

### 12.8 Regression

Run and preserve accepted tests for:

- `S02-BE-001` list/detail;
- `S02-BE-002` create;
- `S02-BE-003` update;
- `S02-BE-004` lifecycle/access enforcement;
- Stage 1 authentication/session behavior;
- role middleware and centralized error envelopes;
- full backend suite.

Do not introduce production-only test routes or SQLite-only tests.

---

## 13. Quality Gates and Verification

Run repository-equivalent commands from the accepted backend environment and
report exact commands/results:

```text
php artisan route:list --path=api/v1/platform/dashboard
php artisan test --filter=PlatformDashboard
php artisan test --filter=PlatformInstitution
php artisan test --filter=AuthenticationSessionApiTest
php artisan test --filter=RoleAuthorizationMiddlewareTest
php artisan test
vendor/bin/pint --test
composer validate --strict
```

If real test class/filter names differ, run and report the actual focused
equivalents. A zero-test filter is not a pass.

Required scope/integrity checks:

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
it omits the working-tree implementation. Treat `git status --short` as the
complete path inventory, inspect the full tracked change set against `HEAD`,
and read every untracked file listed by status in full. Phase 2 must account
for modified, staged, deleted, renamed, and untracked paths without staging
them.

Inspect the complete diff for:

- missing middleware or client-driven authorization;
- incorrect user-count semantics;
- effective-login/online activity mislabeled as `active`;
- optional metric creep;
- raw model/relationship leakage;
- N+1 or in-memory full-table counting;
- non-deterministic recent ordering;
- incorrect limit or extra fields;
- response-envelope drift;
- writes, token changes, timestamp touches, or cache side effects;
- migration/dependency/frontend/docs changes;
- secrets, private data, debug output, or unrelated refactors.

---

## 14. Manual Smoke Check

Use only local/test data and redact credentials/tokens.

1. Start from the accepted PostgreSQL runtime and clean representative test
   state.
2. Create an active, password-complete Platform Owner and obtain a redacted
   token.
3. Create at least six Institutions with controlled `created_at` values and a
   mix of active/inactive statuses.
4. Create representative active/inactive users for all approved roles,
   including one individually active user in an inactive Institution.
5. Record the expected Institution and User counts directly from controlled
   fixtures.
6. Call `GET /api/v1/platform/dashboard` as Platform Owner.
7. Verify exact counts, integer types, recent ordering, limit five, exact item
   fields, and absence of extra blocks.
8. Call with one unsupported query key and verify `422 validation_failed`.
9. Call as one eligible non-Platform-Owner and verify `403 forbidden`.
10. Verify no relevant database row/timestamp/token changed.

Do not use production data. Do not print passwords, Bearer tokens, secret
values, or private user records. If smoke cannot run, report `NOT RUN` and the
exact reason; do not claim success.

---

## 15. Explicit Non-Goals

Do not implement:

- `GET /api/v1/platform/statistics`;
- `S02-BE-006` or `S02-BE-007` Institution Admin APIs;
- `S02-FE-001` through `S02-FE-009`;
- dashboard filters, pagination, configurable limits, or date ranges;
- attention/support/issue/global-settings blocks;
- role, Institution, or login-activity breakdowns;
- online-user/session statistics;
- educational progress or learning metrics;
- charts, trends, comparisons, rankings, predictions, or exports;
- billing, subscription, license, storage, quota, or monetization;
- audit/activity event tables or detailed audit analytics;
- cache, scheduler, queue, event bus, warehouse, or BI integration;
- migrations, indexes, packages, environment changes, or broad refactors;
- docs/01–09 revisions.

---

## 16. Stop Conditions

Stop and report `BLOCKED` before implementation if:

- Stage 1 closure is not PASS;
- any `S02-BE-001` through `S02-BE-004` predecessor is not
  Accepted/delivered;
- current `main` is unavailable, divergent, or not safely synchronized;
- applicable `AGENTS.md`, locked docs, index, or accepted predecessors
  materially conflict;
- the approved task/prompt or truthful Stage 2 index is missing;
- a conflicting dashboard route/implementation already exists;
- accepted Platform Owner route/security/error patterns cannot be reused
  without material redesign;
- the accepted schema lacks the required Institution/User source fields;
- PostgreSQL-capable test runtime is unavailable;
- unrelated user changes overlap required files and cannot be preserved;
- fulfillment requires a protected-path change, migration, dependency, cache,
  frontend work, docs rewrite, or later-task scope.

During implementation, diagnose/fix only in-scope technical failures. During
the read-only acceptance phase, do not self-fix findings.

---

## 17. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git preflight

1. Synchronize safely with `origin/main`.
2. Verify dependencies and clean state.
3. Create/switch to the exact task branch.
4. Ensure the approved task and prompt are present.
5. Update only truthful `S02-BE-005` index state if needed.
6. Do not commit or push.

### Phase 1 — Implementation

1. Implement only this task.
2. Run focused and full verification.
3. Run protected-path/scope checks.
4. Perform the controlled smoke check.
5. Inspect the complete diff.
6. Do not commit or push.

### Phase 2 — Read-only acceptance gate

After implementation, re-read every authority, accepted predecessor evidence,
the complete diff, code, tests, scope checks, and smoke evidence.

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

- `P1`: authorization, protected-data/tenant leakage, secret, destructive, or
  read-only-integrity blocker;
- `P2`: material count semantics, response, ordering, query quality,
  architecture, test, or scope mismatch;
- `P3`: non-blocking observation.

Any remaining P1/P2 means:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop immediately. Do not fix findings inside the same acceptance gate and do
not start `S02-BE-006`.

Acceptance requires all of:

```text
no P1 findings
no P2 findings
focused tests PASS
full backend suite PASS
Pint/Composer checks PASS
protected-path checks clean
manual smoke PASS
task scope clean
```

### Phase 3 — Post-acceptance Git delivery

Run only after Phase 2 returns PASS with no P1/P2.

1. Mark `S02-BE-005` Accepted and review PASS.
2. Preserve every other task's truthful index state.
3. Apply only necessary task/stage lifecycle bookkeeping.
4. Re-run appropriate integrity checks.
5. Create one focused commit using repository convention.
6. Push the exact task branch normally.
7. Open a non-draft PR to `main` with task summary, tests, smoke evidence, and
   scope statement.
8. Verify PR head/base, changed files, checks, and mergeability.
9. Merge only through the accepted repository workflow after required checks
   pass.
10. Fast-forward local `main` after merge.
11. Verify:

    ```text
    local main == origin/main
    working tree clean
    S02-BE-005 = Accepted
    S02-BE-006 remains not started/unapproved unless separately prepared
    ```

Never force-push, rewrite history, bypass hooks, alter global Git config, or
destructively clean unrelated work.

If implementation and review pass but delivery cannot complete, return:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Preserve the safe task branch and report exact evidence.

---

## 18. Acceptance Criteria

- [ ] Task began only after `S02-BE-004` and all earlier predecessors were
      Accepted/delivered.
- [ ] Exact dashboard GET route exists once in the accepted Platform group.
- [ ] Accepted middleware order and Platform Owner-only access hold.
- [ ] All query keys are rejected with `422 validation_failed`.
- [ ] Institution total/active/inactive semantics are exact and consistent.
- [ ] User total includes all roles, including Platform Owner.
- [ ] User active count uses only `users.is_active = true`.
- [ ] Recent list includes at most five active/inactive Institutions.
- [ ] Recent ordering is `created_at DESC, id DESC`.
- [ ] Recent items expose exactly five approved fields.
- [ ] Empty state returns exact zeros and `[]` with `200`.
- [ ] Success response has no message/meta/pagination/optional block.
- [ ] No record-level user, settings, support, issue, or learning data leaks.
- [ ] Queries are bounded, server-side, projected, and N+1-free.
- [ ] Dashboard request performs no write or side effect.
- [ ] Centralized error contracts remain accepted.
- [ ] PostgreSQL-focused and predecessor regression tests pass.
- [ ] Full backend suite, Pint, Composer, diff, and scope checks pass.
- [ ] Controlled smoke check passes with redacted evidence.
- [ ] No migration, dependency, frontend, docs, or later-task scope exists.
- [ ] Phase 2 inventories and reviews every tracked and untracked changed path;
      it does not rely on a commit-range diff that omits working-tree changes.
- [ ] Read-only acceptance reports no P1/P2.
- [ ] GitHub delivery completes and final `main == origin/main` is clean.

---

## 19. Required Codex Final Report

The final report must state:

1. `FINAL STATUS`: `ACCEPTED`, `NOT ACCEPTED`, `BLOCKED`, or
   `DELIVERY BLOCKED`.
2. Dependency/preflight evidence and starting commit SHA.
3. Exact route and dashboard architecture implemented.
4. Institution and User aggregate semantics/results verified.
5. Recent-Institution limit/order/field evidence.
6. Authorization, validation, error, and protected-data evidence.
7. Read-only/query-quality evidence.
8. Focused/full tests and quality commands with real counts/results.
9. Manual smoke result or exact `NOT RUN` reason.
10. Protected-path and complete-diff scope result.
11. Changed files.
12. P1/P2/P3 findings and acceptance verdict.
13. Branch, commit SHA, PR URL/number, merge result, and final synchronized
    `main` SHA when delivery succeeds.
14. Confirmation that `S02-BE-006` was not started.

Do not claim `ACCEPTED` before the read-only gate and required GitHub delivery
both complete.
