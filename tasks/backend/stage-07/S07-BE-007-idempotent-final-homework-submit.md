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
| Current review baseline | `origin/main @ c4814a02122b13b99ed2c3fd5229a07309bbe4b8` |
| Implementation baseline | ChatGPT re-checks/freezes current `origin/main` immediately before Codex starts |
| Readiness Gate | Pending ChatGPT current-main revalidation after contract correction; implementation is not authorized until PASS |
| Verification | focused Submit/idempotency/lifecycle/concurrency verification only |
| Delivery | Codex = commit/push/create PR after all task verification passes; Project Owner = merge only after ChatGPT acceptance |
| Backend block checkpoint | Stage 7 Backend Phase 2 immediately after this task block |

Start only after all dependencies are delivered, ChatGPT current-main revalidation is PASS, the implementation baseline is re-checked, and Git preflight is safe.

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
   - `StudentHomeworkAttemptAnswerStates` -> `StudentHomeworkAnswerIntegrity`, also used by `ShowStudentHomeworkAttempt`;
   - answer/file persistence used only for the shared read-only integrity gate and preservation evidence;
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

Thus a retry remains the same semantic request after later Attempt status changes.
This fingerprint stability does not extend the Stage-7 Student-safe answer
projection to genuine Stage-9 checked Answers (Sections 16 and 25).

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

## Precondition / invariant behavior

Use the same structural semantics as the delivered BE-002 finalizer.

If:

```text
status != in_progress
```

then:

```text
return false
```

with zero writes.

If:

```text
status = in_progress
```

then require all:

```text
submitted_at = null
finalized_at = null
locked_at = null
finalization_reason = null
```

If an `in_progress` Attempt has any non-null finalization field, this is persisted
state corruption/invariant failure:

```text
throw LogicException / server invariant failure
```

Do not convert a structurally inconsistent `in_progress` Attempt into
`attempt_not_editable`, and do not silently repair it.

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

Deadline outcome is represented internally by a marker so the Submit
transaction can abandon its new claim and release its own locks before the
authoritative BE-002 public deadline reconciliation runs and commits.

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
4. acquire shared parent locks + `FOR UPDATE` on only the authenticated Student's route Attempt and re-verify the complete delivered structural invariant in Section 15;
5. handle completed replay;
6. claim idempotency for a new logical request;
7. capture authoritative `submittedAt` after lock/idempotency waits;
8. validate current Homework/Topic lifecycle;
9. if deadline is reached:
   - abandon the new incomplete claim;
   - return an internal deadline marker with zero Submit-domain writes;
10. require the structurally valid Attempt to be `in_progress` under Section 21;
11. load current Assessment Questions read-only in deterministic position/ID order and invoke delivered `StudentHomeworkAttemptAnswerStates` for the locked Attempt solely as the persisted-answer integrity gate in Section 22;
12. only after that gate succeeds, freeze the own Attempt with `student_submit`;
13. complete idempotency record;
14. commit;
15. if the transaction returned a deadline marker:
   - invoke delivered public `FinalizeHomeworkAttemptsAtDeadline(student.institution_id, assessment.id)`;
   - after reconciliation returns, throw `409 deadline_passed`;
16. otherwise return success.

Structural Attempt or saved Answer corruption throws `LogicException`, maps to
safe `500 server_error`, and rolls back the new Submit transaction/claim with
zero Submit mutation and no completed/incomplete Submit idempotency record.
An already completed historical record is never deleted or rewritten.

Do not perform all-Student deadline reconciliation inside the normal Submit transaction.

---

# 14. Lock Order and Lock Modes

Inside the Submit transaction acquire only:

```text
Topic
-> Assessment
-> HomeworkAssignment
-> authenticated Student's exact route AssessmentAttempt
```

The order and lock modes are fixed:

```text
Topic                               -> shared/read row lock
Assessment                          -> shared/read row lock
HomeworkAssignment                  -> shared/read row lock
authenticated Student route Attempt -> FOR UPDATE
```

Use the repository/Laravel PostgreSQL equivalent of a shared row lock
(`FOR SHARE` / established `sharedLock()` pattern).

Do **not** lock all Assessment Attempts for a normal explicit Submit.

Rationale:

```text
own Attempt FOR UPDATE
  = Submit vs this Student's answer/file mutation serialization boundary

shared Topic/Assessment/Homework
  = lifecycle/deadline/Teacher-close exclusion boundary

BE-002 public deadline reconciliation
  = all-due-Attempts reconciliation owner, invoked only after a late Submit
    releases its local Submit transaction
```

This permits different Students on the same Homework to Submit/save independently
while preserving exact races:

- Teacher close needs conflicting exclusive aggregate locks;
- scheduler deadline reconciliation needs conflicting Assessment/Homework locks;
- BE-005/006 answer/file mutation needs the same Student Attempt lock.

