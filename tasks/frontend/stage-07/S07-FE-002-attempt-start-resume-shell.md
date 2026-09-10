# Codex Implementation Contract: S07-FE-002 — Attempt Start / Resume Shell

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S07-FE-002` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter idempotent Homework Attempt start + current Attempt resume/read shell + canonical execution routing` |
| Depends on | `S07-FE-001 = Accepted / Delivered`; Stage 7 Backend Phase 2 remains `PASS` |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Current review baseline | `origin/main @ 8277667c75beeb0d9e49cf2f0374e1ca2711ebc6` |
| Implementation baseline | ChatGPT re-checks/freezes current `origin/main` immediately before Codex starts |
| Readiness Gate | `PASS — corrected/revalidated`; execution remains blocked until `S07-BE-PHASE-2 = PASS` and `S07-FE-001 = Accepted / Delivered` |
| Supported surfaces | `Student desktop + mobile` |
| Verification | focused frontend tests + format/analyze + diff check |
| Delivery | Project Owner |
| Frontend block checkpoint | Stage 7 Frontend Phase 2 after `S07-FE-001…005` |

Do not create a duplicate `CODEX-PROMPT`.

---

# 2. Context Boundary

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. delivered `S07-FE-001` Student Homework domain/data/application/presentation/routing;
5. current Student Session ownership patterns;
6. current configured Dio/failure infrastructure;
7. current GoRouter helpers/guards;
8. exact backend Attempt/Start contracts reproduced below;
9. existing package list only to confirm no dependency is required.

Do not read product docs, roadmap, architecture/database/API docs, previous task files, Stage history, closure reviews, or unrelated modules to determine behavior.

This contract resolves:

- Start vs Resume UX;
- client-generated idempotency UUID;
- idempotency-key lifetime under uncertain outcomes;
- exact POST/GET Attempt transport;
- strict Attempt/answer DTO parsing;
- nested execution route;
- direct-entry hierarchy verification;
- session/target/stale completion safety;
- detail action reconciliation;
- read-only execution shell;
- tests and verification.

If delivered backend or FE-001 materially conflicts with this contract, return `BLOCKED` with exact evidence. Do not redesign.

---

# 3. Goal

Extend FE-001 so a Student can:

1. open an assigned active Homework;
2. if no current Attempt exists and backend reports capacity, start one;
3. if backend races and returns an existing current Attempt, safely resume it;
4. if FE-001 detail already exposes `in_progress_attempt`, navigate directly to that Attempt without sending a redundant Start request;
5. open/reload the current own Attempt from:
   ```text
   GET /student/attempts/{attempt}
   ```
6. enter a canonical Attempt execution shell.

The shell displays:

- Attempt number/status;
- Homework deadline;
- safe Questions;
- already-saved answer state;
- read-only saved/not-saved indication.

No answer editing is implemented in FE-002.

---

# 4. Explicit Non-Goals

Do not implement:

- non-file answer editors;
- answer PUT;
- file picker/upload/download UX;
- final Submit;
- Submit idempotency;
- score/checking/review UI;
- countdown timer;
- local deadline authority;
- optimistic Attempt creation;
- offline retry queue;
- background synchronization;
- Blitz;
- Parent;
- new package/dependency;
- new router/client/state framework;
- platform-file changes.

`S07-FE-003` owns eight non-file editors.

`S07-FE-004` owns file-answer UX.

`S07-FE-005` owns final Submit/finalization UX.

---

# 5. Start vs Resume UX Decision

The FE-001 Homework detail already exposes:

```text
attempts.in_progress_attempt
```

Use it.

## If `in_progress_attempt != null`

Render:

```text
Resume Attempt <N>
```

Action:

```text
navigate directly to the Attempt execution route
```

using the known Attempt ID.

Do **not** send `POST /homework/{homework}/attempts` merely to resume a confirmed current Attempt.

The execution route will perform authoritative GET Attempt reconciliation.

## If no current in-progress Attempt

A **new Start mutation** may be offered only from a confirmed current FE-001
Homework detail state:

```text
StudentHomeworkDetailStatus = data
isStale = false / no retained-stale marker
status = active
remaining > 0
in_progress_attempt = null
Start controller is not submitting/uncertain
```

Then render:

```text
Start Attempt
```

Action sends the idempotent Start POST.

Do not offer a new Start from retained or non-authoritative detail state:

```text
initial
loading
refreshing
stale
error
notFound
```

A refreshing/stale view may continue showing read-only Homework information, but
must not expose a new Start action based on retained counts/lifecycle.

Do not derive deadline eligibility from device time.

## Otherwise

No new Start action.

A confirmed current `in_progress_attempt` may still expose the direct Resume
action defined above; the execution-route GET remains authoritative.

Show the existing read-only Homework state only where applicable.

Do not invent a disabled action based on local clock.

---

# 6. Backend Start Contract

Endpoint:

```text
POST /api/v1/student/homework/{homework}/attempts
```

Required header:

```http
Idempotency-Key: <client-generated UUID>
```

Body:

```json
{}
```

No query parameters.

Backend semantic result:

```text
201 = new Attempt created
200 = existing current in_progress Attempt resumed
```

Both success responses use the same exact Attempt resource shape.

Known deterministic Start errors include:

```text
404 resource_not_found
409 task_not_active
409 task_closed
409 task_archived
409 assessment_not_assigned
409 deadline_passed
409 attempts_exhausted
409 idempotency_key_reused
409 business_conflict
422 validation_failed
```

Do not parse human messages for control flow.

---

# 7. Backend Attempt Read Contract

Endpoint:

```text
GET /api/v1/student/attempts/{attempt}
```

No query/body.

Success:

```text
200
```

Exact envelope:

```json
{
  "data": {
    "id": "attempt-uuid",
    "assessment_id": "homework-uuid",
    "attempt_number": 1,
    "status": "in_progress",
    "started_at": "2026-09-08T12:00:00Z",
    "submitted_at": null,
    "finalized_at": null,
    "finalization_reason": null,
    "deadline_at": "2026-09-10T13:00:00Z",
    "questions": [],
    "answers": []
  }
}
```

No extra success-envelope keys.

---

# 8. Attempt Status Domain

Create:

```text
frontend/lib/features/student/domain/student_homework_attempt.dart
```

Enum:

```text
StudentHomeworkAttemptStatus:
  inProgress       = in_progress
  submitted        = submitted
  waitingForReview = waiting_for_teacher_review
  checked          = checked
```

For Homework FE-002 do not accept:

```text
timed_out_finalized
```

as a valid success status.

Unknown values:

```text
FormatException
```

