# Codex Implementation Contract: S06-FE-001 — Homework Client Domain, Read Surfaces and Routing

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S06-FE-001` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter Teacher read-side Homework foundation` |
| Depends on | `S06-BE-001…006 Accepted / Delivered` **and** Stage 6 Backend Phase 2 `PASS` |
| Planning/readiness baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |
| Backend contract source | Approved Stage 6 backend contracts `S06-BE-003` and `S06-BE-006`; final implementation must be re-checked after Backend Phase 2 |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` immediately before Codex execution |
| Flutter toolchain | FVM-pinned Flutter `3.44.7` unless current `origin/main` deliberately changes the pin before implementation |
| Implementation Readiness Gate | `PASS — planning contract`; runtime entry remains gated by Backend Phase 2 |
| Verification | `Codex — focused frontend verification only` |
| Delivery execution | `Project Owner` |
| Frontend block checkpoint | Stage 6 Frontend Phase 2 after `S06-FE-001…004` are `Accepted / Delivered` |

This contract may be prepared before the backend block is implemented, but Codex must **not** start frontend implementation until:

```text
S06-BE-001…006 = Accepted / Delivered
Stage 6 Backend Phase 2 = PASS
current origin/main is re-checked
final backend Homework endpoints/resources are re-inspected
this contract still matches the delivered backend
clean synchronized local main
```

If final Backend Phase 2 produces a public API change that materially conflicts with this contract, stop and return `BLOCKED`; ChatGPT must reconcile the frontend contract before implementation.

This file is the complete task-specific implementation contract. Do not create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this implementation contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. final delivered Stage 6 backend route/resource implementation directly required to confirm the API already encoded below;
5. directly relevant current Teacher frontend source/tests.

Do not read product specifications, roadmap files, Stage history, previous task files, checkpoint reviews, closure reviews, or unrelated modules to determine requirements.

This contract already resolves:

- Homework read domain;
- strict DTO/resource parsing;
- Teacher Homework repository/data-source boundaries;
- eligible Group Student roster client boundary;
- Homework list query state;
- Topic-detail Homework section;
- Homework read-only detail route;
- desktop/mobile read behavior;
- typed all-nine Question readback;
- timezone display;
- session/target/stale-completion safety;
- route parsing/direct-entry behavior;
- loading/empty/error/not-found states;
- exact scope exclusions.

Codex must not add create/edit/lifecycle/designation behavior because a backend endpoint exists. Those belong to later approved frontend tasks.

---

# 3. Goal

Establish the Stage 6 Teacher Homework client/read foundation on top of the final Backend Phase 2 API.

An authenticated Teacher on an approved desktop or mobile surface must be able to:

1. open an authorized Topic;
2. see its Homework list;
3. search/filter/page that list;
4. refresh it independently from Topic detail;
5. open one Homework as a read-only detail route;
6. inspect authoritative metadata, deadline, fixed attempt policy, recipients count, and all nine typed Question configurations.

The task also creates the typed client/repository boundary for:

```text
GET /teacher/groups/{group}/students
```

so S06-FE-002 can build the selected-Student picker without inventing a second transport model.

No Stage 6 authoring action is exposed yet.

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

- typed Homework enums/domain models;
- typed all-nine Question read domain;
- strict Homework DTO parsing;
- strict Teacher Group Student roster DTO parsing;
- Homework list query model;
- Group Student query model;
- Homework repository contract/implementation;
- Group Student repository contract/implementation;
- configured Dio remote data sources;
- Homework list Riverpod state/controller scoped by Topic;
- Homework detail Riverpod state/controller scoped by route target;
- independent session/target/generation stale-completion safety;
- read-only Homework section in Teacher Topic detail;
- nested Teacher Homework detail route;
- responsive read-only Homework detail screen;
- presentation labels/formatters;
- focused DTO/data-source/repository/controller/router/widget tests;
- directly affected Stage 5 routing/Topic detail regressions.

## 4.2 Explicit non-goals

Do **not** implement:

- Homework create form;
- Homework edit form;
- Student selector UI;
- deadline picker/editing;
- Question builder/editors;
- Question create/update/delete/reorder mutations;
- Homework activate/close/archive controls;
- official Homework designation controls;
- result-pair GET/PUT client behavior;
- “Official” badge inferred from local assumptions;
- Student Homework execution;
- Attempt UI;
- checking/scoring UI;
- Blitz UI;
- Topic result UI;
- optimistic mutation state;
- offline persistence;
- URL-backed Homework list filters;
- new Flutter package;
- new router;
- new state-management framework;
- second Dio client;
- code generation framework;
- desktop-only artificial restriction for read routes;
- backend/API changes;
- platform file changes;
- full frontend test suite;
- full analyze/build;
- Windows/Android build;
- E2E.

Do not render dead/disabled “Create Homework”, “Edit”, lifecycle, Question edit, or official-designation controls in this task. Later tasks add working controls together with working destinations/actions.

---

# 5. Existing Frontend Architecture to Preserve

Reuse the current responsibility flow:

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
configured dioProvider
DioFailureMapper
ApiFailure
ApiRequestException
ApiErrorCodes
Teacher DTO parsing helpers
Teacher list pagination/envelope helpers where compatible
Topic detail formatting helpers
```

The current Teacher Topic detail controller already uses:

```text
session ownership
generation counter
autoDispose
404 -> notFound
session failure -> auth bootstrap/session reset
stale completion rejection
```

Homework read controllers must preserve the same safety model.

Do not create a parallel Teacher session abstraction.

---

# 6. Backend Read API Dependency

The final backend is authoritative.

The configured Dio base URL already includes:

```text
/api/v1
```

Use exactly these Stage 6 reads.

## 6.1 Homework list