Do not blindly reuse an access helper if it acquires exclusive shared-parent locks
or all Assessment Attempts. Add only one focused Student Submit lock/reload method
if needed to preserve these exact semantics.

Do not acquire row locks on:

```text
Group
current Group membership
result pair
Question
Answer rows
File rows
other Students' Attempts
```

during Submit. The read-only Question/Answer/File reads needed by Section 22's
delivered shared integrity path are required; they must not add `FOR UPDATE`
locks. The own Attempt `FOR UPDATE` remains the Student answer/file mutation
barrier.

The official Topic result pair was already locked at first Attempt Start in BE-004
and Submit does not change its meaning.

If delivered dependency code cannot provide these semantics without a material
architecture conflict, return `BLOCKED` with exact evidence rather than falling
back to coarse aggregate/all-Attempt locking.

---

# 15. Re-Verify Locked Attempt

After shared parent locks and the exact route Attempt `FOR UPDATE` lock,
re-resolve the previously authorized exact Attempt and require the complete
Homework Attempt structural invariant already delivered by BE-005/006:

```text
attempt.id = preliminary authorized Attempt
attempt.institution_id = authenticated Student Institution
attempt.student_id = authenticated Student
attempt.assessment_id = locked Homework Assessment
attempt.assessment_student_id = authoritative persisted AssessmentStudent
attempt.deadline_at = null

status in:
- in_progress
- submitted
- waiting_for_teacher_review
- checked

finalization_reason != timeout_auto_submit
```

For `in_progress`, also require:

```text
submitted_at = null
finalized_at = null
locked_at = null
finalization_reason = null
```

`timed_out_finalized` / `timeout_auto_submit` remain Blitz-only. They are
structural corruption on a Homework Attempt, not ordinary non-editability.

If the previously authorized exact Attempt disappears from or fails locked
structural re-resolution, including identity/assignment drift:

```text
LogicException / safe 500 server_error
zero Submit mutation
no Submit idempotency completion
```

Do not map this post-authorization corruption to ordinary `404`; Section 9's
privacy-safe `404` applies to unsuccessful preliminary authorization. Roll back
any new Submit claim and preserve any historical completed record unchanged.

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

Then return the successful action result immediately. The complete locked
Attempt structural invariant in Section 15 still applies; terminal status alone
does not invalidate a historical success.

Do not re-run:

```text
Homework lifecycle
deadline gate
Attempt editability
the new in-progress Submit persisted-answer integrity gate
```

With saved Answers still valid for the delivered Stage-7 Student-safe projection,
this permits endpoint replay after:

- later Homework close/archive;
- deadline;
- later Attempt terminal status progression;
- another later normal Attempt.

BE-007 guarantees durable Submit/idempotency replay semantics. It may test later
Attempt terminal status progression while saved Answers remain valid Stage-7
pending state. It does not implement or validate genuine Stage-9 checked-answer
projection.

The HTTP response still uses `ShowStudentHomeworkAttempt` and its delivered
shared integrity path (Section 25). If current persisted corruption prevents a
Student-safe representation, safe `500 server_error` is allowed; the historical
completed record must remain unchanged. Do not delete/rewrite that record or its
timestamps because response projection fails.

Stage 9 must extend the Student-safe read/integrity projection for legitimate
later checking states while preserving the completed BE-007 Submit idempotency
record and replay semantics. BE-007 must not relax Stage-7 Answer integrity to
accept checked/scored Answers.

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

- shared parent locks;
- exact route Attempt `FOR UPDATE` lock;
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

A completed same-key replay already bypassed current lifecycle rules under
Section 16.

For a **new** idempotency claim, use the same precedence as BE-005/006.

## 19.1 Homework lifecycle first

Apply the locked Homework state:

```text
closed   => 409 task_closed
archived => 409 task_archived
draft    => 409 task_not_active
active   => continue
```

No successful new Submit occurs after Teacher close/archive.

## 19.2 Active-parent consistency

Only when Homework is `active`, require:

```text
Topic.status = active
```

Otherwise:

```text
409 task_not_active
```

This keeps Submit error precedence aligned with Student answer/file mutation:
Homework lifecycle is authoritative first; a non-active/inconsistent Topic only
maps to `task_not_active` for an otherwise active Homework.

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

Do **not** lock/reconcile all Assessment Attempts inside the Submit transaction.

When the locked `submittedAt` is at/effectively after deadline:

1. abandon/delete the new incomplete Submit idempotency claim;
2. perform zero Submit-domain writes;
3. return an internal marker containing at least:
   - `institutionId`;
   - `assessmentId`;
4. commit/release the Submit transaction;
5. invoke delivered public:

```text
FinalizeHomeworkAttemptsAtDeadline(
    student.institution_id,
    assessment.id
)
```

