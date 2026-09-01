# Codex Implementation Contract: S06-FE-003 — Nine-Type Question Builder

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S06-FE-003` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter desktop typed Question Builder + add/update/delete/reorder mutations` |
| Depends on | `S06-FE-001`, `S06-FE-002` — both `Accepted / Delivered`; Stage 6 Backend Phase 2 remains `PASS` |
| Planning/readiness baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |
| Backend API dependency | Final delivered S06-BE-004 Question mutation API after Backend Phase 2 |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` immediately before Codex execution |
| Flutter toolchain | FVM-pinned Flutter `3.44.7` unless current `origin/main` deliberately changes the pin |
| Implementation Readiness Gate | `PASS — planning contract`; execution remains dependency-gated |
| Verification | `Codex — focused frontend verification only` |
| Delivery execution | `Project Owner` |
| Frontend block checkpoint | Stage 6 Frontend Phase 2 after `S06-FE-001…004` are `Accepted / Delivered` |

Do not start implementation until:

```text
Stage 6 Backend Phase 2 = PASS
S06-FE-001 = Accepted / Delivered
S06-FE-002 = Accepted / Delivered
current origin/main re-checked
final Question mutation API inspected
current FE-001/002 Homework domain/routes/controllers inspected
this contract still matches current implementation
clean synchronized local main
```

If delivered dependencies materially conflict with this contract, return `BLOCKED` with exact evidence. Do not invent a new Question/API/business/UX contract.

This file is the complete task-specific implementation contract. Do not create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. delivered S06-FE-001/S06-FE-002 source and focused tests directly required by this task;
5. final delivered Stage 6 backend Question mutation route/resource implementation needed to confirm the API already encoded below;
6. directly relevant current Teacher form/dialog/state patterns.

Do not read product specifications, roadmap files, Stage history, previous task specifications, checkpoint reviews, closure reviews, or unrelated modules to determine requirements.

This contract already resolves:

- Question Builder route/capability;
- all nine Question form models;
- local authoring limits;
- type/checking-mode behavior;
- add/edit/delete/reorder UX;
- append-only add position;
- exact mutation payloads;
- type-specific configuration serialization;
- Matching request correlation keys;
- Fill-in-the-Blank placeholder validation;
- server-authoritative total points;
- mutation uncertainty and reconciliation;
- scoring-content lock handling;
- active Homework behavior;
- local order staging;
- stale async/session/target safety;
- accessibility;
- focused tests.

---

# 3. Goal

Add a production-quality desktop Teacher Question Builder for Stage 6 Homework.

The Teacher must be able to:

- open a draft or active Homework's Question Builder;
- add any of the nine supported Question types;
- edit any existing Question before backend editing integrity blocks it;
- delete Questions before backend editing integrity blocks it;
- stage and save Question order;
- see authoritative Homework total points after every confirmed server mutation;
- recover safely from uncertain mutation outcomes without automatic replay;
- receive clear server-authoritative lock/conflict feedback.

Mobile remains read-only through the FE-001 Homework detail screen.

---

# 4. Included Backend Mutation API

Use exactly:

```text
POST   /teacher/assessments/{homeworkId}/questions
PATCH  /teacher/questions/{questionId}
DELETE /teacher/questions/{questionId}
POST   /teacher/assessments/{homeworkId}/questions/reorder
```

Configured Dio base already includes:

```text
/api/v1
```

All successful mutations return the complete authoritative Teacher Homework resource.

Expected success:

```text
Add      -> 201 + "Question created successfully."
Update   -> 200 + "Question updated successfully."
Delete   -> 200 + "Question deleted successfully."
Reorder  -> 200 + "Questions reordered successfully."
```

Do not call Homework metadata PATCH to mutate Questions.

---

# 5. Explicit Non-Goals

Do not implement:

- Homework metadata create/edit behavior beyond FE-002 integration;
- Homework activate/close/archive controls;
- official Homework designation;
- result-pair client;
- Student answer entry;
- Student Attempt UI;
- automatic checking;
- manual checking;
- score calculation;
- Blitz;
- mobile Question authoring;
- Question bank/reuse;
- import/export Questions;
- bulk Question copy;
- rich-text/HTML editor;
- image/audio/video Question content;
- per-Question timers;
- negative marking;
- fuzzy/AI answer matching;
- drag-and-drop package;
- new Flutter package;
- backend changes;
- code generation framework;
- optimistic mutation success;
- automatic mutation replay;
- full frontend suite/build/E2E.

Do not expose future lifecycle/designation controls as disabled placeholders in this task.

---

# 6. Dependency Contract from FE-001 / FE-002

Reuse equivalent delivered boundaries:

```text
TeacherHomework
TeacherQuestion
TeacherQuestionType
TeacherQuestionCheckingMode
typed TeacherQuestionConfiguration hierarchy
TeacherHomeworkRepository
TeacherHomeworkRemoteDataSource
TeacherHomeworkRouteTarget
teacherHomeworkDetailControllerProvider(target)
TeacherHomeworkDetailScreen
TeacherHomeworkEditScreen
TeacherSessionKey
InstitutionTimezone
ApiErrorCodes
```

S06-FE-003 must extend the existing Homework repository/data source rather than create a second Question-only transport root unless a narrow separate interface is required by the delivered FE architecture.

Preferred:

```text
TeacherHomeworkRepository
  + addQuestion
  + updateQuestion
  + deleteQuestion
  + reorderQuestions
```

The Question resource returned inside full Homework remains the FE-001 typed domain model.

---

# 7. Question Builder Route

Add one desktop authoring route:

```text
/teacher/topics/{topicId}/homework/{homeworkId}/questions
```

Recommended route constants:

```text
teacherHomeworkQuestionsSegment = questions
teacherHomeworkQuestions
teacherHomeworkQuestionsLocation(topicId, homeworkId)
isTeacherHomeworkQuestionsPath(path)
```

Recommended route name:

```text
teacherHomeworkQuestions
```

Nest under the existing Homework detail route.

Builder:

```text
TeacherQuestionBuilderScreen(
  topicId: ...,
  homeworkId: ...,
)
```

Use:

```text
_buildTeacherDestination(
  ...,
  authoring: true,
)
```

Desktop only.

Do not create a new ShellRoute.

---

# 8. Mobile Route Behavior

Authenticated Teacher + mobile:

```text
/teacher/topics/<topic>/homework/<homework>/questions
  -> /teacher/topics/<topic>/homework/<homework>
