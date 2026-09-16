# Phase 2 Read-Only Block Review — Stage 8 Frontend

## 1. Metadata

| Field | Value |
|---|---|
| Review ID | `S08-FE-PHASE-2` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Block | `Frontend` |
| Review mode | `Read-only integrated Flutter checkpoint` |
| Status | `Pending execution after S08-FE-001…006 are Accepted / Delivered` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Audited `origin/main` | Resolve/freeze at execution |
| Frontend diff base | Commit immediately before first Stage 8 frontend production change |
| Backend dependency | `S08-BE-PHASE-2 = PASS` |
| Review owner | ChatGPT |
| Verification executor | Project Owner / approved CI |
| Codex role | None during read-only review; focused fixes only from a later ChatGPT fix contract |
| Verdict | Pending |
| Next permitted gate after PASS | `ChatGPT current-main/readiness review of S08-INT-001` |

This is a **checkpoint/review contract**, not an implementation task.

Do not create a duplicate `CODEX-PROMPT`.

---

# 2. Entry Gate

Execute only when:

```text
S08-BE-PHASE-2 = PASS

S08-FE-001 = Accepted / Delivered
S08-FE-002 = Accepted / Delivered
S08-FE-003 = Accepted / Delivered
S08-FE-004 = Accepted / Delivered
S08-FE-005 = Accepted / Delivered
S08-FE-006 = Accepted / Delivered
```

All accepted code/tests must be merged to `origin/main`.

Required Git preflight:

```bash
git switch main
git fetch --prune origin
git branch --show-current
git rev-parse HEAD
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
git status --short
```

Required:

```text
branch = main
HEAD == origin/main
ahead/behind = 0/0
working tree = clean
```

If any accepted task is still only local/unmerged/divergent:

```text
BLOCKED
```

---

# 3. Frontend Diff Base

At execution identify:

```text
FRONTEND_BLOCK_DIFF_BASE
=
the commit immediately before the first Stage 8 frontend production implementation entered main
```

Audit:

```text
<FRONTEND_BLOCK_DIFF_BASE>...origin/main
```

The range must include:

- FE-001…006 production changes;
- focused tests;
- router changes;
- shared Teacher/Student refactors;
- idempotency/error/formatter changes;
- all Phase 2 fixes merged before final PASS.

Do not use only the last task diff.

---

# 4. Read-Only Rule

During checkpoint execution do not:

- edit source/tests;
- auto-format;
- auto-fix analyzer output;
- change dependencies/FVM pin;
- stage/commit/push;
- alter task/checkpoint files.

Allowed:

- inspect code/tests/diff/history;
- run tests/analyze/format-check/builds;
- report findings.

If a finding exists:

```text
record evidence
assign severity
Verdict = NOT ACCEPTED
```

Fixes happen only through a separate focused implementation contract.

---

# 5. Severity

## P1 — Critical

Examples:

- Student sees Blitz Questions before successful Start/Resume;
- answer keys/checking data leak;
- cross-Tenant/cross-Student data or file leak;
- stale async result publishes into another session/Blitz;
- recovery uses a new Start key and can create replacement Attempt #2;
- device clock can extend authoritative Blitz execution;
- Student can mutate terminal Attempt;
- private storage path exposed;
- Teacher monitoring exposes Student answers/files/scores;
- mobile route bypass exposes forbidden mutation surface.

Any P1 => `NOT ACCEPTED`.

## P2 — Major

Examples:

- lifecycle/API mismatch;
- replacement timing UX wrong;
- countdown reset grants apparent extra time;
- uncertain Start/Activate/Submit/grant changes key;
- uncertain answer/file PUT blindly replays;
- Submit requires all Questions answered;
- Submit allowed with dirty/uncertain local state;
- locked partial pair cannot be filled;
- monitoring overlaps/runs in background;
- mobile capability matrix wrong;
- Stage 6/7 regression;
- full tests/analyze/build failure.

Any unresolved P2 => `NOT ACCEPTED`.

## P3 — Minor

