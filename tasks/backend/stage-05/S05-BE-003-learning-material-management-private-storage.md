# S05-BE-003 — Learning Material Management and Private Storage

## Task Metadata

| Field | Value |
|---|---|
| Stage | `Stage 5 — Topics and Learning Materials` |
| Area | Backend |
| Status | `Approved` |
| Implementation type | Laravel Teacher Learning Material API + private file storage |
| Depends on | `S05-BE-002 Accepted / Delivered`; `S05-BE-001` persistence foundation |
| Planning baseline | `origin/main` @ `08fc5bca465562bf88f2824dd62f0d13aa29a478` |
| Implementation baseline | `Freeze current origin/main after S05-BE-002 bookkeeping + this task contract are delivered and before Codex starts` |
| Verification model | `Workflow v3 — Lean Verification` |
| Delivery owner | `Project Owner` |
| Block checkpoint | Stage 5 Backend Phase 2 after `S05-BE-001…005` are Accepted / Delivered |

---

## 1. Implementation Authority and Required Inputs

This file is the complete implementation contract for `S05-BE-003`.

Codex must read only:

1. this task;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. directly relevant backend source/tests/configuration/infrastructure required
   by this task.

Codex must not read product specifications, roadmap files, architecture/database
documents, API specification documents, Stage indexes, previous task files,
closure reviews, or Stage history to rediscover requirements.

Before Codex starts, ChatGPT / orchestration must:

- confirm `S05-BE-002` is Accepted / Delivered on current `origin/main`;
- confirm S05-BE-002 bookkeeping and this `S05-BE-003` contract are delivered;
- freeze the exact current `origin/main` implementation baseline;
- ensure local `main` is clean and synchronized with that baseline.

If current source materially conflicts with this contract, stop and report the
exact conflict. Do not invent product/API/storage/security/lifecycle behavior.

---

## 2. Goal

Implement Teacher Learning Material management and private storage for Stage 5:

```text
GET    /api/v1/teacher/topics/{topic}/materials
POST   /api/v1/teacher/topics/{topic}/materials
POST   /api/v1/teacher/materials/{material}/replace
PATCH  /api/v1/teacher/materials/{material}
DELETE /api/v1/teacher/materials/{material}
```

The result must allow the owning Teacher to:

- list current Learning Materials for an authorized Topic;
- see current effective upload capability;
- upload PDF/DOCX/PPT/PPTX Learning Materials;
- replace the current file while preserving logical Material identity;
- update only optional Material display title;
- remove current Material historically/non-destructively;
- keep all file objects private and inaccessible without a later protected
  download authorization path.

The backend remains authoritative for tenant scope, Teacher ownership, current
Teacher–Group membership, Topic/Group editability, file type, actual file size,
storage location, file metadata, and removal state.

---

## 3. Explicit Non-Goals

Do not implement:

- `GET /api/v1/files/{file}/download`;
- Student Topic/material APIs;
- Student file access;
- Parent file access;
- Institution Admin material mutation;
- Topic `activate`;
- Topic `close`;
- Topic `archive`;
- Learning Material version-history API/UI;
- public URLs or direct filesystem URLs;
- draft Topic deletion;
- Homework/Blitz/submission files;
- frontend code;
- new database tables or columns;
- schema migrations;
- new Composer packages/dependencies;
- cloud/S3-specific behavior beyond Laravel filesystem abstraction;
- antivirus scanning;
- asynchronous file processing;
- file preview/conversion;
- OCR;
- broad refactors.

Do not make physical storage paths or keys part of public API authority.

---

## 4. Current Implementation Context

At the approved planning baseline:

- `Topic`, `File`, and `LearningMaterial` persistence exists from `S05-BE-001`;
- `File` already persists:
  - Institution;
  - uploader;
  - category;
  - original name;
  - storage disk/key;
  - MIME;
  - extension;
  - byte size;
  - optional SHA-256 checksum;
  - `removed_at`;
- `LearningMaterial` already persists:
  - Institution;
  - Topic;
  - `file_id`;
  - Teacher;
  - optional `title`;
  - `position`;
  - `removed_at`;
- database constraints already enforce:
  - Learning Material file category hard maximum = 26,214,400 bytes;
  - supported Stage 5 extensions = `pdf|docx|ppt|pptx`;
  - unique `(storage_disk, storage_key)`;
  - tenant-composite integrity;
  - one `File` per `LearningMaterial` through unique `file_id`;
- Teacher Topic read/update authorization exists from `S05-BE-002`;
- `Topic::visibleToTeacher()` already represents Teacher read scope;
- `topic_not_editable` already exists;
- `InstitutionSetting.learning_material_max_mb` exists and is constrained to
  `1..25`;
