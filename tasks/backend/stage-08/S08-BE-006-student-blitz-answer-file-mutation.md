# Codex Implementation Contract: S08-BE-006 — Student Blitz Typed and File Answer Mutation

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-BE-006` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Laravel shared Student answer route + Blitz typed/file save-replace + private submission resume` |
| Depends on | `S08-DOC-001`, `S08-BE-001`, `S08-BE-002`, `S08-BE-003`, `S08-BE-004`, `S08-BE-005` — all `Accepted / Delivered` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` after dependencies are delivered and immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |
| Backend block checkpoint | `Stage 8 Backend Phase 2` after `S08-BE-001…010` are `Accepted / Delivered` |
| Blocks | `S08-BE-007` |

Start only when:

```text
S08-DOC-001 = Accepted / Delivered
S08-BE-001  = Accepted / Delivered
S08-BE-002  = Accepted / Delivered
S08-BE-003  = Accepted / Delivered
S08-BE-004  = Accepted / Delivered
S08-BE-005  = Accepted / Delivered
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
4. delivered S08-BE-001…005 source/tests directly required here;
5. current Stage 7 Student Homework answer/file Actions, Requests, Resources, access/support and focused tests;
6. current protected Student submission download path;
7. current shared Question/Answer/File persistence directly required by this task.

Do **not** read:

- `docs/01–09`;
- roadmap files;
- Stage indexes;
- `S08-DOC-001`;
- previous implementation task files;
- closure reviews;
- frontend code

to infer behavior.

This contract resolves:

- canonical shared Student answer endpoint;
- Homework/Blitz dispatch;
- strict typed answer payloads;
- file upload/replace behavior;
- Student/Attempt/Question/Tenant scope;
- Blitz lifecycle/write eligibility;
- authoritative deadline rule;
- no-timeout-writer boundary;
- no-op semantics;
- normalized typed persistence;
- pending checking state;
- private file storage/compensation;
- Student own submission download;
- Start/Resume answer-state projection;
- concurrency/future-finalization compatibility;
- errors;
- acceptance criteria;
- focused tests/verification.

If delivered dependencies materially conflict with this contract, return:

```text
BLOCKED
```

with exact file/line evidence.

Do not redesign Stage 7 Homework answer behavior or pre-implement BE-007 finalization.

---

# 3. Goal

Extend the existing shared Student Attempt answer URL so an authenticated Student can save/replace answers on an active own Blitz Attempt.

Support all nine approved Question types:

```text
single_choice
multiple_choice
true_false
short_written
open_written
file_based
matching
ordering
fill_in_blank
```

The task must:

- reuse the delivered normalized `attempt_answers`/typed payload tables;
- reuse the delivered private `files` + `answer_files` model;
- mutate only an own editable `in_progress` Blitz Attempt;
- require `server_now < attempt.deadline_at`;
- reject late writes with `blitz_time_expired`;
- preserve exact Student text semantics;
- preserve file privacy;
- return canonical saved answer state;
- make saved answer states visible on later Blitz Start/Resume;
- never check/score answers.

---

# 4. Canonical Public Endpoint — No New Route Family

Continue using exactly:

```text
PUT /api/v1/student/attempts/{attempt}/answers/{question}
```

This route is shared by:

```text
Homework Attempts
Blitz Attempts
```

Do not add:

```text
/student/blitz/attempts/{attempt}/answers/{question}
/student/homework/attempts/{attempt}/answers/{question}
```

aliases.

The route remains inside the existing Student middleware group:

```text
auth:sanctum
active.account
password.changed
role:student
```

No `Idempotency-Key` is required for ordinary answer/file mutation.

---

# 5. Explicit Non-Goals

Do not implement or change:

- Student Blitz Start rules except answer-state readback extension;
- Attempt #2 exception runtime;
- explicit Blitz Submit;
- timeout finalization;
- request-path timeout reconciliation;
- Scheduler;
- Teacher Blitz Close;
- exception grant;
- Teacher monitoring;
- automatic checking;
- Teacher manual review;
- awarded points;
- Attempt score;
- official Blitz score;
- Topic result;
- frontend;
- E2E harness/seed data;
- schema/migrations;
- dependencies;
- docs/tasks.

Do not:

- create a parallel `blitz_answers` table;
- create a parallel `blitz_files` table;
- add generic JSON answer persistence;
- add per-question timer;
- add idempotency records for ordinary answer PUT.

---

# 6. Existing Stage 7 Answer Persistence Must Be Reused

Reuse the delivered lower-level normalized persistence:

```text
attempt_answers
answer_choice_selections
answer_text_values
answer_boolean_values
answer_matching_pairs
answer_ordering_items
answer_fill_blank_values
answer_files
files
```

Reuse the delivered answer helpers that are structurally Assessment-generic even where their historical class names contain `Homework`, including the current equivalents of:

```text
StudentHomeworkAnswerValue
StudentHomeworkAnswerIntegrity
StudentHomeworkAnswerWriter
StudentAnswerText
StudentSubmissionUploadPolicy
LearningMaterialFileInspector
PrivateFileStorage
StudentAttemptAnswerStateResource
```

Do **not** duplicate their algorithms for Blitz.

Do not mass-rename stable Stage 7 support classes solely for cosmetic naming in this task.

A narrow type-neutral result/dispatcher extraction is required where the shared route itself becomes multi-Assessment-type.

---

# 7. Shared Route Architecture

The current route/controller is historically Homework-specific.

Refactor the route boundary so it is truthfully shared while preserving the exact public URL.

Create a thin type-neutral controller, conceptually:

```text
StudentAttemptAnswerController
```

and type-neutral request:

```text
StudentAttemptAnswerRequest
```

The existing Homework request wire contract must remain exactly unchanged.

The old Homework-specific controller/request may be removed after all direct callers/tests are updated.

Do not keep two route implementations for the same URL.

