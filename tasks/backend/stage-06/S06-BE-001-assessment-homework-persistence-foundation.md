# Codex Implementation Contract: S06-BE-001 — Assessment and Homework Persistence Foundation

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S06-BE-001` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Area | `Backend` |
| Status | `Accepted` |
| Implementation type | `Laravel/PostgreSQL persistence foundation` |
| Depends on | `Stage 5 CLOSED`; Stage 6 decomposition approved |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |
| Delivery | `Delivered — PR #143` |
| Delivered merge | `ab9c826b626891d119d5c8f674dff212ebe7a806` |
| Acceptance review | `PASS — P1=0, P2=0, P3=0` |
| Block checkpoint | Stage 6 Backend Phase 2 after `S06-BE-001…006` are `Accepted / Delivered` |

Start only when this task remains `Approved`, Stage 5 remains explicitly closed, the current implementation baseline has been re-checked by ChatGPT, and Git preflight is safe.

This file is the complete task-specific implementation contract. Do not create a duplicate `CODEX-PROMPT` file.

---

## 2. Implementation Authority and Context Discipline

Codex may read only:

1. this implementation contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. existing backend source, migrations, models, factories, and tests directly required to implement this task.

Do **not** read product specifications, roadmap files, architecture/database/API documents, Stage indexes, closure reviews, previous task files, or Stage history to determine what to implement.

The requirements below already resolve the relevant Stage 6 product, database, lifecycle, tenant, history, and future-stage compatibility decisions.

If the current implementation materially conflicts with this contract, return `BLOCKED` with the exact conflict. Do not redesign the schema or make a product/security/lifecycle decision independently.

A newer `origin/main` than the planning baseline is allowed only after ChatGPT has re-checked it and confirmed this contract remains implementation-ready.

---

## 3. Goal

Create the PostgreSQL and Eloquent persistence foundation required for Stage 6 Homework authoring and for the later Student-attempt lifecycle to attach safely without redesigning the Stage 6 schema.

The task must introduce structural storage for:

- shared Assessments;
- Homework-specific lifecycle/deadline data;
- Assessment recipient snapshots;
- structural Assessment Attempts;
- the staged Topic official-result pair.

The result must provide:

- direct Institution ownership on high-risk rows;
- same-Institution foreign-key protection;
- same-Topic protection for official-pair assessment references;
- database-enforced structural enum/numeric/lifecycle invariants where practical;
- explicit Eloquent models and relationships;
- deterministic same-Institution factories;
- focused PostgreSQL schema/persistence/model tests.

This task exposes **no HTTP/API behavior** and implements **no Student attempt execution**.

---

## 4. Scope

### 4.1 Included

Implement only:

- one or more new forward-only Stage 6 migrations required by this contract;
- `assessments`;
- `homework_assignments`;
- `assessment_students`;
- `assessment_attempts`;
- `topic_result_pairs`;
- enums required for the persisted machine values below;
- Eloquent models for the five new persistence concepts;
- required inverse relationships on existing `Institution`, `Topic`, and `User` models;
- factories for the five new models;
- explicit PostgreSQL foreign keys, support uniqueness, business uniqueness, checks, and indexes defined below;
- focused schema-inspection, persistence-invariant, and factory/model tests.

### 4.2 Shared future structural support intentionally created now

The shared `assessments` base table must support:

```text
homework
blitz
```

even though Stage 6 implements only Homework behavior.

The structural `assessment_attempts` table must support the locked future attempt/finalization machine values required by later stages, but this task must not expose or implement any attempt start/save/submit/finalize/scoring action.

The staged `topic_result_pairs` table must support Stage 6 official Homework designation before a Blitz exists:

```text
homework_assessment_id = required
blitz_assessment_id    = nullable until the later Blitz stage
```

This is an intentional Stage 6 sequencing contract, not a temporary workaround.

---

## 5. Explicit Non-Goals

Do not add or change:

- routes;
- controllers;
- Form Requests;
- API Resources;
- Actions/use cases;
- authorization policies/services;
- middleware;
- public API responses;
- Teacher Homework API;
- Teacher Group Student roster API;
- Question authoring APIs;
- Question persistence tables;
- Question validation/checking logic;
- Homework create/update business actions;
- Homework activation/close/archive actions;
- recipient snapshot population logic;
- official Homework designation/read API;
- Student Homework list/detail;
- Student Attempt start/read/save/submit endpoints;
- deadline reconciliation or Laravel Scheduler behavior;
- automatic deadline finalization;
- task-close attempt finalization;
- automatic/manual answer checking;
- scoring or official-score resolution;
- Student submission files;
- Blitz creation/lifecycle/timing/exception behavior;
- Topic result calculation;
- result release;
- seed/demo/E2E data;
- frontend code;
- dependencies;
- `docs/01–09`;
- task/Stage bookkeeping;
- unrelated refactors.

Do not:

- edit already-delivered migrations when a forward migration is appropriate;
- introduce soft deletes;
- introduce PostgreSQL RLS;
- add database triggers for role, current membership, Assessment type, assignment eligibility, scoring, or lifecycle orchestration;
- add a generic repository/service framework;
- put workflow or authorization logic into Eloquent models.

---

## 6. Shared Persistence Conventions

Use the repository’s established Laravel/PostgreSQL conventions.

Required:

