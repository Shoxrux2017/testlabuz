# Phase 2 Read-Only Block Review — Stage 7 Backend

## 1. Review Metadata

| Field | Value |
|---|---|
| Review ID | `S07-BE-PHASE-2` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Block | `Backend` |
| Review mode | `Read-only` |
| Status | `Pending current-main ChatGPT revalidation before execution` |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Current contract review baseline | `origin/main @ ad40fc2bbca1efd348b8da25651bc3d6e5e9d8f7` |
| Audited `origin/main` | `Resolve/freeze at actual checkpoint execution` |
| Backend task delivery | `S07-BE-001…007 — Accepted / Delivered` |
| Backend block diff base | `First parent of S07-BE-001 production merge 86067f9a61864a4d313b7ec8b59ee1217218b612` |
| Review owner | `ChatGPT` |
| Verification executor | `Project Owner / approved CI` |
| Codex role | `None during read-only review; focused fixes only if ChatGPT later issues a fix contract` |
| Verdict | `Pending` |
| Findings | `Pending` |
| Next permitted implementation gate after PASS | `S07-FE-001 — Student Homework Read Foundation` |

This file defines the Stage 7 Backend Phase 2 checkpoint.

It is **not** an implementation task.

Do not give this review to Codex merely to run the full suite or collect evidence.

---

# 2. Entry Gate

Run this checkpoint only when all conditions below are true.

S07-BE-001…007 are now `Accepted / Delivered`. This delivery state does not
constitute checkpoint execution or PASS; ChatGPT must still revalidate current
main before execution and resolve/freeze the actual audited revision.

| Condition | Required |
|---|---|
| `S07-DOC-001` accepted/delivered | Yes |
| `S07-BE-001` accepted/delivered | Yes |
| `S07-BE-002` accepted/delivered | Yes |
| `S07-BE-003` accepted/delivered | Yes |
| `S07-BE-004` accepted/delivered | Yes |
| `S07-BE-005` accepted/delivered | Yes |
| `S07-BE-006` accepted/delivered | Yes |
| `S07-BE-007` accepted/delivered | Yes |
| All accepted backend results are on `origin/main` | Yes |
| Local `main == origin/main` | Yes |
| Ahead/behind | `0/0` |
| Working tree | Clean |
| No unresolved task blocker | Yes |

At checkpoint execution, record in the ChatGPT final Phase 2 review report:

```text
origin/main = <sha>
local main = <sha>
ahead/behind = 0/0
working tree = clean
```

If any required entry condition fails:

```text
Verdict: NOT ACCEPTED
```

or stop as an entry blocker before substantive review.

Do not compensate for missing delivery by reviewing task branches as though they were accepted `main`.

---

# 3. Read-Only Rule

During this review:

- do not edit production code;
- do not edit tests;
- do not edit migrations;
- do not edit task contracts;
- do not “quick-fix” a finding;
- do not stage;
- do not commit;
- do not push;
- do not create or update a PR;
- do not merge.

ChatGPT identifies and classifies findings.

All instructions to populate evidence or replace `Pending` fields apply to the
**ChatGPT final Phase 2 review report**, not to editing this contract during the
checkpoint. Production, tests, migrations, and contracts remain unchanged.

If findings block PASS under Section 32, Phase 2 returns `NOT ACCEPTED` and
ChatGPT creates a separate focused fix task:

1. record `NOT ACCEPTED`;
2. preserve the review evidence;
3. create a compact focused fix contract;
4. Codex implements only that fix;
5. Project Owner delivers it;
6. ChatGPT decides which checkpoint evidence was invalidated;
7. rerun only required invalidated evidence plus every previously failing required command;
8. issue a new final Phase 2 verdict.

---

# 4. Authoritative Review Inputs

At checkpoint execution ChatGPT must re-read from current GitHub `main`:

```text
AGENTS.md
backend/AGENTS.md
tasks/README.md
tasks/STAGE_07_TASK_INDEX.md
```

and the relevant locked Stage 7 product/technical inputs:

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

Review the delivered Stage 7 contracts:

```text
S07-DOC-001
S07-BE-001
S07-BE-002
S07-BE-003
S07-BE-004
S07-BE-005
S07-BE-006
S07-BE-007
```

Review current implementation/tests, not only task completion reports.

GitHub `main` is the source of truth.

---

# 5. Audited Backend Task Inventory

Fill from actual delivery evidence in the ChatGPT final Phase 2 review report.
The `Pending` results below are checkpoint review results, not the already
completed task acceptance/delivery statuses. Do not edit this contract to fill them.

| Task | Required integrated outcome | Delivery evidence | Result |
|---|---|---|---|
| `S07-BE-001` | normalized Student answer persistence + durable idempotency + one-in-progress constraint | `<PR/SHA>` | `Pending` |
| `S07-BE-002` | deadline finalization engine + Teacher close auto-finalization + Scheduler | `<PR/SHA>` | `Pending` |
| `S07-BE-003` | Student Homework list/detail + safe Question projection + read reconciliation | `<PR/SHA>` | `Pending` |
| `S07-BE-004` | idempotent Attempt start/resume + own Attempt read + first official pair lock | `<PR/SHA>` | `Pending` |
| `S07-BE-005` | eight typed non-file answer save/replace + resume answer state | `<PR/SHA>` | `Pending` |
| `S07-BE-006` | private file-based answer upload/replace/download | `<PR/SHA>` | `Pending` |
| `S07-BE-007` | idempotent explicit final Submit | `<PR/SHA>` | `Pending` |

Confirm:

- every delivered backend task is represented;
- no hidden backend Stage 7 implementation bypassed an approved task;
- later tasks did not silently change earlier contracts;
- no Stage 8/9 behavior entered Stage 7.

---

# 6. Stage 7 Backend Scope Boundary

The integrated backend block must implement:

```text
Student Homework read
Attempt start/resume
Attempt read
eight non-file typed answer mutations
file-based answer upload/replace
own Student submission download
explicit Student Submit
deadline auto-finalization
Teacher-close auto-finalization
durable Start/Submit idempotency
first official Homework Attempt result-pair lock
```

