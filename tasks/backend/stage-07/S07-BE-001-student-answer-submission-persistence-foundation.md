# Codex Implementation Contract: S07-BE-001 — Student Answer and Submission Persistence Foundation

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S07-BE-001` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Backend` |
| Status | `Approved` |
| Type | `Laravel/PostgreSQL persistence foundation` |
| Depends on | `S07-DOC-001 = Accepted / Delivered` before implementation |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Current review baseline | `origin/main @ b04833df22798c3c1ca42c3de3f0a0be01df4417` |
| Implementation baseline | ChatGPT re-checks current `origin/main` immediately before Codex starts |
| Readiness Gate | `PASS — contract corrected/revalidated`; execution remains blocked until `S07-DOC-001 = Accepted / Delivered` |
| Verification | focused backend persistence only |
| Delivery | Project Owner |
| Block checkpoint | Stage 7 Backend Phase 2 after `S07-BE-001…007` |

Do not create a duplicate `CODEX-PROMPT`.

## 2. Context Boundary

Codex may read only:
1. this contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. current Assessment/Question/File migrations, Models, factories and persistence tests directly required here.

Do not read roadmap/product/architecture/database/API docs, previous tasks, Stage history/indexes/closure reviews, or unrelated modules to determine requirements.

If current delivered code materially conflicts with this contract, return `BLOCKED` with exact evidence. Do not redesign.

## 3. Goal

Add the persistence/domain foundation for later Student Homework execution:

```text
AssessmentAttempt
  -> AttemptAnswer
       -> choice selections
       -> text value
       -> boolean value
       -> matching pairs
       -> ordering items
       -> fill-blank values
       -> one private Student submission file link
```

Also add:
- one-`in_progress` Attempt structural guard;
- durable DB-backed idempotency storage reusable by Stage 8.

No Student HTTP/lifecycle/scoring implementation belongs here.

## 4. Non-Goals

Do not implement:
- routes/controllers/Form Requests/Resources;
- Homework read API;
- Attempt start/resume action;
- official result-pair locking action;
- answer save/replace action;
- upload/download behavior;
- Submit/deadline/Teacher-close finalization;
- Scheduler;
- automatic/manual checking;
- scores/official scores/results;
- Blitz execution;
- frontend/E2E/seeders/docs/task bookkeeping;
- new package/dependency or unrelated refactor.

Do not edit delivered migrations. Use one new forward migration.

---

# 5. Migration

Create exactly:

```text
backend/database/migrations/2026_09_08_000000_create_student_answer_submission_persistence_foundation.php
```

If this filename already exists at implementation baseline for another delivered change: `BLOCKED`.

The migration must:
1. add tenant-reference unique keys to selected Question child tables;
2. add the one-in-progress Attempt partial unique index;
3. create all answer/file-link tables;
4. create `idempotency_records`;
5. roll back in reverse dependency order.

PostgreSQL behavior is authoritative.

## 5.1 Existing Question child tenant keys

Add:

```text
unique question_choice_options(institution_id, id)
  name: question_choice_options_institution_id_unique

unique question_matching_items(institution_id, id)
  name: question_matching_items_institution_id_unique

unique question_ordering_items(institution_id, id)
  name: question_ordering_items_institution_id_unique
```

`question_fill_blanks(institution_id,id)` already exists; do not duplicate it.

## 5.2 One in-progress Attempt

Add partial unique index:

```sql
unique (assessment_id, student_id)
where status = 'in_progress'
```

name:

```text
assessment_attempts_one_in_progress_per_student_unique
```

It must reject two concurrent persisted `in_progress` rows for the same Student/Assessment while allowing historical terminal Attempts.

This is a **shared `assessment_attempts` structural invariant**, not a Homework-only
predicate. It therefore applies to every Assessment type stored in this table,
including future Blitz Attempts:

```text
for one assessment_id + student_id
there may be at most one status = in_progress row
```

This does **not** implement Stage 8 Blitz workflow or exception behavior. It only
locks the structural rule that a future Blitz replacement/exception Attempt may
start only after the earlier Attempt for that same Student/Assessment is no
longer `in_progress`. Do not add Blitz runtime logic in BE-001.

### Existing-data precondition

Adding the partial unique index must be data-preserving. Before applying the new
index in the implementation environment, check for already-invalid duplicate
rows equivalent to:

```sql
select assessment_id, student_id, count(*)
from assessment_attempts
where status = 'in_progress'
group by assessment_id, student_id
having count(*) > 1;
```

