# S05-FE-004 — Student Topics and Learning Materials

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S05-FE-004` |
| Stage | `Stage 5 — Topics and Learning Materials` |
| Area | `Frontend` |
| Status | `Approved` |
| Depends on | `S05-FE-003 Accepted / Delivered` |
| Planning/readiness baseline | `origin/main @ a407cf9250357f7d4a674da806a52f469476ba51` |
| Backend gate | `S05-BE-001…005 Accepted / Delivered; Backend Phase 2 PASS` |
| Verification model | `Workflow v3 — Lean Verification` |
| New dependencies | `None` |
| Reused dependencies | `timezone`, `file_picker`, `open_file` from prior approved frontend tasks |
| Implementation baseline | `Must be re-frozen from current origin/main after S05-FE-003 Accepted / Delivered` |

This file is the complete implementation contract for `S05-FE-004`.

Codex must read only:

1. this task;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. directly relevant frontend source/tests needed to implement this task.

Codex must not read product specifications, roadmap files, Stage history,
previous task files, checkpoint reviews, closure reviews, or architecture/API
documents to rediscover requirements.

### Mandatory implementation-entry gate

This contract may be prepared and stored before `S05-FE-003` implementation,
but Codex must **not** implement it until orchestration has confirmed:

```text
S05-FE-003 = Accepted / Delivered
current origin/main re-checked
actual FE-001…003 Teacher/file-transfer implementation inspected
this contract still matches current implementation
clean synchronized local main
```

If the delivered FE-003 implementation materially conflicts with local names or
wiring assumed here, preserve the behavior below and adapt only implementation
wiring. Do not invent product/API/security/file behavior.

---

# 2. Goal

Replace the generic Student placeholder entry with the real Stage 5 Student
learning experience.

An authenticated Student on desktop and mobile must be able to:

- view only currently authorized non-draft Topics;
- search Topics;
- filter by Topic status;
- paginate Topics;
- open Topic Detail;
- read Topic description and Student instructions;
- view current eligible Learning Materials;
- securely open/download supported Learning Materials;
- view lesson date/time in Institution timezone;
- remain isolated to current Institution and current Student–Group membership;
- reconcile safely when Topic/Material access changes.

The Laravel backend remains authoritative for:

```text
Student role
Institution scope
current Student–Group membership
Topic visibility
draft invisibility
Topic lifecycle
current Material/File state
download authorization
file availability
```

---

# 3. Device Scope

This task supports:

```text
Student desktop
Student mobile / Android
```

Both devices support:

```text
Topic list
Topic search/filter/pagination
Topic Detail
Student instructions
Learning Material list
Open
Save as / download
Refresh/retry
Sign out
```

Do not add Student authoring or management actions.

---

# 4. Explicit Non-Goals

Do not implement:

- Topic create/edit/lifecycle;
- Teacher functionality;
- Learning Material upload/replace/title edit/remove;
- Homework execution;
- Homework attempts;
- Blitz execution;
- Blitz timing;
- Student submissions;
- result calculation;
- result release UI;
- understanding categories;
- Parent UI;
- Student dashboard metrics beyond the Stage 5 Topics workspace;
- public/signed file URLs;
- local offline cache/synchronization;
- persistent document library;
- new backend endpoints;
- backend/schema changes;
- new Flutter packages;
- a second router;
- a second HTTP client;
- a second file-transfer stack;
- broad refactors.

The Stage 5 backend placeholders:

```text
homework
blitz_status
result_status
```

must be strictly parsed but must not be rendered as real Stage 6+ functionality.

---

# 5. Feature Structure

Create a focused Student feature:

```text
frontend/lib/features/student/
  application/
  data/
  domain/
  presentation/
