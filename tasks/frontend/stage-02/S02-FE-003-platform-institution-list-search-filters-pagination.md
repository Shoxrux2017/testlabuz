# Codex Task: Platform Institution List — Search, Filters, Sorting, and Pagination

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-FE-003` |
| Status | `Accepted` |
| Approved on | `2026-08-10` |
| Stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Frontend / Platform Owner Institution list read integration` |
| Priority | `High` |
| Depends on | `S02-FE-002` accepted, delivered, and present on current `origin/main`; accepted `S02-BE-001` Institution list API |
| Sequence next | `S02-FE-004` |
| Repository | `https://github.com/Shoxrux2017/testlabuz.git` |
| Target branch | `task/s02-fe-003-institution-list` |
| Execution model | One focused implementation task followed by read-only acceptance and safe GitHub delivery |

---

## 2. Goal

Replace only the honest Institutions placeholder at:

```text
/platform-owner/institutions
```

with a real, read-only, server-driven Institution list backed by:

```text
GET /api/v1/platform/institutions
```

The accepted screen must allow an eligible desktop `platform_owner` to:

- view real Institution summaries returned by the backend;
- search Institution names;
- filter by exact Institution status and type;
- sort by every backend-approved list sort;
- move through server-side result pages;
- choose an approved page size;
- distinguish initial loading, data, global-empty, filtered-empty, request
  failure, and Retry states;
- remain inside the accepted Platform Owner shell with correct navigation,
  current identity, logout, role/device guards, and session isolation.

Every displayed Institution fact must come from the accepted list response.
The client must not fetch users, settings, learning data, or a detail endpoint to
construct the list.

This task implements only the Institution list. It must not implement row
navigation/detail (`S02-FE-004`), creation (`S02-FE-005`), editing
(`S02-FE-006`), lifecycle actions (`S02-FE-007`), or Institution Admin UI
(`S02-FE-008`–`S02-FE-009`).

### Scope boundary

This task owns only:

- typed Institution-summary and pagination transport/domain models;
- typed allowlisted list-query state;
- one Institution-list data-source/repository flow;
- one focused Riverpod-owned list controller/provider boundary;
- the real `/platform-owner/institutions` list body;
- search, `status`, and `type` controls;
- the four accepted sort fields and two directions;
- page navigation and `20`/`50`/`100` page-size choices;
- complete list loading/data/empty/error/Retry presentation;
- request deduplication, stale-completion protection, and session isolation;
- focused unit, controller, widget, route-regression, and responsive-layout
  tests;
- truthful Windows desktop smoke verification against the accepted backend.

It does not:

- add, rename, or redesign Platform Owner routes, shell, or navigation;
- call the Institution detail endpoint;
- make rows clickable or add a selection/detail panel;
- add create/edit/activate/deactivate/Admin actions or disabled future buttons;
- fetch role breakdowns, activity, support, settings, learning, or User records;
- perform local search, filtering, sorting, count aggregation, or pagination;
- implement export, bulk actions, saved views, URL-query persistence, cache,
  polling, refresh timers, offline state, or WebSocket behavior;
- add packages or change backend, schema, Docker, CI, or locked `docs/01–09`.

---

## 3. Current Accepted Context

Treat current `origin/main` at execution time as implementation truth. This
preparation snapshot exists only to make the contract reviewable; Codex must
independently synchronize and inspect the repository.

Verified preparation baseline:

```text
origin/main Stage 1 closure commit:
b6c840a9dc935f6a9b2a87a63e5fc99352782ed8
```

At execution time, current `origin/main` must additionally contain:

- accepted and delivered `S02-BE-001` through `S02-BE-007`;
- accepted and delivered `S02-FE-001` Platform Owner shell/navigation;
- accepted and delivered `S02-FE-002` real Platform dashboard;
- the truthful Stage 2 index state for those completed tasks.

Accepted frontend foundations provide:

- Flutter, Riverpod, GoRouter, Dio, and secure token storage;
- one configured authenticated API client and envelope/failure mapping;
- current `/api/v1/auth/me`-restored session authority;
- global `401` and session invalidation handling;
- first-login password routing and role/device guards;
- canonical Platform Owner routes:
  - `/platform-owner`;
  - `/platform-owner/institutions`;
- one persistent Platform Owner desktop shell with exactly Dashboard and
  Institutions navigation;
- current-user identity, logout, account-switch, and stale-session isolation;
- a real dashboard at `/platform-owner`;
- an honest Institutions placeholder intended for replacement by this task;
- established feature-first `features/platform_admin/` patterns.

Accepted backend `S02-BE-001` provides:

```text
GET /api/v1/platform/institutions
```

with server-side name search, exact status/type filters, allowlisted sorting,
stable ordering, pagination, and basic Institution user counts. The backend is
the authority for role access, validation, query semantics, counts, and result
ordering.

---

## 4. Dependency and Stage-Control Gate

Before implementation, prove from repository evidence:

1. Stage 1 is `Closed` and Stage DoD is `PASS`.
2. `S02-BE-001` through `S02-BE-007` are `Accepted`, reviewed `PASS`, delivered,
   and present on current `origin/main`.
3. `S02-BE-001` exposes the exact Institution list contract defined below and
   its PostgreSQL-backed authorization/query/resource tests pass.
4. `S02-FE-001` is accepted/delivered and owns the exact shell and Institutions
   route.
5. `S02-FE-002` is accepted/delivered and did not implement the Institution
   list or alter the accepted Institutions route boundary.
