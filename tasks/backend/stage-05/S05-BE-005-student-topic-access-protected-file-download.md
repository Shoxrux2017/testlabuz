# S05-BE-005 — Student Topic Access and Protected File Download

## Task Metadata

| Field | Value |
|---|---|
| Stage | `Stage 5 — Topics and Learning Materials` |
| Area | Backend |
| Status | `Approved` |
| Implementation type | Laravel Student Topic read API + protected Learning Material binary download |
| Depends on | `S05-BE-003 Accepted / Delivered`; `S05-BE-004 Accepted / Delivered`; Stage 4 Student–Group graph |
| Planning baseline | `origin/main` @ `8dee9f91f08a7c032429ab7c07e31d911c67b065` |
| Implementation baseline | `Freeze current origin/main after S05-BE-004 bookkeeping + this task contract are delivered and before Codex starts` |
| Verification model | `Workflow v3 — Lean Verification` |
| Delivery owner | `Project Owner` |
| Block checkpoint | Stage 5 Backend Phase 2 immediately after `S05-BE-001…005` are Accepted / Delivered |

---

## 1. Implementation Authority

This file is the complete implementation contract for `S05-BE-005`.

Codex must read only:

1. this task;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. directly relevant backend source/tests required by this task.

Codex must not read product specifications, roadmap files, architecture/database/API
documents, Stage indexes, previous task files, closure reviews, or Stage history
to rediscover requirements.

Before Codex starts, ChatGPT / orchestration must:

- confirm `S05-BE-004` is Accepted / Delivered on current `origin/main`;
- confirm S05-BE-004 bookkeeping and this contract are delivered;
- freeze the exact current `origin/main` implementation baseline;
- ensure local `main` is clean and synchronized.

If current source materially conflicts with this contract, stop and report the
exact conflict. Do not invent product/API/storage/security behavior.

---

## 2. Goal

Complete the Stage 5 backend vertical slice by implementing:

```text
GET /api/v1/student/topics
GET /api/v1/student/topics/{topic}
GET /api/v1/files/{file}/download
```

The result must allow:

- an authenticated Student to list only currently authorized non-draft Topics;
- a Student to read one authorized Topic and its current Learning Materials;
- an owning/currently assigned Teacher to download a current Learning Material;
- a currently assigned Student to download a current Learning Material belonging
  to an accessible non-draft Topic;
- private binary delivery without exposing filesystem/object-storage authority.

Laravel remains authoritative for role, Institution, current Group membership,
Teacher Topic ownership, Topic lifecycle, current Material/File state, persisted
private disk/key, and binary availability.

---

## 3. Explicit Non-Goals

Do not implement:

- Student dashboard;
- Homework APIs;
- Blitz APIs;
- attempts/submissions;
- result calculation or release;
- Parent Topic/material/file access;
- Institution Admin binary download;
- Platform Owner binary download;
- Student submission-file download;
- generic download support for every `FileCategory`;
- public/signed URLs;
- direct client storage disk/key/path input;
- file preview/conversion;
- inline browser rendering contract;
- HTTP Range/partial-content support;
- antivirus/OCR;
- cloud-provider-specific APIs;
- schema/migrations;
- new database columns/indexes;
- new Composer packages;
- frontend changes;
- broad refactors.

This task supports protected download only for current Stage 5
`learning_material` Files.

---

## 4. Current Implementation Context

At the planning baseline:

- `Topic`, `LearningMaterial`, `File`, `GroupStudentMembership`, and
  `GroupTeacherMembership` persistence already exists;
- `GroupStudentMembership::current()` means `ended_at IS NULL`;
- current membership is authoritative for normal Student access;
- Teacher Topic read scope already exists;
- Topic lifecycle is `draft|active|closed|archived`;
- S05-BE-003 persists actual `storage_disk`, `storage_key`, canonical MIME,
  canonical extension, byte size, original filename, and removal state;
- S05-BE-003 replacement preserves logical `LearningMaterial` and `File`
  identity while replacing the current blob location;
