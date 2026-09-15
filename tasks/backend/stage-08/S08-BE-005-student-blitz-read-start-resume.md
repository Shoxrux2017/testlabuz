# Codex Implementation Contract: S08-BE-005 — Student Blitz Read and Idempotent Start/Resume

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-BE-005` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel Student active Blitz read + server-authoritative normal Attempt #1 Start/Resume + narrow existing Homework Start pair-lock compatibility` |
| Depends on | `S08-DOC-001`, `S08-BE-001`, `S08-BE-002`, `S08-BE-003`, `S08-BE-004` — all `Accepted / Delivered` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` after dependencies are delivered and immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |
| Backend block checkpoint | `Stage 8 Backend Phase 2` after `S08-BE-001…010` are `Accepted / Delivered` |
| Blocks | `S08-BE-006` |

Start only when:

```text
S08-DOC-001 = Accepted / Delivered
S08-BE-001  = Accepted / Delivered
S08-BE-002  = Accepted / Delivered
S08-BE-003  = Accepted / Delivered
S08-BE-004  = Accepted / Delivered
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
4. delivered S08-BE-001…004 source/tests directly required by this task;
5. current Student Homework read/Start/idempotency source/tests directly required as patterns;
6. current Student-safe Question projection code;
7. current shared Assessment/Attempt models and persistence directly required by this task.

Do **not** read:

- `docs/01–09`;
- roadmap files;
- Stage indexes;
- `S08-DOC-001`;
- previous task files;
- closure reviews;
- frontend code

to infer behavior.

This contract already resolves:

- exact Student endpoints;
- active-list eligibility;
- detail visibility;
- Question secrecy before Start;
- server timing projection;
- synchronized deadline;
- individual deadline;
- normal Attempt #1 only;
- explicit `start_normal` vs specific-Attempt `resume` request intent semantics;
- durable Start/Resume idempotency;
- official-pair first-activity lock;
- existing Homework Start compatibility with a Blitz-origin pair lock;
- recipient/ownership/Tenant security;
- late Start/Resume behavior before the timeout engine exists;
- response fields;
- errors;
- concurrency;
- acceptance criteria;
- focused tests/verification.

If the delivered dependencies materially conflict with this contract, return:

```text
BLOCKED
```

with exact evidence.

Do not independently implement timeout finalization, replacement Attempt #2, answer mutation, Submit, or Teacher Close.

---

# 3. Goal

Implement the Student entry point into an already Teacher-activated Blitz.

At completion an assigned Student can:

```text
see currently executable Blitz tasks
view active Blitz instructions/timing/Attempt availability
start normal Blitz Attempt #1 exactly once
resume the same still-valid in-progress Attempt
receive Student-safe Questions only after Start/Resume
```

The server must be authoritative for:

```text
assignment
Blitz lifecycle
timer mode
started_at
deadline_at
remaining time
Attempt capacity
official-pair first activity lock
```

The device clock/timezone must never decide execution eligibility.

This task also owns one narrow compatibility correction to the already-delivered
Homework Start path: after Stage 8 makes Blitz-first Student activity valid, a
shared `topic_result_pairs.locked_at` backed by official Blitz activity must not
be misclassified as corrupted merely because the official Homework still has
zero Attempts.

---

# 4. Included Public Endpoints

Add exactly:

```text
GET  /api/v1/student/blitz/active
GET  /api/v1/student/blitz/{blitz}
POST /api/v1/student/blitz/{blitz}/attempts
```

All routes live inside the existing Student middleware group:

```text
auth:sanctum
active.account
password.changed
role:student
```

Do not add:

```text
GET /student/blitz/{blitz}/attempts/{attempt}
POST /student/blitz/{blitz}/submit
```

aliases.

Do not change the shared answer/submit routes in this task.

---

# 5. Explicit Non-Goals

Do not implement or change:

- typed answer save/replace;
- file answer save/replace;
- generic Attempt GET for Blitz;
- explicit Student Submit;
- timeout auto-finalization;
- request-path timeout reconciliation;
- Scheduler;
- Teacher Blitz Close;
- technical Attempt exception grant;
- replacement Attempt #2 Start;
- Teacher monitoring;
- checking/scoring;
- official score selection;
- Topic result;
- frontend;
- E2E harness/seed data;
- dependencies;
- docs;
- task/Stage bookkeeping.

Do not create:

```text
blitz_attempts
blitz_answers
```

Do not add migrations.

Do not alter shared Attempt schema.

The narrow compatibility update to the existing Homework Start Action/access is
**included** in this task. It must not change the Homework public endpoint,
request shape, idempotency operation, deadline behavior, three-normal-Attempt
policy, response shape, or Student authorization. It changes only the
official-pair activity integrity check from Homework-only evidence to
pair-wide official activity evidence.

---

# 6. Delivered Foundation to Reuse

Reuse:

```text
assessments
blitz_tasks
assessment_students
assessment_attempts
topic_result_pairs
questions
blitz_attempt_exceptions
idempotency_records
```

Reuse enums/models delivered through BE-004.

Reuse:

```text
IdempotencyGuard
IdempotencyRequestFingerprint
StudentQuestionResource
StudentQuestionAnswerUi
```

Reuse shared Student file-upload-limit projection logic where practical, but do not implement file mutation.

---

# 7. Stage Boundary — Attempt #1 Only

This task implements only the normal Blitz Attempt:

```text
Attempt #1
```

Do not create Attempt #2.

The exception table exists structurally, but runtime grant/replacement logic belongs to:

```text
S08-BE-009
```

Until BE-009 extends the Start behavior:

- no exception endpoint exists;
- no replacement Attempt is created;
- one terminal normal Attempt exhausts current runtime Start capacity.

The implementation should be structured so BE-009 can later extend:

```text
normal #1
→ approved exception
→ replacement #2
```

without changing the public Start URL.

No Attempt #3 is ever valid for Blitz.

---

# 8. Active Blitz List

## 8.1 Endpoint

```text
GET /api/v1/student/blitz/active
```

No request body.

No query parameters.

Any body/query key:

```text
422 validation_failed
```

## 8.2 Visibility base

A Blitz is considered for the Student only when:

```text
assessment.institution_id = student.institution_id
assessment.type = blitz
blitz_tasks.institution_id = student.institution_id
assessment_students.institution_id = student.institution_id
assessment_students.assessment_id = assessment.id
assessment_students.student_id = authenticated Student
blitz_tasks.status = active
```

UUID knowledge, Topic membership today, or Group membership today cannot replace the persisted recipient relation.

The activation recipient snapshot is authoritative.

## 8.3 Current execution eligibility

The Active list returns only tasks for which this Student can **start or resume normal Attempt #1 now**.

Include when either:

### Not started

```text
no Student Attempt exists
```

and timer mode permits a new normal Start.

### Resume

Exactly one normal:

```text
attempt_number = 1
status = in_progress
```

exists and its authoritative deadline has not been reached.

Exclude when:

- normal Attempt #1 is terminal;
- an in-progress Attempt is already at/past deadline;
- synchronized common end is reached before any Start;
- Blitz is not active;
- Student has no recipient row.

BE-009 later extends eligibility for a valid replacement exception.

## 8.4 Synchronized list timing

For:

```text
timer_start_mode_snapshot = synchronized
```

require valid:

```text
synchronized_ends_at
```

and:

```text
readAt < synchronized_ends_at
```

where:

```text
readAt = one backend server instant captured for the request and truncated to UTC whole-second precision
```

If:

```text
readAt >= synchronized_ends_at
```

exclude the Blitz from the Active list.

Do not finalize an Attempt here in BE-005.

## 8.5 Individual list timing

Before Attempt #1 starts:

```text
active Blitz remains startable
```

until Teacher lifecycle later closes it.

For existing in-progress Attempt #1:

```text
readAt < attempt.deadline_at
```

is required to include it.

Expired in-progress Attempt is excluded.

Do not timeout-finalize it here.

## 8.6 Ordering

Use deterministic:

```text
blitz_tasks.activated_at DESC
assessments.id DESC
```

## 8.7 Collection shape

Return a plain collection:

```json
{
  "data": []
}
```

No pagination/query contract is added for the active classroom list.

---

# 9. Active Blitz List Item

Each item returns Student-safe summary only:

