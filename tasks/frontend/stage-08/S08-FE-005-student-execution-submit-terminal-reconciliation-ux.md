# Codex Implementation Contract: S08-FE-005 — Student Blitz Execution, Submit and Terminal Reconciliation UX

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-FE-005` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter Student Blitz typed/file answer execution + idempotent Submit + timeout/close terminal reconciliation` |
| Depends on | `S08-FE-001…004 Accepted / Delivered`; `S08-BE-PHASE-2 = PASS` remains valid |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Runtime implementation baseline | ChatGPT must re-check/freeze current `origin/main` immediately before Codex execution |
| Backend API dependency | Final delivered Stage 8 shared answer/file route + Blitz Submit + protected file download after Backend Phase 2 PASS |
| Flutter toolchain | Use the repository's current FVM-pinned Flutter version at implementation time |
| Implementation Readiness Gate | `PASS — planning contract`; execution remains dependency-gated |
| Verification | `Codex — focused frontend verification only` |
| Delivery execution | `Project Owner` |
| Frontend block checkpoint | `S08-FE-PHASE-2` after `S08-FE-001…006` are `Accepted / Delivered` |
| Blocks | `S08-FE-006` |

Do not start until:

```text
S08-FE-004 = Accepted / Delivered
S08-BE-PHASE-2 = PASS
current origin/main re-checked
final shared answer/file + Blitz Submit backend resources inspected
current FE-004 Blitz execution shell/start-state implementation inspected
current Stage 7 answer/file/Submit frontend primitives inspected
clean synchronized local main
```

If delivered dependencies materially conflict with this contract:

```text
BLOCKED
```

with exact evidence.

Do not invent:

- a Blitz Attempt GET endpoint;
- a local timeout finalization rule;
- a second normal retry;
- scoring/checking behavior;
- a new file storage/download contract.

This file is the complete task-specific implementation contract.

Do **not** create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. delivered S08-FE-004 source/tests directly required here;
5. final delivered Stage 8 answer/file/Submit/protected-file backend routes/resources directly required to confirm the API already encoded below;
6. current Stage 7 Student answer/file/Submit source directly required for type-safe reuse;
7. shared Student Question, file-picker, protected-transfer, idempotency and session infrastructure required by this task.

Do **not** read:

- product docs;
- roadmap;
- previous Stage 8 task files;
- Stage history;
- checkpoint reviews;
- closure reviews;
- unrelated modules

to determine behavior.

This contract resolves:

- authoritative current Blitz Attempt ownership without GET Attempt;
- safe replay of the completed Start request;
- eight non-file answer editors;
- file answer selection/upload/replace;
- current submitted-file open/save;
- shared answer transport reuse;
- answer mutation success adoption;
- uncertain answer/file reconciliation;
- deadline/countdown edit gating;
- explicit final Submit;
- Submit readiness;
- Submit Idempotency-Key lifetime;
- uncertain Submit retry/check behavior;
- terminal timeout/Teacher-close/student-submit reconciliation;
- unanswered Question handling;
- leaving/dirty/uncertain-operation guards;
- session/route/attempt stale-completion safety;
- desktop/mobile execution UX;
- focused verification.

---

# 3. Goal

Complete Student Blitz execution UX on top of FE-004.

While a valid Blitz Attempt is in progress, the Student must be able to:

- answer all eight non-file Question types;
- clear answers where the shared answer contract permits it;
- choose/upload/replace a file answer;
- open/save their current submitted file;
- recover safely from uncertain answer/file mutations;
- see only server-confirmed saved state;
- explicitly Submit before the authoritative deadline;
- Submit even when some Questions remain unanswered;
- safely retry an uncertain Submit with the same key;
- reconcile timeout/Teacher-close terminal state;
- never gain extra time from local device clock or UI retries.

When execution becomes terminal, the Student must see a read-only finalization
summary.

Stage 8 still does **not** show:

```text
correctness
awarded points
score
feedback
checking result
official Topic result
```

---

# 4. Included Backend APIs

Use configured Dio base:

```text
/api/v1
```

## 4.1 Shared typed/file answer route

```text
PUT /student/attempts/{attemptId}/answers/{questionId}
```

Non-file:

```text
Content-Type: application/json
```

File:

```text
multipart/form-data
```

Success:

```text
200
```

Exact success envelope remains the shared current answer-mutation shape:

```json
{
  "data": {
    "question_id": "uuid",
    "type": "single_choice",
    "answer": {},
    "updated_at": "2026-09-15T00:00:00Z"
  }
}
```

Cleared answer:

```json
{
  "data": {
    "question_id": "uuid",
    "type": "open_written",
    "answer": null,
    "updated_at": null
  }
}
```

## 4.2 Protected current submission file

Reuse:

```text
GET /files/{fileId}/download
```

No Blitz-specific file endpoint.

## 4.3 Final Submit

```text
POST /student/attempts/{attemptId}/submit
```

Required:

```http
Idempotency-Key: <uuid>
```

Body:

```json
{}
```

Success:

```text
200
```

Exact message:

```text
Blitz attempt submitted successfully.
```

Returns complete authoritative:

```text
StudentBlitzAttempt
```

## 4.4 Attempt reconciliation

There is still **no** Blitz Attempt GET endpoint.

Authoritative Attempt reconciliation uses the already-completed FE-004 Start
request replay mechanism defined below.

---

# 5. Explicit Non-Goals

Do not implement:

- Teacher monitoring;
- Teacher exception grant UI;
- Student exception-request UI;
- a new Attempt;
- Attempt #3;
- automatic Submit at local zero;
- client-side timeout persistence;
- score/checking/review UI;
- official score;
- Topic result;
- result comparison;
- Parent UI;
- offline answer queue;
- background uploads;
- automatic non-idempotent answer retry;
- automatic file upload retry;
- new package;
- backend changes;
- platform changes;
- full frontend suite/build/E2E.

Do not expose correct-answer data.

Do not invent a score from `points`.

---

# 6. Critical FE-004 Compatibility Extension — Preserve Completed Immutable Start Request

FE-004 already owns one immutable logical execution request:

```text
StudentBlitzAttemptRequest {
  intent,
  attemptId?,
  idempotencyKey
}
```

S08-FE-005 requires a narrow handoff extension:

> After a strictly validated successful Start/Resume/replacement-Start, preserve
> the **exact request object that was actually sent** privately for the current
> route-session as the completed Start replay request.

Do not reduce that request to only its Idempotency-Key.

Required private distinction:

```text
FE-004:
_pendingRequest

FE-005 route-session:
_completedStartRequest
```

Both values use the same immutable `StudentBlitzAttemptRequest` type.

## On successful Start/Resume/replacement-Start

Before FE-004 clears `_pendingRequest`, atomically hand off:

```text
authoritative returned StudentBlitzAttempt
+
exact immutable pending request {
  intent,
  attemptId?,
  idempotencyKey
}
```

to the FE-005 execution authority.

After successful handoff FE-004 may clear:

```text
_pendingRequest
```

FE-005 retains an immutable private copy as:

```text
_completedStartRequest
```

## On uncertain Start

Only FE-004 `_pendingRequest` exists.

Do not create/update FE-005 completed context until strict success is confirmed.

## On deterministic Start failure

Clear FE-004 pending request according to FE-004.

Do not create FE-005 completed context.

## On route/session loss

Clear both pending and completed request contexts.

Do not expose:

```text
intent
attemptId
idempotencyKey
```

as mutable Widget state or raw debug/user-facing data.

This preserves FE-004's pending-request lifecycle while retaining the complete
fingerprint-bearing request required for safe later replay.

---

# 7. Why the Completed Start Request Is Required

Blitz backend intentionally has no:

```text
GET /student/attempts/{attempt}
```

read route.

Answer PUT is not idempotent.

A Student needs a safe way to re-read the exact current Attempt after:

- uncertain typed answer save;
- uncertain file upload;
- timeout conflict;
- task-close conflict;
- uncertain Submit;
- terminal race.

The completed Start idempotency record is the safe read/replay anchor, but its
fingerprint includes the original semantic request.

Therefore replay requires the same:

```text
intent
attempt_id when intent=resume
Idempotency-Key
```

not the key alone.

Calling:

```text
POST /student/blitz/{blitz}/attempts
```

with the exact immutable `_completedStartRequest`:

- replays the same logical Start/Resume/replacement-Start result;
- resolves the same Attempt;
- cannot switch semantic intent;
- never creates replacement Attempt #2 merely because recovery ran;
- never resets timing;
- can return the Attempt's current terminal state after timeout/close/Submit.

This is the only approved Attempt re-read mechanism in FE-005.

Do not derive the replay body from:

```text
current Attempt number
current Attempt status
fresh Blitz detail
replacement availability
current lifecycle
```

The original completed request is the replay authority.

---

# 8. Do Not Use a New Start Key for Reconciliation

Never reconcile an existing Attempt by generating a new Start key.

Why:

- if Attempt #1 became terminal and a Teacher granted an exception concurrently,
  a new Start key could legitimately create replacement Attempt #2;
- a read/recovery action must never create new work.

Every FE-005 current-Attempt reconciliation uses:

```text
_completedStartRequest
```

only.

The exact stored:

```text
intent
attemptId?
idempotencyKey
```

must be resent unchanged.

If no completed replay request exists:

- answer/file/Submit mutation authority is unavailable;
- require Student to return to the pre-Start/detail authority and reload current
  server state;
- offer explicit Resume **only if** that fresh detail still identifies an exact
  `in_progress` Attempt;
