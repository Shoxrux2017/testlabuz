# Codex Implementation Contract: S07-FE-004 — File Answer UX

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S07-FE-004` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Frontend` |
| Status | `Approved` |
| Implementation type | `Flutter file-based Homework answer select/upload/replace + own protected file open/save UX` |
| Depends on | `S07-FE-003 = Accepted / Delivered`; Stage 7 Backend Phase 2 remains `PASS` |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Current review baseline | `origin/main @ 55528f106288527c2443142022ba5df567d019de` |
| Implementation baseline | ChatGPT re-checks/freezes current `origin/main` immediately before Codex starts |
| Readiness Gate | `PENDING — current-main revalidation by ChatGPT required after this correction is merged` |
| Supported surfaces | `Student desktop + mobile` |
| Verification | focused frontend tests + shared-file regressions + format/analyze + diff check |
| Delivery | Codex: implementation -> focused verification -> final focused scope/diff self-review -> stage task scope only -> `git diff --cached --check` -> commit -> push -> create PR -> stop before merge. Project Owner: merge only after ChatGPT acceptance review. |
| Implementation branch | `implement/s07-fe-004-file-answer-ux` |
| Pre-approved implementation commit | `feat(stage7): add student file answer ux` |
| Frontend block checkpoint | Stage 7 Frontend Phase 2 after `S07-FE-001…005` |

Do not create a duplicate `CODEX-PROMPT`.

Do not update `STAGE_07_TASK_INDEX.md`.

---

# 2. Context Boundary

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. delivered `S07-FE-001…003` Student Homework/Attempt/answer source and focused tests;
5. existing:
   - `file_picker`;
   - Teacher material file-picker/upload transport patterns;
   - `ProtectedLearningMaterialTransfer`;
   - `TrustedDownloadedFile` / protected-download parser;
   - `LocalFileActions`;
   - Student/Teacher protected transfer tests directly affected here;
6. configured Dio/failure/session infrastructure;
7. exact backend file-answer contract reproduced below.

Do not read product docs, roadmap, architecture/database/API docs, previous task files, Stage history, closure reviews, or unrelated modules to determine behavior.

This contract resolves:

- file picker abstraction;
- local filename/extension/size validation;
- multipart PUT transport;
- first upload vs replacement UX;
- upload progress;
- deterministic vs uncertain mutation outcome;
- safe uncertain-upload reconciliation without blind PUT replay;
- parent Attempt reconciliation;
- saved file Open / Save As;
- protected download validation against current saved metadata;
- navigation protection;
- terminal Attempt behavior;
- tests and verification.

If delivered backend or FE-003 materially conflicts with this contract, return `BLOCKED` with exact evidence. Do not redesign.

---

# 3. Goal

Extend the Student Attempt screen so `file_based` Questions support:

```text
Choose file
Upload first answer
Choose replacement
Replace saved answer
Reconcile uncertain upload / retry confirmed storage failure
Open own saved submission
Save own saved submission locally
```

Use the existing backend answer mutation route:

```text
PUT /api/v1/student/attempts/{attempt}/answers/{question}
```

with:

```text
multipart/form-data
```

File answers remain private and are downloaded only through:

```text
GET /api/v1/files/{file}/download
```

Final Homework Submit remains `S07-FE-005`.

---

# 4. Explicit Non-Goals

Do not implement:

- file answer clear/delete;
- multiple files per Question;
- final Homework Submit;
- Submit confirmation/idempotency;
- automatic upload immediately after picking;
- autosave;
- chunked/resumable protocol;
- direct-to-cloud upload;
- public/signed URLs;
- client MIME/security inspection;
- client-side PDF/OOXML/OLE signature parsing;
- checksum computation;
- virus scanning;
- Teacher submission download/review;
- score/checking/review UI;
- offline queue;
- background upload;
- new package/dependency;
- protected-download transport rewrite/rename;
- broad shared file architecture refactor;
- backend/platform changes.

---

# 5. Existing File Infrastructure to Reuse

The current frontend already has:

```text
file_picker
Dio FormData / MultipartFile.fromStream
ProtectedLearningMaterialTransfer
TrustedDownloadedFile
LocalFileActions
open_file
```

Despite the historical class name:

```text
ProtectedLearningMaterialTransfer
```

its transport contract is generic:

```text
fileId
-> GET /files/{fileId}/download
-> validate protected headers/bytes
```

FE-004 must reuse it.

Do not create:

```text
ProtectedStudentSubmissionHttpClient
```

or a duplicate protected download parser.

Do not rename the shared class in this focused task.

---

# 6. Backend File Question Read Contract

From FE-001 safe `answer_ui`:

```json
{
  "allowed_extensions": [
    "pdf",
    "docx",
    "ppt",
    "pptx"
  ],
  "max_size_bytes": 15728640
}
```

The backend-provided current:

```text
max_size_bytes
```

is the effective upload limit at the read instant.

It may be lower than 15 MB.

Flutter local validation uses it for UX only.

Backend re-validates the authoritative current setting at upload time.

---

# 7. Backend File Answer Upload Contract

Endpoint:

```text
PUT /api/v1/student/attempts/{attempt}/answers/{question}
```

Transport:

```text
multipart/form-data
```

Fields exactly:

```text
type = file_based
file = selected upload
```

No query.

No `Idempotency-Key`.

Success:

```text
200
```

Exact mutation response:

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

For `file_based`:

```text
answer is never null on successful PUT
updated_at is never null
```

There is no file clear request.

---

# 8. Relevant Backend File Errors

Stable relevant codes:

```text
404 resource_not_found

409 task_not_active
409 task_closed
409 task_archived
409 deadline_passed
409 attempt_not_editable
409 business_conflict

422 validation_failed
422 unsupported_file_type
422 file_too_large

500 file_upload_failed
```

Download also uses:

```text
500 file_not_available
```

Session/auth errors remain the existing shared contract.

Do not branch on human-readable messages.

---

# 9. Student Upload File Domain

Create:

```text
frontend/lib/features/student/domain/student_submission_upload.dart
```

Define:

```dart
typedef StudentSubmissionUploadProgress =
    void Function(int sent, int total);
```

and:

```text
StudentSubmissionUploadFile:
  name
  length
  openRead
```

where:

```text
openRead = Stream<List<int>> Function()
```

Expose:

```text
extension?
```

from the final filename suffix, lowercased.

Do not store filesystem path in application/domain state.

Do not expose platform file handles outside the picker abstraction.

---

# 10. Selected File Validation Result

Create a typed result/error enum:

```text
StudentSubmissionSelectionError:
  emptyFile
  unsupportedExtension
  tooLarge
  filenameTooLong
  invalidFilename
```

Validation inputs:

```text
StudentSubmissionUploadFile
StudentFileAnswerUi
```

Use backend-safe `answer_ui` as the current local policy.

Do not return human-readable error strings from domain validation.

Presentation maps typed errors to labels.

---

# 11. Local File Validation Rules

A selected file is locally valid only when:

## Name

```text
name is non-empty
name is not "." or ".."
```

The final extension exists.

Filename Unicode code-point length:

```text
<= 500
```

Use:

```dart
name.runes.length
```

to align with the delivered BE-006 backend boundary:

```text
mb_strlen(original_name, 'UTF-8') <= 500
```

Do not use UTF-8 byte length as the acceptance limit; that would incorrectly
reject valid multibyte Unicode filenames that the backend accepts.

Do not silently rename the upload.

## Extension

Lowercased final suffix must be contained in:

```text
Question.answerUi.allowedExtensions
```

The picker filter is not sufficient; re-check after selection.

## Size

Require:

```text
length > 0
length <= Question.answerUi.maxSizeBytes
```

Do not use a hardcoded Institution limit if the Question supplies a lower effective max.

Platform hard max remains enforced by backend.

## Content

Do **not** inspect binary signatures in Flutter.

Backend owns PDF/DOCX/PPT/PPTX content verification.

---

# 12. Student File Picker

Create:

```text
frontend/lib/features/student/application/student_submission_file_picker.dart
```

Provider:

```text
studentSubmissionFilePickerProvider
```

Interface:

```dart
abstract interface class StudentSubmissionFilePicker {
  Future<StudentSubmissionUploadFile?> pickFile({
    required List<String> allowedExtensions,
  });
}
```

Native implementation uses existing `file_picker`:

```text
FileType.custom
dialogTitle = "Choose an answer file"
allowedExtensions = backend safe list
```

Convert returned platform file to:

```text
name
await length()
readAsByteStream
```

If picker is cancelled:

```text
return null
```

No error state merely for cancellation.

---

# 13. File Picker Failure

If native picker throws:

- do not crash;
- do not issue a network request;
- present:
  ```text
  The file picker could not be opened.
  ```

Do not expose OS/path exception text.

Session/target stale completion from a picker must not publish.

---

# 14. File Answer Editor State

Create:

```text
frontend/lib/features/student/application/student_file_answer_state.dart
frontend/lib/features/student/application/student_file_answer_controller.dart
```

One family controller per:

```text
StudentHomeworkAttemptRouteTarget
```

It manages all `file_based` Questions in the current Attempt.

It does not own non-file drafts.

Per Question state:

```text
serverFile?
selectedFile?
status
sentBytes
totalBytes
failure?
selectionError?
```

Status:

```text
idle
selecting
ready
uploading
uncertain
failure
uploaded
```

Controller-level:

```text
activeQuestionId?
```

Allow at most one active asynchronous file mutation-capable operation per Attempt:

```text
picker selection OR upload OR uncertain-upload reconciliation GET
```

`activeQuestionId` owns that operation. While any of these is active, no other
file picker/upload or duplicate `Reload attempt` may start. Other valid `ready`
selections may remain in local state. Unresolved uncertainty retains its recovery
ownership and blocks new picker/upload operations until Section 32 resolves it.

---

# 15. Initial File State

