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
| Current review baseline | `origin/main @ 291ee97693cf4ba2242ad30cd39371800760e740` |
| Implementation baseline | ChatGPT re-checks/freezes current `origin/main` immediately before Codex starts |
| Readiness Gate | `PENDING — current-main revalidation by ChatGPT required after this correction is merged` |
| Supported surfaces | `Student desktop + mobile` |
| Verification | focused frontend tests + FE-001…004 regressions + format/analyze + diff check |
| Delivery | Codex implements, verifies, reviews, stages approved scope, commits, pushes, creates PR, and stops before merge; Project Owner merges only after ChatGPT acceptance review |
| Implementation branch | `implement/s07-fe-005-submit-finalization-ux` |
| Pre-approved implementation commit | `feat(stage7): add student homework submit ux` |
| Frontend block checkpoint | Stage 7 Frontend Phase 2 immediately after this frontend task block |

Do not create a duplicate `CODEX-PROMPT`.

Implementation delivery after the future Readiness PASS:

```text
Codex:
implementation
-> focused verification
-> focused scope/diff self-review
-> stage only approved task scope
-> git diff --cached --check
-> commit
-> push
-> create PR
-> stop before merge

Project Owner:
merge only after ChatGPT acceptance review
```

Do not update `STAGE_07_TASK_INDEX.md` or other Stage bookkeeping.

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
- post-Submit retained Homework detail refresh and Topic Homework list reconciliation;
- route-operation serialization + route-leave behavior during submitting/uncertain state;
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

The gate exposes controlled operations with exactly these transitions, not an
unrestricted public setter:

```text
initial confirmed Submit:
  idle -> submitting

uncertain result:
  submitting -> submitUncertain

same-key Retry:
  submitUncertain -> submitting

owned Check current:
  gate remains submitUncertain

confirmed success:
  -> idle

deterministic Submit failure:
  -> idle

owned terminal Check reconciliation:
  -> idle

explicit uncertain/checking Leave:
  -> idle

session/target loss:
  -> idle
```

The Submit controller synchronously claims `submitting` before the first await
for both the initial POST and same-key Retry POST. Both are active HTTP Submit
requests, so Back during an active Retry has the same stay-only behavior as the
initial POST.

FE-003/004 mutation controllers read the gate before beginning any new
mutation-capable operation.

They must refuse all new local mutation/reconciliation entry points listed in
Sections 12 and 13 while:

```text
submitting
submitUncertain
```

The gate does not retroactively cancel a mutation that already synchronously
claimed its own FE-003/004 active state before Submit preflight ran. In that
ordering, Submit readiness must observe the active mutation and refuse to claim
the gate.

---

# 12. Modify FE-003 Answer Mutation Gate Check

Delivered:

```text
StudentAttemptAnswerEditorController
```

must require:

```text
routeOperationGate == idle
```

before every new local mutation/reconciliation entry:

```text
updateDraft
discardChanges
clearAnswer
saveAnswer
reloadAttempt
```

`clearLocalState()` for explicit route abandonment/session cleanup remains
allowed while the gate is held.

The corrected FE-003 has no blind PUT retry for an uncertain answer save;
uncertainty is reconciled through authoritative GET and any later Save is a new
explicit mutation.

For Save entry, order must be synchronous:

```text
check routeOperationGate == idle
-> claim FE-003 saving/operation ownership
-> only then perform first await / PUT
```

If Submit already claimed the gate:

- do nothing;
- do not send PUT;
- preserve draft.

Do not cancel an FE-003 mutation that synchronously claimed saving ownership
first; Submit readiness observes that operation and refuses to claim its gate.

Existing answer-save behavior otherwise remains unchanged.

Do not make the answer controller depend on Submit business state beyond this small gate.

---

# 13. Modify FE-004 File Mutation Gate Check

Before every new local mutation/reconciliation entry:

```text
chooseFile
uploadAnswer
confirmed file_upload_failed Retry
discardSelectedFile
reloadAttempt
```

delivered:

```text
StudentFileAnswerController
```

must additionally require:

```text
routeOperationGate == idle
```

`clearLocalState()` for explicit route abandonment/session cleanup remains
allowed while the gate is held.

The corrected FE-004 has no blind PUT retry for uncertain upload; that state is
reconciled through authoritative GET.

For picker/upload entry, order must be synchronous:

```text
check routeOperationGate == idle
-> claim FE-004 selecting/uploading operation ownership
-> only then perform first await / picker / PUT
```

If Submit already claimed the gate:

- do nothing;
- preserve current local state where safe;
- send no upload.

Mutation-first blocks Submit. Submit-first blocks all new FE-003/004 local
mutation/reconciliation operations. Do not introduce a global mutation manager.

During `submitting` and `submitUncertain`, including Submit `checking`,
presentation also disables initiation of new saved-file Open/Save As actions.
It combines existing transfer authority with `gate == idle`; do not make
`StudentSubmissionTransferController` depend on Submit business state. Visible
confirmed answers/files remain displayed.

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

`localStateUnavailable` is required whenever FE-003/004 local state cannot be
proven to belong to the same current:

```text
StudentSessionKey
StudentHomeworkAttemptRouteTarget
authoritative Attempt publication token
Question set
```

as the Attempt data used for Submit readiness.

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

Ready requires all participating states to be aligned to the same current
eligible `StudentSessionKey`, route target and authoritative Attempt publication
token.

The exact normal-ready alignment is:

```text
Attempt state:
  status == data
  attempt != null
  publication token != null
  Attempt/Homework IDs match the current route target
  attempt.status == in_progress

FE-003:
  isEligible == true
  isAuthoritative == true
  sourceAttemptPublication is identical to parent publication token

FE-004:
  isAuthoritative == true
  isTerminal == false
  sourceAttemptPublication is identical to parent publication token
```

Let:

```text
nonFileQuestionIds =
  IDs of every current Attempt Question except file_based

fileQuestionIds =
  IDs of every current file_based Question
```

Require exact Question ownership:

```text
FE-003 state Question IDs == nonFileQuestionIds
FE-004 state Question IDs == fileQuestionIds
```

Map keys and each entry's Question identity/family must agree. No missing, extra,
duplicate, or wrong-family Question state is allowed.

If editor/file state is not initialized yet, belongs to an older Attempt
publication, has a Question-set mismatch, or ownership cannot be proven:

```text
localStateUnavailable
```

The computed readiness must update reactively in presentation.

Submit controller must independently re-check the same required conditions
synchronously immediately before claiming the gate.

UI disabling is not the sole safety boundary.

## 15.1 Parent Attempt Publication Token

Add a focused, opaque identity-only application token such as
`StudentHomeworkAttemptPublicationToken` to `StudentHomeworkAttemptState`.
It proves that an editor state was rebased from this exact authoritative parent
publication. It is neither a backend version nor business state, and must not
expose the controller's `_generation` directly as application state.

Production `StudentHomeworkAttemptController` lifecycle:

```text
successful authoritative GET data publication:
  fresh publication token

acceptAuthoritativeTerminalAttempt(...):
  fresh publication token

refreshing with retained Attempt:
  preserve previous publication token

error with retained Attempt:
  preserve previous publication token

initial/loading without retained authoritative data:
  publication token = null

notFound:
  publication token = null

session loss:
  publication token = null
```

A retained token in `refreshing` or `error` does not grant Submit authority;
normal readiness still requires `status == data`.

## 15.2 FE-003 Source Publication

