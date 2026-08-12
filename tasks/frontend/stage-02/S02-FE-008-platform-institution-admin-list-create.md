# Codex Task: Platform Institution Admin List and Create UI

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-FE-008` |
| Status | `Accepted` |
| Approved on | `2026-08-10` |
| Stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Frontend / Platform Owner Institution Admin management` |
| Priority | `High` |
| Depends on | `S02-FE-007` accepted, delivered, and present on current `origin/main`; accepted `S02-BE-006` Institution Admin list/create API |
| Sequence next | `S02-FE-009` |
| Repository | `https://github.com/Shoxrux2017/testlabuz.git` |
| Target branch | `task/s02-fe-008-institution-admin-list-create` |
| Review status | `PASS` |
| Delivery status | `Delivered` |
| Accepted commit | `86fd616eab3a55e7d38116b203d67f80881cea69` |
| Main before S02-FE-008 | `72fe5b2705bb4f7c69bc4ddbaa3f349174bbe8fa` |
| Pull request | `#36` |
| Merge commit | `37a154d2d40d408df86b9b39263289cbe082187c` |
| Manual live smoke | `NOT RUN - no running backend or Platform Owner credentials were available` |
| Execution model | One focused implementation task followed by read-only acceptance and safe GitHub delivery |

---

## 2. Goal

Extend the accepted Platform Owner Institution detail experience with a real,
path-scoped Institution Admin list and a safe create flow backed only by:

```text
GET  /api/v1/platform/institutions/{institution}/admins
POST /api/v1/platform/institutions/{institution}/admins
```

The accepted result must let an eligible desktop `platform_owner`:

- view only the Institution Admin accounts belonging to the currently opened
  Institution;
- search, filter, sort, and paginate the list through backend-authoritative
  query parameters;
- understand account active state, mandatory-first-login state, and last-login
  information without exposing credentials or private model data;
- open one accessible create dialog inside the Institution detail context;
- submit exactly the five approved fields once per explicit gesture;
- create an active `institution_admin` account whose Institution, role,
  creator, UUID, lifecycle state, and first-login flag are set by Laravel;
- handle validation, definite failure, and uncertain mutation outcomes without
  duplicate creation or false success;
- refresh visible server facts after confirmed creation and invalidate only
  current-session dependent data;
- preserve the accepted Platform Owner shell, Institution dashboard/list/
  detail/create/edit/lifecycle flows, logout, guards, and session isolation.

The backend remains authoritative for authorization, Institution binding,
role, uniqueness, hashing, active state, first-login enforcement, persistence,
pagination, and public serialization. The frontend must not derive those facts
from route visibility, locally mutate list/count data, or send protected
fields.

This task implements only Institution Admin list/create UI. It must not
implement Institution Admin update/activate/deactivate (`S02-FE-009`) or the
Stage-wide real-stack closure (`S02-INT-001`).

### Scope boundary

This task owns only:

- one Institution Admin section inside the accepted detail route:

  ```text
  /platform-owner/institutions/:institutionId
  ```

- typed GET query state for `search`, `status`, `page`, `per_page`, `sort`, and
  `direction`;
- server-side list loading, filtering, sorting, pagination, and safe states;
- explicit typed mapping of the approved Institution Admin public resource;
- an accessible create dialog with `full_name`, `login_name`, `email`, `phone`,
  and `password`;
- exact POST mapping, in-flight duplicate protection, validation mapping, and
  safe secret handling;
- confirmed-success refresh/invalidation and uncertain-outcome reconciliation;
- focused data/application/presentation/regression/accessibility tests;
- truthful Windows desktop smoke verification against the accepted backend.

It does not:

- add a new route, sidebar item, Institution Admin detail page, drawer, or
  global selected-Admin state;
- add row actions, edit, activate, deactivate, reset password, reveal password,
  resend password, impersonate, delete, or replace an admin;
- create Teacher, Student, Parent, or Platform Owner accounts;
- send `institution_id`, role, active state, first-login state, creator,
  timestamps, or any other server-owned field;
- distribute credentials through email, SMS, notification, print, clipboard,
  export, or a server-generated password;
- add bulk import/export, invites, self-registration, permissions, custom
  roles, audit/support workflows, or learning-data access;
- change backend, database, Docker, CI, packages, lockfiles, or locked
  `docs/01–09`;
- implement `S02-FE-009+`.

---

## 3. Current Accepted Context

Treat current `origin/main` at execution time as implementation truth. This
preparation snapshot exists only to make the contract reviewable.

Verified preparation baseline:

```text
origin/main Stage 1 closure commit:
b6c840a9dc935f6a9b2a87a63e5fc99352782ed8
```

At execution time, current `origin/main` must additionally contain:

- accepted and delivered `S02-BE-001` through `S02-BE-007`;
- accepted and delivered `S02-FE-001` through `S02-FE-007`;
- truthful Stage 2 index state for those completed tasks.

Accepted frontend foundations provide:

- Flutter, Riverpod, GoRouter, Dio, and secure token storage;
- one configured authenticated API client and typed envelope/failure mapping;
- `/api/v1/auth/me`-restored session authority;
- global authentication, inactive-account, inactive-Institution,
  first-login, role, and device reconciliation;
- desktop Platform Owner shell with Dashboard and Institutions navigation;
- real Platform dashboard and Institution list/detail/create/edit/lifecycle;
- typed Institution/status/type models, route-scoped detail state, and
  feature-first `features/platform_admin/` organization;
- accepted query debouncing, request generation, in-flight de-duplication,
  provider invalidation, dialogs, feedback, form, and session-isolation
  patterns.