- if no resumable Attempt exists, remain read-only and follow the authoritative
  current lifecycle/usage state instead of inventing a new Start/Resume path.

Do not fall back to a new key or reconstruct a different intent body.

Do not add a historical Blitz Attempt GET merely to restore discarded local
route-session state.

---

# 9. Blitz Execution Authority Controller

Create or refactor to one route-session parent authority equivalent to:

```text
StudentBlitzExecutionController
StudentBlitzExecutionState
```

Family target:

```text
StudentBlitzRouteTarget
```

This becomes the authoritative frontend owner of the currently opened Blitz
Attempt after Start/Resume.

FE-004 Start controller must transfer the successful Attempt together with the
exact immutable successful `StudentBlitzAttemptRequest` into it.

Do not keep two independently mutable copies of the Attempt.

---

# 10. Execution State

State concepts:

```text
none
active
refreshing
terminal
reconciliationFailed
```

Fields:

```text
attempt?
publicationToken?
failure?
localTimeExpired
```

The completed immutable Start request remains private in the controller, not
public state.

Public execution state must not expose raw `intent`, `attemptId` or
`idempotencyKey` merely for replay bookkeeping.

---

# 11. Attempt Publication Token

Create an opaque identity token equivalent to the current Homework Attempt
publication-token pattern.

Every accepted authoritative full Attempt publication creates a new token.

Answer/file editor state records the source token it synchronized from.

Submit readiness requires all editor/file state to align with the current token.

A partial answer-mutation success that the execution controller safely applies
creates a new publication token.

This prevents Submit from using stale editor snapshots.

---

# 12. FE-004 Start Success Handoff

On valid FE-004 Start/Resume/replacement-Start success:

```text
StudentBlitzAttempt
+
exact successful StudentBlitzAttemptRequest {
  intent,
  attemptId?,
  idempotencyKey
}
```

must be atomically handed to:

```text
StudentBlitzExecutionController.acceptStartedAttempt(...)
```

or a responsibility-equivalent API that accepts both values in one handoff.

Require:

```text
same Student session
same Blitz route target
attempt.assessmentId == target.blitzId
attempt.id canonical

completedRequest.intent = exact FE-004 originating intent
completedRequest.idempotencyKey = exact sent key

if completedRequest.intent = resume:
  completedRequest.attemptId = exact requested Attempt ID
  returned attempt.id = completedRequest.attemptId

if completedRequest.intent = start_normal:
  completedRequest.attemptId = null
  returned attempt.attemptNumber = 1

if completedRequest.intent = start_replacement:
  completedRequest.attemptId = null
  returned attempt.attemptNumber = 2
```

Do not infer or rewrite the completed intent from the returned Attempt.

If Attempt is:

```text
in_progress
```

execution state becomes:

```text
active
```

If valid replay is already terminal:

```text
terminal
```

Questions remain read-only.

---

# 13. Completed Start Replay Method

Execution controller exposes a focused method:

```text
Future<StudentBlitzAttemptReplayOutcome> refreshCurrentAttempt()
```

or equivalent internal application API.

It:

1. requires current Student session;
2. requires current route target;
3. requires current Attempt;
4. requires private immutable `_completedStartRequest`;
5. replays through the FE-004 intent-specific execution repository using the
   **exact stored request**, either via:
   ```text
   execute(blitzId, completedStartRequest)
   ```
   or exact semantic dispatch selected only from the stored intent:
   ```text
   startNormal(
     blitzId,
     completedStartRequest.idempotencyKey,
   )

   resume(
     blitzId,
     completedStartRequest.attemptId,
     completedStartRequest.idempotencyKey,
   )

   startReplacement(
     blitzId,
     completedStartRequest.idempotencyKey,
   )
   ```
6. sends the exact original JSON body:
   ```json
   {"intent":"start_normal"}
   ```
   or:
   ```json
   {"intent":"resume","attempt_id":"<original-attempt-id>"}
   ```
   or:
   ```json
   {"intent":"start_replacement"}
   ```
   with the same original `Idempotency-Key`;
7. requires returned:
   ```text
   attempt.id == current Attempt ID
   attempt.assessmentId == target.blitzId
   ```
8. additionally requires:
   ```text
   completed intent=start_normal      => returned attempt_number=1
   completed intent=start_replacement => returned attempt_number=2
   completed intent=resume            => returned attempt.id=stored attemptId
   ```
9. accepts the full authoritative Attempt;
10. returns whether Attempt is active/terminal.

Never choose replay intent from the current Attempt or refreshed detail.

If replay unexpectedly resolves another Attempt or violates the stored intent:

```text
invalidResponse
```

and do not adopt.

No new key.

No modified body.

No intent switching.

---

# 14. Replay HTTP Result Status

Backend returns the original completed Start logical HTTP status:

```text
200 or 201
```

even when current projection is now terminal.

Do not interpret:

```text
201
```

during replay as a new Attempt.

The key is already completed.

The returned Attempt ID must remain exactly the current one.

---

# 15. Execution Controller — Answer Mutation Adoption

For a strict successful answer/file mutation response, do **not** require a full
Attempt replay.

The mutation response is authoritative for exactly one Question.

Execution controller exposes a method equivalent to:

```text
acceptAnswerMutation(
  attemptId,
  questionId,
  mutationResult,
  expectedPublicationToken,
)
```

It validates:

- same current Attempt ID;
- current Attempt still `in_progress`;
- Question exists;
- Question type matches;
- mutation response belongs to that Question;
- caller's expected publication is still current.

Then replace/remove exactly that Answer in the immutable Attempt answer list.

Preserve:

```text
Questions
Attempt status/timing
other answers
```

Publish a new Attempt snapshot/token.

No score/checking change.

---

# 16. Clear Answer Adoption

When strict mutation result is:

```text
answer = null
updatedAt = null
```

remove the persisted answer entry for that Question.

Do not create:

```text
empty placeholder answer
```

The local editor draft becomes canonical empty state.

---

# 17. Shared Answer Mutation Transport Extraction

The current Stage 7 HTTP implementation for:

```text
PUT /student/attempts/{attempt}/answers/{question}
```

is Assessment-type-neutral.

Extract/reuse a shared boundary such as:

```text
StudentAttemptAnswerRepository
StudentAttemptAnswerRemoteDataSource
```

Methods:

```text
saveAnswer(...)
uploadFileAnswer(...)
```

Move/reuse existing:

```text
StudentAttemptAnswerMutationResult
StudentAttemptAnswerMutationDto
StudentAnswerMutation
StudentSubmissionUploadFile
```

Update Homework answer/file controllers to use the shared repository without
behavior change.

Do not copy the raw answer PUT implementation into a second Blitz transport.

---

# 18. Shared Answer Mutation DTO

Keep the existing strict response parser.

It already validates:

- exact envelope;
- Question ID;
- requested type;
- safe answer shape;
- file metadata against selected file;
- clear nullability.

If FE-004 extracted saved-answer parser to type-neutral files, update imports.

Do not broaden response shape.

No message key is expected for answer mutation.

---

# 19. Eight Non-File Question Editors

Reuse existing:

```text
StudentAnswerDraft
StudentQuestionAnswerEditorState
StudentQuestionAnswerEditor
StudentChoiceAnswerEditor
StudentWrittenAnswerEditor
StudentMatchingAnswerEditor
StudentOrderingAnswerEditor
StudentFillBlankAnswerEditor
```

Supported non-file types:

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

Do not create Blitz-specific field widgets.

---

# 20. Blitz Non-File Answer Controller

Create:

```text
StudentBlitzAnswerEditorController
```

family keyed by a stable execution target equivalent to:

```text
StudentBlitzExecutionTarget(
  routeTarget,
  attemptId,
)
```

Reuse:

```text
StudentAttemptAnswerEditorState
StudentQuestionAnswerEditorState
StudentAnswerSaveStatus
```

where types are genuinely type-neutral.

Do not force the existing Homework controller to watch two incompatible parent
authority implementations.

Controller orchestration may be Blitz-specific while editor domain/UI remains
shared.

---

# 21. Blitz Execution Target

Create immutable:

```text
StudentBlitzExecutionTarget
```

Fields:

```text
routeTarget: StudentBlitzRouteTarget
attemptId
```

All IDs canonical.

Equality/hash includes:

```text
topicId
blitzId
attemptId
```

This identifies answer/file/Submit controller ownership.

It is not a Flutter route.

---

# 22. Editor Synchronization

The Blitz answer editor watches:

```text
StudentBlitzExecutionController(routeTarget)
```

When a new authoritative Attempt publication is active/terminal:

- rebuild per-Question editor states;
- preserve a dirty local draft only while the current publication remains a safe
  active continuation and no authoritative conflict invalidates it;
- preserve an uncertain mutation state until its owned reconciliation completes;
- terminal Attempt clears editable draft authority.

Do not preserve dirty/uncertain state into another Attempt ID.

---

# 23. Non-File Edit Authority

A non-file Question is editable only when all are true:

```text
same current Student session
same execution target
execution Attempt status = in_progress
execution publication is authoritative
local countdown has not entered expired/reconciling gate
no Submit route gate blocks mutations
question is non-file
no answer mutation currently active for this controller
```

Positive local countdown is a UX condition, not server authorization.

Backend remains final authority.

---

# 24. Non-File Save

Use existing:

```text
StudentAnswerDraft.toMutation(question)
```

Send through shared:

```text
StudentAttemptAnswerRepository.saveAnswer(...)
```

No Idempotency-Key.

Do not automatically retry.

Only one non-file save operation at a time in the Blitz answer controller.

