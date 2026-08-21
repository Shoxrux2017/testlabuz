# S04-BE-003 — Teacher and Student Group Membership API

## Task Metadata

| Field | Value |
|---|---|
| Task ID | `S04-BE-003` |
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | Backend |
| Status | `Accepted` |
| Direct dependencies | `S04-BE-001` and `S04-BE-002` are `Accepted` and `Delivered`; both results are present on `origin/main` |
| Delivery | `Implementation + GitHub delivery` |
| Implementation gate | Stage 4 decomposition/task index is approved, dependencies are accepted/delivered, and local `main` is clean and synchronized with `origin/main` before Codex starts |
| Block checkpoint | Stage 4 Backend Phase 2 Review after all approved Stage 4 backend tasks through `S04-BE-004` are `Accepted` and `Delivered` |

## 1. Implementation Authority and Gate

This file is the complete implementation contract for `S04-BE-003`.

Codex must read only:

1. this task;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. existing backend code and tests directly required by this task.

Do not read product specifications, roadmap/API/architecture documents, previous tasks, Stage history, task indexes, or closure reviews to determine what to implement.

Before Codex starts, ChatGPT/orchestration must:

- confirm the Stage 4 decomposition/task index is approved;
- confirm `S04-BE-001` and `S04-BE-002` are `Accepted` and `Delivered` on `origin/main`;
- provide the exact current `origin/main` commit to use as the baseline.

Codex performs the normal Stage 4 Git preflight: verify local `main` is clean, fetch and confirm local `main == origin/main`, verify the expected remote, and create one focused task branch from that synchronized `main`.

Codex validates repository state only from the provided dependency/baseline facts and the current worktree. It must not inspect Stage history or dependency evidence to rediscover those decisions.

## 2. Goal

Implement the Institution Admin API for listing, bulk-assigning, and removing current Teacher and Student memberships for a same-Institution Group.

The public POST contract must match the locked Stage 4 API shape: Teacher assignment accepts `teacher_ids` and Student assignment accepts `student_ids`, each as an array of User UUIDs. The API must preserve historical membership rows, derive tenant and assigning actor fields from authentication, expose deterministic current-member lists, make bulk assignment atomic and idempotent, keep Resources query-free, and serialize membership, Group archive, User lifecycle, and overlapping-request races through PostgreSQL row locks.

## 3. Endpoints

All routes belong inside the existing Institution Admin route group and its existing authentication/account/password/role middleware:

```text
GET    /api/v1/institution/groups/{group}/teachers
POST   /api/v1/institution/groups/{group}/teachers
DELETE /api/v1/institution/groups/{group}/teachers/{teacher}

GET    /api/v1/institution/groups/{group}/students
POST   /api/v1/institution/groups/{group}/students
DELETE /api/v1/institution/groups/{group}/students/{student}
```

Do not use implicit route-model binding for `{group}`, `{teacher}`, or `{student}`. Pass path strings into tenant-scoped Actions.

The two POST endpoints are bulk-additive assignment endpoints. They add any requested Users that are not currently assigned and leave already-current requested memberships unchanged. They do not replace the complete Group membership set and do not remove Users omitted from the request.

## 4. Current Membership Resource

Teacher and Student collection items and each item returned by successful bulk Assign responses use this exact item shape:

```json
{
  "id": "f08d47e5-7a8c-4f5f-9367-5764df74ed33",
  "full_name": "John Smith",
  "login_name": "john.smith",
  "email": "john@example.com",
  "phone": "+998901234567",
  "is_active": true,
  "started_at": "2026-08-19T10:00:00Z"
}
```

Rules:

- `id` is the Teacher or Student User UUID, not the membership-row UUID.
- `email` and `phone` remain nullable JSON strings according to the User record.
- `is_active` is a JSON boolean.
- `started_at` is the membership start in RFC 3339 UTC at whole-second precision.
- The endpoint fixes the role, so do not add a redundant `role` field.
- Do not expose `institution_id`, membership ID, `group_id`, `assigned_by_user_id`, `ended_at`, credentials, password state, login history, or internal timestamps.
- The Resource must use an already-loaded Teacher or Student and must not issue queries.

