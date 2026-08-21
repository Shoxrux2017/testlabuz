# S04-FE-002 — Institution Group Create and Detail

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S04-FE-002` |
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | `Frontend` |
| Status | `Draft` |
| Review | `Pending` |
| Depends on | `S04-FE-001 Accepted / Delivered` |
| Delivery | `Implementation + GitHub delivery` |

This file is the complete task-specific implementation contract for Codex.

> **Execution gate:** This file is intentionally stored before final review. Codex must not implement this task while `Status = Draft`. ChatGPT/reviewer must complete read-only review, resolve findings, change the task to `Approved`, and deliver that planning update to `main` first.

Codex must use only this contract, applicable `AGENTS.md` files, and directly relevant source/tests. Do not read product docs, roadmap, previous tasks, Stage history, or closure reviews to determine behavior.

---

## 2. Goal

Extend the Institution Admin Groups experience with:

1. a production-quality **Create Group** flow backed by:

```text
POST /api/v1/institution/groups
```

2. a production-quality **Group Detail** screen backed by:

```text
GET /api/v1/institution/groups/{group}
```

3. navigation from the S04-FE-001 Group list to create/detail routes.

This task does not implement Group edit/archive or membership management.

---

## 3. Scope

### Included

- Add canonical Institution Admin routes:
  - `/institution-admin/groups/new`
  - `/institution-admin/groups/:groupId`
- Add strict route/path helpers for Group UUID targets.
- Add `Create Group` entry points to the existing Group list.
- Make existing Group list rows open Group Detail.
- Implement controlled Create Group form/state/controller/data/repository flow.
- Implement strict Create Group response parsing and uncertain-outcome handling.
- Implement Group Detail data/repository/controller/state/screen.
- Reuse the strict Group model/DTO introduced by S04-FE-001.
- Preserve retained Group-list query state across create/detail navigation.
- Invalidate affected Group/dashboard reads after a create result that may have committed.
- Add focused deterministic tests.

### Non-goals

Do **not** implement:

- Group edit;
- Group archive;
- archive confirmation;
- Group reactivation;
- Teacher membership list/add/remove;
- Student membership list/add/remove;
- Parent–Student relationships;
- optimistic insertion into the Group list;
- optimistic Group counts;
- automatic replay/retry of Group creation;
- client-side uniqueness checking for Group name;
- backend/schema/API changes;
- dependency/package changes;
- a second router, API client, state framework, or cache architecture.

Those belong to later tasks.

---

## 4. Current Implementation Context

S04-FE-001 owns the Group list and establishes the Group read model, strict Group DTO, list/pagination query flow, list controller/state, Group list screen, and Groups shell destination.

Reuse those exact Group types and the existing Institution Admin architecture:

```text
frontend/lib/features/institution_admin/
  application/
  data/
  domain/
  presentation/
```

Also reuse established patterns from:

- Institution User create flow for controlled form/mutation/session ownership;
- Institution User detail flow for family provider, target ownership, refresh/not-found handling;
- Institution Admin route helpers and shell;
- configured Dio/failure mapper;
- current session reconciliation;
- Institution Admin UTC presentation formatting.

Do not refactor unrelated User code simply to make a generic abstraction.

---

## 5. Exact Implementation Contract

### 5.1 Routes and route classification

Add names:

```text
AppRouteNames.institutionAdminGroupCreate
AppRouteNames.institutionAdminGroupDetail
```

Add route paths/segments/parameter:

```text
institutionAdminGroupCreateSegment = new
institutionAdminGroupIdParameter = groupId

