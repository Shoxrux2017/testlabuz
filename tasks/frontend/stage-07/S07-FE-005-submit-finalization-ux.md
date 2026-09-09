# Codex Implementation Contract: S07-FE-005 — Submit / Finalization UX

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S07-FE-005` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter final Attempt review/confirmation + idempotent Student Submit + finalization reconciliation` |
| Depends on | `S07-FE-004 = Accepted / Delivered`; Stage 7 Backend Phase 2 remains `PASS` |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Implementation baseline | ChatGPT re-checks/freezes current `origin/main` immediately before Codex starts |
| Readiness Gate | `PASS`, conditional on dependencies above |
| Supported surfaces | `Student desktop + mobile` |
| Verification | focused frontend tests + FE-001…004 regressions + format/analyze + diff check |
| Delivery | Project Owner |
| Frontend block checkpoint | Stage 7 Frontend Phase 2 immediately after this frontend task block |

Do not create a duplicate `CODEX-PROMPT`.

---

# 2. Context Boundary

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. delivered `S07-FE-001…004` Student Homework/Attempt/answer/file source and focused tests;
5. delivered FE-002:
   - `IdempotencyKeyGenerator`;
   - Attempt route/controller/repository/data source;
6. delivered FE-003/004 local mutation state and route-leave protection;
7. current safe confirmation-dialog pattern where directly useful;
8. configured Dio/failure/session infrastructure;
9. exact backend Submit contract reproduced below.

Do not read product docs, roadmap, architecture/database/API docs, previous task files, Stage history, closure reviews, or unrelated modules to determine behavior.

This contract resolves:

- exact Submit request/response;
- Submit idempotency-key lifetime;
- local pre-Submit safety gate;
- unsaved/uncertain answer blocking;
- confirmation content;
- zero/partial/full answer submission;
- same-key uncertain retry;
- Submit-vs-lifecycle reconciliation;
- immediate terminal state adoption;
- post-Submit cache invalidation;
- route-leave behavior during submitting/uncertain state;
- tests and verification.

If delivered backend or FE-004 materially conflicts with this contract, return `BLOCKED` with exact evidence. Do not redesign.

---

# 3. Goal

Complete the Stage 7 Student Homework frontend flow.

A Student with a confirmed editable Attempt can:

1. save or discard any local answer changes;
2. review how many Question answers are confirmed as saved;
3. explicitly confirm final submission;
4. submit through:
   ```text
   POST /api/v1/student/attempts/{attempt}/submit
   ```
   with a client-generated `Idempotency-Key`;
5. safely retry the same logical Submit after an uncertain response using the same key;
6. reconcile deadline/close/other terminal outcomes;
7. remain on a read-only terminal Attempt screen after finalization.

This task does not show scores/checking results.

---

# 4. Explicit Non-Goals

Do not implement:

- automatic answer checking;
- Teacher review;
- awarded points;
- Attempt score;
- official Homework score selection;
- Student result release;
- Parent result visibility;
- final Topic result;
- Blitz;
- autosave-all-before-submit;
- transactional client batch save;
- new Attempt creation immediately after Submit;
- countdown/deadline authority;
- offline Submit queue;
- background retry;
- durable device persistence of pending Submit keys;
- new package/dependency;
- router/client/state framework change;
- backend/platform changes.

A later normal Attempt, when available, is started through the existing FE-002 Homework detail flow.

---

# 5. Backend Submit Contract

Endpoint:

```text
POST /api/v1/student/attempts/{attempt}/submit
```

Required header:

```http
Idempotency-Key: <UUID>
```

Body:

```json
{}
```

No query.

Success:

```text
200 OK
```

Exact response:

```json
{
  "data": {
    "id": "attempt-uuid",
    "assessment_id": "homework-uuid",
    "attempt_number": 1,
    "status": "submitted",
    "started_at": "2026-09-08T12:00:00Z",
    "submitted_at": "2026-09-08T12:10:00Z",
    "finalized_at": "2026-09-08T12:10:00Z",
    "finalization_reason": "student_submit",
    "deadline_at": "2026-09-10T13:00:00Z",
    "questions": [],
    "answers": []
  },
  "message": "Homework submitted successfully."
}
```

The same completed idempotency key may later replay the same logical Submit while the returned current safe Attempt status has progressed to a later server lifecycle state.

No score/checking fields are returned by the Stage 7 client contract.

---

# 6. Backend Explicit Submit State

A normal current Stage 7 explicit success transitions:

```text
in_progress
->
submitted
```

with:

```text
submitted_at != null
finalized_at = submitted_at
finalization_reason = student_submit
```

The frontend must never produce or infer these fields itself.

The returned server Attempt resource is authoritative.

---

# 7. Backend Submit Errors

Relevant deterministic errors:

```text
404 resource_not_found

409 task_not_active
409 task_closed
409 task_archived
409 deadline_passed
409 attempt_not_editable
409 idempotency_key_reused
409 business_conflict

422 validation_failed
```

Session/auth errors remain the existing shared contract.

Server/transport uncertainty may also occur.

Do not branch on human-readable messages.

---

# 8. Unanswered Questions Are Allowed

Submit must remain possible when the current server-confirmed Attempt has:

```text
all Questions answered
some Questions answered
zero Questions answered
```

There is no frontend:

```text
all questions required
```

rule.

Do not add:

```text
submission_incomplete
required question
answer every question first
```

validation.

