# Codex Implementation Contract: S08-BE-001 — Blitz Persistence and Domain Foundation

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-BE-001` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel/PostgreSQL Blitz persistence + Eloquent domain foundation` |
| Depends on | `S08-DOC-001 — Accepted / Delivered` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` after `S08-DOC-001` delivery and immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |
| Backend block checkpoint | `Stage 8 Backend Phase 2` after `S08-BE-001…010` are `Accepted / Delivered` |
| Blocks | `S08-BE-002` |

Start only when:

```text
S08-DOC-001 = Accepted / Delivered
this contract remains Approved
ChatGPT has re-checked current origin/main
Git preflight is safe
```

This file is the complete task-specific implementation contract.

Do **not** create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this implementation contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. current backend migrations/models/enums/factories/tests directly required by this task.

Do **not** read:

- `docs/01–09`;
- roadmap files;
- `STAGE_08_TASK_INDEX.md`;
- `S08-DOC-001`;
- previous task files;
- Stage history;
- closure reviews;
- frontend code;
- unrelated backend modules

to determine what to implement.

The contract below already resolves the required persistence/domain decisions.

If the current implementation materially conflicts with this contract, return:

```text
BLOCKED
```

with exact file/line evidence.

Do not make a new product, lifecycle, database, API, security, timing, or exception-policy decision independently.

A newer `origin/main` than the planning baseline is allowed only after ChatGPT has revalidated this contract against it.

---

# 3. Goal

Add the missing Blitz-specific persistence/domain foundation on top of the already-delivered shared Assessment infrastructure.

At completion the backend has durable structural storage for:

```text
Blitz task lifecycle/timing definition
+
Student-specific Blitz attempt exception history
```

through:

```text
blitz_tasks
blitz_attempt_exceptions
```

and corresponding:

- enums;
- Eloquent models;
- relationships;
- deterministic factories;
- PostgreSQL constraints/indexes/FKs;
- focused persistence tests.

This task exposes **no public HTTP/API behavior**.

This task implements **no Blitz lifecycle action**.

This task creates **no Student Attempt**.

---

# 4. Delivered Foundation That Must Be Reused

The existing delivered schema already provides:

```text
assessments
assessment_students
assessment_attempts
topic_result_pairs
questions
attempt_answers
idempotency_records
```

Do not duplicate them.

## 4.1 Existing Assessment type

Already delivered:

```text
AssessmentType::Homework = homework
AssessmentType::Blitz    = blitz
```

Do not create another Assessment type enum.

## 4.2 Existing timer-mode enum

Already delivered:

```text
BlitzTimerStartMode::Synchronized = synchronized
BlitzTimerStartMode::Individual   = individual
```

It is already used by:

```text
InstitutionSetting.blitz_timer_start_mode
```

Reuse this exact enum for:

```text
BlitzTask.timer_start_mode_snapshot
```

Do not create another timer-mode enum.

## 4.3 Existing Attempt storage

`assessment_attempts` already contains:

```text
deadline_at
status
submitted_at
finalized_at
finalization_reason
locked_at
official_score_eligible
```

and already supports:

```text
status = timed_out_finalized
finalization_reason = timeout_auto_submit
```

The shared structural Attempt number check is already:

```text
1 <= attempt_number <= 3
```

because Homework permits three normal Attempts.

Do **not** replace that global structural check with a Blitz-specific maximum.

Later Blitz Actions enforce:

```text
normal Blitz = Attempt #1
exception replacement = Attempt #2 only
Attempt #3 forbidden for Blitz by application/domain behavior
```

## 4.4 Existing one-in-progress database backstop

The delivered Stage 7 migration already provides:

```text
unique (assessment_id, student_id)
where status = 'in_progress'
```

through:

```text
assessment_attempts_one_in_progress_per_student_unique
```

Reuse it.

Do not create another competing one-in-progress index.

## 4.5 Existing staged result pair

Already delivered:

```text
topic_result_pairs.blitz_assessment_id nullable
```

with same-Topic tenant-safe FK support.

This task does not mutate result-pair behavior or schema.

---

# 5. Scope

## 5.1 Included

Implement only:

- one new forward-only Stage 8 migration;
- `blitz_tasks`;
- `blitz_attempt_exceptions`;
- `BlitzStatus`;
- `BlitzAttemptExceptionReasonType`;
- `BlitzTask` model;
- `BlitzAttemptException` model;
- required inverse Eloquent relationships;
- `BlitzTaskFactory`;
- `BlitzAttemptExceptionFactory`;
- focused PostgreSQL schema/persistence/factory-model tests;
- the one directly obsolete Stage 6 schema-test assertion that currently requires `blitz_tasks` to be absent.

## 5.2 Existing files that may require narrow modification

Only where needed by this contract:

```text
backend/app/Models/Assessment.php
backend/app/Models/AssessmentStudent.php
backend/app/Models/AssessmentAttempt.php
backend/app/Models/Institution.php
backend/app/Models/User.php
backend/tests/Feature/Persistence/AssessmentHomeworkSchemaInspectionTest.php
```

No existing relationship semantics may be changed.

---

# 6. Explicit Non-Goals

Do not implement or change:

- routes;
- controllers;
- Form Requests;
- API Resources;
- Actions/use cases;
- Teacher Blitz create/list/detail/update;
- scheduling Action;
- archive Action;
- Question mutation behavior;
- official Blitz designation;
- result-pair PUT behavior;
- activation;
- recipient snapshot population;
- official cohort establishment/reuse;
- Student Blitz list/detail;
- Attempt Start/Resume;
- answer/file save/replace;
- Student Submit;
- timeout reconciliation;
- Scheduler;
- Teacher Close;
- technical-exception grant Action;
- replacement Attempt creation;
- monitoring;
- idempotency operation codes/runtime behavior;
- checking;
- scoring;
- official scores;
- Topic results;
- frontend;
- seed/E2E data;
- dependencies;
- `docs/01–09`;
- task/Stage bookkeeping.

Do not:

- edit delivered migrations;
- alter `assessment_attempts` columns/checks/indexes;
- alter `topic_result_pairs`;
- add `attempt_limit`;
- add per-question timers;
- add a separate `blitz_attempts` table;
- add a separate `blitz_answers` table;
- add duplicated Question tables;
- add PostgreSQL native enums;
- add PostgreSQL RLS;
- add database triggers;
- add soft deletes;
- add a generic repository/service framework.

---

# 7. Migration Strategy

Create one new forward migration with the next safe chronological filename, conceptually:

```text
<new_timestamp>_create_blitz_persistence_domain_foundation.php
```

Do not rename or edit:

```text
2026_09_01_000000_create_assessment_homework_persistence_foundation.php
2026_09_02_000000_create_question_persistence_foundation.php
2026_09_08_000000_create_student_answer_submission_persistence_foundation.php
```

Migration `up()` order:

```text
1. blitz_tasks
2. blitz_attempt_exceptions
```

Migration `down()` order:

```text
1. blitz_attempt_exceptions
2. blitz_tasks
```

All new foreign keys use:

```text
ON DELETE RESTRICT
```

Use explicit stable names for every check, unique, index, and foreign key.

---

# 8. `blitz_tasks` Persistence Contract

`blitz_tasks` is the Blitz-specific detail/lifecycle row for one shared Assessment.

Public/future Blitz identity is the shared:

```text
assessments.id
```

represented by:

```text
blitz_tasks.assessment_id
```

There is no second independent public Blitz UUID.

## 8.1 Exact columns

| Column | PostgreSQL type | Null | Contract |
|---|---|---:|---|
| `assessment_id` | uuid | no | Primary key; shared Blitz Assessment identity |
| `institution_id` | uuid | no | Direct Tenant owner |
| `status` | varchar(20) | no | Blitz lifecycle |
| `duration_seconds` | integer | no | Whole-Blitz configured duration |
| `scheduled_at` | timestamptz | yes | Set while scheduled; retained historically after later activation when applicable |
| `timer_start_mode_snapshot` | varchar(24) | yes | Activation snapshot; null before activation |
| `activated_at` | timestamptz | yes | Server-authoritative activation instant |
| `synchronized_ends_at` | timestamptz | yes | Common end only for synchronized activated Blitz |
| `closed_at` | timestamptz | yes | Close instant |
| `archived_at` | timestamptz | yes | Archive instant |
| `activated_by_user_id` | uuid | yes | Same-Institution activation actor |
| `created_at` | timestamptz | no | Laravel timestamp |
| `updated_at` | timestamptz | no | Laravel timestamp |

Do not add:

```text
id
attempt_limit
normal_attempts
timer_start_mode
per_question_duration
question_time_limit
official_score
is_official
topic_id
teacher_id
```

Common Topic/Teacher data remains on `assessments`.

---

# 9. `BlitzStatus` Enum

Create:

```text
App\Enums\BlitzStatus
```

Exact string values and order:

```php
Draft     = 'draft'
Scheduled = 'scheduled'
Active    = 'active'
Closed    = 'closed'
Archived  = 'archived'
```

Provide the repository-standard:

```php
public static function values(): array
```

returning exactly:

```text
draft
scheduled
active
closed
archived
```

Do not reuse `HomeworkStatus`; Homework and Blitz are separate lifecycle concepts.

---

# 10. `blitz_tasks` Database Constraints

## 10.1 Status check

Named:

```text
blitz_tasks_status_check
```

Exact allowed values:

```text
draft
scheduled
active
closed
archived
```

## 10.2 Positive duration

Named:

```text
blitz_tasks_duration_check
```

Require:

```text
duration_seconds > 0
```

There is no database hard maximum in this task.

The product's approximate 5–10 minute classroom intent is **not** a database maximum.

## 10.3 Timer-mode value check

Named:

```text
blitz_tasks_timer_mode_check
```

Require:

```text
timer_start_mode_snapshot is null
OR
timer_start_mode_snapshot in ('synchronized', 'individual')
```

## 10.4 Lifecycle shape check

Named:

```text
blitz_tasks_lifecycle_check
```

Enforce these structural shapes.

### Draft

```text
status = draft

