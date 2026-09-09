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
| Implementation baseline | ChatGPT re-checks/freezes current `origin/main` immediately before Codex starts |
| Readiness Gate | `PASS`, conditional on dependencies above |
| Supported surfaces | `Student desktop + mobile` |
| Verification | focused frontend tests + shared-file regressions + format/analyze + diff check |
| Delivery | Project Owner |
| Frontend block checkpoint | Stage 7 Frontend Phase 2 after `S07-FE-001…005` |

Do not create a duplicate `CODEX-PROMPT`.

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
- safe same-selection retry;
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
Retry uncertain/known-retryable upload
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

Filename UTF-8 byte length:

```text
<= 500
```

Use:

```dart
utf8.encode(name).length
```

to match the backend byte-oriented transport boundary conservatively.

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

Allow at most:

```text
one active file upload per Attempt
```

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

Observe the delivered Attempt state.

## Attempt remains `in_progress`

For each file Question:

- update `serverFile` to the latest confirmed server answer;
- preserve a local valid `selectedFile`;
- preserve an active/uncertain upload snapshot;
- remove state for Questions no longer present.

A normal GET refresh must not silently discard a Student's selected local file.

## Attempt becomes terminal

Immediately:

- clear all selected local files;
- clear active/uncertain upload state;
- update `serverFile` from authoritative Attempt;
- make file Questions read-only.

No new upload may start.

## Session/route target changes

Clear all local selections/operation ownership.

Do not carry a selected file across Student/session/Attempt targets.

---

# 17. Choose File Behavior

For an editable current `file_based` Question:

1. ensure:
   ```text
   Attempt.status = in_progress
   no active file upload
   current session/target valid
   ```
2. set Question state:
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
Attempt.status = in_progress
Question.type = file_based
selectedFile is locally valid
no active file upload for this Attempt
current session/target valid
```

Revalidate the selected file against the **current** Question `answer_ui` immediately before sending.

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
  questionId,
  file,
  onProgress,
)
```

Exact request:

```dart
dio.put<Object?>(
  '/student/attempts/${Uri.encodeComponent(attemptId)}/answers/'
  '${Uri.encodeComponent(questionId)}',
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
  questionId,
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

Reuse existing mutation-response parsing.

Do not create a second answer mutation DTO format.

---

# 24. File Mutation Response Integrity

For a valid `200` require:

```text
response.questionId == requested questionId
response.type == file_based
response.answer != null
response.answer is file
response.updatedAt != null
```

Additionally compare response file metadata with the uploaded selection:

```text
originalName == selectedFile.name
extension == selectedFile.extension
sizeBytes == selectedFile.length
```

If replacing an already saved server file, require:

```text
response.file.id == previous serverFile.id
```

because backend replacement preserves File identity.

Any mismatch is:

```text
invalidResponse
```

and therefore an uncertain mutation outcome because the server may have committed.

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

File upload has no idempotency key.

However backend mutation is a complete replacement and repeating the same chosen file is safe:

- if first request did not commit, retry can commit it;
- if first request committed, retrying the same bytes/name becomes an equivalent replace/no-op server-side.

The client cannot prove exact byte identity from a GET Attempt because the API intentionally does not expose checksum.

Therefore a plain GET reload is **not sufficient evidence** that the exact selected file committed.

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

covered below.

Store the same:

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
- show:
  ```text
  Retry upload
  ```

Retry must use:

```text
the same selected StudentSubmissionUploadFile
same attemptId
same questionId
```

No new picker selection may start until uncertainty is resolved or the Student leaves the route/session.

---

# 30. Retry Upload

`Retry upload` reopens the same selected file stream through:

```text
selectedFile.openRead
```

and sends the same multipart semantic content/name.

If valid `200` returns:

- confirm success normally.

If uncertain again:

- keep same pending selection.

If deterministic failure:

- clear uncertainty and apply the deterministic failure rules.

Do not generate any idempotency key.

---

# 31. Stream Reopen Failure

If retry cannot open/read the previously selected file before a valid server outcome is obtained:

- stop retry;
- clear active network state;
- show:
  ```text
  The selected file is no longer available. Choose the file again.
  ```
- clear the stale local selection;
- refresh Attempt to show current server state.

Do not claim whether the earlier upload committed.

---

# 32. Reload During Uncertain Upload

The Student may manually refresh/re-enter the Attempt through the existing FE-002 GET.

The refreshed `serverFile` is authoritative for current server state.

But while the same controller still owns an unresolved uncertain upload:

- a GET showing matching filename/size/extension does **not** confirm exact selected bytes;
- do not automatically mark the uncertain upload as saved.

The only in-place confirmation path is:

```text
Retry upload -> valid 200
```

If the Student explicitly leaves the route after the warning:

- discard local retry state;
- next entry starts from server GET state;
- the Student may choose/upload the desired file again.

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
- allow:
  ```text
  Retry upload
  ```
  using the same file;
- keep existing `serverFile`;
- show:
  ```text
  The file could not be stored. Try again.
  ```

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

Session failures follow existing Student session reconciliation.

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

For any confirmed saved `serverFile`, including terminal Attempts, provide:

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

Resolve from the current FE-002 Attempt controller state.

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

After download and before local action, re-check current saved server file.

If an Attempt refresh changed/removed the file target:

- abandon local action;
- publish no stale success feedback.

Late completion after session/route disposal must not open/save a file.

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

Current:

```text
LocalFileActions.saveAs(...)
```

hardcodes the native dialog text:

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

Extend adapter method with required/explicit:

```text
dialogTitle
```

and native `FilePicker.saveFile(...)` uses it.

Existing learning-material callers that omit the argument retain exactly:

```text
Save learning material
```

Student submission transfer passes:

```text
Save submitted answer
```

No other behavior changes.

Update affected test fakes.

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

Integrate into the FE-003 common Question surface.

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

Disable file picker/upload controls for file Questions while one file upload is active.

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

If parent Attempt refresh becomes terminal during:

```text
selecting
ready
failure
```

clear local selection and switch read-only.

If upload is currently in flight and server finalization wins:

backend returns a deterministic lifecycle error or the subsequent refresh becomes terminal.

Then:

- clear selected file;
- no retry;
- show authoritative terminal Attempt state.

If upload committed before finalization:

GET refresh shows the saved file and terminal state.

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
Leaving will discard the retry state. Re-opening the attempt will reload server data.
```

