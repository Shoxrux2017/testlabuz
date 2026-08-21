# S04-FE-001 — Institution Group Navigation and List

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S04-FE-001` |
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | `Frontend` |
| Status | `Approved` |
| Depends on | Stage 4 backend block delivered; complete Backend Phase 2 `PASS` |
| Delivery | `Implementation + GitHub delivery` |

This file is the complete task-specific implementation contract for Codex.

Codex must use only this contract, applicable `AGENTS.md` files, and directly relevant source/tests. Do not read product docs, roadmap, previous tasks, Stage history, checkpoint reviews, or closure reviews to determine behavior.

---

## 2. Goal

Add a real **Groups** destination to the Institution Admin desktop shell and implement a production-quality read-only Group list backed by:

```text
GET /api/v1/institution/groups
```

This task owns **navigation + Group list only**.

---

## 3. Scope

### Included

- Add `Groups` to the existing Institution Admin desktop navigation.
- Add canonical frontend route `/institution-admin/groups`.
- Add strict typed Group/domain/list/pagination/query models.
- Add Group list remote data source, repository, Riverpod controller/state, and UI.
- Support search, status filter, sorting, pagination, refresh, retry, loading, empty, error, and bounded out-of-range page correction.
- Preserve current Institution Admin session/device/tenant boundaries and stale-async safety.
- Retain Group list query/search draft only within the same eligible Institution Admin session.
- Add focused deterministic tests and directly affected router/shell regressions.

### Non-goals

Do **not** implement:

- Group detail route/screen;
- Group create/edit/archive;
- Teacher/Student membership management;
- Parent–Student relationship management;
- row/detail navigation;
- future mutation placeholders/buttons;
- URL-backed Group list filters/query state;
- backend/schema/API changes;
- package/dependency changes;
- platform-file changes;
- a second router, API client, cache, serialization approach, or state-management architecture;
- unrelated refactors of the existing Institution User list.

---

## 4. Current Implementation Context

Reuse the established Institution Admin feature-first structure:

```text
frontend/lib/features/institution_admin/
  application/
  data/
  domain/
  presentation/
```

Relevant existing implementation patterns:

```text
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
frontend/lib/features/institution_admin/presentation/institution_admin_shell.dart

frontend/lib/features/institution_admin/domain/institution_user_list_query.dart
frontend/lib/features/institution_admin/data/dto/institution_user_list_dto.dart
frontend/lib/features/institution_admin/data/institution_user_list_remote_data_source.dart
frontend/lib/features/institution_admin/data/institution_user_list_repository_impl.dart
frontend/lib/features/institution_admin/application/institution_user_list_controller.dart
frontend/lib/features/institution_admin/application/institution_user_list_state.dart
frontend/lib/features/institution_admin/presentation/institution_admin_users_screen.dart
```

Use the existing:

```text
configured Dio client
DioFailureMapper
ApiFailure
ApiRequestException
ApiErrorCodes
Riverpod
GoRouter
InstitutionAdminShell
```

Do not refactor the User list merely to create speculative shared abstractions.

---

# 5. Exact Implementation Contract

## 5.1 Route registry and shell

Add exact route name:

```text
AppRouteNames.institutionAdminGroups =
    institution-admin-groups
```

Add exact route segment:

```text
AppRoutePaths.institutionAdminGroupsSegment =
    groups
```

Add exact canonical path:

```text
AppRoutePaths.institutionAdminGroups =
    /institution-admin/groups