Teacher and Student Resources have the same public keys but remain separate focused Resource classes so neither one conditionally guesses the membership type.

## 5. Teacher and Student Lists

### Requests

```text
GET /api/v1/institution/groups/{group}/teachers
GET /api/v1/institution/groups/{group}/students
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
| `search` | Optional nullable string; trim before validation; max 254; empty after trim means no search |
| `status` | Optional exact `active` or `inactive`; omitted means both |
| `page` | Integer, minimum 1, default 1 |
| `per_page` | Integer 1–100, default 20 |
| `sort` | Exact `full_name` or `started_at`; default `full_name` |
| `direction` | Exact `asc` or `desc`; default `asc` |

Unknown query keys and any non-empty request body return `422 validation_failed`.

### Resolution and query behavior

- Resolve `{group}` by valid UUID and authenticated actor Institution before querying memberships.
- Invalid UUID, nonexistent Group, and another Institution's Group return the same `404 resource_not_found` envelope.
- Active and archived Groups are readable.
- Return only the endpoint's membership type where `ended_at is null`.
- Include current members regardless of User activity unless the optional `status` filter is supplied.
- Search `full_name`, `login_name`, `email`, and `phone` using literal case-insensitive PostgreSQL `ILIKE` matching.
- Escape `!`, `%`, and `_` and use explicit `ESCAPE '!'` so input cannot introduce wildcard semantics.
- `full_name` sorting is case-insensitive with `lower(full_name)`.
- `started_at` sorting uses the membership timestamp.
- Always add User `id` as the deterministic final tiebreaker using the requested direction.
- Scope by actor Institution and Group before search, status, sorting, pagination, or relation loading.
- Load only the exact membership and User columns required by Section 4.
- Query count must remain constant as the number of returned members increases; no per-row User queries.

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

The corresponding current membership key set from Section 4 is used for every item.

## 6. Bulk Assign Teachers or Students

### Requests

```text
POST /api/v1/institution/groups/{group}/teachers
Content-Type: application/json