```

Follow:

```text
Presentation
→ Controller / State
→ Repository contract
→ Repository implementation
→ Remote data source
→ configured Dio
```

Reuse existing:

```text
AuthSessionController
SessionInvalidationSignal
AppDeviceSurface
GoRouter
Riverpod
DioFailureMapper
ApiFailure
ApiRequestException
timezone support from FE-002
protected file-transfer/platform boundary from FE-003
```

Do not duplicate shared file-transfer behavior inside Student feature.

---

# 6. Routing

Keep canonical Student root:

```text
/student
```

Replace its current generic RoleEntryScreen with:

```text
StudentLearningWorkspaceScreen
```

Add:

```text
/student/topics/:topicId
```

Suggested route name:

```text
student-topic-detail
```

Do not create Student create/edit routes.

## 6.1 Route helper behavior

Add focused Student route helpers equivalent to:

```text
isStudentTopicDetailPath
isStudentApprovedLocation
isStudentSegment
studentTopicDetailLocation
```

Topic ID path parameter must be a canonical hyphenated UUID.

Direct deep links to a valid Student Topic Detail must work after auth bootstrap.

Reject/redirect safely for:

```text
invalid Topic ID
extra Student child segments
query parameters
fragments
```

Do not issue an API request for an invalid route target.

## 6.2 Role/device behavior

Student desktop and mobile may use:

```text
/student
/student/topics/:topicId
```

Other roles must remain unable to enter Student destinations.

Unsupported device behavior remains governed by existing entry routing.

---

# 7. Student Session Eligibility

Eligible Student state requires:

```text
authenticated
role = student
user active
must_change_password = false
non-empty institution_id
user.institution.id == institution_id
institution.status = active
surface = desktop OR mobile
```

Bind async publication to:

```text
Student user ID
current AuthUser instance identity
Institution ID
AppDeviceSurface
query/Topic target
operation generation
```

On:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

clear protected Student feature state and reuse existing auth/session
reconciliation.

A stale response from a previous Student/session must never populate the current
workspace/detail.

---

# 8. Student Topic List API

Endpoint:

```text
GET /student/topics
```

Accepted query exactly:

```text
status
search
page
per_page
```

No request body.

Do not send:

```text
group_id
sort
direction
teacher_id
institution_id
draft
```

Defaults:

```text
page = 1
per_page = 20
```

Backend ordering is fixed:

```text
created_at DESC
id DESC
```

Frontend must not invent sorting controls.

---

# 9. Student Topic List Query Model

Implement a typed immutable query model.

Fields:

```text
status: null | active | closed | archived
search: null | normalized search
page: >= 1
perPage: fixed 20
```

## 9.1 Search

Rules:

```text
trim
blank → null
max 254 Unicode code points
300 ms debounce
Enter/Search commits immediately
```

Local validation text:

```text
Search must be 254 characters or fewer.
```

Invalid search blocks query-changing requests until fixed/cleared.

If a valid pending search exists and Student changes status, refreshes, or pages,
commit the pending normalized search into the single resulting request.

Avoid duplicate requests for the same logical query.

## 9.2 Status filter

UI options:

```text
All
Active
Closed
Archived
```

Map to machine values:

```text
null
active
closed
archived
```

Never send:

```text
draft
published
```

Changing status resets page to 1 while preserving valid committed/pending search.

---

# 10. Student Topic Summary DTO

Strictly parse exact list item:

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

Exact top-level item keys:

```text
id
group
title
subject
lesson_at
status
```

Exact Group keys:

```text
id
name
level
subject_direction
status
```

Validate:

- Topic/Group IDs are UUIDs;
- title and subject are non-empty strings;
- `level` and `subject_direction` nullable strings;
- Group status only:
  - `active`
  - `archived`
- Topic status only:
  - `active`
  - `closed`
  - `archived`
- `lesson_at` nullable strict UTC `...Z`.

Reject draft in Student DTO even if server unexpectedly returns it.

Do not accept extra keys.

---

# 11. Topic List Envelope

Expected exact success:

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

No success message.

Strictly validate:

```text
page == requested page
per_page == 20
total >= 0
last_page >= 1
last_page == max(1, ceil(total / per_page))
data.length <= per_page
duplicate Topic IDs rejected
```

Do not silently coerce malformed pagination.

---

# 12. Topic List Controller States

Support:

```text
initial loading
query loading
refreshing with data retained
data
global empty
filtered empty
recoverable empty page
error + retry
```

## 12.1 Empty states

Global empty:

```text
No Topics are available yet.
```

Filtered/search empty:

```text
No matching Topics.
```

Do not suggest creating a Topic.

## 12.2 Pagination

Show:

```text
Previous
Page X of Y
Next
```

No page-size control.

No sort control.

## 12.3 Bounded empty-page correction

If requested page > 1 and response has zero rows:

```text
if total == 0:
  target = 1
else:
  target = max(1, min(last_page, requested_page - 1))