6. only after that reconciliation returns, throw:

```text
409 deadline_passed
```

The public BE-002 action is the authoritative owner of all-due-Attempt locking
and reconciliation.

Required route-Attempt outcome if it was still `in_progress` when BE-002
reconciliation obtained its locks:

```text
status = submitted
submitted_at = null
finalized_at = exact homework deadline
locked_at = exact homework deadline
finalization_reason = homework_deadline_auto_submit
```

If another valid BE-002/Teacher-close-at-or-after-deadline transaction finalized
the Attempt first, Submit must not overwrite that terminal state; the public
reconciliation may validly return zero and the API still returns
`409 deadline_passed`.

No `student_submit`.

No completed/incomplete Submit idempotency record remains.

This reconciles every due in-progress Attempt for that Homework exactly as
delivered BE-002 requires without turning ordinary Student Submit into a
class-wide lock.

---

# 21. Attempt Editability / Structural Integrity

For a new logical Submit after active/pre-deadline checks, use the complete
locked structural invariant from Section 15 before deciding editability. Never
reduce it to a status-only check.

## Structurally valid terminal/non-editable status

If:

```text
the complete Section 15 invariant holds
attempt.status in submitted / waiting_for_teacher_review / checked
```

return:

```text
409 attempt_not_editable
```

Zero Submit mutation; roll back the new claim so no completed/incomplete Submit
idempotency record remains.

Examples:

- different new key after an already explicit Student Submit;
- active Homework fixture with an already terminal Attempt.

## Corrupt `in_progress` state

If:

```text
attempt.status = in_progress
```

require all:

```text
attempt.submitted_at = null
attempt.finalized_at = null
attempt.locked_at = null
attempt.finalization_reason = null
```

Any violation is a persisted invariant failure:

```text
LogicException / safe 500 server_error
zero Submit mutation
no Submit idempotency completion
```

Do not map this corrupt `in_progress` shape to `attempt_not_editable`.

Identity/assignment drift, disappearance after preliminary authorization,
non-null Attempt `deadline_at`, disallowed status, and `timeout_auto_submit` are
also structural corruption under Section 15, even on an otherwise terminal row.
They must not become `404` or `409 attempt_not_editable`.

A structurally valid `in_progress` Attempt may proceed to the persisted-answer
integrity gate; only after that gate succeeds may it Submit.

Do not reinterpret an already terminal Attempt as another successful Submit
unless the same completed idempotency key/fingerprint is replayed.

---

# 22. Pre-Finalization Persisted-Answer Integrity Gate

For a **new valid in-progress Submit**, after lifecycle/deadline/Attempt
structural validation and before `finalizeByStudentSubmit()`:

1. load current Assessment Questions read-only in deterministic position/ID order;
2. invoke delivered `StudentHomeworkAttemptAnswerStates` for the locked Attempt;
3. use it only as a persisted-answer integrity gate.

Reuse the delivered BE-006 path also used by `ShowStudentHomeworkAttempt`:

```text
StudentHomeworkAttemptAnswerStates
-> StudentHomeworkAnswerIntegrity
```

Do not introduce a second Submit-specific Answer validator or N+1 validation.
Keep the delivered Stage-7 integrity requirements for every existing Answer:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

Submit does **not** require all Questions answered or any saved Answers to exist.
Do not fabricate, score/check, repair, or mutate Answers/Files. Do not acquire
Answer/File `FOR UPDATE` or Question row locks for this gate.

The Attempt row lock remains the mutation barrier because all BE-005/006 Student
answer/file writes lock the same Attempt first.

Therefore:

```text
Submit acquires Attempt lock
=> no answer PUT/file replacement can commit concurrently past it
=> shared read-only persisted-answer integrity gate succeeds
=> only then status changes to submitted
=> later answer writes fail as non-editable
```

If any existing non-file or file-based Answer is structurally corrupt:

```text
LogicException
=> safe 500 server_error
=> Submit transaction rollback
=> Attempt remains in_progress
=> no completed/incomplete Submit idempotency record
=> answers/files unchanged
```

Save-time validation alone is insufficient. Submit must not commit a submitted
Attempt/completed 200 record and only afterward discover pre-existing saved
Answer corruption while building the HTTP response. Only a successful integrity
gate permits finalization, idempotency completion, and commit.

---

# 23. Explicit Submit Transition

