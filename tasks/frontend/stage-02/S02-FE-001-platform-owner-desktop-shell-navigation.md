# Codex Task: Platform Owner Desktop Shell and Navigation

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-FE-001` |
| Status | `Accepted` |
| Approved on | `2026-08-10` |
| Stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Frontend / Platform Owner desktop shell and navigation foundation` |
| Priority | `High` |
| Depends on | `S02-BE-001` through `S02-BE-007` accepted, delivered, and present on current `origin/main` |
| Sequence next | `S02-FE-002` |
| Foundation for | `S02-FE-002` through `S02-FE-009` |
| Repository | `https://github.com/Shoxrux2017/testlabuz.git` |
| Target branch | `task/s02-fe-001-platform-owner-shell-navigation` |
| Execution model | One focused implementation task followed by read-only acceptance and safe GitHub delivery |

---

## 2. Goal

Replace the temporary Stage 1 Platform Owner entry presentation with the real
Stage 2 desktop management shell and its route-aware navigation foundation.

The accepted result must provide these exact Platform Owner locations:

```text
/platform-owner
/platform-owner/institutions
```

The shell must:

- remain available only to an authenticated, active, password-complete
  `platform_owner` on an approved desktop device surface;
- display a stable desktop navigation area with exactly two Stage 2
  destinations: `Dashboard` and `Institutions`;
- keep `/platform-owner` as the canonical Platform Owner entry and dashboard
  location;
- support direct entry, refresh, navigation, and back/forward behavior for
  `/platform-owner/institutions`;
- show the currently authenticated Platform Owner identity and a safe logout
  action;
- preserve the accepted first-login, role/device, logout, global session
  invalidation, and account-switch isolation behavior from Stage 1;
- expose only honest, non-data placeholder bodies for the two destinations so
  later tasks can replace them without rebuilding the shell.

This task establishes navigation and layout only. It must not call the Stage 2
Platform APIs, display invented metrics or institution rows, or implement any
dashboard, institution-management, form, or lifecycle behavior owned by later
tasks.

### Scope boundary

This task owns only:

- Platform Owner route-family support;
- the Platform Owner desktop shell;
- Dashboard/Institutions navigation;
- route selection and direct-route safety;
- current-session identity presentation;
- logout integration;
- shell-level responsive presentation and focused tests.

It does not:

- fetch or render Platform dashboard aggregates;
- fetch, search, filter, sort, or paginate institutions;
- render institution detail or usage data;
- create or edit an Institution;
- activate or deactivate an Institution;
- list, create, edit, activate, or deactivate Institution Admin accounts;
- add platform settings, support, issue, statistics, billing, licensing, audit,
  notification, or impersonation screens;
- add Institution Admin, Teacher, Student, or Parent product navigation;
- add web support or change the approved role/device matrix;
- add or change backend endpoints;
- revise locked `docs/01–09`.

---

## 3. Current Accepted Context

Treat current `origin/main` at execution time as the implementation source of
truth. The preparation snapshot below exists only to make the task reviewable;
Codex must independently re-check the repository.

Verified preparation baseline:

```text
origin/main commit:
b6c840a9dc935f6a9b2a87a63e5fc99352782ed8
```

The closed Stage 1 frontend provides:

- Flutter with Riverpod, GoRouter, Dio, and secure token storage;
- one `AuthSessionController` and server-restored `/api/v1/auth/me` identity;
- `AuthUser.role` and `mustChangePassword` as current-session routing inputs;
- injectable `AppDeviceSurface` resolution;
- approved desktop/mobile/unsupported device mapping;
- canonical Stage 1 Platform Owner route `/platform-owner`;
- direct-route role/device guards;
- safe `/login`, `/change-password`, and `/unsupported-device` behavior;
- immediate local shell removal on logout and backend logout failure safety;
- global authentication invalidation and account-switch isolation;
- a temporary `RoleEntryScreen` for each role;
- Material 3 application theme and Flutter test foundation.

At preparation time, the important accepted paths include:

```text
frontend/lib/app/app.dart
frontend/lib/app/device/app_device_surface.dart
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
frontend/lib/features/auth/application/auth_session_controller.dart
frontend/lib/features/auth/application/auth_session_state.dart
frontend/lib/features/entry/domain/entry_route_resolver.dart
frontend/lib/features/entry/presentation/role_entry_screen.dart
```