- domain IDs use PostgreSQL `uuid`;
- authoritative instants use PostgreSQL `timestamp with time zone`;
- `created_at` and `updated_at` are non-null;
- foreign keys use explicit stable names;
- all foreign keys introduced by this task use `ON DELETE RESTRICT`;
- high-risk institution-owned references use same-Institution composite foreign keys where the required support key exists;
- add only the composite support unique keys actually needed by the same-Institution/same-Topic references below;
- structural invariants belong in PostgreSQL where practical;
- role/current-membership/Assessment-type/recipient-eligibility semantics remain application-layer rules for later Stage 6 tasks;
- migrations must be PostgreSQL-safe and rollback-safe;
- no client/API assumptions belong in migrations.

Existing Stage 5 `topics` already provides the tenant/topic parent used by this task. Do not weaken or reinterpret existing Topic/Learning Material constraints.

---

# 7. `assessments` Persistence Contract

`assessments` stores common authoring identity/metadata for Homework and future Blitz tasks.

## 7.1 Columns

| Column | Type | Null | Contract |
|---|---|---:|---|
| `id` | uuid | no | Primary key |
| `institution_id` | uuid | no | Direct tenant owner |
| `topic_id` | uuid | no | Same-Institution Topic |
| `teacher_id` | uuid | no | Same-Institution owning User; Teacher role is later application validation |
| `type` | varchar(20) | no | `homework|blitz` |
| `title` | varchar(255) | no | Non-empty after PostgreSQL `btrim` |
| `description` | text | yes | Optional |
| `student_instructions` | text | no | Non-empty after PostgreSQL `btrim` |
| `assignment_mode` | varchar(32) | no | `group|selected_students` |
| `total_possible_points` | numeric(14,6) | no | Explicit persisted total; draft may be `0` |
| `created_at` | timestamptz | no | Laravel timestamp |
| `updated_at` | timestamptz | no | Laravel timestamp |

Do not add:

```text
attempt_limit
normal_attempts
official_score
group_id
institution-selecting client fields
```

The Group context is inherited through the owning Topic.

## 7.2 Required support keys

Require:

```text
unique(institution_id, id)
unique(institution_id, topic_id, id)
```

Use explicit stable names.

The second key exists so `topic_result_pairs` can use a composite same-Institution + same-Topic foreign key to each official Assessment candidate.

## 7.3 Required checks

Use explicit named PostgreSQL checks with these semantics:

```text
type in ('homework', 'blitz')
assignment_mode in ('group', 'selected_students')
btrim(title) <> ''
btrim(student_instructions) <> ''
total_possible_points >= 0
```

`total_possible_points = 0` is structurally valid for draft authoring. Stage 6 activation will later recalculate the current Question total transactionally and require it to be greater than zero.

## 7.4 Required foreign keys

All `ON DELETE RESTRICT`:

```text
institution_id
  -> institutions.id

(institution_id, topic_id)
  -> topics(institution_id, id)

(institution_id, teacher_id)
  -> users(institution_id, id)
```

Do not add role-checking triggers.

## 7.5 Required indexes

```text
(institution_id, topic_id, type)
(institution_id, teacher_id, type)
```

Use explicit stable index names.

---

# 8. `homework_assignments` Persistence Contract

`homework_assignments` stores only Homework-specific lifecycle and deadline state.

It uses composition with `assessments`; it must not duplicate common title/topic/teacher/assignment/points fields.

## 8.1 Columns

| Column | Type | Null | Contract |
|---|---|---:|---|
| `assessment_id` | uuid | no | Primary key + Assessment reference |
| `institution_id` | uuid | no | Direct tenant owner |
| `status` | varchar(20) | no | `draft|active|closed|archived` |
| `deadline_at` | timestamptz | yes | Optional authoritative absolute instant |
| `activated_at` | timestamptz | yes | Lifecycle timestamp |
| `closed_at` | timestamptz | yes | Lifecycle timestamp |
| `archived_at` | timestamptz | yes | Lifecycle timestamp |
| `created_at` | timestamptz | no | Laravel timestamp |
| `updated_at` | timestamptz | no | Laravel timestamp |

There is deliberately **no `attempt_limit` column**.

The fixed MVP Homework rule is:

```text
normal attempts = 3
```

but attempt availability is later application/domain behavior, not a mutable persistence setting.

## 8.2 Required support key

Require:

```text
unique(institution_id, assessment_id)
```

in addition to `assessment_id` being the primary key.

## 8.3 Required checks

Status:

```text
status in ('draft', 'active', 'closed', 'archived')
```

Lifecycle shape:

```text
draft:
  activated_at is null
  closed_at is null
  archived_at is null

active:
  activated_at is not null
  closed_at is null
  archived_at is null

closed:
  activated_at is not null
  closed_at is not null
  archived_at is null

archived:
  archived_at is not null
  AND either:
    activated_at is null and closed_at is null
  OR
    activated_at is not null and closed_at is not null
```

This structurally permits only the intended historical shapes:

```text
draft
draft -> archived
draft -> active
draft -> active -> closed
draft -> active -> closed -> archived
```

It structurally rejects an archived record representing direct:

```text
active -> archived
```

Timestamp ordering when applicable:

```text
activated_at >= created_at
closed_at >= activated_at
archived_at >= created_at
archived_at >= closed_at when closed_at is not null
```

Do not add a database check requiring `deadline_at` to be in the future. Deadline eligibility depends on authoritative request-time state and belongs to a later Action.

## 8.4 Required foreign key

Use one same-Institution composite FK:

```text
(institution_id, assessment_id)
  -> assessments(institution_id, id)
  ON DELETE RESTRICT
```

The database does not need a trigger to assert `assessments.type = 'homework'`; that is mandatory application validation in later Stage 6 behavior.

## 8.5 Required index

```text
(institution_id, status, deadline_at)
```

---