```text
GET /teacher/topics/{topic}/homework
```

Success:

```text
HTTP 200
```

## 6.2 Homework detail

```text
GET /teacher/homework/{homework}
```

Success:

```text
HTTP 200
```

## 6.3 Eligible Group Students

```text
GET /teacher/groups/{group}/students
```

Success:

```text
HTTP 200
```

Do not call:

```text
/result-pair
```

in S06-FE-001.

Do not call mutation endpoints.

---

# 7. Domain Enums

Create exact machine enums.

## 7.1 `TeacherHomeworkStatus`

```text
draft
active
closed
archived
```

## 7.2 `TeacherHomeworkAssignmentMode`

```text
group
selectedStudents -> API `selected_students`
```

## 7.3 `TeacherQuestionType`

Exactly:

```text
singleChoice -> single_choice
multipleChoice -> multiple_choice
trueFalse -> true_false
shortWritten -> short_written
openWritten -> open_written
fileBased -> file_based
matching -> matching
ordering -> ordering
fillInBlank -> fill_in_blank
```

## 7.4 `TeacherQuestionCheckingMode`

```text
automatic
manual
```

Keep machine values out of presentation labels.

Do not use human-readable UI text as enum serialization authority.

---

# 8. Homework Summary Domain

Create a read model equivalent to:

```text
TeacherHomeworkSummary
```

Required fields:

```text
id
topicId
title
assignmentMode
totalPossiblePoints
questionCount
deadlineAt
institutionTimezone
status
createdAt
updatedAt
```

Types:

- IDs: canonical UUID `String`;
- `totalPossiblePoints`: finite non-negative `double`/`num` read value;
- `questionCount`: non-negative `int`;
- `deadlineAt`: nullable UTC `DateTime`;
- `createdAt/updatedAt`: UTC `DateTime`.

Important:

The frontend may display numeric points but must not recompute an authoritative Assessment total from summary values.

---

# 9. Full Homework Domain

Create a full read model equivalent to:

```text
TeacherHomework
```

Required fields:

```text
id
topicId
title
description
studentInstructions
assignmentMode
studentIds
totalPossiblePoints
deadlineAt
institutionTimezone
status
attemptPolicy
activatedAt
closedAt
archivedAt
createdAt
updatedAt
questions
```

## 9.1 Attempt policy

Typed value:

```text
TeacherHomeworkAttemptPolicy
```

Exact authoritative server values:

```text
normalAttempts = 3
officialScorePolicy = highest_valid_completed
```

The DTO parser must reject a success payload that returns another normal-attempt value or another official-score policy.

Flutter must not expose an editable attempt count.

## 9.2 Student IDs

`studentIds` is a list of canonical UUIDs.

Required DTO invariants:

- no duplicates;
- for `assignment_mode = group`, list must be empty;
- for `selected_students`, list may be non-empty according to server state.

Presentation in this task does **not** display raw Student UUIDs.

Use:

```text
Whole group
```

or:

```text
Selected students: N
```

Student names belong to authoring/roster UX in S06-FE-002.

This also avoids incorrectly resolving historical selected recipients against a roster endpoint that returns only currently eligible Students.

---

# 10. Typed Question Domain

Create:

```text
TeacherQuestion
```

with:

```text
id
type
prompt
instructions
points
position
checkingMode
configuration
```

`configuration` must be typed. Do not pass raw `Map<String, dynamic>` into application/presentation state.

Recommended sealed/domain hierarchy:

```text
TeacherQuestionConfiguration
TeacherChoiceQuestionConfiguration
TeacherTrueFalseQuestionConfiguration
TeacherShortWrittenAutomaticConfiguration
TeacherEmptyQuestionConfiguration
TeacherFileBasedQuestionConfiguration
TeacherMatchingQuestionConfiguration
TeacherOrderingQuestionConfiguration
TeacherFillInBlankQuestionConfiguration
```

Equivalent focused names are allowed.

The type/checking/configuration combination must remain explicit.

---

# 11. Choice Configuration Domain

For Single Choice and Multiple Choice:

```text
TeacherChoiceQuestionConfiguration
```

contains ordered:

```text
TeacherChoiceOption
  text
  isCorrect
  position
```

Read invariants:

- option count >= 2;
- positions exact `1..N`;
- non-blank text;
- Single Choice:
  - `checkingMode = automatic`;
  - exactly one correct.
- Multiple Choice:
  - `checkingMode = automatic`;
  - one or more correct.

Do not derive/store a client-authoritative `maxSelections`.

---

# 12. True/False Configuration Domain

Typed:

```text
TeacherTrueFalseQuestionConfiguration
```

with:

```text
correctValue: bool
```

Require:

```text
type = true_false
checkingMode = automatic
```

---

# 13. Short Written Domain

## 13.1 Automatic

Typed:

```text
TeacherShortWrittenAutomaticConfiguration
```

contains ordered:

```text
acceptedAnswers: List<String>
```

Require:

- `checkingMode = automatic`;
- at least one non-blank accepted answer.

Do not implement Student answer normalization or fuzzy comparison.

## 13.2 Manual

Use an explicit empty configuration value or a shared typed empty configuration.

Require:

```text
checkingMode = manual
configuration = {}
```

Do not show a fake answer key.

---

# 14. Open Written Domain

Require:

```text
checkingMode = manual
configuration = {}
```

Presentation shows:

```text
Manual review
```

No answer key.

---

# 15. File-Based Domain

Typed:

```text
TeacherFileBasedQuestionConfiguration
```

with exact:

```text
pdf
docx
ppt
pptx
```

Require:

- `checkingMode = manual`;
- exact four values;
- exact canonical order;
- no duplicate/additional extension.

Presentation shows the supported file extensions.

