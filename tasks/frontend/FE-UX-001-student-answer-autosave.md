# FE-UX-001 — Student Answer Autosave

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `FE-UX-001` (platform task; runs before Stage 9 code, not counted as a Stage 9 task) |
| Area | Frontend (Student Homework and Blitz Attempt screens) + documentation |
| Owner decisions | `INT-D2` (2026-09-27: the Save button is unwanted), `S09-D8` = A (autosave now, as a separate task), `S09-D8a` = A (file answers upload right after the file is chosen) |
| Baseline | `origin/main` `b07bdb14` plus the Stage 9 planning package |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |

## 2. Goal

A Student never presses a button to save an answer. Every answer, including a chosen file, is saved
automatically while the Attempt is editable. The Homework screen no longer jumps back to Question 1, and
nothing a save or a refresh does disturbs what the Student is typing.

This deliberately reverses the Stage 7/8 decisions “explicit per-Question Save, no autosave”
(`S07-FE-003` §67, `S07-FE-004`, `S07-FE-005` §51, `S08-FE-005`) and “render the Attempt shell only on
confirmed current data” (`S07-FE-002` §45) for the refresh case in §5.4. Those historical task files are
not edited; the reversal is recorded in `tasks/STAGE_09_TASK_INDEX.md`.

## 3. Scope

### Included

- Automatic saving of the eight non-file answer types on Homework and Blitz Attempt screens, desktop and
  mobile; automatic upload of a chosen file.
- Removal of the `Save answer`, `Discard changes`, `Upload answer`/`Upload replacement` and
  `Discard selected file` buttons.
- Submit and leave-screen flushing; the Question-1 jump fix; typing protection during saves, refreshes
  and recovery.
- Documentation: `BR-SUB-004` (`docs/05:1526`), `docs/06` §19.11 (`:2513`), `docs/03:2199`,
  `docs/04:5433` and the Student Homework/Blitz flow lines in `docs/04`.

### Non-goals

- No backend change: the existing `PUT /api/v1/student/attempts/{attempt}/answers/{question}` (JSON and
  multipart) is used as is, without an `Idempotency-Key`.
- No offline drafts, no local persistence across app restarts, no Teacher-side change, no new package.
- No change to Blitz timing: nothing is written after local zero, exactly as today.
- No change to server Submit semantics or finalization.

## 4. Current Implementation Context

Paths are under `frontend/lib/features/student/`.

- Both Attempt screens render every Question in one `SingleChildScrollView`
  (`presentation/student_homework_attempt_screen.dart:393`, key `studentHomeworkAttemptScroll`;
  `presentation/student_blitz_attempt_shell.dart:61`, key `studentBlitzAttemptShell`). There is no
  question-by-question navigation.
- Each Question has a `StudentQuestionAnswerEditorState` (`application/student_attempt_answer_editor_state.dart`)
  with `serverAnswer`, `draft`, `validation`, semantic `isDirty` (`domain/student_answer_draft.dart:235-281`)
  and `saveStatus` (`idle, saving, uncertain, failure, saved`). `canSave` allows one save in flight per
  Attempt (`activeQuestionId == null`). A Question is not editable while its own save is in flight.
- Homework `saveAnswer` (`application/student_attempt_answer_editor_controller.dart:119-197`) replaces the
  draft with the server value and calls `_refreshAttempt()` (`:176`). Blitz `saveAnswer`
  (`application/student_blitz_answer_editor_controller.dart:122-221`) claims `execution.beginWrite()`
  (null while a replay is pending: the save silently no-ops) and patches the parent with
  `acceptAnswerMutation` (`application/student_blitz_execution_controller.dart:134-182`), which requires
  the publication token to be identical to the one captured before the request.
- An uncertain outcome (network, timeout, 5xx) keeps `activeQuestionId` set and blocks every save until the
  Student presses the per-Question recovery button (Homework `reloadAttempt` `:199-273`, Blitz
  `checkCurrentAttempt` `:225-289`). Both recoveries adopt the server value into the draft. The Blitz shell
  button `Check current attempt` (`student_blitz_attempt_shell.dart:87-90`) does not clear a Question's
  uncertain state.