- removal marks Material/File removed and deletes the blob best-effort after commit;
- `PrivateFileStorage` currently owns private-disk write/delete behavior;
- no Student API controller/resource namespace exists yet;
- `ApiErrorResponse` does not yet implement `file_not_available`.

No schema change is required.

---

# 5. Route and Middleware Contract

## 5.1 Student Topic Routes

Add:

```text
GET /student/topics
GET /student/topics/{topic}
```

Exact middleware:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:student
```

## 5.2 Protected File Route

Add:

```text
GET /files/{file}/download
```

Exact middleware:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:teacher,student
```

Parent, Institution Admin, and Platform Owner must fail at the role boundary with
existing `403 forbidden`.

Do not expose duplicate Teacher/Student download routes.

---

# 6. Student Topic Read Scope

Add focused scope:

```text
Topic::visibleToStudent(User $student)
```

Required predicates:

```text
topics.institution_id = authenticated Student institution
current GroupStudentMembership for:
  same institution
  topics.group_id
  authenticated Student id
  ended_at IS NULL

topics.status IN (active, closed, archived)
```

Do not require:

- current Teacher–Group membership;
- active Group status;
- Teacher account status beyond persisted Topic ownership history.

A Group may be `active` or `archived` for Student historical read.

A draft Topic is outside Student scope.

Invalid/missing/foreign/unrelated/ended-membership/draft Topics all return:

```text
404 resource_not_found
```

Do not reveal which privacy condition failed.

---

# 7. `GET /api/v1/student/topics`

## 7.1 Accepted Input

Accepted query keys exactly:

```text
status
search
page
per_page
```

A request body is not allowed.

Unknown query keys or any body:

```text
422 validation_failed
```

## 7.2 Query Validation

```text
status:
  optional
  one of active|closed|archived

search:
  optional
  nullable
  trim
  max 254
  blank after trim = no search filter

page:
  optional integer
  min 1
  default 1

per_page:
  optional integer
  min 1
  max 100
  default 20
```

`status=draft` returns `422 validation_failed`.

Search is a case-insensitive literal substring across `title` and `subject`.
Escape `%`, `_`, and the chosen SQL escape character.

Apply Student scope before filtering/search/pagination.
Do not load all rows and filter in PHP.

## 7.3 Ordering

Fixed Stage 5 ordering:

```text
created_at DESC
id DESC
```

No client `sort`/`direction` input exists.

## 7.4 Exact List Resource

Each item:

```json
{
  "id": "topic-uuid",
  "group": {
    "id": "group-uuid",
    "name": "9-A",
    "level": "Grade 9",
    "subject_direction": "Informatics",
    "status": "active"
  },
  "title": "Internet Basics",
  "subject": "Informatics",
  "lesson_at": "2026-08-25T04:00:00Z",
  "status": "active"
}
```

Top-level success:

```json
{
  "data": [],
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 20,
      "total": 0,
      "last_page": 1
    }
  }
}
```

No success `message`.

Do not expose Institution/Teacher IDs, membership rows, lifecycle internals,
storage metadata, or internal timestamps.

`group.status` may be `active` or `archived`.
All public timestamps use UTC `...Z`.
Resources must not issue hidden queries.

---

# 8. `GET /api/v1/student/topics/{topic}`

## 8.1 Input

Path Topic UUID is the only accepted input.

Any query parameter or body:

```text
422 validation_failed
```

## 8.2 Scope

Resolve through `visibleToStudent()`.

Out-of-scope, draft, foreign, missing, invalid UUID, or ended-membership targets:

```text
404 resource_not_found
```

## 8.3 Exact Stage 5 Topic Detail Resource

Return:

```json
{
  "data": {
    "id": "topic-uuid",
    "group": {
      "id": "group-uuid",
      "name": "9-A",
      "level": "Grade 9",
      "subject_direction": "Informatics",
      "status": "active"
    },
    "title": "Internet Basics",
    "description": "Optional description",
    "subject": "Informatics",
    "student_instructions": "Study the materials.",
    "lesson_at": null,
    "status": "active",
    "materials": [
      {
        "id": "material-uuid",
        "title": "Lesson slides",
        "file": {
          "id": "file-uuid",
          "original_name": "lesson.pptx",
          "extension": "pptx",
          "size_bytes": 1250000
        }
      }
    ],
    "homework": [],
    "blitz_status": "not_available",
    "result_status": "waiting_for_homework"
  }
}
```