timer_start_mode_snapshot = null
activated_at = null
synchronized_ends_at = null
closed_at = null
archived_at = null
activated_by_user_id = null
```

`scheduled_at` may be null or non-null while the Blitz remains `draft`.

This is intentional because the approved Create Blitz API accepts an optional
`scheduled_at` preparation value while creation still returns `status = draft`.
Only the explicit Schedule Blitz lifecycle operation later changes the lifecycle
status to `scheduled`.

### Scheduled

```text
status = scheduled

scheduled_at is not null
timer_start_mode_snapshot = null
activated_at = null
synchronized_ends_at = null
closed_at = null
archived_at = null
activated_by_user_id = null
```

### Active

```text
status = active

timer_start_mode_snapshot is not null
activated_at is not null
activated_by_user_id is not null
closed_at = null
archived_at = null
```

`scheduled_at` may be null or non-null because a Blitz may activate from draft or from scheduled state.

`synchronized_ends_at` is governed by the separate timer-shape constraint.

### Closed

```text
status = closed

timer_start_mode_snapshot is not null
activated_at is not null
activated_by_user_id is not null
closed_at is not null
archived_at = null
```

### Archived

Require:

```text
archived_at is not null
```

and exactly one historical family:

#### Archived before activation

```text
activated_at = null
activated_by_user_id = null
timer_start_mode_snapshot = null
synchronized_ends_at = null
closed_at = null
```

`scheduled_at` may be null or non-null, allowing historical shapes such as:

```text
draft -> archived
draft with prepared scheduled_at -> archived
scheduled -> archived
```

#### Archived after completed active lifecycle

```text
activated_at is not null
activated_by_user_id is not null
timer_start_mode_snapshot is not null
closed_at is not null
```

This intentionally rejects structural history equivalent to:

```text
active -> archived
```

without a close.

Later lifecycle Actions remain responsible for allowed transitions and authorization.

## 10.5 Timer shape check

Named:

```text
blitz_tasks_timer_shape_check
```

Enforce:

### Before activation

```text
timer_start_mode_snapshot = null
activated_at = null
activated_by_user_id = null
synchronized_ends_at = null
```

or:

### Synchronized activated history

```text
timer_start_mode_snapshot = synchronized
activated_at is not null
activated_by_user_id is not null
synchronized_ends_at = activated_at + duration_seconds seconds
```

or:

### Individual activated history

```text
timer_start_mode_snapshot = individual
activated_at is not null
activated_by_user_id is not null
synchronized_ends_at = null
```

The equality must use PostgreSQL timestamp/interval arithmetic.

Do not derive or persist Student individual deadlines here; those belong to:

```text
assessment_attempts.deadline_at
```

## 10.6 Timestamp ordering checks

Named checks:

```text
blitz_tasks_activated_order_check
blitz_tasks_closed_order_check
blitz_tasks_archived_order_check
```

Require:

```text
activated_at is null
OR activated_at >= created_at
```

```text
closed_at is null
OR (
  activated_at is not null
  AND closed_at >= activated_at
)
```

```text
archived_at is null
OR (
  archived_at >= created_at
  AND (
    closed_at is null
    OR archived_at >= closed_at
  )
)
```

Do **not** add a database rule requiring `scheduled_at > server_now` or `scheduled_at >= created_at`; schedule eligibility is later application behavior.

---

# 11. `blitz_tasks` Keys, FKs, and Indexes

## 11.1 Primary/support key

Primary:

```text
primary key (assessment_id)
```

Also create:

```text
unique (institution_id, assessment_id)
```

named:

```text
blitz_tasks_institution_assessment_unique
```

This mirrors the delivered Homework detail-table tenant support pattern.

## 11.2 Foreign keys

Named:

```text
blitz_tasks_assessment_tenant_foreign
```

```text
(institution_id, assessment_id)
  -> assessments(institution_id, id)
  ON DELETE RESTRICT
