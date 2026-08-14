# Codex Execution Prompt — S03-FE-001

Execute exactly one approved task:

`S03-FE-001 — Institution Admin Desktop Shell and Navigation`

Repository: `G:\project\testlabuz`

Remote: `https://github.com/Shoxrux2017/testlabuz.git`

Authority task:

`tasks/frontend/stage-03/S03-FE-001-institution-admin-desktop-shell-navigation.md`

Required branch:

`task/s03-fe-001-institution-admin-shell`

Read the detailed task completely. It controls this prompt unless a referenced
locked contract is stricter.

## Authority and Dependency Preflight

Read root/frontend `AGENTS.md`, the detailed task, `tasks/README.md`,
`tasks/STAGE_03_TASK_INDEX.md`, accepted S03-INT-001 and S03-BE-001 through
S03-BE-007, relevant `docs/02–09`, accepted Stage 1 auth/session/device/router
evidence, accepted S02-FE-001 and current Platform Owner shell/code/tests, and
current Flutter/Git implementation.

Prove before edits:

```text
Stage 1 and Stage 2 = Closed / PASS
S03-INT-001 = Accepted / PASS / Delivered on origin/main
S03-BE-001 through S03-BE-007 = Accepted / PASS / Delivered on origin/main
Stage 3 index/README dependency and current-state narrative are truthful
the approved S03-FE-001 pair is the only owner-prepared authority
local main == origin/main
working tree is otherwise clean
origin is the approved repository
```

This pair may be prepared early, but implementation must stop until S03-BE-007
is delivered. Create/switch to
`task/s03-fe-001-institution-admin-shell`. Stop on unsafe Git, stale/missing
dependency bookkeeping, routing/session/contract conflict, non-allowlisted
required change, or scope expansion. Do not commit/push before Phase 2 PASS.

## Implement Only the Exact Shell Route Family

Replace only the temporary desktop Institution Admin route presentation with
one Material 3 `InstitutionAdminShell` for:

```text
/institution-admin
/institution-admin/users
/institution-admin/users/new
/institution-admin/users/:userId
/institution-admin/institution
/institution-admin/settings
```

Use exact globally unique route names:

```text
institution-admin
institution-admin-users
institution-admin-user-create
institution-admin-user-detail
institution-admin-institution
institution-admin-settings
```

Add exact segment/parameter constants for `users`, `new`, `userId`,
`institution`, and `settings`; four-primary-destination list; exact static/
create/detail/approved-location/segment-safe classifiers; and one safe
`institutionAdminUserDetailLocation(userId)` builder.

Register all six route patterns exactly once in existing protected/all route
registries, but use the approved-location helper—not template membership or a
broad prefix—for real dynamic bootstrap/authorization decisions.

Declare `/users/new` before `/users/:userId`. The detail parameter is valid
only when it is an untrimmed canonical hyphenated 8-4-4-4-12 hexadecimal UUID
shape, case-insensitive; do not constrain UUID version. The helper rejects
empty/whitespace/`new`/non-UUID/slash/backslash/dot/control/query/fragment/
percent-separator input, then URI-encodes accepted input. A valid nonexistent
UUID may show the placeholder; malformed direct paths safely resolve to
`/institution-admin` and never build the detail child.

Never authorize/preserve by broad prefix. Exact approved locations are the five
static paths plus a structurally valid detail path. Reject trailing/extra/
unknown descendants and `/institution-admin-extra`.

## Exact Destination and Placeholder Mapping

Primary navigation is exactly:

```text
Dashboard   → /institution-admin
Users       → /institution-admin/users
Institution → /institution-admin/institution
Settings    → /institution-admin/settings
```

Exact path mapping:

```text
/institution-admin
  selected Dashboard; title Dashboard
  Institution dashboard will be implemented in S03-FE-002.

/institution-admin/users
  selected Users; title Users
  Institution user list will be implemented in S03-FE-004.

/institution-admin/users/new
  selected Users; title Create User
  Institution user creation will be implemented in S03-FE-006.

/institution-admin/users/:userId
  selected Users; title User Details
  Institution user details will be implemented in S03-FE-005.

/institution-admin/institution
  selected Institution; title Institution
  Institution profile will be implemented in S03-FE-003.

/institution-admin/settings
  selected Settings; title Settings
  Assessment settings and understanding categories will be implemented in S03-FE-008 and S03-FE-009.
```

