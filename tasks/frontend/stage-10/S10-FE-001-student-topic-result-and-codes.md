# Implementation Contract: S10-FE-001 — Student Topic Result and Stage 10 Error Codes

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S10-FE-001` |
| Stage | `Stage 10 — Final Result and Understanding Assessment` |
| Area | `Frontend` (Student) |
| Status | `Approved` |
| Depends on | Stage 10 backend (`S10-BE-001` … `004`, `PHASE-2`, `PHASE-2-FIX-001`) on `main` `15c9a71` |
| Owner decisions applied | `S10-D2` (what the Student sees), `S10-D3` (window), `S10-D4`, `S10-D8` (Blitz Start bar) |
| Implementation | Claude |
| Delivery | Claude opens the PR and merges it after review `PASS` and green verification |
| Blocks | `S10-FE-002` |

Normative sources: `docs/09` §§29.3, 29.5, 20.3 (Homework before Blitz), 17.3, 5.1; `docs/04` Student result
flows (1560-1575, 2361-2373, 1521); `docs/02:452-479`; `S10-DOC-001` §14.1.

## 2. Goal

The Student sees the Topic result on the Topic detail page exactly as the server allows, and gets clear
messages for the two new Student conflicts. The client knows all seven Stage 10 error codes.

## 3. Scope

Included: §5.1-§5.5. Non-goals: any Teacher screen (`S10-FE-002`…`004`); a Topic-list result badge (the list
API has no result field); any Parent screen (Stage 11); announcing the Homework-before-Blitz rule before
Start (`docs/04:1521`: the Student learns it from the `409`); any backend change.

## 4. Current Context

- `StudentTopicRepository` (`fetchTopics`, `fetchTopic`), `StudentTopicRemoteDataSource` (envelope
  `{data}`, `_mapFailures`), `StudentTopicDetailController` (autoDispose family on `topicId`, session key,
  generation, session-failure bootstrap), `StudentTopicDetailScreen` (header card → information → group →
  materials → `StudentHomeworkSection`), DTO helpers in `student_dto_parse.dart`, `formatScoreOneDecimal`.
- Fakes: `FakeStudentTopicRepository` in `test/features/student/student_test_support.dart` and a second one
  in `test/router_bootstrap_test.dart`.
- `studentBlitzStartFailureMessage`, `studentHomeworkStartFailureMessage` and the Homework start controller's
  reconcile switch have no Stage 10 codes; `ApiErrorCodes` lacks all seven.

## 5. Exact Contract

### 5.1 Error codes

Add to `ApiErrorCodes`: `result_closed`, `result_not_ready`, `result_not_ready_for_closure`,
`student_result_not_released`, `manual_release_not_allowed`, `official_homework_not_activated`,
`homework_not_submitted`. The Teacher mappings come in `S10-FE-003`/`004`.

### 5.2 Data

`GET /student/topics/{topic}/result` through `StudentTopicRepository.fetchTopicResult(topicId)` returning
`StudentTopicResult?` (null for `{"data": null}`); the repository rejects a `topic_id` other than the request.
Strict DTO (`readExactStudentMap`, the eleven keys) with these invariants, otherwise `FormatException`:

| Field | Rule |
|---|---|
| `result_status` | one of the seven statuses |
| `closed_outcome` | non-null (`calculated`/`not_completed`) exactly when the status is `closed` |
| `missing_component` | non-null (`homework`/`blitz`/`both`) exactly when the result is Not completed (open, or closed as `not_completed`) |
| `visible` | bool; true only for `calculated`, `not_completed` or `closed` |
| value fields | all null when not visible |
| visible calculated (open or closed) | both side scores, final score and method non-null; category one of the four numeric codes |
| visible Not completed | final score and method null; category `not_completed`; the missing side's score null |
| scores | finite numbers 0-100 |
| `category` | null or exactly `{code, label}`, code one of the five, label non-blank |
| `teacher_comment` | null or a non-blank string |

### 5.3 Topic result section

A `StudentTopicResultSection(topicId)` card right after the header card of the Topic detail page (desktop and
mobile), with its own controller (autoDispose family on the lowercase `topicId`, the Topic detail ownership
pattern) and its own Refresh button. Texts:

| Case | Shown |
|---|---|
| loading / error | progress / "The Topic result could not be loaded." with Retry |
| no result (`data: null`) | "No Topic result is available yet." |
| status label | Waiting for Homework · Waiting for Blitz · Waiting for Teacher review · Being prepared (`waiting_for_settings`) · Calculated · Not completed · Final (closed calculated) · Not completed (final) (closed Not completed) |
| missing component | "Missing: Homework" / "Missing: Blitz" / "Missing: Homework and Blitz" |
| hidden values, outcome status | "The result is not open yet." (never presented as incomplete) |
| hidden values, waiting status | "Scores appear when the result is ready." |
| visible | Homework score, Blitz score, Final score (each only when present, one decimal via `formatScoreOneDecimal`); method line "The final score is the average of the Homework and Blitz scores." / "The final score is the Blitz score."; Category (server label); "Teacher's comment" when present |

Never shown: D, T, consistency, `category_score`, the word "inconsistent".

### 5.4 Student conflicts

- Official Blitz Start `409 homework_not_submitted`: "This Blitz can only be started after the Topic's
  Homework was submitted." (no reconcile; Start remains, the server decides).
- Homework Start `409 result_closed`: "Your Topic result is closed, so a new Homework attempt cannot be
  started." and the Homework detail is re-read.

### 5.5 Tests

DTO (every invariant and each status), data source (path, envelope, null data, status), repository id check,
controller (load, refresh, stale result after session change, session failure, error), section widget (each
status, hidden/visible, Not completed per missing side, closed outcomes, comment, no D/T text, narrow 360 px
and text scaling), Topic detail placement, the two Student conflict messages, and the existing tests whose
fakes implement `StudentTopicRepository`.

## 6. Verification

```text
flutter test test/features/student (and router_bootstrap_test.dart); flutter analyze --no-pub lib test;
dart format --output=none --set-exit-if-changed lib test; git diff --check
```
