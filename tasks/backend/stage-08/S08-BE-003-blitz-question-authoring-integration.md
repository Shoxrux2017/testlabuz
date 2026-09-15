# Codex Implementation Contract: S08-BE-003 — Blitz Question Authoring Integration

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-BE-003` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel shared Teacher Question mutation integration for Homework + Blitz` |
| Depends on | `S08-DOC-001 — Accepted / Delivered`; `S08-BE-001 — Accepted / Delivered`; `S08-BE-002 — Accepted / Delivered` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` after dependencies are delivered and immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |
| Backend block checkpoint | `Stage 8 Backend Phase 2` after `S08-BE-001…010` are `Accepted / Delivered` |
| Blocks | `S08-BE-004` |

Start only when:

```text
S08-DOC-001 = Accepted / Delivered
S08-BE-001  = Accepted / Delivered
S08-BE-002  = Accepted / Delivered
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
4. delivered S08-BE-001/S08-BE-002 backend source/tests directly required by this task;
5. current shared Teacher Question mutation source/tests;
6. current Homework authoring/access/resource code directly required to preserve regression behavior.

Do **not** read:

- `docs/01–09`;
- roadmap files;
- Stage indexes;
- `S08-DOC-001`;
- previous implementation task files;
- Stage history;
- closure reviews;
- frontend code

to determine requirements.

The requirements below already resolve:

- exact endpoints;
- Homework/Blitz dispatch;
- authorization;
- lifecycle/editability;
- result-pair behavior;
- Question add/update/delete/reorder semantics;
- total-point maintenance;
- response projection;
- no-op/timestamp behavior;
- concurrency;
- regression boundaries;
- focused tests/verification.

If the delivered dependency implementation materially conflicts with this contract, return:

```text
BLOCKED
```

with exact file/line evidence.

Do not independently redesign the Question API, Blitz lifecycle, result-pair semantics, or shared Assessment architecture.

---

# 3. Goal

Extend the already-delivered Assessment-oriented Teacher Question mutation endpoints so they work for **both**:

```text
Homework
Blitz
```

without weakening any existing Homework editing-integrity rule.

The shared Question endpoints already use Assessment-oriented URLs, but the delivered implementation is still Homework-specific:

```text
TeacherHomeworkAccess
TeacherQuestionMutationAccess -> HomeworkAssignment
ShowTeacherHomework
TeacherHomeworkResource
```

This task converts that implementation into a true shared Assessment Question authoring boundary.

At completion:

- Homework Question mutation behaves exactly as before;
- editable Blitz Questions can use all nine supported types;
- Blitz Question mutation is allowed only before activation;
- active/closed/archived Blitz content is immutable to Teacher Question authoring;
- shared endpoints return the complete authoritative parent resource of the correct type;
- no Question persistence schema is duplicated.

---

# 4. Existing Public Endpoints — No Route Expansion

Do not add new Question routes.

Continue using exactly:

```text
POST   /api/v1/teacher/assessments/{assessment}/questions
PATCH  /api/v1/teacher/questions/{question}
DELETE /api/v1/teacher/questions/{question}
POST   /api/v1/teacher/assessments/{assessment}/questions/reorder
```

All remain inside the existing Teacher middleware group:

```text
auth:sanctum
active.account
password.changed
role:teacher
```

Do not create:

```text
/teacher/blitz/{blitz}/questions
/teacher/homework/{homework}/questions
```

aliases.

The existing Assessment-oriented route family is the canonical shared authoring API.

---

# 5. Explicit Non-Goals

Do not implement or change:

- Blitz create/list/detail/PATCH/schedule/archive behavior except direct projection/reuse required here;
- official Blitz designation;
- result-pair PUT;
- Blitz activation;
- Blitz close;
- Student recipient activation snapshot;
- official cohort establishment/reuse;
- Student Blitz read;
- Student Start/Resume;
- Student answer/file mutation;
- Submit;
- timeout reconciliation;
- Scheduler;
- Attempt exception;
- monitoring;
- checking/scoring;
- official scores;
- Topic results;
- Question database schema;
- Question answer schema;
- frontend;
- E2E seed/harness;
- dependencies;
- docs;
- tasks/Stage bookkeeping.

Do not add:

- new Question types;
- generic JSON Question configuration storage;
- Question version tables;
- per-question timer;
- Question soft deletes;
- client-controlled `total_possible_points`;
- client-controlled Question child-row IDs;
- fuzzy/AI checking;
- negative marking.

Do not edit migrations.

---

# 6. Delivered Shared Question Contract to Preserve

The current Question system already owns:

```text
QuestionType
QuestionCheckingMode
QuestionAuthoringLimits
QuestionConfigurationValidator
QuestionConfigurationWriter
QuestionPositionWriter
QuestionPositionSetValidator
AssessmentPointMath
TeacherQuestionResource
```

