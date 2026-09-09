# Codex Implementation Contract: S07-BE-003 — Student Homework Read API

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S07-BE-003` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel Student Homework list/detail API + Student-safe Question projection + read-path deadline reconciliation` |
| Depends on | `S07-BE-001` and `S07-BE-002` — both `Accepted / Delivered` before implementation |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Implementation baseline | ChatGPT re-checks/freezes current `origin/main` immediately before Codex starts |
| Readiness Gate | `PASS`, conditional on dependencies above |
| Verification | focused Student read/API/security verification only |
| Delivery | Project Owner |
| Backend block checkpoint | Stage 7 Backend Phase 2 after `S07-BE-001…007` |

Start only after both dependencies are delivered, the implementation baseline is re-checked, and Git preflight is safe.

Do not create a duplicate `CODEX-PROMPT`.

---

# 2. Context Boundary

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. delivered `S07-BE-001` / `S07-BE-002` source/tests directly required here;
5. current Student Topic controller/request/action/resource/test patterns;
6. current Assessment/Homework/Question Models and directly required Question child Models;
7. current Teacher Homework read code only as a local implementation-pattern reference;
8. current Institution settings model only for Student submission read metadata.

Do not read roadmap/product/architecture/database/API docs, previous task files, Stage history/indexes/closure reviews, frontend, or unrelated modules to determine requirements.

This contract resolves:

- exact endpoints;
- Student assignment authority;
- draft/privacy behavior;
- query contract;
- pagination/sorting;
- attempt summary semantics;
- read-path deadline reconciliation;
- all nine Student Question projections;
- correct-answer leakage prevention;
- file-based read metadata;
- tenant/Student isolation;
- response shapes;
- N+1/query expectations;
- tests and verification.

If delivered dependencies materially conflict with this contract, return `BLOCKED` with exact evidence. Do not redesign.

---

# 3. Goal

Expose the first Student Homework read surface:

```text
GET /api/v1/student/homework
GET /api/v1/student/homework/{homework}
```

so an assigned Student can:

- see active/historical assigned Homework;
- see server-authoritative deadline state;
- see fixed three-attempt usage/capacity;
- discover an existing `in_progress` Attempt identity for later resume;
- see all nine Question types in a Student-safe form;
- never receive Teacher answer keys/correctness configuration.

Before read state is returned, due in-progress Homework work must be reconciled through the authoritative BE-002 deadline action.

No Student mutation endpoint is implemented here.

---

# 4. Explicit Non-Goals

Do not implement:

- Attempt Start/resume POST;
- Attempt detail endpoint;
- answer save/replace;
- file upload/replace;
- final Submit;
- idempotency claim/replay;
- Teacher close changes beyond delivered BE-002;
- answer checking;
- Teacher review;
- scores/official scores/results;
- Student/Parent score visibility behavior;
- Blitz;
- frontend;
- E2E/seeders;
- schema migration;
- docs/task bookkeeping;
- package/dependency changes;
- unrelated refactors.

Do not expose saved Student answer payloads from Homework detail. Those belong to the later Attempt read/execution surface.

---

# 5. Routes and Middleware

Modify:

```text
backend/routes/api.php
```

Inside the existing Student group:

```text
auth:sanctum
active.account
password.changed
role:student
```

register exactly:

```text
GET /api/v1/student/homework
GET /api/v1/student/homework/{homework}
```

Controller:

```text
App\Http\Controllers\Api\V1\Student\StudentHomeworkController
```

Methods:

```text
index
show
```

Do not add aliases or duplicate non-versioned routes.

---

# 6. Student Assignment Authority

The authoritative Student Homework assignment relation is:

```text
assessment_students
```

not current Group membership.

A Homework is readable by the authenticated Student only when all hold:

```text
assessments.institution_id = student.institution_id
assessments.type = homework

assessment_students.institution_id = student.institution_id
assessment_students.assessment_id = assessments.id
assessment_students.student_id = student.id

homework_assignments.institution_id = student.institution_id
homework_assignments.assessment_id = assessments.id
homework_assignments.status in (active, closed, archived)
```

