# Codex Implementation Contract: S07-BE-005 — Typed Student Answer Save / Replace

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S07-BE-005` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel typed Student Homework answer save/replace + resume answer read state` |
| Depends on | `S07-BE-001…004` — all `Accepted / Delivered` before implementation |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Implementation baseline | ChatGPT re-checks/freezes current `origin/main` immediately before Codex starts |
| Readiness Gate | `PASS`, conditional on dependencies above |
| Verification | focused Student answer/API/persistence/concurrency verification only |
| Delivery | Project Owner |
| Backend block checkpoint | Stage 7 Backend Phase 2 after `S07-BE-001…007` |

Start only after all dependencies are delivered, the implementation baseline is re-checked, and Git preflight is safe.

Do not create a duplicate `CODEX-PROMPT`.

---

# 2. Context Boundary

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. delivered `S07-BE-001…004` source/tests directly required here;
5. current Question/typed Question Models and `QuestionAuthoringLimits`;
6. current Student Attempt controller/resource/access patterns;
7. current API error infrastructure needed for the two new error mappings below.

Do not read roadmap/product/architecture/database/API docs, previous task files, Stage history/indexes/closure reviews, frontend, or unrelated modules to determine requirements.

This contract resolves:

- exact endpoint;
- strict JSON shapes for eight non-file Question types;
- validation limits;
- own-Attempt/Question/tenant scope;
- deadline and lifecycle precedence;
- save/replace/clear semantics;
- typed normalized persistence;
- no-op semantics;
- response/read representation;
- answer locking/concurrency;
- no-scoring boundary;
- error behavior;
- tests and verification.

If delivered dependencies materially conflict with this contract, return `BLOCKED` with exact evidence. Do not redesign.

---

# 3. Goal

Implement:

```text
PUT /api/v1/student/attempts/{attempt}/answers/{question}
```

for these eight Question types:

```text
single_choice
multiple_choice
true_false
short_written
open_written
matching
ordering
fill_in_blank
```

The endpoint must:

- mutate only the authenticated Student's current `in_progress` Homework Attempt;
- replace the complete saved answer for one Question atomically;
- allow partial progressive answers where defined below;
- reject post-deadline/post-finalization writes;
- persist only BE-001 normalized typed tables;
- preserve exact Student text where saved;
- never score/check answers;
- make saved answers available through `GET /student/attempts/{attempt}` for resume.

`file_based` is deliberately deferred to `S07-BE-006`.

---

# 4. Explicit Non-Goals

Do not implement:

- file answer upload/replace/download;
- final Homework Submit;
- idempotency key for ordinary answer PUT;
- auto checking;
- Short Written correctness matching;
- awarded points;
- Teacher review;
- Attempt score;
- official Homework score;
- Topic result;
- Blitz;
- frontend;
- E2E/seeders;
- schema migration;
- docs/task bookkeeping;
- new package/dependency;
- unrelated refactor.

Do not introduce a generic JSON answer payload.

---

# 5. Route

Modify:

```text
backend/routes/api.php
```

inside the existing Student middleware group:

```text
auth:sanctum
active.account
password.changed
role:student
```

Add exactly:

```text
PUT student/attempts/{attempt}/answers/{question}
```

Controller:

```text
App\Http\Controllers\Api\V1\Student\StudentHomeworkAttemptAnswerController
```

Method:

```text
update
```

No route alias.

---

# 6. Request Content Contract

Create:

```text
backend/app/Http/Requests/Student/StudentHomeworkAttemptAnswerRequest.php
```

Requirements:

```text
Content-Type = application/json
body = one JSON object
no query parameters
```

Reject:

- missing/empty body;
- malformed JSON;
- JSON array;
- JSON scalar/null;
- non-JSON body;
- unknown top-level key;
- unknown nested object key;
- protected/internal fields.

All failures use:

```text
422 validation_failed
```

unless Section 13 explicitly defines `selection_limit_exceeded`.

Do not accept:

```text
attempt_id
question_id
institution_id
student_id
checking_status
awarded_points
feedback
checked_by_user_id
checked_at
is_correct
correct_value
accepted_answers
correct_position
match_key
```

anywhere in the body.

---

# 7. Allowed Request Types / Exact Shapes

`type` is always required and only these values are accepted in BE-005:

```text
single_choice
multiple_choice
true_false
short_written
open_written
matching
ordering
fill_in_blank
```

`file_based` is not accepted by this endpoint in BE-005.

