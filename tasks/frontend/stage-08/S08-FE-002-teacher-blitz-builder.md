# Codex Implementation Contract: S08-FE-002 — Teacher Blitz Builder

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-FE-002` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter desktop Teacher Blitz create/edit + assignment/duration authoring + shared nine-type Question Builder` |
| Depends on | `S08-FE-001 Accepted / Delivered`; `S08-BE-PHASE-2 = PASS` remains valid |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Runtime implementation baseline | ChatGPT must re-check/freeze current `origin/main` immediately before Codex execution |
| Backend API dependency | Final delivered Stage 8 Teacher Blitz authoring + shared Question mutation API after Backend Phase 2 PASS |
| Flutter toolchain | Use the repository's current FVM-pinned Flutter version at implementation time |
| Implementation Readiness Gate | `PASS — planning contract`; execution remains dependency-gated |
| Verification | `Codex — focused frontend verification only` |
| Delivery execution | `Project Owner` |
| Frontend block checkpoint | `S08-FE-PHASE-2` after `S08-FE-001…006` are `Accepted / Delivered` |
| Blocks | `S08-FE-003` |

Do not start until:

```text
S08-FE-001 = Accepted / Delivered
S08-BE-PHASE-2 = PASS
current origin/main re-checked
final delivered Blitz authoring/Question API inspected
current FE-001 Blitz domain/routes/controllers inspected
current shared Homework Question authoring infrastructure inspected
clean synchronized local main
```

If delivered FE-001 or final backend implementation materially conflicts with
this contract, return:

```text
BLOCKED
```

with exact evidence.

Do not invent a new UX/API/business contract.

This file is the complete task-specific implementation contract.

Do **not** create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. delivered S08-FE-001 source/tests directly required here;
5. final delivered Stage 8 Blitz create/update and shared Question mutation
   routes/resources directly required to confirm the API already encoded below;
6. current Stage 6 Homework create/edit Student-picker and Question-builder source
   directly required as implementation patterns/reuse targets;
7. current Teacher Topic/detail/session/router/error/time infrastructure directly
   required by this task.

Do **not** read:

- product docs;
- roadmap;
- previous Stage 8 task files;
- Stage history;
- checkpoint reviews;
- closure reviews;
- unrelated modules

to determine requirements.

This contract resolves:

- desktop/mobile authoring boundary;
- Blitz create/edit routes;
- metadata/assignment/duration form;
- selected-Student picker behavior;
- official-Blitz assignment UX safety;
- exact create payload;
- exact changed-field PATCH payload;
- schedule exclusion from Builder;
- create/edit mutation uncertainty;
- list/detail reconciliation;
- Question Builder route;
- all-nine shared Question editor behavior;
- add/update/delete/reorder mutations;
- Blitz-specific Question editability;
- shared-vs-subtype frontend architecture;
- dirty navigation protection;
- session/route/operation stale-completion safety;
- accessibility/responsiveness;
- focused verification.

---

# 3. Goal

Add production-quality **desktop Teacher Blitz authoring**.

The Teacher must be able to:

## Create

- start a new Blitz from an authorized Topic;
- enter title;
- optionally enter description;
- enter Student instructions;
- choose whole-group or selected-Student assignment;
- select current eligible Students for selected assignment;
- enter one positive whole-Blitz duration in seconds;
- see that normal attempts are fixed at `1`;
- see that at most `1` additional Student-specific exception attempt may later
  be granted;
- create the Blitz as a `draft`;
- create it with no initial Questions;
- navigate to the authoritative created Blitz.

## Edit

For a current:

```text
draft
scheduled
```

Blitz, the Teacher may update:

```text
title
description
student instructions
assignment mode
selected Student set
duration
```

The Builder does **not** edit scheduling.

## Questions

For a current:

```text
draft
scheduled
```

Blitz, the Teacher may:

- add any of the nine supported Question types;
- edit existing Questions;
- delete Questions;
- stage and save Question order;
- see authoritative total points after every confirmed mutation.

The task does not implement lifecycle execution.

`S08-FE-003` owns:

```text
Schedule / Reschedule
Official Blitz designation
Activate
Close
Archive
```

and corresponding lifecycle UX.

---

# 4. Scope

## 4.1 Included

Implement:

- desktop Blitz Create route/screen;
- desktop Blitz Edit route/screen;
- desktop Blitz Question Builder route/screen;
- working `Create Blitz` action in FE-001 Topic Blitz section;
- working `Edit` action in FE-001 Blitz detail;
- working `Manage Questions` action in FE-001 Blitz detail;
- Blitz form domain/value/validation;
- create/update mutation request types;
- create/update repository/data-source methods;
- strict mutation response parsing;
- mutation-outcome-unknown classification;
- create controller/state;
- edit controller/state;
- selected-Student picker reuse/extraction;
- fixed attempt-policy information;
- duration input/preview;
- official-Blitz assignment lock hint when authoritative pair state confirms it;
- Question add/update/delete/reorder methods on Blitz repository;
- Blitz Question Builder orchestration;
- reuse of existing nine-type Question domain/configuration authoring;
- reuse/extraction of existing Question editor presentation where practical;
- route/session/operation stale-completion safety;
- dirty-form/order navigation protection;
- local/server validation mapping;
- business/lifecycle conflict reconciliation;
- narrow Blitz list/detail invalidation;
- mobile authoring redirects;
- focused tests and directly affected Stage 6/FE-001 regressions.

## 4.2 Explicit non-goals

Do **not** implement:

- schedule/reschedule control;
- scheduled date/time picker;
- automatic schedule after create;
- official Blitz designation mutation;
- Activate;
- Close;
- Archive;
- monitoring;
- attempt-exception grant UI;
- Student Blitz UI;
- countdown;
- answer/file UI;
- Submit UI;
- checking/scoring;
- Topic result;
- editable timer-start mode;
- current Institution timer-setting editor/read dependency;
- per-Question timers;
- editable attempt count;
- mobile authoring;
- optimistic mutation success;
- automatic mutation replay;
- offline storage;
- new package;
- drag-and-drop package;
- new router/state-management/network architecture;
- backend changes;
- platform changes;
- full frontend suite/build/E2E.

Do not render disabled future lifecycle/monitoring controls.

---

# 5. Critical Builder Boundary — No Scheduling Here

The backend Create endpoint permits an optional prepared:

```text
scheduled_at
```

and the dedicated lifecycle endpoint later owns scheduling/rescheduling.

For a single clear frontend ownership model:

> **S08-FE-002 never authors `scheduled_at`.**

Create sends:

```json
"scheduled_at": null
```

and Edit never sends:

```text
scheduled_at
```

The only Stage 8 Teacher UI that schedules/reschedules a Blitz will be
`S08-FE-003`.

This avoids two competing scheduling workflows.

Do not add a date/time field hidden behind the Builder.

---

# 6. Dependency Contract from FE-001

Reuse delivered equivalents of:

```text
TeacherBlitz
TeacherBlitzSummary
TeacherBlitzStatus
TeacherBlitzAssignmentMode
TeacherBlitzTimerStartMode
TeacherBlitzAttemptPolicy
TeacherBlitzRepository
TeacherBlitzRemoteDataSource
TeacherBlitzRouteTarget
teacherBlitzListControllerProvider(topicId)
teacherBlitzDetailControllerProvider(target)
TeacherBlitzSection
TeacherBlitzDetailScreen
TeacherQuestion
TeacherQuestionDto
TeacherQuestionReadView
TeacherTopicResultPairController
TeacherSessionKey
AppRoutePaths.teacherBlitzDetailLocation(...)
```

Reuse existing Stage 6 Teacher Question authoring domain:

```text
TeacherQuestionDraft
TeacherValidatedQuestionDraft
TeacherQuestionCreateRequest
TeacherQuestionEditSnapshot
TeacherQuestionEditRequest
TeacherQuestionReorderRequest
TeacherQuestionMutationOperation
TeacherQuestionAuthoringLimits
TeacherQuestionConfigurationFields
```

Do not duplicate the all-nine Question domain/configuration hierarchy.

---

# 7. Existing Selected-Student Infrastructure

Reuse the current Teacher Group Student roster API/client infrastructure
delivered in Stage 6:

```text
TeacherGroupStudent
TeacherGroupStudentRepository
TeacherGroupStudentList
TeacherGroupStudentListQuery
GET /teacher/groups/{group}/students
```

The current Homework Student picker behavior is structurally assignment-generic.

Do **not** copy its roster/search/pagination/selection state machine into a second
independent implementation.

Allowed implementation approach:

- extract/rename a type-neutral assignment Student-picker core and preserve the
  Homework behavior through a thin wrapper/adaptation; or
- reuse the existing controller/core through a thin Blitz-specific adapter if
  that preserves clear ownership.

Required outcome:

```text
one authoritative roster/search/pagination/selection implementation
Homework behavior unchanged
Blitz gets its own presentation labels/keys where needed
```

Do not perform a broad unrelated refactor.

---

# 8. Shared Question Authoring Architecture

The following existing components are genuinely shared and must remain shared:

```text
TeacherQuestionType
TeacherQuestionCheckingMode
TeacherQuestionDraft
TeacherQuestionAuthoringLimits
TeacherQuestionCreateRequest
TeacherQuestionEditRequest
TeacherQuestionReorderRequest
typed Question configuration drafts
TeacherQuestionConfigurationFields
TeacherQuestionReadView
```

Blitz-specific lifecycle/reconciliation orchestration may use Blitz-specific
controllers because:

```text
Homework editable states = draft|active under its own rules
Blitz editable states    = draft|scheduled
```

Do not force those incompatible lifecycle policies into one boolean-heavy
controller.

However:

> Do not copy the nine-type form/configuration implementation.

A narrow type-neutral editor **presentation** extraction is encouraged/required
where necessary to avoid copying the current Question editor field UI.

The final implementation must have one authoritative set of:

- Question form fields;
- type-change confirmation behavior;
- checking-mode confirmation behavior;
- all-nine configuration widgets;
- local Question validation rules.

Subtype-specific controllers may provide state/callbacks to that shared
presentation.

---

# 9. Backend Create API

Use configured Dio base:

```text
/api/v1
```

Endpoint:

```text
POST /teacher/topics/{topicId}/blitz
```

Success:

```text
201 Created
```

Expected successful authoritative resource:

```text
TeacherBlitz
```

Expected success message from the Stage 8 backend contract:

```text
Blitz task created successfully.
```

At implementation start inspect the delivered backend response envelope and keep
strict parsing aligned with the accepted backend.

If final Backend Phase 2 changed this exact public envelope, stop and return
`BLOCKED`; do not silently broaden parser acceptance.

---

# 10. Create Payload

S08-FE-002 sends exactly:

```json
{
  "title": "Topic Blitz",
  "description": null,
  "student_instructions": "Answer quickly.",
  "assignment_mode": "group",
  "student_ids": [],
  "duration_seconds": 600,
  "scheduled_at": null,
  "questions": []
}
```

Exact keys:

```text
title
description
student_instructions
assignment_mode
student_ids
duration_seconds
scheduled_at
questions
```

Do not send:

```text
status
attempt_limit
normal_attempts
timer_start_mode
timer_start_mode_snapshot
total_possible_points
activated_at
synchronized_ends_at
```

Create does not nest locally authored Questions.

Questions are managed after the Blitz resource exists.

---

# 11. Backend Update API

Endpoint:

```text
PATCH /teacher/blitz/{blitzId}
```

Allowed fields only:

```text
title
description
student_instructions
assignment_mode
student_ids
duration_seconds
```

Do not send:

```text
scheduled_at
questions
status
timer_start_mode
attempt_limit
```

Success:

```text
200 OK
```

with the complete authoritative Teacher Blitz resource.

Do not require a human-readable success message unless the final accepted backend
actually defines one.

A strict valid `200 + authoritative resource` is sufficient update success
evidence.

---

# 12. Shared Question Mutation API

Use exactly:

```text
POST   /teacher/assessments/{blitzId}/questions
PATCH  /teacher/questions/{questionId}
DELETE /teacher/questions/{questionId}
POST   /teacher/assessments/{blitzId}/questions/reorder
```

Expected successes:

```text
Add      -> 201 + "Question created successfully."
Update   -> 200 + "Question updated successfully."
Delete   -> 200 + "Question deleted successfully."
Reorder  -> 200 + "Questions reordered successfully."
```

Each success returns the complete authoritative:

```text
TeacherBlitz
```

for a Blitz target.

Do not call Blitz metadata PATCH to mutate Questions.

---

# 13. Create Route

Add canonical desktop authoring route:

```text
/teacher/topics/{topicId}/blitz/new
```

Recommended:

```text
AppRouteNames.teacherBlitzCreate
teacherBlitzCreateSegment = 'new'
AppRoutePaths.teacherBlitzCreate
teacherBlitzCreateLocation(topicId)
isTeacherBlitzCreatePath(path)
```

Register the static:

```text
blitz/new
```

route before the dynamic:

```text
blitz/:blitzId
```

route can consume it.

Builder:

```text
TeacherBlitzCreateScreen(topicId: ...)
```

Use:

```text
_buildTeacherDestination(
  ...,
  authoring: true,
)
```

Desktop only.

---

# 14. Edit Route

Add:

```text
/teacher/topics/{topicId}/blitz/{blitzId}/edit
```

Recommended:

```text
AppRouteNames.teacherBlitzEdit
teacherBlitzEditSegment = 'edit'
teacherBlitzEditLocation(topicId, blitzId)
isTeacherBlitzEditPath(path)
```

Nest under FE-001 Blitz detail.

Use:

```text
authoring: true
```

desktop only.

---

# 15. Question Builder Route

Add:

```text
/teacher/topics/{topicId}/blitz/{blitzId}/questions
```

Recommended:

```text
AppRouteNames.teacherBlitzQuestions
teacherBlitzQuestionsSegment = 'questions'
teacherBlitzQuestionsLocation(topicId, blitzId)
isTeacherBlitzQuestionsPath(path)
```

Nest under Blitz detail.

Screen:

```text
TeacherBlitzQuestionBuilderScreen
```

Use:

```text
authoring: true
```

desktop only.

No second ShellRoute.

---

# 16. Mobile Route Behavior

Authenticated Teacher + mobile:

```text
/teacher/topics/<topic>/blitz/new
  -> /teacher/topics/<topic>

/teacher/topics/<topic>/blitz/<blitz>/edit
  -> /teacher/topics/<topic>/blitz/<blitz>

/teacher/topics/<topic>/blitz/<blitz>/questions
  -> /teacher/topics/<topic>/blitz/<blitz>
```

The read-only Blitz detail remains mobile-supported.

Do not transiently render desktop authoring UI before redirect.

Update bootstrap/auth route normalization consistently.

Do not change existing Homework mobile redirects.

---

# 17. Topic Detail Create Entry

Extend FE-001:

```text
TeacherBlitzSection
```

On desktop only, show a working:

```text
Create Blitz
```

control when the **confirmed current Topic** status is:

```text
draft
active
```

Do not show for:

```text
closed
archived
```

Do not show if Topic detail is:

```text
loading
error
notFound
stale without confirmed current state
```

Navigate to:

```text
teacherBlitzCreateLocation(topic.id)
```

No Create control on mobile.

