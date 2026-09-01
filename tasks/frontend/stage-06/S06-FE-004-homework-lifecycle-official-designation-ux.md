# Codex Implementation Contract: S06-FE-004 — Homework Lifecycle and Official Designation UX

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S06-FE-004` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter Homework lifecycle + official Homework designation UX` |
| Depends on | `S06-FE-001…003` all `Accepted / Delivered`; Stage 6 Backend Phase 2 remains `PASS` |
| Planning/readiness baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |
| Backend API dependency | Final delivered S06-BE-005/S06-BE-006 APIs after Backend Phase 2 |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` immediately before Codex execution |
| Flutter toolchain | FVM-pinned Flutter `3.44.7` unless current `origin/main` deliberately changes the pin |
| Implementation Readiness Gate | `PASS — planning contract`; execution remains dependency-gated |
| Verification | `Codex — focused frontend verification only` |
| Delivery execution | `Project Owner` |
| Frontend block checkpoint | Stage 6 Frontend Phase 2 immediately after `S06-FE-001…004` are `Accepted / Delivered` |

Do not start implementation until:

```text
Stage 6 Backend Phase 2 = PASS
S06-FE-001 = Accepted / Delivered
S06-FE-002 = Accepted / Delivered
S06-FE-003 = Accepted / Delivered
current origin/main re-checked
final Homework lifecycle/result-pair backend behavior inspected
current Homework detail/list/Question Builder integration inspected
this contract still matches current implementation
clean synchronized local main
```

If delivered dependencies materially conflict with this contract, return `BLOCKED` with exact evidence. Do not invent a new lifecycle/result-pair/UX/API contract.

This file is the complete task-specific implementation contract. Do not create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this implementation contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. delivered S06-FE-001…003 source/tests directly required by this task;
5. final delivered S06-BE-005/S06-BE-006 route/resource implementation needed to confirm the API already encoded below;
6. current Stage 5 Topic lifecycle controller/presentation patterns directly required for integration.

Do not read product specifications, roadmap files, Stage history, previous task specifications, checkpoint reviews, closure reviews, or unrelated modules to determine requirements.

This contract already resolves:

- Homework activate/close/archive UX;
- desktop/mobile capability boundary;
- confirmation behavior;
- lifecycle mutation uncertainty/reconciliation;
- activation-specific server conflict UX;
- official result-pair domain/read state;
- official Homework designation/replacement;
- result-pair mutation uncertainty/reconciliation;
- official badges;
- official draft archive UX;
- result-pair lock UX;
- Topic `topic_has_open_assessments` integration;
- cache/detail/list reconciliation;
- stale async/session/route safety;
- accessibility;
- exact scope exclusions.

---

# 3. Goal

Complete the Stage 6 Teacher Homework management UX.

An authenticated Teacher must be able to:

### Desktop

- activate an eligible draft Homework;
- close an active Homework;
- archive a draft or closed Homework;
- see authoritative lifecycle state after each mutation;
- see whether a Homework is the Topic's official result-bearing Homework;
- designate an eligible whole-group draft/active Homework as official;
- replace an existing official Homework before the backend locks result meaning;
- understand when official designation is locked;
- receive clear guidance when Topic close/archive is blocked by open Homework.

### Mobile

- keep the FE-001 Homework/detail read experience;
- see official Homework status read-only;
- see lifecycle state read-only;
- perform no Homework lifecycle or official-designation mutation.

The Laravel backend remains authoritative for:

- lifecycle eligibility;
- activation readiness;
- deadline validity;
- recipient validity;
- Student activity locks;
- official whole-group eligibility;
- result-pair lock;
- Topic lifecycle compatibility.

---

# 4. Included Backend APIs

Use configured Dio base `/api/v1`.

## 4.1 Homework lifecycle

```text
POST /teacher/homework/{homeworkId}/activate
POST /teacher/homework/{homeworkId}/close
POST /teacher/homework/{homeworkId}/archive
```

Success:

```text
200 OK
```

Exact success messages:

```text
Homework activated successfully.
Homework closed successfully.
Homework archived successfully.
```

Each returns the complete authoritative Teacher Homework resource.

## 4.2 Result pair read

```text
GET /teacher/topics/{topicId}/result-pair
```

Success:

```text
200 OK
```

No pair:

```json
{
  "data": null
}
```

## 4.3 Official Homework designation

```text
PUT /teacher/topics/{topicId}/result-pair
```

Stage 6 body exactly:

```json
{
  "homework_assessment_id": "uuid"
}
```

Success:

```text
200 OK
```

Exact success message:

```text
Topic result pair updated successfully.
```

Do not send or require:

```text
blitz_assessment_id
```

from Stage 6 Flutter.

---

# 5. Explicit Non-Goals

Do not implement:

- Student Homework execution;
- Attempt start/save/submit;
- checking/scoring;
- deadline scheduler UI;
- manual review;
- official score;
- Blitz authoring/designation;
- result comparison;
- Topic result/category UI;
- result release;
- pair clear/delete endpoint;
- changing official Homework to selected-student mode;
- automatic lifecycle transitions based on client time;
- device-clock deadline enforcement;
- mobile lifecycle controls;
- mobile official designation controls;
- lifecycle controls inside Question Builder;
- lifecycle controls inside metadata Edit screen;
- optimistic mutation success;
- automatic mutation replay;
- backend changes;
- new package;
- platform changes;
- full frontend suite/build/E2E.

Do not expose `blitz_assessment_id` as a Teacher-editable Stage 6 field.

Do not add “future Blitz” placeholder controls.

---

# 6. Dependency Contract from S06-FE-001…003

Reuse equivalent delivered boundaries:

```text
TeacherHomework
TeacherHomeworkSummary
TeacherHomeworkStatus
TeacherHomeworkAssignmentMode
TeacherHomeworkAttemptPolicy
TeacherHomeworkRepository
TeacherHomeworkRemoteDataSource
TeacherHomeworkRouteTarget
teacherHomeworkDetailControllerProvider(target)
teacherHomeworkListControllerProvider(topicId)
TeacherHomeworkDetailScreen
TeacherHomeworkSection
TeacherQuestionBuilderScreen
TeacherSessionKey
ApiFailure
ApiRequestException
ApiErrorCodes
```

Reuse FE-002 mutation uncertainty/envelope conventions.

Reuse FE-003 server-lock/read-authority conventions where applicable.

Do not create another Homework domain/DTO/repository hierarchy.

---

# 7. No New Authoring Route

S06-FE-004 adds **no new Flutter route**.

Lifecycle controls and official designation live on:

```text
TeacherHomeworkDetailScreen
```

Official read badges also appear in:

```text
TeacherHomeworkSection
TeacherHomeworkDetailScreen
```

No lifecycle/official control appears on mobile.

No new ShellRoute.

---

# 8. Homework Lifecycle Domain

Create/reuse:

```text
TeacherHomeworkLifecycleAction
```

Exact values:

```text
activate
close
archive
```

with exact path segments:

```text
activate
close
archive
```

Presentation labels:

```text
Activate
Close
Archive
```

Machine values must not be derived from labels.

---

# 9. Homework Lifecycle Action Availability

Client-side action visibility is only a UX projection of confirmed server status.

## Draft

Show on desktop:

```text
Activate
Archive
```

except official-draft Archive UX in Section 35.

## Active

Show:

```text
Close
```

## Closed

Show:

```text
Archive
```

## Archived

Show no lifecycle mutation action.

Do not render a same-target action button such as Activate on already active Homework.

Backend idempotency remains important for retries/concurrent state changes.

Mobile shows no lifecycle controls.

---

# 10. Lifecycle Confirmation Dialogs

Every lifecycle action requires explicit confirmation.

## Activate

Title:

```text
Activate Homework?
```

Body:

```text
Students assigned by the server will be able to use this Homework when Stage execution rules allow it.
The backend will validate Questions, points, recipients, Topic state, and deadline.
```

Do not claim activation will succeed.

Buttons:

```text
Cancel
Activate
```

## Close

Title:

```text
Close Homework?
```

Body:

```text
Closing stops further normal Homework activity.
The backend will confirm whether the Homework can be closed now.
```

Do not claim/infer Student Attempt state.

Buttons:

```text
Cancel
Close
```

## Archive

Title:

```text
Archive Homework?
```

Body:

```text
Archived Homework remains historical and read-only.
```

Buttons:

```text
Cancel
Archive
```

No mutation is sent before confirmation.

---

# 11. Lifecycle Repository Extension

Extend delivered:

```text
TeacherHomeworkRepository
```

with:

```text
Future<TeacherHomework> performLifecycleAction(
  String homeworkId,
  TeacherHomeworkLifecycleAction action,
)
```

Do not create a second lifecycle repository.

---

# 12. Lifecycle Remote Data Source

Extend:

```text
TeacherHomeworkRemoteDataSource
```

Request:

```text
POST /teacher/homework/{encodedHomeworkId}/{action.segment}
```

Requirements:

- canonical Homework UUID;
- no request body;
- no query;
- `followRedirects = false`;
- require `200`;
- require exact operation-specific success message;
- parse returned full Homework through FE-001 strict DTO.

Do not send:

```json
{}
```

unless the delivered backend/client convention explicitly requires it. Preferred client request is no body.

---

# 13. Lifecycle Mutation Uncertainty

Lifecycle POST may commit before the client receives a reliable response.

Reuse/create a typed unknown-outcome exception if FE-002's mutation abstraction supports operation identity safely.

Do not automatically replay lifecycle POST.

Although backend same-target operations are idempotent, this frontend follows the project mutation-reconciliation rule:

```text
unknown outcome -> authoritative GET -> classify
```

rather than automatic replay.

Unknown includes:

- timeout/network ambiguity;
- malformed success resource;
- unexpected status/envelope;
- local parse failure after potential 2xx commit.

---

# 14. Lifecycle Definite Failure Classification

Recognize exact structured failures.

Common:

```text
401 authentication_required

