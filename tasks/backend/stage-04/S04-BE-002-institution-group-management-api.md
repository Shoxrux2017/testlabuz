# S04-BE-002 — Institution Group Management API

## Task Metadata

| Field | Value |
|---|---|
| Task ID | `S04-BE-002` |
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | Backend |
| Status | `Draft` |
| Direct dependency | `S04-BE-001` is `Accepted` and `Delivered`; its result is present on `origin/main` |
| Delivery | `Implementation + GitHub delivery` |
| Implementation gate | Stage 4 decomposition/task index is approved, dependency is accepted/delivered, and local `main` is clean and synchronized with `origin/main` before Codex starts |
| Block checkpoint | Stage 4 Backend Phase 2 Review after all approved Stage 4 backend tasks through `S04-BE-004` are `Accepted` and `Delivered` |

## 1. Implementation Authority and Gate

This file is the complete implementation contract for `S04-BE-002`.

Codex must read only:

1. this task;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. existing backend code and tests directly required by this task.

Do not read product specifications, roadmap/API/architecture documents, previous tasks, Stage history, task indexes, or closure reviews to determine what to implement.

Before Codex starts, ChatGPT/orchestration must:

- confirm the Stage 4 decomposition/task index is approved;
- confirm `S04-BE-001` is `Accepted` and `Delivered` and its result is present on `origin/main`;
- provide the exact current `origin/main` commit to use as the baseline.

Codex performs the normal Stage 4 Git preflight from the approved workflow: verify local `main` is clean, fetch and confirm local `main == origin/main`, verify the expected remote, and create one focused task branch from that synchronized `main`.

Codex validates repository state only from the provided dependency/baseline facts and the current worktree. It must not inspect Stage history or closure evidence to rediscover those decisions.

## 2. Goal

Implement the Institution Admin Group-management HTTP/API boundary for listing, creating, viewing, updating, and archiving same-Institution Groups.

The implementation must use the persistence foundation already present from `S04-BE-001`, keep controllers thin, derive tenancy from the authenticated actor, provide strict deterministic contracts, preserve no-op timestamps, and serialize Update/Archive races safely.

## 3. Endpoints

All routes belong inside the existing Institution Admin route group and its existing authentication/account/password/role middleware:

```text
GET   /api/v1/institution/groups
POST  /api/v1/institution/groups
GET   /api/v1/institution/groups/{group}
PATCH /api/v1/institution/groups/{group}
POST  /api/v1/institution/groups/{group}/archive
```

Do not use implicit route-model binding for `{group}`. Pass the path string to a tenant-scoped Action so cross-Institution existence is never disclosed.

## 4. Public Group Resource

Every single Group response uses this exact `data` shape and key set:

```json
{
  "data": {
    "id": "8c6f0a5c-70b8-4f6b-9a62-1a0d725786c1",
    "name": "10-A",
    "level": "Grade 10",
    "subject_direction": "General",
    "description": null,
    "status": "active",
    "teachers_count": 2,
    "students_count": 25,
    "archived_at": null,
    "created_at": "2026-08-19T10:00:00Z",
    "updated_at": "2026-08-19T10:00:00Z"
  }
}
```

Rules:

- `teachers_count` and `students_count` count relationship rows where `ended_at is null`.
- Counts include a current relationship even when its related User account is inactive; account activity is a separate access condition.
- Archive does not end or delete membership rows.
- Counts are JSON integers.
- Timestamps are RFC 3339 UTC at whole-second precision; nullable timestamps use JSON `null`.
- Do not expose `institution_id`, `created_by_user_id`, membership identifiers, credentials, or other internal columns.
- The Resource must serialize already-loaded fields/counts and must not issue queries.

Mutation responses add exactly one top-level `message` beside `data`.

## 5. Group List

### Request

```text
GET /api/v1/institution/groups
```

Accepted query keys:

```text
search
status
page
per_page
sort
direction
```

Defaults and validation:

| Parameter | Contract |
|---|---|
| `search` | Optional nullable string, trim before validation, max 254; empty after trim means no search |
| `status` | Optional exact `active` or `archived`; omitted means both |
| `page` | Integer, minimum 1, default 1 |
| `per_page` | Integer 1–100, default 20 |
| `sort` | `name`, `status`, `created_at`, or `updated_at`; default `name` |
| `direction` | `asc` or `desc`; default `asc` |

