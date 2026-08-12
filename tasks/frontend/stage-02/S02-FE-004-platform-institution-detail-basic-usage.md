# Codex Task: Platform Institution Detail and Basic Usage Presentation

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-FE-004` |
| Status | `Accepted` |
| Approved on | `2026-08-10` |
| Stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Frontend / Platform Owner Institution detail read integration` |
| Priority | `High` |
| Depends on | `S02-FE-003` accepted, delivered, and present on current `origin/main`; accepted `S02-BE-001` Institution detail API |
| Sequence next | `S02-FE-005` |
| Repository | `https://github.com/Shoxrux2017/testlabuz.git` |
| Target branch | `task/s02-fe-004-institution-detail` |
| Execution model | One focused implementation task followed by read-only acceptance and safe GitHub delivery |

---

## 2. Goal

Add the real, read-only Platform Owner Institution detail experience backed by:

```text
GET /api/v1/platform/institutions/{institution}
```

The accepted result must let an eligible desktop `platform_owner`:

- open one Institution from the accepted Institution list;
- open the same Institution through a direct protected URL;
- review the Institution's approved platform-level identity, contact, address,
  description, status, and timestamps;
- review the only approved basic usage facts in this response: total and active
  Institution User-account counts;
- distinguish loading, data, not-found, ordinary failure, and Retry states;
- return reliably to the Institution list;
- remain inside the accepted Platform Owner shell with correct navigation,
  identity, logout, auth/password/role/device guards, and session isolation.

Every displayed fact must come from the accepted detail response. The client
must not call the list, dashboard, statistics, Institution Admin, settings,
reports, or learning endpoints to enrich this screen.

This task implements only the read-only detail and basic usage presentation. It
must not implement create (`S02-FE-005`), edit (`S02-FE-006`), Institution
lifecycle actions (`S02-FE-007`), or Institution Admin management
(`S02-FE-008`–`S02-FE-009`).

### Scope boundary

This task owns only:

- the canonical nested route:

  ```text
  /platform-owner/institutions/:institutionId
  ```

- one accessible `View details` transition from each accepted Institution-list
  row to the selected Institution route;
- typed Institution-detail transport/domain models;
- one focused Institution-detail data-source/repository flow;
- one route-keyed, session-aware Riverpod detail controller/provider boundary;
- the read-only Institution detail page inside the existing Platform Owner
  shell;
- exact basic information and basic User-count presentation;
- loading, data, not-found, error, and Retry behavior;
- request deduplication, route-change stale-completion protection, and session
  isolation;
- focused DTO, repository, controller, widget, router, regression, and
  responsive-layout tests;
- truthful Windows desktop smoke verification against the accepted backend.

It does not:

- add a new shell destination or redesign the accepted shell/navigation;
- add create/edit/activate/deactivate/Admin controls, even disabled ones;
- call `GET /api/v1/platform/statistics` or calculate new statistics;
- call `GET /api/v1/platform/institutions/{institution}/admins`;
- show User identities, role breakdowns, last-login/activity, online status, or
  effective login eligibility;
- show Institution learning settings, groups, topics, materials, submissions,
  scores, results, files, support issues, billing, licenses, or audit data;
- derive an inactive-User count from `total - active`;
- implement refresh polling, cache, offline persistence, prefetch, URL-query
  state, or background synchronization;
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
- accepted and delivered `S02-FE-003` Institution list;
- the truthful Stage 2 index state for those completed tasks.

Accepted frontend foundations provide:

- Flutter, Riverpod, GoRouter, Dio, and secure token storage;
- one configured authenticated API client and envelope/failure mapping;
- current `/api/v1/auth/me`-restored session authority;
- global `401` and session invalidation handling;
- first-login password routing and role/device guards;
- canonical Platform Owner routes and one persistent desktop shell;
- current-user identity, logout, account-switch, and stale-session isolation;
- a real Dashboard at `/platform-owner`;
- a real Institution list at `/platform-owner/institutions`;
- typed Platform Institution summary/count/status/type patterns;
- established feature-first `features/platform_admin/` conventions.

Accepted backend `S02-BE-001` provides:

```text
GET /api/v1/platform/institutions/{institution}
```

It returns one Institution's approved platform metadata plus aggregate
`user_counts.total` and `user_counts.active`. It returns no User identities,
role breakdown, settings, learning data, or activity details. The backend is
the authority for authentication, role access, resource existence, exact
serialization, and count meaning.

---

## 4. Dependency and Stage-Control Gate