## 7.1 Single Choice

Exact top-level keys:

```text
type
selected_option_ids
```

Body:

```json
{
  "type": "single_choice",
  "selected_option_ids": ["option-uuid"]
}
```

Validation:

```text
selected_option_ids = array
count = exactly 1
element = UUID string
no duplicate IDs
```

Single Choice has no clear-via-empty operation in this contract.

## 7.2 Multiple Choice

Exact keys:

```text
type
selected_option_ids
```

Body:

```json
{
  "type": "multiple_choice",
  "selected_option_ids": [
    "option-uuid-1",
    "option-uuid-2"
  ]
}
```

Shape validation:

```text
selected_option_ids = array
count 0..20
each = UUID string
distinct IDs
```

Domain validation later applies the actual Question:

```text
count(selected_option_ids) <= max_selections
```

where:

```text
max_selections =
count(question_choice_options where is_correct = true)
```

Exceeding the Question-specific cap:

```text
422 selection_limit_exceeded
```

An empty array means:

```text
clear this answer
```

and produces no persisted `attempt_answers` row.

## 7.3 True / False

Exact keys:

```text
type
value
```

Body:

```json
{
  "type": "true_false",
  "value": true
}
```

`value` must be a real JSON boolean.

Strings/numbers such as:

```text
"true"
1
0
```

are invalid.

No clear operation is defined for this type.

## 7.4 Short Written

Exact keys:

```text
type
text
```

Body:

```json
{
  "type": "short_written",
  "text": "DNS"
}
```

Validation:

```text
text = string
Unicode character length <= 1000
```

Storage:

- preserve submitted text exactly;
- do not lowercase/trim/collapse/normalize it before persistence.

Semantic empty:

```text
trim(text) == ''
```

means:

```text
clear this answer
```

and no `attempt_answers` row remains.

Stage 9 later applies scoring normalization to the preserved text.

## 7.5 Open Written

Exact keys:

```text
type
text
```

Body:

```json
{
  "type": "open_written",
  "text": "Longer explanation..."
}
```

Validation:

```text
text = string
Unicode character length <= 20000
```

Storage preserves exact submitted text.

Semantic empty:

```text
trim(text) == ''
```

means clear.

No Teacher/manual checking behavior is invoked here.

## 7.6 Matching

Exact keys:

```text
type
pairs
```

Body:

```json
{
  "type": "matching",
  "pairs": [
    {
      "left_item_id": "uuid",
      "right_item_id": "uuid"
    }
  ]
}
```

Validation:

```text
pairs = array
count 0..50
each item = object with exactly:
  left_item_id
  right_item_id
both values = UUID strings
left IDs distinct inside request
right IDs distinct inside request
```

Partial answer is valid.

An empty array means clear.

Domain rules:

- every `left_item_id` belongs to this Question and has `side = left`;
- every `right_item_id` belongs to this Question and has `side = right`;
- no item from another Question/Institution is accepted;
- one left and one right item may appear at most once.

Do not compare against `match_key`.

## 7.7 Ordering

Exact keys:

```text
type
items
```

Body:

```json
{
  "type": "ordering",
  "items": [
    {
      "item_id": "uuid",
      "position": 1
    },
    {
      "item_id": "uuid",
      "position": 2
    }
  ]
}
```

Validation:

```text
items = array
count 0..50
each item = object with exactly:
  item_id
  position
item_id = UUID string
position = integer
item IDs distinct
positions distinct
```

Domain rules:

- every item belongs to this Question;
- `1 <= position <= total Question ordering-item count`.

A partial subset is valid.

Positions need not be contiguous for a partial save.

Example with total 5:

```text
item A -> position 2
item B -> position 5
```

is structurally valid as a partial answer.

An empty array means clear.

Do not read/compare `correct_position`.

## 7.8 Fill in the Blank

Exact keys:

```text
type
values
```

Body:

```json
{
  "type": "fill_in_blank",
  "values": [
    {
      "blank_id": "uuid",
      "text": "domain name"
    }
  ]
}
```

Validation:

```text
values = array
count 0..50
each item = object with exactly:
  blank_id
  text
blank_id = UUID string
text = string
Unicode character length <= 1000
blank IDs distinct
```

For each included element:

```text
trim(text) must be non-empty
```

To clear one previously saved blank, omit it from the replacement `values` set.

Partial answer is valid.

An empty array means clear the complete Fill Blank answer.

