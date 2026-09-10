# Codex Implementation Contract: S07-FE-001 — Student Homework Read Foundation

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S07-FE-001` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter typed Student Homework list/detail read layer + Topic section + canonical routing` |
| Depends on | `S07-BE-PHASE-2 = PASS` and delivered Stage 7 backend read contract |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Current review baseline | `origin/main @ 943596fbac4bcac0e0226b5f0650d4843288e8c2` |
| Implementation baseline | ChatGPT re-checks/freezes current `origin/main` immediately before Codex starts |
| Readiness Gate | `PASS — corrected/revalidated`; execution remains blocked until `S07-BE-PHASE-2 = PASS` |
| Supported surfaces | `Student desktop + mobile` |
| Verification | focused frontend tests + format/analyze + diff check |
| Delivery | Project Owner |
| Frontend block checkpoint | Stage 7 Frontend Phase 2 after `S07-FE-001…005` |

Do not start implementation until Stage 7 Backend Phase 2 is `PASS`.

Do not create a duplicate `CODEX-PROMPT`.

---

# 2. Context Boundary

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. current Student Topic domain/data/application/presentation code and tests;
5. current configured Dio/failure infrastructure;
6. current GoRouter path/router/session patterns;
7. current Teacher Homework/Question frontend code only where a local implementation pattern is directly useful;
8. the delivered backend API only through the exact contract reproduced below.

Do not read product docs, roadmap, architecture/database/API docs, Stage history, previous task contracts, closure reviews, or unrelated modules to determine behavior.

This contract resolves:

- exact Student Homework API shapes used by Flutter;
- Student-specific domain models;
- strict DTO parsing;
- repository/data-source boundaries;
- list/detail controller state;
- session/stale completion rules;
- Topic-detail Homework section;
- read-only Homework detail UX;
- canonical nested route;
- direct-entry behavior;
- responsive/accessibility behavior;
- tests and verification.

If current delivered backend responses materially differ from this contract, return `BLOCKED` with exact evidence. Do not redesign either layer.

---

# 3. Goal

Add the Student Homework read foundation on top of the delivered Stage 7 backend:

```text
GET /api/v1/student/homework
GET /api/v1/student/homework/{homework}
```

The Student can:

- see assigned Homework inside an existing currently visible Topic detail;
- refresh/filter/paginate that Topic's Homework list;
- open one Homework detail;
- enter a canonical Homework detail deep-link without requiring a successful
  Student Topic API read/current Group membership;
- see lifecycle/deadline/attempt summary;
- see all nine Question types in the exact safe Student projection;
- see whether an in-progress Attempt exists.

Primary discoverable UI entry for currently visible Topics remains the Topic
detail Homework section. The Homework detail route itself is a standalone
Stage 7 assignment/read boundary because backend Homework authorization is based
on the persisted `assessment_students` snapshot rather than current Topic
membership.

This task is read-only.

No Attempt Start/Resume request is sent in FE-001.

---

# 4. Explicit Non-Goals

Do not implement:

- POST Attempt start/resume;
- Attempt execution screen;
- GET Attempt execution state;
- answer editors;
- answer PUT;
- file upload/download UX;
- final Submit;
- idempotency-key generation;
- score/checking/review UI;
- optimistic lifecycle logic;
- countdown/deadline authority;
- Blitz;
- Parent;
- new dashboard architecture;
- offline cache;
- new HTTP client/state/router;
- new package/dependency;
- platform-file changes;
- broad UI redesign.

`S07-FE-002` owns Attempt start/resume shell.

`S07-FE-003` owns eight non-file answer editors.

`S07-FE-004` owns file-answer UX.

`S07-FE-005` owns final Submit/finalization UX.

---

# 5. Existing Frontend Architecture to Preserve

Current Student flow already follows:

```text
Presentation
-> Riverpod Controller
-> Repository contract
-> Repository implementation
-> Dio data source
-> strict DTO
```

Preserve:

```text
StudentSessionSnapshot / StudentSessionKey
generation-based stale completion rejection
configured dioProvider
DioFailureMapper
ApiRequestException / ApiFailure
GoRouter
Student desktop + mobile eligibility
```

Do not add a parallel cache/client/router/session mechanism.

---

# 6. Backend Read Contract — List

Data source calls:

```text
GET /student/homework
```

Accepted query parameters:

```text
topic_id
status
page
per_page
sort
direction
```

FE-001 Topic section always supplies:

```text
topic_id = current route Topic UUID
```

Supported Student status values:

```text
active
closed
archived
```

Supported sort values:

```text
created_at
title
deadline_at
status
```

Directions:

```text
asc
desc
```

Pagination:

```text
default page = 1
default per_page = 20
max per_page = 100
```

List success:

```json
{
  "data": [
    {
      "id": "homework-uuid",
      "topic": {
        "id": "topic-uuid",
        "title": "Internet Basics"
      },
      "title": "Homework 1",
      "status": "active",
      "deadline_at": "2026-09-10T13:00:00Z",
      "attempts": {
        "allowed": 3,
        "used": 1,
        "remaining": 2,
        "official_score_policy": "highest_valid_completed"
      },
      "my_status": "submitted",
      "score_visible": false
    }
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 20,
      "total": 1,
      "last_page": 1
    }
  }
}
```

No other success keys are accepted.

---

# 7. Backend Read Contract — Detail

Data source calls:

```text
GET /student/homework/{homework}
```

Success envelope:

```json
{
  "data": {
    "id": "homework-uuid",
    "topic": {
      "id": "topic-uuid",
      "title": "Internet Basics"
    },
    "title": "Homework 1",
    "description": "Optional description",
    "student_instructions": "Complete the task.",
    "status": "active",
    "deadline_at": "2026-09-10T13:00:00Z",
    "total_possible_points": 10.0,
    "attempts": {
      "allowed": 3,
      "used": 1,
      "remaining": 2,
      "official_score_policy": "highest_valid_completed",
      "in_progress_attempt": {
        "id": "attempt-uuid",
        "attempt_number": 1,
        "started_at": "2026-09-08T12:00:00Z"
      }
    },
    "my_status": "in_progress",
    "score_visible": false,
    "questions": []
  }
}
```

`in_progress_attempt` may be `null`.

No extra success keys are accepted.