Build file Question states from the confirmed FE-002 Attempt.

For each `file_based` Question:

## No saved answer

```text
serverFile = null
selectedFile = null
status = idle
```

## Saved file answer

```text
serverFile = current StudentSubmissionFile
selectedFile = null
status = idle
```

Do not fabricate a local upload selection from saved server metadata.

---

# 16. Parent Attempt Synchronization

Observe the delivered FE-002 Attempt controller and distinguish confirmed-current
data from retained/loading/error state.

The delivered `StudentHomeworkAttemptLoadStatus` values are exactly:

```text
initial
loading
data
refreshing
notFound
error
```

There is no Attempt-level `stale` status or `isStale` property. Asynchronous
ownership guards for stale completions/session/targets are separate concerns.

## Confirmed Attempt remains `in_progress`

For each non-uncertain file Question:

- update `serverFile` to the latest confirmed server answer;
- preserve a local valid `selectedFile`;
- remove state for Questions no longer present.

For the active uncertain file Question:

- retain the pending selected-file snapshot;
- retain `uncertain` status and recovery ownership;
- do not compare ordinary parent metadata as proof of the upload outcome;
- retain its Question/recovery state even if the ordinary parent Attempt omits
  that Question, until the explicitly owned Section 32 reconciliation GET resolves
  it.

The screen must continue exposing the active uncertain Question with:

```text
We could not confirm whether this file was uploaded.
Reload attempt
```

even when an ordinary confirmed in-progress parent refresh temporarily omits it.
This preserves the same uncertainty-ownership rule as delivered FE-003.

A normal parent GET refresh must not silently discard a Student's selected local
file.

A normal refresh also must not silently convert an uncertain upload into
`uploaded`, even when filename/size/extension happen to match.

## Parent is `initial`, `loading`, `refreshing`, `error`, or `notFound`

Local selected files may remain visible as unsaved work, but:

```text
Choose file
Choose replacement
Upload answer
Upload replacement
Retry upload
```

must not begin a new picker/upload operation until a confirmed-current
`data` Attempt is available again.

`refreshing` and `error` may retain an older Attempt; retained data is not
picker/upload/retry mutation authority. Section 21 defines the exact gate.

## Confirmed Attempt becomes terminal

Terminal server state always wins.

Immediately:

- invalidate picker/upload/reconciliation generation;
- clear `activeQuestionId`;
- clear all selected local files;
- clear unresolved uncertain-upload ownership/snapshots;
- update `serverFile` from authoritative terminal Attempt;
- make file Questions read-only.

Any picker/PUT/reconciliation GET completion from the obsolete editable
generation must be ignored and must not publish success/failure/progress,
restore selections, or re-enable editing.

No new upload may start.

## Existing FE-003 accepted terminal authority

The file controller may observe only the existing route-level terminal field:

```text
studentAttemptAnswerEditorControllerProvider(target).terminalAttempt
```

This is `StudentAttemptAnswerEditorState.terminalAttempt`. A matching confirmed
non-null terminal snapshot immediately wins over older retained in-progress
parent data, including a later parent `refreshing` or `error` state. Apply the
same terminal invalidation above: invalidate picker/upload/reconciliation
generation, clear `activeQuestionId`, selections and uncertainty, derive
`serverFile` from the terminal Attempt, and disable all file mutations.

Do not own/mutate non-file drafts or create a second full Attempt cache/provider.
The existing Attempt screen continues displaying this accepted terminal snapshot.

## File-owned reconciliation returns terminal

Add a focused boundary to the existing
`frontend/lib/features/student/application/student_homework_attempt_controller.dart`:

```dart
bool acceptAuthoritativeTerminalAttempt(
  StudentHomeworkAttempt attempt,
)
```

Accept only when current Student/session ownership remains valid, Attempt IDs
are canonical UUIDs, `attempt.id == target.attemptId`,
`attempt.assessmentId == target.homeworkId`, and `attempt.status != in_progress`.
Compare UUIDs case-insensitively only after canonical validation.

On acceptance, invalidate/increment the parent request generation, publish
`status = data` with `attempt = supplied terminal Attempt`, and return `true`.
An older in-flight parent GET must not overwrite this accepted terminal state.
If current session/target no longer matches or acceptance conditions fail,
return `false` and publish nothing.

Section 32 must use this boundary when its owned GET returns terminal. The parent
publication makes the whole route terminal; the existing FE-003 controller then
observes and retains the terminal snapshot, including after later parent refresh
failure.

## Session/route target changes

Invalidate operation generation and clear all local selections/operation
ownership.

Do not carry a selected file across Student/session/Attempt targets.

---

# 17. Choose File Behavior

For an editable current `file_based` Question:

1. ensure:
   ```text
   Attempt controller status == data
   attempt != null
   attempt.id == route target attemptId
   attempt.assessmentId == route target homeworkId
   attempt.status == in_progress
   current Student/session/route target is eligible
   current Question exists and is file_based
   no active file mutation/reconciliation operation (including picker selection)
   ```
   The Section 16 terminal authority and Section 29 uncertainty block also apply.
   `initial`, `loading`, `refreshing`, `error`, and `notFound` never authorize a
   picker. Selected-file validity is checked after picking and wherever upload is
   required.
2. assign `activeQuestionId` and set Question state:
   ```text
   selecting
   ```
3. invoke picker using that Question's current:
   ```text
   allowedExtensions
   ```
4. stale completion guard;
5. cancellation:
   - restore previous Question state/selection;
   - no error;
6. validate selected file;
7. invalid:
   - preserve previous valid selection if one existed;
   - expose typed selection error;
   - do not send;
8. valid:
   ```text
   selectedFile = file
   status = ready
   ```

Clear active picker ownership on a current completion/cancellation/failure;
obsolete completions must not clear a newer operation's ownership.

Selecting a new valid file replaces only the local pending selection.

No upload occurs until explicit Student action.

---

# 18. First Upload vs Replacement Presentation

## No saved `serverFile`

Buttons/text:

```text
Choose file
Upload answer
```

## Existing saved `serverFile`

Show current saved metadata:

```text
filename
extension
size
```

Buttons/text:

```text
Choose replacement
Upload replacement
```

The backend preserves the File ID during replacement.

Flutter does not create/delete File identities locally.

---

# 19. Local Selection Is Dirty Work

A valid:

```text
selectedFile != null
```

is an unsaved local change even if:

- its name matches current saved file;
- its size matches current saved file;
- its extension matches current saved file.

Flutter cannot compare content checksum.

Therefore do not implement a client-side "same file no-op" based on metadata.

Backend owns exact-binary no-op detection.

---

# 20. Discard Selected File

Provide local action:

```text
Discard selected file
```

when:

```text
selectedFile != null
status not uploading/uncertain
```

It:

- clears only selected local upload;
- keeps `serverFile` unchanged;
- sends no request.

Do not label it:

```text
Delete answer
```

There is no Stage 7 file clear.

---

# 21. Upload Preconditions

Enable upload only when:

```text
Attempt controller status == data
attempt != null
attempt.id == route target attemptId
attempt.assessmentId == route target homeworkId
attempt.status == in_progress
current Student/session/route target is eligible
current Question exists and is file_based
selected file is locally valid where upload is required
no active file mutation/reconciliation operation (including picker selection)
```

Do not send while the parent Attempt is:

```text
initial
loading
refreshing
error
notFound
```

These are the actual delivered non-authorizing states. An older Attempt retained
by `refreshing` or `error` grants no mutation authority. A matching accepted
FE-003 terminal snapshot always disables mutation under Section 16; unresolved
uncertainty requires Section 32 recovery before a new picker/upload.

The same gate applies to `Retry upload` after confirmed `file_upload_failed`.

Revalidate the selected file against the **current confirmed** Question
`answer_ui` immediately before sending.

If FE-002 refresh lowered `maxSizeBytes` while a file was selected:

- local validation may now fail;
- do not send;
- show current local size error.

Do not compare device time to Homework deadline.

---

# 22. Multipart Upload Data Source

Modify delivered:

```text
StudentHomeworkAttemptRemoteDataSource
```

Add:

```text
uploadFileAnswer(
  attemptId,
  StudentQuestion question,
  file,
  onProgress,
)
```

Exact request:

```dart
dio.put<Object?>(
  '/student/attempts/${Uri.encodeComponent(attemptId)}/answers/'
  '${Uri.encodeComponent(question.id)}',
  data: FormData.fromMap({
    'type': 'file_based',
    'file': MultipartFile.fromStream(
      file.openRead,
      file.length,
      filename: file.name,
    ),
  }),
  options: Options(
    sendTimeout: const Duration(minutes: 5),
    followRedirects: false,
  ),
  onSendProgress: onProgress,
)
```

No query.

No `Idempotency-Key`.

Require:

```text
200
```

Do not explicitly send a client MIME type as file authority.

Let Dio construct multipart boundaries.

The request must have `Content-Type = multipart/form-data` with a Dio-generated
boundary. Do not construct the boundary manually or automatically retry uploads.
The stream boundary must preserve the typed local-source failure in Section 31,
including when Dio wraps a stream error.

---

# 23. Repository Extension

Modify:

```text
StudentHomeworkAttemptRepository
StudentHomeworkAttemptRepositoryImpl
```

Add:

```text
uploadFileAnswer(
  attemptId,
  StudentQuestion question,
  StudentSubmissionUploadFile file, {
  StudentSubmissionUploadProgress? onProgress,
})
```

Return the existing FE-003 typed:

```text
StudentAttemptAnswerMutationResult
```

with:

```text
type = file_based
answer = StudentFileAnswerValue
updatedAt != null
```

Extend the existing `StudentAttemptAnswerMutationDto` as frozen in Section 24.

Do not create a second answer mutation DTO format.

Do not add `file_based` to `StudentAnswerMutation`. That family and repository
`saveAnswer(...)` remain FE-003 non-file JSON paths; file mutation uses only the
separate multipart `uploadFileAnswer(...)` boundary.

