# Implementation Contract: S09-BE-007C — Student Finished Blitz List

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-BE-007C` (third part of the planned `S09-BE-007`) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Backend` (new read-only endpoint; no existing response changes, so no frontend parser change) |
| Status | `Approved` |
| Depends on | `S09-BE-007B — Accepted / Delivered` (PR #299, `main` `bb6da8b`) |
| Implementation baseline | `origin/main` `bb6da8b` |
| Decisions applied | `S09-D3` (automatic release), `S09-D4` (the replacement counts after an exception), `S09-D5` (feedback), `S09-T7` (invalidated #1 never shows a score) |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |
| Blocks | `S09-FE-004` (parses and displays the list) |

This file is the complete task contract.

## 2. Goal

A Student lists the Blitz tasks that have finished and, when results are released automatically, sees the
score and the Teacher's feedback of the Attempt that counts.

## 3. Scope

### Included

- `GET /api/v1/student/blitz/finished` (docs/09 §20.6, `S09-DOC-001` §12), declared before
  `GET /api/v1/student/blitz/{blitz}`.

### Non-goals

- No change to any existing Blitz or Homework response; no frontend change (the parser and screen are
  `S09-FE-004`); no Parent change; no migration.
- No read snapshot or locks: a closed Blitz cannot gain an exception or an Attempt, so only checking and review
  change what the list shows; a read racing a review commit may show a score and feedback from two consecutive
  commits once, and the next read is consistent.

## 4. Current Implementation Context

- `StudentBlitzAccess::query()` is the Student's Blitz access (persisted recipient, own Institution);
  `readQuery()` eager-loads the Topic, the task row, the Student's Attempts and exceptions.
- Teacher close finalizes every in-progress Attempt, and an activated Blitz is archived only after close, so a
  finished Blitz has only terminal Attempts and a `closed_at`.
- The list pattern: `StudentHomeworkIndexRequest` (strict query), `StudentHomeworkCollection` (pagination meta).
- `institution_settings.student_result_release_mode` and the Attempt visibility rule of `S09-BE-007B`.

## 5. Exact Contract

### 5.1 Request

Query parameters `page` (integer ≥ 1, default 1) and `per_page` (integer 1..100, default 25) only; no body.
Anything else is `422 validation_failed`.

### 5.2 Selection and order

The Student's Blitz tasks (persisted recipient, own Institution) with `activated_at` not null and status
`closed` or `archived`, ordered by `coalesce(closed_at, archived_at)` descending, then id descending, paged.

### 5.3 Item

```json
{
  "id": "uuid",
  "topic": { "id": "uuid", "title": "Internet Basics" },
  "title": "Topic Blitz",
  "status": "closed",
  "closed_at": "2026-09-30T10:00:00Z",
  "attempt_exception": false,
  "result": {
    "attempt_number": 1,
    "visible": true,
    "normalized_score": 82.0,
    "feedback": [ { "question_id": "uuid", "position": 3, "text": "Good explanation." } ]
  }
}
```

- `attempt_exception` ⇔ an approved exception exists for this recipient.
- The counting Attempt is replacement #2 when an exception exists, otherwise #1; `result` is `null` when there is
  no such Attempt (never started, or no replacement taken).
- `visible` ⇔ the counting Attempt is `checked` ∧ `official_score_eligible` ∧ the release mode is `automatic`
  (the Blitz is always closed or archived here). `normalized_score` is `null` and `feedback` is `[]` unless
  visible. `feedback` lists the counting Attempt's answers with non-null Teacher feedback, ordered by Question
  position.
- An invalidated #1 never shows a score. No correct answers, per-answer points or checking status, reviewer
  identity or other Students' data.
- Response: `{ "data": [items], "meta": { "pagination": { "page", "per_page", "total", "last_page" } } }`.

### 5.4 Design

- `StudentBlitzAccess::finishedQuery()` adds the selection, order and eager loads to `query()`.
- `ListStudentFinishedBlitz` pages the query, reads the release mode once and the visible feedback in one query
  for the page, and sets each Blitz's `student_finished_result`.
- `StudentBlitzFinishedRequest`, `StudentFinishedBlitzResource`, `StudentFinishedBlitzCollection`,
  `StudentBlitzController::finished`, route.
- The Attempt visibility rule moves into `StudentResultVisibility`, shared with `S09-BE-007B`'s
  `StudentHomeworkResults` (review correction: one authoritative rule for Stage 10 to change).

## 6. Security and Integrity

- Tenant and recipient scope come from the authenticated Student; no id is accepted. Another Student's
  Blitz, Attempts or feedback never appear.

## 7. Tests

`tests/Feature/Student/StudentFinishedBlitzApiTest.php`:

- Route registered once, before `blitz/{blitz}`, behind the Student gates; 401 and a Teacher's 403; unknown
  query parameters, a body and out-of-range `page`/`per_page` → `422`.
- Selection: closed and archived-after-close Blitz of the Student; not an active, scheduled or draft Blitz, one
  archived without activation, another Student's, another Institution's, or one without a recipient row.
- Order by close time then id; pagination meta and defaults.
- Result: a checked visible normal #1 with feedback ordered by position; waiting and submitted Attempts hidden;
  never started → `null`; exception with a checked replacement → #2 visible and `attempt_exception: true`;
  exception without a replacement → `null`; `manual_teacher` and unconfigured release → hidden with empty
  feedback.
- A classmate's Attempts, exception and feedback on the same Blitz never change the Student's item.
- Exact item keys; the list query count stays bounded as rows grow.

## 8. Expected Files

```text
backend/app/Actions/Student/ListStudentFinishedBlitz.php
backend/app/Http/Controllers/Api/V1/Student/StudentBlitzController.php
backend/app/Http/Requests/Student/StudentBlitzFinishedRequest.php
backend/app/Http/Resources/Student/StudentFinishedBlitzCollection.php
backend/app/Http/Resources/Student/StudentFinishedBlitzResource.php
backend/app/Support/Student/StudentBlitzAccess.php
backend/app/Support/Student/StudentHomeworkResults.php
backend/app/Support/Student/StudentResultVisibility.php
backend/routes/api.php
backend/tests/Feature/Student/StudentFinishedBlitzApiTest.php
tasks/backend/stage-09/S09-BE-007C-student-finished-blitz.md
tasks/STAGE_09_TASK_INDEX.md
tasks/README.md
```

## 9. Acceptance Criteria

- [ ] §5 is implemented exactly; no existing response changes.
- [ ] The §7 tests pass; the backend Student suite passes.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.

## 10. Verification

```text
vendor/bin/phpunit tests/Feature/Student/StudentFinishedBlitzApiTest.php
vendor/bin/phpunit tests/Feature/Student
vendor/bin/pint --test <changed PHP files>
git diff --check
```