# 9. `assessment_students` Persistence Contract

`assessment_students` is the persisted recipient snapshot relation.

Rows mean:

> this Student is a recipient of this Assessment.

Later Group membership changes must not rewrite a persisted active-task recipient snapshot.

This task creates the storage only; it does not decide/populate recipients from current memberships.

## 9.1 Columns

| Column | Type | Null | Contract |
|---|---|---:|---|
| `id` | uuid | no | Primary key |
| `institution_id` | uuid | no | Direct tenant owner |
| `assessment_id` | uuid | no | Same-Institution Assessment |
| `student_id` | uuid | no | Same-Institution User; Student role is later application validation |
| `assignment_source` | varchar(20) | no | `group|direct` |
| `assigned_at` | timestamptz | no | Server-authoritative assignment/snapshot instant |
| `assigned_by_user_id` | uuid | no | Same-Institution actor; Teacher authorization is later application validation |
| `created_at` | timestamptz | no | Laravel timestamp |
| `updated_at` | timestamptz | no | Laravel timestamp |

## 9.2 Required support key

```text
unique(institution_id, id)
```

## 9.3 Required uniqueness

A Student may appear only once in one Assessment recipient snapshot:

```text
unique(assessment_id, student_id)
```

## 9.4 Required check

```text
assignment_source in ('group', 'direct')
```

Interpretation for later application behavior:

```text
assignment_mode = group
  -> assignment_source = group

assignment_mode = selected_students
  -> assignment_source = direct
```

Do not enforce that cross-table semantic with a trigger in this task.

## 9.5 Required foreign keys

All `ON DELETE RESTRICT`:

```text
institution_id
  -> institutions.id

(institution_id, assessment_id)
  -> assessments(institution_id, id)

(institution_id, student_id)
  -> users(institution_id, id)

(institution_id, assigned_by_user_id)
  -> users(institution_id, id)
```

## 9.6 Required indexes

```text
(institution_id, student_id, assessment_id)
(institution_id, assessment_id)
```

---

# 10. `assessment_attempts` Structural Persistence Contract

`assessment_attempts` stores every future Student try as an independent historical row.

Stage 6 does **not** expose attempt creation or mutation. The table exists now because:

- Stage 6 editing integrity/designation locking is defined against existence of Student activity;
- Stage 7 must attach to a stable persistence contract without redesigning Stage 6 history semantics.

## 10.1 Columns

| Column | Type | Null | Contract |
|---|---|---:|---|
| `id` | uuid | no | Primary key |
| `institution_id` | uuid | no | Direct tenant owner |
| `assessment_id` | uuid | no | Same-Institution Assessment |
| `assessment_student_id` | uuid | no | Same-Institution recipient relation |
| `student_id` | uuid | no | Same-Institution User |
| `attempt_number` | smallint | no | Sequential attempt number |
| `status` | varchar(40) | no | Stored attempt state |
| `started_at` | timestamptz | no | Server-authoritative start |
| `deadline_at` | timestamptz | yes | Future effective Blitz deadline snapshot; Homework normally null |
| `submitted_at` | timestamptz | yes | Explicit Student submit time |
| `finalized_at` | timestamptz | yes | Explicit or server-authoritative finalization time |
| `finalization_reason` | varchar(40) | yes | Stable machine reason |
| `locked_at` | timestamptz | yes | Answer-set immutability instant |
| `official_score_eligible` | boolean | no | Default `true` |
| `earned_points` | numeric(16,8) | yes | Null until applicable scoring state |
| `possible_points` | numeric(14,6) | no | Assessment-points snapshot |
| `normalized_score` | numeric(12,8) | yes | High-precision 0–100 score |
| `scoring_completed_at` | timestamptz | yes | Scoring completion |
| `created_at` | timestamptz | no | Laravel timestamp |
| `updated_at` | timestamptz | no | Laravel timestamp |

## 10.2 Required support key

```text
unique(institution_id, id)
```

## 10.3 Required stored statuses

Exactly:

```text
in_progress
submitted
timed_out_finalized
waiting_for_teacher_review
checked
```

Do not persist:

```text
not_started
not_completed
```

`not_started` is derived from a recipient row with no Attempt. `not_completed` is a later task/result business outcome.

## 10.4 Required finalization reasons

When non-null, exactly:

```text
student_submit
timeout_auto_submit
task_closed_auto_finalize
homework_deadline_auto_submit
```

## 10.5 Required checks

```text
attempt_number >= 1
attempt_number <= 3
possible_points >= 0
```

When non-null:

```text
0 <= normalized_score <= 100
0 <= earned_points <= possible_points
```

Timestamp ordering when the dependent timestamp exists:

```text
submitted_at >= started_at
finalized_at >= started_at
locked_at >= started_at
scoring_completed_at >= started_at
```

Do **not** add a task-type trigger that attempts to enforce Homework versus Blitz attempt-count policy in PostgreSQL.

Later application/domain validation must enforce:

```text
Homework -> attempt numbers 1..3
Blitz    -> normally attempt #1, future approved exception may permit #2
```

The database-level upper bound of `3` is a structural hard ceiling shared by the current MVP schema; it is not a client-configurable limit.

Do not over-constrain future status transitions with speculative cross-column checks beyond the explicit rules above.

## 10.6 Required uniqueness

```text
unique(assessment_id, student_id, attempt_number)
```

Concurrent attempt-number allocation is later application/transaction behavior.

## 10.7 Required foreign keys

All `ON DELETE RESTRICT`:

```text
institution_id
  -> institutions.id

(institution_id, assessment_id)
  -> assessments(institution_id, id)

(institution_id, assessment_student_id)
  -> assessment_students(institution_id, id)

(institution_id, student_id)
  -> users(institution_id, id)
```

The database must reject cross-Institution FK combinations.

The semantic invariant:

```text
assessment_student_id
must represent the same assessment_id + student_id
```

is mandatory later application/domain validation. Do not introduce a trigger in this persistence-only task.

## 10.8 Required indexes

```text
(institution_id, student_id, assessment_id)
(institution_id, assessment_id, status)
(assessment_student_id, attempt_number)
(status, finalized_at)
(institution_id, deadline_at, status)
```

---

# 11. `topic_result_pairs` Staged Persistence Contract

This table stores the official Topic assessment relationship.

The full MVP result eventually uses:

```text
1 whole-group official Homework
+
1 whole-group official Blitz
```

Stage 6 occurs before Blitz implementation, so the persistence contract is intentionally staged.

## 11.1 Stage 6 staged rule

A valid Stage 6 row has:

```text
homework_assessment_id = required
blitz_assessment_id    = null OR a later same-Topic Blitz Assessment
```

The `blitz_assessment_id` column must be nullable.

Do **not** require creating a placeholder/fake Blitz row.

Do **not** create a second temporary “official homework” table.

The same `topic_result_pairs` row must grow into the final pair later by filling the previously null Blitz slot.

## 11.2 Columns

| Column | Type | Null | Contract |
|---|---|---:|---|
| `id` | uuid | no | Primary key |
| `institution_id` | uuid | no | Direct tenant owner |
| `topic_id` | uuid | no | Exactly one pair row per Topic |
| `homework_assessment_id` | uuid | no | Same-Institution, same-Topic Assessment; later application must require type Homework |
| `blitz_assessment_id` | uuid | yes | Same-Institution, same-Topic Assessment; null until later Blitz stage |
| `designated_by_user_id` | uuid | no | Same-Institution actor |
| `designated_at` | timestamptz | no | Server-authoritative designation instant |
| `cohort_snapshotted_at` | timestamptz | yes | Set when the official cohort is persisted |
| `locked_at` | timestamptz | yes | Set when Student activity locks official Homework/cohort meaning |
| `created_at` | timestamptz | no | Laravel timestamp |
| `updated_at` | timestamptz | no | Laravel timestamp |

## 11.3 Required support key

```text
unique(institution_id, id)
```

## 11.4 Required uniqueness

Exactly one staged/final result-pair row per Topic:

```text
unique(topic_id)
```

Do not create a second pair row merely because the future Blitz slot is still null.

## 11.5 Required checks

```text
blitz_assessment_id is null
OR blitz_assessment_id <> homework_assessment_id
```

Timestamp/history shape:

```text
cohort_snapshotted_at is null
OR cohort_snapshotted_at >= designated_at
```

```text
locked_at is null
OR (
  cohort_snapshotted_at is not null
  AND locked_at >= cohort_snapshotted_at
)
```

Important future-stage compatibility:

- `locked_at` may become non-null while `blitz_assessment_id` is still null after Stage 7 Homework activity;
- later filling the previously null Blitz slot is **not** the same operation as replacing the locked Homework/cohort;
- this task only provides the storage shape; mutation rules are implemented later.

## 11.6 Required foreign keys

All `ON DELETE RESTRICT`.

Tenant/Topic:

```text
institution_id
  -> institutions.id

(institution_id, topic_id)
  -> topics(institution_id, id)
```

Official Homework candidate must be the same Institution and same Topic:

```text
(institution_id, topic_id, homework_assessment_id)
  -> assessments(institution_id, topic_id, id)
```

Nullable future Blitz candidate must also be the same Institution and same Topic:

```text
(institution_id, topic_id, blitz_assessment_id)
  -> assessments(institution_id, topic_id, id)
```

Designating actor:

```text
(institution_id, designated_by_user_id)
  -> users(institution_id, id)
```

Later application/domain logic must additionally enforce:

```text
homework_assessment.type = homework
homework_assessment.assignment_mode = group

if blitz_assessment_id is non-null:
  blitz_assessment.type = blitz
  blitz_assessment.assignment_mode = group
```

Do not implement these semantic type/assignment rules with triggers here.

---

# 12. Enum Contract

Use string-backed PHP enums following the repository’s established enum style. Include a `values(): array` helper where that matches current enum conventions.

Add exactly the machine-value concepts required by this task.

## 12.1 `AssessmentType`

```text
Homework = 'homework'
Blitz    = 'blitz'
```

## 12.2 `AssessmentAssignmentMode`

```text
Group            = 'group'
SelectedStudents = 'selected_students'
```

## 12.3 `HomeworkStatus`

```text
Draft    = 'draft'
Active   = 'active'
Closed   = 'closed'
Archived = 'archived'
```

## 12.4 `AssessmentAssignmentSource`

```text
Group  = 'group'
Direct = 'direct'
```

## 12.5 `AssessmentAttemptStatus`

```text
InProgress              = 'in_progress'
Submitted               = 'submitted'
TimedOutFinalized       = 'timed_out_finalized'
WaitingForTeacherReview = 'waiting_for_teacher_review'
Checked                 = 'checked'
```

## 12.6 `AssessmentAttemptFinalizationReason`

```text
StudentSubmit               = 'student_submit'
TimeoutAutoSubmit           = 'timeout_auto_submit'
TaskClosedAutoFinalize      = 'task_closed_auto_finalize'
HomeworkDeadlineAutoSubmit  = 'homework_deadline_auto_submit'
```