---

# 18. Blitz Detail Edit / Question Entries

On desktop, for a confirmed current Blitz status:

```text
draft
scheduled
```

show:

```text
Edit
Manage Questions
```

Do not show these controls for:

```text
active
closed
archived
```

Do not show them on mobile.

Do not infer Attempt existence.

Backend remains authoritative for races/conflicts.

No lifecycle controls yet.

---

# 19. Direct Authoring Route After Lifecycle Change

A Teacher may have an authoring route open while another operation/client changes
the Blitz lifecycle.

## Edit

If current authoritative Blitz becomes:

```text
active
closed
archived
```

the Edit screen switches to unavailable/review state:

```text
Blitz editing is no longer available.
```

No Save.

## Question Builder

For:

```text
active
closed
archived
```

direct Question route becomes read/review-only:

- Questions still visible;
- add/edit/delete/reorder controls absent/disabled;
- Back to Blitz available.

Do not navigate automatically merely because lifecycle changed.

---

# 20. Blitz Form Value

Create immutable controlled value equivalent to:

```text
TeacherBlitzFormValue
```

Fields:

```text
title: String
description: String
studentInstructions: String
assignmentMode: TeacherBlitzAssignmentMode
selectedStudentIds: Set<String>
durationSecondsText: String
```

Create defaults:

```text
title = ''
description = ''
studentInstructions = ''
assignmentMode = group
selectedStudentIds = {}
durationSecondsText = ''
```

Do not invent a default duration.

No schedule state.

No timer-mode state.

No Question state.

No attempt-count state.

---

# 21. Blitz Form Field Enum

Create:

```text
TeacherBlitzFormField
```

Exact request mapping:

```text
title                -> title
description          -> description
studentInstructions  -> student_instructions
assignmentMode       -> assignment_mode
studentIds           -> student_ids
durationSeconds      -> duration_seconds
```

Use for:

- local field errors;
- server 422 mapping;
- first-invalid focus.

Do not add:

```text
scheduledAt
questions
timerStartMode
attemptLimit
status
```

as form fields.

---

# 22. Local Validation — Title

On submit:

```text
trim
required
1..255 Unicode characters after trim
```

Send the trimmed value.

---

# 23. Local Validation — Description

Optional.

Maximum:

```text
10000 Unicode characters
```

Normalization:

```text
exact '' -> null
non-empty String -> preserve verbatim
```

Do not trim a non-empty description.

Whitespace-only non-empty value remains user input and is not silently rewritten.

---

# 24. Local Validation — Student Instructions

On submit:

```text
trim
required
1..10000 Unicode characters after trim
```

Send trimmed value.

---

# 25. Local Validation — Assignment

Exact:

```text
group
selected_students
```

## Group

Resulting selected IDs:

```text
[]
```

## Selected

Require:

```text
selectedStudentIds.isNotEmpty
```

Every ID canonical UUID.

Request IDs:

```text
sorted ascending
```

Do not locally infer backend eligibility beyond the current roster response.

---

# 26. Local Validation — Duration

The backend contract is:

```text
integer >= 1
<= PostgreSQL signed integer max
```

Use:

```text
2147483647
```

as the transport/persistence upper bound.

`durationSecondsText` validation:

```text
trim
required
ASCII/base-10 whole integer syntax only
1..2147483647
```

Do not accept:

- decimal seconds;
- negative;
- sign-only;
- exponent notation;
- localized thousands separators.

Request sends:

```text
int
```

Do not impose a 5-minute/10-minute product range.

---

# 27. Duration UX

Use one clear numeric field:

```text
Duration (seconds)
```

Helper text:

```text
Whole-Blitz duration. Example: 600 seconds = 10 minutes.
```

Show a read-only formatted preview when valid, using FE-001:

```text
formatTeacherBlitzDuration(...)
```

Examples:

```text
90  -> 1 min 30 sec
600 -> 10 min
```

Do not add a dependency for a duration picker.

Do not add per-Question duration.

---

# 28. Assignment UX

Present:

```text
Whole group
Selected students
```

For selected mode show:

```text
Choose Students
Selected: N
```

Use the shared assignment Student picker.

When switching:

## Selected -> Group

If selected IDs are non-empty, require explicit confirmation before clearing the
selection.

## Group -> Selected

Do not fabricate a selection.

Require the Teacher to choose at least one Student before Save/Create.

---

# 29. Practice / Official Assignment Note

Selected-Student Blitz is practice/supplementary.

When selected assignment is chosen, show a neutral info note:

```text
A selected-student Blitz cannot be designated as the official Topic Blitz.
Only whole-group Blitz can be official.
```

This is informational.

Do not automatically change result-pair state.

Do not label the task “Practice” as an authoritative status in list/detail.

---

# 30. Selected-Student Picker Behavior

Reuse the Stage 6 picker semantics:

```text
search
page
perPage
selected IDs across pages
resolved names
unresolved persisted IDs on Edit
```

Default:

```text
page = 1
perPage = 50
search = null
```

Search:

```text
max 100
trim on commit
empty -> null
```

Selection persists across searches/pages.

No current page may silently remove off-page selections.

---

# 31. Unresolved Selected IDs on Edit

Blitz detail may contain persisted selected Student IDs that the current eligible
roster no longer returns.

Do not display raw UUIDs.

Show placeholder entries equivalent to:

```text
Selected student N
Name not loaded in the current eligible roster view.
```

with:

```text
Remove
```

Preserve the internal ID unless Teacher removes it.

If later roster data resolves the ID, display the real name/login.

Do not call the Student definitively “ineligible” merely because it was not
loaded.

Backend validation remains authoritative.

---

# 32. Server Student-IDs Error

If backend returns:

```text
422 validation_failed
errors.student_ids
```

map to assignment/picker error:

```text
Review the selected Students. One or more selections may no longer be eligible.
```

Focus/scroll to assignment area.

Do not disclose a private Student ID from backend/internal state.

---

# 33. Fixed Attempt Policy UX

Create/Edit show a read-only information card:

```text
Blitz attempts
Normal attempts: 1
Maximum additional exception attempts: 1
```

Additional helper text:

```text
An additional attempt is not a normal retry.
It can only be granted later by an authorized Teacher for one Student when a valid exception applies.
```

On Edit use authoritative parsed:

```text
blitz.attemptPolicy
```

On Create display the fixed product values `1` and `1`.

Do not put attempt counts in request payload.

No editable attempt field.

---

# 34. Timer Mode Information

Create/Edit may show one read-only informational note:

```text
The institution timer-start mode is snapshotted by the server when the Blitz is activated.
It is not configured in this Builder.
```

Do not:

- fetch current setting solely for this Builder;
- show an editable timer-mode control;
- send timer mode.

On Edit, if the Blitz is Draft/Scheduled:

```text
timerStartModeSnapshot == null
```

per strict FE-001 parsing.

---

# 35. Create Request Type

Create:

```text
TeacherBlitzCreateRequest
```

from validated form.

Fields serialized exactly:

```text
title
description
student_instructions
assignment_mode
student_ids
duration_seconds
scheduled_at = null
questions = []
```

Request object must guarantee:

- canonical sorted Student IDs;
- valid assignment relationship;
- positive duration;
- no protected field.

---

# 36. Edit Snapshot

Create:

```text
TeacherBlitzEditSnapshot
```

from authoritative `TeacherBlitz`.

Contains semantic initial values for:

```text
title
description
studentInstructions
assignmentMode
studentIds
durationSeconds
```

Do not include:

```text
scheduledAt
status
timer snapshot
Questions
```

in editable comparison.

---

# 37. Edit Request

Create:

```text
TeacherBlitzEditRequest
```

containing only changed fields.

Changed-field rules:

## Title