Before implementation, prove from repository evidence:

1. Stage 1 is `Closed` and Stage DoD is `PASS`.
2. `S02-BE-001` through `S02-BE-007` are `Accepted`, reviewed `PASS`, delivered,
   and present on current `origin/main`.
3. `S02-BE-001` exposes the exact Institution detail contract defined below and
   its PostgreSQL-backed authorization/resource/count tests pass.
4. `S02-FE-001` is accepted/delivered and owns the Platform Owner shell and
   route-family guards.
5. `S02-FE-002` is accepted/delivered and owns the real Dashboard.
6. `S02-FE-003` is accepted/delivered and owns the exact Institution list,
   query state, and row presentation that this task extends only with a detail
   transition.
7. `tasks/STAGE_02_TASK_INDEX.md` matches the approved 17-task decomposition.
8. This detailed task exists exactly at:

   ```text
   tasks/frontend/stage-02/S02-FE-004-platform-institution-detail-basic-usage.md
   ```

9. Its status is `Approved`.
10. The accepted API client, session, failure, shell, route, theme, list, and
    test foundations are present and passing.
11. No conflicting Institution-detail implementation already exists.

If any dependency is missing, local `main` differs from `origin/main`, or
current evidence materially contradicts this contract, stop and return:

```text
FINAL STATUS: BLOCKED
```

Do not repair predecessor scope, recreate backend/list work, or absorb
`S02-FE-005+`.

This task may update only the truthful `S02-FE-004` lifecycle state in the
Stage 2 index. It must not create, approve, implement, or state-mutate
`S02-FE-005` or a later task.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

Before editing:

1. Read root `AGENTS.md`, `frontend/AGENTS.md`, and any nearer instruction file
   completely.
2. Read `tasks/README.md`, `tasks/STAGE_02_TASK_INDEX.md`, and this complete
   task.
3. Read accepted `S02-BE-001`, `S02-FE-001`, `S02-FE-002`, and `S02-FE-003`
   contracts and delivery evidence.
4. Read only the locked specification sections referenced in Section 12.
5. Inspect the actual Platform Owner shell, router, Institution list,
   session providers, configured API client, envelope/failure mapping,
   platform-admin models/controllers/widgets, and tests.
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
   tasks/frontend/stage-02/S02-FE-004-platform-institution-detail-basic-usage.md
   tasks/frontend/stage-02/S02-FE-004-CODEX-PROMPT.md
   ```

   No other modified, staged, deleted, renamed, or untracked path is allowed.
   Neither preparation file may be committed on `main`.
8. Create/switch to exactly:

   ```text
   task/s02-fe-004-institution-detail
   ```

9. Carry the two approved files to the task branch if needed and prove
   committed `main` was unchanged.
10. Use the repository-pinned Flutter/Dart toolchain and lockfile.
11. Run relevant pre-existing frontend quality gates before material edits.
12. Do not commit, push, open a PR, merge, or mark accepted before the read-only
    acceptance gate passes.

Unrelated changes are a blocker. Preserve user work and never reset, discard,
overwrite, or destructively clean it.

### 5.2 Route, list, and shell integration

Add exactly one nested detail route under the accepted Institutions area:

```text
route pattern: /platform-owner/institutions/:institutionId
example URL:   /platform-owner/institutions/550e8400-e29b-41d4-a716-446655440000
```

Requirements:

- define the route through the accepted route constants/naming conventions;
- use one route parameter named `institutionId` as the selected resource
  identifier;
- render the detail page inside the existing Platform Owner shell;
- keep `Institutions` selected in compact and wide navigation;
- preserve Dashboard navigation, identity, logout, and route-family guards;
- extend each accepted list row with one obvious, keyboard-accessible
  `View details` affordance using that row's server-returned `id`;
- the affordance must have a meaningful accessible label including the
  Institution name where the accepted component pattern permits;
- do not turn the row into a mutation surface or add an action menu;
- direct URL entry/refresh must restore the session normally, then load exactly
  the addressed Institution;
- provide an explicit `Back to Institutions` link/action that always navigates
  to `/platform-owner/institutions`, including after direct URL entry with no
  navigation history;
- navigating back must not deliberately mutate/reset the accepted list query;
  do not add persistence merely to retain it;
- route changes from Institution A to B must key data/request state by the
  current `institutionId`;
- wrong role, unsupported device, unauthenticated state, inactive state, and
  first-login state must remain blocked/reconciled before usable detail data is
  shown.

Do not add a new navigation destination, second shell, modal route, detail
drawer, global selected-Institution authority, or route query parameters.

### 5.3 Exact endpoint and request contract

Use only:

```text
GET /api/v1/platform/institutions/{institution}
```

Request requirements:

- replace `{institution}` with the current route `institutionId` as one safely
  encoded path segment;
- use the existing configured authenticated API client;
- send no request body;
- send no query parameters;
- do not send `institution_id`, role, user ID, include/expand flags, or any
  other client authority;
- do not call the Institution list to locate or verify the record first;
- do not call dashboard/statistics/Admin/settings/report/learning endpoints;
- do not infer resource existence or permission from locally cached list data;
- backend `404 resource_not_found` is authoritative for malformed or unknown
  identifiers;
- one initial route value produces at most one active logical request;
- rebuilds do not create duplicate requests;
- Retry after an ordinary retryable failure creates exactly one new request
  for the same current route/session key;
- a second Retry while that request is in flight is ignored/disabled.

The request is read-only. It must not change Institution/User state or server
timestamps.

### 5.4 Exact success response and typed mapping

Consume `200 OK`:

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Example School",
    "type": "school",
    "status": "active",
    "contact_email": "info@example.uz",
    "contact_phone": "+998...",
    "address": "Samarkand",
    "description": "Optional notes",
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-07T15:00:00Z",
    "user_counts": {
      "total": 42,
      "active": 40
    }
  }
}
```