Do not create enums for display labels or future API-only concepts.

---

# 13. Eloquent Model Contract

Create:

```text
App\Models\Assessment
App\Models\HomeworkAssignment
App\Models\AssessmentStudent
App\Models\AssessmentAttempt
App\Models\TopicResultPair
```

Each must:

- use the existing UUID model convention where the table has its own UUID `id`;
- use the existing factory convention;
- declare explicit writable attributes;
- cast stable machine values to the enums defined above;
- cast timestamps to datetime;
- cast numeric/boolean fields appropriately;
- contain relationships/query representation only;
- contain no authorization, lifecycle transitions, recipient resolution, attempt allocation, scoring, or result-pair mutation decisions.

`HomeworkAssignment` uses `assessment_id` as its non-incrementing UUID primary key. Implement the Laravel model key configuration correctly for that shape.

## 13.1 `Assessment`

Required casts:

```text
type -> AssessmentType
assignment_mode -> AssessmentAssignmentMode
total_possible_points -> decimal:6 or equivalent repository-consistent precise representation
```

Required relationships:

```text
institution
topic
teacher
homeworkAssignment
recipients
attempts
resultPairAsHomework
resultPairAsBlitz
```

## 13.2 `HomeworkAssignment`

Required casts:

```text
status -> HomeworkStatus
deadline_at
activated_at
closed_at
archived_at
```

Required relationships:

```text
assessment
institution
```

Do not duplicate Assessment metadata as model accessors with independent stored authority.

## 13.3 `AssessmentStudent`

Required casts:

```text
assignment_source -> AssessmentAssignmentSource
assigned_at
```

Required relationships:

```text
institution
assessment
student
assignedBy
attempts
```

## 13.4 `AssessmentAttempt`

Required casts:

```text
status -> AssessmentAttemptStatus
finalization_reason -> AssessmentAttemptFinalizationReason (nullable)
started_at
deadline_at
submitted_at
finalized_at
locked_at
official_score_eligible -> boolean
earned_points -> repository-consistent precise numeric cast
possible_points -> repository-consistent precise numeric cast
normalized_score -> repository-consistent precise numeric cast
scoring_completed_at
```

Required relationships:

```text
institution
assessment
assessmentStudent
student
```

## 13.5 `TopicResultPair`

Required casts:

```text
designated_at
cohort_snapshotted_at
locked_at
```

Required relationships:

```text
institution
topic
homeworkAssessment
blitzAssessment
designatedBy
```

`blitzAssessment` must correctly support `null`.

---

# 14. Required Inverse Relationships on Existing Models

Add only the relationships needed to make the new persistence graph explicit and testable.

## 14.1 `Topic`

Add:

```text
assessments
resultPair
```

Do not alter existing Topic authorization scopes or Stage 5 lifecycle behavior.

## 14.2 `Institution`

Add:

```text
assessments
homeworkAssignments
assessmentStudents
assessmentAttempts
topicResultPairs
```

## 14.3 `User`

Add clearly named relationships for:

```text
authoredAssessments          // teacher_id
assessmentAssignments        // student_id on assessment_students
assessmentAssignmentsCreated // assigned_by_user_id
assessmentAttempts           // student_id
designatedTopicResultPairs   // designated_by_user_id
```

Use specific names; do not add ambiguous generic relationships such as `assessments()` on `User`.

No existing relationship semantics may change.

---

# 15. Factory Contract

Create deterministic factories for:

```text
Assessment
HomeworkAssignment
AssessmentStudent
AssessmentAttempt
TopicResultPair
```

Factories are test infrastructure, not hidden business services.

## 15.1 `AssessmentFactory`

Default may be a valid draft-friendly Homework assessment, but it must provide explicit states:

```text
homework()
blitz()
groupAssignment()
selectedStudentsAssignment()
```

The default graph must keep Institution, Topic, and Teacher IDs consistent.

Do not require current Teacher–Group membership merely for structural factory validity unless a specific test explicitly creates it.

## 15.2 `HomeworkAssignmentFactory`

Default:

- points to an Assessment of `type = homework`;
- uses the same Institution as that Assessment;
- produces a valid `draft` lifecycle shape unless a lifecycle state is explicitly requested.

Provide explicit valid lifecycle states sufficient for tests, for example:

```text
draft()
active()
closed()
archivedFromDraft()
archivedAfterClose()
```

Do not create an invalid direct `active -> archived` state.

## 15.3 `AssessmentStudentFactory`

Default graph must produce:

- one Assessment;
- one same-Institution Student User;
- one same-Institution assigning actor;
- consistent `institution_id`;
- a valid `assignment_source`.

## 15.4 `AssessmentAttemptFactory`

Default graph must produce:

- one recipient relation;
- the same Assessment/Student/Institution as that relation;
- `attempt_number = 1`;
- `status = in_progress`;
- `possible_points >= 0`;
- `official_score_eligible = true`;
- no fabricated submitted/finalized timestamps for the default in-progress state.

State helpers may exist only where they make focused tests readable. Do not build future scoring workflows into the factory.

## 15.5 `TopicResultPairFactory`

Default must create a valid **Stage 6 partial pair**:

```text
homework_assessment_id = same-Topic Homework Assessment
blitz_assessment_id = null
```

Provide a focused state/helper for a structurally complete same-Topic pair when needed by persistence tests:

```text
withBlitz()
```

The future Blitz Assessment may be an `Assessment` row of `type = blitz`; do not create a `blitz_tasks` table/model in this task.

Factories must never silently create cross-Institution or cross-Topic links.

---

# 16. Authorization and Tenant Isolation Boundary

