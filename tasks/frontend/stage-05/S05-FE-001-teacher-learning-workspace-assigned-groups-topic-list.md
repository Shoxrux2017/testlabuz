# S05-FE-001 — Teacher Learning Workspace, Assigned Groups and Topic List

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S05-FE-001` |
| Stage | `Stage 5 — Topics and Learning Materials` |
| Area | Frontend |
| Status | `Approved` |
| Planning / readiness baseline | `origin/main @ a407cf9250357f7d4a674da806a52f469476ba51` |
| Dependency gate | `S05-BE-001…005 Accepted / Delivered; Backend Phase 2 PASS` |
| Backend Phase 2 audited baseline | `999f477f6a281f2266ad4abbded8b0732b5d789c` |
| Verification model | `Workflow v3 — Lean Verification` |
| Delivery owner | `Project Owner` |

This file is the complete task-specific implementation contract for Codex.

Codex must use only:

1. this task contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. directly relevant existing frontend source and tests required to implement this task.

Codex must not read product docs, roadmap files, Stage history, previous task specifications, checkpoint reviews, closure reviews, or unrelated modules to determine requirements.

If current source materially conflicts with this contract, stop and report the exact conflict instead of making a product, UX, API, architecture, security, lifecycle, package, or routing decision.

### Mandatory implementation-entry gate

Because Stage 5 frontend contracts are being prepared before sequential
implementation, Codex must **not** start this task merely from the planning SHA
recorded above.

Immediately before implementation, orchestration must confirm:

```text
all approved Stage 5 frontend planning contracts/bookkeeping are delivered
current origin/main is re-checked
S05-FE-001 remains the next permitted frontend implementation task
actual current Teacher placeholder/router/network/test baseline is re-inspected
clean synchronized local main
```

Freeze that current `origin/main` SHA as the implementation baseline for the
Codex run.

The planning/readiness baseline remains historical evidence of the contract
design; it is not permission to implement against stale source.

---

## 2. Goal

Replace the current generic Teacher `/teacher` placeholder with a real Stage 5 Teacher learning workspace backed by the delivered Teacher Group and Topic APIs.

The workspace must let an authenticated Teacher:

- view currently assigned active Groups;
- search and page through those Groups;
- view owned/in-scope Topics;
- search Topics;
- filter Topics by status;
- filter Topics by a selected assigned Group;
- page and refresh results;
- use the same capability safely on approved desktop and mobile surfaces.

This task owns the read/list Teacher learning workspace only.

---

## 3. Scope

### Included

Implement a new feature-first Teacher area under:

```text
frontend/lib/features/teacher/
```

using the existing project responsibility flow:

```text
presentation/
application/
domain/
data/
```

Implement:

- real `/teacher` workspace;
- assigned Group projection;
- Topic list;
- Group search and pagination;
- Topic search, status filter, selected-Group filter and pagination;
- independent loading/error/empty/refresh handling for Groups and Topics;
- strict typed DTO/domain mapping;
- configured Dio data sources;
- repository contracts/implementations;
- focused Riverpod controllers/state;
- stale-request/session safety;
- responsive desktop/mobile UI;
- existing auth/session logout behavior;
- focused tests and directly affected routing regressions.

### Non-goals

Do **not** implement:

- Topic creation;
- Topic detail route/screen;
- Topic editing;
- Topic activation/close/archive actions;
- Learning Material UI;
- upload/download/open/save behavior;
- Student functionality;
- Homework or Blitz functionality;
- Teacher child-route family or new `ShellRoute`;
- dead/disabled future-feature buttons;
- placeholder Create/Detail screens;
- URL-backed list-filter state;
- backend/API/schema changes;
- new Flutter packages;
- new state-management framework;
- second API client;
- generic speculative shared abstractions;
- unrelated refactors;
- full frontend suite;
- Windows/Android build;
- E2E.

### Authoring boundary

`/teacher` becomes the canonical Teacher learning/Topic workspace.

Do not render an actionable `Create Topic` control in this task because `S05-FE-002` owns the real create route and form. `S05-FE-002` will add the desktop authoring action together with its working destination.

Likewise, Topic rows/cards are not detail links in this task. `S05-FE-002` owns Topic detail navigation.

---

## 4. Existing Architecture Contract

Reuse the existing:

```text
GoRouter
Riverpod
configured Dio client
DioFailureMapper
ApiFailure
ApiRequestException
ApiErrorCodes
AuthSessionController
SessionInvalidationSignal
AppDeviceSurface
```

Required responsibility flow:

```text
Presentation
  → Riverpod Controller/State
    → Repository contract
      → Repository implementation
        → Remote data source
          → configured Dio
