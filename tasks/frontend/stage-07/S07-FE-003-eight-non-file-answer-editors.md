# Codex Implementation Contract: S07-FE-003 — Eight Non-File Answer Editors

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S07-FE-003` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter typed drafts + explicit save/replace/clear UX for eight non-file Student Homework Question types` |
| Depends on | `S07-FE-002 = Accepted / Delivered`; Stage 7 Backend Phase 2 remains `PASS` |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Current review baseline | `origin/main @ 8277667c75beeb0d9e49cf2f0374e1ca2711ebc6` |
| Implementation baseline | ChatGPT re-checks/freezes current `origin/main` immediately before Codex starts |
| Readiness Gate | `PASS — corrected/revalidated`; execution remains blocked until `S07-BE-PHASE-2 = PASS` and `S07-FE-002 = Accepted / Delivered` |
| Supported surfaces | `Student desktop + mobile` |
| Verification | focused frontend tests + format/analyze + diff check |
| Delivery | Project Owner |
| Frontend block checkpoint | Stage 7 Frontend Phase 2 after `S07-FE-001…005` |

Do not create a duplicate `CODEX-PROMPT`.

---

# 2. Context Boundary

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. delivered `S07-FE-001` and `S07-FE-002` Student Homework/Attempt source and focused tests;
5. current configured Dio/failure infrastructure;
6. current Student Session/stale-completion patterns;
7. current Teacher Question editor presentation only for directly useful Flutter control/layout patterns;
8. exact backend answer mutation contract reproduced below.

Do not read product docs, roadmap, architecture/database/API docs, previous task files, Stage history, closure reviews, or unrelated modules to determine behavior.

This contract resolves:

- all eight non-file editor UXs;
- typed local draft/state;
- exact PUT payloads;
- local validation;
- semantic dirty/no-op behavior;
- clear behavior;
- explicit save semantics;
- uncertain PUT result + authoritative GET reconciliation;
- lifecycle/error reconciliation;
- parent Attempt synchronization;
- navigation protection for unsaved/uncertain work;
- accessibility/responsiveness;
- tests and verification.

If delivered backend or FE-002 materially conflicts with this contract, return `BLOCKED` with exact evidence. Do not redesign.

---

# 3. Goal

Turn the FE-002 read-only Attempt shell into an editable Student Homework Attempt for exactly these eight Question types:

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

Each Question owns a controlled typed draft.

The Student explicitly saves one Question at a time through:

```text
PUT /api/v1/student/attempts/{attempt}/answers/{question}
```

The server response becomes the new confirmed answer state.

`file_based` remains read-only until `S07-FE-004`.

Final Homework Submit remains absent until `S07-FE-005`.

---

# 4. Explicit Non-Goals

Do not implement:

- file picker;
- file upload/replace;
- file download/open;
- final Submit;
- Submit confirmation;
- Start changes;
- idempotency key for answer PUT;
- autosave;
- background synchronization;
- offline queue;
- score/checking/review UI;
- correctness feedback;
- local scoring;
- answer-key inference;
- deadline countdown;
- client-authoritative lifecycle;
- new package/dependency;
- new router/client/state framework;
- backend/platform changes.

---

# 5. Backend Save Endpoint

Endpoint:

```text
PUT /api/v1/student/attempts/{attempt}/answers/{question}
```

For FE-003:

```text
Content-Type: application/json
no query parameters
no Idempotency-Key
```

Success:

```text
200 OK
```

Exact envelope:

```json
{
  "data": {
    "question_id": "question-uuid",
    "type": "multiple_choice",
    "answer": {
      "selected_option_ids": [
        "option-uuid"
      ]
    },
    "updated_at": "2026-09-08T12:10:00Z"
  }
}
```

For a successful clear:

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

No extra success keys.

---

# 6. Backend Answer Error Surface

Relevant stable codes:

```text
404 resource_not_found

409 task_not_active
409 task_closed
409 task_archived
409 deadline_passed
409 attempt_not_editable
409 business_conflict

422 validation_failed
422 selection_limit_exceeded
```

Session/auth errors remain handled through existing infrastructure.

Do not branch on human-readable messages.

---

# 7. Editor Strategy

FE-003 uses:

```text
explicit per-Question Save
```

not autosave.

Rationale:

- Student controls when a draft becomes server state;
- fewer network calls;
- easier uncertain-outcome handling;
- easier mobile UX;
- clear dirty/saved state;
- no debounce/timer lifecycle.

A Question may be edited locally without transport until:

```text
Save answer
```

is pressed.

---

# 8. Attempt-Level Editing Controller

Create one cohesive controller keyed by the current Attempt route target:

```text
frontend/lib/features/student/application/student_attempt_answer_editor_state.dart
frontend/lib/features/student/application/student_attempt_answer_editor_controller.dart
```

Family key:

```text
StudentHomeworkAttemptRouteTarget
```

This controller owns only:

- non-file Question drafts;
- confirmed server answer bases;
- local validation;
- one active answer mutation;
- uncertain mutation snapshot + authoritative GET reconciliation ownership;
- dirty state;
- discard/reset state.

It does not own:

- Attempt loading;
- Homework loading;
- routing;
- final Submit;
- file answers;
- score/checking.

Do not create a God controller.

---

# 9. Typed Draft Domain

Create:

```text
frontend/lib/features/student/domain/student_answer_draft.dart
frontend/lib/features/student/domain/student_answer_mutation.dart
```

No raw `Map<String, dynamic>` in application state.

Draft variants:

```text
StudentSingleChoiceDraft
StudentMultipleChoiceDraft
StudentTrueFalseDraft
StudentShortWrittenDraft
StudentOpenWrittenDraft
StudentMatchingDraft
StudentOrderingDraft
StudentFillBlankDraft
```

Mutation variants:

```text
StudentSingleChoiceMutation
StudentMultipleChoiceMutation
StudentTrueFalseMutation
StudentShortWrittenMutation
StudentOpenWrittenMutation
StudentMatchingMutation
StudentOrderingMutation
StudentFillBlankMutation
```

Each mutation is immutable and serializes to exactly one backend payload.

---

# 10. Draft Initialization

When an editable Attempt is first confirmed, initialize each non-file Question draft from the FE-002 saved answer state.

If no saved answer exists:

## Single

```text
selectedOptionId = null
```

## Multiple

```text
selectedOptionIds = empty
```

## True/False

```text
value = null
```