Relevant baseline behavior:

```text
Platform Owner + desktop → /platform-owner
Platform Owner + mobile  → /unsupported-device
Platform Owner + web     → /unsupported-device
```

The current Stage 1 router redirects a password-complete user to one exact
canonical entry path. This task must extend that logic narrowly so an eligible
Platform Owner may remain anywhere inside the approved Platform Owner route
family. It must not turn prefix matching into a cross-role or arbitrary-path
bypass.

Accepted Stage 2 backend predecessors provide the real APIs used by later
frontend tasks:

```text
GET   /api/v1/platform/dashboard
GET   /api/v1/platform/institutions
POST  /api/v1/platform/institutions
GET   /api/v1/platform/institutions/{institution}
PATCH /api/v1/platform/institutions/{institution}
POST  /api/v1/platform/institutions/{institution}/activate
POST  /api/v1/platform/institutions/{institution}/deactivate
GET   /api/v1/platform/institutions/{institution}/admins
POST  /api/v1/platform/institutions/{institution}/admins
PATCH /api/v1/platform/institution-admins/{user}
POST  /api/v1/platform/institution-admins/{user}/activate
POST  /api/v1/platform/institution-admins/{user}/deactivate
```

Those endpoints are context only. This task must make **zero** Stage 2 API
requests and must not introduce Platform DTOs, repositories, or data sources
before their owning frontend tasks.

---

## 4. Dependency and Stage-Control Gate

Before implementation, verify:

1. Stage 1 is `Closed` and Stage DoD is `PASS`.
2. `S02-BE-001` through `S02-BE-007` are each `Accepted`, reviewed `PASS`,
   delivered, and present on current `origin/main`.
3. `tasks/STAGE_02_TASK_INDEX.md` exists and matches the approved 17-task
   decomposition.
4. This detailed task exists at:

   ```text
   tasks/frontend/stage-02/S02-FE-001-platform-owner-desktop-shell-navigation.md
   ```

5. Its status is `Approved` before implementation.
6. The accepted Stage 1 session, route, device, and isolation foundations are
   still present and passing.
7. No conflicting Stage 2 Platform Owner shell or real frontend data flow
   already exists.

If a dependency is missing, local `main` differs from `origin/main`, or current
repository evidence materially contradicts this contract, stop and report:

```text
FINAL STATUS: BLOCKED
```

Include exact evidence. Do not repair predecessor scope, recreate accepted
backend work, or absorb `S02-FE-002+`.

This task may update only the truthful `S02-FE-001` lifecycle state in the
Stage 2 index. It must not create, approve, implement, or change the state of
`S02-FE-002` or any later task.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

Before editing:

1. Read root `AGENTS.md`, `frontend/AGENTS.md`, and any nearer instructions
   completely.
2. Read `tasks/README.md`, `tasks/STAGE_02_TASK_INDEX.md`, and this task.
3. Read accepted Stage 1 frontend task/closure evidence relevant to session,
   routing, device surfaces, logout, and isolation.
4. Read accepted `S02-BE-001` through `S02-BE-007` task/delivery evidence only
   as needed to prove the Stage 2 dependency gate.
5. Read only locked specification sections referenced in Section 11.
6. Inspect actual router, route constants, entry resolver/screens, session
   state/controller, device resolver, theme, and tests before designing edits.
7. Run safe synchronization checks:

   ```text
   git fetch origin
   git switch main
   git pull --ff-only origin main
   git status --short
   git rev-parse HEAD
   git rev-parse origin/main
   git remote -v
   ```

8. Confirm local `main == origin/main`, the remote is the approved repository,
   and the only permitted worktree changes are exactly these two approved
   preparation files:

   ```text
   tasks/frontend/stage-02/S02-FE-001-platform-owner-desktop-shell-navigation.md
   tasks/frontend/stage-02/S02-FE-001-CODEX-PROMPT.md
   ```

   No other modified, staged, deleted, renamed, or untracked path is allowed.
   Neither preparation file may be committed on `main`.
9. Create or switch to exactly:

   ```text
   task/s02-fe-001-platform-owner-shell-navigation
   ```

10. Carry the two approved files to the task branch if needed and verify that
    committed `main` was not changed.