```

Do not transiently render the Question Builder on mobile.

Valid Homework detail remains mobile-supported.

During auth bootstrap, normalize unsupported mobile authoring path to the supported Homework detail location.

Invalid UUID, query, fragment, or extra segment remains rejected by existing Teacher route safety.

---

# 9. Homework Detail Integration

Extend FE-001 `TeacherHomeworkDetailScreen`.

On desktop, show working:

```text
Manage Questions
```

only when confirmed Homework status is:

```text
draft
active
```

No control for:

```text
closed
archived
```

No control on mobile.

Navigate to:

```text
teacherHomeworkQuestionsLocation(topicId, homeworkId)
```

Do not infer whether Student Attempts already exist.

Active Homework may still render Manage Questions; backend decides whether editing is locked.

---

# 10. Builder Screen State Source

The builder must use the authoritative FE-001 Homework detail controller for:

```text
TeacherHomeworkRouteTarget(topicId, homeworkId)
```

Do not maintain a second independent Homework cache.

The Builder presentation observes:

```text
loading
data
refreshing
notFound
error
```

from the detail boundary plus its own local mutation/order state.

If detail is unavailable/notFound:

- do not issue Question mutation;
- show safe unavailable/error UI;
- provide Back to Homework/Topic as appropriate.

---

# 11. Builder Editability

## 11.1 Draft

Question mutation controls enabled subject to local busy/order state.

## 11.2 Active

Question mutation controls remain available initially.

Show neutral note:

```text
Question editing may be locked after Student activity begins.
The server will confirm whether changes are still allowed.
```

Do not locally infer Attempt existence.

## 11.3 Closed / Archived

Builder direct route shows review-only state:

```text
Question editing is unavailable for this Homework.
```

Actions:

```text
Back to Homework
```

Do not show add/edit/delete/reorder controls.

## 11.4 Server-locked session state

If a mutation receives:

```text
409 business_conflict
409 result_pair_locked
```

set builder-local:

```text
serverLocked = true
```

after authoritative Homework refresh.

Disable all further Question mutations in that Builder route instance.

Show:

```text
Question editing is locked by the current server state.
Review the current Homework before continuing.
```

Do not claim the exact hidden reason, such as a particular Student Attempt.

A full explicit Refresh may clear `serverLocked` only if the server later returns a state and no new mutation conflict has occurred in the refreshed route instance. Since normal activity locks are effectively permanent, this is mostly defensive.

---

# 12. Question Authoring Limits

Create a focused frontend constants/value boundary:

```text
TeacherQuestionAuthoringLimits
```

Exact values:

```text
maxQuestionsPerAssessment = 100

maxPromptLength = 10000
maxInstructionsLength = 5000

maxChoiceOptions = 20
maxOptionTextLength = 2000

maxShortAcceptedAnswers = 20
maxAcceptedAnswerLength = 1000

maxMatchingPairs = 50
maxMatchingItemTextLength = 2000
maxClientKeyLength = 80

maxOrderingItems = 50
maxOrderingItemTextLength = 2000

maxFillBlanks = 50
maxAcceptedAnswersPerBlank = 20

maxPoints = 999999.999999
maxPointsFractionDigits = 6
```

These are deterministic local request limits from the API contract.

Backend remains final authority.

Do not make them configurable in Flutter.

---

# 13. Question Draft Model

Create an immutable controlled authoring model equivalent to:

```text
TeacherQuestionDraft
```

Common fields:

```text
type
prompt
instructions
pointsText
checkingMode
configurationDraft
```

`position` is not editable inside the Question form.

New Questions are appended automatically.

Existing Question position is changed only by the Builder reorder flow.

---

# 14. Common Question Local Validation

## 14.1 Prompt

On submit:

```text
trim
required
1..10000 chars after trim
```

Request sends trimmed prompt.

## 14.2 Instructions

Optional.

Normalization:

- exact empty String -> `null`;
- non-empty String preserved verbatim;
- max 5000;
- whitespace-only non-empty value is invalid because backend rejects blank non-null instructions.

Do not silently trim non-empty instructions.

## 14.3 Points

Form owns points as text.

Accepted submit grammar:

```text
0
1
1.5
999999.999999
```

Reject:

- blank;
- negative;
- more than 6 fractional digits;
- scientific notation;
- comma decimal separator;
- value > `999999.999999`;
- NaN/Infinity;
- non-numeric text.

A focused parser/value helper may canonicalize the accepted decimal text.

Request sends a JSON number.

`0` is allowed.

Flutter does not decide whether an active Homework aggregate remains scoreable; backend may reject a mutation with:

```text
assessment_has_no_scoreable_points
```

## 14.4 Checking mode

Fixed by Question type except:

```text
short_written
```

which allows:

```text
automatic
manual
```

Do not expose a checking-mode control for fixed-mode types.

---

# 15. New Question Defaults

When opening Add Question:

```text
type = single_choice
prompt = ''
instructions = ''
pointsText = '1'
checkingMode = automatic
```

Initial Single Choice configuration:

```text
2 empty options
first option correct
second option incorrect
```

This is a UI editing skeleton, not a valid submit until option texts are filled.

No Question is persisted until submit succeeds.

---

# 16. Type Change Behavior

Teacher may change Question type before backend lock.

Common fields preserved:

```text
prompt
instructions
pointsText
```

Type-specific configuration is reset to the new type's local skeleton.

If the current type-specific configuration contains meaningful non-empty user content, show confirmation:

```text
Change Question type?
Changing the type will reset its answer configuration.
```

Actions:

```text
Keep current type
Change type
```

Do not silently reinterpret old configuration.

The new checking mode becomes the type's required mode.

For `short_written`, default after type change:

```text
automatic
```

with one empty accepted-answer row.

---

# 17. Single Choice Form

Type:

```text
single_choice
```

Checking mode:

```text
automatic
```

UI:

- ordered option rows;
- text input;
- radio control for exactly one correct answer;
- Add option;
- Remove option;
- Move up/down.

Rules:

```text
2..20 options
each text trimmed on submit
non-empty
max 2000
exactly one correct
```

Positions are derived from current UI list order:

```text
1..N
```

Do not expose numeric position inputs.

Request configuration:

```json
{
  "options": [
    {
      "text": "A",
      "is_correct": true,
      "position": 1
    }
  ]
}
```

No local option IDs in request.

---

# 18. Multiple Choice Form

Type:

```text
multiple_choice
```

Checking mode:

```text
automatic
```

UI same ordered option editor, but correct answers use checkboxes.

Rules:

```text
2..20 options
>=1 correct
all options correct is allowed
```

Do not show/edit:

```text
max_selections
```

Optional informational text:

```text
Students may select up to the number of correct options.
```

This is explanatory only.

Positions derived from UI order.

---

# 19. True / False Form

Type:

```text
true_false
```

Checking mode:

```text
automatic
```

UI:

```text
Correct answer:
  True
  False
