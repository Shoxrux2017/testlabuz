# Codex Implementation Contract: S08-BE-010 — Teacher Blitz Monitoring API

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-BE-010` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel live Teacher Blitz monitoring projection with timeout reconciliation and exception-aware Student operational state` |
| Depends on | `S08-DOC-001`, `S08-BE-001…009` — all `Accepted / Delivered` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` after dependencies are delivered and immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |
| Backend block checkpoint | `Stage 8 Backend Phase 2` immediately after this task is `Accepted / Delivered` |
| Blocks | `S08-BE-PHASE-2` |

Start only when:

```text
S08-DOC-001 = Accepted / Delivered
S08-BE-001…009 = Accepted / Delivered
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
4. delivered S08-BE-001…009 source/tests directly required by this task;
5. current Teacher Blitz access/resource/controller code;
6. current Blitz timeout reconciliation support;
7. current Blitz Attempt/exception history validation and Student projection support;
8. current Teacher Group Student read conventions only where needed for safe Student identity projection.

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

- exact monitoring endpoint;
- lifecycle availability;
- authorization/Tenant scope;
- timeout reconciliation before projection;
- assigned Student roster authority;
- Student operational status state machine;
- exception-aware current Attempt selection;
- summary count semantics;
- timing/remaining-seconds semantics;
- Teacher-visible exception metadata;
- no-score/no-answer-content boundary;
- deterministic ordering;
- concurrency/read consistency;
- query/N+1 requirements;
- acceptance criteria;
- focused verification.

If delivered dependencies materially conflict with this contract, return:

```text
BLOCKED
```

with exact evidence.

Do not redesign Blitz execution, exception, scoring, or result behavior.

---

# 3. Goal

Provide the authorized Teacher with one operational live view of an **active** Blitz.

The monitoring response must answer:

```text
How much class-wide time remains?
How many Students are assigned?
Who has not started the currently available path?
Who is in progress?
Who is already execution-finalized?
Who is waiting for Teacher review if a later checking stage has produced that state?
Which Students have a granted exception?
Which Attempt (#1 or #2) is the Student currently using?
What authoritative deadline/remaining time applies to that current Attempt?
```

The endpoint is for observation only.

It must never allow the Teacher to:

- answer on behalf of a Student;
- edit Student answers/files;
- submit a Student Attempt;
- alter scores;
- grant/revoke an exception through the monitoring GET itself;
- change task lifecycle.

The only allowed state mutation caused by monitoring is automatic authoritative **timeout reconciliation** through the already-delivered BE-007 engine.

---

# 4. Public Endpoint

Add exactly:

```text
GET /api/v1/teacher/blitz/{blitz}/monitoring
```

inside the existing Teacher middleware group:

```text
auth:sanctum
active.account
password.changed
role:teacher
```

No alias.

Do not add:

```text
/monitor
/live
/students/status
```

endpoints.

---

# 5. Request Contract

Monitoring accepts:

```text
no request body
no query parameters
```

Any body or query key:

```text
422 validation_failed
```

Create a focused request such as:

```text
TeacherBlitzMonitoringRequest
```

or reuse an exact existing strict empty-read request convention if already delivered and semantically appropriate.

No pagination/filter/sort input is accepted.

The assigned class roster is returned as one operational collection.

---

# 6. Explicit Non-Goals

Do not implement:

- answer checking;
- Teacher manual review;
- awarded points;
- Attempt score;
- official Blitz score;
- Topic result;
- result release;
- submission queue;
- Teacher answer/file download expansion;
- exception grant mutation in this GET;
- exception edit/revoke;
- Blitz activation/close mutation;
- Student Start/Submit mutation;
- Student answer/file mutation;
- WebSocket/SSE/push;
- background subscription;
- pagination;
- frontend;
- E2E harness/seed data;
- schema/migrations;
- dependencies;
- docs/tasks.

Do not create a live socket infrastructure.

Frontend polling may call this normal GET later.

---

# 7. Authorization

Resolve `{blitz}` through the delivered Teacher Blitz access boundary.

Require:

```text
same Institution
Assessment.type = blitz
teacher_id = authenticated Teacher
owning Topic remains within Teacher read scope
current Teacher–Group membership exists
BlitzTask exists
```

Malformed UUID, foreign Institution, another Teacher's Blitz, ended Teacher membership, or structurally missing BlitzTask:

```text
404 resource_not_found
```

Do not reveal private UUID existence.

---

# 8. Monitoring Lifecycle

This endpoint is a **live active-Blitz** endpoint.

## Active

Allowed.

## Draft / Scheduled

Return:

```text
409 task_not_active
```

## Closed

Return:

```text
409 task_closed
```

## Archived

Return:

```text
409 task_archived
```

Do not turn monitoring into a historical result/submission endpoint.

After Teacher Close, the Close response already returns the Teacher Blitz resource; later historical results belong to later result/review functionality.

---

# 9. Active After Timer End Is Still Monitorable

An active synchronized Blitz may remain:

```text
status = active
```

after:

```text
server_now >= synchronized_ends_at
```

until the Teacher explicitly closes it.

Monitoring must still succeed while task status remains `active`.

In that case:

- class synchronized remaining time is effectively zero;
- BE-007 reconciliation has frozen every due existing in-progress Attempt;
- never-started Students remain `not_started`;
- no new normal synchronized Attempt is startable;
- an unused granted replacement exception may still be startable under BE-009 rules.

Do not auto-close the Blitz.

---

# 10. Automatic Timeout Reconciliation and Snapshot Stabilization

Monitoring must never return:

```text
in_progress
```

for an Attempt that is already due at the **response snapshot boundary**.

It also must never build one response from table reads that belong to different
committed database states.

Use this exact high-level protocol:

```text
preliminary privacy-safe authorization
↓
BE-007 timeout reconciliation
↓
open one PostgreSQL REPEATABLE READ READ ONLY final-read transaction
↓
first statement establishes the MVCC snapshot and captures snapshotAt
↓
final authorization/lifecycle read inside that snapshot
↓
recipients + Users + Attempts + Exceptions inside the same snapshot
↓
validate/project
```

## 10.1 Preliminary authorization

Resolve enough Teacher/Blitz identity to perform the normal privacy-safe
authorization and decide whether timeout reconciliation may be relevant.

