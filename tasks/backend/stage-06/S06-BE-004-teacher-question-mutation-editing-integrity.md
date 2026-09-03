# Codex Implementation Contract: S06-BE-004 — Teacher Question Mutation and Editing Integrity

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S06-BE-004` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Area | `Backend` |
| Status | `Accepted` |
| Delivery | `Delivered — PR #149` |
| Delivered merge | `1f366e8b4b98f1f40a115ca02c64bb7709901156` |
| Acceptance review | `PASS — P1=0, P2=0, P3=0` |
| Implementation type | `Laravel Teacher Question mutation API + transactional editing-integrity enforcement` |
| Depends on | `S06-BE-001`, `S06-BE-002`, `S06-BE-003` — all `Accepted / Delivered` before implementation |
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
4. delivered S06-BE-001/S06-BE-002/S06-BE-003 source and focused tests directly required by this task;
5. current Teacher route/request/action/resource patterns directly required for implementation.

Do not read product specifications, roadmap files, architecture/database/API documents, Stage history, previous task files, Stage indexes, or closure reviews to determine requirements.

This contract already resolves:

- exact Question mutation endpoints;
- Stage 6 Homework-only authorization behind the shared Assessment URL;
- add/update/delete/reorder semantics;
- typed configuration replacement;
- matching-key behavior;
- Question positions;
- active/draft editability;
- lock after Student activity;
- defensive official-pair lock;
- exact total-point recalculation;
- no-op timestamps;
- concurrency serialization;
- strict request bodies;
- response behavior;
- errors and focused verification.

If a delivered dependency materially conflicts with the names or invariants below, return `BLOCKED` with exact evidence. Do not redesign dependencies independently.

---

# 3. Goal

Allow an authorized Teacher to maintain the typed Question set of an editable Homework while preserving scoring meaning, tenant isolation, deterministic ordering, exact total points, and historical integrity.

The Teacher must be able to:

1. add a Question at a requested position;
2. update a Question and/or replace its full typed configuration;
3. delete a Question before Student activity;
4. reorder the complete Question set;
5. receive the complete authoritative Homework resource after every successful mutation.

Once Student activity begins, Question content becomes immutable.

---

# 4. Included Endpoints

Implement exactly:

```text
POST   /api/v1/teacher/assessments/{assessment}/questions
PATCH  /api/v1/teacher/questions/{question}
DELETE /api/v1/teacher/questions/{question}
POST   /api/v1/teacher/assessments/{assessment}/questions/reorder
```

All routes live inside the existing Teacher middleware group:

```text
auth:sanctum
active.account
password.changed
role:teacher
```

The URL is intentionally Assessment-oriented for future Homework/Blitz reuse.

For **Stage 6**, mutation access is intentionally limited to:

```text
assessment.type = homework
```

A non-Homework Assessment is privacy-safely unavailable and returns:

```text
404 resource_not_found
```

Future Blitz implementation may extend the shared access boundary after Blitz lifecycle persistence exists. Do not implement speculative Blitz mutation behavior now.

---

# 5. Explicit Non-Goals

Do not implement or change:

- Homework create/list/detail/PATCH behavior except narrowly required reuse/fixes;
- Homework activate/close/archive;
- recipient selection;
- official Homework designation mutation;
- result-pair API;
- Student Homework API;
- Attempt start/save/submit;
- Attempt answers;
- checking/scoring;
- official-score resolution;
- deadline runtime;
- close/deadline auto-finalization;
- file submission;
- Blitz;
- result calculation/release;
- frontend;
- seed/E2E data;
- docs;
- dependencies;
- task/Stage bookkeeping;
- unrelated refactors.

Do not add:

- soft delete for Questions;
- Question revision/version tables;
- audit/event-sourcing framework;
- client-controlled `total_possible_points`;
- client-controlled Question child-row IDs;
- generic JSON Question configuration;
- per-question timer;
- negative marking;
- fuzzy/AI checking.

---

# 6. Dependency Contract

## 6.1 S06-BE-001

Required delivered persistence/models include:

```text
assessments
homework_assignments
assessment_attempts
topic_result_pairs

App\Models\Assessment
App\Models\HomeworkAssignment
App\Models\AssessmentAttempt
App\Models\TopicResultPair
```

Homework public ID is the shared Assessment UUID.

## 6.2 S06-BE-002

Required delivered Question layer includes:

```text
questions
question_choice_options
question_true_false_answers
question_short_accepted_answers
question_matching_items
question_ordering_items
question_fill_blanks
question_fill_blank_accepted_answers
```

