# Focused Fix Contract: S09-FE-PHASE-2-FIX-001 — Related-View Refresh and User-Visible Defects

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-FE-PHASE-2-FIX-001` |
| Stage | `Stage 9 — Checking and Scoring` |
| Source | `S09-FE-PHASE-2` run #1 (`tasks/frontend/stage-09/S09-FE-PHASE-2-frontend-block-review.md` §7) |
| Owner decision | `S09-FE-PH2-D1`: fix the P2 and the five user-visible P3 findings, carry the rest |
| Baseline | `origin/main` `6e58259` |
| Status | `Approved` |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |

## 2. Goal

Fix the P2 finding: after a review save, the views below the submission must show the new state. Also fix the five P3 defects that a Teacher or Student can see.

## 3. Items

### 3.1 `C-1` (P2): a related-view refresh replaces a load in flight

**Problem.** `TeacherReviewQueueController.refresh()`, `TeacherHomeworkDetailController.refresh()` and `TeacherBlitzDetailController.refresh()` do nothing while their own load runs. That load may have been read before a review save committed, and it is then published as current.

**Fix.** Each of the three controllers gains `refreshAfterReview(TeacherSessionKey originatingSessionKey)`.
- It acts only when the controller owns that session key and the key still matches the live session.
- It drops any load in flight, so that load's completion is never published, and reloads the current query or target. Retained data stays on screen while the reload runs.

`TeacherSubmissionReviewController._refreshRelatedViews` calls `refreshAfterReview` with its session key instead of `refresh()`. The user-facing `refresh()` methods are unchanged.

### 3.2 `B-1` (P3): a 404 while reconciling the review deadline

**Problem.** In `TeacherHomeworkReviewDeadlineController`, a `404 resource_not_found` on the reconcile read leads to a blocking outcome review. That review holds the route lease forever.

**Fix.**
- A `404 resource_not_found` on the reconcile read is handled like the definite 404: mark the Homework unavailable, release the lease, and go back to idle.
- A `404 resource_not_found` on the read after a conflict also marks the Homework unavailable. The conflict message stays.

### 3.3 `A-1` (P3): a Homework file chosen during a refresh

**Problem.** When the picker returns while the Homework Attempt is being read again, the choice is restored to the previous entry and nothing is uploaded.

**Fix.** The pick is kept. It is validated against the last known Question and shown as `ready`, and the upload is deferred. Once the Attempt has authority again, the upload starts, as the Blitz file controller does with `_deferredUpload`.

The deferred upload is dropped in three cases:
- the Attempt becomes terminal;
- the session changes;
- the scope is cleared.

### 3.4 `A-3` (P3): cancelling the leave flush during a Submit flush

**Problem.** The leave flush and the Submit flush share the editor's flush, so a cancel from the leave dialog also ends the Submit flush. The Submit card then reports a save failure that did not happen.

**Fix.**
- The Homework and Blitz answer editor controllers record whether their latest flush ended through `cancelFlush()`.
- The Homework and Blitz Submit controls treat such a flush as cancelled. They show no "not saved" message and open no confirmation.

### 3.5 `A-4` (P3): the save status live region

**Fix.** In `StudentQuestionAnswerEditor`, the status text is a live region only for messages that need attention:
- the uncertain message;
- a failure message;
- a validation message.

`Saving…`, `Saved` and `Not answered` stay plain text.

### 3.6 `C-2` (P3): the review bar at large text sizes

**Fix.** On the Teacher submission detail, the review bar lays the changes text and failure message above the actions, and the actions wrap.

The screen must not overflow at either of these desktop sizes:
- 800×600 logical at text scale 2.0;
- 960×540 logical at text scale 2.25.

## 4. Non-Goals

- No other P3 finding. They are carried: `A-2`, `B-2`, `B-3`, `B-4`, `B-5`, `C-3`, `C-4`, `D-3`, `D-4`.
- No change to user-facing `refresh()` semantics.
- No backend change.

## 5. Tests

Each item gets a test that fails first:
1. **Item 1.**
   - For the queue, the Homework detail and the Blitz detail: a load running when a review save is confirmed is replaced. Two fetches are expected, and the published data comes from the second.
   - Another session's key does nothing.
2. **Item 2.** A 404 on the reconcile read makes the Homework not found and releases the lease. A 404 after a conflict also makes it not found.
3. **Item 3.**
   - A file chosen while the Attempt refreshes is kept and uploaded once the refresh publishes.
   - It is dropped when the Attempt turns terminal.
4. **Item 4.** For Homework and Blitz: a Submit flush cancelled from the leave dialog shows no "not saved" message.
5. **Item 5.** The live region is present for the failure, uncertain and validation messages, and absent for `Saving…` and `Saved`.
6. **Item 6.** Large-text desktop tests at both sizes report no overflow.

## 6. Verification

```text
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze
flutter test   (whole frontend suite, with TEMP on drive G:)
flutter build windows --debug
flutter build apk --debug
git diff --check
```

These results are Phase 2 run #2.

## 7. Acceptance Criteria

- [ ] §3 is implemented; each new test is seen failing first and mutation-checked.
- [ ] An independent fresh-context review of the fix finds P1 = 0, P2 = 0.
- [ ] Phase 2 run #2: every §6 check passes.
