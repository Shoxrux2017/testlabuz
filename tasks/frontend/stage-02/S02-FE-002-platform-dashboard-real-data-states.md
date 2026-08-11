# Codex Task: Platform Owner Dashboard — Real Data and Complete View States

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-FE-002` |
| Status | `Accepted` |
| Approved on | `2026-08-10` |
| Stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Frontend / Platform Owner dashboard read integration` |
| Priority | `High` |
| Depends on | `S02-FE-001` accepted, delivered, and present on current `origin/main`; accepted `S02-BE-005` dashboard API |
| Sequence next | `S02-FE-003` |
| Repository | `https://github.com/Shoxrux2017/testlabuz.git` |
| Target branch | `task/s02-fe-002-platform-dashboard` |
| Execution model | One focused implementation task followed by read-only acceptance and safe GitHub delivery |

---

## 2. Goal

Replace only the static Dashboard placeholder at:

```text
/platform-owner
```

with a real, read-only Platform Owner dashboard backed by:

```text
GET /api/v1/platform/dashboard
```

The accepted dashboard must:

- remain inside the accepted `S02-FE-001` Platform Owner desktop shell;
- use the existing authenticated API client and current-session authority;
- render the five approved platform metrics:
  - total Institutions;
  - active Institutions;
  - inactive Institutions;
  - total User accounts;
  - active User accounts;
- render up to five recent Institutions supplied by the backend;
- distinguish initial loading, institution-empty, data, partial-empty, and safe
  error/retry states;
- preserve global authentication, first-login, user-status, role/device,
  logout, invalidation, and account-switch behavior;
- expose no private user, Institution contact, settings, learning, support, or
  debug data;
- remain honest: every number and recent Institution comes from the response.

This is one read-integration task. It must not implement Institution list,
detail, create, update, lifecycle, or Institution Admin UI owned by
`S02-FE-003` through `S02-FE-009`.

### Scope boundary

This task owns only:

- typed transport/domain representation for the core dashboard response;
- one dashboard API data-source/repository flow;
- one focused Riverpod-owned dashboard state boundary;
- the real `/platform-owner` Dashboard body;
- loading, institution-empty, data, partial-empty, error, and retry presentation;
- five KPI presentations and the server-provided recent-Institution list;
- focused unit/widget tests and Windows desktop smoke verification.

It does not:

- change the Platform Owner shell, routes, navigation destinations, or guard
  policy except for minimal integration that replaces the Dashboard
  placeholder;
- fetch `/api/v1/platform/institutions`;
- implement Institution search, filters, sorting, pagination, or detail;
- navigate recent rows to an Institution detail screen;
- implement Institution or Institution Admin mutations;
- call or implement `/api/v1/platform/statistics`;
- add charts, trends, rankings, comparisons, predictions, exports, support,
  issue, attention, settings, storage, quota, billing, licensing, audit, or
  educational analytics blocks;
- add polling, background refresh, persistence, offline cache, or a package;
- change backend code, schema, Docker, CI, or locked `docs/01–09`.

---

## 3. Current Accepted Context

Treat current `origin/main` at execution time as implementation truth. This
preparation snapshot exists only to make the task reviewable; Codex must
independently synchronize and inspect the repository.

Verified preparation baseline:

```text
origin/main commit:
b6c840a9dc935f6a9b2a87a63e5fc99352782ed8
```

That commit closes Stage 1. At execution, `origin/main` must additionally
contain all accepted Stage 2 backend tasks through `S02-BE-007` and the
accepted/delivered `S02-FE-001` shell task.

Accepted frontend foundations provide:

- Flutter, Riverpod, GoRouter, Dio, and secure token storage;
- one configured API client and centralized envelope/failure mapping;
- one live `/api/v1/auth/me`-restored session authority;
- global `401` and session invalidation handling;
- first-login password routing and role/device guards;
- the canonical `/platform-owner` route;
- a persistent Platform Owner desktop shell;
- exactly Dashboard and Institutions navigation destinations;
- current-user identity, logout, account-switch, and stale-session isolation;
- an honest Dashboard placeholder intended for replacement by this task.

Accepted backend `S02-BE-005` provides exactly one read endpoint:

```text
GET /api/v1/platform/dashboard
```