The last three fields are Stage 5 placeholders required by the locked Student
Topic resource shape:

```text
homework = []
blitz_status = not_available
result_status = waiting_for_homework
```

They do not implement Homework, Blitz, result persistence, assignment, attempts,
or scoring. Later stages replace them with real backend-owned state.

No success `message`.

## 8.4 Student Material Projection

Return only current Learning Materials:

```text
learning_materials.institution_id = Student institution
learning_materials.topic_id = authorized Topic
learning_materials.removed_at IS NULL

linked File:
  same Institution
  category = learning_material
  removed_at IS NULL
```

Order:

```text
position ASC
created_at ASC
id ASC
```

Exact Student material resource:

```json
{
  "id": "material-uuid",
  "title": "Lesson slides",
  "file": {
    "id": "file-uuid",
    "original_name": "lesson.pptx",
    "extension": "pptx",
    "size_bytes": 1250000
  }
}
```

Do not expose Topic/Teacher/Institution/uploader IDs, MIME, storage disk/key,
checksum, removal state, position, File timestamps, or URLs.

Material/File relations must be eagerly loaded. Resources issue no hidden queries.

---

# 9. Protected Learning Material Download

Endpoint:

```text
GET /api/v1/files/{file}/download
```

Path File UUID is the only accepted input.

Query/body:

```text
422 validation_failed
```

The client must never submit storage authority.

---

# 10. Preliminary File Resolution and Privacy

The File UUID must first be resolved through a scope-safe Learning Material path,
not an unscoped `File::find()` followed by authorization.

The preliminary query may read only enough information to identify:

```text
File id
LearningMaterial id
Topic id
Group id
```

inside authenticated actor Institution and role relationship scope.

Invalid/missing/foreign/wrong-category/removed/unrelated/ended-membership/draft-
for-Student targets all return:

```text
404 resource_not_found
```

Authorization completes before binary availability is checked.

---

# 11. Teacher Download Authorization

Authenticated Teacher requires:

```text
File:
  same Institution
  category = learning_material
  removed_at IS NULL

LearningMaterial:
  same Institution
  removed_at IS NULL
  teacher_id = authenticated Teacher

Topic:
  same Institution
  teacher_id = authenticated Teacher
  connected to LearningMaterial

current GroupTeacherMembership:
  same Institution
  Topic Group
  authenticated Teacher
  ended_at IS NULL
```

Teacher Topic may be:

```text
draft
active
closed
archived
```

Group may be `active` or `archived`.
Teacher access does not require Topic editability.

---

# 12. Student Download Authorization

Authenticated Student requires:

```text
File:
  same Institution
  category = learning_material
  removed_at IS NULL

LearningMaterial:
  same Institution
  removed_at IS NULL

Topic:
  same Institution
  connected to LearningMaterial
  status IN (active, closed, archived)

current GroupStudentMembership:
  same Institution
  Topic Group
  authenticated Student
  ended_at IS NULL
```

Group may be `active` or `archived`.

Draft Student target is always `404 resource_not_found`.
Current Teacher membership is not a Student-download prerequisite.

---

# 13. Authoritative Download Lock Order

After preliminary scope-safe resolution, run a short transaction and lock/revalidate:

```text
1. Group
2. role-specific current membership
   - GroupTeacherMembership for Teacher
   - GroupStudentMembership for Student
3. Topic
4. LearningMaterial
5. File
6. open private read stream
```

All locked rows remain Institution/role scoped.
The final authorization decision uses locked current state.

Do not lock File first.
Do not hold the transaction open while streaming bytes to the client.

Before commit, acquire a readable stream for the currently locked authoritative
`File.storage_disk` + `File.storage_key`.

After stream acquisition, commit and return a response that owns the already-open
stream. Response callback closes the stream in `finally`.