```

Named:

```text
blitz_tasks_activator_tenant_foreign
```

```text
(institution_id, activated_by_user_id)
  -> users(institution_id, id)
  ON DELETE RESTRICT
```

The activator FK is nullable before activation.

The database does **not** use a trigger to enforce:

```text
assessments.type = blitz
activated_by_user.role = teacher
```

Those are later application/domain rules.

## 11.3 Required indexes

Named:

```text
blitz_tasks_institution_status_scheduled_index
```

on:

```text
(institution_id, status, scheduled_at)
```

Named:

```text
blitz_tasks_institution_activated_index
```

on:

```text
(institution_id, activated_at)
```

Named:

```text
blitz_tasks_institution_synchronized_ends_index
```

on:

```text
(institution_id, synchronized_ends_at)
```

---

# 12. `BlitzTask` Model

Create:

```text
App\Models\BlitzTask
```

Follow the existing `HomeworkAssignment` detail-model pattern.

## 12.1 Identity

```text
primary key = assessment_id
incrementing = false
key type = string
```

Use:

```text
HasFactory
```

Do not use `HasUuids` because the primary key is the existing Assessment UUID, not a separately generated ID.

## 12.2 Fillable fields

Exactly the writable persistence fields:

```text
assessment_id
institution_id
status
duration_seconds
scheduled_at
timer_start_mode_snapshot
activated_at
synchronized_ends_at
closed_at
archived_at
activated_by_user_id
```

## 12.3 Casts

```text
status                    -> BlitzStatus
duration_seconds          -> integer
timer_start_mode_snapshot -> BlitzTimerStartMode
scheduled_at              -> datetime
activated_at              -> datetime
synchronized_ends_at      -> datetime
closed_at                 -> datetime
archived_at               -> datetime
```

Reuse existing:

```text
App\Enums\BlitzTimerStartMode
```

## 12.4 Relationships

Exact relationship names:

```text
assessment(): BelongsTo
institution(): BelongsTo
activatedBy(): BelongsTo
attemptExceptions(): HasMany
```

Mappings:

```text
activatedBy
  -> User via activated_by_user_id

