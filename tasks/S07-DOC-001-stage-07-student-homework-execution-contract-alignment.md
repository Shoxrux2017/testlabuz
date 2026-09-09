# S07-DOC-001 — Stage 7 Student Homework Execution Contract Alignment

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S07-DOC-001` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Documentation / contract alignment` |
| Status | `Approved` |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Depends on | `Stage 6 CLOSED / PASS` and approved Stage 7 decomposition |
| Blocks | `S07-BE-001` implementation |
| Production code changes | `Forbidden` |
| Migration/schema implementation changes | `Forbidden` |
| API implementation changes | `Forbidden` |
| Verification | `Documentation diff only` |
| Delivery execution | `Project Owner / Codex only as exact documentation editor` |

This task synchronizes the already-approved Stage 7 execution boundary into the locked MVP product and technical documentation before Student Homework implementation begins.

It does **not** reopen product design.

Codex must not read the affected documents to discover or reinterpret product, architecture, API, persistence, lifecycle, security, scoring, or concurrency decisions. All required decisions are stated below. Codex may inspect only the exact in-scope document text needed to place the prescribed edits safely and keep nearby wording consistent.

Do not create a duplicate `CODEX-PROMPT` file.

---

# 2. Goal

Align the documentation around one strict Stage boundary:

```text
Stage 7 = Student Homework execution, saved-answer persistence,
          file-answer persistence, immutable submission/finalization,
          deadline/Teacher-close reconciliation, retry/idempotency safety

Stage 9 = answer checking, awarded points, Teacher review,
          Attempt scoring, official Homework score selection/reselection
```

Stage 7 must create trustworthy historical submission records without prematurely implementing Stage 9 scoring.

The documentation must also make the following implementation prerequisites explicit before public Student Attempt start is exposed:

1. one Student may have at most one `in_progress` Attempt for the same Homework at a time;
2. the first Attempt on the official Homework atomically locks the staged Topic result-pair meaning/cohort;
3. Homework deadline and Teacher close auto-finalize existing `in_progress` Attempts instead of rejecting closure;
4. finalization freezes only the Student answer set in Stage 7;
5. no unanswered-answer rows are fabricated merely to represent zero score;
6. high-risk Attempt Start and final Submit use durable database-backed idempotency;
7. the same idempotent deadline-finalization action is used by request-path reconciliation and Laravel Scheduler;
8. race conditions produce exactly one logical finalization.

---

# 3. Documents in Scope

Current-main readiness review at the planning baseline found direct Stage 7 / Stage 9 boundary contradictions in the live overview/role/feature documents as well as the detailed technical docs.

Therefore the final implementation scope is now explicit:

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

All edits must be narrowly targeted to the Stage 7 execution-vs-Stage 9 checking/scoring alignment in this contract. Do not broadly rewrite these documents.

### 3.1 Required correction in `docs/01-business-overview.md`

Current live wording says, in effect, that closing active Homework auto-finalizes saved work and **gives zero to unanswered components** in the close operation.

Replace that causal wording so the document says:

```text
Stage 7 close/deadline finalization freezes already-saved Student work
and creates no fake Attempt/answer rows.

Stage 9 later treats missing answers as zero and applies the approved
automatic/manual checking rules to the frozen answer set.
```

General full-MVP statements about automatic/manual checking and final results remain valid when clearly described as later processing.

### 3.2 Required correction in `docs/02-user-roles.md`

The current `Homework attempts` text explicitly says that deadline finalization **scores unanswered components as zero**, and nearby deadline bullets say saved answers are evaluated normally / unanswered Questions receive zero points.

Replace those immediate-scoring statements with the locked Stage 7 behavior:

```text
deadline freezes an existing in_progress Homework Attempt from saved work;
no fake Attempt is created;
no Stage 7 checking/scoring occurs;
missing answers remain absent;
Stage 9 later treats missing answers as zero and checks saved answers.
```

Keep the fixed three-attempt and Student visibility rules.

### 3.3 Required correction in `docs/03-features.md`

The current Student Homework feature text says that when the authoritative Homework deadline arrives, Laravel auto-finalizes saved work, **scores unanswered components as zero**, and preserves manual-review answers for Teacher checking.

Replace that wording with:

```text
Laravel freezes the saved answer set as the Stage 7 submitted Attempt,
blocks later writes/starts, and leaves saved answers pending.

Stage 9 later performs automatic/manual checking, treats missing answers as
zero, and advances review/scoring state.
```

Keep the feature-level full-MVP description otherwise intact.

### 3.4 Historical audit exclusion

Do **not** modify:

```text
docs/FINAL_AUDIT_REPORT.md
```

It is historical audit evidence, not the live implementation contract.

Do not modify source code, migrations, tests, integration harnesses, prior task files, Stage 6 closure evidence, or `tasks/README.md` in this task.

---

# 4. Authoritative Stage 7 Boundary

The live docs must consistently distinguish submission finalization from checking/scoring.