```

### Route registries

Update the existing route registries exactly as follows:

1. Add `institutionAdminGroups` to:

```text
AppRoutePaths.protected
```

exactly once.

2. Because `AppRoutePaths.all` is composed from `auth + protected`, do not separately duplicate the path in `all`.

3. Add `institutionAdminGroups` to:

```text
institutionAdminPrimaryDestinations
```

between:

```text
institutionAdminUsers
institutionAdminInstitution
```

4. The existing Institution Admin static/approved-location classification must recognize Groups through the existing primary-destination composition. Do not add a duplicate special-case location if the current composition already covers it.

5. Add exactly one `GoRoute` for:

```text
name = AppRouteNames.institutionAdminGroups
path = AppRoutePaths.institutionAdminGroups
```

inside the **existing Institution Admin `ShellRoute`**.

6. Add:

```text
InstitutionAdminShellDestination.groups
```

between:

```text
users
institution
```

with:

```text
label = Groups
path = AppRoutePaths.institutionAdminGroups
```

Use suitable existing Material group/class-style icons; icon choice is a local presentation choice and must not create a new design-system abstraction.

7. `InstitutionAdminShellDestination.fromPath(...)` must resolve `/institution-admin/groups` to `groups`.

8. `_pageTitleForPath(...)` must return:

```text
Groups
```

for `/institution-admin/groups`.

9. Route name/path must remain globally unique.

### Navigation order

Exact shell navigation order:

```text
Dashboard
Users
Groups
Institution
Settings
```

For `/institution-admin/groups`:

```text
selected shell destination = Groups
page title = Groups
```

Do not create:

```text
a new ShellRoute
a new router
a nested Groups router family
```

### URL query / fragment policy

Group list search/filter/sort/page state is controller-owned.

Do not read, write, or synchronize list query state through URL query parameters or fragments.

Keep the existing Institution Admin static-route query/fragment policy unchanged. If a URL contains a query/fragment, it must not alter the Group list query model.

---

## 5.2 API read contract

Use only:

```text
GET /institution/groups
```

The configured Dio base URL already owns `/api/v1`.

Expected success:

```text
exactly HTTP 200
```

No other 2xx status is accepted as a valid Group-list success.

### Allowed query keys

Only:

```text
search
status
page
per_page
sort
direction
```

Defaults:

```text
search = null
status = null
page = 1
per_page = 20
sort = name
direction = asc
```

`status` values:

```text
active
archived
```

Allowed sorts:

```text
name
status
created_at
updated_at
```

Allowed directions:

```text
asc
desc
```

UI page-size options:

```text
20
50
100
```

### Exact serialization

Always send:

```text
page
per_page
sort
direction
```

Send only when non-null:

```text
search
status
```

Do not send:

```text
all
blank search
empty string for status
JSON null
current_page
institution_id
unknown key
array/list query value
unsupported enum value
```

Search serialization uses its normalized committed value from Section 5.3.

Use Dio `queryParameters`.

Do **not**:

- construct a raw query string;
- put query parameters into the path manually;
- send request body bytes;
- pass `data: {}`;
- pass `data: null`;
- send JSON null/form body/empty object as GET data;
- send a tenant selector/header.

Unexpected success status or malformed success payload maps to existing local:

```text
ApiFailureKind.invalidResponse
```

---

## 5.3 Query model and transitions

The Group query model owns exactly:

```text
search
status
page
perPage
sort
direction
```

Query equality/hash/deduplication uses all six logical values after search normalization.

### Search model

Search is two-state:

```text
searchDraft     = exact text visible in the field
committedSearch = normalized value in the server query
```

UI label:

```text
Search groups
```

Normalization:

```text
trim leading/trailing whitespace
blank after trim -> null
otherwise preserve case and content
```

Characters such as:

```text
%
_
!
apostrophe
non-ASCII text
```

remain literal user search text; Dio owns URL encoding and backend owns literal search escaping.

### Search length

Maximum:

```text
254 Unicode code points
```

Measure with the Dart equivalent of:

```text
value.runes.length
```

Do not measure with:

```text
UTF-8 byte length
UTF-16 code-unit/String.length semantics
```

for the contract boundary.

Exact local validation text:

```text
Search must be 254 characters or fewer.
```

### Search orchestration

1. Each valid text change cancels the prior timer and starts an exact 300 ms debounce.
2. At 300 ms of inactivity, commit normalized search.
3. Committed search change resets page to 1.
4. Enter/Search submission cancels the debounce and commits immediately.
5. Recommitting the same normalized query sends no duplicate GET.
6. Over-length normalized search:
   - shows the exact local validation text;
   - cancels pending debounce;
   - sends no GET.

### Pending valid search draft + another action

If the current valid search draft differs from committed search and a debounce is pending:

For:

```text
Status
Sort
Page size
Refresh
```

the controller must:

1. cancel the debounce;
2. include the current normalized search draft in the same resulting query;
3. reset page to 1 when search changed;
4. send only one logical GET.

Do not first request the old committed search and then send a second request after debounce.

For:

```text
Previous
Next
```

while a different valid search draft is pending:

- commit the pending search instead;
- load page 1;
- do not navigate within results for the old committed search.

### Invalid search draft + another action

While local over-length search validation exists:

The following must not send a GET:

```text
Search submit
Status change
Sort change
Page-size change
Previous
Next
Refresh
```

`Clear filters` remains enabled and restores a valid query state.

---

## 5.4 Status/filter/sort/page transitions

### Status filter

UI values:

```text
All statuses
Active
Archived
```

Machine values:

```text
null
active
archived
```

Changing status:

```text
reset page = 1
preserve current valid committed/pending-normalized search
preserve perPage/sort/direction
```

### Clear filters

`Clear filters` clears only:

```text
searchDraft
committed search
status
local search validation
```

and resets:

```text
page = 1
```

It preserves:

```text
perPage
sort
direction
```

If search/status are already clear, no local search error exists, and page is already 1:

```text
do not send a duplicate GET
```

### Sorting

Sortable UI columns:

```text
Name
Status
Created
Updated
```

Mapping:

```text
Name    -> name
Status  -> status
Created -> created_at
Updated -> updated_at
```

Rules:

- default = Name ascending;
- selecting a different sort field => direction `asc`;
- selecting the currently selected field => toggle `asc <-> desc`;
- sort change resets page to 1.

### Pagination

Previous/Next:

- change only page when no pending different search draft exists;
- preserve committed search/status/perPage/sort/direction;
- derive enabled state from authoritative server pagination.

Page size:

```text
20
50
100
```

Changing page size:

```text
reset page = 1
preserve search/status/sort/direction
```

### Refresh

Refresh:

```text
reload exactly the current committed logical query
```

except that a different pending valid search draft is first committed according to Section 5.3.

Refresh is duplicate-protected.

### Retry

Retry:

```text
reload exactly the failed committed query
```

Retry is duplicate-protected and does not silently reset filters/page/sort.

---

## 5.5 Empty-page correction

The backend may validly return:

```text
HTTP 200
data = []
requested page > current last_page
```

A logical request gets at most **one** automatic page correction.

When:

```text
data is empty
requested page > 1
correctionUsed = false
```

calculate:

```text
if total == 0:
    target = 1
