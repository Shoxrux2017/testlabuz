# Implementation Contract: S10-FE-002 — Teacher Topic Results (Read)

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S10-FE-002` |
| Stage | `Stage 10 — Final Result and Understanding Assessment` |
| Area | `Frontend` (Teacher) |
| Status | `Approved` |
| Depends on | `S10-FE-001` on `main` `e979a46` |
| Owner decisions applied | `S10-FE-D1` = B (Teacher results on desktop and mobile), `S10-D2`, `S10-D6`, `S10-D9` |
| Implementation | Claude |
| Delivery | Claude opens the PR and merges it after review `PASS` and green verification |
| Blocks | `S10-FE-003` |

Normative sources: `docs/09` §§25.3-25.6, 2.13; `docs/04:1127-1151`, `3876-3901`; frontend plan (index §7 row `7`).

## 2. Goal

The Teacher sees the Topic results on desktop and mobile: an entry card with the status counts on the Topic
detail page, a results list with status and category filters and pages, and one Student's result detail. This
task only reads; the actions come in `S10-FE-003`.

## 3. Scope

Included: §5.1-§5.7. Non-goals: release, comment and close (`S10-FE-003`); activation/archive warnings, the
review `result_closed` message, review-queue filters and related-view refresh (`S10-FE-004`); a link from a
result to its Attempts; any Parent screen; any backend change; docs (aligned in `S10-FE-003`).

## 4. Current Context

- Teacher feature layout `lib/features/teacher/{application,data,data/dto,domain,presentation}`; DTO helpers
  `teacher_dto_parse.dart`; `TeacherListPaginationDto`; `formatScoreOneDecimal`; `formatInstitutionInstant`.
- Templates: `TeacherReviewQueueController` (paged, filtered list), `TeacherTopicResultPairController` and
  `TeacherTopicDetailController` (single read), session ownership via `TeacherSessionSnapshot`.
- Routing: `AppRoutePaths` (names, paths, predicates, location helpers, `isTeacherApprovedLocation`,
  `teacherTopicIdFromPath`), `app_router.dart` (Teacher tree, mobile `_authRedirect`, bootstrap keep list). A
  query string or fragment on a Teacher location redirects to `/teacher`, so filters live in the controller.
- Five test harnesses render the Teacher Topic detail page and override each repository it reads.

## 5. Exact Contract

### 5.1 Routes

| Name | Path | Surfaces |
|---|---|---|
| `teacher-topic-results` | `/teacher/topics/:topicId/results` | desktop, mobile |
| `teacher-topic-result-detail` | `/teacher/topics/:topicId/results/:studentId` | desktop, mobile |

Canonical UUIDs only (any case); location helpers throw `ArgumentError` otherwise. Both paths are approved
Teacher locations, allowed on mobile, kept during bootstrap on both surfaces, and give their Topic id to
`teacherTopicIdFromPath`. A non-Teacher never reaches them. Back goes to the parent route (pop, or `go` on an
empty stack).

### 5.2 Data

- `GET /teacher/topics/{topic}/results?page&per_page=25[&result_status][&category]` and
  `GET /teacher/topics/{topic}/results/{student}` through a new `TeacherTopicResultRepository`
  (`fetchResults(topicId, query)`, `fetchResult(topicId, studentId)`); exact `200`, no redirects, ArgumentError
  for a non-canonical id; the repository rejects a detail whose Student is not the requested one.
- List envelope exactly `{data, meta: {pagination, counts}}`; pagination as every Teacher list; `counts`
  exactly the seven statuses, non-negative integers; no duplicate Students; with no filter `total` equals the
  sum of the counts, with only a status filter it equals that count, with any filter it is at most the sum;
  every row matches the active filters.
- Item: exactly the docs/09 §25.4 keys; detail: the item keys plus the six §25.6 keys. Otherwise
  `FormatException` (`invalidResponse`):

| Field | Rule |
|---|---|
| `student` | exactly `{id, full_name}`, canonical UUID, non-blank name |
| `result_status` | one of the seven |
| `closed_outcome`, `closed_at` | non-null exactly when `closed` |
| `missing_component` | non-null exactly for Not completed (open, or closed `not_completed`) and equal to the sides whose state is `missing` |
| `homework` side | canonical `assessment_id`; state one of six (never `not_designated`) |
| `blitz` side | `assessment_id` null exactly when `not_designated`; state one of seven |
| side Attempt | `official_attempt_id`, `attempt_number` and `score` non-null exactly when `ready`; the number is 1-3 for Homework (three Attempts) and 1-2 for Blitz (the normal Attempt and one exception replacement) |
| calculated (open or closed) | both sides `ready`; D, T, consistency, method, final and `category_score` non-null; `consistent` with `average`, `inconsistent` with `blitz`; numeric category |
| otherwise | D, T, consistency, method, final and `category_score` null; category `not_completed` for Not completed, else null |
| scores, D, T | finite numbers 0-100; `category_score` integer 0-100 |
| `category` | null or exactly `{code, label}`, one of the five codes, non-blank label |
| `teacher_comment` | null or non-blank |
| `visibility` | exactly the eight keys; modes null or known; `*_visible`, `can_release_*` booleans; release times null or UTC; visible only for `calculated`, `not_completed`, `closed` |
| `can_close` | boolean; true only for open `calculated` or `not_completed` |
| detail actors | null or exactly `{id, full_name}` |
| `closure_reason` | `teacher`/`topic_archived` exactly when `closed`; `closed_by` null for an open result |

### 5.3 Controllers

- `teacherTopicResultListControllerProvider` (autoDispose family on the lowercase Topic id): query (status,
  category, page; page resets to 1 on a filter change), `setStatus`, `setCategory`, `clearFilters`,
  `previousPage`, `nextPage`, `refresh`, `retry`; the last confirmed `counts` survive later loads (and a failed
  one) until the session changes; stale result kept after a failed refresh. Shared by the entry card and the
  list screen.
- `teacherTopicResultDetailControllerProvider` (autoDispose family on the lowercase Topic and Student ids):
  load, `refresh`, stale result kept after a failed refresh.
- Both use the Teacher session ownership pattern: no publish after a session change or dispose; session
  failures clear the state and bootstrap (except `authentication_required`); other errors keep the failure.

### 5.4 Entry card on the Teacher Topic detail page

Right after the header card, desktop and mobile: "Topic results"; progress while counts are unknown; "Topic
results could not be loaded." with Retry ("These Topic results are not available." without Retry for `404`);
a zero total: "No results yet. Results appear once the official Homework is activated."; otherwise
"Students: N", one line per non-zero status ("Calculated: 21") and an "Open results" button. Counts kept
after a failed load show "These counts may be out of date." with Retry.

### 5.5 Results list screen

AppBar "Topic results" with Back and Refresh. Status filter (All statuses and the seven, each with its count),
category filter (All categories and the five), Clear filters. Rows: Student name, status label, missing
component, "Homework 88.0 · Blitz 84.0 · Final 86.0" (present values only), category (server label), Student
and Parent visibility; a row opens the detail. Empty: "No results match these filters." with filters, else the
§5.4 empty text. Count "N Students", "Page X of Y", Previous/Next. Stale banner and Retry like the review queue.

### 5.6 Result detail screen

AppBar "Topic result" with Back and Refresh. Sections: Student and status (missing component; for a closed
result "Closed at", "Closed by", reason); Homework and Blitz (state, Attempt number, score); "Final result"
when there is a category (final score, category; for a calculated result also the method, score difference,
allowed difference and the consistency line); Teacher's comment (read-only, last change time and author) or
"No comment yet."; Visibility (Student and Parent: release mode, visible now, released time and by whom).

### 5.7 Teacher wording

| Value | Label |
|---|---|
| statuses | Waiting for Homework · Waiting for Blitz · Waiting for review · Waiting for result settings · Calculated · Not completed · Closed (row: "Closed · Calculated" / "Closed · Not completed") |
| `waiting_for_settings` detail | "The Institution Admin has not set the allowed difference or the categories yet." |
| side states | Ready · Waiting for review · Checking · Not activated · Open · Missing · No official Blitz |
| consistent | "The scores are within the allowed difference, so the final score is their average." |
| inconsistent | "The scores differ by more than the allowed difference, so the Blitz score is used." |
| Student release mode | Automatic · Manual by the Teacher · Not configured |
| Parent release mode | With the Student · Manual by the Teacher · Hidden from Parents · Not configured |
| closure reason | Closed by the Teacher · Closed when the Topic was archived |

Scores, D and T use one decimal (`formatScoreOneDecimal`); times use the Institution timezone. The raw words
"inconsistent", "consistency" and `category_score` are never shown.

### 5.8 Tests

DTO (each rule above), data source (paths, query, envelope, status, guards, failure mapping), repository
Student check, both controllers (load, filters and page reset, paging, counts kept, refresh, stale, session
change, session failure, error), route helpers and redirects (both surfaces, bootstrap, non-Teacher, malformed
paths), entry card states and placement, list (filters with counts, rows, empty texts, pages, opening a row),
detail (each status family, consistency wording, closure, visibility, comment), narrow 360 px with text scaling;
the existing Topic detail harnesses get the new fake repository.

## 6. Verification

```text
flutter test test/features/teacher test/router_bootstrap_test.dart; flutter analyze --no-pub lib test;
dart format --output=none --set-exit-if-changed lib test; git diff --check
```
