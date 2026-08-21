# S04-BE-004 — Parent–Student Relationship API

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S04-BE-004` |
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | Backend |
| Status | `Accepted` |
| Direct dependency | `S04-BE-003` is `Accepted` and `Delivered`; its result is present on `origin/main` |
| Delivery | `Implementation + GitHub delivery` |
| Implementation gate | Stage 4 decomposition/task index is approved, dependency is accepted/delivered, and local `main` is clean and synchronized with `origin/main` before Codex starts |
| Block checkpoint | Stage 4 Backend Phase 2 Review immediately after this task is `Accepted` and `Delivered` |

Start only when this task is `Approved` and the implementation gate above is satisfied.

This file is the complete task-specific implementation contract. Do not create a duplicate `CODEX-PROMPT` file.

---

## 2. Implementation Authority and Context Discipline

Codex must read only:

1. this task;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. existing backend source, tests, migrations, configuration, and infrastructure directly required by this task.

Do not read product specifications, roadmap/API/architecture/database documents, previous tasks, Stage history, task indexes, closure reviews, or unrelated modules to determine what to implement.

Before Codex starts, ChatGPT/orchestration must:

- confirm the Stage 4 decomposition/task index is approved;
- confirm `S04-BE-003` is `Accepted` and `Delivered` on `origin/main`;
- provide the exact current `origin/main` commit to use as the baseline.

Codex performs normal Stage 4 Git preflight:

- verify local `main` is clean;
- fetch and confirm local `main == origin/main`;
- verify the expected `origin`;
- create one focused task branch from synchronized `main`;
- preserve all pre-existing user work.

If the current repository materially conflicts with this contract, stop and report the exact conflict instead of redesigning behavior.

---

## 3. Goal

Implement the Institution Admin Parent–Student relationship API required by the locked Stage 4 public contract:

```text
GET    /api/v1/institution/parents/{parent}/students
GET    /api/v1/institution/students/{student}/parents
POST   /api/v1/institution/parent-student-relationships
DELETE /api/v1/institution/parent-student-relationships/{relationship}
```

The implementation must:

- use Parent–Student persistence delivered by `S04-BE-001`;
- preserve historical relationship rows through `ended_at`;
- enforce same-Institution Parent and Student roles at the application boundary;
- derive Institution and connecting actor from authentication;
- expose the relationship UUID required by the public API;
- make repeated Connect/Disconnect idempotent;
- preserve existing relationships when a User is later deactivated;
- use deterministic PostgreSQL locking for relationship and User-lifecycle races;
- keep Controllers thin and Resources query-free.

---

## 4. Explicit Non-Goals

Do not implement or change:

- any `/parent-student-connections` route family;
- pair-addressed DELETE routes such as `/{parent}/{student}`;
- relationship history/detail endpoints;
- bulk Connect/Disconnect;
- candidate-selection endpoints;
- Institution User API behavior;
- Group or Teacher/Student membership APIs;
- Parent/Student self-service APIs;
- User role/lifecycle semantics;
- family/guardian type, custody, invitation, approval, primary-parent, or permission metadata;
- Topics, learning delivery, results, reports, or progress;
- frontend code;
- Stage 4 persistence schema/model relationships from `S04-BE-001`;
- packages or lockfiles;
- product documentation or instruction files;
- task/Stage bookkeeping outside explicitly required delivery evidence.

Do not introduce generic graph repositories/services, polymorphic relationship abstractions, soft deletes, or PostgreSQL RLS.

---

## 5. Public Relationship Resource

All successful relationship representations use exactly:

```json
{
  "id": "relationship-uuid",
  "parent_id": "parent-user-uuid",
  "student_id": "student-user-uuid",
  "started_at": "2026-08-19T10:00:00Z",
  "ended_at": null
}
```

Rules:

- `id` is the `parent_student_relationships.id` UUID.
- `parent_id` and `student_id` are User UUIDs.
- `started_at` and non-null `ended_at` are RFC 3339 UTC at whole-second precision.
- Current-list endpoints return only rows with `ended_at = null`, so list item `ended_at` is always JSON `null`.
- Do not expose `institution_id`, `connected_by_user_id`, `created_at`, `updated_at`, User credentials, password state, login history, or other internal fields.
- The Resource serializes already-resolved relationship state and must issue no queries.

Use:

- `InstitutionParentStudentRelationshipResource`;
- one focused paginated collection class if needed by the existing collection pattern.

---

## 6. Current Students for Parent

### Endpoint

```text
GET /api/v1/institution/parents/{parent}/students
```

### Input contract

Accepted query keys:

```text
search
status
page
per_page
sort
direction
```

| Parameter | Contract |
|---|---|
| `search` | Optional nullable string; trim; max 254; blank after trim means no search |
| `status` | Optional `active` or `inactive`; filters the related Student account; omitted means both |
| `page` | Integer >= 1; default 1 |
| `per_page` | Integer 1–100; default 20 |
| `sort` | `full_name` or `started_at`; default `full_name` |
| `direction` | `asc` or `desc`; default `asc` |

Unknown query keys or any non-empty request body return `422 validation_failed`.

### Resolution

- `{parent}` must be a valid UUID.
- Resolve the path User inside `authenticated actor institution_id` with exact `role = parent`.
- Invalid UUID, nonexistent User, cross-Institution User, or wrong-role User return the same `404 resource_not_found`.
- Parent activity does not affect administrative readability.

### Query behavior

Start from:

```text
parent_student_relationships.institution_id = actor.institution_id
parent_student_relationships.parent_id = resolved parent
parent_student_relationships.ended_at is null
```

Then join the related Student only inside the same Institution and with exact `role = student`.

- Include active and inactive Students unless `status` is supplied.
- `search` performs literal case-insensitive PostgreSQL `ILIKE` across Student `full_name`, `login_name`, `email`, and `phone`.
- Escape `!`, `%`, and `_`; use explicit `ESCAPE '!'`.
- `full_name` sorting uses `lower(student.full_name)`.
- `started_at` sorting uses relationship `started_at`.
- Final deterministic tiebreaker is relationship `id` using the requested direction.
- Scope by Institution, Parent, current state, and role before search/filter/sort/pagination.
- Select only columns required for filtering/sorting and the Section 5 resource.
- Query count must remain constant as result size grows; no per-row relationship/User queries.

### Success

`200 OK`:

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

Each item uses exactly the Section 5 relationship resource.

---

## 7. Current Parents for Student

### Endpoint

```text
GET /api/v1/institution/students/{student}/parents
```

Use the same pagination/search/strict-input contract as Section 6, with the roles reversed:

- `{student}` resolves tenant-safely with exact `role = student`;
- current relationships are filtered by `student_id`;
- related Users must be same-Institution `role = parent`;
- `status` filters Parent account activity;
- search operates on Parent `full_name`, `login_name`, `email`, and `phone`;
- `full_name` sorting uses `lower(parent.full_name)`;
- `started_at` sorting uses the relationship timestamp;
- relationship `id` is the deterministic final tiebreaker.

Invalid/nonexistent/cross-tenant/wrong-role path Users return the same `404 resource_not_found`.

Success is `200 OK` with the same Section 5 item resource and pagination envelope.

---

## 8. Connect Parent and Student

### Endpoint

```text
POST /api/v1/institution/parent-student-relationships
Content-Type: application/json
```

### Request

The body must be exactly one non-empty JSON object with exactly:

```json
{
  "parent_id": "parent-user-uuid",
  "student_id": "student-user-uuid"
}
```

Validation:

- both fields required and non-null;
- both are valid UUID strings;
- query parameters are forbidden;
- unknown/protected keys are forbidden;
- missing body, wrong content type, malformed JSON, scalar root, or array root returns `422 validation_failed`;
- no mutation may occur on validation failure.

### Tenant/role resolution

Both targets must resolve inside the authenticated Institution:

```text
parent_id  -> role = parent
student_id -> role = student
```

Invalid, nonexistent, cross-Institution, reversed-role, Institution Admin, Teacher, or otherwise wrong-role target returns the same `404 resource_not_found`.

A Parent may have multiple Students, and a Student may have multiple Parents.

### Transaction and deterministic lock order

The operation is one database transaction.

1. Query the two target UUIDs within the actor Institution.
2. Lock the two User rows with `FOR UPDATE` in ascending User UUID order, independent of Parent/Student role.
3. Require exactly one locked Parent matching `parent_id` and one locked Student matching `student_id`; otherwise throw scoped `404`.
4. Query and `FOR UPDATE` lock the current exact Parent/Student relationship.
5. If a current relationship exists, return it as a write-free idempotent no-op even when either already-connected User is now inactive.
6. If no current relationship exists and either locked User is inactive, throw `InactiveParentStudentRelationshipUserException`.
7. Otherwise create one new relationship.

New-row values:

```text
institution_id       = authenticated actor institution_id
parent_id            = locked Parent id
student_id           = locked Student id
connected_by_user_id = authenticated Institution Admin id
started_at           = now()
ended_at             = null
```

Normal model timestamps are written once.

Never revive or rewrite an ended historical row. A reconnect after a prior disconnect creates a new relationship UUID.

The partial unique current-pair index remains the database backstop. Normal duplicate requests must be resolved by application locking, not surfaced as a raw uniqueness error.

### Success

First creation:

```text
201 Created
```

Repeated current Connect:

```text
200 OK
```

Repeated Connect must perform no INSERT/UPDATE and preserve the existing relationship's `id`, `started_at`, `created_at`, and `updated_at`.

Both return:

```json
{
  "data": {
    "id": "relationship-uuid",
    "parent_id": "parent-user-uuid",
    "student_id": "student-user-uuid",
    "started_at": "2026-08-19T10:00:00Z",
    "ended_at": null
  },
  "message": "Parent and student connected successfully."
}
```

Use an explicit `ParentStudentRelationshipConnectResult` carrying the relationship and `created: bool` so the Controller selects `201` or `200` without inferring persistence behavior.

---

## 9. Disconnect Relationship

### Endpoint

```text
DELETE /api/v1/institution/parent-student-relationships/{relationship}
```

### Strict input

- No query parameters.
- No request body.
- `{relationship}` must be a valid UUID.
- Invalid UUID, nonexistent relationship, or relationship from another Institution return the same `404 resource_not_found`.

### Tenant-safe resolution and lock order

Because Connect locks User rows before the relationship row, Disconnect must use the same order to avoid deadlocks.

1. Before acquiring locks, resolve the relationship by `relationship id + actor institution_id` only far enough to obtain its immutable `parent_id` and `student_id`.
2. Start/continue one transaction and lock those two same-Institution User rows in ascending UUID order.
3. Re-query and `FOR UPDATE` lock the exact relationship by `id + actor institution_id`.
4. If the relationship disappeared or its immutable pair no longer matches the pre-resolved pair, return scoped `404` without mutation.
5. Do not require Parent/Student account activity for disconnect.
6. The persisted relationship's Parent/Student roles must remain the expected roles; a material legacy/data conflict should be reported rather than silently reinterpreted.

### Lifecycle

If `ended_at is null`:

- set `ended_at = now()` once;
- allow `updated_at` to advance once;
- do not delete the row.

If `ended_at` is already non-null:

- return an idempotent no-op;
- perform no UPDATE;
- preserve original `ended_at` and `updated_at`.

Both first and repeated Disconnect return:

```text
204 No Content
```

with an empty body.

A later Connect for the same Parent/Student pair creates a new relationship row and new relationship UUID.

---

## 10. User Lifecycle Interaction

- User deactivation does not end/delete a current Parent–Student relationship.
- Current relationships containing inactive Users remain readable through Sections 6 and 7.
- Repeating Connect for an already-current pair returns `200` as a write-free no-op even if either User is inactive.
- Creating a missing relationship requires both locked Users to be active.
- Disconnect remains allowed when one or both Users are inactive.
- Do not change the existing Institution User lifecycle API.

Concurrency with User deactivation:

- if deactivation locks/commits before Connect locks a User and there is no current relationship, Connect returns `409 business_conflict`;
- if Connect locks/commits first, later deactivation leaves the newly created relationship current.

---

## 11. Concurrency Contract

Every relationship mutation uses deterministic User lock order:

```text
User rows ordered by users.id ASC
-> exact current/target relationship row
-> write/no-op
```

Required outcomes:

- Two concurrent Connect requests for an absent pair: first creates and returns `201`; second returns the same current relationship with `200` and no write.
- Two concurrent Disconnect requests for a current relationship ID: first ends the row; second returns `204` with no second write.
- Connect locks first, then Disconnect of the newly created relationship: Connect commits; Disconnect then ends it; final state has no current pair.
- Disconnect of the current relationship locks first, then Connect for that pair: Disconnect ends it; Connect then creates a new current row; final state has exactly one current pair and two historical relationship rows.
- Concurrent mutations for overlapping pairs sharing a Parent or Student serialize on the shared User with no inconsistent lock order.
- Mutations for disjoint pairs may proceed independently.
- Deactivation/Connect races obey Section 10.
- No raw partial-unique or foreign-key exception may become normal API behavior.

Concurrency tests must use independent PostgreSQL connections and deterministic barriers or equivalent transaction control. Do not use sleeps.

---

## 12. Error Contract

Use the existing centralized API error envelope.

Add exactly:

```text
Exception: InactiveParentStudentRelationshipUserException
HTTP: 409 Conflict
code: business_conflict
message: The selected parent or student is inactive.
errors: {}
```

Register the exception through the existing centralized API error boundary.

Do not add a new stable machine code, branch on human-readable messages, expose SQL/internal class names, or create endpoint-local error envelopes.

Error summary:

| Case | Required result |
|---|---|
| Invalid request shape/query/body | `422 validation_failed` |
| Invalid/nonexistent/cross-tenant/wrong-role path or target | `404 resource_not_found` |
| New connection includes inactive Parent/Student | `409 business_conflict` |
| Repeated current Connect | `200`, no write |
| Repeated Disconnect of already-ended in-scope relationship | `204`, no write |
| Unexpected error | existing safe `500 server_error` |

The existing `ApiErrorContractTest` must remain green.

---

## 13. Required Architecture

Use existing namespaces/conventions and these focused boundaries.

### Controllers

- `InstitutionParentStudentsController` — `index`;
- `InstitutionStudentParentsController` — `index`;
- `InstitutionParentStudentRelationshipController` — `store`, `destroy`.

### Form Requests

- `InstitutionParentStudentsIndexRequest`;
- `InstitutionStudentParentsIndexRequest`;
- `InstitutionParentStudentRelationshipConnectRequest`;
- `InstitutionParentStudentRelationshipDisconnectRequest`.

### Actions

- `ListInstitutionParentStudents`;
- `ListInstitutionStudentParents`;
- `ConnectInstitutionParentStudentRelationship`;
- `DisconnectInstitutionParentStudentRelationship`.

### Resources

- `InstitutionParentStudentRelationshipResource`;
- focused collection class(es) following the existing pagination convention.

### Application/error types

- `ParentStudentRelationshipConnectResult`;
- `InactiveParentStudentRelationshipUserException`.

Controllers must not own:

- validation;
- tenant/role queries;
- filtering/sorting;
- transactions or row locks;
- lifecycle decisions;
- persistence.

Form Requests must not query persisted state.

Resources must not issue queries, authorize access, or decide lifecycle behavior.

Do not add generic repository/service layers or `BelongsToMany` shortcuts that hide historical relationship rows.

---

## 14. Expected Files and Areas

Expected changes are limited to the directly required backend areas:

```text
backend/routes/api.php
backend/app/Http/Controllers/Api/V1/Institution/
backend/app/Http/Requests/Institution/
backend/app/Actions/Institution/
backend/app/Http/Resources/Institution/
backend/app/Exceptions/Institution/        # or existing equivalent exception namespace
backend/app/Support/ApiErrorResponse.php   # only minimal error mapping support if required
backend/bootstrap/app.php                  # only minimal centralized exception registration if required
backend/tests/Feature/Institution/
backend/tests/Feature/ApiErrorContractTest.php  # inspect; modify only if contract registration requires expected coverage
```

Do not change migrations/models delivered by `S04-BE-001` unless a material dependency conflict is found; report that conflict instead of silently expanding scope.

---

## 15. Required Focused Tests

Add exactly:

- `tests/Feature/Institution/InstitutionParentStudentsApiTest.php`
- `tests/Feature/Institution/InstitutionStudentParentsApiTest.php`
- `tests/Feature/Institution/InstitutionParentStudentRelationshipMutationApiTest.php`
- `tests/Feature/Institution/InstitutionParentStudentRelationshipConcurrencyTest.php`

### Read coverage

Verify:

- exact four public routes/methods and absence of `/parent-student-connections`;
- exact Section 5 key set, relationship UUID exposure, UTC timestamps, and protected-field absence;
- Parent→Students and Student→Parents tenant-safe path resolution;
- current-only rows;
- active/inactive related Users;
- search escaping for `!`, `%`, `_`;
- allowed sorts, deterministic ties, pagination, empty results;
- invalid query values and strict body/query rejection;
- bounded query count with no N+1;
- invalid/nonexistent/cross-tenant/wrong-role path identifiers produce indistinguishable `404`.

### Mutation coverage

Verify:

- exact POST body and DELETE-by-relationship-ID route;
- first Connect `201`;
- derived `institution_id` / `connected_by_user_id`;
- exact Parent and Student roles;
- one Parent→many Students and one Student→many Parents;
- repeated current Connect `200` no-op with frozen relationship timestamps;
- new inactive target rejection;
- repeated current Connect remains allowed after later User deactivation;
- first Disconnect `204`, one `ended_at` write, no physical deletion;
- repeated Disconnect by same ended relationship ID `204` no-op with frozen timestamps;
- reconnect creates a new row/new UUID rather than clearing old `ended_at`;
- cross-tenant relationship ID is existence-private;
- unauthenticated, wrong role, inactive actor/institution, and mandatory-password gate behavior;
- exact centralized `InactiveParentStudentRelationshipUserException` mapping.

### Concurrency coverage

Verify all Section 11 outcomes using deterministic independent PostgreSQL connections:

- duplicate Connect;
- duplicate Disconnect;
- Connect→Disconnect;
- Disconnect→Connect;
- overlapping-pair deterministic User lock order;
- disjoint pairs;
- User deactivation versus Connect.

No arbitrary sleeps or external network calls.

---

## 16. Proportional Verification

Run from `backend/`:

```bash
./vendor/bin/pint --test

