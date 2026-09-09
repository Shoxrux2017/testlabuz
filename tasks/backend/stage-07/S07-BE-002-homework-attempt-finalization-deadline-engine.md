# Codex Implementation Contract: S07-BE-002 — Homework Attempt Finalization and Deadline Engine

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S07-BE-002` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel Homework finalization engine + deadline reconciliation + Scheduler + Teacher close integration` |
| Depends on | `S07-BE-001 = Accepted / Delivered` before implementation |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Implementation baseline | ChatGPT re-checks/freezes current `origin/main` immediately before Codex starts |
| Readiness Gate | `PASS`, conditional on dependency above |
| Verification | focused backend lifecycle/deadline/concurrency verification only |
| Delivery | Project Owner |
| Backend block checkpoint | Stage 7 Backend Phase 2 after `S07-BE-001…007` |

Start only after `S07-BE-001` is `Accepted / Delivered`, the implementation baseline is re-checked, and Git preflight is safe.

Do not create a duplicate `CODEX-PROMPT`.

---

# 2. Context Boundary

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. delivered Stage 7 BE-001 source/tests directly required here;
5. current `CloseTeacherHomework`, Teacher Homework lifecycle access/action/controller tests;
6. current `assessment_attempts` model/enums/factories;
7. current Laravel console/scheduler bootstrap needed to register the scheduled command.

Do not read roadmap/product/architecture/database/API docs, previous task files, Stage history/indexes/closure reviews, frontend, or unrelated modules to determine requirements.

This contract resolves:

- exact Stage 7 Homework finalization state;
- deadline timestamp semantics;
- Teacher-close semantics;
- deadline-vs-close precedence;
- no-scoring boundary;
- reusable finalizer responsibilities;
- request-path deadline reconciliation action;
- Scheduler/batch behavior;
- tenant scope;
- locking/order requirements;
- obsolete Stage 6 close-guard removal;
- idempotency/no-op behavior;
- concurrency coverage;
- verification.

If current delivered code materially conflicts with the contract, return `BLOCKED` with exact evidence. Do not redesign.

---

# 3. Goal

Replace the temporary Stage 6 behavior:

```text
Teacher close + any in_progress Attempt
=> 409 conflict
```

with the Stage 7 authoritative behavior:

```text
Teacher close
=> atomically freeze every existing in_progress Homework Attempt
=> close Homework
```

and implement server-authoritative Homework deadline reconciliation that can run:

- explicitly from later Student request paths;
- automatically from Laravel Scheduler.

At the end of this task:

```text
in_progress Homework Attempt
  -- explicit future Submit (BE-007) -->
  submitted

in_progress Homework Attempt
  -- Homework deadline -->
  submitted + homework_deadline_auto_submit

in_progress Homework Attempt
  -- Teacher close before deadline -->
  submitted + task_closed_auto_finalize
```

`S07-BE-002` implements only the two automatic paths.

No answer checking/scoring occurs here.

---

# 4. Locked Stage 7 Finalization State

For Stage 7 Homework automatic finalization, the Attempt must become:

```text
status = submitted
submitted_at = null
finalized_at = authoritative finalization instant
locked_at = finalized_at
finalization_reason = reason-specific value
```

The two reasons in this task are:

```text
homework_deadline_auto_submit
task_closed_auto_finalize
```

Do not use:

```text
timed_out_finalized
timeout_auto_submit
waiting_for_teacher_review
checked
```

for Homework deadline or Teacher-close finalization.

`timed_out_finalized`/`timeout_auto_submit` remain Blitz concerns.

Do not mutate:

```text
earned_points
normalized_score
scoring_completed_at
official_score_eligible
```

during Stage 7 automatic finalization.

Do not mutate any Student answer payload.

Do not change `attempt_answers.checking_status` from `pending`.

Do not create missing `attempt_answers` rows for unanswered Questions.

Unanswered Questions are interpreted as zero later by Stage 9 scoring.

---

# 5. Explicit Non-Goals

Do not implement:

- Student Homework list/detail endpoints;
- Student Attempt Start/resume;
- official result-pair first-Attempt locking;
- Student answer save/replace;
- file upload/download;
- Student final Submit;
- Student idempotency claim/replay service;
- automatic answer checking;
- Teacher manual review;
- awarded points;
- Attempt scoring;
- official Homework score selection;
- Topic result recalculation;
- Blitz timeout behavior;
- frontend;
- E2E/seeders;
- docs/task bookkeeping;
- schema migration;
- new package/dependency;
- unrelated refactor.

