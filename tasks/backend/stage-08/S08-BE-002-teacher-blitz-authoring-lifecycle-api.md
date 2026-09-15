# Codex Implementation Contract: S08-BE-002 — Teacher Blitz Authoring, Read, Update, Schedule and Archive API

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-BE-002` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel Teacher Blitz authoring/read/pre-activation lifecycle API` |
| Depends on | `S08-DOC-001 — Accepted / Delivered`; `S08-BE-001 — Accepted / Delivered` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` after dependencies are delivered and immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |
| Backend block checkpoint | `Stage 8 Backend Phase 2` after `S08-BE-001…010` are `Accepted / Delivered` |
| Blocks | `S08-BE-003` |

Start only when:

```text
S08-DOC-001 = Accepted / Delivered
S08-BE-001  = Accepted / Delivered
this contract remains Approved
ChatGPT has re-checked current origin/main
Git preflight is safe
```

This file is the complete task-specific implementation contract.

Do **not** create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this implementation contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. delivered `S08-BE-001` source/tests directly required by this task;
5. current Teacher Homework/Topic/Question source and tests directly required as implementation patterns;
6. current shared Question validation/writer code directly required for nested Blitz creation.

Do **not** read:

- `docs/01–09`;
- roadmap files;
- `STAGE_08_TASK_INDEX.md`;
- `S08-DOC-001`;
- previous task files;
- Stage history;
- closure reviews;
- frontend code

to discover requirements.

The contract below resolves:

- exact endpoints;
- exact list filters;
- create/update payloads;
- nested Question boundary;
- assignment/recipient behavior;
- duration behavior;
- `scheduled_at` behavior;
- Draft/Scheduled lifecycle behavior;
- archive behavior;
- authorization/Tenant isolation;
- no-op behavior;
- forward compatibility with official Blitz designation;
- concurrency/lock ordering;
- response projections;
- errors;
- acceptance criteria;
- focused tests/verification.

If delivered dependencies materially conflict with this contract, return:

```text
BLOCKED
```

with exact evidence.

Do not redesign the Stage 8 API/lifecycle independently.

---

# 3. Goal

Implement the Teacher-facing Blitz authoring/read/pre-activation lifecycle slice.

At task completion an authorized Teacher can:

```text
list Blitz tasks
create a draft Blitz
read Blitz detail
update safely editable Blitz authoring fields
schedule/reschedule a Blitz
archive a non-active Blitz or a previously closed Blitz
```

The task must establish the stable Teacher resource and request patterns needed by later:

```text
S08-BE-003 Question mutation integration
S08-BE-004 official Blitz designation + activation
S08-BE-010 monitoring
frontend Teacher Blitz work
```

This task does **not** activate or close a Blitz.

---

# 4. Included Public Endpoints

Add exactly:

```text
GET   /api/v1/teacher/blitz
POST  /api/v1/teacher/topics/{topic}/blitz
GET   /api/v1/teacher/blitz/{blitz}
PATCH /api/v1/teacher/blitz/{blitz}
POST  /api/v1/teacher/blitz/{blitz}/schedule
POST  /api/v1/teacher/blitz/{blitz}/archive
```

All live inside the existing Teacher route group:

```text
auth:sanctum
active.account
password.changed
role:teacher
```

Do not add aliases.

Do not add Topic-scoped Blitz list as a second route.

Do not add:

```text
activate
close
monitoring
attempt-exception
Student routes
```

in this task.

---

# 5. Explicit Non-Goals

Do not implement or change:

- official Blitz designation mutation;
- result-pair PUT extension;
- Blitz activation;
- timer-mode snapshot runtime;
- recipient snapshot for whole-group activation;
- official cohort establishment/reuse;
- Student active Blitz list/detail;
- Student Attempt Start/Resume;
- Student answer/file execution;
- Student Submit;
- timeout reconciliation;
- Scheduler;
- Teacher Close;
- technical Attempt exception grant;
- replacement Attempt;
- Teacher monitoring;
- Stage 9 checking/scoring;
- official scores;
- Topic result;
- frontend;
- E2E seed/harness;
- dependencies;
- `docs/01–09`;
- task/Stage bookkeeping.

Do not add:

```text
attempt_limit
normal_attempts
timer_start_mode
timer_start_mode_snapshot
question.time_limit_seconds
per-question timer
is_official
official_blitz_id
```

to Teacher-writable payloads.

Do not create:

```text
blitz_attempts
blitz_answers
```

or another Question persistence subsystem.

---

# 6. Required Reuse Boundaries

## 6.1 Shared Assessment/Question foundation

Reuse delivered:

```text
Assessment
AssessmentType::Blitz
AssessmentAssignmentMode
AssessmentAssignmentSource
QuestionAuthoringLimits
QuestionConfigurationValidator
QuestionPositionSetValidator
QuestionConfigurationWriter
AssessmentPointMath
TeacherQuestionResource
```

Nested Create questions use the existing shared Question persistence/configuration model.

Do not implement automatic checking.

## 6.2 Shared educational date-time parser

Reuse:

```text
InstitutionEducationalDateTime
```

for institution-timezone validation.

Create a Blitz-specific wrapper if useful:

```text
InstitutionBlitzScheduledAt
```

analogous to:

```text
InstitutionHomeworkDeadlineAt
```

Do not copy timezone parsing logic.

## 6.3 Shared selected-recipient mechanics

The current `TeacherHomeworkRecipients` implementation is structurally Assessment-generic.

Rename/extract it to:

```text
TeacherAssessmentRecipients
```

and update existing Homework callers to use the renamed shared helper.

Required behavior must remain byte-for-byte equivalent in business meaning for Homework:

```text
lockSelected
lockAllEligible
lockExisting
synchronize
```

No Stage 6/7 Homework behavior may change.

Do not keep two duplicated recipient services containing the same rule.

## 6.4 Nested Question request validation

Do not duplicate the current large nested Question validation algorithm independently.

Extract the task-agnostic nested Question payload validation from the existing Homework request boundary into one focused shared support/concern, conceptually:

```text
TeacherAssessmentQuestionPayloadValidator
```

or an equivalently focused name/location.

Both:

```text
TeacherHomeworkCreateRequest
TeacherBlitzCreateRequest
```

must reuse the same nested Question structural/configuration validation.

This refactor must not change the accepted/rejected Homework request contract.

Do not refactor unrelated Homework request behavior.

---

# 7. Teacher Blitz Access Boundary

Create a Blitz-specific access helper, conceptually:

```text
TeacherBlitzAccess
```

Do not make Blitz lifecycle behavior flow through `TeacherHomeworkAccess`.

The helper must provide privacy-safe, Tenant-first resolution for:

```text
Topic
Blitz Assessment
BlitzTask
current Teacher–Group membership
```

## 7.1 Topic visibility

A Teacher may create/manage Blitz only inside:

```text
teacher.institution_id
+
Topic.teacher_id = teacher.id
+
current Teacher membership in Topic.group_id
```

Malformed Topic UUID, foreign Institution, another Teacher's Topic, or Topic whose Group is no longer assigned to the Teacher:

```text
404 resource_not_found
```

## 7.2 Blitz visibility

`{blitz}` must resolve only when all are true:

```text
assessment.institution_id = teacher.institution_id
assessment.teacher_id     = teacher.id
assessment.type           = blitz
Assessment Topic is visibleToTeacher(teacher)
paired blitz_tasks row exists in same Institution
```

Malformed, foreign-Tenant, another Teacher's, no-longer-assigned, non-Blitz Assessment, or structurally missing BlitzTask:

```text
404 resource_not_found
```

Do not expose which condition failed.

---

# 8. Deterministic Lock Order

All mutations must re-resolve current state under locks.

Use this common parent-first ordering where the participating rows exist:

```text
1. Group
2. current Teacher–Group membership
3. Topic
4. Assessment
5. BlitzTask
6. TopicResultPair when needed
7. AssessmentAttempts ordered by id when needed
8. existing AssessmentStudents ordered by student_id when needed
9. selected Student users/memberships ordered deterministically when needed
```

Create has no Assessment/Blitz row yet, so it begins with:

```text
Group
→ membership
→ Topic
→ selected Students/memberships when applicable
→ create Assessment
→ create BlitzTask
→ create selected recipients
→ create Questions
```

Later Stage 8 activation must be able to use the same parent ordering.

Do not lock rows globally without Tenant scope.

---

# 9. Topic Lifecycle Boundary

## 9.1 Create

Teacher may create a Blitz only when Topic is:

```text
draft
active
```

For Topic:

```text
closed
archived
```

return:

```text
409 topic_not_editable
```

## 9.2 Update / Schedule

Update and Schedule are allowed only while the owning Topic is:

```text
draft
active
```

For Topic:

```text
closed
archived
```

return:

```text
409 topic_not_editable
```

## 9.3 Read

List/detail may read authorized historical Blitz under Topic states:

```text
draft
active
closed
archived
```

subject to current Teacher authorization scope.

## 9.4 Archive

Archiving a Blitz is allowed even when the Topic itself is already closed/archived, provided the Blitz's own archive rules pass.

Archive is historical housekeeping and does not edit Topic learning meaning.

---

# 10. Teacher Blitz List

## 10.1 Endpoint

```text
GET /api/v1/teacher/blitz
```

No request body.

## 10.2 Accepted query keys only

```text
topic_id
group_id
status
page
per_page
```

Unknown query parameter:

```text
422 validation_failed
```

Body present:

```text
422 validation_failed
```

## 10.3 Validation

```text
topic_id  = optional UUID string
group_id  = optional UUID string
status    = optional BlitzStatus
page      = optional integer >= 1
per_page  = optional integer 1..100
```

Defaults:

```text
page = 1
per_page = 20
```

## 10.4 Filter authorization

If `group_id` is supplied, first require it to be a Group currently readable by the Teacher through current Teacher membership.

Inaccessible/malformed Group:

```text
404 resource_not_found
```

If `topic_id` is supplied, require it to be an authorized Topic visible to the Teacher.

Inaccessible/malformed Topic:

```text
404 resource_not_found
```

If both filters are individually authorized but:

```text
topic.group_id != group_id
```

return a normal empty paginated collection.

Do not leak unrelated data.

## 10.5 Query scope

List only:

```text
Assessment.type = blitz
Assessment.institution_id = Teacher Institution
Assessment.teacher_id = Teacher
Assessment Topic currently visible to Teacher
BlitzTask exists in same Institution
```

Apply optional filters:

```text
topic_id
topic.group_id
blitz_tasks.status
```

## 10.6 Ordering

No public sort/direction query is added in Stage 8.

Use deterministic:

```text
assessments.created_at DESC
assessments.id DESC
```

## 10.7 Performance

Use server-side filtering/pagination.

Load only required list relations/fields.

Use:

```text
withCount('questions')
```

or equivalent.

Do not load all Questions/configuration for list rows.

No N+1.

---

# 11. Teacher Blitz List Resource

Each list item returns exactly the stable authoring summary fields:

```json
{
  "id": "blitz-uuid",
  "topic_id": "topic-uuid",
  "group_id": "group-uuid",
  "title": "Topic Blitz",
  "assignment_mode": "group",
  "total_possible_points": 3.0,
  "question_count": 3,
  "duration_seconds": 600,
  "scheduled_at": null,
  "institution_timezone": "Asia/Tashkent",
  "status": "draft",
  "created_at": "2026-09-14T17:00:00Z",
  "updated_at": "2026-09-14T17:00:00Z"
}
```

Collection envelope uses the existing pagination shape:

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

All server timestamps:

```text
UTC RFC3339 ...Z
```

---

# 12. Create Blitz

## 12.1 Endpoint

```text
POST /api/v1/teacher/topics/{topic}/blitz
```

Request must be:

```text
Content-Type: application/json
```

and one JSON object.

No query parameters.

## 12.2 Accepted top-level keys only

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

Reject all other keys with:

```text
422 validation_failed
```

This explicitly rejects protected/unsupported fields such as:

```text
id
institution_id
topic_id
teacher_id
type
status
total_possible_points
attempt_limit
normal_attempts
timer_start_mode
timer_start_mode_snapshot
activated_at
synchronized_ends_at
closed_at
archived_at
activated_by_user_id
created_at
updated_at
```

## 12.3 Required/optional fields

Required:

```text
title
student_instructions
assignment_mode
student_ids
duration_seconds
```

Optional:

```text
description
scheduled_at
questions
```

Defaults:

```text
description = null
scheduled_at = null
questions = []
```

## 12.4 Common field validation

```text
title:
  string
  trim before validation/persistence
  non-empty
  max 255