POST /api/v1/institution/groups/{group}/students
Content-Type: application/json
```

Teacher request body:

```json
{
  "teacher_ids": [
    "f08d47e5-7a8c-4f5f-9367-5764df74ed33",
    "509f7191-7aac-4638-a252-2d5d0bb1a751"
  ]
}
```

Student request body:

```json
{
  "student_ids": [
    "f08d47e5-7a8c-4f5f-9367-5764df74ed33",
    "509f7191-7aac-4638-a252-2d5d0bb1a751"
  ]
}
```

### Strict request contract

Each body must be exactly one non-empty JSON object with exactly one endpoint-specific key:

```text
teachers endpoint -> teacher_ids
students endpoint -> student_ids
```

Validation:

- the endpoint-specific field is required, non-null, and an array;
- the array must contain at least one item and at most 100 items;
- every item must be a non-null valid UUID string;
- duplicate UUIDs inside one request are rejected with `422 validation_failed`; do not silently deduplicate;
- query parameters and unknown/protected body keys return `422 validation_failed`;
- missing body, wrong content type, malformed JSON, scalar root, or array root returns `422 validation_failed` without mutation;
- `teacher_ids` is invalid on the Student endpoint and `student_ids` is invalid on the Teacher endpoint.

### Target resolution and atomicity

The entire batch is one atomic operation. Either all requested targets are valid and the operation succeeds, or no membership row is created/changed.

Inside one database transaction use this lock and decision order:

1. resolve and `FOR UPDATE` lock the Group by authenticated actor Institution;
2. reject an archived Group with the existing `GroupArchivedException` mapping;
3. normalize the requested UUID list only for deterministic internal processing; the response must preserve request order;
4. resolve **all** target Users by authenticated actor Institution and exact endpoint role;
5. require the resolved User count to equal the requested ID count; otherwise throw the privacy-safe scoped `404 resource_not_found` before any membership write;
6. `FOR UPDATE` lock the target User rows in ascending UUID order;
7. query and `FOR UPDATE` lock any current memberships for the exact Group/requested User set in ascending target-User UUID order;
8. for each requested target:
   - if a current membership exists, treat that target as an idempotent no-op even when that already-assigned User is now inactive;
   - if no current membership exists and the target User is inactive, throw `InactiveGroupMemberException`, rolling back the whole batch;
   - otherwise create one new current membership row;
9. return the requested Users' current memberships in the same order as the request array.

Invalid, nonexistent, cross-Institution, Institution Admin, Parent, or otherwise wrong-role target IDs are deliberately indistinguishable and return the same `404 resource_not_found` envelope for the whole batch.

For every newly created row:

- derive `institution_id` and `assigned_by_user_id` from the authenticated Institution Admin;
- use the locked Group and target User IDs;
- set `started_at = now()` and `ended_at = null`;
- let normal model timestamps be written once;
- do not revive or modify historical ended rows.

A Teacher or Student may hold current memberships in multiple different Groups.

The partial unique current-membership index remains the database backstop. The Group lock, deterministic User lock order, and current-membership decision path must keep normal duplicate-current races from surfacing as database errors.

### Idempotency and mixed batches

- If every requested target is already current, the whole request is a write-free idempotent no-op.
- If some targets are already current and others are eligible new assignments, create only the missing memberships; do not touch existing current rows.
- If any missing target is inactive, no new membership from that request may persist.
- Existing current membership timestamps (`started_at`, `created_at`, `updated_at`) must remain unchanged for idempotent targets.

### Responses

If at least one membership row is newly created, return `201 Created`.

If all requested memberships were already current, return `200 OK`.

Teacher response:

```json
{
  "data": [
    {
      "id": "f08d47e5-7a8c-4f5f-9367-5764df74ed33",
      "full_name": "John Smith",
      "login_name": "john.smith",
      "email": "john@example.com",
      "phone": "+998901234567",
      "is_active": true,
      "started_at": "2026-08-19T10:00:00Z"
    }
  ],
  "message": "Teachers assigned to group successfully."
}
```

Student response uses the same item key set and:

```json
{
  "message": "Students assigned to group successfully."
}
```

Rules:

- `data` is always an array containing exactly one item per requested UUID;
- item order matches request order;
- already-current requested memberships are included;
- Resources must serialize already-loaded Users/membership timestamps and issue no queries.

The application layer must return one explicit `GroupMembershipAssignmentResult` containing the ordered current-membership result list and the number of newly created memberships, so Controllers choose `201` versus `200` without inferring persistence behavior.

## 7. Remove Teacher or Student

### Requests

```text
DELETE /api/v1/institution/groups/{group}/teachers/{teacher}
DELETE /api/v1/institution/groups/{group}/students/{student}
```

- Query parameters and any request body are forbidden and return `422 validation_failed`.
- Resolve the Group by actor Institution and the path User by actor Institution plus exact endpoint role.
- Invalid, nonexistent, cross-Institution, or wrong-role path identifiers return the same `404 resource_not_found` envelope.
- An inactive correctly-typed User remains removable.

### Transaction and lifecycle

Use the same transaction and lock order as Assign:

1. lock tenant-scoped Group;
2. reject an archived Group;
3. lock tenant- and role-scoped target User;
4. query and lock the exact current membership.

If a current membership exists:

- set `ended_at = now()` once;
- allow the membership `updated_at` to reflect that write;
- do not delete the historical row.

If no current membership exists, perform an idempotent no-op. Do not update any historical row and do not create a row.

First and repeated Remove both return status `204 No Content` with an empty response body.

After removal, a later Assign creates a new historical membership row rather than clearing `ended_at` on the old row.

## 8. Group Counts and User Lifecycle Interaction

- A new current Teacher or Student membership increases the corresponding Group count defined by `S04-BE-002`.
- Ending a current membership decreases that count.
- Idempotent Assign and Remove do not change counts.
- Deactivating a User does not end or delete current memberships; list results and Group counts may therefore include inactive current members.
- If target deactivation locks and commits before a bulk Assign locks that User, and that target has no current membership, the entire bulk Assign returns `409 business_conflict` and creates no new memberships.
- If bulk Assign locks/commits first, later User deactivation leaves any newly created membership current.
- Removing an inactive current member remains allowed.

Do not change the existing Institution User lifecycle API in this task.

## 9. Concurrency Contract

All membership mutation endpoints use a shared deterministic lock discipline.

### Lock order

For bulk Assign:

```text
Group row
-> target User rows ordered by users.id ASC
-> current membership rows ordered by target User id ASC
-> writes
```

For single Remove:

```text
Group row
-> target User row
-> current membership row
-> write/no-op
```

Group archive from `S04-BE-002` and every membership mutation serialize through the same Group row. User deactivation and membership assignment serialize through the same target User row.

Required outcomes:

- Two concurrent identical bulk Assign requests for an absent batch: the first Group-lock holder creates all missing rows and receives `201`; the second receives `200`, returns the same current memberships, and performs no membership write.
- Two overlapping bulk Assign requests: Group locking serializes them; each request creates only memberships still missing when it obtains the lock, and no duplicate current row is produced.
- Two concurrent Remove requests for one current pair: the first ends the row; the second returns `204` as a no-op. Exactly one end write occurs.
- Bulk Assign locks first, then Remove for one requested User: Assign completes, Remove then ends that User's current row; unrelated requested memberships remain current.
- Remove locks first, then bulk Assign containing that User: Remove ends the existing row or no-ops, then Assign creates a new current row for that User if eligible; final state has exactly one current membership for that pair.
- Membership mutation locks first, then Archive: the membership mutation commits, Archive then archives the Group; committed membership state is retained.
- Archive locks first, then membership mutation: Archive commits; the later Assign or Remove reads the archived Group and returns `409 business_conflict` without membership mutation.
- Target User deactivation commits before bulk Assign locks that User: if the target lacks a current membership, bulk Assign returns `409 business_conflict` and the entire batch rolls back.
- Bulk Assign locks the target User first and commits: later deactivation does not end the new membership.
- Two bulk Assign requests for different Groups but overlapping Users must lock target Users in ascending UUID order so overlapping User sets cannot deadlock through inconsistent User ordering.

Tests must coordinate independent PostgreSQL connections with deterministic barriers or equivalent transaction control. Do not use timing sleeps as concurrency proof.

## 10. Error Contract

Use the existing centralized API error envelope.

Reuse the existing archived Group mapping:

```text
Exception: GroupArchivedException
HTTP: 409 Conflict
code: business_conflict
message: The group is archived.
errors: {}
```

Add this exact focused mapping:

```text
Exception: InactiveGroupMemberException
HTTP: 409 Conflict
code: business_conflict
message: The selected user is inactive.
errors: {}
```

Register the new exception through the existing centralized API error boundary. Do not add a new stable error code, change product/API contract documentation, branch on exception messages, expose SQL/internal classes, or create endpoint-local error envelopes.

Bulk validation/state failure rules:

- malformed array shape, duplicate IDs, or invalid UUID syntax -> `422 validation_failed`;
- any syntactically valid target UUID that cannot be resolved as same-Institution endpoint-role User -> `404 resource_not_found` for the whole batch;
- any missing-membership target that is inactive -> `409 business_conflict` through `InactiveGroupMemberException` for the whole batch;
- archived Group -> `409 business_conflict` through `GroupArchivedException`;
- all bulk failures occur before commit and must leave the membership set unchanged.

## 11. Required Architecture

Use these focused boundaries, following existing namespaces and conventions:

- Controllers:
  - `InstitutionGroupTeacherMembershipController` with `index`, `store`, and `destroy`;
  - `InstitutionGroupStudentMembershipController` with `index`, `store`, and `destroy`.
- Form Requests:
  - `InstitutionGroupTeacherMembershipIndexRequest`;
  - `InstitutionGroupTeacherMembershipAssignRequest`;
  - `InstitutionGroupTeacherMembershipRemoveRequest`;
  - `InstitutionGroupStudentMembershipIndexRequest`;
  - `InstitutionGroupStudentMembershipAssignRequest`;
  - `InstitutionGroupStudentMembershipRemoveRequest`.
- Actions:
  - `ListInstitutionGroupTeachers`;
  - `AssignTeacherToInstitutionGroup`;
  - `RemoveTeacherFromInstitutionGroup`;
  - `ListInstitutionGroupStudents`;
  - `AssignStudentToInstitutionGroup`;
  - `RemoveStudentFromInstitutionGroup`.
- Resources:
  - `InstitutionGroupTeacherMembershipResource` and `InstitutionGroupTeacherMembershipCollection`;
  - `InstitutionGroupStudentMembershipResource` and `InstitutionGroupStudentMembershipCollection`.
- One explicit `GroupMembershipAssignmentResult` application result carrying the ordered current-membership result list plus `created_count`, so the Controller can select `201` when `created_count > 0` or `200` when `created_count = 0` without inferring persistence behavior.
- `InactiveGroupMemberException` and its minimal centralized mapping.

Controllers must not own validation, tenant/role queries, filtering, sorting, transactions, locks, lifecycle decisions, or persistence. Requests must not query persisted state. Resources must not query, authorize, or decide lifecycle behavior.

Do not add generic repository/service layers, generic polymorphic membership abstractions, or `BelongsToMany` shortcuts that hide historical rows.

## 12. Explicit Non-Goals

Do not implement or change:

- bulk removal or replace-all membership semantics;
- membership-history endpoints;
- candidate-selection endpoints or changes to the existing Institution User list API;
- Parent–Student connections;
- Group create/update/archive behavior;
- User role or lifecycle mutation behavior;
- Teacher/Student role-specific self-service APIs;
- Group reactivation/deletion;
- topics, learning delivery, reports, or progress;
- frontend code;
- persistence schema or model relationships from `S04-BE-001`;
- dependency packages, lockfiles, documentation, instruction files, or task/Stage bookkeeping outside the delivery evidence explicitly allowed by this contract.

## 13. Required Focused Tests

Add exactly:

- `tests/Feature/Institution/InstitutionGroupTeacherMembershipApiTest.php`
- `tests/Feature/Institution/InstitutionGroupStudentMembershipApiTest.php`
- `tests/Feature/Institution/InstitutionGroupMembershipConcurrencyTest.php`

Required coverage:

- exact routes, methods, strict request contracts, response status, messages, key sets, nullable contact fields, booleans, UTC timestamps, and protected-field absence;
- Teacher and Student list defaults, filters, literal search escaping, allowed sorts, deterministic ties, pagination, empty results, current-only rows, archived Group reads, and bounded query count;
- indistinguishable invalid/nonexistent/cross-tenant Group and target identifiers and wrong-role targets;
- bulk Teacher `teacher_ids` and Student `student_ids` request shapes, 1..100 bounds, UUID validation, duplicate-ID rejection, and rejection of the opposite endpoint key;
- first bulk Assign ownership/actor derivation, endpoint-role correctness, active-user requirement for missing memberships, multiple-Group membership, historical re-assignment, request-order response, and exact `201` response;
- mixed current/new bulk Assign creates only missing memberships and preserves existing membership timestamps;
- all-current bulk Assign returns exact `200` as a write-free no-op, including already-current Users later made inactive;
- atomic rollback when any target is invalid/wrong-role/cross-tenant/inactive-without-current; no partial membership creation;
- first and repeated Remove exact `204`, inactive-user removal, one `ended_at` write, no physical deletion, no historical-row rewrite, and subsequent new-row re-assignment;
- archived Group mutation conflict before any membership write;
- unauthenticated, wrong role, inactive actor/institution, and mandatory-password gate behavior;
- exact `InactiveGroupMemberException` and `GroupArchivedException` `409 business_conflict` envelopes;
- all concurrency outcomes from Section 9, including identical/overlapping bulk Assign, mixed Assign/Remove, Archive/membership, User-deactivation/Assign, and cross-Group overlapping-User lock ordering, with exact final row/current-membership counts;
- Group `teachers_count` and `students_count` changes only for real current-membership transitions;
- the existing `ApiErrorContractTest` remains green after adding the exception mapping.

Use deterministic time control, SQL/query inspection, and independent PostgreSQL connections for concurrency coverage. Do not use sleeps or external networks.

## 14. Proportional Verification

Run from `backend/`:

```bash
./vendor/bin/pint --test