Small copy/accessibility/maintainability issues.

Default final target:

```text
P1=0
P2=0
P3=0
```

---

# 6. Task Inventory

Populate actual PR/SHA evidence at execution:

```text
S08-FE-001 — Teacher read foundation
S08-FE-002 — Teacher Builder + Questions
S08-FE-003 — Teacher lifecycle + official designation
S08-FE-004 — Student active/detail/Start/countdown
S08-FE-005 — Student execution/Submit/terminal UX
S08-FE-006 — Teacher monitoring/exception/mobile runtime
```

Confirm each delivery is ancestor of audited `main`.

Confirm no unapproved Stage 8 frontend production scope entered outside these
tasks/focused fixes.

---

# 7. Mandatory Full Frontend Tests

Run once initially:

```bash
cd frontend
fvm flutter test
```

Record:

```text
exit code
passed
failed
skipped if reported
duration
audited SHA
```

Do not hide first-run failure or rerun repeatedly until green.

Any unresolved deterministic failure => `NOT ACCEPTED`.

---

# 8. Mandatory Static Analysis

Run:

```bash
cd frontend
fvm flutter analyze --no-pub
```

Required:

```text
No issues found
exit code 0
```

---

# 9. Mandatory Read-Only Format Gate

Run:

```bash
cd frontend
fvm dart format --output=none --set-exit-if-changed lib test integration_test
```

Required:

```text
0 files changed
exit code 0
```

Never use write-format during review.

---

# 10. Mandatory Windows Debug Build

Run in approved Windows-capable environment:

```bash
cd frontend
fvm flutter build windows --debug
```

Required: PASS.

Record artifact path if reported.

If current machine cannot build Windows, Phase 2 remains pending/blocking until
approved Windows evidence exists.

---

# 11. Mandatory Android Debug Build

Run:

```bash
cd frontend
fvm flutter build apk --debug
```

Required: PASS.

Stage 8 materially changes Student and Teacher mobile runtime; Android build
evidence is mandatory.

---

# 12. Stage-Wide Diff Gate

From repo root:

```bash
git diff --check <FRONTEND_BLOCK_DIFF_BASE>...origin/main
git diff --stat <FRONTEND_BLOCK_DIFF_BASE>...origin/main
git diff --name-status <FRONTEND_BLOCK_DIFF_BASE>...origin/main
```

Verify no:

- unrelated backend change;
- dependency/package churn;
- accidental `pubspec.lock`;
- platform churn;
- generated artifacts;
- debug output/secrets;
- broad unrelated format churn;
- weakened tests;
- Stage 9 scoring/result UI.

---

# 13. Architecture Review

Expected architecture remains:

```text
Presentation
-> Application / Riverpod controller
-> Repository contract
-> Repository implementation
-> Remote data source / DTO
-> configured Dio
```

Verify:

- no Widget calls Dio;
- no raw JSON in presentation/application;
- controllers do not construct URLs;
- strict DTOs own parsing;
- one Dio stack;
- one GoRouter;
- one Riverpod architecture;
- no global mutable Blitz/Attempt cache.

Review shared abstractions:

```text
Teacher Question authoring
Teacher Student picker
Student Question domain
Student saved-answer domain/parser
Student answer mutation transport
file picker/transfer
IdempotencyKeyGenerator
timezone/formatters
```

Shared code must remain genuinely shared without merging incompatible
Homework/Blitz lifecycle policy.

---

# 14. Teacher Blitz DTO / Read Audit

Verify FE-001 strict parsing of:

```text
status
assignment
duration
attempt policy
timer snapshot
lifecycle timestamps
Questions
list pagination
```

Required fixed attempt policy:

```text
normalAttempts = 1
maxAdditionalExceptionAttempts = 1
```

Validate lifecycle/timer cross-fields:

```text
Draft      -> no activation snapshot
Scheduled  -> scheduledAt present, no activation
Active     -> activatedAt + timer snapshot
Closed     -> valid activation + closedAt
Archived   -> valid preactivation or post-close archive
```

