# Codex Implementation Contract: S07-BE-004 — Idempotent Homework Attempt Start and Resume

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S07-BE-004` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel Student Homework Attempt start/resume + own-Attempt read + durable idempotency + official result-pair first-activity lock` |
| Depends on | `S07-BE-001`, `S07-BE-002`, `S07-BE-003` — all `Accepted / Delivered` before implementation |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Current review baseline | `origin/main @ b04833df22798c3c1ca42c3de3f0a0be01df4417` |
| Implementation baseline | ChatGPT re-checks current `origin/main` immediately before Codex starts |
| Readiness Gate | `PASS — contract corrected/revalidated`; execution remains blocked until `S07-BE-001`, `S07-BE-002`, and `S07-BE-003` are all `Accepted / Delivered` |
| Verification | focused Student Attempt/API/idempotency/concurrency verification only |
| Delivery | Project Owner |
| Backend block checkpoint | Stage 7 Backend Phase 2 after `S07-BE-001…007` |

Start only after all dependencies are delivered, the implementation baseline is re-checked, and Git preflight is safe.

Do not create a duplicate `CODEX-PROMPT`.

---

# 2. Context Boundary

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. delivered `S07-BE-001…003` source/tests directly required here;
5. current `AssessmentAttempt`, `AssessmentStudent`, `TopicResultPair`, Assessment/Homework Models/enums/factories;
6. current Student route/controller/request/resource patterns;
7. current Teacher Homework/Question/result-pair locking code and concurrency tests only where directly required to preserve lock ordering.

Do not read roadmap/product/architecture/database/API docs, previous task files, Stage history/indexes/closure reviews, frontend, or unrelated modules to determine requirements.

This contract resolves:

- exact POST/GET endpoints;
- strict request/header behavior;
- Student assignment/tenant authorization;
- active/deadline rules;
- start-vs-resume behavior;
- exactly three normal Homework Attempts;
- attempt-number allocation;
- durable idempotency claim/replay mechanics;
- same-key/different-request conflict;
- first official Homework Attempt `topic_result_pairs.locked_at`;
- concurrency/lock ordering;
- response shapes;
- exact error behavior;
- tests and verification.

If delivered dependencies materially conflict with this contract, return `BLOCKED` with exact evidence. Do not redesign.

---

# 3. Goal

Implement Student Homework Attempt execution entry:

```text
POST /api/v1/student/homework/{homework}/attempts
GET  /api/v1/student/attempts/{attempt}
```

The POST has create-or-resume semantics:

```text
no current in_progress Attempt
+ capacity/lifecycle/deadline valid
=> create next Attempt
=> 201

current in_progress Attempt exists
+ lifecycle/deadline still valid
=> return same Attempt
=> 200
```

Never create parallel in-progress Homework Attempts.

The first Attempt on the official Homework must atomically lock the existing Topic result-pair meaning/cohort before the Attempt row is inserted.

High-risk Start is protected by durable PostgreSQL idempotency from BE-001.

---

# 4. Explicit Non-Goals

Do not implement:

- answer save/replace;
- Student file upload/replace;
- Student final Submit;
- answer checking/scoring;
- Teacher review;
- official score selection;
- Topic result recalculation;
- Blitz execution;
- frontend;
- E2E/seeders;
- schema migration;
- docs/task bookkeeping;
- new package/dependency;
- unrelated refactor.

The GET Attempt endpoint in this task returns Attempt state + Student-safe Questions only.

It does **not** yet return saved answer payloads. BE-005/BE-006 extend the execution representation when those mutation flows are implemented.

---

# 5. Routes

Modify:

```text
backend/routes/api.php
```

inside the existing Student middleware group:

```text
auth:sanctum
active.account
password.changed
role:student
```

Add exactly:

```text
POST student/homework/{homework}/attempts
GET  student/attempts/{attempt}
```

Controller:

```text
App\Http\Controllers\Api\V1\Student\StudentHomeworkAttemptController
```

Methods:

```text
store
show
```

No aliases or duplicate route families.

---

# 6. POST Request Contract

Create:

```text
backend/app/Http/Requests/Student/StudentHomeworkAttemptStartRequest.php
```

## 6.1 Required header

Require:

```http
Idempotency-Key: <client-generated-uuid>
```

Expose it to Form Request validation as:

```text
idempotency_key
```

Rules:

```text
required
string
uuid
```

Missing/malformed:

```text
422 validation_failed
```

with field-level error under:

```text
idempotency_key
```

Return normalized validated UUID through:

```text
idempotencyKey(): string
```

using lowercase canonical string form.

## 6.2 Body

Accept only:

```text
no body
```

or:

```http
Content-Type: application/json
```

```json
{}
```

Reject:

- non-empty JSON object;
- JSON array;
- `null`;
- scalar JSON;
- malformed JSON;
- non-empty non-JSON body.

Return:

```text
422 validation_failed
```

Use the same strict empty/`{}` behavior already established by lifecycle POST requests.

## 6.3 Query

No query parameters.

Any query key:

```text
422 validation_failed
```

---

# 7. GET Attempt Request

Create:

```text
backend/app/Http/Requests/Student/StudentHomeworkAttemptShowRequest.php
```

No query parameters.

No request body.

Any query/body:

```text
422 validation_failed
```

Follow the delivered BE-003 Student show-request convention.

---

# 8. Preliminary Student Homework Authorization

Reuse delivered BE-003:

```text
StudentHomeworkAccess
```

or its exact delivered equivalent.

Before any idempotency lookup/domain transaction, POST must resolve `{homework}` through the Student-assigned read scope.

Required:

```text
same Institution
assessment.type = homework
persisted assessment_students row for authenticated Student
Homework status is Student-readable:
  active
  closed
  archived
```

Malformed UUID, foreign Institution, another Student's/unassigned Homework, draft Homework, non-Homework Assessment:

```text
404 resource_not_found
```

Do not expose same-Institution Homework existence to an unassigned Student.

Current Group membership is **not** required; persisted `assessment_students` assignment remains authoritative.

---

# 9. Idempotency Fingerprint

Create:

```text
backend/app/Support/Idempotency/IdempotencyRequestFingerprint.php
```

Provide a reusable method:

```text
make(
    User $actor,
    IdempotencyOperation $operation,
    array $routeIdentity,
    array $bodyIdentity = []
): string
```

For Start call it with:

```text
operation = student.homework.attempt.start

routeIdentity = {
  homework_id: lowercase authorized Homework UUID
}

bodyIdentity = {}
```

The fingerprint identity includes exactly:

```text
operation
institution_id
user_id
route identity
semantic body identity
```

Do not include:

- bearer token;
- raw headers;
- request ID;
- device metadata;
- idempotency key itself.

## 9.1 Canonicalization

Canonicalization must be deterministic:

- recursively sort associative-object keys lexicographically;
- preserve list order;
- preserve JSON scalar types;
- lowercase UUID values supplied by this operation;
- encode deterministic canonical JSON using PHP JSON throwing behavior;
- hash canonical bytes with:

```text
SHA-256
```

Return lowercase 64-character hex.

Do not use PHP serialization as the cross-process request fingerprint.

---

# 10. Reusable Idempotency Guard

Create:

```text
backend/app/Support/Idempotency/IdempotencyGuard.php
backend/app/Support/Idempotency/IdempotencyClaim.php
```

Use the delivered BE-001:

```text
IdempotencyRecord
IdempotencyOperation
idempotency_records
```

The guard is reusable by BE-007.

It must not know Student Homework product rules.

## 10.1 Transaction requirement

Every guard mutation/read-for-update method used by a protected operation must require:

```text
DB::transactionLevel() > 0
```

Otherwise throw `LogicException`.

## 10.2 Scope

Every lookup/claim uses exactly:

```text
institution_id
user_id
operation
idempotency_key
```

Never query globally by key first.

## 10.3 `completedReplay`

Provide:

```text
completedReplay(
    User $actor,
    IdempotencyOperation $operation,
    string $key,
    string $fingerprint
): ?IdempotencyRecord
```

Inside the caller transaction:

- query the exact scope;
- `lockForUpdate()` if a row exists;
- different fingerprint → throw `IdempotencyKeyReusedException`;
- completed row → return it;
- committed row with `completed_at = null` → invariant failure (`LogicException`);
- no row → `null`.

This lookup exists so a previously successful Start can replay even if the Homework is now closed/archived/deadline-passed.

Authorization to the Homework still occurs before this lookup.

## 10.4 `claim`

Provide:

```text
claim(
    User $actor,
    IdempotencyOperation $operation,
    string $key,
    string $fingerprint
): IdempotencyClaim
```

Use a PostgreSQL-safe conflict pattern:

```text
INSERT ... ON CONFLICT DO NOTHING
```

or Laravel `insertOrIgnore` equivalent against the authoritative unique scope.

Then load the scoped record:

```text
FOR UPDATE
```

Required outcomes:

### New claim

The current transaction inserted the row:

```text
IdempotencyClaim(new = true)
```

Record is incomplete.

### Concurrent/same-key completed claim

Another transaction already committed same scope/key:

- same fingerprint;
- completed record;

return:

```text
IdempotencyClaim(replay = true)
```

### Different fingerprint

Return no domain mutation.

Throw:

```text
409 idempotency_key_reused
```

### Committed incomplete row

This should be impossible under the contract.

Throw safe invariant failure; do not guess ownership or continue mutation.

## 10.5 `complete`

Provide:

```text
complete(
    IdempotencyClaim $claim,
    string $resourceType,
    string $resourceId,
    int $responseStatus
): void
```

Allowed only for a new incomplete claim.

For Start use:

```text
result_resource_type = assessment_attempt
result_resource_id = Attempt UUID
response_status = 201 for new Attempt
response_status = 200 for resume
completed_at = server now
```

Require 2xx status.

Do not modify a completed record.

## 10.6 `abandon`

Provide:

```text
abandon(IdempotencyClaim $claim): void
```

Allowed only for a new, still-incomplete claim.

Delete that transaction-local claim row.

This is used only when the authoritative Homework deadline becomes reached after the claim was acquired but before Attempt mutation: deadline reconciliation must commit, while the rejected Start must leave no persisted idempotency success/claim.

No completed idempotency record may be deleted.

---

# 11. Idempotency Public Semantics

Operation:

```text
student.homework.attempt.start
```

## Same key + same request identity

Return the same logical Attempt ID.

Preserve the originally recorded HTTP semantic status:

```text
201 remains 201
200 remains 200
```

Do not create a second Attempt.

Current safe Attempt serialization may be returned; byte-for-byte old response storage is not required.

Thus an old Start retry may show that the same Attempt has since been deadline-finalized, while still using its original stored Start HTTP status.

## Same key + materially different request

Example:

```text
same Student
same operation
same key
different authorized Homework UUID
```

Return:

```text
409 idempotency_key_reused
```

No new Attempt/domain mutation for the second request.

## Different actor scope

The same UUID key may be independently used by another:

- Student;
- Institution.

## Replay resource integrity

A completed Start record is replayable only when its referenced
`assessment_attempt` still exists and belongs to the same authorized
Student/Homework/recipient graph.

A broken or foreign replay target is:

```text
server invariant failure
```

not a new Start opportunity and not a privacy-safe `404` because the Student
already authorized the Homework and the corruption is internal persisted state.

## Failed Start

Validation/authorization/lifecycle/deadline/exhaustion/business failure must not leave a persisted incomplete idempotency record.

---

# 12. Student Attempt Access

Create:

```text
backend/app/Support/Student/StudentHomeworkAttemptAccess.php
```

This is query/locking infrastructure only.

No lifecycle/idempotency decisions in this class.

## 12.1 `resolveAttempt`

Required method:

```text
resolveAttempt(User $student, string $attemptId): AssessmentAttempt
```

Malformed UUID or inaccessible row:

```text
404 resource_not_found
```

Require all:

```text
assessment_attempts.institution_id = student.institution_id
assessment_attempts.student_id = student.id

assessment_students:
  id = assessment_attempts.assessment_student_id
  same institution
  same assessment_id
  student_id = student.id

assessments:
  same institution
  id = assessment_attempts.assessment_id
  type = homework

homework_assignments:
  same institution
  assessment_id = assessment
  status in (active, closed, archived)
```

No current Group membership requirement.

No global Attempt lookup followed by authorization.

## 12.2 Start parent lock

Required method/equivalent returns locked:

```text
Topic
Assessment
HomeworkAssignment
```

for the already preliminary-authorized Homework.

Lock order:

```text
Topic
-> Assessment
-> HomeworkAssignment
```

Student does not lock Group/current membership.

Teacher paths may lock Group before Topic, which does not create a reverse dependency because Student never subsequently requests the Group lock.

Recheck:

```text
same Student Institution
same Topic/Assessment relation
assessment.type = homework
```

## 12.3 Recipient lock

Lock exact:

```text
assessment_students
institution_id = student.institution_id
assessment_id = assessment.id
student_id = student.id
```

If the preliminary-authorized recipient disappears before the transaction lock:

```text
409 assessment_not_assigned
```

This code is only a post-authorization race/invariant outcome.

Normal direct access by a never-assigned Student remains privacy-safe `404`.

## 12.4 Result-pair lock

Lock the Topic's singleton:

```text
topic_result_pairs
institution_id = student.institution_id
topic_id = Topic.id
```

if it exists.