## 4.1 Stage 7 owns

Stage 7 implements:

- Student Homework list/detail execution surfaces;
- Student-safe Question projection with no correct-answer leakage;
- Attempt start/resume;
- fixed normal Homework Attempt numbers `1..3`;
- exactly one current `in_progress` Homework Attempt per Student/Homework;
- typed saved-answer create/replace while editable;
- private file-based answer create/replace/download authorization;
- Student final Submit;
- Homework deadline reconciliation;
- Teacher close auto-finalization of saved work;
- immutable Attempt history after finalization;
- first official Homework Attempt result-pair locking;
- database-backed high-risk request idempotency;
- tenant and Student ownership enforcement;
- concurrency-safe exactly-once finalization.

## 4.2 Stage 7 does not own

Stage 7 must **not** implement:

- automatic correctness evaluation;
- partial-credit calculation;
- writing `attempt_answers.awarded_points`;
- Teacher manual review;
- Teacher feedback/checked metadata;
- transition to `waiting_for_teacher_review`;
- transition to `checked`;
- writing `assessment_attempts.earned_points`;
- writing `assessment_attempts.normalized_score`;
- writing `assessment_attempts.scoring_completed_at`;
- official Homework score selection/reselection;
- `official_task_scores` creation/update;
- dependent Topic result recalculation;
- Homework–Blitz comparison;
- final Topic result or release behavior.

Those remain Stage 9+ responsibilities.

## 4.3 Full-MVP scoring rules remain valid

Do not delete the approved eventual scoring policies from the docs.

Instead make their execution point explicit:

```text
Stage 7 freezes the answer set.
Stage 9 consumes that frozen answer set and applies the approved scoring/checking rules.
```

An unanswered Question still eventually contributes zero according to Stage 9 scoring rules, but Stage 7 does not need to fabricate an empty `attempt_answers` row or award zero points at finalization time.

---

# 5. Stage 7 Homework Attempt State Contract

## 5.1 Editable state

A Student-editable Homework Attempt is:

```text
status = in_progress
finalized_at = null
locked_at = null
```

The Student may save/replace answers only in this state and only while Homework assignment/lifecycle/deadline rules still allow writes.

## 5.2 Frozen Stage 7 Homework state

Every Stage 7 Homework finalization path ends the Student execution phase as:

```text
status = submitted
finalized_at = non-null
locked_at = finalized_at
```

This applies to:

```text
student_submit
task_closed_auto_finalize
homework_deadline_auto_submit
```

The reason is distinguished by `finalization_reason`, not by performing checking inside Stage 7.

`submitted` therefore means:

> the Homework Attempt has a frozen Student answer set and is ready for later checking.

It does **not** mean that the Student necessarily pressed Submit.

`submitted_at` distinguishes explicit Student submission from server auto-finalization.

## 5.3 Explicit Student Submit

Successful explicit Submit sets one captured server instant:

```text
finalizedAt = server_now

status = submitted
submitted_at = finalizedAt
finalized_at = finalizedAt
locked_at = finalizedAt
finalization_reason = student_submit
```

Stage 7 does not change answer checking state beyond leaving persisted answers `pending`.

## 5.4 Homework deadline auto-finalization

For an `in_progress` Homework Attempt when:

```text
server_now >= homework_assignments.deadline_at
```

finalization uses the authoritative Homework deadline instant:

```text
status = submitted
submitted_at = null
finalized_at = homework_assignments.deadline_at
locked_at = homework_assignments.deadline_at
finalization_reason = homework_deadline_auto_submit
```

Scheduler/reconciliation latency must not alter the effective deadline or make a late write valid.

## 5.5 Teacher close auto-finalization

When Teacher closes an active Homework before its deadline, use one captured close instant:

```text
closedAt = server_now
```

Every still-`in_progress` Attempt is atomically frozen as:

```text
status = submitted
submitted_at = null
finalized_at = closedAt
locked_at = closedAt
finalization_reason = task_closed_auto_finalize
```

Then the Homework close transition commits in the same transaction.

If the close transaction fails, its Attempt finalizations must also roll back.

## 5.6 Later Stage 9 transitions

Only later checking may move a frozen Homework Attempt from:

```text
submitted
```

to:

```text
waiting_for_teacher_review
checked
```

according to the Stage 9 checking contract.

## 5.7 `timed_out_finalized`

Do not use:

```text
timed_out_finalized
```

for Stage 7 Homework deadline or Teacher-close finalization.

That stored status remains reserved for the Blitz timeout semantics implemented in Stage 8+.

---

# 6. Answer Persistence Boundary

## 6.1 Answer rows while Student is editing

When a Student saves an answer, Stage 7 creates/replaces the typed persisted answer payload and keeps:

```text
attempt_answers.checking_status = pending
attempt_answers.awarded_points = null
attempt_answers.feedback = null
attempt_answers.checked_by_user_id = null
attempt_answers.checked_at = null
```

