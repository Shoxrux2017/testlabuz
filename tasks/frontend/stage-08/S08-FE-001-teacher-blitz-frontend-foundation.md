# Codex Implementation Contract: S08-FE-001 — Teacher Blitz Frontend Foundation

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-FE-001` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter Teacher Blitz typed client/read foundation + Topic section + read-only detail routing` |
| Depends on | `S08-BE-001…010 Accepted / Delivered` **and** `S08-BE-PHASE-2 = PASS` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Runtime implementation baseline | Re-check/freeze current `origin/main` (at or after `1c56cde`) immediately before implementation starts |
| Backend contract authority at execution | Delivered Stage 8 backend on audited `main` after Backend Phase 2 PASS |
| Current readiness gate | `Approved — revalidated 2026-09-24 on main 1c56cde after S08-BE-PHASE-2 run #2 PASS (STAGE_08_TASK_INDEX §17); corrections marked "revalidation 2026-09-24"` |
| Flutter toolchain | Use the repository's current FVM-pinned Flutter version at implementation time |
| Implementation Readiness Gate | `PASS` — Backend Phase 2 PASS recorded; current readiness Approved |
| Verification | `Implementer (Claude, from 2026-09-23) — focused frontend verification only` |
| Delivery execution | `Implementer opens the branch/commits/PR; Project Owner reviews and merges` |
| Frontend block checkpoint | `S08-FE-PHASE-2` after `S08-FE-001…006` are `Accepted / Delivered` |
| Blocks | `S08-FE-002` |

Start only when:

```text
S08-BE-001…010 = Accepted / Delivered
S08-BE-PHASE-2 = PASS
this contract remains currently Approved by ChatGPT
ChatGPT has re-checked current origin/main
Git preflight is safe
```

ChatGPT verifies the delivered dependencies, Backend Phase 2 PASS and current
readiness before this contract is handed off.

Codex must not read the Stage index or Stage history to rediscover authorization.
Receiving FE-001 for implementation means ChatGPT already confirmed its current
readiness.

If Backend Phase 2 changes the final public Blitz API in a way that materially
conflicts with this contract, stop:

```text
BLOCKED
```

and report the exact mismatch.

This file is the complete task-specific implementation contract.

Do **not** create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this implementation contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. current delivered Stage 8 backend route/resource implementation directly required to confirm the already-defined API below;
5. directly relevant current Teacher frontend source/tests;
6. current router/session/device/error infrastructure required by this task.

Do **not** read:

- product docs;
- roadmap files;
- previous Stage 8 task contracts;
- Stage history;
- Backend Phase 2 review;
- closure reviews;
- unrelated frontend modules

to decide product or UX behavior.

This contract already resolves:

- Blitz read domain;
- strict DTO parsing;
- list/detail data-source and repository boundaries;
- Topic-scoped list query;
- Teacher Topic Blitz section;
- read-only Blitz detail route;
- desktop/mobile read behavior;
- all-nine Teacher Question readback;
- official-Blitz read indicator;
- timing/lifecycle display;
- session/target/stale-completion safety;
- route parsing/direct-entry behavior;
- loading/empty/error/not-found/stale states;
- scope exclusions;
- focused verification.

Do not add create/edit/schedule/activate/close/archive/exception/monitoring controls
merely because those backend endpoints exist.

Those are owned by later frontend tasks.

---

# 3. Goal

Establish the Stage 8 Teacher Blitz frontend foundation on top of the final
Backend Phase 2 API.

An authenticated Teacher on supported desktop or mobile read surfaces must be
able to:

1. open an authorized Topic;
2. see the Topic's Blitz list;
3. filter that list by Blitz status;
4. page and refresh independently from Topic detail;
5. identify the currently designated official Blitz only when confirmed by the
   existing result-pair API state;
6. open one Blitz using a canonical nested route;
7. inspect authoritative Blitz metadata, assignment mode, duration, schedule,
   timer snapshot/history, attempt policy, lifecycle timestamps and all nine
   Teacher Question configurations;
8. refresh the detail safely without stale async completions overwriting a newer
   session/route target.

No Blitz mutation is exposed yet.

---

# 4. Scope

## 4.1 Included

Implement under the existing Teacher feature-first area:

```text
frontend/lib/features/teacher/
  domain/
  data/
  application/
  presentation/
```

Implement:

- typed Teacher Blitz enums/domain models;
- typed Blitz list query/list/pagination domain;
- strict Blitz summary/detail DTO parsing;
- strict attempt-policy parsing;
- strict lifecycle/timer cross-field validation;
- reuse of existing all-nine `TeacherQuestion` domain/DTO/read presentation;
- Blitz repository contract/implementation;
- configured Dio remote data source;
- Topic-scoped Blitz list Riverpod state/controller;
- route-target-scoped Blitz detail Riverpod state/controller;
- independent session/target/generation stale-completion safety;
- read-only `TeacherBlitzSection` on Teacher Topic detail;
- canonical nested Teacher Blitz detail route;
- responsive read-only Blitz detail screen;
- official-Blitz read-only chip driven only by confirmed Topic result-pair state;
- Blitz presentation formatters;
- focused DTO/data-source/repository/controller/router/widget tests;
- directly affected Topic/Homework/router regression tests.

## 4.2 Explicit non-goals

Do **not** implement:

- Blitz create form;
- Blitz edit form;
- Student picker UI;
- duration editor;
- schedule picker/editor;
- Question builder/editors;
- Question create/update/delete/reorder controls;
- Teacher Activate button;
- Teacher Close button;
- Teacher Archive button;
- official Blitz designation mutation;
- result-pair PUT mutation;
- attempt-exception grant UI;
- monitoring screen;
- live monitoring polling;
- Student Blitz list/detail;
- Student Start/Resume;
- Student countdown;
- Student answer/file UI;
- Student Submit;
- checking/scoring UI;
- Topic result UI;
- optimistic mutations;
- offline persistence;
- URL-backed Blitz list filter state;
- new Flutter package;
- new router;
- new state-management framework;
- second Dio client;
- code generation framework;
- backend/API changes;
- platform file changes;
- full frontend suite;
- full project analyze;
- full desktop/mobile build;
- E2E.

Do not render disabled/dead controls for later features.

If an action is not implemented in this task, do not show its button.

---

# 5. Existing Frontend Architecture to Preserve

Reuse the existing flow:

```text
Presentation
  -> Riverpod Controller / State
    -> Repository contract
      -> Repository implementation
        -> Remote data source
          -> configured Dio
```

Reuse current:

```text
GoRouter
AppRoutePaths / AppRouteNames
_TeacherDestinationGate
AuthSessionController
TeacherSessionSnapshot / TeacherSessionKey
AppDeviceSurface
dioProvider
DioFailureMapper
ApiFailure
ApiRequestException
ApiErrorCodes
Teacher DTO parsing helpers
TeacherListEnvelopeDto / pagination infrastructure
TeacherQuestion / TeacherQuestionDto
TeacherQuestionReadView
TeacherTopicResultPairController
Teacher Topic detail route/state conventions
```

