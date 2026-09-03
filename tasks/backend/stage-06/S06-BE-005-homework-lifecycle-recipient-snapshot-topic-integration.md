# Codex Implementation Contract: S06-BE-005 — Homework Lifecycle, Recipient Snapshot and Topic Integration

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S06-BE-005` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Area | `Backend` |
| Status | `Accepted` |
| Delivery | `Delivered — PR #151` |
| Delivered merge | `2bf1b94328f81810566af9bb0e9c739267e1352a` |
| Acceptance review | `PASS — P1=0, P2=0, P3=0` |
| Implementation type | `Laravel Homework lifecycle + recipient snapshot + Topic lifecycle integration` |
| Depends on | `S06-BE-001…004` — all `Accepted / Delivered` before implementation |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` after dependencies are delivered and immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |
| Backend block checkpoint | Stage 6 Backend Phase 2 after `S06-BE-001…006` are `Accepted / Delivered` |

Start only when all dependencies are `Accepted / Delivered`, this task remains `Approved`, ChatGPT has re-checked current `origin/main`, and Git preflight is safe.

This file is the complete task-specific implementation contract. Do not create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. delivered S06-BE-001…004 source/tests directly required by this task;
5. current Stage 5 Topic lifecycle Actions/requests/tests directly required for the Topic integration below.

Do not read product specifications, roadmap files, architecture/database/API documents, previous task files, Stage history, Stage indexes, or closure reviews to determine requirements.

This contract already resolves:

- Homework lifecycle transitions;
- exact idempotent same-target behavior;
- activation validation;
- authoritative deadline rule;
- exact points recalculation;
- Group and selected-recipient activation semantics;
- no fabricated Attempts;
- Stage 6 close boundary before Stage 7 answer/finalization persistence exists;
- Topic close/archive integration;
- lock ordering and concurrency;
- no-op timestamps;
- error codes;
- strict lifecycle request shape;
- API response contract;
- focused verification.

If a delivered dependency materially conflicts with the names or invariants below, return `BLOCKED` with exact evidence. Do not make a new product/lifecycle/security/schema decision independently.

---

# 3. Goal

Complete the Teacher-controlled Homework lifecycle for Stage 6.

An authorized Teacher must be able to:

1. activate a valid draft Homework;
2. freeze/establish its current recipient set for Student execution;
3. close an active Homework safely;
4. archive a draft or closed Homework;
5. repeat the same lifecycle command idempotently without timestamp churn;
6. prevent a Topic from becoming closed/archived while it still contains open Homework.

Stage 6 still has **no public Student Homework execution API**. Therefore this task must preserve the future Stage 7 close/deadline finalization contract without inventing incomplete answer/scoring behavior now.

---

# 4. Included Endpoints

Implement exactly:

```text
POST /api/v1/teacher/homework/{homework}/activate
POST /api/v1/teacher/homework/{homework}/close
POST /api/v1/teacher/homework/{homework}/archive
```

All belong inside the existing Teacher middleware group:

```text
auth:sanctum
active.account
password.changed
role:teacher
```

Reuse the full Teacher Homework resource delivered by S06-BE-003.

---

# 5. Explicit Non-Goals

Do not implement:

- official Homework designation;
- result-pair GET/PUT;
- Student Homework list/detail;
- Student Attempt start;
- answer save;
- final submit;
- answer tables;
- automatic/manual checking;
- official score selection;
- Homework deadline scheduler/reconciler;
- deadline auto-finalization;
- task-close answer auto-finalization;
- Student file submission;
- Blitz;
- Topic result calculation;
- result release;
- notifications;
- frontend;
- seed/E2E data;
- docs;
- dependency additions;
- task/Stage bookkeeping;
- unrelated refactors.

Do not create fake/empty Attempts for Students who never started.

Do not introduce a temporary answer/scoring model merely to make close simulate Stage 7 behavior.

---

# 6. Dependency Contract

## 6.1 S06-BE-001

Required delivered persistence/models:

```text
assessments
homework_assignments
assessment_students
assessment_attempts
topic_result_pairs
```

Required lifecycle states:

```text
draft
active
closed
archived
```

Required structural Attempt status includes:

```text
in_progress
submitted
timed_out_finalized
waiting_for_teacher_review
checked
```

## 6.2 S06-BE-002

Required delivered Question domain:

```text
QuestionConfigurationValidator
QuestionPositionSetValidator
QuestionAuthoringLimits
```

with normalized typed Question persistence.

## 6.3 S06-BE-003

Required delivered support/application contracts:

```text
TeacherHomeworkAccess
TeacherHomeworkResource
AssessmentPointMath
```

and current Group/selected recipient authoring behavior.

## 6.4 S06-BE-004

Question mutation is already constrained so:

- scoring Question content is editable only before any Attempt;
- active Homework cannot be edited into zero total scoreable points;
- Question mutation and future first Attempt serialize through the Assessment row.

S06-BE-005 must use the same Assessment row as the lifecycle/activation serialization boundary.

---

# 7. Homework Lifecycle State Machine

The exact Stage 6 lifecycle is:

```text
draft -> active
draft -> archived
active -> closed
closed -> archived
archived -> terminal
```

No transitions:

```text
active -> archived
closed -> active
archived -> any other state
```

No reopen/reactivate behavior.

---

# 8. Lifecycle Idempotency

Same-target commands are idempotent.

## 8.1 Activate active Homework

```text
active -> activate
```

Return current authoritative Homework:

```text
200 OK
```

Do not:

- rewrite recipient rows;
- recalculate/write points;
- rewrite `activated_at`;
- touch Assessment/Homework timestamps;
- revalidate deadline;
- create anything.

## 8.2 Close closed Homework

```text
closed -> close
```

Return:

```text
200 OK
```

No writes/timestamp changes.

## 8.3 Archive archived Homework

```text
archived -> archive
```

Return:

```text
200 OK
```

No writes/timestamp changes.

Authorization/current Teacher membership is still required before an idempotent response. Idempotency must not reveal or reopen inaccessible data.

---

# 9. Strict Lifecycle Request Contract

Use the current Teacher Topic lifecycle request semantics.

Each lifecycle POST accepts only:

```text
no request body
```

or:

```json
{}
```

with:

```text
Content-Type: application/json
```

No query parameters.

Reject:

- non-empty JSON object;
- JSON array;
- scalar;
- malformed JSON;
- non-empty non-JSON body;
- any query parameter.

Result:

```text
422 validation_failed
```

A shared Teacher Homework lifecycle request class is expected.

Do not accept lifecycle state in the body.

---

# 10. Privacy-Safe Homework Access

`{homework}` is the Assessment UUID.

Resolve only through the delivered `TeacherHomeworkAccess` boundary:

- valid UUID;
- `assessment.type = homework`;
- same Institution as authenticated Teacher;
- `assessment.teacher_id = authenticated Teacher`;
- owning Topic belongs to the same Teacher/Institution;
- Teacher has current membership in the Topic Group.

Malformed, foreign-Tenant, another Teacher's, inaccessible, or non-Homework ID:

```text
404 resource_not_found
```

Do not globally resolve Homework/Assessment first and then reveal an authorization result.

---

# 11. Activation — Endpoint

```text
POST /api/v1/teacher/homework/{homework}/activate
```

Successful draft activation:

```text
200 OK
```

Message:

```text
Homework activated successfully.
```

Return the complete authoritative Teacher Homework resource.

---

# 12. Activation — Required Parent State

Before a draft Homework can activate:

## 12.1 Topic

Owning Topic must be:

```text
active
```

If Topic is:

```text
draft
closed
archived
```

return:

```text
409 topic_not_editable
```

## 12.2 Group

Topic Group must still be:

```text
active
```

Otherwise:

```text
409 topic_not_editable
```

## 12.3 Teacher membership

Current Teacher Group membership must still exist.

Loss of current relationship makes Homework inaccessible:

```text
404 resource_not_found
```

Do not convert lost authorization into a lifecycle conflict.

---

# 13. Activation — Homework Metadata Validation

The locked Assessment/Homework aggregate must still satisfy:

```text
assessment.type = homework
title = non-empty after trim, max 255
student_instructions = non-empty after trim, max 10000
assignment_mode in (group, selected_students)
homework status = draft
```

`description` remains optional.

If persisted metadata is incomplete/corrupt in a way ordinary Teacher PATCH can correct:

```text
409 business_conflict
```

Do not silently repair it.

Do not read client-supplied lifecycle metadata because activation body has no fields.

---

# 14. Activation — Question Aggregate Validation

Activation must validate the authoritative persisted Question graph, not trust only the stored `total_possible_points`.

## 14.1 Question count

Require:

```text
1 <= question_count <= QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT
```

Zero Questions:

```text
409 assessment_has_no_scoreable_points
```

## 14.2 Positions

Locked current Question positions must be exact canonical:

```text
1..N
```

Use `QuestionPositionSetValidator`.

Invalid persisted order/configuration:

```text
409 business_conflict
```

## 14.3 Typed configuration

For every Question:

1. reconstruct its canonical persisted type-specific configuration;
2. verify type/checking mode/configuration compatibility through the delivered `QuestionConfigurationValidator`;
3. verify no incompatible typed child rows coexist.

Activation must therefore catch malformed/incomplete direct database state, not only API-authored happy paths.

A narrow reusable reader/validator is allowed, for example:

```text
App\Support\Assessment\QuestionConfigurationReader
App\Domain\Assessment\PersistedQuestionAggregateValidator
```

or equivalent.

If S06-BE-003 Teacher Question serialization already contains reusable canonical reconstruction logic, extract/reuse it instead of duplicating nine type readers.

Do not make an HTTP Resource the business-validation dependency.

Invalid/incomplete typed Question configuration:

```text
409 business_conflict
```

## 14.4 Points

Every current Question point value must satisfy delivered structural/domain limits.

Recalculate the sum from locked current Questions using:

```text
AssessmentPointMath
```

Immediately before activation.

Require:

```text
total_possible_points > 0
```

If not:

```text
409 assessment_has_no_scoreable_points
```

Client-stored/prior total is not authority.

On successful activation, persist the freshly recalculated exact scale-6 total even if the stored value was stale.

If the recalculated value equals the stored value, no separate extra write is required before the lifecycle write.

---

# 15. Activation — Deadline Contract

`deadline_at` is optional.

When non-null, it is already persisted as an authoritative UTC instant.

Capture one server-authoritative transition instant:

```text
transitionedAt = now()
```

after required locks are held.

Activation requires:

```text
deadline_at > transitionedAt
```

If:

```text
deadline_at <= transitionedAt
```

return:

```text
409 deadline_passed
```

No activation writes.

Do not consult:

- device clock;
- device timezone;
- client-provided current time.

No minimum future duration beyond `> now` is imposed.

Changing Institution timezone after deadline storage does not rewrite the absolute deadline.

---

# 16. Activation — Recipient Rules

Activation creates/validates the recipient set that future Student Homework execution will use.

No Attempt rows are created.

## 16.1 Common eligible Student definition

An eligible Student at activation is:

- same Institution;
- User role = Student;
- User `is_active = true`;
- current `GroupStudentMembership` for Topic Group;
- membership `ended_at IS NULL`.

At least one recipient is required for activation.

If no valid recipient set exists:

```text
409 assessment_not_assigned
```

## 16.2 Group Homework activation

For:

```text
assignment_mode = group
```

the draft is expected to have no recipient rows.

At activation:

1. lock the current eligible Group Student membership/User set;
2. derive the complete eligible Student UUID set;
3. require at least one;
4. create exactly one `assessment_students` row per eligible Student with:

```text
institution_id = Teacher Institution
assessment_id = Homework Assessment
student_id = eligible Student
assignment_source = group
assigned_at = transitionedAt
assigned_by_user_id = authenticated Teacher
```

The persisted active recipient set is a snapshot.

Do not include:

- former members;
- inactive Students;
- foreign-Institution users.

Do not create duplicate rows.

If unexpected recipient rows already exist for a draft Group Homework, do not merge silently. Treat as invalid draft state:

```text
409 business_conflict
```

unless the delivered S06-BE-003 contract explicitly created a valid equivalent draft representation. The intended S06-BE-003 contract is zero Group recipient rows before activation.

## 16.3 Selected Students Homework activation

For:

```text
assignment_mode = selected_students
```

draft direct recipient rows already represent the Teacher's selected working set.

Activation must:

1. lock all persisted direct recipient rows;
2. require at least one;
3. reject duplicate/inconsistent source rows;
4. re-resolve every selected Student against the common eligible definition;
5. require the eligible set to equal the persisted selected set exactly.

If any previously selected Student became:

- inactive;
- no longer current Group member;
- foreign/inconsistent;

return:

```text
409 assessment_not_assigned
```

Do not silently drop the Student.

The Teacher must PATCH the selection before activating.

On successful activation:

- preserve the same recipient row IDs;
- preserve existing `assigned_at`;
- preserve existing unchanged selected history;
- do not delete/reinsert all rows merely to call them a snapshot.

They become the authoritative active recipient set.

---

# 17. Activation — Transaction and Lock Order

Activation runs in one database transaction.

Use stable lock order compatible with prior tasks:

1. Topic Group;
2. current Teacher–Group membership;
3. Topic;
4. Assessment;
5. HomeworkAssignment;
6. existing `topic_result_pairs` row referencing this Homework, when present;
7. current Questions in position/ID order;
8. typed Question configuration rows required for validation;
9. existing `assessment_students`;
10. eligible Student Users/current GroupStudentMembership rows.

Re-check all relevant state after locks.

The lifecycle transition and recipient snapshot must be atomic.

If any validation fails:

- status remains draft;
- no recipient snapshot delta commits;
- no points change commits;
- no lifecycle timestamp changes;
- no aggregate timestamp changes.

---

# 18. Activation — Writes

On successful draft activation, using the single captured `transitionedAt`:

```text
homework_assignments.status = active
homework_assignments.activated_at = transitionedAt
homework_assignments.closed_at = null
homework_assignments.archived_at = null
homework_assignments.updated_at = transitionedAt
```

Persist exact recalculated:

```text
assessments.total_possible_points
```

and:

```text
assessments.updated_at = transitionedAt
```

Recipient snapshot rows are created/preserved as Section 16 defines.

Do not create:

- Attempt rows;
- result-pair rows;
- official designation;
- scores.

---

# 19. Close — Endpoint

```text
POST /api/v1/teacher/homework/{homework}/close
```

Successful active close:

```text
200 OK
```

Message:

```text
Homework closed successfully.
```

Return complete Teacher Homework resource.

---

# 20. Close — State Rules

Allowed transition:

```text
active -> closed
```

Same-target:

```text
closed -> close
```

is idempotent as Section 8.

If current status is:

```text
draft
```

return:

```text
409 task_not_active
```

If:

```text
archived
```

return:

```text
409 task_archived
```

Owning Topic must remain privacy-safe accessible.

A Topic already closed is allowed when the Homework itself is already closed and the call is the idempotent same-target case.

For a real `active -> closed` transition, owning Topic must not be archived.

If Topic is archived in an inconsistent direct-DB state:

```text
409 topic_not_editable
```

---

# 21. Close — Stage 6 Attempt Boundary

The locked MVP business rule ultimately requires close to auto-finalize every `in_progress` Attempt from saved answers.

That full behavior belongs to Stage 7 because Stage 6 intentionally has:

- no Student answer persistence;
- no answer checking;
- no Attempt execution API.

Therefore Stage 6 must not fabricate incomplete finalization.

## 21.1 Stage 6 safe rule

Before `active -> closed`, lock/check current Attempts.

If **any** Attempt has:

```text
status = in_progress
```

return:

```text
409 business_conflict
```

with a non-sensitive message that active Student work cannot yet be closed by the current execution layer.

Do not mutate Homework or Attempt.

## 21.2 Other completed/finalized Attempt rows

Structural test/future rows with statuses such as:

```text
submitted
timed_out_finalized
waiting_for_teacher_review
checked
```

do not by themselves block close because they are not active answer-editing sessions.

## 21.3 Frozen Stage 7 extension contract

Before public Homework Attempt start is enabled in Stage 7, Stage 7 must replace the temporary `in_progress` close guard with the final required behavior:

```text
lock Homework/Attempts
auto-finalize each in_progress Attempt from saved server answers
unanswered = zero
manual answered components -> waiting for teacher review
finalization_reason = task_closed_auto_finalize
submitted_at remains null for auto-finalization
then close Homework atomically
```

Stage 7 must preserve the same lifecycle endpoint and public success contract.

S06-BE-005 must structure the close Action so this finalizer can be inserted cleanly; do not bury close transition logic in a controller/model.

---

# 22. Close — Transaction / Writes

Run in one transaction.

Stable lock order:

1. Topic Group;
2. current Teacher–Group membership;
3. Topic;
4. Assessment;
5. HomeworkAssignment;
6. relevant result-pair row if present;
7. Assessment Attempts in deterministic order.

After locks:

- re-check access/status;
- idempotent closed returns with no writes;
- reject draft/archived;
- reject `in_progress` Stage 6 boundary.

Capture:

```text
transitionedAt = now()
```

Then:

```text
homework_assignments.status = closed
homework_assignments.closed_at = transitionedAt
homework_assignments.updated_at = transitionedAt
assessments.updated_at = transitionedAt
```

Preserve:

```text
activated_at
deadline_at
archived_at = null
recipient rows
Questions
points
Attempts
```

No recipient rows are deleted on close.

---

# 23. Archive — Endpoint

```text
POST /api/v1/teacher/homework/{homework}/archive
```

Success:

```text
200 OK
```

Message:

```text
Homework archived successfully.
```

Return complete Teacher Homework resource.

---

# 24. Archive — State Rules

Allowed:

```text
draft -> archived
closed -> archived
```

Same-target:

```text
archived -> archive
```

is idempotent.

Forbidden:

```text
active -> archived
```

Result:

```text
409 business_conflict
```

Teacher must close active Homework first.

There is no implicit close during archive.

## 24.1 Defensive Attempt rule

For `draft -> archived`, any existing Attempt row indicates inconsistent historical state.

Reject:

```text
409 business_conflict
```

Do not archive a draft that somehow already has activity.

For `closed -> archived`, historical finalized/submitted/reviewed Attempts are preserved.

If an inconsistent `in_progress` Attempt exists under a closed Homework:

```text
409 business_conflict
```

Do not mutate Attempt.

---

# 25. Archive — Writes

Run in the same parent lock order.

Capture:

```text
transitionedAt = now()
```

For `draft -> archived`:

```text
status = archived
activated_at = null
closed_at = null
archived_at = transitionedAt
```

For `closed -> archived`:

```text
status = archived
activated_at = preserved
closed_at = preserved
archived_at = transitionedAt
```

Always on a semantic archive:

```text
homework_assignments.updated_at = transitionedAt
assessments.updated_at = transitionedAt
```

Do not delete:

- Questions;
- recipients;
- Attempts;
- result-pair references.

Archive is historical/read-only, not deletion.

---

# 26. Topic Lifecycle Integration

Current Stage 5 Topic close/archive does not know about Stage 6 child Homework.

S06-BE-005 must extend Topic lifecycle safely.

## 26.1 Open child definition

A Homework is an open child when:

```text
homework_assignments.status IN ('draft', 'active')
```

and its Assessment belongs to that Topic.

Only:

```text
assessment.type = homework
```

is in scope for this Stage 6 guard.

Future Blitz integration will extend the same conceptual guard in its own stage.

## 26.2 Topic close

For a real:

```text
Topic active -> closed
```

after locking Topic and before changing status, lock/check all Homework child lifecycle rows.

If any child Homework is:

```text
draft
active
```

reject:

```text
409 topic_has_open_assessments
```

No Topic/Homework writes.

Teacher must explicitly resolve Homework first:

- draft Homework -> archive or activate/close as appropriate;
- active Homework -> close.

Do not cascade Homework lifecycle from Topic close.

If Topic is already closed, preserve existing Stage 5 same-target idempotency and return no-op; do not retroactively mutate children.

## 26.3 Topic archive

For real Topic archive from:

```text
draft
closed
```

lock/check child Homework.

If any child Homework is:

```text
draft
active
```

reject:

```text
409 topic_has_open_assessments
```

No cascade.

If Topic is already archived, preserve current same-target idempotency.

## 26.4 New stable machine code

Add/support:

```text
topic_has_open_assessments
```

HTTP:

```text
409 Conflict
```

Message must be non-sensitive and explain that open Homework must be resolved before Topic closure/archive.

Do not return child IDs in the error.

---

# 27. Topic / Homework Concurrency

Topic lifecycle and Homework lifecycle must serialize so these invalid outcomes cannot occur:

```text
Topic closes while a child Homework concurrently activates
Topic archives while a child Homework concurrently becomes active
Homework activates under a Topic that concurrently closes
```

Required shared parent lock order begins with:

```text
Group
TeacherGroupMembership
Topic
```

and then child Assessment/Homework.

A real Topic close/archive must lock the relevant child Homework rows before committing the parent transition.

Homework activation must re-check Topic `active` after Topic lock.

Therefore one operation wins deterministically:

- if Topic close wins first, later Homework activation sees non-active Topic and rejects;
- if Homework activation wins first, Topic close sees open active Homework and rejects.

Do not rely on pre-transaction status reads alone.

---

# 28. Recipient Snapshot Concurrency

Activation must not snapshot stale membership.

For Group mode:

- lock current eligible membership rows;
- derive snapshot after locks.

For selected mode:

- lock persisted recipient rows;
- lock/re-resolve each selected Student/current membership.

Concurrent Student removal/deactivation must not result in an invalid newly active selected Homework.

If membership/user eligibility changes before activation's locked validation, activation rejects:

```text
409 assessment_not_assigned
```

If activation locks/wins first and commits a valid snapshot, later Group membership changes do not rewrite the active Homework's persisted recipients.

---

# 29. Result-Pair Interaction Boundary

S06-BE-005 does **not** create or change official designation.

If a `topic_result_pairs` row already exists due to future/direct fixture state:

- lifecycle actions may read/lock it for consistency;
- do not replace Homework;
- do not fill Blitz;
- do not set/clear `locked_at`;
- do not set `cohort_snapshotted_at`.

Official designation/cohort semantics belong to S06-BE-006.

Homework activation recipient snapshot must remain compatible with later official designation.

---

# 30. Aggregate `updated_at` / No-Op Contract

The Assessment is the Teacher authoring aggregate root.

On semantic lifecycle transition:

```text
assessments.updated_at = transitionedAt
homework_assignments.updated_at = transitionedAt
```

On same-target lifecycle no-op:

- no save;
- no touch;
- no recipient rewrite;
- no points rewrite;
- no timestamps changed.

On blocked lifecycle:

- zero writes.

Recipient rows:

- Group activation creates them once;
- selected activation preserves existing valid rows;
- close/archive do not rewrite them.

---

# 31. Application Actions / Placement

Expected Actions:

```text
ActivateTeacherHomework
CloseTeacherHomework
ArchiveTeacherHomework
```

Expected reusable lifecycle support may include:

```text
TeacherHomeworkLifecycleAccess
HomeworkActivationValidator
HomeworkRecipientSnapshotter
```

or equivalent narrow classes.

Reuse:

```text
TeacherHomeworkAccess
TeacherHomeworkResource
AssessmentPointMath
QuestionConfigurationValidator
QuestionPositionSetValidator
```

Add/extract canonical Question configuration reader only if needed to validate persisted typed aggregates without depending on an HTTP Resource.

Update existing:

```text
CloseTeacherTopic
ArchiveTeacherTopic
```

only for the child Homework guard/concurrency integration.

`ActivateTeacherTopic` should remain unchanged unless a narrowly necessary shared locking helper refactor is required; Stage 6 Homework is **not** a Topic activation prerequisite.

Do not create a generic lifecycle engine/state-machine framework.

Controllers remain thin.

Models remain free of workflow transitions.

---

# 32. Error Contract

Use existing global envelope.

| Case | Required result |
|---|---|
| Unauthenticated | `401 authentication_required` |
| Account/Institution inactive | existing middleware contract |
| Password change required | `403 password_change_required` |
| Wrong role | existing Teacher role middleware contract |
| Malformed/foreign/unowned/inaccessible Homework | `404 resource_not_found` |
| Lost current Teacher Group relationship | `404 resource_not_found` |
| Non-empty lifecycle body/query | `422 validation_failed` |
| Activate while Topic not active / Group not active | `409 topic_not_editable` |
| Invalid persisted Homework/Question configuration | `409 business_conflict` |
| No Questions / total <= 0 | `409 assessment_has_no_scoreable_points` |
| Deadline already reached/passed at activation | `409 deadline_passed` |
| No valid activation recipient set | `409 assessment_not_assigned` |
| Close draft | `409 task_not_active` |
| Activate closed | `409 task_closed` |
| Activate/archive closed according to allowed transition | activate -> `task_closed`; archive is allowed |
| Any operation against archived except archive no-op | `409 task_archived` |
| Active -> archive | `409 business_conflict` |
| Stage 6 close with `in_progress` Attempt | `409 business_conflict` |
| Topic close/archive with draft/active Homework | `409 topic_has_open_assessments` |
| Unexpected failure | safe existing `500 server_error` |

Do not leak SQL, stack traces, child IDs, foreign record existence, or Student details.

---

# 33. Success Resource Contract

Reuse the complete `TeacherHomeworkResource` from S06-BE-003.

Lifecycle responses must include authoritative:

```text
status
total_possible_points
deadline_at
institution_timezone
attempt_policy
activated_at
closed_at
archived_at
created_at
updated_at
student_ids
questions
```

Timestamps remain UTC RFC3339.

No new lifecycle-only response DTO.

---

# 34. Expected Files and Areas

| Area | Action |
|---|---|
| `backend/routes/api.php` | Add three Homework lifecycle routes only |
| `backend/app/Actions/Teacher/ActivateTeacherHomework.php` | Create |
| `backend/app/Actions/Teacher/CloseTeacherHomework.php` | Create |
| `backend/app/Actions/Teacher/ArchiveTeacherHomework.php` | Create |
| `backend/app/Support/Teacher/TeacherHomeworkAccess.php` | Extend narrowly if lifecycle lock helper needed |
| `backend/app/Support/Teacher/TeacherHomeworkLifecycleAccess.php` or equivalent | Create if it prevents duplication |
| `backend/app/Domain/Assessment/HomeworkActivationValidator.php` or equivalent | Create focused persisted aggregate validation |
| `backend/app/Support/Assessment/QuestionConfigurationReader.php` or equivalent | Create/extract only if required |
| `backend/app/Support/Teacher/HomeworkRecipientSnapshotter.php` or equivalent | Create if snapshot logic merits focused abstraction |
| `backend/app/Http/Controllers/Api/V1/Teacher/TeacherHomeworkController.php` or lifecycle controller | Extend/create lifecycle methods |
| `backend/app/Http/Requests/Teacher/TeacherHomeworkLifecycleRequest.php` | Create |
| `backend/app/Actions/Teacher/CloseTeacherTopic.php` | Modify — block open Homework |
| `backend/app/Actions/Teacher/ArchiveTeacherTopic.php` | Modify — block open Homework |
| Teacher Topic conflict exception/error mapping | Modify/create narrowly for `topic_has_open_assessments` |
| `backend/tests/Feature/Teacher/TeacherHomeworkLifecycleApiTest.php` | Create |
| `backend/tests/Feature/Teacher/TeacherHomeworkActivationRecipientTest.php` | Create |
| `backend/tests/Feature/Teacher/TeacherHomeworkLifecycleAuthorizationTest.php` | Create |
| `backend/tests/Feature/Teacher/TeacherHomeworkLifecycleConcurrencyTest.php` | Create |
| `backend/tests/Feature/Teacher/TeacherTopicLifecycleApiTest.php` or current equivalent | Modify/add focused child-guard coverage only |
| `backend/tests/Feature/Teacher/TeacherTopicLifecycleConcurrencyTest.php` | Modify/add Stage 6 cross-lifecycle race coverage only |

Changes outside these areas require a concrete necessity and must be reported.

Do not modify migrations, Question schema, frontend, docs, seeders, dependencies, task files, or unrelated code.

---

# 35. Acceptance Criteria

- [x] Exact activate/close/archive Teacher Homework routes exist.
- [x] Lifecycle request accepts only no body or `{}` and rejects query/body data.
- [x] Homework direct IDs are privacy-safe and tenant/Teacher/current-membership scoped.
- [x] State machine is exactly `draft->active`, `draft->archived`, `active->closed`, `closed->archived`.
- [x] Activate/close/archive same-target operations are idempotent with zero timestamp/write churn.
- [x] Activation requires active Topic and active Group.
- [x] Activation revalidates complete persisted Question configuration.
- [x] Activation recalculates total exactly from locked Questions.
- [x] Zero Questions/zero total cannot activate.
- [x] Optional deadline must be strictly future relative to authoritative server time at activation.
- [x] Group activation snapshots exactly current active eligible Group Students.
- [x] Group activation requires at least one recipient.
- [x] Selected activation requires at least one persisted direct recipient and revalidates the exact selected set.
- [x] Selected Student becoming ineligible blocks activation rather than being silently dropped.
- [x] Activation creates no Attempts and no official result pair.
- [x] Successful activation writes lifecycle + aggregate timestamps once and atomically.
- [x] Close draft is rejected; close closed is idempotent; close archived is rejected.
- [x] Stage 6 close blocks when an `in_progress` Attempt exists and never fabricates incomplete finalization.
- [x] Completed/finalized historical Attempt rows remain intact through close.
- [x] Archive supports draft/closed only and preserves historical data.
- [x] Active archive is rejected rather than implicitly closing.
- [x] Topic close is blocked by any child Homework in draft/active.
- [x] Topic archive is blocked by any child Homework in draft/active.
- [x] Topic lifecycle never cascades Homework state.
- [x] New `409 topic_has_open_assessments` contract is deterministic and non-sensitive.
- [x] Topic close/archive versus Homework activation is transactionally race-safe.
- [x] Recipient snapshot is race-safe against membership changes.
- [x] Lifecycle semantic transitions touch Assessment + HomeworkAssignment `updated_at`; no-op/blocked operations do not.
- [x] Existing Stage 5 Topic lifecycle behavior remains unchanged when no Stage 6 open Homework exists.
- [x] No Student Attempt API, answer persistence, scoring, official designation, Blitz, frontend, docs, seed, dependency, or unrelated work enters scope.
- [x] Focused tests pass.
- [x] Pint passes.
- [x] `git diff --check` passes.
- [x] Final focused diff review finds no blocking tenant/security/lifecycle/concurrency/data-integrity issue.

## 35.1 Delivery Evidence

- Delivered in PR #151; merge `2bf1b94328f81810566af9bb0e9c739267e1352a`.
- Final independent review: `PASS — P1=0, P2=0, P3=0`.
- Focused verification: 89 tests / 1,538 assertions.
- Pint: PASS.
- `git diff --check`: PASS.
- Delivery scope: exactly 26 backend files.
- Delivery baseline: local `main` matched `origin/main`, ahead/behind `0/0`, with a clean worktree.

---

# 36. Focused Tests and Verification

Run from:

```text
backend/
```

Do not run the full backend suite. Full backend regression belongs to Stage 6 Backend Phase 2.

## 36.1 New lifecycle tests

```bash
php artisan test \
  tests/Feature/Teacher/TeacherHomeworkLifecycleApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkActivationRecipientTest.php \
  tests/Feature/Teacher/TeacherHomeworkLifecycleAuthorizationTest.php