There is no public actor-driven API in this persistence-only task.

Therefore:

```text
HTTP authorization = N/A
```

However structural tenant isolation is mandatory.

PostgreSQL must reject direct persistence attempts that mix:

- foreign Topic + Institution;
- foreign Teacher + Institution;
- foreign Assessment + Institution;
- foreign Student + Institution;
- foreign assigning/designating actor + Institution;
- foreign recipient relation + Attempt Institution;
- foreign-Topic official Homework/Blitz candidate in `topic_result_pairs`.

A syntactically valid UUID never bypasses these foreign-key boundaries.

Role semantics are intentionally deferred:

- `teacher_id` / `assigned_by_user_id` / `designated_by_user_id` being a Teacher;
- `student_id` being a Student;
- current Teacher–Group membership;
- current Student–Group membership;
- eligible selected-Student assignment;
- official-task `assignment_mode = group`;
- Homework/Blitz type-specific behavioral rules.

Those rules belong to later Stage 6 Actions and must not be approximated with database triggers in this task.

---

# 17. Validation and Error Boundary

No HTTP validation/error contract is implemented.

Expected persistence failures must surface in tests as database constraint/FK/unique violations without changing production error mapping.

The migration/model/factory implementation must not catch and transform database exceptions into a new public API contract.

Required structural rejection categories include:

| Case | Required persistence result |
|---|---|
| Invalid Assessment type | Database reject |
| Invalid assignment mode/source | Database reject |
| Negative `total_possible_points` / `possible_points` | Database reject |
| Invalid Homework lifecycle shape | Database reject |
| Invalid Homework status | Database reject |
| Duplicate Assessment recipient | Database reject |
| Invalid Attempt status/finalization reason | Database reject |
| Attempt number `0` or `4+` | Database reject |
| Duplicate Student/Assessment/attempt number | Database reject |
| Score outside `0..100` | Database reject |
| Earned points below `0` or above possible points | Database reject |
| Cross-Institution FK combination | Database reject |
| Cross-Topic official Assessment candidate | Database reject |
| Same Homework and Blitz ID when Blitz is non-null | Database reject |
| Second result-pair row for same Topic | Database reject |
| `locked_at` without cohort snapshot | Database reject |
| Deleting referenced historical parent row | Database reject through `ON DELETE RESTRICT` |

---

# 18. Concurrency and Idempotency

### Database concurrency

Required only through constraints for this task:

- unique Assessment recipient;
- unique Attempt number per Assessment + Student;
- unique result-pair row per Topic;
- FK integrity;
- lifecycle checks.

Do **not** implement row-locking Actions in this task.

Concurrent next-attempt allocation, recipient snapshotting, lifecycle transitions, and result-pair designation are later Action-level responsibilities.

### API idempotency

```text
N/A — no mutation API exists in this task.
```

### Migration idempotency

Use ordinary Laravel forward migration semantics. Do not write runtime “if table exists then silently skip half the schema” behavior that can hide a partial migration.

---

# 19. Architecture and Placement

Use the established Laravel modular-monolith responsibility boundary.

Owning areas:

```text
backend/database/migrations
backend/database/factories
backend/app/Enums
backend/app/Models
backend/tests/Feature/Persistence
```

Reuse existing:

- UUID model/factory conventions;
- PostgreSQL explicit constraint/index naming style;
- `RefreshDatabase`;
- persistence test utilities such as the existing database-rejection helper where appropriate;
- existing Topic/Institution/User models only for required inverse relationships.

Forbidden:

- business Actions in Models;
- authorization checks in migrations;
- controller/API code;
- question/scoring services;
- new repository layer;
- speculative generic Assessment framework beyond the five concrete persistence concepts and enums required here.

The shared `assessments` base is an approved architecture boundary; do not flatten Homework-specific lifecycle columns into `assessments`, and do not create an unrelated second Homework identity table with a separate public UUID.

The public Homework identity in later tasks is the shared Assessment UUID represented by `homework_assignments.assessment_id`.

---

# 20. Expected Files and Areas

Exact timestamp prefixes for new migrations are ordinary local implementation details; use the next safe forward-only timestamp(s).

| Path or area | Action | Reason |
|---|---|---|
| `backend/database/migrations/*assessment*homework*persistence*.php` or equivalent focused forward migration(s) | Create | New tables, FKs, checks, indexes |
| `backend/app/Enums/AssessmentType.php` | Create | Stable Assessment type machine values |
| `backend/app/Enums/AssessmentAssignmentMode.php` | Create | Assignment mode values |
| `backend/app/Enums/HomeworkStatus.php` | Create | Homework lifecycle values |
| `backend/app/Enums/AssessmentAssignmentSource.php` | Create | Recipient source values |
| `backend/app/Enums/AssessmentAttemptStatus.php` | Create | Attempt state values |
| `backend/app/Enums/AssessmentAttemptFinalizationReason.php` | Create | Finalization reason values |
| `backend/app/Models/Assessment.php` | Create | Shared Assessment model |
| `backend/app/Models/HomeworkAssignment.php` | Create | Homework lifecycle/detail model |
| `backend/app/Models/AssessmentStudent.php` | Create | Recipient snapshot model |
| `backend/app/Models/AssessmentAttempt.php` | Create | Structural Attempt model |
| `backend/app/Models/TopicResultPair.php` | Create | Staged official pair model |
| `backend/app/Models/Topic.php` | Modify | `assessments`, `resultPair` inverses only |
| `backend/app/Models/Institution.php` | Modify | Required new inverses only |
| `backend/app/Models/User.php` | Modify | Clearly named new inverses only |
| `backend/database/factories/AssessmentFactory.php` | Create | Deterministic Assessment graphs |
| `backend/database/factories/HomeworkAssignmentFactory.php` | Create | Homework lifecycle factory |
| `backend/database/factories/AssessmentStudentFactory.php` | Create | Recipient factory |
| `backend/database/factories/AssessmentAttemptFactory.php` | Create | Structural Attempt factory |
| `backend/database/factories/TopicResultPairFactory.php` | Create | Partial/final structural pair factory |
| `backend/tests/Feature/Persistence/AssessmentHomeworkSchemaInspectionTest.php` | Create | Exact schema/constraint/index inspection |
| `backend/tests/Feature/Persistence/AssessmentHomeworkPersistenceTest.php` | Create | DB invariants and tenant/history rejection |
| `backend/tests/Feature/Persistence/AssessmentHomeworkFactoryModelTest.php` | Create | Enums/casts/relationships/factories |

