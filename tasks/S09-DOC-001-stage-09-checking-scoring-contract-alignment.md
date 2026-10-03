# S09-DOC-001 — Stage 9 Checking and Scoring Contract Alignment

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-DOC-001` |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Documentation / contract alignment` (no production code, no tests) |
| Planning baseline | `origin/main` `b07bdb14` (Stage 8 closed, `API-FIX-001` merged) |
| Depends on | Stage 9 decomposition approved (2026-09-28); `FE-UX-001` Accepted / Delivered |
| Owner decisions applied | `S09-D1`…`S09-D9`, `S09-D8a` (restated where they apply) |
| Technical decisions applied | `S09-T1`…`S09-T8`, detailed in §§4-15 below |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |

## 2. Goal

Make `docs/01`–`docs/09` one consistent, implementation-ready Stage 9 contract before any Stage 9
code is written. Every later Stage 9 implementation contract (`S09-BE-*`, `S09-FE-*`) cites the
aligned documents; none of them may have to choose between contradictory document statements.

This task edits documentation only. It records the decisions below; it does not reopen them. This
contract is self-contained: every rule the documents must state is written here.

## 3. Scope

### Included

- Apply every rule in §§4-15 to the owning documents and remove every statement that contradicts it.
- Remove stale lines: `docs/09:42` (“implementation draft” note), `docs/FINAL_AUDIT_REPORT.md:56-58`
  (deadline scoring is owned by Stage 9), duplicate rule id `BR-HW-021` (`docs/05:655`, `:658`; the
  second becomes `BR-HW-021A`).
- Record for Stage 10 planning, in `docs/06` Stage 10 dependencies: Topic-result feedback and any
  Parent-visible feedback flag (`docs/03:473`, `docs/04:1904-1913`, `docs/05:1281`) are undecided;
  practice-task results under `manual_teacher` need a release path; Stage 10 closure must re-check live
  Attempt state (§8).

### Non-goals

- No Stage 10 content beyond the boundary notes in §4 and the Stage 10 dependency notes above.
- No change to Stage 6/7/8 lifecycle, timer, idempotency, cohort or pair rules except the deliberate
  edits in §§7, 9, 10.7, 11 and 12.
- No autosave text: `FE-UX-001` already changed `BR-SUB-004` and `docs/06` §19.11.

## 4. Stage Boundary

Stage 9 owns: automatic checking; Attempt and Answer checking-state transitions; Teacher manual review
and correction; awarded points; Attempt scoring and normalization; official task-score selection and
persistence; the Teacher review queue and submission detail; Teacher download of submitted answer
files; the Homework review deadline; Student visibility of own results under §12.

Stage 10 owns: Homework–Blitz comparison, Topic results, categories, result release actions, Parent
visibility, result closure, and the `409 result_closed` guard on review corrections after closure.
Until Stage 10 exists, a correction is always allowed (§10.6).

Out of MVP (unchanged): negative marking, AI or fuzzy checking, appeals, Teacher choice of the official
Attempt, Student view of correct answers or per-Question points, a review history table (the last
reviewer and time are kept in `checked_by_user_id` and `checked_at`, `docs/08` actor-field decision).

## 5. Automatic Checking Rules (S09-D1, S09-D9)

For every Question of a frozen Attempt:

| Type | Rule |
|---|---|
| `single_choice` | Full points when the one selected option is correct; otherwise 0 |
| `multiple_choice` | `points × correctly_selected / total_correct` (`S09-D1` = `BR-Q-009`). A wrong selection earns nothing and deducts nothing. The selection cap stays the save-time rule |
| `true_false` | Full points when the value equals `correct_value`; otherwise 0 |
| `short_written`, automatic | Full points when the normalized answer equals any normalized accepted answer; otherwise 0 |
| `fill_in_blank` | `points × correct_blanks / total_blanks`. A blank is correct when its normalized value equals any normalized accepted answer of that blank (`S09-D9`: same normalization as short answers) |
| `matching` | `points × correct_pairs / total_left_items`. A pair is correct when the chosen right item has the left item's `match_key` |
| `ordering` | `points × correctly_positioned / total_items`. An item counts only at its exact `correct_position` (both sides 1-based) |
| `open_written`, `file_based`, `short_written` manual | Manual review (§10) |

Additional rules:

- Only `short_written` can be switched to manual checking; `docs/06:1646` (“any question explicitly
  configured for manual review”) is reworded to that.