The integrated backend block must **not** implement:

```text
automatic answer checking
manual Teacher review
awarded points
Attempt normalized scoring
official Homework score selection/reselection
Student score release
Parent score visibility
Blitz execution
final Topic result
Stage 8/9/10 APIs
frontend behavior
```

Any material scoring/review/result behavior entering Stage 7 is a blocking scope defect.

---

# 7. Architecture Review

Review complete Stage 7 backend as one system, not seven isolated tasks.

## 7.1 HTTP boundaries

Verify:

- Student controllers are thin;
- Form Requests own shape/transport validation;
- Actions own lifecycle/transaction behavior;
- Resources serialize preloaded state only;
- Resources issue no hidden queries;
- no Controller contains tenant, locking, idempotency, deadline or storage workflow logic.

## 7.2 Shared domain/infrastructure boundaries

Verify the integrated ownership is coherent:

```text
HomeworkAttemptFinalizer
  = exact Attempt transition fields

FinalizeHomeworkAttemptsAtDeadline
  = authoritative per-Homework deadline reconciliation

StudentHomeworkAccess
  = Student Homework assignment/read scope

StudentHomeworkAttemptAccess
  = own Attempt + lock infrastructure

IdempotencyGuard
  = operation-agnostic durable claim/replay/completion

StudentQuestionAnswerUi
  = Student-safe Question projection

PrivateFileStorage
  = private physical storage primitive
```

Flag duplicated authoritative rules.

Examples of blocking duplication:

- separate deadline comparison logic that disagrees across Start/Save/Submit;
- separate idempotency implementations for Start and Submit;
- Student-safe Question keys removed only after Teacher serialization;
- independent Student file signature parser duplicating existing inspector.

## 7.3 No God service

Review whether any Stage 7 Action/support class accumulated:

- authorization;
- transport validation;
- storage;
- serialization;
- scoring;
- unrelated result logic

in one broad object.

Material responsibility collapse is at least `P2`.

---

# 8. Database / Persistence Review

Review delivered S07-BE-001 migration and resulting PostgreSQL schema.

## 8.1 Tenant-safe keys

Verify required composite tenant reference support exists for:

```text
question_choice_options
question_matching_items
question_ordering_items
attempt_answers
answer_* tables
idempotency_records
```

and FK shapes cannot cross Institutions.

## 8.2 One in-progress Attempt

Verify PostgreSQL partial unique invariant:

```text
unique (assessment_id, student_id)
where status = 'in_progress'
```

exists and composes correctly with application locks.

## 8.3 Typed answer normalization

Verify one canonical storage path per Question type:

```text
single_choice / multiple_choice -> answer_choice_selections
true_false                     -> answer_boolean_values
short/open written             -> answer_text_values
matching                       -> answer_matching_pairs
ordering                       -> answer_ordering_items
fill_in_blank                  -> answer_fill_blank_values
file_based                     -> answer_files -> files
```

No generic answer JSON fallback.

## 8.4 AttemptAnswer invariant

For Stage 7 Student-saved answers verify:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

No automatic scoring side effect.

## 8.5 Idempotency records

Verify:

```text
unique(institution_id,user_id,operation,idempotency_key)
SHA-256 request fingerprint
completed resource metadata
no global-key lookup
no TTL cleanup changing replay correctness
```

No committed incomplete records under normal success/failure paths.

## 8.6 File graph

Verify one file-based answer resolves to:

```text
AttemptAnswer
-> AnswerFile
-> File(category=student_submission)
```

with one file per answer and tenant-consistent FKs.

---

# 9. API Contract Review

Verify exact public Stage 7 Student endpoints:

```text
GET  /api/v1/student/homework
GET  /api/v1/student/homework/{homework}
POST /api/v1/student/homework/{homework}/attempts
GET  /api/v1/student/attempts/{attempt}
PUT  /api/v1/student/attempts/{attempt}/answers/{question}
POST /api/v1/student/attempts/{attempt}/submit
GET  /api/v1/files/{file}/download
```

Check:

- middleware exactly preserves auth/active/password/Student gates;
- no accidental public route;
- no duplicate route;
- strict query/body rules;
- exact response envelopes;
- UTC timestamps;
- stable machine error codes;
- no Teacher-only fields in Student resources;
- no score/checking surface in Stage 7 final Submit response.

---

# 10. Student Assignment / Tenant Isolation Review

The persisted:

```text
assessment_students
```

snapshot must be authoritative for Student Homework execution.

Verify all Stage 7 Student paths consistently avoid replacing it with:

```text
current group_student_memberships
```

for assignment/history.

Current Group membership removal after activation must not erase:

- Homework visibility;
- own Attempt access;
- answer editability while lifecycle allows;
- own historical Student submission download.

Review all direct identifier paths:

```text
homework UUID
attempt UUID
question UUID
option/item/blank UUID
file UUID
idempotency key
```

Confirm a syntactically valid identifier never widens scope.

Cross-Institution access must be impossible at query level.

---

# 11. Student Question Privacy Review

Recursively verify Student Homework/Attempt responses never expose:

```text
is_correct
correct_value
accepted_answers
correct_position
match_key
checking_mode
Teacher configuration object
```

Review indirect leakage too.

## Multiple Choice

Allowed:

```text
max_selections
```

Not allowed:

```text
which options are correct
```

## Matching

Verify response order does not encode correct pairs.

## Ordering

Verify response order does not encode correct order.

## Fill Blank

Placeholder identity may be exposed.

Accepted answers must not.

## Answer state

Student's own submitted values are visible.

Teacher correct-answer/checking/scoring fields are not.

Any answer-key leak is `P1`.

---

# 12. Attempt Lifecycle Review

Validate integrated transition graph.

## 12.1 Start

```text
no current in_progress + capacity => new in_progress
existing in_progress             => resume same Attempt
```

Max normal Homework Attempt number:

```text
3
```

No Attempt #4.

## 12.2 Explicit Submit

```text
in_progress
-> submitted

submitted_at = submittedAt
finalized_at = submittedAt
locked_at = submittedAt
reason = student_submit
```

## 12.3 Deadline

