# Implementation Contract: S09-BE-003B — Automatic Checking Pipeline, Trigger and Sweep

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-BE-003B` (second half of the planned `S09-BE-003`) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Backend` (no frontend change: `S09-BE-003A` made every Student read and replay accept checked Attempts) |
| Status | `Approved` |
| Depends on | `S09-BE-003A — Accepted / Delivered` (PR #292, `main` `f8bf790`) |
| Implementation baseline | `origin/main` `f8bf790` |
| Technical decisions applied | `S09-T1` (post-commit trigger, not a queued job; minute sweep), `S09-T3`, `S09-T7` |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |
| Blocks | `S09-BE-004` (official-score resolver runs inside the same checking transaction) |

This file is the complete task contract.

## 2. Goal

Every frozen Attempt (`submitted` or `timed_out_finalized`) is checked automatically right after its freeze
commits, and a scheduled sweep checks anything still frozen (including history frozen before Stage 9).
Checking routes each answer, awards automatic points, sends manual answers to Teacher review, and scores
the Attempt when nothing waits. The freeze itself and its response are unchanged.

## 3. Scope

### Included

- `CheckFrozenAttempt` (the checking transaction for one Attempt), the answer-key mapping onto
  `S09-BE-001`, the request-scoped `FrozenAttemptCheckQueue`, the finalizer hook, the console drain, the
  sweep command and its schedule.
- The deliberate updates of Stage 7/8 tests whose assertions describe the now-changed post-freeze state.

### Non-goals

- No official score (the resolver and its lock of the official row are `S09-BE-004`).
- No review API, correction or visibility (`S09-BE-005…007`). No response field or shape changes.
- No change to how or when an Attempt freezes, to the freeze responses, or to Stage 7/8 locks inside the
  freeze transactions.

## 4. Current Implementation Context

- Freezes happen only through `HomeworkAttemptFinalizer` (`finalizeByStudentSubmit`, `finalizeAtDeadline`,
  `finalizeAtClose`) and `BlitzAttemptFinalizer` (`finalizeByStudentSubmit`, `finalizeAtTimeout`,
  `finalizeAtClose`); each returns `true` exactly when it froze the row inside the caller's transaction.
  Callers: Homework Submit, the Homework deadline engine (HTTP reads/writes and `homework:reconcile-deadlines`),
  Homework Teacher close, Blitz Submit, the Blitz timeout engine (HTTP and `blitz:reconcile-timeouts`), Blitz
  Teacher close, and the timeout inside the Blitz exception grant. All are resolved by the container.
- The console reconcilers (`ReconcileDueHomeworkDeadlines`, `ReconcileDueBlitzTimeouts`) run one engine
  transaction per candidate, `report()` failures and print `Candidates: X; finalized attempts: Y; failures: Z.`;
  the scheduler runs them every minute `withoutOverlapping(5)` (`routes/console.php`).
- HTTP tests run `$kernel->terminate` after each request, so `app()->terminating` callbacks run inside tests;
  `$this->artisan()` does not terminate.
- Answers: `attempt_answers` (`checking_status` default `pending`, `awarded_points numeric(16,8)`,
  `checked_by_user_id`, `checked_at`, Eloquent timestamps); answer families and
  `StudentHomeworkAnswerIntegrity::load/canonical` (pending-only integrity and canonical payloads:
  `selected_option_ids`, `value`, `text`, `pairs`, `items`, `values`, `file`).
- Keys: `question_choice_options.is_correct`, `question_true_false_answers.correct_value`,
  `question_short_accepted_answers`, `question_matching_items(side, match_key)`,
  `question_ordering_items.correct_position` (1-based), `question_fill_blanks` + accepted answers;
  `questions.points` (`decimal:6`), `checking_mode`. Questions cannot change once Attempts exist.
- `assessment_attempts.possible_points` is the Start snapshot and is positive for every Attempt.
- `StudentAttemptAnswerStateResource` returns `attempt_answers.updated_at` to the Student.

## 5. Exact Contract

### 5.1 `App\Actions\Checking\CheckFrozenAttempt`

`__invoke(string $attemptId): bool` — returns `true` when it checked the Attempt. One transaction:

1. Read the Attempt (unlocked) for its Institution, Assessment, recipient and type. Unknown, or not
   `submitted`/`timed_out_finalized` → return `false`.
2. Lock, in this order, all scoped to that Institution: the Topic `FOR SHARE`; the Assessment
   `FOR SHARE`; its `homework_assignments` or `blitz_tasks` row `FOR SHARE`; the recipient
   `assessment_students` row `FOR UPDATE`; every Attempt of that recipient `FOR UPDATE` ordered by id; the
   target Attempt's `attempt_answers` rows `FOR UPDATE` ordered by id. (`S09-BE-004` appends the official
   row.) Missing parents or a mismatched tenant/recipient graph → `LogicException`.