Exact response rules:

- `data` is one object, not a collection;
- `id` and `name` are required non-empty strings;
- `type` is one of the nine accepted Institution types;
- `status` is exactly `active` or `inactive`;
- `contact_email`, `contact_phone`, `address`, and `description` are nullable
  strings;
- `created_at` and `updated_at` are required valid RFC3339 timestamps;
- `user_counts.total` and `user_counts.active` are required non-negative
  integers;
- `user_counts.active <= user_counts.total` must hold; an impossible response
  becomes a safe decode/contract failure rather than misleading UI;
- the response has no required success `message`;
- additive unknown fields may be ignored safely but must not automatically
  appear in UI;
- missing, null, wrong-type, unknown-enum, negative-count, impossible-count, or
  invalid-timestamp core data becomes a typed decode/contract failure;
- do not partially render an invalid response;
- no raw JSON map reaches presentation.

Reuse accepted Institution type/status/count value objects and formatting
utilities where they genuinely match. Use a focused detail DTO/domain model for
the detail-only fields; do not weaken the stricter list-summary contract or
duplicate conflicting enum/count definitions.

### 5.5 Institution detail presentation

The page must contain these truthful read-only areas.

#### Page context

- `Back to Institutions`;
- page title using the returned Institution name only after successful load;
- visible Institution type label;
- visible, accessible status badge for `active` or `inactive`;
- no fake subtitle, activity, health, warning, or support status.

#### Basic information

Display labeled values for exactly:

```text
Name
Type
Status
Contact email
Contact phone
Address
Description
Created at
Updated at
```

Rules:

- use readable labels while preserving typed enum values internally;
- null/empty optional fields use one consistent honest placeholder such as
  `Not provided`; never display literal `null` or invent a value;
- long email/phone/address/description values wrap or truncate accessibly
  without horizontal overflow or exposing raw layout errors;
- preserve line breaks safely only where the accepted text component supports
  them; render all server text as text, never executable markup;
- timestamps use the accepted date/time formatter and preserve the server
  instant; do not claim Institution-local time because Institution timezone is
  not returned by this endpoint;
- no edit affordance, inline field, copy-secret behavior, or hidden mutation.

#### Basic usage

Display exactly two aggregate values from `user_counts`:

```text
Total user accounts  ← user_counts.total
Active user accounts ← user_counts.active
```

Meaning:

- `total` includes active and inactive users whose
  `users.institution_id = institution.id`;
- `active` means persisted `users.is_active = true`;
- it does not mean online, recently active, able to log in now, or active after
  applying Institution status/password rules;
- Platform Owner accounts are not included;
- do not derive/display inactive count, percentages, trends, charts, role
  counts, or activity timestamps;
- counts are server facts and must not be recalculated from other client data.

#### Layout and accessibility

- follow the accepted Material 3/theme/design components;
- use a readable one-column compact desktop layout and a balanced multi-column
  wide layout where appropriate;
- the content must scroll vertically when height is constrained;
- no horizontal overflow at `800 × 600` and `1440 × 900` Windows viewports;
- keyboard focus order starts with navigation/back context and reaches all
  interactive elements predictably;