and the typed tables for all nine supported types.

Reuse them exactly.

Do not duplicate validation/writer logic for Blitz.

The supported types remain exactly:

```text
single_choice
multiple_choice
true_false
short_written
open_written
file_based
matching
ordering
fill_in_blank
```

The existing configuration/checking-mode rules remain unchanged.

---

# 7. Core Type-Specific Editing Rule

Question authoring is scoring/fairness-relevant content.

The shared access layer must apply different lifecycle rules based on:

```text
Assessment.type
```

## 7.1 Homework

Preserve the delivered Stage 6 behavior exactly.

Homework Question mutation is allowed only when:

```text
Topic status = draft | active
Homework status = draft | active
no Assessment Attempt exists
official Homework result-pair row is not locked
```

If the official Homework pair has:

```text
locked_at != null
```

return:

```text
409 result_pair_locked
```

even if a corrupted fixture has no Attempt row.

An active Homework must never be left with:

```text
0 Questions
or
total_possible_points = 0
```

A mutation that would do so returns:

```text
409 assessment_has_no_scoreable_points
```

and rolls back.

All existing Homework semantics, errors, response shapes, positions, point calculation, and timestamps remain unchanged.

## 7.2 Blitz

Blitz Question mutation is allowed only when:

```text
Topic status = draft | active
Blitz status = draft | scheduled
no Assessment Attempt exists
```

Blitz Question mutation is **not** allowed after activation.

This is intentional even when no Student Attempt exists yet.

Reason:

- synchronized activation may already have started the common class timer;
- individual activation has already exposed the executable task;
- changing Questions after activation would change the meaning of the live timed assessment.

Therefore:

```text
Blitz active   -> 409 business_conflict
Blitz closed   -> 409 task_closed
Blitz archived -> 409 task_archived
```

Draft/Scheduled Blitz may temporarily contain:

```text
0 Questions
total_possible_points = 0
```

because `S08-BE-004` activation later validates positive scoreable points.

Question mutation must not:

- change Blitz lifecycle;
- change `scheduled_at`;
- change duration;
- snapshot timer mode;
- create recipients;
- create Attempts.

---

# 8. Critical Result-Pair Difference

The existing Homework access rule:

```text
official pair locked -> Question mutation blocked
```

must **not** be blindly applied to Blitz.

## 8.1 Why

The Topic result pair may already be:

```text
locked_at != null
```

because official Homework Student activity began **before** the official Blitz existed.

Stage 8 explicitly allows the previously-null Blitz side to be attached later.

Therefore a locked result pair may validly contain:

```text
homework_assessment_id = official Homework
blitz_assessment_id    = this draft/scheduled Blitz
locked_at               = historical Homework lock
```

while the Blitz still needs pre-activation authoring.

## 8.2 Blitz rule

For a Blitz in:

```text
draft
scheduled
```

the pair's existing:

```text
locked_at
cohort_snapshotted_at
```

do **not** by themselves block Question mutation.

Question mutation must preserve the pair exactly.

Do not:

- clear `locked_at`;
- change cohort;
- change official Homework;
- change official Blitz;
- change designation timestamps.

If a Blitz Attempt exists unexpectedly, Question mutation is blocked by the Attempt-integrity rule.

Once the Blitz is active, its lifecycle already blocks Question mutation.

Thus there is no need to overload historical Homework pair locking as a Blitz-content lock.

---

# 9. Shared Access Architecture

Refactor the existing:

```text
TeacherQuestionMutationAccess
```

into the single shared Question-mutation access boundary.

Do not create a second duplicate Blitz Question access service.

It must now depend on:

```text
TeacherHomeworkAccess
TeacherBlitzAccess
```

from the delivered implementations.

## 9.1 Required preliminary resolvers

Add:

```text
resolveAssessment(User $teacher, string $assessmentId): Assessment
resolveAssessmentForQuestion(User $teacher, string $questionId): Assessment
```

Both must resolve privacy-safely across:

```text
AssessmentType::Homework
AssessmentType::Blitz
```

only.

## 9.2 Assessment route resolution

For:

```text
POST /teacher/assessments/{assessment}/questions
POST /teacher/assessments/{assessment}/questions/reorder
```

resolve only Assessment rows satisfying:

```text
same Institution
teacher_id = authenticated Teacher
type in (homework, blitz)
owning Topic currently visibleToTeacher
required type-specific detail row exists
```

Malformed UUID, foreign-Tenant, another Teacher, ended Group membership, inaccessible Topic, or structurally missing detail row:

```text
404 resource_not_found
```

## 9.3 Question route resolution

For:

```text
PATCH /teacher/questions/{question}
DELETE /teacher/questions/{question}
```

never:

```text
Question::find($id)
-> authorize later
```