```

Use radio/segmented choice.

Configuration:

```json
{
  "correct_value": true
}
```

No extra fields.

---

# 20. Short Written Form

Type:

```text
short_written
```

Expose:

```text
Checking:
Automatic
Manual
```

## 20.1 Automatic

Editor:

- accepted-answer rows;
- Add answer;
- Remove;
- optional Move up/down.

Rules:

```text
1..20 answers
trim each on submit
non-empty
max 1000
exact duplicate canonical submit strings rejected
```

Do not apply Student-answer NFC/casefold/apostrophe normalization.

That is backend checking behavior, not Teacher authoring normalization.

Request:

```json
{
  "accepted_answers": ["DNS"]
}
```

## 20.2 Manual

Configuration:

```json
{}
```

No accepted-answer fields visible.

When switching:

```text
automatic -> manual
```

and non-empty accepted answers exist, confirm that accepted-answer configuration will be removed.

When switching:

```text
manual -> automatic
```

initialize one empty answer row.

---

# 21. Open Written Form

Type:

```text
open_written
```

Checking mode fixed:

```text
manual
```

Show:

```text
This Question is reviewed manually.
```

Configuration:

```json
{}
```

No answer-key fields.

---

# 22. File-Based Form

Type:

```text
file_based
```

Checking mode fixed:

```text
manual
```

Show read-only:

```text
Allowed files:
PDF
DOCX
PPT
PPTX
```

Show:

```text
Manual review
```

Configuration always:

```json
{
  "allowed_extensions": [
    "pdf",
    "docx",
    "ppt",
    "pptx"
  ]
}
```

Do not expose:

- extension checkbox;
- custom extension;
- file-size control.

---

# 23. Matching Form

Type:

```text
matching
```

Checking mode:

```text
automatic
```

UI owns ordered semantic pair rows:

```text
left
right
```

Rules:

```text
1..50 pairs
left trimmed on submit, non-empty, max 2000
right trimmed on submit, non-empty, max 2000
```

Controls:

- Add pair;
- Remove pair;
- Move up/down.

Do not show/edit server `clientKey` from FE-001 read domain.

## 23.1 Request correlation keys

When serializing a Matching mutation that includes configuration, generate deterministic request-only keys by current pair order:

```text
pair_1
pair_2
...
pair_N
```

These satisfy backend request-key grammar.

Do not reuse FE-001 readback server `clientKey` as mutation authority.

This avoids the server UUID/readback format becoming a client mutation identifier.

Configuration:

```json
{
  "pairs": [
    {
      "client_key": "pair_1",
      "left": "DNS",
      "right": "Domain Name System"
    }
  ]
}
```

Request client keys are correlation-only.

Semantic no-op comparison ignores them.

---

# 24. Ordering Form

Type:

```text
ordering
```

Checking mode:

```text
automatic
```

UI shows ordered item text rows.

Controls:

- Add item;
- Remove;
- Move up/down.

Rules:

```text
2..50 items
trim on submit
non-empty
max 2000
```

The current UI list order **is the correct order**.

Do not expose numeric `correct_position` inputs.

Serialize:

```json
{
  "items": [
    {
      "text": "First",
      "correct_position": 1
    }
  ]
}
```

Positions derive from list order `1..N`.

---

# 25. Fill-in-the-Blank Form

Type:

```text
fill_in_blank
```

Checking mode:

```text
automatic
```

The common Question prompt contains placeholders:

```text
{{blank_key}}
```

Example:

```text
DNS converts {{host}} into an {{address}}.
```

Editor owns ordered blank rows:

```text
key
accepted answers
```

Controls:

- Add blank;
- Remove blank;
- Move blank up/down;
- add/remove accepted answer.

## 25.1 Blank key

Rules:

```text
^[A-Za-z][A-Za-z0-9_-]{0,79}$
unique within Question
```

Do not include braces in the key field.

UI helper text:

```text
Use the placeholder {{key}} in the Question prompt.
```

## 25.2 Blank count

```text
1..50
```

Positions derive from blank list order.

## 25.3 Accepted answers

Per blank:

```text
1..20
trim on submit
non-empty
max 1000
exact duplicates rejected within the blank
```

## 25.4 Placeholder validation

On submit parse prompt placeholders matching exactly:

```text
{{[A-Za-z][A-Za-z0-9_-]{0,79}}}
```

Require:

- each configured blank key appears exactly once;
- every matching prompt placeholder has one configured blank;
- no configured blank is missing from prompt;
- duplicate occurrence of the same configured placeholder is invalid.

Literal brace text not matching the grammar is ordinary prompt text.

Show a clear form error:

```text
Each configured blank must appear exactly once in the prompt as {{key}}.
```

Do not auto-rewrite the prompt.

---

# 26. Ordered Local Editor Items

For stable Flutter widget identity, local authoring rows may use UI-only keys:

```text
localId
```

Examples:

- choice option;
- short accepted answer row;
- matching pair;
- ordering item;
- fill blank;
- blank accepted answer.

These keys:

- never enter API payload except generated Matching request `pair_N`;
- are not persisted;
- exist only to stabilize controls/focus/reordering.

Use deterministic monotonic local counters inside the form controller.

Do not add a UUID package.

---

# 27. Question Create Request

Create:

```text
TeacherQuestionCreateRequest
```

Exact serialized keys:

```text
type
prompt
instructions
points
position
checking_mode
configuration
```

No `client_key` at Question top level.

## 27.1 Add position

FE-003 intentionally appends new Questions.

If authoritative Homework currently has:

```text
N Questions
```

send:

```text
position = N + 1
```

Do not expose insertion-position UI.

Teacher can reorder after creation.

If:

```text
N >= 100
```

disable Add Question locally and show:

```text
Maximum 100 Questions.
```

Backend remains final authority.

## 27.2 Payload source

Serialize only from a locally valid canonical `TeacherQuestionDraft`.

No raw TextEditingController values directly in data source.

---

# 28. Question Edit Snapshot

Create:

```text
TeacherQuestionEditSnapshot
```

from authoritative `TeacherQuestion`.

Comparable semantic fields:

```text
type
prompt
instructions
points
checkingMode
typed configuration
```

Ignore:

```text
id
position
server Matching clientKey
```

for form semantic equality except Question identity itself.

Matching semantic configuration comparison uses ordered:

```text
left
right
```

pairs only.

---

# 29. Question Edit Request

Create:

```text
TeacherQuestionEditRequest
```

Allowed keys:

```text
type
prompt
instructions
points
checking_mode
configuration
```

No `position`.

`isEmpty` required.

Include only semantically changed fields.

Rules:

- prompt if changed;
- instructions if changed;
- points if changed;
- type if changed;
- checking mode if changed;
- configuration if semantic config changed;
- if type or checking mode changed, configuration is always included.

Do not send an empty PATCH.

---

# 30. Question Edit `matches(current)`

Implement reconciliation comparison for only fields present in the PATCH.

Rules:

- type/checking exact enum;
- prompt exact canonical submit string;
- instructions exact nullable value;
- points numeric equality against canonical submitted number;
- configuration semantic typed equality.

Matching request correlation keys are ignored.

Do not compare:

- position;
- Homework total;
- unrelated Questions;
- Homework lifecycle timestamps.

---

# 31. Reorder Request

Create:

```text
TeacherQuestionReorderRequest
```

Body exactly:

```json
{
  "question_ids": [
    "uuid-1",
    "uuid-2"
  ]
}
```

IDs:

- canonical;
- unique;
- exact current authoritative set at the moment local order staging begins.

No other keys.

---

# 32. Repository Extension

Extend FE-001/002 `TeacherHomeworkRepository`.

Add equivalent methods:

```text
Future<TeacherHomework> addQuestion(
  String homeworkId,
  TeacherQuestionCreateRequest request,
)