else:
    target = max(1, min(last_page, requested_page - 1))
```

If target differs from requested page:

1. update committed query.page to target;
2. mark `correctionUsed = true`;
3. issue exactly one corrective GET;
4. preserve search/status/perPage/sort/direction;
5. keep the same latest-operation/session ownership.

Never perform a second automatic correction for the same logical query.

Page 1 never auto-corrects.

After the one correction:

- `total == 0` on page 1 becomes global or filtered empty;
- rows become normal data;
- an empty page with `total > 0` becomes a safe `emptyPage` state with manual recovery controls;
- stale correction responses cannot publish.

Every new user-initiated logical intent gets its own one-correction maximum.

---

## 5.6 Exact Group resource

Every Group item must contain exactly:

```text
id
name
level
subject_direction
description
status
teachers_count
students_count
archived_at
created_at
updated_at
```

Strict rules:

`id`

```text
canonical hyphenated UUID string
```

`name`

```text
required non-blank string
```

`level`

```text
nullable string
```

`subject_direction`

```text
nullable string
```

`description`

```text
nullable string
```

`status`

```text
active
archived
```

`teachers_count`

```text
JSON integer >= 0
```

`students_count`

```text
JSON integer >= 0
```

`created_at`

```text
required valid ISO-8601 UTC timestamp ending in Z
```

`updated_at`

```text
required valid ISO-8601 UTC timestamp ending in Z
```

`archived_at`

```text
null or valid ISO-8601 UTC timestamp ending in Z
```

Lifecycle invariant:

```text
status = active   -> archived_at == null
status = archived -> archived_at != null
```

Reject as malformed success if:

- required/unknown keys exist;
- scalar/nullability/type contract is wrong;
- UUID is malformed/noncanonical;
- status is unsupported;
- count is negative/non-integer;
- UTC timestamp is invalid, local, or offset instead of `Z`;
- lifecycle fields contradict status;
- duplicate Group IDs occur within one page.

Do not silently trim/default/coerce server Group resource values.

---

## 5.7 Exact list envelope

Require exactly:

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

Reject unknown/missing/renamed top-level, `meta`, or `pagination` keys.

Pagination values must be JSON integers and satisfy:

```text
page >= 1
page == requested page

