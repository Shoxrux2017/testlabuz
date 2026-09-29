# Implementation Contract: S09-BE-003A — Checking Readiness of Stage 7/8 Reads and Timeout Rules

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-BE-003A` (first half of the planned `S09-BE-003`) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Backend` (no frontend change: §4) |
| Status | `Approved` |
| Depends on | `S09-BE-002 — Accepted / Delivered` (PR #291, `main` `9b772b4`) |
| Implementation baseline | `origin/main` `9b772b4` |
| Technical decisions applied | `S09-T2` (timeout rules keyed on the finalization reason) |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |
| Blocks | `S09-BE-003B` (checking pipeline, trigger and sweep) |

This file is the complete task contract.

## 2. Goal

Before any Attempt is checked, make every Stage 7/8 read and rule that looks at a terminal Attempt behave
the same whether the Attempt is still `submitted`/`timed_out_finalized` or already
`waiting_for_teacher_review`/`checked`:

- Blitz Start/Resume, Blitz read and Blitz Submit rules that mean “this Attempt ended by timeout” are keyed
  on `finalization_reason = timeout_auto_submit`, not on the status `timed_out_finalized`.
- Student reads and Submit replays of terminal Homework Attempts read answers in any checking state.

Observable Stage 7/8 responses stay exactly the same. The split from `S09-BE-003B` keeps checking itself
out of this PR: nothing here changes a status or an answer.

## 3. Scope

### Included

- The four status-keyed timeout conditions (§5.1).
- The Homework Attempt read projection (§5.2).
- Tests (§6), including the one deliberate update of an existing test that encodes the old rule.

### Non-goals

- No checking, trigger, sweep, scoring or official score (`S09-BE-003B`, `S09-BE-004`).
- No new response field (`S09-BE-007`); answer states keep exposing only `question_id`, `type`, `answer`,
  `updated_at`.
- No change to Stage 8's historical-read proof for Blitz replays, to monitoring, to Answer mutation
  (`409 attempt_not_editable` for any terminal Attempt) or to finalization lineage validation.

## 4. Current Implementation Context

- Status-keyed timeout rules:
  - `StartStudentBlitzAttempt.php:118-120` (Resume: `status === TimedOutFinalized` → `blitz_time_expired`,
    other terminal → `attempt_not_editable`) and `:130-132` (`start_normal`/`start_replacement` over a
    terminal current Attempt: `status === TimedOutFinalized` → `blitz_time_expired`, else
    `attempts_exhausted`; the exception + `start_normal` rule before it is unchanged).
  - `StudentBlitzTiming::assertExecutable` `:68-70` (`status === TimedOutFinalized` →
    `blitz_time_expired`; used by Start and by `GET /student/blitz/{blitz}` in `ReadStudentBlitz`).
  - `SubmitStudentBlitzAttempt.php:84-87` (`status === TimedOutFinalized && reason === TimeoutAutoSubmit`
    → `blitz_time_expired`, other terminal → `attempt_not_editable`).
- `StudentBlitzAttemptSummary::assertTerminal` validates lineage by reason and excludes impossible
  status/reason pairs; it already accepts `waiting_for_teacher_review`/`checked` for every reason and is not
  a status-keyed rule. Monitoring already maps every terminal status except waiting to `finalized`.
- Blitz answer reads happen only in `ShowStudentBlitzAttempt`; replays of `waiting`/`checked` Attempts
  already use the Stage 8 historical-read proof; fresh responses are built inside the freeze transaction.
- `ShowStudentHomeworkAttempt.php:65-67` projects answers with `StudentHomeworkAttemptAnswerStates::__invoke`
  → `StudentHomeworkAnswerIntegrity::canonical`, which requires `checking_status = pending` and null
  `awarded_points`, `feedback`, `checked_by_user_id`, `checked_at`. It serves `GET /student/attempts/{attempt}`,
  the Start response/replay and the Submit response/replay. `historicalRead`
  (`canonicalForHistoricalRead`: any valid checking status) exists and is used only by Blitz.
- Existing test encoding the old Submit rule: `StudentBlitzAttemptSubmitLifecycleTest::terminalAttempts`
  expects `waiting_for_teacher_review`/`checked` + `timeout_auto_submit` → `attempt_not_editable`.
- Frontend: the Homework and Blitz Attempt parsers already accept `waiting_for_teacher_review` and
  `checked`, and answer states carry no checking field; fresh Blitz Submit responses stay `submitted`.
  No frontend change is needed.

## 5. Exact Contract

### 5.1 Timeout rules keyed on the finalization reason

Replace each condition `status === timed_out_finalized` (and the status half of the Submit condition) with
`finalization_reason === timeout_auto_submit`:

| Place | New condition → result | Unchanged |
|---|---|---|
| Start `resume` of the current Attempt | terminal with reason `timeout_auto_submit` → `409 blitz_time_expired` | any other terminal → `409 attempt_not_editable` |
| Start `start_normal`/`start_replacement` over a terminal current Attempt | reason `timeout_auto_submit` → `409 blitz_time_expired` | exception + `start_normal` → `attempts_exhausted` first; otherwise `attempts_exhausted` |
| `StudentBlitzTiming::assertExecutable` | reason `timeout_auto_submit` → `409 blitz_time_expired` | replacement available → no rule; deadline check |
| Blitz Submit, new key | reason `timeout_auto_submit` → `409 blitz_time_expired` | any other terminal → `409 attempt_not_editable` |

An `in_progress` Attempt has a null reason, so none of these rules applies to it.

### 5.2 Homework reads of terminal Attempts

`ShowStudentHomeworkAttempt` projects answer states with `StudentHomeworkAttemptAnswerStates::historicalRead`
when the Attempt is terminal (any status other than `in_progress`) and with the pending-only projection
when it is `in_progress`. The resource output is unchanged. Start, answer saving and Submit keep their
pending-only checks on the `in_progress` Attempt.

The historical projection (`canonicalForHistoricalRead`, shared with Blitz replays) keeps accepting every
checking state, and additionally rejects a `pending` answer that carries checking metadata (`awarded_points`,
`feedback`, `checked_by_user_id` or `checked_at`), exactly as the pending-only projection does. This keeps the
Stage 7 corruption check (`StudentHomeworkAttemptSubmitIdempotencyTest` corrupted-answer replay) for a
terminal Attempt whose answers are not yet checked.

## 6. Tests

New `tests/Feature/Student/StudentBlitzCheckedTimeoutRulesTest.php` (committed fixtures through
`UsesBlitzReadSnapshot`, because Blitz reads own a real snapshot transaction) — for an Attempt finalized by
timeout, still `timed_out_finalized` (baseline) and then moved to `waiting_for_teacher_review` and to
`checked`: new-key Start `start_normal` and `resume` → `409 blitz_time_expired`; `GET /student/blitz/{blitz}`
→ `409 blitz_time_expired`; nothing is written. For an Attempt finalized by Student Submit and then
`waiting_for_teacher_review`/`checked`: `resume` → `409 attempt_not_editable`, `start_normal` →
`409 attempts_exhausted`, the detail read → `200`. The new-key Submit rule is covered by the updated
`StudentBlitzAttemptSubmitLifecycleTest::terminalAttempts` rows.

New `tests/Feature/Student/StudentHomeworkCheckedAttemptReadTest.php` — a submitted Homework Attempt whose
answers are moved to `auto_checked`/`waiting_for_teacher_review`/`teacher_checked` with awarded points,
feedback, reviewer and time, and the Attempt to `waiting_for_teacher_review` and `checked`:
`GET /student/attempts/{attempt}` returns `200` with the same answer values as before checking and no
checking field; the completed Submit replay returns the current status and the original finalization fields;
an `in_progress` Attempt with a non-pending answer still fails its read (`500`, integrity).

Deliberate update: `StudentBlitzAttemptSubmitLifecycleTest::terminalAttempts` — the
`waiting_for_teacher_review`/`checked` + `timeout_auto_submit` rows expect `blitz_time_expired`.

## 7. Expected Files

```text
backend/app/Actions/Student/StartStudentBlitzAttempt.php
backend/app/Actions/Student/SubmitStudentBlitzAttempt.php
backend/app/Support/Student/StudentBlitzTiming.php
backend/app/Actions/Student/ShowStudentHomeworkAttempt.php
backend/app/Support/Student/StudentHomeworkAnswerIntegrity.php
backend/tests/Feature/Student/StudentBlitzCheckedTimeoutRulesTest.php
backend/tests/Feature/Student/StudentHomeworkCheckedAttemptReadTest.php
backend/tests/Feature/Student/StudentBlitzAttemptSubmitLifecycleTest.php
tasks/backend/stage-09/S09-BE-003A-checking-readiness.md
tasks/STAGE_09_TASK_INDEX.md
tasks/README.md
```

## 8. Acceptance Criteria

- [ ] §5 is implemented exactly; no status, answer or response shape changes.
- [ ] The §6 tests pass; the only existing-test change is the one listed.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.

## 9. Verification

```text
vendor/bin/phpunit tests/Feature/Student/StudentBlitzCheckedTimeoutRulesTest.php tests/Feature/Student/StudentHomeworkCheckedAttemptReadTest.php tests/Feature/Student/StudentBlitzAttemptSubmitLifecycleTest.php tests/Feature/Student/StudentBlitzTimeoutStartTest.php tests/Feature/Student/StudentBlitzAttemptStartTest.php tests/Feature/Student/StudentBlitzAttemptStartHistoricalReplayTest.php tests/Feature/Student/StudentBlitzReadApiTest.php tests/Feature/Student/StudentBlitzAttemptSubmitApiTest.php tests/Feature/Student/StudentBlitzAttemptSubmitIdempotencyTest.php tests/Feature/Student/StudentHomeworkAttemptSubmitIdempotencyTest.php tests/Feature/Student/StudentHomeworkAttemptSubmitApiTest.php tests/Feature/Student/StudentHomeworkAttemptStartApiTest.php tests/Feature/Student/StudentHomeworkReadApiTest.php tests/Feature/Student/StudentHomeworkDeadlineReadReconciliationTest.php
vendor/bin/pint --test <changed PHP files>
git diff --check
```

The full backend suite is a Backend Phase 2 activity.