---

# 14. Persisted Storage Location Is Authority

Download uses the authorized locked:

```text
File.storage_disk
File.storage_key
```

Do not replace `File.storage_disk` with current
`config('filesystems.private_files_disk')` because configuration can change after
upload.

Current selector is authority for new writes. Persisted File location is authority
for existing reads.

Never expose either persisted value publicly.

---

# 15. Private Storage Read Boundary

Extend existing private-storage infrastructure additively.

`PrivateFileStorage` may gain a method equivalent to:

```text
openReadStream(storedDiskName, storedStorageKey, fileId)
```

Requirements:

1. Stored disk exists in `filesystems.disks`.
2. Stored disk config is an array.
3. `visibility = public` is rejected.
4. Stored disk need not equal current `private_files_disk`.
5. Use Laravel/Flysystem streaming read (`readStream` or equivalent).
6. Missing/failing/non-resource stream becomes `file_not_available`.
7. Do not use `Storage::get()` or `file_get_contents()` for the blob.
8. Do not log storage root/path/key/provider credentials.
9. Safe logs may include `file_id` and operation/error category only.
10. Do not log binary content.

---

# 16. `file_not_available`

Add:

```text
App\Exceptions\Files\FileNotAvailableException
```

and existing API error mapping.

Exact response:

```text
HTTP 500 Internal Server Error
```

```json
{
  "message": "The requested file is currently unavailable.",
  "code": "file_not_available",
  "errors": {}
}
```

Use only after authorization succeeds but backing storage cannot be opened safely:

```text
stored disk missing
malformed disk config
stored disk explicitly public
blob missing
readStream failure
non-resource readStream
```

Unauthorized/out-of-scope/removed targets remain `404 resource_not_found`.
No disk/key/path/provider/error text is exposed.

---

# 17. Binary Response Contract

After successful authorization + stream acquisition:

```text
200 OK
```

Headers:

```text
Content-Type = persisted canonical File.mime_type
Content-Disposition = attachment with safely encoded original filename
Cache-Control = private, no-store
X-Content-Type-Options = nosniff
```

Do not manually concatenate an untrusted filename into headers.

Filename rules:

1. persisted `original_name` is display metadata only;
2. remove/replace CR, LF, NUL and header-dangerous controls;
3. if unusable after normalization, use `download.<canonical_extension>`;
4. use Symfony/Laravel Content-Disposition generation with safe ASCII fallback
   and UTF-8 filename parameter.

Do not expose storage/path/bucket/provider metadata.
No Stage 5 Range/206 behavior is required.

---

# 18. Download Concurrency Semantics

Authorization is based on locked state at stream-acquisition time.

## 18.1 Student Membership Removal

```text
download first:
  stream acquired under current membership
  download remains valid
  membership removal waits, then succeeds

membership removal first:
  removal succeeds
  later download → 404
```

## 18.2 Teacher Membership Removal

```text
download first:
  stream acquired
  download remains valid
  membership removal waits, then succeeds

membership removal first:
  removal succeeds
  later download → 404
```

## 18.3 Material Remove

```text
download first:
  current Material/File locked
  stream acquired
  remove waits
  download remains valid
  remove then succeeds

remove first:
  Material/File removed
  later download → 404
```

## 18.4 Material Replace

```text
download first:
  stream for old current blob acquired
  replace waits
  download may finish from already-open old stream
  replace then succeeds; new blob becomes authoritative

replace first:
  File row changes to new current storage key
  later download serves new blob
```

Never authorize the old replaced key by client input.

## 18.5 Topic Activation vs Student Download

Initially draft Topic:

```text
activation first:
  activation succeeds
  later Student download succeeds if membership/material remain current

Student download first:
  draft is outside Student scope → 404
  later activation may succeed
```

---

# 19. Student Topic Read Concurrency

Student list/detail are ordinary scoped reads and do not require row locks.

Each request evaluates current membership/lifecycle from its own DB read.
If membership ended before query evaluation, Topic is absent from list and detail
returns `404`.

No historical Student read is created from an ended membership in Stage 5.