per_page in 1..100
per_page == requested perPage

total >= 0

last_page >= 1
last_page == max(1, ceil(total / per_page))
```

Row invariants:

- row count <= `per_page`;
- if total == 0, data is empty and last_page == 1;
- if total > 0, row count <= total;
- page > last_page is valid only with empty data;
- duplicate Group IDs are rejected.

Do not accept:

```text
current_page
numeric strings
doubles
booleans
null pagination values
plausible default metadata when fields are missing
```

Malformed success maps to:

```text
ApiFailureKind.invalidResponse
```

---

## 5.8 Application state and async ownership

Follow the established Institution User list ownership style without copying unrelated behavior blindly.

The Group list application boundary owns:

```text
query
search draft
confirmed result/page
failure
local search validation
request presentation
session key
operation generation
in-flight logical query
retained query/search state
```

Required UI/application states:

```text
initial
loading
queryLoading
refreshing
data
globalEmpty
filteredEmpty
emptyPage
error
```

### Request ownership

The controller must:

- auto-load only for an eligible Institution Admin desktop session;
- suppress duplicate identical in-flight logical requests;
- allow a newer valid logical query to supersede an older one when current UI behavior permits the action;
- reject stale success/error completion from superseded requests;
- reject completion after disposal;
- reject completion from an old user/session/institution/device context;
- reject stale page-correction completion;
- never let previous-query rows masquerade as current-query confirmed data.

Explicit Refresh may retain only the current same-session confirmed rows and must show visible/semantic refreshing state.

Actual Dio cancellation is not required.

---

## 5.9 Session key and retained query

Eligibility requires all:

```text
authenticated
user exists
role = institution_admin
user.is_active = true
must_change_password = false
user.institution_id is non-empty
user.institution exists
user.institution.id == user.institution_id
user.institution.status = active
desktop surface
```

Bind retained Group list state to the established session identity convention:

```text
session user ID
session User object instance identity
institution ID
```

Retain only:

```text
committed query
search draft
```

Do not retain confirmed Group rows as authoritative cross-route cached data.

When the same eligible session returns to Groups:

- restore retained query/search draft;
- load the retained query authoritatively from the server.

Clear retained state and invalidate all request generations on:

```text
logout
bootstrap/session replacement
same-role account switch
cross-role account switch
institution change
inactive user
must-change-password transition
inactive institution
desktop eligibility loss
controller disposal/session loss
```

No prior-session rows/actions may appear in a new session's initial loading state.

---

## 5.10 Error and retry contract

Reuse:

```text
ApiFailure
ApiRequestException
DioFailureMapper
ApiErrorCodes
```

Never branch on backend human-readable message text.

### Session-authority failures

For exact server codes:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

do not leave protected Group data in a normal list-error state.

Apply the existing Institution Admin auth/session reconciliation behavior:

- clear Group rows/current protected list state;
- clear same-session retained Group state as required;
- invalidate pending operations;
- invoke the established bootstrap/session invalidation path where applicable;
- stale completion must not republish data.

Do not offer a normal Group-list Retry button while protected session authority is being reconciled/lost.

### Other read failures

For non-session failures, show:

```text
title: Unable to load groups
manual Retry: available
```

Retry repeats exactly the failed committed query and is duplicate-protected.

No automatic retry.

Safe messages:

| Failure | Message |
|---|---|
| `forbidden` | `You do not have permission to view groups.` |
| `validation_failed` | `The group list request did not match the API contract.` |
| `resource_not_found` | `The groups list could not be loaded.` |
| `rate_limited` | `Too many requests. Wait before trying again.` |
| connection | `Could not reach the server. Check the connection and try again.` |
| timeout | `The group list request timed out.` |
| invalid response | `The server returned an unexpected group list response.` |
| cancelled/current failure | `The group list request was cancelled.` |
| server/unknown/other safe failure | `The groups list could not be loaded.` |

Do not render/log:

```text
raw backend message
validation payload
Dio exception text
stack trace
raw URL
token
raw JSON
SQL/internal details
tenant/user private identifier
```

---

## 5.11 UI contract

Page heading:

```text
Groups
```

This task must **not** show:

```text
Create Group
Open/View Group
Edit
Archive
membership actions
```

### Toolbar

```text
Search groups
Status
Clear filters
Refresh
```

Page-size control belongs to pagination.

### Table columns

Exact list columns:

```text
Name
Level
Subject direction
Status
Teachers
Students
Created
Updated
```

Sortable:

```text
Name
Status
Created
Updated
```

Display rules:

- null `level` => `—`;
- null `subject_direction` => `—`;
- show `teachers_count` exactly;
- show `students_count` exactly;
- status visibly says `Active` / `Archived`;
- status must not be communicated by color alone;
- `created_at` / `updated_at` use existing Institution Admin UTC convention;
- `description` and `archived_at` are parsed/retained in the typed resource but are not list columns;
- rows are not clickable/selectable for navigation in this task.

### Required states

```text
initial/loading:
Loading groups

