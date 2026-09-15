# Codex Implementation Contract: S08-BE-008 — Idempotent Student Blitz Submit

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-BE-008` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel shared Student final-Submit route + Blitz pre-deadline idempotent finalization` |
| Depends on | `S08-DOC-001`, `S08-BE-001…007` — all `Accepted / Delivered` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` after dependencies are delivered and immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |
| Backend block checkpoint | `Stage 8 Backend Phase 2` after `S08-BE-001…010` are `Accepted / Delivered` |
| Blocks | `S08-BE-009` |

Start only when:

```text
S08-DOC-001 = Accepted / Delivered
S08-BE-001…007 = Accepted / Delivered
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
4. delivered S08-BE-001…007 source/tests directly required here;
5. current Stage 7 Homework Submit/idempotency source and focused tests;
6. current shared Student Attempt/answer-state/resource support directly required by this task.

Do **not** read:

- `docs/01–09`;
- roadmap files;
- Stage indexes;
- `S08-DOC-001`;
- previous task files;
- closure reviews;
- frontend code

to determine requirements.

This contract resolves:

- canonical shared Submit endpoint;
- Homework/Blitz dispatch;
- strict request/header behavior;
- Blitz Submit idempotency operation/fingerprint;
- successful pre-deadline finalization;
- timeout reconciliation;
- terminal-attempt behavior;
- durable replay semantics;
- Stage 8 no-checking/no-scoring boundary;
- response projection;
- concurrency/lock ordering;
- error behavior;
- acceptance criteria;
- focused verification.

If delivered dependencies materially conflict with this contract, return:

```text
BLOCKED
```

with exact file/line evidence.

Do not redesign the endpoint, finalization states, timeout engine, idempotency infrastructure, or Stage 8/9 boundary.

---

# 3. Goal

Implement explicit Student final Submit for an own Blitz Attempt through the already-canonical shared Attempt endpoint.

A successful pre-deadline Submit must atomically freeze the exact Student work already committed on the server as:

```text
status = submitted
submitted_at = submittedAt
finalized_at = submittedAt
locked_at = submittedAt
finalization_reason = student_submit
```

It must:

- require a durable `Idempotency-Key`;
- never change the Attempt deadline;
- never create missing answer rows;
- never check/score answers;
- never overwrite an already terminal timeout/close reason;
- reuse the BE-007 timeout engine when the authoritative deadline has been reached.

---

# 4. Canonical Endpoint — No New Blitz Submit URL

Continue using exactly:

```text
POST /api/v1/student/attempts/{attempt}/submit
```

This route becomes truly shared between:

```text
Homework Attempt
Blitz Attempt
```

Do not add:

```text
/student/blitz/attempts/{attempt}/submit
/student/homework/attempts/{attempt}/submit
```

aliases.

The route remains inside:

```text
auth:sanctum
active.account
password.changed
role:student
```

---

# 5. Explicit Non-Goals

Do not implement or change:

- Attempt exception grant;
- replacement Attempt #2 creation;
- Teacher monitoring;
- Student Start timing rules except directly affected Submit replay projection;
- answer/file mutation semantics except direct Submit-race regressions;
- Teacher Close semantics except direct race regressions;
- timeout Scheduler semantics except direct Submit-race regressions;
- checking;
- Teacher review;
- awarded points;
- Attempt score;
- official Blitz score;
- Topic result;
- frontend;
- E2E harness/seed data;
- migrations/schema;
- dependencies;
- docs/tasks.

Do not:

- create a second Submit endpoint;
- create a second idempotency table;
- fabricate answers;
- auto-answer unanswered Questions;
- move answers to Teacher review state;
- calculate zeros/scores in Stage 8.

---

# 6. Stage 8 / Stage 9 Boundary

Explicit Submit freezes execution only.

Every already-saved answer remains:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

Attempt score fields remain:

```text
earned_points = null
normalized_score = null
scoring_completed_at = null
```

No missing answer row is created.

No unanswered-zero score is persisted in this task.

Stage 9 later interprets missing answers and performs checking/scoring.

## 6.1 Pending execution integrity vs historical read integrity

Stage 8 must preserve two different contracts.

### Mutation / fresh Submit contract

Every Student answer mutation and every **new** explicit Student Submit still
requires the existing pending execution invariant:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

Do not weaken that invariant.

### Historical completed-replay read contract

A previously frozen Blitz Attempt may later be read after Stage 9 has
legitimately changed answer checking metadata and advanced the Attempt to:

```text
waiting_for_teacher_review
checked
```

Stage 8 must support that read only when the caller has already proven one of
these completed idempotent replay origins:

```text
student.blitz.attempt.submit
student.blitz.attempt.start
```

For `student.blitz.attempt.start`, the original semantic request remains exact:

```text
start_normal
resume + original attempt_id
start_replacement
```

`start_replacement` support here is forward-compatible projection/read support
only. BE-008 must not make the public replacement-Start request executable before
BE-009 delivers that intent.

That historical read must still validate:

```text
Institution ownership
Attempt ownership
Question belongs to the same Assessment
exact typed-answer family
typed child ownership
file-answer link integrity
private Student file ownership/category/current-file integrity
canonical Student answer value
```

but must **not** require the old Stage-8-only `pending/null` checking metadata.

The historical read path is read-only compatibility only.

It does not grant replay validity by itself. Replay validity must be proven by
the owning Start/Submit idempotency path before this projection mode is selected.

It must not:

```text
change checking_status
change awarded_points
change feedback
change checked_by_user_id
change checked_at
change Attempt score fields
implement automatic checking
implement Teacher review
calculate score
expose checking/scoring metadata to Student
```

---

# 7. Shared Submit Route Architecture

The current canonical route is historically wired through Homework-specific:

```text
StudentHomeworkAttemptController
StudentHomeworkAttemptSubmitRequest
SubmitStudentHomeworkAttempt
StudentHomeworkAttemptResource
```

Refactor only the Submit route boundary to be type-safe/shared.

Do not disturb Homework Start/Show routes.

Recommended structure:

```text
StudentAttemptSubmissionController
StudentAttemptSubmitRequest
SubmitStudentAttempt
StudentAttemptSubmitResult
```

Exact equivalent names are acceptable if responsibilities remain identical.

The canonical Submit route must point to the shared submission controller.

---

# 8. Shared Submit Request

Replace/narrowly extract the current Homework-only Submit request into:

```text
StudentAttemptSubmitRequest
```

Preserve the exact delivered wire behavior.

## Required header

```http
Idempotency-Key: <uuid>
```

Missing/malformed:

```text
422 validation_failed
```

Normalize to lowercase.

## Body

Allowed:

```text
empty
```

or exact empty JSON object:

```json
{}
```

Any other body:

```text
422 validation_failed
```

## Query

No query parameters.

Any query key:

```text
422 validation_failed
```

Do not inspect Assessment type/lifecycle in the Form Request.

---

# 9. Shared Own-Attempt Submit Target

Reuse the type-neutral own-Attempt resolver delivered/extracted by BE-006 if it safely provides:

```text
Attempt ID
Assessment ID
Assessment type
same-Institution Student ownership
same AssessmentStudent recipient graph
```

If BE-006's exact helper is answer-specific, extract the minimal common ownership resolution into one neutral support class and update BE-006 to use it without behavior change.

Do not duplicate two different global Attempt ownership queries.

Malformed UUID, foreign Tenant, another Student, broken recipient graph, unsupported Assessment type:

```text
404 resource_not_found
```

Authorization must happen before idempotency replay.

---

# 10. Type-Safe Submit Dispatcher

Create:

```text
SubmitStudentAttempt
```

or equivalent.

It resolves the own Attempt target, then dispatches:

```text
AssessmentType::Homework
  -> existing SubmitStudentHomeworkAttempt

AssessmentType::Blitz
  -> new SubmitStudentBlitzAttempt
```

The dispatcher owns no lifecycle/finalization logic.

Unexpected Assessment type:

```text
404 resource_not_found
```

or internal invariant error according to the delivered target resolver.

