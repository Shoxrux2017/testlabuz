# Codex Implementation Contract: S08-BE-009 — Student-Specific Blitz Attempt Exception

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-BE-009` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel Teacher-granted one-Student Blitz exception + replacement Attempt #2 Start/Resume integration` |
| Depends on | `S08-DOC-001`, `S08-BE-001…008` — all `Accepted / Delivered` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` after dependencies are delivered and immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |
| Backend block checkpoint | `Stage 8 Backend Phase 2` after `S08-BE-001…010` are `Accepted / Delivered` |
| Blocks | `S08-BE-010` |

Start only when:

```text
S08-DOC-001 = Accepted / Delivered
S08-BE-001…008 = Accepted / Delivered
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
4. delivered S08-BE-001…008 source/tests directly required here;
5. current Teacher Blitz access/lifecycle/idempotency patterns;
6. current Student Blitz Start/Resume/read/timing/idempotency code;
7. current `blitz_attempt_exceptions` model/factory/schema delivered by BE-001;
8. current Blitz timeout/finalization support delivered by BE-007.

Do **not** read:

- `docs/01–09`;
- roadmap files;
- Stage indexes;
- `S08-DOC-001`;
- previous task files;
- closure reviews;
- frontend code

to discover requirements.

This contract resolves:

- exact grant endpoint;
- exact request/header contract;
- authorized Student target;
- valid reason contract;
- normal Attempt #1 precondition;
- handling of a still-in-progress #1;
- original Attempt invalidation semantics;
- durable exception idempotency;
- exactly one exception;
- no Attempt #2 at grant;
- Student Attempt #2 Start/Resume rules;
- synchronized replacement timing;
- individual replacement timing;
- Student read/Attempt availability projection;
- exception row linking;
- official-score eligibility flags;
- concurrency/lock ordering;
- errors;
- acceptance criteria;
- focused tests/verification.

If delivered dependencies materially conflict with this contract, return:

```text
BLOCKED
```

with exact evidence.

Do not invent another retry mechanism or class-wide attempt-limit change.

---

# 3. Goal

Implement the single approved MVP exception to the fixed Blitz attempt policy.

Normal policy remains:

```text
exactly 1 normal Blitz Attempt
```

For a valid Student-specific technical/other approved problem, an authorized Teacher may grant:

```text
exactly 1 additional replacement Attempt
```

to exactly one assigned Student.

The grant must:

- preserve normal Attempt #1 in history;
- mark #1 excluded from official Blitz scoring;
- create one durable exception record;
- record mandatory reason and Teacher;
- **not** create Attempt #2 immediately.

Later, the same Student Start endpoint may create/resume:

```text
Attempt #2
```

only through that approved exception.

No Blitz Attempt #3 is allowed.

---

# 4. Included Public Endpoint

Add exactly:

```text
POST /api/v1/teacher/blitz/{blitz}/students/{student}/attempt-exception
```

inside the existing Teacher middleware group:

```text
auth:sanctum
active.account
password.changed
role:teacher
```

Required header:

```http
Idempotency-Key: <uuid>
```

Request body defined below.

Do not add:

- exception DELETE;
- revoke exception;
- class-wide retry endpoint;
- Student self-grant endpoint;
- direct “create Attempt #2” Teacher endpoint.

---

# 5. Existing Student Start Endpoint Is Extended

Do not create a replacement-specific Student route.

Continue using exactly:

```text
POST /api/v1/student/blitz/{blitz}/attempts
```

BE-005 already made Student execution intent explicit. BE-009 preserves those
semantics and extends the accepted request intent set by exactly one value.

Final Stage 8 intents are:

```text
start_normal
resume
start_replacement
```

The server must never choose between normal Start, Resume, and replacement Start
based only on current state.

Current state validates the submitted intent; it does not rewrite that intent
into another operation.

## 5.1 Final Student Start request bodies

### Normal Start

```json
{
  "intent": "start_normal"
}
```

### Resume exact Attempt

```json
{
  "intent": "resume",
  "attempt_id": "attempt-uuid"
}
```

### Confirmed replacement Start

```json
{
  "intent": "start_replacement"
}
```

Strict rules:

- `attempt_id` is required only for `resume`;
- `attempt_id` is forbidden for both Start intents;
- empty/`{}` body is invalid;
- unknown intents/keys are invalid;
- malformed UUID is `422 validation_failed`.

The existing endpoint may therefore:

- create/return normal #1 only for `start_normal`;
- return one exact existing Attempt only for `resume`;
- create/return replacement #2 only for `start_replacement`.

---

# 6. Explicit Non-Goals

Do not implement:

- more than one exception per Student/Blitz;
- more than Attempt #2;
- exception revoke/edit;
- retroactive deletion of Attempt #1;
- rewriting Student answers/files;
- checking/scoring;
- official score calculation;
- Topic result calculation;
- Teacher monitoring UI/API beyond fields directly required by existing Student projections;
- frontend;
- E2E harness/seed data;
- migration/schema changes;
- dependencies;
- docs/tasks.

Do not create:

```text
attempt_limit = 2
normal_attempts = 2
class_retry_count
```

The fixed class-wide normal limit remains **1**.

---

# 7. Delivered Persistence to Reuse

Reuse exactly:

```text
blitz_attempt_exceptions
```

with delivered fields:

```text
id
institution_id
assessment_id
assessment_student_id
student_id
invalidated_attempt_id
replacement_attempt_id nullable
reason_type
reason
granted_by_user_id
granted_at
created_at
updated_at
```

Reuse delivered uniqueness:

```text
unique(assessment_id, student_id)
unique(invalidated_attempt_id)
unique(replacement_attempt_id) where non-null / PostgreSQL nullable unique semantics
```

Do not alter schema.

---

# 8. Reason Types

Reuse delivered enum:

```text
BlitzAttemptExceptionReasonType
```

with exactly:

```text
technical
other_valid
```

No additional reason type.

The Teacher's selected reason type is authoritative classification for MVP.

The backend does not use AI or free-text inference to decide whether the reason “sounds valid”.

---

# 9. Grant Request Contract

Request must be:

```text
Content-Type: application/json
one JSON object
no query parameters
```

Accepted exact keys:

```text
reason_type
reason
```

No other field.

Example:

```json
{
  "reason_type": "technical",
  "reason": "The Student's device lost connection during the normal attempt."
}
```

---

# 10. Grant Field Validation

## `reason_type`

Required:

```text
string
technical | other_valid
```

## `reason`

Required:

```text
string
trimmed before semantic validation/persistence
non-empty after trim
max 4000 Unicode characters
```

The 4000-character API cap is a Stage 8 request-safety limit; persistence remains `text`.

Do not accept an empty/whitespace-only reason.

Persist the trimmed reason.

Unknown/protected keys:

```text
422 validation_failed
```

Do not accept:

```text
student_id
assessment_id
invalidated_attempt_id
replacement_attempt_id
granted_by_user_id
granted_at
official_score_eligible
attempt_number
```

from the client.

---

# 11. Grant Idempotency Operation

Extend:

```text
IdempotencyOperation
```

with exactly:

```text
TeacherBlitzAttemptExceptionGrant
=
'teacher.blitz.attempt_exception.grant'
```

Do not use the activation operation.

Do not add another exception-grant operation later for the same endpoint.

---

# 12. Grant Fingerprint

After privacy-safe resolution of the authorized Blitz and assigned Student:

```text
operation = teacher.blitz.attempt_exception.grant

route identity = {
  "blitz_id": lowercase Blitz Assessment UUID,
  "student_id": lowercase Student UUID
}

body identity = {
  "reason_type": canonical enum value,
  "reason": trimmed persisted reason
}
```

Use:

```text
IdempotencyRequestFingerprint
```

Do not include:

- Attempt #1 ID;
- current lifecycle;
- current time;
- current exception row ID

in the request fingerprint.

Those are authoritative server state.

---

# 13. Teacher / Blitz Authorization

Resolve `{blitz}` through the delivered Teacher Blitz access boundary.

Require:

```text
same Institution
Assessment.type = blitz
teacher_id = authenticated Teacher
owning Topic visible to Teacher
current Teacher–Group membership exists
BlitzTask exists
```

Malformed/private/foreign/no-current-membership:

```text
404 resource_not_found
```

Do not leak existence.

---

# 14. Student Target Authorization