/institution-admin/groups/new
/institution-admin/groups/:groupId
```

The static `new` location must never be interpreted as a Group UUID detail target.

Add helpers equivalent in strictness to the existing Institution User detail helpers:

```text
isInstitutionAdminGroupCreatePath(...)
isInstitutionAdminGroupDetailPath(...)
institutionAdminGroupDetailLocation(groupId)
```

A valid Group detail location requires an untrimmed canonical hyphenated UUID.

The location builder must throw `ArgumentError` for malformed IDs, including whitespace, path separators, encoded path manipulation, query/fragment text, non-UUIDs, or `new`.

Both create/detail locations are approved Institution Admin locations.

Shell destination mapping:

```text
/institution-admin/groups
/institution-admin/groups/new
/institution-admin/groups/<valid UUID>
```

all select:

```text
InstitutionAdminShellDestination.groups
```

Shell page titles:

```text
/institution-admin/groups/new        -> Create Group
/institution-admin/groups/<UUID>     -> Group Details
```

For Group detail, query parameters and fragments are not allowed as part of the canonical direct-entry route. Mirror the existing Institution User detail safety pattern: malformed/non-canonical direct targets must not instantiate a Group detail API request and must fail/redirect through the existing safe Institution Admin routing boundary.

Do not add another `ShellRoute`.

---

## 5.2 S04-FE-001 Group list integration

After this task, the Group list adds:

### Header action

```text
Create Group
```

which navigates to:

```text
/institution-admin/groups/new
```

### Global-empty action

When no Groups exist globally, provide:

```text
Create Group
```

Filtered-empty behavior remains `Clear filters`; do not replace it with a create-specific flow.

### Row navigation

Each existing Group row opens:

```text
/institution-admin/groups/<group.id>
```

Use the same accessible row-selection convention already established by the Institution User table:

- semantic action/label on the primary visible Group name;
- row activation opens detail;
- keyboard/assistive technology can discover the action.

Do not add edit/archive/membership controls to list rows.

Retain the existing Group list query/search/status/sort/page state when navigating to create/detail and back.

---

## 5.3 Create Group API contract

Use exactly:

```text
POST /institution/groups
```

No query parameters.

JSON body contains exactly:

```json
{
  "name": "10-A",
  "level": "Grade 10",
  "subject_direction": "General",
  "description": "Optional description"
}
```

The client may send JSON `null` for nullable optional fields.

Do not send:

```text
id
institution_id
status
created_by_user_id
teachers_count
students_count
archived_at
created_at
updated_at
```

or any other key.

The configured Dio client owns the `/api/v1` base and JSON transport.

---

## 5.4 Create form fields and normalization

Fields:

```text
Name
Level
Subject direction
Description
```

### Name

- required;
- text input;
- trim before request;
- trimmed value must be non-empty;
- maximum 160 Unicode code points/characters;
- do not lowercase/title-case/rewrite internal whitespace.

Safe local messages:

```text
Group name is required.
Group name must be 160 characters or fewer.
```

### Level

- optional;
- maximum 100 characters after trim;
- exactly empty input `""` maps to JSON `null`;
- non-empty input is trimmed before request;
- spaces-only non-empty input is invalid and must not silently become `null`.

Safe local messages:

```text
Level must not contain only spaces.
Level must be 100 characters or fewer.
```

### Subject direction

- optional;
- maximum 160 characters after trim;
- exactly empty input maps to JSON `null`;
- non-empty input is trimmed;
- spaces-only non-empty input is invalid.

Safe local messages:

```text
Subject direction must not contain only spaces.
Subject direction must be 160 characters or fewer.
```

### Description

- optional multiline text;
- no client-defined maximum is introduced;
- exactly empty input maps to JSON `null`;
- non-empty input is trimmed;
- spaces-only non-empty input is invalid.

Safe local message:

```text
Description must not contain only spaces.
```

Do not normalize newlines, punctuation, case, or internal whitespace.

### Duplicate names

Do not check Group-name uniqueness locally.

The backend explicitly permits multiple Groups with the same normalized name. Duplicate names must not be treated as a validation conflict.

---

## 5.5 Create screen UX

Route:

```text
/institution-admin/groups/new
```

Heading:

```text
Create Group
```

Actions:

```text
Cancel
Create Group
```

Cancel:

- available only while no create request is in flight;
- clears create-route controller state;
- returns to `/institution-admin/groups`;
- no unsaved-changes confirmation is required in this task.

Submit:

- prevent duplicate submission while active;
- run local validation first;
- focus the first invalid field;
- while submitting, fields/Cancel/Create and conflicting shell navigation are disabled;
- expose visible + semantic progress:

```text
Creating group
```

Use `PopScope`/equivalent existing navigation protection so a normal back/pop does not abandon the route during the active mutation.

Do not use optimistic success.

---

## 5.6 Create success response

Success must be:

```text
201 Created
```

with exact top-level keys:

```json
{
  "data": {
    "...": "exact S04-FE-001 Group resource"
  },
  "message": "Group created successfully."
}
```

Require the exact message:

```text
Group created successfully.
```

Parse `data` with the strict Group DTO from S04-FE-001.

The returned resource must also satisfy the create snapshot:

- returned `name` equals normalized requested name;
- returned `level` equals normalized requested level/null;
- returned `subject_direction` equals normalized requested value/null;
- returned `description` equals normalized requested value/null;
- `status == active`;
- `teachers_count == 0`;
- `students_count == 0`;
- `archived_at == null`.

Any unexpected success status, malformed success envelope, malformed Group resource, wrong message, or mismatch between request snapshot and returned Group is **not confirmed success**.

### Confirmed success UI

On confirmed success:

1. invalidate affected Group-list data without discarding the S04-FE-001 retained query/search store;
2. invalidate/refresh Institution Admin dashboard data so Group totals cannot remain authoritative stale data;
3. clear create-route form/controller state;
4. show:

```text
Group created successfully.
```

as success feedback;
5. navigate to:

```text
/institution-admin/groups/<returned Group UUID>
```

The Group Detail route performs its normal authoritative GET. Do not seed the detail controller with an optimistic copy of the create response.

---

## 5.7 Definite create failures vs uncertain outcome

Group creation is non-idempotent and duplicate Group names are allowed. Therefore a blind replay may create a second Group.

### Definite failures

A failed POST may be treated as definite only when an exact expected error envelope is received for:

```text
401 authentication_required