## 6.1 Later Group-membership changes

Once Homework activation has persisted the recipient snapshot, later changes to:

```text
group_student_memberships
```

must not silently remove that Homework assignment/history.

Therefore Student Homework read access must **not** require:

```text
current group_student_membership
```

and must not reuse `Topic::visibleToStudent()` as the authorization boundary for Homework.

This preserves the persisted assignment snapshot.

## 6.2 Draft privacy

`draft` Homework is never Student-readable.

This is especially important for:

```text
assignment_mode = selected_students
```

because draft recipient rows may already exist for Teacher authoring.

A Student recipient row does not make a draft Homework public.

## 6.3 Active account

User/Institution active state and Student role remain enforced by existing middleware.

---

# 7. Privacy-Safe Resolution

Create:

```text
backend/app/Support/Student/StudentHomeworkAccess.php
```

Responsibilities:

- build the tenant + recipient-snapshot scoped Homework query;
- resolve one readable Homework by UUID;
- never rely on global `Assessment::find()` followed by authorization.

For `{homework}`:

- malformed UUID;
- foreign-Institution Homework;
- another Student's/unassigned Homework;
- draft Homework;
- non-Homework Assessment;
- missing HomeworkAssignment;

all resolve as:

```text
404 resource_not_found
```

through the existing not-found API boundary.

Do not reveal which condition failed.

For list `topic_id`, a valid UUID with no matching assigned Homework returns an empty collection, not `404`.

---

# 8. Read-Path Deadline Reconciliation

Create:

```text
backend/app/Actions/Student/ReconcileStudentHomeworkDeadlines.php
```

It reuses delivered:

```text
FinalizeHomeworkAttemptsAtDeadline
```

from BE-002.

No deadline transition logic may be duplicated here.

## 8.1 Reconcile all relevant Student Homework

Required method:

```text
all(User $student): void
```

Find only Student-assigned Homework where:

```text
same Institution
assessment type = homework
homework status = active
deadline_at IS NOT NULL
deadline_at <= scanNow
Student is persisted assessment_students recipient
Student has an assessment_attempts row:
  student_id = authenticated Student
  status = in_progress
```

Use deterministic keyset iteration by Assessment UUID; do not use offset pagination over a result set that shrinks after finalization.

For each candidate call:

```text
FinalizeHomeworkAttemptsAtDeadline(
    student.institution_id,
    assessment.id
)
```

The BE-002 action re-checks authoritative time/state under locks and may finalize all due in-progress Attempts for that Homework, which is correct after the deadline.

## 8.2 Reconcile one authorized Homework

Required method:

```text
one(User $student, Assessment $authorizedHomework): void
```

Precondition:

```text
$authorizedHomework was already resolved through StudentHomeworkAccess
```

Call the same BE-002 per-Homework action.

Never use a user-supplied Homework UUID to trigger reconciliation before Student authorization is established.

## 8.3 Invocation order

List:

```text
ReconcileStudentHomeworkDeadlines::all(student)
-> query/paginate fresh read state
```

Detail:

```text
resolve authorized Homework
-> ReconcileStudentHomeworkDeadlines::one(...)
-> reload fresh detail projection
```

Thus response attempt state cannot remain stale merely because Scheduler has not run yet.

---

# 9. Student Homework List Request

Create:

```text
backend/app/Http/Requests/Student/StudentHomeworkIndexRequest.php
```

Accepted query keys only:

```text
topic_id
status
page
per_page
sort
direction
```

No request body.

Unknown query key or any body:

```text
422 validation_failed
```

## 9.1 `topic_id`

Optional UUID string.

It filters:

```text
assessments.topic_id
```

inside the already Student-assigned tenant scope.

## 9.2 `status`

Allowed:

```text
active
closed
archived
```

Draft is not accepted.

## 9.3 Pagination

```text
default page = 1
default per_page = 20
max per_page = 100
```

Validation:

```text
page >= 1
1 <= per_page <= 100
```

## 9.4 Sorting