BE-002 may consume the BE-001 persistence foundation but must not expand it.

---

# 6. Shared Homework Attempt Finalizer

Create:

```text
backend/app/Support/Assessment/HomeworkAttemptFinalizer.php
```

This class owns the exact field transition for an already locked Homework Attempt.

It must contain exactly the two automatic Stage 7 operations required here:

```text
finalizeAtDeadline(AssessmentAttempt $attempt, CarbonInterface $deadlineAt): bool
finalizeAtClose(AssessmentAttempt $attempt, CarbonInterface $closedAt): bool
```

The exact concrete Carbon interface/type may follow current project conventions, but callers must pass an authoritative server instant.

## 6.1 Common precondition

Both methods operate only when:

```text
attempt.status = in_progress
```

If the Attempt is already any terminal/review state, return:

```text
false
```

with **zero writes**.

Do not rewrite existing reason/timestamps.

## 6.2 Deadline transition

`finalizeAtDeadline` sets:

```text
status = submitted
submitted_at = null
finalized_at = deadlineAt
locked_at = deadlineAt
finalization_reason = homework_deadline_auto_submit
```

Save once and return `true`.

## 6.3 Teacher-close transition

`finalizeAtClose` sets:

```text
status = submitted
submitted_at = null
finalized_at = closedAt
locked_at = closedAt
finalization_reason = task_closed_auto_finalize
```

Save once and return `true`.

## 6.4 Timestamp rule

Do not set `updated_at` manually to the deadline when reconciliation occurs later.

Normal Eloquent `updated_at` may represent the actual persistence/reconciliation write instant.

The historical semantic instant is:

```text
finalized_at / locked_at
```

For a delayed deadline reconciliation these remain exactly the Homework deadline.

## 6.5 No answer/scoring dependency

`HomeworkAttemptFinalizer` must not query or mutate:

```text
attempt_answers
typed answer tables
answer_files
Question correct-answer configuration
official_task_scores
topic_results
```

It is a submission-freezing service, not a checking engine.

---

# 7. `FinalizeHomeworkAttemptsAtDeadline`

Create:

```text
backend/app/Actions/Homework/FinalizeHomeworkAttemptsAtDeadline.php
```

This is the single authoritative per-Homework deadline reconciliation use case.

Required public invocation:

```text
__invoke(string $institutionId, string $assessmentId): int
```

Return value:

```text
number of Attempts transitioned by this invocation
```

A no-op returns `0`.

## 7.1 Tenant-safe resolution

Inside one DB transaction, resolve/lock:

```text
Assessment
```

by:

```text
institution_id = supplied institution
id = supplied assessment
type = homework
```

then resolve/lock its:

```text
HomeworkAssignment
```

by the same Institution + Assessment.

If the exact tenant-owned Homework aggregate does not exist, return `0`.

This is an internal use case, not a public existence-disclosure endpoint.

Do not resolve an Assessment globally and then compare Institution afterward.

## 7.2 Eligible Homework lifecycle

Standalone deadline reconciliation mutates only:

```text
HomeworkStatus::Active
```

For:

```text
draft
closed
archived
```

return `0`.

A closed Homework should already have had its in-progress work reconciled by the close transaction.

## 7.3 Deadline boundary

After the Assessment/Homework row locks are acquired, capture:

```text
observedAt = now()
```

Deadline is passed when:

```text
deadline_at != null
AND observedAt >= deadline_at
```

If:

```text
deadline_at = null
```

or:

```text
observedAt < deadline_at
```

return `0` with zero writes.

Device/client time is irrelevant.

## 7.4 Lock relevant Attempts

When deadline is passed, lock matching Attempts:

```text
institution_id = Homework Institution
assessment_id = Homework Assessment
status = in_progress
```

Order by:

```text
id
```

before `FOR UPDATE` to keep lock acquisition deterministic.

Do not load another Institution's rows.

## 7.5 Finalization instant

For every still-locked `in_progress` Attempt call:

```text
HomeworkAttemptFinalizer::finalizeAtDeadline(...)
```

with exactly:

```text
homework_assignments.deadline_at
```

not `observedAt`.