## Short/Open

```text
text = ''
```

## Matching

```text
leftToRight = empty
```

## Ordering

```text
itemToPosition = empty
```

## Fill

```text
blankTextById = all Question blanks -> ''
```

No fabricated server answer is created.

---

# 11. Confirmed Server Base vs Local Draft

For every non-file Question state retain:

```text
serverAnswer?
draft
validation
isDirty
saveStatus
failure?
```

The `serverAnswer` is the latest confirmed server representation known to this editor controller.

The `draft` is current Student local input.

Dirty state is semantic:

```text
canonical draft answer != canonical confirmed server answer
```

not merely:

```text
a Widget received onChanged
```

---

# 12. Semantic No-Op

Do not send PUT when the canonical draft equals server state.

Examples:

```text
same selected option
same multiple-choice set in different tap order
same boolean
same exact written text
same matching map in different row iteration order
same ordering item->position mapping
same fill blank values in different map iteration order
```

For clearable types:

```text
empty canonical draft + no server answer
```

is not dirty and sends no request.

Save button is disabled when there is no semantic mutation.

---

# 13. Single Choice Editor

Question UI supplies safe options:

```text
id
text
```

Editor:

```text
Radio / radio-style selection
```

Draft:

```text
selectedOptionId?
```

Local save validity:

```text
selectedOptionId != null
selected option belongs to Question
```

Payload:

```json
{
  "type": "single_choice",
  "selected_option_ids": [
    "option-uuid"
  ]
}
```

Exactly one.

No clear behavior.

Do not offer:

```text
Clear answer
```

for Single Choice.

Student may replace one selection with another and Save.

---

# 14. Multiple Choice Editor

Render checkboxes.

Display:

```text
Select up to N.
Selected: X / N
```

where:

```text
N = backend answer_ui.max_selections
```

Draft:

```text
Set<String> selectedOptionIds
```

Local rules:

```text
0 <= count <= maxSelections
all IDs belong to Question
```

When max is reached:

- selected options remain enabled for deselection;
- unchecked options are disabled until capacity is freed.

Do not silently drop a Student selection.

Payload canonical order:

```text
Question option display order
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

Empty set is valid and means server clear.

Provide local:

```text
Clear answer
```

which clears the draft only.

Student still presses:

```text
Save answer
```

to persist clear.

---

# 15. True / False Editor

Render accessible radio/segmented controls:

```text
True
False
```

Draft:

```text
bool?
```

Save valid only when non-null.

Payload:

```json
{
  "type": "true_false",
  "value": true
}
```

No clear behavior.

Do not coerce strings/numbers.

---

# 16. Short Written Editor

Draft:

```text
String text
```

Maximum:

```text
1000 Unicode scalar values
```

Local length check uses:

```dart
text.runes.length
```

Do not truncate automatically.

Do not trim/normalize/case-fold the Student text.

Payload:

```json
{
  "type": "short_written",
  "text": "exact draft text"
}
```

Semantic clear:

```text
text.trim().isEmpty
```

Canonical answer becomes:

```text
null
```

Therefore:

- absent server answer + whitespace-only draft = no-op;
- existing server answer + whitespace-only draft = dirty clear.

Provide:

```text
Clear answer
```

which sets local draft text to `''`.

---

# 17. Open Written Editor

Draft:

```text
String text
```

Maximum:

```text
20000 Unicode scalar values
```

Use:

```dart
text.runes.length
```

Do not truncate.

Preserve exact text.

Payload:

```json
{
  "type": "open_written",
  "text": "exact draft text"
}
```

Whitespace-only has the same clear semantics as Short Written.

Render a larger multiline field.

Provide:

```text
Clear answer
```

as local draft action.

---

# 18. Matching Editor

Safe Question UI exposes:

```text
leftItems
rightItems
```

Do not pair them by index.

Draft:

```text
Map<String, String> leftToRight
```

where:

```text
left item ID -> right item ID
```

Partial matching is valid.

UI:

- one row/card per left item;
- display left text;
- accessible dropdown/menu for right item;
- include:
  ```text
  Not matched
  ```
- a right item already assigned to another left item is not selectable in another row;
- the current row's assigned value remains selectable.

Do not silently reassign a right item from another row.

Student must explicitly unmatch first if necessary.

Payload canonical order:

```text
Question leftItems display order
```

Body:

```json
{
  "type": "matching",
  "pairs": [
    {
      "left_item_id": "left-uuid",
      "right_item_id": "right-uuid"
    }
  ]
}
```

Empty mapping means server clear.

Provide:

```text
Clear answer
```

which empties local mapping.

---

# 19. Ordering Editor

Safe Question UI exposes unordered display items:

```text
id
text
```

Backend supports partial submitted positions.

FE-003 must preserve that capability.

Draft:

```text
Map<String, int> itemToPosition
```

Partial mapping valid.

UI:

- one row/card per item;
- item text;
- position dropdown:
  ```text
  Unassigned
  1
  2
  ...
  N
  ```
- positions assigned to another item are disabled in the current row;
- current selected position remains selectable.

Do not silently swap two items.

Student explicitly clears/reassigns.

Local rules:

```text
item IDs unique
positions unique
1 <= position <= total Question item count
```

Payload canonical order:

```text
submitted position ASC
then item ID
```

Body:

```json
{
  "type": "ordering",
  "items": [
    {
      "item_id": "uuid",
      "position": 1
    }
  ]
}
```

Empty mapping means clear.

Provide:

```text
Clear answer
```

which marks all items Unassigned locally.

Do not display or infer correct positions.

---

# 20. Fill-in-the-Blank Editor

Safe UI exposes:

```text
blank.id
blank.key
blank.position
```

Draft:

```text
Map<String, String> blankTextById
```

Initialize every safe blank with `''` when not saved.

Render blanks in:

```text
blank.position ASC
```

Each field label:

```text
Blank: <key>
```

or equivalent accessible label.

Maximum per included answer:

```text
1000 Unicode scalar values
```

using:

```dart
text.runes.length
```

A field whose:

```text
text.trim().isEmpty
```

is omitted from the payload.

Do not trim non-empty text before sending.

Payload canonical order:

```text
blank.position ASC
```

Body:

```json
{
  "type": "fill_in_blank",
  "values": [
    {
      "blank_id": "uuid",
      "text": "exact Student text"
    }
  ]
}
```

Partial values are valid.

If all fields are semantically empty:

```text
values = []
```

which clears server answer.

Provide:

```text
Clear answer
```

which clears all local blank fields.

---

# 21. File-Based Question in FE-003

`file_based` remains non-editable in this task.

Keep FE-002 read-only file state.

Display a neutral action boundary such as:

```text
File answer
```

and existing saved file metadata if present.

Do not add:

- file picker;
- upload;
- replace;
- download/open.

FE-004 will extend this exact Question surface.

---

# 22. Canonical Mutation Serialization

Every mutation must produce deterministic JSON.

## Single

One selected ID.

## Multiple

Selected IDs in Question option display order.

## Matching

Pairs in Question left-item display order.

## Ordering

Entries sorted by:

```text
position ASC
itemId ASC
```

## Fill

Values in blank-position order.

This ensures:

- deterministic tests;
- stable pending-mutation comparison during uncertain reconciliation;
- no accidental semantic differences due Dart map/set iteration.

Do not include null/extra fields.

---

# 23. Answer Mutation Response DTO

Create:

```text
frontend/lib/features/student/data/dto/student_attempt_answer_mutation_dto.dart
```

Exact envelope:

```text
data
```

Data exact keys:

```text
question_id
type
answer
updated_at
```

Require:

```text
question_id = requested Question ID
type = requested Question type
type = current safe StudentQuestion.type
```

The mutation-response parser must receive the current validated safe
`StudentQuestion` as request context, not only the two route/type strings.

When `answer != null`, reuse the delivered FE-002 saved-answer typed parser and
apply the same cross-collection constraints against that safe Question:

```text
single/multiple choice IDs belong to Question options
multiple choice count <= Question.maxSelections
matching left/right IDs belong to the corresponding safe side sets
ordering item IDs belong to Question items
ordering 1 <= position <= Question.items.length
fill blank IDs belong to Question blanks
written/fill persisted text is semantically non-empty when present
```

Do not duplicate parsing logic.

Any response target/type/child-integrity mismatch is:

```text
ApiFailureKind.invalidResponse
```

and is **not** a confirmed save.

---

# 24. Mutation Response Nullability

For:

```text
multiple_choice
short_written
open_written
matching
ordering
fill_in_blank
```

allow:

```text
answer = null
updated_at = null
```

for successful clear.

For:

```text
single_choice
true_false
```

a successful `answer = null` is an invalid response.

Require the exact nullability pair:

```text
answer = null     <=> updated_at = null
answer != null    <=> updated_at != null
```

Any non-null `updated_at` must use the corrected FE-001/002 Stage 7 Homework
timestamp parser exactly:

```text
YYYY-MM-DDTHH:MM:SSZ
```

Do not fall back to the older permissive Student Topic timestamp syntax.

No:

```text
checking_status
score
feedback
```

accepted.

---

# 25. Data Source Extension

Modify delivered:

```text
StudentHomeworkAttemptRemoteDataSource
```

Add:

```text
Future<StudentAttemptAnswerMutationDto> saveAnswer(
  String attemptId,
  StudentQuestion question,
  StudentAnswerMutation mutation,
)
```

HTTP exactly:

```dart
dio.put<Object?>(
  '/student/attempts/${Uri.encodeComponent(attemptId)}/answers/'
  '${Uri.encodeComponent(question.id)}',
  data: mutation.toJson(),
  options: Options(followRedirects: false),
)
```

No query.

No `Idempotency-Key`.

Require:

```text
200
```

Map malformed success to:

```text
ApiFailureKind.invalidResponse
```

No automatic retry.

---

# 26. Repository Extension

Modify delivered:

```text
StudentHomeworkAttemptRepository
StudentHomeworkAttemptRepositoryImpl
```

Add:

```text
Future<StudentAttemptAnswerMutationResult> saveAnswer(
  String attemptId,
  StudentQuestion question,
  StudentAnswerMutation mutation,
)
```

Result contains:

```text
questionId
type
answer?
updatedAt?
```

No raw JSON.

No score/checking fields.

---

# 27. Answer Save Status

Per Question editor state uses:

```text
StudentAnswerSaveStatus:
  idle
  saving
  uncertain
  failure
  saved