`{student}` must be resolved **inside the already-authorized Blitz assignment snapshot**, not through an arbitrary Institution Student lookup alone.

Require:

```text
valid Student UUID
same Institution User
role = student
is_active = true
AssessmentStudent exists for this exact Blitz
AssessmentStudent.student_id = Student
same Institution
```

Current Group Student membership is **not** required.

Reason:

> Blitz assignment/cohort was frozen at activation; later Group membership changes must not rewrite who was assigned.

Malformed UUID, foreign Student, another Blitz recipient, unassigned Student, wrong role, inactive Student:

```text
404 resource_not_found
```

Do not reveal which condition failed.

The Teacher must still have current Teacher–Group authorization for the Blitz itself.

---

# 15. Grant Lifecycle

A new exception may be granted only while:

```text
BlitzTask.status = active
```

For:

```text
draft
scheduled
closed
archived
```

return:

```text
409 blitz_attempt_exception_not_allowed
```

Do not reopen a Blitz.

Do not grant an exception after Teacher Close.

A synchronized class-wide common end may already be in the past while the Blitz remains `active`; this alone does **not** block a grant.

That is intentional because a valid Student-specific replacement receives its own compensating full-duration window.

---

# 16. Normal Attempt #1 Is Required

The assigned Student must already have exactly one normal Blitz Attempt:

```text
attempt_number = 1
```

If none exists:

```text
409 blitz_normal_attempt_required
```

Do not create Attempt #1 as part of exception grant.

If persisted history contains no #1 but contains #2/#3:

```text
LogicException
```

Do not repair.

---

# 17. Attempt #1 Ownership / Structure

Under lock require Attempt #1:

```text
institution_id = Teacher/Blitz Institution
assessment_id = Blitz Assessment
assessment_student_id = target recipient
student_id = target Student
attempt_number = 1
deadline_at non-null
```

The Attempt may be:

```text
submitted
timed_out_finalized
waiting_for_teacher_review
checked
```

subject to valid finalization structure.

At Stage 8 delivery, normal terminal states expected are primarily:

```text
submitted + student_submit
timed_out_finalized + timeout_auto_submit
```

A future checked/review state must not make the historical exception graph invalid.

---

# 18. Live In-Progress Attempt #1 Rule

A still-editable pre-deadline normal Attempt cannot be invalidated by grant.

Reason:

- Stage 8 persistence has no fake `exception_invalidated` finalization reason;
- the platform must not invent `timeout_auto_submit` before the deadline;
- it must not invent `task_closed_auto_finalize` while the task is still active;
- Attempt #2 cannot coexist with another `in_progress` Attempt for the same Student/Assessment.

Therefore:

## #1 in progress and deadline not reached

Return:

```text
409 blitz_attempt_exception_not_allowed
```

No exception record.

No eligibility mutation.

## #1 in progress and deadline reached

The grant transaction may use the delivered authoritative:

```text
BlitzAttemptFinalizer::finalizeAtTimeout(...)
```

on the locked #1 because:

```text
server_now >= attempt.deadline_at
```

Then #1 becomes:

```text
timed_out_finalized
timeout_auto_submit
finalized_at = locked_at = exact deadline_at
submitted_at = null
```

and the grant may continue atomically.

Do not duplicate timeout transition code.

---

# 19. Valid Reason Is Not “Try Again for a Better Score”

The exception is for:

```text
technical
other valid interruption/fairness problem
```

It is not a normal score-improvement retry.

MVP enforcement is:

- authorized Teacher;
- required reason type;
- required reason text;
- exactly one exception;
- historical #1 invalidation.

The backend does not inspect a score to decide whether the Teacher's reason is legitimate.

Stage 9 score existence is not a prerequisite.

---

# 20. Existing Exception Precedence

Lock existing:

```text
blitz_attempt_exceptions
```

for the exact:

```text
assessment_id + student_id
```

before creating a new exception.

## Same completed Idempotency-Key

Replay returns the existing exception success before “already granted” conflict.

## Different/new key and exception already exists

Return:

```text
409 blitz_attempt_exception_already_granted
```

Do not mutate the existing exception.

Do not create another record.

Do not update its reason.

---

# 21. Original Attempt Eligibility Mutation

Before grant, require:

```text
Attempt #1.official_score_eligible = true
```

If it is already false without the corresponding locked exception row:

```text
LogicException
```

Do not silently create an explanation for unknown historical invalidation.

On successful grant set exactly:

```text
Attempt #1.official_score_eligible = false
```

Do not alter:

```text
status
started_at
deadline_at
submitted_at
finalized_at
finalization_reason
locked_at
possible_points
answers
files
```

except the due in-progress timeout transition allowed by Section 18.

---

# 22. Grant Does Not Create Attempt #2

This is mandatory.

Successful grant creates only:

```text
BlitzAttemptException
```

and changes:

```text
Attempt #1.official_score_eligible = false
```

Persist:

```text
replacement_attempt_id = null
```

Attempt #2 is created only when the Student later explicitly uses the normal Start endpoint.

This preserves:

- actual Student initiation time;
- accurate replacement deadline;
- idempotent Start semantics;
- no fabricated Attempt for an unused exception.

---

# 23. Exception Persistence

Create exactly one row:

```text
id = server UUID
institution_id = Teacher Institution
assessment_id = Blitz Assessment
assessment_student_id = target recipient ID
student_id = target Student ID
invalidated_attempt_id = Attempt #1 ID
replacement_attempt_id = null
reason_type = request
reason = trimmed request reason
granted_by_user_id = authenticated Teacher ID
granted_at = grantedAt
created_at = grantedAt
updated_at = grantedAt
```

Capture one:

```text
grantedAt = server_now
```

after required lock waits and final eligibility checks.

---

# 24. Grant Idempotency Completion

Complete the new claim with:

```text
result_resource_type = blitz_attempt_exception
result_resource_id = exception.id
response_status = 201
```

Grant domain writes and idempotency completion commit atomically.

If completion fails:

- exception row rolls back;
- #1 eligibility mutation rolls back;
- any same-transaction timeout transition rolls back;
- claim rolls back.

Retry may safely execute.

---

# 25. Grant Replay Validation

Completed replay must reference:

```text
same Institution
same Blitz Assessment
same Student
same target recipient
same invalidated Attempt #1
```

and exact:

```text
result_resource_type = blitz_attempt_exception
response_status = 201
```

The referenced exception must still exist.

Corrupt replay metadata:

```text
LogicException
```

Do not create a replacement exception.

---

# 26. Grant Response Resource

Create:

```text
TeacherBlitzAttemptExceptionResource
```

or equivalent.

Exact public data:

```json
{
  "data": {
    "id": "exception-uuid",
    "blitz_id": "blitz-uuid",
    "student_id": "student-uuid",
    "invalidated_attempt_id": "attempt-1-uuid",
    "replacement_attempt_id": null,
    "reason_type": "technical",
    "reason": "The Student's device lost connection during the normal attempt.",
    "granted_at": "2026-09-14T19:00:00Z",
    "replacement_attempt_available": true
  },
  "message": "One additional Blitz attempt has been granted."
}
```

Do not expose:

```text
institution_id
assessment_student_id
granted_by_user_id
created_at
updated_at
```

through this endpoint.

---

# 27. `replacement_attempt_available`

This field is a **current availability projection**, not proof that the exception
was just created and not a generic monitoring-only invariant.

Use this exact truth table for the Teacher exception resource.

## 27.1 Granted, unused, Blitz still active

```text
replacement_attempt_id = null
Blitz.status = active
replacement_attempt_available = true
```

The Student may still explicitly start replacement #2 subject to the normal
Student Start authorization/state checks.

## 27.2 Granted, unused, Blitz later closed/archived

A completed grant remains historical even when the replacement can no longer be
started:

```text
replacement_attempt_id = null
Blitz.status = closed|archived
replacement_attempt_available = false
```

This shape is required for completed same-key grant replay after later lifecycle
change.

Do not fabricate Attempt #2 merely to avoid the `null + false` combination.

## 27.3 Replacement #2 already exists

For any valid current lifecycle where the exception already links #2:

```text
replacement_attempt_id = Attempt #2 UUID
replacement_attempt_available = false
```

This remains false whether #2 is in-progress or terminal.

## 27.4 Invalid combinations

Never serialize:

```text
replacement_attempt_id != null
replacement_attempt_available = true
```

