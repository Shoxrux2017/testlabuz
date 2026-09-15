# Phase 2 Read-Only Block Review — Stage 8 Backend

## 1. Review Metadata

| Field | Value |
|---|---|
| Review ID | `S08-BE-PHASE-2` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Block | `Backend` |
| Review mode | `Read-only integrated backend checkpoint` |
| Status | `Pending execution after S08-BE-001…010 are Accepted / Delivered` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Audited `origin/main` | `Resolve/freeze at actual checkpoint execution` |
| Backend block diff base | `Resolve as first parent before the first delivered Stage 8 backend production change` |
| Review owner | `ChatGPT` |
| Verification executor | `Project Owner / approved CI` |
| Codex role | `None during read-only review; focused fix implementation only if ChatGPT later issues a fix contract` |
| Verdict | `Pending` |
| Findings | `Pending` |
| Next permitted gate after PASS | `OWNER_FRONTEND_APPROVAL_REQUIRED` |
| Required owner command at that gate | `/approve frontend` |

This file defines the mandatory Stage 8 Backend Phase 2 checkpoint.

It is **not** an implementation task.

Do not give this file to Codex merely to run broad verification or decide whether
the backend architecture is correct.

The checkpoint exists because Stage 8 backend behavior is distributed across ten
implementation tasks whose correctness depends on their integration as one
state machine.

---

# 2. Entry Gate

Execute this checkpoint only when all conditions below are true.

| Condition | Required |
|---|---|
| `S08-DOC-001` Accepted / Delivered | Yes |
| `S08-BE-001` Accepted / Delivered | Yes |
| `S08-BE-002` Accepted / Delivered | Yes |
| `S08-BE-003` Accepted / Delivered | Yes |
| `S08-BE-004` Accepted / Delivered | Yes |
| `S08-BE-005` Accepted / Delivered | Yes |
| `S08-BE-006` Accepted / Delivered | Yes |
| `S08-BE-007` Accepted / Delivered | Yes |
| `S08-BE-008` Accepted / Delivered | Yes |
| `S08-BE-009` Accepted / Delivered | Yes |
| `S08-BE-010` Accepted / Delivered | Yes |
| All accepted backend production/tests are on `origin/main` | Yes |
| Local `main == origin/main` | Yes |
| Ahead/behind | `0/0` |
| Working tree | Clean |
| No unresolved backend task blocker | Yes |

At execution, record:

```text
branch = main
origin/main = <sha>
local main = <sha>
ahead/behind = 0/0
working tree = clean
```

If any required delivery is still only local, in a task branch, or in an
unmerged PR:

```text
Backend Phase 2 execution = BLOCKED
```

Do not review unmerged task branches as though they were authoritative Stage
state.

---

# 3. Read-Only Rule

During Phase 2 review:

- do not edit production code;
- do not edit tests;
- do not edit migrations;
- do not edit contracts;
- do not update Stage bookkeeping;
- do not stage;
- do not commit;
- do not push;
- do not create/merge a PR;
- do not “quick-fix” findings.

ChatGPT performs the read-only integrated review and classifies findings.

If a blocking finding exists:

1. verdict = `NOT ACCEPTED`;
2. preserve review evidence;
3. ChatGPT creates one focused fix contract;
4. Codex implements only that fix;
5. Project Owner delivers it to `main`;
6. ChatGPT rechecks the new `main`;
7. rerun every invalidated required verification item;
8. issue a refreshed Phase 2 verdict.

Do not convert the checkpoint into a broad Codex refactor task.

---

# 4. Authoritative Review Inputs

At actual execution ChatGPT must re-read current GitHub `main`.

Minimum project/workflow inputs:

```text
AGENTS.md
backend/AGENTS.md
tasks/README.md
tasks/STAGE_08_TASK_INDEX.md
```

Locked product/technical inputs:

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

Stage 8 contract inputs:

```text
S08-DOC-001
S08-BE-001
S08-BE-002
S08-BE-003
S08-BE-004
S08-BE-005
S08-BE-006
S08-BE-007
S08-BE-008
S08-BE-009
S08-BE-010
```

Also inspect:

- current production source;
- migrations;
- routes;
- commands/scheduler;
- Resources;
- Requests;
- Actions/support/domain logic;
- Stage 8 tests;
- directly modified Homework/shared infrastructure;
- delivery PRs/commits needed to establish the backend block diff.

GitHub `main` is the source of truth.

Do not trust task completion summaries without re-reading the implementation.

---

# 5. Audited Task Inventory

Populate actual delivery PR/SHA evidence in the Phase 2 review report.

