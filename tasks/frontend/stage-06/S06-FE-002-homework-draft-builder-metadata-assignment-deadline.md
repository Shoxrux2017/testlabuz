# Codex Implementation Contract: S06-FE-002 — Homework Draft Builder: Metadata, Assignment and Deadline

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S06-FE-002` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter desktop Homework draft create/edit + selected-Student picker + deadline input` |
| Depends on | `S06-FE-001 Accepted / Delivered`; Stage 6 Backend Phase 2 remains `PASS` |
| Planning/readiness baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |
| Backend API dependency | Final delivered S06-BE-003 authoring API after Backend Phase 2 |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` immediately before Codex execution |
| Flutter toolchain | FVM-pinned Flutter `3.44.7` unless current `origin/main` deliberately changes the pin |
| Implementation Readiness Gate | `PASS — planning contract`; execution remains dependency-gated |
| Verification | `Codex — focused frontend verification only` |
| Delivery execution | `Project Owner` |
| Frontend block checkpoint | Stage 6 Frontend Phase 2 after `S06-FE-001…004` are `Accepted / Delivered` |

Do not start implementation until:

```text
Stage 6 Backend Phase 2 = PASS
S06-FE-001 = Accepted / Delivered
current origin/main re-checked
final Teacher Homework API/data models/routes from FE-001 inspected
this contract still matches current implementation
clean synchronized local main
```

If the delivered FE-001 structure or final backend contract materially conflicts with this contract, return `BLOCKED` with the exact mismatch. Do not invent a new UX/API/business contract.

This file is the complete task-specific implementation contract. Do not create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this task contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. delivered `S06-FE-001` implementation and focused tests directly required by this task;
5. final Stage 6 backend Homework authoring routes/resources directly required to confirm the API already encoded below;
6. current Topic create/edit form/controller/router patterns directly required for consistency.

Do not read roadmap/product docs, Stage history, previous task specifications, checkpoint reviews, closure reviews, or unrelated frontend/backend modules to determine requirements.

This contract already resolves:

- create/edit routes;
- desktop/mobile capability boundary;
- metadata fields;
- group vs selected-Student assignment;
- selected-Student picker behavior;
- unresolved selected-recipient display;
- fixed three-attempt presentation;
- optional deadline input;
- timezone conversion;
- create payload;
- PATCH changed-field payload;
- no-op behavior;
- mutation-outcome uncertainty;
- conflict reconciliation;
- dirty-form protection;
- list/detail invalidation;
- local validation;
- accessibility/responsiveness;
- explicit Question-builder exclusion.

---

# 3. Goal

Add production-quality Teacher Homework **draft metadata authoring** on desktop.

The Teacher must be able to:

### Create

- start a new Homework from an authorized Topic;
- enter title;
- optionally enter description;
- enter Student instructions;
- choose whole-group or selected-Student assignment;
- select current eligible Students when using selected assignment;
- optionally set a deadline in the Institution timezone;
- see that normal Homework attempts are fixed at `3`;
- create the Homework as a draft with **zero initial Questions**.

### Edit

- open an existing draft/active Homework metadata editor;
- update only changed metadata/assignment/deadline fields;
- edit selected recipients using the current eligible roster;
- preserve unresolved previously selected recipient IDs without exposing raw UUIDs;
- reconcile authoritative server state after uncertain or lifecycle-conflict outcomes.

This task does **not** build Questions. `S06-FE-003` owns the nine-type Question Builder.

---

# 4. Scope

## 4.1 Included

Implement:

- desktop Homework create route/screen;
- desktop Homework edit route/screen;
- working `Create Homework` action from Topic Homework section;
- working `Edit` action from Homework detail;
- Homework mutation request/domain types;
- create/update repository methods;
- mutation DTO strict parsing;
- mutation-outcome-unknown classification;
- create controller/state;
- edit controller/state;
- Homework metadata form model/snapshot;
- assignment mode controls;
- selected-Student multi-select picker;
- roster query/controller state needed by the picker;
- optional Institution-timezone deadline picker;
- fixed attempt-policy read-only callout;
- dirty-form navigation protection;
- server validation field mapping;
- lifecycle/business-conflict reconciliation;
- narrow Homework list/detail invalidation/authoritative refresh integration;
- mobile authoring redirects;
- focused tests and directly affected FE-001 regressions.

## 4.2 Explicit non-goals

Do not implement:

- Question add/edit/delete/reorder UI;
- Question type selector;
- Question configuration editor;
- nested Question data on Homework create other than exact `questions: []`;
- Homework lifecycle activate/close/archive UI;
- official Homework designation;
- result-pair client;
- Student Attempt UI;
- checking/scoring;
- Blitz;
- Student/Parent result UI;
- mobile Homework authoring;
- mobile selected-Student picker;
- changing Topic;
- changing Teacher/Institution;
- editable attempt count;
- current-device timezone authority;
- deadline “must be future” local business enforcement;
- auto-activation after create;
- optimistic mutation success;
- automatic mutation replay;
- offline storage;
- new packages;
- new router/state-management/network architecture;
- backend changes;
- full frontend suite/build/E2E.

No dead/disabled Question or lifecycle controls should be added in this task. S06-FE-003/004 will add working controls when their implementation exists.

---

# 5. Dependency Contract from S06-FE-001

This task expects delivered FE-001 to provide equivalent boundaries for:

```text
TeacherHomework
TeacherHomeworkSummary
TeacherHomeworkStatus
TeacherHomeworkAssignmentMode
TeacherHomeworkRepository
TeacherHomeworkRemoteDataSource
TeacherGroupStudent
TeacherGroupStudentRepository
TeacherGroupStudentList
TeacherGroupStudentListQuery
teacherHomeworkListControllerProvider(topicId)
teacherHomeworkDetailControllerProvider(target)
TeacherHomeworkRouteTarget
TeacherHomeworkSection
TeacherHomeworkDetailScreen
AppRoutePaths.teacherHomeworkDetailLocation(...)
```

If names differ, adapt local wiring while preserving behavior.

Do not duplicate the FE-001 Homework/Question DTO hierarchy.

---

# 6. Backend Mutation API Contract

Use configured Dio base `/api/v1`.

## 6.1 Create

```text
POST /teacher/topics/{topicId}/homework
```

Success:

```text
201 Created
```

Exact success message:

```text
Homework created successfully.
```

Response contains the full authoritative Homework resource plus `message`.

## 6.2 Update

```text
PATCH /teacher/homework/{homeworkId}
```

Success:

```text
200 OK
```

Exact success message:

```text
Homework updated successfully.
```

Response contains the full authoritative Homework resource plus `message`.

Do not call Question mutation endpoints in this task.

---

# 7. Create Route

Add canonical route:

```text
/teacher/topics/{topicId}/homework/new
```

Recommended constants:

```text
teacherHomeworkCreateSegment = new
teacherHomeworkCreate
teacherHomeworkCreateLocation(topicId)
isTeacherHomeworkCreatePath(path)
```

Recommended route name:

```text
teacherHomeworkCreate
```

Nest under the existing Topic detail route alongside Homework detail.

Register static `new` before dynamic Homework ID resolution so it cannot be treated as a UUID.

Builder:

```text
TeacherHomeworkCreateScreen(topicId: ...)
```

Use:

```text
_buildTeacherDestination(
  ...,
  authoring: true,
)
```

Therefore desktop only.

---

# 8. Edit Route

Add canonical route:

```text
/teacher/topics/{topicId}/homework/{homeworkId}/edit
```

Recommended constants:

```text
teacherHomeworkEditSegment = edit
teacherHomeworkEdit
teacherHomeworkEditLocation(topicId, homeworkId)
isTeacherHomeworkEditPath(path)
```

Recommended route name:

```text
teacherHomeworkEdit
```

Builder:

```text
TeacherHomeworkEditScreen(
  topicId: ...,
  homeworkId: ...,
)
```

Use:

```text
authoring: true
```

Desktop only.

---

# 9. Mobile Route Behavior

Authenticated Teacher + mobile:

```text
/teacher/topics/<topic>/homework/new
  -> /teacher/topics/<topic>