- Laravel `local` filesystem disk currently points to:
  `storage/app/private`;
- `public` filesystem disk is separate;
- current Docker PHP image has PHP `zip`, but no explicit upload/post transport
  headroom for 25 MiB uploads.

Reuse current Teacher route/middleware and Controller → Action → Eloquent /
Resource conventions.

---

## 5. Route and Middleware Contract

All endpoints use the existing Teacher middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:teacher
```

Add exactly:

```text
GET    /teacher/topics/{topic}/materials
POST   /teacher/topics/{topic}/materials
POST   /teacher/materials/{material}/replace
PATCH  /teacher/materials/{material}
DELETE /teacher/materials/{material}
```

Do not add download/open routes in this task.

---

# 6. Learning Material Authorization

## 6.1 Topic Read Scope

Material listing starts from the S05-BE-002 Teacher Topic read scope:

```text
authenticated Teacher
+ same Institution
+ Topic owned by Teacher
+ current Teacher–Group membership
```

The Topic Group may be `active` or `archived` for historical read.

Any missing/foreign/other-Teacher/ended-membership Topic returns:

```text
404 resource_not_found
```

## 6.2 Material Mutation Scope

Upload/replace/title-update/remove additionally require:

```text
Group.status = active
Topic.status in (draft, active)
current Teacher–Group membership
owning Teacher
```

For direct material routes, the Material must additionally be:

```text
same Institution
+ owned by authenticated Teacher
+ connected to a Topic satisfying Teacher read scope
+ material.removed_at IS NULL
+ current linked File exists
+ file.removed_at IS NULL
```

Failure behavior:

```text
missing / invalid UUID
foreign Institution
other Teacher
ended membership
removed Material
removed File
Material outside Teacher Topic scope
→ 404 resource_not_found
```

Business-state editability:

```text
closed Topic
archived Topic
archived Group
→ 409 topic_not_editable
```

Authorization/privacy checks must precede lifecycle disclosure.

A direct Material or File UUID never grants authorization.

---

# 7. Learning Material Resource

Use one exact public resource for list/upload/replace/update:

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

Do not expose:

```text
institution_id
teacher_id
uploaded_by_user_id
storage_disk
storage_key
storage path
checksum_sha256
removed_at
File.created_at
File.updated_at
public URL
signed URL
```

All public timestamps use UTC `...Z`.

Resources must not issue hidden queries.

Actions must preload the current File needed by the Resource.

---

# 8. `GET /api/v1/teacher/topics/{topic}/materials`

## 8.1 Input

Path Topic UUID is the only input.

Reject any query parameter or request body with:

```text
422 validation_failed
```

## 8.2 Scope

Resolve Topic through Teacher Topic read scope.

The Group may be `active` or `archived` for read-only historical access.

Return only current Materials:

```text
learning_materials.removed_at IS NULL
File.removed_at IS NULL
File.category = learning_material
same Institution
```

Do not include removed Material/File rows.

## 8.3 Ordering

Order current Materials by:

```text
position asc
created_at asc
id asc
```

No pagination is required for Stage 5 Topic Material list.

Do not load/filter in PHP.

## 8.4 Upload Capability Metadata

Success includes:

```json
{
  "meta": {
    "upload": {
      "max_size_bytes": 20971520,
      "platform_max_size_bytes": 26214400,
      "allowed_extensions": [
        "pdf",
        "docx",
        "ppt",
        "pptx"
      ]
    }
  }
}
```

Exact calculation:

```text
platform_max_size_bytes = 26_214_400

institution_max_size_bytes =
institution_settings.learning_material_max_mb * 1_048_576

