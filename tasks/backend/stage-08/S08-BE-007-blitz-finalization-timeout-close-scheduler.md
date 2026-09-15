# Codex Implementation Contract: S08-BE-007 — Blitz Finalization Engine: Timeout, Teacher Close and Scheduler

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-BE-007` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel server-authoritative Blitz timeout reconciliation + Teacher Close + Scheduler` |
| Depends on | `S08-DOC-001`, `S08-BE-001…006` — all `Accepted / Delivered` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` after dependencies are delivered and immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |
| Backend block checkpoint | `Stage 8 Backend Phase 2` after `S08-BE-001…010` are `Accepted / Delivered` |
| Blocks | `S08-BE-008` |

Start only when:

```text
S08-DOC-001 = Accepted / Delivered
S08-BE-001…006 = Accepted / Delivered
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
4. delivered S08-BE-001…006 source/tests directly required here;
5. current Stage 7 Homework deadline/finalization/Teacher-close/Scheduler source and focused tests;
6. current shared Attempt enums/models;
7. current Student Blitz read/Start/answer/file paths that must be wired to the new reconciler.

Do **not** read:

- `docs/01–09`;
- roadmap files;
- Stage indexes;
- `S08-DOC-001`;
- previous task files;
- closure reviews;
- frontend code

to infer requirements.

This contract resolves:

- exact Blitz timeout state transition;
- exact Teacher-close transition;
- timeout-vs-close precedence;
- server-authoritative historical timestamps;
- one reusable reconciliation engine;
- request-path wiring;
- Scheduler command/cadence;
- no checking/scoring boundary;
- no fabricated Attempt/answer rows;
- terminal immutability;
- concurrency/lock ordering;
- errors;
- acceptance criteria;
- focused tests/verification.

If delivered dependencies materially conflict with this contract, return:

```text
BLOCKED
```

with exact evidence.

Do not independently redesign lifecycle, timing, Attempt statuses, scoring, or Stage 8/9 ownership.

---

# 3. Goal

Implement one authoritative Blitz execution-finalization engine so that a timed Blitz cannot remain Student-editable after its persisted deadline.

The engine must be reused by:

```text
Student Blitz active/detail reads
Student Blitz Start/Resume
Student typed answer mutation
Student file answer mutation
Teacher Blitz Close
Laravel Scheduler
```

At completion:

- every reached Blitz Attempt deadline is authoritative;
- existing `in_progress` Attempt work is frozen;
- delayed Scheduler execution never extends Student time;
- Teacher Close cannot overwrite a timeout that already became due;
- terminal Attempt history is immutable;
- Stage 8 still performs no answer checking/scoring.

---

# 4. Public API Change

Add exactly:

```text
POST /api/v1/teacher/blitz/{blitz}/close
```

inside the existing Teacher middleware group:

```text
auth:sanctum
active.account
password.changed
role:teacher
```

No `Idempotency-Key` is required.

Reuse the delivered empty lifecycle request convention:

```text
empty body
or
{}
no query parameters
```

Do not add any other public route in this task.

---

# 5. Explicit Non-Goals

Do not implement:

- explicit Student Blitz Submit;
- Blitz Submit idempotency;
- technical Attempt exception grant;
- replacement Attempt #2;
- Teacher monitoring;
- automatic checking;
- Teacher manual review;
- awarded points;
- Attempt score;
- official Blitz score;
- Topic result;
- frontend;
- integration seed/harness;
- schema migration;
- new persistence table;
- event bus/queue for finalization;
- per-question timer.

Do not modify Student answers during finalization.

Do not create synthetic answers for unanswered Questions.

Do not create Attempts for never-started Students.

---

# 6. Existing Shared Persistence to Reuse

Reuse:

```text
assessment_attempts
attempt_answers
blitz_tasks
assessments
assessment_students
```

Existing Attempt statuses:

```text
in_progress
submitted
timed_out_finalized
waiting_for_teacher_review
checked
```

Existing finalization reasons:

```text
student_submit
timeout_auto_submit
task_closed_auto_finalize
homework_deadline_auto_submit
```

No enum value or schema change is required.

---

# 7. Stage 8 / Stage 9 Boundary

This task finalizes **execution only**.

It must never:

```text
check an answer
compare with correct-answer configuration
set checking_status to a reviewed/checked state
write awarded_points
write feedback
write checked_by_user_id
write checked_at
write earned_points
write normalized_score
write scoring_completed_at
select official score
calculate Topic result
```

Every already-saved Stage 8 answer remains:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

Stage 9 later interprets absent answers as zero and checks/scores frozen saved work.

---

# 8. Blitz Attempt Finalizer

Create a focused support class:

```text
App\Support\Assessment\BlitzAttemptFinalizer
```

It owns only Attempt field transitions after the caller has locked the Attempt.

Do not route Blitz timeout through `HomeworkAttemptFinalizer`.

Homework deadline finalization remains unchanged.

---

# 9. Common In-Progress Integrity Gate

Before any Blitz finalization transition, an `in_progress` Attempt must satisfy:

```text
status = in_progress
deadline_at is not null
submitted_at = null
finalized_at = null
locked_at = null
finalization_reason = null
```

If status is already terminal:

```text
return false
```

without writes.

If status says `in_progress` but finalization fields are inconsistent:

```text
LogicException
```

Do not repair inconsistent history.