/teacher/topics/<topic>/homework/<homework>/edit
  -> /teacher/topics/<topic>/homework/<homework>
```

Do not transiently render desktop form content before redirect.

During auth bootstrap, preserve only routes supported by the current surface:

- Homework detail can remain on mobile;
- Homework create/edit authoring routes must normalize to supported read locations.

Desktop behavior remains:

```text
create -> allowed
edit   -> allowed
detail -> allowed
```

Invalid UUID/extra-segment/query/fragment still resolves safely through existing Teacher router policy.

---

# 10. Topic Detail Create Entry

Extend FE-001 `TeacherHomeworkSection`.

On **desktop only**, render a working:

```text
Create Homework
```

control only when confirmed Topic status is:

```text
draft
active
```

Do not render it for:

```text
closed
archived
```

This is a UX capability hint only; backend remains authoritative.

The control navigates to:

```text
teacherHomeworkCreateLocation(topic.id)
```

Do not show this control on mobile.

Do not add a create control when Topic detail itself is loading/error/notFound/stale without confirmed Topic.

---

# 11. Homework Detail Edit Entry

Extend FE-001 `TeacherHomeworkDetailScreen`.

On desktop, render a working:

```text
Edit
```

control when confirmed Homework status is:

```text
draft
active
```

Do not render Edit for:

```text
closed
archived
```

Active Homework is intentionally editable because:

- title/description may remain safe after Student activity;
- some fairness-relevant fields may be server-locked after activity;
- FE-001 resource does not expose Attempt existence as client authority.

Backend rejection/reconciliation is the authority.

No Edit control on mobile.

---

# 12. Homework Form Value

Create a controlled immutable value equivalent to:

```text
TeacherHomeworkFormValue
```

Fields:

```text
title: String
description: String
studentInstructions: String
assignmentMode: TeacherHomeworkAssignmentMode
selectedStudentIds: Set<String>
deadlineWallClock: InstitutionWallClock?
```

Default create value:

```text
title = ''
description = ''
studentInstructions = ''
assignmentMode = group
selectedStudentIds = {}
deadlineWallClock = null
```

No Question state in this form.

No attempt-count state.

---

# 13. Homework Form Field Enum

Create equivalent:

```text
TeacherHomeworkFormField
```

Exact request mapping:

```text
title                -> title
description          -> description
studentInstructions  -> student_instructions
assignmentMode       -> assignment_mode
studentIds           -> student_ids
deadlineAt           -> deadline_at
```

Use this enum for:

- local field errors;
- server `422` mapping;
- first-invalid focus.

Do not add:

```text
questions
attemptLimit
status
```

as editable form fields.

---

# 14. Local Validation

Local validation improves UX but does not replace backend authority.

## 14.1 Title

On submit:

```text
trim
required
1..255 chars after trim
```

Request sends trimmed value.

## 14.2 Description

Optional.

Rules:

```text
max 10000 characters
```

Normalization:

- exact empty string `''` -> JSON `null`;
- any non-empty String is preserved **verbatim**;
- do not trim non-empty description;
- whitespace-only non-empty description is not silently rewritten.

This matches the backend's optional nullable description contract.

## 14.3 Student instructions

On submit:

```text
trim
required
1..10000 chars after trim
```

Request sends trimmed value.

## 14.4 Assignment mode

Must be exactly:

```text
group
selected_students
```

## 14.5 Selected students

For:

```text
group
```

resulting selected set must be empty.

For:

```text
selected_students
```

require:

```text
selectedStudentIds.isNotEmpty
```

Every stored ID must be canonical UUID.

Do not locally infer current eligibility beyond the roster data returned by the backend.

## 14.6 Deadline

Optional.

If non-null:

- Institution timezone must resolve through existing `InstitutionTimezone`;
- local wall clock must be a valid real wall-clock instant for that IANA zone;
- DST gap/nonexistent time -> local field error;
- serialize with explicit numeric offset using existing helper.

Do **not** reject a past deadline locally.

Draft backend contract intentionally allows past deadlines; activation later enforces future time.

---

# 15. Fixed Attempt Policy UX

Both Create and Edit screens show a non-editable information card:

```text
Homework attempts
Normal attempts: 3
The attempt limit cannot be changed.
```

On Edit, use the actual `TeacherHomework.attemptPolicy.normalAttempts` value already strictly parsed as `3`.

On Create, the UI may render literal product contract value `3`, but it is display-only and must not enter the request body.

Do not render:

- text field;
- slider;
- dropdown;
- admin override;
- hidden request value.

---

# 16. Deadline Form Contract

Reuse:

```text
frontend/lib/core/time/institution_timezone.dart
```

Do not add a second timezone dependency/helper.

## 16.1 Create initial value

```text
null
```

No default deadline is invented.

## 16.2 Edit initial value

Convert authoritative:

```text
homework.deadlineAt UTC
```

into current authenticated Institution timezone:

```text
InstitutionTimezone.instantToWallClock(...)
```

If current Institution timezone cannot resolve:

- do not guess;
- editor enters an unavailable/review state;
- do not send mutation.

## 16.3 Date/time picker

Reuse Flutter built-in:

```text
showDatePicker
showTimePicker
```

A reasonable selectable calendar range consistent with Topic authoring is:

```text
2000..2100
```

This range is UI affordance only.

No “today or later” restriction.

## 16.4 Serialization

Use:

```text
InstitutionTimezone.serializeWallClock(...)
```

Expected:

```text
YYYY-MM-DDTHH:mm:ss±HH:mm
```

No device timezone.

## 16.5 No-op comparison

For Edit, deadline equality is based on the **absolute instant**, not wall-clock textual identity.

Algorithm:

1. convert draft wall clock through current Institution timezone;
2. obtain UTC instant;
3. compare to initial authoritative `deadlineAt.toUtc()`.

If same instant:

```text
no deadline_at PATCH field
```

This prevents a timezone-display conversion from causing a false mutation.

---

# 17. Selected-Student Picker — Purpose

Implement one reusable desktop multi-select dialog/panel for current eligible Students of the Topic Group.

Use FE-001:

```text
TeacherGroupStudentRepository
GET /teacher/groups/{groupId}/students
```

Do not call Institution Admin endpoints.

The picker is used by:

- Homework Create;
- Homework Edit.

---

# 18. Selected-Student Picker State

Create a focused autoDispose family/application boundary equivalent to:

```text
TeacherHomeworkStudentPickerController
TeacherHomeworkStudentPickerState
TeacherHomeworkStudentPickerTarget
```

Target must include at least:

```text
groupId
initialSelectedIds
session identity ownership handled by controller
```

Prefer target/value equality rather than hidden static state.

State owns:

```text
query
searchDraft
result
failure
selectedIds
resolvedStudentsById
```

`resolvedStudentsById` contains only names returned by the current/previous successful roster pages in this picker session.

Do not create a global Student cache.

---

# 19. Picker Query Behavior

Use FE-001 roster query contract:

```text
search
page
perPage
```

UI defaults:

```text
search = null
page = 1
perPage = 50
```

Search:

- max 100;
- trim on explicit commit;
- empty -> null;
- Enter/Search button commits;
- changing search resets page = 1.

Pagination:

- Previous/Next;
- preserve selected IDs across pages/searches.

Do not remove a selection merely because the selected Student is not on the current page.

Older search/page responses must not overwrite current picker query/selection state.

---

# 20. Picker Selection Semantics

Selection set uses canonical Student UUIDs internally.

## 20.1 Loaded roster item

Each row shows:

```text
fullName
loginName
checkbox
```

Toggling updates the selected ID set.

## 20.2 Selected ID not currently resolved to a name

This case is valid on Edit because Homework detail returns persisted selected IDs while roster endpoint returns only **currently eligible** Students and current page/search.

Do not show raw UUID.

Render a selected placeholder entry:

```text
Selected student N
Name not loaded in the current eligible roster view.
```

with:

```text
Remove
```

The internal UUID remains associated with that placeholder.

If a later roster page returns that ID, replace the placeholder label with the actual Student name/login.

Do not label an unresolved ID as definitively “ineligible” merely because it has not been loaded.

## 20.3 Unresolved retention

Keeping an unresolved selected ID is allowed in the draft UI.

Backend validation remains authoritative.

If submit returns:

```text
422 validation_failed
errors.student_ids
```

the UI tells the Teacher:

```text
Review the selected Students. One or more selections may no longer be eligible.
```

and returns focus to the assignment/picker control.

## 20.4 Deterministic request order

When serializing selected IDs:

```text
sort UUID strings ascending
```

Backend treats recipients as a set; deterministic payload simplifies no-op/reconciliation.

---

# 21. Picker Dialog UX

Recommended dialog key:

```text
teacherHomeworkStudentPickerDialog
```

Header:

```text
Choose Students
```

Elements:

- Search field;
- loaded roster list;
- selected count;
- unresolved selected entries;
- pagination;
- Retry;
- Cancel;
- Apply selection.

`Cancel`:

- closes without changing parent form selection.

`Apply selection`:

- returns complete selected ID set to parent form.

For create/edit selected mode, parent form remains invalid if result set empty.

Keyboard:

- Enter commits search when focus is in search;
- Escape closes dialog when no blocking async operation;
- focus order follows visual order.

Do not close dialog on stale async completion.

---

# 22. Create Request Domain

Extend/create mutation domain equivalent to:

```text
TeacherHomeworkCreateRequest
```

Fields:

```text
title
description
studentInstructions
assignmentMode
studentIds
deadlineAtSerialized
questions
```

`questions` is fixed in FE-002:

```text
[]
```

and is not exposed in the form.

Exact `toJson()` keys:

```json
{
  "title": "...",
  "description": null,
  "student_instructions": "...",
  "assignment_mode": "group",
  "student_ids": [],
  "deadline_at": null,
  "questions": []
}
```

Always send all seven keys for deterministic create payload.

Never send:

```text
attempt_limit
status
total_possible_points
institution_id
teacher_id
topic_id
```

---

# 23. Edit Snapshot

Create immutable:

```text
TeacherHomeworkEditSnapshot
```

from authoritative `TeacherHomework`.

Store comparable initial values:

```text
title
description
studentInstructions
assignmentMode
selectedStudentIds
deadlineAtUtc
```

Do not store display-formatted strings as authoritative comparison state.

Do not include Questions in FE-002 snapshot.

---

# 24. Edit Request Domain

Create:

```text
TeacherHomeworkEditRequest
```

as a partial PATCH request.

Allowed serialized keys only:

```text
title
description
student_instructions
assignment_mode
student_ids
deadline_at
```

`isEmpty` required.

## 24.1 Common changed fields

Include only semantic changes.

- title compare canonical trimmed request value;
- description compare exact nullable value;
- Student instructions compare canonical trimmed request value;
- deadline compare absolute UTC instant.

## 24.2 Assignment transition rules

### group -> group

No `student_ids`.

### selected -> selected

If selected set changed:

```text
student_ids = sorted resulting selected IDs
```

If unchanged:

```text
omit student_ids
```

### group -> selected_students

Include both:

```text
assignment_mode = selected_students
student_ids = sorted non-empty set
```

### selected_students -> group

Include both:

```text
assignment_mode = group
student_ids = []
```

This ensures backend resulting state is unambiguous.

## 24.3 No Questions

Never include:

```text
questions
```

in PATCH.

---

# 25. Edit Request `matches(current)` Contract

For uncertain-mutation reconciliation implement:

```text
TeacherHomeworkEditRequest.matches(TeacherHomework current)
```

Compare only fields present in the request.

Rules:

- title exact canonical String;
- description exact nullable String;
- Student instructions exact canonical String;
- assignment mode exact enum;
- `student_ids` compare as sets;
- deadline compare UTC instant/null.

Do not compare:

- Questions;
- status;
- total points;
- lifecycle timestamps;
- updatedAt;
- attempt policy.

A backend-authoritative change outside the intended PATCH does not prove the PATCH failed.

---

# 26. Mutation Success DTO

Create/reuse an operation DTO that accepts exactly:

```text
data
message
```

`data` is parsed through the strict FE-001 full Homework DTO.

Create expected message:

```text
Homework created successfully.
```

Update expected message:

```text
Homework updated successfully.
```

Missing/extra/malformed success envelope -> mutation outcome unknown, not confirmed success.

Do not trust status code alone.

---

# 27. Mutation Outcome Unknown Contract

Create:

```text
TeacherHomeworkMutationOutcomeUnknownException
```

or equivalent.

A mutation outcome is **unknown** when the client cannot prove whether the backend committed, including:

- connection drop after request may have reached server;
- timeout without a definite recognized response;
- malformed/unexpected success body;
- unexpected status/error envelope not classified as a definite failure;
- local parsing error after a 2xx mutation response.

Do not automatically replay POST/PATCH.

Automatic replay can create duplicate create attempts or overwrite newer state.

---

# 28. Definite Mutation Failure Classification

Only an exact recognized error envelope is a definite failure.

Use current strict error-envelope parser pattern.

## 28.1 Common definite errors

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

## 28.2 Create-specific 409

Recognize:

```text
409 topic_not_editable
```

as definite create failure.

## 28.3 Update-specific 409

Recognize exactly:

```text
409 topic_not_editable
409 task_closed
409 task_archived
409 business_conflict
409 official_task_requires_group_assignment
```

as definite update failure.

If final backend adds a specifically documented Stage 6 update code during Backend Phase 2, ChatGPT must reconcile this contract before implementation; Codex must not broaden “all 409 are definite” independently.

For definite validation failure, `errors` may contain fields.

For non-validation definite errors, require:

```text
errors = {}
```

consistent with project envelope policy.

---

# 29. Repository Extension

Extend FE-001 `TeacherHomeworkRepository`.

Add:

```text
Future<TeacherHomework> createHomework(
  String topicId,
  TeacherHomeworkCreateRequest request,
)

