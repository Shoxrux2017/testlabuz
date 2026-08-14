# Codex Task: Institution Admin Desktop Shell and Navigation

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-FE-001` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Frontend` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Depends on | `S03-BE-007 — Accepted / PASS / Delivered` (therefore all sequential Stage 3 backend predecessors are delivered) |
| Blocks | `S03-FE-002` through `S03-FE-009`, `S03-INT-002` |

This task/prompt pair may be prepared before its dependency is accepted, but
execution must not start until S03-BE-007 is `Accepted / PASS / Delivered` on
current `origin/main`.

## 2. Goal

Replace only the temporary desktop Institution Admin `RoleEntryScreen` with one
real, route-aware Material 3 administration shell and six honest Stage 3 route
destinations, without fetching or inventing product data.

Exact public route family:

```text
/institution-admin
/institution-admin/users
/institution-admin/users/new
/institution-admin/users/:userId
/institution-admin/institution
/institution-admin/settings
```

Exactly four primary navigation destinations:

```text
Dashboard
Users
Institution
Settings
```

The canonical post-login Institution Admin entry remains
`/institution-admin`, which means Dashboard.

## 3. Current Accepted Context

Treat current `origin/main` at execution time as the implementation source of
truth. The preparation snapshot below is review context only and must be
rechecked before edits:

```text
origin/main at preparation review:
2d0504aaae613e3b75ac5328973c0b3bab00b0b4
```

At that baseline:

- Stage 1 provides Riverpod, GoRouter, Dio, secure session storage, server-
  restored `/api/v1/auth/me`, mandatory password-change routing, device
  surfaces, immediate local logout, global invalidation, session generations,
  and temporary role-entry screens.
- Stage 2 provides the accepted `PlatformOwnerShell`, full-path `ShellRoute`
  pattern, URI-derived selected destination, desktop navigation rail,
  GoRouter imperative URL reflection, direct-route guards, and focused route/
  shell tests.
- `AppRoutePaths.institutionAdmin` and
  `AppRouteNames.institutionAdmin` already exist.
- `resolveEntryPath()` already maps a desktop Institution Admin to
  `/institution-admin` and mobile/unsupported surfaces to
  `/unsupported-device`.
- `AuthUser` already carries `fullName`, `isActive`, `institutionId`, and the
  current `AuthInstitution` (`id`, `name`, `status`, `timezone`).
- `RoleEntryScreen` must remain in use for Teacher, Student, Parent, and the
  accepted unsupported-device behavior.
- Existing `frontend/test/router_bootstrap_test.dart` contains Institution Admin
  temporary-entry expectations and must be updated narrowly for this real
  shell while preserving all other accepted assertions.

This task establishes presentation and routing only. Later tasks own real
dashboard, profile, User, settings, and category models/repositories/screens.

## 4. Dependency and Stage-Control Gate

Before implementation, prove all of the following on current `origin/main`:

1. Stage 1 and Stage 2 are closed with PASS.
2. `S03-INT-001` and S03-BE-001 through S03-BE-007 are each
   `Accepted / PASS / Delivered`.
3. The Stage 3 index and `tasks/README.md` truthfully reflect those deliveries
   and still identify S03-FE-001 as the next execution gate.
4. This detailed task exists at:

   ```text
   tasks/frontend/stage-03/S03-FE-001-institution-admin-desktop-shell-navigation.md
   ```

5. The paired prompt exists, this task is `Approved`, and the pair is the only
   owner-prepared S03-FE-001 authority.
6. The accepted auth/session/device/router foundations and current Platform
   Owner shell remain present and green.
7. No conflicting Institution Admin shell or Stage 3 frontend data flow already
   exists.

If any dependency is missing/stale, current implementation contradicts the
contract, or safe completion requires predecessor/later scope, stop before
implementation. Preparing this pair does not satisfy its dependency gate.

## 5. Exact Route Contract

### 5.1 Route Names, Paths, Segments, and Parameter

Preserve the existing root constants and add exactly these names:

```text
AppRouteNames.institutionAdmin             = institution-admin
AppRouteNames.institutionAdminUsers        = institution-admin-users
AppRouteNames.institutionAdminUserCreate   = institution-admin-user-create
AppRouteNames.institutionAdminUserDetail   = institution-admin-user-detail
AppRouteNames.institutionAdminInstitution  = institution-admin-institution
AppRouteNames.institutionAdminSettings     = institution-admin-settings
```

Define/reuse these exact public paths:

```text
AppRoutePaths.institutionAdmin             = /institution-admin
AppRoutePaths.institutionAdminUsers        = /institution-admin/users
AppRoutePaths.institutionAdminUserCreate   = /institution-admin/users/new
AppRoutePaths.institutionAdminUserDetail   = /institution-admin/users/:userId
AppRoutePaths.institutionAdminInstitution  = /institution-admin/institution
AppRoutePaths.institutionAdminSettings     = /institution-admin/settings
```