description:
  nullable string
  max 10000

student_instructions:
  string
  trim before validation/persistence
  non-empty
  max 10000

assignment_mode:
  group | selected_students

student_ids:
  JSON array
  UUID strings
  case-insensitive duplicate UUIDs rejected

duration_seconds:
  JSON integer
  >= 1
  <= PostgreSQL integer max
```

Do not impose a product maximum such as 5 or 10 minutes.

`600` in examples/factories is not a runtime default.

---

# 13. Create Assignment Rules

## 13.1 Group

For:

```text
assignment_mode = group
```

require exactly:

```json
"student_ids": []
```

No `assessment_students` recipient rows are created at Draft creation for group mode.

The group recipient snapshot belongs to activation (`S08-BE-004`).

## 13.2 Selected Students

For:

```text
assignment_mode = selected_students
```

require:

```text
student_ids non-empty
```

Every supplied Student must currently be:

```text
same Institution
role = student
is_active = true
current member of Topic Group
```

Resolve/lock deterministically.

If any supplied ID is invalid/ineligible/foreign/non-member/inactive/non-Student:

```text
422 validation_failed
```

with one privacy-safe `student_ids` error.

Do not reveal which foreign/private ID exists.

Persist selected recipients immediately:

```text
assessment_students.assignment_source = direct
```

Selected-Student Blitz is practice/supplementary.

This task does not mark it official.

---

# 14. `scheduled_at` Create Contract

`scheduled_at` is optional.

When supplied non-null:

- it must be a string;
- exact RFC3339 local date-time with explicit numeric offset;
- local date/time and offset must correspond to the Institution IANA timezone;
- parse to authoritative UTC;
- after acquiring required authoring locks, require:

```text
scheduledAt > server_now
```

Past/equal schedule:

```text
422 validation_failed
```

field:

```text
scheduled_at
```

Important:

> Create always returns a `draft` Blitz, even when `scheduled_at` is supplied.

Therefore:

```text
status = draft
scheduled_at = parsed future instant or null
```

A prepared `scheduled_at` value does **not** itself schedule or activate the task.

Only:

```text
POST /teacher/blitz/{blitz}/schedule
```

changes lifecycle to `scheduled`.

This rule matches the Stage 8 persistence contract where Draft may retain an optional prepared `scheduled_at`.

---

# 15. Nested Questions on Create

`questions` is optional and may be an empty JSON array.

Maximum count must reuse:

```text
QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT
```

Each nested Question uses the exact current Teacher Question authoring model.

Required request-local fields:

```text
client_key
type
prompt
points
position
checking_mode
configuration
```

Optional:

```text
instructions
```

Rules:

- `client_key` is request-local only;
- do not persist/return `client_key`;
- allowed Question types are the delivered nine `QuestionType` values;
- checking-mode/type compatibility uses delivered `QuestionConfigurationValidator`;
- point precision/range uses delivered `AssessmentPointMath`;
- positions are exact contiguous `1..N`;
- nested configuration uses existing exact structures;
- no Question `time_limit_seconds`;
- no per-question Blitz timer.

Create must use the shared:

```text
QuestionConfigurationWriter
```

for persistence.

Compute:

```text
Assessment.total_possible_points
```

from the supplied Question points server-side.

Do not accept it from request.

Empty Questions:

```text
total_possible_points = 0
```

is valid for Draft.

Activation later requires a positive recalculated total.

---

# 16. Create Persistence Transaction

Inside one transaction:

1. resolve preliminary authorized Topic;
2. lock Group;
3. lock current Teacher membership;
4. lock Topic;
5. re-check Topic `draft|active`;
6. validate/lock selected Student set when applicable;
7. parse/re-check `scheduled_at` against one captured server instant when non-null;
8. calculate total points;
9. create one `assessments` row:
   ```text
   type = blitz
   institution_id = Teacher Institution
   topic_id = Topic
   teacher_id = Teacher
   request common fields
   total_possible_points = server calculated
   ```
10. create one `blitz_tasks` row:
    ```text
    assessment_id = Assessment ID
    institution_id = Teacher Institution
    status = draft
    duration_seconds = request
    scheduled_at = parsed value/null
    timer_start_mode_snapshot = null
    activated_at = null
    synchronized_ends_at = null
    closed_at = null
    archived_at = null
    activated_by_user_id = null
    ```
11. for selected mode, create exact Direct recipient rows;
12. create nested Questions/configuration;
13. return the complete Teacher Blitz resource.

Any failure rolls back the whole create.

## 16.1 Success

```text
201 Created
```

Message:

```text
Blitz task created successfully.
```

---

# 17. Blitz Detail

## 17.1 Endpoint

```text
GET /api/v1/teacher/blitz/{blitz}
```

No query parameters.

No request body.

Unknown query/body:

```text
422 validation_failed
```

Use privacy-safe resolution from Section 7.

## 17.2 Required detail projection

Load without N+1:

```text
BlitzTask
Topic group_id
selected recipients ordered by student_id
Questions ordered by position
all Question configuration required by TeacherQuestionResource
Institution timezone
```

---

# 18. Full Teacher Blitz Resource

Return:

```json
{
  "data": {
    "id": "blitz-uuid",
    "topic_id": "topic-uuid",
    "group_id": "group-uuid",
    "title": "Topic Blitz",
    "description": null,
    "student_instructions": "Answer independently.",
    "assignment_mode": "group",
    "student_ids": [],
    "total_possible_points": 3.0,
    "duration_seconds": 600,
    "scheduled_at": null,
    "institution_timezone": "Asia/Tashkent",
    "status": "draft",
    "timer_start_mode_snapshot": null,
    "attempt_policy": {
      "normal_attempts": 1,
      "max_additional_exception_attempts": 1
    },
    "activated_at": null,
    "synchronized_ends_at": null,
    "closed_at": null,
    "archived_at": null,
    "created_at": "2026-09-14T17:00:00Z",
    "updated_at": "2026-09-14T17:00:00Z",
    "questions": []
  }
}
```

For:

```text
assignment_mode = selected_students
```

`student_ids` is the sorted persisted Direct recipient ID set.

For:

```text
assignment_mode = group
```

`student_ids` is always:

```json
[]
```

even if future activation creates whole-group recipient snapshot rows.

Teacher monitoring later owns participant projection.

Do not expose:

```text
institution_id
teacher_id
activated_by_user_id
internal recipient row IDs
Attempt rows
correct-answer data outside Teacher Question resource
scores/results
```

Question configuration is Teacher-authoring data and may include answer-key configuration through the existing `TeacherQuestionResource`.

---

# 19. Update Blitz

## 19.1 Endpoint

```text
PATCH /api/v1/teacher/blitz/{blitz}
```

Request must be an `application/json` object.

No query parameters.

At least one accepted field is required.

## 19.2 Accepted fields only

```text
title
description
student_instructions
assignment_mode
student_ids
duration_seconds
```

`scheduled_at` is intentionally **not** mutated by PATCH.

Use the dedicated Schedule endpoint for scheduling/rescheduling.

Create may accept a prepared `scheduled_at`, but after creation the lifecycle-specific schedule operation owns schedule mutation.

Reject:

```text
questions
scheduled_at
status
attempt_limit
timer_start_mode
timer_start_mode_snapshot
total_possible_points
lifecycle timestamps
ownership fields
```

with:

```text
422 validation_failed
```

Dedicated Question mutation belongs to `S08-BE-003`.

## 19.3 Field validation

Same common validation as Create for any supplied field.

`duration_seconds`:

```text
integer >= 1
```

No product hard maximum.

`student_ids` duplicate/UUID shape validation remains strict.

## 19.4 Editable Blitz states

Authoring PATCH is allowed only when Blitz status is:

```text
draft
scheduled
```

For:

```text
active
```

return:

```text
409 business_conflict
```

For:

```text
closed
```

return:

```text
409 task_closed
```

For:

```text
archived
```

return:

```text
409 task_archived
```

The owning Topic must still be `draft|active`.

## 19.5 Defensive no-activity rule

Under lock, require zero `assessment_attempts` rows for the Blitz.

Any Attempt on a Draft/Scheduled Blitz indicates historical/integrity state that must not be reinterpreted.

Return:

```text
409 business_conflict
```

Do not delete/repair Attempts.

## 19.6 Resulting assignment state

Calculate the complete resulting state from current persisted values plus supplied fields.

Require exactly:

```text
group
  => student_ids = []