For a structurally valid editable pre-deadline Attempt, only after Section 22's
shared persisted-answer integrity gate succeeds, call:

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
-> shared read-only persisted-answer integrity gate
-> Attempt student_submit transition
-> complete idempotency record
-> commit
```

If the persisted-answer integrity gate fails, roll back the new claim with zero
Attempt/Answer/File writes and no completed/incomplete Submit record. If
idempotency completion fails:

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

For a new valid in-progress Submit, Section 22 invokes the same delivered
`StudentHomeworkAttemptAnswerStates` -> `StudentHomeworkAnswerIntegrity` path
before finalization/commit. Response construction must not be the first point at
which pre-existing saved Answer corruption is detected.

When the current Student-safe representation can be produced, a same-key replay
returns the same top-level message and current representation of the same logical
Attempt. Later Attempt terminal status progression may be tested while all saved
Answers remain valid Stage-7 pending state.

Corruption introduced after a historically successful Submit may prevent that
current representation. Safe `500 server_error` is allowed in that case; it must
never delete/rewrite the historical completed idempotency record, re-finalize the
Attempt, or mutate Answers/Files.

BE-007 guarantees durable Submit/idempotency replay semantics. It does not
implement or validate genuine Stage-9 checked-answer projection. Stage 9 must
extend the Student-safe read/integrity projection for legitimate later checking
states while preserving the completed BE-007 Submit idempotency record and replay
semantics. Keep Stage-7 `checking_status = pending` and all awarded/checking fields
null; do not accept checked/scored Answers in BE-007.

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
server_error
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

Retry while the current Student-safe representation remains valid:

```text
200
same logical Attempt
```

No new finalization write.

No timestamp rewrite.

Durable Submit/idempotency replay semantics survive later Attempt terminal status
progression. BE-007 endpoint replay tests keep saved Answers in valid Stage-7
pending state; genuine Stage-9 checked-answer projection remains Stage 9 work.
If later persisted corruption prevents the current safe representation, safe
`500 server_error` is allowed and the historical completed record stays unchanged.

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
500 server_error from Attempt structural or persisted-answer corruption
```

This zero-record rule applies to a failed **new** Submit. It never permits
deleting/rewriting a completed historical record when later projection fails.

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
backend/tests/Feature/Student/StudentHomeworkAttemptSubmitCrossFeatureConcurrencyTest.php
```

## Modify

```text
backend/routes/api.php

backend/app/Support/Assessment/HomeworkAttemptFinalizer.php

backend/app/Http/Controllers/Api/V1/Student/StudentHomeworkAttemptController.php
```

Modify delivered Student Attempt access/support only if needed for one focused
shared-parent + exact-route-Attempt lock/reload helper.

Do not add an all-Attempts lock helper for Submit.

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
feedback = null
checked_by_user_id = null
checked_at = null
Attempt score fields remain null
```

## Submit with partial answers

Must succeed after the delivered shared persisted-answer integrity gate, with
every saved Answer/File unchanged and no fabricated rows for unanswered Questions.

## Submit with zero answers

Must succeed exactly the same way.

No fabricated `attempt_answers`.

## Persisted-answer corruption before finalization

Cover both an existing non-file Answer and a file-based Answer rejected by the
delivered shared integrity path. Each new Submit must return safe
`500 server_error`, keep the Attempt `in_progress`, leave zero completed/incomplete
Submit records, and preserve Answer/File rows and file contents. Section 38's
fixed-key regressions must prove this happens before finalization/completion,
rather than only while building the response after commit.

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

Fixture later existing Attempt terminal statuses:

```text
waiting_for_teacher_review
checked
```

while preserving original submit fields and keeping all saved Answers in valid
Stage-7 pending state:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

Same original key still replays `200`.

Do not require the resource status to remain `submitted`.

This proves durable Submit/idempotency replay with later Attempt status
progression only. It does not implement or validate genuine Stage-9 checked-answer
projection. Stage 9 must extend that Student-safe read/integrity projection while
preserving the completed BE-007 record and replay semantics.

## Fixed-key corruption rollback and recovery

Add separate focused regressions for:

- a structurally corrupt persisted non-file Answer;
- a structurally corrupt persisted file-based Answer.

For each case, start with an existing active pre-deadline own `in_progress`
Attempt and one fixed new Submit UUID Idempotency-Key `K`. Corrupt only the saved
Answer fixture in a way rejected by delivered `StudentHomeworkAttemptAnswerStates`
-> `StudentHomeworkAnswerIntegrity`.

Assert this exact sequence using the same `K` throughout:

```text
Submit K -> safe 500 server_error
Attempt remains in_progress; zero Submit idempotency records

retry K -> safe 500 server_error
Attempt remains in_progress; still zero completed/incomplete Submit records

repair only test fixture

Submit K -> 200
Attempt.status = submitted
Attempt.finalization_reason = student_submit
exactly one completed Submit idempotency record

replay K -> 200
same completed record
no timestamp churn
```

Compare Attempt/finalization fields before and after each failed request. Compare
Answer/File row and file-content snapshots before/after every request to prove
Submit never mutates them; only the explicit fixture repair may alter the saved
fixture. Successful replay must preserve all Section 35 Attempt/idempotency
timestamps and the completed record's identity/metadata.