Do not use models/relationships loaded during this preliminary phase as the final
monitoring graph.

## 10.2 Reconcile before final snapshot

If the preliminary task is active, invoke the delivered:

```text
FinalizeTimedOutBlitzAttempts(
  teacher.institution_id,
  blitzAssessmentId
)
```

using its normal BE-007 contract.

Monitoring does **not** require BE-007 to expose its internal `observedAt`.

## 10.3 Final consistent snapshot

After reconciliation completes, start one explicit PostgreSQL:

```text
ISOLATION LEVEL REPEATABLE READ
READ ONLY
```

transaction on one database connection.

Before any table read, the first SQL statement must establish that transaction's
MVCC snapshot and capture one database-server authoritative instant:

```text
snapshotAt
```

Use one PostgreSQL statement equivalent to:

```sql
SELECT date_trunc('second', clock_timestamp()) AS snapshot_at
```

on the same connection as the subsequent monitoring reads.

The first statement both establishes the final MVCC snapshot and yields the
authoritative monitoring instant at the Stage 8 canonical precision:

```text
UTC whole seconds
```

This is truncation, never rounding upward.

Serialize `snapshotAt` exactly as:

```text
YYYY-MM-DDTHH:MM:SSZ
```

with no fractional component.

Then, inside that same transaction:

1. re-resolve/re-authorize the final Teacher/Topic/Assessment/BlitzTask state;
2. require the snapshot-visible Blitz lifecycle to be `active`;
3. load recipients;
4. load recipient Student Users;
5. load all relevant Blitz Attempts;
6. load all relevant Blitz Attempt Exceptions;
7. validate the complete graph;
8. derive the response rows/summary.

No graph SELECT may escape this transaction.

## 10.4 Deadline crossing between reconciliation and snapshot

A deadline may legitimately be crossed in the short interval between the
pre-snapshot reconciler and `snapshotAt`.

If the final consistent snapshot contains any current:

```text
status = in_progress
AND deadline_at <= snapshotAt
```

this is **not corruption** and must not produce `LogicException`.

Instead:

1. discard the read-only snapshot without returning it;
2. invoke `FinalizeTimedOutBlitzAttempts` again after the read transaction ends;
3. start a new `REPEATABLE READ READ ONLY` snapshot;
4. rebuild the response from the new snapshot.

Do not sleep between retries.

Each stabilization retry must be caused by an actually observed due
`in_progress` Attempt. The shared reconciler finalizes all currently due Attempts
for the Blitz, so the retry is progress-oriented rather than an arbitrary poll.

## 10.5 Close relative to the snapshot boundary

Close semantics are defined by the final MVCC snapshot, not by JSON
serialization completion:

```text
Close committed before snapshot boundary
=> final snapshot sees non-active Blitz
=> return the exact lifecycle conflict (normally 409 task_closed)

Close commits after snapshot boundary
=> it is not visible inside this response snapshot
=> returning the internally consistent pre-Close active snapshot is valid
```

The next monitoring request observes the later Close.

Do not mix a pre-Close parent row with post-Close Attempt/exception state.

Timeout reconciliation may finalize due Attempts for multiple Students in the same
Blitz aggregate.

This is authoritative maintenance, not a Teacher answer/result mutation.

---

# 11. No Other GET-Side Mutation

Monitoring must not write:

```text
BlitzTask lifecycle
Assessment
AssessmentStudent
TopicResultPair
BlitzAttemptException
non-due AssessmentAttempt
AttemptAnswer
AnswerFile
File
idempotency_records
```

It may write only through the existing due-Attempt timeout reconciler.

No `updated_at` is touched merely because monitoring was viewed.

---

# 12. Roster Authority

The monitoring roster is exactly the persisted:

```text
assessment_students
```

snapshot for this Blitz.

Do not rebuild from current Group membership.

Do not drop a recipient because the Student later:

- left the Group;
- became inactive;
- changed membership state.

The activation-time recipient snapshot remains the historical assignment authority.

Every persisted recipient contributes exactly one monitoring Student row.

---

# 13. Recipient / Student Integrity

For each recipient require a same-Institution Student User:

```text
assessment_students.institution_id = Blitz Institution
assessment_students.assessment_id = Blitz Assessment
User.id = assessment_students.student_id
User.institution_id = Blitz Institution
User.role = student
```

The User may now be inactive; monitoring still shows the assigned historical Student.

A missing/cross-Tenant/wrong-role User behind an existing recipient is structural corruption:

```text
LogicException
```

Do not silently reduce `assigned`.

---

# 14. Student Identity Projection

Expose exactly:

```json
{
  "student": {
    "id": "student-uuid",
    "full_name": "Student Name"
  }
}
```

Do not expose:

```text
login_name
email
phone
institution_id
is_active
membership rows
password/auth fields
```

Monitoring is classroom operational state, not a user-admin endpoint.

---

# 15. Attempt/Exception History Source

For every recipient, load:

```text
all Blitz AssessmentAttempts for that recipient/Student
optional BlitzAttemptException for that recipient/Student
```

Reuse the exact BE-009 Blitz history integrity/state-selection support where possible.

Do not independently invent a second #1/#2 validator.

If BE-009 delivered the history validator only inside Student access code, extract the minimal Assessment-domain or shared Blitz history projector and update the Student path to use it without behavior change.

Required valid histories remain:

```text
[]                                           // normal not started
[#1 in_progress]
[#1 terminal]
[#1 terminal/ineligible + unused exception]
[#1 terminal/ineligible + #2 in_progress + linked exception]
[#1 terminal/ineligible + #2 terminal + linked exception]
```

No #3.

Invalid graph:

```text
LogicException
```

Monitoring must not silently choose an arbitrary Attempt.

---

# 16. Operational Current Path

Monitoring status represents the Student's **current operational Blitz path**, not merely the latest historical row.

Determine the effective path as follows.

## No exception

Current path is:

```text
Attempt #1
```

when it exists.

If #1 does not exist:

```text
current Attempt = null
```

## Granted exception, replacement not started

Attempt #1 is historical invalidated work.

Current operational path is:

```text
replacement Attempt #2 not started
```

Therefore:

```text
current Attempt = null
```

The historical #1 remains referenced through:

```text
attempt_exception.invalidated_attempt_id
```

