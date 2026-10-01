# Implementation Contract: S09-FE-004B — Student Finished Blitz List

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-FE-004B` (second and last part of the planned `S09-FE-004`) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Frontend` (Student) |
| Status | `Approved` |
| Depends on | `S09-FE-004A` — delivered (PR #309, `main` `c1082e5`) |
| Implementation baseline | `origin/main` `c1082e5` |
| Decisions applied | `S09-D3` (release rules), `S09-D4` (an approved exception invalidates Attempt 1), `S09-D5` (Blitz results only after the close), `S09-T3` (scores shown with one decimal) |
| Backend contract | `S09-DOC-001` §12, delivered by `S09-BE-007C` (`tasks/backend/stage-09/S09-BE-007C-student-finished-blitz.md` §5) |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |

This file is the complete task contract.

## 2. Goal

The Student sees their finished Blitz tasks on the workspace. Each one shows its released score and the Teacher's feedback. When there is no score, it says why.

## 3. Backend Contract (read from the code)

`GET /api/v1/student/blitz/finished` takes the query parameters `page` (≥ 1) and `per_page` (1..100) and no body. Anything else is `422`.

It returns `200` with `{"data": [items], "meta": {"pagination": {"page", "per_page", "total", "last_page"}}}`. The items are ordered by close time, newest first.

Each item has exactly these keys:

| Key | Value |
|---|---|
| `id` | UUID |
| `topic` | `{id, title}` |
| `title` | string |
| `status` | `closed` or `archived` |
| `closed_at` | UTC timestamp. It is never null here: an activated Blitz is closed before it can be archived (`CloseTeacherBlitz`, `ArchiveTeacherBlitz`, `blitz_tasks_lifecycle_check`) |
| `attempt_exception` | true when an approved exception exists for the Student |
| `result` | `null`, or `{attempt_number, visible, normalized_score, feedback}` |

Rules for `result`:
- It is `null` when no Attempt counts: the Student never started, or the replacement was not taken.
- Otherwise it describes the counting Attempt: number 2 when `attempt_exception` is true, otherwise 1.
- `visible` is true when the Attempt is `checked` and eligible, and the release mode is `automatic`.
- `normalized_score` is a number from 0 to 100 when visible, and `null` otherwise.
- `feedback` is `[]` unless visible. Otherwise it is `[{question_id, position, text}]` in Question position order, with non-empty text.

Errors: session errors and `422`.

## 4. Scope

### 4.1 Domain and parsing

New file `domain/student_finished_blitz.dart` with:
- `StudentFinishedBlitzStatus` (`closed`, `archived`);
- `StudentFinishedBlitzFeedback` (`questionId`, `position`, `text`);
- `StudentFinishedBlitzResult` (`attemptNumber`, `visible`, `normalizedScore`, `feedback`);
- `StudentFinishedBlitz` (`id`, `topic` as the existing `StudentBlitzTopicSummary`, `title`, `status`, `closedAt`, `attemptException`, `result`);
- `StudentFinishedBlitzPage` (`items`, `page`, `perPage`, `total`, `lastPage`).

`StudentFinishedBlitzPageDto.fromJson(json, page:, perPage:)` parses strictly. Any violation is a `FormatException`.
- **Keys and types:** exact keys at every level, canonical ids, the status enum, and UTC timestamps.
- **Item rules:**
  - `closed_at` is required for both statuses;
  - the result's Attempt number matches `attempt_exception`;
  - visible ⇔ a score in 0..100, and hidden ⇒ no score and no feedback;
  - feedback has unique canonical Question ids, positions ≥ 1 in ascending order, and non-empty text.
- **Page rules:** unique item ids, and pagination consistent with the request, as `StudentHomeworkListDto` does.

### 4.2 Data

- `StudentBlitzRemoteDataSource.fetchFinishedBlitz({required int page, required int perPage})` sends `GET /student/blitz/finished?page=&per_page=` with `followRedirects: false` and requires `200`.
- `StudentBlitzRepository.fetchFinishedBlitz({page, perPage})` returns the page.

### 4.3 Controller

`studentFinishedBlitzControllerProvider` is an `autoDispose` provider, not keyed, because the list is global for the Student. It follows `StudentActiveBlitzController`:
- the session handling;
- the generation guard;
- session failures clear it, and run `bootstrap()` except for `authentication_required`;
- a failed refresh keeps the page as stale.

Details:
- The page size is 5. It loads page 1 on build.
- State: `status` (`initial`, `loading`, `data`, `refreshing`, `error`), `page`, `failure` and `isStale`.
- Actions:
  - `refresh()`, which reloads the current page;
  - `retry()`, which repeats the latest request, so a failed page change is retried on the page that was asked for;
  - `nextPage()` and `previousPage()`, which are ignored while a request is in flight or at either end.
- A later request supersedes an earlier one.

### 4.4 Screen

`StudentFinishedBlitzSection` is a card with key `studentFinishedBlitzSection`. It sits on the Student workspace right after `Active Blitz` and before My Topics, on every surface.

**Header.** The heading `Finished Blitz` has header semantics. A refresh `IconButton` has key `studentFinishedBlitzRefreshButton` and tooltip `Refresh finished Blitz tasks`. It is disabled while a request is in flight.

**States.**

| State | Content |
|---|---|
| loading | `Loading finished Blitz tasks`, key `studentFinishedBlitzLoading` |
| error without data | `Finished Blitz tasks could not be loaded.`, a failure message, and `Retry` (key `studentFinishedBlitzRetryButton`) |
| refreshing | A `LinearProgressIndicator` with semantics label `Refreshing finished Blitz tasks` |
| stale | `The finished Blitz list may be out of date.` and `Retry` (key `studentFinishedBlitzStaleRetryButton`), key `studentFinishedBlitzStale` |
| empty | `No finished Blitz tasks yet.`, key `studentFinishedBlitzEmpty` |

**Pagination.** `Previous` (key `studentFinishedBlitzPreviousButton`), `Page <p> of <n>` and `Next` (key `studentFinishedBlitzNextButton`).

**Failure messages.**

| Failure | Message |
|---|---|
| connection | `Could not reach the server.` |
| timeout | `The finished Blitz request timed out.` |
| invalid response | `The server returned an unexpected finished Blitz response.` |
| anything else | `Try again.` |

Raw failure text is never shown.

**Item card.** The card has key `studentFinishedBlitzCard<id>` and has no open button: a finished Blitz cannot be opened (`409 blitz_not_active`).

| Part | Content |
|---|---|
| Title | the title |
| Topic | `Topic: <topic title>` |
| Closed | `Closed <Institution time>`, or `Closed Institution timezone unavailable` when the time zone cannot be resolved; `Archived` is added as a chip for archived tasks |
| Exception | `Attempt 1 was invalidated.` when `attemptException` |
| Result line | key `studentFinishedBlitzResult<id>`, as below |

Result line:

| Case | Text |
|---|---|
| visible | `Score <one decimal>` |
| hidden | `Result not available yet` |
| no result, no exception | `No attempt counts for this Blitz.` |
| no result, with an exception | `No replacement attempt was taken.` |

**Feedback.** When feedback exists, the card shows the label `Teacher feedback` and one `SelectableText` line per entry: `Question <position>: <text>`. The block has key `studentFinishedBlitzFeedback<id>`.

### Non-goals

- No route or screen for a single finished Blitz.
- No change to the Active Blitz section or the Blitz detail.
- No backend change.

## 5. Tests

- **DTO.**
  - A full page with every result shape: visible with feedback, hidden, null, and exception.
  - Rejected:
    - an extra or missing key at each level;
    - an unknown status;
    - `closed` without `closed_at`;
    - a wrong Attempt number;
    - visible without a score, or hidden with a score or feedback;
    - a score outside 0..100;
    - feedback with a duplicate id, a position out of order or below 1, or empty text;
    - duplicate items;
    - pagination contradictions.
- **Data source.** The path and query, `followRedirects: false`, `200`, and a format failure as an invalid response.
- **Controller.**
  - Load page 1.
  - Next and previous.
  - Ignored at the ends and while in flight.
  - Refresh keeps the page.
  - A failed refresh is stale.
  - Error and retry.
  - Session failures.
  - A session change drops the completion.
- **Section.**
  - Each result line, the exception line and the feedback block.
  - `S09-T3` rounding.
  - Loading, error with retry, stale, empty and pagination.
  - The placement between `Active Blitz` and My Topics.
  - A mobile layout check.

Review corrections (independent review: P1 = 0, P2 = 0, P3 = 7):
- the pagination is validated before `last_page` is computed, so a page size of 0 is a format error;
- feedback positions must strictly ascend, and `closed_at` is required for archived tasks too;
- `retry()` repeats the latest request, so a failed page change retries the page that was asked for;
- the close time falls back to `Institution timezone unavailable`, like the Homework card;
- `readStudentBool` is shared by both Blitz parsers; the stale Retry button has a key;
- tests cover every session code, the score bounds, the total checks, the keys, the stale Retry and a
  failed page change.

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