---

# 11. Type-Neutral Submit Result

Replace/refine:

```text
StudentHomeworkAttemptSubmitResult
```

into one neutral result:

```text
StudentAttemptSubmitResult
```

Required information:

```text
attemptId
assessmentType
httpStatus
```

For all successful final Submit operations in this task:

```text
httpStatus = 200
```

Update existing Homework Submit to return the neutral result with:

```text
assessmentType = homework
```

No Homework behavior change.

---

# 12. Shared Submit Controller Response Dispatch

The shared Submit controller must return the correct canonical Attempt resource.

## Homework

Use:

```text
ShowStudentHomeworkAttempt
StudentHomeworkAttemptResource
```

Message unchanged:

```text
Homework submitted successfully.
```

## Blitz

Use:

```text
ShowStudentBlitzAttempt
StudentBlitzAttemptResource
```

Exact message:

```text
Blitz attempt submitted successfully.
```

Both:

```text
200 OK
```

Do not return a generic raw `AssessmentAttempt` database resource.

---

# 13. Blitz Submit Idempotency Operation

Extend:

```text
IdempotencyOperation
```

with exactly:

```text
StudentBlitzAttemptSubmit = 'student.blitz.attempt.submit'
```

Keep existing:

```text
student.homework.attempt.submit
```

unchanged.

Do not collapse the two operation codes after the fact; the delivered implementation is already Homework-specific and Stage 8 alignment approves the Blitz-specific code.

---

# 14. Blitz Submit Fingerprint

After privacy-safe own Blitz Attempt resolution:

```text
operation = student.blitz.attempt.submit
route identity = {
  "attempt_id": lowercase own Attempt UUID
}
body identity = {}
```

Use:

```text
IdempotencyRequestFingerprint
```

Shared fingerprint already includes:

```text
institution_id
user_id
operation
```

Do not include:

- current status;
- deadline;
- Blitz ID separately when Attempt ID already defines the route resource;
- current time;
- saved answers;
- lifecycle state.

Those are server state, not client request identity.

---

# 15. `SubmitStudentBlitzAttempt`

Create:

```text
App\Actions\Student\SubmitStudentBlitzAttempt
```

It must reuse:

```text
StudentBlitzAttemptAccess
IdempotencyGuard
IdempotencyRequestFingerprint
BlitzAttemptFinalizer
FinalizeTimedOutBlitzAttempts
Student Attempt answer-state integrity projection
```

from the delivered Stage 8 foundation.

Do not route Blitz Submit through:

```text
SubmitStudentHomeworkAttempt
HomeworkAttemptFinalizer
FinalizeHomeworkAttemptsAtDeadline
```

---

# 16. Preliminary Resolution

Before starting the Submit transaction:

1. privacy-safely resolve own Blitz Attempt;
2. resolve only enough Assessment identity to build the operation fingerprint;
3. no lifecycle state is exposed to an unauthorized caller.

The Attempt may currently be terminal.

This is required so a completed same-key replay can remain authorized after later lifecycle changes.

---

# 17. Submit Lock Order

Inside the transaction use the same decisive ordering as BE-007:

```text
1. Topic
2. Assessment
3. BlitzTask
4. own AssessmentAttempt
5. Idempotency record
6. Questions/answer integrity rows only when a new successful Submit needs validation
```

If the delivered `StudentBlitzAttemptAccess` has a compatible established order, reuse it exactly.

Do not acquire answer rows before the Attempt lock.

Do not lock Topic result pair: Submit does not change official identity/cohort/lock.

---

# 18. Locked Attempt Re-Resolution

Under lock require the exact previously authorized graph:

```text
same Institution
Assessment.type = blitz
BlitzTask exists
Attempt belongs to authenticated Student
Attempt.assessment_id = Assessment
Attempt.assessment_student_id = own same-Assessment recipient
```

If the already-authorized graph disappears/corrupts under lock:

```text
LogicException
```

Do not silently rebind the Attempt.

---

# 19. Completed Idempotency Replay Comes First

After parent/Attempt lock and before new lifecycle eligibility decisions:

```text
completedReplay(...)
```

must be checked.

If a completed record exists with the same fingerprint:

- validate replay metadata;
- validate that the current Attempt still carries the historical lineage of the
  original successful Student Submit;
- perform zero domain mutation;
- return the same logical successful Submit result.

This replay remains valid even if the Blitz later became:

```text
closed
archived
```

or the Attempt is now read in a later result stage.

## 19.1 Allowed current replay projection

A completed successful Student Submit may currently project as:

```text
submitted
waiting_for_teacher_review
checked
```

provided the execution-finalization lineage still proves:

```text
finalization_reason = student_submit
submitted_at non-null
finalized_at = submitted_at
locked_at = submitted_at
finalized_at < deadline_at
```

and the original execution timestamps/reason were not rewritten.

`waiting_for_teacher_review` and `checked` are forward-compatible later result
stages. BE-008 does not create those states and does not implement Stage 9
checking/scoring.

## 19.1.1 Answer projection policy for completed replay

After the execution-lineage checks above succeed:

### Current status = submitted

Use the normal pending execution answer projection.

Require every persisted answer to remain:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

A `submitted` Attempt carrying later checking metadata is not silently
reclassified by BE-008.

### Current status = waiting_for_teacher_review | checked

Use the dedicated historical **read-only** answer projection from Section 30.1
after the completed Submit replay has produced the verified historical-read
context defined there.

Do not call the pending-only projection for these later result stages.

The historical projection validates answer value/ownership/file integrity but
does not require Stage-8 pending checking metadata.

In all allowed replay statuses, the public Student answer JSON remains the same
Student-safe answer surface and must not add checking/score fields.

## 19.2 Forbidden replay projection

A completed Student Submit record must **not** convert these current Attempt
histories into successful Submit replay:

```text
in_progress
timed_out_finalized + timeout_auto_submit
submitted + task_closed_auto_finalize
waiting_for_teacher_review + timeout_auto_submit
waiting_for_teacher_review + task_closed_auto_finalize
checked + timeout_auto_submit
checked + task_closed_auto_finalize
```

Such combinations contradict the completed Submit record/history and are a
structural integrity failure, not a new lifecycle decision and not permission to
rewrite history.

Current Student authorization remains mandatory.

---

# 20. Replay Metadata

A completed Blitz Submit record must contain exactly:

```text
result_resource_type = assessment_attempt
result_resource_id = this Attempt UUID
response_status = 200
completed_at non-null
```

Any other completed metadata:

```text
LogicException
```

Do not create a new Submit from a corrupt completed record.

---

# 21. New Claim

When no completed replay exists:

```text
claim(...)
```

the key/fingerprint inside the same transaction.

If another concurrent request already completed the claim:

```text
claim.new = false
```

validate and replay that completed result.

A failed new Submit must not leave a committed incomplete/successful claim.

---

# 22. Locked Attempt Structural Validation

The Submit path must support an own Blitz Attempt created through the delivered Start logic.

For an `in_progress` candidate require:

```text
deadline_at non-null
started_at non-null
deadline_at > started_at
submitted_at = null
finalized_at = null
locked_at = null
finalization_reason = null
```

Recipient/Assessment ownership must be exact.

Impossible persisted structure:

```text
LogicException
```

Do not repair.

---

# 23. Terminal Attempt Precedence for a New Submit

A matching completed replay has already returned before this section.

For a **new** key/request:

## Timeout-finalized

If:

```text
status = timed_out_finalized
finalization_reason = timeout_auto_submit
```

return:

```text
409 blitz_time_expired
```

No new successful idempotency record.

No timestamp/reason change.

## Any other terminal execution state

Examples:

```text
submitted + student_submit
submitted + task_closed_auto_finalize
waiting_for_teacher_review
checked
```

return:

```text
409 attempt_not_editable
```

No new successful idempotency record.

Do not invent a second Submit success for a new key.

---

# 24. No `submission_locked` Code in Stage 8

Do **not** introduce:

```text
submission_locked
```

in this task.