Required outcome:

```text
no rows => continue
one or more rows => BLOCKED
```

If duplicates already exist, report exact affected `assessment_id` /
`student_id` evidence. Do **not** delete Attempts, choose a winner, change status,
auto-finalize, renumber, or otherwise repair historical data inside this task.

The forward migration itself must contain no duplicate-cleanup/backfill behavior.
If a deployment database violates this prerequisite, creation of the unique
index must fail rather than silently rewrite data.

Do not alter existing:

```text
unique(assessment_id, student_id, attempt_number)
```

---

# 6. Answer Tables

All new domain FKs use `ON DELETE RESTRICT`.

## 6.1 `attempt_answers`

| Column | Type | Null | Rule |
|---|---|---:|---|
| `id` | uuid | no | PK |
| `institution_id` | uuid | no | tenant |
| `attempt_id` | uuid | no | |
| `question_id` | uuid | no | |
| `checking_status` | varchar(30) | no | default `pending` |
| `awarded_points` | numeric(16,8) | yes | `>= 0` when present |
| `feedback` | text | yes | |
| `checked_by_user_id` | uuid | yes | |
| `checked_at` | timestamptz | yes | |
| `created_at` | timestamptz | no | |
| `updated_at` | timestamptz | no | |

Allowed `checking_status`:

```text
pending
auto_checked
waiting_for_teacher_review
teacher_checked
```

Required:

```text
unique(institution_id, id)
unique(attempt_id, question_id)
index(institution_id, checking_status, checked_at)
```

FKs:

```text
institution_id -> institutions.id
(institution_id, attempt_id) -> assessment_attempts(institution_id, id)
(institution_id, question_id) -> questions(institution_id, id)
(institution_id, checked_by_user_id) -> users(institution_id, id)
```

Stage 7 Student-created/replaced answer defaults:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

No auto-check callbacks/events.

## 6.2 `answer_choice_selections`

Used for `single_choice` + `multiple_choice`.

| Column | Type | Null |
|---|---|---:|
| `answer_id` | uuid | no |
| `option_id` | uuid | no |
| `institution_id` | uuid | no |
| `created_at` | timestamptz | no |

```text
primary key(answer_id, option_id)
```

FKs:

```text
institution_id -> institutions.id
(institution_id, answer_id) -> attempt_answers(institution_id, id)
(institution_id, option_id) -> question_choice_options(institution_id, id)
```

Do not add a surrogate ID or composite-key package.

Question ownership/cardinality remains later domain validation.

## 6.3 `answer_text_values`

Used for `short_written` + `open_written`.

| Column | Type | Null |
|---|---|---:|
| `answer_id` | uuid | no PK |
| `institution_id` | uuid | no |
| `text_value` | text | no |
| `created_at` | timestamptz | no |
| `updated_at` | timestamptz | no |

FKs:

```text
institution_id -> institutions.id
(institution_id, answer_id) -> attempt_answers(institution_id, id)
```

## 6.4 `answer_boolean_values`

Used for `true_false`.

| Column | Type | Null |
|---|---|---:|
| `answer_id` | uuid | no PK |
| `institution_id` | uuid | no |
| `boolean_value` | boolean | no |
| `created_at` | timestamptz | no |
| `updated_at` | timestamptz | no |

Same tenant/answer FKs as text values.

## 6.5 `answer_matching_pairs`

| Column | Type | Null |
|---|---|---:|
| `id` | uuid | no PK |
| `institution_id` | uuid | no |
| `answer_id` | uuid | no |
| `left_item_id` | uuid | no |
| `right_item_id` | uuid | no |
| `created_at` | timestamptz | no |

Required:

```text
unique(institution_id, id)
unique(answer_id, left_item_id)
unique(answer_id, right_item_id)
```

FKs:

```text
institution_id -> institutions.id
(institution_id, answer_id) -> attempt_answers(institution_id, id)
(institution_id, left_item_id) -> question_matching_items(institution_id, id)
(institution_id, right_item_id) -> question_matching_items(institution_id, id)
```

`left/right side` and same-Question validation are later domain rules, not triggers.

## 6.6 `answer_ordering_items`

| Column | Type | Null |
|---|---|---:|
| `id` | uuid | no PK |
| `institution_id` | uuid | no |
| `answer_id` | uuid | no |
| `ordering_item_id` | uuid | no |
| `submitted_position` | integer | no |
| `created_at` | timestamptz | no |

Required:

```text
submitted_position >= 0
unique(institution_id, id)
unique(answer_id, ordering_item_id)
unique(answer_id, submitted_position)
```

FKs:

```text
institution_id -> institutions.id
(institution_id, answer_id) -> attempt_answers(institution_id, id)
(institution_id, ordering_item_id) -> question_ordering_items(institution_id, id)
```

## 6.7 `answer_fill_blank_values`

| Column | Type | Null |
|---|---|---:|
| `id` | uuid | no PK |
| `institution_id` | uuid | no |
| `answer_id` | uuid | no |
| `blank_id` | uuid | no |
| `text_value` | text | no |
| `created_at` | timestamptz | no |
| `updated_at` | timestamptz | no |

Required:

```text
unique(institution_id, id)
unique(answer_id, blank_id)
```

FKs:

```text
institution_id -> institutions.id
(institution_id, answer_id) -> attempt_answers(institution_id, id)
(institution_id, blank_id) -> question_fill_blanks(institution_id, id)
```

## 6.8 `answer_files`

Links one existing private `files` row to one file-based answer.

| Column | Type | Null |
|---|---|---:|
| `id` | uuid | no PK |
| `institution_id` | uuid | no |
| `answer_id` | uuid | no |
| `file_id` | uuid | no |
| `created_at` | timestamptz | no |

Required:

```text
unique(institution_id, id)
unique(answer_id)
unique(file_id)
```

FKs:

```text
institution_id -> institutions.id
(institution_id, answer_id) -> attempt_answers(institution_id, id)
(institution_id, file_id) -> files(institution_id, id)
```

`files.category = student_submission`, uploader ownership, MIME/size and storage behavior are `S07-BE-006`, not DB triggers here.

---

# 7. Durable Idempotency Persistence

Create:

```text
idempotency_records
```

| Column | Type | Null |
|---|---|---:|
| `id` | uuid | no PK |
| `institution_id` | uuid | no |
| `user_id` | uuid | no |
| `operation` | varchar(80) | no |
| `idempotency_key` | uuid | no |
| `request_fingerprint` | char(64) | no |
| `result_resource_type` | varchar(80) | yes |
| `result_resource_id` | uuid | yes |
| `response_status` | smallint | yes |
| `completed_at` | timestamptz | yes |
| `created_at` | timestamptz | no |
| `updated_at` | timestamptz | no |

Required:

```text
unique(institution_id, id)

unique(institution_id, user_id, operation, idempotency_key)
  name: idempotency_records_scope_key_unique

index(institution_id, user_id, operation, created_at)
  name: idempotency_records_lookup_index
```

FKs:

```text
institution_id -> institutions.id
(institution_id, user_id) -> users(institution_id, id)
```

No FK for `result_resource_id`.

Checks:

```text
btrim(operation) <> ''

request_fingerprint ~ '^[0-9a-f]{64}$'

result_resource_type is null
OR btrim(result_resource_type) <> ''

response_status is null
OR response_status between 200 and 299

(
  completed_at is null
  AND result_resource_type is null
  AND result_resource_id is null
  AND response_status is null
)
OR
(
  completed_at is not null
  AND result_resource_type is not null
  AND result_resource_id is not null
  AND response_status is not null
)

completed_at is null OR completed_at >= created_at
```

MVP:
- no expiry/TTL;
- no automatic deletion;
- no cache-only substitute.

Database `operation` remains extensible; do not CHECK it against only Stage 7 values.

---

# 8. Enums

Create:

```text
backend/app/Enums/AttemptAnswerCheckingStatus.php
```

exact cases:

```text
Pending                 = pending
AutoChecked             = auto_checked
WaitingForTeacherReview = waiting_for_teacher_review
TeacherChecked          = teacher_checked
```

Create:

```text
backend/app/Enums/IdempotencyOperation.php
```

exact Stage 7 cases:

```text
StudentHomeworkAttemptStart  = student.homework.attempt.start
StudentHomeworkAttemptSubmit = student.homework.attempt.submit
```

Both follow current enum convention and expose:

```text
values(): array
```

Migration SQL must not depend on PHP enum execution.

---

# 9. Models

Use current `#[Fillable]`, `HasFactory`, `HasUuids`, cast and relationship conventions. Models contain representation/relationships only.

## Create

```text
AttemptAnswer
AnswerTextValue
AnswerBooleanValue
AnswerMatchingPair
AnswerOrderingItem
AnswerFillBlankValue
AnswerFile
IdempotencyRecord
```