---

# 8. Student Domain Models

Create focused Student-specific models.

Do not reuse Teacher models because Teacher Question domain contains protected correctness configuration.

Create:

```text
frontend/lib/features/student/domain/student_homework.dart
frontend/lib/features/student/domain/student_question.dart
frontend/lib/features/student/domain/student_homework_list.dart
frontend/lib/features/student/domain/student_homework_list_query.dart
frontend/lib/features/student/domain/student_homework_repository.dart
```

---

# 9. Homework ID / Status Domain

In `student_homework.dart` define canonical hyphenated UUID validation consistent with existing Student Topic conventions.

```text
isCanonicalStudentHomeworkId(...)
isCanonicalStudentAttemptId(...)
```

Enums:

```text
StudentHomeworkStatus:
  active
  closed
  archived
```

Do not include `draft`.

Attempt/read status enum:

```text
StudentHomeworkMyStatus:
  notStarted       = not_started
  inProgress       = in_progress
  submitted        = submitted
  waitingForReview = waiting_for_teacher_review
  checked          = checked
```

Do not include `timed_out_finalized` for Homework.

Unknown machine values:

```text
FormatException
```

Do not map unknown values to a generic UI state.

---

# 10. Homework Summary Domain

Define:

```text
StudentHomeworkTopicSummary
StudentHomeworkAttemptSummary
StudentHomeworkSummary
StudentInProgressHomeworkAttempt
StudentHomeworkDetail
```

## `StudentHomeworkTopicSummary`

```text
id
title
```

## `StudentHomeworkAttemptSummary`

List/detail common fields:

```text
allowed
used
remaining
officialScorePolicy
```

Detail-only:

```text
inProgressAttempt?
```

Enforce transport/domain invariants:

```text
allowed == 3
0 <= used <= 3
0 <= remaining <= 3
used + remaining <= 3
officialScorePolicy == highest_valid_completed
```

Also enforce the backend summary consistency:

```text
used == 0
<=> myStatus == not_started

myStatus == in_progress
<=> detail.inProgressAttempt != null

terminal myStatus
(submitted / waiting_for_teacher_review / checked)
=> detail.inProgressAttempt == null
=> used >= 1

detail.inProgressAttempt != null
=> 1 <= attemptNumber <= used
```

For list summaries, where `in_progress_attempt` is intentionally absent, still
enforce:

```text
myStatus == not_started => used == 0
myStatus != not_started => used >= 1
```

Do not locally recompute `remaining`.

The backend is authoritative.

## `StudentInProgressHomeworkAttempt`

```text
id
attemptNumber
startedAt
```

Require:

```text
attemptNumber in 1..3
```

## `StudentHomeworkSummary`

```text
id
topic
title
status
deadlineAt?
attempts
myStatus
scoreVisible
```

## `StudentHomeworkDetail`

```text
id
topic
title
description?
studentInstructions
status
deadlineAt?
totalPossiblePoints
attempts
myStatus
scoreVisible
questions
```

Lists are unmodifiable.

---

# 11. Stage 7 Score Visibility Invariant

Backend FE-001 contract requires:

```text
score_visible = false
```

Strict DTO parsing must reject:

```text
score_visible = true
```

as an invalid Stage 7 success payload.

Do not add score fields to the domain.

Later Stage 9 explicitly changes this boundary.

---

# 12. Student Question Domain

Create a fully separate Student Question domain.

Enum:

```text
StudentQuestionType:
  singleChoice
  multipleChoice
  trueFalse
  shortWritten
  openWritten
  fileBased
  matching
  ordering
  fillInBlank
```

`StudentQuestion`:

```text
id
type
prompt
instructions?
points
position
answerUi
```

Require:

```text
points >= 0
position >= 1
```

No:

```text
checkingMode
configuration
correct answer
```

in the Student domain.

For one Homework detail Question collection require:

```text
Question IDs are unique
Question positions are unique
positions are exactly 1..N
collection order is ascending by position
```

These are transport-integrity checks only; Flutter does not author/reorder
Questions in FE-001.

---

# 13. Student `answer_ui` Domain

Use a sealed/focused typed hierarchy rather than raw `Map`.

Required variants:

```text
StudentChoiceAnswerUi
StudentEmptyAnswerUi
StudentFileAnswerUi
StudentMatchingAnswerUi
StudentOrderingAnswerUi
StudentFillBlankAnswerUi
```

## Choice option

```text
StudentChoiceOption:
  id
  text
```

## Single Choice

```text
StudentChoiceAnswerUi:
  options
  maxSelections = null
```

Require at least two options and unique option IDs.

## Multiple Choice

```text
StudentChoiceAnswerUi:
  options
  maxSelections = required positive int
```

Require at least two options, unique option IDs and:

```text
1 <= maxSelections <= options.length
```

## True / Short / Open

Use:

```text
StudentEmptyAnswerUi
```

and require API object:

```json
{}
```

exactly.

## File

```text
allowedExtensions
maxSizeBytes
```

Require exact extensions:

```text
pdf
docx
ppt
pptx
```

with no duplicates and:

```text
maxSizeBytes > 0
maxSizeBytes <= 15_728_640
```

Do not convert max bytes into an upload rule owned by Flutter; it is display metadata in FE-001.

## Matching

```text
leftItems
rightItems
```

Each:

```text
id
text
```

Require:

- non-empty left/right collections;
- unique IDs inside each side;
- no same ID on both sides.

Do not infer pair correctness from list order.

## Ordering

```text
items:
  id
  text
```

Require a non-empty item collection and unique item IDs.

Do not add an initial/correct position field.

## Fill Blank

```text
blanks:
  id
  key
  position
```

Require:

```text
position >= 1
unique blank IDs
unique keys
unique positions
```

No accepted answers.

---

# 14. Forbidden Student Transport Keys

Student DTO code must never accept Teacher answer-key fields.

At minimum reject any Question/`answer_ui` success payload containing:

```text
is_correct
correct_value
accepted_answers
correct_position
match_key
checking_mode
configuration
client_key
```

Strict exact-key parsing should make these fail automatically.

Do not parse a broad Map and remove these keys afterward.

---

# 15. Student Homework List Query

Create `StudentHomeworkListQuery`.

Fields:

