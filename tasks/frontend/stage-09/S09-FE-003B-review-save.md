# Implementation Contract: S09-FE-003B — Teacher Review Save and Correction (Desktop)

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-FE-003B` (second part of the planned `S09-FE-003`) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Frontend` (Teacher) |
| Status | `Approved` |
| Depends on | `S09-FE-003A` — delivered (PR #306, `main` `8d401ca`) |
| Implementation baseline | `origin/main` `8d401ca` |
| Decisions applied | `S09-D7` (review is desktop-only), `S09-D6` (practice work is reviewed the same way) |
| Backend contract | `S09-DOC-001` §10.5 and §10.6, delivered by `S09-BE-006` |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |

`S09-FE-003C` (the official-score panel) follows. This file is the complete task contract.

## 2. Goal

On the desktop submission detail, the Teacher:
- enters points and optional feedback for answers waiting for review;
- corrects answers that were already reviewed;
- saves all changed answers together.

When the Teacher goes back, the review queues and the task's review counts already show the new state.

## 3. Backend Contract (read from the code)

### 3.1 Request

`PUT /api/v1/teacher/submissions/{submission}/review` takes no query parameters and no `Idempotency-Key`.

Body, as strict JSON:

```json
{ "answers": [ { "answer_id": "uuid", "awarded_points": 2.5, "feedback": "Good start." } ] }
```

- `answers` is a non-empty array, and its `answer_id` values are unique.
- `awarded_points` is a JSON number.
- `feedback` is a string or null.
  - The server trims it with PHP `trim`, which removes only space, `\t`, `\n`, `\r`, `\0` and `\x0B`.
  - Empty becomes null.
  - After trimming, it has at most 2000 characters, counted as Unicode code points.

The values are absolute. Sending the same body again gives the same stored answers.

### 3.2 Evaluation order

1. **Shape:** `422 validation_failed`.
2. **Access:** `404 resource_not_found`.
3. **State:** a `submitted` or `timed_out_finalized` submission gives `409 automatic_checking_pending`.
4. **Items:** `422 validation_failed`, with every item error reported together.
   - `answers.N.answer_id`: the answer is not a manual-review answer of this submission. A manual-review answer is `waiting_for_teacher_review` or `teacher_checked`.
   - `answers.N.awarded_points`: the value is negative, has more than 6 fractional digits, or exceeds the Question points.

The save is atomic: after any error, nothing is saved.

### 3.3 Success

`200` returns `{"data": <the detail, as in GET>, "message": "Submission review saved successfully."}`. The envelope has exactly these two keys.

What the save changes:
- Each sent answer becomes `teacher_checked`, with the sent points and feedback, `checked_by` set to the Teacher and `checked_at` set to now.
- The submission becomes `checked` when no answer is still waiting, and otherwise stays `waiting_for_teacher_review`.
- The official score is resolved again.

**Correction** (§10.6) uses the same request on `teacher_checked` answers.

### 3.4 Other failures

- `401`/`403` with a session code;
- `403 forbidden`;
- `429 rate_limited`.

## 4. Scope

### 4.1 Domain

New file `domain/teacher_submission_review.dart`.

- **`TeacherAnswerReviewDraft`** has the fields `pointsText` and `feedbackText`, both `String?`. A null field is untouched, and the saved value is shown in its place.
- **`normalizeTeacherReviewFeedback(String text)`** returns `String?`.
  - It strips leading and trailing space, `\t`, `\n`, `\r`, `\0` and `\x0B`, which is the server's trim set.
  - Other whitespace, such as a no-break space, is kept, as on the server.
  - An empty result becomes null.
- **`TeacherAnswerReviewItem`** has the fields `answerId`, `awardedPoints` (`double`) and `feedback` (`String?`).
- **`TeacherSubmissionReviewRequest(items)`**:
  - It throws `ArgumentError` when `items` is empty or two ids are equal without regard to case.
  - `toJson()` returns exactly `{'answers': [{'answer_id', 'awarded_points', 'feedback'}]}`, in item order.
  - `matches(TeacherSubmissionDetail detail)` is true when, for every item, the detail has that answer as `teacher_checked`, with equal `awardedPoints` and equal `feedback`.
- **`TeacherSubmissionReviewOutcomeUnknownException`.**
- **`TeacherReviewPointsError`** is an enum: `missing` or `invalid`.
- **`TeacherAnswerReviewErrors`** has the fields `points` (`TeacherReviewPointsError?`), `feedbackTooLong` and `notReviewable`.
- **`buildTeacherSubmissionReview(detail, drafts)`** returns `TeacherSubmissionReviewBuild`, with `items` in Question position order and `errors` keyed by answer id.
  - It considers only answers that are `waiting_for_teacher_review` or `teacher_checked` and have a draft.
  - The saved points text is `formatTeacherQuestionPoints(awardedPoints)` for `teacher_checked`, and empty for waiting.
  - The saved feedback is `answer.feedback`.
  - Effective texts:
    - points: `draft.pointsText ?? saved points text`;
    - feedback: `draft.feedbackText ?? saved feedback ?? ''`.
  - The points are unchanged when both trimmed texts parse with `TeacherQuestionPoints.tryParse` to equal values, or when both trimmed texts are equal.
  - The feedback is unchanged when the normalized effective text equals the saved feedback.
  - An answer is **changed** when its points or its feedback changed.
  - Each changed answer is validated:
    - empty trimmed points give `missing`;
    - points that do not parse, or that exceed the Question points, give `invalid`;
    - a normalized feedback longer than 2000 code points gives `feedbackTooLong`.
  - Every valid changed answer becomes an item, with the parsed points and the normalized feedback. When there are errors, the caller sends nothing.

### 4.2 Data

- **`ApiErrorCodes.automaticCheckingPending`** is `automatic_checking_pending`.
- **`TeacherSubmissionRemoteDataSource.saveReview(submissionId, request)`**:
  - It throws `ArgumentError` for a non-canonical id.
  - It sends `PUT /teacher/submissions/{id}/review` with `request.toJson()` and `followRedirects: false`, through `sendTeacherMutation`.
  - It expects status `200`. Its conflict codes are `{automatic_checking_pending}`.
  - It parses the envelope with exactly the keys `data` and `message`. The message must equal `Submission review saved successfully.`, and `data` is parsed by `TeacherSubmissionDetailDto`.
  - Any other success body, or any unrecognized failure, throws `TeacherSubmissionReviewOutcomeUnknownException`.
- **`TeacherSubmissionRepository.saveReview(submissionId, request)`** returns the domain detail.

### 4.3 Controllers

**`teacherSubmissionReviewControllerProvider`** is an `autoDispose.family` keyed by the submission id. It is active for desktop Teacher sessions only. Its session handling is the detail controller's.

State:
- `status`: `idle`, `saving` or `reconciling`;
- `drafts`, keyed by answer id;
- `errors`, keyed by answer id;
- `failureMessage`, kept until the next edit, discard or save;
- `successFeedback`, consumed by the screen.

Actions:
- **`editPoints(answerId, text)` and `editFeedback(answerId, text)`.** They are ignored while busy. Each one sets its draft field, and clears that answer's errors and the failure message.
- **`discardChanges()`.** It is ignored while busy. It clears the drafts, the errors and the failure message.
- **`save()`.**
  - It is ignored while busy, without a session, or when the detail status is not `data`.
  - It builds the review from the current detail and the drafts.
  - With no changed answer, it does nothing.
  - With errors, it publishes them and sends nothing.
  - Otherwise it sets `saving` and sends the request.
- **`consumeFeedback()`.**

Outcomes:
- **Success.** The returned detail has the requested id and `request.matches(returned)` holds. Then the controller:
  - publishes the detail through `acceptAuthoritativeDetail`;
  - clears the drafts and errors;
  - sets the success feedback `Review saved.`;
  - refreshes the related views (§4.4).
- **Another id, or values that do not match:** reconcile.
- **Unknown outcome:** reconcile.
- **Reconcile.** The status is `reconciling`, and the controller sends one `GET` for the detail.
  - The detail matches: success, as above.
  - The detail does not match: it becomes the saved state, and the drafts are kept. The message is `The review could not be confirmed. Check the answers and save again.`
  - `404`, or a session failure, is handled as in the table below.
  - Any other failure keeps the drafts. The message is `The review could not be confirmed. Save again or refresh the submission.`
  - Saving again is safe because the values are absolute.

Definite failures. Nothing was saved, and the drafts are kept.

| Failure | Result |
|---|---|
| `404 resource_not_found` | The detail becomes `notFound` through `markNotFound`; the review state is cleared; the related views are refreshed |
| `409 automatic_checking_pending` | `This submission is still waiting for automatic checking. Try again later.` |
| `422` with `answers.N.<field>` keys | Errors on the answer of sent item N: `awarded_points` → `invalid`, `feedback` → `feedbackTooLong`, `answer_id` → `notReviewable`. The message is `Some answers were not saved. Check the marked fields.` |
| `422` without such keys | `The review could not be validated. Refresh and try again.` |
| `403 forbidden` | `You do not have permission to review this submission.` |
| `429 rate_limited` | `Too many requests. Wait before trying again.` |
| session failures | Cleared as in the detail controller: `bootstrap()` runs, except for `authentication_required` |
| any other definite failure | `The review could not be saved. Try again.` |

A completion is dropped when it comes from a previous session or a disposed controller, or when a later operation has started.

**`TeacherSubmissionDetailController`** gains two methods. Both act only for the current session.
- `acceptAuthoritativeDetail(detail, sessionKey)` drops any in-flight load and publishes `data`.
- `markNotFound(sessionKey)` drops any in-flight load and publishes `notFound`.

### 4.4 Related views

A confirmed save, a `404`, and a reconcile that does not confirm the save (it may still have committed)
refresh these views. Each one is refreshed only if it exists (`ref.exists`), with its `refresh()`, which keeps its filters and page:
- the review queue for `TeacherReviewQueueScope.all`;
- the task queue for `TeacherReviewQueueScope.task(topicId, assessmentId, type)` of the submission;
- the Homework detail for `TeacherHomeworkRouteTarget(topicId, homeworkId: assessmentId)`, or the Blitz detail for `TeacherBlitzRouteTarget(topicId, blitzId: assessmentId)`.

### 4.5 Screen

**Review section.** Each answer that is `waiting_for_teacher_review` or `teacher_checked` gets a review section in its card, under the status and feedback lines.

| Part | Content |
|---|---|
| Points field | Key `teacherSubmissionReviewPoints:<answerId>`. Label `Points`, helper `0 to <points>` (`formatTeacherReviewPoints`). It starts with the saved points, or empty while waiting |
| Feedback field | Key `teacherSubmissionReviewFeedback:<answerId>`. Label `Feedback (optional)`, 2 to 6 lines. It starts with the saved feedback |

Field errors are shown as the field's error text:

| Error | Text |
|---|---|
| `missing` | `Enter points.` |
| `invalid` | `Enter 0 to <points> with up to 6 decimal places.` |
| `feedbackTooLong` | `Use at most 2000 characters.` |
| `notReviewable` | `This answer can no longer be reviewed. Refresh the submission.`, shown under the section |

Behavior:
- The fields are disabled while saving or reconciling.
- When the saved state changes, after a refresh or a save, untouched fields show the new saved values. Typed values are kept.

**Review bar.** The bar has key `teacherSubmissionReviewBar` and is the Scaffold's `bottomNavigationBar`. It is shown while a detail is displayed that has at least one reviewable answer.

| Part | Content |
|---|---|
| Changes text | `No unsaved changes`, `1 answer changed` or `<n> answers changed` |
| Failure message | Key `teacherSubmissionReviewMessage`, when set |
| Discard | `TextButton` `Discard changes`, key `teacherSubmissionReviewDiscardButton`. Enabled when there are changes and nothing is busy |
| Save | `FilledButton` `Save review`, key `teacherSubmissionReviewSaveButton`. Enabled when there are changes, nothing is busy, and the detail status is `data` |
| Progress | While saving or reconciling: a `LinearProgressIndicator` with key `teacherSubmissionReviewProgress` and semantics label `Saving review` |

A success shows the SnackBar `Review saved.`

**Back and refresh.**
- Both are disabled while saving or reconciling.
- Refresh keeps the typed values and shows no dialog.
- Back with changes opens a dialog:
  - title `Discard unsaved review?`;
  - content `The points and feedback you entered have not been saved.`;
  - `Keep editing`, key `teacherSubmissionDiscardCancelButton`;
  - `Discard`, key `teacherSubmissionDiscardConfirmButton`, which leaves the screen.

### Non-goals

- No official score; that is `S09-FE-003C`.
- No mobile review, no backend change, no autosave of review drafts, and no per-answer save buttons.
- The `S09-FE-003A` lines (`Reviewed by …`, `Feedback: …`) are unchanged.

## 5. Tests

- **Domain.**
  - Normalization: the server trim set, a kept no-break space, empty to null.
  - Change detection:
    - `2.50` against a saved `2.5` is unchanged;
    - an untouched waiting answer is unchanged;
    - feedback only on a waiting answer gives `missing`;
    - cleared feedback on a checked answer becomes a null item.
  - Validation:
    - points above the Question points, 7 decimals, or not a number;
    - 2000 against 2001 code points, using characters outside the Basic Multilingual Plane.
  - The request: `toJson` exactly; empty or duplicate items throw; `matches`.
- **Data source.**
  - Method, path, body and `followRedirects: false`.
  - A `200` exact envelope gives the detail.
  - A wrong message, an extra key or a bad detail gives an unknown outcome.
  - An exact `409 automatic_checking_pending` and an exact `422` with field errors are definite failures.
  - A timeout gives an unknown outcome.
  - A non-canonical id throws before transport.
- **Controller.**
  - Edits and discard.
  - A save sends only the changed answers. Its success publishes the detail, clears the drafts, sets the feedback and refreshes every existing related view.
  - Client errors send nothing.
  - Reconcile: confirmed, not matching (drafts kept), and failed.
  - Every definite failure in the table, including the `422` mapping by item index.
  - Session failures.
  - A session change drops the completion.
  - Inactive on mobile.
  - No save unless the detail status is `data`.
- **Screen.**
  - Sections only on reviewable answers, with their starting texts.
  - Typing updates the changes text and enables Save.
  - A save with the SnackBar and the new status line.
  - Field errors and the failure message.
  - Everything disabled while saving, with the progress indicator.
  - Discard.
  - Back with changes: both dialog choices.
  - Refresh keeps typed values.
  - No bar without reviewable answers.

Review corrections (independent review: P1 = 0, P2 = 0, P3 = 7):
- the outcome of a save is decided before it is published, so a failure while publishing a confirmed
  save cannot start a reconcile;
- a reconcile that does not confirm the save also refreshes the related views (§4.4);
- tests now cover a detail of another submission, a session failure while reconciling, related views
  that are not shown, and the saved text replacing typed text after a save.

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
