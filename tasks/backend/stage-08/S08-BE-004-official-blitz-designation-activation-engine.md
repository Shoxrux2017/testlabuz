# Codex Implementation Contract: S08-BE-004 — Official Blitz Designation and Activation Engine

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-BE-004` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel official Blitz designation + cohort-safe activation + timer snapshot + durable idempotency` |
| Depends on | `S08-DOC-001`, `S08-BE-001`, `S08-BE-002`, `S08-BE-003` — all `Accepted / Delivered` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` after dependencies are delivered and immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |
| Backend block checkpoint | `Stage 8 Backend Phase 2` after `S08-BE-001…010` are `Accepted / Delivered` |
| Blocks | `S08-BE-005` |

Start only when:

```text
S08-DOC-001 = Accepted / Delivered
S08-BE-001  = Accepted / Delivered
S08-BE-002  = Accepted / Delivered
S08-BE-003  = Accepted / Delivered
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
4. delivered S08-BE-001…003 source/tests directly required by this task;
5. current Teacher Topic result-pair implementation/tests;
6. current Homework activation/recipient-snapshot implementation/tests;
7. current shared idempotency implementation/tests;
8. current Topic close/archive open-assessment guard/tests.

Do **not** read:

- `docs/01–09`;
- roadmap files;
- Stage indexes;
- `S08-DOC-001`;
- previous task files;
- closure reviews;
- frontend code

to determine requirements.

The requirements below resolve:

- Stage 8 result-pair PUT extension;
- official Blitz eligibility/replacement;
- locked staged-pair completion;
- official cohort establishment/reuse;
- Homework-first and Blitz-first activation;
- timer mode snapshot;
- synchronized end;
- activation idempotency;
- activation response/errors;
- Teacher/Institution/Group authorization;
- lock ordering;
- concurrency;
- Topic lifecycle integration;
- directly affected Homework behavior;
- acceptance criteria;
- focused verification.

If delivered dependencies materially conflict with this contract, return:

```text
BLOCKED
```

with exact evidence.

Do not invent an alternative official-pair/cohort/timer architecture.

---

# 3. Goal

Implement the core server-authoritative transition from:

```text
prepared Blitz
```

to:

```text
officially designated when applicable
+
recipient/cohort-safe active Blitz
+
immutable timer-start-mode snapshot
+
authoritative activation timestamps
```

The task has two tightly-coupled responsibilities:

1. extend the existing Topic result-pair contract so the Blitz side can be filled/replaced safely before activity;
2. implement idempotent Teacher Blitz activation with exact cohort/timer semantics.

It must also make existing Homework activation compatible with a Blitz-first official cohort.

This task does **not** implement Student Blitz Attempts.

---

# 4. Included Public API Changes

## 4.1 Extend existing result-pair PUT

Keep the existing canonical endpoint:

```text
PUT /api/v1/teacher/topics/{topic}/result-pair
```

Extend request/behavior to support:

```text
homework_assessment_id
blitz_assessment_id
```

No second “designate Blitz” endpoint.

## 4.2 Add Blitz activation

Add exactly:

```text
POST /api/v1/teacher/blitz/{blitz}/activate
```

inside the existing Teacher middleware group.

Required header:

```http
Idempotency-Key: <uuid>
```

Request body:

```text
empty
```

or:

```json
{}
```

No query parameters.

## 4.3 No other new public endpoint

Do not add:

- Blitz Close;
- Student Blitz;
- monitoring;
- exception;
- scoring;
- result API.

---

# 5. Explicit Non-Goals

Do not implement:

- Student active Blitz list/detail;
- Student Start/Resume;
- answer/file save;
- Submit;
- timeout reconciliation;
- Scheduler;
- Teacher Blitz Close;
- replacement Attempt exception;
- monitoring;
- checking/scoring;
- official score resolution;
- Topic result calculation;
- frontend;
- integration seed/harness;
- new persistence tables;
- schema migration;
- per-question timer;
- configurable normal Attempt count.

Do not modify:

```text
assessment_attempts schema
topic_result_pairs schema
blitz_tasks schema
assessment_students schema
idempotency_records schema
```

No migration is required for this task.

---

# 6. Delivered Foundation to Reuse

Reuse delivered:

```text
Assessment
BlitzTask
HomeworkAssignment
AssessmentStudent
AssessmentAttempt
TopicResultPair
InstitutionSetting
Question
```

Enums:

```text
AssessmentType
AssessmentAssignmentMode
AssessmentAssignmentSource
BlitzStatus
BlitzTimerStartMode
HomeworkStatus
TopicStatus
GroupStatus
IdempotencyOperation
```

Question activation validation/writers from completed stages.

Reuse durable:

```text
IdempotencyGuard
IdempotencyRequestFingerprint
idempotency_records
```

Do not implement another idempotency subsystem.

---

# 7. Result-Pair Resource — No Shape Change

Keep the existing Teacher result-pair resource fields exactly:

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

No:

```text
official_homework
official_blitz
is_locked
cohort_ids
```

are added in this task.

GET behavior remains unchanged.

---

# 8. Result-Pair PUT Request Contract

## 8.1 Exact accepted keys

```text
homework_assessment_id
blitz_assessment_id
```

Unknown keys:

```text
422 validation_failed
```

No query parameters.

Body must be one:

```text
application/json object
```

## 8.2 Homework ID

Always required:

```text
homework_assessment_id:
  string
  uuid
```

This preserves the existing Stage 6 caller.

## 8.3 Blitz ID

Optional:

```text
blitz_assessment_id:
  sometimes
  string
  uuid
```

If supplied:

- it must be non-null;
- it means “set/replace the Blitz side according to the rules below”.

Explicit:

```json
"blitz_assessment_id": null
```

is invalid:

```text
422 validation_failed
```

Stage 8 provides no “clear official Blitz” operation.

## 8.4 Omitted Blitz field

When `blitz_assessment_id` is omitted:

> Preserve the currently persisted Blitz side exactly.

Never reset it to null.

This is mandatory because the current Stage 6 implementation writes:

```text
blitz_assessment_id = null
```

during every designation mutation; that behavior must be removed.

---

# 9. Result-Pair Candidate Resolution

All candidate IDs are privacy-safely resolved only inside the authorized Teacher Topic context.

## 9.1 Homework candidate

Require:

```text
same Institution
same Topic
teacher_id = authenticated Teacher
Assessment.type = homework
HomeworkAssignment exists
```

Malformed/private/foreign/wrong-type:

```text
404 resource_not_found
```

## 9.2 Blitz candidate

Require:

```text
same Institution
same Topic
teacher_id = authenticated Teacher
Assessment.type = blitz
BlitzTask exists
```

Malformed/private/foreign/wrong-type:

```text
404 resource_not_found
```

## 9.3 No existence leakage

Do not tell the caller whether a foreign/private UUID exists.

---

# 10. Official Homework Eligibility — Preserve Stage 6

For a **new/replacement** Homework side, preserve the delivered Stage 6 rules.

Require:

```text
assignment_mode = group
status = draft | active
no Assessment Attempt exists
```

Selected-Student Homework:

```text
409 official_task_requires_group_assignment
```

Closed/Archived candidate:

```text
409 business_conflict
```

Candidate with Student activity:

```text
409 result_pair_locked
```

## 10.1 Draft official Homework

Draft official Homework must have:

```text
no persisted recipient rows
```

Otherwise:

```text
409 business_conflict
```

Resulting:

```text
cohort_snapshotted_at = null
```

unless an existing authoritative cohort must be preserved by an exact same-Homework operation.

## 10.2 Active official Homework

Active candidate must have a valid persisted whole-group recipient snapshot:

- non-empty;
- same Institution;
- same Assessment;
- `assignment_source = group`;
- unique Student IDs;
- valid assigned timestamps.

Do not resnapshot current Group membership.

When a new/replacement active Homework becomes official before any pair lock, its persisted recipient set establishes the official cohort according to the existing Stage 6 rule.

---

# 11. Official Blitz Eligibility

A **new/replacement** official Blitz candidate must satisfy:

```text
Assessment.type = blitz
assignment_mode = group
Blitz status = draft | scheduled
no Assessment Attempt exists
```

Selected-Student Blitz:

```text
409 official_task_requires_group_assignment
```

Active/Closed/Archived candidate:

```text
409 business_conflict
```

Any Attempt:

```text
409 result_pair_locked
```

## 11.1 Preactivation recipient integrity

A group Blitz that has not activated must not already carry a hidden whole-group snapshot.

Require:

```text
assessment_students for candidate Blitz = empty
```

If non-empty:

```text
409 business_conflict
```

This keeps official cohort creation/reuse exclusively in activation.

## 11.2 Question completeness not required for designation

Official Blitz may be designated while still incomplete as a Draft/Scheduled authoring object.

Do **not** require:

- Questions;
- positive points;
- configured Institution timer mode

for result-pair designation.

Those are activation requirements.

---

# 12. Result-Pair PUT State Machine

All mutation runs inside one DB transaction after privacy-safe preliminary resolution.

The owning Topic must be:

```text
draft | active
```

otherwise:

```text
409 topic_not_editable
```

## 12.1 No existing pair

Create one pair only after validating:

- Homework candidate eligibility;
- optional Blitz candidate eligibility.

Persist:

```text
homework_assessment_id = request Homework
blitz_assessment_id = supplied Blitz or null
designated_by_user_id = Teacher
designated_at = designatedAt
created_at = designatedAt
updated_at = designatedAt
locked_at = null
```

Cohort:

- draft Homework → null;
- active Homework with valid persisted group recipients → `designatedAt`.

Do not create Blitz recipients.

Do not create Attempts.

## 12.2 Existing pair — exact semantic no-op

A request is an exact semantic no-op when:

```text
requested homework = current homework
AND
(
  Blitz field omitted
  OR requested Blitz = current Blitz
)
```

This succeeds even if later:

- pair is locked;
- Homework closed/archived;
- Blitz active/closed/archived.

Return current resource.

Perform zero writes.

Do not change:

```text
designated_at
designated_by_user_id
cohort_snapshotted_at
locked_at
updated_at
```

This preserves the delivered Stage 6 same-target idempotency principle.

## 12.3 Existing pair — replace Homework while Blitz side is null

Allowed only when:

```text
pair.locked_at = null
pair.blitz_assessment_id = null
```

Apply existing Stage 6 replacement rules:

- current official Homework has no Attempts;
- candidate Homework has no Attempts;
- candidate is whole-group;
- candidate lifecycle eligible;
- candidate recipient shape valid.

Then replace Homework side.

If candidate is Draft:

```text
cohort_snapshotted_at = null
```

If candidate is Active:

```text
cohort_snapshotted_at = replacedAt
```

Update:

```text
designated_by_user_id = Teacher
designated_at = replacedAt
updated_at = replacedAt
```

Preserve:

```text
created_at
```

If Blitz is also supplied in the same request, validate and attach that Blitz atomically after the Homework replacement decision.

## 12.4 Existing pair — pair locked, Blitz side null

This is the critical Stage 8 staged-completion path.

Allow exactly:

```text
existing Homework ID remains unchanged
+
eligible Blitz supplied
```

even when:

```text
pair.locked_at != null
```

This is **completion**, not replacement.

Preserve exactly:

```text
homework_assessment_id
designated_by_user_id
designated_at
cohort_snapshotted_at
locked_at
created_at
```

Set only:

```text
blitz_assessment_id = candidate Blitz
updated_at = completedAt
```

Do not churn the historical pair lock.

Do not rewrite the established cohort.

If request changes Homework while locked:

```text
409 result_pair_locked
```

## 12.5 Existing pair — unlocked, Blitz side null

If Homework remains the same and eligible Blitz is supplied:

- attach Blitz;
- preserve Homework;
- preserve cohort;
- preserve pair `designated_at/designated_by_user_id`;
- set `updated_at = changedAt`.

If Homework is being replaced in the same request:

- apply Section 12.3 first;
- attach the supplied eligible Blitz in the same transaction.

## 12.6 Existing pair — Blitz side already populated

### Same Blitz

No-op when Homework also remains same.

### Different Blitz

Replacement is allowed only when:

```text
pair.locked_at = null
Homework ID remains unchanged
current official Blitz = draft | scheduled
candidate Blitz = draft | scheduled
current official Blitz has no Attempts
candidate Blitz has no Attempts
current/candidate whole-group
```

Current official Blitz must not have been activated.

Any current official Blitz state:

```text
active
closed
archived
```

blocks replacement:

```text
409 result_pair_locked
```

Any current/candidate Attempt:

```text
409 result_pair_locked
```

Actual replacement:

```text
blitz_assessment_id = new candidate
updated_at = changedAt
```

Preserve:

```text
homework_assessment_id
designated_by_user_id
designated_at
cohort_snapshotted_at
locked_at
created_at
```

Do not delete the old Blitz.

Do not delete old Questions/history.

## 12.7 Completed pair blocks Homework replacement

When:

```text
blitz_assessment_id != null
```

a different Homework cannot be substituted through ordinary Stage 8 PUT.

Return:

```text
409 result_pair_locked
```

This preserves Stage 6's “do not independently rewrite one side of a completed future pair” invariant.

---

# 13. Why Blitz-Only Completion Preserves `designated_at`

The current schema has one pair-level:

```text
designated_at
```

and the database constraint:

```text
cohort_snapshotted_at is null
OR cohort_snapshotted_at >= designated_at
```

When Homework activity already established the cohort before Stage 8, changing `designated_at` to a later Blitz attachment time would violate historical ordering.

Therefore:

> Blitz-only attach/replacement does not repurpose the original pair designation timestamp/actor.

It updates only:

```text
blitz_assessment_id
updated_at
```

This task must not add a new Blitz-designation timestamp column.

---

# 14. Result-Pair Lock Order and Concurrency

Use the existing parent-first same-Topic serialization.

Required conceptual order:

```text
1. Group
2. current Teacher–Group membership
3. Topic
4. involved Assessment/detail rows
5. TopicResultPair
6. AssessmentAttempts ordered by assessment_id,id
7. AssessmentStudents ordered by assessment_id,student_id,id
```

The locked Topic serializes same-Topic designation/activation operations and prevents pair/candidate deadlock across competing Teacher requests.

Do not acquire pair first and then parent Assessment if that reverses the established lifecycle order.

---

# 15. Activation Endpoint Request

Create a dedicated request such as:

```text
TeacherBlitzActivationRequest
```

## 15.1 Required header

```http
Idempotency-Key: <uuid>
```

Missing/malformed:

```text
422 validation_failed
```

Normalize to lowercase.

## 15.2 Body

Allowed:

```text
empty
```

or exact empty JSON object:

```json
{}
```

Any body field:

```text
422 validation_failed
```

Non-object body:

```text
422 validation_failed
```

## 15.3 Query

No query parameters.

Any query key:

```text
422 validation_failed
```

---

# 16. Idempotency Operation

Extend:

```text
IdempotencyOperation
```

with exactly:

```text
TeacherBlitzActivate = 'teacher.blitz.activate'
```

Do not add exception-grant/Student Blitz operations yet; their owning tasks add them later.

---

# 17. Shared Idempotency Exception Must Become Role-Neutral