Do not automatically upload on leave.

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

Other saved file Questions may remain downloadable.

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

FE-003 mutation response parser reuses the saved-answer parser.

FE-004 must extend/reuse those exact models.

Do not create a second:

```text
StudentUploadedFile
StudentAnswerFileDto
```

with overlapping shape unless a direct existing type cannot represent the contract.

One canonical saved Student submission model.

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
- Retry upload accessible by keyboard/touch;
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
frontend/lib/features/student/data/student_homework_attempt_remote_data_source.dart
frontend/lib/features/student/data/student_homework_attempt_repository_impl.dart

frontend/lib/features/student/application/student_attempt_answer_editor_state.dart
frontend/lib/features/student/presentation/student_homework_attempt_screen.dart
frontend/lib/features/student/presentation/student_question_answer_editor.dart
frontend/lib/features/student/presentation/student_homework_formatters.dart

frontend/lib/core/files/local_file_actions.dart

frontend/test/core/network/protected_learning_material_transfer_test.dart
```

Modify FE-002/003 saved-answer DTO/parser only as required for safe reuse/invariants.

Update existing Student/Teacher file-transfer test fakes only as required by the `dialogTitle` adapter parameter.

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
- filename UTF-8 byte boundary;
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
fields:
  type = file_based
files:
  file filename exact
no query
no Idempotency-Key
followRedirects = false
sendTimeout = 5 minutes
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
- wrong type;
- selected name/size/extension mismatch;
- replacement returns different File ID;
- extra storage/checksum fields;
- malformed updated_at.

No automatic retry.

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
- Retry uses same upload object;
- picker/new upload disabled;
- repeated uncertainty preserved.

## `file_upload_failed`

- confirmed failure;
- selected file retained;
- Retry allowed.

## unsupported/too-large

- selection cleared;
- existing server file retained.

## lifecycle

- deadline/non-editable refreshes parent;
- terminal parent clears selections.

## stale/session

- Student/session/route/dispose stale completion ignored.

---

# 64. Protected Submission Transfer Tests

`student_submission_transfer_controller_test.dart` covers:

## Current saved file

- Open downloads `/files/{id}/download`;
- Save As downloads same endpoint;
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

to `LocalFileActions`.

## Open

No-app outcome gives safe feedback.

## Download errors

- 404 -> Attempt refresh;
- file_not_available;
- timeout;
- connection;
- invalid protected response.

## Historical terminal Attempt

Open/Save As remains permitted by frontend; backend remains authority.

## Stale target

If current Attempt/file changes before local action, old transfer does nothing.

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
- Retry upload only;
- no choose-new-file action.

## Errors

- unsupported;
- too large;
- file upload failed retry;
- lifecycle terminal transition.

## Terminal

- no picker/upload;
- saved file Open/Save As still shown;
- unanswered file Question shows no file submitted.

No score/checking.

---

# 67. Navigation Guard Regression

Extend FE-003 navigation tests:

- pending file selection triggers unsaved warning;
- discard/leave sends no upload;
- uncertain file upload triggers uncertainty warning;
- Stay preserves retry state;
- Leave clears local file retry state;
- clean file state does not add confirmation.

If non-file dirty draft and uncertain file upload coexist:

```text
uncertain outcome warning takes priority
```

because server outcome ambiguity is more important than ordinary local unsaved work.

---

# 68. Directly Affected Regression Tests

Run FE-004 tests plus:

```text
test/features/student/student_answer_editor_controller_test.dart
test/features/student/student_answer_editor_screen_test.dart