---

# 25. Non-File Success

On strict `200` mutation result:

1. confirm current operation/session/target;
2. ask execution controller to accept the answer mutation against the expected
   publication token;
3. if accepted:
   - synchronize editor from new publication;
   - status `saved`;
   - show updated timestamp where current UI does;
4. if not accepted because parent authority changed:
   - perform safe Start replay reconciliation;
   - do not blindly apply stale response.

No full Attempt replay is needed for the normal successful path.

---

# 26. Non-File Uncertain Save

Treat as uncertain:

```text
connection
timeout
cancelled
invalidResponse
unknown
statusCode == null
statusCode >= 500
```

Do not automatically retry the PUT.

Keep:

```text
pending mutation snapshot
draft
Question identity
```

UI:

```text
Save result unconfirmed
Check current attempt
```

Do not show an automatic `Retry Save`.

Reason:

> PUT is non-idempotent at the transport level and the current server result must
> be checked first.

---

# 27. Non-File Uncertain Reconciliation

`Check current attempt` uses:

```text
StudentBlitzExecutionController.refreshCurrentAttempt()
```

which safely replays the **exact completed immutable Start request**.

If returned Attempt is still:

```text
in_progress
```

find the current server answer.

Compare pending mutation semantically using existing draft/mutation logic.

## Server answer matches pending mutation

Classify:

```text
save confirmed
```

Draft resets to server answer.

## Server answer differs

Adopt current server answer.

Keep the Student's pending draft only when doing so is safe and intentional,
equivalent to current Homework recovery:

- draft may remain dirty against newly adopted server answer;
- status returns to editable idle;
- user can review and explicitly Save again.

Do not automatically replay.

---

# 28. Uncertain Reconciliation Finds Terminal Attempt

If completed Start replay returns terminal:

- execution controller adopts terminal Attempt;
- clear uncertain save operation;
- discard unsaved local mutation authority;
- render terminal read-only state.

Do not attempt another answer PUT.

The terminal Attempt's saved answers are authoritative.

---

# 29. Definite Non-File Save Errors

Stable Blitz errors include:

```text
blitz_time_expired
blitz_not_active
attempt_not_editable
resource_not_found
business_conflict
validation_failed
selection_limit_exceeded
```

Mapping:

## `selection_limit_exceeded`

Question-level failure.

Adopt no local server answer change.

Student may correct draft while Attempt remains active.

## `blitz_time_expired`

Immediately revoke local edit authority and run safe current-Attempt replay.

## `blitz_not_active`

Reconcile current Attempt + Blitz detail/list.

## `attempt_not_editable`

Reconcile current Attempt.

## `resource_not_found`

Reconcile; if file/Question/Attempt graph disappears, do not leak details.

## `business_conflict`

Reconcile current Attempt.

## `validation_failed`

Show safe Question-level validation/contract failure as current Stage 7
presentation does.

No message parsing.

---

# 30. Local Countdown Expired Gate

FE-004 countdown zero immediately establishes:

```text
localTimeExpired = true
```

in execution authority before network reconciliation.

While true:

- all non-file fields become read-only;
- Save/Clear/Discard-to-server controls cannot issue mutation;
- file choose/upload disabled;
- Submit disabled;
- uncertain Check/reconciliation actions remain available;
- file Open/Save of already persisted current file may remain available if
  ownership is still authoritative.

Do not restore mutation authority from old countdown state.

Only a newer authoritative in-progress Attempt publication with positive
server-anchored timing may clear the local expired gate.

---

# 31. File Answer UX Reuse

Reuse:

```text
StudentFileAnswerState
StudentFileQuestionAnswerState
StudentSubmissionFilePicker
StudentSubmissionUploadFile
StudentFileAnswerEditor
StudentSubmissionTransferState
protectedLearningMaterialTransferProvider
localFileActionsProvider
```

Do not create a second file picker or transfer implementation.

Blitz needs subtype-specific orchestration because parent Attempt authority is
different.

---

# 32. Blitz File Answer Controller

Create:

```text
StudentBlitzFileAnswerController
```

keyed by:

```text
StudentBlitzExecutionTarget
```

It mirrors the proven Stage 7 responsibilities:

- choose file;
- local extension/size validation;
- upload;
- replace;
- uncertain state;
- reconcile;
- terminal synchronization.

Use shared answer repository upload method.

---

# 33. File Selection Rules

Use Question-safe backend-provided:

```text
allowedExtensions
maxSizeBytes
```

Validate before upload.

Do not hardcode only platform 15 MiB when the Question `answerUi` contains a
smaller effective Institution cap.

Do not trust filename extension alone for server acceptance; local check is UX
only.

Server remains authoritative.

---

# 34. File Upload Success

On strict success:

1. validate response against selected file and Question;
2. accept mutation through execution controller;
3. new server file becomes current;
4. clear selected local replacement;
5. update editor state;
6. no full Attempt replay required.

Do not retain the old file as current in frontend after confirmed replacement.

Backend preserves stable File ID according to contract; frontend accepts
authoritative returned file metadata.

---

# 35. File Upload Uncertain

Do not retry automatically.

UI:

```text
We could not confirm whether this file was uploaded.
Check current attempt.
```

Keep local selected file reference only while:

- route/session still owns it;
- file source remains available;
- Question remains active.

No automatic re-upload.

---

# 36. File Uncertain Reconciliation

Use the exact completed immutable Start request replay.

If Attempt remains in progress:

1. adopt current full Attempt;
2. inspect server current file for that Question;
3. do **not** claim the selected bytes committed merely because metadata happens
   to match;
4. retain selected local file as a ready candidate when still valid;
5. show current server file truth;
6. Student explicitly chooses Upload again if needed.

This preserves the Stage 7 security rule:

> metadata cannot prove selected local bytes committed.

If replay returns terminal:

- adopt terminal;
- discard selected file/pending upload authority;
- server current file metadata remains read-only.

---

# 37. File Source Unavailable

If selected local source disappears:

```text
StudentSubmissionSourceUnavailable
```

show:

```text
The selected file is no longer available.
Choose the file again.
```

No server mutation assumed.

No unsafe retry.

---

# 38. Current Submitted File Transfer

Create:

```text
StudentBlitzSubmissionTransferController
```

or extract a shared target-neutral controller only if the change remains narrow.

It may reuse:

```text
StudentSubmissionTransferState
protectedLearningMaterialTransferProvider
localFileActionsProvider
```

It can Open/Save As only a file that is currently present in the authoritative
Blitz Attempt answer state.

Do not allow transfer of:

- stale old replacement metadata;
- selected-but-not-uploaded local file through protected endpoint;
- file from another Question/Attempt;
- file while an uncertain upload could invalidate current authority.

---

# 39. File Transfer 404

On:

```text
404 resource_not_found
```

perform safe Attempt replay reconciliation.

Do not keep a locally-authorized stale file link.

Show privacy-safe:

```text
The submitted file is no longer available.
```

No raw storage details.

---

# 40. Shared Presentation Labels

Current reusable widgets import Homework-named numeric/time formatters.

Where necessary, extract only pure Student-common formatting:

```text
formatStudentAssessmentPoints
formatStudentSubmissionBytes
formatStudentInstitutionInstant
studentQuestionTypeLabel
```

Preserve Homework output.

Do not fork the answer/file editor widgets only to rename imports.

---

# 41. Route Operation Gate

Create a Blitz route-session gate equivalent to:

```text
StudentBlitzExecutionOperationGate
```

keyed by:

```text
StudentBlitzExecutionTarget
```

Minimum states:

```text
idle
submitting
submitUncertain
terminalReconciliation
```

Answer/file controllers require an appropriate idle execution gate before
starting new writes.

Submit claims the gate.

While Submit is:

```text
submitting
uncertain
checking
```

no answer/file mutation begins.

Do not create a global Student mutation lock.

---

# 42. Why Submit Needs a Gate

Submit freezes execution.

Without a local gate, the client could issue:

```text
answer PUT
```

while:

```text
Submit POST
```

is in flight.

Backend serializes correctly, but frontend would create avoidable confusing
outcomes.

Required current-client UX:

```text
Submit starts
-> answer/file new writes disabled
-> pending local operations must already be resolved
```

---

# 43. Submit Readiness

Create:

```text
StudentBlitzSubmitReadiness
StudentBlitzSubmitReadyToken
```

patterned on current Homework readiness but sourced from:

```text
StudentBlitzExecutionController
StudentBlitzAnswerEditorController
StudentBlitzFileAnswerController
StudentBlitzExecutionOperationGate
countdown/local expiry state
```

---

# 44. Submit Blockers

Block Submit when any applies:

```text
attempt not in_progress
execution publication unavailable/stale
local countdown expired/reconciling
non-file unsaved changes
non-file save in progress
non-file save uncertain
file selected but not uploaded/discarded
file picker/upload in progress
file upload uncertain
route operation not idle
session/target mismatch
editor/file Question sets do not align with current Attempt
```

Do not block merely because:

```text
one or more Questions are unanswered
```

Unanswered is valid.

---

# 45. Confirmed Answer Count Snapshot

Readiness computes:

```text
questionCount
confirmedAnsweredCount
unansweredCount
```

from authoritative editor/file server state.

This snapshot is presentation only.

Do not write zero answers.

Do not score.

---

# 46. Submit Button

Show only for active current Attempt.

Label:

```text
Submit Blitz
```

For Attempt #2 the same label is acceptable.

Do not show:

```text
Finish and score
```

or any score promise.

Disabled/blocker UI should explain unresolved local mutations when applicable.