Define focused constants for:

```text
institutionAdminUsersSegment       = users
institutionAdminUserCreateSegment  = new
institutionAdminUserIdParameter    = userId
institutionAdminInstitutionSegment = institution
institutionAdminSettingsSegment    = settings
```

Do not scatter these literals through widgets/tests or rename the accepted
root to `/institution` or `/admin`.

Add all six declared route patterns to the existing protected/all route
registries exactly once. Bootstrap authorization still uses the exact approved-
location helper because a template string in a registry does not match a real
dynamic location.

### 5.2 Exact Helpers and Classification

`AppRoutePaths` must provide one tested source for:

- the four primary navigation locations;
- exact static-route recognition;
- exact User-create recognition;
- exact structurally valid User-detail recognition;
- complete approved Institution Admin location recognition;
- segment-safe Institution Admin prefix detection used only to reject malformed
  descendants, never as authorization;
- a safe User-detail location builder.

Equivalent clear helper names are allowed only when their behavior and tests
are exact. Preferred names:

```text
institutionAdminPrimaryDestinations
isInstitutionAdminPrimaryDestination(path)
isInstitutionAdminUserCreatePath(path)
isInstitutionAdminUserDetailPath(path)
isInstitutionAdminApprovedLocation(path)
isInstitutionAdminSegment(path)
institutionAdminUserDetailLocation(userId)
```

`isInstitutionAdminApprovedLocation` returns true only for the five exact
static locations plus a valid detail location. A broad check such as
`path.startsWith('/institution-admin')` is never sufficient to preserve or
authorize a route.

These examples are not approved locations:

```text
/institution-admin-extra
/institution-admin/
/institution-admin/users/
/institution-admin/users/new/extra
/institution-admin/users//
/institution-admin/users/not-a-uuid
/institution-admin/users/<uuid>/extra
/institution-admin/institution/edit
/institution-admin/settings/categories
```

### 5.3 User ID Shape and Safe Location Building

The route parameter is structurally valid only when it is one canonical
hyphenated UUID-shaped string:

```text
8-4-4-4-12 hexadecimal characters, case-insensitive
```

Do not constrain the UUID version digit; current Laravel UUID generation may
change version while retaining the canonical shape.

The location helper must:

- accept only the exact untrimmed UUID-shaped input;
- reject empty, whitespace, `new`, slash/backslash, dot traversal, control,
  query/fragment, percent-encoded separator, and arbitrary non-UUID values with
  a deterministic local argument failure;
- call `Uri.encodeComponent` for the accepted parameter before composing the
  location;
- never concatenate raw untrusted text into a route.

A well-formed but nonexistent UUID may reach the honest detail placeholder in
this task; S03-FE-005 owns the later backend `resource_not_found` UI. A malformed
detail location is not approved and must resolve safely to the canonical
Institution Admin entry after authentication, without building the detail
child or exposing another shell.

### 5.4 ShellRoute Declaration Order

Create one Institution Admin `ShellRoute` with all six full-path children.
Within its route list, declare the static create route:

```text
/institution-admin/users/new
```

before the dynamic detail route:

```text
/institution-admin/users/:userId
```

This prevents `new` from being interpreted as `userId`. Every route name is
globally unique. Do not add a second Institution Admin shell, nested router, or
competing root.

## 6. Exact Destination, Title, and Placeholder Contract

Use one `InstitutionAdminShellDestination` enum (or equivalently focused
single source) with exactly these four values and navigation properties:

| Destination | Label/title | Primary path | Required icon meaning |
|---|---|---|---|
| Dashboard | `Dashboard` | `/institution-admin` | dashboard |
| Users | `Users` | `/institution-admin/users` | people/users |
| Institution | `Institution` | `/institution-admin/institution` | institution/business |
| Settings | `Settings` | `/institution-admin/settings` | settings |

The selected primary destination and header page title derive only from the
current exact path:

| Current path | Selected navigation | Exact page title | Honest body text |
|---|---|---|---|
| `/institution-admin` | Dashboard | `Dashboard` | `Institution dashboard will be implemented in S03-FE-002.` |
| `/institution-admin/users` | Users | `Users` | `Institution user list will be implemented in S03-FE-004.` |
| `/institution-admin/users/new` | Users | `Create User` | `Institution user creation will be implemented in S03-FE-006.` |
| `/institution-admin/users/:userId` | Users | `User Details` | `Institution user details will be implemented in S03-FE-005.` |
| `/institution-admin/institution` | Institution | `Institution` | `Institution profile will be implemented in S03-FE-003.` |
| `/institution-admin/settings` | Settings | `Settings` | `Assessment settings and understanding categories will be implemented in S03-FE-008 and S03-FE-009.` |