```

Widgets must not:

- call Dio directly;
- construct API URLs;
- parse raw JSON;
- infer tenant ownership;
- implement server lifecycle rules;
- inspect human-readable backend messages to make application decisions.

Do not create a Teacher shell or second routing architecture in this task.

---

## 5. Routing and Session Entry

Keep the existing canonical path and route identity:

```text
/teacher
```

Change only its rendered destination:

```text
RoleEntryScreen
→ TeacherLearningWorkspaceScreen
```

Do not add Teacher child routes in this task.

Preserve current route behavior:

```text
Teacher + desktop → /teacher
Teacher + mobile  → /teacher
unsupported role/device → existing redirect behavior
must_change_password → existing password-change flow
unauthenticated → existing login flow
```

`RoleEntryScreen` remains available for still-placeholder Student/Parent entry flows.

---

## 6. API Contract

The configured Dio base URL already owns:

```text
/api/v1
```

### 6.1 Assigned Groups

Use only:

```text
GET /teacher/groups
```

Accept success only as exactly:

```text
HTTP 200
```

Send no request body.

Always send:

```text
page
per_page
sort
direction
```

Use:

```text
page      = current page
per_page  = 20
sort      = name
direction = asc
```

Send `search` only when the normalized value is non-null.

Do not send:

```text
institution_id
teacher_id
status
unknown query keys
blank search
JSON body
```

#### Group search

UI label:

```text
Search assigned groups
```

Rules:

```text
trim leading/trailing whitespace
blank → null
max = 254 Unicode code points
debounce = 300 ms
```

Measure the limit using Unicode code points (`runes`), not UTF-8 bytes or UTF-16 code-unit length.

Invalid local search text:

```text
Search must be 254 characters or fewer.
```

No request is sent while that local validation error remains.

### 6.2 Topics

Use only:

```text
GET /teacher/topics
```

Accept success only as exactly:

```text
HTTP 200
```

Send no request body.

Always send:

```text
page
per_page
sort
direction
```

Use:

```text
page      = current page
per_page  = 20
sort      = created_at
direction = desc
```

Send only when non-null:

```text
group_id
status
search
```

Allowed Topic statuses:

```text
draft
active
closed
archived
```

Do not send:

```text
institution_id
teacher_id
unknown query keys
blank search
JSON body
```

#### Topic search

UI label:

```text
Search topics
```

Search uses the same:

```text
trim
blank → null
254 Unicode-code-point maximum
300 ms debounce
```

Local validation text:

```text
Search must be 254 characters or fewer.
```

#### Group filter

A Group returned by `/teacher/groups` may be selected as the Topic `group_id` filter.

Selecting a Group:

```text
preserve Topic search
preserve Topic status
set group_id
reset Topic page = 1
load once
```

The selected Group remains selected even if the currently visible Group search/page no longer contains that Group. Absence from one paginated Group response is not evidence that authorization ended.

Provide an explicit:

```text
All groups
```

or equivalent clear-group action.

Clearing the Group filter:

```text
group_id = null
reset Topic page = 1
preserve Topic search/status
```

---

## 7. Query Orchestration

For both searches:

1. valid text change cancels the previous timer;
2. wait exactly 300 ms;
3. normalize and commit;
4. search change resets that list to page 1;
5. Enter/Search commits immediately;
6. recommitting the same logical query sends no duplicate GET.

If a valid uncommitted search draft exists and the user changes another Topic filter or refreshes:

```text
cancel debounce
commit current normalized search in the same resulting query
send one logical request
```

Do not request the old query and then a second query after debounce.

While a search is over 254 code points, query-changing actions for that list must not issue a GET until the draft is corrected or cleared.

---

## 8. DTO and Domain Contract

Use strict typed parsing consistent with the existing frontend.

Malformed successful API responses must map to:

```text
ApiFailureKind.invalidResponse
```

Do not coerce wrong types, silently default missing fields, or ignore unknown resource/envelope keys.

### 8.1 Teacher Group

Each `/teacher/groups` item contains exactly:

```text
id
name
level
subject_direction
status
```

Rules:

```text
id                canonical hyphenated UUID
name              required non-blank string
level             nullable string
subject_direction nullable string
status            active
```

`GET /teacher/groups` represents currently assigned active Groups, so any other Group status is an invalid success payload.

A reusable Teacher Group summary model may support `archived` because the nested Group inside a Topic may legitimately be archived.

### 8.2 Teacher Topic

Each Topic contains exactly:

```text
id
group
title
description
subject
student_instructions
lesson_at
status
activated_at
closed_at
archived_at
created_at
updated_at
```

Nested `group` contains exactly:

```text
id
name
level
subject_direction
status
```

Nested Group status:

```text
active
archived
```

Topic status:

```text
draft
active
closed
archived
```

Required scalar behavior:

```text
id                   canonical UUID
title                non-blank string
description          nullable string
subject              non-blank string
student_instructions non-blank string
lesson_at            null or valid UTC ISO-8601 timestamp ending Z
created_at            valid UTC ISO-8601 timestamp ending Z
updated_at            valid UTC ISO-8601 timestamp ending Z
```

Lifecycle timestamp invariants:

```text
draft:
  activated_at = null
  closed_at    = null
  archived_at  = null

