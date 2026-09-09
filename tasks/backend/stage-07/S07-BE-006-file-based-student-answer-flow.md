# Codex Implementation Contract: S07-BE-006 — File-Based Student Answer Flow

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S07-BE-006` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Backend` |
| Status | `Approved` |
| Implementation type | `Private Student submission upload/replace/read/download for file_based Homework Questions` |
| Depends on | `S07-BE-001…005` — all `Accepted / Delivered` before implementation |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Implementation baseline | ChatGPT re-checks/freezes current `origin/main` immediately before Codex starts |
| Readiness Gate | `PASS`, conditional on dependencies above |
| Verification | focused Student file-answer/storage/download/concurrency verification only |
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
4. delivered `S07-BE-001…005` source/tests directly required here;
5. existing private-file infrastructure:
   - `PrivateFileStorage`;
   - `LearningMaterialFileInspector`;
   - learning-material upload/replace actions and tests;
   - protected file download controller/action/access and tests;
6. current `File`, `FileCategory`, `FileExtension`, `InstitutionSetting`;
7. current Student Attempt answer request/action/resource/access from BE-005.

Do not read roadmap/product/architecture/database/API docs, previous task files, Stage history/indexes/closure reviews, frontend, or unrelated modules to determine requirements.

This contract resolves:

- exact upload endpoint behavior;
- multipart shape;
- accepted formats;
- content/filename/extension inspection;
- effective size limit;
- storage key;
- first upload vs replacement;
- DB/blob compensation;
- answer/file identity behavior;
- deadline/lifecycle behavior;
- Student resume representation;
- protected download authorization;
- tenant isolation;
- no-op behavior;
- concurrency;
- tests and verification.

If delivered dependencies materially conflict with this contract, return `BLOCKED` with exact evidence. Do not redesign.

---

# 3. Goal

Extend the existing Student answer endpoint:

```text
PUT /api/v1/student/attempts/{attempt}/answers/{question}
```

so a `file_based` Question may persist exactly one private Student submission file.

Required capabilities:

```text
first upload
replace existing uploaded file
resume/read saved file metadata
download own saved file through protected endpoint
```

Storage must reuse:

```text
files
answer_files
PrivateFileStorage
GET /api/v1/files/{file}/download
```

No public/signed storage URL.

No file grading occurs in Stage 7.

---

# 4. Explicit Non-Goals

Do not implement:

- more than one file per Question answer;
- a new file table/storage subsystem;
- public/signed URLs;
- cloud-provider-specific direct upload;
- chunked/resumable upload protocol;
- virus-scanning service/package;
- Student file-answer delete/clear endpoint;
- Teacher download/review of Student submission files;
- Parent/Admin/Platform download of Student submissions;
- final Attempt Submit;
- checking/scoring;
- official score/result;
- Blitz;
- frontend;
- E2E/seeders;
- schema migration;
- docs/task bookkeeping;
- new package/dependency;
- unrelated refactor.

For Stage 7 MVP, once a file answer exists it can be **replaced** while editable but not cleared to unanswered. A Student who never uploads a file remains unanswered.

---

# 5. Reuse Existing File Format Contract

Allowed file formats remain exactly:

```text
pdf
docx
ppt
pptx
```

Do not create a second signature/MIME parser.

Reuse the existing:

```text
LearningMaterialFileInspector
```

for Student submissions because the binary-format contract is intentionally identical.

Despite its historical class name, it already owns the exact required content inspection:

- PDF signature;
- DOCX OOXML structure;
- PPTX OOXML structure;
- legacy PPT OLE PowerPoint stream;
- original filename extension must match detected content type;
- SHA-256 checksum;
- canonical MIME from detected extension.

Do not trust client-declared MIME as file identity.

Persist canonical MIME derived from inspected content.

Do not weaken the inspector.

---

# 6. Student Submission Upload Policy

Create:

```text
backend/app/Support/Files/StudentSubmissionUploadPolicy.php
```

Constants:

```text
BYTES_PER_MIB = 1_048_576
PLATFORM_MAX_SIZE_BYTES = 15 * 1_048_576 = 15_728_640
```

Effective limit:

```text
min(
  15_728_640,
  institution_settings.student_submission_max_mb * 1_048_576
)
```

Expose focused methods equivalent to the existing learning-material policy:

```text
maxSizeBytes(InstitutionSetting $setting): int
ensureWithinLimit(int $sizeBytes, int $maxSizeBytes): void
```

Reuse existing:

```text
FileTooLargeException
ApiErrorResponse::fileTooLarge(...)
```

Do not create a second file-too-large error contract.

---

# 7. Request Extension

Modify delivered:

```text
StudentHomeworkAttemptAnswerRequest
```

without changing the BE-005 JSON contracts.

The same route now supports two transport modes.

## 7.1 Non-file types

All eight BE-005 non-file Question types remain:

```text
application/json
```

with exactly their delivered behavior.

No regression.

## 7.2 File-based type

A file-based answer must use:

```text
multipart/form-data
```

Accepted input fields exactly:

```text
type
file
```

No query parameters.

Body fields:

```text
type = file_based
file = UploadedFile
```

Rules:

```text
type required string exactly file_based
file required valid uploaded file
file size > 0
original client filename length <= 500 characters
```

Reject unknown multipart fields.

Do not accept JSON `file_based`.

Do not accept multipart for non-file Question types.

Wrong transport/type:

```text
422 validation_failed
```

## 7.3 Question type match

After route Question resolution, request:

```text
type = file_based
```

must match persisted:

```text
QuestionType::FileBased
```

Otherwise:

```text
422 validation_failed
```

with generic `type` mismatch error.

Do not expose Question answer-key/configuration data.

---

# 8. Preliminary Access Before Blob Storage

Create:

```text
backend/app/Actions/Student/SaveStudentHomeworkFileAnswer.php
```

Before inspecting/storing the blob:

1. resolve authenticated Student's own `{attempt}` using delivered BE-004 access;
2. resolve `{question}` privacy-safely inside:
   - same Institution;
   - same Assessment as Attempt;
   - `type = file_based`;
3. inaccessible/malformed IDs:
   - `404 resource_not_found`;
4. read current Institution setting;
5. inspect upload;
6. apply early effective-size check.

Do not write a storage blob for a target that already fails preliminary authorization.

Current Group membership is not required.

---

# 9. Storage Key

Generate a new storage key for every physical upload:

```text
student-submissions/{institution_id}/{attempt_id}/{question_id}/{uuid}.{extension}
```

Rules:

- use server-generated UUID;
- use canonical inspected extension;
- never use original filename as storage path;
- never accept client storage key/disk/path;
- never expose storage key/disk to API.

Store through:

```text
PrivateFileStorage::store(...)
```

on the configured private disk.

---

# 10. Blob-First Compensation Pattern

Follow the existing learning-material private-storage pattern.

Sequence:

```text
preliminary authorization
-> inspect
-> early size check
-> store new private blob
-> DB transaction with final locks/checks
```

Create one idempotent cleanup closure for the newly stored blob.

It must call:

```text
PrivateFileStorage::deleteBestEffort(...)
```

at most once.

Required compensation:

- DB rollback;
- final locked validation failure;
- deadline rejection;
- task/Attempt non-editable rejection;
- identical-file no-op;
- unexpected exception before successful DB commit.

A failed cleanup is logged by existing `PrivateFileStorage`; do not expose storage internals to Student.

No persistent DB record may reference a failed/rolled-back new blob.

---

# 11. Locked Mutation Order

Inside one DB transaction lock using the BE-005 Student answer chain:

```text
Topic
-> Assessment
-> HomeworkAssignment
-> authenticated Student AssessmentAttempt
-> Question
-> existing AttemptAnswer, if any
-> existing AnswerFile, if any
-> existing File, if any
-> InstitutionSetting
```

Do not lock Group/current membership.

Use deterministic scoped queries.

Do not query File globally before tenant/answer ownership is established.

---

# 12. Final Locked Preconditions

After required parent/Attempt/Question locks, capture:

```text
observedAt = now()
```

Apply the same BE-005 lifecycle rules.

## Homework

```text
draft    => 409 task_not_active
closed   => 409 task_closed
archived => 409 task_archived
active   => continue
```

Inconsistent non-active Topic:

```text
409 task_not_active
```

## Deadline

If:

```text
deadline_at != null
AND observedAt >= deadline_at
```

then:

- commit zero file-answer DB writes;
- clean up the newly uploaded blob;
- invoke delivered BE-002 deadline reconciliation after the file-answer transaction;
- return:

```text
409 deadline_passed
```

Existing saved file answer remains unchanged.

## Attempt editability

Require:

```text
status = in_progress
finalized_at = null
locked_at = null
```

Otherwise:

```text
409 attempt_not_editable
```

New blob is cleaned up.

---

# 13. Final Locked Size Check

Lock:

```text
institution_settings
```

for the authenticated Student Institution.

If missing:

```text
server invariant failure
```

Recompute current effective:

```text
student_submission_max_mb
```

and run:

```text
StudentSubmissionUploadPolicy::ensureWithinLimit(...)
```

again.

This catches an Institution Admin lowering the limit while the file upload was in progress.

If now too large:

```text
422 file_too_large
```

with current effective limit.

No DB answer change.

New blob cleanup required.

---

# 14. Existing File-Answer Integrity

For an existing `AttemptAnswer` on a `file_based` Question require:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

Required typed structure:

```text
exactly one answer_files row
no non-file typed child rows
```

The linked `File` must have:

```text
same Institution
category = student_submission
uploaded_by_user_id = authenticated Student
removed_at = null
```

If these invariants fail:

```text
409 business_conflict
```

Do not silently repair or erase review/scoring state.

For no existing Answer, there must be no stray `answer_files` relation for that Attempt/Question.

---

# 15. First File Upload

When no persisted answer exists:

capture one real mutation instant:

```text
savedAt = now()
```

Create:

## `attempt_answers`

```text
institution_id = Student Institution
attempt_id = own Attempt
question_id = locked file_based Question
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
created_at/updated_at = savedAt
```

## `files`

Create one row:

```text
institution_id = Student Institution
uploaded_by_user_id = authenticated Student
category = student_submission
original_name = inspected original name
storage_disk = PrivateFileStorage returned disk
storage_key = generated key
mime_type = canonical inspected MIME
extension = canonical inspected FileExtension
size_bytes = inspected size
checksum_sha256 = lowercase SHA-256
removed_at = null
created_at/updated_at = savedAt
```

## `answer_files`

Create:

```text
institution_id = Student Institution
answer_id = new AttemptAnswer ID
file_id = new File ID
created_at = savedAt
```

Commit atomically.

Do not touch parent AssessmentAttempt timestamps/status/score fields.

---

# 16. File Replacement

When an existing valid file answer exists:

preserve identities:

```text
attempt_answers.id
attempt_answers.created_at
answer_files.id
answer_files.created_at
files.id
files.created_at
```

Do not create a second File row.

Capture:

```text
savedAt = now()
```

Save old:

```text
storage_disk
storage_key
```

Update the same `files` row:

```text
original_name
storage_disk
storage_key
mime_type
extension
size_bytes
checksum_sha256
updated_at = savedAt
```

Keep:

```text
institution_id
uploaded_by_user_id
category = student_submission
removed_at = null
```

Update:

```text
attempt_answers.updated_at = savedAt
```

Do not rewrite `answer_files`.

After DB commit only:

```text
deleteBestEffort(oldDisk, oldStorageKey, "student_submission_replace_old_blob_cleanup", fileId)
```

If DB transaction fails:

- old File row/blob remains authoritative;
- new blob is compensation-deleted.

---

# 17. Exact-Binary No-Op

A replacement upload is semantically identical only when all are equal to current persisted File:

```text
checksum_sha256
size_bytes
extension
mime_type
original_name
```

If identical:

- return `200`;
- no DB row/timestamp changes;
- preserve existing File/Answer IDs;
- clean up the newly uploaded duplicate blob best-effort;
- do not delete the currently referenced old blob.

If bytes are the same but `original_name` differs, treat as a real replacement because display metadata changed.

---

# 18. No File Clear in BE-006

The endpoint does not accept an empty/absent file as clear.

For:

```text
type = file_based
```

`file` is always required.

Do not delete an existing file answer merely because multipart parsing failed or the client omitted the file.

A future explicit removal feature would require its own contract.

---

# 19. File Answer Response

Extend delivered:

```text
StudentAttemptAnswerStateResource
```

for `file_based`.

PUT success:

