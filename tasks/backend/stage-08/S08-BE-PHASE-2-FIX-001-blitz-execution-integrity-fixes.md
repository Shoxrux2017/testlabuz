# Focused Fix Contract: S08-BE-PHASE-2-FIX-001 — Blitz Execution Integrity Fixes

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-BE-PHASE-2-FIX-001` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Origin | `S08-BE-PHASE-2` run #1 on audited `main` `232ebcd` — `NOT ACCEPTED` |
| Findings fixed | `P1-1`, `P2-1`, `P3-1`, `P3-2`, `P3-3`; test gap for the `D3` row |
| Project Owner decisions | `D1 = A + D`, `D2 = A + D`, `D3 = B`, `D5 = A` (2026-09-23) |
| Area | Backend |
| Implementation | Claude (implementation role, see `tasks/README.md` roles as reassigned 2026-09-23) |
| Delivery | Claude opens the PR; Project Owner reviews and merges |
| Depends on | Nothing. Independent of `FIX-002` (docs) and `FIX-003` (test config) |

## 2. Goal

Remove the blocking Stage 8 backend defects found by Backend Phase 2 run #1 without changing any
public API shape, error code, route, schema or unrelated behavior:

1. Students must not be able to recover Matching/Ordering answer keys from item identifiers.
2. Blitz-first official activity must not make the official Homework impossible to author/activate.
3. Final Student/Teacher reads and timeout reconciliation must decide "due" with one instant.
4. Completed activation replay must fail closed on impossible lifecycle history.
5. Teacher monitoring must not take row locks on every poll when nothing is due.

## 3. Scope

### Included

- `P1-1`: random version-4 UUID primary keys for new Matching and Ordering item rows.
- `P2-1`: official Homework Question mutation is blocked by the pair lock only when the lock is
  explained by that Homework's own activity (or by no activity at all).
- `P3-1`: snapshot-observed due Attempts are reconciled at the snapshot instant.
- `P3-2`: activation replay validates the persisted Blitz lifecycle and activation evidence.
- `P3-3`: monitoring runs the locking preliminary reconciler only when a due Attempt exists.
- A focused test for the `D3` row (timeout-finalized #2 on `resume` / `start_replacement`).
- The review's two executable proofs become permanent regression tests.

### Non-Goals

- No re-keying of existing Matching/Ordering rows (`D1`: no real Student data yet).
- No change to `SetTeacherTopicResultPair`, official cohort, activation rules, Start, Submit,
  answer/file mutation, Scheduler, Close or exception grant behavior.
- No public error-code, route, request, resource or schema change.
- No documentation change (owned by `S08-BE-PHASE-2-FIX-002`).
- No `phpunit.xml` change (owned by `S08-BE-PHASE-2-FIX-003`).
- None of the accepted P3 follow-ups (`P3-4`, `P3-5`, `P3-6`, `P3-7` scope note, remaining `P3-8`,
  `P3-9`).
- No Stage 9 behavior.

## 4. Current Implementation Context (audited `232ebcd`)

- `app/Support/Student/StudentQuestionAnswerUi.php:99-108` shuffles display order by a hash but
  returns real item IDs. `QuestionMatchingItem` / `QuestionOrderingItem` use `HasUuids`, which in
  Laravel 13 generates `Str::uuid7()` (time-ordered, monotonic within a process).
  `QuestionConfigurationWriter.php:316-349` inserts Matching items as `L1, R1, L2, R2, …` and
  Ordering items in payload order; the Teacher client sends Ordering items in correct order.
  Proven: sorting the IDs of a public Start response recovered 6/6 pairs and 7/7 positions.
- `app/Support/Teacher/TeacherQuestionMutationAccess.php:126-130` throws
  `ResultPairLockedException` for any official Homework whenever `pair.locked_at` is set.
  Since `S08-BE-004` the lock is pair-wide (set by the first official Homework **or** Blitz
  Attempt). Proven via API: after Blitz-first activity, adding a Question to the draft official
  Homework returns `409 result_pair_locked`, activating it returns
  `409 assessment_has_no_scoreable_points`, replacing it returns `409 result_pair_locked`.
  Audit of every `topic_result_pairs.locked_at` read: this is the only site with the
  Homework-only meaning.
- `app/Support/Student/StudentBlitzReadSnapshot.php:30-35` takes the final-read instant from
  PostgreSQL `clock_timestamp()`; `app/Actions/Blitz/FinalizeTimedOutBlitzAttempts.php:37` decides
  with PHP `now()`. With the DB clock ahead of the app clock, a read at the deadline observes a
  due Attempt, the reconciler finalizes nothing, the next snapshot observes it again and the
  progress guard throws `LogicException` (HTTP 500) —
  `ReadStudentBlitz.php:105-107`, `ShowTeacherBlitzMonitoring.php:54-56`.
- `app/Actions/Teacher/ActivateTeacherBlitz.php:116-124` `replay()` checks only idempotency result
  metadata; DOC-001 §11.3 matrix requires "Completed-success activation record | `draft`,
  `scheduled` | Fail closed as an internal integrity inconsistency; never a successful replay".
- `app/Actions/Teacher/ShowTeacherBlitzMonitoring.php:42-44` calls the locking reconciler on every
  read of an active Blitz (`FOR UPDATE` on Assessment, BlitzTask and every in-progress Attempt),
  blocking concurrent Student answer saves and Submits. The Student read path first runs a cheap
  EXISTS (`ReconcileStudentBlitzTimeouts.php:29-34`).

## 5. Exact Implementation Contract

### 5.1 `P1-1` — item identifiers carry no authoring order

- `QuestionMatchingItem` and `QuestionOrderingItem` override `newUniqueId()` to return a random
  RFC 4122 version-4 UUID string (`Str::uuid()`), with a short comment stating the reason
  (Students receive these IDs; time-ordered IDs reveal authoring order and thus the key).
- Every other model keeps its current UUID generation.
- Wire format, validation (`uuid` rule), answer persistence and display ordering are unchanged.

### 5.2 `P2-1` — official Homework authoring under a Blitz-first pair lock

In `TeacherQuestionMutationAccess::lock()`, for a Homework whose official pair has
`locked_at !== null`:

| Homework own Attempts | Pair Blitz side has ≥ 1 Attempt (same Institution) | Result |
|---|---|---|
| ≥ 1 | any | `409 result_pair_locked` (unchanged) |
| 0 | yes | Lock is explained by official Blitz activity: do **not** raise `result_pair_locked`; continue with the remaining existing guards |
| 0 | no (or no Blitz side) | `409 result_pair_locked` (unchanged fail-closed for an unexplained lock) |

- Existing guard order is preserved: `topic_not_editable` → Blitz-active conflict →
  `task_closed` → `task_archived` → `result_pair_locked` → Attempts `business_conflict`.
- The Blitz-activity check is a plain existence read (no row lock). It runs while the Topic row
  is held `FOR UPDATE`; official Blitz Attempts are created only under that Topic lock and are
  never deleted, so the answer cannot change inside the transaction. Do not add Attempt row locks
  (they would contend with Student answer saves).
- Blitz Question mutation, `ensureActiveResultIsScoreable`, result-pair PUT, cohort and
  activation behavior are unchanged.

### 5.3 `P3-1` — one decision instant for snapshot-observed due Attempts

- `FinalizeTimedOutBlitzAttempts::__invoke(string $institutionId, string $assessmentId,
  ?CarbonInterface $dueAt = null): int`. The decision instant is the later of the current app
  time and `$dueAt`. Persisted values are unchanged: `finalized_at = locked_at = deadline_at`,
  `status = timed_out_finalized`, `finalization_reason = timeout_auto_submit`.
- `ReadStudentBlitz` and `ShowTeacherBlitzMonitoring` pass the `snapshotAt` of the discarded
  snapshot that observed the due Attempts when they reconcile before re-reading.
- All other callers keep calling without `$dueAt`.
- The progress guard stays: if the same Attempt is still due + `in_progress` in the next
  snapshot, throw the existing `LogicException`.

### 5.4 `P3-2` — activation replay fails closed

- A completed activation replay (both `completedReplay` and a non-new claim) additionally
  requires, on the locked BlitzTask: status in `active | closed | archived` and non-null
  `activated_at`, `activated_by_user_id`, `timer_start_mode_snapshot`. Otherwise throw
  `LogicException` (centralized `500 server_error`), inside the transaction, with zero mutation.
- Valid replays (active / closed / archived with evidence) keep returning `200` with the current
  resource.

### 5.5 `P3-3` — monitoring locks only when something is due

- `ShowTeacherBlitzMonitoring` invokes the preliminary reconciler only when the preliminary
  Blitz is `active` **and** an `in_progress` Attempt with `deadline_at <=` current app time exists
  for that Blitz in the Teacher's Institution (plain EXISTS, no lock).
- The snapshot-driven path (5.3) is unchanged and still reconciles whatever a snapshot observes.
- Response shape, status projection and `server_now` behavior are unchanged.

### 5.6 `D3` test gap

- Add a focused test proving the adopted behavior: after replacement #2 is timeout-finalized,
  a new-key `resume` of #2 and a new-key `start_replacement` both return `409 blitz_time_expired`
  with zero mutation and no #3.

### 5.7 Architecture and placement

- Changes stay in the listed classes; no new service or abstraction is required.
- Authorization and Tenant scoping are unchanged; every new query filters by the authenticated
  user's `institution_id`.

## 6. Expected Files and Areas

Production:

```text
backend/app/Models/QuestionMatchingItem.php
backend/app/Models/QuestionOrderingItem.php
backend/app/Support/Teacher/TeacherQuestionMutationAccess.php
backend/app/Actions/Blitz/FinalizeTimedOutBlitzAttempts.php
backend/app/Actions/Student/ReadStudentBlitz.php
backend/app/Actions/Teacher/ShowTeacherBlitzMonitoring.php
backend/app/Actions/Teacher/ActivateTeacherBlitz.php
```

Tests: new focused tests plus the explicitly changed tests below.

Explicitly changed existing tests (behavior changed by this contract):

- `StudentBlitzExceptionReadConsistencyTest::test_repeated_due_attempt_after_reconciliation_fails_instead_of_looping`
- `TeacherBlitzMonitoringTimeoutReconciliationTest::test_reconciliation_without_progress_fails_instead_of_looping`

Both currently force "no progress" through app/DB clock skew, which 5.3 makes a supported case.
They must keep asserting the exact `LogicException` message, but force the impossible condition
differently (a committed concurrent revert of the finalized Attempt between the two snapshots).
Any existing monitoring query-count assertion may change only by the preliminary-reconciler
queries removed or the EXISTS query added by 5.5.

## 7. Acceptance Criteria

- [ ] New Matching/Ordering item IDs are version-4 UUIDs; the attacker test (sort item IDs from the
      public Blitz Start response and from the Homework Start response) no longer recovers the
      pairs or the order.
- [ ] Blitz-first official activity: Question add/update/delete/reorder on the zero-Attempt
      official Homework succeeds; Homework activation then succeeds; Homework replacement via
      result-pair PUT still returns `409 result_pair_locked`.
- [ ] Homework with its own Attempts under a locked pair still returns `409 result_pair_locked`;
      an unexplained lock (no Attempts on either side) still returns `409 result_pair_locked`.
- [ ] A final Student read and a Teacher monitoring read with the DB clock ahead of the app clock
      at the deadline return `200` with the Attempt finalized at exactly `deadline_at`; no 500.
- [ ] The progress guard still throws the exact `LogicException` for a truly repeated due Attempt.
- [ ] Activation replay against `draft` / `scheduled` Blitz or missing activation evidence returns
      `500 server_error` with zero mutation; valid replays unchanged.
- [ ] Monitoring of an active Blitz with no due Attempt issues no `FOR UPDATE`; with a due Attempt
      it still finalizes it before projecting.
- [ ] Timeout-finalized #2: new-key `resume` and `start_replacement` return `409 blitz_time_expired`.
- [ ] No public API, route, schema, error-code or unrelated behavior change.

## 8. Focused Tests and Verification

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app php vendor/bin/phpunit --filter '<new and changed test classes>'
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app ./vendor/bin/pint --test
git diff --check
```

Directly affected regression (run once):

```text
tests/Feature/Teacher/TeacherHomework*Question*  tests/Feature/Teacher/TeacherQuestion*
tests/Feature/Teacher/TeacherBlitzQuestion*       tests/Feature/Teacher/TeacherOfficial*
tests/Feature/Teacher/TeacherBlitzActivation*     tests/Feature/Teacher/TeacherBlitzMonitoring*
tests/Feature/Student/StudentBlitz*               tests/Feature/Student/StudentHomeworkAttemptStart*
tests/Feature/Student/StudentHomeworkRead*  (Question projection)
tests/Feature/Blitz/*  tests/Feature/Persistence/*Question*
```

The full backend suite is not part of this task; the refreshed `S08-BE-PHASE-2` runs the exact
§40 command once after `FIX-001…003` are merged.

## 9. Delivery

Branch `fix/stage8-phase2-fix-001-blitz-integrity`, one commit per concern, PR to `main` with the
verification evidence in the description. Project Owner merges.

## 10. Planning Provenance

`S08-BE-PHASE-2` run #1 report and Project Owner decisions `D1`–`D5`, recorded in
`tasks/STAGE_08_TASK_INDEX.md` §17.