Synchronized:

```text
synchronizedEndsAt = activatedAt + duration
```

Individual:

```text
synchronizedEndsAt = null
```

Malformed successful data => `invalidResponse`.

---

# 15. Teacher Routing Audit

Expected Stage 8 routes:

```text
/teacher/topics/:topicId/blitz/new
/teacher/topics/:topicId/blitz/:blitzId
/teacher/topics/:topicId/blitz/:blitzId/edit
/teacher/topics/:topicId/blitz/:blitzId/questions
/teacher/topics/:topicId/blitz/:blitzId/monitoring
```

Classifiers must be exact/mutually exclusive.

Verify direct-entry and bootstrap behavior desktop/mobile.

Existing Homework routes must remain unchanged.

---

# 16. Teacher Topic Blitz Section

Verify:

- Topic-scoped server list;
- status filter;
- pagination;
- independent Topic/Blitz loading;
- official chip only from confirmed exact result-pair match;
- no false Practice inference;
- correct desktop/mobile read behavior.

After FE-002/003/006 no visible dead placeholder action may remain.

---

# 17. Builder Audit

Editable fields exactly:

```text
title
description
student instructions
assignment
selected Student IDs
duration seconds
```

Create:

```text
scheduled_at = null
questions = []
```

No Builder control for:

```text
schedule
timer mode
attempt count
status
```

Edit sends changed fields only.

No-op Edit sends no PATCH.

Duration:

```text
1..2147483647
```

No invented 5–10 minute restriction.

---

# 18. Student Picker / Question Builder Audit

Verify one shared Student picker implementation and one shared nine-type Question
authoring system.

Blitz Question editability:

```text
Draft|Scheduled -> editable
Active|Closed|Archived -> read-only
```

Homework behavior remains unchanged.

No per-question timer.

Pair lock alone must not incorrectly block Draft/Scheduled Blitz Question
authoring.

---

# 19. Teacher Mutation Uncertainty Audit

Audit:

```text
Create
Edit
Question mutations
Schedule
official PUT
Activate
Close
Archive
```

General rule:

```text
unknown outcome != blind automatic replay
```

Activation:

```text
one logical operation -> one Idempotency-Key
unknown -> GET current Blitz
explicit Retry -> SAME key
```

Official PUT:

```text
unknown -> GET result pair
exact match proves desired state
```

---

# 20. Schedule / Official Pair Audit

Schedule:

- Institution timezone;
- server future-time authority;
- no device-time eligibility;
- same Scheduled instant is local no-op;
- Draft same instant still POSTs Schedule;
- UI clearly says scheduling does not auto-activate.

Official Blitz:

- pair must already contain official Homework;
- no Blitz-only PUT when pair null;
- current Homework ID always preserved;
- whole-group Draft/Scheduled candidate only;
- locked partial pair with null Blitz side remains fillable;
- populated locked pair not replaceable;
- unlocked populated pair replaceable when otherwise eligible;
- no clear/remove official UI.

---

# 21. Teacher Lifecycle / Mobile Matrix Audit

Desktop final matrix:

```text
Draft      -> Schedule, Activate, eligible Archive, official actions
Scheduled  -> Reschedule, Activate, eligible Archive, official actions
Active     -> Close, Monitor
Closed     -> Archive
Archived   -> read-only
```

Mobile final matrix:

```text
Draft/Scheduled -> Activate
Active          -> Monitor
```

Mobile must NOT expose:

```text
Create
Edit
Questions
Schedule
Official
Close
Archive
exception grant
```

Verify both UI hiding and application/controller action guards.

---

# 22. Student Active Blitz Audit

Exact endpoint:

```text
GET /student/blitz/active
```

No query/pagination.

Active Blitz workspace must be independent from Topic list.

No local reimplementation of server assignment/eligibility.

No Questions in active-list model/UI.

---

# 23. Pre-Start Privacy — Blocking Gate

Before successful Start/Resume, Student Blitz detail must contain no:

```text
Questions
answers
answer_ui
correct-answer data
```