- status meaning must not depend on color alone;
- headings, labels, Retry, and Back actions must have clear semantics/tooltips
  where required by accepted components;
- loading placeholders must not announce fake Institution values.

### 5.6 Exact view states

The detail flow has these mutually exclusive presentation states.

#### Initial loading

- keep the accepted shell visible for a still-valid session;
- show a bounded detail-page loading/skeleton state;
- do not show stale list-row fields as if they were confirmed detail data;
- do not show zeros or placeholder facts that look authoritative;
- no duplicate request on rebuild.

#### Data

- render only after the complete response passes typed parsing;
- show all exact basic-information labels and the two usage counts;
- nullable optional fields remain honest placeholders;
- ordinary rebuilds do not refetch.

#### Not found

For backend:

```text
404 resource_not_found
```

- show a dedicated safe `Institution not found` state inside the shell;
- show no cached/partial Institution detail;
- provide `Back to Institutions`;
- do not show Retry as if the same identifier will become valid;
- do not distinguish malformed, deleted, unknown, or otherwise unavailable
  identifiers;
- do not expose raw UUID parsing, server internals, or stack traces.

#### Ordinary error

For retryable network/server/decode failures:

- show one safe detail error with one Retry action where retry is meaningful;
- remove any partial/current detail from the failed request state;
- preserve current route context and shell only while the session is valid;
- do not display raw exception text, request headers, tokens, payload dumps,
  internal URLs, SQL, or stack traces.

#### Route change

- while moving from Institution A to B, never render A under B's URL/title;
- show B's loading state or another clearly non-authoritative transition state;
- completion from A must not overwrite B;
- a late failure from A must not replace B's newer state.

There is no ordinary `empty` state for a successful single-resource response.
Null optional fields are part of `data`, not an empty result.

### 5.7 Request orchestration and stale-completion safety

Use one focused controller/provider flow whose identity includes:

```text
authenticated session/account identity
+ current institutionId
```

Requirements:

- exactly one initial logical request per current detail key;
- rebuilds do not create additional requests;
- duplicate in-flight Retry is prevented;
- route A → B invalidates/ignores completion for A;
- logout, token invalidation, role change, account switch, and controller
  disposal invalidate/ignore late completion;
- a late response may not repopulate protected data after invalidation;
- do not keep one global mutable selected-Institution singleton;
- no polling, background refresh, prefetch from list hover, persistent cache,
  offline storage, or speculative request;
- cancellation may be used when supported, but correctness must also hold when
  transport cancellation races or is unavailable.

### 5.8 Auth, failure, and session reconciliation

Use stable machine-readable failures; never parse human-readable `message` to
make business decisions.

| Backend/client result | Required frontend behavior |
|---|---|
| `401 authentication_required` | Use accepted global session invalidation/login reconciliation and remove detail data |
| `403 user_inactive` | Reconcile through accepted account/session restriction flow; show no detail |
| `403 password_change_required` | Route only to accepted password-change flow; show no detail |
| `403 forbidden` | Use accepted protected-route/failure behavior; show no Institution data |
| `404 resource_not_found` | Dedicated safe not-found state with Back action |
| Unexpected `422 validation_failed` | Safe request/error state; do not reinterpret as not-found or expose raw field internals |
| `5xx`, timeout, connectivity | Safe retryable error where meaningful |
| Decode/contract failure | Safe non-data error; never partial rendering |

Client-side route guards remain UX boundaries. Backend response remains the
final data-access authority.

### 5.9 Session and account isolation

Required behavior:

- Platform Owner A's detail cannot appear for Platform Owner B;
- Platform Owner detail cannot appear for Institution Admin/Teacher/Student/
  Parent after account switch;
- logout clears visible detail/error/loading ownership immediately;
- invalidation while loading prevents late response repopulation;
- the same Institution UUID in a new session must produce a new authorized
  request, not reuse old protected data;
- list-to-detail navigation never copies a row object into authoritative detail
  state;
- route state contains only the identifier, not a serialized Institution/User
  payload;
- tests must prove isolation under delayed completion.

### 5.10 Architecture and code organization

Required conceptual flow:

```text
accepted configured API client
→ focused Institution-detail data source
→ repository + typed DTO/domain mapping
→ route-keyed session-aware Riverpod controller/provider
→ detail presentation
```

Rules:

- presentation does not call Dio or parse JSON;
- route parsing does not authorize existence;
- widgets do not inspect tokens or construct API URLs ad hoc;
- one focused repository may own Institution read operations if the accepted
  list architecture makes that coherent; do not force a duplicate repository;
- keep list query state separate from detail state;
- reuse accepted enum/count/format/UI primitives where semantically exact;
- avoid a god `PlatformController`, generic CRUD framework, speculative
  selected-tenant context, or parallel API/auth/session/error boundary;
- no new package is expected;
- no generated/codegen expansion is required unless already established and
  unavoidable; report any generated-file impact;
- implementation names may follow current accepted conventions, but the route,
  endpoint, response, states, and boundaries in this task are exact.

### 5.11 Expected file surface

Codex must inspect actual `origin/main` before choosing final path names.

| File or area | Expected action | Reason |
|---|---|---|
| `AGENTS.md`, `frontend/AGENTS.md` | Read | Root/frontend authority |
| `tasks/README.md`, `tasks/STAGE_02_TASK_INDEX.md` | Read; lifecycle-only update after acceptance | Workflow and truthful stage state |
| this detailed task and prompt | Preserve; lifecycle update only after Phase 2 PASS | Approved scope/audit trail |
| `frontend/lib/app/router/*` | Modify minimally | Add exact protected nested detail route |
| accepted Institution-list presentation | Modify minimally | Add one accessible detail transition |
| `frontend/lib/features/platform_admin/data/*` | Reuse/modify/create focused files | Detail request and DTO parsing |
| `frontend/lib/features/platform_admin/domain/*` | Reuse/modify/create focused files | Typed detail model/repository contract |
| `frontend/lib/features/platform_admin/presentation/*` | Create/modify focused files | Detail controller, states, screen/widgets |
| `frontend/test/features/platform_admin/*` | Create/modify focused tests | DTO/repository/controller/widget coverage |
| router/session regression tests | Modify | Direct route, guards, isolation, back/list behavior |

Changes outside this surface require a concrete necessity inside scope and
must be reported.

Do not modify:

- locked `docs/01–09`;
- `backend/` or `docker/`;
- database/schema/migrations;
- auth/session endpoint semantics;
- `frontend/pubspec.yaml` or `frontend/pubspec.lock`;
- CI/toolchain configuration;
- unrelated role features.

---

## 6. Required Automated Tests

Zero executed tests is not a pass.

### 6.1 DTO and domain mapping

- [ ] Exact successful response decodes to the detail domain model.
- [ ] All nine Institution types and both statuses decode through accepted
      typed values.
- [ ] Each nullable optional field accepts JSON `null` and maps honestly.
- [ ] Required fields missing/null/wrong-type fail safely.
- [ ] Empty ID/name, unknown enum, invalid timestamp fail safely.
- [ ] Counts reject negative values, wrong types, and `active > total`.
- [ ] Additive unknown fields are ignored and never exposed automatically.
- [ ] Detail-only fields do not weaken list-summary parsing.

### 6.2 Data source and repository

- [ ] Exact GET path uses the current safely encoded `institutionId`.
- [ ] Request sends no body, query, role, Institution, User, or include
      authority.
- [ ] Single-resource envelope is parsed through accepted core boundaries.
- [ ] Typed auth/status/password/forbidden/not-found/server/network/decode
      failures are preserved/mapped correctly.
- [ ] No secondary list/dashboard/statistics/Admin/settings/report request is
      made.
- [ ] Successful order/text/count values are preserved without calculation.

### 6.3 Controller and request lifecycle

- [ ] One initial request occurs; rebuild/list repaint causes no duplicate.
- [ ] Retry issues one request for the same current key.
- [ ] Duplicate in-flight Retry is prevented.
- [ ] A → B route transition shows no A detail under B.
- [ ] Late A success/failure cannot overwrite B.
- [ ] Logout/invalidation/account switch prevents late repopulation.
- [ ] A new authenticated session refetches even for the same UUID.
- [ ] Controller disposal cannot publish protected late data.

### 6.4 Widget states and presentation

- [ ] Loading contains no fake/cached authoritative detail values.
- [ ] Data shows every exact basic-information label/value.
- [ ] Null optional fields use the accepted honest placeholder.
- [ ] Usage shows exactly total and active User accounts from the response.
- [ ] No derived inactive/percentage/trend/chart/role/activity value exists.
- [ ] Active/inactive status is textually and visually accessible.
- [ ] `404 resource_not_found` shows dedicated not-found + Back and no Retry.
- [ ] Retryable error shows safe message + one protected Retry.
- [ ] Raw error/UUID/server/token/stack details are absent.
- [ ] Long values and constrained height remain usable.
- [ ] No overflow at `800 × 600` and `1440 × 900`.