```

Perform at most one automatic correction for one user query operation.

Preserve current status/search.

Never loop.

---

# 13. Student Workspace Presentation

Header must show:

```text
TestLabUz
Student
current user
Institution
Sign out
```

Main heading:

```text
My Topics
```

Controls:

```text
Search topics
Status filter
Refresh
Pagination
```

Each Topic card shows:

```text
title
subject
Group name
Group level when present
Group subject direction when present
Topic status
Group archived context when applicable
lesson date/time when present
```

Topic card opens:

```text
/student/topics/{topicId}
```

Do not show Teacher authoring controls.

---

# 14. Institution Timezone for `lesson_at`

Reuse the shared IANA timezone support delivered by FE-002 under the approved neutral `core/time` boundary.

Authoritative timezone:

```text
current authenticated Institution timezone
```

Backend Topic timestamps arrive as UTC instants.

Display:

```text
server UTC instant
→ convert using Institution IANA timezone
→ Student-facing local educational time
```

Do not use:

```text
DateTime.toLocal()
device timezone
device clock
```

If the Institution timezone cannot be resolved locally:

- keep the Topic visible;
- do not guess device-local time;
- show a safe time-formatting-unavailable state;
- do not block Topic/material access.

No new timezone package is added.

---

# 15. Student Topic Detail API

Endpoint:

```text
GET /student/topics/{topicId}
```

Send:

```text
no query
no body
```

Expected:

```text
200
{
  "data": { "...exact Student Topic Detail..." }
}
```

Returned Topic ID must equal requested Topic ID.

---

# 16. Student Topic Detail DTO

Strictly parse:

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
  "description": "Optional description",
  "subject": "Informatics",
  "student_instructions": "Study the materials.",
  "lesson_at": null,
  "status": "active",
  "materials": [],
  "homework": [],
  "blitz_status": "not_available",
  "result_status": "waiting_for_homework"
}
```

Exact keys:

```text
id
group
title
description
subject
student_instructions
lesson_at
status
materials
homework
blitz_status
result_status
```

Validate:

- same Group shape as summary;
- title/subject/instructions non-empty;
- description nullable;
- lesson_at nullable strict UTC;
- Topic status:
  - active
  - closed
  - archived;
- `materials` exact typed list;
- `homework` exactly empty list in Stage 5;
- `blitz_status` exactly `not_available`;
- `result_status` exactly `waiting_for_homework`.

If placeholder fields differ unexpectedly, treat the response as invalid rather
than guessing later-stage semantics.

Do not render Homework/Blitz/Result placeholder UI.

---

# 17. Student Learning Material DTO

Strictly parse:

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

Exact Material keys:

```text
id
title
file
```

Exact File keys:

```text
id
original_name
extension
size_bytes
```

Validate:

- Material/File IDs UUID;
- title nullable and non-empty when non-null;
- original_name non-empty;
- extension exactly:
  - pdf
  - docx
  - ppt
  - pptx;
- size_bytes integer >= 1;
- duplicate Material IDs rejected;
- duplicate File IDs rejected.

Preserve server Material order.

Do not locally sort.

Do not model unavailable private fields.

---

# 18. Student Topic Detail Presentation

Desktop and mobile show:

```text
Topic title
Subject
Topic status
Group
Group status
Description when present
Student instructions
Lesson date/time when present
Learning Materials
```

Do not display:

```text
Teacher name when API does not provide it
Homework placeholder
Blitz placeholder
Result placeholder
internal IDs as primary labels
storage metadata
```

## 18.1 Detail states

Support:

```text
loading
data
refreshing with data retained
not found/unavailable
error + retry
```

## 18.2 Topic unavailable

For:

```text
404 resource_not_found
```

show generic:

```text
This Topic is no longer available.
```

Do not reveal whether:

```text
membership ended
Topic was draft
Topic was foreign
Topic was removed
Student was never assigned
```

Actions:

```text
Back to Topics
```

Also invalidate/refresh the Student Topic list narrowly.

---

# 19. Learning Materials Presentation

Materials are embedded in Student Topic Detail.

No separate Student Material-list endpoint.

For each Material:

If `title != null`:

```text
<custom title>
<original file name>
<extension> · <human size>
```

If `title == null`:

```text
<original file name>
<extension> · <human size>
```

Empty:

```text
No learning materials are available for this Topic.
```