Thus a Scheduler execution at 10:03 for a 10:00 deadline records:

```text
finalized_at = 10:00
locked_at = 10:00
```

while `updated_at` may reflect 10:03.

## 7.6 No fabricated Attempts

If there are no `in_progress` rows:

```text
return 0
```

Do not create an Attempt for a recipient who never started.

Do not consume unused attempt numbers by creating placeholder rows.

---

# 8. Reuse Inside an Existing Locking Transaction

`CloseTeacherHomework` already owns a larger Teacher-authorized aggregate transaction.

To avoid duplicating deadline semantics, `FinalizeHomeworkAttemptsAtDeadline` must expose one focused method for already locked state:

```text
finalizeLocked(
    HomeworkAssignment $homework,
    Collection $lockedAttempts,
    CarbonInterface $observedAt
): ?int
```

Contract:

```text
null => Homework deadline is absent or not yet reached; zero writes
int  => deadline is reached; value is count of newly finalized Attempts
```

Preconditions:

- caller already holds the Homework row lock;
- caller already holds locks for the relevant Assessment Attempts;
- all passed Attempts are from the same Institution/Assessment aggregate.

When deadline is reached, this method uses:

```text
homework.deadline_at
```

as the finalization instant and delegates every transition to `HomeworkAttemptFinalizer`.

Do not open a second independent transaction inside `finalizeLocked`.

The standalone `__invoke()` and Teacher close must share this same locked-state deadline logic.

---

# 9. Teacher Close Integration

Modify:

```text
backend/app/Actions/Teacher/CloseTeacherHomework.php
```

Preserve existing:

- privacy-safe Teacher resolution;
- Teacher current Group membership authorization;
- Topic/Assessment/Homework locking;
- draft → `task_not_active`;
- archived → `task_archived`;
- archived Topic → `topic_not_editable`;
- already-closed idempotent success;
- result-pair lock;
- final Teacher response/resource shape.

Remove only the temporary Stage 6 “in-progress Attempt blocks close” behavior.

## 9.1 Required locked sequence

Within the existing transaction:

1. lock Teacher/Group/membership/Topic/Assessment/Homework using current access;
2. apply existing lifecycle checks/no-op behavior;
3. lock relevant Topic result-pair as today;
4. lock all Homework Attempts deterministically as today;
5. capture one server instant:

```text
transitionedAt = now()
```

6. call:

```text
FinalizeHomeworkAttemptsAtDeadline::finalizeLocked(
    $homework,
    $attempts,
    $transitionedAt
)
```

7. if result is `null`, deadline had not passed:
   - finalize every still-`in_progress` Attempt with
     `HomeworkAttemptFinalizer::finalizeAtClose($attempt, $transitionedAt)`;
8. if result is an integer, deadline had already passed:
   - do **not** replace deadline reasons with close reasons;
9. close Homework:

```text
status = closed
closed_at = transitionedAt
updated_at = transitionedAt
```

10. update owning Assessment `updated_at = transitionedAt` as current code does;
11. commit atomically;
12. return the existing Teacher Homework response.

## 9.2 Deadline precedence

At:

```text
transitionedAt >= deadline_at
```

deadline wins even if Scheduler has not run yet.

The in-progress Attempt becomes:

```text
status = submitted
submitted_at = null
finalized_at = deadline_at
locked_at = deadline_at
finalization_reason = homework_deadline_auto_submit
```

The Homework itself still closes at:

```text
closed_at = transitionedAt
```

At:

```text
transitionedAt < deadline_at
```

Teacher close wins:

```text
finalized_at = transitionedAt
finalization_reason = task_closed_auto_finalize
```

At exact equality:

```text
transitionedAt == deadline_at
```

deadline wins.

## 9.3 Existing terminal Attempts

Do not rewrite:

- submitted Attempts;
- future Stage 9 review/checked Attempts;
- any already finalized reason/timestamp.

Only current `in_progress` rows transition.

## 9.4 Never-started recipients

Teacher close must not create Attempts for:

```text
assessment_students
```

recipients with no Attempt history.

## 9.5 Atomicity

Auto-finalization + Homework close is one transaction.

If any write fails, neither the close nor partial Attempt finalization may commit.

---

# 10. Remove the Obsolete Stage 6 Close Guard

The current temporary exception becomes invalid after BE-002.

Delete:

```text
backend/app/Exceptions/Teacher/HomeworkHasInProgressAttemptException.php
```

Remove its import/render registration from:

```text
backend/bootstrap/app.php
```

Remove the now-unused:

```text
ApiErrorResponse::homeworkHasInProgressAttempt(...)
```

from:

```text
backend/app/Support/ApiErrorResponse.php
```

Do not remove the general:

```text
business_conflict
```

error code/method; it is used elsewhere.

Before deletion, Codex may confirm current references are limited to this obsolete close path/renderer. If a new delivered dependency legitimately uses the exception at implementation baseline, return `BLOCKED` instead of deleting it blindly.

---

# 11. Scheduler Batch Action

Create:

```text
backend/app/Actions/Homework/ReconcileDueHomeworkDeadlines.php
```

Purpose:

> find due active Homework that actually still has in-progress Attempts and invoke the authoritative per-Homework deadline action.

Required invocation:

```text
__invoke(): array
```

Return exact shape:

```php
[
    'candidates' => int,
    'finalized_attempts' => int,
    'failures' => int,
]
```

## 11.1 Candidate query

Select from active `homework_assignments` only where:

```text
deadline_at IS NOT NULL
deadline_at <= scanNow
```

and where at least one matching:

```text
assessment_attempts.status = in_progress
```

exists for the same:

```text
institution_id + assessment_id
```

Do not scan every historical expired Homework on every minute.

## 11.2 Pagination

Do not use offset pagination because successful processing removes candidates from the `EXISTS(in_progress)` result set and offset paging could skip rows.

Use deterministic keyset/chunking based on the unique Homework key:

```text
assessment_id
```

with a reasonable fixed chunk size such as:

```text
100
```

Use the repository/Laravel equivalent of `lazyById`/keyset iteration.

## 11.3 Per-candidate processing

For each candidate call:

```text
FinalizeHomeworkAttemptsAtDeadline(
    institution_id,
    assessment_id
)
```

Accumulate returned finalized counts.

The per-Homework action re-checks current state/time under row locks; the scan is only candidate discovery and is not authoritative.

## 11.4 Failure isolation

One unexpected candidate failure must not prevent unrelated later candidates from being attempted.

For each candidate:

- catch unexpected `Throwable` at the batch boundary;
- use normal Laravel `report($exception)` or current safe reporting convention;
- increment `failures`;
- continue;
- do not log Student answer contents, tokens, or private payloads.

Do not swallow the aggregate failure: the Console command below returns failure status when `failures > 0`.

---

# 12. Console Command

Create:

```text
backend/app/Console/Commands/ReconcileHomeworkDeadlines.php
```

Signature:

```text
homework:reconcile-deadlines
```

Purpose text should clearly describe server-side reconciliation of due Homework Attempts.

Command behavior:

1. invoke `ReconcileDueHomeworkDeadlines`;
2. optionally emit one compact operational summary with counts only;
3. return:

```text
Command::SUCCESS when failures = 0
Command::FAILURE when failures > 0
```

No Student content in console output.

Do not duplicate candidate/finalization logic in the command.

---

# 13. Laravel Scheduler Registration

Modify:

```text
backend/routes/console.php
```

Preserve the existing `inspire` command.

Import Laravel Scheduler facade and register exactly one schedule for:

```text
homework:reconcile-deadlines
```

with:

```text
everyMinute()
withoutOverlapping(5)
```

Do not add `onOneServer()` as a correctness dependency.

Database row locks/idempotent state transitions remain the correctness boundary even if multiple application nodes invoke the command.

Do not change deployment cron/process configuration in this task.

The application still requires the normal Laravel production scheduler runner (`schedule:run`/equivalent infrastructure) outside repository business logic.

---

# 14. Request-Path Reconciliation Contract for Later Tasks

BE-002 creates the reusable:

```text
FinalizeHomeworkAttemptsAtDeadline
```

but no Student routes exist yet.

Later Stage 7 tasks must call it before relevant:

- Student Homework/Attempt reads;
- Attempt Start;
- answer writes;
- final Submit.

Do not implement those integrations in BE-002.

Scheduler latency can therefore never become permission to write after deadline once those request paths are delivered.

---

# 15. Concurrency Contract

All decisions are made from locked current database state.

## 15.1 Deadline reconciliation vs itself

Two concurrent deadline reconciliations for the same Homework:

- serialize on Homework/Attempt locks;
- first transition wins;
- second sees no `in_progress` work;
- final reason/timestamps are written once.

## 15.2 Deadline reconciliation vs Teacher close

If deadline is already reached when locked close state is evaluated:

```text
homework_deadline_auto_submit
```

wins.

If Teacher close validly locks/evaluates before deadline:

```text
task_closed_auto_finalize
```

wins and later deadline reconciliation is a no-op because Homework/Attempts are already terminal/closed.

No terminal reason may be rewritten by the second operation.

## 15.3 Future Submit race

BE-002 must make the finalizer/lock structure compatible with the later BE-007 contract:

```text
Submit vs deadline vs close => exactly one transition from in_progress
```

Do not implement Submit now.

## 15.4 Lock ordering

Teacher close retains its current broader order:

```text
Group
-> current Teacher membership
-> Topic
-> Assessment
-> Homework
-> result pair
-> Attempts ordered by id
```

Standalone deadline reconciliation needs only:

```text
Assessment
-> Homework
-> Attempts ordered by id
```

It must never acquire Group/Topic locks after holding Assessment/Homework, preventing a reverse lock dependency with Teacher close.

---

# 16. No-Op / Historical Timestamp Rules

Required write-free cases:

- standalone reconciliation before deadline;
- Homework without deadline;
- non-active Homework;
- due Homework with no in-progress Attempts;
- repeated reconciliation after finalization;
- already-closed Teacher close;
- finalizer called for an already-terminal Attempt.

A retry/no-op must not rewrite:

```text
submitted_at
finalized_at
locked_at
finalization_reason
Attempt updated_at
Homework closed_at
```

except the first successful lifecycle transition itself.

---

# 17. Expected Files

## Create

```text
backend/app/Support/Assessment/HomeworkAttemptFinalizer.php
backend/app/Actions/Homework/FinalizeHomeworkAttemptsAtDeadline.php
backend/app/Actions/Homework/ReconcileDueHomeworkDeadlines.php
backend/app/Console/Commands/ReconcileHomeworkDeadlines.php

backend/tests/Feature/Homework/HomeworkDeadlineFinalizationTest.php
backend/tests/Feature/Homework/HomeworkDeadlineFinalizationConcurrencyTest.php
backend/tests/Feature/Console/ReconcileHomeworkDeadlinesCommandTest.php
```

## Modify

```text
backend/app/Actions/Teacher/CloseTeacherHomework.php
backend/bootstrap/app.php
backend/app/Support/ApiErrorResponse.php
backend/routes/console.php

backend/tests/Feature/Teacher/TeacherHomeworkLifecycleApiTest.php
```

Modify `TeacherHomeworkLifecycleConcurrencyTest.php` only if the smallest safe way to reuse its existing PostgreSQL worker helpers is to extend that file. Prefer a separate focused BE-002 concurrency test if possible.

## Delete

```text
backend/app/Exceptions/Teacher/HomeworkHasInProgressAttemptException.php
```

No migration, routes/api.php, Student API, scoring, docs, frontend or E2E files.

---

# 18. `HomeworkDeadlineFinalizationTest`

Use `RefreshDatabase` and frozen server time.

At minimum cover:

## 18.1 Before deadline

Active Homework, future deadline, one in-progress Attempt:

```text
FinalizeHomeworkAttemptsAtDeadline => 0
```

Attempt unchanged.

## 18.2 Exact deadline

At:

```text
now == deadline_at
```

one or more in-progress Attempts become:

```text
status = submitted
submitted_at = null
finalized_at = deadline_at
locked_at = deadline_at
finalization_reason = homework_deadline_auto_submit
```

## 18.3 Delayed reconciliation

If deadline = 10:00 and reconciliation = 10:03:

```text
finalized_at = 10:00
locked_at = 10:00
```

not 10:03.

## 18.4 Saved answer preservation

Create an BE-001 `AttemptAnswer` + typed payload before deadline.

After reconciliation verify:

- payload unchanged;
- `checking_status = pending`;
- `awarded_points = null`;
- no scoring/review fields written.

## 18.5 Unanswered/never-started

Have another assigned Student with no Attempt.

After deadline:

```text
no fabricated Attempt
no fabricated AttemptAnswer
```

## 18.6 Terminal Attempt preservation

Existing submitted/finalized Attempt remains unchanged.