```

Meaning:

## idle

No active result message.

May be dirty or clean.

## saving

One PUT is in flight.

## uncertain

PUT may have committed but client cannot prove outcome.

## failure

Confirmed deterministic failure.

## saved

Latest mutation has a confirmed 200 result.

Any new local edit after `saved` returns status to:

```text
idle
```

while dirty state becomes true.

No timer is required to clear `saved`.

---

# 28. One Active Answer Mutation / Reconciliation per Attempt

FE-003 permits at most one operation that can change or reconcile authoritative
answer state per Attempt at a time:

```text
one active PUT save
OR
one active uncertain-outcome GET reconciliation
```

Reason:

- backend serializes answer writes through the Attempt row;
- one explicit uncertainty owner avoids ambiguous server-base rebasing;
- clearer Student feedback;
- no functional need for concurrent per-question mutations.

While one Question is:

```text
saving
or
uncertain/reconciling
```

other Questions may retain/edit local drafts, but all Save buttons are disabled.

Do not discard those drafts.

There is **no blind PUT retry operation** in FE-003.

---

# 29. Save Preconditions

A Question Save is enabled only when all are true:

```text
FE-002 Attempt controller status = data
Attempt data is confirmed current/non-stale for this target
Attempt.status = in_progress
Question type is one of FE-003 eight
draft locally valid
draft is semantically dirty
no active save/uncertain reconciliation operation for this Attempt
current Student session/route target is eligible/current
```

Do not send a PUT while the parent Attempt view is:

```text
initial
loading
refreshing
stale/retained-only
error
notFound
```

Local drafts may remain visible/editable where the delivered FE-002 retained
presentation permits it, but Save is disabled until a new confirmed-current
`data` Attempt establishes editability again.

For Single/True:

```text
no selection => Save disabled
```

For clearable types:

```text
canonical null is valid
```

if it differs from current server answer.

---

# 30. Local Validation

Local validation improves UX only.

Backend remains authoritative.

Do not send when local contract is invalid.

Required local errors:

## Multiple

```text
selected count > maxSelections
```

## Short

```text
>1000 Unicode scalars
```

## Open

```text
>20000 Unicode scalars
```

## Matching

Normally UI prevents duplicate right selection, but controller validates uniqueness before send.

## Ordering

Controller validates:

```text
unique submitted positions
range 1..N
```

## Fill

Each semantically non-empty text:

```text
<=1000 Unicode scalars
```

Do not validate correctness.

---

# 31. Confirmed Save Success

A transport `200` is confirmed success only after the mutation response passes
all strict DTO + current-safe-Question validation from Sections 23–24.

On a valid confirmed mutation result:

1. verify response target/type/current Question + child IDs/ranges;
2. set `serverAnswer` to returned answer/null;
3. reset current draft from the confirmed returned server state;
4. set:
   ```text
   isDirty = false
   saveStatus = saved
   ```
5. clear active mutation snapshot;
6. request a non-blocking FE-002 Attempt refresh for whole-resource reconciliation.

If the HTTP request returned `200` but the success payload is malformed,
mismatched or violates current safe Question constraints:

```text
ApiFailureKind.invalidResponse
=> uncertain
=> retain the exact sent pendingMutationSnapshot
=> do not rebase draft/serverAnswer
=> do not claim Saved
=> require authoritative GET Attempt reconciliation
```

Do not optimistically infer server result from sent payload when the response supplies an authoritative state.

If clear success returns null:

- canonical local draft becomes the empty form for that type.

---

# 32. Parent Attempt Reconciliation

After a confirmed save:

```text
studentHomeworkAttemptControllerProvider(target).refresh()
```

or equivalent delivered reconciliation method.

Do not invalidate the route or navigate.

If that refresh fails:

- keep the mutation response as confirmed local server answer;
- show no false rollback;
- normal Attempt refresh UI may indicate stale/error independently.

Do not patch Homework attempt counts; answer save does not change them.

---

# 33. Parent Attempt State Synchronization

When the FE-002 Attempt controller publishes a newer **confirmed** Attempt,
distinguish ordinary parent refresh from the editor's explicit uncertainty
reconciliation operation.

## If Attempt is terminal

Terminal confirmed server state always wins.

Immediately:

- invalidate the editor mutation/reconciliation generation;
- stop editing;
- clear the active save ownership;
- clear any pending uncertain snapshot/reconciliation state;
- clear dirty drafts that can no longer be written;
- rebuild editor bases from terminal server answers;
- show terminal/read-only shell.

Any late completion from a PUT or reconciliation GET that belonged to the prior
editable generation must be ignored and must not publish `saved`, failure,
feedback, or re-enable editing.

## If Attempt remains `in_progress` and no Question is uncertain

For each Question:

### Clean local draft

Synchronize base + draft to latest server answer.

### Dirty local draft

Update the known server base but preserve local draft.

Then recompute:

```text
isDirty
```

This allows a Student's unsaved local work to survive a normal parent refresh.

## If one Question is uncertain

An **ordinary** parent refresh must not silently resolve that uncertainty.

For the uncertain Question:

- keep `pendingMutationSnapshot`;
- keep `saveStatus = uncertain` (or explicit reconciling substate);
- do not compare ordinary refresh data to the pending snapshot as proof;
- do not rebase the uncertain draft/serverAnswer from that ordinary refresh.

Other non-uncertain Questions may synchronize normally.

Only the completion of the explicitly owned uncertainty-reconciliation GET from
Section 37 may compare server state with the pending snapshot and resolve the
uncertainty.

Do not silently overwrite dirty local input.

---

# 34. Uncertain PUT Outcome

A PUT result is uncertain for:

```text
ApiFailureKind.connection
ApiFailureKind.timeout
ApiFailureKind.cancelled
ApiFailureKind.invalidResponse
ApiFailureKind.unknown
```

and structured/server failures when:

```text
statusCode == null
or
statusCode >= 500
```

Because PUT may have committed before the response was lost.

Store the exact canonical:

```text
pendingMutationSnapshot
```

used by the request.

State:

```text
uncertain
```

Do not claim:

```text
Saved
Failed
```

---

# 35. Uncertain Editor UX

For the affected Question:

- disable its input controls;
- show:
  ```text
  We could not confirm whether this answer was saved.
  ```
- show exactly one recovery action:
  ```text
  Reload attempt
  ```

Do **not** show a blind `Reload attempt` action.

While uncertainty exists:

- all Question Save buttons are disabled;
- other local drafts remain intact/editable;
- no new answer mutation starts;
- only the owned authoritative GET reconciliation may resolve uncertainty.

---

# 36. No Blind PUT Retry After Uncertain Outcome

FE-003 ordinary answer PUT has:

```text
no Idempotency-Key
no ETag/version precondition
no compare-and-swap token
```

Therefore a repeated PUT after an uncertain response is **not** automatically
safe: another device/request for the same Student may have saved a newer answer
between the lost response and the retry.

Forbidden recovery:

```text
uncertain
-> resend pendingMutationSnapshot automatically/on Retry
```

because it could overwrite a newer intervening server answer.

The exact `pendingMutationSnapshot` is retained only for:

- comparison against an authoritative GET Attempt result;
- restoring the Student's intended value as a local dirty draft when the server
  differs and the Attempt remains editable.

After reconciliation shows a differing server answer, a later Student-initiated
`Save answer` is a **new explicit mutation decision** built from the current
dirty draft/current safe Question/current confirmed Attempt state.

Do not add an idempotency header to ordinary answer PUT in FE-003.

---

# 37. Authoritative Uncertain-Outcome Reconciliation

`Reload attempt` starts one explicit editor-owned reconciliation operation using
the FE-002 authoritative GET Attempt boundary.

The editor records a reconciliation generation/token bound to:

```text
StudentSessionKey
StudentHomeworkAttemptRouteTarget
questionId
pendingMutationSnapshot
```

Only that owned GET completion may resolve the uncertainty.

While reconciliation is in flight:

- no PUT may start;
- the uncertain Question remains input-disabled;
- other local drafts remain intact;
- duplicate Reload taps are suppressed.

After the owned confirmed GET completion:

## Server answer semantically equals pending mutation result

Treat the earlier PUT as proven saved:

```text
saveStatus = saved
serverAnswer = refreshed answer
draft = refreshed answer
isDirty = false
clear pending snapshot
clear reconciliation ownership
```

## Server answer differs and Attempt remains `in_progress`

Do **not** overwrite the newer/different server answer automatically.

Instead:

- clear uncertainty/reconciliation ownership;
- set `serverAnswer` from GET;
- restore the exact `pendingMutationSnapshot` as the local draft intent;
- recompute it against the refreshed safe Question;
- if still locally valid and semantically different, expose it as dirty;
- if the refreshed Question changed so the pending intent is locally invalid,
  keep the draft visible with validation error and require Student correction;
- allow a **new explicit Save** only after the parent Attempt is confirmed-current
  `data`.

## Attempt is terminal

- clear uncertainty/reconciliation ownership;
- terminal server state wins;
- show refreshed read-only server answers;
- pending attempted value is discarded because it is no longer writable.

## GET reconciliation is itself uncertain/fails non-authoritatively

Keep:

```text
saveStatus = uncertain
pendingMutationSnapshot unchanged
```

and allow another `Reload attempt` later.

Session/target loss invalidates reconciliation ownership and clears local editor
state under Section 39.

Do not fabricate success.

---

# 38. Deterministic Save Errors

After excluding the session/account failures in Section 39, a structured
confirmed feature-level 4xx response is deterministic.

## `selection_limit_exceeded`

- clear active mutation snapshot;
- state failure;
- retain draft;
- show:
  ```text
  Too many options are selected.
  ```
- trigger Attempt refresh to reconcile current `max_selections`.

Do not silently deselect.

## `validation_failed`

- retain draft;
- show safe validation failure;
- no raw backend message dependency for control flow.

## `deadline_passed`

- clear active snapshot;
- trigger:
  ```text
  Attempt refresh
  Homework detail refresh
  ```
- show:
  ```text
  The Homework deadline has passed.
  ```
- expect refreshed Attempt to become terminal/read-only.

## `attempt_not_editable`

- trigger Attempt refresh;
- show:
  ```text
  This attempt is no longer editable.
  ```

## `task_closed` / `task_archived` / `task_not_active`

- trigger Attempt + Homework detail refresh;
- show:
  ```text
  This Homework is no longer editable.
  ```

## `resource_not_found`

- clear editor operation;
- trigger FE-002 Attempt notFound reconciliation.

## `business_conflict`

- retain draft only while Attempt remains in_progress;
- refresh Attempt;
- show safe generic conflict.

---

# 39. Session Failure

Use existing FE-002 session behavior.

If response is:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

clear editor operation/reconciliation ownership and invalidate its generation.

Clear all local drafts/pending mutation snapshots for this Student/target.

Unsaved local drafts must not carry into a future/new Student session.

Do not persist them globally.

Trigger auth bootstrap according to existing convention.

Late PUT/GET completions from the old session must not publish feedback, saved
state, validation, or navigation.

---

# 40. Draft Update During Saving

For the Question currently `saving`:

```text
disable its input controls
```

so the sent mutation snapshot and visible draft do not diverge.

Other Question drafts remain editable.

Do not allow current Question edit while its request is in flight.

---

# 41. Discard Local Changes

For any dirty Question not saving/uncertain provide:

```text
Discard changes
```

Action:

```text
reset draft to latest confirmed serverAnswer
clear local validation/failure state
isDirty = false
```

This is local only.

No DELETE/PUT is sent.

Do not label this as deleting the saved answer.

---

# 42. Clear Answer Local Action

Provide:

```text
Clear answer
```

only for server-clearable types:

```text
multiple_choice
short_written
open_written
matching
ordering
fill_in_blank
```

This changes local draft to its semantic-empty form.

It does **not** send immediately.

Student must press:

```text
Save answer
```

If server answer is already absent, clear produces no dirty state/no request.

No Clear action for:

```text
single_choice
true_false
file_based
```

---

# 43. Navigation / Unsaved Work Protection

Attempt screen must protect against accidental loss.

Define:

```text
hasDirtyDrafts
hasUncertainMutation
```

across the Attempt editor controller.

Use `PopScope` or the current equivalent project-compatible mechanism.

When Student tries to leave the Attempt route via its Back action/system back:

## Dirty drafts

Confirm:

```text
You have unsaved answer changes.
Leave and discard these changes?
```

Actions:

```text
Stay
Leave
```

## Uncertain mutation

Confirm separately or with priority:

```text
A save result is still unconfirmed.
Leaving will discard the local uncertainty/reconciliation state. Re-opening the attempt will reload server data.
```

Actions:

```text
Stay
Leave
```

On confirmed Leave:

- clear local editor state;
- navigate to Homework detail.

Do not send mutations automatically during route pop.

---

# 44. No Browser/Route Global Guard Architecture

Do not add a second global navigation guard system.

The unsaved-work protection belongs to:

```text
StudentHomeworkAttemptScreen
```

and its route-level pop behavior only.

Do not alter Teacher/Institution routing.

---

# 45. Editor Screen Integration

Modify delivered:

```text
student_homework_attempt_screen.dart
```

When the FE-002 Attempt controller has confirmed current:

```text
status = data
attempt.status = in_progress
```

render editors for the eight non-file types with Save eligibility from
Section 29.

During retained `refreshing`/stale presentation of a previously in-progress
Attempt, local drafts may remain visible according to the delivered FE-002
presentation, but all mutation Save actions are disabled until confirmed current
`data` returns.

When a confirmed Attempt is terminal:

- retain FE-002 read-only answer views;
- render no editing controls;
- terminal synchronization rules from Section 33 apply.

For `file_based` even during in-progress:

- retain FE-002 read-only file view.

---

# 46. Common Question Editor Card

Create focused presentation:

```text
frontend/lib/features/student/presentation/student_question_answer_editor.dart
```

It owns common card shell:

```text
Question number/type
prompt
instructions
points
editor body
save status
Save answer
Discard changes
Clear answer where allowed
```

Extract type-specific widgets when they carry meaningful complexity.

Recommended:

```text
student_choice_answer_editor.dart
student_written_answer_editor.dart
student_matching_answer_editor.dart
student_ordering_answer_editor.dart
student_fill_blank_answer_editor.dart
```

True/False may share choice-related file if clean.

Do not create one giant Widget with deeply nested type flags.

---

# 47. Save Status Presentation

Per Question show textual state.

Examples:

```text
Saved
Unsaved changes
Saving…
Save result unconfirmed
Could not save answer
```

Do not rely on icon/color only.

After successful save display server-confirmed:

```text
updatedAt
```

in Institution timezone if useful.

No timers required.

---

# 48. Multiple Choice Backend Cap Reconciliation

Backend-derived:

```text
maxSelections
```

is safe and authoritative.

Frontend local prevention is UX only.

If `selection_limit_exceeded` occurs despite local state:

- do not assume backend bug;
- refresh Attempt;
- preserve Student selections;
- recompute validation from refreshed Question;
- require Student to resolve if now over cap.

Do not infer which answers are correct from the cap.

---

# 49. Matching Privacy

Never:

- pair left/right items by array index;
- retain original Teacher `client_key`;
- expose `match_key`;
- style a mapping as correct/incorrect.

The editor only submits Student choices.

Right-item dropdown ordering is exactly the safe backend order received in the Question.

---

# 50. Ordering Privacy

Never:

- derive correct order from initial display order;
- expose `correct_position`;
- compare Student positions to any hidden answer.

The initial Question item order is only display order.

The position controls represent Student-submitted order only.

---

# 51. Written Privacy / Normalization

Do not implement backend Stage 9 matching normalization in Flutter.

For Short Written:

- preserve exact input;
- validate only length/semantic clear;
- do not lowercase;
- do not collapse whitespace;
- do not normalize apostrophes;
- do not compare against accepted answers.

Open Written same exact preservation.

---

# 52. Fill Blank Prompt

Continue displaying the safe Question prompt.

Blank fields are keyed by safe:

```text
blank.key
```

Do not try to retrieve hidden accepted answers.

The editor may render fields separately below the prompt rather than attempting an inline rich text field inside `{{key}}`.

No requirement for inline replacement UI in Stage 7 MVP.

---

# 53. Local State and Text Controllers

Text editing must remain deterministic.

Widgets may use `TextEditingController` where appropriate, but must synchronize it with the typed application draft without:

- cursor jumps on every rebuild;
- stale server refresh overwriting dirty text;
- controller leaks.

Dispose controllers.

For dynamic Fill fields, use stable keys based on:

```text
blank.id
```

Do not key fields by list index alone.

---

# 54. Accessibility

Required:

## Choice

- option labels announced;
- selection state accessible.

## Multiple

- announce:
  ```text
  selected X of N
  ```
- disabled-at-cap options remain semantically understandable.

## Written

- field labels tied to Question context;
- length error text accessible.

## Matching

- each dropdown semantic label includes left item text.

## Ordering

- each position dropdown label includes item text;
- Unassigned is explicit.

## Fill

- each field label includes blank key.

## Common

- Save/Discard/Clear have explicit labels;
- saving exposes busy semantics;
- uncertain/error text is accessible;
- status not color-only;
- keyboard traversal logical on desktop;
- touch targets usable on mobile.

---

# 55. Responsiveness

Support desktop/mobile.

Requirements:

- no fixed width causing overflow;
- option text wraps;
- written fields expand to width;
- Matching rows may stack label/dropdown on narrow mobile;
- Ordering rows stack safely;
- Fill fields stack;
- action buttons use `Wrap` where necessary;
- long prompt/instructions remain scrollable;
- text scaling does not overflow horizontally.

No desktop-only editing restriction.

---

# 56. API Error Codes

Modify delivered:

```text
frontend/lib/core/network/api_error_codes.dart
```

Add if not already present:

```text
attemptNotEditable = attempt_not_editable
selectionLimitExceeded = selection_limit_exceeded
```

Do not pre-add FE-004/FE-005-only codes unless delivered baseline already has them.

---

# 57. Expected Files

## Create

```text
frontend/lib/features/student/domain/student_answer_draft.dart
frontend/lib/features/student/domain/student_answer_mutation.dart