```

Required coverage:

### Activation state/validation

- valid draft -> active;
- active -> activate idempotent;
- closed -> activate `task_closed`;
- archived -> activate `task_archived`;
- Topic draft -> `topic_not_editable`;
- Topic closed/archived -> `topic_not_editable`;
- inactive Group -> `topic_not_editable`;
- malformed/inaccessible ID -> 404;
- missing current Teacher membership -> 404;
- no Questions -> `assessment_has_no_scoreable_points`;
- zero total -> same;
- exact points recalculation repairs stale stored total on successful activation;
- invalid typed persisted config -> `business_conflict`;
- gapped Question positions -> `business_conflict`;
- future deadline succeeds;
- deadline exactly/past authoritative now rejects;
- same-target active no-op does not revalidate/rewrite expired deadline.

### Recipients

- Group snapshots all current active Students;
- excludes former Group memberships;
- excludes inactive Students;
- excludes foreign Institution;
- zero eligible Group recipients -> `assessment_not_assigned`;
- selected valid set activates preserving recipient row IDs/`assigned_at`;
- selected empty -> `assessment_not_assigned`;
- selected Student removed before activation -> `assessment_not_assigned`;
- selected Student deactivated before activation -> same;
- blocked activation rolls back all snapshot/lifecycle/point writes;
- no Attempt rows are created.

### Close

- active -> closed;
- closed no-op;
- draft -> `task_not_active`;
- archived -> `task_archived`;
- active with no `in_progress` Attempt closes;
- active with `in_progress` structural Attempt -> `business_conflict`;
- submitted/checked historical Attempt does not get deleted/rewritten;
- no fake Attempt created.

### Archive

- draft -> archived;
- closed -> archived;
- archived no-op;
- active -> `business_conflict`;
- draft with corrupt Attempt -> `business_conflict`;
- closed with corrupt `in_progress` -> `business_conflict`;
- historical rows preserved.

### Strict request

- no body allowed;
- `{}` allowed;
- non-empty object rejected;
- array/scalar/malformed rejected;
- query param rejected.

### Timestamp/no-op

- transition timestamps exact/preserved;
- aggregate + lifecycle `updated_at` change on semantic transition;
- same-target no-op preserves all timestamps/recipients/points.

## 36.2 Topic integration regression

Run current Topic lifecycle tests with new focused cases.

At minimum:

```bash
php artisan test \
  tests/Feature/Teacher/TeacherTopicLifecycleApiTest.php \
  tests/Feature/Teacher/TeacherTopicLifecycleConcurrencyTest.php