Add optional `sourceAttemptPublication` to
`StudentAttemptAnswerEditorState`. On complete synchronization from a parent
`status == data` publication, store that exact parent token.

Preserve it across local draft edits and confirmed mutation overlays that still
belong to that parent base. If synchronization preserves unresolved uncertainty
from an older publication, the mixed state must use
`sourceAttemptPublication = null` until a complete authoritative rebase; it must
not falsely claim the newer parent token.

An FE-003-owned reconciliation GET is not automatically a parent publication.
After such an owned in-progress GET, use `sourceAttemptPublication = null`;
Submit remains unavailable until normal parent reconciliation produces an
aligned `data` publication.

## 15.3 FE-004 Source Publication

Add optional `sourceAttemptPublication` to `StudentFileAnswerState`, following
the same complete-parent-rebase rule as FE-003.

A selected local file or confirmed upload overlay may preserve its current
source publication. Unresolved uncertain file state carried across another
parent publication uses `sourceAttemptPublication = null` until a complete
authoritative rebase, rather than claiming the newer token.

After FE-004-owned in-progress reconciliation, use
`sourceAttemptPublication = null`; Submit remains unavailable until parent/local
states are aligned again. Do not duplicate the full
`StudentHomeworkAttempt` in either state object merely for ownership tracking.

---

# 16. Editable Attempt Requirement

The delivered Attempt controller has exactly these load states:

```text
StudentHomeworkAttemptLoadStatus:
  initial
  loading
  data
  refreshing
  notFound
  error
```

There is no `stale` load status, `isStale` property, or `nonStale` property.

No Submit button for:

```text
submitted
waiting_for_teacher_review
checked
```

Do not accept `timed_out_finalized` as Homework.

Submit may be ready only from:

```text
StudentHomeworkAttemptState.status == data
attempt != null
Attempt/Homework IDs match the current route target
attempt.status == in_progress
eligible current Student session
publication token != null
```

Treat all of the following as not ready:

```text
initial
loading
refreshing
error
notFound
session/account reconciliation in progress
```

Use `attemptStateLoading` for unresolved/loading/refreshing lifecycle state where
appropriate and `attemptNotEditable`/`localStateUnavailable` for the other typed
cases according to delivered state shape; do not invent a ready path from
retained data.

Reason:

> An Attempt retained inside `refreshing` or `error` may be reconciling
> deadline/close finalization and is not current mutation authority.

Do not submit against knowingly non-current lifecycle state.

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
isReconciling == true
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
uncertain-upload reconciliation GET in progress
```

Use:

```text
fileUploadInProgress
```

Submit is blocked for unresolved:

```text
uncertain upload
```

Use:

```text
fileUploadUncertain
```

A retained selected file after confirmed `file_upload_failed` or
`validation_failed` remains:

```text
fileSelectionPending
```

until a successful upload or explicit discard resolves the selection. Preserve
FE-004's existing rule that a `validation_failed` selection is local context
only: it cannot be re-uploaded until a newly accepted locally valid selection
replaces it.

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

# 20. Confirmed Answer Snapshot Derivation

Do not create a second independent answer overlay cache.

Only after the publication and exact Question-set alignment in Section 15
passes, derive the current confirmed snapshot directly from FE-003/004 server
bases:

```text
for every non-file Question:
  corresponding FE-003 serverAnswer != null -> confirmed answered
  corresponding FE-003 serverAnswer == null -> unanswered

for every file Question:
  corresponding FE-004 serverFile != null -> confirmed answered
  corresponding FE-004 serverFile == null -> unanswered
```

These existing server bases already represent the latest parent GET base plus
any newer confirmed local mutation response. A confirmed FE-003 clear makes the
Question unanswered; a confirmed FE-003 answer or FE-004 upload not yet returned
by a later GET counts as answered.

When a newer authoritative parent GET is completely rebased into FE-003/004,
its fresh publication supersedes the previous overlay naturally. Do not merge
Attempt answers again or independently reapply an older overlay.

Never count dirty drafts, selected local files, pending mutations, uncertain
mutations, or uncertain uploads. Failed ownership/publication/Question-set
proof yields `localStateUnavailable`, not an invented count.

Require:

```text
0 <= confirmedAnsweredCount <= questionCount
unansweredCount = questionCount - confirmedAnsweredCount
```

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

The button captures a `StudentHomeworkSubmitReadyToken` from the readiness
boundary before opening the dialog. Content uses the confirmed answer-count
snapshot from that token.

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

Create the application-level `StudentHomeworkSubmitReadyToken` inside the
readiness boundary. Before opening the dialog, capture enough identity to prove
it refers to the exact state later submitted:

```text
StudentSessionKey
StudentHomeworkAttemptRouteTarget
parent Attempt publication token
FE-003 state identity/publication
FE-004 state identity/publication
confirmed answer-count snapshot
```

After the dialog returns `true`, the Submit controller must synchronously
recompute/read current readiness and require that the captured token still
matches current state, before claiming a gate or generating a key.

Any change while the dialog was open to the following invalidates confirmation:

```text
session
route target
Attempt publication
Question set
FE-003 state
FE-004 state
dirty/pending/uncertain state
Attempt lifecycle
```

If the captured token no longer matches or current readiness is blocked:

- send no POST;
- claim no Submit gate;
- generate no Submit key;
- close dialog normally;
- render the current UI.

The Student may press Submit again and confirm the new snapshot. Presentation
also checks that its context is mounted, but Widget `mounted` alone never proves
session, target, publication, or local-state ownership. A deadline/close may
occur while the dialog is open.

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

After confirmation and successful captured-ready-token validation against current
readiness, before the first await:

- generate exactly one new UUID;
- retain it through the logical Submit operation.

## Confirmed success

Clear key only after authoritative terminal Attempt adoption succeeds, then
release the route gate as specified in Section 39.

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

`StudentHomeworkSubmitDto.fromJson(...)` must receive:

```text
expectedAttemptId
expectedHomeworkId
```

Parse `data` through the delivered FE-002:

```text
StudentHomeworkAttemptDto
```

Do not duplicate Attempt parsing.

Reject extra top-level keys.

Apply all Section 29 semantic checks inside this DTO boundary. Compare IDs
case-insensitively only after canonical UUID validation.

---

# 29. Submit Success Semantic Validation

For requested route target require:

```text
returned attempt.id == target.attemptId
returned attempt.assessmentId == target.homeworkId
```

A valid successful Submit/replay `200` must prove the same logical explicit
Student Submit.

Require:

```text
status in:
  submitted
  waiting_for_teacher_review
  checked

finalizationReason = studentSubmit
submittedAt != null
finalizedAt == submittedAt
```

The corrected FE-002 Attempt parser already enforces the general timestamp/
deadline consistency.

`waiting_for_teacher_review` / `checked` are allowed only as later lifecycle
progression of the same originally explicit `student_submit`; they do not relax
the required finalization reason.

Reject as malformed success, for example:

```text
status = in_progress
finalizationReason = homeworkDeadline
finalizationReason = taskClosed
submittedAt = null
```

even if the transport status is `200`.

Any malformed/inconsistent `200` becomes:

```text
ApiFailureKind.invalidResponse
=> uncertain outcome
=> retain SAME Idempotency-Key
```

because the backend finalization may already have committed.

The Submit controller must defensively repeat the typed result checks before
authoritative adoption. An invalid injected repository result must also become
`ApiFailureKind.invalidResponse` / uncertain with the same key retained; it must
never produce local success.

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
  String expectedHomeworkId,
  String idempotencyKey,
)
```