### 6.5 Route, list, shell, session, and regression

- [ ] Each list row exposes one accessible `View details` transition using its
      server ID.
- [ ] Route pattern and parameter are exact.
- [ ] Direct protected URL loads after accepted session restore.
- [ ] Institutions navigation stays selected; shell/identity/logout remain.
- [ ] Explicit Back works both after list navigation and direct URL entry.
- [ ] Unauthenticated, first-login, wrong-role, inactive-user, mobile, web, and
      unsupported-device behavior remains accepted.
- [ ] `401` invalidation removes protected detail/shell state as accepted.
- [ ] Platform Owner A → B and Platform Owner → another role leak no detail.
- [ ] Dashboard and Institution list query/filter/pagination behavior remain
      correct and independent.
- [ ] No mutation/Admin/later-task affordance is introduced.
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

- secrets, credentials, tokens, `.env` content, private URLs, or payload logs;
- raw Dio/JSON/maps in widgets;
- duplicate API client, auth, session, router, or error boundaries;
- unsafe route/path construction or client-side existence authority;
- requests beyond the exact detail endpoint;
- cached list data rendered as authoritative detail;
- derived/fake counts, role/activity/settings/learning data;
- duplicate requests, Retry races, stale route/session completion;
- polling, prefetch, persistence, cross-account state;
- edit/lifecycle/Admin/later-task UI;
- dependency/package/generated/lockfile drift;
- unrelated refactors or protected-path changes.

---

## 8. Manual Smoke Checklist

Use the real Windows app, accepted Laravel/PostgreSQL runtime, and controlled
local/test data. Redact credentials/tokens.

### Real detail behavior

1. Prepare at least two Institutions with different types/statuses, controlled
   timestamps/User counts, and combinations of null, long, Unicode, and
   multiline optional fields.
2. Login as an active, password-complete Platform Owner on Windows desktop.
3. Open `/platform-owner/institutions` and verify the accepted list remains
   correct.
4. Use `View details` for Institution A and confirm exact route ID and one
   detail request.
5. Compare every visible value and both User counts with the real response.
6. Confirm nullable fields show an honest placeholder and long text wraps.
7. Confirm active and inactive Institutions are labeled correctly without
   implying User online/login eligibility.
8. Use Back and confirm the Institution list remains usable and no mutation
   occurred.
9. Open Institution B through a direct URL/refresh and confirm normal session
   restoration plus correct B data.
10. Confirm no dashboard/statistics/Admin/settings/report/learning request or
    future action appears.
11. Verify keyboard navigation, focus, status semantics, scrolling, and
    `800 × 600` / `1440 × 900` layouts.

### Failure and isolation

1. Open a controlled unknown valid UUID and a malformed route value; confirm
   the same safe not-found presentation where backend returns the accepted
   `404`.
2. Safely make the detail endpoint fail without production-code test hooks.
3. Confirm safe error, no partial/stale detail, and one Retry.
4. Restore backend, Retry once, and confirm one successful current-ID request.
5. Navigate A → B under controlled latency and prove late A cannot overwrite B.
6. Trigger invalid-token reconciliation while detail is present/loading and
   confirm protected data is removed.
7. Logout, login as another Platform Owner, then another role; confirm no old
   detail/error/loading state appears.
8. Confirm Dashboard and list behavior remain intact.

Report every unavailable manual item as `NOT RUN` with exact reason. Never
claim a widget-only or mocked check as real-stack smoke.

---

## 9. Acceptance Criteria

- [ ] Dependency/Git gate is proven.
- [ ] Work occurs only on `task/s02-fe-004-institution-detail`.
- [ ] Exact nested protected route and list transition exist.
- [ ] Direct URL and explicit Back behavior work inside the accepted shell.
- [ ] Only the exact Institution detail GET endpoint is used.
- [ ] Request contains no body/query/client authority.
- [ ] Exact response fields map through typed DTO/domain/repository/controller
      boundaries.
- [ ] Basic information and exactly two User-count facts render truthfully.
- [ ] No derived/fake/protected/activity/settings/learning data exists.
- [ ] Loading, data, not-found, error, Retry, and route-change states are tested.
- [ ] Duplicate requests and stale route/session completion are prevented.
- [ ] Auth/password/status/role/device/account isolation remains accepted.
- [ ] Dashboard, Institution list, shell, identity, logout, and query-state
      regressions remain green.