attemptExceptions
  -> BlitzAttemptException via assessment_id
```

Do not put lifecycle mutation methods in the model.

---

# 13. `blitz_attempt_exceptions` Persistence Contract

This table stores one auditable Student-specific additional-Blitz opportunity.

It stores the **grant/history relation**, not the replacement Attempt lifecycle engine.

## 13.1 Exact columns

| Column | PostgreSQL type | Null | Contract |
|---|---|---:|---|
| `id` | uuid | no | Primary key |
| `institution_id` | uuid | no | Direct Tenant owner |
| `assessment_id` | uuid | no | Blitz Assessment identity |
| `assessment_student_id` | uuid | no | Persisted recipient |
| `student_id` | uuid | no | Student |
| `invalidated_attempt_id` | uuid | no | Normal Attempt #1 being excluded |
| `replacement_attempt_id` | uuid | yes | Attempt #2 after it later starts |
| `reason_type` | varchar(24) | no | Stable exception reason category |
| `reason` | text | no | Required Teacher explanation |
| `granted_by_user_id` | uuid | no | Granting actor |
| `granted_at` | timestamptz | no | Server-authoritative grant instant |
| `created_at` | timestamptz | no | Laravel timestamp |
| `updated_at` | timestamptz | no | Laravel timestamp |

Do not add:

```text
status
approved
attempt_limit
extra_attempts
duration_seconds
timer_mode
new_deadline
score
```

The exception authorizes later domain behavior; it does not duplicate the Attempt row.

---

# 14. `BlitzAttemptExceptionReasonType` Enum

Create:

```text
App\Enums\BlitzAttemptExceptionReasonType
```

Exact values and order:

```php
Technical  = 'technical'
OtherValid = 'other_valid'
```

Provide standard:

```php
values(): array
```

returning exactly:

```text
technical
other_valid
```

Do not encode free-text reason values into this enum.

---

# 15. `blitz_attempt_exceptions` Constraints

## 15.1 Reason type

Named:

```text
blitz_attempt_exceptions_reason_type_check
```

Require:

```text
reason_type in ('technical', 'other_valid')
```

## 15.2 Required explanation

Named:

```text
blitz_attempt_exceptions_reason_not_empty_check
```

Require PostgreSQL:

```text
btrim(reason) <> ''
```

## 15.3 Distinct invalidated/replacement Attempt

Named:

```text
blitz_attempt_exceptions_distinct_attempts_check
```

Require:

```text
replacement_attempt_id is null
OR replacement_attempt_id <> invalidated_attempt_id
```

Do not attempt cross-table Student/Assessment/Attempt-number checks with triggers.

Those are later `S08-BE-009` application/domain rules.

---

# 16. `blitz_attempt_exceptions` Uniqueness

## 16.1 One exception per Student/Blitz

Named:

```text
blitz_attempt_exceptions_assessment_student_unique
```

Require:

```text
unique (assessment_id, student_id)
```

## 16.2 Original Attempt invalidated only once

Named:

```text
blitz_attempt_exceptions_invalidated_attempt_unique
```

Require:

```text
unique (invalidated_attempt_id)
```

## 16.3 Replacement Attempt referenced only once

Named:

```text
blitz_attempt_exceptions_replacement_attempt_unique
```

Require uniqueness of non-null:

```text
replacement_attempt_id
```

PostgreSQL ordinary uniqueness is acceptable because multiple null values remain allowed.

## 16.4 Query index

Named:

```text
blitz_attempt_exceptions_institution_assessment_student_index
```

on:

```text
(institution_id, assessment_id, student_id)
```

---

# 17. `blitz_attempt_exceptions` Foreign Keys

All are restrictive.

Named:

```text
blitz_attempt_exceptions_institution_id_foreign
```

```text
institution_id
  -> institutions.id
```

Named:

```text
blitz_attempt_exceptions_assessment_tenant_foreign
```

```text
(institution_id, assessment_id)
  -> assessments(institution_id, id)
```

Named:

```text
blitz_attempt_exceptions_recipient_tenant_foreign
```

```text
(institution_id, assessment_student_id)
  -> assessment_students(institution_id, id)
```

Named:

```text
blitz_attempt_exceptions_student_tenant_foreign
```

```text
(institution_id, student_id)
  -> users(institution_id, id)
```

Named:

```text
blitz_attempt_exceptions_invalidated_attempt_tenant_foreign
```

```text
(institution_id, invalidated_attempt_id)
  -> assessment_attempts(institution_id, id)
```

Named:

```text
blitz_attempt_exceptions_replacement_attempt_tenant_foreign
```

nullable child:

```text
(institution_id, replacement_attempt_id)
  -> assessment_attempts(institution_id, id)
```

Named:

```text
blitz_attempt_exceptions_grantor_tenant_foreign
```

```text
(institution_id, granted_by_user_id)
  -> users(institution_id, id)