```text
in_progress
-> submitted

submitted_at = null
finalized_at = deadline_at
locked_at = deadline_at
reason = homework_deadline_auto_submit
```

## 12.4 Teacher close before deadline

```text
in_progress
-> submitted

submitted_at = null
finalized_at = close instant
locked_at = close instant
reason = task_closed_auto_finalize
```

## 12.5 Explicit Submit structural integrity

Verify safe locked exact-Attempt re-resolution retains the previously authorized
target and trusted Institution/Student scope. The complete locked Homework
Attempt invariant also requires identity/Assessment/recipient consistency:

```text
attempt.id = preliminary authorized Attempt
attempt.institution_id = authenticated Student Institution
attempt.student_id = authenticated Student
attempt.assessment_id = locked Homework Assessment
attempt.assessment_student_id = authoritative persisted AssessmentStudent

attempt.deadline_at = null

allowed Homework statuses only:
- in_progress
- submitted
- waiting_for_teacher_review
- checked

finalization_reason != timeout_auto_submit

in_progress requires:
submitted_at = null
finalized_at = null
locked_at = null
finalization_reason = null
```

For a new logical Submit, apply the complete invariant only after this
precedence, without replacing safe exact-target locking with a status-only check:

```text
Homework lifecycle
-> active Topic consistency
-> deadline
-> full Attempt structural invariant
-> editability
```

Review outcomes at the structural/editability gate:

```text
structurally valid in_progress
=> may proceed to the saved-answer integrity gate

structurally valid terminal
=> new-key 409 attempt_not_editable

structural corruption
=> safe server invariant / 500 server_error
```

Blitz-only `timed_out_finalized` / `timeout_auto_submit`, non-null Attempt
deadline, invalid identity/recipient relationships, and corrupt `in_progress`
finalization fields must not be reduced to ordinary non-editability. A new
Submit rejected by this invariant leaves no Submit mutation or new
completed/incomplete idempotency record.

Completed same-key replay bypasses current lifecycle/deadline, but still
validates the complete locked Homework Attempt invariant before returning
action success. Historical completed idempotency metadata remains unchanged.

The Student finalizer must preserve the delivered BE-002 structural semantics:
terminal status returns false; corrupt `in_progress` state fails safely.

## 12.6 Forbidden Stage 7 Homework terminal use

Verify automatic Homework paths do not use:

```text
timed_out_finalized
timeout_auto_submit
waiting_for_teacher_review
checked
```

Later Attempt terminal status progression is only a replay compatibility case
with valid Stage-7 pending Answers (Sections 17 and 25); Stage 7 does not produce
Teacher-review or checked states.

## 12.7 Pre-finalization saved-answer integrity

For every new valid in-progress Submit, verify this delivered order while the
own Attempt mutation barrier is held:

```text
own Attempt FOR UPDATE
-> lifecycle/deadline
-> full Attempt invariant
-> StudentHomeworkAttemptAnswerStates
-> StudentHomeworkAnswerIntegrity
-> finalizeByStudentSubmit
-> idempotency complete
-> commit
```

The shared saved-answer gate must:

- reuse the delivered read-only path also used by Student Attempt projection;
- read current Assessment Questions in deterministic position/ID order;
- validate both non-file and file-based persisted Answers, including the File graph;
- require `checking_status = pending` and null `awarded_points`, `feedback`,
  `checked_by_user_id`, and `checked_at`;
- require no completeness: full, partial, and zero saved-answer sets are allowed;
- create no missing Answers and perform no Answer/File mutation, repair, scoring,
  or checking;
- acquire no Question row lock or Answer/File `FOR UPDATE`;
- retain own Attempt `FOR UPDATE` as the answer/file mutation barrier.

Response projection must not be the first discovery of pre-existing saved-state
corruption after finalization and idempotency completion have already committed.
Corrupt saved Answer/File state before a new Submit must produce:

```text
safe 500 server_error
Attempt remains in_progress
no completed/incomplete Submit idempotency record
no Answer/File mutation
```

Require evidence for this fixed-key sequence separately for non-file and
file-based corruption, using the same key throughout:

```text
500
-> retry same key 500
-> fixture repair
-> 200 student_submit / one completed record
-> replay 200 / no timestamp churn
```

Compare Attempt fields, Answer/File rows and file contents around every request;
only the explicit test-fixture repair may change the saved fixture. Verify the
completed record identity, result metadata, and timestamps remain stable on replay.

If corruption arises after a historical successful Submit, later Student-safe
projection may return safe `500 server_error`. That failure must never delete or
rewrite the historical completed Submit record or its timestamps, re-finalize the
Attempt, or mutate Answers/Files.

---

# 13. Deadline Authority Review

Verify Homework deadline authority is only:

```text
homework_assignments.deadline_at
```

and:

```text
assessment_attempts.deadline_at = null
```

for Homework.

Boundary everywhere must be:

```text
server observed instant >= deadline
=> deadline passed
```

Review:

- Student Homework read reconciliation;
- Start;
- non-file answer save;
- file replacement;
- Submit;
- Teacher close;
- Scheduler.

Scheduler latency must never permit a post-deadline Student mutation.

No client/device clock authority.

---

# 14. Deadline / Close / Submit Exact-Once Review

This is a blocking Stage 7 risk surface.

Verify all competing operations make decisions from locked current state.

For a new Submit, verify Homework lifecycle precedes active Topic consistency,
then deadline, then the full Attempt invariant and editability (Section 12.5).
The lock helper retains the safe exact target; it must not apply the complete
structural validator before the lifecycle/deadline gates.

Required negative precedence evidence includes:

```text
closed Homework + structurally invalid otherwise-resolved Attempt
=> 409 task_closed; no Submit record; no Submit mutation

active due Homework + structurally invalid terminal Homework Attempt
=> 409 deadline_passed; no Submit record; no student_submit mutation
```

Late Submit abandons its new claim and releases its local transaction before
public BE-002 reconciliation. That reconciliation may finalize due in-progress
Attempts but must not rewrite an already terminal Attempt. Completed same-key
replay bypasses current lifecycle/deadline while retaining full locked-invariant
validation and historical idempotency metadata.

Required outcomes:

## Submit before deadline wins

Later deadline/close preserves:

```text
student_submit
```

## Deadline reached before/equal Submit decision

Deadline wins:

```text
homework_deadline_auto_submit
```

and Submit cannot overwrite it.

## Teacher close before deadline wins

Attempt reason:

```text
task_closed_auto_finalize
```

and later Student Submit cannot overwrite it.

## Teacher close after deadline before Scheduler

Deadline semantics still win for in-progress Attempts.

No operation may rewrite terminal finalization reason/time.

---

# 15. Read-Path Reconciliation Review

Verify:

```text
Student Homework list
Student Homework detail
Attempt read
```

cannot return stale editable/in-progress state merely because Scheduler has not run.

Read reconciliation must:

- authorize before mutating an inaccessible specific target;
- use tenant-safe candidates;
- call the same deadline engine;
- fabricate no Attempts.

Confirm an unauthorized direct read cannot be used as a side-effect trigger against another Student/Institution Homework.

---

# 16. Start / Official Result-Pair Review

For the first global Attempt on the official Homework verify in one transaction:

```text
lock Topic/Assessment/Homework
lock topic_result_pairs
require cohort_snapshotted_at != null
require official group-assignment semantics
require Student in persisted official cohort
set pair.locked_at = Attempt.started_at if null
persist pair lock before Attempt insert
insert Attempt
```

Verify rollback cannot leave:

```text
locked pair + missing first Attempt
```

Subsequent valid Attempts preserve the original pair lock timestamp.

Practice Homework must not mutate result pair.

Student execution must never rewrite:

```text
homework_assessment_id
blitz_assessment_id
cohort_snapshotted_at
designated_at
designated_by_user_id
```

---

# 17. Idempotency Review

Review both operations:

```text
student.homework.attempt.start
student.homework.attempt.submit
```

## 17.1 Scope

Exact scope:

```text
institution
user
operation
key
```

## 17.2 Start

Same key/same semantic request:

- same logical Attempt;
- original semantic status preserved (`201` or `200`).

Different keys on concurrent Start:

```text
one create
one resume
same Attempt
```

## 17.3 Submit

Same key/same Attempt:

```text
complete locked Homework Attempt invariant
-> 200 replay when the current Student-safe representation can be produced
```

For a new logical Submit, verify the delivered order after preliminary
authorization and shared Topic/Assessment/Homework + exact Attempt locks:

```text
completed idempotency replay check
-> new claim
-> submittedAt captured after lock/idempotency waits
-> Homework lifecycle
-> active Topic consistency
-> deadline
-> full Attempt structural invariant
-> terminal editability
-> shared saved-answer integrity gate
-> student_submit finalization
-> idempotency completion
-> commit
```

Only a structurally valid terminal Attempt on an otherwise active/pre-deadline
new-key path maps to `409 attempt_not_editable`. Structural corruption at its
required validation point is safe `500 server_error`, never a status-only
non-editability shortcut. Rejected new claims leave no completed/incomplete
Submit record; a historical completed record is never discarded for a later failure.

## 17.4 Replay after later lifecycle

A previously completed same-key request may replay after:

- deadline;
- close/archive;
- later Attempt terminal status progression while saved Answers remain valid
  Stage-7 pending state.

BE-007 guarantees durable Submit/idempotency replay semantics. Authorization to
the target and the complete locked Homework Attempt invariant remain required;
completed same-key replay bypasses current lifecycle/deadline, editability, and
the new-Submit saved-answer gate.

HTTP replay still requires a producible current Student-safe representation.
Later persisted corruption may cause safe `500 server_error` during projection,
but never deletion/rewriting of historical completed metadata or timestamps.

Genuine Stage-9 checked-answer Student projection is not implemented by Stage 7.
BE-007 does not prove endpoint replay with checked/scored Answers. Stage 9 must
extend `StudentHomeworkAnswerIntegrity` / Student-safe projection for legitimate
checked/scored states while preserving historical completed BE-007 idempotency
records and replay semantics. Phase 2 must reject premature relaxation of the
Stage-7 pending-only Answer integrity boundary.

## 17.5 Atomicity

Verify no successful protected operation can commit domain state without completed idempotency metadata in the same transaction.

For Submit, the shared persisted-answer integrity gate must succeed before
finalization and idempotency completion. Require both fixed-key corruption
rollback/recovery regressions and historical-record preservation evidence from
Section 12.7.

Any reliable duplicate domain mutation from an idempotency race is `P1/P2` depending impact.

---

# 18. Typed Answer Review

Review all eight non-file types.

## Single Choice

Exactly one selected valid Question option.

## Multiple Choice

- empty clears;
- max count = number of correct options;
- no correct-option identity leak;
- `selection_limit_exceeded` exact behavior.

## True/False

Real JSON boolean only.

## Short/Open Written

Exact Student text preserved.

Verify the delivered BE-005 raw-JSON boundary:

```text
raw application/json object = authoritative Student answer payload
JSON "" remains an empty String and performs contracted clear behavior
non-empty leading/trailing whitespace is preserved exactly
semantic-empty detection uses the contracted Unicode-whitespace helper only
middleware-normalized request input is not authoritative for stored text
```

Scoring normalization not run in Stage 7.

## Matching

- partial allowed;
- left/right side validation;
- no `match_key` use for saving.

## Ordering

- partial allowed;
- 1-based submitted position;
- no correct-position comparison.

## Fill Blank

- partial allowed;
- exact text preserved;
- no accepted-answer comparison.

## No-op

Semantically identical replacements must be write-free where contracted.

---

# 19. File Submission Review

Review shared private storage and Student-specific behavior.

## Upload

Verify:

```text
PDF/DOCX/PPT/PPTX
existing binary inspector
client MIME untrusted
filename extension must match detected format
server-generated storage key
private configured disk
```

## Effective size

```text
min(15 MB platform, Institution student_submission_max_mb)
```

Verify:

- server-observed oversized upload is rejected before expensive binary inspection;
- inspected size agrees with server-observed upload size;
- final effective limit is rechecked under a **shared/read** InstitutionSetting lock;
- Student uploads are not serialized by an exclusive InstitutionSetting lock.