## Corruption after historical success

First Submit `K` successfully and snapshot its completed idempotency record and
Attempt finalization fields. Then introduce persisted saved Answer corruption
through the test fixture and retry the original `K`.

If the current Student-safe representation cannot be produced, expect safe
`500 server_error` while the same historical completed record remains unchanged
in full, including timestamps and result metadata. Repeated failed projection
must not delete/rewrite that record, re-finalize the Attempt, or mutate
Answers/Files. This is distinct from the zero-record rule for a failed new Submit.

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

No Submit idempotency row remains after a new lifecycle/deadline/non-editable or
structural/Answer integrity failure. Historical success records remain unchanged
when later response projection fails.

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

## Structurally valid terminal/new key

Cover each allowed terminal status (`submitted`, `waiting_for_teacher_review`,
`checked`) with the complete Section 15 invariant intact and saved Answers still
valid Stage-7 pending state:

```text
409 attempt_not_editable
```

No timestamp rewrite.

Zero Submit mutation and no completed/incomplete record for the new key.

## Complete locked Homework Attempt invariant

Prove safe `500 server_error` / `LogicException` for every failed Section 15
structural requirement, including:

- the exact previously authorized Attempt disappearing during locked re-resolution;
- identity/Institution/Student/Assessment drift after successful preliminary authorization;
- `assessment_student_id` differing from the authoritative persisted AssessmentStudent;
- non-null Attempt `deadline_at`;
- status outside `in_progress`, `submitted`, `waiting_for_teacher_review`, `checked`,
  including Blitz-only `timed_out_finalized`;
- Blitz-only `finalization_reason = timeout_auto_submit`, including on an otherwise
  allowed terminal status.

Use deterministic fixture/interleaving setup for post-authorization drift; retain
Section 9's privacy-safe `404` for unsuccessful preliminary authorization. Failed
locked re-resolution must never become ordinary `404` or `attempt_not_editable`.
Every structural failure has zero Submit mutation and no completed/incomplete
new Submit record; do not repair or substitute an Attempt.

## Corrupt in-progress finalization fields

Fixture:

```text
status = in_progress
submitted_at != null
```

Cover each non-null field independently: `submitted_at`, `finalized_at`,
`locked_at`, and `finalization_reason`.

Expect `LogicException` / safe `500 server_error`, zero Submit mutation, and no
completed/incomplete new Submit record.

Do not return `attempt_not_editable` and do not repair/mutate the row.

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

# 40. Submit Concurrency Verification

Use real PostgreSQL process concurrency and the repository's deterministic
lock-wait style.

No arbitrary sleep synchronization.

Split the proof into the two focused files declared in Section 36.

All successful new Submit paths must include Section 22's shared read-only
persisted-answer integrity gate while the own Attempt lock is held. That gate
must preserve the lock modes and cross-Student independence below; it adds no
Question/Answer/File row locks or Submit-specific answer validation.

## 40.1 `StudentHomeworkAttemptSubmitConcurrencyTest`

Own Submit/idempotency lock behavior only.

### Same-key Submit race

One in-progress Attempt.

Two workers use the same key.

First worker holds the exact route Attempt/idempotency transaction state.

Second worker must enter a real PostgreSQL lock wait.

Final:

```text
both outcomes = 200
same Attempt
status = submitted
reason = student_submit
one completed Submit idempotency record
```

Transition/idempotency completion timestamps are written once.

### Different-key Submit race

Two workers use different valid keys for the same Attempt.

Final:

```text
one outcome = 200 student_submit
other outcome = 409 attempt_not_editable
```

DB:

```text
one student_submit finalization
one completed Submit idempotency record
no completed/incomplete record for loser
```

### Different Students / same Homework non-blocking regression

Two Students own different `in_progress` Attempts in the same Homework.

Each uses a different valid Submit key.

Worker A holds:

```text
shared Topic/Assessment/Homework locks
FOR UPDATE on Attempt A
```

Worker B must be able to obtain:

```text
shared Topic/Assessment/Homework locks
FOR UPDATE on Attempt B
```

without waiting on A merely because the Homework is shared.

Both may complete independently with `200 student_submit`.

This test must fail if Submit accidentally takes exclusive shared-parent locks or
locks all Assessment Attempts.

## 40.2 `StudentHomeworkAttemptSubmitCrossFeatureConcurrencyTest`

Prove the Stage 7 freeze boundary against the delivered cross-feature writers/
finalizers.

### Submit vs non-file answer save

Real race against one BE-005 answer replace.

Allowed serialized outcomes only:

- answer save commits first -> the shared integrity gate reads the committed
  saved state, then Submit freezes the new answer;
- Submit commits first -> answer save returns `409 attempt_not_editable`.