active:
  activated_at != null
  closed_at     = null
  archived_at   = null

closed:
  activated_at != null
  closed_at    != null
  archived_at   = null

archived:
  archived_at != null
  and either:
    activated_at = null && closed_at = null
  or:
    activated_at != null && closed_at != null
```

`lesson_at` must be parsed and retained as an authoritative UTC instant.

FE-001 must **not display it as institution-local time**. Do not add a timezone dependency in this task.

### 8.3 List envelope

Both endpoints require exactly:

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

Require exact top-level/meta/pagination keys.

Validate:

```text
page >= 1
page == requested page
per_page == requested per_page
total >= 0
last_page == max(1, ceil(total / per_page))
row count <= per_page
duplicate resource IDs are rejected
page > last_page is valid only when data is empty
```

---

## 9. Controllers and Stale-State Safety

Use two independent focused controllers:

```text
Teacher assigned Group list
Teacher Topic list
```

Do not create one monolithic controller for the entire workspace.

Both controllers must derive an eligible Teacher session from:

```text
AuthSessionStatus.authenticated
role = teacher
user active
must_change_password = false
non-empty institution_id
user.institution.id == user.institution_id
institution.status = active
device surface = desktop OR mobile
```

Use a session ownership key sufficient to distinguish:

```text
user ID
current AuthUser instance/session
institution ID
device surface
```

Every async load must also have operation generation/ownership protection.

A result may publish only when:

```text
controller not disposed
operation is latest
query is still current
Teacher session key is still current
```

Cancel search debounce and invalidate outstanding operations when:

```text
provider disposes
session changes
institution changes
role becomes ineligible
device surface becomes ineligible
```

Never publish a previous Teacher/session response into a later authenticated session, even if the same account ID logs in again.

Do not retain list/query state across a different authenticated session.

---

## 10. Pagination and Empty-Page Recovery

Both lists use server pagination with fixed:

```text
per_page = 20
```

Provide:

```text
Previous
Next
current page / last page
```

No page-size control and no sort UI are required.

If a valid response returns an empty page while requested page > 1, allow at most one automatic correction for that logical intent.

Use:

```text
if total == 0:
  target = 1
else:
  target = max(1, min(last_page, requested_page - 1))