---

# 9. Finalization Reason Domain

Enum:

```text
StudentHomeworkAttemptFinalizationReason:
  studentSubmit       = student_submit
  homeworkDeadline    = homework_deadline_auto_submit
  taskClosed          = task_closed_auto_finalize
```

Do not accept:

```text
timeout_auto_submit
```

for Homework.

`finalizationReason` is nullable only where the Attempt state permits it.

---

# 10. Attempt Domain

`StudentHomeworkAttempt` fields:

```text
id
assessmentId
attemptNumber
status
startedAt
submittedAt?
finalizedAt?
finalizationReason?
deadlineAt?
questions
answers
```

Require:

```text
attemptNumber in 1..3
questions immutable
answers immutable
```

Use FE-001:

```text
StudentQuestion
```

Do not duplicate Student Question models.

---

# 11. Attempt Lifecycle DTO Invariants

Strict parser must enforce coherent Stage 7 Homework state.

All non-null Attempt timestamps use the delivered FE-001 exact Homework timestamp
parser:

```text
YYYY-MM-DDTHH:MM:SSZ
```

Do not fall back to the older, more permissive Student Topic timestamp syntax.

For every Attempt require:

```text
started_at != null
started_at <= finalized_at when finalized_at != null
started_at <= submitted_at when submitted_at != null
```

## `in_progress`

Require:

```text
submitted_at = null
finalized_at = null
finalization_reason = null
```

Backend `locked_at` is intentionally not exposed.

## `submitted`

Require:

```text
finalized_at != null
finalization_reason != null
```

Then:

### `student_submit`

Require:

```text
submitted_at != null
submitted_at == finalized_at
```

If `deadline_at != null`:

```text
finalized_at < deadline_at
```

because equality/after-deadline belongs to deadline finalization.

### `homework_deadline_auto_submit`

Require:

```text
deadline_at != null
submitted_at = null
finalized_at == deadline_at
```

### `task_closed_auto_finalize`

Require:

```text
submitted_at = null
```

If `deadline_at != null`:

```text
finalized_at < deadline_at
```

because at/effectively after deadline the deadline reason must win.

## `waiting_for_teacher_review` / `checked`

These are forward-compatible Stage 9 statuses.

Require:

```text
finalized_at != null
finalization_reason != null
```

Preserve the same explicit/automatic `submitted_at` and deadline consistency
based on `finalization_reason`:

- `student_submit` -> `submitted_at == finalized_at`, and before deadline when a
  deadline exists;
- `homework_deadline_auto_submit` -> `submitted_at = null`,
  `deadline_at != null`, `finalized_at == deadline_at`;
- `task_closed_auto_finalize` -> `submitted_at = null`, and before deadline when
  a deadline exists.

FE-002 does not render scores.

---

# 12. Saved Answer Domain

Create Student-only typed read state in:

```text
student_homework_attempt.dart
```

or a focused adjacent:

```text
student_attempt_answer.dart
```

Do not use raw `Map<String, dynamic>` in application/presentation.

Base concept:

```text
StudentAttemptAnswerState:
  questionId
  type
  value
  updatedAt
```

Typed answer value variants:

```text
StudentChoiceAnswerValue
StudentBooleanAnswerValue
StudentTextAnswerValue
StudentMatchingAnswerValue
StudentOrderingAnswerValue
StudentFillBlankAnswerValue
StudentFileAnswerValue
```

---

# 13. Choice Saved Answer

For:

```text
single_choice
multiple_choice
```

exact nested answer:

```json
{
  "selected_option_ids": ["uuid"]
}
```

Domain:

```text
selectedOptionIds
```

Require canonical UUIDs and no duplicates.

For Single Choice:

```text
count == 1
```

For Multiple Choice:

```text
count >= 1
count <= referenced Question.answerUi.maxSelections
```

The referenced FE-001 Multiple Choice Question must provide the validated
positive `maxSelections`.

An empty persisted answer must not appear in GET Attempt.

Do not validate correctness.

---

# 14. True/False Saved Answer

Exact:

```json
{
  "value": true
}
```

Require JSON boolean.

Domain:

```text
bool value
```

---

# 15. Written Saved Answer

For:

```text
short_written
open_written
```

exact:

```json
{
  "text": "exact saved text"
}
```

Preserve exact text.

Do not trim/normalize.

A persisted saved answer must satisfy:

```text
text.trim().isNotEmpty
```

for the DTO semantic-empty check. This check does **not** mutate the value:
preserve the original non-empty String exactly, including meaningful
leading/trailing whitespace.

If backend returns a semantically cleared written state as persisted data, treat
the response as invalid.

Do not score/compare accepted answers.

---

# 16. Matching Saved Answer

Exact:

```json
{
  "pairs": [
    {
      "left_item_id": "uuid",
      "right_item_id": "uuid"
    }
  ]
}
```

Domain pair:

```text
leftItemId
rightItemId
```

Require:

- at least one pair in persisted state;
- canonical UUIDs;
- unique left IDs;
- unique right IDs.

Do not infer correctness.

---

# 17. Ordering Saved Answer

Exact:

```json
{
  "items": [
    {
      "item_id": "uuid",
      "position": 1
    }
  ]
}
```

Require:

```text
at least one item
canonical item UUID
1 <= position <= referenced Question ordering item count
unique item IDs
unique submitted positions
```

Partial subsets and non-contiguous positions remain valid.

Do not compare to correct position.

---

# 18. Fill Blank Saved Answer

Exact:

```json
{
  "values": [
    {
      "blank_id": "uuid",
      "text": "domain name"
    }
  ]
}
```

Require:

- at least one value;
- canonical blank UUIDs;
- unique blank IDs;
- every saved `text.trim().isNotEmpty`.

Preserve each original non-empty text exactly; do not trim/normalize the stored
display value.

Do not parse accepted answers.

---

# 19. File Saved Answer

Exact:

```json
{
  "file": {
    "id": "file-uuid",
    "original_name": "homework.pptx",
    "extension": "pptx",
    "size_bytes": 1048576
  }
}
```

Domain:

```text
StudentSubmissionFile:
  id
  originalName
  extension
  sizeBytes
```

Require extension one of:

```text
pdf
docx
ppt
pptx
```

Require:

```text
sizeBytes > 0
sizeBytes <= 15_728_640
```

Do not accept/expose:

```text
storage_disk
storage_key
mime_type
checksum_sha256
uploaded_by_user_id
institution_id
removed_at
```

FE-002 does not download/open the file yet.

---

# 20. Attempt Answer State Exact Shape

Each `answers` element exact keys:

```text
question_id
type
answer
updated_at
```

`answer` must be non-null for persisted GET Attempt entries.

Unknown/extra keys:

```text
FormatException
```

No:

```text
checking_status
awarded_points
feedback
checked_at
```

in Student Attempt answer transport/domain.

---

# 21. Attempt Cross-Collection Integrity

Strict `StudentHomeworkAttemptDto` parsing must enforce:

- Question IDs unique;
- Question positions unique;
- Question positions are exactly `1..N`;
- Question collection order is ascending by `position`;
- Answer `question_id` unique;
- every Answer references a returned Question;
- Answer `type` exactly equals referenced Question type;
- saved choice option IDs belong to the safe Question's option ID set;
- saved Multiple Choice count does not exceed the safe Question `maxSelections`;
- matching saved left/right IDs belong to the corresponding safe Question side sets;
- ordering saved item IDs belong to that Question's item set and each submitted
  position is within `1..Question.items.length`;
- fill saved blank IDs belong to that Question's blank set;
- file answer only references a `file_based` Question.

Do not validate correctness.

If any invariant fails:

```text
invalidResponse
```

---

# 22. Attempt DTO

Create:

```text
frontend/lib/features/student/data/dto/student_homework_attempt_dto.dart
```

Exact Attempt keys:

```text
id
assessment_id
attempt_number
status
started_at
submitted_at
finalized_at
finalization_reason
deadline_at
questions
answers
```

Reuse FE-001:

```text
StudentQuestionDto
```

or extract a safe shared parser only if already architecturally appropriate.

Do not duplicate the Student Question parser.

---

# 23. Start Operation Result Domain

Create:

```text
StudentHomeworkAttemptStartResult
```

Fields:

```text
attempt
resultKind
```

Enum:

```text
StudentHomeworkAttemptStartResultKind:
  created
  resumed
```

Map from HTTP status only:

```text
201 -> created
200 -> resumed
```

Do not infer created/resumed from Attempt number or local state.

Unexpected successful status:

```text
invalidResponse
```

---

# 24. Attempt Data Source

Create:

```text
frontend/lib/features/student/data/student_homework_attempt_remote_data_source.dart
```

Provider uses:

```text
dioProvider
DioFailureMapper
```

Methods:

```text
Future<StudentHomeworkAttemptStartOperationDto> startAttempt(
  String homeworkId,
  String idempotencyKey,
)

Future<StudentHomeworkAttemptDto> fetchAttempt(
  String attemptId,
)
```

Validate canonical IDs before transport.

---

# 25. Start HTTP Construction

Call exactly:

```dart
dio.post<Object?>(
  '/student/homework/${Uri.encodeComponent(homeworkId)}/attempts',
  data: const <String, Object?>{},
  options: Options(
    followRedirects: false,
    headers: {
      'Idempotency-Key': idempotencyKey,
    },
  ),
)
```

Do not send query parameters.

Accept only success:

```text
200
201
```

Parse exact envelope:

```text
data
```

No automatic Dio retry/replay.

---

# 26. GET Attempt Construction

Call:

```dart
dio.get<Object?>(
  '/student/attempts/${Uri.encodeComponent(attemptId)}',
  options: Options(followRedirects: false),
)
```

No query/body.

Require:

```text
200
```

Parse exact envelope:

```text
data
```

---

# 27. Repository

Create exactly one dedicated Attempt repository boundary:

```text
frontend/lib/features/student/domain/student_homework_attempt_repository.dart
frontend/lib/features/student/data/student_homework_attempt_repository_impl.dart
```

Methods:

```text
Future<StudentHomeworkAttemptStartResult> startAttempt(
  String homeworkId,
  String idempotencyKey,
)

Future<StudentHomeworkAttempt> fetchAttempt(
  String attemptId,
)
```

Ownership is fixed:

```text
StudentHomeworkRepository
  = FE-001 Homework list/detail reads only

StudentHomeworkAttemptRepository
  = FE-002 Start + Attempt read only
```

Do not add Start/Attempt methods to `StudentHomeworkRepository`.

No presentation formatting.

No retry loop.

No local lifecycle decision.

---

# 28. Client Idempotency Key Generator

No UUID package exists in the approved baseline.

Do not add one.

Create:

```text
frontend/lib/core/network/idempotency_key_generator.dart
```

Implement a focused injectable:

```text
IdempotencyKeyGenerator
```

Default implementation generates an RFC 4122-compatible random UUID v4 using:

```text
dart:math Random.secure()
```

Algorithm:

1. generate 16 secure random bytes;
2. set version bits:
   ```text
   byte[6] = (byte[6] & 0x0f) | 0x40
   ```
3. set RFC variant bits:
   ```text
   byte[8] = (byte[8] & 0x3f) | 0x80
   ```
4. format lowercase:
   ```text
   8-4-4-4-12
   ```

No timestamp/device/user data enters the key.

No persistence beyond current logical operation is required.

Provide a Riverpod provider so tests can inject deterministic keys.

Do not use non-secure `Random()`.

---

# 29. Start Controller

Create:

```text
frontend/lib/features/student/application/student_homework_attempt_start_state.dart
frontend/lib/features/student/application/student_homework_attempt_start_controller.dart
```

Family target:

```text
StudentHomeworkRouteTarget
```

from FE-001.

Statuses:

```text
idle
submitting
uncertain
failure
completed
```

State may expose:

```text
failure?
completedAttemptId?
completedResultKind?
```

Do not expose the raw idempotency key to Widgets.

---

# 30. Start Controller Session Ownership

Bind to:

```text
StudentSessionKey
StudentHomeworkRouteTarget
generation
```

On session/target loss:

- invalidate generation;
- clear pending idempotency key;
- return to neutral state.

A completion from an old:

- Student;
- Institution;
- session instance;
- device surface;
- Homework target;
- disposed controller;

must not publish or navigate.

---

# 31. Logical Start Key Lifetime

Controller owns private:

```text
_pendingIdempotencyKey
```

## New logical Start

When Student presses Start from idle/failure after a deterministic prior failure:

- generate one new UUID;
- retain it until outcome classification completes.

## Confirmed success

On `200/201`:

- clear pending key;
- publish completed Attempt ID/result kind.

## Deterministic rejection

On a confirmed structured 4xx response:

- clear pending key;
- publish failure/reconciliation state.

## Uncertain outcome

Retain the **same** key.

Retry must use the same key.

No second key may be generated until this logical operation is reconciled or target/session changes.

---

# 32. Uncertain Outcome Classification

Treat as outcome-uncertain:

```text
ApiFailureKind.connection
ApiFailureKind.timeout
ApiFailureKind.cancelled
ApiFailureKind.invalidResponse
ApiFailureKind.unknown
```

Also treat structured/server failure as uncertain when:

```text
statusCode == null
or
statusCode >= 500
```

Reason:

> the request may have committed server-side before the client lost the response.

State:

```text
uncertain
```

UI message:

```text
We could not confirm whether the attempt started.
Retry to safely check the same request.
```

Action:

```text
Retry
```

uses the same retained key.

Do not show confirmed failure/success.

---

# 32A. Start Session / Account Failure Reconciliation

Session/account gate failures are **not** normal feature-level deterministic
Start failures.

Handle stable codes through the existing Student session reconciliation:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

Required behavior:

1. clear `_pendingIdempotencyKey`;
2. invalidate the current Start generation/ownership;
3. return Start controller state to neutral/cleared;
4. do not publish feature SnackBar/inline Start failure from that stale operation;
5. apply the same existing Student auth/session reconciliation behavior used by
   FE-001 controllers:
   - authentication loss follows current auth routing;
   - password/user/institution gate changes trigger the existing bootstrap/
     reconciliation path where current Student conventions require it.

A late completion after session reconciliation must not publish or navigate.

---

# 33. Deterministic Start Failure Classification

After excluding the session/account failures above, a structured confirmed 4xx
is deterministic for this logical Start operation.

Handle stable codes.

## `deadline_passed`

Show safe text:

```text
The Homework deadline has passed.
```

Trigger Homework detail reconciliation/refresh.

## `attempts_exhausted`

```text
No Homework attempts remain.
```

Refresh detail/list.

## `task_not_active` / `task_closed` / `task_archived`

Show:

```text
This Homework is no longer available for a new attempt.
```

Refresh detail/list.

## `assessment_not_assigned`

Show:

```text
This Homework is no longer assigned to you.
```

Refresh detail and Topic Homework list.

## `resource_not_found`

Treat Homework as unavailable and reconcile FE-001 detail/list.

## `idempotency_key_reused`

This should be exceptional/collision/stale-operation behavior.

Show:

```text
The attempt could not be started safely. Refresh and try again.
```

Clear the key.

Do not silently generate a new key inside the same failed call.

## `business_conflict`

Safe generic conflict.

Refresh detail.

## `validation_failed`

Treat as client/server contract failure, not a field form error.

Clear key and surface safe failure.

Do not branch on message text.

---

# 34. Start Duplicate Suppression

While:

```text
submitting
```

disable Start and Retry controls.

Do not launch a second concurrent Start from the same controller.

While:

```text
uncertain
```

show only the safe same-key Retry path, not a separate new-key Start.

---

# 35. Start Success Reconciliation

On transport-success `200/201`:

1. ensure returned:
   ```text
   attempt.assessmentId == target.homeworkId
   ```
2. if strict success parsing/hierarchy fails:
   ```text
   ApiFailureKind.invalidResponse
   ```
   treat the Start outcome as **uncertain**, retain the same pending key, and do
   not navigate;
3. on valid confirmed success, mark/invalidate FE-001 Homework detail/list as
   stale so future reads refresh used/remaining/in-progress status;
4. publish:
   ```text
   completedAttemptId
   completedResultKind
   ```
5. clear the pending key only after valid success has been confirmed.

Presentation owns navigation after observing a current completed state.

Do not optimistically patch `used` or `remaining`.

---

# 36. Direct Resume Behavior

When FE-001 detail has:

```text
inProgressAttempt
```

the Homework detail Widget navigates directly.

Before building the path, validate canonical:

```text
topicId
homeworkId
attemptId
```

No POST.

No new idempotency key.

No local assumption that the Attempt remains editable.

GET Attempt on the execution route is authoritative.

---

# 37. Attempt Route Target

Create:

```text
frontend/lib/features/student/domain/student_homework_attempt_route_target.dart
```

Fields:

```text
topicId
homeworkId
attemptId
```

All canonical UUIDs.

Value equality/hashCode includes all three.

This is the complete execution-screen target identity.

---

# 38. Canonical Attempt Execution Route

Modify FE-001 route helpers/router.

Add:

```text
AppRouteNames.studentHomeworkAttempt
```

Segment:

```text
studentHomeworkAttemptsSegment = attempts
studentHomeworkAttemptIdParameter = attemptId
```

Canonical route:

```text
/student/topics/:topicId/homework/:homeworkId/attempts/:attemptId
```

Nested under:

```text
studentHomeworkDetail
```

No flat competing:

```text
/student/attempts/:attemptId
```

frontend route.

Backend API remains flat.

---

# 39. Route Helpers

Add:

```text
studentHomeworkAttemptLocation(
  topicId,
  homeworkId,
  attemptId,
)

isStudentHomeworkAttemptPath(path)

studentAttemptIdFromPath(path)
```

Preserve the corrected FE-001 route classifiers as mutually exclusive.

Exact semantics after FE-002:

```text
isStudentTopicDetailPath(path)
  = true only for /student/topics/{topicId}

isStudentHomeworkDetailPath(path)
  = true only for /student/topics/{topicId}/homework/{homeworkId}

isStudentHomeworkAttemptPath(path)
  = true only for
    /student/topics/{topicId}/homework/{homeworkId}/attempts/{attemptId}

studentTopicIdFromPath(path)
  = Topic ID for exact Topic, Homework or Attempt route

studentHomeworkIdFromPath(path)
  = Homework ID for exact Homework or Attempt route
  = null for Topic/root

studentAttemptIdFromPath(path)
  = Attempt ID only for exact Attempt route

isStudentApprovedLocation(path)
  = Student root OR one of the three exact route forms
```

Do not redefine `isStudentTopicDetailPath()` or
`isStudentHomeworkDetailPath()` merely in terms of a broader ID extractor.

Update router bootstrap location preservation so the exact Attempt execution
route remains at its canonical deep-link during auth bootstrap on both desktop
and mobile, just like the corrected FE-001 Homework route.

Reject:

- malformed UUID;
- extra segments;
- singular `attempt`;
- edit/submit aliases;
- query/fragment as canonical route path input where existing router helper semantics reject them.

---

# 40. Attempt Detail Controller

Create:

```text
frontend/lib/features/student/application/student_homework_attempt_state.dart
frontend/lib/features/student/application/student_homework_attempt_controller.dart
```

Family provider keyed by:

```text
StudentHomeworkAttemptRouteTarget
```

Statuses:

```text
initial
loading
data
refreshing
notFound
error
```

State:

```text
attempt?
failure?
```

---