Do not create:

- parallel Teacher session ownership;
- parallel UUID helpers when current Teacher parsing helpers are applicable;
- second pagination envelope;
- second Question read model;
- second API error mapper.

---

# 6. Backend Read API Dependency

The final delivered backend is authoritative.

Configured Dio base URL already includes:

```text
/api/v1
```

Use only the following Stage 8 reads in this task.

## 6.1 Teacher Blitz list

```text
GET /teacher/blitz
```

Query keys supported by backend:

```text
topic_id
group_id
status
page
per_page
```

This UI foundation is Topic-scoped.

It must send:

```text
topic_id = current Topic ID
```

FE-001 does not send `group_id` (revalidation 2026-09-24: the delivered backend accepts it, but
the Topic filter alone is authoritative and keeps the request deterministic).

It must **not** send:

```text
search
assignment_mode
sort
direction
```

because they are not part of the approved backend Blitz-list contract.

Success:

```text
200
```

## 6.2 Teacher Blitz detail

```text
GET /teacher/blitz/{blitz}
```

Success:

```text
200
```

## 6.3 Existing result-pair read

Reuse the already-delivered existing Topic result-pair read state/controller only
for read-only official-Blitz identification.

Do not issue result-pair PUT in this task.

## 6.4 No mutations

Do not call:

```text
POST /teacher/topics/{topic}/blitz
PATCH /teacher/blitz/{blitz}
POST /teacher/blitz/{blitz}/schedule
POST /teacher/blitz/{blitz}/activate
POST /teacher/blitz/{blitz}/close
POST /teacher/blitz/{blitz}/archive
POST /teacher/blitz/{blitz}/students/{student}/attempt-exception
GET  /teacher/blitz/{blitz}/monitoring
```

in S08-FE-001.

Do not call shared Question mutation endpoints.

---

# 7. Domain: Blitz Status

Create exact machine enum:

```text
TeacherBlitzStatus
```

Values:

```text
draft
scheduled
active
closed
archived
```

Example mapping:

```text
draft     -> 'draft'
scheduled -> 'scheduled'
active    -> 'active'
closed    -> 'closed'
archived  -> 'archived'
```

Unsupported machine value:

```text
FormatException
```

Do not use UI labels as serialization authority.

---

# 8. Domain: Blitz Assignment Mode

Create:

```text
TeacherBlitzAssignmentMode
```

Exact values:

```text
group
selectedStudents -> API selected_students
```

Do not reuse `TeacherHomeworkAssignmentMode` as the Blitz domain type.

The machine values happen to match, but Homework and Blitz remain separate
feature-domain types.

This avoids coupling future subtype-specific behavior to a Homework-named enum.

---

# 9. Domain: Blitz Timer Start Mode

Create:

```text
TeacherBlitzTimerStartMode
```

Exact values:

```text
synchronized
individual
```

Preactivation resource state may have:

```text
timerStartModeSnapshot = null
```

After activation it must be non-null.

Do not read current Institution setting to reconstruct an active Blitz mode.

The backend resource snapshot is authoritative.

---

# 10. Blitz Summary Domain

Create a read model equivalent to:

```text
TeacherBlitzSummary
```

Required fields:

```text
id
topicId
groupId
title
assignmentMode
totalPossiblePoints
questionCount
durationSeconds
scheduledAt
institutionTimezone
status
createdAt
updatedAt
```

Types:

- IDs: canonical UUID String;
- title: non-blank String;
- `totalPossiblePoints`: finite non-negative double;
- `questionCount`: non-negative int;
- `durationSeconds`: positive int;
- `scheduledAt`: nullable UTC DateTime;
- `institutionTimezone`: non-blank String;
- timestamps: UTC DateTime.

The frontend displays server values.

Do not recalculate authoritative total points from summary data.

---

# 11. Blitz Attempt Policy Domain

Create:

```text
TeacherBlitzAttemptPolicy
```

Exact canonical values:

```text
normalAttempts = 1
maxAdditionalExceptionAttempts = 1
```

Expose constants analogous to:

```text
requiredNormalAttempts = 1
requiredMaxAdditionalExceptionAttempts = 1
```

The DTO must reject a success payload whose policy differs.

Do not locally invent configurable attempt counts.

---

# 12. Full Blitz Domain

Create a full read model equivalent to:

```text
TeacherBlitz
```

Required fields (revalidation 2026-09-24: `description` is a nullable String; `title` and
`studentInstructions` are non-blank Strings, as in the Teacher Homework DTO):

```text
id
topicId
groupId
title
description
studentInstructions
assignmentMode
studentIds
totalPossiblePoints
durationSeconds
scheduledAt
institutionTimezone
status
timerStartModeSnapshot
attemptPolicy
activatedAt
synchronizedEndsAt
closedAt
archivedAt
createdAt
updatedAt
questions
```

`questions` uses existing:

```text
List<TeacherQuestion>
```

Do not create:

```text
TeacherBlitzQuestion
```

or duplicate all-nine Question domain types.

---

# 13. Recipient Cross-Field Invariant

`studentIds` is authoritative read metadata from backend.

Validate:

## Group

```text
assignmentMode = group
studentIds = []
```

## Selected students

```text
assignmentMode = selected_students
studentIds is non-empty
all IDs canonical UUID
case-insensitive unique
```

Contradiction:

```text
FormatException
```

Do not fetch Student names in this task.

Display selected Student count only.

---

# 14. Duration Invariant

Validate:

```text
durationSeconds >= 1
```

Reject:

- zero;
- negative;
- non-integer;
- value outside Dart int representation.

Do not add a client-side 5–10 minute constraint.

Backend intentionally allows any positive configured whole-Blitz duration inside
the accepted server integer range.

---

# 15. Summary DTO Exact Keys

Create strict summary DTO.

Expected exact summary keys:

```text
id
topic_id
group_id
title
assignment_mode
total_possible_points
question_count
duration_seconds
scheduled_at
institution_timezone
status
created_at
updated_at
```

Use the current strict Teacher DTO helper:

```text
readExactTeacherMap
```

Unknown/missing key:

```text
FormatException
```

For a Topic-scoped list, every row must satisfy:

```text
row.topic_id == requested Topic ID
```

case-insensitively.

A malformed successful list payload becomes:

```text
ApiFailureKind.invalidResponse
```

through the existing failure boundary.

---

# 16. Full Blitz DTO Exact Keys

`scheduled_at` is `timestamptz(6)`: the backend serializes it with a `.uuuuuu` fraction when
the stored instant has a non-zero fraction (`InstitutionBlitzScheduledAt`), for example
`2026-09-18T04:00:00.123456Z`. The existing UTC parser accepts this. Every other timestamp is
whole-second `YYYY-MM-DDTHH:MM:SSZ`.