6. `tasks/STAGE_02_TASK_INDEX.md` matches the approved 17-task decomposition.
7. This detailed task exists exactly at:

   ```text
   tasks/frontend/stage-02/S02-FE-003-platform-institution-list-search-filters-pagination.md
   ```

8. Its status is `Approved`.
9. The accepted API client, session, failure, shell, route, theme, and test
   foundations are present and passing.
10. No conflicting Institution-list implementation already exists.

If any dependency is missing, local `main` differs from `origin/main`, or
current evidence materially contradicts this contract, stop and return:

```text
FINAL STATUS: BLOCKED
```

Do not repair predecessor scope, recreate accepted backend/shell/dashboard
work, or absorb `S02-FE-004+`.

This task may update only the truthful `S02-FE-003` lifecycle state in the
Stage 2 index. It must not create, approve, implement, or state-mutate
`S02-FE-004` or a later task.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

Before editing:

1. Read root `AGENTS.md`, `frontend/AGENTS.md`, and any nearer instruction file
   completely.
2. Read `tasks/README.md`, `tasks/STAGE_02_TASK_INDEX.md`, and this complete
   task.
3. Read accepted `S02-BE-001`, `S02-FE-001`, and `S02-FE-002` contracts and
   delivery evidence.
4. Read only the locked specification sections referenced in Section 12.
5. Inspect the actual Platform Owner shell, Institutions placeholder, router,
   session providers, configured API client, envelope parser, typed failures,
   endpoint/query conventions, theme/widgets, and existing platform-admin
   tests.
6. Run:

   ```text
   git fetch origin
   git switch main
   git pull --ff-only origin main
   git status --short
   git rev-parse HEAD
   git rev-parse origin/main
   git remote -v
   ```

7. Confirm local `main == origin/main`, the remote is the approved repository,
   and the only permitted worktree changes are these two approved preparation
   files:

   ```text
   tasks/frontend/stage-02/S02-FE-003-platform-institution-list-search-filters-pagination.md
   tasks/frontend/stage-02/S02-FE-003-CODEX-PROMPT.md
   ```

   No other modified, staged, deleted, renamed, or untracked path is allowed.
   Neither preparation file may be committed on `main`.
8. Create/switch to exactly:

   ```text
   task/s02-fe-003-institution-list
   ```

9. Carry the two approved files to the task branch if needed and prove
   committed `main` was unchanged.
10. Use the repository-pinned Flutter/Dart toolchain and lockfile.
11. Run relevant pre-existing frontend quality gates before material edits.
12. Do not commit, push, open a PR, merge, or mark accepted before the read-only
    acceptance gate passes.

Unrelated changes are a blocker. Preserve user work and never reset, discard,
overwrite, or destructively clean it.

### 5.2 Route and shell integration

Replace only the Institutions placeholder body already rendered at:

```text
/platform-owner/institutions
```

Requirements:

- preserve the exact route path and route name from `S02-FE-001`;
- render inside the existing Platform Owner shell;
- keep Institutions selected in both compact and wide navigation;
- preserve Dashboard navigation and the real `S02-FE-002` dashboard;
- preserve current identity, logout, shell layout, and route-family guards;
- direct URL entry/refresh must load the same list after normal session restore;
- shell/navigation may remain visible during ordinary feature loading/error
  while the session is valid;
- wrong role, unsupported device, unauthenticated state, inactive state, and
  first-login state must remain blocked/reconciled before usable list data is
  shown.

Do not add a new route, nested detail route, query-string router state, modal
route, second shell, or second navigation framework.

### 5.3 Exact endpoint and query contract

Issue only:

```http
GET /api/v1/platform/institutions
Accept: application/json
Authorization: Bearer <managed by accepted API client>
```

The only permitted query keys are:

```text
search
status
type
page
per_page
sort
direction
```

The frontend must always send the effective values for:

```text
page
per_page
sort
direction
```

It must omit `search`, `status`, and `type` when their effective value is
unset. Never send an empty string, `null`, display label, arbitrary column
name, or unknown key.

Initial canonical request state:

```text
search    = omitted
status    = omitted
type      = omitted
page      = 1
per_page  = 20
sort      = name
direction = asc
```

Example canonical combined request:

```text
GET /api/v1/platform/institutions
    ?search=school
    &status=active
    &type=school
    &page=2
    &per_page=20
    &sort=created_at
    &direction=desc
```

Query-string key ordering is not an API contract, but the key/value set is.
Use the existing client's query encoding. Do not construct a raw URL through
string concatenation.

Never send:

```text
institution_id
created_by_user_id
role
user_id
include_users
include_learning_data
address
description
activity
teacher_count
student_count
```

Do not call the detail, dashboard, Admin, settings, User, reporting, support, or
mutation endpoints to populate the list.

### 5.4 Typed query-state contract

Represent the effective query through one immutable, typed value owned by the
focused Institution-list application boundary.

Required query dimensions:

```text
search: String?              // normalized committed search, max 200
status: InstitutionStatus?  // active | inactive
type: InstitutionType?      // nine accepted values
page: int                   // >= 1
perPage: int                // 20 | 50 | 100 in this UI
sort: InstitutionListSort   // name | created_at | updated_at | status
direction: SortDirection    // asc | desc
```

Rules:

- widgets must not assemble query maps independently;
- enum/display labels must map through an explicit allowlist;
- request state is immutable and equality-comparable using existing project
  conventions;