Student answer replacement before finalization must not perform scoring.

## 6.2 Unanswered Question

If the Student never saved an answer for a Question:

```text
no attempt_answers row is required for that Question
```

Do not create an empty synthetic answer row at Student Submit, Homework deadline, or Teacher close merely to encode zero.

Stage 9 scoring interprets an absent answer as unanswered and awards zero according to the existing approved scoring policy.

For a partially populated structured answer, Stage 9 applies its Question-type scoring rules to the persisted payload; Stage 7 remains responsible only for structural validity and persistence.

## 6.3 Finalization does not mutate answer payloads

Student Submit/deadline/close finalization must not:

- rewrite answer content;
- insert correct-answer configuration into Student rows;
- calculate awarded points;
- create Teacher review metadata;
- change `checking_status` from `pending`.

Finalization freezes what the Student already saved.

---

# 7. One In-Progress Homework Attempt Rule

For one pair:

```text
assessment_id + student_id
```

there may be at most one persisted Homework Attempt with:

```text
status = in_progress
```

at any time.

The database contract must add a PostgreSQL partial unique index equivalent to:

```text
unique (assessment_id, student_id)
where status = 'in_progress'
```

Application transaction/locking remains mandatory; the partial unique index is the final structural guard.

A Student cannot start Attempt 2 while Attempt 1 is still `in_progress`.

A new normal Attempt is allowed only after the prior one is frozen and only while the fixed `1..3` limit and all assignment/lifecycle/deadline rules permit it.

---

# 8. Start / Resume Contract

## 8.1 New start

When no `in_progress` Attempt exists and all rules allow a new Attempt:

```text
next_attempt_number = max(existing attempt_number) + 1
```

with fixed Homework maximum:

```text
3
```

The backend must allocate the number under transaction/locking so concurrent requests cannot create duplicate numbers or consume two attempts accidentally.

Success for a newly created Attempt remains:

```text
201 Created
```

## 8.2 Resume instead of parallel Attempt

If the Student already owns an `in_progress` Attempt for this Homework, an independent valid Start request must return that existing Attempt instead of creating another one.

Use:

```text
200 OK
```

for this resume result.

The response identifies the same Attempt and does not increment attempt usage.

## 8.3 Attempt exhaustion

If no `in_progress` Attempt exists and Attempts `1`, `2`, and `3` already exist:

```text
409 attempts_exhausted
```

No Attempt 4 is created.

## 8.4 Official Homework first-activity lock

When creating the first Attempt for the Homework currently referenced by:

```text
topic_result_pairs.homework_assessment_id
```

perform result-pair locking in the same transaction as Attempt creation.

Required:

- resolve the pair inside the same Institution/Topic;
- lock the pair row;
- require the already-established official cohort (`cohort_snapshotted_at` non-null);
- require the Student to belong to that persisted official Homework recipient cohort;
- if `locked_at` is null, set:

```text
locked_at = startedAt
updated_at = startedAt
```

where `startedAt` is the same captured server instant used for the new Attempt `started_at`;
- if `locked_at` is already non-null, preserve it;
- `blitz_assessment_id` may still be null;
- do not replace official Homework/cohort meaning;
- do not create a Blitz.

A structural inconsistency in an official pair/cohort must fail the new Attempt atomically; Codex must not repair or resnapshot it silently.

Practice Homework that is not the official Homework does not mutate `topic_result_pairs`.

---

# 9. Durable Idempotency Contract

## 9.1 Operations requiring `Idempotency-Key`

Stage 7 requires a valid client-generated UUID header for:

```text
POST /api/v1/student/homework/{homework}/attempts
POST /api/v1/student/attempts/{attempt}/submit
```

Missing or malformed header:

```text
422 validation_failed
```

Answer replacement PUTs remain naturally replace-style mutations and do not gain this header requirement in Stage 7.

## 9.2 Persistence is mandatory

Do not implement high-risk idempotency using only:

- process memory;
- request-local state;
- Flutter state;
- cache-only state with eviction semantics;
- timing heuristics.

Use durable PostgreSQL persistence so safe retries remain safe across PHP workers/process restarts and concurrent requests.

## 9.3 New table: `idempotency_records`

Add the following **documentation contract** to `docs/08-database.md`; implementation belongs to `S07-BE-001`.

Purpose:

> Stores an authenticated tenant/user-scoped durable claim and successful logical outcome for high-risk API operations that require `Idempotency-Key`.

Required columns:

| Column | Type | Null | Notes |
|---|---|---:|---|
| `id` | uuid | no | PK |
| `institution_id` | uuid | no | Tenant owner |
| `user_id` | uuid | no | Authenticated caller |
| `operation` | varchar(80) | no | Stable operation code |
| `idempotency_key` | uuid | no | Client header UUID |
| `request_fingerprint` | char(64) | no | Lowercase SHA-256 hex of canonical semantic request identity |
| `result_resource_type` | varchar(80) | yes | Successful logical result type |
| `result_resource_id` | uuid | yes | Successful logical result ID |
| `response_status` | smallint | yes | Original successful HTTP status |
| `completed_at` | timestamptz | yes | Set before successful transaction commit |
| `created_at` | timestamptz | no | |
| `updated_at` | timestamptz | no | |

