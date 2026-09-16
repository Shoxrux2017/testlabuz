# S08-DOC-001 — Stage 8 Blitz Execution Contract Alignment

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-DOC-001` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Documentation / contract alignment` |
| Status | `Approved` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Depends on | `Stage 7 CLOSED / PASS` + approved Stage 8 decomposition |
| Blocks | `S08-BE-001` |
| Implementation Readiness Gate | `PASS` |
| Production code / migrations / tests / API implementation | `Forbidden` |
| Verification | `Documentation diff only` |
| Delivery execution | `Project Owner / Codex only as exact documentation editor` |

This task aligns the already-approved Blitz behavior into the live MVP documentation before Stage 8 backend implementation begins.

It does **not** reopen product design.

This file is the complete task-specific implementation contract.

Codex may inspect only:

1. this contract;
2. root `AGENTS.md`;
3. the exact in-scope live-document text required to place the edits safely.

Codex must **not** read roadmap/product/architecture/database/API documents broadly to discover or reinterpret requirements. The exact required behavior is frozen below.

Do not create a duplicate `CODEX-PROMPT` file.

---

# 2. Why This Alignment Task Exists

The current live docs already contain most of the correct Blitz product model:

- one normal Blitz Attempt;
- one optional Student-specific Teacher-approved exception Attempt;
- `draft / scheduled / active / closed / archived`;
- synchronized and individual timer-start modes;
- whole-Blitz duration;
- backend-authoritative time;
- timeout auto-finalization;
- Teacher monitoring;
- official Homework/Blitz Topic result pair;
- official cohort snapshot;
- Stage 9 checking/scoring;
- Stage 10 final Topic result.

However, the live documentation still contains an execution/checking ownership conflict.

Some Blitz wording currently says or implies that Stage 8 timeout/Teacher-close finalization immediately:

```text
checks objective answers
awards points
moves manual answers to Waiting for teacher review
```

while the Stage roadmap and the already-delivered Stage 7 alignment establish:

```text
Stage 8 = Blitz execution/finalization
Stage 9 = checking/scoring/Teacher review/official score
```

That ambiguity must be removed before Blitz persistence and execution code is written.

The live docs must also freeze the exact Stage 8 contracts for:

- official Blitz designation;
- result-pair completion;
- official cohort reuse/establishment;
- timer snapshotting;
- synchronized/individual deadlines;
- Attempt terminal semantics;
- timeout vs Teacher-close precedence;
- Student-specific exception;
- required high-risk idempotency;
- Stage 8/Stage 9 boundary.

---

# 3. Locked Stage Ownership Boundary

The authoritative MVP sequencing is:

```text
Stage 7
= Student Homework execution
= immutable Homework submission/finalization history

Stage 8
= Teacher/Student Blitz workflow
= server-authoritative Blitz timing
= immutable Blitz execution/finalization history
= technical replacement-Attempt exception

Stage 9
= automatic answer checking
= Teacher manual review
= awarded points
= Attempt scoring
= official Homework score
= official Blitz score

Stage 10
= Homework–Blitz comparison
= final Topic result
= understanding category
= result release workflow
```

## 3.1 Stage 8 owns

Stage 8 owns:

- Teacher Blitz authoring;
- Blitz list/detail/update;
- group/selected-Student assignment;
- scheduling;
- archive;
- all nine Question types for Blitz authoring;
- Blitz Question editing integrity;
- official Blitz designation;
- result-pair Blitz-side completion;
- official cohort enforcement;
- Blitz activation;
- timer-mode snapshot;
- synchronized timer;
- individual timer;
- server-authoritative time;
- Student active Blitz discovery/detail;
- Student Start/Resume;
- one normal Attempt;
- Student typed/file answers;
- explicit Student Submit;
- timeout reconciliation;
- Scheduler timeout reconciliation;
- Teacher-close finalization;
- immutable frozen execution history;
- Student-specific technical exception;
- one replacement Attempt;
- exclusion of invalidated Attempt from later official-score eligibility;
- Teacher live monitoring;
- Tenant/ownership/privacy enforcement;
- required DB-backed idempotency;
- execution/finalization concurrency safety.

## 3.2 Stage 8 does not own

Do not describe the following as Stage 8 implementation:

```text
automatic correctness evaluation
partial-credit calculation
attempt_answers.awarded_points
Teacher answer checking/review
Teacher scoring/feedback
checking_status transition to checked
checking_status transition to needs_review / equivalent
assessment_attempts.earned_points
assessment_attempts.normalized_score
assessment_attempts.scoring_completed_at
official Blitz score selection
official Homework score selection
official_task_scores
Homework–Blitz comparison
Topic result calculation
understanding category
result release
Parent result UI
AI/fuzzy checking
```

Those remain later-stage behavior.

The full MVP Question checking formulas remain documented, but their execution timing must be clear:

```text
Stage 8 freezes the Student's committed Blitz work.

Stage 9 later:
- treats missing/unanswered work as zero under the approved scoring rules;
- automatically checks objective saved answers;
- identifies answers requiring Teacher review;
- performs Teacher review;
- awards points;
- completes Attempt scoring;
- selects the eligible official Blitz score.
```

---

# 4. Scope and Preservation Rules

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

Do not modify:

- source code;
- migrations;
- tests;
- integration harnesses;
- Flutter;
- dependencies;
- `AGENTS.md`;
- `tasks/README.md`;
- previous Stage task files;
- Stage 6/7 closure evidence;
- Stage 8 task index;
- unrelated documentation.

## 4.1 Preserve delivered Stage 6/7 behavior

This task must not weaken or reinterpret:

- Stage 6 Homework authoring;
- Stage 6 official Homework designation;
- Stage 6 staged nullable-Blitz result pair;
- Stage 6 official cohort snapshot contract;
- Stage 7 Student Homework execution;
- Stage 7 Homework finalization;
- Stage 7 Homework idempotency;
- Stage 7 first official Homework Attempt pair lock;
- Stage 7 answer/file freeze boundary.

Combined Homework/Blitz wording may be split when necessary, but the delivered Homework behavior must remain unchanged.

---

# 5. Blitz Lifecycle Contract

The Blitz task lifecycle is exactly:

```text
draft
scheduled
active
closed
archived
```

These are **task** lifecycle statuses.

Attempt/checking state is separate.

## 5.1 Draft

`draft` means:

- Teacher may author/edit the Blitz according to edit-integrity rules;
- Students cannot access it as executable work;
- no Student Attempt may start;
- duration may be configured;
- Questions may be configured;
- assignment may be configured;
- an eligible whole-group Blitz may be designated official;
- Institution timer-start setting is not required merely to save a draft.

## 5.2 Scheduled

`scheduled` means:

- prepared for later classroom activation;
- Students still cannot answer it;
- Teacher activation is still required;
- scheduling does not start a timer;
- scheduling does not create Attempts;
- scheduling does not create result/checking/scoring records.

## 5.3 Active

Only Teacher activation may transition an eligible Blitz to `active`.

Activation:

- captures backend-authoritative activation time;
- snapshots the current Institution Blitz timer-start mode;
- establishes or reuses the required recipient snapshot;
- establishes/reuses the official cohort when the Blitz is official;
- starts the synchronized common timer when mode is synchronized;
- makes the Blitz available for eligible Student Start when mode is individual;
- does not create fake Student Attempts.

## 5.4 Closed

Closing an active Blitz:

- stops new Student Starts;
- stops further Student answer/file mutation;
- reconciles any already-expired in-progress Attempts first;
- freezes any still-`in_progress` Attempts according to Teacher-close semantics;
- creates no Attempt for never-started Students;
- does not perform Stage 9 checking/scoring.

## 5.5 Archived

Archived Blitz:

- is retained for history;
- accepts no new Student activity;
- does not rewrite historical Attempts;
- does not erase exception history;
- does not erase official-pair history.

---

# 6. Blitz Structure and Activation Readiness

A Blitz requires the existing common Assessment data plus Blitz-specific data.

Before activation, require at minimum:

```text
assessment.type = blitz
title present
Topic valid
Teacher valid
assignment valid
instructions valid according to existing common rules
at least 1 valid Question
total_possible_points > 0
duration_seconds > 0
Blitz lifecycle permits activation
required recipient/official-cohort rules pass
Institution blitz_timer_start_mode is configured
```

The fixed normal Attempt rule is:

```text
1
```

It is never a Teacher-provided request value.

Do not add:

```text
attempt_limit
normal_attempt_limit
max_attempts
```

to Teacher Blitz create/update payloads.

The Institution timer mode is not a Teacher-provided Blitz request value.

Do not add a Teacher-editable:

```text
timer_start_mode
```

field to create/update semantics.

The authoritative timer mode is snapshotted only at activation.

---

# 7. Official Blitz and Topic Result-Pair Contract

Stage 8 completes the existing staged Topic result pair.

The existing authoritative row is:

```text
topic_result_pairs
```

Before Stage 8 completion it may validly contain:

```text
homework_assessment_id = official Homework
blitz_assessment_id    = null
```

Stage 8 must fill the nullable Blitz side in the **same row**.

Do not:

- create a second result-pair row;
- replace the official Homework merely because Blitz is being attached;
- create `official_blitz_id` on Topic;
- create `is_official` on `blitz_tasks`;
- create a fake Blitz placeholder;
- fabricate Blitz recipients before a real Blitz exists.

## 7.1 Official Blitz eligibility

A Blitz may become official only when all are true:

```text
assessment.type = blitz
same Institution as Topic/result pair
same Topic
same authorized Teacher scope
assignment_mode = group
lifecycle is pre-activation
no Student Attempt exists
```

The normal designation candidates are:

```text
draft
scheduled
```

Do not newly designate an already:

```text
active
closed
archived
```

Blitz as official.

Do not retroactively convert a practice Blitz with Student activity into official result-bearing work.

Selected-Student Blitz remains supplementary/practice only.

## 7.2 Official Homework Is Required; a Pre-Existing Pair Row Is Not

A result-bearing Blitz is always connected to one valid official Homework for the
same Topic. Stage 8 does not invent an official Homework.

However, the `topic_result_pairs` row does **not** have to pre-exist before the
Stage 8-compatible result-pair PUT.

The existing canonical PUT supports both authoritative cases.

### No existing pair

After validating the required Homework candidate and the optional supplied Blitz
candidate, create exactly one Topic result-pair row atomically:

```text
homework_assessment_id = requested eligible Homework
blitz_assessment_id = supplied eligible Blitz or null
designated_by_user_id = authenticated Teacher
designated_at = designatedAt
created_at = designatedAt
updated_at = designatedAt
locked_at = null
```

Cohort state follows the already-approved Homework designation state:

```text
draft Homework
=> cohort_snapshotted_at = null

active Homework with a valid persisted official group-recipient snapshot
=> cohort_snapshotted_at = designatedAt
```

Do not create Blitz recipients or Student Attempts merely because the pair row is
created.

### Existing pair

Reuse and mutate that one existing row only according to Sections 7.3–7.5.

Therefore the invariant is:

```text
valid official Homework is required
pre-existing topic_result_pairs row is not required
one Topic result-pair row maximum
```

