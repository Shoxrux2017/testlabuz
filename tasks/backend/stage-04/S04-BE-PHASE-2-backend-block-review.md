# Stage 4 Backend Phase 2 — Read-Only Block Review

## 1. Review Metadata

| Field | Value |
|---|---|
| Stage | `Stage 4 — Groups and User Relationships` |
| Block | Backend (`S04-BE-001` through `S04-BE-004`) |
| Status | `Approved` |
| Review mode | `Read-only` |
| Entry gate | `S04-BE-001`…`S04-BE-004` are all `Accepted` and `Delivered` on `origin/main` |
| Audited branch | `main` |
| Required repository state | local `main == origin/main`, ahead/behind `0/0`, clean worktree |
| Verdicts | `PASS` or `NOT ACCEPTED` |
| Next gate after PASS | Stage 4 frontend implementation |

This checkpoint reviews the complete delivered Stage 4 backend block as one integrated implementation surface.

It does not implement fixes, perform delivery, modify bookkeeping, or begin frontend work.

ChatGPT owns:

- review scope;
- architecture/security analysis;
- findings;
- severity;
- final verdict.

Codex may run the explicitly assigned read-only commands and tests below and return evidence. Codex must not make missing product, architecture, API, database, security, tenant, lifecycle, concurrency, or idempotency decisions.

---

## 2. Authoritative Inputs and Context Discipline

### ChatGPT/reviewer inputs

ChatGPT must reconcile:

- current `origin/main`;
- root `AGENTS.md`;
- `backend/AGENTS.md`;
- `tasks/README.md`;
- approved `STAGE_04_TASK_INDEX.md`;
- approved contracts `S04-BE-001` through `S04-BE-004`;
- relevant locked `docs/01–09`;
- current backend implementation and tests;
- accepted delivery evidence for all four backend tasks;
- Stage 3 closure evidence required only to establish the Stage dependency.

### Codex evidence-collection inputs

Codex may read only:

1. this review contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. current Stage 4 backend source/tests required to inspect the delivered block;
5. files needed to execute the explicitly required verification commands.

Codex must not reopen product specifications, roadmap/API/database/architecture documents, previous task files, Stage history, task indexes, or closure reviews to reinterpret requirements.

The requirements below are already resolved and self-contained for evidence collection.

---

## 3. Entry Conditions

Before any Phase 2 review command runs, verify all of the following:

| Condition | Required result |
|---|---|
| `S04-BE-001` | `Accepted / Delivered` |
| `S04-BE-002` | `Accepted / Delivered` |
| `S04-BE-003` | `Accepted / Delivered` |
| `S04-BE-004` | `Accepted / Delivered` |
| Accepted results | Present on `origin/main` |
| Local branch | `main` |
| `local main == origin/main` | Yes |
| Ahead/behind | `0/0` |
| Worktree | Clean |
| Origin | Expected TestLabUz repository |
| PostgreSQL test tooling | Available |

Required preflight commands from repository root:

```bash
git branch --show-current
git fetch --prune origin
git rev-parse main
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
git status --short
git remote -v
```

ChatGPT/orchestration must provide:

- the exact Stage 4 backend baseline SHA immediately before `S04-BE-001`;
- the expected current audited `origin/main` SHA.

Codex may verify those supplied SHAs against the current repository but must not derive Stage management decisions from Git history.

If a required entry condition fails, stop the checkpoint and report the blocker. The checkpoint does not receive `PASS`.

---

## 4. Strict Read-Only Boundary

During this checkpoint do not:

- edit, create, rename, or delete repository files;
- run auto-fix formatters;
- generate migrations, models, tests, snapshots, or documentation;
- install/update packages or lockfiles;
- alter application/environment configuration;
- stage or commit files;
- push or merge;
- open/update/merge a PR;
- modify task or Stage bookkeeping;
- fix a finding;
- begin frontend implementation.

Allowed:

- read-only Git inspection;
- `./vendor/bin/pint --test`;
- route inspection;
- static/read-only inspection commands;
- tests against the configured isolated PostgreSQL test database.

Do not manually run destructive database commands against development, staging, or production data.

If a supposedly read-only command unexpectedly changes a tracked repository file, stop, preserve evidence, and report the issue. Do not silently revert or clean it.

---

## 5. Reviewed Delta and Scope

Use the exact baseline SHA provided by ChatGPT/orchestration:

```bash
export STAGE4_BACKEND_BASELINE_SHA=<provided-exact-sha>
```

From repository root:

```bash
git diff --check "$STAGE4_BACKEND_BASELINE_SHA" origin/main
git diff --name-status "$STAGE4_BACKEND_BASELINE_SHA" origin/main
git diff --stat "$STAGE4_BACKEND_BASELINE_SHA" origin/main
git diff "$STAGE4_BACKEND_BASELINE_SHA" origin/main -- backend
```

The reviewed product delta must be backend-only except for separately approved task/delivery bookkeeping already present on `origin/main`.

Review every changed backend file in the Stage 4 delta.

Scope failures include:

- frontend code;
- unrelated product features;
- unapproved docs/spec changes;
- dependency/lockfile changes without an approved reason;
- CI/deployment changes unrelated to Stage 4;
- unrelated refactors or formatting churn;
- speculative infrastructure for later Stages.

---

## 6. Approved Persistence Surface — S04-BE-001

Review the delivered PostgreSQL/Eloquent foundation against these exact invariants.

### 6.1 Shared persistence rules

- UUID primary/foreign identifiers.
- Lifecycle and Laravel timestamps use PostgreSQL `timestamp with time zone`.
- `created_at` and `updated_at` are non-null.
- Explicit named foreign keys use `on delete restrict`.
- Historical relationships end through `ended_at`; normal application behavior never physically deletes them.
- Current relationship means exactly `ended_at is null`.
- Structural tenant consistency is enforced through composite foreign keys.
- Role correctness remains an application-layer concern.
- No soft deletes, PostgreSQL RLS, role-check triggers, or generic persistence abstraction.

### 6.2 User tenant support key

Required:

```text
users_institution_id_id_unique
```

on:

```text
users(institution_id, id)
```

It must preserve:

- the existing UUID primary key;
- existing User rows;
- Platform Owner rows with `institution_id = null`;
- the existing role/institution constraint.

### 6.3 Groups

Required columns:

```text
id
institution_id
name
level
subject_direction
description
status
created_by_user_id
archived_at
created_at
updated_at
```

Required status values:

```text
active
archived
```

Required named objects:

```text
groups_name_not_empty_check
groups_status_check
groups_status_archived_at_check
groups_institution_id_foreign
groups_institution_creator_foreign
groups_institution_id_id_unique
groups_institution_status_index
groups_institution_lower_name_index
```

Group names are intentionally not unique.

### 6.4 Historical relationship tables

Required:

```text
group_teacher_memberships
group_student_memberships
parent_student_relationships
```

Required behavior:

- tenant-owned UUID row;
- same-tenant Group/User/actor references;
- `started_at` non-null;
- `ended_at` nullable;
- `ended_at is null or ended_at >= started_at`;
- historical ended rows remain;
- multiple historical rows per pair are allowed;
- at most one current row per pair.

Required current partial unique indexes:

```text
group_teacher_memberships_current_unique
group_student_memberships_current_unique
parent_student_relationships_current_unique
```

Required query indexes must support tenant + target/group + `ended_at` lookup shapes.

### 6.5 Rollback/migration safety

Review that:

- migrations are forward-only;
- delivered Stage 0–3 migrations were not rewritten;
- relationship tables drop before dependent Group/User support constraints;
- `users_institution_id_id_unique` is removed only after Stage 4 relationship dependencies are gone;
- PostgreSQL-specific behavior is covered by real PostgreSQL tests.

### 6.6 Models/factories

Required:

- `GroupStatus` exactly `active|archived`;
- UUID models;
- explicit writable attributes;
- datetime casts;
- `Group.status` enum cast;
- focused owned relationships;
- User inverse names:
  - `teacherGroupMemberships`;
  - `studentGroupMemberships`;
  - `parentStudentRelationships`;
  - `studentParentRelationships`;
- no actor-side inverse relationships for creator/assigner/connector;
- no `BelongsToMany` shortcuts hiding historical rows;
- `current` scope means only `ended_at is null`;
- factories default to same-Institution, role-correct valid records;
- explicit test overrides are preserved.

---

## 7. Approved HTTP Surface — 15 Routes

Exactly these Stage 4 Institution Admin routes are approved.

### 7.1 Group management — 5

```text
GET    /api/v1/institution/groups
POST   /api/v1/institution/groups
GET    /api/v1/institution/groups/{group}
PATCH  /api/v1/institution/groups/{group}
POST   /api/v1/institution/groups/{group}/archive
```