# 41. Attempt Controller Load

Call repository:

```text
fetchAttempt(target.attemptId)
```

After success require:

```text
attempt.id == target.attemptId
attempt.assessmentId == target.homeworkId
```

If not:

```text
notFound / invalid target
```

Do not render another Homework's Attempt under the route hierarchy.

Topic hierarchy is validated by simultaneously using FE-001:

```text
studentHomeworkDetailControllerProvider(
  StudentHomeworkRouteTarget(
    topicId,
    homeworkId,
  ),
)
```

The execution screen must not consider its route fully valid unless both:

```text
Homework detail confirms topicId/homeworkId
Attempt confirms homeworkId/attemptId
```

No extra backend authorization endpoint is invented.

---

# 42. Attempt Session / Stale Completion Safety

Bind publication to:

```text
StudentSessionKey
StudentHomeworkAttemptRouteTarget
generation
```

Follow FE-001 Student detail pattern.

Stale completion cannot:

- replace another Attempt;
- publish after logout;
- publish across Student switch;
- publish after route disposal;
- publish after newer refresh.

On session failure:

- clear state/ownership;
- use existing auth bootstrap behavior.

---

# 43. Attempt 404 Reconciliation

Backend:

```text
404 resource_not_found
```

becomes:

```text
notFound
```

Also mark/invalidate:

```text
FE-001 Homework detail
Topic Homework list
```

for the route target.

Do not leak raw Attempt URL/server message.

---

# 44. Execution Screen

Create:

```text
frontend/lib/features/student/presentation/student_homework_attempt_screen.dart
```

Scaffold key:

```text
studentHomeworkAttemptScreen
```

Use existing Student destination gate.

Supported:

```text
desktop
mobile
```

No authoring device restriction.

---

# 45. Execution Screen Parent State Composition

Watch:

```text
StudentHomeworkDetailController(target topic/homework)
StudentHomeworkAttemptController(target topic/homework/attempt)
```

Required rendering:

## Parent Homework notFound

Show:

```text
Homework unavailable
Back to Topic
```

## Attempt notFound

Show:

```text
Attempt unavailable
Back to Homework
```

## Either session-ineligible

Existing destination/session behavior applies.

## Loading / retained parent state

Show progress until required current hierarchy is known.

A retained `refreshing`/stale Homework detail is not sufficient to establish the
current parent hierarchy for a new execution view. Render the execution shell
only after:

```text
Homework detail = confirmed current data for target
Attempt = confirmed current data for target
```

A terminal Attempt is still valid read-only data once both hierarchy components
are confirmed.

Do not show execution controls/content with only stale/partial target
validation.

---

# 46. Execution Shell Content

When hierarchy is valid, display:

## Header

```text
Homework title
Attempt <N>
Attempt status
```

## Timing

```text
Started
Deadline if present
Submitted if present
Finalized if present
Finalization reason if present
```

Format using authenticated Institution timezone.

No countdown.

No local deadline eligibility.

## Questions

Render safe FE-001 Question read views.

For each Question display:

```text
Saved answer
```

or:

```text
Not answered
```

based solely on whether an answer entry exists.

No editor.

No Save button.

No Submit button.

---

# 47. Saved Answer Read-Only Summary

Create a focused:

```text
StudentAttemptAnswerReadView
```

or equivalent.

It may show the Student's own saved value in a non-editable way.

## Choice

Show selected option text when option IDs resolve in the safe Question model.

If saved option ID failed cross-collection parsing, the DTO would already be invalid.

## Boolean

Show:

```text
True
False
```

## Written

Show exact saved Student text.

Use selectable/wrapped text.

## Matching

Show Student-selected left → right mappings using safe Question item text.

Do not show correct mapping.

## Ordering

Show submitted order according to saved `position`.

Do not label it correct.

## Fill Blank

Show:

```text
blank key -> Student text
```

No accepted answers.

## File

Show:

```text
original filename
extension
size
```

No Open/Download button in FE-002.

---

# 48. Terminal Attempt Shell

If GET Attempt returns:

```text
submitted
waiting_for_teacher_review
checked
```

the execution shell remains read-only.

Show status/finalization information.

Do not attempt to reopen editors.

Do not display score.

This makes direct Resume navigation safe even when FE-001 detail was stale and the Attempt has since been finalized.

---

# 49. Homework Detail Start/Resume Controls

Modify:

```text
student_homework_detail_screen.dart
```

## Confirmed in-progress Attempt

Button key:

```text
studentHomeworkResumeAttemptButton
```

Text:

```text
Resume Attempt <N>
```

Direct navigation.

## No current Attempt + active + remaining > 0

Button key:

```text
studentHomeworkStartAttemptButton
```

Text:

```text
Start Attempt
```

Calls Start controller.

## No capacity / non-active

No Start button.

Do not rely on:

```text
DateTime.now()
deadline comparison
```

for visibility.

---

# 50. Start Mutation UX

During:

```text
submitting
```

Button:

- disabled;
- shows progress/busy semantics;
- prevents duplicate tap.

On deterministic failure:

- remain on Homework detail;
- show safe SnackBar/inline status;
- refresh/reconcile authoritative detail where contracted.

On uncertain failure:

- do not show normal Start button;
- show:
  ```text
  Retry Start
  ```
- explain outcome is unconfirmed;
- Retry same key.

On confirmed success:

- navigate to canonical Attempt route;
- if status 201/created, optional safe feedback:
  ```text
  Attempt started.
  ```
- if 200/resumed:
  ```text
  Existing attempt resumed.
  ```

Do not use these labels for logic.

---

# 51. Navigation Stale Safety

Navigation after Start success may occur only when:

- Widget context remains mounted;
- controller's target is still current;
- Student session remains the same eligible session;
- completion belongs to current generation;
- completed Attempt ID is canonical.

The controller should clear/consume completion after navigation signal so rebuilds do not navigate repeatedly.

Do not navigate from an obsolete async completion.

---

# 52. Start Result `200` Race Handling

Even when FE-001 showed no `in_progress_attempt`, backend may return:

```text
200 resumed
```

because another device/request created one first.

Treat it as success.

Navigate to returned Attempt.

Do not show conflict.

Do not consume an additional attempt locally.

---

# 53. Idempotency Replay After Uncertain First Response

Example:

1. Student taps Start.
2. Backend creates Attempt and commits.
3. client times out.
4. controller enters `uncertain` with retained key.
5. Student presses Retry.
6. same key is sent.
7. backend returns original logical Attempt/status.

Flutter must:

- accept 200 or 201 according to backend replay;
- navigate to returned Attempt;
- clear retained key;
- never generate a second key for this Retry.