| Task | Integrated responsibility | Delivery evidence | Review result |
|---|---|---|---|
| `S08-BE-001` | Blitz persistence/domain foundation | `<PR/SHA>` | Pending |
| `S08-BE-002` | Teacher Blitz authoring/read/update/schedule/archive | `<PR/SHA>` | Pending |
| `S08-BE-003` | shared Homework/Blitz Question authoring integration | `<PR/SHA>` | Pending |
| `S08-BE-004` | official Blitz designation + activation/cohort/timer/idempotency | `<PR/SHA>` | Pending |
| `S08-BE-005` | Student Blitz read + normal Attempt #1 Start/Resume | `<PR/SHA>` | Pending |
| `S08-BE-006` | typed/file answer mutation + private file resume | `<PR/SHA>` | Pending |
| `S08-BE-007` | timeout/Teacher Close/Scheduler finalization | `<PR/SHA>` | Pending |
| `S08-BE-008` | idempotent Student Blitz Submit | `<PR/SHA>` | Pending |
| `S08-BE-009` | one-Student exception + replacement Attempt #2 | `<PR/SHA>` | Pending |
| `S08-BE-010` | Teacher live monitoring | `<PR/SHA>` | Pending |

Confirm:

- every accepted backend task is present on audited `main`;
- no hidden Stage 8 backend production work bypassed an approved task;
- later tasks did not silently alter earlier contracts;
- no Stage 9 checking/scoring/result implementation entered Stage 8.

---

# 6. Backend Scope Boundary

The integrated Stage 8 backend must implement:

```text
Blitz persistence/lifecycle
Teacher authoring
shared Question authoring
official Blitz designation
official cohort establishment/reuse
Teacher activation
synchronized / individual timer snapshot
Student active Blitz read/detail
normal Attempt #1 Start/Resume
typed answer mutation
file answer mutation/private own download
timeout reconciliation
Teacher Close
Scheduler timeout reconciliation
idempotent final Submit
one Student-specific approved replacement Attempt #2
Teacher operational monitoring
```

It must **not** implement Stage 9 ownership:

```text
automatic answer checking
Teacher manual review
awarded points
feedback/check timestamps
Attempt scoring
official Homework/Blitz score selection
Topic result calculation
result release
Teacher submission-review queue
Parent/Student score visibility
```

Any material Stage 9 production behavior introduced by Stage 8 is a blocking
scope defect.

---

# 7. Architecture Review

Review Stage 8 as one integrated backend subsystem.

## 7.1 HTTP boundaries

Verify:

```text
Route
-> Form Request
-> focused Action/use case
-> domain/support boundary
-> Eloquent/infrastructure
-> Resource
```

Check that:

- Controllers remain thin;
- Form Requests own transport/input shape only;
- persisted-state/lifecycle decisions stay out of Form Requests;
- Actions own transaction/use-case behavior;
- Resources serialize preloaded/projected state only;
- Resources do not query;
- no Controller owns tenant, timer, locking, idempotency or storage workflows.

Material layering collapse is at least `P2`.

## 7.2 Shared vs subtype-specific behavior

Verify Stage 8 generalized shared boundaries only where the persistence/API is
actually shared.

Expected shared responsibilities include, where delivered:

```text
Question mutation transport/persistence
Student answer payload persistence
Student final Submit route dispatch
Student submission file ownership
idempotency infrastructure
Assessment activation validation
recipient snapshot mechanics
Blitz attempt-history validation
```

Expected subtype-specific policy remains distinct:

```text
Homework lifecycle/deadline semantics
Blitz lifecycle/timer semantics
Blitz exception policy
Blitz timeout state
```

Flag either:

- duplicated authoritative shared rules; or
- false abstraction that merges incompatible Homework/Blitz business rules.

## 7.3 No God service

No one class should own a broad mix of:

```text
authorization
transport validation
Question configuration
recipient snapshots
timer math
idempotency
answer persistence
storage
timeout finalization
monitoring serialization
scoring
```

Review responsibilities, not only line count.

---

# 8. Persistence / Migration Review

Review every Stage 8 schema change on audited PostgreSQL.

## 8.1 `blitz_tasks`

Verify delivered structure supports exactly:

```text
assessment_id as subtype identity
institution_id
status
duration_seconds
scheduled_at
timer_start_mode_snapshot
activated_at
synchronized_ends_at
closed_at
archived_at
activated_by_user_id
timestamps
```

Verify:

- positive duration DB invariant;
- tenant-safe composite references where required;
- status enum/domain values;
- lifecycle timestamp combinations are coherent;
- synchronized activation shape;
- individual activation shape;
- no per-question timer field.

## 8.2 `blitz_attempt_exceptions`

Verify structural support for:

```text
one exception per assessment + Student
invalidated Attempt #1
nullable replacement Attempt #2
reason type/text
grant actor/time
tenant-safe relationships
```

Confirm uniqueness prevents:

- duplicate exception for same Student/Blitz;
- one invalidated Attempt used by multiple exception rows;
- one replacement Attempt linked to multiple exceptions.

## 8.3 Shared Attempt schema compatibility

Verify Stage 8 correctly reuses:

```text
assessment_attempts
attempt_answers
typed answer tables
files
answer_files
idempotency_records
```

No Blitz-only duplicate Attempt/answer table.

## 8.4 Attempt number invariant

The existing global structural upper bound may permit more values, but Stage 8
application behavior must enforce:

```text
#1 normal
#2 exception replacement only
no #3
```

Check both business guards and concurrency backstops.

---

# 9. Public Route Inventory