---

# 8. Type-Safe Answer Dispatcher

Create one focused Action, conceptually:

```text
SaveStudentAttemptAnswer
```

Responsibilities only:

1. privacy-safely resolve the authenticated Student's own Attempt target;
2. determine:
   ```text
   AssessmentType::Homework
   AssessmentType::Blitz
   ```
3. dispatch:
   - Homework non-file -> delivered `SaveStudentHomeworkAttemptAnswer`;
   - Homework file -> delivered `SaveStudentHomeworkFileAnswer`;
   - Blitz non-file -> new `SaveStudentBlitzAttemptAnswer`;
   - Blitz file -> new `SaveStudentBlitzFileAnswer`;
4. return one type-neutral mutation result.

Do not place lifecycle logic in the dispatcher.

Do not globally resolve arbitrary Attempts before ownership scope.

---

# 9. Type-Neutral Mutation Result

Replace the narrow result type:

```text
StudentHomeworkAttemptAnswerMutationResult
```

with:

```text
StudentAttemptAnswerMutationResult
```

Exact data remains:

```text
Question $question
?AttemptAnswer $attemptAnswer
```

Update:

- current Homework typed answer Action;
- current Homework file answer Action;
- current answer-state projection;
- `StudentAttemptAnswerStateResource`

to use the neutral result class.

This is a semantic shared-boundary correction, not a behavior change.

Do not rename the deeper stable answer persistence helpers merely for naming.

---

# 10. Own Attempt Target Resolution

Create a focused resolver, conceptually:

```text
StudentAttemptAnswerTarget
```

It must resolve `{attempt}` only when all are true:

```text
assessment_attempts.institution_id = Student Institution
assessment_attempts.student_id = authenticated Student
assessment_students.id = assessment_attempts.assessment_student_id
assessment_students.institution_id = Student Institution
assessment_students.student_id = authenticated Student
assessment_students.assessment_id = assessment_attempts.assessment_id
assessments.id = assessment_attempts.assessment_id
assessments.institution_id = Student Institution
assessments.type in (homework, blitz)
```

Malformed UUID, foreign Tenant, another Student, broken ownership graph, or unsupported Assessment type:

```text
404 resource_not_found
```

Return only enough identity to dispatch safely.

Do not expose the target to the client.

---

# 11. Question Scope

`{question}` must:

```text
be a valid UUID
belong to the same Institution
belong to the exact same Assessment as the Attempt
```

Otherwise:

```text
404 resource_not_found
```

Do not resolve a Question globally and authorize afterward.

Every supplied option/item/blank child ID must belong to the same Question/Institution according to the existing Stage 7 validators.

Foreign/wrong-Question child values use the existing:

```text
422 validation_failed
```

or:

```text
422 selection_limit_exceeded
```

contract where already defined.

---

# 12. Request Wire Contract — Preserve Stage 7 Exactly

For non-file answers:

```text
Content-Type: application/json
body = one JSON object
no query parameters
```

For file answers:

```text
Content-Type: multipart/form-data
fields = type, file
no query parameters
```

Reject unknown/protected fields.

Do not accept:

```text
attempt_id
question_id
student_id
institution_id
checking_status
awarded_points
feedback
checked_by_user_id
checked_at
started_at
deadline_at
finalized_at
is_correct
correct_value
accepted_answers
correct_position
match_key
```

Use the raw JSON body as authoritative for Student text.

Do not allow global middleware normalization to convert exact Student `""` into `null` contrary to the accepted Stage 7 wire contract.

---

# 13. Non-File Payload Shapes

Exact accepted shape depends on `type`.

## 13.1 Single choice

```json
{
  "type": "single_choice",
  "selected_option_ids": ["option-uuid"]
}
```

Rules:

- exactly one option ID;
- same Question;
- duplicate IDs impossible;
- valid UUID string.

Single choice cannot be cleared by an empty selection.

## 13.2 Multiple choice

```json
{
  "type": "multiple_choice",
  "selected_option_ids": []
}
```

or selected option IDs.

Rules:

- all IDs same Question;
- no duplicates;
- maximum selections equals the current configured number of correct options;
- exceeding cap:
  ```text
  422 selection_limit_exceeded
  ```
- empty array means clear/remove the saved answer.

The backend may internally load `is_correct` only to derive the selection cap.

Never serialize correct identities.

## 13.3 True / False

```json
{
  "type": "true_false",
  "value": true
}
```

`value` must be a JSON boolean.

## 13.4 Short Written

```json
{
  "type": "short_written",
  "text": "DNS"
}
```

Max accepted Stage 7 length remains:

```text
1000
```

Whitespace semantics remain exactly the delivered `StudentAnswerText` rule.

Semantic empty text clears/removes the answer.

Non-empty text is persisted exactly:

- no trim;
- no case normalization;
- no Unicode normalization.

## 13.5 Open Written

```json
{
  "type": "open_written",
  "text": "Long explanation"
}
```

Max length:

```text
20000
```

Semantic empty clears.

Exact non-empty text preserved.

## 13.6 Matching

```json
{
  "type": "matching",
  "pairs": [
    {
      "left_item_id": "uuid",
      "right_item_id": "uuid"
    }
  ]
}
```

Rules:

- left IDs belong to current Question left side;
- right IDs belong to current Question right side;
- no repeated left ID;
- no repeated right ID;
- partial valid matching is allowed;
- empty array clears answer.

## 13.7 Ordering

```json
{
  "type": "ordering",
  "items": [
    {
      "item_id": "uuid",
      "position": 1
    }
  ]
}
```

Rules:

- item IDs belong to current Question;
- no duplicate item IDs;
- submitted positions unique;
- each position is integer in current Question bounds;
- partial valid ordering is allowed;
- empty array clears answer.

Do not load/use correct positions for mutation validation.

## 13.8 Fill in Blank