The detail placeholder receives the decoded, validated UUID through the route
boundary but does not display it, use it as authority, or fetch data.

Placeholder bodies contain only their destination identity and exact honest
text. They contain no fake counts, users, profile values, settings, category
ranges, charts, tables, loading/error states, forms, actions, IDs, or records.
Do not create generic data-state machinery for static placeholders.

## 7. Authentication, Device, and Exact Route Guards

### 7.1 Guard Precedence

Preserve this accepted order for all six routes:

```text
session bootstrap/restore
→ authentication
→ mandatory password change
→ role/device canonical entry
→ exact role-owned location
→ shell session-context invariant
```

Expected outcomes:

| Current state | Attempted Institution Admin location | Outcome |
|---|---|---|
| initial/bootstrapping | exact approved location | preserve only that exact location while neutral bootstrap UI is shown |
| initial/bootstrapping | malformed descendant/prefix | do not preserve it; use existing technical root flow |
| bootstrap failure | any | existing technical bootstrap-failure behavior |
| unauthenticated/authenticating | any | `/login` |
| any authenticated role with `must_change_password=true` | any | `/change-password` |
| valid Institution Admin + desktop | exact approved location | requested shell destination |
| Institution Admin + mobile/web/unsupported | any | `/unsupported-device` |
| Platform Owner + desktop | any | accepted Platform Owner canonical entry |
| Teacher/Student on accepted surface | any | that role's accepted canonical entry |
| Parent on mobile | any | `/parent` |
| Parent on desktop | any | `/unsupported-device` |
| valid Institution Admin + malformed Institution Admin descendant | malformed path | `/institution-admin` |

`AppDeviceSurface.unsupported` is the existing representation for web and
unsupported native targets. Do not add web Institution Admin support or a
second web-specific shell. Width/breakpoints affect layout only, never device
authorization.

### 7.2 Narrow Router Integration

Extend `_authRedirect` and `_keepsLocationDuringBootstrap` only as required:

- an eligible desktop Institution Admin may remain on an exact approved
  Institution Admin location;
- bootstrap preserves only exact approved locations, including a valid UUID
  detail path;
- malformed/unknown descendants are not preserved or authorized by prefix;
- query/fragment data is never role, tenant, destination, or User-ID authority;
- wrong roles/devices are redirected by the existing canonical resolver;
- Platform Owner and all other accepted routes/guards remain unchanged.

Keep `/institution-admin` as `resolveEntryPath()` output. No change to
`entry_route_resolver.dart` should be required.

### 7.3 Shell Session-Context Invariant

Normal protected shell content may render only when the live session has:

```text
status = authenticated
user != null
user.role = institution_admin
device surface = desktop
user.isActive = true
user.mustChangePassword = false
user.institutionId is non-empty
user.institution != null
user.institution.id = user.institutionId
user.institution.status = active
current path maps to a valid shell destination
```

The backend remains the authority and normally prevents inactive sessions. The
shell checks these values as a fail-closed presentation invariant, not as a
replacement for backend authorization.

If session identity is absent/transitioning, show only a neutral non-sensitive
loading scaffold. If role/device/Institution/path context is inconsistent,
show the focused non-sensitive `Session route unavailable` surface with only a
safe sign-out action; do not render the child, navigation, full name,
Institution name, old account data, or another role shell.

Do not change `AuthSessionController`, `AuthSessionState`, `AuthUser`,
`AuthInstitution`, `AppDeviceSurface`, auth DTOs/repository, token storage, or
session-generation behavior in this task.

## 8. Desktop Shell Presentation and Navigation

### 8.1 Exact Shell Content

One focused `InstitutionAdminShell` under
`features/institution_admin/presentation` must contain:

- `TestLabUz` product identity;
- one persistent left Material 3 navigation rail/sidebar;
- exactly four navigation destinations and no Groups/Reports/learning routes;
- header title from the exact path mapping in Section 6;
- exact role context `Institution Admin`;
- `Current user: <fullName>` from the live session;
- `Institution: <institution.name>` from the same live session;
- one clearly discoverable `Sign out` action using the accepted
  `AuthSessionController.signOut()`;
- the GoRouter child content region.

Do not display login name, email, phone, IDs, timezone, token, raw role/status,
debug data, or any fake product data.

Use these stable keys:

```text
institutionAdminShell
institutionAdminNavigation
institutionAdminProductName
institutionAdminPageTitle
institutionAdminRoleLabel
institutionAdminCurrentUser
institutionAdminInstitutionName
institutionAdminUnavailable
institutionAdminDashboardPlaceholder
institutionAdminUsersPlaceholder
institutionAdminUserCreatePlaceholder
institutionAdminUserDetailPlaceholder
institutionAdminInstitutionPlaceholder
institutionAdminSettingsPlaceholder
```