```json
{
  "id": "blitz-uuid",
  "topic": {
    "id": "topic-uuid",
    "title": "Topic title"
  },
  "title": "Topic Blitz",
  "status": "active",
  "duration_seconds": 600,
  "timing": {
    "mode": "synchronized",
    "server_now": "2026-09-14T17:00:00Z",
    "synchronized_ends_at": "2026-09-14T17:05:00Z",
    "deadline_at": "2026-09-14T17:05:00Z",
    "remaining_seconds": 300
  },
  "attempts": {
    "normal_attempts": 1,
    "normal_used": 0,
    "in_progress_attempt_id": null,
    "additional_exception_granted": false,
    "replacement_attempt_available": false
  }
}
```

For individual mode before Start:

```json
{
  "timing": {
    "mode": "individual",
    "server_now": "2026-09-14T17:00:00Z",
    "synchronized_ends_at": null,
    "deadline_at": null,
    "remaining_seconds": null
  }
}
```

For individual mode with a valid in-progress Attempt:

```text
deadline_at = persisted Attempt.deadline_at
remaining_seconds = deadline_at - server_now
```

No Question content is returned in the Active list.

No answer keys/configuration are returned.

No Teacher/internal recipient IDs are returned.

---

# 10. Student Blitz Detail

## 10.1 Endpoint

```text
GET /api/v1/student/blitz/{blitz}
```

No body.

No query.

Malformed/private/unassigned Blitz:

```text
404 resource_not_found
```

## 10.2 Recipient-first privacy

A Student can resolve a Blitz detail only through a persisted own:

```text
assessment_students
```

recipient row.

Do not resolve a Blitz globally and then reveal lifecycle to an unassigned Student.

## 10.3 Lifecycle

If assigned but Blitz is:

```text
draft
scheduled
closed
archived
```

return:

```text
409 blitz_not_active
```

Active Blitz is readable subject to timing rules below.

## 10.4 Expired active execution window

For synchronized mode:

```text
server_now >= synchronized_ends_at
```

returns:

```text
409 blitz_time_expired
```

For individual mode with an existing in-progress Attempt:

```text
server_now >= attempt.deadline_at
```

returns:

```text
409 blitz_time_expired
```

BE-005 does **not** finalize the Attempt.

BE-007 later adds timeout reconciliation before the same conflict is returned/projected.

A terminal Attempt #1 does not itself make the active Blitz detail private; detail may return current metadata/Attempt usage even though no normal Start remains.

---

# 11. Critical Question-Secrecy Rule

`GET /student/blitz/{blitz}` must **not** return Question content before Start.

This is mandatory because in:

```text
individual
```

mode the Student timer starts only at Student Start.

If Detail exposed Questions first, the Student could inspect the Blitz without consuming timed execution.

Therefore Student Blitz Detail returns:

- title;
- description;
- Student instructions;
- total points;
- status;
- duration;
- timing projection;
- Attempt policy/usage;

but **not**:

```text
questions
answer_ui
correct-answer configuration
```

Questions become visible only in a successful Start/Resume Attempt resource.

Use the same secrecy rule for synchronized mode for one consistent Student API surface.

---

# 12. Student Blitz Detail Resource

Required shape:

```json
{
  "data": {
    "id": "blitz-uuid",
    "topic": {
      "id": "topic-uuid",
      "title": "Topic title"
    },
    "title": "Topic Blitz",
    "description": null,
    "student_instructions": "Answer independently.",
    "status": "active",
    "duration_seconds": 600,
    "total_possible_points": 5.0,
    "timing": {
      "mode": "synchronized",
      "server_now": "2026-09-14T17:00:00Z",
      "synchronized_ends_at": "2026-09-14T17:05:00Z",
      "deadline_at": "2026-09-14T17:05:00Z",
      "remaining_seconds": 300
    },
    "attempts": {
      "normal_attempts": 1,
      "normal_used": 0,
      "in_progress_attempt_id": null,
      "additional_exception_granted": false,
      "replacement_attempt_available": false
    }
  }
}
```

For individual before Start:

```text
timing.deadline_at = null
timing.remaining_seconds = null
```

For in-progress Attempt:

```text
attempts.normal_used = 1
attempts.in_progress_attempt_id = Attempt UUID
timing.deadline_at = Attempt.deadline_at
```

For terminal Attempt #1:

```text
attempts.normal_used = 1
attempts.in_progress_attempt_id = null
```

The detail remains Question-free.

---

# 13. Timing Projection

Create one focused server-side projector, conceptually:

```text
StudentBlitzTiming
```

or equivalent.

It receives:

- locked/read `BlitzTask`;
- optional Student Attempt;
- one request/action `serverNow`.

It must never read device time.

## 13.1 `server_now` and canonical timer precision

Every Student Blitz read/Start/Resume timing projection uses one backend instant
normalized before any timer arithmetic:

```text
serverNow =
  server_now in UTC
  truncated to whole-second precision
```

Canonical public form is exactly:

```text
YYYY-MM-DDTHH:MM:SSZ
```

No fractional second component is serialized.

All Stage 8 persisted Blitz timer timestamps consumed by this projector must also
be whole-second values:

```text
synchronized_ends_at
Attempt.started_at
Attempt.deadline_at
```

If a Stage 8 Blitz timer field created by the approved Stage 8 paths contains a
non-zero fractional component, treat it as an internal timing-integrity failure.
Do not silently round persisted history differently in different resources.

## 13.2 Remaining seconds

Because both values are canonical whole-second instants, calculate exactly:

```text
remaining_seconds =
max(0, deadline_epoch_second - serverNow_epoch_second)
```

No hidden fractional value participates in this calculation.

Equivalent Carbon integer-second arithmetic is allowed only when it yields this
exact result.

Tests must include controlled fractional raw server-clock instants and prove the
normalization occurs before comparison/arithmetic/serialization.

The client may animate a countdown locally for UX, but backend write eligibility
always rechecks authoritative server time under the same whole-second timer policy.

## 13.3 Synchronized

```text
mode = synchronized
synchronized_ends_at = persisted BlitzTask.synchronized_ends_at
deadline_at = synchronized_ends_at
```

for normal Attempt #1.

## 13.4 Individual before Start

```text
mode = individual
synchronized_ends_at = null
deadline_at = null
remaining_seconds = null
```

## 13.5 Individual after Start

```text
deadline_at = persisted AssessmentAttempt.deadline_at
remaining_seconds = max(0, deadline_epoch_second - serverNow_epoch_second)
```

---

# 14. Attempt Usage Projection

Create a focused Student Blitz Attempt summary/projector.

For BE-005 runtime:

```text
normal_attempts = 1
```

`normal_used`:

```text
0 if no Attempt #1
1 if Attempt #1 exists in any status
```

`in_progress_attempt_id`:

```text
Attempt #1 ID when status = in_progress
otherwise null
```

Until BE-009:

```text
additional_exception_granted = false
replacement_attempt_available = false
```

Do not infer a replacement opportunity from raw exception rows in this task.

BE-009 will extend the projection when the grant workflow exists.

---

# 15. Start Blitz Attempt Endpoint

## 15.1 Endpoint

```text
POST /api/v1/student/blitz/{blitz}/attempts
```

## 15.2 Required header

```http
Idempotency-Key: <uuid>
```

Missing/malformed:

```text
422 validation_failed
```

Normalize lowercase.

## 15.3 Body — explicit execution intent

The request body is mandatory and must be one JSON object representing the
Student's exact execution intent.

### Normal Start

Exact body:

```json
{
  "intent": "start_normal"
}
```

Accepted keys:

```text
intent
```

`start_normal` may create normal Attempt #1 when none exists. It may return the
already-existing in-progress #1 as a safe same-path result, but it must never
create replacement Attempt #2.

### Resume

Exact body:

```json
{
  "intent": "resume",
  "attempt_id": "attempt-uuid"
}
```

Accepted keys:

```text
intent
attempt_id
```

`attempt_id` must be a canonical UUID and identifies the exact Attempt the
Student intends to continue.

A Resume request may return only that exact own in-progress Attempt. Resume must
never:

- create Attempt #1;
- create Attempt #2;
- switch from #1 to #2;
- select a newer "current" Attempt automatically.