Every `blank_id` must belong to this Question.

Do not load/compare accepted answers.

---

# 8. Question Type Match

The body `type` must exactly equal the locked route Question's persisted type.

Mismatch:

```text
422 validation_failed
```

field:

```text
type
```

Suggested message:

```text
The answer type does not match the Question type.
```

This includes attempts to send a non-file payload to a file-based Question.

If body uses:

```text
type = file_based
```

the Form Request rejects it as unsupported in BE-005.

---

# 9. Preliminary Access / Privacy

Reuse delivered BE-004:

```text
StudentHomeworkAttemptAccess
```

Before mutation:

1. resolve `{attempt}` as authenticated Student's own Homework Attempt;
2. validate `{question}` UUID;
3. preliminarily resolve Question only when:

```text
question.institution_id = student.institution_id
question.assessment_id = attempt.assessment_id
question.id = route question
```

Malformed/inaccessible/foreign/wrong-Assessment Question:

```text
404 resource_not_found
```

Other Student/cross-Institution Attempt:

```text
404 resource_not_found
```

Do not expose existence through validation details.

Current Group membership is not required.

---

# 10. Mutation Lock Order

Create:

```text
backend/app/Actions/Student/SaveStudentHomeworkAttemptAnswer.php
```

and any one focused Student access extension/support class needed for locking.

After preliminary privacy-safe resolution, enter:

```text
DB::transaction(...)
```

Lock in this order:

```text
Topic
-> Assessment
-> HomeworkAssignment
-> authenticated Student AssessmentAttempt
-> Question
-> existing AttemptAnswer for Attempt+Question, if any
```

The parent lock path must be the delivered BE-004 Student-safe path.

Do not acquire a Group lock.

Do not acquire a result-pair lock; answer content does not mutate pair meaning.

This ordering is compatible with Teacher Question mutation:

```text
... Homework
-> result pair
-> Attempts
-> Questions
```

because Student never holds Question before Attempt.

---

# 11. Locked Mutation Preconditions / Error Precedence

After required locks, capture:

```text
observedAt = now()
```

Use this order.

## 11.1 Homework lifecycle

If Homework:

```text
closed => 409 task_closed
archived => 409 task_archived
draft => 409 task_not_active
```

If Homework is `active`, continue.

If active Homework belongs to a non-active Topic/inconsistent parent state:

```text
409 task_not_active
```

No answer writes.

## 11.2 Deadline

If:

```text
homework.deadline_at != null
AND observedAt >= deadline_at
```

return an internal deadline marker from the transaction with **zero answer writes**.

After the transaction releases its locks:

1. call delivered:

```text
FinalizeHomeworkAttemptsAtDeadline(
  student.institution_id,
  assessment.id
)
```

2. then throw the delivered Student:

```text
409 deadline_passed
```

This ensures:

- no post-deadline answer write can commit;
- deadline reconciliation occurs before the API response;
- normal answer saves do not lock every Student's Attempt.

Do not throw the deadline exception after performing reconciliation inside the same transaction if that would roll back reconciliation.

## 11.3 Attempt editability

After passing active/deadline rules require:

```text
attempt.status = in_progress
attempt.finalized_at = null
attempt.locked_at = null
```

Otherwise:

```text
409 attempt_not_editable
```

No answer writes.

An explicitly submitted Attempt while Homework is still active therefore returns `attempt_not_editable`.

---

# 12. Current Question / Typed Child Validation

The Question must still belong to the locked Assessment and Institution.

Load/lock only the current Question's needed typed rows.

## Choice

Lock all options ordered:

```text
position
id
```

Validate requested option IDs against this set.

## True/False

No correct-answer row is needed for saving.

Do not load:

```text
correct_value
```

## Short/Open

No accepted-answer row is needed.

Do not load:

```text
question_short_accepted_answers
```

## Matching

Lock:

```text
question_matching_items
```

for this Question.

Only use:

```text
id
side
```

Do not use `match_key`.

## Ordering

Lock Question ordering items.

Use only IDs/count for request validation.

Do not use `correct_position`.

## Fill Blank

Lock Question blanks.

Use:

```text
id
position
```

Do not load accepted answers.

No validation may reveal protected answer-key values.

---

# 13. Multiple Choice Selection Limit

Create:

```text
backend/app/Exceptions/Student/SelectionLimitExceededException.php
```

The domain calculates:

```text
max_selections =
number of this Question's options with is_correct = true
```