## 18.7 Null deadline

No-op.

## 18.8 Non-active Homework

Draft/closed/archived standalone reconciliation does not mutate Attempts.

## 18.9 Retry

After successful reconciliation:

- advance test clock;
- invoke again;
- returns `0`;
- terminal reason/finalized/locked/updated timestamps unchanged.

## 18.10 Tenant scope

Calling the internal action with the wrong Institution ID does not mutate the target Homework/Attempts.

---

# 19. Teacher Lifecycle Test Updates

Update the old Stage 6 close-guard expectation in:

```text
TeacherHomeworkLifecycleApiTest
```

to the final Stage 7 behavior.

At minimum add/adjust:

## 19.1 Pre-deadline close

Freeze clock before deadline.

Close active Homework with in-progress Attempt.

Expect existing Teacher endpoint success and:

```text
Homework = closed
Attempt.status = submitted
Attempt.submitted_at = null
Attempt.finalized_at = close instant
Attempt.locked_at = close instant
Attempt.finalization_reason = task_closed_auto_finalize
```

## 19.2 Deadline-passed close

Deadline occurred before close, Scheduler not previously invoked.

Teacher close still succeeds.

Expect:

```text
Attempt.finalized_at = deadline_at
Attempt.finalization_reason = homework_deadline_auto_submit
Homework.closed_at = close instant
```

## 19.3 Equality

At exactly deadline, deadline reason wins.

## 19.4 Multiple Attempt states

Close affects only `in_progress`.

Existing terminal Attempts keep their timestamps/reasons.

## 19.5 Saved answers

Close freezes Attempt only; Student answer content/checking state remains unchanged.

## 19.6 Never-started recipient

No Attempt created.

## 19.7 Repeated close

Second close remains existing write-free idempotent success and does not rewrite Attempt/Homework transition timestamps.

Preserve all unrelated existing lifecycle tests.

---

# 20. Scheduler / Command Tests

Create:

```text
ReconcileHomeworkDeadlinesCommandTest
```

At minimum verify:

## Command discovery

```text
homework:reconcile-deadlines
```

is registered.

## Schedule

Exactly one scheduled event targets the command and uses:

```text
every minute
without overlapping
```

Do not rely only on string snapshot if Laravel exposes a stable schedule event object.

## Due work across Institutions

Create due active Homeworks in at least two Institutions, each with in-progress Attempts.

Run command.

Both are reconciled tenant-safely.

## Future/null deadlines

Ignored.

## No in-progress work

Expired Homework without in-progress Attempts is not materially changed.

## Command exit

Normal run:

```text
SUCCESS
```

A focused mocked/controlled candidate failure should verify batch failure isolation and command:

```text
FAILURE
```

while another independent candidate is still attempted.

Do not assert sensitive exception text in command output.

---

# 21. PostgreSQL Concurrency Test

Create:

```text
HomeworkDeadlineFinalizationConcurrencyTest
```

Use the repository's existing process/PostgreSQL lock-test pattern rather than sleeps.

At minimum prove one real lock serialization race for the same due Homework:

```text
deadline reconciliation
vs
Teacher close
```

Required final invariant:

```text
Homework = closed
Attempt = submitted
finalization_reason = homework_deadline_auto_submit
finalized_at = deadline_at
```

with one stable terminal transition.

The second worker must actually enter a PostgreSQL lock wait; do not simulate concurrency only with sequential method calls.

Keep the concurrency test focused. Submit races belong to BE-007.

---

# 22. Direct Regression Scope

Run the new/changed BE-002 tests plus the directly affected existing lifecycle tests:

```text
tests/Feature/Teacher/TeacherHomeworkLifecycleApiTest.php
tests/Feature/Teacher/TeacherHomeworkLifecycleConcurrencyTest.php
```

Also run BE-001 persistence tests because BE-002 now relies on its Attempt/Answer invariants:

```text
tests/Feature/Persistence/StudentAnswerSubmissionSchemaInspectionTest.php
tests/Feature/Persistence/StudentAnswerSubmissionPersistenceTest.php
tests/Feature/Persistence/StudentAnswerSubmissionFactoryModelTest.php
```

Do not run the full backend suite.

---

# 23. Verification

From the backend environment use the repository's normal Docker/Sail wrapper.

Run formatter/static checks required for changed PHP files.