The validated decoded User UUID reaches the detail placeholder boundary but is
not displayed or used as authority. Add no fake counts/users/profile/settings/
category data, loading/error states, forms, actions, IDs, tables, charts, or
future controls.

## Exact Guard and Session Behavior

Preserve guard precedence:

```text
bootstrap → authentication → password change → role/device entry
→ exact approved location → shell session-context invariant
```

Extend router/bootstrap logic narrowly:

- initial/bootstrap preserves only an exact approved Institution Admin
  location; malformed prefix/descendant uses existing technical-root flow;
- unauthenticated/authenticating → `/login`;
- any role with `must_change_password=true` → `/change-password`;
- eligible Institution Admin desktop → requested exact location;
- Institution Admin mobile/web/unsupported → `/unsupported-device`;
- wrong role → its accepted canonical route/device outcome;
- malformed Institution Admin descendant for valid desktop admin →
  `/institution-admin`;
- query/fragment never supplies role, tenant, destination, or User-ID authority.

Web is represented by `AppDeviceSurface.unsupported`; do not add web support.
Keep `resolveEntryPath()` and RoleEntryScreen behavior for other roles
unchanged.

Normal shell content requires the live session to be authenticated, desktop,
password-complete, active Institution Admin with non-empty `institutionId`,
non-null active Institution, matching Institution IDs, and valid destination.
Backend remains authoritative; this is a fail-closed presentation invariant.

Absent/transitioning identity shows only neutral loading. Inconsistent role/
device/Institution/path shows only `Session route unavailable` plus Sign out—
no child/navigation/name/Institution/old data. Do not modify auth session/
domain/DTO/repository/controller, device resolver, entry resolver, or token/
generation foundations.

## Exact Shell and Navigation

Create one feature-owned shell with:

```text
TestLabUz
exact four-destination left NavigationRail/sidebar
URI-derived selected destination and page title
Institution Admin
Current user: <live fullName>
Institution: <live institution.name>
accepted entryLogoutButton Sign out
GoRouter child
```

Return no login/email/phone/IDs/timezone/token/raw role/status/debug fields.
Use every exact stable key defined by the detailed task for shell, navigation,
header context, unavailable state, and all six placeholders.

Follow the accepted Platform Owner pattern without coupling feature classes or
creating a universal role shell. At width `>=1100`, an extended rail is
allowed; `800×600` must use a usable compact presentation with labels/tooltips;
`1440×900` remains readable. Test text scales 1.0/2.0 and 80-character full/
Institution names at both sizes with no overflow/exception. Width never changes
authorization.

Every destination is keyboard/focus/semantics usable; Enter/Space activates
focused Material controls; selected state is not color-only; Sign out remains
reachable and usable.

Navigation is URI-driven. Primary selection updates reflected location;
create/detail keep Users selected; reselect is a no-op; back restores prior
path/selection/title/body; direct/restart/provider refresh preserves valid child
location. Keep no stale selected index, User ID, account, or Institution cache.

## Zero Product-API and Isolation Boundary

Make zero Stage 3 product calls:

```text
/api/v1/institution/dashboard
/api/v1/institution/profile
/api/v1/institution/users/**
/api/v1/institution/settings/assessment
/api/v1/institution/understanding-categories
```

Existing `/api/v1/auth/me` bootstrap and user-triggered logout remain allowed.
Create no Institution Admin data/domain/repository/data-source/controller/
notifier/provider/fake production repository or direct Dio call.

Reuse accepted immediate local logout, backend-logout-failure safety, global
invalidation, token version, and session generation. Prove no protected flash
or restoration across Institution Admin A→B, A→another role, another role→B,
or delayed stale completion.

## Exact Change Scope

Change exactly these application/test paths:

```text
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
frontend/lib/features/institution_admin/presentation/institution_admin_shell.dart
frontend/lib/features/institution_admin/presentation/institution_admin_placeholder_screen.dart
frontend/test/app/router/institution_admin_route_paths_test.dart
frontend/test/features/institution_admin/institution_admin_shell_test.dart
frontend/test/router_bootstrap_test.dart
```

Preserve existing auth/session/domain/DTO/repository/token/device files,
`entry_route_resolver.dart`, `role_entry_screen.dart`, all Platform Owner code/
tests, pubspec/lock, integration tests, backend, Docker, docs, schema, generated
plugins, and Windows runner byte-for-byte. The app router stops using
RoleEntryScreen only for Institution Admin; remaining accepted uses stay.

## Mandatory Verification

Test every detailed-task requirement, including:

- exact names/paths/segments/parameter/helper list and uniqueness;
- UUID upper/lower valid cases and the complete malformed/path-manipulation
  matrix;
- create-before-detail collision protection;
- direct entry to all six paths and exact destination/title/body mapping;
- every route across unauthenticated, bootstrap/failure, password-change,
  Institution Admin desktop/mobile/unsupported, and all wrong-role/device
  outcomes;
- malformed prefix/descendant bootstrap and authenticated behavior;
- valid and invalid live Institution/session context;
- navigation/reselect/back/rebuild/location reflection;
- compact/wide/text-scale/long-name no-overflow;
- labels/tooltips/selected semantics/focus/keyboard/Sign out;
- logout success/failure, global invalidation, token-version and stale-session
  behavior, same/cross-role account switches;
- exact placeholders/private-field exclusions and zero Stage 3 product calls;
- updated root router bootstrap expectations plus full Stage 1/2/Platform
  regressions.

Run from `frontend/`:

```text
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/app/router/institution_admin_route_paths_test.dart test/router_bootstrap_test.dart test/features/institution_admin/institution_admin_shell_test.dart
flutter test
flutter build windows --debug
```

Run additional configured frontend gates. `flutter pub get` must not modify
pubspec/lock. Zero tests, unexplained warning, skipped required coverage, or
format/analyze/test/build failure blocks acceptance.

Manual Windows smoke must PASS when controlled runtime/auth is available.
`NOT RUN` is non-blocking only for genuine environment unavailability stated
exactly with equivalent automated coverage; smoke FAIL always blocks.

During Phase 1, change only the S03-FE-001 Stage 3 index row to:

```text
In Progress / Not started / Not started
```

Keep the detailed task `Approved` and this prompt byte-for-byte unchanged before
Phase 2. Do not commit or push.

## Strict Read-Only Phase 2

After Phase 1, re-read all authority and inspect the complete staged/unstaged/
untracked change set plus route/UUID/order/guard/bootstrap/session/destination/
placeholder/navigation/history/layout/accessibility/keyboard/logout/isolation/
no-request/scope/test/build/smoke evidence.

Phase 2 permits no edit, auto-fix/write-format, generated write, bookkeeping
change, staging/unstaging, commit, push, PR, merge, or self-fix.

Classify findings:

```text
P1 = auth/role/device/first-login/route-ID/session/tenant/protected-content/secret/destructive-Git/read-only breach
P2 = material route/order/helper/shell/navigation/layout/a11y/no-request/architecture/test/build/scope/workflow defect
P3 = non-blocking observation with no correctness/security/evidence impact
```

Any unresolved P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start S03-FE-002. Report P3; P3 alone does
not block acceptance.

## Post-PASS Delivery

After PASS with no unresolved P1/P2 only:

1. change only the detailed task metadata status to `Accepted`;
2. prepare only its Stage 3 index row as `Accepted / PASS / Delivered`;
3. update directly affected Stage 3 index/README narrative truthfully so Stage
   3 remains `In Progress`, S03-FE-001 is delivered, and S03-FE-002 is next;
4. preserve later statuses and do not start/accept S03-FE-002;
5. keep this prompt byte-for-byte unchanged and include both owner-prepared
   authority files in delivery;
6. keep Stage 3 not closed and Stage 4 not started;
7. rerun final safe diff/scope/secret/package-lock/tests/analyze/format/build/
   consistency checks and commit:

```text
feat(institution): add admin desktop shell navigation

Task: S03-FE-001
```

Stage only approved implementation/tests, the task, this unchanged prompt,
Stage 3 index, and README. Push the exact branch, open a PR to `main`, verify
base/head/diff, merge only when safe/green, fast-forward local main, and prove
local main equals origin/main with a clean tree.

Prepared `Accepted / PASS / Delivered` bookkeeping becomes authoritative only
after successful merge and final local/remote/clean verification.

Delivery failure after PASS: `FINAL STATUS: DELIVERY BLOCKED`.

Complete delivery: `FINAL STATUS: ACCEPTED`.

Final response must include every detailed-task report item, P1/P2/P3 findings,
smoke decision, exact route/UUID/guard/session/destination/navigation/layout/
accessibility/isolation/no-request evidence, bookkeeping and Git delivery proof,
and state:

```text
No real Institution dashboard, profile, User, settings, category, Group,
relationship, report, learning, backend, schema, web, mobile-admin, or later-
stage behavior was implemented.
Next implementation gate: S03-FE-002.
```