Do not change:

```text
started_at
deadline_at
attempt_number
assessment_student_id
student_id
official_score_eligible
possible_points
earned_points
normalized_score
scoring_completed_at
```

during timeout/close finalization.

---

# 10. Timeout Finalization Transition

Method conceptually:

```text
finalizeAtTimeout(AssessmentAttempt $attempt): bool
```

Use the persisted:

```text
attempt.deadline_at
```

as the historical finalization instant.

For an eligible `in_progress` Attempt set exactly:

```text
status = timed_out_finalized
submitted_at = null
finalized_at = deadline_at
locked_at = deadline_at
finalization_reason = timeout_auto_submit
```

Do not set:

```text
submitted_at = deadline_at
```

Timeout is not an explicit Student Submit.

Do not use delayed:

```text
server_now
Scheduler processing time
request processing time
Teacher close time
```

as `finalized_at`.

The exact persisted deadline is authoritative.

---

# 11. Teacher-Close Finalization Transition

Method conceptually:

```text
finalizeAtClose(AssessmentAttempt $attempt, CarbonInterface $closedAt): bool
```

This method is used only when:

```text
closedAt < attempt.deadline_at
```

For an eligible `in_progress` Attempt set exactly:

```text
status = submitted
submitted_at = null
finalized_at = closedAt
locked_at = closedAt
finalization_reason = task_closed_auto_finalize
```

Teacher Close is not an explicit Student Submit.

Do not set:

```text
submitted_at = closedAt
```

---

# 12. Timeout Precedence Over Teacher Close

For every locked `in_progress` Attempt at one captured:

```text
closedAt = server_now
```

apply:

```text
if closedAt >= attempt.deadline_at:
    timeout-finalize at exact attempt.deadline_at
else:
    task-close-finalize at closedAt
```

This is per Attempt.

It is **not** one global decision for the whole Blitz.

This distinction is mandatory in `individual` timer mode because Students may have different deadlines.

At exact equality:

```text
closedAt == deadline_at
```

timeout wins.

---

# 13. Why Persisted `deadline_at` Is the Execution Authority

The reconciler must use:

```text
assessment_attempts.deadline_at
```

as the authoritative effective Student deadline.

Do not recompute deadlines from:

- client time;
- current Institution setting;
- current device timezone;
- current Blitz activation age.

BE-005 already persisted the correct normal Attempt deadline.

Future BE-009 may create a Student-specific replacement Attempt with its own deadline.

The finalization engine must remain compatible with that future replacement by treating each Attempt's persisted deadline independently.

---

# 14. No Synchronized-Only Deadline Assumption

Do **not** make the timeout engine require:

```text
every synchronized-mode Attempt.deadline_at
=
blitz_tasks.synchronized_ends_at
```

as a universal finalization invariant.

That is true for normal Attempt #1, but the approved future Student-specific replacement Attempt may have a compensating Student-specific deadline while the class-wide synchronized end remains historical.

Timing-shape validation belongs to Attempt creation/grant paths.

The finalizer requires only a structurally valid persisted Attempt deadline.

---

# 15. Reusable Aggregate Reconciler

Create:

```text
App\Actions\Blitz\FinalizeTimedOutBlitzAttempts
```

or an equivalently precise name.

Public callable contract:

```php
__invoke(string $institutionId, string $assessmentId): int
```

Return:

```text
number of Attempts transitioned to timed_out_finalized
```

The Action must be safe to call repeatedly.

---

# 16. Reconciler Transaction

Inside one DB transaction:

1. resolve/lock:
   ```text
   Assessment
   ```
   by Institution + ID + `type = blitz`;
2. lock:
   ```text
   BlitzTask
   ```
   same Institution/Assessment;
3. capture:
   ```text
   observedAt = server_now
   ```
   only after parent locks;
4. if Blitz is not `active`:
   ```text
   return 0
   ```
5. lock all:
   ```text
   assessment_attempts
   where same Institution/Assessment
   and status = in_progress
   order by id
   ```
6. for each locked Attempt:
   - validate same aggregate;
   - require non-null valid `deadline_at`;
   - if:
     ```text
     observedAt >= deadline_at
     ```
     call `BlitzAttemptFinalizer::finalizeAtTimeout`;
   - otherwise preserve it;
7. commit.

Do not lock or mutate answer rows.

No Attempt:

```text
return 0
```

---

# 17. Reconciler Handles Mixed Individual Deadlines

Example at:

```text
observedAt = 12:10
```

locked Attempts:

```text
A deadline = 12:05
B deadline = 12:10
C deadline = 12:15
```

Result:

```text
A -> timed_out_finalized at 12:05
B -> timed_out_finalized at 12:10
C -> remains in_progress
```

One aggregate call may finalize only a subset.

Do not use the earliest/latest deadline as a whole-task decision.

---

# 18. Reconciler Structural Integrity

For every locked in-progress Attempt require:

```text
institution_id = Blitz Institution
assessment_id = Blitz Assessment
started_at non-null
deadline_at non-null
deadline_at > started_at
```

If structural history is impossible:

```text
LogicException
```

and the transaction rolls back.

Do not silently skip malformed in-progress Attempts while finalizing others in the same aggregate.

Terminal Attempts are not selected for transition and remain unchanged.

---

# 19. Read-Path Student Timeout Reconciliation