This is the only BE-005 save validation that needs the internal correctness flag.

Do not expose which options are correct.

If persisted Multiple Choice configuration has:

```text
max_selections < 1
```

treat as server/business invariant failure:

```text
409 business_conflict
```

If request count exceeds max:

```text
422 selection_limit_exceeded
```

Suggested message:

```text
Too many options were selected for this Question.
```

Errors:

```json
{
  "selected_option_ids": [
    "Select no more than the allowed number of options."
  ]
}
```

Add the stable API code without changing general `validation_failed`.

---

# 14. Invalid Typed Child IDs

Syntactically valid UUIDs that do not belong to the locked Question/Institution are invalid input, not authorization to another object.

Return:

```text
422 validation_failed
```

with a generic field-level error.

Examples:

```text
selected_option_ids
pairs
items
values
```

Do not reveal whether the foreign ID exists or its owner.

Side mismatch in Matching uses the same generic validation failure.

No DB exception should escape for these expected input errors.

---

# 15. Answer Persistence Boundary

Use the delivered BE-001 normalized tables only.

A persisted non-file answer always has:

```text
attempt_answers:
  institution_id = Attempt Institution
  attempt_id = own Attempt
  question_id = locked Question
  checking_status = pending
  awarded_points = null
  feedback = null
  checked_by_user_id = null
  checked_at = null
```

Do not score/check on save.

No `attempt_answers` row is created for semantic-empty/cleared state.

---

# 16. Existing Answer Integrity

Before replace/clear, the locked existing `AttemptAnswer`, if any, must have:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

and must contain only the typed child structure compatible with the current Question type.

If not:

```text
409 business_conflict
```

Do not erase Teacher/scoring state or silently repair incompatible typed rows.

A non-file Question must not have an `answer_files` row.

---

# 17. Save / Replace / Clear Semantics

The endpoint represents:

```text
replace the complete answer for this one Question
```

not patch individual typed child rows.

## 17.1 First non-empty save

Create one `AttemptAnswer` and its typed payload atomically.

## 17.2 Replace

Preserve:

```text
attempt_answers.id
attempt_answers.created_at
```

Update:

```text
attempt_answers.updated_at = savedAt
```

and replace its typed children atomically.

Capture one:

```text
savedAt = now()
```

for a real semantic mutation.

Use that instant consistently for newly inserted child timestamps where applicable.

## 17.3 Clear

For types where Sections 7.x define semantic empty:

1. delete expected typed child rows;
2. delete the parent `attempt_answers` row;
3. leave no empty parent Answer placeholder.

BE-001 uses `ON DELETE RESTRICT`, so delete child rows before parent.

If no answer exists already:

```text
clear = write-free no-op
```

## 17.4 No parent Attempt touch

Do not modify:

```text
assessment_attempts.updated_at
started_at
status
locked_at
finalization fields
score fields
```

during an answer save.

---

# 18. Canonical Semantic Equality / No-Op

A repeated semantically identical PUT returns `200` but performs zero DB writes.

Do not rewrite answer/child timestamps.

Canonical comparison:

## Single/Multiple Choice

Selection order is not semantic.

Canonicalize by locked Question option:

```text
position ASC
id ASC
```

## True/False

Boolean equality.

## Short/Open

Exact stored string equality.

Do not normalize whitespace/case for no-op comparison.

## Matching

Pair-array order is not semantic.

Canonicalize by:

```text
left_item_id ASC
then right_item_id ASC
```

The left→right mapping itself is semantic.

## Ordering

Canonicalize by:

```text
position ASC
then item_id ASC
```

Both item ID and submitted position are semantic.

## Fill Blank

Array order is not semantic.

Canonicalize by Question blank:

```text
position ASC
id ASC
```

Text is exact.

Semantic-clear against no existing answer is a no-op.

---

# 19. Typed Replacement Details

## 19.1 Choice

Persistence:

```text
answer_choice_selections
```

Delete old selected pivots and insert canonical current set only when semantic value changed.

Single Choice persists exactly one pivot.

Multiple Choice persists 1..max when non-empty.

## 19.2 True/False

Persistence:

```text
answer_boolean_values
```

One row keyed by `answer_id`.

Replace boolean value only on change.

## 19.3 Written

Persistence:

```text
answer_text_values
```

One row keyed by `answer_id`.

Preserve exact text.

## 19.4 Matching

Persistence:

```text
answer_matching_pairs
```

Each submitted mapping persists one row.