Required FKs:

```text
institution_id -> institutions.id
user_id        -> users.id
```

Do not create a generic polymorphic database FK for `result_resource_id`.

Required unique constraint:

```text
unique(institution_id, user_id, operation, idempotency_key)
```

Required index:

```text
index(institution_id, user_id, operation, created_at)
```

Add `idempotency_records` to the high-risk direct Institution ownership list.

MVP retention rule:

```text
do not expire/delete completed idempotency records automatically
```

This avoids a later replay of an old key accidentally becoming a new attempt during the MVP lifecycle.

## 9.4 Stable Stage 7 operation codes

Use:

```text
student.homework.attempt.start
student.homework.attempt.submit
```

The table is intentionally reusable by Stage 8 Blitz operations without a second idempotency subsystem.

## 9.5 Request fingerprint

The fingerprint must represent the semantic request identity and include, in deterministic canonical form:

- operation code;
- authenticated Institution;
- authenticated user;
- route target UUID(s);
- normalized request-body fields, if any.

Do not store raw Authorization tokens or secrets.

Do not treat the idempotency key itself as the only request identity.

## 9.6 Same key / same request

If the unique idempotency scope already exists with the same fingerprint:

- do not execute the domain mutation again;
- resolve and return the same logical resource identity;
- preserve the original successful semantic HTTP result recorded for the operation;
- current safe resource serialization may be used; byte-for-byte historical response-body storage is not required.

## 9.7 Same key / materially different request

Return:

```text
409 idempotency_key_reused
```

No domain mutation may occur.

## 9.8 Transactional claim pattern

The idempotency claim and the protected domain mutation must participate in the same database transaction.

The implementation must use a conflict-safe database claim pattern (`INSERT ... ON CONFLICT`, equivalent Laravel-safe technique, or another PostgreSQL-safe approach) so concurrent requests with the same scope/key cannot both execute the protected mutation.

A transaction-local incomplete claim must never be deliberately committed. On mutation failure, the claim rolls back with the domain transaction.

## 9.9 Idempotency is not authorization

Every request still passes normal:

- authentication;
- active account/password-change middleware;
- Student role;
- Institution isolation;
- resource ownership/assignment authorization.

An idempotency record must never allow a caller to replay another user's or another Institution's result.

---

# 10. Homework Deadline Reconciliation

## 10.1 Authoritative boundary

For Homework with a non-null deadline:

```text
server_now < deadline_at  => Student write/start may continue if other rules pass
server_now >= deadline_at => deadline has passed
```

Device time is never authoritative.

## 10.2 Shared application action

Document one reusable idempotent application action concept, for example:

```text
FinalizeHomeworkAttemptsAtDeadline
```

The exact class name may follow repository naming conventions, but there must be one shared domain operation rather than separate request-path and scheduler implementations with divergent rules.

## 10.3 Invocation points

The same deadline reconciliation behavior is invoked:

- before relevant Student Homework/Attempt reads that expose current editable/finalized state;
- before Student Attempt Start;
- before Student answer mutation;
- before Student final Submit;
- before Teacher Homework close when the deadline may already have passed;
- by Laravel Scheduler server-side.

Scheduler latency cannot extend write eligibility because every write independently checks/reconciles authoritative deadline state.

## 10.4 No fabricated Attempt

A Student who never started gets no empty Attempt at deadline.

Do not create:

```text
attempt_number = 1
```

only to represent missing work.

## 10.5 Remaining attempt capacity

Once deadline has passed, all unused normal Homework Attempt capacity is unavailable.

New Start returns:

```text
409 deadline_passed
```

## 10.6 Post-deadline mutations

After reconciliation, further Student answer writes/final Submit cannot mutate the frozen Attempt.

A new late operation returns the documented deadline/locked conflict; it does not reopen the Attempt.

A valid idempotent replay of a previously committed pre-deadline high-risk operation may still return its prior logical success after the deadline because replay performs no new domain mutation.

---

# 11. Teacher Close Reconciliation and Precedence

The current Stage 6 temporary behavior that rejects close merely because an `in_progress` structural Attempt exists must not remain once public Stage 7 Attempt Start is exposed.

Stage 7 documentation must require atomic auto-finalization instead.

## 11.1 Deadline precedence

When Teacher close is requested:

1. resolve/lock authorized Homework;
2. if authoritative deadline has already passed, reconcile deadline first;
3. Attempts finalized because the deadline already occurred keep:

```text
finalization_reason = homework_deadline_auto_submit
finalized_at = deadline_at
```

4. only still-`in_progress` Attempts for a close occurring before deadline use:

```text
finalization_reason = task_closed_auto_finalize
```

This prevents delayed Scheduler execution from incorrectly rewriting an earlier deadline event as Teacher-close finalization.

## 11.2 Atomicity

For a pre-deadline Teacher close:

```text
freeze all current in_progress Attempts
+
close Homework
```

must commit atomically.

No new Attempt/write may slip between finalization and close.

## 11.3 Existing frozen Attempts

Already-frozen Attempts are not rewritten merely because the Homework is later closed.

## 11.4 Never-started Students

No Attempts are fabricated for never-started Students on close.

---

# 12. Finalization Concurrency Contract

The docs must explicitly require exactly one logical terminal transition when any of these race:

```text
Student explicit Submit
Homework deadline reconciliation/Scheduler
Teacher Homework close
```

Required technique:

- transaction;
- lock the relevant Homework/Attempt rows in deterministic scope;
- re-read state after lock acquisition;
- re-check authoritative time after acquiring the required lock(s);
- transition only from `in_progress`;
- preserve an already committed terminal reason/timestamps;
- no double scoring/checking in Stage 7 because Stage 7 performs none;
- safe idempotent retry returns the existing logical result;
- incompatible later mutation returns the documented conflict.

### Race outcomes

If Student Submit validly commits first before the deadline/close transition:

```text
finalization_reason = student_submit
```

Later deadline/close leaves the Attempt unchanged.

If authoritative deadline is already reached when the locked state is evaluated:

```text
homework_deadline_auto_submit
```

wins over a new Student Submit or later Teacher close.

If Teacher close validly commits before deadline and before Student Submit:

```text
task_closed_auto_finalize
```

wins; later Student Submit cannot rewrite it.

---

# 13. `docs/04-user-flows.md`

Align the Student Homework flow to show:

```text
1. Student opens an assigned active Homework.
2. Backend shows server-authoritative deadline and Attempt availability.
3. Student starts a new Attempt or resumes the existing in-progress Attempt.
4. Starting the first Attempt on the official Homework locks official Homework/cohort meaning.
5. Student saves/replaces typed answers while the Attempt is editable.
6. File-based answers use private protected storage.
7. Student explicitly submits, or backend freezes saved work at deadline/Teacher close.
8. Stage 7 ends with an immutable submitted Attempt.
9. Stage 9 later checks/scores that frozen Attempt and performs Teacher review where required.
```

Remove/adjust any flow wording that makes automatic checking or Teacher review part of the Stage 7 submit transaction.

Preserve the full-MVP outcome that those checks happen later.

---

# 14. `docs/05-business-rules.md`

## 14.1 `BR-HW-012 — Closed Homework and in-progress attempts`

Preserve:

- close blocks new Attempts and further Student answer changes;
- existing `in_progress` Attempts are auto-finalized from saved work;
- no Attempt for never-started Students;
- unused capacity becomes unavailable;
- reason is `task_closed_auto_finalize`.

Replace the immediate-checking wording with Stage 7/Stage 9 separation:

> Closing Homework freezes each existing in-progress Attempt using the answers already saved before closure. Stage 7 does not evaluate correctness or create Teacher-review state during that close transaction. Unanswered Questions remain absent/unsaved and are treated as zero later by Stage 9 scoring; saved answers are checked later according to their Question type. The frozen Attempt remains `submitted` until Stage 9 checking advances it.

## 14.2 `BR-HW-016 — Deadline auto-finalization`

Preserve the authoritative deadline and no-late-write rules.

Replace immediate-checking wording with:

> At the authoritative Homework deadline, every existing in-progress Attempt is frozen from the answers already saved. Stage 7 sets the Homework Attempt to `submitted`, keeps `submitted_at = null`, sets `finalized_at`/`locked_at` to the authoritative deadline, and stores `homework_deadline_auto_submit`. It does not score answers. Stage 9 later treats missing answers as zero and evaluates saved answers under the approved checking rules.

Add/retain:

- no fabricated Attempt for never-started Student;
- unused Attempt capacity unavailable after deadline;
- request-path reconciliation + Scheduler use the same idempotent behavior;
- race with Submit creates exactly one finalization.

## 14.3 Homework submit rule

Where the rules describe explicit Student submit, clarify:

> Explicit Submit freezes the Attempt and records `student_submit`; it does not itself imply that checking has completed. Stage 9 owns the later checking/scoring transition.

## 14.4 One-in-progress rule

Add a clear business invariant:

> A Student may have at most one in-progress Attempt for the same Homework at a time. A Start request resumes that Attempt rather than opening another parallel Attempt. A new Attempt is available only after the previous Attempt is frozen and the three-attempt/deadline/lifecycle rules still allow it.

---

# 15. `docs/06-roadmap.md`

Under Stage 7, make the implementation boundary explicit.

Required Stage 7 scope text:

```text
Stage 7 persists Student Homework execution and immutable submissions.
It does not perform automatic/manual checking, Attempt score calculation,
or official Homework score selection; those are Stage 9 responsibilities.
```

