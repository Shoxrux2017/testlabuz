# Codex Implementation Contract: S08-FE-006 — Teacher Live Monitoring, Attempt Exception and Mobile Runtime

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-FE-006` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter Teacher active-Blitz monitoring + one-Student attempt exception UX + mobile Activate/basic monitoring` |
| Depends on | `S08-FE-001…005 Accepted / Delivered`; `S08-BE-PHASE-2 = PASS` remains valid |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Runtime implementation baseline | ChatGPT must re-check/freeze current `origin/main` immediately before Codex execution |
| Backend API dependency | Final delivered Stage 8 monitoring + attempt-exception + activation APIs after Backend Phase 2 PASS |
| Flutter toolchain | Use the repository's current FVM-pinned Flutter version at implementation time |
| Implementation Readiness Gate | `PASS — planning contract`; execution remains dependency-gated |
| Verification | `Codex — focused frontend verification only` |
| Delivery execution | `Project Owner` |
| Frontend block checkpoint | `S08-FE-PHASE-2` immediately after this task is `Accepted / Delivered` |
| Blocks | `S08-FE-PHASE-2` |

Do not start until:

```text
S08-FE-001…005 = Accepted / Delivered
S08-BE-PHASE-2 = PASS
current origin/main re-checked
final Teacher monitoring/exception/activation APIs inspected
current FE-003 lifecycle controller/detail integration inspected
current Teacher router/mobile destination rules inspected
clean synchronized local main
```

If delivered dependencies materially conflict with this contract, return:

```text
BLOCKED
```

with exact evidence.

Do not invent new Teacher/Student execution APIs or broaden the approved mobile
capability.

This file is the complete task-specific implementation contract.

Do **not** create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this implementation contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. delivered S08-FE-001…005 source/tests directly required here;
5. final delivered Stage 8 monitoring/exception/activation backend routes/resources directly required to confirm the API already encoded below;
6. current Teacher router/session/device/lifecycle/idempotency implementation;
7. current reusable Teacher read/detail/list formatting/error infrastructure.

Do **not** read:

- product docs;
- roadmap;
- previous Stage 8 task files;
- Stage history;
- checkpoint reviews;
- closure reviews;
- unrelated features

to determine requirements.

This contract resolves:

- monitoring route;
- desktop/mobile monitoring capability;
- strict monitoring DTO/domain;
- operational Student state projection;
- 5-second foreground polling;
- polling lifecycle;
- timeout-reconciled server snapshot trust;
- summary/student presentation;
- desktop exception visibility;
- grant eligibility hint;
- exception reason form;
- grant Idempotency-Key lifetime;
- grant uncertain outcome reconciliation;
- mobile Activate extension;
- mobile activation warning/official-state context;
- router/bootstrap/mobile rules;
- same-route mutation integration;
- privacy/no-score/no-answer boundary;
- accessibility/responsiveness;
- focused verification.

---

# 3. Goal

Complete Stage 8 Teacher runtime UX.

The Teacher must be able to:

## Desktop

- open an Active Blitz monitoring screen;
- see live server-refreshed summary counts;
- see every persisted assigned Student's operational state;
- see Attempt #1/#2 runtime status and remaining time;
- see granted exception metadata;
- grant exactly one approved additional Attempt to an eligible Student;
- safely recover from uncertain grant responses;
- continue to use FE-003 lifecycle controls from Blitz detail.

## Mobile

- view Blitz detail;
- activate an eligible Draft/Scheduled Blitz;
- open basic Active Blitz monitoring;
- see summary and Student operational status;
- perform no authoring/scheduling/designation/close/archive/exception mutation.

This task is the final Stage 8 frontend implementation task.

It does **not** add result/scoring/review functionality.

---

# 4. Approved Surface Matrix

The final Stage 8 Teacher capability matrix must be:

| Capability | Desktop | Mobile |
|---|---:|---:|
| Read Topic/Blitz | Yes | Yes |
| Create Blitz | Yes | No |
| Edit metadata | Yes | No |
| Manage Questions | Yes | No |
| Schedule/Reschedule | Yes | No |
| Official designation | Yes | No |
| Activate | Yes | **Yes** |
| Close | Yes | No |
| Archive | Yes | No |
| Monitoring read | **Yes** | **Yes — basic** |
| Grant Student exception | **Yes** | No |
| Check/score/review answers | No | No |

Do not expand mobile beyond this table.

---

# 5. Backend Monitoring API

Use configured Dio base:

```text
/api/v1
```

Endpoint:

```text
GET /teacher/blitz/{blitzId}/monitoring
```

No query.

No request body.

Success:

```text
200 OK
```

Monitoring is valid only while:

```text
Blitz.status = active
```

Known lifecycle failures:

```text
409 task_not_active
409 task_closed
409 task_archived
404 resource_not_found
```

The backend performs authoritative timeout reconciliation before returning
monitoring state.

Frontend must not attempt its own timeout transitions.

---

# 6. Monitoring Success Contract

Exact top-level envelope:

```json
{
  "data": {
    "blitz": {},
    "summary": {},
    "students": []
  }
}
```

No:

```text
message
meta
pagination
links
```

Strictly parse all nested structures.

---

# 7. Monitoring Blitz Domain

Create:

```text
TeacherBlitzMonitoringBlitz
```

Fields:

```text
id
status
durationSeconds
activatedAt
timing
```

Require:

```text
id canonical UUID
id == target.blitzId
status == active
durationSeconds >= 1
activatedAt non-null UTC whole-second timestamp
```

The monitoring payload intentionally contains no `topic_id`.

Therefore it is **not sufficient by itself** to prove that the route:

```text
/teacher/topics/{topicId}/blitz/{blitzId}/monitoring
```

represents the correct Topic/Blitz relationship.

Before any monitoring response may be published, Section 26 requires a confirmed
FE-001 Blitz detail identity:

```text
detail.id == target.blitzId
detail.topicId == target.topicId
```

No title is required here; after that identity guard succeeds, use the same
confirmed FE-001 detail resource for screen title/context.

---

# 8. Monitoring Timing Domain

Create:

```text
TeacherBlitzMonitoringTiming
```

Fields:

```text
mode: TeacherBlitzTimerStartMode
synchronizedEndsAt?
serverNow
```

Reuse FE-001:

```text
TeacherBlitzTimerStartMode
```

Do not create another timer-mode enum.

Require:

## Synchronized

```text
synchronizedEndsAt != null
```

## Individual

```text
synchronizedEndsAt = null
```

`serverNow` is authoritative request snapshot time.

Do not use device time for business state.

---

# 9. Monitoring Summary Domain

Create:

```text
TeacherBlitzMonitoringSummary
```

Fields:

```text
assigned
notStarted
inProgress
finalized
waitingForTeacherReview
attemptExceptionsGranted
```

Every field:

```text
int >= 0
```

Require:

```text
assigned
==
notStarted
+ inProgress
+ finalized
+ waitingForTeacherReview
```

No score counts.

No answer counts.

---

# 10. Monitoring Student Status Enum

Create:

```text
TeacherBlitzMonitoringStudentStatus
```

Exact values:

```text
notStarted              -> not_started
inProgress               -> in_progress
finalized                -> finalized
waitingForTeacherReview  -> waiting_for_teacher_review
```

Do not expose backend raw Attempt persistence status through this field.

Unknown value:

```text
FormatException
```

---

# 11. Monitoring Student Identity

Create:

```text
TeacherBlitzMonitoringStudentIdentity
```

Exact fields:

```text
id
fullName
```

Require:

```text
canonical UUID
non-blank fullName
```

Do not parse/display:

```text
email
login
phone
institution
account active flag
```

---

# 12. Monitoring Finalization Reason

Create:

```text
TeacherBlitzMonitoringFinalizationReason
```

Exact values:

```text
studentSubmit -> student_submit
timeout       -> timeout_auto_submit
taskClosed    -> task_closed_auto_finalize
```

Do not accept:

```text
homework_deadline_auto_submit
```

for Blitz.

---

# 13. Attempt Exception Reason Type

Create/reuse:

```text
TeacherBlitzAttemptExceptionReasonType
```

Exact:

```text
technical
otherValid -> other_valid
```

Presentation labels:

```text
Technical problem
Other valid reason
```

Machine values remain explicit.

---

# 14. Monitoring Exception Domain

Create:

```text
TeacherBlitzMonitoringAttemptException
```

Fields:

```text
id
invalidatedAttemptId
replacementAttemptId?
reasonType
reason
grantedAt
replacementAttemptAvailable
```

Require canonical UUIDs.

Reason:

```text
trimmed non-blank
<= 4000 Unicode characters
```

`grantedAt` UTC whole-second.

---

# 15. Monitoring Exception Cross-Invariants

Because monitoring endpoint is Active-only:

## Unused replacement

```text
replacementAttemptId = null
replacementAttemptAvailable = true
```

## Replacement already started

```text
replacementAttemptId != null
replacementAttemptAvailable = false
```

Reject:

```text
replacementAttemptId = null
replacementAttemptAvailable = false
```

for a valid Active monitoring response.

Do not infer class timer eligibility.

Backend already applied BE-009 semantics.

---

# 16. Monitoring Student Domain

Create:

```text
TeacherBlitzMonitoringStudent
```

Fields:

```text
student
status
attemptNumber?
startedAt?
deadlineAt?
remainingSeconds?
finalizationReason?
attemptException?
```

Do **not** include a score domain field.

The response contains:

```text
score
```

only so Stage 8 frontend can validate that it is exactly:

```text
null
```

---

# 17. Student Exact Keys

Require exactly:

```text
student
status
attempt_number
started_at
deadline_at
remaining_seconds
finalization_reason
score
attempt_exception
```

Require:

```text
score == null
```

Any non-null score in Stage 8 monitoring:

```text
FormatException
```

Do not silently expose it.

---

# 18. `not_started` Invariant

For:

```text
status = not_started
```

require:

```text
attemptNumber = null
startedAt = null
deadlineAt = null
finalizationReason = null
```

Remaining:

## Synchronized normal path, no exception

May be:

```text
int >= 0
```

from class common timer.

## Individual normal path

```text
null
```

## Unused exception replacement path

Require:

```text
attemptException != null
attemptException.replacementAttemptAvailable = true
remainingSeconds = null
```

Do not show historical invalidated #1 as current Attempt.

---

# 19. `in_progress` Invariant

Require:

```text
attemptNumber in {1,2}
startedAt != null
deadlineAt != null
deadlineAt > startedAt
remainingSeconds != null
remainingSeconds >= 0
finalizationReason = null
```

If:

```text
attemptNumber == 2
```

require:

```text
attemptException != null
attemptException.replacementAttemptId != null
replacementAttemptAvailable = false
```

If #1:

exception normally absent.

Do not reject a server-valid future shape solely because an exception object is
present, but any contradiction with replacement ID/number is invalid.

---

# 20. `finalized` Invariant

Require:

```text
attemptNumber in {1,2}
startedAt != null
deadlineAt != null
remainingSeconds == 0
finalizationReason != null
```

Attempt #2 requires linked exception metadata.

Attempt #1 may have no exception and be a grant candidate.

---

# 21. `waiting_for_teacher_review` Invariant

Require:

```text
attemptNumber in {1,2}
startedAt != null
deadlineAt != null
remainingSeconds == 0
finalizationReason != null
```

This monitoring status remains compatible with future checking flow.

Stage 8 UI still shows:

```text
score = null
```

No review action.

---

# 22. Student List Integrity

Require:

- Student IDs unique;
- each row valid;
- returned order preserved;
- no client re-sort required;
- `students.length == summary.assigned`;
- counted statuses exactly equal summary buckets;
- number of non-null exceptions exactly equals:
  ```text
  summary.attemptExceptionsGranted
  ```

If summary and rows disagree:

```text
invalidResponse
```

Do not display inconsistent dashboard counts.

---

# 23. Monitoring DTO

Create strict:

```text
TeacherBlitzMonitoringDto
```

Expected `data` keys:

```text
blitz
summary
students
```

Nested exact keys as defined above.

Convert to immutable domain.

Unknown/missing success keys:

```text
FormatException
```

Data-source layer maps malformed 2xx to:

```text
ApiFailureKind.invalidResponse
```

---

# 24. Monitoring Repository / Data Source

Extend the delivered:

```text
TeacherBlitzRepository
TeacherBlitzRemoteDataSource
```

with:

```dart
Future<TeacherBlitzMonitoring> fetchMonitoring(String blitzId);
```

Do not create direct Dio in controller/widget.

A focused separate monitoring DTO file is expected.

---

# 25. Monitoring HTTP Construction

Call:

```dart
dio.get<Object?>(
  '/teacher/blitz/${Uri.encodeComponent(blitzId)}/monitoring',
  options: Options(followRedirects: false),
)
```

No query/body.

Require:

```text
200
```

Strict parse.

No HTTP retry interceptor/loop specific to monitoring.

Polling controller owns repeated reads.

---

# 26. Monitoring Route and Mandatory Topic/Blitz Identity Guard

Add:

```text
AppRouteNames.teacherBlitzMonitoring
```

Nested under:

```text
teacherBlitzDetail
```

Canonical path:

```text
/teacher/topics/:topicId/blitz/:blitzId/monitoring
```

Add:

```text
teacherBlitzMonitoringSegment = 'monitoring'
teacherBlitzMonitoringLocation(topicId, blitzId)
isTeacherBlitzMonitoringPath(path)
```

This is a **read/runtime route**, not an authoring route.

Register with:

```text
_buildTeacherDestination(
  TeacherBlitzMonitoringScreen(...),
  authoring: false,
)
```

Therefore supported on:

```text
desktop
mobile
```

## 26.1 Nested routing is not relationship authorization

Do **not** assume that the nested GoRouter path proves:

```text
Blitz belongs to route Topic
```

The monitoring backend route is Blitz-ID based and its response contains no
Topic ID.

The frontend must therefore establish one mandatory route-parent identity guard
from FE-001 detail before monitoring becomes usable.

Use the existing:

```text
teacherBlitzDetailControllerProvider(target)
```

or a narrow reusable identity projection over it.

Confirmed identity is exactly:

```text
detail.id == target.blitzId
AND
detail.topicId == target.topicId
```

## 26.2 Identity guard states

Conceptually expose:

```text
checking
confirmed
notFound
error
```

Rules:

### checking

- no monitoring GET publication;
- no Grant action;
- show loading/current safe verification UI.

### confirmed

Only now may monitoring GET/polling and grant eligibility proceed.

### notFound

Use when:

- FE-001 detail returns privacy-safe `404 resource_not_found`; or
- an otherwise returned detail does not match the route Topic/Blitz identity.

Required route state:

```text
notFound
```

Do not publish independently fetched monitoring data.

Do not show Grant.

Do not reveal that a different Topic owns the Blitz.

### error

For transient/unconfirmed FE-001 detail failure:

- do not fall back to independent monitoring;
- do not show Grant;
- show safe Retry for the parent/detail verification.

A transport failure is not proof of relationship mismatch.

## 26.3 Direct-entry requirement

This guard is mandatory for:

```text
desktop direct entry
mobile direct entry
normal navigation from Blitz detail
auth/bootstrap restored route
```

It is not optional merely because a previous screen once displayed the Blitz.

---

# 27. Exact Route Classification

After FE-006:

```text
isTeacherBlitzDetailPath(path)
```

must remain exact for:

```text
/teacher/topics/<topic>/blitz/<blitz>
```

and return false for:

```text
.../monitoring
```

Add exact monitoring classifier.

Update:

```text
teacherTopicIdFromPath
teacherBlitzIdFromPath
isTeacherApprovedLocation
```

as needed.

Do not weaken existing Create/Edit/Questions route distinctions.

---

# 28. Mobile Router / Bootstrap Integration

A valid monitoring route must survive:

```text
auth bootstrap
mobile Teacher redirect validation
direct entry
```

Update current mobile Teacher route whitelist so:

```text
Teacher Topic detail
Teacher Homework detail
Teacher Blitz detail
Teacher Blitz monitoring
```

are valid mobile destinations after Stage 8.

Existing desktop-only authoring paths still redirect to their supported read
location.

Do not make:

```text
Blitz Create
Blitz Edit
Blitz Questions
Topic Edit
Homework Edit
Homework Questions
```

mobile-authorized.

---

# 29. Monitoring Screen

Create:

```text
TeacherBlitzMonitoringScreen
```

Input:

```text
TeacherBlitzRouteTarget
```

App bar:

```text
Blitz Monitoring
```

Back:

```text
Back to Blitz
```

using canonical detail route.

Supported:

```text
desktop
mobile
```

---

# 30. Monitoring Controller

Create autoDispose family:

```text
teacherBlitzMonitoringControllerProvider(target)
TeacherBlitzMonitoringController
TeacherBlitzMonitoringState
```

Target:

```text
TeacherBlitzRouteTarget
```

Observe:

```text
Teacher session/device surface
teacherBlitzDetailControllerProvider(target)
```

or an equivalent narrow confirmed-identity projection.

Both:

```text
desktop
mobile
```

are eligible only after Section 26 confirms the exact Topic/Blitz identity.

---

# 31. Monitoring State

Statuses:

```text
initial
loading
data
refreshing
error
notFound
notActive
closed
archived
```

State fields:

```text
monitoring?
failure?
isStale
livePollingEnabled
pollingPausedByRateLimit
lastRefreshWasAutomatic
```