```text
topicId
status?
page
perPage
sort
direction
```

Enums:

```text
StudentHomeworkSort:
  createdAt
  title
  deadlineAt
  status

StudentHomeworkSortDirection:
  asc
  desc
```

Defaults for Topic section:

```text
status = null
page = 1
perPage = 20
sort = createdAt
direction = desc
```

Require canonical Topic UUID.

`toQueryParameters()` emits exact backend machine keys/values.

No search field: backend Student Homework list does not expose search.

---

# 16. List Page Domain

`StudentHomeworkList` contains:

```text
items
page
perPage
total
lastPage
```

Require:

```text
page >= 1
perPage in 1..100
total >= 0
lastPage >= 1
page <= lastPage unless backend's established empty pagination convention explicitly returns otherwise
```

Use the same pagination semantics/pattern already used by Student Topic list.

Do not derive total by `items.length`.

---

# 17. DTO Layer

Create:

```text
frontend/lib/features/student/data/dto/student_homework_dto.dart
frontend/lib/features/student/data/dto/student_homework_list_dto.dart
frontend/lib/features/student/data/dto/student_question_dto.dart
```

Reuse/extend the existing:

```text
student_dto_parse.dart
```

only for genuinely shared strict helpers.

Do not create a second generic parser utility if the existing one owns exact-map/string/int/date parsing.

---

# 18. Strict DTO Parsing

All success DTOs must validate:

- exact required keys;
- no unknown keys;
- exact primitive types;
- canonical UUID syntax;
- strict enum values;
- non-negative numeric constraints;
- timestamp format;
- nested exact-key shapes;
- cross-field invariants from this contract.

Malformed success data maps through the existing data source pattern to:

```text
ApiFailureKind.invalidResponse
```

Do not pass malformed data to application state.

---

# 19. Timestamp Parsing

Backend Stage 7 Homework read timestamps are UTC RFC3339 with literal `Z` and
whole-second precision.

Require exactly:

```text
YYYY-MM-DDTHH:MM:SSZ
```

Conceptual validation regex:

```text
^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$
```

Then parse and validate the represented calendar/time fields as a real UTC
instant.

The current shared Student timestamp helper is more permissive for earlier
Student Topic contracts (for example optional seconds/fractional seconds).
Do **not** reuse that permissive behavior unchanged for FE-001 Homework
timestamps.

Implementation may add one focused exact-whole-second helper to
`student_dto_parse.dart`, but must not silently tighten prior Stage 5 Topic
parsing semantics.

Store as UTC `DateTime`.

Do not accept uncontrolled local timestamp strings as authoritative backend success data.

Presentation converts using the authenticated Institution timezone through existing formatting patterns.

Do not compare device time to deadline for eligibility.

---

# 20. Numeric Parsing

`total_possible_points` and Question `points` may arrive as JSON number.

Parse finite numeric values only.

Reject:

```text
NaN
Infinity
negative values
```

Do not use display-formatted strings as numeric control values.

---

# 21. List DTO Exact Shapes

Summary exact keys:

```text
id
topic
title
status
deadline_at
attempts
my_status
score_visible
```

Topic exact keys:

```text
id
title
```

List attempts exact keys:

```text
allowed
used
remaining
official_score_policy
```

No `in_progress_attempt` in list summary.

Envelope exact keys:

```text
data
meta
```

Meta exact keys:

```text
pagination
```

Pagination exact keys:

```text
page
per_page
total
last_page
```

`StudentHomeworkListDto.fromJson(...)` must receive the exact
`requestedQuery` used for transport and reject a success payload unless:

```text
pagination.page == requestedQuery.page
pagination.per_page == requestedQuery.perPage
every row.topic.id == requestedQuery.topicId
Homework IDs are unique across returned rows
```

The `topic_id` equality check is case-insensitive only after both IDs have
already passed canonical UUID validation.

For pagination also require the same established Student list consistency:

```text
last_page == (total == 0 ? 1 : ceil(total / per_page))
rowCount <= per_page
rowCount <= total
page > last_page is allowed only when rowCount == 0
```

---

# 22. Detail DTO Exact Shapes

Detail exact keys:

```text
id
topic
title
description
student_instructions
status
deadline_at
total_possible_points
attempts
my_status
score_visible
questions
```

Detail attempts exact keys:

```text
allowed
used
remaining
official_score_policy
in_progress_attempt
```

In-progress attempt exact keys when non-null:

```text
id
attempt_number
started_at
```

---

# 23. Question DTO Exact Shapes

Common exact Question keys:

```text
id
type
prompt
instructions
points
position
answer_ui
```

No extra Question keys.

## Single Choice `answer_ui`

Exact:

```text
options
```

Option exact:

```text
id
text
```

Require at least two options and unique option IDs.

## Multiple Choice

Exact:

```text
options
max_selections
```

Require:

```text
options.length >= 2
option IDs unique
1 <= max_selections <= options.length
```

## True / Short / Open

Exact empty object:

```json
{}
```

## File

Exact:

```text
allowed_extensions
max_size_bytes
```

## Matching

Exact:

```text
left_items
right_items
```

Each item exact:

```text
id
text
```

## Ordering

Exact:

```text
items
```

Each item exact:

```text
id
text
```

Require:

```text
items non-empty
item IDs unique
```

## Fill

Exact:

```text
blanks
```

Each blank exact:

```text
id
key
position
```

---

# 24. Data Source

Create:

```text
frontend/lib/features/student/data/student_homework_remote_data_source.dart
```

Provider follows existing Student Topic provider pattern.

Methods:

```text
Future<StudentHomeworkListDto> fetchHomework(
  StudentHomeworkListQuery query,
)

Future<StudentHomeworkDetailDto> fetchHomeworkDetail(
  String homeworkId,
)
```

## List request

```dart
dio.get<Object?>(
  '/student/homework',
  queryParameters: query.toQueryParameters(),
)
```

Require success status:

```text
200
```

Parse with the exact request identity:

```text
StudentHomeworkListDto.fromJson(
  response.data,
  requestedQuery: query,
)
```

so Topic/pagination integrity is validated at the transport boundary.

## Detail request

Validate canonical Homework ID before transport.

Call:

```text
/student/homework/{encodedHomeworkId}
```

with:

```text
followRedirects: false
```