## Replacement

Must preserve:

```text
AttemptAnswer ID
AnswerFile ID
File ID
```

and update same File row.

## Compensation

Verify:

- new blob cleanup on rollback/rejection;
- old blob cleanup only after DB commit;
- cleanup failure cannot corrupt DB reference;
- no path/content leakage in logs/errors.

## Download

Stage 7 permits only the Student owner to download their linked Student submission.

Verify the complete ownership invariant includes:

```text
File.category = student_submission
File.uploaded_by_user_id = authenticated Student
Attempt/AssessmentStudent chain = authenticated Student
```

A linked File whose uploader differs from the Attempt owner must remain
privacy-safe `404`.

Verify protected Student-submission download acquires a **shared/read File lock**
before opening the stream:

```text
download + download    = may coexist
download + replacement = serialize against replacement File FOR UPDATE
```

The download path must not acquire a parent Homework/Attempt lock after the File
lock.

Teacher review/download remains Stage 9.

Historical own file survives Attempt finalization/current Group membership loss.

The original filename limit is 500 Unicode code points, not 500 UTF-8 bytes.

---

# 20. Concurrency / Lock Ordering Review

Build an explicit lock-order map from current implementation.

Minimum surfaces:

```text
Teacher Question mutation
Teacher Homework close
deadline Scheduler/reconciliation
Student Start
Student answer save
Student file replace
Student Submit
protected file download/replacement
```

Verify no reverse lock chain creates a realistic deadlock cycle.

Required principles:

```text
tenant scope before lock
fresh state under lock
deterministic Attempt ordering where an operation genuinely locks multiple Attempts
Student never acquires Group after Topic

BE-005 non-file answer:
  Topic/Assessment/Homework/Question = shared/read
  own Attempt = FOR UPDATE
  existing AttemptAnswer = FOR UPDATE

BE-006 file answer:
  Topic/Assessment/Homework/Question/InstitutionSetting = shared/read
  own Attempt + existing Answer/File graph = FOR UPDATE

BE-007 explicit Submit:
  Topic/Assessment/Homework = shared/read
  own route Attempt = FOR UPDATE
  saved-answer integrity gate = read-only; no Question/Answer/File row locks
  no ordinary class-wide/all-Attempt lock

deadline reconciliation / Teacher close:
  authoritative conflicting aggregate/finalization locks

late Submit:
  abandon claim + release local Submit transaction
  -> public BE-002 deadline reconciliation

protected Student-submission download:
  File = shared/read before stream opening
  no later parent lock acquisition
```

Verify no corrected Student mutation path falls back to coarse exclusive shared
aggregate locks merely for convenience.

Also verify the intended non-blocking behavior:

```text
different Students + different Attempts + same Homework
=> ordinary answer/file/Submit operations must not serialize solely because the
   aggregate/Question/InstitutionSetting is shared
```

Review actual SQL/test behavior, not only intended comments.

---

# 20A. Corrected Task-Contract Invariant Review

These checks reflect the hardened current contracts and must not regress back to
the original planning-package wording.

## BE-005

Verify:

```text
raw JSON = authoritative answer payload
empty JSON String remains String
exact non-empty Student whitespace preserved
explicit Unicode-whitespace semantic-empty helper
shared parent/Question locks
own Attempt FOR UPDATE
```

## BE-006

Verify:

```text
early size gate before binary inspection
filename max = 500 Unicode code points
shared InstitutionSetting upload lock
different Students/different Attempts may upload concurrently
File uploader must match Student owner
download File lock = shared/read
replacement File lock = FOR UPDATE
```

## BE-007

Verify:

```text
shared Topic/Assessment/Homework locks
own route Attempt FOR UPDATE
lock helper = safe exact-target re-resolution, not the full structural validator
no ordinary all-Attempt Submit lock
late Submit releases local transaction before public BE-002 reconciliation
new Submit: Homework lifecycle -> active Topic consistency -> deadline
  -> full Attempt invariant -> editability
full invariant = identity/recipient/tenant consistency + null Attempt deadline
  + allowed Homework statuses + no timeout_auto_submit
  + all in_progress finalization fields null
valid in_progress -> shared saved-answer integrity gate -> finalize -> complete -> commit
valid terminal on active/pre-deadline new key -> 409 attempt_not_editable
structural corruption at invariant gate -> safe 500 server_error
completed same-key replay bypasses lifecycle/deadline but validates full locked invariant
StudentHomeworkAttemptAnswerStates -> StudentHomeworkAnswerIntegrity = read-only
Questions ordered by position/ID; pending-only Answer state; no completeness/scoring
no Answer/File FOR UPDATE; own Attempt lock remains the mutation barrier
corrupt saved state -> 500 + in_progress + no new Submit record + no Answer/File mutation
non-file and file fixed-key recovery/replay evidence required
later projection failure never deletes/rewrites historical completed Submit metadata
```

Verify the complete requirements and fixed-key evidence in Sections 12.5–12.7,
14, and 17, including the Stage-7 pending-only / Stage-9 projection boundary.
Superseded coarse locking, status-only validation, validation before required
lifecycle/deadline precedence, or integrity checking only after commit is a
checkpoint finding.

---

# 21. Scheduler Review

Verify Stage 7 scheduled command:

```text
homework:reconcile-deadlines
```

runs:

```text
everyMinute
withoutOverlapping(5)
```

Candidate scan:

```text
active
deadline <= scanNow
has in_progress Attempts
```

must use keyset iteration, not offset over shrinking results.

Per-candidate action must re-check authoritative locked state.

One candidate failure must not prevent later candidates.

Correctness must not depend on `withoutOverlapping` or a single application node.

---

# 22. Error Contract Review

Verify consistent existing envelope:

```text
message
code
errors
```

Review Stage 7 codes:

```text
resource_not_found
validation_failed
task_not_active
task_closed
task_archived
deadline_passed
assessment_not_assigned
attempts_exhausted
attempt_not_editable
selection_limit_exceeded
idempotency_key_reused
business_conflict
unsupported_file_type
file_too_large
file_upload_failed
file_not_available
server_error
```

