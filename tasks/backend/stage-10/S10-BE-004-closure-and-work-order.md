# Implementation Contract: S10-BE-004 — Closure and Work-Order Rules

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S10-BE-004` |
| Stage | `Stage 10 — Final Result and Understanding Assessment` |
| Area | `Backend` (new endpoints; Topic archive, review, Homework Start, Blitz activation and Blitz Start behavior) |
| Status | `Approved` |
| Depends on | `S10-BE-003` delivered (PR #319, `main` `48a607a`) |
| Implementation baseline | `origin/main` `48a607a` |
| Owner decisions applied | `S10-D7` (bulk close, archive auto-close), `S10-D8` (Homework before Blitz), `S10-D9` (closure needs finished work) |
| Technical decisions applied | `S10-T2` (snapshot holds Attempt ids), `S10-T6` (locks, idempotent closure), `S10-T7` (`result_closed` guards) |
| Implementation | Claude |
| Delivery | Claude opens the PR and merges it after review `PASS` and green verification |
| Blocks | `S10-BE-PHASE-2` |

This file is the complete task contract (normative source: `S10-DOC-001` §§8.3, 10.2, 12.6-12.8, 13, 15;
`docs/09` §§15.6, 17.3, 19.1, 20.3, 23.1-23.2, 25.8-25.11; `docs/07` §§17.8, 33).

## 2. Goal

Teachers close Topic results (one Student, all ready results, and automatically at Topic archive) into a
frozen snapshot; a closed result blocks the actions that could still change it; and the official
Homework comes before the official Blitz (`S10-D8`).

## 3. Scope

### Included

1. Single and bulk close, the closure snapshot, archive auto-close (§5.1-§5.3).
2. `409 result_closed` guards on review corrections and the official Homework Start (§5.4).
3. `S10-D8`: draft-Homework activation conflict, Homework close at official Blitz activation, Blitz Start bar (§5.5).
4. Three new 409 codes (§5.6), deliberate Stage 8/9 test updates (§5.7), real-concurrency tests (§7).

### Non-goals

- Any Student, Teacher or Parent screen (frontend plan); the Blitz read announcing the bar.
- Any change to the release, read or comment endpoints of `S10-BE-002`/`003` (the comment guard exists).
- Rerunning or rewriting the historical Stage 8/9 end-to-end harnesses (`frontend/integration_test/stage8_*`,
  `stage9_*`); their seeders change only if a PHP seeder test breaks.

## 4. Current Implementation Context

- `TopicResultReader::forTopic/forStudent` (no locks; `closable = terminal && workFinished`; a closed row
  yields `closedView`, `terminal = false`), `TopicResultView`/`TopicResultSideView`, `TopicResultReleases`
  (rows `FOR UPDATE` in id order, create missing), `TopicResultActionOutcome`, `TopicResultBulkOutcome`,
  `TeacherTopicResultBulkResource`, `ShowTeacherTopicResult`, `TeacherTopicLifecycleAccess::lockTopic`.
- `topic_results` check constraints (migration `2026_10_04_000000`): open rows have every closure column
  null; closed rows need `closed_by_user_id`, `closure_reason`, `closed_outcome`, `homework_assessment_id`
  and both side states; `blitz_assessment_id` null exactly when `blitz_state = not_designated`; a side has
  its Attempt id and score exactly when `ready`; calculated / Not completed column sets; method ↔ consistency.
- `ArchiveTeacherTopic`: `lockTopic` → idempotent archived return → status check →
  `TeacherTopicOpenAssessmentGuard::lockAndEnsureResolved` (task Assessments and rows `FOR UPDATE`) →
  `$transitionedAt = now()` → archive. `CloseTeacherTopic` closes no result and stays unchanged.
- `ReviewTeacherSubmission`: pre-transaction 404 / `automatic_checking_pending` / 422; in the transaction
  `RecipientScoringLock::lock` (Topic `FOR SHARE` first), answers `FOR UPDATE`, re-resolve, re-checked
  `automatic_checking_pending`, item re-validation, writes.
- `StartStudentHomeworkAttempt`: Topic `FOR UPDATE` first; replay; `assertActive`; `$official`; deadline;
  resume; `attempts_exhausted`; pair `locked_at`; create.
- `ActivateTeacherBlitz`: `lockBlitz` (Topic `FOR UPDATE`); replay/claim; already active no-op; lifecycle;
  `lockResultPair` (non-null only for the pair's Blitz); `lockSettings`; timer-mode check
  (`institution_settings_incomplete`); `TeacherOfficialAssessmentCohort::lock` (both official Assessments,
  their Homework/Blitz rows and every Attempt of both official tasks `FOR UPDATE`); questions; validate;
  `$activatedAt = now()->utc()->startOfSecond()`; cohort apply; writes.
- `CloseTeacherHomework` closes a locked Homework: `FinalizeHomeworkAttemptsAtDeadline::finalizeLocked`
  (null when no passed deadline), else `HomeworkAttemptFinalizer::finalizeAtClose` per Attempt (freezes
  `in_progress` as `task_closed_auto_finalize`, queues the after-response check), then status/`closed_at`.
- `StartStudentBlitzAttempt`: Topic `FOR UPDATE` first; `$official`; Attempts of both official tasks
  locked; replay; intent conflicts; `timing->assertExecutable`; an existing #1/#2 is returned; pair
  `locked_at`; create.
- Concurrency test infrastructure: worker processes via `proc_open`, `pg_blocking_pids` waits
  (`RunsBlitzExceptionWorkers` + `tests/Support/BlitzExceptionWorker.php`,
  `RunsStudentHomeworkSubmitConcurrency`, `TeacherSubmissionReviewConcurrencyTest`,
  `HomeworkDeadlineFinalizationConcurrencyTest`).

## 5. Exact Contract

### 5.1 Single close

`POST /api/v1/teacher/topics/{topic}/results/{student}/close`. Request `TeacherTopicLifecycleRequest`
(empty body or `{}`, no query). Access as `S10-BE-002` §5.1 (`resolveTopic`; `{student}` UUID of a cohort
Student, else `404`).

Transaction (`S10-T6`, `S10-DOC-001` §13.1): `lockTopic` → the Student's Attempts of the official Homework
and Blitz `FOR SHARE` in one query ordered by Attempt id → the live result from `TopicResultReader` → the
row `FOR UPDATE` (created when missing) → evaluate and write. First match:

1. The row is closed → `200` (no change).
2. Not closable (`TopicResultView::closable` false: not terminal, or work not finished) →
   `409 result_not_ready_for_closure`.
3. Write the snapshot (§5.2) with `closure_reason = teacher`, `closed_by_user_id` = the Teacher → `200`.

Response after commit: `200 {"message": "Topic result closed.", "data": <S10-BE-002 detail>}`.

### 5.2 Closure snapshot

One `closedAt = now()` per transaction. From the live `TopicResultView`: `closed_at`, `closed_by_user_id`,
`closure_reason`, `closed_outcome` (`calculated` or `not_completed` from the status),
`missing_component`, `homework_assessment_id`, `blitz_assessment_id`, `homework_state`, `blitz_state`,
the Attempt id and score of each `ready` side, and for `calculated` `score_difference`,
`acceptable_difference_used`, `calculation_method`, `consistency`, `final_score`, `category_score`,
`category_code`, `category_min_score_used`, `category_max_score_used`. The comment and release columns
are kept. The reader then serves the row as a closed result (frozen; never reads current settings).

### 5.3 Bulk close and archive auto-close

- `POST /api/v1/teacher/topics/{topic}/results/close` (same request): every cohort Student in one
  transaction, the same lock order (all official Attempts of the cohort `FOR SHARE` in one query ordered
  by id); rule 1 → `skipped.already_done`, rule 2 → `skipped.not_ready`, rule 3 → closed. Response
  `200 {"message": "Topic results closed.", "data": {"processed": n, "skipped": {"already_done": a,
  "not_ready": b}}}`.
- `POST /teacher/topics/{topic}/archive`: request, response and conflicts unchanged. A real archive (not
  the idempotent already-archived return) closes, inside its transaction, after the open-assessment
  guard and before the archive write, every terminal open result of the cohort with
  `closure_reason = topic_archived`, `closed_by_user_id` = the archiving Teacher and `closed_at` = the
  archive `$transitionedAt` (closable at archive = terminal, `S10-DOC-001` §8.3). Same Attempt
  `FOR SHARE` lock first. Waiting results stay open. A Topic without a cohort archives as before.
  `POST /teacher/topics/{topic}/close` closes no result.

### 5.4 `409 result_closed` guards (`S10-T7`)

- **Review** (`ReviewTeacherSubmission`): inside the scoring-lock transaction, after the re-checked
  `automatic_checking_pending` and before the item re-validation and any write — when an item names an
  answer whose locked `checking_status` is `teacher_checked`, the task is official
  (`OfficialTaskDesignation::isOfficial`) and the Student's `topic_results` row of that Topic is closed →
  `409 result_closed`, nothing written. A first review (only `waiting_for_teacher_review` answers) stays
  allowed and never changes the snapshot. Invalid items still get the pre-transaction `422` first.
- **Official Homework Start** (`StartStudentHomeworkAttempt`): after the existing lifecycle, deadline and
  `attempts_exhausted` conflicts and before the pair lock write — when the Homework is the pair's
  official Homework and the Student's result is closed → `409 result_closed`, the claim rolls back.
- Idempotent replays of earlier successful requests keep returning the stored response. Practice tasks
  are never affected. No other guard is added (§13.2 of `S10-DOC-001`).

### 5.5 Homework before Blitz (`S10-D8`)

Official Blitz activation (`ActivateTeacherBlitz`, only when `lockResultPair` returns the pair):

- **Draft Homework**: immediately after the timer-mode settings check and before the cohort lock, the
  official Homework `status` read without a row lock; `draft` → `409 official_homework_not_activated`,
  nothing changes (the claim rolls back).
- **Active Homework**: after all locks and validations capture one untruncated `closedAt = now()`;
  `activatedAt = closedAt` truncated to the UTC second (the existing timing rule). Close the Homework
  exactly like `CloseTeacherHomework` with `closedAt`: deadline reconciliation first when it has passed,
  otherwise every `in_progress` Attempt frozen as `submitted` with `task_closed_auto_finalize`;
  `status = closed`, `closed_at = closedAt`, Homework and Assessment `updated_at = closedAt`; frozen
  Attempts checked after the response. Only the Homework's own Attempts (filtered from the cohort's
  locked Attempts) are passed. The shared close steps move into one helper used by both actions. The
  rows come from the cohort step's locks (re-selecting a row this transaction already locks is allowed);
  no new lock order.
- A `closed` or `archived` official Homework is unchanged. The response, idempotency, the already-active
  no-op and every other conflict are unchanged; a replay never closes anything. Practice Blitz unchanged.

Official Blitz Start (`StartStudentBlitzAttempt`): after the existing executability checks and the
returns of an existing Attempt, when `intent = start_normal` would create a new Attempt #1 and the
Student has no terminal (`submitted`, `waiting_for_teacher_review`, `checked`) Attempt of the official
Homework (from the already locked Attempts) → `409 homework_not_submitted`, no Attempt, the claim rolls
back. `resume`, `start_replacement`, returns of an existing #1, replays and practice Blitz are unaffected.

### 5.6 New 409 codes

| Code | Message |
|---|---|
| `result_not_ready_for_closure` | `The result cannot be closed yet.` |
| `official_homework_not_activated` | `The official Homework must be activated before the official Blitz.` |
| `homework_not_submitted` | `The Homework must be submitted before the Blitz can be started.` |

Each: an exception in `App\Exceptions`, an `ApiErrorResponse` method, a render mapping, an
`ApiErrorContractTest` case.

### 5.7 Deliberate test updates

Tests that encode the pre-`S10-D8` order change only as far as `S10-D8` requires: official-Blitz
activations get an active (or closed) official Homework, official `start_normal` #1 Starts get a
terminal official Homework Attempt, and Homework-first activation tests also assert the Homework close.
Known: `TeacherBlitzActivationIdempotencyTest` (`activationPair()`), `TeacherBlitzOfficialCohortActivationTest`,
`TeacherBlitzActivationConcurrencyTest`, `TeacherOfficialHomeworkBlitzFirstAuthoringTest`,
`StudentOfficialBlitzAttemptStartTest`, `StudentBlitzAttemptStartIdempotencyTest`
(`officialStudentBlitz()`), `StudentBlitzAttemptStartConcurrencyTest`,
`StudentHomeworkAttemptStartConcurrencyTest`. A test whose subject is the old Blitz-first history keeps
its subject by building that history with rows (as the Stage 9 seeder does) instead of the API.

## 6. Security and Integrity

Closure is Teacher-scoped and serializes on the Topic (`FOR UPDATE`) with comment, release, scoring
(`FOR SHARE`), Starts and grants; the Attempt `FOR SHARE` lock serializes it with the deadline and timeout
finalizers, which never take the Topic. A closed snapshot never changes; the closure, the activation close
and the guards are atomic (a conflict writes nothing). No lock cycle: no path locks the Topic and then a
group or Teacher membership.

## 7. Tests

- **Close**: single first-match rows (already closed → no change; not terminal; terminal but work not
  finished); calculated and Not completed snapshots with every column (a Not completed result whose other
  side still waits for review keeps that side without Attempt and score); actor, time, reason; the
  comment and releases kept; response detail; frozen after a settings change; bulk counts with a mixed
  cohort; `404` for other Teacher / outsider / bad id; strict body.
- **Archive**: terminal results closed with `topic_archived` and the archiving Teacher; waiting results
  open; Topic without cohort; already-archived replay closes nothing; Topic close closes nothing; a Topic
  whose official Blitz was never activated: a Not completed result (Homework missing) closes at archive
  and its values stay hidden from the Student.
- **Guards**: correction of an official answer after closure → `409 result_closed` and nothing written;
  first review after closure allowed and the snapshot unchanged; a practice correction unaffected; the
  official Homework Start after closure → `409 result_closed` (history with a later deadline).
- **`S10-D8`**: draft Homework → `409 official_homework_not_activated` with nothing changed (claim, Blitz,
  cohort); active Homework closed with `closedAt` (sub-second, ≥ Attempt `started_at`), in-progress
  Attempts frozen and checked after the response, `activated_at` truncated; a passed deadline reconciled
  first; closed/archived Homework untouched; replay and already-active no-op close nothing; a barred
  Student gets `409 homework_not_submitted` while a submitted Student starts; resume / replacement /
  existing-#1 return / practice unaffected; the barred Student's result is Not completed with
  `missing_component = both`.
- **Errors**: the three codes in `ApiErrorContractTest`.
- **Real concurrency** (worker processes; each asserts that the second operation really waits on the
  expected lock via `pg_blocking_pids`, and the final committed state equals the serial order):
  1. close vs a review correction, both orders (review first → snapshot holds the corrected score; close
     first → the correction gets `409 result_closed`);
  2. close vs the Homework deadline finalizer holding the Attempts (close evaluates the committed state);
  3. official Blitz activation vs a Homework Submit holding the Attempt (the submitted Attempt keeps
     `student_submit`, the Homework closes);
  4. `CL9-9`: exception grant vs a checking run; the `attempts:check-frozen` sweep vs a Homework Submit.

## 8. Expected Files

```text
backend/app/Support/Results/TopicResultClosures.php (closure rules + snapshot writer)
backend/app/Actions/Teacher/CloseTeacherTopicResult.php, CloseTeacherTopicResults.php, ArchiveTeacherTopic.php
backend/app/Http/Controllers/Api/V1/Teacher/TeacherTopicResultController.php, routes/api.php
backend/app/Actions/Teacher/ReviewTeacherSubmission.php, ActivateTeacherBlitz.php, CloseTeacherHomework.php
backend/app/Support/... (shared locked-Homework close helper)
backend/app/Actions/Student/StartStudentHomeworkAttempt.php, StartStudentBlitzAttempt.php
backend/app/Exceptions/*.php, app/Support/ApiErrorResponse.php, bootstrap/app.php
backend/tests/... (new tests, §5.7 updates, concurrency workers)
tasks/backend/stage-10/S10-BE-004-closure-and-work-order.md, tasks/STAGE_10_TASK_INDEX.md
```

## 9. Acceptance Criteria

- [ ] §5.1-§5.7 implemented exactly; existing responses unchanged except the new conflicts and the
      archive/activation side effects.
- [ ] Every §7 test group exists and passes; existing suites stay green apart from §5.7 updates.
- [ ] Independent fresh-context review `PASS` (P1 = 0, P2 = 0).

## 10. Verification

```text
backend: pint --test; phpunit tests/Unit tests/Feature/Results tests/Feature/Teacher tests/Feature/Student
  tests/Feature/Parent tests/Feature/Checking tests/Feature/Homework tests/Feature/Seeders
  tests/Feature/ApiErrorContractTest.php tests/Feature/Authorization (memory_limit 512M)
git diff --check
```