and:

```text
QuestionAuthoringLimits
QuestionPositionSetValidator
QuestionConfigurationValidator
```

with all nine approved Question types.

## 6.3 S06-BE-003

Required delivered application/support behavior includes:

```text
TeacherHomeworkAccess
TeacherHomeworkResource
TeacherQuestionResource
QuestionConfigurationWriter
AssessmentPointMath
```

or exact equivalent names with the same responsibility.

S06-BE-004 must reuse/refine those abstractions rather than create duplicate Question validation, serialization, or point arithmetic.

---

# 7. Editing Integrity — Authoritative Rule

A Homework Question set is scoring/fairness-relevant content.

Question mutation is allowed only while all of the following are true:

- Teacher still has authorized access to the Homework/Topic/Group;
- owning Topic is not `closed` or `archived`;
- Homework status is `draft` or `active`;
- there is no `assessment_attempts` row for this Assessment;
- the Homework is not protected by a locked official result-pair row.

The first persisted Attempt locks:

- Question prompts;
- Question instructions;
- Question type;
- checking mode;
- correct-answer configuration;
- options/items/blanks;
- Question points;
- Question count;
- Question order.

No hard delete, replacement, reorder, or scoring-content edit is allowed after activity begins.

This applies regardless of Attempt status.

Even an `in_progress` Attempt is sufficient to lock Question content.

---

# 8. Defensive Official-Pair Lock

If a `topic_result_pairs` row exists where:

```text
homework_assessment_id = this Homework
locked_at IS NOT NULL
```

Question mutation is blocked even if a corrupted/test fixture has no visible Attempt row.

Return:

```text
409 result_pair_locked
```

This is a defensive historical-integrity rule.

Normally the pair becomes locked because Student activity has already begun, so the ordinary Attempt lock is expected to trigger first.

When both are true, prefer the more specific:

```text
409 result_pair_locked
```

after privacy-safe access resolution.

Do not mutate/unlock the pair in this task.

---

# 9. Homework / Topic Lifecycle Mutation Rules

## 9.1 Topic

If owning Topic is:

```text
closed
archived
```

return:

```text
409 topic_not_editable
```

Question readback through existing Homework detail remains unchanged.

## 9.2 Homework

If Homework is:

```text
draft
active
```

Question mutation may proceed subject to activity/pair locks.

If Homework is:

```text
closed
```

return:

```text
409 task_closed
```

If Homework is:

```text
archived
```

return:

```text
409 task_archived
```

There is no reopen behavior.

---

# 10. Privacy-Safe Access

## 10.1 Assessment endpoints

For:

```text
POST /teacher/assessments/{assessment}/questions
POST /teacher/assessments/{assessment}/questions/reorder
```

`{assessment}` must be a UUID and must resolve only through the delivered Teacher Homework authorization boundary:

- same Institution as authenticated Teacher;
- Assessment owned by authenticated Teacher;
- `type = homework`;
- owning Topic owned/visible to Teacher;
- current Teacher membership in Topic Group.

Malformed, foreign-Tenant, another Teacher's, inaccessible, or non-Homework Assessment:

```text
404 resource_not_found
```

## 10.2 Question endpoints

For:

```text
PATCH /teacher/questions/{question}
DELETE /teacher/questions/{question}
```

Do not resolve Question globally and authorize afterward.

Resolve Question through a tenant/Teacher-scoped Assessment/Topic query so a direct UUID cannot reveal private existence.

Malformed, foreign-Tenant, another Teacher's, or Question belonging to non-Homework/inaccessible Assessment:

```text
404 resource_not_found
```

---

# 11. Add Question

## 11.1 Endpoint

```text
POST /api/v1/teacher/assessments/{assessment}/questions
```

## 11.2 Strict request object

Body must be an `application/json` object.

Allowed keys exactly:

```text
type
prompt
instructions
points
position
checking_mode
configuration
```

No query parameters.

No `client_key` at Question top level for this dedicated endpoint.

Matching configuration may still contain per-pair request correlation `client_key` values as defined by S06-BE-002.

Unknown/protected key ->:

```text
422 validation_failed
```

## 11.3 Field contract

Use the same exact common Question rules delivered by S06-BE-002/S06-BE-003:

```text
type
prompt
instructions
points
checking_mode
configuration
```

Requirements:

- `prompt` trimmed, non-empty, max approved length;
- `instructions` nullable, non-blank if present, max approved length;
- `points` JSON number, not numeric string;
- finite;
- `0 <= points <= 999999.999999`;
- max 6 fractional digits;
- `type/checking_mode/configuration` validated through the shared `QuestionConfigurationValidator`.

## 11.4 Add position

`position` is required JSON integer.

Let current Question count be:

```text
N
```

Allowed add position:

```text
1 .. N + 1
```

If current count equals:

```text
QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT
```

reject add:

```text
422 validation_failed
```

No Question count above the approved maximum may be persisted.

## 11.5 Position insertion semantics

If adding at:

```text
N + 1
```

append.

If adding within:

```text
1 .. N
```

shift existing Questions at that position and after by `+1`.

Final persisted positions must be exactly:

```text
1..N+1
```

No duplicate/gap may remain.

Use the common position writer defined later; do not perform unsafe row-by-row updates against the unique `(assessment_id, position)` constraint.

## 11.6 Typed configuration

Reuse the delivered `QuestionConfigurationWriter`.

For Matching:

- request pair `client_key` is correlation-only;
- generate one fresh server UUID `match_key` per semantic pair;
- persist exactly one left + one right row using that key.

Do not persist request pair keys as authorization identifiers.

## 11.7 Points

After Question + typed configuration + final positions are persisted, recalculate the Assessment total from all locked current Questions with `AssessmentPointMath`.

Do not increment/decrement a stored total using floating arithmetic.

Persist exact recalculated scale-6 total.

---

# 12. Update Question

## 12.1 Endpoint

```text
PATCH /api/v1/teacher/questions/{question}
```

## 12.2 Allowed keys

Exactly:

```text
type
prompt
instructions
points
checking_mode
configuration
```

The dedicated PATCH does **not** accept:

```text
position
assessment_id
institution_id
question_id
created_at
updated_at
```

Question position changes only through the reorder endpoint.

No query parameters.

Body must contain at least one allowed key.

## 12.3 Partial common fields

For:

```text
prompt
instructions
points
```

PATCH is ordinary partial update.

Validate the resulting values with the same limits/rules as create.

## 12.4 Type/checking/configuration replacement rule

Typed configuration is a full aggregate, not a merge-patch.

If either:

```text
type
checking_mode
```

changes semantically, then:

```text
configuration
```

is required in the same PATCH.

If neither type nor checking mode changes, `configuration` may be omitted.

If `configuration` is present, it must be the complete canonical configuration for the **resulting** Question type/checking mode.

Never partially merge nested configuration.

Examples:

Allowed:

```json
{
  "points": 2
}
```

Allowed:

```json
{
  "configuration": {
    "correct_value": false
  }
}
```

Allowed:

```json
{
  "type": "open_written",
  "checking_mode": "manual",
  "configuration": {}
}
```

Rejected:

```json
{
  "type": "open_written"
}
```

because resulting configuration/checking semantics are unresolved.

## 12.5 Configuration replacement persistence

On a semantic typed-configuration change, atomically:

1. validate complete resulting configuration before destructive writes;
2. delete existing type-specific child rows in FK-safe child-to-parent order;
3. persist exactly the new normalized configuration through `QuestionConfigurationWriter`;
4. update common Question type/checking fields;
5. verify/reload canonical representation.

No old configuration row may survive a type/mode change.

No typed rows belonging to another Question type may remain.

Because mutation is prohibited after Student activity, hard deletion of editable draft/pre-attempt typed configuration is allowed.

## 12.6 Matching PATCH semantic comparison

Matching `client_key` values are not content meaning.

For no-op semantic comparison, compare:

- ordered `left` text;
- ordered `right` text;
- pair count/order;

and ignore request `client_key` values.

If the submitted Matching configuration has the same semantic pair content/order as persisted state, it is a no-op even if correlation keys differ.

If semantic Matching configuration changes, the writer may replace its typed rows and generate fresh server `match_key` UUIDs.

---

# 13. Delete Question

## 13.1 Endpoint

```text
DELETE /api/v1/teacher/questions/{question}
```

No request body.

No query parameters.

A body/query parameter is invalid:

```text
422 validation_failed
```

## 13.2 Editable pre-activity delete

For an editable draft/pre-attempt Homework:

1. remove typed configuration rows in FK-safe order;
2. hard-delete the Question row;
3. compact all remaining Question positions to exact `1..N`;
4. recalculate and persist exact `total_possible_points`.

No soft-delete row is introduced.

## 13.3 Draft result

A draft Homework may become:

```text
0 Questions
total_possible_points = 0
```

This is valid.

## 13.4 Active result validity

An active Homework must remain activation-valid after the mutation.

After a proposed active add/update/delete, require:

```text
question_count >= 1
total_possible_points > 0
```

If an active delete/update would leave:

```text
0 Questions
```

or:

```text
total_possible_points <= 0
```

reject the complete mutation:

```text
409 assessment_has_no_scoreable_points
```

No partial deletion/configuration/point change may commit.

An individual active Question may have zero points as long as the whole active Homework remains positive.

---

# 14. Reorder Questions

## 14.1 Endpoint

```text
POST /api/v1/teacher/assessments/{assessment}/questions/reorder
```

## 14.2 Strict body

Body exactly:

```json
{
  "question_ids": [
    "uuid-1",
    "uuid-2",
    "uuid-3"
  ]
}
```

Allowed top-level key only:

```text
question_ids
```

No query parameters.

`question_ids`:

- required JSON array;
- every item UUID string;
- no duplicates;
- count must equal current Question count;
- maximum approved Question count.

## 14.3 Exact-set rule

The submitted set must equal the complete current Question ID set of this Assessment.

Reject:

- missing ID;
- foreign Question;
- another Assessment's Question;
- duplicate;
- extra UUID;
- stale deleted UUID;
- incomplete subset.

Because the parent Assessment is already authorized, set mismatch is request validation/business invalidity:

```text
422 validation_failed
```

Do not disclose which supplied UUID belongs elsewhere.

## 14.4 Final order

Array order is authoritative.

Persist:

```text
question_ids[0] -> position 1
question_ids[1] -> position 2
...
```

No Question content/config/points changes.

`total_possible_points` remains mathematically unchanged and need not be recomputed solely for reorder, but the stored total must be left unchanged.

---

# 15. Safe Position Writer

Create/reuse one narrow internal helper, for example:

```text
App\Support\Assessment\QuestionPositionWriter
```

Responsibilities:

- operate only on already-authorized/locked Questions of one Assessment;
- perform insertion shifts;
- compact after delete;
- write complete reorder;
- avoid transient unique-position collisions;
- finish with exact contiguous `1..N`.

Allowed implementation strategy:

- move affected/current positions temporarily into a safe non-overlapping range;
- then assign final `1..N`.

The temporary range must be derived so it cannot collide with current/final positions and remains inside PostgreSQL integer bounds.

Do not drop/disable the unique database constraint.

Do not use unordered row-by-row updates that can fail depending on execution order.

Do not embed authorization or lifecycle logic in this helper.

---

# 16. Transaction and Lock Order

Every Question mutation must run in one database transaction.

Use a stable parent-to-child lock order compatible with S06-BE-003:

1. Topic Group;
2. current Teacher–Group membership;
3. Topic;
4. Assessment;
5. HomeworkAssignment;
6. locked `topic_result_pairs` row for this Homework when present;
7. existing Assessment Attempt rows/existence boundary;
8. all current Questions for this Assessment in deterministic order;
9. typed configuration rows needed by the specific mutation.

Re-check:

- Teacher access;
- Topic state;
- Homework state;
- pair lock;
- Attempt existence;

after locks, before writes.

Question-scoring mutation and future first-Attempt creation must serialize on the same Assessment row.

This task therefore establishes a forward implementation contract:

> Stage 7 Attempt-start must lock the Assessment row before inserting the first Attempt.

Do not implement Stage 7 now.

---

# 17. Activity Lock and Concurrency

After the Assessment row is locked, check whether any:

```text
assessment_attempts
```

exists for this Assessment.

If yes:

```text
409 business_conflict
```

and no Question/typed/position/total timestamp changes.

Required race safety:

### Question mutation vs first Attempt

Only one may cross the scoring-content boundary first.

If Question mutation locks Assessment first:

- it may commit;
- a later Attempt sees the committed Question set.

If Attempt start locks Assessment first in the future Stage 7 contract:

- it inserts first Attempt;
- waiting Question mutation sees activity and rejects.

There must be no state where an Attempt starts against one scoring definition while the Teacher concurrently commits another.

---

# 18. Total Possible Points

Use delivered:

```text
AssessmentPointMath
```

after successful add/update/delete.

Authoritative algorithm:

1. read all current Question point values from locked rows;
2. convert/sum using approved scale-6 exact arithmetic;
3. persist recalculated Assessment `total_possible_points`.

Do not trust:

- prior total delta arithmetic;
- client total;
- Flutter sum;
- binary floating-point accumulation.

Reorder does not change total.

For active Homework, apply Section 13.4 before commit.

---

# 19. Aggregate `updated_at` Semantics

The Homework Assessment is the authoring aggregate root.

On a **semantic** successful Question mutation:

- add -> update/touch Assessment `updated_at`;
- PATCH -> update/touch Assessment `updated_at`;
- delete -> update/touch Assessment `updated_at`;
- reorder -> update/touch Assessment `updated_at` if order changed.

The `homework_assignments.updated_at` lifecycle row must **not** change merely because Questions changed.

Typed child rows change only when their configuration changes.

No-op requests must preserve timestamps as defined below.

---

# 20. No-Op Semantics

## 20.1 PATCH no-op

Build/compare the canonical resulting Question representation.

If submitted fields produce no semantic change:

- return success;
- do not save Question;
- do not delete/recreate typed configuration;
- do not regenerate Matching `match_key`;
- do not recalculate/write total;
- do not touch Assessment;
- preserve Question/Assessment/child `updated_at`.

## 20.2 Reorder no-op

If submitted `question_ids` already equal current position order:

- return success;
- do not rewrite positions;
- do not touch Questions;
- do not touch Assessment.

## 20.3 Delete

Delete can never be a no-op because inaccessible/missing Question is 404.

## 20.4 Add

Add can never be a no-op.

---

# 21. Request Validation Rules

Use current strict Teacher JSON conventions.

For POST/PATCH/reorder:

- `Content-Type` media type must be `application/json`;
- body must be a JSON object;
- reject malformed/empty/null/scalar/array body;
- reject query parameters;
- reject unknown/protected fields;
- do not silently cast numeric strings to numbers;
- do not silently cast `"true"`/`1` to boolean;
- nested configuration must be a JSON object;
- reuse S06-BE-002 domain validation for type/config compatibility.

For DELETE:

- no JSON body;
- no query parameters.

Validation errors:

```text
422 validation_failed
```

with field-level errors where practical.

Domain validator `InvalidArgumentException` must be translated at the request/action boundary into the existing validation error contract; do not leak internal exception text as server error.

---

# 22. Error Contract

Use existing API envelopes.

| Case | Required result |
|---|---|
| Unauthenticated | `401 authentication_required` |
| Inactive account/Institution | existing middleware contract |
| Password change required | `403 password_change_required` |
| Wrong role | existing Teacher role middleware contract |
| Malformed/foreign/unowned/non-Homework Assessment | `404 resource_not_found` |
| Malformed/foreign/unowned Question | `404 resource_not_found` |
| Unknown/protected/malformed input | `422 validation_failed` |
| Invalid typed Question config | `422 validation_failed` |
| Invalid add position | `422 validation_failed` |
| Reorder not exact current set | `422 validation_failed` |
| Max Question count exceeded | `422 validation_failed` |
| Closed/archived Topic | `409 topic_not_editable` |
| Closed Homework | `409 task_closed` |
| Archived Homework | `409 task_archived` |
| Any Assessment Attempt exists | `409 business_conflict` |
| Locked official result pair | `409 result_pair_locked` |
| Active mutation would remove all scoreable points | `409 assessment_has_no_scoreable_points` |
| Unexpected failure | safe existing `500 server_error` |

Do not return database/stack details.

---

# 23. Success Response Contract

Question mutations return the **complete authoritative Teacher Homework resource** from S06-BE-003.

This is deliberate: Question mutation changes server-owned:

- Question set/order/config;
- `total_possible_points`;
- aggregate `updated_at`.

Returning the complete Homework prevents the client from reconstructing authoritative aggregate state from partial mutations.

## 23.1 Add

```text
201 Created
```

Response:

```json
{
  "data": {
    "...": "complete TeacherHomeworkResource"
  },
  "message": "Question created successfully."
}
```

## 23.2 PATCH

```text
200 OK
```

Response full Homework:

```text
message = "Question updated successfully."
```

A no-op PATCH returns the same 200/message.

## 23.3 DELETE

```text
200 OK
```

Response full Homework after deletion/compaction:

```text
message = "Question deleted successfully."
```

Do **not** return `204`, because authoritative recalculated Homework state is useful to the client.

## 23.4 Reorder

```text
200 OK
```

Response full Homework:

```text
message = "Questions reordered successfully."
```

A no-op reorder returns the same 200/message without writes.

---

# 24. Canonical Typed Configuration Readback