The Stage 8 execution alignment supersedes older combined Stage-8/9 wording.

Exact Stage 8 behavior is:

```text
same successful Submit key
  -> successful replay

new Submit on timeout-finalized Attempt
  -> 409 blitz_time_expired

new Submit on any other terminal Attempt
  -> 409 attempt_not_editable
```

This keeps the execution API aligned with the stable codes already used by BE-005…007.

---

# 25. New Submit Lifecycle Preconditions

After confirming:

```text
Attempt.status = in_progress
```

require:

```text
Topic.status = active
BlitzTask.status = active
```

If not:

```text
409 blitz_not_active
```

This is a defensive invariant because Teacher Close should atomically finalize all in-progress Attempts before making the Blitz closed.

Do not submit an in-progress Attempt under a non-active Blitz.

---

# 26. Authoritative Submit Decision Instant

All parent/Attempt/idempotency lock waits happen before:

```text
submittedAt = server_now
```

Capture exactly one server instant for the new Submit decision.

The client supplies no time.

---

# 27. Deadline Rule

For a new in-progress Submit:

```text
submittedAt < attempt.deadline_at
```

is required for explicit Student Submit.

At exact equality:

```text
submittedAt == deadline_at
```

timeout wins.

If:

```text
submittedAt >= attempt.deadline_at
```

the explicit Submit does **not** finalize with `student_submit`.

Instead follow Section 28.

---

# 28. Late Submit Reconciliation

When a locked in-progress Attempt is already due:

1. abandon/delete the new incomplete idempotency claim using the existing guard;
2. perform zero Submit finalization;
3. return an internal due marker from the transaction;
4. release local Submit locks;
5. invoke:
   ```text
   FinalizeTimedOutBlitzAttempts(
     student.institution_id,
     assessment.id
   )
   ```
6. after reconciliation succeeds, throw:
   ```text
   409 blitz_time_expired
   ```

No successful Blitz Submit idempotency record is created.

No incomplete claim remains committed.

Timeout finalization persists:

```text
timed_out_finalized
timeout_auto_submit
finalized_at = locked_at = exact deadline_at
submitted_at = null
```

---

# 29. Why Late Submit Is Not a Successful Idempotent Submit

Timeout is a server-authoritative execution event, not a Student Submit.

Therefore a late explicit Submit request:

- may trigger reconciliation;
- returns a timeout conflict;
- does not own the timeout result through `student.blitz.attempt.submit`;
- does not create a completed Submit idempotency record.

Retrying the same key after timeout is treated as a new request against a timeout-finalized Attempt and returns:

```text
409 blitz_time_expired
```

unless that key had already completed a successful pre-deadline Submit earlier.

---

# 30. Saved-Answer Integrity Before Successful Submit

Before explicit pre-deadline finalization:

1. load current authorized Blitz Questions ordered by:
   ```text
   position
   id
   ```
2. load all saved Attempt answers;
3. validate canonical persisted typed/file integrity using the delivered shared Student answer-state support;
4. require every persisted answer to belong to one current authorized Question.

Unanswered Questions are valid and have no row.

If persisted answer integrity is corrupt:

```text
LogicException
```

or the existing safe business-conflict mapping if the delivered support intentionally wraps that condition.

Do not finalize a successful Student Submit around corrupt persisted answer ownership.

This is the **pending execution** integrity path and must retain the existing
pending/null checking assertions.

## 30.1 Historical Student Answer Projection for Completed Replay

Permit a narrow shared-support adaptation.

### `StudentHomeworkAnswerIntegrity`

Preserve existing:

```text
canonical(...)
```

with its current behavior unchanged.

It remains the pending-only canonicalization used by:

```text
Student answer mutation
file answer mutation
new Homework Submit
new Blitz Submit
ordinary Stage-8 submitted replay
```

Add one explicit read-only method, conceptually:

```php
canonicalForHistoricalRead(
    AttemptAnswer $answer,
    AssessmentAttempt $attempt,
    Question $question
): array
```

Exact repository-consistent naming is allowed, but the two semantics must remain
unambiguous.

Refactor duplicated internals only enough that both methods reuse one structural
canonicalization implementation.

`canonicalForHistoricalRead(...)` must validate the same:

```text
answer.institution_id == attempt.institution_id
answer.attempt_id == attempt.id
answer.question_id == question.id
question.assessment_id == attempt.assessment_id

exact Question-type answer family
no extra typed families
typed child institution/answer/question ownership

file AnswerFile/File identity
file Institution
file uploaded_by_user_id == attempt.student_id
file category = student_submission
file removed_at = null
allowed extension/MIME
positive bounded size
checksum/storage metadata integrity
```

and produce the same canonical Student answer value.

It must also require the persisted raw:

```text
checking_status
```

to be one of the existing `AttemptAnswerCheckingStatus` enum values:

```text
pending
auto_checked
waiting_for_teacher_review
teacher_checked
```

It must **not** impose Stage 9 business semantics such as:

```text
which later checking status requires awarded_points
whether feedback is mandatory
who is allowed to be checked_by_user_id
how checked_at relates to scoring completion
maximum awarded points
```

Those rules belong to Stage 9.

It must not require:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

for historical read.

It must not place any of those fields into `student_answer_value`.

### `StudentHomeworkAttemptAnswerStates`

Preserve its existing invocation behavior as pending-only.

Do not change existing Homework/BE-006 callers merely to support historical
replay.

Add one explicit method, conceptually:

```php
historicalRead(
    string $institutionId,
    AssessmentAttempt $attempt,
    Collection $questions
): SupportCollection
```

Exact repository-consistent naming is allowed.

It must:

1. load the same authorized Question value support;
2. load all own Attempt answers;
3. load the same typed/file relations;
4. reject any answer whose Question is outside the authorized Question set;
5. use `canonicalForHistoricalRead(...)`;
6. set only the same internal:
   ```text
   student_answer_value
   ```
   used by the existing Student resource;
7. return the same Student answer-state result shape.

Do not duplicate the typed/file canonicalization algorithm in a new Blitz-only
helper.

### Verified historical-read context

Do not let a controller/request/resource choose historical mode from a boolean,
query/body flag or `Attempt.status` alone.

Create one narrow internal proof/context, conceptually:

```text
StudentBlitzHistoricalAnswerReadProof
```

or an exact responsibility-equivalent typed value.

It is created only after the owning idempotency replay path has already verified
the replay.

Minimum proof identity:

```text
origin_operation
referenced_attempt_id
completed_response_status
terminal_finalization_reason
```

For Start replay also retain:

```text
start_intent
resume_attempt_id nullable
```

The public request never supplies this proof.

`ShowStudentBlitzAttempt` / the canonical Start-or-Submit Attempt projection may
use `historicalRead(...)` only when this verified proof is present and matches
the exact Attempt being projected.

### Call-site restriction — completed Submit replay

Existing completed Submit replay remains valid only when all are proven:

```text
origin_operation = student.blitz.attempt.submit
completed same-key/same-fingerprint record exists
result_resource_type = assessment_attempt
result_resource_id = this Attempt UUID
response_status = 200
completed_at non-null
current Student still owns/authorizes the Attempt

Attempt.status in {waiting_for_teacher_review, checked}
finalization_reason = student_submit
submitted_at != null
finalized_at = submitted_at
locked_at = submitted_at
finalized_at < deadline_at
```

Only then create the verified historical-read context and use
`historicalRead(...)`.

### Call-site restriction — completed Start/Resume/replacement-Start replay

The same historical projection is also permitted for a completed replay of:

```text
operation = student.blitz.attempt.start
```

but only after the existing Start idempotency layer has proven all of:

```text
completed record exists
same Idempotency-Key
same exact request fingerprint/body
result_resource_type = assessment_attempt
result_resource_id = the same referenced Attempt UUID
response_status in {200, 201}
completed_at non-null
current Student still owns/authorizes the Attempt
same Institution
same Blitz Assessment
same persisted recipient graph
```

The original semantic request must remain exact:

```text
start_normal
-> referenced Attempt must remain normal Attempt #1

resume
-> original body attempt_id must equal referenced Attempt ID
-> never switch to another Attempt

start_replacement
-> referenced Attempt must remain replacement Attempt #2
-> where BE-009 is delivered, the persisted exception replacement link must still
   identify this same #2
```

The replay must preserve the completed record's original logical HTTP status:

```text
200 or 201
```

and original logical Start/Resume/replacement-Start response semantics.

Do not create:

```text
new Attempt
new Start idempotency result
new exception
new replacement capacity
```

during replay.

Same key with a changed:

```text
Blitz
intent
Resume attempt_id
```

remains:

```text
409 idempotency_key_reused
```

before historical answer projection.

BE-008 must not broaden the public BE-005 request validator to accept
`start_replacement` early. It prepares shared replay/projection support so the
BE-009 public replacement branch later reuses the same verified path.

### Terminal lineage matrix for historical Start replay

When a verified completed Start replay currently projects:

```text
waiting_for_teacher_review
checked
```

the execution history must satisfy exactly one of these already-approved
lineages.

#### Student explicit Submit lineage

```text
finalization_reason = student_submit
submitted_at != null
finalized_at = submitted_at
locked_at = submitted_at
finalized_at < deadline_at
```

#### Timeout lineage

```text
finalization_reason = timeout_auto_submit
submitted_at = null
finalized_at = deadline_at
locked_at = deadline_at
```

#### Teacher-close lineage

```text
finalization_reason = task_closed_auto_finalize
submitted_at = null
finalized_at non-null
locked_at = finalized_at
finalized_at < deadline_at
```

Do not collapse these histories into the Submit lineage.

Do not rewrite any terminal timestamp/reason merely to satisfy replay.

If `waiting_for_teacher_review|checked` carries no valid lineage from the matrix:

```text
LogicException
```

for the impossible persisted graph.

### Pending-only/default projection remains unchanged

Use the existing pending-only answer projection for:

```text
fresh answer/file mutation
new Homework Submit
new Blitz Submit
new-key Start/Resume/replacement-Start operations
ordinary in_progress Start/Resume result
completed Start replay while current Attempt answers are still Stage-8 pending
completed Submit replay while current status = submitted
timeout/close terminal replay before later checking has advanced the Attempt
```

A new-key operation must never enable historical mode merely because the target
Attempt is terminal.

### Student response privacy

Continue using the existing Student answer resource shape:

```text
question_id
type
answer
updated_at
```

Do not expose:

```text
checking_status
awarded_points
feedback
checked_by_user_id
checked_at
earned_points
normalized_score
scoring_completed_at
correct-answer/checking configuration
```

BE-008 is adapting **read validation**, not expanding the Student API.

### Start replay response dispatch

For a verified completed `student.blitz.attempt.start` replay:

```text
Attempt current status = in_progress|submitted|timed_out_finalized
-> ordinary pending-only answer-state projection

Attempt current status = waiting_for_teacher_review|checked
-> verified historical read-only answer-state projection
   after the exact lineage matrix above passes
```

The Start replay still returns:

```text
the same referenced Attempt ID
the same original logical HTTP 200/201 result
the same original Start/Resume/replacement-Start message semantics
```

while the Attempt body may reflect its current terminal status.

No score/checking block is added.

No client-supplied projection mode is accepted.

---

# 31. Explicit Student Submit Transition

Extend delivered:

```text
BlitzAttemptFinalizer
```

with:

```text
finalizeByStudentSubmit(
  AssessmentAttempt $attempt,
  CarbonInterface $submittedAt
): bool
```

For one valid locked `in_progress` Attempt set exactly:

```text
status = submitted
submitted_at = submittedAt
finalized_at = submittedAt
locked_at = submittedAt
finalization_reason = student_submit
updated_at = submittedAt
```

Preserve:

```text
started_at
deadline_at
attempt_number
assessment_student_id
student_id
official_score_eligible
possible_points
earned_points = null
normalized_score = null
scoring_completed_at = null
```

If the Attempt is no longer `in_progress`:

```text
return false
```

The caller must never interpret false as permission to overwrite terminal history.

---

# 32. Submit Creates No Missing Answers

Student may explicitly Submit:

- all Questions answered;
- some Questions answered;
- no Questions answered.

All are valid execution finalizations before the deadline.

Do not:

- create AttemptAnswer rows for missing Questions;
- persist zero points;
- mark missing answers wrong;
- reject because a Question is unanswered.

Stage 9 applies missing-answer-as-zero scoring later.

---

# 33. Submit Does Not Recalculate Assessment Points

`possible_points` was snapshotted at Attempt creation.

Question authoring is immutable after activation.

Submit does not:

- recalculate Question total;
- rewrite Attempt possible points;
- rewrite Assessment total.

If structural point identity is impossible, treat it as an internal consistency issue according to delivered Start/Attempt integrity support.

---

# 34. Idempotency Completion

After successful explicit finalization:

```text
idempotency.complete(
  claim,
  resourceType: 'assessment_attempt',
  resourceId: attempt.id,
  responseStatus: 200
)
```

The Attempt transition and completed idempotency record commit in the same DB transaction.

If completion fails:

- Attempt finalization rolls back;
- claim rolls back;
- answers/files remain editable if the transaction did not commit;
- retry may safely execute.

---

# 35. Same-Key Successful Replay

Given a completed successful Submit:

```text
student.blitz.attempt.submit
+
same Student
+
same key
+
same Attempt fingerprint
```

later replay returns:

```text
200
Blitz attempt submitted successfully.
```

with the same logical Attempt.

The current resource may be:

```text
submitted
waiting_for_teacher_review
checked
```

only when Section 19's original:

```text
student_submit
```

execution lineage is preserved.

No replay mutation/churn is allowed to:

```text
submitted_at
finalized_at
locked_at
finalization_reason
updated_at
answers/files
```

A later Stage 9 result transition may change its own result/checking fields/status
under that future contract, but replay itself does not perform such a transition.

---

# 36. Same-Key Replay After Teacher Close/Archive

If Student submitted successfully first, a later Teacher Close preserves:

```text
student_submit
```

A same-key replay after Blitz later becomes Closed/Archived:

- still authorizes the Student through the own persisted Attempt/recipient graph;
- returns the same successful Submit logical result;
- does not require current Blitz `active` state;
- does not reopen/activate anything.

The internal Attempt projection used for replay must support authorized historical parent lifecycle.

No new public historical Blitz-detail route is added.

---

# 37. Different-Key Request After Successful Submit

After Attempt is already:

```text
submitted
student_submit
```

a **different** Submit key is not a replay.

Return:

```text
409 attempt_not_editable
```

No second completed Submit record.

No timestamp churn.

---

# 38. Different-Key Request After Teacher-Close Finalization

If:

```text
status = submitted
finalization_reason = task_closed_auto_finalize
```

return:

```text
409 attempt_not_editable
```

Do not rewrite to `student_submit`.

No successful Submit idempotency record.

---

# 39. Different-Key Request After Timeout

If:

```text
status = timed_out_finalized
finalization_reason = timeout_auto_submit
```

return:

```text
409 blitz_time_expired
```

Do not rewrite to `student_submit`.

No successful Submit idempotency record.

---

# 40. Future Attempt #2 Compatibility

BE-008 owns Submit-by-Attempt identity, not normal-Attempt allocation.

Do not hard-code Submit to:

```text
attempt_number = 1
```

as its core behavior.

The action must finalize any own Blitz Attempt that the delivered Student Blitz access layer recognizes as a valid executable Attempt.

At BE-008 delivery only normal Attempt #1 exists through public runtime.

BE-009 may extend valid history/access to replacement Attempt #2 without changing:

```text
POST /student/attempts/{attempt}/submit
```

or the explicit Submit transition semantics.

Do not implement exception validation in this task.

---

# 41. Shared Student Submit Resource Boundary

The canonical Blitz Submit response uses the delivered terminal-capable:

```text
StudentBlitzAttemptResource
```

from BE-007.

It must show at least:

```text
id
assessment_id
attempt_number
status
started_at
deadline_at
submitted_at
finalized_at
finalization_reason
timing
questions
answers
```

## 41.1 Fresh successful Submit projection

For a newly committed explicit Submit in BE-008:

```text
status = submitted
submitted_at = finalized_at
finalization_reason = student_submit
timing.remaining_seconds = 0
```

This is the required fresh Stage 8 success shape.

## 41.2 Completed same-key replay projection

When the request is a completed same-key replay, the current resource may
legitimately have advanced to:

```text
submitted
waiting_for_teacher_review
checked
```

but must still expose the original execution history:

```text
finalization_reason = student_submit
submitted_at non-null
finalized_at = submitted_at
finalized_at < deadline_at
timing.remaining_seconds = 0
```

The persisted `locked_at` remains equal to that original Submit instant even
though this public resource does not need to add a new `locked_at` field merely
for replay validation.

A timeout/Teacher-close lineage is never a successful Student Submit replay.

No score/checking block is added by BE-008. Supporting later status values here
is forward compatibility only; Stage 8 still does not implement checking/scoring.

For answer projection:

```text
fresh successful Submit
or completed replay with current status=submitted
-> existing pending-only answer state projection

completed same-key replay with current status=waiting_for_teacher_review|checked
-> Section 30.1 historical read-only answer state projection
```

Both paths serialize the same Student-safe answer JSON.

No checking/score metadata is added to the response.

---

# 42. Successful Blitz Submit Example

```json
{
  "data": {
    "id": "attempt-uuid",
    "assessment_id": "blitz-uuid",
    "attempt_number": 1,
    "status": "submitted",
    "started_at": "2026-09-14T18:00:00Z",
    "deadline_at": "2026-09-14T18:10:00Z",
    "submitted_at": "2026-09-14T18:07:30Z",
    "finalized_at": "2026-09-14T18:07:30Z",
    "finalization_reason": "student_submit",
    "timing": {
      "server_now": "2026-09-14T18:07:30Z",
      "mode": "individual",
      "remaining_seconds": 0
    },
    "questions": [],
    "answers": []
  },
  "message": "Blitz attempt submitted successfully."
}
```

No answer key or score is present.

---

# 43. Successful Submit Resource Server Time

For a newly successful Submit, the response may use:

```text
timing.server_now = submittedAt
```

for deterministic final projection.

For a replay, capture a fresh response projection time if needed, but:

```text
remaining_seconds = 0
```

and no domain timestamp changes.

Do not persist replay time.

---

# 44. New Submit Error Precedence

After privacy-safe resolution and completed replay check:

1. validate locked ownership/structure;
2. if timeout-finalized:
   ```text
   blitz_time_expired
   ```
3. if any other terminal status:
   ```text
   attempt_not_editable
   ```
4. require Topic/Blitz active for still-in-progress Attempt:
   ```text
   blitz_not_active
   ```
5. capture `submittedAt`;
6. if due:
   - abandon claim;
   - reconcile outside current locks;
   - return `blitz_time_expired`;
7. validate saved answers;
8. explicit-submit finalize.

This precedence is mandatory.

---

# 45. Submit vs Typed Answer Race

Both lock the same Attempt row.

## Answer commits first

Submit later:

- sees the committed answer;
- validates it;
- freezes it.

## Submit commits first

Later answer mutation:

```text
Attempt terminal
-> zero answer mutation
-> attempt_not_editable
```

No Student answer can commit after Submit.

---

# 46. Submit vs File Answer Race

Same Attempt-row serialization.

## File replacement commits first

Submit freezes the newly committed File answer.

## Submit commits first

Later file upload:

- cannot replace DB answer/file;
- staged new blob must be compensated by the BE-006 logic;
- prior current file remains historical current answer.

---

# 47. Submit vs Timeout Reconciler Race

Both share parent/Attempt lock order.

## Submit obtains lock and captures pre-deadline instant

It may commit:

```text
student_submit
```

Scheduler later sees terminal Attempt and does zero rewrite.

## Reconciler wins after deadline

Attempt becomes:

```text
timed_out_finalized
timeout_auto_submit
```

Submit later returns:

```text
blitz_time_expired
```

## Submit obtains lock but deadline already reached

It does not explicit-submit.

It releases its local lock, reconciles through the shared BE-007 engine, then returns:

```text
blitz_time_expired
```

Exactly one terminal reason survives.

---

# 48. Submit vs Teacher Close Race

Both share the decisive Attempt lock.

## Submit first

Attempt:

```text
submitted + student_submit
```

Teacher Close preserves it.

## Close first before Attempt deadline

Attempt:

```text
submitted + task_closed_auto_finalize
```

later Submit:

```text
attempt_not_editable
```

## Close first at/after deadline

Attempt:

```text
timed_out_finalized + timeout_auto_submit
```

later Submit:

```text
blitz_time_expired
```

No reason/timestamp rewrite.

---

# 49. Concurrent Submit — Same Key

Two concurrent same-key requests for one Attempt must produce:

- one terminal transition;
- one completed idempotency record;
- same Attempt ID;
- same submitted/finalized instant;
- both logical outcomes `200`.

Do not produce duplicate claims/results.

---

# 50. Concurrent Submit — Different Keys

Two different Submit keys race for one editable Attempt.

Required:

- exactly one request may commit `student_submit`;
- winning key receives one completed successful record;
- loser sees the terminal Attempt and returns:
  ```text
  409 attempt_not_editable
  ```
- losing key leaves no completed/incomplete persisted claim;
- no timestamp/reason churn.

Do not treat different keys as equivalent retries.

---

# 51. Idempotency Key Reuse Across Attempts

Same Student:

```text
same operation
same Idempotency-Key
different Attempt ID
```

produces different fingerprint and must return:

```text
409 idempotency_key_reused
```

No mutation on the second Attempt.

---

# 52. Same Key Across Users

Idempotency scope remains:

```text
Institution
+
User
+
Operation
+
Key
```

Different Students may use the same UUID key independently.

No cross-user replay/collision.

---

# 53. Authorization During Replay

A completed key is not a bearer token.

Every replay first requires current authenticated Student ownership of the referenced Attempt through the persisted recipient graph.

Another Student or cross-Tenant caller:

```text
404 resource_not_found
```

even if they know:

- Attempt UUID;
- Idempotency-Key.

---

# 54. No Pair Mutation on Submit

Submit does not mutate:

```text
topic_result_pairs
```

The official pair was locked on first official Student activity during Start.

Do not change:

```text
homework_assessment_id
blitz_assessment_id
cohort_snapshotted_at
locked_at
updated_at
```

during Submit.

---

# 55. No Blitz Lifecycle Mutation on Submit

Student Submit does not:

- close Blitz;
- archive Blitz;
- change activated time;
- change timer snapshot;
- change synchronized common end.

The Blitz may remain:

```text
active
```

while one Student has already explicitly submitted.

Teacher Close remains independent.

---

# 56. No Recipient Mutation on Submit

Do not create/update/delete:

```text
assessment_students
```

The frozen activation assignment remains authoritative.

---

# 57. Homework Submit Preservation

Existing Homework Submit public behavior must remain exact:

```text
POST /student/attempts/{attempt}/submit
Idempotency-Key required
student.homework.attempt.submit
200
Homework submitted successfully.
```

Preserve:

- Homework deadline reconciliation;
- Homework `submitted` final state;
- `homework_deadline_auto_submit`;
- Teacher-close race;
- existing answer-integrity validation;
- existing idempotency semantics;
- existing response JSON.

Only the route boundary/request/result may become type-neutral.

No existing Homework test should be weakened.

---

# 58. Expected File Scope

Exact filenames may follow delivered dependency names.

## Create likely