## Replacement started

Current path is:

```text
Attempt #2
```

whether in progress or terminal.

Do not continue projecting invalidated #1 as the Student's current status after a granted unused exception.

---

# 17. Monitoring Operational Status Values

Each Student row `status` is one of exactly:

```text
not_started
in_progress
finalized
waiting_for_teacher_review
```

Do not expose raw persistence status as this operational field.

---

# 18. `not_started`

Set:

```text
status = not_started
```

when the current operational path has no Attempt row.

This covers:

## Normal path

```text
no Attempt #1
no exception
```

## Replacement path

```text
valid exception exists
replacement_attempt_id = null
Attempt #2 does not exist
```

The second case intentionally means:

> The original invalidated #1 exists historically, but the currently available replacement path has not started.

---

# 19. `in_progress`

Set:

```text
status = in_progress
```

when the current effective Attempt is:

```text
AssessmentAttemptStatus::InProgress
```

In the stabilized final snapshot, an `in_progress` current Attempt must satisfy:

```text
snapshotAt < attempt.deadline_at
```

If:

```text
attempt.deadline_at <= snapshotAt
```

do **not** classify this ordinary clock-boundary race as structural corruption.

Trigger the Section 10.4 stabilization path:

```text
discard snapshot
→ reconcile
→ rebuild one new consistent snapshot
```

Only after a stabilized snapshot is obtained may a remaining impossible
`in_progress` finalization shape be treated as `LogicException`.

Do not display stale time and do not compare against a later per-row clock.

---

# 20. `waiting_for_teacher_review`

Set:

```text
status = waiting_for_teacher_review
```

when the current effective Attempt persistence status is:

```text
waiting_for_teacher_review
```

Stage 8 itself does not create this status through checking.

The mapping is retained because the shared Attempt enum already contains it and future Stage 9 may transition frozen work without requiring a redesign of monitoring.

`score` remains null in this Stage 8 endpoint.

---

# 21. `finalized`

Set:

```text
status = finalized
```

for any current effective terminal Attempt that is not currently waiting for Teacher review.

This includes Stage 8 execution-terminal states:

```text
submitted
timed_out_finalized
```

and forward-compatible:

```text
checked
```

Do not expose `checked` as a separate monitoring status in Stage 8.

The raw execution reason is still available through:

```text
finalization_reason
```

---

# 22. Summary Partition

The summary must contain exactly:

```json
{
  "assigned": 25,
  "not_started": 5,
  "in_progress": 8,
  "finalized": 10,
  "waiting_for_teacher_review": 2,
  "attempt_exceptions_granted": 1
}
```

Build these counts from the same in-memory Student monitoring rows used for the response.

Mandatory invariant:

```text
assigned
=
not_started
+ in_progress
+ finalized
+ waiting_for_teacher_review
```

Do not run independent aggregate queries whose result may drift from the returned rows.

`attempt_exceptions_granted` is an orthogonal count:

```text
number of assigned Students with one exception row
```

It is not part of the four-way status partition.

---

# 23. Current Attempt Number

Student row field:

```text
attempt_number
```

is:

```text
null
```

when current operational path is `not_started`.

Otherwise it is:

```text
1
or
2
```

for the current effective Attempt.

After exception grant but before replacement Start:

```text
attempt_number = null
```

Do not return historical invalidated #1 as current attempt number.

---

# 24. Attempt Timing Fields

Student row fields:

```text
started_at
deadline_at
remaining_seconds
```

follow the current operational path.

---

# 25. `started_at`

If current effective Attempt exists:

```text
started_at = Attempt.started_at
```

UTC RFC3339 `Z`.

If `not_started`:

```text
started_at = null
```

---

# 26. `deadline_at`

If current effective Attempt exists:

```text
deadline_at = Attempt.deadline_at
```

UTC RFC3339 `Z`.

If current path has not started:

```text
deadline_at = null
```

This is important for an unused replacement exception, including synchronized mode: replacement deadline does not exist until #2 starts.

---

# 27. `remaining_seconds` — In Progress

For an in-progress current Attempt:

```text
remaining_seconds
=
max(0, attempt.deadline_epoch_second - server_now_epoch_second)
```

where:

```text
server_now = snapshotAt
```

from the single stabilized final-read transaction.

After stabilization this must be positive for every `in_progress` row.

Use this one monitoring response instant for every row.

Do not capture a different clock instant per Student.

---

# 28. `remaining_seconds` — Terminal

For:

```text
finalized
waiting_for_teacher_review
```

return:

```text
remaining_seconds = 0
```

Do not report historical time-left-at-submit.

---

# 29. `remaining_seconds` — Normal Not Started

When:

```text
no #1
no exception
```

then:

## Synchronized

```text
remaining_seconds
=
max(0, synchronized_end_epoch_second - server_now_epoch_second)
```

This may be zero after the class common end.

## Individual

```text
remaining_seconds = null
```

because the Student timer has not started.

---

# 30. `remaining_seconds` — Replacement Not Started

When:

```text
exception exists
replacement_attempt_id = null
```

return:

```text
remaining_seconds = null
deadline_at = null
started_at = null
```

in **both** timer modes.

Reason:

> BE-009 replacement #2 receives its full duration from its own future server Start.

For synchronized mode, the historical common end must not be presented as the replacement's effective deadline.

---

# 31. Finalization Reason

Student row:

```text
finalization_reason
```

is:

- current effective Attempt's enum value when terminal;
- null for in-progress;
- null for current path not started.

Possible Stage 8 values include:

```text
student_submit
timeout_auto_submit
task_closed_auto_finalize
```

`homework_deadline_auto_submit` is invalid for Blitz Attempt history.

If encountered on a Blitz Attempt:

```text
LogicException
```

---

# 32. Teacher Monitoring Exception Object

Student row includes:

```text
attempt_exception
```

Either:

```text
null
```

or:

```json
{
  "id": "exception-uuid",
  "invalidated_attempt_id": "attempt-1-uuid",
  "replacement_attempt_id": null,
  "reason_type": "technical",
  "reason": "The Student's device lost connection.",
  "granted_at": "2026-09-14T19:00:00Z",
  "replacement_attempt_available": true
}
```

Do not duplicate:

```text
blitz_id
student_id
```

inside the nested object because the containing monitoring row already supplies both context dimensions.