All existing `StudentHomeworkAttemptRepository` fakes listed in Section 60 must
receive signature-compatibility updates. Where a regression does not exercise
uploads, add only a fail-fast stub equivalent to:

```dart
throw StateError(
  'This regression must not upload Student file answers.',
);
```

Do not weaken existing assertions. Run the directly affected regressions in
Section 69.1, not only static analysis.

---

# 24. File Mutation Response Integrity

Current main's existing parser deliberately rejects `StudentQuestionType.fileBased`:

```text
frontend/lib/features/student/data/dto/student_attempt_answer_mutation_dto.dart
```

FE-004 must extend this exact `StudentAttemptAnswerMutationDto`, passing the
current validated safe `StudentQuestion` and requested type. For every type:

```text
response.questionId == current StudentQuestion.id
response.type == requestedType
response.type == current StudentQuestion.type
```

For `file_based` success additionally require:

```text
requestedType == file_based
question.type == file_based
question.answerUi is StudentFileAnswerUi

response.answer != null
response.answer is StudentFileAnswerValue
response.updatedAt != null
```

The non-null answer must pass through the existing shared parser:

```dart
parseStudentAttemptAnswerValue(
  Object? json,
  StudentQuestion question,
)
```

Do not create a second file-answer parser or mutation-response DTO. Preserve all
existing non-file nullability:

```text
clearable:
  multiple_choice
  short_written
  open_written
  matching
  ordering
  fill_in_blank

non-null success required:
  single_choice
  true_false
  file_based
```

The shared saved-file parser continues enforcing historical/platform-safe
persisted-file metadata:

```text
canonical File UUID
response.file.extension in pdf/docx/ppt/pptx
response.file.sizeBytes > 0
response.file.sizeBytes <= 15_728_640
non-blank response.file.originalName
```

Do not require historical GET files to satisfy a later-lowered Institution
upload limit. For the current mutation response additionally require current
safe Question policy and exact selected-file metadata:

```text
response.file.extension in current question.answerUi.allowedExtensions
response.file.sizeBytes <= current question.answerUi.maxSizeBytes
response.file.originalName == selectedFile.name
response.file.extension == selectedFile.extension
response.file.sizeBytes == selectedFile.length
```

If replacing an already saved server file, require:

```text
response.file.id == previous serverFile.id
```

because backend replacement preserves File identity.

`response.updatedAt` must use the corrected Stage 7 exact timestamp parser:

```text
YYYY-MM-DDTHH:MM:SSZ
```

Any target/type/policy/metadata/File-ID/timestamp mismatch is:

```text
ApiFailureKind.invalidResponse
```

and therefore an uncertain mutation outcome because the server may have
committed.

Do not navigate/announce success.

---

# 25. Upload Progress

During upload publish:

```text
sentBytes
totalBytes
```

only for the current session/route/question/generation.

Presentation may show:

```text
Uploading… X%
```

when total is known and positive.

Otherwise show indeterminate progress.

Do not infer success from:

```text
sent == total
```

Only valid HTTP `200` + valid response confirms success.

---

# 26. Upload Success

On valid confirmed `200`:

1. set:
   ```text
   serverFile = returned file
   selectedFile = null
   status = uploaded
   ```
2. clear active upload snapshot/progress;
3. request FE-002 Attempt refresh;
4. keep route on Attempt screen;
5. show:
   ```text
   File answer uploaded.
   ```
   or replacement-equivalent safe feedback.

Do not patch any score/attempt count.

Do not change non-file drafts.

---

# 27. Why Upload Outcome Can Be Uncertain

File upload has:

```text
no Idempotency-Key
no ETag/version precondition
no compare-and-swap token
```

A connection/timeout/malformed-success failure may occur after the backend has
already committed the file replacement.

However, blindly repeating the same PUT is **not** generally safe. Between the
lost response and a retry, another device/request for the same Student may save
a newer file. A blind replay of the older selected file would overwrite that
newer server state.

The backend exact-binary no-op protects only a replay against an unchanged
server file graph; it does not protect against an intervening replacement.

The client also cannot prove exact byte identity from GET Attempt because the
Student API intentionally does not expose checksum.

Therefore uncertain upload recovery is:

```text
uncertain PUT
-> authoritative GET Attempt reconciliation
-> current server state becomes the base
-> selected local file remains explicit unsaved intent if Attempt is editable
-> Student decides whether to Upload again
```

No blind PUT retry is permitted for an uncertain outcome.

---

# 28. Uncertain Upload Classification

Treat upload result as uncertain for:

```text
connection
timeout
cancelled
invalidResponse
unknown
```

and structured/server failure when:

```text
statusCode == null
```

or:

```text
statusCode >= 500
```

except the specifically deterministic:

```text
file_upload_failed
```

covered in Section 35.

The typed selected-local-source-unavailable marker in Section 31 takes
precedence over this generic transport/unknown classification, including a
Dio-wrapped local stream failure.

Store:

```text
StudentSubmissionUploadFile
attemptId
questionId
previousServerFileId?
```

as the pending upload snapshot.

State:

```text
uncertain
```

Do not claim success/failure.

The snapshot is retained only for:

- preserving the Student's selected local intent;
- revalidating it after authoritative GET;
- allowing a later **new explicit Upload** if the Student chooses.

It is not an automatic retry token.

---

# 29. Uncertain Upload UX

For the affected Question:

- disable picker;
- disable replacing selection;
- disable normal upload;
- show:
  ```text
  We could not confirm whether this file was uploaded.
  ```
- show exactly one recovery action:
  ```text
  Reload attempt
  ```

Do **not** show `Retry upload` for an uncertain outcome.

No new picker/upload may start until uncertainty is reconciled or the Student
leaves the route/session.

---

# 30. No Blind PUT Retry After Uncertain Upload

Forbidden:

```text
uncertain
-> reopen selectedFile.openRead
-> resend the previous multipart PUT
```

The old request may already have committed, and a newer intervening server
replacement may exist.

After uncertainty reconciliation, any later upload is a new explicit Student
mutation decision based on:

```text
confirmed-current Attempt
current safe file Question
current serverFile
retained/revalidated selectedFile
```

No `Idempotency-Key` is added in FE-004.

`Retry upload` remains allowed only for the confirmed `file_upload_failed`
case in Section 35, where the backend explicitly reports storage-write failure.

---

# 31. Selected Stream Availability

Whenever a retained selected file is about to be sent by a **new explicit
Upload** (including the confirmed `file_upload_failed` retry), stream opening may
still fail because the local source was removed or became inaccessible.

Use a focused typed/local marker for `selected local source unavailable` within
the approved FE-004 upload domain/state boundary. Do not introduce a cross-cutting
error framework or a new backend error code.

The data-source/file-stream boundary must preserve that distinction even when
Dio wraps the error. Cover both:

```text
openRead throws before transport stream begins
stream emits a local read error
```

For this typed local-source failure:

- stop the local operation;
- clear the active operation/network state;
- keep the current `serverFile`;
- show:
  ```text
  The selected file is no longer available. Choose the file again.
  ```
- clear the stale local selection;
- refresh Attempt to show current server state;
- require the Student to choose the file again.

Do not claim upload success or classify this as a generic uncertain server commit.
Do not claim any prior uncertain upload result from this local error. Ordinary
transport failures retain the uncertainty behavior in Section 28.

---

# 32. Authoritative Uncertain Upload Reconciliation

`Reload attempt` starts exactly one explicitly owned reconciliation through:

```text
StudentFileAnswerController
-> StudentHomeworkAttemptRepository.fetchAttempt(target.attemptId)
```

Only this owned GET may reconcile an uncertain file PUT. An ordinary FE-002 parent
refresh must never prove that upload's outcome or clear its recovery state.

At reconciliation dispatch capture:

```text
StudentSessionKey
StudentHomeworkAttemptRouteTarget
questionId
pending StudentSubmissionUploadFile identity/object
previousServerFileId?
operation generation/token
```

While reconciliation is in flight:

- no file picker or PUT may start;
- duplicate Reload taps are suppressed;
- the affected file Question remains picker/upload disabled;
- non-file local drafts remain untouched.

Before accepting completion, require every captured ownership value still to be
current. Before using the returned Attempt, validate canonical UUIDs and require:

```text
returnedAttempt.id == target.attemptId
returnedAttempt.assessmentId == target.homeworkId
```

Compare IDs case-insensitively only after canonical UUID validation. If the
Attempt remains `in_progress`, require exactly one matching current Question:

```text
question.id == captured questionId
question.type == file_based
question.answerUi is StudentFileAnswerUi
```

Malformed/mismatched Attempt or assessment identity, or a missing/duplicate/wrong
type captured Question in an in-progress response, is an invalid authoritative
response. Keep the upload `uncertain` and the pending selected-file snapshot
intact; do not claim success or resend PUT. Ownership invalidation still wins
over obsolete completions.

After the owned GET passes these checks:

## Attempt is terminal

- pass the terminal Attempt to the parent controller's
  `acceptAuthoritativeTerminalAttempt(...)` boundary in Section 16;
- only acceptance publishes `status = data` with that terminal Attempt and
  invalidates the parent request generation, preventing an older in-flight parent
  GET from overwriting it;
- the existing FE-003 controller observes that publication and retains
  `terminalAttempt`, so the whole route remains terminal after later parent
  `refreshing`/`error` states;
- apply Section 16 terminal invalidation, clearing active ownership, all selected
  files and uncertainty, deriving terminal `serverFile`, and disabling mutations;
- if acceptance returns `false`, publish nothing from the obsolete operation;
  current session/target authority wins.

## Attempt remains `in_progress`

The refreshed `serverFile` is the current confirmed server base.

A matching:

```text
filename
extension
size
```

still does **not** prove that the exact selected bytes committed.