However **local unsaved work** must be resolved before Submit so the Student knows exactly which server snapshot will be frozen.

---

# 9. Local Pre-Submit Safety Principle

Final Submit freezes:

```text
server-saved answers
```

not arbitrary visible unsaved Flutter drafts.

Therefore Submit is enabled only when the current screen has no unresolved local answer mutation state.

The Student must explicitly:

```text
Save
or
Discard
```

each local unsaved change before Submit.

FE-005 must never auto-save answers when Submit is pressed.

---

# 10. Route Submit Operation Gate

Create:

```text
frontend/lib/features/student/application/student_attempt_route_operation_gate.dart
```

Family provider keyed by:

```text
StudentHomeworkAttemptRouteTarget
```

State enum:

```text
StudentAttemptRouteOperation:
  idle
  submitting
  submitUncertain
```

Purpose:

- prevent a new answer save/file upload from starting once Submit begins;
- keep the entire Attempt locally frozen while Submit outcome is uncertain.

It is not a generic global mutation framework.

It applies only to the current Attempt route.

---

# 11. Gate Ownership

The Submit controller:

- claims:
  ```text
  submitting
  ```
  synchronously before its first async wait/request;
- changes to:
  ```text
  submitUncertain
  ```
  on uncertain outcome;
- releases to:
  ```text
  idle
  ```
  on:
  - confirmed success;
  - deterministic Submit failure;
  - authoritative terminal reconciliation;
  - session/route-target invalidation;
  - explicit abandonment when leaving an uncertain route.

FE-003/004 answer controllers read the gate before beginning a new mutation.

They must refuse new save/upload work while:

```text
submitting
submitUncertain
```

---

# 12. Modify FE-003 Answer Mutation Gate Check

Before a non-file Question save/retry begins, delivered:

```text
StudentAttemptAnswerEditorController
```

must additionally require:

```text
routeOperationGate == idle
```

If Submit already claimed the gate:

- do nothing;
- do not send PUT;
- preserve draft.

Existing answer-save behavior otherwise remains unchanged.

Do not make the answer controller depend on Submit business state beyond this small gate.

---

# 13. Modify FE-004 File Mutation Gate Check

Before:

```text
file picker
file upload
retry upload
```

begins, delivered:

```text
StudentFileAnswerController
```

must additionally require:

```text
routeOperationGate == idle
```

If Submit already claimed the gate:

- do nothing;
- preserve current local state where safe;
- send no upload.

Saved-file read-only Open/Save As may remain available unless presentation chooses to disable them during the brief Submit operation.

No file mutation may start.

---

# 14. Submit Readiness Model

Create:

```text
frontend/lib/features/student/domain/student_homework_submit.dart
frontend/lib/features/student/application/student_homework_submit_readiness.dart
```

Typed blockers:

```text
StudentHomeworkSubmitBlocker:
  attemptNotEditable
  attemptStateLoading
  nonFileUnsavedChanges
  nonFileSaveInProgress
  nonFileSaveUncertain
  fileSelectionPending
  fileUploadInProgress
  fileUploadUncertain
  localStateUnavailable
```

No raw booleans-only API.

---

# 15. Submit Readiness Inputs

Readiness derives from current confirmed route/session state:

```text
StudentHomeworkAttemptController
StudentAttemptAnswerEditorController
StudentFileAnswerController
StudentAttemptRouteOperationGate
```

and the current route target.

The computed readiness must update reactively in presentation.

Submit controller must independently re-check the same required conditions synchronously immediately before claiming the gate.

UI disabling is not the sole safety boundary.

---

# 16. Editable Attempt Requirement

Submit readiness requires current confirmed Attempt:

```text
status = in_progress
```

No Submit button for:

```text
submitted
waiting_for_teacher_review
checked
```

Do not accept `timed_out_finalized` as Homework.

If parent Attempt is currently loading with no confirmed data:

```text
attemptStateLoading
```

If a refresh is in progress while retaining confirmed `in_progress` data:

- disable Submit until the refresh completes.

Reason:

> a refresh may be reconciling deadline/close finalization.

Do not submit against knowingly refreshing lifecycle state.

---

# 17. Non-File Local Blockers

Submit is blocked when FE-003 reports any:

```text
hasDirtyDrafts
```

Use:

```text
nonFileUnsavedChanges
```

Submit is blocked when an answer operation is:

```text
saving
```

Use:

```text
nonFileSaveInProgress
```

Submit is blocked when:

```text
uncertain
```

Use:

```text
nonFileSaveUncertain
```

A deterministic failure with a dirty draft remains blocked by:

```text
nonFileUnsavedChanges
```

The Student must:

- fix + Save; or
- Discard changes.

---

# 18. File Local Blockers

Submit is blocked when FE-004 reports:

```text
hasPendingSelection
```

Use:

```text
fileSelectionPending
```

Submit is blocked while:

```text
selecting
uploading
```

Use:

```text
fileUploadInProgress
```

Submit is blocked for:

```text
uncertain upload
```

Use:

```text
fileUploadUncertain
```

A retained selected file after confirmed `file_upload_failed` remains:

```text
fileSelectionPending
```

until retried/discarded.

---

# 19. Answer Count Snapshot

Create a safe confirmed answer snapshot for confirmation display.

Fields:

```text
questionCount
confirmedAnsweredCount
unansweredCount
```

Require:

```text
0 <= confirmedAnsweredCount <= questionCount
unansweredCount = questionCount - confirmedAnsweredCount
```

Do not count local dirty/selected-but-unsaved work as answered.

---

# 20. Confirmed Answer Snapshot Merge

The FE-002 Attempt may be slightly older than a just-confirmed FE-003/004 mutation response when a non-blocking GET refresh failed.

Therefore compute current **confirmed server answer state** by merging:

1. FE-002 Attempt `answers`;
2. FE-003 latest confirmed `serverAnswer` per non-file Question;
3. FE-004 latest confirmed `serverFile` per file Question.

Rules:

- FE-003 confirmed null clear removes that Question from answered count;
- FE-003 confirmed non-null adds it;
- FE-004 confirmed `serverFile != null` adds it;
- no local dirty draft counts;
- no selected file counts;
- no uncertain mutation snapshot counts.

Use Question IDs as identity.

Do not infer answer completeness from Widget controls.

---

# 21. Submit Button UX

On an editable Attempt show a final section:

```text
Submit attempt
```

Button key:

```text
studentHomeworkSubmitAttemptButton
```

When ready:

```text
FilledButton
Submit Attempt
```

When blocked:

- disabled;
- show one or more concise blocker messages.

Examples:

```text
Save or discard unsaved answer changes before submitting.
Wait for the current answer save to finish.
Resolve the unconfirmed answer save before submitting.
Upload or discard the selected file before submitting.
Resolve the unconfirmed file upload before submitting.
Wait for the Attempt refresh to finish.
```

Do not silently fix blockers.

---

# 22. Confirmation Dialog

Pressing enabled Submit first opens:

```text
AlertDialog
```

Key:

```text
studentHomeworkSubmitConfirmDialog
```

Title:

```text
Submit Attempt <N>?
```

Content includes current confirmed snapshot.

Example:

```text
5 of 9 answers are saved.
4 Questions have no saved answer.

Submitting will lock this Attempt and it cannot be edited afterward.
Unanswered Questions are allowed.

If another Homework Attempt is available later, it must be started separately.
```

If all saved:

```text
9 of 9 answers are saved.
```

If zero:

```text
0 of 9 answers are saved.
9 Questions have no saved answer.
```

Zero does **not** disable confirmation.

---

# 23. Confirmation Actions

Actions:

```text
Cancel
Submit Attempt
```

`Cancel` gets initial focus on desktop where existing project confirmation convention supports it.

Confirmation button key:

```text
studentHomeworkSubmitConfirmButton
```

Do not add:

```text
Save all and submit
```

No automatic answer mutation.

---

# 24. Confirmation Async Ownership

Before opening dialog capture:

```text
StudentSessionKey
StudentHomeworkAttemptRouteTarget
current readiness snapshot identity/generation if applicable
```

After dialog returns `true`, re-check:

- context mounted;
- route target still current;
- Student session key unchanged;
- current Attempt still confirmed `in_progress`;
- readiness still `ready`.

If any check fails:

- send no Submit;
- close dialog normally;
- refresh/re-render authoritative state as needed.

A deadline/close may occur while the dialog is open.

---

# 25. Submit Idempotency Key

Reuse delivered FE-002:

```text
IdempotencyKeyGenerator
idempotencyKeyGeneratorProvider
```

Do not create another UUID implementation.

The Submit controller owns private:

```text
_pendingIdempotencyKey
```

per current route target/session.

---

# 26. Submit Logical Key Lifetime

## New logical Submit

After confirmation and final readiness re-check:

- generate exactly one new UUID;
- retain it through the logical Submit operation.

## Confirmed success

Clear key.

## Deterministic 4xx failure

Clear key.

## Uncertain outcome

Retain the same key.

## Retry

Use the exact same retained key.

## Session/target loss

Clear key/gate.

No durable storage beyond the current controller lifetime.

---

# 27. Submit Domain Result

Create:

```text
StudentHomeworkSubmitResult
```

Fields:

```text
attempt
```

No display message is required in domain.

The backend message is transport contract evidence only.

No score fields.

---

# 28. Submit Response DTO

Create:

```text
frontend/lib/features/student/data/dto/student_homework_submit_dto.dart
```

Exact top-level keys:

```text
data
message
```

Require:

```text
message == "Homework submitted successfully."
```

Parse `data` through the delivered FE-002:

```text
StudentHomeworkAttemptDto
```

Do not duplicate Attempt parsing.

Reject extra top-level keys.

---

# 29. Submit Success Semantic Validation

For requested route target require:

```text
returned attempt.id == target.attemptId
returned attempt.assessmentId == target.homeworkId
```

A successful Submit response must not return:

```text
status = in_progress
```

Allowed current returned statuses:

```text
submitted
waiting_for_teacher_review
checked
```

This supports a safe same-key replay after later server lifecycle progression.

For immediate Stage 7 normal success, the backend returns:

```text
submitted
student_submit
```

If the response is malformed/inconsistent:

```text
uncertain outcome
```

because server finalization may already have committed.

---

# 30. Data Source Submit Method

Modify:

```text
StudentHomeworkAttemptRemoteDataSource
```

Add:

```text
submitAttempt(
  String attemptId,
  String idempotencyKey,
)
```

Exact request:

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

No automatic retry.

---

# 31. Repository Submit Method

Modify:

```text
StudentHomeworkAttemptRepository
StudentHomeworkAttemptRepositoryImpl
```

Add:

```text
Future<StudentHomeworkSubmitResult> submitAttempt(
  String attemptId,
  String idempotencyKey,
)
```

No presentation logic.

No local finalization.

No score/checking logic.

---

# 32. Submit Controller

Create:

```text
frontend/lib/features/student/application/student_homework_submit_state.dart
frontend/lib/features/student/application/student_homework_submit_controller.dart
```

Family key:

```text
StudentHomeworkAttemptRouteTarget
```

Statuses:

```text
idle
submitting
uncertain
failure
completed
```

State may include:

```text
failure?
notice?
```

Do not expose raw idempotency key to Widget state.

---

# 33. Submit Controller Preflight

`submitConfirmed()` or equivalent must synchronously:

1. resolve current eligible `StudentSessionKey`;
2. verify route target;
3. verify current Attempt confirmed/in-progress/not refreshing;
4. verify no FE-003 dirty/save/uncertain state;
5. verify no FE-004 selected/upload/uncertain state;
6. verify operation gate `idle`;
7. generate/reuse the logical Submit key;
8. synchronously claim:
   ```text
   gate = submitting
   ```
9. only then start async request.

No first `await` before the gate claim.

This prevents a new answer save/upload from entering between readiness check and Submit.

---

# 34. Duplicate Submit Suppression

While:

```text
submitting
uncertain
```

do not start another logical Submit.

During `uncertain`, only:

```text
Retry submission
Check current Attempt
```

actions are allowed.

No normal new-key Submit button.

---

# 35. Submit Uncertain Outcome Classification

Treat as uncertain:

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

Reason:

> the backend may have committed the idempotent Submit before the response was lost.

Actions:

```text
status = uncertain
gate = submitUncertain
retain same idempotency key
```

Do not claim success/failure.

---

# 36. Uncertain Submit UX

Display a prominent state:

```text
We could not confirm whether this Attempt was submitted.
```

Actions:

```text
Retry submission
Check current Attempt
```

`Retry submission` is the primary safe action.

While uncertain:

- all answer editors are locally frozen/read-only;
- file picker/upload is blocked;
- normal Submit is hidden/disabled;
- route operation gate remains claimed.

Do not allow new answer changes after an uncertain Submit because the backend may already have frozen the Attempt.

---

# 37. Retry Submission

Retry sends:

```text
same Attempt ID
same Idempotency-Key
same body {}
```

No new key.

If `200` valid:

- confirmed success.

If another uncertain result:

- retain the same key/gate.

If deterministic lifecycle result:

- release gate/key;
- reconcile authoritative Attempt.

This exact same-key retry behavior requires a controller test.

---

# 38. Check Current Attempt

The uncertain state may call delivered:

```text
StudentHomeworkAttemptController.refresh()
```

After authoritative GET:

## Attempt now terminal with `student_submit`

Treat the desired submission outcome as achieved:

- clear pending key;
- release gate;
- state `completed`;
- use current terminal Attempt.

This is valid proof that the Attempt has been explicitly submitted, regardless of which idempotent delivery observed the success.

## Attempt terminal due:

```text
homework_deadline_auto_submit
task_closed_auto_finalize
```

The Attempt is finalized, but not by explicit Student submit.

Actions:

- clear key/gate;
- state returns to a terminal-reconciled notice;
- show the authoritative finalization reason;
- do not show:
  ```text
  Submitted successfully
  ```
  as an explicit action success.

## Attempt remains `in_progress`

Do **not** conclude that the original Submit definitely failed.

The original timed-out request may still be resolving.

Remain:

```text
uncertain
```

with the same key.

`Retry submission` remains the safe resolution path.

---

# 39. Confirmed Submit Success

On valid `200`:

1. clear pending key;
2. release route operation gate;
3. state:
   ```text
   completed
   ```
4. adopt returned server Attempt into the FE-002 Attempt controller;
5. clear/reconcile FE-003/004 local editor state through the now-terminal parent Attempt;
6. mark/invalidate FE-001:
   - Homework detail;
   - Topic Homework list;
7. remain on the Attempt route;
8. show:
   ```text
   Attempt submitted successfully.
   ```

Do not automatically navigate away.

Do not automatically start the next Attempt.

---

# 40. Authoritative Attempt Adoption

Add a focused method to delivered:

```text
StudentHomeworkAttemptController
```

such as:

```text
adoptAuthoritativeAttempt(
  StudentHomeworkAttempt attempt,
)
```

or equivalent.

It may accept the returned Submit Attempt only when:

```text
current route target matches
current Student session matches
attempt.id == target.attemptId
attempt.assessmentId == target.homeworkId
```

Then publish:

```text
data
```

without another network request.

This avoids a transient UI where backend Submit succeeded but the local Attempt still appears editable.

Do not expose a generic arbitrary model injection API.

---

# 41. Homework Read Reconciliation After Success

After confirmed Submit mark:

```text
Student Homework detail/list
```

stale/invalidate using FE-001 mechanisms.

Reason:

- `my_status`;
- used/remaining;
- `in_progress_attempt`;

changed.

Do not locally patch:

```text
remaining
used
myStatus
```

Backend remains authoritative.

---

# 42. Deterministic `deadline_passed`

On:

```text
409 deadline_passed
```

the backend has reconciled due Attempts.

Actions:

- clear pending Submit key;
- release gate;
- refresh:
  ```text
  Attempt
  Homework detail
  Topic Homework list
  ```