frontend/lib/features/student/data/dto/student_attempt_answer_mutation_dto.dart

frontend/lib/features/student/application/student_attempt_answer_editor_state.dart
frontend/lib/features/student/application/student_attempt_answer_editor_controller.dart

frontend/lib/features/student/presentation/student_question_answer_editor.dart
frontend/lib/features/student/presentation/student_choice_answer_editor.dart
frontend/lib/features/student/presentation/student_written_answer_editor.dart
frontend/lib/features/student/presentation/student_matching_answer_editor.dart
frontend/lib/features/student/presentation/student_ordering_answer_editor.dart
frontend/lib/features/student/presentation/student_fill_blank_answer_editor.dart

frontend/test/features/student/student_answer_mutation_test.dart
frontend/test/features/student/student_answer_mutation_data_test.dart
frontend/test/features/student/student_answer_editor_controller_test.dart
frontend/test/features/student/student_answer_editor_screen_test.dart
```

## Modify

```text
frontend/lib/features/student/domain/student_homework_attempt_repository.dart
frontend/lib/features/student/data/student_homework_attempt_remote_data_source.dart
frontend/lib/features/student/data/student_homework_attempt_repository_impl.dart

frontend/lib/features/student/presentation/student_homework_attempt_screen.dart
frontend/lib/features/student/presentation/student_homework_formatters.dart