Until BE-009, only normal Attempt #1 can be a valid Resume target. BE-009 later
extends the same exact Resume intent to Attempt #2.

### Strict validation

Reject:

- empty body;
- `{}`;
- unknown `intent`;
- missing `attempt_id` for `resume`;
- `attempt_id` supplied for `start_normal`;
- malformed/non-object body;
- unknown keys.

All return:

```text
422 validation_failed
```

BE-009 later extends the same request contract with exactly one additional
intent:

```text
start_replacement
```

It does not reinterpret either `start_normal` or `resume`.

## 15.4 Query

No query parameters.

---

# 16. Idempotency Operation

Extend:

```text
IdempotencyOperation
```

with exactly:

```text
StudentBlitzAttemptStart = 'student.blitz.attempt.start'
```

Do not add Submit operation in this task.

Do not add exception-grant operation here if already delivered by a later dependency does not yet exist.

---

# 17. Start / Resume Fingerprint

After privacy-safe recipient/Blitz preliminary resolution, fingerprint the exact
semantic request intent.

For normal Start:

```text
operation = student.blitz.attempt.start
route = {
  "blitz_id": lowercase authorized Blitz UUID
}
body = {
  "intent": "start_normal"
}
```

For Resume:

```text
operation = student.blitz.attempt.start
route = {
  "blitz_id": lowercase authorized Blitz UUID
}
body = {
  "intent": "resume",
  "attempt_id": lowercase validated Attempt UUID
}
```

Use:

```text
IdempotencyRequestFingerprint
```

`intent` and Resume `attempt_id` are semantic body identity and therefore must be
included in the fingerprint.

The same key reused with a different intent or a different Resume Attempt ID is:

```text
409 idempotency_key_reused
```

Do not include:

- timer mode;
- deadline;
- current time;
- derived Attempt number;
- lifecycle state

in request identity.

Those are authoritative server state.

BE-009 later adds `start_replacement` to the same body identity without creating
a second idempotency operation.

---

# 18. Student Blitz Access Boundary

Create:

```text
StudentBlitzAccess
```

or equivalent focused access helper.

It must not reuse:

```text
StudentHomeworkAccess
```

for Blitz lifecycle semantics.

## 18.1 Assigned resolution

`resolveAssigned(...)` must require:

```text
same Institution
Assessment.type = blitz
BlitzTask exists
own AssessmentStudent recipient exists
```

It may resolve regardless of Blitz lifecycle so the API can distinguish:

```text
unassigned/private -> 404
assigned but inactive -> 409
```

## 18.2 Read query

Student-safe query must join/filter by the Student's own recipient row.

Load only own Attempts.

Do not use current Group membership as authorization.

Do not expose another Student's Attempt.

---

# 19. Start Lock Order

Within the Start transaction, use deterministic parent-first ordering compatible with BE-004 activation/BE-007 finalization:

```text
1. Topic
2. Assessment
3. BlitzTask
4. TopicResultPair
5. own AssessmentStudent recipient
6. idempotency record
7. AssessmentAttempt rows required by the decision
8. Student-safe Questions/configuration relations for response after Start decision
```

For an **official** Start, pair-wide first-activity integrity must inspect
Attempts for both official Assessment IDs. Lock those rows only after the pair
lock, in deterministic:

```text
assessment_id
id
```

order.

Then partition/use the locked rows according to the owning task semantics:

- Blitz Start validates this Student's Blitz Attempt history under Sections
  22–26;
- the narrow Homework compatibility path continues to validate Homework history
  using the existing Homework-only history rules;
- cross-side rows are used only as evidence that official pair activity exists;
  they are not counted as Attempts of the other Assessment.

For a practice Blitz, lock only this Student's relevant Blitz Attempt history in
the delivered deterministic order.

If delivered BE-004 uses a slightly different compatible order for
pair/recipient/idempotency, preserve one consistent relative order across both
paths.

Do not lock unrelated Institution Student rows.

---

# 20. Start Locked Re-Resolution

After preliminary privacy-safe resolution, re-lock and re-read:

```text
Topic
Assessment
BlitzTask
recipient
```

Require the same authorized graph.

If the authorized graph disappears/corrupts during locking:

```text
LogicException
```

or privacy-safe domain failure according to the repository's existing invariant style.

Do not silently move the Student to another recipient row.

---

# 21. Start Lifecycle Validation

For a new Start/Resume require:

```text
Topic.status = active
BlitzTask.status = active
timer_start_mode_snapshot in synchronized|individual
activated_at non-null
duration_seconds > 0
Assessment total_possible_points > 0
```

If task lifecycle is not active:

```text
409 blitz_not_active
```

If timing structural fields are internally inconsistent:

```text
LogicException
```

rather than inventing Student-visible repair behavior.

---

# 22. Attempt #1 History Validation

Lock this Student's Blitz Attempts.

In BE-005 valid runtime history is:

```text
[]
```

or:

```text
[Attempt #1]
```

No other Attempt number is created by this task.

For every existing Attempt require:

```text
same Institution
same Assessment
same Student
same assessment_student_id
attempt_number = 1
deadline_at non-null
possible_points = Assessment total snapshot compatible with historical row
```

For `in_progress`:

```text
submitted_at = null
finalized_at = null
finalization_reason = null
locked_at = null
```

Terminal status may be any structurally valid later-state value supported by the shared schema.

Do not require Stage 9 scoring completion.

If history contains:

- duplicate #1;
- Attempt #2/#3 before BE-009 runtime support;
- recipient mismatch;
- invalid deadline mode shape;

treat as internal structural conflict:

```text
LogicException
```

Do not create another Attempt around corrupt history.

BE-009 later deliberately extends the history validator for approved Attempt #2.

---

# 23. Explicit Start / Resume Semantics

The backend must decide from the **validated request intent plus locked current
state**. Server state may validate or reject an intent; it must not silently
change the intent into a different operation.

## 23.1 `intent = start_normal`

### No Attempt yet

Create exactly:

```text
Attempt #1
```

if timing permits.

Complete idempotency with:

```text
response_status = 201
```

### Attempt #1 already in progress

Return the same #1 with:

```text
200
```

This is a safe same-path outcome for concurrent/double normal Starts.

Do not reset timer or mutate Attempt timestamps.

### Attempt #1 terminal

Return:

```text
409 attempts_exhausted
```

Even after BE-009 later introduces a replacement exception, `start_normal` must
never be reinterpreted as permission to create #2.

## 23.2 `intent = resume`

Resolve `attempt_id` only inside this authenticated Student's persisted recipient
and Blitz Attempt history.

### Target not owned by this Student/Blitz

Return privacy-safe:

```text
404 resource_not_found
```

### Exact target is valid in-progress Attempt #1 and before deadline

Return **that exact Attempt ID**:

```text
200
```

Do not:

- create another row;
- increment Attempt number;
- change `started_at`;
- change `deadline_at`;
- reset timer;
- touch Attempt timestamps;
- touch Blitz lifecycle;
- change pair lock.

Complete the new Resume idempotency key with:

```text
result_resource_type = assessment_attempt
result_resource_id = requested Attempt ID
response_status = 200
```

### Exact target reached deadline

Apply Section 26 timing behavior:

```text
409 blitz_time_expired
```

BE-007 later performs authoritative timeout reconciliation before the same public
outcome.

### Exact target is already terminal / no longer resumable

Return stable:

```text
409 attempt_not_editable
```

with Blitz-specific message:

```text
This Blitz attempt is no longer editable.
```

Resume performs zero Attempt creation.

## 23.3 Critical stale-state guarantee

A request that was semantically `resume` when the UI issued it remains Resume
even if, before the transaction decision:

- #1 times out or is submitted;
- a Teacher later grants an exception;
- replacement #2 becomes available;
- another request starts #2.

Such a stale Resume must return the appropriate current-state error for its exact
`attempt_id` and **must never create or switch to #2**.

This is an atomic server guarantee. A preliminary GET is not sufficient.

## 23.4 BE-009 extension boundary

BE-009 adds a separate explicit:

```text
intent = start_replacement
```

for replacement #2. It must not change the semantics above.

---

# 24. Synchronized Normal Start

Require persisted activation fields:

```text
timer_start_mode_snapshot = synchronized
synchronized_ends_at non-null
synchronized_ends_at
=
activated_at + duration_seconds
```

After all required lock waits and before creating Attempt, capture:

```text
startedAt = truncate_to_utc_second(server_now)
```

Persist `started_at` with zero fractional seconds.

If:

```text
startedAt >= synchronized_ends_at
```

return:

```text
409 blitz_time_expired
```

Do not create an immediately expired Attempt.

Do not persist an idempotency claim from the failed transaction.

For successful Attempt #1:

```text
started_at = startedAt
deadline_at = blitz_tasks.synchronized_ends_at
```

A late opener receives only the remaining common time.

---

# 25. Individual Normal Start

Require:

```text
timer_start_mode_snapshot = individual
synchronized_ends_at = null
```

Capture after lock waits:

```text
startedAt = truncate_to_utc_second(server_now)
```

Persist `started_at` with zero fractional seconds.

Then:

```text
deadlineAt = startedAt + duration_seconds
```

Persist:

```text
started_at = startedAt
deadline_at = deadlineAt
```

Student receives the full configured duration.

Do not use:

- activation time;
- scheduled time;
- device clock

as the Student deadline.

---

# 26. Resume Deadline Rules

For existing in-progress normal Attempt #1:

## Synchronized

Require:

```text
attempt.deadline_at = blitz_tasks.synchronized_ends_at
```

If:

```text
server_now >= attempt.deadline_at
```

return:

```text
409 blitz_time_expired
```

Do not modify the Attempt in BE-005.

## Individual

Require exact historical shape:

```text
attempt.deadline_at
=
attempt.started_at + blitz_tasks.duration_seconds
```

If:

```text
server_now >= attempt.deadline_at
```

return:

```text
409 blitz_time_expired
```

Do not modify the Attempt in BE-005.

BE-007 later replaces this read-only expiry rejection with authoritative timeout reconciliation.

---

# 27. Why BE-005 Does Not Finalize Timeout

Timeout finalization requires one shared engine reused by:

- Start/Resume;
- read reconciliation;
- answer/file writes;
- Submit;
- Teacher Close;
- Scheduler;
- monitoring.

That engine belongs to:

```text
S08-BE-007
```

Therefore BE-005 does only:

```text
authoritative deadline check
+
late Start/Resume rejection
```

and does not yet write:

```text
timed_out_finalized
timeout_auto_submit
finalized_at
locked_at
```

Do not implement a temporary separate timeout writer here.

---

# 28. Official Blitz Pair Detection

Inside Start lock the Topic result pair.

The Blitz is official only when:

```text
pair exists
AND
pair.blitz_assessment_id = assessment.id
```

Practice Blitz Start must not mutate:

```text
topic_result_pairs
```

---

# 29. Official Blitz Start Preconditions

For an official Blitz require:

```text
assessment.assignment_mode = group
recipient.assignment_source = group
pair.homework_assessment_id non-null
pair.blitz_assessment_id = assessment.id
pair.cohort_snapshotted_at non-null
```

Do not resnapshot Group membership.

Do not consult current Group membership to decide official cohort membership.

The persisted recipient row created/reused at activation is authoritative.

If these official invariants fail:

```text
409 business_conflict
```

Do not repair the pair/recipient graph.

---

# 30. First Official Activity Pair Lock

The Topic result-pair lock represents first Student activity on either official Assessment.

Before creating the first normal official Blitz Attempt:

- lock the pair;
- lock Attempts for both official Assessment IDs where necessary to validate first-activity history;
- preserve official identities/cohort.

## 30.1 Pair already locked

This is valid.

For example Homework Student activity may already have set:

```text
pair.locked_at
```

before any Blitz Attempt exists.

Preserve:

```text
locked_at
updated_at
```

Do not churn the pair timestamp merely because Blitz activity starts later.

## 30.2 Pair unlocked

If:

```text
pair.locked_at = null
```

require no existing Attempt on either official Assessment.

If any official Homework/Blitz Attempt exists while pair is unexpectedly unlocked:

```text
409 business_conflict
```

Do not repair historical inconsistency.

When creating the first official Blitz Attempt:

```text
pair.locked_at = startedAt
pair.updated_at = startedAt
```

using the exact same:

```text
startedAt
```

as the Attempt.

## 30.3 Pair locked but no official activity anywhere

If pair is structurally locked while neither official Assessment has any Attempt:

```text
409 business_conflict
```

Do not infer why it was locked.

## 30.4 Practice Blitz

No pair lock mutation.

## 30.5 Existing Homework Start must become pair-wide-lock compatible

This task owns the narrow Stage 8 compatibility update to the delivered:

```text
StartStudentHomeworkAttempt
StudentHomeworkAttemptAccess
```

or their exact delivered equivalents.

The public Homework Start contract remains unchanged.

For an official Homework Start, after locking the Topic result pair, inspect
Attempt **existence** across the two official Assessment IDs:

```text
pair.homework_assessment_id
pair.blitz_assessment_id when non-null
```

using the pair-wide deterministic Attempt lock order from Section 19.

Define:

```text
officialPairHasActivity
=
at least one AssessmentAttempt row exists for either official Assessment
within the authenticated Student Institution
```

The pair/activity invariant is symmetric:

```text
pair.locked_at = null
AND officialPairHasActivity = false
=> valid pre-first-activity state
```

```text
pair.locked_at = null
AND officialPairHasActivity = true
=> 409 business_conflict
```

```text
pair.locked_at != null
AND officialPairHasActivity = true
=> valid already-locked state
```

```text
pair.locked_at != null
AND officialPairHasActivity = false
=> 409 business_conflict
```

The critical valid Stage 8 case is:

```text
real official Blitz Attempt exists
pair.locked_at != null
official Homework Attempts = empty
```

The first Homework Start must then continue normally when all existing Homework
rules pass:

```text
create Homework Attempt #1
preserve pair.locked_at
preserve pair.updated_at
```

Do **not** require a Homework Attempt merely to justify the existing pair lock.

Keep Homework Attempt history/capacity completely separate:

- validate only Homework rows with the delivered Homework structural rules;
- Homework attempt numbers remain `1..3`;
- Blitz Attempts never increment Homework `attempt_number`;
- Blitz Attempts never count toward Homework exhaustion;
- do not interpret Blitz timeout/replacement history as Homework history;
- future valid Blitz Attempt #2 from BE-009 still counts as pair activity by
  existence without requiring another Homework compatibility redesign.

If the pair is still unlocked and the new Homework Attempt is the first official
activity, preserve the delivered Stage 7 behavior:

```text
pair.locked_at = Homework Attempt.started_at
pair.updated_at = Homework Attempt.started_at
```

before inserting the Attempt in the same transaction.

Practice Homework behavior remains unchanged.

Do not add a new endpoint, table, status, or public error for this compatibility
fix.

---

# 31. Normal Attempt #1 Persistence

Create:

```text
institution_id = Student Institution
assessment_id = Blitz Assessment ID
assessment_student_id = own recipient ID
student_id = authenticated Student ID
attempt_number = 1
status = in_progress
started_at = startedAt
deadline_at = effective deadline
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

Do not create answer rows.

Do not create empty answers for all Questions.

Do not score.

---

# 32. Student-Safe Question Projection After Start

Only after a successful Start/Resume decision load the current frozen Blitz Questions.

Use the delivered Student-safe projection:

```text
StudentQuestionResource
StudentQuestionAnswerUi
```

Never use:

```text
TeacherQuestionResource
```

in Student API.

## 32.1 Internal loads

The backend may load typed configuration required to derive safe UI, such as:

- option text/order;
- matching item text;
- ordering display items;
- blank positions;
- multiple-choice selection cap.

It must not serialize:

- `is_correct`;
- correct option IDs;
- accepted answers;
- true/false correct value;
- matching answer mapping;
- ordering correct positions;
- fill accepted values;
- checking configuration.

## 32.2 File-based Question UI

Reuse current Institution:

```text
student_submission_max_mb
```

and platform 15 MiB cap for safe `answer_ui`.

This is display guidance only.

File mutation remains BE-006.

If Institution submission setting is structurally invalid, follow the existing Student Homework invariant style:

```text
LogicException
```

rather than silently inventing a limit.

---

# 33. Start/Resume Attempt Resource

Return:

```json
{
  "data": {
    "id": "attempt-uuid",
    "assessment_id": "blitz-uuid",
    "attempt_number": 1,
    "status": "in_progress",
    "started_at": "2026-09-14T17:00:00Z",
    "deadline_at": "2026-09-14T17:05:00Z",
    "timing": {
      "server_now": "2026-09-14T17:00:00Z",
      "mode": "synchronized",
      "remaining_seconds": 300
    },
    "questions": []
  },
  "message": "Blitz attempt started successfully."
}
```

For resume:

```text
200 OK
message = Blitz attempt resumed successfully.
```

For new Attempt:

```text
201 Created
message = Blitz attempt started successfully.
```

The response contains no:

- score;
- checking state;
- Teacher/internal IDs;
- correct-answer configuration;
- answer rows in BE-005.

BE-006 may extend the same canonical Attempt projection with saved answer states once Blitz answer mutation exists, without changing Start identity/timing semantics.

---

# 34. Start Resource Timing Instant

For a new Attempt, the response uses:

```text
server_now = startedAt
```

for deterministic first projection. `startedAt` is already canonical
whole-second UTC.

For Resume, after required locks capture:

```text
resumedAt = truncate_to_utc_second(server_now)
```

and use that same whole-second instant only for response timing.

Do not persist `resumedAt`.

Do not change Attempt timestamps.

---

# 35. Durable Start / Resume Idempotency

Use:

```text
IdempotencyGuard
```

inside the same DB transaction as the intent-specific Start/Resume decision.

## 35.1 Same key / same fingerprint

Return the previously completed logical Attempt.

No new Attempt.

No timer reset.

Preserve recorded original HTTP semantic status:

```text
201 created
or
200 same-path/resumed
```

## 35.2 Same key / different semantic request

The following are different fingerprints:

- different Blitz;
- `start_normal` vs `resume`;
- Resume with a different `attempt_id`;
- future `start_replacement` vs either BE-005 intent.

Return:

```text
409 idempotency_key_reused
```

No domain mutation.

## 35.3 New `start_normal` key while Attempt #1 is in progress

Return the same #1 with:

```text
200
```

and complete this new key to #1.

No timer reset.

## 35.4 New `resume` key

It is valid only for the exact requested own in-progress Attempt ID.

It must never fall through to normal Start or future replacement creation.

## 35.5 New key after Attempt #1 terminal

Until BE-009:

```text
start_normal -> 409 attempts_exhausted
resume #1   -> 409 attempt_not_editable
```

No successful new claim remains.

## 35.6 Replay after Attempt later becomes terminal

A completed key remains replayable for its original semantic request.

Return the referenced own Attempt as the same logical result.

The replay must not:

- reopen;
- extend deadline;
- create new Attempt;
- change intent;
- switch to a different Attempt ID.

The response may reflect the referenced Attempt's current terminal status if the
canonical projection supports it later.

In BE-005 tests, replay of an in-progress Attempt is sufficient; later tasks add
terminal replay regression.

---

# 36. Replay Validation

Completed Start idempotency record must have:

```text
result_resource_type = assessment_attempt
result_resource_id = valid UUID
response_status in (200, 201)
```

The referenced Attempt must still be:

```text
same Institution
same authenticated Student
same Blitz Assessment
same recipient graph
```

Invalid completed metadata:

```text
LogicException
```

Do not treat corrupted idempotency data as a new Start.

---

# 37. Error Contract

Add Student Blitz errors through existing API error infrastructure.

## 37.1 `blitz_not_active`

HTTP:

```text
409
```

Code:

```text
blitz_not_active
```

Message:

```text
This Blitz is not active.
```

## 37.2 `blitz_time_expired`

HTTP:

```text
409
```

Code:

```text
blitz_time_expired
```

Message:

```text
The Blitz time has expired.
```

## 37.3 Assignment

Unassigned/private direct ID:

```text
404 resource_not_found
```

For Start where an already privacy-authorized graph loses its recipient under lock, use stable:

```text
409 assessment_not_assigned
```

with Blitz-appropriate message.

Do not expose recipient existence across Tenants.

## 37.4 Attempts exhausted

Use existing machine code:

```text
attempts_exhausted
```

with Blitz-specific human message:

```text
No Blitz attempts remain.
```

Do not change the existing Homework error message globally if that would break accepted tests.

A focused `StudentBlitzAttemptsExhaustedException` may map to the same machine code.

## 37.5 Resume target no longer editable

Reuse existing stable machine code:

```text
attempt_not_editable
```

with Blitz-specific human message:

```text
This Blitz attempt is no longer editable.
```

Use it when the requested own Resume `attempt_id` exists but is already terminal
or otherwise no longer resumable after locked state validation.

Do not use it to hide malformed persistence corruption.

A focused `StudentBlitzAttemptNotEditableException` may map to the existing
machine code without changing Homework copy.

---

# 38. Controller Boundary

Create:

```text
StudentBlitzController
StudentBlitzAttemptController
```

or equivalent focused controllers.

## `StudentBlitzController`

Methods:

```text
active
show
```

## `StudentBlitzAttemptController`

Method:

```text
store
```

Controllers only:

- receive validated request;
- get authenticated Student;
- call Action;
- return Resource.

No business queries/timer decisions in Controller.

---

# 39. Required Actions

Create focused Actions:

```text
ListStudentActiveBlitz
ShowStudentBlitz
StartStudentBlitzAttempt
ShowStudentBlitzAttempt
```

`ShowStudentBlitzAttempt` is an internal Action/projection loader for Start/Resume response.

It is **not** a new public generic Attempt endpoint in this task.

Do not create one broad `StudentBlitzService`.

---

# 40. Required Requests

Create:

```text
StudentBlitzActiveRequest
StudentBlitzShowRequest
StudentBlitzAttemptStartRequest
```

The Start request must implement the exact intent-dependent body contract in
Section 15 and reuse only the truly shared Idempotency-Key / strict-query
mechanics from Student Homework where practical.

Do **not** reuse an empty-body base that would erase the Blitz-specific semantic
request body.

A focused shared request concern/base may cover only:

```text
required UUID Idempotency-Key
no query
strict JSON object/content-type mechanics
```

while Blitz owns validation of:

```text
intent
attempt_id
```

Do not alter Homework Start request semantics.

---

# 41. Required Resources

Create:

```text
StudentBlitzSummaryResource
StudentBlitzResource
StudentBlitzCollection
StudentBlitzAttemptResource
```

`StudentBlitzCollection` is a plain non-paginated collection wrapper.

Resources perform no hidden queries.

Resources consume preloaded/projected server state.

---

# 42. Read Query Performance

## Active list

Use one server-side eligible query plus bounded eager loading.

Avoid per-row Attempt queries.

Prefer eager-loaded own Attempt #1 relation/query scope.

No N+1 across:

- Topic;
- BlitzTask;
- own Attempt.

## Detail

Load only:

- Topic summary;
- BlitzTask;
- own recipient;
- own normal Attempt history.

Do not load Questions.

## Start response

Load Questions once after Start/resume decision.

Do not reload full Teacher configuration through N+1 relations.

---

# 43. Read-Time Attempt Integrity

Student Blitz list/detail projections must not silently normalize corrupt Attempt history.

If loaded own history violates BE-005 expectations:

```text
LogicException
```

rather than:

- hiding duplicate Attempt;
- choosing arbitrary Attempt;
- inventing remaining capacity.

This is an internal integrity failure, not a Student action conflict.

BE-009 later updates this invariant to allow valid Attempt #2.

---

# 44. Security / Tenant Isolation

Student endpoints require:

```text
authenticated active Student
same Institution
own persisted recipient
own Attempts only
```

Do not authorize from current Group membership.

Do not expose:

- unassigned Blitz;
- another Student's Attempt;
- another Institution;
- another recipient row;
- Teacher correct-answer config.

A valid UUID never grants access.

---

# 45. Active List vs Detail Privacy Semantics

## Active list

Simply omits ineligible/private tasks.

## Detail

- no own recipient -> `404`;
- own recipient + lifecycle inactive -> `409 blitz_not_active`;
- own recipient + active but execution deadline reached -> `409 blitz_time_expired`;
- own recipient + active terminal Attempt #1 -> `200` metadata showing normal attempt used, unless timing itself is expired.

This distinction lets UI show a completed in-class Blitz if reached directly without making it startable.

---

# 46. Start vs Activation Race

Student Start must be safe when a selected-Student recipient existed before activation and requests race.

Use shared parent locks:

## Start obtains task lock while still Draft/Scheduled

Start re-reads:

```text
not active
```

and returns:

```text
409 blitz_not_active
```

No Attempt.

## Activation commits first

Start later re-reads:

```text
active
timer snapshot present
```

and may proceed.

No Student Attempt may use:

- null timer snapshot;
- stale duration;
- preactivation state.

---

# 47. Start vs Teacher Close Future Compatibility

Teacher Close is implemented later, but Start lock order must be compatible.

Required invariant for BE-007:

- Close and Start both lock Topic/Assessment/BlitzTask before Attempt decision.
- If Close commits first:
  ```text
  Start sees closed -> blitz_not_active
  ```
- If Start commits first:
  ```text
  Close later sees/finalizes that Attempt
  ```

Do not create an independent lock order that would make this impossible.

---

# 48. Start vs Result-Pair Mutation

Official Blitz cannot be replaced after BE-004 activation.

Start still locks the pair before setting first-activity lock.

Required:

- pair identity cannot change during Start;
- first official Start cannot lock a different candidate than the active Blitz;
- pair lock/Attempt creation commit atomically.

---

# 49. Concurrent Starts — Same Key

Two same-key concurrent normal Starts must create at most one Attempt.

After serialization:

- one Attempt #1;
- one recipient;
- one deadline;
- one completed idempotency record for the key;
- both callers receive same logical result.

Do not rely only on application pre-check.

Existing DB uniqueness is a backstop, not the complete algorithm.

---

# 50. Concurrent Starts — Different Keys

Two different keys for the same Student/Blitz race.

Required final outcome:

```text
exactly one Attempt #1
```

The request that observes the created in-progress Attempt resumes it.

Possible logical results:

```text
one 201
one 200
```

Each key may complete to the same Attempt with its own response status.

Attempt number cannot duplicate/skip.

Deadline cannot differ.

For individual mode, the winning creation's `started_at/deadline_at` is authoritative; the resume does not recalculate.

---

# 51. Concurrent First Official Starts by Different Students

For an official Blitz with:

```text
pair.locked_at = null
```

two Students may start concurrently.

Required:

- pair locks serialize;
- one winning first Start sets:
  ```text
  pair.locked_at = that Attempt.started_at
  ```
- later Student preserves that lock;
- both Attempts may validly exist;
- pair lock timestamp is not overwritten by the second;
- official identity/cohort remain unchanged.

No duplicate pair row.

---

# 52. Server-Authoritative Device Clock Resistance

No request field may contain:

```text
started_at
deadline_at
remaining_seconds
client_time
timezone
```

Start/Resume request accepts only the explicit semantic `intent` contract and
optional Resume `attempt_id`; timer/client-clock fields remain forbidden.

Read/Start always use backend time.

Tests must demonstrate that changing arbitrary client Date/time headers or payload attempts cannot:

- extend synchronized end;
- alter individual duration;
- reset Resume deadline.

Ignore/forbid unsupported fields rather than trusting them.

---

# 53. Expected File Scope

Exact filenames may follow repository conventions.

## Create likely

```text
backend/app/Actions/Student/ListStudentActiveBlitz.php
backend/app/Actions/Student/ShowStudentBlitz.php
backend/app/Actions/Student/StartStudentBlitzAttempt.php
backend/app/Actions/Student/ShowStudentBlitzAttempt.php