403 forbidden
403 password_change_required
403 user_inactive
403 institution_inactive

422 validation_failed

429 rate_limited
```

For `422 validation_failed`:

- map known server field keys to local fields;
- do not display backend human-readable validation strings as application-control logic;
- safe field messages:

```text
name              -> Review the group name.
level             -> Review the level.
subject_direction -> Review the subject direction.
description       -> Review the description.
```

If a 422 error contains only protocol/body/unknown keys or cannot be mapped safely, show form-level:

```text
The group could not be created.
```

Other definite safe messages:

```text
forbidden    -> You do not have permission to create groups.
rate_limited -> Too many requests. Wait before trying again.
default      -> The group could not be created.
```

Session-authority errors follow the existing auth bootstrap/reconciliation pattern and must clear stale create authority.

### Uncertain create outcome

Treat the result as **unknown** when the request may have reached the server but commit success cannot be proven, including:

- connection interruption after dispatch;
- timeout;
- 5xx response;
- malformed/unexpected error envelope;
- unexpected HTTP status;
- malformed 201 body;
- malformed/mismatched success resource;
- unexpected exception after dispatch.

On unknown outcome:

- do not automatically retry or replay POST;
- do not expose a `Retry creation` or `Submit again` action on the same terminal state;
- invalidate Group-list and dashboard reads because the mutation may have committed;
- prevent the stale form from presenting confirmed failure or confirmed success;
- show a live-region/accessible warning:

```text
Group creation could not be confirmed. The request may have succeeded. Review Groups before creating another group.
```

Provide:

```text
Review Groups
```

which clears route-local create state and navigates to `/institution-admin/groups`.

Because duplicate names are valid, do **not** attempt to infer success by searching for a same-name Group.

A user who reviews the Group list and intentionally chooses to try again must explicitly reopen the Create Group route as a new operation.

---

## 5.8 Create async/session ownership

The create controller must bind the mutation to:

- authenticated Institution Admin identity;
- exact authenticated user instance/session;
- institution ID;
- desktop eligibility;
- immutable normalized create request snapshot;
- operation generation.

A stale completion must not:

- navigate from a later session;
- show success/failure to a different session/institution;
- clear a newer form;
- publish mutation feedback after route/session ownership is gone.

On route exit, session change, Institution change, logout, password-change gate, inactive account/institution, or device ineligibility, invalidate the active operation's publication authority.

Actual network cancellation is not required.

---

## 5.9 Group Detail API contract

Use exactly:

```text
GET /institution/groups/{groupId}
```

No query parameters.

No request body.

Success:

```text
200 OK
```

exact envelope:

```json
{
  "data": {
    "...": "exact S04-FE-001 Group resource"
  }
}
```

No success `message` is allowed.

Use the strict S04-FE-001 Group DTO.

Missing, inaccessible, cross-tenant, wrong-scope, or otherwise scope-hidden Group is represented by backend as:

```text
404 resource_not_found
```

Frontend must not distinguish existence across tenants.

---

## 5.10 Group Detail target and state ownership

Use an `autoDispose family`-style detail controller keyed by `groupId`, consistent with the current Institution User detail controller.

Before an API call:

- validate canonical Group UUID locally;
- malformed local targets produce a local unavailable/not-found presentation;
- no network request is issued for malformed target.

Bind detail reads to:

- target Group UUID;
- authenticated Institution Admin session identity;
- authenticated user instance;
- institution ID;
- desktop eligibility;
- operation generation.

Reject stale completion after:

- target change;
- superseding refresh;
- dispose;
- session/user/institution change;
- loss of desktop eligibility.

Suppress duplicate same-target in-flight reads.

---

## 5.11 Group Detail states and error behavior

Required states:

```text
initial/loading
data
refreshing
not_found
error
```

Initial/loading:

```text
Loading group
```

Refresh:

- keep confirmed current Group visible;
- show explicit progress;
- disable duplicate refresh.

404 `resource_not_found`:

```text
Group not found
The requested group is not available.
```

Actions:

```text
Back to Groups
```

General error:

```text
Unable to load group
```

Always provide `Back to Groups`.

Provide `Retry` only for retryable failures consistent with the existing Institution User detail pattern:

- connection;
- timeout;
- unknown local failure;
- server failure with HTTP >= 500.

Do not make invalid-response/validation/forbidden/rate-limit states automatically retryable unless existing shared failure semantics already classify them within the above allowed categories.

Session failures:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

must clear detail authority and use existing auth/session reconciliation.

On refresh returning `404 resource_not_found`, discard the previously displayed Group and enter `not_found`.

Never expose raw exceptions, response JSON, token data, URLs, stack traces, SQL, or private identifiers in error text.

---

## 5.12 Group Detail UI

Route:

```text
/institution-admin/groups/<groupId>
```

Toolbar/actions in this task:

```text
Back to Groups
Refresh
```

Do **not** show:

```text
Edit
Archive
Manage teachers
Manage students
```

Those belong to S04-FE-003/S04-FE-004.

Heading after data loads may use the Group name, while the shell title remains:

```text
Group Details
```

Display the following authoritative values:

```text
Name
Status
Level
Subject direction
Description
Teachers
Students
Archived at
Created
Updated
```

Display rules:

- `Status`: visible text `Active` / `Archived` and not color-only;
- null `level`, `subject_direction`, `description`: `Not provided`;
- current teacher/student counts exactly as returned;
- active Group `archived_at == null`: display `—`;
- archived Group: show archived timestamp;
- timestamps follow the existing Institution Admin UTC formatter/convention.

Long name/description/subject values must wrap or constrain safely without desktop overflow.

No relationship member list is fetched in this task.

---

## 5.13 Back/navigation and retained list state

From Create Group Cancel, unknown-outcome `Review Groups`, Group Detail `Back to Groups`, or normal successful future return:

```text
/institution-admin/groups
```

must restore the retained S04-FE-001 query/search/filter/sort/page state for the same eligible session.

Confirmed or uncertain create must force the actual Group list data to reload when next shown; do not keep stale confirmed list rows as authoritative.

Do not clear retained filters solely because create/detail was opened.

---

## 5.14 Accessibility / keyboard / focus / responsiveness

Create form:

- predictable focus order;
- labels associated with fields;
- field errors associated semantically;
- first invalid field receives focus after validation;
- Enter/submit behavior must not create duplicate requests;
- busy state exposes semantic progress;
- Cancel/Create disabled during active request;
- text scaling and supported desktop widths do not overflow.

Group list create action/row opening:

- keyboard and semantics discoverable;
- Group name semantic action communicates that it opens details.

Detail:

- Back and Refresh keyboard reachable;
- loading/refresh progress semantic;
- not-found/error feedback readable by assistive technology;
- detail labels and values remain usable with text scaling;
- long content wraps instead of producing RenderFlex overflow.

Do not introduce a new design system.

---

## 5.15 Security / tenant isolation

Eligible frontend context remains exactly:

```text
authenticated
role = institution_admin
active user
must_change_password = false
active own institution
desktop surface
```

The frontend must not send:

```text
institution_id
created_by_user_id
tenant selector
status override
```

during Group creation.

Group detail IDs identify only a requested resource; they never expand tenant scope.

The backend remains authoritative for authorization and tenant isolation.

A `404 resource_not_found` for detail must be presented identically for missing and cross-tenant targets.

Do not add Group-create/detail access to other role surfaces.

---

## 5.16 Persistence / lifecycle / concurrency

Database/schema:

```text
N/A — frontend task
```

Client-authoritative Group lifecycle:

```text
N/A — backend owns it
```

Create replay/idempotency:

```text
No Idempotency-Key contract exists for Group creation.
No automatic replay is allowed.
Unknown outcome requires list review before a new explicit operation.
```

Optimistic list/detail changes:

```text
Not allowed.
```

---

## 6. Expected Files / Areas

Reuse S04-FE-001 Group model/DTO/list files.

Expected new files may include:

```text
frontend/lib/features/institution_admin/domain/institution_group_create.dart
frontend/lib/features/institution_admin/domain/institution_group_create_repository.dart
frontend/lib/features/institution_admin/domain/institution_group_detail_repository.dart