Require:

```text
200
```

Use existing `DioFailureMapper`.

Map DTO `FormatException` to:

```text
ApiFailure.local(kind: invalidResponse)
```

No automatic retry.

---

# 25. Repository

Create:

```text
frontend/lib/features/student/data/student_homework_repository_impl.dart
```

Implement domain contract:

```text
StudentHomeworkRepository
```

Methods:

```text
Future<StudentHomeworkList> fetchHomework(
  StudentHomeworkListQuery query,
)

Future<StudentHomeworkDetail> fetchHomeworkDetail(
  String homeworkId,
)
```

Repository:

- maps DTO to domain;
- owns no UI formatting;
- owns no cache;
- owns no deadline/business decision.

Provider uses current configured data source.

---

# 26. List Application State

Create:

```text
frontend/lib/features/student/application/student_homework_list_state.dart
frontend/lib/features/student/application/student_homework_list_controller.dart
```

Family provider:

```text
studentHomeworkListControllerProvider(topicId)
```

The Topic ID is the controller target identity.

Required status model:

```text
initial
loading
data
empty
refreshing
error
```

State carries:

```text
query
page?
failure?
isStale
```

Use meaningful state rather than unrelated booleans.

---

# 27. List Session / Stale Completion Safety

Mirror the existing Student Topic ownership standard.

Controller must bind every request to:

```text
StudentSessionKey
topicId
generation
query
```

A completion may publish only when all remain current.

Stale completion must not:

- replace a newer page/filter result;
- publish into another Student session;
- publish after logout/session bootstrap;
- publish after route/provider disposal;
- clear newer data;
- show stale failure feedback.

On session-key change:

```text
clear ownership/data
```

and load under the new eligible session only.

---

# 28. List Controller Operations

Required operations:

```text
refresh()
retry()
setStatus(StudentHomeworkStatus?)
previousPage()
nextPage()
```

No search.

Filter change:

```text
page -> 1
```

Then load.

Keep server-authoritative ordering fixed in FE-001:

```text
created_at desc
```

Do not add client-side sort UI in this task.

Pagination buttons use server metadata only.

Use the existing Student Topic one-shot out-of-range page correction semantics.

After a successful list response:

```text
if items are non-empty
or requested page <= 1
or correction already used
=> publish normally

otherwise:
  target =
    total == 0
      ? 1
      : max(1, min(lastPage, requestedPage - 1))

  if target != requestedPage
    => issue exactly one corrected request under the same
       session/topic/generation logical operation
```

The corrected request becomes the current query identity. Stale completion
guards still apply.

Never:

- display an out-of-range empty page as "No Homework assigned" when `total > 0`;
- recurse correction more than once;
- use device/local item counts to invent pagination metadata.

Prevent duplicate same-target in-flight calls where existing controller conventions do so.

---

# 29. List Failure Handling

Session/server codes:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

must follow existing Student controller behavior:

- clear owned state;
- trigger auth bootstrap where existing convention requires it;
- do not retain stale authenticated Student Homework.

Other failure:

- if initial load: error state;
- if refresh with confirmed data: retain data as stale/error according to existing Student retained-data convention.

Do not branch on human error messages.

---

# 30. Detail Route Target

Create:

```text
frontend/lib/features/student/domain/student_homework_route_target.dart
```

or equivalent focused value object.

Fields:

```text
topicId
homeworkId
```

Both canonical UUIDs.

Equality/hashCode must represent both IDs.

This is the route/application target identity for detail controller/widget key.

---

# 31. Detail Application State

Create:

```text
frontend/lib/features/student/application/student_homework_detail_state.dart
frontend/lib/features/student/application/student_homework_detail_controller.dart
```

Family provider keyed by:

```text
StudentHomeworkRouteTarget
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
homework?
failure?
```

---

# 32. Detail Load Integrity

Controller calls repository by:

```text
homeworkId
```

After success require:

```text
returned homework.id == route homeworkId
returned homework.topic.id == route topicId
```

case-insensitive canonical UUID comparison is acceptable.

If backend returns a valid accessible Homework belonging to another Topic than the route hierarchy:

```text
treat route target as unavailable/notFound
```

Do not display it under the wrong Topic route.

Do not invent a second backend authorization call.

---

# 33. Detail Session / Stale Completion Safety

Bind request publication to:

```text
StudentSessionKey
StudentHomeworkRouteTarget
generation
```

A stale completion from:

- old Student;
- old Institution;
- desktop/mobile surface switch;
- old topic/homework target;
- disposed provider;
- earlier refresh;

must not publish.

Follow current Student Topic Detail controller conventions.

---

# 33A. Direct Homework Route Independence

The canonical Homework detail route must be able to load its Homework directly
from:

```text
GET /student/homework/{homeworkId}
```

without requiring a successful:

```text
GET /student/topics/{topicId}
```

request and without using current Topic/Group membership as a frontend
eligibility gate.

This is required for the Stage 7 historical frozen-assignment case:

```text
assessment_students still assigns Student
current group_student_membership ended
Student Topic API may be unavailable
Student Homework API remains authorized
```

Required behavior:

- direct Homework deep-link may render valid Homework detail even if the parent
  Student Topic read would be `404`;
- the Homework detail controller does not call the Topic repository/API as an
  authorization precondition;
- the router/Student destination gate uses only authenticated eligible Student
  session + canonical route syntax;
- returned Homework `topic.id` must still equal the route `topicId`;
- no Stage 5 Topic authorization rule is widened.

The `Back to Topic` action remains the canonical Topic location. If that Topic is
no longer currently visible, the existing Topic unavailable flow may safely
lead the Student back to the Student workspace; this does not invalidate the
already-authorized Homework detail read.

---

# 34. Detail Not Found / Session Failure

Backend:

```text
404 resource_not_found
```

becomes:

```text
StudentHomeworkDetailStatus.notFound
```

Session failures use the same Student session reconciliation behavior as existing Topic Detail.

Do not expose backend raw message/URL.

On authoritative 404, mark the Topic Homework list stale/invalidate its provider so a back-navigation refresh cannot present the removed/inaccessible row as current.

---

# 35. Topic Detail Homework Section

Create:

```text
frontend/lib/features/student/presentation/student_homework_section.dart
```

Modify:

```text
student_topic_detail_screen.dart
```

to render the section after Learning Materials.

The section is independent from the existing Student Topic API `homework: []` placeholder.

Do not modify Student Topic domain to absorb Homework data.

The section owns its own backend list controller:

```text
topic_id = current Topic
```

---

# 36. Homework Section UX

Card key:

```text
studentHomeworkSection
```

Header:

```text
Homework
```

Provide:

```text
Refresh icon/button
Status filter:
  All
  Active
  Closed
  Archived
```

No Create/Edit controls.

No Start/Resume button in FE-001.

No score.

## Loading

Initial:

```text
progress indicator
Loading Homework
```

## Empty

Display clear text:

```text
No Homework is assigned for this Topic.
```

If a status filter is active and result is empty:

```text
No Homework matches this status.
```

## Error

Show safe generic failure UI plus:

```text
Retry
```

## Refreshing

Retain current rows and show a non-blocking linear progress indicator.

## Stale

If retained data is stale, visibly communicate it.

Do not render stale rows as silently current.

---

# 37. Homework Summary Card

Each row/card shows:

```text
title
Homework status
deadline if present
attempts used / 3
remaining attempts
my status
```

Example presentation:

```text
Homework 1
Active
Deadline: Sep 10, 2026, 18:00
Attempts: 1 of 3 used
Remaining: 2
Status: In progress
```

Use backend-provided:

```text
used
remaining
myStatus
```

Do not recompute remaining from device time.

If deadline is already past on the device but backend says remaining > 0 due stale display:

- do not override backend state;
- refresh can reconcile;
- presentation must not claim authoritative eligibility from device clock.

---

# 38. Summary Card Navigation

Whole card or explicit:

```text
Open Homework
```

navigates to canonical:

```text
/student/topics/{topicId}/homework/{homeworkId}
```

Use `AppRoutePaths` helper.

Do not build path strings in the Widget.

Navigation requires current card data only; no mutation.

---

# 39. Canonical Student Homework Route

Modify:

```text
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
```

Add:

```text
AppRouteNames.studentHomeworkDetail
```

Segments/parameters:

```text
studentHomeworkSegment = homework
studentHomeworkIdParameter = homeworkId
```

Canonical route:

```text
/student/topics/:topicId/homework/:homeworkId
```

Nested under existing:

```text
/student/topics/:topicId
```

Add helper:

```text
studentHomeworkDetailLocation(topicId, homeworkId)
```

Validate both canonical UUIDs before constructing.

---

# 40. Route Recognition

Update Student path helpers with non-overlapping route classification.

Exact semantics:

```text
isStudentTopicDetailPath(path)
  = true only for /student/topics/{canonicalTopicId}

isStudentHomeworkDetailPath(path)
  = true only for
    /student/topics/{canonicalTopicId}/homework/{canonicalHomeworkId}

studentTopicIdFromPath(path)
  = Topic ID for exact Topic detail OR exact Homework detail
  = null otherwise

studentHomeworkIdFromPath(path)
  = Homework ID for exact Homework detail
  = null otherwise

isStudentApprovedLocation(path)
  = /student
    OR exact Topic detail
    OR exact Homework detail
```

Do **not** implement `isStudentTopicDetailPath()` merely as:

```text
studentTopicIdFromPath(path) != null
```

after expanding `studentTopicIdFromPath()` to nested Homework paths.

Update router bootstrap location preservation so the exact Student Homework
detail route is preserved on supported desktop/mobile surfaces during session
bootstrap, just like the existing Student Topic detail route.

Do not allow:

```text
extra path segments
new/edit/questions execution aliases
non-canonical IDs
```

---

# 41. Router Screen

Create:

```text
frontend/lib/features/student/presentation/student_homework_detail_screen.dart
```

Router may remain structurally nested under the Student Topic route for canonical
URL composition/navigation, but the Homework child screen/data load must remain
independent of parent Topic API success/current Topic membership.

Construct one target:

```text
StudentHomeworkRouteTarget(
  topicId: route topicId,
  homeworkId: route homeworkId,
)
```

Use a stable `ValueKey<StudentHomeworkRouteTarget>`.

Wrap through existing:

```text
_buildStudentDestination(...)
```

No separate device gate.

Student desktop and mobile are both supported.

---

# 42. Homework Detail Screen — State UX

Scaffold key:

```text
studentHomeworkDetailScreen
```

AppBar title:

```text
Homework
```

Back action:

```text
Back to Topic
```

goes to:

```text
studentTopicDetailLocation(topicId)
```

State handling:

```text
loading
notFound
error
data
refreshing
```

Provide explicit:

```text
Refresh
Retry
Back to Topic
```

where appropriate.

Do not navigate automatically on a normal transport error.

---

# 43. Homework Detail — Read-Only Content

Use scrollable responsive layout.

Recommended max content width:

```text
900
```

matching existing Student Topic detail pattern.

Show:

## Header

```text
title
status chip
my status chip
```

## Homework information

```text
Topic title
description if non-null
student instructions
deadline if non-null
total possible points
```

## Attempt information

```text
Allowed attempts = 3
Used
Remaining
Official score policy label:
  Highest valid completed attempt
```

If backend supplies `in_progress_attempt`, show read-only:

```text
Attempt N in progress
Started: <institution-timezone formatted instant>
```

Do not provide Resume action yet.

If absent, do not create fake Attempt state.

No score display.

---

# 44. Deadline Presentation

Format deadline using authenticated Institution timezone through existing Student formatter approach.

If timezone formatting fails:

```text
fallback safely
```

consistent with Student Topic detail behavior.

Do not:

- calculate `deadline_passed`;
- disable/enable future actions;
- show a countdown;
- infer `remaining=0`.

Backend state is authoritative.

---

# 45. Question Read-Only Section

Homework detail renders:

```text
Questions
```

If no Questions are returned in an otherwise valid payload, show:

```text
No Questions are available.
```

Do not treat this as editable/local authoring error.

For each Question show:

```text
number/position
prompt
instructions if any
points
type label
safe answer structure
```

No input controls in FE-001.

---

# 46. Read-Only Question Presentation

Create:

```text
frontend/lib/features/student/presentation/student_question_read_view.dart
```

or equivalent focused component.

It consumes only Student domain models.