Add Stage 7 acceptance/boundary points for:

- start/resume;
- maximum three Attempts;
- one `in_progress` Attempt at a time;
- all nine answer types including private file submission;
- Student final Submit;
- deadline auto-finalization;
- Teacher-close auto-finalization;
- no fabricated Attempts for never-started Students;
- durable idempotency for Start/final Submit;
- first official Homework Attempt result-pair lock;
- tenant/ownership isolation;
- exactly-once race handling.

Under Stage 9, explicitly say it consumes Stage 7 frozen Attempt/answer records and then performs:

- automatic checking;
- manual Teacher review;
- Attempt scoring;
- official Homework score selection/reselection.

Do not move Blitz implementation from Stage 8 or final Topic results from Stage 10.

---

# 16. `docs/07-architecture.md`

Add/align the following architecture rules.

## 16.1 Execution vs scoring separation

Document:

```text
Student Homework execution writes answer/submission history.
Checking/scoring consumes frozen history later.
```

The finalization service must not depend on the future checking engine.

## 16.2 Shared Homework finalizer

Document one reusable Homework finalization/reconciliation service used by:

- explicit Submit;
- deadline reconciliation;
- Teacher close integration;

with reason-specific transitions and row locking.

Deadline reconciliation additionally has the Scheduler entry point.

The exact code may use separate thin actions around a shared finalizer, but business transition logic must not be duplicated inconsistently.

## 16.3 Idempotency component

Document a reusable DB-backed idempotency component/service that:

- validates the UUID key;
- scopes by Institution/user/operation;
- fingerprints semantic request identity;
- claims the key transactionally;
- detects same-key/different-request reuse;
- records the successful logical resource/status;
- supports Stage 8 reuse.

## 16.4 Tenant isolation

All Attempt/Answer/File/idempotency resolution remains tenant-first and Student-owned.

Direct UUID possession never grants access.

## 16.5 Official result-pair lock

Document that the first newly created Attempt on the official Homework sets the existing staged pair `locked_at` in the same transaction, while `blitz_assessment_id` may still be null.

---

# 17. `docs/08-database.md`

Perform all required persistence-document updates.

## 17.1 Direct ownership list

Add:

```text
idempotency_records
```

to high-risk Institution-owned tables.

## 17.2 `assessment_attempts.status`

Keep all existing allowed stored values:

```text
in_progress
submitted
timed_out_finalized
waiting_for_teacher_review
checked
```

Clarify lifecycle ownership:

```text
Stage 7 Homework:
  in_progress -> submitted

Stage 9 Homework checking:
  submitted -> waiting_for_teacher_review / checked

Stage 8+ Blitz timeout:
  may use timed_out_finalized according to Blitz contract
```

## 17.3 Homework deadline rule

Replace any current text that says deadline finalization immediately evaluates/auto-checks answers or moves directly to Teacher review/checked.

Use the exact Stage 7 state from Section 5.4 of this task.

## 17.4 Teacher-close rule

Document the Section 5.5/11 atomic close behavior and deadline precedence.

## 17.5 One-in-progress structural guard

Add the partial unique index:

```text
unique(assessment_id, student_id)
where status = 'in_progress'
```

in addition to the existing unique Attempt-number constraint.

## 17.6 `attempt_answers`

Clarify that a newly saved/replaced Student answer begins/remains:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

until Stage 9.

Clarify that unanswered Questions do not require fabricated `attempt_answers` rows.

## 17.7 New `idempotency_records` contract

Add the exact schema, constraints, purpose, indexes, FK and retention rules from Section 9.3.

Place it in a logically appropriate technical/attempt-support section without renaming existing domain tables.

Update the documented table-creation ordering so its dependencies are respected.

No source migration is created in this documentation task.

---

# 18. `docs/09-api-contracts.md`

## 18.1 General idempotency convention

Keep the existing public rule:

```http
Idempotency-Key: <client-generated-uuid>
```

and align it with Section 9:

- missing/malformed key → `422 validation_failed`;
- same scoped key + same fingerprint → same logical result, no second mutation;
- same scoped key + materially different request → `409 idempotency_key_reused`;
- persistence is durable/database-backed;
- idempotency never bypasses authorization.

The public API document does not need to expose internal table IDs.

## 18.2 Stage 7 section boundary

At the start of `Student Homework Attempt APIs`, add an explicit implementation boundary:

> Stage 7 endpoints capture/freeze Student Homework work only. A frozen Homework Attempt remains `submitted` with score/checking completion unavailable until Stage 9. Stage 9 later advances checking states and computes scores without rewriting Student answer payloads.

## 18.3 Student Homework list/detail

Keep Student-safe assignment/deadline/Attempt availability.

Do not expose Teacher-only answer keys/correct-answer configuration.

Where score fields are present in the full-MVP shape before Stage 9, they must be null/not-ready and must not imply that Stage 7 selected an official score.