Accepted backend `S02-BE-006` provides:

```text
GET  /api/v1/platform/institutions/{institution}/admins
POST /api/v1/platform/institutions/{institution}/admins
```

It guarantees:

- Platform Owner middleware authorization and path-owned Institution scope;
- GET rows constrained by both path Institution and
  `role = institution_admin` before filtering/pagination;
- exact query allowlists/defaults, deterministic ordering, and pagination;
- an explicit safe Institution Admin resource;
- POST validation for exactly five client fields;
- backend-derived Institution, role, creator, active state, and
  `must_change_password = true`;
- securely hashed password that never appears in response or logs;
- global `login_name` uniqueness, including a field-level `422` for a
  recognized concurrent uniqueness loser;
- exact `201` success and accepted first-login enforcement.

Accepted backend `S02-BE-007` owns later update/lifecycle endpoints. Their
existence does not authorize implementing their UI in this task.

---

## 4. Dependency and Stage-Control Gate

Before implementation, prove from repository evidence:

1. Stage 1 is `Closed` and Stage DoD is `PASS`.
2. `S02-BE-001` through `S02-BE-007` are `Accepted`, reviewed `PASS`,
   delivered, and present on current `origin/main`.
3. `S02-BE-006` exposes the exact GET/POST, query/resource/create/error/
   first-login contracts and PostgreSQL-backed tests required here.
4. `S02-FE-001` through `S02-FE-007` are accepted and delivered, including the
   Institution detail route and current-session invalidation patterns.
5. `tasks/STAGE_02_TASK_INDEX.md` matches the approved 17-task decomposition.
6. This detailed task exists exactly at:

   ```text
   tasks/frontend/stage-02/S02-FE-008-platform-institution-admin-list-create.md
   ```

7. Its status is `Approved`.
8. No conflicting Institution Admin list/create UI already exists.

If a dependency is missing, local `main` differs from `origin/main`, or current
evidence materially contradicts this contract, stop and return:

```text
FINAL STATUS: BLOCKED
```

Do not repair predecessor scope, recreate backend behavior, or absorb
`S02-FE-009+`.

This task may update only truthful `S02-FE-008` lifecycle state in the Stage 2
index. It must not create, approve, implement, or state-mutate a later task.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

Before editing:

1. Read root `AGENTS.md`, `frontend/AGENTS.md`, and any nearer instruction file
   completely.
2. Read `tasks/README.md`, `tasks/STAGE_02_TASK_INDEX.md`, and this task.
3. Read accepted `S02-BE-006`, `S02-FE-003` through `S02-FE-007`, and relevant
   shared Stage 1 contracts/delivery evidence.
4. Read only the locked specification sections referenced in Section 12.
5. Inspect the actual Platform Owner shell/router, Institution detail,
   dashboard/list providers, API client, endpoint registry, envelope/failure
   mapping, DTO/domain conventions, session generation, forms/dialogs,
   responsive tables/cards, feedback, and tests.
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

7. Confirm local `main == origin/main`, the remote is approved, and the only
   permitted worktree changes are exactly these two approved preparation files:

   ```text
   tasks/frontend/stage-02/S02-FE-008-platform-institution-admin-list-create.md
   tasks/frontend/stage-02/S02-FE-008-CODEX-PROMPT.md
   ```

   No other modified, staged, deleted, renamed, or untracked path is allowed.
   Neither preparation file may be committed on `main`.
8. Create/switch to exactly:

   ```text
   task/s02-fe-008-institution-admin-list-create
   ```

9. Carry the two approved files to the task branch if needed and prove
   committed `main` was not changed.
10. Use the repository-pinned Flutter/Dart toolchain and lockfile.
11. Run relevant pre-existing frontend gates before material edits.
12. Do not commit, push, open a PR, merge, or mark accepted before Phase 2
    read-only acceptance passes.

Unrelated changes are a blocker. Preserve user work and never reset, discard,
overwrite, or destructively clean it.

### 5.2 Institution-detail placement and request ownership

Extend only the accepted route:

```text
/platform-owner/institutions/:institutionId
```

Requirements:

- add a clearly titled `Institution administrators` section after successful
  Institution detail loading;
- keep the existing basic information, usage, edit, lifecycle, back action,
  shell, navigation selection, logout, and guards intact;
- add no route, route query parameter, navigation destination, second shell,
  drawer, or modal route;
- derive the target Institution only from the current `institutionId` route
  segment and the accepted route-scoped detail context;
- do not send a list/create request until the current Institution detail has
  loaded successfully; detail `404`/error/guard states must not probe the Admin
  endpoints;
- a route change from Institution A to B clears A's Admin rows, query, form,
  errors, pending requests, and feedback before B data is usable;
- direct URL entry restores the session, loads the Institution detail, then
  loads that Institution's Admin list;
- Institution status does not hide the section or disable creation: an
  inactive Institution remains manageable by Platform Owner, but the UI must
  explain that its users cannot use normal Institution access until the
  Institution is reactivated;
- wrong role, unsupported device, unauthenticated, inactive-account, and
  first-login states remain blocked/reconciled before Admin facts or controls
  appear.

The section owns its own list query/mutation state keyed by session generation
and current `institutionId`. It must not become a global selected-Institution
or selected-Admin authority.

### 5.3 Exact list endpoint and query contract

Issue only:

```http
GET /api/v1/platform/institutions/{institutionId}/admins
Accept: application/json
Authorization: Bearer <managed by accepted API client>
```