Structural or persisted-state corruption at its required validation point is
intentionally surfaced as a safe server invariant / `500 server_error`. Verify
the expected error envelope without weakening the invariant or replacing the
defined lifecycle/deadline precedence. Failed new Submit integrity checks roll
back the new claim; later projection failure preserves historical completed
Submit metadata (Sections 12, 14, and 17).

No raw:

- `LogicException` details;
- SQL;
- filesystem path;
- stack trace;
- class name;
- internal idempotency/resource metadata;
- answer key;
- foreign resource existence.

---

# 23. Query / Performance Review

Review for obvious N+1 or unbounded reads.

## Student Homework list

Must not query Topic/Attempts per row.

## Homework detail / Attempt read

Question typed configuration must load in fixed query families rather than per Question.

## Deadline reconciliation

Candidate discovery must be bounded/keyset.

## Start

At most bounded 3 Student normal Attempts for practice path.

Official path may lock all Homework Attempts because pair/fairness correctness requires global activity knowledge; confirm query is tenant/Assessment bounded.

## Submit

Ordinary explicit Submit must **not** lock all Assessment Attempts.

Verify the normal path is bounded to:

```text
shared Topic/Assessment/Homework
+ exact authenticated Student Attempt FOR UPDATE
```

Late deadline reconciliation belongs to the public BE-002 action after the local
Submit transaction releases its locks.

Any class-wide/all-Attempt lock in ordinary Submit is a material scalability/
concurrency regression.

## Resources

No hidden lazy queries.

Any material linear query growth introduced across ordinary list/detail serialization is at least `P2`.

---

# 24. Previous-Stage Regression Review

Review shared Stage 1–6 surfaces affected by Stage 7.

Minimum:

## Authentication/middleware

Existing Student/Teacher auth behavior unchanged.

## Stage 4 group history

Removing current Student membership must preserve historical assignment/Attempt semantics.

## Stage 5 protected learning material download

The new protected-file dispatcher must not change learning-material authorization or response headers.

## Stage 6 Teacher Homework

Preserve:

- authoring;
- typed Question mutation lock after first Attempt;
- activation recipient snapshot;
- official designation;
- result-pair behavior;
- archive/history;
- Topic lifecycle interaction.

Only the explicitly planned Stage 6 close guard is replaced by Stage 7 auto-finalization.

---

# 25. Stage 8 / Stage 9 Compatibility Review

## Stage 8

Confirm Stage 7 does not misuse Homework `timed_out_finalized`.

`assessment_attempts.deadline_at` remains available for Blitz semantics.

Stage 8 must still be able to fill the null Blitz side of an already locked official pair according to its later contract.

## Stage 9

Confirm Stage 7 leaves sufficient immutable evidence:

```text
answers persisted
Attempt status submitted
finalization reason
submitted/finalized/locked timestamps
possible_points snapshot
checking_status pending
```

and does not preempt Stage 9 by:

- awarding points;
- selecting official Attempt;
- converting to `checked`;
- entering Teacher review.

BE-007 guarantees durable Submit/idempotency replay semantics. Later Attempt
terminal status progression may replay only while saved Answers remain valid
Stage-7 pending state. This is not proof of genuine endpoint replay after
Stage-9 checked/scored Answers.

Genuine Stage-9 checked-answer Student projection is not implemented by Stage 7.
Stage 9 must extend `StudentHomeworkAnswerIntegrity` / Student-safe projection
for legitimate checked/scored states while preserving the historical completed
BE-007 idempotency record and replay semantics.

Verify Stage 7 has not prematurely relaxed `checking_status = pending` or the
null awarded/checking fields. Later projection failures must not delete/rewrite
completed Submit records. Require both pending-only boundary and durable-history
evidence; do not demand Stage-9 implementation as a Stage-7 checkpoint condition.

---

# 26. Stage 7 Backend Acceptance-Criteria Matrix

At review execution populate evidence in the ChatGPT final Phase 2 review
report, using this matrix as its template. Do not edit this contract or replace
its `Pending` fields during the checkpoint.

| Criterion | Primary task(s) | Evidence | Result |
|---|---|---|---|
| Student assigned Homework read | BE-003 | `<tests/code>` | Pending |
| Safe Student Question projection | BE-003 | `<tests/code>` | Pending |
| Deadline read reconciliation | BE-002/003 | `<tests/code>` | Pending |
| At most 3 Attempts | BE-001/004 | `<tests/schema>` | Pending |
| One in-progress Attempt | BE-001/004 | `<tests/schema>` | Pending |
| Create-or-resume | BE-004 | `<tests>` | Pending |
| First official Attempt locks result pair | BE-004 | `<tests>` | Pending |
| Durable Start idempotency | BE-001/004 | `<tests>` | Pending |
| Eight non-file answer types | BE-001/005 | `<tests>` | Pending |
| File answer private flow | BE-001/006 | `<tests>` | Pending |
| Own protected submission download | BE-006 | `<tests>` | Pending |
| Explicit Submit freeze | BE-007 | `<tests>` | Pending |
| Pre-finalization read-only saved-answer integrity + non-file/file fixed-key rollback/recovery, no Answer/File mutation or completeness | BE-007 | `<tests/code, row/file snapshots>` | Pending |
| Durable Submit idempotency | BE-001/004/007 | `<tests>` | Pending |
| Historical completed Submit metadata/timestamps preserved when later projection fails | BE-007 | `<tests, record snapshots>` | Pending |
| Deadline auto-finalization | BE-002 | `<tests>` | Pending |
| Teacher-close auto-finalization | BE-002 | `<tests>` | Pending |
| No scoring/checking in Stage 7 | BE-002/005/006/007 | `<review/tests>` | Pending |
| Cross-tenant/ownership privacy | BE-003…007 | `<tests>` | Pending |
| Raw JSON / exact Student text boundary | BE-005 | `<tests/code>` | Pending |
| File uploader/download integrity + shared download lock | BE-006 | `<tests/code>` | Pending |
| Cross-Student ordinary-write non-blocking lock scope | BE-005/006/007 | `<pgsql tests>` | Pending |
| New-Submit lifecycle/Topic/deadline precedence before full invariant/editability, including invalid otherwise-resolved Attempts | BE-007 | `<tests/code>` | Pending |
| Complete locked Homework Attempt invariant on new Submit and replay + local lock scope | BE-007 | `<tests/code>` | Pending |
| Safe server_error for structural/persisted corruption without internal leaks | BE-005/006/007 | `<tests/code>` | Pending |
| Durable replay after later Attempt status progression with pending Answers; no premature Stage-9 checked-answer projection | BE-007 | `<tests/review>` | Pending |
| Concurrency exact-once | BE-002/004/005/006/007 | `<pgsql tests>` | Pending |