403 forbidden
403 password_change_required
403 user_inactive
403 institution_inactive

404 resource_not_found

422 validation_failed

429 rate_limited
```

Documented lifecycle 409 codes:

```text
topic_not_editable
task_not_active
task_closed
task_archived
business_conflict
assessment_has_no_scoreable_points
assessment_not_assigned
deadline_passed
```

Do not classify unknown future 409s as definite without a contract update.

Non-validation definite errors require empty `errors`.

---

# 15. API Error Code Additions

Extend `ApiErrorCodes` only where missing.

Required by FE-004:

```text
taskNotActive = 'task_not_active'
assessmentNotAssigned = 'assessment_not_assigned'
deadlinePassed = 'deadline_passed'
topicHasOpenAssessments = 'topic_has_open_assessments'
```

Reuse delivered additions:

```text
taskClosed
taskArchived
officialTaskRequiresGroupAssignment
resultPairLocked
assessmentHasNoScoreablePoints
```

and existing:

```text
businessConflict
topicNotEditable
resourceNotFound
validationFailed
```

Do not add unrelated Stage 7/8 codes.

---

# 16. Homework Lifecycle Controller

Create autoDispose family:

```text
TeacherHomeworkLifecycleController
TeacherHomeworkLifecycleState
```

keyed by:

```text
TeacherHomeworkRouteTarget(topicId, homeworkId)
```

Ownership:

```text
TeacherSessionKey
route target
operation generation
active lifecycle action
```

Desktop mutation only.

The controller reads the FE-001 detail controller as the authoritative current Homework source.

---

# 17. Lifecycle Controller States

Use a focused representation covering:

```text
idle
submitting
reconciling
confirmedSuccess
definiteFailure
outcomeReview
unavailable
```

State may include:

```text
activeAction
feedback
pendingAction
failure category
```

Do not duplicate the full Homework object in lifecycle state if FE-001 detail already owns it.

`isBusy` must disable all lifecycle and official mutation controls on the same Homework detail screen.

---

# 18. Lifecycle Submit Flow

Required:

1. confirmed desktop Teacher session;
2. current route target;
3. confirmed current Homework;
4. action is locally visible for current status;
5. no lifecycle operation already active;
6. no official designation mutation active on the same detail screen;
7. user confirmed;
8. send mutation once.

On confirmed success:

- accept returned authoritative Homework in FE-001 detail controller;
- invalidate Topic Homework list;
- refresh result-pair read if it exists/was loaded because activation may set `cohort_snapshotted_at`;
- publish success feedback;
- remain on Homework detail.

Do not navigate away automatically after lifecycle success.

---

# 19. Lifecycle Unknown Outcome Reconciliation

On unknown lifecycle result:

1. enter reconciling;
2. GET authoritative Homework;
3. verify Topic target;
4. publish current Homework into FE-001 detail controller;
5. compare current status with action target.

Target statuses:

```text
activate -> active
close    -> closed
archive  -> archived
```

If exact target status:

```text
confirmed success
```

Use ordinary success feedback.

If current status differs:

```text
outcomeReview
```

Show:

```text
The lifecycle result could not be confirmed.
Review the current Homework state before taking another action.
```

No automatic replay.

If GET fails:

```text
outcomeReview
```

with:

```text
Check current Homework
```

An explicit Check performs GET only.

---

# 20. Lifecycle 404

Exact:

```text
404 resource_not_found
```

during mutation/reconciliation:

- mark FE-001 Homework detail `notFound`;
- invalidate Topic Homework list;
- lifecycle state becomes unavailable;
- safe message:
  `This Homework is no longer available.`;
- no scope/existence detail.

---

# 21. Activation Conflict UX

For definite `409`, refresh authoritative Homework when possible before presenting final state.

## `assessment_has_no_scoreable_points`

Show:

```text
This Homework needs at least one scoreable Question before activation.
Review the Questions and points.
```

Do not compute aggregate validity locally.

Provide working desktop action when current Homework remains editable:

```text
Manage Questions
```

using FE-003 route.

## `assessment_not_assigned`

Show:

```text
Review the Homework assignment.
The server could not confirm an eligible recipient set.
```

Provide working desktop action when metadata editing remains available:

```text
Edit Homework
```

Do not infer exactly which Student is invalid.

## `deadline_passed`

Show:

```text
The Homework deadline has already passed.
Update the deadline before activation.
```

Provide:

```text
Edit Homework
```

Do not compare device time to deadline to decide this result.

## `topic_not_editable`

Show:

```text
The Topic is not in a state that allows this Homework to be activated.
Review the current Topic.
```

Provide:

```text
Back to Topic
```

## `business_conflict`

Show:

```text
The Homework cannot be activated in the current server state.
Refresh and review its configuration.
```

Do not invent the hidden condition.

---

# 22. Close Conflict UX

## `task_not_active`

Refresh authoritative Homework.

Show:

```text
This Homework is not active.
Review its current state.
```

## `task_archived`

Show:

```text
This Homework is archived.
```

## `business_conflict`

Show:

```text
This Homework cannot be closed in the current server state.
Review the current Homework before trying again.
```

Do not claim a particular Student Attempt exists.

## `topic_not_editable`

Use safe Topic-state message.

Backend remains final authority.

---

# 23. Archive Conflict UX

## Active Homework

The UI normally does not expose Archive for active status.

If a stale/concurrent request receives:

```text
409 business_conflict
```

refresh authoritative Homework.

If refreshed status is active, show:

```text
Close the active Homework before archiving it.
```

If refreshed status is draft and current result-pair confirms this Homework is official, show:

```text
Replace the official Homework before archiving this draft.
```

Otherwise:

```text
This Homework cannot be archived in the current server state.
```

Do not parse backend human message to choose among these cases.

---

# 24. Result-Pair Domain Model

Create:

```text
TeacherTopicResultPair
```

Fields:

```text
id
topicId
homeworkAssessmentId
blitzAssessmentId
cohortSnapshottedAt
lockedAt
designatedAt
createdAt
updatedAt
```

Types:

- IDs canonical UUID strings;
- `blitzAssessmentId`: nullable;
- timestamps UTC DateTime;
- `cohortSnapshottedAt`: nullable;
- `lockedAt`: nullable.

No `institutionId`.

No designating user ID in frontend public domain because backend resource does not expose it.

---

# 25. Result-Pair Domain Invariants

Strict parsing must require:

- `id`, `topicId`, `homeworkAssessmentId` canonical UUID;
- nullable Blitz ID canonical UUID when non-null;
- when Blitz ID non-null:
  `blitzAssessmentId != homeworkAssessmentId`;
- all returned timestamps exact UTC `Z`;
- `lockedAt != null` requires:
  `cohortSnapshottedAt != null`;
- when both present:
  `lockedAt >= cohortSnapshottedAt`.

Do not require Blitz to be non-null.

Stage 6 normal state is:

```text
blitzAssessmentId = null
```

even when:

```text
lockedAt != null
```

Do not reject this valid staged state.

---

# 26. Result-Pair DTO

Create strict DTO under Teacher data layer.

GET success envelope accepts exactly:

```text
data
```

where `data` is:

```text
null
```

or exact pair object.

Pair object accepts exactly:

```text
id
topic_id
homework_assessment_id
blitz_assessment_id
cohort_snapshotted_at
locked_at
designated_at
created_at
updated_at
```

Unknown/missing keys -> invalid response.

Do not accept old two-ID-required assumptions.

---

# 27. Result-Pair Repository

Create a focused Topic-level interface:

```text
TeacherTopicResultPairRepository
```

Operations:

```text
Future<TeacherTopicResultPair?> fetchResultPair(String topicId)