Expected exact full resource keys:

```text
id
topic_id
group_id
title
description
student_instructions
assignment_mode
student_ids
total_possible_points
duration_seconds
scheduled_at
institution_timezone
status
timer_start_mode_snapshot
attempt_policy
activated_at
synchronized_ends_at
closed_at
archived_at
created_at
updated_at
questions
```

No extra key is silently ignored.

Use existing strict Teacher parse helpers for:

```text
UUID
String
nullable String
number
int
UTC timestamp
nullable UTC timestamp
exact maps
```

---

# 17. Attempt Policy DTO

Expected exact keys:

```text
normal_attempts
max_additional_exception_attempts
```

Require:

```text
normal_attempts = 1
max_additional_exception_attempts = 1
```

Any other success payload:

```text
FormatException
```

Do not silently adapt UI to a backend contract violation.

---

# 18. Question Parsing

Reuse:

```text
TeacherQuestionDto
```

for every item in:

```text
questions
```

Validate collection-level invariants:

- response value is a list;
- Question IDs are case-insensitively unique;
- positions are contiguous:
  ```text
  1..N
  ```
- returned order matches canonical position order.

A small shared Question-list parser may be extracted from the current Homework
DTO if doing so avoids real duplicate parsing logic.

If extracted:

- update Homework DTO to use the same helper;
- preserve exact Homework behavior;
- add directly affected regression tests.

Do not duplicate the full all-nine Question parser.

---

# 19. Blitz Lifecycle DTO Validation

Strict success parsing must validate lifecycle/timer cross-field consistency.

---

# 20. Draft State

For:

```text
status = draft
```

require:

```text
timerStartModeSnapshot = null
activatedAt = null
synchronizedEndsAt = null
closedAt = null
archivedAt = null
```

`scheduledAt` may be:

```text
null
or non-null
```

because backend Create may preserve optional schedule metadata while status is
still Draft.

---

# 21. Scheduled State

For:

```text
status = scheduled
```

require:

```text
scheduledAt != null
timerStartModeSnapshot = null
activatedAt = null
synchronizedEndsAt = null
closedAt = null
archivedAt = null
```

---

# 22. Active State

For:

```text
status = active
```

require:

```text
activatedAt != null
timerStartModeSnapshot != null
closedAt = null
archivedAt = null
```

Then:

## Synchronized

```text
synchronizedEndsAt != null
synchronizedEndsAt
=
activatedAt + durationSeconds
```

## Individual

```text
synchronizedEndsAt = null
```

Do not derive or replace the backend snapshot from current Institution settings.

---

# 23. Closed State

For:

```text
status = closed
```

require:

```text
activatedAt != null
timerStartModeSnapshot != null
closedAt != null
archivedAt = null
```

Require:

```text
closedAt >= activatedAt
```

Timer shape remains:

## Synchronized

```text
synchronizedEndsAt
=
activatedAt + durationSeconds
```

## Individual

```text
synchronizedEndsAt = null
```

Do not require close to occur before/after synchronized end.

Both are valid because Teacher Close may happen at either point.

---

# 24. Archived State

Two historical shapes are valid.

## Preactivation archive

```text
status = archived
activatedAt = null
timerStartModeSnapshot = null
synchronizedEndsAt = null
closedAt = null
archivedAt != null
scheduledAt = null or non-null
```

## Post-close archive

```text
status = archived
activatedAt != null
timerStartModeSnapshot != null
closedAt != null
archivedAt != null
```

Timer shape still follows synchronized/individual rules.

Do not accept:

```text
active -> archived without closedAt
```

as a canonical successful resource.

---

# 25. Lifecycle Chronology

When timestamps are present validate obvious ordering:

```text
closedAt >= activatedAt
archivedAt >= closedAt     // post-close archive
```

For preactivation archive:

```text
archivedAt != null
```

No client-side assumption is made about whether `scheduledAt` is before
activation.

Scheduling is preparation metadata and Teacher activation may occur before or
after the planned time.

---

# 26. Blitz List Query Domain

Create:

```text
TeacherBlitzListQuery
```

UI-owned mutable fields:

```text
status
page
perPage
```

Topic ID is supplied separately by the Topic-scoped repository/controller.

Defaults:

```text
status = null
page = 1
perPage = 20
```

Constraints:

```text
page >= 1
1 <= perPage <= 100
```

Query serialization:

```text
topic_id = route Topic ID
status = optional exact machine value
page
per_page
```

Do not emit null query keys.

Do not emit unsupported list filters.

---

# 27. Blitz List Domain / Pagination

Create:

```text
TeacherBlitzList
```

with:

```text
items: List<TeacherBlitzSummary>
pagination: existing TeacherListPagination domain type
```

Reuse current Teacher list-envelope/pagination infrastructure.

Do not create another pagination model.

---

# 28. Repository Contract

Create:

```text
TeacherBlitzRepository
```

with exactly the read operations required by FE-001:

```dart
Future<TeacherBlitzList> fetchBlitzList(
  String topicId,
  TeacherBlitzListQuery query,
);

Future<TeacherBlitz> fetchBlitz(String blitzId);
```

Do not place mutation methods in this repository yet.

Later tasks extend the same repository deliberately.

Do not add speculative:

```text
createBlitz
updateBlitz
scheduleBlitz
activateBlitz
closeBlitz
archiveBlitz
grantException
monitor
```

methods in FE-001.

---

# 29. Remote Data Source

Create:

```text
TeacherBlitzRemoteDataSource
```

provided from:

```text
dioProvider
```

and the existing:

```text
DioFailureMapper
```

No direct Dio use in Widgets/controllers.

---

# 30. List Data Source Request

Validate Topic ID is canonical before request.

Send:

```text
GET /teacher/blitz
```

with:

```text
topic_id
status?
page
per_page
```

`followRedirects: false` consistent with current Teacher data-source patterns.

Require success status:

```text
200
```

Parse using strict:

```text
TeacherBlitzListDto
```

Any malformed 2xx success payload becomes:

```text
ApiFailureKind.invalidResponse
```

Do not silently return an empty list.

---

# 31. Detail Data Source Request

Validate Blitz ID is canonical before request.

Send:

```text
GET /teacher/blitz/{blitz}
```

Require:

```text
200
```

Parse the exact `{"data": {...}}` envelope (as `TeacherHomeworkDetailDto`) into:

```text
TeacherBlitzDetailDto
```

Malformed 2xx success:

```text
invalidResponse
```

Transport/server failures use existing `DioFailureMapper`.

---

# 32. Repository Implementation / Provider

Create:

```text
TeacherBlitzRepositoryImpl
teacherBlitzRepositoryProvider
```

