# Implementation Contract: S09-FE-003A — Teacher Submission Detail and File Download (Desktop)

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-FE-003A` (first part of the planned `S09-FE-003`) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Frontend` (Teacher) |
| Status | `Approved` |
| Depends on | `S09-FE-002B` — delivered (PR #305, `main` `bf6df48`) |
| Implementation baseline | `origin/main` `bf6df48` |
| Decisions applied | `S09-D7` (review is desktop-only), `S09-T5` (the Teacher downloads submitted files), `S09-T3` (scores shown with one decimal) |
| Backend contract | `S09-DOC-001` §10.3 and §10.7. The detail is delivered by `S09-BE-005A`, the download by `S09-BE-005B` |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |

The rest of `S09-FE-003` follows in two tasks:
- `S09-FE-003B`: saving and correcting a review;
- `S09-FE-003C`: the official-score panel.

This file is the complete task contract.

## 2. Goal

On desktop, the Teacher opens a submission from either review queue. The Teacher reads every Question
with the Student's answer, the correct answer, the checking state, the awarded points and the feedback,
and can save the Student's submitted files.

## 3. Backend Contract (read from the code)

### 3.1 Detail request

`GET /api/v1/teacher/submissions/{submission}` takes no query parameters and no body. It returns `200`
with `{"data": {...}}` and no `message`.

`data` has the 15 queue-item keys parsed by `TeacherSubmissionDto`, plus:
- `submitted_at`: a timestamp or null;
- `questions`: every Question, ordered by `position` then `id`. Each element is `{question, answer|null}`.

### 3.2 Question

Keys: `id`, `type`, `position` (an int), `prompt`, `points` (a number ≥ 0), `checking_mode`,
`configuration`. There is no `instructions` key.

Allowed checking modes:
- `short_written`: `automatic` or `manual`;
- `open_written` and `file_based`: `manual`;
- every other type: `automatic`.

### 3.3 Configuration

Every row carries the ids that the answer values reference.

| Type | Configuration |
|---|---|
| choice | `{options:[{id, text, is_correct, position}]}`. Positions run 1..N; 2–20 options. `single_choice` has exactly 1 correct option, `multiple_choice` at least 1 |
| `true_false` | `{correct_value: bool}` |
| `short_written`, automatic | `{accepted_answers:[str]}`, 1–20 strings |
| `short_written`, manual | `{}` |
| `open_written` | `{}` |
| `file_based` | `{allowed_extensions:["pdf","docx","ppt","pptx"]}` |
| `matching` | `{pairs:[{client_key, left, right, left_item_id, right_item_id}]}`. A row is a correct match |
| `ordering` | `{items:[{id, text, correct_position}]}`. Positions run 1..N; at least 2 items |
| `fill_in_blank` | `{blanks:[{id, key, position, accepted_answers}]}`. Positions run 1..N |

### 3.4 Answer

`answer` is null when the Student gave no answer. Otherwise its keys are `id`, `value`,
`checking_status`, `awarded_points`, `feedback`, `checked_by` (`{id, full_name}` or null) and
`checked_at`.

| Status | Awarded points | Checked at | Feedback | Checked by |
|---|---|---|---|---|
| `pending` | null | null | null | null |
| `auto_checked` | set | set | null | null |
| `waiting_for_teacher_review` | null | null | null | null |
| `teacher_checked` | set | set | string or null | set |

Awarded points are always in 0..points.

### 3.5 Answer value

| Type | Value |
|---|---|
| choice | `{selected_option_ids:[id]}`. `single_choice` has exactly 1; `multiple_choice` has 1 to the number of correct options |
| `true_false` | `{value: bool}` |
| `short_written`, `open_written` | `{text: str}` |
| `matching` | `{pairs:[{left_item_id, right_item_id}]}`. A non-empty subset; no id repeats |
| `ordering` | `{items:[{item_id, position}]}`. A non-empty subset; positions are in 1..N and unique |
| `fill_in_blank` | `{values:[{blank_id, text}]}`. A non-empty subset; the text is non-blank |
| `file_based` | `{file:{id, original_name, extension, size_bytes}}`. The extension is one of the four; size is 1–15,728,640; the name is 1–500 characters |

Every id in a value refers to its own configuration.

### 3.6 Numbers and errors

- **Numbers** may be JSON integers or decimals.
- **Errors:**
  - `422` for a query parameter or a body;
  - `404 resource_not_found` for an unknown, foreign or in-progress submission;
  - the standard session errors.

### 3.7 File download

- **Request.** `GET /api/v1/files/{fileId}/download`, the same protected endpoint used by
  `ProtectedLearningMaterialTransfer`.
- **Success.** `200` with the file bytes; the headers are validated by `parseTrustedProtectedDownload`.
- **Errors.** `404 resource_not_found`, or `500 file_not_available`.

## 4. Scope

### 4.1 Route and navigation

- **Route.** Path `/teacher/reviews/{submissionId}`, name `teacher-submission-detail`.
  - `AppRoutePaths.teacherSubmissionDetail`; predicate `isTeacherSubmissionDetailPath`, exact with a
    canonical UUID; helper `teacherSubmissionDetailLocation(id)`, which throws on a non-canonical id.
  - It is a desktop-only, approved location, kept during desktop bootstrap, and built with
    `_buildTeacherDestination(..., authoring: true)`.
  - Mobile and unsupported surfaces get `/teacher`, the same as any other unknown Teacher path. A query
    string or fragment also gets `/teacher`.
- **Opening a submission.** Each row in both queues becomes tappable: an `InkWell` with a semantic label
  `Open submission of <Student name>` that calls `context.push(teacherSubmissionDetailLocation(id))`. The
  queue stays mounted, so returning keeps its filters and page.
- **Back.** The detail back button (key `teacherSubmissionBackButton`) pops when it can, and otherwise
  goes to `/teacher/reviews`.

### 4.2 Domain and parsing

**`TeacherSubmissionDetail`** has the fields:
- `submission`, the existing `TeacherSubmission`;
- `submittedAt`;
- `questions`, a list of `TeacherReviewQuestion`.

**`TeacherReviewQuestion`** has the fields `id`, `type` (`TeacherQuestionType`), `position`, `prompt`,
`points`, `checkingMode` (`TeacherQuestionCheckingMode`), a typed `configuration` and an `answer` that may
be null. The configuration has one class per type:
- choice, with option ids;
- true/false;
- short written, with its accepted answers or none when manual;
- open written;
- file;
- matching, with item ids;
- ordering, with item ids;
- fill-in-blank, with blank ids.

**`TeacherReviewAnswer`** has the fields:
- `id`, `checkingStatus` (`pending`, `autoChecked`, `waitingForTeacherReview`, `teacherChecked`);
- `awardedPoints`, `feedback`, `checkedBy` (`id`, `fullName`) and `checkedAt`;
- a typed `value`: choice, true/false, text, matching, ordering, fill-in-blank or file.

**`TeacherSubmissionDetailDto`** parses strictly:
- the 17 exact top-level keys; the shared 15 keys are delegated to `TeacherSubmissionDto`;
- every §3 rule: exact keys at every level, enums, canonical and unique ids, positions, counts, the
  checking modes allowed for each type, the null rules for each status, awarded points within 0..points,
  value shapes and the ids they reference;
- questions in ascending position order with unique ids;
- blank keys are unique and case-sensitive, like their placeholders;
- `waiting_for_teacher_review` and `teacher_checked` answers belong to manual Questions only.

Consistency with the submission:
- `review.waiting_answers` equals the number of waiting answers, and `review.reviewed_answers` the number of
  `teacher_checked` answers;
- a `checked` submission has no `pending` or waiting answers;
- a `waiting_for_teacher_review` submission has at least one waiting answer and no `pending` one;
- a `submitted` or `timed_out_finalized` submission has only `pending` answers.

Any violation is a `FormatException`, and the data source maps it to an invalid response.

**Data source.** `TeacherSubmissionRemoteDataSource.fetchSubmission(id)` sends `GET`, requires `200`
and a canonical id, and uses `followRedirects: false`. The repository's `fetchSubmission(id)` returns
the domain object and checks that the returned id matches the request; a mismatch is an invalid response.

### 4.3 Controllers

**`teacherSubmissionDetailControllerProvider`** is an `autoDispose.family` keyed by the submission id. It
is active for desktop Teacher sessions only and loads on build.
- Status: `initial`, `loading`, `data`, `refreshing`, `notFound` or `error`, with `isStale` when a
  failed refresh keeps the detail.
- Actions: `refresh()` and `retry()`.
- Session errors clear the controller.
- `404 resource_not_found` gives `notFound`.
- A stale completion after a session change is dropped.

**`teacherSubmissionFileControllerProvider`** is an `autoDispose.family` keyed by the submission id. It is
desktop-only.
- `saveFile(TeacherReviewFile file)` downloads through `protectedLearningMaterialTransferProvider` and
  saves with `localFileActionsProvider.saveAs`.
- Status: `idle`, `downloading`, `saving` or `failure`, with the active file id and a feedback.
- A saved file gives the feedback `File saved.`; a cancelled save gives no feedback.
- Session errors clear the controller.
- Only one file transfer runs at a time.

Failure feedback:

| Failure | Feedback |
|---|---|
| `resource_not_found` | `This file is no longer available.` |
| `file_not_available` | `The file is temporarily unavailable. Try again.` |
| invalid response | `The server returned an unexpected file response.` |
| timeout | `The download timed out. Try again.` |
| anything else | `The file could not be downloaded.` |

### 4.4 Screen

`TeacherSubmissionDetailScreen(submissionId)`, key `teacherSubmissionDetailScreen`, has the AppBar title
`Submission`, the back button and a refresh button (key `teacherSubmissionRefreshButton`).

**States.**
- **Loading.** A progress indicator with key `teacherSubmissionDetailLoading`.
- **Not found.** The text `This submission is not available.`
- **Error without data.** The text `The submission could not be loaded.` and a retry button (key
  `teacherSubmissionDetailRetryButton`).
- **Stale.** A banner with key `teacherSubmissionDetailStaleMessage` and the text `The displayed
  submission may be out of date.`
- Raw failure text is never shown.

**Header card** (key `teacherSubmissionHeader`).
- The Student name and the same chips as a queue row.
- The task line and the attempt line, as on a queue row. The shared row formatters move from
  `teacher_review_queue_screen.dart` into `teacher_review_formatters.dart` and are reused.
- `Submitted <time>` when it is not null.
- The review progress, `Review by`, and `Score <one decimal>` exactly as on the queue row.

**Question cards.** One card per Question, key `teacherSubmissionQuestion:<questionId>`.

| Part | Text |
|---|---|
| Heading | `Question <position> · <type label> · <points> points`, using `formatTeacherHomeworkPoints` and `teacherQuestionTypeLabel`; the word is `point` when the value is 1 |
| Prompt | the prompt |
| No answer | `No answer.` |
| `pending` | `Waiting for automatic checking` |
| `auto_checked` | `Checked automatically · <awarded> of <points> points` |
| `waiting_for_teacher_review` | `Waiting for review` |
| `teacher_checked` | `Reviewed by <name> · <awarded> of <points> points` (also `point` for 1) |
| Feedback | `Feedback: <text>` when set |

The answer is shown per type:
- **Choice.** One line per option in position order: `<text>`, plus ` · Student answer` when selected
  and ` · Correct` when correct.
- **True/false.** `Student answer: True|False` and `Correct answer: True|False`.
- **Short or open written.** `Student answer: <text>`. For automatic short written, also
  `Accepted answers: <a>, <b>`.
- **Matching.** Under `Student matches:`, a line `<left> → <right>` for each Student pair, in the
  configured left order. Under
  `Correct matches:`, a line `<left> → <right>` for each configured pair.
- **Ordering.** Under `Student order:`, a line `<position>. <text>` for each Student item in position
  order. Under `Correct order:`, a line `<n>. <text>`.
- **Fill in the blank.** Under `Student answers:`, a line `<key>: <text>` in blank position order. Under
  `Accepted answers:`, a line `<key>: <a>, <b>`.
- **File.** The line `<original name> · <EXTENSION> · <size>`, using `formatTeacherMaterialBytes`, and an
  `OutlinedButton.icon` `Save file` with key `teacherSubmissionFileSaveButton:<fileId>`.
  - While a transfer runs, every `Save file` button is disabled and a progress indicator is shown.
  - The success feedback appears in a SnackBar; a failure appears as text under the file.

### Non-goals

- No review inputs or saving (`S09-FE-003B`); no official score (`S09-FE-003C`).
- No mobile submission view; no backend change.

## 5. Tests

- **DTO.**
  - A full valid detail with all nine question types and every answer status.
  - A null answer.
  - Rejected:
    - an extra or missing key at each level;
    - an unknown type, mode or status;
    - a checking mode not allowed for the type;
    - the null rules broken;
    - awarded points above the Question points;
    - a value id that is not in the configuration;
    - a value shape that does not match the type;
    - single choice with two selections;
    - a duplicate pair or position;
    - a file with a bad extension or size;
    - positions out of order;
    - review counts that do not match;
    - a status/answer contradiction.
- **Data source.** Path, method, no body, `200`; a format failure is an invalid response; a non-canonical id is
  rejected before transport. The repository rejects an id mismatch.
- **Detail controller.** Load; inactive on mobile; `404` gives not found; error and retry; a failed refresh is
  stale; session errors.
- **File controller.**
  - Save, which downloads and saves with the `File saved.` feedback.
  - A cancelled save.
  - Each failure message.
  - Only one transfer at a time.
  - Session errors.
- **Router.**
  - The exact predicate and helper.
  - A desktop direct entry, and a desktop deep link through bootstrap.
  - Mobile, query strings and fragments are redirected to `/teacher`.
  - A row tap opens the detail, and back returns to the queue with its page kept. From a task queue,
    back returns to that task queue.
- **Screen.** For every question type: the header, the status lines and the answer texts. Plus the
  feedback line, the `Save file` flow with its disabled state, and the not-found, error, stale and
  loading states.

Review corrections (independent review: P2 = 3, P3 = 4):
- blank keys that differ only by case were rejected;
- the DTO tests now cover a missing and an extra key at every level, an unknown mode, and unknown matching,
  ordering and fill-in-blank ids;
- the screen tests now assert the heading and status line of every card, including the pending line;
- the DTO now rejects review statuses on automatic Questions and pending answers in a waiting submission;
- Student matches follow the configured order;
- tests cover dropping stale completions after a session change.

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