frontend/lib/core/network/api_error_codes.dart
```

Modify FE-002 Attempt answer parsing code only to expose/reuse an existing safe typed answer parser.

Do not create duplicate saved-answer models/parsers.

No routing path change required.

No backend/pubspec/platform files.

---

# 58. Mutation Domain Tests

`student_answer_mutation_test.dart` covers exact serialization.

## Single

```text
one ID
```

## Multiple

- safe option-order canonicalization;
- empty serializes empty list.

## True

boolean exact.

## Short/Open

- exact text preserved;
- whitespace payload preserved even though canonical semantic state is clear;
- Unicode-rune length validation.

## Matching

- Question left-order canonicalization;
- partial/empty.

## Ordering

- position sort;
- partial/empty;
- no duplicate positions.

## Fill

- blank-position order;
- whitespace-only fields omitted;
- exact non-empty text preserved;
- empty values list.

Also test semantic equality/dirty comparison.

---

# 59. Mutation Data Tests

`student_answer_mutation_data_test.dart` covers exact:

```text
PUT /student/attempts/{attempt}/answers/{question}
```

Verify:

- encoded IDs;
- JSON body exact;
- no query;
- no Idempotency-Key;
- `followRedirects=false`;
- success 200 only.

Response parsing:

- non-null typed answer;
- null clear response;
- exact `answer <=> updated_at` nullability;
- exact whole-second UTC `YYYY-MM-DDTHH:MM:SSZ`;
- question/type mismatch rejected;
- child ID outside the requested safe Question rejected;
- Multiple response above safe `maxSelections` rejected;
- Ordering response position outside Question item count rejected;
- written/fill semantically-empty persisted response rejected;
- unexpected keys rejected;
- invalid null for Single/True rejected;
- malformed/permissive/fractional `updated_at` rejected;
- score/checking fields rejected.

Malformed success:

```text
invalidResponse
```

---

# 60. Editor Controller Tests

`student_answer_editor_controller_test.dart` must cover.

## Initialization

All eight non-file drafts from:

```text
saved answer
no saved answer
```

File Question excluded from editor map.

## Dirty/no-op

- same semantic state clean;
- order-only changes clean where non-semantic;
- clear absent clean;
- real replacement dirty.

## Local validation

- missing Single/True selection;
- Multiple cap;
- written lengths using runes;
- matching uniqueness;
- ordering uniqueness/range;
- fill length.

## Save

- valid dirty sends exact mutation only from confirmed-current `data`
  in-progress Attempt;
- clean does not send;
- refreshing/stale/error/notFound parent cannot send;
- only one active save/reconciliation per Attempt;
- saving current Question disables further save.

## Success

- response is validated against the current safe Question;
- response becomes base;
- draft rebased;
- dirty false;
- parent Attempt refresh requested.

## Malformed 200

- invalid response becomes uncertain;
- exact sent mutation snapshot retained;
- no `saved` state;
- no blind PUT retry.

## Deterministic failure

- draft retained;
- mutation snapshot cleared;
- correct reconciliation triggered for lifecycle codes.

## Uncertain

- exact mutation snapshot retained;
- no Retry-save control/path exists;
- other save blocked;
- Reload Attempt is the only recovery action.

## Reload reconciliation

- owned reconciliation completion with refreshed server answer == snapshot => saved;
- differs while in-progress => refreshed server becomes base and exact snapshot
  returns as dirty local draft;
- differing/newer server state is never automatically overwritten;
- terminal => read-only/server state wins;
- reconciliation GET failure keeps uncertainty/snapshot.

## Parent refresh ownership

- ordinary in-progress parent refresh does not resolve an uncertain Question;
- terminal parent refresh invalidates active PUT/reconciliation generation;
- late PUT/GET completion after terminal publish is ignored.

## Session/target/dispose

Stale mutation/reconciliation completion cannot publish.

---

# 61. Editor Screen Tests

`student_answer_editor_screen_test.dart` covers desktop and mobile.

Render an in-progress Attempt containing all nine types.

Verify editors for exactly eight non-file types.

## Single

- selection;
- Save;
- no clear.

## Multiple

- cap;
- disabled unchecked option at cap;
- deselect;
- Clear answer;
- Save clear.

## True

- True/False;
- no clear.

## Short/Open

- exact text;
- validation error;
- Clear answer;
- Discard changes.

## Matching

- each left has dropdown;
- right item cannot be duplicated;
- partial;
- clear.

## Ordering

- Unassigned;
- unique positions;
- partial;
- clear.

## Fill

- fields by blank key;
- partial;
- clear;
- long-value error.

## File

No picker/upload in FE-003.

## Common

- Save disabled when clean;
- Save disabled while parent Attempt is refreshing/stale/non-current;
- Saving busy;
- Saved state;
- deterministic error;
- uncertain state shows `Reload attempt` and no `Reload attempt`;
- other Save buttons blocked during active mutation/reconciliation.

No score/correctness UI.

---

# 62. Terminal Attempt Regression

Widget/controller tests must verify that when parent Attempt refresh changes:

```text
in_progress
->
submitted
```

while local drafts and/or an active/uncertain operation exist:

- editor mutation/reconciliation generation is invalidated;
- all editors disappear/become read-only;
- dirty drafts no longer appear as savable;
- pending uncertainty is cleared;
- server saved answers are shown;
- late PUT/GET completion cannot publish over terminal state;
- no automatic PUT is sent;
- no score is shown.

This covers deadline/Teacher-close races from the client perspective.

---

# 63. Unsaved Navigation Tests

Test:

## Dirty draft + Back

Confirmation appears.

`Stay`:

- remains on Attempt;
- draft retained.

`Leave`:

- no save request;
- returns to Homework detail.

## Uncertain save + Back

Unconfirmed-outcome warning appears.

Leave clears the local pending mutation/reconciliation state.

Re-entering is expected to GET Attempt through FE-002; FE-003 does not preserve
uncertain operation globally and does not auto-resend the old PUT.

## Clean

Back navigates without confirmation.

Use controlled navigation test harness.

---

# 64. Directly Affected Regression Tests

Run FE-003 tests plus:

```text
test/features/student/student_homework_attempt_dto_test.dart
test/features/student/student_homework_attempt_data_test.dart
test/features/student/student_homework_attempt_start_controller_test.dart
test/features/student/student_homework_attempt_controller_test.dart
test/features/student/student_homework_attempt_screen_test.dart
test/features/student/student_homework_attempt_routing_test.dart