Do not expose:

```text
institution_id
assessment_student_id
granted_by_user_id
created_at
updated_at
```

---

# 33. Monitoring Exception Availability Flag

Inside `attempt_exception`:

```text
replacement_attempt_available = true
```

only when:

```text
replacement_attempt_id = null
Blitz status = active
```

and history validates #1 as terminal/ineligible.

Because monitoring endpoint itself is active-only, a valid unused exception normally projects:

```text
true
```

If replacement #2 exists:

```text
false
```

Do not infer availability from class common synchronized end.

---

# 34. Score Field

Every Student monitoring row contains:

```json
"score": null
```

in Stage 8.

Do not read/serialize:

```text
earned_points
normalized_score
awarded_points
checking results
official_task_scores
Topic results
```

even if a fixture or later stage has populated them.

This endpoint is execution monitoring, not result exposure.

Stage 9 may explicitly revise/extend score projection later under its own contract.

---

# 35. Exact Student Row Shape

Return exactly:

```json
{
  "student": {
    "id": "student-uuid",
    "full_name": "Student Name"
  },
  "status": "in_progress",
  "attempt_number": 1,
  "started_at": "2026-09-14T19:01:00Z",
  "deadline_at": "2026-09-14T19:10:00Z",
  "remaining_seconds": 360,
  "finalization_reason": null,
  "score": null,
  "attempt_exception": null
}
```

Do not add:

```text
recipient_id
assignment_source
official_score_eligible
answer_count
answered_questions
file count
score visibility
contact information
```

in Stage 8 monitoring.

---

# 36. Top-Level Blitz Monitoring Shape

Success:

```json
{
  "data": {
    "blitz": {
      "id": "blitz-uuid",
      "status": "active",
      "duration_seconds": 600,
      "activated_at": "2026-09-14T19:00:00Z",
      "timing": {
        "mode": "synchronized",
        "synchronized_ends_at": "2026-09-14T19:10:00Z",
        "server_now": "2026-09-14T19:04:00Z"
      }
    },
    "summary": {
      "assigned": 25,
      "not_started": 5,
      "in_progress": 8,
      "finalized": 10,
      "waiting_for_teacher_review": 2,
      "attempt_exceptions_granted": 1
    },
    "students": []
  }
}
```

No top-level `message`.

No pagination metadata.

No links.

---

# 37. Blitz Timing Block

Use the activation-time frozen timing state.

Required:

```text
mode = blitz_tasks.timer_start_mode_snapshot
synchronized_ends_at = persisted value or null
server_now = stabilized snapshotAt
```

## Synchronized

Require structurally:

```text
activated_at non-null
synchronized_ends_at non-null
```

## Individual

Require:

```text
activated_at non-null
synchronized_ends_at = null
```

Invalid active task timing state:

```text
LogicException
```

Do not fall back to current Institution setting.

---

# 38. One Response Clock Instant

The response time is the exact canonical whole-second:

```text
serverNow = snapshotAt
```

captured by the first statement of the stabilized final
`REPEATABLE READ READ ONLY` transaction defined in Section 10.

Use this exact instant for:

- `blitz.timing.server_now`;
- every Student `remaining_seconds`;
- normal not-started synchronized remaining calculation;
- the Section-19 in-progress deadline check.

Do not call application `now()` after reconciliation for projection.

Do not call `now()` separately per Student.

If a deadline was crossed before `snapshotAt`, Section 10.4 reconciles and
rebuilds instead of throwing an internal error.

This makes both the database graph and the response clock internally coherent.

---

# 39. Student Ordering

Return all monitoring Student rows in deterministic order:

```text
lower(users.full_name) ASC
users.id ASC
```

Do not use current Group roster order.

Do not sort by mutable status unless a future API explicitly adds a sort contract.

No client sort input exists.

---

# 40. Monitoring Read Strategy

After reconciliation, load the entire final monitoring graph inside the one
stabilized `REPEATABLE READ READ ONLY` transaction from Section 10.

Conceptually, after the snapshot-establishing `snapshotAt` statement:

```text
1. authorized Blitz/Topic/Task final read
2. assessment_students recipients
3. recipient Student Users
4. all Blitz Attempts for recipient Student IDs
5. all Blitz Attempt Exceptions for recipient Student IDs
```

All five data-query families must use:

```text
the same database connection
the same transaction
the same PostgreSQL MVCC snapshot
```

Do not load parent/recipients under one transaction and Attempts/Exceptions after
that transaction has ended.

Equivalent optimized joins/eager loads are acceptable when they preserve the
same snapshot and exact projection semantics.

Do not query per Student.

Do not query per Attempt.

Do not query answer rows/questions because monitoring does not need them.

---

# 41. N+1 Requirement

Query count must remain effectively constant as roster size grows.

Add a focused query-count regression if the repository already uses such assertions.

At minimum, tests must demonstrate that increasing from a small roster to a larger roster does not cause one query per Student for:

- User;
- Attempts;
- Exception.

---

# 42. Summary Must Be Derived From Returned Rows

Do not separately run:

```text
COUNT not_started
COUNT in_progress
...
```

against database state.

Build Student rows first from the graph loaded inside the stabilized final
snapshot.

Then derive summary counts from those exact row states.

This guarantees:

```text
summary
```

matches:

```text
students
```

within the response even if another transaction changes state immediately afterward.

---

# 43. Monitoring Read Consistency and Concurrency

Monitoring is a live observational snapshot, not a display-locking workflow.

## 43.1 Required isolation

The final graph read must use PostgreSQL:

```text
REPEATABLE READ
READ ONLY
```

not the default multi-statement:

```text
READ COMMITTED
```

because READ COMMITTED may give each SELECT a newer snapshot and can manufacture
a graph that never existed as one committed state.

Set the isolation/read-only mode before the first snapshot/data statement.

## 43.2 No display locks

Do not use merely for display:

```text
FOR UPDATE
FOR NO KEY UPDATE
FOR SHARE
FOR KEY SHARE
```

on:

- Blitz parent rows;
- recipients;
- Users;
- Attempts;
- exception rows.

The earlier BE-007 reconciler owns any write locks required to finalize due
Attempts. The final monitoring transaction is read-only.

## 43.3 One committed graph

The `snapshotAt` statement fixes the final transaction snapshot.