- show:
  ```text
  The Homework deadline has passed.
  ```
- expect Attempt to become terminal with:
  ```text
  homework_deadline_auto_submit
  ```

Do not show explicit Student Submit success.

---

# 43. Deterministic `attempt_not_editable`

Actions:

- clear key/gate;
- refresh Attempt;
- show:
  ```text
  This Attempt is no longer editable.
  ```

If refresh shows another-device explicit `student_submit`:

- render terminal state;
- do not manufacture a success for the current new-key operation.

No further editor access.

---

# 44. Deterministic Task Lifecycle Errors

For:

```text
task_not_active
task_closed
task_archived
```

Actions:

- clear key/gate;
- refresh:
  ```text
  Attempt
  Homework detail
  ```
- show:
  ```text
  This Homework is no longer available for submission.
  ```

If the Attempt is now terminal due close, render that server finalization.

---

# 45. Deterministic `resource_not_found`

Actions:

- clear key/gate;
- trigger FE-002 Attempt notFound reconciliation;
- refresh/mark stale Homework detail/list;
- no raw backend ID/message exposure.

---

# 46. Deterministic `idempotency_key_reused`

This indicates unexpected logical-key reuse/collision/state corruption on the client side.

Actions:

- clear the key;
- release gate;
- state `failure`;
- refresh Attempt;
- show:
  ```text
  The Attempt could not be submitted safely. Check the current Attempt and try again if it is still editable.
  ```

Do not silently generate a replacement key within the same operation.

A later explicit new Submit is allowed only after authoritative refresh confirms:

```text
status = in_progress
```

and readiness is clean.

---

# 47. Deterministic `business_conflict`

Actions:

- clear key/gate;
- refresh Attempt;
- retain no submission-in-flight state;
- show safe generic conflict.

If Attempt remains `in_progress`, Student may retry as a new logical Submit after the UI returns to a ready state.

---

# 48. Deterministic `validation_failed`

The frontend always sends:

```text
UUID Idempotency-Key
{}
```

so a backend validation rejection indicates contract/client mismatch.

Actions:

- clear key/gate;
- state failure;
- show:
  ```text
  The submission request could not be validated. Refresh and try again.
  ```
- do not display field internals as a Student answer validation issue.

Do not auto retry.

---

# 49. Session Failure

On:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

use existing Student session reconciliation.

Also:

- clear pending Submit key;
- release gate;
- no completion/navigation from stale response.

Do not carry pending Submit state into a future session.

---

# 50. Submission Does Not Require All Answers

The Submit controller must not inspect Question-specific validity to require answers.

It only requires:

```text
no unsaved local mutation state
```

A Question can be confirmed unanswered.

Examples that must be allowed:

```text
Single Choice with no server answer
True/False with no server answer
file_based with no serverFile
all Questions unanswered
```

The confirmation reports the count, then Submit proceeds if the Student confirms.

---

# 51. No Auto-Save Before Submit

Do not implement:

```text
for each dirty answer:
  save
then submit
```

Reasons:

- multiple independent network outcomes;
- uncertain answer mutations;
- server lifecycle may change between calls;
- unclear Student intent.

Instead the Student explicitly resolves each draft first.

This is a locked UX decision.

---

# 52. Editor Presentation During Submit

When route operation gate:

```text
submitting
submitUncertain
```

the FE-003/004 presentation must become locally read-only/frozen.

Do not clear visible confirmed answers.

For `submitting`:

```text
Submitting Attempt…
```

For `submitUncertain`:

```text
Submission result unconfirmed.
```

Do not allow:

- option changes;
- text changes;
- file picker;
- answer Save;
- Discard;
- Clear.

Open/Save As of an already saved file may remain disabled during `submitting/uncertain` for a simpler fully-frozen Attempt presentation.

---

# 53. Submit Progress

During:

```text
submitting
```

show:

```text
LinearProgressIndicator
Submitting Attempt…
```

with semantic label.

Do not infer completion by elapsed time.

No client timeout countdown.

---

# 54. Terminal Attempt Presentation

After any authoritative finalization:

```text
submitted
waiting_for_teacher_review
checked
```

FE-002 terminal read-only shell remains the base.

Add a finalization summary card:

```text
Attempt finalized
Status
Finalized at
Submitted at if explicit
Finalization reason
```

Human labels:

```text
student_submit
  -> Submitted by you

homework_deadline_auto_submit
  -> Finalized at the Homework deadline

task_closed_auto_finalize
  -> Finalized when the Homework was closed
```

No score/checking result.

---

# 55. Successful Explicit Submit Notice

For the current confirmed Submit operation only:

```text
Attempt submitted successfully.
```

This notice may be shown as:

- inline status;
- SnackBar plus terminal summary.

Do not persist it as a domain state beyond current route/session.

A terminal Attempt loaded later through GET does not need to claim that the current client performed the successful submit; its finalization reason is enough.

---

# 56. Starting Another Attempt

FE-005 does not add:

```text
Start another Attempt
```

inside the terminal Attempt screen.

Provide:

```text
Back to Homework
```

The FE-001/002 Homework detail refresh then decides from server state whether:

```text
Start Attempt
```

is available.

Do not duplicate attempts remaining logic in the terminal screen.

---

# 57. Back / Route Leave During `submitting`

While the HTTP Submit request is actively:

```text
submitting
```

block route leave.

If the Student invokes Back/system back, show:

```text
Submission is in progress.
Wait until the result is known.
```

Only action:

```text
Stay
```

Do not let the route dispose while the request outcome is actively pending in-process.

This avoids unnecessary loss of the idempotency replay context.

---

# 58. Back / Route Leave During `uncertain`

When:

```text
submitUncertain
```

allow leaving only after explicit warning:

```text
The submission result is still unconfirmed.

Leaving will discard this retry key.
When you open the Attempt again, the app will load the current server state.
```

Actions:

```text
Stay
Leave
```

On Leave:

- clear pending key;
- release gate;
- clear current Submit controller operation;
- navigate back to Homework detail.

No automatic new request.

---

# 59. Route Leave Guard Priority

FE-005 extends the FE-003/004 Attempt PopScope priority.

Use exactly:

1. `submitting`
2. `submitUncertain`
3. uncertain answer/file mutation
4. ordinary dirty answer / selected file
5. clean leave

Reason:

> final Submit outcome ambiguity dominates earlier local draft warnings.

Do not show multiple stacked dialogs for one Back action.

---

# 60. Normal Clean Back

When no submit/mutation/dirty state exists:

```text
Back to Homework
```

works without confirmation.

Terminal Attempt also leaves without a dirty-work confirmation.

---

# 61. Submit Confirmation Is Not Route Leave Confirmation

Keep separate:

```text
Submit Attempt?
```

and:

```text
Leave with unsaved/uncertain work?
```

Do not reuse one ambiguous dialog.

Each has its own key/semantic label.

---

# 62. Accessibility

Required:

- Submit section has semantic heading;
- blocker reasons are readable text;
- Submit button label explicit;
- confirmation counts are announced as text;
- Cancel is safe initial focus on desktop;
- progress has semantic label;
- uncertain state announced/readable;
- Retry submission and Check current Attempt are keyboard/touch accessible;
- terminal finalization reason is text, not color;
- no score/correctness hidden via color/icon;
- dialogs have meaningful titles/actions;
- no focus trap.

---

# 63. Responsiveness

Support desktop/mobile.

Submit/finalization card:

- max available width;
- buttons use `Wrap`;
- confirmation dialog content scrolls if needed;
- counts/warnings wrap;
- no fixed-width overflow;
- large text scale remains usable.

No desktop-only Submit restriction.

---

# 64. Submit Readiness Presentation

Create a focused Widget or helper:

```text
student_homework_submit_controls.dart
```

It consumes typed readiness + Submit state.

Do not make `student_homework_attempt_screen.dart` a monolithic lifecycle/mutation file.

Recommended responsibility split:

```text
Attempt screen
  -> question editors
  -> file editor
  -> Submit controls
  -> finalization summary
```

---

# 65. Expected Files

## Create

```text
frontend/lib/features/student/domain/student_homework_submit.dart

frontend/lib/features/student/data/dto/student_homework_submit_dto.dart

frontend/lib/features/student/application/student_attempt_route_operation_gate.dart
frontend/lib/features/student/application/student_homework_submit_readiness.dart
frontend/lib/features/student/application/student_homework_submit_state.dart
frontend/lib/features/student/application/student_homework_submit_controller.dart

frontend/lib/features/student/presentation/student_homework_submit_controls.dart
frontend/lib/features/student/presentation/student_attempt_finalization_summary.dart

frontend/test/features/student/student_homework_submit_data_test.dart
frontend/test/features/student/student_homework_submit_readiness_test.dart
frontend/test/features/student/student_homework_submit_controller_test.dart
frontend/test/features/student/student_homework_submit_screen_test.dart
```

## Modify

```text
frontend/lib/features/student/domain/student_homework_attempt_repository.dart
frontend/lib/features/student/data/student_homework_attempt_remote_data_source.dart
frontend/lib/features/student/data/student_homework_attempt_repository_impl.dart

frontend/lib/features/student/application/student_homework_attempt_controller.dart
frontend/lib/features/student/application/student_attempt_answer_editor_controller.dart
frontend/lib/features/student/application/student_file_answer_controller.dart

frontend/lib/features/student/presentation/student_homework_attempt_screen.dart
frontend/lib/features/student/presentation/student_question_answer_editor.dart
frontend/lib/features/student/presentation/student_file_answer_editor.dart
frontend/lib/features/student/presentation/student_homework_formatters.dart
```

Update FE-003/004 navigation guard implementation/tests.

No route path changes required.

No backend/pubspec/pubspec.lock/platform files.

No new API error code is expected beyond FE-002/003 delivered constants.

---

# 66. Submit Data Tests

`student_homework_submit_data_test.dart` covers exact request:

```text
POST /student/attempts/{attempt}/submit
```

Assert:

```text
body = {}
Idempotency-Key exact
no query
followRedirects = false
```

Success only:

```text
200
```

Exact response:

```text
data
message
```

Require exact message.

Reuse Attempt parser.

Reject:

- wrong Attempt ID;
- wrong Homework assessment ID;
- returned `in_progress`;
- malformed Attempt;
- extra top-level key;
- score/checking fields;
- wrong success message.

Malformed 200 response is surfaced as:

```text
invalidResponse
```

to the Submit controller, which classifies it as uncertain.

No automatic retry.

---

# 67. Readiness Tests

`student_homework_submit_readiness_test.dart` must cover independently:

```text
ready clean in_progress
terminal attempt
loading
refreshing
dirty non-file
saving non-file
uncertain non-file
pending file selection
selecting/uploading file
uncertain file
local state unavailable
```