Include only if normalized trimmed title differs.

## Description

Compare normalized nullable representation:

```text
'' -> null
non-empty exact
```

## Student instructions

Compare normalized trimmed value.

## Duration

Compare validated integer seconds.

## Assignment

Treat:

```text
assignment_mode + student_ids
```

as one semantic resulting relationship.

When assignment mode changes, send both:

```text
assignment_mode
student_ids
```

When mode stays selected but Student set changes:

```text
student_ids
```

only is sufficient.

When mode stays group and IDs remain empty:

```text
no assignment field
```

Student ID comparison is case-insensitive set comparison.

No-op request:

```text
isEmpty = true
```

No network call.

---

# 38. Edit No-Op UX

If Teacher presses Save and semantic changed-field request is empty:

- do not send PATCH;
- show:
  ```text
  No changes to save.
  ```
- remain on Edit screen.

Do not churn server timestamps.

---

# 39. Official Blitz Assignment Lock in Edit UX

Reuse existing confirmed Topic result-pair state.

If:

```text
pair.blitzAssessmentId == current blitz.id
```

then the frontend knows this is the official Blitz.

For confirmed official Blitz:

```text
assignment mode must remain whole group
```

Edit UI:

- displays `Whole group`;
- disables/hides switch to selected students;
- no Student picker;
- shows:
  ```text
  Official Blitz uses whole-group assignment.
  ```

Other safe fields remain editable when status is:

```text
draft
scheduled
```

Do not block title/instructions/duration merely because pair is locked.

---

# 40. Official State Unavailable

If result-pair read is:

```text
loading
error
unconfirmed
```

do not invent official state.

Do not locally disable group/selected controls solely on uncertainty.

If Teacher attempts a server-invalid selected assignment and backend returns:

```text
409 official_task_requires_group_assignment
```

perform authoritative reconciliation:

1. refresh Blitz detail;
2. refresh result-pair state;
3. show server-authoritative conflict feedback;
4. do not retry mutation automatically.

---

# 41. Official-State Structural Contradiction

If confirmed pair says this Blitz is official but authoritative Blitz resource says:

```text
assignmentMode = selected_students
```

treat current authoring state as inconsistent.

Do not submit mutations from that inconsistent state.

Show safe review message:

```text
The current official Blitz assignment is inconsistent. Refresh the Blitz before editing.
```

Allow refresh/back.

Do not silently switch the server value.

---

# 42. Create Controller

Create focused autoDispose controller/state equivalent to:

```text
TeacherBlitzCreateController
TeacherBlitzCreateState
```

It must use:

```text
Teacher Topic detail
Teacher session ownership
TeacherBlitzRepository
```

Create direct route must obtain a confirmed Topic to know:

```text
topic ID
group ID
Topic lifecycle
```

Create allowed UI when confirmed Topic is:

```text
draft
active
```

Closed/Archived:

```text
Blitz creation is unavailable for this Topic.
```

Backend remains authoritative.

---

# 43. Create Controller State

State concepts:

```text
initial/loadingContext
editing
localValidationFailure
serverValidationFailure
submitting
definiteFailure
outcomeReview
success
unavailable
```

Fields as needed:

```text
form
fieldErrors
formError
failure
feedback
```

Do not use unrelated boolean soup when one enum state communicates operation.

---

# 44. Create Submission

Before request require:

- current eligible desktop Teacher session;
- confirmed current Topic;
- Topic route target unchanged;
- no request in flight;
- local form valid.

Create one immutable request snapshot.

While submitting:

- disable form submit;
- block duplicate Submit;
- block Student-picker launch;
- protect navigation according to mutation state.

---

# 45. Create Success

On strict successful `201`:

1. require returned:
   ```text
   blitz.topicId == route topicId
   blitz.groupId == confirmed Topic groupId
   status = draft
   ```
2. refresh/invalidate:
   ```text
   teacherBlitzListControllerProvider(topicId)
   ```
   without losing retained query/filter/page unnecessarily;
3. seed/accept returned Blitz into its detail controller if the delivered FE-001
   boundary supports an authoritative accept method, or rely on the detail GET
   after navigation if not;
4. navigate to:
   ```text
   teacherBlitzDetailLocation(topicId, returned.id)
   ```
5. show concise success feedback according to current Teacher mutation pattern.

No automatic navigation to Question Builder.

Teacher chooses `Manage Questions` from detail.

---

# 46. Create Mutation Outcome Uncertainty

Do not automatically replay Create after:

- connection loss after request may have been sent;
- timeout with unknown server outcome;
- malformed/unrecognized success response;
- unrecognized response that cannot prove failure.

Enter blocking:

```text
outcomeReview
```

message:

```text
Blitz creation outcome is uncertain.
Check the Topic Blitz list before trying to create it again.
```

Because there is no trusted created Blitz ID, the client cannot safely prove
which resource was created from a generic list if duplicate metadata is possible.

Provide:

```text
Check Blitz list
```

which:

- refreshes/marks the Topic Blitz list stale/current using the FE-001 list
  controller;
- returns to Topic detail;
- performs **no** automatic Create retry.

The Teacher may manually inspect and decide whether another Create is needed.

Do not match by title to infer success.

---

# 47. Create Definite Failures

Known exact failures remain retryable/editable as appropriate.

Map:

```text
422 validation_failed
```

to field/form errors.

Expected lifecycle/business conflict such as:

```text
409 topic_not_editable
```

causes:

- no automatic retry;
- refresh current Topic;
- switch to unavailable if Topic no longer permits creation;
- safe feedback.

Common auth/session failure follows existing Teacher session reconciliation.

---

# 48. Edit Controller

Create:

```text
TeacherBlitzEditController
TeacherBlitzEditState
```

Target:

```text
TeacherBlitzRouteTarget
```

Observe:

```text
teacherBlitzDetailControllerProvider(target)
teacherTopicResultPairControllerProvider(topicId)
Teacher session
```

Initialize form only from confirmed non-stale Blitz detail.

Editable statuses:

```text
draft
scheduled
```

No Edit mutation from stale detail.

---

# 49. Edit Lifecycle Change

If authoritative detail refresh becomes:

```text
active
closed
archived
```

then:

- cancel/retire local editable ownership generation;
- do not submit current draft;
- retain enough draft only for discard warning if necessary;
- show review/unavailable state;
- provide Back to Blitz.

Do not force a PATCH to “finish” a stale draft.

---

# 50. Edit Mutation Success

On strict successful PATCH:

1. returned Blitz must match:
   ```text
   target.blitzId
   target.topicId
   ```
2. accepted resource becomes authoritative detail via FE-001 detail controller
   accept method; add such a method if FE-001 delivered only refresh and the
   pattern matches current Homework detail;
3. refresh Blitz list preserving current query where practical;
4. clear dirty state;
5. navigate back to Blitz detail or show success then return according to current
   Teacher Edit pattern.

Preferred:

```text
successful Save -> Blitz detail
```

No lifecycle mutation.

---

# 51. Edit Mutation Outcome Uncertainty

Do not automatically replay PATCH.

If outcome is uncertain:

1. keep the request snapshot;
2. enter `outcomeReview`;
3. block another Save of the same uncertain operation;
4. offer:
   ```text
   Check current Blitz
   ```
5. perform exact:
   ```text
   GET /teacher/blitz/{blitzId}
   ```
6. compare the authoritative resource to the changed fields from the request.

If every requested changed field now matches:

```text
treat as reconciled success
```

If not:

- accept server resource as new authoritative baseline only after explicit UI
  reconciliation;
- show:
  ```text
  The server state differs from the attempted changes. Review the current Blitz before saving again.
  ```
- do not replay automatically.

---

# 52. Update Definite Conflict Mapping

