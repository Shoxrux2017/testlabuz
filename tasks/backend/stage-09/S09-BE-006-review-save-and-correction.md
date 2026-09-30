# Implementation Contract: S09-BE-006 — Teacher Review Save and Correction

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-BE-006` |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Backend` (new endpoint; no existing response changes, no frontend change) |
| Status | `Approved` |
| Depends on | `S09-BE-005B — Accepted / Delivered` (PR #296, `main` `06fe754`) |
| Implementation baseline | `origin/main` `06fe754` |
| Decisions applied | `S09-T4` (partial saves, 0..points, feedback ≤ 2000, serialized concurrent saves, corrections allowed in Stage 9), `S09-D6`, `S09-D7` |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |
| Blocks | `S09-BE-007`, `S09-FE-003` |

This file is the complete task contract.

## 2. Goal

A Teacher saves points and feedback for the manual answers of a submission (all or some of them) and may
correct them later. Each save recalculates the Attempt and re-resolves the official score in one transaction.

## 3. Scope

### Included

- `PUT /api/v1/teacher/submissions/{submission}/review` (docs/09 §23.1, §23.2), its request, action, route and
  the `409 automatic_checking_pending` error.

### Non-goals

- No Student visibility or official-score read (`S09-BE-007`); no UI (`S09-FE-003`).
- No result-closure guard (Stage 10); no review history (the actor fields hold the last reviewer).
- No change to automatic checking, the queue, the detail or the download.

## 4. Current Implementation Context

- `TeacherSubmissionAccess` (review access rule, `resolve()` → `404`), `TeacherSubmissionProjection` and
  `ShowTeacherSubmission` (detail) from `S09-BE-005A`; the detail resource is `TeacherSubmissionDetailResource`.
- `RecipientScoringLock::lock($institutionId, $assessmentId, $recipientId)` takes the `S09-DOC-001` §8 order up to
  the recipient's Attempts; `OfficialTaskScoreResolver::resolve(...)` locks the official row last (`S09-BE-004`).
- `CheckingScoreMath` (`sum`, `normalizedScore`, `compare`) works on decimal strings; `AssessmentPointMath::normalize`
  enforces the Question points number rule (JSON number, at most 6 fractional digits) and returns a 6-decimal string.
- Strict JSON requests: `TeacherQuestionMutationRequest` (raw object decoding, typed checks, unknown keys and query
  parameters rejected). API errors: `ApiErrorResponse` + exception renderers in `bootstrap/app.php`.
- `attempt_answers.updated_at` is the Student's "last saved" time and must never change after the freeze.

## 5. Exact Contract

### 5.1 Request (`TeacherSubmissionReviewRequest`) — step 1, `422 validation_failed`

- `application/json` object with exactly the key `answers`; no query parameters (each is an error on its key;
  a non-object body is an error on `body`).
- `answers`: a non-empty JSON array; each item a JSON object with exactly `answer_id` (UUID string),
  `awarded_points` (JSON integer or float, not a string or boolean) and `feedback` (string or `null`); errors on
  `answers.N` / `answers.N.<field>`.
- `answer_id` values are unique case-insensitively (a duplicate is an error on its `answers.N.answer_id`).
- `feedback` is trimmed; an empty result becomes `null`; at most 2000 characters after trimming.

### 5.2 Action (`ReviewTeacherSubmission`)

Before the transaction, then again in it after the locks:

2. **Access** — `TeacherSubmissionAccess::resolve`; otherwise `404 resource_not_found`.
3. **State** — `submitted` or `timed_out_finalized` → `409 automatic_checking_pending`.
4. **Items** (`422 validation_failed`, all item errors together) — `answers.N.answer_id`: the answer belongs to
   this submission and is `waiting_for_teacher_review` or `teacher_checked`; `answers.N.awarded_points`: passes
   `AssessmentPointMath::normalize` and is between 0 and the Question's `points` inclusive.

Transaction: `RecipientScoringLock::lock(...)` for the submission's recipient; the submission's answers
`FOR UPDATE` ordered by id; steps 2–4 again; then with one server now per save:

- each item's answer: `awarded_points` (the normalized value), `feedback` (`null` clears it),
  `checking_status = teacher_checked`, `checked_by_user_id` = the Teacher, `checked_at` = now — written with the
  query builder so `attempt_answers.updated_at` never changes;
- the Attempt: still any `waiting_for_teacher_review` answer → `waiting_for_teacher_review` with null
  `earned_points`, `normalized_score`, `scoring_completed_at`; otherwise `checked` with
  `earned_points = sum(awarded_points of all its answers)`, `normalized_score = normalizedScore(earned,
  possible_points)` and `scoring_completed_at` = now (a correction recalculates a `checked` Attempt the same way);
  `updated_at` = now; frozen fields never change;
- `OfficialTaskScoreResolver::resolve(...)` with the locked Attempts and now.

### 5.3 Response and error

- `200` with the submission detail (`TeacherSubmissionDetailResource`, read after the commit) and
  `"message": "Submission review saved successfully."`.
- `ApiErrorResponse::automaticCheckingPending` → `409 { "message": "The submission is still waiting for automatic
  checking.", "code": "automatic_checking_pending" }` for `AutomaticCheckingPendingException`.
- Route in the `teacher` group: `Route::put('submissions/{submission}/review', ...)`.

## 6. Security and Integrity

- Access is re-checked under the locks; a Teacher never writes another Teacher's or another Institution's answers.
- Only manual-review answers change; automatic results and the Student's answer content never do.
- Concurrent saves of one submission serialize on the recipient lock; each answer keeps the last committed value.

## 7. Tests

- `tests/Feature/Teacher/TeacherSubmissionReviewApiTest.php` — route and middleware; every §5.1 shape error;
  the evaluation order (shape before access, access before state, state before items); access `404`s (malformed id,
  another Teacher, ended membership, another Institution, `in_progress`); `409` for `submitted` and
  `timed_out_finalized`; item `422`s (another submission's answer, an automatic answer, points above the Question,
  negative, seven decimals); a partial save keeps the Attempt waiting with null scores; completing the review
  checks it with exact earned and normalized scores and `scoring_completed_at`; a correction keeps it `checked` and
  recalculates; feedback trimming and clearing; reviewer and time; `attempt_answers.updated_at` unchanged; the
  official Homework score is created when the review completes and moves after a correction; the lock statements
  run in the §8 order ending with `official_task_scores update`; the response is the detail with the message.
- `tests/Feature/Teacher/TeacherSubmissionReviewConcurrencyTest.php` — two PostgreSQL worker processes save the
  same answer; the second waits on the recipient lock; the final value is the second commit's.

## 8. Expected Files

```text
backend/app/Actions/Teacher/ReviewTeacherSubmission.php
backend/app/Exceptions/Teacher/AutomaticCheckingPendingException.php
backend/app/Http/Requests/Teacher/TeacherSubmissionReviewRequest.php
backend/app/Http/Controllers/Api/V1/Teacher/TeacherSubmissionController.php
backend/app/Support/ApiErrorResponse.php
backend/bootstrap/app.php
backend/routes/api.php
backend/tests/Feature/Teacher/TeacherSubmissionReviewApiTest.php
backend/tests/Feature/Teacher/TeacherSubmissionReviewConcurrencyTest.php
tasks/backend/stage-09/S09-BE-006-review-save-and-correction.md
tasks/STAGE_09_TASK_INDEX.md
tasks/README.md
```

## 9. Acceptance Criteria

- [ ] §5 is implemented exactly; no existing response changes.
- [ ] The §7 tests pass.
- [ ] The backend Teacher, Checking, Student and Persistence feature suites pass.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.

## 10. Verification

```text
vendor/bin/phpunit tests/Feature/Teacher/TeacherSubmissionReviewApiTest.php tests/Feature/Teacher/TeacherSubmissionReviewConcurrencyTest.php
vendor/bin/phpunit tests/Feature/Teacher tests/Feature/Checking tests/Feature/Student tests/Feature/Persistence
vendor/bin/pint --test <changed PHP files>
git diff --check
```