```text
backend/app/Actions/Student/SubmitStudentAttempt.php
backend/app/Actions/Student/SubmitStudentBlitzAttempt.php

backend/app/Support/Student/StudentAttemptSubmitResult.php
backend/app/Support/Student/StudentBlitzHistoricalAnswerReadProof.php
  or one responsibility-equivalent internal typed replay/projection context

backend/app/Http/Controllers/Api/V1/Student/StudentAttemptSubmissionController.php
backend/app/Http/Requests/Student/StudentAttemptSubmitRequest.php

backend/tests/Feature/Student/StudentBlitzAttemptSubmitApiTest.php
backend/tests/Feature/Student/StudentBlitzAttemptSubmitLifecycleTest.php
backend/tests/Feature/Student/StudentBlitzAttemptSubmitIdempotencyTest.php
backend/tests/Feature/Student/StudentBlitzAttemptSubmitHistoricalReplayTest.php
backend/tests/Feature/Student/StudentBlitzAttemptStartHistoricalReplayTest.php
backend/tests/Feature/Student/StudentBlitzAttemptSubmitConcurrencyTest.php
backend/tests/Feature/Student/StudentBlitzAttemptSubmitCrossFeatureConcurrencyTest.php
```

## Rename/remove narrow submit-boundary classes

Replace:

```text
StudentHomeworkAttemptSubmitRequest
StudentHomeworkAttemptSubmitResult
```

with type-neutral equivalents.

`StudentHomeworkAttemptController` keeps its Homework Start/Show methods, but its Submit route/method may be removed/repointed to the shared submission controller.

## Modify

```text
backend/routes/api.php

backend/app/Actions/Student/SubmitStudentHomeworkAttempt.php
backend/app/Enums/IdempotencyOperation.php

backend/app/Support/Student/StudentHomeworkAnswerIntegrity.php
backend/app/Support/Student/StudentHomeworkAttemptAnswerStates.php
backend/app/Http/Resources/Student/StudentAttemptAnswerStateResource.php
  only if a no-behavior-change type/generalization is required; its public key
  set must remain unchanged

delivered BE-005/007:
StudentBlitzAttemptAccess
StartStudentBlitzAttempt
ShowStudentBlitzAttempt
StudentBlitzAttemptResource
the exact internal Start result/projection context used by the delivered Start action
only where directly required to:
- produce verified completed-Start replay proof;
- pass that proof into canonical Attempt projection;
- select pending-only vs historical-read answer-state projection;
- preserve the original Start replay HTTP/message semantics

delivered BE-007:
BlitzAttemptFinalizer
```

Optional narrow own-Attempt target extraction may update BE-006 shared answer
dispatch without changing mutation behavior.

Do not modify BE-005 public request validation to enable `start_replacement`
before BE-009.

Do not implement replacement Attempt creation in BE-008.

No migrations.

No Teacher API behavior change.

No frontend/docs/tasks.

---

# 59. Submit API Tests

Create:

```text
StudentBlitzAttemptSubmitApiTest
```

Cover:

- valid synchronized pre-deadline Submit;
- valid individual pre-deadline Submit;
- exact explicit finalization fields;
- `submitted_at = finalized_at = locked_at`;
- `student_submit`;
- status `submitted`;
- existing saved typed answers preserved;
- existing File answer preserved;
- no-answer Submit valid;
- unanswered Questions get no rows;
- no checking/scoring writes;
- exact response resource/message;
- no pair mutation;
- no Blitz lifecycle mutation.

---

# 60. Submit Request / Authorization Tests

Cover:

- missing Idempotency-Key;
- malformed key;
- uppercase UUID normalized;
- empty body accepted;
- `{}` accepted;
- non-empty body rejected;
- query rejected;
- malformed Attempt UUID -> 404;
- another Student -> 404;
- cross-Tenant -> 404;
- Homework still dispatches to Homework behavior;
- unsupported/corrupt Assessment type does not leak.

---

# 61. Submit Lifecycle Tests

Create:

```text
StudentBlitzAttemptSubmitLifecycleTest
```

Cover:

## Due

- just before deadline -> success;
- exact deadline -> reconcile timeout + `blitz_time_expired`;
- after deadline -> reconcile timeout + `blitz_time_expired`;
- exact timeout fields preserved;
- no successful Submit idempotency record on late Submit.

## Already terminal

- timeout-finalized + new key -> `blitz_time_expired`;
- student-submitted + new key -> `attempt_not_editable`;
- task-close-finalized + new key -> `attempt_not_editable`;
- future waiting/checked fixture retains terminal non-editable behavior according to finalization reason.

## Lifecycle

- in-progress under non-active Blitz structural fixture -> `blitz_not_active`;
- no terminal reason is rewritten.

---

# 62. Submit Idempotency Tests

Create:

```text
StudentBlitzAttemptSubmitIdempotencyTest
```

Cover:

- enum operation exact:
  ```text
  student.blitz.attempt.submit
  ```
- first success creates one completed record;
- same key/same Attempt replay -> 200 same logical result;
- replay has zero execution timestamp/reason churn;
- replay current `submitted + student_submit` accepted;
- forward-compatible replay current `waiting_for_teacher_review + student_submit` accepted;
- forward-compatible replay current `checked + student_submit` accepted;
- each later-stage replay preserves `submitted_at = finalized_at = locked_at` from the original Submit;
- timeout/close finalization lineage cannot replay as successful Student Submit;
- same key/different Attempt -> `idempotency_key_reused`;
- different Student same key independent;
- successful record metadata exact:
  ```text
  assessment_attempt
  Attempt UUID
  200
  ```
- failed lifecycle Submit leaves no claim;
- late Submit leaves no claim;
- injected failure before completion rolls back Attempt finalization and claim;
- replay after Teacher Close/Archive remains successful if Student still owns Attempt.

Do not satisfy later-stage replay tests by changing only `Attempt.status` while
leaving every answer `pending`.

Create/add:

```text
StudentBlitzAttemptSubmitHistoricalReplayTest
```

with persisted answer fixtures that contain **real non-pending metadata**.

## Waiting-for-review replay

Attempt:

```text
status = waiting_for_teacher_review
finalization_reason = student_submit
original submitted/finalized/locked timestamps preserved
```

Persist representative answers including:

```text
auto_checked
waiting_for_teacher_review
```

with non-null Stage-9-style checking fields where the current schema permits.

Same original Submit key/fingerprint must return:

```text
200
same logical Submit success
```

and the Student answer/file values must still project correctly.

## Checked replay

Attempt:

```text
status = checked
finalization_reason = student_submit
original submitted/finalized/locked timestamps preserved
```

Persist representative answers including:

```text
auto_checked
teacher_checked
```

and non-null schema-valid examples of:

```text
awarded_points
feedback
checked_by_user_id
checked_at
```

Same original Submit key/fingerprint:

```text
200
zero domain mutation
```

## Privacy

Recursively assert replay JSON does **not** contain:

```text
checking_status
awarded_points
feedback
checked_by_user_id
checked_at
earned_points
normalized_score
scoring_completed_at
```

The canonical Student answer value itself remains present.

## Pending-only regression

Directly prove the ordinary pending projection still rejects a non-pending
answer fixture.

Also prove a:

```text
new explicit Submit
```

cannot use historical projection to bypass pending execution integrity.

## Structural corruption

Historical read still fails on:

```text
foreign Institution answer
wrong Attempt ownership
wrong Question/Assessment
extra/wrong typed family
broken typed child ownership
broken AnswerFile/File ownership/category/current-file integrity
unknown checking_status if DB constraints are intentionally bypassed in a controlled fixture
```

No Stage 9 checker/scorer is implemented for these fixtures. Tests may arrange
schema-valid later metadata directly.

## Completed Start replay historical-answer tests

Create:

```text
StudentBlitzAttemptStartHistoricalReplayTest
```

Do not satisfy this test by changing only `Attempt.status` while answers stay
`pending`.

The fixture matrix must contain real schema-valid non-pending typed **and**
file-based saved Answers and must cover:

```text
normal Attempt #1
replacement Attempt #2 support fixture
start_normal completed replay identity
resume completed replay identity
start_replacement completed replay identity
student_submit lineage
timeout_auto_submit lineage
task_closed_auto_finalize lineage
waiting_for_teacher_review
checked
```

