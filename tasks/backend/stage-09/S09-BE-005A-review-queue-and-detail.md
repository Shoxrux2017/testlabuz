# Implementation Contract: S09-BE-005A — Teacher Review Access, Submission Queue and Detail

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-BE-005A` (first half of the planned `S09-BE-005`) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Backend` (new read-only endpoints; no existing response changes, so no frontend parser change) |
| Status | `Approved` |
| Depends on | `S09-BE-004 — Accepted / Delivered` (PR #294, `main` `da53031`) |
| Implementation baseline | `origin/main` `da53031` |
| Decisions applied | `S09-D6` (practice work reviewed too), `S09-D7` (API does not check the device), `S09-T7` (invalidated #1 labelled, never official) |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |
| Blocks | `S09-BE-005B` (`review_summary`, Teacher file download), `S09-BE-006` (review save uses the same access and detail) |

This file is the complete task contract. The split of `S09-BE-005` into `005A` (this task) and `005B`
(`review_summary` with its Teacher Homework/Blitz parser change, and the Teacher submitted-file download) is
recorded in `tasks/STAGE_09_TASK_INDEX.md`.

## 2. Goal

A Teacher can list the checked and waiting work of the Students in their Topics and open one submission
with every Question, its configuration (including correct answers) and the Student's answer with its
checking state.

## 3. Scope

### Included

- The review access rule (§5.1), shared by every review resource.
- `GET /api/v1/teacher/submissions` (§5.2) and `GET /api/v1/teacher/submissions/{submission}` (§5.3).

### Non-goals

- `review_summary` on Teacher task details and the Teacher file download (`S09-BE-005B`); review save and
  correction (`S09-BE-006`); the official-score read and Student visibility (`S09-BE-007`).
- No change to any existing endpoint, resource, migration or index. The queue is served by the existing
  `assessment_attempts(institution_id, assessment_id, status)` and `attempt_answers(attempt_id, question_id)`
  indexes (answer counts are read for one page of Attempts by `attempt_id`); the optional partial index of
  `docs/08` §27.7 is not added.

## 4. Current Implementation Context

- Teacher routes live in the `teacher` group of `routes/api.php` (`auth:sanctum`, `active.account`,
  `password.changed`, `role:teacher`). A Topic is visible to a Teacher through `Topic::visibleToTeacher`
  (same Institution, `topics.teacher_id`, a current `group_teacher_memberships` row).
- Strict request pattern: `TeacherGroupIndexRequest` (accepted query keys, unknown keys and any body →
  `422 validation_failed`) and `TeacherHomeworkShowRequest` (no query, no body). Paginated collections return
  `meta.pagination { page, per_page, total, last_page }` (`TeacherGroupCollection`).
- Teacher Question configuration: `QuestionConfigurationReader::read` on a Question with `choiceOptions`,
  `trueFalseAnswer`, `shortAcceptedAnswers`, `matchingItems`, `orderingItems`, `fillBlanks.acceptedAnswers`
  loaded as in `ShowTeacherHomework`.
- Student answer values: `StudentHomeworkAttemptAnswerStates::historicalRead($institutionId, $attempt,
  $questions)` returns the canonical value of every answer in any checking state (file answers as
  `file { id, original_name, extension, size_bytes }`). Its `StudentHomeworkAnswerValue::loadQuestions` reloads
  choice/matching/ordering/blank relations with reduced columns, so the Teacher configuration must be read
  from a separately loaded Question collection.
- Official tasks: `topic_result_pairs.homework_assessment_id` / `blitz_assessment_id`. Homework review
  deadline: `homework_assignments.review_due_at` (nullable).
- Scores: `assessment_attempts.possible_points numeric(14,6)`, `earned_points numeric(16,8)`,
  `normalized_score numeric(12,8)`; answers `awarded_points numeric(16,8)`, `checked_by_user_id`,
  `checked_at`, `feedback`.

## 5. Exact Contract

### 5.1 Review access (`App\Support\Teacher\TeacherSubmissionAccess`)

A submission is an Attempt in `submitted`, `timed_out_finalized`, `waiting_for_teacher_review` or `checked`
where, all in the Teacher's Institution: its Assessment's Topic is visible to the Teacher
(`Topic::visibleToTeacher`), and its `assessment_student_id` is a persisted recipient row of the same
Assessment and Student. Topic, Homework and Blitz status never restrict it. The class offers the bare rule as
a query (inner joins only; a later writer locks in the `S09-DOC-001` §8 order, not through this query, whose
plain `FOR UPDATE` would also lock the joined rows) and `resolve(User $teacher, string $submissionId,
?Closure $scope)`; a non-UUID id or anything outside the rule (including `in_progress` Attempts) →
`404 resource_not_found`. The response projection (task, Topic, Group, Student, answer counts, `official`,
`review_overdue`) is a separate `TeacherSubmissionProjection` applied to that query; it reads server now once
per request.

### 5.2 `GET /api/v1/teacher/submissions`

Request `TeacherSubmissionIndexRequest` (strict: unknown query key or any body → `422 validation_failed`
with the key as field). All parameters optional:

| Parameter | Values |
|---|---|
| `assessment_id`, `topic_id`, `group_id`, `student_id` | UUID; an id outside the Teacher's scope matches nothing |
| `checking_status` | `waiting_for_teacher_review`, `checked`, `automatic_checking_pending` (= `submitted` or `timed_out_finalized`) |
| `type` | `homework`, `blitz` |
| `official` | `true`, `false` |
| `overdue` | `true` |
| `sort` | `default` (default), `finalized_at`, `student_name`, `review_due_at` |
| `direction` | `asc` (default), `desc` |
| `page` | integer ≥ 1, default 1 |
| `per_page` | integer 1..100, default 25 |

Derived values (per Attempt):

- `official` = the Assessment is its Topic pair's Homework or Blitz **and** `official_score_eligible`.
- `review_due_at` = the Homework's `review_due_at`; always null for Blitz.
- `review_overdue` = status `waiting_for_teacher_review` **and** `review_due_at` not null **and**
  `review_due_at` ≤ server now.

Filters combine with AND. Ordering:

- `sort=default` ignores `direction`: `official` true first, then `review_overdue` true first, then
  `finalized_at` ascending, then Attempt `id` ascending.
- `finalized_at` / `student_name` (case-insensitive `full_name`) / `review_due_at` follow `direction`, then
  Attempt `id` in the same direction; `review_due_at` null values are last in both directions.

Response `200`: `data` = list of items, `meta.pagination` as `TeacherGroupCollection`. Item, exactly these keys:

```json
{
  "id": "attempt-uuid",
  "assessment": { "id": "uuid", "type": "homework", "title": "Homework 1" },
  "official": true,
  "topic": { "id": "uuid", "title": "Internet Basics" },
  "group": { "id": "uuid", "name": "7-A" },
  "student": { "id": "uuid", "full_name": "Student Name" },
  "attempt_number": 2,
  "status": "waiting_for_teacher_review",
  "official_score_eligible": true,
  "finalization_reason": "student_submit",
  "finalized_at": "2026-09-30T10:00:00Z",
  "review": { "waiting_answers": 1, "reviewed_answers": 0 },
  "review_due_at": "2026-10-02T18:00:00Z",
  "review_overdue": false,
  "score": { "earned_points": null, "possible_points": 20, "normalized_score": null }
}
```

- `review.waiting_answers` / `reviewed_answers` = the Attempt's answers in `waiting_for_teacher_review` /
  `teacher_checked`.
- `score.earned_points` and `normalized_score` are JSON numbers from the stored decimals when the Attempt is
  `checked`, otherwise null; `possible_points` is the Attempt's Start snapshot as a JSON number.
- Timestamps are UTC `Y-m-d\TH:i:s\Z`.
- The list runs a bounded number of queries per page (no per-item query).

### 5.3 `GET /api/v1/teacher/submissions/{submission}`

Request `TeacherSubmissionShowRequest` (no query, no body; else `422`). Access §5.1, else `404`.
Response `200` `{ "data": { ...every §5.2 item key..., "submitted_at": ..., "questions": [...] } }`;
`submitted_at` is the Attempt's value (null for timeout and close finalizations). `questions` lists every
Question of the Assessment in `position` order:

```json
{
  "question": { "id": "uuid", "type": "open_written", "position": 3, "prompt": "Explain DNS.",
                "points": 5, "checking_mode": "manual", "configuration": {} },
  "answer": { "id": "answer-uuid", "value": {}, "checking_status": "waiting_for_teacher_review",
              "awarded_points": null, "feedback": null, "checked_by": null, "checked_at": null }
}
```

- `question.configuration` is the Teacher Question resource configuration (`QuestionConfigurationReader`,
  correct answers included; `{}` when empty) plus the ids that `answer.value` refers to: `options[].id`,
  `pairs[].left_item_id` / `right_item_id`, `items[].id` and `blanks[].id`, matched to each row by its unique
  position, match key, correct position or blank key. `points` is a JSON number. (Review correction: without
  these ids the Teacher cannot tell which option, item or blank a Student chose; `docs/09` §21.2 is updated in
  this task. The Teacher authoring resource itself is unchanged.)
- `answer` is null for an unanswered Question; otherwise `value` is the historical canonical value (§4),
  `awarded_points` a JSON number or null, `feedback` the stored text or null, `checked_by`
  `{ id, full_name }` of `checked_by_user_id` or null, `checked_at` UTC or null.
- An answer that fails the historical integrity rules is a server error (`500`, no details), as in Student
  reads.

## 6. Security and Privacy

- Every query is scoped to the Teacher's Institution and visible Topics; ids from the query string only
  narrow that scope. No `404` or count leaks another Teacher's work.
- The detail exposes correct answers and other Students' nothing: it is the Teacher's own Topic.
- No write happens; no lock is taken.

## 7. Tests

- `tests/Feature/Teacher/TeacherSubmissionQueueApiTest.php` — the route and middleware; the access rule
  (another Teacher's Topic, an ended membership, another Institution, `in_progress` Attempts, a missing
  recipient row → absent); every filter, including ids outside the scope; `official` for official,
  practice and invalidated Blitz #1; `review_overdue` at, before and after `review_due_at`; every sort and
  direction with the id tie-break and null-last `review_due_at`; the default order; pagination meta and
  `per_page` bounds; strict query and body validation; the exact item keys and values; a bounded query count.
- `tests/Feature/Teacher/TeacherSubmissionDetailApiTest.php` — exact keys; every Question in position
  order, unanswered ones with `answer: null`; Teacher configuration with correct answers; answer values of
  every type including a file; `checked_by` of a reviewed answer; automatic results without a reviewer;
  `404` for a malformed id, another Teacher, an `in_progress` Attempt and another Institution; strict
  request validation.

## 8. Expected Files

```text
backend/app/Support/Teacher/TeacherSubmissionAccess.php
backend/app/Support/Teacher/TeacherSubmissionProjection.php
backend/app/Support/Teacher/TeacherSubmissionQuestion.php
backend/app/Actions/Teacher/ListTeacherSubmissions.php
backend/app/Actions/Teacher/ShowTeacherSubmission.php
backend/app/Http/Requests/Teacher/TeacherSubmissionIndexRequest.php
backend/app/Http/Requests/Teacher/TeacherSubmissionShowRequest.php
backend/app/Http/Controllers/Api/V1/Teacher/TeacherSubmissionController.php
backend/app/Http/Resources/Teacher/TeacherSubmissionResource.php
backend/app/Http/Resources/Teacher/TeacherSubmissionCollection.php
backend/app/Http/Resources/Teacher/TeacherSubmissionDetailResource.php
backend/routes/api.php
backend/tests/Feature/Teacher/TeacherSubmissionQueueApiTest.php
backend/tests/Feature/Teacher/TeacherSubmissionDetailApiTest.php
backend/tests/Feature/Teacher/Concerns/BuildsTeacherSubmissionContext.php
docs/09-api-contracts.md
tasks/backend/stage-09/S09-BE-005A-review-queue-and-detail.md
tasks/STAGE_09_TASK_INDEX.md
tasks/README.md
```

## 9. Acceptance Criteria

- [ ] §5 is implemented exactly; no existing response, schema or index changes.
- [ ] The §7 tests pass.
- [ ] The backend Teacher, Checking, Student and Persistence feature suites pass.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.

## 10. Verification

```text
vendor/bin/phpunit tests/Feature/Teacher/TeacherSubmissionQueueApiTest.php tests/Feature/Teacher/TeacherSubmissionDetailApiTest.php
vendor/bin/phpunit tests/Feature/Teacher tests/Feature/Checking tests/Feature/Student tests/Feature/Persistence
vendor/bin/pint --test <changed PHP files>
git diff --check
```