Enumerate current production routes and verify exactly the intended Stage 8
surface.

Teacher Blitz:

```text
GET    /api/v1/teacher/blitz
POST   /api/v1/teacher/topics/{topic}/blitz
GET    /api/v1/teacher/blitz/{blitz}
PATCH  /api/v1/teacher/blitz/{blitz}
POST   /api/v1/teacher/blitz/{blitz}/schedule
POST   /api/v1/teacher/blitz/{blitz}/archive
POST   /api/v1/teacher/blitz/{blitz}/activate
POST   /api/v1/teacher/blitz/{blitz}/close
POST   /api/v1/teacher/blitz/{blitz}/students/{student}/attempt-exception
GET    /api/v1/teacher/blitz/{blitz}/monitoring
```

Existing official pair endpoint extended:

```text
PUT /api/v1/teacher/topics/{topic}/result-pair
```

Shared Question endpoints:

```text
POST   /api/v1/teacher/assessments/{assessment}/questions
POST   /api/v1/teacher/assessments/{assessment}/questions/reorder
PATCH  /api/v1/teacher/questions/{question}
DELETE /api/v1/teacher/questions/{question}
```

Student Blitz:

```text
GET  /api/v1/student/blitz/active
GET  /api/v1/student/blitz/{blitz}
POST /api/v1/student/blitz/{blitz}/attempts
```

Shared Student Attempt endpoints:

```text
PUT  /api/v1/student/attempts/{attempt}/answers/{question}
POST /api/v1/student/attempts/{attempt}/submit
```

Existing protected file endpoint:

```text
GET /api/v1/files/{file}/download
```

Scheduler command:

```text
blitz:reconcile-timeouts
```

Check:

- no duplicate route family;
- no stale experimental alias;
- exact middleware;
- no production test/debug route;
- no accidental public endpoint.

---

# 10. Teacher Authorization / Tenant Isolation

For every Teacher path verify query order conceptually begins from:

```text
authenticated Teacher
-> Teacher Institution
-> current Teacher–Group relationship
-> owned Topic / Assessment
-> subtype/detail
```

Check direct IDs for:

```text
Topic
Blitz Assessment
Question
Student exception target
```

A valid UUID must not widen scope.

Verify:

- foreign Institution returns privacy-safe 404;
- another Teacher's resource does not leak;
- ended Teacher membership revokes normal Teacher access;
- monitoring/exception do not resolve arbitrary Institution Students outside
  the persisted Blitz recipient set.

Any cross-Tenant read/write is `P1`.

---

# 11. Result-Pair Integration Review

Review final `topic_result_pairs` behavior after BE-004 and later tasks.

Verify:

- Homework-only Stage 6 PUT still works;
- omitted `blitz_assessment_id` preserves existing Blitz side;
- explicit null cannot clear the Blitz side;
- official Blitz must be whole-group;
- Draft/Scheduled unused Blitz may be designated;
- locked partial pair may fill only the missing Blitz side;
- locked pair identity is not rewritten;
- completed pair blocks ordinary Homework substitution;
- preactivity unlocked Blitz replacement rules are enforced;
- exact same-target operation is a true no-op;
- Question mutation/Start/Submit/monitoring do not mutate pair identity.

## 11.1 Historical designation timestamp

Verify Blitz-only completion does not incorrectly rewrite pair-level
`designated_at` and violate historical cohort ordering.

## 11.2 First Student activity lock

For official tasks verify:

```text
pair.locked_at
```

is established on the first official Student Attempt activity and is preserved
afterward.

No later Student Start/Submit/exception rewrites it.

---

# 12. Official Cohort Review

The first activated official assessment establishes the common cohort.

Review both directions:

```text
Homework first -> Blitz later
Blitz first -> Homework later
```

Verify:

- persisted `assessment_students` snapshots are the authority;
- later Group membership does not redefine official cohort;
- established official cohort is copied exactly to the later activated official task;
- pair lock does not prevent activation of an already-designated second official task;
- incompatible persisted cohort snapshots are rejected, not silently repaired;
- no current-membership resnapshot after cohort establishment.

Cohort mismatch/rewriting is at least `P1` if it can change official result
population.

---

# 13. Blitz Authoring / Lifecycle Review

Verify lifecycle:

```text
draft -> scheduled -> active -> closed -> archived
```

and valid preparation shortcuts/no-ops defined by contracts.

Review:

- Create always returns Draft, even with optional `scheduled_at`;
- Schedule is preparation only;
- Schedule does not activate;
- Update cannot edit active/closed/archived content;
- Archive does not act as Close;
- active Blitz cannot be archived directly;
- closed archive preserves history;
- `scheduled_at` remains historical on activation;
- Teacher Close is natural no-op when already closed;
- no automatic Scheduler close.

Review Topic lifecycle guard:

```text
Draft/Scheduled/Active Blitz
=> Topic has open assessments
```

Closed/Archived Blitz is resolved for Topic close/archive.

---

# 14. Question Authoring Integration Review

Shared Question endpoints must genuinely support both:

```text
Homework
Blitz
```

without weakening Homework.

