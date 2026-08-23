# S05-FE-003 — Teacher Learning Material Management

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S05-FE-003` |
| Stage | `Stage 5 — Topics and Learning Materials` |
| Area | `Frontend` |
| Status | `Approved` |
| Depends on | `S05-FE-002 Accepted / Delivered` |
| Planning/readiness baseline | `origin/main @ a407cf9250357f7d4a674da806a52f469476ba51` |
| Backend gate | `S05-BE-001…005 Accepted / Delivered; Backend Phase 2 PASS` |
| Verification model | `Workflow v3 — Lean Verification` |
| Approved new dependencies | `file_picker: ^12.0.0`, `open_file: ^4.0.0` |
| Implementation baseline | `Must be re-frozen from current origin/main after S05-FE-002 Accepted / Delivered` |

This file is the complete implementation contract for `S05-FE-003`.

Codex must read only:

1. this task;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. directly relevant frontend source/tests needed to implement this task.

Codex must not read product specifications, roadmap files, Stage history,
previous task files, checkpoint reviews, closure reviews, or architecture/API
documents to rediscover requirements.

### Mandatory implementation-entry gate

This contract may be prepared and stored before `S05-FE-002` implementation,
but Codex must **not** implement it until orchestration has confirmed:

```text
S05-FE-002 = Accepted / Delivered
current origin/main re-checked
actual FE-001/FE-002 Teacher feature/routes/providers/tests inspected
this contract still matches current implementation
clean synchronized local main
```

If the delivered FE-002 implementation materially conflicts with local names or
wiring assumed by this contract, preserve the behavior below and adapt only the
implementation wiring. Do not invent product/API/security/file/lifecycle
behavior.

---

# 2. Goal

Add production-quality Teacher Learning Material management to the desktop Topic
Detail experience created by `S05-FE-002`.

An authenticated Teacher on desktop must be able to:

- view current Learning Materials for a readable Topic;
- view current effective upload capability;
- upload PDF, DOCX, PPT, or PPTX;
- optionally assign a display title;
- replace a current Material's file while preserving logical identity;
- update/clear a Material display title;
- remove a current Material when backend editability permits;
- securely download a current Material;
- securely open a downloaded Material with the operating system's associated
  application;
- reconcile authoritative server state after every mutation;
- remain safe across session, route, Topic, Material, and asynchronous changes.

The Laravel backend remains authoritative for:

```text
Institution scope
Teacher ownership
current Teacher–Group membership
Topic read scope
Topic/Group editability
Material/File current state
actual file content/type
actual byte size
effective Institution upload limit
private storage location
download authorization
mutation success
```

---

# 3. Device Boundary

This task is **Teacher desktop material management only**.

Desktop supports:

```text
list
upload
replace
edit title
remove
download
open
save as
```

Teacher mobile does not gain Learning Material management in this task.

Do not add mobile:

```text
upload
replace
rename
remove
download/open controls
```

The mobile Topic Detail behavior from S05-FE-002 remains unchanged.

Do not add a separate mobile Materials route.

---

# 4. Scope

## Included

- Learning Materials section integrated into desktop Teacher Topic Detail.
- Material list + effective upload capability.
- Single-file upload.
- Optional Material display title.
- File replacement.
- Material title edit/clear.
- Historical/non-destructive Material remove intent.
- Protected authenticated binary download through the shared `core/files` boundary.
- Native Save As.
- Native Open via temporary local file.
- Upload and download progress.
- Backend-authoritative mutation reconciliation.
- File-transfer-specific timeout overrides.
- Exact Material DTO/resource parsing.
- Binary API-error parsing enhancement for the existing core network pipeline.
- Stable file error machine codes.
- Approved package additions:
  - `file_picker: ^12.0.0`
  - `open_file: ^4.0.0`
- Focused frontend tests.
- Windows debug build because this task introduces native desktop plugins.

## Explicit non-goals

Do not implement:

- Student Topic/material UI;
- Teacher mobile Material actions;
- Parent file access;
- Institution Admin file access;
- Material version-history UI;
- Material reorder;
- file preview/rendering inside Flutter;
- document conversion;
- OCR;
- antivirus scanning;
- cloud-specific SDK integration;
- direct storage paths/keys;
- public or signed file URLs;
- offline file cache/synchronization;
- background transfer service;
- persistent local file library;
- `path_provider`;
- `permission_handler`;
- `file_saver`;
- `http`;
- `mime`;
- any package except the two explicitly approved above;
- backend/API/schema changes;
- FE-004 Student implementation;
- full frontend suite;
- Android build;
- broad E2E.

---

# 5. Reuse Contract

Reuse the delivered Teacher feature created by FE-001/FE-002.

Expected logical structure remains:

```text
frontend/lib/features/teacher/
  application/
  data/
  domain/
  presentation/