Future<TeacherTopicResultPair> setOfficialHomework(
  String topicId,
  String homeworkId,
)
```

Do not merge this Topic-level relationship into `TeacherHomeworkRepository`.

The resource has different ownership/lifetime and may be watched by Topic and Homework screens.

---

# 28. Result-Pair Remote Data Source

Create:

```text
TeacherTopicResultPairRemoteDataSource
```

using configured Dio.

## GET

```text
GET /teacher/topics/{encodedTopicId}/result-pair
```

No body/query.

Require 200.

Strict parse nullable pair.

## PUT

```text
PUT /teacher/topics/{encodedTopicId}/result-pair
```

Body exactly:

```json
{
  "homework_assessment_id": "canonical-homework-uuid"
}
```

No Blitz field.

Require:

```text
200
Topic result pair updated successfully.
```

Strict parse full pair mutation envelope.

No automatic retry.

---

# 29. Result-Pair Definite Failure Classification

PUT exact definite errors:

```text
401 authentication_required

403 forbidden
403 password_change_required
403 user_inactive
403 institution_inactive

404 resource_not_found

409 topic_not_editable
409 official_task_requires_group_assignment
409 business_conflict
409 result_pair_locked

422 validation_failed

429 rate_limited
```

Do not classify arbitrary 409s.

GET uses ordinary read failure mapping.

---

# 30. Result-Pair Read Controller

Create autoDispose family:

```text
TeacherTopicResultPairController
TeacherTopicResultPairState
```

keyed by:

```text
topicId
```

Read states:

```text
initial
loading
data
refreshing
error
```

`data` may contain:

```text
pair = null
```

which means confirmed no official Homework designation yet.

This is different from loading/error.

Ownership:

```text
TeacherSessionKey
topicId
generation
```

Stale session/topic completions cannot publish.

---

# 31. Result-Pair Read Independence

Result-pair read must not become a prerequisite for ordinary Homework list/detail rendering.

If pair GET fails:

- Topic Homework list still renders;
- Homework detail still renders;
- lifecycle controls still render;
- official badge/action area shows:
  `Official Homework status unavailable.`;
- provide Retry.

Do not silently treat pair read error as `pair = null`.

That could incorrectly imply there is no current official Homework.

---

# 32. Result-Pair Accept/Refresh Boundary

The read controller must expose equivalent methods:

```text
refresh()
acceptAuthoritativePair(pair)
```

and may expose:

```text
acceptNoPair()
```

only for a confirmed GET null response.

A PUT success/reconciliation can publish authoritative pair through this controller.

Do not duplicate pair state inside Topic section and Homework detail.

---

# 33. Official Homework Mutation Controller

Create autoDispose family:

```text
TeacherOfficialHomeworkController
TeacherOfficialHomeworkState
```

keyed by:

```text
TeacherHomeworkRouteTarget(topicId, homeworkId)
```

Desktop mutation only.

It reads:

- current Homework detail;
- current result-pair read state.

Ownership:

```text
TeacherSessionKey
route target
operation generation
active requested homeworkId
```

No global singleton mutation state.

---

# 34. Official Candidate UX Eligibility

The frontend may show/hide mutation UI from confirmed current data but backend remains authority.

## Current Homework is already official

When:

```text
pair.homeworkAssessmentId == homework.id
```

show:

```text
Official Homework
```

No “Set official” button.

This remains true even if Homework is:

```text
closed
archived
```

or pair is locked.

## Current Homework not official

A designation/replacement button may be shown only when:

```text
homework.assignmentMode == group
homework.status == draft || active
pair read is confirmed
```

and, when a pair exists:

```text
pair.lockedAt == null
pair.blitzAssessmentId == null
```

If pair appears locked or has non-null future Blitz:

- do not show replacement action;
- show read-only:
  `Official Homework selection is locked.`

Backend may still reject an apparently eligible candidate because Attempt existence is not exposed to Flutter.

## Selected-student Homework

Show read-only informational text:

```text
Selected-student Homework is practice-only and cannot be the official Homework.
```

No designation button.

## Closed/archived non-official Homework

No designation button.

---

# 35. Official Draft Archive UX

When current Homework is:

```text
draft
```

and confirmed pair says it is the current official Homework:

- do not show the normal Archive action;
- show explanatory text:

```text
Replace the official Homework before archiving this draft.
```

This prevents a predictable server conflict.

Backend remains final authority if pair state races.

A closed official Homework still shows:

```text
Archive
```

because historical official archive is allowed.

If pair state is unavailable, do not assume the Homework is non-official. The Archive action may remain available based on lifecycle state; if backend rejects it, reconcile through the lifecycle conflict flow.

---

# 36. Official Designation Confirmation

## No current pair

Title:

```text
Set as official Homework?
```

Body:

```text
This whole-group Homework will be used as the Topic's official Homework for result comparison.
```

If candidate status is active, additionally:

```text
Its existing assigned-group snapshot will become the official Topic cohort.
```

Buttons:

```text
Cancel
Set official
```

## Replacing another official Homework

Title:

```text
Replace official Homework?
```

Body:

```text
This Topic already has an official Homework.
Replace it with this Homework?
```

If candidate active, include the cohort note above.

Do not show raw current official UUID.

Buttons:

```text
Cancel
Replace
```

No PUT before confirmation.

---

# 37. Official PUT Success

On exact success:

1. publish authoritative pair into `TeacherTopicResultPairController(topicId)`;
2. keep current Homework detail unchanged because PUT does not mutate Homework resource;
3. show:
   `Official Homework updated successfully.`;
4. remain on Homework detail.

Do not invalidate Homework list solely for designation because list fields are unchanged.

The Topic Homework section watches the shared pair controller and updates its official badge naturally.

---

# 38. Official PUT Unknown Outcome Reconciliation

On ambiguous PUT:

1. GET `/teacher/topics/{topicId}/result-pair`;
2. if GET returns pair with:
   `homeworkAssessmentId == requestedHomeworkId`
   -> confirmed success;
3. if GET returns null or a different Homework ID:
   -> unconfirmed current state;
4. publish confirmed GET result into pair read controller;
5. do not replay PUT automatically.

If GET fails:

```text
outcomeReview
```

with action:

```text
Check current official Homework
```

This performs GET only.

No second PUT until the outcome is reviewed.

---

# 39. Official Definite Failure UX

After a definite 409/404, refresh pair and Homework when safe.

## `official_task_requires_group_assignment`

Show:

```text
Only whole-group Homework can be the official Homework.
```

No local assignment change.

## `result_pair_locked`

Show:

```text
Official Homework selection is locked by the current server state.
```

Refresh pair.

Do not claim a specific Attempt exists.

## `business_conflict`

Show:

```text
This Homework cannot become the official Homework in the current server state.
Review the current Homework and Topic.
```

## `topic_not_editable`

Show:

```text
The Topic is no longer editable.
```

## `404 resource_not_found`

Refresh current Homework/list/pair boundaries as applicable.

Show:

```text
The requested Homework or Topic is no longer available in your current Teacher workspace.
```

No existence detail.

## `422 validation_failed`

Treat as safe designation form-level failure:

```text
The official Homework selection could not be validated.
Refresh and review the current state.
```

There is no editable field beyond candidate choice.

---

# 40. Official Status Presentation on Homework Detail

Add a read-only card/section:

```text
Official Homework
```

States:

## Loading

Small local progress.

## Error

```text
Official Homework status unavailable.
Retry
```

## No pair

For group draft/active desktop:

```text
No official Homework has been selected for this Topic.
```

For mobile: same read-only statement, no button.

## Pair exists, current Homework is official

Show badge/text:

```text
Official Homework
```

If:

```text
cohortSnapshottedAt == null
```

show:

```text
Official cohort will be fixed when this Homework is activated.
```

If non-null:

```text
Official cohort prepared.
```

If:

```text
lockedAt != null
```

also show:

```text
Official selection locked.
```

Do not display raw pair timestamps unless needed for existing history style.

Do not show `blitzAssessmentId`.

## Pair exists, another Homework is official

Show:

```text
Another Homework is currently official for this Topic.
```

Then eligible desktop replacement action when Section 34 permits.

---

# 41. Official Badge in Topic Homework Section

The FE-001 Topic Homework section observes the shared result-pair controller.

For each Homework row where:

```text
summary.id == pair.homeworkAssessmentId
```

show a clearly labeled badge/chip:

```text
Official
```

Do not infer official from:

- whole-group assignment;
- status;
- creation order;
- title.

If pair state loading/error:

- do not show a guessed badge;
- list remains usable;
- optional compact official-status loading/error indicator in the section header.

Mobile also shows the badge when pair read succeeds.

---

# 42. Pair Read Loading Strategy

When `TeacherHomeworkSection` first appears for a Topic:

- Homework list and result-pair GET may load independently/in parallel;
- one does not cancel the other;
- a pair failure does not turn the Homework list into an error;
- a Homework list failure does not erase confirmed pair state.

When `TeacherHomeworkDetailScreen` appears:

- it may watch the same topic-scoped pair provider;
- if Topic detail underneath already loaded it, reuse the provider state;
- do not issue redundant forced refresh solely because of nested navigation.

---

# 43. Homework Detail Mutation Coordination

Lifecycle and official PUT controls share one detail screen.

Do not allow simultaneous local mutation.

If lifecycle controller is busy:

- disable official Set/Replace;
- disable other lifecycle buttons.

If official controller is busy:

- disable lifecycle buttons;
- disable official action.

Question Builder/Edit metadata routes are separate authoring destinations, so no cross-route global mutation lock is required.

Do not introduce an app-wide mutation mutex.

---

# 44. Detail Refresh Coordination

Explicit Homework Detail Refresh remains a read operation.

Disable Refresh while:

```text
lifecycle mutation submitting/reconciling
official mutation submitting/reconciling
```

unless the controller is specifically in an outcome-review state where:

```text
Check current Homework
```

or:

```text
Check current official Homework
```

is the designated reconciliation action.

Do not let an unrelated refresh overwrite a pending operation classification.

---

# 45. Topic Lifecycle Integration — New Backend Conflict

S06-BE-005 adds:

```text
409 topic_has_open_assessments
```

to Topic close/archive.

FE-004 must extend the existing Stage 5 Topic lifecycle transport/controller UX.

## 45.1 Data-source classification

The existing Topic lifecycle remote-data-source definite-failure classifier must recognize:

```text
topic_has_open_assessments
```

for lifecycle operations.

Do not classify every 409 generically.

## 45.2 Controller behavior

When Topic close/archive returns this exact code:

- treat mutation as definite non-commit;
- refresh authoritative Topic if current session/target is valid;
- do not replay lifecycle POST;
- show:

```text
Close or archive the Topic's draft/active Homework before closing or archiving the Topic.
```

Do not list child IDs from the error.

## 45.3 Navigation affordance

The Teacher is already on Topic detail where Homework section exists.

No forced navigation is required.

Ensure the Homework section remains visible/usable so the Teacher can open and resolve child Homework.

Do not auto-close/archive Homework.

---

# 46. Topic Lifecycle Unknown Outcome Preservation

Do not weaken existing Stage 5 Topic lifecycle unknown-outcome behavior.

Adding `topic_has_open_assessments` must not:

- turn all 409s into definite;
- remove current Topic reconciliation;
- break session/target ownership;
- change same-target idempotency handling;
- regress Material mutation coordination.

Only add the exact Stage 6 code behavior.

---

# 47. Homework Lifecycle Success and Pair Cohort Refresh

Activation of an already designated draft Homework may update:

```text
topic_result_pairs.cohort_snapshotted_at
```

without returning the pair in the Homework lifecycle response.

Therefore after confirmed/reconciled activation success:

- if the topic-scoped pair controller exists or official-status UI is currently mounted, trigger one pair refresh;
- do not block lifecycle success UI on pair refresh;
- if pair refresh fails, Homework activation remains confirmed and official-status area shows its independent read error.

Close/archive do not require pair refresh for identity, but refreshing an already-mounted pair after any lifecycle semantic change is allowed if it is a single bounded read and preserves independent error state.

Prefer refresh on activation only.

---

# 48. List/Detail Reconciliation after Lifecycle

On confirmed or reconciled lifecycle success:

```text
detail controller -> accept authoritative Homework
topic Homework list -> invalidate/mark stale
```

Do not optimistically patch:

- list status;
- sort position;
- filter totals;
- pagination.

The next list GET is authoritative.

For lifecycle 404:

- detail notFound;
- list stale/invalidate.

---

# 49. List/Pair Reconciliation after Designation

Official designation does not change Homework list fields.

Do not invalidate the Homework list merely to display official status.

Instead:

```text
pair controller -> accept authoritative pair
```

The Homework section badge derives from pair state.

If pair reconciliation discovers a different official Homework after uncertain PUT, the list stays intact and badge moves according to the confirmed pair.

---

# 50. Lifecycle Feedback

Use route-local SnackBar/live-region feedback after confirmed success.

Exact user-facing success:

```text
Homework activated successfully.
Homework closed successfully.
Homework archived successfully.
```

These may match backend messages but are presentation constants; do not inspect arbitrary backend message text for control logic.

Do not show success before confirmed response/reconciliation.

---

# 51. Official Designation Feedback

Confirmed success:

```text
Official Homework updated successfully.
```

Unknown/review:

```text
The official Homework update result could not be confirmed.
Review the current official Homework before trying again.
```

Locked:

```text
Official Homework selection is locked by the current server state.
```

Do not show raw pair IDs.

---

# 52. Mobile Capability Boundary

Mobile Teacher may:

- read Topic Homework list;
- read Homework detail;
- see lifecycle status;
- see Official badge/status;
- navigate between read screens.

Mobile Teacher may not:

- Activate;
- Close;
- Archive;
- Set/Replace official;
- Create/Edit Homework;
- Manage Questions.

Do not derive capability from viewport width alone.

Use current `AppDeviceSurface` / Teacher destination authoring model.

---

# 53. Server Authority / No Client Reimplementation

Flutter must not independently decide:

- whether activation is valid;
- whether deadline has passed;
- whether selected recipients remain eligible;
- whether an active Homework has Student activity;
- whether Question editing is locked;
- whether pair is actually replaceable beyond confirmed exposed pair fields;
- whether hidden Attempts exist;
- whether Topic can close;
- whether a result is ready.

Local visibility is UX only.

Every mutation still handles backend rejection and reconciles authoritative state.

---

# 54. Result-Pair Staged Contract

The frontend must explicitly preserve the staged Stage 6 pair.

Valid:

```text
homeworkAssessmentId != null
blitzAssessmentId = null
```

Also valid in future/current forward-compatible data:

```text
lockedAt != null
blitzAssessmentId = null
```

Do not:

- show this as malformed;
- require pair “completion” before showing Official;
- hide Official because Blitz is null;
- create a client-side placeholder Blitz;
- send null Blitz back in Stage 6 PUT.

Stage 8 will extend this contract later.

---

# 55. Result-Pair Mutation No-Op

Backend same-target PUT is idempotent.

The frontend does not need to expose a “Set official” button for the already-official Homework.

If a stale UI somehow invokes same-target PUT:

- exact 200 success is accepted;
- pair state updated from response;
- no problem.

Do not compare `updatedAt` to decide success.

---

# 56. Official Replacement Lock UX

If confirmed pair has:

```text
lockedAt != null
```

and current Homework is not official:

- show no replacement button;
- show:
  `Official Homework selection is locked.`

If:

```text
blitzAssessmentId != null
```

in future-compatible data:

- also show no replacement button;
- do not expose Stage 8 mutation.

Backend may also return `result_pair_locked` even when `lockedAt` is null because hidden Attempt activity exists.

On that response:

- refresh pair;
- show locked server-state message;
- do not infer corruption.

---

# 57. Official Active Candidate UX

An active whole-group Homework can be selected as official if backend allows it.

Do not disable solely because status is active.

Confirmation includes:

```text
Its existing assigned-group snapshot will become the official Topic cohort.
```

Do not fetch current Group roster to predict that cohort.

The backend uses persisted active recipients.

---

# 58. Official Selected Candidate UX

A selected-student Homework must never expose designation action.

Show:

```text
Practice Homework
Selected-student Homework cannot be used as the official result Homework.
```

This is a direct stable business rule already represented in the API contract.

Do not auto-change assignment to group.

---

# 59. Lifecycle / Official Screen Layout

Extend the existing Homework detail presentation without turning it into a control dashboard.

Recommended order:

```text
Summary
Official Homework
Instructions
Assignment
Attempt policy
Questions
History
```

Desktop action row near Summary may contain:

```text
Edit
Manage Questions
Activate / Close / Archive
Set/Replace official
Refresh
```

but only actions valid for current confirmed UX state.

When too many actions wrap, use Material `Wrap` with clear labels.

Do not hide read-only sections while an operation is busy.

Use a LinearProgressIndicator or equivalent for current operation.

---

# 60. Official Status Accessibility

Official badge must include text:

```text
Official
```

not icon/color only.

Locked status includes explicit text.

Result-pair loading indicator has semantics label:

```text
Loading official Homework status
```

Retry control has visible label or tooltip.

Designation buttons have descriptive text:

```text
Set as official Homework
Replace official Homework
```

Confirmation dialog focuses safely.

---

# 61. Lifecycle Accessibility

Every lifecycle button has visible text and icon only as supplement.

Confirmation dialogs:

- descriptive title;
- focused default-safe action;
- Cancel available;
- destructive-ish Archive uses clear wording, not color only.

Busy state:

- affected buttons disabled;
- progress semantics:
  - `Activating Homework`
  - `Closing Homework`
  - `Archiving Homework`
  - `Updating official Homework`

No repeated SnackBar loop from state rebuilds; consume feedback once.

---

# 62. Async / Session / Target Safety

Lifecycle controller, result-pair read controller, and official mutation controller must reject stale completions.

Anchor to:

```text
TeacherSessionKey
topicId
homework route target where applicable
operation/read generation
active operation identity
```

A stale result must not:

- change another Homework detail;
- move Official badge in a newer session;
- show SnackBar on another route;
- navigate;
- disable controls in another target;
- overwrite a newer pair GET.

Do not rely only on Widget `mounted`.

---

# 63. Pair Read and Route Lifetime

Because Topic detail may remain mounted under pushed Homework detail:

- one topic-scoped pair provider may be watched by both;
- provider state may legitimately remain alive while either watcher exists;
- this is desired shared authoritative read state.

Mutation feedback must **not** live in the shared pair read state because an underlying Topic screen must not accidentally consume feedback created by the nested Homework screen.

Keep route-specific mutation feedback in `TeacherOfficialHomeworkController`.

---

# 64. Error UX Independence

Homework detail can be:

```text
data
```

while result-pair read is:

```text
error
```

Render both independently.

Do not turn the whole Homework detail into error because Official status failed.

Likewise, pair data may remain confirmed while a Homework list refresh fails.

Do not couple unrelated states.

---

# 65. Expected Files and Areas

Recommended domain:

```text
frontend/lib/features/teacher/domain/
  teacher_homework_lifecycle.dart
  teacher_topic_result_pair.dart
  teacher_topic_result_pair_repository.dart