Therefore:

- clear uncertainty/reconciliation ownership;
- set `serverFile` from GET;
- retain the previously selected local file as unsaved local intent;
- revalidate it against the refreshed safe `StudentFileAnswerUi`;
- if valid, set the file Question to `ready`;
- if invalid under the refreshed policy, retain it only long enough to show the
  typed selection error, then require the Student to choose a valid file before
  upload according to the normal selection rules;
- allow a new explicit Upload only when the exact parent `data` and current
  Attempt/Question/session/selection gate in Section 21 is satisfied. An owned
  GET does not make older retained `refreshing`/`error` parent data mutation
  authority.

The Student may also `Discard selected file` and accept the current server state.

## Reconciliation GET fails non-authoritatively

Keep:

```text
status = uncertain
pending selected file/snapshot
```

and allow another `Reload attempt` later.

Session/target/terminal-generation invalidation still wins over a late GET
completion.

Do not mark the prior upload confirmed merely from metadata equality.

---

# 33. Deterministic Unsupported File

For:

```text
422 unsupported_file_type
```

the request definitively failed.

Actions:

- clear active/uncertain state;
- clear the selected file because retrying the same content is invalid;
- keep existing `serverFile`;
- show:
  ```text
  The selected file content is not a supported PDF, DOCX, PPT, or PPTX file.
  ```

Do not expose backend binary-inspector details.

---

# 34. Deterministic File Too Large

For:

```text
422 file_too_large
```

Actions:

- clear active/uncertain state;
- clear selected file;
- keep existing saved file;
- refresh Attempt so latest `max_size_bytes` can be obtained;
- show:
  ```text
  The selected file exceeds the current upload limit.
  ```

Do not hardcode a new limit from the error message.

---

# 35. Deterministic File Upload Failed

For:

```text
500 file_upload_failed
```

backend explicitly reports that storage write failed.

Treat this as a **confirmed failure**, not an uncertain commit.

Actions:

- retain selected file;
- state `failure`;
- keep existing `serverFile`;
- show:
  ```text
  The file could not be stored. Try again.
  ```

Allow:

```text
Retry upload
```

only as a new explicit Student action after rechecking the normal Section 21
preconditions against confirmed-current Attempt/Question state and revalidating
the selected file.

This confirmed-failure retry is not the uncertain blind-retry path forbidden in
Section 30.

Do not mark saved.

---

# 36. Other Deterministic Upload Errors

## `validation_failed`

Confirmed rejection.

- retain selected file only as local context;
- normal re-upload button disabled until a new selection is made;
- show safe contract error.

## `deadline_passed`

- clear selected file;
- refresh Attempt + Homework detail;
- show deadline message;
- expect terminal state.

## `attempt_not_editable`

- clear selected file;
- refresh Attempt;
- show non-editable message.

## `task_not_active` / `task_closed` / `task_archived`

- clear selected file;
- refresh Attempt + Homework detail;
- show no-longer-editable message.

## `resource_not_found`

- clear file controller state;
- trigger FE-002 Attempt notFound reconciliation.

## `business_conflict`

- stop upload;
- clear selected file;
- refresh Attempt;
- show safe conflict message.

Session failures use the existing Student session reconciliation and must:

- invalidate file picker/upload/reconciliation generation;
- clear active operation ownership and local selected files for the old session;
- publish no stale file feedback/open/save action after auth/session changes.

---

# 37. No File Clear

FE-004 does not expose:

```text
Remove file
Delete file answer
Clear file answer
```

Once serverFile exists, the Student can only:

```text
replace it while Attempt is editable
```

When Attempt is terminal, it is read-only/downloadable.

---

# 38. Saved File Download UX

For a saved `serverFile` authorized by either current parent `data` or the accepted
FE-003 terminal snapshot under Section 40, provide:

```text
Open
Save As…
```

These actions are read-only and remain available when backend authorization permits.

Do not require Attempt to be `in_progress`.

Do not construct storage/public URLs.

Download through existing:

```text
ProtectedLearningMaterialTransfer.download(file.id)
```

---

# 39. Student Submission Transfer Controller

Create:

```text
frontend/lib/features/student/application/student_submission_transfer_state.dart
frontend/lib/features/student/application/student_submission_transfer_controller.dart
```

Family key:

```text
StudentHomeworkAttemptRouteTarget
```

It owns:

```text
one current saved-file transfer at a time
download progress
open/save local action
safe feedback
session/target ownership
```

It does not own upload.

Actions enum:

```text
open
saveAs
```

State statuses:

```text
idle
downloading
opening
saving
failure
```

---

# 40. Transfer Current-Target Validation

Before transfer, require the file is still the current saved file answer for:

```text
attempt route target
questionId
fileId
```

Resolve read-only transfer authority from either:

1. current FE-002 Attempt controller `status == data` with a non-null matching
   current Attempt; this Attempt may be `in_progress` or terminal; or
2. accepted FE-003 `editorState.terminalAttempt != null`, matching the route target,
   with the current Student/session eligible and parent status not `notFound`.

In either case validate canonical Attempt/Homework IDs against the route target
and current Student/session ownership. A matching accepted terminal snapshot wins
over older retained in-progress parent data. It remains read-only transfer
authority when the parent later becomes `refreshing` or `error`.

Ordinary retained `in_progress` parent data in `refreshing`/`error` is not transfer
authority. `initial`/`loading` alone cannot authorize a transfer. `notFound`, session
loss, route-target change, and file-target change always block/abort transfer.

Require:

```text
Question.type = file_based
saved answer.type = file_based
saved answer.file.id = requested fileId
```

Do not permit a stale File ID captured from an old rebuild.

---

# 41. Download Result Validation Against Saved Metadata

After `ProtectedLearningMaterialTransfer.download(...)` succeeds and before local Open/Save:

require:

```text
downloaded.extension == current serverFile.extension
downloaded.bytes.length == current serverFile.sizeBytes
downloaded.bytes.isNotEmpty
downloaded.bytes.length <= 15_728_640
```

The shared protected parser already validates:

```text
supported canonical MIME
Content-Disposition attachment
private,no-store
nosniff
non-empty protected bytes
```

Do not duplicate those header checks.

Filename may be safely sanitized/fallback by the shared parser and need not equal the raw `originalName`.

If size/extension metadata mismatch:

```text
invalid protected file response
```

Do not open/save the bytes.

---

# 42. Transfer Stale Completion Safety

Bind transfer to:

```text
StudentSessionKey
Attempt route target
questionId
fileId
operation generation
```

After download and before local action, revalidate the same current authority
from Section 40 and the current saved server file. The accepted terminal snapshot
remains valid through parent `refreshing`/`error`; ordinary retained in-progress
data does not.

If an Attempt refresh changed/removed the file target:

- abandon local action;
- publish no stale success feedback.

Late completion after session/route disposal must not open/save a file.

Parent `notFound`, session loss, target change, or file-target change must abort
the transfer before local Open/Save As even if download has completed.

---

# 43. Download Failure Reconciliation

## `resource_not_found`

Trigger:

```text
Attempt refresh
```

Then show:

```text
This submitted file is no longer available.
```

if the route remains current.

## `file_not_available`

Show:

```text
The file is temporarily unavailable. Try again.
```

## invalid response

Show:

```text
The server returned an unexpected file response.
```

## timeout / connection

Show safe retryable download message.

Session failures use the existing Student session behavior.

---

# 44. Minimal `LocalFileActions` Extension

Current `LocalFilePlatformAdapter.saveFile(...)` does not receive the dialog title;
native code hardcodes:

```text
Save learning material
```

FE-004 needs correct Student submission wording without duplicating local-file infrastructure.

Modify:

```text
frontend/lib/core/files/local_file_actions.dart
```

so:

```dart
Future<bool> saveAs(
  TrustedDownloadedFile file, {
  String dialogTitle = 'Save learning material',
})
```

passes the title to:

```text
LocalFilePlatformAdapter.saveFile
```

Require the adapter signature exactly:

```dart
Future<Uri?> saveFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
  required String dialogTitle,
});
```

`LocalFileActions.saveAs` forwards `dialogTitle`, and native
`FilePicker.saveFile(...)` uses that supplied value. If
`NativeLocalFilePlatformAdapter.saveFileDialog` injection remains, its callback
signature must receive `dialogTitle` too so focused tests verify forwarding.

Existing learning-material callers that omit the argument retain exactly:

```text
Save learning material
```

Student submission transfer passes:

```text
Save submitted answer
```

No other behavior changes.

Update every existing `LocalFilePlatformAdapter` implementation/fake required
for signature compatibility, including:

```text
frontend/test/core/network/protected_learning_material_transfer_test.dart
frontend/test/features/student/student_topic_detail_transfer_controller_test.dart
frontend/test/features/teacher/teacher_material_transfer_controller_test.dart
frontend/integration_test/stage5_e2e_support.dart
```

The Stage 5 integration helper is a compile/analyze compatibility touch only in
FE-004; do not run Stage 5 E2E here.

---

# 45. Local Open

Use existing:

```text
LocalFileActions.open(fileId, downloaded)
```

No new local temporary-file subsystem.

If no native application can open the format:

```text
No application is available to open this file. Save the file instead.
```

Do not treat this as download failure.

---

# 46. File Question Presentation

Create:

```text
frontend/lib/features/student/presentation/student_file_answer_editor.dart
```

Extract/expose one focused shared presentation shell, for example
`StudentQuestionAnswerCard`, inside the existing:

```text
frontend/lib/features/student/presentation/student_question_answer_editor.dart
```

It owns only common rendering:

```text
Question number/type
prompt
instructions
points
content/body slot
status/action slot where needed
```

`StudentQuestionAnswerEditor` continues composing this shell for the eight
existing non-file editors. New `StudentFileAnswerEditor` composes the same shell
for file-specific state/actions.