BE-005 Student read paths currently reject/omit expired work without mutation.

After BE-007, wire them to the shared reconciler.

## 19.1 Active list

Before producing the final active list:

1. capture a scan/read boundary as needed;
2. identify assigned active Blitz assessments with this Student's `in_progress` Attempt whose:
   ```text
   deadline_at <= server_now
   ```
3. invoke `FinalizeTimedOutBlitzAttempts` for each candidate Assessment;
4. execute/re-execute the final list query.

Because the aggregate reconciler finalizes all due Attempts for the same Blitz, one Student read may also reconcile other Students' already-due Attempts on that same Blitz.

This is acceptable and mirrors the authoritative aggregate Homework deadline behavior.

After reconciliation:

- timed-out Attempt is terminal;
- without replacement support, that Blitz is no longer startable/resumable for this Student;
- it is omitted from active-startable list.

Do not fabricate a replacement Attempt.

## 19.2 Blitz detail

Before the final detail timing/Attempt projection, reconcile this assigned Blitz when an own in-progress Attempt may be due.

After reconciliation:

- if active synchronized execution window itself is expired:
  ```text
  409 blitz_time_expired
  ```
- if individual own Attempt has just timed out:
  ```text
  409 blitz_time_expired
  ```
  under the existing BE-005 execution-detail contract.

The persisted Attempt is now terminal.

Do not return a stale `in_progress` state.

---

# 20. Start/Resume Timeout Wiring

Update:

```text
StartStudentBlitzAttempt
```

or exact delivered equivalent.

Two cases matter.

## 20.1 New normal Start with no Attempt

For synchronized mode when:

```text
server_now >= synchronized_ends_at
```

return:

```text
409 blitz_time_expired
```

No Attempt exists, so no reconciler write is needed.

Do not fabricate an expired Attempt.

## 20.2 Existing in-progress Attempt reaches deadline

When the locked Start/Resume decision discovers:

```text
server_now >= attempt.deadline_at
```

do not finalize inside a conflicting partial lock sequence if doing so would violate the aggregate lock order.

Follow the established Homework pattern:

1. return an internal due marker from the transaction after releasing current locks;
2. invoke:
   ```text
   FinalizeTimedOutBlitzAttempts
   ```
   for the Assessment;
3. throw:
   ```text
   409 blitz_time_expired
   ```

for a **new Start key**.

No new successful idempotency claim remains from the rejected Start.

---

# 21. Completed Start Replay at Timeout

A previously completed Start idempotency key remains replayable.

It is not a new request for additional time.

If replay resolves an Attempt that is still `in_progress` but its deadline is now reached:

1. reconcile the Blitz using the shared timeout engine;
2. reload the referenced own Attempt;
3. return the same logical completed Start replay with its original recorded HTTP semantic status:
   ```text
   200 or 201
   ```
4. project the Attempt's current terminal state.

Do not:

- extend deadline;
- create a new Attempt;
- return a fresh `blitz_time_expired` instead of the valid completed replay;
- mutate the completed idempotency record.

This preserves durable Start replay semantics while preventing stale in-progress state.

---

# 22. Answer Mutation Timeout Wiring

Update the BE-006 Blitz typed-answer path.

When, after the relevant locks:

```text
server_now >= attempt.deadline_at
```

the transaction must perform zero answer-domain mutation and return an internal due marker.

After releasing its current locks:

1. call:
   ```text
   FinalizeTimedOutBlitzAttempts
   ```
2. throw:
   ```text
   409 blitz_time_expired
   ```

No answer row/payload changes may commit.

If a prior answer exists, it remains exactly as last committed before the deadline.

---

# 23. File Mutation Timeout Wiring

Update the BE-006 Blitz file path similarly.

If the deadline is reached after upload staging but before persistence eligibility:

1. perform zero answer/file DB replacement;
2. release current transaction locks;
3. compensate/delete the newly staged blob best-effort;
4. reconcile:
   ```text
   FinalizeTimedOutBlitzAttempts
   ```
5. throw:
   ```text
   409 blitz_time_expired
   ```

The previously-valid persisted File/Answer remains current.

Do not delete the old blob.

Do not leave the newly staged blob treated as current.

---

# 24. Teacher Blitz Close Endpoint

Implement:

```text
POST /api/v1/teacher/blitz/{blitz}/close
```

through the delivered:

```text
TeacherBlitzController
```

or exact equivalent.

Controller remains thin.

Action:

```text
CloseTeacherBlitz
```

Request:

```text
TeacherBlitzLifecycleRequest
```

or the delivered equivalent empty-lifecycle request.

---

# 25. Teacher Close Authorization

Resolve only through the delivered Teacher Blitz access boundary:

```text
same Institution
Assessment.type = blitz
teacher_id = authenticated Teacher
Topic currently visible to Teacher
current Teacher–Group membership exists
BlitzTask exists
```

Malformed/private/foreign/no-longer-authorized:

```text
404 resource_not_found
```

Do not authorize by UUID possession.

---

# 26. Teacher Close Lifecycle

## Active

May close.

## Already Closed

Return current full Teacher Blitz resource:

```text
200 OK
```

with:

```text
Blitz task closed successfully.
```

Perform zero writes.

Do not:

- change `closed_at`;
- refinalize Attempts;
- touch Assessment/Blitz timestamps.

## Draft / Scheduled