Do not query only by supplied Homework ID and miss a concurrent Topic singleton.

After parent locks, inspect whether:

```text
pair.homework_assessment_id = current Homework
```

If not, this Homework is practice/non-official for Start-lock purposes; do not mutate the pair.

## 12.5 Attempt locks

Provide deterministic lock methods:

### Current Student attempts

```text
same institution
same assessment
same student
order by attempt_number
then id
FOR UPDATE
```

### All Assessment attempts

Needed for official-pair integrity/deadline reconciliation:

```text
same institution
same assessment
order by id
FOR UPDATE
```

No unscoped cross-Institution reads.

---

# 13. Start Action

Create:

```text
backend/app/Actions/Student/StartStudentHomeworkAttempt.php
backend/app/Support/Student/StudentHomeworkAttemptStartResult.php
```

Public signature concept:

```text
__invoke(
    User $student,
    string $homeworkId,
    string $idempotencyKey
): StudentHomeworkAttemptStartResult
```

Public result after action returns successfully contains:

```text
attemptId
httpStatus
```

where status is:

```text
201
or
200
```

A deadline rejection uses an internal transaction outcome so deadline reconciliation can commit, then the public action throws the deadline exception after `DB::transaction` returns.

Do not throw from inside the transaction after performing deadline-finalization writes, because that would roll back required reconciliation.

---

# 14. Start Transaction — Exact Order

After preliminary StudentHomeworkAccess authorization and fingerprint calculation:

```text
DB::transaction(...)
```

Inside the transaction execute in this order.

## 14.1 Lock parent

Lock:

```text
Topic
Assessment
HomeworkAssignment
```

using Section 12.

## 14.2 Early completed replay

Call:

```text
IdempotencyGuard::completedReplay(...)
```

If completed same-fingerprint record exists:

- validate its result metadata is exactly compatible with Start:
  - `result_resource_type = assessment_attempt`;
  - `result_resource_id` non-null UUID;
  - `response_status in (200, 201)`;
- resolve the referenced Attempt through a scoped invariant query before replay;
- require the referenced Attempt to exist and satisfy:
  ```text
  institution_id = authenticated Student Institution
  student_id = authenticated Student
  assessment_id = this already-authorized Homework
  assessment_student_id points to an assessment_students row where:
    institution_id = Student Institution
    assessment_id = this Homework
    student_id = authenticated Student
  ```
- validate the referenced Attempt itself against the Homework Attempt history
  invariants in Section 14.8;
- return that logical result immediately;
- do not re-run current lifecycle/deadline/capacity allocation;
- do not change any Attempt/pair/idempotency timestamps.

The replay-target validation is an internal integrity check, not a new
authorization lookup. Preliminary Homework authorization already succeeded.

If the idempotency metadata is structurally incompatible, the referenced
Attempt is missing, points to another Student/Institution/Homework/recipient, or
violates the Homework Attempt history invariants:

```text
throw LogicException / server invariant failure
```

Do not return `404`, start a replacement Attempt, repair the idempotency record,
or silently follow the foreign/mismatched resource ID.

## 14.3 Re-lock recipient

Lock the exact Student recipient row.

Missing after preliminary authorization:

```text
409 assessment_not_assigned
```

No current Group membership query.

## 14.4 Acquire idempotency claim

Call:

```text
IdempotencyGuard::claim(...)
```

If claim resolves a concurrently completed same-fingerprint result:

- apply the same exact metadata + scoped replay-target Attempt validation from
  Section 14.2;
- return replay immediately only after that validation passes.

Different fingerprint:

```text
409 idempotency_key_reused
```

No domain mutation.

A newly inserted claim remains incomplete until successful create/resume.

## 14.5 Lifecycle

For a new logical operation, require owning Topic:

```text
status = active
```

Otherwise:

```text
409 task_not_active
```

Homework:

```text
active => continue
closed => 409 task_closed
archived => 409 task_archived
```

Draft is not reachable through preliminary Student access; if encountered under lock, treat as:

```text
409 task_not_active
```

Failures roll back the new idempotency claim.

## 14.6 Result-pair

Lock the Topic result-pair singleton.

If it points to another Homework, preserve it and treat this Homework as practice.

If it points to current Homework, apply Section 17.

## 14.7 Lock Attempts

If current Homework is official:

```text
lock all Assessment Attempts ordered by id
```

This provides:

- first-global-Attempt integrity;
- current Student Attempt state;
- lock-order compatibility with Teacher result/question/lifecycle paths.

If current Homework is practice/non-official:

```text
lock only authenticated Student's Attempts
```

ordered by attempt number/id.

## 14.8 Validate locked Homework Attempt history

Before the locked Attempt set may influence:

- deadline reconciliation;
- resume;
- normal Attempt capacity/exhaustion;
- next Attempt number;
- official-pair first/subsequent-activity integrity;

validate the relevant locked Homework Attempt history.

For every locked Homework Attempt used by this Start decision require:

```text
attempt.institution_id = Student Institution
attempt.assessment_id = current Homework Assessment
attempt.assessment_student_id resolves to an assessment_students row with:
  same Institution
  assessment_id = current Homework Assessment
  student_id = attempt.student_id

attempt.deadline_at = null
attempt.status in (
  in_progress,
  submitted,
  waiting_for_teacher_review,
  checked
)
attempt.finalization_reason != timeout_auto_submit
```

`timed_out_finalized` / `timeout_auto_submit` are Blitz-only and are invalid
inside Homework history.

For the authenticated Student's Attempts additionally require:

```text
attempt.student_id = authenticated Student
attempt.assessment_student_id = locked recipient.id
```

For every `in_progress` Homework Attempt require the structurally editable state:

```text
submitted_at = null
finalized_at = null
locked_at = null
finalization_reason = null
```

If any relevant row violates these invariants:

```text
throw LogicException / server invariant failure
outer transaction rolls back
```

Do not:

- resume the corrupted Attempt;
- count it toward exhaustion;
- use it as official-pair activity evidence;
- convert a Blitz-only state into a Homework state;
- repair recipient linkage/status/timestamps;
- create a replacement Attempt.

For the authenticated Student, attempt numbers must also form the normal
historical prefix:

```text
[]          => no history
[1]         => valid
[1, 2]      => valid
[1, 2, 3]   => valid
```

A gap/out-of-sequence set such as:

```text
[2]
[1, 3]
```

is a server invariant failure. Do not backfill the gap or allocate around it.

The database unique/range constraints remain defense-in-depth; this application
validation protects cross-column/history invariants that those constraints do
not fully express.

## 14.9 Capture authoritative Start decision instant

After required pair/recipient/Attempt locks, history validation, and any idempotency-key conflict wait completes, capture exactly one:

```text
startedAt = now()
```

Use this same instant for:

- deadline eligibility decision;
- new Attempt `started_at`;
- first official pair `locked_at`;
- first official pair `updated_at`.

Do not capture `startedAt` before lock waits.

---

# 15. Deadline at Start

With the locked Homework and captured:

```text
startedAt
```

deadline is passed when:

```text
deadline_at != null
AND startedAt >= deadline_at
```

At exact equality, Start is not allowed.

## 15.1 New claim cleanup

If this request owns a new incomplete idempotency claim:

```text
IdempotencyGuard::abandon(...)
```

before committing the deadline reconciliation.

No idempotency record remains for the failed Start.

## 15.2 Finalize due work

Ensure all current Assessment Attempts are locked ordered by ID.

Invoke delivered BE-002:

```text
FinalizeHomeworkAttemptsAtDeadline::finalizeLocked(
    $homework,
    $allLockedAttempts,
    $startedAt
)
```

It must preserve:

```text
finalized_at = exact Homework deadline
finalization_reason = homework_deadline_auto_submit
```

Commit the transaction.

After transaction returns, throw:

```text
409 deadline_passed
```

No new Attempt.

No fabricated Attempt for a never-started Student.

---

# 16. Fixed Attempt Policy

Homework normal Attempts are exactly:

```text
1
2
3
```

No configurable count.

Use all persisted Student/Assessment Attempt rows only after the locked history
has passed Section 14.8 invariants.

## 16.1 Resume first

If a locked current Student Attempt exists with:

```text
status = in_progress
```

return that existing Attempt.

Do not create another row.

Do not change:

```text
attempt_number
started_at
updated_at
```

Do not touch result-pair timestamps.

Successful independent Start/resume request:

```text
200 OK
```

Complete its new idempotency claim with:

```text
resource = same existing Attempt
response_status = 200
```

This remains true even when the existing Attempt is number 3.

## 16.2 Exhaustion

If no `in_progress` Attempt exists and:

```text
max(existing attempt_number) >= 3
```

return:

```text
409 attempts_exhausted
```

No Attempt #4.

The new idempotency claim rolls back with the failed transaction.

## 16.3 Next number

When capacity remains:

```text
next_attempt_number =
  1 when no previous rows
  otherwise max(attempt_number) + 1
```

Do not use `count + 1`.

Do not backfill a corrupted historical numbering gap. Section 14.8 rejects
such a gap as a server invariant before resume/exhaustion/allocation.

The database still enforces `1..3` and unique Student/Assessment/number.

---

# 17. Official Homework Result-Pair Lock

This implements the frozen Stage 6 future contract.

A Homework is official when the locked Topic singleton has:

```text
topic_result_pairs.homework_assessment_id = assessment.id
```

## 17.1 Required official integrity

Before creating/resuming a new logical Start request, require:

```text
pair.cohort_snapshotted_at IS NOT NULL
assessment.assignment_mode = group
recipient.assignment_source = group
```

The Student's locked `assessment_students` row is their official-cohort membership evidence.

Do not consult current Group membership.

If these invariants fail:

```text
409 business_conflict
```

No Attempt/pair mutation.

## 17.2 First global official Attempt

If:

```text
pair.locked_at IS NULL
```

then the locked, Section-14.8-validated global Assessment Attempt set must be empty.

If any existing Attempt already exists while pair lock is null:

```text
409 business_conflict
```

Do not silently repair historical inconsistency.

Immediately before inserting the new Attempt, set:

```text
pair.locked_at = startedAt
pair.updated_at = startedAt
```

Persist pair **before** Attempt insertion inside the same transaction.

Then insert the Attempt.

If Attempt insertion fails, transaction rollback restores pair to unlocked state.

## 17.3 Already locked official pair

If:

```text
pair.locked_at IS NOT NULL
```

preserve it.

Require at least one persisted, Section-14.8-validated global Homework Attempt
already exists before a new/subsequent Start can use that lock.

If pair is locked but no Attempt history exists:

```text
409 business_conflict
```

Do not replace lock timestamp.

## 17.4 Never rewrite official identity

Student Start must never change:

```text
homework_assessment_id
blitz_assessment_id
designated_by_user_id
designated_at
cohort_snapshotted_at
```

`blitz_assessment_id` may still be null.

A future Stage 8 completed pair remains compatible with this rule.

## 17.5 Practice Homework

If no pair exists, or the Topic pair points to another Homework:

- create/resume normally;
- do not change `topic_result_pairs`.

---

# 18. New Attempt Persistence

For a newly created Homework Attempt persist exactly:

```text
id = UUID
institution_id = Student Institution
assessment_id = Homework Assessment
assessment_student_id = locked recipient.id
student_id = authenticated Student
attempt_number = next number
status = in_progress
started_at = startedAt
deadline_at = null
submitted_at = null
finalized_at = null
finalization_reason = null
locked_at = null
official_score_eligible = true
earned_points = null
possible_points = Assessment.total_possible_points snapshot
normalized_score = null
scoring_completed_at = null
```

Homework Attempt-level:

```text
deadline_at
```

remains null; the authoritative Homework deadline is:

```text
homework_assignments.deadline_at
```

Require locked active Assessment:

```text
total_possible_points > 0
```

If an impossible active zero-point state is encountered:

```text
409 business_conflict
```

No Attempt.

No `attempt_answers` rows are created by Start.

No score/checking rows are created.

---

# 19. Idempotency Completion Ordering

For create:

```text
claim
-> validate final locked state
-> pair lock if first official activity
-> insert Attempt
-> complete idempotency record with 201
-> commit
```

For resume:

```text
claim
-> validate final locked state
-> identify existing in_progress Attempt
-> complete idempotency record with 200
-> commit
```

If completing the idempotency record fails, the Attempt/pair transaction must roll back.

There must never be:

```text
Attempt committed
+
idempotency claim missing/incomplete
```

for a successful protected Start.

---

# 20. Start Result and Replay

Create:

```text
backend/app/Support/Student/StudentHomeworkAttemptStartResult.php
```

It represents internally:

```text
success:
  attemptId
  httpStatus

deadline marker:
  internal only
```

The public `StartStudentHomeworkAttempt` method must throw the deadline exception after a committed deadline-marker transaction and otherwise return only successful result.

Do not expose `replayed` to the public API.

When replaying a completed idempotency record, use its original:

```text
response_status
```

and `result_resource_id`.

---

# 21. Own Attempt Read

Create:

```text
backend/app/Actions/Student/ShowStudentHomeworkAttempt.php
```

Flow:

1. resolve the own Homework Attempt through `StudentHomeworkAttemptAccess`;
2. invoke delivered BE-003 `ShowStudentHomework` using the authorized Attempt's `assessment_id`;
   - this reuses BE-003 deadline reconciliation;
   - this reuses the exact Student-safe Question eager-load/projection;