Do not add file state to `StudentAnswerDraft`,
`StudentAttemptAnswerEditorState.questions`, or the non-file answer-editor
controller. Do not create a God widget with nullable non-file/file state flags.

For `in_progress` Attempt:

## No saved file

Show:

```text
No file uploaded.
Choose file
```

After valid selection:

```text
Selected:
<name>
<size>

Upload answer
Discard selected file
```

## Saved file

Show:

```text
Current file:
<name>
<size>

Open
Save As…
Choose replacement
```

After replacement selection:

```text
Selected replacement:
<name>
<size>

Upload replacement
Discard selected file
```

No Delete/Clear.

---

# 47. Terminal File Question Presentation

For terminal Attempt:

- no picker;
- no upload/replace;
- show saved file metadata if present;
- show Open/Save As when file exists;
- if unanswered:
  ```text
  No file was submitted.
  ```

Use the matching accepted FE-003 terminal snapshot after later parent
`refreshing`/`error` states; its saved file remains visible and Open/Save As stays
available under Section 40. `notFound` and session/target invalidation still win.

Do not show score/checking state.

---

# 48. File Size Formatting

Add/use focused presentation formatter.

Display:

- bytes/KB/MB in a stable human-readable format;
- maximum upload size from safe `answer_ui.maxSizeBytes`.

The machine comparison remains integer bytes.

Do not parse formatted labels back into application logic.

---

# 49. Picker/Upload Progress UX

## Selecting

Show compact busy state:

```text
Opening file picker…
```

Do not block the entire Attempt screen.

## Uploading

Show:

```text
Uploading file…
```

plus progress indicator.

Disable file picker/upload controls for all file Questions while any picker,
upload, or uncertain-upload reconciliation GET is active. `activeQuestionId` owns
that single operation, duplicate Reload actions are suppressed, and other valid
`ready` selections may remain stored. Uncertainty retains its Section 29 block
until reconciled.

Non-file local fields may remain editable.

Do not infer completion from progress.

---

# 50. Upload and FE-003 Non-File Mutations

FE-004 does not introduce a new global mutation coordinator.

A file upload and a non-file Question Save may technically overlap.

This is acceptable:

- backend serializes through the Attempt row;
- they affect different Question answers;
- controllers reconcile from GET Attempt;
- no local score/lifecycle outcome is inferred.

Do not create provider cycles merely to globally serialize both controller types.

`S07-FE-005` must prevent final Submit while any mutation is active/uncertain.

---

# 51. Upload vs Parent Finalization

If a confirmed parent Attempt becomes terminal, or the existing FE-003 controller
exposes a matching accepted `terminalAttempt`, during:

```text
selecting
ready
failure
uncertain/reconciling
uploading
```

apply Section 16 terminal invalidation:

- invalidate picker/upload/reconciliation generation;
- clear `activeQuestionId`;
- clear selected file/pending uncertainty;
- switch read-only;
- ignore every late completion from the obsolete editable generation.

If backend finalization wins against an in-flight upload, the request may return
a lifecycle error or the parent refresh may publish terminal state first.
Either way, confirmed terminal authority wins over older retained in-progress
parent data and no retry action is restored. File-owned reconciliation returning
terminal must first use Section 16's parent acceptance boundary to invalidate
older parent GETs and publish terminal state for the entire route.

If upload committed before finalization, a later authoritative GET may show that
saved file in terminal state.

No optimistic reconciliation.

---

# 52. File Unsaved Navigation Protection

Extend the FE-003 Attempt route leave guard.

File controller exposes:

```text
hasPendingSelection
hasUncertainUpload
```

Combine with FE-003:

```text
hasDirtyDrafts
hasUncertainMutation
```

The existing guard remains in place. Resolve warning priority exactly:

```text
1. file.hasUncertainUpload
   -> file upload uncertainty warning
2. nonFile.hasUncertainMutation
   -> existing non-file save uncertainty warning
3. file.hasPendingSelection || nonFile.hasDirtyDrafts
   -> existing unsaved answer changes warning
4. otherwise
   -> leave directly
```

## Selected but not uploaded file

Treat as unsaved local work.

Leave warning:

```text
You have unsaved answer changes.
Leave and discard these changes?
```

## Uncertain file upload

Use uncertainty-priority warning:

```text
A file upload result is still unconfirmed.
Leaving will discard the local uncertainty/reconciliation state. Re-opening the attempt will reload server data.
```

On `Stay`, preserve both controllers' local state.

On confirmed `Leave`, clear FE-003 non-file local state and FE-004 local
selection/uncertainty state, send no PUT or upload, and navigate to Homework
detail. Do not auto-upload or auto-save on leave.

---

# 53. Current Saved File Download During Pending Replacement

While a new replacement is merely selected:

- current server file Open/Save As remains available.

It clearly refers to:

```text
Current file
```

not the selected replacement.

During an active upload for that same Question:

- disable Open/Save As for that Question until upload outcome is resolved, to avoid UI ambiguity.

Other saved file Questions may remain downloadable when Section 40 authority
still holds. Ordinary retained in-progress `refreshing`/`error` data cannot
authorize a new transfer.

---

# 54. API Error Codes

FE-003 should already include:

```text
attempt_not_editable
```

FE-004 reuses existing core:

```text
unsupported_file_type
file_too_large
file_upload_failed
file_not_available
```

No new error constants are expected.

Add one only if the delivered baseline is genuinely missing an exact backend code required here.

Do not duplicate string literals in Widgets.

---

# 55. File Answer Response / Attempt Parser Reuse

FE-002 already parses:

```text
StudentFileAnswerValue
StudentSubmissionFile
```

Current FE-003 `StudentAttemptAnswerMutationDto` deliberately rejects
`StudentQuestionType.fileBased`; FE-004 must extend that existing DTO as specified
in Section 24, continuing to use `parseStudentAttemptAnswerValue` and these exact
models.

Do not create a second:

```text
StudentUploadedFile
StudentAnswerFileDto
```

with overlapping shape.

One canonical saved Student submission model.

Current main's
`frontend/lib/features/student/data/dto/student_homework_attempt_dto.dart` already
parses `StudentFileAnswerValue` through the shared parser and is expected unchanged.
Do not refactor it. If implementation discovers a concrete blocker requiring a
change there, return `BLOCKED` with evidence rather than inventing another parser
architecture. `StudentAnswerMutation` and `saveAnswer(...)` remain non-file JSON
mutation paths.

---

# 56. Saved File Invariant on Replacement

Because backend replacement preserves the same `File.id`, the client may use the File ID as stable saved-answer identity across a confirmed replacement.

Do not use original filename as identity.

Do not assume local selected file has an ID before server success.

---

# 57. Filename Privacy / Display

Display only:

```text
originalName
extension
sizeBytes
```

from safe server metadata.

Do not display:

```text
local source path
storage path
disk
checksum
owner ID
Institution ID
```

For locally selected file, display:

```text
file.name
file.length
```

never platform path.

---

# 58. Accessibility

Required:

- Choose file / replacement has explicit semantic label including Question context;
- selected filename and size readable;
- upload progress has semantics;
- current saved vs selected replacement are textually distinct;
- Open/Save As labels explicit;
- failure/uncertain states not color-only;
- Reload attempt for uncertain upload and confirmed-failure Retry upload are keyboard/touch accessible;
- Discard selection label is unambiguous;
- no "Delete answer" wording;
- buttons wrap on mobile;
- focus returns sensibly after picker cancellation/completion where practical.

---

# 59. Responsiveness

Support desktop/mobile.

File card must:

- wrap long Unicode filenames;
- not horizontally overflow;
- place action buttons in `Wrap`;
- progress bar fit narrow screens;
- show size/extension metadata vertically if needed.

No desktop-only file answer editing.

---

# 60. Expected Files

## Create

```text
frontend/lib/features/student/domain/student_submission_upload.dart

frontend/lib/features/student/application/student_submission_file_picker.dart
frontend/lib/features/student/application/student_file_answer_state.dart
frontend/lib/features/student/application/student_file_answer_controller.dart
frontend/lib/features/student/application/student_submission_transfer_state.dart
frontend/lib/features/student/application/student_submission_transfer_controller.dart

frontend/lib/features/student/presentation/student_file_answer_editor.dart

frontend/test/features/student/student_submission_upload_test.dart
frontend/test/features/student/student_file_answer_data_test.dart
frontend/test/features/student/student_file_answer_controller_test.dart
frontend/test/features/student/student_submission_transfer_controller_test.dart
frontend/test/features/student/student_file_answer_screen_test.dart
```

## Modify

```text
frontend/lib/features/student/domain/student_homework_attempt_repository.dart
frontend/lib/features/student/data/dto/student_attempt_answer_mutation_dto.dart
frontend/lib/features/student/data/student_homework_attempt_remote_data_source.dart
frontend/lib/features/student/data/student_homework_attempt_repository_impl.dart

frontend/lib/features/student/application/student_homework_attempt_controller.dart
frontend/lib/features/student/presentation/student_homework_attempt_screen.dart
frontend/lib/features/student/presentation/student_question_answer_editor.dart
frontend/lib/features/student/presentation/student_homework_formatters.dart

frontend/lib/core/files/local_file_actions.dart

frontend/test/features/student/student_answer_mutation_data_test.dart
frontend/test/features/student/student_homework_attempt_start_controller_test.dart
frontend/test/features/student/student_homework_attempt_controller_test.dart
frontend/test/features/student/student_homework_attempt_screen_test.dart
frontend/test/features/student/student_homework_attempt_routing_test.dart
frontend/test/features/student/student_homework_screen_test.dart
frontend/test/features/student/student_answer_editor_controller_test.dart
frontend/test/features/student/student_answer_editor_screen_test.dart

frontend/test/core/network/protected_learning_material_transfer_test.dart
frontend/test/features/student/student_topic_detail_transfer_controller_test.dart
frontend/test/features/teacher/teacher_material_transfer_controller_test.dart
frontend/integration_test/stage5_e2e_support.dart
```