```

Reuse existing project infrastructure:

```text
configured Dio
AuthTokenInterceptor
DioFailureMapper
ApiFailure
ApiRequestException
ApiErrorCodes
AuthSessionController
SessionInvalidationSignal
AppDeviceSurface
GoRouter
Riverpod
```

Reuse FE-002:

```text
Teacher Topic Detail
Teacher Topic domain/resource
Topic-detail session/target ownership
Topic lifecycle controllers/state
Topic list invalidation/stale handling
```

Do not create a second Topic cache or a separate Teacher networking stack.

## 5.1 Shared protected file-transfer boundary

`S05-FE-004` is already approved and must use the same protected
`GET /files/{file}/download` flow for Student desktop/mobile. Therefore the
download/Open/Save transport-platform behavior is confirmed shared
infrastructure and must be placed in a neutral focused boundary **during
S05-FE-003**, not implemented under `features/teacher` and extracted later.

Create a small shared location such as:

```text
frontend/lib/core/files/
  protected_learning_material_transfer.dart
  protected_download_metadata.dart
  local_file_actions.dart
```

Equivalent focused names are acceptable.

The shared boundary may own only responsibilities genuinely common to Teacher
and Student:

```text
authenticated protected binary GET by File UUID
ResponseType.bytes and file-transfer timeout/progress
trusted download response/header validation
safe Content-Disposition filename parsing
binary API-error compatibility through existing core network pipeline
native Save As
temporary-file Open
small injectable platform adapter around file_picker/open_file
```

It must **not** own:

```text
Teacher Material list/mutations
Student Topic/Material state
role-specific authorization assumptions
Topic lifecycle rules
Material editability
```

Teacher application/controllers own Teacher session/Topic/Material operation
state and call this shared boundary.

Do not create a universal storage/download framework beyond the protected Stage
5 Learning Material use case.

Learning Material responsibilities follow:

```text
Presentation
→ focused Controller / State
→ typed Repository
→ Remote Data Source
→ configured Dio
```

Widgets must not call Dio directly, parse multipart/raw JSON, write private app
storage, or interpret backend authorization/lifecycle rules.

---

# 6. Approved Dependencies

Add exactly:

```yaml
file_picker: ^12.0.0
open_file: ^4.0.0
```

The implementation baseline uses Flutter `3.44.7` / Dart `^3.12.2`.

Do not add other dependencies.

## 6.1 `file_picker`

Use for:

- native single-file selection;
- extension-filtered selection;
- on-demand streaming reads for upload;
- native Save As dialog.

Use v12 APIs.

For single file selection prefer:

```dart
FilePicker.pickFile(...)
```

For upload bytes use on-demand streaming:

```dart
PlatformFile.readAsByteStream()
PlatformFile.length()
```

Do not request eager whole-file bytes for upload.

## 6.2 `open_file`

Use only to ask the OS to open a local temporary file.

Do not treat `open_file` success as backend/download success. Download must
complete and local file writing must complete first.

Plugin errors are mapped to safe UX text; do not display raw plugin/native
exception messages.

---

# 7. Backend Endpoints

Configured Dio base URL already owns `/api/v1`.

Use exactly:

```text
GET    /teacher/topics/{topic}/materials
POST   /teacher/topics/{topic}/materials
POST   /teacher/materials/{material}/replace
PATCH  /teacher/materials/{material}
DELETE /teacher/materials/{material}
GET    /files/{file}/download
```

Do not create alternative routes.

---

# 8. Teacher Learning Material Resource

Strictly parse this exact resource:

```json
{
  "id": "material-uuid",
  "topic_id": "topic-uuid",
  "title": "Lesson slides",
  "file": {
    "id": "file-uuid",
    "original_name": "lesson.pptx",
    "mime_type": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "extension": "pptx",
    "size_bytes": 1250000
  },
  "created_at": "2026-08-07T15:00:00Z",
  "updated_at": "2026-08-07T15:00:00Z"
}
```

Exact Material keys:

```text
id
topic_id
title
file
created_at
updated_at
```

Exact nested File keys:

```text
id
original_name
mime_type
extension
size_bytes
```

Reject unknown/missing keys.

Validate:

- Material/File IDs are UUIDs;
- `topic_id` matches the owning Topic requested by the controller/repository;
- `title` is nullable; when non-null it is a non-empty string;
- `original_name` is a non-empty string;
- `extension` is exactly one of:
  - `pdf`
  - `docx`
  - `ppt`
  - `pptx`
- MIME must match the canonical backend MIME for the extension;
- `size_bytes` is an integer `>= 1`;
- timestamps are strict UTC `...Z`;
- Material IDs are unique in one list;
- File IDs are unique in one current list.

Do not expose or model as public client authority:

```text
institution_id
teacher_id
uploaded_by_user_id
storage_disk
storage_key
checksum_sha256
removed_at
```

---

# 9. Material List and Upload Capability

Endpoint:

```text
GET /teacher/topics/{topic}/materials
```

Send:

```text
no body
no query parameters
```

Expected success:

```text
200
```

Exact top-level shape:

```json
{
  "data": [],
  "meta": {
    "upload": {
      "max_size_bytes": 20971520,
      "platform_max_size_bytes": 26214400,
      "allowed_extensions": ["pdf", "docx", "ppt", "pptx"]
    }
  }
}
```

No success `message`.

## 9.1 Capability validation

Strictly validate:

```text
max_size_bytes >= 1
platform_max_size_bytes = 26_214_400
max_size_bytes <= platform_max_size_bytes
allowed_extensions exactly contains pdf/docx/ppt/pptx with no duplicates
```

Do not hardcode the Institution effective limit.

The list response is authoritative for current UX capability only. Mutation
backend validation remains final authority.

## 9.2 List ordering

Preserve backend order.

Do not sort Materials locally.

## 9.3 States

The Material section supports:

```text
initial loading
data
empty
refreshing while retaining confirmed data
error + retry
```

Topic Detail and Material section failures are separate:

- a Material-list failure must not erase an already confirmed Topic Detail;
- Topic unreadable/not-found must close/clear Material ownership as part of the
  parent Topic boundary.

---

# 10. Topic Detail Integration

Add a desktop section:

```text
Learning Materials
```

to the actual FE-002 Topic Detail.

Do not add a new `/materials` page unless delivered FE-002 structure makes an
embedded section technically impossible; if so, stop and report the conflict
instead of inventing navigation.

For each Material show:

```text
display title when non-null
otherwise original filename
original filename as secondary text when a custom title exists
extension/type label
human-readable size
updated/created presentation where useful
```

Status/actions must not rely on color alone.

## 10.1 Read-only vs editable projection

Material list/download is allowed for readable historical Topics.

Mutation controls are shown only when current Topic Detail indicates:

```text
Group status = active
Topic status = draft OR active
```

This is UX projection only.

Backend remains authoritative and may return `409 topic_not_editable` after a
concurrent change.

For:

```text
closed Topic
archived Topic
archived Group
```

show read-only Material list + protected download/open/save controls.

Do not hide historical Materials merely because Topic mutation is unavailable.

---

# 11. Upload UX

Desktop button:

```text
Upload material
```

Open a focused dialog/surface with:

```text
File *
Title (optional)
```

Helper text:

```text
Leave the title empty to use the original file name.
```

Show current capability:

```text
Allowed: PDF, DOCX, PPT, PPTX
Maximum size: <current effective MiB/bytes>
```

## 11.1 File picker

Use native single-file selection:

```text
allowed extensions = pdf, docx, ppt, pptx
```

Picker filtering is UX only.

Do not inspect OOXML/OLE/PDF internals in Flutter.

Backend determines actual supported file type.

## 11.2 Local pre-validation

After selection:

- obtain `PlatformFile.length()`;
- reject `0` bytes locally;
- reject size `> current meta.upload.max_size_bytes`;
- extension check is case-insensitive;
- reject missing/unsupported selected filename extension;
- title:
  - optional;
  - trim;
  - blank → omit/null rather than send empty string;
  - non-null max 255 Unicode code points.

Do not treat local size/extension checks as security authority.

Do not attempt to reproduce backend 500-byte filename validation exactly from a
Dart character count. Backend remains authoritative.

## 11.3 Multipart request

Endpoint:

```text
POST /teacher/topics/{topic}/materials
```

Use multipart/form-data with exactly:

```text
file
title when non-null
```

No query parameters.

Build file upload from:

```text
PlatformFile.readAsByteStream()
PlatformFile.length()
original selected filename
```

using Dio streaming multipart APIs.

Do not read the whole upload into a single `Uint8List`.

Expected success:

```text
201
{
  "data": { "...exact Material resource..." }
}
```

No success message is required.

Returned:

```text
material.topic_id == current Topic ID
```

must hold.

---

# 12. Upload Progress and Operation Ownership

Show progress when total bytes are known using Dio `onSendProgress`.

Progress is presentation-only.

During upload:

- suppress duplicate submit;
- disable conflicting Material mutations;
- disable FE-002 lifecycle mutation controls on the same Topic Detail;
- keep current Topic/Material data visible where safe;
- prevent stale route/session completion from showing success or navigation.

Do not add an in-flight network Cancel action after upload dispatch.

A picker/dialog may be canceled before dispatch.

---

# 13. Upload Outcome Uncertainty

Upload creates a server-generated Material UUID and may commit before the client
receives a trusted response.

Never automatically replay an ambiguous upload.

Treat post-dispatch outcome as unknown for:

```text
connection interruption
timeout
malformed/unexpected success response
unexpected status/error pairing where persistence cannot be proven
other transport ambiguity
```

Do not claim definitive failure when commit may have occurred.

After unknown upload outcome:

1. mark the Material section stale;
2. perform one authoritative Material-list refresh when still owned by the same
   current Topic/session;
3. show:

```text
Upload outcome could not be confirmed. Review the current materials before uploading again.
```

Do not infer success by filename alone because duplicate filenames/files are
allowed and no client idempotency key exists.

Do not automatically issue another POST.

---

# 14. Confirmed Upload

On confirmed `201`:

- validate returned Material;
- mark Material list stale/invalidate it narrowly;
- refresh/reconcile authoritative Material list;
- keep Topic Detail current;
- show one success notification:

```text
Learning material uploaded.
```

Do not append a speculative local row as authoritative Material state.

Because activation readiness depends on current server Material state, once
Material list refresh confirms at least one current Material, FE-002's Activate
button remains governed by its existing Topic lifecycle presentation and backend
authority. Do not add client-side activation authority.

---

# 15. Replace File

Action:

```text
Replace file
```

Only for mutation-eligible Topic state.

Require confirmation before dispatch.

Suggested confirmation:

```text
Replace this file?
```

For active Topic, explain:

```text
Students may already be using this material. The current file will be replaced.
```

Do not imply historical DB deletion.

## 15.1 Picker/pre-validation

Use the same allowed extension and effective size UX as upload.

No title field is accepted by replace.

## 15.2 Request

Endpoint:

```text
POST /teacher/materials/{material}/replace
```

Multipart exact field:

```text
file
```

No title.
No query.

Use streaming multipart.

Expected success:

```text
200
{
  "data": { "...exact Material resource..." },
  "message": "Learning material replaced successfully."
}
```

Strictly validate:

```text
returned Material.id == requested Material.id
returned File.id == previous Material.file.id
returned topic_id == current Topic.id
returned title == previous Material.title
```

File metadata may change.

Do not require timestamp change as the only proof of success.

---

# 16. Replace Outcome Uncertainty

Never automatically replay replace after an ambiguous result.

The logical Material/File IDs remain known, but the public API does not expose a
checksum or storage generation, so a list refresh cannot always prove which
binary bytes won a concurrent/ambiguous replacement.

After unknown replace outcome:

1. refresh authoritative Material list once;
2. show the current authoritative Material/File metadata;
3. show:

```text
Replacement outcome could not be confirmed. Review the current material before replacing it again.
```

Do not claim failure or success solely because filename/size matches.

Do not automatically issue another replace POST.

---

# 17. Edit Material Title

Action:

```text
Edit title
```

Only for mutation-eligible Topic state.

Form field:

```text
Title
```

The user may explicitly choose:

```text
Use original file name
```

which maps to:

```json
{"title": null}
```

Non-null title:

```text
trim
non-empty
max 255 Unicode code points
```

## 17.1 No-op

If normalized desired title equals current authoritative title:

```text
do not send PATCH
show "No changes to save."
```

## 17.2 Request

Endpoint:

```text
PATCH /teacher/materials/{material}
```

Exact JSON:

```json
{"title": "Updated title"}
```

or:

```json
{"title": null}
```

No query parameters.

Expected success:

```text
200
{
  "data": { "...exact Material resource..." },
  "message": "Learning material updated successfully."
}
```

Strictly require returned Material/File/Topic identity to match the current
resource.

---

# 18. Title-Update Unknown Outcome

Do not automatically repeat PATCH after an ambiguous result.

Reconcile via authoritative Material-list GET.

If current server Material with the same ID has the normalized requested title:

```text
treat as reconciled success
```

Otherwise:

- show current authoritative title;
- show:

```text
Title update outcome could not be confirmed.
```

If refresh cannot complete, retain an outcome-unknown state and expose:

```text
Check current materials
```

which performs only GET.

---

# 19. Remove Material

Action:

```text
Remove material
```

Only for mutation-eligible Topic state.

Require confirmation:

```text
Remove this learning material?
```

Explain:

```text
The material will no longer be available through the current Topic. Historical server records are preserved.
```

Do not use destructive hard-delete language.

## 19.1 Request

Endpoint:

```text
DELETE /teacher/materials/{material}
```

No body.
No query.

Expected success:

```text
204 No Content
```

A JSON body on a purported successful 204 is not required/parsed as business
data.

Do not require another Material to remain after remove.

Do not prevent removing the last current Material from an already active Topic;
activation readiness is evaluated at activation time by the backend.

---

# 20. Remove Outcome Uncertainty

Never automatically replay DELETE after an ambiguous result.

Reconcile via Material-list GET.

If the Material ID is absent from the authoritative current list:

```text
treat removal as reconciled success
```

If it remains:

```text
removal outcome is not confirmed
```

Do not infer historical deletion state because removed rows intentionally
disappear from the current API.

If reconciliation GET fails, expose:

```text
Check current materials
```

and do not automatically DELETE again.

---

# 21. `409 topic_not_editable`

Upload/replace/title-update/remove may race with Topic/Group lifecycle.

For:

```text
409 topic_not_editable
```

do not guess the exact cause.

Required behavior:

1. refresh Topic Detail authority;
2. refresh Material list if Topic remains readable;
3. disable mutation controls when refreshed Topic/Group is not editable;
4. show:

```text
Learning materials are no longer editable in the current Topic state.
```

Do not parse backend human messages.

If Topic refresh becomes `404`, clear Material ownership and use FE-002's generic
unavailable Topic handling.

---

# 22. Protected File Download

Endpoint:

```text
GET /files/{file}/download
```

Use configured authenticated Dio.

Send:

```text
no body
no query parameters
```

Never send:

```text
storage_disk
storage_key
path
topic_id as authorization
material_id as authorization
```

Use the current File UUID only.

Backend independently authorizes Teacher scope.

## 22.1 Response mode

Request binary data using:

```text
ResponseType.bytes
```

The task's hard platform maximum is 25 MiB per Learning Material file, so one
explicit download may be buffered in memory for native Save As.

Do not use this approach for arbitrary future large files.

## 22.2 Success headers

A successful download must have:

```text
200
Content-Type
Content-Disposition: attachment
Cache-Control: private, no-store
X-Content-Type-Options: nosniff
```

Use current response headers as authoritative download metadata because the
File's binary metadata may have changed via concurrent replace while preserving
the same File UUID.

Do not rely only on the Material snapshot's original filename/MIME/extension.

Validate supported Content-Type against the four Stage 5 canonical material
types.

Parse the server-generated `Content-Disposition` only for its expected
attachment filename parameters.

Provide a small focused parser for:

```text
filename*=UTF-8''...
filename="..."
```

Prefer valid UTF-8 `filename*` when present.

Sanitize the resulting local suggestion against:

```text
CR
LF
NUL
path separators
control characters
"." / ".."
```

If the header is malformed or filename unusable, use:

```text
download.<extension inferred from canonical response Content-Type>
```

Do not trust a filename to choose authorization or MIME behavior.

## 22.3 Download size

Do not trust `Content-Length` as authorization.

Reject obviously impossible client result if successfully buffered bytes are:

```text
empty
> 26_214_400
```

as invalid response.

Institution lower upload limits do not retroactively make previously valid
stored files unreadable; download must not compare to current Institution upload
limit.

---

# 23. Binary API Error Parsing Enhancement

Current shared API error parsing expects a JSON object.

For binary `ResponseType.bytes` requests, Dio may expose an API JSON error
envelope as bytes.

Enhance the existing core parser additively so:

```text
ApiErrorResponse.tryParse(Object?)
```

also accepts a small `List<int>`/`Uint8List` containing UTF-8 JSON.

Rules:

1. keep existing Map behavior unchanged;
2. accept at most `64 KiB` of binary candidate error data;
3. strict UTF-8 decode; malformed UTF-8 → not parseable;
4. JSON decode;
5. pass decoded Map through the existing parser;
6. non-object/scalar/list JSON is not a valid API error;
7. do not treat arbitrary downloaded file bytes as error JSON;
8. do not log candidate bytes.

This allows the existing:

```text
AuthTokenInterceptor
DioFailureMapper
ApiFailure
SessionInvalidationSignal
```

to keep working for protected binary download errors.

Do not create a second download-specific auth/error pipeline.

Add focused core network tests proving `401 authentication_required` encoded as
bytes still invalidates only the current authenticated session.

---

# 24. Download Error Mapping

Add stable frontend codes not already introduced by FE-002:

```dart
unsupportedFileType = 'unsupported_file_type'
fileTooLarge = 'file_too_large'
fileUploadFailed = 'file_upload_failed'
fileNotAvailable = 'file_not_available'
```

`topicNotEditable` is expected from FE-002.

Do not add future Stage codes.

Safe UX:

### `404 resource_not_found`

```text
This learning material is no longer available.
```

Refresh Material list.

Do not disclose whether it was removed, foreign, unassigned, or otherwise out of
scope.

### `500 file_not_available`

```text
The file is temporarily unavailable. Try again.
```

Do not remove the Material from the list solely because backing storage is
temporarily unavailable.

### Authentication/session authority errors

Reuse existing session reconciliation.

### Malformed/unsupported successful binary response

```text
The server returned an unexpected file response.
```

Do not write/open/save it.

---

# 25. Save As

Desktop action:

```text
Save as…
```

Flow:

```text
authorized binary GET
→ validate response/status/headers/bytes
→ FilePicker.saveFile(...)
```

Use authoritative server download filename as `fileName`.

Use authoritative response MIME as `mimeType`.

`file_picker 12` requires bytes for Save As.

If user cancels the save dialog:

```text
no error
no success notification
```

If save succeeds:

```text
show a short success confirmation
```

Do not persist selected local path as app authority/state.

Do not request broad filesystem permission.

---

# 26. Open

Desktop action:

```text
Open
```

Flow:

```text
authorized binary GET
→ validate response/status/headers/bytes
→ write to unique app/system temporary path
→ OpenFile.open(...)
```

Use `dart:io` `Directory.systemTemp`.

Create/use a focused TestLabUz subdirectory under system temp.

For the actual temp filename prefer a safe generated name tied to current
File UUID + canonical extension, e.g.:

```text
<file-uuid>.<extension>
```

Do not use unsanitized original filename as a filesystem path component.

Write bytes only after a trusted complete download.

Call `open_file` using the canonical response MIME when supported by the plugin
API.

If the OS has no associated application or open fails:

```text
No application is available to open this file. Save the file instead.
```

Do not expose native result/error strings.

Temporary copies are disposable local artifacts, not domain cache.

Do not promise immediate physical deletion while an external Office/PDF
application may still have the file open.

Do not implement a persistent temp-file cleanup subsystem in this task.

---

# 27. File Transfer Timeouts

The shared configured Dio defaults remain unchanged for normal API calls.

For upload and replace only, override per request:

```text
sendTimeout = 5 minutes
```

Keep existing connection timeout.

For protected download only, override per request:

```text
receiveTimeout = 5 minutes
```

Do not globally increase all API timeouts.

A timeout after mutation dispatch is an outcome-unknown mutation and follows
Sections 13/16/18/20.

A timeout during protected GET is a normal download failure; it is safe for the
user to retry because GET is non-mutating.

---

# 28. Download Progress

Use Dio receive progress where available for the protected GET.

Show determinate progress only when total length is known and meaningful.

Otherwise show indeterminate progress.

Progress must not be treated as proof of complete/trusted download.

Only final validated response completion may enable Save/Open result handling.

---

# 29. Cross-Operation Coordination with FE-002 Lifecycle

Do not create a new global mutex.

Within the same Topic Detail:

```text
lifecycle mutation active
→ disable material mutation actions