It accepts no query parameters and returns only the approved Institution/User
aggregates and recent Institutions. The locked API permits future optional
dashboard metrics to evolve; this task consumes only the approved core fields.

---

## 4. Dependency and Stage-Control Gate

Before implementation, prove from repository evidence:

1. Stage 1 is `Closed` and Stage DoD is `PASS`.
2. `S02-BE-001` through `S02-BE-007` are `Accepted`, reviewed `PASS`, delivered,
   and present on current `origin/main`.
3. `S02-BE-005` exposes the exact accepted dashboard response and tests.
4. `S02-FE-001` is `Accepted`, reviewed `PASS`, delivered, and present on
   current `origin/main`.
5. `tasks/STAGE_02_TASK_INDEX.md` matches the approved 17-task decomposition.
6. This detailed task exists exactly at:

   ```text
   tasks/frontend/stage-02/S02-FE-002-platform-dashboard-real-data-states.md
   ```

7. Its status is `Approved`.
8. The accepted shell and Dashboard placeholder exist without a conflicting
   dashboard implementation.
9. The API client, session, failure, and test foundations are passing.

If a dependency is missing, local `main` differs from `origin/main`, or current
evidence materially contradicts this contract, stop and return:

```text
FINAL STATUS: BLOCKED
```

Do not repair predecessor scope, recreate accepted backend/shell work, or
absorb `S02-FE-003+`.

This task may update only the truthful `S02-FE-002` lifecycle state in the
Stage 2 index. It must not create, approve, implement, or state-mutate
`S02-FE-003` or a later task.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

Before editing:

1. Read root `AGENTS.md`, `frontend/AGENTS.md`, and nearer instructions fully.
2. Read `tasks/README.md`, `tasks/STAGE_02_TASK_INDEX.md`, and this task.
3. Read accepted `S02-BE-005` and `S02-FE-001` evidence.
4. Read only locked specification sections referenced in Section 12.
5. Inspect the actual shell, placeholder, router, session providers, configured
   API client, envelope parser, typed failures, repository/provider
   conventions, theme, and tests.
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
   permitted worktree changes are these two preparation files:

   ```text
   tasks/frontend/stage-02/S02-FE-002-platform-dashboard-real-data-states.md
   tasks/frontend/stage-02/S02-FE-002-CODEX-PROMPT.md
   ```

   No other modified, staged, deleted, renamed, or untracked path is allowed.
   Neither preparation file may be committed on `main`.
8. Create/switch to:

   ```text
   task/s02-fe-002-platform-dashboard
   ```

9. Carry the two approved files to the task branch if needed and prove
   committed `main` was unchanged.
10. Use the repository-pinned Flutter/Dart toolchain and lockfile.
11. Do not commit, push, or open a PR before the read-only gate passes.

Unrelated changes are a blocker. Preserve user work and never reset, discard,
overwrite, or destructively clean it.

### 5.2 Exact endpoint and request contract

Issue exactly:

```http
GET /api/v1/platform/dashboard
Accept: application/json
Authorization: Bearer <managed by accepted API client>
```

Rules:

- use the existing authenticated API client and endpoint convention;
- send no query parameters and no body;
- never send `institution_id`, role, user ID, metrics, limit, page, date range,
  include list, sort, or other scope input;
- do not manually read tokens inside this feature;
- do not add a Dio instance, auth interceptor, envelope parser, or base URL;
- do not retry automatically or poll;
- one initial eligible entry may produce one request;
- rebuilds and layout changes must not duplicate the request;
- the explicit error Retry creates one new request and is in-flight protected.

Backend authorization remains authoritative. The route guard is UX only.

### 5.3 Exact response contract

Consume this core shape:

```json
{
  "data": {
    "institutions": {
      "total": 20,
      "active": 18,
      "inactive": 2
    },
    "users": {
      "total": 2800,
      "active": 2720
    },
    "recent_institutions": [
      {
        "id": "uuid",
        "name": "Example School",
        "type": "school",
        "status": "active",
        "created_at": "2026-08-01T10:00:00Z"
      }
    ]
  }
}
```

Required typed fields:

```text
institutions.total      integer >= 0
institutions.active     integer >= 0
institutions.inactive   integer >= 0
users.total             integer >= 0
users.active            integer >= 0
recent_institutions     list, server maximum 5

recent item:
id                      non-empty UUID-form identifier string
name                    non-empty string
type                    canonical Institution type
status                  active | inactive
created_at              valid RFC 3339 / ISO 8601 timestamp
```