Validate all three UUID inputs before transport. Pass `attemptId` and
`expectedHomeworkId` to the Submit DTO as `expectedAttemptId` and
`expectedHomeworkId` for response ownership validation.

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
  String expectedHomeworkId,
  String idempotencyKey,
)
```

The repository implementation forwards all three inputs unchanged. The
controller passes exactly:

```text
target.attemptId
target.homeworkId
pendingIdempotencyKey
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
checking
failure
completed
reconciledTerminal
```

Meaning:

```text
completed
  = current logical Submit is proven successful by a valid same-key/new Submit
    HTTP 200 response

reconciledTerminal
  = authoritative GET proves the Attempt is terminal, but does not prove that
    this current logical Submit operation produced that terminal state
```

State may include typed:

```text
failure?
notice?
terminalReconciliationReason?
```

Use a typed reconciliation reason such as:

```text
studentSubmitAlreadyTerminal
homeworkDeadlineAutoFinalized
taskClosedAutoFinalized
```

Do not use display strings as control values.

Do not expose raw idempotency key to Widget state.

---

# 33. Submit Controller Preflight

After confirmation returns `true`, `submitConfirmed(capturedReadyToken)` or
equivalent must perform exactly this order synchronously before transport:

1. validate the captured `StudentHomeworkSubmitReadyToken` against current
   readiness;
2. verify current eligible `StudentSessionKey`;
3. verify current route target;
4. verify parent Attempt load status `data`;
5. verify a non-null matching current `in_progress` Attempt;
6. verify current non-null parent publication token;
7. verify FE-003/004 publication identity and exact Question-set ownership;
8. verify no FE-003 dirty/saving/uncertain/reconciling work;
9. verify no FE-004 selection/selecting/uploading/uncertain/reconciling work;
10. verify route operation gate `idle`;
11. generate exactly one new Idempotency-Key;
12. synchronously claim `gate = submitting`;
13. publish Submit state `submitting`;
14. only then perform the first await / POST.

Any failed precondition means no key generation, no gate claim, and no POST.
An Attempt retained under `refreshing` or `error` is not Submit authority.
Same-key Retry uses the separate owned transition in Section 37.

The FE-003/004 mutation entry points must symmetrically claim their own
saving/selecting/uploading states synchronously after checking `gate == idle`
and before their first await.

Thus in the single Flutter isolate:

```text
answer/file operation claims first
=> Submit preflight sees blocker and sends no POST

Submit claims gate first
=> later answer/file operation sees non-idle gate and sends no PUT/picker
```

No interleaving window is left to a Widget-only check.

---

# 34. Duplicate Submit Suppression

While:

```text
submitting
uncertain
checking
```

do not start another logical Submit.

During `uncertain`, actions are:

```text
Retry submission
Check current Attempt
```

but exactly one resolution operation may be active at a time.

During `checking`, disable both duplicate Check and Retry until that owned GET
finishes.

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

When either Retry or Check starts, disable the other action until the current
resolution operation completes.

While uncertain/checking:

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
same expected Homework ID
same Idempotency-Key
same body {}
```

No new key.

Before the first await / POST:

```text
verify current logical-operation ownership
synchronously switch gate submitUncertain -> submitting
publish Submit state = submitting
claim a new Submit-resolution generation
```

Bind the generation to:

```text
StudentSessionKey
StudentHomeworkAttemptRouteTarget
pending Idempotency-Key
logical Submit generation
```

While Retry is in flight, Check and duplicate Retry are disabled. The gate is
`submitting`, so Back uses the same stay-only dialog as the initial POST.

If valid `200`:

- apply the confirmed success ordering in Section 39, including invalidation of
  older Check generations and terminal adoption before gate release.

If another uncertain result:

- retain the same key;
- return to state `uncertain` and gate `submitUncertain`.

If deterministic lifecycle result:

- invalidate resolution generation;
- release gate/key;
- reconcile authoritative Attempt.

This exact same-key retry behavior requires a controller test.

---

# 38. Owned `Check Current Attempt` Reconciliation

The uncertain state uses only:

```text
StudentHomeworkAttemptRepository.fetchAttempt(target.attemptId)
```

FE-005 owns this resolution operation. A normal unrelated parent refresh is not
proof for the logical Submit.

`checkCurrentAttempt()` (or equivalent) binds one check generation to:

```text
StudentSessionKey
StudentHomeworkAttemptRouteTarget
pending Idempotency-Key
logical Submit generation
check generation
```

Before the GET:

```text
status = checking
gate remains submitUncertain
Retry submission disabled
duplicate Check disabled
```

Only the completion owned by this check generation may resolve the Submit
state. Prove the current eligible session, route target, pending key, logical
Submit generation, check generation, and matching Attempt/Homework IDs before
consuming the result.

A late Check completion is ignored after:

```text
valid Retry/new Submit 200 success
deterministic Submit resolution
explicit uncertain-route Leave
session change
route-target change
controller disposal
newer Check generation
```

After the owned authoritative GET:

## Attempt terminal with `student_submit`

This proves the **Attempt is explicitly submitted**, but by itself does not prove
that the current pending Idempotency-Key/logical client operation caused that
terminal state; another device/request could have won the race.

Actions:

- prove the terminal status and `studentSubmit` finalization reason;
- call `acceptAuthoritativeTerminalAttempt(...)` while the gate remains
  `submitUncertain` and require acceptance succeeds;
- only after adoption, clear pending key;
- publish state `reconciledTerminal`;
- release gate;
- typed reason:
  ```text
  studentSubmitAlreadyTerminal
  ```
- show neutral terminal notice such as:
  ```text
  This Attempt is already submitted.
  ```
- do **not** show the current-operation success notice:
  ```text
  Attempt submitted successfully.
  ```

The user's desired terminal outcome is achieved, so no retry is necessary.

## Attempt terminal due:

```text
homework_deadline_auto_submit
task_closed_auto_finalize
```

Actions:

- prove the terminal status and `homeworkDeadline` / `taskClosed` reason;
- call `acceptAuthoritativeTerminalAttempt(...)` while the gate remains
  `submitUncertain` and require acceptance succeeds;
- only after adoption, clear pending key;
- publish state `reconciledTerminal`;
- release gate;
- set the corresponding typed reconciliation reason;
- show the authoritative finalization reason;
- do not show explicit Student Submit success.

## Attempt remains `in_progress`

Do **not** conclude that the original Submit definitely failed.

Actions:

```text
status = uncertain
retain same Idempotency-Key
gate remains submitUncertain
```

`Retry submission` remains the durable-idempotency resolution path.

## Check GET is itself non-authoritatively failed/uncertain

Return to:

```text
status = uncertain
retain same Idempotency-Key
gate remains submitUncertain
```

and allow a later Retry submission or another Check.

Do not allow an ordinary parent refresh to resolve the logical Submit state.
Terminal adoption must precede gate release. A failed adoption cannot publish
terminal reconciliation; obsolete operation/session/target ownership adopts
nothing and publishes no completion or navigation.

---

# 39. Confirmed Submit Success

On a valid Submit/replay `200` satisfying Section 29:

1. invalidate older Check/retry resolution generations;
2. call `acceptAuthoritativeTerminalAttempt(returnedAttempt)` under current
   session/target/operation ownership while the gate remains held;
3. require acceptance succeeds;
4. clear pending Idempotency-Key;
5. publish state `completed`;
6. release route operation gate;
7. start retained Homework detail refresh;
8. mark Topic Homework list stale as specified in Section 41.