The delivered shared:

```text
IdempotencyGuard
```

currently throws:

```text
App\Exceptions\Student\IdempotencyKeyReusedException
```

Stage 8 activation is the first Teacher-owned user of that shared guard.

Move/refactor this exception to a role-neutral location:

```text
App\Exceptions\IdempotencyKeyReusedException
```

Update:

- `IdempotencyGuard`;
- `bootstrap/app.php`;
- any direct imports/tests

to use the common exception.

Public behavior remains exactly:

```text
409 idempotency_key_reused
```

Do not change existing Student Homework idempotency semantics.

Do not leave duplicated Student/common exception classes with ambiguous handling.

---

# 18. Activation Fingerprint

After privacy-safe preliminary Blitz resolution, calculate fingerprint using:

```text
operation = teacher.blitz.activate
route identity = {
  "blitz_id": lowercase authorized Blitz UUID
}
body identity = {}
```

The fingerprint must include the existing shared actor:

```text
institution_id
user_id
operation
```

through `IdempotencyRequestFingerprint`.

Do not include:

- current lifecycle state;
- current Institution timer mode;
- current recipients;
- current time

in the request fingerprint.

Those are server state, not client request identity.

---

# 19. Activation Replay Contract

Authorization is mandatory before replay.

Flow:

1. privacy-safely resolve the current Teacher-authorized Blitz;
2. open transaction;
3. lock current parent context;
4. check completed replay for the key/fingerprint;
5. if completed, return the authorized current Blitz resource referenced by the record.

Completed activation records use:

```text
result_resource_type = 'blitz'
result_resource_id = Assessment UUID
response_status = 200
```

Replay must validate this metadata.

A successful old activation replay remains valid even if the Blitz later became:

```text
closed
archived
```

The replay returns the same logical Blitz resource under current authorized projection and performs zero domain mutation.

Replay does not bypass current Teacher authorization.

---

# 20. Natural Activation Idempotency With a New Key

If a Blitz is already structurally:

```text
active
```

and the Teacher sends a **new valid** Idempotency-Key:

- do not restart timer;
- do not rewrite recipients;
- do not rewrite cohort;
- do not rewrite activation actor/time;
- create/complete the new idempotency claim to the same Blitz;
- return `200` current resource.

This gives safe domain-level repeated activation while preserving per-key replay semantics.

If task is:

```text
closed
archived
```

and there is no completed replay for the submitted key:

- reject according to lifecycle rules;
- no successful idempotency record remains.

---

# 21. Activation Authorization

`{blitz}` must resolve through delivered:

```text
TeacherBlitzAccess
```

or the exact equivalent.

Require:

```text
same Institution
Assessment.type = blitz
teacher_id = authenticated Teacher
owning Topic visible to Teacher
current Teacher membership in Topic Group
BlitzTask exists
```

Malformed/private/foreign/wrong-Teacher/no-current-membership:

```text
404 resource_not_found
```

---

# 22. Activation Source Lifecycle

New activation is allowed from:

```text
draft
scheduled
```

Scheduling time does **not** automatically gate Teacher activation.

Teacher may activate a Scheduled Blitz before/after its informational `scheduled_at` while Topic/Group/lifecycle rules allow it.

`scheduled_at` is preparation metadata, not an automatic start.

## 22.1 Active

Use Section 20 no-op semantics.

## 22.2 Closed

```text
409 task_closed
```

## 22.3 Archived

```text
409 task_archived
```

No reopen.

---

# 23. Topic and Group Activation Preconditions

For a new activation require:

```text
Topic.status = active
Group.status = active
current Teacher membership still exists
```

Otherwise:

```text
409 topic_not_editable
```

for Topic/Group lifecycle conflict after privacy-safe access.

Do not activate Blitz while Topic is Draft.

---

# 24. Institution Timer Setting

Lock the authenticated Institution's:

```text
institution_settings
```

row inside the activation transaction.

Read:

```text
blitz_timer_start_mode
```

Allowed:

```text
synchronized
individual
```

If null:

```text
409 institution_settings_incomplete
```

with exact metadata:

```json
{
  "message": "Required institution settings are incomplete.",
  "code": "institution_settings_incomplete",
  "errors": {},
  "meta": {
    "missing_fields": [
      "blitz_timer_start_mode"
    ]
  }
}
```

Do not block:

- Blitz create;
- update;
- schedule;
- archive;
- result-pair designation

for a null timer setting.

---

# 25. API Error Infrastructure for Missing Settings

Add role-neutral:

```text
InstitutionSettingsIncompleteException
```

carrying a sorted unique list of missing field names.

Extend `ApiErrorResponse` to support optional:

```text
meta
```

without changing existing error JSON for methods that do not supply meta.

Existing error responses must remain exactly:

```text
message
code
errors
```

unless they intentionally include meta.

Add:

```text
CODE_INSTITUTION_SETTINGS_INCOMPLETE
```

and a renderer in:

```text
bootstrap/app.php
```

No internal setting values are exposed.

---

# 26. Official Cohort Mismatch Error

Add stable:

```text
409 official_cohort_mismatch
```

for structural mismatch between official recipient snapshots.

Example response:

```json
{
  "message": "The official assessment cohort does not match the established Topic cohort.",
  "code": "official_cohort_mismatch",
  "errors": {}
}
```

Create a focused role-neutral/Teacher domain exception such as:

```text
OfficialCohortMismatchException
```

and map it through existing API error handling.

Use this only for official cohort-set mismatch.

Do not use it for general selected-Student assignment failure.

---

# 27. Activation Question Validation

The current:

```text
HomeworkActivationValidator
```

contains Assessment-generic metadata/Question validation.

Rename/extract it to:

```text
AssessmentActivationValidator
```

and update existing Homework activation to use it.

Preserve exact delivered behavior:

```text
title/instructions/assignment_mode structurally valid
Question count within maximum
positions contiguous
typed configuration canonical
type/checking mode valid
points exact
sum exact
total > 0
```

If no Questions or zero total:

```text
409 assessment_has_no_scoreable_points
```

Other structural corruption:

```text
409 business_conflict
```

Do not duplicate a Blitz-only Question validator.

---

# 28. Shared Recipient Snapshotter

The current:

```text
HomeworkRecipientSnapshotter
```

implements Assessment-generic current-membership recipient snapshot logic.

Rename/extract to:

```text
AssessmentRecipientSnapshotter
```

or equivalent shared name.

Update existing Homework activation to use it.

Preserve existing practice Homework behavior exactly.

The shared snapshotter must support two recipient modes:

1. current-eligibility snapshot/validation;
2. exact established official cohort replication.

---

# 29. Ordinary Practice Blitz Recipient Activation

When the Blitz is **not** the official Blitz in the Topic result pair:

## 29.1 Group practice Blitz

At activation:

- lock existing recipient rows;
- require no pre-existing group snapshot;
- lock current Group Student memberships;
- lock Student users;
- select only:
  ```text
  same Institution
  current Group membership
  role = student
  is_active = true
  ```
- require non-empty eligible set;
- create one `assessment_students` row per Student:
  ```text
  assignment_source = group
  assigned_at = activatedAt
  assigned_by_user_id = Teacher
  ```

No current member:

```text
409 assessment_not_assigned
```

## 29.2 Selected-Student practice Blitz

Recipients were created during authoring.

At activation revalidate every persisted Direct recipient:

```text
same Institution
assignment_source = direct
assigned_by_user_id = Teacher
Student role = student
Student active
current Group membership still exists
```

If invalid/missing:

```text
409 assessment_not_assigned
```

Do not silently drop a selected Student.

Do not rewrite the selected set.

---

# 30. Official Blitz Recipient/Cohort Activation