Changes outside these areas require a concrete necessity inside this task and must be reported.

Do not modify routes, controllers, Actions, Requests, Resources, docs, task files, frontend, dependencies, seeders, or unrelated tests.

---

# 21. Acceptance Criteria

The task is implementation-complete only when all are true.

- [x] `assessments` exists with the exact common metadata, tenant ownership, enum/numeric checks, support keys, FKs, and indexes required above.
- [x] `homework_assignments` exists with no configurable attempt-limit field and with the exact lifecycle/deadline structure.
- [x] Homework lifecycle DB checks accept valid `draft`, `active`, `closed`, `draft→archived`, and `closed→archived` historical shapes and reject invalid shapes.
- [x] `assessment_students` stores one unique persisted recipient per Student/Assessment and enforces same-Institution FKs.
- [x] `assessment_attempts` provides the exact structural machine values/columns required above without exposing attempt execution behavior.
- [x] Attempt number structural bound rejects `0` and `4+`; there is no mutable Homework attempt-limit setting/column.
- [x] `topic_result_pairs` requires Homework but permits `blitz_assessment_id = null`.
- [x] No placeholder/fake Blitz record is required for a Stage 6 partial pair.
- [x] `topic_result_pairs` rejects cross-Institution and cross-Topic Assessment references.
- [x] Only one result-pair row can exist per Topic.
- [x] A locked pair requires an existing cohort snapshot, while a locked row may still have `blitz_assessment_id = null`.
- [x] All new FK deletes are restrictive and historical child rows prevent destructive parent deletion.
- [x] All required enums exist with exact machine values.
- [x] All five Eloquent models use correct casts, writable attributes, key behavior, and relationships without workflow logic.
- [x] Existing `Topic`, `Institution`, and `User` behavior is unchanged except for the required inverse relationships.
- [x] Factories produce deterministic valid same-Institution graphs and valid lifecycle states.
- [x] Cross-Institution persistence attempts are rejected by the database.
- [x] No Question tables/API, Student attempt API, scoring, deadline runtime, lifecycle Actions, official designation API, frontend, dependencies, seeders, docs, or unrelated refactor enters scope.
- [x] The three new focused persistence test files pass.
- [x] Directly affected Stage 5 persistence/settings regressions pass.
- [x] Pint passes.
- [x] `git diff --check` passes.
- [x] Focused final diff review finds no P1/P2 security, tenant, data-integrity, or scope problem.

---

# 22. Focused Tests and Verification

Run from:

```text
backend/
```

Codex runs only the task-level focused verification below.

Do not run the full backend suite; that belongs to Stage 6 Backend Phase 2.

## 22.1 New focused persistence tests

```bash
php artisan test \
  tests/Feature/Persistence/AssessmentHomeworkSchemaInspectionTest.php \
  tests/Feature/Persistence/AssessmentHomeworkPersistenceTest.php \
  tests/Feature/Persistence/AssessmentHomeworkFactoryModelTest.php
```

Required cases include at least:

### Schema

- exact required columns/types/nullability;
- exact enum/check semantics;
- lifecycle check semantics;
- required unique/support keys;
- required indexes;
- required FKs and `ON DELETE RESTRICT`;
- `blitz_assessment_id` nullable;
- no `attempt_limit` on `homework_assignments`;
- no Question/Blitz-detail/answer/result-score tables created by this task.

### Persistence invariants

- valid same-Institution Assessment graph persists;
- cross-Institution Topic/Teacher references are rejected;
- invalid Assessment type/assignment mode/negative points are rejected;
- all valid Homework lifecycle shapes persist;
- invalid Homework lifecycle/timestamp shapes are rejected;
- duplicate recipient is rejected;
- cross-Institution Assessment/Student/assigner recipient references are rejected;
- valid structural Attempt persists;
- invalid Attempt number/status/finalization reason/score values are rejected;
- duplicate Attempt number for Student/Assessment is rejected;
- cross-Institution Attempt references are rejected;
- partial result pair with null Blitz persists;
- structurally complete same-Topic pair persists;
- cross-Topic/cross-Institution official candidate is rejected;
- same Homework/Blitz ID is rejected when Blitz is non-null;
- second pair for one Topic is rejected;
- `locked_at` without cohort snapshot is rejected;
- locked partial pair with cohort snapshot and null Blitz is accepted;
- restrictive FK deletes preserve history.

### Models/factories

- enum casts use exact machine values;
- `HomeworkAssignment` correctly uses UUID `assessment_id` primary key;
- relationships resolve the intended records;
- `blitzAssessment` safely supports null;
- required inverse relationships resolve;
- factory defaults are same-Institution and internally consistent;
- valid lifecycle factory states are valid;
- partial pair factory defaults to Homework + null Blitz.