Future<TeacherHomework> updateHomework(
  String homeworkId,
  TeacherHomeworkEditRequest request,
)
```

Do not create a second mutation-only repository.

Keep roster repository separate.

---

# 30. Remote Data Source Mutation Methods

Extend FE-001 `TeacherHomeworkRemoteDataSource`.

## 30.1 Create

Validate canonical Topic ID.

Request:

```text
POST /teacher/topics/{encodedTopicId}/homework
```

Body:

```text
request.toJson()
```

Options:

```text
followRedirects = false
```

Require:

```text
201 + exact success envelope/message
```

## 30.2 Update

Validate canonical Homework ID.

Reject local empty request before transport.

Request:

```text
PATCH /teacher/homework/{encodedHomeworkId}
```

Require:

```text
200 + exact success envelope/message
```

## 30.3 Unknown/definite semantics

Use the mutation uncertainty contract above.

Do not reuse GET read mapping blindly because mutation ambiguity differs from read failure semantics.

Do not add generic automatic retries.

---

# 31. Create Controller Ownership

Create autoDispose:

```text
TeacherHomeworkCreateController
TeacherHomeworkCreateState
```

keyed by:

```text
topicId
```

Ownership:

```text
TeacherSessionKey
topicId
routeGeneration
operationGeneration
activeRequest identity
```

Desktop only.

The controller also observes/uses the existing Topic detail state for the same `topicId`.

---

# 32. Create Initial Topic Gate

Before showing editable create form, require confirmed Topic detail.

States:

```text
loading
unavailable/notFound
initialLoadError
editing
```

If Topic is:

```text
closed
archived
```

show a review/unavailable state:

```text
Homework cannot be created for this Topic.
```

with:

```text
Back to Topic
```

Do not render an editable form.

If Topic is draft/active, form is editable.

Backend remains final authority if Topic changes concurrently.

---

# 33. Create Submit Flow

Required:

1. validate current session/desktop/route ownership;
2. local validate form;
3. build canonical create request;
4. prevent duplicate submit;
5. enter submitting;
6. call repository create;
7. handle confirmed success, definite failure, or unknown outcome.

## 33.1 Confirmed success

On confirmed full Homework response:

- invalidate/refresh topic-scoped Homework list state;
- ensure no stale old list is treated authoritative;
- leave create route ownership;
- show success feedback;
- navigate to:

```text
teacherHomeworkDetailLocation(topicId, created.id)
```

Do not auto-activate.

Do not open Question Builder automatically in FE-002.

S06-FE-003 may later add an explicit “Edit Questions” action on detail/editor.

## 33.2 Unknown create outcome

Do not automatically retry.

Show blocking review state:

```text
Creation outcome unknown
The Homework creation request may have succeeded.
Review this Topic's Homework before creating another Homework.
```

Action:

```text
Review Homework
```

Behavior:

- mark/invalidate Topic Homework list;
- leave route;
- navigate to Topic detail;
- do not fabricate an ID;
- do not assume failure.

A second create submit is disabled while in unknown state.

---

# 34. Create Definite Failure UX

## 34.1 `422 validation_failed`

Map known fields:

```text
title
description
student_instructions
assignment_mode
student_ids
deadline_at
```

to concise local field errors.

If backend returns validation key:

```text
questions
```

despite FE-002 always sending `[]`, treat as form-level backend rejection:

```text
The Homework could not be created.
```

Do not invent a Question form field.

Unknown validation key -> form-level failure.

## 34.2 `404 resource_not_found`

Topic/current scope is unavailable.

Show:

```text
This Topic is no longer available in your current Teacher workspace.
```

Clear/create route editing ownership appropriately.

## 34.3 `409 topic_not_editable`

Fetch/refresh Topic detail once if current controller can safely do so, then show:

```text
This Topic is no longer editable. Review its current server state.
```

Do not replay create.

## 34.4 Other definite

Use safe UX:

- forbidden;
- rate limited;
- generic failure.

No raw backend messages.

---

# 35. Edit Controller Ownership

Create autoDispose family:

```text
TeacherHomeworkEditController
TeacherHomeworkEditState
```

keyed by:

```text
TeacherHomeworkRouteTarget(topicId, homeworkId)
```

Ownership:

```text
TeacherSessionKey
route target
routeGeneration
operationGeneration
activeRequest identity
```

Desktop only.

Observe/reuse FE-001 Homework detail controller for the same target.

---

# 36. Edit Initialization

From confirmed `TeacherHomework`:

Require:

```text
homework.topicId == route.topicId
```

already guaranteed by FE-001 detail controller.

If status:

```text
closed
archived
```

show review state:

```text
This Homework is no longer editable.
```

Do not render editable form.

For:

```text
draft
active
```

build:

```text
TeacherHomeworkFormValue.fromHomework(...)
TeacherHomeworkEditSnapshot.fromHomework(...)
```

using current Institution timezone for deadline wall-clock.

If timezone unavailable:

```text
unavailable/review
```

and no mutation.

---

# 37. Edit Dirty State

`canSave` only when:

- route/session valid;
- not busy/review-only;
- form locally valid enough to evaluate;
- resulting semantic PATCH is non-empty.

If user presses Save with no changes:

```text
No changes to save.
```

Do not issue PATCH.

Dirty status is derived from `TeacherHomeworkEditRequest.fromForm(...).isEmpty`.

Do not maintain a competing manually toggled dirty boolean as authority.

---

# 38. Dirty Navigation Protection

Create and Edit screens use deterministic route ownership.

## Create

If form remains pristine:

- Back/Cancel leaves immediately.

If any user-entered field/assignment/deadline differs from default:

- Back/Cancel/browser back shows discard confirmation.

## Edit

If resulting PATCH is non-empty:

- Back/Cancel shows:

```text
Discard unsaved changes?
```

Actions:

```text
Keep editing
Discard
```

When submitting/reconciling/unknown:

- block accidental pop where leaving would hide unresolved mutation state.

Do not block app/session redirect when authentication becomes invalid.

Escape may close sub-dialogs first; main dirty form discard still requires confirmation.

---

# 39. Edit Submit Flow

Required:

1. validate current route/session;
2. local validate;
3. build changed-field PATCH;
4. if empty -> no request;
5. submit exactly once;
6. confirmed success -> accept authoritative resource;
7. unknown -> GET reconcile;
8. definite state conflict -> authoritative GET reconcile/review;
9. no automatic mutation replay.

---

# 40. Edit Confirmed Success

On confirmed full Homework response:

- update FE-001 Homework detail controller with authoritative Homework;
- invalidate/refresh Topic Homework list;
- update form/snapshot to returned authoritative state;
- clear dirty/pending request;
- show:
  `Homework updated successfully.`;
- remain on Edit screen **or** return to detail?

Approved behavior:

```text
return to Homework detail after confirmed success
```

Reason:

- FE-002 edit is a focused metadata operation;
- the next-stage Question Builder is separate;
- authoritative read detail is the stable post-mutation surface.

Navigate to:

```text
teacherHomeworkDetailLocation(topicId, homeworkId)
```

Do not rely on browser pop to an arbitrary prior route.

---

# 41. Edit Unknown Outcome Reconciliation

On `TeacherHomeworkMutationOutcomeUnknownException` or unexpected local exception after transport may have committed:

1. enter `reconciling`;
2. GET current Homework detail through repository;
3. verify route Topic ID;
4. publish authoritative current Homework into FE-001 detail controller;
5. compare pending request through:
   `request.matches(current)`.

If match:

```text
treat as confirmed success
```

and navigate to detail.

If current resource is available but does not match:

```text
unconfirmedCurrentState
```

Show:

```text
The update result could not be confirmed.
Review the current server state before trying again.
```

Display current server values and preserve attempted draft for comparison/review.

No automatic replay.

If GET itself fails/uncertain:

```text
outcomeUnknown
```

Show:

```text
Check current Homework
```

which explicitly reruns the GET reconciliation.

---

# 42. Definite Update Conflict Reconciliation

For exact recognized:

```text
409 topic_not_editable
409 task_closed
409 task_archived
409 business_conflict
409 official_task_requires_group_assignment
```

the PATCH is a definite non-commit.

Still perform one authoritative Homework GET when route/session remain valid because the conflict commonly means local editability assumptions are stale.

After GET:

- publish current authoritative detail;
- preserve attempted draft in review state;
- do not call `request.matches()` to convert the definite 409 into success;
- explain the stable category without parsing backend message.

Mappings:

## `task_closed`

```text
This Homework is closed and cannot be edited.
```

## `task_archived`

```text
This Homework is archived and cannot be edited.
```

## `topic_not_editable`

```text
The Topic is no longer editable.
```

## `business_conflict`

```text
Some Homework settings are locked by current server state.
Review the current Homework before making another change.
```

This is the expected UI when Student activity has locked assignment/instructions/deadline.

## `official_task_requires_group_assignment`

```text
The official Homework must remain assigned to the whole group.
```

Restore/present current authoritative assignment after reconciliation.

Do not infer “has attempts” from the code; backend intentionally returns generic `business_conflict`.

---

# 43. Edit Validation Failure

For `422 validation_failed`:

Map known request fields.

Special `student_ids` mapping:

```text
Review the selected Students. One or more selections may no longer be eligible.
```

Keep form values.

Do not automatically clear current selected IDs.

Teacher explicitly chooses what to remove.

Deadline validation:

```text
Review the Homework deadline and Institution timezone.
```

Focus the first mapped field after frame.

Unknown validation key -> safe form-level error.

---

# 44. 404 During Edit/Reconcile

Exact:

```text
404 resource_not_found
```

means Homework is no longer available in current scope.

- mark FE-001 detail controller `notFound`;
- invalidate Homework list for Topic;
- show unavailable review state;
- navigation action:
  `Back to Topic`.

Do not reveal whether it was deleted, moved, foreign, or membership was lost.

---

# 45. Assignment Control UX

Form section:

```text
Assignment
```

Use radio/segmented controls equivalent to:

```text
Whole group
Selected students
```

Machine enum stays in domain.

## Whole group

Show:

```text
All eligible Students in the Topic Group will be snapshotted by the backend when the Homework is activated.
```

Do not fetch roster just to show a count.

Changing to Whole group:

- form selected IDs becomes empty **only after user explicitly changes the mode**;
- Edit dirty state reflects the resulting clear.

## Selected students

Show:

- selected count;
- button:
  `Choose Students`;
- picker error when no selection;
- current selected Student chips/summary where names are resolved.

Do not silently drop selected IDs when switching modes and then switching back within the same editing session?

Approved UX:

- when user changes `selected_students -> group`, keep a **transient remembered selected set** inside UI state for convenience;
- authoritative `form.selectedStudentIds` used for request becomes empty in group mode;
- if user switches back to selected before submit, restore the remembered set;
- this remembered set is UI-only and is cleared/reinitialized after authoritative success/reload.

This avoids accidental loss during mode exploration while preserving exact group request semantics.

Do not persist this remembered set outside the form/controller.

---

# 46. Selected Student Summary Outside Picker

For selected mode, show:

```text
N Students selected
```

Optionally list a small set of resolved names in chips when available.

Never display raw UUIDs.

Unresolved IDs may be represented as:

```text
Selected student N
```

with no claim about eligibility.

The full editable selection belongs in the picker.

---

# 47. Create/Edit Screen Layout

Use one focused reusable field widget where it genuinely avoids duplication, for example:

```text
TeacherHomeworkMetadataFields
```

but keep controllers/state separate.

Recommended max width:

```text
800–900 logical px
```

Sections:

1. Topic context
2. Homework information
3. Assignment
4. Deadline
5. Attempt policy
6. actions

## Topic context

Read-only:

```text
Topic title
Group name
Topic status
```

Do not let Teacher change Topic/Group from Homework form.

## Homework information

Fields:

```text
Title
Description
Student instructions
```

## Assignment

As above.

## Deadline

Read-only Institution timezone label + optional picker/clear.

## Attempt policy

Fixed read-only.

---

# 48. Create Screen UX

Screen key:

```text
teacherHomeworkCreateScreen
```

App bar:

```text
Create Homework
```

Submit label:

```text
Create draft Homework
```

Cancel returns to Topic detail.

During submit/reconcile:

- disable editable controls;
- show progress semantics;
- prevent duplicate submit.

Unknown create state replaces the form with a clear review panel; do not permit another create in that route instance.

Create request always has:

```text
questions: []
```

The screen should explicitly state:

```text
Questions can be added after the draft is created.
```

No fake Question editor.

---

# 49. Edit Screen UX

Screen key:

```text
teacherHomeworkEditScreen
```

App bar:

```text
Edit Homework
```

Show status chip:

```text
Draft / Active
```

Submit:

```text
Save changes
```

Cancel/back goes to Homework detail.

For active Homework add a neutral informational note:

```text
Some assignment, instruction, or deadline changes may be locked after Student activity begins. The server will confirm what is still editable.
```

Do not claim activity exists.

Do not disable those fields based solely on active status.

Closed/archived direct edit route renders review/unavailable state with Back to Homework, not an editable form.

---

# 50. Roster Loading Ownership

The Student picker may be opened after the parent form started.

Stale roster completions must not:

- mutate a closed picker;
- mutate another session;
- overwrite a newer search/page;
- apply selection after Cancel;
- close the dialog.

Anchor to:

```text
TeacherSessionKey
groupId
picker generation
query generation
```

The parent create/edit controller accepts returned selection only if its own route/session ownership still matches the owner captured before opening the picker.

Reuse the same pattern used by current Topic Group picker.

---

# 51. Homework List / Detail Reconciliation

Create one narrow helper/provider strategy, not a second cache.

## On confirmed create

```text
invalidate teacherHomeworkListControllerProvider(topicId)
```

or mark its retained result stale using the FE-001 pattern if one exists.

## On create unknown Review Homework

Also invalidate/mark stale before returning to Topic.

## On confirmed edit

- accept authoritative Homework in detail controller if supported;
- invalidate Topic list.

## On edit 404

- mark detail notFound;
- invalidate Topic list.

Do not optimistically patch list ordering/filter counts.

Backend list remains authoritative.

---

# 52. API Error Code Additions

Extend:

```text
frontend/lib/core/network/api_error_codes.dart
```

only for Stage 6 codes actually needed by FE-002 and not already present.

Required if missing:

```text
taskClosed = 'task_closed'
taskArchived = 'task_archived'
officialTaskRequiresGroupAssignment = 'official_task_requires_group_assignment'
```

Existing:

```text
businessConflict
topicNotEditable
validationFailed
resourceNotFound
```

must be reused.

Do not add future Stage 7/8 codes merely for completeness.

---

# 53. No Client Business Reinvention

Flutter must not decide:

- whether a selected Student is ultimately authorized;
- whether active Homework has Attempts;
- whether a fairness field is server-locked;
- whether a deadline is too late for activation;
- whether Homework is official;
- whether Topic can close;
- whether attempt count can change.

Local validation covers only deterministic request-shape/UX constraints in this contract.

Backend conflict overrides local assumptions.

---

# 54. Accessibility / Focus

Required:

- labeled text fields;
- field errors associated visibly;
- assignment controls have semantic labels;
- `Choose Students` reachable by keyboard;
- picker checkboxes have Student full name/login semantic text;
- unresolved selected placeholders have distinguishable accessible numbering;
- date picker control has label and current value;
- Clear Deadline button has tooltip/semantic text;
- fixed attempt policy not conveyed by color only;
- submitting progress uses live/progress semantics;
- first invalid field receives focus once per validation result;
- dialog Cancel/Apply focus order logical;
- dirty discard dialog accessible;
- long names/instructions wrap;
- no horizontal overflow at supported desktop window widths.

Do not use color as sole assignment/validation state.

---

# 55. Async / Route Ownership

Create/edit mutations can outlive the route.

Required safeguards:

- autoDispose controllers;
- explicit `enterRoute()`/`leaveRoute()` or equivalent route ownership;
- route generation;
- operation generation;
- active request identity;
- TeacherSessionKey equality;
- target equality for Edit.

A stale mutation completion must not:

- show SnackBar on a newer route/session;
- navigate from obsolete route;
- overwrite another Homework;
- close a new Student picker;
- mark a different Topic list stale.

Do not rely only on `context.mounted`.

---

# 56. Expected Files and Areas

Recommended domain additions/extensions:

```text
frontend/lib/features/teacher/domain/
  teacher_homework_mutation.dart
  teacher_homework_form.dart