Future<TeacherHomework> updateQuestion(
  String questionId,
  TeacherQuestionEditRequest request,
)

Future<TeacherHomework> deleteQuestion(
  String questionId,
)

Future<TeacherHomework> reorderQuestions(
  String homeworkId,
  TeacherQuestionReorderRequest request,
)
```

Do not create a second full Homework read cache/repository.

---

# 33. Remote Data Source Mutations

Extend `TeacherHomeworkRemoteDataSource` or equivalent.

All:

```text
followRedirects = false
```

## Add

```text
POST /teacher/assessments/{encodedHomeworkId}/questions
201
Question created successfully.
```

## Update

```text
PATCH /teacher/questions/{encodedQuestionId}
200
Question updated successfully.
```

Reject empty local request before transport.

## Delete

```text
DELETE /teacher/questions/{encodedQuestionId}
200
Question deleted successfully.
```

No body.

## Reorder

```text
POST /teacher/assessments/{encodedHomeworkId}/questions/reorder
200
Questions reordered successfully.
```

Body exact request.

Every success resource is parsed through the FE-001 strict full Homework DTO.

---

# 34. Question Mutation Unknown Outcome

Reuse/create:

```text
TeacherQuestionMutationOutcomeUnknownException
```

or a shared safe Homework mutation uncertainty type if FE-002 delivered one that can distinguish operation identity.

A mutation outcome is unknown for:

- ambiguous timeout/network failure;
- malformed/unexpected success body;
- unexpected status/envelope not documented as definite;
- local parse failure after a potentially successful mutation.

Never automatically replay:

```text
POST add
PATCH update
DELETE
POST reorder
```

All can produce duplicate/incorrect semantic changes if replayed blindly.

---

# 35. Definite Question Mutation Failures

Only exact recognized structured error envelopes are definite.

Common:

```text
401 authentication_required

403 forbidden
403 password_change_required
403 user_inactive
403 institution_inactive

404 resource_not_found

422 validation_failed

