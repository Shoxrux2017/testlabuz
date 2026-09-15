# Codex Implementation Contract: S08-FE-004 — Student Active Blitz, Detail, Start/Resume and Countdown

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-FE-004` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter Student active-Blitz discovery + pre-Start detail + idempotent Start/Resume + server-anchored countdown shell` |
| Depends on | `S08-FE-001…003 Accepted / Delivered`; `S08-BE-PHASE-2 = PASS` remains valid |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Runtime implementation baseline | ChatGPT must re-check/freeze current `origin/main` immediately before Codex execution |
| Backend API dependency | Final delivered Stage 8 Student Blitz active/detail/Start APIs after Backend Phase 2 PASS |
| Flutter toolchain | Use repository current FVM-pinned Flutter version at implementation time |
| Implementation Readiness Gate | `PASS — planning contract`; execution remains dependency-gated |
| Verification | `Codex — focused frontend verification only` |
| Delivery execution | `Project Owner` |
| Frontend block checkpoint | `S08-FE-PHASE-2` after `S08-FE-001…006` are `Accepted / Delivered` |
| Blocks | `S08-FE-005` |

Do not start until:

```text
S08-FE-001…003 = Accepted / Delivered
S08-BE-PHASE-2 = PASS
current origin/main re-checked
final Student Blitz active/detail/Start backend resources inspected
current Stage 7 Student Homework session/idempotency/question infrastructure inspected
clean synchronized local main
```

If delivered dependencies materially conflict with this contract:

```text
BLOCKED
```

with exact evidence.

Do not invent a new Student Blitz API, Attempt GET route, timer authority, or
execution lifecycle.

This file is the complete task-specific implementation contract.

Do **not** create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. delivered S08-FE-001…003 source/tests directly required here;
5. final delivered Stage 8 Student Blitz active/detail/Start resources/routes
   directly required to confirm the API already encoded below;
6. current Stage 7 Student Homework read/Start/Attempt/session/routing code
   directly required as architecture/reuse reference;
7. shared Student Question/answer-state/idempotency/error infrastructure required
   by this task.

Do **not** read:

- roadmap/product docs;
- previous Stage 8 task files;
- Stage history;
- checkpoint reviews;
- closure reviews;
- unrelated features

to infer behavior.

This contract resolves:

- where active Blitz appears;
- Blitz Student domain/DTOs;
- strict active-list/detail/timing parsing;
- pre-Start Question secrecy;
- Start vs Resume vs replacement-start UX;
- Start idempotency key lifetime;
- no unsafe Attempt deep-link route;
- execution-shell ownership;
- Attempt DTO including terminal replay states;
- shared Student Question/answer-state reuse;
- synchronized/individual/replacement timing UX;
- server-anchored countdown;
- zero-time reconciliation;
- device clock non-authority;
- session/target/stale completion safety;
- mobile/desktop support;
- accessibility/responsiveness;
- focused verification.

---

# 3. Goal

Enable Student Blitz entry and timed execution foundation on desktop and mobile.

A Student must be able to:

1. see all currently startable/resumable Blitz tasks returned by the server;
2. see Topic context for each active Blitz;
3. open an assigned active Blitz;
4. read Blitz instructions and authoritative timing metadata **without seeing
   Questions before Start**;
5. understand whether the task uses:
   ```text
   synchronized
   individual
   ```
   timing;
6. explicitly:
   ```text
   Start Blitz
   Resume Blitz
   Start additional attempt
   ```
   depending on authoritative server state;
7. safely retry an uncertain Start using the same Idempotency-Key;
8. receive the full Attempt resource only after successful Start/Resume;
9. then see the Student-safe Questions;
10. see a live countdown anchored to server-provided remaining time;
11. preserve replacement Attempt timing semantics;
12. reconcile safely when the timer reaches zero.

This task creates the execution foundation only.

`S08-FE-005` owns:

```text
typed answer editors
file answer UX
answer mutation orchestration
final Submit
terminal reconciliation UX
```

---

# 4. Explicit Non-Goals

Do **not** implement:

- Teacher Blitz UI;
- answer PUT;
- non-file answer editors;
- file picker/upload/download;
- Submit;
- Submit Idempotency-Key;
- score/checking/review UI;
- result comparison;
- Topic result;
- Parent result UI;
- automatic retry queue;
- offline persistence;
- push/WebSocket;
- background service;
- Attempt history screen;
- historical terminal Attempt route;
- Student attempt-exception request/grant;
- local timeout finalization;
- client-side lifecycle authority;
- device-clock deadline authority;
- per-question timers;
- new package;
- backend changes;
- platform changes;
- full frontend suite/build/E2E.

Do not render disabled answer/Submit controls as placeholders.

---

# 5. Critical API / Routing Decision — No Blitz Attempt Deep-Link Route

Stage 8 backend intentionally exposes:

```text
GET  /student/blitz/active
GET  /student/blitz/{blitz}
POST /student/blitz/{blitz}/attempts
```

and does **not** expose:

```text
GET /student/blitz/{blitz}/attempts/{attempt}
GET /student/attempts/{attempt}
```

for Blitz Attempt read.

Therefore FE-004 must **not** invent a canonical Flutter route such as:

```text
/student/topics/{topic}/blitz/{blitz}/attempts/{attempt}
```

that cannot be safely reconstructed from a read API.

It must also **not** auto-call Start POST on route/deep-link load merely to
reconstruct an Attempt.

Reason:

> A Start POST may create an unused replacement Attempt #2 when an exception
> exists. Opening/reloading a URL must never create a new Attempt without an
> explicit Student Start/Resume action.

Approved architecture:

```text
/student/topics/{topicId}/blitz/{blitzId}
```

is both:

- pre-Start Blitz detail; and
- post-Start execution shell route.

Questions appear only after an explicit Start/Resume succeeds in the current
route session.

If the Student leaves/reloads and later returns, the detail shows:

```text
Resume Blitz
```

when backend says an Attempt is in progress.

The Student explicitly presses Resume, which safely calls the idempotent Start
endpoint and returns the authoritative Attempt again.

This is intentional.

---

# 6. Public Backend Dependencies

Configured Dio base includes:

```text
/api/v1
```

Use exactly:

## Active list

```text
GET /student/blitz/active
```

No query.

No body.

Success:

```text
200
```

## Detail

```text
GET /student/blitz/{blitzId}
```

No query/body.

Success:

```text
200
```

## Start / Resume / Replacement Start

```text
POST /student/blitz/{blitzId}/attempts
```

Header:

```http
Idempotency-Key: <uuid>
```

The body carries the Student's exact intent.

Normal Start:

```json
{
  "intent": "start_normal"
}
```

Resume:

```json
{
  "intent": "resume",
  "attempt_id": "attempt-uuid"
}
```

Replacement Start after explicit confirmation:

```json
{
  "intent": "start_replacement"
}
```

No query.

Success:

```text
201 = a new Attempt was created
200 = the same intent path returned an already in-progress Attempt
```

The frontend must never send an empty `{}` Start body.

Messages:

```text
201 -> Blitz attempt started successfully.
200 -> Blitz attempt resumed successfully.
```

No other Student Blitz endpoint is called in FE-004.

---

# 7. Student Blitz Route

Add:

```text
AppRouteNames.studentBlitzDetail
```

Segments:

```text
studentBlitzSegment = 'blitz'
studentBlitzIdParameter = 'blitzId'
```

Canonical route:

```text
/student/topics/:topicId/blitz/:blitzId
```

Nest under:

```text
studentTopicDetail
```

parallel to Homework detail.

Supported:

```text
desktop
mobile
```

No device-surface restriction.

---

# 8. Route Target

Create immutable:

```text
StudentBlitzRouteTarget
```

Fields:

```text
topicId
blitzId
```

Require canonical UUIDs.

Normalize equality/hash consistently with current Student Homework route target.

Do not include Attempt ID.

Do not include title/timing in route identity.

---

# 9. Route Helpers

Add:

```text
studentBlitzDetailLocation(topicId, blitzId)
isStudentBlitzDetailPath(path)
studentBlitzIdFromPath(path)
```

Update exact Student route classification.

After FE-004:

```text
isStudentTopicDetailPath
```

remains true only for exact Topic detail.

```text
isStudentHomeworkDetailPath
```

remains true only for exact Homework detail.

```text
isStudentHomeworkAttemptPath
```

remains true only for existing Homework Attempt route.

```text
isStudentBlitzDetailPath
```

is true only for:

```text
/student/topics/<uuid>/blitz/<uuid>
```

Update:

```text
studentTopicIdFromPath
isStudentApprovedLocation
```

so exact Blitz detail is supported.

Reject malformed/extra/query/fragment route variants according to current router
safety behavior.

Do not modify Homework route semantics.

---

# 10. Router Bootstrap / Direct Entry

Valid Student Blitz detail must survive current authenticated/bootstrap location
handling on:

```text
desktop
mobile
```

Wrong role/session still resolves through existing destination guards.

Direct entry to a valid Blitz route:

- loads pre-Start detail only;
- never auto-starts;
- never reveals Questions before explicit Student action.

---

# 11. Active Blitz Placement

The backend active list is **global across the Student's currently eligible
Blitz tasks** and accepts no Topic filter.

Therefore place the read surface in:

```text
StudentLearningWorkspaceScreen
```

as:

```text
Active Blitz
```

above or before:

```text
My Topics
```

Recommended order:

```text
Active Blitz
My Topics
```

Reason:

> Blitz is time-sensitive and the endpoint already represents the Student's
> complete current execution queue.

Do not locally split/filter the server collection by Topic and create multiple
network-backed sections.

Do not add a second active-list fetch inside every Topic detail.

---

# 12. Active List Domain — Status

Create:

```text
StudentBlitzStatus
```

For FE-004 successful Student Blitz resources the only valid status is:

```text
active
```

Parser:

```text
active -> StudentBlitzStatus.active
anything else -> FormatException
```

Closed/Archived/Draft/Scheduled are returned as conflicts, not successful
Student execution detail.

Do not broaden successful parsing “for future use”.

---

# 13. Student Blitz Timer Mode

Create:

```text
StudentBlitzTimerMode
```

Exact:

```text
synchronized
individual
```

No nullable mode in a successful active Student Blitz resource.

Activation snapshot is authoritative.

---

# 14. Topic Summary

Create reusable:

```text
StudentBlitzTopicSummary
```

Fields:

```text
id
title
```

Require:

- canonical UUID;
- non-blank title.

Do not create a second Student Topic detail model.

---

# 15. Attempt Usage Summary

Create:

```text
StudentBlitzAttemptSummary
```

Fields:

```text
normalAttempts
normalUsed
inProgressAttemptId
additionalExceptionGranted
replacementAttemptAvailable
```

Exact fixed contract:

```text
normalAttempts = 1
normalUsed in 0..1
inProgressAttemptId nullable canonical UUID
additionalExceptionGranted bool
replacementAttemptAvailable bool
```

---

# 16. Attempt Summary Cross-Invariants

Require:

```text
normalAttempts == 1
```

If:

```text
normalUsed == 0
```

then:

```text
additionalExceptionGranted == false
replacementAttemptAvailable == false
```

and:

```text
inProgressAttemptId == null
```

or the parser may accept `normalUsed == 1` for any persisted Attempt.

Because the backend counts a created normal Attempt as used, a non-null
`inProgressAttemptId` requires:

```text
normalUsed == 1
```

If:

```text
additionalExceptionGranted == true
```

require:

```text
normalUsed == 1
```

If:

```text
replacementAttemptAvailable == true
```

require:

```text
additionalExceptionGranted == true
inProgressAttemptId == null
```

Do not try to infer #1/#2 solely from this summary.

Attempt number becomes authoritative only after Start/Resume returns the Attempt.

---

# 17. Timing Domain

Create:

```text
StudentBlitzTiming
```

Fields:

```text
mode
serverNow
synchronizedEndsAt
deadlineAt
remainingSeconds
```

Types:

- server/timestamps: canonical whole-second UTC `DateTime`;
- remaining: nullable non-negative int.

Before parsing to `DateTime`, require the wire timestamp string itself to match:

```text
YYYY-MM-DDTHH:MM:SSZ
```

Reject fractional forms such as:

```text
YYYY-MM-DDTHH:MM:SS.500Z
```

and reject non-`Z` offset forms for these Stage 8 timer fields.

A small shared strict UTC-second parser is preferred over duplicated DTO string
logic.

No device timezone conversion is used for execution authority.

---

# 18. Timing Base Integrity

For every successful timing block:

```text
serverNow != null
remainingSeconds == null || remainingSeconds >= 0
```

If:

```text
deadlineAt != null
```

require:

```text
deadlineAt >= serverNow
remainingSeconds != null
```

and require exact response-snapshot consistency:

```text
remainingSeconds
==
max(
  0,
  deadlineAt.millisecondsSinceEpoch ~/ 1000
  - serverNow.millisecondsSinceEpoch ~/ 1000
)
```

Because both accepted timestamps are exact whole-second instants, this is the
same integer difference returned by backend; there is no hidden fractional
remainder.

Backend uses one canonical whole-second server request snapshot.

If:

```text
deadlineAt == null
```

require:

```text
remainingSeconds == null
```

except no other shape is accepted.

---

# 19. Synchronized Timing Integrity

For:

```text
mode = synchronized
```

require:

```text
synchronizedEndsAt != null
```

There are three legitimate effective timing shapes.

## Normal Start available / normal in-progress #1

If:

```text
replacementAttemptAvailable == false
additionalExceptionGranted == false
```

then pre-Start or #1 timing may use:

```text
deadlineAt = synchronizedEndsAt
remainingSeconds = synchronizedEndsAt - serverNow
```

when the task is still startable/resumable.

## Replacement available but not started

When:

```text
replacementAttemptAvailable == true
```

require effective replacement timing:

```text
deadlineAt = null
remainingSeconds = null
```

while preserving historical:

```text
synchronizedEndsAt != null
```

even if the class common end is in the past.

## Replacement #2 in progress

When:

```text
additionalExceptionGranted == true
inProgressAttemptId != null
replacementAttemptAvailable == false
```

the effective:

```text
deadlineAt
```

comes from replacement Attempt #2 and may be **later than**
`synchronizedEndsAt`.

Do not require equality to common class end in this case.

---

# 20. Individual Timing Integrity

For:

```text
mode = individual
```

require:

```text
synchronizedEndsAt = null
```

## Before effective Attempt starts

```text
deadlineAt = null
remainingSeconds = null
```

This includes:

- normal #1 not started;
- replacement #2 available but not started.

## In-progress Attempt

```text
inProgressAttemptId != null
deadlineAt != null
remainingSeconds != null
```

The deadline is the persisted current Attempt deadline.

---

# 21. Active List Item Domain

Create:

```text
StudentActiveBlitzSummary
```

Fields:

```text
id
topic
title
status
durationSeconds
timing
attempts
```

No:

```text
description
studentInstructions
totalPossiblePoints
questions
answers
```

in the active list model.

`durationSeconds` must be positive.

---

# 22. Active List Exact Item Shape

Strict exact keys:

```text
id
topic
title
status
duration_seconds
timing
attempts
```

Unknown/missing key:

```text
FormatException
```

This deliberately rejects accidental Question leakage.

---

# 23. Active List Envelope

Exact success:

```json
{
  "data": []
}
```

Require exact envelope keys:

```text
data
```

No pagination.

No query-state model.

No meta.

No links.

Duplicate Blitz IDs are invalid.

Ordering is server-authoritative.

Do not re-sort in Flutter.

---

# 24. Active List Eligibility Trust

The server collection already includes only currently:

```text
startable
resumable
replacement-startable
```

Blitz tasks.

Frontend must not recreate full eligibility rules.

Do not locally remove a row because:

- synchronized common end appears passed on device clock;
- current Group membership is unknown;
- Student thinks attempts are used;
- local timer drifted.

The current API response is authoritative.

The UI may locally mark its rendered countdown as expired after monotonic elapsed,
but actual collection membership changes only after server refresh.

---

# 25. Blitz Detail Domain

Create:

```text
StudentBlitzDetail
```

Fields:

```text
id
topic
title
description
studentInstructions
status
durationSeconds
totalPossiblePoints
timing
attempts
```

Critically there is **no**:

```text
questions
answers
```

field.

Do not add optional Question fields.

The absence is a security boundary.

---

# 26. Detail Exact Keys

Strict exact successful resource keys:

```text
id
topic
title
description
student_instructions
status
duration_seconds
total_possible_points
timing
attempts
```

If successful detail unexpectedly includes:

```text
questions
answer_ui
answers
```

strict parsing fails as invalidResponse.

Do not silently ignore pre-Start Question leakage.

---

# 27. Detail Lifecycle Response Handling

Expected success:

```text
200 active detail
```

Stable conflicts:

## `blitz_not_active`

Map to:

```text
StudentBlitzDetailStatus.notActive
```

UI:

```text
This Blitz is no longer active.
```

## `blitz_time_expired`

Map to:

```text
StudentBlitzDetailStatus.timeExpired
```

UI:

```text
The Blitz time has expired.
```

## `resource_not_found`

Map to:

```text
notFound
```

Do not treat known execution conflicts as generic network error.

---

# 28. Detail Topic Hierarchy

Backend detail endpoint is keyed by Blitz ID.

Flutter route includes Topic ID.

After a successful resource require:

```text
blitz.topic.id == target.topicId
```

case-insensitively.

Mismatch:

```text
notFound
```

Do not display a Blitz under another Topic route.

---

# 29. Shared Student Question Reuse

Reuse exactly:

```text
StudentQuestion
StudentQuestionType
StudentAnswerUi
StudentQuestionDto
StudentQuestionReadView
```

from Stage 7.

Do not create:

```text
StudentBlitzQuestion
StudentBlitzQuestionDto
```

The safe Question transport is Assessment-generic.

Questions are parsed only inside a successful Start/Resume Attempt resource.

---

# 30. Shared Saved-Answer Domain Extraction

Stage 7 currently keeps reusable saved-answer classes in the Homework-named
Attempt domain.

Because Blitz Start/Resume after BE-006 returns:

```text
answers
```

extract the truly shared answer-state domain into a type-neutral file, for
example:

```text
frontend/lib/features/student/domain/student_attempt_answer.dart
```

Move/reuse without behavior change:

```text
StudentAttemptAnswerState
StudentAttemptAnswerValue
StudentChoiceAnswerValue
StudentBooleanAnswerValue
StudentTextAnswerValue
StudentMatchingAnswerPair
StudentMatchingAnswerValue
StudentOrderingAnswerItem
StudentOrderingAnswerValue
StudentFillBlankAnswerEntry
StudentFillBlankAnswerValue
StudentSubmissionFile
StudentFileAnswerValue
```

Update Homework Attempt domain imports.

Do not duplicate these classes for Blitz.

---

# 31. Shared Saved-Answer DTO Extraction

Likewise extract the current reusable saved-answer parsing/integrity from
`StudentHomeworkAttemptDto` into a focused shared parser, conceptually:

```text
StudentAttemptAnswerStateDtoParser
```

or equivalent.

It must continue validating against the exact safe:

```text
StudentQuestion
```

set.

Reuse for:

```text
Homework Attempt DTO
Blitz Attempt DTO
```

Homework behavior must remain identical.

Do not weaken:

- child ID ownership;
- exact text preservation;
- file metadata safety;
- duplicate answer Question-ID checks.