material mutation active
→ disable lifecycle mutation actions
```

Download/Open/Save may remain independently available when safe, but do not
allow them to reuse a Material currently being replaced/removed by the same
client operation.

Backend remains final concurrency authority.

A server-side concurrent change from another client is reconciled via the
authoritative response/error + Topic/Material refresh.

---

# 30. Async Ownership

Material operations must bind publication to:

```text
authenticated Teacher user ID
current AuthUser instance/session identity
Institution ID
desktop AppDeviceSurface
current Topic ID
current Material ID/File ID where applicable
latest operation generation
route ownership
```

A stale completion must not:

- update another Topic's Material section;
- overwrite a newer Material list;
- show a Snackbar in a replacement session;
- open/save a file after route/session ownership changed;
- reconcile/remove the wrong Material;
- close a newer dialog;
- trigger FE-002 lifecycle UI changes for another Topic.

Dispose/session/route changes invalidate owned in-flight publication.

Do not use widget `mounted` as the only async-ownership protection.

---

# 31. Session and Security

Material management eligibility requires:

```text
authenticated
role = teacher
user active
must_change_password = false
non-empty institution_id
user.institution.id == institution_id
institution.status = active
desktop surface
```

For:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

clear protected task-owned state and use existing auth/session reconciliation.

The backend remains authoritative for Material/file existence and access.

Do not cache bearer tokens in Material state.

Do not log:

```text
Authorization header
downloaded document bytes
multipart file bytes
raw server binary response
storage paths/keys
private local save paths
```

---

# 32. Validation/Error UX for Upload/Replace

### `422 unsupported_file_type`

Show:

```text
The selected file is not a valid supported PDF, DOCX, PPT or PPTX file.
```

Keep the selected file/form available for user correction where safe.

### `422 file_too_large`

Show:

```text
The selected file exceeds the current allowed size.
```

Then refresh Material list/capability so `max_size_bytes` becomes authoritative
again.

Do not parse backend human text to derive the new limit.

### `422 validation_failed`

Map known fields:

```text
file
title
body
```

to safe form-level/field-level messages.

Unknown validation keys become generic form error.

### `500 file_upload_failed`

Show:

```text
The file could not be uploaded. No successful upload was confirmed.
```

Because a server `file_upload_failed` is an explicit definitive backend error,
do not classify it as transport-unknown merely because upload is a mutation.

### `500 server_error`

Use safe generic failure text.

Do not surface raw Laravel/plugin/Dio exceptions.

---

# 33. Material List Reconciliation

Do not optimistically patch Material collection ordering or membership.

After confirmed/reconciled:

```text
upload
replace
title update
remove
```

narrowly mark/invalidate Material list and refresh authoritative current data.

Preserve current Topic Detail.

Do not invalidate unrelated Teacher Topic pages or auth state.

For replace/title updates, the mutation response may immediately update the
focused Material detail presentation while the list is marked stale, but final
collection membership/order remains GET-authoritative.

---

# 34. Presentation and Accessibility

Use the existing Material design/project style.

Required:

- keyboard-accessible buttons/dialogs;
- predictable focus;
- focus first form validation error;
- visible busy state;
- semantic progress/live-region announcements;
- responsive Wrap/action layout;
- long filename/title wrapping;
- no horizontal overflow at supported desktop widths;
- format/size/status not communicated by color alone;
- confirmation dialogs restore focus to invoking control where appropriate.

File size display may use a small focused presentation formatter.

Do not turn size formatting into upload business logic.

---

# 35. Acceptance Criteria

The task is Accepted only when all are true:

- S05-FE-002 is Accepted / Delivered on implementation baseline.
- Desktop Topic Detail has a real Learning Materials section.
- Mobile Teacher gains no Material-management actions.
- Material list strictly parses exact backend resource/capability.
- Historical readable Topics show current Materials read-only.
- Mutation controls appear only for active Group + draft/active Topic UX.
- Backend remains authoritative for editability.
- Upload uses native single-file picker.
- Upload supports only PDF/DOCX/PPT/PPTX selection UX.
- Upload streams selected file instead of eagerly loading whole file.
- Effective upload limit comes from `meta.upload.max_size_bytes`.
- Upload/replace have progress and 5-minute send timeout only.
- Protected download uses authenticated configured Dio.
- Download uses 5-minute receive timeout only.
- Binary API errors pass through existing auth/error pipeline.
- `authentication_required` still invalidates current session for binary request.
- Protected download/Open/Save transport-platform code is delivered in a neutral shared `core/files` boundary, not Teacher-only code.
- Successful download validates authoritative response headers.
- Concurrent replace cannot force the client to rely only on stale file metadata.
- Save As uses native `file_picker` save dialog.
- Open uses a safe temporary local file + `open_file`.
- No broad storage permission is introduced.
- Replace preserves Material/File identity contract.
- Title update sends only title/null and skips exact no-op.
- Remove expects 204 and does not invent hard-delete behavior.
- No client rule requires one Material to remain on an active Topic.
- Ambiguous upload/replace/update/remove is never automatically replayed.
- Unknown mutations reconcile by authoritative Material GET as defined.
- `topic_not_editable` reconciles Topic + Material state.
- Stable file machine codes are used; backend human messages are not parsed for
  application control.
- Material operations cross-disable conflicting FE-002 lifecycle mutations.
- Stale completion cannot publish across session/route/Topic/Material.
- Only approved dependencies are added.
- No backend/schema/API changes.
- No FE-004 Student implementation.
- Focused tests pass.
- Windows debug build passes because native plugins changed.
- `git diff --check` passes.
- Final diff contains no unrelated work.

---

# 36. Required Focused Tests

Add/extend tests under:

```text
frontend/test/features/teacher/
frontend/test/core/network/
```

Exact filenames may follow delivered FE-001/FE-002 naming.

## 36.1 Material DTO/list

Test:

- exact Material keys;
- exact nested File keys;
- UUID validation;
- topic ID ownership match;
- canonical extension/MIME pairs;
- size >= 1;
- strict UTC timestamps;
- duplicate Material/File ID rejection;
- exact `meta.upload`;
- platform max exact 26,214,400;
- effective <= platform max;
- exact allowed extensions;
- unknown/malformed fields rejected.

## 36.2 Material list data source/repository

Test:

- exact GET path;
- no body/query;
- status 200 only;
- strict response;
- failure mapping;
- Topic ownership validation;
- no local reordering.

## 36.3 Upload

Test:

- file picker abstraction is injectable/fakeable;
- local extension/size/title validation;
- blank title omission/null behavior;
- exact multipart fields;
- no protected fields/query;
- stream-based upload path;
- send timeout override only for transfer;
- progress publication;
- strict 201 resource;
- resource topic match;
- transport ambiguity → unknown;
- no automatic POST replay;
- confirmed success invalidates/refreshes list;
- `file_too_large` refreshes capability;
- unsupported type safe UX;
- `topic_not_editable` Topic/material reconciliation;
- stale route/session completion rejected.

Do not test the native OS picker with real dialogs in unit/widget tests.

## 36.4 Replace

Test:

- confirmation;
- exact endpoint;
- only multipart file field;
- streaming upload;
- Material ID preserved;
- File ID preserved;
- Topic ID preserved;
- custom title preserved;
- strict message;
- unknown outcome refreshes but never auto-replays;
- mutation/lifecycle cross-disable.

## 36.5 Title update

Test:

- trim/max 255;
- null clear;
- exact no-op sends no PATCH;
- exact JSON;
- strict success;
- ambiguous PATCH reconciles through GET;
- matching server title → reconciled success;
- differing server title → unconfirmed current-state UX.

## 36.6 Remove

Test:

- confirmation;
- exact DELETE/no body/query;
- success only 204;
- confirmed success refreshes list;
- unknown DELETE reconciles through GET;
- missing Material after refresh → reconciled success;
- present Material → unconfirmed;
- no automatic replay;
- no "last Material" client restriction.

## 36.7 Binary error parser/core

Test `ApiErrorResponse.tryParse`:

- existing Map behavior unchanged;
- valid UTF-8 JSON bytes parsed;
- malformed UTF-8 rejected;
- JSON scalar/list rejected;
- >64 KiB candidate rejected;
- arbitrary document bytes rejected.

Test AuthTokenInterceptor:

- byte-encoded exact `401 authentication_required` triggers current-session
  invalidation;
- stale token version does not invalidate replacement session;
- non-401 byte error does not invalidate;
- malformed bytes do not invalidate.

## 36.8 Protected download

Test:

- exact GET path;
- no body/query;
- `ResponseType.bytes`;
- receive timeout override only for transfer;
- auth interceptor remains in configured Dio path;
- expected status/headers;
- canonical Content-Type validation;
- Content-Disposition UTF-8 filename parsing;
- unsafe filename sanitization/fallback;
- empty/oversized successful bytes rejected;
- progress behavior;
- 404 safe handling;
- file_not_available safe handling;
- stale session/route completion cannot Save/Open.

## 36.9 Save/Open platform abstraction

Wrap native picker/open calls behind a very small injectable platform boundary
so controller/widget tests use fakes.

Test:

- Save dialog cancel is neutral;
- successful Save reports success;
- Open writes safe generated temp filename;
- Open uses canonical extension/MIME;
- open-plugin failure maps to safe user text;
- no original filename path traversal;
- no local path persisted as domain state.

## 36.10 Presentation

Test:

- desktop Material section loading/data/empty/error;
- effective upload capability visible;
- editable Topic shows mutation actions;
- closed/archived/archived-Group state is read/download-only;
- long names wrap;
- busy/progress accessibility;
- confirmation dialogs;
- no horizontal overflow;
- mobile Topic Detail still has no Material management controls.

---

# 37. Verification Scope

Use Flutter SDK:

```text
3.44.7
```

Run from repository root.

Install approved dependency changes:

```powershell
Push-Location frontend
fvm spawn 3.44.7 pub get
Pop-Location
```

Focused Teacher tests:

```powershell
Push-Location frontend
fvm spawn 3.44.7 test test/features/teacher
Pop-Location
```

Focused core network tests affected by binary error parsing/interceptor:

```powershell
Push-Location frontend
fvm spawn 3.44.7 test test/core/network
Pop-Location
```

Run directly affected FE-002 Topic Detail/router tests based on actual delivered
file names if they are not already included above.

Static analysis:

```powershell
Push-Location frontend
fvm spawn 3.44.7 analyze
Pop-Location
```

Format check:

```powershell
Push-Location frontend