Allowed:

```text
created_at
title
deadline_at
status
```

Directions:

```text
asc
desc
```

Defaults:

```text
sort = created_at
direction = desc
```

Rules:

```text
created_at => assessments.created_at
title      => lower(assessments.title)
deadline   => homework_assignments.deadline_at NULLS LAST
status     => homework_assignments.status
```

Always add deterministic Assessment ID tie-breaker in the same requested direction.

Do not sort/filter in PHP after pagination.

---

# 10. `ListStudentHomework`

Create:

```text
backend/app/Actions/Student/ListStudentHomework.php
```

Flow:

1. reconcile due current-Student Homework through Section 8;
2. build tenant + persisted-recipient query;
3. join/read `homework_assignments`;
4. apply filters;
5. apply deterministic sort;
6. eager load required Topic and Student Attempt rows;
7. paginate server-side;
8. attach resolved Student attempt summary state for each returned Homework.

Do not query current Group membership.

## 10.1 Required eager data

For each page load:

```text
topic:
  id
  title
```

and only authenticated Student's Attempts for that Assessment, ordered:

```text
attempt_number ASC
```

with fields needed for read state:

```text
id
assessment_id
student_id
attempt_number
status
started_at
submitted_at
finalized_at
finalization_reason
locked_at
```

Maximum normal Homework Attempts are fixed at three, so eager loading these rows is bounded.

Do not load all Students' Attempts.

---

# 11. Attempt Summary Semantics

Create one focused reusable projector/service, for example:

```text
backend/app/Support/Student/StudentHomeworkAttemptSummary.php
```

It receives already loaded authenticated-Student Attempt rows plus Homework lifecycle/deadline state.

Resources must not independently decide attempt availability.

Capture one:

```text
observedAt = now()
```

per list/detail projection operation.

## 11.1 `allowed`

Always:

```text
3
```

## 11.2 `used`

Count every persisted Attempt row belonging to this Student/Homework.

Includes:

```text
in_progress
submitted
waiting_for_teacher_review
checked
```

and any other valid historical stored status if present.

No fabricated row means no usage.

## 11.3 `remaining`

Represents unused normal Attempt capacity that is still available under current Homework lifecycle/deadline rules.

If:

```text
homework.status != active
```

then:

```text
remaining = 0
```

If:

```text
deadline_at != null
AND observedAt >= deadline_at
```

then:

```text
remaining = 0
```

Otherwise:

```text
remaining = max(0, 3 - used)
```

An existing `in_progress` Attempt is already included in `used`.

`remaining` does not authorize opening a parallel Attempt; BE-004 separately enforces one-in-progress/resume behavior.

## 11.4 `my_status`

If Student has no Attempt:

```text
not_started
```

Else if one `in_progress` Attempt exists:

```text
in_progress
```

Else use the highest `attempt_number` Attempt's persisted status.

During Stage 7 before checking this will normally be:

```text
submitted
```

Later Stage 9 may legitimately expose:

```text
waiting_for_teacher_review
checked
```

Do not invent a fake `not_completed` Attempt status here.

## 11.5 In-progress identity

Detail projection must expose at most one:

```text
in_progress_attempt
```

using the BE-001 structural invariant.

Shape:

```json
{
  "id": "attempt-uuid",
  "attempt_number": 1,
  "started_at": "2026-09-08T12:00:00Z"
}
```

or:

```json
null
```

This lets the later frontend choose resume rather than opening a parallel Attempt.

If loaded persistence somehow contains more than one in-progress Attempt despite BE-001 structural constraints, fail safely as a server invariant violation; do not choose one arbitrarily.

## 11.6 Official-score policy metadata

Return string:

```text
highest_valid_completed
```

as policy metadata only.

BE-003 does not select or calculate an official score.

## 11.7 Score visibility

Stage 7 Student Homework read returns:

```text
score_visible = false
```

No score value is returned.

---

# 12. Student Homework List Response

Create:

```text
StudentHomeworkSummaryResource
StudentHomeworkCollection
```