Resolve through:

```text
Teacher
-> same-Tenant owned Assessment
-> authorized Topic/current Group membership
-> Question in that Assessment
```

Malformed, foreign, another Teacher's, or inaccessible Question:

```text
404 resource_not_found
```

Do not reveal whether a foreign/private UUID exists.

---

# 10. Shared Locked Context

`TeacherQuestionMutationAccess::lock(...)` must lock the type-specific parent context before Questions.

The returned context may use this exact semantic shape:

```text
assessment: Assessment
task: HomeworkAssignment | BlitzTask
questions: Collection<Question>
```

A dedicated small typed DTO is permitted only if it expresses exactly this contract and does not create a generic framework.

Do not return a fake common lifecycle model.

## 10.1 Required lock order

Within one DB transaction:

```text
1. Group
2. current Teacher–Group membership
3. Topic
4. Assessment
5. type-specific detail row:
     HomeworkAssignment
     OR
     BlitzTask
6. TopicResultPair when relevant
7. AssessmentAttempt rows ordered by id
8. Question rows ordered by position, then id
9. typed Question configuration rows only when the mutation needs them
```

Use existing access helpers so Group/membership/Topic ordering remains consistent with Teacher Homework/Blitz mutation flows.

All locks are Tenant-scoped.

---

# 11. Homework Locked Context — Preserve Exact Behavior

For:

```text
Assessment.type = homework
```

reuse:

```text
TeacherHomeworkAccess::lockHomework(...)
```

Then lock the Topic result pair using the existing same-Topic/Homework identity rule.

Lock all Assessment Attempt rows ordered by `id`.

Lock all Questions ordered by:

```text
position
id
```

Then enforce, in the delivered error precedence:

1. Topic closed/archived:
   ```text
   409 topic_not_editable
   ```
2. Homework closed:
   ```text
   409 task_closed
   ```
3. Homework archived:
   ```text
   409 task_archived
   ```
4. official Homework pair locked:
   ```text
   409 result_pair_locked
   ```
5. any Attempt exists:
   ```text
   409 business_conflict
   ```

Do not alter this precedence without a concrete dependency conflict.

---

# 12. Blitz Locked Context

For:

```text
Assessment.type = blitz
```

reuse delivered:

```text
TeacherBlitzAccess
```

to lock:

```text
Group
membership
Topic
Assessment
BlitzTask
```

Then lock any Topic result pair for the Topic where:

```text
blitz_assessment_id = assessment.id
```

if present.

Lock Assessment Attempts ordered by `id`.

Lock Questions ordered by:

```text
position
id
```

Then enforce:

1. Topic closed/archived:
   ```text
   409 topic_not_editable
   ```
2. Blitz active:
   ```text
   409 business_conflict
   ```
3. Blitz closed:
   ```text
   409 task_closed
   ```
4. Blitz archived:
   ```text
   409 task_archived
   ```
5. any Attempt exists:
   ```text
   409 business_conflict
   ```

Allowed status:

```text
draft
scheduled
```

Do **not** reject merely because:

```text
TopicResultPair.locked_at != null
```

for Blitz.

Do not mutate the result pair.

---

# 13. Parent Projection After Mutation

Every successful Question mutation must still return the **complete authoritative parent authoring resource**.

Required behavior:

```text
Homework Question mutation
-> complete TeacherHomeworkResource

Blitz Question mutation
-> complete TeacherBlitzResource
```

Do not change existing Homework API JSON shape.

Do not return only a Question.

Do not return a generic database Assessment resource.

---

# 14. `ShowTeacherAssessmentAuthoring`

Create one focused type dispatcher:

```text
App\Actions\Teacher\ShowTeacherAssessmentAuthoring
```

or an equivalently exact focused class.

Responsibility only:

```text
AssessmentType::Homework
  -> ShowTeacherHomework

AssessmentType::Blitz
  -> ShowTeacherBlitz
```

It returns the fully loaded `Assessment` projection required by the corresponding Teacher resource.

It must not:

- authorize independently outside the delegated show behavior;
- mutate;
- query unrelated types;
- contain lifecycle decisions.

Unexpected type:

```text
LogicException
```

because only delivered `homework|blitz` Assessment types are valid.

Use this dispatcher in all four Question mutation Actions.

---

# 15. `TeacherAssessmentAuthoringResource`

Create one presentation dispatcher:

```text
App\Http\Resources\Teacher\TeacherAssessmentAuthoringResource
```

Responsibility:

```text
AssessmentType::Homework
  -> serialize exactly as TeacherHomeworkResource

AssessmentType::Blitz
  -> serialize exactly as TeacherBlitzResource
```

It must not execute queries.

It must not authorize.

It must not mutate.

It must not invent a new generic payload.

This wrapper exists only so the shared Question controller can preserve the correct type-specific parent response.

