# Implementation Contract: S09-FE-003C — Official-Score Panel on the Submission (Desktop)

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-FE-003C` (third and last part of the planned `S09-FE-003`) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Frontend` (Teacher) |
| Status | `Approved` |
| Depends on | `S09-FE-003B` — delivered (PR #307, `main` `1983fdc`) |
| Implementation baseline | `origin/main` `1983fdc` |
| Decisions applied | `S09-D2`, `S09-D4`, `S09-D6` (official score rules), `S09-D7` (review is desktop-only), `S09-T3` (scores shown with one decimal) |
| Backend contract | `S09-DOC-001` §8 and §14, delivered by `S09-BE-007A` |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |

This file is the complete task contract.

## 2. Goal

On the desktop submission detail, the Teacher sees the Student's official score for the task:
- the score, which Attempt it comes from, and when it was selected;
- or why there is no official score yet.

The panel follows review saves and refreshes.

## 3. Backend Contract (read from the code)

`GET /api/v1/teacher/assessments/{assessment}/students/{student}/official-score` takes no query parameters and no body.

It returns `200` with an envelope that has exactly one key, `data`, and no `message`. `data` has exactly these keys:

| Key | Value |
|---|---|
| `assessment_id`, `student_id` | the requested ids |
| `assessment_type` | `homework` or `blitz` |
| `status` | `not_applicable`, `ready`, `waiting_for_replacement`, `automatic_checking_pending`, `waiting_for_teacher_review` or `no_completed_attempt` |
| `official_attempt_id` | UUID |
| `attempt_number` | integer |
| `normalized_score` | number from 0 to 100 |
| `selection_policy_code` | `highest_valid_completed`, `valid_normal_blitz` or `approved_blitz_exception_replacement` |
| `selected_at` | UTC timestamp |

Rules:
- The last five keys are all non-null when `status` is `ready`, and all null otherwise (`OfficialScoreReading`).
- Homework uses `highest_valid_completed`.
- Blitz uses `valid_normal_blitz` with Attempt 1, or `approved_blitz_exception_replacement` with Attempt 2. Blitz Attempts are always numbered 1 or 2 (`StartStudentBlitzAttempt`).
- `waiting_for_replacement` is a Blitz status.

Errors:
- `404 resource_not_found`: the Assessment is not visible to the Teacher, or the Student is not a recipient;
- `422 validation_failed`: query parameters or a body were sent;
- session errors.

`status` is evaluated live (`S09-DOC-001` §14), so a review save can change it.

## 4. Scope

### 4.1 Domain and parsing

**`TeacherOfficialScoreTarget`** has the fields:
- `assessmentId` and `studentId`, both canonical UUIDs, lowercased;
- `type`, a `TeacherSubmissionTaskType`.

It throws `ArgumentError` on a non-canonical id. It has value equality, and it is built from a submission with `TeacherOfficialScoreTarget.ofSubmission(TeacherSubmission)`.

**`TeacherOfficialScore`** has the fields:
- `assessmentId`, `assessmentType` and `studentId`;
- `status`, a `TeacherOfficialScoreStatus`;
- `officialAttemptId`, `attemptNumber`, `normalizedScore` and `selectedAt`;
- `selectionPolicy`, a `TeacherOfficialScoreSelectionPolicy`.

**`TeacherOfficialScoreDto`** parses strictly:
- the exact keys, enums and canonical ids;
- the ready and null rule;
- `normalized_score` from 0 to 100;
- `attempt_number` of at least 1;
- the policy for each type and the Blitz Attempt number;
- `waiting_for_replacement` only for Blitz.

Any violation is a `FormatException`.

### 4.2 Data

- **`TeacherSubmissionRemoteDataSource.fetchOfficialScore(assessmentId, studentId)`**:
  - It throws `ArgumentError` for non-canonical ids.
  - It sends `GET /teacher/assessments/{a}/students/{s}/official-score` with `followRedirects: false`.
  - It requires `200` and the exact `{data}` envelope.
  - A format failure is an invalid response.
- **`TeacherSubmissionRepository.fetchOfficialScore(TeacherOfficialScoreTarget target)`** returns the domain object. A response for another assessment, student or type is an invalid response.

### 4.3 Controller

**`teacherOfficialScoreControllerProvider`** is an `autoDispose.family` keyed by `TeacherOfficialScoreTarget`.

- It is active for desktop Teacher sessions only, and loads on build.
- Status: `initial`, `loading`, `data`, `refreshing`, `notFound` or `error`, with `isStale` when a failed refresh keeps the score.
- Actions: `refresh()` and `retry()`. `refresh()` replaces a load in flight, because that load may have read the
  score before a review save committed; its completion is dropped.
- `404 resource_not_found` gives `notFound`.
- Session errors clear the controller: `bootstrap()` runs, except for `authentication_required`.
- A completion from a previous session or from a replaced load is dropped.

Apart from `refresh()` replacing a load in flight, this is the lifecycle of `TeacherSubmissionDetailController`.

**Refreshes.**
- The detail screen's refresh button also refreshes the panel.
- `TeacherSubmissionReviewController` refreshes the panel together with its other related views (`S09-FE-003B` §4.4), if the panel exists. It does so after a confirmed save, a `404`, or a reconcile that does not confirm the save.

### 4.4 Screen

The panel is a card with key `teacherOfficialScorePanel`. It sits under the header card on the detail screen whenever a detail is displayed. Its heading is `Official score`, with header semantics.

| State | Content |
|---|---|
| loading | `LinearProgressIndicator`, key `teacherOfficialScoreLoading`, semantics label `Loading official score` |
| refreshing | The last data under a `LinearProgressIndicator`, key `teacherOfficialScoreRefreshing`, semantics label `Refreshing official score` |
| `ready` | `Score <one decimal>` (`formatScoreOneDecimal`); `Attempt <n> · <policy label>`, plus ` · This submission` when the official Attempt is this submission; `Selected <time>` (`formatTeacherReviewTime`, Institution time zone) |
| `not_applicable` | `Practice task: no official score.` |
| `waiting_for_replacement` | `Waiting for the Student's replacement attempt.` |
| `automatic_checking_pending` | `Waiting for automatic checking.` |
| `waiting_for_teacher_review` | `Waiting for Teacher review.` |
| `no_completed_attempt` | `No completed attempt counts yet.` |
| not found | `The official score is not available.` |
| error without data | `The official score could not be loaded.` and a `Retry` button, key `teacherOfficialScoreRetryButton` |
| stale | The last data, plus `The official score may be out of date.` and the same `Retry` button |

Policy labels:

| Policy | Label |
|---|---|
| `highest_valid_completed` | `Best checked attempt` |
| `valid_normal_blitz` | `Blitz attempt` |
| `approved_blitz_exception_replacement` | `Replacement attempt` |

Raw failure text is never shown.

### Non-goals

- No change to the review fields, the review bar or the `S09-FE-003A` lines.
- No mobile view, no backend change.
- No Topic result; that is Stage 10.

## 5. Tests

- **DTO.**
  - Ready Homework.
  - Ready Blitz, normal and replacement.
  - Every non-ready status.
  - Rejected:
    - an extra or missing key in `data` or the envelope;
    - an unknown status, type or policy;
    - ready with a null field;
    - not ready with a non-null field;
    - a policy for the wrong type;
    - a wrong Blitz Attempt number;
    - `waiting_for_replacement` on Homework;
    - a score outside 0..100;
    - Attempt 0;
    - a bad id or timestamp.
- **Data source.**
  - Method, path, no query or body, `followRedirects: false`.
  - A wrong status or envelope is an invalid response.
  - Non-canonical ids are rejected before transport.
  - The repository rejects a response for another target.
- **Controller.**
  - Load.
  - Inactive on mobile.
  - `404` gives not found.
  - Error and retry.
  - A failed refresh is stale.
  - A refresh during a load replaces it, and the first completion is dropped.
  - Session failures.
  - A session change drops the completion.
- **Review controller.** A confirmed save refreshes an existing panel and does not create a missing one.
- **Screen.**
  - Every status text.
  - The ready lines, with and without ` · This submission`, and the Institution time.
  - Loading, error with retry, stale, and not found.
  - The refresh button reloads the panel.

Review corrections (independent review: P1 = 0, P2 = 1, P3 = 3):
- a refresh during a load was ignored, so a load that read the score before a confirmed save could be shown
  as current; `refresh()` now replaces a load in flight;
- the panel shows a progress indicator while it refreshes;
- tests now cover a score that only `S09-T3` rounding shows correctly, the heading semantics, the panel
  position, every non-ready result field, and the panel refresh after a `404` and an unconfirmed save.

## 6. Verification

```text
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze
flutter test   (whole frontend suite, with TEMP on drive G:)
git diff --check
```

## 7. Acceptance Criteria

- [ ] §4 is implemented exactly; each new test is seen failing first.
- [ ] `flutter analyze` is clean; the whole `flutter test` suite passes.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.