Reuse the S06-BE-003 Teacher Question serializer.

Do not introduce a second response shape.

After every semantic mutation, return configuration reconstructed from normalized persisted rows.

Important:

- no internal child-row UUIDs;
- Matching persisted `match_key` may be surfaced as readback `client_key`;
- File Based returns fixed:
  `["pdf","docx","ppt","pptx"]`;
- automatic Short Written accepted answers retain persisted order;
- Fill Blank accepted answers retain persisted order;
- configuration is always a JSON object.

---

# 25. Application Actions / Placement

Expected focused Actions:

```text
AddTeacherAssessmentQuestion
UpdateTeacherQuestion
DeleteTeacherQuestion
ReorderTeacherAssessmentQuestions
```

Equivalent concise naming is allowed.

Use thin controllers.

Reuse:

```text
TeacherHomeworkAccess
QuestionConfigurationValidator
QuestionConfigurationWriter
QuestionPositionSetValidator
AssessmentPointMath
TeacherHomeworkResource
```

Add:

```text
QuestionPositionWriter
```

only if not already present.

A focused Question mutation access helper may be created only if needed to scope a Question through Teacher-owned Homework; do not create a generic authorization framework.

Controllers must not contain:

- tenant query logic;
- lifecycle decisions;
- typed persistence loops;
- point arithmetic;
- row-lock orchestration.

Models must not gain mutation workflow methods.

---

# 26. Expected Files and Areas

| Area | Action |
|---|---|
| `backend/routes/api.php` | Add four Question routes only |
| `backend/app/Actions/Teacher/AddTeacherAssessmentQuestion.php` or equivalent | Create |
| `backend/app/Actions/Teacher/UpdateTeacherQuestion.php` | Create |
| `backend/app/Actions/Teacher/DeleteTeacherQuestion.php` | Create |
| `backend/app/Actions/Teacher/ReorderTeacherAssessmentQuestions.php` | Create |
| `backend/app/Support/Assessment/QuestionPositionWriter.php` | Create if dependency does not already provide equivalent |
| `backend/app/Support/Assessment/QuestionConfigurationWriter.php` | Extend narrowly for replace/delete typed configuration if required |
| `backend/app/Support/Teacher/TeacherHomeworkAccess.php` | Extend narrowly for Question-scoped resolution/locking if required |
| `backend/app/Http/Controllers/Api/V1/Teacher/TeacherQuestionController.php` | Create |
| `backend/app/Http/Requests/Teacher/TeacherQuestionCreateRequest.php` | Create |
| `backend/app/Http/Requests/Teacher/TeacherQuestionUpdateRequest.php` | Create |
| `backend/app/Http/Requests/Teacher/TeacherQuestionDeleteRequest.php` | Create if needed for no-body/query enforcement |
| `backend/app/Http/Requests/Teacher/TeacherQuestionReorderRequest.php` | Create |
| `backend/app/Http/Resources/Teacher/TeacherHomeworkResource.php` | Reuse; modify only if dependency defect blocks complete post-mutation serialization |
| S06-BE-001/S06-BE-002 models | No changes unless a narrowly missing relation is required |
| `backend/tests/Feature/Teacher/TeacherQuestionMutationApiTest.php` | Create |
| `backend/tests/Feature/Teacher/TeacherQuestionEditingIntegrityTest.php` | Create |
| `backend/tests/Feature/Teacher/TeacherQuestionMutationAuthorizationTest.php` | Create |
| `backend/tests/Feature/Teacher/TeacherQuestionMutationConcurrencyTest.php` | Create if concurrency tests are kept separate |
| `backend/tests/Unit/Support/Assessment/QuestionPositionWriterTest.php` | Optional if meaningful logic is not fully covered by feature tests |

Changes outside these areas require concrete necessity and must be reported.

Do not modify docs, frontend, seeders, dependencies, task files, or unrelated code.

---

# 27. Acceptance Criteria

