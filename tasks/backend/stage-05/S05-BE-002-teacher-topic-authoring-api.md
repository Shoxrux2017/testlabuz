# S05-BE-002 — Teacher Topic Authoring API

## Task Metadata

| Field | Value |
|---|---|
| Stage | `Stage 5 — Topics and Learning Materials` |
| Area | Backend |
| Status | `Approved` |
| Implementation type | Laravel teacher learning-context and Topic authoring API |
| Depends on | `S05-BE-001 Accepted / Delivered`; Stage 4 Teacher–Group graph |
| Planning baseline | `origin/main` @ `17129ede0e266087c23355f135f9a340ccdaaf92` |
| Implementation baseline | `Freeze current origin/main after bookkeeping + this task contract are delivered and before Codex starts` |
| Verification model | `Workflow v3 — Lean Verification` |
| Delivery owner | `Project Owner` |
| Block checkpoint | Stage 5 Backend Phase 2 after `S05-BE-001…005` are Accepted / Delivered |

---

## 1. Implementation Authority and Required Inputs

This file is the complete implementation contract for `S05-BE-002`.

Codex must read only:

1. this task;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. directly relevant backend source/tests required by this task.

Codex must not read product specifications, roadmap files, architecture/database
documents, API specification documents, Stage indexes, previous task files,
closure reviews, or Stage history to rediscover requirements.

Before Codex starts, ChatGPT / orchestration must:

- confirm `S05-BE-001` is Accepted / Delivered on current `origin/main`;
- confirm bookkeeping and this `S05-BE-002` contract are delivered;
- freeze the exact current `origin/main` implementation baseline;
- ensure local `main` is clean and synchronized with that baseline.

If current source materially conflicts with this contract, stop and report the
exact conflict. Do not invent a product/API/security/lifecycle decision.

---

## 2. Goal

Implement the first Teacher learning-content API surface:

```text
GET   /api/v1/teacher/groups
GET   /api/v1/teacher/topics
POST  /api/v1/teacher/topics
GET   /api/v1/teacher/topics/{topic}
PATCH /api/v1/teacher/topics/{topic}
```

The result must let an authenticated Teacher:

- see only currently assigned active Groups available for new authoring;
- list only Topics in current authorized Teacher scope;
- create a draft Topic only for a currently assigned active Group;
- view own authorized Topic;
- update allowed metadata only while Topic/Group state remains editable.

All authorization and Institution scope are server-derived.

---

## 3. Explicit Non-Goals

Do not implement:

- Topic `activate`;
- Topic `close`;
- Topic `archive`;
- Learning Material list/upload/replace/update/remove;
- protected file download;
- Student Topic APIs;
- Parent access;
- Institution Admin learning-content authoring;
- Homework, Blitz, submissions, scoring, results;
- new migrations or schema changes;
- file-storage operations;
- new packages/dependencies;
- frontend code;
- seed/demo data;
- broad refactors;
- generic repository/service abstractions.

Do not change Stage 1–4 behavior except where the new Teacher routes require
shared route/error regression coverage.

---

## 4. Current Implementation Context

At the approved planning baseline:

- `Topic`, `File`, and `LearningMaterial` persistence already exists from
  `S05-BE-001`;
- `GroupTeacherMembership::current()` exists and means `ended_at is null`;
- Institution Admin Group APIs already demonstrate:
  - strict query/body validation;
  - literal PostgreSQL `ILIKE` search with escaped `%` / `_`;
  - deterministic sort with UUID tie-break;
  - Controller → Action → Resource layering;
- production routes currently contain `auth`, `platform`, and `institution`
  groups only; no Teacher product route block exists yet;
- shared API errors already support `validation_failed`, `forbidden`,
  `resource_not_found`, and generic conflict handling;
- `topic_not_editable` is not yet implemented in the shared API error boundary.

Reuse existing conventions. Do not copy Institution Admin behavior blindly when
Teacher authorization differs.