The terminal parent publication reconciles FE-003/004 local editor state. Its
adoption must precede gate release so there is no `gate = idle` interval with an
editable `in_progress` parent. Remain on the Attempt route and show:

```text
Attempt submitted successfully.
```

If session/target/operation ownership is obsolete, adopt nothing, publish no
success, and navigate nowhere. Failed authoritative adoption cannot complete
the Submit.

Do not automatically navigate away.

Do not automatically start the next Attempt.

---

# 40. Authoritative Attempt Adoption

Reuse the delivered method:

```text
StudentHomeworkAttemptController.acceptAuthoritativeTerminalAttempt(...)
```

The caller owns semantic proof. Before confirmed Submit/retry `200` adoption,
FE-005 must prove:

```text
current route target matches
current Student session matches
current logical-operation/resolution ownership matches
attempt.id == target.attemptId
attempt.assessmentId == target.homeworkId
attempt.status is terminal
attempt.finalizationReason == studentSubmit
attempt.submittedAt != null
attempt.finalizedAt == attempt.submittedAt
```

For owned Check-current terminal reconciliation, FE-005 must first prove:

```text
current owned Check generation and logical-operation ownership
matching Attempt/Homework IDs
terminal status
finalization reason in studentSubmit / homeworkDeadline / taskClosed
```

The existing parent method provides current-session/target validation,
terminal-only acceptance, old parent GET generation invalidation, and immediate
`data` publication without another request. That terminal publication receives
a fresh identity-only parent publication token.

Do not create `adoptAuthoritativeAttempt(...)`, a separate adoption architecture,
or another generic arbitrary model injection API. Do not broaden the delivered
method into an arbitrary-state setter. Require successful terminal adoption
while the Submit gate remains held before clearing the key or releasing gate.

---

# 41. Homework Read Reconciliation After Success

After terminal Attempt adoption, use the delivered retained refresh:

```text
StudentHomeworkDetailController.refresh()
```

Do not use destructive
`ref.invalidate(studentHomeworkDetailControllerProvider(...))` immediately after
successful Submit. Matching retained Homework detail must remain available for
the terminal Attempt header during refresh and retained error.

For the Topic Homework list, when its provider exists, call:

```text
markAuthoritativeRowsStale(currentSessionKey)
```

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
inProgressAttempt
```

Backend remains authoritative.

---

# 41A. Deterministic Resolution Ownership

Before handling any deterministic Submit failure after the logical operation has
started:

- invalidate the current Submit resolution/check generation;
- ensure a late Retry/Check completion cannot publish;
- then apply the specific key/gate/reconciliation behavior below.

Session/target loss remains stronger and clears all Submit operation ownership.

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

On:

```text
422 validation_failed
```

The frontend always sends:

```text
UUID Idempotency-Key
{}
```

so a backend validation rejection indicates contract/client mismatch.

Actions:

- clear key/gate;
- state failure;
- refresh current Attempt;
- show:
  ```text
  The submission request could not be validated. Refresh and try again.
  ```
- do not display field internals as a Student answer validation issue.

Do not automatically retry or generate a replacement key inside the same
logical operation. A later new Submit is possible only after current parent
`data` and complete FE-003/004 publication alignment again prove readiness.

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

- invalidate logical Submit/check/retry generation;
- clear pending Submit key;
- release gate;
- clear Submit state ownership;
- no completion/navigation/notice from stale response.

Do not carry pending Submit state into a future session.

---

# 50. Submission Does Not Require All Answers

The Submit controller must not inspect Question-specific validity to require answers.

Alongside the session/route/publication readiness requirements, it requires:

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

When route operation gate is:

```text
submitting
submitUncertain
```

including owned Submit controller `checking` while the gate remains
`submitUncertain`, the FE-003/004 presentation must remain locally read-only:

```text
FE-003 canEdit = false
FE-003 canSave = false

FE-004 canChoose = false
FE-004 canUpload = false
FE-004 canDiscard = false
```

Do not clear visible confirmed answers or files. Use the existing enable/disable
inputs on `student_question_answer_editor.dart` and
`student_file_answer_editor.dart`; those child Widgets are not expected to
change. A concrete compile blocker requiring their modification is `BLOCKED`,
not permission to broaden scope.

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

Disable initiation of new Open / Save As actions while the gate is non-idle.
Presentation may combine `existing transfer authority && gate == idle`; do not
make `StudentSubmissionTransferController` depend on Submit business state.

Disable the ordinary AppBar Attempt refresh while the gate is non-idle. During
Submit uncertainty, only owned `Check current Attempt` may resolve the logical
Submit. No package/router changes.

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

FE-002 terminal read-only shell remains the base. A confirmed FE-003 terminal
Attempt for the current session and route stays visible when matching Homework
detail is retained under `data`, `refreshing`, or `error`. Require the retained
Homework to match both `target.homeworkId` and `target.topicId`.

Thus terminal adoption followed by retained Homework refresh keeps the terminal
Attempt visible through refresh success or failure with matching retained data.
Retained Homework error is not authority for a new Submit. Homework `notFound`,
session loss, and route-target mismatch remain stronger and must not fabricate
Homework context. Ordinary `in_progress` Attempt loading/error authority rules
remain unchanged.

Avoid rendering Status/Submitted/Finalized/Reason twice. Freeze the composition:

```text
in_progress main Attempt card:
  Homework title
  Attempt number
  Status = In progress
  Started
  Deadline

terminal main Attempt card:
  Homework title
  Attempt number
  Started
  Deadline
```

The terminal `StudentAttemptFinalizationSummary` alone renders:

```text
Attempt finalized
Status
Submitted at, when explicit
Finalized at
Finalization reason
```

Human labels:

```text
studentSubmit
  -> Submitted by you

homeworkDeadline
  -> Finalized at the Homework deadline

taskClosed
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

The existing AppBar action already provides:

```text
Back to Homework
```

Do not add a duplicate return or Start-next flow.

The FE-001/002 Homework detail refresh then decides from server state whether:

```text
Start Attempt
```

is available.

Do not duplicate attempts remaining logic in the terminal screen.

---

# 57. Back / Route Leave During `submitting`

While the initial HTTP Submit or same-key Retry request is active, the gate is:

```text
submitting
```

Block route leave.

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

When the gate is:

```text
submitUncertain
```

including owned Submit controller `checking`, allow leaving only after explicit
warning:

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

- invalidate Submit logical/check/retry generations;
- clear pending key;
- release gate;
- clear current Submit controller operation;
- clear FE-003 local state;
- clear FE-004 local state;
- navigate back to Homework detail.

Send no request. On Stay, preserve all operation/key/gate/local state.

---

# 59. Route Leave Guard Priority

FE-005 extends the existing single FE-003/004 Attempt PopScope guard.

Use exactly:

1. active Submit POST (`gate == submitting`, including Retry): stay-only
   "Submission is in progress" dialog; route cannot leave;
2. `checking` or `submitUncertain`: Submit uncertainty warning, Stay / Leave;
3. file upload uncertainty;
4. non-file answer save uncertainty;
5. pending selected file or dirty non-file draft;
6. clean leave.

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

Open confirmation using the snapshot from the current
`StudentHomeworkSubmitReadyToken`. After confirmation returns `true`, pass the
captured token to the controller for the synchronous Section 33 preflight. If
session, target, parent publication, Question set, FE-003/004 state,
dirty/pending/uncertain state, or lifecycle changed, close the dialog and render
the current UI without key generation, gate claim, or POST. The Student may
press Submit again to confirm the new snapshot. Widget `mounted` alone is not
sufficient proof.

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