429 rate_limited
```

Question mutation documented 409 codes:

```text
topic_not_editable
task_closed
task_archived
business_conflict
result_pair_locked
assessment_has_no_scoreable_points
```

Not every code applies to every operation, but the data source may classify these exact Stage 6 Question mutation codes as definite when returned by the four Question endpoints.

Do not classify an unknown future 409 code as definite without a contract update.

Non-validation definite errors must have empty `errors`.

---

# 36. API Error Codes

Extend:

```text
ApiErrorCodes
```

only if missing:

```text
resultPairLocked = 'result_pair_locked'
assessmentHasNoScoreablePoints = 'assessment_has_no_scoreable_points'
```

Reuse FE-002 additions:

```text
taskClosed
taskArchived
```

and existing:

```text
businessConflict
topicNotEditable
validationFailed
resourceNotFound
```

Do not add unrelated Stage 7/8 codes.

---

# 37. Shared Question Mutation Activity

Create a narrow activity boundary scoped to one Homework route target, for example:

```text
TeacherQuestionMutationActivity
```

It prevents concurrent local Question mutations for the same current Homework.

While any Question mutation is active:

- Add disabled;
- Edit disabled;
- Delete disabled;
- Save Order disabled;
- metadata navigation may remain possible only if leaving does not hide an unresolved mutation outcome;
- editor submit cannot start a second operation.

Activity ownership includes:

```text
TeacherSessionKey
TeacherHomeworkRouteTarget
operation token/generation
```

Do not use a global app-wide mutation lock.

---

# 38. Question Editor Controller

Create autoDispose family:

```text
TeacherQuestionEditorController
TeacherQuestionEditorState
TeacherQuestionEditorTarget
```

Target contains:

```text
homework route target
mode = add | edit
questionId? for edit
```

For edit, initialize from the current authoritative FE-001 Homework detail Question.

If target Question no longer exists:

```text
unavailable
```

Do not issue a global Question read; no such endpoint exists.

---

# 39. Question Editor Local States

Use meaningful states such as:

```text
editing
localValidationFailure
submitting
serverValidationFailure
confirmedSuccess
outcomeReview
lockedReview
unavailable
```

Avoid an oversized enum if a simpler state shape suffices.

State owns:

```text
draft
field/section errors
form error
pending request
```

No raw transport JSON.

---

# 40. Question Editor Submit

## Add

Before request:

- session/desktop/route ownership current;
- no shared mutation activity;
- Homework confirmed draft/active;
- builder not serverLocked;
- current Question count < 100;
- local validation passes.

Build:

```text
position = current authoritative count + 1
```

Important:

If Homework detail changed after editor opened and count/Question IDs changed, rebase add position to the **latest authoritative Homework** at submit time.

Do not use stale open-time count.

## Edit

At submit:

- target Question must still exist in latest authoritative Homework;
- build request from latest initial authoritative Question snapshot and current draft;
- if request empty:
  `No changes to save.`;
- no position field.

---

# 41. Editor Confirmed Success

On exact success full Homework:

1. accept authoritative Homework into FE-001 detail controller;
2. invalidate Topic Homework list;
3. clear shared mutation activity;
4. publish success;
5. close editor/dialog;
6. show safe feedback on Builder:
   - `Question created successfully.`
   - or `Question updated successfully.`

Do not locally patch Question arrays.

Server response owns:

- ID;
- positions;
- total points;
- configuration readback;
- updatedAt.

---

# 42. Add Unknown Outcome Reconciliation

Add cannot always be proven from content because duplicate semantic Questions are allowed.

On unknown add:

1. perform one authoritative Homework GET;
2. if GET succeeds:
   - publish current Homework to detail controller;
   - close editor;
   - clear activity;
   - show Builder review notice:

```text
The Question creation result could not be confirmed.
Review the current Question list before adding another Question.
```

Do not infer success from prompt/config equality alone.

Do not retry automatically.

If GET fails:

- keep blocking outcome-review state;
- provide:
  `Check current Homework`;
- no second Question mutation allowed until an authoritative check succeeds or route/session is left.

---

# 43. Update Unknown Outcome Reconciliation

On unknown PATCH:

1. GET authoritative Homework;
2. locate target Question ID.

If target exists and:

```text
pendingRequest.matches(currentQuestion)
```

-> confirmed success.

If target exists but does not match:

- publish authoritative Homework;
- close editor;
- clear activity;
- show:

```text
The Question update result could not be confirmed.
Review the current Question before editing again.
```

If target no longer exists:

- do not claim success;
- publish authoritative Homework;
- show review notice that the Question is no longer available.

If GET fails:

- outcome-review with `Check current Homework`.

No replay.

---

# 44. Server Validation in Editor

For:

```text
422 validation_failed
```

keep editor open.

Map:

```text
type
prompt
instructions
points
checking_mode
configuration
configuration.*
```

Known nested configuration errors map to the relevant type-specific configuration section.

Do not attempt to perfectly duplicate arbitrary backend nested path text.

If local validation missed a backend constraint:

```text
Review the Question configuration.
```

and focus the configuration section.

Unknown server validation key -> form-level safe error.

Do not display raw backend messages as behavioral instructions.

---

# 45. Editor Lock / Lifecycle Conflicts

For definite:

```text
409 business_conflict
409 result_pair_locked
409 task_closed
409 task_archived
409 topic_not_editable
409 assessment_has_no_scoreable_points
```

do not retry mutation.

Perform one authoritative Homework GET when possible.

Mappings:

## `business_conflict`

```text
Question editing is locked by the current server state.
```

Builder `serverLocked = true`.

## `result_pair_locked`

Same safe locked message.

Builder `serverLocked = true`.

## `task_closed`

```text
This Homework is closed.
```

## `task_archived`

```text
This Homework is archived.
```

## `topic_not_editable`

```text
The Topic is no longer editable.
```

## `assessment_has_no_scoreable_points`

Used by update when an active Homework would become non-scoreable:

```text
An active Homework must keep at least one scoreable Question.
```

Do **not** set `serverLocked` for this code.

Keep editor current draft available so Teacher can increase points/change another Question.

---

# 46. Delete Flow

Delete is initiated from a current authoritative Question card.

Confirm:

```text
Delete Question N?
This removes the Question and its answer configuration.
```

Actions:

```text
Cancel
Delete
```

Do not show hard-delete implementation terminology.

Before DELETE:

- current session/target;
- Homework draft/active;
- no shared mutation active;
- no staged unsaved Question order;
- target Question still exists.

On confirmed success:

- accept full authoritative Homework;
- invalidate Topic Homework list;
- show `Question deleted successfully.`

---

# 47. Delete Unknown Reconciliation

On ambiguous DELETE:

1. GET authoritative Homework;
2. if target Question ID is absent:
   -> treat as confirmed success;
3. if target still exists:
   -> publish authoritative Homework;
   -> show:

```text
The delete result could not be confirmed.
Review the current Question list before trying again.
```

No automatic second DELETE.

If GET fails:

- blocking outcome review;
- `Check current Homework`.

---

# 48. Delete Definite Conflicts

Map documented codes as in Section 45.

For:

```text
assessment_has_no_scoreable_points
```

show:

```text
An active Homework must keep at least one scoreable Question.
Add or adjust another Question before deleting this one.
```

No local delete.

No local total manipulation.

---

# 49. Builder Local Reorder State

Question order editing is staged locally before one server mutation.

Builder keeps:

```text
authoritativeOrderIds
draftOrderIds
orderDirty
```

Initial:

```text
draftOrderIds = authoritative Question IDs ordered by position
orderDirty = false
```

UI controls per Question card:

```text
Move up
Move down
```

No drag package.

Keyboard-accessible buttons are the required mechanism.

Optional use of Flutter's built-in `ReorderableListView` is permitted only if:

- no new dependency;
- explicit Move up/down controls remain available for keyboard/accessibility;
- final behavior remains this contract.

---

# 50. Reorder Editing Rules

When `orderDirty = true`:

- Add disabled;
- Edit disabled;
- Delete disabled;
- Refresh that would silently overwrite draft order is not automatic;
- show:
  `Save order`
  `Reset order`.

Move buttons update only local `draftOrderIds`.

No network call per move.

This prevents interleaving local order assumptions with other Question mutations.

---

# 51. Reorder Stale Authoritative State

If the FE-001 Homework detail resource changes while local order is dirty:

Compare latest authoritative Question ID set/order to the base `authoritativeOrderIds`.

If the authoritative set or order changed externally:

- discard local draft order;
- reinitialize from server;
- show:

```text
The Question list changed on the server.
Review the current order before reordering again.
```

Do not submit stale IDs.

If only non-order Question content changed while the ID order remains the same, the local staged order may remain.

---

# 52. Save Reorder

Before mutation:

- draft order differs from authoritative order;
- exact same ID set;
- no duplicates;
- current Homework draft/active;
- no shared mutation active;
- not serverLocked.

Send:

```text
TeacherQuestionReorderRequest(questionIds: draftOrderIds)
```

On confirmed success:

- accept authoritative Homework;
- reset order state from returned Questions;
- invalidate Topic Homework list because `updated_at` changes on semantic reorder;
- show:
  `Questions reordered successfully.`

No local position patch after success.

---

# 53. Reorder Unknown Reconciliation

On ambiguous reorder:

1. GET authoritative Homework;
2. compare current Question ID order to pending requested order.

If exact match:

```text
confirmed success
```

If not:

- publish authoritative Homework;
- reset local order;
- show:

```text
The reorder result could not be confirmed.
Review the current Question order before trying again.
```

No replay.

If GET fails:

- blocking outcome review;
- `Check current Homework`.

---

# 54. Reorder Validation Failure

If backend returns:

```text
422 validation_failed
```

for `question_ids`:

- fetch/refresh authoritative Homework;
- reset local order;
- show:

```text
The Question list changed.
Review the current order and try again.
```

Do not try to surgically remove a rejected UUID based on backend message.

---

# 55. Builder Refresh

Explicit Refresh is available when:

- no mutation active;
- no unresolved mutation outcome;
- no unsaved local reorder.

If `orderDirty`, Refresh first asks:

```text
Discard unsaved Question order and refresh?
```

On confirm:

- discard local order;
- call FE-001 detail refresh.

Refresh does not mutate server state.

---

# 56. Builder Navigation / Unsaved State

Back to Homework:

- if no local order dirty and no blocking mutation outcome -> navigate normally;
- if order dirty -> discard-order confirmation;
- if mutation submitting/reconciling/outcome unknown -> block accidental navigation until the operation reaches a safe review state.

Editor dialog has its own dirty confirmation:

```text
Discard Question changes?
```

when local form differs from its initial draft/snapshot.

Closing editor without submit never changes server state.

Auth/session redirect must never be blocked by local dirty UI.

---

# 57. Question Editor UI Form Layout

Use one dialog or large modal surface suitable for desktop.

Recommended:

```text
AlertDialog / Dialog
width ~ 760–900
max height constrained with internal scroll
```

A separate nested route is **not** required.

Stable key:

```text
teacherQuestionEditorDialog
```

Sections:

1. Type
2. Prompt
3. Instructions
4. Points
5. Checking behavior
6. Type-specific answer configuration
7. Cancel / Save

For Add title:

```text
Add Question
```

For Edit:

```text
Edit Question
```

Do not create nine independent full screens.

Use focused type-specific configuration widgets.

---

# 58. Question Builder Screen UX

Screen key:

```text
teacherQuestionBuilderScreen
```

App bar:

```text
Question Builder
```

Show Homework context:

- Homework title;
- status;
- current server total points;
- current Question count.

Show Question list ordered by current draft/server order.

Controls:

```text
Add Question
Refresh
```

When order dirty:

```text
Save order
Reset order
```

Question card actions when editable:

```text
Edit
Delete
Move up
Move down
```

At max 100 Questions:

- Add disabled;
- explanatory text.

No lifecycle/designation controls.

---

# 59. Question Card Summary

Each card shows:

```text
Question N
type label
points
checking mode
prompt
optional instructions summary
```

Use FE-001 read-only configuration view or a compact derivative.

Do not duplicate the full answer-key renderer if it is already reusable.

For Builder cards, a collapsed configuration summary is acceptable, with Edit opening the full form.

Do not hide current correct-answer configuration from Teacher when edit controls are disabled; read-only review remains available.

---

# 60. Local Form Configuration Draft Types

Do not use raw nested `Map<String, dynamic>` as form authority.

Create typed local configuration drafts equivalent to:

```text
TeacherChoiceConfigurationDraft
TeacherTrueFalseConfigurationDraft
TeacherShortWrittenConfigurationDraft
TeacherEmptyConfigurationDraft
TeacherFileBasedConfigurationDraft
TeacherMatchingConfigurationDraft
TeacherOrderingConfigurationDraft
TeacherFillInBlankConfigurationDraft
```

Use type-specific row value objects.

Provide:

```text
fromQuestion(...)
validate(...)
toCanonicalConfigurationRequest(...)
semanticEquals(...)
```

through focused methods/helpers where appropriate.

Do not put HTTP transport into widgets.

---

# 61. Readback-to-Edit Conversion

When editing an existing Question:

- common fields copied from FE-001 authoritative Question;
- points formatted to a stable editable decimal string without scientific notation;
- choice option order preserved;
- short accepted answer order preserved;
- true/false preserved;
- file fixed values preserved;
- ordering correct order preserved;
- fill blanks/answers preserved.

## Matching

Discard server readback `clientKey` as mutation identity.

Create local pair rows from only:

```text
left
right
order
```

New request correlation keys are generated during serialization as `pair_N`.

This is mandatory.

---

# 62. Server-Authoritative Total Points

Builder displays:

```text
homework.totalPossiblePoints
```

from the latest full server Homework resource.

Do not recalculate and present a locally authoritative Homework total after add/edit/delete.

During a local editor draft, optional preview:

```text
Question points: X
```

is fine.

Do not optimistically adjust Homework total before server confirmation.

After confirmed mutation/reconciliation, display the returned authoritative total.

---

# 63. No Client Scoring Logic

Do not implement formulas for:

- Multiple Choice partial credit;
- Matching partial credit;
- Ordering partial credit;
- Fill Blank partial credit;
- Short Written answer normalization;
- official score.

Question Builder only authors answer configuration.

Any instructional text about checking must remain descriptive and not become execution logic.

---

# 64. Session / Target / Stale Async Safety

All async Question operations must be anchored to:

```text
TeacherSessionKey
TeacherHomeworkRouteTarget
operation generation
operation identity
```

Editor also includes:

```text
questionId / add mode
editor generation
```

A stale completion must not:

- close a newer editor;
- update another Homework;
- show feedback in another session;
- overwrite a newer authoritative Homework;
- reset a newer staged order;
- navigate from an obsolete route.

Do not rely only on Widget `mounted`.

---

# 65. Mutation Activity and Route Changes

If user changes route/session while a mutation is in flight:

- stale completion is ignored;
- no automatic navigation;
- no SnackBar on unrelated route;
- repository request may complete, but current UI must not assume outcome.

If the user later returns, normal GET reload is authoritative.

Do not create background retry/recovery jobs.

---

# 66. Error UX

Use stable code categories only.

## 404

Question/Homework no longer available:

- refresh/detail notFound;
- close editor if target gone;
- invalidate Topic Homework list;
- safe message.

## 422

Keep editor/reorder UI and map known fields.

## 409 locks/lifecycle

Refresh authoritative Homework and show contract-defined state.

## 429

```text
Too many requests. Wait before trying again.
```

## Transport/server/invalid response for GET reconciliation

Safe outcome-review state.

Never show:

- stack trace;
- raw exception;
- SQL;
- bearer token;
- raw backend URL;
- hidden UUID as error detail.

---

# 67. Accessibility

Required:

- dialog title announced;
- Type control labeled;
- Prompt/Instructions/Points labels;
- type-specific row inputs labeled with ordinal, e.g. `Option 1`;
- correct-answer radio/checkbox semantics;
- Add/Remove controls include row identity in tooltip/semantics;
- Move up/down buttons include Question/row ordinal;
- disabled first Move up and last Move down;
- errors visible and associated by section;
- first invalid common/config section receives focus where practical;
- progress state announced;
- correct answers not indicated by color only;
- delete confirmation focus safe;
- builder cards keyboard reachable where actionable;
- no horizontal overflow at supported desktop widths;
- editor scroll supports long content and text scaling.

No drag-only ordering.

---

# 68. Expected Files and Areas

Recommended domain:

```text
frontend/lib/features/teacher/domain/
  teacher_question_authoring.dart
  teacher_question_mutation.dart