max_size_bytes =
min(platform_max_size_bytes, institution_max_size_bytes)
```

The current value is read at request time.

This metadata is advisory for Flutter UX only.

Upload/replace must independently revalidate the actual current limit at
mutation time.

## 8.5 Success

`200 OK`

```text
data = exact current Learning Material resources
meta.upload = exact capability metadata
no success message
```

---

# 9. Private Filesystem Configuration

## 9.1 Configured Private Disk

Add an explicit application configuration selector under existing filesystem
configuration:

```text
filesystems.private_files_disk
```

Default:

```text
local
```

Environment override:

```text
PRIVATE_FILES_DISK
```

Do not hardcode the `local` disk in Action/domain logic.

All Learning Material file writes in this task use:

```text
config('filesystems.private_files_disk')
```

## 9.2 Private-Disk Safety

The configured private-files disk must exist.

The application must reject an explicitly public disk configuration for Learning
Material writes.

At minimum, a configured disk with:

```text
visibility = public
```

must not be accepted.

The current approved default `local` disk is private under:

```text
storage/app/private
```

Do not use:

```text
public
storage/app/public
public/storage
```

for Learning Materials.

A misconfigured private disk is a server/infrastructure failure, not client
validation failure.

Do not expose the selected disk or root path in API responses.

## 9.3 Server-Generated Storage Key

Generate a new unpredictable storage key for every newly stored blob:

```text
learning-materials/{institution_uuid}/{topic_uuid}/{random_uuid}.{extension}
```

The random component must be server-generated.

Never use the original client filename as an authoritative path component.

No path traversal from filename/input may be possible.

---

# 10. File Type Detection and Canonical Metadata

Allowed logical extensions:

```text
pdf
docx
ppt
pptx
```

Do not trust:

- client `Content-Type`;
- original filename;
- filename extension;
- temporary upload MIME alone.

The backend must inspect actual file content and derive one supported canonical
type.

## 10.1 PDF

Require valid PDF signature at the start of the uploaded file.

Canonical:

```text
extension = pdf
mime_type = application/pdf
```

The original filename may use case-insensitive `.pdf`.

## 10.2 DOCX

Require ZIP/OOXML content consistent with Microsoft Word document format.

At minimum inspect the ZIP package for Word document structure/content type,
including evidence equivalent to:

```text
word/document.xml
```

and OOXML content type/package metadata sufficient to distinguish DOCX from
generic ZIP/PPTX.

Canonical:

```text
extension = docx
mime_type = application/vnd.openxmlformats-officedocument.wordprocessingml.document
```

## 10.3 PPTX

Require ZIP/OOXML content consistent with Microsoft PowerPoint presentation
format.

At minimum inspect the ZIP package for PowerPoint structure/content type,
including evidence equivalent to:

```text
ppt/presentation.xml
```

and OOXML package metadata sufficient to distinguish PPTX from generic ZIP/DOCX.

Canonical:

```text
extension = pptx
mime_type = application/vnd.openxmlformats-officedocument.presentationml.presentation
```

## 10.4 PPT

Require the OLE Compound File signature and PowerPoint-document evidence
sufficient to reject a generic arbitrary OLE file.

Canonical:

```text
extension = ppt
mime_type = application/vnd.ms-powerpoint
```

Do not accept a file merely because the name ends in `.ppt`.

## 10.5 Filename / Detected-Type Agreement

The original uploaded filename extension must exist and must agree
case-insensitively with the server-detected canonical type.

Examples:

```text
lesson.PDF + detected PDF  → allowed
lesson.docx + detected PPTX → rejected
archive.zip + detected DOCX → rejected
```

## 10.6 Failure

Unsupported, spoofed, generic ZIP/OLE, mismatched, or unrecognized type:

```text
422 unsupported_file_type
```

No storage/database attachment side effect.

---

# 11. File Integrity Metadata

For every accepted uploaded blob, compute:

```text
checksum_sha256
```

using actual uploaded bytes.

Persist lowercase 64-character SHA-256 hex.

Do not expose checksum publicly.

Also persist:

```text
category = learning_material
original_name = original client filename
storage_disk = configured private disk
storage_key = server-generated
mime_type = canonical detected MIME
extension = canonical detected extension
size_bytes = actual stored upload byte size
uploaded_by_user_id = authenticated Teacher
institution_id = authenticated Teacher Institution
removed_at = null
```

Original name must be safely treated as metadata only.

---

# 12. Upload Size Rules

Platform hard maximum:

```text
25 MiB
= 25 * 1_048_576
= 26_214_400 bytes
```

Effective limit:

```text
min(
  26_214_400,
  institution_settings.learning_material_max_mb * 1_048_576
)
```

Actual uploaded byte size must satisfy:

```text
1 <= size_bytes <= effective_limit
```

Zero-byte upload is invalid:

```text
422 validation_failed
```

Size larger than effective limit:

```text
422 file_too_large
```

Use actual byte size, not client-declared size, as authority.

The database hard maximum remains the final structural backstop.

---

# 13. PHP Multipart Transport Headroom

The current Docker PHP runtime must be configured so Laravel can actually
receive the full permitted upload and return the application-level contract.

Add explicit PHP configuration used by the repository Docker PHP image:

```text
upload_max_filesize = 32M
post_max_size = 40M
```

These are transport headroom only.

They do not change the business/API maximum.

The authoritative Learning Material application maximum remains:

```text
26_214_400 bytes
```

or a lower Institution setting.

Do not introduce web-server limits unrelated to the existing runtime.

Do not alter Student submission business limit in this task.

---

# 14. `POST /api/v1/teacher/topics/{topic}/materials`

## 14.1 Content Type

Require:

```text
multipart/form-data
```

Accepted form fields exactly:

```text
file
title
```

`title` is optional.

Reject unknown/protected multipart fields.

Reject query parameters.

## 14.2 Validation

```text
file:
  required
  successful upload
  non-empty
  supported detected format
  filename extension agrees with detected format
  actual size <= current effective limit