This exact case requires a deterministic controller test.

---

# 54. Detail Refresh During Uncertain Start

Do not automatically discard the pending key merely because FE-001 Homework detail refresh shows an `in_progress_attempt`.

The original Start result is still logically reconcilable with the retained key.

However presentation may offer a safe secondary action:

```text
Open current attempt
```

only if the refreshed backend detail exposes an exact `in_progress_attempt`.

If the user chooses it:

- navigate directly to that Attempt;
- clear the abandoned pending Start operation key/controller state because authoritative read has identified the current Attempt.

Do not start another request.

This secondary action is optional; if omitted, same-key Retry is sufficient.

---

# 55. API Error Codes

Modify:

```text
frontend/lib/core/network/api_error_codes.dart
```

Add only Stage 7 codes required by FE-002:

```text
attemptsExhausted = attempts_exhausted
idempotencyKeyReused = idempotency_key_reused
```

Do not pre-add later FE-003/004/005-only codes unless the delivered implementation already added them.

Reuse existing:

```text
taskNotActive
taskClosed
taskArchived
assessmentNotAssigned
deadlinePassed
businessConflict
resourceNotFound
validationFailed
```

---

# 56. No Optimistic Attempt Counts

After Start:

Do not locally:

```text
used++
remaining--
set myStatus
construct inProgressAttempt
```

Instead:

- navigate using confirmed returned Attempt;
- invalidate/refresh FE-001 detail/list for later authoritative counts.

Backend is authoritative.

---

# 57. Accessibility

Required:

- Start/Resume button semantic labels are explicit;
- submitting state exposes busy/progress semantics;
- uncertain state text is announced/readable;
- Retry Start is keyboard/touch accessible;
- Attempt status text does not rely on color;
- Saved/Not answered state is textual;
- Question headings remain semantic;
- terminal status is announced/readable;
- back/refresh controls have tooltips.

No focus trap.

---

# 58. Responsiveness

Support desktop and mobile.

Attempt screen:

- centered max-width content;
- single-column baseline;
- wrap metadata/status chips;
- long Student written answers wrap/scroll vertically;
- no horizontal overflow;
- matching read-only mappings stack safely on mobile;
- file metadata wraps.

Do not add desktop-only Attempt execution.

---

# 59. Expected Files

## Create

```text
frontend/lib/core/network/idempotency_key_generator.dart

frontend/lib/features/student/domain/student_homework_attempt.dart
frontend/lib/features/student/domain/student_homework_attempt_repository.dart
frontend/lib/features/student/domain/student_homework_attempt_route_target.dart

frontend/lib/features/student/data/dto/student_homework_attempt_dto.dart
frontend/lib/features/student/data/student_homework_attempt_remote_data_source.dart
frontend/lib/features/student/data/student_homework_attempt_repository_impl.dart

frontend/lib/features/student/application/student_homework_attempt_start_state.dart
frontend/lib/features/student/application/student_homework_attempt_start_controller.dart
frontend/lib/features/student/application/student_homework_attempt_state.dart
frontend/lib/features/student/application/student_homework_attempt_controller.dart

frontend/lib/features/student/presentation/student_homework_attempt_screen.dart
frontend/lib/features/student/presentation/student_attempt_answer_read_view.dart

frontend/test/core/network/idempotency_key_generator_test.dart
frontend/test/features/student/student_homework_attempt_dto_test.dart
frontend/test/features/student/student_homework_attempt_data_test.dart
frontend/test/features/student/student_homework_attempt_start_controller_test.dart
frontend/test/features/student/student_homework_attempt_controller_test.dart
frontend/test/features/student/student_homework_attempt_screen_test.dart
frontend/test/features/student/student_homework_attempt_routing_test.dart
```

## Modify

```text
frontend/lib/features/student/presentation/student_homework_detail_screen.dart
frontend/lib/features/student/presentation/student_homework_formatters.dart

frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart

frontend/lib/core/network/api_error_codes.dart
```

Do not modify FE-001 `StudentHomeworkRepository` / repository implementation
to add Attempt operations. The dedicated Attempt repository in this contract is
the only owner of Start/Attempt read transport.

No backend files.

No `pubspec.yaml` or `pubspec.lock` change.

No platform files.

---

# 60. UUID Generator Tests

`idempotency_key_generator_test.dart` must generate many sample keys and verify:

```text
canonical lowercase 8-4-4-4-12
version nibble = 4
variant = RFC 4122 10xx
no duplicates in focused sample
```

The no-duplicate sample is a smoke property, not a proof of randomness.

Use deterministic injected generator/fake in controller tests.

Do not test statistical randomness quality.

---

# 61. Attempt DTO Tests

Cover valid:

- in_progress;
- explicit submitted;
- deadline auto-finalized submitted;
- close auto-finalized submitted;
- forward-compatible waiting_for_teacher_review;
- checked;
- null/non-null deadline;
- all nine Question types reused from FE-001;
- every saved answer type;
- zero saved answers;
- partial saved answers.

Reject:

- `timed_out_finalized`;
- `timeout_auto_submit`;
- incoherent timestamps/reason;
- deadline-finalized Attempt where `deadline_at` is null;
- deadline-finalized Attempt where `finalized_at != deadline_at`;
- student-submit/close reason at or after a non-null deadline;
- `started_at > submitted_at/finalized_at`;
- Attempt number outside 1..3;
- malformed/non-whole-second/non-UTC timestamps;
- unknown keys;
- score/checking fields;
- duplicate Question/Answer IDs;
- duplicate/non-contiguous/out-of-order Question positions;
- Answer referencing missing Question;
- Answer type mismatch;
- saved Multiple Choice count above safe `maxSelections`;
- saved Ordering position outside `1..Question.items.length`;
- saved written/fill text whose `trim().isEmpty`;
- saved child ID outside safe Question;
- storage internals in file answer.

---

# 62. Data Source Tests

`student_homework_attempt_data_test.dart` verifies exact:

## Start

```text
POST /student/homework/{id}/attempts
Idempotency-Key header exactly present
body = {}
no query
followRedirects = false
```

Map:

```text
201 -> created
200 -> resumed
```

Unexpected success status rejected.

## Fetch

```text
GET /student/attempts/{id}
```

No query/body.

## Failure

Dio failures map through existing infrastructure.

Malformed success → invalidResponse.

No automatic retry.

---

# 63. Start Controller Tests

At minimum:

## New Start success

Injected key:

```text
11111111-1111-4111-8111-111111111111
```

Repository receives it once.

201 -> completed created.