```

Recommended data:

```text
frontend/lib/features/teacher/data/
  teacher_topic_result_pair_remote_data_source.dart
  teacher_topic_result_pair_repository_impl.dart
  dto/
    teacher_topic_result_pair_dto.dart
    teacher_topic_result_pair_operation_dto.dart
```

Extend:

```text
teacher_homework_remote_data_source.dart
teacher_homework_repository_impl.dart
teacher_homework_repository.dart
```

Recommended application:

```text
teacher_homework_lifecycle_controller.dart
teacher_homework_lifecycle_state.dart
teacher_topic_result_pair_controller.dart
teacher_topic_result_pair_state.dart
teacher_official_homework_controller.dart
teacher_official_homework_state.dart
```

Recommended presentation:

```text
teacher_homework_lifecycle_controls.dart
teacher_official_homework_section.dart
```

Modify narrowly:

```text
frontend/lib/features/teacher/presentation/teacher_homework_detail_screen.dart
frontend/lib/features/teacher/presentation/teacher_homework_section.dart
frontend/lib/features/teacher/data/teacher_topic_remote_data_source.dart
frontend/lib/features/teacher/application/teacher_topic_lifecycle_controller.dart
frontend/lib/core/network/api_error_codes.dart
frontend/test/features/teacher/teacher_test_support.dart
```

No new route file change is required unless delivered FE structure needs a mechanical import/helper adjustment.

Do not modify:

- backend;
- docs;
- pubspec/lock;
- platform files;
- Student/Parent/Institution Admin/Platform features;
- Question authoring rules;
- Homework metadata form rules.

---

# 66. Acceptance Criteria

- [ ] Desktop Homework detail exposes lifecycle actions according to confirmed draft/active/closed/archived state.
- [ ] Mobile never exposes lifecycle mutation controls.
- [ ] Activate/Close/Archive require explicit confirmation.
- [ ] Lifecycle data source sends exact no-body POST endpoints and requires exact full-Homework success envelopes/messages.
- [ ] Unknown lifecycle mutation is never auto-replayed.
- [ ] Unknown lifecycle result reconciles via authoritative Homework GET and target status.
- [ ] Confirmed lifecycle success updates detail and invalidates Topic Homework list.
- [ ] Activation success refreshes mounted official pair state without making pair refresh part of lifecycle success.
- [ ] `assessment_has_no_scoreable_points`, `assessment_not_assigned`, `deadline_passed`, `topic_not_editable`, lifecycle state codes, and `business_conflict` have safe specific UX.
- [ ] Flutter does not use device time to decide deadline validity.
- [ ] Result-pair domain accepts Stage 6 partial pair with `blitzAssessmentId = null`.
- [ ] Result-pair domain accepts `lockedAt != null` while Blitz remains null.
- [ ] GET result pair distinguishes confirmed `data:null` from loading/error.
- [ ] Pair read failure does not break Homework list/detail.
- [ ] Topic Homework section and Homework detail share one topic-scoped pair read state.
- [ ] Official badge appears only when pair `homeworkAssessmentId` matches that Homework.
- [ ] No official inference from assignment/status/title/order.
- [ ] Selected-student Homework never exposes official designation action.
- [ ] New/replacement designation UI requires confirmed whole-group draft/active candidate.
- [ ] Confirmed locked/non-null-Blitz pair exposes no replacement action.
- [ ] Active whole-group Homework can still be offered as candidate.
- [ ] Official PUT sends only `homework_assessment_id`.
- [ ] Official PUT unknown result reconciles through GET pair and candidate ID match; no auto replay.
- [ ] `result_pair_locked`, `official_task_requires_group_assignment`, `business_conflict`, and `topic_not_editable` have safe UX.
- [ ] Already-official Homework shows Official read-only state and no Set button at all lifecycle statuses.
- [ ] Official draft does not expose Archive while confirmed pair state is available.
- [ ] Official closed Homework may still expose Archive.
- [ ] No Blitz field/control appears.
- [ ] Stage 5 Topic lifecycle recognizes `topic_has_open_assessments` as an exact definite conflict.
- [ ] Topic conflict tells Teacher to resolve draft/active Homework and does not cascade lifecycle.
- [ ] Existing Topic lifecycle unknown/reconciliation/material coordination behavior remains intact.
- [ ] lifecycle and official mutations cannot start simultaneously from one Homework detail screen.
- [ ] stale pair/lifecycle/official completions cannot affect a newer session/target.
- [ ] no Student execution/scoring/Blitz/mobile authoring/backend/package/platform scope enters.
- [ ] focused tests pass.
- [ ] focused analyze passes.
- [ ] format check passes.
- [ ] `git diff --check` passes.
- [ ] focused diff self-review finds no blocking state/API/security/accessibility/scope issue.

---

# 67. Focused Tests and Verification

Run from:

```text
frontend/
```

Use FVM.

Do not run the full frontend suite/build/E2E. Those belong to Stage 6 Frontend Phase 2 / Integration.

## 67.1 Result-pair DTO / data

```bash
fvm flutter test \
  test/features/teacher/teacher_topic_result_pair_dto_test.dart \
  test/features/teacher/teacher_topic_result_pair_data_test.dart