Responsibilities only:

- call remote data source;
- convert DTO -> domain.

No state caching inside repository.

No Riverpod session logic inside repository.

No presentation formatting inside repository.

---

# 33. List Controller

Create an auto-dispose family controller equivalent to:

```text
teacherBlitzListControllerProvider(topicId)
```

State equivalent to:

```text
TeacherBlitzListState
```

Required state concepts:

```text
initial
loading
refreshing
data
error
query
result
failure
isStale
```

No search draft because the backend Blitz list has no search query.

---

# 34. List Controller Session Ownership

Use the existing Teacher session pattern:

```text
TeacherSessionSnapshot.fromSession(
  auth session,
  device surface,
).eligibleKey
```

Controller must:

- reject invalid Topic ID;
- clear ownership if Teacher session becomes ineligible;
- own one active TeacherSessionKey;
- own generation counter;
- suppress duplicate identical in-flight loads;
- reject stale completion after:
  - logout;
  - user/session change;
  - device-surface identity change;
  - provider disposal;
  - newer load;
- never publish old list data into a newer Teacher session.

---

# 35. List Controller Operations

Expose only:

```text
setStatus(...)
previousPage()
nextPage()
refresh()
retry()
```

`setStatus` resets page to:

```text
1
```

Do not add search.

Do not add assignment-mode filter.

Do not add group selector inside Topic detail.

Do not add mutation operations.

---

# 36. List Refresh Behavior

Initial load:

```text
loading
```

Refresh with confirmed existing list:

```text
refreshing
retain current result
```

Refresh failure with retained result:

```text
error
result retained
isStale = true
```

Initial failure without prior result:

```text
error
result = null
```

Do not present stale retained data as fully current.

---

# 37. List Session Failure Handling

For existing session failure machine codes:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

follow the current Teacher controller pattern.

Do not keep stale Blitz data across an invalidated Teacher session.

Bootstrap/reconciliation behavior must remain consistent with existing Teacher
controllers.

---

# 38. Detail Route Target

Create immutable:

```text
TeacherBlitzRouteTarget
```

with:

```text
topicId
blitzId
```

Require canonical UUID values.

Normalize identity consistently with existing Homework route target behavior.

Implement equality/hash suitable for Riverpod family keys and Widget ValueKeys.

Do not include display labels in route identity.

---

# 39. Detail Controller

Create:

```text
teacherBlitzDetailControllerProvider(
  TeacherBlitzRouteTarget target
)
```

with state:

```text
initial
loading
refreshing
data
notFound
error
```

State fields:

```text
blitz
failure
isStale
```

Follow current Homework detail controller ownership pattern.

---

# 40. Detail Target Integrity

Backend detail endpoint is keyed only by:

```text
Blitz ID
```

but Flutter route is nested under:

```text
Topic ID
```

After fetching a successful Blitz, require:

```text
blitz.topicId == target.topicId
```

case-insensitively.

Mismatch:

```text
local notFound state
```

Do not display a Blitz under the wrong Topic URL.

Do not rewrite the route to the server's Topic automatically.

---

# 41. Detail 404 Mapping

Exact backend:

```text
404 resource_not_found
```

maps to:

```text
TeacherBlitzDetailStatus.notFound
```

Other failures map to:

```text
error
```

with typed `ApiFailure`.

Do not branch on human message strings.

---

# 42. Detail Refresh / Stale Behavior

Initial detail load:

```text
loading
```

Refresh with existing Blitz:

```text
refreshing
retain current Blitz
```

Refresh failure:

```text
error
retain Blitz
isStale = true
```

Retry can re-request.

A stale completion from another target/session must never overwrite current
state.

---

# 43. App Route Names / Paths

Add:

```text
AppRouteNames.teacherBlitzDetail
```

Add route segment:

```text
teacherBlitzSegment = 'blitz'
teacherBlitzIdParameter = 'blitzId'
```

Canonical nested path:

```text
/teacher/topics/:topicId/blitz/:blitzId
```

Add:

```text
AppRoutePaths.teacherBlitzDetail
```

---

# 44. Route Helper

Add:

```text
teacherBlitzDetailLocation(topicId, blitzId)
```

Requirements:

- both IDs must be canonical UUIDs;
- reject invalid/untrimmed malformed values with `ArgumentError`;
- URI encode each segment;
- return canonical nested path.

No query parameters.

No fragments.

---

# 45. Route Recognition

Add exact helper:

```text
isTeacherBlitzDetailPath(path)
```

It returns true only for:

```text
/teacher/topics/<uuid>/blitz/<uuid>
```

No trailing extra segment.

No `new`.

No edit/monitoring segment in FE-001.

Update:

```text
isTeacherApprovedLocation
teacherTopicIdFromPath
```

and any relevant Teacher route parsing helper so the new detail route is a
first-class approved Teacher location.

Add a Blitz-ID extraction helper only if existing router/test conventions need
one.

---

# 46. GoRouter Registration

Register `teacherBlitzDetail` nested beneath:

```text
teacherTopicDetail
```

parallel to Homework detail.

Builder:

- resolves `topicId`;
- resolves `blitzId`;
- creates `TeacherBlitzRouteTarget`;
- passes canonical target to `TeacherBlitzDetailScreen`;
- uses `_buildTeacherDestination` with:

```text
authoring = false
```

`authoring = false` alone does not make the route reachable (revalidation 2026-09-24). The
implementation must also add the Blitz detail path predicate to:

- `AppRoutePaths.isTeacherApprovedLocation` (desktop approval);
- the mobile Teacher allowlist in `_authRedirect` (today Topic detail and Homework detail only);
- `_keepsLocationDuringBootstrap` for desktop and mobile, so a deep link survives bootstrap.

Only then is the read-only route available on both supported desktop and mobile Teacher surfaces.

Do not add authoring routes in FE-001.

---

# 47. Mobile / Desktop Routing

Read-only Blitz detail is allowed on:

```text
desktop
mobile
```

The existing Teacher destination gate remains authoritative.

Do not redirect mobile Blitz detail back to Topic.

Do not classify it as `authoring: true`.

Future create/edit/question-builder routes will be desktop-authoring surfaces
under later tasks.

---

# 48. Auth Redirect Integration

Update Teacher approved-location checks so a valid Blitz detail route survives:

- bootstrap;
- authenticated redirect;
- direct application launch/deep-link equivalent supported by current router;
- desktop/mobile Teacher route validation.

Query/fragment remains unsupported.

Malformed Blitz paths, or any query/fragment, redirect an authenticated Teacher to the Teacher
workspace without a Blitz GET (existing Homework behavior); during bootstrap they fall back to
`/`.

Do not weaken other role/device routing.

---

# 49. Topic Detail Integration

Add:

```text
TeacherBlitzSection
```

to:

```text
TeacherTopicDetailScreen
```