replacement query:
Loading matching groups

refresh:
keep current confirmed rows
show visible + semantic refresh progress

global empty:
No groups available

filtered/search empty:
No matching groups
Clear filters

error:
Unable to load groups
Retry

empty page after correction budget:
No groups on this page
manual Page 1 / Previous / Refresh when valid
```

Global empty must not include a Create Group action in this task.

---

## 5.12 Accessibility / keyboard / responsiveness

Required:

- predictable keyboard traversal;
- visible/reachable search/filter/refresh/pagination controls;
- search keyboard submit;
- sortable headers expose sort purpose/current direction semantically;
- loading/query-loading/refresh indicators use semantic/live-region labels;
- status includes visible text and semantics, not color only;
- Group counts remain readable with text scaling;
- long values use bounded text/tooltip behavior consistent with existing desktop lists;
- horizontal table overflow scrolls and never produces RenderFlex overflow;
- supported desktop resizing and text scale 2.0 do not overflow;
- controls that cannot safely act in a current state are visibly/semantically disabled;
- focus must not be moved to nonexistent future create/detail controls.

Do not introduce a new design system or breakpoint architecture.

---

## 5.13 Authorization / tenant isolation

Eligible frontend context is exactly:

```text
authenticated
role = institution_admin
active user
must_change_password = false
active own institution
desktop surface
```

Frontend must never send:

```text
institution_id
tenant selector
institution path segment selected by the client
custom tenant header
```

Institution scope remains backend-authoritative from the authenticated actor.

UI route guarding is UX only and is not authorization.

The route must not become an approved destination for:

```text
Platform Owner
Teacher
Student
Parent
mobile/unsupported Institution Admin surface
```

A stale response from another session/institution must never publish into the current Group list.

---

## 5.14 Persistence / mutations / concurrency

```text
Database/schema:
N/A — frontend read-only task