```json
{
  "type": "fill_in_blank",
  "values": [
    {
      "blank_id": "uuid",
      "text": "answer"
    }
  ]
}
```

Rules:

- blank IDs belong to current Question;
- no duplicate blank IDs;
- each provided text is non-semantic-empty;
- max individual text length remains 1000;
- partial valid values are allowed;
- empty array clears answer.

Do not load/use accepted-answer values.

---

# 14. File-Based Payload

Use multipart:

```text
type = file_based
file = required upload
```

No other fields.

The target Question must be:

```text
QuestionType::FileBased
```

Otherwise:

```text
422 validation_failed
```

A JSON `file_based` body is not accepted.

A multipart non-file answer type is not accepted.

---

# 15. File Type / Content Validation

Reuse the existing delivered content-inspection path.

Allowed Student submission extensions remain exactly:

```text
pdf
docx
ppt
pptx
```

Server-detected content/MIME must agree with the accepted type.

Do not trust filename extension alone.

Reject:

- empty upload;
- failed upload;
- unsupported type;
- extension/content mismatch;
- invalid metadata;
- filename over accepted Stage 7 maximum.

Use existing stable errors:

```text
422 unsupported_file_type
422 file_too_large
500 file_upload_failed
```

where currently defined.

---

# 16. File Size Limit

Use:

```text
effective limit
=
min(
  platform Student submission max = 15 MiB,
  institution_settings.student_submission_max_mb
)
```

The setting is server-authoritative.

Use the current Stage 7 upload policy.

Perform:

1. early pre-storage limit validation;
2. post-inspection limit validation;
3. locked current-setting revalidation before DB persistence.

If the Institution Admin lowered the limit while upload/inspection occurred, the latest committed limit wins.

Do not persist an oversized answer.

---

# 17. Blitz Write Eligibility

New Blitz answer Actions use the delivered:

```text
StudentBlitzAttemptAccess
StudentBlitzAccess
```

or exact equivalents from BE-005.

Do not route Blitz execution through `StudentHomeworkAttemptAccess`.

After privacy-safe preliminary resolution, inside transaction re-lock and validate:

```text
Topic
Assessment
BlitzTask
own AssessmentAttempt
Question
existing AttemptAnswer
```

Required current state:

```text
Topic.status = active
BlitzTask.status = active
Attempt belongs to Student/recipient/Blitz
Attempt.status = in_progress
Attempt.finalized_at = null
Attempt.locked_at = null
Attempt.deadline_at is non-null
server_now < Attempt.deadline_at
```

Only then may an answer write occur.

---

# 18. Blitz Lifecycle Error Behavior

For assigned own Blitz Attempt when:

```text
Topic not active
Blitz status != active
```

return:

```text
409 blitz_not_active
```

Use this Student-facing stable code for:

```text
draft
scheduled
closed
archived
```

Do not expose Teacher lifecycle internals.

If Blitz remains active but Attempt is already terminal before deadline:

```text
409 attempt_not_editable
```

Use the existing machine code.

---

# 19. Authoritative Deadline Rule

Every Blitz answer/file mutation independently checks:

```text
observedAt = server_now
```

**after** relevant lifecycle/Attempt/Question locks are acquired.

Eligibility:

```text
observedAt < attempt.deadline_at
```

Expired:

```text
observedAt >= attempt.deadline_at
```

returns:

```text
409 blitz_time_expired
```

No client time/header/payload can change this.

The rule is identical for synchronized and individual modes because:

```text
assessment_attempts.deadline_at
```

already persists the authoritative effective deadline.

Do not recompute synchronized or individual deadline from client state during answer mutation.

---

# 20. BE-006 Does Not Finalize Timeout

This task must **not** write:

```text
status = timed_out_finalized
finalization_reason = timeout_auto_submit
finalized_at
locked_at
```

when a deadline is reached.

Instead:

```text
expired write
-> zero answer/file domain mutation
-> 409 blitz_time_expired
```

`S08-BE-007` later introduces the single shared timeout/finalization engine and wires it into this same path.

Do not create a temporary Blitz timeout service in BE-006.

---

# 21. Attempt Status vs Deadline Precedence

After privacy/lifecycle/structural validation:

1. validate own Attempt integrity;
2. if Attempt is not `in_progress`:
   ```text
   409 attempt_not_editable
   ```
3. capture/recheck authoritative time;
4. if:
   ```text
   server_now >= deadline_at
   ```
   return:
   ```text
   409 blitz_time_expired
   ```

This prevents a terminal historical Attempt from being reclassified as “timed out” by a later answer request.

BE-007 may later reconcile only genuinely `in_progress` expired Attempts.

---

# 22. Lock Order for Blitz Answer Mutation

Use deterministic ordering compatible with BE-005 and future BE-007/BE-008:

```text
1. Topic — shared/read lock as appropriate
2. Assessment — shared/read lock as appropriate
3. BlitzTask — shared/read lock as appropriate
4. AssessmentAttempt — exclusive row lock
5. Question — shared lock
6. existing AttemptAnswer — exclusive row lock
7. existing typed answer child rows through integrity/writer logic
8. InstitutionSetting/file rows when file-based path requires them
```

Do not reverse Attempt vs parent task ordering.

The Attempt row is the decisive serialization point against:

- future Submit;
- timeout finalization;
- Teacher Close;
- competing answer mutation.

---

# 23. Mutation vs Future Finalization Invariant

The only valid outcomes are:

## Answer/file mutation obtains/commits Attempt lock first

```text
mutation commits
future finalizer later sees the committed answer/file
and freezes it
```

## Finalizer obtains/commits first

```text
Attempt becomes terminal
later mutation re-reads terminal state
performs zero answer/file-domain mutation
```

Never allow:

```text
terminal Blitz Attempt
+
Student answer/file change committed afterward
```

BE-007 must be able to reuse this invariant without changing BE-006 persistence semantics.