selected_students
  => student_ids non-empty
```

If the partial PATCH would produce an inconsistent pair:

```text
422 validation_failed
```

If selected mode is resulting state, validate/lock every resulting Student against the current authorized Topic Group.

## 19.7 Recipient synchronization

When resulting mode is:

```text
selected_students
```

persist exact Direct recipient set.

When resulting mode is:

```text
group
```

remove pre-activation Direct selected-recipient rows.

Do not create group snapshot rows.

Whole-group snapshot remains activation work.

## 19.8 Future official-Blitz compatibility

The action must already be safe after `S08-BE-004` begins populating:

```text
topic_result_pairs.blitz_assessment_id
```

Lock the Topic result pair when one may reference this Blitz.

If this Blitz is the official Blitz:

```text
pair.blitz_assessment_id = assessment.id
```

then it must remain:

```text
assignment_mode = group
```

A resulting change to:

```text
selected_students
```

returns:

```text
409 official_task_requires_group_assignment
```

This remains true whether pair `locked_at` is null or non-null.

A locked pair does **not** by itself forbid safe pre-activation metadata/duration edits when:

```text
Blitz = draft|scheduled
no Blitz Attempt exists
assignment remains group
official identity/cohort is unchanged
```

Do not mutate the pair in this task.

## 19.9 Questions and total points

PATCH does not mutate Questions.

PATCH does not recalculate or overwrite:

```text
total_possible_points
```

`S08-BE-003` owns dedicated Question mutation and corresponding total-point maintenance.

## 19.10 Semantic no-op

If resulting values equal persisted semantic values:

- return `200`;
- return current resource;
- perform no writes;
- do not change:
  ```text
  assessments.updated_at
  blitz_tasks.updated_at
  assessment_students
  ```

Comparison of Student IDs is canonical set comparison.

---

# 20. Schedule Blitz

## 20.1 Endpoint

```text
POST /api/v1/teacher/blitz/{blitz}/schedule
```

Request must be exactly:

```json
{
  "scheduled_at": "2026-09-15T09:00:00+05:00"
}
```

Required:

```text
Content-Type: application/json
```

No query parameters.

No other JSON keys.

## 20.2 Validation

`scheduled_at`:

- required;
- string;
- RFC3339 with explicit numeric offset;
- must match Institution IANA timezone;
- after locking current state, parsed instant must satisfy:

```text
scheduledAt > transitionedAt
```

where:

```text
transitionedAt = one captured server_now
```

Past/equal:

```text
422 validation_failed
```

## 20.3 Allowed source states

Allowed:

```text
draft
scheduled
```

For:

```text
active
```

return:

```text
409 business_conflict
```

For:

```text
closed
```

return:

```text
409 task_closed
```

For:

```text
archived
```

return:

```text
409 task_archived
```

Owning Topic must be `draft|active`.

## 20.4 Defensive Attempt rule

Require no Assessment Attempt rows.

If any exist:

```text
409 business_conflict
```

No repair/deletion.

## 20.5 Draft → Scheduled

Set:

```text
status = scheduled
scheduled_at = parsed instant
updated_at = transitionedAt
```

and:

```text
assessment.updated_at = transitionedAt
```

Preserve:

```text
timer_start_mode_snapshot = null
activated_at = null
synchronized_ends_at = null
closed_at = null
archived_at = null
activated_by_user_id = null
```

Do not:

- activate;
- snapshot Institution timer mode;
- create group recipients;
- validate scoreable points;
- create Attempts.

## 20.6 Scheduled → Scheduled reschedule

If parsed instant differs:

```text
status remains scheduled
scheduled_at = new instant
updated_at = transitionedAt
assessment.updated_at = transitionedAt
```

If it is the exact same instant:

- return current resource;
- perform no writes;
- no timestamp churn.

## 20.7 Success

```text
200 OK
```

Message:

```text
Blitz task scheduled successfully.
```

---

# 21. Archive Blitz

## 21.1 Endpoint

```text
POST /api/v1/teacher/blitz/{blitz}/archive
```

Body:

```text
empty
```

or:

```json
{}
```

No query parameters.

Reuse the established empty lifecycle-request convention.

No `Idempotency-Key` is required.

## 21.2 Allowed state behavior

### Already archived

Idempotent domain success:

- `200 OK`;
- current resource;
- no writes;
- no timestamp churn.

### Active

Reject:

```text
409 business_conflict
```

The Teacher must use future Close behavior before archive.

This task does not close automatically.

### Draft / Scheduled

May archive only when:

- no Assessment Attempt exists;
- this Blitz is not currently the designated official Blitz.

If:

```text
topic_result_pairs.blitz_assessment_id = assessment.id
```

return:

```text
409 business_conflict
```

The official relationship must not silently point at a newly archived pre-activation task.

Do not clear the pair.

### Closed

May archive only when no `in_progress` Attempt remains.

If an in-progress Attempt exists:

```text
409 business_conflict
```

Do not finalize it here.

Future Close/finalization owns that invariant.

A closed official Blitz may be archived because official historical identity remains valid and is preserved.

## 21.3 Transition

Capture:

```text
archivedAt = server_now
```

Set:

```text
status = archived
archived_at = archivedAt
blitz_tasks.updated_at = archivedAt
assessments.updated_at = archivedAt
```

Preserve all historical fields:

```text
scheduled_at
timer_start_mode_snapshot
activated_at
synchronized_ends_at
closed_at
activated_by_user_id
```

according to the already-valid source history.

Do not delete:

- recipients;
- Questions;
- Attempts;
- answers/files;
- exception rows;
- result pair;
- scores/results.

## 21.4 Success

```text
200 OK
```

Message:

```text
Blitz task archived successfully.
```

---

# 22. No Activation Dependency on Institution Timer Setting

This task must not require:

```text
institution_settings.blitz_timer_start_mode
```

to be configured for:

- list;
- create;
- detail;
- update;
- schedule;
- archive.

A null timer-start mode blocks only future activation.

Do not return:

```text
institution_settings_incomplete
```

from these authoring/preparation endpoints solely because the timer mode is null.

---

# 23. Controller Boundary

Create one thin controller, conceptually:

```text
TeacherBlitzController
```

Methods:

```text
index
store
show
update
schedule
archive
```

Each method:

1. receives validated request;
2. gets authenticated `User`;
3. invokes one focused Action;
4. returns Resource/Collection response.

No authorization queries, transactions, lifecycle logic, or recipient synchronization in Controller.

---

# 24. Required Actions

Create focused Actions:

```text
ListTeacherBlitz
CreateTeacherBlitz
ShowTeacherBlitz
UpdateTeacherBlitz
ScheduleTeacherBlitz
ArchiveTeacherBlitz
```

Do not create one broad `BlitzService`.

Do not put workflow logic in Models/Resources.

---

# 25. Required Requests

Create focused Form Requests, conceptually:

```text
TeacherBlitzIndexRequest
TeacherBlitzCreateRequest
TeacherBlitzShowRequest
TeacherBlitzUpdateRequest
TeacherBlitzScheduleRequest
TeacherBlitzLifecycleRequest
```

`TeacherBlitzLifecycleRequest` may reuse the same empty-body mechanics as `TeacherTopicLifecycleRequest`.

Do not use request validation to perform Tenant database authorization.

Persisted-state/lifecycle decisions belong in Actions.

---

# 26. Resource Classes

Create:

```text
TeacherBlitzResource
TeacherBlitzListResource
TeacherBlitzCollection
```

Use existing Homework resource/collection conventions.

Resources:

- serialize already-resolved state;
- must not run hidden queries;
- must not authorize;
- must not calculate lifecycle;
- must not expose internal protected columns.

---

# 27. Authoritative Timestamp Serialization

All returned authoritative instants:

```text
UTC RFC3339 with Z
```

For example:

```text
2026-09-15T04:00:00Z
```

Teacher resource also returns:

```text
institution_timezone
```

for educational schedule display.

Do not serialize according to arbitrary device timezone.

---

# 28. Error Contract

Use existing error infrastructure.

Required expected behavior includes:

| Condition | HTTP / code |
|---|---|
| malformed/private Topic/Blitz/Group direct ID | `404 resource_not_found` |
| unauthenticated | existing `401 authentication_required` |
| wrong role | existing authorization behavior |
| invalid/unknown request/query field | `422 validation_failed` |
| invalid selected Student set | `422 validation_failed` |
| invalid/past `scheduled_at` | `422 validation_failed` |
| Topic closed/archived on create/update/schedule | `409 topic_not_editable` |
| Active Blitz PATCH/Schedule/Archive conflict | `409 business_conflict` |
| Closed Blitz PATCH/Schedule | `409 task_closed` |
| Archived Blitz PATCH/Schedule | `409 task_archived` |
| Official Blitz changed to selected_students | `409 official_task_requires_group_assignment` |
| Pre-activation official Blitz archive | `409 business_conflict` |
| unexpected Attempt/history inconsistency | `409 business_conflict` |

Do not add a new machine code when an approved existing code fits.

Do not expose SQL/constraint/internal-class details.

---

# 29. Assignment and Membership Concurrency

Create/Update must be safe if, concurrently:

- Teacher–Group membership ends;
- selected Student membership ends;
- selected Student becomes inactive;
- Topic lifecycle changes;
- another Blitz mutation targets the same task.

Required:

- preliminary privacy-safe resolution;
- transaction;
- deterministic parent locks from Section 8;
- re-read/re-check under locks;
- no partial recipient mutation;
- no cross-Tenant recipient link.

If the locked current state no longer permits the operation, fail safely and roll back.

---

# 30. Update / Schedule / Archive Concurrency

All three mutate the same:

```text
Assessment
BlitzTask
```

under the same deterministic parent lock order.

Required outcomes:

## 30.1 Update vs Schedule

Whichever obtains/commits the locked task first is visible to the second.

Second request re-evaluates current status/state.

No lost update.

## 30.2 Update vs future Activation

This task must lock in a way compatible with future `S08-BE-004`.

If Activation commits first:

```text
Update re-reads active and rejects
```

If Update commits first:

```text
Activation later validates the updated definition
```

## 30.3 Schedule vs future Activation

If Activation commits first:

```text
Schedule rejects active
```

If Schedule commits first:

```text
Activation later sees scheduled state/time
```

Scheduling never restarts/controls the future timer itself.

## 30.4 Archive vs future Activation

If Archive commits first:

```text
Activation later rejects archived
```

If Activation commits first:

```text
Archive re-reads active and rejects
```

## 30.5 Repeated same operation

No-op/idempotent lifecycle semantics must not churn timestamps.

---

# 31. Required Shared-Helper Refactor Regression Safety

Because this task renames/extracts shared recipient/question payload mechanics, preserve existing Homework behavior exactly.

## 31.1 Recipient helper

After refactor:

```text
CreateTeacherHomework
UpdateTeacherHomework
```

must behave exactly as before for:

- group mode;
- selected_students;
- active Student/group membership validation;
- recipient synchronization;
- validation failure behavior.

Do not change Homework API fields/messages/codes intentionally.

## 31.2 Nested Question validator

Current Homework Create must still accept/reject the exact same nested Question payloads.

No Question configuration rule changes are authorized.

No Stage 6 Question mutation rule changes are authorized.

---

# 32. Suggested File Scope

Exact filenames may follow existing repository naming, but expected scope is:

## Create

```text
backend/app/Actions/Teacher/ListTeacherBlitz.php
backend/app/Actions/Teacher/CreateTeacherBlitz.php
backend/app/Actions/Teacher/ShowTeacherBlitz.php
backend/app/Actions/Teacher/UpdateTeacherBlitz.php
backend/app/Actions/Teacher/ScheduleTeacherBlitz.php
backend/app/Actions/Teacher/ArchiveTeacherBlitz.php