Verify Homework retains:

```text
draft/active pre-Attempt editing
locked official pair protection
active scoreability guard
existing exact errors/resource shape
```

Verify Blitz allows Question mutation only:

```text
draft
scheduled
```

and blocks:

```text
active
closed
archived
```

Confirm:

- historical pair `locked_at` alone does not block valid Draft/Scheduled Blitz authoring;
- all nine Question types use the shared canonical writer/validators;
- no per-question timer exists;
- total points remain exact after add/update/delete;
- reorder preserves points;
- semantic no-ops do not churn timestamps;
- activation vs Question mutation shares a safe lock order.

---

# 15. Activation / Institution Timer Review

Verify Teacher activation:

- requires active Topic/Group/current Teacher authorization;
- snapshots current Institution `blitz_timer_start_mode`;
- does not use client timer mode;
- missing setting returns `institution_settings_incomplete`;
- validates current Question graph/positive scoreable total;
- snapshots/validates recipients;
- creates no Student Attempt.

## Synchronized

Verify:

```text
synchronized_ends_at
=
activated_at + duration_seconds
```

## Individual

Verify:

```text
synchronized_ends_at = null
```

Institution setting changes after activation must not change active task timing.

Activation must be safe under:

```text
Question mutation
Schedule/Update
result-pair mutation
Institution settings update
membership changes
concurrent activation
```

---

# 16. Student Pre-Start Privacy Review

Verify:

```text
GET /student/blitz/{blitz}
```

does **not** expose Question content before Start.

This is especially critical for individual mode.

Active list/detail must not leak:

```text
Question prompts/options
answer keys
Teacher configuration
checking metadata
```

Questions become visible only in a valid Start/Resume Attempt projection.

Pre-start Question leakage is `P1`.

---

# 17. Student Assignment / Recipient Authority

Student execution must use persisted:

```text
assessment_students
```

not current Group membership.

Review:

- Active list;
- Detail;
- Start/Resume;
- answer/file mutation;
- Submit;
- own Student-submission download.

Later Group membership removal must not silently erase historical/frozen Blitz
assignment.

Current active-account middleware may block login/use, but the assignment graph
must remain historical.

---

# 18. Normal Attempt #1 Review

For Student without exception verify:

```text
exactly one normal Attempt #1
```

No Attempt #2 or #3 without the approved exception path.

## Synchronized normal Start

Verify:

```text
deadline_at = blitz.synchronized_ends_at
```

Late opener gets only remaining class time.

At/equal common end:

```text
no Attempt creation
```

## Individual normal Start

Verify:

```text
deadline_at = started_at + duration_seconds
```

## Resume

Verify:

- same Attempt ID;
- no timer reset;
- no `started_at`/`deadline_at` churn.

---

# 19. Replacement Attempt #2 Review

Verify Teacher grant and Student replacement compose exactly.

Grant must:

```text
preserve #1 history
set #1 official_score_eligible=false
create one exception row
not create #2
```

Replacement Start must:

```text
require valid exception
create #2 only
set #2 official_score_eligible=true
link exception.replacement_attempt_id=#2
create no #3
copy no answers/files
```

## 19.1 Timing

Replacement #2 gets:

```text
deadline_at = replacement_started_at + duration_seconds
```

in **both** timer modes.

For synchronized mode:

- common class end remains unchanged;
- #2 may extend beyond it;
- #2 may start after common end while Blitz remains active.

This cross-task rule is mandatory.

---

# 20. Exception Grant Review

Review exact grant policy:

- active Blitz only;
- assigned active Student target;
- exactly #1 required;
- valid reason type;
- mandatory reason;
- exactly one exception;
- no revoke/edit;
- same-key replay;
- different-key duplicate conflict.

A live #1 before deadline must not be artificially invalidated.

If #1 is in-progress but already due, grant may reuse the exact timeout finalizer.

No invented finalization reason.

No exception grant changes:

```text
Blitz duration
timer snapshot
class common end
pair/cohort
other Students
normal attempt count
```

---

# 21. Answer Persistence / Mutation Review

Shared Student answer URL must correctly dispatch Homework vs Blitz.

Verify all nine Blitz Question types use normalized persistence.

Check:

- own Attempt/Question scope;
- exact typed child ownership;
- complete replace semantics;
- clear semantics;
- semantic no-op;
- raw Student text preservation;
- pending checking state;
- no score writes;
- deadline/lifecycle re-check under lock.

No generic JSON answer fallback.

No post-finalization Student mutation.

---

# 22. File Answer / Private Storage Review

Verify Blitz reuses the Stage 7 private Student submission model.

Check:

- server MIME/content inspection;
- institution effective size limit;
- private storage;
- stable File ID on replacement;
- identical replacement no-op;
- rollback/blob compensation;
- old blob cleanup only after commit;
- Teacher still cannot download Student submission in Stage 8;
- Student can download only own persisted current file;
- Homework file download remains unchanged.

Cross-Tenant file access or public storage is `P1`.

---

# 23. Execution Finalization Review

## 23.1 Explicit Student Submit

Pre-deadline:

```text
status = submitted
submitted_at = finalized_at = locked_at = submittedAt
reason = student_submit
```

## 23.2 Timeout

At/equal deadline:

```text
status = timed_out_finalized
submitted_at = null
finalized_at = locked_at = exact attempt.deadline_at
reason = timeout_auto_submit
```

## 23.3 Teacher Close before Attempt deadline

```text
status = submitted
submitted_at = null
finalized_at = locked_at = closedAt
reason = task_closed_auto_finalize
```

## 23.4 Timeout precedence

For every Attempt independently:

```text
if closedAt >= attempt.deadline_at:
    timeout wins
else:
    close wins
```

Important for individual mode and replacement #2.

Terminal state/reason/timestamps must never be rewritten.

---

# 24. Timeout Reconciliation Coverage

The same authoritative Blitz timeout engine must be used by:

```text
Student Active list
Student Detail
Start/Resume
typed answer mutation
file answer mutation
late Submit
Teacher Close
Scheduler
Teacher monitoring
```

Review for duplicated timeout logic that can disagree.

Scheduler latency must not change historical finalization time.

No due Attempt may remain editable simply because Scheduler has not run.

No timeout operation creates:

```text
missing Attempt
missing answer rows
scores
checking results
```

---

# 25. Scheduler Review

Verify exact command:

```text
blitz:reconcile-timeouts
```

and schedule:

```text
everyMinute()
withoutOverlapping(5)
```

Confirm:

- existing Homework Scheduler remains unchanged;
- due candidate scan is bounded/lazy;
- each candidate is rechecked under authoritative locks;
- one bad candidate does not stop later candidates;
- command returns failure when failures > 0;
- Scheduler finalizes Attempts only;
- Scheduler never auto-closes Blitz.

---

# 26. Submit Idempotency Review

Verify shared Submit URL dispatches Homework/Blitz safely.

Blitz operation exact:

```text
student.blitz.attempt.submit
```

Check:

- ownership before replay;
- fingerprint route identity;
- completed resource metadata;
- atomic Attempt transition + idempotency completion;
- same-key success replay;
- different-key terminal behavior;
- late Submit leaves no successful/incomplete claim.

Expected new request terminal behavior:

```text
timeout-finalized -> blitz_time_expired
other terminal    -> attempt_not_editable
```

No Stage 8 `submission_locked`.

---

# 27. Start Idempotency Review

Operation:

```text
student.blitz.attempt.start
```

Review both Attempt paths.

## Normal

- one #1;
- concurrent different keys -> one #1, loser resumes.

## Replacement

- old completed #1 Start key replays #1;
- new key required to create #2;
- concurrent replacement starts -> one #2;
- exception linkage and Start completion are atomic.

No key can be used as authorization.

---

# 28. Teacher Idempotency Review

Review:

```text
teacher.blitz.activate
teacher.blitz.attempt_exception.grant
```

For each:

- authenticated Teacher ownership before replay;
- operation-specific fingerprint;
- same-key replay;
- different fingerprint reuse rejection;
- successful domain writes + completion atomic;
- failed operation leaves no committed claim;
- replay after later lifecycle preserves historical logical success.

Close has no durable idempotency operation and must remain naturally idempotent.

---

# 29. Monitoring Review

Monitoring is operational only.

Verify:

- active Blitz only;
- timeout reconciliation before final projection;
- persisted recipient snapshot is roster authority;
- Student rows expose only `id/full_name`;
- no Questions/answers/files/checking data;
- `score = null`;
- deterministic status projection;
- exception-aware current path;
- #2 becomes current after replacement Start;
- unused replacement exception projects `not_started`;
- summary partition derives from returned rows;
- one `server_now` per response;
- no N+1 Student/Attempt/Exception query pattern.

Monitoring must not mutate anything except via the shared due-timeout reconciler.

---

# 30. Error Contract Review

Review all Stage 8 machine codes for:

- exact HTTP status;
- stable usage;
- no message-based branching;
- no duplicate synonymous codes;
- no SQL/internal leakage.

Important codes include current delivered equivalents of:

```text
resource_not_found
validation_failed
business_conflict
task_not_active
task_closed
task_archived
topic_not_editable
topic_has_open_assessments
official_task_requires_group_assignment
official_cohort_mismatch
assessment_has_no_scoreable_points
institution_settings_incomplete
assessment_not_assigned
attempts_exhausted
attempt_not_editable
blitz_not_active
blitz_time_expired
idempotency_key_reused
blitz_attempt_exception_not_allowed
blitz_attempt_exception_already_granted
blitz_normal_attempt_required
```

Verify exact privacy-safe behavior for direct IDs.

---

# 31. Concurrency / Lock-Order Audit

This is a major Stage 8 checkpoint requirement.

Build a cross-task lock-order map from current implementation.

At minimum compare these operations:

```text
result-pair PUT
Blitz Update/Schedule/Archive
Question mutation
Activation
Student Start
answer mutation
file mutation
timeout reconciliation
Student Submit
Teacher Close
exception grant
replacement Start
monitoring final read
```