Do not infer/upload file-size rules in this task.

---

# 16. Matching Domain

Typed pair:

```text
TeacherMatchingPair
  clientKey
  left
  right
```

Read invariants:

- at least one pair;
- `clientKey` is a canonical UUID on server readback;
- left/right non-blank;
- no duplicate client keys;
- `checkingMode = automatic`.

The returned `clientKey` is readback correlation data only.

Presentation must not construct mutation URLs from it.

---

# 17. Ordering Domain

Typed item:

```text
TeacherOrderingItem
  text
  correctPosition
```

Require:

- at least two items;
- positions exact `1..N`;
- non-blank text;
- `checkingMode = automatic`.

Presentation orders by `correctPosition`.

---

# 18. Fill-in-the-Blank Domain

Typed:

```text
TeacherFillBlank
  key
  position
  acceptedAnswers
```

Require:

- at least one blank;
- keys unique;
- key grammar matches backend:
  `^[A-Za-z][A-Za-z0-9_-]{0,79}$`;
- positions exact `1..N`;
- at least one non-blank accepted answer per blank;
- `checkingMode = automatic`.

DTO parsing must also verify the Homework Question prompt has exact configured placeholder correspondence:

```text
{{blank_key}}
```

for the read success resource.

A malformed backend success payload must become an invalid-response failure rather than silently rendering an ambiguous Question.

---

# 19. Question List Cross-Field Invariants

Full Homework DTO parsing must require:

- Question IDs are unique;
- Question positions are exact contiguous `1..N`;
- list order matches `position`;
- every Question `points` is finite and non-negative;
- every type/checking/configuration combination is valid;
- unknown Question/config keys are rejected.

Do not calculate authoritative:

```text
sum(question.points) == totalPossiblePoints
```

in the frontend as a business truth check.

Backend owns the aggregate total.

---

# 20. Homework List Query Domain

Create immutable:

```text
TeacherHomeworkListQuery
```

Fields:

```text
search
status
assignmentMode
page
perPage
sort
direction
```

UI-owned defaults:

```text
search = null
status = null
assignmentMode = null
page = 1
perPage = 20
sort = created_at
direction = desc
```

S06-FE-001 UI does not expose sort/direction controls.

They remain fixed to:

```text
created_at desc
```

for deterministic newest-first Topic Homework browsing.

Search rules:

- UI draft text may contain surrounding spaces;
- on Apply/Search:
  - trim;
  - empty -> `null`;
  - max 160 characters;
- do not send unchanged search intent unnecessarily.

Filters:

```text
All statuses
Draft
Active
Closed
Archived
```

and:

```text
All assignments
Whole group
Selected students
```

Changing search/status/assignment filter resets:

```text
page = 1
```

Pagination:

- previous when page > 1;
- next only when current page < lastPage.

No URL query-state persistence.

---

# 21. Homework List Domain Result

Reuse existing Teacher list pagination value where appropriate.

Create:

```text
TeacherHomeworkList
  items
  pagination
```

Strict collection envelope:

```json
{
  "data": [],
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 20,
      "total": 0,
      "last_page": 1
    }
  }
}
```

Reuse the current strict Teacher list-envelope parser only if it supports the exact contract without weakening validation.

Do not duplicate pagination parsing merely for naming.

---

# 22. Eligible Group Student Read Domain

Create:

```text
TeacherGroupStudent
  id
  fullName
  loginName
```

and:

```text
TeacherGroupStudentList
TeacherGroupStudentListQuery
```

Query defaults:

```text
search = null
page = 1
perPage = 50
```

Maximum client value:

```text
100
```

The repository/data-source implements this read in S06-FE-001, but no roster UI/controller is required yet.

S06-FE-002 will consume this boundary for the selected-Student picker.

DTO must reject success rows with extra/missing keys.

Do not add email/phone fields to the client model.

---

# 23. Strict DTO Parsing

Add focused DTOs under:

```text
frontend/lib/features/teacher/data/dto/
```

Reuse current helpers such as:

```text
readExactTeacherMap
readTeacherCanonicalUuid
readTeacherRequiredUtcTimestamp
readTeacherNullableUtcTimestamp
```

Add narrowly focused numeric/list helpers only if needed.

## 23.1 Exact keys

Homework summary accepts exactly:

```text
id
topic_id
title
assignment_mode
total_possible_points
question_count
deadline_at
institution_timezone
status
created_at
updated_at
```

Full Homework accepts exactly:

```text
id
topic_id
title
description
student_instructions
assignment_mode
student_ids
total_possible_points
deadline_at
institution_timezone
status
attempt_policy
activated_at
closed_at
archived_at
created_at
updated_at
questions
```

Attempt policy accepts exactly:

```text
normal_attempts
official_score_policy
```

Question accepts exactly:

```text
id
type
prompt
instructions
points
position
checking_mode
configuration
```

Every nested configuration/item object must also reject missing/unknown keys.

## 23.2 Numeric parsing

For points/totals:

- require JSON number (`int` or `double`);
- reject string numeric values;
- reject `NaN`/infinity;
- require non-negative.

The frontend uses these read values only for display/form initialization in later tasks; it does not use them to independently decide authoritative score validity.

## 23.3 Timestamps

Require UTC `Z` success timestamps using current Teacher UTC parser.

`deadline_at` nullable.

Lifecycle cross-field shape must be consistent:

### draft

```text
activatedAt = null
closedAt = null
archivedAt = null
```

### active

```text
activatedAt != null
closedAt = null
archivedAt = null
```

### closed

```text
activatedAt != null
closedAt != null
archivedAt = null
```

### archived

Accept only backend-approved historical shapes:

```text
archivedAt != null
```

and either:

```text
activatedAt = null, closedAt = null
```

or:

```text
activatedAt != null, closedAt != null
```

Malformed success payload -> `ApiFailureKind.invalidResponse`.

Do not render malformed success data.

---

# 24. Homework Remote Data Source

Create:

```text
TeacherHomeworkRemoteDataSource
```

using configured `Dio`.

## 24.1 List

Method equivalent:

```text
fetchHomeworkList(topicId, query)
```

Before transport:

- require canonical Topic UUID;
- require query values are valid.

Request:

```text
GET /teacher/topics/{encodedTopicId}/homework
```

Always send:

```text
page
per_page
sort = created_at
direction = desc
```

Send only when non-null:

```text
search
status
assignment_mode
```

No body.

Require:

```text
statusCode == 200
```

Strict parse the collection.

## 24.2 Detail

Method equivalent:

```text
fetchHomework(homeworkId)
```

Require canonical UUID.

Request:

```text
GET /teacher/homework/{encodedHomeworkId}
```

No query/body.

Require 200.

Strict parse full resource.

## 24.3 Read failure mapping

Use:

```text
DioFailureMapper
ApiRequestException
```

same as current Topic reads.

Malformed success:

```text
ApiFailure.local(
  kind: invalidResponse
)
```

Do not add mutation-outcome-unknown behavior to pure GETs.

---

# 25. Group Student Remote Data Source

Create:

```text
TeacherGroupStudentRemoteDataSource
```

Request:

```text
GET /teacher/groups/{encodedGroupId}/students
```

Always send:

```text
page
per_page
```

Optional:

```text
search
```

Require 200.

Strict parse exact paginated rows.

Use the same read failure mapping as Homework/Topic reads.

Do not call Institution Admin roster endpoints.

---

# 26. Repository Contracts

Create focused interfaces.

## 26.1 Homework

```text
TeacherHomeworkRepository
```

Operations:

```text
Future<TeacherHomeworkList> fetchHomeworkList(
  String topicId,
  TeacherHomeworkListQuery query,
)

Future<TeacherHomework> fetchHomework(String homeworkId)
```

No mutation methods yet.

Later S06-FE-002…004 may extend this repository incrementally.

## 26.2 Group Student

```text
TeacherGroupStudentRepository
```

Operation:

```text
Future<TeacherGroupStudentList> fetchGroupStudents(
  String groupId,
  TeacherGroupStudentListQuery query,
)
```

Do not merge Group Student roster into the existing assigned-Group repository merely because both concern a Group. They have different API/resource ownership.

---

# 27. Homework List Controller

Create an autoDispose family controller keyed by:

```text
topicId
```

Recommended:

```text
teacherHomeworkListControllerProvider(topicId)
```

Use one focused state:

```text
initial
loading
data
refreshing
error
```

The empty case is:

```text
data + result.items.isEmpty
```

unless a distinct empty status materially simplifies the existing project pattern.

State must contain:

```text
result
failure
query
searchDraft
```

as needed for deterministic UI.

## 27.1 Session ownership

Anchor ownership to:

```text
TeacherSessionKey
topicId
generation
```

On:

- session replacement;
- logout;
- password-change gate;
- inactive account/institution;
- provider disposal;

stale async completion must not publish old Homework rows.

## 27.2 Load

Initial valid Teacher session + canonical Topic ID:

```text
loading -> fetch default query -> data/error
```

Invalid target/session:

```text
clear ownership
initial
```

## 27.3 Refresh

Keep current confirmed rows while refreshing:

```text
data -> refreshing(result retained) -> data/error
```

If refresh fails, it may keep the previous confirmed list only if the state explicitly distinguishes it as retained/stale with an error/notice; do not present it as freshly confirmed silently.

Use the existing Teacher list-controller convention where possible.

## 27.4 Search/filter/page

Changing query starts a new generation.

Older response must not overwrite newer query state.

Prevent duplicate exact-current request while the same operation is already active.

Do not debounce using arbitrary sleeps in tests.

Search may be explicitly submitted by Enter/Search button.

---

# 28. Homework Detail Route Target

Create an immutable route/application target:

```text
TeacherHomeworkRouteTarget
  topicId
  homeworkId
```

Both must be canonical UUIDs.

Use value equality.

The detail controller must be keyed by the complete target, not only `homeworkId`, because the route carries Topic context and a stale/mismatched parent route must never display a Homework under the wrong Topic screen.

---

# 29. Homework Detail Controller

Create an autoDispose family controller keyed by:

```text
TeacherHomeworkRouteTarget
```

States:

```text
initial
loading
data
refreshing
notFound
error
```

Use session + target + generation ownership equivalent to current Topic detail controller.

## 29.1 Backend 404

Exact:

```text
404 resource_not_found
```

-> `notFound`.

## 29.2 Route Topic mismatch

After a successful Homework fetch, require:

```text
homework.topicId == routeTarget.topicId
```

case-insensitive canonical UUID equality.

If not:

- do not display the Homework;
- publish `notFound`/unavailable state;
- do not attempt another endpoint to “discover” the correct Topic.

Backend remains authorization authority; this is route-context integrity only.

## 29.3 Session failures

Handle the same stable session codes as current Teacher detail:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

Clear ownership and use existing auth bootstrap behavior.

Do not branch on human-readable messages.

---

# 30. Routing Contract

Add one read route only.

Canonical path:

```text
/teacher/topics/{topicId}/homework/{homeworkId}
```

Recommended constants:

```text
teacherHomeworkSegment = homework
teacherHomeworkIdParameter = homeworkId
teacherHomeworkDetail
teacherHomeworkDetailLocation(topicId, homeworkId)
teacherHomeworkIdFromPath(path)
isTeacherHomeworkDetailPath(path)
```