Use focused DTOs and domain/UI models; widgets must not decode raw JSON.

Parsing rules:

- require all core fields and expected types;
- do not coerce `"20"` to integer or treat missing values as zero;
- do not recompute totals from recent rows;
- do not derive active users from Institution status, tokens, or login time;
- route invalid core shapes through the typed decode/failure boundary;
- never show raw decode exceptions or JSON;
- ignore additive unknown fields safely so future optional metrics do not
  become UI authority or crash valid core data;
- do not retain, log, or render unknown response content;
- never silently repair contradictory server values.

### 5.4 Exact metric meaning and labels

| UI concept | Backend field | Exact meaning |
|---|---|---|
| Total institutions | `institutions.total` | Every persisted Institution |
| Active institutions | `institutions.active` | Institution `status=active` |
| Inactive institutions | `institutions.inactive` | Institution `status=inactive` |
| Total users | `users.total` | Every User, including Platform Owner accounts |
| Active users | `users.active` | `users.is_active=true`, independent of Institution status |

Never relabel active users as online, logged-in, recent, currently eligible, or
active-institution users.

Canonical Institution type values:

```text
school
college
lyceum
university
institute
learning_center
training_center
private_education
other
```

Render human-readable type labels through a focused mapping. Do not create a
localization system. Render `active`/`inactive` with accessible text/badges;
color is not the only signal.

Parse `created_at`, normalize it consistently, and use an existing date
formatter. If none fits, add only a focused deterministic UTC display helper;
do not add a dependency or assume an Institution timezone.

### 5.5 Dashboard state model

Use one focused state/controller boundary representing at least:

```text
initial/loading
data
empty
error
```

An in-flight retry flag is allowed only for deterministic duplicate protection.

Rules:

- first eligible entry shows loading without removing shell/navigation;
- successful non-empty response shows data;
- zero Institutions with an empty recent list shows the Institution-empty
  state while preserving the real User metrics;
- non-zero metrics with no recent rows shows data plus partial-empty recent
  state;
- transport/server/decode failure shows a safe error with Retry;
- retry cannot fire twice while in flight;
- no exception leaves permanent spinner/disabled UI;
- failed new logical load is not displayed as stale fresh success;
- no data is stored in secure storage, preferences, disk, or cross-account
  cache;
- leaving/changing the session disposes or invalidates feature state.

No polling, timers, periodic refresh, background fetch, optimistic data, or
offline cache.

### 5.6 Institution-empty state

The dashboard Institution-empty state means:

```text
institutions.total    == 0
institutions.active   == 0
institutions.inactive == 0
recent_institutions   == []
```

User counts are not part of the empty-state predicate. In a real authenticated
session, `users.total` normally includes at least the current Platform Owner
and therefore may be greater than zero. Display `users.total` and
`users.active` exactly as returned.

The UI must:

- remain inside the Dashboard and shell;
- show all five truthful zero values or an equally explicit accessible zero
  summary;
- explain neutrally that no platform institutions/data exist yet;
- show no fabricated Institution, count, graph, activity, or warning;
- not expose a create form or mutation;
- not confuse Institution-empty success with error, denial, or loading.

Creation belongs to `S02-FE-005`; the Institutions destination already exists.

### 5.7 Data and partial-empty presentation

Show:

1. A clear Platform Dashboard page heading.
2. Five accessible KPI cards/tiles for the exact metrics.
3. A `Recent institutions` section using only the response array.

Visible recent fields are only:

```text
name
type
status
created_at
```

UUID may be retained as model identity but need not be shown. Never show or
infer contacts, address, description, creator, lifecycle timestamps, settings,
users, user counts, support, activity, or learning data.

Rules:

- preserve server ordering; do not sort locally;
- show no more than the returned maximum five;
- do not paginate, search, filter, or fetch more;
- rows do not open detail or expose edit/lifecycle/Admin actions;
- use a table or responsive structured list matching accepted UI conventions;
- practical compact/wide desktop layouts do not overflow;
- non-zero metrics with no rows shows `No recent institutions` only in that
  section.

Do not invent trends, percentages, charts, sparklines, growth, or health scores.

