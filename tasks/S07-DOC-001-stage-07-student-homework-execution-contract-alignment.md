# S07-DOC-001 — Stage 7 Student Homework Execution Contract Alignment

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S07-DOC-001` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Documentation / contract alignment` |
| Status | `Approved` |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Depends on | `Stage 6 CLOSED / PASS` + approved Stage 7 decomposition |
| Blocks | `S07-BE-001` |
| Production code / migrations / API implementation | `Forbidden` |
| Verification | `Documentation diff only` |
| Delivery execution | `Project Owner / Codex only as exact documentation editor` |

This task aligns the already-approved Stage 7 Homework execution contract into the live MVP docs before Student Homework implementation begins. It does **not** reopen product design.

This file is the complete task-specific contract. Codex may inspect only the exact in-scope live-document text needed to place these edits safely. Do not use product/roadmap/architecture/database/API docs to discover or reinterpret requirements.

Do not create a duplicate `CODEX-PROMPT`.

---

# 2. Locked Stage Boundary

```text
Stage 7 = Student Homework execution, saved-answer/file persistence,
          immutable submission/finalization, deadline/Teacher-close
          reconciliation, retry/idempotency safety

Stage 9 = Homework answer checking, awarded points, Teacher review,
          Attempt scoring, official Homework score selection/reselection
```

Stage 7 creates trustworthy historical Student submission records; Stage 9 later consumes them for checking/scoring.

Before public Student Attempt Start is exposed, the live docs must encode all of these invariants:

1. at most one `in_progress` Attempt per Student/Homework;
2. first Attempt on the official Homework atomically locks the staged Topic result-pair/cohort meaning;
3. deadline and Teacher close auto-finalize existing `in_progress` Attempts instead of rejecting closure;
4. Stage 7 finalization freezes only already-committed Student work;
5. unanswered Questions require no fabricated answer row;
6. Start and final Submit use durable DB-backed idempotency;
7. request-path deadline reconciliation and Scheduler use the same authoritative behavior;
8. Submit/deadline/Teacher-close races yield exactly one finalization;
9. answer/file mutation cannot commit after the Attempt is frozen;
10. a late high-risk request may commit required deadline reconciliation while still returning failure and leaving no incomplete idempotency claim;
11. this task must not change Blitz semantics.

---

# 3. Scope and Preservation Rules

Modify only:

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
```

Do not modify:

```text
docs/FINAL_AUDIT_REPORT.md
```

or source code, migrations, tests, harnesses, prior task files, Stage 6 closure evidence, `tasks/README.md`, or unrelated Stage bookkeeping.

### Combined Homework/Blitz wording

Some current rules mention Homework and Blitz together. If such wording must change:

- split it when necessary;
- apply this contract only to Homework;
- preserve all existing Blitz lifecycle/timer/timeout/finalization/checking/scoring/exception semantics;
- preserve `timed_out_finalized` / `timeout_auto_submit` as Blitz concerns;
- do not reinterpret Stage 8+ Blitz ownership.

No documentation edit may accidentally convert a Blitz rule into the Stage 7 Homework contract.

---

# 4. Stage 7 Ownership

## 4.1 Stage 7 owns

- Student Homework list/detail execution surfaces;
- Student-safe Question projection with no correct-answer leakage;
- Start/resume with fixed normal Attempts `1..3`;
- one current `in_progress` Attempt per Student/Homework;
- typed answer save/replace;
- private file-answer save/replace/download authorization;
- explicit final Submit;
- deadline reconciliation;
- Teacher-close auto-finalization;
- immutable historical Attempt after finalization;
- first official Homework Attempt result-pair lock;
- DB-backed high-risk idempotency;
- tenant/Student ownership;
- concurrency-safe finalization and write exclusion.

## 4.2 Stage 7 does not own

Do not describe any of these as immediate Stage 7 work:

```text
automatic correctness evaluation
partial credit
attempt_answers.awarded_points
Teacher manual review / feedback / checked metadata
waiting_for_teacher_review
checked
assessment_attempts.earned_points
assessment_attempts.normalized_score
assessment_attempts.scoring_completed_at
official Homework score selection/reselection
official_task_scores
dependent Topic result recalculation
Homework–Blitz comparison
final Topic result/release
```

For Homework these are Stage 9+ responsibilities.

Approved full-MVP scoring rules remain documented, but with this timing:

```text
Stage 7 freezes Student work.
Stage 9 later checks it, treats missing answers as zero under the
approved policy, performs required Teacher review, and computes/selects
the Homework score.
```

Stage 7 does not fabricate missing `attempt_answers` rows merely to encode zero.

---

# 5. Homework Attempt Lifecycle

## 5.1 Editable

```text
status = in_progress
finalized_at = null
locked_at = null
```

Student answer/file mutation is allowed only while this state and all assignment/lifecycle/deadline rules remain valid.

## 5.2 Frozen Stage 7 state

All Stage 7 Homework finalization paths end as:

```text
status = submitted
finalized_at = non-null
locked_at = finalized_at
```

Reasons:

```text
student_submit
task_closed_auto_finalize
homework_deadline_auto_submit
```

`submitted` means frozen Student work ready for later checking. It does **not** imply the Student pressed Submit or that checking/scoring completed.

`submitted_at` is set only for explicit Student Submit.

## 5.3 Explicit Submit

Capture one server instant:

```text
finalizedAt = server_now