title:
  optional
  nullable
  string when non-null
  trim
  max 255
  blank after trim is invalid
```

Backend-controlled fields are not accepted, including:

```text
institution_id
topic_id
teacher_id
uploaded_by_user_id
storage_disk
storage_key
category
mime_type
extension
size_bytes
checksum_sha256
position
removed_at
created_at
updated_at
```

## 14.3 Authorization and Locking

A preliminary scope-safe Topic check is allowed before writing a blob.

The final authoritative decision occurs under transaction locks.

Mutation lock order:

```text
1. Group
2. current Teacher–Group membership
3. Topic
4. InstitutionSetting
```

Under locks re-check:

```text
same Institution
Topic.teacher_id = Teacher
Group = active
membership current
Topic status in draft|active
current effective upload limit
```

Do not lock an unscoped Group/Topic.

## 14.4 Position

Assign initial position deterministically:

```text
max(current non-removed material.position for Topic) + 1
```

If no current Material:

```text
position = 0
```

Calculate this under the Topic transaction lock so concurrent uploads to the
same Topic do not assign ambiguous current positions.

No reorder API is added in this task.

## 14.5 Storage / DB Compensation Algorithm

Required flow:

```text
A. validate multipart shape/basic upload
B. preliminary Teacher Topic scope check
C. detect type
D. compute actual size/checksum
E. read current effective limit for early rejection
F. generate private storage key
G. write new blob to private storage
H. start/continue authoritative DB transaction
   Group
   → current membership
   → Topic
   → InstitutionSetting
   → revalidate state and effective limit
   → create File row
   → create LearningMaterial row
I. commit
```

If storage write fails:

```text
no File row
no LearningMaterial row
500 file_upload_failed
```

If DB/persisted-scope/current-limit validation fails after the new blob was
stored:

```text
rollback DB
best-effort delete the newly stored blob
return the correct contract error
```

If blob cleanup fails:

- do not convert the original business/validation error into success;
- do not attach the blob;
- do not expose its storage key;
- log only safe operational metadata;
- private unattached blob remains non-authoritative.

Unexpected DB failure after blob write:

```text
rollback
best-effort new-blob cleanup
500 server_error
```

Do not leak storage/database details.

## 14.6 Success

`201 Created`

Return exact Material resource.

No `storage_key` or public URL.

---

# 15. `POST /api/v1/teacher/materials/{material}/replace`

## 15.1 Input

Require multipart/form-data.

Accept exactly:

```text
file
```

No `title` change in replace.

No query parameters.

Unknown/protected fields:

```text
422 validation_failed
```

## 15.2 Authorization

Resolve Material through:

```text
authenticated Teacher
→ same Institution
→ Material current
→ linked current File
→ owning Topic
→ Teacher Topic read scope
```

Out-of-scope/removed/missing:

```text
404 resource_not_found
```

Then enforce editability:

```text
Group active
Topic draft|active
```

Otherwise:

```text
409 topic_not_editable
```

## 15.3 Identity Rule

Replacement preserves both:

```text
LearningMaterial.id
File.id
```

Do not create a second version-history Material/File row.

Full file version history is outside MVP.

## 15.4 Replacement Storage Algorithm

Required high-level flow:

```text
A. preliminary scope-safe Material resolution
B. validate/detect new file
C. compute actual size/checksum
D. early effective-limit check
E. write NEW blob under NEW unique private key
F. DB transaction with final current-state revalidation
G. update the existing File row to reference NEW blob metadata/key
H. touch LearningMaterial.updated_at for a real replacement
I. commit
J. best-effort delete OLD physical blob after commit
```

Do not overwrite the old blob in place.

A failed replacement must never destroy the previously valid current Material.

## 15.5 Lock Order

Inside the final transaction:

```text
1. Group
2. current Teacher–Group membership
3. Topic
4. LearningMaterial
5. File
6. InstitutionSetting
```

Re-check under locks:

```text
same Institution
Teacher ownership
current membership
Group active
Topic draft|active
Material current
File current
effective upload limit
```

## 15.6 Failed Replacement Before Commit

If new storage write fails:

```text
old Material/File remain unchanged
500 file_upload_failed
```

If DB/business/current-scope/limit validation fails after new blob write:

```text
old Material/File remain authoritative
rollback DB
best-effort delete NEW blob
return correct error
```

## 15.7 Old-Blob Cleanup After Commit

After successful commit:

- new File metadata/key is authoritative;
- old storage object is no longer authoritative;
- attempt best-effort delete of old blob.

If old-blob deletion fails:

- replacement remains successful;
- do not roll back DB;
- do not expose old key;
- log safe cleanup failure metadata;
- old blob remains private/unreferenced.

## 15.8 Success

`200 OK`

Exact current Material resource.

```text
message = Learning material replaced successfully.
```

A real replacement updates:

```text
File.updated_at
LearningMaterial.updated_at
```

Material and File IDs remain unchanged.

---

# 16. `PATCH /api/v1/teacher/materials/{material}`

## 16.1 Input

Require a non-empty JSON object containing exactly:

```text
title
```

Examples:

```json
{
  "title": "Updated display title"
}
```

```json
{
  "title": null
}
```

Reject:

- query parameters;
- empty object/body;
- malformed JSON;
- scalar/array root;
- unknown/protected keys.

Failures:

```text
422 validation_failed
```

## 16.2 Title Rules

```text
title:
  required key
  nullable
  string when non-null
  trim
  max 255