---

# 24. Answer Persistence State

Every successful Stage 8 save/replace must keep:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

On replacement, do not change that state to:

```text
auto_checked
waiting_for_teacher_review
teacher_checked
```

Stage 8 does no checking/scoring.

---

# 25. Complete Replacement Semantics

One PUT represents the complete current answer for that Question.

Do not merge partial payload with an older saved payload unless the payload itself is a valid partial answer shape such as partial matching/fill/ordering.

For changed value:

1. lock existing answer;
2. delete old type-specific payload in FK-safe order;
3. persist canonical new payload;
4. keep one AttemptAnswer per Attempt/Question;
5. return canonical representation.

No stale child rows may remain.

---

# 26. Clear Semantics

Where Section 13 allows a semantic empty value:

```text
multiple_choice []
semantic-empty short/open text
matching []
ordering []
fill_in_blank []
```

the current answer is removed entirely:

```text
attempt_answers row deleted
typed child rows deleted
```

Return:

```json
{
  "question_id": "...",
  "type": "...",
  "answer": null,
  "updated_at": null
}
```

Do not create an empty placeholder answer row.

Single choice/true_false do not have a clear-via-empty request shape.

File answer has no “delete file answer” operation in this task.

---

# 27. Semantic No-Op — Typed Answers

If canonical resulting answer equals the currently persisted canonical answer:

- perform zero answer-domain writes;
- do not change `attempt_answers.updated_at`;
- do not rewrite child rows;
- return current canonical answer state.

Canonical comparison uses delivered Stage 7 semantics.

Order-insensitive request forms are normalized according to the existing answer helpers.

---

# 28. File Storage Key

Use the existing private Student submission key convention:

```text
student-submissions/{institution_id}/{attempt_id}/{question_id}/{server_uuid}.{extension}
```

Do not include:

- Student display name;
- original filename;
- Topic title;
- correct-answer data

in storage key.

Use private storage only.

---

# 29. File Creation / Replacement Identity

## 29.1 First file answer

Create:

```text
AttemptAnswer
File(category = student_submission)
AnswerFile
```

with one stable server File UUID.

## 29.2 Changed replacement

Preserve the existing:

```text
File.id
```

identity.

Update its current storage metadata to the newly accepted private blob.

Do not create a second answer-file relation.

After DB commit, best-effort delete the old private blob.

If old blob deletion fails, persistence still points only at the new current blob; use existing cleanup logging behavior.

## 29.3 Identical replacement

If inspected metadata matches the persisted current File:

```text
checksum
size
extension
MIME
original_name
```

treat as semantic no-op:

- delete the newly staged duplicate blob;
- perform zero DB writes;
- keep existing File ID/storage key;
- no timestamp churn.

---

# 30. File Compensation

File bytes are staged before the DB transaction as in Stage 7.

Every path that does **not** commit the staged file as the new current Student answer must best-effort delete the new blob exactly once.

This includes:

- lifecycle conflict;
- terminal Attempt;
- expired deadline;
- Question mismatch;
- current upload setting now too small;
- DB exception/rollback;
- semantic identical no-op.

Use:

```text
DB::afterRollBack
```

plus exception compensation as already delivered.

Do not delete the previously-valid old blob before the new DB state commits.

---

# 31. File Answer Integrity

Existing persisted file answer must validate:

```text
same Institution
AttemptAnswer belongs to Attempt
Question belongs to same Assessment
Question.type = file_based
AnswerFile belongs to Answer
File belongs to same Institution
File.uploaded_by_user_id = Student
File.category = student_submission
removed_at = null
supported extension/MIME
valid size/checksum/storage identity
```

Structural corruption:

```text
409 business_conflict
```

or internal `LogicException` according to the delivered Stage 7 public/invariant split.

Do not silently repair or replace a corrupt prior answer.

---

# 32. Shared Student Answer Route Dispatch Must Preserve Homework

The route now accepts own Homework or Blitz Attempts.

For Homework:

- call existing delivered Homework answer/file Actions;
- preserve all Stage 7 lifecycle/deadline/finalization behavior;
- preserve current request/error/response semantics.

Do not rewrite Homework logic into Blitz rules.

For Blitz:

- call new Blitz-specific Actions;
- use Blitz lifecycle/deadline semantics.

This is deliberate:

```text
shared lower-level answer persistence
+
separate Homework/Blitz execution policy
```

---

# 33. Student Own Submission Download Must Support Blitz

The existing canonical protected endpoint remains:

```text
GET /api/v1/files/{file}/download
```

No new download route.

Extend:

```text
ProtectedStudentSubmissionAccess
```

so an authenticated Student can download their own current `student_submission` File when it belongs to either:

```text
Homework Attempt
Blitz Attempt
```

## 33.1 Homework preservation

Existing allowed Homework historical states remain unchanged:

```text
active
closed
archived
```

Do not change Stage 7 access semantics.

## 33.2 Blitz allowed historical states

Allow own Blitz Student submission file when associated BlitzTask status is:

```text
active
closed
archived
```

Draft/Scheduled must not authorize a Student submission download path.

## 33.3 Ownership remains mandatory

Require:

```text
File same Institution
File uploaded_by_user_id = current Student
File category = student_submission
not removed
AnswerFile -> AttemptAnswer
Attempt belongs to current Student
AssessmentStudent belongs to current Student
Question belongs to Attempt Assessment
Question.type = file_based
Assessment.type matches detail table
```

## 33.4 Teacher remains denied

Do not expand Teacher download of Student submissions in Stage 8.

Teacher access remains unavailable until the later checking/review stage explicitly owns it.

A Teacher probing Student submission UUID:

```text
404 resource_not_found
```

as currently designed.

---

# 34. Protected Download Query Structure

Refactor the current Homework-only ownership query without losing Tenant-first filtering.

Do not inner-join only `homework_assignments`.