Preserve the accepted logout key `entryLogoutButton` so existing cross-feature
regression tests remain meaningful.

### 8.2 Responsive Contract

Use the accepted Platform Owner shell layout as a pattern without coupling the
two feature classes or creating a premature cross-role universal shell.

Required behavior:

- width at or above `1100` logical pixels may use an extended rail with visible
  labels;
- practical compact desktop `800 × 600` uses a compact rail with all four
  labels discoverable and tooltips on icons;
- practical wide desktop `1440 × 900` remains readable and does not stretch
  placeholder content excessively;
- the header keeps title, identity, Institution, and sign-out usable without
  overflow;
- a long full name and Institution name (at least 80 characters each) use safe
  wrapping/flex/ellipsis without revealing hidden text through layout errors;
- text scale `1.0` and `2.0` at both required sizes produce no Flutter overflow
  or uncaught layout exception;
- resizing does not change authorization, route, selected destination, or
  shell identity.

Use named local constants for repeated rail widths, breakpoint, and spacing.
Do not add design-system/theme changes or packages.

### 8.3 Accessibility and Keyboard Contract

- Every destination has a visible label in extended mode and accessible label/
  tooltip in compact mode.
- Selected state is conveyed by Material selection semantics/icon treatment,
  not color alone.
- Logical focus order reaches navigation destinations and Sign out.
- Enter/Space activates the focused destination/action through normal Material
  controls.
- Focus indicators remain visible; do not suppress focus/semantics.
- Header and placeholder headings have appropriate semantic meaning without
  duplicate/conflicting labels.

Widget tests must inspect labels/tooltips/selected semantics and exercise at
least keyboard navigation activation plus Sign out focus/activation.

### 8.4 URI-Driven Navigation

- Current path is the only selected-destination/page-title authority.
- Dashboard/Users/Institution/Settings taps use the existing GoRouter
  imperative navigation pattern and update reflected URI/location.
- `users/new` and a valid `users/:userId` keep Users selected while showing
  their own page title/body.
- Reselecting the current primary path is a no-op and creates no history loop.
- Navigating to another destination creates normal history; back returns the
  prior path/selection/title/body.
- Direct entry/restart-at-location and router/session refresh do not reset a
  valid child location to Dashboard.
- Shell code keeps no independent stale selected index, User ID, account, or
  Institution cache.

Web remains unsupported for Institution Admin. References to URL/history mean
GoRouter route information and desktop/deep-link-style testing, not enabling a
browser product shell.

## 9. API, Data, and Session Isolation Boundary

This task makes zero Stage 3 product API requests. Specifically, it must not
call:

```text
GET /api/v1/institution/dashboard
GET/PATCH /api/v1/institution/profile
any /api/v1/institution/users endpoint
GET/PUT /api/v1/institution/settings/assessment
GET/PUT /api/v1/institution/understanding-categories
```

The already accepted authentication bootstrap (`GET /api/v1/auth/me`), global
auth handling, and user-triggered logout (`POST /api/v1/auth/logout`) are not
Stage 3 product-data calls and remain allowed through existing infrastructure.

Do not create an Institution Admin DTO, domain model, repository, data source,
controller/notifier, fake production repository, loading/error/data state, or
direct Dio call. Static route/widget tests may use the existing fake auth
repository only.

Required isolation behavior:

- logout changes local session state before awaiting backend logout, so shell,
  identity, Institution, and child disappear immediately;
- backend logout failure cannot restore protected content;
- global `authentication_required` invalidation removes the shell and old data;
- session generation prevents a stale bootstrap/sign-in completion restoring
  the prior account;
- Institution Admin A → Institution Admin B shows only B's name/Institution and
  canonical route state;
- Institution Admin A → another role shows only that role's accepted entry and
  no Institution Admin shell/A context;
- another role → Institution Admin B shows only B's current context;
- no shell state survives ProviderScope/router recreation as authority.

Reuse existing session behavior; do not duplicate or modify it.

## 10. Exact Files and Responsibilities

Change only these application/test paths:

| File | Action | Responsibility |
|---|---|---|
| `frontend/lib/app/router/app_route_paths.dart` | Modify | Exact names/paths/segments/UUID helpers/location classification |
| `frontend/lib/app/router/app_router.dart` | Modify | One Institution Admin ShellRoute, ordered children, narrow guards/bootstrap preservation |
| `frontend/lib/features/institution_admin/presentation/institution_admin_shell.dart` | Create | Session-safe shell, destination mapping, responsive navigation/header/logout |
| `frontend/lib/features/institution_admin/presentation/institution_admin_placeholder_screen.dart` | Create | Six exact static placeholder screen classes/bodies |
| `frontend/test/app/router/institution_admin_route_paths_test.dart` | Create | Exact constants/helpers/UUID/malformed/uniqueness proof |
| `frontend/test/features/institution_admin/institution_admin_shell_test.dart` | Create | Complete shell/route/guard/layout/a11y/session/no-request proof |
| `frontend/test/router_bootstrap_test.dart` | Modify narrowly | Replace temporary Institution Admin expectations and preserve full Stage 1/2 matrix |
| `tasks/STAGE_03_TASK_INDEX.md` | Modify only as Section 16 permits | Truthful execution/review/delivery state |
| `tasks/README.md` | Modify only after Phase 2 PASS | Truthful Stage 3 current/next gate |
| this detailed task | Status metadata only after Phase 2 PASS | Accepted task state |
| paired Codex prompt | Preserve byte-for-byte | Approved execution authority |

Inspect/reuse but preserve byte-for-byte:

```text
frontend/lib/features/auth/**
frontend/lib/features/entry/domain/entry_route_resolver.dart
frontend/lib/features/entry/presentation/role_entry_screen.dart
frontend/lib/app/device/app_device_surface.dart
frontend/lib/features/platform_admin/**
frontend/test/app/router/platform_owner_route_paths_test.dart
frontend/test/features/platform_admin/**
frontend/pubspec.yaml
frontend/pubspec.lock
frontend/integration_test/**
```

No other application/test path may change. The Institution Admin temporary
route is removed from `app_router.dart`, but `RoleEntryScreen` itself remains
for other roles. Stop instead of widening the allowlist if the accepted current
architecture cannot support the task safely.

No backend, Docker, locked docs, schema, dependency, generated plugin, Windows
runner, or later-stage file change belongs here.

## 11. Authoritative References

| Source | Exact area | Requirement |
|---|---|---|
| `docs/02-user-roles.md` | `2. Institution Admin`; device summary | Own-Institution desktop authority and management boundary |
| `docs/03-features.md` | `3. Institution Admin Features` | Dashboard/profile/User/settings desktop scope |
| `docs/04-user-flows.md` | `3. Institution Admin Flow` | Dashboard-first management navigation and logout |
| `docs/05-business-rules.md` | tenant/role/account/ACL rules | No cross-role/tenant authority or invented data |
| `docs/06-roadmap.md` | `2.6`; `8. Stage 3`; `9. Stage 4` | Desktop scope, current stage boundary, Groups exclusion |
| `docs/07-architecture.md` | Flutter application/navigation/role sections | Riverpod/GoRouter feature-first shell architecture |
| `docs/09-api-contracts.md` | Current User/Session and Stage 3 endpoints | `/auth/me` shell authority; product APIs are later-task context |
| accepted `S02-FE-001` and current Platform Owner shell/code/tests | route/shell/session precedent | Reuse pattern without cross-role coupling |
| accepted Stage 1 auth/session/device tasks/tests | security foundation | Guard precedence/logout/invalidation/account switching |
| `frontend/AGENTS.md` | applicable complete file | Frontend boundaries, tests, quality, package rules |
| `tasks/STAGE_03_TASK_INDEX.md`, `tasks/README.md` | lifecycle/dependencies | Sequential gate and truthful delivery |

If this task conflicts with stricter locked authority or accepted current code,
stop and report rather than silently changing the contract/docs.

## 12. Acceptance Criteria

- [ ] Dependency/Git/index gate proves S03-BE-007 and all predecessors are
      accepted and delivered before execution.
- [ ] Exact six globally unique route names/paths/segments/parameter exist once
      under one Institution Admin ShellRoute.
- [ ] `/users/new` is declared before `/:userId` and cannot become a detail ID.
- [ ] UUID builder/classifier accepts only canonical hyphenated UUID shape,
      encodes safely, and rejects every malformed/path-manipulation case.
- [ ] Bootstrap and authenticated routing preserve only exact approved
      locations; no broad prefix grants a destination.
- [ ] Canonical entry is Dashboard; exact four primary destinations and exact
      path/title/body mapping are enforced.
- [ ] User create/detail select Users while retaining their own titles/bodies.
- [ ] Direct entry, rebuild, route reflection, reselect, navigation, and back
      behavior are deterministic and URI-driven.
- [ ] Only a password-complete desktop Institution Admin with valid live
      Institution context renders the protected shell.
- [ ] Every wrong role/device/unauthenticated/first-login/malformed route follows
      exact accepted guard precedence without protected-content flash.
- [ ] Transitional and invariant-failure surfaces expose no prior/current
      protected identity, Institution, navigation, or child.
- [ ] Header displays only current session full name, Institution name, role,
      page title, product name, and safe logout.