- Submit readiness (`application/student_homework_submit_readiness.dart:140-153`,
  `application/student_blitz_submit_readiness.dart:152-165`) blocks on dirty, saving and uncertain answers.
  It has no separate blocker for validation errors or failed saves: those are covered only because such a
  draft is dirty. The confirmation compares the ready token by identity (`student_homework_submit_controller.dart:67-78`,
  `student_blitz_submit_controller.dart:81-86`); the dialog and token live in
  `presentation/student_homework_submit_controls.dart` and `presentation/student_blitz_submit_controls.dart`.
- Leave dialogs: Homework `studentHomeworkSubmitInProgressDialog`, `studentHomeworkSubmitLeaveDialog`,
  `studentHomeworkAttemptLeaveDialog` (`student_homework_attempt_screen.dart:54-146`); Blitz
  `studentBlitzSubmitInProgressDialog`, `studentBlitzSubmitLeaveDialog`, `studentBlitzUnconfirmedLeaveDialog`,
  `studentBlitzReconcilingLeaveDialog`, `studentBlitzUnsavedLeaveDialog`, `studentBlitzLeaveDialog`
  (“Your server timer will continue”) (`student_blitz_detail_screen.dart:357-490`).
- File answers: choosing keeps a local selection; a separate button uploads it
  (`application/student_file_answer_controller.dart:102-341`, `application/student_blitz_file_answer_controller.dart:180-338`).
  The file controllers have their own per-Attempt upload gate (`application/student_file_answer_state.dart:67-73`),
  independent of the text-save gate.
- **Question-1 jump root cause:** Homework `_refreshAttempt()` → `StudentHomeworkAttemptController.refresh()`
  sets `status = refreshing`; the screen replaces `_AttemptContent` with a progress indicator
  (`student_homework_attempt_screen.dart:257-288`), unmounting the scroll view (plain `Key`, no stored offset).
  The rebuilt view starts at offset 0. The same happens after a file upload, a reload and reconciled 409s.
  Blitz does not re-read after a save and keeps its shell during `refreshing`.
- Text fields rewrite their controller text and move the cursor to the end when the draft differs from the
  field (`presentation/student_written_answer_editor.dart:28-41`).
- The backend writes nothing when the saved value equals the stored one, has no API throttle (only login is
  rate-limited), and serializes saves on the Attempt row lock.

## 5. Exact Contract

### 5.1 When a non-file answer is saved

- 1000 ms after the last draft change of a Question (every non-file type), the Question is queued.
- When a text field (short, open, each blank) loses focus, its Question is queued immediately.
- When the app goes to the background (`AppLifecycleState.inactive`, `hidden` or `paused`), every dirty
  valid Question is queued immediately.
- Text saves stay one in flight per Attempt. Queued Questions are sent in the order they first became dirty;
  a Question changed while its save is in flight is queued again after that save finishes.
- A draft with a local validation error is not sent; it is queued as soon as it becomes valid.
- A Question whose draft is not dirty is never sent.
- File uploads (§5.7) are not in this queue; they may run while a text save runs.

### 5.2 Drafts are never overwritten

- A Question stays editable while its own save is in flight; the request carries a snapshot of the draft.
- No save result, refresh, recovery or replay replaces a **dirty** local draft of an editable Attempt: for
  a dirty Question they only set `serverAnswer`/`updatedAt`, and the Question stays queued. A **clean**
  Question adopts the new server value as its draft, so a change saved from another device is shown and is
  never overwritten by a stale local value. A Question is clean when `draft.isDirty(question, serverAnswer)`
  is false. The text, cursor and focus of a dirty Question are never changed by these events.