## Modify production

```text
frontend/lib/features/student/domain/student_homework_attempt_repository.dart

frontend/lib/features/student/data/student_homework_attempt_remote_data_source.dart
frontend/lib/features/student/data/student_homework_attempt_repository_impl.dart

frontend/lib/features/student/application/student_homework_attempt_state.dart
frontend/lib/features/student/application/student_homework_attempt_controller.dart
frontend/lib/features/student/application/student_attempt_answer_editor_state.dart
frontend/lib/features/student/application/student_attempt_answer_editor_controller.dart
frontend/lib/features/student/application/student_file_answer_state.dart
frontend/lib/features/student/application/student_file_answer_controller.dart

frontend/lib/features/student/presentation/student_homework_attempt_screen.dart
frontend/lib/features/student/presentation/student_homework_formatters.dart
```

The parent controller change adds publication-token support and reuses its
existing `acceptAuthoritativeTerminalAttempt(...)`. Do not replace that boundary
with another adoption architecture.

The existing enable/disable inputs are sufficient; these files are not expected
to change:

```text
frontend/lib/features/student/presentation/student_question_answer_editor.dart
frontend/lib/features/student/presentation/student_file_answer_editor.dart
```

If a concrete compile blocker proves otherwise, return `BLOCKED`; do not broaden
presentation architecture silently.

## Modify compatibility/regression tests

Adding `submitAttempt(String attemptId, String expectedHomeworkId,
String idempotencyKey)` to the repository explicitly permits fake/interface
compatibility changes in exactly:

```text
frontend/test/features/student/student_homework_attempt_start_controller_test.dart
frontend/test/features/student/student_homework_attempt_controller_test.dart
frontend/test/features/student/student_homework_attempt_screen_test.dart
frontend/test/features/student/student_homework_attempt_routing_test.dart
frontend/test/features/student/student_homework_screen_test.dart
frontend/test/features/student/student_answer_editor_controller_test.dart
frontend/test/features/student/student_answer_editor_screen_test.dart
frontend/test/features/student/student_file_answer_controller_test.dart
frontend/test/features/student/student_file_answer_screen_test.dart
```

The focused publication, gate, terminal-rendering, and navigation regressions
required below also belong in the already listed applicable test files. When a
regression does not exercise Submit, add only a fail-fast implementation
equivalent to:

```dart
throw StateError(
  'This regression must not submit a Student Homework Attempt.',
);
```

Do not weaken any existing assertion. Do not add unlisted test files.

No route path changes required.

No backend/pubspec/pubspec.lock/router/platform files.

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

Verify the remote data source, repository, and implementation accept all three
arguments and validate `attemptId`, `expectedHomeworkId`, and `idempotencyKey` as
UUIDs before transport. Invalid input sends no request. The DTO receives both
expected IDs; comparison is case-insensitive only after canonical UUID validation.

Reject:

- wrong Attempt ID;
- wrong Homework assessment ID;
- returned `in_progress`;
- returned deadline/close finalization reason under HTTP 200;
- terminal response without `student_submit`;
- missing/null submitted timestamp for successful explicit Submit;
- finalized timestamp different from the submitted timestamp;
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

The directly affected parent/editor/file controller tests must prove:

- every successful authoritative parent GET `data` publication has a fresh
  identity-only token;
- retained `refreshing` and retained `error` preserve the previous token;
- initial/loading without retained authoritative data, `notFound`, and session
  loss clear the token;
- terminal acceptance creates a fresh token and defeats an older parent GET;
- FE-003 and FE-004 source tokens align with a complete parent `data` rebase;
- local drafts/selections and confirmed overlays preserve their parent token;
- mixed state preserving older uncertainty uses a null source token and cannot
  falsely claim a new parent publication;
- FE-003/004-owned in-progress reconciliation does not itself create parent
  alignment, and Submit waits for a complete normal parent rebase.

`student_homework_submit_readiness_test.dart` must cover independently:

```text
ready clean data in_progress with current session/route and aligned publications
terminal attempt
initial
loading
refreshing
error including retained Attempt
notFound
missing Attempt or wrong route IDs
ineligible or changed Student session
null parent publication
dirty non-file
saving non-file
uncertain/reconciling non-file
pending file selection
selecting/uploading/reconciling file
uncertain file
FE-003 state not initialized
FE-004 state not initialized
editor/file state from older Attempt publication
mismatched FE-003 source publication
mismatched FE-004 source publication
FE-003 ineligible or non-authoritative
FE-004 non-authoritative or terminal
wrong non-file Question set
wrong file Question set
missing/extra/duplicate/wrong-family Question state
local state unavailable
```

Verify zero answered remains:

```text
ready
```

when no local blockers exist.

Only after exact publication and Question-set alignment, verify confirmed counts
come from FE-003 `serverAnswer` and FE-004 `serverFile`, without a second overlay
cache:

- Attempt base answer;
- FE-003 newly confirmed owned non-file answer not yet reflected in GET;
- FE-003 confirmed clear;
- FE-004 newly confirmed owned file;
- newer authoritative GET supersedes/rebases older overlays;
- stale/unowned overlay cannot override newer GET and blocks via
  `localStateUnavailable`;
- local dirty value ignored;
- selected file ignored;
- uncertain mutation/file snapshot ignored.

Require `0 <= confirmedAnsweredCount <= questionCount` and
`unansweredCount = questionCount - confirmedAnsweredCount`.

---

# 68. Submit Controller Tests

`student_homework_submit_controller_test.dart` covers:

## Success

- deterministic injected UUID;
- one repository call with the exact target Attempt ID, Homework ID, and key;
- gate synchronously claims `submitting`;
- fully validated 200 `studentSubmit` terminal response;
- older Check/retry resolution generation invalidated before terminal adoption;
- parent terminal adoption through `acceptAuthoritativeTerminalAttempt(...)`
  while the gate is still held, before pending-key clearing or gate release;
- old parent GET cannot overwrite the adopted terminal publication;
- only then pending key cleared, `completed` published, and gate released;
- retained Homework detail `refresh()` and existing Topic Homework list
  `markAuthoritativeRowsStale(currentSessionKey)` reconciliation.

## Obsolete confirmation token

For each captured session, route target, parent publication, Question set,
FE-003/004 state identity/publication, count snapshot, dirty/pending/uncertain
state, or lifecycle change while confirmation is open:

- no key generated;
- no gate claimed;
- no POST;
- current UI can offer a fresh confirmation when readiness returns.

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
- Retry synchronously changes `submitUncertain -> submitting` before its first
  await and claims a new resolution generation;
- success;
- generator called once.

## 500/connection

Same uncertain same-key behavior.

## Invalid success payload

Classified uncertain.

Same key retained.

Cover at minimum:

- HTTP 200 with deadline reason;
- HTTP 200 with close reason;
- HTTP 200 terminal without `student_submit`;
- HTTP 200 missing explicit submitted timestamp;
- wrong Attempt/Homework ID or inconsistent finalization timestamp;
- invalid typed result from an injected repository, independently of DTO parsing.

Each is uncertain, retains the same key, and cannot adopt local success.

## Check-current ownership

- uncertain -> Check claims `checking`;
- Check keeps the gate `submitUncertain`;
- Retry disabled while Check active;
- duplicate Check ignored;
- stale Check `in_progress` completion after a newer valid Retry 200 is ignored;
- stale Check completion after Leave/session/target change is ignored.