---

# 32. Blitz Attempt Status Domain

Create:

```text
StudentBlitzAttemptStatus
```

Exact values:

```text
inProgress          -> in_progress
submitted           -> submitted
timedOutFinalized   -> timed_out_finalized
waitingForReview    -> waiting_for_teacher_review
checked             -> checked
```

Unknown:

```text
FormatException
```

FE-004 itself does not create review/checked states but parser remains compatible
with backend resource evolution already included in Stage 8.

---

# 33. Blitz Finalization Reason Domain

Create:

```text
StudentBlitzAttemptFinalizationReason
```

Exact:

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

# 34. Blitz Attempt Timing Domain

Create:

```text
StudentBlitzAttemptTiming
```

Fields:

```text
serverNow
mode
remainingSeconds
```

Require:

```text
remainingSeconds >= 0
```

This timing block does not need to repeat deadline because Attempt has:

```text
deadlineAt
```

---

# 35. Blitz Attempt Domain

Create:

```text
StudentBlitzAttempt
```

Fields:

```text
id
assessmentId
attemptNumber
status
startedAt
deadlineAt
submittedAt
finalizedAt
finalizationReason
timing
questions
answers
```

Attempt number:

```text
1..2
```

Exactly:

```text
#1 normal
#2 exception replacement
```

No #3.

Questions/answers immutable.

---

# 36. Attempt Exact Resource Keys

Strict exact keys:

```text
id
assessment_id
attempt_number
status
started_at
deadline_at
submitted_at
finalized_at
finalization_reason
timing
questions
answers
```

If final delivered backend uses the same exact shape after BE-006/007/008/009,
parse it.

If Backend Phase 2 materially changes this shape, stop before implementation and
report the mismatch.

Do not accept score/checking fields.

---

# 37. Attempt Lifecycle Integrity — In Progress

For:

```text
status = in_progress
```

require:

```text
startedAt != null
deadlineAt != null
deadlineAt > startedAt
submittedAt = null
finalizedAt = null
finalizationReason = null
timing.remainingSeconds >= 0
```

Require:

```text
timing.mode
```

matches the active Blitz detail/list timer snapshot when both are available.

For current response:

```text
timing.remainingSeconds
==
max(0, deadlineAt - timing.serverNow)
```

---

# 38. Attempt Lifecycle Integrity — Explicit Submit

For terminal:

```text
status = submitted
reason = student_submit
```

require:

```text
submittedAt != null
finalizedAt != null
submittedAt == finalizedAt
finalizedAt < deadlineAt
timing.remainingSeconds = 0
```

FE-004 does not Submit but Start same-key replay may return this later-terminal
Attempt.

---

# 39. Attempt Lifecycle Integrity — Timeout

For:

```text
status = timed_out_finalized
reason = timeout_auto_submit
```

require:

```text
submittedAt = null
finalizedAt == deadlineAt
timing.remainingSeconds = 0
```

This is a valid Start idempotency replay result.

Do not enter editable execution shell.

---

# 40. Attempt Lifecycle Integrity — Teacher Close

For:

```text
status = submitted
reason = task_closed_auto_finalize
```

require:

```text
submittedAt = null
finalizedAt != null
finalizedAt < deadlineAt
timing.remainingSeconds = 0
```

At/equal deadline timeout reason must have won.

---

# 41. Forward-Compatible Waiting / Checked

For:

```text
waiting_for_teacher_review
checked
```

require terminal finalization metadata consistent with one of:

```text
student_submit
timeout_auto_submit
task_closed_auto_finalize
```

Use the same timestamp rules.

FE-004 renders them terminal/read-only only.

No score UI.

---

# 42. Attempt Questions Integrity

Reuse `StudentQuestionDto`.

Require:

- Question IDs unique;
- positions exactly `1..N`;
- returned order canonical;
- no correct-answer leakage through the safe Question parser.

Question count may be zero only if backend returned such a valid Attempt fixture;
normal activation should have scoreable Questions.

Do not invent Questions from the pre-Start detail.

---

# 43. Attempt Answers Integrity

Use shared extracted saved-answer parser.

Require:

- answer Question IDs unique;
- every answer references returned Question;
- type exact;
- child IDs belong to safe Question;
- no checking/score metadata.

Unanswered Questions have no answer entry.

Do not fabricate empty answer state.

---

# 44. Start Result Domain

Create:

```text
StudentBlitzAttemptStartResult
```

Fields:

```text
attempt
resultKind
```

Enum:

```text
created
resumed
```

Map from HTTP status only:

```text
201 -> created
200 -> resumed
```

Do not infer result kind from attempt number.

Attempt #2 creation is still:

```text
created
```

## 44.1 Student execution request intent

Create:

```text
StudentBlitzAttemptIntent
```

with exact wire values:

```text
startNormal      -> start_normal
resume           -> resume
startReplacement -> start_replacement
```

Create one immutable pending execution request value, conceptually:

```text
StudentBlitzAttemptRequest
```

carrying:

```text
intent
attemptId nullable
idempotencyKey
```

Invariants:

```text
startNormal      => attemptId = null
startReplacement => attemptId = null
resume           => attemptId = canonical UUID
```

The pending request object is the semantic retry identity. An uncertain Retry
must resend the same:

```text
intent
attemptId
Idempotency-Key
```

It must not recompute intent from newly refreshed detail.

---

# 45. Start Success Message Strictness

Require exact:

## 201

```text
Blitz attempt started successfully.
```

## 200

```text
Blitz attempt resumed successfully.
```

Envelope exact:

```text
data
message
```

Do not accept a mismatched message/status pair as confirmed success.

A malformed possible-success response is outcome-uncertain.

---

# 46. Student Blitz Repository Boundaries

Create:

```text
StudentBlitzRepository
```

for:

```text
fetchActiveBlitz()
fetchBlitz(blitzId)
```

Create a dedicated execution repository:

```text
StudentBlitzAttemptRepository
```

with intent-explicit methods:

```text
startNormal(blitzId, idempotencyKey)
resume(blitzId, attemptId, idempotencyKey)
startReplacement(blitzId, idempotencyKey)
```

or one typed method accepting the exact immutable
`StudentBlitzAttemptRequest`. In either form, invalid intent/Attempt-ID
combinations must be unrepresentable or rejected before Dio.

Reason:

```text
StudentBlitzRepository
= read list/detail

StudentBlitzAttemptRepository
= high-risk intent-specific execution mutation
```

Do not put Start into a presentation/controller direct Dio call.

No Attempt GET method exists.

---

# 47. Active List Remote Data Source

Call exactly:

```dart
dio.get<Object?>(
  '/student/blitz/active',
  options: Options(followRedirects: false),
)
```

No query.

No body.

Require:

```text
200
```

Strict parse `{data}` collection.

---

# 48. Detail Remote Data Source

Call:

```dart
dio.get<Object?>(
  '/student/blitz/${Uri.encodeComponent(blitzId)}',
  options: Options(followRedirects: false),
)
```

No query/body.

Require:

```text
200
```

Known 404/409 errors map through stable machine codes.

---

# 49. Start / Resume Remote Data Source

Call the same endpoint with one exact intent body.

## Normal Start

```dart
dio.post<Object?>(
  '/student/blitz/${Uri.encodeComponent(blitzId)}/attempts',
  data: const <String, Object?>{
    'intent': 'start_normal',
  },
  options: Options(
    followRedirects: false,
    headers: {
      'Idempotency-Key': idempotencyKey,
    },
  ),
)
```

## Resume exact Attempt

```dart
dio.post<Object?>(
  '/student/blitz/${Uri.encodeComponent(blitzId)}/attempts',
  data: <String, Object?>{
    'intent': 'resume',
    'attempt_id': attemptId,
  },
  options: Options(
    followRedirects: false,
    headers: {
      'Idempotency-Key': idempotencyKey,
    },
  ),
)
```

Validate canonical `attemptId` before network.

## Replacement Start

```dart
dio.post<Object?>(
  '/student/blitz/${Uri.encodeComponent(blitzId)}/attempts',
  data: const <String, Object?>{
    'intent': 'start_replacement',
  },
  options: Options(
    followRedirects: false,
    headers: {
      'Idempotency-Key': idempotencyKey,
    },
  ),
)
```

No query.

Accept only:

```text
200
201
```

Strict envelope/message/resource and intent-specific success validation.

No automatic Dio retry.

---

# 50. Active List Controller

Create autoDispose:

```text
studentActiveBlitzControllerProvider
StudentActiveBlitzController
StudentActiveBlitzState
```

Not family-keyed because backend list is global for current Student.

State:

```text
initial
loading
data
refreshing
error
```

Fields:

```text
items
failure
isStale
```

No pagination/query/search.

---

# 51. Active List Session Ownership

Bind to:

```text
StudentSessionKey
generation
```

On session loss/switch:

- clear items;
- invalidate generation;
- old completion cannot publish.

Refresh:

- retains current items;
- state `refreshing`.

Refresh failure with retained items:

```text
error
isStale = true
```

Initial failure has no data.

Do not preserve one Student's Blitz list into another session.

---

# 52. Active List Refresh After Execution Changes

Provide focused method:

```text
refreshAfterExecution(StudentSessionKey originatingSessionKey)
```

or equivalent.

Used after:

- Start/Resume success;
- deterministic expiry/not-active/exhausted reconciliation;
- local countdown expiry reconciliation.

Requirements:

- reject stale session;
- invalidate older in-flight list request;
- refresh server list;
- retain current cards while refreshing when present.

Do not optimistically remove/add cards.

---

# 53. Student Workspace Integration

Add:

```text
StudentActiveBlitzSection
```

inside `StudentLearningWorkspaceScreen`.

The section is independent from Topic list loading.

One failed active-Blitz request must not make the Topic list unusable.

Recommended layout:

```text
Active Blitz card/section
spacing
My Topics card/section
```

Both remain scrollable within current workspace shell.

---

# 54. Active Section States

## Loading

```text
Loading active Blitz tasks
```

progress semantics.

## Data

Cards.

## Empty

```text
No active Blitz tasks are available right now.
```

## Initial error

```text
Active Blitz tasks could not be loaded.
```

Retry.

## Stale refresh error

Retain cards and show:

```text
The active Blitz list may be out of date.
```

Refresh/Retry.

---

# 55. Active Blitz Card

Display:

```text
title
Topic title
timer mode
duration
effective remaining state
attempt path
```

Attempt path text:

## `normalUsed == 0`

```text
Not started
```

## `inProgressAttemptId != null && !additionalExceptionGranted`

```text
In progress
```

## `replacementAttemptAvailable`

```text
Additional attempt available
```

## `inProgressAttemptId != null && additionalExceptionGranted`

```text
Additional attempt in progress
```

Do not label a replacement a second “normal attempt”.

---

# 56. Active List Timing Display

FE-004 does not create one `Timer.periodic` per active-list card.

Render server-snapshot timing in compact form.

Examples:

## Synchronized normal path

```text
Class time remaining: 4 min 12 sec
```

using returned `remainingSeconds`.

Label it as server snapshot where helpful:

```text
Time at last refresh
```

## Individual pre-Start

```text
Full 10 min starts when you start.
```

## Replacement available

```text
Full 10 min additional attempt starts when you start.
```

## In-progress

```text
Attempt time remaining at last refresh: ...
```

The detail/execution screen owns live countdown.

---

# 57. Active Card Navigation

Card action:

```text
Open Blitz
```

or whole-card InkWell.

Navigate:

```text
studentBlitzDetailLocation(
  item.topic.id,
  item.id,
)
```

Semantics:

```text
Open Blitz <title>
```

No Start from workspace card.

Opening a card never creates an Attempt.

---

# 58. Blitz Detail Controller

Create family:

```text
studentBlitzDetailControllerProvider(target)
StudentBlitzDetailController
StudentBlitzDetailState
```

Statuses:

```text
initial
loading
data
refreshing
notFound
notActive
timeExpired
error
```

State:

```text
blitz
failure
```

Retained data allowed during refresh/error only according to explicit state
semantics.

New Start actions require confirmed:

```text
status == data
```

only.

---

# 59. Detail Session / Target Safety

Bind publication to:

```text
StudentSessionKey
StudentBlitzRouteTarget
generation
```

Stale completion cannot:

- replace another Blitz;
- publish after logout;
- publish across Institution/Student switch;
- publish after disposal;
- publish after newer refresh.

Use existing Student controller conventions.

---

# 60. Detail Refresh

Initial:

```text
loading
```

Refresh with current data:

```text
refreshing
retain blitz
```

Known `blitz_time_expired` during refresh:

- clear current actionable detail authority;
- state becomes `timeExpired`.

Known `blitz_not_active`:

- state `notActive`.

404:

- `notFound`.

A retained pre-conflict resource must not continue authorizing Start.

---

# 61. Detail Screen

Create:

```text
StudentBlitzDetailScreen
```

within canonical route.

Supported:

```text
desktop
mobile
```

App bar:

```text
Blitz
```

Back:

```text
Back to Topic
```

using route Topic ID.

Direct route entry always has a safe parent navigation.

---

# 62. Pre-Start Detail Content

Before a successful Start/Resume, show:

```text
title
Topic title
description
Student instructions
duration
total possible points
timer mode
attempt usage
exception availability
effective timing
Refresh
Start/Resume action if eligible
```

Do **not** render:

```text
Questions
answer structure
answers
correct-answer metadata
```

No Questions heading with “hidden” placeholders.

The screen should not reveal Question count unless backend detail actually
contains it; it does not.

---

# 63. Pre-Start Action Decision

Action is computed only from confirmed `data` detail.

## Existing in-progress Attempt

When:

```text
attempts.inProgressAttemptId != null
```

show:

```text
Resume Blitz
```

Do not navigate to another route.

Pressing it captures that exact:

```text
attempts.inProgressAttemptId
```

and sends:

```text
intent = resume
attempt_id = captured ID
```

The controller must not later substitute another Attempt ID because detail
changed concurrently.

## Replacement available

When:

```text
attempts.replacementAttemptAvailable == true
inProgressAttemptId == null
```

show:

```text
Start additional attempt
```

## Normal not started

When:

```text
normalUsed == 0
inProgressAttemptId == null
replacementAttemptAvailable == false
```

show:

```text
Start Blitz
```

## No execution capacity

No Start control.

Do not use device clock to hide/show an action.

Server detail success and attempt projection are the authority.

---

# 64. Start Confirmation

For normal `Start Blitz`, confirmation is required because starting may begin the
authoritative timer.

## Synchronized normal mode

Title:

```text
Start Blitz?
```

Body includes:

```text
This Blitz uses a shared class timer.
You will receive only the time remaining on the server.
Starting does not reset the class timer.
```

## Individual normal mode

Body:

```text
Your full Blitz duration starts when the server starts your attempt.
```

Buttons:

```text
Cancel
Start
```

No Start POST before confirmation.

---

# 65. Resume Confirmation

For confirmed in-progress Attempt:

A separate destructive confirmation is not required.

Button:

```text
Resume Blitz
```

may immediately invoke the intent-specific Resume POST for the exact
`inProgressAttemptId` captured from the confirmed detail.

Reason:

- the Attempt already exists;
- backend Resume does not reset timer;
- Resume cannot create another Attempt;
- user is explicitly continuing that exact execution.

While request is in flight disable repeat presses.

If that exact Attempt becomes terminal or invalidated before the server decides,
the backend returns the documented conflict. The frontend refreshes authoritative
state; it must not automatically issue `start_replacement`.

---

# 66. Replacement Start Confirmation

For:

```text
replacementAttemptAvailable == true
```

require confirmation.

Title:

```text
Start additional Blitz attempt?
```

Body:

```text
Your original attempt remains in history.
This approved additional attempt receives the full configured Blitz duration from the moment the server starts it.
```

For synchronized mode also state:

```text
The original class timer does not restart for other Students.
```

Buttons:

```text
Cancel
Start additional attempt
```

No POST before confirmation.

After confirmation send exactly:

```text
intent = start_replacement
```

with a newly generated logical-operation Idempotency-Key.

Do not call Resume and do not derive replacement creation from server state
behind a generic request.

---

# 67. Start Controller

Create:

```text
StudentBlitzAttemptStartController
StudentBlitzAttemptStartState
```

Family target:

```text
StudentBlitzRouteTarget
```

Statuses:

```text
idle
submitting
uncertain
active
terminal
failure
```

State may hold:

```text
attempt
resultKind
failure
feedback
originatingIntent
requestedAttemptId
```

Private controller state additionally owns the immutable pending execution
request (`intent + attemptId + Idempotency-Key`) for uncertain retry.

Do not expose raw idempotency key to Widget.

---

# 68. Start Controller Session Ownership

Bind to:

```text
StudentSessionKey
StudentBlitzRouteTarget
generation
```

On session/target loss:

- clear pending key;
- clear active Attempt from this route-session controller;
- invalidate generation.

No stale completion may reveal Questions in another session/Blitz.

---

# 69. Start Eligibility Re-Check

Before a **new logical POST** require:

```text
current detail status == data
same target
no Start operation in flight/uncertain
server-projected action exists
```

Do not rely on a stale retained detail.

Map the confirmed UI action exactly:

```text
Start Blitz
-> intent=start_normal

Resume Blitz
-> intent=resume
-> attempt_id = current confirmed inProgressAttemptId captured now

confirmed Start additional attempt
-> intent=start_replacement
```

Once the request begins, that intent/Attempt ID is frozen for this logical
operation. Later detail changes cannot rewrite it.

All three use the same endpoint but they are not interchangeable semantic
requests.

Do not inspect Question data before POST.

---

# 70. Idempotency Key Generator

Reuse existing:

```text
IdempotencyKeyGenerator
idempotencyKeyGeneratorProvider
```

from Stage 7.

Do not create another UUID generator.

One logical Student Start/Resume operation owns one key.

---

# 71. Execution Request / Idempotency-Key Lifetime

Private pending state is one immutable logical request:

```text
_pendingRequest = {
  intent,
  attemptId?,
  idempotencyKey
}
```

## User begins a new semantic action

Generate one key and freeze the exact request body.

This includes Resume.

## Confirmed valid success

Clear the whole pending request only after strict intent-specific
resource/message validation.

## Deterministic 4xx rejection

Clear the whole pending request.

## Uncertain outcome

Retain the exact same:

```text
intent
attemptId
Idempotency-Key
```

Retry resends that same request.

Do **not** refresh detail and then silently reinterpret the pending request as a
different Start/Resume/replacement action.

## Session/target loss

Clear pending request.

Do not persist it across unrelated route session.

---

# 72. Why Resume Also Uses a Key and Attempt ID

Backend requires Idempotency-Key on every Student execution POST.

A Resume with a new logical client operation uses:

```text
new Idempotency-Key
intent = resume
attempt_id = exact confirmed in-progress Attempt ID
```

Backend returns:

```text
200 that exact in-progress Attempt
```

and does not reset timer.

The explicit Attempt ID is what prevents a stale Resume from becoming a later
replacement Start if authoritative state changes before the server decision.

If its response is uncertain, retry must use the same key **and the same
attempt_id**.

---

# 73. Uncertain Start Classification

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

State:

```text
uncertain
```

UI:

```text
We could not confirm the Blitz attempt state.
Retry safely using the same request.
```

Action:

```text
Retry
```

Same key.

No separate new-key Start button.

No Questions revealed from local assumptions.

---