test/features/student/student_homework_screen_test.dart
test/features/student/student_homework_routing_test.dart
```

If delivered FE-001/002 materially do not contain these approved boundaries,
return `BLOCKED` for dependency-contract mismatch instead of silently remapping
verification.

Do not run the full frontend suite in this task.

---

# 65. Verification

Run from:

```text
frontend/
```

## 65.1 Focused FE-003 + directly affected FE-002/FE-001 regressions

Exactly:

```bash
flutter test \
  test/features/student/student_answer_mutation_test.dart \
  test/features/student/student_answer_mutation_data_test.dart \
  test/features/student/student_answer_editor_controller_test.dart \
  test/features/student/student_answer_editor_screen_test.dart \
  test/features/student/student_homework_attempt_dto_test.dart \
  test/features/student/student_homework_attempt_data_test.dart \
  test/features/student/student_homework_attempt_start_controller_test.dart \
  test/features/student/student_homework_attempt_controller_test.dart \
  test/features/student/student_homework_attempt_screen_test.dart \
  test/features/student/student_homework_attempt_routing_test.dart \
  test/features/student/student_homework_screen_test.dart \
  test/features/student/student_homework_routing_test.dart
```

Narrow single-test diagnostic reruns are allowed only to diagnose/confirm a
concrete failure.

## 65.2 Exact Dart format check

Exactly:

```bash
dart format --output=none --set-exit-if-changed \
  lib/features/student/domain/student_answer_draft.dart \
  lib/features/student/domain/student_answer_mutation.dart \
  lib/features/student/domain/student_homework_attempt_repository.dart \
  lib/features/student/data/dto/student_attempt_answer_mutation_dto.dart \
  lib/features/student/data/student_homework_attempt_remote_data_source.dart \
  lib/features/student/data/student_homework_attempt_repository_impl.dart \
  lib/features/student/application/student_attempt_answer_editor_state.dart \
  lib/features/student/application/student_attempt_answer_editor_controller.dart \
  lib/features/student/presentation/student_question_answer_editor.dart \
  lib/features/student/presentation/student_choice_answer_editor.dart \
  lib/features/student/presentation/student_written_answer_editor.dart \
  lib/features/student/presentation/student_matching_answer_editor.dart \
  lib/features/student/presentation/student_ordering_answer_editor.dart \
  lib/features/student/presentation/student_fill_blank_answer_editor.dart \
  lib/features/student/presentation/student_homework_attempt_screen.dart \
  lib/features/student/presentation/student_homework_formatters.dart \
  lib/core/network/api_error_codes.dart \
  test/features/student/student_answer_mutation_test.dart \
  test/features/student/student_answer_mutation_data_test.dart \
  test/features/student/student_answer_editor_controller_test.dart \
  test/features/student/student_answer_editor_screen_test.dart
