# Codex Implementation Contract: S07-BE-007 — Idempotent Final Homework Submit

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S07-BE-007` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel idempotent explicit Student Homework Attempt final submission/freeze` |
| Depends on | `S07-BE-001…006` — all `Accepted / Delivered` before implementation |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Implementation baseline | ChatGPT re-checks/freezes current `origin/main` immediately before Codex starts |
| Readiness Gate | `PASS`, conditional on dependencies above |
| Verification | focused Submit/idempotency/lifecycle/concurrency verification only |
| Delivery | Project Owner |
| Backend block checkpoint | Stage 7 Backend Phase 2 immediately after this task block |

Start only after all dependencies are delivered, the implementation baseline is re-checked, and Git preflight is safe.

Do not create a duplicate `CODEX-PROMPT`.

---

# 2. Context Boundary

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. delivered `S07-BE-001…006` source/tests directly required here;
5. current `AssessmentAttemptStatus` and `AssessmentAttemptFinalizationReason`;
6. delivered:
   - `HomeworkAttemptFinalizer`;
   - `FinalizeHomeworkAttemptsAtDeadline`;
   - Student Attempt access/controller/resource;
   - `IdempotencyGuard`, fingerprint and operation enum;
   - answer/file persistence used only to prove preservation;
7. current Teacher Homework close/deadline tests only where directly needed for race regression.

Do not read roadmap/product/architecture/database/API docs, previous task files, Stage history/indexes/closure reviews, frontend, or unrelated modules to determine requirements.

This contract resolves:

- exact Submit endpoint;
- request/header contract;
- explicit Student finalization state;
- unanswered Question behavior;
- no-scoring Stage 7 boundary;
- durable idempotency semantics;
- lifecycle/deadline precedence;
- exactly-once Submit vs deadline/close/answer-write races;
- response shape;
- tests and verification.

If delivered dependencies materially conflict with this contract, return `BLOCKED` with exact evidence. Do not redesign.

---

# 3. Goal

Implement:

```text
POST /api/v1/student/attempts/{attempt}/submit
```

as the authoritative explicit Student finalization of one existing Homework Attempt.

A valid explicit Submit must freeze the current server-saved answer set and transition:

```text
in_progress
->
submitted
```

with:

```text
submitted_at = submittedAt
finalized_at = submittedAt
locked_at = submittedAt
finalization_reason = student_submit
```

The operation is high-risk and must use durable idempotency:

```text
student.homework.attempt.submit
```

Stage 7 stops at capture/finalization.

No answer checking, Teacher review, score, official-attempt selection or Topic-result calculation is performed here.

---

# 4. Explicit Non-Goals

Do not implement:

- automatic checking;
- deterministic Short Written scoring;
- Multiple Choice/Matching/Ordering/Fill scoring;
- file/manual review;
- `waiting_for_teacher_review`;
- `checked`;
- awarded points;
- Attempt normalized score;
- official Homework score selection/reselection;
- Topic result recalculation;
- Student result release;
- Teacher review API;
- Blitz;
- frontend;
- E2E/seeders;
- schema migration;
- docs/task bookkeeping;
- new package/dependency;
- unrelated refactor.

Do not fabricate unanswered `attempt_answers`.

---

# 5. Stage 7 Submit State

Explicit Student Submit always ends in:

```text
AssessmentAttemptStatus::Submitted
```

Set exactly:

```text
status = submitted
submitted_at = submittedAt
finalized_at = submittedAt
locked_at = submittedAt
finalization_reason = student_submit
```

Preserve:

```text
started_at
deadline_at
attempt_number
assessment_student_id
official_score_eligible
possible_points
```

Do not populate/change:

```text
earned_points
normalized_score
scoring_completed_at
```

Do not change any `attempt_answers` checking/scoring fields.

For every existing Answer preserve:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

Student Submit means:

> the answer set is frozen and ready for later Stage 9 checking.

It does **not** mean:

> checking is complete.

---

# 6. Unanswered Questions

A Student may explicitly submit an Attempt with:

- all Questions answered;
- some Questions unanswered;
- zero persisted answers.

Submit must **not** reject incomplete answer coverage.

Do not create:

```text
attempt_answers
```

for unanswered Questions/components.

Stage 9 later interprets absent answer state as zero for scoring.

Therefore this task has no:

```text
all_questions_answered
required_answer
incomplete_submission
```

validation/error.

A file-based Question is unanswered when no file Answer exists; Submit is still allowed.

---

# 7. Route

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
POST student/attempts/{attempt}/submit
```

Use delivered:

```text
StudentHomeworkAttemptController
```

and add method:

```text
submit
```

No alias route.

---

# 8. Submit Request

Create:

```text
backend/app/Http/Requests/Student/StudentHomeworkAttemptSubmitRequest.php
```

## 8.1 Required idempotency header

Require:

```http
Idempotency-Key: <uuid>
```

Normalize/expose as:

```text
idempotency_key
```

Rules:

```text
required
string
uuid
```

Missing/malformed:

```text
422 validation_failed
```

field:

```text
idempotency_key
```

Return lowercase canonical UUID from:

```text
idempotencyKey(): string
```

## 8.2 Body

Accept only:

```text
no body
```

or:

```http
Content-Type: application/json
```

```json
{}
```

Reject:

- non-empty JSON object;
- array;
- scalar/null;
- malformed JSON;
- non-empty non-JSON body.

Use:

```text
422 validation_failed
```

## 8.3 Query

No query parameters.

Any query key:

```text
422 validation_failed
```

Follow the strict empty lifecycle/Start POST pattern already delivered.

---

# 9. Preliminary Attempt Authorization

Before idempotency/domain mutation, resolve `{attempt}` using delivered:

```text
StudentHomeworkAttemptAccess::resolveAttempt(...)
```

or exact delivered equivalent.

Require complete own Homework Attempt chain:

```text
same Institution
attempt.student_id = authenticated Student
assessment_student ownership consistent
assessment.type = homework
homework assignment exists/readable
```

Malformed UUID, another Student, foreign Institution, broken/inaccessible chain:

```text
404 resource_not_found
```

Do not create/read an idempotency record for a target the Student is not authorized to know.

Current Group membership is not required.

Historical assignment snapshot remains authoritative.

---

# 10. Submit Idempotency Fingerprint

Reuse delivered:

```text
IdempotencyRequestFingerprint
```

Operation:

```text
IdempotencyOperation::StudentHomeworkAttemptSubmit
```

stable value:

```text
student.homework.attempt.submit
```

Fingerprint semantic identity:

```text
operation
institution_id
user_id
attempt_id
body = {}
```

Route identity:

```text
attempt_id = lowercase authorized Attempt UUID
```

Do not include:

- bearer token;
- request ID;
- current Attempt status;
- current Homework status;
- current answers;
- Idempotency-Key itself.

Thus a safe retry remains the same semantic request even after the Attempt later changes to a Stage 9 status.

---

# 11. Extend `HomeworkAttemptFinalizer`

Modify delivered:

```text
backend/app/Support/Assessment/HomeworkAttemptFinalizer.php
```

Add:

```text
finalizeByStudentSubmit(
    AssessmentAttempt $attempt,
    CarbonInterface $submittedAt
): bool
```

or exact project-typed equivalent.

## Precondition

Only transition:

```text
status = in_progress
```

and:

```text
submitted_at = null
finalized_at = null
locked_at = null
finalization_reason = null
```

If the Attempt is already terminal/non-editable:

```text
return false
```

with zero writes.

## Transition

Set one coherent transition instant:

```text
status = submitted
submitted_at = submittedAt
finalized_at = submittedAt
locked_at = submittedAt
finalization_reason = student_submit
updated_at = submittedAt
```

Do not change answer/scoring fields.

Return:

```text
true
```

after the save.

Existing BE-002 automatic methods remain unchanged:

```text
finalizeAtDeadline
finalizeAtClose
```

Do not merge reasons or make one generic ambiguous finalizer.

---

# 12. Submit Result

Create:

```text
backend/app/Support/Student/StudentHomeworkAttemptSubmitResult.php
```

Successful result:

```text
attemptId
httpStatus = 200
```

Deadline outcome may be represented internally by a marker so the transaction can commit deadline reconciliation before the public action throws.

No `201` path exists.

No public `replayed` flag.

---

# 13. Submit Action

Create:

```text
backend/app/Actions/Student/SubmitStudentHomeworkAttempt.php
```

Public conceptual signature:

```text
__invoke(
    User $student,
    string $attemptId,
    string $idempotencyKey
): StudentHomeworkAttemptSubmitResult
```

Flow:

1. preliminary privacy-safe own-Attempt resolution;
2. build Submit fingerprint;
3. enter one DB transaction;
4. lock current parent/Attempt state;
5. handle completed replay;
6. claim idempotency for a new logical request;
7. validate current lifecycle/deadline/editability;
8. freeze Attempt with `student_submit`;
9. complete idempotency record;
10. commit;
11. if transaction returned deadline marker, throw deadline exception after commit;
12. otherwise return success.

---

# 14. Lock Order

Inside the Submit transaction, use the delivered Student-safe parent order:

```text
Topic
-> Assessment
-> HomeworkAssignment
-> all Assessment Attempts ordered by id
```

Then identify the exact authenticated Student Attempt from the locked set.

Rationale:

- BE-002 deadline reconciliation operates on all in-progress Attempts;
- Teacher close uses the same Homework/Attempt aggregate;
- exact Submit-vs-deadline/close ordering must be deterministic.

Do not acquire:

```text
Group
current Group membership
result pair
Question
```

during Submit.

The official Topic result pair was already locked at first Attempt Start in BE-004 and Submit does not change its meaning.

---

# 15. Re-Verify Locked Attempt

After parent and all-Attempt locks, the route Attempt must still satisfy:

```text
id = preliminary authorized Attempt
institution_id = Student Institution
student_id = authenticated Student
assessment_id = locked Homework Assessment
assessment_student_id still points to this Student/Assessment assignment
```

If it disappeared/became inconsistent after preliminary resolution:

```text
404 resource_not_found
```

No mutation.

Do not substitute another in-progress Attempt.

---

# 16. Early Completed Idempotency Replay

After locks and before current lifecycle rules call delivered:

```text
IdempotencyGuard::completedReplay(...)
```

If a completed record with same fingerprint exists, require:

```text
result_resource_type = assessment_attempt
result_resource_id = this same Attempt ID
response_status = 200
```

Then return replay success immediately.

Do not re-run:

```text
Homework lifecycle
deadline gate
Attempt editability
answer validation
```

This permits safe replay after:

- later Homework close/archive;
- deadline;
- Stage 9 review/checking;
- another later normal Attempt.

Do not rewrite idempotency timestamps.

If completed metadata is inconsistent:

```text
server invariant failure
```

Do not silently repair.

Different fingerprint through the same scoped key:

```text
409 idempotency_key_reused
```

---

# 17. Acquire New Submit Claim

For no completed replay, call delivered:

```text
IdempotencyGuard::claim(...)
```

Scope remains:

```text
institution_id
user_id
operation = student.homework.attempt.submit
idempotency_key
```

If a concurrent transaction completed same fingerprint while waiting:

```text
return replay 200
```

If fingerprint differs:

```text
409 idempotency_key_reused
```

A new incomplete claim must either:

- be completed in the same successful Submit transaction; or
- roll back/abandon on rejected operation.

No committed incomplete record is allowed.

---

# 18. Capture Authoritative Submit Instant

After:

- parent locks;
- all Attempt locks;
- completed-replay check;
- idempotency claim/wait;

capture one:

```text
submittedAt = now()
```

Do not capture it before lock waits.

Use this same instant for explicit Student finalization fields:

```text
submitted_at
finalized_at
locked_at
updated_at
```

Client/device time is irrelevant.

---

# 19. Lifecycle Precedence for New Logical Submit

For a new idempotency claim apply locked current state.

## Topic

Require:

```text
Topic.status = active
```

Otherwise:

```text
409 task_not_active
```

## Homework

```text
draft    => 409 task_not_active
closed   => 409 task_closed
archived => 409 task_archived
active   => continue
```

No successful new Submit occurs after Teacher close/archive.

A completed same-key replay already bypassed these current lifecycle rules under Section 16.

---

# 20. Deadline Precedence

For new logical Submit:

```text
deadline reached
iff
homework.deadline_at != null
AND submittedAt >= homework.deadline_at
```

At exact equality:

```text
deadline wins
```

Student Submit is not accepted.

## Deadline flow

Because all Assessment Attempts are already locked:

1. abandon/delete the new incomplete Submit idempotency claim;
2. invoke delivered:

```text
FinalizeHomeworkAttemptsAtDeadline::finalizeLocked(
    $homework,
    $allLockedAttempts,
    $submittedAt
)
```

3. return an internal deadline marker;
4. commit the transaction;
5. outside the transaction throw:

```text
409 deadline_passed
```

Required result for the route Attempt if it was still in progress:

```text
status = submitted
submitted_at = null
finalized_at = exact homework deadline
locked_at = exact homework deadline
finalization_reason = homework_deadline_auto_submit
```

No `student_submit`.

No completed Submit idempotency record remains.

This also reconciles any other due in-progress Attempts for that Homework exactly as BE-002 requires.

---

# 21. Attempt Editability

After active/pre-deadline checks require:

```text
attempt.status = in_progress
attempt.submitted_at = null
attempt.finalized_at = null
attempt.locked_at = null
attempt.finalization_reason = null
```

If false:

```text
409 attempt_not_editable
```

No completed idempotency record.

Examples:

- different new key after an already explicit Student Submit;
- active Homework fixture with already terminal Attempt.

Do not reinterpret an already terminal Attempt as another successful Submit unless the same completed idempotency key/fingerprint is replayed.

---

# 22. Answer Snapshot Integrity

Submit does **not** require answers to exist.

It must not mutate answers.

Before finalization, lock/read no typed answer rows merely to count completeness.

The Attempt row lock is the mutation barrier because all BE-005/006 Student answer writes lock the same Attempt first.

Therefore:

```text
Submit acquires Attempt lock
=> no answer PUT/file replacement can commit concurrently past it
=> status changes to submitted
=> later answer writes fail as non-editable
```

Do not introduce N+1 Question/Answer validation on Submit.

Persisted answers were already validated at save time.

If direct DB corruption is encountered later by Stage 9, checking owns that integrity boundary.

---

# 23. Explicit Submit Transition

For a valid editable pre-deadline Attempt call:

```text
HomeworkAttemptFinalizer::finalizeByStudentSubmit(
    $attempt,
    $submittedAt
)
```

Require it returns:

```text
true
```

If it returns false after the action already validated editable locked state:

```text
server invariant failure
```

Do not continue.

No other Attempt is explicitly submitted by this operation.

---

# 24. Complete Idempotency in Same Transaction

After successful Attempt transition, call delivered:

```text
IdempotencyGuard::complete(...)
```

with:

```text
resourceType = assessment_attempt
resourceId = submitted Attempt ID
responseStatus = 200
```

Ordering:

```text
claim
-> locked validation
-> Attempt student_submit transition
-> complete idempotency record
-> commit
```

If idempotency completion fails:

```text
Attempt finalization must roll back
```

Never commit:

```text
submitted Attempt
+
missing/incomplete success idempotency record
```

---

# 25. Success Response

After successful/replayed action result, load the authoritative Attempt through delivered:

```text
ShowStudentHomeworkAttempt
```

and return delivered:

```text
StudentHomeworkAttemptResource
```

with all Student-safe Questions and saved answers.

Controller response:

```text
200 OK
```

and add top-level:

```json
{
  "message": "Homework submitted successfully."
}
```

Conceptual shape:

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

Do not add:

```text
checking
requires_teacher_review
score
normalized_score
awarded_points
official_attempt
```

in Stage 7.

A same-key replay returns the same top-level message and current safe representation of the same logical Attempt.

If Stage 9 has since changed the Attempt status, safe replay may reflect the current later status while preserving the original Submit logical success.

---

# 26. Controller

Modify delivered:

```text
backend/app/Http/Controllers/Api/V1/Student/StudentHomeworkAttemptController.php
```

Add thin:

```text
submit
```

Flow:

```text
validated request
-> authenticated Student
-> SubmitStudentHomeworkAttempt
-> ShowStudentHomeworkAttempt(result.attemptId)
-> StudentHomeworkAttemptResource
-> 200 + message
```

No lifecycle/idempotency/scoring logic in Controller.

---

# 27. Error Reuse

No new API error code is required if BE-004/005 were delivered correctly.

Reuse:

```text
resource_not_found
validation_failed
idempotency_key_reused
task_not_active
task_closed
task_archived
deadline_passed
attempt_not_editable
business_conflict
```

Do not add:

```text
submission_incomplete
already_submitted
checking_pending
```

The explicit already-submitted/new-key case is:

```text
attempt_not_editable
```

---

# 28. Idempotency Semantics

## Same key + same Attempt

First valid Submit:

```text
200
```

Retry:

```text
200
same logical Attempt
```

No new finalization write.

No timestamp rewrite.

## Same key + another authorized Attempt

Same Student, same Submit operation, same key, different Attempt route:

```text
409 idempotency_key_reused
```

No mutation of second Attempt.

## Same UUID key used for Start

Allowed independently because operation differs:

```text
student.homework.attempt.start
vs
student.homework.attempt.submit
```

## Another Student/Institution

Same UUID key may be used independently due scoped idempotency uniqueness.

## Failed new Submit

No persisted completed/incomplete Submit idempotency record after:

```text
task_not_active
task_closed
task_archived
deadline_passed
attempt_not_editable
business_conflict
404 authorization failure
422 validation failure
```

---

# 29. New Attempt After Submit

Successful Submit does not close Homework and does not consume more than the current persisted Attempt.

If:

```text
attempt_number < 3
Homework remains active
deadline still future/absent
```

the Student may later call BE-004 Start with a new idempotency key and create the next normal Attempt.

BE-007 must not create the next Attempt automatically.

It must not select an official/highest Attempt.

---

# 30. Submit vs Answer Save

Both use the parent Homework + Attempt lock chain.

Required serial outcomes.

## Answer save wins first

- answer save commits;
- Submit locks afterward;
- Submit freezes that saved answer;
- response includes it.

## Submit wins first

- Submit changes Attempt to `submitted`;
- later non-file/file answer write acquires lock;
- returns:

```text
409 attempt_not_editable
```

- no post-submit answer change.

No partial race state.

---

# 31. Submit vs File Replacement

Same rule as Section 30.

If file replacement wins:

- new File/Answer state commits;
- Submit freezes it.

If Submit wins:

- file replacement DB mutation is rejected;
- BE-006 new-blob compensation runs;
- existing file remains frozen.

Do not add special file handling inside Submit.

---

# 32. Submit vs Teacher Close

Both serialize on Homework/Attempt locks.

## Submit commits first

At valid pre-deadline time:

```text
Attempt reason = student_submit
```

Teacher close later:

- must not rewrite that terminal Attempt;
- closes Homework;
- preserves `student_submit`.

## Teacher close commits first before deadline

Attempt becomes:

```text
task_closed_auto_finalize
```

New Submit request with a new key sees:

```text
409 task_closed
```

No `student_submit`.

## Same successful Submit key retried after close

Idempotency replay:

```text
200
same logical Attempt
```

Current closed Homework does not invalidate the prior successful operation.

---

# 33. Submit vs Deadline

Exact-once rule:

```text
submittedAt < deadline
=> explicit Student Submit may win