backend/app/Http/Controllers/Api/V1/Teacher/TeacherBlitzController.php

backend/app/Http/Requests/Teacher/TeacherBlitzIndexRequest.php
backend/app/Http/Requests/Teacher/TeacherBlitzCreateRequest.php
backend/app/Http/Requests/Teacher/TeacherBlitzShowRequest.php
backend/app/Http/Requests/Teacher/TeacherBlitzUpdateRequest.php
backend/app/Http/Requests/Teacher/TeacherBlitzScheduleRequest.php
backend/app/Http/Requests/Teacher/TeacherBlitzLifecycleRequest.php

backend/app/Http/Resources/Teacher/TeacherBlitzCollection.php
backend/app/Http/Resources/Teacher/TeacherBlitzListResource.php
backend/app/Http/Resources/Teacher/TeacherBlitzResource.php

backend/app/Support/Teacher/TeacherBlitzAccess.php
backend/app/Support/Teacher/InstitutionBlitzScheduledAt.php

backend/app/Support/Assessment/TeacherAssessmentQuestionPayloadValidator.php
  or equivalent single shared extraction

backend/app/Support/Teacher/TeacherAssessmentRecipients.php
```

## Rename/remove

Replace delivered:

```text
TeacherHomeworkRecipients
```

with shared:

```text
TeacherAssessmentRecipients
```

and update only direct callers/tests.

## Modify narrowly

```text
backend/routes/api.php