```

If target differs:

```text
update page
issue exactly one corrective GET
preserve filters/search
preserve same operation/session ownership
```

Never loop automatic corrections.

---

## 11. Selected-Group Revocation Reconciliation

`GET /teacher/topics?group_id=...` may return:

```text
404 resource_not_found
```

when a previously selected Group is no longer inside current Teacher scope.

Only when a Topic request contains a selected `group_id`, handle this as stale filter-target reconciliation:

1. discard that selected Group filter;
2. reset Topic page to 1;
3. preserve valid Topic search/status;
4. refresh the assigned Group list;
5. issue one unfiltered Topic reload;
6. show a non-sensitive transient notice such as:

```text
The selected group is no longer available. Showing topics you can currently access.
```

Do not disclose whether the Group was deleted, archived, reassigned, foreign, or otherwise inaccessible.

Do not perform this reconciliation for unrelated `404` responses.

Do not allow a reconciliation loop.

---

## 12. Independent Section State

Groups and Topics load independently.

Initial eligible workspace entry starts both reads without requiring the Group request to finish before Topic loading.

A Group error must not hide a successful Topic list.

A Topic error must not hide a successful Group list.

Important:

```text
No active assigned Groups
≠
No readable Topics
```

The Topic API may still expose Teacher-owned historical Topics whose current readable Group is archived.

Therefore the UI must not derive Topic emptiness from the Group endpoint.

Each section supports the states required by its responsibility:

```text
initial loading
query loading
refreshing with existing data retained
data
global empty
filtered empty
recoverable empty page
error + retry
```

---

## 13. Desktop UX

Desktop Teacher workspace uses the current `/teacher` route.

Header must show:

```text
TestLabUz
Teacher
current user
institution
Sign out
```

Use existing auth session state; do not fetch identity again.

Main content:

```text
Assigned Groups
Topics
```

For a sufficiently wide desktop window, use a two-column layout:

```text
left  → Assigned Groups
right → Topics
```

At a narrow desktop width, stack the two sections vertically rather than introducing horizontal page overflow.

Use approximately `1000 logical px` as the responsive layout boundary. Small local adjustments needed to fit the existing Material presentation are allowed, but behavior must remain deterministic and tested.

Assigned Group cards show:

```text
name
level when present
subject direction when present
selected state
```

Topic cards show at minimum:

```text
title
subject
Topic status
Group name
Group status
```

Do not display lifecycle controls.

Do not display `lesson_at` as a local educational date in FE-001.

Use Wrap/flexible layouts for controls and preserve keyboard/focus usability.

---

## 14. Mobile UX

Teacher mobile remains on the same canonical:

```text
/teacher
```

Use a single-column scroll layout.

Show:

```text
Assigned Groups section
Topics section
```

Cards and controls must fit normal phone widths without horizontal scrolling.

Mobile supports:

```text
view assigned Groups
Group search/pagination
select Group as Topic filter
Topic search
Topic status filter
Topic pagination
refresh/retry
read Topic summary/status
sign out
```

Mobile does **not** expose:

```text
Create Topic
Edit
Activate
Close
Archive
Material management
```

Do not use viewport width to decide whether the Teacher role is permitted. `AppDeviceSurface` remains the authorization-facing device classification; layout width controls presentation only.

---

## 15. Empty and Error UX

### Group global empty

When Group query has no search and total is zero:

```text
No active assigned groups
```

Explain that no active Group is currently assigned to this Teacher.

Do not hide the Topic section.

### Group filtered empty

```text
No matching assigned groups
```

Provide search clear/reset.

### Topic global empty

When no Topic search/status/group filter exists and total is zero:

```text
No topics yet
```

Do not render a fake Create Topic action in this task.

### Topic filtered empty

```text
No matching topics
```

Provide clear filters.

### Error mapping

Branch on stable `ApiFailure` / machine codes only.

Use safe UI behavior for:

```text
forbidden
validation_failed
resource_not_found
rate_limited
server_error
connection
timeout
invalidResponse
unknown
```

Never display raw backend, Dio, stack-trace, SQL, URL, token, or parser text.

For these session-authority codes:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

clear Teacher feature state immediately.

`authentication_required` continues through the existing session invalidation signal.

For the other session-authority codes, trigger the existing Auth session bootstrap/reconciliation pattern so the router can move to the authoritative state.

Do not introduce parallel authentication logic.

---

## 16. Security and Tenant Rules

The frontend must never send or derive an authority selector such as:

```text
institution_id
teacher_id
```

Backend remains authoritative for:

```text
institution isolation
Teacher role
current Teacher–Group membership
Topic ownership
Topic readable scope
Group lifecycle
Topic lifecycle
existence privacy
```

UI visibility is usability only and is never an authorization boundary.

Do not store or expose data from a prior session after authentication/session ownership changes.

Do not treat possession of a Group or Topic UUID as access authority.

---

## 17. Acceptance Criteria

The task is accepted only when all of the following are true:

- `/teacher` renders the real Teacher learning workspace instead of `RoleEntryScreen`.
- Existing Teacher desktop/mobile entry routing remains correct.
- Student/Parent placeholder behavior is not changed.
- Assigned Groups come only from `GET /teacher/groups`.
- Topics come only from `GET /teacher/topics`.
- Requests use only the exact allowed query contract.
- No tenant/Teacher selector is sent by the client.
- Group and Topic responses are strictly typed and malformed success is rejected.
- Group search and Topic search follow the exact 300 ms / 254-code-point rules.
- Topic status filtering works for all four statuses.
- selecting an assigned Group correctly filters Topics.
- selected-Group `404` safely reconciles without existence leakage or retry loop.
- Group and Topic pagination work and cannot enter an automatic correction loop.
- Group and Topic sections fail independently.
- empty state distinguishes no active Groups from no Topics.
- stale responses cannot publish after query/session/device changes.
- session-authority failures reconcile through existing auth infrastructure.
- desktop wide/narrow layouts are usable.
- mobile layout has no desktop authoring controls.
- `lesson_at` is not incorrectly rendered in device-local time.
- no new dependency/package is added.
- no backend/schema/API change is made.
- no Topic create/detail/edit/lifecycle implementation is included.
- focused tests and directly affected regressions pass.
- `git diff --check` passes.
- final diff contains no unrelated work.

---

## 18. Required Focused Tests

Add focused tests under:

```text
frontend/test/features/teacher/
```

Cover at minimum:

### Query/domain/DTO

- Group query exact serialization/defaults/search normalization.
- Topic query exact serialization/defaults/group/status/search behavior.
- 254 Unicode-code-point validation.
- strict Group resource parsing.
- strict Topic + nested Group parsing.
- lifecycle timestamp invariants.
- UTC `Z` timestamp validation.
- exact pagination envelope validation.
- duplicate-ID rejection.
- malformed/unknown fields → invalid response behavior.

### Remote data sources / repositories

Verify:

```text
GET /teacher/groups
GET /teacher/topics
```

including:

- exact query parameters;
- no body;
- exact 200 requirement;
- Dio failure mapping;
- malformed success mapping.

Repository tests are required where needed to verify data-source-to-domain delegation; do not add redundant tests for trivial language mechanics.

### Group controller

Cover:

- eligible Teacher initial load;
- ineligible session performs no read;
- search debounce/Enter/deduplication;
- pagination;
- refresh/retry;
- global/filtered/empty-page states;
- bounded page correction;
- stale response rejection;
- logout/session replacement rejection;
- session-authority error clearing.

### Topic controller

Cover:

- initial unfiltered load;
- status/search filters;
- selected Group filter;
- pending-search + filter single-request behavior;
- pagination/refresh/retry;
- selected-Group `404` reconciliation;
- no reconciliation loop;
- global/filtered/empty-page states;
- stale query response rejection;
- session replacement/logout rejection.

### Widget/responsive

Cover:

- Teacher desktop workspace replaces placeholder;
- desktop wide two-section layout;
- narrow desktop remains usable;
- Teacher mobile single-column layout;
- assigned Group selection updates Topic filter;
- independent Group/Topic loading/error/empty states;
- sign out remains available;
- no Create/Edit/Lifecycle controls in FE-001;
- no horizontal-overflow exception at representative mobile width and increased text scale.

### Direct routing regression

Update existing router test setup as necessary so Teacher cases inject deterministic fake Teacher repositories instead of making real network calls.

Run directly affected regressions for:

```text
frontend/test/features/entry/entry_route_resolver_test.dart
frontend/test/router_bootstrap_test.dart
```

Preserve all existing role/device redirect guarantees.

---

## 19. Verification Scope

Use Flutter SDK:

```text
3.44.7
```

From repository root:

```powershell
Push-Location frontend