status = submitted
submitted_at = finalizedAt
finalized_at = finalizedAt
locked_at = finalizedAt
finalization_reason = student_submit
```

Persisted answers remain `pending`.

## 5.4 Deadline

When:

```text
server_now >= homework_assignments.deadline_at
```

freeze each current `in_progress` Attempt using the authoritative deadline:

```text
status = submitted
submitted_at = null
finalized_at = homework_assignments.deadline_at
locked_at = homework_assignments.deadline_at
finalization_reason = homework_deadline_auto_submit
```

Scheduler/reconciliation latency must not change the historical deadline instant.

## 5.5 Teacher close before deadline

Capture:

```text
closedAt = server_now
```

and atomically freeze all still-`in_progress` Attempts:

```text
status = submitted
submitted_at = null
finalized_at = closedAt
locked_at = closedAt
finalization_reason = task_closed_auto_finalize
```

Attempt finalizations and Homework close commit in the same transaction and roll back together.

## 5.6 Deadline precedence

On Teacher close:

1. lock authorized Homework/Attempts;
2. if deadline is already reached, reconcile deadline first;
3. deadline-finalized Attempts keep `homework_deadline_auto_submit` and `deadline_at`;
4. only still-`in_progress` Attempts for a pre-deadline close use `task_closed_auto_finalize`.

A delayed Scheduler or later close must never rewrite the earlier semantic event.

## 5.7 Later checking

Only later Stage 9 Homework checking may move:

```text
submitted
```

to:

```text
waiting_for_teacher_review
checked
```

Do not use `timed_out_finalized` / `timeout_auto_submit` for Stage 7 Homework.

---

# 6. Answer/File Persistence and Freeze Boundary

Saved/replaced Student answers remain:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

If the Student never saved a Question:

```text
no attempt_answers row is required
```

Submit/deadline/close finalization must not rewrite answer payloads, replace a Student file answer, expose/insert correct-answer configuration, calculate points, create Teacher-review metadata, or change `checking_status`.

### Write vs finalization race

For:

```text
answer/file mutation
vs
Submit/deadline/Teacher close
```

the only valid outcomes are:

```text
Student mutation commits first
=> that committed answer/file state is part of the frozen Attempt

finalization commits first
=> later Student mutation performs zero answer/file-domain mutation
   and returns the documented lifecycle/deadline/editability conflict
```

Never allow:

```text
frozen Attempt + Student answer/file mutation committed afterward
```

The technical docs must require serialization through the relevant Homework/Attempt lock boundary with lifecycle, authoritative-time, and Attempt-editability re-check after required locks.

A rejected file replacement must not change the persisted answer/file identity/content. Cleanup of transient upload bytes is left to the file implementation task.

---

# 7. Attempt Start / Resume

For:

```text
assessment_id + student_id
```

at most one Attempt may have:

```text
status = in_progress
```

Document a PostgreSQL partial unique index equivalent to:

```text
unique (assessment_id, student_id)
where status = 'in_progress'
```

Application locking remains mandatory.

Start semantics:

```text
no in_progress + rules valid
=> next_attempt_number = max(existing attempt_number) + 1
=> maximum 3
=> 201 Created

existing in_progress
=> return same Attempt
=> 200 OK
=> no extra attempt usage