php artisan test \
  tests/Feature/Institution/InstitutionParentStudentsApiTest.php \
  tests/Feature/Institution/InstitutionStudentParentsApiTest.php \
  tests/Feature/Institution/InstitutionParentStudentRelationshipMutationApiTest.php \
  tests/Feature/Institution/InstitutionParentStudentRelationshipConcurrencyTest.php

php artisan test tests/Feature/ApiErrorContractTest.php
```

Then from repository root:

```bash
git diff --check
git status --short
```

Perform the complete focused diff/self-review required by root/backend `AGENTS.md`, including:

- route/API exactness;
- tenant and role scoping;
- existence privacy;
- query count/N+1;
- transaction/lock order;
- idempotent no-write behavior;
- historical preservation;
- no unrelated files/refactors;
- no weakened tests/debug code/secrets.

Do not run the full backend suite in this task. The full backend regression suite belongs to the Stage 4 Backend Phase 2 checkpoint immediately after this task is `Accepted` and `Delivered`.

---

## 17. Acceptance Criteria

The task is implementation-complete when:

- all four locked Parent–Student endpoints match this contract;
- `/parent-student-connections` and pair-addressed DELETE are not introduced;
- public relationship UUID is exposed exactly as required;
- both contextual lists return only current tenant-safe role-correct relationships without N+1;
- Connect creates at most one current relationship per Parent/Student pair;
- repeated current Connect is a write-free `200` no-op;
- Disconnect addresses an exact relationship UUID, ends rather than deletes it, and repeated Disconnect is a write-free `204` no-op;
- reconnect creates a new historical row/new UUID;
- inactive Users remain visible/disconnectable while new missing relationships require active Users;
- Institution ownership and connector are derived only from authentication;
- concurrency and User lifecycle races produce the exact defined outcomes;
- required focused verification passes;
- GitHub delivery completes;
- accepted result is on `origin/main`;
- local `main == origin/main`;
- ahead/behind is `0/0`;
- worktree is clean;
- no history/detail/bulk/candidate/frontend/later-stage/dependency/documentation/unrelated change is present.

Task-level `Accepted` does **not** mean the Stage 4 backend block passed Phase 2. Backend Phase 2 starts only after this task is accepted/delivered.

---

## 18. Stop Conditions

Stop and report instead of inventing a solution if:

- Stage 4 decomposition/task index is not approved;
- `S04-BE-003` is not `Accepted` and `Delivered` on `origin/main`;
- the provided `origin/main` baseline does not match synchronized local `main`;
- Parent–Student persistence from `S04-BE-001` is absent or materially different;
- the required Group/User/API dependencies materially conflict with this contract;
- implementation requires changing the locked four-endpoint public API;
- implementation requires a schema change or new stable error code;
- safe deterministic User/relationship locking cannot be implemented/tested with configured PostgreSQL;
- unrelated user work overlaps the task and cannot be safely preserved;
- PostgreSQL, independent test connections, or required tooling is unavailable;
- a required focused check fails and cannot be corrected within scope.

---

## 19. GitHub Delivery and Task Acceptance

After implementation, focused verification, `git diff --check`, and focused self-review pass:

1. stage only task-owned files;
2. inspect staged diff and run required secret/safety checks;
3. create one focused task commit;
4. push the task branch;
5. open a Pull Request to `main`;
6. merge only when required checks pass and merge is permitted;
7. fetch and resynchronize local `main`;
8. verify local `main == origin/main`;
9. verify ahead/behind is `0/0`;
10. verify the worktree is clean.

If implementation/verification pass but safe delivery cannot complete, report `DELIVERY BLOCKED`.

The task may report `ACCEPTED` only after the delivered result is present on `origin/main` and all synchronization checks pass.

Do not modify task/Stage bookkeeping, start the Backend Phase 2 checkpoint, or begin frontend implementation as part of this implementation task. Phase 2 is a separate orchestration action after task acceptance.

---

## 20. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to rediscover requirements.

| Source | Decision already encoded above |
|---|---|
| `docs/09-api-contracts.md` §11.1 | `GET /api/v1/institution/parents/{parent}/students` |
| `docs/09-api-contracts.md` §11.2 | `GET /api/v1/institution/students/{student}/parents` |
| `docs/09-api-contracts.md` §11.3 | `POST /api/v1/institution/parent-student-relationships`; body uses `parent_id` + `student_id`; public relationship UUID is returned |
| `docs/09-api-contracts.md` §11.4 | `DELETE /api/v1/institution/parent-student-relationships/{relationship}` ends the relationship |
| Stage 4 relationship rules | Parent↔Student is explicit, same-Institution, many-to-many, and historical state is preserved |
| Stage 4 workflow | One task branch, proportional verification, GitHub delivery, task-level acceptance before block Phase 2 |

---

## 21. Codex Completion Report

Return:

1. **Status:** `ACCEPTED`, `BLOCKED`, or `DELIVERY BLOCKED`.
2. **Implementation:** concise result.
3. **Changed files:** file → purpose.
4. **Endpoints:** exact four routes implemented.
5. **Acceptance criteria:** PASS/FAIL evidence.
6. **Verification:** exact commands and results.
7. **Security/tenant:** tenant/role/existence-privacy evidence.
8. **Concurrency/history:** lock order, idempotency, historical preservation evidence.
9. **Scope/diff:** non-goals, `git diff --check`, unrelated-change check.
10. **Delivery:** branch, commit, PR, merge, final `origin/main` SHA, local sync/ahead-behind/clean-worktree evidence.
11. **Deviations/blockers:** exact facts.

Do not repeat the full contract.