Do not duplicate full FE-001 Blitz detail resource inside monitoring state.

---

# 32. Initial Monitoring Load

On eligible session/target, first resolve/observe the Section 26 FE-001 parent
identity guard.

## Parent identity checking

Do not issue/publish monitoring GET yet.

State may remain:

```text
loading
```

with safe parent-context verification UI.

## Parent identity confirmed

Only after:

```text
detail.id == target.blitzId
detail.topicId == target.topicId
```

perform the initial monitoring GET.

On monitoring success additionally require:

```text
monitoring.blitz.id == target.blitzId
```

Then publish:

```text
data
```

Start polling only after:

- parent identity remains confirmed;
- route screen has enabled foreground live mode;
- no mutation active.

## Parent notFound / identity mismatch

Transition monitoring controller to:

```text
notFound
```

without publishing monitoring data.

If a monitoring request was already in flight from an earlier confirmed
generation, invalidate/ignore its completion.

## Parent transient error/unconfirmed

Do not independently fetch/publish monitoring as a fallback.

Keep Grant unavailable and expose parent verification Retry.

Do not poll a provider that is merely instantiated in a test/offstage context
without route ownership.

---

# 33. Live Polling Cadence

Use:

```text
5 seconds
```

fixed MVP polling cadence.

No WebSocket/SSE.

No new package.

One controller Timer only.

Do not create one Timer per Student.

---

# 34. Polling Non-Overlap

If a monitoring request is already active when a 5-second tick occurs:

```text
skip that tick
```

Do not queue requests.

Do not cancel the in-flight GET solely because the next tick arrived.

Manual Refresh may cancel/obsolete an older generation according to controller
conventions, but must not create overlapping publication races.

---

# 35. Foreground Polling Ownership

Create controller methods equivalent to:

```text
enterLiveRoute()
leaveLiveRoute()
setAppResumed(bool)
```

Polling runs only when all are true:

```text
route owned/current
Teacher session eligible
Topic/Blitz parent identity currently confirmed
app lifecycle resumed
screen not in terminal monitoring state
not paused by rate limit
no exception-grant mutation currently owns the monitoring route
```

If the FE-001 parent detail becomes `notFound`, mismatched, or otherwise loses
confirmed identity, stop polling immediately and invalidate any later monitoring
publication from the older confirmed generation.

---

# 36. App Lifecycle

Use Flutter SDK only.

`TeacherBlitzMonitoringScreen` may use:

```text
AppLifecycleListener
```

or a narrow `WidgetsBindingObserver`.

Behavior:

## resumed

- enable polling;
- trigger immediate refresh if current data may be stale.

## inactive / paused / hidden / detached

- stop periodic polling;
- do not clear current monitoring data.

No background polling.

No background service.

---

# 37. Route Disposal

On monitoring screen leave/dispose:

- stop Timer;
- invalidate publication generation;
- no late GET/grant completion may show feedback on another route.

AutoDispose alone is not the only ownership check; preserve session/target
generation safety.

---

# 38. Manual Refresh

Available desktop/mobile.

If current data exists:

```text
refreshing
retain current data
```

On success replace snapshot.

On failure retain current data:

```text
error
isStale = true
```

Do not clear usable monitoring snapshot for a transient network error.

---

# 39. Automatic Poll Failure

For transient:

```text
connection
timeout
5xx
unknown
invalidResponse
```

retain last valid snapshot if one exists.

Mark:

```text
stale
```

Allow next 5-second tick to try again unless rate-limited.

Do not show a Snackbar every 5 seconds.

Use one visible stale banner:

```text
Live monitoring may be out of date.
```

---

# 40. Rate Limit

If:

```text
429 rate_limited
```

during automatic/manual monitoring read:

- retain current snapshot;
- set:
  ```text
  pollingPausedByRateLimit = true
  ```
- stop periodic reads;
- show:
  ```text
  Live updates are paused because too many requests were sent.
  ```
- provide:
  ```text
  Retry
  ```

Manual Retry clears the pause and performs one GET.

On success polling resumes.

Do not spin every 5 seconds against 429.

---

# 41. Monitoring Lifecycle Errors

Map exact:

## `task_not_active`

State:

```text
notActive
```

Stop polling.

UI:

```text
This Blitz is not active.
```

## `task_closed`

State:

```text
closed
```

Stop polling.

UI:

```text
This Blitz has been closed.
```

## `task_archived`

State:

```text
archived
```

Stop polling.

UI:

```text
This Blitz is archived.
```

## `resource_not_found`

State:

```text
notFound
```

Stop polling.

Privacy-safe unavailable UI.

Do not automatically navigate away.

Provide:

```text
Back to Blitz
```

where route is still meaningful.

---

# 42. Timeout Reconciliation Trust

Monitoring GET itself may cause the backend to finalize due Attempts.

Frontend treats the returned response as authoritative.

Do not:

- locally change Student `in_progress -> finalized` based on countdown;
- fabricate timeout reason;
- mutate rows before GET.

If an old displayed row's remaining value reaches/appears zero between polls,
wait for the next monitoring GET.

Server owns status.

---

# 43. Monitoring Top Header

Display only after Section 26 parent identity is confirmed:

```text
Blitz title          // from the confirmed FE-001 detail for this exact route target
Active
timer mode
duration
activated time
```

The FE-001 detail is **required route-context authority**, not an optional title
source.

For synchronized:

```text
Common timer end
```

Use server snapshot values for monitoring.

Do not run a client lifecycle timer.

---

# 44. Monitoring Live Indicator

Display a small status:

```text
Live · updates every 5 seconds
```

when polling active.

When app/poll paused:

```text
Live updates paused
```

When stale:

```text
Live monitoring may be out of date
```

Do not imply WebSocket immediacy.

---

# 45. Monitoring Summary Presentation

Show:

```text
Assigned
Not started
In progress
Finalized
Waiting for Teacher review
Additional attempts granted
```

Use cards/chips responsive to width.

No score count.

No answered Question count.

---

# 46. Desktop Student Monitoring Row

Desktop row/card displays at minimum:

```text
Student full name
status
Attempt number / —
started time / —
deadline / —
remaining time / —
finalization reason / —
exception badge/details
```

No:

```text
answer text
Question
file
score
feedback
```

---

# 47. Mobile Basic Student Monitoring

Mobile intentionally uses a reduced card.

Display:

```text
Student full name
status
Attempt 1 / Additional attempt / Not started
remaining time when applicable
finalization reason when terminal
Additional attempt granted badge when exception exists
```

Do **not** display on mobile:

```text
exception reason text
grant button
invalidated/replacement UUIDs
```

This is the approved “basic monitoring” scope.

---

# 48. Monitoring Status Labels

Presentation labels:

```text
not_started                 -> Not started
in_progress                 -> In progress
finalized                   -> Finalized
waiting_for_teacher_review  -> Waiting for Teacher review
```

No raw machine code.

---

# 49. Finalization Reason Labels

```text
student_submit             -> Submitted by Student
timeout_auto_submit        -> Time expired
task_closed_auto_finalize  -> Finalized when Blitz closed
```

No score implication.

---

# 50. Attempt Number Presentation

```text
null -> —
1    -> Attempt 1
2    -> Additional attempt
```

Do not label #2:

```text
Second normal attempt
```

---

# 51. Remaining Time Presentation

Use response:

```text
remainingSeconds
```

as server snapshot.

Do not calculate from:

```text
DateTime.now()
```

Monitoring polls every 5 seconds, so per-row remaining time is updated by server
snapshots.

Format:

```text
mm:ss
h:mm:ss
```

or `—` for null.

If status terminal:

```text
00:00
```

or equivalent.

No one-second per-row timer.

---

# 52. Exception Details — Desktop

If row exception exists, show:

```text
Additional attempt granted
Reason type
Reason
Granted at
Replacement state
```

Replacement state:

## null replacement ID / available

```text
Waiting for Student to start additional attempt
```

## replacement started

```text
Additional attempt already started
```

Do not show UUIDs in ordinary UI.

No revoke/edit button.

---

# 53. Exception Grant Visibility

Desktop only.

Show:

```text
Grant additional attempt
```

only when local monitoring snapshot suggests a plausible candidate:

```text
monitoring Blitz active
row.attemptException == null
row.attemptNumber == 1
row.status == finalized
OR row.status == waitingForTeacherReview
```

Do not show for:

```text
notStarted
inProgress
Attempt 2
existing exception
```

This is a UX hint only.

Backend remains authoritative.

Do not inspect score.

---

# 54. Inactive Assigned Student Caveat

Monitoring API intentionally does not expose current Student account active
state.

Therefore the frontend cannot perfectly know whether the backend will accept an
exception target.

Do not invent account-status assumptions.