submittedAt >= deadline
=> deadline wins
```

Because `submittedAt` is captured after lock acquisition:

- no request can pre-date its lock wait artificially;
- scheduler latency never extends eligibility.

If Student Submit commits first before deadline, later scheduler deadline reconciliation sees no in-progress Attempt and does not rewrite reason.

If deadline reconciliation/Teacher-close-after-deadline commits first, Submit cannot overwrite the terminal deadline reason.

---

# 34. Submit vs Submit Concurrency

## Same idempotency key

Two concurrent identical requests:

```text
same Student
same Attempt
same key
```

must produce:

```text
both HTTP 200
same Attempt ID
one student_submit transition
one completed Submit idempotency record
```

The second must replay.

## Different idempotency keys

Two concurrent Submit requests for same in-progress Attempt:

```text
winner => 200 student_submit
loser  => 409 attempt_not_editable
```

Final:

```text
one terminal Attempt
one completed successful Submit idempotency record
no completed record for losing key
```

Do not treat different keys as automatic replay aliases.

---

# 35. No-Op / Timestamp Rules

Successful explicit transition writes once.

Same-key replay must not change:

```text
submitted_at
finalized_at
locked_at
finalization_reason
Attempt.updated_at
idempotency completed_at
```

New-key already-terminal failure writes nothing.

Deadline rejection may validly write BE-002 deadline finalization but:

- no Student Submit fields;
- no Submit idempotency success.

Teacher-close failure path may already have committed close transition in its independent earlier transaction; Submit itself writes nothing.

---

# 36. Expected Files

## Create

```text
backend/app/Actions/Student/SubmitStudentHomeworkAttempt.php
backend/app/Support/Student/StudentHomeworkAttemptSubmitResult.php
backend/app/Http/Requests/Student/StudentHomeworkAttemptSubmitRequest.php