- [ ] Logout/global invalidation/account switching/stale completion cannot
      restore or flash old shell/context.
- [ ] Compact/wide and text-scale/long-identity layouts have no overflow and all
      destinations/logout remain accessible and keyboard usable.
- [ ] Placeholders contain exact honest text and no fake/later product data,
      states, controls, IDs, or metrics.
- [ ] Shell rendering/navigation makes zero Stage 3 product API calls and adds
      no data/domain/repository/controller code.
- [ ] Platform Owner and all Stage 1 role/device/session behavior remains green;
      `RoleEntryScreen` continues serving its accepted remaining roles.
- [ ] Only exact allowlisted application/test/bookkeeping files change; no
      package/backend/docs/Docker/generated/later-stage drift exists.
- [ ] Focused/full tests, analyze, format, Windows build, scope/secret checks,
      and required manual smoke satisfy the gates.
- [ ] Phase 2 has zero unresolved P1/P2 and safe delivery completes before
      final `ACCEPTED`.

## 13. Required Tests

### 13.1 Route Constants, UUID, and Classification

Prove:

- every exact name/path/segment/parameter value;
- global route-name/path/helper-list uniqueness;
- four primary destination locations in exact order;
- exact recognition for six static/template meanings and representative valid
  UUID detail locations, including upper/lower hexadecimal;
- location helper output for valid UUID;
- helper rejection for empty, whitespace, `new`, non-UUID, incomplete/extra
  groups, braces, slash, backslash, dot traversal, query, fragment, control,
  percent-encoded slash/backslash, and extra segment input;
- malformed paths listed in Section 5.2 are not approved;
- `/institution-admin-extra` is not an Institution Admin segment;
- query/fragment cannot change primary destination or authority.

### 13.2 Direct Entry and Destination Mapping

For an eligible desktop Institution Admin, direct/restart-style entry into each
exact location proves:

```text
correct URI path
one Institution Admin shell
correct primary selected index
correct exact page title
correct exact placeholder body
no temporary RoleEntryScreen
no Platform Owner shell
```

Use at least two different valid User UUIDs. The User ID is passed to the
detail placeholder boundary but never displayed.

### 13.3 Guard and Bootstrap Matrix

Parameterize all six approved locations across required cases:

- unauthenticated/authenticating → login;
- every role with password change required → change-password;
- valid Institution Admin desktop → requested location;
- Institution Admin mobile and unsupported/web → unsupported-device;
- Platform Owner desktop → Platform Owner entry;
- Teacher desktop/mobile and Student desktop/mobile → accepted role entry;
- Parent mobile → parent; Parent desktop → unsupported-device;
- wrong roles never render Institution Admin shell/context during redirect;
- exact routes remain during initial/bootstrap neutral state and appear only
  after matching server-restored identity;
- malformed descendants/prefixes are not preserved during bootstrap and become
  canonical `/institution-admin` for a valid admin;
- bootstrap failure retains accepted technical behavior.

### 13.4 Shell, Navigation, and History

- exact product/role/page/current-user/Institution labels and no extra private
  session fields;
- exactly four destinations/icons/labels/tooltips and no Groups/Reports/
  learning/later navigation;
- each primary tap updates URI, selected state, title, body;
- Users remains selected for list/create/detail;
- reselect is stable and adds no history loop;
- normal back returns previous path/selection/title/body;
- router/provider refresh at every child does not reset to Dashboard;
- same shell contract wraps all children;
- invalid session/path context shows only unavailable+logout; transitional
  state shows neutral content only.

### 13.5 Responsive, Text, Accessibility, and Keyboard

At minimum test:

```text
800 × 600 at text scale 1.0 and 2.0
1440 × 900 at text scale 1.0 and 2.0
80-character full name and Institution name
```

For every case prove no overflow/uncaught exception, correct compact/expanded
mode, discoverable labels/tooltips, stable selection/authorization, and usable
Sign out. Inspect selection semantics/non-color affordance, logical focus order,
Enter/Space destination activation, and keyboard Sign out activation.

### 13.6 Logout, Invalidation, and Account Isolation

From every primary destination and representative create/detail child, prove:

```text
Sign out trigger
→ local shell/context removed immediately
→ /login
→ old full name/Institution/body absent
```

Also prove backend logout transport failure cannot restore content; current-
token global invalidation removes it; stale-token invalidation does not clear a
newer session incorrectly; Institution Admin A→B, A→other role, and other
role→B switches show only the new account/shell; delayed prior bootstrap/sign-in
completion cannot restore A.

### 13.7 No-Request, No-Future-Scope, and Regression

- shell/placeholder/navigation performs zero Institution Stage 3 product calls;
- expected auth bootstrap/logout calls remain the only allowed network-facing
  behavior;