no in_progress + attempts 1,2,3 already exist
=> 409 attempts_exhausted
```

Attempt-number allocation must be concurrency-safe.

### First official Homework activity lock

When creating the first Attempt for the Homework referenced by:

```text
topic_result_pairs.homework_assessment_id
```

the same transaction must:

- resolve/lock the pair in the same Institution/Topic;
- require `cohort_snapshotted_at` non-null;
- require Student membership in the persisted official Homework recipient cohort;
- if `locked_at` is null, set `locked_at = startedAt` and `updated_at = startedAt`;
- use the same `startedAt` as the new Attempt;
- preserve an already non-null `locked_at`;
- allow `blitz_assessment_id = null`;
- never replace official Homework/cohort identity;
- never create a Blitz.

Structural pair/cohort inconsistency fails atomically; do not repair/resnapshot silently. Practice Homework does not mutate `topic_result_pairs`.

---

# 8. Durable Idempotency

## 8.1 Required operations

Require:

```text
Idempotency-Key: <client-generated-uuid>
```

for:

```text
POST /api/v1/student/homework/{homework}/attempts
POST /api/v1/student/attempts/{attempt}/submit
```

Missing/malformed → `422 validation_failed`.

Ordinary answer/file PUTs do not use this header in Stage 7.

## 8.2 Persistence

Use durable PostgreSQL persistence, not process/request/Flutter/cache-only/timing state.

Document `idempotency_records` with:

| Column | Type | Null |
|---|---|---:|
| `id` | uuid | no |
| `institution_id` | uuid | no |
| `user_id` | uuid | no |
| `operation` | varchar(80) | no |
| `idempotency_key` | uuid | no |
| `request_fingerprint` | char(64) | no |
| `result_resource_type` | varchar(80) | yes |
| `result_resource_id` | uuid | yes |
| `response_status` | smallint | yes |
| `completed_at` | timestamptz | yes |
| `created_at` | timestamptz | no |
| `updated_at` | timestamptz | no |

Required:

```text
institution_id -> institutions.id
user_id        -> users.id

unique(institution_id, user_id, operation, idempotency_key)

index(institution_id, user_id, operation, created_at)
```

Do not create a generic FK for `result_resource_id`.

Add the table to high-risk direct Institution ownership.

MVP retention:

```text
do not automatically expire/delete completed records
```

Operation codes:

```text
student.homework.attempt.start
student.homework.attempt.submit
```

## 8.3 Fingerprint/replay

Fingerprint includes deterministic semantic identity:

```text
operation
authenticated institution
authenticated user
route target UUID(s)
normalized semantic body fields, if any
```

Do not include secrets, Authorization tokens, or the idempotency key itself.

Same scope/key/fingerprint:

- no second domain mutation;
- return same logical resource;
- preserve original successful semantic HTTP status;
- current safe serialization is allowed.

Same scope/key but different fingerprint:

```text
409 idempotency_key_reused
```

with zero domain mutation.

## 8.4 Transactional claim

A successful protected Start/Submit and its idempotency claim/result must commit atomically. Use conflict-safe PostgreSQL claiming (`INSERT ... ON CONFLICT` or equivalent).

Never commit:

```text
successful protected mutation + missing/incomplete idempotency result
```

and never deliberately commit an incomplete claim.

## 8.5 Late high-risk request + deadline reconciliation

This case must be explicit because “request failed” does **not** mean required deadline reconciliation may roll back.

If Start/Submit discovers under authoritative locking/time re-check that the deadline is already reached:

1. required deadline reconciliation **must commit**;
2. the late Start/Submit still returns the documented failure, normally `409 deadline_passed`;
3. no new completed idempotency success record is created for that failed operation;
4. no new incomplete idempotency claim remains committed.

Allowed designs:

```text
A. reconcile before acquiring a new claim
```

or:

```text
B. if a new incomplete claim was already acquired,
   abandon/remove only that new claim,
   commit deadline reconciliation,
   then surface the failure after commit