Unexpected type:

```text
LogicException
```

---

# 16. Controller Refactor

Update:

```text
TeacherQuestionController
```

to use:

```text
TeacherAssessmentAuthoringResource
```

instead of hard-coded:

```text
TeacherHomeworkResource
```

Rename local variables from:

```text
$homework
```

to:

```text
$assessment
```

or equivalent generic naming.

Keep exact existing success statuses/messages:

## Add

```text
201 Created
Question created successfully.
```

## Update

```text
200 OK
Question updated successfully.
```

## Delete

```text
200 OK
Question deleted successfully.
```

## Reorder

```text
200 OK
Questions reordered successfully.
```

Do not change the route contract.

---

# 17. Request Contracts — Preserve Existing Shared Requests

Continue using the delivered:

```text
TeacherQuestionCreateRequest
TeacherQuestionUpdateRequest
TeacherQuestionDeleteRequest
TeacherQuestionReorderRequest
```

Do not create Blitz-specific copies.

The Question request shapes remain Assessment-type independent.

Existing strict JSON/query behavior remains authoritative.

## 17.1 Add request

Accepted exact keys:

```text
type
prompt
instructions
points
position
checking_mode
configuration
```

No top-level `client_key`.

No query parameters.

## 17.2 Update request

Accepted keys:

```text
type
prompt
instructions
points
checking_mode
configuration
```

No `position`.

At least one accepted field.

No query parameters.

## 17.3 Delete

No body.

No query.

## 17.4 Reorder

Use the existing exact complete-current-set request contract.

Do not change its JSON shape.

---

# 18. Add Question — Shared Behavior

Update:

```text
AddTeacherAssessmentQuestion
```

to resolve/lock through the shared mutation access.

Do not inject/use `TeacherHomeworkAccess` directly.

## 18.1 Add position

For current count:

```text
N
```

allow:

```text
1 .. N + 1
```

Question-count maximum remains:

```text
QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT
```

Use existing safe position writer.

Final positions:

```text
1..N+1
```

No duplicate/gap.

## 18.2 Typed configuration

Reuse:

```text
QuestionConfigurationWriter
```

unchanged.

Matching request `client_key` remains request-local correlation only.

## 18.3 Total points

After mutation recalculate from all current locked Questions:

```text
AssessmentPointMath
```

Persist exact scale-6:

```text
assessments.total_possible_points
```

Never accept total from client.

## 18.4 Scoreability guard

After recalculation:

### Active Homework

Preserve existing guard:

```text
Question count > 0
total_possible_points > 0
```

### Draft Homework

Zero remains structurally allowed.

### Draft/Scheduled Blitz

Zero remains allowed.

Active Blitz never reaches mutation because lifecycle rejects it first.

---

# 19. Update Question — Shared Behavior

Update:

```text
UpdateTeacherQuestion
```

to resolve/lock through shared mutation access.

Do not inject/use `TeacherHomeworkAccess` directly.

Preserve all delivered behavior:

- partial common-field update;
- full typed-configuration replacement;
- type/checking-mode change requires configuration;
- canonical semantic no-op;
- Matching `client_key` ignored in semantic comparison;
- no stale typed child rows after type change;
- exact point recalculation.

## 19.1 No-op

If common/configuration semantic meaning is unchanged:

- return current full parent resource;
- no Question write;
- no Assessment write/touch;
- no detail-row write;
- no timestamp churn.

This applies to both Homework and Blitz.

## 19.2 Changed update

When semantic change commits:

- update/replace typed configuration safely;
- update Question;
- recalculate total;
- update/touch Assessment according to existing behavior;
- do **not** touch `HomeworkAssignment.updated_at`;
- do **not** touch `BlitzTask.updated_at`.

The parent authoring `updated_at` remains the shared Assessment timestamp.

---

# 20. Delete Question — Shared Behavior

Update:

```text
DeleteTeacherQuestion
```

to use shared access/projection.

Preserve:

1. type-specific configuration delete;
2. Question hard delete;
3. compact remaining positions to `1..N`;
4. recalculate exact total;
5. persist/touch Assessment;
6. return complete type-specific parent resource.

## 20.1 Homework active last-scoreable delete

Preserve existing rollback:

```text
409 assessment_has_no_scoreable_points
```

when an active Homework would become unscoreable.

No Question/config/position/total write may remain committed.

## 20.2 Blitz draft/scheduled

Deleting the last Question is allowed:

```text
Question count = 0
total_possible_points = 0
```

Activation later rejects zero scoreable points.

---

# 21. Reorder Questions — Shared Behavior

Update:

```text
ReorderTeacherAssessmentQuestions
```

to use shared access/projection.

Required:

- complete exact current Question ID set;
- no duplicates;
- no missing/foreign IDs;
- existing contiguous set validated;
- safe unique-position choreography;
- exact requested order persisted;
- no point/config change.