A Blitz is official when the locked Topic pair has:

```text
pair.blitz_assessment_id = Blitz Assessment ID
```

Official Blitz must have:

```text
assignment_mode = group
```

otherwise:

```text
409 business_conflict
```

Activation must never change:

```text
homework_assessment_id
blitz_assessment_id
locked_at
```

## 30.1 Shared pair-lock activity consistency

For activation of either already-designated official task, interpret
`pair.locked_at` as a pair-wide first-Student-activity marker.

After the pair lock is held, lock Attempt rows for both official Assessment IDs
when present, in deterministic:

```text
assessment_id
id
```

order.

For this integrity check, activity means **existence** of an Attempt row under
either official Assessment. Do not require the activity to belong to the task
currently being activated and do not count cross-side Attempts toward that
task's own Attempt policy.

Require:

```text
pair.locked_at = null
<=> no official Homework/Blitz Attempt exists yet
```

If the pair is locked with zero official activity, or unlocked while official
activity already exists:

```text
409 business_conflict
```

with no lock/cohort/recipient repair.

This shared invariant is used by both official Blitz activation and the
Homework activation compatibility in Section 33.

---

# 31. Official Cohort — No Cohort Exists Yet

When:

```text
pair.cohort_snapshotted_at = null
```

the currently activating official task establishes the common cohort.

This may be:

```text
official Homework
or
official Blitz
```

For official Blitz activation:

1. require its preactivation recipient set empty;
2. snapshot current eligible whole-group Students using Section 29.1;
3. require non-empty;
4. use exactly that new Blitz recipient set as the official Topic cohort;
5. set:
   ```text
   pair.cohort_snapshotted_at = activatedAt
   pair.updated_at = activatedAt
   ```
6. preserve:
   ```text
   pair.homework_assessment_id
   pair.blitz_assessment_id
   pair.designated_at
   pair.designated_by_user_id
   pair.locked_at
   ```

Do not create Homework recipient rows.

Later official Homework activation must replicate this established Student set exactly.

---

# 32. Official Cohort — Already Established

When:

```text
pair.cohort_snapshotted_at != null
```

current Group membership is **not** the authority for official cohort identity.

Determine the authoritative Student set from the persisted group-recipient snapshots of the official pair tasks.

## 32.1 Lock both official recipient sets

Lock recipients for:

```text
pair.homework_assessment_id
pair.blitz_assessment_id when non-null
```

in deterministic:

```text
assessment_id
student_id
id
```

order.

## 32.2 Valid official recipient row

Every row participating in an official cohort snapshot must have:

```text
same Institution
assessment_id = corresponding official Assessment
assignment_source = group
assigned_at non-null
unique Student ID within Assessment
```

Otherwise:

```text
409 official_cohort_mismatch
```

## 32.3 Authoritative set resolution

When cohort is established:

- at least one official Assessment must have a non-empty valid group-recipient set;
- every non-empty official recipient set must be exactly the same Student-ID set.

If two non-empty official sets differ:

```text
409 official_cohort_mismatch
```

If both are empty despite non-null `cohort_snapshotted_at`:

```text
409 official_cohort_mismatch
```

## 32.4 Activating task has no recipients yet

Create exact recipient rows for the established IDs:

```text
assignment_source = group
assigned_at = activatedAt
assigned_by_user_id = Teacher
```

Do **not** require those Students to still be current Group members.

Do **not** remove a Student because:

- membership ended later;
- Student became inactive later.

Historical official cohort identity is preserved.

Account/middleware rules later determine whether the Student can currently authenticate/use the app.

## 32.5 Activating task already has recipients

This is allowed only when the persisted Student set exactly matches the authoritative official cohort.

Preserve rows/timestamps.

Any difference:

```text
409 official_cohort_mismatch
```

No silent resnapshot/repair.

---

# 33. Homework Activation Must Become Blitz-First Compatible

Modify existing:

```text
ActivateTeacherHomework
```

only as required to use the shared official cohort engine.

Current delivered behavior incorrectly treats:

```text
pair.blitz_assessment_id != null
or
pair.cohort_snapshotted_at != null
```

as an activation conflict in the Homework-first-only world.

Stage 8 requires:

## 33.1 Homework is not official

Keep ordinary Homework activation behavior unchanged.

## 33.2 Official Homework, cohort null

If official Homework activates first:

- snapshot current eligible whole-group recipients;
- set pair cohort at Homework activation instant;
- preserve optional already-designated Blitz side;
- do not create Blitz recipients.

## 33.3 Official Homework, cohort already established by Blitz

Use exactly the persisted official cohort under Sections 32.1–32.5.

Do not resnapshot current Group membership.

Do not clear/replace Blitz.

Do not change `cohort_snapshotted_at`.

## 33.4 Pair already locked — pair-wide activity invariant

A non-null:

```text
pair.locked_at
```

does **not** by itself block activation of the already-designated official Homework.

In Stage 8 the pair lock means:

> Student activity has begun on at least one Assessment of the official
> Homework–Blitz pair.

It is **not** a Homework-only activity marker.

For official Homework activation, after the parent/pair locks are held, lock the
Attempt rows belonging to the official Assessment IDs in deterministic:

```text
assessment_id
id
```

order and evaluate only pair-wide activity existence here:

```text
official activity exists
=
any AssessmentAttempt row exists for
  pair.homework_assessment_id
  OR
  pair.blitz_assessment_id when non-null
within the same Institution
```

Do not require a Homework Attempt specifically.

Therefore this valid Stage 8 state must succeed when every other activation rule
passes:

```text
official Blitz activated first
→ real official Blitz Attempt exists
→ pair.locked_at was set by that Student Blitz Start
→ official Homework has zero Attempts and is still preactivation
→ official Homework activates later
```

The Homework activation must:

- reuse the already-established official cohort;
- preserve `pair.locked_at`;
- preserve the pair's existing `updated_at` when no cohort field changes;
- create/reuse only the Homework recipient snapshot required by the established
  cohort;
- never reinterpret the Blitz Attempt as Homework Attempt history.

Defensive consistency remains required:

```text
pair.locked_at != null
AND no Attempt exists on either official Assessment
=> 409 business_conflict
```

and:

```text
pair.locked_at = null
AND an Attempt already exists on either official Assessment
=> 409 business_conflict
```

Do not infer, clear, synthesize, or repair the pair lock in either inconsistent
case.

The lock protects official identity/cohort; it does not prohibit later
activation of the other already-designated official task.

## 33.5 Existing Homework same-target active no-op

Preserve the delivered natural active no-op semantics.

---

# 34. Activation Decision Instant and Timer Precision

All lock waits and required validation must occur before the authoritative activation instant is captured.

Stage 8 timer-domain precision is exactly:

```text
UTC whole seconds
no fractional seconds
```

After the required lock waits, capture backend server time and **truncate** its
fractional part to the beginning of that UTC second:

```text
activatedAt =
  server_now in UTC
  with microseconds set to 0
```

This is truncation/flooring, never rounding to the next second.

Required conceptual flow:

```text
resolve
lock parents
idempotency replay/claim
validate lifecycle
lock timer setting
lock/validate Questions
lock recipient/cohort state
validate recipient/cohort strategy
activatedAt = truncate_to_utc_second(server_now)
perform snapshot writes
persist activation
complete idempotency
```

This prevents transaction wait time from consuming synchronized Student duration
before the transition can actually commit and gives every downstream timer field
one canonical precision.

Use this one whole-second `activatedAt` for all activation-domain timestamps that
participate in Blitz timer semantics.

For synchronized mode:

```text
synchronized_ends_at = activatedAt + duration_seconds
```

must therefore also have zero fractional seconds.