Recommended content order:

```text
Topic information
Group
History
Learning Materials where applicable
Homework
Blitz
```

This preserves the educational sequence:

```text
Homework -> Blitz
```

---

# 50. Blitz Section Header

Display:

```text
Blitz
```

with:

- Refresh button;
- status filter.

Do **not** display:

- Create Blitz;
- Edit;
- Activate;
- Close;
- Archive;
- Monitor;
- Grant exception.

Later frontend tasks add working mutation/action controls.

No disabled placeholder buttons.

---

# 51. Status Filter

Provide exact options:

```text
All statuses
Draft
Scheduled
Active
Closed
Archived
```

Changing status:

- calls list controller `setStatus`;
- resets page to 1;
- loads new server query.

No local post-fetch filtering.

---

# 52. Blitz List Loading / Error / Empty

Required visual states:

## Loading

Progress indicator with semantic label.

## Refreshing

Retain current cards and show progress indicator.

## Initial error

Show:

```text
Blitz could not be loaded.
```

with Retry.

## Stale refresh error

Keep current data and visibly indicate:

```text
The displayed Blitz list may be out of date.
```

with Retry/Refresh available according to controller state.

## Empty without filter

Use clear wording equivalent to:

```text
No Blitz has been created for this Topic yet.
```

## Empty with status filter

Equivalent:

```text
No Blitz matches the current status filter.
```

Do not tell the user to create one in FE-001 because no create action is
available yet.

---

# 53. Blitz List Card

Each card must display at minimum:

```text
title
status label
assignment label
question count
total points
duration
scheduled time / Not scheduled
```

If result-pair state is confirmed and:

```text
lowercase(pair.blitzAssessmentId) == lowercase(blitz.id), only when hasConfirmedData
```

show:

```text
Official
```

chip.

Never show:

```text
Practice
```

merely because current pair state is unavailable/not loaded.

Absence of confirmed official evidence is not proof of practice.

---

# 54. Official-Blitz Read Indicator

Reuse existing:

```text
teacherTopicResultPairControllerProvider(topicId)
```

Do not create another result-pair repository/controller.

Rules:

- confirmed pair + case-insensitively equal Blitz ID -> show Official chip;
- confirmed pair + different/null Blitz ID -> no Official chip;
- pair loading/error/unconfirmed -> no Official chip;
- do not locally infer official status from assignment mode;
- do not mutate pair.

Do not block Blitz list/detail data if result-pair read fails.

Official status is supplemental read metadata.

---

# 55. Card Navigation

Blitz card is a real interactive read target.

On tap:

```text
context.push(
  AppRoutePaths.teacherBlitzDetailLocation(topicId, blitz.id)
)
```

Use accessible Semantics:

```text
button: true
label: Open Blitz <title>
```

No mutation on card tap.

---

# 56. Pagination UI

Reuse the current Teacher list pagination presentation pattern.

Display:

```text
Previous
Page X of Y
Next
```

Disable unavailable directions.

Do not implement infinite scroll.

Do not locally modify pagination totals.

---

# 57. Read-Only Blitz Detail Screen

Create:

```text
TeacherBlitzDetailScreen
```

Property:

```text
TeacherBlitzRouteTarget target
```

The route builder passes the canonical target and keys the screen with `ValueKey(target)`, as
the Homework edit route does. Use the same target for controller ownership.

---

# 58. Detail Scaffold / Navigation

App bar:

```text
Blitz Detail
```

Back action:

```text
Teacher Topic detail
```

using canonical Topic location.

Do not rely only on Navigator history; direct route entry must still have a safe
Back-to-Topic action.

---

# 59. Detail Loading / Not Found / Error

## Loading

Centered progress with semantic label.

## Not found

Display:

```text
Blitz unavailable
```

with explanation that it is unavailable in the current Teacher workspace.

Back to Topic.

## Error

Display user-safe generic mapping based on `ApiFailure.kind`:

- connection;
- timeout;
- other.

Retry.

Do not display raw exception text/server internals.

---

# 60. Detail Refreshing / Stale

When a confirmed Blitz is refreshed:

- retain visible content;
- show progress indicator;
- disable duplicate refresh;
- if refresh fails, visibly mark content may be out of date.

Do not replace a confirmed detail with a blank screen during refresh.

---

# 61. Detail Header

Display:

```text
title
status chip
assignment chip
optional Official chip
```

Official chip follows Section 54 only.

Do not display mutation buttons in FE-001.

A Refresh button is allowed.

---

# 62. Blitz Information Card

Display:

```text
Description              // if non-null
Student instructions
Assignment
Selected students count  // selected_students only
Total possible points
Questions count
Institution timezone
```

For group assignment:

```text
Whole group
```

Do not list recipient names.

Do not fetch a Student roster.

---

# 63. Timing Card

Display:

```text
Duration
Scheduled time
Timer start mode snapshot
Activated at
Synchronized common end
Closed at
Archived at
```

Only show timestamps that exist, except planned schedule/timer mode may show
explicit absent labels.

---

# 64. Duration Formatting

Create a deterministic presentation formatter.

Examples:

```text
60    -> 1 min
600   -> 10 min
90    -> 1 min 30 sec
45    -> 45 sec
3661  -> 1 hr 1 min 1 sec
```

Exact wording may be concise but must be:

- deterministic;
- readable;
- derived only from backend `durationSeconds`.

Do not round away seconds when not divisible by 60.

Do not assume duration is 5–10 minutes.

---

# 65. Scheduled Time Formatting

If:

```text
scheduledAt = null
```

show:

```text
Not scheduled
```

Otherwise format the authoritative instant in:

```text
institutionTimezone
```

using the existing Teacher timezone formatter infrastructure.

If timezone formatting unexpectedly fails:

```text
Institution timezone unavailable
```

or the established equivalent.

Do not use device local timezone as authority.

---

# 66. Timer Mode Display

If:

```text
timerStartModeSnapshot = null
```

show wording equivalent to:

```text
Not snapshotted until activation
```

If synchronized:

```text
Synchronized
```

If individual:

```text
Individual
```

Do not read current Institution setting to fill null.

---

# 67. Attempt Policy Card

Display:

```text
Normal attempts: 1
Maximum additional exception attempts: 1
```

This is read-only server-authoritative policy.

Do not present the additional attempt as already granted.

Do not create exception UI.

---

# 68. Lifecycle History

Display existing timestamps:

```text
Created
Updated
Activated
Closed
Archived
```

in UTC or existing established history formatting where current Teacher detail
screens do so.

Scheduled time remains Institution-timezone formatted separately.

Do not calculate inferred lifecycle state from timestamps for control flow.

Use the parsed enum.

---

# 69. Question Read Section

Header:

```text
Questions
```

If empty:

```text
No Questions have been added.
```

Else render every Question in canonical order using existing:

```text
TeacherQuestionReadView
```