`student_attempt_answer_mutation_dto.dart` must be extended for file responses;
`student_homework_attempt_dto.dart` is expected unchanged under Section 55. Do not
duplicate the parser/model.

`student_attempt_answer_editor_state.dart` is not an expected modification because
file state is separately owned. Only a concrete compile-only requirement may
justify a change there; no file drafts/state may be added. If that exception is
needed, add its exact path to the format check and explain the reason in the
completion report.

The seven existing Attempt-repository fake files listed above are explicitly
authorized for `uploadFileAnswer(...)` signature compatibility. Regressions not
exercising FE-004 uploads receive only the fail-fast stub in Section 23, without
weakening assertions. `student_homework_attempt_controller_test.dart` also tests
the terminal acceptance boundary, and the answer-editor screen regression covers
the extended leave guard.

`stage5_e2e_support.dart` may change only for `LocalFilePlatformAdapter`
signature compatibility. No Stage 5 behavior redesign.

No route path change.

No backend/pubspec/pubspec.lock/platform files.

---

# 61. Selection Domain Tests

`student_submission_upload_test.dart` covers:

- extension extraction;
- case-insensitive extension;
- no extension;
- empty file;
- allowed PDF/DOCX/PPT/PPTX;
- disallowed extension;
- exact `maxSizeBytes`;
- over max;
- filename Unicode code-point boundary (500 runes);
- Unicode filename;
- invalid filename;
- selected-file validation typed error.

Do not test binary content signatures.

---

# 62. File Upload Data Tests

`student_file_answer_data_test.dart` covers exact:

```text
PUT /student/attempts/{attempt}/answers/{question}
```

Assert:

```text
FormData
Content-Type = multipart/form-data
Dio-generated multipart boundary present
fields exactly:
  type = file_based
one file part exactly:
  file
filename exact
no query parameters
no Idempotency-Key
followRedirects = false
sendTimeout = 5 minutes
HTTP 200 only
```

Consume stream and verify uploaded bytes in the test adapter.

Progress callback receives transport values.

Success:

- exact 200;
- file mutation response parsed;
- metadata/target checked.

Reject as invalid response:

- answer null;
- wrong question ID;
- wrong type/non-file safe Question;
- response extension outside current safe Question allowed extensions;
- response size exceeds current safe Question `maxSizeBytes`, including a limit
  below the platform cap;
- selected name/size/extension mismatch;
- replacement returns different File ID;
- extra storage/checksum fields;
- malformed/non-whole-second/non-UTC `updated_at`.

Malformed `200` is classified as uncertain by the controller and requires GET
reconciliation.

No automatic retry.

Do not manually construct a multipart boundary or send client MIME type as
authoritative file type. Verify synchronous `openRead` throws and emitted local
read errors both retain the typed source-unavailable marker through Dio wrapping.

Update the existing file-boundary regression in
`student_answer_mutation_data_test.dart` to prove:

- GET Attempt file answers still use the shared saved-answer parser;
- valid `file_based` mutation responses are now accepted by the existing extended
  `StudentAttemptAnswerMutationDto`, with typed `StudentFileAnswerValue` and
  non-null `updated_at`;
- null file answers and null `updated_at` are rejected;
- malformed metadata and unknown/extra file fields remain rejected;
- Question ID, requested type, current Question type and file UI must match;
- existing clearable/non-null non-file behavior in Section 24 remains intact;
- historical GET parsing stays platform-cap based even if current Institution
  `maxSizeBytes` is lower;
- `StudentAnswerMutation` and `StudentHomeworkAttemptRepository.saveAnswer(...)`
  remain non-file JSON paths; FE-003 JSON Save cannot upload files.

---

# 63. File Controller Tests

`student_file_answer_controller_test.dart` covers:

## Initialization

- no file answer;
- saved file answer;
- multiple file Questions.

## Picker

- cancel neutral;
- picker throw safe failure;
- invalid local extension;
- empty;
- too large;
- filename too long;
- valid ready state;
- replacing local selection.

## Mutation authority / concurrency

- the Attempt state uses exactly `initial`, `loading`, `data`, `refreshing`,
  `notFound`, `error`, with no Attempt `stale` status or `isStale` property;
- picker/upload/retry require all exact Section 21 preconditions, including a
  non-null Attempt matching both route IDs and the current file Question;
- `initial`/`loading`/`refreshing`/`error`/`notFound` never authorize mutation,
  including when old in-progress data is retained;
- only one picker/upload/reconciliation operation may be active per Attempt;
- a picker blocks another Question's picker/upload, upload blocks picker/upload,
  reconciliation blocks picker/upload/duplicate Reload, and `activeQuestionId`
  owns the operation;
- other valid `ready` selections survive; non-file local edits/Save retain the
  allowed Section 50 overlap.

## First upload

- ready -> uploading -> confirmed serverFile;
- selection cleared;
- parent Attempt refresh.

## Replacement

- current File ID preserved;
- confirmed metadata updated.

## Progress

Only current operation can publish.

## Uncertain

- timeout retains same selected file;
- invalid success retains uncertainty;
- no blind Retry-upload path exists;
- Reload Attempt is the only uncertainty recovery;
- picker/new upload disabled until reconciliation;
- GET metadata equality alone never marks prior PUT confirmed;
- in-progress reconciliation makes GET server file the base and retained local
  selection `ready` only after current-policy revalidation;
- reconciliation failure preserves uncertainty;
- ordinary parent refresh cannot resolve uncertainty or compare metadata as proof;
- ordinary parent omission of the uncertain Question preserves its snapshot,
  status, recovery ownership and visible Reload action;
- only the file-controller-owned repository `fetchAttempt(target.attemptId)` can
  reconcile the pending upload;
- captured session, route, Question, selected-file object, previous File ID and
  generation must all remain current;
- returned Attempt/Homework UUIDs must be canonical and match the route;
- an in-progress response must have exactly one matching current file Question
  with `StudentFileAnswerUi`;
- malformed/mismatched identities and missing/duplicate/wrong-type Question keep
  uncertainty and the exact selected snapshot, never report success or send PUT;
- terminal reconciliation goes through parent `acceptAuthoritativeTerminalAttempt`,
  clears selected/uncertain state and makes the whole route read-only;
- an older in-flight parent GET cannot overwrite file-reconciled terminal state;
- a later parent refresh failure retains FE-003 terminal authority.

## `file_upload_failed`

- confirmed failure;
- selected file retained;
- Retry allowed only after current Attempt/Question/selection preconditions are
  revalidated.

## unsupported/too-large

- selection cleared;
- existing server file retained.

## Selected source unavailable

- synchronous `openRead` throw and emitted local read error, including Dio-wrapped
  failures, preserve the typed local distinction;
- no success or generic uncertain server-commit classification;
- clear active operation and stale selection, preserve current `serverFile`, show
  the exact Section 31 message, refresh Attempt, and require choosing again;
- ordinary connection/timeout/cancelled/invalidResponse/unknown and 5xx except
  confirmed `file_upload_failed` still retain uncertainty.

## lifecycle

- deadline/non-editable refreshes parent;
- parent `initial`/`loading`/`refreshing`/`error`/`notFound` disables Choose/Upload/Retry;
- terminal parent clears selections and invalidates active upload/reconciliation
  generation;
- matching FE-003 `terminalAttempt` immediately invalidates picker/upload/
  reconciliation, clears `activeQuestionId` and local selection/uncertainty,
  derives terminal server files and wins over retained in-progress parent data;
- late PUT/GET/picker completion after terminal state is ignored.

Strengthen `student_homework_attempt_controller_test.dart` for the parent terminal
acceptance method: eligible session, canonical matching Attempt/Homework IDs and
terminal status accept/publish `data` and increment request generation; invalid
IDs, in-progress status or obsolete session/target return `false` without
publication. An older in-flight GET cannot overwrite the accepted terminal Attempt.

## stale/session

- Student/session/route/dispose stale completion ignored;
- session failure clears local selected files and operation ownership.

---

# 64. Protected Submission Transfer Tests

`student_submission_transfer_controller_test.dart` covers:

## Current saved file

- confirmed-current Attempt data permits Open via `/files/{id}/download`;
- confirmed-current Attempt data permits Save As via same endpoint;
- ordinary `initial`/`loading` and retained in-progress `refreshing`/`error` parent
  states cannot start a transfer;
- matching accepted FE-003 terminal snapshot permits Open/Save As after parent
  `refreshing` or `error` even when older in-progress parent data is retained;
- `notFound`, session loss, target change or file-target change blocks/aborts
  transfer under either authority;
- no public URL.

## Metadata validation

Reject downloaded bytes when:

```text
byte length != server size
extension mismatch
> 15 MB
```

before local action.

## Save dialog

Verify Student submission passes:

```text
Save submitted answer
```

to `LocalFileActions`, which forwards it through the required adapter parameter
and native save-dialog callback.

## Open

No-app outcome gives safe feedback.

## Download errors

- 404 -> Attempt refresh;
- file_not_available;
- timeout;
- connection;
- invalid protected response.

## Historical terminal Attempt

Open/Save As remains permitted from matching current parent data or accepted
terminal snapshot; backend remains authority. Terminal file visibility and both
local actions survive later parent refresh failure.

## Stale target

After download and before local action, revalidate the same Section 40 authority,
session/route/generation and current saved file. If authority is lost or the
Attempt/file target changes, old transfer does nothing. A retained in-progress
error state must not authorize a delayed local action.

---

# 65. Shared File Regression Test

Update:

```text
test/core/network/protected_learning_material_transfer_test.dart
```

for the minimal `LocalFileActions` signature change.

Verify existing default still sends:

```text
Save learning material
```

for old call sites.

Add custom dialog-title forwarding test.