Allowed query keys:

```text
search
status
page
per_page
sort
direction
```

Always send the effective values for:

```text
page
per_page
sort
direction
```

Omit `search` and `status` when unset. Never send empty string, `null`, display
label, raw property/column name, or an unknown key.

Initial canonical query:

```text
search    = omitted
status    = omitted
page      = 1
per_page  = 20
sort      = full_name
direction = asc
```

Example:

```text
GET /api/v1/platform/institutions/{institutionId}/admins
    ?search=admin
    &status=active
    &page=2
    &per_page=20
    &sort=created_at
    &direction=desc
```

Use the configured client and query encoder. Never construct raw URLs through
string concatenation. Never send:

```text
institution_id
role
user_id
must_change_password
created_by_user_id
include
expand
permissions
password
```

Do not call dashboard, general User, settings, reports, learning, update,
activate, deactivate, or password endpoints to populate the list.

### 5.4 Typed Admin-list query state

Use one immutable typed query value:

```text
search: String?                    // normalized committed search, max 254
status: InstitutionAdminStatus?  // active | inactive
page: int                          // >= 1
perPage: int                       // 20 | 50 | 100 in this UI
sort: InstitutionAdminListSort    // full_name | login_name | created_at | updated_at
direction: SortDirection           // asc | desc
```

Rules:

- widgets do not independently assemble query maps;
- display labels map through explicit enum allowlists;
- every effective search/status/sort/page-size change resets `page` to `1`;
- Previous/Next changes only `page`;
- no local filter, sort, slice, count, or merge may redefine server data;
- visible controls and committed query state must agree;
- exact repeat of the current query is a no-op except explicit Retry/Refresh.

#### Search

- searches backend-approved `full_name`, `login_name`, `email`, and `phone`;
- editable text is separate from committed search;
- trim outer whitespace before commit;
- trimmed empty commits `null` and omits the key;
- maximum is 254 characters; invalid input shows field feedback and sends no
  request;
- commit after `350 ms` without another edit;
- Enter commits immediately and cancels pending debounce;
- `%`, `_`, apostrophes, Unicode, and spaces are passed as normal encoded text;
  Flutter does not implement SQL/wildcard logic;
- one committed value produces at most one logical request.

#### Status

Visible mapping:

```text
All statuses → omitted
Active       → active
Inactive     → inactive
```

#### Sorting

Expose all four accepted sorts through typed controls or sortable fields:

```text
Full name  → full_name
Login name → login_name
Created    → created_at
Updated    → updated_at
```

Initial order is `full_name asc`. Selecting the current sort toggles
`asc ↔ desc`; selecting another starts at `asc`. Active sort/direction must be
visible and accessible. Contact, status, first-login, and last-login columns
are not sortable.

#### Pagination

Use only response pagination metadata. Page-size choices are exactly:

```text
20
50
100
```

Show current page, last page, total matching Admin count, Previous, Next, and
page-size selector. Disable Previous at page 1 and Next at/after last page or
for an empty result. Prevent duplicate page activation while its exact request
is in flight. Do not prefetch, infinite-scroll, or infer totals from row count.

One Reset action restores the complete initial canonical Admin query.

### 5.5 Exact list response and typed public resource

Consume only the accepted `200 OK` shape:

```json
{
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "full_name": "Institution Admin",
      "login_name": "admin.school1",
      "email": null,
      "phone": "+998...",
      "is_active": true,
      "must_change_password": true,
      "last_login_at": null,
      "deactivated_at": null,
      "created_at": "2026-08-10T10:00:00Z",
      "updated_at": "2026-08-10T10:00:00Z"
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

The typed public model may contain exactly:

```text
id
fullName
loginName
email
phone
isActive
mustChangePassword
lastLoginAt
deactivatedAt
createdAt
updatedAt
```

Parsing rules:

- `data` is a list;
- `id`, `full_name`, and `login_name` are non-empty strings;
- `email` and `phone` are string or JSON `null`;
- `is_active` and `must_change_password` are real JSON booleans;
- `last_login_at` and `deactivated_at` are valid RFC3339 timestamps or null;
- `created_at` and `updated_at` are required valid RFC3339 timestamps;
- pagination integers are real integers with `page >= 1`,
  `1 <= per_page <= 100`, `total >= 0`, and `last_page >= 1`;
- missing/null/wrong-type/invalid-time core data is a safe typed contract
  failure; do not partially render;
- additive unknown fields may be ignored but must not enter domain,
  presentation, logs, diagnostics, search, or filters;
- raw JSON/maps never reach widgets.

Never model or expose password/hash, tokens, remember token, role,
`institution_id`, creator data, permissions, Institution settings, or learning
data even if a drifting response includes them.

### 5.6 List presentation and exact view states

The section header contains:

- `Institution administrators`;
- a truthful count only when returned pagination is valid;
- search/status/sort/page-size controls;
- one keyboard-accessible `Create administrator` action.

Wide desktop presentation may use a table. At compact desktop widths, use a
responsive card/list treatment rather than causing page-level horizontal
overflow. Show these readable facts:

```text
Full name
Login name
Email
Phone
Account status
Password change required/completed
Last login
Created at
```

Rules:

- active/inactive and password-change meaning are text-accessible, not
  color-only;
- null email/phone/last-login use one honest placeholder such as
  `Not provided` / `Never`;
- timestamps use the accepted instant formatter and do not claim Institution
  timezone;
- long text wraps/truncates accessibly without leaking or executing markup;
- rows/cards contain no action menu, edit, activate, deactivate, reset,
  reveal, copy-password, impersonate, or delete affordance;
- server order is preserved; no local optimistic row insertion.

Required states:

```text
waiting for Institution detail
initial loading
data
query-change loading
global empty
filtered empty
empty page after concurrent change
ordinary error
retry in flight
```

State rules:

- list loading keeps the confirmed Institution detail and shell visible;
- no sample/fake rows, zero facts, or prior-session data appear;
- query-change loading clears old rows/pagination from the result surface while
  retaining controls and detail context;
- global empty requires `data=[]`, `total=0`, no search/status, and page 1;
  show a neutral message plus the task-owned Create action;
- filtered empty shows no-match, active controls, Reset, and the header Create
  action without claiming the Institution has no admins globally;
- page > 1 with no rows shows truthful pagination and one safe way to page 1
  or Previous, without automatic request loops;
- ordinary network/server/decode error shows safe error and one GET-only Retry
  for the exact current query;
- Retry is in-flight protected, does not duplicate, and never exposes raw URL,
  token, headers, JSON, stack, SQL, Dio internals, or backend internals.

Request orchestration must cancel where supported and always ignore stale
completions by session generation, route Institution, and query generation.
Rebuild, resize, focus, hover, or unrelated detail refresh must not duplicate
the Admin GET.

### 5.7 Create dialog, fields, and client validation

`Create administrator` opens one accessible modal dialog/surface in the
current Institution detail context. It is not a route.

Render exactly:

```text
Full name *
Login name *
Email
Phone
Initial password *
```

Field contract:

| UI field | Request key | Required behavior |
|---|---|---|
| Full name | `full_name` | Required, trimmed non-empty string, max 200 |
| Login name | `login_name` | Required, trimmed non-empty string, max 191; backend owns global uniqueness |
| Email | `email` | Optional valid email, max 254 |
| Phone | `phone` | Optional trimmed non-empty when present, max 50; no invented E.164-only rule |
| Initial password | `password` | Required string, min 8, max 255; no invented composition rule |

Dialog requirements:

- title clearly names the current Institution using safely rendered text;
- explain that the account is created active and must change its password at
  first login;
- for an inactive Institution, additionally explain that Institution status
  still blocks normal login/access until reactivation;
- password is obscured by default; an accessible show/hide toggle may reveal
  only while the user explicitly chooses it and must not copy/log/persist it;
- use real labels, required semantics, focus order, keyboard operation, error
  associations, and initial focus on the first field;
- Cancel/Escape/dismiss sends no request and clears all form/secret state;
- one dialog and one mutation at a time;
- no password confirmation field because the accepted API does not define it;
- no hidden/default role, Institution, status, first-login, creator, ID,
  timestamps, permissions, or lifecycle fields;
- no username availability request, duplicate-contact check, or preliminary
  list request.

Client validation improves feedback but does not replace backend authority.
Trim outer whitespace for full/login/contact values; submit empty optional
contact as JSON `null`; preserve meaningful internal Unicode text. Do not
lowercase, transliterate, title-case, or otherwise rewrite `login_name`.

Map backend `422` only for approved keys:

```text
full_name
login_name
email
phone
password
```

Unknown/global validation entries use one safe form-level area. Editing a
field clears only that field's stale server error. Validation response details
must never echo the password.

### 5.8 Exact create request

Issue only:

```http
POST /api/v1/platform/institutions/{institutionId}/admins
Accept: application/json
Content-Type: application/json
Authorization: Bearer <managed by accepted API client>
```

Send exactly:

```json
{
  "full_name": "Institution Admin",
  "login_name": "admin.school1",
  "email": null,
  "phone": "+998...",
  "password": "initial-password"
}
```

Never send:

```text
id
institution_id
role
is_active
must_change_password
last_login_at
deactivated_at
created_by_user_id
created_at
updated_at
password_confirmation
permissions
```

Also:

- no query parameters, multipart, client UUID, actor/role headers, or raw
  request construction in widgets;
- no `Idempotency-Key`, ETag, `If-Match`, version, or custom lock protocol;
- one explicit valid submit produces at most one in-flight POST;
- button, Enter, double-click, rebuild, and dialog action cannot duplicate it;
- no automatic retry at API client, repository, controller, or widget layer;
- never log request body, password, contact values, token, or raw response.

### 5.9 Mutation state and exact success mapping

Use focused session/Institution-owned states:

```text
editing
submitting
validation failure
definite ordinary failure
ambiguous outcome
confirmed success
```

Controls remain visible and bounded progress is shown while submitting. Do not
clear fields on correctable validation/definite failure; password may remain
only in the live obscured dialog memory and must never enter diagnostic,
provider persistence, serialization, logs, disk, secure storage, or snapshots.

Require HTTP `201 Created` and typed decoding of:

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "full_name": "Institution Admin",
    "login_name": "admin.school1",
    "email": null,
    "phone": "+998...",
    "is_active": true,
    "must_change_password": true,
    "last_login_at": null,
    "deactivated_at": null,
    "created_at": "2026-08-10T10:00:00Z",
    "updated_at": "2026-08-10T10:00:00Z"
  },
  "message": "Institution admin created successfully."
}
```

Confirmed success requires:

- exact `201`;
- the complete valid public resource from Section 5.5;
- `is_active = true`;
- `must_change_password = true`;
- `last_login_at = null` and `deactivated_at = null`;
- returned `login_name` equal to the submitted normalized login name;
- non-empty success `message` suitable only for feedback.

