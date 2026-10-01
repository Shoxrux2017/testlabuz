# Implementation Contract: S09-FE-004A — Student Homework Results and Feedback

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-FE-004A` (first part of the planned `S09-FE-004`) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Frontend` (Student) |
| Status | `Approved` |
| Depends on | `S09-FE-003C` — delivered (PR #308, `main` `473d8a0`) |
| Implementation baseline | `origin/main` `473d8a0` |
| Decisions applied | `S09-D3` (what a Student may see, and when), `S09-T3` (scores shown with one decimal) |
| Backend contract | `S09-DOC-001` §12, delivered by `S09-BE-007B`; the Student parser already shipped with it |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |

`S09-FE-004B` (the finished Blitz list) follows. This file is the complete task contract.

## 2. Goal

The Student sees their released Homework results:
- the official score on the Homework list and the Homework detail;
- each finished Attempt with its own score, which can be opened;
- the Teacher's feedback under each answer.

## 3. Backend Contract (already parsed)

`S09-BE-007B` changed these Student responses. The Flutter parsers and domain types shipped with it.

- **Homework summary and detail.**
  - `scoreVisible`, and `officialScore` (`normalizedScore`, `attemptNumber`).
  - `officialScore` is non-null exactly when `scoreVisible` is true. That happens when:
    - the Homework is the Topic's official one;
    - its official score is ready;
    - the release mode is `automatic`.
- **Homework detail.** `attemptResults`: every terminal Attempt in Attempt-number order, with `attemptId`, `attemptNumber`, `status` and `result` (`visible`, `normalizedScore`).
- **Homework Attempt.**
  - `result` (`visible`, `normalizedScore`).
  - Each answer's `feedback`, which is non-null only when the result is visible and the Teacher wrote feedback.
- **Visibility.** An Attempt result is visible when:
  - the Attempt is `checked`;
  - it is eligible for the official score;
  - the release mode is `automatic`.
- **Never shown to a Student:**
  - correct answers;
  - points per Question;
  - per-answer checking status;
  - the reviewer.

## 4. Scope

Scores use `formatScoreOneDecimal` (`lib/core/scoring/score_display.dart`).

### 4.1 Homework list

Each Homework card gets one more line when `officialScore` is set: `Official score: <score>`, key `studentHomeworkOfficialScore<homeworkId>`. Nothing else changes.

### 4.2 Homework detail

A `Results` card, key `studentHomeworkResultsCard`, comes right after the `Attempt information` card. It is shown when `attemptResults` is not empty; the parser accepts an official score only together with its visible Attempt result. Its heading `Results` has header semantics.

| Part | Content |
|---|---|
| Official score | `Official score: <score> (Attempt <n>)`, key `studentHomeworkOfficialScore`, when set |
| One row per Attempt result | Key `studentHomeworkAttemptResult<attemptId>`. `Attempt <n> · <status label> · Score <score>` when visible; otherwise `Attempt <n> · <status label> · Result not available yet`. The status label comes from `studentHomeworkAttemptStatusLabel` |
| Open button per row | `OutlinedButton` `Open attempt <n>`, key `studentHomeworkOpenAttempt<attemptId>`. It goes to `studentHomeworkAttemptLocation(topicId, homeworkId, attemptId)` after recreating the retained Attempt route providers, as Resume does. It is disabled while the detail refreshes or an Attempt start is in flight |

### 4.3 Homework Attempt screen (terminal Attempts)

- **Result.** `StudentAttemptFinalizationSummary` gains a `Result` field, key `studentHomeworkAttemptResult`:
  - `Score <score>` when the result is visible;
  - otherwise `Not available yet`.
- **Teacher feedback.** Under each Question whose saved answer has feedback, show:
  - the label `Teacher feedback`;
  - the feedback as `SelectableText`, key `studentAttemptFeedback<questionId>`.

  This applies to every answer type, file answers included.

### Non-goals

- No finished Blitz list; that is `S09-FE-004B`.
- No change to Blitz screens.
- No Parent view, no backend change, no parser change.

## 5. Tests

- **Homework list.** The official score line with a score that only `S09-T3` rounding shows correctly. No line without an official score.
- **Homework detail.**
  - The card with the official score.
  - Visible and hidden Attempt rows.
  - Opening an Attempt goes to its route.
  - The button is disabled while refreshing, and while an Attempt start is submitting or uncertain.
  - Opening recreates the retained Attempt route providers.
  - No card without results.
  - The heading semantics.
- **Attempt screen.**
  - The visible and hidden result.
  - Feedback under a text answer and a file answer.
  - No feedback block without feedback.

Review corrections (independent review: P1 = 0, P2 = 0, P3 = 5):
- Open now recreates the retained Attempt route providers, through the helper Resume uses;
- Open is also disabled while an Attempt start is in flight;
- the feedback key uses the Question id as is, like its sibling keys;
- the feedback test asserts its position and `SelectableText`;
- the test data is consistent with the parser, and the detail's official score line is pinned to
  `S09-T3` rounding; the card no longer has a branch for an official score without Attempts.

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