frontend/lib/features/institution_admin/data/dto/institution_group_create_dto.dart
frontend/lib/features/institution_admin/data/dto/institution_group_detail_dto.dart
frontend/lib/features/institution_admin/data/institution_group_create_remote_data_source.dart
frontend/lib/features/institution_admin/data/institution_group_create_repository_impl.dart
frontend/lib/features/institution_admin/data/institution_group_detail_remote_data_source.dart
frontend/lib/features/institution_admin/data/institution_group_detail_repository_impl.dart

frontend/lib/features/institution_admin/application/institution_group_create_controller.dart
frontend/lib/features/institution_admin/application/institution_group_create_state.dart
frontend/lib/features/institution_admin/application/institution_group_detail_controller.dart
frontend/lib/features/institution_admin/application/institution_group_detail_state.dart

frontend/lib/features/institution_admin/presentation/institution_admin_group_create_screen.dart
frontend/lib/features/institution_admin/presentation/institution_admin_group_detail_screen.dart
```

Modify only as required:

```text
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
frontend/lib/features/institution_admin/presentation/institution_admin_shell.dart
frontend/lib/features/institution_admin/presentation/institution_admin_groups_screen.dart
```

Focused tests go under the corresponding existing `frontend/test/...` hierarchy.

If S04-FE-001 chose slightly different but equivalent Group filenames, extend those established files instead of duplicating models/DTOs.

Forbidden changes:

- `backend/`;
- `docs/`;
- unrelated tasks;
- unrelated features;
- `pubspec.yaml`;
- `pubspec.lock`;
- platform folders.

Any extra file requires concrete in-scope necessity and must be reported.

---

## 7. Acceptance Criteria

- [ ] `/institution-admin/groups/new` is canonical, approved, and selects Groups with shell title `Create Group`.
- [ ] `/institution-admin/groups/:groupId` uses strict canonical UUID routing, selects Groups, and uses shell title `Group Details`.
- [ ] Static `new` cannot be interpreted as a detail ID.
- [ ] Group list now exposes Create Group and accessible row-to-detail navigation.
- [ ] S04-FE-001 retained list query state survives create/detail navigation.
- [ ] Create form uses exact fields, normalization, limits, and nullable behavior.
- [ ] Duplicate Group names are allowed with no client uniqueness rule.
- [ ] Create sends exactly one allowed JSON request with no tenant/protected fields.
- [ ] Definite 401/403/422/429 failures are safely mapped.
- [ ] Ambiguous create outcomes never auto-replay and require Review Groups.
- [ ] Confirmed create invalidates Group-list/dashboard reads, shows success feedback, and navigates to authoritative detail GET.
- [ ] Group Detail consumes only exact GET and strict Group DTO.
- [ ] Missing/cross-tenant detail is the same `Group not found` UI.
- [ ] Detail refresh/stale-target/session ownership is safe.
- [ ] Detail shows all specified fields/counts/timestamps.
- [ ] No edit/archive/membership behavior is introduced.
- [ ] Keyboard/accessibility/focus/responsive requirements pass.
- [ ] No backend/schema/dependency/public API change.
- [ ] Focused verification and directly affected regressions pass.
- [ ] `git diff --check` passes.
- [ ] Diff has no unrelated changes.

---

## 8. Focused Tests and Verification

### Required focused coverage

#### Route/path tests

- exact create/detail route names/paths/segments/parameter;
- primary/approved location integration;
- valid lower/upper canonical UUIDs;
- `new` exclusion;
- malformed/path-manipulation UUID rejection;
- query/fragment detail safety;
- Groups shell destination/title mapping.

#### Create domain/form

- default form;
- name trim/required/max;
- optional empty => null;
- spaces-only optionals invalid;
- level/subject max;
- description no invented maximum;
- exact request JSON;
- duplicate names are not rejected locally.

#### Create remote/repository

- exact POST path/body/no query;
- exact 201 `{data,message}`;
- strict message;
- returned snapshot/status/count/archive invariants;
- definite exact 401/403/422/429 mapping;
- connection/timeout/5xx/malformed response/unexpected status => unknown outcome;
- malformed/mismatched 201 => unknown outcome;
- no automatic replay.

#### Create controller

- eligible-session behavior;
- local/server validation;
- first-error ownership;
- duplicate submit suppression;
- confirmed-success publication;
- Group-list/dashboard invalidation;
- unknown terminal state and Review Groups requirement;
- stale completion rejection on route/session/institution/device change;
- no navigation/feedback from stale operation.

#### Detail DTO/data/repository

- exact GET path;
- no query/body;
- exact `{data}` envelope;
- strict Group DTO reuse;
- 404 mapping;
- malformed success handling.

#### Detail controller

- invalid UUID => no request/local unavailable;
- initial load;
- data;
- refresh retaining confirmed data;
- duplicate request suppression;
- retryable vs non-retryable failure;
- 404 -> not found;
- refresh 404 removes stale detail;
- stale target/session/institution/device/dispose completion rejection;
- session-authority reconciliation.

#### Widgets

- Group list Create Group button;
- global-empty Create Group action;
- filtered-empty remains filter-oriented;
- accessible row/detail navigation;
- Create screen fields, validation, focus, busy controls, Cancel;
- confirmed success feedback/navigation;
- uncertain-outcome warning + Review Groups with no retry-submit;
- Detail loading/data/refresh/not-found/error;
- absence of edit/archive/membership controls;
- keyboard/text-scale/narrow-desktop overflow behavior.

### Focused test command

Run only the new S04-FE-002 tests plus S04-FE-001 Group-list tests directly changed by this task.

Expected command shape:

```powershell
fvm spawn 3.44.7 test `
  test/features/institution_admin/institution_group_create_domain_test.dart `
  test/features/institution_admin/institution_group_create_remote_data_source_test.dart `
  test/features/institution_admin/institution_group_create_repository_impl_test.dart `
  test/features/institution_admin/institution_group_create_controller_test.dart `
  test/features/institution_admin/institution_group_detail_remote_data_source_test.dart `
  test/features/institution_admin/institution_group_detail_repository_impl_test.dart `
  test/features/institution_admin/institution_group_detail_controller_test.dart `
  test/features/institution_admin/institution_admin_group_create_screen_test.dart `
  test/features/institution_admin/institution_admin_group_detail_screen_test.dart `
  test/features/institution_admin/institution_admin_groups_screen_test.dart