Verify consistent parent-first ordering.

Expected conceptual hierarchy should remain compatible with:

```text
Group / membership
Topic
Assessment
BlitzTask
TopicResultPair / InstitutionSetting / recipient as applicable
AssessmentAttempt
Question / Answer
File
Exception
Idempotency row
```

Exact relative placement may differ where an operation does not need a row, but
no two high-risk operations may establish opposite lock orders that create
avoidable deadlocks.

Review task-level concurrency tests as evidence but also inspect actual lock
order in production code.

Material deadlock/lost-update risk is at least `P1/P2` depending on impact.

---

# 32. Cross-Task Race Audit

Verify actual code for these integrated races:

```text
Question mutation vs Activation
Activation vs Update/Schedule/Archive
Activation vs result-pair mutation
Activation vs Institution setting update
Start vs Activation
Start vs Teacher Close
Start vs exception grant
Start vs pair first-activity lock
answer/file vs Submit
answer/file vs timeout
answer/file vs Teacher Close
Submit vs timeout
Submit vs Teacher Close
grant vs timeout
grant vs Close
grant vs replacement Start
replacement Start vs Close
replacement Start vs Scheduler
monitoring vs Start
monitoring vs Submit
monitoring vs grant
monitoring vs Close
```

For every race require one coherent committed history.

No repair-by-later-read should be required for an invariant that should have been
atomic.

---

# 33. Timestamp / Server Clock Audit

Verify backend clock is authoritative everywhere.

Check:

```text
activated_at
synchronized_ends_at
Attempt.started_at
Attempt.deadline_at
submitted_at
finalized_at
locked_at
closed_at
granted_at
pair.locked_at
cohort_snapshotted_at
```

No client field/header controls these instants.

Review exact boundary behavior:

```text
server_now == deadline_at
=> expired
```

No device timezone can extend execution.

UTC API serialization must remain consistent.

---

# 34. No-Op / Historical Immutability Audit

Review semantic no-op behavior across:

```text
Blitz PATCH
Schedule
Archive repeat
Question update/reorder
Activation repeat
Close repeat
Start resume/replay
Submit replay
exception grant replay
timeout reconciliation repeat
monitoring read
```

No-op/replay must not churn historical timestamps unless the contract explicitly
defines a current resource projection only.

Terminal Attempt:

```text
status
reason
submitted_at
finalized_at
locked_at
```

must be immutable after first valid terminal transition.

---

# 35. Query / Performance Review

Inspect Stage 8 hot queries.

Verify no obvious N+1/unbounded reads in:

```text
Teacher Blitz list
Teacher Blitz detail
Student active Blitz list
Student Blitz Start/Resume projection
Teacher monitoring
Question resources
exception/read projection
```

Monitoring must load roster/Attempts/exceptions in a bounded query count.

List endpoints must filter/order in SQL.

Check indexes support new primary query shapes where needed.

Do not accept a performance “optimization” that weakens tenant scoping.

---

# 36. Security / Data Leakage Review

Search recursively across Student-facing Blitz JSON.

Student must never receive:

```text
is_correct
correct_value
accepted_answers
correct_position
match_key
Teacher checking configuration
another Student's Attempt
another Student's exception
storage disk/key
private filesystem path
Teacher internal IDs
```

Teacher monitoring must never receive Student answer contents or private file
metadata.

Teacher Stage 8 must not gain Student-submission download.

Any answer-key/cross-Student/cross-Tenant/private-storage leak is `P1`.

---

# 37. Shared Homework Regression Architecture Review

Because Stage 8 deliberately generalized shared infrastructure, inspect Homework
behavior for unintended regression in:

```text
Question authoring
recipient snapshot
activation validation
Topic open-assessment guard
Student answer shared route
Student submission file ownership
shared Submit route
idempotency exception namespace/infrastructure
```

Confirm Stage 6/7 Homework semantics remain intact.

Do not rely only on Stage 8 tests; full backend regression below is mandatory.

---

# 38. Migration Safety Review

Inspect new forward migration(s).

Verify:

- no delivered migration edited destructively;
- PostgreSQL-compatible;
- rollback reasonable;
- existing Stage 7 data remains valid;
- no unsafe table/column rename;
- constraints match application assumptions;
- indexes support candidate queries;
- no environment-specific value;
- no secrets.

Run no manual schema patch as part of review.

---

# 39. Test Quality Review

Review Stage 8 tests, not only pass counts.

Check coverage for:

```text
happy paths
strict validation
auth/role
Tenant isolation
direct-ID privacy
lifecycle
no-op timestamps
DB constraints
Question privacy
timer boundaries
timeout equality
idempotency
concurrency
file compensation
exception #2
monitoring
Homework regressions
```

Flag:

- weakened assertions;
- tests changed only to accommodate incorrect code;
- sleeps/non-deterministic timing where frozen time/barriers should be used;
- tests that mock away PostgreSQL behavior being tested;
- missing negative cross-Tenant coverage.

---

# 40. Full Backend Regression Gate