Student never sees mutation controls.

---

# 20. Protected File Transfer Reuse

Use the same backend endpoint as Teacher:

```text
GET /files/{file}/download
```

Do **not** duplicate FE-003 transport logic in Student feature.

Reuse the confirmed shared behavior for:

```text
authenticated Dio binary GET
ResponseType.bytes
binary API-error parsing
Content-Type validation
Content-Disposition parsing
safe filename handling
download progress
5-minute receive timeout
Save As
Open via temp file
file_not_available handling
session invalidation
```

## 20.1 Shared-layer delivery requirement

The approved FE-003 contract requires the protected transfer/platform behavior
to be delivered already in a neutral focused boundary such as:

```text
frontend/lib/core/files/
```

FE-004 must reuse that boundary directly.

If the delivered FE-003 implementation leaves this behavior Teacher-scoped or
duplicates protected transfer logic instead of providing the approved shared
boundary, treat that as an implementation-baseline conflict during FE-004
readiness revalidation. Do not silently create a second implementation or make
an unplanned architectural extraction inside FE-004.

The fix belongs to the FE-003 dependency state before FE-004 implementation
continues.

---

# 21. Student Download Authorization UX

Frontend submits only:

```text
File UUID
```

Backend decides authorization.

Never send:

```text
topic_id
material_id
student_id
group_id
institution_id
storage_disk
storage_key
```

as download authority.

A copied/known File UUID does not imply access.

---

# 22. Student Open / Save As

Both desktop and mobile expose:

```text
Open
Save as…
```

or platform-appropriate equivalent labels while preserving the same behavior.

## 22.1 Open

Reuse FE-003:

```text
authenticated binary GET
→ trusted response validation
→ safe temp file
→ OS associated application
```

If no application can open it:

```text
No application is available to open this file. Save the file instead.
```

## 22.2 Save As

Reuse native file picker Save As behavior.

No broad storage permission.

User cancel is neutral.

Do not persist local path as domain/application authority.

---

# 23. Material Download Races

A Material shown in Topic Detail may become removed or inaccessible before
download.

For:

```text
404 resource_not_found
```

show:

```text
This learning material is no longer available.
```

Then perform one authoritative:

```text
GET /student/topics/{topicId}
```

If Topic still succeeds:

- update current Material list from the detail response.

If Topic becomes `404`:

- transition to Topic unavailable;
- invalidate Student Topic list.

Do not infer the reason.

## 23.1 Temporary backing-storage failure

For:

```text
500 file_not_available
```

show:

```text
The file is temporarily unavailable. Try again.
```

Do not remove the Material from the UI solely because storage is temporarily
unavailable.

---

# 24. Download Retry

Protected download is GET and non-mutating.

A Student may manually retry after:

```text
connection failure
timeout
file_not_available
```

Do not implement hidden automatic retry loops.

Do not open/save a partial/untrusted download.

---

# 25. Student List Error Handling

Use stable error codes/categories only.

### Session-authority failures

Reuse auth bootstrap/invalidation.

### `403 forbidden`

Safe generic:

```text
You do not have permission to access Student Topics.
```

Do not rewrite local role assumptions.

### `422 validation_failed`

A client-generated list query should already be valid. Treat an exact server
validation rejection as query contract failure and keep safe UI.

Do not display raw Laravel messages.

### `429 rate_limited`

Safe retry-later text.

### Server/connection/timeout/invalid response

Use existing typed failure categories and retry UI.

---

# 26. Detail/List Reconciliation

Do not optimistically add/remove Topics based on local assumptions.

Topic list remains GET-authoritative.

After a detail `404`:

```text
mark/invalidate Student list
```

Preserve current search/status query when returning to workspace.

When list refresh removes the Topic, accept that result.

Do not reveal why it disappeared.

---

# 27. Async Ownership for File Operations

Student file actions must publish only while all remain current:

```text
authenticated Student session
AuthUser instance
Institution
desktop/mobile surface
Topic ID
Material ID
File ID
route ownership
latest file operation generation
```

A stale completion must not:

- open a file after logout;
- save after a Student/session replacement;
- show feedback on another Topic;
- update another Material;
- navigate from an obsolete detail route.

File transfer may outlive the initiating widget, so widget `mounted` alone is
insufficient.

---

# 28. Responsive UX

## Desktop