## 7.3 Stage 8 result-pair API extension

Keep the existing endpoint:

```text
GET /api/v1/teacher/topics/{topic}/result-pair
PUT /api/v1/teacher/topics/{topic}/result-pair
```

The GET resource continues to expose the persisted:

```text
homework_assessment_id
blitz_assessment_id
cohort_snapshotted_at
locked_at
designation timestamps
```

Extend the Stage 6 PUT request contract without breaking the existing Homework-only caller.

Allowed request shape:

```json
{
  "homework_assessment_id": "official-homework-uuid",
  "blitz_assessment_id": "official-blitz-uuid"
}
```

Rules:

- `homework_assessment_id` remains required.
- `blitz_assessment_id` is optional.
- when omitted, preserve the currently persisted Blitz side exactly;
- when supplied, it must be a non-null UUID;
- Stage 8 adds no `null` clear operation;
- unknown keys remain validation failures.

This preserves the existing Stage 6 Homework-only request:

```json
{
  "homework_assessment_id": "official-homework-uuid"
}
```

without silently clearing a Blitz that may already exist.

## 7.4 Result-pair mutation semantics

If `blitz_assessment_id` is supplied:

### Pair unlocked + Blitz side null

Eligible Blitz may be attached.

### Pair unlocked + Blitz side already populated

Teacher may replace the pre-activity official Blitz only with another eligible pre-activation whole-group Blitz.

Do not alter the Homework side unless the normal existing Homework replacement rules also independently allow the supplied Homework change.

### Pair locked + Blitz side null

The approved Stage 8 exception applies:

```text
fill the previously absent Blitz side
```

when and only when:

- Homework side remains exactly unchanged;
- same Topic/Institution rules pass;
- candidate Blitz is eligible;
- candidate is whole-group;
- established cohort contract can be honored.

This is completion of already-locked official meaning, not replacement.

Preserve:

```text
locked_at
homework_assessment_id
cohort_snapshotted_at
```

Do not churn the original pair-lock timestamp.

### Pair locked + Blitz side already populated

Only exact same-target idempotent replay is permitted.

Do not replace either official task.

## 7.5 Exact Designation Timestamp Semantics

Do not delegate Blitz-side timestamp behavior to a later implementation choice.

### Initial pair creation

When no pair exists, Section 7.2 creates the row with:

```text
designated_by_user_id = authenticated Teacher
designated_at = designatedAt
created_at = designatedAt
updated_at = designatedAt
```

### Blitz-only null-to-Blitz completion

When the Homework side remains unchanged and an eligible Blitz fills a previously
null Blitz side, preserve exactly:

```text
homework_assessment_id
designated_by_user_id
designated_at
cohort_snapshotted_at
locked_at
created_at
```

Change only the approved Blitz-side identity plus the real mutation timestamp:

```text
blitz_assessment_id = candidate Blitz
updated_at = changedAt
```

This preservation rule applies whether the existing pair is unlocked or is the
approved locked staged-completion case.

### Blitz-only replacement before activity

When an unlocked pair already has a different pre-activation Blitz and the
Homework side remains unchanged, preserve:

```text
homework_assessment_id
designated_by_user_id
designated_at
cohort_snapshotted_at
locked_at = null
created_at
```

and change only:

```text
blitz_assessment_id = replacement Blitz
updated_at = changedAt
```

### Homework replacement in the same PUT

If the request genuinely replaces the official Homework and the existing Stage 6
Homework replacement rules allow it, the Homework replacement owns any change to:

```text
designated_by_user_id
designated_at
cohort_snapshotted_at
```

The optional Blitz attachment in that same transaction must not independently
rewrite those fields a second time.

### Exact same-target replay

A semantic no-op performs zero writes and preserves:

```text
designated_by_user_id
designated_at
cohort_snapshotted_at
locked_at
updated_at
```

Do not introduce duplicate Blitz-designation columns.

---

# 8. Official Cohort Contract

The official Homework and official Blitz use one common Student cohort.

## 8.1 Existing cohort

When:

```text
topic_result_pairs.cohort_snapshotted_at != null
```

the established official cohort is authoritative.

Later official Blitz activation must use **exactly** the persisted official cohort.

Do not resnapshot from current Group membership.

Do not:

- add newly joined Students to the official cohort;
- remove Students because they later left the Group;
- silently repair/redefine historical cohort membership.

Normal account-active/security middleware still controls whether a recipient can currently authenticate/use the application.

## 8.2 No cohort established yet

When:

```text
cohort_snapshotted_at = null
```

the first activated official whole-group Assessment establishes the cohort from its valid persisted activation recipient snapshot.

This may be:

```text
official Homework
or
official Blitz
```

If official Blitz activates first:

1. resolve the authorized Topic/Group;
2. snapshot the eligible whole-group recipients;
3. use that exact persisted recipient snapshot as the official Topic cohort;
4. set `cohort_snapshotted_at` to the same authoritative activation transition instant;
5. preserve the official Homework ID;
6. do not create Homework Attempts.

Later activation of the official Homework must use the already-established cohort.

## 8.3 Pair lock and first official activity

The existing Stage 7 rule remains:

- first official Homework Attempt may set null `topic_result_pairs.locked_at`.

Stage 8 must apply the equivalent official meaning protection to Blitz activity.

Before the first official Blitz Attempt is created:

- resolve/lock the official pair;
- require official Blitz identity matches the Attempt Assessment;
- require the Student belongs to the persisted official cohort;
- require cohort snapshot exists;
- if pair `locked_at` is null, set it to the same `startedAt` used by the new Attempt;
- preserve an already non-null lock.

Do not change official task/cohort identity during Student Start.

---

# 9. Timer-Mode Snapshot Contract

Institution setting:

```text
institution_settings.blitz_timer_start_mode
```

allowed configured values:

```text
synchronized
individual
```

The Institution setting may be unconfigured (`null`) before the Institution Admin chooses the policy.

A null timer mode:

- does not block Blitz draft creation;
- does not block Question authoring;
- does not block unrelated Topic/Homework work;
- does not block ordinary Institution administration;
- **does block Blitz activation**.

Activation failure uses the existing incomplete-setting contract:

```text
409 institution_settings_incomplete
```

or the exact already-approved API error shape/code in the live docs.

At successful activation copy the setting into:

```text
blitz_tasks.timer_start_mode_snapshot
```

This snapshot is immutable for the activated Blitz.

Changing the Institution setting afterward must not change an already-activated Blitz.

---

# 10. Whole-Blitz Duration Contract

Teacher configures exactly one duration for the entire Blitz:

```text
duration_seconds > 0
```

No per-question timer exists in the MVP.

Duration is part of the Blitz definition and must not be silently changed after activation.

Do not invent a product maximum in this alignment task if the live approved docs do not already define one.

Do not describe the approximate 5–10 minute classroom intent as a hard validation limit.

## 10.1 Stage 8 Canonical Execution-Time Precision

All backend-generated Stage 8 instants that participate in Blitz execution
eligibility/countdown arithmetic use canonical **UTC whole-second precision**.

This includes at minimum:

```text
activated_at
synchronized_ends_at
Attempt.started_at
Attempt.deadline_at
Student/Teacher execution-response server_now or snapshotAt
timeout finalized_at/locked_at when they equal the persisted deadline
```

When a raw backend/database clock contains fractional seconds:

```text
truncate/floor to the beginning of that UTC second
```

before:

```text
comparison
duration arithmetic
persistence of the affected execution timer field
projection
serialization
```

Never round upward.

Example:

```text
12:00:59.999999Z
-> 12:00:59Z
```

Successful Stage 8 execution/timer wire timestamps use exactly:

```text
YYYY-MM-DDTHH:MM:SSZ
```

with:

```text
UTC Z suffix
no fractional-second component
no non-UTC offset for server-generated execution instants
```

This is a Stage 8 execution-timing specialization of the general RFC3339 API
convention. Existing Teacher-entered schedule/deadline input rules that use the
Institution timezone remain unchanged.

Persisted timer fields used in arithmetic must not contain a hidden fractional
value while the API hides that fraction.

For every response countdown:

```text
remaining_seconds
=
max(
  0,
  deadline_epoch_second - serverNow_epoch_second
)
```

Both operands are the canonical whole-second instants serialized for that
response.

No hidden fractional value participates in `remaining_seconds`.

Device time/timezone never participates in this arithmetic.

---

# 11. Activation Contract

High-risk endpoint:

```text
POST /api/v1/teacher/blitz/{blitz}/activate
```

requires:

```http
Idempotency-Key: <client-generated-uuid>
```

Activation must be concurrency-safe and DB-backed.

At normal first activation from eligible `draft` or `scheduled`, capture one
authoritative canonical instant. Existing activation eligibility, cohort, timer
snapshot and timing rules remain unchanged; Section 11.3 governs replay and
fresh requests for an already-activated Blitz.

```text
activatedAt = truncate_to_utc_second(server_now)
```

Persist/serialize it with zero fractional seconds and use this same value for all
activation-domain timing arithmetic.

Then:

```text
status = active
activated_at = activatedAt
timer_start_mode_snapshot = current configured Institution mode
```

No Student Attempt is created by activation.

## 11.1 Synchronized activation

When snapshot mode is:

```text
synchronized
```

persist:

```text
synchronized_ends_at = activatedAt + duration_seconds
```

All assigned Students share that end instant.

A Student who opens/starts later receives only remaining time.

## 11.2 Individual activation

When snapshot mode is:

```text
individual
```

persist:

```text
synchronized_ends_at = null
```

Activation only makes the Blitz available.

Each eligible Student receives a personal deadline when that Student Starts.

## 11.3 Activation replay and fresh-request lifecycle

Authorization is mandatory before replay or fresh-request execution.

### Completed same-key activation replay

A valid completed activation record with matching scope/key/fingerprint,
valid persisted activation evidence and valid idempotency result metadata
returns `200` with the current authorized Blitz resource when its current
lifecycle is `active`, `closed` or `archived`.

For `closed` or `archived`, this confirms the previous activation historically.
It does not reopen the Blitz, restart its timer or rewrite its lifecycle.
Replay performs zero activation-domain mutation and must not:

```text
rewrite activated_at
rewrite timer_start_mode_snapshot
rewrite synchronized_ends_at
resnapshot recipients
rewrite official cohort
rewrite pair identity/lock
reopen closed/archived Blitz
```

A completed-success record pointing to a current `draft` or `scheduled` Blitz
is an impossible/inconsistent successful-activation history. Fail closed as an
internal integrity inconsistency; do not return a successful replay or invent
a successful public business state. Missing/invalid persisted activation
evidence or idempotency result metadata must not produce a successful replay.

### Fresh/new-key request for an active Blitz

With a new valid idempotency key and current status `active`, activation is
naturally idempotent: return `200` with the current authorized Blitz resource.
The new idempotency claim may complete to that same logical Blitz.

Perform zero activation-domain mutation: no timer restart, no `activated_at`
rewrite, no recipient resnapshot, no official-cohort rewrite, no
`synchronized_ends_at` rewrite, no `timer_start_mode_snapshot` rewrite and no
pair identity/lock rewrite.