Collection pagination envelope must match the existing Student Topic convention:

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

Each summary returns exactly:

```json
{
  "id": "homework-uuid",
  "topic": {
    "id": "topic-uuid",
    "title": "Internet Basics"
  },
  "title": "Homework 1",
  "status": "active",
  "deadline_at": "2026-09-10T13:00:00Z",
  "attempts": {
    "allowed": 3,
    "used": 1,
    "remaining": 2,
    "official_score_policy": "highest_valid_completed"
  },
  "my_status": "submitted",
  "score_visible": false
}
```

No:

```text
teacher_id
institution_id
assignment_mode
recipient IDs
correct-answer configuration
score
```

in list summary.

Timestamps use UTC RFC3339 `...Z`.

---

# 13. Student Homework Detail Request

Create:

```text
backend/app/Http/Requests/Student/StudentHomeworkShowRequest.php
```

No query parameters.

No request body.

Any query key or body:

```text
422 validation_failed
```

Use the same pattern as current `StudentTopicShowRequest`.

---

# 14. `ShowStudentHomework`

Create:

```text
backend/app/Actions/Student/ShowStudentHomework.php
```

Flow:

1. resolve authorized readable Homework through `StudentHomeworkAccess`;
2. reconcile deadline for that already-authorized Homework;
3. reload fresh Homework aggregate in the same Student assignment scope;
4. load authenticated Student's Attempts;
5. load Student-safe Question relations only;
6. load institution `student_submission_max_mb`;
7. attach attempt summary and effective file-size metadata;
8. return Assessment for exact Resource serialization.

## 14.1 Question ordering

Questions:

```text
position ASC
id ASC
```

## 14.2 Safe eager-loading

Load only data needed for Student projection.

### Choice options

Load:

```text
id
question_id
option_text
is_correct
position
```

`is_correct` is needed internally only to derive Multiple Choice `max_selections`.

It must never be serialized.

### True / False

Do **not** load:

```text
question_true_false_answers.correct_value
```

Student does not need it.

### Short Written

Do **not** load:

```text
question_short_accepted_answers
```

### Matching

Load only:

```text
id
question_id
side
item_text
```

Do not select/load:

```text
match_key
```

for Student read.

### Ordering

Load only:

```text
id
question_id
item_text
```

Do not select/load:

```text
correct_position
```

for Student read.

### Fill Blank

Load only:

```text
id
question_id
blank_key
position
```

Do not load:

```text
question_fill_blank_accepted_answers
```

### File-based

No persisted correct configuration is needed.

---

# 15. Student Homework Detail Response

Create:

```text
backend/app/Http/Resources/Student/StudentHomeworkResource.php
```

Return exactly:

```json
{
  "id": "homework-uuid",
  "topic": {
    "id": "topic-uuid",
    "title": "Internet Basics"
  },
  "title": "Homework 1",
  "description": "Optional description",
  "student_instructions": "Complete the task.",
  "status": "active",
  "deadline_at": "2026-09-10T13:00:00Z",
  "total_possible_points": 10.0,
  "attempts": {
    "allowed": 3,
    "used": 1,
    "remaining": 2,
    "official_score_policy": "highest_valid_completed",
    "in_progress_attempt": {
      "id": "attempt-uuid",
      "attempt_number": 1,
      "started_at": "2026-09-08T12:00:00Z"
    }
  },
  "my_status": "in_progress",
  "score_visible": false,
  "questions": []
}
```

When there is no current in-progress Attempt:

```json
"in_progress_attempt": null
```

Do not return Student answer payloads here.

Do not return official score fields.

---

# 16. Student Question Resource

Create:

```text
backend/app/Http/Resources/Student/StudentQuestionResource.php
backend/app/Support/Student/StudentQuestionAnswerUi.php
```

Common Question shape:

```json
{
  "id": "question-uuid",
  "type": "single_choice",
  "prompt": "Question text",
  "instructions": null,
  "points": 1.0,
  "position": 1,
  "answer_ui": {}
}
```

Do **not** expose:

```text
checking_mode
```