- [x] All four exact Teacher Question routes exist.
- [x] Stage 6 Question mutation accepts only authorized Homework Assessments; non-Homework is privacy-safe 404.
- [x] Direct Question UUIDs cannot escape Teacher/Institution/Topic/Group scope.
- [x] Add accepts exactly the approved common Question fields and typed configuration.
- [x] Add supports positions `1..N+1`, safely shifts existing Questions, and leaves exact contiguous positions.
- [x] Add enforces max Questions.
- [x] PATCH cannot directly edit `position`; reorder is the sole order endpoint.
- [x] PATCH type/checking-mode change requires full `configuration`.
- [x] Typed configuration replacement removes obsolete typed rows and persists exactly the new valid configuration.
- [x] Matching semantic no-op ignores request correlation keys and does not regenerate server keys.
- [x] Delete removes typed rows + Question only before activity and compacts remaining positions.
- [x] Draft may end with zero Questions/zero total.
- [x] Active Homework can never be mutated into zero Questions or zero total.
- [x] Reorder requires the exact complete current Question set and writes canonical `1..N`.
- [x] Position writes do not violate unique constraints transiently.
- [x] Add/update/delete recalculate exact server total with `AssessmentPointMath`.
- [x] Reorder leaves total unchanged.
- [x] Any Attempt blocks every Question add/update/delete/reorder.
- [x] Locked official pair blocks Question mutation.
- [x] Closed/archived Topic or Homework blocks mutation with exact required conflict.
- [x] Question mutation and future first Attempt serialize through Assessment row lock.
- [x] Semantic Question changes touch Assessment `updated_at`; no-op does not.
- [x] `homework_assignments.updated_at` is not changed solely by Question mutation.
- [x] PATCH/reorder no-op performs zero configuration/position/aggregate write churn.
- [x] Every successful mutation returns complete authoritative Teacher Homework resource.
- [x] No Student Attempt/checking/scoring/lifecycle/result-pair mutation/Blitz/frontend/docs/seed/dependency work enters scope.
- [x] Focused tests pass.
- [x] Pint passes.
- [x] `git diff --check` passes.
- [x] Final focused diff review finds no blocking tenant/security/data-integrity/concurrency/scope problem.

---

# 28. Focused Tests and Verification

Run from:

```text
backend/
```

Do not run the full backend suite. Full regression belongs to Stage 6 Backend Phase 2.

## 28.1 New Question API tests

```bash
php artisan test \
  tests/Feature/Teacher/TeacherQuestionMutationApiTest.php \
  tests/Feature/Teacher/TeacherQuestionEditingIntegrityTest.php \
  tests/Feature/Teacher/TeacherQuestionMutationAuthorizationTest.php
```

If concurrency is separate:

```bash
php artisan test tests/Feature/Teacher/TeacherQuestionMutationConcurrencyTest.php
```

Required coverage includes:

### Add

- add first Question;
- append;
- insert at beginning/middle;
- safe shifting under unique position constraint;
- position 0/out of range rejected;
- max count rejected;
- all nine types positive coverage, parameterized where practical;
- malformed configuration rejected;
- strict JSON/object/unknown/protected/query rejection;
- exact total recalculation;
- full Homework response.

### PATCH

- prompt-only;
- instructions;
- points;
- configuration replacement;
- type + checking + config transition;
- missing config on type/mode change rejected;
- `position` rejected;
- old typed rows removed;
- all resultant typed rows valid;
- exact total changes;
- no-op preserves timestamps/typed rows;
- Matching equivalent pair content with changed correlation key is no-op;
- full Homework response.

### Delete

- draft delete;
- typed rows removed;
- position compaction;
- total recalculated;
- last draft Question -> zero/zero allowed;
- active delete preserving positive total allowed;
- active last/last-scoreable Question rejected atomically;
- full Homework response.

### Reorder

- full valid reorder;
- reverse order;
- no-op order;
- missing ID;
- duplicate ID;
- foreign/other Assessment ID;
- stale ID;
- subset/extra rejected;
- no total change;
- no transient uniqueness failure.

### Integrity/lifecycle

- draft editable;
- active zero Attempts editable;
- any `in_progress` Attempt locks;
- submitted/checked Attempt also locks;
- locked result pair blocks;
- closed Homework blocks;
- archived Homework blocks;
- closed/archived Topic blocks;
- no hard delete after activity;
- no writes on blocked requests.

### Authorization/tenant

- foreign Assessment 404;
- other Teacher 404;
- former Teacher Group membership 404;
- foreign Question 404;
- non-Homework Assessment 404;
- malformed UUID 404;
- no scope leakage.

## 28.2 Concurrency

Prove the relevant serialized boundary using the repository's existing PostgreSQL concurrency-test pattern.

At minimum verify:

- concurrent reorder/add cannot leave duplicate/gapped final positions;
- concurrent Question mutation against creation of the first structural Attempt cannot commit both in a way that mutates scoring definition after activity starts.

For the second case, if Stage 7 Attempt action does not yet exist, use a focused test transaction that follows the frozen Stage 7 contract:

```text
lock Assessment -> insert first Attempt
```

to verify S06-BE-004's lock/check behavior.

Do not implement public Attempt API merely for the test.

## 28.3 Dependency regression — S06-BE-003

Run delivered focused Teacher Homework authoring tests because this task adds routes and reuses/extends Homework access/resource/writer behavior:

```bash
php artisan test \
  tests/Feature/Teacher/TeacherHomeworkAuthoringApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkRecipientApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkAuthorizationApiTest.php
```

Also run:

```bash
php artisan test tests/Unit/Domain/Assessment/AssessmentPointMathTest.php
```

If the delivered S06-BE-003 concurrency test is separate and shared access locking was modified, run it too.

## 28.4 Dependency regression — S06-BE-002

Run the typed Question domain tests:

```bash
php artisan test \
  tests/Unit/Domain/Assessment/QuestionConfigurationValidatorTest.php \
  tests/Unit/Domain/Assessment/QuestionPositionSetValidatorTest.php
```

Run Question persistence/model tests only if production typed model/writer relationships were modified:

```bash
php artisan test \
  tests/Feature/Persistence/QuestionPersistenceTest.php \
  tests/Feature/Persistence/QuestionFactoryModelTest.php
```

Do not run the whole backend suite.

## 28.5 Format

```bash
./vendor/bin/pint --test
```

## 28.6 Always

```bash
git diff --check
```

Then inspect the complete diff:

- only Question route/action/request/support/test areas changed;
- no delivered migration rewrite;
- no tenant scope weakened;
- no global unscoped Question lookup;
- no JSON blob/config regression;
- no Student Attempt public behavior;
- no checking/scoring;
- no Homework lifecycle implementation;
- no result-pair mutation;
- no frontend/docs/seed/dependency change;
- no tests weakened;
- no debug/secrets/temp artifacts/unrelated format churn.

If implementation necessarily changes shared infrastructure beyond this verification contract, report the concrete regression risk instead of independently running a broad suite.

---

# 29. Project Owner Manual Check

```text
Not required at task level — backend API behavior is covered by focused automated verification.
Real-stack Question Builder smoke belongs to S06-INT-001.
```

---

# 30. Delivery

Follow root `AGENTS.md` and `tasks/README.md`.

Delivery execution:

```text
Project Owner
```

Suggested delivery:

```text
Branch: feat/s06-be-004-question-mutations
Commit: feat(stage6): add teacher question mutations
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

## 30.1 Acceptance and Delivery Evidence

- Delivery: PR #149, merge `1f366e8b4b98f1f40a115ca02c64bb7709901156`.
- Final independent review: `PASS — P1=0, P2=0, P3=0`.
- Focused verification: 67 tests passed, 880 assertions.
- Pint: PASS.
- `git diff --check`: PASS.
- Delivery scope: exactly 24 backend files.
- Final synchronization: local `main == origin/main`, ahead/behind `0/0`, worktree clean.

---

# 31. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to rediscover requirements.

| Source/reference | Decision already encoded above |
|---|---|
| Approved Stage 6 decomposition | BE-004 owns dedicated Question add/update/delete/reorder + editing integrity |
| Locked Question API contract | Shared Assessment Question endpoint URLs |
| Locked Question authoring contract | Dedicated Question endpoints are reusable for Homework/Blitz |
| Stage 6 sequencing resolution | Current implementation authorizes Homework only; future Blitz stage extends shared boundary |
| Homework editing-integrity rules | Questions/options/correct answers/points/order lock after Student activity |
| S06-BE-001 | structural Attempt + staged result-pair persistence |
| S06-BE-002 | normalized typed Question persistence and validator contracts |
| S06-BE-003 | Teacher Homework access/resource, typed writer, exact point math |
| Approved concurrency resolution | Assessment row is the serialization boundary between scoring-content mutation and future first Attempt |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |

---

# 32. Codex Final Report

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
7. **Editing integrity/concurrency** — evidence.
8. **Question positions/total points** — evidence.
9. **No-op/scope/diff** — evidence including `git diff --check`.
10. **Delivery handoff** — Project Owner + current Git state.
11. **Deviations/blockers** — exact facts.

Do not output task `Accepted`.

Do not repeat the contract or paste large successful command logs.

If any required product, API, persistence, tenant, security, lifecycle, Question, or concurrency decision is missing or conflicts with delivered dependencies/current source, return `BLOCKED` rather than deciding independently.