- **Unanswered Question** (no `attempt_answers` row): contributes 0. No row is fabricated and no review
  is required, including for manual Questions. An empty answer cannot exist: clearing deletes the row.
- **Zero-point Question**: an automatic answer is checked with 0 points; a manual answer is closed
  automatically as `auto_checked` with 0 points and never enters the review queue.
- **Automatic results** set `checked_at` to the checking time and leave `checked_by_user_id` null.
- **Text normalization** (`BR-Q-013A`, now also cited by `BR-Q-024`): apply to both sides, in order:
  Unicode NFC → Unicode full case folding (locale-independent) → NFC again → map the apostrophe variants
  U+0027 `'`, U+0060 `` ` ``, U+00B4 `´`, U+02BB `ʻ`, U+02BC `ʼ`, U+2018 `‘`, U+2019 `’` to U+0027 →
  replace every run of the Student-answer whitespace set (U+0009–U+000D, U+0020, U+0085, U+00A0,
  U+1680, U+2000–U+200A, U+2028, U+2029, U+202F, U+205F, U+3000, U+FEFF) with one U+0020 → trim. Then
  compare exactly. Punctuation and other symbols stay significant.
- `docs/01:185` and `docs/08:1453` are rewritten to the `BR-Q-009` formula.

## 6. Arithmetic and Precision (S09-T3)

- No binary floating point in any scoring calculation. The backend uses `brick/math` (`BigDecimal`),
  declared as a direct dependency of `backend/composer.json` at the already locked version (`0.18.0`,
  today only transitive through `laravel/framework`). `bcmath` must not be used: the Docker image does
  not install it. NFC uses `Normalizer` from `symfony/polyfill-intl-normalizer` (also declared directly
  at its locked version); case folding uses `mb_convert_case(..., MB_CASE_FOLD)`.
- A partial-credit Question is computed in one step, `points × correct / total`, rounded half-up to
  8 decimal places for `attempt_answers.awarded_points`. A fully correct answer always stores exactly
  `points`, so `earned_points ≤ possible_points` always holds.
- `earned_points` = exact sum of the stored `awarded_points` of the Attempt.
- `normalized_score` = `earned_points × 100 / possible_points`, rounded half-up to 8 decimal places.
  `possible_points` is the Attempt snapshot taken at Start and is always positive.
- Official selection, ties and every later comparison use stored `normalized_score` values; any bound
  compared with them (§8) is rounded the same way first.
- API scores are JSON numbers converted from the stored decimal; clients never calculate with them.
  Display is one decimal place, standard half-up rounding.
- Teacher-awarded points (§10.5) follow the Question `points` number rule
  (`AssessmentPointMath::normalize`: shortest JSON representation, at most 6 fractional digits).

## 7. Checking States and Trigger (S09-T1, S09-T7)

Answer `checking_status`:

```text
pending → auto_checked                  (automatic types; zero-point manual answers)
pending → waiting_for_teacher_review    (manual answer with a row and points > 0)
waiting_for_teacher_review → teacher_checked   (Teacher review)
teacher_checked → teacher_checked              (Teacher correction)
```

Attempt `status`:

```text
submitted | timed_out_finalized
  → checked                     (automatic run leaves no waiting answer)
  → waiting_for_teacher_review  (at least one waiting answer)