### 5.8 Loading presentation

Loading must:

- retain shell, selected Dashboard navigation, identity, and logout;
- communicate loading accessibly;
- show no prior-account data or fake values/rows;
- avoid overflow and uncontrolled repeated animations;
- not block logout/session invalidation.

A focused progress indicator or skeleton is acceptable. Skeletons must not be
announced as real values.

### 5.9 Error, Retry, and global failure behavior

Ordinary transport, `server_error`, or decode failures must:

- show one safe dashboard error state;
- show no stale cross-session data;
- provide one discoverable Retry;
- branch on typed failures/codes, not human `message` text;
- hide stack traces, Dio internals, raw JSON, SQL, tokens, and secret URLs;
- preserve shell/logout while the current session remains valid.

Global reconciliation remains authoritative:

| Condition | Required outcome |
|---|---|
| `401 authentication_required` | Invalidate/reconcile session and leave protected shell |
| `403 password_change_required` | Reconcile to mandatory password-change flow |
| `403 user_inactive` | Remove protected data and use accepted inactive handling |
| `403 institution_inactive` | Preserve accepted status handling; invent no Platform Owner Institution |
| `403 forbidden` | Safe protected-access outcome; no dashboard data |
| `422 validation_failed` | Safe client/API contract failure; request has no input |
| `500 server_error`, network, decode | Feature error with Retry for valid session |

Do not weaken or duplicate the accepted global interceptor/session controller.
A broad auth redesign is a blocker.

### 5.10 Session and account isolation

Required:

- logout/global invalidation removes dashboard data immediately;
- Platform Owner A data is never shown for Platform Owner B;
- Platform Owner data is never shown after switching to another role;
- stale Session A completion cannot overwrite Session B/logged-out state;
- late completion after disposal/logout is ignored safely;
- wrong-role/device entry remains blocked before usable dashboard UI;
- provider/repository overrides do not leak test/session state.

Do not key dashboard data by a client-selected Institution. Scope is global and
server-authorized.

### 5.11 Architecture and code organization

Follow feature-first architecture under:

```text
frontend/lib/features/platform_admin/
```

Required logical flow:

```text
Dashboard screen
  ↓
focused controller/notifier/provider
  ↓
dashboard repository contract
  ↓
repository implementation
  ↓
dashboard API data source
  ↓
existing configured API client
```

Rules:

- widgets do not call Dio or parse JSON;
- DTOs remain in data; domain/UI models contain only approved fields;
- dependencies are injectable/testable;
- no service locator or global mutable singleton;
- no god Platform controller spanning later tasks;
- no speculative abstractions for `S02-FE-003+`;
- reuse typed failure/envelope/client patterns;
- use focused names such as `PlatformDashboardDto`, repository, and controller;
- reuse theme/tokens/widgets only when they genuinely fit;
- no codegen/package addition unless already configured and required.

### 5.12 Expected file surface

Inspect accepted paths before choosing final names. Expected areas include:

| Path | Expected action |
|---|---|
| `frontend/lib/features/platform_admin/data/**` | Dashboard DTO, remote data source, repository implementation |
| `frontend/lib/features/platform_admin/domain/**` | Dashboard model/repository contract where conventions require |
| `frontend/lib/features/platform_admin/application/**` or accepted equivalent | Focused state/controller/provider |
| `frontend/lib/features/platform_admin/presentation/**` | Replace Dashboard placeholder only |
| `frontend/lib/core/network/**` | Minimal endpoint/envelope integration only if current conventions require |
| `frontend/test/features/platform_admin/**` | DTO/repository/controller/widget tests |
| `frontend/test/app/router/**` | Minimal regression only if route construction is touched |
| `tasks/frontend/stage-02/S02-FE-002-*.md` | Preserve; lifecycle update only after PASS |
| `tasks/STAGE_02_TASK_INDEX.md` | Truthful `S02-FE-002` update only |

Equivalent project-aligned paths are acceptable and must be reported.

Protected paths:

```text
backend/**
docker/**
docs/01–09
frontend/pubspec.yaml
frontend/pubspec.lock
```

Do not modify CI, platform build configuration, dependencies, the accepted
Institutions destination implementation, or later task files.

---

## 6. Required Automated Tests

Use current conventions and behavior-focused names. Zero executed tests is not
a pass.