- every effective search/filter/sort/page-size change resets `page` to `1`;
- Previous/Next changes only `page`;
- no local collection filter, sort, slice, or count may redefine server data;
- controller state and rendered controls must describe the same committed
  query.

#### Search

Search applies only to Institution `name` on the backend.

Frontend behavior:

- maintain an editable field value separately from the committed query value;
- trim surrounding whitespace before committing;
- a trimmed empty value commits `search = null` and omits the query key;
- allow at most 200 characters; while invalid, show safe field feedback and do
  not issue a list request for the invalid value;
- commit after `350 ms` without another edit;
- pressing Enter commits immediately and cancels the pending debounce;
- one committed search value produces at most one request;
- typing/rebuilds must not issue one request per frame/character outside the
  accepted debounce behavior;
- `%`, `_`, apostrophes, Unicode, and spaces are passed as normal encoded text;
  do not implement SQL wildcard escaping or local matching logic in Flutter.

If the accepted project already has a tested shared debounce abstraction, reuse
it. Do not add a package solely for debounce.

#### Status filter

Visible options:

```text
All statuses  → omitted
Active        → active
Inactive      → inactive
```

#### Type filter

Visible options must map to exactly:

```text
All types          → omitted
School             → school
College            → college
Lyceum             → lyceum
University         → university
Institute          → institute
Learning center    → learning_center
Training center    → training_center
Private education  → private_education
Other              → other
```

Labels may follow the accepted capitalization style, but machine values are
fixed and must not be user-generated.

#### Sorting

Expose every accepted sort through sortable table headers or an equally clear
typed control:

```text
name
created_at
updated_at
status
```

Behavior:

- initial sort is `name asc`;
- choosing the currently sorted field toggles `asc ↔ desc`;
- choosing another field starts at `asc`;
- the active field and direction have a visible text/icon indication and
  accessible semantics;
- Type, contact, and User counts are not sortable in this task;
- no raw display label or arbitrary property name reaches the API.

#### Pagination

Use backend pagination metadata. The page-size choices are exactly:

```text
20
50
100
```

Required controls:

- current `page` and `last_page` presentation;
- total matching Institution count;
- Previous;
- Next;
- page-size selector;
- Previous disabled when `page <= 1`;
- Next disabled when `page >= last_page` or the result is empty;
- pagination controls protected against duplicate in-flight activation;
- search/filter/sort controls may still commit a newer query; correctness must
  come from latest-query/stale-completion protection, not from freezing the
  whole toolbar;
- no locally generated page list is authoritative;
- do not infer total from current row count.

If concurrent backend changes make a previously valid page empty, present an
honest empty-page state with a safe route back to page `1` or the previous page.
Do not loop through automatic corrective requests.

One reset action must restore the complete initial canonical query state,
including search, filters, page, page size, sort, and direction.

### 5.5 Exact success response contract

Consume only this accepted `200 OK` shape:

```json
{
  "data": [
    {
      "id": "uuid",
      "name": "Example School",
      "type": "school",
      "status": "active",
      "contact_email": "info@example.uz",
      "contact_phone": "+998...",
      "created_at": "2026-08-07T15:00:00Z",
      "updated_at": "2026-08-07T15:00:00Z",
      "user_counts": {
        "total": 42,
        "active": 40
      }
    }
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 20,
      "total": 1,
      "last_page": 1
    }
  }
}
```

Each typed Institution summary must contain only:

```text
id
name
type
status
contactEmail
contactPhone
createdAt
updatedAt
userCounts.total
userCounts.active
```

Parsing rules:

- `data` must be a list;
- `id` must be a non-empty string suitable as a stable item identity;
- `name` must be a non-empty string;
- `type` must be one of the nine accepted machine values;
- `status` must be `active` or `inactive`;
- `contact_email` and `contact_phone` must be string or JSON `null`;
- timestamps must be valid RFC 3339/ISO 8601 and normalized consistently;
- counts and pagination integers must be real non-negative integers, not
  strings, floats, booleans, or nulls;
- `user_counts.active <= user_counts.total`;
- `page >= 1`, `1 <= per_page <= 100`, `total >= 0`, and `last_page >= 1`;
- missing/wrong core fields produce a safe typed decode failure;
- additive unknown fields are ignored;
- additive protected fields must not enter domain/presentation models, logs,
  diagnostics, search, filters, or widgets;
- widgets receive typed models, never raw JSON/maps.

The client must not require Laravel paginator URLs/links or undocumented fields.
The client must not locally recompute `user_counts`, result order, total, or
`last_page`.

### 5.6 Institution-list presentation contract

The real Institutions destination must contain:

1. A clear `Institutions` page title inside the existing shell.
2. One search field with accessible label/hint.
3. One status filter.
4. One type filter.
5. One Reset action.
6. One real result table/list.
7. Pagination and page-size controls.

Each data row may visibly use only:

```text
name
type
status
contact_email
contact_phone
user_counts.active
user_counts.total
created_at
updated_at
```

Recommended desktop columns:

| Column | Required presentation |
|---|---|
| Institution | Human-readable `name` |
| Type | Human-readable label from accepted machine value |
| Status | Accessible text plus optional non-color-only badge |
| Users | `active / total` with unambiguous label/semantics |
| Contact | Email/phone where present; neutral `Not provided` when both null |
| Created | Existing deterministic date/time format |
| Updated | Existing deterministic date/time format |

Requirements:

- preserve the backend order exactly;
- use the accepted theme/components/spacing rather than a parallel design
  system;
- use `Semantics`, labels, tooltips, focus order, and keyboard behavior where
  current project conventions require;
- status and sort direction must not be communicated by color alone;
- long names/contact values must wrap, truncate with accessible full text, or
  use a safe horizontal table pattern without layout overflow;
- nullable contact fields must never display literal `null`;
- User counts mean persisted Institution users; `active` means
  `users.is_active`, not online/current-session/effective login eligibility;
- do not display UUID, creator, `deactivated_at`, address, description,
  settings, role breakdown, last activity, support state, User identities, or
  learning information;
- do not synthesize teacher/student counts from total User counts;
- rows must not navigate, open a panel, select an Institution, or expose action
  menus in this task;
- do not show Create/Edit/Activate/Deactivate/Admin buttons, including disabled
  placeholders.

At `1440 × 900`, present a clear desktop management table. At `800 × 600`, the
page may compact controls and use an intentional horizontal-scroll/compact
table strategy, but the app itself must not produce uncontrolled render
overflow or change scope/behavior.

### 5.7 Exact view states

The focused state boundary must support:

```text
initial/loading
data
query-change loading
global empty
filtered empty
empty page after concurrent change
error
retry in flight
```

#### Initial/loading

- retain accepted shell/navigation/current identity/logout;
- show an accessible progress/skeleton presentation;
- show no fake/sample rows, counts, previous-account data, or dashboard data;
- one eligible first entry produces one list request.

#### Data

- show only the current response rows and pagination metadata;
- keep controls synchronized with the committed query;
- preserve server ordering and exact count semantics;
- do not append pages into an infinite list.

#### Query-change loading

- commit the new query atomically;
- clear prior rows/pagination from the visible result surface before showing
  results for the new query;
- retain the controls and shell;
- show safe in-context progress;
- ignore/cancel stale earlier completions;
- do not relabel old rows as though they match the new query.

#### Global empty

Classify as global empty only when:

```text
data = []
meta.pagination.total = 0
search = omitted
status = omitted
type = omitted
page = 1
```

Sort and page-size values do not imply a filter. Show a neutral message that no
Institutions are available. Do not show sample data or a Create action; Create
belongs to `S02-FE-005`.

#### Filtered empty

When `data=[]`, `total=0`, and committed search/status/type is active, show a
truthful no-match message and Reset. Preserve the active controls. Do not call
the unfiltered endpoint in the background to guess whether global data exists.

#### Empty page after concurrent change

When the current requested `page > 1` returns no rows, show the returned
pagination facts and one safe way to return to page `1` or Previous. Do not
pretend the whole platform is empty and do not auto-loop requests.

#### Error and Retry

Ordinary transport/server/decode failures show a safe feature error and one
Retry for the exact committed query. Do not display raw exceptions, response
JSON, SQL, URLs, tokens, headers, stack traces, Dio internals, or backend human
messages as decision logic.

Retry requirements:

- one activation creates one request for the same committed query;
- duplicate activation while in flight is prevented/harmless;
- duplicate activations cannot issue the same conflicting request while Retry
  is active; a genuinely newer committed query supersedes the Retry safely;
- success replaces the error with the returned state;
- failure returns to safe error;
- no automatic retry/backoff/polling is added.

### 5.8 Request orchestration and stale-completion safety

Required behavior:

- initial eligible route entry issues one request;
- rebuilds, resizing, focus changes, hover, and shell navigation rebuilds do not
  duplicate it;
- each committed filter/sort/page/page-size change issues one request;
- debounced search issues at most one request for the final committed value;
- exact repeat of the current committed query is a no-op unless explicit Retry
  is used after error;
- rapid changes may cancel an earlier request where current client conventions
  support it, but correctness must not depend on cancellation;
- every request carries/generates an internal generation identity so an older
  completion cannot overwrite a newer query;
- no prefetch of adjacent pages;
- no automatic refresh on timer/window focus/navigation hover;
- no persistence, offline cache, cross-route singleton row cache, or global
  selected Institution is introduced.

### 5.9 Auth, failure, and session reconciliation

Preserve accepted stable behavior:

| Response/failure | Required frontend behavior |
|---|---|
| `401 authentication_required` | Global session invalidation/reconciliation; protected shell/list removed |
| `403 password_change_required` | Mandatory password-change flow |
| `403 user_inactive` | Accepted inactive-account handling; no list data |
| `403 institution_inactive` | Accepted status handling; do not invent a Platform Owner Institution |
| `403 forbidden` | Safe denial; no rows or protected facts |
| `422 validation_failed` | Safe query-contract failure; field details may be mapped only through accepted typed conventions |
| `500 server_error` | Feature error + explicit Retry for valid session |
| Network/timeout/decode failure | Feature error + explicit Retry for valid session |

Rules:

- do not parse human `message` text for control flow;
- do not add endpoint-specific auth/session logic that competes with the
  configured client;
- a Platform Owner list request never uses client-selected Institution scope;
- backend role authorization remains authoritative;
- route visibility/guarding is not a substitute for backend denial;
- safe errors reveal no existence or content of protected records.

### 5.10 Session and account isolation

Required:

- logout/global invalidation clears list rows, pagination, committed query,
  editable search text, pending debounce, and error immediately;
- Platform Owner A data never appears for Platform Owner B;
- Platform Owner data never appears after switching to another role;
- stale Session A request/debounce completion cannot overwrite Session B or a
  logged-out state;