### Fresh/new-key request for a closed or archived Blitz

No historical replay exists for the submitted key. Return exactly:

```text
closed   -> 409 task_closed
archived -> 409 task_archived
```

Do not reopen the Blitz. No successful activation idempotency result may remain
for the failed new request.

### Normal first activation

An eligible `draft` or `scheduled` Blitz follows the ordinary successful
activation contract in Sections 6–11.2, including the existing eligibility,
cohort, timer snapshot and timing rules.

Different request fingerprint with reused key:

```text
409 idempotency_key_reused
```

---

# 12. Student Blitz Availability

Student executable Blitz requires:

```text
authenticated active Student
same Institution
persisted assessment_students recipient
Blitz status = active
timer rules still permit Start/execution
normal/exception Attempt capacity permits action
```

Students must not execute:

```text
draft
scheduled
closed
archived
```

Blitz tasks.

Direct UUID possession must never bypass:

- recipient assignment;
- Student ownership;
- Institution isolation;
- active-account middleware;
- lifecycle;
- timer rules.

---

# 13. Student Start / Resume / Replacement-Start Contract

High-risk endpoint:

```text
POST /api/v1/student/blitz/{blitz}/attempts
```

requires:

```http
Idempotency-Key: <client-generated-uuid>
```

The body is **mandatory** and expresses the Student's exact semantic execution
intent.

Final Stage 8 accepted intents are exactly:

```text
start_normal
resume
start_replacement
```

The server validates the submitted intent against current state. It must never
silently reinterpret one intent as another.

## 13.1 Exact request bodies

### Normal Start

Exact body:

```json
{
  "intent": "start_normal"
}
```

Accepted keys:

```text
intent
```

`attempt_id` is forbidden.

`start_normal` creates normal Attempt #1 when capacity is unused and all
preconditions pass, or returns the already-existing editable in-progress #1
under Section 13.9. It must never create or switch to replacement Attempt #2.

### Resume exact Attempt

Exact body:

```json
{
  "intent": "resume",
  "attempt_id": "attempt-uuid"
}
```

Accepted keys:

```text
intent
attempt_id
```

`attempt_id` is required, must be a canonical UUID and identifies the **exact**
own Attempt the Student intends to continue.

For a fresh request, Resume may return only that exact own editable
`in_progress` Attempt under Section 13.9. Completed replay follows Section 13.3.

Resume must never:

```text
create #1
create #2
switch #1 -> #2
switch #2 -> #1
select a newer/current Attempt automatically
derive a replacement Start from current state
```

A stale Resume target that is no longer editable must not become a different
Attempt.

### Confirmed replacement Start

Exact body:

```json
{
  "intent": "start_replacement"
}
```

Accepted keys:

```text
intent
```

`attempt_id` is forbidden.

Only this intent may create replacement Attempt #2, and only when the Student
has the valid unused exception/capacity defined in Section 20. It may return an
existing own editable in-progress #2 under Section 13.9; exact-target Resume
may also return that #2 under the same matrix.

It never creates another normal #1 and never creates #3.

## 13.2 Strict validation

Reject all of the following with:

```text
422 validation_failed
```

before business execution:

```text
missing body
{}
non-object JSON root
malformed JSON
unknown intent
unknown key
missing attempt_id for resume
attempt_id supplied for start_normal
attempt_id supplied for start_replacement
malformed/non-canonical Resume attempt_id
```

No query parameters are accepted.

## 13.3 Idempotency operation and fingerprint

All three intents use one operation:

```text
student.blitz.attempt.start
```

After privacy-safe preliminary Student/recipient/Blitz resolution, request
identity includes:

```text
operation = student.blitz.attempt.start
route.blitz_id = lowercase authorized Blitz UUID
body.intent = exact submitted intent
body.attempt_id = lowercase validated Attempt UUID only for resume
```

Do not include derived server state such as:

```text
timer mode
deadline
server_now
Attempt number
lifecycle state
exception availability
```

in the fingerprint.

Completed valid same key + same fingerprint takes precedence over the fresh
request matrix in Section 13.9, after mandatory authorization:

```text
replay the same logical Start/Resume/replacement-Start result
```

with no new Attempt and no timer/history churn. Preserve the original
successful semantic HTTP status:

```text
201 if the original operation created that Attempt
200 if the original logical operation returned an existing Attempt
```

A later lifecycle transition does not reinterpret the original request into
another intent or replace its completed logical result with a fresh-request
decision.

Same key reused with:

```text
different Blitz
different intent
different Resume attempt_id
```

returns:

```text
409 idempotency_key_reused
```

and performs no domain mutation.

A completed old `start_normal` or `resume` key can never later be reinterpreted
as `start_replacement`.

Starting replacement #2 requires a new logical request/key with:

```json
{"intent":"start_replacement"}
```

## 13.4 Normal synchronized Start

When creating normal Attempt #1 of an active synchronized Blitz:

```text
startedAt = truncate_to_utc_second(server_now)
started_at = startedAt
deadline_at = blitz_tasks.synchronized_ends_at
```

The normal Attempt does not receive a fresh full duration.

If:

```text
startedAt >= synchronized_ends_at
```

no normal Attempt #1 may start.

Do not create an immediately-expired empty normal Attempt.

The approved replacement Attempt #2 is the narrow exception defined in Section
20.3 and receives its own full-duration deadline from its own replacement Start.

## 13.5 Normal individual Start

When creating normal Attempt #1 in individual mode:

```text
startedAt = truncate_to_utc_second(server_now)
started_at = startedAt
deadline_at = startedAt + duration_seconds
```

Persist both timer values with zero fractional seconds.

Later Institution setting changes or client clock changes cannot alter them.

## 13.6 Resume timing

For a fresh request, Resume returns the exact requested own in-progress Attempt
only while it is still editable; due/terminal targets follow Section 13.9.

It must not persist a new "resume time".

It must not change:

```text
started_at
deadline_at
attempt_number
```

Response `server_now` is a fresh canonical UTC whole-second server instant only
for current timing projection.

## 13.7 Replacement Start timing

When `start_replacement` creates Attempt #2:

```text
replacementStartedAt = truncate_to_utc_second(server_now)
Attempt #2.started_at = replacementStartedAt
Attempt #2.deadline_at = replacementStartedAt + duration_seconds
```

This is true in **both** synchronized and individual modes.

For synchronized Blitz:

```text
blitz_tasks.synchronized_ends_at
```

remains the historical class common end and is never rewritten/extended by #2.

## 13.8 Official pair lock

Creating the first Attempt on the official Blitz follows Section 8.3 and may
atomically set a previously-null pair `locked_at`.

Practice Blitz Start does not mutate the result pair.

## 13.9 Exact fresh-request decision/result matrix

Keep exactly one public Start route: the endpoint at the start of Section 13.
The strict bodies, validation and fingerprint rules above remain authoritative.
Completed valid same-key/same-fingerprint results follow Section 13.3 before
this fresh-request matrix. Authorization, lifecycle and applicable timing
requirements remain mandatory.

### `start_normal`

| Own normal Attempt #1 state | Exact result |
|---|---|
| No #1 exists and all authorization/lifecycle/timing requirements pass | Create #1; `201`. |
| #1 is `in_progress` and still editable | Return the same #1; `200`. No new Attempt and no `started_at`/`deadline_at` reset. |
| #1 is `in_progress` and its deadline is reached | Apply authoritative timeout reconciliation when the owning finalization contract is available; then `409 blitz_time_expired`. Never return a stale editable Attempt. |
| #1 is terminal | `409 attempts_exhausted`. Do not create another normal Attempt. |

`start_normal` never creates #2. Separately granted replacement capacity does
not reinterpret this intent.

### `resume`

| Exact requested target state/scope | Exact result |
|---|---|
| Exact own target is `in_progress` and still editable | Return that exact Attempt; `200`. No new Attempt, timer reset or switching. |
| Exact own target is `in_progress` and its deadline is reached | Canonically reconcile the deadline, then `409 blitz_time_expired`. |
| Exact own target is already terminal, including valid terminal execution/checking history as applicable | `409 attempt_not_editable`. |
| Target belongs to another Student, Blitz or Institution, or is otherwise outside the authenticated Student's allowed target scope | Privacy-safe `404 resource_not_found`. |

Resume never creates #1/#2, switches #1 to #2 or #2 to #1, or automatically
selects a newer Attempt.

### `start_replacement`

| Own replacement state/capacity | Exact result |
|---|---|
| Valid unused approved exception capacity exists and all replacement preconditions/lifecycle/timing requirements pass | Create #2; `201`. |
| Own #2 exists as `in_progress` and is still editable | Return the same #2; `200`. No #3 and no timer reset. |
| Existing #2 is `in_progress` and already due | Apply canonical timeout reconciliation; then `409 blitz_time_expired`. |
| Replacement #2 has been consumed and is terminal | `409 attempts_exhausted`. |
| Otherwise structurally valid history has no approved replacement exception/available capacity | `409 attempts_exhausted`. |
| Exception graph/capacity exists but is not valid for replacement | `409 blitz_attempt_exception_not_allowed`, preserving the existing invariant/public-error split. |

Only `start_replacement` may create #2. Never create Attempt #3.

---

# 14. Blitz Attempt Execution States

Stage 8 execution uses the existing shared `assessment_attempts` model.

The meaningful Stage 8 execution states are:

```text
in_progress
submitted
timed_out_finalized
```

`waiting_for_teacher_review` and `checked` are Stage 9 checking/scoring states.

## 14.1 Editable Attempt

```text
status = in_progress
finalized_at = null
locked_at = null
```

Student answer/file mutation is allowed only while:

- Blitz remains active;
- Attempt remains owned/assigned;
- authoritative deadline has not been reached;
- Attempt remains editable.

## 14.2 Explicit Student Submit

Before deadline, successful explicit Submit freezes:

```text
status = submitted
submitted_at = submittedAt
finalized_at = submittedAt
locked_at = submittedAt
finalization_reason = student_submit
```

where:

```text
submittedAt = server_now
```

Saved answers remain unscored/pending for Stage 9.

## 14.3 Timeout

When:

```text
server_now >= attempt.deadline_at
```

authoritative timeout reconciliation freezes an `in_progress` Blitz Attempt as:

```text
status = timed_out_finalized
submitted_at = null
finalized_at = attempt.deadline_at
locked_at = attempt.deadline_at
finalization_reason = timeout_auto_submit
```

The historical finalization instant is the exact persisted deadline, not delayed Scheduler/request processing time.

## 14.4 Teacher close before an Attempt deadline

For an `in_progress` Attempt whose effective deadline has **not** yet been reached, Teacher close freezes:

```text
status = submitted
submitted_at = null
finalized_at = closedAt
locked_at = closedAt
finalization_reason = task_closed_auto_finalize
```

where one authoritative:

```text
closedAt = server_now
```

is captured for the close transaction.

This is an automatic task-close finalization, not an explicit Student Submit.

## 14.5 Teacher close at/after an Attempt deadline

Teacher close must first reconcile deadline expiry.

For each Attempt whose deadline is already reached:

```text
timed_out_finalized
timeout_auto_submit
finalized_at = locked_at = exact deadline_at
```

must win.

Only Attempts still genuinely pre-deadline when locked may use:

```text
submitted
task_closed_auto_finalize
closedAt
```

This is especially important for individual timer mode where different Students may have different deadlines.

## 14.6 Terminal preservation

Once one finalization commits:

- repeated timeout reconciliation does not rewrite it;
- repeated close does not rewrite it;
- later Submit does not rewrite it;
- later answer/file mutation cannot alter it;
- historical reason/timestamps remain stable.

---

# 15. Stage 8 Answer/File Freeze Contract

Stage 8 reuses the delivered typed/file Student answer persistence model.

While the Blitz Attempt is editable, Student may save/replace the supported answer payload.

Every Stage 8 saved answer remains:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

Stage 8 must not run the Question checking strategy.

If the Student never saves a Question:

```text
no attempt_answers row is required
```

If the Student never starts:

```text
no assessment_attempts row is created
```

Timeout/Submit/Teacher close must not fabricate missing answer rows merely to encode zero.

Stage 9 later interprets missing answers/components as zero under the approved scoring rules.

## 15.1 Meaning of “unanswered receives zero”

All live docs must make this sequencing explicit.

The product rule:

> unanswered Blitz work receives zero

does **not** require Stage 8 to persist awarded points.

It means:

```text
Stage 8:
freeze the exact committed answer set

Stage 9:
during checking/scoring, absence of a valid saved answer/component contributes zero
```

Do not create synthetic empty answer rows.

## 15.2 Meaning of “manual answers wait for Teacher review”

Stage 8 must not prematurely change saved answer checking state.

For a saved answer whose Question type/configuration requires manual review:

```text
Stage 8 = frozen + checking_status remains pending
Stage 9 = identifies/reviews it under the checking contract
```

UI/business wording may describe such work as “awaiting later Teacher review,” but must not claim Stage 8 already performed the Stage 9 checking-state transition.

---

# 16. Write vs Finalization Concurrency

For:

```text
typed answer mutation
file answer mutation
vs
Student Submit
timeout reconciliation
Teacher close
```

the only valid outcomes are:

```text
Student mutation commits first
=> that exact committed answer/file state is included in the frozen Attempt

finalization commits first
=> later mutation performs zero answer/file-domain mutation
```

Never allow:

```text
frozen Blitz Attempt
+
Student answer/file mutation committed afterward
```

The technical docs must require:

- DB transaction;
- deterministic relevant row locking;
- locked state re-read;
- authoritative time re-check after locking;
- transition only from `in_progress`;
- no terminal timestamp/reason rewrite.

For file replacement, rejected/late mutation must not replace the persisted Student file identity/content.

---

# 17. Timeout Reconciliation Contract

One authoritative Blitz timeout behavior must be reusable by:

- relevant Student Blitz/detail reads where reconciliation is necessary;
- Attempt Start/Resume boundary;
- typed answer mutation;
- file mutation;
- explicit Submit;
- Teacher Close;
- Teacher monitoring read where current state must be authoritative;
- Laravel Scheduler.

Every write independently checks authoritative time.

Scheduler latency never extends eligibility.

At/equal/after deadline:

```text
server_now >= deadline_at
```

means the Attempt is no longer editable.

Reconciliation:

- finalizes existing `in_progress` Attempt only;
- uses exact `deadline_at`;
- creates no Attempt for never-started Student;
- creates no missing answer row;
- performs no Stage 9 checking/scoring.

---

# 18. Explicit Student Submit and Idempotency

The shared endpoint remains:

```text
POST /api/v1/student/attempts/{attempt}/submit
```

For a Blitz Attempt it must apply Blitz rules.

It requires:

```http
Idempotency-Key: <client-generated-uuid>
```

This is the already-approved high-risk final-submit contract.

Successful pre-deadline Blitz Submit:

- transitions only an own editable `in_progress` Blitz Attempt;
- freezes committed work;
- persists `student_submit`;
- performs no checking/scoring;
- creates no new Attempt.

Same valid key/fingerprint:

- same logical result;
- no second terminal transition;
- no timestamp churn.

Different fingerprint reuse:

```text
409 idempotency_key_reused
```

If the deadline is already reached under the required lock/time re-check:

- required timeout reconciliation must commit;
- late/new Submit returns exactly:
  ```text
  409 blitz_time_expired
  ```
- no new successful Submit idempotency result is created;
- no incomplete new idempotency claim remains committed.

For a **new** key/request against an already-terminal Blitz Attempt:

```text
timed_out_finalized + timeout_auto_submit
-> 409 blitz_time_expired

any other terminal execution state
including submitted + student_submit
or submitted + task_closed_auto_finalize
or later waiting_for_teacher_review|checked
-> 409 attempt_not_editable
```

Do **not** use:

```text
submission_locked
```

as the Stage 8 Blitz Submit error.

A replay of an earlier **successfully completed same-key Student Submit** remains
successful without new domain mutation when the current Attempt still preserves
the original:

```text
finalization_reason = student_submit
submitted_at non-null
finalized_at = submitted_at
locked_at = submitted_at
```

The current Attempt may later be:

```text
submitted
waiting_for_teacher_review
checked
```

as forward-compatible later-stage state. Stage 8 does not create those later
checking states and does not expose checking/score metadata merely for replay.

---

# 19. Teacher Close Contract

Endpoint:

```text
POST /api/v1/teacher/blitz/{blitz}/close
```

Teacher Close itself is **not** added to the approved `Idempotency-Key` list by this task.

Close must nevertheless be naturally safe/idempotent at domain level:

- repeated close does not refinalize;
- repeated close does not change timestamps;
- repeated close does not rewrite Attempt reasons;
- no duplicate history is created.

Close captures one `closedAt` and uses Section 14 rules.

For synchronized mode, after the common end has been reached, timeout semantics win for expired `in_progress` Attempts.

For individual mode, one close transaction may encounter:

- already terminal Attempts;
- already-expired `in_progress` Attempts;
- still-pre-deadline `in_progress` Attempts.

It must:

1. preserve existing terminal Attempts;
2. timeout-finalize already-expired Attempts at their exact deadlines;
3. task-close-finalize still-pre-deadline Attempts at `closedAt`;
4. close the Blitz atomically with the required finalizations.

No Stage 9 checking occurs.

---

# 20. Student-Specific Technical Attempt Exception

Endpoint:

```text
POST /api/v1/teacher/blitz/{blitz}/students/{student}/attempt-exception
```

requires:

```http
Idempotency-Key: <client-generated-uuid>
```

Only an authorized Teacher for the Blitz/Topic/Group may grant it.

Request requires a non-empty valid reason according to the existing API limits.

## 20.1 Preconditions

Require:

- same Institution;
- authorized Teacher;
- Student is a persisted Blitz recipient;
- normal Blitz Attempt #1 exists;
- no prior exception exists for this Student/Blitz;
- Attempt #2 does not already exist;
- exception is for fairness/technical validity, not score improvement;
- `BlitzTask.status = active`.

A new exception may be granted only while `BlitzTask.status = active`.
For every other task lifecycle state, reject the new grant exactly:

```text
draft     -> 409 blitz_attempt_exception_not_allowed
scheduled -> 409 blitz_attempt_exception_not_allowed
closed    -> 409 blitz_attempt_exception_not_allowed
archived  -> 409 blitz_attempt_exception_not_allowed
```

Teacher Close permanently prevents a new exception grant. The grant must not
reopen a closed Blitz.

In synchronized mode, `synchronized_ends_at` may already be in the past while
`BlitzTask.status` remains `active`. That fact alone does not block an otherwise
valid exception grant: approved Student-specific replacement Attempt #2
receives its own full compensating duration under Section 20.3.

The pre-deadline, due and already-terminal #1 rules in Section 20.2 still apply;
every other grant precondition must pass.

If no normal Attempt #1 exists:

```text
409 blitz_normal_attempt_required
```

or the exact already-approved error code.

If exception already exists:

```text
409 blitz_attempt_exception_already_granted
```

If not allowed:

```text
409 blitz_attempt_exception_not_allowed
```

## 20.2 Effect

Granting the exception must:

1. create exactly one durable exception record;
2. preserve normal Attempt #1;
3. mark Attempt #1:

```text
official_score_eligible = false
```

4. never delete/rewrite its Student answers/files;
5. authorize capacity for exactly Attempt #2;
6. not create Attempt #2 on behalf of the Student;
7. not change the class-wide normal Attempt rule.

If Attempt #1 is still `in_progress`, the grant decision is exact and must be
made from locked authoritative state.

### Pre-deadline editable #1

When:

```text
server_now < attempt_1.deadline_at
```

return:

```text
409 blitz_attempt_exception_not_allowed
```

and perform:

```text
no exception insert
no official_score_eligible mutation
no Attempt #2 creation
no synthetic finalization
```

A live editable normal Attempt cannot be invalidated merely to grant another
Attempt.

### Due in-progress #1

When:

```text
server_now >= attempt_1.deadline_at
```

reuse the shared authoritative Blitz timeout finalizer on locked Attempt #1:

```text
status = timed_out_finalized
submitted_at = null
finalized_at = locked_at = exact deadline_at
finalization_reason = timeout_auto_submit
```

Then, within the approved atomic grant workflow and only if all other grant
preconditions still pass:

```text
Attempt #1.official_score_eligible = false
create exactly one exception row
replacement_attempt_id = null
```

The grant still does **not** create Attempt #2.

Already-terminal valid Attempt #1 preserves its existing terminal
reason/timestamps; the grant only applies the approved eligibility exclusion and
exception audit row.

Do not invent a separate `exception_invalidated` finalization reason and do not
allow two simultaneously-`in_progress` Blitz Attempts.

## 20.3 Replacement Attempt

After approved exception, Student Start may create/resume:

```text
Attempt #2
```

only.

There is no Attempt #3.

The exception is intended to compensate one Student for an invalid/interrupted
normal Attempt. Therefore the replacement receives the **same full configured
whole-Blitz duration** from its own server-authoritative replacement Start:

```text
replacementStartedAt = server_now
started_at            = replacementStartedAt
deadline_at           = replacementStartedAt + blitz_tasks.duration_seconds
```

This rule applies to the approved replacement Attempt #2 in **both** timer modes.

### Replacement under synchronized mode

The class-wide synchronized window remains historical and unchanged:

```text
blitz_tasks.activated_at
blitz_tasks.synchronized_ends_at
timer_start_mode_snapshot = synchronized
```

Granting or starting the replacement must **not**:

- restart Teacher activation;
- rewrite `activated_at`;
- rewrite `synchronized_ends_at`;
- extend time for any other Student;
- change `timer_start_mode_snapshot`;
- create a second class-wide timer.

Instead, Attempt #2 is the narrow Student-specific technical-exception path and
uses its persisted compensating `deadline_at` from `replacementStartedAt`.

This means a valid exception may still be usable after the original synchronized
common end while the Blitz remains `active` and all other exception/lifecycle
rules permit the replacement Start.

### Replacement under individual mode

Attempt #2 likewise receives:

```text
deadline_at = replacementStartedAt + duration_seconds
```

exactly like a normal individual Start, but only after the approved exception.

### Shared replacement invariants

```text
the Teacher exception authorizes one replacement Attempt;
the replacement uses the existing configured duration;
it never changes the configured Blitz duration;
it never changes the Institution timer-start mode snapshot;
it never changes the class-wide synchronized activation/end window;
it affects only the authorized Student.
```

Do not invent a different/special duration value for the exception.

Stage 9 later uses only the eligible valid replacement Attempt as the potential
official Blitz score source.

---

# 21. High-Risk Idempotency Contract

The approved five high-risk client mutation categories remain:

```text
Start Homework Attempt
Start Blitz Attempt
Final Submit
Activate Blitz
Grant Blitz Attempt Exception
```

Stage 8 must not broaden this list casually.

For Stage 8 the required operations are:

```text
Student Blitz Attempt Start
Student final Submit of a Blitz Attempt
Teacher Blitz activation
Teacher Blitz exception grant
```

Reuse the delivered durable:

```text
idempotency_records
```

model.

The Stage 8 high-risk operation set is exactly:

```text
student.blitz.attempt.start
student.blitz.attempt.submit
teacher.blitz.activate
teacher.blitz.attempt_exception.grant
```

Stage 8 final Submit uses exactly `student.blitz.attempt.submit`. The delivered
Stage 7 Homework operation remains `student.homework.attempt.submit` unchanged.
Do not merge Homework and Blitz Submit operation identities or substitute an
Assessment-type-independent final-submit operation.

Ordinary:

- answer PUT;
- file-answer mutation;
- Teacher Close;
- schedule;
- archive;
- result-pair PUT

do not gain an `Idempotency-Key` requirement from this alignment task unless already explicitly approved elsewhere.

Authorization always remains mandatory during replay.

---

# 22. Teacher Monitoring Boundary

While an active Blitz is in progress, Teacher monitoring may expose authorized operational state such as:

- assigned Student;
- not started;
- started;
- in progress;
- explicit submitted/frozen;
- timed-out finalized;
- task-close finalized;
- Attempt number;
- remaining/time-spent projection where available;
- exception granted;
- technical issue marker where supported;
- later-review pending projection where safe.

Monitoring must not:

- allow Teacher to answer for Student;
- expose another Institution;
- rewrite Student answers;
- award points;
- perform Stage 9 checking;
- create an Attempt;
- extend a deadline;
- change timer mode.

If monitoring triggers authoritative timeout reconciliation, it must reuse the same finalization engine and not implement a competing transition path.

---

# 23. Security / Tenant Isolation

Preserve and explicitly apply:

```text
Tenant first
authorization second
resource exposure last
```

Teacher Blitz operations require:

- authenticated Teacher;
- active account;
- same Institution;
- current required Teacher–Group authorization;
- same Topic;
- same Group scope;
- no cross-Tenant direct-ID lookup.

Student Blitz operations require:

- authenticated Student;
- active account;
- same Institution;
- persisted `assessment_students` recipient;
- own Attempt only;
- same-Assessment Question;
- same-Question child IDs;
- protected private file authorization.

Malformed/foreign/unauthorized direct IDs must follow the existing privacy-safe `404 resource_not_found` policy where applicable.

Knowledge of a UUID never grants access.

Device type never expands permission.

---

# 24. Exact Live-Document Edit Map

Use Sections 2–23 as authoritative.

Do not restate them with different semantics.

| Document | Required alignment |
|---|---|
| `docs/01-business-overview.md` | Clarify Stage 8 Blitz execution/finalization vs Stage 9 checking/scoring; timeout/close freeze committed work only; no fake Attempt/answer rows; unanswered zero is a later checking interpretation, not Stage 8 awarded-points persistence. Preserve Stage 7 Homework wording. |
| `docs/02-user-roles.md` | Keep Teacher/Student authority boundaries; clarify Teacher controls activation/duration/exception but never authoritative clock or Student answers; Stage 8 monitoring does not equal checking/scoring. |
| `docs/03-features.md` | Align Blitz timeout/close semantics to frozen pending work; remove immediate Stage 8 scoring implication; keep one normal Attempt + one exception; clarify official cohort/timer snapshot and Teacher monitoring. |
| `docs/04-user-flows.md` | Ensure flow is author → designate official Blitz when applicable → activate → Student Start → save → explicit Submit or timeout/close freeze → Stage 9 checking/review/scoring. Preserve final Stage 10 result flow. |
| `docs/05-business-rules.md` | Align `BR-BLZ-*` and `BR-ATT-*`: lifecycle, official designation, cohort, synchronized/individual timing, timeout/close terminal states, no immediate checking/scoring, no fake rows, one exception, replacement eligibility. Freeze Section 20.1 active-only new exception grants: draft/scheduled/closed/archived return `409 blitz_attempt_exception_not_allowed`; Teacher Close permanently prevents new grants; an elapsed synchronized common end alone does not block a valid grant while active. |
| `docs/06-roadmap.md` | Make Stage 8 completion criteria explicitly execution/finalization only and Stage 9 the owner of checking/scoring; preserve Stage 7 and Stage 10 boundaries; include concurrency/idempotency and result-pair/cohort semantics. |
| `docs/07-architecture.md` | Separate Blitz execution engine from checking engine; freeze activation/timer/deadline, terminal-state, timeout/close, official pair/cohort, exception, idempotency, and lock/concurrency contracts. Apply Section 20.1 active-only new exception-grant lifecycle, including permanent Teacher Close rejection and the elapsed synchronized-end allowance while active. Remove wording that Stage 8 immediately checks/scores on timeout. |
| `docs/08-database.md` | Align Blitz-specific detail table, Attempt lifecycle meaning, timeout/close timestamps/reasons, answer `pending` state, no fabricated answer row, exception eligibility/history, idempotency operation usage, and exact result-pair create/completion/replacement persistence. Exception persistence follows Section 20.1 active-only grant preconditions. Use the exact four Stage 8 operations in Section 21, including `student.blitz.attempt.submit`; preserve the separate `student.homework.attempt.submit` identity without an Assessment-type-independent alternative. Blitz-only attach/replacement preserves `designated_by_user_id`/`designated_at`; only the owning Homework replacement may change those fields. Do not redesign already-delivered common tables unnecessarily. |
| `docs/09-api-contracts.md` | Align Teacher Blitz authoring/lifecycle, result-pair PUT extension including initial atomic pair creation, activation idempotency, exact `timer_start_mode_snapshot` naming, and the final Student execution API. Apply Section 11.3 exactly: authorized completed same-key activation replay returns `200` for current active/closed/archived with valid activation evidence/result metadata and zero activation-domain mutation; current draft/scheduled is an internal integrity inconsistency. Fresh/new-key active returns `200` without activation-domain mutation; fresh closed/archived returns `409 task_closed`/`409 task_archived` with no successful claim; eligible first draft/scheduled activation remains unchanged. In §2.11 add the stricter Stage 8 server-generated execution-timestamp rule: UTC whole seconds, `YYYY-MM-DDTHH:MM:SSZ`, truncate/floor before timer comparison/arithmetic/persistence/projection, and exact integer `remaining_seconds`. In §18.2 fix the Create Blitz nested `questions[]` example/contract so every nested Question includes required unique `client_key`, `checking_mode`, and canonical `configuration` along with type/prompt/instructions/points/position. In §20.3 replace create-or-resume/empty-body wording with the three exact mandatory intent bodies (`start_normal`, `resume` + exact `attempt_id`, `start_replacement`), strict field rules, no-switch Resume, and idempotency fingerprint identity containing intent plus Resume target. Include the exact Section 13.9 result/error matrix and completed-replay precedence preserving original `201`/`200`. In §20.5 use exactly `student.blitz.attempt.submit`, separate from unchanged `student.homework.attempt.submit`, and replace `submission_locked` Blitz behavior with exact `blitz_time_expired` vs `attempt_not_editable` rules while preserving successful same-key replay. Use the exact four Stage 8 operations in Section 21 with no alternative Submit identity. Align Blitz Attempt projection, answer/file timer enforcement, timeout reconciliation, close, exception, monitoring and stable errors. Section 20.1 permits a new exception only while active; draft/scheduled/closed/archived return `409 blitz_attempt_exception_not_allowed`; Teacher Close permanently prevents new grants; elapsed synchronized end alone does not block a valid active grant. Exception grant rejects pre-deadline editable #1, may first timeout-reconcile a due #1 and preserves already-terminal #1 reason/timestamps. Remove immediate Stage 8 scoring response fields/meaning. |

---

# 25. Required `docs/05-business-rules.md` Corrections

At minimum, correct Blitz wording equivalent to:

```text
Teacher close evaluates answered components immediately
timeout immediately scores automatically-checkable answers
manual answers enter persisted Waiting for teacher review during Stage 8
```

Replace with:

```text
Stage 8 freezes all successfully committed Student work.

No Stage 8 checking/scoring is performed.

No answer row is fabricated for unanswered work.

Stage 9 later:
- treats absent/unanswered work as zero;
- checks objective answers;
- routes manual answers through Teacher review;
- awards points and completes scoring.
```

Preserve the business meaning that timeout does not turn an otherwise valid saved manual answer into “wrong”.

---

# 26. Required `docs/06-roadmap.md` Stage 8 Boundary

Stage 8 must read semantically as:

```text
Stage 8 produces trustworthy immutable Blitz execution history
that Stage 9 later consumes for checking/scoring.
```

Stage 8 acceptance must prove:

- Teacher can create/run Blitz;
- both timer modes work;
- Student can execute;
- authoritative timeout works;
- Teacher close works;
- technical exception works;
- Tenant/security boundaries hold;
- immutable Attempt/answer history is preserved.

Stage 8 acceptance must not require the Stage 9 scoring engine to exist.

Where existing Stage 8 text says:

```text
unanswered receive zero
manual review remains waiting
```

clarify sequencing:

```text
Stage 8 freezes the execution state;
Stage 9 later applies zero/checking/review semantics.
```

---

# 27. Required `docs/07-architecture.md` Contracts

## 27.1 Application Actions

Keep/align the intended Stage 8 application services such as:

```text
ActivateBlitz
StartBlitzAttempt
SubmitBlitzAttempt
FinalizeTimedOutBlitzAttempt
FinalizeAttemptsOnTaskClose
GrantBlitzAttemptException
```

Naming may remain architectural rather than exact future class names.

Do not merge Homework and Blitz lifecycle logic merely because both use shared `AssessmentAttempt`.

## 27.2 Domain ownership

Domain layer owns:

- activation eligibility;
- timer-mode snapshot;
- deadline calculation;
- one-normal-Attempt rule;
- timeout finalization;
- Teacher-close finalization;
- exception eligibility;
- official-score eligibility exclusion;
- terminal immutability.

Stage 9 checking strategies remain separate.

## 27.3 Timeout architectural state

`timed_out_finalized` is the persisted Stage 8 timeout state under the already-delivered common Attempt enum.

Clarify:

```text
timed_out_finalized
= authoritative deadline reached
= committed Student work frozen
= no longer editable
= not a missing/abandoned Attempt
= not proof that checking/scoring completed
```