C:\Users\Administrator\fvm\versions\3.44.7\bin\cache\dart-sdk\bin\dart.exe `
  format --output=none --set-exit-if-changed lib test

Pop-Location
```

Because this task introduces native Windows plugins, run the focused platform
build gate:

```powershell
Push-Location frontend
fvm spawn 3.44.7 build windows --debug
Pop-Location
```

Always:

```powershell
git diff --check
```

Then perform focused diff/scope self-review for:

```text
FE-003 only
shared core/files boundary contains only cross-role protected transfer/platform behavior
exactly file_picker + open_file dependency additions
native/plugin files changed only as generated/required
no backend changes
no FE-004 Student UI
desktop Teacher material boundary
streaming upload
authenticated protected download
no storage authority leakage
binary error parser bounded/safe
no mutation auto-replay
Topic/Material/session stale ownership
no broad timeout change
no unrelated refactor
```

Do **not** run for this task:

```text
full frontend suite
Android build
real-stack E2E
backend suite
```

Those remain block-checkpoint/integration responsibilities unless a concrete
failure requires targeted escalation.

---

# 38. Codex Implementation Report

Return a compact report containing:

1. implementation baseline SHA;
2. confirmation `S05-FE-002 Accepted / Delivered`;
3. implementation summary;
4. changed files;
5. dependency changes;
6. Material API operations implemented;
7. upload streaming/progress behavior;
8. protected download/Save/Open behavior;
9. binary API-error parser change;
10. mutation uncertainty/reconciliation behavior;
11. desktop/mobile boundary;
12. tests added/updated;
13. exact verification commands/results;
14. Windows debug build result;
15. `git diff --check`;
16. focused scope/diff self-review;
17. deviations/blockers.

Do not commit, push, create/merge a PR, or perform Stage bookkeeping unless the
Project Owner separately instructs that delivery step.