- returning after a new authenticated session starts from the initial canonical
  query, unless the accepted global route contract explicitly defines otherwise;
- the feature does not persist query/data as independent long-term authority;
- no token, role, account ID, or request payload is logged.

Use the accepted session identity/generation boundary rather than comparing
display names or roles alone.

### 5.11 Architecture and code organization

Use the accepted feature-first platform administration area and actual current
patterns. A typical structure is:

```text
frontend/lib/features/platform_admin/
  data/
  domain/
  application/        # or accepted equivalent
  presentation/
```

Keep Institution-list code focused and separate from Dashboard code.

Required boundaries:

```text
configured API client
→ Institution list remote data source
→ repository mapping typed failures/models
→ focused Riverpod controller/provider
→ presentation widgets
```

Rules:

- DTOs parse transport only;
- domain/query models contain typed application data, not raw maps;
- repository/data source owns endpoint and exact query serialization;
- controller owns committed query, debounce, request lifecycle, generation,
  retry, and session-aware state;
- widgets render state and dispatch intents only;
- widgets must not call Dio, parse JSON, inspect tokens, filter/sort rows, or
  calculate backend counts;
- do not grow one god Platform controller/model/file;
- do not duplicate Dashboard transport/controller boundaries unnecessarily;
- reuse accepted enum/date/status/UI utilities where correct;
- create focused names such as `PlatformInstitutionSummary`,
  `PlatformInstitutionListQuery`, `PlatformInstitutionListRepository`, and
  `PlatformInstitutionListController` or project-aligned equivalents;
- use no speculative abstraction for detail/mutations/Admin management;
- add no package and no new router/auth/network framework.

### 5.12 Expected file surface

Inspect accepted paths before choosing final names. Expected areas include:

| Path | Expected action |
|---|---|
| `frontend/lib/features/platform_admin/data/**` | Institution summary/list DTO, remote data source, repository implementation |
| `frontend/lib/features/platform_admin/domain/**` | Typed summary, pagination, query, repository contract where conventions require |
| `frontend/lib/features/platform_admin/application/**` or accepted equivalent | Focused list controller/provider/debounce/generation state |
| `frontend/lib/features/platform_admin/presentation/**` | Replace only Institutions placeholder with toolbar/table/states/pagination |
| `frontend/lib/core/network/**` | Minimal endpoint/query/envelope integration only if accepted conventions require |
| `frontend/test/features/platform_admin/**` | DTO/query/repository/controller/widget/layout tests |
| `frontend/test/app/router/**` | Minimal direct-route/shell regression only if integration changes routing construction |
| `tasks/frontend/stage-02/S02-FE-003-*.md` | Preserve; lifecycle update only after Phase 2 PASS |
| `tasks/STAGE_02_TASK_INDEX.md` | Truthful `S02-FE-003` update only |

Equivalent project-aligned paths are acceptable and must be reported.

Protected paths:

```text
backend/**
docker/**
docs/01–09
frontend/pubspec.yaml
frontend/pubspec.lock
```

Do not modify CI, platform build configuration, dependencies, accepted
Dashboard behavior, Institution detail placeholder/route, or later task files.

---

## 6. Required Automated Tests

Use current conventions and behavior-focused names. Zero executed tests is not
a pass.

### 6.1 DTO and domain mapping

- [ ] Normal multi-row and exact empty responses decode.
- [ ] All nine Institution types and both statuses decode through typed values.
- [ ] Nullable email/phone decode without literal `null` presentation.
- [ ] RFC 3339 created/updated timestamps parse consistently.
- [ ] User counts enforce non-negative integers and `active <= total`.
- [ ] Pagination enforces typed/non-negative/bounded core values.
- [ ] Missing/wrong/null core fields produce typed decode failure.
- [ ] String/floating/boolean numeric values are not silently accepted.
- [ ] Invalid type/status/time produces safe failure.
- [ ] Additive unknown fields are ignored.
- [ ] Protected creator/lifecycle/settings/User/learning fields are absent from
      domain and presentation models.

### 6.2 Typed query and serialization

- [ ] Initial query serializes exactly `page=1`, `per_page=20`, `sort=name`,
      `direction=asc`.
- [ ] Unset search/status/type keys are omitted, not empty/null.
- [ ] Trimmed search serializes through the configured query encoder.
- [ ] Empty trimmed search becomes omitted.
- [ ] Search over 200 characters issues no request and shows safe feedback.
- [ ] Status maps only `active|inactive`.
- [ ] All nine types map to exact machine values.
- [ ] Sort maps only `name|created_at|updated_at|status`.
- [ ] Direction maps only `asc|desc`.
- [ ] Page size maps only `20|50|100` from the UI.
- [ ] No unknown/client-authority/protected key is emitted.
- [ ] Query equality prevents duplicate identical loads.

### 6.3 Data source and repository

- [ ] Exact GET path is used with no body.
- [ ] Existing configured client/envelope boundary is reused.
- [ ] The exact current query map is sent once.
- [ ] Success maps rows and pagination without local filtering/sorting/counting.
- [ ] Backend order is preserved.
- [ ] Stable auth/status/forbidden/validation/server/network/decode failures are
      preserved as typed behavior.
- [ ] Human `message` is not parsed for logic.
- [ ] No detail/dashboard/User/settings/mutation endpoint is called.
- [ ] No auto-retry, polling, cache, or page prefetch occurs.