An existing exception under impossible regressed Blitz lifecycle such as
`draft|scheduled` is structural corruption, not a valid historical projection.

The completed idempotency response status remains:

```text
201
```

Do not pretend another exception was created.

---

# 28. Stable Exception Errors

Add exact API error mappings:

## `blitz_attempt_exception_not_allowed`

```text
HTTP 409
message = A Blitz attempt exception cannot be granted in the current state.
```

## `blitz_attempt_exception_already_granted`

```text
HTTP 409
message = An additional Blitz attempt has already been granted to this Student.
```

## `blitz_normal_attempt_required`

```text
HTTP 409
message = The Student must have a normal Blitz attempt before an exception can be granted.
```

Do not add another synonymous code.

`result_closed` is not required by Stage 8 exception execution because Stage 8 has no separate closed-result aggregate; a non-active Blitz is handled by:

```text
blitz_attempt_exception_not_allowed
```

---

# 29. Grant Lock Order

Use deterministic parent-first order compatible with activation/close/Start:

```text
1. Group
2. current Teacher–Group membership
3. Topic
4. Assessment
5. BlitzTask
6. target AssessmentStudent recipient
7. target Student User
8. Idempotency record
9. target Student AssessmentAttempts ordered by attempt_number,id
10. existing BlitzAttemptException row
```

If delivered access helpers establish recipient/User ordering differently, preserve one consistent order across Teacher monitoring/exception later.

Do not lock all Institution Students.

---

# 30. Grant vs Timeout / Scheduler Race

Because grant locks the same Attempt #1:

## Timeout finalizer wins first

Grant later sees terminal timeout #1 and may proceed.

## Grant locks #1 after deadline first

Grant uses the same `BlitzAttemptFinalizer` timeout transition and may proceed atomically.

## Grant sees #1 before deadline still in progress

Grant rejects.

No fake early timeout.

No two terminal transitions.

---

# 31. Grant vs Teacher Close Race

Both lock parent Blitz/Attempt state.

## Close commits first

Grant re-reads non-active Blitz:

```text
blitz_attempt_exception_not_allowed
```

No exception.

## Grant commits first

Exception exists.

Teacher Close may later close the Blitz.

If replacement has not started:

- no Attempt #2 is fabricated;
- exception remains historical unused.

If replacement is in progress:

- Teacher Close finalizes #2 using BE-007 normal per-Attempt rule.

---

# 32. Grant vs Concurrent Grant — Same Key

Two same-key concurrent grant requests:

- one exception row;
- one #1 eligibility mutation;
- one completed idempotency record;
- both logical outcomes `201`;
- same exception ID.

No duplicate exception.

---

# 33. Grant vs Concurrent Grant — Different Keys

Two different keys race for same Student/Blitz.

Required:

- exactly one exception succeeds;
- one completed successful idempotency record;
- loser returns:
  ```text
  blitz_attempt_exception_already_granted
  ```
- losing key leaves no incomplete/successful record.

DB uniqueness remains a backstop, not the sole business algorithm.

---

# 34. Student Start History After Exception

Extend the delivered Student Blitz Attempt history validator.

Valid histories become:

## No Attempt

```text
[]
```

## Normal in progress

```text
[#1 in_progress]
no exception
```

## Normal terminal, no exception

```text
[#1 terminal]
no replacement capacity
```

## Normal terminal, granted replacement not yet started

```text
[#1 terminal, official_score_eligible = false]
exception.invalidated_attempt_id = #1
exception.replacement_attempt_id = null
```

## Replacement in progress

```text
[#1 terminal, ineligible]
[#2 in_progress, eligible]
exception.invalidated_attempt_id = #1
exception.replacement_attempt_id = #2
```

## Replacement terminal

```text
[#1 terminal, ineligible]
[#2 terminal, eligible]
exception links #1 -> #2
```

No other history is valid.

---

# 35. Attempt Number Rules

Blitz runtime now permits exactly:

```text
Attempt #1 = normal
Attempt #2 = replacement only through exception
```

Never:

```text
Attempt #3
```

Never:

```text
Attempt #2 without exception
```

Never:

```text
exception invalidated_attempt_id != #1
```

Never:

```text
replacement_attempt_id points to #1
```

Structural violation:

```text
LogicException
```

Do not “repair” numbering.

---

# 36. Replacement Start Preconditions

A new Attempt #2 may be created only for:

```text
intent = start_replacement
```

and only when all are true:

```text
BlitzTask.status = active
Topic status = active
own recipient remains valid
Attempt #1 exists and is terminal
Attempt #1.official_score_eligible = false
one exception exists
exception.invalidated_attempt_id = Attempt #1
exception.assessment_student_id = own recipient
exception.student_id = Student
exception.replacement_attempt_id = null
no Attempt #2 exists
```

Neither `start_normal` nor `resume` may enter this creation branch, even when the
same locked state would otherwise make replacement capacity available.

If no exception:

```text
409 attempts_exhausted
```

If exception structure exists but is invalid:

```text
409 blitz_attempt_exception_not_allowed
```

or `LogicException` for impossible persisted graph according to the delivered invariant/public-error split.

No replacement Start when Blitz is closed/archived.

---

# 37. Replacement Start Intent and Idempotency Identity

The existing operation remains:

```text
student.blitz.attempt.start
```

The public route remains the same.

BE-005 fingerprinting already includes the semantic request body.

For replacement creation the body identity is exactly:

```text
{
  "intent": "start_replacement"
}
```

A previously completed key for:

```text
start_normal
```

or:

```text
resume + attempt_id
```

remains forever tied to that original logical request.

If the same key is reused with `start_replacement`, the fingerprint differs:

```text
409 idempotency_key_reused
```

If the Student replays the old #1 key with its original body:

- replay the original #1 logical result;
- do **not** create #2.

To start #2, the client must send:

```text
new valid Idempotency-Key
+
intent = start_replacement
```

A replacement key replay uses the same `start_replacement` body and returns the
same logical #2 result.

This preserves one idempotency operation while preventing cross-intent
reinterpretation.

---

# 38. Replacement Start Decision Instant

After all required parent/recipient/Attempt/exception/idempotency lock waits,
apply the same Stage 8 timer precision owned by BE-005:

```text
replacementStartedAt = truncate_to_utc_second(server_now)
```

Never round upward.

Use exactly this canonical whole-second server instant as:

```text
Attempt #2.started_at
```

Do not reuse:

- Attempt #1 start;
- Attempt #1 deadline;
- Teacher grant time;
- Blitz activation time;
- synchronized class end;
- device time.

---

# 39. Replacement Timing — Both Timer Modes

The approved Student-specific exception is compensating.

Attempt #2 receives the full configured whole-Blitz duration in **both** timer
modes measured in the approved whole-second timer domain.

Persist:

```text
deadline_at
=
replacementStartedAt + blitz_tasks.duration_seconds
```

This applies when activation snapshot is:

```text
synchronized
individual
```

---

# 40. Synchronized Replacement Is a Narrow Exception Path

For a synchronized Blitz:

```text
blitz_tasks.synchronized_ends_at
```

remains the historical class-wide normal-attempt end.

Attempt #2:

```text
does not change synchronized_ends_at
does not change timer_start_mode_snapshot
does not restart the class timer
does not grant time to any other Student
```

Its own:

```text
assessment_attempts.deadline_at
```

may be later than the class common end.

This is intentional.

BE-007 already finalizes each Attempt from persisted `deadline_at`.

---

# 41. Replacement May Start After Common Synchronized End

If:

```text
timer mode = synchronized
server_now >= synchronized_ends_at
```

normal Attempt #1 is not startable.

But an assigned Student with a valid unused exception may start replacement Attempt #2 while:

```text
BlitzTask.status = active
Topic.status = active
```

The common class end does not block the replacement.

The replacement receives:

```text
full duration from replacementStartedAt
```

Teacher Close still blocks all future starts.

---

# 42. Replacement Attempt #2 Persistence

Create:

```text
institution_id = Student Institution
assessment_id = Blitz Assessment
assessment_student_id = own recipient ID
student_id = authenticated Student
attempt_number = 2
status = in_progress
started_at = replacementStartedAt
deadline_at = replacementStartedAt + duration_seconds
submitted_at = null
finalized_at = null
finalization_reason = null
locked_at = null
official_score_eligible = true
earned_points = null
possible_points = current Assessment total_possible_points
normalized_score = null
scoring_completed_at = null
```