3. find the same Attempt ID inside the freshly loaded authenticated-Student Attempt collection;
4. require the fresh BE-003 projection/history validation to confirm the same
   Attempt still belongs to the exact Student/Homework/recipient graph and uses
   Homework-valid state;
5. if missing/inconsistent despite prior authorization, fail as server invariant error;
6. attach/set the freshly loaded Homework Assessment as the Attempt's loaded `assessment` relation;
7. return `AssessmentAttempt`.

Do not duplicate BE-003 Question answer-key filtering.

Do not use `TeacherQuestionResource`.

---

# 22. Attempt Resource

Create:

```text
backend/app/Http/Resources/Student/StudentHomeworkAttemptResource.php
```

Use delivered:

```text
StudentQuestionResource
```

for Questions.

Require the returned Attempt to have a fully loaded Student-safe Homework Assessment relation with:

```text
homeworkAssignment
questions
```

Return exactly:

```json
{
  "id": "attempt-uuid",
  "assessment_id": "homework-uuid",
  "attempt_number": 1,
  "status": "in_progress",
  "started_at": "2026-09-08T12:00:00Z",
  "submitted_at": null,
  "finalized_at": null,
  "finalization_reason": null,
  "deadline_at": "2026-09-10T13:00:00Z",
  "questions": [
    {
      "id": "question-uuid",
      "type": "single_choice",
      "prompt": "What does DNS do?",
      "instructions": null,
      "points": 1.0,
      "position": 1,
      "answer_ui": {
        "options": [
          {
            "id": "option-uuid",
            "text": "..."
          }
        ]
      }
    }
  ]
}
```

`deadline_at` comes from:

```text
homework_assignments.deadline_at
```

not `assessment_attempts.deadline_at`.

All timestamps:

```text
UTC RFC3339 ...Z
```

Do not expose:

```text
institution_id
student_id
assessment_student_id
locked_at
official_score_eligible
earned_points
possible_points
normalized_score
scoring_completed_at
checking data
correct-answer configuration
```

No saved Student answer payload yet in BE-004.

---

# 23. Controller

Create:

```text
backend/app/Http/Controllers/Api/V1/Student/StudentHomeworkAttemptController.php
```

Keep it thin.

## `store`

```text
validated request
-> authenticated Student
-> StartStudentHomeworkAttempt
-> ShowStudentHomeworkAttempt(result.attemptId)
-> StudentHomeworkAttemptResource
-> set response status to result.httpStatus
```

No message field is required.

## `show`

```text
validated request
-> authenticated Student
-> ShowStudentHomeworkAttempt
-> StudentHomeworkAttemptResource
```

Default status:

```text
200
```

No tenant/lifecycle/idempotency logic in Controller.

---

# 24. Error Classes and API Mapping

Create focused Student exceptions:

```text
backend/app/Exceptions/Student/StudentHomeworkNotActiveException.php
backend/app/Exceptions/Student/StudentHomeworkClosedException.php
backend/app/Exceptions/Student/StudentHomeworkArchivedException.php
backend/app/Exceptions/Student/StudentHomeworkDeadlinePassedException.php
backend/app/Exceptions/Student/StudentAssessmentNotAssignedException.php
backend/app/Exceptions/Student/AttemptsExhaustedException.php
backend/app/Exceptions/Student/IdempotencyKeyReusedException.php
backend/app/Exceptions/Student/StudentHomeworkConflictException.php
```

Each may be a focused `RuntimeException` with no sensitive payload.

Modify:

```text
backend/bootstrap/app.php
backend/app/Support/ApiErrorResponse.php
```

Map:

| Exception | HTTP | code |
|---|---:|---|
| `StudentHomeworkNotActiveException` | 409 | `task_not_active` |
| `StudentHomeworkClosedException` | 409 | `task_closed` |
| `StudentHomeworkArchivedException` | 409 | `task_archived` |
| `StudentHomeworkDeadlinePassedException` | 409 | `deadline_passed` |
| `StudentAssessmentNotAssignedException` | 409 | `assessment_not_assigned` |
| `AttemptsExhaustedException` | 409 | `attempts_exhausted` |
| `IdempotencyKeyReusedException` | 409 | `idempotency_key_reused` |
| `StudentHomeworkConflictException` | 409 | `business_conflict` |

Reuse existing generic response helpers for task/deadline/business codes.

Add new stable helpers/constants only where missing:

```text
attempts_exhausted
idempotency_key_reused
```

and a Student-specific human message for:

```text
assessment_not_assigned
```

without changing the existing Teacher activation message/behavior.

Suggested exact new messages:

```text
attempts_exhausted:
No Homework attempts remain.

idempotency_key_reused:
The Idempotency-Key has already been used for a different request.

Student assessment_not_assigned:
This Homework is no longer assigned to the current Student.
```

Do not expose internal lock/SQL/invariant details.

---

# 25. Error Precedence

After middleware and strict request validation:

## Preliminary access first

Malformed/foreign/unassigned/draft/non-Homework:

```text
404 resource_not_found
```

No idempotency lookup/write.

## Authorized target + existing completed key

Same fingerprint:

```text
replay prior logical success
```

This occurs before current lifecycle/deadline rules.

Different fingerprint:

```text
409 idempotency_key_reused
```

## New logical operation

Then locked current state decides:

```text
recipient disappeared => 409 assessment_not_assigned
Topic not active => 409 task_not_active
Homework draft => 409 task_not_active
Homework closed => 409 task_closed
Homework archived => 409 task_archived
deadline reached => 409 deadline_passed
official/persistence invariant conflict => 409 business_conflict
no in_progress + 3 attempts used => 409 attempts_exhausted
```

A successful current in-progress resume takes precedence over exhaustion.

---

# 26. Concurrency / Locking Contract

Correctness must not depend only on the BE-001 partial unique index.

## 26.1 Same Homework Start serialization

Parent lock includes:

```text
Topic
Assessment
Homework
```

so Start requests for one Homework serialize before attempt allocation.

## 26.2 Teacher fairness/lifecycle compatibility

For an official Homework, order continues:

```text
Topic
-> Assessment
-> Homework
-> result pair
-> Attempts
```

This is compatible with current Teacher paths that acquire their extra Group/current-membership locks **before** Topic and then proceed to Assessment/Homework/result-pair/Attempts.

Student must never acquire Group after Topic.

## 26.3 Same key, same request

Two concurrent POSTs:

```text
same Student
same Homework
same Idempotency-Key
```

must produce:

```text
one Attempt
one completed idempotency record
same Attempt ID
both semantic HTTP status = original 201
```

if the original operation created the Attempt.

## 26.4 Different keys, same Student/Homework

Two concurrent POSTs with different keys:

```text
first committed logical Start => 201 create
second => 200 resume same Attempt
```

