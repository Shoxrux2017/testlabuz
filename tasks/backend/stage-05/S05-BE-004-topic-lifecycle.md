# S05-BE-004 — Topic Lifecycle

## Task Metadata

| Field | Value |
|---|---|
| Stage | `Stage 5 — Topics and Learning Materials` |
| Area | Backend |
| Status | `Approved` |
| Implementation type | Laravel Teacher Topic lifecycle API |
| Depends on | `S05-BE-003 Accepted / Delivered`; `S05-BE-002` Teacher Topic authoring |
| Planning baseline | `origin/main` @ `dbcaaf02073bab269ce729173795f7ee55ea0909` |
| Implementation baseline | `Freeze current origin/main after S05-BE-003 bookkeeping + this task contract are delivered and before Codex starts` |
| Verification model | `Workflow v3 — Lean Verification` |
| Delivery owner | `Project Owner` |
| Block checkpoint | Stage 5 Backend Phase 2 after `S05-BE-001…005` are Accepted / Delivered |

---

## 1. Implementation Authority

This file is the complete implementation contract for `S05-BE-004`.

Codex must read only:

1. this task;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. directly relevant backend source/tests required by this task.

Codex must not read product specifications, roadmap files, architecture/database/API
documents, Stage indexes, previous task files, closure reviews, or Stage history
to rediscover requirements.

Before Codex starts, ChatGPT / orchestration must:

- confirm `S05-BE-003` is Accepted / Delivered on current `origin/main`;
- confirm S05-BE-003 bookkeeping and this contract are delivered;
- freeze the exact current `origin/main` implementation baseline;
- ensure local `main` is clean and synchronized.

If current source materially conflicts with this contract, stop and report the
exact conflict. Do not invent product/API/security/lifecycle behavior.

---

## 2. Goal

Implement the controlled Teacher Topic lifecycle:

```text
POST /api/v1/teacher/topics/{topic}/activate
POST /api/v1/teacher/topics/{topic}/close
POST /api/v1/teacher/topics/{topic}/archive
```

Required lifecycle:

```text
draft → active
draft → archived
active → closed
closed → archived
```

Required invariants:

- `archived` is terminal;
- no return to `draft`;
- no `active → archived`;
- lifecycle fields are backend-owned;
- transitions are atomic and concurrency-safe;
- idempotent same-state lifecycle calls do not write;
- lifecycle never hard-deletes Topic/material/history;
- activation requires current learning content;
- Group/membership/Teacher/Tenant scope remains authoritative.

---

## 3. Explicit Non-Goals

Do not implement:

- Topic delete;
- Topic restore/reopen;
- `active → draft`;
- `closed → active`;
- `archived → *`;
- arbitrary client `status` mutation;
- Student Topic APIs;
- protected file download;
- Homework/Blitz lifecycle or cascade behavior;
- Homework as Topic activation prerequisite;
- Student recipient snapshotting;
- result-pair behavior;
- frontend changes;
- schema/migration changes;
- new database columns/indexes;
- new Composer dependencies;
- new error codes;
- broad refactors;
- changes to Learning Material storage/type/size behavior from S05-BE-003.

---

## 4. Current Implementation Context

At the planning baseline:

- `TopicStatus` already contains `draft`, `active`, `closed`, `archived`;
- `Topic` already persists/casts `status`, `activated_at`, `closed_at`, `archived_at`;
- Teacher Topic create/list/detail/update exists;
- `Topic::visibleToTeacher()` already enforces same Institution, owning Teacher,
  and current Teacher–Group membership;
- `TeacherTopicResource` already exposes lifecycle fields and preloaded Group projection;
- `TopicNotEditableException` and exact `409 topic_not_editable` mapping exist;
- S05-BE-003 already implements current Learning Material/File rules;
- material mutations use `Group → membership → Topic → LearningMaterial → File`;
- Group archival and Teacher membership removal both lock Group first;
- no Student Topic delivery exists yet.

Reuse these contracts instead of duplicating authorization or serialization.

---

## 5. Route and Middleware Contract