backend/app/Support/Student/StudentBlitzAccess.php
backend/app/Support/Student/StudentBlitzAttemptAccess.php
backend/app/Support/Student/StudentBlitzTiming.php
backend/app/Support/Student/StudentBlitzAttemptSummary.php
backend/app/Support/Student/StudentBlitzAttemptStartResult.php

backend/app/Http/Controllers/Api/V1/Student/StudentBlitzController.php
backend/app/Http/Controllers/Api/V1/Student/StudentBlitzAttemptController.php

backend/app/Http/Requests/Student/StudentBlitzActiveRequest.php
backend/app/Http/Requests/Student/StudentBlitzShowRequest.php
backend/app/Http/Requests/Student/StudentBlitzAttemptStartRequest.php

backend/app/Http/Resources/Student/StudentBlitzSummaryResource.php
backend/app/Http/Resources/Student/StudentBlitzResource.php
backend/app/Http/Resources/Student/StudentBlitzCollection.php
backend/app/Http/Resources/Student/StudentBlitzAttemptResource.php

backend/app/Exceptions/Student/StudentBlitzNotActiveException.php
backend/app/Exceptions/Student/StudentBlitzTimeExpiredException.php
backend/app/Exceptions/Student/StudentBlitzAttemptsExhaustedException.php
backend/app/Exceptions/Student/StudentBlitzAttemptNotEditableException.php
```

## Modify narrowly

```text
backend/routes/api.php
backend/app/Enums/IdempotencyOperation.php
backend/app/Support/ApiErrorResponse.php
backend/bootstrap/app.php