### 7.2 Teacher/Student membership — 6

```text
GET    /api/v1/institution/groups/{group}/teachers
POST   /api/v1/institution/groups/{group}/teachers
DELETE /api/v1/institution/groups/{group}/teachers/{teacher}

GET    /api/v1/institution/groups/{group}/students
POST   /api/v1/institution/groups/{group}/students
DELETE /api/v1/institution/groups/{group}/students/{student}
```

### 7.3 Parent–Student relationships — 4

```text
GET    /api/v1/institution/parents/{parent}/students
GET    /api/v1/institution/students/{student}/parents
POST   /api/v1/institution/parent-student-relationships
DELETE /api/v1/institution/parent-student-relationships/{relationship}
```

All routes must remain inside the existing Institution Admin middleware chain:

```text
auth:sanctum
-> active.account
-> password.changed
-> role:institution_admin
```

No Stage 4 route may use implicit route-model binding in a way that resolves institution-owned resources before tenant-safe scoping.

Unapproved route families include:

```text
/api/v1/institution/parent-student-connections
/api/v1/institution/parent-student-connections/{parent}/{student}
```

No candidate/history/self-service/reactivation/hard-delete/later-stage routes are approved.

---

## 8. Group Management Contract — S04-BE-002

### 8.1 Resource

Exact keys:

```text
id
name
level
subject_direction
description
status
teachers_count
students_count
archived_at
created_at
updated_at
```

Rules:

- current membership counts use `ended_at is null`;
- inactive related Users still count while membership remains current;
- Resources issue no queries;
- timestamps are whole-second UTC RFC 3339;
- protected/internal fields are absent.

### 8.2 List

Only:

```text
search
status
page
per_page
sort
direction
```

- literal escaped PostgreSQL `ILIKE` on name/level/subject direction;
- name sort is case-insensitive;
- other allowed sorts: `status`, `created_at`, `updated_at`;
- UUID final deterministic tiebreaker in requested direction;
- pagination default `1/20`, max `100`;
- tenant scope precedes filter/search/sort/pagination/counts;
- query count remains bounded.

### 8.3 Create

- strict JSON object;
- exact allowed writable fields;
- normalized name/optionals;
- derived `institution_id` and creator;
- `active`, `archived_at = null`;
- duplicate Group names allowed;
- `201`;
- message:

```text
Group created successfully.
```

### 8.4 Update

- strict non-empty partial JSON;
- tenant-scoped `FOR UPDATE`;
- archived Group conflicts before no-op comparison;
- exact no-op emits no SQL UPDATE and preserves `updated_at`;
- real update changes only supplied fields;
- `200`;
- message:

```text
Group updated successfully.
```

### 8.5 Archive

- no body or `{}`;
- tenant-scoped `FOR UPDATE`;
- only `active -> archived`;
- first transition sets `archived_at`;
- memberships remain unchanged;
- repeated archive is a no-write idempotent `200`;
- Archive/Update races serialize through the same Group row;
- message:

```text
Group archived successfully.
```

---

## 9. Teacher/Student Membership Contract — S04-BE-003

### 9.1 List resources

Teacher and Student list items expose exactly:

```text
id
full_name
login_name
email
phone
is_active
started_at
```

`id` is the related User UUID, not membership UUID.

Rules:

- current only;
- inactive Users included unless filtered;
- search across name/login/email/phone with literal escaped `ILIKE`;
- sort `full_name|started_at`;
- deterministic User UUID tiebreaker;
- archived Groups remain readable;
- Resources issue no queries;
- no membership/tenant/assigner/internal fields leak.

### 9.2 Bulk Teacher Assign

Exact body:

```json
{
  "teacher_ids": [
    "uuid-1",
    "uuid-2"
  ]
}
```

### 9.3 Bulk Student Assign

Exact body:

```json
{
  "student_ids": [
    "uuid-1",
    "uuid-2"
  ]
}
```

Required bulk semantics:

- endpoint-specific array only;
- 1–100 UUIDs;
- duplicate UUIDs inside one request are rejected;
- whole request is atomic;
- every target must be same-Institution and exact endpoint role;
- target Users are locked in ascending UUID order;
- Group is locked before Users;
- current memberships are locked after Users;
- already-current requested memberships are write-free no-ops, even if User later became inactive;
- missing membership + inactive target blocks the whole batch with `409 business_conflict`;
- mixed current/new batch creates only missing memberships;
- any invalid/wrong-role/cross-tenant/inactive-missing target produces no partial creation;
- response order matches request order;
- at least one creation -> `201`;
- all-current batch -> `200`;
- newly created rows derive Institution/assigner from authenticated Institution Admin.