## 21.1 Exact no-op

If requested order equals current order:

- no Question writes;
- no Assessment touch;
- no detail-row touch;
- full current parent resource returned.

Applies to both Homework and Blitz.

---

# 22. Result-Pair and Official Blitz Preservation

Question mutation never changes:

```text
topic_result_pairs
```

For official Blitz:

```text
pair.blitz_assessment_id = assessment.id
```

Draft/Scheduled Question authoring remains allowed even if:

```text
pair.locked_at != null
pair.cohort_snapshotted_at != null
```

provided:

```text
no Blitz Attempt exists
Blitz is not active/closed/archived
Topic remains editable
Teacher remains authorized
```

This preserves the staged workflow where Homework may have locked the official pair before Blitz authoring completes.

Do not reuse:

```text
ResultPairLockedException
```

for valid pre-activation Blitz Question authoring.

Homework continues to use it unchanged.

---

# 23. Attempt Integrity

For both Assessment types:

> Any existing `assessment_attempts` row for that Assessment makes Question content historically significant.

Therefore:

```text
attempt exists -> Question mutation blocked
```

even if a corrupted fixture reports a pre-activity task lifecycle.

For Homework, existing pair-lock precedence remains more specific.

For Blitz, lifecycle may already block first; for a corrupted Draft/Scheduled Blitz with Attempt rows:

```text
409 business_conflict
```

Do not:

- delete Attempt;
- rewrite Attempt;
- repair lifecycle;
- mutate Questions.

---

# 24. Concurrency Contract

Question add/update/delete/reorder must remain serialized against:

- another Question mutation;
- Homework lifecycle/activity locks;
- Blitz Update/Schedule/Archive;
- future Blitz Activation;
- future Student Start.

## 24.1 Question vs Question

Reuse deterministic Question locking and position writer behavior.

Concurrent operations must not leave:

- duplicate positions;
- gaps;
- orphan typed configuration;
- stale total points.

## 24.2 Blitz Question vs Blitz Update/Schedule

Shared parent lock order must serialize.

If Question mutation commits first:

- later Update/Schedule sees new Assessment timestamp/Question state.

If Update/Schedule commits first:

- Question mutation locks current task and re-evaluates current lifecycle.

No lost update.

## 24.3 Question vs future Blitz Activation

This is a required future-compatibility invariant.

Both use the same parent-first locks:

```text
Group
membership
Topic
Assessment
BlitzTask
...
```

If Question mutation commits first:

```text
Activation validates the new Question set/total.
```

If Activation commits first:

```text
Question mutation re-reads status = active
-> 409 business_conflict
-> zero Question-domain mutation
```

It must never be possible to commit a Question change after authoritative activation.

## 24.4 Question vs future Student Start

If an impossible/corrupted preactivation race attempts to create an Attempt concurrently, the shared parent/Attempt locking plus activity re-check must prevent Question mutation from reinterpreting started work.

The later Student Start implementation is responsible for matching this ordering.

---

# 25. Total-Point Invariant

After every committed add/update/delete:

```text
assessments.total_possible_points
=
exact sum of current questions.points
```

Use:

```text
AssessmentPointMath
```

No float accumulation.

Reorder does not change total points.

A semantic no-op update/reorder does not touch the Assessment.

---

# 26. Error Contract

Preserve existing error infrastructure.

## 26.1 Shared privacy

| Condition | Result |
|---|---|
| malformed Assessment UUID | `404 resource_not_found` |
| malformed Question UUID | `404 resource_not_found` |
| foreign Institution | `404 resource_not_found` |
| another Teacher | `404 resource_not_found` |
| ended Teacher–Group membership | `404 resource_not_found` |
| inaccessible Topic | `404 resource_not_found` |
| structurally missing type-specific detail row | `404 resource_not_found` |

## 26.2 Validation

Existing request/config/position errors:

```text
422 validation_failed
```

Existing selection/configuration machine codes remain unchanged where currently used.

## 26.3 Lifecycle/integrity

### Homework

Preserve exact existing codes:

```text
topic_not_editable
task_closed
task_archived
result_pair_locked
business_conflict
assessment_has_no_scoreable_points
```

### Blitz

Use:

```text
topic_not_editable
business_conflict        // active or defensive Attempt conflict
task_closed
task_archived
```

Do not invent:

```text
blitz_question_locked
question_not_editable
```

unless already delivered by a dependency.

---

# 27. Security / Tenant Isolation

All Question routes remain Teacher-only.

Required query concept:

```text
authenticated Teacher
-> Teacher Institution
-> owned authorized Assessment
-> current Topic Group membership
-> Question
```

Do not:

```text
Question::find()
Assessment::find()
```

globally and authorize later.