```

or focused equivalent files.

Recommended application:

```text
teacher_question_builder_controller.dart
teacher_question_builder_state.dart
teacher_question_editor_controller.dart
teacher_question_editor_state.dart
teacher_question_mutation_activity.dart
```

Recommended presentation:

```text
teacher_question_builder_screen.dart
teacher_question_editor_dialog.dart
teacher_question_common_fields.dart
teacher_question_choice_fields.dart
teacher_question_short_written_fields.dart
teacher_question_matching_fields.dart
teacher_question_ordering_fields.dart
teacher_question_fill_blank_fields.dart
```

Do not mechanically create one file per tiny widget if a focused grouping is clearer.

Modify narrowly:

```text
frontend/lib/features/teacher/domain/teacher_homework_repository.dart
frontend/lib/features/teacher/data/teacher_homework_remote_data_source.dart
frontend/lib/features/teacher/data/teacher_homework_repository_impl.dart
frontend/lib/features/teacher/presentation/teacher_homework_detail_screen.dart
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
frontend/lib/core/network/api_error_codes.dart
frontend/test/features/teacher/teacher_test_support.dart
```

No backend/docs/package/platform changes.

---

# 69. Acceptance Criteria

- [ ] Desktop `/teacher/topics/{topic}/homework/{homework}/questions` route exists.
- [ ] Mobile Question Builder route redirects to Homework detail without transient authoring UI.
- [ ] Homework detail exposes Manage Questions only on desktop draft/active Homework.
- [ ] Builder uses FE-001 authoritative Homework detail state rather than a second cache.
- [ ] Draft and active Homework can enter Builder; closed/archived are review-only.
- [ ] server `business_conflict` / `result_pair_locked` disables further mutation in current Builder route and refreshes authoritative state.
- [ ] local limits exactly match Stage 6 contract.
- [ ] all nine Question types have typed local form configuration.
- [ ] type change resets type-specific configuration only after required confirmation when meaningful data would be lost.
- [ ] Single Choice requires 2–20 options and exactly one correct.
- [ ] Multiple Choice requires 2–20 options and at least one correct.
- [ ] True/False persists one Boolean correct value.
- [ ] Short Written supports automatic accepted answers or manual empty config.
- [ ] Open Written is manual with no answer key.
- [ ] File Based is fixed PDF/DOCX/PPT/PPTX manual config with no editable file limit.
- [ ] Matching authors semantic pairs and sends deterministic request-only `pair_N` client keys.
- [ ] Matching never uses server readback key as mutation authority.
- [ ] Ordering UI list order serializes exact `correct_position`.
- [ ] Fill Blank enforces key grammar, uniqueness, accepted answers, and exact `{{key}}` prompt correspondence.
- [ ] Points input rejects invalid precision/format and permits zero.
- [ ] New Questions append at authoritative `N+1`; no insertion-position UI exists.
- [ ] Edit PATCH never sends `position`.
- [ ] Edit request sends only semantic changes; type/mode change includes full configuration.
- [ ] no-op Edit sends no PATCH.
- [ ] Delete uses explicit confirmation.
- [ ] local Question reordering is staged and saved once through exact full ID list.
- [ ] while order is dirty, add/edit/delete are disabled until Save/Reset.
- [ ] stale authoritative list change discards stale local order instead of submitting it.
- [ ] confirmed add/update/delete/reorder always accepts full server Homework resource.
- [ ] server authoritative `total_possible_points` is displayed; Flutter does not compute aggregate authority.
- [ ] unknown add is never inferred from duplicate-able content and never replayed.
- [ ] unknown update/delete/reorder reconcile through authoritative GET using safe operation-specific rules.
- [ ] validation errors keep the relevant editor/order UI recoverable.
- [ ] `assessment_has_no_scoreable_points` is handled without locally deleting/updating state.
- [ ] stale route/session/editor/mutation completions cannot affect a newer target.
- [ ] no lifecycle/official/Student/scoring/Blitz/mobile authoring/backend/package work enters scope.
- [ ] focused tests pass.
- [ ] focused analyze passes.
- [ ] format check passes.
- [ ] `git diff --check` passes.
- [ ] focused diff review finds no blocking API/state/accessibility/scope issue.

---

# 70. Focused Tests and Verification

Run from:

```text
frontend/
```

Use FVM.

Do not run full frontend suite/build/E2E. Those belong to Frontend Phase 2/Integration.

## 70.1 Authoring domain / serialization

```bash
fvm flutter test \
  test/features/teacher/teacher_question_authoring_test.dart \
  test/features/teacher/teacher_question_mutation_test.dart