```json
{
  "data": {
    "question_id": "question-uuid",
    "type": "file_based",
    "answer": {
      "file": {
        "id": "file-uuid",
        "original_name": "homework.pptx",
        "extension": "pptx",
        "size_bytes": 1048576
      }
    },
    "updated_at": "2026-09-08T12:10:00Z"
  }
}
```

Do not return:

```text
storage_disk
storage_key
mime_type
checksum_sha256
uploaded_by_user_id
institution_id
removed_at
```

No public URL is required.

Client downloads through existing:

```text
GET /api/v1/files/{file}/download
```

using the returned File ID.

---

# 20. Extend Attempt Resume Read

Modify delivered BE-005:

```text
ShowStudentHomeworkAttempt
StudentHomeworkAttemptResource
StudentAttemptAnswerStateResource
```

to include saved file-based answers in the existing:

```text
answers
```

array.

File state uses the exact metadata shape from Section 19.

Unanswered file-based Questions have no fabricated answer entry.

Do not read blob bytes merely to serialize Attempt state.

No storage path/disk/checksum leakage.

---

# 21. Controller Dispatch

Modify delivered:

```text
StudentHomeworkAttemptAnswerController
```

Keep it thin.

Transport dispatch is allowed:

```text
type = file_based
  -> SaveStudentHomeworkFileAnswer

all delivered non-file types
  -> SaveStudentHomeworkAttemptAnswer
```

This dispatch is not business-rule ownership; each Action owns its full domain logic.

Do not duplicate the non-file action inside the file action.

Do not make the Controller perform tenant/deadline/storage decisions.

---

# 22. Protected Download Dispatcher

The existing route:

```text
GET /api/v1/files/{file}/download
```

must remain unchanged.

Current middleware remains:

```text
auth:sanctum
active.account
password.changed
role:teacher,student
```

Create:

```text
backend/app/Actions/Files/DownloadProtectedFile.php
```

Modify:

```text
ProtectedFileDownloadController
```

to invoke this dispatcher instead of directly invoking only `DownloadLearningMaterialFile`.

## Dispatcher behavior

Validate UUID.

Look up only:

```text
files.institution_id = actor.institution_id
files.id = fileId
files.removed_at IS NULL
```

selecting:

```text
category
```

Then:

```text
learning_material
  -> existing DownloadLearningMaterialFile

student_submission
  -> new DownloadStudentSubmissionFile
```

Unknown/inaccessible:

```text
404 resource_not_found
```

Category discovery is internal only.

Do not expose File category to unauthorized clients.

Existing learning-material download behavior must remain unchanged.

---

# 23. Student Submission Download Action

Create:

```text
backend/app/Actions/Files/DownloadStudentSubmissionFile.php
backend/app/Support/Files/ProtectedStudentSubmissionAccess.php
```

Use existing:

```text
PrivateFileStorage
ProtectedFileDownload
```

## 23.1 Allowed actor in Stage 7

Only:

```text
role = student
```

and only the Student who owns the Attempt/file answer.

A Teacher hitting a Student submission File ID receives:

```text
404 resource_not_found
```

Teacher review/download is deferred to Stage 9.

Parent/Admin/Platform are already outside route middleware and are not added.

## 23.2 Ownership query

Resolve only when the complete persisted chain holds:

```text
files:
  institution_id = student.institution_id
  id = requested file
  category = student_submission
  removed_at IS NULL

answer_files:
  same institution
  file_id = files.id

attempt_answers:
  same institution
  id = answer_files.answer_id

assessment_attempts:
  same institution
  id = attempt_answers.attempt_id
  student_id = authenticated Student

assessment_students:
  same institution
  id = assessment_attempts.assessment_student_id
  assessment_id = assessment_attempts.assessment_id
  student_id = authenticated Student

questions:
  same institution
  id = attempt_answers.question_id
  assessment_id = assessment_attempts.assessment_id
  type = file_based

assessments:
  same institution
  id = assessment_attempts.assessment_id
  type = homework

homework_assignments:
  same institution
  assessment_id = assessments.id
  status in (active, closed, archived)
```

Current Group membership is not required.

This lets a Student download their own historical submitted file after later membership changes.

## 23.3 Privacy

Malformed UUID, another Student, foreign Institution, Teacher direct ID, wrong category, unlinked File, removed File:

```text
404 resource_not_found
```

No existence disclosure.

---

# 24. Download Lock / Replacement Race

`ProtectedStudentSubmissionAccess` preliminary resolution may use a scoped join.