Verify `LocalFileActions.saveAs` forwards both default and custom titles through
`LocalFilePlatformAdapter.saveFile` and the native `saveFileDialog` injection (if
retained), not only at the caller boundary.

The protected HTTP parser/transport behavior itself must not change.

Run directly affected existing:

```text
test/features/student/student_topic_detail_transfer_controller_test.dart
test/features/teacher/teacher_material_transfer_controller_test.dart
```

to prove Stage 5 Learning Material Open/Save remains intact.

---

# 66. File Answer Screen Tests

`student_file_answer_screen_test.dart` covers desktop + mobile.

## No saved file

Shows:

```text
Choose file
No file uploaded
```

After selection:

```text
Selected
Upload answer
Discard selected file
```

No automatic request on pick.

## Saved file

Shows:

```text
Current file
Open
Save As…
Choose replacement
```

No Delete/Clear.

## Replacement selected

Clearly distinguishes:

```text
Current file
Selected replacement
```

## Uploading

- progress/busy;
- picker/upload disabled.

## Success

- new safe server metadata;
- selected draft gone.

## Uncertain

- unconfirmed warning;
- `Reload attempt` recovery only;
- no blind `Retry upload`;
- no choose-new-file action until reconciliation.
- ordinary confirmed parent refresh, including omission of the uncertain
  Question, retains that Question's exact uncertainty message and `Reload attempt`.

## Errors

- unsupported;
- too large;
- file upload failed retry;
- lifecycle terminal transition.
- selected local source unavailable uses the exact safe message, clears the local
  selection, retains the current file and requires choosing again.

## Terminal

- no picker/upload;
- saved file Open/Save As still shown;
- unanswered file Question shows no file submitted.
- file-owned reconciliation returning terminal publishes through the parent
  controller and makes the whole Attempt route terminal;
- an older parent GET cannot restore in-progress editing after that publication;
- later parent `refreshing`/`error` with retained in-progress data cannot displace
  the accepted FE-003 terminal snapshot or restore file mutation controls;
- terminal saved file Open/Save As remains available after parent refresh failure;
- ordinary retained in-progress error data cannot authorize Open/Save As.

Verify the shared Question-card shell renders all eight existing non-file editors
and the separately owned file editor without placing file state in non-file drafts.

No score/checking.

---

# 67. Navigation Guard Regression

Extend FE-003 navigation tests:

- pending file selection triggers unsaved warning;
- discard/leave sends no upload;
- uncertain file upload triggers uncertainty warning;
- Stay preserves uncertainty/reconciliation state;
- Leave clears local file uncertainty/reconciliation state;
- clean file state does not add confirmation.

Cover the full Section 52 priority, including coexisting conditions:

```text
file.hasUncertainUpload -> file uncertainty warning
else nonFile.hasUncertainMutation -> existing non-file uncertainty warning
else file.hasPendingSelection || nonFile.hasDirtyDrafts -> existing unsaved warning
else -> leave directly
```

Verify `Stay` preserves both controllers' local state. Confirmed `Leave` clears
both non-file local state and file selection/uncertainty, sends no PUT or upload,
and navigates to Homework detail. No auto-save or auto-upload.

---

# 68. Directly Affected Regression Tests

Run FE-004 tests plus:

```text
test/features/student/student_answer_mutation_data_test.dart
test/features/student/student_answer_editor_controller_test.dart
test/features/student/student_answer_editor_screen_test.dart

test/features/student/student_homework_attempt_dto_test.dart
test/features/student/student_homework_attempt_data_test.dart
test/features/student/student_homework_attempt_start_controller_test.dart
test/features/student/student_homework_attempt_controller_test.dart
test/features/student/student_homework_attempt_screen_test.dart
test/features/student/student_homework_attempt_routing_test.dart
test/features/student/student_homework_screen_test.dart

test/core/network/protected_learning_material_transfer_test.dart
test/features/student/student_topic_detail_transfer_controller_test.dart
test/features/teacher/teacher_material_transfer_controller_test.dart
```

If delivered FE-001…003 materially do not contain these approved boundaries,
return `BLOCKED` for dependency-contract mismatch instead of silently remapping
verification.

Do not run the full frontend suite in this individual task.

---

# 69. Verification

Run from:

```text
frontend/
```

## 69.1 Focused FE-004 + directly affected FE-003/FE-002/shared-file regressions

Exactly:

```bash
flutter test \
  test/features/student/student_submission_upload_test.dart \
  test/features/student/student_file_answer_data_test.dart \
  test/features/student/student_file_answer_controller_test.dart \
  test/features/student/student_submission_transfer_controller_test.dart \
  test/features/student/student_file_answer_screen_test.dart \
  test/features/student/student_answer_mutation_data_test.dart \
  test/features/student/student_answer_editor_controller_test.dart \
  test/features/student/student_answer_editor_screen_test.dart \
  test/features/student/student_homework_attempt_dto_test.dart \
  test/features/student/student_homework_attempt_data_test.dart \
  test/features/student/student_homework_attempt_start_controller_test.dart \
  test/features/student/student_homework_attempt_controller_test.dart \
  test/features/student/student_homework_attempt_screen_test.dart \
  test/features/student/student_homework_attempt_routing_test.dart \
  test/features/student/student_homework_screen_test.dart \
  test/core/network/protected_learning_material_transfer_test.dart \
  test/features/student/student_topic_detail_transfer_controller_test.dart \
  test/features/teacher/teacher_material_transfer_controller_test.dart
```

Do not run Stage 5 integration E2E here; its support file is modified only for
interface compatibility and is covered by static analysis.

Narrow single-test diagnostic reruns are allowed only to diagnose/confirm a
concrete failure.

## 69.2 Exact Dart format check

Exactly:

```bash
dart format --output=none --set-exit-if-changed \
  lib/features/student/domain/student_submission_upload.dart \
  lib/features/student/domain/student_homework_attempt_repository.dart \
  lib/features/student/data/dto/student_attempt_answer_mutation_dto.dart \
  lib/features/student/data/student_homework_attempt_remote_data_source.dart \
  lib/features/student/data/student_homework_attempt_repository_impl.dart \
  lib/features/student/application/student_submission_file_picker.dart \
  lib/features/student/application/student_file_answer_state.dart \
  lib/features/student/application/student_file_answer_controller.dart \
  lib/features/student/application/student_submission_transfer_state.dart \
  lib/features/student/application/student_submission_transfer_controller.dart \
  lib/features/student/application/student_homework_attempt_controller.dart \
  lib/features/student/presentation/student_file_answer_editor.dart \
  lib/features/student/presentation/student_homework_attempt_screen.dart \
  lib/features/student/presentation/student_question_answer_editor.dart \
  lib/features/student/presentation/student_homework_formatters.dart \
  lib/core/files/local_file_actions.dart \
  test/features/student/student_submission_upload_test.dart \
  test/features/student/student_file_answer_data_test.dart \
  test/features/student/student_file_answer_controller_test.dart \
  test/features/student/student_submission_transfer_controller_test.dart \
  test/features/student/student_file_answer_screen_test.dart \
  test/features/student/student_answer_mutation_data_test.dart \
  test/features/student/student_answer_editor_controller_test.dart \
  test/features/student/student_answer_editor_screen_test.dart \
  test/features/student/student_homework_attempt_start_controller_test.dart \
  test/features/student/student_homework_attempt_controller_test.dart \
  test/features/student/student_homework_attempt_screen_test.dart \
  test/features/student/student_homework_attempt_routing_test.dart \
  test/features/student/student_homework_screen_test.dart \
  test/core/network/protected_learning_material_transfer_test.dart \
  test/features/student/student_topic_detail_transfer_controller_test.dart \
  test/features/teacher/teacher_material_transfer_controller_test.dart \
  integration_test/stage5_e2e_support.dart
```

This command includes every expected created/modified Dart file, including the
existing mutation-response DTO and all explicitly authorized repository/adapter
compatibility files. Do not include unchanged files merely for volume.

## 69.3 Static analysis

Exactly:

```bash
flutter analyze
```

## 69.4 Diff hygiene

From repository root exactly:

```bash
git diff --check
```

Then perform the focused diff/scope self-review required by root/frontend
`AGENTS.md`.

Do not run:

- full frontend test suite;
- target build;
- backend suite;
- Stage 5 E2E;
- Stage 7 E2E;
- Frontend Phase 2;
- broad E2E/integration runner.

---

# 70. Acceptance Criteria

Implementation acceptance review requires all criteria below and the delivery in
Section 72. This contract correction does not claim current-main Readiness PASS;
the Readiness Gate remains PENDING as recorded in Section 1.

## Selection

- existing `file_picker` reused;
- safe extensions come from Question;
- selected extension/size/name revalidated;
- filename limit is 500 Unicode code points/runes, aligned with BE-006;
- current backend `max_size_bytes` used for local UX;
- no local binary/MIME trust pretends to replace backend inspection;
- cancellation neutral.

## Upload

- exact multipart PUT;
- fields exactly `type,file`;
- no Idempotency-Key;
- streaming upload;
- progress;
- Choose/Upload/Retry require `status == data`, non-null Attempt matching both
  route IDs, `in_progress`, eligible current Student/session/target, a current
  file Question, locally valid selection where required, and no active file
  picker/mutation/reconciliation operation;
- only the existing extended `StudentAttemptAnswerMutationDto` and shared
  `parseStudentAttemptAnswerValue` accept/parse a file mutation response;
- Question ID, requested type and current Question type match; file success
  requires `StudentFileAnswerUi`, non-null `StudentFileAnswerValue` and `updated_at`;
- existing non-file nullability and non-file JSON `StudentAnswerMutation`/
  `saveAnswer(...)` behavior remain unchanged;
- historical GET file parsing stays platform-cap based, while current upload
  response also satisfies current Question allowed extensions/`maxSizeBytes` and
  exact selected name/extension/length;
