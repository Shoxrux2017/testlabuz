# Focused Fix Contract: S08-FE-PHASE-2-FIX-001 — Countdown Baseline, Return Re-read and Route Ownership

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-FE-PHASE-2-FIX-001` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Origin | `S08-FE-PHASE-2` run #1 on audited `main` `03c6581` — `NOT ACCEPTED` |
| Findings fixed | `P2-1`, `P3-1`, `P3-2`, `P3-3`, `P3-4` |
| Project Owner decisions | `FE-D1 = B`, `FE-D2 = A` (2026-09-27) |
| Area | Frontend (Flutter) |
| Implementation | Claude (implementation role, as reassigned 2026-09-23) |
| Delivery | Claude opens the PR; Project Owner reviews and merges |
| Depends on | Nothing |

## 2. Goal

Remove the blocking Stage 8 frontend defect found by Frontend Phase 2 run #1 and close its minor
findings, without changing any API call, error handling, route or unrelated behavior:

1. A Student Blitz countdown never shows more time than the server snapshot allows: its elapsed-time
   baseline starts when the snapshot is adopted, not when the countdown is first drawn.
2. When the Student returns to the app, the Blitz detail is re-read once, so a countdown that stood
   still while the app was hidden or the device slept is re-anchored from a fresh server snapshot.
3. An older Teacher screen instance leaving its route cannot stop or clear a newer instance of the
   same Blitz route.
4. The missing or unrealistic tests named by run #1 are added.

## 3. Scope

### Included

- `P2-1` — adoption-time countdown baseline (FE-004 §85 conformance), §5.1.
- `FE-D1 = B` — one Blitz detail re-read when the app becomes visible again, §5.2.
- `P3-1` — uncertain Start Retry tests for `start_replacement` and Resume #2, §5.3.
- `P3-2` — route-owner generations for Teacher Blitz monitoring and Teacher Blitz detail, §5.4.
- `P3-3` — a realistic result-pair-lock test for Blitz Question authoring, §5.5.
- `P3-4` — the stale doc comment in `teacher_blitz_section.dart`, §5.6.

### Non-Goals

- No POST, no Start replay and no new Idempotency-Key caused by returning to the app.
- No change to the countdown formula, the local-zero behavior, the re-anchor rule for an older or
  equal snapshot, the Start/Resume/Submit/answer/file flows, or any request, DTO, error code or
  route.
- No change to Stage 7 Homework screens or controllers (their route pattern is out of this finding).
- No change to Teacher monitoring polling rules other than route ownership.
- No refactor of the duplicated Blitz/Homework controllers (run #1 observation, contracts allow it).
- No Stage 9 behavior.

## 4. Current Implementation Context (audited `03c6581`)

- `frontend/lib/features/student/presentation/student_blitz_countdown.dart:64-66`: `_anchor()` creates
  and starts the `Stopwatch` (from `studentBlitzStopwatchFactoryProvider`, defined in the same
  file) in `initState` / `didUpdateWidget`, i.e. when the countdown widget is first built for an
  anchor.
- `StudentBlitzCountdownAnchor` (`frontend/lib/features/student/domain/student_blitz.dart:130-160`)
  holds only `subjectId`, `deadlineAt`, `serverNow`, `remainingSeconds`; equality is value-based.
- Execution anchors are built by `StudentBlitzExecutionController._publish`
  (`student_blitz_execution_controller.dart:445-451`, a new anchor on every publish) and `_onDetail`
  (`:387-408`, only from a strictly newer `serverNow`). The pre-Start class-time anchor is built
  in presentation by `studentBlitzPreStartAnchor(blitz)` (`student_blitz_detail_screen.dart:486-503`)
  from the published detail.
- A snapshot adopted while the app renders no frames (Start/Resume/Check current attempt answered
  while the app is hidden) starts its countdown only on return, so the first shown value is the full
  old `remaining_seconds`, and local writes stay enabled past the real deadline until the server
  answers `blitz_time_expired`.
- No Student screen listens to the app lifecycle; nothing re-reads on return.
- `teacher_blitz_monitoring_screen.dart:55-69` calls `leaveLiveRoute()` unconditionally after the
  frame on the shared family notifier; `teacher_blitz_detail_screen.dart:51-82` calls
  `invalidateRouteCompletions()`, `leaveRoute()` and `endRoute()` unconditionally on the shared
  lifecycle, official and route-activity notifiers. A popping instance of the same route (Back, then
  Monitor or the Blitz card again during the pop transition) therefore stops the newer instance.
  `TeacherBlitzQuestionBuilderController.enterRoute()` / `leaveRoute([int? ownerGeneration])` /
  `ownsRouteGeneration` already implement the owner-generation pattern.
- `student_blitz_attempt_start_controller_test.dart:211-350` covers uncertain-outcome Retry for
  normal Start and Resume #1 only.
- `teacher_blitz_question_builder_controller_test.dart:93-121` fakes a `409 result_pair_locked`
  that the real data source cannot produce; no test covers a confirmed pair with `lockedAt` whose
  Blitz side is this Draft/Scheduled Blitz.
- `teacher_blitz_section.dart:18-19` still says lifecycle actions belong to later tasks.

## 5. Exact Implementation Contract

### 5.1 `P2-1` — the baseline starts at adoption

- `StudentBlitzCountdownAnchor` carries the monotonic elapsed-time reference of its adoption: a
  `Stopwatch` that the application controller starts at the moment it publishes the server
  snapshot the anchor is built from.
  - Execution: `StudentBlitzExecutionController` starts it when it publishes an Attempt or accepts a
    newer detail snapshot.
  - Pre-Start: `StudentBlitzDetailController` starts it when it publishes a detail snapshot. The
    detail state exposes it, and `studentBlitzPreStartAnchor` uses it.
- Equality and `hashCode` stay value-based over `subjectId`, `deadlineAt`, `serverNow` and
  `remainingSeconds` only.
- Publishing a snapshot equal to the current anchor keeps the existing anchor instance and its
  reference. A rebuild or a republished equal snapshot never restarts the baseline.
- `StudentBlitzCountdown` computes `max(0, remainingSeconds - reference.elapsed.inSeconds)` from the
  anchor's reference and never starts a baseline of its own. `Timer.periodic` still only schedules
  recomputation, and `onExpired` still fires once per anchor. If the first computation after build
  is already 0, the existing post-frame expiry report applies.
- The stopwatch factory moves to the application layer, because controllers must not import
  presentation. The provider keeps its name `studentBlitzStopwatchFactoryProvider` and its
  default `Stopwatch.new`. Tests keep overriding it with the fake clock.

### 5.2 `FE-D1 = B` — one detail re-read when the app becomes visible again

- `StudentBlitzDetailScreen` owns an `AppLifecycleListener`. On `onShow` (the app becomes visible
  after being hidden) it calls `StudentBlitzDetailController.refresh()` once. `refresh()` already
  ignores the call while a read is in flight or the session no longer owns the route.
- Focus-only changes (`inactive` ↔ `resumed` without `hidden`) trigger nothing.
- The listener is disposed with the screen.
- Returning to the app never sends a POST, never replays the completed Start request, never
  generates a key, and does not change any other detail handling. The existing rules decide the
  result:
  - The pre-Start anchor comes from the newly published detail (§5.1).
  - The execution controller re-anchors only from a strictly newer `serverNow` with the same
    deadline and positive remaining, and not after local expiry (unchanged rule).
  - A detail showing the Attempt no longer in progress follows the existing completed-Start replay
    path.

### 5.3 `P3-1` — uncertain Retry for every intent

Parameterize or extend the uncertain-outcome group in
`student_blitz_attempt_start_controller_test.dart` over `start_replacement` and Resume of Attempt
#2. After each unknown outcome, the explicit Retry resends the identical request object, the same
body and the same Idempotency-Key, and nothing else.

### 5.4 `P3-2` — route-owner generations

- `TeacherBlitzMonitoringController.enterLiveRoute()` returns an owner generation.
  `leaveLiveRoute([int? ownerGeneration])` does nothing when a generation is given and it is not the
  current owner's. `TeacherBlitzMonitoringScreen` passes the generation it received, including when
  it rebinds in `didUpdateWidget`.
- `TeacherBlitzLifecycleController`, `TeacherOfficialBlitzController` and
  `TeacherBlitzRouteMutationActivityController` gain the same pattern:
  - `enterRoute()` returns a generation;
  - `invalidateRouteCompletions([int?])`, `leaveRoute([int?])` and `endRoute([int?])` do nothing for
    a generation that is not the current owner's.
- `TeacherBlitzDetailScreen` enters on bind and passes its generation on rebind and dispose.
- Calls without a generation keep today's behavior, so existing callers and tests stay valid.
- The pattern follows `TeacherBlitzQuestionBuilderController.enterRoute` / `leaveRoute`. Session,
  lease and generation checks are unchanged.

### 5.5 `P3-3` — realistic pair-lock test

Add a test where the result-pair repository returns a confirmed pair with `lockedAt != null` whose
Blitz side is this whole-group Draft or Scheduled Blitz. Blitz Question authoring stays available
there, and an add and an update each send exactly one request. Keep the existing test unchanged.

### 5.6 `P3-4` — stale comment

Update the doc comment at `teacher_blitz_section.dart:18-19` to the delivered behavior: the section
lists Blitz and links to detail; lifecycle actions live on the Blitz detail screen. Comment only.

### 5.7 Architecture and placement

- Application controllers own the countdown baseline. Presentation reads it.
- Presentation owns the app-lifecycle listener and calls an existing controller method.
- No new package, provider family, request or error code.

## 6. Expected Files and Areas

Production:

```text
frontend/lib/features/student/domain/student_blitz.dart
frontend/lib/features/student/application/student_blitz_countdown_clock.dart   (new: stopwatch factory)
frontend/lib/features/student/application/student_blitz_detail_controller.dart
frontend/lib/features/student/application/student_blitz_detail_state.dart
frontend/lib/features/student/application/student_blitz_execution_controller.dart
frontend/lib/features/student/presentation/student_blitz_countdown.dart
frontend/lib/features/student/presentation/student_blitz_detail_screen.dart
frontend/lib/features/teacher/application/teacher_blitz_monitoring_controller.dart
frontend/lib/features/teacher/application/teacher_blitz_lifecycle_controller.dart
frontend/lib/features/teacher/application/teacher_official_blitz_controller.dart
frontend/lib/features/teacher/application/teacher_blitz_route_mutation_activity.dart
frontend/lib/features/teacher/presentation/teacher_blitz_monitoring_screen.dart
frontend/lib/features/teacher/presentation/teacher_blitz_detail_screen.dart
frontend/lib/features/teacher/presentation/teacher_blitz_section.dart           (comment only)
```

Tests: new focused tests, plus these explicitly allowed mechanical changes to existing tests:

- Tests that construct `StudentBlitzCountdownAnchor` directly may pass the new adoption reference.
  Their assertions stay unchanged.
- Tests that import `studentBlitzStopwatchFactoryProvider` may import it from its new file.

## 7. Acceptance Criteria

- [ ] A snapshot adopted while no countdown is built counts from its adoption. When the countdown is first built after monotonic time T, it already shows `remaining - T`. This holds for an execution anchor and for the pre-Start class anchor, and the tests prove it with the fake clock.
- [ ] A rebuild, a republished equal snapshot or a re-mounted countdown never restarts the baseline. Only a strictly newer snapshot re-anchors.
- [ ] `hidden → shown` triggers exactly one detail GET and no POST. `inactive ↔ resumed` alone triggers nothing. A newer snapshot re-anchors the running countdown; an older or equal one does not.
- [ ] Uncertain `start_replacement` and uncertain Resume #2 each Retry with the identical request object, body and key.
- [ ] An older monitoring or detail screen instance leaving its route leaves the newer instance's polling, lease, pending activation key and in-flight completions intact. A call without a generation behaves as before.
- [ ] A locked confirmed pair whose Blitz side is this Draft/Scheduled Blitz does not block Blitz Question authoring.
- [ ] The `teacher_blitz_section.dart` comment matches the delivered behavior.
- [ ] No API, request, DTO, error-code, route or unrelated behavior change. The Homework screens are unchanged.

## 8. Focused Tests and Verification

Run from `frontend/` with the pinned SDK (`./.fvm/flutter_sdk/bin/flutter`, `.../dart`):

```bash
flutter test <new and changed test files>
flutter test test/features/student/student_blitz_countdown_test.dart \
  test/features/student/student_blitz_detail_screen_test.dart \
  test/features/student/student_blitz_execution_screen_test.dart \
  test/features/student/student_blitz_execution_controller_test.dart \
  test/features/student/student_blitz_replay_safety_test.dart \
  test/features/student/student_blitz_attempt_start_controller_test.dart \
  test/features/teacher/teacher_blitz_monitoring_controller_test.dart \
  test/features/teacher/teacher_blitz_monitoring_screen_test.dart \
  test/features/teacher/teacher_blitz_lifecycle_controller_test.dart \
  test/features/teacher/teacher_blitz_lifecycle_screen_test.dart \
  test/features/teacher/teacher_official_blitz_controller_test.dart \
  test/features/teacher/teacher_blitz_detail_screen_test.dart \
  test/features/teacher/teacher_blitz_routing_screen_test.dart \
  test/features/teacher/teacher_blitz_question_builder_controller_test.dart
flutter analyze --no-pub lib/features/student lib/features/teacher
dart format --output=none --set-exit-if-changed <changed Dart files>
git diff --check
```

Deliberate-break checks must cover:
- the widget starting its own baseline;
- a republished equal snapshot restarting the baseline;
- a missing `onShow` refresh;
- a refresh on focus-only changes;
- an owner-generation check removed from each of the four controllers.

## 9. Evidence Invalidation for Phase 2 Run #2

This fix changes shared Student execution/countdown runtime and shared Teacher route controllers, so
it invalidates the run #1 full-suite, analyze, format and both build results. `S08-FE-PHASE-2` run #2
reruns §§7-12 once on the new `main`, plus a targeted read-only re-review of the fix diff and of
§§29, 30, 36, 39 and 44. The other run #1 area results stay valid unless the fix diff touches them.

## 10. Delivery

Branch `fix/stage8-fe-phase2-fix-001`, one commit, PR to `main` with the verification evidence in
the description. Project Owner merges.

## 11. Planning Provenance

`S08-FE-PHASE-2` run #1 record and Project Owner decisions `FE-D1`, `FE-D2`, in
`tasks/STAGE_08_TASK_INDEX.md` §18.
