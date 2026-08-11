# Codex Task: Platform Institution List & Detail API

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-BE-001` |
| Roadmap stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Backend / platform institution read API` |
| Status | `Accepted` |
| Approved on | `2026-08-10` |
| Depends on | `Stage 1 — Authentication and Role-Based Entry (Closed; Stage DoD PASS)` |
| Blocks | `S02-BE-002`; `S02-FE-003`; `S02-FE-004` |

This task is approved for Codex execution.

Codex must still enforce every dependency, Git preflight, scope, testing,
read-only acceptance, and GitHub delivery gate defined below.

---

## 2. Goal

Implement the first read-only Stage 2 backend slice for Platform Owner institution
management.

The accepted result must provide two real PostgreSQL-backed endpoints:

```text
GET /api/v1/platform/institutions
GET /api/v1/platform/institutions/{institution}
```

An authenticated, active, password-complete `platform_owner` must be able to:

- list institutions through contract-compliant pagination;
- search institutions by name;
- filter by exact institution status and type;
- sort by the endpoint allowlist;
- open one institution by UUID;
- see minimal institution-scoped user totals without receiving user identities
  or protected learning data.

Every other role must be denied by the backend.

This task creates the institution **read API** only. It does not create, edit,
activate, deactivate, or delete institutions.

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

Verified Stage 1 closure state at preparation time:

- `Stage 1 = Closed`;
- `Stage DoD = PASS`;
- all 13 Stage 1 tasks are accepted and delivered;
- closure merge is present on `main` at commit
  `b6c840a9dc935f6a9b2a87a63e5fc99352782ed8`;
- Stage 2 product implementation has not started.

The current accepted backend already contains:

- Laravel 13 under `backend/`;
- PostgreSQL-backed test/runtime infrastructure;
- UUID `institutions`, `users`, and `institution_settings` persistence;
- exact `InstitutionType`, `InstitutionStatus`, and `UserRole` enums;
- `Institution`, `User`, and `InstitutionSetting` models and factories;
- Sanctum Bearer authentication;
- active-user and active-institution enforcement;
- mandatory first-login password-change enforcement;
- reusable `role:<allowed roles>` middleware;
- centralized JSON error envelopes;
- only the four accepted Stage 1 auth endpoints in `backend/routes/api.php`.

Codex must independently re-check the actual current `origin/main`. The commit
above is preparation evidence, not permission to skip preflight or assume that
the repository has not moved.

---

## 4. Stage 2 Control-File Entry Gate

Stage 1 closure guidance requires the Stage 2 task index and first task to be
explicitly approved before Stage 2 implementation starts.

This file is the approved first task. During this task, Codex must also create
the bookkeeping-only file:

```text
tasks/STAGE_02_TASK_INDEX.md
```

before changing production application code, if that index is not already
present.

### 4.1 Exact approved decomposition to record

The Stage 2 index must record this already approved order and scope:

| Order | Task ID | Area | Short outcome |
|---:|---|---|---|
| 1 | `S02-BE-001` | Backend | Institution list/detail API, search, filters, sorting, pagination, and basic user counts |
| 2 | `S02-BE-002` | Backend | Atomic institution creation with safe `institution_settings` initialization |
| 3 | `S02-BE-003` | Backend | Institution basic-profile update with a strict platform-field allowlist |
| 4 | `S02-BE-004` | Backend | Idempotent institution activate/deactivate and institution-user access enforcement |
| 5 | `S02-BE-005` | Backend | Platform dashboard aggregate API |
| 6 | `S02-BE-006` | Backend | Institution Admin list/create API and first-login password gate |
| 7 | `S02-BE-007` | Backend | Institution Admin update/activate/deactivate API |
| 8 | `S02-FE-001` | Frontend | Platform Owner desktop shell and navigation |
| 9 | `S02-FE-002` | Frontend | Real Platform dashboard with loading/error/empty/data states |
| 10 | `S02-FE-003` | Frontend | Institution list, search, filters, sorting, and pagination |
| 11 | `S02-FE-004` | Frontend | Institution detail and basic usage presentation |
| 12 | `S02-FE-005` | Frontend | Create Institution form and mutation flow |
| 13 | `S02-FE-006` | Frontend | Edit Institution form for allowed fields |
| 14 | `S02-FE-007` | Frontend | Activate/deactivate confirmation, in-flight protection, and refresh |
| 15 | `S02-FE-008` | Frontend | Institution Admin list/create UI within Institution detail |
| 16 | `S02-FE-009` | Frontend | Institution Admin edit/activate/deactivate UI |
| 17 | `S02-INT-001` | Integration | Full real-stack Stage 2 end-to-end verification on Windows |