```

Do not add database triggers to enforce:

```text
assessment.type = blitz
assessment_student.assessment_id = assessment_id
assessment_student.student_id = student_id
invalidated_attempt.assessment_id = assessment_id
invalidated_attempt.student_id = student_id
invalidated_attempt.attempt_number = 1
replacement_attempt.assessment_id = assessment_id
replacement_attempt.student_id = student_id
replacement_attempt.attempt_number = 2
grantor role = teacher
```

`S08-BE-009` must enforce those transactionally.

This task creates structural tenant-safe storage only.

---

# 18. `BlitzAttemptException` Model

Create:

```text
App\Models\BlitzAttemptException
```

Use:

```text
HasFactory
HasUuids
```

## 18.1 Fillable

```text
institution_id
assessment_id
assessment_student_id
student_id
invalidated_attempt_id
replacement_attempt_id
reason_type
reason
granted_by_user_id
granted_at
```

## 18.2 Casts

```text
reason_type -> BlitzAttemptExceptionReasonType
granted_at  -> datetime
```

## 18.3 Relationships

Exact names:

```text
institution(): BelongsTo
assessment(): BelongsTo
assessmentStudent(): BelongsTo
student(): BelongsTo
invalidatedAttempt(): BelongsTo
replacementAttempt(): BelongsTo
grantedBy(): BelongsTo
```

Mappings:

```text
student
  -> User via student_id

invalidatedAttempt
  -> AssessmentAttempt via invalidated_attempt_id

replacementAttempt
  -> AssessmentAttempt via replacement_attempt_id

grantedBy
  -> User via granted_by_user_id
```

Do not add grant/validation workflow methods to the model.

---

# 19. Required Inverse Relationships

Add only these new inverse relationships.

## 19.1 `Assessment`

Add:

```text
blitzTask(): HasOne
blitzAttemptExceptions(): HasMany
```

Do not change existing:

```text
homeworkAssignment
recipients
attempts
questions
resultPairAsHomework
resultPairAsBlitz
```

## 19.2 `AssessmentStudent`

Add:

```text
blitzAttemptExceptions(): HasMany
```

using:

```text
assessment_student_id
```

## 19.3 `AssessmentAttempt`

Add:

```text
invalidatingBlitzException(): HasOne
replacementBlitzException(): HasOne
```

Mappings:

```text
invalidatingBlitzException
  -> BlitzAttemptException.invalidated_attempt_id

replacementBlitzException
  -> BlitzAttemptException.replacement_attempt_id
```

Do not change existing Attempt answer/student/assessment relationships.

## 19.4 `Institution`

Add:

```text
blitzTasks(): HasMany
blitzAttemptExceptions(): HasMany
```

## 19.5 `User`

Add:

```text
activatedBlitzTasks(): HasMany
blitzAttemptExceptions(): HasMany
grantedBlitzAttemptExceptions(): HasMany
```

Mappings:

```text
activatedBlitzTasks
  -> BlitzTask.activated_by_user_id

blitzAttemptExceptions
  -> BlitzAttemptException.student_id

grantedBlitzAttemptExceptions
  -> BlitzAttemptException.granted_by_user_id