to Student in Stage 7.

The Student needs an answer surface, not Teacher checking policy.

---

# 17. Forbidden Student Question Data

No Student Homework response may contain any key/value equivalent of:

```text
is_correct
correct_value
accepted_answers
correct_position
match_key
```

Also do not serialize:

```text
checking_mode
configuration
client_key
```

from Teacher authoring resources.

Do not reuse `TeacherQuestionResource`.

Do not call `QuestionConfigurationReader::read()` and then try to remove sensitive keys afterward.

Student projection must be constructed independently from safe fields.

---

# 18. Question-Type `answer_ui`

## 18.1 Single Choice

Return:

```json
{
  "options": [
    {
      "id": "option-uuid",
      "text": "Option text"
    }
  ]
}
```

Order options by authoring `position`, tie-break `id`.

Do not expose `is_correct` or position.

## 18.2 Multiple Choice

Return:

```json
{
  "options": [
    {
      "id": "option-uuid",
      "text": "Option text"
    }
  ],
  "max_selections": 2
}
```

`max_selections` is:

```text
count(choiceOptions where is_correct = true)
```

This count is the approved Student validation cap.

Do not indicate which options are correct.

If persisted active Homework has an impossible Multiple Choice definition with fewer than one correct option, fail as a server invariant error rather than return misleading UI.

## 18.3 True / False

Return an empty object:

```json
{}
```

Flutter knows the boolean control from:

```text
type = true_false
```

Never expose `correct_value`.

## 18.4 Short Written

Return:

```json
{}
```

Never expose accepted answers, regardless of automatic/manual checking mode.

## 18.5 Open Written

Return:

```json
{}
```

## 18.6 File Based

Return:

```json
{
  "allowed_extensions": [
    "pdf",
    "docx",
    "ppt",
    "pptx"
  ],
  "max_size_bytes": 15728640
}
```

Allowed extensions come from the existing platform FileExtension contract.

Effective size:

```text
min(15, institution_settings.student_submission_max_mb)
* 1_048_576
```

The current DB contract already constrains the institution value to max 15; keep the platform min defensively explicit.

This is read metadata only.

Actual upload/MIME/storage validation belongs to `S07-BE-006`.

## 18.7 Matching

Return:

```json
{
  "left_items": [
    {
      "id": "left-item-uuid",
      "text": "Left text"
    }
  ],
  "right_items": [
    {
      "id": "right-item-uuid",
      "text": "Right text"
    }
  ]
}
```

Never return:

```text
match_key
pair grouping
shared authoring position
```

### Safe display ordering

The response order itself must not reveal the correct pair.

Do not order both sides by persisted `position`.

Do not depend on raw UUID lexical order alone because UUID generation may correlate with row creation order.

Use a deterministic Student-safe hash order independent of correct pairing:

```text
left:
sha256("matching-left|{question_id}|{item_id}")

right:
sha256("matching-right|{question_id}|{item_id}")
```

sort hash ascending, then item ID as collision tie-breaker.

The hash is internal and is not serialized.

## 18.8 Ordering

Return:

```json
{
  "items": [
    {
      "id": "ordering-item-uuid",
      "text": "Item text"
    }
  ]
}
```

Never return or load into the Student projection:

```text
correct_position
```

The array order must not equal the authoring correct order by construction.

Use deterministic safe hash order:

```text
sha256("ordering|{question_id}|{item_id}")
```

then item ID tie-breaker.

Do not use DB creation order or UUID lexical order alone.

## 18.9 Fill in the Blank

Return:

```json
{
  "blanks": [
    {
      "id": "blank-uuid",
      "key": "dns_name",
      "position": 1
    }
  ]
}
```

`key` is required because the prompt uses the approved:

```text
{{blank_key}}
```

placeholder syntax.

Order blanks by `position`, then `id`.

Never load/return accepted answers.

---

# 19. Student Question Projection Implementation Rules

`StudentQuestionAnswerUi` must:

- operate only on relations explicitly loaded by `ShowStudentHomework`;
- throw a safe server invariant exception/`LogicException` if a required relation is absent or structurally impossible;
- never issue hidden per-Question queries;
- never query correct-answer tables for TrueFalse/Short/FillBlank;
- never serialize Teacher configuration objects;
- return an object-like empty payload, not JSON array `[]`, for empty `answer_ui`.

The Resource remains serialization-focused.

---

# 20. Read Performance / Query Shape

## List

Must use:

- one paginated Homework query;
- eager-loaded Topic;
- eager-loaded only-current-Student Attempts;
- no per-row Topic/Attempt query.

Deadline reconciliation occurs before the read query and only for current Student's due in-progress assigned Homework.

## Detail

Typed Question relations must be eager-loaded in a fixed number of relation queries.

Do not issue:

```text
one query per Question
```

or:

```text
one query per option/item/blank
```

Resources/support projections must not cause N+1.

No unbounded all-Student Attempt reads.

---

# 21. Controller

Create:

```text
backend/app/Http/Controllers/Api/V1/Student/StudentHomeworkController.php
```

Keep it thin.

`index`:

```text
validated request
-> authenticated Student
-> ListStudentHomework
-> StudentHomeworkCollection
```

`show`:

```text
validated request
-> authenticated Student
-> ShowStudentHomework
-> StudentHomeworkResource
```

No tenant/business/deadline logic in controller.

---

# 22. Expected Files

## Create

```text
backend/app/Support/Student/StudentHomeworkAccess.php
backend/app/Support/Student/StudentHomeworkAttemptSummary.php
backend/app/Support/Student/StudentQuestionAnswerUi.php

backend/app/Actions/Student/ReconcileStudentHomeworkDeadlines.php
backend/app/Actions/Student/ListStudentHomework.php
backend/app/Actions/Student/ShowStudentHomework.php

backend/app/Http/Requests/Student/StudentHomeworkIndexRequest.php
backend/app/Http/Requests/Student/StudentHomeworkShowRequest.php

backend/app/Http/Controllers/Api/V1/Student/StudentHomeworkController.php

backend/app/Http/Resources/Student/StudentHomeworkSummaryResource.php
backend/app/Http/Resources/Student/StudentHomeworkCollection.php
backend/app/Http/Resources/Student/StudentHomeworkResource.php
backend/app/Http/Resources/Student/StudentQuestionResource.php

backend/tests/Feature/Student/StudentHomeworkReadApiTest.php
backend/tests/Feature/Student/StudentHomeworkQuestionPrivacyTest.php
backend/tests/Feature/Student/StudentHomeworkDeadlineReadReconciliationTest.php
```

## Modify

```text
backend/routes/api.php
```

No migration/model schema change is expected.

If a tiny direct Model relation update is genuinely required to support an eager-load relation already implicit in delivered persistence, keep it minimal and report it; do not broaden Models into workflow logic.

---

# 23. `StudentHomeworkReadApiTest`

At minimum cover:

## Routes

Exactly two GET routes registered once under Student middleware.

Teacher/Admin/Parent/Platform role tokens cannot use them.

## Authentication gates

Preserve:

```text
401 authentication_required
403 user_inactive
403 institution_inactive
403 password_change_required
```

through existing middleware.

## List validation

- defaults;
- all allowed query fields;
- malformed `topic_id`;
- invalid status;
- invalid sort/direction;
- page/per_page boundaries;
- unknown query;
- request body;
- `422 validation_failed`.

## Assignment visibility

Student sees only Homework where their persisted `assessment_students` row exists.

Verify hidden:

- foreign Institution;
- another Student's assignment;
- non-Homework Assessment;
- draft Homework.

## Snapshot durability

Activate/construct assigned Homework, then end the Student's current Group membership.

Student Homework list/detail must remain readable because the persisted recipient snapshot is authoritative.

Do not change existing Student Topic behavior in this task.

## Historical statuses

Assigned:

```text
active
closed
archived
```

are readable/filterable.

## Topic filter

Valid unrelated/inaccessible Topic UUID produces no leak and no unrelated rows.

