# S10-DOC-001 — Stage 10 Topic Results Contract Alignment

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S10-DOC-001` |
| Stage | `Stage 10 — Final Result and Understanding Assessment` |
| Area | `Documentation / contract alignment` (no production code, no tests) |
| Planning baseline | `origin/main` `ccab413` (Stage 9 closed, `DEP-FIX-001` merged) |
| Depends on | Stage 10 backend plan approved by the Project Owner (2026-10-03) |
| Owner decisions applied | `S10-D1`…`S10-D9` (§5) |
| Technical decisions applied | `S10-T1`…`S10-T9` (§6), detailed in §§7-17 |
| Implementation | Claude |
| Delivery | Claude opens the PR and merges it after review `PASS` (Stage 10 process, owner decision 2026-10-03) |

## 2. Goal

Make `docs/01`–`docs/09` one consistent, implementation-ready Stage 10 contract before any Stage 10 code
is written. Every later Stage 10 implementation contract (`S10-BE-*`, `S10-FE-*`) restates the rules it
needs from this contract; none of them may have to choose between contradictory document statements.

This task edits documentation only. It records the decisions below; it does not reopen them. This
contract is self-contained: every rule the documents must state is written here.

## 3. Scope

### Included

- Apply every rule in §§7-17 to the owning documents and remove every statement that contradicts it
  (`05` rules, `08` persistence, `09` API, `07` architecture, `04`/`02`/`03`/`01` flows, roles and
  overview, `06` Stage 10 scope, required tests and dependencies).
- Remove the superseded Stage 10 design: stored and recalculated open results, the recalculate
  endpoint, release-mode snapshots, `topic_results` references to `official_task_scores`, the
  four-value calculation method, any hide/unrelease wording, `409 category_configuration_invalid` and
  the unused `result_not_visible` code.
- Mark every “Carried from Stage 9 into Stage 10 planning” item in `docs/06` with its disposition (§18).
- Add the Stage 10 deployment note to `docs/07` §36 (§17).

### Non-goals

- No Stage 11 content: Parent screens and lists, dashboards, progress and report APIs keep their
  current text except where they restate a Stage 10 visibility rule.
- No change to Stage 1-9 behavior except the deliberate edits named in §§8.1, 11, 12.8, 13 and 14.
- No rule on the Homework deadline itself: `S10-D8` enforces the order “Homework before Blitz” at the
  official Blitz activation instead (`docs/01:17,140`).

## 4. Stage Boundary

Stage 10 owns: the live Topic result (comparison, formula, category, status, Not completed), the
“Homework before Blitz” work order (`S10-D8`), the Teacher's Topic-result comment, Student and Parent visibility of Topic results and of official Attempt
results, Teacher release (single and bulk), result closure (single, bulk and on Topic archive), the
`409 result_closed` guards, the Student Topic-result read, and a minimal Parent API (one result read).

Stage 11 owns: Parent screens, the Parent children list, dashboards, progress and report APIs, group
and Institution summaries.

Out of MVP (unchanged): appeals and post-closure revision, reopening a closed result, hiding a released
result, Teacher override of scores or categories, custom category names, notifications.

## 5. Project Owner Decisions (2026-10-03)

| ID | Decision |
|---|---|
| `S10-D1` | A Topic result carries one optional Teacher comment (≤ 2000 characters, trimmed, empty means none; §12.4). The Student sees it with the visible result; the Parent sees it only when the result is visible to the Parent. No separate Parent flag. Answer feedback stays Student-only. The comment cannot change after closure. |
| `S10-D2` | The Student and the Parent see H, B, the final score, the category, the completion status, the Teacher comment and one neutral line on how the final score was formed (the calculation method). They never see the word “inconsistent”, the difference D or the threshold T. The Teacher sees everything. |
| `S10-D3` | A Topic result can become visible to the Student only when the official Blitz is closed (or archived) **and** the official Homework can no longer be submitted (closed, archived, or its deadline has passed). Automatic mode: it becomes visible by itself at that moment. Manual mode: the Teacher's release becomes available at that moment. The key point: a Student who finishes the Blitz early never sees a score before the Blitz closes. |
| `S10-D4` | A manual Topic release also makes that Student's official Homework and Blitz Attempt results and answer feedback visible. Practice (non-official) task results are not governed by the release mode: they are visible after checking in every mode (a practice Blitz after it closes). |
| `S10-D5` | A released result stays released. After a Teacher correction the Student and the Parent see the new values at once; if the result falls back to a waiting status they see that status without values, then the new result without a new release. There is no hide or unrelease action. |
| `S10-D6` | An open (not closed) result always uses the current threshold T and the current category ranges. A closed result is frozen forever. Release-mode changes act immediately on all results; releases a Teacher already made stay. |
| `S10-D7` | Single-Student close and release stay; bulk “close all ready”, “release all ready to Students” and “release to Parents all results visible to Students” are added; each bulk action acts only on eligible results and reports how many it skipped and why. Archiving a Topic closes every terminal result automatically; waiting results stay open. |
| `S10-D8` | Homework before Blitz. The Blitz checks whether the Student did the Homework alone, so: activating the official Blitz closes the official Homework for the whole class (an `in_progress` Attempt is submitted with its saved work, as on a Teacher close); only a Student with a submitted Homework Attempt may start the official Blitz; a Student without one is Not completed (Homework and Blitz); the official Blitz cannot be activated while the official Homework is still a draft. Practice Blitz tasks and the replacement Attempt #2 are unaffected. |
| `S10-D9` | A result can be closed only when the Student's work is finished — the same moment the result can become visible (`S10-D3`); with `S10-D8` that is, for everyone, right after the official Blitz closes. |

## 6. Technical Decisions (approved with the plan)

| ID | Decision |
|---|---|
| `S10-T1` | An open Topic result is computed live on every read from the current state; it is not stored and never recalculated by a job. `topic_results` stores only what cannot be derived: the Teacher comment, Teacher release facts and the closure snapshot. No Scheduler entry is added. |
| `S10-T2` | `topic_results` never references `official_task_scores` (the resolver deletes and re-inserts those rows). The closure snapshot stores the official Attempt ids and their scores, with tenant-safe references to `assessment_attempts`, which are never deleted. |
| `S10-T3` | Not completed as soon as one side can no longer be completed, even while the other side is still open. A side the Teacher never designated or never activated is never “missing”: the result waits. Status precedence: Homework, then Blitz, then Teacher review. |
| `S10-T4` | Both scores ready but the threshold or a valid category set missing: status `waiting_for_settings`. |
| `S10-T5` | Exact decimal arithmetic; the final score is stored and serialized half-up to 8 decimals; `category_score` comes from the exact final score (`.0`–`.5` down, above `.5` up); clients display one decimal (the Stage 9 rule). |
| `S10-T6` | Results are read and changed by the Topic's Teacher (owner of the Topic and current Teacher of its group, the review access rule). Every Teacher result action locks group → Teacher membership → Topic `FOR UPDATE` first, which serializes it with scoring, Starts and exception grants (they all take the Topic first). Close and release are idempotent. |
| `S10-T7` | After a Student's result is closed: corrections of that Student's official Homework/Blitz answers, comment edits and a Start of the official Homework return `409 result_closed`. Closure needs finished work (`S10-D9`), so a Blitz Start, an exception grant and a pair change cannot occur after closure and get no guard. A first review of a still-waiting answer stays allowed (it never changes the closed snapshot, §13.3). |
| `S10-T8` | Stage 10 adds a Parent route group with one read (`GET /parent/children/{student}/topics/{topic}/result`). In `hidden` mode the Parent receives no result information at all. Parent screens are Stage 11. |
| `S10-T9` | A backend change to an existing response ships in the same PR as the frontend parser change that accepts it (the `S09-T8` rule), so `main` never breaks between PRs. |

## 7. Result Inputs

### 7.1 Official pair and cohort

- The Topic's official pair is its `topic_result_pairs` row: the official Homework and the optional
  official Blitz (`docs/09` §25.1-25.2, unchanged).
- A Topic has Topic results only after its official cohort is established (`cohort_snapshotted_at` is
  set). The **cohort** is the set of persisted recipients (`assessment_students`) of the official
  Homework and the official Blitz (the existing cohort rule keeps both sets identical once both have
  recipients). Before that, the Topic has no results.
- Group membership changes after the snapshot never change the cohort (`BR-TOP-004A`, unchanged).

### 7.2 Side states

Each side (Homework, Blitz) of one cohort Student has exactly one state. The official-score status is
the Stage 9 live read (`docs/09` §24.1, unchanged): `ready` only while the stored official row matches
the live evaluation.

Homework side — first match:

| # | Condition | Side state |
|---|---|---|
| 1 | Official score status `ready` | `ready` (value H, official Attempt) |
| 2 | Status `waiting_for_teacher_review` | `waiting_for_teacher_review` |
| 3 | Status `automatic_checking_pending` | `checking` |
| 4 | The official Homework was never activated | `not_activated` |
| 5 | The Student has an `in_progress` Attempt | `open` |
| 6 | The Homework is active, has no deadline or `server_now < deadline_at`, and the Student has fewer than three Attempts | `open` |
| 7 | Otherwise (closed or archived, deadline passed, no checked or pending Attempt) | `missing` |

Blitz side — first match:

| # | Condition | Side state |
|---|---|---|
| 1 | The pair has no Blitz | `not_designated` |
| 2 | Official score status `ready` | `ready` (value B, official Attempt) |
| 3 | Status `waiting_for_teacher_review` | `waiting_for_teacher_review` |
| 4 | Status `automatic_checking_pending` | `checking` |
| 5 | Status `waiting_for_replacement` | `open` |
| 6 | The official Blitz was never activated (draft, scheduled, or archived before activation) | `not_activated` |
| 7 | The Blitz is active, the Student has no Blitz Attempt and the Homework side is `missing` (the Student can no longer get the submitted Homework that `S10-D8` requires to start) | `missing` |
| 8 | The Blitz is active | `open` |
| 9 | Otherwise (closed or archived after activation; never started, or an exception without a taken replacement — even while #1 waits for review, `BR-ATT-020`) | `missing` |

## 8. Result Status

### 8.1 Open results — first match

| # | Condition | `result_status` |
|---|---|---|
| 1 | Some side is `missing` | `not_completed`; `missing_component` = `homework`, `blitz` or `both` (the sides that are `missing` now) |
| 2 | Both sides `ready`, and the Institution has a threshold T and a valid complete category set | `calculated` |
| 3 | Both sides `ready`, threshold or category set missing | `waiting_for_settings` |
| 4 | Homework side `not_activated`, `open` or `checking` | `waiting_for_homework` |
| 5 | Blitz side `not_designated`, `not_activated`, `open` or `checking` | `waiting_for_blitz` |
| 6 | Otherwise (a side `waiting_for_teacher_review`) | `waiting_for_teacher_review` |

`missing_component` is null for every other status. A `not_completed` result can still change its
`missing_component` (for example `homework` → `both`) until it is closed.

A side that waits for checking or Teacher review is never `missing`, so review alone never makes a result
Not completed; a result is Not completed only because some side is `missing`, even while the other side
still waits for review (`S10-T3`). `BR-CAT-011` and the `BR-ATT-020` bullet (`docs/05:1025`) are reworded
to this.

### 8.2 Closed results

A closed result has `result_status = closed` and `closed_outcome` = `calculated` or `not_completed`
(null for open results); all values come from the closure snapshot (§10.2).

### 8.3 Terms

- **Terminal**: open `calculated` or open `not_completed`.
- **Work finished** (per Student; this is the `S10-D3` visibility window): the official Blitz was
  activated and is closed or archived; the official Homework is closed or archived, or has
  `deadline_at <= server_now`, or the Student has used all three Attempts; and the Student has no
  `in_progress` Attempt on either official task. A Topic without an official Blitz never has finished work
  for visibility. A deadline moved later or removed (allowed only while the Homework has no Attempts, so
  only in history from before `S10-D8`) closes the window again for an open result. A result closed by the
  Teacher (`closure_reason = teacher`) always counts as finished (its work was finished at closure); a
  result closed at Topic archive counts as finished by the rule above (at archive no Attempt is in
  progress and every task is closed or archived, so only a Topic without an activated official Blitz
  stays unfinished, and its values stay hidden).
- **Closable** (`S10-D9`): terminal, and either the Student's work is finished or the Topic is being
  archived. At archive every task is closed or archived and the Topic can no longer change, so no
  further work is possible even without an official Blitz; values of such a result stay hidden (§11.1).
- Waiting for review, waiting for settings and not released are never Not completed (`BR-CAT-011` as
  reworded above, `BR-CAT-012`).

## 9. Calculation (`S10-T5`, `S10-D6`)

For a `calculated` result, with H and B the stored 8-decimal official scores and T the Institution's
current `acceptable_score_difference`:

```text
D = |H - B|                        (exact)
D <= T  ->  final = (H + B) / 2,  calculation_method = average,  consistency = consistent
D >  T  ->  final = B,            calculation_method = blitz,    consistency = inconsistent
```

- The comparison uses exact values; `final` is exact (it can need nine decimals) and is stored and
  serialized half-up to 8 decimals.
- `category_score` is an integer from the exact final score: fractional part `.0` through `.5` rounds
  down, above `.5` rounds up (85.5 → 85, 85.50000001 → 86).
- The category is the numeric category whose inclusive range contains `category_score`, from the
  Institution's current category set. A stored set that fails the existing set validator counts as
  missing (§8.1 row 3).
- `calculation_method` has exactly two values, `average` and `blitz`; waiting and Not completed live in
  `result_status`, never in the method.
- The same rule applies whichever score is higher; an inconsistent result is never presented as an
  accusation (`BR-CMP-011`, unchanged).
- Display: every user-facing score shows one decimal, half-up, by the client from the stored value
  (the Stage 9 rule); display rounding never changes the category.

## 10. Persistence

### 10.1 `topic_results` (`S10-T1`, `S10-T2`)

One row per Topic and Student, created on the first write for that pair (comment, release or closure);
an open result without a row is fully described by the live computation.

| Column | Type | Null | Meaning |
|---|---|---|---|
| `id` | uuid | no | PK |
| `institution_id` | uuid | no | Tenant |
| `topic_id` | uuid | no | Tenant FK `(institution_id, topic_id)` → `topics` |
| `student_id` | uuid | no | Tenant FK → `users` |
| `teacher_comment` | text | yes | `S10-D1`; never an empty string |
| `teacher_comment_updated_by_user_id` | uuid | yes | Tenant FK → `users` |
| `teacher_comment_updated_at` | timestamptz | yes | |
| `student_released_at` | timestamptz | yes | Teacher Student release (manual mode) |
| `student_released_by_user_id` | uuid | yes | Tenant FK → `users` |
| `parent_released_at` | timestamptz | yes | Teacher Parent release (manual mode) |
| `parent_released_by_user_id` | uuid | yes | Tenant FK → `users` |
| `closed_at` | timestamptz | yes | |
| `closed_by_user_id` | uuid | yes | Tenant FK → `users`; the closing or archiving Teacher |
| `closure_reason` | varchar(20) | yes | `teacher` or `topic_archived` |
| `closed_outcome` | varchar(20) | yes | `calculated` or `not_completed` |
| `missing_component` | varchar(20) | yes | `homework`, `blitz`, `both` |
| `homework_assessment_id` | uuid | yes | Snapshot of the pair's Homework; tenant FK → `assessments` |
| `blitz_assessment_id` | uuid | yes | Snapshot of the pair's Blitz; tenant FK → `assessments` |
| `homework_state` | varchar(30) | yes | §7.2 Homework side state at closure |
| `blitz_state` | varchar(30) | yes | §7.2 Blitz side state at closure |
| `homework_attempt_id` | uuid | yes | Tenant FK → `assessment_attempts` |
| `homework_score` | numeric(12,8) | yes | |
| `blitz_attempt_id` | uuid | yes | Tenant FK → `assessment_attempts` |
| `blitz_score` | numeric(12,8) | yes | |
| `score_difference` | numeric(12,8) | yes | D |
| `acceptable_difference_used` | numeric(12,8) | yes | T |
| `calculation_method` | varchar(20) | yes | `average`, `blitz` |
| `consistency` | varchar(20) | yes | `consistent`, `inconsistent` |
| `final_score` | numeric(12,8) | yes | |
| `category_score` | smallint | yes | 0-100 |
| `category_code` | varchar(40) | yes | Including `not_completed` |
| `category_min_score_used` | smallint | yes | |
| `category_max_score_used` | smallint | yes | |
| `created_at`, `updated_at` | timestamptz | no | |

Constraints: `unique(topic_id, student_id)`, `unique(institution_id, id)`; every value list as a
check; scores and ranges 0-100, `category_min_score_used <= category_max_score_used`; closed rows have a
non-null `homework_assessment_id`, and `blitz_assessment_id` is null exactly when `blitz_state =
not_designated`; actor and time columns come in pairs; open rows (`closed_at` null) have
every closure column null; closed rows have both side states, and a side has its Attempt id and score
exactly when its state is `ready`; `closed_outcome = calculated` requires H, B, both Attempt ids, D, T, method,
consistency, final, `category_score`, a numeric `category_code` and its range, with
`missing_component` null; `closed_outcome = not_completed` requires `category_code = not_completed`,
`missing_component` not null, and D, T, method, consistency, final, `category_score` and the range
null (H or B with its Attempt id may be present when that side was ready). All foreign keys
`ON DELETE RESTRICT`. No reference to `official_task_scores` or `topic_result_pairs`.

### 10.2 Closure snapshot

Closing writes, from the live computation inside the closure transaction: `closed_at`,
`closed_by_user_id`, `closure_reason`, `closed_outcome`, `missing_component`, the pair's assessment ids,
both side states, the official Attempt ids and scores of the `ready` sides, and for `calculated` D, T,
method, consistency, final, `category_score`, `category_code` and the range used. After closure the
closure and comment columns never change (`S10-T7`, `S10-D6`); the release columns can still be set
(release stays separate from closure, `BR-RES-011`). A closed result never reads current settings again.

## 11. Visibility (`S10-D2`…`S10-D6`)

### 11.1 Topic result — Student

The result values (H, B, final, method, category, comment) are visible to the Student when all hold:

```text
result is terminal or closed
+ the Student's work is finished (§8.3)
+ (Institution student_result_release_mode = automatic  or  topic_results.student_released_at is set)
```

The status (`result_status`, `closed_outcome`, `missing_component`) is always visible to the Student
(`BR-STAT-018`). The Student never sees D, T, consistency or `category_score`.

### 11.2 Topic result — Parent

The Parent sees result information only for a Student with a current Parent–Student relationship. With
`parent_result_release_mode = hidden` (or unconfigured) the Parent receives no result information at
all, not even the status. Otherwise the status is visible, and the values (as §11.1, including the
comment) are visible when:

```text
the values are visible to the Student (§11.1)
+ (parent mode = with_student  or  (parent mode = manual_teacher and topic_results.parent_released_at is set))
```

### 11.3 Attempt results (replaces the Stage 9 rule, `S10-D4`)

An Attempt result (normalized score and answer feedback) is visible to its Student when all hold:

```text
attempt.status = checked
+ attempt.official_score_eligible = true
+ (Homework) or (Blitz with status closed or archived)
+ (practice task) or (student mode = automatic) or (the Student's Topic result has student_released_at)
```

The Student Homework `official_score` / `score_visible` follow the same release condition (ready by the
live rule, and automatic mode or released). Shapes of every Stage 9 response stay unchanged; only which
values are visible changes. The Attempt status `checked` stays visible without a score in manual mode
(`BR-STAT-018`; carried `CL9-10` accepted).

## 12. Teacher API (`S10-D1`, `S10-D7`, `S10-T6`)

Access for every endpoint: the Teacher owns the Topic and is a current Teacher of its group (the review
access rule); otherwise `404`. A `{student}` outside the cohort is `404`. Topic and task status never
restrict these endpoints.

### 12.1 Result item

Used by the list, the detail and every single-Student action response:

```json
{
  "student": { "id": "uuid", "full_name": "Student Name" },
  "result_status": "calculated",
  "closed_outcome": null,
  "closed_at": null,
  "missing_component": null,
  "homework": { "assessment_id": "uuid", "state": "ready", "official_attempt_id": "uuid", "attempt_number": 2, "score": 88.0 },
  "blitz": { "assessment_id": "uuid", "state": "ready", "official_attempt_id": "uuid", "attempt_number": 1, "score": 84.0 },
  "score_difference": 4.0,
  "acceptable_difference": 10.0,
  "consistency": "consistent",
  "calculation_method": "average",
  "final_score": 86.0,
  "category_score": 86,
  "category": { "code": "understood_well", "label": "Understood well" },
  "teacher_comment": null,
  "visibility": {
    "student_release_mode": "manual_teacher",
    "student_visible": false,
    "student_released_at": null,
    "can_release_to_student": true,
    "parent_release_mode": "with_student",
    "parent_visible": false,
    "parent_released_at": null,
    "can_release_to_parent": false
  },
  "can_close": true
}
```

- `state` is the §7.2 side state (`blitz.assessment_id` is null when not designated); the Attempt id,
  number and score are non-null only for `ready`.
- D, T, consistency, method, final and `category_score` are non-null only for `calculated` (open or
  closed). `category` is the numeric category for `calculated`, `{code: not_completed, label: "Not
  completed"}` for Not completed, and null otherwise.
- Closed results take every value, including both side states, from the snapshot.
- Release modes are the current Institution modes (null while unconfigured). `can_release_to_student`,
  `can_release_to_parent` and `can_close` are true exactly when the single-Student action would change
  state now (an already-done action returns `200` without a change and shows `false`).
- The Teacher sees the consistency label; D and T are displayed with one decimal like every score, so
  equal-looking D and T with `inconsistent` are possible and correct (T allows 8 decimals).
- Scores are JSON numbers of the stored 8-decimal values; clients round for display (`S10-T5`).

### 12.2 `GET /api/v1/teacher/topics/{topic}/results`

Query: `result_status` (one of the seven statuses), `category` (a category code), `page`, `per_page`
(default 25, max 100); unknown parameters are `422`. Items are cohort Students ordered by full name, then
id. `meta` holds the pagination and `counts`: the number of cohort results per `result_status` (before
filtering). A Topic without an established cohort returns an empty list.

### 12.3 `GET /api/v1/teacher/topics/{topic}/results/{student}`

The item plus: `teacher_comment_updated_at`, `teacher_comment_updated_by`, `student_released_by`,
`parent_released_by`, `closed_by` (each `{id, full_name}` or null) and `closure_reason`.

### 12.4 `PUT /api/v1/teacher/topics/{topic}/results/{student}/comment`

Body exactly `{"teacher_comment": string|null}`. Leading and trailing Unicode whitespace (including
non-breaking spaces) is trimmed; an empty result is null; at most 2000 characters after trimming, else
`422`. Allowed in every status until closure; on a closed result every request (even an unchanged value)
returns `409 result_closed`. Otherwise an unchanged value is a no-op. Returns the detail. Rows of
Students who are no longer in the cohort (a pair re-designated before any Attempt) are ignored.

### 12.5 Release — single Student

`POST /api/v1/teacher/topics/{topic}/results/{student}/release/student` (body `{}`), first match:

1. Current Student mode is not `manual_teacher` → `409 manual_release_not_allowed`.
2. Already released → `200` (no change).
3. The result is neither terminal nor closed, or the Student's work is not finished → `409 result_not_ready`.
4. Otherwise set `student_released_at`/`by` → `200`.

`POST …/release/parent` (body `{}`), first match:

1. Current Parent mode is not `manual_teacher` → `409 manual_release_not_allowed`.
2. Already released to Parents → `200`.
3. The values are not visible to the Student now (§11.1) → `409 student_result_not_released`.
4. Otherwise set `parent_released_at`/`by` → `200`.

Both return the detail. A release never changes any value or status (`BR-STAT-017` without “hiding”).

### 12.6 Close — single Student

`POST /api/v1/teacher/topics/{topic}/results/{student}/close` (body `{}`): already closed → `200` with
the closed detail; not closable (§8.3: not terminal, or the Student's work is not finished) →
`409 result_not_ready_for_closure`; otherwise write the snapshot (§10.2) with
`closure_reason = teacher` → `200`.

### 12.7 Bulk actions

`POST /api/v1/teacher/topics/{topic}/results/close`, `…/results/release/student`,
`…/results/release/parent` (body `{}`) apply the single-Student rule to every cohort Student in one
transaction:

```json
{ "data": { "processed": 21, "skipped": { "already_done": 3, "not_ready": 6 } } }
```

`skipped` keys: `already_done` (bulk close: already closed; bulk Student release: already released to
the Student; bulk Parent release: already released to Parents) and `not_ready` (the single action would
return `result_not_ready`, `result_not_ready_for_closure` or `student_result_not_released`). A closed
result is released like any other. A mode that forbids the release fails the whole call with
`409 manual_release_not_allowed`.

### 12.8 Automatic closure on Topic archive

`POST /teacher/topics/{topic}/archive` keeps its request, response and conflicts; inside its transaction
it closes every terminal result of the cohort (§8.3 Closable) with `closure_reason = topic_archived` and
`closed_by_user_id` = the archiving Teacher. Waiting results stay open. Closing a Topic (`…/close`)
closes no result. This is a deliberate change to the Stage 5 archive behavior.

## 13. Closure Effects and Concurrency (`S10-T6`, `S10-T7`)

### 13.1 Lock order

Teacher result actions (comment, release, close, bulk, archive) lock group → Teacher membership → Topic
`FOR UPDATE` (the Topic lifecycle order), then the `topic_results` rows they write. Scoring (checking,
review, sweep repair) takes the Topic `FOR SHARE` first; Student Starts and the exception grant take the
Topic `FOR UPDATE` first; Submit and answer saves take it shared. The Homework deadline and Blitz timeout
finalizers lock the Assessment and then the Attempts and never the Topic, so closure (single, bulk and on
archive) additionally locks the official Attempt rows of every affected Student `FOR SHARE` in one query
ordered by Attempt id (one global order, also across Students in a bulk close), after the Topic and before
evaluating; terminal state, finished work and the snapshot then come from one consistent view. No path
locks the Topic and then a group or a Teacher membership (the activation snapshot locks Student
memberships after the Topic, which no Teacher result action locks), so no lock cycle exists.
Reads take no locks and compute inside one `REPEATABLE READ READ ONLY` snapshot.

### 13.2 What closure blocks — `409 result_closed`

For a Student whose Topic result is closed:

- `PUT /teacher/submissions/{submission}/review` on an Attempt of the Topic's official Homework or Blitz:
  any item naming an answer that is `teacher_checked` (a correction) fails the whole request with
  `409 result_closed` — inside the scoring-lock transaction, after the re-checked
  `automatic_checking_pending` and before the item re-validation and any write; invalid items still get
  the existing pre-transaction `422` first;
- the comment `PUT` (§12.4), before the no-op check;
- `POST /student/homework/{homework}/attempts` (Start) of the official Homework, after the existing
  lifecycle, deadline and attempt-count conflicts. It is reachable only in history from before
  `S10-D8`: a Homework with no Attempt at all whose deadline a Teacher moved later.

Closure needs finished work (`S10-D9`) — the official Blitz is closed — or the Topic is archived, so a
Blitz Start, an exception grant and a pair change (`result_pair_locked`/`topic_not_editable` already
apply) cannot happen after closure; they get no `result_closed` guard. Idempotent replays of an earlier successful request keep returning the
stored response. Practice tasks are never affected.

### 13.3 Still allowed after closure

A first review of a still-waiting answer. For a `calculated` closure no pending Attempt could overtake,
so the review cannot change the official score. For a `not_completed` closure the snapshot holds only
the sides that were `ready`; a later first review may still complete the other side's official score in
`official_task_scores` (Stage 9 views show it), but it never changes the closed snapshot. Automatic
checking and the sweep keep running unchanged; nothing they do can change a closed result's snapshot.

### 13.4 Homework before Blitz (`S10-D8`)

Activation of the official Blitz (`POST /teacher/blitz/{blitz}/activate`, the Blitz is the pair's Blitz):

- If the official Homework is a draft → `409 official_homework_not_activated`, nothing changes. This
  check runs immediately after the existing timer-mode settings check and before the cohort is locked. It
  reads the Homework status without a row lock: every Homework lifecycle change takes the Topic, which the
  activation already holds, so the read is stable (locking the Homework row here would put it before its
  Assessment, against the deadline finalizer's order).
- If the official Homework is active, the activation closes it inside the same transaction exactly like a
  Teacher Homework close (`BR-HW-012`): after all locks the activation captures one untruncated
  `closedAt = server_now`; the Blitz `activated_at` is `closedAt` truncated to the UTC second (the
  existing Blitz timing rule); the Homework close uses `closedAt` itself (so it never precedes the
  Homework's own sub-second `activated_at` or an Attempt's `started_at`): the deadline is reconciled
  first when it has passed, every still-`in_progress` Attempt is frozen as `submitted` with
  `finalization_reason = task_closed_auto_finalize`, the Homework gets `status = closed` and
  `closed_at = closedAt` (a Homework close records no actor), and frozen Attempts are checked after the
  response like every other freeze. Only the Homework's own Attempts are passed to the Homework finalizer
  (the cohort step returns the Attempts of both official tasks).
- A closed or archived official Homework is left unchanged.
- Locks: the close reuses the Homework Assessment, Homework row and Attempts that the existing cohort step
  of the activation already locks; it takes no lock in another order. Every other writer of these Attempts
  takes the Topic first or locks the Homework Assessment first, so no cycle exists.
- The response, idempotency and every other conflict of the activation are unchanged; a replay never
  closes anything.

Start of normal Attempt #1 of the official Blitz (`POST /student/blitz/{blitz}/attempts` with
`intent = start_normal`): when the request would create a new Attempt #1 (after the existing executability
checks, and only when the Student has no Attempt #1), the Student must have at least one terminal
(`submitted`, `waiting_for_teacher_review` or `checked`) Attempt of the official Homework, otherwise
`409 homework_not_submitted`. A `start_normal` that returns an existing Attempt #1, an idempotent replay,
`intent = resume` and `intent = start_replacement` are unaffected. A barred Student is Not completed at
once when the activation closed the Homework (Homework side `missing`, Blitz side `missing` by §7.2 Blitz
row 7, `missing_component = both`); in history from before `S10-D8` with a still-open Homework the result
waits for the Homework instead. The
Student Blitz read does not announce the bar; the client learns it from the `409` (frontend plan).

## 14. Student and Parent API

### 14.1 `GET /api/v1/student/topics/{topic}/result`

Access follows the Stage 9 recipient rule: the Topic is in the Student's Institution and is active,
closed or archived, and the Student is a current group member or a cohort member (a persisted recipient
of an official task keeps access after leaving the group, `BR-REL-010`); otherwise `404`. A Student
outside the cohort (or a Topic without a cohort) gets `{"data": null}`.

```json
{
  "data": {
    "topic_id": "uuid",
    "result_status": "calculated",
    "closed_outcome": null,
    "missing_component": null,
    "visible": true,
    "homework_score": 88.0,
    "blitz_score": 84.0,
    "final_score": 86.0,
    "calculation_method": "average",
    "category": { "code": "understood_well", "label": "Understood well" },
    "teacher_comment": "Well done; revise question 4."
  }
}
```

When `visible` is false every value field is null. When visible, the fields hold what exists: a Not
completed result shows the ready side, the Not completed category, the comment and null final score and
method.

### 14.2 Student Topic detail

`GET /student/topics/{topic}` keeps its shape; `result_status` becomes the §14.1 value (null when the
Student has no Topic result) instead of the fixed `waiting_for_homework`. `homework` and `blitz_status`
stay Stage 11 placeholders. The Student parser change ships in the same PR (`S10-T9`).

### 14.3 Parent — `GET /api/v1/parent/children/{student}/topics/{topic}/result`

New `parent` route group (role Parent, same Institution). Access: a current relationship with the
Student and the §14.1 access of that Student to the Topic; otherwise `404`. `{"data": null}` when the Student has no
Topic result or the Parent mode is `hidden` or unconfigured. Otherwise the §14.1 shape with values only
when visible to the Parent (§11.2).

## 15. Error Codes

| Code | Status | Used by |
|---|---|---|
| `result_closed` | 409 | §13.2 guards, comment edit |
| `result_not_ready` | 409 | Single release when not terminal or outside the window |
| `result_not_ready_for_closure` | 409 | Single close when not closable |
| `student_result_not_released` | 409 | Parent release while values are hidden from the Student |
| `manual_release_not_allowed` | 409 | Release when the current mode is not `manual_teacher` |
| `official_homework_not_activated` | 409 | Official Blitz activation while the official Homework is a draft (§13.4) |
| `homework_not_submitted` | 409 | Official Blitz Start without a submitted Homework Attempt (§13.4) |

Removed from the `docs/09` catalogue: `result_not_visible` and `category_configuration_invalid` (no
endpoint returns them; missing settings are status `waiting_for_settings`). Category-set validation keeps
its `422` rules.

## 16. Settings Changes (`S10-D6`)

- `PUT /institution/settings/assessment` and `PUT /institution/understanding-categories` keep their
  contracts. Every open result uses the new T and ranges on its next read; closed results never change.
- A release-mode change acts on every result immediately; existing Teacher releases stay. Example:
  automatic → manual hides values the Student saw only through the automatic mode until the Teacher
  releases them.
- No per-result rule or mode snapshot exists before closure: remove `*_release_mode_used`,
  “explicitly recalculated” (`BR-CAT-014`, `docs/04` Institution category flow), “saved or current
  rule” (`BR-CMP-015`) and “when calculated or closed” (`docs/06` Rule Snapshots) in favor of this rule.

## 17. Deployment (`docs/07` §36)

Stage 10 adds one migration (`topic_results` and the `attempt_answers` non-empty feedback check of
§18) and the `parent` route group; no Scheduler entry, queue or backfill (open results are live).
Rollback drops both.

## 18. Carried Items

| Item | Disposition |
|---|---|
| Topic-result feedback, Parent flag | `S10-D1` |
| Practice results under `manual_teacher` | `S10-D4` |
| Live re-check at closure | §12.6 (closure computes live inside its transaction) |
| `409 result_closed` | §13.2 |
| Blitz closed without #2 → Not completed | §7.2 Blitz row 9 |
| `topic_results` reference rule | `S10-T2` |
| Review-queue Topic, group, Student filters | Stage 10 frontend plan (the API already accepts them) |
| `CL9-9` real-concurrency tests | `S10-BE-004` |
| Homework before Blitz (owner, planning) | `S10-D8`, §13.4, `S10-BE-004` |
| `PH2-4` consolidate official and visibility rules | `S10-BE-001` (§11.3 is the single rule) |
| `CL9-10` status visible under `manual_teacher` | Accepted (`BR-STAT-018`, §11.3) |
| `CL9-11` hardening | `S10-BE-001`: the check `attempt_answers.feedback is null or feedback <> ''`; and a Teacher text value that is blank after trimming the Unicode whitespace set (U+0009–U+000D, U+0020, U+0085, U+00A0, U+1680, U+2000–U+200A, U+2028, U+2029, U+202F, U+205F, U+3000, U+FEFF — the Student-answer set) is rejected with the error the request already returns for an ASCII-blank value, for: Question `prompt`, choice `options[].text`, short-written `accepted_answers[]`, matching `pairs[].left`/`right`, ordering `items[].text`, fill-in-blank `blanks[].accepted_answers[]`, Homework/Blitz `title` and `student_instructions`, Blitz exception `reason`. Stored values are never rewritten; answer-feedback trimming is unchanged |
| Frontend Phase 2 carried P3 | Stage 10 frontend plan |
| `PH2-1` sweep scan bound | Stage 13 release readiness (unchanged) |

## 19. Known Places to Change

From the planning surveys (line numbers on `ccab413`; search for the topic, the lines may move):

- `docs/05`: `BR-CAT-011` and the `BR-ATT-020` bullet (§8.1 note), `BR-STAT-021` (`:1630`, release
  condition), `BR-Q-039` (`:891`), `BR-INST-016B` (status `waiting_for_settings`), `BR-INST-018`,
  `BR-CMP-013..015`,
  `BR-RES-007` (comment), `BR-RES-008` (two methods), `BR-RES-011` (closable, blocks), `BR-CAT-009`
  (“assign”, §7.2), `BR-CAT-013/014`, `BR-STAT-005..010` (§§7-8, seven statuses), `BR-STAT-013..020`
  (window, Parent, no hiding, §11.3), `BR-HW-025` (Parent sees the Topic-result comment, not answer
  feedback), `BR-Q-039`, `BR-SUB-010`, `BR-TOP-010` (archive closes terminal results), the
  `docs/05:1870` message.
- `docs/08`: §20.2 `topic_results` (rewrite to §10.1), §21.1, §22, §23.9, §25.13-25.14 (FKs), §27.8
  indexes, DEC-06/DEC-07, the relationship summary, `docs/08:2067` and `:3142`.
- `docs/09`: §2.13 numbers, §5.1 catalogue, §17/§20 visibility notes, §19.3 grant conflicts, §23.2
  correction conflict, §25.1-25.2 pair conflict, §25.3-25.6 (rewrite to §12; remove §25.5), §26 (remove
  `409 category_configuration_invalid`), §27 (rewrite), §29.3, §29.5, §30.4 (point to §14.3), Appendix A.
- `docs/07`: §§16.8-19, §25.2, §33 (races resolved by §13.1), §36, the action/class lists (no
  `CalculateTopicResult` job or recalculate action).
- Topic archive (§12.8) in `BR-TOP-010`, `docs/09` Topic archive section and `docs/04` Topic lifecycle flow.
- `S10-D8` in every owning place: `docs/05` Blitz activation and Start rules (`BR-BLZ-*`, `BR-ATT-*`
  start rules), Homework close (`BR-HW-012`: also closed by the official Blitz activation); `docs/09`
  Blitz activation and Student Blitz Start sections (new conflicts); `docs/04` Teacher Blitz activation
  flow (warning that the official Homework will be closed) and Student Blitz flow; `docs/01`/`03` process
  description; `docs/08` Homework close notes (the activation close uses `task_closed_auto_finalize` and
  records no actor) and the Topic archive notes (§12.8).
- `docs/04`: Institution category flow (`:636-640`), Teacher result and release flows, Student and
  Parent result flows (`:1548`, `:1880`, `:2331`), Teacher Feedback Viewing Flow (`:1914-1918`), result
  status flow (`:3788-3800`), consistency wording (`:3817`).
- `docs/02`, `docs/03`, `docs/01`: Student/Parent “what is visible” lists (`02:449-457` drops
  consistency), Parent feature 12, “possible outside help” wording (`03:1080`).
- `docs/06` Stage 10: dependencies (carried list → §18), scope (statuses, visibility window, comment,
  bulk, archive closure, live results), Required Tests (§20 list).

## 20. Acceptance Criteria

- [ ] Every rule in §§5-18 is stated in its owning document and no document contradicts it.
- [ ] No document still describes stored/recalculated open results, a recalculate endpoint,
      `*_release_mode_used`, `topic_results` references to `official_task_scores`, a hide/unrelease
      action, four calculation methods, `category_configuration_invalid` or `result_not_visible`.
- [ ] The Stage 10 roadmap “Required Tests” list adds: side-state and status precedence tables,
      `waiting_for_settings`, the visibility window, release modes after a mode change, release
      idempotency, Parent `hidden` returns nothing, Attempt visibility under §11.3, practice tasks in
      manual mode, comment rules, bulk skip counts, closure snapshot, closure only with finished work,
      archive auto-close, every §13.2 guard, first review after closure, the closure races (`S10-T6`)
      and `CL9-9`, the official Blitz activation closing the official Homework, the draft-Homework
      activation conflict, and the Blitz Start without a submitted Homework.
- [ ] Stage 1-9 statements are unchanged except the edits named in §§8.1, 11, 12.8, 13 and 14.
- [ ] An independent fresh-context review finds no remaining contradiction between `docs/01`–`09` on
      Stage 10 behavior (P1 = 0, P2 = 0).

## 21. Expected Files

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
tasks/S10-DOC-001-stage-10-topic-results-contract-alignment.md
tasks/STAGE_10_TASK_INDEX.md
```

## 22. Verification

```text
git diff --check
grep for every removed term: release_mode_used, recalculate, result_not_visible,
  category_configuration_invalid, official_homework_score_id, official_blitz_score_id,
  "hiding", "unrelease" (only the §27.7-style prohibition may remain), "explicitly recalculated"
fresh-context read-only review of docs/01-09 against this contract
```

No code, test or build runs: the task changes documentation only.
