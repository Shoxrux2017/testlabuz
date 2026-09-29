# Implementation Contract: S09-BE-001 — Checking Domain

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-BE-001` |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Backend` — pure domain code and unit tests; no persistence, no API |
| Status | `Approved` |
| Depends on | `S09-DOC-001 — Accepted / Delivered` (PR #289, `main` `4cff8af`) |
| Implementation baseline | `origin/main` `4cff8af` (re-checked before implementation) |
| Owner decisions applied | `S09-D1` (multiple-choice formula), `S09-D9` (fill-in-blank normalization) |
| Technical decisions applied | `S09-T3` (exact decimals, `brick/math`, NFC polyfill, no `bcmath`) |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |
| Blocks | `S09-BE-002` |

This file is the complete task contract. It needs no other document to implement.

## 2. Goal

Add the reusable checking and scoring rules that later Stage 9 tasks call: the Student-answer text
normalizer, the automatic checker for every automatic Question type, the routing rule that decides
between automatic checking, Teacher review and zero-point closing, and exact decimal score arithmetic.
`S09-BE-003` maps persisted Questions and answers onto this API; `S09-BE-004` and `S09-BE-006` reuse the
arithmetic.

## 3. Scope

### Included

- `backend/composer.json`: declare `brick/math` and `symfony/polyfill-intl-normalizer` as direct
  requirements at their locked versions; `backend/composer.lock` changes only its `content-hash`.
- New domain classes under `backend/app/Domain/Assessment/Checking/` (§5).
- New unit tests under `backend/tests/Unit/Domain/Assessment/Checking/` (§7).

### Non-goals

- No migration, model, Eloquent query, Action, controller, route, Resource, command or scheduler change.
- No mapping from persisted rows to the checker inputs (`S09-BE-003`).
- No official-score resolver, review API, visibility or API number formatting (`S09-BE-004…007`).
- No change to answer saving, the selection cap, or Question authoring validation.

## 4. Current Implementation Context

- PHP 8.4 in `docker/php/Dockerfile` with native `mbstring`; no `intl` and no `bcmath` extension.
- `composer.lock` already contains `brick/math` `0.18.0` and `symfony/polyfill-intl-normalizer`
  `v1.38.0`, only as transitive dependencies of `laravel/framework`.
- Question points are `numeric(14,6)`; `AssessmentPointMath::normalize()` returns them as decimal strings
  with six fractional digits (`"2.500000"`). `attempt_answers.awarded_points` is `numeric(16,8)` cast as
  `decimal:8`; `assessment_attempts.earned_points` is `numeric(16,8)`, `normalized_score` is
  `numeric(12,8)`, `possible_points` is `numeric(14,6)`.
- `QuestionConfigurationValidator` allows `checking_mode = manual` only for `short_written`,
  `open_written` and `file_based`; `open_written` and `file_based` are always manual; every other type is
  always automatic. Single choice has exactly one correct option; multiple choice has at least one.
  Ordering `correct_position` values are the contiguous positions `1…n`.
- Saved answers (`StudentHomeworkAnswerValue`): an empty answer cannot exist (clearing deletes the row).
  Choice answers hold option ids; matching answers hold `{left_item_id, right_item_id}` pairs, possibly
  for only some left items; ordering answers hold `{item_id, position}` for placed items, possibly not
  all; fill-in-blank answers hold `{blank_id, text}` for filled blanks, possibly not all.
- `StudentAnswerText::isEmpty()` uses the Student-answer whitespace set below.

## 5. Exact Contract

Namespace `App\Domain\Assessment\Checking`. Every class is `final` and stateless. Decimal values cross the
API as strings.

### 5.1 `AnswerTextNormalizer`

`normalize(string $text): string` applies, in this order:

1. Unicode NFC (`Normalizer::normalize($text, Normalizer::FORM_C)`);
2. full Unicode case folding, locale-independent (`mb_convert_case($text, MB_CASE_FOLD, 'UTF-8')`);
3. NFC again;
4. map each of U+0027 `'`, U+0060 `` ` ``, U+00B4 `´`, U+02BB `ʻ`, U+02BC `ʼ`, U+2018 `‘`, U+2019 `’`
   to U+0027;
5. replace every run of characters from the set U+0009–U+000D, U+0020, U+0085, U+00A0, U+1680,
   U+2000–U+200A, U+2028, U+2029, U+202F, U+205F, U+3000, U+FEFF with one U+0020;
6. remove leading and trailing U+0020.

Punctuation and every other symbol stay significant. A text that is not valid UTF-8 (the normalizer returns
`false`) throws `LogicException`.

### 5.2 `CheckingScoreMath`

All results are decimal strings with exactly 8 fractional digits (`"2.50000000"`), computed with
`Brick\Math\BigDecimal`; no `float`, `bcmath` or `round()` is used.

- `partialPoints(string $points, int $correct, int $total): string` — `points × correct / total`, computed
  in one step and rounded half-up (`RoundingMode::HalfUp`) to 8 decimal places. Requires
  `0 ≤ correct ≤ total` and `total ≥ 1`; otherwise `LogicException`. `correct = total` returns exactly
  `points`; `correct = 0` returns `"0.00000000"`.
- `sum(list<string> $awardedPoints): string` — the exact sum; an empty list is `"0.00000000"`.
- `normalizedScore(string $earnedPoints, string $possiblePoints): string` — `earned × 100 / possible`,
  rounded half-up to 8 decimal places. `possible ≤ 0`, a negative `earned`, or `earned > possible` throws
  `LogicException`.
- `compare(string $left, string $right): int` — `-1`, `0` or `1`, comparing the exact decimal values
  (later tasks compare scores and bounds with it, never as strings or floats).
- `isZero(string $points): bool` — whether the value equals zero (used by the route in §5.3).

`points` and every decimal argument must be a plain non-negative decimal string with at most 8 fractional
digits (`^\d+(\.\d{1,8})?$`); anything else throws `LogicException`. Question points have 6 and stored
scores 8, so every sum is exact at 8 places and full credit returns exactly `points`.

### 5.3 `AnswerCheckingRoute`

String-backed enum with the cases `automatic`, `teacher_review`, `zero_point_closed`, and

`public static function resolve(QuestionType $type, QuestionCheckingMode $mode, string $points): self`

| Type and mode | `points > 0` | `points = 0` |
|---|---|---|
| automatic type with `automatic` mode (single, multiple, true/false, short written automatic, matching, ordering, fill-in-blank) | `automatic` | `automatic` |
| `short_written` `manual`, `open_written` `manual`, `file_based` `manual` | `teacher_review` | `zero_point_closed` |

Any other combination (`short_written` is the only type whose mode may be either) throws `LogicException`.
The route applies to an answered Question only; an unanswered Question has no answer row and is never
routed (it contributes 0). `zero_point_closed` means the caller stores `auto_checked` with 0 points; an
`automatic` Question with 0 points is checked normally and earns 0.

### 5.4 `AutomaticAnswerChecker`

Each method returns the awarded points (8-decimal string, `CheckingScoreMath`) for one answered automatic
Question. `$points` is the Question's points. Ids are compared case-insensitively (lower-case both sides).
Inputs that break the saved-answer integrity rules listed per method throw `LogicException`; they are
never scored silently.

| Method | Rule | Integrity errors |
|---|---|---|
| `singleChoice(string $points, array<string,bool> $options, list<string> $selectedOptionIds)` | `points` when the one selected option is the correct one, else 0 | no option; an option id repeated; a non-boolean correctness flag; not exactly one correct option; not exactly one selected id; a selected id that is not an option |
| `multipleChoice(string $points, array<string,bool> $options, list<string> $selectedOptionIds)` | `partialPoints(points, count(selected ∩ correct), count(correct))`; a wrong selection earns and deducts nothing; the selection cap is not re-checked | no option; an option id repeated; a non-boolean correctness flag; no correct option; empty selection; a duplicate selected id; a selected id that is not an option |
| `trueFalse(string $points, bool $correctValue, bool $answer)` | `points` when equal, else 0 | — |
| `shortWritten(string $points, list<string> $acceptedAnswers, string $text)` | `points` when `normalize(text)` equals `normalize(a)` for any accepted answer `a`, else 0 | no accepted answer |
| `matching(string $points, array<string,string> $leftMatchKeys, array<string,string> $rightMatchKeys, list<array{left_item_id:string,right_item_id:string}> $pairs)` | a pair is correct when the right item's match key equals the left item's match key; `partialPoints(points, correct pairs, count(leftMatchKeys))` | no left item; a pair naming an unknown left or right item; a left or right item used twice; an empty pair list |
| `ordering(string $points, array<string,int> $correctPositions, list<array{item_id:string,position:int}> $items)` | an item is correct only when its placed position equals its `correct_position` (both 1-based); `partialPoints(points, correct items, count(correctPositions))` | fewer than one item in the key; a correct or placed position that is not an integer; an unknown item; an item or a position used twice; a position outside `1…count(correctPositions)`; an empty item list |
| `fillInBlank(string $points, array<string,list<string>> $acceptedAnswersByBlank, list<array{blank_id:string,text:string}> $values)` | a blank is correct when `normalize(text)` equals the normalized form of any of that blank's accepted answers; unfilled blanks are wrong; `partialPoints(points, correct blanks, count(acceptedAnswersByBlank))` | no blank; any blank (filled or not) without accepted answers; an unknown blank; a blank filled twice; an empty value list |

`singleChoice`/`multipleChoice`: keys of `$options` are the Question's option ids, values are `is_correct`.
`matching`: keys of `$leftMatchKeys`/`$rightMatchKeys` are item ids, values are match keys. `ordering`:
keys are item ids, values are correct positions. `fillInBlank`: keys are blank ids. Match keys also compare
case-insensitively.

### 5.5 Dependencies

In `backend/composer.json` `require`, add `"brick/math": "^0.18"` and
`"symfony/polyfill-intl-normalizer": "^1.38"`. Update the lock with
`composer update --lock --no-install` (or an equivalent that changes no package version):
no package entry of `composer.lock` changes; only `content-hash` (and the `plugin-api-version` metadata the
container's Composer writes) may differ.

## 6. Security and Integrity

No I/O, no user input and no tenant data are handled here. Integrity errors are `LogicException`s so a
caller (`S09-BE-003`) isolates and logs them per Attempt; they never award points.

## 7. Tests

Unit tests (`PHPUnit\Framework\TestCase`, no database) in
`backend/tests/Unit/Domain/Assessment/Checking/`:

- `AnswerTextNormalizerTest`: NFC composes a decomposed letter; full case folding (`ẞ`/`ß` → `ss`,
  Turkish dotted `İ` folds locale-independently, Cyrillic and Uzbek Latin letters); each of the seven
  apostrophe variants becomes U+0027; each whitespace code point (every one of the set, including U+0085,
  U+00A0, U+FEFF, U+3000) collapses; runs collapse to one space; leading and trailing spaces are trimmed;
  punctuation, hyphens and quotes other than the seven apostrophes stay significant; the order matters (an
  apostrophe produced by NFC/case folding is still mapped; the first NFC runs before folding; non-ASCII
  whitespace at the ends is collapsed and then trimmed, and only U+0020 is trimmed); every whitespace code
  point is also empty for `StudentAnswerText::isEmpty()` (the two rules must not drift); invalid UTF-8
  throws.
- `CheckingScoreMathTest`: one-step rounding (`1 × 1 / 3` → `0.33333333`, `2 × 2 / 3` → `1.33333333`,
  a half-up case at the 9th digit); `correct = total` returns exactly `points`; `0.1 + 0.2` sums exactly;
  normalized score `2.5 / 3` → `83.33333333`, `earned = possible` → `100.00000000`, `0` → `0.00000000`,
  and an exact 9th-digit tie rounds up (`0.00000001 × 100 / 200` → `0.00000001`); `compare` on exact
  values; every invalid argument (including 9 fractional digits) throws.
- `AnswerCheckingRouteTest`: every row of §5.3, including zero points, and every invalid combination.
- `AutomaticAnswerCheckerTest`: for every method, full credit, zero credit and partial credit where the
  type has it; multiple choice with a wrong selection earning nothing and with more selections than
  correct options; matching and ordering with a partial answer (some items unplaced); fill-in-blank with
  unfilled blanks, normalization and several accepted answers per blank; mixed-case ids; every integrity
  error in §5.4.

## 8. Expected Files

```text
backend/composer.json
backend/composer.lock
backend/app/Domain/Assessment/Checking/AnswerTextNormalizer.php
backend/app/Domain/Assessment/Checking/CheckingScoreMath.php
backend/app/Domain/Assessment/Checking/AnswerCheckingRoute.php
backend/app/Domain/Assessment/Checking/AutomaticAnswerChecker.php
backend/tests/Unit/Domain/Assessment/Checking/AnswerTextNormalizerTest.php
backend/tests/Unit/Domain/Assessment/Checking/CheckingScoreMathTest.php
backend/tests/Unit/Domain/Assessment/Checking/AnswerCheckingRouteTest.php
backend/tests/Unit/Domain/Assessment/Checking/AutomaticAnswerCheckerTest.php
tasks/backend/stage-09/S09-BE-001-checking-domain.md
tasks/STAGE_09_TASK_INDEX.md
tasks/README.md
```

## 9. Acceptance Criteria

- [ ] Every rule in §5 is implemented exactly; no float, `bcmath` or `round()` in scoring code.
- [ ] `composer.json` declares both packages directly; no package entry of `composer.lock` changes.
- [ ] The §7 tests pass and cover every rule and integrity error in §5.
- [ ] No file outside §8 changes.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.

## 10. Verification

Run in the app container (`POSTGRES_HOST_PORT=5434 docker compose --env-file docker/.env -f
docker/docker-compose.yml`):

```text
vendor/bin/phpunit tests/Unit/Domain/Assessment
vendor/bin/pint --test <changed PHP files>
composer validate --no-check-publish
git diff --check
```

The full backend suite is a Backend Phase 2 activity; this task adds no persistence or HTTP behavior.