Return:

```text
409 task_not_active
```

## Archived

Return:

```text
409 task_archived
```

No reopen.

---

# 27. Topic State During Close

Mirror the delivered recovery-safe Homework close boundary.

If Topic is:

```text
archived
```

return:

```text
409 topic_not_editable
```

An Active Blitz under an already-Closed Topic is structurally unexpected because the Topic open-assessment guard should have prevented Topic close.

If such a valid-authorized fixture exists, allow Teacher Blitz Close to resolve the active task rather than making it impossible to close.

Do not reopen or mutate the Topic.

---

# 28. Teacher Close Transaction and Lock Order

Inside one transaction:

1. lock:
   ```text
   Group
   current Teacher–Group membership
   Topic
   Assessment
   BlitzTask
   ```
   through delivered lifecycle access;
2. resolve lifecycle no-op/errors;
3. lock the Topic result pair if this Blitz participates in it;
4. lock all Assessment Attempts:
   ```text
   same Institution/Assessment
   order by id
   ```
5. validate Attempt aggregate integrity;
6. capture one:
   ```text
   closedAt = server_now
   ```
7. for every locked Attempt currently `in_progress`:
   ```text
   if closedAt >= attempt.deadline_at:
       timeout-finalize at exact deadline_at
   else:
       task-close-finalize at closedAt
   ```
8. set Blitz:
   ```text
   status = closed
   closed_at = closedAt
   updated_at = closedAt
   ```
9. preserve:
   ```text
   scheduled_at
   timer_start_mode_snapshot
   activated_at
   activated_by_user_id
   synchronized_ends_at
   archived_at = null
   ```
10. set:
    ```text
    assessments.updated_at = closedAt
    ```
11. commit;
12. return complete Teacher Blitz resource.

No Attempt creation.

No answer/checking writes.

---

# 29. Teacher Close and Terminal Attempts

Already-terminal Attempts are historical.

Preserve them exactly.

Teacher Close must not rewrite:

```text
status
submitted_at
finalized_at
locked_at
finalization_reason
updated_at
checking/scoring fields
```

for terminal Attempts.

Examples preserved:

```text
submitted + student_submit
timed_out_finalized + timeout_auto_submit
submitted + task_closed_auto_finalize
```

Later Stage 9 states are also terminal execution history and must not be rewritten.

---

# 30. Teacher Close Creates No Missing Work

For a Student who never started:

```text
no assessment_attempts row
```

remains correct.

For an unanswered Question:

```text
no attempt_answers row
```

remains correct.

Teacher Close does not create:

- empty Attempts;
- zero-score answer rows;
- missing-answer placeholders;
- review rows.

Stage 9 applies scoring interpretation later.

---

# 31. Teacher Close Response

Success:

```text
200 OK
```

Message:

```text
Blitz task closed successfully.
```

Return the complete:

```text
TeacherBlitzResource
```

The resource may show:

```text
status = closed
closed_at
timer snapshot/history
Questions
```

It does not add scoring results.

---

# 32. Natural Close Idempotency

Teacher Close itself does **not** use durable `Idempotency-Key`.

Its domain transition is naturally idempotent:

```text
first active -> closed
later closed -> current resource, zero writes
```

Do not add an `IdempotencyOperation` for close.

Do not write idempotency records.

---

# 33. Scheduler Command

Create:

```text
php artisan blitz:reconcile-timeouts
```

Command class conceptually:

```text
ReconcileBlitzTimeouts
```

Description:

```text
Reconcile due Blitz Attempts using server-authoritative deadlines
```

---

# 34. Scheduler Cadence

Register exactly once:

```php
Schedule::command('blitz:reconcile-timeouts')
    ->everyMinute()
    ->withoutOverlapping(5);
```

Preserve the existing Homework scheduled command unchanged:

```text
homework:reconcile-deadlines
```

Both commands coexist.

Do not merge them into one generic scheduled command in this task.

---

# 35. Global Due-Blitz Scanner

Create:

```text
App\Actions\Blitz\ReconcileDueBlitzTimeouts
```

It scans only likely candidates and calls the authoritative aggregate reconciler.

Return:

```text
{
  candidates: int,
  finalized_attempts: int,
  failures: int
}
```

Command output follows the Stage 7 style:

```text
Candidates: X; finalized attempts: Y; failures: Z.
```

Exit:

```text
SUCCESS when failures = 0
FAILURE when failures > 0
```

---

# 36. Scheduler Candidate Query

A candidate Blitz Assessment must have:

```text
blitz_tasks.status = active
```

and at least one:

```text
assessment_attempts.status = in_progress
deadline_at <= scanNow
```

same Institution/Assessment.

Scan distinct:

```text
institution_id
assessment_id
```

in deterministic batches/lazy iteration.

Do not load all due Attempt rows into memory globally.

The scan query is only an optimization.

Every candidate still calls:

```text
FinalizeTimedOutBlitzAttempts
```

which re-locks/re-checks actual current state and current time.

---

# 37. Scheduler Failure Isolation

Each candidate Blitz is reconciled independently.

If one candidate throws:

- `report($exception)`;
- increment `failures`;
- continue with later candidates.

A corrupt one-Tenant Blitz must not prevent unrelated due Blitz tasks from being processed.

The command returns failure if any candidate failed.

Do not swallow/report success for failed aggregates.