```

Do not add a direct `Topic -> BlitzTask` relationship; Blitz task context already resolves through `Topic -> Assessment -> BlitzTask`.

---

# 20. `BlitzTaskFactory`

Create:

```text
Database\Factories\BlitzTaskFactory
```

Factories are deterministic test infrastructure, not production defaults.

## 20.1 Default

Default creates a same-Institution:

```text
Assessment.type = blitz
BlitzTask.status = draft
duration_seconds = 600
```

with:

```text
scheduled_at = null
timer_start_mode_snapshot = null
activated_at = null
synchronized_ends_at = null
closed_at = null
archived_at = null
activated_by_user_id = null
```

`600` is a **test-fixture value only**.

It is not a product/runtime default.

`institution_id` must be derived from the linked Assessment.

## 20.2 Required readable states

Provide states sufficient to create every valid structural lifecycle family:

```text
draft()
scheduled()
activeSynchronized()
activeIndividual()
closedSynchronized()
closedIndividual()
archivedFromDraft()
archivedFromScheduled()
archivedAfterCloseSynchronized()
archivedAfterCloseIndividual()
```

Every state must satisfy:

- timestamp ordering;
- timer-shape constraint;
- same-Institution activator;
- synchronized end exactly equals activation + duration;
- individual synchronized end is null.

Prefer the linked Assessment's owning Teacher as the activation actor where practical.

Do not make factory states execute future application Actions.

---

# 21. `BlitzAttemptExceptionFactory`

Create:

```text
Database\Factories\BlitzAttemptExceptionFactory
```

Default graph must be structurally/domain-consistent for testing.

At minimum it must produce:

```text
one Blitz Assessment
one corresponding BlitzTask
one same-Institution AssessmentStudent recipient
one same Student
one normal Blitz Attempt #1
one same-Institution granting Teacher
one exception row
replacement_attempt_id = null
reason_type = technical
non-empty reason
```

The invalidated Attempt must be historical/non-editable and:

```text
attempt_number = 1
official_score_eligible = false
```

so the default factory does not create a graph that contradicts the meaning of an already-persisted exception.

Do not create replacement Attempt #2 by default.

A readable optional state may provide:

```text
withReplacementAttempt()
```

only if needed by the focused tests.

If provided, it must create:

```text
Attempt #2
same Assessment
same AssessmentStudent
same Student
same Institution
replacement_attempt_id = Attempt #2
```

without violating the delivered one-`in_progress` partial unique index.

Factories must never silently create cross-Institution links.

---

# 22. Existing Schema/Test Compatibility

The delivered Stage 6 schema test currently asserts that several future tables are absent.

Narrowly update:

```text
backend/tests/Feature/Persistence/AssessmentHomeworkSchemaInspectionTest.php
```

so:

```text
blitz_tasks
```

is no longer in the "must not exist" future-table list.

Continue to require these later-stage tables to remain absent:

```text
official_task_scores
topic_results
```

Do not rewrite the rest of the Stage 6 schema test.

Do not weaken any Stage 6 constraint/FK/index assertion.

No existing test should be changed merely to make an incorrect implementation pass.

---

# 23. No Existing Shared Schema Mutation

The Stage 8 migration must create only:

```text
blitz_tasks
blitz_attempt_exceptions
```

It must not alter:

```text
assessments
homework_assignments
assessment_students
assessment_attempts
topic_result_pairs
questions
attempt_answers
idempotency_records
```

The only exception would be a proven migration prerequisite that cannot be satisfied otherwise.

If such a prerequisite is discovered, return `BLOCKED` with exact evidence instead of independently widening the task.

---

# 24. Authorization / Tenant Boundary

This is persistence-only work.

There is no new public actor-driven API.

Therefore no Policy/Action authorization implementation belongs here.

Database requirements are still Tenant-sensitive:

- both new tables have direct `institution_id`;
- every new parent reference is same-Institution where the delivered parent support key exists;
- cross-Institution links are rejected by PostgreSQL FKs;
- actor/Student role semantics remain later application validation;
- UUID knowledge does not imply access.

Do not add global scopes or hidden automatic Tenant filtering to the models.

---

# 25. Concurrency Boundary

This task does not implement concurrent grant/start/activation workflows.

Database support created here must enable later concurrency-safe Actions:

- one exception per `(assessment_id, student_id)`;
- one use of `invalidated_attempt_id`;
- one use of non-null `replacement_attempt_id`;
- existing one-in-progress Attempt partial unique index remains unchanged.

Do not add row-locking services in this task.

Do not add event/listener logic.

---

# 26. Expected File Scope

### Create

```text
backend/database/migrations/<timestamp>_create_blitz_persistence_domain_foundation.php

backend/app/Enums/BlitzStatus.php
backend/app/Enums/BlitzAttemptExceptionReasonType.php

backend/app/Models/BlitzTask.php
backend/app/Models/BlitzAttemptException.php

backend/database/factories/BlitzTaskFactory.php
backend/database/factories/BlitzAttemptExceptionFactory.php

backend/tests/Feature/Persistence/BlitzPersistenceSchemaInspectionTest.php
backend/tests/Feature/Persistence/BlitzPersistenceTest.php
backend/tests/Feature/Persistence/BlitzFactoryModelTest.php
```

### Modify narrowly

```text
backend/app/Models/Assessment.php
backend/app/Models/AssessmentStudent.php
backend/app/Models/AssessmentAttempt.php
backend/app/Models/Institution.php
backend/app/Models/User.php

backend/tests/Feature/Persistence/AssessmentHomeworkSchemaInspectionTest.php
```

Changes outside this list require a concrete necessity directly caused by this contract and must be reported.

Forbidden scope includes:

```text
backend/routes/
backend/app/Http/
backend/app/Actions/
backend/app/Support/Teacher/
backend/app/Support/Student/
backend/app/Console/
frontend/
docs/
tasks/
seeders/
composer.json
composer.lock
```

unless an exact unavoidable blocker is first reported.

---

# 27. Required Focused Tests

Create exactly focused persistence tests in the established `Feature/Persistence` style.

## 27.1 `BlitzPersistenceSchemaInspectionTest`

Verify at least:

### Tables and exact columns

```text
blitz_tasks
blitz_attempt_exceptions
```

with exact contract columns, types, nullability, lengths, and primary keys.

### Named checks

Verify:

```text
blitz_tasks_status_check
blitz_tasks_duration_check
blitz_tasks_timer_mode_check
blitz_tasks_lifecycle_check
blitz_tasks_timer_shape_check
blitz_tasks_activated_order_check
blitz_tasks_closed_order_check
blitz_tasks_archived_order_check

blitz_attempt_exceptions_reason_type_check
blitz_attempt_exceptions_reason_not_empty_check
blitz_attempt_exceptions_distinct_attempts_check
```

### Unique constraints/indexes

Verify:

```text
blitz_tasks_institution_assessment_unique

blitz_attempt_exceptions_assessment_student_unique
blitz_attempt_exceptions_invalidated_attempt_unique
blitz_attempt_exceptions_replacement_attempt_unique