---

## 5. Teacher Route and Middleware Contract

Add one Teacher route group:

```text
prefix: teacher

middleware order:
auth:sanctum
→ active.account
→ password.changed
→ role:teacher
```

Routes:

```text
GET   /teacher/groups
GET   /teacher/topics
POST  /teacher/topics
GET   /teacher/topics/{topic}
PATCH /teacher/topics/{topic}
```

Do not add aliases, duplicate routes, or lifecycle/material routes.

The backend derives Institution scope only from the authenticated Teacher.

No query/body/path/header `institution_id` is authority.

---

## 6. `GET /api/v1/teacher/groups`

### 6.1 Purpose

Read-only Teacher learning context.

This endpoint does not grant Group administration capability.

### 6.2 Authorization Scope

Return a Group only when all are true:

```text
group.institution_id = authenticated Teacher institution
group.status = active
current GroupTeacherMembership exists
membership.teacher_id = authenticated Teacher id
membership.ended_at is null
```

Ended memberships, archived Groups, foreign-Institution Groups, and unrelated
Groups are excluded.

### 6.3 Accepted Query

Exactly:

```text
search
page
per_page
sort
direction
```

Unknown query keys return `422 validation_failed`.

Any request body returns `422 validation_failed`.

### 6.4 Query Rules

```text
search:
  optional
  nullable
  string
  trim
  max 254
  empty after trim => no search

page:
  optional
  integer
  min 1
  default 1

per_page:
  optional
  integer
  min 1
  max 100
  default 20

sort:
  optional
  one of name|level|subject_direction
  default name

direction:
  optional
  asc|desc
  default asc
```

Search is a case-insensitive literal substring across `name`, `level`, and
`subject_direction`.

Escape SQL wildcard characters so `%` and `_` are treated literally.

Sorting:

- `name`, `level`, and `subject_direction` are case-insensitive;
- every sort uses Group UUID as deterministic tie-break;
- tie-break direction matches requested direction;
- nullable `level` / `subject_direction` use one deterministic PostgreSQL order;
  do not sort in PHP.

### 6.5 Success Resource

`200 OK`

Each item contains exactly:

```json
{
  "id": "group-uuid",
  "name": "9-A",
  "level": "Grade 9",
  "subject_direction": "Informatics",
  "status": "active"
}
```

Do not expose:

```text
institution_id
description
created_by_user_id
teachers_count
students_count
membership row/id
unrelated user data
```

Pagination envelope:

```json
{
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

---

## 7. Teacher Topic Read Scope

All Teacher Topic list/detail/update operations must begin from this scope:

```text
authenticated Teacher
+ same Institution
+ topic.teacher_id = authenticated Teacher id
+ current Teacher–Group membership for topic.group_id
```

The Group may be `active` or `archived` for read access.

A Topic must be hidden with the same `404 resource_not_found` when any is true:

- UUID is syntactically invalid;
- Topic is missing;
- Topic belongs to another Institution;
- Topic belongs to another Teacher in the same Group;
- Topic Group has no current Teacher membership;
- prior membership ended.

Do not reveal which authorization condition failed.

---

## 8. Teacher Topic Resource

Use one exact resource for Topic list/create/detail/update.

```json
{
  "id": "topic-uuid",
  "group": {
    "id": "group-uuid",
    "name": "9-A",
    "level": "Grade 9",
    "subject_direction": "Informatics",
    "status": "active"
  },
  "title": "Internet Basics",
  "description": null,
  "subject": "Informatics",
  "student_instructions": "Study the materials.",
  "lesson_at": null,
  "status": "draft",
  "activated_at": null,
  "closed_at": null,
  "archived_at": null,
  "created_at": "2026-08-22T08:00:00Z",
  "updated_at": "2026-08-22T08:00:00Z"
}
```

Do not expose:

```text
institution_id
teacher_id
raw membership data
storage metadata
materials
results
```

All timestamps in public Topic resources are UTC `...Z`.

The Resource must not issue hidden queries. Actions must load the required Group
projection before serialization.

---

## 9. `GET /api/v1/teacher/topics`

### 9.1 Accepted Query

Exactly:

```text
group_id
status
search
page
per_page
sort
direction
```

Unknown keys or a request body return `422 validation_failed`.

### 9.2 Validation and Defaults

```text
group_id:
  optional UUID