Persistent frontend write:
N/A

Mutations:
N/A

Optimistic UI:
N/A

Mutation idempotency/replay:
N/A
```

Only read-request async ownership, deduplication, latest-operation publication, and bounded page correction defined above apply.

---

# 6. Expected Files and Areas

Expected new production files:

```text
frontend/lib/features/institution_admin/domain/institution_group.dart
frontend/lib/features/institution_admin/domain/institution_group_list.dart
frontend/lib/features/institution_admin/domain/institution_group_list_query.dart
frontend/lib/features/institution_admin/domain/institution_group_list_repository.dart

frontend/lib/features/institution_admin/data/dto/institution_group_dto.dart
frontend/lib/features/institution_admin/data/dto/institution_group_list_dto.dart
frontend/lib/features/institution_admin/data/institution_group_list_remote_data_source.dart
frontend/lib/features/institution_admin/data/institution_group_list_repository_impl.dart

frontend/lib/features/institution_admin/application/institution_group_list_controller.dart
frontend/lib/features/institution_admin/application/institution_group_list_state.dart

frontend/lib/features/institution_admin/presentation/institution_admin_groups_screen.dart
```

Expected router/shell modifications:

```text
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
frontend/lib/features/institution_admin/presentation/institution_admin_shell.dart
```

Expected focused tests:

```text
frontend/test/features/institution_admin/institution_group_list_query_test.dart
frontend/test/features/institution_admin/institution_group_dto_test.dart
frontend/test/features/institution_admin/institution_group_list_dto_test.dart
frontend/test/features/institution_admin/institution_group_list_remote_data_source_test.dart
frontend/test/features/institution_admin/institution_group_list_repository_impl_test.dart
frontend/test/features/institution_admin/institution_group_list_controller_test.dart
frontend/test/features/institution_admin/institution_admin_groups_screen_test.dart
```

Directly affected existing tests:

```text
frontend/test/app/router/institution_admin_route_paths_test.dart
frontend/test/features/institution_admin/institution_admin_shell_test.dart
```

If a concrete implementation responsibility makes one listed new test file unnecessary because equivalent coverage is cleanly combined into another named focused Group test, that is allowed only when the final report names the real test file/command and explains the narrow placement reason.

Changes outside these areas require a concrete in-scope necessity and must be reported.

Forbidden changes:

```text
backend/
docs/
unrelated tasks
pubspec.yaml
pubspec.lock
frontend/android/
frontend/ios/
frontend/windows/
frontend/linux/
frontend/macos/
frontend/web/
unrelated features
```

---

# 7. Acceptance Criteria

- [ ] `Task ID = S04-FE-001` implementation stays within navigation + read-only Group list scope.
- [ ] Exact route name `institution-admin-groups`, segment `groups`, and path `/institution-admin/groups` are added.
- [ ] Groups appears exactly once in protected/approved routing and between Users and Institution in primary navigation.
- [ ] Exactly one Groups `GoRoute` exists inside the existing Institution Admin `ShellRoute`.
- [ ] Groups shell destination/title resolution is correct.
- [ ] Existing role/device/session routing restrictions remain intact.
- [ ] Group list uses only `GET /institution/groups`.
- [ ] Exact success status is 200 and GET sends no body.
- [ ] Query serialization always sends page/per_page/sort/direction and conditionally sends search/status only.
- [ ] Search uses trimmed 254-Unicode-code-point validation and exact 300 ms debounce.
- [ ] Pending-search interactions with filters/sort/page-size/Refresh/Previous/Next follow this contract and do not generate double requests.
- [ ] Invalid over-length search blocks query-changing requests except Clear filters.
- [ ] Clear filters clears only search/status, resets page 1, and preserves page size/sort/direction.
- [ ] Refresh and Retry use the exact current/failed committed query and are duplicate-protected.
- [ ] Strict Group + list/pagination parsing is implemented.
- [ ] Active/archived `archived_at` lifecycle invariants are enforced.
- [ ] One bounded empty-page correction uses the exact target formula and never loops.
- [ ] Loading/data/refresh/global-empty/filtered-empty/empty-page/error states work.
- [ ] No create/detail/edit/archive/membership action or row navigation is introduced.
- [ ] Same-session query/search retention works and clears across session/institution/device boundary.
- [ ] Duplicate requests and stale async completions cannot publish incorrect state.
- [ ] Session-authority failures reconcile with existing auth/session handling and do not leave stale Group data.
- [ ] Other list failures expose safe manual Retry and no raw backend/transport details.
- [ ] Keyboard/accessibility/responsive behavior is covered.
- [ ] No dependency/backend/schema/public API/platform change.
- [ ] Focused verification and directly affected regressions pass.
- [ ] `git diff --check` passes.
- [ ] Final diff contains no unrelated work.

---

# 8. Tests and Verification

Run Flutter/Dart commands from:

```text
frontend/
```

Do not run them from repository root.

## 8.1 Focused tests

From repository root:

```powershell
Push-Location frontend