## Backend resume race

200 -> completed resumed.

## Duplicate tap

While submitting, second call is ignored.

## Uncertain timeout

- first call uses key A;
- timeout;
- state uncertain;
- retry uses same key A;
- success;
- no new generator call.

## Uncertain 500

Same retained-key behavior.

## Deterministic 409

- key cleared;
- state failure;
- a later explicit new Start generates key B.

## Invalid success response / hierarchy mismatch

- first call uses key A;
- backend transport returns 200/201 but strict payload/hierarchy is invalid;
- state becomes uncertain;
- key A is retained;
- Retry uses key A again;
- no new generator call.

## `idempotency_key_reused`

No silent automatic new-key retry.

## Session/account failures

For each relevant stable gate code:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

verify:

- key cleared;
- Start state/ownership cleared;
- existing auth/session reconciliation invoked as contracted;
- no stale feature feedback/navigation.

## Session switch

Old completion ignored; pending key cleared.

## Dispose

Late completion ignored.

## Target change

Old completion cannot publish to another Homework.

---

# 64. Attempt Controller Tests

Cover:

- eligible auto-load;
- loading/data;
- refresh;
- 404 notFound;
- invalid hierarchy:
  ```text
  attempt.assessmentId != target.homeworkId
  ```
  rejected;
- session failure;
- Student switch;
- stale refresh completion;
- disposal;
- current terminal Attempt accepted as read-only.

No arbitrary sleeps.

---

# 65. Homework Detail Widget Tests

Update FE-001 screen tests.

Verify:

## In-progress detail

Shows:

```text
Resume Attempt N
```

No Start button.

Tap builds/navigates to exact Attempt route.

No POST controller call.

## Available new Attempt

Only confirmed-current FE-001 `data` state with:

```text
active
remaining > 0
in_progress_attempt = null
not stale/refreshing
```

shows:

```text
Start Attempt
```

## Retained/non-authoritative detail state

For:

```text
loading
refreshing
stale
error
notFound
```

do not expose a new Start action from retained lifecycle/capacity values.

## Non-active / zero remaining

No Start button.

## Submitting

Button disabled/busy.

## Uncertain

Shows safe unconfirmed message and:

```text
Retry Start
```

No normal Start new-key action.

## Deterministic failure

Safe feedback.

No fake decrement/count changes.

---

# 66. Attempt Screen Tests

Desktop + mobile.

Cover:

- loading;
- Homework notFound;
- Attempt notFound;
- error/retry;
- data;
- refreshing;
- in-progress shell;
- terminal shell;
- timing/status labels;
- Questions;
- Saved vs Not answered;
- all saved answer read views;
- file metadata only;
- no editors;
- no Save;
- no Submit;
- no score/checking;
- back to Homework.

Assert no horizontal overflow in focused narrow-width/text-scale case.

---

# 67. Routing Tests

Verify canonical:

```text
/student/topics/{topic}/homework/{homework}/attempts/{attempt}
```

Test:

- helper path;
- all 3 UUID validation;
- exact Attempt route recognition;
- `isStudentTopicDetailPath` is false for Homework and Attempt routes;
- `isStudentHomeworkDetailPath` is false for Attempt route;
- `isStudentHomeworkAttemptPath` is true only for exact Attempt route;
- Topic extraction works for Topic/Homework/Attempt routes;
- Homework extraction works for Homework/Attempt routes only;
- Attempt extraction works only for Attempt route;
- approved Student location;
- malformed IDs rejected;
- extra path segment rejected;
- direct entry renders Attempt screen through Student destination gate;
- canonical Attempt deep-link is preserved during bootstrap on desktop/mobile;
- query/fragment follows existing Student rejection/redirect behavior;
- wrong/ineligible session uses existing technical-root behavior;
- back action returns to Homework detail.

Confirm no flat frontend Attempt route exists.

---

# 68. Directly Affected Regression Tests

Run FE-002 tests plus the exact corrected FE-001/directly affected boundaries:

```text
test/features/student/student_homework_dto_test.dart
test/features/student/student_homework_data_test.dart
test/features/student/student_homework_controller_test.dart
test/features/student/student_homework_screen_test.dart
test/features/student/student_homework_routing_test.dart
test/features/student/student_workspace_screen_test.dart
test/router_bootstrap_test.dart
```

If delivered FE-001 materially does not contain these approved boundaries,
return `BLOCKED` for dependency-contract mismatch instead of silently remapping
verification.

Do not run the full frontend suite in this individual task.

---

# 69. Verification

Run from:

```text
frontend/
```

## 69.1 Focused FE-002 + directly affected FE-001/router regressions

Exactly:

```bash
flutter test \
  test/core/network/idempotency_key_generator_test.dart \
  test/features/student/student_homework_attempt_dto_test.dart \
  test/features/student/student_homework_attempt_data_test.dart \
  test/features/student/student_homework_attempt_start_controller_test.dart \
  test/features/student/student_homework_attempt_controller_test.dart \
  test/features/student/student_homework_attempt_screen_test.dart \
  test/features/student/student_homework_attempt_routing_test.dart \
  test/features/student/student_homework_dto_test.dart \
  test/features/student/student_homework_data_test.dart \
  test/features/student/student_homework_controller_test.dart \
  test/features/student/student_homework_screen_test.dart \
  test/features/student/student_homework_routing_test.dart \
  test/features/student/student_workspace_screen_test.dart \
  test/router_bootstrap_test.dart
```

Narrow single-test diagnostic reruns are allowed only to diagnose/confirm a
concrete failure.

## 69.2 Exact Dart format check

Exactly:

```bash
dart format --output=none --set-exit-if-changed \
  lib/core/network/idempotency_key_generator.dart \
  lib/core/network/api_error_codes.dart \
  lib/features/student/domain/student_homework_attempt.dart \
  lib/features/student/domain/student_homework_attempt_repository.dart \
  lib/features/student/domain/student_homework_attempt_route_target.dart \
  lib/features/student/data/dto/student_homework_attempt_dto.dart \
  lib/features/student/data/student_homework_attempt_remote_data_source.dart \
  lib/features/student/data/student_homework_attempt_repository_impl.dart \
  lib/features/student/application/student_homework_attempt_start_state.dart \
  lib/features/student/application/student_homework_attempt_start_controller.dart \
  lib/features/student/application/student_homework_attempt_state.dart \
  lib/features/student/application/student_homework_attempt_controller.dart \
  lib/features/student/presentation/student_homework_attempt_screen.dart \
  lib/features/student/presentation/student_attempt_answer_read_view.dart \
  lib/features/student/presentation/student_homework_detail_screen.dart \
  lib/features/student/presentation/student_homework_formatters.dart \
  lib/app/router/app_route_paths.dart \
  lib/app/router/app_router.dart \
  test/core/network/idempotency_key_generator_test.dart \
  test/features/student/student_homework_attempt_dto_test.dart \
  test/features/student/student_homework_attempt_data_test.dart \
  test/features/student/student_homework_attempt_start_controller_test.dart \
  test/features/student/student_homework_attempt_controller_test.dart \
  test/features/student/student_homework_attempt_screen_test.dart \
  test/features/student/student_homework_attempt_routing_test.dart \
  test/features/student/student_homework_screen_test.dart \
  test/features/student/student_homework_routing_test.dart \
  test/router_bootstrap_test.dart
```