blitz_tasks_institution_status_scheduled_index
blitz_tasks_institution_activated_index
blitz_tasks_institution_synchronized_ends_index
blitz_attempt_exceptions_institution_assessment_student_index
```

### Foreign keys

Verify exact restrictive Tenant-safe definitions from Sections 11 and 17.

### Existing shared foundation preserved

Verify:

```text
assessment_attempts_one_in_progress_per_student_unique
```

still exists.

Do not require a new Blitz-specific Attempt table/index.

## 27.2 `BlitzPersistenceTest`

Cover:

- valid draft Blitz row;
- valid scheduled row;
- valid synchronized active row;
- valid individual active row;
- valid synchronized closed row;
- valid individual closed row;
- valid archive from draft;
- valid archive from scheduled;
- valid archive after synchronized close;
- valid archive after individual close;
- invalid status rejected;
- zero/negative duration rejected;
- invalid timer mode rejected;
- draft with activation fields rejected;
- scheduled without `scheduled_at` rejected;
- active without activation actor rejected;
- active without timer snapshot rejected;
- synchronized active without exact common end rejected;
- synchronized active with wrong common end rejected;
- individual active with non-null common end rejected;
- closed without activation rejected;
- active-direct-to-archived structural shape rejected;
- activation before creation rejected;
- close before activation rejected;
- archive before valid historical boundary rejected;
- cross-Institution Assessment rejected;
- cross-Institution activation actor rejected;
- restrictive parent deletion preserves history.

Exception cases:

- valid technical exception persists;
- valid `other_valid` exception persists;
- blank reason rejected;
- invalid reason type rejected;
- same Student/Blitz duplicate exception rejected;
- duplicate invalidated Attempt rejected;
- duplicate non-null replacement Attempt rejected;
- invalidated/replacement same UUID rejected;
- cross-Institution Assessment rejected;
- cross-Institution recipient rejected;
- cross-Institution Student rejected;
- cross-Institution invalidated Attempt rejected;
- cross-Institution replacement Attempt rejected;
- cross-Institution grantor rejected;
- restrictive parent deletion preserves exception history.

Do **not** expect PostgreSQL to reject same-Tenant semantic mismatches that this contract explicitly leaves to `S08-BE-009`, such as:

- referenced Assessment is same-Tenant but non-Blitz;
- recipient belongs to another same-Tenant Assessment;
- Attempt belongs to another same-Tenant Assessment;
- Attempt number is not #1/#2;
- grantor is same-Tenant but wrong role.

Those are later domain tests.

## 27.3 `BlitzFactoryModelTest`

Verify:

- exact `BlitzStatus::values()`;
- exact `BlitzAttemptExceptionReasonType::values()`;
- existing `BlitzTimerStartMode::values()` unchanged;
- `BlitzTask` key name/type/increment behavior;
- `BlitzTask` casts;
- `BlitzAttemptException` UUID/casts;
- all relationships in Sections 12, 18, and 19;
- default factories create same-Institution graphs;
- default BlitzTask Assessment is `AssessmentType::Blitz`;
- all BlitzTask lifecycle factory states satisfy DB constraints;
- default exception graph uses Attempt #1 and `official_score_eligible = false`;
- replacement remains null by default.

---

# 28. Directly Affected Regression Tests

Run the existing Stage 6 persistence tests because this task attaches new detail/history relations to the shared Assessment foundation and deliberately changes one forward-compatibility assertion:

```bash
php artisan test \
  tests/Feature/Persistence/AssessmentHomeworkSchemaInspectionTest.php \
  tests/Feature/Persistence/AssessmentHomeworkPersistenceTest.php \
  tests/Feature/Persistence/AssessmentHomeworkFactoryModelTest.php
```

Run the institution assessment-settings regression because its historical-preservation logic already conditionally observes future assessment tables and `blitz_tasks` will now exist:

```bash
php artisan test \
  tests/Feature/Institution/InstitutionAssessmentSettingsApiTest.php
```

No full backend suite at task level.

Full backend regression belongs to:

```text
S08-BE-PHASE-2
```

---

# 29. Verification Commands

Run from:

```text
backend/
```

## 29.1 New focused tests

```bash
php artisan test \
  tests/Feature/Persistence/BlitzPersistenceSchemaInspectionTest.php \
  tests/Feature/Persistence/BlitzPersistenceTest.php \
  tests/Feature/Persistence/BlitzFactoryModelTest.php
```

## 29.2 Direct regressions

```bash
php artisan test \
  tests/Feature/Persistence/AssessmentHomeworkSchemaInspectionTest.php \
  tests/Feature/Persistence/AssessmentHomeworkPersistenceTest.php \
  tests/Feature/Persistence/AssessmentHomeworkFactoryModelTest.php
```

```bash
php artisan test \
  tests/Feature/Institution/InstitutionAssessmentSettingsApiTest.php