```

Equivalent focused grouping allowed.

Recommended application:

```text
teacher_homework_create_controller.dart
teacher_homework_create_state.dart
teacher_homework_edit_controller.dart
teacher_homework_edit_state.dart
teacher_homework_student_picker_controller.dart
teacher_homework_student_picker_state.dart
```

Recommended presentation:

```text
teacher_homework_create_screen.dart
teacher_homework_edit_screen.dart
teacher_homework_form_fields.dart
teacher_homework_student_picker_dialog.dart
```

Modify narrowly:

```text
frontend/lib/features/teacher/domain/teacher_homework_repository.dart
frontend/lib/features/teacher/data/teacher_homework_remote_data_source.dart
frontend/lib/features/teacher/data/teacher_homework_repository_impl.dart
frontend/lib/features/teacher/presentation/teacher_homework_section.dart
frontend/lib/features/teacher/presentation/teacher_homework_detail_screen.dart
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
frontend/lib/core/network/api_error_codes.dart
```

Test support:

```text
frontend/test/features/teacher/teacher_test_support.dart
```

Focused tests:

```text
teacher_homework_mutation_test.dart
teacher_homework_create_controller_test.dart
teacher_homework_edit_controller_test.dart
teacher_homework_student_picker_controller_test.dart
teacher_homework_create_screen_test.dart
teacher_homework_edit_screen_test.dart
teacher_homework_student_picker_test.dart
teacher_homework_routing_screen_test.dart
```

Exact filenames may be consolidated where responsibilities remain focused.

Do not change:

- backend;
- docs;
- pubspec/lock;
- platform files;
- Student/Institution Admin/Platform feature code;
- Question-builder implementation;
- unrelated Teacher files.

---

# 57. Acceptance Criteria

- [ ] Desktop route `/teacher/topics/{topic}/homework/new` exists.
- [ ] Desktop route `/teacher/topics/{topic}/homework/{homework}/edit` exists.
- [ ] Both authoring routes are blocked/redirected on mobile to supported read locations.
- [ ] Topic Homework section exposes working Create only on desktop and only for confirmed draft/active Topic.
- [ ] Homework detail exposes working Edit only on desktop and confirmed draft/active Homework.
- [ ] Create form owns exact metadata/assignment/deadline fields and no Question editor.
- [ ] Create POST always sends `questions: []`.
- [ ] Create always creates draft intent; no status/attempt/points fields are sent.
- [ ] Title/Student instructions trim and validate exact limits.
- [ ] Description empty -> null; non-empty content remains verbatim.
- [ ] Assignment mode uses exact machine values.
- [ ] Whole-group request has empty `student_ids`.
- [ ] Selected mode requires non-empty selected IDs.
- [ ] Selected IDs are serialized sorted and unique.
- [ ] Picker uses Teacher Group Student roster API and preserves selections across page/search.
- [ ] Picker does not expose email/phone/raw UUID.
- [ ] Existing selected IDs not currently resolved to names remain removable placeholders rather than silently disappearing.
- [ ] Backend `student_ids` validation maps to useful picker error.
- [ ] Deadline uses Institution timezone helper and explicit offset; no device-time authority.
- [ ] Past deadline is not locally rejected merely for being past.
- [ ] Edit compares deadline by absolute instant.
- [ ] Attempt policy is displayed as fixed `3` and never writable.
- [ ] Edit PATCH sends only semantically changed fields.
- [ ] selected->group includes `student_ids: []`.
- [ ] group->selected includes assignment mode + sorted IDs.
- [ ] No Questions appear in PATCH.
- [ ] no-op Edit issues no mutation.
- [ ] confirmed mutation invalidates authoritative Homework list and refreshes/accepts detail state.
- [ ] Create unknown outcome is never auto-replayed and routes to manual Homework review.
- [ ] Edit unknown outcome reconciles through authoritative GET without replay.
- [ ] recognized lifecycle/business conflicts are definite non-commit and refresh current Homework state.
- [ ] active Homework editor does not locally claim whether Attempt activity exists.
- [ ] dirty-form back/cancel protection works.
- [ ] stale session/route/mutation/picker completions cannot affect current state.
- [ ] no mobile authoring, lifecycle UI, Question Builder, official designation, backend/package/platform work enters scope.
- [ ] focused tests pass.
- [ ] focused analyze passes.
- [ ] format check passes.
- [ ] `git diff --check` passes.
- [ ] final diff self-review finds no blocking API/state/routing/accessibility/scope issue.

---

# 58. Focused Tests and Verification

Run from:

```text
frontend/
```

Use FVM.

Do not run the full frontend suite/build/E2E. Those belong to Frontend Phase 2 / Integration.

## 58.1 Mutation domain/data

```bash
fvm flutter test \
  test/features/teacher/teacher_homework_mutation_test.dart \
  test/features/teacher/teacher_homework_data_test.dart