Do not require or expose role, Institution ID, creator, password/hash, token,
permissions, or settings. Do not branch on the human-readable message. A
non-`201` 2xx, malformed resource, wrong active/first-login/null state, or
mismatched login name is not confirmed success because the server may still
have committed.

### 5.10 Confirmed-success refresh and invalidation

Only after valid current-session/current-Institution `201`:

1. prevent a second success transition;
2. wipe the password and all dialog field/error state before closing;
3. close the dialog once;
4. invalidate the current Institution Admin list query family;
5. invalidate the current Institution detail because `user_counts` changed;
6. invalidate the Platform Institution list query family and Platform
   dashboard for the current session;
7. immediately refetch only the two visible resources: current Admin list and
   current Institution detail;
8. do not issue hidden Institution-list or dashboard requests;
9. keep the user on the same Institution detail route;
10. show one safe success feedback using the accepted message, never the
    password.

Retain the current Admin query where it still belongs to the same session and
Institution. A created active Admin may legitimately be hidden by current
search/status/page. Do not inject, sort, paginate, count, or claim the row is
visible. Server refresh is the only list/count authority.

If Admin-list or Institution-detail refresh fails after confirmed `201`, keep
the success fact distinct from refresh failure and offer GET-only refresh. Do
not repeat POST.

### 5.11 Failure and ambiguous-outcome behavior

Handle through the accepted typed failure boundary:

| Case | Required frontend behavior |
|---|---|
| `401 authentication_required` | Global session invalidation/reconciliation; clear Admin rows/form/secret |
| `403 user_inactive` | Accepted account reconciliation; no protected Admin data |
| `403 institution_inactive` | Accepted global handling when applicable; do not reinterpret target Institution status |
| `403 password_change_required` | Accepted password-change reconciliation |
| `403 forbidden` | Safe denied behavior; no row/form success |
| `404 resource_not_found` | Privacy-safe Institution not-found state; clear Admin section/form |
| GET `422 validation_failed` | Safe query-contract error; no raw details |
| POST `422 validation_failed` | Map approved field errors; recognized duplicate `login_name` remains a normal field error |
| Definite `500 server_error`/other HTTP failure | Safe failure; no success/invalidation; explicit new submit allowed only after user review |
| GET network/timeout/decode failure | Safe list error + GET-only Retry |
| POST timeout/disconnect after transmission may have begun | `Creation outcome is unknown`; never automatically repeat POST |
| Apparent `201` with invalid/mismatched data | Unknown outcome; no false success or automatic repeat |

For ambiguous POST outcome:

- wipe the password immediately and never display it again;
- preserve non-secret field values only in the current in-memory dialog if
  useful for manual comparison;
- explain that the account may have been created;
- provide `Refresh administrators`, which performs only the current GET;
- do not infer confirmed identity merely because search results contain the
  same text;
- do not auto-search by login, poll, or issue a second POST;
- do not offer one-click mutation Retry from the unknown state;
- after manual reconciliation, any future create attempt requires a newly
  entered password and a fresh explicit submit.

Late response after logout, session/account/role/password/device change, route
disposal, Institution change, dialog disposal, or newer mutation generation
must not render, notify, close a new dialog, invalidate/refetch new-session
providers, or leak any prior values.

### 5.12 Session, route, and Institution isolation

On logout/global invalidation/account change/route change:

- clear Admin rows, pagination, committed query, editable search, debounce,
  errors, dialog fields, password, mutation/unknown state, and feedback
  ownership;
- cancel requests where supported and ignore every late completion;
- never show Institution A Admins for Institution B;
- never show Platform Owner A data/form state for Platform Owner B;
- never show Platform Owner data after switching to another role;
- never persist Admin query/data/form/secret as independent long-term or
  cross-session authority;
- never log tokens, IDs as authority, contact data, credentials, or bodies.

Every GET/POST completion must match current session generation and current
route `institutionId`. Mutation completion must additionally match its own
submission generation.

### 5.13 Architecture and code organization

Follow accepted feature-first flow:

```text
Institution Admin section/dialog
  ↓
focused Admin list/create controllers
  ↓
Platform Institution Admin repository
  ↓
remote data source
  ↓
accepted configured Dio client
```

Requirements:

- widgets contain no raw Dio, envelope parsing, JSON maps, authorization, or
  tenant decisions;
- query/request serialization is typed and allowlisted;
- reuse accepted session generation, route identity, API client, failure
  mapper, pagination, sort direction, debounce, dialog/form, feedback, date,
  and responsive components where responsibilities match;
- keep Admin resource/query/create responsibilities focused; do not force them
  into the existing Institution summary/detail model;
- do not duplicate router, shell, token storage, auth/session controller,
  global cache, API client, or failure hierarchy;
- do not create a giant future Admin management controller or prebuild
  `S02-FE-009` actions;
- use provider overrides/fakes in tests only; no production test route, delay,
  fake response, secret logger, or environment switch;
- add no package or lockfile change.

### 5.14 Expected file surface

Derive exact paths from accepted `origin/main`. A focused change may touch:

```text
frontend/lib/features/platform_admin/data/...
frontend/lib/features/platform_admin/domain/...
frontend/lib/features/platform_admin/application/...
frontend/lib/features/platform_admin/presentation/institutions/...
frontend/test/features/platform_admin/...
tasks/frontend/stage-02/S02-FE-008-...
tasks/STAGE_02_TASK_INDEX.md
```

Do not pre-create every suggested file. Keep each responsibility focused and
reuse accepted paths. Backend, migrations, Docker, docs, CI, packages,
lockfiles, global auth/router/shell redesign, and unrelated frontend features
are protected/out of scope.