Then run exactly:

```bash
php artisan test \
  tests/Feature/Homework/HomeworkDeadlineFinalizationTest.php \
  tests/Feature/Homework/HomeworkDeadlineFinalizationConcurrencyTest.php \
  tests/Feature/Console/ReconcileHomeworkDeadlinesCommandTest.php \
  tests/Feature/Teacher/TeacherHomeworkLifecycleApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkLifecycleConcurrencyTest.php \
  tests/Feature/Persistence/StudentAnswerSubmissionSchemaInspectionTest.php \
  tests/Feature/Persistence/StudentAnswerSubmissionPersistenceTest.php \
  tests/Feature/Persistence/StudentAnswerSubmissionFactoryModelTest.php
```

Then repository root:

```bash
git diff --check
```

and focused diff/scope review.

Do not run:

- full backend suite;
- frontend tests/build;
- E2E/integration Stage runner.

---

# 24. Acceptance Criteria

PASS only if all are true.

## Finalization

- deadline automatic path ends Homework Attempt in `submitted`;
- Teacher-close automatic path ends Homework Attempt in `submitted`;
- `submitted_at` remains null for both;
- exact finalization reasons are correct;
- deadline uses exact `homework_assignments.deadline_at`;
- close-before-deadline uses one captured close instant;
- no answer/checking/scoring mutation occurs;
- no unanswered/never-started rows are fabricated.

## Deadline engine

- one tenant-safe per-Homework deadline action exists;
- it locks current state and is idempotent;
- exact `>=` boundary is used;
- repeated calls are write-free;
- later Student request tasks can reuse it.

## Scheduler

- candidate scan includes only active due Homework with current in-progress Attempts;
- keyset pagination avoids skip-on-shrinking-result bugs;
- per-candidate action re-checks locked current state;
- one candidate failure does not stop unrelated candidates;
- command is scheduled every minute with `withoutOverlapping(5)`.

## Teacher close

- no in-progress conflict guard remains;
- close + auto-finalization are one transaction;
- deadline already passed => deadline reason wins;
- pre-deadline close => close reason wins;
- terminal Attempts remain unchanged;
- repeated close remains no-op.

## Cleanup

- obsolete `HomeworkHasInProgressAttemptException` deleted;
- obsolete renderer/import/API error helper removed;
- general business-conflict behavior preserved.

## Concurrency

- PostgreSQL test proves deadline reconciliation and Teacher close serialize;
- final terminal reason/timestamps cannot be double-written/replaced.

## Scope

- no Student HTTP endpoints;
- no Attempt Start;
- no Submit;
- no upload behavior;
- no scoring/manual review/official score;
- no schema/docs/frontend/E2E changes;
- no new dependency.

## Verification

- focused tests pass;
- named regressions pass;
- formatter/static checks pass;
- `git diff --check` passes;
- focused self-review finds no scope leakage.

---

# 25. Locked Implementation Decisions

These are decisions, not suggestions:

```text
Homework auto-finalized Stage 7 status = submitted
deadline finalization instant = exact Homework deadline
deadline boundary = server_now >= deadline_at
Teacher close before deadline = task_closed_auto_finalize
deadline reached before/equal close = homework_deadline_auto_submit
no Stage 7 checking/scoring
no fabricated Attempts/answers
shared field transition = HomeworkAttemptFinalizer
authoritative per-Homework reconciliation = FinalizeHomeworkAttemptsAtDeadline
scheduler command = homework:reconcile-deadlines
scheduler cadence = everyMinute
overlap lock = withoutOverlapping(5)
batch candidate pagination = keyset, not offset
PostgreSQL row locks = concurrency boundary
```

Codex must not substitute:

- queue-only delayed finalization;
- frontend timers as authority;
- Scheduler-only enforcement;
- `checked`/`waiting_for_teacher_review` at finalization;
- placeholder unanswered rows;
- global unscoped Attempt queries;
- cache locks as the sole correctness boundary.

---

# 26. Completion Report

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
2. changed/deleted files and purpose;
3. exact focused verification commands/results;
4. directly affected regressions;
5. concurrency evidence;
6. `git diff --check`;
7. scope/non-goal confirmation;
8. deviations/blockers;
9. final `git status --short`.

Do not claim `Accepted`.

Do not commit/push/create PR/update Stage bookkeeping unless explicitly instructed later.