backend/tests/Feature/Student/StudentHomeworkAttemptSubmitApiTest.php
backend/tests/Feature/Student/StudentHomeworkAttemptSubmitIdempotencyTest.php
backend/tests/Feature/Student/StudentHomeworkAttemptSubmitLifecycleTest.php
backend/tests/Feature/Student/StudentHomeworkAttemptSubmitConcurrencyTest.php
```

## Modify

```text
backend/routes/api.php

backend/app/Support/Assessment/HomeworkAttemptFinalizer.php

backend/app/Http/Controllers/Api/V1/Student/StudentHomeworkAttemptController.php
```

Modify delivered Student Attempt access/support only if needed for one focused all-Attempts lock/reload helper.

No migration.

No answer/file persistence changes are expected.

No new exception/API-error mapping should be needed.

No scoring/docs/frontend/E2E files.

---

# 37. `StudentHomeworkAttemptSubmitApiTest`

At minimum cover:

## Route/middleware

Exact POST route registered once under Student middleware.

Other roles cannot use it.

## Strict request

Reject:

- missing Idempotency-Key;
- malformed key;
- non-empty body;
- malformed JSON;
- JSON array/scalar;
- query parameter.

Accept:

```text
no body
{}
```

## Explicit submit with answers

Create own active pre-deadline in-progress Attempt with:

- choice answer;
- written answer;
- matching/ordering/fill answer;
- file answer.

Submit.

Expect:

```text
200
status = submitted
submitted_at = submittedAt
finalized_at = submittedAt
locked_at = submittedAt
finalization_reason = student_submit
```

Verify every answer/file row unchanged.

Verify:

```text
checking_status = pending
awarded_points = null
Attempt score fields remain null
```

## Submit with zero answers

Must succeed exactly the same way.

No fabricated `attempt_answers`.

## Response

Contains:

```text
Student-safe questions
saved answers
message
```

Does not contain:

```text
checking
score
correct-answer keys
storage internals
```

## Next attempt remains possible

After explicit Attempt #1 submit, active pre-deadline Homework still permits BE-004 Start to create Attempt #2.

BE-007 itself creates no new row.

---

# 38. `StudentHomeworkAttemptSubmitIdempotencyTest`

At minimum:

## Same-key replay

First:

```text
200
```

Retry same key:

```text
200
same Attempt
```

DB:

```text
one Submit idempotency record
operation = student.homework.attempt.submit
response_status = 200
result_resource_type = assessment_attempt
result_resource_id = Attempt ID
```

Attempt finalization timestamps unchanged on retry.

## Replay after close/archive

Successful Submit first.

Then Teacher close/archive according to existing valid lifecycle.

Retry original same key.

Expect:

```text
200
```

same logical Attempt.

No new submit transition.

## Replay after later status progression

If safe to fixture a later Stage 9-valid enum state without implementing Stage 9 logic, set Attempt to an existing later terminal status such as:

```text
waiting_for_teacher_review
```

while preserving original submit fields.

Same original key still replays `200`.

Do not require the resource status to remain `submitted`.

## Different Attempt same key

Two authorized Attempts for same Student.

Key succeeds on A.

Same key on B:

```text
409 idempotency_key_reused
```

B unchanged.

## Operation isolation

Same UUID key used for prior Start and then Submit:

```text
allowed
```

because operation differs.

## Actor scope

Same key independently usable by another Student/Institution.

## Failed operations

No Submit idempotency row remains after lifecycle/deadline/non-editable failure.

---

# 39. `StudentHomeworkAttemptSubmitLifecycleTest`

At minimum:

## Privacy

- other Student Attempt;
- foreign Institution;
- malformed Attempt UUID;

→ `404`.

No idempotency record.

## Current Group membership removed

Persisted own assigned Attempt remains submittable while active/pre-deadline.

## Topic non-active inconsistent state

```text
409 task_not_active
```

## Closed

```text
409 task_closed
```

## Archived

```text
409 task_archived
```

## Already submitted/new key

```text
409 attempt_not_editable
```

No timestamp rewrite.

## Deadline exact

At:

```text
submittedAt == deadline
```

deadline wins.

Expect:

```text
409 deadline_passed
status = submitted
submitted_at = null
finalized_at = deadline
finalization_reason = homework_deadline_auto_submit
```

No Submit idempotency record.

## Deadline after

Same deadline behavior.

## Before deadline

Explicit `student_submit` wins.

## Deadline with other in-progress Students

Submit request arriving after deadline must invoke BE-002 locked reconciliation for all due in-progress Attempts for that Homework.

All get exact deadline finalization.

No fabricated Attempt for never-started recipients.

---

# 40. `StudentHomeworkAttemptSubmitConcurrencyTest`

Use real PostgreSQL process concurrency and repository lock-wait style.

No arbitrary sleep synchronization.

At minimum prove these two scenarios.

## 40.1 Same-key Submit race

One in-progress Attempt.

Two workers use same key.

First worker holds the Homework/Attempt lock after claiming the operation.

Second worker starts and must enter a PostgreSQL lock wait.

Final:

```text
both outcomes = 200
same Attempt
status = submitted
reason = student_submit
one completed Submit idempotency record
```

Transition timestamps written once.

## 40.2 Different-key Submit race

Two workers use different valid keys.

Final:

```text
one outcome = 200
other = attempt_not_editable
```

DB:

```text
one student_submit finalization
one completed Submit idempotency record
no completed record for loser
```

## 40.3 Submit vs answer save

If the test remains focused, include a third real lock race:

```text
Submit vs one BE-005 non-file answer replace
```

Required final state must correspond to one serialized order:

- answer-save then Submit; or
- Submit then rejected answer-save.

Never post-submit answer mutation.

If adding this makes the test materially too broad, cover it in a separate focused test file but still within BE-007.

---

# 41. Directly Affected Regression Tests

Run BE-007 tests plus:

```text
tests/Feature/Student/StudentHomeworkAttemptStartApiTest.php
tests/Feature/Student/StudentHomeworkAttemptIdempotencyTest.php
tests/Feature/Student/StudentHomeworkAnswerLifecycleTest.php
tests/Feature/Student/StudentHomeworkFileAnswerLifecycleTest.php