No required row may remain `Not verified` for `PASS`.

---

# 27. Full Backend Checkpoint Verification

Default executor:

```text
Project Owner
```

Approved CI may run equivalent commands.

Use the actual repository Docker environment.

## 27.1 Git preflight evidence

From repository root:

```bash
git switch main
git fetch --prune origin
git rev-parse HEAD
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
git status --short
```

Required:

```text
local main == origin/main
ahead/behind = 0/0
working tree clean
```

## 27.2 Full backend test suite

Run exactly one initial full-suite invocation:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app php artisan test
```

Record:

```text
passed
failed
skipped
assertions
duration
exit code
```

Do not rerun a failed full suite merely to obtain a green result without first classifying the failure.

Classify a failure as:

```text
candidate production defect
test/harness defect
environment/infrastructure failure
pre-existing unrelated failure
```

ChatGPT decides consequence/evidence validity.

## 27.3 Backend formatter

Run:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app ./vendor/bin/pint --test
```

Record exact result/exit code.

## 27.4 PHP syntax/static-equivalent check

The repository currently has no separate PHPStan/Psalm dependency in the reviewed baseline.

If that remains true at checkpoint execution, do not invent a new static-analysis dependency.

Run exactly:

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app sh -lc 'set -eu; find app bootstrap config database public routes tests -type f -name "*.php" -print0 | xargs -0 -n1 php -l'
```

Record exact result/exit code.

If a static analyzer has been legitimately added and configured in the repository
before checkpoint execution, ChatGPT must re-review this checkpoint command
before execution rather than letting the executor silently substitute a
different tool.

## 27.5 Migration/schema verification

Full suite must include migration-backed tests.

Additionally confirm via focused schema tests already present on `main` that:

```text
S07-BE-001 migration constraints/indexes
assessment_attempts invariants
Question tenant composite keys
answer typed tables
idempotency_records
```

are exercised.

Do not edit schema during review.

## 27.6 Stage-wide diff hygiene

From Windows PowerShell, resolve and check exactly:

```powershell
$BACKEND_BLOCK_BASE = git rev-parse '86067f9a61864a4d313b7ec8b59ee1217218b612^1'
$AUDITED_MAIN = git rev-parse origin/main

git diff --check "$BACKEND_BLOCK_BASE...$AUDITED_MAIN"
```

Must pass.

The semantic base remains the first parent of the S07-BE-001 production merge.
Record both resolved revisions in the final review report.

Also inspect the complete backend Stage 7 diff.

---

# 28. Mandatory Stage-Specific Security / Tenant Evidence

The full backend suite is necessary but not sufficient for the review.

Confirm test evidence exists and passed for:

```text
cross-Institution Homework ID
other Student Homework/Attempt ID
foreign Question/option/item/blank IDs
foreign/direct File ID
wrong role
inactive Student
inactive Institution
password-change-required
current membership removed but historical snapshot preserved
unauthorized read cannot trigger foreign deadline mutation
Teacher cannot download Student submission in Stage 7
Student cannot download another Student submission
linked Student-submission File with mismatched uploaded_by_user_id is 404
```

Any missing critical tenant/security evidence blocks PASS.

---

# 29. Mandatory Concurrency Evidence

Confirm real PostgreSQL concurrency tests pass for the delivered surfaces:

```text
deadline reconciliation vs Teacher close

Start same idempotency key
Start different keys

same-Attempt answer replacement
different Students / same Homework answer-save non-blocking

same-Attempt file replacement
different Students / same Homework file-upload non-blocking
Student-submission download shared File lock vs replacement FOR UPDATE