No `match_key` is copied.

## 19.5 Ordering

Persistence:

```text
answer_ordering_items
```

API positions are 1-based.

Persist:

```text
submitted_position = request.position
```

Do not convert to zero-based.

## 19.6 Fill Blank

Persistence:

```text
answer_fill_blank_values
```

Persist exact submitted text.

No accepted answer is copied.

---

# 20. Mutation Result

Create:

```text
backend/app/Support/Student/StudentHomeworkAttemptAnswerMutationResult.php
```

It contains:

```text
question
attemptAnswer|null
```

where null means the answer is now cleared/unanswered.

Controller returns:

```text
200 OK
```

for:

- first save;
- replace;
- clear;
- no-op.

No `201`.

---

# 21. Answer State Resource

Create:

```text
backend/app/Http/Resources/Student/StudentAttemptAnswerStateResource.php
```

The PUT response shape is:

```json
{
  "data": {
    "question_id": "question-uuid",
    "type": "multiple_choice",
    "answer": {
      "selected_option_ids": [
        "option-uuid-1",
        "option-uuid-2"
      ]
    },
    "updated_at": "2026-09-08T12:10:00Z"
  }
}
```

For a cleared/unanswered result:

```json
{
  "data": {
    "question_id": "question-uuid",
    "type": "multiple_choice",
    "answer": null,
    "updated_at": null
  }
}
```

Timestamps are UTC RFC3339 `...Z`.

Do not expose:

```text
AttemptAnswer.id
institution_id
attempt_id
checking_status
awarded_points
feedback
checked_by_user_id
checked_at
correctness values
```

---

# 22. Canonical Answer JSON by Type

Inside the state resource:

## Single / Multiple Choice

```json
{
  "selected_option_ids": ["uuid"]
}
```

Use canonical option authoring order.

## True / False

```json
{
  "value": true
}
```

## Short / Open Written

```json
{
  "text": "exact persisted text"
}
```

## Matching

```json
{
  "pairs": [
    {
      "left_item_id": "uuid",
      "right_item_id": "uuid"
    }
  ]
}
```

Canonical left-ID order.

## Ordering

```json
{
  "items": [
    {
      "item_id": "uuid",
      "position": 1
    }
  ]
}
```

Canonical submitted-position order.

## Fill Blank

```json
{
  "values": [
    {
      "blank_id": "uuid",
      "text": "exact persisted text"
    }
  ]
}
```

Canonical Question blank order.

`file_based` is not handled until BE-006.

---

# 23. Extend Attempt Resume Read

Modify delivered:

```text
ShowStudentHomeworkAttempt
StudentHomeworkAttemptResource
```

so:

```text
GET /api/v1/student/attempts/{attempt}
```

and Start/resume responses now include:

```json
"answers": [
  {
    "question_id": "uuid",
    "type": "true_false",
    "answer": {
      "value": true
    },
    "updated_at": "2026-09-08T12:10:00Z"
  }
]
```

Only persisted non-empty answers appear.

Unanswered Questions have no fabricated answer entry.

Order `answers` by:

```text
Question.position ASC
Question.id ASC
```

## 23.1 Safe eager loading

Load the current Student Attempt's:

```text
answers
```

plus only the typed Student answer rows required for serialization.

For selected choices, load only IDs/order metadata needed to canonicalize; do not serialize option correctness.

Do not load:

```text
Question correct_value
Short accepted answers
Matching match_key
Ordering correct_position
Fill accepted answers
```

through answer serialization.

No hidden queries from Resources.

---

# 24. Controller

Create:

```text
backend/app/Http/Controllers/Api/V1/Student/StudentHomeworkAttemptAnswerController.php
```

`update` stays thin:

```text
validated request
-> authenticated Student
-> SaveStudentHomeworkAttemptAnswer
-> StudentAttemptAnswerStateResource
```

No business/tenant/deadline/persistence branching in Controller.

---

# 25. New Error Mapping

Create:

```text
backend/app/Exceptions/Student/AttemptNotEditableException.php
backend/app/Exceptions/Student/SelectionLimitExceededException.php
```

Modify:

```text
backend/bootstrap/app.php
backend/app/Support/ApiErrorResponse.php
```

Mappings:

## Attempt not editable

```text
HTTP 409
code = attempt_not_editable
message = This Homework attempt is no longer editable.
```

## Selection limit