# 74. Deterministic Start Errors

Handle stable machine codes.

## `blitz_not_active`

```text
This Blitz is no longer active.
```

Refresh detail and active list.

## `blitz_time_expired`

```text
The Blitz time has expired.
```

Refresh/reconcile detail and active list.

## `attempt_not_editable`

```text
This Blitz attempt can no longer be resumed.
```

This is an expected stale-Resume outcome.

Clear the pending request, refresh detail and active list, and show the newly
authoritative action if one exists.

Critically:

```text
do not automatically call start_replacement
```

even if refresh reveals an available additional attempt. Replacement still
requires the Section 66 Student confirmation.

## `attempts_exhausted`

```text
No Blitz attempts remain.
```

Refresh detail/list.

## `assessment_not_assigned`

```text
This Blitz is no longer assigned to you.
```

Refresh detail/list.

## `resource_not_found`

Mark detail unavailable and refresh list.

## `idempotency_key_reused`

```text
The Blitz attempt could not be started safely.
Refresh and try again.
```

Clear key.

Do not silently generate another key in the same call.

## `business_conflict`

Generic current-state conflict; refresh detail.

## `validation_failed`

Treat as client/server contract failure, not a Student form error.

No message-text branching.

---

# 75. Session / Account Start Failures

Reuse Stage 7 handling for:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

Required:

- clear key;
- invalidate current Start operation;
- clear private execution state;
- no stale feature SnackBar;
- use existing auth/bootstrap reconciliation.

---

# 76. Intent-Specific Start Success Validation

On every `200/201` first require:

```text
attempt.assessmentId == target.blitzId
attempt.id canonical
attempt.attemptNumber in 1..2
```

Then require semantic consistency with the exact pending request.

## `start_normal`

Returned Attempt must be:

```text
attempt_number = 1
```

`201` may represent creation; `200` may represent the already-existing
in-progress #1 after a safe concurrent/double Start.

A #2 response to `start_normal` is invalid/uncertain transport success.

## `resume`

Require:

```text
HTTP 200
attempt.id == pendingRequest.attemptId
```

The returned resource may be in-progress or a terminal same-key replay of that
**same Attempt ID**, but it may never be another Attempt.

A server response containing #2 when the request targeted stale #1 is invalid;
the frontend must not accept it as authoritative Resume success.

## `start_replacement`

Returned Attempt must be:

```text
attempt_number = 2
```

`201` may create #2; `200` may return the already-in-progress #2 after a safe
concurrent replacement Start.

A #1 response is invalid/uncertain transport success.

The returned Attempt is authoritative only **within the submitted semantic
intent**. Backend state advancement does not authorize cross-intent switching.

---

# 77. Start Success — In Progress

If strict transport success returns:

```text
attempt.status == in_progress
```

then:

1. clear pending key;
2. publish:
   ```text
   status = active
   attempt
   resultKind
   ```
3. invalidate/refresh Blitz detail;
4. refresh active Blitz list;
5. remain on the same Blitz route;
6. render execution shell with Questions/countdown.

Do not navigate to an Attempt route.

---

# 78. Start Success Replay — Terminal Attempt

A completed Start idempotency key may replay after the Attempt later became
terminal.

Therefore `200/201` may contain:

```text
submitted
timed_out_finalized
waiting_for_teacher_review
checked
```

If returned Attempt is terminal:

1. clear key;
2. publish:
   ```text
   status = terminal
   attempt
   ```
3. do **not** expose editable execution;
4. refresh detail/active list;
5. show terminal reason copy:
   - timeout -> time expired;
   - task close -> Blitz closed/finalized;
   - student submit -> already submitted;
   - waiting/checked -> already finalized.

Do not treat a valid same-key replay as malformed success merely because current
Attempt is terminal.

---

# 79. Execution Shell Ownership

After Start/Resume success the same:

```text
StudentBlitzDetailScreen
```

switches its main content to:

```text
StudentBlitzAttemptShell
```

while:

```text
StudentBlitzAttemptStartState.status == active
```

The shell receives the authoritative in-memory:

```text
StudentBlitzAttempt
```

from the Start controller.

No second API read is needed.

FE-005 later extends this same shell state with answer mutation/Submit behavior.

---

# 80. Execution Shell Exit / Return

If Student presses Back to Topic or leaves Blitz route:

- autoDispose eventually clears route-session Attempt shell state;
- no Attempt is cancelled;
- server Attempt continues.

When Student returns:

1. detail GET shows:
   ```text
   inProgressAttemptId
   ```
   if still active;
2. UI shows:
   ```text
   Resume Blitz
   ```
3. Student explicitly presses Resume;
4. POST returns current full Attempt again.

Do not persist Questions in local storage to reconstruct execution later.

---

# 81. Execution Shell Content

FE-004 read-only shell displays:

```text
Blitz title
Attempt number
timer mode
started time
deadline
live countdown
Questions
saved-answer indication
Back/Leave navigation
```

No answer input controls.

No Submit.

Questions use:

```text
StudentQuestionReadView
```

or a small Blitz execution wrapper around it without changing safe Question
content.

---

# 82. Saved Answer Indication

Because Resume returns saved answer states after BE-006, FE-004 may show a
read-only indicator per Question:

```text
Saved
```

when an answer exists.

Otherwise:

```text
Not answered
```

Do not render answer editor.

Do not render correctness/checking.

A compact optional saved-value readback is allowed only if it reuses the current
safe Student answer presentation from Stage 7 without introducing editing.

Preferred FE-004 scope:

```text
Saved / Not answered
```

only.

FE-005 owns editable answer values.

---

# 83. Execution Questions Security

The execution shell appears only after:

```text
strict successful Start/Resume
```

Do not derive Questions from:

- Teacher resource;
- cached Topic data;
- pre-Start detail;
- active list.

If Start is uncertain/fails:

```text
Questions remain hidden.
```

This is a security/fairness requirement.

---

# 84. Countdown Requirement

Create one reusable presentation component/controller, for example:

```text
StudentBlitzCountdown
```

It displays effective remaining seconds without treating device wall clock as
authority.

Input:

```text
remainingSeconds
anchor identity
onExpired
```

It does **not** receive a mutable device deadline as authority.

---

# 85. Countdown Anchor

The authoritative starting value is backend:

```text
remaining_seconds
```

from the current:

- Blitz detail timing; or
- Attempt timing.

Start a Dart:

```text
Stopwatch
```

when that server snapshot is adopted.

Displayed remaining:

```text
max(
  0,
  serverRemainingSeconds - stopwatch.elapsed.inSeconds
)
```

Use:

```text
Timer.periodic
```

only to schedule repaint/recalculation.

Do **not** calculate remaining with:

```text
deadlineAt.difference(DateTime.now())
```

Do not use device timezone.

---

# 86. Why Stopwatch / Remaining Seconds

The backend already calculated:

```text
remaining_seconds
```

from authoritative server time.

A monotonic elapsed timer preserves that snapshot locally without trusting
device wall-clock changes.

If the Student changes:

- device clock;
- timezone;
- locale;

the countdown does not gain time.

Backend still validates every future answer/Submit mutation.

Frontend countdown is presentation, not authorization.

---

# 87. Countdown Re-Anchor

When a newer authoritative server response is adopted:

```text
new serverNow
new remainingSeconds
new Attempt/deadline identity
```

reset the countdown anchor.

Do not keep decrementing an older snapshot.

Use a stable anchor identity containing enough fields, for example:

```text
blitz/attempt ID
deadlineAt
serverNow
remainingSeconds
```

so unrelated Widget rebuilds do not reset countdown.

---

# 88. Countdown Tick Accuracy

Do not decrement a stored integer by “one per Timer callback”.

Reason:

> App suspension/event-loop delay may skip callbacks.

On every repaint/tick recompute from:

```text
Stopwatch.elapsed
```

This prevents paused event-loop ticks from artificially granting extra display
time.

No arbitrary sleeps in tests.

---

# 89. Countdown Formatting

Provide deterministic:

```text
mm:ss
```

for under one hour.

For one hour or more:

```text
h:mm:ss
```

Examples:

```text
300  -> 05:00
61   -> 01:01
0    -> 00:00
3661 -> 1:01:01
```

Also provide semantic label:

```text
5 minutes remaining
```

or equivalent accessible wording.

State must not rely on color alone.

---

# 90. Pre-Start Countdown — Synchronized Normal Path

When detail says:

```text
mode = synchronized
replacementAttemptAvailable = false
deadlineAt != null
remainingSeconds != null
normal path not started
```

show live:

```text
Class time remaining
```

using server-anchored countdown.

Explain:

```text
Starting does not reset this timer.
```

If local countdown reaches zero before another server response:

- disable the local Start button;
- trigger authoritative detail reconciliation once;
- show:
  ```text
  Checking current Blitz time…
  ```

Do not create/finalize Attempt locally.

---

# 91. Pre-Start Individual Path

When:

```text
mode = individual
deadlineAt = null
```

show no countdown.

Show:

```text
Your full <duration> starts when the server starts your attempt.
```

No device-time prediction.

---

# 92. Pre-Start Replacement Path

When:

```text
replacementAttemptAvailable = true
```

show no effective countdown before Start in **both** modes.

Show:

```text
Approved additional attempt available.
Your full <duration> starts when the server starts it.
```

For synchronized mode, historical class common end may be displayed separately
as context but must not appear as the replacement's countdown/deadline.

Do not locally block replacement because class common timer is zero.

---

# 93. In-Progress Attempt Countdown

After successful Start/Resume:

```text
attempt.timing.remainingSeconds
```

anchors the live execution countdown.

Works identically for:

```text
normal synchronized #1
normal individual #1
replacement synchronized #2
replacement individual #2
```

Do not infer deadline formula in Flutter.

The persisted Attempt response is authoritative.

---