Use an explicit type/detail branch:

```text
assessment.type = homework
AND matching homework_assignments row
AND status in (active, closed, archived)
```

OR:

```text
assessment.type = blitz
AND matching blitz_tasks row
AND status in (active, closed, archived)
```

Every branch remains same-Institution scoped.

Do not broaden to arbitrary Assessment types.

---

# 35. Blitz Start/Resume Resource — Saved Answers

BE-005 intentionally starts with Question visibility after Start.

BE-006 must extend the canonical:

```text
StudentBlitzAttemptResource
```

to include:

```json
"answers": [
  {
    "question_id": "uuid",
    "type": "short_written",
    "answer": {
      "text": "DNS"
    },
    "updated_at": "2026-09-14T18:00:00Z"
  }
]
```

Only persisted answers are listed.

Unanswered Questions have no fabricated answer entry.

Use:

```text
StudentAttemptAnswerStateResource
```

for each saved answer.

Ordering:

```text
Question position
then Question ID
```

or the delivered Question order, with answer states projected in that same order.

---

# 36. Resume Projection Integrity

The BE-005 internal:

```text
ShowStudentBlitzAttempt
```

or exact equivalent must:

1. load authorized current Questions;
2. derive Student-safe `answer_ui`;
3. load current Attempt answers;
4. validate persisted typed/file integrity;
5. attach canonical answer values;
6. return:
   - Attempt timing;
   - Questions;
   - saved Answers.

Do not expose checking fields/answer keys.

If persisted answer references a Question outside the authorized current Assessment Question set:

```text
LogicException
```

Do not hide corrupted data.

---

# 37. Answer Mutation Response

Successful PUT returns exactly one canonical answer state:

```json
{
  "data": {
    "question_id": "question-uuid",
    "type": "multiple_choice",
    "answer": {
      "selected_option_ids": [
        "option-uuid"
      ]
    },
    "updated_at": "2026-09-14T18:01:00Z"
  }
}
```

Clear response:

```json
{
  "data": {
    "question_id": "question-uuid",
    "type": "multiple_choice",
    "answer": null,
    "updated_at": null
  }
}
```

No success message is required if the existing shared Stage 7 endpoint currently returns resource-only.

Preserve its current response envelope/status.

Expected HTTP:

```text
200 OK
```

---

# 38. No Checking / No Score Leakage

Neither answer mutation nor Start/Resume projection returns:

```text
checking_status
awarded_points
feedback
checked_by_user_id
checked_at
earned_points
normalized_score
is_correct
correct_value
accepted_answers
correct_position
match_key
```

The Student-safe response may expose only data required to:

- render the Question;
- render the Student's own saved answer;
- continue editing.

---

# 39. Blitz Error Contract

Required Student-facing behavior:

| Condition | Result |
|---|---|
| foreign/unowned Attempt | `404 resource_not_found` |
| wrong/foreign Question | `404 resource_not_found` |
| Blitz/Topic not active | `409 blitz_not_active` |
| own Attempt terminal | `409 attempt_not_editable` |
| own in-progress Attempt at/past deadline | `409 blitz_time_expired` |
| request type != Question type | `422 validation_failed` |
| invalid option/item/blank IDs | `422 validation_failed` |
| multiple-choice selection cap exceeded | `422 selection_limit_exceeded` |
| unsupported file | existing `422 unsupported_file_type` |
| file too large | existing `422 file_too_large` |
| unexpected file storage failure | existing `500 file_upload_failed` |
| corrupt saved answer graph exposed as business state | `409 business_conflict` where existing Stage 7 pattern uses it |

Do not invent:

```text
submission_locked
blitz_answer_locked
```

in this task.

---

# 40. Request Validation Must Stay Assessment-Type Neutral

The shared:

```text
StudentAttemptAnswerRequest
```

does not inspect Homework/Blitz lifecycle.

It validates only wire shape.

Persisted-state decisions remain in Actions.

Do not query database from Form Request to decide Assessment type.

---

# 41. Concurrency — Two Answer Writes Same Question

Concurrent writes to the same:

```text
Attempt + Question
```

serialize through:

```text
Attempt row
existing AttemptAnswer row
```

Final state is one complete valid canonical answer.

No duplicate `attempt_answers` row.

No mixed typed child payload.

Whichever transaction commits last after observing the lock becomes the current answer, unless a finalization commits first.

---

# 42. Concurrency — Different Questions Same Attempt

The Attempt exclusive lock intentionally serializes Student mutations for one live Blitz Attempt.

This favors correctness/finalization ordering over high write parallelism.

Do not weaken Attempt locking to gain concurrent per-question writes.

Blitz is short-lived and correctness of deadline/finalization is authoritative.

---

# 43. Concurrency — Answer vs Deadline Boundary

Freeze time/barriers in focused tests.

Required valid outcomes:

## Mutation locks Attempt before deadline and commits before finalizer

```text
answer commits
later finalizer freezes it
```

## Mutation waits and observes `server_now >= deadline_at`

```text
zero answer mutation
409 blitz_time_expired
```

BE-006 itself does not finalize.

The test may use controlled lock timing rather than a public finalizer that does not exist yet.

---

# 44. Concurrency — File vs Deadline Boundary

Same rule as typed answer, plus blob compensation.

If file mutation loses eligibility after upload staging:

- no DB replacement;
- previous answer/file remains current;
- staged new blob deleted best-effort;
- no old blob deletion.

---

# 45. Future Submit/Close/Timeout Compatibility

BE-007/BE-008 will acquire the same decisive:

```text
AssessmentAttempt
```

row lock before finalization.

BE-006 must not introduce a different terminal-write lock order.

Required future invariant:

```text
Student answer/file write
vs
Submit/timeout/Teacher Close
=
one serialized Attempt history
```

No additional event bus/listener is needed.

---

# 46. Expected File Scope