After read-only code review reaches a state where running the suite is justified,
execute the **full backend suite once** on the frozen audited SHA:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app php artisan test
```

Required:

```text
exit code = 0
all tests passed
no unexpected skipped/incomplete/risky test that invalidates Stage 8 evidence
```

Record exact:

```text
passed count
assertion count
duration
exit code
audited SHA
```

Do not rerun a passing full suite merely to produce a nicer duration/count.

If the run fails:

- preserve exact failure evidence;
- determine whether it is product/test/environment;
- Phase 2 cannot PASS while a required product regression remains failing.

A rerun is allowed only when:

- diagnosing a failure;
- environment recovery is required;
- a delivered focused fix invalidated prior full-suite evidence.

---

# 41. Backend Format / Static Gate

On the same audited SHA run the repository's required backend format/static
checks.

Minimum:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app ./vendor/bin/pint --test
```

Also run the current repository's established PHP lint/static-equivalent command
if one exists at checkpoint execution.

Do not invent a new static-analysis tool/package.

Record exact command/result.

---

# 42. Git Diff Check

From repository root:

```bash
git diff --check <BACKEND_BLOCK_DIFF_BASE>...origin/main
```

Required:

```text
PASS
```

Also inspect:

```bash
git diff --stat <BACKEND_BLOCK_DIFF_BASE>...origin/main
git status --short
```

The block review must understand the complete Stage 8 backend diff.

Do not use only the final task diff.

---

# 43. Scope/Diff Review

Inspect every Stage 8 backend changed file and classify it as:

```text
required production
required migration
required test
required shared regression refactor
unrelated/unnecessary
```

Blocking examples:

- unrelated frontend change in backend task delivery;
- dependency/lockfile churn without approved dependency;
- speculative Stage 9 code;
- generated/debug files;
- duplicated old/new route families;
- large unrelated refactor;
- modified historical task/doc file as part of production implementation without
  explicit ownership.

No “it still passes tests” exception for out-of-scope production behavior.

---

# 44. Severity Model

Classify findings:

## P1 — Critical / blocking

Examples:

- cross-Tenant access/write;
- answer-key leakage;
- Student can extend authoritative Blitz time;
- duplicate/extra Attempt beyond policy;
- official cohort/result-pair identity corruption;
- terminal Attempt reason/time can be overwritten;
- lost Student answer/file after accepted commit;
- private file exposure;
- scoring/result behavior materially wrong;
- concurrency race corrupts official execution history.

Any `P1`:

```text
Verdict = NOT ACCEPTED
```

## P2 — Major / blocking

Examples:

- lifecycle/API contract mismatch;
- broken idempotency replay;
- monitoring gives materially incorrect Student state;
- replacement timing wrong;
- N+1 severe enough for normal classroom roster;
- shared Homework regression;
- architecture responsibility defect likely to cause inconsistent authoritative
  rules;
- missing material test coverage.

Any unresolved `P2`:

```text
Verdict = NOT ACCEPTED
```

## P3 — Minor

Examples:

- small maintainability issue;
- narrow naming/readability issue;
- non-blocking test clarity gap;
- low-risk inefficiency.

A P3 may be:

```text
fix now
or
record as accepted follow-up
```

only if it does not threaten Stage 8 correctness/security/integration.

---

# 45. PASS Conditions

Backend Phase 2 may PASS only when all are true:

```text
P1 = 0
P2 = 0
all required entry gates PASS
all S08-BE-001…010 accepted work is on audited main
architecture review PASS
API contract review PASS
database/migration review PASS
authorization/Tenant review PASS
result-pair/cohort review PASS
Question privacy review PASS
timer/Attempt lifecycle review PASS
idempotency review PASS
answer/file review PASS
timeout/Close/Scheduler review PASS
exception/replacement review PASS
monitoring review PASS
cross-task concurrency review PASS
shared Homework regression review PASS
full backend suite PASS
Pint/static gate PASS
git diff --check PASS
final read-only diff review has no blocking finding
```

Passing task-level focused tests alone is insufficient.

---

# 46. NOT ACCEPTED Conditions

Return:

```text
Backend Phase 2: NOT ACCEPTED
```

for any:

- unresolved P1;
- unresolved P2;
- full backend suite failure caused by product/test regression;
- format/static required failure;
- missing accepted task delivery;
- dirty/diverged Git state that prevents authoritative checkpoint;
- material scope drift;
- inability to establish Tenant/security integrity;
- inability to validate the integrated Stage 8 state machine.

Do not proceed to frontend implementation while Backend Phase 2 is NOT ACCEPTED.

---

# 47. Focused Fix Workflow

If Phase 2 finds a defect:

1. ChatGPT writes a **small focused fix implementation contract**;
2. Codex reads only that fix contract + applicable engineering rules + directly
   relevant code/tests;
3. Codex runs focused fix verification only;
4. Project Owner delivers;
5. ChatGPT reviews the fix;
6. ChatGPT determines which Phase 2 evidence is invalidated.

Examples:

## Local behavior fix only

May require:

```text
focused test rerun
Pint
git diff --check
targeted read-only re-review
```