```

Blank non-null string after trim:

```text
422 validation_failed
```

## 16.3 Authorization and Locking

Resolve current Material scope first.

Inside transaction use:

```text
Group
→ current Teacher membership
→ Topic
→ LearningMaterial
→ File
```

Re-check:

```text
Group active
Topic draft|active
Material/File current
Teacher/Institution ownership
```

File is not mutated by title update.

## 16.4 No-Op

If normalized title equals stored title:

```text
200
message = Learning material updated successfully.
```

Return current Material resource.

Preserve:

```text
LearningMaterial.updated_at
File.updated_at
```

## 16.5 Real Update

Update only:

```text
learning_materials.title
learning_materials.updated_at
```

Do not touch File metadata or storage.

Success:

```text
200
message = Learning material updated successfully.
```

---

# 17. `DELETE /api/v1/teacher/materials/{material}`

## 17.1 Authorization

Resolve current Material/File through Teacher material scope.

Already removed/out-of-scope/missing:

```text
404 resource_not_found
```

Then enforce:

```text
Group active
Topic draft|active
```

Otherwise:

```text
409 topic_not_editable
```

## 17.2 Historical Removal

Removal is non-destructive at DB record level.

Inside transaction lock:

```text
Group
→ current Teacher membership
→ Topic
→ LearningMaterial
→ File
```

Set one authoritative server timestamp:

```text
removed_at = now()
```

to both:

```text
LearningMaterial.removed_at
File.removed_at
```

Use the same instant for both rows.

Do not hard-delete either row.

Do not change:

```text
Material id
File id
Topic
Teacher ownership
File metadata other than removed_at/updated_at
```

## 17.3 Physical Blob Cleanup

After successful DB commit:

- best-effort delete the physical blob from its private disk/key.

If physical delete fails:

- DB removal remains successful;
- Material/File remain unavailable to current APIs;
- return the normal successful removal response;
- log safe cleanup metadata;
- do not expose storage path/key.

This preserves authorization correctness even if storage cleanup is delayed.

## 17.4 Repeated Remove

Second DELETE after successful removal:

```text
404 resource_not_found
```

Do not disclose that the Material existed and was removed.

## 17.5 Success

```text
204 No Content
```

No response JSON body.

---

# 18. Error Contracts

Keep the existing global API error envelope.

Add exact focused file errors.

## 18.1 Unsupported File Type

```text
HTTP 422
code = unsupported_file_type
message = The uploaded file type is not supported.
```

Errors:

```json
{
  "file": [
    "Supported file types are PDF, DOCX, PPT, and PPTX."
  ]
}
```

## 18.2 File Too Large

```text
HTTP 422
code = file_too_large
message = The uploaded file exceeds the allowed size.
```

`errors.file` must contain the current effective limit in bytes and MiB.

Example for a 20 MiB institution limit:

```text
The file must not exceed 20971520 bytes (20 MiB).
```

Do not rely on Flutter to calculate this.

## 18.3 File Upload Failed

Unexpected storage write failure:

```text
HTTP 500
code = file_upload_failed
message = The file could not be uploaded.
errors = {}
```

Do not expose disk/key/path/driver exception details.

## 18.4 Existing Errors

Reuse:

```text
401 authentication_required
403 forbidden
403 user_inactive
403 institution_inactive
403 password_change_required
404 resource_not_found
409 topic_not_editable
422 validation_failed
500 server_error
```

Do not map expected unsupported/oversized/storage failures to generic
`business_conflict`.

---

# 19. Required Backend Structure

Follow existing repository conventions.

Expected focused application structure:

```text
app/Actions/Teacher/
  ListTeacherLearningMaterials.php
  UploadTeacherLearningMaterial.php
  ReplaceTeacherLearningMaterial.php
  UpdateTeacherLearningMaterial.php
  RemoveTeacherLearningMaterial.php