# 94. Countdown Zero Behavior — Execution

When execution countdown reaches local zero:

1. fire `onExpired` exactly once for that anchor;
2. immediately switch shell to a local:
   ```text
   time reconciliation / non-editable
   ```
   state;
3. do not locally mark Attempt `timed_out_finalized`;
4. do not fabricate `finalizedAt`;
5. request authoritative Blitz detail refresh;
6. refresh active Blitz list.

The detail GET invokes backend timeout reconciliation as required by Stage 8.

Expected authoritative response may be:

```text
409 blitz_time_expired
```

or another newer lifecycle state.

Do not call Start automatically at zero.

---

# 95. Countdown Zero Network Failure

If the authoritative detail reconciliation fails due connection/timeout:

- keep execution locally non-editable;
- show:
  ```text
  Time may have expired. Reconnect and refresh to confirm the current Blitz state.
  ```
- provide Refresh;
- do not restart countdown from old remaining value;
- do not grant more local execution time.

FE-005 answer controls must later honor this non-editable gate.

---

# 96. Countdown Cannot Authorize Server Mutations

Even while local countdown displays positive time:

- backend remains final authority;
- FE-005 writes may still receive `blitz_time_expired`.

Even if local countdown reaches zero early/late by transport latency:

- frontend never finalizes;
- server response resolves truth.

No client-side business state is persisted.

---

# 97. Detail Expiry Reconciliation Controller Integration

Provide a focused method such as:

```text
StudentBlitzDetailController.reconcileAfterLocalExpiry()
```

or use `refresh()` with explicit owning state.

Requirements:

- only current session/target may invoke;
- suppress duplicate expiry refresh;
- known `blitz_time_expired` becomes `timeExpired`;
- known `blitz_not_active` becomes `notActive`;
- connection failure remains error/retry without resurrecting Start.

Execution controller observes/adopts this state and clears/hides editable shell
when authoritative execution is no longer active.

---

# 98. Start Controller and Detail State Synchronization

If detail becomes:

```text
notActive
timeExpired
notFound
```

while Start controller still holds an `active` Attempt:

- invalidate/retire local execution shell;
- do not continue showing Questions as actionable execution;
- saved in-memory Questions may be discarded;
- server history remains intact.

A later valid server state cannot “resume” the old shell without an explicit
Resume Start call.

---

# 99. Active List Refresh at Countdown Zero

If provider exists:

```text
studentActiveBlitzControllerProvider
```

refresh it.

Do not optimistically remove the card.

Server may still include a valid replacement exception path.

Example:

```text
normal #1 timed out
Teacher grants exception
```

could make the Blitz active/startable again.

Server collection is authoritative.

---

# 100. Start Result Kind UX

Use:

```text
created
resumed
```

for presentation only.

Examples:

## 201 normal #1

```text
Blitz started.
```

## 200 Resume

```text
Blitz resumed.
```

only after the exact requested Attempt ID passes Section 76.

## 201 replacement #2

```text
Additional Blitz attempt started.
```

## 200 `start_replacement`

When a concurrent replacement Start already created #2:

```text
Additional Blitz attempt is already in progress.
```

and the returned validated #2 becomes the execution shell Attempt.

Use the originating intent plus validated returned Attempt number for copy.

Do not infer `201` alone means normal #1.

---

# 101. Attempt Number Display

Execution shell:

```text
Attempt 1
```

or:

```text
Additional attempt (Attempt 2)
```

For #2 explicitly explain:

```text
This is the approved additional attempt.
```

Do not call it:

```text
second normal attempt
```

---

# 102. Start Failure Reconciliation

For deterministic:

```text
blitz_not_active
blitz_time_expired
attempts_exhausted
assessment_not_assigned
resource_not_found
business_conflict
```

trigger exact Blitz detail refresh when still safely authorized, plus active list
refresh.

Do not patch:

```text
normalUsed
replacementAvailable
inProgressAttemptId
```

locally.

---

# 103. Student Detail Before Start Must Stay Question-Free

Widget tests must explicitly assert that before a successful Start/Resume:

```text
find StudentQuestionReadView -> findsNothing
```

even when:

- synchronized;
- individual;
- normal in-progress summary exists;
- replacement available.

Questions are only in returned Attempt resource.

This is a blocking security/fairness criterion.

---

# 104. Existing Student Homework Question Read Reuse

`StudentQuestionReadView` currently imports Homework formatting helpers for
points.

If necessary, extract only pure shared Student Question presentation helpers so
Blitz can reuse the view without Homework naming leakage.

Do not fork/copy the Widget.

Preserve existing Homework appearance/behavior.

---

# 105. Student Answer State Extraction Regression

If shared saved-answer classes/parser are moved out of Homework files:

run direct Stage 7 tests covering:

- Homework Attempt DTO;
- Start/resume;
- Student answer-state parsing;
- file saved-answer metadata;
- Homework execution shell.

No public Homework JSON/domain behavior changes.

---

# 106. Active List Error Copy

Map failure kind safely.

Examples:

## connection

```text
Could not reach the server.
```

## timeout

```text
The active Blitz request timed out.
```

## invalidResponse

```text
The server returned an unexpected active Blitz response.
```

No raw URL/exception body.

---

# 107. Detail Error Copy

Known execution states have dedicated UI.

Generic error only for true load failures.

Do not show:

```text
blitz_time_expired
```

machine code to user.

Do not use human backend message for branching.

---

# 108. Start Mutation Status UI

While:

```text
submitting
```

show progress:

```text
Starting Blitz…
```

or:

```text
Resuming Blitz…
```

based on originating action snapshot.

While uncertain:

```text
We could not confirm the Blitz attempt state.
Retry safely.
```

Button:

```text
Retry
```

same key.

While deterministic failure:

show mapped copy + Refresh where useful.

No second Start button while uncertain.

---

# 109. Refresh During Active Execution

FE-004 execution shell may show:

```text
Refresh Blitz state
```

but it must not discard current Questions and pretend another Attempt state
without clear reconciliation.

Preferred:

- while active execution countdown > 0, do not offer a broad pre-Start detail
  Refresh button inside the Question shell;
- FE-005 later owns richer execution reconciliation.

Countdown expiry triggers required refresh automatically.

Back/leaving remains available.

---

# 110. Back / Leave Execution

Back action from execution shell:

```text
Back to Topic
```

or:

```text
Leave Blitz
```

must not imply Attempt cancellation.

If showing confirmation, use neutral wording:

```text
Leave Blitz?
Your server timer will continue.
You can resume later while the attempt remains active.
```

A confirmation is recommended when countdown is active.

Buttons:

```text
Stay
Leave
```

Leaving performs no API mutation.

No timer pause.

---

# 111. Resume After Leaving

When Student returns and detail confirms:

```text
inProgressAttemptId != null
```

show:

```text
Resume Blitz
```

Do not reconstruct Questions from prior local memory.

The explicit Resume POST returns current Questions/answers again.

This supports process/navigation safety without Attempt GET.

---

# 112. Responsive Layout

Support:

```text
desktop
mobile
```

Active workspace:

- cards wrap/stack;
- no horizontal overflow.

Blitz detail/execution:

```text
SafeArea
SingleChildScrollView
ConstrainedBox
```

or existing equivalents.

Questions with Matching two-column structure already adapt through shared
`StudentQuestionReadView`.

Long:

- title;
- instructions;
- prompt;
- option text

must wrap.

Countdown stays visible near top of execution shell.

---

# 113. Countdown Visibility

Execution countdown should be visually prominent but not obscure content.

Recommended:

```text
Card / persistent top section inside scroll content
Time remaining: 04:32
```

No platform-specific overlay required.

Do not use a global floating Timer service.

---

# 114. Accessibility

Required:

- active cards actionable Semantics;
- section headers semantic;
- progress indicators semantic;
- countdown uses live-region semantics sparingly;
- do not announce every second to screen readers.

Recommended:

- visible countdown updates every second;
- accessibility semantic announcement updates at meaningful thresholds only or
  exposes current text without `liveRegion` every tick.

At minimum avoid a screen-reader announcement every second.

State not color-only.

---

# 115. Countdown Warning Presentation

Optional presentation-only warning thresholds:

```text
<= 60 seconds
```

may use stronger typography/icon.

Do not change business behavior.

Do not introduce sound/vibration in FE-004.

Do not treat color as the only signal.

---

# 116. Expected File Scope

Exact filenames may follow current conventions.

## Create likely

```text
frontend/lib/features/student/domain/student_blitz.dart
frontend/lib/features/student/domain/student_blitz_route_target.dart
frontend/lib/features/student/domain/student_blitz_attempt.dart
frontend/lib/features/student/domain/student_blitz_repository.dart
frontend/lib/features/student/domain/student_blitz_attempt_repository.dart
frontend/lib/features/student/domain/student_attempt_answer.dart

frontend/lib/features/student/data/dto/student_blitz_dto.dart
frontend/lib/features/student/data/dto/student_blitz_attempt_dto.dart
frontend/lib/features/student/data/dto/student_attempt_answer_parser.dart
frontend/lib/features/student/data/student_blitz_remote_data_source.dart
frontend/lib/features/student/data/student_blitz_repository_impl.dart
frontend/lib/features/student/data/student_blitz_attempt_remote_data_source.dart
frontend/lib/features/student/data/student_blitz_attempt_repository_impl.dart

frontend/lib/features/student/application/student_active_blitz_state.dart
frontend/lib/features/student/application/student_active_blitz_controller.dart
frontend/lib/features/student/application/student_blitz_detail_state.dart
frontend/lib/features/student/application/student_blitz_detail_controller.dart
frontend/lib/features/student/application/student_blitz_attempt_start_state.dart
frontend/lib/features/student/application/student_blitz_attempt_start_controller.dart

frontend/lib/features/student/presentation/student_active_blitz_section.dart
frontend/lib/features/student/presentation/student_blitz_detail_screen.dart
frontend/lib/features/student/presentation/student_blitz_attempt_shell.dart
frontend/lib/features/student/presentation/student_blitz_countdown.dart
frontend/lib/features/student/presentation/student_blitz_formatters.dart
```