---

# 20. Expected Backend Structure

Expected production additions:

```text
app/Actions/Student/
  ListStudentTopics.php
  ShowStudentTopic.php

app/Actions/Files/
  DownloadLearningMaterialFile.php

app/Support/Files/
  ProtectedLearningMaterialAccess.php
  ProtectedFileDownload.php

app/Http/Controllers/Api/V1/Student/
  StudentTopicController.php

app/Http/Controllers/Api/V1/Files/
  ProtectedFileDownloadController.php

app/Http/Requests/Student/
  StudentTopicIndexRequest.php
  StudentTopicShowRequest.php

app/Http/Requests/Files/
  ProtectedFileDownloadRequest.php

app/Http/Resources/Student/
  StudentTopicSummaryResource.php
  StudentTopicCollection.php
  StudentTopicResource.php
  StudentLearningMaterialResource.php

app/Exceptions/Files/
  FileNotAvailableException.php
```

Expected focused modifications:

```text
app/Models/Topic.php
app/Support/Files/PrivateFileStorage.php
app/Support/ApiErrorResponse.php
bootstrap/app.php
routes/api.php
```

`ProtectedFileDownload` may be a small immutable DTO/value object carrying only:

```text
open stream resource
mime type
display filename
canonical extension
```

It is never serialized to JSON.

Exact internal split may be smaller if current conventions make it cleaner, but
Controllers/Resources must not own authorization or storage decisions.

---

# 21. Student Resource Query Rules

Student list/detail Actions must:

- apply tenant/current-membership/lifecycle scope before filters;
- select only needed columns;
- eagerly load Group projection;
- detail eagerly loads only current Material/File rows;
- avoid N+1;
- avoid hidden Resource queries;
- avoid unbounded reads outside one authorized Topic;
- use server-side list pagination/search.

No Student resource may leak Teacher-only or storage-internal metadata.

---

# 22. Required Focused Tests

Add exactly three new files:

```text
backend/tests/Feature/Student/StudentTopicApiTest.php
backend/tests/Feature/Files/ProtectedLearningMaterialDownloadApiTest.php
backend/tests/Feature/Files/ProtectedLearningMaterialDownloadConcurrencyTest.php
```

## 22.1 `StudentTopicApiTest`

Cover:

- exact routes/middleware and auth/account/Institution/password/role gates;
- only `status|search|page|per_page` query keys;
- body/unknown query rejection;
- invalid status including draft;
- pagination boundaries;
- search trim/max/literal `%`/`_`;
- active/closed/archived Topic visibility;
- draft/unrelated/ended/cross-Institution exclusion;
- archived Group historical read while membership current;
- deterministic `created_at DESC, id DESC` pagination;
- detail invalid/missing/foreign/unrelated/ended/draft → 404;
- exact Topic detail shape;
- current Material/File only;
- removed Material/File and wrong category excluded;
- material ordering;
- exact placeholder fields;
- no Teacher/Institution/storage leakage;
- no hidden Resource queries.

## 22.2 `ProtectedLearningMaterialDownloadApiTest`

Cover:

- exact route/middleware;
- unauthenticated/account/Institution/password gates;
- Parent/Admin/Platform Owner forbidden before resource disclosure;
- path only; query/body rejected; invalid UUID → 404;
- Teacher own/current membership succeeds for all Topic statuses;
- Teacher archived Group succeeds;
- other Teacher/ended/foreign → 404;
- Student active/closed/archived succeeds;
- Student archived Group succeeds;
- Student draft/unrelated/ended/foreign → 404;
- removed Material/File/wrong category/orphan File → 404;
- real private bytes returned;
- persisted MIME + safe attachment disposition;
- UTF-8 filename safely handled;
- CR/LF/NUL injection impossible;
- fallback filename works;
- `Cache-Control` private/no-store;
- `X-Content-Type-Options = nosniff`;
- no storage metadata leakage;
- persisted valid private disk different from current selector still reads correctly;
- stored missing/malformed/public disk, missing blob, readStream failure → exact 500 `file_not_available`;
- unauthorized target remains 404 even when blob is missing.