Verify zero answered remains:

```text
ready
```

when no local blockers exist.

Verify answer-count merge:

- Attempt base answer;
- FE-003 newly confirmed non-file answer not yet reflected in GET;
- FE-003 confirmed clear;
- FE-004 newly confirmed file;
- local dirty value ignored;
- selected file ignored;
- uncertain mutation ignored.

---

# 68. Submit Controller Tests

`student_homework_submit_controller_test.dart` covers:

## Success

- deterministic injected UUID;
- one repository call;
- gate synchronously claims `submitting`;
- 200 terminal response;
- pending key cleared;
- gate released;
- Attempt authoritative adoption;
- Homework detail/list invalidation.

## Zero answers

Submit succeeds.

No completeness error.

## Duplicate call

Second call while submitting ignored.

## Timeout

- key A generated;
- uncertain;
- gate becomes `submitUncertain`;
- Retry uses key A;
- success;
- generator called once.

## 500/connection

Same uncertain same-key behavior.

## Invalid success payload

Classified uncertain.

Same key retained.

## Deterministic 409

Key/gate cleared.

Correct refresh path triggered.

## deadline

Attempt/Homework refresh.

No explicit success notice.

## idempotency reuse

No automatic new key.

## session/target stale completion

Cannot adopt/navigate/publish success.

Gate/key cleared on session ownership loss.

---

# 69. Operation Gate Regression Tests

Add focused tests proving:

## Submit claims first

Then FE-003 answer Save:

```text
sends no PUT
```

and FE-004 file picker/upload:

```text
sends no mutation
```

## Answer/file mutation already active

Readiness blocks Submit before gate claim.

No POST.

This is application-layer behavior, not Widget-only disabling.

---

# 70. Uncertain Check-Current Tests

Controller/widget tests cover:

## GET returns student_submit terminal

- uncertainty clears;
- key/gate clears;
- completed state;
- explicit success achieved.

## GET returns deadline terminal

- uncertainty clears;
- no explicit success notice;
- deadline finalization displayed.

## GET returns close terminal

Same authoritative auto-finalization behavior.

## GET remains in_progress

- uncertainty remains;
- key retained;
- Retry still same key.

No new key.

---

# 71. Confirmation Screen Tests

`student_homework_submit_screen_test.dart` desktop + mobile.

Verify:

## Ready

Submit button enabled.

## Dirty

Disabled + message.

## Pending file

Disabled + message.

## Uncertain answer/file

Disabled + resolve message.

## Refreshing

Disabled.

## Confirmation counts

Cases:

```text
9/9
5/9
0/9
```

0/9 confirm button remains enabled.

## Cancel

No POST.

## Confirm

Calls controller only after session/target/readiness re-check.

## State changed while dialog open

If Attempt becomes terminal or a blocker appears before confirmation returns:

- no POST.

---

# 72. Submitting / Uncertain Screen Tests

Verify:

## Submitting

- progress;
- editors frozen;
- file mutation controls disabled;
- Submit button not duplicated;
- Back action shows in-progress stay-only dialog.

## Uncertain

- warning;
- Retry submission;
- Check current Attempt;
- editors frozen;
- no new normal Submit;
- Back shows uncertainty leave warning.

## Leave uncertain

- key/gate state abandoned;
- route returns to Homework detail;
- no new request.

---

# 73. Success / Finalization Screen Tests

## Explicit success

After confirmed returned Attempt:

- Attempt becomes read-only immediately;
- finalization summary:
  ```text
  Submitted by you
  ```
- success notice;
- no answer editors;
- no Submit button;
- saved file Open/Save As may remain in terminal UI;
- Back to Homework works.

## Deadline reconciliation

- terminal read-only;
- label:
  ```text
  Finalized at the Homework deadline
  ```
- no explicit success notice.

## Teacher close reconciliation

Label:

```text
Finalized when the Homework was closed
```

No explicit success notice.

No score/checking values.

---

# 74. Next Attempt Regression

After explicit Submit:

- FE-005 does not show Start another Attempt;
- Back to refreshed Homework detail uses FE-002 server `remaining`/`in_progress_attempt`;
- if server says another Attempt available, existing FE-002 Start button appears there;
- if not, it does not.

No client `remaining--` patch.

---

# 75. Answer/File Regression Tests

Run FE-003/004 tests proving:

- all eight non-file editors still save normally when gate idle;
- file upload still works gate idle;
- dirty/uncertain route guard behavior remains;
- file Open/Save As remains available terminal as contracted;
- Submit gate blocks only mutation starts, not normal rendering.

Do not weaken existing assertions merely to add Submit.

---

# 76. Directly Affected Regression Tests

Run FE-005 tests plus:

```text
test/features/student/student_answer_editor_controller_test.dart
test/features/student/student_answer_editor_screen_test.dart

test/features/student/student_file_answer_controller_test.dart
test/features/student/student_file_answer_screen_test.dart
test/features/student/student_submission_transfer_controller_test.dart

test/features/student/student_homework_attempt_dto_test.dart
test/features/student/student_homework_attempt_data_test.dart
test/features/student/student_homework_attempt_controller_test.dart
test/features/student/student_homework_attempt_screen_test.dart

test/features/student/student_homework_screen_test.dart
test/features/student/student_homework_controller_test.dart
```