```

Never delete a previously completed idempotency record.

Do not throw inside the reconciliation transaction if doing so would roll back required deadline finalization.

A valid replay of a previously committed pre-deadline success may still return that prior success after deadline because replay performs no new domain mutation.

## 8.6 Authorization remains mandatory

Idempotency never bypasses authentication, active-account/password-change middleware, Student role, Institution isolation, or assignment/ownership checks.

Lookup scope is:

```text
institution_id + user_id + operation + idempotency_key
```

Never query globally by key and authorize afterward.

---

# 9. Deadline, Close, and Concurrency

Authoritative deadline rule:

```text
server_now < deadline_at  => write/start may continue if other rules pass
server_now >= deadline_at => deadline passed
```

Device time is irrelevant.

Use one authoritative reusable deadline reconciliation behavior, e.g.:

```text
FinalizeHomeworkAttemptsAtDeadline
```

for:

- relevant Student Homework/Attempt reads;
- Attempt Start;
- answer mutation;
- file-answer mutation;
- final Submit;
- Teacher close when deadline may have passed;
- Laravel Scheduler.

Every write independently enforces deadline; Scheduler latency cannot extend eligibility.

At deadline:

- finalize existing `in_progress` Attempts only;
- create no Attempt for never-started Students;
- unused capacity becomes unavailable;
- new Start → `409 deadline_passed`;
- no new Student answer/file/Submit mutation may alter the frozen Attempt.

### Terminal races

Exactly one terminal transition must result from:

```text
Student Submit
deadline reconciliation/Scheduler
Teacher close
```

Required architecture: transaction, deterministic relevant row locks, state re-read and authoritative-time re-check after locking, transition only from `in_progress`, preserve already committed reason/timestamps.

Outcomes:

```text
Submit validly commits first before deadline/close
=> student_submit stays authoritative

deadline already reached when locked state is evaluated
=> homework_deadline_auto_submit wins

Teacher close validly commits first before deadline/Submit
=> task_closed_auto_finalize stays authoritative
```

### Write races / no-op rules

Also preserve:

- answer/file mutation vs finalization follows Section 6;
- concurrent same-key Start → one logical Attempt;
- concurrent different-key Start → still at most one `in_progress`; later valid Start resumes;
- attempt numbers cannot duplicate/skip because of race;
- concurrent same-key Submit → one finalization;
- repeated deadline reconciliation → no writes after reconciliation;
- repeated close → no frozen timestamp/reason rewrite;
- idempotent replay → no domain timestamp churn.

---

# 10. Security / Privacy

Preserve all of these for Student Homework/Attempt/Answer/File operations:

- `role = student`;
- active account/Institution middleware;
- authenticated Student Institution is authoritative;
- Student must be an `assessment_students` recipient;
- Attempt belongs to the same Student and Assessment;
- Question belongs to that Assessment;
- answer child IDs/options/items/blanks belong to the same Question/Institution;
- direct UUID possession never grants access;
- another Student's/cross-Institution Attempt/File does not leak existence/content;
- protected file download remains backend-authorized;
- no correct-answer/checking configuration is exposed while Student answers.

Frozen `assessment_students` assignment/history remains authoritative where specified; current Group membership must not silently replace it.

---

# 11. Exact Live-Document Edit Map

Use Sections 2–10 as authoritative. Do not restate them differently.

| Document | Required edit |
|---|---|
| `docs/01-business-overview.md` | Homework close/deadline freezes saved work; no fake Attempt/answer rows; no Stage 7 scoring; Stage 9 later checks/scores and treats missing answers as zero. Preserve unrelated/Blitz wording. |
| `docs/02-user-roles.md` | Replace deadline “scores unanswered as zero” with Stage 7 freeze/no-fake-row/no-scoring + Stage 9 later checking. Keep exactly 3 Homework Attempts and role/visibility rules. |
| `docs/03-features.md` | Homework deadline freezes saved answer set as `submitted`, blocks later starts/writes, leaves answers pending; Stage 9 later checks/scores/reviews. Preserve Blitz features. |
| `docs/04-user-flows.md` | Student opens assigned active Homework → sees server deadline/availability → Start/resume → first official Attempt locks pair/cohort → saves typed/file answers → explicit Submit or deadline/close freeze → immutable `submitted` Attempt → Stage 9 later checking/scoring. |
| `docs/05-business-rules.md` | Align `BR-HW-012`, `BR-HW-016`, Submit, one-in-progress rule, no fabricated rows, deadline/close reasons, Scheduler reuse, write-vs-freeze race. |
| `docs/06-roadmap.md` | Stage 7 = Student Homework execution/immutable submission, not checking/scoring/official score. Add Start/resume, 3 Attempts, one `in_progress`, nine answer types, file privacy, finalization, idempotency, pair lock, tenant safety, terminal/write races. Stage 9 consumes frozen Homework history. Do not alter Stage 8 Blitz or Stage 10 Topic-result scope. |
| `docs/07-architecture.md` | Execution history separated from checking engine; shared Homework finalization/deadline behavior; write-vs-freeze serialization; DB-backed idempotency including Section 8.5; tenant-first access; first official pair lock. Split combined Homework/Blitz paragraphs as needed without changing Blitz. |
| `docs/08-database.md` | Lifecycle ownership, partial unique one-`in_progress` index, pending answer fields/no fabricated answer row, exact `idempotency_records` schema/constraints/ownership/retention and table ordering. |
| `docs/09-api-contracts.md` | Stage 7 Homework boundary; Start 201/200 + idempotency; own Attempt read; answer/file PUT remains pending/no late mutation; Submit returns `submitted`/no score; exact deadline/close behavior; Section 8.5 late-request semantics; write-vs-freeze race; preserve Blitz APIs. |

## 11.1 Required `docs/08-database.md` lifecycle wording

Keep stored statuses:

```text
in_progress
submitted
timed_out_finalized
waiting_for_teacher_review
checked
```

Clarify:

```text
Stage 7 Homework:
  in_progress -> submitted