If ChatGPT determines the original full-suite evidence remains valid for
unaffected code, do not rerun it automatically.

## Shared architecture / DB / route / lifecycle fix

Normally invalidates the full backend suite evidence.

Rerun the full suite before PASS.

The goal is evidence correctness, not ritual repetition.

---

# 48. Final Phase 2 Report Template

ChatGPT final checkpoint report should contain compact evidence.

```text
Stage 8 Backend Phase 2
Audited main: <sha>
Diff base: <sha>
Git state: main == origin/main, ahead/behind 0/0, clean

Task delivery:
S08-BE-001: <PR/SHA>
S08-BE-002: <PR/SHA>
S08-BE-003: <PR/SHA>
S08-BE-004: <PR/SHA>
S08-BE-005: <PR/SHA>
S08-BE-006: <PR/SHA>
S08-BE-007: <PR/SHA>
S08-BE-008: <PR/SHA>
S08-BE-009: <PR/SHA>
S08-BE-010: <PR/SHA>

Verification:
Full backend suite: <PASS/FAIL + passed/assertions/duration/exit>
Pint --test: <PASS/FAIL>
PHP lint/static-equivalent: <PASS/FAIL or N/A with reason>
git diff --check: <PASS/FAIL>

Read-only review:
Architecture: <PASS/findings>
API: <PASS/findings>
DB/migrations: <PASS/findings>
Authorization/Tenant: <PASS/findings>
Pair/cohort: <PASS/findings>
Timing/lifecycle: <PASS/findings>
Idempotency: <PASS/findings>
Answers/files: <PASS/findings>
Exception/replacement: <PASS/findings>
Monitoring: <PASS/findings>
Concurrency: <PASS/findings>
Homework regressions: <PASS/findings>
Scope/diff: <PASS/findings>

Findings:
P1 = <n>
P2 = <n>
P3 = <n>

Verdict:
PASS | NOT ACCEPTED

If PASS:
Next required state = OWNER_FRONTEND_APPROVAL_REQUIRED
Frontend owner approval = NOT YET GRANTED BY THIS PASS
```

Do not paste enormous successful test logs.

Include exact failure details when they are needed to support a finding.

---

# 49. Exit Gate After PASS

A Backend Phase 2 PASS does **not** directly authorize frontend implementation.

After:

```text
S08-BE-PHASE-2 = PASS
```

the Stage must stop at:

```text
OWNER_FRONTEND_APPROVAL_REQUIRED
```

The repository owner must then send, at that exact stopped state:

```text
/approve frontend
```

The Stage Orchestrator must validate the original owner comment and its matching
bot-created receipt before `S08-FE-001` is released.

An early `/approve frontend`, a manually edited INDEX value, or a cached issue
marker without valid receipt evidence is not authorization.

Only after:

```text
Backend Phase 2 PASS
+
valid current owner frontend approval receipt
```

may ChatGPT/orchestration re-check current `origin/main`, confirm FE-001 current
readiness, and hand the exact FE-001 contract to Codex.

Codex must not inspect Stage history, the INDEX, control-issue comments or
approval receipts to decide whether this gate passed.

Backend PASS means:

> The complete Stage 8 backend block is integrated and trusted enough to become
> the frontend/API dependency.

It does **not** mean the frontend block is owner-approved, and it does **not**
mean Stage 8 is closed.

Still required later:

```text
OWNER_FRONTEND_APPROVAL_REQUIRED
S08-FE-001…006
S08-FE-PHASE-2
OWNER_INTEGRATION_APPROVAL_REQUIRED
S08-INT-001
OWNER_CLOSURE_APPROVAL_REQUIRED
STAGE_08_CLOSURE_REVIEW
```

---

# 50. Checkpoint Readiness Verdict

```text
Review type                         = READ-ONLY BLOCK CHECKPOINT
Backend task scope                  = DEFINED
Entry gate                          = DEFINED
Authoritative inputs                = DEFINED
Task inventory                      = DEFINED
Architecture audit                  = DEFINED
Persistence audit                   = DEFINED
API/routes audit                    = DEFINED
Authorization/Tenant audit          = DEFINED
Result-pair/cohort audit            = DEFINED
Question authoring/privacy audit    = DEFINED
Activation/timer audit              = DEFINED
Attempt #1/#2 audit                 = DEFINED
Answer/file audit                   = DEFINED
Timeout/Close/Scheduler audit       = DEFINED
Submit/idempotency audit            = DEFINED
Exception replacement audit         = DEFINED
Monitoring audit                    = DEFINED
Concurrency/lock-order audit        = DEFINED
Homework regression audit           = DEFINED
Full backend suite gate             = DEFINED
Format/static gate                  = DEFINED
Git/diff gate                       = DEFINED
Severity/verdict rules              = DEFINED
Focused fix workflow                = DEFINED

Checkpoint contract readiness       = PASS
Execution state                     = BLOCKED until S08-BE-001…010 are Accepted / Delivered on origin/main
Next gate after checkpoint PASS      = OWNER_FRONTEND_APPROVAL_REQUIRED
Frontend release                    = valid /approve frontend owner receipt only
```