```

If exposing the delivered FE-002 saved-answer parser requires editing its
existing DTO/domain file, add that **exact delivered changed file** to this
format invocation during ChatGPT implementation-baseline revalidation before
Codex starts. Codex must not choose an unreviewed parser refactor/file on its
own.

## 65.3 Static analysis

Exactly:

```bash
flutter analyze
```

## 65.4 Diff hygiene

From repository root exactly:

```bash
git diff --check
```

Then perform the focused diff/scope self-review required by root/frontend
`AGENTS.md`.

Do not run:

- full frontend test suite;
- target build;
- backend suite;
- E2E/integration runner.

---

# 66. Acceptance Criteria

PASS only if all are true.

## Eight types

- Single Choice editable/savable;
- Multiple Choice editable/clearable with max;
- True/False editable/savable;
- Short Written editable/clearable;
- Open Written editable/clearable;
- Matching partial/clearable;
- Ordering partial/clearable;
- Fill Blank partial/clearable;
- File remains non-editable.

## Typed architecture

- no raw answer Maps in application/presentation;
- typed drafts/mutations;
- FE-002 saved-answer parser reused;
- mutation response is validated against the current safe `StudentQuestion`;
- mutation timestamps reuse exact Stage 7 whole-second UTC parser;
- repository/data source own transport.

## Save semantics

- explicit Save only;
- no autosave;
- exact backend JSON;
- no idempotency header;
- semantic no-op sends nothing;
- server response becomes confirmed base;
- clear only for backend-supported types.

## Reliability

- one active answer mutation/reconciliation per Attempt;
- uncertain PUT retains the exact mutation only for GET comparison/local draft
  restoration;
- no blind PUT Retry exists after an uncertain outcome;
- authoritative Reload reconciles safely without overwriting an intervening
  newer server answer;
- ordinary parent refresh cannot silently resolve an uncertain Question;
- terminal parent refresh invalidates active operation generations;
- deterministic lifecycle errors refresh authoritative state;
- stale session/target/terminal-obsolete completion cannot publish.

## Lifecycle

- editing/Save authority requires confirmed-current FE-002 `data` +
  `in_progress`;
- refreshing/stale/error/notFound parent state cannot send PUT;
- terminal refresh removes editors and invalidates active save/reconciliation;
- no device-time eligibility;
- no post-finalization optimistic state.

## UX

- dirty/saved/saving/failure/uncertain states visible;
- Discard changes works;
- Clear answer is local until Save;
- unsaved/uncertain route leave warns;
- desktop/mobile/accessibility requirements met.

## Privacy

- no answer keys/correctness/scoring;
- Matching/Ordering do not infer correctness;
- written answers are not scoring-normalized.

## Scope

- no file mutation;
- no final Submit;
- no score/review;
- no package/router/backend/platform change.

## Verification

- exact focused test command passes;
- exact named regressions pass;
- exact Dart format command passes;
- `flutter analyze` passes;
- `git diff --check` passes;
- focused self-review passes.

---

# 67. Locked Implementation Decisions

These are decisions, not suggestions:

```text
answer UX = explicit per-Question Save
autosave = no
non-file types = exactly 8
file_based = FE-004
final Submit = FE-005
ordinary answer PUT = no Idempotency-Key
semantic clean state = no request
one active save/reconciliation operation per Attempt
uncertain PUT = no blind PUT retry
uncertain recovery = authoritative GET Attempt reconciliation
pending mutation snapshot = comparison + local dirty-intent restoration only
clearable = multiple, short, open, matching, ordering, fill
not clearable = single, true_false
Short max = 1000 Unicode scalars
Open max = 20000 Unicode scalars
Fill value max = 1000 Unicode scalars
matching partial = allowed
ordering partial = allowed
fill partial = allowed
server Attempt confirmed-current data/status = editability authority
refreshing/stale parent Attempt = no PUT
device time = never editability authority
mutation response = validate against current safe Question
mutation updatedAt = exact YYYY-MM-DDTHH:MM:SSZ
dirty local draft survives normal in-progress parent refresh
ordinary parent refresh does not resolve uncertain Question
terminal parent state invalidates active operations, discards unsavable dirty drafts and shows server state
```

Codex must not substitute:

- autosave/debounce;
- one idempotency UUID per answer;
- blind resend of uncertain PUT snapshot;
- treating complete-replace PUT as safe against an intervening newer write;
- generic JSON answer state;
- drag-only full Ordering that removes partial support;
- index-based Matching;
- hidden correctness inference;
- silent text normalization;
- automatic Save on route leave;
- file picker early;
- Submit early.

---

# 68. Completion Report

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
3. exact focused test results;
4. eight-type payload/editor evidence;
5. semantic no-op/clear evidence;
6. uncertain PUT GET-reconciliation/no-blind-retry evidence;
7. lifecycle/session/parent-refresh/stale-completion evidence;
8. unsaved-navigation evidence;
9. desktop/mobile/accessibility evidence;
10. directly affected regressions;
11. format/analyze results;
12. `git diff --check`;
13. scope/non-goal confirmation;
14. deviations/blockers;
15. final `git status --short`.

Do not claim `Accepted`.

Do not commit/push/create PR/update Stage bookkeeping unless explicitly instructed later.