```

Expected HTTP structure:

```text
app/Http/Controllers/Api/V1/Teacher/
  TeacherLearningMaterialController.php

app/Http/Requests/Teacher/
  TeacherLearningMaterialIndexRequest.php
  TeacherLearningMaterialUploadRequest.php
  TeacherLearningMaterialReplaceRequest.php
  TeacherLearningMaterialUpdateRequest.php
  TeacherLearningMaterialRemoveRequest.php

app/Http/Resources/Teacher/
  TeacherLearningMaterialResource.php
  TeacherLearningMaterialCollection.php
```

Expected focused file infrastructure/domain support may include:

```text
app/Support/Files/
  LearningMaterialUploadPolicy.php
  LearningMaterialFileInspector.php
  PrivateFileStorage.php
```

or equivalent focused names.

Do not create:

```text
GeneralFileService
CommonStorageManager
UniversalUploadHelper
Repository interfaces around every model
```

Exact internal class splitting may differ if current repository conventions
support a simpler focused structure, but these responsibilities must remain
separate:

1. request shape;
2. Teacher/material authorization Action;
3. file content inspection/canonical metadata;
4. private filesystem interaction;
5. Resource serialization.

---

# 20. Model Query Scopes / Relationships

Focused reusable Eloquent scopes may be added where they clarify:

```text
current LearningMaterial
current File
Teacher-visible/current Material resolution
```

Do not turn Models into workflow managers.

No global scopes that could hide historical rows from explicit administrative
or future Stage queries.

Existing tenant ownership must remain explicit and reviewable.

---

# 21. Storage Failure Injection / Testability

The storage boundary must be testable without real external network storage.

Use Laravel filesystem abstraction and supported fake/failure mechanisms for
focused failure tests.

Do not catch every `Throwable` around entire business Actions.

Catch/translate only storage-operation failures where required to produce:

```text
file_upload_failed
```

Unexpected programming/database errors must still flow to normal server error
handling after required compensation.

---

# 22. Required Focused Tests

Add exactly:

```text
backend/tests/Feature/Teacher/TeacherLearningMaterialReadApiTest.php
backend/tests/Feature/Teacher/TeacherLearningMaterialUploadApiTest.php
backend/tests/Feature/Teacher/TeacherLearningMaterialMutationApiTest.php
```

Use real Laravel HTTP, PostgreSQL, models, transactions, and Laravel filesystem.

No external network storage.

## 22.1 `TeacherLearningMaterialReadApiTest`

Cover:

- exact route registration + middleware;
- unauthenticated / wrong role / account / Institution / password gates;
- Topic list scope:
  - own same-Institution;
  - current membership;
  - other Teacher hidden;
  - foreign tenant hidden;
  - ended membership hidden;
- archived Group current-membership Topic remains readable;
- removed Material excluded;
- removed File excluded;
- non-learning-material File excluded;
- exact Resource keys;
- storage disk/key/checksum/uploader/tenant hidden;
- exact UTC timestamps;
- deterministic ordering:
  - position;
  - created_at;
  - UUID tie-break;
- no query/body input accepted;
- exact `meta.upload`;
- effective Institution lower limit;
- default 25 MiB limit;
- Resource serialization performs no hidden queries.

## 22.2 `TeacherLearningMaterialUploadApiTest`

Cover:

- valid PDF upload;
- valid DOCX upload;
- valid PPT upload;
- valid PPTX upload;
- mixed-case filename extension accepted when detected type agrees;
- generic ZIP rejected;
- DOCX renamed `.pptx` rejected;
- PPTX renamed `.docx` rejected;
- arbitrary OLE renamed `.ppt` rejected;
- arbitrary bytes renamed `.pdf` rejected;
- missing file;
- failed upload;
- zero-byte file;
- unsupported filename extension;
- extra multipart/protected fields;
- query parameters;
- title trim;
- null/omitted title;
- blank title rejected;
- title >255 rejected;
- exact effective Institution lower limit:
  - exact limit bytes accepted;
  - limit + 1 byte rejected;
- exact platform 26,214,400 accepted when Institution = 25;
- 26,214,401 rejected;
- `file_too_large` exact error includes bytes/MiB;
- SHA-256 persisted;
- canonical MIME/extension persisted;
- private configured disk used;
- unpredictable server-generated key;
- original filename is metadata only;
- no public storage path;
- File and Material tenant/Teacher/Topic linkage exact;
- position assignment deterministic;
- storage write failure:
  - no DB attachment;
  - exact `500 file_upload_failed`;
- DB/current-scope failure after blob write:
  - DB rollback;
  - new blob cleanup attempted;
  - no valid Material.

## 22.3 `TeacherLearningMaterialMutationApiTest`

Cover replace:

- Material ID preserved;
- File ID preserved;
- new private key used;
- old File metadata replaced;
- checksum/MIME/extension/size/original_name updated;
- Material `updated_at` advances;
- all four approved types work through shared detection behavior;
- oversized/unsupported replacement leaves old File/Material unchanged;
- storage failure leaves old File/Material/blob authoritative;
- DB failure after new blob leaves old File/Material authoritative and new blob
  unattached/cleaned;
- successful commit then old-blob cleanup attempted;
- old-blob cleanup failure does not roll back successful replacement;
- foreign/other Teacher/ended membership/removed Material → 404;
- archived Group/closed Topic/archived Topic → 409.

Cover title update:

- exact title update;
- null clears;
- trim;
- blank rejected;
- unknown/protected/query/invalid body rejected;
- exact no-op preserves `LearningMaterial.updated_at`;
- File `updated_at` never changes.

Cover remove:

- exact 204;
- same removal timestamp on Material/File;
- DB rows retained;
- second DELETE → 404;
- post-commit blob delete attempted;
- blob-delete failure still returns successful 204 and DB state stays removed;
- foreign/other Teacher/ended/removed → 404;
- closed/archived/archived Group → 409.

Concurrency/races:

- upload first vs Group archive;
- Group archive first vs upload;
- upload first vs membership removal;
- membership removal first vs upload;
- replace first vs Group archive;
- Group archive first vs replace;
- replace first vs membership removal;
- membership removal first vs replace;
- replace first vs remove;
- remove first vs replace.

Use deterministic PostgreSQL lock-wait testing consistent with the existing
S05-BE-002 technique.

Do not add arbitrary sleeps or broad concurrency infrastructure.

---

# 23. Directly Affected Regression Tests

Run:

```text
tests/Feature/ApiErrorContractTest.php
tests/Feature/Authorization/RoleAuthorizationProductionRouteHygieneTest.php
tests/Feature/Teacher/TeacherTopicReadApiTest.php
```

`ApiErrorContractTest` must cover the new exact:

```text
unsupported_file_type
file_too_large
file_upload_failed
```

error mappings.

Do not run the full Stage 4 or full backend suite.

---

# 24. Docker / PHP Transport Verification

Because this task must support a 25 MiB business upload and changes PHP transport
configuration, verify the repository Docker PHP runtime reports at least:

```text
upload_max_filesize = 32M
post_max_size = 40M
```

A focused Docker image/config verification is required.

Do not run a broad application build.

Do not change unrelated Docker services.

---

# 25. Proportional Verification

Run from `backend/` unless noted.

## 25.1 Formatter

```bash
./vendor/bin/pint --test
```

## 25.2 New focused Teacher material tests

```bash
php artisan test \
  tests/Feature/Teacher/TeacherLearningMaterialReadApiTest.php \
  tests/Feature/Teacher/TeacherLearningMaterialUploadApiTest.php \
  tests/Feature/Teacher/TeacherLearningMaterialMutationApiTest.php