status:
  optional
  draft|active|closed|archived

search:
  optional
  nullable string
  trim
  max 254
  empty after trim => no search

page:
  default 1
  min 1

per_page:
  default 20
  min 1
  max 100

sort:
  title|lesson_at|created_at|updated_at
  default created_at

direction:
  asc|desc
  default desc
```

Every sort uses Topic UUID as deterministic tie-break in the same direction.

Title sorting is case-insensitive.

Use deterministic PostgreSQL ordering for nullable `lesson_at`; do not sort in
PHP.

### 9.3 Search

Case-insensitive literal substring search over:

```text
title
subject
```

Escape `%` and `_` so they are literal input.

### 9.4 `group_id` Scope Behavior

If `group_id` is syntactically invalid:

```text
422 validation_failed
```

If it is a valid UUID but the Group is:

- foreign Institution;
- unrelated to the authenticated Teacher;
- only historically/ended assigned;

return:

```text
404 resource_not_found
```

An archived Group is valid for Topic read filtering when the current Teacher
membership still exists.

A current-authorized Group with zero matching Topics returns:

```text
200
data = []
```

### 9.5 Success

Return only Topics satisfying Section 7 read scope.

Return exact Topic resources and normal pagination metadata.

---

## 10. `POST /api/v1/teacher/topics`

### 10.1 Input Shape

Accept exactly one `application/json` object with:

```text
group_id
title
description
subject
student_instructions
lesson_at
```

Query parameters are not allowed.

Unknown or protected JSON keys are rejected.

Malformed JSON, scalar root, array root, or empty body is rejected.

All such request-shape failures return `422 validation_failed`.

### 10.2 Field Validation

```text
group_id:
  required
  UUID syntax

title:
  required
  string
  trim
  non-empty
  max 255

description:
  optional
  nullable
  string

subject:
  required
  string
  trim
  non-empty
  max 160

student_instructions:
  required
  string
  trim
  non-empty

lesson_at:
  optional
  nullable
  RFC 3339 date-time
  explicit numeric offset required
  must be valid for the authenticated Institution IANA timezone
```

Do not accept `Z` for Teacher-entered `lesson_at` in this authoring contract.

Examples:

```text
valid:
2026-08-25T09:00:00+05:00

