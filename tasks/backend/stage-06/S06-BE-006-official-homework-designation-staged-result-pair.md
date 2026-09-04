# Codex Implementation Contract: S06-BE-006 — Official Homework Designation and Staged Result-Pair Contract

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S06-BE-006` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Area | `Backend` |
| Status | `Accepted` |
| Delivery | `Delivered — PR #153` |
| Delivered merge | `c45e834784a303e74a41535a39293fbaefb6afc9` |
| Acceptance review | `PASS — P1=0, P2=0, P3=0` |
| Implementation type | `Laravel official Homework designation + staged Topic result-pair API` |
| Depends on | `S06-BE-001…005` — all `Accepted / Delivered` before implementation |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` after dependencies are delivered and immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |
| Backend block checkpoint | `Stage 6 Backend Phase 2` immediately after `S06-BE-001…006` are `Accepted / Delivered` |

Start only when all dependencies are `Accepted / Delivered`, this task remains `Approved`, ChatGPT has re-checked current `origin/main`, and Git preflight is safe.

This file is the complete task-specific implementation contract. Do not create a duplicate `CODEX-PROMPT` file.

---

# 2. Implementation Authority and Context Discipline

Codex may read only:

1. this implementation contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. delivered S06-BE-001…005 source/tests directly required by this task;
5. current Teacher Topic/Homework request/action/resource patterns directly required to implement this task.

Do not read roadmap, product specifications, architecture/database/API documents, Stage history, previous task files, Stage indexes, or closure reviews to decide requirements.

The contract below already resolves:

- Stage 6 partial result-pair semantics;
- exact GET/PUT API;
- whole-group official Homework eligibility;
- candidate lifecycle eligibility;
- same-Topic/Teacher/Institution scope;
- designation before activation;
- active-candidate cohort adoption;
- designated-draft activation integration;
- replacement before Student activity;
- immutable meaning after Student activity;
- defensive lock rules;
- interaction with Homework PATCH/archive/Questions;
- no-op timestamps;
- Stage 7 first-Attempt locking contract;
- Stage 8 nullable-Blitz completion exception;
- concurrency and error behavior.

If a delivered dependency materially conflicts with the required names/invariants below, return `BLOCKED` with exact evidence. Do not redesign the result-pair model or lifecycle independently.

---

# 3. Goal

Allow the Teacher to designate exactly one whole-group Homework as the Topic's official result-bearing Homework while preserving a single Topic-level result-pair row that can later be completed by Stage 8 with the official Blitz.

At the end of Stage 6:

- a Topic may have zero or one `topic_result_pairs` row;
- when a row exists, `homework_assessment_id` is required;
- `blitz_assessment_id` is still `null`;
- the designated Homework must be whole-group;
- selected-Student Homework remains practice-only;
- the official Homework may be designated while draft or while already active with no Student activity;
- once official Student activity begins, Homework designation/cohort meaning cannot be replaced;
- Stage 8 will fill the nullable Blitz slot in the **same row**, not create another pair.

---

# 4. Stage 6 Staged Result-Pair Rule

This task implements the approved Stage 6 sequencing specialization.

The Stage 6 authoritative shape is:

```text
topic_result_pairs.homework_assessment_id = NOT NULL
topic_result_pairs.blitz_assessment_id    = NULL
```

during normal Stage 6 operation.

Do not:

- require a Blitz to exist;
- create a fake/placeholder Blitz Assessment;
- create a temporary `official_homework` table;
- create a second result-pair row later;
- require the Teacher to supply a Blitz ID in Stage 6.

The persistence foundation from S06-BE-001 intentionally made:

```text
blitz_assessment_id nullable
```

for this reason.

This implementation contract supersedes any older planning/database/API text that required both official IDs before a pair row could exist.

---

# 5. Included Endpoints

Implement exactly:

```text
GET /api/v1/teacher/topics/{topic}/result-pair
PUT /api/v1/teacher/topics/{topic}/result-pair
```

Both live inside the existing Teacher middleware group:

```text
auth:sanctum
active.account
password.changed
role:teacher
```

No DELETE/clear endpoint is added in Stage 6.

---

# 6. Explicit Non-Goals

Do not implement:

- Blitz persistence/lifecycle;
- Blitz designation;
- non-null `blitz_assessment_id` mutation through the Stage 6 PUT;
- Student Homework attempt API;
- first-Attempt implementation;
- answer persistence/checking;
- official score resolution;
- final Topic result;
- Homework–Blitz comparison;
- result release;
- result-pair Student/Parent API;
- pair deletion/clearing;
- Topic result records;
- frontend;
- seed/E2E data;
- docs changes;
- dependencies;
- task/Stage bookkeeping;
- unrelated refactors.

Do not add:

```text
is_official
official_homework_id
result_bearing
```

as duplicated mutable columns on `assessments` or `homework_assignments`.

The authoritative official Homework relationship is:

```text
topic_result_pairs.homework_assessment_id
```

only.

---

# 7. Dependency Contract from S06-BE-001

Required delivered persistence/model:

```text
topic_result_pairs
App\Models\TopicResultPair
```

with at least:

```text
id
institution_id
topic_id
homework_assessment_id
blitz_assessment_id nullable
designated_by_user_id
designated_at
cohort_snapshotted_at nullable
locked_at nullable
created_at
updated_at
```

Required structural invariants include:

- one pair row per Topic;
- same-Institution/same-Topic Assessment FKs;
- Homework/Blitz IDs cannot be identical when Blitz is non-null;
- `locked_at` requires a cohort snapshot.

Also required:

```text
assessments
homework_assignments
assessment_students
assessment_attempts
```

---

# 8. Dependency Contract from S06-BE-003…005

Reuse the delivered:

```text
TeacherHomeworkAccess
TeacherHomeworkResource
```

and the established Teacher Topic/current-membership privacy boundary.

S06-BE-005 activation is the source of the active whole-group recipient snapshot.

S06-BE-004 already treats a non-null pair `locked_at` as a defensive Question-mutation lock.

Do not duplicate access logic.

---

# 9. Topic Authorization

For both endpoints, `{topic}` must resolve through the existing privacy-safe Teacher Topic scope.

Required:

- valid UUID;
- same Institution as authenticated Teacher;
- Topic owned by authenticated Teacher;
- current Teacher membership in Topic Group.

Malformed, foreign-Institution, another Teacher's, or no-longer-assigned Topic:

```text
404 resource_not_found
```

GET is allowed for Topic states:

```text
draft
active
closed
archived
```

PUT mutation is allowed only when Topic is:

```text
draft
active
```

For:

```text
closed
archived
```

PUT returns:

```text
409 topic_not_editable
```

---

# 10. GET Result Pair

## 10.1 Endpoint

```text
GET /api/v1/teacher/topics/{topic}/result-pair
```

No query parameters.

No request body.

Unknown query data:

```text
422 validation_failed
```

If the authorized Topic has no pair:

```json
{
  "data": null
}
```

with:

```text
200 OK
```

Do not return `404` for “no designation yet”.

## 10.2 Result-pair resource

When a row exists, return exactly:

```json
{
  "data": {
    "id": "pair-uuid",
    "topic_id": "topic-uuid",
    "homework_assessment_id": "homework-uuid",
    "blitz_assessment_id": null,
    "cohort_snapshotted_at": null,
    "locked_at": null,
    "designated_at": "2026-09-01T09:00:00Z",
    "created_at": "2026-09-01T09:00:00Z",
    "updated_at": "2026-09-01T09:00:00Z"
  }
}
```

`blitz_assessment_id` may be non-null only for forward-compatible/future Stage 8 data; GET must serialize the persisted value without failing.

All timestamps:

```text
UTC RFC3339 ...Z
```

Do not expose:

- `institution_id`;
- `designated_by_user_id`;
- recipient-row IDs;
- Student IDs;
- score/result data.

The Teacher already knows the official Homework ID and can load the Homework resource through existing APIs.

---

# 11. PUT Stage 6 Request Contract

## 11.1 Endpoint

```text
PUT /api/v1/teacher/topics/{topic}/result-pair
```

Request body must be an `application/json` object containing exactly:

```json
{
  "homework_assessment_id": "uuid"
}
```

Allowed top-level key only:

```text
homework_assessment_id
```

The field is required and must be a UUID string.

No query parameters.

Reject in Stage 6:

```text
blitz_assessment_id
institution_id
topic_id
designated_by_user_id
designated_at
cohort_snapshotted_at
locked_at
id
created_at
updated_at
```

Result:

```text
422 validation_failed
```

Stage 8 will explicitly extend this endpoint contract to accept/fill the Blitz side.

---

# 12. Official Homework Candidate Scope

Resolve `homework_assessment_id` only inside the already-authorized Topic and trusted Teacher scope.

The candidate must be:

```text
assessment.type = homework
assessment.institution_id = authenticated Teacher institution
assessment.teacher_id = authenticated Teacher
assessment.topic_id = authorized Topic
```

and have one paired `homework_assignments` row.

Malformed, foreign-Institution, another Teacher's, another Topic's, or non-Homework Assessment ID:

```text
404 resource_not_found
```

Do not reveal which condition failed.

---

# 13. Whole-Group Eligibility

Official Homework must have:

```text
assignment_mode = group
```

If the authorized candidate is:

```text
selected_students
```

return:

```text
409 official_task_requires_group_assignment
```

Selected-Student Homework remains practice-only.

Do not automatically convert assignment mode.

Do not discard selected recipients.

Teacher must choose/create a whole-group candidate instead.

---

# 14. Candidate Lifecycle Eligibility

A **new or replacement** official Homework candidate must be:

```text
draft
active
```

Candidate:

```text
closed
archived
```

cannot newly become official.

Return:

```text
409 business_conflict
```

Rationale: official meaning must be selected before completion/history is finalized, not retroactively after the task is closed.

Important idempotent exception:

If the pair already designates the same Homework ID, repeating the same PUT remains an idempotent success regardless of the Homework later being:

```text
active
closed
archived
```

or the pair later being locked.

Same-target PUT does not reinterpret/revalidate historical designation as a replacement.

---

# 15. Candidate Student-Activity Rule

A Homework that already has **any** `assessment_attempts` row cannot newly become the official Homework.

This includes all statuses.

Return:

```text
409 result_pair_locked
```

Do not designate a previously practice-used Homework as official after Student activity has begun.

This prevents retroactive changes to result meaning.

If the submitted Homework is already the currently designated official Homework, same-target PUT is still the idempotent exception and returns current pair without writes.

---

# 16. Pair Creation

When no result-pair row exists and the candidate passes all rules:

Capture one server instant:

```text
designatedAt = now()
```

Create exactly one row:

```text
institution_id = Teacher Institution
topic_id = authorized Topic
homework_assessment_id = candidate Assessment
blitz_assessment_id = null
designated_by_user_id = authenticated Teacher
designated_at = designatedAt
locked_at = null
```

`cohort_snapshotted_at` depends on candidate lifecycle as Sections 17–18 define.

Return:

```text
200 OK
```

not `201`, because PUT represents idempotent set/replace semantics for the Topic-level singleton relationship.

Message:

```text
Topic result pair updated successfully.
```

Return the result-pair resource.

---

# 17. Designating a Draft Whole-Group Homework

For:

```text
candidate Homework status = draft
```

the candidate must not yet have an active recipient snapshot.

The new/replaced pair stores:

```text
cohort_snapshotted_at = null
locked_at = null
```

No `assessment_students` rows are created by designation.

No Homework activation occurs implicitly.

No Question/recipient validation beyond official-candidate eligibility is repeated here; actual activation validation remains S06-BE-005.

The official cohort becomes defined only when this designated Homework successfully activates.

---

# 18. Designating an Already Active Whole-Group Homework

An already-active candidate may be designated only when:

- it has zero Attempts;
- it has a valid active Group recipient snapshot;
- recipient snapshot is non-empty;
- every recipient row has:
  `assignment_source = group`;
- rows belong to this Assessment/Institution;
- no duplicate/inconsistent recipient set exists.

If the active recipient snapshot is absent or structurally inconsistent:

```text
409 business_conflict
```

Do not silently resnapshot from current Group membership during designation.

The active Homework's persisted recipient snapshot is the fair historical set for that active task.

When designation succeeds, that exact persisted Student set becomes the official Topic cohort.

Set:

```text
cohort_snapshotted_at = designatedAt
```

This timestamp means:

> the existing active Homework recipient snapshot was adopted as the official Topic cohort at designation time.

Do not rewrite:

- `assessment_students`;
- their `assigned_at`;
- Homework `activated_at`;
- current Group membership.

---

# 19. Designated Draft Homework Activation Integration

S06-BE-006 must extend the delivered `ActivateTeacherHomework` flow narrowly.

When activating a Homework that is already referenced as:

```text
topic_result_pairs.homework_assessment_id
```

and the pair has:

```text
cohort_snapshotted_at = null
locked_at = null
blitz_assessment_id = null
```

the activation flow must:

1. perform all S06-BE-005 activation validation;
2. create the normal whole-group recipient snapshot;
3. use that exact persisted recipient set as the official Topic cohort;
4. set:

```text
topic_result_pairs.cohort_snapshotted_at = transitionedAt
topic_result_pairs.updated_at = transitionedAt
```

5. leave:
   - `homework_assessment_id` unchanged;
   - `blitz_assessment_id = null`;
   - `locked_at = null`;
   - `designated_at` unchanged;
   - `designated_by_user_id` unchanged.

The pair update and Homework activation/snapshot must be in the same transaction.

If the pair is already inconsistent/locked before draft activation:

```text
409 result_pair_locked
```

or:

```text
409 business_conflict
```

as appropriate; do not silently reset the pair.

---

# 20. Official Cohort Identity

After:

```text
cohort_snapshotted_at IS NOT NULL
```

the Stage 6 official Topic cohort is defined by the set:

```text
assessment_students.student_id
WHERE assessment_id = topic_result_pairs.homework_assessment_id
```

for the designated whole-group Homework.

This set is the authoritative cohort source for future Stages.

Current Group membership after the snapshot does **not** rewrite it.

No separate duplicate `topic_result_pair_students` table is introduced.

Stage 8 must reuse/copy this exact set for the official Blitz when the cohort is already defined.

---

# 21. Replace Official Homework Before Lock

A pair may be changed to a different Homework only while all replacement preconditions hold.

Required:

```text
pair.locked_at IS NULL
pair.blitz_assessment_id IS NULL
```

and:

- current designated Homework has no Assessment Attempts;
- new candidate has no Assessment Attempts;
- new candidate satisfies all eligibility rules.

If the current official Homework already has any Attempt, even if `locked_at` was not populated by a direct fixture/corrupt earlier implementation:

```text
409 result_pair_locked
```

Do not rely only on `locked_at`.

## 21.1 Replacement to draft candidate

On semantic replacement:

```text
homework_assessment_id = new candidate
blitz_assessment_id = null
designated_by_user_id = current Teacher
designated_at = replacedAt
cohort_snapshotted_at = null
locked_at = null
updated_at = replacedAt
```

The old active/pre-attempt official cohort is no longer official.

Do not rewrite/delete the old Homework's own historical recipient rows.

## 21.2 Replacement to active candidate

Validate/adopt the new candidate's exact active Group recipient snapshot.

Set:

```text
cohort_snapshotted_at = replacedAt
```

and update designation fields as above.

Again, do not resnapshot from current Group membership.

---

# 22. Locked Pair Replacement

If:

```text
pair.locked_at IS NOT NULL
```

and PUT requests a different Homework:

```text
409 result_pair_locked
```

No writes.

If current official Homework has any Attempt while `locked_at` is unexpectedly null:

```text
409 result_pair_locked
```

No writes.

If `blitz_assessment_id IS NOT NULL` and PUT requests a different Homework:

```text
409 result_pair_locked
```

Stage 6 must not independently rewrite one side of a completed future pair.

Same-target PUT remains a no-op success.

---

# 23. Same-Target PUT No-Op

If the submitted:

```text
homework_assessment_id
```

already equals the pair's current Homework ID:

Return:

```text
200 OK
```

with current resource and normal message.

Do not:

- update `designated_at`;
- update `designated_by_user_id`;
- update `cohort_snapshotted_at`;
- update `locked_at`;
- touch `updated_at`;
- rewrite recipient rows;
- revalidate candidate lifecycle/attempt eligibility as though it were replacement.

Authorization to Topic still must pass.

---

# 24. Interaction with Homework PATCH

S06-BE-006 must extend the delivered S06-BE-003 Homework PATCH integrity rules.

If a Homework is currently referenced as:

```text
topic_result_pairs.homework_assessment_id
```

then its official eligibility must remain whole-group.

A PATCH that would semantically change:

```text
assignment_mode: group -> selected_students
```

must return:

```text
409 official_task_requires_group_assignment
```

even if:

```text
pair.locked_at IS NULL
```

Do not automatically clear/replace the pair.

Same-value `assignment_mode = group` remains a no-op field.

Other pre-attempt Homework metadata rules from S06-BE-003 remain unchanged.

After any Attempt, the existing stricter editing-integrity lock still applies.

---

# 25. Interaction with Homework Archive

Extend S06-BE-005 archive only for the official-draft edge case.

## 25.1 Designated draft Homework

If Homework is:

```text
draft
```

and is the current designated official Homework, reject:

```text
409 business_conflict
```

The Teacher must first replace official designation with another eligible Homework.

There is no Stage 6 “clear pair” endpoint.

This prevents a pair from pointing to an official Homework that was archived without ever activating.

## 25.2 Designated closed Homework

A designated:

```text
closed -> archived
```

transition remains allowed.

The pair continues to reference the archived historical official Homework.

Do not delete/clear/replace the pair.

This preserves result history.

## 25.3 Non-designated Homework

Archive behavior remains exactly S06-BE-005.

---

# 26. Interaction with Question Mutation

No new behavior is required beyond the delivered S06-BE-004 rules:

- official but unlocked/pre-attempt Homework Questions remain editable;
- first Attempt locks scoring content through activity checks;
- `pair.locked_at` is a defensive lock when non-null.

Do not freeze Questions merely because Homework was designated official before Student activity.

This permits the Teacher to finish a designated draft before activation.

---

# 27. Stage 7 First Official Homework Attempt — Frozen Future Contract

S06-BE-006 does **not** implement Student Attempt start.

However Stage 7 must follow this exact integration rule before public Attempt start is enabled.

When starting the first Attempt for a Homework that is:

```text
topic_result_pairs.homework_assessment_id
```

Stage 7 must, in one transaction:

1. resolve authorized assigned Student;
2. lock Topic/Assessment/Homework using the Stage 7 Student-safe parent order;
3. lock the `topic_result_pairs` row;
4. require:

```text
cohort_snapshotted_at IS NOT NULL
```

5. require Student belongs to the persisted official Homework recipient set;
6. if:

```text
locked_at IS NULL
```

set:

```text
locked_at = attempt startedAt
updated_at = attempt startedAt
```

7. insert the first Attempt only after the official meaning/cohort is locked.

If already locked, subsequent valid official Homework Attempts reuse the same lock.

Stage 7 must not rewrite:

- official Homework ID;
- official cohort;
- designation time.

This ensures Homework official meaning becomes immutable at first Student activity.

---

# 28. Stage 8 Blitz Completion — Frozen Future Contract

This is the critical staged-pair exception.

Stage 8 may fill:

```text
blitz_assessment_id
```

when it is currently null.

That operation is **completion of the existing pair**, not replacement of the locked Homework side.

Therefore Stage 8 may fill the Blitz slot even when:

```text
pair.locked_at IS NOT NULL
```

provided every Stage 8 condition is satisfied.

Stage 8 must never interpret Stage 6 `result_pair_locked` as prohibiting the one-time null-to-valid Blitz completion.

## 28.1 When official cohort already exists

If:

```text
cohort_snapshotted_at IS NOT NULL
```

Stage 8 official Blitz must use exactly the same Student ID set as the official Homework recipient snapshot.

Stage 8 may create/synchronize the Blitz recipient snapshot from that **locked official cohort**, not from then-current Group membership.

If candidate Blitz already has an incompatible recipient snapshot:

```text
409 official_cohort_mismatch
```

## 28.2 When cohort is still null

If the pair exists but both official tasks are still pre-activation and:

```text
cohort_snapshotted_at IS NULL
```

Stage 8 may attach an eligible draft whole-group Blitz.

The first official task to activate must establish one common cohort and persist/reuse it for both official tasks.

Stage 8 owns that later two-task activation integration.

## 28.3 Never allowed

Stage 8 must not:

- replace `homework_assessment_id` after pair lock;
- alter the locked official cohort;
- create a second pair row;
- clear `locked_at`.

---

# 29. PUT Transaction and Lock Order

PUT executes in one database transaction.

Use the same parent lock hierarchy as prior Teacher Homework mutations:

1. Topic Group;
2. current Teacher–Group membership;
3. Topic;
4. candidate Assessment;
5. candidate HomeworkAssignment;
6. `topic_result_pairs` row for Topic when it exists;
7. current official Homework Assessment/Homework row if it differs from candidate and additional validation is needed;
8. candidate/current relevant Attempt rows/existence boundary;
9. candidate recipient rows when active.

Because the Topic is locked before pair creation/replacement, concurrent PUTs for the same Topic serialize even when no pair row exists yet.

Re-check after locks:

- Teacher authorization/current membership;
- Topic state;
- candidate scope/type/assignment/status;
- candidate Attempt existence;
- pair current IDs/lock;
- current official Attempt existence;
- active candidate recipient snapshot.

Do not authorize from pre-lock state.

---

# 30. Concurrency Rules

## 30.1 Two concurrent initial designations

Both lock the same Topic.

Exactly one candidate becomes current first.

The second then observes the created pair and applies ordinary replacement rules.

Final state:

- one pair row only;
- no uniqueness exception leaks as server error;
- deterministic valid pair.

## 30.2 Designation vs Homework activation

Both flows lock Topic before Assessment/pair work.

No invalid outcome where:

- a draft candidate activates using one official meaning while designation commits another without re-check.

If candidate is designated first, activation updates the same pair cohort atomically.

If activation occurs first, later designation adopts the already persisted active recipient snapshot.

## 30.3 Replacement vs first Attempt fixture/future Stage 7

Replacement must not commit after Student activity wins the serialization boundary.

If the current official or candidate Attempt appears before replacement's locked re-check:

```text
409 result_pair_locked
```

## 30.4 Replacement vs Question mutation

Both are pre-attempt operations and may serialize through Topic/Assessment locks.

Neither may bypass the activity lock.

---

# 31. `updated_at` Semantics

## 31.1 Initial create

Normal `created_at/updated_at` at `designatedAt`.

## 31.2 Semantic replacement

Update exactly:

```text
homework_assessment_id
designated_by_user_id
designated_at
cohort_snapshotted_at
updated_at
```

as required.

Preserve:

```text
id
topic_id
institution_id
created_at
blitz_assessment_id = null
locked_at = null
```

## 31.3 Designated draft activation

Update only pair:

```text
cohort_snapshotted_at
updated_at
```

alongside Homework activation.

## 31.4 Same-target PUT

No writes/timestamp churn.

## 31.5 GET

No writes.

---

# 32. Strict Input and Error Contract

## 32.1 GET

- no body;
- no query parameters.

Invalid query/body:

```text
422 validation_failed
```

## 32.2 PUT

- `Content-Type: application/json`;
- body must be JSON object;
- exact one allowed field:
  `homework_assessment_id`;
- no query parameters;
- reject unknown/protected keys;
- no scalar/array/null/malformed body.

Errors use existing envelopes.

| Case | Required result |
|---|---|
| Unauthenticated | `401 authentication_required` |
| Inactive account/Institution | existing middleware contract |
| Password change required | `403 password_change_required` |
| Wrong role | existing Teacher role middleware contract |
| Inaccessible Topic | `404 resource_not_found` |
| Foreign/other-topic/other-teacher/non-Homework candidate | `404 resource_not_found` |
| Invalid request shape | `422 validation_failed` |
| Topic closed/archived on PUT | `409 topic_not_editable` |
| Selected-Student candidate | `409 official_task_requires_group_assignment` |
| Candidate closed/archived for new/replacement designation | `409 business_conflict` |
| Candidate has Student activity | `409 result_pair_locked` |
| Current pair locked/activity exists and replacement requested | `409 result_pair_locked` |
| Pair already has non-null Blitz and replacement requested | `409 result_pair_locked` |
| Active candidate recipient snapshot invalid | `409 business_conflict` |
| Designated draft archive attempt | `409 business_conflict` |
| Unexpected failure | safe existing `500 server_error` |

Do not expose Student IDs, foreign record existence, SQL, or stack details in errors.

---

# 33. Result-Pair Resource / Action Placement

Expected focused application pieces:

```text
ShowTeacherTopicResultPair
SetTeacherTopicResultPair
TeacherTopicResultPairResource
TeacherTopicResultPairShowRequest
TeacherTopicResultPairUpdateRequest
TeacherTopicResultPairController
```

Equivalent concise naming is allowed.

A narrow support helper may be added, for example:

```text
TeacherTopicResultPairAccess
OfficialHomeworkDesignationValidator
```

only if it reduces duplicate privacy/locking rules.

Reuse current:

```text
TeacherHomeworkAccess
```

where appropriate.

Controllers remain thin.

Do not place designation workflow into Eloquent model methods.

Do not create a generic assessment-result service framework.

---

# 34. Required Integration Changes

This task may narrowly modify delivered code in three places.

## 34.1 `ActivateTeacherHomework`

Add the designated-draft cohort snapshot update from Section 19.

All ordinary non-designated activation behavior remains S06-BE-005.

## 34.2 `UpdateTeacherHomework`

Prevent an official Homework from changing:

```text
group -> selected_students
```

as Section 24 defines.

Do not otherwise widen/narrow S06-BE-003 metadata behavior.

## 34.3 `ArchiveTeacherHomework`

Prevent archiving a currently designated draft Homework.

Allow closed official Homework to archive historically.

No other lifecycle change.

---

# 35. Expected Files and Areas

| Area | Action |
|---|---|
| `backend/routes/api.php` | Add GET/PUT Topic result-pair routes |
| `backend/app/Actions/Teacher/ShowTeacherTopicResultPair.php` | Create |
| `backend/app/Actions/Teacher/SetTeacherTopicResultPair.php` | Create |
| `backend/app/Support/Teacher/TeacherTopicResultPairAccess.php` or equivalent | Create if useful |
| `backend/app/Domain/Assessment/OfficialHomeworkDesignationValidator.php` or equivalent | Optional focused validator |
| `backend/app/Http/Controllers/Api/V1/Teacher/TeacherTopicResultPairController.php` | Create |
| `backend/app/Http/Requests/Teacher/TeacherTopicResultPairShowRequest.php` | Create |
| `backend/app/Http/Requests/Teacher/TeacherTopicResultPairUpdateRequest.php` | Create |
| `backend/app/Http/Resources/Teacher/TeacherTopicResultPairResource.php` | Create |
| `backend/app/Actions/Teacher/ActivateTeacherHomework.php` | Modify narrowly for official cohort snapshot |
| `backend/app/Actions/Teacher/UpdateTeacherHomework.php` | Modify narrowly for official group invariant |
| `backend/app/Actions/Teacher/ArchiveTeacherHomework.php` | Modify narrowly for designated-draft guard |
| `backend/tests/Feature/Teacher/TeacherTopicResultPairApiTest.php` | Create |
| `backend/tests/Feature/Teacher/TeacherOfficialHomeworkIntegrityTest.php` | Create |
| `backend/tests/Feature/Teacher/TeacherTopicResultPairAuthorizationTest.php` | Create |
| `backend/tests/Feature/Teacher/TeacherTopicResultPairConcurrencyTest.php` | Create |
| existing Homework lifecycle/authoring/Question tests | Modify only when needed for new official integration assertions |

No migration should be required if S06-BE-001 was implemented according to its contract.

If a migration/schema change appears necessary, return `BLOCKED` and report the exact dependency mismatch rather than silently changing the approved persistence contract.

Do not modify frontend, docs, seeders, dependencies, task files, or unrelated code.

---

# 36. Acceptance Criteria

- [x] GET `/teacher/topics/{topic}/result-pair` returns `data:null` when no designation exists.
- [x] GET returns the exact Stage 6/future-compatible result-pair resource when present.
- [x] PUT accepts exactly one Stage 6 writable field: `homework_assessment_id`.
- [x] Stage 6 PUT does not require/accept `blitz_assessment_id`.
- [x] Candidate resolution is same-Topic/same-Institution/current-Teacher scoped and privacy-safe.
- [x] Selected-Student Homework cannot be official.
- [x] New/replacement candidate must be draft or active.
- [x] A Homework with any existing Attempt cannot newly become official.
- [x] Initial designation creates exactly one partial pair with null Blitz.
- [x] Draft candidate leaves official cohort unsnapshotted.
- [x] Active candidate adopts its existing persisted Group recipient snapshot without resnapshotting current membership.
- [x] Designated draft activation atomically sets `cohort_snapshotted_at`.
- [x] Official cohort identity is the designated Homework persisted recipient Student set.
- [x] Pair replacement is allowed only before lock/activity and while Blitz slot is null.
- [x] Replacement to draft clears cohort snapshot; replacement to active adopts candidate snapshot.
- [x] Pair replacement never deletes old Homework recipient/history rows.
- [x] Locked/activity-bearing pair replacement returns `result_pair_locked`.
- [x] Same-target PUT is idempotent even after later close/archive/lock, with zero timestamp churn.
- [x] Official Homework PATCH cannot change assignment mode to selected.
- [x] Designated draft Homework cannot archive until designation is replaced.
- [x] Designated closed Homework may archive historically and pair remains.
- [x] Question editing remains allowed pre-attempt according to S06-BE-004; designation alone does not freeze Questions.
- [x] No fake Blitz or second pair row exists.
- [x] Future Stage 7 first official Homework Attempt lock contract is encoded/testable without implementing the public Attempt API.
- [x] Future Stage 8 may fill nullable Blitz even after Homework-side pair lock; no code in this task structurally prevents that null-to-valid completion.
- [x] Concurrent initial/replacement designation remains one-row consistent.
- [x] Designation/activation concurrency preserves one authoritative cohort.
- [x] No scoring/result/Blitz/frontend/docs/seed/dependency work enters scope.
- [x] Focused tests pass.
- [x] Pint passes.
- [x] `git diff --check` passes.
- [x] Final focused diff review finds no blocking tenant/security/history/concurrency/staged-pair issue.

## 36.1 Delivery Evidence

- Delivery: PR #153, merge `c45e834784a303e74a41535a39293fbaefb6afc9`.
- Independent review: PASS — P1=0, P2=0, P3=0.
- Focused verification: 79 tests / 957 assertions.
- Pint: 466 files PASS.
- `git diff --check`: PASS.
- Delivery scope: exactly 22 backend files.
- Post-delivery Git state: local `main == origin/main`, ahead/behind `0/0`, worktree clean.

---

# 37. Focused Tests and Verification

Run from:

```text
backend/
```

Do not run the full backend suite. The full suite is mandatory at the immediately following Stage 6 Backend Phase 2 checkpoint.

## 37.1 Result-pair API tests

```bash
php artisan test \
  tests/Feature/Teacher/TeacherTopicResultPairApiTest.php \
  tests/Feature/Teacher/TeacherOfficialHomeworkIntegrityTest.php \
  tests/Feature/Teacher/TeacherTopicResultPairAuthorizationTest.php