test/features/student/student_homework_attempt_dto_test.dart
test/features/student/student_homework_attempt_data_test.dart
test/features/student/student_homework_attempt_controller_test.dart
test/features/student/student_homework_attempt_screen_test.dart

test/core/network/protected_learning_material_transfer_test.dart
test/features/student/student_topic_detail_transfer_controller_test.dart
test/features/teacher/teacher_material_transfer_controller_test.dart
```

Use actual delivered filenames if FE-001…003 naming differs slightly and report the exact mapping.

Do not run the full frontend suite in this individual task.

---

# 69. Verification

From:

```text
frontend/
```

Run:

```bash
flutter test \
  test/features/student/student_submission_upload_test.dart \
  test/features/student/student_file_answer_data_test.dart \
  test/features/student/student_file_answer_controller_test.dart \
  test/features/student/student_submission_transfer_controller_test.dart \
  test/features/student/student_file_answer_screen_test.dart \
  test/features/student/student_answer_editor_controller_test.dart \
  test/features/student/student_answer_editor_screen_test.dart \
  test/features/student/student_homework_attempt_dto_test.dart \
  test/features/student/student_homework_attempt_data_test.dart \
  test/features/student/student_homework_attempt_controller_test.dart \
  test/features/student/student_homework_attempt_screen_test.dart \
  test/core/network/protected_learning_material_transfer_test.dart \
  test/features/student/student_topic_detail_transfer_controller_test.dart \
  test/features/teacher/teacher_material_transfer_controller_test.dart
```

Run format over changed task-owned Dart files:

```bash
dart format --output=none --set-exit-if-changed <changed Dart files>
```

Run:

```bash
flutter analyze
```

Then repository root:

```bash
git diff --check
```

and focused diff/scope self-review.

Do not run:

- full frontend test suite;
- target build;
- backend suite;
- broad E2E/integration runner.

---

# 70. Acceptance Criteria

PASS only if all are true.

## Selection

- existing `file_picker` reused;
- safe extensions come from Question;
- selected extension/size/name revalidated;
- current backend `max_size_bytes` used for local UX;
- no local binary/MIME trust pretends to replace backend inspection;
- cancellation neutral.

## Upload

- exact multipart PUT;
- fields exactly `type,file`;
- no Idempotency-Key;
- streaming upload;
- progress;
- first upload and replacement both work;
- confirmed replacement preserves File ID;
- no file clear/delete.

## Reliability

- one active file upload per Attempt;
- timeout/unknown/invalid-success is uncertain;
- same selected file retained;
- Retry uses same file;
- GET metadata alone never falsely proves exact selected bytes committed;
- `file_upload_failed` is confirmed retryable failure;
- lifecycle errors reconcile Attempt/Homework.

## Download

- existing protected transfer reused;
- saved own submission supports Open/Save As;
- response bytes checked against current saved extension/size before local action;
- terminal historical file remains readable from UI;
- no public/storage URL;
- Stage 5 Learning Material transfer remains unchanged.

## State / Navigation

- selected file is unsaved local work;
- terminal Attempt clears upload controls;
- session/route stale completions cannot publish/open/save;
- pending/uncertain file work participates in FE-003 leave protection.

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

- focused tests pass;
- shared-file regressions pass;
- format passes;
- `flutter analyze` passes;
- `git diff --check` passes;
- focused self-review passes.

---

# 71. Locked Implementation Decisions

These are decisions, not suggestions:

```text
file picker = existing file_picker
file upload = explicit, not automatic after pick
transport = multipart PUT on existing answer endpoint
multipart fields = type,file
file answer Idempotency-Key = none
allowed extensions = backend answer_ui
local size max = backend answer_ui.max_size_bytes
backend binary inspection = authoritative
file clear/delete = not available
replacement = same server File ID
upload uncertain retry = same selected file
GET Attempt metadata = not proof of exact uncertain bytes
file_upload_failed = confirmed failed, retryable same file
protected download = reuse ProtectedLearningMaterialTransfer
saved file local actions = Open + Save As
Student Save As dialog = "Save submitted answer"
terminal saved file = still downloadable
selected local file = unsaved-work guard input
```

Codex must not substitute:

- upload immediately on picker return;
- new file ID assumption on replacement;
- filename/size equality as proof of uncertain upload success;
- checksum field exposure;
- public URL;
- duplicate protected download stack;
- client binary signature parser;
- file clear;
- final Submit;
- new package.

---

# 72. Completion Report

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
3. exact focused test results;
4. picker/local-validation evidence;
5. multipart/progress evidence;
6. first-upload/replacement identity evidence;
7. uncertain/retry and deterministic-failure evidence;
8. protected Open/Save As evidence;
9. session/stale/navigation-guard evidence;
10. Stage 5 shared-file regression evidence;
11. desktop/mobile/accessibility evidence;
12. format/analyze results;
13. `git diff --check`;
14. scope/non-goal confirmation;
15. deviations/blockers;
16. final `git status --short`.

Do not claim `Accepted`.

Do not commit/push/create PR/update Stage bookkeeping unless explicitly instructed later.
