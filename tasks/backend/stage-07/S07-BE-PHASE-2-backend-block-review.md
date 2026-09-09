# Phase 2 Read-Only Block Review — Stage 7 Backend

## 1. Review Metadata

| Field | Value |
|---|---|
| Review ID | `S07-BE-PHASE-2` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Block | `Backend` |
| Review mode | `Read-only` |
| Status | `Pending — execute only after S07-BE-001…007 are Accepted and Delivered` |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Audited `origin/main` | `Resolve at checkpoint execution time` |
| Backend block diff base | `Resolve as the commit immediately before the first delivered S07-BE-001 production change` |
| Review owner | `ChatGPT` |
| Verification executor | `Project Owner or approved CI` |
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

At checkpoint execution, record:

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
- do not merge.

ChatGPT identifies and classifies findings.

If code changes are required:

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

Fill from actual delivery evidence.

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

## 12.5 Forbidden Stage 7 Homework terminal use

Verify automatic Homework paths do not use:

```text
timed_out_finalized
timeout_auto_submit
waiting_for_teacher_review
checked
```

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
200 replay
```

Different key after terminal Submit:

```text
attempt_not_editable
```

## 17.4 Replay after later lifecycle

A previously completed same-key request may replay after:

- deadline;
- close/archive;
- later Stage 9 status progression.

Authorization to target remains required.

## 17.5 Atomicity

Verify no successful protected operation can commit domain state without completed idempotency metadata in the same transaction.

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

Rechecked under final locked Institution setting.

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

Teacher review/download remains Stage 9.

Historical own file survives Attempt finalization/current Group membership loss.

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
deterministic Attempt ordering
Student never acquires Group after Topic
answer mutation locks Attempt before Question
Submit/deadline/close serialize on Homework/Attempts
file download locks File without later parent lock acquisition
```

Review actual SQL/test behavior, not only intended comments.

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
```

No raw:

- SQL;
- filesystem path;
- stack trace;
- class name;
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

Locking all Assessment Attempts is intentional for exact deadline/close serialization; confirm no unrelated Institution scope.

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

---

# 26. Stage 7 Backend Acceptance-Criteria Matrix

At review execution populate evidence.

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
| Durable Submit idempotency | BE-001/004/007 | `<tests>` | Pending |
| Deadline auto-finalization | BE-002 | `<tests>` | Pending |
| Teacher-close auto-finalization | BE-002 | `<tests>` | Pending |
| No scoring/checking in Stage 7 | BE-002/005/006/007 | `<review/tests>` | Pending |
| Cross-tenant/ownership privacy | BE-003…007 | `<tests>` | Pending |
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

Run a repository-native PHP syntax check over Stage 7 changed PHP production/test files or an equivalent existing backend lint command.

If a static analyzer has been added legitimately before the checkpoint, use the repository's actual configured command and record it.

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

Let:

```text
BACKEND_BLOCK_BASE=<commit immediately before S07-BE-001 production delivery>
AUDITED_MAIN=<current origin/main>
```

Run:

```bash
git diff --check "${BACKEND_BLOCK_BASE}...${AUDITED_MAIN}"
```

Must pass.

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
```

Any missing critical tenant/security evidence blocks PASS.

---

# 29. Mandatory Concurrency Evidence

Confirm real PostgreSQL concurrency tests pass for the delivered surfaces:

```text
deadline reconciliation vs Teacher close
Start same idempotency key
Start different keys
answer replacement
file replacement
Submit same idempotency key
Submit different keys
```

At least the contracted tests must prove actual lock wait rather than sequential simulation.

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
- post-deadline mutation;
- storage path/private-file exposure;
- data loss/corruption.

## P2

Material functional/architecture/lifecycle defect, including:

- wrong Attempt count;
- stale deadline state;
- wrong finalization reason/timestamp;
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
- required Stage 7 backend criteria have evidence.

P3 findings alone do not automatically block PASS, but record them.

---

# 33. PASS Follow-Up

If:

```text
Verdict: PASS
```

record final evidence:

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

When executed, replace `Pending` fields with evidence and conclude with:

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

This checkpoint itself performs no implementation.