backend/app/Actions/Teacher/CreateTeacherHomework.php
backend/app/Actions/Teacher/UpdateTeacherHomework.php
backend/app/Http/Requests/Teacher/TeacherHomeworkMutationRequest.php
```

only as required by the shared helper/validator extraction.

## Tests

Create focused Stage 8 tests such as:

```text
backend/tests/Feature/Teacher/TeacherBlitzAuthoringApiTest.php
backend/tests/Feature/Teacher/TeacherBlitzAuthorizationApiTest.php
backend/tests/Feature/Teacher/TeacherBlitzScheduleArchiveApiTest.php
backend/tests/Feature/Teacher/TeacherBlitzPreparationConcurrencyTest.php
```

Changes outside these areas require concrete necessity and must be reported.

Do not change:

```text
migrations from BE-001
Question persistence schema
Student controllers/actions
Scheduler
frontend
docs
tasks
seeders
dependencies
```

---

# 33. Required Focused Test Coverage

## 33.1 List

Verify:

- Teacher sees only own authorized Blitz;
- no Homework leaks into list;
- cross-Institution Blitz excluded;
- another Teacher's Blitz excluded;
- no-longer-assigned Topic Blitz excluded;
- `topic_id` filter;
- `group_id` filter;
- combined compatible filters;
- combined accessible-but-mismatched filters return empty;
- status filter;
- pagination;
- deterministic ordering;
- unknown query rejected;
- request body rejected;
- malformed/inaccessible filter UUID behavior.

## 33.2 Create

Verify:

- group Draft create;
- selected-Student Draft create;
- selected recipients persisted as Direct;
- group create creates no recipients;
- create with optional future `scheduled_at` remains Draft;
- create without `scheduled_at`;
- duration positive integer;
- no product hard duration default;
- empty Questions allowed;
- nested supported Question persists with derived total;
- malformed/unknown/protected fields rejected;
- `attempt_limit`, `timer_start_mode`, `status`, `total_possible_points` rejected;
- group requires empty `student_ids`;
- selected requires non-empty;
- duplicate Student IDs rejected;
- inactive/non-member/foreign/wrong-role selected Student rejected safely;
- Topic closed/archived rejected;
- foreign/another Teacher/no-membership Topic returns 404;
- atomic rollback on nested Question persistence failure.

## 33.3 Detail

Verify:

- complete exact resource shape;
- group_id comes from Topic;
- selected Student IDs sorted;
- group resource returns `student_ids = []`;
- questions include Teacher authoring configuration;
- fixed Attempt policy:
  ```text
  1 normal
  max 1 additional exception
  ```
- no internal ownership/recipient IDs;
- privacy-safe direct IDs;
- no N+1 regression for required projection where query assertions are established.

## 33.4 Update

Verify:

- Draft metadata update;
- Scheduled metadata/duration update;
- duration update;
- selected Student set replacement;
- selected → group clears Direct recipients;
- group → selected creates Direct recipients;
- resulting assignment-state validation;
- exact no-op has no timestamp churn;
- Questions rejected from PATCH;
- `scheduled_at` rejected from PATCH;
- protected fields rejected;
- Active update conflict;
- Closed update conflict;
- Archived update conflict;
- Topic closed/archived blocks update;
- unexpected Attempts block update;
- forward-compatible official Blitz cannot become selected_students.

For official-Blitz forward-compat test, a structural `topic_result_pairs` fixture with this Blitz ID is allowed; this task does not expose designation API.

## 33.5 Schedule

Verify:

- Draft → Scheduled;
- Draft with prefilled `scheduled_at` → Scheduled;
- Scheduled → rescheduled;
- same Scheduled instant no-op/no timestamp churn;
- exact Institution timezone input accepted;
- wrong offset/local mapping rejected;
- malformed date rejected;
- past/equal server time rejected;
- Active/Closed/Archived rejected correctly;
- Topic closed/archived rejected;
- scheduling does not:
  - activate;
  - snapshot timer mode;
  - create group recipients;
  - create Attempts;
- null institution `blitz_timer_start_mode` does not block scheduling.

## 33.6 Archive

Verify:

- Draft practice Blitz archive;
- Scheduled practice Blitz archive;
- Closed Blitz archive;
- already Archived returns no-op success/no timestamp churn;
- Active archive rejected;
- Draft/Scheduled official Blitz archive rejected;
- Closed official Blitz may archive and pair remains unchanged;
- unexpected Attempt on Draft/Scheduled blocks;
- in-progress Attempt on Closed blocks;
- recipients/Questions/history preserved;
- no automatic Close/finalization occurs;
- null Institution timer mode does not block archive.

## 33.7 Authorization

For list/create/detail/update/schedule/archive cover relevant:

- unauthenticated;
- non-Teacher role;
- foreign Institution;
- another Teacher;
- ended Teacher–Group membership;
- direct UUID probing;
- selected Student cross-Tenant/privacy.

---

# 34. Focused Concurrency Test

Use the repository's existing PostgreSQL concurrency-test pattern.

Prove at least one conflicting preparation lifecycle pair on the same Blitz, for example:

```text
Schedule vs Archive
```

or:

```text
Update vs Archive
```

Required invariant:

- both do not commit incompatible state;
- one locked current state wins;
- loser/retry sees committed current lifecycle and returns the allowed outcome;
- no partial recipient/config mutation;
- final `blitz_tasks` row satisfies BE-001 lifecycle checks.

Do not build activation concurrency in this task.

`S08-BE-004` owns Activation races.

---

# 35. Directly Affected Homework Regression

Because of the shared-recipient and shared-question-payload extraction, run:

```bash
php artisan test \
  tests/Feature/Teacher/TeacherHomeworkAuthoringApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkAuthorizationApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkRecipientApiTest.php