invalid:
2026-08-25T09:00:00
2026-08-25T04:00:00Z
```

### 10.3 Group Authorization

Create requires:

```text
same Institution
+ active Group
+ current GroupTeacherMembership for authenticated Teacher
```

Any missing, foreign, unrelated, ended-membership, or archived Group returns:

```text
404 resource_not_found
```

Do not return a Group-assignment-specific 403.

### 10.4 Server-Owned Fields

Backend sets:

```text
id = server UUID
institution_id = authenticated Teacher institution
teacher_id = authenticated Teacher id
status = draft
activated_at = null
closed_at = null
archived_at = null
```

The client cannot set ownership or lifecycle fields.

### 10.5 Transaction and Locking

Create must be race-safe against Stage 4 Group archive and Teacher membership
removal.

Use this lock order inside one transaction:

```text
1. same-Institution Group
2. current Teacher–Group membership
3. INSERT Topic
```

Requirements:

- lock Group first;
- Group must still be active under the lock;
- lock the current membership row after Group;
- membership must still be current under the lock;
- then insert Topic.

If archive/removal completes first, create must fail scope-safely with
`404 resource_not_found`.

If create holds the required locks first, the Topic may be inserted and the
later Stage 4 operation completes after commit.

Do not introduce broader locking.

### 10.6 Success

`201 Created`

Return exact Topic resource and:

```text
message = Topic created successfully.
```

---

## 11. Institution Timezone / `lesson_at` Contract

Teacher-entered `lesson_at` is educational local date/time input.

The backend must:

1. resolve Institution timezone from the authenticated Teacher's
   `institution_settings.timezone`;
2. require RFC 3339 with explicit numeric offset;
3. parse the submitted local wall-clock plus offset;
4. validate that the submitted offset is valid for that local date/time in the
   Institution IANA timezone;
5. reject nonexistent/invalid local-offset combinations with
   `422 validation_failed`;
6. persist the authoritative instant;
7. return UTC `...Z` in Topic resources.

Example for `Asia/Tashkent`:

```text
2026-08-25T09:00:00+05:00
→ response 2026-08-25T04:00:00Z
```

`+04:00` for that same local wall-clock is invalid.

Do not use the client/device timezone as authority.

Keep persisted-context timezone validation outside a FormRequest when it requires
database state. A small focused support/domain helper is allowed when needed by
both create and update; do not create a generic date framework.

---

## 12. `GET /api/v1/teacher/topics/{topic}`

Path UUID is the only accepted input.

Any query parameter or request body:

```text
422 validation_failed
```

Resolve only through Teacher Topic read scope from Section 7.

Out of scope:

```text
404 resource_not_found
```

Success:

```text
200
data = exact Topic resource
no success message
```

---

## 13. `PATCH /api/v1/teacher/topics/{topic}`

### 13.1 Input Shape

Accept a non-empty partial JSON object containing only:

```text
title
description
subject
student_instructions
lesson_at
```

Query parameters are not allowed.

Reject:

- malformed JSON;
- empty body;
- scalar root;
- array root;
- empty object;
- unknown fields;
- protected fields.

Protected examples include:

```text
institution_id
teacher_id
group_id
status
activated_at
closed_at
archived_at
created_at
updated_at
```

Failures return `422 validation_failed`.

### 13.2 Field Validation

Use corresponding create rules.

Differences:

```text
title:
  when present required/non-null

subject:
  when present required/non-null

student_instructions:
  when present required/non-null

description:
  when present nullable

lesson_at:
  when present nullable
```

Explicit `null` clears `description` and `lesson_at`.

Omitted fields remain unchanged.

### 13.3 Authorization and Editability Order

First enforce Teacher Topic read scope.

If read scope fails:

```text
404 resource_not_found
```

Only after scope is established evaluate editability.

Metadata update requires:

```text
Group.status = active
Topic.status in (draft, active)
current Teacher–Group membership still exists
```

If Topic is `closed` / `archived`, or its Group is archived:

```text
409 topic_not_editable
```

Ended membership remains:

```text
404 resource_not_found
```

Do not leak lifecycle state to an actor outside read scope.

### 13.4 Transaction and Locking

Update must be race-safe against:

- Stage 4 Group archive;
- Teacher membership removal;
- future Topic lifecycle mutations.

A scope-safe lightweight Topic lookup may be used first only to obtain immutable
`group_id`.

Then inside one transaction use lock order:

```text
1. Group
2. current Teacher–Group membership
3. Topic
```

After locking:

- re-check Group Institution/status;
- re-check current membership;
- re-check Topic same Institution, teacher ownership, group_id, and status;
- only then apply allowed metadata.

Never lock an unscoped record first.

### 13.5 No-Op

After normalization, if no persisted field changes:

```text
200
message = Topic updated successfully.
```

Return current Topic resource.

Do not change:

```text
updated_at
ownership
group_id
lifecycle state
lifecycle timestamps
```

### 13.6 Real Update

A real update:

- is atomic;
- changes `updated_at`;
- changes only explicitly supplied allowed metadata.

Success:

```text
200
message = Topic updated successfully.
```

---

## 14. `topic_not_editable` Error Contract

Add a focused expected exception, for example:

```text
App\Exceptions\Teacher\TopicNotEditableException
```

Map it through the shared API error boundary.

Exact response:

```text
HTTP 409
message = The topic is not editable.
code = topic_not_editable
errors = {}
```

Do not change the global API envelope.

Do not reuse a generic business conflict code for this public contract.

---

## 15. Required Backend Structure

Follow existing Controller → Action → Eloquent/Resource patterns.

Expected focused classes:

```text
app/Actions/Teacher/
  ListTeacherGroups.php
  ListTeacherTopics.php
  CreateTeacherTopic.php
  ShowTeacherTopic.php
  UpdateTeacherTopic.php