Every later graph query in that transaction observes the same committed state.

Therefore a concurrent Student Start/Submit, Teacher exception grant,
replacement Start, or Teacher Close is observed only according to whether its
transaction committed before or after that snapshot boundary.

A transaction that commits **after** the snapshot boundary must not become
partially visible merely because it commits between two monitoring SELECTs.

Use the shared history validator only against the complete history loaded from
this one snapshot.

## 43.4 No connection drift

Do not perform part of the graph read through another database connection.

Do not dispatch final graph queries asynchronously onto independent connections.

Resources/DTOs must remain query-free after the transaction returns.

---

# 44. Monitoring vs Student Start

Possible valid snapshots are defined by the final snapshot boundary.

## Start committed before snapshot boundary

The complete Start state is visible:

```text
in_progress
```

with the matching Attempt/recipient state.

## Start commits after snapshot boundary

The Start is invisible to this response:

```text
not_started
```

or the prior valid path visible in the snapshot.

Even if Start commits between the monitoring Attempts query and a later query,
the current response remains on the same pre-Start snapshot.

No mutation from monitoring.

No Start block beyond ordinary short database reads.

---

# 45. Monitoring vs Submit

If Submit committed before the final snapshot boundary:

```text
finalized
```

is visible with its complete terminal metadata.

If Submit commits after the snapshot boundary:

```text
in_progress
```

may be returned from the valid pre-Submit snapshot, provided Section 10
stabilization confirms it was not due at `snapshotAt`.

A Submit that commits between graph SELECTs cannot create a hybrid terminal
shape inside this response.

Do not attempt to “complete” Submit from monitoring.

Only due timeout reconciliation is automatic.

---

# 46. Monitoring vs Exception Grant

The grant mutates both Attempt #1 eligibility and the exception graph.

Those changes must be observed atomically from one MVCC snapshot.

## Grant committed before snapshot boundary

The final graph contains the complete post-grant state:

```text
#1 official_score_eligible = false
attempt_exception != null
current operational path = replacement not_started
replacement_attempt_available = true
```

## Grant commits after snapshot boundary

The final graph contains the complete pre-grant state:

```text
#1 remains the current historical/terminal normal path
attempt_exception = null
```

If the grant is deliberately committed while monitoring is paused **between**
the Attempts SELECT and Exceptions SELECT, both SELECTs must still observe the
same pre-grant snapshot.

Forbidden hybrid:

```text
Attempts read before grant
+
Exception read after grant
```

Do not interpret such a hybrid as data corruption; prevent it through the
required isolation.

---

# 47. Monitoring vs Replacement Start

Replacement Start atomically creates #2 and links the exception.

## Replacement Start committed before snapshot boundary

Return the complete post-Start path:

```text
in_progress
attempt_number = 2
replacement_attempt_available = false
exception.replacement_attempt_id = #2
```

## Replacement Start commits after snapshot boundary

Return the complete pre-Start path:

```text
not_started
attempt_number = null
replacement_attempt_available = true
exception.replacement_attempt_id = null
```

If replacement Start commits between the Attempts and Exceptions SELECTs, the
response must still use one of those complete states, never:

```text
#2 visible without matching exception link
```

or:

```text
exception linked to #2 while #2 is absent
```

No #3 logic.

---

# 48. Monitoring vs Timeout Scheduler

Both monitoring and Scheduler call the same BE-007 timeout reconciler.

Repeated calls are safe.

Terminal Attempt timestamps/reasons must not churn.

Monitoring after either reconciliation path sees terminal state.

No duplicate timeout transition.

---

# 49. Monitoring vs Teacher Close

Teacher Close and monitoring race relative to the final snapshot boundary.

## Close committed before snapshot boundary

The snapshot-visible final parent state is:

```text
closed
```

Return:

```text
409 task_closed
```

and do not build Student rows.

## Close commits after snapshot boundary

The Close transaction is not visible in this read-only snapshot.

Monitoring may return the valid, internally consistent pre-Close:

```text
blitz.status = active
```

response.

This is not stale relative to the response snapshot.

Even if Close commits while monitoring is paused between graph SELECTs, later
SELECTs in that transaction must not observe post-Close Attempt rows.

The next monitoring request sees `closed` and returns `task_closed`.

Do not reopen the task.

---

# 50. Practice and Official Blitz

Monitoring works identically for:

```text
practice Blitz
official result-bearing Blitz
```

The endpoint does not expose:

```text
topic_result_pair
official score
official cohort metadata
```

The persisted recipient snapshot is sufficient.

Do not branch Student status based on official/practice designation.

---

# 51. Inactive Assigned Student

If a Student account became inactive after activation:

- keep the Student in `assigned`;
- keep their persisted Attempt/exception operational state;
- show their historical `full_name`.

Do not classify account inactivity as a new monitoring status.

Do not remove their row.

---

# 52. Never-Started Student After Synchronized End

When:

```text
no #1
no exception
mode = synchronized
server_now >= synchronized_ends_at
```

monitoring row remains:

```text
status = not_started
attempt_number = null
started_at = null
deadline_at = null
remaining_seconds = 0
finalization_reason = null
```

No Attempt is fabricated.

No timeout Attempt is created.

This accurately distinguishes:

```text
assigned but never started
```

from:

```text
started and timed out
```

---

# 53. Exception Granted After Synchronized End

When:

```text
#1 terminal/ineligible
unused exception exists
server_now >= synchronized_ends_at
Blitz remains active
```

monitoring row is:

```text
status = not_started
attempt_number = null
started_at = null
deadline_at = null
remaining_seconds = null
replacement_attempt_available = true
```

This reflects the compensating BE-009 replacement window.

Do not show common-end `0` as the replacement remaining time.

---

# 54. Terminal Replacement #2

When #2 is terminal:

```text
status = finalized
or waiting_for_teacher_review
attempt_number = 2
remaining_seconds = 0
finalization_reason = #2 reason
replacement_attempt_available = false
```

Attempt #1 remains accessible only indirectly through exception metadata in this monitoring endpoint.

Full Attempt history UI is not Stage 8 monitoring scope.

---

# 55. Error Contract