Use readable constrained content width.

Topic cards may use a denser multi-column/wider presentation where appropriate.

Detail can use wider sections.

## Mobile

One-column scrollable layout.

Required:

- no horizontal overflow;
- touch-friendly controls;
- long instructions wrap;
- long filenames wrap;
- filters/search remain usable at narrow width;
- progress is visible and accessible;
- file actions fit via Wrap/menu if needed;
- representative text scaling supported.

Viewport width only controls presentation, not feature authorization.

---

# 29. Accessibility

Required:

- semantic headings;
- accessible Topic cards;
- predictable focus on desktop;
- visible keyboard focus;
- semantic loading/progress announcements;
- search field error association;
- status communicated by text, not color only;
- file buttons have meaningful labels including Material name where useful;
- no focus trap in narrow layouts.

---

# 30. No New Dependencies

FE-004 must add **no new packages**.

Reuse packages already delivered by prior approved tasks:

```text
timezone
file_picker
open_file
```

Do not change package versions unless orchestration explicitly approves a
dependency compatibility fix before implementation.

Do not add:

```text
path_provider
permission_handler
file_saver
http
mime
shared_preferences
```

for this task.

---

# 31. Acceptance Criteria

The task is Accepted only when all are true:

- S05-FE-003 is Accepted / Delivered on implementation baseline.
- `/student` no longer uses the generic Stage 1 placeholder.
- Student desktop and mobile both reach the real Stage 5 workspace.
- Student Topic list uses only exact `status/search/page/per_page`.
- No sort/group filter is invented.
- Draft status is never requested/displayed.
- Search debounce/validation/query ownership are correct.
- Pagination is strict and has one bounded empty-page correction.
- Student summary DTO strictly validates exact resource.
- Topic cards open Student Topic Detail.
- Student detail route supports valid direct deep links.
- Invalid Student child routes fail safely without API request.
- Detail DTO strictly validates exact Stage 5 shape.
- Stage 5 Homework/Blitz/Result placeholders are parsed but not rendered as real
  later-stage UI.
- Materials come only from authoritative Topic Detail response.
- Material ordering is preserved from backend.
- Removed/out-of-scope Materials do not become visible through local state.
- Lesson time displays in Institution timezone, not device timezone.
- Open/download works on desktop and mobile.
- File transfer reuses FE-003 shared behavior rather than duplicating it.
- FE-003 must already have delivered the shared protected transfer boundary; FE-004 performs no duplicate implementation or deferred extraction.
- No public/storage path authority is used.
- Material/Topic `404` remains privacy-safe.
- `file_not_available` is treated as temporary availability, not authorization
  failure.
- Stale file/list/detail completions cannot publish across Student session/route.
- No new dependencies.
- No backend/schema changes.
- No Stage 6+ functionality.
- Focused tests pass.
- Android debug build passes.
- `git diff --check` passes.
- Final diff contains no unrelated work.

---

# 32. Required Focused Tests

Add tests under:

```text
frontend/test/features/student/
```

and reuse/extend affected shared file tests.

## 32.1 Student list query

Test:

- initial exact query;
- per_page fixed 20;
- no sort/direction/group_id;
- statuses null/active/closed/archived;
- draft cannot be represented;
- search trim/blank/max 254 code points;
- 300 ms debounce;
- Enter immediate commit;
- pending valid search + status/page/refresh single-request behavior;
- dedupe;
- page reset on status/search;
- invalid search blocks requests.

## 32.2 Summary DTO/list envelope

Test:

- exact keys;
- exact Group keys;
- UUIDs;
- Topic statuses;
- Group statuses;
- strict UTC lesson time;
- draft response rejected;
- unknown fields rejected;
- exact pagination;
- duplicate Topic IDs;
- row count/per-page invariants.

## 32.3 List data source/repository

Test:

- exact GET path;
- exact query;
- no body;
- success 200 only;
- malformed response mapping;
- typed failure mapping.

## 32.4 List controller

Test:

- desktop/mobile Student eligibility;
- initial load;
- refresh;
- search/status/page;
- global empty;
- filtered empty;
- error/retry;
- one empty-page correction;
- no correction loop;
- stale query response rejection;
- session replacement clearing;
- authority errors reconcile auth.

## 32.5 Workspace widget

Test:

- placeholder replaced;
- Student identity/Institution/sign-out;
- search/status filters;
- Topic cards;
- empty/error/loading/data;
- desktop responsiveness;
- mobile no horizontal overflow;
- no Teacher controls.

## 32.6 Detail DTO

Test:

- exact keys;
- exact Group;
- description nullability;
- required instructions;
- strict lesson time;
- active/closed/archived only;
- strict Materials;
- `homework == []`;
- `blitz_status == not_available`;
- `result_status == waiting_for_homework`;
- unexpected placeholder values rejected;
- unknown keys rejected.

## 32.7 Material DTO

Test:

- exact keys;
- exact File keys;
- UUIDs;
- nullable title;
- non-empty original name;
- allowed extension;
- size >= 1;
- duplicate Material/File IDs.

## 32.8 Detail controller/widget

Test:

- exact GET/no body/query;
- requested/returned ID match;
- loading/refresh/error/not-found;
- list invalidation after detail 404;
- Material empty/data;
- Student instructions;
- Institution-time display;
- no Homework/Blitz/Result placeholder UI;
- desktop/mobile layout.

## 32.9 Protected file integration

Reuse shared FE-003 tests and add Student-facing controller/widget cases:

- Open/Save calls shared protected transfer boundary;
- current Student/Topic/Material/File ownership checked before publication;
- 404 refreshes Topic Detail;
- Topic 404 after Material 404 transitions to unavailable;
- file_not_available leaves Material visible;
- timeout/connection allows manual retry;
- stale session/route completion cannot Open/Save;
- no storage authority submitted.

## 32.10 Shared transfer reuse regression

Test:

- FE-004 uses the already-delivered shared protected file-transfer service;
- directly affected Teacher protected-download tests remain green when Student
  integration changes shared call sites/configuration;
- no duplicate HTTP/header/parser/platform logic exists in Student feature.

## 32.11 Router/entry

Test:

- Student desktop `/student`;
- Student mobile `/student`;
- valid `/student/topics/:uuid`;
- direct deep link survives bootstrap;
- invalid UUID safe fallback;
- query/fragment safe fallback;
- Student cannot enter Teacher/Admin routes;
- other roles cannot enter Student child route;
- existing Teacher routes remain unaffected.

---

# 33. Verification Scope

Use Flutter SDK:

```text
3.44.7
```

Run from repository root.

Focused Student tests:

```powershell
Push-Location frontend
fvm spawn 3.44.7 test test/features/student
Pop-Location
```

Run directly affected shared file-transfer/core tests based on delivered FE-003
layout.

Run directly affected Teacher material/file-transfer tests as focused regression whenever FE-004 changes shared `core/files` call sites/configuration.

Run router/entry tests directly affected by Student child-route support.

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

Because this task is the first actual Android/mobile use of the file-transfer
plugins delivered in FE-003, run:

```powershell
Push-Location frontend
fvm spawn 3.44.7 build apk --debug
Pop-Location
```

Always:

```powershell
git diff --check
```

Then perform focused diff/scope self-review for:

```text
FE-004 only
no new dependencies
no backend changes
no Stage 6+ UI
Student desktop/mobile only
draft never visible
exact Student API contracts
shared FE-003 core/files transfer boundary reused without deferred extraction
no duplicated protected file pipeline
no storage authority leakage
Institution timezone display
privacy-safe 404
session/route/file stale ownership
no unrelated refactor
```

Do **not** run for this task:

```text
full frontend suite
release builds
real-stack E2E
backend suite
```

Those belong to Frontend Phase 2 / Integration unless a concrete regression
requires targeted escalation.

---

# 34. Codex Implementation Report

Return a compact report containing:

1. implementation baseline SHA;
2. confirmation `S05-FE-003 Accepted / Delivered`;
3. implementation summary;
4. changed files;
5. confirmation no new dependencies;
6. routes added/changed;
7. Student Topic list/detail API behavior;
8. Institution-time lesson formatting;
9. Learning Material projection;
10. protected Open/Save reuse through the shared `core/files` boundary;
11. desktop/mobile behavior;
12. tests added/updated;
13. exact verification commands/results;
14. Android debug build result;
15. `git diff --check`;
16. focused scope/diff self-review;
17. deviations/blockers.

Do not commit, push, create/merge a PR, or perform Stage bookkeeping unless the
Project Owner separately instructs that delivery step.