All three endpoints use the existing Teacher middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:teacher
```

Add exactly:

```text
POST /teacher/topics/{topic}/activate
POST /teacher/topics/{topic}/close
POST /teacher/topics/{topic}/archive
```

Do not add generic lifecycle/status routes.

---

## 6. Shared Lifecycle Request Contract

Use one focused Form Request for all three lifecycle endpoints:

```text
TeacherTopicLifecycleRequest
```

Accepted input:

```text
no request body
```

or an explicit empty JSON object:

```json
{}
```

No query parameters are allowed.

Reject with:

```text
422 validation_failed
```

when any of these are present:

- non-empty JSON object;
- malformed JSON;
- scalar JSON root;
- array JSON root;
- non-empty non-JSON body;
- query parameter.

No lifecycle endpoint accepts `status`, lifecycle timestamps, ownership fields,
or any other client field.

No `Idempotency-Key` header is required for Topic lifecycle in Stage 5.

---

## 7. Shared Teacher Scope and Existence Privacy

Every lifecycle endpoint must first resolve Topic through:

```text
authenticated Teacher
+ Topic.institution_id = Teacher.institution_id
+ Topic.teacher_id = Teacher.id
+ current Teacher–Group membership
```

The Group may be active or archived for scope resolution.

Return the same:

```text
404 resource_not_found
```

for invalid/missing UUID, foreign Institution, another Teacher, ended membership,
or any other out-of-scope Topic.

Authorization/existence privacy is checked before lifecycle-state disclosure.

---

## 8. Shared Transaction and Lock Order

All lifecycle operations run inside a database transaction.

Lock in this exact order:

```text
1. Group
2. current GroupTeacherMembership
3. Topic
```

All lookups are scoped by authenticated Institution and Teacher.

Do not lock Topic first.
Do not use unscoped `findOrFail()` before tenant/Teacher/membership scope.

For real activation, check the material prerequisite only after these locks.

---

# 9. Activate Topic

Endpoint:

```text
POST /api/v1/teacher/topics/{topic}/activate
```

## 9.1 Group Rule

Activation requires:

```text
Group.status = active
```

This applies before same-state idempotency.

Therefore an archived Group returns:

```text
409 topic_not_editable
```

even if the Topic had previously become `active`.

An archived Group permits only the historical `close` / `archive` operations.

## 9.2 Lifecycle Matrix

```text
draft    → active
active   → idempotent 200
closed   → 409 topic_not_editable
archived → 409 topic_not_editable
```

The idempotent `active → active` path is allowed only while Group remains active
and current Teacher membership remains valid.

## 9.3 Required Topic Metadata

A real `draft → active` must confirm persisted required metadata:

```text
title: trimmed non-empty, <= 255
subject: trimmed non-empty, <= 160
student_instructions: trimmed non-empty
```

`description` and `lesson_at` remain optional.

Invalid required metadata:

```text
409 topic_not_editable
```

No new readiness error code.

## 9.4 Current Learning Material Prerequisite

A real activation requires at least one current valid attachment:

```text
LearningMaterial:
  same Institution
  same locked Topic
  teacher_id = authenticated Teacher
  removed_at IS NULL

linked File:
  same Institution
  category = learning_material
  removed_at IS NULL