backend/app/Actions/Student/StartStudentHomeworkAttempt.php
backend/app/Support/Student/StudentHomeworkAttemptAccess.php
```

The last two files are allowed **only** for Section 30.5 pair-wide activity
compatibility. Do not change the Homework endpoint, request payload,
idempotency, deadline, three-attempt policy, response, authorization, or answer
behavior.

Focused existing Homework tests may be modified only to encode this approved
compatibility, primarily:

```text
backend/tests/Feature/Student/StudentHomeworkAttemptStartApiTest.php
backend/tests/Feature/Student/StudentHomeworkAttemptStartConcurrencyTest.php
```

Optional narrow shared request extraction may modify:

```text
StudentHomeworkAttemptStartRequest
```

only with exact Homework request behavior preserved.

No migration.

No Teacher Blitz behavior change.

No frontend/docs/tasks.

---

# 54. Active List Tests

Create focused file such as:

```text
StudentBlitzReadApiTest.php
```

Cover:

- active assigned synchronized Blitz before end appears;
- active assigned individual Blitz before Start appears;
- valid in-progress synchronized Attempt appears while deadline future;
- valid in-progress individual Attempt appears while deadline future;
- synchronized expired Blitz omitted;
- individual expired in-progress Blitz omitted;
- terminal normal Attempt omitted;
- Draft/Scheduled/Closed/Archived omitted;
- unassigned omitted;
- cross-Tenant omitted;
- another Student recipient omitted;
- deterministic ordering;
- plain collection shape;
- no Questions in list;
- no request body/query accepted;
- no N+1 regression using repository query-count style if practical;
- raw request clock `12:00:00.500000Z` projects canonical `server_now=12:00:00Z`;
- no successful timing timestamp contains a fractional-second wire component.

---

# 55. Detail Tests

Cover:

- synchronized active detail timing;
- individual before-Start timing null deadline/remaining;
- individual in-progress detail uses persisted deadline;
- terminal Attempt #1 detail exposes normal_used=1;
- no Questions in detail;
- no correct config;
- unassigned/foreign/malformed -> 404;
- assigned Draft/Scheduled/Closed/Archived -> blitz_not_active;
- synchronized active but expired -> blitz_time_expired;
- individual in-progress expired -> blitz_time_expired;
- no body/query accepted;
- fractional raw clock is truncated before `server_now`/remaining calculation;
- persisted fractional Stage 8 Blitz timer fixture is rejected as timing-integrity failure rather than inconsistently rounded.

Mandatory security test:

> An individual-mode Student must not obtain Question prompt/options through Detail before Start.

---

# 56. Start Normal Synchronized Tests

Cover:

- new Attempt #1 -> 201;
- exact `started_at`;
- exact common `deadline_at`;
- late opener gets reduced remaining time;
- no Attempt at exact common end;
- after common end -> blitz_time_expired;
- no idempotency row committed on failed Start;
- no Answer rows fabricated;
- Student-safe Questions returned after success;
- no correct-answer configuration;
- raw Start at `12:00:00.500000Z` persists `started_at=12:00:00Z`;
- at raw `deadline - 1 microsecond`, normalized decision instant is still the prior second and the request remains pre-deadline;
- at raw `deadline + 1 microsecond`, normalized decision instant equals/passes the whole-second deadline and the request is expired.

---

# 57. Start Normal Individual Tests

Cover:

- new Attempt #1 -> 201;
- `deadline_at = started_at + duration_seconds`;
- exact full remaining duration at frozen start time;
- activation age does not shorten duration;
- synchronized end is not used;
- no client time affects deadline;
- raw Start at `12:00:00.500000Z` persists `started_at=12:00:00Z`, `deadline_at=12:10:00Z`, and first `remaining_seconds=600` for duration 600;
- persisted `started_at/deadline_at` have zero microseconds.

---

# 58. Explicit Start / Resume Intent Tests

For both timer modes:

## `start_normal`

- exact body `{"intent":"start_normal"}`;
- no #1 -> 201 new #1;
- #1 already in-progress -> 200 same #1;
- terminal #1 -> attempts_exhausted;
- no timer reset;
- never creates #2.

## `resume`

- exact body contains `intent=resume` + exact own `attempt_id`;
- in-progress #1 -> 200 same requested Attempt ID;
- same `started_at`;
- same `deadline_at`;
- no second Attempt;
- no timer reset;
- response remaining based on current server time;
- expired in-progress -> blitz_time_expired;
- terminal own #1 -> attempt_not_editable;
- foreign/other-Student/other-Blitz Attempt ID -> resource_not_found;
- no Attempt is ever created by Resume;
- BE-005 performs no timeout finalization.

## Stale Resume safety

Prove that if locked state changes after detail was read:

```text
Resume #1 request
+
#1 becomes terminal
```

the Resume returns a deterministic conflict and creates zero new Attempts.

BE-009 must preserve this guarantee when replacement capacity later exists.

---

# 59. Idempotency Tests

Create focused:

```text
StudentBlitzAttemptStartIdempotencyTest.php
```

Cover:

- operation value exact;
- same key/same `start_normal` replay;
- same key/same Resume `attempt_id` replay;
- same key/different Blitz -> idempotency_key_reused;
- same key/different intent -> idempotency_key_reused;
- same key/Resume different `attempt_id` -> idempotency_key_reused;
- different `start_normal` key while #1 in-progress -> 200 same Attempt;
- different Resume key for same exact in-progress #1 -> 200 same Attempt;
- failed lifecycle/timing/intent decision leaves no claim;
- replay does not reset deadline;
- concurrent same-key;
- concurrent different-key;
- result metadata:
  ```text
  assessment_attempt
  Attempt UUID
  200|201
  ```
- authorization required before replay;
- foreign Student cannot replay another Student's key/resource.

Run existing Homework idempotency regression.

---

# 60. Official Pair Start Tests

Create focused:

```text
StudentOfficialBlitzAttemptStartTest.php
```

Cover:

## First Blitz activity, pair unlocked

- pair has official Homework + Blitz;
- cohort snapshotted;
- Student is group recipient;
- no official Homework/Blitz Attempts;
- Start #1 succeeds;
- `pair.locked_at = Attempt.started_at`;
- `pair.updated_at` same instant;
- IDs/cohort unchanged.

## Pair already locked by Homework

- Homework Attempt exists;
- pair locked historically;
- Blitz no Attempts;
- Blitz Start succeeds;
- pair lock unchanged.

## Corrupt unlocked pair with prior official activity

- official Homework Attempt exists;
- pair lock null;
- Blitz Start rejects business_conflict;
- no repair/no Blitz Attempt.

## Corrupt locked pair with no activity anywhere

- pair lock non-null;
- no Homework/Blitz Attempts;
- Start rejects business_conflict.

## Wrong official recipient shape

- direct source or missing cohort;
- business_conflict;
- no Attempt.

## Practice Blitz

- Start does not mutate pair.

---

# 61. Concurrency Tests

Create focused:

```text
StudentBlitzAttemptStartConcurrencyTest.php
```

Minimum:

1. same Student, same Blitz, same `start_normal` key;
2. same Student, same Blitz, different `start_normal` keys;
3. concurrent Resume requests for the same explicit Attempt ID;
4. Resume racing terminalization of that exact Attempt;
5. two Students first-starting one unlocked official Blitz pair;
6. Start racing a controlled lifecycle transition to Closed-compatible state if BE-007 public Close does not yet exist.

For #4, use controlled DB transaction with the same parent lock order; do not implement public Teacher Close.

Required final states must always satisfy:

- max one in-progress Attempt per Student/Assessment;
- normal Attempt number = 1;
- one deadline;
- no pair lock overwrite;
- no Attempt created after closed lifecycle wins.

---

# 62. Direct BE-004 Regression

Run delivered activation/cohort tests relevant to the Student Start dependency:

```text
TeacherBlitzActivationApiTest
TeacherBlitzOfficialCohortActivationTest
TeacherBlitzActivationIdempotencyTest
```

No need to rerun all BE-004 designation tests unless Start implementation changes shared pair access.

If it does, run the directly affected result-pair tests and report why.

---

# 63. Student Homework Compatibility and Regression

Because this task deliberately makes the narrow Section 30.5 compatibility
change, extend the existing Homework Start coverage without weakening any Stage
7 assertion.

Required new focused cases in the current equivalent of
`StudentHomeworkAttemptStartApiTest.php`:

## 63.1 Valid Blitz-first lock

Construct a valid official pair where:

```text
official cohort is established
real official Blitz Attempt exists
pair.locked_at != null
Homework Attempts = empty
```

Then first Homework Start must:

```text
201 Created
Homework attempt_number = 1
pair.locked_at unchanged
pair.updated_at unchanged
Blitz Attempt unchanged
```

Blitz history must not count toward Homework capacity.

## 63.2 Pair/activity corruption remains rejected

Cover:

```text
locked pair + zero Attempts on both official Assessments
```

and:

```text
unlocked pair + existing official Blitz Attempt
```

Both must return the existing official-pair business conflict with:

- zero new Homework Attempt;
- zero pair repair;
- no successful new idempotency claim.

## 63.3 Concurrency compatibility

Use the existing PostgreSQL concurrency pattern to cover the directly affected
official-pair Start boundary when practical. At minimum preserve:

- pair lock written at most once;
- no lock timestamp overwrite;
- Homework Attempt numbering remains independent of Blitz Attempts;
- no deadlock.

Run:

```bash
php artisan test \
  tests/Feature/Student/StudentHomeworkReadApiTest.php \
  tests/Feature/Student/StudentHomeworkAttemptStartApiTest.php \
  tests/Feature/Student/StudentHomeworkAttemptStartConcurrencyTest.php \
  tests/Feature/Student/StudentHomeworkAttemptIdempotencyTest.php
```

Preserve every other delivered Homework behavior exactly.

---

# 64. Verification Commands

Run from:

```text
backend/
```

## 64.1 Student Blitz read/start

```bash
php artisan test \
  tests/Feature/Student/StudentBlitzReadApiTest.php \
  tests/Feature/Student/StudentBlitzAttemptStartTest.php \
  tests/Feature/Student/StudentBlitzAttemptStartIdempotencyTest.php \
  tests/Feature/Student/StudentOfficialBlitzAttemptStartTest.php \
  tests/Feature/Student/StudentBlitzAttemptStartConcurrencyTest.php
```

## 64.2 Direct BE-004 regression

```bash
php artisan test \
  tests/Feature/Teacher/TeacherBlitzActivationApiTest.php \
  tests/Feature/Teacher/TeacherBlitzOfficialCohortActivationTest.php \
  tests/Feature/Teacher/TeacherBlitzActivationIdempotencyTest.php
```

## 64.3 Student Homework compatibility/regression

```bash
php artisan test \
  tests/Feature/Student/StudentHomeworkReadApiTest.php \
  tests/Feature/Student/StudentHomeworkAttemptStartApiTest.php \
  tests/Feature/Student/StudentHomeworkAttemptStartConcurrencyTest.php \
  tests/Feature/Student/StudentHomeworkAttemptIdempotencyTest.php