The matrix need not be a full Cartesian product, but every listed intent,
Attempt number and terminal lineage must be exercised at least once.

### Public normal Start / Resume replay

For already-delivered BE-005 intents, exercise the real public Start endpoint.

For each replay:

1. create/retain one completed `student.blitz.attempt.start` idempotency record;
2. retain the original exact fingerprint/body and `result_resource_id`;
3. advance the same Attempt fixture to an allowed later status/lineage;
4. persist real non-pending typed/file answer checking metadata;
5. send the same key + exact original body;
6. require the original logical HTTP `200/201`;
7. require the exact same Attempt ID;
8. require Student-safe canonical saved answers/files;
9. require zero domain mutation from replay.

### Replacement #2 forward-compatible support fixture

BE-008 executes before BE-009, so this task must **not** enable the public
`start_replacement` request early.

Instead, create a structural support-level fixture containing:

```text
valid replacement Attempt #2
valid recipient ownership
valid exception.replacement_attempt_id -> #2
completed student.blitz.attempt.start metadata
request identity = {"intent":"start_replacement"}
```

and exercise the same verified replay-proof -> canonical Attempt projection path
that BE-009 will later reuse.

Require:

```text
same #2
no #3
no new exception
no new idempotency result
historical answer/file projection works for waiting/checked
```

### Resume exact-target protection

Cover both:

```text
Resume #1
Resume #2 support fixture
```

and prove:

```text
original resume attempt_id = referenced Attempt ID
```

A changed Resume target with the same key must never enable historical mode and
must remain:

```text
409 idempotency_key_reused
```

or, for support-level proof construction, be rejected before proof creation.

### Lineage-specific assertions

Assert exact immutable execution history.

Student Submit:

```text
submitted_at = finalized_at = locked_at
finalization_reason = student_submit
finalized_at < deadline_at
```

Timeout:

```text
submitted_at = null
finalized_at = locked_at = deadline_at
finalization_reason = timeout_auto_submit
```

Teacher Close:

```text
submitted_at = null
finalized_at = locked_at
finalized_at < deadline_at
finalization_reason = task_closed_auto_finalize
```

Corrupt/mixed lineage:

```text
historical proof/projection fails
no timestamp/reason repair
```

### Idempotency immutability

Before/after replay compare the completed Start idempotency record fields and
require no churn to:

```text
operation
key
fingerprint/request hash
result_resource_type
result_resource_id
response_status
completed_at
```

No second successful/incomplete Start record is created.

### Authorization/privacy

Cover at minimum:

```text
another Student
cross-Tenant Student
recipient ownership mismatch
referenced Attempt mismatch
```

Historical answer projection must never bypass current Student authorization.

Recursively assert Student JSON does not expose:

```text
checking_status
awarded_points
feedback
checked_by_user_id
checked_at
earned_points
normalized_score
scoring_completed_at
correct-answer/checking configuration
```

### Pending-only regression

Prove all remain pending-only:

```text
fresh/new-key Start or Resume
new explicit Submit
typed answer mutation
file answer mutation
```

A caller cannot select historical mode using only:

```text
status
request body flag
query
client field
```

---

# 63. Submit Concurrency Tests

Create:

```text
StudentBlitzAttemptSubmitConcurrencyTest
```

Cover:

1. same key concurrent Submit;
2. different keys concurrent Submit;
3. Submit vs timeout reconciler;
4. Submit vs Teacher Close.

Required final invariants:

- one terminal transition;
- no timestamp/reason rewrite;
- one successful key for different-key race;
- timeout precedence after deadline;
- Teacher-close reason preserved if close wins pre-deadline.

---

# 64. Cross-Feature Concurrency Tests

Create:

```text
StudentBlitzAttemptSubmitCrossFeatureConcurrencyTest
```

Cover:

- typed answer vs Submit;
- file answer vs Submit.

Required:

## Student mutation commits first

Submit response contains/freeze sees the committed answer state.

## Submit commits first

later mutation makes zero persisted answer/file changes.

File loser compensates staged blob.

No Student mutation commits after Submit freeze.

---

# 65. Direct BE-007 Regression

Run delivered focused tests for:

```text
Blitz timeout reconciliation
Teacher Blitz Close
Scheduler timeout
Student timeout read reconciliation
```

because Submit reuses their lock/finalization behavior.

Use exact delivered filenames.

---

# 66. Direct BE-006 Regression

Run focused Student Blitz answer/file tests because Submit serializes with them
and uses their answer integrity support.

These regressions must prove the new historical read method did **not** weaken
the existing pending-only mutation path.

At minimum:

```text
StudentBlitzAnswerLifecycleTest
StudentBlitzAnswerConcurrencyTest
StudentBlitzFileAnswerLifecycleTest
StudentBlitzFileAnswerConcurrencyTest
```

Use exact delivered filenames.

---

# 67. Homework Submit Regression

Run the complete delivered Stage 7 Submit block:

```bash
php artisan test \
  tests/Feature/Student/StudentHomeworkAttemptSubmitApiTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitLifecycleTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitIdempotencyTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitConcurrencyTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitCrossFeatureConcurrencyTest.php
```

No existing assertion may be weakened merely because the route boundary becomes shared.

---

# 68. Verification Commands

Run from:

```text
backend/
```

## 68.1 New Blitz Submit tests

```bash
php artisan test \
  tests/Feature/Student/StudentBlitzAttemptSubmitApiTest.php \
  tests/Feature/Student/StudentBlitzAttemptSubmitLifecycleTest.php \
  tests/Feature/Student/StudentBlitzAttemptSubmitIdempotencyTest.php \
  tests/Feature/Student/StudentBlitzAttemptSubmitHistoricalReplayTest.php \
  tests/Feature/Student/StudentBlitzAttemptStartHistoricalReplayTest.php \
  tests/Feature/Student/StudentBlitzAttemptSubmitConcurrencyTest.php \
  tests/Feature/Student/StudentBlitzAttemptSubmitCrossFeatureConcurrencyTest.php
```

## 68.2 Direct BE-007 regression

Run the exact delivered focused Blitz timeout/close/Scheduler files affected by Submit.

## 68.2A Direct BE-005 Start/Resume regression

Run the delivered focused BE-005 Start/Resume/idempotency/resource tests directly
affected by completed Start replay projection.

They must prove:

```text
fresh start_normal unchanged
fresh exact Resume unchanged
same-key same-body replay unchanged
same-key body/Resume-target mismatch still rejected
same Attempt identity preserved
no timer reset
pre-Start Question privacy unchanged
```

Do not run a full backend suite here.

## 68.3 Direct BE-006 regression

Run the exact delivered focused Blitz answer/file lifecycle/concurrency files affected by Submit.

## 68.4 Homework Submit regression

```bash
php artisan test \
  tests/Feature/Student/StudentHomeworkAttemptSubmitApiTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitLifecycleTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitIdempotencyTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitConcurrencyTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitCrossFeatureConcurrencyTest.php
```

## 68.5 Format

```bash
./vendor/bin/pint --test
```

No additional static-analysis command is required unless current repository configuration makes one mandatory for exactly the changed backend scope.

## 68.6 Always

From repository root:

```bash
git diff --check
```

Do not run:

- full backend suite;
- frontend tests;
- Flutter analyze/build;
- broad E2E.

Full backend regression belongs to:

```text
S08-BE-PHASE-2
```

---

# 69. Acceptance Criteria — Shared Submit Route

- [ ] Canonical URL remains `/student/attempts/{attempt}/submit`.
- [ ] No Blitz-specific Submit route added.
- [ ] Shared request preserves strict header/body/query contract.
- [ ] Type-safe own Attempt dispatch supports Homework/Blitz.
- [ ] Homework public behavior unchanged.
- [ ] Shared Submit result boundary exists.

---

# 70. Acceptance Criteria — Successful Blitz Submit