## 22.3 `ProtectedLearningMaterialDownloadConcurrencyTest`

Use deterministic PostgreSQL workers/lock waits; no arbitrary sleeps.

Cover:

- Student download ↔ Student membership removal, both orders;
- Teacher download ↔ Teacher membership removal, both orders;
- download ↔ Material remove, both orders;
- download ↔ Material replace, both orders;
- Topic activation → Student download;
- Student draft download → Topic activation.

For download-first remove/replace, prove the first worker acquired a valid readable
stream under locks and can still read expected bytes after the competing
transaction completes.

For replace-first, later download returns new authoritative bytes.
For removal/membership-first, later download is 404.
No transaction remains open while full response bytes are consumed.

---

# 23. Directly Affected Regression Tests

Run exactly:

```text
tests/Feature/ApiErrorContractTest.php
tests/Feature/Authorization/RoleAuthorizationProductionRouteHygieneTest.php
tests/Feature/Institution/InstitutionGroupStudentMembershipApiTest.php
tests/Feature/Teacher/TeacherLearningMaterialReadApiTest.php
```

Reasons:

- shared error boundary gains `file_not_available`;
- one multi-role production route is added;
- Student membership becomes a learning-access authority;
- Teacher material read/private metadata behavior must remain unchanged.

Do not run full backend suite here.
Do not rerun Docker upload transport checks.
Do not run frontend/E2E.

---

# 24. Proportional Verification

From `backend/` unless noted.

```bash
./vendor/bin/pint --test
```

```bash
php artisan test \
  tests/Feature/Student/StudentTopicApiTest.php \
  tests/Feature/Files/ProtectedLearningMaterialDownloadApiTest.php \
  tests/Feature/Files/ProtectedLearningMaterialDownloadConcurrencyTest.php
```

```bash
php artisan test \
  tests/Feature/ApiErrorContractTest.php \
  tests/Feature/Authorization/RoleAuthorizationProductionRouteHygieneTest.php \
  tests/Feature/Institution/InstitutionGroupStudentMembershipApiTest.php \
  tests/Feature/Teacher/TeacherLearningMaterialReadApiTest.php
```

If host PHP lacks `pdo_pgsql`, run the same exact commands in repository Docker
PHP/PostgreSQL runtime.

No full backend suite.

From repository root:

```bash
git diff --check
git status --short
```

Then perform focused Student-scope, tenant/privacy, private-storage read,
streaming/header, download-race, and diff/scope self-review.

---

# 25. Allowed Change Scope

Expected production areas:

```text
backend/app/Actions/Student/
backend/app/Actions/Files/
backend/app/Exceptions/Files/
backend/app/Http/Controllers/Api/V1/Student/
backend/app/Http/Controllers/Api/V1/Files/
backend/app/Http/Requests/Student/
backend/app/Http/Requests/Files/
backend/app/Http/Resources/Student/
backend/app/Models/Topic.php
backend/app/Support/Files/
backend/app/Support/ApiErrorResponse.php
backend/bootstrap/app.php
backend/routes/api.php
```

Expected tests are exactly the three new focused files above.

Direct regression tests may change only if a route/error assertion is genuinely
obsolete and original protection is preserved.

Do not change:

```text
database/migrations
composer.json
composer.lock
docker/
frontend/
docs/
tasks/
Teacher upload/type-detection rules
Topic lifecycle rules
Stage 6+ assessment persistence/API
```

---

# 26. Acceptance Criteria

`S05-BE-005` is complete only when all are true:

1. Exact Student Topic list/detail routes exist.
2. Exact protected File download route exists.
3. Student routes use Student role middleware.
4. Download route allows only Teacher/Student roles.
5. Student Topic scope is Institution/current-membership based.
6. Draft Topics never appear to Student.
7. Active/closed/archived Topics are readable to current assigned Student.
8. Archived Group preserves Student historical read while membership current.
9. Ended Student membership revokes Topic/material access.
10. Student list accepts only `status|search|page|per_page`.
11. Student list rejects draft filter.
12. Student list uses literal case-insensitive search.
13. Student list ordering/pagination is deterministic.
14. Student detail uses exact Stage 5 resource shape.
15. Student detail includes only current Material/current learning-material File.
16. Student resource leaks no Teacher/Institution/storage metadata.
17. Stage 5 placeholder fields remain static and do not implement assessments.
18. File UUID alone never grants access.
19. Teacher download requires owning Topic + current Teacher membership.
20. Student download requires current Student membership + non-draft Topic.
21. Teacher may download draft/active/closed/archived material.
22. Student may download active/closed/archived material.
23. Archived Group download remains allowed for current authorized role.
24. Removed Material/File cannot be downloaded.
25. Non-learning-material File cannot use this route.
26. Parent/Admin/Platform Owner receive no binary access.
27. Download uses persisted `File.storage_disk/storage_key`.
28. Current selector cannot redirect an existing File read.
29. Stored disk must exist and not be explicitly public.
30. Binary is streamed, not loaded wholly into application memory.
31. Authorization completes before binary availability disclosure.
32. Missing/unreadable authorized blob returns exact `500 file_not_available`.
33. Unauthorized/missing/private targets remain `404 resource_not_found`.
34. Binary MIME comes from persisted canonical metadata.
35. Content-Disposition is safely encoded/header-injection resistant.
36. No storage/path/key/provider metadata leaks.
37. Download transaction ends before full binary transfer.
38. Lock order is `Group → membership → Topic → Material → File`.
39. Required membership/material/replace/activation race outcomes pass.
40. Download-first remove/replace retains a readable already-open stream.
41. No migrations/dependencies/frontend/Stage 6 scope is added.
42. Three new focused test files pass.
43. Four direct regression files pass.
44. Pint passes.
45. `git diff --check` passes.
46. Focused security/streaming/concurrency/diff review passes.

---

# 27. Focused Self-Review Checklist

Confirm before completion:

- Student scope is tenant-first/current-membership based;
- draft is privacy-safe invisible;
- Group archival preserves current historical read;
- ended membership revokes access;
- Student resources expose no Teacher/storage authority;
- download role boundary excludes Parent/Admin/Platform Owner;
- File UUID is never direct authorization;
- preliminary resolution is scope-safe;
- final authorization is revalidated under locks;
- lock order matches Group/material mutation order;
- persisted disk/key, not current selector, is read authority;
- stored public disk config is rejected;
- authorized missing blob maps only to `file_not_available`;
- unauthorized missing blob does not reveal availability;
- streams are closed safely;
- no full-file `get()`/`file_get_contents()` is used;
- filename disposition cannot inject headers;
- no transaction stays open during body streaming;
- replacement/removal races cannot expose an unauthorized storage key;
- no existing security test is weakened;
- no debug/temp/generated files are included.

---

# 28. Delivery and Completion Report

Routine Git/GitHub delivery is owned by the Project Owner.

Codex must not commit, push, open a PR, or merge unless explicitly instructed
outside this contract.

Final report must begin with:

```text
S05-BE-005 IMPLEMENTATION COMPLETE
```

and include:

- changed production files;
- changed test files;
- exact routes/middleware;
- Student Topic resource/filter/order behavior;
- Student scope/draft/history behavior;
- Teacher download authorization;
- Student download authorization;
- persisted-disk behavior;
- streaming/header behavior;
- `file_not_available` behavior;
- lock order;
- concurrency outcomes;
- focused test counts/assertions;
- direct regression counts/assertions;
- Pint;
- `git diff --check`;
- focused security/streaming/concurrency/diff self-review;
- final Git state;
- exact blocker if incomplete.

If any required check fails, leave the task incomplete and report the exact
failure.

---

# Final Implementation Rule

> Complete the Stage 5 backend learning-content delivery path without weakening
> privacy or private storage. Student access is current-membership + non-draft
> Topic scoped. Protected binary access is role/tenant/relationship scoped,
> revalidated under PostgreSQL locks, opened from the persisted private File
> location, streamed without public storage authority, and never reveals whether
> an unauthorized blob exists.