Do not copy answers/files from Attempt #1.

Replacement starts clean.

Do not create empty answer rows.

---

# 43. Link Exception to Attempt #2 Atomically

In the same transaction as Attempt #2 creation:

```text
exception.replacement_attempt_id = Attempt #2 ID
exception.updated_at = replacementStartedAt
```

Do not change:

```text
reason_type
reason
granted_by_user_id
granted_at
invalidated_attempt_id
```

If exception update cannot commit:

- Attempt #2 creation rolls back;
- Start idempotency completion rolls back.

No unlinked #2.

---

# 44. Replacement Start Idempotency Completion

For a new #2 Start:

```text
result_resource_type = assessment_attempt
result_resource_id = Attempt #2
response_status = 201
```

Same existing `student.blitz.attempt.start` operation.

No new “replacement-start” idempotency operation.

---

# 45. Replacement Resume

When #2 exists and remains:

```text
in_progress
server_now < #2.deadline_at
Blitz active
```

the normal UI continuation path sends:

```json
{
  "intent": "resume",
  "attempt_id": "#2-uuid"
}
```

A new Resume key returns:

```text
200
that exact Attempt #2
```

Resume must not:

- create #3;
- create #2;
- switch to #1;
- change #2 started_at;
- change #2 deadline_at;
- change exception row.

A concurrent/double confirmed:

```text
intent = start_replacement
```

that serialized after #2 was already created may safely return the existing
in-progress #2 with `200`, because it remains the same replacement-start path and
does not create #3.

Same-key replay returns its original intent-specific logical result as usual.

---

# 46. Replacement Timeout

When #2 is:

```text
in_progress
server_now >= #2.deadline_at
```

reuse BE-007:

```text
FinalizeTimedOutBlitzAttempts
```

Then new Start returns:

```text
409 blitz_time_expired
```

No #3.

Exception remains linked to terminal #2.

---

# 47. Replacement Submit

BE-008 Submit is Attempt-ID based and must work unchanged for valid #2.

Do not add special replacement Submit code.

A valid in-progress #2 before deadline:

```text
student_submit
```

A late #2 Submit:

```text
BE-007 timeout reconciliation
+
blitz_time_expired
```

Original #1 remains ineligible.

---

# 48. Replacement Answer/File Mutation

BE-006 is Attempt-ID based and must work unchanged for valid in-progress #2.

Do not add separate replacement answer routes.

Answers/files belong only to #2.

No copying/mixing with #1.

---

# 49. Student Active List After Exception

Extend the BE-005/007 active-list eligibility.

The Blitz is eligible for this Student when one of these is true:

## Normal Attempt not yet used

```text
no #1
normal timer permits Start
```

## Normal Attempt #1 in progress

```text
#1 before its deadline
```

## Replacement available

```text
#1 terminal
exception exists
replacement_attempt_id = null
Blitz active
```

This remains eligible even when synchronized common end is already passed.

## Replacement #2 in progress

```text
#2 before its own deadline
```

No eligibility after #2 becomes terminal.

---

# 50. Student Detail Attempt Projection

Extend the existing attempt summary:

```json
{
  "attempts": {
    "normal_attempts": 1,
    "normal_used": 1,
    "in_progress_attempt_id": null,
    "additional_exception_granted": true,
    "replacement_attempt_available": true
  }
}
```

Rules:

```text
additional_exception_granted
=
exception exists
```

```text
replacement_attempt_available
=
exception exists
AND replacement_attempt_id is null
AND #1 is terminal
AND Blitz active
```

When #2 is in progress:

```text
in_progress_attempt_id = #2.id
replacement_attempt_available = false
```

When #2 terminal:

```text
in_progress_attempt_id = null
replacement_attempt_available = false
```

## 50.1 Coherent Student GET Read Boundary

BE-009 extends both delivered Student read paths with exception/replacement state:

```text
GET /api/v1/student/blitz/active
GET /api/v1/student/blitz/{blitz}
```

Those responses must never combine Attempt history from one committed database
state with BlitzAttemptException state from another.

Use one common final-read protocol for both paths:

```text
preliminary privacy-safe Student/recipient resolution
↓
BE-007 due-timeout reconciliation where applicable
↓
open one PostgreSQL REPEATABLE READ READ ONLY final-read transaction
↓
first SQL statement establishes the MVCC snapshot and captures snapshotAt
↓
re-resolve final lifecycle/recipient state inside that snapshot
↓
load own Attempt #1/#2 history inside that snapshot
↓
load own BlitzAttemptException inside that snapshot
↓
validate complete graph
↓
derive eligibility/timing/attempt summary from that one graph
```

Anything loaded before the final read-only transaction is preliminary only and
must not contribute directly to the returned projection.

### 50.1.1 Snapshot clock and isolation

The final read transaction must use exactly:

```text
PostgreSQL
ISOLATION LEVEL REPEATABLE READ
READ ONLY
```

on one connection.

Its first SQL statement must establish the MVCC snapshot and capture one
authoritative Stage 8 instant equivalent to:

```sql
SELECT date_trunc('second', clock_timestamp()) AS snapshot_at
```

Requirements:

```text
snapshotAt = UTC whole-second instant
truncate/floor only; never round upward
all final graph SELECTs use the same connection/transaction/snapshot
all final timing/eligibility math uses this one snapshotAt
```

Serialize:

```text
YYYY-MM-DDTHH:MM:SSZ
```

and derive:

```text
remaining_seconds
=
max(0, deadline_epoch_second - snapshotAt_epoch_second)
```

Do not capture another application/server clock for the same final projection.

### 50.1.2 Active-list protocol

Preserve BE-007 read reconciliation before the final list:

1. identify own assigned active Blitz aggregates whose own in-progress Attempt may
   already be due;
2. invoke `FinalizeTimedOutBlitzAttempts` for each distinct candidate Assessment;
3. do not return/project from that preliminary scan;
4. open one final RR read-only transaction for the **whole active-list response**;
5. inside that snapshot load, in bounded queries:
   ```text
   active Blitz/Assessment parent rows
   own persisted recipient rows as required
   own Attempt #1/#2 rows
   own BlitzAttemptException rows
   ```
6. compute every returned row's eligibility from that same snapshot and
   `snapshotAt`.

Do not open one transaction per row.

Do not perform one Exception query per Blitz.

No N+1 is allowed.

### 50.1.3 Detail protocol

For detail:

1. perform only enough preliminary privacy-safe own recipient/Blitz resolution to
   decide whether BE-007 reconciliation may be relevant;
2. reconcile due own work through the shared BE-007 aggregate reconciler;
3. discard preliminary models for projection;
4. open the final RR read-only transaction;
5. re-resolve inside that same snapshot:
   ```text
   Assessment
   BlitzTask
   own AssessmentStudent recipient
   own Attempt #1/#2 history
   own BlitzAttemptException
   ```
6. validate and project only after the full snapshot graph is loaded.

No resource/lazy relationship query may escape the final transaction and still
contribute to the response.

### 50.1.4 Deadline crossing between reconciliation and snapshot

A deadline may legitimately be crossed after preliminary reconciliation but
before `snapshotAt`.

If the final snapshot contains any own:

```text
status = in_progress
AND deadline_at <= snapshotAt
```

that is a normal stabilization race, not corruption.

Required:

1. do not return that snapshot;
2. end/discard the read-only transaction;
3. invoke `FinalizeTimedOutBlitzAttempts` for every distinct affected Assessment;
4. establish a new final RR read-only snapshot;
5. rebuild from the new snapshot.

Do not sleep.

Every retry must be caused by an actually observed due in-progress Attempt.

Progress guard:

```text
after the reconciler completed,
the same Attempt ID must not still be due + in_progress
in the next newly established snapshot
```

If that impossible condition repeats, fail internally instead of looping
forever.

If:

```text
deadline_at > snapshotAt
```

the Attempt may remain `in_progress` in this response even if real wall time
passes the deadline during later SELECTs or JSON serialization. The response is
authoritative as of `snapshotAt`.

### 50.1.5 Grant relative to snapshot boundary

```text
Grant commits before snapshotAt
=> snapshot sees:
   #1 official_score_eligible = false
   Exception exists

Grant commits after snapshotAt
=> snapshot sees complete pre-Grant graph:
   #1 official_score_eligible = true
   no Exception
```