An unrelated parent refresh cannot resolve the logical Submit uncertainty.

## Deterministic 409

Key/gate cleared.

Correct refresh path triggered.

## deadline

Attempt/Homework refresh.

No explicit success notice.

## idempotency reuse

No automatic new key.

## Deterministic validation failure

For `422 validation_failed`, prove key clearing, gate release, failure state,
current Attempt refresh, and the exact notice:

```text
The submission request could not be validated. Refresh and try again.
```

No automatic retry or replacement key. A new logical Submit waits for a current
`data` publication and aligned FE-003/004 state.

## session/target stale completion

Cannot adopt/navigate/publish success.

Gate/key cleared on session ownership loss.

---

# 69. Operation Gate Regression Tests

Add focused tests proving:

## Submit claims first

Submit synchronously sets:

```text
gate = submitting
```

before first await.

Then every FE-003 entry is refused:

```text
updateDraft
discardChanges
clearAnswer
saveAnswer
reloadAttempt
```

and every FE-004 entry is refused:

```text
chooseFile
uploadAnswer
confirmed file_upload_failed Retry
discardSelectedFile
reloadAttempt
```

Assert no local edit/discard, picker, PUT, or reconciliation GET starts. Apply
these assertions with gate `submitting` and `submitUncertain`, including Submit
controller `checking`. `clearLocalState()` remains available for explicit
abandonment/session cleanup.

## Answer save claims first

FE-003 synchronously claims `saving` before its first await/PUT.

Then Submit preflight:

```text
blocked
does not claim gate
sends no POST
```

## File operation claims first

FE-004 synchronously claims `selecting` or `uploading` before its first await.

Then Submit preflight:

```text
blocked
does not claim gate
sends no POST
```

## Uncertain/reconciliation state already active

FE-003/004 uncertainty or reconciliation blocks Submit.

## Retry and Check gate transitions

Retry synchronously changes `submitUncertain -> submitting` before POST. Another
uncertain Retry restores `submitUncertain` with the same key. Check holds
`submitUncertain`; Check and Retry cannot overlap. Controlled gate operations
release ownership only at the specified success/failure/terminal-Check/Leave/
session-target-loss boundaries; there is no unrestricted public setter.

This is application-layer behavior, not Widget-only disabling.

Use controlled completers; no arbitrary sleeps.

---

# 70. Uncertain Check-Current Tests

Controller/widget tests cover:

For each allowed owned terminal Check result (`studentSubmit`,
`homeworkDeadline`, or `taskClosed`), assert
`acceptAuthoritativeTerminalAttempt(...)` succeeds while the gate remains held;
only then clear the key, publish `reconciledTerminal`, and release the gate.

## GET returns `student_submit` terminal

- uncertainty clears;
- key/gate clears;
- state = `reconciledTerminal`, not `completed`;
- typed reason = `studentSubmitAlreadyTerminal`;
- neutral "already submitted" notice;
- no current-operation success notice.

## GET returns deadline terminal

- uncertainty clears;
- state = `reconciledTerminal`;
- no explicit success notice;
- deadline finalization displayed.

## GET returns close terminal

Same authoritative `reconciledTerminal` auto-finalization behavior.

## GET remains in_progress

- state returns from `checking` to `uncertain`;
- gate remains `submitUncertain`;
- key retained;
- Retry still uses same key.

## Check ownership and failure

Check calls `fetchAttempt(target.attemptId)` and binds session, target, pending
key, logical Submit generation, and check generation. A mismatched/invalid
result or failed Check cannot create success or a replacement key. Only a
current owned terminal result with a matching Attempt/Homework and an allowed
finalization reason is adopted through the delivered terminal boundary.

## Check/Retry race suppression

- Check active => Retry disabled;
- Retry active => Check disabled;
- late older Check cannot overwrite newer Retry success;
- late Check after Leave/session/target invalidation is ignored.

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

## Non-data parent / local-state mismatch

Submit is disabled for `initial`, `loading`, `refreshing`, `error`, and
`notFound`, even with a retained Attempt; a missing/mismatched publication or
Question set also blocks it.

`localStateUnavailable` has a safe blocker message and opens no confirmation.

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

Uses the captured ready token and its count snapshot; the controller
synchronously validates it against current readiness after confirmation.

## State changed while dialog open

For a changed session, route, publication, Question set, FE-003/004 state,
dirty/pending/uncertain condition, or Attempt lifecycle before confirmation
returns:

- no key;
- no gate claim;
- no POST;
- dialog closes and current UI is rendered.

---

# 72. Submitting / Uncertain Screen Tests

Verify:

## Submitting

- progress;
- editors frozen;
- file mutation controls disabled;
- Open/Save As initiation and ordinary AppBar Attempt refresh disabled;
- Submit button not duplicated;
- Back action shows in-progress stay-only dialog.

The same stay-only behavior applies during an active same-key Retry POST.

## Uncertain

- warning;
- Retry submission;
- Check current Attempt;
- editors frozen;
- no new normal Submit;
- Open/Save As initiation and ordinary AppBar Attempt refresh disabled;
- Back shows uncertainty leave warning.

## Checking current Attempt

- checking/busy state;
- duplicate Check disabled;
- Retry disabled until Check completes;
- editors remain frozen;
- Open/Save As initiation and ordinary AppBar Attempt refresh disabled;
- gate remains `submitUncertain`.

## Leave uncertain/checking

- logical/check/retry generations invalidated;
- key/gate/Submit operation state cleared;
- FE-003 and FE-004 local state cleared;
- route returns to Homework detail;
- no new request.

Stay preserves all state. One PopScope applies the exact priority: active Submit
POST, Submit checking/uncertainty, file uncertainty, answer uncertainty, pending
file or dirty draft, then clean leave. No stacked dialogs.

---

# 73. Success / Finalization Screen Tests

## Retained Homework detail

After terminal adoption and retained Homework refresh, terminal UI remains
visible when matching Homework detail is `data`, `refreshing`, or retained
`error`; it also remains visible after refresh succeeds. Both Homework ID and
Topic ID must match. `notFound`, session loss, and target mismatch retain their
stronger guards; do not fabricate terminal context. Ordinary `in_progress`
loading/error authority rules remain unchanged.

## One finalization summary

Assert terminal Status, Submitted at when explicit, Finalized at, and Reason
appear only in `StudentAttemptFinalizationSummary`. The terminal main card keeps
Homework title, Attempt number, Started, and Deadline. The in-progress main card
also displays `Status = In progress`. Exact reason labels appear once; no
duplicate finalization fields or Start-next flow are added.

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

## Check-current finds already `student_submit`

- terminal read-only;
- state uses reconciled/already-submitted notice;
- finalization summary may still label:
  ```text
  Submitted by you
  ```
  from the authoritative reason;
- no current-operation:
  ```text
  Attempt submitted successfully.
  ```
  notice.

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
- a non-idle Submit gate freezes all specified local mutation/reconciliation
  entry points and transfer initiation, while confirmed answer/file rendering
  remains visible;
- transfer controller retains its existing authority contract; presentation
  combines that authority with `gate == idle`.

Do not weaken existing assertions merely to add Submit.

---

# 76. Directly Affected Regression Tests

Run FE-005 tests plus:

```text
test/features/student/student_answer_mutation_data_test.dart
test/features/student/student_answer_editor_controller_test.dart
test/features/student/student_answer_editor_screen_test.dart

test/features/student/student_file_answer_data_test.dart
test/features/student/student_file_answer_controller_test.dart
test/features/student/student_file_answer_screen_test.dart
test/features/student/student_submission_transfer_controller_test.dart

test/features/student/student_homework_attempt_dto_test.dart
test/features/student/student_homework_attempt_data_test.dart
test/features/student/student_homework_attempt_start_controller_test.dart
test/features/student/student_homework_attempt_controller_test.dart
test/features/student/student_homework_attempt_screen_test.dart
test/features/student/student_homework_attempt_routing_test.dart

test/features/student/student_homework_screen_test.dart
test/features/student/student_homework_controller_test.dart
```

If delivered FE-001…004 materially do not contain these approved boundaries,
return `BLOCKED` for dependency-contract mismatch instead of silently remapping
verification.

Do not run the full frontend test suite in this individual task.

---

# 77. Verification

Run from:

```text
frontend/
```

## 77.1 Focused FE-005 + directly affected FE-004/003/002/001 regressions

Exactly:

```bash
flutter test \
  test/features/student/student_homework_submit_data_test.dart \
  test/features/student/student_homework_submit_readiness_test.dart \
  test/features/student/student_homework_submit_controller_test.dart \
  test/features/student/student_homework_submit_screen_test.dart \
  test/features/student/student_answer_mutation_data_test.dart \
  test/features/student/student_answer_editor_controller_test.dart \
  test/features/student/student_answer_editor_screen_test.dart \
  test/features/student/student_file_answer_data_test.dart \
  test/features/student/student_file_answer_controller_test.dart \
  test/features/student/student_file_answer_screen_test.dart \
  test/features/student/student_submission_transfer_controller_test.dart \
  test/features/student/student_homework_attempt_dto_test.dart \
  test/features/student/student_homework_attempt_data_test.dart \
  test/features/student/student_homework_attempt_start_controller_test.dart \
  test/features/student/student_homework_attempt_controller_test.dart \
  test/features/student/student_homework_attempt_screen_test.dart \
  test/features/student/student_homework_attempt_routing_test.dart \
  test/features/student/student_homework_screen_test.dart \
  test/features/student/student_homework_controller_test.dart
```

Narrow single-test diagnostic reruns are allowed only to diagnose/confirm a
concrete failure.

## 77.2 Exact Dart format check

Exactly:

```bash
dart format --output=none --set-exit-if-changed \
  lib/features/student/domain/student_homework_submit.dart \
  lib/features/student/domain/student_homework_attempt_repository.dart \
  lib/features/student/data/dto/student_homework_submit_dto.dart \
  lib/features/student/data/student_homework_attempt_remote_data_source.dart \
  lib/features/student/data/student_homework_attempt_repository_impl.dart \
  lib/features/student/application/student_attempt_route_operation_gate.dart \
  lib/features/student/application/student_homework_submit_readiness.dart \
  lib/features/student/application/student_homework_submit_state.dart \
  lib/features/student/application/student_homework_submit_controller.dart \
  lib/features/student/application/student_homework_attempt_state.dart \
  lib/features/student/application/student_homework_attempt_controller.dart \
  lib/features/student/application/student_attempt_answer_editor_state.dart \
  lib/features/student/application/student_attempt_answer_editor_controller.dart \
  lib/features/student/application/student_file_answer_state.dart \
  lib/features/student/application/student_file_answer_controller.dart \
  lib/features/student/presentation/student_homework_submit_controls.dart \
  lib/features/student/presentation/student_attempt_finalization_summary.dart \
  lib/features/student/presentation/student_homework_attempt_screen.dart \
  lib/features/student/presentation/student_homework_formatters.dart \
  test/features/student/student_homework_submit_data_test.dart \
  test/features/student/student_homework_submit_readiness_test.dart \
  test/features/student/student_homework_submit_controller_test.dart \
  test/features/student/student_homework_submit_screen_test.dart \
  test/features/student/student_answer_editor_controller_test.dart \
  test/features/student/student_answer_editor_screen_test.dart \
  test/features/student/student_file_answer_controller_test.dart \
  test/features/student/student_file_answer_screen_test.dart \
  test/features/student/student_homework_attempt_start_controller_test.dart \
  test/features/student/student_homework_attempt_controller_test.dart \
  test/features/student/student_homework_attempt_screen_test.dart \
  test/features/student/student_homework_attempt_routing_test.dart \
  test/features/student/student_homework_screen_test.dart
```

This command includes every expected created/modified Dart file, including
publication state and fake/interface compatibility files. Do not add unchanged
files merely for volume or select unreviewed state refactors/files.

## 77.3 Static analysis

Exactly:

```bash
flutter analyze
```

## 77.4 Diff hygiene

From repository root exactly:

```bash
git diff --check
```

Then perform the focused diff/scope self-review required by root/frontend
`AGENTS.md`.

Do not run:

- full frontend suite;
- frontend build;
- backend suite;
- Stage 7 E2E;
- Frontend Phase 2.

Those follow after FE-005 acceptance/delivery.

---

# 78. Acceptance Criteria

PASS only if all are true.

## Submit eligibility

- parent status exactly `data`, non-null matching `in_progress` Attempt, current
  eligible Student session, and non-null publication token;
- disabled during initial/loading/refreshing/error/notFound, including a retained
  Attempt outside `data`;
- FE-003 is eligible/authoritative; FE-004 is authoritative/non-terminal; both
  source tokens are identical to the current parent publication;
- exact non-file/file Question sets contain no missing, extra, duplicate, or
  wrong-family state;
- uninitialized/older/mismatched local state blocks via `localStateUnavailable`;
- fresh parent GET/terminal acceptance tokens and retained-state token rules hold;
- mixed older uncertainty cannot falsely advance local source publication;
- dirty non-file draft blocks;
- active/uncertain/reconciling answer state blocks;
- selected/active/uncertain/reconciling file state blocks;
- zero unanswered/all unanswered does **not** block;
- no local deadline logic.

## Confirmation

- saved/unanswered count derives only from aligned FE-003 `serverAnswer` and
  FE-004 `serverFile` bases; confirmed overlays count before a later GET and are
  superseded by its complete rebase;
- zero-answer Submit explicitly supported;
- warns Attempt becomes locked/read-only;
- no Save-all behavior;
- captured ready token identifies session, route, parent/local publications and
  state identities, and counts;
- obsolete confirmation sends no POST, generates no key, and claims no gate.

## Idempotency

- FE-002 UUID generator reused;
- one key per logical Submit;
- uncertain outcome retains same key;
- Retry uses same key;
- repository receives Attempt ID, expected Homework ID, and key; all three UUIDs
  are validated before the exact no-retry transport;
- valid 200 proves exact envelope/message, matching IDs, terminal `studentSubmit`,
  non-null submitted timestamp, and identical finalized timestamp;
- controller independently rejects invalid injected typed results as uncertain;
- malformed/auto-finalized 200 is uncertain and retains the same key;
- deterministic failure clears key;
- duplicate Submit/resolution suppressed;
- no automatic new-key retry.

## Operation gate

- Submit synchronously claims gate before first await;
- FE-003 Save and FE-004 picker/upload synchronously claim their own active
  operation after checking gate and before first await;
- both ordering directions are race-safe;
- answer/file controllers enforce the gate;
- submitting/uncertain/checking screen is locally read-only;
- every specified FE-003/004 mutation/reconciliation entry point enforces the
  gate; explicit cleanup remains allowed;
- Retry switches `submitUncertain -> submitting` synchronously before its POST;
- Check keeps `submitUncertain`; Open/Save As and ordinary AppBar refresh cannot
  start while the gate is held;