If grant receives privacy-safe:

```text
404 resource_not_found
```

refresh monitoring and show safe unavailable feedback.

---

# 55. Exception Grant Dialog

Desktop only.

Create:

```text
TeacherBlitzAttemptExceptionDialog
```

Title:

```text
Grant additional Blitz attempt
```

Display Student full name.

Fields:

```text
Reason type
Reason
```

Reason-type options:

```text
Technical problem
Other valid reason
```

Helper text:

```text
The original attempt remains in history.
This grant allows one replacement attempt only.
The replacement attempt is created only when the Student starts it.
```

Buttons:

```text
Cancel
Grant additional attempt
```

---

# 56. Exception Reason Validation

Create immutable request/value:

```text
TeacherBlitzAttemptExceptionRequest
```

Fields:

```text
reasonType
reason
```

Validation:

```text
reason type required
reason trimmed
reason non-empty after trim
reason <= 4000 Unicode characters
```

Persist/send trimmed reason.

Do not accept Teacher-entered Student/Attempt IDs.

Route supplies Student.

---

# 57. Exception Grant API

Extend:

```text
TeacherBlitzRepository
```

with:

```dart
Future<TeacherBlitzAttemptException> grantAttemptException(
  String blitzId,
  String studentId,
  TeacherBlitzAttemptExceptionRequest request, {
  required String idempotencyKey,
});
```

Endpoint:

```text
POST /teacher/blitz/{blitzId}/students/{studentId}/attempt-exception
```

Headers:

```text
Idempotency-Key
```

JSON body:

```json
{
  "reason_type": "technical",
  "reason": "Device disconnected during the normal attempt."
}
```

No query.

---

# 58. Exception Grant Success Contract

Require:

```text
201 Created
```

Exact envelope:

```text
data
message
```

Exact message:

```text
One additional Blitz attempt has been granted.
```

Parse exact exception resource.

---

# 59. Grant Resource DTO — Separate From Active Monitoring Invariants

Create:

```text
TeacherBlitzAttemptExceptionDto
```

Exact `data` keys:

```text
id
blitz_id
student_id
invalidated_attempt_id
replacement_attempt_id
reason_type
reason
granted_at
replacement_attempt_available
```

Require:

```text
blitz_id == requested Blitz
student_id == requested Student
```

Reuse the same reason/UUID/basic field parsing as monitoring where practical, but
**do not reuse Section 15's Active-only cross-invariant validator**.

The grant/replay resource has this exact truth table:

## Granted, unused, currently available

```text
replacementAttemptId = null
replacementAttemptAvailable = true
```

Valid for an Active Blitz before #2 starts.

## Granted, unused, no longer available

```text
replacementAttemptId = null
replacementAttemptAvailable = false
```

This is a valid historical grant/replay resource after the Blitz later becomes:

```text
closed
archived
```

before #2 starts.

It means:

```text
the grant exists
the replacement was never started
the replacement cannot now be started
```

It is **not** `invalidResponse`.

## Replacement already started

```text
replacementAttemptId != null
replacementAttemptAvailable = false
```

Valid for current replay after #2 creation.

## Invalid

Reject:

```text
replacementAttemptId != null
replacementAttemptAvailable = true
```

The DTO does not need the Blitz lifecycle field itself. Availability is an
authoritative backend projection in this grant resource.

Monitoring remains stricter because its endpoint is Active-only; Section 15 is
unchanged.

Do not parse/expose:

```text
institution_id
assessment_student_id
granted_by_user_id
```

---

# 60. Grant Idempotency Key

Reuse:

```text
IdempotencyKeyGenerator
```

One logical grant:

```text
one generated key
```

Private controller state only.

Do not expose/log.

---

# 61. Grant Controller

Create:

```text
TeacherBlitzAttemptExceptionController
TeacherBlitzAttemptExceptionState
```

Family target:

```text
TeacherBlitzRouteTarget
```

It must observe the same Section 26 confirmed parent identity guard as monitoring.

It may handle one Student grant operation at a time only while:

```text
detail.id == target.blitzId
detail.topicId == target.topicId
```

If parent identity is checking/notFound/error:

```text
no grant request
```

State:

```text
idle
submitting
uncertain
checking
confirmed
failure
```

Track privately:

```text
pendingKey
requestedStudentId
requestSnapshot
operationGeneration
```

Desktop eligible only.

Mobile builds neutral/unavailable mutation state.

---

# 62. Grant Mutation Serialization

Grant operation coordinates with the monitoring controller.

While grant is:

```text
submitting
uncertain
checking
```

pause automatic monitoring polling.

Reason:

- avoid current-client GET/mutation publication races;
- grant response is followed by intentional monitoring reconciliation.

Manual unrelated monitoring Refresh is disabled while grant operation owns the
route.

After grant settles:

- resume polling when route/app eligible.

---

# 63. Grant Success / Completed Replay

On any strict `201` that passes the grant-specific Section 59 DTO:

1. validate target IDs;
2. clear pending key;
3. mark the logical grant `confirmed`;
4. do **not** patch a monitoring Student row locally from the exception alone;
5. perform a best-effort immediate monitoring refresh when the monitoring route
   can still return an Active snapshot;
6. let any monitoring lifecycle response (`task_closed|task_archived`) update the
   monitoring controller normally;
7. never let a later monitoring lifecycle response undo the already-confirmed
   grant result.

## Available unused grant

For:

```text
replacementAttemptId = null
replacementAttemptAvailable = true
```

feedback:

```text
Additional Blitz attempt granted.
```

The monitoring refresh should normally establish:

```text
not_started + replacement available
```

or a newer state.

## Historical unused-but-unavailable grant

For:

```text
replacementAttemptId = null
replacementAttemptAvailable = false
```

feedback:

```text
Additional-attempt grant confirmed, but the Blitz no longer allows the Student to start that attempt.
```

This can be a same-key completed replay after Close/Archive.

Do not classify it as uncertain and do not offer another grant.

## Replacement already started

For:

```text
replacementAttemptId != null
replacementAttemptAvailable = false
```

feedback:

```text
Additional-attempt grant confirmed. The additional attempt has already been started.
```

Do not create/patch #2 locally; monitoring remains the source for operational
Student state when available.

Grant creates no Attempt in frontend.

---

# 64. Grant Uncertain Classification

Treat as uncertain:

```text
connection
timeout
cancelled
invalidResponse
unknown
statusCode == null
statusCode >= 500
```

Keep same key and request snapshot.

UI:

```text
We could not confirm whether the additional attempt was granted.
```

Actions:

```text
Retry grant
Check monitoring
```

No new-key Grant button.

---

# 65. Grant Same-Key Retry

Explicit:

```text
Retry grant
```

uses the same key and exact request body/route target.

Do not generate another key.

The backend checks completed replay before current grant lifecycle eligibility.

Therefore a Retry after the Blitz later becomes Closed/Archived has two
deterministic possibilities:

```text
original grant had committed
-> 201 same exception
-> Section 59 may return null replacement ID + availability false
-> confirmed historical grant

original grant had not committed
-> no completed replay exists
-> current non-active lifecycle rejects the grant
-> 409 blitz_attempt_exception_not_allowed
-> definite failure/no grant
```

This is the recovery path that remains authoritative even when Active-only
monitoring can no longer display the exception.

Disable reason editing while logical result remains uncertain.

The Student target/reason snapshot cannot change until operation is resolved or
abandoned by route/session loss.

---

# 66. Grant Check Monitoring

`Check monitoring` performs GET monitoring only as an Active-Blitz recovery aid.

## Active monitoring succeeds and exception exists

If authoritative row now has:

```text
attemptException != null
```

then desired operational state has been achieved.

Required:

- clear pending key;
- state `confirmed`;
- feedback:
  ```text
  An additional attempt is now granted to this Student.
  ```
- do not claim which device/request created it;
- resume polling.

## Active monitoring succeeds and exception is absent

Keep:

```text
uncertain
```

Same-key Retry remains available.

## Monitoring is no longer available because Blitz closed/archived

If Check monitoring returns:

```text
task_closed
task_archived
```

it cannot prove whether the earlier grant committed, because the monitoring
endpoint is Active-only.

Required:

- update monitoring UI to the lifecycle terminal state;
- **retain** the pending grant key/request snapshot;
- keep grant outcome unresolved;
- offer/retain explicit:
  ```text
  Retry grant
  ```
  using the same key;
- explain:
  ```text
  Live monitoring is no longer available for this Blitz. Retry the original grant request to confirm whether it was recorded.
  ```

Do not generate a new key.

Do not infer "grant failed" merely because monitoring closed.

---

# 67. Grant Already-Granted Error

On:

```text
409 blitz_attempt_exception_already_granted
```

do not treat as a generic failure.