| Condition | Result |
|---|---|
| malformed/private/foreign Blitz | `404 resource_not_found` |
| request body/query supplied | `422 validation_failed` |
| Draft/Scheduled Blitz | `409 task_not_active` |
| Closed Blitz | `409 task_closed` |
| Archived Blitz | `409 task_archived` |
| corrupt active timer snapshot | internal invariant failure |
| corrupt recipient/User graph | internal invariant failure |
| corrupt #1/#2/exception history | internal invariant failure |

Do not add monitoring-specific business error codes.

---

# 56. Controller / Action Boundary

Add monitoring to:

```text
TeacherBlitzController
```

or a focused:

```text
TeacherBlitzMonitoringController
```

Either is acceptable if route architecture remains clean.

Controller does only:

1. receive validated request;
2. get authenticated Teacher;
3. call monitoring Action;
4. return monitoring Resource.

No direct Eloquent monitoring queries in Controller.

---

# 57. Required Action

Create:

```text
ShowTeacherBlitzMonitoring
```

or exact equivalent.

Responsibilities:

1. preliminary privacy-safe Teacher/Blitz resolution sufficient to decide whether reconciliation may be relevant;
2. invoke shared timeout reconciler for the preliminary active task;
3. open one PostgreSQL `REPEATABLE READ READ ONLY` final-read transaction;
4. first statement establishes the snapshot and captures `snapshotAt`;
5. re-resolve/re-authorize final parent/lifecycle state inside that snapshot;
6. load recipients/Users/Attempts/Exceptions inside the same snapshot;
7. if any `in_progress.deadline_at <= snapshotAt`, discard the snapshot, reconcile, and restart the final-read cycle;
8. validate/project each Student current operational state;
9. derive summary from those exact rows;
10. return a fully materialized query-free DTO/projection with `serverNow = snapshotAt`.

Do not return a raw Eloquent aggregate requiring hidden Resource queries.

Do not return a raw Eloquent aggregate requiring hidden Resource queries.

---

# 58. Monitoring Projection DTO

Use one explicit immutable projection object or a small family of DTOs, for example:

```text
TeacherBlitzMonitoring
TeacherBlitzMonitoringStudent
TeacherBlitzMonitoringException
```

Exact names are flexible.

Avoid attaching a large number of transient attributes to Eloquent models.

The projection must carry everything the Resource needs.

Resources must not query.

---

# 59. Required Resource

Create:

```text
TeacherBlitzMonitoringResource
```

It serializes the exact Section 36 contract.

A small nested Student resource is allowed if it reduces complexity.

No resource method may execute DB queries.

---

# 60. Shared History Projector Extraction

If needed, extract a domain-focused helper such as:

```text
BlitzAttemptHistory
```

that receives:

```text
Assessment
AssessmentStudent
Student
collection of this Student's Attempts
optional BlitzAttemptException
```

and validates/selects:

```text
normal #1
replacement #2
current effective Attempt/path
replacement availability
```

Use it from:

- BE-009 Student Start/read logic;
- BE-010 Teacher monitoring.

Do not maintain separate logic that could disagree about whether replacement #2 is valid.

No public API change from the extraction.

---

# 61. Monitoring Score Boundary Test

Tests must deliberately create fixtures with non-null:

```text
earned_points
normalized_score
```

or later-style checked state where schema allows.

Monitoring must still return:

```json
"score": null
```

This prevents accidental early Stage 9 result leakage.

Do not load official task score/result tables.

---

# 62. Monitoring Answer Privacy Test

Monitoring must not contain any of:

```text
questions
answers
answer text
selected option IDs
file metadata
correct answer configuration
checking_status
awarded_points
feedback
```

The Teacher learns operational execution status only.

Teacher submission review is a separate later capability.

---

# 63. Monitoring API Tests

Create:

```text
TeacherBlitzMonitoringApiTest.php
```

Cover:

- exact route registered once;
- no body/query;
- basic active synchronized response shape;
- basic active individual response shape;
- one response `server_now`;
- deterministic Student ordering;
- exact summary partition;
- no score/answer leakage;
- no top-level message/pagination.

---

# 64. Monitoring Authorization Tests

Create:

```text
TeacherBlitzMonitoringAuthorizationTest.php
```

Cover:

- unauthenticated;
- wrong role;
- foreign Institution;
- another Teacher;
- ended Teacher–Group membership;
- malformed UUID;
- direct private UUID probing.

All private/out-of-scope cases:

```text
404 resource_not_found
```

after authentication/middleware where appropriate.

---

# 65. Monitoring Lifecycle Tests

Cover:

```text
draft     -> task_not_active
scheduled -> task_not_active
closed    -> task_closed
archived  -> task_archived
active    -> 200
```

Also verify:

- synchronized common end already passed but task active -> monitoring still 200;
- monitoring does not auto-close;
- repeated monitoring does not churn task timestamps.

---

# 66. Basic Student State Tests

Build assigned recipients covering:

```text
never-started normal path
#1 in progress
#1 explicit submitted
#1 timeout-finalized
#1 close-finalized
```

Assert exact:

```text
status
attempt_number
started_at
deadline_at
remaining_seconds
finalization_reason
score = null
```

Assert:

```text
assigned = number of returned students
summary partition equals rows
```

---

# 67. Exception / Replacement Monitoring Tests

Cover:

## Grant unused

```text
#1 terminal/ineligible
exception replacement null
```

Result:

```text
status = not_started
attempt_number = null
timing fields null
exception available true
```

## Replacement in progress

```text
status = in_progress
attempt_number = 2
deadline = #2 deadline
exception available false
```

## Replacement submitted

```text
status = finalized
attempt_number = 2
remaining = 0
```

## Replacement timed out

Same operational finalized mapping with:

```text
timeout_auto_submit
```

## Synchronized common end passed + unused exception

Replacement remains:

```text
not_started
remaining_seconds = null
available = true
```

---

# 68. Waiting-for-Review Forward-Compatible Test

Where current enum/schema permits, create a structurally valid current Attempt fixture with:

```text
status = waiting_for_teacher_review
```

and valid terminal execution fields.

Monitoring maps it to:

```text
waiting_for_teacher_review
```

and increments that summary bucket.

Still:

```text
score = null
```

Stage 8 does not create the status itself.

---

# 69. Timeout Reconciliation Monitoring Tests

Create:

```text
TeacherBlitzMonitoringTimeoutReconciliationTest.php
```

