# Implementation Contract: S10-BE-001 — Topic Result Foundation

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S10-BE-001` |
| Stage | `Stage 10 — Final Result and Understanding Assessment` |
| Area | `Backend` (no new endpoint, no response-shape change; one validation tightening) |
| Status | `Approved` |
| Depends on | `S10-DOC-001` delivered (PR #316, `main` `cc7a05f`) |
| Implementation baseline | `origin/main` `cc7a05f` |
| Owner decisions applied | `S10-D6` (open results use current settings), `S10-D8` (Blitz side for a Student without Homework), `S10-D9` (closable) |
| Technical decisions applied | `S10-T1` (live results), `S10-T2` (no reference to `official_task_scores`), `S10-T3` (Not completed, precedence), `S10-T4` (`waiting_for_settings`), `S10-T5` (precision) |
| Carried items | `PH2-4` (rule consolidation), `CL9-11` (hardening) |
| Implementation | Claude |
| Delivery | Claude opens the PR and merges it after review `PASS` and green verification (Stage 10 process) |
| Blocks | `S10-BE-002`, `S10-BE-003`, `S10-BE-004` |

This file is the complete task contract.

## 2. Goal

Everything a Stage 10 endpoint needs to show a Topic result, without any endpoint yet: the `topic_results`
table, the pure calculation, and one live reader that computes every cohort Student's result from the
current Attempts, official scores, task lifecycle and Institution settings with a constant number of
queries. Two carried Stage 9 items are closed on the way.

## 3. Scope

### Included

1. `PH2-4`: one Blitz counting-Attempt rule, the Blitz condition inside `StudentResultVisibility`, one
   official-designation query (§5.1). Behavior unchanged.
2. `CL9-11`: non-empty stored answer feedback; Teacher text fields that are blank after Unicode
   whitespace trimming are rejected (§5.2).
3. Migration, model, enums and factory for `topic_results` (§5.3).
4. Pure domain: `TopicResultMath`, `TopicResultCalculator` (§5.4).
5. Live reader `TopicResultReader` with side states, status, work finished and closable (§5.5).

### Non-goals

- No endpoint, resource or response change; no visibility or release logic (`S10-BE-003`); no write
  to `topic_results` outside the factory (`S10-BE-002`…`004`).
- No change to the Stage 9 official-score rules, the resolver, the sweep, or any lock order.
- No change to answer-feedback trimming (the Teacher client confirms saves by exact equality with the
  PHP `trim` result).

## 4. Current Implementation Context

- `OfficialScoreEvaluator` (`app/Support/Checking`) evaluates one recipient; its Blitz branch queries the
  exception itself and asserts the Attempt graph. `OfficialScoreReader::read` adds per-recipient queries
  (Attempts, official row, exception, Blitz status) and maps to `OfficialScoreStatus`.
- `ListStudentFinishedBlitz::countingAttempt` picks #2 when an exception exists, else #1, with looser
  checks than the evaluator.
- `StudentResultVisibility::visible(attempt, released)` leaves the Blitz closed/archived condition to the
  caller's query (`StudentBlitzAccess::finishedQuery`).
- `RepairOfficialTaskScores` builds its own official-assessment subquery (`:63-66`).
- `StudentAnswerText::isEmpty` and `AnswerTextNormalizer::WHITESPACE_RUN` hold the same Unicode
  whitespace class twice (it equals Dart's `String.trim()` set).
- Teacher requests trim with PHP `trim` (ASCII). Backend accepts these Unicode-whitespace-only values
  that the frontend parsers reject: Question `prompt`, choice `options[].text`, short-written
  `accepted_answers[]`, matching `pairs[].left`/`right`, ordering `items[].text`, fill-in-blank
  `blanks[].accepted_answers[]` (all validated in `QuestionConfigurationValidator`), Homework/Blitz
  `title` and `student_instructions` (mutation requests and `AssessmentActivationValidator`), Blitz
  exception `reason`.
- `attempt_answers.feedback` has no check; the only writer turns `''` into null.
- `CheckingScoreMath` (brick/math, scale 8, half-up) has no difference or average.
- Homework Attempts are always `official_score_eligible`; a Student has at most three.

## 5. Exact Contract

### 5.1 `PH2-4` consolidation (no behavior change)

- **Blitz counting Attempt.** `OfficialScoreEvaluator::countingBlitzAttempt(attempts, ?exception)`
  selects it: no exception → #1; exception → #2 or null; it keeps the evaluator's graph assertions
  (`LogicException` on an inconsistent graph). The evaluator's Blitz branch and
  `ListStudentFinishedBlitz` use it; the finished list passes its already loaded exception, whose eager
  load (`StudentBlitzAccess::finishedQuery`) now also selects `invalidated_attempt_id`.
- **Preloaded evaluation.** `OfficialScoreEvaluator::evaluateLoaded(task, recipient, attempts, ?exception)`
  and `OfficialScoreReader::readLoaded(task, recipient, attempts, ?officialRow, ?exception, ?blitzStatus)`
  evaluate without queries (the answers of waiting Attempts are preloaded by the caller); `evaluate()` and
  `read()` keep their public behavior and load that data themselves.
- **Designation.** `OfficialTaskDesignation::officialTaskKeys()` is the official-task subquery that
  `RepairOfficialTaskScores` uses instead of its own. In-PHP pair comparisons inside lock helpers stay.
- **Visibility.** `StudentResultVisibility::visible(attempt, task, released)` decides the Blitz condition
  itself: a Blitz Attempt is visible only when its loaded Blitz task is closed or archived. The release
  input stays `automatic` only (Stage 10 release arrives in `S10-BE-003`).

### 5.2 `CL9-11` hardening

- `App\Domain\Text\UnicodeWhitespace` holds the one character class (U+0009–U+000D, U+0020, U+0085,
  U+00A0, U+1680, U+2000–U+200A, U+2028, U+2029, U+202F, U+205F, U+3000, U+FEFF) as `CHARACTER_CLASS`,
  with `isBlank()` and `blankAsEmpty()`; `StudentAnswerText` and `AnswerTextNormalizer` use it (their
  behavior unchanged). The Unicode trim of the Topic-result comment arrives with the comment (`S10-BE-002`).
- Every field in §4's list is rejected when `UnicodeWhitespace::isBlank(trim(value))`, with the error the
  same request already returns for an ASCII-blank value: the requests map such a value to `''` before
  validation, and `QuestionConfigurationValidator` (whose text check also covers the matching
  `client_key`, which is never stored) rejects it in its blank check. Stored values are not changed.
  Activation keeps rejecting a stored blank title or instructions with its existing error.
- The migration adds `attempt_answers_feedback_not_empty_check`: `feedback is null or feedback <> ''`.

### 5.3 `topic_results` persistence

Migration `2026_10_04_000000_create_stage_10_topic_result_foundation.php` (the single Stage 10
migration) creates the table and the §5.2 check; `down()` drops both.

Columns (in this order): `id` uuid PK; `institution_id`, `topic_id`, `student_id` uuid not null;
`teacher_comment` text; `teacher_comment_updated_by_user_id` uuid; `teacher_comment_updated_at`
timestamptz; `student_released_at` timestamptz; `student_released_by_user_id` uuid;
`parent_released_at` timestamptz; `parent_released_by_user_id` uuid; `closed_at` timestamptz;
`closed_by_user_id` uuid; `closure_reason` varchar(20); `closed_outcome` varchar(20); `missing_component`
varchar(20); `homework_assessment_id`, `blitz_assessment_id` uuid; `homework_state`, `blitz_state`
varchar(30); `homework_attempt_id` uuid; `homework_score` numeric(12,8); `blitz_attempt_id` uuid;
`blitz_score` numeric(12,8); `score_difference`, `acceptable_difference_used` numeric(12,8);
`calculation_method`, `consistency` varchar(20); `final_score` numeric(12,8); `category_score` smallint;
`category_code` varchar(40); `category_min_score_used`, `category_max_score_used` smallint;
`created_at`, `updated_at` timestamptz not null. Every other column is nullable.

Constraints (names `topic_results_{name}_check|_unique|_tenant_foreign`):

- `unique(topic_id, student_id)`, `unique(institution_id, id)`.
- Foreign keys, all `on delete restrict`: `institution_id` → `institutions`; tenant-safe
  `(institution_id, x)` → `(institution_id, id)` for `topic_id` (`topics`), `student_id` and the four actor
  columns (`users`), `homework_assessment_id`, `blitz_assessment_id` (`assessments`),
  `homework_attempt_id`, `blitz_attempt_id` (`assessment_attempts`).
- Value lists: `closure_reason` (`teacher`, `topic_archived`); `closed_outcome` (`calculated`,
  `not_completed`); `missing_component` (`homework`, `blitz`, `both`); `homework_state` (`ready`,
  `waiting_for_teacher_review`, `checking`, `not_activated`, `open`, `missing`); `blitz_state` (the same
  plus `not_designated`); `calculation_method` (`average`, `blitz`); `consistency` (`consistent`,
  `inconsistent`); `category_code` (the five category codes).
- `teacher_comment is null or (teacher_comment <> '' and char_length(teacher_comment) <= 2000)`;
  the comment actor and time are both null or both set, and set when the comment is set.
- Each release pair (`*_released_at`, `*_released_by_user_id`) is both null or both set.
- Open rows (`closed_at` null): every closure column is null (`closed_by_user_id`, `closure_reason`,
  `closed_outcome`, `missing_component`, both assessment ids, both states, both Attempt ids, every score,
  D, T, method, consistency, final, `category_score`, `category_code`, both range columns).
- Closed rows: `closed_by_user_id`, `closure_reason`, `closed_outcome`, `homework_assessment_id`,
  `homework_state`, `blitz_state` are set; `blitz_assessment_id` is null exactly when `blitz_state =
  not_designated`; for each side the Attempt id and score are set exactly when its state is `ready`.
- `closed_outcome = calculated`: both states `ready`; D, T, method, consistency, final,
  `category_score`, both range columns set; `category_code` one of the four numeric codes;
  `missing_component` null.
- `closed_outcome = not_completed`: `category_code = not_completed`; D, T, method, consistency, final,
  `category_score` and both range columns null; `missing_component` = `homework` exactly when only
  `homework_state = missing`, `blitz` exactly when only `blitz_state = missing`, `both` when both are.
- `(calculation_method = 'average' and consistency = 'consistent') or (calculation_method = 'blitz' and
  consistency = 'inconsistent') or (both null)`.
- Scores, D, T and final between 0 and 100; `category_score` and the range columns between 0 and 100;
  `category_min_score_used <= category_max_score_used`.

Model `App\Models\TopicResult` (casts: `decimal:8` scores, enum casts, `immutable_datetime` times) and
`TopicResultFactory` with states `withComment`, `releasedToStudent`, `releasedToParent`,
`closedCalculated`, `closedNotCompleted` that build consistent rows. Enums in `App\Enums`:
`TopicResultStatus` (seven values), `TopicResultSideState` (seven), `TopicResultMissingComponent`,
`TopicResultCalculationMethod`, `TopicResultConsistency`, `TopicResultClosureReason`,
`TopicResultOutcome`.

### 5.4 Pure domain (`App\Domain\Results`)

`TopicResultMath` (brick/math; inputs are decimal strings on the 0–100 scale with at most 8 decimals, the
exact average up to 9):

- `difference(H, B)`: `|H − B|`, exact (8 decimals); `exceeds(D, T)`: `D > T`.
- `exactAverage(H, B)`: the exact `(H + B) / 2` (up to 9 decimals); `storedScore(exact)`: half-up to 8
  decimals.
- `categoryScore(exact final)`: integer part, plus one when the fractional part is above `.5`
  (85.5 → 85, 85.500000005 → 86, 85.0 → 85, 100 → 100).

`TopicResultCalculator::calculate(homeworkSide, blitzSide, ?T, ?validCategorySet)` returns a
`TopicResultComputation`:

- Status — first match: a side `missing` → `not_completed` with `missing_component` (`homework`, `blitz`,
  `both`); both `ready` with T and a set → `calculated`; both `ready` otherwise → `waiting_for_settings`;
  Homework `not_activated`, `open` or `checking` → `waiting_for_homework`; Blitz `not_designated`,
  `not_activated`, `open` or `checking` → `waiting_for_blitz`; otherwise → `waiting_for_teacher_review`.
- `calculated`: D = difference; `D <= T` → method `average`, consistency `consistent`, final =
  average; else method `blitz`, `inconsistent`, final = B. The comparison uses exact values. The category
  is the numeric band containing `categoryScore(exact final)`.
- Every other status: D, T, method, consistency, final, `category_score` null; category
  `not_completed` for `not_completed`, null otherwise.
- `terminal` = `calculated` or `not_completed`.

### 5.5 Live reader (`App\Support\Results\TopicResultReader`)

`forTopic(Topic $topic): list<TopicResultView>` (ordered by Student id) and `forStudent(Topic $topic, string $studentId):
?TopicResultView`. No locks; callers wrap reads in a `REPEATABLE READ READ ONLY` snapshot (`S10-BE-002`).
The current time comes from the application clock.

- **Cohort.** Empty when the Topic has no pair or `cohort_snapshotted_at` is null. Otherwise the union
  of the persisted recipients of the pair's Homework and Blitz. `forStudent` returns null for a Student
  outside it. Each view carries the Student (`id`, `full_name`).
- **Side states.** Built from one shared evaluation of the Stage 9 official-score status (§5.1) with
  batch-loaded data, then mapped exactly as `S10-DOC-001` §7.2:
  - Homework: `ready`; `waiting_for_teacher_review`; `automatic_checking_pending` → `checking`; never
    activated → `not_activated`; an `in_progress` Attempt → `open`; active with no deadline or
    `now < deadline_at` and fewer than three Attempts → `open`; otherwise `missing`.
  - Blitz: no pair Blitz → `not_designated`; `ready`; `waiting_for_teacher_review`;
    `automatic_checking_pending` → `checking`; `waiting_for_replacement` → `open`; never activated →
    `not_activated`; active, no Blitz Attempt and the Homework side `missing` → `missing`; active →
    `open`; otherwise `missing`.
  - A `ready` side carries its official Attempt id, Attempt number and score (the stored official row's
    score, confirmed by the live evaluation).
- **Settings.** T = `institution_settings.acceptable_score_difference`; the category set = the stored
  categories when the existing set validator accepts them, else none.
- **Work finished**: the pair's Blitz was activated and is closed or archived; the Homework is closed or
  archived, has `deadline_at <= now`, or the Student has three Attempts; and the Student has no
  `in_progress` Attempt on either task.
- **Closable** = terminal and work finished.
- **Stored rows.** The view carries the Student's `topic_results` row when one exists. A closed row
  replaces the computation: `result_status = closed`, `closed_outcome`, `missing_component`, both side
  states with their Attempt ids and scores, and every value from the snapshot (Attempt numbers are read
  from the referenced Attempts). For a closed row, work finished is true when `closure_reason = teacher`
  and follows the rule above when `topic_archived`; closable and terminal are false. Rows of Students
  outside the cohort are ignored.
- **Queries.** A constant number per Topic, independent of the cohort size.

`TopicResultView` exposes: Student, `result_status`, `closed_outcome`, `missing_component`, the two sides
(state, assessment id, Attempt id, Attempt number, score), D, T, method, consistency, final,
`category_score`, category (code, min, max), `terminal`, `workFinished`, `closable`, and the stored row
(or null).

## 6. Security and Integrity

The reader takes the Topic and Institution from its caller and filters every query by `institution_id`;
it never trusts a Student id outside the cohort. The migration's tenant-safe keys keep every reference
in the Institution. No Student-facing value changes in this task.

## 7. Tests

- **Unit** — `TopicResultMath` (difference, average rounding, `categoryScore` boundaries);
  `TopicResultCalculator`: every status-precedence row, the formula cases from the roadmap (close
  scores, large difference, Blitz higher, missing Homework, missing Blitz, waiting for review, Not
  completed, `D = T`, `D` above `T` only in the 8th decimal), category boundaries, display rounding never
  changing the category, `waiting_for_settings`; `UnicodeWhitespace`.
- **Persistence** — `topic_results`: exact columns, types and nullability; uniques; every check with a
  rejected and an accepted row; the exact foreign-key map; parent delete restricted; the feedback check.
- **Reader (feature, PostgreSQL)** — every Homework and Blitz side-state row with real data (including the
  exception with and without #2, #1 waiting for review after the close, a stale official row, a
  Student barred by `S10-D8`); cohort before and after the snapshot and the union of recipients; work
  finished (each condition); closable; a closed row (both outcomes and both closure reasons); rows of
  Students outside the cohort ignored; current settings used (a changed T changes an open result, not a
  closed one); invalid or missing categories → `waiting_for_settings`; the query count is the same for a
  cohort of two and of six.
- **`PH2-4`** — the counting Attempt (no exception, exception without and with #2, inconsistent graph);
  `StudentResultVisibility` hides an active Blitz Attempt; the existing Checking and Student result tests
  stay green unchanged.
- **`CL9-11`** — for each §4 field a value of only non-breaking spaces (and one of U+3000) returns the
  existing `422`, and a value with text around them is accepted.

## 8. Expected Files

```text
backend/database/migrations/2026_10_04_000000_create_stage_10_topic_result_foundation.php
backend/app/Models/TopicResult.php
backend/database/factories/TopicResultFactory.php
backend/app/Enums/TopicResult*.php
backend/app/Domain/Results/*
backend/app/Domain/Text/UnicodeWhitespace.php
backend/app/Support/Results/*
backend/app/Support/Checking/OfficialScoreEvaluator.php, OfficialScoreReader.php, OfficialTaskDesignation.php
backend/app/Actions/Checking/RepairOfficialTaskScores.php
backend/app/Actions/Student/ListStudentFinishedBlitz.php
backend/app/Support/Student/StudentResultVisibility.php, StudentAnswerText.php, StudentHomeworkResults.php (if the signature changes)
backend/app/Domain/Assessment/Checking/AnswerTextNormalizer.php
backend/app/Domain/Assessment/QuestionConfigurationValidator.php, AssessmentActivationValidator.php (or where they live)
backend/app/Http/Requests/Teacher/TeacherHomeworkMutationRequest.php, TeacherBlitzMutationRequest.php, TeacherBlitzAttemptExceptionRequest.php
backend/tests/Unit/Domain/Results/*, tests/Unit/Domain/Text/*
backend/tests/Feature/Persistence/TopicResultPersistenceTest.php
backend/tests/Feature/Results/TopicResultReaderTest.php
backend/tests/Feature/... CL9-11 request tests and PH2-4 tests
tasks/backend/stage-10/S10-BE-001-topic-result-foundation.md, tasks/STAGE_10_TASK_INDEX.md
```

## 9. Acceptance Criteria

- [ ] §5.1-§5.5 implemented exactly; no endpoint or response shape changes.
- [ ] Every test group of §7 exists and passes; existing Checking, Student, Teacher Question/Homework/Blitz
      and Persistence tests pass unchanged except the deliberate updates: the Stage 6 and Stage 8 schema
      inspection guards that `topic_results` does not exist yet (`AssessmentHomeworkSchemaInspectionTest`,
      `BlitzPersistenceSchemaInspectionTest`) now point to the Stage 10 schema test.
- [ ] Independent fresh-context review `PASS` (P1 = 0, P2 = 0).

## 10. Verification

```text
docker compose ... exec -T app vendor/bin/pint --test
docker compose ... exec -T app vendor/bin/phpunit tests/Unit
docker compose ... exec -T app vendor/bin/phpunit tests/Feature/Results tests/Feature/Persistence tests/Feature/Checking
docker compose ... exec -T app vendor/bin/phpunit tests/Feature/Student tests/Feature/Teacher
git diff --check
```