Expected server conflicts include:

```text
topic_not_editable
task_closed
task_archived
business_conflict
official_task_requires_group_assignment
```

Use machine codes, not human messages.

On lifecycle conflict:

- refresh authoritative Blitz;
- refresh Topic/result-pair when relevant;
- update UI capability from confirmed new state.

No automatic mutation retry.

---

# 53. Form Dirty Navigation Protection

Create/Edit:

- track semantic dirty state;
- Back/system pop while dirty opens:
  ```text
  Discard Blitz changes?
  ```
- actions:
  ```text
  Keep editing
  Discard
  ```
- while a mutation outcome is uncertain/busy:
  block unsafe navigation according to current Teacher patterns.

A session invalidation may force safe route/session reset; do not preserve private
draft across another authenticated Teacher session.

---

# 54. Student Picker Launch Ownership

The selected-Student dialog may outlive its origin screen state.

Before opening:

- capture Teacher session owner;
- capture form/controller operation generation.

After dialog returns:

apply selected IDs only if:

```text
same Teacher session
same route target
same create/edit controller generation
form still in an editable state
```

A stale picker completion must not modify a newer form/session.

---

# 55. Question Builder — Blitz Editability

Question mutations are allowed by UX only for authoritative:

```text
draft
scheduled
```

Blitz.

For:

```text
active
closed
archived
```

show review-only Questions.

Do not permit Question mutation on Active Blitz.

This intentionally differs from Homework.

Do not reuse a Homework helper that says Active is editable.

---

# 56. Question Builder Screen

Create:

```text
TeacherBlitzQuestionBuilderScreen
```

Use the FE-001 Blitz detail controller as authoritative read source.

Do not create a second independent Blitz detail cache.

Screen shows:

```text
Blitz title/context
status
total possible points
Questions
Add Question
Refresh
Save order / Reset order when dirty
per-Question Edit/Delete/Move controls
```

Mutation controls appear only when:

```text
desktop
confirmed current detail
status = draft|scheduled
not busy
not stale
no blocking uncertain outcome
```

---

# 57. Question Builder Total Points

Display:

```text
blitz.totalPossiblePoints
```

from the authoritative server resource.

Do not sum local Question points and treat the result as authoritative.

After successful mutation:

- adopt returned complete Blitz;
- render returned total.

A local staged reorder does not change total.

---

# 58. Question Limit

Reuse:

```text
TeacherQuestionAuthoringLimits.maxQuestionsPerAssessment
```

Expected current contract:

```text
100
```

At max count:

- Add disabled;
- show:
  ```text
  Maximum 100 Questions.
  ```

Do not define a Blitz-specific different limit.

---

# 59. Add Question

New Question position:

```text
current authoritative question count + 1
```

Use existing:

```text
TeacherQuestionCreateRequest
```

No client Question ID.

No per-question timer.

Mutation:

```text
POST /teacher/assessments/{blitzId}/questions
```

Success returned Blitz is authoritative.

---

# 60. Edit Question

Use:

```text
TeacherQuestionEditSnapshot
TeacherQuestionEditRequest
```

No-op edit:

```text
no PATCH
No changes to save.
```

Mutation:

```text
PATCH /teacher/questions/{questionId}
```

Question must exist in current authoritative Blitz before editor opens/submits.

---

# 61. Delete Question

Require explicit confirmation:

```text
Delete Question N?
This removes the Question and its answer configuration.
```

Mutation:

```text
DELETE /teacher/questions/{questionId}
```

After success:

- returned Blitz authoritative;
- positions already compacted by server;
- do not locally renumber as authority.

---

# 62. Reorder Questions

Use staged local ID order.

Move controls:

```text
Move up
Move down
```

No new drag package.

While order dirty:

```text
Save order
Reset order
```

Request:

```text
TeacherQuestionReorderRequest
```

containing every current Question ID exactly once in desired order.

Mutation:

```text
POST /teacher/assessments/{blitzId}/questions/reorder
```

Success returned Blitz authoritative.

---

# 63. Question Order Dirty Navigation

While local Question order differs from authoritative:

- Back/Refresh requires:
  ```text
  Discard unsaved Question order?
  ```
- editor add/edit/delete is disabled until order is either saved or reset.

Do not combine a stale local reorder with a different Question mutation.

---

# 64. Shared Question Editor Presentation

Do not copy the current nine-type field implementation.

Required shared presentation behavior:

```text
Type
Prompt
Instructions
Points
Checking mode
type-specific configuration
```

Reuse existing:

```text
TeacherQuestionConfigurationFields
```

and all existing type-specific subwidgets.

If the current `TeacherQuestionEditorDialog` is too Homework-specific at the
provider/controller boundary, extract a shared pure presentation body/dialog
shell and keep:

```text
Homework editor wrapper/controller
Blitz editor wrapper/controller
```

as subtype orchestration.

Homework behavior and test keys may be preserved through wrappers.

Do not create a second set of configuration widgets.

---

# 65. Question Type / Checking Mode Behavior

Preserve the existing authoring contract exactly.

Examples:

- changing type may require confirmation and resets incompatible configuration;
- changing automatic/manual mode may require confirmation;
- file/open-written remain manual where the existing domain enforces it;
- local IDs are presentation-only correlation IDs;
- Matching request uses canonical correlation behavior;
- Fill-in-Blank placeholder validation remains unchanged.

Do not invent Blitz-specific Question rules.

---

# 66. Question Mutation Repository Methods

Extend:

```text
TeacherBlitzRepository
```

with:

```dart
Future<TeacherBlitz> addQuestion(
  String blitzId,
  TeacherQuestionCreateRequest request,
);

Future<TeacherBlitz> updateQuestion(
  String questionId,
  TeacherQuestionEditRequest request,
);

Future<TeacherBlitz> deleteQuestion(String questionId);

Future<TeacherBlitz> reorderQuestions(
  String blitzId,
  TeacherQuestionReorderRequest request,
);
```

Do not add lifecycle methods in FE-002.

---

# 67. Shared Question Transport Reuse

The public Question routes are shared across Homework and Blitz.

Avoid copy-pasting an entire second raw HTTP/error-envelope implementation when a
small type-neutral shared transport can safely own:

```text
method/path/body
expected status
expected success message
common auth/validation/rate-limit mapping
```

while caller supplies/parses the subtype authoritative resource.

Allowed:

```text
TeacherQuestionMutationRemoteDataSource
```

or equivalent focused extraction.

Do not force Homework and Blitz lifecycle conflict sets into one hardcoded list.

Subtype-specific allowed conflict codes may remain parameterized.

Preserve all accepted Homework behavior.

---

# 68. Blitz Question Conflict Codes

Expected definite `409` conflicts for Blitz Question mutation include:

```text
topic_not_editable
task_closed
task_archived
business_conflict
```

Do not treat:

```text
result_pair_locked
```

as a general Blitz Question-authoring lock.

A Draft/Scheduled official Blitz may still be authored even when the pair is
historically locked.

Do not locally disable Questions merely because:

```text
pair.lockedAt != null
```

---

# 69. Question Mutation Outcome Uncertainty

Use the same high-quality rule as current Homework Question mutation:

> Never automatically replay an uncertain non-idempotent Question mutation.

For uncertain add/update/delete/reorder:

1. retain operation identity/request snapshot;
2. block conflicting mutation;
3. offer:
   ```text
   Check current Blitz
   ```
4. GET exact authoritative Blitz detail;
5. determine whether the attempted effect is now provably present.

Examples:

## Add

Can reconcile as success only if the authoritative returned/current Question set
contains a semantic Question matching the attempted create in the expected
position without ambiguity under the existing current reconciliation strategy.

If exact success cannot be proved:

```text
do not replay automatically
show current authoritative state
```

## Update

If changed fields match the current target Question:

```text
reconciled success
```

## Delete

If target Question is absent:

```text
reconciled success
```

## Reorder

If current authoritative ID order exactly matches requested order:

```text
reconciled success
```

Otherwise require Teacher review.

---

# 70. Question Builder Server Lock Handling

If a Question mutation returns:

```text
business_conflict
task_closed
task_archived
topic_not_editable
```

then:

- do not retry automatically;
- refresh current Blitz detail;
- update builder capability;
- show a stable human message based on machine code.

If refreshed Blitz becomes Active/Closed/Archived:

```text
review-only
```

No hidden mutation remains enabled.

---

# 71. Authoritative Detail Adoption

Add/ensure FE-001 detail controller supports a narrow method equivalent to:

```text
acceptAuthoritativeBlitz(
  TeacherBlitz blitz,
  TeacherSessionKey originatingSessionKey,
)
```

It must publish only when:

```text
same current session
same route target Blitz ID
same Topic ID
```

Otherwise ignore.

Question/update controllers use this after strict successful mutation.

This avoids an unnecessary immediate GET after every confirmed successful
mutation.

List still refreshes independently.

---

# 72. Blitz List Refresh After Mutation

Extend FE-001 list controller with a narrow method equivalent to:

```text
refreshAfterMutation(TeacherSessionKey originatingSessionKey)
```

Requirements:

- ignore stale session;
- invalidate any older in-flight read generation;
- refresh the current retained query;
- retain current result while refreshing when present;
- preserve status filter/page unless server pagination after mutation requires a
  later normal correction.

Do not optimistically insert/remove/reorder list rows.

Server list is authoritative.

---

# 73. Create/Edit/Question Mutation Activity Isolation

Do not allow simultaneous same-Blitz mutations from two route/controller
surfaces to publish conflicting feedback/state.

Use focused operation ownership/generation.

At minimum:

- duplicate Save disabled;
- question editor and question reorder serialized;
- stale completion ignored after route/session change;
- Edit success cannot overwrite a newer detail mutation;
- a Question mutation success cannot close/navigate a newer editor/session.

A shared route mutation-activity lease may be reused/extracted where current
Homework Question Builder already has a proven pattern.

Do not create a global mutable singleton.

---

# 74. Create Form Screen

Create:

```text
TeacherBlitzCreateScreen
```

Desktop only.

App bar:

```text
Create Blitz
```

Back:

```text
Back to Topic
```

Sections:

```text
Blitz information
Assignment
Duration
Attempt policy
```

No Questions in Create screen.

Helper text may say:

```text
Create the Blitz first, then add Questions from Blitz detail.
```

No schedule field.

---

# 75. Edit Form Screen

Create:

```text
TeacherBlitzEditScreen
```

Desktop only.

App bar:

```text
Edit Blitz
```

Back:

```text
Back to Blitz
```

Same editable fields as Create.

Show current read-only schedule/timer information only if it naturally helps
context, but do not render a dead schedule editor.

Preferred:

- leave scheduling to FE-003;
- keep edit form focused.

---

# 76. Form Field Layout

Create reusable:

```text
TeacherBlitzFormFields
```

or equivalent.

Use current Material form patterns.

Fields:

```text
Title
Description
Student instructions
Assignment
Duration (seconds)
```

Responsive desktop layout:

- no fixed width overflow;
- text fields stretch inside bounded content;
- assignment controls wrap;
- picker button/selected count remain usable at smaller desktop widths.

No mobile authoring requirement.

---

# 77. Form Accessibility

Required:

- labels attached through Material form controls;
- field errors visible and programmatically associated where current framework
  behavior provides it;
- first invalid field receives focus after submit;
- busy state progress semantics;
- selected Student count not color-only;
- assignment radio/dropdown keyboard usable;
- discard dialog keyboard accessible;
- duration helper/preview readable.

---

# 78. Error Field Mapping

Map backend `422` keys:

```text
title
description
student_instructions
assignment_mode
student_ids
duration_seconds
```

to `TeacherBlitzFormField`.

If Create unexpectedly returns validation for fixed:

```text
scheduled_at
questions
```

despite this contract sending canonical:

```text
null
[]
```

treat as form-level server validation/contract issue.

Do not invent editable controls to fix those fields.

---

# 79. API Error-Code Infrastructure

Add any missing Stage 8 machine code constants required by this task to the
existing:

```text
ApiErrorCodes
```

Only add codes actually consumed here, for example:

```text
topic_not_editable
task_closed
task_archived
business_conflict
official_task_requires_group_assignment
```

if not already present from earlier frontend stages.

Do not duplicate constants in feature files.

---

# 80. Create/Edit Success Feedback

Use concise established Teacher mutation feedback.

Examples:

```text
Blitz created successfully.
Blitz updated successfully.
```

UI feedback text is presentation copy.

Do not use human response message as application control flow.

Transport success is established by:

```text
HTTP status
+
strict success envelope/resource
```

---

# 81. No Schedule Mutation in Repository

Even though the backend repository eventually needs schedule in FE-003:

S08-FE-002 must not prematurely add:

```text
scheduleBlitz
```

unless FE-003 is implemented in the same approved task, which it is not.

Keep current task API minimal.

---

# 82. No Lifecycle Eligibility Helper Beyond Builder

It is acceptable to create narrow helpers:

```text
teacherBlitzCanEditAuthoring
teacherBlitzCanManageQuestions
```

if they encode exactly:

```text
draft|scheduled
```

for FE-002 authoring UI.

Do **not** add:

```text
canActivate
canClose
canArchive
canSchedule
```

in FE-002.

Those belong to FE-003.

---

# 83. Expected File Scope

Exact filenames may follow current repository conventions.

## Create likely

```text
frontend/lib/features/teacher/domain/teacher_blitz_form.dart
frontend/lib/features/teacher/domain/teacher_blitz_mutation.dart

frontend/lib/features/teacher/application/teacher_blitz_create_state.dart
frontend/lib/features/teacher/application/teacher_blitz_create_controller.dart
frontend/lib/features/teacher/application/teacher_blitz_edit_state.dart
frontend/lib/features/teacher/application/teacher_blitz_edit_controller.dart

frontend/lib/features/teacher/application/teacher_blitz_question_builder_state.dart
frontend/lib/features/teacher/application/teacher_blitz_question_builder_controller.dart
frontend/lib/features/teacher/application/teacher_blitz_question_editor_controller.dart
frontend/lib/features/teacher/application/teacher_blitz_question_editor_target.dart

frontend/lib/features/teacher/presentation/teacher_blitz_create_screen.dart
frontend/lib/features/teacher/presentation/teacher_blitz_edit_screen.dart
frontend/lib/features/teacher/presentation/teacher_blitz_form_fields.dart
frontend/lib/features/teacher/presentation/teacher_blitz_question_builder_screen.dart
frontend/lib/features/teacher/presentation/teacher_blitz_question_editor_dialog.dart
```

A type-neutral shared Student-picker or Question-editor presentation extraction
may add/rename directly related files.

## Modify likely

```text
frontend/lib/features/teacher/domain/teacher_blitz_repository.dart

frontend/lib/features/teacher/data/teacher_blitz_remote_data_source.dart
frontend/lib/features/teacher/data/teacher_blitz_repository_impl.dart
frontend/lib/features/teacher/data/dto/* directly required for mutation envelope

frontend/lib/features/teacher/application/teacher_blitz_list_controller.dart
frontend/lib/features/teacher/application/teacher_blitz_detail_controller.dart

frontend/lib/features/teacher/presentation/teacher_blitz_section.dart
frontend/lib/features/teacher/presentation/teacher_blitz_detail_screen.dart

frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
frontend/lib/core/network/api_error_codes.dart
```