```text
HTTP 422
code = selection_limit_exceeded
message = Too many options were selected for this Question.
errors.selected_option_ids = [
  Select no more than the allowed number of options.
]
```

Reuse delivered Student task/deadline/business exceptions from BE-004.

Do not change unrelated API error messages.

---

# 26. Concurrency Contract

The locked Attempt row serializes all answer mutations for one Attempt.

This is intentional:

- two simultaneous saves cannot interleave typed child deletion/insertion;
- final Submit in BE-007 can later lock the same Attempt and freeze a complete state;
- Teacher close/deadline finalization also serializes against the Attempt.

## 26.1 Same Question concurrent replacements

Two simultaneous valid PUTs for the same Attempt/Question must result in:

```text
one AttemptAnswer
one complete typed payload
```

matching one whole request or the other.

Never a mixed payload.

## 26.2 Different Questions same Attempt

They may serialize on the Attempt lock.

Correctness is preferred over per-question write parallelism in MVP.

## 26.3 Save vs Teacher close

Because both ultimately lock the same parent/Attempt chain:

- save commits first → close may then preserve and auto-finalize it;
- close commits first → save sees closed/non-editable state and writes nothing.

## 26.4 Save vs deadline

A save may commit only if its locked `observedAt` is strictly before deadline.

At/effectively after deadline:

```text
no answer write
deadline reconciliation
409 deadline_passed
```

---

# 27. Expected Files

## Create

```text
backend/app/Actions/Student/SaveStudentHomeworkAttemptAnswer.php

backend/app/Support/Student/StudentHomeworkAttemptAnswerMutationResult.php

backend/app/Http/Requests/Student/StudentHomeworkAttemptAnswerRequest.php
backend/app/Http/Controllers/Api/V1/Student/StudentHomeworkAttemptAnswerController.php
backend/app/Http/Resources/Student/StudentAttemptAnswerStateResource.php

backend/app/Exceptions/Student/AttemptNotEditableException.php
backend/app/Exceptions/Student/SelectionLimitExceededException.php

backend/tests/Feature/Student/StudentHomeworkAnswerSaveApiTest.php
backend/tests/Feature/Student/StudentHomeworkAnswerValidationTest.php
backend/tests/Feature/Student/StudentHomeworkAnswerLifecycleTest.php
backend/tests/Feature/Student/StudentHomeworkAnswerConcurrencyTest.php
```

## Modify

```text
backend/routes/api.php
backend/bootstrap/app.php
backend/app/Support/ApiErrorResponse.php

backend/app/Actions/Student/ShowStudentHomeworkAttempt.php
backend/app/Http/Resources/Student/StudentHomeworkAttemptResource.php
```

Modify delivered BE-004 Student Attempt access/support only if a focused lock method is needed.

No migration, file-storage, Submit/scoring/docs/frontend/E2E files.

---

# 28. `StudentHomeworkAnswerSaveApiTest`

Build one active assigned Homework Attempt with all eight non-file Question types.

At minimum verify happy-path save and replace for each.

## Single Choice

- save exactly one valid option;
- replace with another;
- one parent Answer;
- one pivot;
- response canonical.

## Multiple Choice

- save one/multiple within cap;
- replace;
- order-insensitive same set is write-free no-op;
- empty array clears parent Answer.

## True/False

- true save;
- false replace;
- exact boolean response.

## Short Written

- exact text persisted including meaningful leading/trailing whitespace when non-empty;
- changed exact text updates;
- whitespace-only clears.

## Open Written

Same persistence/clear behavior with longer text.

## Matching

- partial mapping valid;
- replace complete set;
- request pair order irrelevant for no-op;
- canonical response.

## Ordering

- partial subset valid;
- positions are persisted 1-based;
- replace;
- canonical response ordered by submitted position;
- empty clears.

## Fill Blank

- partial values valid;
- omitted prior blank is removed on replace;
- exact text preserved;
- request order irrelevant;
- empty clears.

For every persisted Answer verify:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

No score fields on Attempt change.

---

# 29. `StudentHomeworkAnswerValidationTest`

At minimum:

## Strict JSON

Reject:

- no body;
- malformed JSON;
- non-object;
- wrong content type;
- unknown top-level key;
- unknown nested keys;
- query params.

## Type

- missing;
- unsupported;
- `file_based`;
- body type != actual Question type.

## Single

- empty;
- >1;
- malformed UUID;
- duplicate;
- option from another Question/Institution.

## Multiple