- [ ] Own `in_progress` Blitz Attempt only.
- [ ] Topic/Blitz active.
- [ ] Required Idempotency-Key.
- [ ] Server `submittedAt` captured after lock waits.
- [ ] Must be strictly before `deadline_at`.
- [ ] Status becomes `submitted`.
- [ ] `submitted_at = finalized_at = locked_at = submittedAt`.
- [ ] Reason becomes `student_submit`.
- [ ] Deadline unchanged.
- [ ] Saved answers/files preserved.
- [ ] Missing answers remain absent.
- [ ] No checking/scoring.
- [ ] No pair/recipient/Blitz lifecycle mutation.
- [ ] Response is terminal Student Blitz Attempt + exact success message.

---

# 71. Acceptance Criteria — Timeout/Terminal

- [ ] Submit at exact deadline does not win over timeout.
- [ ] Late in-progress Submit invokes shared timeout reconciler.
- [ ] Late Submit returns `blitz_time_expired`.
- [ ] Late Submit leaves no successful/incomplete idempotency claim.
- [ ] New Submit on timed-out Attempt returns `blitz_time_expired`.
- [ ] New Submit on student-submitted Attempt returns `attempt_not_editable`.
- [ ] New Submit on task-close-finalized Attempt returns `attempt_not_editable`.
- [ ] No `submission_locked` code is added.
- [ ] Terminal reasons/timestamps never rewritten.

---

# 72. Acceptance Criteria — Idempotency

- [ ] Operation exact `student.blitz.attempt.submit`.
- [ ] Fingerprint based on own Attempt route identity.
- [ ] Successful transition and completed record atomic.
- [ ] Same-key replay returns same logical Submit success.
- [ ] Fresh successful Submit projects `submitted + student_submit`.
- [ ] Completed replay may project current `submitted|waiting_for_teacher_review|checked` only with original `student_submit` lineage.
- [ ] Later-stage replay preserves original submitted/finalized/locked execution timestamps and finalization reason.
- [ ] `submitted` replay still uses pending-only answer integrity.
- [ ] `waiting_for_teacher_review|checked` same-key replay uses historical read-only answer integrity.
- [ ] Historical replay accepts schema-valid non-pending checking metadata without implementing checking/scoring.
- [ ] Historical replay preserves tenant/question/typed/file canonical integrity.
- [ ] Historical replay exposes no checking/score metadata to Student.
- [ ] Verified completed `student.blitz.attempt.start` replay may use the same historical answer projection.
- [ ] Start historical replay requires completed record + exact fingerprint/body + result metadata + same referenced Attempt + current authorization.
- [ ] Start historical replay preserves original logical HTTP `200/201` and same Attempt identity.
- [ ] `start_normal`, exact `resume`, and forward-compatible `start_replacement` replay identities are all covered.
- [ ] Start replay with waiting/checked validates exact `student_submit|timeout_auto_submit|task_closed_auto_finalize` lineage rather than forcing Submit lineage.
- [ ] Same-key changed intent/Resume target cannot create historical proof.
- [ ] Historical Start replay creates no Attempt, exception or new idempotency result.
- [ ] Replacement #2 historical support does not enable public replacement Start before BE-009.
- [ ] Ordinary mutation/new Submit/new-key Start pending-only integrity remains unchanged.
- [ ] Timeout/Teacher-close lineage cannot masquerade as successful Submit replay.
- [ ] Same-key replay itself has zero domain timestamp/reason churn.
- [ ] Same key against different Attempt rejected as reused.
- [ ] Authorization still required during replay.
- [ ] Different-key terminal request is not treated as replay.
- [ ] Failed/late Submit does not leave a claim.
- [ ] Failure before completion rolls back both Attempt and claim.

---

# 73. Acceptance Criteria — Concurrency

- [ ] Submit vs answer/file serialized on Attempt.
- [ ] Submit vs timeout serialized.
- [ ] Submit vs Teacher Close serialized.
- [ ] Same-key concurrent requests commit one logical result.
- [ ] Different-key race has exactly one successful Submit key.
- [ ] Timeout wins when authoritative deadline already reached.
- [ ] No Student mutation commits after Submit finalization.
- [ ] No duplicate terminal transitions/idempotency success rows.

---

# 74. Scope Acceptance

- [ ] No migration.
- [ ] No Attempt exception/grant.
- [ ] No replacement Attempt creation.
- [ ] No monitoring.
- [ ] No checking/scoring implementation.
- [ ] Historical replay support is read-only projection compatibility only.
- [ ] No replacement Attempt creation/grant is implemented in BE-008.
- [ ] Public `start_replacement` remains BE-009-owned.
- [ ] No Student checking/score metadata is exposed.
- [ ] No frontend/docs/task changes.
- [ ] Focused Blitz Submit + Start historical replay tests pass.
- [ ] BE-005/006/007 direct regressions pass.
- [ ] Homework Submit regression passes.
- [ ] Pint passes.
- [ ] `git diff --check` passes.

---

# 75. Focused Diff Self-Check

Before completion confirm:

```text
shared final Submit route
+
Blitz explicit pre-deadline Submit
+
durable Submit idempotency
+
verified completed Start historical answer replay
```

Verify specifically:

```text
student_submit only before deadline
timeout engine owns late Submit
same-key successful Submit replay
completed Start replay proof requires exact original request identity
waiting/checked Start replay preserves student_submit/timeout/close lineage exactly
same referenced Attempt and original 200/201 Start result preserved
new-key Start/Submit remains pending-only/non-replay
no client-selected historical mode
new-key terminal conflict
no submission_locked
no scoring/checking
no Attempt #2 grant/creation logic
```

Confirm no unrelated refactor.

---

# 76. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. shared Submit route/request/dispatcher refactor;
4. exact Blitz Submit transition;
5. timeout/terminal precedence;
6. idempotency operation/fingerprint/result metadata;
7. same-key Submit replay behavior including later result-stage projection;
8. completed Start/Resume/replacement-Start historical replay proof policy;
9. lineage-specific waiting/checked projection (`student_submit|timeout_auto_submit|task_closed_auto_finalize`);
10. historical answer-read privacy boundary;
11. different-key terminal behavior;
12. response resource/message and preserved Start `200/201` replay semantics;
13. pending vs historical answer/file integrity validation;
14. concurrency behavior;
15. focused Blitz Submit/Start historical replay test results;
16. BE-005 regression results;
17. BE-007 regression results;
18. BE-006 regression results;
19. Homework Submit regression results;
20. Pint result;
21. `git diff --check`;
22. final `git status --short`;
23. focused scope/diff self-check;
24. any blocker/deviation.

Do not claim Stage 8 backend complete.

After delivery ChatGPT performs read-only acceptance review.

`S08-BE-009` remains blocked until:

```text
S08-BE-008 = Accepted / Delivered
```

---

# 77. Implementation Readiness Verdict

```text
Scope / non-goals                    = RESOLVED
Canonical shared Submit endpoint     = RESOLVED
Homework/Blitz dispatch              = RESOLVED
Strict Submit request                = RESOLVED
Blitz Submit idempotency operation   = RESOLVED
Fingerprint/replay metadata          = RESOLVED
Later result-stage Submit replay     = RESOLVED
Historical answer read policy         = RESOLVED
Completed Start historical replay      = RESOLVED
Start replay proof/fingerprint gate     = RESOLVED
Start terminal-lineage matrix           = RESOLVED
Pending-vs-historical integrity split  = RESOLVED
Successful pre-deadline transition   = RESOLVED
Late Submit reconciliation           = RESOLVED
Terminal error precedence            = RESOLVED
submission_locked conflict           = RESOLVED — not used
No-answer Submit                     = RESOLVED
Saved answer/file integrity          = RESOLVED
No checking/scoring boundary         = RESOLVED
Response projection                  = RESOLVED
Future Attempt #2 compatibility      = RESOLVED
Authorization/Tenant isolation       = RESOLVED
Concurrency/lock ordering            = RESOLVED
Homework regression boundary         = RESOLVED
Acceptance criteria                  = RESOLVED
Focused verification                 = RESOLVED

Implementation Readiness Gate        = PASS
Execution dependency                 = S08-BE-007 Accepted / Delivered
```