Messages:

```text
Teachers assigned to group successfully.
Students assigned to group successfully.
```

### 9.4 Remove

DELETE remains single-target:

```text
/groups/{group}/teachers/{teacher}
/groups/{group}/students/{student}
```

Required:

- no body/query;
- tenant + endpoint-role resolution;
- archived Group rejects mutation;
- current row gets one `ended_at` write;
- repeated removal is `204` with no write;
- inactive current User remains removable;
- re-assignment later creates a new historical row.

### 9.5 Concurrency

Review:

- identical bulk Assign;
- overlapping bulk Assign;
- duplicate Remove;
- Assign→Remove;
- Remove→Assign;
- membership→Archive;
- Archive→membership;
- User deactivation→Assign;
- Assign→User deactivation;
- different Groups with overlapping User sets use the same ascending User UUID order.

No normal uniqueness exception or deadlock may be the intended API behavior.

---

## 10. Parent–Student Relationship Contract — S04-BE-004

### 10.1 Public relationship resource

Exact keys:

```text
id
parent_id
student_id
started_at
ended_at
```

Rules:

- `id` is the relationship UUID and is public;
- current list items have `ended_at = null`;
- timestamps are whole-second UTC RFC 3339;
- no `institution_id`, connector, created/updated timestamps, credentials, or User-internal fields.

### 10.2 Parent → Students

```text
GET /api/v1/institution/parents/{parent}/students
```

Required:

- path resolves same-Institution `role = parent`;
- current relationships only;
- related User exact `role = student`;
- optional related Student `status`;
- search related Student name/login/email/phone;
- sort `full_name|started_at`;
- deterministic relationship UUID tiebreaker;
- bounded query count.

### 10.3 Student → Parents

```text
GET /api/v1/institution/students/{student}/parents
```

Same contract with Parent/Student roles reversed.

### 10.4 Connect

```text
POST /api/v1/institution/parent-student-relationships
```

Exact body:

```json
{
  "parent_id": "uuid",
  "student_id": "uuid"
}
```

Required:

- same-Institution exact roles;
- Users locked in ascending UUID order;
- exact current relationship locked after Users;
- current existing relationship -> write-free `200`;
- absent pair requires both Users active;
- first creation -> `201`;
- derive Institution/connector from authenticated Institution Admin;
- ended historical row is never revived;
- reconnect creates a new relationship UUID;
- many Parents per Student and many Students per Parent are allowed.

Message:

```text
Parent and student connected successfully.
```

### 10.5 Disconnect by relationship UUID

```text
DELETE /api/v1/institution/parent-student-relationships/{relationship}
```

Required:

- relationship ID is tenant-scoped and existence-private;
- no query/body;
- use deterministic User lock order before relationship lock;
- current relationship gets one `ended_at` write;
- already-ended in-scope relationship is a write-free `204` no-op;
- inactive Users remain disconnectable;
- no row is physically deleted.

### 10.6 Concurrency

Review:

- duplicate Connect;
- duplicate Disconnect;
- Connect→Disconnect;
- Disconnect→Connect;
- overlapping pairs sharing one User;
- disjoint pairs;
- User deactivation/Connect both lock orders.

---

## 11. Cross-Cutting Security, Validation, and Errors

Review all Stage 4 endpoints for:

- Institution scope derived only from authenticated Institution Admin;
- no client-supplied tenant authority;
- unauthenticated denial;
- inactive actor/institution denial;
- mandatory first-login password gate;
- wrong-role denial;
- cross-tenant existence privacy;
- valid UUID not granting access;
- strict unknown query/body-key rejection;
- correct request content type/root validation;
- protected-field rejection;
- safe `404 resource_not_found`;
- safe `422 validation_failed`;
- safe `409 business_conflict`;
- no SQL/internal class/credential/token leakage;
- centralized error mapping only.

Required Stage 4 conflict mappings:

```text
GroupArchivedException
-> 409
-> business_conflict
-> The group is archived.

InactiveGroupMemberException
-> 409
-> business_conflict
-> The selected user is inactive.

InactiveParentStudentRelationshipUserException
-> 409
-> business_conflict
-> The selected parent or student is inactive.
```