```

## 25.3 Direct regressions

```bash
php artisan test \
  tests/Feature/ApiErrorContractTest.php \
  tests/Feature/Authorization/RoleAuthorizationProductionRouteHygieneTest.php \
  tests/Feature/Teacher/TeacherTopicReadApiTest.php
```

## 25.4 Focused Docker transport check

Use the repository Docker configuration to build/use the PHP runtime as needed
and prove:

```text
upload_max_filesize >= 32M
post_max_size >= 40M
```

Do not run the full backend suite.

If host PHP cannot run PostgreSQL tests because `pdo_pgsql` is unavailable, run
the exact same test commands inside the repository Docker PHP/PostgreSQL runtime.

## 25.5 Repository checks

From repository root:

```bash
git diff --check
git status --short
```

Then perform the focused storage/security/scope/diff self-review required by
root and backend `AGENTS.md`.

---

# 26. Acceptance Criteria

`S05-BE-003` is implementation-complete only when all are true:

1. Exact five Teacher material routes exist under Teacher middleware.
2. Material list is Tenant/Teacher/current-membership scoped.
3. Archived Group historical material read works while membership remains current.
4. Material list returns only current Material/File rows.
5. Exact Material Resource leaks no private storage metadata.
6. Exact upload capability metadata uses current Institution lower limit.
7. All Learning Material blobs use configured private filesystem storage.
8. No public disk/path becomes authoritative.
9. Storage keys are server-generated/unpredictable.
10. PDF/DOCX/PPT/PPTX are detected by actual content, not trusted filename/MIME.
11. Filename extension must agree with detected canonical type.
12. Canonical MIME/extension/actual size/SHA-256 are persisted.
13. Exact effective byte limit is enforced at request time.
14. PHP transport headroom permits Laravel to receive the full 25 MiB business range.
15. Upload creates no valid attachment on storage or DB failure.
16. New unattached blob cleanup is attempted after DB/current-state failure.
17. Replace preserves LearningMaterial ID.
18. Replace preserves File ID.
19. Failed replace never destroys the old valid Material.
20. Successful replace changes to a new private storage key.
21. Old blob deletion occurs only after successful DB commit.
22. Old-blob cleanup failure does not corrupt authoritative DB state.
23. Title update accepts only `title`, supports null, and preserves timestamps
    on exact no-op.
24. Remove is DB-historical, not hard delete.
25. Material/File receive the same removal timestamp.
26. Repeated remove is privacy-safe 404.
27. Removed Material/File cannot appear as current material.
28. Mutation authorization is revalidated under locks.
29. Mutation lock order is consistent with the approved contract.
30. Ordered upload/replace/remove races satisfy approved outcomes.
31. `unsupported_file_type` exact error contract passes.
32. `file_too_large` exact error contract passes.
33. `file_upload_failed` exact error contract passes.
34. No download, Student, lifecycle, frontend, migration, dependency, or
    unrelated scope is introduced.
35. Required focused tests pass.
36. Required direct regression tests pass.
37. Pint passes.
38. Focused Docker PHP upload/post limit check passes.
39. `git diff --check` passes.
40. Focused storage/security/diff self-review passes.

---

# 27. Focused Self-Review Checklist

Before reporting completion, Codex must confirm:

- every Material access starts from authenticated Teacher/Tenant scope;
- direct Material/File UUID cannot bypass Topic/current-membership scope;
- read vs mutation Group lifecycle difference is preserved;
- closed/archived Topic and archived Group are read-only;
- removed rows are not exposed as current;
- no public URL/storage key is serialized;
- client MIME/filename alone is never authoritative;
- actual byte size is authoritative;
- current Institution limit is re-read during authoritative mutation;
- storage disk selection is configuration-based and private;
- path traversal via original filename is impossible;
- checksum is calculated from actual upload bytes;
- upload compensation does not leave a valid DB attachment;
- failed replacement preserves old authority;
- replacement does not create version-history rows;
- replacement preserves Material and File IDs;
- old blob is deleted only post-commit;
- removal is DB historical;
- blob cleanup failure never re-exposes removed content;
- lock ordering is consistent and tenant-scoped;
- Resources issue no hidden queries;
- new error codes preserve global error envelope;
- PHP transport headroom does not alter business maximum;
- no lifecycle/download/Student/frontend/schema/dependency scope creep exists.

---

# 28. Delivery and Completion Report

Routine Git/GitHub delivery is owned by the Project Owner.

Codex must not commit, push, open a PR, or merge unless explicitly instructed
outside this contract.

Codex final report must include:

```text
S05-BE-003 IMPLEMENTATION COMPLETE
```

and report:

- changed production files;
- changed test files;
- changed Docker/PHP transport configuration files;
- routes added;
- exact private-storage configuration;
- exact file type detection behavior;
- effective size-limit behavior;
- upload compensation behavior;
- replace identity/compensation behavior;
- remove/history behavior;
- authorization/tenant behavior;
- concurrency verification;
- focused test counts/assertions;
- direct regression counts/assertions;
- Docker upload/post limit evidence;
- Pint result;
- `git diff --check` result;
- focused storage/security/diff self-review result;
- final Git state;
- any exact blocker if implementation could not be completed safely.

If a required check fails, leave the task incomplete and report the exact
failure.

---

# Final Implementation Rule

> Implement only Stage 5 Teacher Learning Material list/upload/replace/title
> update/remove with private storage and strong tenant/current-membership
> authorization. Preserve logical Material/File identity on replace, keep
> removed records historical, never expose private storage metadata, and never
> allow partial storage/database failure to create or destroy authoritative
> learning content.