---

# 38. Scheduler Latency Rule

If an Attempt deadline is:

```text
12:00
```

and Scheduler processes it at:

```text
12:03
```

persist:

```text
finalized_at = 12:00
locked_at = 12:00
finalization_reason = timeout_auto_submit
```

not:

```text
12:03
```

The Student lost write eligibility at the authoritative deadline, not when the worker happened to run.

---

# 39. Active Synchronized Blitz After Common End

The Scheduler finalizes due existing Attempts.

It does **not** automatically transition the Blitz task itself from:

```text
active
```

to:

```text
closed
```

Teacher Close remains a separate lifecycle operation.

After synchronized common end:

- no new normal Start;
- no answer/file writes;
- existing due in-progress Attempts are timeout-finalized;
- Blitz may remain active until Teacher closes it.

Do not invent automatic close.

---

# 40. Individual Blitz Scheduler Behavior

For one active individual Blitz, Scheduler may run many times.

At each run it finalizes only Attempts whose persisted deadline is already reached.

Future-deadline Attempts remain in progress.

This is expected.

Do not close the task because one Student timed out.

---

# 41. Reconciliation and Stage 8 Attempt Resource

Update the delivered:

```text
StudentBlitzAttemptResource
```

so it can serialize execution-terminal:

```text
timed_out_finalized
submitted
```

without assuming every Start/Resume projection is `in_progress`.

Required execution fields remain:

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

For terminal Attempt:

```text
timing.remaining_seconds = 0
```

Do not expose score/checking data.

Do not make terminal Attempt editable.

---

# 42. Timeout-Reconciled Attempt Projection

For:

```text
status = timed_out_finalized
```

project exactly:

```text
submitted_at = null
finalized_at = deadline_at
finalization_reason = timeout_auto_submit
timing.remaining_seconds = 0
```

Saved answers are returned exactly as frozen.

Unanswered Questions still have no answer entry.

No checking result appears.

---

# 43. Task-Close-Finalized Attempt Projection

For:

```text
status = submitted
finalization_reason = task_closed_auto_finalize
```

project:

```text
submitted_at = null
finalized_at = locked_at = close instant
timing.remaining_seconds = 0
```

Do not label it as explicit Student Submit.

---

# 44. Student Active List After Teacher Close

Because active list filters:

```text
BlitzTask.status = active
```

a closed Blitz disappears from:

```text
GET /student/blitz/active
```

No extra special-case needed.

Do not delete recipient/history.

---

# 45. Student Detail After Teacher Close

An assigned Student accessing:

```text
GET /student/blitz/{blitz}
```

after close continues to follow the delivered BE-005 lifecycle contract:

```text
409 blitz_not_active
```

This task does not add a historical Student Blitz detail API.

Historical Attempt/result visibility can be added by later UI/result stages if required.

---

# 46. Typed Answer vs Timeout Race

Required outcomes:

## Answer mutation wins Attempt lock before deadline and commits

Answer is included in frozen work when timeout finalizer later locks.

## Timeout finalizer wins / deadline already reached

Attempt is terminal.

Later typed answer mutation:

```text
zero answer-domain mutation
409 attempt_not_editable or blitz_time_expired according to the request-path reconciliation ordering
```

For a request that itself detects due `in_progress` state and triggers reconciliation, the public error is:

```text
409 blitz_time_expired
```

No mutation after freeze.

---

# 47. File Answer vs Timeout Race

Same semantics plus blob safety.

If timeout wins:

- no persisted replacement;
- staged new blob is compensated;
- previous persisted file remains current;
- old blob is not deleted.

If file mutation commits first before deadline:

- new file becomes current;
- finalizer later freezes that committed answer.

---

# 48. Start vs Timeout Race

For existing in-progress Attempt:

## Resume transaction wins while still before deadline

Return same Attempt.

Timeout may later finalize at deadline.

## Reconciliation observes reached deadline

Attempt becomes timed out at exact deadline.

A new Start key gets:

```text
409 blitz_time_expired
```

No replacement Attempt.

A completed prior Start key remains replayable per Section 21.

---

# 49. Teacher Close vs Timeout Race

Both acquire the same parent/Attempt locks.

Whichever obtains the current locked state determines the one legal transition.

Even when Teacher Close observes an Attempt after deadline:

```text
timeout_auto_submit
```

must win.

A delayed Scheduler after Close sees no in-progress Attempt and performs zero rewrite.

A Scheduler timeout committed first remains untouched by later Close.

---

# 50. Teacher Close vs Answer/File Race

Use the existing decisive Attempt row serialization from BE-006.

If Student write commits first:

```text
Close freezes that committed state
```

If Close commits first:

```text
later write sees terminal/non-active state
zero Student answer/file mutation
```

No partial answer/file replacement after task closure.

---

# 51. Teacher Close vs Future Submit

BE-008 will use the same parent/Attempt lock ordering.

This task must leave a clean extension point:

- Submit before close may finalize `student_submit`;
- Close afterward preserves it;
- Close first may finalize task-close/timeout;
- later Submit cannot overwrite.

Do not implement Submit now.

---

# 52. Repeated Timeout Reconciliation

Calling the aggregate reconciler repeatedly:

- transitions an eligible in-progress due Attempt once;
- later calls return zero for that Attempt;
- does not change:
  ```text
  finalized_at
  locked_at
  finalization_reason
  updated_at
  ```
  merely due to repeat reconciliation.