- [ ] No create/edit/lifecycle/Admin/later-task behavior exists.
- [ ] No backend/docs/Docker/schema/dependency/CI change exists.
- [ ] Focused/full tests, analyze, format, Windows build, and APK build pass.
- [ ] Manual smoke is truthful and secrets are redacted.
- [ ] Phase 2 has zero unresolved P1/P2 findings.
- [ ] Final `ACCEPTED` occurs only after PR delivery, merge, and clean sync.

---

## 10. Explicit Non-Goals

- Create Institution form/mutation (`S02-FE-005`).
- Edit Institution form/mutation (`S02-FE-006`).
- Activate/deactivate UI (`S02-FE-007`).
- Institution Admin list/create (`S02-FE-008`).
- Institution Admin edit/lifecycle (`S02-FE-009`).
- Stage 2 full real-stack verification (`S02-INT-001`).
- New shell navigation destination or shell redesign.
- Detail drawer/modal/global selected-Institution context.
- List-query URL persistence or new list behavior beyond one detail transition.
- Teacher/student/parent/Admin/role counts or User identities.
- Inactive-User derivation, percentages, charts, trends, activity, last login,
  online/eligible User claims.
- Settings, support/issues, reports, groups, learning data, files, submissions,
  scores, results, creator/deactivation metadata.
- Dashboard/statistics enrichment or additional API calls.
- Action menus, create/edit/lifecycle/Admin buttons, dialogs, or disabled
  future placeholders.
- Export, print, copy-all, bulk actions, saved views, shareable snapshots.
- Polling, cache, offline, prefetch, WebSocket/background refresh.
- Mobile/web Platform Owner support.
- Localization/design-system overhaul.
- New packages or backend/schema/Docker/docs/CI changes.

---

## 11. Relevant Business and Security Rules

1. Only an active, password-complete desktop `platform_owner` uses the screen.
2. Backend authorization and resource existence remain authoritative.
3. Route UUID identifies requested intent; it does not grant access.
4. Platform Owner detail access does not authorize ordinary Institution-user or
   daily learning access.
5. Detail returns only approved platform metadata and aggregate User counts.
6. `user_counts.active` means persisted account state, not online activity or
   effective access while Institution/user/password gates apply.
7. Platform Owner accounts are excluded from Institution counts.
8. No role breakdown or inactive count may be inferred/displayed.
9. Status is `active` or `inactive`; deactivation preserves data and blocks
   normal Institution-user functionality.
10. No request in this task mutates lifecycle, profile, Admin, or learning data.
11. Stable typed errors, not human messages, drive behavior.
12. Session/route changes invalidate detail ownership and late completion.
13. Server text is rendered safely as text.
14. Daily learning, settings, support, and advanced analytics remain outside
    this task.

---

## 12. Authoritative References

| Source | Exact section | Requirement |
|---|---|---|
| `docs/01-business-overview.md` | Multi-Institution foundation, approved roles/devices, Platform Owner overview | Platform-level Institution management and desktop boundary |
| `docs/02-user-roles.md` | `1. Platform Owner / Super Admin`; role/device boundaries | Detail/status/basic usage authority without daily-learning interference |
| `docs/03-features.md` | `2. Platform Owner / Super Admin Features` | View Institution information/status/basic usage; advanced analytics excluded |
| `docs/04-user-flows.md` | `2. Platform Owner / Super Admin Flow`; `Institution Management Flow`; boundaries | List → details → basic information/status/users/activity overview, limited by accepted API |
| `docs/05-business-rules.md` | `BR-INST-001`–`021`; applicable role/access rules | Isolation, lifecycle meaning, platform authority, daily-learning boundary |
| `docs/06-roadmap.md` | `2.6`; `7. Stage 2`; `Institution Management`; boundary/tests | Desktop detail, status, basic usage, protected-data exclusions |
| `docs/07-architecture.md` | `20`, `21`, `22.1`, `23`, `29`, `32.4`–`32.6`, `35` | Flutter layers, protected route/shell, typed API/errors, tests, security |
| `docs/09-api-contracts.md` | `2`, `4`, `5`, `7.4`, `33` | Single-resource envelope, exact detail endpoint, stable failures, security |
| `AGENTS.md` and `frontend/AGENTS.md` | Applicable full rules | Workflow, typed layers/states, tests, safe delivery |
| accepted `S02-BE-001` | Complete detail contract/evidence | Exact fields, counts, `404`, PostgreSQL and protected-data boundary |
| accepted `S02-FE-001` | Complete contract/evidence | Shell, route family, navigation, guards, logout, isolation |
| accepted `S02-FE-002` | Complete contract/evidence | Platform-admin architecture and Dashboard independence |
| accepted `S02-FE-003` | Complete contract/evidence | Institution list/query state and source of detail transition |
| `tasks/STAGE_02_TASK_INDEX.md` | `S02-FE-004` and successors | Exact sequence and non-goals |