---

# 47. Submit Confirmation

Require explicit confirmation.

Title:

```text
Submit Blitz?
```

Content includes:

```text
Answered: X of Y
Unanswered: Z

After submission, this attempt cannot be edited.
Unanswered Questions will remain unanswered.
```

If:

```text
unansweredCount > 0
```

show a visible warning:

```text
You still have Z unanswered Questions.
```

But keep Confirm enabled.

Buttons:

```text
Cancel
Submit
```

---

# 48. Submit Ready Token

Capture at dialog open:

```text
sessionKey
execution target
publication token
Attempt identity
answer editor state identity
file state identity
answer counts
local expiry generation/anchor
```

After dialog returns, Submit occurs only if current readiness token still matches.

If anything changed while confirmation was open:

- do not Submit;
- close dialog;
- ask Student to review current Attempt.

This prevents stale confirmation.

---

# 49. Blitz Submit Domain

Create:

```text
StudentBlitzSubmitResult
```

containing:

```text
StudentBlitzAttempt attempt
```

No score.

Create strict:

```text
StudentBlitzSubmitDto
```

---

# 50. Blitz Submit DTO — Fresh Success vs Completed Replay

Require exact envelope:

```text
data
message
```

Require:

```text
message == "Blitz attempt submitted successfully."
```

Parse `data` using the strict FE-004:

```text
StudentBlitzAttemptDto
```

Always require:

```text
attempt.id == expectedAttemptId
attempt.assessmentId == expectedBlitzId
attempt.finalizationReason = student_submit
attempt.submittedAt != null
attempt.finalizedAt == submittedAt
attempt.finalizedAt < deadlineAt
timing.remainingSeconds = 0
```

The Submit transport/parser must also receive one explicit expected-response
context owned by the Submit controller:

```text
fresh
completedReplay
```

This is frontend operation context, not a request/API field.

## 50.1 Fresh Submit success

For the first logical Submit POST:

```text
expectation = fresh
```

require exactly:

```text
attempt.status = submitted
```

Stage 8 fresh Submit does not itself produce:

```text
waiting_for_teacher_review
checked
```

## 50.2 Same-key completed replay

For explicit:

```text
Retry Submit
```

using the retained same Idempotency-Key:

```text
expectation = completedReplay
```

accept current status:

```text
submitted
waiting_for_teacher_review
checked
```

but only with the same original:

```text
finalizationReason = student_submit
submittedAt == finalizedAt < deadlineAt
remainingSeconds = 0
```

This allows a completed Submit to be replayed after a later result/checking stage
without implementing Stage 9 UI.

Never accept as successful Submit replay:

```text
in_progress
timed_out_finalized
submitted + task_closed_auto_finalize
waiting_for_teacher_review/checked with timeout_auto_submit
waiting_for_teacher_review/checked with task_closed_auto_finalize
```

Those remain terminal/current-state outcomes to reconcile through the existing
Attempt authority paths, not successful Submit DTO results.

Malformed or context-incompatible `2xx` remains outcome-uncertain.

---

# 51. Submit Repository Method

Create/reuse a small enum/value equivalent to:

```text
StudentBlitzSubmitResponseExpectation
```

with exactly:

```text
fresh
completedReplay
```

Extend:

```text
StudentBlitzAttemptRepository
```

with:

```dart
Future<StudentBlitzSubmitResult> submitAttempt(
  String attemptId,
  String expectedBlitzId,
  String idempotencyKey, {
  required StudentBlitzSubmitResponseExpectation expectation,
});
```

The expectation affects only successful response validation. It is **not** sent
to the backend and does not alter the Submit request fingerprint.

Use exact shared Submit endpoint:

```text
POST /student/attempts/{attemptId}/submit
```

No separate Blitz URL.

---

# 52. Submit HTTP Construction

Call:

```dart
dio.post<Object?>(
  '/student/attempts/${Uri.encodeComponent(attemptId)}/submit',
  data: const <String, Object?>{},
  options: Options(
    followRedirects: false,
    headers: {
      'Idempotency-Key': idempotencyKey,
    },
  ),
)
```

No query.

Require:

```text
200
```

Strict DTO.

No automatic Dio retry.

---

# 53. Submit Controller

Create:

```text
StudentBlitzSubmitController
StudentBlitzSubmitState
```

family keyed by:

```text
StudentBlitzExecutionTarget
```

Statuses:

```text
idle
submitting
uncertain
checking
completed
reconciledTerminal
failure
```

Private:

```text
_pendingSubmitIdempotencyKey
logicalGeneration
resolutionGeneration
```

---

# 54. Submit Key Lifetime and Response Expectation

## New confirmed Submit

Generate one secure UUID using existing:

```text
IdempotencyKeyGenerator
```

only after:

- current readiness token validates;
- confirmation accepted;
- route gate successfully claimed.

Send with:

```text
expectation = fresh
```

## Confirmed Submit success

Clear key.

## Deterministic non-terminal rejection

Clear key.

## Uncertain outcome

Keep the same key.

## Same-key Retry

Reuse the exact same key and send with:

```text
expectation = completedReplay
```

A retry may be the request that actually performs the first successful server
transition if the earlier uncertain request never committed. That is still safe:
the resulting normal `submitted + student_submit` resource is accepted by the
`completedReplay` expectation.

If the earlier request committed and the Attempt advanced later, the same
expectation also accepts valid `waiting_for_teacher_review|checked` current
projection with original `student_submit` lineage.

## Route/session loss

Clear the key.

Do not expose key or response expectation to Widgets.

---

# 55. Submit Uncertain Classification

Treat as uncertain:

```text
connection
timeout
cancelled
invalidResponse
unknown
statusCode == null
statusCode >= 500
```

State:

```text
uncertain
```

UI:

```text
We could not confirm whether the Blitz was submitted.
```

Actions:

```text
Retry Submit
Check current attempt
```

No new-key Submit.

---

# 56. Retry Submit

Explicit:

```text
Retry Submit
```

uses the same pending Submit key and calls the Submit repository with:

```text
expectation = completedReplay
```

No new confirmation is required for the same unresolved logical Submit unless
current execution authority changed.

A successful `200` retry may therefore return:

```text
submitted
waiting_for_teacher_review
checked
```

only when Section 50 proves the original `student_submit` lineage.

If current Attempt is already locally terminal:

- no Retry.

---

# 57. Check Current Attempt During Submit Uncertainty

Use:

```text
StudentBlitzExecutionController.refreshCurrentAttempt()
```

which replays the exact completed immutable Start request.

Do **not** use a new Start key.

Possible result:

## Still `in_progress`

Submit outcome remains uncertain.

Keep:

```text
pending Submit key
uncertain state
```

Student may use:

```text
Retry Submit
```

Do not re-enable answers while Submit remains logically uncertain.

## Terminal

Adopt terminal Attempt and resolve the execution session as terminal.

See Sections 58–61.

---

# 58. Check Finds `student_submit`

If safe Start replay returns:

```text
status = submitted
reason = student_submit
```

then execution is definitively terminal.

It does **not** prove which Submit key/device won.

User-level outcome is nevertheless:

```text
This Blitz attempt is submitted.
```

Required:

- clear pending Submit key;
- mark `reconciledTerminal`;
- release route gate;
- do not claim:
  ```text
  "Your retry was confirmed"
  ```
- refresh detail/list.

No further Submit is needed.

---

# 59. Check Finds Timeout

If:

```text
timed_out_finalized
timeout_auto_submit
```

then:

- clear pending Submit key;
- `reconciledTerminal`;
- terminal reason:
  ```text
  time expired
  ```
- no Submit success feedback;
- refresh detail/list.

Do not rewrite it to Student Submit.

---

# 60. Check Finds Teacher Close

If:

```text
submitted
task_closed_auto_finalize
```

then:

- clear pending Submit key;
- terminal:
  ```text
  Blitz was closed and this attempt was finalized.
  ```
- no Submit success claim;
- refresh detail/list.

---

# 61. Waiting / Checked Terminal

If Start replay returns:

```text
waiting_for_teacher_review
checked
```

accept as terminal under FE-004's general terminal invariants.

For **Submit same-key replay success**, the narrower Section 50 rule applies:

```text
waiting_for_teacher_review|checked
+
finalization_reason = student_submit
+
submittedAt == finalizedAt
```

This is enough to confirm the historical Student Submit while still rendering
only the terminal/read-only Stage 8 surface.

If the later-stage Attempt instead carries timeout/Teacher-close finalization
reason, it is not a successful Submit replay; preserve that terminal reason.

Do not show score/checking result in Stage 8.

---

# 62. Submit Success Adoption

On a context-valid strict Submit `200`:

1. require current logical operation ownership;
2. accept the full returned terminal Attempt into execution controller;
3. clear pending Submit key;
4. publish:
   ```text
   completed
   ```
5. release route gate;
6. clear/retire answer/file mutation authority;
7. refresh:
   ```text
   Student Blitz detail
   Active Blitz list
   ```
8. remain on the same Blitz route showing terminal summary.

Feedback:

## Fresh success or replay returning `submitted`

```text
Blitz submitted successfully.
```

## Completed same-key replay returning `waiting_for_teacher_review|checked`

Use non-overclaiming confirmation:

```text
Blitz submission confirmed.
```

The later status is adopted as current terminal/read-only state.

Do not claim that FE-005 performed Teacher review/checking.

Do not navigate to results.

---

# 63. Late Submit — `blitz_time_expired`

Backend late Submit does not create a successful Submit idempotency result.

On:

```text
409 blitz_time_expired
```

required:

1. clear pending Submit key;
2. do not show Submit failure retry as normal editable state;
3. claim terminal reconciliation gate;
4. replay the exact completed immutable Start request to load the same Attempt;
5. expect timeout-finalized or newer terminal state;
6. accept terminal;
7. refresh detail/list.

If replay cannot be completed due network:

```text
Time has expired.
Reconnect and refresh to confirm the final attempt state.
```

Keep local execution non-editable.

Never generate a new Submit key automatically.

---

# 64. Submit `attempt_not_editable`

On:

```text
409 attempt_not_editable
```

the Attempt is no longer editable.

Required:

- clear pending Submit key;
- replay the exact completed immutable Start request;
- adopt terminal if available;
- do not re-enable answer controls from stale local state.

If replay says still in-progress unexpectedly:

```text
business/current-state inconsistency
```

keep execution read-only and require Refresh.

Do not blindly allow another Submit.

---

# 65. Submit `blitz_not_active`

On:

```text
409 blitz_not_active
```

reconcile:

```text
Attempt via exact completed immutable Start request replay
Blitz detail
Active Blitz list
```

Do not assume Teacher Close reason until Attempt says so.

Keep writes disabled during reconciliation.

---

# 66. Submit `idempotency_key_reused`

This indicates unsafe/colliding request identity.

Clear pending Submit key.

Do not generate/send a new key automatically.

Show:

```text
The Blitz could not be submitted safely.
Check the current attempt before trying again.
```

Run safe Start replay.

If Attempt remains in-progress and current state becomes trustworthy, Student may
explicitly initiate a **new** Submit later, which gets a new key.

---

# 67. Submit `resource_not_found`

Privacy-safe terminal/unavailable recovery:

- clear pending key;
- attempt safe Start replay if still authorized by route-session key;
- refresh detail/list;
- if unavailable, clear private execution state.

Do not leak which resource disappeared.

---

# 68. Submit Validation Failure

Unexpected:

```text
422 validation_failed
```

is a client/server contract issue.

Clear pending key.

Keep execution safe/non-mutating until current Attempt is replayed/refreshed.

Show:

```text
The submission request could not be validated.
Refresh the current Blitz and try again if it remains editable.
```

No field form.

---

# 69. Answer/File Mutation During Submit

Once Submit gate is claimed:

- no new answer edit Save;
- no file choose/upload;
- no answer clear;
- no uncertain answer/file reconciliation operation begins independently.

Existing unsaved/uncertain/in-progress operations prevent Submit readiness before
claim.

No answer PUT can begin after readiness token is captured and Submit gate
successfully claimed.

---

# 70. Terminal Execution Synchronization

When execution controller adopts terminal Attempt:

notify/synchronize:

```text
StudentBlitzAnswerEditorController
StudentBlitzFileAnswerController
StudentBlitzSubmissionTransferController
StudentBlitzSubmitController
```

Required:

- editors read-only;
- local dirty drafts discarded from authoritative submit eligibility;
- selected local files discarded;
- uncertain answer/file operations retired;
- persisted saved answers/files remain visible read-only;
- protected current file Open/Save may remain available when authorization stays
  valid.

No further server answer mutation.

---

# 71. Terminal Summary

Create:

```text
StudentBlitzFinalizationSummary
```

or extend a shared execution-finalization presentation component.

Display:

```text
Attempt number
Finalized state
Finalization reason
Started
Deadline
Finalized at
Answered X of Y
Unanswered Z
```

No points awarded.

No score.

No checking status.

---

# 72. Terminal Copy — Student Submit

For:

```text
student_submit
```

show:

```text
Submitted
Your Blitz attempt has been submitted.
```

If Submit controller strict success caused it:

```text
Blitz submitted successfully.
```

If reconciled from safe Start replay:

```text
This Blitz attempt is already submitted.
```

Do not overclaim which device/key caused it.

---

# 73. Terminal Copy — Timeout

For:

```text
timeout_auto_submit
```

show:

```text
Time expired
The server finalized the answers that were saved before the deadline.
Unanswered Questions remain unanswered.
```

Do not say:

```text
All unanswered answers were marked wrong
```

Stage 9 decides scoring.

---

# 74. Terminal Copy — Teacher Close

For:

```text
task_closed_auto_finalize
```

show:

```text
Blitz closed
The Teacher closed the Blitz.
The answers saved before finalization were preserved.
```

No score.

---

# 75. Terminal Copy — Waiting / Checked

If persistence status is:

```text
waiting_for_teacher_review
```

show:

```text
Finalized
Some answers may require Teacher review.
```

If:

```text
checked
```

show:

```text
Finalized
```

Do not show score/checking details in Stage 8.

---

# 76. Answered Count in Terminal State

Compute from authoritative terminal:

```text
attempt.answers
```

Count unique persisted answers only.

Unanswered:

```text
questions.length - answers.length
```

Do not count:

- dirty local draft;
- selected local file not uploaded;
- uncertain mutation not confirmed.

No score interpretation.

---

# 77. Answer Read-Only Presentation After Terminal

For non-file:

reuse safe answer read presentation if current Stage 7 component exists:

```text
StudentAttemptAnswerReadView
```

or equivalent.

For file:

reuse `StudentFileAnswerEditor` in:

```text
isTerminal = true
```

mode, preserving Open/Save controls for current server file when valid.

Do not show answer editing controls.

---

# 78. Execution Shell Question Rendering

While active:

## Non-file

Use:

```text
StudentQuestionAnswerEditor
```

with Blitz controller callbacks.

## File

Use:

```text
StudentFileAnswerEditor
```

with Blitz file/transfer callbacks.

Do not render separate `StudentQuestionReadView` underneath an editor for the same
Question.

Every Question appears once.

---

# 79. Save Status Copy

Reuse existing save statuses:

```text
Saving…
Saved
Unsaved changes
Save result unconfirmed
Could not save answer
```

Do not rename based on Blitz unless needed for context.

Ensure old Homework-specific recovery label:

```text
Reload attempt
```

may be generalized to:

```text
Check current attempt
```

through a shared presentation parameter/label.

If shared widget is changed, preserve Homework wording/behavior where tests
require it.

---

# 80. Protected File Transfer Does Not Require Editability

A terminal/current authoritative submitted file may still be:

```text
Open
Save As…
```

provided:

- file metadata belongs to current authoritative Attempt;
- transfer controller owns current session/target.

Do not disable download solely because Attempt is terminal.

Backend authorization allows own active/closed/archived Blitz submission file.

---

# 81. Local Leave Guard

FE-004 already warns that the timer continues.

FE-005 extends leave guard.

Before leaving active execution, inspect:

```text
Submit submitting
Submit uncertain
typed answer uncertain
typed answer dirty
typed answer saving
file selected
file upload uncertain
file uploading/selecting
terminal reconciliation active
```

---

# 82. Leave While Submit Is In Progress

If Submit state:

```text
submitting
```

do not allow Leave.

Dialog:

```text
Submission is in progress.
Wait until the result is known.
```

No Leave action.

---

# 83. Leave While Submit Is Uncertain

Allow explicit Leave only with warning:

```text
The submission result is unconfirmed.
Leaving will discard this local retry key.
When you return, the app will reload the current server state.
If this attempt is still in progress, Resume will be available.
If it was finalized while you were away, it may no longer be resumable.
```

The warning must not promise that Resume will exist.

If Student leaves:

- clear pending Submit key;
- clear local execution route-session state;
- do not send another mutation.

Server remains authoritative.

Leaving also means FE-005 may no longer possess the full terminal Attempt
resource needed for the rich terminal summary. Do not promise that summary on
return unless an authoritative full terminal Attempt is later obtained through
an already-approved existing flow.

---

# 84. Leave With Dirty/Selected Local Work

Warn:

```text
You have unsaved answer changes.
Leaving discards only the unsaved local changes.
Your server timer continues.
```

For selected but not-uploaded file:

```text
The selected local file has not been uploaded.
```

Student chooses:

```text
Stay
Leave
```

No API mutation on Leave.

---

# 85. Leave With Uncertain Answer/File Mutation

Warn:

```text
A save result is still unconfirmed.
Leaving discards the local reconciliation state.
When you return, the app will reload the current server state.
If this attempt is still in progress, Resume will be available.
If it was finalized while you were away, it may no longer be resumable.
```

Do not claim the server mutation failed.

Do not promise a full terminal summary after return merely from the pre-Start
detail. That detail can prove current usage/resumability but does not replace an
authoritative full terminal Attempt resource.

Clear local pending operation only after confirmed Leave.

---

# 86. Return After Leaving — Conditional Resume

When Student returns, first reload the normal Student Blitz detail/current
lifecycle authority. Do not assume the Attempt remained resumable.

## 86.1 Attempt still in progress

If fresh detail confirms:

```text
attempts.inProgressAttemptId != null
```

then:

1. show `Resume Blitz`;
2. explicit Resume targets that exact confirmed Attempt ID;
3. successful Resume returns the authoritative full Attempt;
4. establish a new route-session completed immutable Start request containing
   the exact Resume intent, exact confirmed Attempt ID and exact successful key;
5. initialize editor/file state from the returned server Attempt;
6. do not restore discarded local dirty/uncertain state.

## 86.2 No resumable Attempt

If fresh detail has:

```text
attempts.inProgressAttemptId = null
```

then:

- do **not** show Resume merely because an Attempt existed before Leave;
- do **not** generate a new normal/replacement Start key as recovery;
- present the authoritative current detail/lifecycle/attempt-usage state;
- remain read-only unless the normal Start/replacement rules independently make
  a new explicit action legal;