Terminal immutability is mandatory.

---

# 53. `updated_at` Semantics

Execution-authoritative fields:

```text
finalized_at
locked_at
```

must use exact deadline/close transition times as defined.

The Eloquent `updated_at` field may represent the actual persistence update time unless the existing repository pattern deliberately sets it to the transition instant.

Do not use `updated_at` as the source of truth for deadline/close history.

Tests must assert the authoritative fields, not infer them from `updated_at`.

Teacher Close explicitly sets task/Assessment `updated_at = closedAt`.

---

# 54. Errors

## Student

Reuse/add stable:

```text
409 blitz_time_expired
409 blitz_not_active
409 attempt_not_editable
```

according to the path rules above.

No new timeout-specific synonym.

## Teacher Close

| Condition | Result |
|---|---|
| malformed/private/foreign Blitz | `404 resource_not_found` |
| Draft/Scheduled | `409 task_not_active` |
| Archived | `409 task_archived` |
| Topic archived | `409 topic_not_editable` |
| Active valid | `200` |
| already Closed | `200` no-op |

## Internal corruption

Invalid in-progress Attempt finalization shape:

```text
LogicException
```

Do not expose SQL internals.

---

# 55. `task_not_active` Infrastructure

If BE-004/BE-002 has not already exposed the existing Teacher:

```text
TaskNotActiveException
```

for Blitz lifecycle use, reuse it.

Do not create:

```text
blitz_not_active
```

for Teacher Close.

`blitz_not_active` remains the Student execution code.

---

# 56. Expected File Scope

Exact filenames may follow delivered dependency names.

## Create likely

```text
backend/app/Support/Assessment/BlitzAttemptFinalizer.php

backend/app/Actions/Blitz/FinalizeTimedOutBlitzAttempts.php
backend/app/Actions/Blitz/ReconcileDueBlitzTimeouts.php

backend/app/Actions/Teacher/CloseTeacherBlitz.php

backend/app/Console/Commands/ReconcileBlitzTimeouts.php

backend/tests/Feature/Blitz/BlitzTimeoutFinalizationTest.php
backend/tests/Feature/Teacher/TeacherBlitzCloseApiTest.php
backend/tests/Feature/Teacher/TeacherBlitzCloseConcurrencyTest.php
backend/tests/Feature/Student/StudentBlitzTimeoutReadReconciliationTest.php
backend/tests/Feature/Student/StudentBlitzTimeoutAnswerLifecycleTest.php
backend/tests/Feature/Console/ReconcileBlitzTimeoutsCommandTest.php
```

Test directory naming may follow current repository conventions (`Student`, `Teacher`, `Console`) rather than a new `Blitz` directory.

## Modify

```text
backend/routes/api.php

backend/app/Http/Controllers/Api/V1/Teacher/TeacherBlitzController.php

delivered BE-005:
ListStudentActiveBlitz
ShowStudentBlitz
StartStudentBlitzAttempt
ShowStudentBlitzAttempt
StudentBlitzAttemptResource
and directly required Blitz support

delivered BE-006:
SaveStudentBlitzAttemptAnswer
SaveStudentBlitzFileAnswer
and directly required dispatch/support

backend/routes/console.php
```

No migration.

No frontend/docs/tasks.

---

# 57. Focused Timeout Finalizer Tests

Cover:

- synchronized normal Attempt due;
- individual due;
- individual future Attempt preserved;
- mixed due/future Attempts same Blitz;
- exact deadline equality is due;
- timeout status exactly `timed_out_finalized`;
- reason exactly `timeout_auto_submit`;
- `submitted_at = null`;
- `finalized_at = locked_at = exact deadline_at`;
- answers unchanged;
- checking metadata unchanged;
- no unanswered answer fabricated;
- no Attempt for never-started Student;
- already terminal Attempt unchanged;
- repeated reconciliation zero rewrite;
- invalid in-progress finalization fields cause rollback;
- wrong aggregate/corrupt deadline causes rollback.

---

# 58. Teacher Close API Tests

Cover:

- Active synchronized Blitz close before deadline;
- Active synchronized close after common deadline;
- Active individual Blitz with mixed Student deadlines;
- exact deadline equality -> timeout;
- future deadline -> task-close;
- one close transaction may produce both reasons across different Attempts;
- already explicit-submitted Attempt unchanged;
- already timed-out Attempt unchanged;
- no Attempts -> task still closes;
- never-started Students get no Attempt;
- no fake answers;
- no checking/scoring;
- Draft -> task_not_active;
- Scheduled -> task_not_active;
- Archived -> task_archived;
- already Closed -> 200 no-op/timestamp stable;
- Topic archived -> topic_not_editable;
- full Teacher Blitz resource returned.

---

# 59. Student Read Reconciliation Tests

Cover:

## Active list

- due in-progress Attempt is timeout-finalized before final list;
- list omits Student's now-terminal normal Attempt Blitz;
- future in-progress remains listed;
- reconciler may finalize other due Attempts in same Blitz aggregate;
- no stale in-progress projection.

## Detail

- synchronized expired in-progress Attempt finalized then `blitz_time_expired`;
- individual expired in-progress Attempt finalized then `blitz_time_expired`;
- exact deadline equality;
- saved answers preserved;
- no checking/scoring.