- malformed/duplicate IDs;
- foreign/wrong Question option;
- count > Question `max_selections` → exact `selection_limit_exceeded`;
- empty is valid clear.

## True/False

Reject non-boolean.

## Written

- non-string;
- Short >1000 chars;
- Open >20000 chars.

## Matching

- >50;
- missing/extra nested keys;
- duplicate left/right IDs;
- wrong Question item;
- left ID with `side=right`;
- right ID with `side=left`;
- empty clear.

## Ordering

- >50;
- duplicate item IDs;
- duplicate positions;
- non-integer;
- position <1;
- position > total Question items;
- wrong Question item;
- empty clear.

## Fill

- >50;
- duplicate blanks;
- wrong Question blank;
- text >1000;
- included whitespace-only text invalid;
- empty clear.

Validation failures must commit zero answer changes.

No private correct-answer values appear in error payloads.

---

# 30. `StudentHomeworkAnswerLifecycleTest`

At minimum verify:

## Ownership/privacy

- other Student Attempt → 404;
- foreign Institution Attempt → 404;
- Question from another Assessment → 404;
- malformed IDs → 404.

## Current Group membership removed

Persisted assignment/own Attempt remains editable while lifecycle/deadline allow.

## Submitted Attempt

Active Homework + explicit terminal/submitted Attempt:

```text
409 attempt_not_editable
```

No mutation.

## Teacher closed

```text
409 task_closed
```

No mutation.

## Archived

```text
409 task_archived
```

## Deadline exact/after

At:

```text
observedAt >= deadline
```

- no answer change;
- BE-002 reconciliation occurs;
- Attempt becomes deadline-finalized;
- `409 deadline_passed`.

## Before deadline

Save succeeds.

## Existing saved answer at deadline

Rejected post-deadline save does not replace existing payload before finalization.

## Repeated no-op

Same semantic PUT:

- `200`;
- AttemptAnswer/typed-child timestamps unchanged;
- Attempt timestamp unchanged.

## Clear no-op

Clear when absent:

- `200`;
- no DB write;
- response `answer = null`.

---

# 31. `StudentHomeworkAnswerConcurrencyTest`

Use real PostgreSQL process concurrency and existing lock-wait test style.

At minimum prove same Attempt + same Question concurrent replacement.

Use a multi-row type such as:

```text
multiple_choice
```

or:

```text
matching
```

First worker holds the Attempt lock after resolving its requested canonical value.

Second worker starts and must enter a PostgreSQL lock wait.

Release first.

Final DB must contain exactly one coherent final payload corresponding to a complete committed request.

Assert:

```text
1 AttemptAnswer
no duplicate/mixed child set
checking_status remains pending
no score fields
```

No arbitrary sleep as synchronization.

Do not add broad Submit concurrency here; BE-007 owns Submit races.

---

# 32. Attempt Resume Regression

Extend/assert through the new tests that:

```text
GET /student/attempts/{attempt}
```

returns all saved non-file answers in canonical Question order.

Verify recursively that answer output contains none of:

```text
is_correct
correct_value
accepted_answers
correct_position
match_key
checking_status
awarded_points
```

Start/resume response after existing saved answers uses the same Attempt Resource and includes them.

---

# 33. Directly Affected Regression Tests

Run BE-005 tests plus:

```text
tests/Feature/Student/StudentHomeworkAttemptStartApiTest.php
tests/Feature/Student/StudentHomeworkAttemptIdempotencyTest.php
tests/Feature/Student/StudentHomeworkQuestionPrivacyTest.php
tests/Feature/Student/StudentHomeworkDeadlineReadReconciliationTest.php

tests/Feature/Homework/HomeworkDeadlineFinalizationTest.php

tests/Feature/Persistence/StudentAnswerSubmissionPersistenceTest.php
tests/Feature/Persistence/StudentAnswerSubmissionFactoryModelTest.php
```

Rationale:

- Attempt resource is extended;
- Student-safe Question privacy must remain intact;
- deadline action is reused;
- BE-001 typed persistence is now publicly mutated.

Do not run full backend suite.

---

# 34. Verification

Use the repository's normal Docker/Sail backend command wrapper.

Run required formatter/static check for changed PHP files.

Then exactly:

```bash
php artisan test \
  tests/Feature/Student/StudentHomeworkAnswerSaveApiTest.php \
  tests/Feature/Student/StudentHomeworkAnswerValidationTest.php \
  tests/Feature/Student/StudentHomeworkAnswerLifecycleTest.php \
  tests/Feature/Student/StudentHomeworkAnswerConcurrencyTest.php \
  tests/Feature/Student/StudentHomeworkAttemptStartApiTest.php \
  tests/Feature/Student/StudentHomeworkAttemptIdempotencyTest.php \
  tests/Feature/Student/StudentHomeworkQuestionPrivacyTest.php \
  tests/Feature/Student/StudentHomeworkDeadlineReadReconciliationTest.php \
  tests/Feature/Homework/HomeworkDeadlineFinalizationTest.php \
  tests/Feature/Persistence/StudentAnswerSubmissionPersistenceTest.php \
  tests/Feature/Persistence/StudentAnswerSubmissionFactoryModelTest.php
```

Then repository root:

```bash
git diff --check
```

and focused diff/scope self-review.

Do not run:

- full backend suite;
- frontend tests/build;
- E2E/integration Stage runner.

---

# 35. Acceptance Criteria

PASS only if all are true.

## Endpoint

- exact Student PUT route exists;
- strict JSON/query behavior is enforced;
- only eight non-file types accepted.

## Access/lifecycle

- only authenticated Student's own Attempt can mutate;
- Question must belong to the Attempt Assessment;
- persisted assignment remains authoritative;
- current Group membership not required;
- only `in_progress` active pre-deadline Attempt is editable;
- post-deadline write never commits;
- due request triggers BE-002 reconciliation before error response.

## Validation

- exact typed shapes;
- child IDs scoped to current Question/Institution;
- Matching sides enforced without match-key usage;
- Ordering submitted positions validated without correct-position usage;
- Multiple Choice cap uses count of correct options but exposes no identities;
- exact `selection_limit_exceeded` behavior;
- written/fill text limits enforced.

## Persistence

- normalized BE-001 tables only;
- one parent AttemptAnswer per Attempt/Question;
- checking state always pending/null score on Student save;
- replacement is atomic;
- clear removes child then parent;
- no empty fabricated parent Answer;
- no score/checking writes.

## No-op

- semantically identical request is write-free;
- array order is ignored where not semantic;
- exact text differences remain semantic;
- Attempt timestamps are not touched.

## Resume representation

- GET Attempt and Start/resume responses include canonical saved answer states;
- unanswered Questions remain absent from `answers`;
- no correct-answer/checking/scoring fields leak.

## Concurrency

- real PostgreSQL same-answer replacement race serializes;
- final payload is coherent, never mixed/duplicated.

## Scope

- no file answer behavior;
- no Submit;
- no idempotency for ordinary PUT;
- no scoring/manual review/official result;
- no schema/docs/frontend/E2E;
- no new dependency/unrelated refactor.

## Verification

- focused tests pass;
- named regressions pass;
- formatter/static check passes;
- `git diff --check` passes;
- focused self-review passes.

---

# 36. Locked Implementation Decisions

These are decisions, not suggestions:

```text
PUT semantics = complete replace for one Question
ordinary answer PUT = no Idempotency-Key
Student answer initial checking state = pending
no scoring/checking on save
Single Choice = exactly one
Multiple Choice empty = clear
Multiple Choice cap = count(correct options)
True/False = JSON boolean
Short max = 1000 Unicode chars
Open max = 20000 Unicode chars
Matching partial = allowed
Ordering partial = allowed
Ordering request positions = 1-based
Fill partial = allowed
Written semantic empty = trim(text)=='' => clear
clear = no AttemptAnswer row
same semantic state = write-free 200 no-op
exact Student text = preserved
deadline save gate = server observedAt < deadline
deadline rejection = reconcile through BE-002 then 409
Attempt lock = serialization boundary
file_based = BE-006 only
```

Codex must not substitute:

- generic JSON answer storage;
- auto scoring;
- correct-answer values in response;
- `match_key` comparison;
- `correct_position` comparison;
- current Group membership authorization;
- client/device deadline authority;
- delete-and-recreate parent Answer on every replace;
- timestamp-changing no-op writes.

---

# 37. Completion Report

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
4. typed validation/persistence evidence;
5. deadline/lifecycle evidence;
6. PostgreSQL concurrency evidence;
7. directly affected regressions;
8. `git diff --check`;
9. scope/non-goal confirmation;
10. deviations/blockers;
11. final `git status --short`.

Do not claim `Accepted`.

Do not commit/push/create PR/update Stage bookkeeping unless explicitly instructed later.