Do not persist one fractional value and merely hide the fraction during JSON
serialization.

---

# 35. Timer Snapshot Persistence

At successful new activation:

```text
blitz_tasks.timer_start_mode_snapshot
=
institution_settings.blitz_timer_start_mode
```

Snapshot is immutable after activation.

Later Institution setting changes must not affect the active Blitz.

---

# 36. Synchronized Activation

When mode is:

```text
synchronized
```

persist exactly:

```text
status = active
activated_at = activatedAt
activated_by_user_id = Teacher ID
timer_start_mode_snapshot = synchronized
synchronized_ends_at = activatedAt + duration_seconds seconds
closed_at = null
archived_at = null
updated_at = activatedAt
```

The common end must use exact server duration arithmetic.

Do not create Student Attempts.

A Student opening later will use this same end in `S08-BE-005`.

---

# 37. Individual Activation

When mode is:

```text
individual
```

persist:

```text
status = active
activated_at = activatedAt
activated_by_user_id = Teacher ID
timer_start_mode_snapshot = individual
synchronized_ends_at = null
closed_at = null
archived_at = null
updated_at = activatedAt
```

Do not create Student deadlines.

Individual Student `deadline_at` belongs to Student Start in `S08-BE-005`.

---

# 38. Assessment Total on Activation

After validating current locked Questions:

```text
assessment.total_possible_points
=
exact recalculated Question point sum
```

Persist:

```text
assessment.updated_at = activatedAt
```

even if the numeric total was already equal, because activation is a real parent lifecycle mutation.

Do not modify Question rows.

---

# 39. Scheduled Metadata on Activation

Preserve:

```text
blitz_tasks.scheduled_at
```

when activating.

Do not clear it.

It remains historical planned-preparation metadata.

Do not require activation time to equal or exceed it.

---

# 40. Activation Result-Pair Writes

If Blitz is not official:

```text
no result-pair write
```

If official and cohort was already established:

```text
no result-pair timestamp write
```

unless a real repair is prohibited and therefore throws.

If official and this activation establishes the cohort:

```text
pair.cohort_snapshotted_at = activatedAt
pair.updated_at = activatedAt
```

Preserve all other pair fields.

Activation never sets:

```text
pair.locked_at
```

Pair lock occurs only on the first official Student Attempt through either
official Student Start path. `S08-BE-005` aligns new Blitz Start and the
existing Homework Start to this one pair-wide first-activity invariant.

---

# 41. Activation Success

Return:

```text
200 OK
```

complete delivered:

```text
TeacherBlitzResource
```

plus:

```text
message = Blitz task activated successfully.
```

Resource must expose authoritative:

```text
status = active
duration_seconds
timer_start_mode_snapshot
activated_at
synchronized_ends_at
scheduled_at
attempt_policy
questions
institution_timezone
```

Do not return:

- Institution setting row;
- recipient internal IDs;
- cohort ID array;
- idempotency record;
- score.

---

# 42. Activation Failure and Idempotency Atomicity

A failed new activation must not leave a committed incomplete idempotency claim.

The transaction must atomically include:

```text
idempotency claim
recipient/cohort writes
Assessment total/timestamp
Blitz activation state
pair cohort write when needed
idempotency completion
```

Any thrown validation/business exception rolls the transaction back.

No partial:

- recipients;
- pair cohort;
- timer snapshot;
- activation timestamps;
- idempotency row

may remain.

---

# 43. Activation Error Contract

Required expected errors include:

| Condition | Result |
|---|---|
| malformed/private/foreign Blitz | `404 resource_not_found` |
| missing/malformed Idempotency-Key | `422 validation_failed` |
| non-empty/invalid request body/query | `422 validation_failed` |
| Topic/Group not active after lock | `409 topic_not_editable` |
| Blitz closed | `409 task_closed` |
| Blitz archived | `409 task_archived` |
| Questions empty/zero points | `409 assessment_has_no_scoreable_points` |
| other Question/config corruption | `409 business_conflict` |
| timer-start mode null | `409 institution_settings_incomplete` + `meta.missing_fields` |
| no eligible practice group recipient | `409 assessment_not_assigned` |
| selected practice recipient no longer eligible | `409 assessment_not_assigned` |
| official Blitz not group | `409 business_conflict` |
| official cohort snapshots conflict | `409 official_cohort_mismatch` |
| same Idempotency-Key different fingerprint | `409 idempotency_key_reused` |

Do not add:

```text
blitz_time_expired
blitz_not_active
```

to activation errors; those belong to Student execution.

---

# 44. Topic Open-Assessment Guard Must Include Blitz

The existing:

```text
TeacherTopicOpenHomeworkGuard
```

knows only Homework.

Once this task can create `active` Blitz, Topic lifecycle must not ignore it.

Rename/extract to:

```text
TeacherTopicOpenAssessmentGuard
```

and update:

```text
CloseTeacherTopic
ArchiveTeacherTopic
```

to use it.

## 44.1 Homework behavior

Preserve current open Homework rule:

```text
Homework draft | active
=> Topic has open assessment
```

## 44.2 Blitz behavior

Treat:

```text
Blitz draft
Blitz scheduled
Blitz active
```

as open/unresolved.

Only:

```text
Blitz closed
Blitz archived
```

is resolved for Topic close/archive purposes.

If any open Homework or Blitz exists:

```text
409 topic_has_open_assessments
```

## 44.3 Error message

Generalize the human message from Homework-only wording to:

```text
The topic has open assessments that must be resolved before closing or archiving it.
```

Machine code remains:

```text
topic_has_open_assessments
```

Update exact tests expecting the old human message.

No frontend contract should branch on the message.

---

# 45. Topic Guard Locking

The generalized Topic open-assessment guard must lock same-Topic Assessment/detail rows deterministically.

Conceptual order after Topic is already locked:

```text
Assessments ordered by id
HomeworkAssignment rows ordered by assessment_id
BlitzTask rows ordered by assessment_id
```

Do not separately query without Tenant scope.

Do not mutate child tasks.

Topic close/archive only observes whether unresolved tasks remain.

---

# 46. Result-Pair Access Refactor

The current:

```text
TeacherTopicResultPairAccess
```

is Homework-only.

Extend it to support focused methods for:

- Homework candidate/current official;
- Blitz candidate/current official;
- attempts for involved assessments;
- recipients for involved assessments;
- pair lock.

Do not replace it with a generic repository framework.

Do not use `TeacherHomeworkAccess` to resolve Blitz.

Use delivered `TeacherBlitzAccess`.

Topic/group/membership locking must remain one canonical behavior.

A small shared Teacher Assessment Topic access extraction is allowed only if it removes real duplicate parent locking without changing authorization.

---

# 47. Activation Access

Create a focused:

```text
TeacherBlitzLifecycleAccess
```

or equivalent if not already delivered.

Responsibilities:

- resolve authorized Blitz;
- lock Group/membership/Topic/Assessment/BlitzTask;
- lock result pair;
- lock Questions;
- lock Attempts if needed for defensive integrity;
- lock InstitutionSetting.

Do not put lifecycle business decisions in the access class.

Do not route through Homework lifecycle access.

---

# 48. Defensive Preactivation Attempt Integrity

For a Draft/Scheduled Blitz being newly activated:

```text
Assessment Attempt rows must be empty
```

Lock them.

If any exist:

```text
409 business_conflict
```

Do not activate around corrupted Student history.

This check also protects result-pair replacement assumptions.

---

# 49. Activation Lock Order

Use one deterministic order compatible with BE-002/BE-003 and future Student Start:

```text
1. Group
2. current Teacher–Group membership
3. Topic
4. Assessment
5. BlitzTask
6. TopicResultPair
7. InstitutionSetting
8. involved official Assessment rows/details when required, deterministic by Assessment ID
9. AssessmentAttempts ordered by assessment_id,id
10. AssessmentStudents ordered by assessment_id,student_id,id
11. current Group Student memberships/users when a current snapshot is required
12. Questions ordered by position,id
13. typed Question configuration rows through existing validator/writer order
```

If the delivered shared validator requires Questions before recipient rows, retain one consistent order across Homework/Blitz activation and update the contract implementation accordingly; do not create opposite lock orders between the two activation Actions.

The key invariant is:

> Same parent resources use the same relative lock order in Homework activation, Blitz activation, result-pair mutation, Question mutation, and future Student Start.

---

# 50. Activation vs Result-Pair PUT Race

Because both operations lock the same Topic before mutating pair/Assessment state:

## Designation commits first

Activation re-reads:

- current official Blitz identity;
- cohort state;
- pair lock;

and activates under that committed meaning.

## Activation commits first

A later result-pair mutation sees:

```text
Blitz status = active
```

and cannot newly designate/replace that active Blitz.

No request may:

- activate candidate A while pair commits candidate B;
- replace official Blitz after its activation commits;
- rewrite cohort after activation.

---

# 51. Activation vs Question Mutation Race

Preserve the BE-003 invariant.

If Question mutation commits first:

```text
activation validates the committed Question set and points
```

If Activation commits first:

```text
Question mutation re-reads active Blitz
-> conflict
-> zero Question-domain mutation
```

No Question content may commit after activation wins.

---

# 52. Activation vs Blitz Update/Schedule/Archive Race

Use shared parent locks.

## Activation first

Later:

- Update rejects active;
- Schedule rejects active;
- Archive rejects active.

## Preparation mutation first

Activation sees committed definition/lifecycle and revalidates.

No timer starts from stale duration/Question/assignment state.

---

# 53. Activation vs Institution Settings Update

Activation locks the InstitutionSetting row before reading:

```text
blitz_timer_start_mode
```

An Institution Admin update and activation therefore serialize on that row.

Whichever commits first defines the value visible to the later transaction.

Once activation commits, its snapshot remains unchanged by later setting updates.

---

# 54. Activation vs Group Membership Changes

For practice/current-snapshot activation:

- lock relevant current memberships/users;
- membership changes serialize through their normal row locks;
- final snapshot is based on one committed authoritative state.

For established official cohort replication:

- do not consult current Group membership for cohort identity;
- membership changes do not alter historical cohort.

---

# 55. Required New/Changed Classes — Expected Scope

Exact names may follow delivered code where already created.

## Create likely

```text
backend/app/Actions/Teacher/ActivateTeacherBlitz.php

backend/app/Http/Requests/Teacher/TeacherBlitzActivationRequest.php

backend/app/Support/Teacher/TeacherBlitzLifecycleAccess.php
backend/app/Support/Teacher/TeacherOfficialAssessmentCohort.php
  or one equivalently focused official-cohort service

backend/app/Exceptions/InstitutionSettingsIncompleteException.php
backend/app/Exceptions/Teacher/OfficialCohortMismatchException.php
backend/app/Exceptions/IdempotencyKeyReusedException.php
```

## Rename/extract likely

```text
HomeworkActivationValidator
-> AssessmentActivationValidator

HomeworkRecipientSnapshotter
-> AssessmentRecipientSnapshotter

TeacherTopicOpenHomeworkGuard
-> TeacherTopicOpenAssessmentGuard
```

Update direct callers/tests only.

## Modify

```text
backend/app/Actions/Teacher/ActivateTeacherHomework.php

backend/app/Actions/Teacher/SetTeacherTopicResultPair.php
backend/app/Support/Teacher/TeacherTopicResultPairAccess.php
backend/app/Http/Requests/Teacher/TeacherTopicResultPairUpdateRequest.php
backend/app/Http/Controllers/Api/V1/Teacher/TeacherTopicResultPairController.php

backend/app/Http/Controllers/Api/V1/Teacher/TeacherBlitzController.php
backend/routes/api.php

backend/app/Enums/IdempotencyOperation.php
backend/app/Support/Idempotency/IdempotencyGuard.php

backend/app/Support/ApiErrorResponse.php
backend/bootstrap/app.php

backend/app/Actions/Teacher/CloseTeacherTopic.php
backend/app/Actions/Teacher/ArchiveTeacherTopic.php
```

No migration.

No frontend.

No docs/tasks.

---

# 56. Result-Pair Focused Tests

Extend existing:

```text
TeacherTopicResultPairApiTest
TeacherOfficialHomeworkIntegrityTest
```

rather than replacing them.

Add focused Stage 8 tests where separation improves readability, such as:

```text
TeacherOfficialBlitzDesignationTest.php
TeacherOfficialPairStage8ConcurrencyTest.php
```

Required cases:

## Request shape

- existing Homework-only PUT still accepted;
- optional Blitz ID accepted;
- explicit null Blitz rejected;
- unknown key rejected;
- query/body strictness preserved.

## Preservation

- Homework-only PUT after Blitz is attached preserves Blitz ID;
- exact same pair no-op after lock/close/archive with no timestamp churn.

## Initial complete pair

- no pair + draft Homework + draft Blitz;
- no pair + draft Homework + scheduled Blitz;
- no pair + active Homework valid recipient snapshot + draft Blitz.

## Blitz eligibility

- selected Blitz rejected;
- active/closed/archived candidate rejected;
- candidate with Attempt rejected;
- candidate with preactivation recipient rows rejected;
- cross-Topic/Tenant/Teacher/non-Blitz rejected privately.

## Locked staged completion

- locked partial pair + same Homework + draft Blitz succeeds;
- preserves Homework/cohort/lock/designated/created timestamps;
- only Blitz ID + updated_at changes;
- locked partial pair + different Homework rejected;
- locked complete pair + different Blitz rejected.

## Unlocked Blitz replacement

- draft/scheduled official Blitz replaced before activity;
- current active official Blitz replacement rejected;
- current/candidate Attempt replacement rejected;
- Homework ID remains unchanged;
- cohort preserved.

## Completed pair

- different Homework replacement rejected once Blitz side populated.

---

# 57. Blitz Activation API Tests

Create focused tests such as:

```text
TeacherBlitzActivationApiTest.php
TeacherBlitzActivationAuthorizationTest.php
TeacherBlitzActivationIdempotencyTest.php
TeacherBlitzOfficialCohortActivationTest.php
TeacherBlitzActivationConcurrencyTest.php
```

## 57.1 Basic synchronized activation

Verify:

- Draft/Scheduled source;
- Topic/Group active;
- setting synchronized;
- Questions valid;
- positive total;
- recipients valid;
- status active;
- activation actor/time;
- timer snapshot synchronized;
- exact end = activation + duration;
- no Attempts created;
- full Blitz response;
- scheduled_at preserved.

## 57.2 Basic individual activation

Verify:

- snapshot individual;
- common end null;
- no Student deadlines/Attempts created.

## 57.3 Missing timer setting

Verify:

```text
409 institution_settings_incomplete
meta.missing_fields = ["blitz_timer_start_mode"]
```

and complete rollback:

- no recipients;
- no cohort;
- no activation;
- no idempotency record.

## 57.4 Question/point validation

- no Questions;
- zero total;
- corrupt configuration;
- server recalculates points and ignores stale stored total.

## 57.5 Practice assignments

- group practice current eligible snapshot;
- no eligible Students -> assessment_not_assigned;
- selected practice valid current recipients;
- selected Student became inactive/non-member -> assessment_not_assigned.

## 57.6 Lifecycle