Never post-Submit answer mutation.

### Submit vs file replacement

Real race against BE-006 replacement.

Allowed serialized outcomes only:

- replacement commits first -> the shared integrity gate reads the committed
  saved state, then Submit freezes the new stable File state;
- Submit commits first -> replacement DB mutation is rejected and BE-006 new-blob
  compensation runs.

Never post-Submit File/Answer mutation.

Use deterministic local private storage if cross-process blob compensation cannot
be verified faithfully with a fake.

### Submit vs Teacher close

Use delivered `CloseTeacherHomework`.

Prove both lock orders:

```text
Submit wins before deadline
-> Attempt = student_submit
-> close later preserves that terminal reason

Teacher close wins before deadline
-> Attempt = task_closed_auto_finalize
-> new Submit = 409 task_closed
-> no Submit idempotency record
```

The second worker must demonstrate a real PostgreSQL wait on the conflicting
aggregate/Attempt chain where expected.

### Submit vs deadline reconciliation

Use delivered public `FinalizeHomeworkAttemptsAtDeadline`.

Prove both authoritative orders around the exact deadline:

```text
Submit obtains locks and submittedAt < deadline
-> 200 student_submit
-> later deadline reconciliation does not rewrite it

deadline reconciliation wins / Submit obtains locks at-or-after deadline
-> deadline finalization wins
-> Submit leaves no idempotency claim
-> 409 deadline_passed
```

Also prove the late-Submit path releases its local transaction before invoking
the public BE-002 all-Attempt reconciliation; do not implement class-wide locking
inside Submit itself.

### No arbitrary sleeps

Use process markers/backend PIDs/`pg_blocking_pids` or the equivalent existing
BE-002 lock-wait pattern. Narrow polling sleeps used only by the deterministic
test harness are allowed; arbitrary sleeps used as race ordering are not.

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
- Submit reuses the same read-only `StudentHomeworkAttemptAnswerStates` ->
  `StudentHomeworkAnswerIntegrity` path as Show; its non-file/file integrity
  contract and pending-only Stage-7 projection remain unchanged;
- answer/file editability must stop after Submit;
- deadline exact-once behavior is shared;
- Teacher close must preserve an already explicit `student_submit`.

Do not run full backend suite in this individual task.

Full backend regression belongs to Stage 7 Backend Phase 2.

The new fixed-key non-file/file corruption, rollback/recovery, and historical
record preservation proofs belong to the BE-007 tests in Sections 37–39. They
do not authorize broader regression suites or genuine Stage-9 projection tests.

---

# 42. Verification

Run from the repository root.

## 42.1 PHP formatting

Exactly:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app ./vendor/bin/pint --test
```

The repository currently has no separate PHPStan/Psalm task-level static
analyzer requirement for this change. Do not invent one.

## 42.2 Focused BE-007 + directly affected regressions

Exactly:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app php artisan test \
  tests/Feature/Student/StudentHomeworkAttemptSubmitApiTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitIdempotencyTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitLifecycleTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitConcurrencyTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitCrossFeatureConcurrencyTest.php \
  tests/Feature/Student/StudentHomeworkAttemptStartApiTest.php \
  tests/Feature/Student/StudentHomeworkAttemptIdempotencyTest.php \
  tests/Feature/Student/StudentHomeworkAnswerLifecycleTest.php \
  tests/Feature/Student/StudentHomeworkFileAnswerLifecycleTest.php \
  tests/Feature/Homework/HomeworkDeadlineFinalizationTest.php \
  tests/Feature/Homework/HomeworkDeadlineFinalizationConcurrencyTest.php \
  tests/Feature/Teacher/TeacherHomeworkLifecycleApiTest.php
```

Narrow diagnostic reruns of one failing test are allowed only to diagnose or
confirm a concrete failure.

The named BE-007 tests must include the complete Attempt structural invariant,
shared integrity gate before finalization, both fixed-key corruption/recovery
regressions, and preservation of historical completed records on later projection
failure. Later terminal-status replay fixtures must retain valid Stage-7 pending
Answers. Do not expand the command to Stage-9 checking/projection verification.

## 42.3 Diff hygiene

Exactly:

```bash
git diff --check
```

Then perform the focused diff/scope self-review required by root/backend
`AGENTS.md`.

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
- response contains no checking/score surface;
- every existing Answer retains `checking_status = pending`, `awarded_points = null`,
  `feedback = null`, `checked_by_user_id = null`, and `checked_at = null`;
- BE-007 guarantees durable Submit/idempotency replay semantics and may test later
  Attempt terminal status progression only while Answers remain valid Stage-7
  pending state;
- genuine Stage-9 checked-answer projection is neither implemented nor validated;
- Stage 9 must extend the Student-safe read/integrity projection for legitimate
  later checking states while preserving the completed BE-007 record and replay
  semantics; BE-007 does not accept checked/scored Answers.