```

If FE-001 already owns `teacher_homework_data_test.dart`, extend it instead of creating a duplicate transport test.

Required cases:

### Create request

- exact seven keys;
- `questions=[]`;
- group IDs empty;
- selected IDs sorted;
- null deadline;
- explicit-offset deadline;
- description null/verbatim;
- no protected fields.

### Edit request

- each field individually;
- all fields;
- no-op;
- group->selected;
- selected->group;
- selected set reorder alone is no-op;
- deadline equivalent UTC instant no-op;
- no Questions key;
- `matches(current)` exact intended-field behavior.

### Remote source

- exact POST/PATCH path/status/message;
- strict success parse;
- known definite error classification;
- malformed success -> unknown;
- network ambiguity -> unknown;
- no automatic retry.

## 58.2 Create/Edit controllers

```bash
fvm flutter test \
  test/features/teacher/teacher_homework_create_controller_test.dart \
  test/features/teacher/teacher_homework_edit_controller_test.dart
```

Cover:

### Create

- Topic loading;
- Topic unavailable;
- closed/archived Topic review state;
- valid default group form;
- local validation/focus data;
- selected requirement;
- success -> invalidate + destination;
- 422 mapping;
- 404;
- topic_not_editable;
- unknown outcome;
- Review Homework;
- duplicate submit suppression;
- stale route/session completion ignored.

### Edit

- initializes from draft;
- initializes from active;
- closed/archived review-only;
- timezone conversion;
- dirty/no-op;
- success;
- 422;
- student_ids validation;
- each recognized 409 conflict + authoritative refresh;
- unknown mutation + GET matches -> success;
- unknown + GET differs -> review;
- unknown + GET failure -> check-current state;
- 404 -> detail notFound;
- stale target/session completion ignored.

## 58.3 Student picker controller/widget

```bash
fvm flutter test \
  test/features/teacher/teacher_homework_student_picker_controller_test.dart \
  test/features/teacher/teacher_homework_student_picker_test.dart