tests/Feature/Homework/HomeworkDeadlineFinalizationTest.php
tests/Feature/Homework/HomeworkDeadlineFinalizationConcurrencyTest.php

tests/Feature/Teacher/TeacherHomeworkLifecycleApiTest.php
```

Rationale:

- shared Student Attempt controller/resource/idempotency infrastructure is reused;
- answer/file editability must stop after Submit;
- deadline exact-once behavior is shared;
- Teacher close must preserve an already explicit `student_submit`.

Do not run full backend suite in this individual task.

Full backend regression belongs to Stage 7 Backend Phase 2.

---

# 42. Verification

Use the repository's normal Docker/Sail backend command wrapper.

Run required formatter/static check for changed PHP files.

Then exactly:

```bash
php artisan test \
  tests/Feature/Student/StudentHomeworkAttemptSubmitApiTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitIdempotencyTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitLifecycleTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitConcurrencyTest.php \
  tests/Feature/Student/StudentHomeworkAttemptStartApiTest.php \
  tests/Feature/Student/StudentHomeworkAttemptIdempotencyTest.php \
  tests/Feature/Student/StudentHomeworkAnswerLifecycleTest.php \
  tests/Feature/Student/StudentHomeworkFileAnswerLifecycleTest.php \
  tests/Feature/Homework/HomeworkDeadlineFinalizationTest.php \
  tests/Feature/Homework/HomeworkDeadlineFinalizationConcurrencyTest.php \
  tests/Feature/Teacher/TeacherHomeworkLifecycleApiTest.php
