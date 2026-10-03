# Implementation Contract: S10-FE-003 — Teacher Topic Result Actions

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S10-FE-003` |
| Stage | `Stage 10 — Final Result and Understanding Assessment` |
| Area | `Frontend` (Teacher) + docs alignment |
| Status | `Approved` |
| Depends on | `S10-FE-002` on `main` `55883ee` |
| Owner decisions applied | `S10-FE-D1` = B (release on desktop and mobile; comment and close desktop-only), `S10-D1`, `S10-D5`, `S10-D7`, `S10-D9` |
| Implementation | Claude |
| Delivery | Claude opens the PR and merges it after review `PASS` and green verification |
| Blocks | `S10-FE-004` |

Normative sources: `docs/09` §§25.7-25.9, 27.3-27.7; `docs/04:1127-1151`; frontend plan (index §7 row `8`).

## 2. Goal

The Teacher acts on Topic results: releases one result or all ready results to Students and to Parents on desktop
and mobile, and on desktop writes the comment and closes one result or all ready results. Every action is
confirmed by the server's answer; the client never decides eligibility itself.

## 3. Scope

Included: §5.1-§5.6. Non-goals: activation/archive warnings, the review `result_closed` message, review-queue
filters, related-view refresh outside the result screens (`S10-FE-004`); an unsaved-comment leave guard; any
unrelease (none exists, `S10-D5`); Parent screens; any backend change.

## 4. Current Context

- `S10-FE-002`: `TeacherTopicResultRepository` (reads), strict detail DTO, list and detail controllers, entry
  card, list and detail screens.
- `sendTeacherMutation` (`teacher_mutation_transport.dart`): one send, an exact documented failure envelope with
  a whitelisted `409` code is a definite failure, anything else an unknown outcome.
- The single actions and both bulk actions are idempotent on the server (an already-done action returns `200`
  without a change; bulk counts it as `already_done`), and the comment `PUT` sets a value, so a reload after an
  unknown outcome and a later new attempt are safe.

## 5. Exact Contract

### 5.1 Data

| Call | Request | `409` codes that are definite |
|---|---|---|
| `updateComment(topicId, studentId, comment)` | `PUT …/results/{student}/comment` `{"teacher_comment": <trimmed text or null>}` | `result_closed` |
| `release(topicId, studentId, student)` | `POST …/results/{student}/release/student` `{}` | `manual_release_not_allowed`, `result_not_ready` |
| `release(topicId, studentId, parent)` | `POST …/results/{student}/release/parent` `{}` | `manual_release_not_allowed`, `student_result_not_released` |
| `close(topicId, studentId)` | `POST …/results/{student}/close` `{}` | `result_not_ready_for_closure` |
| `releaseAll(topicId, student / parent)` | `POST …/results/release/{student,parent}` `{}` | `manual_release_not_allowed` |
| `closeAll(topicId)` | `POST …/results/close` `{}` | none |

- Through `sendTeacherMutation`, no redirects. Success is exactly `200` with `{data, message}` (a non-blank
  message that is never shown): single actions carry the §25.6 detail (the `S10-FE-002` DTO), bulk actions
  exactly `{processed, skipped: {already_done, not_ready}}` with non-negative integers. Anything else is an
  unknown outcome (`TeacherTopicResultMutationOutcomeUnknownException`).
- The repository also treats as unknown: a detail of another Student; after a comment save a comment other than
  the sent one; after a release no release time for that audience; after a close a result that is not closed.
- Non-canonical ids throw `ArgumentError` before any request.

### 5.2 Single actions on the result detail screen

| Action | Shown when | Surfaces |
|---|---|---|
| "Release to Student" | `can_release_to_student` | desktop, mobile |
| "Release to Parents" | `can_release_to_parent` | desktop, mobile |
| "Close result" | `can_close` | desktop |
| Comment editor | result not closed | desktop (mobile and closed results show the comment read-only) |

- Actions show only while the detail is confirmed current (not loading, refreshing, failed or stale) and are all
  disabled while one runs.
- Release and close ask first (Cancel focused): "Release to the Student?" — "{name} will see the scores, the
  category and your comment. A release cannot be undone."; "Release to Parents?" — "The Parents of {name} will
  see the scores, the category and your comment. A release cannot be undone."; "Close this result?" — "The
  result of {name} becomes final: corrections of the official answers and comment changes are no longer
  possible. Closing cannot be undone."
- Comment editor: prefilled field, counter "N / 2000" (Unicode code points of the trimmed text), "Save comment"
  enabled only when the trimmed text differs from the saved comment and fits ("Use at most 2000 characters.");
  an empty text removes the comment.
- Success: the returned detail is shown, the results list (when open) reloads, and a SnackBar says "Result
  released to the Student.", "Result released to Parents.", "Result closed.", "Comment saved." or "Comment
  removed.".

### 5.3 Bulk actions on the results list screen

- Shown only while the list shows confirmed current rows: "Release ready results to Students" when the Student
  release mode is `manual_teacher`, "Release ready results to Parents" when the Parent mode is `manual_teacher`
  (the Institution modes carried by the rows), "Close ready results" (desktop only). All disabled while one runs.
- Each asks first and names the scope: every Student of the Topic, not only this page or filter; results that
  are not ready are skipped; a release (closing) cannot be undone; closed results can no longer change.
- Success shows a report (live region) and reloads the list: "Released to 21 Students." / "Released to the
  Parents of 21 Students." / "Closed 21 results." followed by "Skipped: 3 already released, 6 not ready yet."
  ("already closed" for close) when anything was skipped; singular forms for one.

### 5.4 Failures

| Failure | Message (inline, live region) | Then |
|---|---|---|
| `409 manual_release_not_allowed` | "The Institution's release mode does not allow a Teacher release." | reload |
| `409 result_not_ready` | "This result is not ready to be released yet." | reload |
| `409 student_result_not_released` | "Parents can see the result only after the Student can." | reload |
| `409 result_not_ready_for_closure` | "This result cannot be closed yet." | reload |
| `409 result_closed` | "This result is closed, so its comment cannot change." | reload |
| `404 resource_not_found` | "This result is no longer available." (bulk: "These Topic results are no longer available.") | reload |
| `422 validation_failed` (comment) | "The comment could not be saved. Check it and try again." | — |
| `429 rate_limited` | "Too many requests. Wait a moment and try again." | — |
| unknown outcome | "The result could not be confirmed and was reloaded. Check it before trying again." (bulk: "The results could not be confirmed and were reloaded. …") | reload |
| session failures | the state clears; bootstrap as for reads | — |

"Reload" refreshes the detail (single actions) and the list. A result of a stale session is never published.

### 5.5 Docs aligned to `S10-FE-D1`

`docs/03` Teacher desktop and mobile lists (results and release); `docs/04` the Teacher mobile flow note and the
result device flow; `docs/06` Stage 10 (the Teacher screens: desktop and mobile read and release, desktop-only
comment and close); `docs/07` §17.9 and the device paragraph (the screens follow `S10-FE-D1`).

### 5.6 Tests

Data source (paths, bodies, whitelists per call, unknown outcomes, guards), repository consistency checks,
both action controllers (success, each failure row, unknown outcome, busy guard, session change, desktop-only
actions refused on mobile), detail and list widgets (buttons per flag and surface, confirmations and Cancel,
comment counter and limit, SnackBars and reports, failure notices, hidden while stale), narrow 360 px with text
scaling.

## 6. Verification

```text
flutter test test/features/teacher test/router_bootstrap_test.dart; flutter analyze --no-pub lib test;
dart format --output=none --set-exit-if-changed lib test; git diff --check
```