```

These exact files exist on the reviewed `main` baseline. If the implementation
baseline later renames them, use the delivered equivalent and report the exact
command.

## 64.4 Format

```bash
./vendor/bin/pint --test
```

No additional static-analysis command unless current repository configuration requires it for exactly this backend scope.

## 64.5 Always

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

# 65. Acceptance Criteria — Read

- [ ] Active-list endpoint exists exactly once.
- [ ] Detail endpoint exists exactly once.
- [ ] Student visibility is recipient-based, not current-membership-based.
- [ ] Active list contains only currently startable/resumable normal Attempt #1 tasks.
- [ ] Synchronized expired tasks are omitted.
- [ ] Individual expired in-progress tasks are omitted.
- [ ] Terminal normal Attempt tasks are omitted until BE-009 replacement support.
- [ ] Detail is 404 for unassigned/private IDs.
- [ ] Detail returns blitz_not_active for assigned inactive lifecycle.
- [ ] Detail returns blitz_time_expired for active expired execution window.
- [ ] Detail never exposes Questions.
- [ ] List never exposes Questions.
- [ ] Timing uses backend server time normalized to UTC whole seconds.
- [ ] Wire timer timestamps are canonical `YYYY-MM-DDTHH:MM:SSZ` with no fraction.
- [ ] `remaining_seconds` is the exact non-negative integer difference of the serialized whole-second deadline and `server_now`.
- [ ] No N+1 obvious regression.

---

# 66. Acceptance Criteria — Start/Resume

- [ ] Required Idempotency-Key.
- [ ] Request body carries exact explicit `intent`.
- [ ] `start_normal` accepts no `attempt_id`.
- [ ] `resume` requires exact canonical own `attempt_id`.
- [ ] Empty/{} body is rejected.
- [ ] Fingerprint includes `intent` and Resume `attempt_id`.
- [ ] Exactly normal Attempt #1 is implemented.
- [ ] No Attempt #2/#3 creation.
- [ ] New synchronized `start_normal` uses shared common end.
- [ ] Late synchronized Start receives remaining time only.
- [ ] Start at/after common end creates no Attempt.
- [ ] New individual Start gets full configured duration.
- [ ] Resume returns only the exact requested Attempt.
- [ ] Resume never creates or switches Attempts.
- [ ] Resume never resets started_at/deadline_at.
- [ ] Expired Resume returns blitz_time_expired.
- [ ] Terminal own Resume target returns attempt_not_editable.
- [ ] BE-005 does not timeout-finalize.
- [ ] Terminal #1 `start_normal` returns attempts_exhausted.
- [ ] Stale Resume cannot become future replacement Start.
- [ ] No answer rows fabricated.
- [ ] Questions become visible only after successful Start/Resume.
- [ ] Student Question payload leaks no answer key.
- [ ] Fractional raw server instants are truncated before timer comparison/arithmetic/persistence.
- [ ] New Blitz Attempt `started_at/deadline_at` persist with zero fractional seconds.

---

# 67. Acceptance Criteria — Official Pair

- [ ] Practice Blitz Start never mutates pair.
- [ ] Official Blitz requires group recipient/cohort.
- [ ] First official activity can lock previously-unlocked pair.
- [ ] Exact Attempt.started_at is pair lock timestamp.
- [ ] Existing Homework-origin pair lock is preserved.
- [ ] Existing Homework Start evaluates pair activity across both official Assessments, not Homework Attempts alone.
- [ ] Valid Blitz-origin lock + zero Homework Attempts allows first Homework Attempt #1 and preserves pair timestamps.
- [ ] Blitz Attempts never count toward Homework numbering or three-attempt capacity.
- [ ] Locked pair with zero official activity is treated as corrupt.
- [ ] Unlocked pair with prior official activity is not silently repaired.
- [ ] Official IDs/cohort never change on either Start path.

---

# 68. Acceptance Criteria — Idempotency/Concurrency

- [ ] `student.blitz.attempt.start` operation exact.
- [ ] Same-key replay returns the same intent-specific logical Attempt.
- [ ] Different intent/Resume target changes fingerprint and reuse is rejected.
- [ ] New `start_normal` key may safely return existing #1.
- [ ] New `resume` key may return only its exact requested in-progress Attempt.
- [ ] Failed Start leaves no successful claim.
- [ ] Same-key concurrent Start creates at most one Attempt.
- [ ] Different-key concurrent Start creates exactly one Attempt #1 and one deadline.
- [ ] Concurrent first official Starts set pair lock once.
- [ ] Device clock cannot affect eligibility/deadline.

---

# 69. Scope Acceptance

- [ ] Existing Homework changes are limited to Section 30.5 pair-wide activity compatibility.
- [ ] Homework endpoint/request/idempotency/deadline/three-attempt/resource behavior is otherwise unchanged.
- [ ] No migration.
- [ ] No answer mutation.
- [ ] No file mutation.
- [ ] No Submit.
- [ ] No timeout finalizer.
- [ ] No Scheduler.
- [ ] No Teacher Close.
- [ ] No exception grant/replacement Attempt.
- [ ] No monitoring.
- [ ] No scoring/checking.
- [ ] No frontend/docs/task changes.
- [ ] Focused tests pass.
- [ ] Direct BE-004 regressions pass.
- [ ] Homework regressions pass.
- [ ] Pint passes.
- [ ] `git diff --check` passes.

---

# 70. Focused Diff Self-Check

Before completion confirm:

```text
Student active Blitz read + explicit-intent normal Attempt #1 Start/Resume
+ narrow existing Homework pair-lock compatibility only
```

Verify specifically:

```text
Questions hidden before Start
start_normal and resume are distinct semantic requests
resume is bound to one exact Attempt ID and never creates/switches Attempts
synchronized deadline = common end
individual deadline = Student Start + duration
resume never resets timer
no timeout finalization
no Attempt #2
official pair locks only on first official activity
Blitz-origin pair lock does not block first Homework Start
Homework and Blitz Attempt histories/capacities remain separate
pair lock/activity corruption is still rejected without repair
```

Confirm the existing Homework Start diff is limited to pair-wide official
activity compatibility and no unrelated refactor.

---

# 71. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. Student endpoint list;
4. Active-list eligibility rules;
5. Detail Question-secrecy behavior;
6. timing projection rules;
7. synchronized Start behavior;
8. individual Start behavior;
9. explicit intent request contract;
10. exact-attempt Resume behavior and stale-Resume safety;
11. official first-activity pair lock behavior;
12. existing Homework Start Blitz-first compatibility behavior;
13. Start/Resume idempotency operation/fingerprint/result metadata;
14. concurrency behavior;
15. Student-safe Question projection;
16. focused Blitz test results;
17. BE-004 regression results;
18. Homework compatibility/regression results;
19. Pint result;
20. `git diff --check`;
21. final `git status --short`;
22. focused scope/diff self-check;
23. any blocker/deviation.

Do not claim Stage 8 backend complete.

After delivery ChatGPT performs read-only acceptance review.

`S08-BE-006` remains blocked until:

```text
S08-BE-005 = Accepted / Delivered
```

---

# 72. Implementation Readiness Verdict

```text
Scope / non-goals                   = RESOLVED
Student endpoints                   = RESOLVED
Recipient privacy                   = RESOLVED
Active-list eligibility             = RESOLVED
Detail visibility                   = RESOLVED
Pre-Start Question secrecy          = RESOLVED
Timing projection                   = RESOLVED
Normal Attempt #1 rule              = RESOLVED
Synchronized Start/deadline         = RESOLVED
Individual Start/deadline           = RESOLVED
Explicit Start/Resume intent         = RESOLVED
Resume exact-attempt binding         = RESOLVED
Stale Resume / replacement boundary  = RESOLVED
Late Start/Resume behavior           = RESOLVED
Timeout-engine boundary             = RESOLVED
Official first-activity pair lock   = RESOLVED
Homework Start Blitz-first compat.  = RESOLVED
Idempotency operation/fingerprint   = RESOLVED
Replay/new-key behavior             = RESOLVED
Question safe projection            = RESOLVED
Authorization/Tenant isolation      = RESOLVED
Concurrency/lock compatibility      = RESOLVED
Error behavior                      = RESOLVED
Acceptance criteria                 = RESOLVED
Focused verification                = RESOLVED

Implementation Readiness Gate       = PASS
Execution dependency                = S08-BE-004 Accepted / Delivered
```