Cross-Tenant child configuration rows remain protected by delivered composite FKs and writer logic.

Question responses are Teacher-authoring responses; they may include correct-answer configuration through existing:

```text
TeacherQuestionResource
```

This task does not change Student-safe Question projection.

---

# 28. Existing Homework Regression Must Remain Exact

The primary success criterion is **extension**, not rewrite.

Existing Homework Question endpoints must preserve:

- same URLs;
- same request bodies;
- same HTTP statuses;
- same success messages;
- same complete Homework response JSON;
- same lifecycle behavior;
- same pair-lock behavior;
- same activity lock;
- same point totals;
- same position behavior;
- same no-op timestamps;
- same concurrency behavior;
- same privacy behavior.

Do not make Homework Question editing stricter merely to simplify Blitz support.

In particular, preserve:

```text
active Homework with no Attempts and unlocked pair
```

as editable subject to the existing scoreability guard.

---

# 29. Expected File Scope

Exact naming may follow delivered repository conventions.

## Create

```text
backend/app/Actions/Teacher/ShowTeacherAssessmentAuthoring.php
backend/app/Http/Resources/Teacher/TeacherAssessmentAuthoringResource.php

backend/tests/Feature/Teacher/TeacherBlitzQuestionMutationApiTest.php
backend/tests/Feature/Teacher/TeacherBlitzQuestionEditingIntegrityTest.php
backend/tests/Feature/Teacher/TeacherBlitzQuestionMutationConcurrencyTest.php
```

## Modify

```text
backend/app/Support/Teacher/TeacherQuestionMutationAccess.php

backend/app/Actions/Teacher/AddTeacherAssessmentQuestion.php
backend/app/Actions/Teacher/UpdateTeacherQuestion.php
backend/app/Actions/Teacher/DeleteTeacherQuestion.php
backend/app/Actions/Teacher/ReorderTeacherAssessmentQuestions.php

backend/app/Http/Controllers/Api/V1/Teacher/TeacherQuestionController.php
```

Existing Question Request classes should normally remain unchanged.

Changes to:

```text
TeacherHomeworkAccess
TeacherBlitzAccess
ShowTeacherHomework
ShowTeacherBlitz
TeacherHomeworkResource
TeacherBlitzResource
```

are allowed only if a narrow projection/access extraction is concretely required and behavior remains unchanged.

Do not change:

```text
routes/api.php
migrations
Question persistence tables
Student endpoints/actions
Scheduler
frontend
docs
tasks
seeders
dependencies
```

unless a concrete blocker is first reported.

Routes already exist and must remain unchanged.

---

# 30. New Blitz Question Test Coverage

## 30.1 Add

Verify:

- add each of nine supported Question types to Draft Blitz;
- add to Scheduled Blitz;
- insertion at first/middle/append positions;
- max Question count;
- exact point total;
- full `TeacherBlitzResource` returned;
- success message/status unchanged;
- no Blitz lifecycle/timer/schedule field changes;
- no recipient/Attempt creation.

At minimum one parameterized/configuration dataset should cover all nine types without duplicating hundreds of lines manually.

## 30.2 Update

Verify:

- prompt/instructions/points update;
- checking/type/configuration replacement;
- complete typed child replacement;
- Matching semantic no-op ignores request client keys;
- exact no-op does not touch Question/Assessment;
- total points recalculated exactly;
- full Blitz resource returned.

## 30.3 Delete

Verify:

- typed configuration deleted safely;
- positions compact;
- total recalculated;
- last Question may be deleted from Draft Blitz;
- last Question may be deleted from Scheduled Blitz;
- zero points remain valid before activation;
- no lifecycle/timer mutation.

## 30.4 Reorder

Verify:

- complete current ID set required;
- exact new positions;
- no-op stable timestamps;
- typed configuration unaffected;
- total unaffected;
- full Blitz resource returned.

---

# 31. Blitz Editing-Integrity Test Coverage

Verify:

## Allowed

```text
Topic draft + Blitz draft
Topic active + Blitz draft
Topic draft + Blitz scheduled
Topic active + Blitz scheduled
```

subject to Teacher authorization and zero Attempts.

## Blocked lifecycle

```text
Blitz active   -> 409 business_conflict
Blitz closed   -> 409 task_closed
Blitz archived -> 409 task_archived
Topic closed   -> 409 topic_not_editable
Topic archived -> 409 topic_not_editable
```

## Attempt lock

Create a structural Attempt on Draft/Scheduled Blitz.

Every Question mutation must reject:

```text
409 business_conflict
```

and perform zero Question/config/position/total mutation.

## Locked official pair allowed

Create an official pair fixture with:

```text
blitz_assessment_id = Blitz
locked_at != null
cohort_snapshotted_at != null
```

and zero Blitz Attempts.

For Draft/Scheduled Blitz:

- add succeeds;
- update succeeds;
- delete succeeds;
- reorder succeeds.

Assert pair fields are byte-for-byte/instant-for-instant unchanged.

This case is mandatory because it protects the staged Homework-first result-pair design.

---

# 32. Blitz Authorization Test Coverage

For all four shared Question endpoints cover relevant:

- unauthenticated;
- wrong role;
- foreign Institution;
- another Teacher;
- ended Teacher–Group membership;
- malformed UUID;
- direct Assessment UUID probing;
- direct Question UUID probing;
- Homework/Blitz both remain type-safe.

A foreign or inaccessible Question/Assessment returns:

```text
404 resource_not_found
```

not a leaking 403.

---

# 33. Blitz Question Concurrency Test

Use the repository's established PostgreSQL concurrency pattern.

Minimum required race:

```text
Blitz Question mutation
vs
Blitz lifecycle transition to active-shaped locked state
```

Because actual Activation belongs to `S08-BE-004`, the test may use a controlled concurrent transaction that acquires the same required parent rows and transitions the delivered BlitzTask to a valid active structural state.

Required invariant:

### Lifecycle transition commits first

Question mutation:

```text
re-reads active
returns conflict
zero Question-domain mutation
```

### Question mutation commits first

Lifecycle transaction later observes the committed Question/total state.

Final database must never show:

```text
activated Blitz
+
Question mutation committed after activation instant/lock transition
```

Also verify no position/total corruption.

Do not implement the public Activate endpoint in this test/task.

---

# 34. Required Existing Homework Regression

Run the entire focused Stage 6 Question mutation block:

```bash
php artisan test \
  tests/Feature/Teacher/TeacherQuestionMutationApiTest.php \
  tests/Feature/Teacher/TeacherQuestionEditingIntegrityTest.php \
  tests/Feature/Teacher/TeacherQuestionMutationConcurrencyTest.php
```

These are mandatory because the shared access/actions/controller are being refactored.

No existing Homework test may be weakened.

---

# 35. Direct S08-BE-002 Regression

Because Question mutation returns:

```text
TeacherBlitzResource
```

and uses:

```text
TeacherBlitzAccess
ShowTeacherBlitz
```

run the directly relevant delivered Blitz authoring/detail tests from S08-BE-002.

Expected names from the approved dependency contract:

```bash
php artisan test \
  tests/Feature/Teacher/TeacherBlitzAuthoringApiTest.php \
  tests/Feature/Teacher/TeacherBlitzAuthorizationApiTest.php
```

If the delivered dependency uses different exact filenames, run the equivalent focused create/detail/authorization tests and report the exact command.

Do not rerun BE-002 schedule/archive/concurrency tests unless implementation changes those lifecycle helpers beyond direct read/access reuse.

---

# 36. Task Verification Commands

Run from:

```text
backend/
```

## 36.1 New Blitz Question tests

```bash
php artisan test \
  tests/Feature/Teacher/TeacherBlitzQuestionMutationApiTest.php \
  tests/Feature/Teacher/TeacherBlitzQuestionEditingIntegrityTest.php \
  tests/Feature/Teacher/TeacherBlitzQuestionMutationConcurrencyTest.php
```

## 36.2 Existing Homework Question regression

```bash
php artisan test \
  tests/Feature/Teacher/TeacherQuestionMutationApiTest.php \
  tests/Feature/Teacher/TeacherQuestionEditingIntegrityTest.php \
  tests/Feature/Teacher/TeacherQuestionMutationConcurrencyTest.php
```

## 36.3 Direct Blitz authoring/access regression

```bash
php artisan test \
  tests/Feature/Teacher/TeacherBlitzAuthoringApiTest.php \
  tests/Feature/Teacher/TeacherBlitzAuthorizationApiTest.php
```

Use actual delivered equivalent filenames if needed.

## 36.4 Format

```bash
./vendor/bin/pint --test
```

No additional static-analysis command is required unless already mandatory for the exact changed backend area.

## 36.5 Always

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

Full backend regression belongs to:

```text
S08-BE-PHASE-2
```

---

# 37. Acceptance Criteria

## Shared endpoints

- [ ] Existing four Assessment-oriented Question routes remain canonical.
- [ ] No duplicate Blitz Question route family is added.
- [ ] Requests remain shared and unchanged.

## Shared access

- [ ] Assessment routes resolve authorized Homework or Blitz only.
- [ ] Question routes resolve through authorized parent Assessment.
- [ ] Tenant/Teacher/current-membership scope precedes exposure.
- [ ] Missing type-specific detail row is privacy-safe 404.
- [ ] Deterministic lock order is preserved.

## Homework preservation

