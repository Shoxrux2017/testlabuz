# Focused Fix Contract: S09-BE-PHASE-2-FIX-001 — Seeder Re-baseline, Test Gaps and Repair Pair Filter

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-BE-PHASE-2-FIX-001` |
| Stage | `Stage 9 — Checking and Scoring` |
| Origin | `S09-BE-PHASE-2` run #1 on audited `main` `98747ef` — `NOT ACCEPTED` (full backend suite: 1 failed) |
| Findings fixed | `F-1` (suite failure); test gaps `A-3`, `B-1`, `C-2`, `C-3`, `D-1`, `D-2`, `E-4`; repair pair filter from `A-1`/`B-3`/`E-1` |
| Area | Backend (tests; one query in `RepairOfficialTaskScores`) |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |
| Status | `Approved` |

Finding ids refer to `S09-BE-PHASE-2-backend-block-review.md` §7.

## 2. Goal

Make the full backend suite pass on Stage 9 behavior, close the test gaps the Phase 2 review found on
integrity-relevant paths, and remove the unindexable pair filter from the per-minute repair sweep, without
changing any public API, error code, route, schema, schedule or product behavior.

## 3. Scope

### Included

1. **`F-1`.** `Stage8E2eSeederTest::test_scheduler_aggregate_is_the_only_exact_candidate_and_keeps_a_future_replacement`
   predates `S09-BE-003B`, which made every reconciler freeze drain the checking queue. The seeded
   `sched_due_1` Attempt has no answers, so the reconciler now freezes it with `timeout_auto_submit` and
   checking moves it to `checked` with 0 of its points. Re-baseline the assertion to that outcome
   (status `checked`, reason `timeout_auto_submit`, no `submitted_at`, zero earned and normalized score,
   scoring completed) and keep every other assertion.
2. **`E-4`.** `TeacherBlitzCloseApiTest` no longer pins the freeze status, because checking rewrites it.
   Add a test where checking cannot run (a zero possible-points snapshot, reported by the queue) so the
   freeze status stays visible: close before the deadline freezes `submitted` with
   `task_closed_auto_finalize`; at and after the deadline it freezes `timed_out_finalized` with
   `timeout_auto_submit`.
3. **`A-3`.** `CheckFrozenAttempt` re-reads the Attempt status under the scoring locks. Add a test where
   the Attempt stops being frozen after the preliminary read and before the locked read (a `DB::listen`
   hook on the recipient lock): the check returns `false` and writes nothing to the Attempt or its answers.
4. **`B-1`.** Repair sweep cases:
   - a missing official Blitz row is repaired (the Blitz half of the pair filter);
   - a Blitz with an exception whose invalidated #1 still waits for review and whose replacement #2 is
     checked, with no row, is repaired with the replacement (the pending probe counts only eligible
     Attempts);
   - two checked Homework Attempts with equal scores and the row on the lower number are not a candidate.
5. **`C-2`.** Review save on the official Blitz: completing #1 without an exception stores the row with
   `valid_normal_blitz`; with an exception, reviewing the invalidated #1 stores nothing and reviewing the
   replacement #2 stores the row with `approved_blitz_exception_replacement`.
6. **`C-3`.** Status never restricts review (`S09-DOC-001` §10.1): an archived Topic with an archived
   Homework still lists the submission in the queue, shows its detail and accepts a review.
7. **`D-1`.** An archived finished Blitz shows the visible result and feedback of its checked #1.
8. **`D-2`.** A classmate's official row, Attempts and Teacher feedback on the same Homework, with automatic
   release, never change the Student's Homework list item, detail or Attempt read.
9. **Repair pair filter (`A-1`, `B-3`, `E-1`).** `RepairOfficialTaskScores::candidates()` selects official
   Attempts with a correlated `EXISTS` whose `OR` across `homework_assessment_id` and
   `blitz_assessment_id` cannot use an index or a hash join. Replace it with the equivalent uncorrelated
   row-value membership `(institution_id, assessment_id) in (pair Homework ids union all pair Blitz ids)`.
   The selected set is identical (the pair's composite foreign keys tie each id to its Institution).

### Non-goals

- No change to the repair rule, the schedule (`everyMinute`, `withoutOverlapping(5)`), the scan's
  full-history shape or any index; those are recorded dispositions in the review (§8).
- No production change other than item 9. No API, error code, route, schema or documentation change.
- None of the other accepted P3 items (review §7).

## 4. Tests and Verification

Each new test must fail against a mutation of the rule it protects (recorded in the PR):

| Item | Mutation |
|---|---|
| 2 | close writes `timed_out_finalized` for a before-deadline Attempt, or `submitted` after the deadline |
| 3 | remove the status re-check under the lock |
| 4 | drop the Blitz half of the pair filter; drop `pending.official_score_eligible`; flip the `attempt_number` order |
| 5 | resolver Blitz branch ignores the exception |
| 6 | add a Topic status filter to `TeacherSubmissionAccess::query` |
| 7 | the finished list shows results only for `closed` |
| 8 | drop the `student_id` filter from the official row query |

```text
vendor/bin/phpunit <each changed test file>
vendor/bin/pint --test <changed PHP files>
git diff --check
Full backend suite (Phase 2 run #2): php artisan test — must pass
```

## 5. Acceptance Criteria

- [ ] The full backend suite passes (Phase 2 run #2).
- [ ] Every item in §3 is implemented; each new test was seen failing against its mutation.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.