---

# 28. Required `docs/08-database.md` Alignment

Preserve the existing common:

```text
assessment_attempts
attempt_answers
```

Do not introduce duplicate Blitz Attempt/Answer tables.

Document the exact Stage 8 idempotency operation set from Section 21.
Blitz Submit uses `student.blitz.attempt.submit`; preserve the separate delivered
Homework operation `student.homework.attempt.submit` without an alternative
Assessment-type-independent Submit identity.

## 28.1 Blitz detail persistence

Keep the approved Blitz detail direction including:

```text
assessment_id
institution_id
status
duration_seconds
scheduled_at
timer_start_mode_snapshot
activated_at
synchronized_ends_at
closed_at
```

and other already-approved lifecycle timestamps if present.

Do not use this DOC task to invent unnecessary new fields.

## 28.2 Attempt deadline

The persisted deadline depends on both the Attempt number/purpose and the
activation timer snapshot.

### Normal Attempt #1 — synchronized

For the normal Attempt #1 of a Blitz whose activation snapshot is
`synchronized`:

```text
deadline_at = blitz_tasks.synchronized_ends_at
```

The Student may receive less than the full configured duration when starting
late. At or after the common synchronized end, no new normal Attempt #1 may be
created.

### Normal Attempt #1 — individual

For the normal Attempt #1 of a Blitz whose activation snapshot is `individual`:

```text
deadline_at = started_at + blitz_tasks.duration_seconds
```

The Student receives the full configured duration from their own Start.

### Replacement Attempt #2 — both timer modes

For the one Teacher-approved Student-specific replacement Attempt #2, regardless
of whether the original activation snapshot was `synchronized` or `individual`:

```text
deadline_at = started_at + blitz_tasks.duration_seconds
```

Attempt #2 receives a fresh full recovery interval from its own
server-authoritative Start. In synchronized mode it must **not** reuse:

```text
blitz_tasks.synchronized_ends_at
```

as its Attempt deadline.

Creating or resuming replacement Attempt #2 must not change:

```text
blitz_tasks.timer_start_mode_snapshot
blitz_tasks.activated_at
blitz_tasks.synchronized_ends_at
```

or any other Student's deadline. The class-wide synchronized window remains
historical and unchanged.

Persist the effective per-Attempt `deadline_at` for history, reconciliation, and
concurrency safety.

## 28.3 Finalization fields

Explicit Submit:

```text
status = submitted
submitted_at = finalized_at = locked_at = server submit instant
finalization_reason = student_submit
```

Timeout:

```text
status = timed_out_finalized
submitted_at = null
finalized_at = locked_at = exact deadline_at
finalization_reason = timeout_auto_submit
```

Teacher close before deadline:

```text
status = submitted
submitted_at = null
finalized_at = locked_at = captured close instant
finalization_reason = task_closed_auto_finalize
```

## 28.4 Answers

Before Stage 9:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

No fabricated unanswered row.

## 28.5 Exception

Preserve one durable exception row per Student/Blitz maximum according to the already-approved table design.

It must identify the invalidated normal Attempt and the approving actor/reason/history according to existing database terminology.

Original Attempt remains present.

Original Attempt:

```text
official_score_eligible = false
```

Do not require a replacement Attempt row to exist at exception-grant time.

---

# 29. Required `docs/09-api-contracts.md` Alignment

## 29.1 Teacher authoring

Keep the approved route family:

```text
GET   /api/v1/teacher/blitz
POST  /api/v1/teacher/topics/{topic}/blitz
GET   /api/v1/teacher/blitz/{blitz}
PATCH /api/v1/teacher/blitz/{blitz}
POST  /api/v1/teacher/blitz/{blitz}/schedule
POST  /api/v1/teacher/blitz/{blitz}/archive
```

Teacher payload includes task content such as assignment/instructions/duration.

For the Create Blitz request, nested:

```text
questions[]
```

must use the delivered canonical nested Question authoring shape.

Every nested create Question contains the applicable canonical fields including:

```text
client_key
type
prompt
instructions
points
position
checking_mode
configuration
```

Example:

```json
{
  "client_key": "q1",
  "type": "true_false",
  "prompt": "DNS resolves domain names.",
  "instructions": null,
  "points": 1,
  "position": 1,
  "checking_mode": "automatic",
  "configuration": {
    "correct_value": true
  }
}
```

Rules:

- `client_key` is required in the nested create collection for request-level
  identity;
- `client_key` values are unique within the request;
- it is not persisted/returned as Question identity;
- `checking_mode` is required and must match the canonical rule for the selected
  Question type;
- all nine approved Question types reuse their existing
  checking-mode/configuration contract;
- positions are contiguous `1..N`;
- no per-question timer is added;
- total possible points are calculated server-side;
- empty `questions` and total `0` remain valid before activation.

Do not preserve the old Blitz Create example that omits `client_key` or
`checking_mode`.

Do not accept Teacher overrides for:

```text
normal_attempt_count
timer_start_mode_snapshot
activated_at
synchronized_ends_at
```

## 29.2 Official result pair

Document Section 7 Stage 8-compatible extension to:

```text
PUT /api/v1/teacher/topics/{topic}/result-pair
```

without breaking Stage 6 Homework-only callers.

## 29.3 Activate

```text
POST /api/v1/teacher/blitz/{blitz}/activate
Idempotency-Key required
```

Apply Section 11.3 after authorization:

| Request/history | Current Blitz lifecycle | Exact result |
|---|---|---|
| Completed same-key/same-fingerprint activation with valid persisted activation evidence and idempotency result metadata | `active`, `closed`, `archived` | `200` current authorized Blitz resource; zero activation-domain mutation. Closed/archived confirms historical activation without reopening, timer restart or lifecycle rewrite. |
| Completed-success activation record | `draft`, `scheduled` | Fail closed as an internal integrity inconsistency; never a successful replay. |
| Fresh/new valid key | `active` | Naturally idempotent `200` current resource; new claim may complete to the same Blitz; zero activation-domain mutation. |
| Fresh/new valid key | `closed` | `409 task_closed`; no successful activation result remains for this request. |
| Fresh/new valid key | `archived` | `409 task_archived`; no successful activation result remains for this request. |
| Normal first activation | Eligible `draft`, `scheduled` | Existing successful activation eligibility/cohort/timer rules remain unchanged. |

Replay and fresh active success must not rewrite `activated_at`,
`timer_start_mode_snapshot`, `synchronized_ends_at`, recipients, official cohort
or pair identity/lock. No request may reopen closed/archived Blitz.

Response must expose enough authoritative state for frontend timing, including
the exact frozen activation field:

```text
status
activated_at
timer_start_mode_snapshot
duration_seconds
synchronized_ends_at when applicable
```

`timer_start_mode_snapshot` is the authoritative Blitz resource/API field.

Do not expose or document a parallel successful-response field named:

```text
timer_start_mode
```

The current Institution setting remains a separate configuration source; the
activated Blitz response exposes its persisted snapshot.

Do not expose an editable client timer source of truth.

## 29.4 Student active/detail

Keep:

```text
GET /api/v1/student/blitz/active
GET /api/v1/student/blitz/{blitz}
```

Student-safe projection must not expose correct-answer/checking configuration.

It must expose enough server data for UI availability/countdown without making the device authoritative.

## 29.5 Start / Resume / Replacement Start

```text
POST /api/v1/student/blitz/{blitz}/attempts
Idempotency-Key required
Content-Type: application/json
no query
```

The body is mandatory.

Exact bodies:

### Normal Start

```json
{"intent":"start_normal"}
```

### Resume exact Attempt

```json
{"intent":"resume","attempt_id":"attempt-uuid"}
```

### Confirmed replacement Start

```json
{"intent":"start_replacement"}
```

Strict public rules:

```text
intent required
attempt_id required iff intent=resume
attempt_id forbidden for both Start intents
unknown keys/intents rejected
empty/{} body rejected
non-object/malformed body rejected
malformed Resume UUID rejected
```

Request-shape failures use:

```text
422 validation_failed
```

Resume is exact-target only and never creates/switches Attempts.

Only `start_replacement` may create replacement #2.

All three intents share:

```text
operation = student.blitz.attempt.start
```

The idempotency fingerprint includes:

```text
authorized Blitz UUID
intent
Resume attempt_id only when intent=resume
```

Same key with a different Blitz, intent or Resume target:

```text
409 idempotency_key_reused
```

Success returns the authoritative Attempt and preserves:

```text
attempt_number
status
started_at
deadline_at
server_now / remaining_seconds timing projection
```

The exact fresh-request matrix is Section 13.9; document every result:

| Intent | Exact results |
|---|---|
| `start_normal` | No #1 and all preconditions pass: create #1, `201`. Existing own editable in-progress #1: same #1, `200`, no timer reset. Due in-progress #1: authoritative timeout reconciliation when the owning finalization contract is available, then `409 blitz_time_expired`. Terminal #1: `409 attempts_exhausted`. Never create #2 or reinterpret replacement capacity as normal capacity. |
| `resume` | Exact own editable in-progress target: `200` exact Attempt, no creation/reset/switching. Due exact in-progress target: canonical deadline reconciliation, then `409 blitz_time_expired`. Already-terminal target, including valid terminal execution/checking history as applicable: `409 attempt_not_editable`. Foreign Student/Blitz/Institution or otherwise out-of-scope target: privacy-safe `404 resource_not_found`. Never create #1/#2 or select another/newer Attempt. |
| `start_replacement` | Valid unused approved exception capacity and all preconditions pass: create #2, `201`. Existing own editable in-progress #2: same #2, `200`, no timer reset. Due in-progress #2: canonical timeout reconciliation, then `409 blitz_time_expired`. Consumed terminal #2 or otherwise structurally valid history with no approved exception/available capacity: `409 attempts_exhausted`. Existing invalid exception graph/capacity: `409 blitz_attempt_exception_not_allowed` under the existing invariant/public-error split. Never create #3. |

Completed valid same-key/same-fingerprint replay takes precedence after
authorization: return the original logical result without a new Attempt,
preserving `201` if it originally created the Attempt or `200` if it originally
returned an existing Attempt. A later lifecycle transition does not reinterpret
the original request into another intent. Fresh returns never reset
`started_at` or `deadline_at` on an existing Attempt.

No score is produced.

## 29.6 Answer/file mutation

Use the approved shared Student Attempt answer route family.

Only own editable `in_progress` Blitz Attempt may mutate.

Every mutation rechecks authoritative deadline.

No awarded points/check result is returned as Stage 8 output.

## 29.7 Submit

```text
POST /api/v1/student/attempts/{attempt}/submit
Idempotency-Key required
```

The Stage 8 operation is exactly `student.blitz.attempt.submit`. Do not merge
it with or change the delivered `student.homework.attempt.submit` operation.

For Blitz success, response shows frozen execution state, not a final score.

Exact Stage 8 terminal behavior:

```text
same completed successful Submit key/fingerprint
-> 200 successful logical replay

new Submit when Attempt is timeout-finalized
-> 409 blitz_time_expired

new Submit when Attempt is any other terminal execution state
-> 409 attempt_not_editable
```