Do not accept the obsolete name:

```text
InactiveParentStudentConnectionUserException
```

No new stable machine code is approved for these conflicts.

---

## 12. Architecture and Responsibility Review

Confirm:

- Controllers are thin.
- Form Requests own only request-shape validation.
- Requests do not query persisted state.
- Actions own tenant/role resolution, filtering/sorting, transactions, locks, lifecycle decisions, and persistence.
- Models own relationships/casts/scopes, not workflow orchestration.
- Resources serialize preloaded state and issue no queries.
- Result objects explicitly communicate create-vs-existing outcome where Controllers need `201` vs `200`.
- No endpoint-local error envelope exists.
- No generic repository/service layer was introduced without an approved need.
- No polymorphic relationship abstraction hides the concrete Stage 4 domain.
- No `BelongsToMany` shortcut hides historical membership/relationship rows.
- Query shapes are bounded and avoid N+1.
- Sort values are allowlisted.
- Search values are parameterized and wildcard-escaped.
- lifecycle decisions use fresh locked rows;
- no-op paths issue no unnecessary INSERT/UPDATE;
- partial unique indexes remain integrity backstops rather than ordinary control flow.

---

## 13. Required Test Inventory

Expected new Stage 4 tests:

### Persistence

```text
tests/Feature/Persistence/GroupRelationshipSchemaInspectionTest.php
tests/Feature/Persistence/GroupRelationshipPersistenceTest.php
tests/Feature/Persistence/GroupRelationshipFactoryModelTest.php
```

### Group management

```text
tests/Feature/Institution/InstitutionGroupReadApiTest.php
tests/Feature/Institution/InstitutionGroupCreateUpdateApiTest.php
tests/Feature/Institution/InstitutionGroupLifecycleApiTest.php
```

### Teacher/Student memberships

```text
tests/Feature/Institution/InstitutionGroupTeacherMembershipApiTest.php
tests/Feature/Institution/InstitutionGroupStudentMembershipApiTest.php
tests/Feature/Institution/InstitutionGroupMembershipConcurrencyTest.php
```

### Parent–Student relationships

```text
tests/Feature/Institution/InstitutionParentStudentsApiTest.php
tests/Feature/Institution/InstitutionStudentParentsApiTest.php
tests/Feature/Institution/InstitutionParentStudentRelationshipMutationApiTest.php
tests/Feature/Institution/InstitutionParentStudentRelationshipConcurrencyTest.php
```

Also review:

```text
tests/Feature/ApiErrorContractTest.php
```

for compatibility with centralized Stage 4 mappings.

### Test-quality requirements

Blocking weaknesses include:

- critical Stage 4 behavior untested;
- skipped critical cases;
- SQLite-only proof for PostgreSQL-specific invariants;
- arbitrary sleeps in concurrency tests;
- race tests that assert only HTTP response but not persisted final state;
- query-count tests that do not grow result size;
- no-op tests that do not verify write absence/timestamp stability;
- cross-tenant tests missing for new institution-owned endpoints;
- tests weakened merely to make implementation pass.

---

## 14. Required Verification

Run from `backend/`:

```bash
./vendor/bin/pint --test
php artisan route:list --path=api/v1/institution
php artisan test
```

Required:

- Pint exits zero and modifies nothing.
- Route output contains all 15 approved Stage 4 routes.
- Route output contains no obsolete `/parent-student-connections` route family.
- Route output shows no unintended Stage 4 route.
- Full backend suite passes against configured PostgreSQL test environment.
- No critical Stage 4 test is skipped.

If the backend has an already-configured non-mutating strict/static command that is part of the accepted project baseline, run it as well and record the exact result. Do not invent or add new tooling during this review.

Then from repository root:

```bash
git diff --check "$STAGE4_BACKEND_BASELINE_SHA" origin/main
git status --short
```

Final `git status --short` must remain empty.

---

## 15. Previous-Stage Regression Review

Explicitly review regression risk to Stages 1–3:

- authentication and logout;
- current-user/password gate;
- platform Institution management;
- Institution Admin dashboard/profile;
- Institution User list/detail/create/update/lifecycle;
- Institution assessment settings;
- understanding-category persistence/API;
- centralized API error envelopes.

The full backend suite is primary regression evidence, but inspect any shared Stage 4 modifications to:

```text
routes/api.php
bootstrap/app.php
ApiErrorResponse.php
User.php
Institution.php
```