php artisan test \
  tests/Feature/Institution/InstitutionGroupTeacherMembershipApiTest.php \
  tests/Feature/Institution/InstitutionGroupStudentMembershipApiTest.php \
  tests/Feature/Institution/InstitutionGroupMembershipConcurrencyTest.php

php artisan test \
  tests/Feature/Institution/InstitutionGroupReadApiTest.php \
  tests/Feature/ApiErrorContractTest.php
```

Then run from the repository root:

```bash
git diff --check
git status --short
```

Inspect the complete task diff and perform the focused scope, layering, API, tenant, role, lifecycle, concurrency, query, and security self-review required by the applicable `AGENTS.md` files.

Do not run the full backend suite in this task. It belongs to the Stage 4 Backend Checkpoint.

## 15. Acceptance Criteria

The task is implementation-complete when:

- all six endpoints match this contract;
- current membership lists are tenant-safe, role-correct, deterministic, paginated, and free of N+1 behavior;
- bulk Assign uses the locked `teacher_ids` / `student_ids` public request shapes, is atomic, preserves request order in the response, creates at most one current relationship per Group/User pair, creates only missing eligible memberships, and is a write-free idempotent no-op when all requested memberships are already current;
- Remove ends rather than deletes a current row and is a write-free idempotent no-op when already absent;
- re-assignment creates a new historical row;
- archived Groups remain readable but reject membership mutations through the existing conflict code;
- inactive Users remain visible/removable while new inactive assignments are rejected exactly as specified;
- every mutation derives Institution and assigning actor fields from authentication;
- duplicate/overlapping bulk Assign, mixed Assign/Remove, Archive/membership, and User lifecycle races produce the exact defined outcomes without deadlock-prone inconsistent User lock ordering;
- Group current-member counts remain correct;
- required focused verification passes;
- GitHub delivery completes and the accepted result is present on `origin/main`;
- local `main == origin/main`, ahead/behind is `0/0`, and the worktree is clean after delivery;
- no bulk removal/replace-all, history, candidate, Parent–Student, frontend, later-stage, dependency, documentation, or unrelated change is present.

Task-level `Accepted` occurs after this contract is satisfied, required focused verification passes, GitHub delivery completes, the accepted result is present on `origin/main`, local `main == origin/main`, ahead/behind is `0/0`, and the worktree is clean.

This task-level acceptance does **not** mean the complete Stage 4 backend block has passed Phase 2. The Backend Phase 2 checkpoint runs only after all approved Stage 4 backend tasks are `Accepted` and `Delivered`; any checkpoint finding is handled by a focused fix contract and checkpoint re-verification.

## 16. Stop Conditions

Stop and report if:

- the Stage 4 decomposition/task index is not approved;
- `S04-BE-001` or `S04-BE-002` is not `Accepted` and `Delivered` on `origin/main`;
- the provided `origin/main` baseline commit does not match the synchronized local `main`;
- the required Group/membership persistence or Group-management API surface is absent or materially conflicts with this contract;
- implementing the exact lifecycle requires a schema change or a new stable API error code;
- the existing User role/lifecycle surface cannot supply deterministic tenant-, role-, and activity-scoped resolution;
- existing unrelated work overlaps this task and cannot be safely preserved;
- PostgreSQL, independent test connections, or required test tooling is unavailable;
- a required focused check fails and cannot be corrected within this scope.

## 17. Completion Report

Return a concise report with:

- implementation summary;
- changed files and purpose;
- endpoints and centralized exception mapping added;
- lifecycle/concurrency outcomes implemented;
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

Do not modify task/Stage bookkeeping or begin `S04-BE-004` as part of this task.

## 19. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to rediscover requirements.

| Source | Decision already encoded in this contract |
|---|---|
| `docs/09-api-contracts.md` §10.2 | Teacher assignment POST uses `teacher_ids` array; targets are same-Institution Teachers and duplicate current membership must not be created |
| `docs/09-api-contracts.md` §10.5 | Student assignment POST uses `student_ids` array; targets are same-Institution Students |
| `docs/05-business-rules.md` Stage 4 relationship rules | Relationships are tenant-scoped and historical membership rows are preserved |
| Stage 4 workflow | One task branch, proportional verification, GitHub delivery, task-level acceptance before block Phase 2 |