- no Institution Admin data/domain/repository/controller/provider is created;
- no fake metrics/User/profile/settings/category state or future controls;
- existing Platform Owner route/shell/API tests and Stage 1 auth/device/router/
  password/logout/invalidation/session-generation tests stay green;
- updated `router_bootstrap_test.dart` distinguishes the Institution Admin real
  shell from remaining temporary role entries without weakening those tests.

Use static/scope evidence rather than inventing an artificial production
repository solely to assert the absence of one.

## 14. Quality and Verification Commands

From `frontend/`, run the repository-pinned equivalents of:

```text
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/app/router/institution_admin_route_paths_test.dart test/router_bootstrap_test.dart test/features/institution_admin/institution_admin_shell_test.dart
flutter test
flutter build windows --debug
```

`flutter pub get` must not change `pubspec.yaml` or `pubspec.lock`; any dependency
change is a blocker. Run additional configured frontend gates required by
`frontend/AGENTS.md`. Zero executed tests, skipped required coverage, analyzer/
format/build failure, or unexplained warning is not PASS.

Before Phase 2, inspect staged, unstaged, and untracked files completely and run
effective repository-root equivalents of:

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

Review every changed/untracked file for secrets, credentials, tokens, private
keys, `.env` data, sensitive fixtures, stale identity/tenant authority, unsafe
prefix/ID handling, fake product data, new dependencies, debug logging, skipped
tests, platform coupling, and later-stage code.

## 15. Manual Windows Smoke

Using controlled credentials that never appear in repository files, reports,
screenshots, or logs:

1. Log in as a password-complete Institution Admin on Windows; verify canonical
   Dashboard shell, current name, and own Institution.
2. Navigate through Dashboard, Users, Institution, Settings; verify URI/title/
   selection/body.
3. Direct/restart at Users, User create, valid-UUID User detail, Institution,
   and Settings; verify exact selected destination and no product request.
4. Use back navigation and reselect the current destination.
5. Resize to practical compact/wide windows and use keyboard focus/activation.
6. Verify malformed User ID/extra/prefix locations safely return to Dashboard
   with no detail child or disclosure.
7. Verify unauthenticated, password-change-required, wrong-role, and unsupported
   device cases.
8. Logout from representative paths; verify immediate removal even when logout
   transport is intentionally unavailable in a controlled test environment.
9. Switch Institution Admin A→B and A→another role; verify no old name,
   Institution, body, or selection survives.
10. Confirm no Stage 3 product endpoint was called by shell/placeholders.

If the controlled Windows/runtime/auth environment is available, smoke must
PASS. A smoke `FAIL` always blocks acceptance. `NOT RUN` is non-blocking only
when the environment is genuinely unavailable, the exact reason is reported,
and equivalent automated route/guard/session/layout/no-request coverage passes.
Do not use `NOT RUN` to hide startup, configuration, implementation, or build
failure.

## 16. Required Workflow and Delivery

### Phase 0 — Git and Authority Preflight

1. Read the paired prompt, this task, root/frontend `AGENTS.md`,
   `tasks/README.md`, Stage 3 index, S03-INT-001, accepted S03-BE-001–007,
   referenced locked sections, accepted Stage 1 routing/session evidence,
   accepted S02-FE-001, and current relevant code/tests.
2. Verify this task is `Approved` and dependencies/bookkeeping are delivered on
   `origin/main`.
3. Verify the approved remote, fetch safely, switch/synchronize main with
   fast-forward-only operations, and prove `local main == origin/main`.
4. Verify the working tree is clean except only the owner-prepared S03-FE-001
   task/prompt; preserve unrelated work and stop on unsafe state.
5. Create/switch to exactly:

   ```text
   task/s03-fe-001-institution-admin-shell
   ```

6. Carry the approved pair to the branch if required without committing main.
7. Verify the repository-pinned Flutter/Dart toolchain and dependency lock.
8. Do not commit, push, create a PR, or merge before Phase 2 PASS.

### Phase 1 — Implementation

Implement only this task and only the exact application/test paths in Section
10. During implementation, update only the S03-FE-001 Stage 3 index row to:

```text
In Progress / Not started / Not started
```

Keep this detailed task `Approved`; keep the paired prompt byte-for-byte
unchanged. Run all required tests, gates, scope/secret checks, and manual-smoke
rule. Inspect the complete change set including untracked files. Do not commit,
push, open a PR, merge, or prepare acceptance bookkeeping.

### Phase 2 — Strict Read-Only Acceptance Gate

Re-read all authority and inspect the complete code/tests/diff plus route/name/
UUID/order/guard/bootstrap/session-context/destination/placeholder/navigation/
history/responsive/text-scale/accessibility/keyboard/logout/invalidation/
account-switch/no-request/scope/build/smoke evidence.