```

Homework is not required.

Do not check physical `Storage::exists()` during activation.

No valid current Material/File:

```text
409 topic_not_editable
```

## 9.5 Material Locking

After:

```text
Group → membership → Topic
```

select one valid current Material by:

```text
position ASC
created_at ASC
id ASC
```

Lock that `LearningMaterial`, then its current linked `File`, and revalidate the
current predicates on the locked rows.

Do not use an unlocked `exists()` as the authoritative activation decision.

## 9.6 Real Activation Write

Using one authoritative server time:

```text
status = active
activated_at = now
closed_at = null
archived_at = null
```

Do not change ownership, Topic metadata, or materials.

A real transition advances `updated_at` once.

## 9.7 Idempotent Activation

Already `active` in an active Group:

```text
200 OK
no write
```

Preserve lifecycle timestamps and `updated_at`.

Do not re-run the material prerequisite for same-state idempotency.

## 9.8 Success

Return existing `TeacherTopicResource` plus:

```text
message = Topic activated successfully.
```

---

# 10. Close Topic

Endpoint:

```text
POST /api/v1/teacher/topics/{topic}/close
```

The Group may be active or archived while current Teacher membership remains valid.

Lifecycle:

```text
draft    → 409
active   → closed
closed   → idempotent 200
archived → 409
```

Real close:

```text
status = closed
closed_at = now
```

Preserve `activated_at`, Topic metadata, materials, ownership, and history.

No Homework/Blitz cascade exists in this task.

Already closed:

```text
200 OK
no write
```

Preserve `closed_at` and `updated_at`.

Success message:

```text
Topic closed successfully.
```

---

# 11. Archive Topic

Endpoint:

```text
POST /api/v1/teacher/topics/{topic}/archive
```

The Group may be active or archived while current Teacher membership remains valid.

Lifecycle:

```text
draft    → archived
active   → 409
closed   → archived
archived → idempotent 200
```

Active Topic must be closed first.

Real archive:

```text
status = archived
archived_at = now
```

For draft archive, activation/close timestamps remain null.
For closed archive, preserve activation/close timestamps.

Never alter Topic metadata, ownership, materials, or history.

Already archived:

```text
200 OK
no write
```

Preserve `archived_at` and `updated_at`.

Success message:

```text
Topic archived successfully.
```

---

## 12. Exact Lifecycle Matrix

| Current | Active Group: activate | Active Group: close | Active Group: archive |
|---|---|---|---|
| `draft` | real → `active` if ready | `409` | real → `archived` |
| `active` | idempotent `200` | real → `closed` | `409` |
| `closed` | `409` | idempotent `200` | real → `archived` |
| `archived` | `409` | `409` | idempotent `200` |

Archived Group with current Teacher membership:

| Current | activate | close | archive |
|---|---|---|---|
| `draft` | `409` | `409` | real → `archived` |
| `active` | `409` | real → `closed` | `409` |
| `closed` | `409` | idempotent `200` | real → `archived` |
| `archived` | `409` | `409` | idempotent `200` |

Every lifecycle conflict uses existing:

```text
409
code = topic_not_editable
message = The topic is not editable.
errors = {}
```

---

## 13. Interaction With Learning Material Mutation

S05-BE-003 permits material mutation only for:

```text
Group active
Topic draft|active
```

Preserve this behavior.

Important outcomes:

- close first → later material mutation fails;
- draft archive first → later material mutation fails;
- material mutation first → close/archive may proceed afterward;
- activation requires a current material only at transition time;
- after successful activation, Teacher may later remove the final current
  material while Topic remains active.

Do not introduce a permanent “active Topic must always contain material” invariant.

---

## 14. Required Concurrency Outcomes

Use deterministic PostgreSQL lock-wait tests. No arbitrary sleep correctness.

### Activation vs Group archive

```text
activate first → activate success; Group archive success; Topic active, Group archived
archive first → archive success; activate 409
```

### Activation vs membership removal

```text
activate first → activate success; removal success; later Teacher access revoked
removal first → removal success; activate 404
```

### Activation vs only current Material remove

```text
activate first → activate success; material remove success; Topic stays active
remove first → remove success; activate 409
```

### Upload vs activation, initially no material

```text
upload first → upload success; activate success
activate first → activate 409; upload success; Topic remains draft
```

### Activate vs archive on draft

```text
activate first → activate success; archive 409; final active
archive first → archive success; activate 409; final archived
```

### Activate vs close on draft

```text
activate first → activate success; close success; final closed
close first → close 409; activate success; final active
```

### Close vs archive on active

```text
close first → close success; archive success; final archived
archive first → archive 409; close success; final closed
```

### Close vs Group archive

Either order:

```text
both succeed
final Topic closed
final Group archived
```

### Same-endpoint concurrency

At minimum:

```text
two concurrent activate calls on activation-ready draft:
  both 200
  one logical activation
  no timestamp regression

two concurrent close calls on active:
  both 200
  one logical close