Clear current pending key only after refreshing monitoring.

If row shows exception:

```text
confirmed current state
```

Feedback:

```text
An additional attempt has already been granted to this Student.
```

If monitoring cannot confirm, show current-state recovery error.

No second grant.

---

# 68. Grant Not-Allowed Error

On:

```text
409 blitz_attempt_exception_not_allowed
```

show:

```text
An additional attempt cannot be granted in the current Blitz state.
Refresh monitoring to review the Student's current attempt.
```

Clear pending key.

Refresh monitoring.

Do not infer whether the cause was live #1, lifecycle, or another race.

---

# 69. Grant Normal-Attempt-Required Error

On:

```text
409 blitz_normal_attempt_required
```

show:

```text
The Student must have a normal Blitz attempt before an additional attempt can be granted.
```

Clear key.

Refresh monitoring.

No Attempt creation.

---

# 70. Grant `idempotency_key_reused`

Show:

```text
The additional-attempt request could not be replayed safely.
Refresh monitoring before trying again.
```

Clear pending key.

Do not generate/send another key automatically.

Refresh monitoring.

---

# 71. Grant `resource_not_found`

Privacy-safe:

```text
The Student or Blitz is no longer available for this action.
```

Clear key.

Refresh monitoring.

Do not disclose which resource failed.

---

# 72. Grant Session Failure

For:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

reuse Teacher session reconciliation.

Clear pending grant key/request.

No stale feedback after session switch.

---

# 73. Mobile Activate — Scope Extension

S08-FE-003 intentionally limited lifecycle mutation UI to desktop.

FE-006 changes only:

```text
Activate
```

to be allowed on:

```text
desktop
mobile
```

Keep:

```text
Schedule/Reschedule  desktop only
Official designation desktop only
Close                desktop only
Archive              desktop only
```

Do not add mobile lifecycle actions beyond Activate.

---

# 74. Reuse Same Activation Controller

Do not create:

```text
TeacherMobileBlitzActivationController
```

Reuse/extend FE-003:

```text
TeacherBlitzLifecycleController
```

and the same:

- activation request;
- Idempotency-Key;
- unknown-outcome GET reconciliation;
- explicit same-key Retry;
- **fresh-success vs completed-replay lifecycle validation**;
- same-key replay acceptance of current `active|closed|archived`;
- rejection of impossible successful replay `draft|scheduled`;
- conflict mapping;
- detail/list/pair refresh.

Mobile must not introduce a second activation replay interpretation.

One activation state machine for desktop/mobile.

---

# 75. Lifecycle Controller Surface Eligibility

Modify FE-003 controller guard.

Teacher session:

```text
desktop or mobile
```

may own the controller.

Per-action capability:

## Activate

```text
desktop || mobile
```

## Schedule / Close / Archive

```text
desktop only
```

If an unsupported action is invoked programmatically on mobile:

```text
no request
```

Do not rely only on hidden buttons.

---

# 76. Mobile Activate Visibility

On mobile Blitz detail show:

```text
Activate
```

only for confirmed:

```text
Draft
Scheduled
```

Do not show:

```text
Edit
Manage Questions
Schedule
Reschedule
Set Official
Replace Official
Close
Archive
Grant exception
```

FE-001 read detail remains unchanged.

---

# 77. Mobile Activate Confirmation

Reuse FE-003 confirmation semantics.

Explain:

```text
The server will snapshot the Institution's current timer-start mode.

Synchronized mode starts the common class timer immediately.

Individual mode makes the Blitz available and each Student's timer starts when that Student starts the attempt.
```

No local timer setting inference.

---

# 78. Mobile Official-State Warning Before Activate

Mobile cannot designate official Blitz.

Use existing confirmed:

```text
TeacherTopicResultPairState
```

as supplemental context.

## Confirmed current Blitz is official

Show:

```text
Official Blitz
```

in confirmation.

## Confirmed pair says this Blitz is not official

Show warning:

```text
This Blitz is not currently designated as the Topic's official Blitz.

If you activate it now, it remains practice/supplementary and cannot later be newly designated as official while Active.
```

Teacher may still activate.

Do not block practice activation.

## Pair state unconfirmed/error

Show:

```text
Official Blitz status could not be confirmed.
If this Blitz must be official, refresh on desktop before activation.
```

Teacher may still activate.

Backend activation does not require official designation.

---

# 79. Mobile Activation Conflict Guidance

Reuse machine-code logic but adapt unavailable desktop corrective actions.

Examples:

## `assessment_has_no_scoreable_points`

Mobile:

```text
This Blitz needs at least one scoreable Question.
Use the desktop Teacher workspace to manage Questions.
```

No mobile Manage Questions button.

## `assessment_not_assigned`

```text
The server could not establish a valid assigned Student set.
Use the desktop Teacher workspace to review the assignment when editing is required.
```

## `institution_settings_incomplete`

Same FE-003 message; no settings editor.

## `official_cohort_mismatch`

Refresh/detail message only.

Do not open desktop-only route on mobile.

---

# 80. Mobile Activation Success / Replay

Reuse FE-003 Section 46 semantics exactly.

## Fresh mobile activation success

For the initial mobile activation POST:

```text
200 + active
```

is the valid fresh success.

Adopt authoritative Active Blitz, refresh Blitz list/result pair, stay on detail,
and show success.

After status becomes Active, mobile detail replaces Activate with:

```text
Monitor
```

## Mobile explicit same-key Retry

If an uncertain mobile activation later performs explicit same-key Retry, accept
the backend's current replay resource exactly as FE-003 does:

```text
active
closed
archived
```

with required persisted activation evidence.

For:

```text
200 + closed
```

adopt Closed current state, clear the pending activation operation, do not show
Activate or Monitor, and do not reopen.

For:

```text
200 + archived
```

adopt Archived current state, clear the pending activation operation, show no
lifecycle mutation, and do not reopen.

`draft|scheduled` remain invalid as a completed successful replay.

A Closed/Archived replay is a confirmed historical activation, not an uncertain
failure.

No automatic navigation.

---

# 81. Monitoring Entry Button

On confirmed:

```text
Blitz.status = active
```

show:

```text
Monitor
```

on:

```text
desktop
mobile
```

Navigate:

```text
teacherBlitzMonitoringLocation(
  topicId,
  blitzId,
)
```

No Monitor button for Draft/Scheduled/Closed/Archived.

---

# 82. Desktop Detail + FE-003 Integration

Desktop Active detail now has:

```text
Close
Monitor
Refresh
```

according to existing FE-003 action grouping.

Monitoring does not replace Close.

No exception grant on detail.

Exception grant lives in monitoring Student rows only.

---

# 83. Monitoring Screen Does Not Own Close

Do not add Close mutation to monitoring screen in FE-006.

Use:

```text
Back to Blitz
```

then FE-003 Close.

Reason:

- mobile monitoring must remain basic read-only;
- one lifecycle action location stays authoritative;
- avoid mixing monitoring polling and Close mutation state.

---

# 84. Monitoring Screen Desktop Layout

Recommended:

```text
Header / live-state banner
Timing card
Summary card grid
Students heading
Student rows/cards
```

Max width suitable for desktop.

For larger widths a table-like layout is allowed.

For medium widths use cards/wrap.

No horizontal overflow.

---

# 85. Monitoring Screen Mobile Layout

Use vertical cards.

Order:

```text
Header
Live status
Timing
Summary wrap
Student cards
```

No wide DataTable that requires horizontal scrolling as the primary UX.

Student reason/grant controls omitted per mobile scope.

---

# 86. Monitoring Timing Presentation

Display:

```text
Timer mode
Duration
Activated at
Server snapshot
Common end          // synchronized only
```

Use Institution timezone for human wall-clock formatting where an existing
Teacher formatter applies.

Execution remaining seconds come from monitoring rows as server snapshots.

Do not compute Student deadlines from timer mode.

---

# 87. Polling and Exception Dialog

When exception dialog is open but no mutation has started:

- polling may continue if it will not replace dialog form state.

Preferred:

- pause polling while dialog is open to prevent candidate row disappearing under
  the form;
- on Cancel resume polling and immediate refresh if needed.

Capture:

```text
session
route target
Student ID
monitoring generation
```

before opening.

If ownership changes, returned dialog result is ignored.

---

# 88. Candidate and Parent-Identity Re-Check Before Grant

After dialog confirms and before generating key/sending POST, require **both**:

```text
Section 26 parent identity is still confirmed
detail.id == target.blitzId
detail.topicId == target.topicId
```

and:

```text
current authoritative monitoring state still has the exact Student row
and local grant-candidate projection
```

## Parent identity changed/lost

If parent identity is no longer confirmed:

- do not generate an Idempotency-Key;
- do not send Grant;
- close/retire the dialog result;
- transition to safe parent notFound/error handling;
- do not disclose another Topic identity.