```

Cover:

### Common

- prompt trim/limits;
- instructions null/verbatim/blank invalid;
- valid/invalid points;
- zero points;
- max precision;
- no scientific/comma format;
- type fixed checking modes.

### Single Choice

- min/max options;
- exactly one correct;
- ordered positions;
- blank/long text.

### Multiple Choice

- zero correct invalid;
- one/many/all correct valid.

### True/False

- exact Boolean configuration.

### Short Written

- auto accepted answers;
- duplicate invalid;
- max count;
- manual `{}`;
- auto/manual transition reset behavior.

### Open/File

- empty manual config;
- exact file extension set.

### Matching

- pair limits;
- text rules;
- generated `pair_1...`;
- semantic equality ignores readback/request keys.

### Ordering

- min/max;
- UI order -> exact positions.

### Fill Blank

- key regex;
- unique keys;
- accepted-answer rules;
- missing placeholder;
- extra placeholder;
- duplicate placeholder;
- valid exact mapping.

### Edit request

- each common field;
- config only;
- type change includes config;
- mode change includes config;
- no position;
- no-op;
- `matches(current)`.

### Reorder

- exact `question_ids` body;
- duplicate invalid locally.

## 70.2 Remote data source

Extend/create focused data test:

```bash
fvm flutter test test/features/teacher/teacher_homework_data_test.dart
```

Cover:

- exact add path/body/status/message;
- exact PATCH path/body/status/message;
- DELETE no body/status/message;
- reorder path/body/status/message;
- strict full Homework success parsing;
- documented definite 409s;
- 422;
- 404;
- malformed success -> unknown;
- ambiguous Dio failure -> unknown;
- no automatic retry.

## 70.3 Editor controller

```bash
fvm flutter test test/features/teacher/teacher_question_editor_controller_test.dart
```

Cover:

- add initialization;
- edit initialization all nine types parameterized where practical;
- type change confirmation/reset;
- Short Written mode change confirmation/reset;
- local validation;
- max count;
- add uses latest N+1;
- edit target vanished;
- no-op edit;
- confirmed add/update;
- 422 mapping;
- business_conflict/result_pair_locked lock;
- scoreable-points conflict;
- task closed/archived/topic conflict;
- unknown add + GET review;
- unknown update + GET match success;
- unknown update + GET mismatch review;
- GET failure -> Check current;
- session/route stale completion ignored.

## 70.4 Builder / delete / reorder controller

```bash
fvm flutter test test/features/teacher/teacher_question_builder_controller_test.dart
```

Cover:

- draft editable;
- active editable initially;
- closed/archived review-only;
- serverLocked;
- delete success;
- delete unknown absent -> success;
- delete unknown present -> review;
- delete scoreable conflict;
- local move up/down;
- order dirty;
- reset;
- save;
- confirmed reorder;
- unknown reorder exact match -> success;
- unknown mismatch -> review;
- authoritative Question set changes while dirty -> local order reset;
- no simultaneous mutation;
- stale target/session ignored.

## 70.5 Widgets / route

```bash
fvm flutter test \
  test/features/teacher/teacher_question_builder_screen_test.dart \
  test/features/teacher/teacher_question_editor_test.dart \
  test/features/teacher/teacher_homework_routing_screen_test.dart \
  test/features/teacher/teacher_homework_detail_screen_test.dart