Unknown query keys and any non-empty body return `422 validation_failed`.

### Query behavior

- Start from `institution_id = authenticated actor institution_id` before search/filter/sort/pagination/counts.
- Search `name`, `level`, and `subject_direction` using literal case-insensitive PostgreSQL `ILIKE` matching.
- Escape `!`, `%`, and `_` so user input cannot introduce wildcard semantics; use explicit `ESCAPE '!'`.
- `name` sorting is case-insensitive with `lower(name)`.
- Other allowed sorts use their stored values.
- Always add `id` as deterministic final tiebreaker using the requested direction.
- Select only resource fields and add current Teacher/Student counts with bounded SQL subqueries/aggregates.
- Query count must remain constant as the number of returned Groups increases; no per-row relationship queries.

### Response

Status `200`:

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

The same exact Group key set from Section 4 is used for each collection item.

## 6. Create Group

### Request

```text
POST /api/v1/institution/groups
Content-Type: application/json
```

Accepted JSON keys and validation:

| Field | Contract |
|---|---|
| `name` | Required non-null string; trim; length 1–160 |
| `level` | Optional; JSON null or string; trim strings; non-empty when a string; max 100 |
| `subject_direction` | Optional; JSON null or string; trim strings; non-empty when a string; max 160 |
| `description` | Optional; JSON null or string; trim strings; non-empty when a string |

Additional rules:

- The body must be one JSON object; arrays, scalars, malformed JSON, missing body, and wrong content type return `422`.
- Query parameters are forbidden.
- Unknown/protected keys—including `id`, `institution_id`, `status`, `created_by_user_id`, `archived_at`, and timestamps—return `422`.
- Do not silently convert an empty optional string to `null`; reject it.
- Derive `institution_id` and `created_by_user_id` from the authenticated Institution Admin.
- Set `status = active` and `archived_at = null`.
- Duplicate Group names are valid.

### Response

Status `201`, exact Group resource plus:

```json
{
  "message": "Group created successfully."
}
```

Created counts are both zero.

## 7. Group Detail

```text
GET /api/v1/institution/groups/{group}
```

- No query parameters or request body are allowed.
- Resolve by valid UUID and authenticated Institution before returning any data.
- Invalid UUID, nonexistent UUID, and another Institution's UUID return the same `404 resource_not_found` envelope.
- Active and archived Groups are readable.
- Return `200` with the exact Section 4 resource.

## 8. Update Group

### Request

```text
PATCH /api/v1/institution/groups/{group}
Content-Type: application/json
```

Accepted keys are exactly:

```text
name
level
subject_direction
description
```

Use the same normalization/type/length rules as Create, except:

- at least one accepted key must be present;
- `name`, when present, cannot be null;
- JSON null clears an optional field;
- omitted fields remain unchanged;
- all query parameters and unknown/protected keys are rejected with `422`.

The PATCH body must be one non-empty `application/json` object. Missing body, wrong content type, malformed JSON, scalar root, array root, or an object without an accepted key returns `422 validation_failed` with no mutation.

### State, no-op, and concurrency

- Resolve and lock the Group by actor Institution inside a database transaction.
- Make the lifecycle and change decision from the fresh locked row.
- If the locked Group is archived, return `409 business_conflict` before comparing attributes, even when the requested values equal current values.
- Compare normalized accepted attributes to current persisted values.
- For an exact no-op, do not issue an SQL `UPDATE`; preserve `updated_at` and return the current resource.
- Otherwise update only supplied accepted fields.
- Reload current counts without introducing Resource queries.

### Response

Status `200`, exact Group resource plus:

```json
{
  "message": "Group updated successfully."
}
```

## 9. Archive Group

### Request

```text
POST /api/v1/institution/groups/{group}/archive
```

- Accept no body or an empty application/json object `{}`.
- Reject any body key, malformed/non-object non-empty body, or query parameter with `422`.
- Resolve and lock by actor Institution inside a transaction.

### Lifecycle

The only Stage 4 lifecycle transition is:

```text
active -> archived
```

- There is no reactivate endpoint or automatic reactivation.
- First archive sets `status = archived` and `archived_at = now()` in one write.
- Do not end/delete Teacher or Student membership rows.
- Repeated archive is an idempotent no-op: return `200`, do not issue an SQL `UPDATE`, and preserve `archived_at` and `updated_at`.
- If Archive locks first in an Archive/Update race, Archive commits the transition and the later Update reads the archived row and returns `409 business_conflict` without mutation.
- If Update locks first, Update applies and commits; Archive then reads the updated row and archives it. The final row retains the committed metadata change and has `status = archived` with `archived_at` set.
- For two concurrent Archive requests, the first lock holder performs the transition. The second then reads the archived row and returns the same archived state as an idempotent no-op without another `UPDATE`.

### Response

Status `200`, exact Group resource plus:

```json
{
  "message": "Group archived successfully."
}
```

## 10. Error Contract

Use the existing API error envelope for authentication, authorization, validation, scoped not-found, rate-limit, and server errors.

Add one focused exception/error mapping using the existing locked conflict code:

```text
Exception: GroupArchivedException
HTTP: 409 Conflict
code: business_conflict
message: The group is archived.
errors: {}
```

Register it through the existing centralized API error response boundary. Do not add a new stable error code, update product/API contract documentation, branch on messages, expose SQL/internal classes, or create endpoint-local error envelopes.

## 11. Required Architecture

Use these focused boundaries, following existing namespaces and conventions:

- `InstitutionGroupController` with thin `index`, `store`, `show`, `update`, and `archive` methods.
- Form Requests:
  - `InstitutionGroupIndexRequest`
  - `InstitutionGroupCreateRequest`
  - `InstitutionGroupShowRequest`
  - `InstitutionGroupUpdateRequest`
  - `InstitutionGroupArchiveRequest`
- Actions:
  - `ListInstitutionGroups`
  - `CreateInstitutionGroup`
  - `ShowInstitutionGroup`
  - `UpdateInstitutionGroup`
  - `ArchiveInstitutionGroup`
- `InstitutionGroupResource` and `InstitutionGroupCollection`.
- `GroupArchivedException` plus the minimal centralized mapping needed for Section 10.

Controllers must not own validation, tenant queries, sorting, transactions, locks, lifecycle decisions, or persistence. Requests must not query persisted state. Resources must not query or decide authorization/lifecycle behavior.

## 12. Explicit Non-Goals

Do not implement or change:

- Group reactivation or deletion;
- Teacher/Student membership list, assignment, or removal endpoints;
- Parent–Student relationships;
- Teacher/Student/Parent role-specific Group endpoints;
- Topics, learning delivery, reports, or progress;
- frontend code;
- persistence schema from `S04-BE-001`, except a strictly necessary correction reported as a contract conflict rather than silently expanded;
- dependency packages, lockfiles, documentation, instruction files, or task/Stage bookkeeping outside the delivery evidence explicitly allowed by this contract.

## 13. Required Focused Tests

Add exactly:

- `tests/Feature/Institution/InstitutionGroupReadApiTest.php`
- `tests/Feature/Institution/InstitutionGroupCreateUpdateApiTest.php`
- `tests/Feature/Institution/InstitutionGroupLifecycleApiTest.php`

Required coverage:

- exact routes, methods, resource/collection key sets, messages, UTC timestamps, integer counts, and protected-field absence;
- list default/explicit pagination, allowed filters/sorts, deterministic ties, literal search escaping, empty results, strict query/body rejection, and bounded query count;
- create validation, trimming, nullable optionals, empty-string rejection, derived ownership/creator, active defaults, duplicate names, and atomic persistence;
- detail active/archived reads and indistinguishable invalid/nonexistent/cross-tenant `404`;
- update strict partial input, optional clearing, protected keys, archived conflict, real change, exact no-op with no UPDATE and unchanged timestamp;
- first/repeated archive, frozen timestamps, no membership mutation, no-op with no UPDATE, and archived/update serialization behavior;
- unauthenticated, wrong role, inactive account/institution, and mandatory-password gate behavior;
- both Archive/Update lock orders and two concurrent Archive requests with the exact final states from Section 9;
- exact `409 business_conflict` envelope and centralized `GroupArchivedException` mapping;
- the existing `ApiErrorContractTest` remains green after adding that mapping.