Both are valid.

Never produce:

```text
pre-Grant #1
+
post-Grant Exception
```

inside one response.

### 50.1.6 Replacement Start relative to snapshot boundary

```text
replacement Start commits before snapshotAt
=> snapshot sees:
   #2 exists
   Exception.replacement_attempt_id = #2.id

replacement Start commits after snapshotAt
=> snapshot sees complete pre-Start graph:
   no #2
   Exception.replacement_attempt_id = null
```

Never produce a cross-state graph where only one side of that atomic linkage is
visible.

### 50.1.7 Teacher Close relative to snapshot boundary

```text
Close commits before active-list snapshot
=> Blitz omitted

Close commits before detail snapshot
=> 409 blitz_not_active

Close commits after snapshotAt
=> one internally consistent pre-Close active response is allowed
```

A post-snapshot Close must not become partially visible in later Attempt or
Exception SELECTs.

The next Student GET observes the committed Close.

### 50.1.8 Integrity validation only after coherent load

Run Section 55 graph validation only after all final Attempt + Exception rows
come from the same MVCC snapshot.

Therefore these remain true corruption only when they coexist in one coherent
snapshot:

```text
Exception exists + #1 still official_score_eligible=true
Exception replacement link points to #2 absent from loaded history
#2 exists + same snapshot Exception replacement_attempt_id is null
```

Do not throw `LogicException` merely because a legal Grant, replacement Start or
Close committed outside the response snapshot.

### 50.1.9 GET-side mutation boundary

Student active/detail GET may write only through the already-delivered BE-007
due-timeout reconciler.

The final snapshot itself is read-only and must not mutate:

```text
BlitzTask
Assessment
AssessmentStudent
BlitzAttemptException
non-due AssessmentAttempt
AttemptAnswer
AnswerFile
File
idempotency_records
topic_result_pairs
```

---

# 51. Student Timing Projection Before Replacement Start

For a valid unused exception with no #2 yet:

## Individual mode

```text
mode = individual
synchronized_ends_at = null
deadline_at = null
remaining_seconds = null
```

## Synchronized mode

Preserve historical class timing:

```text
mode = synchronized
synchronized_ends_at = persisted common end
```

but replacement timing has not started:

```text
deadline_at = null
remaining_seconds = null
```

Even if:

```text
server_now >= synchronized_ends_at
```

Student detail remains executable because:

```text
replacement_attempt_available = true
```

Do not return `blitz_time_expired` solely because the normal class window ended.

---

# 52. Student Timing Projection During Replacement #2

When #2 is in progress, in **both** timer modes:

```text
deadline_at = #2.deadline_at
remaining_seconds = max(0, #2.deadline_at - server_now)
```

For synchronized mode also preserve:

```text
synchronized_ends_at = original class common end
```

Do not use that common end as #2 effective deadline.

---

# 53. Student Detail After Replacement Timeout

After BE-007 finalizes #2 timeout:

- no further Attempt exists;
- exception remains granted/used;
- replacement unavailable.

If the active Blitz detail is requested after the replacement's authoritative deadline and execution is exhausted:

```text
409 blitz_time_expired
```

No #3.

No reset.

---

# 54. Intent-Specific Student Start Decision Tree

After idempotency replay and locked history validation, branch first on the
validated request intent.

```text
if intent == resume:
    resolve exactly request.attempt_id inside own Blitz history
    if exact target is current valid in_progress Attempt:
        resume that exact Attempt
    else if exact target is due:
        reconcile -> blitz_time_expired
    else if exact own target is terminal/not resumable:
        attempt_not_editable
    else:
        resource_not_found

else if intent == start_normal:
    if no #1 exists:
        create normal #1 according to normal mode rules
    else if #1 is valid in_progress:
        return same #1 / 200
    else:
        attempts_exhausted
    // never create #2

else if intent == start_replacement:
    if valid in_progress #2 already exists:
        return same #2 / 200
    else if #1 terminal and valid unused exception exists and no #2:
        create #2 with full duration
    else:
        attempts_exhausted or the exact documented lifecycle/integrity conflict
    // never resume/create #1
```

Before returning/resuming, BE-007 due reconciliation still applies.

Critical invariant:

> The server must never fall through from a stale `resume` or `start_normal`
> request into the replacement-creation branch merely because an exception
> appeared before lock acquisition.

Never choose a different current Attempt for `resume`.

---

# 55. Invalid Exception Runtime State

Examples:

```text
exception exists but invalidated_attempt_id != #1
exception recipient/student mismatch
replacement_attempt_id points to missing Attempt
replacement_attempt_id points to Attempt #1
replacement Attempt number != 2
#2 exists but exception replacement_attempt_id is null
#1 remains official_score_eligible = true after grant
#2 official_score_eligible = false at creation
```

These are persistence-integrity failures only after the complete Student
Attempts + Exception graph has been loaded from the Section 50.1 coherent final
snapshot.

Do not classify a legal concurrent commit outside that snapshot as corruption.

Do not silently repair a genuinely impossible same-snapshot graph.

Use:

```text
LogicException
```

for impossible internal graph unless a directly actionable public business
conflict is explicitly defined.

---

# 56. Official Pair Semantics

Exception grant does not change:

```text
topic_result_pairs
```

Do not rewrite:

```text
homework_assessment_id
blitz_assessment_id
cohort_snapshotted_at
locked_at
designated_at
updated_at
```

The official pair remains locked historical identity.

The original Attempt remains history but becomes:

```text
official_score_eligible = false
```

Replacement #2 becomes the only eligible replacement candidate.

Stage 9 later uses these eligibility flags during official score resolution.

---

# 57. Practice Blitz Semantics

Student-specific exception is also valid for an assigned practice/supplementary Blitz.

The same rules apply:

```text
one normal #1
one optional replacement #2
#1 ineligible after exception
#2 eligible
```

No Topic result-pair mutation.

No official score is calculated in Stage 8.

---

# 58. Teacher Grant Does Not Change Class-Wide Policy

Granting one Student an exception must not:

- change Blitz duration;
- change activation;
- change synchronized common end;
- change timer mode;
- create recipients;
- make Attempt #2 available to another Student;
- change `attempt_policy.normal_attempts = 1`.

Teacher/Student public policy still reports:

```text
normal_attempts = 1
max_additional_exception_attempts = 1
```

---

# 59. Exception Resource / Student Projection Privacy

Teacher grant response may show:

```text
reason_type
reason
invalidated/replacement Attempt IDs
```

Student active/detail summary does **not** need to expose Teacher reason text.

Student receives only operational flags:

```text
additional_exception_granted
replacement_attempt_available
```

BE-010 monitoring later may expose Teacher-side exception details.

---

# 60. Grant Error Precedence

After privacy-safe Teacher Blitz + Student target resolution and completed replay check:

1. validate locked Blitz lifecycle:
   ```text
   non-active -> blitz_attempt_exception_not_allowed
   ```
2. if existing exception:
   ```text
   blitz_attempt_exception_already_granted
   ```
3. validate normal #1 exists:
   ```text
   blitz_normal_attempt_required
   ```
4. validate #1 ownership/history;
5. if #1 is live pre-deadline:
   ```text
   blitz_attempt_exception_not_allowed
   ```
6. if due in-progress:
   timeout-finalize through shared finalizer;
7. validate #1 terminal + currently eligible;
8. create exception/invalidate eligibility.

This precedence is mandatory.

---

# 61. Grant Replay Before Current Lifecycle Conflict

A completed same-key grant replay is a historical replay.

After privacy authorization, it may return successfully even if the Blitz later became:

```text
closed
archived
```

or replacement #2 already started/finished.

Do not re-grant.

Do not reject the completed replay merely because new grants are no longer allowed.

The exception resource reflects the exact Section 27 current projection.

Therefore, when the original grant committed but the Blitz later closed/archived
before replacement #2 started, replay returns:

```text
201
replacement_attempt_id = null
replacement_attempt_available = false
```

If #2 already started, replay returns:

```text
201
replacement_attempt_id = #2 UUID
replacement_attempt_available = false
```

If the Blitz remains active and #2 has not started:

```text
201
replacement_attempt_id = null
replacement_attempt_available = true
```

The recorded HTTP status remains:

```text
201
```

