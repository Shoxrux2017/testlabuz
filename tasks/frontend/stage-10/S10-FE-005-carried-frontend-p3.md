# Implementation Contract: S10-FE-005 — Carried Frontend P3 Fixes

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S10-FE-005` |
| Stage | `Stage 10 — Final Result and Understanding Assessment` |
| Area | `Frontend` (Student and Teacher polish) |
| Status | `Approved` |
| Depends on | `S10-FE-004` on `main` `89d94e2` |
| Owner decisions applied | `S09-FE-PH2-D1` (carried P3), frontend plan (index §7 row `10`) |
| Implementation | Claude |
| Delivery | Claude opens the PR and merges it after review `PASS` and green verification |
| Blocks | `S10-FE-PHASE-2` |

Sources: `tasks/frontend/stage-09/S09-FE-PHASE-2-frontend-block-review.md` §§7-8; `STAGE_09_TASK_INDEX.md` §10
(`FE-PH2` carried row).

## 2. Goal

Close the carried Stage 9 frontend P3 findings that the plan scheduled: one user-visible defect (a deferred upload
during the leave confirmation), two presentation defects, picker robustness, review accessibility, and missing
tests. `C-4` (screen size and controller boilerplate) and `D-4` (duplicated `scoreVisible`) stay carried.

## 3. Scope

Included: §5.1-§5.8. Non-goals: `C-4`, `D-4`; enabling new lints; any backend change; new product behavior.

## 4. Current Context

The deferred uploads live in `student_file_answer_controller.dart` and `student_blitz_file_answer_controller.dart`;
the leave confirmations in `student_homework_attempt_screen.dart` (`_backToHomework`) and
`student_blitz_detail_screen.dart` (`_confirmLeave`). The review-deadline SnackBar fallback is in
`teacher_homework_detail_screen.dart`; review fields and bar in `teacher_submission_detail_screen.dart`; the
pickers in six Teacher create/edit/schedule files.

## 5. Exact Contract

### 5.1 Deferred upload during the leave confirmation (Homework and Blitz)

A file picked while the Attempt is read again (Homework) or replayed (Blitz) waits as `_deferredUpload`. Today it
can start while "Leave Attempt?" (Homework) or a Blitz leave confirmation is open. Fix:

- Both file controllers gain `holdDeferredUpload()` and `releaseDeferredUpload()`. While held, a deferred upload
  never starts; release starts it when the Attempt is authoritative (Homework) or accepts writes (Blitz).
- The Homework and Blitz screens hold before showing their leave confirmation and release afterwards unless the
  Student chose Leave (Leave already clears the controllers and drops the file). The "Saving answers…" flush
  dialog is not held.
- Tests: a deferred pick does not upload while the confirmation is open; Stay uploads it once; Leave never uploads.

### 5.2 `B-2` — archived review-deadline conflict shown twice

The SnackBar for a `409 task_archived` review-deadline conflict is a fallback for when the review-deadline section
is hidden. It shows only when the refreshed Homework is archived (the section is gone); otherwise the inline
section message is the only one. Test: the conflict whose refresh fails shows the message once, inline.

### 5.3 `B-3` — unreachable 500 test

The review-deadline controller case for a `500` definite failure is removed (the transport turns a 500 into an
unknown outcome, whose reconcile paths are already tested). The data test of unknown outcomes gains a `500`.

### 5.4 `B-4` — date pickers

The six Teacher date pickers (Homework deadline create/edit, review deadline, Blitz schedule, Topic lesson time
create/edit) use one helper whose range is 2000-01-01..2100-12-31 widened to always include the initial date.
Tests: the helper; a stored value in 2150 opens its picker without error.

### 5.5 `B-5` — import order

The Homework and Blitz detail screens import their presentation files in alphabetical order.

### 5.6 `C-3` — review validation announcement and focus

- A save stopped by client validation also sets the bar message "Some answers need attention. Check the marked
  fields." (the existing live region announces it; an edit clears it).
- After client validation or a `422` marks fields, the first marked field (Question order; points before
  feedback) receives focus.
- While a save runs the review fields are read-only instead of disabled, so the field being edited keeps focus.

### 5.7 `A-2` — autosave tests

Widget tests: a written answer saves when its field loses focus (before the debounce); dirty answers save when the
app is paused (Homework) and when the app is paused during a Blitz.

### 5.8 `D-3` — role test on review paths

A router test opens every Teacher review path (global queue, submission detail, Homework and Blitz queues, a
Student's result submissions) as a Student and as a Parent: no review screen, no request, the role's entry.

## 6. Verification

```text
flutter test test/features/teacher test/features/student test/router_bootstrap_test.dart;
flutter analyze --no-pub lib test; dart format --output=none --set-exit-if-changed lib test; git diff --check
```