3. Re-read the target status under its lock; not frozen → return `false` (idempotent).
4. Load the Assessment's Questions with their keys; load the answers' families and validate each with
   `StudentHomeworkAnswerIntegrity::canonical` (every answer must still be pending and clean). An answer of a
   Question outside the Assessment → `LogicException`.
5. For each answer, `AnswerCheckingRoute::resolve(type, checking_mode, points)`:
   - `automatic` → awarded points from `AutomaticAnswerChecker` (§5.2), `checking_status = auto_checked`;
   - `zero_point_closed` → `auto_checked`, awarded `0.00000000`;
   - `teacher_review` → `waiting_for_teacher_review`, awarded `null`, `checked_at` `null`.
   Automatic and zero-point results set `checked_at` to the check time and keep `checked_by_user_id` null.
   Writes use the query builder so `attempt_answers.updated_at` never changes.
6. Unanswered Questions have no row and contribute 0; no row is created.
7. The Attempt becomes `waiting_for_teacher_review` when any answer waits (earned, normalized and
   `scoring_completed_at` stay null), otherwise `checked` with
   `earned_points = CheckingScoreMath::sum(awarded)`,
   `normalized_score = normalizedScore(earned_points, possible_points)`, `scoring_completed_at` = check time.
   `status` is the only lifecycle field changed; `submitted_at`, `finalized_at`, `locked_at`,
   `finalization_reason` and `official_score_eligible` never change.