## Complete Homework Attempt invariant

- locked `attempt.id` matches the preliminary authorized Attempt;
- locked Institution/Student/Assessment match authenticated Student context and
  the locked Homework Assessment;
- `assessment_student_id` matches the authoritative persisted AssessmentStudent;
- Attempt `deadline_at = null`;
- status is one of `in_progress`, `submitted`, `waiting_for_teacher_review`, `checked`;
- `finalization_reason != timeout_auto_submit`; Blitz-only `timed_out_finalized`
  and `timeout_auto_submit` are rejected as corruption;
- `in_progress` requires `submitted_at`, `finalized_at`, `locked_at`, and
  `finalization_reason` all null;
- disappearance/identity drift after successful preliminary authorization or any
  structural violation produces `LogicException` / safe `500 server_error`, zero
  Submit mutation, and no new Submit idempotency completion; it is never ordinary
  `404` or `attempt_not_editable`;
- only a structurally valid terminal Attempt maps to new-key `409 attempt_not_editable`.

## Persisted-answer integrity before finalization

- after lifecycle/deadline/Attempt validation, every new valid `in_progress`
  Submit loads current Assessment Questions read-only in deterministic position/ID
  order and invokes delivered `StudentHomeworkAttemptAnswerStates` for the locked
  Attempt before `finalizeByStudentSubmit()`;
- the delivered `StudentHomeworkAnswerIntegrity` path is reused solely as an
  integrity gate, with no second Submit-specific validator;
- no completeness requirement, fabricated/scored/checked Answer, Answer/File
  mutation, or Question/Answer/File row lock is introduced;
- the own Attempt `FOR UPDATE` remains the Student answer/file mutation barrier;
- corrupt saved non-file/file Answers cause safe `500 server_error`, transaction
  rollback, unchanged `in_progress` Attempt, zero completed/incomplete new Submit
  records, and unchanged Answers/Files;
- both fixed-key `K` regressions prove `500`, retry `500`, fixture-only repair,
  `200 student_submit` with exactly one completed record, then replay `200` on the
  same record without timestamp churn;
- only a successful integrity gate permits finalization -> idempotency completion
  -> commit; pre-existing saved Answer corruption is caught before commit.

## Idempotency

- operation exactly `student.homework.attempt.submit`;
- same key/same Attempt preserves durable success and returns `200` when the
  current Student-safe representation can be produced;
- original response status is 200;
- different Attempt with same scoped key conflicts;
- Start/Submit operation keys remain independent;
- success transition + idempotency completion are atomic;
- rejected new Submit leaves no persisted incomplete/success record;
- corruption introduced after historical success may cause safe `500 server_error`
  during projection, but never deletes/rewrites the completed record or its
  timestamps and never mutates the Attempt/Answers/Files.

## Lifecycle/deadline

- completed same-key replay survives later lifecycle changes;
- new Submit uses BE-005/006-consistent precedence: Homework lifecycle first,
  active-Topic consistency second;
- exact `submittedAt >= deadline` gives deadline precedence for an otherwise
  active Homework;
- late Submit abandons its claim/releases its local transaction before public
  BE-002 deadline reconciliation;
- deadline reconciliation commits before `409 deadline_passed`;
- new key on a structurally valid terminal Attempt gives `attempt_not_editable`;
- the complete Section 15 structural invariant is preserved; corrupt
  `in_progress` finalization fields are server invariant failure, not
  `attempt_not_editable`.

## Concurrency

- same-key concurrent Submit yields one transition/one record/two 200 outcomes;
- different-key concurrent Submit yields one success and one non-editable failure;
- different Students/different Attempts on the same Homework are not serialized
  by exclusive aggregate/all-Attempt locks;
- Submit serializes against non-file answer and file replacement writes through
  the own Attempt lock;
- real PostgreSQL Submit-vs-Teacher-close race proves both valid orders;
- real PostgreSQL Submit-vs-deadline race proves both valid orders;
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

