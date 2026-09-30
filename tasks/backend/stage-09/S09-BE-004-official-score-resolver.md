# Implementation Contract: S09-BE-004 — Official Score Resolver

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-BE-004` |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Backend` (no API or response change; no frontend change) |
| Status | `Approved` |
| Depends on | `S09-BE-003B — Accepted / Delivered` (PR #293, `main` `d324716`) |
| Implementation baseline | `origin/main` `d324716` |
| Owner decisions applied | `S09-D2` (Homework “could overtake” wait), `S09-D4` (exception withdrawal), `S09-D6` (practice tasks never official) |
| Technical decisions applied | `S09-T3` (exact decimals), `S09-T7` (invalidated Blitz #1 never official, never blocking) |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |
| Blocks | `S09-BE-006` (review and correction re-resolve), `S09-BE-007` (official-score read uses the live evaluation) |

This file is the complete task contract.

## 2. Goal

Each Student has exactly one official score for the designated Homework and for the designated Blitz of a
Topic, stored in `official_task_scores` exactly while it is ready. The resolver decides it under the
Student's scoring locks inside every automatic checking run and every exception grant, and the minute sweep
repairs a stored row that is missing or stale.

## 3. Scope

### Included

- The live evaluation (`OfficialScoreEvaluator`) of the Homework and Blitz rules, including the
  Attempts that block readiness.
- The resolver (`OfficialTaskScoreResolver`) that writes, updates or deletes the Student's row.
- A shared lock of the Student's scoring graph (`RecipientScoringLock`), extracted from `CheckFrozenAttempt`
  and reused by the resolver's callers.
- The resolver inside `CheckFrozenAttempt` and inside the Blitz exception grant.
- The sweep repair and its command output.

### Non-goals

- No read endpoint and no response field (the Teacher official-score read and Student visibility are
  `S09-BE-007`). No review or correction (`S09-BE-006`), which will call the same resolver.
- No change to checking results, freeze paths, Attempt eligibility, or Stage 8 grant responses.
- No migration: `official_task_scores` exists (`S09-BE-002`).

## 4. Current Implementation Context

- `official_task_scores`: `institution_id`, `assessment_id`, `student_id`, `official_attempt_id`,
  `normalized_score numeric(12,8)` (0..100), `selection_policy_code` (`OfficialScoreSelectionPolicy`:
  `highest_valid_completed`, `valid_normal_blitz`, `approved_blitz_exception_replacement`),
  `selected_by_user_id` (always null, check constraint), `selected_at`, timestamps; unique
  `(assessment_id, student_id)` and unique `official_attempt_id`; composite tenant foreign keys.
- Official tasks are the `topic_result_pairs.homework_assessment_id` and `blitz_assessment_id` of the
  Assessment's Topic (same Institution). Designation cannot change once Attempts exist. Every other Homework
  or Blitz is a practice task.
- Homework Attempts are always `official_score_eligible = true`. A Blitz exception
  (`blitz_attempt_exceptions`: `invalidated_attempt_id`, `replacement_attempt_id`, one per recipient) sets the
  normal Attempt #1 ineligible; the replacement #2 is eligible (`StudentBlitzAttemptSummary::validateHistory`
  states the Stage 8 invariants).
- `CheckFrozenAttempt` (`S09-BE-003B`) takes, per Institution: Topic `FOR SHARE` → Assessment `FOR SHARE` →
  task row `FOR SHARE` → recipient `FOR UPDATE` → all the recipient's Attempts `FOR UPDATE` (by id) → the
  target's answers `FOR UPDATE`, then scores the Attempt with one check time.
- `GrantTeacherBlitzAttemptException` locks Topic/Assessment/Blitz `FOR UPDATE` (via
  `TeacherBlitzLifecycleAccess::lockBlitz`), then the recipient, the Student user, the idempotency claim, the
  Student's Attempts and the exception row; a new grant may finalize #1 at its timeout, sets #1 ineligible and
  creates the exception.
- `CheckingScoreMath` (`sum`, `normalizedScore`, `compare`) works on decimal strings with at most 8 fractional
  digits; `questions.points` is `numeric(14,6)`, `attempt_answers.awarded_points` `numeric(16,8)`.
- The sweep command `attempts:check-frozen` prints `Candidates: X; checked attempts: Y; failures: Z.`.

## 5. Exact Contract

### 5.1 `App\Support\Checking\RecipientScoringLock`

`lock(string $institutionId, string $assessmentId, string $recipientId): LockedRecipientAttempts` takes, in
this order and all scoped to the Institution: the Assessment's Topic `FOR SHARE`, the Assessment
`FOR SHARE`, its `homework_assignments`/`blitz_tasks` row `FOR SHARE`, the recipient `FOR UPDATE`, and every
Attempt of that recipient `FOR UPDATE` ordered by id. A missing parent, a type/Topic mismatch, a recipient of
another Assessment, or an Attempt of another Assessment or Student → `LogicException`.
`LockedRecipientAttempts` (readonly) exposes `assessment` (`id`, `institution_id`, `topic_id`, `type`),
`recipient` (`id`, `assessment_id`, `student_id`) and `attempts` (all columns).

`CheckFrozenAttempt` uses it instead of its private lock code; its lock statements and their order are
unchanged, and the target Attempt is taken from `attempts` (missing → `LogicException`).

### 5.2 `App\Support\Checking\OfficialScoreEvaluator`

`evaluate(Assessment $assessment, AssessmentStudent $recipient, Collection $attempts): OfficialScoreEvaluation`
reads nothing under lock by itself. The caller passes all the recipient's Attempts; one that belongs to
another Institution, Assessment, recipient or Student → `LogicException`. “Terminal” means any status except
`in_progress`; “pending” means `submitted`, `timed_out_finalized` or `waiting_for_teacher_review`.

`OfficialScoreEvaluation` (readonly): `official` (`?AssessmentAttempt`), `policy`
(`?OfficialScoreSelectionPolicy`, null exactly when `official` is null), `blocking` (list of Attempts, by
`attempt_number`).

**Homework** (all Attempts eligible; an ineligible Homework Attempt → `LogicException`):

1. `best` = the `checked` Attempt with the highest `normalized_score`, ties to the lowest `attempt_number`.
   None → not ready; `blocking` = every terminal non-`checked` Attempt.
2. Each pending Attempt has an upper bound: `100.00000000` while `submitted`/`timed_out_finalized`; while
   `waiting_for_teacher_review`, `normalizedScore(sum(awarded points of its auto_checked and teacher_checked
   answers) + sum(points of the Questions of its waiting answers), possible_points)`.
3. A pending Attempt could overtake when its bound is greater than `best`'s `normalized_score`, or equal with
   a lower `attempt_number`. Any → not ready; `blocking` = those Attempts.
4. Otherwise `official = best`, policy `highest_valid_completed`, `blocking` empty.

A `checked` Attempt without `normalized_score` → `LogicException`.

**Blitz** (reads the recipient's `blitz_attempt_exceptions` row, scoped to the Institution):

- At most two Attempts, numbered 1 and 2; otherwise `LogicException`.
- No exception: #2 must not exist and #1 must be eligible (else `LogicException`); the candidate is #1,
  policy `valid_normal_blitz`.
- Exception: #1 must exist, be ineligible and be its `invalidated_attempt_id`; #2, when present, must be
  eligible and be its `replacement_attempt_id`, and `replacement_attempt_id` must be null without #2 (else
  `LogicException`). The candidate is #2, policy `approved_blitz_exception_replacement`.
- Candidate `checked` → ready with the candidate. Candidate pending → not ready, `blocking` = [candidate].
  No candidate or an `in_progress` candidate → not ready, `blocking` empty. #1 after an exception is never
  official and never blocking.

### 5.3 `App\Support\Checking\OfficialTaskScoreResolver`

`resolve(Assessment $assessment, AssessmentStudent $recipient, Collection $attempts, CarbonInterface $resolvedAt): bool`
— the caller holds §5.1's locks (or the grant's stronger ones) and passes all the recipient's Attempts as
locked and as changed in its transaction. Returns `true` when it wrote the row.