## Single/Multiple Choice

List visible option text.

For Multiple Choice optionally show:

```text
Select up to N when answering.
```

Do not label correct options.

## True / Short / Open

Show a neutral type-specific description:

```text
True / False answer
Short written answer
Written answer
```

No editable field.

## File Based

Show:

```text
Allowed: PDF, DOCX, PPT, PPTX
Maximum file size: <formatted bytes>
```

This is informative only.

## Matching

Show two independent columns/lists:

```text
Left items
Right items
```

Do not visually connect items by array index.

On narrow mobile layout stack sections vertically.

Do not infer pair mapping.

## Ordering

List item text in backend-returned display order.

Do not number them as a claimed correct order.

Use neutral bullet/display order.

## Fill Blank

Show prompt and blank identifiers only as needed for readable structure.

Do not show accepted answers.

---

# 47. Presentation Labels

Create/extend focused:

```text
student_homework_formatters.dart
```

Machine-to-label mapping examples:

Homework:

```text
active -> Active
closed -> Closed
archived -> Archived
```

My status:

```text
not_started -> Not started
in_progress -> In progress
submitted -> Submitted
waiting_for_teacher_review -> Waiting for review
checked -> Checked
```

Question type labels:

```text
single_choice -> Single choice
multiple_choice -> Multiple choice
true_false -> True / False
short_written -> Short answer
open_written -> Written answer
file_based -> File upload
matching -> Matching
ordering -> Ordering
fill_in_blank -> Fill in the blank
```

Do not use labels as machine values.

---

# 48. Accessibility

Required:

- Homework section heading uses semantic header;
- Homework cards have a meaningful navigation semantic label;
- refresh/retry controls have tooltips/labels;
- status is communicated by text, not color alone;
- loading/refresh progress has semantic labels;
- Question prompts are readable in traversal order;
- Matching left/right groups have semantic headings;
- buttons meet existing Material tap targets;
- content remains scrollable with text scaling.

No focus trap.

No interaction requiring hover.

---

# 49. Responsiveness

Support:

```text
AppDeviceSurface.desktop
AppDeviceSurface.mobile
```

Do not add Student authoring desktop-only restrictions.

Homework section cards:

- wrap metadata;
- avoid fixed horizontal widths that overflow mobile.

Homework detail:

- one-column on narrow width;
- Matching may use two columns only when enough width exists;
- otherwise stack.

No horizontal overflow under tested text scaling.

---

# 50. Existing Student Topic Integration

Modify existing Student Topic detail only enough to add:

```text
StudentHomeworkSection(topicId: topic.id)
```

Preserve:

- Topic load/error/refresh;
- learning materials;
- file open/save behavior;
- Topic back navigation.

The Homework section has independent failure state.

A Homework list failure must not make the whole Topic detail unavailable.

A Topic failure means the embedded Homework section is naturally not displayed
because that current Topic content is unavailable.

This does **not** make Topic success/current membership a prerequisite for a
direct canonical Homework detail route that the backend still authorizes from
the frozen assignment snapshot.

---

# 51. Cache / Invalidation

FE-001 introduces no repository cache.

Riverpod controller state owns current read data.

On Homework detail authoritative 404:

```text
invalidate/mark stale the corresponding Topic Homework list provider
```

On ordinary detail refresh success:

do not blindly invalidate list.

No optimistic cross-screen patching.

Later mutation tasks define narrow reconciliation/invalidation after Start/Save/Submit.

---

# 52. Expected Files

## Create

```text
frontend/lib/features/student/domain/student_homework.dart
frontend/lib/features/student/domain/student_question.dart
frontend/lib/features/student/domain/student_homework_list.dart
frontend/lib/features/student/domain/student_homework_list_query.dart
frontend/lib/features/student/domain/student_homework_repository.dart
frontend/lib/features/student/domain/student_homework_route_target.dart

frontend/lib/features/student/data/dto/student_homework_dto.dart
frontend/lib/features/student/data/dto/student_homework_list_dto.dart
frontend/lib/features/student/data/dto/student_question_dto.dart
frontend/lib/features/student/data/student_homework_remote_data_source.dart
frontend/lib/features/student/data/student_homework_repository_impl.dart

frontend/lib/features/student/application/student_homework_list_state.dart
frontend/lib/features/student/application/student_homework_list_controller.dart
frontend/lib/features/student/application/student_homework_detail_state.dart
frontend/lib/features/student/application/student_homework_detail_controller.dart

frontend/lib/features/student/presentation/student_homework_section.dart
frontend/lib/features/student/presentation/student_homework_detail_screen.dart
frontend/lib/features/student/presentation/student_homework_formatters.dart
frontend/lib/features/student/presentation/student_question_read_view.dart

frontend/test/features/student/student_homework_dto_test.dart
frontend/test/features/student/student_homework_data_test.dart
frontend/test/features/student/student_homework_controller_test.dart
frontend/test/features/student/student_homework_screen_test.dart
frontend/test/features/student/student_homework_routing_test.dart
```

## Modify

```text
frontend/lib/features/student/presentation/student_topic_detail_screen.dart
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
```

Modify:

```text
frontend/lib/features/student/data/dto/student_dto_parse.dart
```

only if a genuinely shared strict parse helper is needed.

Update existing Student Topic/router tests only where the intentional Homework section/route changes their assertions.

No backend files.

No dependency/platform/lock files.

---

# 53. DTO Test Requirements

`student_homework_dto_test.dart` must cover all accepted exact payloads plus malformed response rejection.

At minimum:

## Summary/list

- valid active/closed/archived;
- null/non-null deadline;
- exact pagination;
- attempts invariants;
- every allowed `my_status`;
- score_visible false.

Reject:

- draft;
- unknown status;
- unknown my_status;
- score_visible true;
- allowed != 3;
- used/remaining out of range;
- contradictory `used` / `my_status`;
- wrong policy;
- malformed UUID;
- timestamp without whole seconds;
- fractional-second timestamp;
- non-UTC/non-`Z` timestamp;
- unexpected key;
- missing key;
- duplicate Homework IDs in one list page;
- any returned row whose `topic.id` differs from `requestedQuery.topicId`;
- contradictory pagination/request identity.

## Detail