The check time is one `now()` per run. Every Attempt is checked the same way whatever its
`official_score_eligible` (an invalidated Blitz #1 and practice tasks included).

### 5.2 Answer keys onto `AutomaticAnswerChecker`

| Type | Checker input |
|---|---|
| `single_choice`, `multiple_choice` | options `id => is_correct`; selected ids from the canonical payload |
| `true_false` | `correct_value` (a missing row → `LogicException`) |
| `short_written` automatic | accepted answer texts |
| `matching` | left items `id => match_key`, right items `id => match_key`; canonical pairs |
| `ordering` | items `id => correct_position`; canonical items |
| `fill_in_blank` | blanks `id => accepted texts`; canonical values |

### 5.3 Trigger

- `App\Support\Checking\FrozenAttemptCheckQueue`, bound `scoped` in `AppServiceProvider`:
  `add(string $attemptId)` records an id and, the first time for this instance, registers one
  `app()->terminating` callback that calls `drain()`; `drain()` takes the recorded ids (clearing the list),
  runs `CheckFrozenAttempt` for each, and repeats until empty. Each id runs in its own checking transaction;
  any `Throwable` is passed to `report()` and never propagates.
- Both finalizers receive the queue by constructor injection and call `add($attempt->id)` whenever they
  return `true`. An id recorded in a transaction that later rolls back is harmless: the Attempt is not frozen,
  so the check returns `false`.
- HTTP: the callback runs after the response is sent, so every freeze response (Submit, close, grant, and
  reads/writes that reconcile a deadline or timeout) is exactly as before.
- Console: `ReconcileDueHomeworkDeadlines` and `ReconcileDueBlitzTimeouts` call `drain()` after each
  candidate's engine call returns (its transaction committed). Their output and exit codes are unchanged;
  checking failures are reported, not counted.
- Not a queued job (`QUEUE_CONNECTION=sync` would run it inside the freeze response). No flag disables the
  trigger.

### 5.4 Sweep

- Command `attempts:check-frozen` (`App\Console\Commands\CheckFrozenAttempts`) → Action
  `CheckDueFrozenAttempts`: every Attempt still `submitted` or `timed_out_finalized`, read `lazyById(100)`,
  each through `CheckFrozenAttempt` with per-Attempt `report()` isolation. Output
  `Candidates: X; checked attempts: Y; failures: Z.`; exit `FAILURE` when failures > 0, else `SUCCESS`.
- Scheduled in `routes/console.php` `everyMinute()->withoutOverlapping(5)`, like the reconcilers.
- `S09-BE-004` extends the sweep with the official-row repair.

## 6. Security and Integrity

System context only: no request data selects Attempts. Every lookup and lock is scoped by the Attempt's
Institution; a broken graph fails that Attempt only. Integrity failures leave the Attempt frozen and
unchanged (the transaction rolls back) for the next sweep and are reported.

## 7. Tests

New:

- `tests/Feature/Checking/CheckFrozenAttemptTest.php` — every automatic type (full, partial, zero credit);
  manual answers wait; a zero-point manual answer is `auto_checked` with 0; unanswered Questions add nothing;
  mixed Attempt → `waiting_for_teacher_review` with null scores; all-automatic Attempt → `checked` with exact
  earned, normalized (8 decimals) and scoring time; frozen fields and `official_score_eligible` unchanged;
  answer `updated_at` unchanged with time moved forward; second run returns `false` and writes nothing;
  `in_progress`, waiting and checked Attempts are ignored; a corrupt answer throws and leaves every row
  unchanged; a timed-out Blitz Attempt and an invalidated Blitz #1 are checked; the lock statements run in
  the §5.1 order.
- `tests/Feature/Checking/FrozenAttemptCheckTriggerTest.php` (Homework) and
  `FrozenBlitzAttemptCheckTriggerTest.php` (Blitz) — after an HTTP Homework Submit, Blitz Submit,
  Homework close, Blitz close, exception-grant timeout and a deadline-reconciling read, the response is
  unchanged (`submitted`/`timed_out_finalized`) and the database shows the checked Attempt; the console
  reconcilers check what they froze; a checking failure is reported and changes neither the response nor
  the freeze; the queue checks each id once.
- `tests/Feature/Console/CheckFrozenAttemptsCommandTest.php` — history is checked, output and exit codes,
  per-Attempt failure isolation, the schedule entry.

Deliberate updates of existing tests: assertions that an Attempt or its answers stay unchecked after an
HTTP freeze or a console reconcile become the §5.1 checked state; assertions on frozen fields, responses
and idempotency stay. Snapshot comparisons of `attempt_answers` exclude or re-baseline the checking
columns; lock-sequence assertions captured after `$kernel->terminate` re-baseline to include the checking
transaction or capture before it. Each updated file is listed in the PR.

## 8. Expected Files

```text
backend/app/Actions/Checking/CheckFrozenAttempt.php
backend/app/Actions/Checking/CheckDueFrozenAttempts.php
backend/app/Support/Checking/FrozenAttemptCheckQueue.php
backend/app/Support/Checking/CheckingAnswerKeys.php
backend/app/Console/Commands/CheckFrozenAttempts.php
backend/app/Support/Assessment/HomeworkAttemptFinalizer.php
backend/app/Support/Assessment/BlitzAttemptFinalizer.php
backend/app/Actions/Homework/ReconcileDueHomeworkDeadlines.php
backend/app/Actions/Blitz/ReconcileDueBlitzTimeouts.php
backend/app/Providers/AppServiceProvider.php
backend/routes/console.php
backend/tests/Feature/Checking/CheckFrozenAttemptTest.php
backend/tests/Feature/Checking/FrozenAttemptCheckTriggerTest.php
backend/tests/Feature/Checking/FrozenBlitzAttemptCheckTriggerTest.php
backend/tests/Feature/Console/CheckFrozenAttemptsCommandTest.php
backend/tests/Feature/... (deliberate Stage 7/8 updates, listed in the PR)
tasks/backend/stage-09/S09-BE-003B-checking-pipeline.md
tasks/STAGE_09_TASK_INDEX.md
tasks/README.md
```

## 9. Acceptance Criteria

- [ ] §5 is implemented exactly; every freeze response is unchanged; `attempt_answers.updated_at` never
      changes by checking.
- [ ] The §7 tests pass; the updated Stage 7/8 tests keep their frozen-state and response assertions.
- [ ] The backend Student, Homework, Blitz, Teacher, Console, Checking and Persistence feature suites pass.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.

## 10. Verification

```text
vendor/bin/phpunit tests/Feature/Checking tests/Feature/Console tests/Unit/Domain/Assessment
vendor/bin/phpunit tests/Feature/Student tests/Feature/Homework tests/Feature/Blitz tests/Feature/Teacher tests/Feature/Persistence
vendor/bin/pint --test <changed PHP files>
git diff --check
```

The whole backend suite runs in Backend Phase 2; these feature suites are the freeze paths' regression
set, because checking now runs after every freeze.
