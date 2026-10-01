# Implementation Contract: S09-FE-001B — Homework Review Deadline

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-FE-001B` (second part of the planned `S09-FE-001`) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Frontend` (Teacher Homework detail) |
| Status | `Approved` |
| Depends on | `S09-FE-001A` — delivered (PR #302, `main` `5aaf9a5`) |
| Implementation baseline | `origin/main` `5aaf9a5` |
| Decisions applied | `S09-D2`: the review deadline ("проверить до") is optional and only a reminder that never changes scores; `S09-D7`: Teacher review work is desktop-only |
| Backend contract | `S09-DOC-001` §11, delivered by `S09-BE-002` |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |

This file is the complete task contract.

## 2. Goal

The Teacher sees a Homework's review deadline, and on desktop sets, changes or clears it from the Homework
detail. This works in any state except archived, including after the Homework is closed, when review
usually happens.

## 3. Current Implementation Context

- `TeacherHomework.reviewDueAt` (`DateTime?`, UTC) is already parsed from `review_due_at` (`S09-BE-002`).
  Nothing displays or edits it.
- Backend: `PUT /api/v1/teacher/homework/{homework}/review-due-at`.
  - Request body: strict JSON with exactly `{"review_due_at": "<RFC 3339 with offset>" | null}`. No
    query parameters, no `Idempotency-Key`. The value is absolute, so repeating the request is safe.
  - Response: `200` with message `Homework review deadline updated successfully.` and the Teacher Homework
    resource.
  - Errors: `404 resource_not_found`, `409 task_archived`, `409 topic_not_editable`,
    `422 validation_failed`, and the standard session and rate-limit errors.
  - Past values are allowed, and there is no ordering rule against `deadline_at`.
- Pattern to mirror: `TeacherOfficialHomeworkController` and `TeacherOfficialHomeworkSection`. They
  show how a Homework-detail mutation works:
  - it is desktop-only;
  - it holds a route mutation lease;
  - it uses generation and session guards;
  - it reconciles an unknown outcome with a GET;
  - a blocking outcome review offers "check current".

  The detail screen binds the controller, lets it leave the route and shows its success SnackBar.
- Wall-clock handling is the same as the Homework deadline:
  - `InstitutionWallClock`;
  - `InstitutionTimezone.serializeWallClock`, which throws `InstitutionTimezoneException` for a local time
    that does not exist;
  - the date and time pickers in `TeacherHomeworkCreateScreen._chooseDeadline`.

## 4. Scope

### 4.1 Display (desktop and mobile)

The Homework detail `Summary` card adds the row `Review deadline` right after `Deadline`. Its value is:
- `formatTeacherHomeworkReviewDeadline(reviewDueAt, institutionTimezone)`;
- or `Not set` when the value is null;
- or `Institution timezone unavailable`, as the deadline formatter does.

### 4.2 Editing section (desktop only)

`TeacherHomeworkReviewDeadlineSection` (key `teacherHomeworkReviewDeadlineSection`) is a card placed
after the `Summary` card. It is shown only on desktop, when the detail shows a Homework that is not stale
and not archived. While the detail refreshes, the section stays visible and its action buttons are
disabled, so a manual refresh does not make it flicker. It contains:
- the heading `Review deadline`;
- the current value, formatted as in §4.1, or `No review deadline.` when there is none;
- the helper line `A reminder for checking submissions. It never changes scores.`;
- `FilledButton.icon`, key `teacherHomeworkReviewDeadlineSetButton`. Its label is `Set review deadline`
  when none is set and `Change review deadline` otherwise;
- `TextButton.icon`, key `teacherHomeworkReviewDeadlineClearButton`, label `Clear`, shown only when a
  deadline is set;
- while the controller is busy: a `LinearProgressIndicator` with key
  `teacherHomeworkReviewDeadlineProgress`;
- after a local picker error, a failure or an unconfirmed outcome: the feedback text with key
  `teacherHomeworkReviewDeadlineFeedback`. A new local picker error takes precedence over an earlier
  server outcome;
- when a current check is required: `OutlinedButton.icon`, key
  `teacherHomeworkReviewDeadlineCheckCurrentButton`, label `Check current Homework`.

Both action buttons are disabled while the route mutation activity is active or the detail refreshes.

**Set.** The date picker opens, then the time picker. The initial value is the current review deadline,
or the current Institution-local time.
- Cancelling either picker sends nothing.
- If the chosen local time does not exist in the Institution timezone, or the timezone is unavailable, the
  section shows the feedback message below and sends nothing:
  - `This local time does not exist in the Institution timezone.`
  - `The Institution timezone is unavailable.`
- Before submitting, the section checks that it is still the current route target and the same eligible
  desktop session, as the official section does.

**Clear** submits `null` directly. There is no confirmation, because this is only a reminder.

### 4.3 Domain, data and repository

- `TeacherHomeworkReviewDueAtRequest` in `teacher_homework_mutation.dart`:
  - `fromWallClock(InstitutionWallClock? wallClock, String institutionTimezone)`. It serializes like
    the deadline and lets `InstitutionTimezoneException` propagate.
  - Fields: `reviewDueAtSerialized` (`String?`) and `reviewDueAtUtc` (`DateTime?`).
  - `toJson()` returns `{'review_due_at': reviewDueAtSerialized}`.
  - `bool matches(TeacherHomework current)` compares instants; null matches only null.
- `TeacherHomeworkRemoteDataSource.setReviewDueAt(homeworkId, request)`:
  - requires a canonical id;
  - sends `PUT /teacher/homework/{id}/review-due-at`, expects `200` and the exact success message;
  - the conflict set is `{task_archived, topic_not_editable}`;
  - everything else follows the shared mutation transport rules.
- `TeacherHomeworkRepository.setReviewDueAt(homeworkId, request)` returns the domain Homework. A returned
  id that differs is an unknown outcome, as `updateHomework` treats it. Every test fake that implements
  the repository gets the method.

### 4.4 Controller

`teacherHomeworkReviewDeadlineControllerProvider`, a `NotifierProvider.autoDispose.family` keyed by
`TeacherHomeworkRouteTarget`, holds `TeacherHomeworkReviewDeadlineState`:
- `status`: `idle`, `submitting`, `reconciling`, `definiteFailure`, `outcomeReview` or `confirmedSuccess`;
- `feedback`;
- `conflictCode`: the server code of a definite failure;
- `requiresCurrentCheck`;
- getters `isBusy` and `canCheckCurrent`.

It uses the new route mutation operation `TeacherHomeworkRouteMutationOperation.reviewDeadline`.

**Guards.** `submit(request)` does nothing unless:
- the session is an eligible desktop session;
- the detail holds confirmed current data for the target;
- the Homework is not archived;
- the controller is not busy and needs no current check;
- the lease is acquired.

**Success.** The returned Homework matches the target and `request.matches(returned)`.
1. Accept it into the detail controller (`acceptAuthoritativeHomework`).
2. Release the lease.
3. Move to `confirmedSuccess` with feedback `Review deadline saved.`, or `Review deadline cleared.` when the
   request was null.

The screen shows the feedback in a SnackBar and consumes it.

**Unknown outcome.** This covers: the transport reports an unknown outcome, the returned Homework does not
match, or an unexpected error occurs. The controller reconciles with a GET.
- If the GET matches the target and `request.matches`, it publishes success.
- If the GET returns another value, it moves to `outcomeReview`, not blocking, with this feedback:
  - `The review deadline change could not be confirmed.`
  - `Review the current Homework before trying again.`
- If the GET fails, it marks the lease as blocking outcome review and shows the same feedback with
  `requiresCurrentCheck`. `checkCurrentHomework()` repeats the reconcile.

**Definite failures.**

| Failure | Handling |
|---|---|
| Session errors | Clear the session, as the official controller does |
| `404 resource_not_found` | Mark the detail not found and refresh the list |
| `409` | Refresh the Homework, accepting it when it matches, then move to `definiteFailure` |
| `task_archived` | `This Homework is archived. Its review deadline can no longer be changed.` |
| `topic_not_editable` | `The Topic is closed or archived. The review deadline can no longer be changed.` |
| `validation_failed` | `The review deadline could not be validated.\nRefresh and try again.` |
| `forbidden` | `You do not have permission to change this review deadline.` |
| `rate_limited` | `Too many requests. Wait before trying again.` |
| Anything else | `The review deadline could not be updated.` |

**`task_archived`.** The refreshed Homework is archived, so the section disappears. The detail screen
announces this message in a SnackBar instead.

**Route lifecycle.** `invalidateRouteCompletions()`, `leaveRoute()` and `consumeFeedback()` behave like the
official controller's. `TeacherHomeworkDetailScreen` binds, invalidates and leaves this controller wherever
it does so for the official controller.

### Non-goals

- No change to the Homework create and edit forms. The dedicated endpoint is the single editing path for
  every state.
- No review queue and no overdue display (`S09-FE-002`).
- No Student, Parent or backend change. No change to Blitz, which has no review deadline.

## 5. Tests

- **Domain.**
  - The request serializes the Institution wall clock with its offset, or null.
  - `matches` compares instants, and null with null.
  - A local time that does not exist throws.
- **Data source.**
  - PUT path, body and exact success-message parsing.
  - `409 task_archived` and `topic_not_editable` are definite.
  - Other `409` codes, a wrong message or status, and transport ambiguity are unknown outcomes.
  - A non-canonical id is rejected before any request.
- **Repository.** A returned id that differs is an unknown outcome.
- **Controller.**
  - Set and clear succeed and update the detail.
  - Guards: mobile, archived, stale detail, busy, and a lease held by another operation.
  - An unknown outcome reconciled to success.
  - A GET with another value gives `outcomeReview`; a failed GET gives a blocking review, and "check current"
    then succeeds.
  - Each mapped `409` refreshes the Homework and shows its message.
  - `404` gives not found; session errors clear the session.
  - A completion after `leaveRoute` publishes nothing.
- **Widgets (detail screen).**
  - The `Review deadline` row shows the value or `Not set`, on mobile and desktop.
  - The section is shown only on desktop for draft, active and closed; it is hidden for archived, on mobile
    and while stale.
  - Set via both pickers sends the serialized value and shows the success SnackBar.
  - Cancelling a picker sends nothing.
  - Clear sends null.
  - The buttons are disabled while another Homework mutation holds the lease, with this section idle.
  - The section is hidden while the detail is stale.
  - A local time that does not exist is explained, sends nothing, and replaces an earlier server failure.
  - The `task_archived` message is announced after the section closes.
  - Failure feedback and "Check current Homework" are shown.
- **Controller, `404`.** Also refreshes the Homework list.

Review corrections (independent review: P2 = 1, P3 = 4):
- the lease test holds another operation's lease;
- a local error is shown first;
- `task_archived` is announced;
- stale and list-refresh tests were added.

## 6. Verification

```text
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze
flutter test test/features/teacher
git diff --check
```

## 7. Acceptance Criteria

- [ ] §4 is implemented exactly; each new test is seen failing first.
- [ ] `flutter analyze` is clean; `flutter test test/features/teacher` passes.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.