11. Use the repository-pinned Flutter/Dart toolchain and dependency lock.
12. Do not commit or push before the read-only acceptance gate passes.

Unrelated or unexplained changes are a blocker. Preserve user work and never
reset, discard, overwrite, or destructively clean it.

### 5.2 Exact route topology

Preserve and use these exact public route paths:

```text
/platform-owner
/platform-owner/institutions
```

Required meaning:

| Route | Destination in this task |
|---|---|
| `/platform-owner` | Platform Owner shell with honest Dashboard placeholder body |
| `/platform-owner/institutions` | Same shell with honest Institutions placeholder body |

Rules:

- `/platform-owner` remains the canonical post-login Platform Owner entry.
- Do not rename the accepted route to `/platform-admin` or create a second
  competing Platform Owner root.
- Both destinations must be represented by route constants/names; do not
  scatter string literals through widgets and tests.
- Use GoRouter nested-shell routing appropriate to the existing architecture.
- The shell must remain mounted when navigating between its two destinations
  so shell-owned state is not unnecessarily recreated.
- Browser/deep-link style direct navigation and URI-driven selection must work
  even though web is not an approved device surface in this MVP.
- Query strings or fragments must not be used as role authority.
- Unknown `/platform-owner/**` paths must not render a valid destination or
  leak another role shell. Use the existing router's safe not-found behavior or
  a focused, non-sensitive route-unavailable surface if required by the actual
  router architecture.

Do not add routes for settings, support, statistics, billing, Institution
Admins, create/edit forms, or lifecycle actions in this task.

### 5.3 Authentication, first-login, role, and device guards

Preserve the accepted guard precedence for both Platform Owner routes:

```text
session bootstrap/restore
→ authentication
→ mandatory password change
→ approved role/device entry
→ exact role-owned destination
```

Required outcomes:

| Current state | Attempted Platform Owner route | Expected result |
|---|---|---|
| Bootstrap initial/loading/failure | Either | Existing technical bootstrap surface |
| Unauthenticated | Either | `/login` |
| Any authenticated role with `must_change_password=true` | Either | `/change-password` |
| `platform_owner` on desktop | Either exact route | Requested Platform Owner destination |
| `platform_owner` on mobile/web/unsupported | Either | `/unsupported-device` |
| Other role on supported surface | Either | That user's accepted canonical role entry |
| Other role on unsupported surface | Either | `/unsupported-device` |

Security and isolation rules:

- The route family is not authorized by path prefix alone.
- Use only the current authenticated `AuthUser` and injected device surface.
- Do not persist role, selected Institution, or Platform authority as an
  independent long-term source of truth.
- Platform Owner is not a universal bypass into Institution Admin, Teacher,
  Student, Parent, or ordinary tenant routes.
- Direct entry to `/platform-owner/institutions` must pass the same guards as
  `/platform-owner`.
- A route-family helper must use a segment-safe/exact definition. A string such
  as `/platform-owner-evil` must never count as a Platform Owner child route.
- Logout or global session invalidation must remove the shell immediately.
- A stale prior session completion must not restore this shell for a newer
  user.

Backend authorization remains mandatory for every future API call. This shell
is a UX boundary only.

### 5.4 Desktop shell presentation contract

Create one focused `PlatformOwnerShell` (or equivalently clear project-aligned
name) under the accepted `features/platform_admin/` feature area.

The shell must contain:

- `TestLabUz` product identity;
- a stable navigation region;
- exactly two navigation destinations:
  - `Dashboard`;
  - `Institutions`;
- a page-title/header region derived from the current exact destination;
- the current Platform Owner's `fullName` from the live session;
- a clearly discoverable `Sign out` action;
- a child content region supplied by GoRouter.

The shell must not show a fake Institution for Platform Owner. It must not show
passwords, tokens, login identifiers, role authority fields, backend debug
data, or sensitive/session internals.

Use the accepted Material 3 theme and existing UI conventions. Do not perform
a design-system or branding overhaul. Do not add a package for layout,
navigation, icons, or state.

Desktop layout requirements:

- provide a persistent left-side Material navigation rail/sidebar;
- an expanded rail may be used when adequate width exists and a compact rail
  may be used on narrower desktop windows;