### 6.1 DTO/mapping

- [ ] Exact non-empty and all-zero responses decode.
- [ ] All nine Institution types and both statuses map safely.
- [ ] RFC 3339 time parses/normalizes consistently.
- [ ] Missing/wrong/null core fields produce typed decode failure.
- [ ] String, floating, negative, or null counts are not silently accepted.
- [ ] Invalid status/time/core type produces safe failure.
- [ ] Additive unknown fields are ignored and never enter presentation.
- [ ] Protected contact/settings/user/learning fields are absent from models.

### 6.2 Data source/repository

- [ ] Exact GET path is used with no query/body/client scope.
- [ ] Existing configured client/envelope boundary is used.
- [ ] Success maps to the exact domain model.
- [ ] Stable auth/status/forbidden/validation/server/network/decode failures are
      preserved as typed behavior.
- [ ] Human `message` is not parsed for logic.
- [ ] No auto-retry, polling, or persistence occurs.

### 6.3 Controller/state

- [ ] Eligible entry begins deterministic loading.
- [ ] One initial load produces one request.
- [ ] Non-zero success produces data.
- [ ] Zero Institution counts with empty recent rows and non-zero real User
      counts produces Institution-empty.
- [ ] Non-zero metrics plus empty recent list produces partial empty.
- [ ] Failure produces error and stops loading.
- [ ] Retry produces exactly one new request.
- [ ] Duplicate in-flight Retry is prevented/harmless.
- [ ] Rebuild does not duplicate loading.
- [ ] Late Session A completion cannot overwrite Session B/logged-out state.
- [ ] Logout/invalidation clears/disposes data.

### 6.4 Widget states and layout

- [ ] Shell/navigation/identity/logout remain visible while feature loads or
      shows ordinary error.
- [ ] Loading shows no fake or old-account data.
- [ ] Exactly five KPI concepts show exact values.
- [ ] Active users is not labeled as online/login activity.
- [ ] Recent rows preserve server order and show only name/type/status/time.
- [ ] Status has text, not color only.
- [ ] UUID/private/internal/learning fields are absent.
- [ ] No chart/trend/optional metric/future action is present.
- [ ] Institution-empty shows truthful Institution zeros/no-data while
      preserving real User counts.
- [ ] Partial empty keeps KPIs and only empties recent section.
- [ ] Safe error hides internals and Retry works once.
- [ ] No overflow at `800 × 600` and `1440 × 900`.

### 6.5 Session, guard, and regression

- [ ] `401` invalidation removes protected shell/data.
- [ ] Password/status/forbidden failures never render dashboard data.
- [ ] Platform Owner A → B leaks no old data.
- [ ] Platform Owner → other role leaks no dashboard/shell data.
- [ ] Stale request cannot repopulate after logout/session switch.
- [ ] Unauthenticated, first-login, wrong-role, mobile, web, and unsupported
      route behavior remains as accepted in `S02-FE-001`.
- [ ] `/platform-owner/institutions` remains separate and is not implemented.
- [ ] Full Stage 1 and `S02-FE-001` frontend regression remains green.

---

## 7. Quality and Verification Commands