fvm spawn 3.44.7 test test/features/teacher

fvm spawn 3.44.7 test `
  test/features/entry/entry_route_resolver_test.dart `
  test/router_bootstrap_test.dart

fvm spawn 3.44.7 analyze

C:\Users\Administrator\fvm\versions\3.44.7\bin\cache\dart-sdk\bin\dart.exe `
  format --output=none --set-exit-if-changed lib test

Pop-Location

git diff --check
```

Then perform a focused final diff self-review for:

```text
task-only scope
no backend changes
no dependency changes
no future FE-002 implementation
exact API paths/query keys
strict DTOs
session/stale safety
desktop/mobile boundary
no unrelated refactor
```

Do **not** run for this task:

```text
full separate frontend regression suite
Windows build
Android build
integration/E2E
backend suite
```

Those broader gates belong to the appropriate Stage checkpoints.

---

## 20. Codex Implementation Report

Return one status:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

The report must contain only:

1. implementation summary;
2. changed files and purpose;
3. exact API/query behavior implemented;
4. desktop/mobile behavior;
5. session/stale-request behavior;
6. tests added/updated;
7. exact focused verification commands and results;
8. `git diff --check` result;
9. focused scope/diff self-review result;
10. deviations, pre-existing failures, unresolved conflicts, or blockers;
11. current Git status needed for Project Owner handoff.

Do not output task `Accepted`.

Do not commit, push, create or merge a PR, or modify task/Stage bookkeeping unless a later explicit instruction assigns that GitHub delivery action to Codex.