- do not infer timeout vs Submit vs Teacher Close reason from
  `inProgressAttemptId = null` alone.

The Attempt may have become terminal while the Student was away.

## 86.3 Terminal summary limitation

The rich FE-005 terminal summary requires an authoritative **full terminal
Attempt resource**.

After Leave, local route-session Attempt/replay state was intentionally
discarded. The pre-Start detail alone is insufficient to reconstruct:

```text
finalization_reason
finalized_at
submitted_at
saved terminal answer set
```

Therefore:

- show the rich terminal summary only if an authoritative full terminal Attempt
  is obtained through an existing approved flow;
- otherwise show only the safe current detail/lifecycle/non-resumable state
  available from the backend;
- do not fabricate terminal reason/timestamps/answers;
- do not add a new historical Attempt GET for F17.

No offline draft persistence.

---

# 87. Local Countdown and Dirty Draft at Zero

When FE-004 countdown reaches zero:

- immediately disable editing;
- do not auto-save dirty local drafts;
- do not auto-upload selected file;
- do not auto-Submit;
- begin current Attempt/detail reconciliation.

Warn:

```text
Time expired before these local changes were confirmed.
Only answers saved by the server before the deadline can be included.
```

Do not imply dirty draft is preserved server-side.

---

# 88. Save Race With Countdown Zero

Possible:

## PUT commits before deadline

Strict success may arrive after local display hit zero.

If current operation ownership is still valid:

- accept server success;
- then reconcile terminal state.

The saved answer may legitimately be included.

## Server rejects due deadline

`blitz_time_expired`.

Do not accept dirty draft.

Reconcile terminal.

Local zero alone does not decide which race won.

---

# 89. File Upload Race With Countdown Zero

Same principle.

If backend confirms file upload `200`:

- accept authoritative file;
- reconcile terminal.

If backend returns timeout:

- do not treat upload as saved;
- selected file remains local only until reconciliation/terminal cleanup.

Backend is authority.

---

# 90. Submit Race With Countdown Zero

If Student confirmed Submit just before local zero:

- allow already-started Submit operation to resolve;
- do not cancel the HTTP request merely because UI timer reaches zero.

Backend decides:

```text
student_submit
or
timeout_auto_submit
```

No new Submit may begin after local zero.

---

# 91. Execution Reconciliation at Zero vs Existing Mutation

Do not start a competing Start replay while an answer/file/Submit request is
still actively in flight.

Sequence:

1. local zero sets mutation gate non-editable;
2. let current in-flight request complete/classify;
3. after it resolves or becomes uncertain, run the appropriate safe
   reconciliation path.

Avoid two concurrent authority-recovery operations in the same route session.

---

# 92. Error Codes

Add/reuse exact `ApiErrorCodes` as needed:

```text
blitzTimeExpired = 'blitz_time_expired'
blitzNotActive = 'blitz_not_active'
attemptNotEditable = 'attempt_not_editable'
selectionLimitExceeded = 'selection_limit_exceeded'
fileUploadFailed = 'file_upload_failed'
unsupportedFileType = 'unsupported_file_type'
fileTooLarge = 'file_too_large'
resourceNotFound = 'resource_not_found'
businessConflict = 'business_conflict'
validationFailed = 'validation_failed'
idempotencyKeyReused = 'idempotency_key_reused'
```

Reuse existing constants where present.

Do not duplicate.

---

# 93. No `submission_locked`

Do not add or branch on:

```text
submission_locked
```

Stage 8 backend contract intentionally uses:

```text
blitz_time_expired
attempt_not_editable
```

for terminal new Submit requests.

---

# 94. No Homework Deadline Error for Blitz

Do not branch Blitz execution on:

```text
deadline_passed
```

The stable Blitz execution code is:

```text
blitz_time_expired
```

Homework remains unchanged.

---

# 95. No Score / Checking Leakage

Search all new Student Blitz JSON/domain/presentation.

Do not parse/display:

```text
checking_status
awarded_points
feedback
checked_by
checked_at
earned_points
normalized_score
scoring_completed_at
official score
Topic understanding category
```

Even if later backend fixtures contain such fields, strict Stage 8 response DTO
must reject unexpected keys where applicable.

---

# 96. No Answer-Key Leakage

Continue relying on safe `StudentQuestionDto`.

Do not expose:

```text
is_correct
correct_value
accepted_answers
correct ordering
matching answer key
```

No Teacher Question resource reuse in Student execution.

---

# 97. Responsive Execution UI

Support:

```text
desktop
mobile
```

Use existing Student answer editor responsiveness.

For mobile:

- no horizontal overflow;
- file controls wrap;
- matching editor remains usable;
- countdown visible;
- Submit controls reachable after Questions;
- confirmation dialogs scroll.

Do not add mobile-only business behavior.

---

# 98. Accessibility

Required:

- Question cards have semantic headings;
- Save states use live regions without excessive announcements;
- upload progress semantic;
- countdown does not announce every second;
- Submit warning not color-only;
- terminal reason semantic heading;
- buttons have clear labels;
- file Open/Save distinguish Question context;
- validation text visible.

No new accessibility framework.

---

# 99. Expected File Scope

Exact filenames may follow FE-004/current project conventions.

## Create likely

```text
frontend/lib/features/student/domain/student_blitz_execution_target.dart
frontend/lib/features/student/domain/student_blitz_submit.dart
frontend/lib/features/student/domain/student_attempt_answer_repository.dart

frontend/lib/features/student/data/student_attempt_answer_remote_data_source.dart
frontend/lib/features/student/data/student_attempt_answer_repository_impl.dart
frontend/lib/features/student/data/dto/student_blitz_submit_dto.dart

frontend/lib/features/student/application/student_blitz_execution_state.dart
frontend/lib/features/student/application/student_blitz_execution_controller.dart
frontend/lib/features/student/application/student_blitz_answer_editor_controller.dart
frontend/lib/features/student/application/student_blitz_file_answer_controller.dart
frontend/lib/features/student/application/student_blitz_submission_transfer_controller.dart
frontend/lib/features/student/application/student_blitz_execution_operation_gate.dart
frontend/lib/features/student/application/student_blitz_submit_readiness.dart
frontend/lib/features/student/application/student_blitz_submit_state.dart
frontend/lib/features/student/application/student_blitz_submit_controller.dart

frontend/lib/features/student/presentation/student_blitz_finalization_summary.dart
```

## Modify likely

```text
frontend/lib/features/student/domain/student_blitz_attempt_repository.dart
frontend/lib/features/student/data/student_blitz_attempt_remote_data_source.dart
frontend/lib/features/student/data/student_blitz_attempt_repository_impl.dart

frontend/lib/features/student/application/student_blitz_attempt_start_controller.dart
frontend/lib/features/student/application/student_blitz_attempt_start_state.dart

frontend/lib/features/student/presentation/student_blitz_detail_screen.dart
frontend/lib/features/student/presentation/student_blitz_attempt_shell.dart
frontend/lib/features/student/presentation/student_question_answer_editor.dart
frontend/lib/features/student/presentation/student_file_answer_editor.dart

frontend/lib/features/student/application/student_attempt_answer_editor_controller.dart
frontend/lib/features/student/application/student_file_answer_controller.dart
frontend/lib/features/student/data/student_homework_attempt_remote_data_source.dart
frontend/lib/features/student/data/student_homework_attempt_repository_impl.dart
frontend/lib/features/student/domain/student_homework_attempt_repository.dart

frontend/lib/core/network/api_error_codes.dart
```

Only narrow Stage 7 changes needed for shared answer transport/presentation reuse
are allowed.

No router change is expected.

Do not modify:

```text
backend/
Teacher Stage 8 frontend
platform files
pubspec.yaml
pubspec.lock
integration_test/
docs/
tasks/
```

---

# 100. Shared Answer Transport Tests

Create:

```text
student_attempt_answer_remote_data_source_test.dart
```

or migrate existing Homework answer transport tests.

Verify:

- exact PUT typed route/body;
- exact multipart file route;
- upload progress;
- success status;
- strict response parser;
- clear response;
- invalid Question/type rejected before/at parser;
- no auto retry.

Run Homework answer transport regression after extraction.

---

# 101. Execution Controller Tests

Create:

```text
student_blitz_execution_controller_test.dart
```

Cover:

- accepts successful FE-004 Attempt + immutable request object atomically;
- active publication token;
- terminal publication;
- completed replay preserves exact `intent + attemptId? + idempotencyKey`;
- normal Start replay sends `start_normal` + same key;
- Resume #1 replay sends `resume` + exact #1 Attempt ID + same key;
- Resume #2 replay sends `resume` + exact #2 Attempt ID + same key;
- replacement Start replay sends `start_replacement` + same key;
- replay never generates new key;
- replay never recomputes/switches intent from current Attempt/detail;
- replay must return same Attempt ID;
- replay active adopts full current answers/timing;
- replay terminal adopts terminal;
- wrong Attempt ID rejected;
- session/route stale replay ignored;
- answer mutation replace;
- answer clear removal;
- stale publication mutation not applied;
- local-time-expired gate;
- newer positive authoritative Attempt can re-anchor only valid current attempt.

---

# 102. Non-File Editor Tests

Create:

```text
student_blitz_answer_editor_controller_test.dart
```

Cover:

- all eight non-file Question types initialize;
- dirty draft;
- clear rules;
- Save success;
- publication adoption;
- selection limit;
- timeout error;
- task non-active;
- attempt not editable;
- uncertain state;
- Check current uses exact completed Start request body + key;
- uncertain match confirms;
- uncertain mismatch adopts server and keeps reviewable dirty draft;
- terminal replay clears edit authority;
- local countdown zero disables Save;
- session/Attempt change clears draft.

---

# 103. File Controller Tests

Create:

```text
student_blitz_file_answer_controller_test.dart
```

Cover:

- choose file;
- extension/size validation;
- upload progress;
- upload success;
- replace current file;
- source unavailable;
- file upload failed retains retry candidate;
- uncertain upload;
- Check current uses exact completed Start request body + key;
- metadata match does not falsely prove bytes committed;
- terminal reconciliation;
- local zero disables upload;
- stale picker completion ignored;
- session/Attempt change clears selected file.

---

# 104. File Transfer Tests

Create:

```text
student_blitz_submission_transfer_controller_test.dart
```

Cover:

- current authoritative file Open;
- Save As;
- progress;
- size/extension response integrity;
- 404 causes current Attempt reconciliation;
- stale file no transfer;
- selected local file cannot use protected endpoint;
- terminal file remains transferable;
- session/Attempt stale completion ignored.

Run existing Homework transfer regression if shared code changed.

---

# 105. Submit Readiness Tests

Create:

```text
student_blitz_submit_readiness_test.dart
```

Cover each blocker:

- Attempt terminal;
- publication unavailable;
- countdown locally expired;
- dirty non-file;
- non-file save in flight;
- uncertain non-file;
- selected file pending;
- upload in progress;
- uncertain upload;
- operation gate busy;
- Question/editor mismatch.

Positive:

```text
0 of N answered -> ready
some answered -> ready
all answered -> ready
```

Unanswered never blocks.

---

# 106. Submit DTO / Data Source Tests

Create:

```text
student_blitz_submit_dto_test.dart
student_blitz_submit_data_source_test.dart
```

Cover:

- exact success envelope/message;
- expected Attempt/Blitz IDs;
- fresh expectation accepts `submitted + student_submit`;
- fresh expectation rejects `waiting_for_teacher_review|checked`;
- completedReplay expectation accepts `submitted + student_submit`;
- completedReplay expectation accepts `waiting_for_teacher_review + student_submit`;
- completedReplay expectation accepts `checked + student_submit`;
- later-stage replay requires `submittedAt == finalizedAt < deadlineAt` and remaining zero;
- timeout finalization cannot parse as successful Submit replay;
- task-close finalization cannot parse as successful Submit replay;
- waiting/checked with timeout/close finalization reason rejected as successful Submit replay;
- in-progress `200` rejected;
- malformed/context-incompatible 200 -> invalidResponse/uncertain;
- expectation is not sent in request JSON/query/header;
- exact POST body/header;
- no query;
- canonical UUID validation.

---

# 107. Submit Controller Tests

Create:

```text
student_blitz_submit_controller_test.dart
```

Cover:

- confirmed readiness token;
- stale confirmation rejected;
- one key per logical Submit;
- fresh success uses `expectation=fresh`;
- unanswered fresh success;
- uncertain;
- same-key Retry reuses key with `expectation=completedReplay`;
- Retry normal `submitted + student_submit` success;
- Retry later `waiting_for_teacher_review + student_submit` success;
- Retry later `checked + student_submit` success;
- Retry later-stage timeout/close lineage does not become Submit success;
- Check current still in-progress remains uncertain;
- Check current student_submit -> reconciled terminal;
- timeout -> reconciled terminal;
- task close -> reconciled terminal;
- waiting/checked terminal;
- `blitz_time_expired`;
- `attempt_not_editable`;
- `blitz_not_active`;
- `idempotency_key_reused`;
- session failures;
- old session/Attempt completion ignored;
- gate release;
- no answer/file mutation can begin during Submit.

---

# 108. Terminal Summary Tests

Create:

```text
student_blitz_finalization_summary_test.dart
```

Cover:

- student submit;
- timeout;
- Teacher close;
- waiting;
- checked;
- Attempt #1;
- Attempt #2;
- answered/unanswered count;
- no score/checking text;
- persisted answer readback;
- file terminal Open/Save controls.

---

# 109. Execution Screen Tests

Extend:

```text
student_blitz_detail_screen_test.dart
```

or create:

```text
student_blitz_execution_screen_test.dart
```

Cover active execution:

- non-file editor for all eight types;
- file editor;
- Save;
- clear;
- file replace;
- countdown;
- Submit readiness;
- Submit confirmation;
- unanswered warning does not disable confirm;
- active operations disabled appropriately;
- uncertain answer/file recovery controls;
- uncertain Submit controls;
- local zero disables mutation;
- terminal transition;
- no result/score UI;
- leave guards;
- uncertain Submit leave copy does not promise unconditional Resume;
- uncertain answer/file leave copy does not promise unconditional Resume;
- return with `inProgressAttemptId != null` shows Resume;
- return with `inProgressAttemptId = null` does not show Resume merely from prior local history;
- no full terminal summary is fabricated from pre-Start detail alone.

Desktop and mobile.

---

# 110. Countdown Race Integration Tests

Use fake time + controlled repositories.

Cover:

1. answer request starts before local zero, returns success after zero;
2. answer request returns `blitz_time_expired`;
3. file upload starts before zero, returns success;
4. file upload timeout;
5. Submit starts before zero and succeeds `student_submit`;
6. Submit starts before zero but backend returns `blitz_time_expired`.

Required:

- no duplicate reconciliation;
- no local fabricated terminal state;
- server result wins.

---

# 111. Safe Completed Start Request Replay Tests

Create explicit coverage that every FE-005 reconciliation:

```text
answer uncertain
file uncertain
Submit check
timeout conflict
task-close conflict
attempt_not_editable
```

uses the exact completed FE-004 immutable request.

Cover all originating request shapes:

```text
start_normal
resume #1
resume #2
start_replacement
```

Assert for every recovery path:

- no new idempotency key generated;
- exact same `Idempotency-Key`;
- exact same `intent`;
- exact same original `attempt_id` for Resume;
- no `attempt_id` added to `start_normal|start_replacement`;
- no Resume `attempt_id` dropped or replaced;
- same Blitz route;
- same current Attempt ID required;
- no intent inferred from current Attempt number/status;
- no intent inferred from refreshed detail;
- no replacement #2 created merely by recovery.

Negative fingerprint-safety cases:

```text
original start_normal + same key replayed as resume
-> forbidden client behavior

original resume + same key but different attempt_id
-> forbidden client behavior

original start_replacement + same key replayed as resume
-> forbidden client behavior
```

No such mismatched request may be sent by FE-005.

Also cover post-Leave recovery after the prior route-session completed request
was intentionally discarded:

```text
fresh detail says in-progress
-> explicit Resume may be offered

fresh detail says no in-progress Attempt
-> no Resume recovery promise
-> no new-key Start as reconciliation
-> no fabricated full terminal summary
```

This is a critical regression.

---

# 112. Stage 7 Shared Regression

Because this task may extract:

```text
StudentAttemptAnswerRepository
common formatters
shared editor recovery label/presentation
```

run directly affected current Stage 7 tests.

At minimum when changed:

```text
student_attempt_answer_editor_controller_test
student_file_answer_controller_test
student_submission_transfer_controller_test
student_homework_submit_readiness_test
student_homework_submit_controller_test
student_homework_screen_test
student_homework_attempt_dto_test
student_homework_attempt_remote_data_source_test
```

Homework continues using:

```text
GET Attempt
deadline_passed
homework_deadline_auto_submit
1..3 attempts
```

Do not accidentally route Homework recovery through Blitz Start replay.

---

# 113. FE-004 Direct Regression

Run focused FE-004 tests for:

```text
active list
detail privacy
Start/Resume/replacement
countdown
routing
Attempt DTO
```

Required:

- Questions still hidden before Start;
- completed Start request extension does not expose raw request/key details;
- pending request and completed request remain distinct;
- normal Start/Resume/replacement behavior unchanged;
- countdown zero remains server-reconciled.

---

# 114. Focused Verification — New FE-005

Run from:

```text
frontend/
```

Conceptually:

```bash
fvm flutter test \
  test/features/student/student_blitz_execution_controller_test.dart \
  test/features/student/student_blitz_answer_editor_controller_test.dart \
  test/features/student/student_blitz_file_answer_controller_test.dart \
  test/features/student/student_blitz_submission_transfer_controller_test.dart \
  test/features/student/student_blitz_submit_readiness_test.dart \
  test/features/student/student_blitz_submit_dto_test.dart \
  test/features/student/student_blitz_submit_data_source_test.dart \
  test/features/student/student_blitz_submit_controller_test.dart \
  test/features/student/student_blitz_finalization_summary_test.dart \
  test/features/student/student_blitz_execution_screen_test.dart
```

Include safe Start replay/countdown race tests if split into separate files.

Use actual names if responsibilities are combined.

---

# 115. Direct Regression Verification

Run:

- exact FE-004 focused tests affected;
- exact Stage 7 answer/file/Submit tests affected by shared extraction.

Do not run full frontend suite.

---

# 116. Focused Analyze

Run:

```bash
fvm flutter analyze --no-pub lib/features/student
```

If core error/shared network files are modified, include the narrowest supported
analyze target.

No router analyze unless router changes unexpectedly.

Do not silently substitute full-project analyze unless required by pinned CLI.

---

# 117. Format Check

Run read-only:

```bash
fvm dart format --output=none --set-exit-if-changed \
  <actual changed Student/core files> \
  <actual focused tests>
```