## Student row changed

If the Student row/candidate changed:

- do not send;
- close dialog;
- show:
  ```text
  The Student's Blitz status changed. Review current monitoring before granting an additional attempt.
  ```

Backend remains final authority even after these checks.

---

# 89. No Score-Based Grant

Do not show:

```text
Grant retry because low score
```

No score exists in Stage 8 monitoring.

Grant reason types are:

```text
technical
other_valid
```

The Teacher chooses a valid exception reason.

No algorithm examines score.

---

# 90. No Exception Revoke/Edit

After exception exists:

- show its current state;
- no:
  ```text
  Edit reason
  Revoke
  Grant again
  ```
- no second mutation button.

Exactly one exception per Student/Blitz.

---

# 91. Monitoring Poll After Grant

A successful grant changes operational monitoring semantics:

```text
Attempt #1 historical
current replacement path not started
```

Do not locally transform row.

Immediate monitoring GET must provide authoritative:

```text
status = not_started
attempt_number = null
attempt_exception.replacement_attempt_available = true
```

or a newer state if Student already started #2.

This is why grant response alone does not patch monitoring row.

---

# 92. Student Starts Replacement During Poll

Possible snapshots:

```text
not_started + replacement available
```

then next poll:

```text
in_progress + Attempt 2
```

Frontend simply replaces monitoring snapshot.

No transition animation/business mutation required.

---

# 93. Monitoring vs Timeout

A row may be:

```text
in_progress with small remaining
```

then next poll:

```text
finalized + timeout_auto_submit
```

Display new state.

Do not locally finalize at zero between polls.

---

# 94. Monitoring vs Teacher Close

Teacher may close from desktop detail/another device.

Monitoring GET later returns:

```text
409 task_closed
```

Stop polling and show:

```text
This Blitz has been closed.
```

Do not try to keep showing stale live status as current.

Retained previous snapshot may be hidden behind the closed notice; do not present
it as live.

---

# 95. Monitoring vs Archive

If archived elsewhere after close:

```text
task_archived
```

stop.

No mutation.

---

# 96. Monitoring Read Privacy

The monitoring response/presentation must not expose:

```text
Question prompts
answers
selected options
written text
file metadata
correct-answer configuration
checking_status
awarded_points
feedback
score
normalized score
```

Search new UI/domain for accidental leakage.

`score` response key is validated null and discarded.

---

# 97. Exception Reason Privacy on Mobile

Mobile monitoring does not display the free-text reason.

Desktop Teacher may view it.

This is a product-scope minimization for basic mobile monitoring, not a backend
security boundary.

Do not attempt to remove it from the fetched DTO.

---

# 98. Session / Target Stale Safety

Monitoring/read/grant/activation completion must be owned by:

```text
TeacherSessionKey
TeacherBlitzRouteTarget
confirmed parent-identity generation
operation/request generation
```

A stale completion cannot:

- overwrite another Blitz monitoring screen;
- show grant feedback for another Student;
- publish after logout;
- publish after Teacher/Institution/session change;
- enable mobile action on another route;
- publish monitoring or Grant state after the parent Topic/Blitz identity guard
  moved to notFound/error or a newer identity generation.

Do not rely only on `context.mounted`.

---

# 99. Polling vs Session Change

On session ownership loss:

- stop polling;
- clear monitoring private data/state according to current Teacher privacy
  conventions;
- clear pending grant key;
- no late request publication;
- no old exception reason visible in new session.

---

# 100. Monitoring Retry / Refresh Accessibility

Controls:

```text
Refresh
Retry
```

must have:

- semantic labels/tooltips;
- disabled busy state;
- visible stale/live state text.

Do not make a tiny icon the only recovery affordance on mobile.

---

# 101. Grant Dialog Accessibility

Required:

- Student name in title/content;
- labelled reason-type input;
- labelled multiline reason;
- max-length helper;
- validation message;
- first invalid field focus;
- progress indicator during Submit outside/inside dialog according to current
  pattern;
- no color-only warning.

---

# 102. Monitoring Student Accessibility

Each Student card/row should expose a coherent semantic summary.

Do not mark every remaining-time poll update as a screen-reader live announcement.

A 5-second poll must not cause repeated spoken announcements automatically.

Use ordinary text unless user focuses the row.

---

# 103. Expected File Scope

Exact names may follow delivered Stage 8 conventions.

## Create likely

```text
frontend/lib/features/teacher/domain/teacher_blitz_monitoring.dart
frontend/lib/features/teacher/domain/teacher_blitz_attempt_exception.dart

frontend/lib/features/teacher/data/dto/teacher_blitz_monitoring_dto.dart
frontend/lib/features/teacher/data/dto/teacher_blitz_attempt_exception_dto.dart

frontend/lib/features/teacher/application/teacher_blitz_monitoring_state.dart
frontend/lib/features/teacher/application/teacher_blitz_monitoring_controller.dart
frontend/lib/features/teacher/application/teacher_blitz_attempt_exception_state.dart
frontend/lib/features/teacher/application/teacher_blitz_attempt_exception_controller.dart

frontend/lib/features/teacher/presentation/teacher_blitz_monitoring_screen.dart
frontend/lib/features/teacher/presentation/teacher_blitz_attempt_exception_dialog.dart
```

## Modify likely

```text
frontend/lib/features/teacher/domain/teacher_blitz_repository.dart
frontend/lib/features/teacher/data/teacher_blitz_remote_data_source.dart
frontend/lib/features/teacher/data/teacher_blitz_repository_impl.dart

frontend/lib/features/teacher/application/teacher_blitz_lifecycle_controller.dart
frontend/lib/features/teacher/application/teacher_blitz_lifecycle_state.dart

frontend/lib/features/teacher/presentation/teacher_blitz_detail_screen.dart
frontend/lib/features/teacher/presentation/teacher_blitz_formatters.dart

frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart

frontend/lib/core/network/api_error_codes.dart
```

Modify FE-003 route-mutation activity only if activation surface eligibility
requires a narrow current-session fix.

Do not modify:

```text
backend/
Student Stage 8 execution feature
platform files
pubspec.yaml
pubspec.lock
integration_test/
docs/
tasks/
```

---

# 104. Monitoring DTO Tests

Create:

```text
teacher_blitz_monitoring_dto_test.dart
```

Cover:

- synchronized active monitoring;
- individual active monitoring;
- empty assigned roster;
- normal not-started synchronized remaining;
- normal not-started individual null remaining;
- Attempt #1 in-progress;
- Attempt #1 finalized;
- waiting review;
- unused exception -> current not-started;
- Attempt #2 in-progress;
- Attempt #2 finalized;
- exact exception metadata;
- score must be null;
- summary partition exact;
- exception count exact;
- duplicate Student ID rejected;
- invalid Attempt #2 without exception rejected;
- invalid replacement availability rejected;
- Homework finalization reason rejected;
- unknown/missing keys rejected.

---

# 105. Grant DTO / Request Tests

Create:

```text
teacher_blitz_attempt_exception_test.dart
```

Cover:

- technical reason;
- other_valid;
- reason trim;
- empty reason rejected;
- 4000 accepted;
- over 4000 rejected;
- exact request JSON;
- exact response resource;
- target Blitz/Student mismatch rejected;
- grant resource replacement null/available true accepted;
- grant resource replacement null/available false accepted as historical unused-but-unavailable;
- grant resource replacement non-null/available false accepted;
- grant resource replacement non-null/available true rejected;
- monitoring DTO still rejects null/available false for an Active monitoring response.

---

# 106. Monitoring Data Source Tests

Create:

```text
teacher_blitz_monitoring_data_source_test.dart
```

Verify:

```text
GET /teacher/blitz/{id}/monitoring
no query/body
200 strict
```

Error mapping:

```text
task_not_active
task_closed
task_archived
resource_not_found
rate_limited
```

Malformed 200 -> invalidResponse.

No polling logic in data source.

---

# 107. Grant Data Source Tests

Create:

```text
teacher_blitz_attempt_exception_data_source_test.dart
```

Verify exact:

```text
POST /teacher/blitz/{blitz}/students/{student}/attempt-exception
Idempotency-Key
JSON reason_type/reason
201
exact message
```

No query.

No automatic retry.

Grant response specifically accepts the Section 59 unused-but-unavailable
`replacement_attempt_id=null` + `replacement_attempt_available=false` shape.

Unknown/malformed success classifiable as uncertain by controller.

---

# 108. Monitoring Controller Tests

Create:

```text
teacher_blitz_monitoring_controller_test.dart
```

Use fake async/pumpable time.

Cover:

- parent identity checking performs no monitoring publication;
- exact Topic/Blitz detail identity -> initial monitoring load;
- detail `resource_not_found` -> monitoring notFound and no monitoring GET;
- detail Topic mismatch -> safe monitoring notFound and no monitoring publication;
- parent transient detail error -> no monitoring fallback + Retry;
- parent identity loss after prior data stops polling and ignores stale in-flight monitoring completion;
- initial load;
- successful data;
- monitoring Blitz ID mismatch rejected;
- manual refresh retained;
- 5-second polling;
- no overlapping poll;
- stale transient failure retained;
- next tick recovery;
- 429 pauses polling;
- manual Retry resumes;
- task_not_active stops;
- task_closed stops;
- task_archived stops;
- 404 stops;
- leave route stops timer;
- app pause stops timer;
- app resume immediate refresh + polling;
- session switch clears;
- stale completion ignored;
- grant-mutation pause/resume integration.

No real 5-second sleep.

---

# 109. Grant Controller Tests

Create:

```text
teacher_blitz_attempt_exception_controller_test.dart
```

Cover:

- desktop candidate grant;
- mobile no grant request;
- confirmed Topic/Blitz parent identity required before grant;
- parent identity checking/notFound/error -> no grant request;
- parent identity lost while dialog open -> no key/no POST;
- local candidate re-check;
- one key;
- exact request snapshot;
- success -> monitoring refresh;
- active unused grant success null/available true;
- same-key replay after Close/Archive accepts null/available false and confirms grant;
- replay with replacement ID/available false confirms already-started replacement state;
- uncertain;
- same-key Retry;
- same-key Retry after lifecycle end: committed original -> 201 historical replay;
- same-key Retry after lifecycle end: uncommitted original -> not_allowed definite failure;
- Check monitoring exception found -> confirmed;
- Check monitoring no exception -> remains uncertain;
- Check monitoring task_closed/task_archived retains pending key and requires same-key Retry for resolution;
- already_granted reconciliation;
- not_allowed;
- normal_attempt_required;
- idempotency_key_reused;
- 404;
- session failure;
- stale Student/route completion ignored;
- polling paused while grant owns operation.

---

# 110. Monitoring Screen Tests

Create:

```text
teacher_blitz_monitoring_screen_test.dart
```

Desktop:

- confirmed parent identity required before header/live data;
- mismatched Topic/Blitz direct context renders safe notFound;
- mismatched/unconfirmed parent context shows no Grant;
- header/live indicator;
- synchronized timing;
- individual timing;
- summary counts;
- Student rows;
- finalization reason;
- exception reason/details;
- Grant button candidate;
- no Grant for invalid candidate;
- grant dialog;
- stale banner;
- rate-limit pause;
- lifecycle terminal notice;
- no score/answer text.

Mobile:

- confirmed parent identity required before monitoring publication;
- mismatched Topic/Blitz direct context renders safe notFound;
- compact summary;
- compact Student cards;
- Attempt #2 label;
- exception-granted badge;
- no exception reason;
- no Grant button;
- no score/answers;
- narrow width no overflow.

---

# 111. Monitoring Routing Tests

Extend:

```text
teacher_blitz_routing_screen_test.dart
```

Verify:

```text
/teacher/topics/<topic>/blitz/<blitz>/monitoring
```

- exact helper/recognizer;
- desktop direct entry with matching Topic/Blitz -> detail identity confirmed, then monitoring loads;
- mobile direct entry with matching Topic/Blitz -> detail identity confirmed, then monitoring loads;
- desktop direct entry with Topic A + Blitz B belonging to Topic B -> safe notFound, monitoring data not published, no Grant;
- mobile direct entry with Topic A + Blitz B belonging to Topic B -> safe notFound, monitoring data not published;
- direct-entry parent detail 404 -> safe notFound;
- parent detail transient error -> Retry/error state, not false notFound and no monitoring fallback;
- auth bootstrap preserves valid matching route;
- wrong role safe;
- malformed IDs safe;
- query/fragment rejected according current rules;
- Blitz detail classifier remains exact;
- Edit/Questions remain mobile unsupported.

Do not count nested GoRoute structure itself as relationship verification.

---

# 112. Mobile Activation Controller Tests

Extend FE-003 lifecycle tests.

Cover:

- desktop Activate still works;
- mobile Draft Activate works;
- mobile Scheduled Activate works;
- mobile activation key/retry same behavior;
- mobile initial activation `200 + active` succeeds;
- mobile uncertain activation -> explicit same-key Retry uses identical key;
- mobile same-key Retry after later Close accepts current `closed` resource as confirmed historical activation;
- mobile same-key Retry after later Archive accepts current `archived` resource as confirmed historical activation;
- Closed/Archived replay does not expose Activate and does not reopen lifecycle;
- mobile replay `draft|scheduled` remains invalid/unknown success;
- mobile cannot Schedule;
- mobile cannot Close;
- mobile cannot Archive;
- mobile does not call official PUT;
- programmatic unsupported action produces no request;
- error corrective copy is mobile-safe.

---

# 113. Mobile Blitz Detail Screen Tests

Extend:

```text
teacher_blitz_detail_screen_test.dart
```

Mobile Draft/Scheduled:

```text
Activate
```

present.

After same-key activation replay adopts:

```text
closed
archived
```

`Activate` is absent and the screen reflects the returned current lifecycle.

No:

```text
Edit
Manage Questions
Schedule/Reschedule
Official designation
Archive
```

Mobile Active:

```text
Monitor
```

present.

No:

```text
Close
Grant exception
```

Desktop remains full FE-003 capability plus Monitor.

---

# 114. Official Warning Tests

Mobile activation confirmation:

## Confirmed official

Displays Official context.

## Confirmed non-official

Displays practice/supplementary warning.

## Pair unconfirmed/error

Displays official-status-unconfirmed warning.

None blocks Activate.

No result-pair PUT.

---

# 115. FE-003 Direct Regression

Run exact focused tests for:

```text
TeacherBlitzLifecycleController
TeacherOfficialBlitzController
TeacherBlitzDetailScreen
Topic open-assessment integration
```

Required:

- desktop Schedule/Official/Close/Archive unchanged;
- activation same-key semantics include valid current `closed|archived` completed replay;
- desktop replay regression remains green;
- new mobile eligibility does not enable other actions.

---

# 116. FE-001/002 Read/Router Regression

Run exact focused:

```text
Teacher Blitz detail/read
Teacher Blitz routing
Teacher Topic detail/Blitz section
```

because:

- monitoring route extends router;
- mobile whitelist changes;
- detail gets Monitor/mobile Activate actions.

Existing authoring redirects remain green.

---

# 117. Focused Verification — New FE-006

Run from:

```text
frontend/
```

Conceptually:

```bash
fvm flutter test \
  test/features/teacher/teacher_blitz_monitoring_dto_test.dart \
  test/features/teacher/teacher_blitz_attempt_exception_test.dart \
  test/features/teacher/teacher_blitz_monitoring_data_source_test.dart \
  test/features/teacher/teacher_blitz_attempt_exception_data_source_test.dart \
  test/features/teacher/teacher_blitz_monitoring_controller_test.dart \
  test/features/teacher/teacher_blitz_attempt_exception_controller_test.dart \
  test/features/teacher/teacher_blitz_monitoring_screen_test.dart \
  test/features/teacher/teacher_blitz_routing_screen_test.dart
```

Include extended lifecycle/detail mobile tests.

Use actual filenames if combined differently.

---

# 118. Direct Regression Verification

Run exact current focused tests for:

- FE-003 lifecycle/official;
- FE-001/002 Blitz detail/router;
- Teacher mobile route bootstrap/redirect;
- Topic detail if affected.

Do not run full frontend suite.

---

# 119. Focused Analyze

Run:

```bash
fvm flutter analyze --no-pub lib/features/teacher
fvm flutter analyze --no-pub lib/app/router
```

If core error code file changes, include narrowest supported scope.

Do not silently substitute full-project analyze unless pinned CLI requires it.

---

# 120. Format Check

Run read-only format check on actual changed Dart files/tests.

Conceptually:

```bash
fvm dart format --output=none --set-exit-if-changed \
  <changed Teacher/router/core files> \
  <changed focused tests>
```

Do not format unrelated code.

---

# 121. Git Diff Check

From repository root:

```bash
git diff --check
```

Required:

```text
PASS
```

Then focused scope/diff self-review.

Do not run:

- full frontend suite;
- full project analyze;
- Windows build;
- Android build;
- broad E2E.

Those belong to:

```text
S08-FE-PHASE-2
S08-INT-001
```

---

# 122. Acceptance Criteria — Monitoring Domain/API

