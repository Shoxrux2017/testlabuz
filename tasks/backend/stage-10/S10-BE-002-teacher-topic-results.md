# Implementation Contract: S10-BE-002 — Teacher Topic Results and Comment

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S10-BE-002` |
| Stage | `Stage 10 — Final Result and Understanding Assessment` |
| Area | `Backend` (three new Teacher endpoints; no change to existing responses) |
| Status | `Approved` |
| Depends on | `S10-BE-001` delivered (PR #317, `main` `f720b8a`) |
| Implementation baseline | `origin/main` `f720b8a` |
| Owner decisions applied | `S10-D1` (comment), `S10-D2` (Teacher sees everything), `S10-D3`/`S10-D9` (work finished), `S10-D4`…`S10-D6` (visibility rule) |
| Technical decisions applied | `S10-T1`, `S10-T5` (numbers), `S10-T6` (access, locks), `S10-T7` (`result_closed` on the comment) |
| Implementation | Claude |
| Delivery | Claude opens the PR and merges it after review `PASS` and green verification |
| Blocks | `S10-BE-003` (release uses the visibility rule and the item), `S10-BE-004` (closure uses `result_closed`) |

This file is the complete task contract. `S10-DOC-001` §§11-12 and `docs/09` §§25.4-25.7 are the
normative source; this contract restates what the task needs.

## 2. Goal

The Topic's Teacher sees every cohort Student's Topic result — its explanation (sides, D, T, method,
consistency, final, category), its visibility state and which action is possible now — and writes the
optional Topic-result comment.

## 3. Scope

### Included

1. `TopicResultVisibility`: the Student and Parent value-visibility rule and the `can_*` flags (§5.2).
2. `GET /api/v1/teacher/topics/{topic}/results` (§5.4) and `GET /api/v1/teacher/topics/{topic}/results/{student}` (§5.5).
3. `PUT /api/v1/teacher/topics/{topic}/results/{student}/comment` (§5.6).
4. The `409 result_closed` error (exception, `ApiErrorResponse`, render mapping) (§5.7).
5. `UnicodeWhitespace::trim()` for the comment, in linear time (no backtracking over interior whitespace).

### Non-goals

- Release, close and bulk actions (`S10-BE-003`, `S10-BE-004`); Student and Parent reads; Stage 9 read changes.
- Any change to an existing endpoint or response; any frontend change.

## 4. Current Implementation Context

- `TopicResultReader::forTopic`/`forStudent` (`app/Support/Results`) return `TopicResultView`s ordered by
  Student id; no locks; callers wrap reads in one `REPEATABLE READ READ ONLY` snapshot
  (`StudentBlitzReadSnapshot::read`, used by the Teacher official-score read).
- `TeacherTopicLifecycleAccess::resolveTopic` (Topic owner + current group Teacher, else `404`) and
  `lockTopic` (group → membership → Topic `FOR UPDATE`).
- Strict requests read the raw JSON body (`TeacherSubmissionReviewRequest`) and reject query parameters;
  index requests reject unknown query keys and any body (`TeacherSubmissionIndexRequest`).
- Paginated Teacher collections return `meta.pagination {page, per_page, total, last_page}`
  (`TeacherSubmissionCollection`). Timestamps serialize as `Y-m-d\TH:i:s\Z` UTC; scores as JSON numbers.
- Error codes: an exception class, an `ApiErrorResponse` method and a render mapping in `bootstrap/app.php`.

## 5. Exact Contract

### 5.1 Access

Every endpoint resolves the Topic with `TeacherTopicLifecycleAccess::resolveTopic` (`404` when the
Teacher does not own it or is not a current Teacher of its group; non-UUID → `404`). `{student}` must be
a UUID of a cohort Student (`TopicResultReader::forStudent` not null), else `404`. Topic and task status
never restrict these endpoints.

### 5.2 `App\Support\Results\TopicResultVisibility`

From a `TopicResultView` and the Institution's current `student_result_release_mode` and
`parent_result_release_mode` (each nullable):

```text
outcome     = view.terminal or view.status = closed
studentSees = outcome and view.workFinished
              and (studentMode = automatic or row.student_released_at is set)