```

Cover:

- initial page;
- search trim;
- page reset;
- pagination;
- select/deselect;
- selections persist across pages;
- selections persist across search;
- unresolved initial selected IDs shown without UUID;
- loaded later ID resolves label;
- Cancel does not apply;
- Apply returns complete set;
- error/retry;
- roster 404 safe error;
- stale older query result ignored;
- session/picker disposal stale result ignored;
- keyboard/semantic basics.

## 58.4 Screens/router

```bash
fvm flutter test \
  test/features/teacher/teacher_homework_create_screen_test.dart \
  test/features/teacher/teacher_homework_edit_screen_test.dart \
  test/features/teacher/teacher_homework_routing_screen_test.dart \
  test/features/teacher/teacher_homework_section_test.dart \
  test/features/teacher/teacher_homework_detail_screen_test.dart
```

Cover:

- desktop create route;
- desktop edit route;
- mobile create redirect Topic detail;
- mobile edit redirect Homework detail;
- query/fragment rejection;
- Create button visibility;
- Edit button visibility;
- form fields;
- assignment mode;
- deadline picker/clear;
- fixed attempt callout;
- no Question editor;
- dirty discard dialog;
- progress/disabled state;
- active informational note;
- unknown create panel;
- conflict review state;
- no overflow in supported desktop constraints.

## 58.5 Directly affected Stage 5 regressions

Because authoring router and timezone helper are reused:

```bash
fvm flutter test \
  test/features/teacher/teacher_topic_routing_screen_test.dart \
  test/features/teacher/teacher_topic_controller_test.dart