Stage 9 Homework checking:
  submitted -> waiting_for_teacher_review / checked

Blitz:
  timed_out_finalized remains reserved for its own contract
```

Also document the one-in-progress partial unique index and the exact `idempotency_records` contract from Section 8.

## 11.2 Required `docs/09-api-contracts.md` Homework API semantics

Stage 7 Student Homework APIs must explicitly say a frozen Homework Attempt remains `submitted` and checking/score completion is unavailable until Stage 9.

Start:

```text
POST /api/v1/student/homework/{homework}/attempts
Idempotency-Key: <client-generated-uuid>

201 Created -> new Attempt
200 OK      -> existing in_progress Attempt returned/resumed
409 attempts_exhausted
409 deadline_passed
```

Save/replace answer:

```text
PUT /api/v1/student/attempts/{attempt}/answers/{question}
```

Only own assigned editable `in_progress` Homework Attempt may mutate. Preserve per-type structural validation, Multiple Choice cap, no answer-key leakage, `checking_status = pending`, and Section 6 race semantics.

File answer remains private and ungraded in Stage 7; replacement obeys Section 6.

Submit:

```text
POST /api/v1/student/attempts/{attempt}/submit
Idempotency-Key: <client-generated-uuid>
```

Success equivalent:

```json
{
  "data": {
    "id": "attempt-uuid",
    "attempt_number": 1,
    "status": "submitted",
    "submitted_at": "2026-09-08T12:00:00Z",
    "finalized_at": "2026-09-08T12:00:00Z",
    "finalization_reason": "student_submit",
    "checking": {
      "completed": false
    },
    "score": {
      "normalized_score": null,
      "visible_to_student": false
    }
  },
  "message": "Homework submitted successfully."
}
```

After success: immutable Student work, saved answers remain pending, no Stage 7 checking; another normal Attempt may start only if capacity/lifecycle/deadline rules permit.

Deadline contract must include:

```text
new Starts blocked
Student answer/file writes blocked
existing in_progress Attempts -> submitted
submitted_at = null
finalized_at = locked_at = exact deadline_at
finalization_reason = homework_deadline_auto_submit
no fabricated Attempt/answer row
no Stage 7 checking/scoring
unused capacity unavailable
request-path + Scheduler share same behavior
terminal/write races are deterministic
```

Teacher close must replace the Stage 6 temporary reject-on-in-progress behavior:

```text
before deadline:
  atomically freeze in_progress Attempts with task_closed_auto_finalize
  + close Homework

at/after deadline:
  reconcile deadline first
  and preserve homework_deadline_auto_submit + deadline timestamp