```

Cover:

### DTO

- `data:null`;
- draft partial pair;
- cohort-snapshotted pair;
- locked pair with null Blitz;
- forward-compatible non-null Blitz;
- duplicate Homework/Blitz ID invalid;
- locked without cohort invalid;
- timestamp ordering;
- malformed UUID;
- missing/unknown keys;
- non-UTC timestamp;
- malformed envelope.

### Data source

- exact GET path/no query/body;
- exact PUT path/body;
- PUT has only `homework_assessment_id`;
- 200 exact message;
- strict success parse;
- documented definite 409 codes;
- 404/422/429;
- malformed success -> unknown;
- ambiguous Dio failure -> unknown;
- no automatic retry.

## 67.2 Result-pair read controller

```bash
fvm flutter test test/features/teacher/teacher_topic_result_pair_controller_test.dart
```

Cover:

- initial load;
- confirmed null;
- confirmed pair;
- refresh retains explicit state safely;
- error distinct from null;
- Retry;
- session change stale completion ignored;
- topic target change/disposal stale completion ignored;
- accept authoritative pair.

## 67.3 Official mutation controller

```bash
fvm flutter test test/features/teacher/teacher_official_homework_controller_test.dart
```

Cover:

- no-pair draft group candidate;
- no-pair active group candidate;
- replacement eligible;
- selected candidate locally not offered;
- closed/archived candidate locally not offered;
- pair locked locally not offered;
- future non-null Blitz locally not offered;
- success updates pair;
- same-target stale invocation 200 accepted;
- unknown PUT + GET matching -> success;
- unknown + GET different -> review;
- unknown + GET null -> review;
- GET failure -> Check current;
- result_pair_locked;
- official_task_requires_group_assignment;
- business_conflict;
- topic_not_editable;
- 404;
- stale session/route completion ignored.

## 67.4 Homework lifecycle data/controller

```bash
fvm flutter test \
  test/features/teacher/teacher_homework_lifecycle_data_test.dart \
  test/features/teacher/teacher_homework_lifecycle_controller_test.dart