This Teacher view may show correct-answer configuration exactly as current
Teacher Homework detail does.

Do not create a second Question display implementation.

No Question edit button.

No reorder controls.

---

# 70. Responsive Layout

Support current approved Teacher desktop/mobile surfaces.

Use:

```text
SafeArea
SingleChildScrollView
ConstrainedBox
Wrap
```

or current equivalents.

No horizontal overflow at narrow mobile widths.

Long:

- title;
- instructions;
- description;
- Question prompt;
- option text

must wrap/scroll vertically.

No desktop-only restriction for this read screen.

---

# 71. Accessibility

Required:

- section headers use Semantics/header where current patterns support it;
- list cards expose an actionable semantic label;
- progress indicators have semantic labels;
- Refresh buttons have tooltip/semantic meaning;
- state is not communicated by color only;
- cards/buttons remain keyboard-focusable through standard Material behavior;
- long text is not clipped as the only presentation.

No custom accessibility framework.

---

# 72. Presentation Formatters

Create:

```text
teacher_blitz_formatters.dart
```

Minimum:

```text
teacherBlitzStatusLabel
teacherBlitzAssignmentLabel
teacherBlitzTimerModeLabel
formatTeacherBlitzDuration
formatTeacherBlitzScheduledAt
```

Use existing general Topic/time formatting helpers where appropriate.

A shared existing points formatter may be reused if it is pure numeric
presentation.

Do not move backend rules into formatters.

---

# 73. No Client Timer Logic in FE-001

Although detail may display:

```text
activatedAt
synchronizedEndsAt
duration
```

FE-001 does **not** implement a live countdown.

Do not schedule local timers.

Do not calculate whether active Blitz time has expired for business control.

The server lifecycle/resource remains authoritative.

Student countdown is owned by S08-FE-004/005.

---

# 74. No Local Lifecycle Action Logic

Do not create helpers like:

```text
teacherBlitzCanActivate
teacherBlitzCanClose
teacherBlitzCanArchive
```

for actionable UI in FE-001.

Status labels/read rendering are allowed.

Mutation action eligibility belongs to S08-FE-003.

---

# 75. No Local Official Designation Logic

Do not derive:

```text
official = assignmentMode == group
```

or:

```text
official = active
```

Official indicator requires exact result-pair ID match.

No result-pair PUT.

---

# 76. Data Source Failure Mapping

GET requests use the existing generic read mapping.

Expected failures include current common infrastructure:

```text
401 authentication_required
403 forbidden / password_change_required / user_inactive / institution_inactive
404 resource_not_found
422 validation_failed where relevant
429 rate_limited
5xx server
transport/timeout
malformed success
```

Do not create a Blitz-specific human-message parser.

---

# 77. Invalid Successful Payload

Any strict DTO failure must become:

```text
ApiFailure.local(
  kind: invalidResponse,
  message: <safe generic message>
)
```

through the existing `_mapFailures` pattern of the Teacher Homework remote data source
(`message` is a required parameter).

UI displays a safe generic load failure.

Do not partially render malformed backend state.

---

# 78. Route / DTO Security Boundary

Flutter route guards are UX only.

Do not treat canonical route IDs as authorization.

Backend 404 remains authoritative.

Do not display one Blitz under another Topic route if the backend resource
`topic_id` does not match the nested route target.

---

# 79. Provider / Cache Ownership

Use auto-dispose family providers consistent with existing Teacher read
controllers.

Do not build a persistent global Blitz cache.

List and detail own their own read state.

If the same Blitz appears in list/detail, no hidden cross-provider mutable object
sharing is required.

Later mutation tasks may add narrow invalidation/reconciliation.

---

# 80. Session Change Safety

If Teacher session identity changes while a list/detail request is in flight:

- old completion is discarded;
- old Blitz data is not published to new session;
- no old Snackbar/navigation is emitted;
- state resets according to current Teacher controller conventions.

Device-surface changes that alter session key likewise invalidate stale
completion.

---

# 81. Target Change Safety

Detail provider is keyed by route target.

A completion for:

```text
Topic A / Blitz X
```

must not publish into:

```text
Topic B / Blitz Y
```

even if Widget reuse occurs.

Use immutable target identity + generation.

Do not rely only on `context.mounted`.

---

# 82. Expected File Scope

Exact filenames may follow repository conventions.

## Create likely

```text
frontend/lib/features/teacher/domain/teacher_blitz.dart
frontend/lib/features/teacher/domain/teacher_blitz_list.dart
frontend/lib/features/teacher/domain/teacher_blitz_list_query.dart
frontend/lib/features/teacher/domain/teacher_blitz_repository.dart

frontend/lib/features/teacher/data/dto/teacher_blitz_dto.dart
frontend/lib/features/teacher/data/dto/teacher_blitz_list_dto.dart
frontend/lib/features/teacher/data/teacher_blitz_remote_data_source.dart
frontend/lib/features/teacher/data/teacher_blitz_repository_impl.dart

frontend/lib/features/teacher/application/teacher_blitz_list_state.dart
frontend/lib/features/teacher/application/teacher_blitz_list_controller.dart
frontend/lib/features/teacher/application/teacher_blitz_detail_state.dart
frontend/lib/features/teacher/application/teacher_blitz_detail_controller.dart
frontend/lib/features/teacher/application/teacher_blitz_route_target.dart

frontend/lib/features/teacher/presentation/teacher_blitz_section.dart
frontend/lib/features/teacher/presentation/teacher_blitz_detail_screen.dart
frontend/lib/features/teacher/presentation/teacher_blitz_formatters.dart
```

## Modify

```text
frontend/lib/features/teacher/presentation/teacher_topic_detail_screen.dart
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
```

A narrow existing shared Question-list parser extraction is allowed if necessary.

Test support (revalidation 2026-09-24): add `FakeTeacherBlitzRepository` and Blitz fixtures to
`frontend/test/features/teacher/teacher_test_support.dart` (existing fake-repository pattern;
`teacherHomeworkQuestions()` provides an all-nine-type fixture), and add the Blitz repository
override to full-app Topic detail tests that override repositories one by one, so no test
reaches the real Dio client.

Do not modify:

```text
backend/
platform files
pubspec.yaml
pubspec.lock
student Blitz frontend
Teacher Homework mutations/lifecycle
integration_test/
docs/
tasks/
```

unless an exact directly affected regression test needs a small test-only update.

---

# 83. DTO Tests

Create focused tests, conceptually:

```text
teacher_blitz_dto_test.dart
teacher_blitz_list_dto_test.dart
```

Cover:

## Summary

- exact valid Draft row;
- Scheduled row;
- all status enum values;
- canonical UUID enforcement;
- non-negative points;
- non-negative question count;
- positive duration;
- nullable schedule;
- wrong Topic row rejected;
- unknown key rejected;
- missing key rejected.

