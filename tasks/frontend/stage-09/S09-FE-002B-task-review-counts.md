# Implementation Contract: S09-FE-002B — Task Review Counts and Task-Scoped Queue

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-FE-002B` (second part of the planned `S09-FE-002`) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Frontend` (Teacher) |
| Status | `Approved` |
| Depends on | `S09-FE-002A` — delivered (PR #304, `main` `f3cbefa`) |
| Implementation baseline | `origin/main` `f3cbefa` |
| Decisions applied | `S09-D7`: review is desktop-only; mobile shows only the read-only counts `waiting for review` and `overdue` |
| Backend contract | `S09-DOC-001` §10.2 (`assessment_id` and `topic_id` filters), §10.4 (`review_summary`) |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |

This file is the complete task contract.

## 2. Goal

- **All surfaces.** The Teacher sees, on each Homework and Blitz detail, how many submissions wait for
  review and, for Homework, how many of those are overdue.
- **Desktop only.** The Teacher opens a queue limited to that task.

## 3. Current Implementation Context

- **Counts.** `TeacherHomework.reviewSummary` and `TeacherBlitz.reviewSummary` (`TeacherReviewSummary {
  waitingForTeacherReview, overdue }`) are parsed but not shown. The Blitz `overdue` is always 0.
- **Queue.** `S09-FE-002A` delivered `teacherReviewQueueControllerProvider` (not a family),
  `TeacherSubmissionListQuery`, `TeacherReviewQueueScreen` and the route `/teacher/reviews`. Teacher
  routes reject query strings, so a task scope needs its own path.
- **Detail screens.**
  - `TeacherHomeworkDetailScreen`: its navigation buttons are disabled while
    `teacherHomeworkRouteMutationActivityProvider` is active.
  - `TeacherBlitzDetailScreen`: likewise with `teacherBlitzRouteMutationActivityProvider`. Its monitor
    navigation shows the pattern: `monitorEnabled: !activity.isActive`.
- **Mobile mapping.** Mobile maps Homework edit and questions paths, and Blitz edit and questions paths,
  to the task detail. This happens both during bootstrap and after authentication, through
  `teacherTopicIdFromPath`, `teacherHomeworkIdFromPath` and `teacherBlitzIdFromPath`.

## 4. Scope

### 4.1 Counts card (all surfaces)

A new `TeacherTaskReviewSummaryCard`, key `teacherTaskReviewSummary`, has these parameters:
- `summary`;
- `showsOverdue`;
- a nullable `onOpenQueue`.

It is a `Card` containing:
- a semantic header `Review`;
- the text `Waiting for review: <n>`, key `teacherTaskReviewWaitingCount`;
- when `showsOverdue`, the text `Overdue: <m>`, key `teacherTaskReviewOverdueCount`;
- when `onOpenQueue` is not null, an `OutlinedButton.icon` with key `teacherTaskReviewQueueButton`,
  label `Open review queue` and icon `Icons.fact_check_outlined`. It is secondary navigation, like the
  Blitz `Monitor` button: an Active Blitz detail keeps no filled button (a Stage 8 test).

Placement:
- **Homework detail.** Right after the `Summary` card. `showsOverdue` is true.
- **Blitz detail.** Right before the `Blitz information` card. `showsOverdue` is false.

On desktop, `onOpenQueue` navigates to the task-scoped queue (§4.2). It is null while that task's route
mutation activity is active, so the button is not shown, and it is always null on mobile. The counts are
read from the detail data shown; there is no extra request.

### 4.2 Task-scoped queue routes (desktop only)

**Paths.**

| Task | Path | Name | Predicate | Location helper |
|---|---|---|---|---|
| Homework | `/teacher/topics/{topicId}/homework/{homeworkId}/reviews` | `teacher-homework-reviews` | `isTeacherHomeworkReviewsPath` | `teacherHomeworkReviewsLocation(topicId, homeworkId)` |
| Blitz | `/teacher/topics/{topicId}/blitz/{blitzId}/reviews` | `teacher-blitz-reviews` | `isTeacherBlitzReviewsPath` | `teacherBlitzReviewsLocation(topicId, blitzId)` |

The segment `reviews` is `AppRoutePaths.teacherReviewsSegment`, already defined.
- `teacherTopicIdFromPath`, `teacherHomeworkIdFromPath` and `teacherBlitzIdFromPath` accept these paths.
- Both are approved desktop locations, kept during desktop bootstrap, behind
  `_buildTeacherDestination(..., authoring: true)`.
- On mobile, during bootstrap and after authentication, each one redirects to its task detail, as the
  edit paths do.
- A query string or fragment redirects to `/teacher`, as on every Teacher path.

### 4.3 Queue scope

**Scope type.** `TeacherReviewQueueScope` is an immutable value with equality.
- `TeacherReviewQueueScope.all` is the global queue.
- `TeacherReviewQueueScope.task({topicId, assessmentId, type})` scopes the queue to one task. Its ids are
  canonical UUIDs; anything else throws `ArgumentError`.

**Provider and query.**
- `teacherReviewQueueControllerProvider` becomes a family keyed by the scope; `/teacher/reviews` uses
  `all`.
- `TeacherSubmissionListQuery.initial({String? topicId, String? assessmentId})` carries the task ids.
  `toQueryParameters()` sends `topic_id` and `assessment_id` when they are set.
- Every filter, sort, paging change and `clearFilters` keeps the scope ids; `clearFilters` returns to the
  scope's initial query.

**Screen.** `TeacherReviewQueueScreen({TeacherReviewQueueScope scope = .all})`. In a task scope:
- a line under the filters, key `teacherReviewQueueScopeLabel`: `Submissions of this Homework` or
  `Submissions of this Blitz`;
- the task filter is hidden; the type is not sent, since the task fixes it;
- the back button returns to the task detail;
- the empty text for the initial query is `No submissions of this task are waiting for review.`

Everything else is unchanged from `S09-FE-002A`.

### Non-goals

- No submission detail or row navigation (`S09-FE-003`). No backend change.
- No count refresh beyond the detail screen's own reads.

## 5. Tests

- **Card.**
  - Counts on desktop and mobile for Homework (waiting and overdue) and Blitz (waiting only).
  - The button appears on desktop only, and is hidden while the task's route lease is held.
  - The Homework and Blitz buttons open the scoped queue, which sends `topic_id`, `assessment_id` and the
    default status.
- **Router.**
  - The Homework and Blitz review paths: exact predicates and helpers; the id extractors; approved
    locations.
  - A desktop direct entry shows the scoped queue, and a desktop deep link survives bootstrap.
  - Mobile is redirected to the task detail, both after authentication and during bootstrap.
  - A query string or fragment is redirected to `/teacher`.
  - Malformed ids are rejected.
- **Scope and query.**
  - The scoped initial query parameters.
  - Changes keep the scope.
  - `clearFilters` returns to the scoped initial query.
  - An invalid scope id throws.
  - The global scope is unchanged.
- **Screen.**
  - The scoped label and the hidden task filter.
  - Back goes to the task detail.
  - The scoped empty text.
  - The `S09-FE-002A` tests pass with the global scope.

Review corrections (independent review: P2 = 2, P3 = 5):
- the button is outlined, so the Stage 8 "no filled button on an Active Blitz" test holds unchanged;
- the mobile test asserts the count values, Homework overdue and no Blitz overdue;
- tests were added for the fragment redirect, a malformed direct entry, Blitz back navigation, the
  lease check's precondition, and route-name resolution.

## 6. Verification

```text
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze
flutter test   (whole frontend suite: the router changes)
git diff --check
```

## 7. Acceptance Criteria

- [ ] §4 is implemented exactly; each new test is seen failing first.
- [ ] `flutter analyze` is clean; the whole `flutter test` suite passes.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.