- null/non-null in-progress Attempt;
- `my_status = in_progress` iff `in_progress_attempt != null`;
- terminal/not-started status consistency with used count/in-progress identity;
- in-progress `attempt_number <= used`;
- route-relevant topic ID;
- finite non-negative points;
- exact Question collection;
- duplicate Question IDs;
- duplicate Question positions;
- non-contiguous/non-`1..N` positions;
- Question collection not ordered by ascending position.

---

# 54. Question DTO Test Requirements

Test all nine types.

Verify accepted exact `answer_ui`.

Reject protected/unknown keys:

```text
is_correct
correct_value
accepted_answers
correct_position
match_key
checking_mode
configuration
client_key
```

Verify:

- Single option count >=2 and IDs unique;
- Multiple option count >=2, IDs unique and `max_selections` range;
- true/short/open require `{}`;
- File exact extensions/max bytes;
- Matching side IDs unique/no overlap;
- Ordering item IDs unique and no correct position accepted;
- Fill blank unique ID/key/position.

A protected answer-key-shaped payload must become invalid response, not valid domain data.

---

# 55. Data Source / Repository Tests

`student_homework_data_test.dart` covers:

## List

Exact:

```text
GET /student/homework
```

and query:

```text
topic_id
page
per_page
sort
direction
status only when selected
```

No body.

## Detail

Exact encoded:

```text
GET /student/homework/{id}
```

`followRedirects = false`.

## Failure mapping

Verify Dio structured failures remain typed.

Malformed success JSON becomes:

```text
ApiFailureKind.invalidResponse
```

No raw Map escapes repository.

---

# 56. Controller Tests

`student_homework_controller_test.dart` covers:

## List

- eligible Student auto-load;
- desktop and mobile;
- ineligible session no load;
- status filter resets page;
- pagination uses backend metadata;
- out-of-range empty page performs one bounded correction request;
- correction does not loop and stale prior page completion cannot publish;
- refresh retains data when appropriate;
- failure state;
- session invalidation;
- stale old request cannot overwrite new session;
- stale previous filter/page completion cannot overwrite current query;
- dispose completion ignored.

## Detail

- loading/data;
- refresh;
- 404 => notFound;
- route Topic/Homework mismatch => notFound;
- valid direct Homework detail publishes even when a separately configured
  parent Student Topic repository/API would return `404`;
- session failure clearing/bootstrap behavior;
- stale target/session completion ignored;
- list invalidated/marked stale on authoritative notFound.

Control async completion explicitly.

No arbitrary sleeps.

---

# 57. Widget / Screen Tests

`student_homework_screen_test.dart` covers desktop and mobile.

## Topic Homework section

- loading;
- empty;
- filtered empty;
- data cards;
- status filter;
- pagination;
- refresh;
- error/retry;
- stale/refresh state;
- existing learning material UI remains present.

Update the old assertion that expected:

```text
Homework = findsNothing
```

because Homework is intentionally introduced.

## Summary

Verify displayed backend counts/status.

No Start/Resume button.

No score.

## Detail

- loading/notFound/error/data/refreshing;
- metadata;
- attempt summary;
- in-progress attempt read-only status;
- all nine Question read views;
- no answer input controls;
- no correct-answer labels/data;
- responsive Matching layout without overflow.

---

# 58. Routing Tests

`student_homework_routing_test.dart` must verify:

```text
/student/topics/{topic}/homework/{homework}
```

is canonical.

Test:

- helper constructs correct path;
- invalid Topic/Homework UUID helper throws;
- approved-location matcher accepts exact detail;
- `isStudentTopicDetailPath` is false for Homework detail;
- `isStudentHomeworkDetailPath` is true only for exact Homework detail;
- `studentTopicIdFromPath` works for both Topic detail and Homework detail;
- `studentHomeworkIdFromPath` works only for Homework detail;
- extra segments rejected;
- malformed IDs rejected;
- direct route enters `StudentHomeworkDetailScreen`;
- direct route does not require successful Topic-detail repository/API state;
- historical frozen-assignment direct route remains renderable when Topic read
  would be unavailable;
- Student destination gate applies;
- bootstrap preserves the canonical Homework detail location on desktop/mobile;
- query/fragment is rejected by existing Student redirect behavior;
- wrong/ineligible session falls to existing technical-root behavior;
- back action returns to canonical Topic detail.

Do not create an Attempt route yet.

---

# 59. Directly Affected Regression Tests

Run FE-001 tests plus these exact current-main directly affected regressions:

```text
test/features/student/student_workspace_screen_test.dart
test/features/student/student_query_dto_test.dart
test/router_bootstrap_test.dart
```

Rationale:

- `student_workspace_screen_test.dart` currently owns Student Topic detail
  presentation/Learning Materials and intentionally asserts Homework absent;
- `student_query_dto_test.dart` protects the existing shared Student strict DTO
  helpers if FE-001 adds an exact timestamp helper;
- `router_bootstrap_test.dart` owns Student route classification/bootstrap guards.

Do not substitute nonexistent historical filenames.

Do not run the full frontend test suite in this individual task.

---

# 60. Verification

Run from:

```text
frontend/
```

## 60.1 Focused FE-001 + directly affected regressions

Exactly:

```bash
flutter test \
  test/features/student/student_homework_dto_test.dart \
  test/features/student/student_homework_data_test.dart \
  test/features/student/student_homework_controller_test.dart \
  test/features/student/student_homework_screen_test.dart \
  test/features/student/student_homework_routing_test.dart \
  test/features/student/student_workspace_screen_test.dart \
  test/features/student/student_query_dto_test.dart \
  test/router_bootstrap_test.dart
```

Narrow single-test diagnostic reruns are allowed only to diagnose/confirm a
concrete failure.

## 60.2 Exact Dart format check

Exactly:

```bash
dart format --output=none --set-exit-if-changed \
  lib/features/student/domain/student_homework.dart \
  lib/features/student/domain/student_question.dart \
  lib/features/student/domain/student_homework_list.dart \
  lib/features/student/domain/student_homework_list_query.dart \
  lib/features/student/domain/student_homework_repository.dart \
  lib/features/student/domain/student_homework_route_target.dart \
  lib/features/student/data/dto/student_homework_dto.dart \
  lib/features/student/data/dto/student_homework_list_dto.dart \
  lib/features/student/data/dto/student_question_dto.dart \
  lib/features/student/data/dto/student_dto_parse.dart \
  lib/features/student/data/student_homework_remote_data_source.dart \
  lib/features/student/data/student_homework_repository_impl.dart \
  lib/features/student/application/student_homework_list_state.dart \
  lib/features/student/application/student_homework_list_controller.dart \
  lib/features/student/application/student_homework_detail_state.dart \
  lib/features/student/application/student_homework_detail_controller.dart \
  lib/features/student/presentation/student_homework_section.dart \
  lib/features/student/presentation/student_homework_detail_screen.dart \
  lib/features/student/presentation/student_homework_formatters.dart \
  lib/features/student/presentation/student_question_read_view.dart \
  lib/features/student/presentation/student_topic_detail_screen.dart \
  lib/app/router/app_route_paths.dart \
  lib/app/router/app_router.dart \
  test/features/student/student_homework_dto_test.dart \
  test/features/student/student_homework_data_test.dart \
  test/features/student/student_homework_controller_test.dart \
  test/features/student/student_homework_screen_test.dart \
  test/features/student/student_homework_routing_test.dart \
  test/features/student/student_workspace_screen_test.dart \
  test/features/student/student_query_dto_test.dart \
  test/router_bootstrap_test.dart
```

`student_dto_parse.dart` is included even if no change was ultimately needed;
the check is read-only and protects the shared parser boundary.

## 60.3 Static analysis

Exactly:

```bash
flutter analyze
```

## 60.4 Diff hygiene

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

Those belong to later checkpoints/integration.

---

# 61. Acceptance Criteria

PASS only if all are true.

## Domain / DTO

- Student Homework has separate typed domain;
- Student Question domain never contains Teacher correctness fields;
- list/detail exact backend contracts parse strictly;
- list rows are unique and every returned `topic.id` matches requested
  `topicId`;
- pagination is validated against the exact requested query;
- attempt summary/my-status/in-progress identity cross-fields are coherent;
- Homework timestamps require exact whole-second UTC `Z` format without
  changing prior Topic timestamp semantics;
- Question IDs/positions are unique, exact `1..N`, and returned in ascending
  position order;
- all nine safe Question projections parse with child-ID uniqueness;
- malformed/protected success payload is rejected;
- backend attempts/remaining/status remain authoritative.

## Data

- configured Dio reused;
- exact GET paths/query;
- failure mapping follows existing infrastructure;
- no raw JSON in Widget/application state.

## Application

- list/detail Riverpod controllers are session/target-safe;
- stale completions cannot publish;
- out-of-range empty pagination performs at most one bounded correction;
- independent Homework list failure does not break Topic detail;
- detail hierarchy verifies returned Topic ID;
- direct Homework detail does not require successful Topic API/current Group
  membership.

## Routing

- canonical nested Homework detail route exists;
- Topic-detail and Homework-detail path classifiers are non-overlapping;
- `studentTopicIdFromPath` extracts the Topic from both exact route forms;
- bootstrap preserves canonical Homework deep-link on desktop/mobile;
- direct Homework route is independently loadable from frozen assignment;
- current Student route guards remain;
- no Attempt/execution route added early.

## UI

- Topic detail contains independent Homework section;
- list loading/empty/error/data/refreshing/stale states work;
- read-only Homework detail works on desktop/mobile;
- attempt summary and in-progress identity are displayed;
- no Start/Resume mutation control;
- all nine Questions have safe read-only presentation;
- no score/checking/correct-answer exposure;
- accessibility/responsive rules are met.

## Scope

- no Attempt mutation;
- no answer editor;
- no file transfer UX;
- no Submit;
- no idempotency;
- no scoring/Blitz;
- no dependency/platform/backend change.

## Verification

- exact focused test command passes;
- exact directly affected regressions pass;
- exact Dart format command passes;
- `flutter analyze` passes;
- `git diff --check` passes;
- focused scope/diff review passes.

---

# 62. Locked Implementation Decisions

These are decisions, not suggestions:

```text
Primary current-Topic Homework UI entry = independent section inside Student Topic Detail
canonical detail route = /student/topics/:topicId/homework/:homeworkId
direct Homework detail route = independent of successful Topic API/current membership
historical frozen-assignment deep-link = allowed when backend Homework API authorizes
isStudentTopicDetailPath = exact Topic route only
isStudentHomeworkDetailPath = exact Homework detail route only
Student desktop + mobile = supported
FE-001 = read-only
Start/Resume = FE-002
Student Question domain = separate from Teacher Question domain
raw Teacher configuration = never parsed by Student
list row topic.id = requested topicId
Question IDs/positions = unique; positions exact 1..N ascending
Homework timestamps = exact whole-second UTC Z
server attempts.remaining = authoritative
server my_status = authoritative
out-of-range pagination = one bounded correction using server metadata
device time = presentation only, never eligibility authority
score_visible must be false in Stage 7 FE-001
Homework list ordering in FE-001 = created_at desc
status filter = all|active|closed|archived
no search
no client-side sorting
```

Codex must not substitute:

- embedding Homework into existing Student Topic DTO placeholder;
- making Topic API/current Group membership an authorization prerequisite for
  direct Homework detail;
- broadening `isStudentTopicDetailPath` to match Homework-detail paths;
- accepting list rows from another Topic than the requested Topic;
- silently treating an out-of-range empty page as a genuine empty Homework list;
- reusing the more permissive prior Student timestamp parser unchanged for
  FE-001 Homework timestamps;
- Teacher Question model reuse;
- local deadline eligibility computation;
- optimistic Attempt state;
- Start button that is not wired until FE-002;
- generic JSON configuration parsing;
- a second Router/Dio/state framework.

---

# 63. Completion Report

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
4. strict DTO/topic/pagination/privacy evidence;
5. session/stale-completion + bounded page-correction evidence;
6. routing/direct historical-assignment deep-link evidence;
7. desktop/mobile widget evidence;
8. directly affected regression results;
9. format/analyze results;
10. `git diff --check`;
11. scope/non-goal confirmation;
12. deviations/blockers;
13. final `git status --short`.

Do not claim `Accepted`.

Do not commit/push/create PR/update Stage bookkeeping unless explicitly instructed later.