- Drafts are replaced only when the Attempt becomes terminal (today's terminal adoption) or the session
  ends (today's `_clearForSessionFailure`).
- `Clear answer` stays: it sets the empty draft, which is saved like any change (the server deletes the answer).

### 5.3 Parent patching without re-reads

- A successful Homework save or file upload no longer calls `_refreshAttempt()`. `StudentHomeworkAttemptController`
  gains `acceptAnswerMutation` with the Blitz guards (active session, same Attempt id, `in_progress`,
  matching Question id and type, `answer`/`updatedAt` both present or both null).
- Both controllers separate two tokens: the **read token**, replaced only by a full Attempt read, refresh or
  replay, and the **publication token**, replaced by every change including patches. A write captures the
  read token when it starts, and its patch is accepted when the read token is still identical. Patches of
  other Questions in between therefore no longer reject it, so a text save and an upload that overlap are
  both accepted.
- If a patch is rejected (the read token changed), the Homework refresh path or the Blitz reconciliation
  runs as today; drafts follow §5.2.
- The child controllers switch their own write guards to the read token as well: the Blitz editor
  `mutationPublication` (`student_blitz_answer_editor_controller.dart:143`), the Homework file
  `_FileOperation.sourcePublication`/`preservePublication` (`student_file_answer_controller.dart:283-286,
  583-591`) and the Blitz transfer `_revokedFile` (`student_blitz_submission_transfer_controller.dart:48`),
  with `student_attempt_publication_token.dart` as needed. Submit readiness keeps its publication-identity
  checks.

### 5.4 Refresh and scroll

- While a Homework refresh is running and the retained Attempt is the same `in_progress` Attempt,
  `_AttemptContent` stays mounted and editable; saves wait until the refresh ends. The progress indicator
  replaces the content only for a first load, a different Attempt or a non-`in_progress` retained Attempt.
  The test “refresh hides shell until both reads are current” is changed to this rule.
- If such a refresh fails, the content stays mounted with a failure banner and a `Retry` button instead of
  the full-screen error (`student_homework_attempt_screen.dart:243-256`); a flush (§5.8) stops on it.
- Both scroll views use a `PageStorageKey` with their current key string, so any remount restores the scroll
  offset. Tests that find these views use the new key type.

### 5.5 Failures and recovery

- **Uncertain outcome** (text save or upload): the recovery runs automatically — Homework `reloadAttempt`,
  Blitz `checkCurrentAttempt` — 2 s after the uncertain result, then after 4, 8, 16 and every 30 s while the
  recovery itself ends uncertain. The per-Question recovery button stays and runs it at once. Recovery clears
  the Question's uncertain state, never replaces drafts (§5.2), and afterwards dirty Questions are queued again.
- Recovery timers stop when the Attempt becomes terminal, at Blitz local zero, on session failure, and when
  the screen or controller is disposed.
- **`422 validation_failed`:** the Question shows the failure and is not sent again until its draft changes.
- **Every other 4xx** keeps today's reconciliation (`_reconcileFailure`, `_reconciledCodes`). Autosave never
  resends a rejected value on its own.
- **Blitz write gate busy** (`beginWrite()` returns null): the Question stays queued and is sent when the gate
  frees. It is never dropped.
- **Blitz local zero:** the queue is cleared and nothing more is sent; `studentBlitzUnconfirmedAtZero` stays.
- Leaving through a route change other than back or system back (for example an authentication redirect)
  drops unsent changes, as today's session-failure path does.

### 5.6 Status line (key `studentSaveStatus{questionId}` unchanged)

First matching row:

| State | Text |
|---|---|
| uncertain | `Save not confirmed. Checking…` plus the recovery button |
| failure | the existing `studentAnswerSaveFailureMessage` text; Blitz `blitz_time_expired` and `blitz_not_active` get `Time is over. This answer was not saved.` and `This Blitz is not active. This answer was not saved.` |
| dirty with a local validation error | the validation message |
| dirty (waiting or queued) or saving | `Saving…` |
| clean with a saved answer | `Saved` |
| clean without an answer | `Not answered` |

`Last saved: …` and the progress bar stay.

### 5.7 File answers (`S09-D8a`)

- Choosing a file starts its upload at once (Homework and Blitz). `Choose file` / `Choose replacement` stay;
  `Upload answer`, `Upload replacement` and `Discard selected file` are removed.
- The existing per-Attempt upload gate stays: while any upload of the Attempt runs, every choose button of
  that Attempt is disabled.
- A retryable upload failure (network, timeout, 5xx) keeps the chosen file and shows `Retry upload` and
  `Cancel`; `Cancel` drops the selection and leaves the saved server file unchanged. An uncertain upload
  also uses the recovery of §5.5.
- A non-retryable rejection (`validation_failed`, `unsupported_file_type`, `file_too_large`,
  `file_upload_failed`) drops the selection at once and shows the error with the file name; the saved server
  file is unchanged and the Student can choose another file. A dropped selection never blocks Submit.
- Blitz starts no upload after local zero.

### 5.8 Submit

- The ready token requires: no dirty, queued or saving Question; no validation error; no failed or uncertain
  save; no pending, running, failed or uncertain upload; plus every other blocker it has today. Validation
  errors and failed saves become explicit blockers.
- The Submit button stays enabled while the only blockers are dirty, queued or saving Questions. Pressing it
  starts a **flush**:
  1. Editors become read-only (the Student sees `Saving answers…` and a `Cancel` button); debounce timers are
     cancelled and every dirty valid Question is queued.
  2. The flush ends with success when nothing is dirty, queued or saving and no upload runs; then readiness is
     evaluated again and, if ready, the existing confirmation opens with a fresh token.
  3. The flush stops as soon as a save or upload ends uncertain or failed, or a dirty Question has a
     validation error, or the Student presses `Cancel`. Editors become editable again and, unless cancelled,
     the Student sees `Some answers are not saved yet. Check the marked questions.`
- Blitz flushes only while writes are accepted; local zero stops the flush.

### 5.9 Leaving the screen

- Back, system back and the Blitz `Leave Blitz` button (`student_blitz_attempt_shell.dart:140-145`) first
  flush as in §5.8 (the Student sees progress and may cancel the leave).
- Homework: if everything is saved, the screen closes with no dialog. If something is not saved,
  `studentHomeworkAttemptLeaveDialog` opens with `Some answers are not saved.\nLeave and lose these changes?`
  The submit dialogs (`studentHomeworkSubmitInProgressDialog`, `studentHomeworkSubmitLeaveDialog`) are
  unchanged.
- Blitz: after the flush, the existing dialog selection is unchanged, except that
  `studentBlitzUnsavedLeaveDialog` opens only when something is not saved after the flush, with the text
  above. `studentBlitzLeaveDialog` (running timer), the submit, unconfirmed and reconciling dialogs keep their
  conditions and texts.

### 5.10 Placement and tests

- Autosave scheduling lives in the editor controllers or one small shared helper in `application/`, never in
  widgets. Timers are created through an injected factory so tests control time with `WidgetTester.pump`
  or a fake timer implementation in the test files; no new dependency (not `fake_async`, which the lint
  `depend_on_referenced_packages` would reject) and no real waiting.

## 6. Documentation

- `BR-SUB-004` (`docs/05:1526`): Student answers on an editable Homework or Blitz Attempt are saved
  automatically (typed answers 1 s after the last change, when leaving a text field, before Submit and
  when the app goes to the background; files right after they are chosen). There is no Save button.
  Offline drafts stay outside the MVP.
- `docs/06` §19.11, `docs/03:2199`, `docs/04:5433`: remove autosave from the future lists.
- `docs/04` Student Homework and Blitz flows (`:1306`, `:1401`, `:1467`, `:2193`, `:2519`): “saves typed
  answers” becomes “answers are saved automatically”.

## 7. Expected Files

```text
frontend/lib/features/student/application/student_attempt_answer_editor_controller.dart
frontend/lib/features/student/application/student_attempt_answer_editor_state.dart
frontend/lib/features/student/application/student_blitz_answer_editor_controller.dart
frontend/lib/features/student/application/student_blitz_answer_editor_state.dart
frontend/lib/features/student/application/student_homework_attempt_controller.dart
frontend/lib/features/student/application/student_homework_attempt_state.dart
frontend/lib/features/student/application/student_blitz_execution_controller.dart
frontend/lib/features/student/application/student_blitz_execution_state.dart
frontend/lib/features/student/application/student_file_answer_controller.dart
frontend/lib/features/student/application/student_file_answer_state.dart
frontend/lib/features/student/application/student_blitz_file_answer_controller.dart
frontend/lib/features/student/application/student_blitz_submission_transfer_controller.dart
frontend/lib/features/student/application/student_attempt_publication_token.dart
frontend/lib/features/student/application/student_homework_submit_readiness.dart
frontend/lib/features/student/application/student_blitz_submit_readiness.dart
frontend/lib/features/student/application/student_homework_submit_controller.dart
frontend/lib/features/student/application/student_blitz_submit_controller.dart
frontend/lib/features/student/application/<autosave helper>.dart                 (optional)
frontend/lib/features/student/domain/student_answer_draft.dart                     (only if needed)
frontend/lib/features/student/presentation/student_question_answer_editor.dart
frontend/lib/features/student/presentation/student_written_answer_editor.dart
frontend/lib/features/student/presentation/student_fill_blank_answer_editor.dart
frontend/lib/features/student/presentation/student_file_answer_editor.dart
frontend/lib/features/student/presentation/student_homework_attempt_screen.dart
frontend/lib/features/student/presentation/student_homework_submit_controls.dart
frontend/lib/features/student/presentation/student_blitz_attempt_shell.dart
frontend/lib/features/student/presentation/student_blitz_submit_controls.dart
frontend/lib/features/student/presentation/student_blitz_detail_screen.dart
frontend/lib/features/student/presentation/student_homework_formatters.dart
frontend/lib/features/student/presentation/student_blitz_formatters.dart
frontend/test/features/student/**            (tests that tap Save/Upload are rewritten)
frontend/integration_test/stage7_student_homework_flow_test.dart
frontend/integration_test/stage8_blitz_flow_test.dart
docs/03-features.md
docs/04-user-flows.md
docs/05-business-rules.md
docs/06-roadmap.md
tasks/frontend/FE-UX-001-student-answer-autosave.md
tasks/STAGE_09_TASK_INDEX.md
tasks/README.md
```

Other files only when a concrete compile dependency requires them.

## 8. Acceptance Criteria

- [ ] No Student Attempt screen shows `Save answer`, `Discard changes`, `Upload answer`,
      `Upload replacement` or `Discard selected file`.
- [ ] A typed change is sent 1000 ms after the last change and not before; a focus loss and an app pause send
      it at once.
- [ ] Typing continues without loss, cursor jump or focus loss while that Question's save, a Homework refresh
      or an automatic recovery runs; a change made meanwhile is sent afterwards.
- [ ] One text save in flight per Attempt, in first-dirty order; a text save and an upload that overlap are
      both adopted without a refresh or an uncertain state.
- [ ] A successful Homework save or upload makes no Attempt GET; the Homework screen keeps its scroll position
      after a save, an upload and a reload (the Question-1 regression test fails before the fix).
- [ ] An uncertain save recovers automatically on the §5.5 schedule and stops under the §5.5 conditions;
      a `422` is not resent until the draft changes; a Blitz save that meets a busy write gate is sent later.
- [ ] Choosing a file uploads it at once; `Retry upload` and `Cancel` work after a retryable failure; a
      rejected file is dropped with its error and never blocks Submit.
- [ ] A clean Question shows a value saved from another device after a refresh and never sends its stale
      value back.
- [ ] Submit right after typing saves first and then opens the confirmation; a keystroke cannot slip in after
      the flush; an uncertain or failed save ends the flush with the §5.8 message; `Cancel` works.
- [ ] Leaving after typing saves first and closes without a dialog; an unsaved answer shows the §5.9 dialog;
      the Blitz timer warning still appears while a Blitz runs.
- [ ] Nothing is sent after Blitz local zero.
- [ ] The two integration scripts no longer tap removed buttons: their `_save` helpers wait for `Saved`; the
      Stage 8 “unsaved draft lost at timeout” step becomes “an autosaved draft is kept at timeout”. They are
      re-run in `S09-INT-001`.
- [ ] `docs/03`, `04`, `05`, `06` state autosave as in §6.

## 9. Focused Verification

Use the project SDK at `frontend/.fvm/flutter_sdk` (FVM is not on PATH).

```text
flutter test test/features/student
flutter analyze
dart format --output=none --set-exit-if-changed <changed Dart files>
git diff --check
```

The change is confined to the Student Attempt screens, so the full frontend suite, builds and the real-stack
integration are not rerun here; `S09-INT-001` covers the Student answer flows on the real stack.

**Project Owner manual smoke** (Windows desktop and Android emulator), after the PR is opened: Homework —
type an answer, wait, reopen the Attempt: the answer is there; the screen never jumps to Question 1; press
Submit right after typing: the answer is included. Blitz — type, wait, let the time run out: the saved answer
is kept; leaving a running Blitz still warns about the timer. File — choose a file: it uploads without another tap.

## 10. Completion Report

Implementation summary, changed files, the exact verification commands and results, `git diff --check`,
deviations, and the PR link.