for unintended behavior changes.

---

## 16. Findings Severity

Use only:

### `P1`

Security, tenant isolation, secret exposure, data loss/corruption, or core public-contract breach.

Examples:

- cross-Institution access;
- wrong relationship visibility;
- missing tenant composite integrity;
- broken public route/body/resource contract;
- destructive history handling;
- unsafe migration;
- sensitive data exposure.

### `P2`

Material functional, architecture, lifecycle, concurrency, query, or regression defect that blocks the checkpoint.

Examples:

- wrong idempotency/no-op semantics;
- concurrency contract not preserved;
- N+1/unbounded query;
- strict validation gap;
- missing critical negative/concurrency coverage;
- material architecture/layering violation;
- full backend regression failure attributable to Stage 4.

### `P3`

Non-blocking maintainability, clarity, or test-quality improvement with no current security/contract/functional impact.

Do not invent findings merely to populate a severity level.

For every finding record:

- ID;
- severity;
- concise title;
- exact file/location;
- evidence;
- violated approved behavior;
- concrete impact;
- minimal remediation direction.

---

## 17. Verdict

Use exactly one:

```text
PASS
NOT ACCEPTED
```

### PASS requires

- all entry conditions pass;
- complete backend Stage 4 scope was reviewed;
- `P1 = 0`;
- `P2 = 0`;
- full backend verification passes;
- route surface matches exactly;
- no unresolved persistence/API/security/tenant/lifecycle/concurrency/cross-task conflict remains;
- no unexplained repository change was created during review.

`P3` may accompany PASS when clearly non-blocking.

### NOT ACCEPTED

Use when:

- any `P1` or `P2` exists;
- required verification fails because of candidate implementation;
- a required Stage 4 criterion lacks sufficient evidence;
- entry conditions do not permit a valid checkpoint;
- the review cannot establish the required safety/correctness boundary.

Do not fix findings during this checkpoint.

If NOT ACCEPTED:

1. preserve review evidence;
2. ChatGPT prepares focused fix contract(s);
3. Codex implements/verifies/delivers the fixes;
4. affected checkpoint checks are rerun;
5. obtain `PASS` before frontend implementation proceeds.

---

## 18. Required Evidence Report From Codex

Codex returns evidence only; ChatGPT assigns findings/severity and final checkpoint verdict.

Required report:

1. **Repository preflight**
   - branch;
   - local main SHA;
   - origin/main SHA;
   - ahead/behind;
   - clean status;
   - supplied baseline SHA match.

2. **Delta inventory**
   - changed Stage 4 backend files;
   - unexplained scope, if any.

3. **Route evidence**
   - all 15 approved Stage 4 routes;
   - confirmation obsolete routes are absent.

4. **Persistence evidence**
   - required tables/constraints/indexes;
   - migration/rollback safety observations.

5. **API/security evidence**
   - tenant/role/existence-privacy observations;
   - strict request/resource/error behavior.

6. **Concurrency/idempotency evidence**
   - Group races;
   - bulk membership races;
   - Parent–Student relationship races;
   - User lifecycle interactions.

7. **Verification**
   - exact commands;
   - exit status;
   - full test totals/assertions;
   - skipped tests, if any.

8. **Final repository state**
   - `git diff --check` result;
   - final `git status --short`;
   - explicit statement that no file was modified/staged/committed/pushed/merged.

Codex must not output `PASS` or `NOT ACCEPTED` as the authoritative Phase 2 verdict. It may state whether evidence collection completed successfully or was blocked.

---

## 19. ChatGPT Final Review Record

ChatGPT produces the checkpoint record in this order:

1. **Verdict:** `PASS` or `NOT ACCEPTED`;
2. findings ordered by `P1`, `P2`, `P3`, or explicit `No findings`;
3. audited `origin/main` SHA and Stage 4 backend baseline SHA;
4. block inventory `S04-BE-001`…`S04-BE-004`;
5. persistence/schema assessment;
6. API/security/tenant assessment;
7. lifecycle/concurrency/idempotency/query assessment;
8. previous-Stage regression assessment;
9. exact verification evidence;
10. final Git cleanliness;
11. next gate.

If verdict is `PASS`, the next permitted gate is:

```text
Stage 4 frontend implementation
```

Backend delivery is already complete before this checkpoint and must not be repeated.

This Phase 2 review does not authorize Stage integration or Stage closure.