app/Http/Controllers/Api/V1/Teacher/
  TeacherGroupController.php
  TeacherTopicController.php

app/Http/Requests/Teacher/
  TeacherGroupIndexRequest.php
  TeacherTopicIndexRequest.php
  TeacherTopicCreateRequest.php
  TeacherTopicShowRequest.php
  TeacherTopicUpdateRequest.php

app/Http/Resources/Teacher/
  TeacherGroupResource.php
  TeacherGroupCollection.php
  TeacherTopicResource.php
  TeacherTopicCollection.php

app/Exceptions/Teacher/
  TopicNotEditableException.php
```

A small focused support/domain class for reusable Institution-timezone
`lesson_at` parsing/validation is allowed if needed.

Exact class splitting may follow existing repository conventions as long as the
contract boundaries remain explicit and no generic architecture is introduced.

Controllers must remain thin.

Resources must not run authorization/business queries.

---

## 16. Query and Performance Contract

### 16.1 Teacher Groups

- tenant scope first;
- current Teacher membership filter in SQL;
- active Group filter in SQL;
- server-side search/sort/pagination;
- no PHP collection filtering;
- no N+1.

### 16.2 Teacher Topics

- tenant + Teacher ownership + current membership scope in SQL;
- server-side filters/search/sort/pagination;
- load Group projection needed by Topic Resource;
- Resource serialization performs no queries;
- deterministic ordering;
- no unbounded reads.

Do not add indexes in this task unless a concrete query plan shows an approved
schema gap. A schema change requires ChatGPT review because this contract
contains no planned migration.

---

## 17. Required Focused Tests

Add exactly:

```text
backend/tests/Feature/Teacher/TeacherAssignedGroupApiTest.php
backend/tests/Feature/Teacher/TeacherTopicReadApiTest.php
backend/tests/Feature/Teacher/TeacherTopicMutationApiTest.php
```

Use real Laravel HTTP, middleware, PostgreSQL, Actions, persistence, and
Resources. Do not mock the changed authorization/persistence boundary.

### 17.1 `TeacherAssignedGroupApiTest`

Cover:

- unauthenticated → `401 authentication_required`;
- wrong role → `403 forbidden`;
- inactive Teacher / inactive Institution behavior through existing middleware;
- password-change-required behavior through existing middleware;
- exact Teacher route middleware/order;
- only current assigned active same-Institution Groups returned;
- ended membership excluded;
- archived Group excluded;
- unrelated Group excluded;
- foreign-Institution Group excluded;
- one Teacher assigned to multiple Groups;
- literal `%` / `_` search behavior;
- search over `name`, `level`, `subject_direction`;
- allowed sort/direction;
- deterministic UUID tie-break;
- page/per_page defaults and bounds;
- unknown query key → 422;
- invalid query values → 422;
- request body → 422;
- exact resource keys and pagination envelope;
- no admin-only/count/membership fields exposed.

### 17.2 `TeacherTopicReadApiTest`

Cover:

- exact Teacher route middleware/order;
- Topic list returns only same Institution + authenticated Teacher-owned +
  current membership-scoped Topics;
- other Teacher Topic hidden;
- foreign-Institution Topic hidden;
- ended Teacher membership revokes access;
- archived Group Topic remains readable while membership is current;
- active Group Topic readable;
- `group_id` filter:
  - invalid UUID → 422;
  - unrelated/foreign/ended-membership Group → 404;
  - current authorized archived Group → allowed;
  - authorized Group with no Topics → empty 200;
- `status` filter;
- literal title/subject search;
- allowed sort/direction;
- deterministic UUID tie-break;
- pagination defaults/bounds;
- unknown query/body → 422;
- detail success exact resource;
- invalid/missing/foreign/other-Teacher/ended-membership Topic detail → 404;
- detail query/body → 422;
- exact Topic and nested Group resource keys;
- no hidden Institution/Teacher/membership/storage data;
- no Resource N+1/hidden query behavior.

Use a query-count assertion only if stable under the current Laravel test
environment; otherwise prove no hidden Resource queries using a repository-
compatible focused technique.

### 17.3 `TeacherTopicMutationApiTest`

Cover create:

- valid draft creation;
- server-owned Institution/Teacher/status/lifecycle fields;
- exact `201` + message/resource;
- active current-assigned Group required;
- missing/foreign/unrelated/ended/archived Group → 404;
- unknown/protected fields → 422;
- query parameters → 422;
- malformed/scalar/array/empty root → 422;
- required/non-empty/max-length rules;
- `lesson_at = null`;
- valid numeric-offset lesson time persisted and returned UTC;
- no-offset input rejected;
- `Z` input rejected;
- wrong Institution timezone offset rejected;
- invalid/nonexistent local time rejected when applicable to fixture timezone.

Cover update:

- draft metadata update;
- active metadata update;
- allowed nullable clearing;
- protected/unknown fields rejected;
- empty object/body/malformed/scalar/array/query rejected;
- closed Topic → `409 topic_not_editable`;
- archived Topic → `409 topic_not_editable`;
- archived Group → `409 topic_not_editable`;
- ended membership → `404 resource_not_found`;
- other Teacher/foreign Topic → 404;
- exact no-op leaves `updated_at` unchanged;
- real update changes `updated_at`;
- ownership/group/status/lifecycle timestamps never mutate;
- success exact `200` + message/resource.

Concurrency/race coverage:

- create vs Group archive;
- create vs Teacher membership removal;
- update vs Group archive;
- update vs Teacher membership removal.

Use the minimum deterministic PostgreSQL concurrency technique consistent with
existing Stage 4 concurrency tests. Verify approved lock-order outcomes; do not
add a broad generic concurrency framework.

---

## 18. Directly Affected Shared Regression Tests

Run these existing tests because this task changes production routes and the
shared API error boundary:

```text
tests/Feature/ApiErrorContractTest.php
tests/Feature/Authorization/RoleAuthorizationProductionRouteHygieneTest.php
```

Do not run the full Stage 4 Group API suite by default.

Stage 4 Group/membership behavior is consumed but not modified. New focused
Teacher tests must exercise the current membership semantics directly.

---

## 19. Proportional Verification

Run from `backend/`.

### 19.1 Formatter

```bash
./vendor/bin/pint --test
```

### 19.2 New Stage 5 Teacher tests

```bash
php artisan test \
  tests/Feature/Teacher/TeacherAssignedGroupApiTest.php \
  tests/Feature/Teacher/TeacherTopicReadApiTest.php \
  tests/Feature/Teacher/TeacherTopicMutationApiTest.php