- viewport width may influence **presentation only**, never role/device
  authorization;
- both modes must retain clear accessible labels/tooltips;
- the shell must not overflow at a practical narrow desktop test size such as
  `800 × 600` logical pixels;
- wide and compact layout must navigate to the same exact routes and enforce
  the same guards;
- default Flutter keyboard/focus behavior must remain usable; do not suppress
  semantics or focus without replacement.

Keep reusable layout constants/tokens focused and named. Do not scatter magic
breakpoints, spacing, colors, or route strings across the feature.

### 5.5 Navigation behavior

Navigation must be URI-driven and deterministic:

- `/platform-owner` selects `Dashboard`;
- `/platform-owner/institutions` selects `Institutions`;
- selecting Dashboard navigates to `/platform-owner`;
- selecting Institutions navigates to `/platform-owner/institutions`;
- reselecting the current destination does not create a navigation loop;
- browser/back-style history returns to the previous destination correctly;
- rebuilding the shell from Riverpod/session changes does not reset the URI to
  Dashboard;
- no destination is selected from a stale global index after direct entry;
- no role or permission decision comes from the selected navigation index.

Navigation labels and icons are presentation. Route constants are the routing
authority.

### 5.6 Honest destination placeholders

This task may add the minimum route bodies needed to prove the shell:

```text
Dashboard placeholder
Institutions placeholder
```

Each body must:

- clearly identify its destination;
- use no fake KPI, count, chart, table row, Institution, status, activity,
  loading result, or error result;
- make no HTTP request;
- expose no create/edit/activate/deactivate/Admin action;
- remain easy for `S02-FE-002` or `S02-FE-003` to replace without changing the
  shell contract.

Do not implement generic loading/empty/error state machinery merely for these
static placeholders. Those states belong to the real data-driven screen tasks.

### 5.7 Current-session identity and logout

The shell must read identity only from the accepted current session provider.

Required behavior:

- show the current Platform Owner `fullName`;
- do not copy the user into a second global session source;
- do not cache identity inside the router or shell across account changes;
- logout uses the accepted `AuthSessionController.signOut()` flow;
- a logout trigger cannot expose the old shell while transport completes;
- repeated logout triggers are prevented or harmless under accepted session
  behavior;
- backend logout failure must still leave local protected content removed;
- a new Platform Owner login displays only the new user's name;
- a new non-Platform-Owner login cannot see the prior shell or identity;
- global authentication invalidation removes shell content and routes to
  `/login`.

The shell must not introduce feature-specific session persistence.

### 5.8 Architecture and state boundary

Follow the accepted feature-first architecture:

```text
frontend/lib/features/platform_admin/presentation/...
```

This task is presentation/routing only. Therefore:

- no Platform Admin repository, DTO, API data source, or controller is needed;
- presentation must not call Dio;
- reuse the existing auth/session/device providers;
- use GoRouter as the only router;
- use Riverpod only where the existing dependency/session boundary requires
  it;
- do not create a second auth, router, navigation framework, or service
  locator;
- keep shell widgets focused and avoid a god widget with future-feature flags;
- do not prebuild generic abstractions for later stages.

### 5.9 API and error boundary

No Stage 2 API call is allowed in this task.

The shell must not:

- call `/api/v1/platform/dashboard`;
- call `/api/v1/platform/institutions` or any mutation endpoint;
- parse backend messages to choose routes;
- create fake network success/error states;
- swallow accepted global auth invalidation;
- suppress future backend `401`/`403` handling because client guards exist.

Accepted auth bootstrap and global session failure behavior must remain
unchanged unless a minimal, tested integration adjustment is required for the
new nested routes.

### 5.10 Expected file surface

Expected high-value changes may include:

| Path | Expected action |
|---|---|
| `frontend/lib/app/router/app_route_paths.dart` | Add exact Institutions child path/name and safe route-family helpers |
| `frontend/lib/app/router/app_router.dart` | Introduce guarded nested Platform Owner shell routing without weakening other roles |
| `frontend/lib/features/entry/domain/entry_route_resolver.dart` | Minimal integration only if required; canonical Platform Owner entry remains `/platform-owner` |
| `frontend/lib/features/entry/presentation/role_entry_screen.dart` | Remove/stop using only the Platform Owner temporary entry presentation; preserve other role entry screens |
| `frontend/lib/features/platform_admin/presentation/**` | Add focused shell and honest destination placeholders |
| `frontend/test/app/router/**` | Add nested-route guard and direct-entry coverage |
| `frontend/test/features/platform_admin/**` | Add shell/navigation/layout/logout/isolation widget tests |
| `tasks/frontend/stage-02/S02-FE-001-*.md` | Preserve approved contract/prompt; update lifecycle only after PASS |
| `tasks/STAGE_02_TASK_INDEX.md` | Truthful `S02-FE-001` lifecycle update only |