Do not document/use:

```text
409 submission_locked
```

for Blitz Submit.

A late in-progress Submit may first trigger authoritative timeout reconciliation,
then returns `409 blitz_time_expired` and creates no successful Submit claim.

## 29.7.1 Stage 8 timer serialization in public resources

Every server-generated Blitz execution/timer instant returned by the Stage 8
execution API uses canonical UTC whole-second form:

```text
YYYY-MM-DDTHH:MM:SSZ
```

No fractional-second successful wire value.

Timer comparison/arithmetic uses the same truncated whole-second values.

For any Attempt countdown:

```text
remaining_seconds
=
max(0, deadline_epoch_second - serverNow_epoch_second)
```

The serialized `deadline_at` and `server_now` are the exact operands.

## 29.8 Timeout reconciliation

Relevant read/write endpoints may reconcile an expired Attempt before serializing/deciding.

A timed-out Attempt response may expose:

```text
status = timed_out_finalized
finalization_reason = timeout_auto_submit
finalized_at = deadline_at
```

but must not claim Stage 9 checking completion.

## 29.9 Close

```text
POST /api/v1/teacher/blitz/{blitz}/close
```

No new `Idempotency-Key` requirement.

Must follow Section 19 semantics.

## 29.10 Exception

```text
POST /api/v1/teacher/blitz/{blitz}/students/{student}/attempt-exception
Idempotency-Key required
```

Require reason.

Apply Section 20.1 exactly: a new grant requires `BlitzTask.status = active`.
Draft/scheduled/closed/archived return `409 blitz_attempt_exception_not_allowed`.
Teacher Close permanently prevents a new grant; grants never reopen the Blitz.
An elapsed `synchronized_ends_at` alone does not block a valid active grant
because #2 receives its own full compensating duration. Preserve Section 20.2
pre-deadline rejection, due #1 reconciliation and terminal #1 history.

Return durable exception/current attempt-capacity state, not score.

## 29.11 Monitoring

Teacher monitoring endpoint/resource must distinguish execution states safely without forcing Stage 9 scoring to exist.

---

# 30. Stable Error Behavior to Preserve/Align

Use existing stable API codes where already approved.

Stage 8 documentation must consistently cover at least:

```text
validation_failed
resource_not_found
business_conflict
institution_settings_incomplete
idempotency_key_reused
blitz_not_active
task_closed
task_archived
blitz_time_expired
attempt_not_editable
attempts_exhausted
blitz_attempt_exception_not_allowed
blitz_attempt_exception_already_granted
blitz_normal_attempt_required
```

The Section 13.9 Start matrix is authoritative, with no alternative public
error convention:

| Exact result | Start/Resume/replacement condition |
|---|---|
| `201` | Valid fresh `start_normal` creates #1 or valid fresh `start_replacement` creates #2. |
| `200` | `start_normal` returns own editable in-progress #1, `resume` returns its exact own editable in-progress target, or `start_replacement` returns own editable in-progress #2. No timer reset or new Attempt. |
| `409 blitz_time_expired` | The selected existing in-progress #1, exact Resume target or #2 is due; reconcile under Section 13.9 before returning. |
| `409 attempt_not_editable` | Exact own Resume target is already terminal, including valid terminal execution/checking history as applicable. |
| `404 resource_not_found` | Resume target is outside the authenticated Student's allowed Student/Blitz/Institution scope. |
| `409 attempts_exhausted` | `start_normal` finds terminal #1; `start_replacement` finds consumed terminal #2 or otherwise structurally valid history with no approved exception/available capacity. |
| `409 blitz_attempt_exception_not_allowed` | `start_replacement` finds an existing exception graph/capacity invalid for replacement, under the existing invariant/public-error split. |
| `409 idempotency_key_reused` | Same Start key is reused with another Blitz, intent or Resume `attempt_id`. |

Completed valid Start replay takes precedence after authorization and preserves
the original logical `201`/`200` result; it never creates a new Attempt or
reinterprets intent. Only `start_replacement` creates #2; no Attempt #3 exists.

Activation lifecycle errors follow Section 11.3: fresh/new-key closed returns
`409 task_closed`, and fresh/new-key archived returns `409 task_archived`.
Neither error invalidates a valid completed historical replay. New exception
grants outside `active` use `409 blitz_attempt_exception_not_allowed` under
Section 20.1.

Do not invent duplicate synonymous errors.

For Blitz Submit specifically, `submission_locked` is stale and must not be
documented as its terminal conflict. Use Section 18/29.7 exact behavior.

If the live API document retains `submission_locked` for some unrelated
pre-existing non-Blitz contract, it must not be presented as a Blitz code.

Privacy-safe unauthorized direct resource IDs must not leak cross-Tenant existence.

---

# 31. Non-Goals

Do not add/redesign:

- Stage 9 checking implementation;
- automatic checking code;
- manual review endpoints;
- awarded-points implementation;
- score calculation;
- official score persistence implementation;
- Stage 10 Topic result;
- AI/fuzzy grading;
- anti-cheat/device monitoring;
- live competition;
- configurable normal Blitz attempt count;
- per-question timer;
- Teacher timer-mode override;
- more than one additional exception Attempt;
- extra Homework Attempt exception;
- new Question types;
- new roles;
- impersonation;
- source code;
- migrations;
- tests;
- frontend;
- E2E harness;
- unrelated documentation cleanup.

---

# 32. Acceptance Criteria

## Stage boundary

- Stage 8 is explicitly Blitz execution/finalization.
- Stage 9 explicitly owns automatic/manual checking, awarded points, Attempt scoring, and official task scores.
- No Stage 8 timeout/close wording still requires immediate automatic scoring.
- No Stage 8 finalization wording still requires persisted Teacher-review transition.
- Full MVP later checking/scoring rules remain documented.

## Lifecycle

- Blitz statuses are exactly `draft / scheduled / active / closed / archived`.
- draft/scheduled are not Student-executable.
- Teacher activation is required.
- close blocks Starts/writes and freezes existing in-progress work.
- archive preserves history.

## Official pair/cohort

- official Blitz is whole-group only;
- selected-Student Blitz cannot become official;
- a valid official Homework is required, but a pre-existing pair row is not;
- one PUT may atomically create the initial pair with required Homework and optional eligible Blitz;
- an existing `topic_result_pairs` row is reused/completed rather than duplicated;
- existing official Homework is preserved for Blitz-only attach/replacement;
- Blitz-only attach/replacement preserves `designated_by_user_id` and `designated_at`;
- initial pair creation sets designation metadata once;
- a valid Homework replacement may update designation metadata only under the existing Stage 6 replacement rules;
- locked pair may fill a previously-null Blitz side while preserving designation/cohort/lock history;
- locked populated Blitz side cannot be replaced;
- established official cohort is reused exactly;
- first activated official task may establish cohort when none exists;
- later Group changes do not redefine cohort;
- first official Blitz Attempt can lock a previously-unlocked pair.

## Timing

- one whole-Blitz duration;
- no per-question timer;
- Institution timer mode is snapshotted at activation;
- activated Blitz API/resource naming uses exact `timer_start_mode_snapshot`;
- no parallel successful-response `timer_start_mode` field is documented;
- null Institution setting blocks activation only;
- normal Attempt #1 in synchronized mode uses the shared `synchronized_ends_at`;
- normal Attempt #1 in individual mode uses `started_at + duration_seconds`;
- replacement Attempt #2 uses a fresh `started_at + duration_seconds` deadline in both timer modes;
- replacement Attempt #2 never rewrites or extends the class-wide `synchronized_ends_at`;
- server time is authoritative;
- device clock/timezone cannot extend time;
- persisted Attempt deadline is authoritative;
- raw server execution clock is truncated/floored to UTC whole seconds before timer comparison/arithmetic/persistence/projection;
- successful execution timer timestamps serialize exactly `YYYY-MM-DDTHH:MM:SSZ` with no fraction;
- `remaining_seconds = max(0, deadline_epoch_second - serverNow_epoch_second)` using the exact serialized whole-second operands.

## Attempts

- exactly one normal Blitz Attempt;
- Start endpoint requires an explicit body intent: `start_normal|resume|start_replacement`;
- `resume` requires exact `attempt_id`; both Start intents forbid `attempt_id`;
- empty/`{}`/unknown/malformed Start bodies are validation failures;
- `start_normal` never creates replacement #2;
- fresh `start_normal` creates unused #1 with `201`, returns own editable in-progress #1 with `200` without resetting `started_at`/`deadline_at`, timeout-reconciles due in-progress #1 when the owning finalization contract is available then returns `409 blitz_time_expired`, and rejects terminal #1 with `409 attempts_exhausted`;
- separately granted replacement capacity never reinterprets `start_normal`;
- fresh `resume` returns only the exact requested own editable in-progress Attempt with `200` and never creates/switches Attempts;
- due exact in-progress Resume target is canonically reconciled then returns `409 blitz_time_expired`;
- already-terminal exact Resume target, including valid terminal execution/checking history as applicable, returns `409 attempt_not_editable`;
- Resume targets belonging to another Student/Blitz/Institution or otherwise outside allowed scope return privacy-safe `404 resource_not_found`;
- only `start_replacement` may create replacement #2;
- fresh `start_replacement` with valid unused approved capacity and all preconditions passing creates #2 with `201`; existing own editable in-progress #2 returns the same #2 with `200` without timer reset;
- due in-progress #2 is canonically timeout-reconciled then returns `409 blitz_time_expired`;
- consumed terminal #2 or otherwise structurally valid history with no approved exception/available replacement capacity returns `409 attempts_exhausted`;
- existing invalid exception graph/capacity returns `409 blitz_attempt_exception_not_allowed` under the existing invariant/public-error split;
- resume never resets timer;
- exception permits at most Attempt #2;
- no Attempt #3;
- exception requires normal Attempt #1;
- a new exception grant requires exactly `BlitzTask.status = active`;
- draft/scheduled/closed/archived new exception grants return `409 blitz_attempt_exception_not_allowed`;
- Teacher Close permanently prevents a new exception grant; the grant never reopens a closed Blitz;
- an elapsed `synchronized_ends_at` alone does not block an otherwise valid grant while active because replacement #2 receives its own full compensating duration;
- pre-deadline editable in-progress #1 rejects grant with `blitz_attempt_exception_not_allowed`;
- due in-progress #1 is timeout-finalized at exact deadline before grant may continue;
- already-terminal #1 preserves its terminal reason/timestamps;
- original Attempt is preserved and becomes ineligible only on successful grant;
- exception grant does not create Attempt #2 automatically.

## Finalization

- explicit Submit → `submitted + student_submit`;
- timeout → `timed_out_finalized + timeout_auto_submit`;
- Teacher close before deadline → `submitted + task_closed_auto_finalize`;
- timeout uses exact deadline instant;
- close after deadline preserves timeout reason/time;
- individual-mode close handles different Student deadlines correctly;
- terminal history is immutable;
- no fake Attempt for never-started Student;
- no fake answer row for unanswered Question.

## Answers/files