From `frontend/`, use the repository-pinned toolchain/wrappers and report exact
results:

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
flutter build windows --debug
flutter build apk --debug
```

Run focused tests first, then full tests. Do not silently skip builds.

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

Open every untracked implementation file. Inspect the whole staged, unstaged,
and untracked set for secrets, raw Dio/JSON in widgets, duplicate client/session
boundaries, client scope, duplicate requests, polling/cache, cross-account
state, protected-data leakage, fake/optional metrics, later scope, dependency
drift, generated noise, and unrelated changes.

---

## 8. Manual Smoke Checklist

Use the real Windows app, accepted Laravel/PostgreSQL runtime, and controlled
local/test data. Redact credentials/tokens.

### Real data

1. Prepare mixed active/inactive Institutions and Users, including more than
   five Institutions with controlled creation times.
2. Login as an active, password-complete Platform Owner.
3. Confirm `/platform-owner` opens inside the accepted shell.
4. Confirm one real dashboard request with no query/body.
5. Verify five KPIs against controlled backend facts.
6. Verify recent Institutions are the exact server-returned five in order.
7. Verify readable type/status/time and no protected fields.
8. Resize to practical compact desktop and verify no overflow.
9. Navigate to Institutions and back; verify no unrelated API/scope appears.

### Failure, Retry, isolation

1. Safely make the request fail without production-code test hooks.
2. Confirm safe error and absence of raw internals.
3. Restore backend, Retry once, and confirm one successful new request.
4. Verify invalid-token reconciliation removes protected data.
5. Logout while loading/after data and confirm immediate removal.
6. Login as another Platform Owner and then another role; confirm no old data.

Complete-zero presentation is mandatory in deterministic widget tests and may
also be smoked when a safe empty controlled backend is available. Report any
unavailable manual item as `NOT RUN` with exact reason.

---

## 9. Acceptance Criteria

- [ ] Dependency/Git gate is proven.
- [ ] Work occurs only on `task/s02-fe-002-platform-dashboard`.
- [ ] Accepted shell contains the real `/platform-owner` dashboard body.
- [ ] Exactly one approved endpoint is called with no query/body.
- [ ] Typed DTO/domain/repository/controller boundaries follow architecture.
- [ ] Five metrics come directly from the response with exact meaning.
- [ ] Recent Institutions expose only approved fields and preserve order.
- [ ] Loading, data, Institution-empty, partial-empty, error, and Retry are
      tested.
- [ ] Global auth/password/status/session behavior is preserved.
- [ ] Logout/account switch/stale completion leaks no data.
- [ ] No fake/optional/later metric or future-task behavior exists.
- [ ] No backend/docs/Docker/schema/dependency/CI change exists.
- [ ] Focused/full tests, analyze, format, Windows build, and APK build pass.
- [ ] Manual smoke is truthful.
- [ ] Phase 2 has zero unresolved P1/P2 findings.
- [ ] Final `ACCEPTED` occurs only after PR delivery, merge, and clean sync.

---

## 10. Explicit Non-Goals

- Institution list/search/filter/sort/pagination (`S02-FE-003`).
- Institution detail/basic usage (`S02-FE-004`).
- Create Institution (`S02-FE-005`).
- Edit Institution (`S02-FE-006`).
- Institution lifecycle (`S02-FE-007`).
- Institution Admin list/create (`S02-FE-008`).
- Institution Admin edit/lifecycle (`S02-FE-009`).
- Stage 2 real-stack verification (`S02-INT-001`).
- `/api/v1/platform/statistics` or a statistics page.
- Charts, trends, rankings, comparisons, predictions, export, BI.
- Support/issues/attention/settings/billing/licensing/storage/audit.
- User identities or learning analytics.
- Polling/cache/offline/WebSocket/background work.
- New routes, mobile/web Platform Owner, localization/design overhaul.
- Packages, backend, schema, Docker, CI, or locked-doc changes.

---

## 11. Relevant Business and Security Rules

1. Only an active, password-complete desktop `platform_owner` uses the screen.
2. Backend authorization remains authoritative.
3. Client sends no role/Institution scope.
4. Platform Owner is not a learning-data bypass.
5. Aggregates do not authorize user record retrieval.
6. Active users means `users.is_active`, not online/effective eligibility.
7. Recent Institutions are a bounded server summary.
8. Client computation/filtering cannot redefine the report.
9. Errors reveal no protected/internal data.
10. Session change invalidates presentation state.
11. The request is read-only and changes no timestamp/token.
12. Daily classroom work and advanced analytics remain outside scope.

---

## 12. Authoritative References

| Source | Exact section | Requirement |
|---|---|---|
| `docs/01-business-overview.md` | Platform Owner/multi-Institution/focused MVP overview | Platform control without daily learning interference |
| `docs/02-user-roles.md` | `1. Platform Owner / Super Admin`; access/device rules | Desktop authority and boundaries |
| `docs/03-features.md` | `2. Platform Owner / Super Admin Features` | Dashboard and basic Institution/User statistics |
| `docs/04-user-flows.md` | `2. Platform Owner / Super Admin Flow`; dashboard/statistics/access/boundary flows | Real overview and unauthorized blocking |
| `docs/05-business-rules.md` | `BR-INST-019`–`021`; `BR-ROLE-004`–`009`; `BR-ACL-001`–`005`, `014`–`016` | Platform scope and security |
| `docs/06-roadmap.md` | `2.6`; `7. Stage 2`; `Super Admin Desktop Dashboard`; boundary | Desktop Stage 2 metrics and exclusions |
| `docs/07-architecture.md` | `20`, `21`, `22.1`, `28`, `32.4–32.6`, `35` | Flutter layers, shell, read model, tests, security |
| `docs/09-api-contracts.md` | `2`, `4`, `5`, `7.1`, `33` | Exact transport, session, endpoint, response, scope |
| `AGENTS.md` and `frontend/AGENTS.md` | Applicable full rules | Workflow, typed layers/states, tests, safe delivery |
| accepted `S02-BE-005` | Complete contract/evidence | Narrow backend dashboard semantics |
| accepted `S02-FE-001` | Complete contract/evidence | Shell, route, guard, identity, logout boundary |
| `tasks/STAGE_02_TASK_INDEX.md` | `S02-FE-002` and successors | Exact sequence and non-goals |

Task-level empty/partial-empty, additive-field, and Retry details narrow
implementation ambiguity without changing locked product behavior.

---

## 13. Stop Conditions

Stop with `FINAL STATUS: BLOCKED` if:

- Stage 1 or required Stage 2 predecessors are not accepted/delivered;
- `S02-BE-005` response differs materially;
- Stage 2 index is missing/conflicting;
- `main` cannot synchronize or `origin` is unexpected;
- unrelated dirty work exists;
- accepted shell/client/session/failure/test foundations are missing/broken;
- locked docs conflict;
- implementation requires protected paths, package, broad auth/network/shell
  redesign, or later-task scope;
- safe account isolation/typed failure behavior cannot be preserved;
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

Do not start `S02-FE-003`.

---

## 14. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git preflight

Complete Section 5.1, create/switch to the exact task branch, carry the two
approved files, and do not commit/push.

### Phase 1 — Implementation

Implement only `S02-FE-002`. Run focused/full tests, analyze, format, builds,
diff/scope/security review, and manual smoke. Do not commit, push, open a PR,
merge, or mark accepted.

### Phase 2 — Read-only acceptance gate

Re-read this task, instructions, referenced locked sections, predecessors, all
changed/untracked code, tests/builds/smoke, request-count, failure, isolation,
and protected-data evidence.

During Phase 2 make no edits; do not auto-fix, format-write, generate, stage,
unstage, commit, push, open/merge a PR, or update lifecycle state.

Severity:

```text
P1 = auth/role/device/session/account-isolation/secret/protected-data issue
P2 = material API/state/UI/architecture/test/build/scope/contract issue
P3 = non-blocking observation
```

PASS requires zero unresolved P1/P2 and complete evidence. Otherwise return
`FINAL STATUS: NOT ACCEPTED`, stop, and do not self-fix.

### Phase 3 — Post-acceptance delivery

Only after Phase 2 PASS:

1. Set this task to `Accepted`.
2. Update only truthful `S02-FE-002` index state to Accepted/review PASS;
   delivery finalizes after merge.
3. Apply only required task lifecycle bookkeeping.
4. Re-run final tests, builds, diff/scope/secret checks.
5. Stage only approved files.
6. Commit:

   ```text
   feat(platform): connect owner dashboard data
   ```

   Body:

   ```text
   Task: S02-FE-002
   ```

7. Push `task/s02-fe-002-platform-dashboard`, open PR to `main`, and do not
   bypass checks.
8. Merge only when safe/green.
9. Fast-forward-sync local `main` and prove clean `main == origin/main`.

Only then return `FINAL STATUS: ACCEPTED`. Do not start `S02-FE-003`.

---

## 15. Required Codex Final Report

Return:

1. Final status and dependency/Git commit evidence.
2. Implementation/changed files and exact request/envelope evidence.
3. Typed architecture and request-count evidence.
4. All view-state/KPI/recent-field evidence.
5. Auth/status/session/account-isolation evidence.
6. No-fake/no-optional/no-later-scope evidence.
7. Focused/full tests, analyze, format, Windows/APK builds.
8. Diff/scope/package/secret/untracked checks.
9. Manual smoke and exact `NOT RUN` items.
10. Phase 2 findings/decision.
11. Commit/branch/PR/merge/final-sync evidence.
12. Remaining blockers/deviations.

Do not create or start `S02-FE-003`.