```

If route test already runs as part of a consolidated Homework router test with existing assertions, avoid a redundant second run only when the exact existing regression assertions are included.

Do not run the entire Stage 5 suite.

## 58.6 Focused analyze

```bash
fvm flutter analyze --no-pub lib/features/teacher
fvm flutter analyze --no-pub lib/app/router
```

Also analyze `lib/core/network/api_error_codes.dart` if the CLI/path invocation supports exact file targets; otherwise it is covered transitively by Teacher imports/router compile analysis.

## 58.7 Format

```bash
fvm dart format --output=none --set-exit-if-changed \
  lib/features/teacher \
  lib/app/router/app_route_paths.dart \
  lib/app/router/app_router.dart \
  lib/core/network/api_error_codes.dart \
  test/features/teacher
```

## 58.8 Always

```bash
git diff --check
```

Then focused diff self-review:

- no widget calls Dio;
- no raw JSON in presentation/application;
- no second Homework DTO/repository hierarchy;
- no automatic mutation retry;
- no device timezone authority;
- no raw Student UUID display;
- no attempt-count input;
- no Question/lifecycle/official UI;
- no mobile authoring;
- no stale async navigation/feedback;
- no unrelated package/platform/backend/docs change;
- no tests weakened;
- no debug/secrets/temp/generated junk;
- no unrelated formatting churn.

---

# 59. Project Owner Manual Check

```text
Not required at task level.
```

Real-stack create/edit/Student selection/deadline smoke belongs to `S06-INT-001`.

---

# 60. Delivery

Follow root `AGENTS.md` and `tasks/README.md`.

Delivery execution:

```text
Project Owner
```

Suggested:

```text
Branch: feat/s06-fe-002-homework-draft-builder
Commit: feat(stage6): add homework draft builder
PR base: main
```

Codex must not:

- commit;
- push;
- open/merge PR;
- modify task/Stage bookkeeping;
- modify this task file.

Codex stops after implementation, focused verification, `git diff --check`, and focused scope/diff self-review.

Task acceptance occurs only after approved delivery is present on `origin/main`, local `main == origin/main`, ahead/behind `0/0`, and worktree clean.

---

# 61. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to rediscover requirements.

| Source/reference | Decision already encoded above |
|---|---|
| Approved Stage 6 decomposition | FE-002 owns Homework metadata/assignment/deadline create/edit; FE-003 owns Questions |
| S06-BE-003 contract | strict create/PATCH fields, selected roster API, deadline timezone, no-op, mutation conflict behavior |
| S06-FE-001 contract | typed Homework read domain, list/detail, roster client, read routes |
| Current Topic authoring UI | desktop-only authoring route gate, controlled forms, picker, dirty/unknown outcome patterns |
| Current Topic edit controller | GET reconciliation after uncertain mutation; no automatic replay |
| Current shared InstitutionTimezone | IANA wall-clock conversion/serialization, no device timezone |
| Current `ApiErrorCodes` | `business_conflict`, `topic_not_editable`, validation/session/base codes already present |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |

---

# 62. Codex Final Report

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
6. **Create/edit payloads** — evidence.
7. **Roster/selection safety** — evidence.
8. **Timezone/no-op** — evidence.
9. **Mutation uncertainty/conflict reconciliation** — evidence.
10. **Session/route stale-async** — evidence.
11. **Accessibility/mobile boundary** — evidence.
12. **Scope/diff** — non-goals + `git diff --check`.
13. **Delivery handoff** — Project Owner + current Git state.
14. **Deviations/blockers** — exact facts.

Do not output task `Accepted`.

Do not repeat the contract or paste large successful logs.

If final backend/FE-001 implementation creates a material contract mismatch or a required product/API/UX/security/state decision is unresolved, return `BLOCKED` rather than deciding independently.