## 69.3 Static analysis

Exactly:

```bash
flutter analyze
```

## 69.4 Diff hygiene

From repository root exactly:

```bash
git diff --check
```

Then perform the focused diff/scope self-review required by root/frontend
`AGENTS.md`.

Do not run:

- full frontend test suite;
- target build;
- backend suite;
- E2E/integration runner.

---

# 70. Acceptance Criteria

PASS only if all are true.

## Idempotency

- secure UUID v4 generated without dependency;
- Start sends exact key/header/body;
- uncertain outcome retains same key;
- Retry reuses same key;
- deterministic failure clears logical operation key;
- no auto retry with a new key;
- stale session/target cannot reuse/publish old operation.

## Start/Resume

- confirmed FE-001 in-progress Attempt resumes by direct navigation;
- no redundant POST for confirmed Resume;
- new Start is offered only from confirmed current/non-stale FE-001 detail;
- retained/loading/refreshing/stale/error/notFound detail cannot authorize a new
  Start action;
- Start POST accepts backend 201 create / 200 race-resume;
- malformed successful Start response is treated as uncertain and retains the
  same key;
- returned Attempt hierarchy is checked;
- no optimistic counts.

## Attempt read

- GET Attempt is strict/typed;
- Attempt timestamps/lifecycle/deadline reason invariants are coherent;
- all saved answer types parse safely;
- saved Multiple Choice/Ordering/text values respect their safe Question/domain
  bounds without checking correctness;
- Question positions remain exact `1..N` ascending;
- cross-collection answer/Question integrity is validated;
- no correctness/checking/score/storage fields enter domain.

## Routing

- nested canonical execution route exists;
- Topic/Homework/Attempt classifiers remain mutually exclusive;
- broader Topic/Homework ID extractors correctly support nested Attempt route;
- bootstrap preserves canonical Attempt deep-link on desktop/mobile;
- deep-link hierarchy validates Topic/Homework/Attempt composition;
- no competing flat frontend route.

## Application

- Start and Attempt controllers are session/target/generation safe;
- dedicated `StudentHomeworkAttemptRepository` exclusively owns Start/Attempt
  read operations;
- duplicate mutation suppressed;
- stale completions cannot navigate/publish;
- session/account gate failures clear operation ownership/key and use existing
  Student auth reconciliation rather than feature failure UX;
- deterministic vs uncertain failures are distinct.

## UI

- FE-001 Homework detail gains Start/Resume controls only when backend-confirmed state permits;
- Attempt shell works desktop/mobile;
- own saved answers are read-only;
- terminal Attempts remain readable;
- no editors/Save/Submit/score/checking;
- accessibility/responsiveness requirements pass.

## Scope

- no answer mutation;
- no file picker/download UX;
- no final Submit;
- no score/review;
- no package/platform/backend change.

## Verification

- exact focused test command passes;
- exact named FE-001/router regressions pass;
- exact Dart format command passes;
- `flutter analyze` passes;
- `git diff --check` passes;
- focused self-review passes.

---

# 71. Locked Implementation Decisions

These are decisions, not suggestions:

```text
confirmed current Attempt => direct Resume navigation, no POST
new Start action => only confirmed current/non-stale FE-001 detail
no current Attempt + active + remaining>0 => Start POST
retained/refreshing/stale Homework detail => no new Start action
Start success 201 = created
Start success 200 = resumed
Start malformed 2xx payload = uncertain, SAME key retained
Start Idempotency-Key = secure client UUID v4
uncertain Start retry = SAME key
deterministic failed logical Start = key discarded
session/account gate failure = key/ownership cleared + existing auth reconciliation
no automatic new-key retry
Attempt repository = dedicated StudentHomeworkAttemptRepository
Attempt API route = /student/attempts/:id
frontend execution route = nested Topic/Homework/Attempt path
Topic/Homework/Attempt route classifiers = mutually exclusive
Attempt deep-link = bootstrap-preserved desktop/mobile
Attempt shell = read-only in FE-002
saved answer domain = typed, no raw maps
Attempt/Homework timestamps = exact whole-second UTC Z
deadline finalization => finalizedAt == deadlineAt
saved Multiple Choice <= maxSelections
saved Ordering positions <= Question item count
written/fill persisted text trim().isNotEmpty but exact value preserved
device deadline = never eligibility authority
backend used/remaining/inProgress = authoritative
no optimistic count/state mutation
```

Codex must not substitute:

- `uuid` package addition;
- insecure random key;
- new key on timeout/invalid-response Retry;
- treating session/account gate errors as ordinary feature failure;
- new Start action from retained/refreshing/stale Homework detail;
- POST for every confirmed Resume;
- adding Start/Attempt methods to FE-001 `StudentHomeworkRepository`;
- broadening Topic/Homework route classifiers to match Attempt routes;
- flat `/student/attempts/:id` frontend navigation route;
- Teacher Question model/config reuse;
- score/checking fields;
- answer editing before FE-003;
- local deadline logic.

---

# 72. Completion Report

Return only:

```text
IMPLEMENTATION COMPLETE
```

or:

```text
BLOCKED
```

with:

1. implementation summary;
2. changed files and purpose;
3. exact focused test results;
4. idempotency-key generation/same-key uncertain retry evidence;
5. 201-create / 200-resume + malformed-2xx uncertain evidence;
6. strict Attempt/lifecycle/answer DTO evidence;
7. session/account reconciliation + stale-completion evidence;
8. mutually exclusive nested routing/bootstrap direct-entry evidence;
9. desktop/mobile shell evidence;
10. directly affected regressions;
11. format/analyze results;
12. `git diff --check`;
13. scope/non-goal confirmation;
14. deviations/blockers;
15. final `git status --short`.

Do not claim `Accepted`.

Do not commit/push/create PR/update Stage bookkeeping unless explicitly instructed later.