- Draft activates;
- Scheduled activates;
- scheduled_at does not auto-start/gate;
- already Active with new key returns no-op, no timestamp/timer churn;
- Closed/Archived rejected for a new key.

## 57.7 Whole-second timer precision

Use controlled fractional server instants.

At raw server time:

```text
12:00:00.500000Z
```

successful activation persists/returns:

```text
activated_at = 12:00:00Z
```

and for `duration_seconds = 600`:

```text
synchronized_ends_at = 12:10:00Z
```

Assert persisted timer timestamps have zero microseconds.

Also cover:

```text
12:00:00.999999Z
```

which still truncates to:

```text
12:00:00Z
```

and never rounds to `12:00:01Z`.

---

# 58. Official Cohort Activation Tests

## 58.1 Homework first, cohort established, pair unlocked

- Homework recipients establish cohort;
- official Blitz activation copies exact set;
- later current Group additions excluded;
- later current Group removals do not remove established cohort member;
- pair cohort timestamp unchanged.

## 58.2 Homework first, pair locked

- Homework Attempt locks pair;
- official Blitz activation still succeeds;
- exact cohort copied;
- pair locked_at unchanged.

## 58.3 Blitz first

- both tasks designated;
- pair cohort null;
- official Blitz activation snapshots current eligible group;
- pair cohort set to exact activation instant;
- no Homework recipients fabricated.

## 58.4 Homework activates after Blitz first

After structural Blitz-first cohort fixture:

- Homework activation uses exact Blitz cohort;
- later Group changes ignored;
- no pair identity/lock change;
- no resnapshot.

## 58.5 Locked by real Blitz activity compatibility

Create a valid Blitz-first state with:

```text
cohort established from official Blitz
official Blitz group recipient snapshot present
real official Blitz Attempt #1 present
pair.locked_at = that first official Blitz Attempt.started_at
Homework still preactivation
Homework Attempts = empty
```

Homework activation must:

- use the exact established official cohort;
- succeed without requiring a Homework Attempt to exist first;
- preserve `pair.locked_at`;
- preserve pair identity/designation history;
- create no extra Blitz recipient/Attempt rows.

## 58.6 Pair lock/activity corruption

Cover both impossible combinations:

```text
pair.locked_at != null
AND no Attempt exists on either official Assessment
```

and:

```text
pair.locked_at = null
AND an official Homework or Blitz Attempt already exists
```

Required:

```text
409 business_conflict
```

with zero activation/cohort/lock repair.

## 58.7 Mismatch

- both official recipient snapshots non-empty but differ;
- non-null cohort but both sets empty;
- recipient uses Direct source;
- duplicate/corrupt graph if fixture can create it.

Return:

```text
409 official_cohort_mismatch
```

No repair.

---

# 59. Activation Idempotency Tests

Required:

## Same key / same request

- first activation success;
- replay returns 200;
- one completed idempotency record;
- same activation timestamp;
- same synchronized end;
- no duplicate recipients;
- no pair timestamp churn.

## Same key / different authorized Blitz

Use same actor/key for another Blitz:

```text
409 idempotency_key_reused
```

because route fingerprint differs.

## Different Teacher / same key

Idempotency scope is per:

```text
Institution + User + Operation + Key
```

No cross-user collision.

## New key on already Active

- 200 current Blitz;
- no timer restart;
- a separate completed activation idempotency record is allowed;
- no domain timestamp churn.

## Replay after later lifecycle

Using a completed activation key against a later Closed/Archived fixture:

- authorization still required;
- replay returns logical current Blitz;
- does not re-activate.

## Atomic rollback

Inject failure before idempotency completion:

- activation/cohort/recipients roll back;
- claim rolls back;
- retry can succeed.

---

# 60. Idempotency Regression Tests

Because shared exception namespace changes, run existing:

```text
StudentHomeworkAttemptIdempotencyTest
StudentHomeworkAttemptSubmitIdempotencyTest
```

Public Student behavior must remain unchanged:

```text
409 idempotency_key_reused
```

No existing Student operation code/fingerprint behavior changes.

---

# 61. Homework Activation Regression Tests

Run focused existing Homework activation/lifecycle tests, including:

```text
TeacherHomeworkActivationRecipientTest
TeacherHomeworkLifecycleApiTest
TeacherHomeworkLifecycleAuthorizationTest
TeacherHomeworkLifecycleConcurrencyTest
TeacherOfficialHomeworkIntegrityTest
```

Add Stage 8 compatibility cases without weakening old assertions.

Preserve:

- ordinary group snapshot;
- selected recipient validation;
- deadline behavior;
- scoreable points;
- old official Homework-first cohort behavior;
- active same-target no-op.

New compatibility:

- optional designated Blitz no longer blocks first official Homework activation;
- existing official cohort from Blitz is reused;
- a pair lock backed by real official Blitz activity does not block activation
  of the already-designated Homework;
- zero Homework Attempts are valid when the pair lock is backed by an official
  Blitz Attempt;
- locked-with-zero-official-activity is rejected without repair;
- unlocked-with-existing-official-activity is rejected without repair.

---

# 62. Topic Lifecycle Regression Tests

Update/run:

```text
TeacherTopicLifecycleApiTest
```

and directly related Topic lifecycle concurrency test if separate.

Verify:

- open Homework still blocks as before;
- Draft Blitz blocks Topic close/archive;
- Scheduled Blitz blocks;
- Active Blitz blocks;
- Closed/Archived Blitz does not block;
- machine code stays `topic_has_open_assessments`;
- human message generalized;
- no task mutation occurs during Topic guard.

---

# 63. Required Concurrency Tests

## 63.1 Competing Blitz activation

Two different Idempotency-Keys concurrently activate the same Draft Blitz.

Required:

- one authoritative activation instant/timer;
- both successful logical outcomes may complete after serialization;
- no duplicate recipient rows;
- no timer restart;
- no cohort duplicate;
- two completed idempotency records may exist, both pointing to same Blitz;
- final state valid.

## 63.2 Activation vs result-pair replacement

Prove no official identity race.

## 63.3 Activation vs Question mutation

Preserve BE-003 invariant.

## 63.4 Activation vs Institution setting update

Verify snapshot equals one committed setting value and never changes afterward.

Use existing PostgreSQL concurrency-test pattern.

Do not use sleeps as correctness synchronization if the repository has barrier helpers.

---

# 64. Verification Commands

Run from:

```text
backend/
```

Exact test filenames may follow delivered dependency names; use equivalent focused files and report exact commands.

## 64.1 Result pair

```bash
php artisan test \
  tests/Feature/Teacher/TeacherTopicResultPairApiTest.php \
  tests/Feature/Teacher/TeacherOfficialHomeworkIntegrityTest.php \
  tests/Feature/Teacher/TeacherOfficialBlitzDesignationTest.php \
  tests/Feature/Teacher/TeacherOfficialPairStage8ConcurrencyTest.php
```

## 64.2 Blitz activation

```bash
php artisan test \
  tests/Feature/Teacher/TeacherBlitzActivationApiTest.php \
  tests/Feature/Teacher/TeacherBlitzActivationAuthorizationTest.php \
  tests/Feature/Teacher/TeacherBlitzActivationIdempotencyTest.php \
  tests/Feature/Teacher/TeacherBlitzOfficialCohortActivationTest.php \
  tests/Feature/Teacher/TeacherBlitzActivationConcurrencyTest.php
```

## 64.3 Homework activation regression

```bash
php artisan test \
  tests/Feature/Teacher/TeacherHomeworkActivationRecipientTest.php \
  tests/Feature/Teacher/TeacherHomeworkLifecycleApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkLifecycleAuthorizationTest.php \
  tests/Feature/Teacher/TeacherHomeworkLifecycleConcurrencyTest.php
```