1. Practice task (the Assessment is not its Topic pair's Homework or Blitz; the pair is read without a lock)
   → return `false` and touch nothing.
2. Lock the Student's row: `official_task_scores` by Institution, Assessment and Student `FOR UPDATE` (the
   last lock, after answers).
3. Evaluate (§5.2).
   - Ready, no row → insert with the official Attempt, its `normalized_score`, the policy,
     `selected_by_user_id = null`, and `selected_at = created_at = updated_at = $resolvedAt`.
   - Ready, row with a different `official_attempt_id` or `normalized_score` → update both, the policy,
     `selected_at` and `updated_at` to `$resolvedAt`. Only the policy differs → update the policy and
     `updated_at`.
   - Ready, identical row → no write.
   - Not ready, row exists → delete it. Not ready, no row → nothing.

### 5.4 Callers

- **Automatic checking.** `CheckFrozenAttempt` calls the resolver after scoring, in the same transaction and
  with its check time, whatever the resulting status (a newly `waiting_for_teacher_review` Attempt may make a
  ready score not ready). Practice tasks and invalidated #1 are handled by §5.2/§5.3.
- **Exception grant.** A new grant calls the resolver after #1 is invalidated and the exception is saved,
  with `$grantedAt`. The row is deleted in the grant transaction (no replacement exists yet). Replays do not
  call it. The grant response and its other effects are unchanged.
- **Sweep repair.** `App\Actions\Checking\RepairOfficialTaskScores` runs after `CheckDueFrozenAttempts` in
  `attempts:check-frozen`. Candidates are recipients of official tasks that have a `checked` eligible Attempt
  and no pending eligible Attempt, and whose row is missing or whose `official_attempt_id`/`normalized_score`
  differ from their best `checked` eligible Attempt (highest `normalized_score`, then lowest
  `attempt_number`); one set-based query, keyed by recipient. Each candidate runs in its own transaction:
  `RecipientScoringLock::lock` and `resolve(..., now())`; a failure is reported and counted, and the next
  candidate continues. The command prints a second line `Official scores repaired: R; failures: F.` (R =
  resolves that wrote) and exits `FAILURE` when either line reports failures.