DTO should reject unexpected Question keys.

Widget tests must prove no Question view before Start.

Any pre-Start Question leak => P1.

---

# 24. Student Blitz Route Audit

Canonical route:

```text
/student/topics/:topicId/blitz/:blitzId
```

The same route owns pre-Start detail and post-Start route-session execution.

There must be no invented Blitz Attempt deep-link route.

Opening/reloading route:

```text
GET detail only
NO automatic Start POST
```

This prevents accidental replacement #2 creation.

---

# 25. Start / Resume / Replacement Audit

One endpoint only:

```text
POST /student/blitz/{blitz}/attempts
Idempotency-Key: <uuid>
Content-Type: application/json
```

The body is mandatory and must be one of exactly:

## Normal Start

```json
{"intent":"start_normal"}
```

Requirements:

```text
attempt_id absent
no extra keys
```

Expected semantics:

```text
no #1                    -> 201, create #1
#1 already in_progress   -> 200, same #1
terminal #1              -> 409 attempts_exhausted
never create/switch to #2
```

## Resume exact Attempt

```json
{"intent":"resume","attempt_id":"<canonical-attempt-uuid>"}
```

Requirements:

```text
attempt_id required
no extra keys
```

Expected semantics:

```text
exact own in_progress target -> 200 same target
exact target due             -> 409 blitz_time_expired after canonical reconciliation
exact own terminal target    -> 409 attempt_not_editable
foreign/other Student/Blitz  -> 404 resource_not_found
never create any Attempt
never switch to another Attempt
```

## Replacement Start

```json
{"intent":"start_replacement"}
```

Requirements:

```text
attempt_id absent
no extra keys
```

Expected semantics:

```text
valid unused exception + no #2 -> 201 create #2
valid in_progress #2           -> 200 same #2
no replacement capacity        -> 409 attempts_exhausted or exact owning lifecycle/integrity conflict
never create/resume #1
never create #3
```

Request-shape failures must be:

```text
422 validation_failed
```

for:

```text
missing/empty/{} body
unknown intent
unknown key
resume without attempt_id
attempt_id on start_normal
attempt_id on start_replacement
malformed Resume attempt_id
```

UI mapping:

```text
normal unused       -> Start Blitz -> start_normal
in-progress         -> Resume Blitz -> resume + exact Attempt ID
replacement granted -> Start additional attempt -> start_replacement
```

Attempt #2 must never be called a second normal attempt.

Returned Attempt is authoritative.

Questions become visible only after a strictly valid Start/Resume/replacement
response.

---

# 26. Immutable Start Request / Replay Audit — Critical

FE-004/FE-005 use one immutable request value equivalent to:

```text
StudentBlitzAttemptRequest {
  intent,
  attemptId?,
  idempotencyKey
}
```

Audit the private distinction:

```text
_pendingRequest
_completedStartRequest
```

## Pending unknown outcome

Retry resends exactly the same:

```text
intent
attemptId?
Idempotency-Key
```

No intent recomputation.

## Successful Start/Resume/replacement-Start

The execution handoff atomically retains:

```text
authoritative returned Attempt
+
exact immutable request that produced it
```

as the route-session completed replay context.

Do not reduce completed context to only the key.

## Current-Attempt reconciliation

Every recovery path replays the exact completed immutable request:

```text
uncertain answer check
uncertain file check
Submit current-state check
timeout reconciliation
task-close reconciliation
attempt_not_editable reconciliation
terminal reconciliation
```

For replay:

```text
start_normal      -> exact same body + key
resume            -> exact same body + exact same attempt_id + key
start_replacement -> exact same body + key
```

Never infer replay intent from:

```text
current Attempt number
current Attempt status
fresh Blitz detail
replacement availability
current lifecycle
```

Never generate a new Start key merely to re-read the current Attempt.

A key-only replay implementation, changed body, changed Resume target, intent
switch or recovery-created replacement is blocking.

Verify explicit recovery coverage for:

```text
normal Start
Resume #1
Resume #2
replacement Start
```