## 22.2 Directly affected regression

Run the existing Stage 5 persistence tests because the new schema hangs from Stage 5 Topic/Institution/User parents and their models receive inverse relationships:

```bash
php artisan test \
  tests/Feature/Persistence/TopicLearningMaterialSchemaInspectionTest.php \
  tests/Feature/Persistence/TopicLearningMaterialPersistenceTest.php \
  tests/Feature/Persistence/TopicLearningMaterialFactoryModelTest.php
```

Run the assessment-settings regression because its historical-preservation test already conditionally snapshots future assessment tables; creation of these tables activates that existing code path:

```bash
php artisan test \
  tests/Feature/Institution/InstitutionAssessmentSettingsApiTest.php
```

No broader regression is required at task level unless implementation necessarily touches shared infrastructure outside this contract. If that occurs, report the exact risk instead of independently running the full suite.

## 22.3 Format/static

```bash
./vendor/bin/pint --test
```

No additional PHP static-analysis command is required unless one is already mandatory for exactly the changed backend area under the current repository configuration.

## 22.4 Always

```bash
git diff --check
```

Then inspect the complete diff and verify:

- every changed file is task-owned;
- no delivered migration was rewritten;
- no API/schema beyond this contract changed;
- no Question/Blitz runtime/Student submission/scoring code appeared;
- no authorization/tenant rule was weakened;
- no test was weakened;
- no debug code, secret, temporary file, generated junk, or unrelated formatting churn exists;
- pre-existing user work is untouched.

Narrow diagnostic reruns are allowed only to investigate a concrete failure.

## 22.5 Project Owner manual check

```text
Not required — persistence-only backend task with no user-facing/API behavior.
```

---

# 23. Delivery

Follow root `AGENTS.md` and `tasks/README.md`.

Delivery owner:

```text
Project Owner
```

Suggested delivery:

```text
Branch: feat/s06-be-001-assessment-homework-persistence
Commit: feat(stage6): add homework persistence foundation
PR base: main
```

Implementation delivery must contain only task-owned backend production/test files.

Codex must not:

- commit;
- push;
- open or merge a PR;
- modify this task file;
- modify a Stage index;
- perform bookkeeping delivery.

Codex stops after implementation, focused verification, `git diff --check`, and focused scope/diff self-review and reports the Git state for Project Owner handoff.

Task acceptance occurs only after approved delivery completes, the accepted result is present on `origin/main`, local `main == origin/main`, ahead/behind is `0/0`, and the worktree is clean.

## 23.1 Accepted Delivery Evidence

- Delivery: Delivered — PR #143.
- Delivered merge: `ab9c826b626891d119d5c8f674dff212ebe7a806`.
- Acceptance review: PASS — P1=0, P2=0, P3=0.
- Required focused Assessment/Homework persistence tests: PASS — 17 tests, 605 assertions.
- Stage 5 Topic/Learning Material persistence regression: PASS — 17 tests, 409 assertions.
- Institution assessment-settings regression: PASS — 13 tests, 1,920 assertions.
- Pint: PASS — 355 files.
- `git diff --check`: PASS.
- Delivery scope: 23 task-owned backend files.
- Accepted baseline state: local `main == origin/main`, ahead/behind `0/0`, worktree clean.

---

# 24. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must **not** open these sources to rediscover or reinterpret requirements.

| Source/reference | Decision already encoded in this contract |
|---|---|
| `docs/06-roadmap.md` — Stage 6 | Homework authoring foundation; fixed 3 normal attempts; Stage 7 owns Student execution |
| `docs/07-architecture.md` — Assessment architecture | Shared Assessment components with distinct Homework lifecycle |
| `docs/08-database.md` — Assessments/Homework/recipients/attempts/result pair | Base table shapes, recipient snapshots, structural Attempt/history model |
| `docs/09-api-contracts.md` — Homework/result-pair contracts | Future public identity and lifecycle expectations |
| Approved Stage 6 planning resolution | `topic_result_pairs.blitz_assessment_id` is nullable until later Blitz implementation; no fake Blitz; later Stage fills the null slot while preserving locked Homework/cohort |
| `tasks/README.md` | Workflow v3 — one compact self-contained Codex contract + focused task verification |
| Current Stage 5 implementation | Topic, Institution, User, UUID, PostgreSQL, factory, persistence-test conventions reused without changing Stage 5 behavior |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |

The staged nullable-Blitz result-pair rule is an approved Stage 6 sequencing specialization and is authoritative for this task.

---

# 25. Codex Final Report

Return one implementation status:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

Use `DELIVERY BLOCKED` only if a future contract explicitly assigns delivery to Codex; this contract does not.

Return:

1. **Status**.
2. **Implementation** — concise result.
3. **Changed files** — file → purpose.
4. **Acceptance criteria** — concise implementation-owned PASS/FAIL evidence.
5. **Focused verification** — exact commands and results.
6. **Persistence/tenant integrity** — concise evidence.
7. **Scope/diff** — non-goals preserved, `git diff --check`, no unrelated changes.
8. **Delivery handoff** — `Project Owner` plus current Git state.
9. **Deviations/blockers** — exact facts.

Do not output task `Accepted`. ChatGPT assigns acceptance only after required focused verification and approved delivery.

Do not repeat this contract or paste large successful logs.

If any product, database, security, tenant, lifecycle, concurrency, idempotency, or architecture decision needed by this task appears unresolved or conflicts with the current implementation, return `BLOCKED` rather than deciding independently.