---

## 6. Required Automated Tests

### 6.1 Query, DTO, and pagination

Test at minimum:

- exact initial query and omission of unset search/status;
- search trim/empty/max-254/`350 ms`/Enter behavior;
- status allowlist, all four sorts, direction, page reset, and 20/50/100 size;
- raw labels/columns/unknown keys never serialize;
- exact GET path uses current route Institution once;
- typed Admin resource and pagination parsing for valid values/nulls;
- wrong/missing booleans, timestamp, list, and pagination data fail safely;
- additive protected fields never enter domain/presentation/logging.

### 6.2 List controller and presentation

- Admin GET starts only after successful current Institution detail;
- one initial request and no rebuild/resize duplicate;
- each committed query produces one request;
- stale query/session/route completion cannot overwrite current state;
- data preserves server order and exact total;
- global empty, filtered empty, empty page, error, Retry, and retry-in-flight;
- reset and Previous/Next disable rules;
- no local filter/sort/page/count/optimistic merge;
- only approved fields appear; nulls and states are honest;
- wide table and compact responsive layout have no page-level overflow at
  `800 × 600` and `1440 × 900`.

### 6.3 Create form and request mapping

- exact five visible fields and no password confirmation/protected field;
- full/login/email/phone/password validation boundaries;
- optional empty contacts become JSON `null`;
- login name is not silently lowercased/rewritten;
- exact POST path/method/body and no query/custom authority/idempotency/version;
- password is obscured by default and never appears in logs, state string,
  error text, snapshots, success feedback, or persisted storage;
- Cancel/Escape clears state and sends no request;
- one submit creates one request; double-click/Enter/rebuild cannot duplicate;
- no automatic POST retry.

### 6.4 Create response, validation, and ambiguity

- exact valid `201` public resource/message maps to confirmed success;
- active/first-login/null operational-state invariants and submitted-login
  match are enforced;
- non-`201` 2xx, malformed/mismatched apparent success becomes unknown;
- `422` maps only five approved keys and preserves safe correctable form state;
- duplicate `login_name` is shown as field error with no SQL/constraint leak;
- definite `500`/other failure produces no success/invalidation;
- uncertain transport wipes password, offers GET-only refresh, and performs no
  second POST/automatic search/polling;
- stale mutation completion cannot close/alter a new context.

### 6.5 Confirmed-success invalidation and regression

- exact current-session Admin-list family invalidation/refetch;
- exact current Institution detail invalidation/refetch;
- Institution list/dashboard invalidated without hidden request;
- no optimistic Admin row or `user_counts` mutation;
- current query retained honestly even when it hides the created row;
- refresh failure remains distinct from confirmed creation and offers GET only;
- detail basic data/edit/lifecycle, Institution list/create, dashboard, shell,
  logout, auth/password/role/device guards remain green;
- no Admin edit/activate/deactivate or Stage 2 integration scope exists.

---

## 7. Quality and Verification Commands