No replay path reopens the Blitz or restores replacement availability.

---

# 62. Grant vs Student Execution-Intent Race

A Student may send a normal Start/Resume/replacement Start while Teacher grant is
happening.

Required serialization:

## `start_normal` commits before grant

If #1 is terminal and no exception:

```text
start_normal -> attempts_exhausted
```

Grant may then commit later.

The old request is never retroactively converted.

## Grant commits before stale `start_normal`

The request still means `start_normal`:

```text
#1 terminal + exception available
-> attempts_exhausted
-> zero #2 creation
```

Student must explicitly confirm/send a later `start_replacement`.

## Stale `resume #1` races grant

If Resume was issued for #1 and grant/timeout makes #1 terminal before the Resume
decision:

```text
resume(attempt_id=#1)
-> attempt_not_editable
   or blitz_time_expired when that request discovers/reconciles the due boundary
-> zero #2 creation
```

The committed grant must not change Resume's meaning.

## Confirmed `start_replacement`

Only a request whose body explicitly says:

```text
intent = start_replacement
```

may create #2 after the grant commits.

## #1 still in-progress before deadline

Grant rejects; exact Resume of #1 may continue #1.

No duplicate in-progress Attempts.

---

# 63. Concurrent Replacement Starts

Two different new Start keys race after a granted unused exception.

Required:

- exactly one Attempt #2 row;
- exception links exactly that row;
- one Start returns `201`;
- the other sees/resumes #2 and returns `200`;
- #2 has one `started_at` and one deadline;
- no #3.

Same-key concurrency follows ordinary Start idempotency.

---

# 64. Replacement Start vs Teacher Close

## Replacement Start commits first

Teacher Close later sees #2 in progress and finalizes it according to BE-007 deadline precedence.

## Teacher Close commits first

Student Start re-reads closed Blitz:

```text
409 blitz_not_active
```

No #2.

Exception remains historical unused.

No reopening.

---

# 65. Replacement Start vs Scheduler

Scheduler uses #1/#2 persisted deadlines.

If #2 has not started:

```text
no Attempt -> nothing to timeout
```

If #2 started:

```text
Scheduler finalizes at #2.deadline_at
```

The synchronized class common end does not timeout #2 early.

---

# 66. Expected File Scope

Exact filenames may follow delivered code conventions.

## Create likely

```text
backend/app/Actions/Teacher/GrantTeacherBlitzAttemptException.php

backend/app/Http/Requests/Teacher/TeacherBlitzAttemptExceptionRequest.php
backend/app/Http/Resources/Teacher/TeacherBlitzAttemptExceptionResource.php

backend/app/Exceptions/Teacher/BlitzAttemptExceptionNotAllowedException.php
backend/app/Exceptions/Teacher/BlitzAttemptExceptionAlreadyGrantedException.php
backend/app/Exceptions/Teacher/BlitzNormalAttemptRequiredException.php

backend/tests/Feature/Teacher/TeacherBlitzAttemptExceptionApiTest.php
backend/tests/Feature/Teacher/TeacherBlitzAttemptExceptionAuthorizationTest.php
backend/tests/Feature/Teacher/TeacherBlitzAttemptExceptionIdempotencyTest.php
backend/tests/Feature/Teacher/TeacherBlitzAttemptExceptionConcurrencyTest.php

backend/tests/Feature/Student/StudentBlitzReplacementAttemptStartTest.php
backend/tests/Feature/Student/StudentBlitzReplacementAttemptTimingTest.php
backend/tests/Feature/Student/StudentBlitzReplacementAttemptConcurrencyTest.php
backend/tests/Feature/Student/StudentBlitzExceptionReadConsistencyTest.php

backend/app/Support/Student/StudentBlitzReadSnapshot.php
```

`StudentBlitzReadSnapshot` is the preferred narrow helper name. A repository-
consistent responsibility-equivalent name is allowed.

It owns only:

```text
RR READ ONLY transaction setup
first-statement snapshotAt capture
same-connection final-read execution
```

It must not own lifecycle policy, timeout mutation, exception policy or response
serialization.

## Modify

```text
backend/routes/api.php

backend/app/Http/Controllers/Api/V1/Teacher/TeacherBlitzController.php

backend/app/Enums/IdempotencyOperation.php
backend/app/Support/ApiErrorResponse.php
backend/bootstrap/app.php

delivered BE-005/007/008 Student Blitz:
StartStudentBlitzAttempt
StudentBlitzAttemptAccess
StudentBlitzAttemptStartRequest
StudentBlitzAttemptSummary
StudentBlitzTiming
ListStudentActiveBlitz
ShowStudentBlitz
ShowStudentBlitzAttempt
StudentBlitzSummaryResource
StudentBlitzResource
StudentBlitzAttemptResource
and only direct equivalents required
```

The read actions may change only as needed for Section 50.1 coherent snapshots.
Resources still perform no hidden queries.

```text

delivered BE-007:
BlitzAttemptFinalizer
only as a reused dependency; modify only if a narrow public method exposure is needed without changing semantics.
```

No migration.

No schema change.

No frontend/docs/tasks.

---

# 67. Teacher Grant API Tests

Create:

```text
TeacherBlitzAttemptExceptionApiTest
```

Cover:

- valid technical grant;
- valid other_valid grant;
- reason trimmed/persisted;
- max reason validation;
- exact resource/message/status;
- #1 remains historical;
- #1 `official_score_eligible` becomes false;
- no Attempt #2 created;
- exception replacement ID null;
- pair unchanged;
- class policy unchanged.

---

# 68. Teacher Grant Authorization Tests

Cover:

- unauthenticated;
- wrong role;
- foreign Institution Blitz;
- another Teacher's Blitz;
- ended Teacher–Group membership;
- malformed Blitz UUID;
- malformed Student UUID;
- foreign Student;
- unassigned Student;
- Student assigned to another Blitz only;
- inactive Student;
- direct UUID probing.

Private/out-of-scope target:

```text
404 resource_not_found
```

---

# 69. Teacher Grant Lifecycle Tests

Cover:

- active Blitz + terminal #1 succeeds;
- synchronized common end passed but Blitz active still allows grant;
- Draft rejected;
- Scheduled rejected;
- Closed rejected;
- Archived rejected;
- no #1 -> `blitz_normal_attempt_required`;
- #1 in-progress before deadline -> `blitz_attempt_exception_not_allowed`;
- #1 in-progress at deadline -> timeout-finalized then grant succeeds atomically;
- #1 in-progress after deadline -> same;
- due timeout exact historical fields;
- terminal #1 reason/timestamps unchanged by grant;
- no fake finalization reason.

---

# 70. Teacher Grant Uniqueness / Eligibility Tests

Cover:

- second new key after exception -> already_granted;
- one exception per Student/Blitz;
- another Student may independently receive one exception;
- same Student on another Blitz may independently receive one exception;
- #1 already `official_score_eligible=false` without exception -> integrity failure;
- exception record points to exact recipient/#1.

---

# 71. Grant Idempotency Tests

Create:

```text
TeacherBlitzAttemptExceptionIdempotencyTest
```

Cover:

- operation exact:
  ```text
  teacher.blitz.attempt_exception.grant
  ```
- first success completed record exact;
- same key/same route/body replay -> same exception;
- same key/different reason -> idempotency_key_reused;
- same key/different Student -> reused;
- same key/different Blitz -> reused;
- different Teacher same key independent;
- failure leaves no claim;
- injected completion failure rolls back:
  - exception;
  - #1 eligibility mutation;
  - same-transaction timeout transition if any;
  - claim;
- replay after later Close remains `201` success;
- replay after later Close before #2 returns `replacement_attempt_id=null` + `replacement_attempt_available=false`;
- replay after later Archive before #2 returns the same unused-but-unavailable shape;
- replay after #2 starts returns same exception with current replacement ID + availability false;
- active replay before #2 returns null ID + availability true;
- non-null replacement ID + availability true is never serialized.

---

# 72. Grant Concurrency Tests

Create:

```text
TeacherBlitzAttemptExceptionConcurrencyTest
```

Cover:

1. same-key concurrent grants;
2. different-key concurrent grants;
3. grant vs timeout finalizer;
4. grant vs Teacher Close;
5. grant vs Student Start.

Required:

- one exception max;
- no early fake timeout;
- no duplicate eligibility mutation;
- no deadlock;
- no #2 without committed grant.