---

# 60. Start/Resume Timeout Tests

Cover:

- new synchronized Start at common end -> time_expired, no Attempt;
- existing synchronized in-progress at deadline -> reconciled + time_expired;
- existing individual in-progress at deadline -> reconciled + time_expired;
- new failed key leaves no successful idempotency record;
- completed prior Start key remains replayable after timeout reconciliation;
- replay returns current `timed_out_finalized` Attempt without extending timer;
- new key after timeout does not create new Attempt.

---

# 61. Typed/File Timeout Wiring Tests

For typed answer:

- request before deadline succeeds;
- at deadline reconciles and returns time_expired;
- after deadline reconciles and returns time_expired;
- no answer mutation after expiry;
- prior answer preserved.

For file answer:

- at/after deadline staged blob compensated;
- Attempt timeout-finalized;
- previous File ID/content remains current;
- no new DB file replacement;
- no old blob deletion.

---

# 62. Scheduler Tests

Create/extend:

```text
ReconcileBlitzTimeoutsCommandTest
```

Verify:

- command registered;
- scheduled exactly once;
- every minute cadence;
- `withoutOverlapping(5)`;
- due synchronized Attempt finalized;
- due individual Attempt finalized;
- future individual Attempt preserved;
- task remains active after timeout reconciliation;
- exact deadline persisted;
- command output counts;
- one corrupt candidate reports failure and later valid candidate still reconciles;
- no Homework behavior changed.

---

# 63. Teacher Close Concurrency Tests

Minimum races:

1. Close vs due timeout reconciler;
2. Close vs typed answer mutation;
3. Close vs file answer mutation;
4. repeat concurrent Close.

Required invariants:

- exactly one terminal transition per Attempt;
- timeout wins when deadline already due;
- no answer/file write after freeze;
- one authoritative `closed_at`;
- no pair/cohort mutation;
- no deadlock under established test harness.

---

# 64. Direct BE-005/006 Regression

Run focused Student Blitz tests from the delivered dependencies:

```text
StudentBlitzReadApiTest
StudentBlitzAttemptStartTest
StudentBlitzAttemptStartIdempotencyTest
StudentBlitzAnswerSaveApiTest
StudentBlitzAnswerLifecycleTest
StudentBlitzFileAnswerApiTest
StudentBlitzFileAnswerLifecycleTest
```

Use exact delivered filenames.

This task intentionally changes expiry behavior from:

```text
reject only
```

to:

```text
reconcile then reject
```

Update only assertions that are directly obsolete because BE-007 now owns timeout reconciliation.

Do not weaken unrelated assertions.

---

# 65. Homework Finalization Regression

Because this task adds a parallel Blitz finalizer/Scheduler and may touch shared lifecycle/test infrastructure, run:

```bash
php artisan test \
  tests/Feature/Console/ReconcileHomeworkDeadlinesCommandTest.php \
  tests/Feature/Teacher/TeacherHomeworkLifecycleApiTest.php \
  tests/Feature/Student/StudentHomeworkDeadlineReadReconciliationTest.php
```

If shared finalizer classes are not modified, no broader Homework suite is required.

Homework remains:

```text
status = submitted
reason = homework_deadline_auto_submit
```

at Homework deadline.

Do not accidentally change Homework to `timed_out_finalized`.

---

# 66. Verification Commands

Run from:

```text
backend/
```

## 66.1 Blitz finalization / close

Use exact created filenames, conceptually:

```bash
php artisan test \
  tests/Feature/Student/StudentBlitzTimeoutReadReconciliationTest.php \
  tests/Feature/Student/StudentBlitzTimeoutAnswerLifecycleTest.php \
  tests/Feature/Teacher/TeacherBlitzCloseApiTest.php \
  tests/Feature/Teacher/TeacherBlitzCloseConcurrencyTest.php \
  tests/Feature/Console/ReconcileBlitzTimeoutsCommandTest.php
```

If a dedicated support-level finalization test exists, include it.

## 66.2 Direct BE-005/006 regression

Run the exact delivered focused Student Blitz read/start/answer/file files affected by the wiring.

## 66.3 Homework regression

```bash
php artisan test \
  tests/Feature/Console/ReconcileHomeworkDeadlinesCommandTest.php \
  tests/Feature/Teacher/TeacherHomeworkLifecycleApiTest.php \
  tests/Feature/Student/StudentHomeworkDeadlineReadReconciliationTest.php
```

## 66.4 Format

```bash
./vendor/bin/pint --test
```

No additional static-analysis command is required unless current repository configuration makes one mandatory for exactly the changed backend scope.

## 66.5 Always

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

# 67. Acceptance Criteria — Timeout Engine

- [ ] One reusable Blitz timeout reconciler exists.
- [ ] Reconciler locks authoritative parent/task/Attempt state.
- [ ] Uses persisted Attempt `deadline_at`.
- [ ] Exact deadline equality is expired.
- [ ] Timeout state is `timed_out_finalized`.
- [ ] Timeout reason is `timeout_auto_submit`.
- [ ] `submitted_at = null`.
- [ ] `finalized_at = locked_at = exact deadline_at`.
- [ ] Mixed individual deadlines handled per Attempt.
- [ ] Repeated reconciliation does not rewrite terminal history.
- [ ] No answers/Attempts fabricated.
- [ ] No Stage 9 checking/scoring.