---

# 27. No Unsafe Blitz Attempt GET

Backend has no Blitz Attempt GET.

Verify Stage 8 frontend does not invent:

```text
GET /student/attempts/{attempt}
```

for Blitz.

Homework's existing Attempt GET remains valid for Homework.

Blitz answer/file/Submit reconciliation uses the exact completed immutable Start request only.

---

# 28. Blitz Attempt DTO Audit

Attempt numbers:

```text
1..2
```

Statuses:

```text
in_progress
submitted
timed_out_finalized
waiting_for_teacher_review
checked
```

Reasons:

```text
student_submit
timeout_auto_submit
task_closed_auto_finalize
```

Reject Homework deadline reason.

Verify lifecycle timestamp invariants and exact timing remaining.

No score/checking fields.

---

# 29. Countdown Authority Audit

Countdown anchor:

```text
server remaining_seconds
+
Stopwatch elapsed
```

Verify no authoritative:

```text
deadlineAt.difference(DateTime.now())
```

and no device timezone authority.

Verify:

- rebuild does not reset countdown;
- delayed event-loop pump correctly reduces by elapsed duration;
- newer server snapshot re-anchors;
- synchronized pre-Start normal countdown;
- individual pre-Start no countdown;
- replacement pre-Start no effective countdown;
- #2 uses returned Attempt timing.

---

# 30. Countdown Zero Audit

At local zero:

```text
disable new writes
do not finalize locally
do not auto-save
do not auto-upload
do not auto-submit
reconcile server state
```

An already in-flight request may complete after local zero; backend result wins.

Network failure after zero must not restore old time/edit authority.

---

# 31. Answer / File Audit

All eight non-file editors reused.

No autosave.

Uncertain answer PUT:

```text
NO blind PUT replay
completed Start replay -> authoritative current Attempt
```

File upload:

- shared picker/transport;
- safe extensions/effective max size;
- no blind uncertain upload retry;
- metadata match alone cannot prove selected bytes committed;
- protected current file Open/Save As only from authoritative current answer.

No storage path leak.

---

# 32. Submit Readiness / Submit Audit

Submit blockers must include:

```text
dirty/unsaved non-file
save in flight
save uncertain
selected file pending
upload in flight
upload uncertain
local expiry/reconciliation
Attempt not in_progress
publication/editor mismatch
route operation busy
session mismatch
```

Unanswered Questions must **not** block Submit.

Confirmation shows answered/unanswered counts.

Submit:

```text
POST /student/attempts/{attempt}/submit
Idempotency-Key
{}
```

Unknown => same-key Retry.

Strict success must prove `student_submit`.

---

# 33. Submit Terminal Reconciliation Audit

`Check current attempt` uses completed Start replay key.

Expected outcomes:

```text
in_progress         -> Submit still uncertain
student_submit      -> terminal submitted
timeout_auto_submit -> time expired
task_closed         -> close-finalized
waiting/checked     -> terminal read-only
```

Late Submit `blitz_time_expired` must never be shown as Submit success.

No Stage 8 `submission_locked`.

No score/checking UI.

---

# 34. Leave / Resume Audit

Verify leave guards for:

```text
Submit in-progress
Submit uncertain
dirty draft
selected file
uncertain answer
uncertain upload
```

Leave sends no mutation; timer continues.

Return path:

```text
detail -> explicit Resume -> authoritative full Attempt
```

No offline restoration of dirty local work.

---

# 35. Teacher Monitoring Privacy / State Audit

Monitoring must never expose:

```text
Questions
answers
files
score
checking details
feedback
```

Response `score` must be validated null/discarded.

Summary:

```text
assigned = notStarted + inProgress + finalized + waitingForTeacherReview
```

Student count and exception count must match summary.

Exception grant but #2 not started:

```text
operational status = not_started
attempt number = null
```

After #2 starts:

```text
Attempt 2 is current
```

---

# 36. Monitoring Polling Audit

Cadence:

```text
5 seconds
```

Verify:

- one Timer/controller;
- no Timer per Student;
- no overlapping GET;
- foreground/current-route only;
- app pause stops polling;
- resume refreshes;
- route leave stops;
- transient failures retain stale snapshot;
- no Snackbar spam;
- 429 pauses until explicit Retry;
- closed/archived/not-active/404 stops polling.

Do not locally finalize Student rows at remaining=0.

---

# 37. Exception Grant Audit

Desktop only.

Request:

```text
technical | other_valid
trimmed non-empty reason <= 4000
Idempotency-Key
```

No score-based eligibility.

No revoke/edit/second grant.

Unknown:

```text
same-key Retry
or Check monitoring
```

Polling pauses while grant mutation owns route.

Success triggers monitoring refresh; frontend does not fabricate replacement #2.

---

# 38. Mobile Monitoring Audit

Mobile basic monitoring may show:

```text
Student name
operational status
Attempt 1 / Additional attempt
remaining snapshot
terminal reason
exception-granted badge
```

Must not show:

```text
exception reason text
grant button
answers/files
score
```

No primary wide table/horizontal-overflow UX.

---

# 39. Session / Stale Async Audit

Review ownership factors across all Stage 8 controllers:

```text
TeacherSessionKey
StudentSessionKey
Topic/Blitz route target
Attempt/execution target
Student/Question ID
publication token
mutation lease
request generation
pending key
completed Start replay key
countdown anchor
monitoring route/app lifecycle
```

Verify stale completion cannot publish/navigate/show feedback into another
session/target.

Terminal publication must retire obsolete editor/file/Submit work.

Old countdown callbacks and monitoring poll completions must not affect newer
targets.

---

# 40. Shared Stage 6 / 7 Regression Audit

Stage 8 shared refactors must not regress:

## Teacher Homework

```text
Student picker
Question builder
result-pair setOfficialHomework
official Homework UX
Homework routes
Topic open-assessment feedback
```

## Student Homework

```text
Student Question DTO
saved-answer parser
answer PUT
file upload/transfer
Submit readiness/controller
Homework Attempt GET
Homework route
IdempotencyKeyGenerator
```

Critical:

```text
Homework keeps valid GET Attempt recovery.
Blitz uses completed Start replay.
```

Do not merge these into one wrong recovery policy.

---

# 41. Topic Open-Assessment Integration

User-facing conflict copy must now include:

```text
Homework and Blitz
```

not Homework only.

Topic close/archive conflict must refresh/invalidate relevant child read state
without mutating children.

---

# 42. API Error-Code Audit

Review Stage 8 machine codes, including:

```text
task_not_active
task_closed
task_archived
topic_not_editable
topic_has_open_assessments
business_conflict
official_task_requires_group_assignment
result_pair_locked
assessment_has_no_scoreable_points
assessment_not_assigned
institution_settings_incomplete
official_cohort_mismatch
blitz_not_active
blitz_time_expired
attempts_exhausted
attempt_not_editable
idempotency_key_reused
blitz_attempt_exception_not_allowed
blitz_attempt_exception_already_granted
blitz_normal_attempt_required
selection_limit_exceeded
file_upload_failed
resource_not_found
validation_failed
rate_limited
```

Verify no human-message branching and no duplicate constants.

Blitz must not use Homework `deadline_passed` as its normal execution timeout
code.

---

# 43. Accessibility / Responsive Audit

Teacher surfaces:

```text
Blitz cards
Builder
Question editor
lifecycle confirmations
monitoring
exception dialog
```

Student surfaces:

```text
Active Blitz
Start confirmations
countdown
answer editors
file progress
Submit confirmation
terminal summary
```

Verify:

- semantic headers/actions;
- progress semantics;
- keyboard traversal desktop;
- validation focus;
- state not color-only;
- no screen-reader announcement every countdown second or poll;
- long text wraps;
- narrow mobile no overflow.

---

# 44. Timer / Resource Cleanup Audit

Audit:

```text
Student countdown Timer/Stopwatch
Teacher monitoring Timer
AppLifecycleListener/WidgetsBindingObserver
```