---

# 73. Replacement Start Tests

Create:

```text
StudentBlitzReplacementAttemptStartTest
```

Cover:

- exact `start_replacement` body required for #2 creation;
- #1 terminal + no exception + `start_replacement` -> attempts_exhausted;
- granted exception -> new key + `start_replacement` creates #2;
- stale `start_normal` after grant -> attempts_exhausted and zero #2;
- stale `resume` targeting #1 after grant -> attempt_not_editable/time_expired as applicable and zero #2;
- Resume of in-progress #2 requires exact #2 `attempt_id`;
- #2 exact ownership/number;
- #1 remains ineligible;
- #2 eligible;
- exception links #2;
- no copied answers/files;
- #2 Questions start empty answer state;
- no #3 after #2 terminal;
- no #2 without exception;
- old #1 Start key replays #1 and does not create #2;
- new replacement Start key creates #2.

---

# 74. Replacement Timing Tests

Create:

```text
StudentBlitzReplacementAttemptTimingTest
```

Cover:

## Individual

```text
#2 deadline = #2 started_at + duration
full duration
```

## Synchronized before common end

```text
#2 deadline = replacement start + duration
not common end
```

## Synchronized after common end

- detail remains replacement-available;
- Start succeeds while Blitz active;
- #2 gets full duration;
- historical `synchronized_ends_at` unchanged.

## Fractional server instant

For `duration_seconds = 600`, raw server time:

```text
12:00:00.500000Z
```

must create #2 with:

```text
started_at = 12:00:00Z
deadline_at = 12:10:00Z
```

and no fractional persistence/wire component.

Also prove `12:00:00.999999Z` truncates to `12:00:00Z`, never rounds upward.

## Institution setting changed later

No effect:

```text
activation timer snapshot unchanged
replacement still uses Blitz configured duration
```

---

# 75. Replacement Active List / Detail Tests

Cover:

- terminal #1 + granted unused exception appears in active list;
- synchronized common end passed + unused exception still appears;
- `additional_exception_granted=true`;
- `replacement_attempt_available=true`;
- pre-#2 synchronized detail:
  ```text
  synchronized_ends_at historical
  deadline_at null
  remaining_seconds null
  ```
- #2 in progress:
  ```text
  in_progress_attempt_id = #2
  replacement_available=false
  deadline_at = #2 deadline
  ```
- #2 terminal:
  no further start capacity.

---

# 75.1 Student GET Snapshot Consistency Tests

Create:

```text
StudentBlitzExceptionReadConsistencyTest
```

Use real PostgreSQL and deterministic worker/barrier coordination.

Do not use arbitrary sleeps.

A test-only DB query observer/barrier may release a separate PostgreSQL worker
after a known production SELECT. Do not add a production debug endpoint,
production sleep or production race hook.

## Grant commits between final SELECTs

Force:

1. GET establishes its RR snapshot;
2. GET reads Attempt history;
3. separate Teacher Grant transaction commits;
4. GET proceeds to Exception read.

The first response must remain the complete pre-Grant snapshot:

```text
additional_exception_granted = false
no mixed-graph LogicException
```

A follow-up GET must see the complete post-Grant state:

```text
additional_exception_granted = true
#1 internally ineligible
replacement availability derived from committed Exception
```

## Replacement Start commits between final SELECTs

Start from a committed unused Exception.

Force:

1. GET establishes final snapshot;
2. GET reads Attempt history without #2;
3. separate `start_replacement` transaction commits #2 + Exception link;
4. GET proceeds to Exception read.

First response:

```text
complete pre-replacement-Start snapshot
replacement_attempt_available = true
in_progress_attempt_id = null
no mixed-graph LogicException
```

Follow-up GET:

```text
#2 visible
Exception replacement link visible
in_progress_attempt_id = #2.id
replacement_attempt_available = false
```

## Teacher Close commits between final SELECTs

Force:

1. detail GET establishes active final snapshot;
2. lifecycle/recipient state is read;
3. Teacher Close commits;
4. GET continues to Attempts/Exception reads.

First response:

```text
internally consistent pre-Close active projection
```

Follow-up detail GET:

```text
409 blitz_not_active
```

Follow-up active list omits the closed Blitz.

## Close before final snapshot

If Close commits before `snapshotAt`:

```text
active list -> omitted
detail -> 409 blitz_not_active
```

## Deadline crossing after preliminary reconciliation

Force the authoritative deadline to become due between preliminary
reconciliation and final `snapshotAt`.

Required:

```text
first final snapshot discarded
BE-007 reconciler invoked
new RR snapshot established
no stale due in_progress projection
```

Timeout reason/timestamps remain exactly BE-007-owned.

## Snapshot clock

Assert the same whole-second `snapshotAt` drives:

```text
server_now
deadline eligibility
remaining_seconds
```

for the final response.

---

# 76. Replacement Concurrency Tests

Create:

```text
StudentBlitzReplacementAttemptConcurrencyTest
```

Cover:

- two new `start_replacement` keys after grant;
- same-key replacement Start replay;
- stale `resume #1` racing grant/timeout cannot create #2;
- stale `start_normal` racing grant cannot create #2;
- Resume #2 vs terminalization preserves exact target semantics;
- Start #2 vs Teacher Close;
- Start #2 vs timeout/Scheduler after creation.

Required:

- exactly one #2;
- exception links it;
- one #2 deadline;
- no #3;
- Close/timeout terminal reason immutable.

---

# 77. BE-005 Start Regression

Run the existing normal Start block.

Verify exception extension does not change:

- no-attempt normal #1;
- synchronized normal common deadline;
- individual normal full duration;
- Start idempotency;
- official first-activity pair lock;
- normal #1 remains one normal attempt.

Normal synchronized Student without exception still cannot Start after common end.

---

# 78. BE-007 Finalization Regression

Run focused timeout/Teacher Close/Scheduler tests.

Add replacement-specific checks:

- #2 timeout uses its persisted replacement deadline;
- synchronized common end does not prematurely finalize #2;
- Teacher Close before #2 deadline uses task_closed_auto_finalize;
- after/equal #2 deadline uses timeout_auto_submit.

No BE-007 algorithm duplication.

---

# 79. BE-008 Submit Regression

Run focused Blitz Submit tests.

Add valid #2 Submit coverage:

- pre-deadline #2 explicit Submit;
- late #2 timeout conflict;
- same-key Submit replay;
- #1 history untouched.

The Submit endpoint remains Attempt-ID based.

---

# 80. Verification Commands

Run from:

```text
backend/
```

## 80.1 Teacher exception tests

```bash
php artisan test \
  tests/Feature/Teacher/TeacherBlitzAttemptExceptionApiTest.php \
  tests/Feature/Teacher/TeacherBlitzAttemptExceptionAuthorizationTest.php \
  tests/Feature/Teacher/TeacherBlitzAttemptExceptionIdempotencyTest.php \
  tests/Feature/Teacher/TeacherBlitzAttemptExceptionConcurrencyTest.php
```

## 80.2 Student replacement tests

```bash
php artisan test \
  tests/Feature/Student/StudentBlitzReplacementAttemptStartTest.php \
  tests/Feature/Student/StudentBlitzReplacementAttemptTimingTest.php \
  tests/Feature/Student/StudentBlitzReplacementAttemptConcurrencyTest.php \
  tests/Feature/Student/StudentBlitzExceptionReadConsistencyTest.php
```

## 80.3 Direct BE-005 regression

Run the delivered focused normal Blitz Start/read/idempotency/official-pair tests affected by history extension.

## 80.4 Direct BE-007 regression

Run the delivered focused Blitz timeout/Close/Scheduler tests affected by Attempt #2 timing.

## 80.5 Direct BE-008 regression

Run the delivered focused Blitz Submit lifecycle/idempotency tests affected by valid Attempt #2.

## 80.6 Format

```bash
./vendor/bin/pint --test
```

No additional static-analysis command is required unless current repository configuration makes one mandatory for exactly this backend scope.

## 80.7 Always

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

# 81. Acceptance Criteria — Grant