Index rules:

- stage name: `Stage 2 — Multi-Institution Platform Management`;
- stage status while this task is executing: `In Progress`;
- `S02-BE-001` status before acceptance: `Approved`;
- all later tasks: `Planned / not individually approved`;
- the index does not approve implementation of later tasks;
- exact dependencies and detailed acceptance criteria for later tasks are added
  only through their individually approved contracts;
- record that a separate Stage 2 Closure Review follows the 17 implementation
  tasks and is not itself an implementation task.

Do not create detailed task files or Codex prompts for the other 16 tasks.

If an existing `tasks/STAGE_02_TASK_INDEX.md` conflicts with this approved
decomposition, stop and report the exact conflict instead of overwriting it.

---

## 5. Included Scope

### 5.1 Git and dependency preflight

Before implementation:

1. Read root `AGENTS.md` completely.
2. Read `backend/AGENTS.md` completely.
3. Read this complete approved task.
4. Read the referenced locked sections from `docs/01–09`.
5. Read `tasks/README.md` and Stage 1 closure artifacts relevant to the entry
   gate.
6. Verify Stage 1 is closed and its accepted result is on `origin/main`.
7. Verify `origin` is exactly the approved TestLabUz repository.
8. Fetch remote state safely.
9. Verify local `main == origin/main`.
10. Verify the accepted PostgreSQL backend test runtime is usable.
11. Verify no Stage 2 product route or implementation already exists.
12. Verify no unsafe or unrelated dirty state exists.

Required task branch:

```text
task/s02-be-001-institution-read-api
```

If the project owner saved only these approved preparation files on otherwise
clean local `main`:

```text
tasks/backend/stage-02/S02-BE-001-platform-institution-list-detail-api.md
tasks/backend/stage-02/S02-BE-001-CODEX-PROMPT.md
```

they are permitted pre-task additions. Do not commit them directly on `main`.
Create the task branch immediately and carry them into the task branch.

Any other unexplained change is a blocker.

### 5.2 Platform route group

Add the two endpoints under an explicit platform administration route group.