```

Required coverage:

### GET

- authorized Topic with no pair -> `data:null`;
- draft partial pair;
- active/cohort-snapshotted pair;
- locked pair;
- forward-compatible fixture with non-null Blitz serializes;
- inaccessible Topic 404;
- no query/body accepted.

### Initial PUT

- designate draft group Homework;
- designate active group Homework;
- partial pair has null Blitz;
- no fake Blitz created;
- active candidate uses existing recipient set;
- active candidate with missing/invalid snapshot -> conflict;
- selected candidate -> `official_task_requires_group_assignment`;
- foreign candidate 404;
- another Topic candidate 404;
- another Teacher candidate 404;
- non-Homework candidate 404;
- candidate closed/archived -> conflict;
- candidate with any Attempt -> `result_pair_locked`;
- strict JSON/unknown/protected/query rejection.

### Replacement

- unlocked draft -> different draft;
- unlocked draft -> active;
- unlocked active/no-attempt -> draft;
- replacement updates designation timestamps/actor;
- old recipient rows preserved;
- locked pair -> `result_pair_locked`;
- current official has seeded Attempt but pair lock null -> `result_pair_locked`;
- new candidate has Attempt -> `result_pair_locked`;
- future fixture with non-null Blitz -> replacement blocked;
- same-target on locked pair succeeds no-op;
- same-target after official Homework close/archive succeeds no-op;
- no-op timestamps unchanged.

### Cohort

- designated draft activation sets pair cohort timestamp;
- activation cohort Student set equals Homework snapshot;
- membership changes after active snapshot are not silently incorporated by later designation;
- active designation does not rewrite recipient IDs/assigned_at;
- replacing active candidate changes official cohort only before lock.

### Integrity extensions

- designated draft `group -> selected_students` PATCH rejected;
- selected mode cannot become official through PATCH tricks;
- designated draft archive rejected;
- non-designated draft archive remains normal;
- designated closed archive succeeds and pair remains;
- pre-attempt official Question mutation remains allowed;
- pair locked/Attempt activity preserves existing Question lock behavior.

## 37.2 Concurrency tests

```bash
php artisan test tests/Feature/Teacher/TeacherTopicResultPairConcurrencyTest.php
```

Required races:

- two concurrent initial designations -> exactly one pair row, valid final candidate;
- two concurrent replacements -> one valid serialized final state;
- designation versus candidate activation -> valid cohort, no duplicate/resnapshot corruption;
- replacement versus seeded/future first-Attempt transaction -> replacement cannot commit after activity wins;
- designated-draft activation versus replacement -> final pair/cohort refer to the same authoritative candidate.

Use existing PostgreSQL concurrency-test conventions.

Do not implement a public Stage 7 Attempt endpoint.

A focused fixture transaction may model the frozen future first-Attempt critical section:

```text
lock Assessment
lock pair
set locked_at if official
insert structural Attempt
```

only for race verification.

## 37.3 Directly affected S06-BE-003/004/005 regression

Run focused Homework authoring/lifecycle/Question integrity tests affected by integration changes:

```bash
php artisan test \
  tests/Feature/Teacher/TeacherHomeworkAuthoringApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkRecipientApiTest.php \
  tests/Feature/Teacher/TeacherQuestionEditingIntegrityTest.php \
  tests/Feature/Teacher/TeacherHomeworkLifecycleApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkActivationRecipientTest.php