Route name:

```text
teacherHomeworkDetail
```

Do not add:

```text
/new
/edit
```

routes yet.

Those belong to S06-FE-002.

---

# 31. Router Placement

Nest the Homework detail `GoRoute` under the existing Teacher Topic detail route.

Conceptually:

```text
/teacher
  /topics/:topicId
    /homework/:homeworkId
```

Builder:

```text
TeacherHomeworkDetailScreen(
  topicId: ...
  homeworkId: ...
)
```

Use:

```text
_buildTeacherDestination(...)
```

with:

```text
authoring = false
```

Therefore read detail is allowed on:

```text
desktop
mobile
```

Do not create a new `ShellRoute`.

---

# 32. Route Parsing Safety

Current `teacherTopicIdFromPath()` was designed before nested Homework routes.

Refactor route helpers carefully.

Required semantics:

## `isTeacherTopicDetailPath(path)`

True only for exact:

```text
/teacher/topics/<canonical-topic-uuid>
```

It must **not** return true for:

```text
/edit
/homework/...
```

## `isTeacherTopicEditPath(path)`

Preserve current exact behavior.

## `isTeacherHomeworkDetailPath(path)`

True only for exact:

```text
/teacher/topics/<canonical-topic-uuid>/homework/<canonical-homework-uuid>
```

No extra slash/segment.

## `teacherTopicIdFromPath(path)`

May return the Topic UUID for:

- exact Topic detail;
- Topic edit;
- Homework detail;

provided existing callers/tests remain correct.

Do not let a malformed nested path pass as a valid Topic detail.

## Query/fragment

Any Teacher route with query/fragment remains rejected by current router redirect to:

```text
/teacher
```

Homework filters are local controller state, not URL state.

---

# 33. Mobile / Bootstrap Routing

Update auth/bootstrap helper logic so valid Homework detail direct entry is retained on:

```text
desktop
mobile
```

when session bootstrap is still in progress.

After authenticated Teacher session:

- desktop Homework detail -> allowed;
- mobile Homework detail -> allowed;
- invalid/unapproved Teacher nested path -> `/teacher`.

Do not introduce mobile authoring.

Later create/edit Homework routes must use the existing authoring gate; this task does not add them.

---

# 34. Topic Detail Homework Section

Add a focused:

```text
TeacherHomeworkSection
```

to the current `TeacherTopicDetailScreen`.

Render it for:

```text
desktop
mobile
```

because it is read-only Teacher functionality.

Current Learning Material section remains desktop-only and unchanged.

Recommended order:

### Desktop

```text
Topic information
Group
History
Learning Materials
Homework
```

### Mobile

```text
Topic information
Group
History
Homework
```

Do not move/remove existing Topic cards/actions except the minimum layout insertion required.

---

# 35. Homework Section UX

Section has a stable key:

```text
teacherHomeworkSection
```

Header:

```text
Homework
```

No Create button in S06-FE-001.

## 35.1 Loading

Show an accessible local progress indicator.

Do not replace the whole Topic detail screen.

## 35.2 Error

Show a section-local safe error.

Provide:

```text
Retry
```

Do not navigate away from an otherwise valid Topic because only Homework list read failed.

## 35.3 Empty

If unfiltered default result empty:

```text
No Homework has been created for this Topic yet.
```

If filters/search produce empty:

```text
No Homework matches the current filters.
```

Do not render a dead create CTA.

## 35.4 Data

Display one card/list row per Homework with:

- title;
- status label;
- assignment label;
- Question count;
- total possible points;
- deadline;
- updated/created context only if layout remains readable.

Deadline display:

- use `institution_timezone` from the Homework summary;
- format via a focused timezone-aware formatter consistent with existing Topic formatting;
- `null` -> `No deadline`;
- never use device timezone as authority.

## 35.5 Navigation

Each row/card is an accessible actionable control.

On open:

```text
context.push(
  teacherHomeworkDetailLocation(topicId, homeworkId)
)
```

Prefer push so the Topic-detail/list state remains mounted beneath the nested route during ordinary in-app navigation.

Do not navigate from stale data that no longer belongs to the current session/Topic controller owner.

---

# 36. Homework Section Filters

Render compact read controls.

## Search

- text field;
- label/semantics: `Search Homework`;
- submit with Enter/Search action and explicit Search button/icon with tooltip;
- trim on submit;
- max 160;
- empty -> clear filter.

## Status

Options:

```text
All statuses
Draft
Active
Closed
Archived
```

## Assignment

Options:

```text
All assignments
Whole group
Selected students
```

## Refresh

Accessible button with tooltip/label.

## Pagination

Show:

```text
Page X of Y
Previous
Next
```

Disable appropriately.

Changing status/assignment immediately applies the filter and resets page to 1.

Search applies explicitly.

Do not add sort controls.

---

# 37. Homework Detail Screen

Create:

```text
TeacherHomeworkDetailScreen
```

Constructor:

```text
topicId
homeworkId
```

Stable screen key:

```text
teacherHomeworkDetailScreen
```

Use existing Scaffold/theme patterns.

App bar title:

```text
Homework Detail
```

Back behavior:

1. if navigator can pop -> `context.pop()`;
2. otherwise direct-entry fallback ->
   `context.go(teacherTopicDetailLocation(topicId))`.

The fallback must validate route IDs before constructing the location through `AppRoutePaths`.

---

# 38. Homework Detail States

## Loading

Full-screen local loading:

```text
teacherHomeworkDetailLoading
```

## Not found

Display:

```text
Homework unavailable
```

with action:

```text
Back to Topic
```

Do not expose whether it was foreign/another Teacher/deleted.

## Error

Safe error text +:

```text
Retry
Back to Topic
```