### 6.4 Controller and request lifecycle

- [ ] Eligible entry begins initial loading and one request.
- [ ] Rebuild/resizing does not duplicate the request.
- [ ] Success produces data with exact committed query.
- [ ] A filter/type/sort/page-size change resets page to `1` and requests once.
- [ ] Previous/Next changes only page and requests once.
- [ ] Search commits after 350 ms and rapid typing does not request every value.
- [ ] Enter commits immediately without a later duplicate debounce request.
- [ ] Identical committed query is a no-op.
- [ ] Query change clears mismatched old rows and shows progress.
- [ ] Older request completion cannot overwrite a newer query.
- [ ] Error retains the committed query and exposes Retry.
- [ ] Retry issues one request; duplicate in-flight Retry is prevented.
- [ ] Logout/invalidation clears rows/query/debounce/error immediately.
- [ ] Session A completion cannot populate Session B/logged-out state.

### 6.5 Widget states, controls, and layout

- [ ] Shell/navigation/identity/logout remain visible for valid-session
      loading/error.
- [ ] Institutions remains selected on direct entry and refresh.
- [ ] Initial loading shows no fake/old rows or counts.
- [ ] Data rows expose only approved visible fields.
- [ ] Backend order and exact User count values are preserved.
- [ ] Status and sort direction have accessible non-color-only meaning.
- [ ] All status/type/sort/page-size options map correctly.
- [ ] Global empty is distinct from filtered empty.
- [ ] Filtered empty preserves active controls and Reset.
- [ ] Empty page after concurrent change is not labeled global empty.
- [ ] Safe error hides internals and Retry works.
- [ ] Pagination uses backend `page`, `last_page`, and `total`.
- [ ] Previous/Next disabled states are correct.
- [ ] Reset restores the complete initial canonical query.
- [ ] Long/null Institution/contact values are safely rendered.
- [ ] No UUID/protected field/fake role count/action menu is visible.
- [ ] Rows are not clickable and expose no detail/create/edit/lifecycle/Admin
      behavior.
- [ ] No overflow at `800 × 600` and `1440 × 900`.
- [ ] Keyboard/focus/semantics behavior follows accepted desktop conventions.

### 6.6 Session, route, and regression

- [ ] `401` invalidation removes protected shell/list data.
- [ ] Password/status/forbidden failures never render rows.
- [ ] Platform Owner A → B leaks no old rows/query state.
- [ ] Platform Owner → another role leaks no list/shell state.
- [ ] Stale request/debounce cannot repopulate after logout/session switch.
- [ ] Unauthenticated, first-login, wrong-role, mobile, web, and unsupported
      route behavior remains as accepted in `S02-FE-001`.
- [ ] Real Dashboard remains correct and does not refetch because list controls
      change.
- [ ] No Institution detail route/panel/action is introduced.
- [ ] Full accepted frontend regression remains green.

---

## 7. Quality and Verification Commands