Before opening the stream, lock the same tenant File row:

```text
FOR UPDATE
```

and re-verify it is still:

```text
category = student_submission
removed_at = null
```

and still linked through the same authorized answer chain.

The download path does not need to lock parent Homework/Attempt rows; it performs no domain mutation.

This avoids reverse lock dependencies.

A concurrent replacement updates the same File row and therefore serializes with download stream opening.

Once the stream is opened, the existing controller owns/finishes that stream even if later replacement cleans the old blob.

---

# 25. Download Headers

Preserve existing protected-download response behavior:

```text
Content-Type = stored canonical MIME
Content-Disposition = attachment with sanitized filename
Cache-Control = private, no-store
X-Content-Type-Options = nosniff
```

Reuse existing filename sanitization/fallback logic in:

```text
ProtectedFileDownloadController
```

Do not add inline rendering.

Do not expose storage path.

---

# 26. MIME / Extension / Filename Rules

Persisted values come only from inspected upload:

```text
extension
mime_type
checksum_sha256
size_bytes
```

The original client filename:

- is display metadata only;
- max length 500;
- must have extension matching inspected binary format;
- is never used as storage key;
- may contain Unicode;
- download controller sanitizes unsafe control/path characters.

Client-declared MIME must not override canonical inspected MIME.

---

# 27. File Errors

Reuse existing errors/mappings:

## Unsupported binary/extension mismatch

```text
422 unsupported_file_type
```

## Effective size exceeded

```text
422 file_too_large
```

with effective bytes in existing error detail.

## Storage write failure

```text
500 file_upload_failed
```

## Stored blob unavailable on download

```text
500 file_not_available
```

## Strict multipart/request errors

```text
422 validation_failed
```

## Lifecycle/deadline/non-editable

Reuse delivered Student errors:

```text
task_not_active
task_closed
task_archived
deadline_passed
attempt_not_editable
business_conflict
```

No raw filesystem exception/path is exposed.

---

# 28. Storage / DB Atomicity Guarantees

Because filesystem/object storage is not part of the PostgreSQL transaction, the contract is compensating, not distributed-transactional.

Required guarantees:

## First upload

If DB commit succeeds:

```text
1 referenced File row
1 AnswerFile row
1 private blob
```

If DB fails:

```text
no File/AnswerFile/AttemptAnswer commit
new blob cleanup attempted
```

## Replacement

If DB commit succeeds:

```text
same File ID now references new blob
old blob cleanup attempted after commit
```

If DB fails:

```text
old DB/File/blob remain authoritative
new blob cleanup attempted
```

## Cleanup failure

A best-effort blob deletion failure may leave an unreferenced physical blob, but must:

- never leave an incorrect DB reference;
- be logged only with safe operation/File ID metadata;
- never expose path/content to API.

Do not invent a queue/outbox garbage-collector system in this task.

---

# 29. Concurrency

The authenticated Attempt lock from BE-005 remains the answer mutation serialization boundary.

## Two first uploads

Concurrent uploads for same Attempt/Question:

- both may temporarily store separate blobs;
- DB mutation serializes;
- first creates stable Answer/File IDs;
- second then replaces that same File row;
- final DB has exactly:
  - one AttemptAnswer;
  - one AnswerFile;
  - one File row;
- superseded blob cleanup is attempted.

## Two replacements

Final DB/File metadata corresponds to one complete committed replacement, never mixed fields.

## Upload vs Teacher close

If upload mutation commits first:

- close may then auto-finalize Attempt;
- saved file remains frozen.

If close wins first:

- upload DB mutation is rejected;
- newly stored blob cleanup is attempted.

## Upload vs deadline

Only upload whose locked:

```text
observedAt < deadline_at
```

may commit.

At/after deadline:

- no new file DB reference;
- new blob cleanup;
- BE-002 reconciliation;
- `409 deadline_passed`.

---

# 30. Expected Files

## Create

```text
backend/app/Support/Files/StudentSubmissionUploadPolicy.php
backend/app/Support/Files/ProtectedStudentSubmissionAccess.php

backend/app/Actions/Student/SaveStudentHomeworkFileAnswer.php

backend/app/Actions/Files/DownloadProtectedFile.php
backend/app/Actions/Files/DownloadStudentSubmissionFile.php

backend/tests/Feature/Student/StudentHomeworkFileAnswerApiTest.php
backend/tests/Feature/Student/StudentHomeworkFileAnswerLifecycleTest.php
backend/tests/Feature/Student/StudentHomeworkFileAnswerConcurrencyTest.php
backend/tests/Feature/Files/ProtectedStudentSubmissionDownloadApiTest.php
```