- exact Pint command passes;
- exact focused/named regression command passes;
- no uncontracted broad suite/static tool is run;
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
same-key replay bypasses later lifecycle and the new-Submit integrity gate
HTTP replay 200 requires a producible current Student-safe representation
BE-007 guarantee = durable Submit/idempotency replay semantics
later Attempt terminal status replay fixtures = Answers remain valid Stage-7 pending
genuine Stage-9 checked-answer projection = not implemented or validated by BE-007
Stage 9 = extend Student-safe read/integrity projection, preserve completed Submit record/replay
Stage-7 Answer integrity = pending; awarded_points/feedback/checked_by_user_id/checked_at null
later corruption/projection 500 = historical completed record unchanged
different-key structurally valid already-submitted = attempt_not_editable
deadline comparison = submittedAt >= homework deadline
deadline at equality = deadline wins
submittedAt captured after own-Attempt lock/idempotency waits
Submit parent locks = shared/read
Submit own route Attempt lock = FOR UPDATE
Submit does not lock other Students' Attempts
late Submit deadline reconciliation = public BE-002 action after local transaction
Homework lifecycle precedence = closed/archived/draft first; active Topic consistency second
locked attempt.id = preliminary authorized Attempt
locked attempt.institution_id = authenticated Student Institution
locked attempt.student_id = authenticated Student
locked attempt.assessment_id = locked Homework Assessment
locked attempt.assessment_student_id = authoritative persisted AssessmentStudent
locked attempt.deadline_at = null
Homework Attempt statuses = in_progress/submitted/waiting_for_teacher_review/checked
Homework finalization_reason != timeout_auto_submit
timed_out_finalized / timeout_auto_submit = Blitz-only
in_progress submitted_at/finalized_at/locked_at/finalization_reason = all null
structurally valid terminal = attempt_not_editable for new key
structurally valid in_progress = may Submit after shared persisted-answer integrity gate
structural corruption/post-authorization drift or disappearance = LogicException / safe 500 server_error
structural corruption = zero Submit mutation; no Submit idempotency completion
new Submit gate = read-only Questions in position/ID order -> StudentHomeworkAttemptAnswerStates
shared integrity implementation = delivered StudentHomeworkAnswerIntegrity; no second validator
gate order = lifecycle/deadline/Attempt validation -> gate -> finalizeByStudentSubmit -> complete -> commit
Question/Answer/File row locks = none; own Attempt FOR UPDATE remains mutation barrier
non-file/file Answer corruption = rollback; Attempt in_progress; no new Submit record; Answers/Files unchanged
fixed-key regressions = 500 -> 500 -> fixture-only repair -> 200/one completed record -> replay 200/no churn
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
- exclusive shared-parent locks or all-Attempt locking for ordinary Submit;
- inline all-Attempt deadline reconciliation inside the Submit transaction;
- mapping corrupt `in_progress` finalization fields to normal non-editable;
- mapping post-authorization disappearance/identity drift to ordinary `404`;
- treating disallowed Homework Attempt status/reason or non-null Attempt deadline as ordinary non-editable;
- finalizing/completing idempotency before the shared persisted-answer integrity gate;
- a Submit-specific Answer validator or Answer/File `FOR UPDATE`;
- relaxing Stage-7 integrity to accept checked/scored Answers or claiming genuine Stage-9 endpoint replay proof;
- deleting/rewriting a historical completed record because later projection fails;
- pair/result mutation;
- submit-and-start-next behavior.

---

# 45. Implementation Execution, Delivery, and Completion Report

Implementation remains unauthorized until the Readiness Gate is PASS. Once
authorized, after **all** BE-007 implementation verification in Section 42 and
the focused scope/diff self-review pass, Codex must complete GitHub delivery in
the same execution. Do not stop before PR creation or wait for another delivery
instruction.

Suggested implementation branch:

```text
implement/s07-be-007-idempotent-final-homework-submit
```

Required delivery sequence:

1. stage only BE-007 task scope, preserving unrelated user work;
2. run `git diff --cached --check` and require PASS;
3. commit with the exact message:

   ```text
   feat(stage7): add idempotent homework submit
   ```

4. push the implementation branch;
5. create a PR against `main`;
6. do not merge; Project Owner merges only after ChatGPT acceptance;
7. do not update `STAGE_07_TASK_INDEX.md` or other task/Stage bookkeeping.

Report completion only after the required PR exists. If implementation is
complete but assigned delivery cannot complete safely, report `DELIVERY BLOCKED`
with the exact blocker and current Git/delivery state.

Use one status:

```text
IMPLEMENTATION COMPLETE
```

or:

```text
BLOCKED
```

or, only when implementation passed but assigned delivery cannot complete:

```text
DELIVERY BLOCKED
```

with:

1. implementation summary;
2. changed files and purpose;
3. exact focused verification results;
4. explicit finalization field evidence;
5. unanswered-answer preservation evidence;
6. idempotency evidence;
7. deadline/Teacher-close race evidence;
8. PostgreSQL Submit/answer/file/cross-Student concurrency evidence;
9. directly affected regressions;
10. `git diff --check`;
11. scope/non-goal confirmation;
12. deviations/blockers;
13. `git diff --cached --check` result before commit;
14. commit SHA;
15. implementation branch;
16. PR number and URL against `main`;
17. final `git status --short`.

Do not claim `Accepted`.

Codex is explicitly authorized and required to commit/push/create the PR after
all task verification passes. Project Owner owns merge only after ChatGPT
acceptance; Codex must not merge or update Stage bookkeeping.