```

### 19.3 Directly affected shared regression

```bash
php artisan test \
  tests/Feature/ApiErrorContractTest.php \
  tests/Feature/Authorization/RoleAuthorizationProductionRouteHygieneTest.php
```

Do not run the full backend suite. Full backend regression belongs to Stage 5
Backend Phase 2 after `S05-BE-001…005`.

If host PHP cannot run PostgreSQL tests because `pdo_pgsql` is unavailable,
execute the same commands in the repository-provided Docker PHP/PostgreSQL
runtime. Report the environment fact; do not alter project dependencies.

### 19.4 Repository checks

From repository root:

```bash
git diff --check
git status --short
```

Then perform the focused scope/security/diff self-review required by root and
backend `AGENTS.md`.

---

## 20. Acceptance Criteria

`S05-BE-002` is implementation-complete only when all are true:

1. Teacher route block exists with exact middleware order.
2. `/teacher/groups` returns only current assigned active same-Institution
   Groups.
3. Teacher Group search/sort/pagination is server-side, literal, deterministic,
   and strict.
4. Topic list/detail enforce same-Institution + Teacher ownership + current
   Teacher–Group membership before exposure.
5. Archived Group Topics remain readable only while membership remains current.
6. `group_id` Topic filter cannot broaden scope.
7. Topic create requires active Group + current Teacher membership.
8. Topic create server-assigns Institution/Teacher/draft lifecycle ownership.
9. Create is race-safe against Group archive and membership removal.
10. Topic update permits only approved metadata in `draft|active` and active
    Group state.
11. Update authorization precedes lifecycle disclosure.
12. Closed/archived/archived-Group mutation returns exact
    `409 topic_not_editable`.
13. Exact PATCH no-op leaves `updated_at` unchanged.
14. Real PATCH updates only supplied metadata and changes no ownership/lifecycle
    fields.
15. Update is race-safe against Group archive, membership removal, and future
    lifecycle mutation.
16. Teacher-entered `lesson_at` requires valid Institution-local numeric offset,
    persists authoritative instant, and returns UTC.
17. Success resources/envelopes/messages match this contract exactly.
18. Cross-tenant, other-Teacher, ended-membership, and direct UUID probes remain
    privacy-safe.
19. Resources perform no hidden authorization/business queries.
20. Required focused tests pass.
21. Pint passes.
22. directly affected shared regression tests pass.
23. `git diff --check` passes.
24. no migration, material API, lifecycle endpoint, Student API, frontend,
    dependency, seed, docs, or unrelated refactor is introduced.

---

## 21. Focused Self-Review Checklist

Before reporting completion, Codex must confirm:

- Teacher middleware order is exact;
- no client Institution ownership field is trusted;
- all Topic exposure starts from tenant + Teacher + current membership scope;
- `group_id` filter cannot enumerate unrelated Groups;
- archived Group read vs authoring/edit distinction is preserved;
- no lifecycle endpoint was added;
- Group → membership → Topic mutation lock order is consistent;
- no lock starts from an unscoped Topic/Group;
- update revalidates locked current state;
- no-op does not touch `updated_at`;
- Resources do not query;
- `%` / `_` are literal in search;
- pagination/sort remain SQL-side and deterministic;
- `lesson_at` timezone validation is server/Institution authoritative;
- `topic_not_editable` uses exact code/status/envelope;
- no Stage 1–4 route/error behavior was accidentally changed;
- no unrelated files changed.

---

## 22. Delivery and Completion Report

Routine Git/GitHub delivery is owned by the Project Owner.

Codex must not commit, push, open a PR, or merge unless explicitly instructed
outside this contract.

Codex final report must include:

```text
S05-BE-002 IMPLEMENTATION COMPLETE
```

and report:

- changed production files;
- changed test files;
- routes added;
- exact authorization/lifecycle behavior implemented;
- exact verification commands/results;
- concurrency test result;
- `git diff --check` result;
- focused diff/security self-review result;
- final Git state;
- any contract blocker if implementation could not be completed safely.

If a required check fails, report the exact failure and leave the task not
complete.

---

# Final Implementation Rule

> Implement only the Teacher assigned-Group projection and Teacher Topic
> list/create/detail/update authoring API defined here. Current authenticated
> Institution/Teacher/Group membership is the authorization source; lifecycle
> endpoints, materials, Student delivery, and later assessment behavior remain
> outside `S05-BE-002`.