- gate releases correctly.

## Reconciliation

- valid 200 terminal Attempt adopted through the existing terminal-only method
  while the gate remains held, before clearing its key or releasing the gate;
- confirmed Submit becomes `completed`; older parent GET cannot overwrite it;
- Homework detail uses retained `refresh()` and the existing Topic list uses
  `markAuthoritativeRowsStale(currentSessionKey)` when present;
- no optimistic Homework counters/status patch or destructive detail invalidation;
- deadline/close/not-editable outcomes refresh;
- deterministic `validation_failed` clears key/gate, publishes failure with the
  exact validation notice, and refreshes Attempt before a new aligned Submit;
- Check current is an owned single resolution operation;
- while Check runs, Retry is disabled and vice versa;
- uncertain Check current:
  - `student_submit` terminal => `reconciledTerminal` / already-submitted notice,
    not current-operation success;
  - auto-finalized terminal => `reconciledTerminal` without false success;
  - in_progress => uncertainty remains with same key;
- stale Check completion cannot overwrite newer Retry success/Leave/session/
  target state;
- unrelated parent refresh cannot resolve the owned logical Submit operation.

## Terminal UX

- explicit Submit shows success + `Submitted by you`;
- deadline/close show correct finalization reason;
- terminal UI survives matching Homework detail `refreshing` and retained
  `error`; notFound/session/target guards remain stronger;
- finalization fields appear once in the summary, with the contracted card
  composition and exact labels;
- no editors/Submit on terminal Attempt;
- no score/checking;
- Start-next remains Homework-detail responsibility.

## Navigation

- initial Submit and Retry POST routes cannot be abandoned;
- uncertain Submit leave warns and discards retry context only on explicit Leave;
- explicit Leave invalidates all Submit generations and clears Submit plus
  FE-003/004 local state without a request; Stay preserves everything;
- one PopScope follows the exact Submit/file/answer/local-draft priority.

## Scope

- no auto checking/scoring/review;
- no next Attempt creation;
- no new route/dependency/backend/platform change;
- no autosave-all.

## Verification

- exact focused test command passes;
- exact named regressions pass;
- exact Dart format command passes;
- `flutter analyze` passes;
- `git diff --check` passes;
- focused self-review passes;
- approved implementation scope staged, `git diff --cached --check` and staged
  review pass, and authorized commit/branch/PR delivery completes before stopping
  short of merge.

---

# 79. Locked Implementation Decisions

These are decisions, not suggestions:

```text
Submit endpoint = POST /student/attempts/:attempt/submit
repository arguments = attemptId, expectedHomeworkId, idempotencyKey
Submit Idempotency-Key = FE-002 secure UUID v4 generator
success = HTTP 200 only
Submit body = {}
all/partial/zero answers = allowed
local dirty/selected/uncertain work = must resolve before Submit
Submit never auto-saves answers
confirmation = required
confirmation shows saved/unanswered counts
Submit authority = data + matching in_progress Attempt + eligible current session
parent publication = opaque identity token, fresh on authoritative data/terminal acceptance
local publication = exact parent identity after complete authoritative rebase
readiness = exact local publication and non-file/file Question-set alignment
confirmed counts = aligned FE-003 serverAnswer + FE-004 serverFile bases
confirmation = captured ready token must still match before key/gate/POST
Submit claims route operation gate before first await
FE-003/004 mutation entry claims own active state synchronously before first await
mutation-first => Submit blocked; Submit-first => mutation blocked
submitting/uncertain/checking = editors frozen
non-idle gate = all specified local mutation/reconciliation entries and transfer initiation refused
uncertain Submit retry = SAME idempotency key
Retry = synchronous submitUncertain -> submitting before POST; Back stay-only
valid HTTP 200 = exact envelope/message + matching IDs + terminal studentSubmit + equal submitted/finalized timestamps
auto-finalized/malformed HTTP 200 => uncertain, SAME key retained
invalid injected typed result = uncertain, SAME key retained
Check current = owned single resolution operation
Check current = fetchAttempt(target.attemptId), gate remains submitUncertain
Check current in_progress = uncertainty remains
Check current student_submit terminal = reconciledTerminal/already submitted, not current-operation success
deadline/close terminal = reconciledTerminal authoritative auto-finalization, not explicit success
valid same-key/new Submit 200 = invalidate old resolution -> accept terminal -> clear key -> completed -> release gate
terminal adoption = reuse acceptAuthoritativeTerminalAttempt, never generic injection
Homework detail = retained refresh; Topic Homework list = markAuthoritativeRowsStale
Homework counters/status = never optimistically patched
terminal UI = retained matching Homework data/refreshing/error context
finalization fields = one summary with exact reason labels
terminal screen = remain on Attempt route
validation_failed = clear key/gate + failure notice + Attempt refresh before new readiness
uncertain/checking Leave = invalidate generations + clear Submit/FE-003/FE-004 local state + no request
next Attempt = only through Back to Homework + FE-002
```

Codex must not substitute:

- requiring all Questions answered;
- auto-saving dirty drafts;
- generating a new key on timeout Retry;
- accepting a 200 deadline/close finalization as Submit success;
- claiming current-operation success from Check-current `student_submit`;
- allowing Check and Retry resolution calls to overlap;
- claiming success from an in-progress GET;
- client-created finalization timestamps/status;
- navigating away immediately after success;
- client-side remaining-attempt calculation;
- score/checking UI;
- broad global mutation manager.

---

# 80. Implementation Delivery and Completion Report

After future current-main Readiness PASS authorizes FE-005 implementation, use
exactly:

```text
Implementation branch:
implement/s07-fe-005-submit-finalization-ux

Pre-approved implementation commit:
feat(stage7): add student homework submit ux
```

After all implementation verification passes:

```text
stage only approved FE-005 implementation/test/compatibility scope
git diff --cached --check
focused staged-diff review
commit with the exact pre-approved message
push implement/s07-fe-005-submit-finalization-ux
create PR against main
stop before merge
```

The PR body includes focused verification and scope/non-goals. Project Owner
merges only after ChatGPT acceptance review. Do not modify Stage bookkeeping.

Use exactly one status, on its own line:

```text
IMPLEMENTATION COMPLETE
BLOCKED
DELIVERY BLOCKED
```

Use `IMPLEMENTATION COMPLETE` after implementation, verification, and delivery
complete; `BLOCKED` for implementation or verification failure; and
`DELIVERY BLOCKED` only when implementation passed but safe delivery cannot
complete.

The completion report contains:

1. implementation summary;
2. changed files and purpose;
3. exact focused test results;
4. publication/readiness/confirmed-count/zero-answer evidence;
5. confirmation-token evidence;
6. idempotency same-key retry + strict `student_submit` 200 proof evidence;
7. symmetric route-operation gate race evidence;
8. owned Check-current / deadline / close / uncertain reconciliation evidence;
9. completed-vs-reconciledTerminal adoption ordering and retained Homework refresh
   evidence;
10. navigation-guard evidence;
11. desktop/mobile/accessibility evidence;
12. FE-003/004 regression evidence;
13. format/analyze results;
14. `git diff --check`, `git diff --cached --check`, and focused complete/staged
    diff-review results;
15. scope/non-goal confirmation;
16. deviations/blockers;
17. commit SHA and branch;
18. PR number and PR URL;
19. final `git status --short`.

Do not claim `Accepted`, `Frontend Phase 2 PASS`, `merged`, or `Stage 7 closed`.