## Pagination/sorting

Verify:

```text
created_at
title
deadline_at NULLS LAST
status
```

and deterministic ID tie-breaker.

## Attempt summary

Cases:

```text
no Attempts => used 0, my_status not_started

one in_progress =>
  used 1
  in list my_status = in_progress

submitted Attempt =>
  used increments
  my_status = highest attempt_number status

three used =>
  remaining 0

closed/deadline passed =>
  remaining 0 even if used < 3
```

## List response

Exact summary field set and pagination envelope.

No score field and `score_visible = false`.

---

# 24. `StudentHomeworkQuestionPrivacyTest`

Build one Student-readable Homework containing all nine Question types.

Verify exact Student Question shapes.

## Forbidden keys recursive assertion

Recursively inspect JSON and assert none of these keys occur anywhere:

```text
is_correct
correct_value
accepted_answers
correct_position
match_key
checking_mode
configuration
client_key
```

## Secret-value assertion

Seed distinctive secret values into:

- True/False correct value context;
- Short accepted answer;
- Matching match key;
- Ordering correct position;
- Fill Blank accepted answer.

Assert response cannot reconstruct/contain those protected configuration values except ordinary visible option/item text that is inherently part of the Student question.

## Multiple Choice

Verify:

- all option IDs/text are returned;
- no option correctness flag;
- `max_selections` equals number of correct options.

## Matching order leak

Create matching rows whose persisted positions clearly align the correct pairs.

Verify Student right-side output order is **not** derived from matching position and matches the deterministic safe-hash order.

## Ordering leak

Create items in correct sequence and with IDs/creation sequence that would make naive ordering leak.

Verify response matches safe-hash display order and contains no correct positions.

## Fill Blank

Verify placeholder key/id/position present, accepted answers absent.

## File

Verify allowed extensions and effective institution/platform size bytes.

---

# 25. `StudentHomeworkDeadlineReadReconciliationTest`

Use frozen time and delivered BE-002 persistence/actions.

At minimum:

## List read

Create active assigned Homework:

```text
deadline_at < now
Student has in_progress Attempt
```

Call list.

Before response assertion verify DB now has:

```text
status = submitted
submitted_at = null
finalized_at = deadline_at
locked_at = deadline_at
finalization_reason = homework_deadline_auto_submit
```

Response:

```text
my_status = submitted
remaining = 0
```

## Detail read

Same behavior when Scheduler has not previously run.

## Saved answers

A BE-001 saved answer remains:

```text
checking_status = pending
awarded_points = null
payload unchanged
```

## Never started

Assigned Student with no Attempt does not receive a fabricated Attempt merely by reading expired Homework.

## Unauthorized trigger protection

Attempt to show another Student's/cross-tenant Homework.

Expect `404`.

Verify that request did **not** trigger deadline reconciliation for that inaccessible Homework.

## Before deadline

Read is write-free with respect to Attempt finalization.

---

# 26. Query Regression Test Requirement

Inside the read tests, include focused query-count evidence that:

- list query count does not grow linearly with number of returned Homework when no reconciliation candidates exist;
- detail typed-configuration query count remains fixed when Question count increases.

A small fixed number of eager-load queries is acceptable.

Do not assert an overly fragile exact total including framework middleware queries; assert a reasonable constant bound or compare small-vs-large fixture growth.

---

# 27. Directly Affected Regression Tests

Run BE-003 tests plus:

```text
tests/Feature/Student/StudentTopicApiTest.php
```

because `routes/api.php` Student group is modified and the existing Student authorization pattern must remain unchanged.

Run the focused BE-002 deadline behavior test:

```text
tests/Feature/Homework/HomeworkDeadlineFinalizationTest.php
```

Run BE-001 model/persistence test needed by answer-state read reconciliation:

```text
tests/Feature/Persistence/StudentAnswerSubmissionFactoryModelTest.php
```

Do not run full backend suite.

---

# 28. Verification

Use the repository's normal Docker/Sail backend command wrapper.

Run required formatter/static check for changed PHP files.

Then exactly:

```bash
php artisan test \
  tests/Feature/Student/StudentHomeworkReadApiTest.php \
  tests/Feature/Student/StudentHomeworkQuestionPrivacyTest.php \
  tests/Feature/Student/StudentHomeworkDeadlineReadReconciliationTest.php \
  tests/Feature/Student/StudentTopicApiTest.php \
  tests/Feature/Homework/HomeworkDeadlineFinalizationTest.php \
  tests/Feature/Persistence/StudentAnswerSubmissionFactoryModelTest.php
```

Then from repository root:

```bash
git diff --check
```

and focused diff/scope self-review.

Do not run:

- full backend suite;
- frontend tests/build;
- E2E/integration Stage runner.

---

# 29. Acceptance Criteria

PASS only if all are true.

## API

- exact two Student GET endpoints exist;
- current Student middleware applies;
- index strict query/body contract works;
- show allows no query/body;
- pagination envelope follows current Student convention.

## Assignment/security

- `assessment_students` snapshot is authoritative;
- current Group membership is not required after assignment;
- draft Homework remains hidden;
- cross-tenant/other-Student/direct-ID access is privacy-safe `404`;
- unauthorized show cannot trigger reconciliation of inaccessible Homework.

## Deadline state

- list/detail reconcile current Student's due in-progress Homework before returning state;
- BE-002 action is reused, not reimplemented;
- exact deadline timestamp semantics remain intact;
- never-started Student gets no fabricated Attempt.

## Attempts

- allowed = 3;
- used counts actual rows;
- remaining becomes zero when closed/archived/deadline-passed;
- my_status is deterministic;
- detail exposes current in-progress Attempt identity only when it exists;
- no score is calculated/returned;
- score_visible = false.

## Question privacy

- all nine Question types render;
- no forbidden Teacher answer keys/config keys leak;
- TrueFalse correct value not queried/returned;
- Short/Fill accepted answers not queried/returned;
- Matching match keys not queried/returned;
- Ordering correct positions not queried/returned;
- Multiple Choice exposes only `max_selections`, not which options are correct;
- Matching/Ordering array order does not leak correct relationships/order;
- file metadata uses platform/institution effective size.

## Quality

- no N+1;
- no unbounded all-Student Attempt load;
- thin controller;
- Resources do not make business/authorization queries;
- no API mutation/scoring functionality leaks into BE-003.

## Verification

- focused tests pass;
- named regressions pass;
- formatter/static check passes;
- `git diff --check` passes;
- focused diff review passes.

---

# 30. Locked Implementation Decisions

These are decisions, not suggestions:

```text
Student Homework assignment authority = assessment_students snapshot
draft Homework = hidden
current Group membership = not required after assignment snapshot
Student Homework status filter = active|closed|archived
list sorts = created_at|title|deadline_at|status
pagination = 20 default, 100 max
read deadline reconciliation = reuse BE-002
Student detail = no saved answer payload
Student Question projection = independent from TeacherQuestionResource
checking_mode = not returned
Matching match_key/paired order = never returned
Ordering correct_position/correct order = never returned
Fill accepted answers = never loaded/returned
File max = min(15 MB platform, institution setting)
score_visible = false in Stage 7
```

Codex must not substitute:

- current Group membership for persisted assignment;
- Teacher resource reuse with key stripping;
- client-side hiding of answer keys;
- generic full Question `configuration`;
- per-Question hidden SQL queries;
- stale Scheduler-only deadline state;
- score/official-score calculation.

---

# 31. Completion Report

Return only:

```text
IMPLEMENTATION COMPLETE
```

or:

```text
BLOCKED
```

with:

1. implementation summary;
2. changed files and purpose;
3. exact focused verification results;
4. security/privacy test evidence;
5. deadline reconciliation evidence;
6. directly affected regressions;
7. `git diff --check`;
8. scope/non-goal confirmation;
9. deviations/blockers;
10. final `git status --short`.

Do not claim `Accepted`.

Do not commit/push/create PR/update Stage bookkeeping unless explicitly instructed later.