Exact filenames may follow delivered dependency names.

## Create

```text
backend/app/Actions/Student/SaveStudentAttemptAnswer.php
backend/app/Actions/Student/SaveStudentBlitzAttemptAnswer.php
backend/app/Actions/Student/SaveStudentBlitzFileAnswer.php

backend/app/Support/Student/StudentAttemptAnswerTarget.php
backend/app/Support/Student/StudentAttemptAnswerMutationResult.php

backend/app/Http/Controllers/Api/V1/Student/StudentAttemptAnswerController.php
backend/app/Http/Requests/Student/StudentAttemptAnswerRequest.php

backend/tests/Feature/Student/StudentBlitzAnswerSaveApiTest.php
backend/tests/Feature/Student/StudentBlitzAnswerValidationTest.php
backend/tests/Feature/Student/StudentBlitzAnswerLifecycleTest.php
backend/tests/Feature/Student/StudentBlitzAnswerConcurrencyTest.php
backend/tests/Feature/Student/StudentBlitzFileAnswerApiTest.php
backend/tests/Feature/Student/StudentBlitzFileAnswerLifecycleTest.php
backend/tests/Feature/Student/StudentBlitzFileAnswerConcurrencyTest.php
backend/tests/Feature/Student/StudentBlitzSubmissionFileDownloadTest.php
```

## Rename/remove narrow route-boundary classes

Replace:

```text
StudentHomeworkAttemptAnswerController
StudentHomeworkAttemptAnswerRequest
StudentHomeworkAttemptAnswerMutationResult
```

with the type-neutral classes above.

## Modify

```text
backend/routes/api.php

backend/app/Actions/Student/SaveStudentHomeworkAttemptAnswer.php
backend/app/Actions/Student/SaveStudentHomeworkFileAnswer.php

backend/app/Support/Student/StudentHomeworkAttemptAnswerStates.php
backend/app/Http/Resources/Student/StudentAttemptAnswerStateResource.php

delivered S08-BE-005:
backend/app/Actions/Student/ShowStudentBlitzAttempt.php
backend/app/Http/Resources/Student/StudentBlitzAttemptResource.php
and only directly required Blitz access/support files

backend/app/Support/Files/ProtectedStudentSubmissionAccess.php
```

If delivered BE-005 names differ, modify the exact equivalents and report them.

Do not modify:

```text
migrations
Teacher Blitz Actions
Question persistence
Submit actions
Scheduler
frontend
docs
tasks
seeders
dependencies
```

---

# 47. Typed Answer API Tests

`StudentBlitzAnswerSaveApiTest` must cover at least:

- single choice create/replace;
- multiple choice create/replace/clear;
- true/false create/replace;
- short written exact-text preservation/clear;
- open written exact-text preservation/clear;
- matching partial/replace/clear;
- ordering partial/replace/clear;
- fill-in-blank partial/replace/clear;
- exact no-op timestamp stability;
- answer remains pending/unscored;
- normalized child rows exact;
- one AttemptAnswer per Attempt/Question;
- response canonical state;
- no correct-answer/checking leakage.

Use parameterized/data-provider coverage where practical.

---

# 48. Typed Validation Tests

`StudentBlitzAnswerValidationTest` covers:

- strict JSON object;
- no query params;
- unknown fields;
- malformed nested shapes;
- wrong `type`;
- wrong Question;
- foreign option/item/blank;
- duplicate IDs;
- single choice cardinality;
- multiple choice selection cap;
- ordering position bounds/duplicates;
- fill blank empty provided text;
- short/open max length;
- protected field attempts;
- file type through JSON rejected.

Ensure privacy-safe 404 is not converted to validation when the direct Question itself is inaccessible.

---

# 49. Typed Lifecycle Tests

`StudentBlitzAnswerLifecycleTest` covers:

- active Topic + active Blitz + own in-progress Attempt before deadline -> success;
- synchronized Attempt before deadline;
- individual Attempt before deadline;
- Topic no longer active -> blitz_not_active;
- Blitz closed -> blitz_not_active;
- Blitz archived -> blitz_not_active;
- Blitz scheduled/draft structural fixture -> blitz_not_active;
- terminal own Attempt -> attempt_not_editable;
- exact deadline -> blitz_time_expired;
- after deadline -> blitz_time_expired;
- expired write performs no timeout finalization in BE-006;
- expired write performs no answer changes.

---

# 50. Typed Concurrency Tests

`StudentBlitzAnswerConcurrencyTest` covers:

- two writes same Question;
- two writes different Questions still serialize safely;
- clear racing replace;
- mutation crossing deadline boundary;
- controlled terminal-state winner blocks later mutation;
- no duplicate/gap/cross-family typed rows.

Do not implement public Submit/Close merely to test concurrency.

---

# 51. File Answer API Tests

`StudentBlitzFileAnswerApiTest` covers:

- first PDF upload;
- DOCX;
- PPT;
- PPTX;
- type/MIME agreement;
- effective size limit;
- canonical response with File ID/name/extension/size;
- private File category;
- Student uploader ownership;
- stable File ID on changed replacement;
- old blob cleanup after commit;
- identical replacement DB no-op and new blob cleanup;
- checking remains pending/null score metadata;
- no additional AnswerFile relation.

Use the existing storage fake/test infrastructure.

---

# 52. File Lifecycle Tests

`StudentBlitzFileAnswerLifecycleTest` covers:

- valid active write;
- terminal Attempt rejected;
- Blitz not active rejected;
- exact/after deadline rejected;
- staged blob cleaned on rejection;
- previous valid file remains current after failed replacement;
- setting lowered during operation causes rejection;
- DB rollback cleans staged blob.

---

# 53. File Concurrency Tests

`StudentBlitzFileAnswerConcurrencyTest` covers:

- two replacements same Question;
- file vs typed impossible type mismatch remains safe;
- file write crossing deadline;
- file write vs controlled terminal finalization;
- one stable File identity;
- one AnswerFile relation;
- no staged orphan treated as current;
- final DB/blob mapping internally consistent.

---

# 54. Student Submission Download Tests

`StudentBlitzSubmissionFileDownloadTest` covers:

- Student can download own active Blitz file;
- own closed Blitz historical file;
- own archived Blitz historical file;
- another Student cannot;
- another Institution cannot;
- Teacher cannot;
- wrong/non-file Question graph cannot authorize;
- foreign/broken recipient graph cannot authorize;
- Draft/Scheduled Blitz cannot authorize;
- existing Homework submission download remains unchanged.

Verify:

```text
Cache-Control: private, no-store
X-Content-Type-Options: nosniff
safe Content-Disposition
```

through existing protected download behavior where already tested.

---

# 55. Start/Resume Saved-Answer Tests

Extend delivered BE-005 focused tests to prove:

1. Start Blitz Attempt;
2. save multiple typed/file answers;
3. call Start again with a new valid key while Attempt remains in progress;
4. receive same Attempt;
5. Questions still Student-safe;
6. `answers` contains only saved Questions;
7. canonical saved values exact;
8. file answer exposes safe File metadata only;
9. unanswered Questions have no answer entry;
10. deadline unchanged.

This is required resume functionality.

---

# 56. Direct BE-005 Regression

Run delivered focused tests for:

```text
StudentBlitzReadApiTest
StudentBlitzAttemptStartTest
StudentBlitzAttemptStartIdempotencyTest
StudentOfficialBlitzAttemptStartTest
```

The exact delivered equivalents are acceptable.

BE-006 must not break:

- pre-Start Question secrecy;
- Start timing;
- resume timing;
- pair lock;
- idempotency.

---

# 57. Homework Answer Regression

Because the shared route/controller/request/result boundary changes, run the delivered Stage 7 answer block:

```bash
php artisan test \
  tests/Feature/Student/StudentHomeworkAnswerSaveApiTest.php \
  tests/Feature/Student/StudentHomeworkAnswerValidationTest.php \
  tests/Feature/Student/StudentHomeworkAnswerLifecycleTest.php \
  tests/Feature/Student/StudentHomeworkAnswerConcurrencyTest.php
```

No existing assertion may be weakened.

---

# 58. Homework File Regression

Run:

```bash
php artisan test \
  tests/Feature/Student/StudentHomeworkFileAnswerApiTest.php \
  tests/Feature/Student/StudentHomeworkFileAnswerLifecycleTest.php \
  tests/Feature/Student/StudentHomeworkFileAnswerConcurrencyTest.php
```

Preserve:

- upload semantics;
- stable File identity;
- compensation;
- download ownership;
- deadline reconciliation behavior.

---

# 59. Protected File Regression

Run the existing focused protected-file tests that cover:

```text
learning materials
Student submission files
cross-role/Tenant denial
```

Use the exact delivered filenames and report the exact command.

Do not run the whole backend suite.

---

# 60. Verification Commands

Run from:

```text
backend/
```

## 60.1 New Blitz typed/file tests

```bash
php artisan test \
  tests/Feature/Student/StudentBlitzAnswerSaveApiTest.php \
  tests/Feature/Student/StudentBlitzAnswerValidationTest.php \
  tests/Feature/Student/StudentBlitzAnswerLifecycleTest.php \
  tests/Feature/Student/StudentBlitzAnswerConcurrencyTest.php \
  tests/Feature/Student/StudentBlitzFileAnswerApiTest.php \
  tests/Feature/Student/StudentBlitzFileAnswerLifecycleTest.php \
  tests/Feature/Student/StudentBlitzFileAnswerConcurrencyTest.php \
  tests/Feature/Student/StudentBlitzSubmissionFileDownloadTest.php
```

## 60.2 Direct BE-005 regression

```bash
php artisan test \
  tests/Feature/Student/StudentBlitzReadApiTest.php \
  tests/Feature/Student/StudentBlitzAttemptStartTest.php \
  tests/Feature/Student/StudentBlitzAttemptStartIdempotencyTest.php \
  tests/Feature/Student/StudentOfficialBlitzAttemptStartTest.php
```

Use actual delivered filenames where they differ.

## 60.3 Homework typed answer regression

```bash
php artisan test \
  tests/Feature/Student/StudentHomeworkAnswerSaveApiTest.php \
  tests/Feature/Student/StudentHomeworkAnswerValidationTest.php \
  tests/Feature/Student/StudentHomeworkAnswerLifecycleTest.php \
  tests/Feature/Student/StudentHomeworkAnswerConcurrencyTest.php
```

## 60.4 Homework file regression

```bash
php artisan test \
  tests/Feature/Student/StudentHomeworkFileAnswerApiTest.php \
  tests/Feature/Student/StudentHomeworkFileAnswerLifecycleTest.php \
  tests/Feature/Student/StudentHomeworkFileAnswerConcurrencyTest.php
```

## 60.5 Protected file regression

Run the current exact focused protected-file tests.

## 60.6 Format

```bash
./vendor/bin/pint --test
```

No additional static-analysis command is required unless current repository configuration makes one mandatory for exactly the changed backend scope.

## 60.7 Always

From repository root:

```bash
git diff --check
```

Do not run:

- full backend suite;
- frontend tests;
- Flutter analyze/build;
- broad E2E.

Full backend regression belongs to:

```text
S08-BE-PHASE-2
```

---

# 61. Acceptance Criteria — Shared Route

- [ ] Existing canonical answer URL remains unchanged.
- [ ] No Homework/Blitz-specific route duplicate added.
- [ ] Own Attempt type is privacy-safely dispatched.
- [ ] Homework path preserves delivered behavior.
- [ ] Blitz path uses Blitz lifecycle/deadline rules.
- [ ] Shared request remains strict and Assessment-type neutral.
- [ ] Type-neutral mutation result/resource boundary exists.