```

Cover:

### Data

- activate exact POST/no body/status/message;
- close;
- archive;
- documented exact 409 classification;
- malformed success -> unknown;
- ambiguous network -> unknown.

### Controller

- draft actions;
- active actions;
- closed actions;
- archived none;
- confirmed activate/close/archive;
- unknown + GET target status -> success;
- unknown + GET different -> review;
- GET failure -> Check current;
- 404;
- scoreable-points conflict;
- assignment conflict;
- deadline conflict;
- topic conflict;
- close `task_not_active`;
- closed/archived conflicts;
- generic business conflict;
- official draft archive UX when pair known;
- activation triggers pair refresh independently;
- list invalidation/detail acceptance;
- duplicate/busy suppression;
- stale session/target ignored.

## 67.5 Homework detail / Topic section widgets

```bash
fvm flutter test \
  test/features/teacher/teacher_homework_detail_screen_test.dart \
  test/features/teacher/teacher_homework_section_test.dart
```

Cover:

- lifecycle buttons desktop;
- no lifecycle mobile;
- confirmation dialogs;
- busy disables other mutations;
- lifecycle feedback;
- activation conflict actions;
- pair loading;
- pair error/retry independent from detail/list;
- no pair;
- current Official badge;
- cohort pending/prepared text;
- locked text;
- another official text;
- selected practice-only text;
- Set official;
- Replace official;
- active-candidate confirmation cohort note;
- locked pair no replacement;
- non-null Blitz fixture no replacement;
- official draft no Archive;
- official closed Archive allowed;
- official badge on list desktop/mobile;
- no raw pair/Student UUID;
- no Blitz UI.

## 67.6 Topic lifecycle Stage 6 integration

```bash
fvm flutter test \
  test/features/teacher/teacher_topic_operation_test.dart \
  test/features/teacher/teacher_topic_controller_test.dart \
  test/features/teacher/teacher_topic_routing_screen_test.dart
