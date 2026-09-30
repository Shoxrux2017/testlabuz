# Implementation Contract: S09-FE-001A — Exception-Grant Warning, `CL-6`, `CL-7`

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-FE-001A` (first part of the planned `S09-FE-001`; `S09-FE-001B` is the Homework review deadline) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Frontend` (Teacher) |
| Status | `Approved` |
| Depends on | `S09-BE-PHASE-2` — `PASS` (PR #301, `main` `95992d3`) |
| Implementation baseline | `origin/main` `95992d3` |
| Decisions applied | `S09-D4` (the grant dialog states the official-score consequence); Stage 8 closure `CL-D1` (`CL-6`, `CL-7` fixed in Stage 9) |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |

This file is the complete task contract.

## 2. Goal

1. The Teacher sees the official-score consequence before granting an additional Blitz attempt.
2. The Question builder and editor states type their start-of-mutation authority, so the compiler checks
   it (`CL-6`).
3. The Homework activation client treats `official_cohort_mismatch` as a definite conflict with a
   specific message (`CL-7`).

## 3. Scope

### Included

1. **Grant warning (`S09-D4`, `S09-DOC-001` §8 Blitz).** `TeacherBlitzAttemptExceptionDialog` shows a
   second explanatory text below the existing helper, with the key
   `teacherBlitzAttemptExceptionOfficialScoreWarning`:

   ```text
   If this is the Topic's official Blitz:
   the original attempt stops counting, and any current official Blitz score is withdrawn;
   the replacement attempt becomes official once it is fully checked, including any Teacher review;
   if the Blitz is closed before the Student starts the replacement, the Student has no official Blitz score.
   ```

   The lines are separated by `\n`, like the existing helper. It is always shown, because the dialog does
   not know whether the Blitz is the official one, so the condition heads every consequence. No behavior of
   the dialog changes. (Review correction: the first wording put the condition on one sentence only and
   said "checked" where a Teacher review may be needed.)
2. **`CL-6`.** A new marker type `abstract interface class TeacherQuestionAuthorityState {}` in
   `lib/features/teacher/application/teacher_question_authority_state.dart`, with a one-line doc comment:
   the detail state that authorizes a Question mutation. `TeacherHomeworkDetailState` and
   `TeacherBlitzDetailState` implement it. `authorityStateAtStart` in
   `TeacherQuestionBuilderPendingOperation` and `TeacherQuestionEditorPendingOperation` becomes
   `final TeacherQuestionAuthorityState authorityStateAtStart;`. The identity comparisons in the four
   controllers are unchanged.
3. **`CL-7`.** `teacher_homework_remote_data_source.dart`: the Homework activate conflict set adds
   `ApiErrorCodes.officialCohortMismatch`. `TeacherHomeworkLifecycleController`:
   - refreshes the Topic result pair on this conflict, as it does for `result_pair_locked`;
   - shows this message:

     ```text
     The official Homework cohort does not match the Topic's established official cohort.
     Refresh the official pair and Homework before continuing.
     ```

     The two lines are separated by `\n`.

### Non-goals

- No API, backend, route or parser change. No change to the Blitz lifecycle.
- No official-status lookup for the grant dialog.
- No change to the Homework close or archive conflict sets.
- No review-deadline UI (`S09-FE-001B`).

## 4. Tests

- `teacher_blitz_monitoring_screen_test.dart`: the grant dialog shows the warning text exactly.
- `teacher_homework_lifecycle_data_test.dart`: `activate` + `409 official_cohort_mismatch` is a definite
  failure. Add it to the documented-conflict cases. The same code on `close` and `archive` stays an
  unknown outcome.
- `teacher_homework_lifecycle_controller_test.dart`: `activate` + `official_cohort_mismatch` gives
  `definiteFailure`, the message above, the Homework re-read and a result-pair refresh (two pair
  fetches), like `result_pair_locked`.
- `CL-6` is a static typing change: `flutter analyze` must pass, and the existing Question builder and
  editor controller tests must pass unchanged.

## 5. Verification

```text
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze
flutter test test/features/teacher
git diff --check
```

## 6. Acceptance Criteria

- [ ] §3 is implemented exactly; each new test is seen failing before the change.
- [ ] `flutter analyze` is clean; `flutter test test/features/teacher` passes.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.