```

Then repository root:

```bash
git diff --check
```

and focused diff/scope self-review.

Do not run:

- full backend suite;
- frontend tests/build;
- broad E2E/integration Stage runner.

---

# 43. Acceptance Criteria

PASS only if all are true.

## Explicit finalization

- exact Submit route exists;
- only own assigned Homework Attempt is submittable;
- valid explicit Submit yields `status=submitted`;
- `submitted_at = finalized_at = locked_at = submittedAt`;
- reason exactly `student_submit`;
- unanswered Questions do not block Submit;
- no unanswered Answer rows are fabricated;
- answers/files remain unchanged.

## Stage 7 boundary

- no auto checking;
- no manual-review transition;
- no score fields;
- no official score/result logic;
- response contains no checking/score surface.

## Idempotency

- operation exactly `student.homework.attempt.submit`;
- same key/same Attempt safely replays;
- original response status is 200;
- different Attempt with same scoped key conflicts;
- Start/Submit operation keys remain independent;
- success transition + idempotency completion are atomic;
- rejected Submit leaves no persisted incomplete/success record.

## Lifecycle/deadline

- completed same-key replay survives later lifecycle changes;
- new Submit obeys current active Homework/Topic;
- exact `submittedAt >= deadline` gives deadline precedence;
- deadline reconciliation commits before `409 deadline_passed`;
- new key on already terminal Attempt gives `attempt_not_editable`.

## Concurrency

- same-key concurrent Submit yields one transition/one record/two 200 outcomes;
- different-key concurrent Submit yields one success and one non-editable failure;
- Submit serializes against answer/file writes;
- Teacher close/deadline never overwrite a winning earlier explicit Submit reason;
- explicit Submit never overwrites earlier deadline/close finalization.

## Scope

- no new Attempt auto-created;
- no migration;
- no answer/file mutation;
- no scoring/manual review/official result;
- no docs/frontend/E2E;
- no new dependency/unrelated refactor.

## Verification

- focused tests pass;
- named regressions pass;
- formatter/static check passes;
- `git diff --check` passes;
- focused self-review passes.

---

# 44. Locked Implementation Decisions

These are decisions, not suggestions:

```text
Submit endpoint = POST /student/attempts/{attempt}/submit
Idempotency-Key = required UUID
Submit operation = student.homework.attempt.submit
success HTTP = 200
explicit terminal status = submitted
submitted_at = explicit Student submit instant
finalized_at = same instant
locked_at = same instant
finalization_reason = student_submit
all/partial/zero answers = submit allowed
unanswered = no fabricated AttemptAnswer
checking/scoring = Stage 9
same-key replay bypasses later lifecycle
different-key already-submitted = attempt_not_editable
deadline comparison = submittedAt >= homework deadline
deadline at equality = deadline wins
submittedAt captured after lock/idempotency waits
Submit locks all Homework Attempts for exact deadline/close serialization
result pair = untouched by Submit
next Attempt = never auto-created
```

Codex must not substitute:

- `checked`;
- `waiting_for_teacher_review`;
- auto scoring;
- completeness requirement;
- client timestamp;
- scheduler latency as eligibility;
- generic “already submitted = 200” for a different idempotency key;
- pair/result mutation;
- submit-and-start-next behavior.

---

# 45. Completion Report

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
4. explicit finalization field evidence;
5. unanswered-answer preservation evidence;
6. idempotency evidence;
7. deadline/Teacher-close race evidence;
8. PostgreSQL concurrency evidence;
9. directly affected regressions;
10. `git diff --check`;
11. scope/non-goal confirmation;
12. deviations/blockers;
13. final `git status --short`.

Do not claim `Accepted`.

Do not commit/push/create PR/update Stage bookkeeping unless explicitly instructed later.