From `frontend/`, use repository-pinned commands/wrappers and report exact
results:

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
flutter build windows --debug
flutter build apk --debug
```

Run focused tests first, then the full suite. Do not silently skip either build.

Before Phase 2, from repository root run:

```text
git status --short
git diff --check
git diff --stat
git diff
git diff --cached --check
git diff --cached --stat
git diff --cached
git ls-files --others --exclude-standard
git status --short -- backend docker docs frontend/pubspec.yaml frontend/pubspec.lock
git diff HEAD -- backend docker docs frontend/pubspec.yaml frontend/pubspec.lock
git diff --cached -- backend docker docs frontend/pubspec.yaml frontend/pubspec.lock
```

Open every untracked implementation file. Inspect the complete staged,
unstaged, and untracked set for:

- secrets, credentials, tokens, `.env` content, or private URLs;
- raw Dio/JSON/maps in widgets;
- duplicate API client, auth, session, router, or error boundaries;
- arbitrary query keys/sort names or client-selected authority;
- local filtering/sorting/pagination/count recomputation;
- request storms, duplicate requests, stale-completion races;
- polling, cache, prefetch, persistence, cross-account state;
- protected-data leakage, fake rows/counts, role breakdown invention;
- detail/mutation/Admin/later-task scope;
- dependency/package/generated/lockfile drift;
- unrelated refactors or protected-path changes.

---

## 8. Manual Smoke Checklist

Use the real Windows app, accepted Laravel/PostgreSQL runtime, and controlled
local/test data. Redact credentials/tokens.

### Real list/query behavior

1. Prepare more than 20 Institutions with mixed names, all nine types, both
   statuses, nullable contacts, controlled timestamps, equal primary sort
   values, and mixed active/inactive User counts.
2. Login as an active, password-complete Platform Owner on Windows desktop.
3. Open `/platform-owner/institutions` directly and through shell navigation.
4. Verify one initial request with canonical query values.
5. Compare visible rows/order/counts/pagination against the real response.
6. Search by mixed case, surrounding whitespace, `%`, and `_` values; confirm
   server results and no request storm.
7. Apply each status filter and all type values.
8. Combine search + status + type.
9. Exercise all four sorts in both directions.
10. Navigate Previous/Next and switch `20`/`50`/`100` page size.
11. Confirm every effective non-page change resets to page `1`.
12. Confirm Reset restores the canonical initial query.
13. Verify null/long contact values, readable dates, accessible status/sort,
    and compact/wide layout.
14. Confirm rows expose no navigation or future actions.

### Empty, failure, and isolation

1. Verify global empty with controlled zero Institutions where safely possible.
2. Verify filtered empty using a guaranteed no-match query.
3. Safely make the endpoint fail without production-code test hooks.
4. Confirm safe error and absence of raw internals/old rows.
5. Restore backend, Retry once, and confirm one successful request for the same
   committed query.
6. Change query rapidly under controlled latency and confirm stale responses do
   not overwrite the latest query.
7. Verify invalid-token reconciliation removes protected data.
8. Logout while loading/after data and confirm immediate removal.
9. Login as another Platform Owner and then another role; confirm no old
   rows/query/error state appears.
10. Confirm the Dashboard remains intact and list activity does not create
    dashboard requests.

Report every unavailable manual item as `NOT RUN` with exact reason. Never
claim a simulated/widget-only check as real-stack smoke.

---

## 9. Acceptance Criteria

- [ ] Dependency/Git gate is proven.
- [ ] Work occurs only on `task/s02-fe-003-institution-list`.
- [ ] The accepted `/platform-owner/institutions` placeholder is replaced by
      the real list inside the existing shell.
- [ ] Only `GET /api/v1/platform/institutions` is used.
- [ ] Query keys/values/defaults/omissions match the accepted backend contract.
- [ ] Search, both filters, all sorts/directions, and page controls work through
      server-side requests.
- [ ] No local search/filter/sort/pagination/count authority exists.
- [ ] Typed DTO/domain/query/repository/controller boundaries follow accepted
      architecture.
- [ ] Rows and pagination consume only approved response fields.
- [ ] Request deduplication, debounce, stale completion, Retry, and session
      isolation are proven.
- [ ] Initial loading, data, global empty, filtered empty, empty page, error,
      and Retry states are tested.
- [ ] Auth/password/status/role/device/session behavior remains accepted.
- [ ] No protected/fake/detail/mutation/Admin/later-task behavior exists.
- [ ] Dashboard, shell, navigation, identity, and logout regressions remain
      green.
- [ ] No backend/docs/Docker/schema/dependency/CI change exists.
- [ ] Focused/full tests, analyze, format, Windows build, and APK build pass.
- [ ] Manual smoke is truthful and secrets are redacted.
- [ ] Phase 2 has zero unresolved P1/P2 findings.
- [ ] Final `ACCEPTED` occurs only after PR delivery, merge, and clean sync.

---

## 10. Explicit Non-Goals

- Institution detail/basic usage or row navigation (`S02-FE-004`).
- Create Institution form/mutation (`S02-FE-005`).
- Edit Institution form/mutation (`S02-FE-006`).
- Activate/deactivate UI (`S02-FE-007`).
- Institution Admin list/create (`S02-FE-008`).
- Institution Admin edit/lifecycle (`S02-FE-009`).
- Stage 2 full real-stack verification (`S02-INT-001`).
- New Platform Owner routes/navigation/shell redesign.
- Address/description/detail presentation.
- Teacher/student/role counts, User identities, last activity, support state.
- Settings, reports, learning data, files, submissions, scores, results.
- Create/Edit/Lifecycle/Admin buttons, menus, dialogs, panels, or placeholders.
- Row selection, detail drawer, deep link, selected Institution context.
- Client-side data manipulation that redefines backend results.
- Export, bulk action, saved view, column customization, URL query persistence.
- Polling, cache, offline, page prefetch, infinite scroll, WebSocket/background
  refresh.
- Localization/design-system overhaul.
- New packages or backend/schema/Docker/CI/locked-doc changes.

---

## 11. Relevant Business and Security Rules

1. Only an active, password-complete desktop `platform_owner` uses the screen.
2. Backend authorization remains authoritative.
3. Client sends only allowlisted presentation query values, never role or
   Institution ownership authority.
4. Platform Owner list access does not authorize daily learning or User-record
   access.
5. Search/filter/sort/pagination never expand protected scope.
6. Server owns search behavior, filter validation, ordering, totals, and pages.
7. `user_counts.active` means persisted `users.is_active`, not online/login
   activity or effective eligibility.
8. Platform Owner accounts are not part of Institution User counts.
9. No role breakdown may be inferred from total/active counts.
10. List rows omit address, description, settings, creator, lifecycle metadata,
    identities, and learning data.
11. Stable typed errors, not human messages, drive behavior.
12. Session change invalidates query/data/request presentation state.
13. The request is read-only and must create no server mutation/timestamp
    change.
14. Detail and every mutation remain separate approved tasks.

---

## 12. Authoritative References

| Source | Exact section | Requirement |
|---|---|---|
| `docs/01-business-overview.md` | Platform Owner, multi-Institution, device, isolation, and focused MVP overview | Platform Institution management without daily learning interference |
| `docs/02-user-roles.md` | `1. Platform Owner / Super Admin`; access/device rules | List/status/basic User-count authority and desktop-only boundary |
| `docs/03-features.md` | `2. Platform Owner / Super Admin Features` | View all Institutions with basic name/type/status/User information and management-table UX |
| `docs/04-user-flows.md` | `2. Platform Owner / Super Admin Flow`; `Institution Management Flow` | Open list, search/filter, then separately open details/actions |
| `docs/05-business-rules.md` | `BR-INST-001`–`021`; `BR-ROLE-004`–`009`; `BR-ACL-001`–`005`, `014`–`016` | Institution separation, platform authority, lifecycle meaning, scope/security |
| `docs/06-roadmap.md` | `2.6`; `7. Stage 2`; `Institution Management`; boundary/tests | Desktop list/search/filter and protected-data exclusions |
| `docs/07-architecture.md` | `20`, `21`, `22.1`, `23.5`, `29`, `32.4`–`32.6`, `35` | Flutter layers, route/shell, pagination, errors, tests, security |
| `docs/09-api-contracts.md` | `2`, `4`, `5`, `6`, `7.2`, `33` | Envelope, session, errors, pagination/search/filter/sort, exact endpoint/query |
| `AGENTS.md` and `frontend/AGENTS.md` | Applicable full rules | Workflow, typed layers/states, tests, safe delivery |
| accepted `S02-BE-001` | Complete contract/evidence | Exact request, response, enums, counts, ordering, PostgreSQL behavior |
| accepted `S02-FE-001` | Complete contract/evidence | Route, shell, navigation, guards, logout, isolation |
| accepted `S02-FE-002` | Complete contract/evidence | Current platform-admin architecture, API/session/failure patterns, real Dashboard boundary |
| `tasks/STAGE_02_TASK_INDEX.md` | `S02-FE-003` and successors | Exact sequence and non-goals |

Task-level query defaults, UI options, debounce, empty-state classification,
request-count, and stale-completion details narrow implementation ambiguity
without changing locked backend/product behavior.

---

## 13. Stop Conditions

Stop with `FINAL STATUS: BLOCKED` if:

- Stage 1 or required Stage 2 predecessors are not accepted/delivered;
- `S02-BE-001` endpoint/query/response differs materially;
- `S02-FE-001` route/shell or `S02-FE-002` architecture is absent/conflicting;
- Stage 2 index is missing/conflicting;
- local `main` cannot synchronize or `origin` is unexpected;
- unrelated dirty work exists;
- accepted client/session/failure/test foundations are missing/broken;
- locked docs conflict;
- implementation requires protected paths, a package, broad auth/network/router
  redesign, or later-task scope;
- safe typed parsing, request deduplication, stale-completion safety, or account
  isolation cannot be preserved;
- a required pre-existing frontend quality gate fails materially;
- safe work requires destructive Git, force-push, bypass, secret exposure, or
  user-work overwrite.

During Phase 2, unresolved P1/P2 means:

```text
FINAL STATUS: NOT ACCEPTED
```

If Phase 2 passes but delivery cannot finish:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Do not start `S02-FE-004`.

---

## 14. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git preflight

Complete Section 5.1, create/switch to the exact task branch, carry the two
approved files, and do not commit/push.

### Phase 1 — Implementation

Implement only `S02-FE-003`. Run focused/full tests, analyze, format, builds,
diff/scope/security review, and manual smoke. Do not commit, push, open a PR,
merge, or mark accepted.

### Phase 2 — Read-only acceptance gate

Re-read this task, instructions, referenced locked sections, predecessors, the
complete staged/unstaged/untracked change set, tests/builds/smoke, exact query
and request-count evidence, all view states, error behavior, and session/data
isolation.

During Phase 2 make no edits; do not auto-fix, format-write, generate, stage,
unstage, commit, push, open/merge a PR, or update lifecycle state.

Severity:

```text
P1 = auth/role/device/session/account-isolation/secret/protected-data issue
P2 = material API/query/state/UI/architecture/test/build/scope/contract issue
P3 = non-blocking observation
```

PASS requires zero unresolved P1/P2 and complete trustworthy evidence.
Otherwise return `FINAL STATUS: NOT ACCEPTED`, stop, and do not self-fix after
Phase 2 begins.

### Phase 3 — Post-acceptance delivery

Only after Phase 2 PASS:

1. Set this detailed task to `Accepted`.
2. Update only truthful `S02-FE-003` index state to Accepted/review PASS;
   delivery finalizes only after merge.
3. Apply only required task lifecycle bookkeeping.
4. Re-run final tests, builds, diff/scope/package/secret checks.
5. Stage only approved implementation, tests, task, prompt, and truthful index
   files.
6. Commit:

   ```text
   feat(platform): add institution list view
   ```

   Body:

   ```text
   Task: S02-FE-003
   ```

7. Push `task/s02-fe-003-institution-list` to the approved origin.
8. Open a PR to `main`; do not bypass checks/protection.
9. Merge only when safe and green.
10. Fast-forward-sync local `main` and prove clean `main == origin/main`.

Only then return:

```text
FINAL STATUS: ACCEPTED
```

Do not create or start `S02-FE-004`.

---

## 15. Required Codex Final Report

Return:

1. Final status and dependency/Git commit evidence.
2. Implementation/changed-file summary and exact endpoint evidence.
3. Exact query defaults, mappings, omissions, reset, and serialization evidence.
4. Typed DTO/domain/repository/controller architecture evidence.
5. Search debounce, request count, deduplication, Retry, and stale-completion
   evidence.
6. All view-state, table, pagination, responsive, and accessibility evidence.
7. Auth/status/session/account-switch/isolation evidence.
8. Protected-data/no-fake/no-detail/no-mutation/no-later-scope evidence.
9. Focused/full tests, analyze, format, Windows/APK builds.
10. Diff/scope/package/secret/untracked checks.
11. Manual smoke and exact `NOT RUN` items.
12. Phase 2 findings/decision.
13. Commit/branch/PR/merge/final-sync evidence.
14. Remaining blockers/deviations.

Do not create or start `S02-FE-004`.