From `frontend/`, run repository-pinned equivalents:

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
flutter build windows --debug
flutter build apk --debug
```

Run focused tests first, then the complete suite. A zero-test filter is not a
pass. Do not skip either build.

From repository root inspect complete staged, unstaged, and untracked scope:

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

Open every untracked file. Do not use only `main...HEAD` as implementation
evidence because it misses uncommitted work.

Inspect the full change set for:

- wrong endpoint/path scope or request before valid detail;
- arbitrary/unvalidated query data or local list authority;
- raw JSON/Dio in widgets or unsafe response parsing;
- role/Institution/creator/status/first-login protected fields;
- plaintext password/contact/token/request-body logging or persistence;
- duplicate/automatic POST, invented idempotency/version, or false success;
- optimistic Admin row/count/dashboard/list mutation;
- stale session/account/Institution/query/mutation leakage;
- inaccessible dialog/controls or desktop overflow;
- backend/docs/package/lockfile changes;
- `S02-FE-009+` implementation or unrelated refactoring.

Any required check not run must be reported `NOT RUN` with exact reason.

---

## 8. Manual Smoke Checklist

Use the accepted real Laravel/PostgreSQL backend and Windows Flutter desktop
app. Never print/capture a password, Bearer token, hash, contact value, raw
body, SQL detail, or production data in the report.

### List behavior

1. Log in as active, password-complete Platform Owner and open one Institution.
2. Verify detail loads first and Admin list then shows only that Institution's
   `institution_admin` accounts.
3. Exercise name/login/email/phone search, including Unicode and literal `%`/
   `_`, active/inactive filter, every sort/direction, and 20/50/100 pagination.
4. Verify empty, filtered-empty, empty-page, error, and GET-only Retry behavior.
5. Open another Institution and prove prior rows/query/dialog never appear.
6. Verify inactive Institution remains manageable and shows the access note.

### Create behavior

7. Open Create, verify exactly five fields, first-login explanation, obscured
   password, keyboard/focus behavior, and Cancel/no request.
8. Exercise client and backend validation without exposing the password.
9. Create one Admin and verify exact one POST, confirmed `201`, safe feedback,
   Admin-list/detail refresh, and no hidden list/dashboard request.
10. Verify returned Admin is active, password-change-required, never logged in,
    and appears only when the current server query includes it.
11. Attempt duplicate `login_name` and verify field-level safe `422`.
12. Verify a created Admin can authenticate under backend rules but normal
    protected use remains blocked until the accepted password-change flow;
    inactive Institution still blocks access.
13. Simulate a safe test transport-unknown outcome where supported and verify
    password wipe, GET-only check, no automatic second POST, and no false
    success/failure claim.
14. Log out/change account with list/create work pending and verify no late
    completion or secret/data crosses sessions.
15. Verify Admin rows have no edit/lifecycle/reset/reveal/delete action.

Report every item `PASS`, `FAIL`, or `NOT RUN` with exact evidence/reason.
Mock/widget tests are not real-stack smoke evidence.

---

## 9. Acceptance Criteria

The task is accepted only when:

1. Exact path-scoped GET/POST are used through the configured client.
2. Admin list starts only for a successfully loaded current Institution.
3. Query allowlist/defaults/search/status/sort/pagination match `S02-BE-006`.
4. Only path-Institution Admin public resources are typed and rendered.
5. Every loading/data/empty/error/retry state is truthful and accessible.
6. Create shows exactly five fields with correct validation and no confirmation
   or protected fields.
7. Password is obscured, transient, never logged/persisted/returned/repeated,
   and cleared on cancel/success/unknown/session change.
8. One submit creates at most one POST and automatic retry is absent.
9. Confirmed success requires exact valid `201`, active/first-login state, and
   submitted-login match.
10. `422`, definite failure, and ambiguous outcome are handled exactly without
    duplicate creation or false success.
11. Confirmed creation refreshes visible Admin/detail facts and invalidates
    current-session Institution list/dashboard without optimistic authority.
12. Session/account/route/Institution/query/mutation stale completions cannot
    leak or overwrite current context.
13. Existing Platform Owner/Institution/auth/device flows remain green.
14. Focused/full tests, analyze, format, Windows build, APK build, diff, secret,
    scope, and real smoke pass with trustworthy evidence.
15. Phase 2 has zero unresolved P1/P2 findings.
16. No backend/docs/package/lockfile or `S02-FE-009+` scope is included.

---

## 10. Explicit Non-Goals

Do not implement:

- Institution Admin edit, activate, or deactivate (`S02-FE-009`);
- Admin detail route/page/drawer or row action menu;
- password reset/reveal/resend/generation/distribution;
- credential email/SMS/notification/print/clipboard/export;
- role reassignment, permissions, multiple roles, impersonation, or deletion;
- Teacher/Student/Parent/Platform Owner account creation;
- bulk import/export/invite/self-registration;
- Institution settings, learning, reporting, support-ticket, or audit data;
- local caching/persistence, offline queue, polling, WebSocket, background sync;
- new API, package, migration, router/shell/navigation redesign;
- Stage-wide integration closure (`S02-INT-001`).

---

## 11. Relevant Business and Security Rules

1. Only authenticated, active, password-complete desktop `platform_owner` may
   use this UI; backend authorization remains mandatory.
2. Route visibility is not authorization.
3. Path `institutionId` is the sole target-Institution authority.
4. Only `institution_admin` Users of that Institution may appear.
5. Client never decides role, Institution, creator, active state, first-login
   state, UUID, operational timestamps, or password hash.
6. `login_name` is globally unique; email and phone are not treated as unique.
7. New Admin is active and `must_change_password = true` under backend rules.
8. Initial password is client-entered, backend-hashed, and never returned.
9. Institution inactive state still blocks its users despite individual active
   state; Platform Owner may continue managing the Institution.
10. Human messages are feedback only, not business-state authority.
11. One explicit submit creates at most one in-flight mutation.
12. Protected data must not cross session/account/role/device/Institution
    boundaries through caches, form state, logs, or late async completion.

---

## 12. Authoritative References

| Source | Exact section | Binding requirement |
|---|---|---|
| `docs/01-business-overview.md` | User Groups; Role and Device Availability; MVP decisions | Platform Owner supports Institution Admin access on desktop; administrator-created account requires first-login password change |
| `docs/02-user-roles.md` | Platform Owner / Super Admin; Institution Admin | Platform-scoped support without daily learning control; Institution-bound Admin role |
| `docs/03-features.md` | Platform Owner / Super Admin Features | Manage/support Institution Admin access inside Institution context |
| `docs/04-user-flows.md` | Institution Admin Support Flow; Authentication and first-login flows | Open Institution, inspect Admin status, provide basic access support safely |
| `docs/05-business-rules.md` | `BR-ROLE-004`–`BR-ROLE-009`; account/Institution/first-login rules | Authorized creator, role/tenant integrity, active gates, mandatory password change |
| `docs/06-roadmap.md` | Stage 2 — Multi-Institution Platform Management | Platform management boundary and Institution Admin bridge |
| `docs/07-architecture.md` | Sections 8–9, 21.2, 22.1, 29, 32, 35 | Backend authority, desktop shell, feature layering, API/error/test/security boundaries |
| `docs/08-database.md` | Users and Roles; constraints/indexes/retention/isolation | User fields, global login uniqueness, role/Institution constraint, lifecycle preservation |
| `docs/09-api-contracts.md` | Sections 1–7.8, 33, Appendices A–C | Exact Admin GET/POST, five create fields, backend-derived role/Institution/first-login, envelopes/errors |
| `AGENTS.md` | API/security/code/test/Git rules | No invented authority/protocol; production-quality delivery |
| `frontend/AGENTS.md` | Backend Authority; Route Guards; Duplicate Mutation Prevention; state/error/accessibility | Typed server authority, one-request guard, safe state/session UX |
| Accepted `S02-BE-006` | Complete contract/evidence | Exact query/resource/create/uniqueness/first-login behavior |
| Accepted `S02-FE-001`–`S02-FE-007` | Complete contracts/evidence | Shell, dashboard/list/detail/create/edit/lifecycle, invalidation, guards, isolation |
| `tasks/STAGE_02_TASK_INDEX.md` | `S02-FE-008` and successors | Exact sequence and non-goals |

Authority order:

```text
locked docs/01–09
→ applicable AGENTS.md
→ tasks/README.md and truthful Stage 2 index
→ this approved detailed task
→ accepted backend/frontend predecessor contracts
→ current accepted origin/main patterns
→ execution prompt
```

Task-level query/UI/state/validation/secret/invalidation/ambiguity/accessibility
details narrow implementation ambiguity without changing locked behavior.

---

## 13. Stop Conditions

Stop with `FINAL STATUS: BLOCKED` if:

- Stage 1 or required Stage 2 predecessors are not accepted/delivered;
- `S02-BE-006` GET/POST/query/resource/create/error contract differs;
- accepted Institution detail/session/invalidation architecture is missing or
  materially conflicts;
- Stage 2 index is missing/conflicting;
- local `main` cannot synchronize or origin is unexpected;
- worktree contains anything beyond the exact two approved preparation files;
- safe implementation requires backend/docs/database/Docker/CI/package/
  lockfile change, new API/product decision, broad auth/router/shell redesign,
  or later-task scope;
- exact password secrecy, duplicate prevention, uncertain-outcome handling,
  path/session isolation, or full verification cannot be preserved;
- a required pre-existing frontend gate fails materially;
- unrelated user changes overlap required files and cannot be preserved;
- safe work requires destructive Git, force-push, bypass, secret exposure, or
  overwrite of user work.

During Phase 2, unresolved P1/P2 means:

```text
FINAL STATUS: NOT ACCEPTED
```

If Phase 2 passes but delivery cannot finish:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Do not start `S02-FE-009`.

---

## 14. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git preflight

Complete Section 5.1, create/switch to the exact task branch, carry the two
approved files, and do not commit/push.

### Phase 1 — Implementation

Implement only `S02-FE-008`. Run focused/full tests, analyze, format, both
builds, complete diff/scope/security review, and real smoke. Do not commit,
push, open a PR, merge, or mark accepted.

### Phase 2 — Read-only acceptance gate

Re-read authorities, predecessors, complete staged/unstaged/untracked change
set, tests/builds/smoke, route/list/query/response/form/request/secret/mutation/
refresh/failure evidence, and session/Institution isolation.

During Phase 2 make no edits; do not auto-fix, format-write, generate, stage,
unstage, commit, push, open/merge a PR, or update lifecycle state.

Severity:

```text
P1 = auth/role/device/session/Institution-isolation/secret/protected-field issue
P2 = material API/query/form/state/retry/refresh/architecture/test/build/scope issue
P3 = non-blocking observation
```

PASS requires zero unresolved P1/P2 and complete trustworthy evidence.
Otherwise return `FINAL STATUS: NOT ACCEPTED`, stop, and do not self-fix after
Phase 2 begins.

### Phase 3 — Post-acceptance delivery

Only after Phase 2 PASS:

1. Set this detailed task to `Accepted`.
2. Update only truthful `S02-FE-008` index state to Accepted/review PASS;
   delivery finalizes only after merge.
3. Apply only required task lifecycle bookkeeping.
4. Re-run final tests, builds, diff/scope/package/secret checks.
5. Stage only approved implementation, tests, task, prompt, and truthful index
   files.
6. Commit:

   ```text
   feat(platform): add institution admin list and create
   ```

   Body:

   ```text
   Task: S02-FE-008
   ```

7. Push `task/s02-fe-008-institution-admin-list-create` to approved origin.
8. Open a PR to `main`; do not bypass checks/protection.
9. Merge only when safe and green.
10. Fast-forward-sync local `main` and prove clean `main == origin/main`.

Only then return:

```text
FINAL STATUS: ACCEPTED
```

Do not create or start `S02-FE-009`.

---

## 15. Required Codex Final Report

Return:

1. Final status and dependency/Git starting/final commit evidence.
2. Changed files grouped by list/query/resource/form/mutation/presentation/test.
3. Detail-only placement, route/path ownership, and no request-before-detail
   evidence.
4. Exact GET query/default/search/filter/sort/pagination behavior.
5. Exact public Admin typed resource and leakage-negative evidence.
6. List states, request de-duplication, stale-query/route/session protection,
   responsive layout, and accessibility evidence.
7. Exact five-field create form/validation and absence of protected/
   confirmation/future fields.
8. Exact POST body, duplicate/no-auto-retry behavior, and password secrecy/
   clearing evidence.
9. Typed `201`, active/first-login/null/login-match validation, and no message
   branching evidence.
10. `401`/`403`/`404`/`422`/`500`/transport/malformed response behavior,
    duplicate-login mapping, and unknown-outcome GET-only reconciliation.
11. Confirmed-success Admin/detail visible refresh, list/dashboard invalidation,
    no hidden requests, and no optimistic row/count evidence.
12. Session/account/route/Institution/query/mutation isolation evidence.
13. Focused/full tests, analyze, format, Windows/APK build results.
14. Complete staged/unstaged/untracked diff, package, scope, and secret review.
15. Real manual smoke result with `PASS`/`FAIL`/`NOT RUN` per item.
16. Phase 2 findings by severity and acceptance decision.
17. Final branch, commit, PR, checks, merge, and clean synchronized-main
    evidence.

Do not create or start `S02-FE-009`.