## Full resource

- Draft with null schedule;
- Draft with non-null schedule;
- Draft with fractional `scheduled_at` (for example `2026-09-18T04:00:00.123456Z`);
- Scheduled canonical state;
- Active synchronized;
- Active individual;
- Closed synchronized;
- Closed individual;
- preactivation Archived;
- post-close Archived;
- assignment/student IDs invariant;
- canonical attempt policy;
- exact timer end math;
- invalid lifecycle timestamp combinations rejected;
- invalid timer snapshot combinations rejected;
- unknown keys rejected;
- duplicate Question IDs rejected;
- non-contiguous Question positions rejected;
- all nine existing Question DTO configurations accepted.

---

# 84. List DTO / Envelope Tests

Verify:

- exact `{data, meta.pagination}` current Teacher list envelope;
- requested page/perPage consistency;
- duplicate Blitz IDs rejected through shared list envelope behavior;
- every row matches expected Topic;
- empty page allowed;
- pagination metadata strict;
- unknown envelope key rejected according to existing list infrastructure.

Do not invent a second envelope parser.

---

# 85. Remote Data Source Tests

Create:

```text
teacher_blitz_remote_data_source_test.dart
```

Verify exact:

## List

```text
GET /teacher/blitz
topic_id
status?
page
per_page
no unsupported query keys
followRedirects=false
```

## Detail

```text
GET /teacher/blitz/{encoded UUID}
no query
```

Verify:

- correct 200 parsing;
- non-200 mapped through existing failure mapper;
- malformed 200 -> invalidResponse;
- invalid local UUID fails before network;
- no mutation endpoint called.

---

# 86. Repository Tests

Verify:

- DTO converts to domain exactly;
- repository introduces no hidden cache;
- list/detail forwarding exact.

A separate test file is optional if data-source + controller tests already cover
the implementation boundary clearly.

Do not add tests merely to inflate count.

---

# 87. List Controller Tests

Create:

```text
teacher_blitz_list_controller_test.dart
```

Cover:

- initial loading;
- successful data;
- status filter resets page;
- previous/next;
- refresh retains data;
- refresh failure marks stale;
- retry;
- duplicate same-query in-flight suppression;
- session loss clears state;
- stale completion after session switch ignored;
- stale completion after newer query ignored;
- disposal ignored;
- invalid Topic ID produces no network request.

No search tests.

---

# 88. Detail Controller Tests

Create:

```text
teacher_blitz_detail_controller_test.dart
```

Cover:

- initial loading;
- valid data;
- route Topic/Blitz target;
- backend resource Topic mismatch -> notFound;
- exact 404/resource_not_found -> notFound;
- other failure -> error;
- refresh retains data;
- refresh error -> stale;
- retry;
- session invalidation;
- stale completion ignored;
- disposal ignored.

---

# 89. Router Tests

Create/extend focused route tests:

```text
teacher_blitz_routing_screen_test.dart
```

Verify:

- exact canonical location:
  ```text
  /teacher/topics/<topicId>/blitz/<blitzId>
  ```
- path recognition;
- Topic ID extraction;
- invalid topic/blitz UUID rejected;
- query/fragment not accepted;
- desktop Teacher direct entry renders Blitz detail;
- mobile Teacher direct entry renders Blitz detail;
- wrong role does not gain Teacher detail;
- authoring gate is not applied to read detail;
- existing Homework routes remain valid.

---

# 90. Topic Detail Section Widget Tests

Create:

```text
teacher_blitz_section_test.dart
```

or extend Topic detail tests.

Cover:

- Blitz section appears after Homework;
- loading;
- empty;
- error + retry;
- stale refresh indicator;
- status filter;
- list cards;
- pagination;
- duration/schedule labels;
- card navigation;
- no create/edit/lifecycle/monitor buttons;
- Official chip only on confirmed pair exact ID;
- no false Practice/Official inference when pair state is unavailable.

Test both narrow mobile and wider desktop layouts where practical.

---

# 91. Detail Screen Widget Tests

Create:

```text
teacher_blitz_detail_screen_test.dart
```

Cover:

- loading;
- not found;
- error/retry;
- data layout;
- refresh progress;
- stale indicator;
- status/assignment labels;
- duration;
- schedule;
- timer mode null/synchronized/individual labels;
- attempt policy;
- lifecycle timestamps;
- selected Student count;
- empty Questions;
- all-nine Question readback reuse;
- Official chip confirmed;
- no mutation buttons;
- mobile no overflow;
- desktop constrained layout.

---

# 92. Question Read Regression

Because Blitz reuses:

```text
TeacherQuestionDto
TeacherQuestionReadView
```

run the existing focused Teacher Homework Question read tests that cover all nine
types.

If no production Question code changes:

- only direct read-view/DTO regression is required.

If a shared Question-list parser is extracted:

- run the current Homework DTO/detail Question parsing tests as well.

Do not run the entire Stage 6 frontend suite.

---

# 93. Topic / Homework Direct Regression

Because Topic detail and routing are changed, run directly affected tests such as
the current equivalents of:

```text
test/features/teacher/teacher_topic_routing_screen_test.dart
test/features/teacher/teacher_learning_material_screen_test.dart
test/features/teacher/teacher_homework_routing_screen_test.dart
test/features/teacher/teacher_homework_section_test.dart
test/features/teacher/teacher_homework_dto_test.dart
test/features/teacher/teacher_homework_detail_screen_test.dart
test/router_bootstrap_test.dart
```

(revalidation 2026-09-24: `teacher_topic_detail_screen_test.dart` does not exist; the Topic
detail screen is exercised by the routing and learning-material screen tests.)

Required:

- Homework section remains present/functional;
- Blitz section does not break Topic lifecycle/layout;
- Homework detail/create/edit/question routes still parse correctly;
- mobile authoring redirects remain unchanged.

---

# 94. Focused Verification Commands

Run from:

```text
frontend/
```

Use exact delivered test filenames where they differ.

## 94.1 Blitz DTO/data/controller/router/UI

```bash
fvm flutter test \
  test/features/teacher/teacher_blitz_dto_test.dart \
  test/features/teacher/teacher_blitz_list_dto_test.dart \
  test/features/teacher/teacher_blitz_remote_data_source_test.dart \
  test/features/teacher/teacher_blitz_list_controller_test.dart \
  test/features/teacher/teacher_blitz_detail_controller_test.dart \
  test/features/teacher/teacher_blitz_routing_screen_test.dart \
  test/features/teacher/teacher_blitz_section_test.dart \
  test/features/teacher/teacher_blitz_detail_screen_test.dart
```

If some responsibilities are combined in fewer focused files, run the actual
equivalent files and report exact commands.

---

# 95. Direct Regression Verification

Run the exact current focused files for:

```text
Teacher Topic detail
Teacher Homework section
Teacher Homework routing
Teacher Question read DTO/view
```

Only include tests directly affected by shared router/Topic/Question changes.

Do not run full frontend tests.

---

# 96. Focused Analyze

Run:

```bash
fvm flutter analyze --no-pub lib/features/teacher
fvm flutter analyze --no-pub lib/app/router
```

If the pinned Flutter CLI supports a narrower exact path set, use the narrowest
supported equivalent.

Do not silently substitute full-project analyze unless the actual CLI requires
it.

Report the exact command.

---

# 97. Format Check

Run read-only format check over directly changed Flutter paths:

```bash
fvm dart format --output=none --set-exit-if-changed \
  lib/features/teacher \
  lib/app/router/app_route_paths.dart \
  lib/app/router/app_router.dart \
  test/features/teacher
```

If this path scope includes unrelated pre-existing files whose formatting is not
part of the task, narrow to the actual changed files and report that exact list.

Do not format unrelated code.

---

# 98. Git Diff Check

From repository root:

```bash
git diff --check
```

Required:

```text
PASS
```

Also perform focused diff self-review.

Do not run:

- full frontend suite;
- full project analyze;
- Windows build;
- Android build;
- broad E2E.

Those belong to later Frontend Phase 2 / Integration.

---

# 99. Acceptance Criteria — Domain / DTO

- [ ] Blitz status enum exact.
- [ ] Assignment enum exact.
- [ ] Timer mode enum exact.
- [ ] Summary domain exact.
- [ ] Full domain exact.
- [ ] Attempt policy exact 1 + 1.
- [ ] Duration positive.
- [ ] Recipients cross-field invariant enforced.
- [ ] Lifecycle/timer cross-field invariant enforced.
- [ ] synchronized end exact.
- [ ] All-nine existing Question domain reused.
- [ ] Unknown/missing success keys rejected.
- [ ] Malformed success becomes invalidResponse.

---

# 100. Acceptance Criteria — Data / State

- [ ] List sends only supported backend query keys.
- [ ] Detail uses exact GET route.
- [ ] Repository is typed.
- [ ] No direct Dio in Widget/controller.
- [ ] List controller session-safe.
- [ ] Detail controller route/session-safe.
- [ ] Stale async completions cannot publish.
- [ ] Refresh can retain stale data visibly.
- [ ] 404 detail maps to notFound.
- [ ] Wrong nested Topic/Blitz route resource maps to notFound.

---

# 101. Acceptance Criteria — Routing

- [ ] Canonical nested Blitz detail route added.
- [ ] Approved Teacher-location parsing updated.
- [ ] Direct desktop entry works.
- [ ] Direct mobile entry works.
- [ ] No authoring gate on detail.
- [ ] Invalid route fails safely.
- [ ] No query/fragment route variant.
- [ ] Existing Homework routing remains green.

---

# 102. Acceptance Criteria — Topic Blitz Section

- [ ] Blitz section appears in Topic detail.
- [ ] No Create button.
- [ ] Status filter only.
- [ ] Refresh/pagination work.
- [ ] Loading/empty/error/stale states intentional.
- [ ] Card displays title/status/assignment/questions/points/duration/schedule.
- [ ] Card opens detail.
- [ ] Official chip requires confirmed exact result-pair match.
- [ ] No false official/practice inference.
- [ ] Mobile/desktop responsive.

---

# 103. Acceptance Criteria — Detail Screen

- [ ] Read-only.
- [ ] Back to Topic works from direct route entry.
- [ ] Metadata/timing/attempt policy visible.
- [ ] selected Student count only; no roster fetch.
- [ ] Timer snapshot null is presented accurately.
- [ ] Scheduled time uses Institution timezone.
- [ ] all-nine Teacher Question readback shown.
- [ ] No mutation controls.
- [ ] No live countdown.
- [ ] No client lifecycle/business authority.
- [ ] mobile layout does not overflow.

---

# 104. Scope Acceptance

- [ ] No backend change.
- [ ] No package change.
- [ ] No platform-file change.
- [ ] No create/edit/schedule mutation.
- [ ] No Question mutation.
- [ ] No Activate/Close/Archive.
- [ ] No official designation mutation.
- [ ] No exception UI.
- [ ] No monitoring.
- [ ] No Student Blitz UI.
- [ ] No checking/scoring/result UI.
- [ ] Focused tests pass.
- [ ] Focused analyze passes.
- [ ] Format check passes.
- [ ] `git diff --check` passes.

---

# 105. Focused Diff Self-Check

Before completion confirm the diff implements only:

```text
Teacher Blitz typed read foundation
+
Topic Blitz section
+
read-only Blitz detail route/screen
```

Verify specifically:

```text
no mutation endpoint call
no dead action button
no local timer authority
no second Question model
no second result-pair controller
no full-roster Student fetch
no Stage 9 score/checking UI
```

Confirm every changed file is necessary.

---

# 106. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. Blitz domain/DTO contract;
4. list/detail API calls;
5. Riverpod list/detail ownership behavior;
6. route/path integration;
7. Topic Blitz section behavior;
8. read-only detail behavior;
9. official-Blitz indicator behavior;
10. responsive/mobile behavior;
11. focused new test results;
12. directly affected regression results;
13. focused analyze result;
14. format check result;
15. `git diff --check`;
16. final `git status --short`;
17. focused scope/diff self-check;
18. any blocker/deviation.

Do not claim Stage 8 frontend complete.

After delivery ChatGPT performs read-only acceptance review.

`S08-FE-002` remains blocked until:

```text
S08-FE-001 = Accepted / Delivered
```

---

# 107. Implementation Readiness Verdict

```text
Scope / non-goals                    = RESOLVED
Backend read endpoints               = RESOLVED
Blitz domain enums/models            = RESOLVED
Summary/detail DTO keys              = RESOLVED
Attempt policy                       = RESOLVED
Lifecycle/timer parsing              = RESOLVED
Question reuse                       = RESOLVED
List query/pagination                = RESOLVED
Repository/data source               = RESOLVED
Riverpod list state                  = RESOLVED
Riverpod detail state                = RESOLVED
Session/stale completion safety      = RESOLVED
Nested route                         = RESOLVED
Desktop/mobile read access           = RESOLVED
Topic Blitz section                  = RESOLVED
Official read indicator              = RESOLVED
Read-only detail UI                  = RESOLVED
Timezone/duration formatting         = RESOLVED
Accessibility/responsiveness         = RESOLVED
Focused tests                        = RESOLVED
Focused verification                 = RESOLVED

Implementation Readiness Gate        = PASS
Execution dependency                 = S08-BE-PHASE-2 PASS
Current ChatGPT readiness approval   = REQUIRED before Codex handoff
Readiness authority                  = ChatGPT re-checks current origin/main and this exact contract
Next task after acceptance            = S08-FE-002
```