## Refreshing

Retain current confirmed Homework and show a progress indicator.

Do not disable ordinary back navigation during refresh.

---

# 39. Homework Detail Metadata Presentation

Display read-only sections.

## Summary

- title;
- status;
- assignment mode;
- Question count;
- total points;
- deadline;
- Institution timezone.

## Instructions

- description when non-null;
- Student instructions.

## Assignment

Show:

```text
Whole group
```

or:

```text
Selected students: N
```

Do not show raw UUIDs.

## Attempt policy

Show:

```text
Normal attempts: 3
Official score: Highest valid completed attempt
```

These are server-read values.

Do not make them editable.

## History

- Created;
- Updated;
- Activated if present;
- Closed if present;
- Archived if present.

Use UTC/history formatting consistent with current Topic detail for server history timestamps.

Deadline is displayed in Institution timezone.

---

# 40. Read-Only Question Presentation

Render:

```text
Questions
```

with Question cards ordered by `position`.

Each card includes:

- `Question N`;
- type human label;
- points;
- checking mode;
- prompt;
- optional instructions;
- type-specific configuration.

No edit/delete/reorder controls.

No drag handles.

No answer input fields.

This is Teacher answer-key/configuration inspection, not Student execution.

---

# 41. Question Configuration Presentation

## Single Choice / Multiple Choice

Show ordered options.

Indicate correct options using text/icon semantics that do not rely on color alone, e.g.:

```text
Correct
```

Do not render them as selectable Student inputs.

## True/False

Show:

```text
Correct answer: True
```

or False.

## Short Written automatic

Show:

```text
Accepted answers
```

list.

## Short Written manual

Show:

```text
Manual review
```

## Open Written

Show:

```text
Manual review
```

## File Based

Show:

```text
Allowed files: PDF, DOCX, PPT, PPTX
Manual review
```

## Matching

Show each pair:

```text
Left → Right
```

Do not show server `clientKey` in UI.

## Ordering

Show the correct ordered sequence.

## Fill in Blank

Show each blank key and accepted-answer list.

Do not implement answer checking in Flutter.

---

# 42. Presentation Formatting

Add focused helpers for:

```text
Homework status label
assignment mode label
Question type label
checking mode label
points display
deadline display
```

Rules:

- machine values stay in domain;
- UI labels stay in presentation;
- do not infer official status;
- do not infer lifecycle permission;
- do not recompute final scores.

Points display may remove insignificant trailing zeros for readability.

Do not use display-rounded values as future mutation equality authority.

---

# 43. Accessibility / Responsive Contract

Support current approved desktop/mobile surfaces.

Required:

- no horizontal overflow at supported mobile widths;
- long titles/prompts wrap;
- Question config lists scroll as part of the screen, not nested unbounded horizontal controls;
- text scaling does not obscure controls;
- all icon-only actions have tooltip/semantic label;
- search field has label;
- filter dropdowns have labels;
- loading indicators have semantics labels;
- actionable Homework cards expose a clear semantic action/name;
- correct-answer status does not rely on color only;
- empty/error text remains readable;
- keyboard Enter submits Homework search on desktop;
- focus order follows visual order.

No custom breakpoint framework.

Use existing Material/theme patterns.

---

# 44. Failure UX / Session Reconciliation

Read controllers branch only on structured failure data.

Handle exact Teacher session failure codes through existing auth/session flow:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

Homework/Topic inaccessible:

```text
404 resource_not_found
```

-> unavailable/notFound where applicable.

Other:

- rate limit;
- transport;
- server;
- invalid response

-> safe local error with retry.

Do not parse backend human-readable messages to decide state.

Do not display raw URLs/UUID-bearing error text/stack traces.

---

# 45. State / Cache Ownership

No repository-level persistent cache is added.

Riverpod read controllers own current confirmed state.

Homework Topic list state is scoped by:

```text
session + topicId
```

Homework detail state is scoped by:

```text
session + topicId + homeworkId
```

No second cache for the existing Topic resource.

Do not insert Homework data into `TeacherTopic` domain model.

Topic detail and Homework list remain independent API/state boundaries.

This is important because Homework failures must not corrupt otherwise-valid Topic detail state.

Later mutation tasks may invalidate/accept authoritative Homework state through these controllers; do not implement speculative mutation invalidation now.

---

# 46. Data / Application File Placement

Recommended new domain files:

```text
frontend/lib/features/teacher/domain/
  teacher_homework.dart
  teacher_homework_list.dart
  teacher_homework_list_query.dart
  teacher_homework_repository.dart
  teacher_question.dart
  teacher_group_student.dart
  teacher_group_student_list.dart
  teacher_group_student_list_query.dart
  teacher_group_student_repository.dart
```

Equivalent focused grouping is allowed if it does not create oversized mixed-responsibility files.

Recommended data:

```text
frontend/lib/features/teacher/data/
  teacher_homework_remote_data_source.dart
  teacher_homework_repository_impl.dart
  teacher_group_student_remote_data_source.dart
  teacher_group_student_repository_impl.dart
  dto/
    teacher_homework_dto.dart
    teacher_homework_list_dto.dart
    teacher_question_dto.dart
    teacher_group_student_dto.dart
    teacher_group_student_list_dto.dart
```

Reuse/extend:

```text
teacher_dto_parse.dart
```

only with general Teacher parsing helpers that are genuinely shared.

Do not add Homework-specific business rules into a generic parser file.

Recommended application:

```text
teacher_homework_list_controller.dart
teacher_homework_list_state.dart
teacher_homework_detail_controller.dart
teacher_homework_detail_state.dart
teacher_homework_route_target.dart
```

No Group Student controller in this task.

---

# 47. Presentation / Router File Placement

Create:

```text
frontend/lib/features/teacher/presentation/
  teacher_homework_section.dart
  teacher_homework_detail_screen.dart
  teacher_homework_formatters.dart
  teacher_question_read_view.dart
```

Equivalent focused widget extraction is allowed.

Modify narrowly:

```text
frontend/lib/features/teacher/presentation/teacher_topic_detail_screen.dart
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
```

Do not create a Teacher shell.

Do not alter Institution Admin / Platform / Student route families except where a route-helper refactor mechanically preserves their behavior.

---

# 48. Router / Session Regression Requirements

Preserve:

- `/teacher`;
- Topic create desktop-only;
- Topic edit desktop-only;
- Topic detail desktop/mobile;
- Student routes;
- Institution Admin routes;
- auth redirects;
- unsupported-device behavior;
- password-change gate.

New:

```text
Homework detail desktop/mobile
```

Invalid Homework nested paths must not become approved Teacher destinations.

Mobile must not gain Topic/Homework authoring routes.

---

# 49. Test Support

Extend current Teacher fake/test support with focused fakes:

```text
FakeTeacherHomeworkRepository
FakeTeacherGroupStudentRepository
```

Do not force unrelated existing tests to construct Homework repositories when they do not render Homework functionality.

Where `TeacherTopicDetailScreen` now renders `TeacherHomeworkSection`, Topic-detail test harnesses must override a safe fake Homework repository so tests do not attempt network access.

A default fake may return an empty first page unless a test provides behavior.

Keep fake behavior explicit and deterministic.

---

# 50. Acceptance Criteria

- [ ] `TeacherHomeworkStatus`, assignment mode, Question type/checking enums use exact API machine values.
- [ ] Homework summary/full domain models are typed and do not expose raw JSON.
- [ ] Full Homework attempt policy strictly requires server fixed value `3` and `highest_valid_completed`.
- [ ] All nine Question types have typed read configuration.
- [ ] DTO parsing rejects unknown/missing keys, bad UUIDs, malformed UTC timestamps, invalid lifecycle shape, invalid type/checking/config combinations, duplicate/gapped Question positions, and malformed Fill Blank placeholders.
- [ ] Numeric points/totals require finite non-negative JSON numbers.
- [ ] Homework list DTO uses strict standard pagination.
- [ ] Group Student roster model exposes only `id/fullName/loginName`.
- [ ] Homework data source uses exact GET paths/query/status rules and configured Dio.
- [ ] Group Student data source uses exact Teacher roster endpoint, not Institution Admin endpoint.
- [ ] Read failures use existing `DioFailureMapper`/`ApiRequestException`.
- [ ] Homework list controller is session/topic/generation safe.
- [ ] Homework detail controller is session/topic/homework/generation safe.
- [ ] stale older query/detail completions cannot overwrite current state.
- [ ] 404 becomes unavailable/notFound without existence leakage.
- [ ] `/teacher/topics/{topic}/homework/{homework}` is the sole new route.
- [ ] Homework detail route is allowed on desktop and mobile.
- [ ] no Homework create/edit/lifecycle/official route/control is added.
- [ ] route query/fragment remains rejected.
- [ ] malformed nested Homework paths are rejected safely.
- [ ] Topic detail renders an independent Homework section on desktop/mobile.
- [ ] Homework list supports search/status/assignment filters, refresh, and pagination.
- [ ] Homework list uses institution timezone for deadline display.
- [ ] list failures do not replace/corrupt Topic detail.
- [ ] Homework detail shows metadata, recipient count semantics, fixed attempt policy, history, and all nine Question configurations read-only.
- [ ] raw selected Student UUIDs and Matching server keys are not shown in UI.
- [ ] no client-side official status inference exists.
- [ ] existing Topic/Material UI behavior remains intact.
- [ ] no new package/platform/backend/docs/seed change enters scope.
- [ ] focused tests pass.
- [ ] focused analyze passes.
- [ ] format check passes.
- [ ] `git diff --check` passes.
- [ ] final diff self-review finds no stale-async/routing/API/architecture/scope blocker.

---

# 51. Focused Tests and Verification

Run from:

```text
frontend/
```

Use the repository-pinned FVM Flutter toolchain.

Do not run the full frontend suite or builds in this task. Those belong to Stage 6 Frontend Phase 2.

## 51.1 DTO / data-source / repository

Create/use focused tests such as:

```bash
fvm flutter test \
  test/features/teacher/teacher_homework_dto_test.dart \
  test/features/teacher/teacher_homework_data_test.dart \
  test/features/teacher/teacher_group_student_data_test.dart
```

Exact filenames may be consolidated if responsibilities remain clear.

Required coverage:

### Homework DTO

- each status;
- group/selected;
- null/non-null deadline;
- fixed attempt policy;
- all nine Question types positive;
- unknown/missing keys;
- malformed UUID;
- numeric string rejection;
- non-finite/negative point rejection;
- lifecycle inconsistency;
- duplicate Student ID;
- group with non-empty Student IDs rejection;
- duplicate Question ID;
- gapped/out-of-order Question positions;
- wrong checking mode;
- malformed typed config;
- Fill Blank placeholder mismatch;
- malformed list envelope.

### Data source

- exact list method/path/query;
- optional filter omission;
- exact detail path;
- exact roster path/query;
- no body;
- 200 required;
- Dio failures map;
- malformed success -> invalid response.

## 51.2 Controllers

```bash
fvm flutter test \
  test/features/teacher/teacher_homework_list_controller_test.dart \
  test/features/teacher/teacher_homework_detail_controller_test.dart
```

Cover:

- initial load;
- refresh retain behavior;
- search/filter/page;
- filter resets page;
- duplicate active request suppression where relevant;
- older search completion cannot overwrite newer;
- session replacement stale completion rejected;
- logout/disposal stale completion rejected;
- 404 detail -> notFound;
- successful detail with wrong `topicId` -> unavailable/notFound;
- session failure clears ownership/reconciles auth;
- invalid response -> error.

## 51.3 Router / screen

```bash
fvm flutter test \
  test/features/teacher/teacher_homework_routing_screen_test.dart \
  test/features/teacher/teacher_homework_section_test.dart \
  test/features/teacher/teacher_homework_detail_screen_test.dart \
  test/features/teacher/teacher_topic_routing_screen_test.dart
```

Cover:

### Route

- desktop direct Homework detail;
- mobile direct Homework detail;
- canonical helper round-trip;
- malformed Topic ID;
- malformed Homework ID;
- extra segment;
- query/fragment redirects;
- mobile Topic create/edit restriction unchanged;
- ordinary back returns Topic;
- direct-entry Back to Topic fallback.

### Section

- loading;
- error/retry;
- default empty;
- filtered empty;
- data cards;
- search;
- status filter;
- assignment filter;
- pagination;
- refresh;
- deadline in Institution timezone;
- card opens nested route;
- no create/edit/lifecycle/designation control.

### Detail

- loading;
- not found;
- error/retry;
- metadata;
- group assignment;
- selected count without UUID display;
- fixed attempt policy;
- null deadline;
- institution-timezone deadline;
- all nine Question read views;
- long content/mobile no overflow in the tested constraints;
- correct-answer state communicates without color only;
- no mutation controls.

## 51.4 Directly affected Stage 5 regressions

Because Topic detail and router are modified:

```bash
fvm flutter test \
  test/features/teacher/teacher_learning_material_screen_test.dart \
  test/features/teacher/teacher_topic_controller_test.dart
```

If `teacher_topic_routing_screen_test.dart` is already in the router group above, do not rerun it redundantly.

No full Stage 5 frontend suite is required at task level.

## 51.5 Focused analyze

```bash
fvm flutter analyze --no-pub lib/features/teacher
fvm flutter analyze --no-pub lib/app/router
```

If the pinned Flutter CLI accepts only one analyze root and the second command cannot target a subdirectory cleanly, run the narrowest supported equivalent and report it. Do not silently substitute a full project analyze unless required by the actual CLI behavior.

## 51.6 Format check

```bash
fvm dart format --output=none --set-exit-if-changed \
  lib/features/teacher \
  lib/app/router/app_route_paths.dart \
  lib/app/router/app_router.dart \
  test/features/teacher
```

Do not format unrelated project areas.

## 51.7 Always

```bash
git diff --check
```

Then focused diff self-review:

- feature-first boundaries preserved;
- Widgets do not call Dio/parse JSON;
- no second router/client/cache/state framework;
- no raw config maps escape DTO/domain boundary;
- no backend-authoritative business result recomputation;
- no mobile authoring enabled;
- no dead future controls;
- stale completion/session ownership correct;
- Topic/Student/Admin routing not regressed;
- no package/platform/lockfile change;
- no debug/secrets/temp/generated junk;
- no unrelated formatting churn.

---

# 52. Project Owner Manual Check

```text
Not required at task level.
```

Reason:

- read/API/routing/widget behavior is covered by focused deterministic tests;
- real-stack Stage 6 Teacher Homework browsing/building smoke belongs to `S06-INT-001`.

---

# 53. Delivery

Follow root `AGENTS.md` and `tasks/README.md`.

Delivery execution:

```text
Project Owner
```

Suggested delivery after implementation:

```text
Branch: feat/s06-fe-001-homework-read-foundation
Commit: feat(stage6): add homework read surfaces
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

---

# 54. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to rediscover requirements.

| Source/reference | Decision already encoded above |
|---|---|
| Approved Stage 6 decomposition | FE-001 owns Homework client domain/data, roster client, list/detail read surfaces and routing |
| Stage 6 backend FE dependency | Frontend starts only after Backend Phase 2 PASS |
| S06-BE-003 contract | Homework list/detail + Teacher Group Student roster resource shapes |
| S06-BE-006 contract | Official status is separate result-pair state and is deliberately not inferred in FE-001 |
| Current Teacher architecture | feature-first Presentation -> Application -> Repository -> Data/Dio |
| Current Topic detail controller | session key + generation stale-completion pattern |
| Current Topic detail screen | desktop/mobile read route; Materials currently desktop-only |
| Current GoRouter | Teacher authoring gate desktop-only, Teacher read destinations desktop/mobile |
| Current Teacher DTO helpers | exact maps, canonical UUID, strict UTC timestamps |
| Current FVM pin | Flutter `3.44.7` |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |

---

# 55. Codex Final Report

Return one implementation status:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

`DELIVERY BLOCKED` is not applicable because delivery is Project Owner-owned.

Return:

1. **Status**.
2. **Implementation** — concise result.
3. **Changed files** — file → purpose.
4. **Acceptance criteria** — concise implementation-owned PASS/FAIL evidence.
5. **Focused verification** — exact commands/results.
6. **API/DTO strictness** — all-nine Question/read contract evidence.
7. **Session/stale async** — evidence.
8. **Routing/mobile boundary** — evidence.
9. **Accessibility/responsive** — evidence.
10. **Scope/diff** — non-goals + `git diff --check`.
11. **Delivery handoff** — Project Owner + current Git state.
12. **Deviations/blockers** — exact facts.

Do not output task `Accepted`.

Do not repeat this contract or paste large successful logs.

If the final delivered backend after Backend Phase 2 materially differs from this API contract, or a required routing/UX/security/state decision is unresolved, return `BLOCKED` rather than inventing a new contract.