---

# 62. Acceptance Criteria — Blitz Typed Answers

- [ ] All eight non-file types save/replace correctly.
- [ ] Exact Stage 7 request semantics reused.
- [ ] Complete replacement, not nested merge.
- [ ] Allowed semantic empty payload removes Answer row.
- [ ] No placeholder unanswered row.
- [ ] Semantic no-op does not churn timestamps.
- [ ] Same-Question child ownership enforced.
- [ ] Multiple-choice cap enforced without answer-key leakage.
- [ ] Exact Student text preserved.
- [ ] Every saved answer remains pending/unscored.

---

# 63. Acceptance Criteria — Blitz File Answers

- [ ] File-based multipart supported on same route.
- [ ] PDF/DOCX/PPT/PPTX only.
- [ ] Server content inspection reused.
- [ ] Current effective upload limit enforced twice/under current setting.
- [ ] Private storage only.
- [ ] First upload creates one Answer/File/AnswerFile graph.
- [ ] Replacement preserves File ID.
- [ ] Identical replacement is DB no-op.
- [ ] Old blob deleted only after successful commit.
- [ ] Failed/late staged blob compensated.
- [ ] No file/checking/score leakage.

---

# 64. Acceptance Criteria — Execution Eligibility

- [ ] Only own assigned Blitz Attempt.
- [ ] Topic and Blitz must still be active.
- [ ] Attempt must be in progress.
- [ ] Attempt deadline must be non-null.
- [ ] Exact deadline is expired.
- [ ] Expired write returns blitz_time_expired.
- [ ] BE-006 does not timeout-finalize.
- [ ] Terminal Attempt returns attempt_not_editable.
- [ ] Device time cannot affect write eligibility.

---

# 65. Acceptance Criteria — Resume / Private Files

- [ ] Blitz Start/Resume resource returns saved `answers`.
- [ ] Only saved Questions receive answer entries.
- [ ] Questions remain Student-safe.
- [ ] Own Blitz submission file downloadable through existing protected route.
- [ ] Another Student/Tenant/Teacher denied.
- [ ] Closed/Archived own Blitz file remains available historically.
- [ ] Existing Homework protected-file behavior unchanged.

---

# 66. Acceptance Criteria — Concurrency

- [ ] Same Question writes serialize.
- [ ] Different Question writes share Attempt serialization.
- [ ] No duplicate AttemptAnswer.
- [ ] No mixed typed payload family.
- [ ] Answer vs future finalization lock order is compatible.
- [ ] File rejection never destroys prior valid file.
- [ ] No Student mutation can commit after terminal finalization wins.
- [ ] Deadline-crossing mutation cannot commit after authoritative deadline check.

---

# 67. Scope Acceptance

- [ ] No migration.
- [ ] No Blitz Submit.
- [ ] No timeout engine.
- [ ] No Scheduler.
- [ ] No Teacher Close.
- [ ] No exception grant/replacement Attempt.
- [ ] No monitoring.
- [ ] No checking/scoring.
- [ ] No frontend/docs/task changes.
- [ ] Focused Blitz tests pass.
- [ ] BE-005 regression passes.
- [ ] Homework answer/file regressions pass.
- [ ] Protected file regressions pass.
- [ ] Pint passes.
- [ ] `git diff --check` passes.

---

# 68. Focused Diff Self-Check

Before completion confirm:

```text
shared Student answer route
+
Blitz typed/file save-replace
+
own private file resume/download
```

Verify specifically:

```text
deadline checked from AssessmentAttempt.deadline_at
no timeout finalization
checking_status remains pending
stable File ID on replace
Questions still hidden before Start
answers visible only in Attempt Start/Resume projection
Teacher still cannot download Student submissions
```

Confirm no unrelated refactor.

---

# 69. Delivery Report

Codex must report:

1. implementation summary;
2. exact changed files and purpose;
3. shared route/controller/request dispatch behavior;
4. Blitz typed answer lifecycle/deadline guard;
5. typed normalization/clear/no-op behavior;
6. file upload/replace/compensation behavior;
7. private Student submission download extension;
8. Start/Resume saved-answer projection;
9. concurrency/future-finalization behavior;
10. focused Blitz answer test results;
11. BE-005 regression results;
12. Homework typed-answer regression results;
13. Homework file regression results;
14. protected-file regression results;
15. Pint result;
16. `git diff --check`;
17. final `git status --short`;
18. focused scope/diff self-check;
19. any blocker/deviation.

Do not claim Stage 8 backend complete.

After delivery ChatGPT performs read-only acceptance review.

`S08-BE-007` remains blocked until:

```text
S08-BE-006 = Accepted / Delivered
```

---

# 70. Implementation Readiness Verdict

```text
Scope / non-goals                    = RESOLVED
Canonical shared answer route        = RESOLVED
Homework/Blitz dispatch              = RESOLVED
Strict request contract              = RESOLVED
Eight typed answer semantics         = RESOLVED
File answer semantics                = RESOLVED
Question/child ownership             = RESOLVED
Blitz lifecycle guard                = RESOLVED
Authoritative deadline guard         = RESOLVED
Timeout-engine boundary              = RESOLVED
Pending checking/scoring boundary    = RESOLVED
Typed replace/clear/no-op             = RESOLVED
File stable identity                 = RESOLVED
Storage compensation                 = RESOLVED
Private download authorization       = RESOLVED
Start/Resume answer projection       = RESOLVED
Concurrency/finalization compatibility = RESOLVED
Tenant/security boundary             = RESOLVED
Error behavior                       = RESOLVED
Acceptance criteria                  = RESOLVED
Focused verification                 = RESOLVED

Implementation Readiness Gate        = PASS
Execution dependency                 = S08-BE-005 Accepted / Delivered
```