Verify:

- no duplicate Timer after rebuild;
- dispose/route leave cleanup;
- no background polling;
- old countdown expiry cannot affect new Attempt;
- countdown anchor not reset by ordinary rebuild.

---

# 45. Performance / Request Churn Audit

Verify no:

- active Blitz request per Topic;
- monitoring request per Student;
- one-second network countdown polling;
- autosave request storm;
- Start POST merely to render pre-Start detail;
- infinite refresh loop after terminal/429/conflict;
- unnecessary duplicate full reads after strict authoritative mutation success.

Do not optimize by weakening authority/security.

---

# 46. Security Search

Search Stage 8 Student/monitoring code for prohibited leak concepts:

```text
is_correct
correct_value
accepted_answers
correct_position
match_key
checking_status
awarded_points
earned_points
normalized_score
storage_key
storage_disk
checksum_sha256
```

Teacher Question authoring may legitimately contain answer configuration;
Student transport/presentation and Teacher monitoring must not.

Any answer-key/private-answer/score leak => P1.

---

# 47. Test Quality Review

Inspect tests, not only pass counts.

Require meaningful coverage for:

```text
strict DTO
unknown keys
routing
desktop/mobile capability
session/stale async
same-key idempotency
exact Start intent/body/fingerprint replay
Resume exact-attempt/no-switch behavior
completed immutable Start request handoff
mutation uncertainty
pre-Start privacy
countdown fake time
replacement #2
answer/file recovery
Submit races
monitoring polling/429
grant idempotency
Stage 6/7 regressions
responsive/accessibility
```

Flag real sleeps where fake/pump time should be used.

Do not accept weakened assertions that only prove a Widget exists when behavior
is the requirement.

---

# 48. Final Git State

After all verification:

```bash
git branch --show-current
git rev-parse HEAD
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
git status --short
```

Required:

```text
main
HEAD == origin/main
0/0
clean
```

---

# 49. Focused Fix Workflow

If finding exists:

1. ChatGPT records exact evidence/severity;
2. Phase 2 verdict `NOT ACCEPTED`;
3. ChatGPT creates one focused fix contract;
4. Codex implements only that fix;
5. Project Owner delivers to `main`;
6. ChatGPT reviews new current `main`;
7. rerun only invalidated evidence.

Shared router/session/DTO/execution fixes normally invalidate broad frontend
suite/analyze/build evidence.

Small isolated copy/test fixes may not, but ChatGPT must explicitly decide.

---

# 50. PASS Conditions

PASS only when:

```text
S08-FE-001…006 delivered on audited main

P1 = 0
P2 = 0

architecture PASS
Teacher read/builder PASS
Teacher lifecycle/result-pair PASS
mobile capability PASS

Student pre-Start privacy PASS
Start/immutable-completed-request PASS
Attempt DTO PASS
countdown authority PASS
answer/file PASS
Submit/terminal PASS

monitoring privacy/state/polling PASS
exception grant PASS

Stage 6/7 regressions PASS

full flutter test PASS
flutter analyze PASS
read-only format PASS
Windows debug build PASS
Android debug build PASS
Stage-wide git diff --check PASS
final Git state clean/synchronized
```

Task-level focused PASS alone is insufficient.

---

# 51. NOT ACCEPTED Conditions

Return:

```text
S08-FE-PHASE-2: NOT ACCEPTED
```

for any:

- unresolved P1/P2;
- deterministic full-suite failure;
- analyzer/format/build failure;
- security/privacy defect;
- lifecycle/state mismatch;
- unsafe idempotency/recovery behavior;
- mobile capability overreach;
- missing accepted delivery;
- dirty/divergent Git state preventing authoritative audit.

Do not proceed to Integration.

---

# 52. Final Report Template