Final DB:

```text
one in_progress Attempt
two completed idempotency records
both records reference same Attempt
response statuses 201 and 200 respectively
```

No Attempt #2 is consumed.

## 26.5 Same key, different Homework

Same actor/operation/key with a different authorized Homework target:

```text
409 idempotency_key_reused
```

Only the winning original logical request may mutate.

## 26.6 Start vs Teacher Question mutation

Existing Teacher Question mutation lock rules must remain valid:

- Teacher mutation commits first → Student Start sees final updated scoring definition and snapshots current `total_possible_points`;
- Student Start commits first → later Teacher fairness-relevant Question mutation fails through existing Attempt/activity lock behavior.

Both must never commit in an order that changes scoring content after Student activity starts.

## 26.7 Start vs Teacher close/deadline

BE-002 parent locks serialize lifecycle.

If close wins first:

```text
new Start => task_closed
```

If Start validly captures:

```text
startedAt < deadline/close transition
```

and commits first, later close/deadline may finalize that Attempt according to BE-002.

At:

```text
startedAt >= deadline
```

no Attempt is created; deadline reconciliation wins.

## 26.8 Required real-Start fairness race

The BE-004 concurrency proof must exercise the actual delivered:

```text
StartStudentHomeworkAttempt
```

against the actual Teacher Question mutation path.

Required outcomes:

```text
Teacher Question mutation commits first
=> Student Start succeeds
=> Attempt.possible_points snapshots the final locked Assessment total
=> final persisted Question/scoring definition is the one Start observed

Student Start commits first
=> later fairness-relevant Teacher Question mutation = business_conflict
=> no scoring/question definition changes after Student activity began
```

Both workers must use the repository PostgreSQL lock-wait harness. Do not satisfy
this requirement only with the older synthetic direct `AssessmentAttempt`
insertion helper.

## 26.9 Required real-Start Teacher-close race

Exercise actual:

```text
StartStudentHomeworkAttempt
vs
CloseTeacherHomework
```

Required outcomes:

```text
Start commits first before close
=> Start succeeds
=> close then succeeds and auto-finalizes that Attempt under BE-002

Teacher close commits first
=> Start returns task_closed
=> no new Attempt / no completed Start idempotency record
```

The losing worker must actually enter PostgreSQL lock wait in the controlled
race.

The BE-002 deadline-vs-close concurrency regression remains required; a separate
crossing-clock Start/deadline process race is not required in BE-004 because the
deadline boundary itself is already covered by BE-002 + BE-004 frozen-time tests.

---

# 27. No-Op / Timestamp Rules

Resume:

- no Attempt timestamp changes;
- no pair timestamp changes;
- only the new idempotency success record is written.

Completed idempotency replay:

- no Attempt writes;
- no pair writes;
- no idempotency timestamp rewrite.

Attempts exhausted/lifecycle/business failures:

- no Attempt/pair writes;
- no persisted idempotency claim.

Deadline failure:

- no new Attempt;
- no persisted idempotency claim;
- BE-002 deadline finalization may validly write existing due in-progress Attempts.

Pair already locked:

- preserve its original `locked_at`/`updated_at` during later Starts.

---

# 28. Expected Files

## Create

```text
backend/app/Support/Idempotency/IdempotencyRequestFingerprint.php
backend/app/Support/Idempotency/IdempotencyGuard.php
backend/app/Support/Idempotency/IdempotencyClaim.php

backend/app/Support/Student/StudentHomeworkAttemptAccess.php
backend/app/Support/Student/StudentHomeworkAttemptStartResult.php

backend/app/Actions/Student/StartStudentHomeworkAttempt.php
backend/app/Actions/Student/ShowStudentHomeworkAttempt.php

backend/app/Http/Requests/Student/StudentHomeworkAttemptStartRequest.php
backend/app/Http/Requests/Student/StudentHomeworkAttemptShowRequest.php

backend/app/Http/Controllers/Api/V1/Student/StudentHomeworkAttemptController.php
backend/app/Http/Resources/Student/StudentHomeworkAttemptResource.php

backend/app/Exceptions/Student/StudentHomeworkNotActiveException.php
backend/app/Exceptions/Student/StudentHomeworkClosedException.php
backend/app/Exceptions/Student/StudentHomeworkArchivedException.php
backend/app/Exceptions/Student/StudentHomeworkDeadlinePassedException.php
backend/app/Exceptions/Student/StudentAssessmentNotAssignedException.php
backend/app/Exceptions/Student/AttemptsExhaustedException.php
backend/app/Exceptions/Student/IdempotencyKeyReusedException.php
backend/app/Exceptions/Student/StudentHomeworkConflictException.php

backend/tests/Feature/Student/StudentHomeworkAttemptStartApiTest.php
backend/tests/Feature/Student/StudentHomeworkAttemptIdempotencyTest.php
backend/tests/Feature/Student/StudentHomeworkOfficialPairAttemptLockTest.php
backend/tests/Feature/Student/StudentHomeworkAttemptStartConcurrencyTest.php
```

## Modify

```text
backend/routes/api.php
backend/bootstrap/app.php
backend/app/Support/ApiErrorResponse.php
```

No migration, answer mutation, file storage, scoring, docs, frontend, seeder or E2E files.

If a tiny delivered BE-003 support signature needs a local compatibility adjustment to reuse the authorized Homework query, keep it minimal and report it; do not redesign BE-003.

---

# 29. `StudentHomeworkAttemptStartApiTest`

At minimum cover:

## Route/middleware

Exact POST + GET routes registered once under Student middleware.

Other role tokens cannot use them.

## Request validation

POST:

- missing key;
- malformed key;
- non-empty body;
- invalid JSON;
- query parameter;

→ `422 validation_failed`.

Allow:

```text
no body
{}
```

GET rejects body/query.

## Create Attempt #1

Assigned active Homework, future/null deadline.

Expect:

```text
201
status = in_progress
attempt_number = 1
```

Exact DB fields from Section 18.

Verify:

```text
deadline_at DB column = null
public deadline_at = Homework deadline
possible_points = locked Assessment total
no attempt_answers rows
no score fields
```

## Resume

Second independent Start with a **different** valid key while #1 is in progress:

```text
200
same Attempt ID
same attempt_number
same started_at
```

DB Attempt count remains 1.

## Next Attempts

After terminal fixture #1:

```text
new Start => #2
```

After terminal #1/#2:

```text
new Start => #3
```

After terminal #1/#2/#3:

```text
409 attempts_exhausted
```

No #4.

## Current #3 resume

If #3 is still `in_progress`:

```text
200 resume #3
```

not exhaustion.

## Existing Homework Attempt history integrity

Focused corrupted fixtures must fail as server invariants before
resume/exhaustion/new allocation:

```text
Attempt.assessment_student_id points to wrong Student/Assessment recipient
Homework Attempt.deadline_at != null
Homework Attempt.status = timed_out_finalized
Homework Attempt.finalization_reason = timeout_auto_submit
in_progress with submitted_at/finalized_at/locked_at/finalization_reason != null
attempt-number gap such as [2] or [1,3]
```

Verify no replacement/new Attempt, pair mutation, or completed Start
idempotency record is produced.

## Assignment snapshot

End current Group membership after Homework recipient snapshot.

Student can still Start/read own assigned Homework Attempt.

## Privacy

Malformed, foreign Institution, another Student/unassigned, draft Homework:

```text
404 resource_not_found
```

No idempotency row created.

## Lifecycle

New key:

```text
closed => task_closed
archived => task_archived
Topic non-active/inconsistent active Homework => task_not_active
```

## Deadline

At exact deadline and after deadline:

```text
409 deadline_passed
```

No new Attempt.

Existing due in-progress work is BE-002-finalized with exact deadline timestamp.

## GET own Attempt

Own active/historical Attempt returns exact resource.

Other Student/foreign Institution/direct UUID:

```text
404
```

No current Group membership requirement.

---

# 30. `StudentHomeworkAttemptIdempotencyTest`

At minimum:

## Create replay

First Start:

```text
201
```

Retry same key/target:

```text
201
same Attempt ID
```

Verify:

```text
1 Attempt
1 idempotency record
response_status = 201
result_resource_type = assessment_attempt
```

Replay does not change Attempt/pair/idempotency completion timestamps.

## Resume replay

Existing in-progress Attempt + new key:

```text
first = 200
retry same key = 200
```

one Attempt.

## Different target reuse

Same Student + same Start operation + same key + another authorized Homework:

```text
409 idempotency_key_reused
```

No mutation of second Homework.

## Actor scope

Same UUID key succeeds independently for another Student/Institution.

## Replay target integrity

After creating a completed Start idempotency record, deliberately corrupt its
`result_resource_id` in focused fixture setup to reference:

- a missing Attempt UUID;
- another Student's Attempt;
- another authorized Homework's Attempt.

For each case:

```text
server invariant failure
no replacement Attempt
no idempotency repair/rewrite
```

Also cover a referenced Attempt whose recipient graph is inconsistent.

## Replay after lifecycle change

Successful original Start, then Homework is closed/archived or deadline reconciliation occurs.

Same original key:

- returns same logical Attempt;
- preserves original Start response status;
- performs no new Start mutation.

Current Attempt resource may show current terminal state.

## Failure record absence

Verify no persisted idempotency row after:

```text
deadline_passed
attempts_exhausted
task_closed
task_archived
business_conflict
authorization/not-found
```

## Fingerprint

Verify stored fingerprint is the expected deterministic lowercase SHA-256 for the exact semantic identity.

---

# 31. `StudentHomeworkOfficialPairAttemptLockTest`

At minimum:

## First official Attempt

Official whole-group Homework pair:

```text
cohort_snapshotted_at != null
locked_at = null
no Attempts
```

Freeze clock.

Start Student Attempt.

Verify atomically:

```text
pair.locked_at = Attempt.started_at
pair.updated_at = Attempt.started_at
Attempt exists
```

and:

```text
blitz_assessment_id remains unchanged/null
homework_assessment_id unchanged
cohort_snapshotted_at unchanged
designated_at unchanged
```

## Subsequent Student

Another official-cohort Student starts after first.

Pair lock timestamp remains unchanged.

## Practice Homework

Start does not mutate Topic pair pointing to another Homework.

## Missing cohort

Official pair with:

```text
cohort_snapshotted_at = null
```

returns:

```text
409 business_conflict
```

No Attempt/pair lock.

## Wrong assignment semantics

Official pair + non-group Assessment or non-group recipient source:

```text
409 business_conflict
```

## Existing Attempt with null pair lock

Persist structural Attempt while official pair lock is null.

New Start:

```text
409 business_conflict
```

Do not silently repair.

## Locked pair without Attempt history

```text
409 business_conflict
```

No new Attempt.

## Transaction rollback

Force Attempt insertion failure after pair lock mutation in a focused test.

Verify pair lock update rolls back.

Do not weaken DB constraints to manufacture the failure.

---

# 32. `StudentHomeworkAttemptStartConcurrencyTest`

Use real PostgreSQL process concurrency and the repository's existing lock-wait pattern; no arbitrary sleep as synchronization.

At minimum prove:

## Same key race

Two workers, same Student/Homework/key.

Force first worker to retain the relevant parent lock while second starts and enters PostgreSQL lock wait.

Final:

```text
both logical responses = 201
same Attempt ID
1 Attempt
1 idempotency record
```

## Different-key race

Two workers, same Student/Homework, different keys.

Final:

```text
first = 201
second = 200
same Attempt ID
1 in_progress Attempt
2 completed idempotency records
```

The test must prove the second worker actually entered a PostgreSQL lock wait.

## Start vs Teacher Question mutation

Use actual `StartStudentHomeworkAttempt` and actual Teacher fairness-relevant
Question mutation.

Prove both lock orders:

```text
mutation first => Start succeeds against final definition/points
Start first => Teacher mutation = business_conflict
```

At least the blocked second worker in each controlled direction must be observed
in PostgreSQL lock wait.

## Start vs Teacher close

Use actual `StartStudentHomeworkAttempt` and `CloseTeacherHomework`.

Prove:

```text
Start first => close finalizes created Attempt
close first => Start = task_closed and creates no Attempt
```

The blocked second worker must be observed in PostgreSQL lock wait.

## Optional same-key/different-target race

Add only if it stays focused and deterministic.

Otherwise sequential idempotency coverage in Section 30 is sufficient.

---

# 33. Directly Affected Regression Tests

Run BE-004 tests plus:

```text
tests/Feature/Student/StudentHomeworkReadApiTest.php
tests/Feature/Student/StudentHomeworkQuestionPrivacyTest.php
tests/Feature/Student/StudentHomeworkDeadlineReadReconciliationTest.php

tests/Feature/Homework/HomeworkDeadlineFinalizationTest.php
tests/Feature/Homework/HomeworkDeadlineFinalizationConcurrencyTest.php

tests/Feature/Persistence/StudentAnswerSubmissionPersistenceTest.php

tests/Feature/Teacher/TeacherHomeworkConcurrencyTest.php
tests/Feature/Teacher/TeacherHomeworkLifecycleConcurrencyTest.php
tests/Feature/Teacher/TeacherQuestionMutationConcurrencyTest.php
tests/Feature/Teacher/TeacherTopicResultPairConcurrencyTest.php
```

Rationale:

- Student route/read surface extended;
- BE-002 deadline action reused;
- BE-001 Attempt/idempotency constraints exercised;
- first real public Attempt creation must preserve existing Teacher
  fairness/result-pair/lifecycle concurrency;
- the new concurrency test must exercise actual Start against Question mutation
  and Teacher close rather than rely only on older synthetic Attempt insertion.

Do not run full backend suite.

---

# 34. Verification

From `backend/`, use the repository's normal Docker/Sail command wrapper.

Run the exact backend format check:

```bash
./vendor/bin/pint --test
```

No additional broad static-analysis command is required unless current
repository configuration makes one mandatory for the changed files.

Then exactly:

```bash
php artisan test \
  tests/Feature/Student/StudentHomeworkAttemptStartApiTest.php \
  tests/Feature/Student/StudentHomeworkAttemptIdempotencyTest.php \
  tests/Feature/Student/StudentHomeworkOfficialPairAttemptLockTest.php \
  tests/Feature/Student/StudentHomeworkAttemptStartConcurrencyTest.php \
  tests/Feature/Student/StudentHomeworkReadApiTest.php \
  tests/Feature/Student/StudentHomeworkQuestionPrivacyTest.php \
  tests/Feature/Student/StudentHomeworkDeadlineReadReconciliationTest.php \
  tests/Feature/Homework/HomeworkDeadlineFinalizationTest.php \
  tests/Feature/Homework/HomeworkDeadlineFinalizationConcurrencyTest.php \
  tests/Feature/Persistence/StudentAnswerSubmissionPersistenceTest.php \
  tests/Feature/Teacher/TeacherHomeworkConcurrencyTest.php \
  tests/Feature/Teacher/TeacherHomeworkLifecycleConcurrencyTest.php \
  tests/Feature/Teacher/TeacherQuestionMutationConcurrencyTest.php \
  tests/Feature/Teacher/TeacherTopicResultPairConcurrencyTest.php
```

Then repository root:

```bash
git diff --check
```

and focused diff/scope self-review.

Do not run:

- full backend suite;
- frontend tests/build;
- broad E2E/integration Stage runner.

---

# 35. Acceptance Criteria

PASS only if all are true.

## Start/resume

- POST exists under exact Student middleware;
- key/body/query validation exact;
- create returns 201;
- existing in-progress returns 200 same Attempt;
- no parallel in-progress Attempt;
- exactly 3 normal Attempts;
- sequential allocation uses max+1;
- locked existing Homework history is validated before resume/exhaustion/allocation;
- Homework history rejects wrong recipient linkage, non-null Attempt deadline,
  Blitz-only status/reason, inconsistent `in_progress` terminal fields, and
  numbering gaps as server invariants;
- no Attempt #4.

## Deadline/lifecycle

- authoritative `startedAt` captured after lock waits;
- `startedAt >= deadline` blocks Start;
- deadline rejection commits BE-002 reconciliation without persisting Start idempotency claim;
- closed/archived/not-active behavior exact;
- no fabricated Attempt.

## Idempotency

- durable BE-001 DB records used;
- scope = Institution + User + operation + key;
- same key/same identity returns same logical Attempt and original HTTP status;
- different identity returns `idempotency_key_reused`;
- claim/domain success are one transaction;
- failed Start leaves no incomplete record;
- replay can survive later close/deadline state;
- completed replay target must exist and match the same
  Institution+Student+Homework+recipient graph;
- broken/foreign replay target is a server invariant failure and never triggers
  replacement Start;
- no cache-only correctness.

## Official pair

- first global official Attempt locks pair before Attempt insertion;
- pair lock instant exactly equals Attempt `started_at`;
- lock + Attempt are atomic;
- official cohort/IDs/designation not rewritten;
- subsequent Starts preserve lock;
- practice Homework does not touch pair;
- structural inconsistencies fail safely.

## Security

- persisted recipient snapshot is authority;
- current Group membership not required;
- direct unassigned/cross-tenant/other-Student IDs return privacy-safe 404;
- own Attempt GET validates Attempt + recipient + Assessment + Institution consistency.

## Response

- POST/GET use Student-safe Questions from BE-003;
- no Teacher answer keys;
- no saved-answer payload yet;
- no score/internal ownership fields.

## Concurrency

- real PostgreSQL same-key race yields one Attempt;
- different-key race yields create+resume on same Attempt;
- actual Start vs Teacher Question mutation is proven in both commit orders;
- actual Start vs Teacher close is proven in both commit orders;
- existing Teacher fairness/result-pair/lifecycle/deadline concurrency regressions pass.

## Scope

- no answer mutation/file upload/final Submit/scoring/Blitz/frontend/schema/docs/E2E;
- no new dependency;
- no unrelated refactor.

## Verification

- focused tests pass;
- named regressions pass;
- `./vendor/bin/pint --test` passes;
- `git diff --check` passes;
- focused self-review passes.

---

# 36. Locked Implementation Decisions

These are decisions, not suggestions:

```text
POST = create-or-resume
new Attempt => 201
existing in_progress => 200
normal Homework Attempts = exactly 3
next number = max + 1
Homework Attempt DB deadline_at = null
Homework deadline source = homework_assignments.deadline_at
deadline eligibility = startedAt < deadline
startedAt captured after required lock/idempotency waits
Start idempotency operation = student.homework.attempt.start
idempotency success resource type = assessment_attempt
same-key replay preserves original HTTP status
completed replay target = same authorized Student/Homework/recipient Attempt
Homework Attempt history is validated before resume/capacity/pair decisions
Homework Attempt deadline_at = null for all existing Homework history
Blitz-only timed_out_finalized/timeout_auto_submit = invalid Homework history
corrupted in_progress fields / numbering gaps = server invariant failure
first official Attempt locks pair before Attempt insert
pair.locked_at = Attempt.started_at
assessment_students snapshot = assignment/cohort authority
current Group membership = not required
```

Codex must not substitute:

- POST always creating a new Attempt;
- client-selected attempt number;
- configurable Homework attempt count;
- cache-only idempotency;
- idempotency after domain commit;
- replaying a missing/foreign/mismatched result_resource_id;
- treating corrupted/Blitz-only Attempt history as normal Homework capacity;
- backfilling an Attempt numbering gap;
- pair locking after Attempt insertion;
- current Group membership for persisted recipient scope;
- frontend/device deadline authority;
- Teacher Question resource reuse;
- scoring/checking during Start.

---

# 37. Completion Report

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
3. exact focused verification results;
4. idempotency evidence;
5. official-pair lock evidence;
6. PostgreSQL concurrency evidence;
7. directly affected regressions;
8. `git diff --check`;
9. scope/non-goal confirmation;
10. deviations/blockers;
11. final `git status --short`.

Do not claim `Accepted`.

Do not commit/push/create PR/update Stage bookkeeping unless explicitly instructed later.