```

If the exact current repository uses a different direct recipient-test filename, use the delivered corresponding Teacher Homework recipient test and report the exact command.

Do not broaden to all Homework/Student tests unless a concrete changed shared file requires it.

---

# 36. Task Verification Commands

Run from:

```text
backend/
```

## 36.1 New focused tests

```bash
php artisan test \
  tests/Feature/Teacher/TeacherBlitzAuthoringApiTest.php \
  tests/Feature/Teacher/TeacherBlitzAuthorizationApiTest.php \
  tests/Feature/Teacher/TeacherBlitzScheduleArchiveApiTest.php \
  tests/Feature/Teacher/TeacherBlitzPreparationConcurrencyTest.php
```

## 36.2 Direct Homework regression

```bash
php artisan test \
  tests/Feature/Teacher/TeacherHomeworkAuthoringApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkAuthorizationApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkRecipientApiTest.php
```

## 36.3 Format

```bash
./vendor/bin/pint --test
```

No additional static-analysis command is required unless already mandatory for exactly the changed backend scope.

## 36.4 Always

From repository root:

```bash
git diff --check
```

Do not run:

- full backend suite;
- frontend tests;
- Flutter analyze/build;
- broad E2E;
- Stage integration harness.

Full backend regression belongs to:

```text
S08-BE-PHASE-2
```

---

# 37. Acceptance Criteria

## API surface

- [ ] Exactly six Teacher Blitz endpoints from Section 4 exist.
- [ ] No activation/close/monitoring/Student endpoint is added.
- [ ] Existing Teacher middleware boundary is reused.

## List

- [ ] Exact five query keys only.
- [ ] Tenant/Teacher/current-membership scope enforced before exposure.
- [ ] Pagination is server-side.
- [ ] Deterministic created-at/id ordering.
- [ ] Topic/Group/status filtering correct.
- [ ] No N+1 list behavior.

## Create

- [ ] Creates `Assessment.type = blitz`.
- [ ] Creates one `BlitzTask.status = draft`.
- [ ] Duration required positive integer.
- [ ] Optional `scheduled_at` may be stored while status remains Draft.
- [ ] Prepared schedule must be future and institution-timezone valid.
- [ ] Group mode creates no recipient rows.
- [ ] Selected mode creates exact Direct recipients.
- [ ] Nested Questions use shared validator/writer.
- [ ] `total_possible_points` is derived.
- [ ] Empty Questions/zero points allowed in Draft.
- [ ] No timer-mode snapshot at create.
- [ ] Atomic transaction.

## Detail/resource

- [ ] Stable full Teacher resource matches Section 18.
- [ ] Attempt policy fixed at 1 + max 1 exception.
- [ ] Teacher Question configuration returned.
- [ ] Internal Tenant/actor/recipient row IDs hidden.
- [ ] UTC timestamps + institution timezone.

## Update

- [ ] Draft/Scheduled only.
- [ ] Questions not mutated by PATCH.
- [ ] Schedule not mutated by PATCH.
- [ ] Assignment result validated.
- [ ] Direct recipients synchronized.
- [ ] Group mode has no preactivation group snapshot.
- [ ] Official Blitz remains whole-group.
- [ ] No Attempt/history reinterpretation.
- [ ] Semantic no-op does not churn timestamps.

## Schedule

- [ ] Draft/Scheduled only.
- [ ] Future institution-timezone instant required.
- [ ] Draft transitions to Scheduled.
- [ ] Scheduled may reschedule.
- [ ] Same scheduled target no-op.
- [ ] Does not activate/snapshot timer/create Attempts/whole-group recipients.
- [ ] Missing Institution timer mode does not block it.

## Archive

- [ ] Active must be closed first.
- [ ] Draft/Scheduled practice task may archive.
- [ ] Pre-activation official Blitz cannot archive.
- [ ] Closed task may archive when no in-progress Attempt.
- [ ] Closed official task may archive without clearing pair/history.
- [ ] Repeat Archive no-op/timestamp stable.
- [ ] Historical data preserved.

## Architecture/reuse

- [ ] No Blitz code routes through Homework lifecycle/access logic.
- [ ] Generic recipient helper extracted/renamed once; no duplicate recipient rule.
- [ ] Nested Question payload validation is shared rather than independently duplicated.
- [ ] Homework semantics remain unchanged.
- [ ] Models/Resources remain free of workflow logic.

## Security

- [ ] Tenant-first direct-ID resolution.
- [ ] Another Teacher/Institution/no-membership resources privacy-safe.
- [ ] Selected Students same Institution/group/current/active.
- [ ] UUID knowledge does not grant access.

## Concurrency

- [ ] Mutations re-read under locks.
- [ ] Schedule/Update/Archive cannot commit incompatible concurrent histories.
- [ ] Lock order is deterministic and future Activation-compatible.

## Verification/scope

- [ ] Focused Blitz tests pass.
- [ ] Direct Homework regressions pass.
- [ ] Pint passes.
- [ ] `git diff --check` passes.
- [ ] No docs/frontend/dependency/migration modification.
- [ ] No Stage 8 Student execution or Stage 9 scoring leaks into task.

---

# 38. Focused Diff Self-Check

Before completion verify:

```text
Teacher Blitz authoring/read/update/schedule/archive only
```

Confirm no implementation of:

- Activate;
- Close;
- monitoring;
- exception grant;
- Student Start;
- Student answer/file;
- Submit;
- timeout;
- Scheduler;
- scoring/checking;
- official-pair mutation.

Confirm:

- no BE-001 migration rewrite;
- no duplicate Question schema;
- no duplicate recipient rule;
- no client-supplied Tenant authority;
- no public sort/filter beyond approved query;
- no timer setting snapshot before activation;
- no hidden whole-group recipient snapshot before activation;
- no unrelated Homework semantic change.

---

# 39. Delivery Report

Codex reports:

1. implementation summary;
2. exact changed files and purpose;
3. endpoint list;
4. Create request/resource contract implemented;
5. Update/schedule/archive lifecycle summary;
6. selected-recipient handling;
7. nested Question reuse/extraction summary;
8. shared recipient-helper rename/extraction summary;
9. Tenant/authorization behavior;
10. concurrency behavior;
11. focused Blitz test results;
12. direct Homework regression results;
13. Pint result;
14. `git diff --check`;
15. final `git status --short`;
16. focused scope/diff self-check;
17. any blocker/deviation.

Do not claim Stage 8 backend complete.

After delivery ChatGPT performs read-only acceptance review.

`S08-BE-003` remains blocked until:

```text
S08-BE-002 = Accepted / Delivered
```

---

# 40. Implementation Readiness Verdict

```text
Scope / non-goals                 = RESOLVED
Endpoint surface                  = RESOLVED
List/query behavior               = RESOLVED
Create request                    = RESOLVED
Nested Question create boundary   = RESOLVED
Assignment/recipient behavior     = RESOLVED
Duration behavior                 = RESOLVED
scheduled_at behavior             = RESOLVED
Detail/resource projection        = RESOLVED
Update behavior                   = RESOLVED
Schedule lifecycle                = RESOLVED
Archive lifecycle                 = RESOLVED
Official-Blitz forward boundary   = RESOLVED
Authorization/Tenant isolation    = RESOLVED
No-op/timestamp behavior          = RESOLVED
Concurrency/lock ordering         = RESOLVED
Error behavior                    = RESOLVED
Acceptance criteria               = RESOLVED
Focused verification              = RESOLVED

Implementation Readiness Gate     = PASS
Execution dependency              = S08-BE-001 Accepted / Delivered
```