- [ ] Exact monitoring GET used.
- [ ] Monitoring route target contains canonical Topic + Blitz IDs.
- [ ] FE-001 detail must confirm `detail.id == target.blitzId` and `detail.topicId == target.topicId` before monitoring publication.
- [ ] Parent identity mismatch/404 becomes privacy-safe notFound with no monitoring publication.
- [ ] Parent transient error does not fall back to independent monitoring.
- [ ] Monitoring response Blitz ID must equal target Blitz ID.
- [ ] Strict top-level/nested DTO.
- [ ] Active status only.
- [ ] Summary partition validated.
- [ ] Student count matches assigned.
- [ ] exception count matches rows.
- [ ] score must be null.
- [ ] Attempt #2 requires exception graph.
- [ ] no answers/questions/files parsed.
- [ ] no client timeout finalization.

---

# 123. Acceptance Criteria — Polling

- [ ] Poll every 5 seconds.
- [ ] One controller Timer only.
- [ ] No overlapping GETs.
- [ ] Foreground/current route only.
- [ ] App pause stops polling.
- [ ] Resume performs current refresh.
- [ ] Transient failure retains stale snapshot.
- [ ] No repeated Snackbar spam.
- [ ] 429 pauses polling until explicit Retry.
- [ ] closed/archived/not-active/404 stops polling.
- [ ] route/session loss stops publication.

---

# 124. Acceptance Criteria — Desktop Monitoring

- [ ] Monitor route available.
- [ ] Summary visible.
- [ ] Student operational state visible.
- [ ] #1/#2 labels accurate.
- [ ] remaining is server snapshot.
- [ ] terminal reason visible.
- [ ] exception details visible.
- [ ] no score.
- [ ] no answer/question/file content.
- [ ] grant action only plausible #1 terminal candidate.

---

# 125. Acceptance Criteria — Exception Grant

- [ ] Desktop only.
- [ ] Grant requires currently confirmed FE-001 Topic/Blitz parent identity.
- [ ] Parent identity loss/mismatch prevents key generation and Grant POST.
- [ ] exact reason type values.
- [ ] mandatory trimmed reason <= 4000.
- [ ] required Idempotency-Key.
- [ ] one logical grant one key.
- [ ] grant DTO uses its own exception availability truth table, not Active-monitoring invariant.
- [ ] `null + available=true` accepted for active unused grant.
- [ ] `null + available=false` accepted for historical unused-but-unavailable grant replay.
- [ ] `replacement ID + available=false` accepted after #2 start.
- [ ] `replacement ID + available=true` rejected.
- [ ] success does not fabricate Attempt #2.
- [ ] success refreshes monitoring when available without making monitoring proof of the grant.
- [ ] uncertain does not auto-replay.
- [ ] explicit Retry same key.
- [ ] same-key Retry can confirm historical grant after Close/Archive.
- [ ] lifecycle-ended Check monitoring retains the key because Active-only monitoring cannot prove grant history.
- [ ] already-granted state reconciled.
- [ ] no revoke/edit/second grant.
- [ ] no score-based eligibility.

---

# 126. Acceptance Criteria — Mobile Runtime

- [ ] Blitz detail remains readable.
- [ ] Draft/Scheduled Activate available.
- [ ] activation uses same FE-003 controller/state/key semantics.
- [ ] mobile same-key activation Retry accepts current Active/Closed/Archived replay exactly as desktop.
- [ ] Closed/Archived replay is confirmed success and never reopens the Blitz.
- [ ] replay adoption removes actions inconsistent with the returned current lifecycle.
- [ ] Schedule unavailable.
- [ ] Official mutation unavailable.
- [ ] Close unavailable.
- [ ] Archive unavailable.
- [ ] Edit/Questions unavailable.
- [ ] Active Blitz Monitor available.
- [ ] monitoring route works on mobile.
- [ ] mobile monitoring is basic/read-only.
- [ ] no exception reason/grant on mobile.

---

# 127. Acceptance Criteria — Mobile Activation Context

- [ ] Confirmed official Blitz is identified.
- [ ] confirmed non-official Blitz warns activation remains practice/supplementary.
- [ ] unconfirmed pair warns official status is unknown.
- [ ] warning does not block Activate.
- [ ] no result-pair mutation.
- [ ] mobile conflict guidance does not navigate to desktop-only authoring routes.

---

# 128. Acceptance Criteria — Routing / Async Safety

- [ ] canonical monitoring route exact.
- [ ] direct desktop/mobile entry.
- [ ] direct entry verifies Topic/Blitz relationship through FE-001 detail before monitoring.
- [ ] Topic A + Blitz from Topic B is safe notFound on desktop/mobile.
- [ ] nested router structure is not treated as relationship authority.
- [ ] bootstrap preserves matching monitoring route.
- [ ] Blitz detail classifier excludes monitoring route.
- [ ] authoring paths remain mobile-blocked.
- [ ] stale poll cannot overwrite another target.
- [ ] stale parent-identity generation cannot publish monitoring or Grant state.
- [ ] stale grant cannot show feedback on another Student/Blitz.
- [ ] session change clears private monitoring/grant state.
- [ ] polling pauses during grant mutation.

---

# 129. Scope Acceptance

- [ ] No Student frontend change.
- [ ] No backend change.
- [ ] No package/platform change.
- [ ] No WebSocket/SSE.
- [ ] No mobile authoring/scheduling/designation/close/archive.
- [ ] No mobile exception mutation.
- [ ] No scoring/checking/result UI.
- [ ] No answer/file monitoring exposure.
- [ ] Focused FE-006 tests pass.
- [ ] FE-001/002/003 direct regressions pass.
- [ ] focused analyze passes.
- [ ] format check passes.
- [ ] `git diff --check` passes.

---

# 130. Focused Diff Self-Check

Before completion confirm the diff implements only:

```text
Teacher live Blitz monitoring
+
desktop Student-specific exception grant
+
mobile Activate with FE-003 replay semantics
+
mobile basic monitoring
```

Verify specifically:

```text
no score/answer leakage
no mobile grant
no mobile Close/Archive/Schedule/Official
no auto-close
no client timeout finalization
no WebSocket
one 5-second foreground poller
grant same-key recovery
grant replay unused-but-unavailable after later Close/Archive
monitoring/grant exception invariants remain intentionally distinct
monitoring/grant require confirmed Topic/Blitz parent identity
activation same-key replay after later Close/Archive
```

Confirm every changed file is necessary.

---

# 131. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. monitoring domain/DTO contract and Topic/Blitz parent-identity guard;
4. polling lifecycle/cadence;
5. desktop monitoring UX;
6. mobile basic monitoring UX;
7. exception form/grant contract including grant-vs-monitoring DTO invariants;
8. grant Idempotency-Key, historical replay and uncertainty behavior;
9. mobile Activate extension including FE-003 same-key replay behavior;
10. official-state activation warning;
11. router/mobile bootstrap integration;
12. privacy/no-score boundary;
13. focused FE-006 test results;
14. FE-003 regression results;
15. FE-001/002/router regression results;
16. focused analyze result;
17. format check result;
18. `git diff --check`;
19. final `git status --short`;
20. focused scope/diff self-check;
21. any blocker/deviation.

Do not claim Stage 8 frontend complete until ChatGPT accepts this task and the
Frontend Phase 2 checkpoint passes.

After delivery ChatGPT performs read-only acceptance review.

The next required gate is:

```text
S08-FE-PHASE-2
```

not another frontend feature task.

---

# 132. Implementation Readiness Verdict

```text
Scope / non-goals                    = RESOLVED
Monitoring endpoint/domain           = RESOLVED
Monitoring strict DTO                = RESOLVED
Topic/Blitz parent identity guard    = RESOLVED
Operational Student states           = RESOLVED
Summary invariants                   = RESOLVED
No-score/no-answer boundary          = RESOLVED
Monitoring route                     = RESOLVED
Desktop/mobile routing               = RESOLVED
5-second polling                     = RESOLVED
Foreground/app lifecycle polling     = RESOLVED
Rate-limit behavior                  = RESOLVED
Desktop monitoring UX               = RESOLVED
Mobile basic monitoring UX           = RESOLVED
Exception grant candidate UX         = RESOLVED
Exception reason form                = RESOLVED
Grant API                            = RESOLVED
Grant Idempotency-Key                = RESOLVED
Grant unused-unavailable replay      = RESOLVED
Grant unknown/retry/check            = RESOLVED
No revoke/edit                       = RESOLVED
Mobile Activate capability           = RESOLVED
Activation replay desktop/mobile     = RESOLVED
Mobile unsupported lifecycle actions = RESOLVED
Official-state activation warning    = RESOLVED
Session/target stale safety          = RESOLVED
Accessibility/responsiveness         = RESOLVED
Focused tests                        = RESOLVED
Focused verification                 = RESOLVED

Implementation Readiness Gate        = PASS
Execution dependency                 = S08-FE-005 Accepted / Delivered
Next gate after acceptance            = S08-FE-PHASE-2
```