```

If the exact delivered filename differs, use the current existing Topic lifecycle feature/concurrency test files that cover activate/close/archive.

Add/verify:

- Topic close with no Homework remains normal;
- Topic archive with no Homework remains normal;
- Topic close with only closed/archived Homework succeeds;
- Topic close with draft Homework -> `topic_has_open_assessments`;
- Topic close with active Homework -> same;
- Topic archive from draft with draft Homework -> same;
- Topic archive from closed with defensive open Homework fixture -> same;
- same-target Topic close/archive remains idempotent;
- no child Homework is cascaded.

## 36.3 Lifecycle concurrency

```bash
php artisan test tests/Feature/Teacher/TeacherHomeworkLifecycleConcurrencyTest.php
```

Required races:

- two concurrent activate calls -> one semantic transition, one effective no-op; one recipient snapshot;
- two concurrent close calls -> one semantic close, no timestamp churn from second;
- two concurrent archive calls -> one semantic archive;
- activation versus membership removal does not create invalid selected snapshot;
- Homework activation versus Topic close cannot both commit into invalid `Topic closed + Homework active`;
- Topic archive versus Homework activation cannot create invalid parent/child state.

Use the repository's established PostgreSQL concurrency approach.

## 36.4 Directly affected S06-BE-003/004 regression

Run the delivered Homework authoring and Question mutation tests that exercise the shared access/resource/aggregate state:

```bash
php artisan test \
  tests/Feature/Teacher/TeacherHomeworkAuthoringApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkRecipientApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkAuthorizationApiTest.php \
  tests/Feature/Teacher/TeacherQuestionEditingIntegrityTest.php