- [ ] Homework draft/active pre-Attempt behavior unchanged.
- [ ] Homework pair-lock behavior unchanged.
- [ ] Homework active scoreability guard unchanged.
- [ ] Existing full Homework mutation response unchanged.
- [ ] Existing no-op/timestamp behavior unchanged.
- [ ] Existing concurrency tests remain green.

## Blitz lifecycle

- [ ] Draft Blitz Question mutation allowed.
- [ ] Scheduled Blitz Question mutation allowed.
- [ ] Active Blitz Question mutation blocked.
- [ ] Closed Blitz Question mutation blocked.
- [ ] Archived Blitz Question mutation blocked.
- [ ] Topic closed/archived blocks mutation.
- [ ] Any Blitz Attempt blocks mutation.

## Result pair

- [ ] Locked official Homework-first pair does not block Draft/Scheduled Blitz Question authoring.
- [ ] Question mutation never changes pair IDs/cohort/lock/designation fields.
- [ ] No `result_pair_locked` is returned solely for valid preactivation Blitz authoring.

## Question semantics

- [ ] All nine types supported.
- [ ] Existing typed validators/writers reused.
- [ ] Add positions safe and contiguous.
- [ ] Update full configuration semantics preserved.
- [ ] Delete compacts positions.
- [ ] Reorder requires exact complete ID set.
- [ ] Matching semantic no-op ignores request-local client keys.
- [ ] No per-question timer added.

## Points

- [ ] Add/update/delete recalculate exact Assessment total.
- [ ] Reorder leaves total unchanged.
- [ ] Draft/Scheduled Blitz may have zero total.
- [ ] Client cannot supply total.

## Response

- [ ] Homework mutations return complete Homework resource.
- [ ] Blitz mutations return complete Blitz resource.
- [ ] Existing success statuses/messages unchanged.
- [ ] Presentation dispatcher performs no query.

## Concurrency/security

- [ ] No Question write can commit after Blitz activation wins the parent lock.
- [ ] No duplicate positions/gaps/stale typed children.
- [ ] Cross-Tenant/direct-ID privacy preserved.
- [ ] Student-safe Question projection untouched.

## Scope/verification

- [ ] No migration changed.
- [ ] No route changed/added.
- [ ] No Student execution added.
- [ ] No activation endpoint added.
- [ ] No scoring/checking added.
- [ ] Focused Blitz tests pass.
- [ ] Existing Homework Question tests pass.
- [ ] Direct BE-002 regressions pass.
- [ ] Pint passes.
- [ ] `git diff --check` passes.
- [ ] Focused diff self-check finds no unrelated change.

---

# 38. Focused Diff Self-Check

Before completion confirm:

```text
shared Teacher Question mutation integration only
```

Verify no:

- Blitz activation implementation;
- result-pair mutation;
- recipient activation snapshot;
- Student Attempt execution;
- answer/file logic;
- Submit;
- timeout/Scheduler;
- exception;
- monitoring;
- scoring/checking;
- migration;
- new Question schema;
- frontend/docs/task changes.

Verify specifically:

```text
Homework pair lock still blocks Homework
Blitz historical pair lock does not block Draft/Scheduled Blitz
active Blitz never accepts Question mutation
```

---

# 39. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. shared access refactor;
4. Homework vs Blitz lifecycle rules;
5. locked result-pair handling difference;
6. parent resource dispatch implementation;
7. Question/total-point behavior;
8. concurrency behavior;
9. security/Tenant behavior;
10. new Blitz Question focused test results;
11. existing Homework Question regression results;
12. direct BE-002 regression results;
13. Pint result;
14. `git diff --check`;
15. final `git status --short`;
16. focused scope/diff self-check;
17. any blocker/deviation.

Do not claim Stage 8 backend complete.

After delivery ChatGPT performs read-only acceptance review.

`S08-BE-004` remains blocked until:

```text
S08-BE-003 = Accepted / Delivered
```

---

# 40. Implementation Readiness Verdict

```text
Scope / non-goals                     = RESOLVED
Shared route strategy                 = RESOLVED
Homework preservation                 = RESOLVED
Blitz lifecycle editability           = RESOLVED
Historical pair-lock difference       = RESOLVED
Assessment/Question privacy resolution = RESOLVED
Lock ordering                         = RESOLVED
Add semantics                         = RESOLVED
Update semantics                      = RESOLVED
Delete semantics                      = RESOLVED
Reorder semantics                     = RESOLVED
Typed configuration reuse             = RESOLVED
Point total invariant                 = RESOLVED
Parent response dispatch              = RESOLVED
No-op/timestamps                      = RESOLVED
Concurrency                           = RESOLVED
Authorization/Tenant isolation        = RESOLVED
Acceptance criteria                   = RESOLVED
Focused verification                  = RESOLVED

Implementation Readiness Gate         = PASS
Execution dependency                  = S08-BE-002 Accepted / Delivered
```