Use deterministic time control and query inspection; do not use sleeps or external networks.

## 14. Proportional Verification

Run from `backend/`:

```bash
./vendor/bin/pint --test

php artisan test \
  tests/Feature/Institution/InstitutionGroupReadApiTest.php \
  tests/Feature/Institution/InstitutionGroupCreateUpdateApiTest.php \
  tests/Feature/Institution/InstitutionGroupLifecycleApiTest.php

php artisan test tests/Feature/ApiErrorContractTest.php
```

Then run from the repository root:

```bash
git diff --check
git status --short
```

Inspect the complete task diff and perform the focused scope, layering, API, tenant, lifecycle, concurrency, query, and security self-review required by the applicable `AGENTS.md` files.

Do not run the full backend suite in this task. It belongs to the Stage 4 Backend Checkpoint.

## 15. Acceptance Criteria

The task is implementation-complete when:

- all five endpoints match this contract;
- every query/mutation derives Institution scope from the authenticated actor;
- Group resources expose exactly the approved fields and current counts without N+1;
- create/update/archive validation and lifecycle/no-op semantics are deterministic;
- Update/Archive uses fresh tenant-scoped row locks and cannot update an already archived Group;
- cross-tenant and invalid identifiers remain existence-private;
- archived Update uses the existing `business_conflict` code and is mapped centrally and exactly;
- required focused verification passes;
- GitHub delivery completes and the accepted result is present on `origin/main`;
- local `main == origin/main`, ahead/behind is `0/0`, and the worktree is clean after delivery;
- no membership-management, parent relationship, frontend, later-stage, dependency, documentation, or unrelated change is present.

Task-level `Accepted` occurs after this contract is satisfied, required focused verification passes, GitHub delivery completes, the accepted result is present on `origin/main`, local `main == origin/main`, ahead/behind is `0/0`, and the worktree is clean.

This task-level acceptance does **not** mean the complete Stage 4 backend block has passed Phase 2. The Backend Phase 2 checkpoint runs only after all approved Stage 4 backend tasks are `Accepted` and `Delivered`; any checkpoint finding is handled by a focused fix contract and checkpoint re-verification.

## 16. Stop Conditions

Stop and report if:

- the Stage 4 decomposition/task index is not approved;
- `S04-BE-001` is not `Accepted` and `Delivered` on `origin/main`;
- the provided `origin/main` baseline commit does not match the synchronized local `main`;
- the required `S04-BE-001` Group persistence/model surface is absent or materially conflicts with this contract;
- implementation would require changing the public fields, lifecycle, tenant policy, or endpoint set defined here;
- existing unrelated work overlaps this task and cannot be safely preserved;
- PostgreSQL or required test tooling is unavailable;
- a required focused check fails and cannot be corrected within this scope.

## 17. Completion Report

Return a concise report with:

- implementation summary;
- changed files and purpose;
- endpoints and error mapping added;
- exact verification commands/results;
- confirmation that non-goals remained excluded;
- deviations, pre-existing failures, or blockers;
- current Git status;
- delivery evidence: task branch, commit, PR, merge result, final `origin/main` SHA, local/main synchronization, ahead/behind `0/0`, and clean worktree.

## 18. GitHub Delivery and Task Acceptance

After implementation, focused verification, `git diff --check`, and the focused scope/diff self-review pass:

1. stage only task-owned files;
2. review the staged diff and perform the required secret/safety checks;
3. create one focused task commit;
4. push the task branch;
5. open a Pull Request to `main`;
6. merge only when required checks pass and merge is permitted;
7. fetch and resynchronize local `main`;
8. verify local `main == origin/main`;
9. verify ahead/behind is `0/0`;
10. verify the worktree is clean.

If implementation and required verification pass but safe delivery cannot complete, report `DELIVERY BLOCKED`.

The task may report `ACCEPTED` only after the delivered result is present on `origin/main` and the final synchronization checks pass.

Do not modify task/Stage bookkeeping or begin `S04-BE-003` as part of this task.