- exact Stage 7 whole-second UTC mutation timestamp is enforced;
- first upload and replacement both work;
- confirmed replacement preserves File ID;
- no file clear/delete.

## Reliability

- one active picker/upload/uncertain-reconciliation GET per Attempt, owned by
  `activeQuestionId`, with other valid ready selections preserved;
- timeout/unknown/invalid-success is uncertain;
- same selected file retained as local intent;
- uncertain outcome has no blind PUT retry;
- only the file-controller-owned repository `fetchAttempt(target.attemptId)`
  reconciles current server state before any later new upload;
- ordinary parent refresh cannot resolve uncertainty or destroy an omitted
  uncertain Question's snapshot/recovery state/UI;
- owned reconciliation validates session, route, Question, selected-file object,
  previous File ID and generation plus canonical returned Attempt/Homework IDs;
- invalid authoritative identities, or a missing/wrong-type current Question when
  the returned Attempt remains `in_progress`, preserve uncertainty and pending
  selection without claiming success or resending PUT;
- GET metadata equality never falsely proves exact selected bytes committed;
- `file_upload_failed` is confirmed retryable failure, but Retry is a new
  explicit action gated by current confirmed state;
- terminal parent state invalidates late picker/PUT/GET completions;
- owned file reconciliation returning terminal publishes through the parent
  terminal-acceptance boundary and invalidates older parent GET generation;
- FE-003 retains that terminal snapshot for the whole route through later parent
  `refreshing`/`error`, and its existing terminal authority also invalidates file
  picker/upload/reconciliation and clears local selections/uncertainty;
- both synchronous and emitted local source-read failures retain their typed
  distinction through Dio, preserve `serverFile`, clear operation/selection, show
  the safe source-unavailable message, refresh Attempt and require choosing again;
- local source-unavailable failure is neither server success nor a generic
  uncertain server commit;
- lifecycle errors reconcile Attempt/Homework.

## Download

- existing protected transfer reused;
- saved own submission supports Open/Save As from matching current parent `data`
  or the accepted FE-003 terminal snapshot under Section 40;
- accepted terminal snapshot keeps its saved file visible and transferable after
  later parent `refreshing`/`error` retaining older in-progress data;
- ordinary retained in-progress `refreshing`/`error` data cannot authorize transfer;
- the same authority is revalidated after download before local Open/Save As;
- `notFound`, session loss, route-target change and file-target change block/abort
  transfers under both authorities;
- response bytes checked against current saved extension/size before local action;
- terminal historical file remains readable from UI;
- no public/storage URL;
- Stage 5 Learning Material transfer remains unchanged;
- all `LocalFilePlatformAdapter` fakes/helpers compile with the dialog-title
  compatibility extension, default `Save learning material` is preserved and
  `Save submitted answer` reaches the native dialog/injected callback.

## State / Navigation

- selected file is unsaved local work;
- no nonexistent Attempt `stale` status or `isStale` property is introduced;
- `initial`/`loading`/`refreshing`/`error`/`notFound` disable new Choose/Upload/Retry;
- terminal Attempt clears upload controls and invalidates active generations;
- session/route/terminal-obsolete completions cannot publish/open/save;
- the existing FE-003 guard uses exact priority: file uncertainty, non-file
  uncertainty, combined pending/dirty changes, then direct leave;
- Stay preserves both controllers; confirmed Leave clears both local states,
  sends no PUT/upload and navigates to Homework detail;
- the focused shared Question-card presentation shell serves both editors while
  file state remains separate from non-file drafts/controller state;
- all `StudentHomeworkAttemptRepository` compatibility implementations compile
  with fail-fast upload stubs where unrelated, without weakening regressions.

## UX

- current file vs selected replacement clearly separated;
- progress/error/uncertain state textual and accessible;
- desktop/mobile responsive;
- no score/checking;
- no final Submit.

## Scope

- no new dependency;
- no protected transport rename/rewrite;
- no backend/platform/route changes;
- no Teacher review;
- no final Submit.

## Verification

- exact focused tests pass;
- exact shared-file regressions pass;
- exact Dart format check passes;
- `flutter analyze` passes, including the Stage 5 integration helper compatibility
  touch;
- `git diff --check` passes;
- final focused scope/diff self-review passes;
- only approved implementation/test/compatibility scope is staged;
- `git diff --cached --check` and focused staged-diff review pass;
- exact implementation commit is pushed on the frozen branch and a PR against
  `main` exists; Codex stops before merge and does not update Stage bookkeeping.

---

# 71. Locked Implementation Decisions

These are decisions, not suggestions:

```text
file picker = existing file_picker
file upload = explicit, not automatic after pick
transport = multipart PUT on existing answer endpoint
multipart fields = type,file
file answer Idempotency-Key = none
filename max = 500 Unicode code points/runes
allowed extensions = backend answer_ui
local size max = backend answer_ui.max_size_bytes
backend binary inspection = authoritative
file clear/delete = not available
replacement = same server File ID
Choose/Upload authority = confirmed-current in_progress Attempt only
Choose/Upload/Retry gate = exact Section 21 data + IDs + session + Question + selection + operation gate
Attempt load statuses = initial,loading,data,refreshing,notFound,error; no stale/isStale
file concurrency = one picker OR upload OR owned reconciliation GET; activeQuestionId owns it
uncertain upload = no blind PUT retry
uncertain recovery = StudentFileAnswerController -> repository.fetchAttempt(target.attemptId)
reconciliation ownership = session,route,question,selected object,previous File ID,generation
reconciliation response = canonical matching Attempt/Homework IDs; current file Question required for in_progress
ordinary parent refresh = never resolves uncertainty; retain omitted uncertain Question/recovery UI
retained selected file after reconciliation = local unsaved intent
GET Attempt metadata = not proof of exact uncertain bytes
file_upload_failed = confirmed failed; same-file Retry is a new explicit gated action
file mutation response = extend existing StudentAttemptAnswerMutationDto + shared saved-answer parser
file mutation success = matching Question/requested/current types + non-null file answer/updated_at
historical GET file policy = platform cap; current mutation also checks current Question maxSizeBytes
StudentAnswerMutation/saveAnswer = non-file JSON only; uploadFileAnswer = multipart only
file mutation updatedAt = exact YYYY-MM-DDTHH:MM:SSZ
selected source unavailable = typed local marker preserved through Dio; clear selection, keep serverFile, refresh
terminal authority = parent terminal or existing FE-003 terminalAttempt; invalidate file generations
file-owned terminal GET = parent acceptAuthoritativeTerminalAttempt publishes data and invalidates old GETs
accepted terminal snapshot = survives later refreshing/error retained in_progress parent data
protected download = reuse ProtectedLearningMaterialTransfer
saved file transfer = matching parent data OR accepted FE-003 terminal snapshot (Section 40)
retained in_progress refreshing/error = no mutation or transfer authority
transfer completion = revalidate same authority; notFound/session/target/file changes block
saved file local actions = Open + Save As
Student Save As dialog = "Save submitted answer"
terminal saved file = still downloadable
selected local file = unsaved-work guard input
leave priority = file uncertainty > non-file uncertainty > pending/dirty > direct leave
Stay = preserve both controllers; Leave = clear both local states, no PUT/upload, Homework detail
Question presentation = shared card shell; file state stays out of non-file drafts/controller
LocalFilePlatformAdapter.saveFile = required dialogTitle forwarded through native callback
Stage5 LocalFilePlatformAdapter helper = signature compatibility touch only
implementation delivery = frozen branch/commit -> push -> PR against main -> stop before merge
```

Codex must not substitute:

- upload immediately on picker return;
- UTF-8 byte-count filename limit instead of 500 Unicode code points;
- new file ID assumption on replacement;
- blind replay of uncertain upload PUT;
- filename/size equality as proof of uncertain upload success;
- checksum field exposure;
- public URL;
- duplicate protected download stack;
- client binary signature parser;
- file clear;
- final Submit;
- new package.

---

# 72. Integrated Implementation Delivery and Completion Report

After every required FE-004 implementation verification check passes, Codex must:

1. perform final focused scope/diff self-review;
2. stage only FE-004 implementation/test/explicit compatibility scope;
3. run from repository root:

   ```bash
   git diff --cached --check
   ```

4. perform focused staged-diff review;
5. commit exactly:

   ```text
   feat(stage7): add student file answer ux
   ```

6. push branch:

   ```text
   implement/s07-fe-004-file-answer-ux
   ```

7. create a PR against `main`, including focused verification and scope/non-goals
   in the PR body;
8. stop before merge; the Project Owner merges only after ChatGPT acceptance review;
9. do not update `STAGE_07_TASK_INDEX.md` or other Stage bookkeeping.

Successful implementation requires an existing PR.

Return status:

```text
IMPLEMENTATION COMPLETE
```

or:

```text
BLOCKED
```

if implementation or required focused verification fails, or:

```text
DELIVERY BLOCKED
```

if implementation/verification passes but safe delivery cannot complete,

with:

1. implementation summary;
2. changed files and purpose;
3. exact focused test results;
4. picker/Unicode-filename/local-validation evidence;
5. multipart/progress/current-safe-Question response evidence;
6. first-upload/replacement identity evidence;
7. uncertain GET-reconciliation/no-blind-retry + deterministic-failure evidence;
8. protected Open/Save As current-data/accepted-terminal authority evidence;
9. session/stale/terminal-generation/navigation-guard evidence;
10. Stage 5 shared-file + adapter-helper compatibility regression evidence;
11. desktop/mobile/accessibility evidence;
12. format/analyze results;
13. `git diff --check`;
14. scope/non-goal confirmation;
15. deviations/blockers;
16. commit SHA;
17. branch;
18. PR number;
19. PR URL;
20. final `git status --short`.

Do not claim `Accepted`, `Frontend Phase 2 PASS`, or `merged`.