- [ ] Exact Teacher exception endpoint exists once.
- [ ] Required Idempotency-Key.
- [ ] Exact reason_type enum.
- [ ] Mandatory trimmed non-empty reason.
- [ ] Target Student must be active assigned recipient.
- [ ] Current Student Group membership is not re-required.
- [ ] New grant requires active Blitz.
- [ ] Exactly normal Attempt #1 required.
- [ ] Live pre-deadline #1 cannot be invalidated.
- [ ] Due #1 uses authoritative timeout finalizer.
- [ ] #1 remains historical.
- [ ] #1 becomes `official_score_eligible=false`.
- [ ] Grant creates no #2.
- [ ] Exactly one exception row.
- [ ] Result pair/class policy unchanged.
- [ ] No scoring/checking.

---

# 82. Acceptance Criteria — Grant Idempotency

- [ ] Operation exact.
- [ ] Fingerprint includes Blitz, Student, canonical reason body.
- [ ] Grant + #1 invalidation + completed claim atomic.
- [ ] Same-key replay returns same exception.
- [ ] Active unused replay projects `replacement_attempt_id=null` + available true.
- [ ] Closed/Archived unused replay projects `replacement_attempt_id=null` + available false.
- [ ] Replay after #2 exists projects exact #2 ID + available false.
- [ ] Non-null replacement ID + available true is invalid.
- [ ] Different key after grant returns already_granted.
- [ ] Different fingerprint key reuse rejected.
- [ ] Failure leaves no incomplete/successful claim.
- [ ] Replay after later lifecycle remains valid and never reopens availability.

---

# 83. Acceptance Criteria — Replacement Attempt

- [ ] Same Start URL used.
- [ ] Request intent explicitly distinguishes `start_normal|resume|start_replacement`.
- [ ] `resume` is bound to one exact `attempt_id` and never creates/switches Attempts.
- [ ] Only `start_replacement` may create #2.
- [ ] #2 requires committed exception.
- [ ] No #2 without terminal #1.
- [ ] #1 must be ineligible.
- [ ] #2 is eligible.
- [ ] Exception links #1 -> #2 atomically.
- [ ] No answers/files copied.
- [ ] No #3.
- [ ] New key + `start_replacement` intent required to create replacement after old #1 key.
- [ ] Old #1 key/body never reinterprets to #2; different-intent reuse is idempotency_key_reused.
- [ ] #2 Resume uses `intent=resume` + exact #2 ID and same deadline.
- [ ] Stale Resume #1 after grant cannot create #2.
- [ ] BE-006 answer/file works on #2.
- [ ] BE-008 Submit works on #2.

---

# 84. Acceptance Criteria — Replacement Timing

- [ ] #2 gets full Blitz duration in individual mode.
- [ ] #2 gets full Blitz duration in synchronized mode.
- [ ] Synchronized class end remains unchanged/history-only for #2.
- [ ] #2 may start after common end while Blitz remains active.
- [ ] #2 `started_at/deadline_at` persist at UTC whole-second precision.
- [ ] Fractional raw Start time is truncated before deadline arithmetic.
- [ ] #2 persisted deadline is authoritative for BE-007.
- [ ] Teacher Close still blocks new replacement Start.
- [ ] Device time cannot affect replacement window.

---

# 85. Acceptance Criteria — Student Projection

- [ ] Additional exception flag true when exception exists.
- [ ] Replacement available only before #2 starts and while Blitz active.
- [ ] Unused exception makes synchronized Blitz executable after common end.
- [ ] Pre-#2 replacement detail has null effective deadline/remaining.
- [ ] In-progress #2 uses its own deadline.
- [ ] Terminal #2 provides no further capacity.
- [ ] Student does not receive Teacher reason text in normal Blitz detail.
- [ ] Active list final graph uses one PostgreSQL RR read-only snapshot.
- [ ] Detail final graph uses one PostgreSQL RR read-only snapshot.
- [ ] Attempts and Exception cannot come from different committed states.
- [ ] One whole-second snapshotAt drives final timing/eligibility.
- [ ] Snapshot-visible due Attempt triggers reconcile + new snapshot.
- [ ] Post-snapshot Grant cannot partially appear in the current response.
- [ ] Post-snapshot replacement Start cannot partially appear in the current response.
- [ ] Post-snapshot Close cannot mix post-Close child state into a pre-Close response.

---

# 86. Acceptance Criteria — Concurrency / Integrity

- [ ] Concurrent grants create max one exception.
- [ ] Concurrent replacement Starts create max one #2.
- [ ] No #2 without exception link.
- [ ] No exception without exact #1.
- [ ] No fake early terminal reason.
- [ ] Grant/Close/timeout serialize safely.
- [ ] #1/#2 official eligibility flags are deterministic.
- [ ] Pair/cohort/history identity never rewritten.
- [ ] Corrupt exception graph is not silently repaired.
- [ ] Same-snapshot corruption is distinguished from legal cross-snapshot concurrency.
- [ ] Controlled Grant/replacement-Start/Close inter-query tests produce coherent old-or-new graphs only.

---

# 87. Scope Acceptance

- [ ] No migration.
- [ ] No exception revoke/edit.
- [ ] No Attempt #3.
- [ ] No class-wide retry.
- [ ] No monitoring API implementation beyond projection fields already owned here.
- [ ] No checking/scoring.
- [ ] No frontend/docs/task changes.
- [ ] Focused exception/replacement tests pass.
- [ ] BE-005/007/008 regressions pass.
- [ ] Pint passes.
- [ ] `git diff --check` passes.

---

# 88. Focused Diff Self-Check

Before completion confirm:

```text
Teacher one-Student exception grant
+
replacement Attempt #2 Start/Resume
+
Student availability/timing integration
+
coherent Student active/detail MVCC reads
```

Verify specifically:

```text
1 normal attempt remains fixed
grant creates no Attempt
#1 remains historical/ineligible
#2 only through exception
#2 full duration in both modes
synchronized class end unchanged
Student GET Attempts/Exception one coherent RR snapshot
snapshotAt whole-second authority
no cross-state LogicException from legal Grant/Start/Close races
no #3
no scoring/checking
```

Confirm no unrelated refactor.

---

# 89. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. grant endpoint/request/resource;
4. grant eligibility/lifecycle rules;
5. in-progress #1 handling;
6. #1 official-score invalidation;
7. exception idempotency operation/fingerprint/result metadata;
8. replacement #2 Start decision tree;
9. synchronized/individual replacement timing;
10. Student list/detail availability projection;
11. Student GET RR read-snapshot/stabilization protocol;
12. exception/#2 atomic linkage;
13. concurrency behavior;
14. Teacher exception focused test results;
15. Student replacement/read-consistency focused test results;
16. BE-005 regression results;
17. BE-007 regression results;
18. BE-008 regression results;
19. Pint result;
20. `git diff --check`;
21. final `git status --short`;
22. focused scope/diff self-check;
23. any blocker/deviation.

Do not claim Stage 8 backend complete.

After delivery ChatGPT performs read-only acceptance review.

`S08-BE-010` remains blocked until:

```text
S08-BE-009 = Accepted / Delivered
```

---

# 90. Implementation Readiness Verdict

```text
Scope / non-goals                      = RESOLVED
Grant endpoint/header/body             = RESOLVED
Teacher/Student authorization          = RESOLVED
Reason semantics                       = RESOLVED
Normal Attempt #1 prerequisite         = RESOLVED
Live #1 invalidation boundary          = RESOLVED
Due #1 timeout integration             = RESOLVED
Original history/eligibility           = RESOLVED
Exactly-one exception                  = RESOLVED
Grant idempotency                      = RESOLVED
Grant replay availability projection   = RESOLVED
No Attempt creation at grant           = RESOLVED
Explicit Start/Resume/replacement intent = RESOLVED
Stale Resume replacement boundary       = RESOLVED
Replacement #2 Start rule               = RESOLVED
Replacement timing synchronized         = RESOLVED
Replacement timing individual          = RESOLVED
Common synchronized-end preservation   = RESOLVED
Student availability projection        = RESOLVED
Student GET coherent-read snapshot       = RESOLVED
Student GET reconciliation stabilization = RESOLVED
Exception/#2 atomic linkage              = RESOLVED
BE-006/007/008 compatibility             = RESOLVED
Pair/cohort preservation               = RESOLVED
Concurrency/lock ordering              = RESOLVED
Error behavior                         = RESOLVED
Acceptance criteria                    = RESOLVED
Focused verification                   = RESOLVED

Implementation Readiness Gate          = PASS
Execution dependency                   = S08-BE-008 Accepted / Delivered
```