```

Required new regression:

- exact `409 topic_has_open_assessments` is definite;
- Topic lifecycle controller refreshes/reviews current state;
- feedback instructs resolving open Homework;
- no auto replay;
- other unknown 409 remains outcome-unknown according to existing classifier;
- current Topic lifecycle/material coordination remains unchanged.

If the delivered Stage 5 test filenames differ, use their actual focused equivalents.

## 67.7 Direct FE-002/003 regressions

Because Homework detail/repository/error codes are extended:

```bash
fvm flutter test \
  test/features/teacher/teacher_homework_edit_controller_test.dart \
  test/features/teacher/teacher_question_builder_controller_test.dart
```

Use actual delivered focused equivalents if filenames differ.

Do not run the whole Teacher suite.

## 67.8 Focused analyze

```bash
fvm flutter analyze --no-pub lib/features/teacher
fvm flutter analyze --no-pub lib/core/network/api_error_codes.dart
```

If the pinned Flutter CLI does not support exact file target in the second command, use the narrowest supported equivalent and report it.

## 67.9 Format

```bash
fvm dart format --output=none --set-exit-if-changed \
  lib/features/teacher \
  lib/core/network/api_error_codes.dart \
  test/features/teacher
```

## 67.10 Always

```bash
git diff --check
```

Then focused diff self-review:

- lifecycle/official logic is in controllers/repositories, not widgets;
- pair error is not treated as “no pair”;
- no official inference from Homework fields;
- no Blitz required for pair validity;
- no automatic mutation replay;
- no device-time authority;
- no lifecycle cascade;
- no mobile mutation capability;
- no second Homework cache/repository;
- Topic lifecycle classifier adds only exact new code;
- stale async ownership preserved;
- no package/platform/backend/docs changes;
- no tests weakened;
- no debug/secrets/temp/generated artifacts;
- no unrelated formatting churn.

---

# 68. Project Owner Manual Check

```text
Not required at task level.
```

Real-stack lifecycle/official-designation UX belongs to `S06-INT-001`.

---

# 69. Delivery

Follow root `AGENTS.md` and `tasks/README.md`.

Delivery execution:

```text
Project Owner
```

Suggested:

```text
Branch: feat/s06-fe-004-homework-lifecycle-official
Commit: feat(stage6): add homework lifecycle and official ux
PR base: main
```

Codex must not:

- commit;
- push;
- open/merge PR;
- modify this task file;
- update Stage/task bookkeeping.

Codex stops after implementation, focused verification, `git diff --check`, and focused scope/diff self-review.

Task acceptance occurs only after approved delivery is present on `origin/main`, local `main == origin/main`, ahead/behind `0/0`, and worktree clean.

After `S06-FE-004` is accepted/delivered, the next permitted gate is:

```text
Stage 6 Frontend Phase 2 Read-Only Review
```

Do not start Stage 6 integration before Frontend Phase 2 passes.

---

# 70. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to rediscover requirements.

| Source/reference | Decision already encoded above |
|---|---|
| Approved Stage 6 decomposition | FE-004 owns Homework lifecycle + official designation UX |
| S06-BE-005 | activate/close/archive, activation conflicts, Topic open-assessment guard |
| S06-BE-006 | staged result-pair GET/PUT, whole-group official rule, replacement/lock behavior |
| S06-FE-001 | Homework list/detail read surfaces and typed domain |
| S06-FE-002 | metadata authoring, mutation uncertainty, desktop-only authoring |
| S06-FE-003 | Question Builder and server-lock conventions |
| Existing Topic lifecycle frontend | structured 409 handling, authoritative reconciliation, route/session safety |
| Approved Stage 6 UX decision | result-pair read independent from Homework read; official badge on desktop/mobile, mutation desktop-only |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |

---

# 71. Codex Final Report

Return:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

`DELIVERY BLOCKED` is not applicable because delivery is Project Owner-owned.

Report:

1. **Status**.
2. **Implementation** — concise result.
3. **Changed files** — file → purpose.
4. **Acceptance criteria** — concise PASS/FAIL evidence.
5. **Focused verification** — exact commands/results.
6. **Lifecycle/reconciliation** — evidence.
7. **Result-pair staged contract** — evidence including null Blitz acceptance.
8. **Official eligibility/lock UX** — evidence.
9. **Topic lifecycle integration** — evidence for `topic_has_open_assessments`.
10. **Session/target stale-async** — evidence.
11. **Accessibility/mobile boundary** — evidence.
12. **Scope/diff** — non-goals + `git diff --check`.
13. **Delivery handoff** — Project Owner + current Git state.
14. **Deviations/blockers** — exact facts.

Do not output task `Accepted`.

Do not repeat this contract or paste large successful logs.

If final backend/frontend dependencies materially conflict with this contract or a required lifecycle/result-pair/security/state decision is unresolved, return `BLOCKED` rather than deciding independently.