Cover:

- synchronized due #1 is finalized before response;
- individual due #1 finalized;
- due #2 replacement finalized by its own deadline;
- future Attempt remains in progress;
- mixed Students same Blitz;
- exact deadline equality;
- persisted finalization uses exact deadline;
- response never shows an Attempt due at final `snapshotAt` as in-progress;
- controlled boundary: first reconciliation occurs at `12:00:59`, deadline is `12:01:00`, final snapshot begins at/equal `12:01:00` -> no LogicException; snapshot is discarded, reconciliation finalizes at exact deadline, rebuilt response is terminal;
- fractional DB clock `12:00:59.999999Z` yields `snapshotAt=12:00:59Z` and exact whole-second remaining;
- fractional DB clock `12:01:00.000001Z` yields `snapshotAt=12:01:00Z` and triggers due stabilization for deadline `12:01:00Z`;
- response `server_now` never contains fractional seconds;
- no arbitrary sleep in stabilization;
- unanswered never-started Student receives no Attempt;
- repeated monitoring has no terminal timestamp churn.

---

# 70. Monitoring Concurrency Tests

Create a focused:

```text
TeacherBlitzMonitoringConcurrencyTest.php
```

or extend existing concurrency harness.

Cover at minimum with PostgreSQL worker/barrier coordination and **no arbitrary
sleep**:

1. Student Start commits between final graph SELECTs;
2. Student Submit commits between final graph SELECTs;
3. exception grant commits specifically after Attempts are read but before Exceptions are read;
4. replacement Start commits specifically between Attempts and Exceptions reads;
5. Teacher Close commits after the final parent read but before later graph SELECTs;
6. Teacher Close commits before the snapshot boundary.

Required:

- verify the final read runs under `repeatable read` semantics, not ordinary multi-statement READ COMMITTED;
- response is one valid committed pre/post snapshot, never a hybrid;
- grant-between-queries cannot produce pre-grant Attempt eligibility + post-grant exception;
- replacement Start-between-queries cannot produce an unlinked/missing-#2 hybrid;
- Close before snapshot boundary -> `task_closed`;
- Close after snapshot boundary -> valid pre-Close active response is allowed and all later graph SELECTs remain pre-Close;
- next request after committed Close -> `task_closed`;
- summary derives from returned snapshot rows;
- no mutation except due timeout reconciliation outside the final read-only transaction;
- no `FOR UPDATE`/share display locks;
- no deadlock from monitoring display reads.

Do not require which business mutation wins the race; require only snapshot-boundary semantics.

---

# 71. N+1 / Query-Bound Test

Add focused evidence that monitoring query count does not scale linearly with Student count.

Use the repository's existing query-listen/count pattern if present.

At minimum compare:

```text
small roster
larger roster
```

and assert no per-Student query family for:

- User;
- Attempts;
- Exceptions.

Do not overfit to an unnecessarily brittle exact total query number if repository conventions avoid exact counts.

---

# 72. Direct BE-007 Regression

Monitoring invokes the BE-007 timeout engine.

Run focused delivered tests covering:

```text
FinalizeTimedOutBlitzAttempts
Scheduler timeout
Teacher Close timeout precedence
```

Use exact delivered filenames.

Monitoring must not alter the timeout state machine.

---

# 73. Direct BE-009 Regression

Monitoring shares exception/history semantics.

Run focused delivered tests covering:

```text
Teacher grant
replacement Start
replacement timing
replacement concurrency/history
```

Use exact delivered filenames.

Monitoring must agree with BE-009 on:

```text
current operational Attempt
replacement availability
#1/#2 graph validity
```

---

# 74. Direct BE-005/008 Regression

Run the directly affected focused tests for:

- Student active list/detail;
- normal Start/Resume;
- Blitz Submit terminal resource.

This confirms any shared history-projector extraction does not change Student behavior.

No broad Stage 8 backend suite yet.

---

# 75. Verification Commands

Run from:

```text
backend/
```

## 75.1 New monitoring tests

```bash
php artisan test \
  tests/Feature/Teacher/TeacherBlitzMonitoringApiTest.php \
  tests/Feature/Teacher/TeacherBlitzMonitoringAuthorizationTest.php \
  tests/Feature/Teacher/TeacherBlitzMonitoringTimeoutReconciliationTest.php \
  tests/Feature/Teacher/TeacherBlitzMonitoringConcurrencyTest.php
```

If exception/state cases are split into another focused monitoring test, include it.

## 75.2 Direct BE-007 regression

Run exact delivered Blitz timeout/Close/Scheduler focused tests affected by the monitoring reconciliation call.

## 75.3 Direct BE-009 regression

Run exact delivered Teacher exception + Student replacement focused tests affected by any shared history extraction.

## 75.4 Direct Student regression

Run exact delivered focused Student Blitz read/Start/Submit tests affected by shared projection/history extraction.

## 75.5 Format

```bash
./vendor/bin/pint --test
```

No additional static-analysis command is required unless current repository configuration makes one mandatory for exactly this backend scope.

## 75.6 Always

From repository root:

```bash
git diff --check
```

Do not run:

- full backend suite;
- frontend tests;
- Flutter analyze/build;
- broad E2E.

The next required gate is:

```text
S08-BE-PHASE-2
```

which owns the full backend regression suite and Stage-wide backend read-only review.

---

# 76. Acceptance Criteria — Endpoint / Authorization

- [ ] Exact monitoring GET route exists once.
- [ ] No body/query accepted.
- [ ] Teacher middleware exact.
- [ ] Tenant/Teacher/current-membership scope enforced.
- [ ] Private UUIDs return scope-safe 404.
- [ ] Active only.
- [ ] Draft/Scheduled/Closed/Archived errors exact.
- [ ] Active task after timer end remains monitorable.

---

# 77. Acceptance Criteria — Timeout Authority

- [ ] Monitoring invokes shared BE-007 timeout reconciler before the final snapshot.
- [ ] Final response clock is whole-second `snapshotAt` captured when the consistent final MVCC snapshot is established.
- [ ] Snapshot SQL truncates fractional DB clock time to the UTC second before timer comparison/projection.
- [ ] Monitoring wire timestamps contain no fractional seconds.
- [ ] A due Attempt at `snapshotAt` causes reconcile-and-rebuild, not `LogicException`.
- [ ] Stabilized response never contains `in_progress` with `deadline_at <= snapshotAt`.
- [ ] Exact deadline timestamp/reason preserved.
- [ ] Replacement #2 uses its own persisted deadline.
- [ ] Monitoring never auto-closes Blitz.
- [ ] Repeated monitoring does not churn terminal history.
- [ ] No other monitoring-triggered domain mutation.