Task-level route, labels, not-found state, no-derived-count rule, request-count,
stale-completion, and responsive details narrow implementation ambiguity without
changing locked backend/product behavior.

---

## 13. Stop Conditions

Stop with `FINAL STATUS: BLOCKED` if:

- Stage 1 or required Stage 2 predecessors are not accepted/delivered;
- `S02-BE-001` endpoint/response/count/error contract differs materially;
- `S02-FE-001` shell/guards or `S02-FE-003` list architecture is absent or
  conflicting;
- Stage 2 index is missing/conflicting;
- local `main` cannot synchronize or `origin` is unexpected;
- unrelated dirty work exists;
- accepted client/session/failure/test foundations are missing/broken;
- locked docs conflict;
- implementation requires a package, backend/docs/schema/Docker/CI change,
  broad auth/network/shell redesign, or later-task scope;
- safe typed parsing, route/request isolation, or account isolation cannot be
  preserved;
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

Do not start `S02-FE-005`.

---

## 14. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git preflight

Complete Section 5.1, create/switch to the exact task branch, carry the two
approved files, and do not commit/push.

### Phase 1 — Implementation

Implement only `S02-FE-004`. Run focused/full tests, analyze, format, builds,
diff/scope/security review, and manual smoke. Do not commit, push, open a PR,
merge, or mark accepted.

### Phase 2 — Read-only acceptance gate

Re-read this task, instructions, referenced locked sections, predecessors, the
complete staged/unstaged/untracked change set, tests/builds/smoke, exact route/
endpoint/response evidence, all view states, error behavior, and route/session/
account isolation.

During Phase 2 make no edits; do not auto-fix, format-write, generate, stage,
unstage, commit, push, open/merge a PR, or update lifecycle state.

Severity:

```text
P1 = auth/role/device/session/account-isolation/secret/protected-data issue
P2 = material API/route/state/UI/architecture/test/build/scope/contract issue
P3 = non-blocking observation
```

PASS requires zero unresolved P1/P2 and complete trustworthy evidence.
Otherwise return `FINAL STATUS: NOT ACCEPTED`, stop, and do not self-fix after
Phase 2 begins.

### Phase 3 — Post-acceptance delivery

Only after Phase 2 PASS:

1. Set this detailed task to `Accepted`.
2. Update only truthful `S02-FE-004` index state to Accepted/review PASS;
   delivery finalizes only after merge.
3. Apply only required task lifecycle bookkeeping.
4. Re-run final tests, builds, diff/scope/package/secret checks.
5. Stage only approved implementation, tests, task, prompt, and truthful index
   files.
6. Commit:

   ```text
   feat(platform): add institution detail view
   ```

   Body:

   ```text
   Task: S02-FE-004
   ```

7. Push `task/s02-fe-004-institution-detail` to the approved origin.
8. Open a PR to `main`; do not bypass checks/protection.
9. Merge only when safe and green.
10. Fast-forward-sync local `main` and prove clean `main == origin/main`.

Only then return:

```text
FINAL STATUS: ACCEPTED
```

Do not create or start `S02-FE-005`.

---

## 15. Required Codex Final Report

Return:

1. Final status and dependency/Git commit evidence.
2. Changed-file summary and exact route/list-transition/endpoint evidence.
3. Exact response/typed DTO/domain/repository/controller evidence.
4. Basic-information and exact two-count presentation evidence.
5. Loading/data/not-found/error/Retry/route-change evidence.
6. Request count, deduplication, stale route/session completion evidence.
7. Auth/status/password/role/device/account isolation evidence.
8. No-protected/no-derived/no-fake/no-mutation/no-later-scope evidence.
9. Focused/full tests, analyze, format, Windows/APK builds.
10. Diff/scope/package/secret/untracked checks.
11. Manual smoke and exact `NOT RUN` items.
12. Phase 2 findings/decision.
13. Commit/branch/PR/merge/final-sync evidence.
14. Remaining blockers/deviations.

Do not create or start `S02-FE-005`.