Phase 2 is strictly read-only:

```text
no edits or auto-fix/write-format
no generated writes
no task/index/README bookkeeping edits
no staging/unstaging or commit
no push, PR, or merge
no self-fixing findings
```

Classify findings:

- `P1`: authentication, role/device, first-login, route-family/User-ID,
  session/tenant/identity, protected-content, secret/token, destructive-Git, or
  read-only-gate violation;
- `P2`: material route/name/order/helper/destination/shell/navigation/history/
  responsive/accessibility/no-request/architecture/test/build/scope/workflow/
  bookkeeping mismatch;
- `P3`: non-blocking observation with no correctness, security, required
  evidence, or maintainability-acceptance impact.

Any unresolved P1 or P2 requires:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start S03-FE-002. Report every P3; P3 alone
does not block acceptance.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 PASS with no unresolved P1/P2.

1. Change only this detailed task's metadata status from `Approved` to
   `Accepted`; do not rewrite approved behavior.
2. Prepare only the S03-FE-001 index row as
   `Accepted / PASS / Delivered` in the delivery commit.
3. Update directly affected Stage 3 index/README current-state narrative
   truthfully: Stage 3 remains `In Progress`, S03-FE-001 is delivered, and
   S03-FE-002 is the next implementation gate.
4. Preserve every later-task status; do not start or accept S03-FE-002.
5. Keep the paired prompt byte-for-byte unchanged and include both
   owner-prepared authority files in the focused delivery commit.
6. Keep Stage 3 not closed and Stage 4 not started.
7. Re-run final non-writing diff, scope, secret, package-lock, test, analyze,
   format, build, and consistency checks after bookkeeping.
8. Stage only the approved application/tests, this task, its unchanged prompt,
   `tasks/STAGE_03_TASK_INDEX.md`, and `tasks/README.md`.
9. Commit:

   ```text
   feat(institution): add admin desktop shell navigation
   ```

   Body:

   ```text
   Task: S03-FE-001
   ```

10. Push only the exact task branch, open a PR to `main`, verify base/head/diff,
    and merge only when required checks are safe/green and merge is permitted.
11. Fast-forward local `main` and prove local `main == origin/main` with a clean
    working tree.

Prepared `Accepted / PASS / Delivered` values become authoritative only after
the delivery commit is merged and final local/remote/clean verification passes.

If Phase 2 passed but safe delivery cannot complete:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Only after complete delivery:

```text
FINAL STATUS: ACCEPTED
```

## 17. Explicit Non-Goals and Stop Conditions

### 17.1 Non-Goals

- Real Dashboard/Profile/User/Settings/Category models, repositories, states,
  data, API calls, lists, details, forms, mutations, dialogs, or controls.
- Institution Admin management of groups/relationships/reports/learning;
  Groups and relationships begin in Stage 4.
- Teacher/Student/Parent product shells or mobile Institution Admin UI.
- Web Institution Admin support.
- Cross-role universal shell abstraction, design-system/theme/localization
  rewrite, or new package.
- Backend/schema/Docker/locked-doc/generated-runner changes.
- Stage 4 routes/features or any S03-FE-002+ implementation.

### 17.2 Stop Conditions

Stop on missing S03-BE-007 delivery, stale dependency/index state, unsafe Git,
missing accepted session/router/device foundation, route/UUID/locked-contract
conflict, inability to fail closed without modifying auth/session foundations,
need to change a non-allowlisted application/test path, need for a new package,
need to call product APIs, another role regression, failing required gate/smoke,
or material scope expansion.

## 18. Required Codex Final Report

Report:

1. Final status and dependency/index/Git preflight evidence.
2. Current `origin/main` commit and exact changed files.
3. Exact route names/paths/order/helpers/UUID classification evidence.
4. Shell/destination/title/placeholder/navigation/history behavior.
5. Guard/bootstrap/wrong-role/device/session-context evidence.
6. Identity/Institution/logout/invalidation/account-switch/stale-session proof.
7. Compact/wide/text-scale/long-name/accessibility/keyboard proof.
8. Zero Stage 3 product-request and no future/data-layer evidence.
9. Focused/full test counts and exact commands/results.
10. Analyze/format/Windows build/package-lock/scope/secret results.
11. Manual smoke result and blocking decision.
12. Phase 2 P1/P2/P3 findings and acceptance decision.
13. Bookkeeping, commit, branch, PR, checks, merge, and final sync/clean proof.
14. Any genuine blocker/deviation.

State exactly:

```text
No real Institution dashboard, profile, User, settings, category, Group,
relationship, report, learning, backend, schema, web, mobile-admin, or later-
stage behavior was implemented.
Next implementation gate: S03-FE-002.
```