Shared Question/Student-picker production files may change narrowly to support
type-neutral reuse.

Do not modify:

```text
backend/
platform files
pubspec.yaml
pubspec.lock
Student Blitz frontend
integration_test/
docs/
tasks/
```

---

# 84. Form Domain Tests

Create:

```text
teacher_blitz_form_test.dart
teacher_blitz_mutation_test.dart
```

Cover:

- default Create form;
- title trim/required/max;
- description null/exact preservation/max;
- Student-instructions trim/required/max;
- group requires empty selection;
- selected requires non-empty IDs;
- canonical/sorted IDs;
- duration required;
- duration `1`;
- duration `2147483647`;
- reject `0`;
- reject negative;
- reject decimal;
- reject exponent;
- reject over max;
- Create request exact keys;
- scheduled_at always null;
- questions always [];
- Edit changed-field detection;
- assignment semantic changes;
- no-op Edit request.

---

# 85. Student Picker Regression / Blitz Integration Tests

If a shared picker core is extracted, run/update the existing Homework picker
tests.

Add Blitz-specific integration coverage for:

- selected mode opens picker;
- search/page selection retained;
- selected count;
- unresolved persisted selected ID;
- raw UUID not rendered;
- switching to group confirms and clears;
- stale picker completion ignored;
- server student_ids error focuses assignment;
- official confirmed Blitz disables selected assignment.

Homework Create/Edit picker behavior must remain green.

---

# 86. Mutation Data Source Tests

Create:

```text
teacher_blitz_mutation_data_source_test.dart
```

or extend FE-001 data-source test.

Verify Create:

```text
POST /teacher/topics/{topic}/blitz
exact body
201
strict success resource/message
```

Verify Update:

```text
PATCH /teacher/blitz/{blitz}
changed fields only
200
strict resource
```

Verify Question mutations:

```text
shared exact routes
expected status/messages
strict TeacherBlitz parsing
```

Verify:

- no scheduled update;
- no timer mode;
- no attempt limit;
- no auto retry;
- known errors definite;
- malformed success / uncertain transport classified outcome-unknown.

---

# 87. Create Controller Tests

Create:

```text
teacher_blitz_create_controller_test.dart
```

Cover:

- confirmed Draft Topic permits editing;
- confirmed Active Topic permits editing;
- Closed/Archived unavailable;
- local validation;
- selected roster launch ownership;
- duplicate submit suppressed;
- exact request;
- success refreshes list/navigable returned ID state;
- 422 field mapping;
- topic_not_editable reconciliation;
- session change ignores stale success;
- uncertain create enters review state;
- uncertain create does not replay;
- Check Blitz list flow marks/refreshes list safely.

---

# 88. Edit Controller Tests

Create:

```text
teacher_blitz_edit_controller_test.dart
```

Cover:

- loads Draft form;
- loads Scheduled form;
- Active/Closed/Archived unavailable;
- no-op Save no request;
- changed-fields PATCH exact;
- selected/group transitions;
- duration change;
- schedule excluded;
- confirmed official disables selected assignment;
- unconfirmed official state does not become local authority;
- official_task_requires_group_assignment reconciles;
- success accepts authoritative detail + refreshes list;
- unknown outcome GET reconciliation;
- request-match reconciled success;
- mismatch requires review;
- session/target stale completion ignored.

---

# 89. Create / Edit Screen Tests

Create:

```text
teacher_blitz_create_screen_test.dart
teacher_blitz_edit_screen_test.dart
```

Cover:

- fields/labels;
- no schedule control;
- no timer-mode control;
- no attempt-count control;
- duration preview;
- attempt policy card;
- selected assignment note;
- picker integration;
- local errors/focus;
- busy progress;
- dirty Back confirmation;
- success navigation;
- outcome-review UI;
- official assignment lock in Edit;
- no lifecycle controls.

---

# 90. Question Builder Controller Tests

Create:

```text
teacher_blitz_question_builder_controller_test.dart
```

Cover:

- Draft editable;
- Scheduled editable;
- Active review-only;
- Closed review-only;
- Archived review-only;
- Question limit;
- staged move/reset;
- save order;
- successful authoritative returned Blitz adoption;
- list refresh;
- business_conflict reconciliation;
- topic_not_editable;
- task_closed/task_archived;
- no `result_pair_locked` local lock;
- session/route stale completion;
- uncertain delete/update/reorder reconciliation;
- no automatic replay.

---

# 91. Blitz Question Editor Tests

Create/extend:

```text
teacher_blitz_question_editor_test.dart
```

Do not re-test every pure domain formula if existing shared Question tests already
cover it.

Required Blitz integration:

- Add opens shared nine-type editor;
- Edit initializes from current Question;
- create position append-only;
- no-op edit;
- success authoritative Blitz adoption;
- current resource lifecycle change closes/locks editor safely;
- all nine type selector values available;
- shared configuration widget used;
- no per-question timer control;
- server validation mapping;
- uncertain mutation review;
- dirty dialog close guard.

Run existing shared Question authoring unit/widget tests as regression.

---

# 92. Question Builder Screen Tests

Create:

```text
teacher_blitz_question_builder_screen_test.dart
```

Cover:

- loading/error/notFound;
- Draft controls;
- Scheduled controls;
- Active review-only;
- Closed/Archived review-only;
- Add;
- Edit;
- Delete confirmation;
- Move up/down;
- Save/reset order;
- total points from server;
- maximum Question message;
- stale/refresh state;
- dirty order Back guard;
- no lifecycle controls;
- all-nine Teacher Question readback.

---

# 93. Routing Tests

Extend/create:

```text
teacher_blitz_routing_screen_test.dart
```

Verify:

```text
/teacher/topics/<topic>/blitz/new
/teacher/topics/<topic>/blitz/<blitz>/edit
/teacher/topics/<topic>/blitz/<blitz>/questions
```

Desktop:

```text
all authoring routes allowed
```

Mobile:

```text
new       -> Topic detail
edit      -> Blitz detail
questions -> Blitz detail
```

Also verify:

- `new` never parsed as Blitz UUID;
- query/fragment rejected;
- malformed IDs safe;
- FE-001 Blitz detail still desktop/mobile;
- existing Homework routing remains unchanged.

---

# 94. FE-001 Direct Regression Tests

Run exact current focused tests for:

```text
TeacherBlitz DTO/list/detail
TeacherBlitz list controller
TeacherBlitz detail controller
TeacherBlitz section
TeacherBlitz detail screen
TeacherBlitz routing
```

Mutation additions must not weaken strict read parsing.

---

# 95. Stage 6 Shared Regression

Because this task may extract shared Student-picker/Question presentation/
transport infrastructure, run directly affected existing Homework tests.

At minimum where changed:

```text
teacher_homework_student_picker_controller_test
teacher_homework_student_picker_test
teacher_question_editor_test
teacher_question_builder_screen_test
teacher_homework_create/edit tests
teacher_homework_routing_screen_test
```

Only run files whose production boundary changed.

Do not weaken existing assertions.

---

# 96. Focused Verification — New Stage 8 Builder

Run from:

```text
frontend/
```

Conceptually:

```bash
fvm flutter test \
  test/features/teacher/teacher_blitz_form_test.dart \
  test/features/teacher/teacher_blitz_mutation_test.dart \
  test/features/teacher/teacher_blitz_mutation_data_source_test.dart \
  test/features/teacher/teacher_blitz_create_controller_test.dart \
  test/features/teacher/teacher_blitz_edit_controller_test.dart \
  test/features/teacher/teacher_blitz_create_screen_test.dart \
  test/features/teacher/teacher_blitz_edit_screen_test.dart \
  test/features/teacher/teacher_blitz_question_builder_controller_test.dart \
  test/features/teacher/teacher_blitz_question_editor_test.dart \
  test/features/teacher/teacher_blitz_question_builder_screen_test.dart \
  test/features/teacher/teacher_blitz_routing_screen_test.dart
```