The Homework detail/read contract should expose enough current Attempt identity/state for the client to resume an existing `in_progress` Attempt safely rather than create a parallel one.

## 18.4 Start Homework Attempt

Keep:

```text
POST /api/v1/student/homework/{homework}/attempts
```

and required Idempotency-Key.

Document both success modes:

```text
201 Created  -> a new next sequential Attempt was created
200 OK       -> the existing in_progress Attempt was resumed/returned
```

Keep fixed maximum `1..3`.

Remove/move from Stage 7 any rule that says this endpoint immediately resolves/recalculates the official Homework score.

Replace with a forward note:

> Stage 9 selects/reselects the official Homework score after eligible Attempts are fully checked. Stage 7 only preserves the Attempt history needed for that later deterministic selection.

Document first official Homework Attempt pair locking from Section 8.4.

## 18.5 Get Attempt

Keep Student-only own-Attempt authorization.

The resource may expose frozen/checking-not-ready fields, but Stage 7 must not fabricate scored values.

## 18.6 Save/replace answer

Keep:

```text
PUT /api/v1/student/attempts/{attempt}/answers/{question}
```

Only own assigned `in_progress` Homework Attempt may be mutated.

After deadline/close/finalization:

- no content mutation;
- use existing stable deadline/task/submission conflict codes according to cause;
- no answer-key leakage;
- saved answer remains `pending` for later Stage 9 checking.

Keep per-type structural validation and the existing Multiple Choice selection cap.

Do not describe an empty Multiple Choice selection as being scored during Stage 7; say it is a valid saved answer whose eventual Stage 9 score is zero.

## 18.7 File-based answer

Preserve existing private-storage/file-limit/security contracts.

Clarify that upload/replace is Student answer persistence only; file content is not graded in Stage 7.

## 18.8 Submit Homework Attempt

Keep:

```text
POST /api/v1/student/attempts/{attempt}/submit
```

with required Idempotency-Key.

Replace the current Stage 7 success examples that return:

```text
checked
waiting_for_teacher_review
normalized_score = non-null
```

with a Stage 7 success example equivalent to:

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

Rules after success:

- Student answer set is immutable;
- no checking occurs in Stage 7;
- saved answer `checking_status` remains `pending`;
- next Attempt may later start if fewer than three are used and all lifecycle/deadline rules still allow it;
- Stage 9 performs checking/scoring/official-score selection.

## 18.9 Deadline contract

Replace current immediate-checking effects with:

1. new Starts rejected with `409 deadline_passed`;
2. further Student answer writes blocked;
3. every existing `in_progress` Attempt frozen from already-saved answers;
4. `status = submitted`;
5. `submitted_at = null`;
6. `finalized_at = deadline_at`;
7. `locked_at = deadline_at`;
8. `finalization_reason = homework_deadline_auto_submit`;
9. no unanswered answer rows fabricated;
10. no Stage 7 checking/scoring;
11. never-started Students get no Attempt;
12. remaining unused Attempt capacity unavailable;
13. request-path reconciliation + Scheduler use the same idempotent action;
14. submit/deadline race yields exactly one terminal transition.

## 18.10 Teacher Homework close contract

Replace the Stage 6 temporary “reject close if in-progress Attempt exists” boundary with the final Stage 7 execution behavior:

- before deadline: atomically auto-finalize all `in_progress` Attempts with `task_closed_auto_finalize`, then close;
- after deadline: reconcile deadline first so prior deadline finalization keeps `homework_deadline_auto_submit`;
- no fabricated Attempt for never-started Student;
- no Stage 7 scoring/checking;
- already-frozen Attempts remain unchanged.

Public Student Attempt Start must not be considered deliverable while production close still merely rejects structural `in_progress` Attempts.

---

# 19. Security and Privacy Contract

Documentation edits must preserve all existing security rules and make these Stage 7 cases explicit where needed.

For Student Homework/Attempt/Answer/File operations:

- role must be `student`;
- account/Institution must be active through existing middleware;
- authenticated Student Institution is authoritative;
- Student must be an `assessment_students` recipient for the Homework;
- Attempt must belong to that same Student and Assessment;
- Question must belong to that Attempt's Assessment;
- answer child IDs/options/items/blanks must belong to that same Question/Institution;
- direct UUID possession is insufficient;
- foreign-Institution / another Student's Attempt/File must not leak private existence/content;
- protected file download remains backend-authorized;
- no correct-answer configuration is exposed before/while Student answers.

Idempotency lookup itself must be scoped by authenticated Institution + user + operation; never look up by key globally and then authorize afterward.

---

# 20. Concurrency and No-Op Rules

The aligned docs must support later implementation of all of these without Codex invention:

- concurrent Start with same idempotency key → one logical Attempt;
- concurrent Start with different keys → still at most one `in_progress` Attempt; one may create, the other resumes the committed Attempt rather than consume another slot;
- sequential Attempt numbers cannot duplicate/skip because of a race;
- concurrent same-key Submit → one finalization;
- Submit vs deadline → one reason/timestamp set;
- Submit vs Teacher close → one reason/timestamp set;
- deadline vs Teacher close → deadline reason wins when deadline already occurred;
- repeated deadline reconciliation → write-free after state is already reconciled;
- repeated close does not rewrite existing frozen Attempt timestamps/reasons;
- idempotent replay does not create a new domain mutation or update domain timestamps merely because it was retried.

---

# 21. Explicit Non-Goals

Do not use this documentation task to add or redesign:

- Stage 8 Blitz APIs/implementation;
- Stage 9 checking implementation;
- Teacher review endpoints;
- official score implementation;
- Stage 10 Topic result implementation;
- AI/fuzzy grading;
- new Question types;
- configurable Homework attempt counts;
- more than one file per file-based answer;
- public file storage;
- new roles/permissions;
- frontend behavior beyond documenting API contract expectations;
- production code/migrations/tests;
- integration harness changes;
- broad documentation cleanup unrelated to the exact alignment.

---

# 22. Acceptance Criteria

This documentation task passes only when all are true.

## 22.1 Stage boundary

- Stage 7 execution/finalization is clearly separated from Stage 9 checking/scoring.
- No Student Submit/deadline/close Stage 7 text still requires immediate `checked` or `waiting_for_teacher_review` transition.
- Full-MVP scoring rules remain documented for Stage 9.

## 22.2 Attempt lifecycle

- Stage 7 Homework terminal execution state is `submitted` for explicit Submit/deadline/close.
- `submitted_at` is explicit-Student-only.
- `finalized_at`/`locked_at` semantics are exact.
- `timed_out_finalized` is not used for Stage 7 Homework.

## 22.3 Answers

- saved Student answers remain `pending` until Stage 9;
- Stage 7 does not write awarded points/check metadata;
- unanswered Questions need no fabricated answer row;
- later scoring of unanswered work as zero remains preserved.

## 22.4 Start/resume

- at most one `in_progress` Homework Attempt per Student/Homework is documented;
- partial unique index is documented;
- Start creates next Attempt or resumes existing one;
- maximum remains exactly three normal Homework Attempts;
- first official Homework Attempt locks result-pair meaning/cohort atomically.

## 22.5 Idempotency

- `idempotency_records` schema is documented exactly;
- operation scope/key/fingerprint behavior is clear;
- same request replays safely;
- materially different reuse returns `409 idempotency_key_reused`;
- claim/domain mutation are transactional;
- auth/tenant isolation is not bypassed;
- no automatic MVP expiration is documented.

## 22.6 Deadline/close

- one shared deadline finalization action is documented for request reconciliation + Scheduler;
- deadline timestamp, not delayed processing time, is the deadline finalization time;
- Teacher close auto-finalizes rather than rejects in-progress Student work;
- deadline precedence over a later close is explicit;
- no never-started Student gets a fabricated Attempt;
- exactly-once race behavior is explicit.

## 22.7 Scope

- only the approved live docs `docs/01-business-overview.md` through `docs/09-api-contracts.md` changed, and only where required by this Stage 7 alignment;
- no source code, migrations, tests, harnesses, prior task files, or historical audit report changed;
- no unrelated doc rewrite.

---

# 23. Verification

No application test suite is required for this documentation-only task.

Run exactly the proportional checks:

```bash
git diff --check
```

Review changed filenames and confirm they are limited to the approved live docs `docs/01-business-overview.md` through `docs/09-api-contracts.md` from Section 3.

Perform focused text checks confirming the final docs contain/retain the required concepts:

```text
Stage 7 execution vs Stage 9 checking boundary
status = submitted
homework_deadline_auto_submit
task_closed_auto_finalize
one in_progress Homework Attempt
idempotency_records
student.homework.attempt.start
student.homework.attempt.submit
Idempotency-Key
FinalizeHomeworkAttemptsAtDeadline or equivalent shared-action wording
```

Also search the changed live docs for stale contradictory Stage 7 wording equivalent to:

```text
Submit immediately auto-checks answers
Deadline finalization immediately checks/awards points
Teacher close immediately moves to checked/waiting review
```

If such wording remains, fix it only where it conflicts with the required Stage boundary.

Do not run backend/frontend tests or builds for this documentation-only task.

---

# 24. Delivery Checklist

Before declaring implementation complete, Codex must report:

1. exact changed documentation files;
2. concise summary of the contract alignment;
3. confirmation that production code/migrations/tests were untouched;
4. `git diff --check` result;
5. focused stale-wording/required-term review result;
6. final `git status --short`;
7. focused diff self-check confirming no Stage 8/9 implementation was pulled into Stage 7.

After delivery, ChatGPT performs the read-only acceptance review.

`S07-BE-001` remains blocked until:

```text
S07-DOC-001 = Accepted / Delivered
```