```text
Stage 8 Frontend Phase 2

Audited main: <sha>
Frontend diff base: <sha>

Git:
main == origin/main
ahead/behind = 0/0
clean = yes

Task delivery:
S08-FE-001: <PR/SHA>
S08-FE-002: <PR/SHA>
S08-FE-003: <PR/SHA>
S08-FE-004: <PR/SHA>
S08-FE-005: <PR/SHA>
S08-FE-006: <PR/SHA>

Verification:
flutter test: <PASS/FAIL + count/duration>
flutter analyze --no-pub: <PASS/FAIL>
dart format check: <PASS/FAIL + files checked>
Windows debug build: <PASS/FAIL>
Android debug build: <PASS/FAIL>
git diff --check: <PASS/FAIL>

Read-only review:
Architecture: <PASS/findings>
Teacher read/builder: <PASS/findings>
Teacher lifecycle/result pair: <PASS/findings>
Mobile Teacher capability: <PASS/findings>
Student pre-Start privacy: <PASS/findings>
Start/immutable request replay: <PASS/findings>
Countdown: <PASS/findings>
Answer/file: <PASS/findings>
Submit/terminal: <PASS/findings>
Monitoring: <PASS/findings>
Exception grant: <PASS/findings>
Routing/session/stale async: <PASS/findings>
Stage 6/7 regressions: <PASS/findings>
Scope/diff: <PASS/findings>

Findings:
P1 = <n>
P2 = <n>
P3 = <n>

Verdict:
PASS | NOT ACCEPTED

If PASS:
Next required activity = ChatGPT re-checks current main and S08-INT-001 readiness
Integration release = after ChatGPT confirms both Phase 2 PASS records and current readiness
```

Do not paste enormous passing logs.

---

# 53. Exit Gate

A Frontend Phase 2 PASS does **not** directly authorize integration.

After:

```text
S08-FE-PHASE-2 = PASS
```

with Backend Phase 2 PASS still valid, ChatGPT must:

1. re-check current `origin/main`;
2. confirm both Phase 2 PASS records remain valid;
3. revalidate `S08-INT-001` against delivered dependencies and the directly
   relevant implementation/tests;
4. record current readiness as `Approved` and release only that integration
   contract to Codex.

The integration contract's harness/preflight requirements remain mandatory.
ChatGPT performs Integration Harness Preflight after harness delivery and before
the first full real-stack runner.

Codex receives the approved self-contained contract and must not inspect Stage
history or the INDEX to infer implementation requirements or readiness.

Frontend Phase 2 PASS does **not** close Stage 8.

Still required:

```text
ChatGPT current-main/readiness review of S08-INT-001
S08-INT-001 Accepted / Delivered / PASS
required integration fixes
ChatGPT verifies closure entry conditions on current main
STAGE_08_CLOSURE_REVIEW
```

---

# 54. Checkpoint Readiness Verdict

```text
Review type                         = READ-ONLY BLOCK CHECKPOINT
Entry gate                          = DEFINED
Frontend diff base                  = DEFINED
Full test suite                     = DEFINED
Full static analysis                = DEFINED
Read-only format check              = DEFINED
Windows debug build                 = DEFINED
Android debug build                 = DEFINED
Stage-wide diff gate                = DEFINED

Teacher read/builder audit          = DEFINED
Teacher lifecycle/result-pair audit = DEFINED
Mobile capability audit             = DEFINED

Student privacy audit               = DEFINED
Start/immutable-request audit       = DEFINED
Countdown audit                     = DEFINED
Answer/file audit                   = DEFINED
Submit/terminal audit               = DEFINED

Monitoring audit                    = DEFINED
Exception-grant audit               = DEFINED

Session/stale async audit           = DEFINED
Stage 6/7 regression audit          = DEFINED
Accessibility/responsive audit      = DEFINED
Severity/verdict rules              = DEFINED
Focused fix workflow                = DEFINED

Checkpoint contract readiness       = PASS
Execution state                     = BLOCKED until S08-FE-001…006 are Accepted / Delivered on origin/main
Next gate after checkpoint PASS      = ChatGPT current-main/readiness review of S08-INT-001
Integration release                 = both Phase 2 PASS records valid + current ChatGPT readiness approval
```