```

## 29.3 Format

```bash
./vendor/bin/pint --test
```

No additional static-analysis command is required unless the current repository configuration already makes one mandatory for exactly the changed backend scope.

## 29.4 Always

From repository root:

```bash
git diff --check
```

Do not run:

- full backend suite;
- frontend tests;
- Flutter analyze/build;
- broad E2E;
- Stage integration harness.

---

# 30. Acceptance Criteria

## Persistence

- [ ] New forward migration creates `blitz_tasks`.
- [ ] New forward migration creates `blitz_attempt_exceptions`.
- [ ] No delivered migration is edited.
- [ ] No shared existing domain table is altered.
- [ ] Rollback drops exception table before Blitz task table.

## `blitz_tasks`

- [ ] Exact columns/types/nullability match Section 8.
- [ ] `assessment_id` is the primary key/shared Assessment identity.
- [ ] Direct Tenant ownership exists.
- [ ] Status values are exact.
- [ ] Duration must be positive.
- [ ] Draft may retain optional prepared `scheduled_at` while remaining `draft`.
- [ ] `scheduled` requires non-null `scheduled_at`.
- [ ] Other preactivation shapes are protected.
- [ ] Active/closed/postclose archive shapes are protected.
- [ ] Direct active→archived structural history is rejected.
- [ ] Timer snapshot values are exact.
- [ ] Synchronized end must exactly equal activation + duration.
- [ ] Individual mode requires null synchronized end.
- [ ] Timestamp ordering is enforced.
- [ ] Assessment and activation actor FKs are Tenant-safe/restrictive.
- [ ] Required query indexes exist.
- [ ] No attempt-limit/per-question timer column exists.

## Exceptions

- [ ] Exact columns/types/nullability match Section 13.
- [ ] Exactly one exception per Student/Blitz is structurally possible.
- [ ] One invalidated Attempt cannot be reused by multiple exception rows.
- [ ] Non-null replacement Attempt cannot be reused by multiple exception rows.
- [ ] Invalidated/replacement IDs cannot be identical.
- [ ] Reason type values are exact.
- [ ] Reason cannot be blank after trim.
- [ ] All foreign references are same-Institution protected.
- [ ] No trigger attempts to implement later grant business rules.
- [ ] Replacement Attempt is nullable until later Start.

## Existing shared foundation

- [ ] `AssessmentType::Blitz` is reused unchanged.
- [ ] `BlitzTimerStartMode` is reused unchanged.
- [ ] Existing Attempt status/finalization enums are unchanged.
- [ ] Existing Attempt number structural check remains 1..3.
- [ ] Existing one-in-progress partial unique index remains.
- [ ] Existing `topic_result_pairs.blitz_assessment_id` remains unchanged.
- [ ] No `blitz_attempts` or `blitz_answers` table exists.

## Models/factories

- [ ] `BlitzStatus` exact values.
- [ ] `BlitzAttemptExceptionReasonType` exact values.
- [ ] `BlitzTask` key/casts/relations correct.
- [ ] `BlitzAttemptException` casts/relations correct.
- [ ] Exact inverse relationships from Section 19 exist.
- [ ] Factories create valid same-Institution structures.
- [ ] Factory test duration does not become a runtime/product default.

## Regression/scope

- [ ] Existing Stage 6 schema test is changed only enough to stop asserting `blitz_tasks` absence.
- [ ] `official_task_scores` and `topic_results` remain outside this task.
- [ ] No route/controller/request/resource/action/scheduler change.
- [ ] No docs/task/frontend/seeder/dependency change.
- [ ] Focused tests pass.
- [ ] Directly affected regressions pass.
- [ ] Pint check passes.
- [ ] `git diff --check` passes.
- [ ] Focused diff self-check finds no unrelated scope.

---

# 31. Focused Diff Self-Check

Before reporting completion, verify:

```text
persistence/domain foundation only
```

Confirm:

- no public API;
- no lifecycle Action;
- no activation;
- no Student Start;
- no Answer mutation;
- no Submit;
- no timeout engine;
- no Scheduler;
- no exception grant workflow;
- no monitoring;
- no scoring/checking;
- no result-pair behavior change;
- no delivered migration rewrite;
- no duplicate timer enum;
- no duplicate Attempt/Answer subsystem;
- no unrelated refactor.

Review all new FKs for Tenant safety.

Review every new constraint/index name for explicit stable naming.

Review factories for accidental cross-Tenant graph creation.

---

# 32. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. migration filename;
4. `blitz_tasks` constraint/index/FK summary;
5. `blitz_attempt_exceptions` constraint/index/FK summary;
6. new enums/models/relationships/factories;
7. exact existing Stage 6 test adjustment;
8. focused test results;
9. directly affected regression results;
10. Pint result;
11. `git diff --check`;
12. final `git status --short`;
13. focused scope/diff self-check;
14. any blocker or deviation.

Do not claim Stage 8 backend complete.

After delivery, ChatGPT performs read-only acceptance review.

`S08-BE-002` remains blocked until:

```text
S08-BE-001 = Accepted / Delivered
```

---

# 33. Implementation Readiness Verdict

```text
Scope / non-goals                    = RESOLVED
Shared-vs-Blitz persistence boundary = RESOLVED
blitz_tasks schema                   = RESOLVED
Blitz lifecycle structure            = RESOLVED
Timer snapshot structure             = RESOLVED
Exception persistence                = RESOLVED
Enums                                = RESOLVED
Models / relationships               = RESOLVED
Factories                            = RESOLVED
Tenant-safe FKs                      = RESOLVED
Constraints / indexes                = RESOLVED
Concurrency DB backstops             = RESOLVED
Regression impact                    = RESOLVED
Acceptance criteria                  = RESOLVED
Focused verification                 = RESOLVED

Implementation Readiness Gate        = PASS
Execution dependency                 = S08-DOC-001 Accepted / Delivered
```