parentSees  = studentSees
              and (parentMode = with_student or (parentMode = manual_teacher and row.parent_released_at is set))
canReleaseToStudent = studentMode = manual_teacher and row.student_released_at is null and outcome and view.workFinished
canReleaseToParent  = parentMode = manual_teacher and row.parent_released_at is null and studentSees
```

`hidden` or null Parent mode → `parentSees = false`. `can_close` is `view.closable`.

### 5.3 Result item

```json
{
  "student": { "id": "uuid", "full_name": "Student Name" },
  "result_status": "calculated",
  "closed_outcome": null,
  "closed_at": null,
  "missing_component": null,
  "homework": { "assessment_id": "uuid", "state": "ready", "official_attempt_id": "uuid", "attempt_number": 2, "score": 88 },
  "blitz": { "assessment_id": "uuid", "state": "ready", "official_attempt_id": "uuid", "attempt_number": 1, "score": 84 },
  "score_difference": 4,
  "acceptable_difference": 10,
  "consistency": "consistent",
  "calculation_method": "average",
  "final_score": 86,
  "category_score": 86,
  "category": { "code": "understood_well", "label": "Understood well" },
  "teacher_comment": null,
  "visibility": {
    "student_release_mode": "manual_teacher",
    "student_visible": false,
    "student_released_at": null,
    "can_release_to_student": true,
    "parent_release_mode": "with_student",
    "parent_visible": false,
    "parent_released_at": null,
    "can_release_to_parent": false
  },
  "can_close": true
}
```

- Exactly these keys in this order. Scores are JSON numbers of the stored 8-decimal values (`(float)`).
- `state` is the side state; `assessment_id` is null only for a Blitz that is not designated; the Attempt
  id, number and score are non-null only for `ready`.
- `score_difference`, `acceptable_difference`, `consistency`, `calculation_method`, `final_score`,
  `category_score` are non-null only for a calculated result (open or closed). `category` is the
  numeric category for calculated, `{code: not_completed, label: "Not completed"}` for Not completed,
  null otherwise; labels come from `UnderstandingCategoryCode::label()`.
- `closed_at` and `closed_outcome` come from a closed row; `teacher_comment` and the release times
  from the Student's row (null when there is none).
- Release modes are the current Institution modes (null while unconfigured).

### 5.4 `GET /api/v1/teacher/topics/{topic}/results`

- Query: `result_status` (one of the seven statuses), `category` (one of the five codes), `page`
  (integer ≥ 1, default 1), `per_page` (integer 1-100, default 25). Any other query key or a request body
  → `422 validation_failed`.
- One snapshot read of the whole cohort. Items are ordered like every Teacher list of Students:
  `lower(full_name)` under the database collation, then Student id; the filters
  apply before paging (`category` matches `category.code`).
- Response `{"data": [items], "meta": {"pagination": {page, per_page, total, last_page}, "counts":
  {"waiting_for_homework": n, …}}}`; `counts` has all seven status keys (zero when none) and counts the
  whole cohort before filtering. A Topic without a cohort returns an empty list and zero counts.

### 5.5 `GET /api/v1/teacher/topics/{topic}/results/{student}`

`{"data": item + {"teacher_comment_updated_at", "teacher_comment_updated_by", "student_released_by",
"parent_released_by", "closed_by", "closure_reason"}}`; each `*_by` is `{id, full_name}` or null,
`closure_reason` is `teacher`, `topic_archived` or null. No query or body (`422`). One snapshot read.

### 5.6 `PUT /api/v1/teacher/topics/{topic}/results/{student}/comment`

- Body exactly `{"teacher_comment": string|null}` as an `application/json` object; any other key, a
  missing key, a non-string non-null value or a query parameter → `422 validation_failed`.
- Normalization: leading and trailing `UnicodeWhitespace` characters are trimmed; an empty result is null;
  more than 2000 characters after trimming (`mb_strlen`) → `422` on `teacher_comment`.
- Transaction: `lockTopic` (group → membership → Topic `FOR UPDATE`); the Student must be in the cohort
  (`404`); the Student's `topic_results` row is locked `FOR UPDATE` when it exists; a closed row →
  `409 result_closed` (even for an unchanged value); an unchanged value (stored comment, or no row and
  null) writes nothing; otherwise the row is created or updated with the comment, the Teacher and the
  current time as `teacher_comment_updated_by_user_id` / `teacher_comment_updated_at`.
- After commit: `200 {"message": "Topic result comment saved successfully.", "data": <detail>}` read as in
  §5.5.

### 5.7 `409 result_closed`

`App\Exceptions\ResultClosedException`, `ApiErrorResponse::resultClosed` (message `This result is
closed and can no longer be changed.`, code `result_closed`, status 409), rendered for API requests.
`ApiErrorContractTest` covers it.

## 6. Security and Integrity

All reads and writes are scoped to the Teacher's Institution and an owned Topic of a current group; a
Student outside the cohort or another Institution's id is `404`; no response exposes another Topic's data.
The comment write serializes on the Topic row with closure (`S10-BE-004`).

## 7. Tests

- **Visibility rule (unit-level, no HTTP)**: every combination that matters — not terminal, terminal
  without finished work, automatic, manual released/unreleased, closed, each Parent mode (incl. null),
  Parent released before/after Student visibility, each `can_*` flag.
- **List**: item JSON exact keys and values for calculated, Not completed, waiting, waiting for settings and
  closed results; ordering; each filter; pagination; `counts` before filtering; empty cohort; Topic of
  another Teacher, an ended membership or another Institution → `404`; unknown query key and body → `422`;
  query count independent of the cohort size.
- **Detail**: actor fields and `closure_reason`; Student outside the cohort → `404`.
- **Comment**: create, update, clear (null and blank), Unicode trim kept inside text, 2000 / 2001
  characters, strict body (`422` cases), unchanged value writes nothing (no `updated_at` change), closed →
  `409 result_closed` also for an unchanged value, outsider → `404`, other Teacher → `404`.
- **Error contract**: `result_closed` rendering.

HTTP read tests use `UsesBlitzReadSnapshot` (the snapshot requires transaction level 0).

## 8. Expected Files

```text
backend/app/Support/Results/TopicResultVisibility.php
backend/app/Domain/Text/UnicodeWhitespace.php (trim)
backend/app/Actions/Teacher/ListTeacherTopicResults.php, ShowTeacherTopicResult.php, UpdateTeacherTopicResultComment.php
backend/app/Http/Controllers/Api/V1/Teacher/TeacherTopicResultController.php
backend/app/Http/Requests/Teacher/TeacherTopicResultIndexRequest.php, TeacherTopicResultShowRequest.php, TeacherTopicResultCommentRequest.php
backend/app/Http/Resources/Teacher/TeacherTopicResultResource.php, TeacherTopicResultDetailResource.php, TeacherTopicResultCollection.php
backend/app/Exceptions/ResultClosedException.php, app/Support/ApiErrorResponse.php, bootstrap/app.php, routes/api.php
backend/tests/... (visibility, list, detail, comment, error contract)
tasks/backend/stage-10/S10-BE-002-teacher-topic-results.md, tasks/STAGE_10_TASK_INDEX.md
```

## 9. Acceptance Criteria

- [ ] §5.1-§5.7 implemented exactly; no existing response changes.
- [ ] Every §7 test group exists and passes; the existing suites stay green.
- [ ] Independent fresh-context review `PASS` (P1 = 0, P2 = 0).

## 10. Verification

```text
pint --test; phpunit tests/Unit tests/Feature/Results tests/Feature/Teacher tests/Feature/ApiErrorContractTest.php
git diff --check
```