```

Public Student Attempt Start is not deliverable while production Teacher close still only rejects `in_progress` Attempts.

General idempotency must document:

```text
missing/malformed key -> 422 validation_failed
same scope/key/fingerprint -> same logical result, no second mutation
different fingerprint reuse -> 409 idempotency_key_reused
durable DB persistence
authorization still required
Section 8.5 late-request reconciliation semantics
```

---

# 12. Non-Goals

Do not add/redesign:

- Stage 8 Blitz implementation or semantics;
- Stage 9 checking implementation / Teacher review endpoints / official score implementation;
- Stage 10 Topic result;
- AI/fuzzy grading;
- new Question types;
- configurable Homework attempt counts;
- more than one file per file answer;
- public Student-submission storage;
- new roles/permissions;
- frontend implementation beyond documenting API expectations;
- source code/migrations/tests/harnesses/dependencies;
- unrelated doc cleanup.

---

# 13. Acceptance Criteria

### Stage boundary
- Stage 7 Homework execution/finalization is separate from Stage 9 checking/scoring.
- No Stage 7 Submit/deadline/close wording still requires immediate `checked` or `waiting_for_teacher_review`.
- Full-MVP later scoring remains documented.
- Blitz semantics remain unchanged.

### Attempt lifecycle
- Stage 7 Homework finalizes to `submitted`.
- `submitted_at` is explicit-Student-only.
- deadline uses exact `deadline_at`; pre-deadline close uses captured close instant.
- `timed_out_finalized` / `timeout_auto_submit` are not repurposed for Homework.
- frozen reason/timestamps are not rewritten.

### Answers/files
- saved answers remain `pending`; Stage 7 writes no awarded points/check metadata.
- no fabricated unanswered row.
- finalization does not rewrite Student answer/file state.
- answer/file write vs finalization has the exact atomic outcome in Section 6.
- no Student write can commit after freeze.

### Start/resume
- one `in_progress` per Student/Homework + partial unique index.
- Start creates next Attempt or resumes existing; maximum exactly 3.
- first official Homework Attempt locks pair/cohort meaning atomically.

### Idempotency
- exact `idempotency_records` schema/constraints/index/retention documented.
- same request replays; different fingerprint reuse → `409 idempotency_key_reused`.
- successful protected mutation + idempotency result commit atomically.
- no committed incomplete claim.
- late high-risk request can commit required deadline reconciliation without leaving a new successful/incomplete claim.
- replay of prior success may remain valid after deadline without new mutation.
- auth/tenant ownership is never bypassed.

### Deadline/close/concurrency
- request paths + Scheduler share one authoritative deadline behavior.
- historical deadline finalization uses deadline timestamp, not delayed processing time.
- Teacher close auto-finalizes instead of rejecting Student work.
- deadline wins once already reached.
- no fabricated Attempt for never-started Student.
- Submit/deadline/close yields one terminal transition.
- answer/file mutation cannot violate immutable history.

### Scope
- only `docs/01-business-overview.md` through `docs/09-api-contracts.md` changed.
- `docs/FINAL_AUDIT_REPORT.md`, code, migrations, tests, harnesses, prior tasks unchanged.
- no unrelated rewrite and no Blitz semantic change.

---

# 14. Verification

No application tests/builds are required.

Run:

```bash
git diff --check
```

Confirm changed filenames are limited to the nine approved live docs.

Focused text review must confirm:

```text
Stage 7 Homework execution vs Stage 9 checking/scoring
status = submitted
homework_deadline_auto_submit
task_closed_auto_finalize
one in_progress Homework Attempt
idempotency_records
student.homework.attempt.start
student.homework.attempt.submit
Idempotency-Key
FinalizeHomeworkAttemptsAtDeadline or equivalent
answer/file write vs finalization protection
late-request deadline reconciliation without incomplete claim
Blitz semantics preserved
```

Search for stale contradictory Homework wording equivalent to:

```text
Stage 7 Submit immediately auto-checks answers
Homework deadline immediately checks/awards points
Homework close immediately moves to checked/waiting review
Homework uses timed_out_finalized/timeout_auto_submit
Student answer/file write may commit after finalization
```

Inspect every changed paragraph that mentions both Homework and Blitz and confirm Blitz behavior was not altered.

Do not run backend/frontend tests, builds, broad E2E, or full suites.

---

# 15. Delivery Checklist

Codex reports:

1. exact changed docs;
2. concise Stage 7/Stage 9 alignment summary;
3. confirmation code/migrations/tests/harnesses were untouched;
4. confirmation Blitz semantics were preserved;
5. `git diff --check`;
6. focused required-term/stale-wording review;
7. final `git status --short`;
8. focused diff self-check for no Stage 8/9 implementation or unrelated rewrite.

After delivery, ChatGPT performs read-only acceptance review.

`S07-BE-001` remains blocked until:

```text
S07-DOC-001 = Accepted / Delivered
```