## 64.4 Topic lifecycle regression

```bash
php artisan test \
  tests/Feature/Teacher/TeacherTopicLifecycleApiTest.php
```

Run the exact directly related concurrency file too if Topic lifecycle concurrency is stored separately.

## 64.5 Shared idempotency regression

```bash
php artisan test \
  tests/Feature/Student/StudentHomeworkAttemptIdempotencyTest.php \
  tests/Feature/Student/StudentHomeworkAttemptSubmitIdempotencyTest.php
```

## 64.6 Direct Blitz preparation regression

Because activation depends on delivered Blitz resource/access/lifecycle:

```bash
php artisan test \
  tests/Feature/Teacher/TeacherBlitzAuthoringApiTest.php \
  tests/Feature/Teacher/TeacherBlitzAuthorizationApiTest.php \
  tests/Feature/Teacher/TeacherBlitzScheduleArchiveApiTest.php
```

## 64.7 Format

```bash
./vendor/bin/pint --test
```

## 64.8 Always

From repository root:

```bash
git diff --check
```

Do not run the full backend suite.

Full regression belongs to:

```text
S08-BE-PHASE-2
```

---

# 65. Acceptance Criteria — Result Pair

- [ ] Existing GET shape unchanged.
- [ ] Existing Homework-only PUT remains valid.
- [ ] PUT accepts optional non-null Blitz UUID.
- [ ] Omitted Blitz preserves existing Blitz side.
- [ ] Explicit null cannot clear Blitz.
- [ ] Only whole-group Blitz may be official.
- [ ] Official Blitz candidate must be Draft/Scheduled and unused.
- [ ] Locked partial pair may fill the missing Blitz side.
- [ ] Locked completion preserves Homework/cohort/lock/designation history.
- [ ] Unlocked preactivity official Blitz may be replaced.
- [ ] Active/used official Blitz cannot be replaced.
- [ ] Completed pair blocks Homework replacement.
- [ ] Exact same pair replay/no-op has zero timestamp churn.
- [ ] No designation operation creates Blitz recipients/Attempts.
- [ ] Cross-Tenant/Topic/Teacher IDs are privacy-safe.

---

# 66. Acceptance Criteria — Activation

- [ ] Activation endpoint exists exactly once.
- [ ] Required Idempotency-Key enforced.
- [ ] Empty/{} body only.
- [ ] Draft/Scheduled can activate.
- [ ] Closed/Archived cannot.
- [ ] Topic/Group must be Active.
- [ ] Institution timer setting locked/read at activation.
- [ ] Null timer mode returns exact `institution_settings_incomplete` meta.
- [ ] Current Questions validated and total recalculated.
- [ ] Practice group recipients snapshot current eligible Students.
- [ ] Practice selected recipients revalidated.
- [ ] Official Blitz requires group assignment.
- [ ] Official no-cohort activation can establish cohort.
- [ ] Established official cohort is copied exactly.
- [ ] Later Group membership cannot redefine official cohort.
- [ ] Cohort mismatch fails without repair.
- [ ] Server activation instant captured after lock waits/validation.
- [ ] Activation timer instant is truncated to UTC whole-second precision before persistence/arithmetic.
- [ ] Persisted `activated_at` and synchronized `synchronized_ends_at` have zero fractional seconds.
- [ ] Synchronized end exact from the normalized activation instant.
- [ ] Individual common end null.
- [ ] Timer mode snapshot immutable.
- [ ] Activation creates no Student Attempt.
- [ ] scheduled_at preserved.
- [ ] active repeat/new key does not restart timer.
- [ ] same-key replay works after later lifecycle.
- [ ] all activation writes + idempotency completion are atomic.

---

# 67. Acceptance Criteria — Cross-Stage Compatibility

- [ ] Homework activation uses shared Assessment activation validator.
- [ ] Homework activation uses shared recipient/cohort engine.
- [ ] Existing Homework-first behavior remains green.
- [ ] Blitz-first cohort can later drive official Homework activation.
- [ ] Pair lock does not block activation of already-designated official task.
- [ ] Valid Blitz-origin pair lock is recognized from activity on either official Assessment; a Homework Attempt is not required merely to justify the lock.
- [ ] Locked-with-zero-official-activity and unlocked-with-existing-official-activity are rejected without repair.
- [ ] Shared idempotency exception is role-neutral.
- [ ] Student Homework idempotency remains unchanged.
- [ ] Topic close/archive guard includes unresolved Blitz.
- [ ] No Stage 8 Student execution implemented.
- [ ] No Stage 9 scoring implemented.

---

# 68. Focused Diff Self-Check

Before completion confirm:

```text
official designation + activation engine only
```

Verify no:

- Blitz Close;
- Student Start;
- answer/file mutation;
- Submit;
- timeout;
- Scheduler;
- exception grant;
- monitoring;
- scoring/checking;
- migration/schema change;
- frontend/docs/task modification.

Verify specifically:

```text
PUT no longer clears Blitz when omitted
locked partial pair can be completed once
Blitz activation can consume Homework-established locked cohort
Homework activation can consume Blitz-established cohort
Homework activation accepts a valid Blitz-origin lock only when official activity evidence exists
pair lock/activity mismatches are rejected without repair
activation never starts Student Attempts
timer mode only snapshots at activation
```

---

# 69. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. result-pair PUT extension;
4. exact locked partial-pair completion behavior;
5. Blitz replacement behavior;
6. official cohort engine behavior;
7. Homework-first and Blitz-first compatibility;
8. timer snapshot behavior;
9. activation idempotency operation/fingerprint/result metadata;
10. role-neutral idempotency exception refactor;
11. Institution settings incomplete error/meta;
12. Topic open-assessment guard integration;
13. concurrency behavior;
14. focused result-pair tests;
15. focused activation tests;
16. Homework regression results;
17. Topic lifecycle regression results;
18. Student idempotency regression results;
19. direct BE-002 regression results;
20. Pint result;
21. `git diff --check`;
22. final `git status --short`;
23. focused scope/diff self-check;
24. any blocker/deviation.

Do not claim Stage 8 backend complete.

After delivery ChatGPT performs read-only acceptance review.

`S08-BE-005` remains blocked until:

```text
S08-BE-004 = Accepted / Delivered
```

---

# 70. Implementation Readiness Verdict

```text
Scope / non-goals                   = RESOLVED
Result-pair request extension       = RESOLVED
Homework-side preservation          = RESOLVED
Blitz candidate eligibility         = RESOLVED
Locked staged-pair completion       = RESOLVED
Preattempt Blitz replacement        = RESOLVED
Designation timestamp semantics     = RESOLVED
Activation endpoint/body/header     = RESOLVED
Activation lifecycle                = RESOLVED
Institution timer snapshot          = RESOLVED
Synchronized timing                 = RESOLVED
Individual timing                   = RESOLVED
Practice recipients                 = RESOLVED
Official cohort establishment       = RESOLVED
Official cohort reuse               = RESOLVED
Homework-first compatibility        = RESOLVED
Blitz-first compatibility           = RESOLVED
Pair-lock activation meaning        = RESOLVED
Idempotency operation/fingerprint   = RESOLVED
Replay/new-key semantics            = RESOLVED
Idempotency exception architecture  = RESOLVED
Error/meta behavior                 = RESOLVED
Topic lifecycle integration         = RESOLVED
Tenant/security boundary            = RESOLVED
Lock ordering/concurrency           = RESOLVED
Acceptance criteria                 = RESOLVED
Focused verification                = RESOLVED

Implementation Readiness Gate       = PASS
Execution dependency                = S08-BE-003 Accepted / Delivered
```