## Modify

```text
backend/app/Http/Requests/Student/StudentHomeworkAttemptAnswerRequest.php
backend/app/Http/Controllers/Api/V1/Student/StudentHomeworkAttemptAnswerController.php
backend/app/Http/Resources/Student/StudentAttemptAnswerStateResource.php
backend/app/Actions/Student/ShowStudentHomeworkAttempt.php
backend/app/Http/Resources/Student/StudentHomeworkAttemptResource.php

backend/app/Http/Controllers/Api/V1/Files/ProtectedFileDownloadController.php
```

Modify delivered Student answer access/support only if required for focused reuse of its exact lock/lifecycle logic.

Modify `File` relation only if BE-001 did not already add the direct `answerFile()` relation expected by delivered persistence.

No route path change is required because both affected routes already exist after BE-005/Stage 5.

No migration/docs/frontend/Submit/scoring files.

---

# 31. `StudentHomeworkFileAnswerApiTest`

Use private storage fake/configuration consistent with current learning-material tests.

At minimum cover:

## First upload for each format

Valid real fixture bytes for:

```text
pdf
docx
ppt
pptx
```

Expect:

```text
200
AttemptAnswer pending
File.category = student_submission
File.uploaded_by_user_id = Student
AnswerFile link
private blob exists
```

Response exposes only safe file metadata.

## Filename/content match

Reject:

- PDF bytes named `.docx`;
- DOCX bytes named `.pdf`;
- arbitrary/invalid bytes;
- unsupported extension.

Exact:

```text
422 unsupported_file_type
```

No DB answer/file row and no retained new blob.

## Multipart strictness

Reject:

- JSON file answer;
- wrong content type;
- missing file;
- empty file;
- missing/wrong type;
- unknown field;
- query parameter;
- original name >500.

## Wrong Question

- file upload to non-file Question → `422 validation_failed`;
- another Assessment/Institution Question → privacy-safe `404`.

## Effective size

Verify:

```text
institution limit < 15 MB
```

is enforced.

Also verify platform cap remains 15 MB.

Use controlled metadata/file fixtures without allocating pathological memory.

## Replacement

Upload file A then B.

Verify:

- same AttemptAnswer ID;
- same AnswerFile ID;
- same File ID;
- File metadata points to B;
- B blob exists;
- A blob deletion attempted/removed after commit;
- no second File row.

## Identical no-op

Upload exact same bytes/name again.

Verify:

- `200`;
- DB timestamps unchanged;
- same File ID/storage key remains;
- duplicate newly stored blob cleanup attempted;
- no extra DB row.

---

# 32. `StudentHomeworkFileAnswerLifecycleTest`

At minimum:

## Privacy

Other Student/cross-Institution Attempt:

```text
404
```

No blob stored after preliminary denial.

## Current Group membership removed

Persisted assigned own Attempt remains editable if active/pre-deadline.

## Submitted Attempt

```text
409 attempt_not_editable
```

New blob cleanup required.

Existing file unchanged.

## Closed

```text
409 task_closed
```

## Archived

```text
409 task_archived
```

## Deadline exact/after

- new blob stored preliminarily may exist temporarily;
- final DB answer remains unchanged/uncreated;
- new blob cleanup attempted;
- Attempt is BE-002 deadline-finalized;
- `409 deadline_passed`.

## Setting lowered during upload

Simulate early size pass, then lower `student_submission_max_mb` before final locked check.

Expect:

```text
422 file_too_large
```

No file-answer DB mutation.

New blob cleanup attempted.

## DB failure compensation

Force a safe DB failure after blob storage and before commit.

Verify:

- no new DB reference;
- old replacement state preserved if replacement;
- new blob cleanup attempted.

Do not weaken DB constraints permanently.

---

# 33. `ProtectedStudentSubmissionDownloadApiTest`

At minimum:

## Owner Student

Own saved file:

```text
200
```

Assert bytes equal stored content and headers:

```text
Content-Type
Content-Disposition attachment
Cache-Control private, no-store
X-Content-Type-Options nosniff
```

## Historical own Attempt

After Attempt finalization and after ending current Group membership, owner Student can still download the linked historical file.

## Other Student

Same Institution other Student direct File UUID:

```text
404
```

## Foreign Institution

```text
404
```

## Teacher

Teacher direct Student submission File UUID in Stage 7:

```text
404
```

Do not add Teacher submission access.

## Unlinked File

A `student_submission` File row not linked through AnswerFile/Attempt ownership:

```text
404
```

## Wrong category

Learning material continues to be handled by existing action, not Student submission access.

## Removed/unavailable

Removed File:

```text
404
```

Authorized row with missing underlying blob:

```text
500 file_not_available
```

## Malformed UUID/query/body

Preserve existing protected-download validation/error behavior.

---

# 34. `StudentHomeworkFileAnswerConcurrencyTest`

Use real PostgreSQL process lock-wait style plus fake/local private storage suitable for cross-process verification.

At minimum prove concurrent same Attempt/Question replacements serialize.

Scenario:

1. existing valid file answer A;
2. worker 1 stores B, obtains Attempt mutation lock and holds it;
3. worker 2 stores C and enters a real PostgreSQL lock wait;
4. release worker 1;
5. both finish.

Final DB must have:

```text
1 AttemptAnswer
1 AnswerFile
1 File row
File metadata/storage key correspond to the later committed complete replacement
checking_status = pending
no score fields
```

Superseded blobs must have cleanup attempted according to commit order.

If cross-process storage fake cannot faithfully verify cleanup, use a deterministic local private disk fixture for this test only.

Do not use arbitrary sleeps as synchronization.

---

# 35. Extend Resume / Answer Privacy Tests

Update/extend focused BE-005 tests so:

```text
GET /student/attempts/{attempt}
```

and Start/resume response include:

```json
{
  "question_id": "...",
  "type": "file_based",
  "answer": {
    "file": {
      "id": "...",
      "original_name": "...",
      "extension": "pdf",
      "size_bytes": 1234
    }
  },
  "updated_at": "..."
}
```

Recursively assert no file answer response includes:

```text
storage_disk
storage_key
mime_type
checksum_sha256
uploaded_by_user_id
institution_id
removed_at
```

Do not expose binary content from Attempt GET.

---

# 36. Directly Affected Regression Tests

Run BE-006 tests plus:

```text
tests/Feature/Student/StudentHomeworkAnswerSaveApiTest.php
tests/Feature/Student/StudentHomeworkAnswerValidationTest.php
tests/Feature/Student/StudentHomeworkAnswerLifecycleTest.php
tests/Feature/Student/StudentHomeworkAttemptStartApiTest.php

tests/Feature/Persistence/StudentAnswerSubmissionPersistenceTest.php
tests/Feature/Persistence/StudentAnswerSubmissionFactoryModelTest.php

tests/Feature/Teacher/TeacherLearningMaterialUploadApiTest.php
tests/Feature/Teacher/TeacherLearningMaterialMutationApiTest.php
tests/Feature/Files/ProtectedLearningMaterialDownloadApiTest.php
```

Rationale:

- shared answer route/request/resource is extended;
- BE-001 AnswerFile/File persistence is now live;
- existing file inspector/private storage/download dispatcher must not regress learning-material behavior.

Do not run full backend suite.

---

# 37. Verification

Use the repository's normal Docker/Sail backend command wrapper.

Run required formatter/static check for changed PHP files.

Then exactly:

```bash
php artisan test \
  tests/Feature/Student/StudentHomeworkFileAnswerApiTest.php \
  tests/Feature/Student/StudentHomeworkFileAnswerLifecycleTest.php \
  tests/Feature/Student/StudentHomeworkFileAnswerConcurrencyTest.php \
  tests/Feature/Files/ProtectedStudentSubmissionDownloadApiTest.php \
  tests/Feature/Student/StudentHomeworkAnswerSaveApiTest.php \
  tests/Feature/Student/StudentHomeworkAnswerValidationTest.php \
  tests/Feature/Student/StudentHomeworkAnswerLifecycleTest.php \
  tests/Feature/Student/StudentHomeworkAttemptStartApiTest.php \
  tests/Feature/Persistence/StudentAnswerSubmissionPersistenceTest.php \
  tests/Feature/Persistence/StudentAnswerSubmissionFactoryModelTest.php \
  tests/Feature/Teacher/TeacherLearningMaterialUploadApiTest.php \
  tests/Feature/Teacher/TeacherLearningMaterialMutationApiTest.php \
  tests/Feature/Files/ProtectedLearningMaterialDownloadApiTest.php
```

