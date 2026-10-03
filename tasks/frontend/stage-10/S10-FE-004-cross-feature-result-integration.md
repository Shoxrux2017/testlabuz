# Implementation Contract: S10-FE-004 — Cross-Feature Result Integration

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S10-FE-004` |
| Stage | `Stage 10 — Final Result and Understanding Assessment` |
| Area | `Frontend` (Teacher, cross-feature) + docs alignment |
| Status | `Approved` |
| Depends on | `S10-FE-003` on `main` `b204628` |
| Owner decisions applied | `S10-D7`, `S10-D8`, `S09-CL-D1` (carried `CL9-5`), `S10-FE-D1` |
| Implementation | Claude |
| Delivery | Claude opens the PR and merges it after review `PASS` and green verification |
| Blocks | `S10-FE-005` |

Normative sources: `docs/04:1058-1069`, `3248-3256` (activation warning); `docs/09` §§19.1, 13.9, 25.10, 25.11,
21.1 (review queue query); `docs/03:255-257`; frontend plan (index §7 row `9`).

## 2. Goal

The Stage 10 rules reach the existing Teacher screens: the official Blitz activation warns about closing the
official Homework, the Topic archive warns that results close, a review correction of a closed result is
explained, results views reload after the actions that change them, and the review queue gains the Topic, group
and Student filters carried from Stage 9 (`CL9-5`), including a link from a result to that Student's submissions.

## 3. Scope

Included: §5.1-§5.6. Non-goals: list or search pickers for the queue filters (filters come from rows and the
result link); the results card `404` wording (`S10-FE-002` record); any backend change.

## 4. Current Context

- Blitz activation: `TeacherBlitzLifecycleControls` (`_confirm` with an optional mobile `note`),
  `TeacherBlitzLifecycleController` (`_conflictMessage`, `_publishSuccess` refreshes the Blitz list and the pair),
  activation `409` whitelist in `teacher_blitz_remote_data_source.dart`; the official pair gives the official
  Homework id; `teacherHomeworkDetailControllerProvider` reads one Homework.
- Topic archive: `teacher_topic_detail_screen.dart` dialog copy; `TeacherTopicLifecycleController._publishSuccess`.
- Review save: `teacher_submission_remote_data_source.dart` (`409` whitelist `automatic_checking_pending`),
  `TeacherSubmissionReviewController` (`_publishDefiniteFailure`, `_refreshRelatedViews`).
- Review queue: `TeacherSubmissionListQuery` (task scope `topicId`/`assessmentId`, filters), `TeacherReviewQueueScope`
  (`all`, `task`), `TeacherReviewQueueScreen`; rows carry Topic, group and Student ids and names.
- Results: `teacherTopicResultListControllerProvider` / `teacherTopicResultDetailControllerProvider` with
  `refreshAfterAction(owner)`.

## 5. Exact Contract

### 5.1 Official Blitz activation (`S10-D8`), desktop and mobile

- When the pair confirms this Blitz is the official Blitz, the activation confirmation adds a note from the
  official Homework's status (read with the Homework detail controller, re-read when the confirmation opens; the
  open note follows that read):

| Official Homework | Note |
|---|---|
| active | "This is the official Blitz. Activating it closes the official Homework for the whole group. Homework Attempts still in progress are submitted with their saved work. Students without a submitted Homework Attempt cannot take this Blitz." |
| draft | "The official Homework is still a draft. Activate it first; this Blitz cannot be activated before it." |
| closed / archived | "This is the official Blitz." |
| not confirmed | "This is the official Blitz. If the official Homework is still active, activating it closes the Homework for the whole group, submits Attempts still in progress with their saved work, and Students without a submitted Homework Attempt cannot take this Blitz." |

  The existing mobile notes for a Blitz that is not official or not confirmed stay as they are.
- `409 official_homework_not_activated` is a definite activation conflict: "The official Homework is still a
  draft. Activate the official Homework before this Blitz." and the official pair and Homework views reload.
- After a confirmed activation the Topic's Homework list, the official Homework detail and the Topic results
  list reload when they are open.

### 5.2 Topic archive (`S10-D7`)

The archive confirmation reads: "The Topic content is retained as historical read-only data. Archiving also
closes every calculated or Not completed Topic result for good; results still waiting stay open." After a
confirmed archive, and when a reconcile finds the Topic archived, the Topic results list (the entry card) reloads.

### 5.3 Review save on a closed result (`S10-T7`)

`409 result_closed` is a definite review-save failure: "This Student's Topic result is closed, so reviewed
answers can no longer be corrected. Answers still waiting for review can be reviewed." The drafts stay and the
related views reload. Every refresh of related views after a review save also reloads that Student's queue of
the Topic (§5.4), the Topic results list and that Student's result detail when they are open.

### 5.4 Review-queue filters (`CL9-5`), desktop

- `TeacherSubmissionListQuery` gains `groupId` and `studentId` (`group_id`, `student_id`), and the global queue
  may filter by `topicId`.
- Every queue row has a "Filter by" menu: "Only this Topic" and "Only this group" (only where the queue does not
  fix the Topic, whose one group it then fixes too), "Only this Student" (not in a Student queue). Active filters show as removable chips "Topic: …", "Group: …", "Student: …"; a change starts at page
  1; Clear filters removes them.
- The result detail (desktop) offers "Open submissions": the route `/teacher/topics/:topicId/results/:studentId/reviews`
  (`teacher-topic-result-reviews`, desktop only; mobile redirects to the result detail; kept during desktop
  bootstrap) shows that Student's submissions of the Topic, every status by default; Back returns to the result.

### 5.5 Docs

`docs/02`, `docs/03`, `docs/04` describe the Topic, group and Student filters and the result link; `docs/06`
records `CL9-5` as delivered.

### 5.6 Tests

Activation note per Homework status on both surfaces, the new conflict and the reloads; archive copy and reload;
review `result_closed` message, drafts kept, results reloads; query parameters, row filter menu, chips, page reset,
clear, scope route helpers and redirects, result-detail link and Back.

## 6. Verification

```text
flutter test test/features/teacher test/router_bootstrap_test.dart; flutter analyze --no-pub lib test;
dart format --output=none --set-exit-if-changed lib test; git diff --check
```