two concurrent archive calls on draft or closed:
  both 200
  one logical archive
```

---

## 15. Required Backend Structure

Expected new classes:

```text
app/Actions/Teacher/
  ActivateTeacherTopic.php
  CloseTeacherTopic.php
  ArchiveTeacherTopic.php

app/Http/Requests/Teacher/
  TeacherTopicLifecycleRequest.php

app/Support/Teacher/
  TeacherTopicLifecycleAccess.php
```

Update:

```text
app/Http/Controllers/Api/V1/Teacher/TeacherTopicController.php
routes/api.php
```

A smaller focused internal split is allowed if it matches current conventions,
but do not duplicate the complete scoped lock sequence three times when a focused
shared helper can represent it safely.

Do not reuse material editability as close/archive authority.

No new Resource, migration, dependency, or API error code.

---

## 16. Required Focused Tests

Add exactly:

```text
backend/tests/Feature/Teacher/TeacherTopicLifecycleApiTest.php
backend/tests/Feature/Teacher/TeacherTopicLifecycleConcurrencyTest.php
```

### `TeacherTopicLifecycleApiTest`

Cover:

- exact three routes + Teacher middleware;
- auth/account/Institution/password/role gates;
- no body and `{}` accepted;
- query/non-empty/malformed/scalar/array input rejected;
- invalid/missing/foreign/other-Teacher/ended-membership Topic → 404;
- full active-Group lifecycle matrix;
- full archived-Group lifecycle matrix;
- real transition timestamps;
- same-state no-op timestamps;
- exact messages/resources;
- activation valid metadata/current material;
- no material, removed Material, removed File, wrong File category;
- invalid persisted required metadata;
- no Homework dependency;
- activation ignores physical storage existence;
- close/archive preserve materials/history;
- Resource serialization has no hidden queries.

### `TeacherTopicLifecycleConcurrencyTest`

Cover Section 14 with real PostgreSQL lock serialization, reusing the focused
worker style already present in Stage 5 tests.

Do not add generic concurrency infrastructure.

---

## 17. Directly Affected Regression Tests

Run exactly:

```text
tests/Feature/Teacher/TeacherTopicReadApiTest.php
tests/Feature/Teacher/TeacherTopicMutationApiTest.php
tests/Feature/Teacher/TeacherLearningMaterialMutationApiTest.php
tests/Feature/Authorization/RoleAuthorizationProductionRouteHygieneTest.php
```

Reasons:

- Topic route assertions after lifecycle routes;
- Topic metadata editability remains unchanged;
- Material mutation serialization remains correct;
- production routes remain role-protected.

Do not rerun `ApiErrorContractTest`, upload tests, or Docker checks unless the
implementation unexpectedly changes those areas.

---

## 18. Proportional Verification

From `backend/` unless noted.

```bash
./vendor/bin/pint --test
```

```bash
php artisan test   tests/Feature/Teacher/TeacherTopicLifecycleApiTest.php   tests/Feature/Teacher/TeacherTopicLifecycleConcurrencyTest.php
```

```bash
php artisan test   tests/Feature/Teacher/TeacherTopicReadApiTest.php   tests/Feature/Teacher/TeacherTopicMutationApiTest.php   tests/Feature/Teacher/TeacherLearningMaterialMutationApiTest.php   tests/Feature/Authorization/RoleAuthorizationProductionRouteHygieneTest.php
```

If host PHP lacks `pdo_pgsql`, run the same commands in repository Docker
PHP/PostgreSQL runtime.

Do not run full backend suite.
Do not run frontend/E2E.
Do not rebuild Docker.

From repository root:

```bash
git diff --check
git status --short
```

Then perform focused lifecycle/security/concurrency/diff self-review.

---

## 19. Allowed Change Scope

Expected production areas:

```text
backend/app/Actions/Teacher/
backend/app/Http/Controllers/Api/V1/Teacher/TeacherTopicController.php
backend/app/Http/Requests/Teacher/
backend/app/Support/Teacher/
backend/routes/api.php
```

Expected tests:

```text
backend/tests/Feature/Teacher/TeacherTopicLifecycleApiTest.php
backend/tests/Feature/Teacher/TeacherTopicLifecycleConcurrencyTest.php
```

Direct regression test files may be modified only if an obsolete route assertion
must be narrowed without weakening its original contract.

Do not change migrations, Composer files, Docker, frontend, docs, tasks,
Learning Material storage/file detection, Student APIs, or assessments.

---

## 20. Acceptance Criteria

S05-BE-004 is complete only when:

1. exact three lifecycle routes exist;
2. exact Teacher middleware applies;
3. lifecycle request input is strict;
4. Topic resolution is tenant/Teacher/current-membership safe;
5. out-of-scope targets are privacy-safe 404;
6. `draft → active` works;
7. `draft → archived` works;
8. `active → closed` works;
9. `closed → archived` works;
10. `active → archived` is rejected;
11. `closed → active` is rejected;
12. archived is terminal;
13. no endpoint returns Topic to draft;
14. activate same-state is idempotent only in active Group;
15. close same-state is idempotent in active/archived Group;
16. archive same-state is idempotent in active/archived Group;
17. no-op preserves `updated_at`;
18. real transitions set timestamps exactly once;
19. historical lifecycle timestamps are preserved;
20. activation requires active Group;
21. activation requires valid required metadata;
22. activation requires one current Material + current learning-material File;
23. activation does not require Homework;
24. activation does not depend on physical storage availability;
25. archived Group activation is rejected;
26. active Topic in archived Group can close;
27. draft/closed Topic in archived Group can archive;
28. ended Teacher membership revokes lifecycle access;
29. lifecycle never deletes Topic/material/history;
30. lock order is `Group → membership → Topic`;
31. activation material check serializes with S05-BE-003;
32. required race outcomes pass;
33. concurrent same-endpoint calls do not duplicate logical transitions;
34. existing TeacherTopicResource is reused safely;
35. exact success messages pass;
36. existing `topic_not_editable` error is reused;
37. no migration/dependency/frontend/Student/assessment scope is introduced;
38. focused tests pass;
39. direct regressions pass;
40. Pint passes;
41. `git diff --check` passes;
42. focused lifecycle/security/concurrency/diff review passes.

---

## 21. Focused Self-Review

Confirm before completion:

- status cannot be client-assigned;
- lifecycle routes are Teacher-role protected;
- Topic lookup is tenant/Teacher/current-membership scoped;
- state is not disclosed before authorization;
- archived Group behavior differs correctly for activate vs close/archive;
- activation readiness is under authoritative locks;
- removed/wrong-category Material/File cannot satisfy activation;
- physical storage existence is not activation authority;
- Homework is not required;
- no-op calls perform no write;
- timestamps do not regress;
- archive cannot skip close for active Topic;
- close/archive preserve metadata/material/history;
- lock order matches Group/membership/material Actions;
- races cannot stale-write lifecycle state;
- no unrelated API/schema/storage behavior changed;
- no test was weakened merely to accept new nested routes.

---

## 22. Delivery and Completion Report

Routine Git/GitHub delivery is owned by Project Owner.

Codex must not commit, push, open PR, or merge unless explicitly instructed
outside this contract.

Final report must include:

```text
S05-BE-004 IMPLEMENTATION COMPLETE
```

and:

- changed production files;
- changed test files;
- routes;
- lifecycle state matrix;
- activation prerequisites;
- archived-Group behavior;
- authorization/tenant behavior;
- idempotency/timestamp behavior;
- lock order;
- concurrency outcomes;
- focused test counts/assertions;
- direct regression counts/assertions;
- Pint;
- `git diff --check`;
- focused self-review;
- final Git state;
- exact blocker if incomplete.

---

# Final Implementation Rule

> Implement only the controlled Stage 5 Teacher Topic lifecycle. Laravel remains
> authoritative for Tenant/Teacher/current-membership scope, activation
> readiness, lifecycle timestamps, and concurrency. Archived Groups may complete
> historical `close`/`archive` lifecycle but may never activate new learning
> content.
