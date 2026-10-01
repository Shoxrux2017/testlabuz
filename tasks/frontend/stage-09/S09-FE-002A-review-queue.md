# Implementation Contract: S09-FE-002A — Teacher Review Queue (Desktop)

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-FE-002A` (first part of the planned `S09-FE-002`; `S09-FE-002B` adds the task review counts and the task-scoped queue) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Frontend` (Teacher) |
| Status | `Approved` |
| Depends on | `S09-FE-001B` — delivered (PR #303, `main` `6ed9b7a`) |
| Implementation baseline | `origin/main` `6ed9b7a` |
| Decisions applied | `S09-D6`: practice work is reviewed too, the queue filters official or practice work and lists official work first; `S09-D7`: review is desktop-only |
| Backend contract | `S09-DOC-001` §10.1–10.2 (`GET /api/v1/teacher/submissions`, delivered by `S09-BE-005A`) |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |

This file is the complete task contract.

## 2. Goal

On desktop, the Teacher opens a review queue that lists the submissions they may review, with filters,
sorting and pages. Opening a submission comes in `S09-FE-003`.

## 3. Current Implementation Context

- **Router.** Teacher routes live under `/teacher` in `app_router.dart`.
  - `_buildTeacherDestination(child, authoring: true)` gates a route to an eligible desktop Teacher
    session.
  - `AppRoutePaths.isTeacherApprovedLocation` lists the desktop locations; mobile keeps only the read
    routes and redirects everything else to `/teacher`.
  - Any query string or fragment on a Teacher path redirects to `/teacher`.
  - During bootstrap, `_keepsLocationDuringBootstrap` keeps the approved desktop locations.
- **List pattern.** Mirror these:
  - `TeacherHomeworkListQuery`, `TeacherHomeworkListController` and `TeacherHomeworkListState`: session
    ownership, generation guard, retained result while refreshing, a stale result after a failed refresh,
    session-failure handling;
  - `TeacherListEnvelopeDto` and `TeacherListPaginationDto` for strict envelope and pagination parsing;
  - `teacher_dto_parse.dart` for the strict readers.
- **Backend item** (`TeacherSubmissionResource`). The item has exactly these keys: `id`, `assessment`,
  `official`, `topic`, `group`, `student`, `attempt_number`, `status`, `official_score_eligible`,
  `finalization_reason`, `finalized_at`, `review`, `review_due_at`, `review_overdue`, `score`.
  - `assessment`: `{id, type, title}`.
  - `topic`: `{id, title}`.
  - `group`: `{id, name}`.
  - `student`: `{id, full_name}`.
  - `review`: `{waiting_answers, reviewed_answers}`.
  - `score`: `{earned_points, possible_points, normalized_score}`; earned and normalized are non-null
    exactly when the status is `checked`.
  - Status values: `submitted`, `timed_out_finalized`, `waiting_for_teacher_review`, `checked`.
  - Finalization reasons: `student_submit`, `timeout_auto_submit`, `task_closed_auto_finalize`,
    `homework_deadline_auto_submit`.
  - The envelope is `{data, meta: {pagination: {page, per_page, total, last_page}}}`.

## 4. Scope

### 4.1 Route and entry

- **Route.** Path `/teacher/reviews`, name `teacher-reviews`, `AppRoutePaths.teacherReviews`, predicate
  `isTeacherReviewQueuePath`. It is a desktop-only destination: an approved desktop location, kept during
  desktop bootstrap. Mobile and unsupported surfaces get `/teacher`, the same as any other unknown Teacher
  path, and a query string redirects to `/teacher` as before.
- **Entry.** The Teacher workspace header gains a desktop-only `FilledButton.tonalIcon` with key
  `teacherReviewQueueButton`, label `Review queue` and icon `Icons.fact_check_outlined`. It navigates to
  `/teacher/reviews`. Nothing changes on mobile.

### 4.2 Domain and data

- **`TeacherSubmission`.** The parsed item.
  - Enums: `TeacherSubmissionTaskType` (`homework`, `blitz`), `TeacherSubmissionStatus` (the four terminal
    statuses), and `TeacherSubmissionFinalizationReason` (the four reasons).
  - Fields: `waitingAnswers`, `reviewedAnswers`, `reviewDueAt`, `reviewOverdue`, `earnedPoints`,
    `possiblePoints`, `normalizedScore`.
- **`TeacherSubmissionList`.** Rows plus `TeacherListPagination`.
- **`TeacherSubmissionListQuery`.**
  - `checkingStatus` (`waiting_for_teacher_review`, `checked`, `automatic_checking_pending`, or null for
    all; the default is `waiting_for_teacher_review`).
  - `type` (null, `homework` or `blitz`).
  - `official` (null, true or false).
  - `overdueOnly` (sends `overdue=true` only when true).
  - `sort`: `default`, `finalized_at`, `student_name` or `review_due_at`.
  - `direction`: `asc` or `desc`. It is sent only for a sort other than `default`; when the sort returns
    to `default`, the direction resets to `asc`.
  - `page` (default 1) and `perPage` (25).

  Every filter or sort change resets the page to 1. `toQueryParameters()` emits only the keys in use, plus
  `page`, `per_page` and `sort`.
- **Strict DTO.**
  - Exact keys on every map. Ids are canonical UUIDs.
  - `attempt_number` ≥ 1.
  - `review` counts are ≥ 0.
  - `possible_points` ≥ 0.
  - `earned_points` and `normalized_score` are non-null if and only if the status is `checked`; the
    normalized score is in 0–100, and earned ≤ possible.
  - `review_due_at` is null for Blitz.
  - `review_overdue` implies the status is `waiting_for_teacher_review` and `review_due_at` is not null.
  - `official` implies `official_score_eligible`.
  - Unknown enum values are rejected.

  The list envelope uses `TeacherListEnvelopeDto` with the requested page and per-page.
- **Data source.** `TeacherSubmissionRemoteDataSource.fetchSubmissions(query)` sends `GET
  /teacher/submissions` with the query parameters, no body and `followRedirects: false`, and expects
  `200`.
- **Repository.** `TeacherSubmissionRepository` (interface) and `TeacherSubmissionRepositoryImpl`,
  each with a Riverpod provider.

### 4.3 Controller

`teacherReviewQueueControllerProvider`, a `NotifierProvider.autoDispose`, holds
`TeacherReviewQueueState`:
- `status`: `initial`, `loading`, `data`, `refreshing` or `error`;
- `query`, `result`, `failure`, `isStale`;
- `canGoPrevious` and `canGoNext`.

It is active only for an eligible desktop Teacher session, and loads on build. Methods:
- `setCheckingStatus`, `setType`, `setOfficial`, `setOverdueOnly`, `setSort`, `setDirection`;
- `clearFilters`, which returns to the initial query;
- `previousPage`, `nextPage`, `refresh`, `retry`.

Behavior mirrors `TeacherHomeworkListController`:
- a changed query starts a new load and drops older completions;
- `refresh` keeps the result and marks it stale on failure;
- session errors clear the controller;
- a change of session reloads.

### 4.4 Screen

`TeacherReviewQueueScreen`, key `teacherReviewQueueScreen`, has the AppBar title `Review queue`, a back
button to `/teacher` (key `teacherReviewQueueBackButton`), and a refresh button (key
`teacherReviewQueueRefreshButton`) that retries after an error.

**Filter bar.** Each control has a key:

| Control | Key | Options |
|---|---|---|
| Status dropdown | `teacherReviewQueueStatusFilter` | `Waiting for review` (default), `Automatic checking pending`, `Checked`, `All statuses` |
| Task dropdown | `teacherReviewQueueTypeFilter` | `All tasks`, `Homework`, `Blitz` |
| Official dropdown | `teacherReviewQueueOfficialFilter` | `Official and practice`, `Official only`, `Practice only` |
| `Overdue only` FilterChip | `teacherReviewQueueOverdueFilter` | on or off |
| Sort dropdown | `teacherReviewQueueSortFilter` | `Recommended order` (`default`), `Finalized time`, `Student name`, `Review deadline` |
| Direction toggle | `teacherReviewQueueDirectionButton` | `Ascending` or `Descending`; disabled for `Recommended order` |
| `Clear filters` | `teacherReviewQueueClearFiltersButton` | enabled when the query differs from the initial one |

**Rows.** Each row is a `Card` with key `teacherReviewQueueRow:<id>`. It is not interactive in this task.
- **Line 1.** The Student's full name, then chips:
  - `Official` or `Practice`;
  - `Invalidated attempt` when `official_score_eligible` is false;
  - `Overdue` when `review_overdue` is true.
- **Line 2.** `<Homework|Blitz> · <task title> · <Topic title> · <Group name>`.
- **Line 3.** `Attempt <n> · <status label> · Finalized <time>`.
  - Status labels: `Waiting for review`; `Checked`; `Automatic checking pending` for `submitted` and
    `timed_out_finalized`.
  - The time is shown in the session's Institution timezone in the `formatInstitutionWallClock` format,
    or in UTC (`formatUtcInstant` with the suffix ` UTC`) when that timezone is unavailable.
- **Line 4.** Shown only when it has content, with the parts joined by ` · `:
  - `Reviewed <reviewed> of <total> answers`, when the total (`reviewed + waiting`) is above 0; the
    word is `answer` when the total is 1;
  - `Review by <time>`, when `review_due_at` is set, formatted as on line 3;
  - `Score <normalized>`, when the status is `checked`. The score is shown with one decimal place,
    using standard half-up rounding (`S09-DOC-001` §6, `S09-T3`). The shared
    `formatScoreOneDecimal` in `lib/core/scoring/score_display.dart` rounds the score's 8-place
    decimal string, so binary errors such as `1.45` → `1.4` cannot occur. `S09-FE-004` reuses it.

**Paging and states.**
- Below the list: the text `<total> submissions` (`1 submission` when there is one), the text
  `Page <page> of <last_page>`, and `Previous` / `Next` buttons with keys
  `teacherReviewQueuePreviousButton` and `teacherReviewQueueNextButton`. Paging stays visible on an empty
  page after the first one. This can happen when a later page empties because its items leave the filter.
- **Loading.** A progress indicator with key `teacherReviewQueueLoading`.
- **Refreshing.** A `LinearProgressIndicator` above the retained list.
- **Error without a result.** The message `The review queue could not be loaded.` and a `Retry` button
  with key `teacherReviewQueueRetryButton`. Raw failure text is never shown.
- **Stale.** A `MaterialBanner` with key `teacherReviewQueueStaleMessage`, the text
  `The displayed review queue may be out of date.`, and `Retry`.
- **Empty.** With the initial query: `No submissions are waiting for review.` Otherwise: `No submissions
  match these filters.`

### Non-goals

- No submission detail, navigation from a row, review or download (`S09-FE-003`).
- No task review counts and no task-scoped queue (`S09-FE-002B`).
- No mobile queue; no backend change; no Student or Parent change.

## 5. Tests

- **Query.** Default parameters; each filter's parameter; direction is sent only for a non-default sort;
  every change resets the page; invalid page or per-page values are rejected.
- **DTO.**
  - A full valid item for each status and type.
  - Unknown or missing keys at every level.
  - Each contradiction in §4.2 is rejected: score versus status, Blitz with `review_due_at`, overdue
    rules, official without eligibility, out-of-range values, unknown enums, and a non-canonical id.
- **Data source.** Path, parameters, no body; `200` parsing; a non-`200` status or a bad envelope is a
  format failure, mapped like the other Teacher list reads.
- **Controller.**
  - The initial load.
  - Each setter reloads from page 1.
  - Paging.
  - A refresh keeps the result, and becomes stale on failure.
  - An error without a result; retry.
  - Session-error clearing.
  - A stale completion after a query change is dropped.
  - Inactive on mobile.
- **Router.**
  - Desktop `/teacher/reviews` shows the screen.
  - Mobile is redirected to `/teacher`.
  - A query string is redirected to `/teacher`.
  - The path predicate is exact.
- **Widgets.**
  - The workspace button appears on desktop only and navigates.
  - Row lines and chips for an official checked Homework item and an invalidated Blitz item.
  - Each filter control sends its query.
  - The direction toggle is disabled for `Recommended order`.
  - Clear filters.
  - Paging buttons and texts.
  - Loading, error with retry, stale banner, and both empty texts.
  - No raw failure text.

Review corrections (independent review: P2 = 1, P3 = 4):
- the score uses one decimal, half-up;
- an emptied later page keeps paging;
- the singular `answer`;
- tests were added for both halves of the score rule, negative values, every filter option, the singular
  submission count, the UTC fallback, the refresh button retrying, and the desktop bootstrap.

## 6. Verification

```text
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze
flutter test test/features/teacher test/app test/core
git diff --check
```

## 7. Acceptance Criteria

- [ ] §4 is implemented exactly; each new test is seen failing first.
- [ ] `flutter analyze` is clean; `flutter test test/features/teacher test/app test/core` passes.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.