waiting_for_teacher_review → checked   (last waiting answer reviewed)
checked → checked                      (correction recalculates)
```

- On `checked`: `earned_points`, `normalized_score` and `scoring_completed_at` (time of the latest
  scoring) are set. While waiting, `earned_points` and `normalized_score` stay null.
- `finalization_reason`, `submitted_at`, `finalized_at` and `locked_at` never change.
- **Trigger.** Freezing points are Homework Submit, deadline reconciliation and Teacher close; Blitz
  Submit, timeout reconciliation, Teacher close, and the timeout performed during an exception grant.
  - In an HTTP request, the ids of the Attempts it froze are collected by one request-scoped collector,
    which registers its `app()->terminating(...)` callback only once per collector instance (a flag) and
    drains its id list on each run, so nothing is checked twice on later requests (Laravel keeps
    terminating callbacks, and in tests also scoped instances, for the application's lifetime).
    The callback runs after the response is built. Not a queued job: `QUEUE_CONNECTION=sync` would run a
    job inline and leak into the freeze response.
  - In a console command (deadline and timeout reconciliation), each frozen Attempt is checked after
    the reconciliation transaction commits.
  - Each Attempt is checked in its own transaction; a failure is logged and never propagates, never
    rolls back or alters the freeze, and never changes the freeze response.
  - A scheduled command runs every minute without overlap. It checks every Attempt still in
    `submitted` or `timed_out_finalized` (this also covers history frozen before Stage 9), isolating
    failures per Attempt, and re-runs the official resolver (§8) for official-task Students that have a
    `checked` eligible Attempt and no pending eligible Attempt but whose official row is missing or differs
    from the live evaluation (a state that should not exist; this repairs it). The scheduler is already required for Stage 7/8
    deadline and timeout reconciliation; the integration harness must run it.
  - Checking takes the §8 locks and acts only on `submitted`/`timed_out_finalized`, so it is idempotent.
- `docs/09:4652` and `docs/08:2272` (“Stage 7/8 freeze does not trigger immediate checking”) are
  rewritten: the freeze itself does no checking; Stage 9 checks right after it commits.
- **Invalidated Blitz Attempt #1 (S09-T7):** checked like any Attempt and may wait for review; never
  official and never blocking. The Student-facing status “Invalidated by approved exception”
  (`docs/05:1439`) is derived from `official_score_eligible = false`; the stored status follows normal
  checking.
- **Practice tasks (S09-D6):** checked and reviewed like official tasks; never an official score.

## 8. Official Task Score (S09-D2, S09-D4, S09-D6)

`official_task_scores` (`docs/08` §19.1) is created in Stage 9 and holds rows only for the Homework and
the Blitz referenced by the Topic result pair. A row exists exactly while the official score is ready.
`selected_by_user_id` is always null. `selected_at` is set when the row is created or when its
`official_attempt_id` or `normalized_score` changes.

### Serialization

Every transaction that may change an official score — automatic checking, review save, correction,
exception grant, and the sweep's re-resolve — locks, in this order:

```text
Topic (shared) → Assessment (shared) → Homework/Blitz task row (shared)
→ the Student's assessment_students recipient row (FOR UPDATE)
→ the Student's Attempt rows of that Assessment (FOR UPDATE) → answer rows → official row
```

- The resolver reads the Student's Attempts of that Assessment only under the recipient lock, so two
  writers for one Student and Assessment never decide concurrently.
- The parent chain comes first because the Teacher Homework update (`UpdateTeacherHomework`), the pair
  designation (`SetTeacherTopicResultPair`) and the Blitz exception grant lock Group, Teacher membership,
  Topic, Assessment and task rows `FOR UPDATE` first, and only then Attempts and recipients. Taking the same parents first makes them serialize with scoring instead of
  deadlocking. The Stage 7/8 Start, Submit, answer, deadline, timeout, close and grant paths already take
  the parents first.
- `topic_result_pairs` is read without a row lock: designation cannot change once Attempts exist, and Blitz
  Start locks the pair before the recipient, so locking it after the recipient would invert that order.

### Homework (S09-D2)

Eligible Attempts: this Student's Attempts of this Homework with `official_score_eligible = true`.

1. `best` = the `checked` eligible Attempt with the highest `normalized_score`; ties go to the lowest
   `attempt_number`. No `checked` Attempt → not ready.
2. Every eligible terminal Attempt that is not `checked` is **pending**. Its upper bound is
   `(awarded points of its checked answers + full points of its waiting answers) × 100 / possible_points`,
   rounded as in §6; an Attempt not yet automatically checked has upper bound 100.
3. Not ready while any pending Attempt has an upper bound greater than `best`, or equal to `best` with
   a lower `attempt_number` than `best`.
4. Otherwise the row is `best`, `selection_policy_code = highest_valid_completed`.

`in_progress` Attempts are not considered. When a later Attempt becomes pending and could overtake, a
ready score becomes not ready until it is checked; this is intended (“wait only for an Attempt that could
overtake”). `docs/06:1676`, `docs/02:222`, `docs/04:3572`, `docs/07:1306-1308` and `docs/09:4786-4790`
all state this one rule.

### Blitz (S09-D4)

- No exception: ready when Attempt #1 is `checked`; policy `valid_normal_blitz`.
- With an exception: #1 is excluded; ready when replacement #2 exists and is `checked`; policy
  `approved_blitz_exception_replacement`.
- The exception grant deletes an existing official row for that Student in the grant transaction.
- A Blitz closed before the Student took replacement #2 has no official Blitz score; Stage 10 treats the
  Student as Not completed. A #2 taken before the close becomes official once it is checked, even when
  its review ends after the close (§14 rows 4-5). The grant dialog states this consequence (`S09-FE-001`).

### When the resolver runs, and reads

- It runs inside every automatic checking run, review save, correction and exception grant for an
  official task, and in the sweep (§7).
- Between a freeze and its checking run the row can still show the previous result. Therefore no read
  trusts the row alone: `ready` (§14) and Student `score_visible` (§12) require the row **and** a live
  evaluation of steps 1-3 (or the Blitz rules) that is ready with the same Attempt and the same
  normalized score. Stage 10 closure must use the same live evaluation.

## 9. Stage 7/8 Behavior Preservation (S09-T2, S09-T6)

- **Timeout keys.** Rules keyed on “terminal Attempt with status `timed_out_finalized`” are rewritten as
  “terminal Attempt with `finalization_reason = timeout_auto_submit`, whatever its later checking status”.
  This applies only to the Blitz Start/Resume matrix (`docs/09` §20.3, `:4221-4236`) and the Blitz Submit
  matrix (`docs/09` §20.5), plus `BR-ATT-004A` (`docs/05:855-864`) and the matching `docs/04`/`docs/07`
  lines. Answer mutation (§20.4) is not changed: a write to any terminal Attempt already returns
  `409 attempt_not_editable`. Observable responses stay exactly as in Stage 8.
- **Historical reads.** Student reads and Submit replays of terminal Homework Attempts use the historical
  answer canonicalization (as Blitz already does), so answers in `auto_checked`, `waiting_for_teacher_review`
  or `teacher_checked` state are read without error. Today the Homework path requires `pending` answers
  and would fail with a server error once checking runs.
- **Replay.** Replay of a completed Homework or Blitz Submit returns the Attempt in its current status,
  which may be `waiting_for_teacher_review` or `checked`; all finalization fields are unchanged.
- **Monitoring** (`docs/09` §19.4) keeps its wire format: `checked` counts as `finalized`, waiting as
  `waiting_for_teacher_review`, and every row keeps `score: null` through Stage 9. “Throughout Stage 8”
  becomes “through Stage 9; the Teacher reads scores from the review resources”.

## 10. Teacher Review API (S09-D6, S09-D7, S09-T4, S09-T5)

### 10.1 Access (all review resources)

A submission is a terminal Attempt (`submitted`, `timed_out_finalized`, `waiting_for_teacher_review`,
`checked`) of a Homework or Blitz whose Topic is visible to the Teacher (same Institution,
`topics.teacher_id`, current Teacher–Group membership) and whose Student is a persisted recipient.
Anything else, including `in_progress` Attempts, is a privacy-safe `404 resource_not_found`. Topic,
Homework and Blitz status (active, closed, archived) do not restrict review. Review is desktop-only in
the UI (`S09-D7`); the API does not check the device.

### 10.2 `GET /api/v1/teacher/submissions`

Query (all optional; unknown parameters or invalid values → `422 validation_failed`):
`assessment_id`, `topic_id`, `group_id`, `student_id` (UUID; an id outside the Teacher's scope simply
matches nothing, so the list is empty, never `404`);
`checking_status` = `waiting_for_teacher_review | checked | automatic_checking_pending`;
`type` = `homework | blitz`; `official` = `true | false`; `overdue` = `true`;
`sort` = `default | finalized_at | student_name | review_due_at`; `direction` = `asc | desc`
(`review_due_at` nulls last in both directions); `page`; `per_page` (default 25, max 100).

Defaults: `page` 1, `sort=default`, `direction=asc`. `sort=default` has the fixed order below and ignores
`direction`; the other sorts follow `direction` with the Attempt id as the tie-break in the same direction
(`student_name` case-insensitive).

`official` is true for an Attempt of the pair's Homework or Blitz with `official_score_eligible = true`.
An invalidated Blitz #1 is not official: it appears under `official=false` together with practice work,
and its `official_score_eligible: false` lets the UI label it “invalidated”. `sort=default`: official first, then overdue first, then
`finalized_at` ascending, then Attempt id.

Item:

```json
{
  "id": "attempt-uuid",
  "assessment": { "id": "uuid", "type": "homework", "title": "Homework 1" },
  "official": true,
  "topic": { "id": "uuid", "title": "Internet Basics" },
  "group": { "id": "uuid", "name": "7-A" },
  "student": { "id": "uuid", "full_name": "Student Name" },
  "attempt_number": 2,
  "status": "waiting_for_teacher_review",
  "official_score_eligible": true,
  "finalization_reason": "student_submit",
  "finalized_at": "2026-09-30T10:00:00Z",
  "review": { "waiting_answers": 1, "reviewed_answers": 0 },
  "review_due_at": "2026-10-02T18:00:00Z",
  "review_overdue": false,
  "score": { "earned_points": null, "possible_points": 20, "normalized_score": null }
}
```

`checking_status=automatic_checking_pending` selects `submitted`/`timed_out_finalized` Attempts.
`review_due_at` is null for Blitz. `review_overdue` = the Attempt is `waiting_for_teacher_review`, and the
Homework `review_due_at` is not null and not later than server now.

### 10.3 `GET /api/v1/teacher/submissions/{submission}`

Returns the item fields above plus `submitted_at` and `questions`: every Question of the Assessment in
position order:

```json
{
  "question": { "id": "uuid", "type": "open_written", "position": 3, "prompt": "Explain DNS.",
                "points": 5, "checking_mode": "manual", "configuration": { } },
  "answer": {
    "id": "answer-uuid",
    "value": { },
    "checking_status": "waiting_for_teacher_review",
    "awarded_points": null,
    "feedback": null,
    "checked_by": null,
    "checked_at": null
  }
}
```

- `configuration` is the Teacher Question configuration shape of the Teacher Question resource,
  including correct answers, plus the ids that `answer.value` refers to (`options[].id`,
  `pairs[].left_item_id`/`right_item_id`, `items[].id`, `blanks[].id`; correction made in `S09-BE-005A`,
  `docs/09` §21.2).
- `answer.value` has the shape of the Student attempt answer state for that type; a file answer carries
  `file { id, original_name, extension, size_bytes }`.
- `answer` is null for an unanswered Question.
- `checked_by` is `{ id, full_name }` of the last reviewer, or null (also for automatic results).

### 10.4 Teacher counts on task details (S09-D7)

The Teacher Homework detail and Teacher Blitz detail resources gain
`review_summary: { "waiting_for_teacher_review": n, "overdue": m }` (Blitz `overdue` is always 0).
Mobile shows only these counts.

### 10.5 `PUT /api/v1/teacher/submissions/{submission}/review`

Body (strict JSON, no query parameters, no `Idempotency-Key`):

```json
{ "answers": [ { "answer_id": "uuid", "awarded_points": 4.5, "feedback": "Good explanation." } ] }
```

Evaluation order:

1. **Shape** (`422 validation_failed`): `answers` is a non-empty array; each item has exactly the keys
   `answer_id` (UUID), `awarded_points` (JSON number) and `feedback` (string or null); `answer_id` values
   are unique. `feedback` is trimmed of ASCII whitespace (space, tab, CR, LF, NUL, vertical tab);
   empty becomes null; at most 2000 characters.
2. **Access** (§10.1): otherwise `404 resource_not_found`.
3. **State**: a submission in `submitted`/`timed_out_finalized` returns `409 automatic_checking_pending`.
4. **Items** (`422` on `answers.N.<field>`): each `answer_id` belongs to this submission and is a
   manual-review answer (`waiting_for_teacher_review` or `teacher_checked`); `awarded_points` is 0 to the
   Question `points` and passes the §6 number rule.

Then, in one transaction with the §8 locks, steps 2-4 are evaluated again under the locks, and only then:
write `awarded_points`, `feedback` (null clears it),
`checking_status = teacher_checked`, `checked_by_user_id`, `checked_at` (server now) for each item;
recalculate the Attempt (§7); run the resolver (§8).

- A subset of the manual answers may be saved (partial review).
- Concurrent reviews of one submission serialize on the locks; each answer keeps the last committed value.
- `200` returns the full submission detail (§10.3) with
  `"message": "Submission review saved successfully."`.

### 10.6 Correction

The same endpoint on `teacher_checked` answers. The Attempt stays `checked` and is recalculated; the
official score is re-resolved and may move to another Attempt. Stage 9 has no closure guard; Stage 10
adds `409 result_closed`.

### 10.7 Teacher submitted-file download (S09-T5)

`GET /api/v1/files/{file}/download` also authorizes a Teacher for a `student_submission` File whose
answer belongs to a submission the Teacher may access (§10.1). Files of `in_progress` Attempts stay
Student-only. Everything else stays privacy-safe `404 resource_not_found`. `docs/09` §22.2 already names
the “authorized Teacher reviewer”; it gains these exact conditions.

## 11. Homework Review Deadline (S09-D2)

- New nullable column `homework_assignments.review_due_at` (timestamptz). It is a reminder only: it never
  changes scores, statuses or official selection. Blitz has none.
- Teacher Homework create and update accept optional `review_due_at` with the same syntax and
  Institution-time parsing as `deadline_at` (RFC 3339 with an explicit offset); `null` clears it; past
  values are allowed; there is no ordering rule against `deadline_at`. In update it follows the usual
  editability (draft, active) and is not a fairness field, so Attempts do not block it.
- `PUT /api/v1/teacher/homework/{homework}/review-due-at` sets it also when the Homework is closed (review
  usually happens after closing):
  - body: strict JSON with exactly the key `review_due_at` (string as above, or `null`); no query
    parameters; no `Idempotency-Key` (absolute value);
  - access and locks: as the Teacher Homework update (Homework visible to the Teacher; Topic, Assessment and
    Homework rows locked in that order); otherwise `404 resource_not_found`;
  - checks in this order: archived Homework → `409 task_archived`; Topic closed or archived →
    `409 topic_not_editable` (existing codes and precedence of the update);
  - `200` returns the Teacher Homework resource.
- The Teacher Homework resource returns `review_due_at`. Student resources never do.

## 12. Student Result Visibility (S09-D3, S09-D5)

An Attempt result is visible to its Student when all hold:

```text
attempt.status = checked
+ attempt.official_score_eligible = true
+ institution student_result_release_mode = automatic
+ (Homework) or (Blitz with status closed or archived)
```

With `manual_teacher` or an unconfigured mode nothing is visible in Stage 9; Stage 10 adds visibility
through result release. An invalidated Blitz #1 never shows a score; the Student sees it as invalidated.

Homework:

- The Student Attempt resource (`GET /student/attempts/{attempt}`, Start/Resume and Submit responses) gains
  `result: { "visible": bool, "normalized_score": number|null }`; the score is null unless visible.
- Each Student answer state gains `feedback: string|null`, non-null only when the result is visible and
  the Teacher wrote feedback.
- The Student Homework detail gains `attempt_results`: every terminal Attempt in `attempt_number` order,
  `{ "attempt_id", "attempt_number", "status", "result": { "visible", "normalized_score" } }`.
- The Student Homework summary and detail keep `score_visible` and gain
  `official_score: { "normalized_score": n, "attempt_number": k } | null`. `score_visible` is true exactly
  when the Homework is the official one, its official score is ready by the §8 live rule and the release
  mode is `automatic`; `official_score` is non-null exactly then.

Blitz (the Student cannot read a closed Blitz today: `GET /student/blitz/{blitz}` returns
`409 blitz_not_active`):

- New `GET /api/v1/student/blitz/finished`: the Student's Blitz tasks (persisted recipient) that were
  activated (`activated_at` not null) and are now closed or archived, ordered by
  `coalesce(closed_at, archived_at)` descending, then id descending; paged (`page`, `per_page` default 25, max 100).
  Item:
  `{ "id", "topic": { "id", "title" }, "title", "status", "closed_at", "attempt_exception": bool,
  "result": { "attempt_number", "visible", "normalized_score", "feedback": [ { "question_id", "position",
  "text" } ] } | null }`.
  `result` describes the counting Attempt (replacement #2 if an exception exists, else #1) and is null when
  there is none. `normalized_score` is null and `feedback` is empty unless visible. `attempt_exception`
  tells the Student that the first Attempt was invalidated.
- The route is declared before `blitz/{blitz}`.

Never exposed to a Student: correct answers, answer keys, per-Question awarded points, per-answer
checking status, reviewer identity, `review_due_at`. Parents see nothing new in Stage 9.
`BR-ROLE-018`, `docs/04:2846-2856`, `docs/04:2949` and `docs/03:733` are rewritten to these rules.

## 13. Error Codes

- New: `409 automatic_checking_pending` (§10.5).
- `manual_review_incomplete`, `score_not_ready` and `official_score_not_ready` are removed from the
  `docs/09` catalogue; no endpoint returns them.
- `result_not_ready` and `result_closed` stay for Stage 10.

## 14. Official-Score Read

`GET /api/v1/teacher/assessments/{assessment}/students/{student}/official-score` (access as §10.1 for the
Assessment and a recipient Student) always returns `200`:

```json
{
  "data": {
    "assessment_id": "uuid",
    "assessment_type": "homework",
    "student_id": "uuid",
    "status": "ready",
    "official_attempt_id": "uuid",
    "attempt_number": 2,
    "normalized_score": 87.5,
    "selection_policy_code": "highest_valid_completed",
    "selected_at": "2026-09-30T10:00:00Z"
  }
}
```

All fields except the ids, type and `status` are null unless `status = ready`.

**Blocking Attempts:** Homework — every pending Attempt that could overtake (§8 step 3), or every
terminal eligible Attempt while none is `checked`; Blitz — the candidate Attempt (#1, or #2 after an
exception) while it is not `checked`.

`status` is the first matching row:

| # | Condition | `status` |
|---|---|---|
| 1 | The Assessment is not the pair's Homework or Blitz | `not_applicable` |
| 2 | Official row exists and the §8 live evaluation is ready with the same Attempt and the same `normalized_score` | `ready` |
| 3 | Blitz with an exception, no terminal #2, Blitz active | `waiting_for_replacement` |
| 4 | Some blocking Attempt is `submitted`/`timed_out_finalized` | `automatic_checking_pending` |
| 5 | Some blocking Attempt is `waiting_for_teacher_review` | `waiting_for_teacher_review` |
| 6 | The live evaluation is ready but the official row is missing or differs from it (a state that should not exist). The sweep repairs it only when the Student has no pending eligible Attempt; otherwise the next checking run, review save or correction of that Student's Attempts re-resolves it | `automatic_checking_pending` |
| 7 | Anything else (never started, only `in_progress`, Blitz closed without a replacement) | `no_completed_attempt` |

## 15. Planning-Audit Items Settled Here

- Feedback lives only on answers in Stage 9 (`attempt_answers.feedback`); Topic-result feedback and a
  Parent-visible flag go to Stage 10 planning (§3).
- The “Invalidated” Student status is derived, not stored (§7).
- No review history table; the actor fields hold the last reviewer (§4).

## 16. Expected Files

```text
docs/01-business-overview.md
docs/02-user-roles.md
docs/03-features.md
docs/04-user-flows.md
docs/05-business-rules.md
docs/06-roadmap.md
docs/07-architecture.md
docs/08-database.md
docs/09-api-contracts.md
docs/FINAL_AUDIT_REPORT.md
tasks/S09-DOC-001-stage-09-checking-scoring-contract-alignment.md
tasks/STAGE_09_TASK_INDEX.md
```

## 17. Acceptance Criteria

- [ ] Every rule in §§5-15 is stated in the owning document (`05` rules, `08` persistence, `09` API,
      `07` architecture, `04`/`02`/`03` flows and roles, `06` Stage 9 scope and Stage 10 dependencies)
      and no document contradicts it.
- [ ] Stage 6/7/8 statements are unchanged except the edits named in §§7, 9, 10.7, 11 and 12 and the
      stale-line removals in §3.
- [ ] The Stage 9 roadmap “Required Tests” list adds: text normalization, zero-point Questions,
      unanswered manual Questions, the “could overtake” wait rule, the resolver race (two writers for one
      Student), exception withdrawal, historical Homework reads of checked Attempts, partial review,
      concurrent review, Teacher file access, visibility per release mode and Blitz status, the
      official-score status table.
- [ ] An independent fresh-context review finds no remaining contradiction between `docs/01`–`09` on
      Stage 9 behavior (P1 = 0, P2 = 0).

## 18. Verification

```text
git diff --check
grep for every removed or renamed term (status-keyed timeout rules in §20.3/§20.5, official_score_not_ready,
  score_not_ready, manual_review_incomplete, "throughout Stage 8", "does not trigger immediate checking",
  the duplicate BR-HW-021)
fresh-context read-only review of docs/01-09 against this contract
```

No code, test or build runs: the task changes documentation only.