## 6. Security and Integrity

System context only: no request data selects Students or Attempts. Every query is scoped by Institution.
Rows exist only for official tasks and point to an eligible `checked` Attempt of the same Institution,
Assessment and Student. Every writer takes the Student's recipient lock before reading Attempts and the row
last, so two writers for one Student and Assessment decide one after another. A broken history fails loudly
and leaves the row unchanged.

## 7. Tests

- `tests/Feature/Checking/OfficialScoreEvaluatorTest.php` — Homework: highest of three `checked` Attempts;
  tie to the lowest number; none checked → blocking terminal Attempts; a frozen Attempt (bound 100) could
  overtake; a waiting Attempt's exact bound (awarded + full waiting points, rounded) above, equal with a lower
  number, equal with a higher number, and below `best`; `in_progress` ignored. Blitz: #1 checked; #1 pending;
  exception without #2; exception with #2 in progress, pending, checked; invalid histories →
  `LogicException`; a foreign Attempt → `LogicException`.
- `tests/Feature/Checking/OfficialTaskScoreResolverTest.php` — practice task untouched; insert with the
  times; identical re-resolve writes nothing; move to another Attempt and a changed score update the row and
  `selected_at`; not ready deletes the row.
- `tests/Feature/Checking/OfficialScoreCheckingTest.php` — through Homework checking: an official Attempt
  creates the row; a later Attempt left waiting with a bound that could overtake deletes it; a better later
  Attempt moves it; a practice task writes nothing; the lock statements of an official check end with
  `official_task_scores update`.
- `tests/Feature/Checking/OfficialBlitzScoreTest.php` — an official Blitz #1 checked after Submit creates
  `valid_normal_blitz`; a grant after #1 became official deletes the row in the grant; the replacement's
  check creates `approved_blitz_exception_replacement`; a grant replay changes nothing; a grant that fails
  after the withdrawal rolls it back.
- Resolver race (`tests/Feature/Checking/OfficialScoreResolverConcurrencyTest.php`, PostgreSQL worker
  processes like the Stage 7/8 concurrency tests): two checking runs of two Attempts of one Student; the
  second waits on the recipient lock held by the first and the final row is the correct best Attempt.
- `tests/Feature/Console/CheckFrozenAttemptsCommandTest.php` — the repair: missing row created, stale row
  corrected, a Student with a pending eligible Attempt and practice tasks untouched, output lines, per-Student
  failure isolation and exit code.

Existing tests change only where an official task's checking now appends the official-row lock to a
captured lock list, or where a fixture's official task now has a row; such updates are listed in the PR.

## 8. Expected Files

```text
backend/app/Support/Checking/RecipientScoringLock.php
backend/app/Support/Checking/LockedRecipientAttempts.php
backend/app/Support/Checking/OfficialScoreEvaluator.php
backend/app/Support/Checking/OfficialScoreEvaluation.php
backend/app/Support/Checking/OfficialTaskScoreResolver.php
backend/app/Actions/Checking/CheckFrozenAttempt.php
backend/app/Actions/Checking/RepairOfficialTaskScores.php
backend/app/Actions/Teacher/GrantTeacherBlitzAttemptException.php
backend/app/Console/Commands/CheckFrozenAttempts.php
backend/tests/Feature/Checking/OfficialScoreEvaluatorTest.php
backend/tests/Feature/Checking/OfficialTaskScoreResolverTest.php
backend/tests/Feature/Checking/OfficialScoreCheckingTest.php
backend/tests/Feature/Checking/OfficialBlitzScoreTest.php
backend/tests/Feature/Checking/OfficialScoreResolverConcurrencyTest.php
backend/tests/Feature/Console/CheckFrozenAttemptsCommandTest.php
backend/tests/Feature/... (lock-list updates, listed in the PR)
tasks/backend/stage-09/S09-BE-004-official-score-resolver.md
tasks/STAGE_09_TASK_INDEX.md
tasks/README.md
```

## 9. Acceptance Criteria

- [ ] §5 is implemented exactly; a row exists for an official task exactly while §5.2 is ready, and never for
      a practice task.
- [ ] Every writer takes the recipient lock before reading Attempts and the official row last.
- [ ] The §7 tests pass; Stage 7/8 and `S09-BE-003B` behaviour and responses are unchanged.
- [ ] The backend Checking, Console, Student, Homework, Blitz, Teacher and Persistence feature suites pass.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.

## 10. Verification

```text
vendor/bin/phpunit tests/Feature/Checking tests/Feature/Console tests/Unit/Domain/Assessment
vendor/bin/phpunit tests/Feature/Student tests/Feature/Homework tests/Feature/Blitz tests/Feature/Teacher tests/Feature/Persistence
vendor/bin/pint --test <changed PHP files>
git diff --check
```

The whole backend suite runs in Backend Phase 2.