Submit same idempotency key
Submit different keys
different Students / same Homework Submit non-blocking
Submit vs non-file answer save
Submit vs file replacement
Submit vs Teacher close
Submit vs deadline reconciliation
```

At least the contracted tests must prove actual lock wait (or explicit absence of
a shared-row blocking dependency for the non-blocking regressions), rather than
sequential simulation.

Also review existing Stage 6 concurrency regressions affected by first public Attempt creation.

If a concurrency test becomes flaky due to arbitrary sleeps/timing rather than lock observation, classify as a checkpoint defect.

---

# 30. Full Diff / Scope Review

Review:

```text
BACKEND_BLOCK_BASE...AUDITED_MAIN
```

but distinguish:

- Stage 7 backend production/test changes;
- task/doc bookkeeping;
- unrelated merged work, if any.

Verify every Stage 7 backend changed file is justified by one approved task.

Search for:

```text
TODO
FIXME
debug
dump(
dd(
var_dump
print_r
temporary
```

where relevant.

Review dependency/lockfile/config changes.

Unexpected package additions are blocking unless explicitly approved.

---

# 31. Findings Severity

Use:

## P1

Security/data-integrity/core-contract issue, including:

- cross-tenant access;
- another Student's Attempt/file access;
- answer-key leak;
- idempotency duplicate mutation causing data corruption;
- saved-answer corruption committed as a successful Submit or destruction of a
  historical completed Submit record after projection failure;
- post-deadline mutation;
- storage path/private-file exposure;
- data loss/corruption.

## P2

Material functional/architecture/lifecycle defect, including:

- wrong Attempt count;
- stale deadline state;
- wrong finalization reason/timestamp;
- new-Submit lifecycle/deadline precedence masked by premature full structural validation;
- status-only non-editability that skips the full Homework Attempt invariant;
- completed replay returning action success without the full locked invariant;
- missing read-only pre-finalization saved-answer gate or fixed-key corruption/recovery evidence;
- premature acceptance of checked/scored Answers by Stage-7 pending-only integrity;
- Stage 7 scoring leakage;
- broken official pair lock;
- broken cleanup/reference semantics;
- material N+1;
- deadlock-prone lock inversion;
- missing required concurrency/negative tests.

## P3

Non-blocking maintainability/test clarity issue that does not break Stage contract.

Record findings:

| ID | Severity | Finding | Evidence | Required focused correction |
|---|---|---|---|---|
| `<S07-BE-R01>` | `<P1/P2/P3>` | `<issue>` | `<file/test>` | `<fix boundary>` |

If none:

```text
No findings.

P1 = 0
P2 = 0
P3 = 0
```

---

# 32. Verdict

Choose exactly:

```text
PASS
NOT ACCEPTED
```

`PASS` requires all:

- entry gate satisfied;
- all S07-BE-001…007 on audited `main`;
- full backend suite PASS;
- Pint PASS;
- required lint/static-equivalent PASS;
- `git diff --check` PASS;
- `P1 = 0`;
- `P2 = 0`;
- no unresolved architecture/API/database/lifecycle/security/tenant/idempotency/concurrency conflict;
- correct new-Submit lifecycle/Topic/deadline precedence before full invariant/editability,
  and full locked-invariant validation for completed replay;
- pre-finalization read-only saved-answer integrity with both fixed-key corruption
  rollback/recovery proofs and no Answer/File mutation;
- historical completed Submit records preserved on later projection failure;
- pending-only Stage-7 Answer integrity preserved, with no claim of genuine
  Stage-9 checked-answer endpoint replay;
- safe `server_error` responses for invariant/persisted-state corruption without
  LogicException/class/SQL/path/internal metadata leaks;
- required Stage 7 backend criteria have evidence.

P3 findings alone do not automatically block PASS, but must be recorded.
Any P1 or P2 finding blocks PASS.
A P3 may still require a focused correction if ChatGPT determines it creates
material Stage risk, but P3 severity itself is not an automatic checkpoint blocker.

Findings are never corrected during this checkpoint.

---

# 33. PASS Follow-Up

If:

```text
Verdict: PASS
```

record final evidence in the ChatGPT final Phase 2 review report, without editing
this contract:

```text
Audited main: <sha>
Full backend suite: <result>
Pint: <result>
Lint/static-equivalent: <result>
git diff --check: PASS
P1=0
P2=0
P3=<count>
```

Then:

```text
Stage 7 Backend block = accepted integrated checkpoint
```

Next permitted implementation gate:

```text
S07-FE-001 — Student Homework Read Foundation
```

Do not run Stage integration yet.

Frontend block must be implemented and later pass its own Phase 2 first.

---

# 34. NOT ACCEPTED Follow-Up

If:

```text
Verdict: NOT ACCEPTED
```

do not proceed to frontend implementation.

ChatGPT must:

1. record exact findings;
2. group only truly coupled findings;
3. issue focused fix contract(s);
4. avoid reopening unrelated accepted tasks;
5. define focused fix verification;
6. assign Project Owner delivery;
7. decide evidence invalidation after each fix.

Then rerun:

- every checkpoint command that previously failed;
- only previously passing checkpoint evidence materially invalidated by the fix.

Examples:

## Narrow answer validation fix

Usually rerun:

```text
focused answer tests
relevant Student API regressions
Pint
git diff --check
```

Full backend suite may remain valid if ChatGPT determines the change cannot invalidate it, unless the original full suite itself failed.

## Shared idempotency/locking fix

Normally invalidates broader:

```text
Start/Submit concurrency
deadline/close race evidence
full backend regression
```

## Schema/tenant/security fix

Normally invalidates:

```text
full backend suite
schema verification
tenant/security review
affected concurrency paths
```

Do not preserve evidence a later change materially invalidated.

---

# 35. Final Review Record Template

At actual checkpoint execution, use this template in the **ChatGPT final Phase 2
review report**. Populate evidence and replace `Pending` fields in that report
only; do not edit this contract. Resolve/freeze the audited `origin/main` at that
execution, rather than treating the current contract review baseline as audited.
Conclude the report with:

```text
S07-BE-PHASE-2

Audited origin/main:
<sha>

Backend tasks:
S07-BE-001: <PR/SHA>
S07-BE-002: <PR/SHA>
S07-BE-003: <PR/SHA>
S07-BE-004: <PR/SHA>
S07-BE-005: <PR/SHA>
S07-BE-006: <PR/SHA>
S07-BE-007: <PR/SHA>

Verification:
Full backend suite: <PASS/FAIL + counts>
Pint --test: <PASS/FAIL>
PHP lint/static-equivalent: <PASS/FAIL>
git diff --check: <PASS/FAIL>

Read-only integrated review:
Architecture: <PASS/FAIL>
API: <PASS/FAIL>
Persistence: <PASS/FAIL>
Lifecycle/deadline: <PASS/FAIL>
Idempotency: <PASS/FAIL>
Submit lifecycle/deadline/full-invariant precedence: <PASS/FAIL>
Pre-finalization saved-answer integrity / fixed-key recovery: <PASS/FAIL>
Historical completed Submit record preservation: <PASS/FAIL>
Pending-only Answer integrity / Stage 9 projection boundary: <PASS/FAIL>
Safe server invariant responses: <PASS/FAIL>
Concurrency: <PASS/FAIL>
Authorization: <PASS/FAIL>
Tenant isolation: <PASS/FAIL>
Question privacy: <PASS/FAIL>
Private file security: <PASS/FAIL>
Previous-stage regression: <PASS/FAIL>
Stage 8/9 compatibility: <PASS/FAIL>

Findings:
P1 = <n>
P2 = <n>
P3 = <n>

Verdict:
<PASS / NOT ACCEPTED>

Next permitted gate:
<S07-FE-001 only if PASS>
```

This checkpoint itself performs no implementation, production/test/contract
edits, or commit/push/PR delivery. Findings that block PASS under Section 32
produce `NOT ACCEPTED` and separate focused fix tasks under Section 34; fixes
are never applied during the checkpoint itself.