## Modify likely

```text
frontend/lib/features/student/presentation/student_learning_workspace_screen.dart

frontend/lib/features/student/domain/student_homework_attempt.dart
frontend/lib/features/student/data/dto/student_homework_attempt_dto.dart

frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart

frontend/lib/core/network/api_error_codes.dart
```

A narrow shared Student Question presentation formatter extraction is allowed.

Do not modify:

```text
backend/
Teacher Stage 8 frontend
platform files
pubspec.yaml
pubspec.lock
integration_test/
docs/
tasks/
```

---

# 117. Active List DTO Tests

Create:

```text
student_blitz_dto_test.dart
```

Active list coverage:

- exact empty `{data:[]}`;
- synchronized normal not-started;
- synchronized normal in-progress;
- individual not-started;
- individual in-progress;
- synchronized replacement available after common end;
- synchronized replacement in-progress with deadline after common end;
- individual replacement available;
- duplicate Blitz ID rejected;
- unknown item/envelope key rejected;
- wrong status rejected;
- duration zero rejected;
- invalid Attempt summary combinations rejected;
- timing/deadline/remaining mismatch rejected;
- fractional `server_now`, `deadline_at`, or `synchronized_ends_at` strings rejected;
- non-`Z` timing offsets rejected;
- canonical whole-second timestamps + exact integer difference accepted;
- no Question field accepted.

---

# 118. Detail DTO Tests

Cover:

- synchronized normal pre-Start;
- individual normal pre-Start;
- normal in-progress summary;
- replacement available;
- replacement in progress;
- terminal normal summary where backend still returns valid detail;
- exact keys;
- description nullable;
- points non-negative;
- Topic canonical;
- wrong/malformed timing rejected;
- fractional timing timestamps rejected;
- `12:00:00Z -> 12:10:00Z` requires exactly `remaining_seconds=600`;
- any `questions` key in success rejected.

---

# 119. Attempt DTO Tests

Create:

```text
student_blitz_attempt_dto_test.dart
```

Cover:

- in-progress #1 synchronized;
- in-progress #1 individual;
- in-progress #2 synchronized deadline beyond common class end context;
- in-progress #2 individual;
- submitted student_submit;
- timed_out_finalized;
- task_closed_auto_finalize;
- waiting_for_review;
- checked;
- reject attempt #0/#3;
- reject Homework finalization reason;
- exact timing remaining from canonical whole-second timestamps;
- fractional `started_at`, `deadline_at`, or `timing.server_now` rejected;
- all-nine Student safe Question types;
- saved answer parsing;
- unanswered absent;
- duplicate answers rejected;
- child ID mismatch rejected;
- no score/checking keys accepted.

---

# 120. Shared Homework Answer Parser Regression

After extraction run current tests proving:

- Homework Attempt DTO shape unchanged;
- all saved answer types unchanged;
- Homework Attempt statuses/reasons unchanged;
- Homework file answer metadata unchanged.

No Stage 7 public behavior changes.

---

# 121. Data Source Tests

Create:

```text
student_blitz_remote_data_source_test.dart
student_blitz_attempt_remote_data_source_test.dart
```

Verify exact:

## Active list

```text
GET /student/blitz/active
no query/body
```

## Detail

```text
GET /student/blitz/{id}
```

## Student execution POST

```text
POST /student/blitz/{id}/attempts

normal:
  body {"intent":"start_normal"}

resume:
  body {"intent":"resume","attempt_id":"<uuid>"}

replacement:
  body {"intent":"start_replacement"}

Idempotency-Key exact
```

Verify:

- exact body keys/values for all three intents;
- Resume canonical Attempt ID validation before network;
- status 200/201 mapping;
- exact message;
- malformed success -> uncertain/invalidResponse boundary;
- canonical ID validation before network;
- no automatic retry.

---

# 122. Active Controller Tests

Create:

```text
student_active_blitz_controller_test.dart
```

Cover:

- loading/data/empty;
- refresh retains items;
- stale error;
- retry;
- session switch clears;
- stale completion ignored;
- duplicate refresh suppression;
- `refreshAfterExecution` rejects stale owner.

---

# 123. Detail Controller Tests

Create:

```text
student_blitz_detail_controller_test.dart
```

Cover:

- initial load;
- data;
- Topic route mismatch -> notFound;
- 404 -> notFound;
- blitz_not_active -> notActive;
- blitz_time_expired -> timeExpired;
- refresh retains data while pending;
- refresh then expiry removes Start authority;
- session switch/dispose stale completion ignored;
- local expiry reconciliation suppresses duplicate GET.

---

# 124. Start Controller Tests

Create:

```text
student_blitz_attempt_start_controller_test.dart
```

Cover:

- normal Start sends `start_normal` and 201 #1;
- safe concurrent normal Start may return 200 same #1;
- normal Resume sends `resume` + exact #1 ID and returns 200 exact #1;
- replacement Start sends `start_replacement` and 201 #2;
- safe concurrent replacement Start may return 200 same #2;
- replacement Resume sends `resume` + exact #2 ID and returns 200 exact #2;
- exact key generated;
- one logical call freezes one intent/body/key;
- uncertain Retry resends same key + same intent + same Attempt ID;
- deterministic failure clears key;
- session failure clears key;
- duplicate submit suppressed;
- valid returned attempt assessment target;
- Resume success requires returned Attempt ID == requested Attempt ID;
- stale Resume #1 that receives #2 is rejected as invalid/uncertain response;
- stale Resume #1 -> backend attempt_not_editable refreshes state and never auto-starts replacement;
- stale normal Start after exception cannot be accepted as #2;
- terminal same-key replay of the same requested Attempt is accepted as terminal, not invalid;
- active success refreshes detail/list;
- deterministic expiry/list reconciliation;
- stale completion after session/target ignored.

---

# 125. Countdown Unit / Widget Tests

Create:

```text
student_blitz_countdown_test.dart
```

Use Flutter fake elapsed time through `tester.pump(Duration(...))`.

Cover:

```text
300 -> 05:00
61 -> 01:01
3661 -> 1:01:01
```

Verify:

- decrements based on elapsed duration;
- delayed pump skips correctly rather than one-per-callback;
- unrelated parent rebuild does not reset anchor;
- new anchor resets;
- reaches zero;
- `onExpired` fires exactly once per anchor;
- no negative display;
- no DateTime.now/device timezone dependency.

No arbitrary real sleep.

---

# 126. Workspace Active Section Tests

Create:

```text
student_active_blitz_section_test.dart
```

Cover:

- Active Blitz appears before My Topics;
- independent loading;
- empty;
- error/retry;
- stale retained state;
- normal not-started card;
- in-progress card;
- replacement available card;
- replacement in-progress card;
- synchronized timing label;
- individual full-duration copy;
- card navigation;
- no Questions shown;
- Topics remain usable when Blitz list errors;
- desktop/mobile narrow layout.

---

# 127. Blitz Detail Screen Tests

Create:

```text
student_blitz_detail_screen_test.dart
```

Pre-Start:

- title/instructions/timing;
- synchronized live class countdown;
- individual no countdown;
- replacement no effective pre-Start countdown;
- Start normal confirmation and exact `start_normal` intent;
- Resume no destructive confirmation but exact captured Attempt-ID binding;
- replacement confirmation and no POST before explicit `start_replacement`;
- stale Resume conflict refreshes to replacement availability without auto-starting #2;
- attempt usage copy;
- no Questions before Start.

Start states:

- submitting;
- uncertain Retry;
- deterministic failures.

Post success:

- same route;
- execution shell;
- Questions visible;
- saved/not-saved indicators;
- Attempt number;
- countdown.

Terminal replay:

- no active Question execution;
- terminal message.

---

# 128. Execution Countdown Expiry Screen Tests

Cover:

- countdown reaches zero;
- shell becomes locally non-editable/reconciling;
- detail refresh triggered once;
- active list refresh triggered;
- backend `blitz_time_expired` -> time-expired screen;
- connection failure -> “time may have expired” recovery UI;
- no local terminal timestamp/status fabricated;
- no automatic Start call.

---

# 129. Routing Tests

Create/extend:

```text
student_blitz_routing_test.dart
```

Verify:

```text
/student/topics/<topic>/blitz/<blitz>
```

- exact helper;
- exact recognizer;
- Topic extraction;
- Blitz extraction;
- desktop direct entry;
- mobile direct entry;
- wrong role safe;
- malformed IDs rejected;
- query/fragment safe;
- no Blitz Attempt route added;
- existing Homework detail/Attempt routes unchanged.

---

# 130. Student Workspace Regression

Because `StudentLearningWorkspaceScreen` changes, run current Student Topic
workspace tests.

Verify:

- My Topics search/filter/pagination unchanged;
- Active Blitz failure does not hide Topic list;
- logout/session behavior unchanged;
- responsive layout unchanged.

---

# 131. Stage 7 Start / Question Regression

Because FE-004 reuses/extracts:

```text
IdempotencyKeyGenerator
StudentQuestion
StudentAttemptAnswerState
```

run directly affected Stage 7 tests:

```text
student_homework_attempt_start_controller_test
student_homework_attempt_dto_test
student_homework_attempt_routing_test
student_homework_screen_test
```

plus exact saved-answer DTO tests if separate.

Do not weaken assertions.

---

# 132. Focused Verification — New FE-004

Run from:

```text
frontend/
```

Conceptually:

```bash
fvm flutter test \
  test/features/student/student_blitz_dto_test.dart \
  test/features/student/student_blitz_attempt_dto_test.dart \
  test/features/student/student_blitz_remote_data_source_test.dart \
  test/features/student/student_blitz_attempt_remote_data_source_test.dart \
  test/features/student/student_active_blitz_controller_test.dart \
  test/features/student/student_blitz_detail_controller_test.dart \
  test/features/student/student_blitz_attempt_start_controller_test.dart \
  test/features/student/student_blitz_countdown_test.dart \
  test/features/student/student_active_blitz_section_test.dart \
  test/features/student/student_blitz_detail_screen_test.dart \
  test/features/student/student_blitz_routing_test.dart
```

Use actual filenames if responsibilities are combined.

---

# 133. Direct Regression Verification

Run exact affected current files for:

- Student workspace/Topic list;
- Student Homework Start;
- Student Homework Attempt DTO;
- Student Homework routing;
- shared Student Question read;
- saved-answer parser extraction.

No full frontend suite.

---

# 134. Focused Analyze

Run:

```bash
fvm flutter analyze --no-pub lib/features/student
fvm flutter analyze --no-pub lib/app/router
```

If core idempotency/error files are modified, include the narrowest supported
analyze scope.

Do not silently substitute full-project analyze unless pinned CLI requires it.

---

# 135. Format Check

Run read-only format check over actual changed Dart files and focused tests.

Conceptually:

```bash
fvm dart format --output=none --set-exit-if-changed \
  <changed Student feature files> \
  <changed router/core files> \
  <changed Student tests>
```

Do not format unrelated code.

---

# 136. Git Diff Check

From repository root:

```bash
git diff --check
```

Required:

```text
PASS
```

Perform focused scope/diff review.

Do not run:

- full frontend suite;
- full project analyze;
- Windows build;
- Android build;
- broad E2E.

Those belong to Frontend Phase 2 / Integration.

---

# 137. Acceptance Criteria — Active List

- [ ] Uses exact global `/student/blitz/active`.
- [ ] No query/pagination invented.
- [ ] Section appears in Student workspace.
- [ ] Topics remain independently usable.
- [ ] Server ordering preserved.
- [ ] normal/resume/replacement paths displayed accurately.
- [ ] no Questions in list.
- [ ] no local eligibility reimplementation.
- [ ] list refreshes after execution changes.

---

# 138. Acceptance Criteria — Detail / Privacy

- [ ] Canonical nested Blitz detail route exists.
- [ ] Desktop/mobile supported.
- [ ] Topic/Blitz hierarchy verified.
- [ ] `blitz_not_active` and `blitz_time_expired` have dedicated states.
- [ ] Pre-Start detail contains no Question domain field.
- [ ] Strict DTO rejects Question leakage.
- [ ] Questions are not rendered before successful Start/Resume.
- [ ] Opening/reloading detail never auto-starts an Attempt.
- [ ] No Blitz Attempt deep-link route is added.

---

# 139. Acceptance Criteria — Start / Resume

- [ ] Normal Start sends exact `intent=start_normal`.
- [ ] Existing Attempt Resume sends exact `intent=resume` + captured `attempt_id`.
- [ ] Replacement Start sends exact `intent=start_replacement` only after confirmation.
- [ ] Required Idempotency-Key.
- [ ] Pending logical request freezes intent/Attempt ID/key.
- [ ] Uncertain Retry resends the exact same semantic request and key.
- [ ] No automatic mutation replay or cross-intent reinterpretation.
- [ ] Resume can succeed only with the exact requested Attempt ID.
- [ ] Stale Resume cannot accept/create a newer replacement Attempt.
- [ ] `attempt_not_editable` refreshes authoritative state but never auto-starts replacement.
- [ ] Start-normal success is #1 only; replacement-start success is #2 only.
- [ ] 200/201 mapped with intent-specific validation.
- [ ] Attempt #1/#2 only.
- [ ] terminal same-key replay supported only for its original referenced Attempt.
- [ ] active execution stays on same Blitz route.
- [ ] leaving does not cancel/pause Attempt.

---

# 140. Acceptance Criteria — Countdown

- [ ] Stage 8 timer timestamps accept only canonical `YYYY-MM-DDTHH:MM:SSZ`.
- [ ] Fractional-second timer timestamps are rejected by strict DTO parsing.
- [ ] Exact DTO remaining check uses the same whole-second values sent by backend.
- [ ] Server `remaining_seconds` is the countdown anchor.
- [ ] No `DateTime.now()` deadline authority.
- [ ] No device timezone authority.
- [ ] Stopwatch elapsed used instead of callback counting.
- [ ] unrelated rebuild does not reset countdown.
- [ ] newer server snapshot re-anchors.
- [ ] synchronized pre-Start normal path counts down.
- [ ] individual pre-Start has no countdown.
- [ ] unused replacement has no effective countdown.
- [ ] #2 countdown uses returned Attempt timing.
- [ ] zero fires one reconciliation.
- [ ] zero never creates/finalizes Attempt locally.
- [ ] network failure at zero does not grant more local execution time.

---

# 141. Acceptance Criteria — Shared Domain Reuse

- [ ] Existing StudentQuestion reused.
- [ ] Existing StudentQuestionDto reused.
- [ ] Existing StudentQuestionReadView reused.
- [ ] Saved-answer domain/parser extracted/reused, not copied.
- [ ] Homework Attempt behavior unchanged.
- [ ] No score/checking leakage.
- [ ] File saved-answer safe metadata unchanged.

---

# 142. Acceptance Criteria — Async / Session Safety

- [ ] Active/detail/start controllers bind to StudentSessionKey.
- [ ] target generations reject stale completion.
- [ ] old session cannot receive Questions.
- [ ] uncertain Start cannot expose Questions.
- [ ] countdown expiry from obsolete anchor cannot mutate new target.
- [ ] session loss clears pending Start key and execution shell.
- [ ] no stale navigation/feedback.

---

# 143. Acceptance Criteria — UX / Accessibility

- [ ] Active Blitz is prominent in Student workspace.
- [ ] Start copy distinguishes synchronized vs individual.
- [ ] replacement copy clearly says additional attempt.
- [ ] Attempt #2 is not called second normal attempt.
- [ ] countdown formatting deterministic.
- [ ] screen reader not spammed every second.
- [ ] state not color-only.
- [ ] narrow mobile layout no overflow.
- [ ] long Question text wraps.
- [ ] Back/Leave explains timer continues.

---

# 144. Scope Acceptance

- [ ] No answer mutation.
- [ ] No file upload/download UX.
- [ ] No Submit.
- [ ] No checking/scoring/result UI.
- [ ] No backend change.
- [ ] No package/platform change.
- [ ] No Attempt GET invented.
- [ ] No auto-start on route load.
- [ ] No local timeout finalization.
- [ ] Focused FE-004 tests pass.
- [ ] Stage 7 shared regressions pass.
- [ ] focused analyze passes.
- [ ] format check passes.
- [ ] `git diff --check` passes.

---

# 145. Focused Diff Self-Check

Before completion confirm the diff implements only:

```text
Student active Blitz discovery
+
pre-Start detail
+
explicit Start/Resume/replacement Start
+
read-only timed execution shell
+
server-anchored countdown
```

Verify specifically:

```text
Questions hidden pre-Start
no Attempt route requiring unsafe reconstruction
no auto POST on deep-link/reload
same-key uncertain Retry
remaining_seconds + Stopwatch countdown
no answer/Submit controls
no local scoring/finalization
```

Confirm every changed file is necessary.

---

# 146. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. active-list domain/API/UI;
4. Blitz detail privacy boundary;
5. route design and why no Attempt route exists;
6. Start/Resume/replacement action state machine;
7. Idempotency-Key lifetime;
8. Attempt DTO/lifecycle support;
9. shared Student Question/answer-state extraction;
10. countdown anchoring/expiry reconciliation;
11. desktop/mobile behavior;
12. focused FE-004 test results;
13. Stage 7 regression results;
14. focused analyze result;
15. format check result;
16. `git diff --check`;
17. final `git status --short`;
18. focused scope/diff self-check;
19. any blocker/deviation.

Do not claim Stage 8 frontend complete.

After delivery ChatGPT performs read-only acceptance review.

`S08-FE-005` remains blocked until:

```text
S08-FE-004 = Accepted / Delivered
```

---

# 147. Implementation Readiness Verdict

```text
Scope / non-goals                    = RESOLVED
Active Blitz placement               = RESOLVED
Active list API/DTO                  = RESOLVED
Detail API/DTO                       = RESOLVED
Pre-Start Question secrecy           = RESOLVED
Student route                        = RESOLVED
No unsafe Attempt route              = RESOLVED
Normal Start                         = RESOLVED
Resume                               = RESOLVED
Replacement Start                    = RESOLVED
Explicit execution intent             = RESOLVED
Resume exact-attempt binding          = RESOLVED
Replacement confirmation boundary     = RESOLVED
Start Idempotency-Key                 = RESOLVED
Uncertain same-request/key Retry       = RESOLVED
Terminal same-attempt replay           = RESOLVED
Attempt #1/#2 domain                 = RESOLVED
Shared Student Question reuse        = RESOLVED
Shared answer-state extraction       = RESOLVED
Synchronized timing UX              = RESOLVED
Individual timing UX                = RESOLVED
Replacement timing UX               = RESOLVED
Server-anchored countdown            = RESOLVED
Countdown zero reconciliation        = RESOLVED
Device clock non-authority           = RESOLVED
Session/target stale safety          = RESOLVED
Desktop/mobile support               = RESOLVED
Accessibility/responsiveness         = RESOLVED
Focused tests                        = RESOLVED
Focused verification                 = RESOLVED

Implementation Readiness Gate        = PASS
Execution dependency                 = S08-FE-003 Accepted / Delivered
Next task after acceptance            = S08-FE-005
```