Do **not** create a standalone normal `AnswerChoiceSelection` model; use the pivot through `AttemptAnswer::selectedOptions()`.

## `AttemptAnswer`

Casts:

```text
checking_status -> AttemptAnswerCheckingStatus
awarded_points  -> decimal:8
checked_at      -> datetime
```

Relations:

```text
institution()
attempt()
question()
checkedBy()
selectedOptions()
textValue()
booleanValue()
matchingPairs()
orderingItems()
fillBlankValues()
answerFile()
```

## `AnswerTextValue` / `AnswerBooleanValue`

Primary key is parent:

```text
answer_id
```

Configure non-incrementing string key; do not generate it with `HasUuids`.

Boolean model casts:

```text
boolean_value -> boolean
```

## UUID child models

Use `HasUuids` for:

```text
AnswerMatchingPair
AnswerOrderingItem
AnswerFillBlankValue
AnswerFile
IdempotencyRecord
```

`AnswerOrderingItem.submitted_position` casts to integer.

`IdempotencyRecord` casts:

```text
operation       -> IdempotencyOperation
response_status -> integer
completed_at    -> datetime
```

Do not place claim/replay logic inside `IdempotencyRecord`.

## Direct parent relation updates

Add only directly useful relations:

```text
AssessmentAttempt::answers()
Question::attemptAnswers()
File::answerFile()
User::idempotencyRecords()
```

Add Institution aggregate relations only if this matches its existing local convention; do not expand purely for symmetry.

---

# 10. Factories

Create:

```text
AttemptAnswerFactory
AnswerTextValueFactory
AnswerBooleanValueFactory
AnswerMatchingPairFactory
AnswerOrderingItemFactory
AnswerFillBlankValueFactory
AnswerFileFactory
IdempotencyRecordFactory
```

No factory for the choice pivot.

Defaults must produce a **domain-coherent same-tenant graph**, not merely UUIDs
that happen to belong to the same Institution.

`AttemptAnswerFactory` default must derive one `AssessmentAttempt` first and then
use a Question from that **same Assessment and Institution**:

```text
attempt.institution_id = answer.institution_id
question.institution_id = answer.institution_id
question.assessment_id = attempt.assessment_id
```

The default must never independently create a Question on a different Assessment.

`AttemptAnswerFactory` checking defaults:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

Typed child factories must derive `institution_id` from their parent
`AttemptAnswer`; they must not independently create a mismatched tenant graph.

`AnswerFileFactory` must produce a structurally valid file-answer graph:

```text
AttemptAnswer.question.type = file_based
File.institution_id = AttemptAnswer.institution_id
File.category = student_submission
File.uploaded_by_user_id = AttemptAnswer.attempt.student_id
File.removed_at = null
```

The File row may be created through the existing File factory/state helpers, but
the resulting uploader must be the Student who owns the parent Attempt, not the
FileFactory's default Teacher.

`AnswerFileFactory` performs no physical storage I/O.

`IdempotencyRecordFactory` must use a User from the same Institution, a lowercase
SHA-256-shaped fingerprint, and internally valid completion metadata.

---

# 11. Typed Mapping

The persistence mapping is locked:

| Question | Storage |
|---|---|
| `single_choice` | `answer_choice_selections` |
| `multiple_choice` | `answer_choice_selections` |
| `true_false` | `answer_boolean_values` |
| `short_written` | `answer_text_values` |
| `open_written` | `answer_text_values` |
| `file_based` | `answer_files` |
| `matching` | `answer_matching_pairs` |
| `ordering` | `answer_ordering_items` |
| `fill_in_blank` | `answer_fill_blank_values` |

Do not add generic JSON answer columns or duplicate correct-answer configuration into Student rows.

Cross-type exclusivity and same-Question semantic validation are later answer-mutation domain rules.

---

# 12. Historical / Tenant Integrity

Use tenant-preserving composite FKs wherever specified above.

PostgreSQL must reject cross-Institution links between:
- Answer and Attempt;
- Answer and Question;
- choice and option;
- matching and items;
- ordering and item;
- fill value and blank;
- AnswerFile and File;
- typed child and parent Answer;
- IdempotencyRecord and User.

Do not add PostgreSQL RLS.

Use `ON DELETE RESTRICT`; no cascade deletion of Student submission history.

---

# 13. Migration Rollback

Conceptual reverse order:

```text
drop idempotency_records
drop answer_files
drop answer_fill_blank_values
drop answer_ordering_items
drop answer_matching_pairs
drop answer_boolean_values
drop answer_text_values
drop answer_choice_selections
drop attempt_answers

drop assessment_attempts_one_in_progress_per_student_unique

drop question_ordering_items_institution_id_unique
drop question_matching_items_institution_id_unique
drop question_choice_options_institution_id_unique
```

Do not touch unrelated Stage 5/6 schema.

---

# 14. Expected Files

## Create

```text
backend/database/migrations/2026_09_08_000000_create_student_answer_submission_persistence_foundation.php

backend/app/Enums/AttemptAnswerCheckingStatus.php
backend/app/Enums/IdempotencyOperation.php

backend/app/Models/AttemptAnswer.php
backend/app/Models/AnswerTextValue.php
backend/app/Models/AnswerBooleanValue.php
backend/app/Models/AnswerMatchingPair.php
backend/app/Models/AnswerOrderingItem.php
backend/app/Models/AnswerFillBlankValue.php
backend/app/Models/AnswerFile.php
backend/app/Models/IdempotencyRecord.php

backend/database/factories/AttemptAnswerFactory.php
backend/database/factories/AnswerTextValueFactory.php
backend/database/factories/AnswerBooleanValueFactory.php
backend/database/factories/AnswerMatchingPairFactory.php
backend/database/factories/AnswerOrderingItemFactory.php
backend/database/factories/AnswerFillBlankValueFactory.php
backend/database/factories/AnswerFileFactory.php
backend/database/factories/IdempotencyRecordFactory.php

backend/tests/Feature/Persistence/StudentAnswerSubmissionSchemaInspectionTest.php
backend/tests/Feature/Persistence/StudentAnswerSubmissionPersistenceTest.php
backend/tests/Feature/Persistence/StudentAnswerSubmissionFactoryModelTest.php
```

## Modify only if required for relations

```text
backend/app/Models/AssessmentAttempt.php
backend/app/Models/Question.php
backend/app/Models/File.php
backend/app/Models/User.php
backend/app/Models/Institution.php
```

No routes/controllers/actions/requests/resources/scheduler/docs/frontend files.

---

# 15. Focused Tests

## `StudentAnswerSubmissionSchemaInspectionTest`

Inspect actual PostgreSQL and verify:
- all nine new tables exist;
- exact columns/nullability;
- checking-status / score / ordering / idempotency checks;
- all unique rules and tenant FKs;
- three added Question child composite uniques;
- partial unique index predicate on `assessment_attempts`;
- idempotency scope unique/index.

## `StudentAnswerSubmissionPersistenceTest`

Cover at minimum:

### AttemptAnswer
- valid same-tenant row;
- duplicate Attempt+Question rejected;
- foreign Attempt rejected;
- foreign Question rejected;
- invalid checking status rejected;
- negative awarded points rejected.

### one-in-progress index
- one allowed;
- second same Student/Assessment rejected;
- terminal historical row + one in-progress allowed;
- the same structural invariant is verified for a Blitz-typed Assessment without implementing Blitz runtime behavior.

### typed children
- choice duplicate + cross-tenant option rejection;
- text/boolean parent tenant rejection;
- matching duplicate left/right + cross-tenant item rejection;
- ordering duplicate item/position + negative position + cross-tenant item rejection;
- fill duplicate blank + cross-tenant blank rejection;
- AnswerFile one-per-answer + unique file + cross-tenant file rejection.

Do not expect DB enforcement of same-Question semantic rules or file category.

### idempotency
- valid completed record;
- same key allowed for different User / Institution / operation;
- duplicate same scope rejected;
- cross-tenant User rejected;
- malformed fingerprint rejected;
- non-2xx status rejected;
- invalid partial completion shape rejected;
- transaction rollback leaves no committed claim row.

No claim/replay service tests in this task.

## `StudentAnswerSubmissionFactoryModelTest`

Verify:
- exact enum values;
- casts listed above;
- main relationships;
- factory tenant consistency;
- `AttemptAnswerFactory` Question uses the same Assessment as the parent Attempt;
- typed child factories inherit the parent Answer Institution;
- AttemptAnswer pending/null checking defaults;
- `AnswerFileFactory` uses a `file_based` Question;
- `AnswerFileFactory` File is `student_submission`, same-Institution, active, and uploaded by the parent Attempt's Student;
- `IdempotencyRecordFactory` User belongs to the same Institution;
- no real storage I/O.

---

# 16. Directly Affected Regression Tests