---

# 68. Acceptance Criteria — Request Wiring

- [ ] Active list reconciles due own candidates before final projection.
- [ ] Detail reconciles due own Attempt before stale projection.
- [ ] Start/Resume reconciles reached existing Attempt deadline.
- [ ] Typed answer at/after deadline reconciles then rejects.
- [ ] File answer at/after deadline reconciles, compensates staged blob, then rejects.
- [ ] New synchronized Start after common end creates no Attempt.
- [ ] Completed Start replay survives timeout and returns current frozen logical Attempt.
- [ ] Device clock cannot extend execution.

---

# 69. Acceptance Criteria — Teacher Close

- [ ] Close route exists exactly once.
- [ ] No Idempotency-Key required.
- [ ] Active Blitz closes.
- [ ] Draft/Scheduled rejected with task_not_active.
- [ ] Archived rejected.
- [ ] Closed repeat is no-op.
- [ ] One server `closedAt` captured after locks.
- [ ] Each in-progress Attempt independently chooses timeout vs close.
- [ ] Due/equal deadline uses timeout.
- [ ] Future deadline uses task_closed_auto_finalize.
- [ ] Close transition uses `submitted`, `submitted_at = null`.
- [ ] Terminal Attempts preserved.
- [ ] No fake Attempt/answer rows.
- [ ] Assessment/Blitz timestamps updated atomically.
- [ ] No scoring/checking.

---

# 70. Acceptance Criteria — Scheduler

- [ ] `blitz:reconcile-timeouts` exists.
- [ ] Runs every minute.
- [ ] Uses `withoutOverlapping(5)`.
- [ ] Existing Homework scheduler unchanged.
- [ ] Candidate scan is bounded/lazy.
- [ ] Aggregate action rechecks current state.
- [ ] Failure isolation works.
- [ ] Scheduler delay does not shift finalization instant.
- [ ] Scheduler never auto-closes Blitz.

---

# 71. Acceptance Criteria — Concurrency

- [ ] Answer/file and finalization serialize on Attempt.
- [ ] Close vs timeout produces one terminal history.
- [ ] Timeout precedence is deterministic.
- [ ] Later Scheduler/Close cannot overwrite prior finalization.
- [ ] No Student mutation commits after finalization wins.
- [ ] File compensation preserves prior valid current file on losing race.
- [ ] Lock order remains compatible with BE-008 Submit.

---

# 72. Scope Acceptance

- [ ] No migration.
- [ ] No Student explicit Submit.
- [ ] No Submit idempotency operation.
- [ ] No Attempt exception/replacement.
- [ ] No monitoring.
- [ ] No scoring/checking.
- [ ] No frontend/docs/task changes.
- [ ] Focused Blitz tests pass.
- [ ] BE-005/006 regressions pass.
- [ ] Homework regression passes.
- [ ] Pint passes.
- [ ] `git diff --check` passes.

---

# 73. Focused Diff Self-Check

Before completion confirm:

```text
Blitz timeout reconciliation
+
Teacher Close
+
Scheduler
+
existing request-path timeout wiring
```

Verify specifically:

```text
timed_out_finalized only for Blitz timeout
timeout_auto_submit exact deadline
task_closed_auto_finalize only before deadline
no scoring/checking
no fabricated rows
no automatic Blitz close by Scheduler
no explicit Student Submit implementation
```

Confirm no unrelated refactor.

---

# 74. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. `BlitzAttemptFinalizer` transition semantics;
4. aggregate timeout reconciler behavior;
5. request-path wiring;
6. Teacher Close lifecycle and per-Attempt precedence;
7. Scheduler command/cadence/candidate behavior;
8. terminal Attempt resource behavior;
9. concurrency behavior;
10. focused Blitz finalization test results;
11. direct BE-005/006 regression results;
12. Homework regression results;
13. Pint result;
14. `git diff --check`;
15. final `git status --short`;
16. focused scope/diff self-check;
17. any blocker/deviation.

Do not claim Stage 8 backend complete.

After delivery ChatGPT performs read-only acceptance review.

`S08-BE-008` remains blocked until:

```text
S08-BE-007 = Accepted / Delivered
```

---

# 75. Implementation Readiness Verdict

```text
Scope / non-goals                    = RESOLVED
Timeout final state                  = RESOLVED
Timeout historical timestamp         = RESOLVED
Teacher-close final state            = RESOLVED
Timeout-vs-close precedence          = RESOLVED
Per-Attempt individual deadlines     = RESOLVED
Reusable reconciliation engine       = RESOLVED
Read-path reconciliation             = RESOLVED
Start/Resume reconciliation          = RESOLVED
Typed/file write reconciliation      = RESOLVED
Completed Start replay boundary      = RESOLVED
Teacher Close endpoint               = RESOLVED
Scheduler command/cadence            = RESOLVED
No automatic task close              = RESOLVED
No fabricated Attempts/answers       = RESOLVED
Stage 8/9 checking boundary           = RESOLVED
Terminal immutability                = RESOLVED
Concurrency/lock compatibility       = RESOLVED
Homework regression boundary         = RESOLVED
Acceptance criteria                  = RESOLVED
Focused verification                 = RESOLVED

Implementation Readiness Gate        = PASS
Execution dependency                 = S08-BE-006 Accepted / Delivered
```