Do not format unrelated files.

---

# 118. Git Diff Check

From repository root:

```bash
git diff --check
```

Required:

```text
PASS
```

Perform focused scope/diff self-review.

Do not run:

- full frontend suite;
- full project analyze;
- Windows build;
- Android build;
- broad E2E.

Those belong to Frontend Phase 2 / Integration.

---

# 119. Acceptance Criteria — Execution Authority

- [ ] Successful FE-004 handoff preserves the full immutable `StudentBlitzAttemptRequest`.
- [ ] Completed context contains exact `intent + attemptId? + idempotencyKey`.
- [ ] Pending and completed Start request contexts are distinct concepts.
- [ ] No raw request/key exposed to UI.
- [ ] No new Start key used to re-read current Attempt.
- [ ] No replay intent is inferred from current Attempt/detail/lifecycle.
- [ ] Replay resends the exact original body and Idempotency-Key.
- [ ] Resume replay preserves the exact original Attempt ID.
- [ ] Safe replay returns same Attempt ID only.
- [ ] Current full Attempt has one frontend authority owner.
- [ ] Publication token prevents stale answer adoption.
- [ ] Strict successful answer mutation patches one authoritative Answer only.
- [ ] Route/session/Attempt change invalidates old mutation authority.

---

# 120. Acceptance Criteria — Typed Answers

- [ ] All eight non-file editors reused.
- [ ] No duplicate Question editor implementation.
- [ ] Shared answer PUT transport reused.
- [ ] Save/clear success authoritative.
- [ ] Unsaved local drafts never count as server answers.
- [ ] Uncertain save never auto-retries.
- [ ] Check current uses the exact completed immutable Start request.
- [ ] terminal replay disables edits.
- [ ] timeout/non-active/not-editable conflicts reconcile.
- [ ] local zero disables new writes.

---

# 121. Acceptance Criteria — File Answers

- [ ] Existing file picker/upload UX reused.
- [ ] Effective Question size/extension limits respected locally.
- [ ] Server remains content authority.
- [ ] Upload/replace success patches authoritative file answer.
- [ ] uncertain upload never auto-retries.
- [ ] metadata match does not falsely prove selected bytes committed.
- [ ] protected current file Open/Save works.
- [ ] stale/selected local file cannot use protected download.
- [ ] terminal current server file remains transferable.
- [ ] local zero disables new upload.

---

# 122. Acceptance Criteria — Submit

- [ ] Submit uses exact shared Attempt endpoint.
- [ ] Required secure Idempotency-Key.
- [ ] One logical Submit one key.
- [ ] Initial POST validates with `fresh` response expectation.
- [ ] Uncertain Retry uses the same key with `completedReplay` expectation.
- [ ] Response expectation is client-only and never changes request fingerprint/body.
- [ ] No new-key button while uncertain.
- [ ] Unanswered Questions do not block Submit.
- [ ] Dirty/uncertain/in-flight local mutations do block Submit.
- [ ] Stale confirmation token cannot Submit.
- [ ] Fresh success requires `submitted + student_submit`.
- [ ] Completed replay accepts current `submitted|waiting_for_teacher_review|checked` only with original `student_submit` lineage.
- [ ] Timeout/Teacher-close lineage never becomes successful Submit replay.
- [ ] Success adopts full current terminal Attempt.
- [ ] Later result-stage replay is compatibility only; no Stage 9 score/checking UI is implemented.
- [ ] No score/checking shown.

---

# 123. Acceptance Criteria — Terminal Reconciliation

- [ ] `blitz_time_expired` never becomes Student Submit.
- [ ] timeout terminal uses exact server Attempt via safe replay.
- [ ] `attempt_not_editable` reconciles rather than re-enables stale UI.
- [ ] Teacher-close terminal preserved.
- [ ] uncertain Submit can Check current safely.
- [ ] current `student_submit` terminal can be accepted without claiming which key/device won.
- [ ] waiting/checked are terminal read-only.
- [ ] waiting/checked same-key Submit replay is accepted only when historical finalization reason remains `student_submit`.
- [ ] terminal editors have no mutation controls.
- [ ] answered/unanswered count comes from persisted answers only.

---

# 124. Acceptance Criteria — Countdown Interaction

- [ ] local zero disables new answer/file/Submit operations.
- [ ] local zero does not finalize Attempt.
- [ ] in-flight server mutation may still resolve after local zero.
- [ ] successful server mutation before authoritative deadline is preserved.
- [ ] server timeout rejection wins when deadline already passed.
- [ ] no auto-save.
- [ ] no auto-upload.
- [ ] no auto-Submit.
- [ ] no local extra time after reconciliation failure.

---

# 125. Acceptance Criteria — Leave / Return / Conditional Resume

- [ ] Submit-in-progress cannot be abandoned through normal Leave.
- [ ] uncertain Submit leave warns about discarded retry key.
- [ ] uncertain Submit warning says Resume is available only if the Attempt is still in progress.
- [ ] dirty draft leave warns.
- [ ] selected file leave warns.
- [ ] uncertain answer/file leave warns.
- [ ] uncertain answer/file warning does not promise unconditional Resume.
- [ ] Leave makes no server mutation.
- [ ] server timer continues.
- [ ] return first reloads authoritative current detail/lifecycle state.
- [ ] return shows Resume only when fresh detail confirms an exact in-progress Attempt.
- [ ] explicit Resume reloads authoritative full Attempt and establishes a new route-session completed immutable Resume request.
- [ ] return with no in-progress Attempt does not create a recovery Start/replacement request.
- [ ] pre-Start detail alone does not fabricate terminal reason/timestamps/answers.
- [ ] rich terminal summary after Leave requires an authoritative full terminal Attempt resource.
- [ ] no new historical Blitz Attempt GET is added for this recovery case.

---

# 126. Scope Acceptance

- [ ] No Teacher monitoring/exception UI.
- [ ] No Attempt #3.
- [ ] No backend change.
- [ ] No new package/platform change.
- [ ] No Blitz Attempt GET invented.
- [ ] No scoring/checking/result UI.
- [ ] No automatic answer/file replay.
- [ ] No automatic Submit at zero.
- [ ] Focused FE-005 tests pass.
- [ ] FE-004 regressions pass.
- [ ] Stage 7 shared regressions pass.
- [ ] focused analyze passes.
- [ ] format check passes.
- [ ] `git diff --check` passes.

---

# 127. Focused Diff Self-Check

Before completion confirm the diff implements only:

```text
Blitz answer/file execution
+
safe current-Attempt replay using immutable completed Start request
+
idempotent final Submit with later-stage completed replay compatibility
+
terminal reconciliation
```

Verify specifically:

```text
no new Start key for recovery
exact original Start intent/body/key replayed
no intent inference from current Attempt/detail
no Attempt GET
no score/checking
unanswered allowed
local countdown not business authority
no automatic non-idempotent replay
no replacement creation from reconciliation
```

Confirm every changed file is necessary.

---

# 128. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. completed immutable Start request handoff/replay extension;
4. execution authority/publication model;
5. shared answer transport extraction;
6. eight non-file editor integration;
7. file picker/upload/transfer integration;
8. uncertain answer/file reconciliation;
9. countdown mutation gating;
10. Submit readiness/confirmation;
11. Submit Idempotency-Key lifecycle and fresh-vs-replay response validation;
12. terminal reconciliation behavior;
13. leave/return/conditional-Resume behavior and terminal-summary limitation;
14. focused FE-005 test results;
15. FE-004 regression results;
16. Stage 7 shared regression results;
17. focused analyze result;
18. format check result;
19. `git diff --check`;
20. final `git status --short`;
21. focused scope/diff self-check;
22. any blocker/deviation.

Do not claim Stage 8 frontend complete.

After delivery ChatGPT performs read-only acceptance review.

`S08-FE-006` remains blocked until:

```text
S08-FE-005 = Accepted / Delivered
```

---

# 129. Implementation Readiness Verdict

```text
Scope / non-goals                    = RESOLVED
Completed immutable Start request    = RESOLVED
Replay body/fingerprint preservation = RESOLVED
No Attempt GET recovery              = RESOLVED
Execution authority                  = RESOLVED
Publication-token integrity          = RESOLVED
Shared answer transport              = RESOLVED
Eight typed editors                  = RESOLVED
File picker/upload/replace           = RESOLVED
Protected file transfer              = RESOLVED
Answer mutation success adoption     = RESOLVED
Answer uncertainty reconciliation    = RESOLVED
File uncertainty reconciliation      = RESOLVED
Countdown write gate                 = RESOLVED
Submit readiness                     = RESOLVED
Unanswered Submit                    = RESOLVED
Submit confirmation                  = RESOLVED
Submit Idempotency-Key               = RESOLVED
Uncertain same-key Retry             = RESOLVED
Submit later-stage replay compatibility = RESOLVED
Submit current-state check           = RESOLVED
Timeout terminal reconciliation      = RESOLVED
Teacher-close terminal reconciliation = RESOLVED
Student-submit terminal reconciliation = RESOLVED
Leave/conditional Resume behavior    = RESOLVED
Post-Leave terminal summary boundary   = RESOLVED
Session/route stale safety           = RESOLVED
Desktop/mobile execution UX          = RESOLVED
Accessibility/responsiveness         = RESOLVED
Focused tests                        = RESOLVED
Focused verification                 = RESOLVED

Implementation Readiness Gate        = PASS
Execution dependency                 = S08-FE-004 Accepted / Delivered
Next task after acceptance            = S08-FE-006
```