Because this migration changes existing `assessment_attempts` and selected Question child constraints, also run:

```text
tests/Feature/Persistence/AssessmentHomeworkSchemaInspectionTest.php
tests/Feature/Persistence/AssessmentHomeworkPersistenceTest.php
tests/Feature/Persistence/AssessmentHomeworkFactoryModelTest.php

tests/Feature/Persistence/QuestionSchemaInspectionTest.php
tests/Feature/Persistence/QuestionPersistenceTest.php
tests/Feature/Persistence/QuestionFactoryModelTest.php

tests/Feature/Persistence/TopicLearningMaterialSchemaInspectionTest.php
tests/Feature/Persistence/TopicLearningMaterialPersistenceTest.php
tests/Feature/Persistence/TopicLearningMaterialFactoryModelTest.php
```

The Stage 5 Topic/Learning-Material persistence regressions are required because
BE-001 adds `File::answerFile()` and builds `AnswerFileFactory` on the existing
shared `files` model/factory graph.

Do not run full backend suite; that belongs to Backend Phase 2.

---

# 17. Verification

Run from `backend/` through the repository's normal backend/container wrapper.

Run the exact backend format check:

```bash
./vendor/bin/pint --test
```

No additional broad static-analysis command is required for this persistence-only
task unless the current repository configuration makes one mandatory for the
changed files.

Then run exactly the focused/new + directly affected regression set:

```bash
php artisan test \
  tests/Feature/Persistence/StudentAnswerSubmissionSchemaInspectionTest.php \
  tests/Feature/Persistence/StudentAnswerSubmissionPersistenceTest.php \
  tests/Feature/Persistence/StudentAnswerSubmissionFactoryModelTest.php \
  tests/Feature/Persistence/AssessmentHomeworkSchemaInspectionTest.php \
  tests/Feature/Persistence/AssessmentHomeworkPersistenceTest.php \
  tests/Feature/Persistence/AssessmentHomeworkFactoryModelTest.php \
  tests/Feature/Persistence/QuestionSchemaInspectionTest.php \
  tests/Feature/Persistence/QuestionPersistenceTest.php \
  tests/Feature/Persistence/QuestionFactoryModelTest.php \
  tests/Feature/Persistence/TopicLearningMaterialSchemaInspectionTest.php \
  tests/Feature/Persistence/TopicLearningMaterialPersistenceTest.php \
  tests/Feature/Persistence/TopicLearningMaterialFactoryModelTest.php
```

Then:

```bash
git diff --check
```

and focused diff/scope self-review.

Do not run:
- full backend suite;
- frontend checks/build;
- E2E/integration.

---

# 18. Acceptance Criteria

PASS only if:

- exact typed answer/file/idempotency schema exists;
- no generic JSON answer payload exists;
- tenant composite FKs are enforced;
- one file per answer and unique file reuse are enforced;
- one `in_progress` Attempt per Student/Assessment is structurally enforced for the shared Attempt table, including Blitz-typed Assessments;
- pre-existing duplicate `in_progress` rows are never silently repaired; they block implementation/migration application;
- historical terminal Attempts remain valid;
- durable idempotency scope is exactly Institution+User+operation+key;
- idempotency fingerprint/completion checks are enforced;
- no TTL/cache-only idempotency is introduced;
- required enums/models/factories exist and remain persistence-focused;
- factories produce same-Assessment/same-Student coherent answer/file graphs as specified;
- no API/lifecycle/finalization/storage/scoring functionality leaked into BE-001;
- new focused tests and all named Assessment/Question/File regressions pass;
- `./vendor/bin/pint --test` and `git diff --check` pass.

Locked implementation choices:

```text
typed normalized answer tables
PostgreSQL partial unique in-progress guard on shared assessment_attempts
at most one in_progress per Student/Assessment for every Assessment type
choice selections as pivot, no composite-key package
initial checking_status = pending
answer_files -> existing files table
durable PostgreSQL idempotency_records
ON DELETE RESTRICT
no idempotency TTL in MVP
```

---

# 19. Completion Report

Return only:

```text
IMPLEMENTATION COMPLETE
```

or:

```text
BLOCKED
```

with:
1. concise implementation summary;
2. changed files/purpose;
3. exact focused verification results;
4. named regressions;
5. `git diff --check`;
6. scope/non-goal confirmation;
7. deviations/blockers;
8. final `git status --short`.

Do not claim `Accepted`.
Do not commit/push/create PR/update Stage bookkeeping unless explicitly instructed later.