Required security order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:platform_owner
```

Required routes:

```text
GET /api/v1/platform/institutions
GET /api/v1/platform/institutions/{institution}
```

Requirements:

- use the existing middleware aliases and canonical `UserRole` authority;
- do not add a Platform Owner universal bypass to ordinary institution routes;
- do not accept role or institution authority from request data;
- do not weaken the existing auth/status/password gates;
- do not add test-only routes to the production route list.

### 5.3 Institution list query contract

Endpoint:

```text
GET /api/v1/platform/institutions
```

The only accepted query keys are:

```text
search
status
type
page
per_page
sort
direction
```

Unknown query keys must return:

```text
HTTP 422
code = validation_failed
```

This includes unsafe or speculative keys such as:

```text
institution_id
created_by_user_id
role
include_users
include_learning_data
```

#### Search

`search` applies only to institution `name`.

Required behavior:

- trim surrounding whitespace;
- an empty trimmed value behaves as no search filter;
- case-insensitive substring matching under PostgreSQL;
- `%` and `_` in user input are treated as literal text, not uncontrolled SQL
  wildcard operators;
- maximum accepted length: 200 characters;
- parameter binding is mandatory; never concatenate raw input into SQL.

Search must not inspect users, settings, submissions, scores, or other learning
data.

#### Filters

`status` accepts exactly:

```text
active
inactive
```

`type` accepts exactly:

```text
school
college
lyceum
university
institute
learning_center
training_center
private_education
other
```

Invalid values return `422 validation_failed` with field-level errors.

Filters may be combined with each other and with search, sorting, and
pagination.

#### Pagination

Accepted contract:

```text
page: integer, minimum 1, default 1
per_page: integer, minimum 1, maximum 100, default 20
```

The response must use:

```json
{
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

Do not expose Laravel paginator transport fields that are outside the locked
contract, including `current_page`, page URLs, or a top-level `links` block.

#### Sorting

Allowed `sort` values:

```text
name
created_at
updated_at
status
```

Allowed `direction` values:

```text
asc
desc
```

Task defaults:

```text
sort = name
direction = asc
```

For `sort=name`, sort case-insensitively by the normalized/lowercase name.
For every sort mode, add a deterministic UUID tie-breaker so repeated
pagination cannot arbitrarily reorder equal primary sort values.

Raw client sort expressions or column names must never be passed directly to
`orderBy`.

### 5.4 Institution detail contract

Endpoint:

```text
GET /api/v1/platform/institutions/{institution}
```

Requirements:

- resolve the institution by UUID through the accepted model/routing style;
- a malformed or unknown UUID must produce the centralized scope-safe
  `404 resource_not_found` response;
- return only institution platform metadata and the basic user counts defined
  below;
- do not expose related user records, credentials, settings policy values,
  groups, topics, materials, submissions, scores, results, or files.

### 5.5 Basic user-count contract

Both list items and institution detail return:

```json
"user_counts": {
  "total": 42,
  "active": 40
}
```

Count rules:

- count only `users.institution_id = institution.id`;
- `total` includes active and inactive institution users;
- `active` includes only `is_active = true` institution users;
- Platform Owner accounts are never counted because they are platform-scoped;
- no role breakdown is part of this task;
- no user identity, contact, `last_login_at`, or password state is returned;
- compute counts server-side without an N+1 query per institution.

### 5.6 Exact success response fields

#### List — `200`

```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Example School",
      "type": "school",
      "status": "active",
      "contact_email": "info@example.uz",
      "contact_phone": "+998...",
      "created_at": "2026-08-07T15:00:00Z",
      "updated_at": "2026-08-07T15:00:00Z",
      "user_counts": {
        "total": 42,
        "active": 40
      }
    }
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 20,
      "total": 1,
      "last_page": 1
    }
  }
}
```

#### Detail — `200`

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
    "updated_at": "2026-08-07T15:00:00Z",
    "user_counts": {
      "total": 42,
      "active": 40
    }
  }
}
```

Response rules:

- all keys are snake_case;
- enum fields serialize to their persisted string values;
- timestamps use RFC3339/ISO 8601 UTC output;
- nullable contact/address/description fields serialize as JSON `null` when
  applicable;
- GET success responses do not add a success `message`;
- list items intentionally omit `address` and `description`;
- neither response exposes `created_by_user_id`, `deactivated_at`, settings,
  users, tokens, or learning records.

The backend must use the established Laravel Resource/response conventions,
not ad-hoc controller arrays that duplicate serialization logic.

---

## 6. Architecture and Code Organization

### 6.1 Thin HTTP layer

The controller layer must:

1. receive an already validated list request or resolved route model;
2. call a focused institution read query/action;
3. return a Resource/collection response.

Do not put the complete filter/sort/count query and response mapping into one
large controller method.

### 6.2 Focused list query

Use one focused query/action abstraction for the institution list when it
materially owns:

- search;
- filters;
- allowlisted sorting;
- stable tie-breaking;
- aggregate user counts;
- pagination.

Do not create a generic repository framework or a broad
`PlatformManagementService`.

### 6.3 Validation boundary

Use a dedicated Form Request or an equally established request-validation
boundary for list query validation, including rejection of unknown keys.

Do not mix request-shape validation with authorization or database business
logic.

### 6.4 Resources

Use reusable institution Resource serialization with an explicit summary/detail
boundary. Avoid duplicating field maps between controllers.

Do not expose model attributes through unrestricted `toArray()` output.

### 6.5 Query quality

- use PostgreSQL/server-side search, filters, sorting, counts, and pagination;
- avoid loading full `users` collections to count them;
- avoid N+1 queries;
- select/eager-load only data required by the response;
- preserve existing database indexes and constraints;
- do not add a migration in this task unless a locked contract proves one is
  missing; if so, stop because schema work is outside the approved scope.

---

## 7. Relevant Files

Codex must inspect the actual repository before deciding the final path names.

| File or directory | Expected action | Reason |
|---|---|---|
| `AGENTS.md` | Read | Root authority/workflow |
| `backend/AGENTS.md` | Read | Backend rules |
| `tasks/README.md` | Inspect; lifecycle-only update if required after acceptance | Stage control |
| `tasks/STAGE_01_CLOSURE_REVIEW.md` | Read | Verify closed dependency |
| `tasks/STAGE_02_TASK_INDEX.md` | Create if absent; otherwise verify | Required approved Stage 2 control index |
| `tasks/backend/stage-02/S02-BE-001-platform-institution-list-detail-api.md` | Preserve; mark Accepted only after Phase 2 PASS | Approved contract/audit trail |
| `tasks/backend/stage-02/S02-BE-001-CODEX-PROMPT.md` | Preserve | Execution artifact |
| `backend/routes/api.php` | Modify | Register protected read routes |
| `backend/app/Http/Controllers/Api/V1/Platform/*` | Create | Thin list/detail HTTP layer |
| `backend/app/Http/Requests/Platform/*` | Create | Strict list query validation |
| `backend/app/Http/Resources/Platform/*` | Create | Exact summary/detail response contract |
| focused Institution query/action location under `backend/app/` | Create | Search/filter/sort/count/pagination boundary |
| `backend/app/Models/Institution.php` | Reuse; minimal query helper only if justified | Accepted model/relationships |
| `backend/app/Enums/InstitutionStatus.php` | Reuse | Canonical statuses |
| `backend/app/Enums/InstitutionType.php` | Reuse | Canonical types |
| `backend/tests/Feature/Platform/*` | Create | Read API behavior/security tests |
| `backend/tests/Unit/*` | Create only if extracted deterministic query helpers justify it | Focused unit coverage |

Changes outside this list require a concrete technical necessity inside the
approved scope and must be reported.

Do not modify:

- locked `docs/01–09`;
- `frontend/`;
- `docker/`;
- database migrations/schema;
- auth endpoint semantics;
- existing institution/user/settings constraints;
- Composer dependencies;
- CI configuration.

---

## 8. Authoritative Specification References

The locked specifications remain authoritative over this task.

| Document | Exact section | Requirement used by this task |
|---|---|---|
| `docs/02-user-roles.md` | `1. Platform Owner / Super Admin` | Platform institution list/status/basic usage authority and daily-learning boundary |
| `docs/04-user-flows.md` | Platform Owner institution-management flow | Platform Owner can locate and view institutions through platform administration |
| `docs/05-business-rules.md` | `2. Institution and Data Separation Rules` — `BR-INST-001`–`BR-INST-009` | Shared-schema isolation; filters/pagination cannot bypass access rules |
| `docs/05-business-rules.md` | `BR-INST-010`–`BR-INST-015` | Exact active/inactive lifecycle values and historical preservation boundary |
| `docs/05-business-rules.md` | `BR-INST-019`–`BR-INST-021` | Platform management authority and no ordinary learning-data interference |
| `docs/06-roadmap.md` | `7. Stage 2 — Multi-Institution Platform Management` | Institution list, search/filter, detail, status, basic usage, protected-data boundary |
| `docs/07-architecture.md` | `6. Laravel Backend Structure` | Correct controller/request/resource/action/query placement |
| `docs/07-architecture.md` | `7. Backend Coding Rules` | Thin controllers, Form Requests, focused authorization and query boundaries |
| `docs/07-architecture.md` | `8. Multi-Institution Architecture` | Explicit platform actions; no accidental global unscoping |
| `docs/07-architecture.md` | `9. Identity and Authorization Architecture` | Canonical role and layered security |
| `docs/07-architecture.md` | `23. API Boundary Principles` | Server authority, stable API boundary, client cannot expand scope |
| `docs/07-architecture.md` | `32. Testing Architecture` | Feature, security, integration, and regression expectations |
| `docs/08-database.md` | `3. Multi-Institution / Tenant Model` | `institutions` tenant root and Platform Owner exception |
| `docs/08-database.md` | `4. Institutions` | Institution fields, exact types/statuses, indexes, and no hard delete |
| `docs/08-database.md` | `5. Users and Roles` | Institution user ownership and count source |
| `docs/09-api-contracts.md` | `1–2. API Contract Overview / General API Conventions` | `/api/v1`, JSON conventions, server authority |
| `docs/09-api-contracts.md` | `5. Error Response Contract` | Stable errors and field-level validation output |
| `docs/09-api-contracts.md` | `6. Pagination, Search, Filter, and Sorting Contract` | Exact query and pagination envelope |
| `docs/09-api-contracts.md` | `7. Super Admin Institution APIs` — `7.2` and `7.4` | Exact list/detail endpoints, query keys, sort allowlist, role requirement |
| `docs/09-api-contracts.md` | `33. Security and Authorization Contract` | Auth/status/password/role enforcement order |
| `AGENTS.md` | Applicable workflow, testing, quality, scope, and completion sections | One-task execution and acceptance/delivery protocol |
| `backend/AGENTS.md` | Entire applicable file | Backend authority, security, code organization, testing |

If any referenced section has moved on current `main`, use its current exact
heading and report the change without altering the locked rule.

---

## 9. Relevant Business and Security Rules

1. Only `platform_owner` may use these platform endpoints.
2. Role authority comes from the authenticated persisted user, never request
   data.
3. Platform Owner reads institutions only through explicit platform routes.
4. Platform Owner status does not make ordinary institution-scoped queries
   automatically unscoped.
5. An inactive Platform Owner is denied before role authorization.
6. A user with `must_change_password = true` is denied before role
   authorization.
7. Institution status filtering uses only `active` and `inactive`.
8. Institution type filtering uses only the nine locked enum values.
9. Pagination, filters, and search must not reveal related protected data.
10. Basic counts are aggregate institution-user facts, not permission to expose
    user records.
11. Knowing an institution UUID does not bypass authentication or role checks.
12. No endpoint in this task changes institution or user state.
13. No endpoint in this task hard-deletes any record.
14. No endpoint in this task exposes educational-policy settings.
15. All database access is parameterized and allowlisted.

---

## 10. Functional Requirements

1. Stage 1 closure is independently verified on `origin/main`.
2. Work occurs on `task/s02-be-001-institution-read-api`.
3. The Stage 2 task index gate is satisfied exactly as Section 4 defines.
4. `GET /api/v1/platform/institutions` exists.
5. `GET /api/v1/platform/institutions/{institution}` exists.
6. Both routes use the accepted security middleware order.
7. An authorized Platform Owner receives `200`.
8. Unauthenticated requests receive `401 authentication_required`.
9. Inactive Platform Owner requests receive `403 user_inactive`.
10. Password-incomplete requests receive `403 password_change_required`.
11. Institution Admin, Teacher, Student, and Parent receive `403 forbidden`.
12. Search is case-insensitive literal substring matching on name only.
13. Status filter accepts only the locked statuses.
14. Type filter accepts only the locked types.
15. Search and both filters compose correctly.
16. Pagination defaults to page 1 / 20 items.
17. `per_page` accepts 1–100 and rejects values outside that range.
18. Pagination response uses `meta.pagination.page`, not `current_page`.
19. All four allowed sort fields work in both allowed directions.
20. Unknown sort fields/directions are rejected.
21. Unknown query keys are rejected.
22. Sorting is deterministic under equal primary values.
23. List items use the exact summary response fields.
24. Detail uses the exact detail response fields.
25. Both responses include correct total/active institution-user counts.
26. Counts do not create N+1 queries or load user collections.
27. Unknown/malformed institution IDs return `404 resource_not_found`.
28. No user identity or protected learning data is serialized.
29. No create/update/activate/deactivate/delete behavior is added.
30. No database schema, locked docs, frontend, Docker, dependency, or CI change
    is introduced.
31. Focused and full backend tests pass on PostgreSQL.
32. Pint and strict Composer validation pass.

---

## 11. Validation and Error Contract

Expected cases:

| Case | HTTP | Stable code / result |
|---|---:|---|
| Missing/invalid token | `401` | `authentication_required` |
| Inactive Platform Owner | `403` | `user_inactive` |
| Password change still required | `403` | `password_change_required` |
| Authenticated wrong role | `403` | `forbidden` |
| Unknown/malformed institution UUID | `404` | `resource_not_found` |
| Invalid `status`, `type`, `page`, `per_page`, `sort`, or `direction` | `422` | `validation_failed` with field errors |
| Unknown query parameter | `422` | `validation_failed` with field errors |
| Valid empty result set | `200` | `data = []` plus pagination meta |
| Unexpected server failure | `500` | `server_error`; no internal details |

Do not introduce endpoint-specific machine codes such as:

```text
institution_list_forbidden
invalid_institution_filter
institution_not_visible
```

Do not expose SQL, stack traces, model internals, tokens, or record-existence
details through errors or logs.

---

## 12. Required Automated Tests

Use descriptive tests and focused fixtures. The exact test file split may
follow current repository conventions.

### 12.1 Route and authorization tests

- [ ] Both routes exist only under `/api/v1/platform/institutions`.
- [ ] Valid active/password-complete Platform Owner can list institutions.
- [ ] Valid active/password-complete Platform Owner can view detail.
- [ ] Missing token returns `401 authentication_required` for both routes.
- [ ] Inactive Platform Owner returns `403 user_inactive`.
- [ ] Password-incomplete Platform Owner returns
      `403 password_change_required` before role checking.
- [ ] Institution Admin returns `403 forbidden`.
- [ ] Teacher returns `403 forbidden`.
- [ ] Student returns `403 forbidden`.
- [ ] Parent returns `403 forbidden`.
- [ ] Query/header/body attempts to claim `platform_owner` do not change the
      persisted role decision.

### 12.2 List/search/filter tests

- [ ] No filters returns all institutions, not platform users or unrelated
      resources.
- [ ] Search matches institution name case-insensitively.
- [ ] Search does not match contact, description, users, or settings.
- [ ] Leading/trailing whitespace is normalized.
- [ ] Literal `%` and `_` search behavior is proven.
- [ ] `status=active` returns only active institutions.
- [ ] `status=inactive` returns only inactive institutions.
- [ ] Every locked type value is accepted.
- [ ] Type filter returns only the selected type.
- [ ] Search + status + type compose correctly.
- [ ] Invalid status and type each return field-level `422` errors.
- [ ] Unknown query keys return `422 validation_failed`.

### 12.3 Pagination/sorting tests

- [ ] Default pagination is `page=1`, `per_page=20`.
- [ ] Custom valid page/per-page values work.
- [ ] `per_page=100` works.
- [ ] `per_page=0`, `per_page=101`, `page=0`, and non-integers fail.
- [ ] Empty result uses the locked pagination shape.
- [ ] Response contains `page`, not `current_page`.
- [ ] Response does not contain paginator links/URLs.
- [ ] `name`, `created_at`, `updated_at`, and `status` sorts work.
- [ ] Both `asc` and `desc` work.
- [ ] Default is case-insensitive `name asc`.
- [ ] Equal primary sort values use deterministic UUID tie-breaking.
- [ ] Unknown sort and direction fail validation.

### 12.4 Resource/count/detail tests

- [ ] Summary exposes exactly the approved list fields.
- [ ] Detail exposes exactly the approved detail fields.
- [ ] Nullable fields serialize as `null`.
- [ ] Enum values and timestamps serialize correctly.
- [ ] Counts include users from only the current institution.
- [ ] `total` includes active and inactive institution users.
- [ ] `active` excludes inactive users.
- [ ] Platform Owners are not counted.
- [ ] Related user objects and private account fields are absent.
- [ ] Settings and learning data are absent.
- [ ] A known UUID returns the correct institution.
- [ ] Unknown valid UUID returns `404 resource_not_found`.
- [ ] Malformed UUID returns the same scope-safe `404` contract.
- [ ] List query does not perform one user-count query per institution.

### 12.5 Regression

All accepted prior backend behavior remains green, including:

- API envelope/error foundation;
- PostgreSQL persistence and constraints;
- login/logout/current-user;
- active account/institution enforcement;
- first-login password gate;
- role authorization matrix;
- Sanctum behavior.

---

## 13. Quality Gates and Verification

Run inside the accepted PostgreSQL-capable backend runtime. If the host PHP
still lacks `pdo_pgsql`, do not substitute SQLite; use the accepted Docker
runtime and report the exact commands actually used.

Required equivalent checks:

```text
php artisan route:list --path=api/v1/platform/institutions
php artisan test --filter=PlatformInstitution
php artisan test
vendor/bin/pint --test
composer validate --strict
```

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

- secrets, credentials, `.env` content, tokens, or private keys;
- raw query concatenation;
- unvalidated sort input;
- unrestricted model serialization;
- authorization bypasses;
- accidental user/learning-data exposure;
- N+1 count queries;
- unrelated refactors.

---

## 14. Manual Smoke Check

Using controlled local/test data and the real Laravel/PostgreSQL runtime:

1. Authenticate an active password-complete Platform Owner.
2. Request the unfiltered institution list and verify the exact envelope.
3. Combine `search`, `status`, `type`, sorting, and pagination.
4. Open one returned institution detail.
5. Verify total/active counts against controlled users.
6. Verify no user identity/settings/learning data appears.
7. Repeat one request as each wrong role and confirm `403 forbidden`.
8. Request an unknown UUID and confirm `404 resource_not_found`.
9. Submit an unknown query key and confirm `422 validation_failed`.

If manual verification cannot run in the environment, report it as `NOT RUN`
with the exact reason. Do not claim it passed.

---

## 15. Explicit Non-Goals

- Create Institution API (`S02-BE-002`).
- Automatic `institution_settings` creation (`S02-BE-002`).
- Institution profile update (`S02-BE-003`).
- Activate/deactivate and access restoration (`S02-BE-004`).
- Platform dashboard/statistics endpoint (`S02-BE-005`).
- Institution Admin account APIs (`S02-BE-006`, `S02-BE-007`).
- Frontend/Flutter work.
- Mobile Platform Owner UI.
- Institution learning-settings management.
- Role breakdown or detailed institution analytics.
- User identities, user detail, export, or bulk operations.
- Groups, Topics, Materials, Homework, Blitz, submissions, scores, results, or
  reports.
- Support tickets, impersonation, billing, subscriptions, licenses, or global
  settings.
- Institution hard delete.
- Schema/index/migration changes.
- Package/dependency additions.
- Refactoring accepted Stage 1 auth/session/role architecture.
- Fixing the known Stage 1 P3 for requests without
  `Accept: application/json`.
- Creating detailed contracts/prompts for the remaining Stage 2 tasks.
- Starting `S02-BE-002`.

---

## 16. Stop Conditions

Stop and report before changing product behavior if:

- Stage 1 is not closed on current `origin/main`;
- local `main` cannot safely synchronize with `origin/main`;
- `origin` is unexpected;
- unexplained dirty state exists;
- the task branch cannot be created safely;
- an existing Stage 2 index conflicts with the approved 17-task
  decomposition;
- Stage 2 institution endpoints already exist in a materially conflicting
  form;
- the accepted Institution/User persistence or role middleware is missing or
  broken;
- correct work requires a migration/schema/dependency change;
- locked documents conflict on list/detail behavior;
- the requested basic usage response cannot be implemented without exposing
  protected data;
- safe authorization or exact error-envelope behavior cannot be preserved;
- correct implementation requires Create/Update/Lifecycle/Dashboard/Admin or
  frontend scope;
- a pre-existing required backend quality gate fails materially;
- safe completion would require force-push, history rewrite, destructive
  cleanup, or check bypass;
- a credential or secret would need to be committed or exposed.

Do not guess, silently broaden scope, or modify `docs/01–09` from this task.

---

## 17. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git Preflight

1. Complete Section 5.1.
2. Create/switch to:

   ```text
   task/s02-be-001-institution-read-api
   ```

3. Ensure the approved task and prompt are on the task branch.
4. Create/verify the Stage 2 task index exactly as Section 4 defines.
5. Do not commit or push.

### Phase 1 — Implementation

Implement only this task.

Run all focused tests, full backend regression, route inspection, Pint,
Composer validation, scope checks, security review, and manual smoke where
possible.

Do not commit or push during Phase 1.

### Phase 2 — Read-Only Acceptance Gate

Re-read:

- this approved task;
- applicable `AGENTS.md` files;
- all referenced locked sections;
- the complete diff;
- routes/resources/queries;
- focused and full test results;
- authorization, validation, leakage, and query-quality evidence.

During Phase 2:

- make no file edits;
- run no auto-fix command;
- do not stage files;
- do not commit;
- do not push;
- do not merge;
- do not fix findings after the gate starts.

Finding severity:

- `P1`: security, authorization, data leakage, destructive, or contract-breaking
  blocker;
- `P2`: material scope, architecture, response, validation, pagination, test,
  or query-quality mismatch;
- `P3`: non-blocking observation.

If any P1/P2 remains, return:

```text
FINAL STATUS: NOT ACCEPTED
```

Then stop. Do not self-fix and do not start another task.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 passes with no P1/P2 finding.

1. Mark this task `Accepted`.
2. Update `tasks/STAGE_02_TASK_INDEX.md`:
   - `S02-BE-001 = Accepted`;
   - review = `PASS`;
   - delivery is finalized only after merge;
   - later tasks remain planned/not individually approved.
3. Apply only necessary Stage 2 lifecycle bookkeeping in `tasks/README.md`.
4. Re-run final diff, scope, security, format, and secret checks.
5. Stage only approved files.
6. Create one focused commit:

   ```text
   feat(institutions): add platform institution read API
   ```

   Commit body:

   ```text
   Task: S02-BE-001
   ```

7. Push the task branch to approved `origin`.
8. Open a Pull Request to `main` when tooling/authentication permits.
9. Never bypass required checks or branch protection.
10. Merge only when required checks pass and the merge is permitted.
11. Synchronize local `main` from merged `origin/main` using safe
    fast-forward-only operations.
12. Verify local `main == origin/main`.
13. Verify `git status --short` is empty.

If Phase 2 passed but delivery cannot safely complete, return:

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

Do not start `S02-BE-002`.

---

## 18. Acceptance Criteria

- [ ] Stage 1 and repository preflight gates pass.
- [ ] Stage 2 task index exactly records the approved decomposition without
      creating later detailed tasks/prompts.
- [ ] Both approved read routes exist with the correct middleware order.
- [ ] Only active, password-complete Platform Owner access succeeds.
- [ ] All four wrong roles are denied with `403 forbidden`.
- [ ] Search/filter validation and composition match the task contract.
- [ ] Pagination and sorting match the locked contract exactly.
- [ ] Unknown query keys are rejected with `422 validation_failed`.
- [ ] List and detail serialize exactly the approved fields.
- [ ] Basic total/active user counts are correct and institution-bound.
- [ ] No user identity, settings policy, or learning data leaks.
- [ ] Unknown/malformed UUIDs use scope-safe `404 resource_not_found`.
- [ ] Controllers remain thin and validation/query/resource responsibilities are
      correctly placed.
- [ ] No obvious N+1 or unsafe raw query/sort behavior exists.
- [ ] Focused and full PostgreSQL backend tests pass.
- [ ] Pint and strict Composer validation pass.
- [ ] Locked docs, frontend, Docker, schema, dependencies, and CI are unchanged.
- [ ] No adjacent Stage 2 behavior or unrelated refactor is included.
- [ ] Read-only acceptance gate reports no P1/P2 finding.
- [ ] Accepted result is delivered to `origin/main` and final Git state is clean.

---

## 19. Required Codex Final Report

Return all of the following:

1. **Final status** — exactly `ACCEPTED`, `NOT ACCEPTED`, or
   `DELIVERY BLOCKED`.
2. **Dependency/Git preflight** — Stage 1 closure, remote, synchronized main,
   clean/safe state, and task branch evidence.
3. **Stage 2 control gate** — index creation/verification and exact later-task
   status boundary.
4. **Implementation summary** — list/detail behavior now available.
5. **Changed files** — every changed file and why.
6. **Route/middleware evidence** — exact endpoints and security order.
7. **Query contract evidence** — search, filters, unknown-key validation,
   pagination, sort allowlist, deterministic tie-breaker.
8. **Resource/count evidence** — exact fields, total/active count correctness,
   and no protected-data exposure.
9. **Authorization/security evidence** — positive Platform Owner and all
   negative role/account/password/UUID cases.
10. **Acceptance gate findings** — `No blocking or material findings` or exact
    P1/P2/P3 findings.
11. **Acceptance criteria** — PASS/FAIL evidence for every Section 18 item.
12. **Tests and quality gates** — exact commands, counts, and results.
13. **Query-quality evidence** — N+1 prevention and parameterized/allowlisted
    query behavior.
14. **Scope confirmation** — explicit confirmation of all protected paths and
    non-goals.
15. **Manual smoke status** — passed, failed, or not run with exact reason.
16. **GitHub delivery evidence** — commit hash/subject, pushed branch, PR,
    checks/merge, local/main hashes, and final clean status.
17. **Risks, deviations, or blockers** — including pre-existing failures.

Do not start `S02-BE-002`.