Then from repository root:

```bash
git diff --check
```

and focused diff/scope self-review.

Do not run:

- full backend suite;
- frontend tests/build;
- broad E2E/integration Stage runner.

---

# 38. Acceptance Criteria

PASS only if all are true.

## Upload

- existing answer PUT supports `file_based` only through strict multipart;
- PDF/DOCX/PPT/PPTX only;
- existing binary inspector reused;
- filename extension matches inspected binary;
- canonical MIME/checksum/size persisted;
- effective institution/platform 15 MB cap enforced twice;
- storage key is server generated/private.

## Persistence

- first upload creates one AttemptAnswer + File + AnswerFile;
- File category is `student_submission`;
- uploader is authenticated Student;
- replacement preserves Answer/AnswerFile/File IDs;
- one file per answer remains enforced;
- no score/checking mutation;
- parent Attempt timestamps/status unchanged.

## Compensation

- rollback/rejection cleans new blob best-effort;
- replacement deletes old blob only after commit;
- identical-file no-op keeps existing DB/blob and cleans duplicate new blob;
- no incorrect DB reference points to failed/rolled-back blob.

## Lifecycle/security

- only own `in_progress` active pre-deadline Attempt is writable;
- current Group membership not required;
- deadline rejection performs cleanup + BE-002 reconciliation;
- cross-tenant/other-Student direct IDs do not leak existence.

## Resume

- saved file metadata appears in Attempt answers;
- no storage internals/checksum leak;
- no binary content in JSON.

## Download

- existing `/files/{file}/download` route remains protected;
- learning material download behavior unchanged;
- Student can download only own linked submission;
- historical own file remains available after finalization/membership change;
- other Student/cross-tenant/Teacher submission download is 404 in Stage 7;
- private/no-store/nosniff headers preserved.

## Concurrency

- concurrent replacements serialize on PostgreSQL Attempt lock;
- final DB has one coherent Answer/File graph;
- superseded blob cleanup is attempted.

## Scope

- no file clear/delete;
- no Teacher review/download of Student submission;
- no Submit/scoring/official result;
- no migration/docs/frontend/E2E;
- no new dependency;
- no duplicate file inspector/storage subsystem.

## Verification

- focused tests pass;
- named regressions pass;
- formatter/static check passes;
- `git diff --check` passes;
- focused self-review passes.

---

# 39. Locked Implementation Decisions

These are decisions, not suggestions:

```text
file_based upload route = existing answer PUT
file_based transport = multipart/form-data
multipart fields = type,file
one file per answer
allowed = pdf,docx,ppt,pptx
binary inspection = existing LearningMaterialFileInspector
client MIME = untrusted
platform max = 15_728_640 bytes
effective max = min(platform, institution setting)
physical storage = existing PrivateFileStorage
storage key = server-generated student-submissions/... UUID path
File.category = student_submission
File.uploaded_by_user_id = Student
replacement preserves File ID
old blob deletion = afterCommit best effort
new blob compensation = rollback/rejection best effort
no file clear in Stage 7
Student owns protected download
Teacher Student-submission download = Stage 9, not BE-006
current Group membership = not required for historical own submission
```

Codex must not substitute:

- public URLs;
- client storage paths;
- a new file table;
- a second MIME/signature parser;
- trusting filename/MIME alone;
- creating a new File row on every replacement;
- deleting old blob before DB commit;
- Teacher access pulled forward;
- scoring/file-content inspection for grading.

---

# 40. Completion Report

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
4. upload/format/limit evidence;
5. compensation/cleanup evidence;
6. protected-download authorization evidence;
7. PostgreSQL concurrency evidence;
8. directly affected regressions;
9. `git diff --check`;
10. scope/non-goal confirmation;
11. deviations/blockers;
12. final `git status --short`.

Do not claim `Accepted`.

Do not commit/push/create PR/update Stage bookkeeping unless explicitly instructed later.