---

# 78. Acceptance Criteria — Roster / State

- [ ] Roster comes from persisted AssessmentStudent snapshot.
- [ ] Current Student Group membership does not redefine assigned count.
- [ ] Inactive assigned Student remains visible.
- [ ] Every recipient maps to exactly one row.
- [ ] No exception -> current #1 semantics.
- [ ] Unused exception -> current replacement path `not_started`.
- [ ] Replacement started -> current #2.
- [ ] No arbitrary Attempt selection.
- [ ] Invalid #1/#2/exception graph not silently repaired.

---

# 79. Acceptance Criteria — Summary / Timing

- [ ] Status values exactly `not_started|in_progress|finalized|waiting_for_teacher_review`.
- [ ] Summary partition equals returned rows.
- [ ] Exception count orthogonal.
- [ ] One response `server_now = snapshotAt`.
- [ ] `snapshotAt` is canonical UTC whole-second precision.
- [ ] `snapshotAt` is captured on the same connection/transaction that owns the final graph snapshot.
- [ ] In-progress remaining is the exact integer epoch-second difference from the current Attempt deadline.
- [ ] Terminal remaining = 0.
- [ ] Normal synchronized not-started uses common remaining.
- [ ] Individual not-started remaining = null.
- [ ] Unused replacement remaining = null in both modes.
- [ ] Synchronized historical common end never becomes replacement deadline.

---

# 80. Acceptance Criteria — Privacy / Stage Boundary

- [ ] Student identity exposes only id/full_name.
- [ ] No answers/questions/files in monitoring.
- [ ] No checking metadata.
- [ ] `score` is always null in Stage 8.
- [ ] No official score/result table read.
- [ ] Teacher exception reason may appear only in `attempt_exception`.
- [ ] No Teacher answer mutation capability added.
- [ ] No scoring/checking implemented.

---

# 81. Acceptance Criteria — Performance / Concurrency

- [ ] Deterministic full-name/id ordering.
- [ ] No pagination added.
- [ ] No N+1 Student/User/Attempt/Exception query pattern.
- [ ] Summary derived from returned rows.
- [ ] Final graph read uses one PostgreSQL `REPEATABLE READ READ ONLY` transaction.
- [ ] Default multi-statement READ COMMITTED is not used for the final graph.
- [ ] All parent/recipient/User/Attempt/Exception reads use one connection and one MVCC snapshot.
- [ ] Monitoring does not take display `FOR UPDATE`/share locks.
- [ ] Start/Submit/grant/replacement races produce one valid pre/post snapshot with no hybrid graph.
- [ ] Close committed before snapshot boundary returns `task_closed`.
- [ ] Close committed after snapshot boundary may yield one valid pre-Close active response; the next request observes Close.
- [ ] No deadlock introduced.

---

# 82. Scope Acceptance

- [ ] No migration.
- [ ] No frontend.
- [ ] No WebSocket/SSE.
- [ ] No result/checking/review implementation.
- [ ] No exception mutation through monitoring.
- [ ] No task lifecycle mutation through monitoring.
- [ ] Focused monitoring tests pass.
- [ ] BE-007 regression passes.
- [ ] BE-009 regression passes.
- [ ] Direct Student regressions pass.
- [ ] Pint passes.
- [ ] `git diff --check` passes.

---

# 83. Focused Diff Self-Check

Before completion confirm:

```text
Teacher active-Blitz operational monitoring only
```

Verify specifically:

```text
timeout reconciliation reused
roster is persisted snapshot
unused exception projects replacement not_started
#2 timing uses #2 deadline
score always null
no answers/files
no lifecycle mutation
no N+1
```

Confirm no unrelated refactor.

---

# 84. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. monitoring endpoint/request contract;
4. authorization/lifecycle behavior;
5. timeout reconciliation behavior;
6. Student operational state-machine mapping;
7. exception/#2 monitoring behavior;
8. summary derivation;
9. timing/remaining calculation;
10. privacy/no-score boundary;
11. query/N+1 behavior;
12. concurrency behavior;
13. focused monitoring test results;
14. BE-007 regression results;
15. BE-009 regression results;
16. direct Student regression results;
17. Pint result;
18. `git diff --check`;
19. final `git status --short`;
20. focused scope/diff self-check;
21. any blocker/deviation.

Do not claim Stage 8 backend complete.

After delivery ChatGPT performs read-only acceptance review of S08-BE-010.

The next gate is **not another implementation feature task**.

After:

```text
S08-BE-010 = Accepted / Delivered
```

the required next step is:

```text
S08-BE-PHASE-2
```

for the complete Stage 8 backend block.

---

# 85. Implementation Readiness Verdict

```text
Scope / non-goals                    = RESOLVED
Monitoring endpoint                  = RESOLVED
Lifecycle availability               = RESOLVED
Authorization/Tenant isolation       = RESOLVED
Timeout reconciliation               = RESOLVED
Roster authority                     = RESOLVED
Student identity projection          = RESOLVED
#1/#2/exception history reuse        = RESOLVED
Operational state machine            = RESOLVED
Summary partition                    = RESOLVED
Timing/remaining semantics           = RESOLVED
Unused replacement projection        = RESOLVED
Teacher exception metadata           = RESOLVED
No-score/no-answer boundary           = RESOLVED
Deterministic ordering                = RESOLVED
Read consistency/concurrency          = RESOLVED
PostgreSQL snapshot isolation          = RESOLVED
Close snapshot-boundary semantics      = RESOLVED
Clock-boundary stabilization           = RESOLVED
N+1/query behavior                    = RESOLVED
Error behavior                        = RESOLVED
Acceptance criteria                   = RESOLVED
Focused verification                  = RESOLVED

Implementation Readiness Gate         = PASS
Execution dependency                  = S08-BE-009 Accepted / Delivered
Next gate after acceptance             = S08-BE-PHASE-2
```