Use actual filenames if combined differently.

Report exact command/result.

---

# 97. Focused Regression Verification

Run:

- exact FE-001 Blitz read/routing tests affected;
- exact Stage 6 Homework picker/Question tests affected by shared extraction.

Do not run the full frontend suite.

---

# 98. Focused Analyze

Run:

```bash
fvm flutter analyze --no-pub lib/features/teacher
fvm flutter analyze --no-pub lib/app/router
```

Also include:

```text
lib/core/network/api_error_codes.dart
```

through the narrowest supported analyze invocation if modified.

Do not silently substitute full-project analyze unless the pinned CLI requires
it.

---

# 99. Format Check

Run read-only format check on directly changed Dart files/directories.

Conceptually:

```bash
fvm dart format --output=none --set-exit-if-changed \
  <changed frontend lib files> \
  <changed focused test files>
```

Do not format unrelated files.

---

# 100. Git Diff Check

From repository root:

```bash
git diff --check
```

Required:

```text
PASS
```

Then perform focused scope/diff review.

Do not run:

- full frontend suite;
- full project analyze;
- Windows build;
- Android build;
- E2E.

Those belong to Frontend Phase 2 / Integration.

---

# 101. Acceptance Criteria — Builder Metadata

- [ ] Create route exists and is desktop-only.
- [ ] Edit route exists and is desktop-only.
- [ ] Create button appears only for current Draft/Active Topic.
- [ ] Edit appears only for Draft/Scheduled Blitz.
- [ ] Form fields exact.
- [ ] Duration is positive whole seconds.
- [ ] No duration product max invented.
- [ ] No schedule field.
- [ ] No timer-mode field.
- [ ] No attempt-limit field.
- [ ] Group/selected assignment exact.
- [ ] Selected Students use shared roster picker.
- [ ] Create sends `scheduled_at=null`.
- [ ] Create sends `questions=[]`.
- [ ] Edit PATCH sends changed fields only.
- [ ] No-op Edit sends no request.

---

# 102. Acceptance Criteria — Official Assignment Safety

- [ ] Selected assignment explains official restriction.
- [ ] Confirmed official Blitz cannot be switched to selected.
- [ ] Safe metadata/duration edits remain possible for Draft/Scheduled official Blitz.
- [ ] Pair lock does not locally disable safe authoring.
- [ ] Unconfirmed result-pair state is not treated as authority.
- [ ] Backend official-assignment conflict reconciles current state.
- [ ] No result-pair mutation in FE-002.

---

# 103. Acceptance Criteria — Question Builder

- [ ] Question route exists and is desktop-only.
- [ ] Draft/Scheduled editable.
- [ ] Active/Closed/Archived review-only.
- [ ] Existing all-nine Question domain/configuration reused.
- [ ] No copied second nine-type implementation.
- [ ] Add/update/delete/reorder exact shared endpoints.
- [ ] Returned Blitz authoritative after each success.
- [ ] Server total points displayed.
- [ ] Staged reorder guarded.
- [ ] No per-question timer.
- [ ] No `result_pair_locked` assumption for Blitz Question editing.
- [ ] No automatic replay after uncertain mutation.

---

# 104. Acceptance Criteria — Async / Mutation Safety

- [ ] Duplicate Save suppressed.
- [ ] Dirty create/edit navigation guarded.
- [ ] Dirty Question order guarded.
- [ ] Student picker stale completion ignored.
- [ ] Create uncertain outcome does not replay/match by title.
- [ ] Edit uncertain outcome reconciles exact Blitz GET.
- [ ] Question uncertain outcome reconciles exact Blitz GET.
- [ ] Old session/route completion cannot publish.
- [ ] Successful authoritative resource adoption validates Topic/Blitz identity.
- [ ] List/detail invalidation is narrow.

---

# 105. Acceptance Criteria — Mobile / Accessibility

- [ ] Mobile cannot render Create/Edit/Question authoring.
- [ ] Mobile authoring routes normalize to supported read locations.
- [ ] Read-only FE-001 Blitz detail remains mobile-supported.
- [ ] Form errors focus correctly.
- [ ] Controls are keyboard usable.
- [ ] Busy state visible/semantic.
- [ ] Long text/desktop narrow width does not overflow.
- [ ] State is not color-only.

---

# 106. Scope Acceptance

- [ ] No scheduling mutation.
- [ ] No lifecycle mutation.
- [ ] No official designation mutation.
- [ ] No monitoring.
- [ ] No exception grant UI.
- [ ] No Student Blitz UI.
- [ ] No checking/scoring/result UI.
- [ ] No backend changes.
- [ ] No package/platform changes.
- [ ] Focused new tests pass.
- [ ] FE-001 regressions pass.
- [ ] Direct shared Homework regressions pass.
- [ ] Focused analyze passes.
- [ ] Format check passes.
- [ ] `git diff --check` passes.

---

# 107. Focused Diff Self-Check

Before completion confirm the diff implements only:

```text
Teacher Blitz create/edit authoring
+
selected Student/duration Builder
+
nine-type Blitz Question authoring
```

Verify specifically:

```text
scheduled_at fixed null on Create
no schedule editor
no timer-mode editor
no lifecycle controls
no official designation mutation
no duplicated Question configuration system
no duplicated Student roster selection state machine
no client scoring/timer authority
```

Confirm every changed file is necessary.

---

# 108. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. Create/Edit routes and desktop/mobile behavior;
4. form/request contract;
5. assignment/Student-picker behavior;
6. duration validation/UX;
7. official-assignment safety behavior;
8. create/edit mutation uncertainty behavior;
9. Question Builder architecture/reuse;
10. Question mutation/reconciliation behavior;
11. list/detail invalidation;
12. stale-session/route protections;
13. focused new test results;
14. FE-001 regression results;
15. directly affected Stage 6 shared regression results;
16. focused analyze result;
17. format check result;
18. `git diff --check`;
19. final `git status --short`;
20. focused scope/diff self-check;
21. any blocker/deviation.

Do not claim Stage 8 frontend complete.

After delivery ChatGPT performs read-only acceptance review.

`S08-FE-003` remains blocked until:

```text
S08-FE-002 = Accepted / Delivered
```

---

# 109. Implementation Readiness Verdict

```text
Scope / non-goals                    = RESOLVED
Create route/UX                      = RESOLVED
Edit route/UX                        = RESOLVED
Question Builder route/UX            = RESOLVED
Create payload                       = RESOLVED
PATCH changed-field payload          = RESOLVED
Schedule ownership boundary          = RESOLVED
Metadata validation                  = RESOLVED
Duration contract                    = RESOLVED
Assignment / Student picker          = RESOLVED
Official assignment safety           = RESOLVED
Fixed attempt policy                 = RESOLVED
Timer-mode exclusion                 = RESOLVED
Shared Question domain reuse         = RESOLVED
Nine-type editor reuse               = RESOLVED
Question mutation API                = RESOLVED
Question lifecycle/editability       = RESOLVED
Mutation uncertainty                 = RESOLVED
List/detail reconciliation           = RESOLVED
Session/route stale safety           = RESOLVED
Mobile authoring redirects           = RESOLVED
Accessibility/responsiveness         = RESOLVED
Focused tests                        = RESOLVED
Focused verification                 = RESOLVED

Implementation Readiness Gate        = PASS
Execution dependency                 = S08-FE-001 Accepted / Delivered
Next task after acceptance            = S08-FE-003
```