```

Cover:

- desktop direct builder;
- mobile builder redirect;
- invalid path/query/fragment;
- Manage Questions visibility;
- no Manage on mobile/closed/archived;
- Builder context/total/count;
- Add max disabled;
- Question cards;
- move buttons;
- order Save/Reset;
- delete confirmation;
- locked banner;
- all nine editor configurations render;
- field labels/errors;
- type-change confirmation;
- dirty editor discard;
- long content scroll/no overflow;
- keyboard-accessible move controls;
- no lifecycle/official controls.

## 70.6 Direct FE-002 regression

Because Homework detail/router/repository mutate:

```bash
fvm flutter test \
  test/features/teacher/teacher_homework_edit_controller_test.dart \
  test/features/teacher/teacher_homework_edit_screen_test.dart
```

If exact delivered filenames differ, run their focused equivalents.

No full Teacher suite.

## 70.7 Focused analyze

```bash
fvm flutter analyze --no-pub lib/features/teacher
fvm flutter analyze --no-pub lib/app/router
```

## 70.8 Format

```bash
fvm dart format --output=none --set-exit-if-changed \
  lib/features/teacher \
  lib/app/router/app_route_paths.dart \
  lib/app/router/app_router.dart \
  lib/core/network/api_error_codes.dart \
  test/features/teacher
```

## 70.9 Always

```bash
git diff --check
```

Then focused diff self-review:

- typed form/domain config, no raw nested JSON in UI;
- no Question scoring logic;
- no local authoritative total calculation;
- no server Matching key mutation authority;
- no automatic mutation replay;
- no drag-only accessibility;
- no second Homework cache/repository;
- no mobile authoring;
- no lifecycle/designation scope creep;
- no package/platform/backend/docs changes;
- no test weakening;
- no stale async navigation/feedback;
- no debug/secrets/temp/generated junk;
- no unrelated formatting churn.

---

# 71. Project Owner Manual Check

```text
Not required at task level.
```

Real-stack all-nine Question authoring belongs to `S06-INT-001`.

---

# 72. Delivery

Follow root `AGENTS.md` and `tasks/README.md`.

Delivery execution:

```text
Project Owner
```

Suggested:

```text
Branch: feat/s06-fe-003-question-builder
Commit: feat(stage6): add nine-type question builder
PR base: main
```

Codex must not:

- commit;
- push;
- open/merge PR;
- modify this task file;
- update task/Stage bookkeeping.

Codex stops after implementation, focused verification, `git diff --check`, and focused scope/diff self-review.

Task acceptance occurs only after approved delivery is present on `origin/main`, local `main == origin/main`, ahead/behind `0/0`, and worktree clean.

---

# 73. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to rediscover requirements.

| Source/reference | Decision already encoded above |
|---|---|
| Approved Stage 6 decomposition | FE-003 owns the nine-type Question Builder |
| S06-BE-002 | typed Question types/configuration/authoring limits |
| S06-BE-004 | add/update/delete/reorder endpoints, activity lock, point recalculation, full Homework responses |
| S06-FE-001 | typed Question read domain + Homework detail route/state |
| S06-FE-002 | desktop authoring route/mutation uncertainty/dirty form conventions |
| Current Teacher frontend architecture | feature-first Riverpod + configured Dio + strict DTO + session ownership |
| Approved UI decision | add appends at N+1; global Question order changed through separate staged Save Order |
| Approved Matching client rule | generate request-only `pair_N`; never use server readback key as mutation authority |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |

---

# 74. Codex Final Report

Return:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

`DELIVERY BLOCKED` is not applicable because delivery is Project Owner-owned.

Report:

1. **Status**.
2. **Implementation** — concise result.
3. **Changed files** — file → purpose.
4. **Acceptance criteria** — concise PASS/FAIL evidence.
5. **Focused verification** — exact commands/results.
6. **Nine-type validation/serialization** — evidence.
7. **Mutation uncertainty/reconciliation** — evidence.
8. **Editing lock/scoreable-points handling** — evidence.
9. **Reorder/stale-state handling** — evidence.
10. **Session/target safety** — evidence.
11. **Accessibility/mobile boundary** — evidence.
12. **Scope/diff** — non-goals + `git diff --check`.
13. **Delivery handoff** — Project Owner + current Git state.
14. **Deviations/blockers** — exact facts.

Do not output task `Accepted`.

Do not repeat this contract or paste large successful logs.

If final backend/FE dependencies materially conflict with this contract or a required Question/API/security/state decision is unresolved, return `BLOCKED` rather than deciding independently.
