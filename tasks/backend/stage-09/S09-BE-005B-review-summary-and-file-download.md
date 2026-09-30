# Implementation Contract: S09-BE-005B — Teacher Review Counts and Submitted-File Download

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-BE-005B` (second half of the planned `S09-BE-005`) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Backend + Frontend parser` (`S09-T8`: the Teacher Homework and Blitz resources gain a key, so the Teacher parsers change in the same PR) |
| Status | `Approved` |
| Depends on | `S09-BE-005A — Accepted / Delivered` (PR #295, `main` `4737ea8`) |
| Implementation baseline | `origin/main` `4737ea8` |
| Decisions applied | `S09-D7` (counts for the mobile Teacher UI), `S09-T5` (Teacher file download), `S09-T8` |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |
| Blocks | `S09-FE-002` (queue and mobile counts), `S09-FE-003` (review screen file download) |

This file is the complete task contract.

## 2. Goal

The Teacher Homework and Blitz resources show how many submissions of that task wait for review and how many
of those are overdue, and a Teacher can download a Student's submitted file for any submission they may review.

## 3. Scope

### Included

- `review_summary` on every response that returns the Teacher Homework or Teacher Blitz resource, with the
  Teacher parser and domain change in the Flutter app (no UI change).
- The Teacher branch of `GET /api/v1/files/{file}/download` for `student_submission` Files.

### Non-goals

- No list resource change (`TeacherHomeworkListResource`, `TeacherBlitzListResource` stay as they are).
- No UI that shows the counts or downloads files (`S09-FE-002`, `S09-FE-003`).
- No change to the Student download path, learning-material downloads, or the review endpoints.

## 4. Current Implementation Context

- Every Teacher Homework response (detail, create, update, activate, close, archive, review-deadline update)
  is built by `ShowTeacherHomework` and rendered by `TeacherHomeworkResource`; every Teacher Blitz response
  (detail, create, update, schedule, activate incl. replays, close, archive) by `ShowTeacherBlitz` and
  `TeacherBlitzResource`. Resources throw `LogicException` when their projection is incomplete.
- `TeacherSubmissionAccess::query(User $teacher)` (`S09-BE-005A`) is the review access rule.
- Downloads: `DownloadProtectedFile` resolves the File category in the actor's Institution and dispatches to
  `DownloadLearningMaterialFile` or `DownloadStudentSubmissionFile`; the latter uses
  `ProtectedStudentSubmissionAccess`, which admits Students only (their own non-removed File on a file-based
  answer of a task in an allowed status), resolves a target, then inside a transaction locks the File
  `FOR SHARE`, re-checks the ownership graph and opens the stream. The route admits Teachers and Students.
- Flutter: `TeacherHomeworkDto.fromJson` and `TeacherBlitzDto.fromJson` read exact key sets through
  `readExactTeacherMap`; `readTeacherInt` reads integers; domain `TeacherHomework` and `TeacherBlitz` are
  immutable models constructed in a few places.

## 5. Exact Contract

### 5.1 `review_summary`

`App\Support\Teacher\TeacherReviewSummary::forTask(User $teacher, Assessment $assessment, ?CarbonInterface $reviewDueAt): array`
returns `['waiting_for_teacher_review' => n, 'overdue' => m]`:

- `n` = the Attempts of that Assessment with status `waiting_for_teacher_review` that pass
  `TeacherSubmissionAccess` (so it equals the queue's `assessment_id` + `checking_status=waiting_for_teacher_review` total);
- `m` = `n` when `$reviewDueAt` is not null and not later than server now, otherwise `0`; always `0` for Blitz
  (called with `null`).

`ShowTeacherHomework` and `ShowTeacherBlitz` set the `review_summary` attribute; `TeacherHomeworkResource`
(after `review_due_at`) and `TeacherBlitzResource` (after `attempt_policy`, before `activated_at`) render
`"review_summary": { "waiting_for_teacher_review": n, "overdue": m }` and throw `LogicException` when it is
missing.

### 5.2 Teacher submitted-file download

`DownloadProtectedFile` sends a `student_submission` File to `DownloadStudentSubmissionFile` for a Student and
to a new `DownloadReviewedSubmissionFile` for a Teacher. The Teacher path (`TeacherSubmissionFileAccess`)
admits the File when all hold, in the Teacher's Institution: the File is a non-removed `student_submission`
uploaded by the Attempt's Student; it is linked by `answer_files` to an answer of a `file_based` Question of the
Attempt's Assessment; and the Attempt passes `TeacherSubmissionAccess` (terminal status, visible Topic, matching
recipient). It resolves the target, then in a transaction locks the File `FOR SHARE`, re-checks the same graph
and opens the stream, like the Student path. Everything else — including Files of `in_progress` Attempts, other
Teachers' Topics, ended memberships and other Institutions — is `404 resource_not_found`. The response headers
and body are the existing download response.

### 5.3 Flutter

- New domain `TeacherReviewSummary { int waitingForTeacherReview; int overdue; }` and parser
  `TeacherReviewSummaryDto.fromJson` (exact keys; non-negative integers; `overdue ≤ waiting_for_teacher_review`;
  anything else throws the Teacher parse error used by the other Teacher DTOs).
- `TeacherHomeworkDto` and `TeacherBlitzDto` require the `review_summary` key and expose
  `TeacherHomework.reviewSummary` / `TeacherBlitz.reviewSummary`; the Blitz parser also rejects `overdue ≠ 0`.
- Test fixtures and model constructors are updated; no widget behaviour changes.

## 6. Security and Privacy

- Counts use the review access rule, so they never include work outside the Teacher's scope.
- The Teacher download never trusts client-supplied storage data; every rejection is the same `404`.

## 7. Tests

- Backend `tests/Feature/Teacher/TeacherTaskReviewSummaryTest.php` — detail, a mutation response of each task
  type, the counts (waiting only; other statuses and `in_progress` excluded), overdue at, before and without
  the review deadline, Blitz `overdue = 0`, equality with the queue total.
- Backend `tests/Feature/Teacher/TeacherSubmittedFileDownloadTest.php` — a Teacher downloads the file of a
  `submitted`, `waiting_for_teacher_review` and `checked` submission of an active, closed and archived task
  (headers and bytes as the Student path); `404` for an `in_progress` Attempt, another Teacher, an ended
  membership, another Institution, a removed File, a learning-material id through the submission path, and a
  File linked to another Student's Attempt; a Student's own download still works.
- Existing Teacher Homework/Blitz resource tests that assert the exact resource keys gain `review_summary`
  (deliberate, listed in the PR).
- Flutter Homework and Blitz DTO tests (`teacher_homework_dto_test.dart`, `teacher_blitz_dto_test.dart`) — the
  new key is required and parsed; missing, extra, negative, non-integer and `overdue > waiting` values are
  rejected; Blitz `overdue ≠ 0` is rejected. Fixtures and model constructors in the Teacher tests gain the key.

## 8. Expected Files

```text
backend/app/Support/Teacher/TeacherReviewSummary.php
backend/app/Support/Files/TeacherSubmissionFileAccess.php
backend/app/Actions/Files/DownloadReviewedSubmissionFile.php
backend/app/Actions/Files/DownloadProtectedFile.php
backend/app/Actions/Teacher/ShowTeacherHomework.php
backend/app/Actions/Teacher/ShowTeacherBlitz.php
backend/app/Http/Resources/Teacher/TeacherHomeworkResource.php
backend/app/Http/Resources/Teacher/TeacherBlitzResource.php
backend/tests/Feature/Teacher/TeacherTaskReviewSummaryTest.php
backend/tests/Feature/Teacher/TeacherSubmittedFileDownloadTest.php
backend/tests/Feature/... (exact-key updates, listed in the PR)
frontend/lib/features/teacher/domain/teacher_review_summary.dart
frontend/lib/features/teacher/data/dto/teacher_review_summary_dto.dart
frontend/lib/features/teacher/domain/teacher_homework.dart
frontend/lib/features/teacher/domain/teacher_blitz.dart
frontend/lib/features/teacher/data/dto/teacher_homework_dto.dart
frontend/lib/features/teacher/data/dto/teacher_blitz_dto.dart
frontend/test/features/teacher/... (DTO tests, JSON fixtures, model constructor call sites)
tasks/backend/stage-09/S09-BE-005B-review-summary-and-file-download.md
tasks/STAGE_09_TASK_INDEX.md
tasks/README.md
```

## 9. Acceptance Criteria

- [ ] §5 is implemented exactly; every Teacher Homework/Blitz resource response carries `review_summary`.
- [ ] The §7 tests pass; the Flutter app parses every Teacher Homework/Blitz response.
- [ ] The backend Teacher, Student, Checking and Persistence feature suites pass; the Flutter Teacher tests,
      `flutter analyze` and `dart format` pass.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.

## 10. Verification

```text
vendor/bin/phpunit tests/Feature/Teacher/TeacherTaskReviewSummaryTest.php tests/Feature/Teacher/TeacherSubmittedFileDownloadTest.php
vendor/bin/phpunit tests/Feature/Teacher tests/Feature/Student tests/Feature/Checking tests/Feature/Persistence
vendor/bin/pint --test <changed PHP files>
flutter test test/features/teacher
flutter analyze
dart format --output=none --set-exit-if-changed lib test
git diff --check
```