```

If exact delivered filenames differ while preserving those responsibilities, use the actual focused equivalents.

Do not run the full backend suite in Codex task verification.

## 37.4 S06-BE-001 structural regression

Because this task relies on staged nullable-Blitz persistence and same-Topic FKs, run:

```bash
php artisan test tests/Feature/Persistence/AssessmentHomeworkPersistenceTest.php
```

Add schema inspection test only if production schema/model was touched unexpectedly:

```bash
php artisan test tests/Feature/Persistence/AssessmentHomeworkSchemaInspectionTest.php
```

A required schema modification indicates a dependency mismatch and should normally be reported `BLOCKED` rather than patched here.

## 37.5 Format

```bash
./vendor/bin/pint --test
```

## 37.6 Always

```bash
git diff --check
```

Then focused diff self-check:

- only result-pair API + narrow Homework integration changed;
- no migration rewrite;
- no fake Blitz;
- no second result-pair structure;
- no Student Attempt public API;
- no score/result computation;
- no assignment-mode escape for official Homework;
- no pair deletion/clear endpoint;
- no cross-Tenant/global Assessment lookup;
- no lock weakening;
- no tests weakened;
- no debug/secrets/temp artifacts/unrelated formatting churn.

If implementation necessarily touches shared infrastructure beyond this verification contract, report the exact regression risk instead of silently running broad verification.

---

# 38. Project Owner Manual Check

```text
Not required at task level — result-pair API/integrity is covered by focused automated verification.
Real-stack official Homework designation smoke belongs to S06-INT-001.
```

---

# 39. Delivery

Follow root `AGENTS.md` and `tasks/README.md`.

Delivery execution:

```text
Project Owner
```

Suggested:

```text
Branch: feat/s06-be-006-official-homework-pair
Commit: feat(stage6): add official homework designation
PR base: main
```

Codex must not:

- commit;
- push;
- open/merge a PR;
- modify this task file;
- update Stage/task bookkeeping.

Codex stops after implementation, focused verification, `git diff --check`, and focused scope/diff self-review.

Task acceptance occurs only after approved delivery is present on `origin/main`, local `main == origin/main`, ahead/behind `0/0`, and worktree clean.

After S06-BE-006 is accepted/delivered, the next permitted implementation gate is:

```text
Stage 6 Backend Phase 2 Read-Only Review + full backend regression suite
```

Do not start frontend implementation before that checkpoint passes.

---

# 40. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to rediscover requirements.

| Source/reference | Decision already encoded above |
|---|---|
| Approved Stage 6 decomposition | BE-006 owns official Homework designation and staged result-pair API |
| Official Homework business rule | Exactly one whole-group official Homework; selected-Student Homework practice-only |
| Topic/result architecture | One Topic-level official Homework + Blitz pair with common official cohort |
| Existing locked database document | Originally assumed both pair IDs non-null |
| Approved Stage 6 sequencing correction | Homework is implemented before Blitz; `blitz_assessment_id` stays nullable until Stage 8 |
| Approved Stage 6 sequencing correction | Stage 8 fills the same row; no fake Blitz or temporary designation table |
| Approved locking rule | Homework side/cohort locks at first official Homework Attempt |
| Approved Stage 8 exception | Null-to-valid Blitz completion is allowed even after Homework-side lock; it is completion, not replacement |
| S06-BE-001 | staged pair persistence and same-Topic composite FKs |
| S06-BE-003 | Teacher Homework access/editing |
| S06-BE-004 | scoring-content lock |
| S06-BE-005 | activation recipient snapshot and Homework lifecycle |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |

---

# 41. Codex Final Report

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
7. **Official eligibility/cohort** — evidence.
8. **Replacement/lock/idempotency** — evidence.
9. **Stage 7/8 future compatibility** — confirm no fake Blitz and no structural block to later Blitz-slot completion.
10. **Concurrency** — evidence.
11. **Scope/diff** — non-goals + `git diff --check`.
12. **Delivery handoff** — Project Owner + current Git state.
13. **Deviations/blockers** — exact facts.

Do not output task `Accepted`.

Do not repeat the contract or paste large successful logs.

If a required product, API, database, tenant, security, cohort, lifecycle, lock, or staged-pair decision appears missing or conflicts with delivered dependencies/current source, return `BLOCKED` rather than deciding independently.