```

If the final focused filenames differ because S04-FE-001 established equivalent names/placement, use those real paths and report the exact command.

### Directly affected regression

```powershell
fvm spawn 3.44.7 test test/app/router/institution_admin_route_paths_test.dart test/features/institution_admin/institution_admin_shell_test.dart
```

Also rerun any S04-FE-001 route/list focused test directly modified by create/detail integration.

### Static analysis

```powershell
fvm spawn 3.44.7 analyze
```

### Format check

```powershell
C:\Users\Administrator\fvm\versions\3.44.7\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed lib test
```

### Build

```text
Not required for this task.
```

### Always

```text
git diff --check
```

Then inspect the complete diff for:

- exact scope;
- no unrelated refactor/format churn;
- no weakened tests;
- no raw-error/secret/debug output;
- no unintended router/API/serialization behavior;
- create unknown-outcome safety;
- correct stale async/session ownership;
- no optimistic backend-authoritative state.

Do not run the full frontend suite, Windows build, broad E2E, or Frontend Phase 2 in this task. Those belong to the frontend block checkpoint unless a concrete unexpected shared-infrastructure risk invalidates the verification assumptions; in that case report the mismatch instead of silently broadening verification.

---

## 9. Delivery

Future Build Runner/Codex execution uses normal task delivery:

```text
branch: task/s04-fe-002-group-create-detail
commit: feat(frontend): add group create and detail
PR: focused PR to main
```

After merge:

```text
local main == origin/main
ahead/behind = 0/0
working tree = clean
```

Do not modify Stage/task bookkeeping during implementation unless the active orchestration step explicitly assigns it.

If implementation/verification succeeds but safe GitHub delivery cannot complete, report:

```text
DELIVERY BLOCKED
```

---

## 10. Codex Completion Report

Return concise evidence:

1. `ACCEPTED`, `BLOCKED`, or `DELIVERY BLOCKED`.
2. Implementation summary.
3. Changed files and purpose.
4. Acceptance-criteria evidence.
5. Exact verification commands/results.
6. Create uncertainty/replay-safety evidence.
7. Session/security/tenant evidence.
8. `git diff --check` + focused scope/diff self-review.
9. Commit/PR/merge/main-sync evidence.
10. Exact deviations/blockers.

If any product, architecture, API, security, tenant, lifecycle, async-ownership, mutation-outcome, or UX decision required by this task is missing or conflicts with current implementation, return `BLOCKED` instead of inventing behavior.