- Stage 8 saved answers remain `pending`;
- no Stage 8 awarded points;
- no Stage 8 check metadata;
- unanswered zero is applied later by Stage 9;
- manual-review answers are frozen pending later Stage 9 review;
- answer/file write vs finalization is serialized;
- no Student mutation can commit after freeze.

## Idempotency

- Start Blitz Attempt requires `Idempotency-Key`;
- final Submit requires `Idempotency-Key`;
- Blitz activation requires `Idempotency-Key`;
- exception grant requires `Idempotency-Key`;
- Teacher Close does not gain a key requirement;
- the exact Stage 8 operation set is `student.blitz.attempt.start`, `student.blitz.attempt.submit`, `teacher.blitz.activate`, `teacher.blitz.attempt_exception.grant`;
- Blitz Submit uses only `student.blitz.attempt.submit`, preserving separate unchanged `student.homework.attempt.submit` with no Assessment-type-independent alternative;
- same valid request replays without duplicate mutation;
- authorized completed same-key activation replay with valid persisted activation evidence and idempotency result metadata returns `200` current Blitz for active/closed/archived;
- closed/archived completed activation replay confirms history without reopening, timer restart or lifecycle rewrite;
- completed-success activation pointing to current draft/scheduled fails closed as an internal integrity inconsistency, never successful replay;
- fresh/new-key active activation is naturally idempotent `200` current Blitz and may complete the new claim to the same logical Blitz;
- completed activation replay and fresh active success perform zero activation-domain mutation, preserving activation time, timer snapshot, synchronized end, recipients, official cohort and pair identity/lock;
- fresh/new-key closed activation returns `409 task_closed`; archived returns `409 task_archived`; no successful activation result remains for either failed request;
- eligible first activation from draft/scheduled retains existing eligibility/cohort/timer rules;
- Student Blitz Start fingerprint includes exact `intent` and Resume `attempt_id`;
- completed valid same-key/same-fingerprint Start replay precedes the fresh matrix after authorization, creates no new Attempt, and preserves original semantic `201` for creation or `200` for an existing Attempt;
- a completed old Start/Resume key is never reinterpreted as replacement Start;
- later lifecycle transitions never reinterpret a completed Start request into another intent;
- different fingerprint reuse → `409 idempotency_key_reused`;
- durable DB-backed records remain authoritative;
- replay does not bypass authorization.

## Public API alignment

- `docs/09` Create Blitz nested Question example includes required `client_key` and `checking_mode`;
- Student Blitz Start docs contain all three exact intent bodies;
- Start docs do not contain empty-body/create-or-resume ambiguity;
- Resume docs specify exact target/no-switch semantics;
- Start docs contain the complete Section 13.9 result/error matrix with no conditional error-code choice;
- Blitz Submit docs use `blitz_time_expired` for timeout-finalized new requests;
- Blitz Submit docs use `attempt_not_editable` for other terminal new requests;
- Blitz Submit docs do not use `submission_locked`;
- Stage 8 execution timestamps/countdown docs use canonical whole-second rules.

## Security

- same-Institution enforcement;
- Teacher group/topic authorization;
- Student frozen-recipient authorization;
- own Attempt only;
- same-Assessment Question/child validation;
- direct-ID privacy;
- protected file authorization;
- no Student correct-answer leakage;
- Teacher monitoring cannot answer for Student.

## Scope

- only `docs/01-business-overview.md` through `docs/09-api-contracts.md` changed;
- `docs/FINAL_AUDIT_REPORT.md` unchanged;
- code/migrations/tests/frontend/harness/tasks unchanged;
- no Stage 7 Homework regression;
- no Stage 9/10 implementation added.

---

# 33. Verification

No application tests or builds are required.

Run:

```bash
git diff --check
```

Confirm changed filenames are limited to:

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

A subset is acceptable if a document already requires no textual correction, but Codex must inspect all nine specified documents for the focused contradictions listed below.

## 33.1 Required focused-term review

Confirm the live docs are mutually consistent for:

```text
Stage 8
Stage 9
Blitz
draft
scheduled
active
closed
archived
blitz_timer_start_mode
timer_start_mode_snapshot
synchronized
individual
duration_seconds
synchronized_ends_at
deadline_at
timed_out_finalized
timeout_auto_submit
task_closed_auto_finalize
student_submit
checking_status = pending
official_score_eligible
blitz_attempt_exceptions
blitz_assessment_id
cohort_snapshotted_at
locked_at
Idempotency-Key
student.blitz.attempt.start
student.blitz.attempt.submit
teacher.blitz.activate
teacher.blitz.attempt_exception.grant
student.homework.attempt.submit
completed same-key activation replay
fresh/new-key activation
valid persisted activation evidence
valid idempotency result metadata
internal integrity inconsistency
BlitzTask.status = active
start_normal
resume
start_replacement
attempt_id
client_key
checking_mode
YYYY-MM-DDTHH:MM:SSZ
remaining_seconds
resource_not_found
blitz_not_active
task_closed
task_archived
blitz_time_expired
attempt_not_editable
attempts_exhausted
blitz_attempt_exception_not_allowed
blitz_attempt_exception_already_granted
blitz_normal_attempt_required
```

## 33.2 Search for stale contradictory wording

Search for wording equivalent to:

```text
Stage 8 timeout immediately checks objective answers
Stage 8 timeout immediately awards points
Stage 8 close immediately awards points
Stage 8 moves manual answers to checking/review state
timed_out_finalized means fully checked/scored
unanswered zero requires a fabricated answer row
device clock controls Blitz eligibility
Teacher may override timer-start mode
Student Start body is empty or `{}` for Blitz
Student Start is implicit create-or-resume without explicit intent
Student Resume may switch to another current/newer Attempt
Student Resume may create replacement #2
start_normal may create another normal Attempt after terminal #1
replacement capacity reinterprets start_normal as start_replacement
due in-progress Start/Resume target returns a stale editable Attempt
terminal exact Resume target returns a code other than 409 attempt_not_editable
foreign Resume target exposes existence instead of 404 resource_not_found
terminal normal capacity or consumed terminal #2 uses a code other than 409 attempts_exhausted
missing approved replacement capacity in structurally valid history uses a code other than 409 attempts_exhausted
invalid replacement exception graph/capacity uses an alternative public error instead of blitz_attempt_exception_not_allowed
attempts_exhausted is used only if the current convention says so
otherwise preserve some Blitz-specific error for exhausted capacity
completed Start replay changes its original successful 201/200 semantic status
start_replacement may create Attempt #3
old Start/Resume key may be reinterpreted as start_replacement
Student resume restarts the timer
Create Blitz nested Question may omit client_key
Create Blitz nested Question may omit checking_mode
Blitz Submit new terminal request returns submission_locked
Blitz Submit may use an Assessment-type-independent final-submit operation
Blitz and Homework Submit may share or merge operation identities
student.blitz.attempt.submit is optional or replaceable by an implementation convention
Stage 8 execution timer wire timestamps may contain fractional seconds
remaining_seconds is computed from hidden fractional/device-local time
exception resets the synchronized class timer
exception increases normal attempt count
task state permits exception according to the live lifecycle contract without exact active-only status
new exception grant may succeed for draft/scheduled/closed/archived Blitz
Teacher Close may be reversed by a new exception grant
elapsed synchronized_ends_at alone prevents an otherwise valid active exception grant
completed same-key activation replay requires current status active only
closed/archived historical activation replay must fail
new activation key may reopen closed/archived Blitz
completed activation replay may succeed while current Blitz is draft/scheduled
fresh/new-key active activation restarts timers or resnapshots recipients/cohort
failed fresh closed/archived activation retains a successful idempotency result
locked result pair can never fill its previously-null Blitz side
official Blitz resnapshots later Group membership
selected-Student Blitz can become official
official Blitz requires a pre-existing result-pair row
Blitz-only attachment/replacement rewrites designated_at or designated_by_user_id
activated Blitz response uses timer_start_mode instead of timer_start_mode_snapshot
a later implementation contract may decide whether a live pre-deadline #1 can be invalidated for exception grant
```

No stale contradictory statement may remain.

## 33.3 Preservation review

Inspect every changed paragraph that mentions:

- Homework;
- Stage 7;
- Stage 9;
- Topic result;
- final score;

and confirm:

- Stage 7 delivered Homework semantics are unchanged;
- Stage 9 remains checking/scoring owner;
- Stage 10 remains final Topic-result owner;
- this task did not accidentally move later-stage work into Stage 8.

Do not run:

- backend tests;
- frontend tests;
- builds;
- broad E2E;
- migrations;
- database commands.

---

# 34. Focused Diff Self-Check

Before reporting completion, Codex must confirm:

```text
documentation only
no production code
no migration
no test
no dependency
no task/index rewrite
no Stage 7 behavior regression
no Stage 9 implementation
no Stage 10 implementation
final three-intent Start API fully represented
exact Start/Resume/replacement result matrix and completed-replay 201/200 precedence represented
active-only exception grant and permanent Teacher Close boundary represented
activation completed replay vs fresh-request lifecycle matrix represented
exact student.blitz.attempt.submit operation with separate unchanged Homework identity represented
final Blitz Submit terminal error matrix fully represented
Create Blitz nested Question client_key/checking_mode represented
whole-second timer convention represented
no unrelated formatting rewrite
```

The diff should be surgical.

Do not reformat entire documents.

Do not change headings/numbering unnecessarily.

Do not rewrite stable unrelated prose for style.

---

# 35. Delivery Checklist

Codex reports:

1. exact changed docs;
2. concise Stage 8/Stage 9 alignment summary;
3. exact timeout/close lifecycle semantics now documented;
4. exact official pair/cohort alignment now documented;
5. timer-mode snapshot alignment;
6. exception/Attempt alignment;
7. required high-risk idempotency alignment;
8. confirmation Stage 7 Homework semantics remain unchanged;
9. confirmation no source/migration/test/frontend/harness changes;
10. `git diff --check`;
11. focused stale-wording search result;
12. final `git status --short`;
13. focused diff self-check.

After delivery, ChatGPT performs read-only acceptance review.

`S08-BE-001` remains blocked until:

```text
S08-DOC-001 = Accepted / Delivered
```

---

# 36. Implementation Readiness Verdict

```text
Scope / non-goals                  = RESOLVED
Stage 8 / Stage 9 ownership        = RESOLVED
Blitz lifecycle                    = RESOLVED
Official pair semantics            = RESOLVED
Official cohort semantics          = RESOLVED
Timer modes                        = RESOLVED
Authoritative deadlines            = RESOLVED
Attempt lifecycle                  = RESOLVED
Timeout / close precedence         = RESOLVED
Answer/file freeze boundary        = RESOLVED
Student exception                  = RESOLVED
Active-only exception grants       = RESOLVED
Activation fresh/replay lifecycle  = RESOLVED
Start/Resume/replacement matrix    = RESOLVED
Exact Blitz Submit operation       = RESOLVED
High-risk idempotency              = RESOLVED
Tenant/security boundary           = RESOLVED
Acceptance criteria                = RESOLVED
Verification scope                 = RESOLVED

Implementation Readiness Gate      = PASS
```