Use actual delivered filenames if FE-001…004 naming differs slightly and report the exact mapping.

Do not run the full frontend test suite in this individual task.

---

# 77. Verification

From:

```text
frontend/
```

Run:

```bash
flutter test \
  test/features/student/student_homework_submit_data_test.dart \
  test/features/student/student_homework_submit_readiness_test.dart \
  test/features/student/student_homework_submit_controller_test.dart \
  test/features/student/student_homework_submit_screen_test.dart \
  test/features/student/student_answer_editor_controller_test.dart \
  test/features/student/student_answer_editor_screen_test.dart \
  test/features/student/student_file_answer_controller_test.dart \
  test/features/student/student_file_answer_screen_test.dart \
  test/features/student/student_submission_transfer_controller_test.dart \
  test/features/student/student_homework_attempt_dto_test.dart \
  test/features/student/student_homework_attempt_data_test.dart \
  test/features/student/student_homework_attempt_controller_test.dart \
  test/features/student/student_homework_attempt_screen_test.dart \
  test/features/student/student_homework_screen_test.dart \
  test/features/student/student_homework_controller_test.dart
```

Run format over changed task-owned Dart files:

```bash
dart format --output=none --set-exit-if-changed <changed Dart files>
```

Run:

```bash
flutter analyze
```

Then repository root:

```bash
git diff --check
```

and focused diff/scope self-review.

Do not run:

- full frontend suite;
- target build;
- backend suite;
- broad E2E/integration runner.

Those belong to Frontend Phase 2 / Stage integration.

---

# 78. Acceptance Criteria

PASS only if all are true.

## Submit eligibility

- only confirmed current `in_progress` Attempt;
- disabled during refresh;
- dirty non-file draft blocks;
- active/uncertain answer save blocks;
- selected/active/uncertain file mutation blocks;
- zero unanswered/all unanswered does **not** block;
- no local deadline logic.

## Confirmation

- saved/unanswered count shown;
- zero-answer Submit explicitly supported;
- warns Attempt becomes locked/read-only;
- no Save-all behavior;
- readiness/session/target rechecked after dialog.

## Idempotency

- FE-002 UUID generator reused;
- one key per logical Submit;
- uncertain outcome retains same key;
- Retry uses same key;
- deterministic failure clears key;
- duplicate Submit suppressed;
- no automatic new-key retry.

## Operation gate

- Submit synchronously freezes new answer/file mutations;
- answer/file controllers enforce the gate;
- submitting/uncertain screen is locally read-only;
- gate releases correctly.

## Reconciliation

- valid 200 authoritative Attempt adopted immediately;
- Homework detail/list invalidated;
- deadline/close/not-editable outcomes refresh;
- uncertain Check current:
  - student_submit terminal confirms;
  - auto-finalized terminal reconciles without false success;
  - in_progress remains uncertain.

## Terminal UX

- explicit Submit shows success + `Submitted by you`;
- deadline/close show correct finalization reason;
- no editors/Submit on terminal Attempt;
- no score/checking;
- Start-next remains Homework-detail responsibility.

## Navigation

- submitting route cannot be abandoned;
- uncertain Submit leave warns and discards retry context only on explicit Leave;
- guard priority composes with FE-003/004.

## Scope

- no auto checking/scoring/review;
- no next Attempt creation;
- no new route/dependency/backend/platform change;
- no autosave-all.

## Verification

- focused tests pass;
- named regressions pass;
- format passes;
- `flutter analyze` passes;
- `git diff --check` passes;
- focused self-review passes.

---

# 79. Locked Implementation Decisions

These are decisions, not suggestions:

```text
Submit endpoint = POST /student/attempts/:attempt/submit
Submit Idempotency-Key = FE-002 secure UUID v4 generator
success = HTTP 200 only
Submit body = {}
all/partial/zero answers = allowed
local dirty/selected/uncertain work = must resolve before Submit
Submit never auto-saves answers
confirmation = required
confirmation shows saved/unanswered counts
Submit claims route operation gate before first await
submitting/uncertain = editors frozen
uncertain Submit retry = SAME idempotency key
Check current in_progress = uncertainty remains
Check current student_submit terminal = desired outcome confirmed
deadline/close terminal = authoritative auto-finalization, not explicit success
valid success Attempt = adopted immediately
Homework detail/list = invalidated, not optimistically patched
terminal screen = remain on Attempt route
next Attempt = only through Back to Homework + FE-002
```

Codex must not substitute:

- requiring all Questions answered;
- auto-saving dirty drafts;
- generating a new key on timeout Retry;
- claiming success from an in-progress GET;
- client-created finalization timestamps/status;
- navigating away immediately after success;
- client-side remaining-attempt calculation;
- score/checking UI;
- broad global mutation manager.

---

# 80. Completion Report

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
4. Submit readiness/zero-answer evidence;
5. confirmation evidence;
6. idempotency same-key retry evidence;
7. route operation gate evidence;
8. deadline/close/uncertain reconciliation evidence;
9. authoritative Attempt adoption/cache invalidation evidence;
10. navigation-guard evidence;
11. desktop/mobile/accessibility evidence;
12. FE-003/004 regression evidence;
13. format/analyze results;
14. `git diff --check`;
15. scope/non-goal confirmation;
16. deviations/blockers;
17. final `git status --short`.

Do not claim `Accepted`.

Do not commit/push/create PR/update Stage bookkeeping unless explicitly instructed later.