```

If exact delivered filenames vary while preserving those responsibilities, use their actual focused equivalents.

Run:

```bash
php artisan test tests/Unit/Domain/Assessment/AssessmentPointMathTest.php
```

Do not run the full backend suite.

## 36.5 Format

```bash
./vendor/bin/pint --test
```

## 36.6 Always

```bash
git diff --check
```

Then inspect the complete diff:

- only lifecycle/access/Topic guard/tests changed;
- no delivered migration/schema rewrite;
- no Student Attempt public API;
- no answer/scoring implementation;
- no fake Attempt finalization;
- no result-pair mutation/official designation;
- no child lifecycle cascade;
- no cross-Tenant unscoped lookup;
- no test weakening;
- no debug/secrets/temp artifacts/unrelated formatting churn.

If implementation necessarily touches shared infrastructure beyond this verification contract, report the exact regression risk instead of independently running a broad suite.

---

# 37. Project Owner Manual Check

```text
Not required at task level — backend lifecycle is covered by focused automated verification.
Real-stack lifecycle/recipient smoke belongs to S06-INT-001.
```

---

# 38. Delivery

Follow root `AGENTS.md` and `tasks/README.md`.

Delivery execution:

```text
Project Owner
```

Suggested:

```text
Branch: feat/s06-be-005-homework-lifecycle
Commit: feat(stage6): add homework lifecycle
PR base: main
```

Codex must not:

- commit;
- push;
- open/merge a PR;
- modify this task file;
- update Stage/task bookkeeping.

Codex stops after implementation, focused verification, `git diff --check`, and focused scope/diff review.

Task acceptance occurs only after approved delivery is present on `origin/main`, local `main == origin/main`, ahead/behind `0/0`, and worktree clean.

---

# 39. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to rediscover requirements.

| Source/reference | Decision already encoded above |
|---|---|
| Approved Stage 6 decomposition | BE-005 owns Homework lifecycle, activation recipient snapshot, Topic integration |
| Homework lifecycle rules | Draft / Active / Closed / Archived |
| Activation business rule | complete valid Questions/correct-answer data and recalculated positive total required |
| Deadline business rule | backend UTC authority; already-passed deadline cannot support active execution |
| Close business rule | final system ultimately auto-finalizes in-progress work from saved answers |
| Approved Stage boundary | Stage 6 has no answer/execution layer; safe temporary close guard for structural in-progress Attempts, replaced in Stage 7 before public Attempt start |
| Editing-integrity rule | Student activity locks scoring content |
| Current Stage 5 Topic lifecycle | idempotent same-target actions with transactional Topic lock |
| Approved Topic integration resolution | Topic close/archive blocks while child Homework is draft/active; no hidden cascade |
| S06-BE-001 | lifecycle/recipient/Attempt/result-pair persistence |
| S06-BE-002 | typed Question validity |
| S06-BE-003 | Teacher Homework access/resource/recipient authoring/exact point math |
| S06-BE-004 | scoring-content lock and Assessment-row concurrency boundary |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |

---

# 40. Codex Final Report

Return one status:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

`DELIVERY BLOCKED` is not applicable because delivery is Project Owner-owned.

Return:

1. **Status**.
2. **Implementation** — concise result.
3. **Changed files** — file → purpose.
4. **Acceptance criteria** — concise PASS/FAIL evidence.
5. **Focused verification** — exact commands/results.
6. **Authorization/tenant** — evidence.
7. **Activation/recipient/deadline** — evidence.
8. **Lifecycle/idempotency** — evidence.
9. **Topic integration/concurrency** — evidence.
10. **Stage 7 boundary** — confirm no fake Attempt finalization was implemented.
11. **Scope/diff** — non-goals + `git diff --check`.
12. **Delivery handoff** — Project Owner + current Git state.
13. **Deviations/blockers** — exact facts.

Do not output task `Accepted`.

Do not repeat the contract or paste large successful logs.

If any required product, API, database, tenant, security, lifecycle, deadline, recipient, or concurrency decision is missing or conflicts with delivered dependencies/current source, return `BLOCKED` rather than deciding independently.