The actual implementation may use equivalent paths that match the accepted
existing architecture. Explain material deviations in the final report.

Forbidden change areas:

```text
backend/
docker/
docs/01–09
```

Do not modify `frontend/pubspec.yaml` or `frontend/pubspec.lock` unless a
material blocker is reported and separately approved. No new package is
expected.

---

## 6. Required Automated Tests

Use existing frontend test conventions and add focused coverage for all
behavior below.

### 6.1 Route constants and exact matching

Prove:

```text
Dashboard    → /platform-owner
Institutions → /platform-owner/institutions
```

Also prove segment-safe matching does not accept unrelated prefixes such as:

```text
/platform-owner-extra
```

### 6.2 Platform Owner desktop direct-entry matrix

For authenticated, password-complete Platform Owner on desktop:

```text
/platform-owner              → Dashboard in Platform Owner shell
/platform-owner/institutions → Institutions in same shell
```

Prove the correct destination is selected after direct entry and rebuild.

### 6.3 Guard-precedence matrix for both routes

For **each** Platform Owner route, test:

- unauthenticated → `/login`;
- every role with `must_change_password=true` → `/change-password`;
- Platform Owner mobile → `/unsupported-device`;
- Platform Owner web/unsupported → `/unsupported-device`;
- Institution Admin desktop → `/institution-admin`;
- Teacher desktop/mobile → `/teacher`;
- Student desktop/mobile → `/student`;
- Parent mobile → `/parent`;
- Parent desktop → `/unsupported-device`.

Wrong roles must never render the Platform Owner shell while redirecting.

### 6.4 Shell content

Prove the shell shows:

- `TestLabUz`;
- exactly `Dashboard` and `Institutions` destinations;
- correct selected destination;
- correct page title/body;
- current Platform Owner full name;
- logout action;
- no fake Institution identity;
- no later-task navigation or actions.

### 6.5 Navigation behavior

Prove:

- Dashboard → Institutions updates URI and selected destination;
- Institutions → Dashboard updates URI and selected destination;
- reselecting current destination remains stable;
- back/navigation restoration returns the prior selection;
- direct Institutions entry is not reset to Dashboard after provider/router
  refresh;
- the same shell structure owns both destinations.

### 6.6 Compact and wide desktop presentation

Widget-test practical desktop sizes, including at least:

```text
800 × 600
1440 × 900
```

Prove:

- no layout overflow/exceptions;
- both destinations remain discoverable/accessibly labeled;
- presentation may compact/expand without changing route authorization or
  destinations.

Do not use viewport width to change `AppDeviceSurface` authorization.

### 6.7 Logout and session invalidation

While each destination is visible, prove:

```text
logout
→ old shell removed immediately
→ /login
→ old Platform Owner identity absent
```

Also prove a global `authentication_required` invalidation removes the shell
and that backend logout transport failure cannot restore it.

### 6.8 Account-switch and stale-session isolation

At minimum:

```text
Platform Owner A /institutions
→ logout
→ Platform Owner B
→ B dashboard/shell only
→ A identity absent
```

and:

```text
Platform Owner A
→ logout
→ Institution Admin B
→ /institution-admin
→ no Platform Owner shell/A identity
```

Preserve accepted stale-bootstrap/session-generation regression coverage.

### 6.9 No API or future-feature side effects

Prove shell/destination rendering:

- makes no Platform Stage 2 HTTP request;
- exposes no fake dashboard or Institution data;
- exposes no create/edit/lifecycle/Admin controls;
- introduces no extra route destination.

Use architecture/static review where a direct test would be artificial.

### 6.10 Full regression

All accepted FE-001 through FE-004 tests must remain green, including:

- auth bootstrap and token isolation;
- login/password-change UX;
- all 10 role/device mappings;
- wrong-role direct-route denial;
- logout and session invalidation;
- same-role/cross-role account switching;
- stale-session protection.

Zero executed tests is not a pass.

---

## 7. Quality and Verification Commands

From `frontend/`, use the repository-pinned toolchain and run:

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
flutter build windows --debug
flutter build apk --debug
```

If the repository provides an equivalent wrapper or pinned Flutter command,
use it and report the exact command. Do not silently skip a required platform
build; report a genuine environment blocker.

Before Phase 2, from repository root run effective scope/diff checks:

```text
git status --short
git diff --check
git diff --stat
git diff
git diff --cached --check
git diff --cached --stat
git diff --cached
git ls-files --others --exclude-standard
git status --short -- backend docker docs
git diff HEAD -- backend docker docs
git diff --cached -- backend docker docs
git diff HEAD -- frontend/pubspec.yaml frontend/pubspec.lock
git diff --cached -- frontend/pubspec.yaml frontend/pubspec.lock
```

Every untracked implementation file listed by `git ls-files --others` must be
opened and reviewed completely during acceptance. A diff that omits untracked
files is not complete evidence.

Inspect all changed content for:

- credentials, tokens, passwords, private keys, certificates, `.env` data, or
  sensitive fixture values;
- cached role/identity authority;
- unsafe route-prefix matching;
- Platform Owner cross-role bypass;
- viewport-width authorization;
- fake dashboard/Institution data;
- premature API/DTO/repository implementation;
- backend/docs/Docker changes;
- unapproved dependencies;
- debug logging or production test shortcuts.

---

## 8. Manual Smoke Checklist

### Windows desktop — Platform Owner

Verify:

1. Login routes to `/platform-owner`.
2. Dashboard navigation is selected.
3. Shell shows current Platform Owner name and no fake Institution.
4. Institutions navigation opens `/platform-owner/institutions`.
5. Refresh/direct entry preserves Institutions selection.
6. Back navigation returns Dashboard correctly.
7. Narrowing the window keeps both destinations usable without overflow.
8. No Platform API request is triggered by either placeholder.
9. Logout removes the shell and routes to `/login`.

### Guard smoke

Verify at least:

```text
unauthenticated /platform-owner/institutions → /login
password-change-required user               → /change-password
Institution Admin desktop                   → /institution-admin
Platform Owner mobile                       → /unsupported-device
```

### Account-switch smoke

Verify:

```text
Platform Owner A
→ /platform-owner/institutions
→ logout
→ different user B
→ B's correct route and identity only
```

Do not store smoke credentials, tokens, or account secrets in repository
files, test reports, screenshots, logs, or task evidence.

---

## 9. Acceptance Criteria

- [ ] Stage 1 is closed and Stage DoD is PASS.
- [ ] `S02-BE-001` through `S02-BE-007` are accepted and delivered.
- [ ] Work occurs on `task/s02-fe-001-platform-owner-shell-navigation`.
- [ ] Existing `/platform-owner` remains the canonical entry/dashboard route.
- [ ] `/platform-owner/institutions` exists.
- [ ] Both routes render through one Platform Owner desktop shell.
- [ ] Navigation contains exactly Dashboard and Institutions.
- [ ] Selected navigation state is derived from the current URI.
- [ ] Direct entry, refresh, reselect, and back behavior are deterministic.
- [ ] Unauthenticated access resolves to `/login`.
- [ ] First-login password gate takes precedence for every role/device.
- [ ] Platform Owner mobile/web remains unsupported.
- [ ] Wrong roles never render the Platform Owner shell.
- [ ] Segment-safe route-family matching prevents prefix bypass.
- [ ] Shell shows current Platform Owner full name and no fake Institution.
- [ ] Logout uses the existing session controller and removes shell locally.
- [ ] Global session invalidation removes the shell.
- [ ] Same-role and cross-role account switches expose no prior identity/state.
- [ ] Shell works without overflow at practical compact and wide desktop sizes.
- [ ] Viewport width affects presentation only, never device authorization.
- [ ] Placeholder bodies contain no fake data or future-task actions.
- [ ] No Stage 2 Platform API request is made.
- [ ] No Platform DTO/repository/data source is introduced.
- [ ] Other Stage 1 role entry routes remain functional.
- [ ] No backend, Docker, or locked-doc change exists.
- [ ] No unapproved dependency is added.
- [ ] Focused router/widget tests pass.
- [ ] Full Flutter test suite passes.
- [ ] `flutter analyze` passes.
- [ ] format check passes.
- [ ] Windows debug build passes.
- [ ] Android debug build passes.
- [ ] Manual smoke passes.
- [ ] Read-only acceptance has zero unresolved P1/P2 findings.
- [ ] Safe GitHub delivery completes before final `ACCEPTED`.

---

## 10. Explicit Non-Goals

Do not implement:

- real Platform dashboard content or `/platform/dashboard` integration;
- Institution list/data source/repository/DTO/table/filter/pagination UI;
- Institution detail or usage screen;
- Create/Edit Institution forms;
- Institution activate/deactivate actions or confirmations;
- Institution Admin list/create/update/lifecycle UI;
- Platform settings, statistics, support, issue, billing, licensing, storage,
  subscription, audit, impersonation, or notification navigation;
- Institution Admin/Teacher/Student/Parent shell redesign;
- cross-role shared product shell abstraction for hypothetical reuse;
- web support;
- localization system addition;
- theme/design-system overhaul;
- backend/API/schema/Docker change;
- new dependency;
- changes to locked `docs/01–09`;
- `S02-FE-002` or any later task.

---

## 11. Authoritative References

| Source | Exact section | Requirement |
|---|---|---|
| `docs/02-user-roles.md` | `1. Platform Owner / Super Admin`; device boundary summary | Platform-wide role, desktop use, institution management without daily educational interference |
| `docs/03-features.md` | `2. Platform Owner / Super Admin Features` | Platform dashboard and Institution management are primary desktop features |
| `docs/04-user-flows.md` | `2. Platform Owner / Super Admin Flow`; dashboard/institution/access-restriction flows | Login opens dashboard; desktop navigation to Institution management; unauthorized users blocked |
| `docs/06-roadmap.md` | `2.6 Desktop and Mobile Scope`; `7. Stage 2 — Multi-Institution Platform Management` | Platform Owner desktop-only boundary and Stage 2 scope |
| `docs/07-architecture.md` | `20. Flutter Application Architecture` | Riverpod/GoRouter/Dio feature-first boundaries |
| `docs/07-architecture.md` | `21. Flutter Navigation Architecture` | Role-aware routes, guards, and desktop shells |
| `docs/07-architecture.md` | `22.1 Platform Owner / Super Admin` | Dashboard/Institutions capabilities and no routine learning editing |
| `docs/09-api-contracts.md` | `4. Current User / Session Contract` | `/auth/me` is current role/shell authority |
| `docs/09-api-contracts.md` | `7. Super Admin Institution APIs` | Future Platform data endpoints; no client role authority |
| `AGENTS.md` | Working model, security, testing, scope, quality, and task completion sections | One focused task, server authority, quality gates, and safe delivery |
| `frontend/AGENTS.md` | Authentication/route guards, device boundaries, routing, state, errors, tests, package, clean-code sections | Frontend security, architecture, and quality rules |
| `tasks/STAGE_01_TASK_INDEX.md` | `S01-FE-004`; stage verification and closure | Accepted role/device routing and session isolation foundation |
| `tasks/STAGE_02_TASK_INDEX.md` | `S02-FE-001` approved row and ordered successors | Exact stage order and scope boundary |

Task-level route strings and placeholder boundaries in this contract narrow
the locked conceptual navigation architecture without changing product
behavior.

---

## 12. Stop Conditions

Stop and report `FINAL STATUS: BLOCKED` before implementation if:

- Stage 1 is not closed;
- any `S02-BE-001` through `S02-BE-007` dependency is not accepted/delivered;
- Stage 2 index is missing or conflicts with the approved decomposition;
- local `main` cannot safely synchronize to `origin/main`;
- the remote is not the approved TestLabUz repository;
- unrelated dirty/staged/untracked work exists;
- the two preparation files are not the only allowed pre-task changes;
- the accepted session/router/device foundation is absent or materially broken;
- locked docs conflict with this task;
- safe nested routing would require weakening role/device/first-login guards;
- a backend/API/schema change or new package is required;
- another implementation already owns the same shell/routes;
- safe completion requires destructive Git, force-push, shared-history rewrite,
  hook/check bypass, secret exposure, or unrelated work overwrite.

During Phase 2, any unresolved P1/P2 finding results in:

```text
FINAL STATUS: NOT ACCEPTED
```

Do not self-fix after the read-only acceptance gate begins. Return findings for
a focused correction cycle.

If implementation acceptance passes but safe delivery cannot complete:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Do not start `S02-FE-002`.

---

## 13. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git preflight

Complete Section 5.1 and create/switch to:

```text
task/s02-fe-001-platform-owner-shell-navigation
```

Carry the two approved task files onto the task branch. Do not implement on
`main`. Do not commit or push.

### Phase 1 — Implementation

Implement only `S02-FE-001`.

Run all focused route, guard, shell, layout, logout, invalidation, isolation,
no-API, regression, analysis, format, and build checks. Complete manual smoke.

Do not commit, push, open a PR, merge, or mark the task `Accepted` during this
phase.

### Phase 2 — Read-only acceptance gate

Re-read:

- root/frontend `AGENTS.md`;
- this task;
- relevant locked sections;
- Stage 1 routing/session acceptance evidence;
- complete staged, unstaged, and untracked change set;
- all focused/full test and build evidence;
- manual smoke evidence.

Phase 2 is strictly read-only:

- no file edits;
- no generated fixes;
- no formatter writes;
- no staging/unstaging;
- no commit/push/PR/merge;
- no task/index status mutation.

Classify findings:

- `P1`: authentication, role/device, first-login, session isolation, secret,
  or cross-role protected-content bypass;
- `P2`: material route, shell, navigation, layout, placeholder, architecture,
  test, build, or scope mismatch;
- `P3`: non-blocking observation.

PASS requires zero unresolved P1/P2 findings and complete trustworthy evidence.

If PASS is not reached, report `FINAL STATUS: NOT ACCEPTED` and stop.

### Phase 3 — Post-acceptance GitHub delivery

Only after Phase 2 PASS:

1. Update this task status from `Approved` to `Accepted`.
2. Update only the truthful `S02-FE-001` row in
   `tasks/STAGE_02_TASK_INDEX.md` to record task `Accepted` and review `PASS`;
   finalize delivery status only after merge.
3. Re-run final diff, secret, scope, focused tests, full Flutter test, analyze,
   format, and appropriate build checks after bookkeeping changes.
4. Stage only approved `S02-FE-001` implementation, tests, task files, and
   truthful index change.
5. Commit with:

   ```text
   feat(platform): add owner desktop shell navigation
   ```

   Commit body:

   ```text
   Task: S02-FE-001
   ```

6. Push only the approved task branch to the approved `origin`.
7. Create a PR into `main`.
8. Do not bypass required checks or branch protection.
9. Merge only when checks are green and merge is permitted.
10. Synchronize local `main` from merged `origin/main` using safe
    fast-forward-only operations.
11. Verify working tree clean and local `main == origin/main`.
12. Only then report:

    ```text
    FINAL STATUS: ACCEPTED
    ```

If delivery cannot safely complete after PASS, report `DELIVERY BLOCKED` with
exact evidence. Do not start the next task.

---

## 14. Required Codex Final Report

Return:

1. Final status: `ACCEPTED`, `NOT ACCEPTED`, `DELIVERY BLOCKED`, or preflight
   `BLOCKED`.
2. Dependency and Git preflight evidence.
3. Current `origin/main` commit used.
4. Implementation summary.
5. Changed files.
6. Exact route topology and URI-selection evidence.
7. Guard-precedence and wrong-role/direct-route evidence.
8. Desktop shell/navigation content evidence.
9. Compact/wide layout evidence.
10. Current-session identity/logout/invalidation evidence.
11. Account-switch and stale-session isolation evidence.
12. No-API/no-fake-data evidence.
13. Focused and full test results with non-zero counts.
14. Analyze/format/build results.
15. Scope, package, and secret checks.
16. Manual smoke results.
17. Phase 2 findings and acceptance decision.
18. Git commit, branch, PR, merge, and final synchronization evidence.
19. Remaining blockers/deviations.

Do not create or start `S02-FE-002`.
