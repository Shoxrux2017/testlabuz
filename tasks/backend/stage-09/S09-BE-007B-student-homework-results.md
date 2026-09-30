# Implementation Contract: S09-BE-007B — Student Homework Results

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-BE-007B` (second part of the planned `S09-BE-007`) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Backend + FE parser` (existing Student responses change; the Student parser changes in the same PR, `S09-T8`) |
| Status | `Approved` |
| Depends on | `S09-BE-007A — Accepted / Delivered` (PR #298, `main` `1171e24`) |
| Implementation baseline | `origin/main` `1171e24` |
| Decisions applied | `S09-D3` (automatic release shows results in Stage 9), `S09-D5` (feedback on answers), `S09-T8` (parser ships with the response change) |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |
| Blocks | `S09-FE-004` (display) |

This file is the complete task contract.

## 2. Goal

A Student reads, when results are released automatically, the score of each checked Homework Attempt, the
Teacher's feedback on its answers and the official Homework score; the Flutter Student parser accepts these
fields. No screen changes (display is `S09-FE-004`).

## 3. Scope

### Included

- Student Homework summary (list) and detail: `official_score`; `score_visible` computed; detail
  `attempt_results` (docs/09 §17.1–§17.2).
- Student Homework Attempt resource (`GET /student/attempts/{attempt}`, Homework Start and Submit
  responses, and their replays): `result`; each item of `answers` gains `feedback` (docs/09 §17.4, §17.13).
- The Flutter Student Homework summary, detail, Attempt and Submit parsers and domain models.

### Non-goals

- No UI change; no Blitz change: the Blitz Attempt resource, Blitz answers and every `PUT` answer response keep
  their exact shape (Blitz results are `S09-BE-007C`). No Parent change. No migration.
- The Topic resources are unchanged (they embed no Homework).

## 4. Current Implementation Context

- `StudentHomeworkAccess::query()/readQuery()` is the Homework read projection (no `assessments.type`; the
  eager-loaded Attempts lack `official_score_eligible`, `possible_points`, `normalized_score`).
  `ListStudentHomework`, `ShowStudentHomework` and `ShowStudentHomeworkAttempt` (which calls
  `ShowStudentHomework`) build the responses; Start and Submit re-render through `ShowStudentHomeworkAttempt`,
  and idempotent replays re-render live (no stored body).
- `StudentHomeworkSummaryResource` hard-codes `score_visible: false`; `StudentAttemptAnswerStateResource` is
  shared by the Homework Attempt, the Blitz Attempt and the `PUT` answer response.
- `institution_settings.student_result_release_mode` (`StudentResultReleaseMode`: `automatic`,
  `manual_teacher`, or `null` while unconfigured).
- `OfficialScoreReader` (`S09-BE-007A`) confirms a stored row against a live `OfficialScoreEvaluator`
  evaluation (same Attempt and score); `OfficialTaskDesignation::isOfficial` is the Topic-pair check. The
  evaluator loads the answers of waiting Attempts with one query per call.
- `StudentHomeworkReadApiTest` bounds the list's query count as rows grow.

## 5. Exact Contract

### 5.1 Visibility rules

- `released` ⇔ the Student's Institution `student_result_release_mode = automatic`.
- An Attempt result is visible ⇔ `status = checked` ∧ `official_score_eligible` ∧ `released`.
  `result = { "visible": bool, "normalized_score": number|null }`; the score is null unless visible.
- An answer's `feedback` is the Teacher's `attempt_answers.feedback` when its Attempt result is visible,
  otherwise `null` (an unanswered Question has no entry in `answers`).
- `official_score = { "normalized_score": number, "attempt_number": int }` ⇔ `released` ∧ the Homework is the
  official Homework of its Topic pair ∧ the persisted official row exists and a live evaluation yields the same
  Attempt and score (the `007A` ready rule); otherwise `null`. `score_visible = (official_score ≠ null)`.

### 5.2 Responses

- Summary (list items): keys `id, topic, title, status, deadline_at, attempts, my_status, score_visible,
  official_score`.
- Detail: keys `id, topic, title, description, student_instructions, status, deadline_at,
  total_possible_points, attempts, my_status, score_visible, official_score, attempt_results, questions`;
  `attempt_results` = every terminal Attempt in `attempt_number` order as
  `{ "attempt_id", "attempt_number", "status", "result" }`.
- Homework Attempt: keys `id, assessment_id, attempt_number, status, started_at, submitted_at,
  finalized_at, finalization_reason, deadline_at, result, questions, answers`; each `answers` item has keys
  `question_id, type, answer, updated_at, feedback`. Start, Submit and replays use this resource.
- Nothing else is added: never correct answers, per-answer points or checking status, reviewer identity or
  `review_due_at`.

### 5.3 Backend design

- `StudentHomeworkAccess::query()` selects `assessments.type`; `readQuery()` also loads the Attempts'
  `official_score_eligible`, `possible_points`, `normalized_score`.
- New `App\Support\Student\StudentHomeworkResults::apply(User $student, iterable<Assessment> $homework,
  ?StudentResultReleaseMode $mode): void` sets `student_official_score` on each Homework and `student_result`
  on each of its Attempts. Its query count does not grow with rows: nothing when not released; otherwise one
  pair query, one official-row query and at most two queries loading the answers (with Question points) of
  waiting Attempts that a stored row depends on; the evaluator uses those loaded answers.
- `OfficialScoreEvaluator` uses an Attempt's already loaded `answers` (each with its `question`) for the upper
  bound and queries only the others; existing callers load none, so their behavior is unchanged.
  `OfficialScoreReader` exposes its row-versus-evaluation check for reuse.
- `ListStudentHomework` reads the release mode once; `ShowStudentHomework` adds it to its existing settings
  read. The Homework Attempt resource adds `feedback` itself; `StudentAttemptAnswerStateResource` is unchanged.

### 5.4 Flutter Student parser (`frontend/lib/features/student`)

- Summary and detail: `score_visible` is a bool; `official_score` is `null` or exactly
  `{normalized_score: number 0..100, attempt_number: int 1..3}`, non-null exactly when `score_visible` is true.
- Detail: `attempt_results` is a list of exactly `{attempt_id: UUID, attempt_number: 1..3, status:
  submitted|waiting_for_teacher_review|checked, result}` with strictly increasing numbers and unique ids; a
  visible `official_score` names an Attempt listed with a visible result of the same score.
- `result` is exactly `{visible: bool, normalized_score}`: visible requires a number 0..100 and (for an
  Attempt) status `checked`; hidden requires `null`. An in-progress Attempt's result is hidden.
- Homework Attempt answers take the extra `feedback` key (a non-empty string, or `null`: the server stores
  trimmed feedback and turns an empty one into `null`, so the parser does not re-trim); a non-null feedback
  requires a visible result. The shared answer parser takes this as an option, so Blitz
  Attempt answers and `PUT` answer responses still reject `feedback`.
- Domain: `StudentHomeworkSummary.officialScore`, `StudentHomeworkDetail.attemptResults`,
  `StudentHomeworkAttempt.result`, `StudentAttemptAnswerState.feedback` — optional with hidden/empty defaults
  so existing constructors compile; the Homework Attempt controller carries `result` across answer saves.

## 6. Security and Integrity

- Every read stays within the Student's own recipient graph and Institution; the release-mode gate is
  server-side. A Student never sees another Student's data, correct answers or per-answer points.

## 7. Tests

Backend (`tests/Feature/Student/StudentHomeworkResultsApiTest.php`, plus deliberate updates):

- Released: a checked eligible Attempt shows its score on the Attempt read, the Submit replay and the detail
  `attempt_results`; feedback shows on its answers; waiting and submitted Attempts stay hidden; an
  unanswered Question has no answer entry.
- Not released (`manual_teacher`, `null`): everything hidden, including feedback.
- `official_score`: official Homework, ready → visible on summary and detail with the official Attempt
  number; practice Homework, a missing or differing row, and a later Attempt that could overtake → `null`.
- The list query count stays bounded with released official Homework rows (including waiting Attempts).
- Blitz Attempt, Blitz answers and `PUT` answer responses keep their keys.
- Deliberate updates to Stage 7/9 tests that assert the exact Homework key sets or the absence of
  `feedback`/`official_score` (`StudentHomeworkReadApiTest`, `StudentHomeworkAttemptSubmitApiTest`,
  `StudentHomeworkAttemptStartApiTest`, `StudentHomeworkCheckedAttemptReadTest`,
  `StudentHomeworkAnswerSaveApiTest`, `StudentHomeworkFileAnswerApiTest`): assertions move to the new exact
  shapes; no assertion is dropped.
- `OfficialScoreEvaluator`: loaded answers give the same bounds as queried ones.

Frontend: parser tests for every §5.4 rule (accept and reject), fixtures updated, Blitz and `PUT` parsers
still reject `feedback`; `flutter analyze` and the Student feature tests pass.

## 8. Expected Files

```text
backend/app/Actions/Student/ListStudentHomework.php
backend/app/Actions/Student/ShowStudentHomework.php
backend/app/Http/Resources/Student/StudentHomeworkAttemptResource.php
backend/app/Http/Resources/Student/StudentHomeworkResource.php
backend/app/Http/Resources/Student/StudentHomeworkSummaryResource.php
backend/app/Support/Checking/OfficialScoreEvaluator.php
backend/app/Support/Checking/OfficialScoreReader.php
backend/app/Support/Checking/OfficialTaskDesignation.php
backend/app/Support/Student/StudentHomeworkAccess.php
backend/app/Support/Student/StudentHomeworkResults.php
backend/tests/Feature/Student/StudentHomeworkResultsApiTest.php
backend/tests/Feature/Checking/OfficialScoreEvaluatorTest.php
backend/tests/Feature/Student/* (deliberate updates listed in §7)
frontend/lib/features/student/data/dto/* (Homework summary/detail, Attempt, answer parser, Submit)
frontend/lib/features/student/domain/* (Homework, Attempt, answer state, result types)
frontend/lib/features/student/application/student_homework_attempt_controller.dart
frontend/test/features/student/* (parser tests and fixtures)
tasks/backend/stage-09/S09-BE-007B-student-homework-results.md
tasks/STAGE_09_TASK_INDEX.md
tasks/README.md
```

## 9. Acceptance Criteria

- [ ] §5 is implemented exactly; Blitz and `PUT` answer responses are unchanged.
- [ ] The §7 tests pass; the backend Student, Teacher, Checking and Persistence suites pass.
- [ ] `flutter analyze` is clean and the Student feature tests pass.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.

## 10. Verification

```text
vendor/bin/phpunit tests/Feature/Student/StudentHomeworkResultsApiTest.php tests/Feature/Checking/OfficialScoreEvaluatorTest.php
vendor/bin/phpunit tests/Feature/Student tests/Feature/Teacher tests/Feature/Checking tests/Feature/Persistence
vendor/bin/pint --test <changed PHP files>
flutter analyze
flutter test test/features/student
dart format --output=none --set-exit-if-changed <changed Dart files>
git diff --check
```