fvm spawn 3.44.7 test `
  test/features/institution_admin/institution_group_list_query_test.dart `
  test/features/institution_admin/institution_group_dto_test.dart `
  test/features/institution_admin/institution_group_list_dto_test.dart `
  test/features/institution_admin/institution_group_list_remote_data_source_test.dart `
  test/features/institution_admin/institution_group_list_repository_impl_test.dart `
  test/features/institution_admin/institution_group_list_controller_test.dart `
  test/features/institution_admin/institution_admin_groups_screen_test.dart

Pop-Location
```

Required focused coverage includes:

- exact query defaults/equality/serialization;
- page/perPage/sort/direction always serialized;
- search/status omitted when null;
- search trim/blank/special/non-ASCII behavior;
- 254/255 Unicode code-point boundary;
- exact 300 ms debounce;
- pending-draft interactions with status/sort/page-size/Refresh/Previous/Next;
- invalid-search action blocking + Clear filters;
- clear-filter preservation rules;
- strict Group resource parsing;
- active/archived lifecycle invariant;
- strict list/pagination parsing;
- duplicate Group IDs;
- exact HTTP 200 + path/query + zero GET body;
- malformed/other-2xx success -> invalidResponse;
- repository mapping;
- initial/loading/queryLoading/refresh/data/empty/error states;
- page correction formula + one-correction maximum;
- duplicate request suppression;
- stale rapid-query success/error rejection;
- disposal/session/institution/device/account-switch ownership;
- same-session retained query/search and authoritative reload;
- session-authority reconciliation;
- safe manual Retry;
- screen toolbar/table/status/counts/timestamps;
- absence of create/detail/mutation/row-navigation controls;
- keyboard/semantics/text-scale/horizontal overflow.

## 8.2 Directly affected regression

From repository root:

```powershell
Push-Location frontend

fvm spawn 3.44.7 test `
  test/app/router/institution_admin_route_paths_test.dart `
  test/features/institution_admin/institution_admin_shell_test.dart

Pop-Location
```

Required regression assertions include:

- route registries stay internally consistent;
- Groups route name/path is unique;
- Groups is a protected Institution Admin primary destination;
- navigation order is Dashboard/Users/Groups/Institution/Settings;
- direct Groups route entry works only for eligible Institution Admin desktop session;
- non-Institution-Admin/unsupported-device behavior remains unchanged;
- shell title and selected destination are correct.

## 8.3 Static analysis

From repository root:

```powershell
Push-Location frontend
fvm spawn 3.44.7 analyze
Pop-Location
```

## 8.4 Format check

From repository root:

```powershell
Push-Location frontend

C:\Users\Administrator\fvm\versions\3.44.7\bin\cache\dart-sdk\bin\dart.exe `
  format --output=none --set-exit-if-changed lib test

Pop-Location
```

## 8.5 Manual check

```text
Not required — this read-only task's required behavior is covered by deterministic
domain/data/controller/router/shell/widget tests. Real-stack/Windows E2E belongs
to the Stage 4 integration/checkpoint workflow.
```

## 8.6 Always

From repository root:

```powershell
git diff --check
```

Then inspect the complete diff for:

- exact S04-FE-001 scope;
- route-registry correctness;
- feature-first placement;
- no Dio/JSON logic in Widgets;
- no parallel router/client/cache/state architecture;
- no backend-authoritative tenant logic moved into Flutter;
- no stale-response/session leakage;
- no unrelated refactor/format churn;
- no weakened tests;
- no debug output;
- no secrets;
- no generated/temp junk;
- no unintended public route/API/serialization change.

Do **not** run:

```text
full frontend test suite
Windows build
broad E2E
Frontend Phase 2
Stage integration
```

in this implementation task.

If implementation necessarily touches shared infrastructure beyond this verification scope and creates a material unhandled regression risk, report:

```text
BLOCKED
```

instead of silently expanding verification.

---

# 9. Delivery

Mode:

```text
Implementation + GitHub delivery
```

Branch:

```text
task/s04-fe-001-group-navigation-list
```

Commit:

```text
feat(frontend): add institution group list
```

PR:

```text
focused PR to main
```

Allowed task-bookkeeping changes:

```text
None
```

Do not modify Stage/task status/index bookkeeping during implementation unless the active orchestration step explicitly assigns it.

After merge, verify:

```text
local main == origin/main
ahead/behind = 0/0
working tree = clean
```

Acceptance requires the merged implementation to be present on `origin/main`.

If implementation/verification passes but safe GitHub delivery cannot complete:

```text
DELIVERY BLOCKED
```

---

# 10. Planning Provenance

For ChatGPT/reviewer traceability only.

Codex must **not** open these sources to rediscover/reinterpret task requirements.

| Source/reference | Decision already encoded in this contract |
|---|---|
| Current `frontend/lib/app/router/app_route_paths.dart` | Existing explicit route registries, primary/static Institution Admin destination composition |
| Current `frontend/lib/app/router/app_router.dart` | Reuse the existing Institution Admin `ShellRoute`; no second router |
| Current `frontend/lib/features/institution_admin/presentation/institution_admin_shell.dart` | Groups destination/title must integrate with existing shell destination resolution |
| Current Institution User list implementation | Query/search/pagination/session-key/retention/stale-request pattern to reuse locally |
| Current `frontend/AGENTS.md` | Feature-first Flutter boundaries, typed DTOs, Riverpod ownership, stale async, accessibility |
| Current Stage 4 backend Group index request/action/resource/tests | Exact list endpoint/query/resource/pagination contract |
| Approved Stage 4 frontend decomposition | FE-001 owns navigation + list only; create/detail begin in FE-002 |

---

# 11. Codex Final Report

Return concise evidence:

1. **Status:** `ACCEPTED`, `BLOCKED`, or `DELIVERY BLOCKED`.
2. Implementation summary.
3. Changed files and purpose.
4. Acceptance-criteria evidence.
5. Exact focused verification commands/results.
6. Route-registry/shell evidence.
7. Query serialization/search orchestration/page-correction evidence.
8. Strict DTO/pagination/error/retry evidence.
9. Session/security/tenant/stale-async evidence.
10. Accessibility/responsive evidence.
11. `git diff --check` + focused scope/diff self-review.
12. Commit/PR/merge/main-sync evidence.
13. Exact deviations/blockers.

If any product, architecture, API, security, tenant, async-ownership, lifecycle, routing, query-orchestration, or UX decision required by this task is missing or conflicts with current implementation, return:

```text
BLOCKED
```

instead of inventing behavior.
