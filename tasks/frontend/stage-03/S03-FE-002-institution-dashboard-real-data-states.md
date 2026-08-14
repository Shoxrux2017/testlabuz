# Codex Task: Institution Dashboard Real Data and States

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-FE-002` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Frontend` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Depends on | `S03-FE-001` and `S03-BE-001` — each must be `Accepted / PASS / Delivered` before execution |
| Blocks | `S03-FE-003`, `S03-INT-002` |

This task/prompt pair may be prepared before its dependencies are delivered,
but production execution must not start until both direct dependencies are
`Accepted / PASS / Delivered` on current `origin/main`. Because Stage 3
implementation is sequential, delivery of S03-FE-001 also proves that all
preceding Stage 3 backend tasks are delivered.

## 2. Goal

Replace only the Institution Admin Dashboard placeholder at
`/institution-admin` with a real desktop screen backed by:

```text
GET /api/v1/institution/dashboard
```

The screen shows exactly three server-authoritative total account counts:

```text
Teachers
Students
Parents
```

Each count already includes active and inactive accounts of that role. This
task must not request, derive, label, or display an active/inactive split.

The screen must provide truthful loading, data, all-zero, error, Retry, and
manual Refresh behavior while preserving the accepted S03-FE-001 shell,
routing, authentication, tenant isolation, and account-switch boundaries.

## 3. Current Accepted Context

Treat current `origin/main` at execution time as the implementation source of
truth. This preparation snapshot is review evidence only and must be rechecked:

```text
origin/main at preparation review:
13a10f56aaef85fea307385bf669f7278ddef3b8
```

At that snapshot:

- S03-INT-001, S03-BE-001, and S03-BE-002 are
  `Accepted / PASS / Delivered`.
- S03-BE-001 implements the exact three-total contract in Section 5 and uses
  one own-Institution aggregate query.
- `frontend/lib/core/network/api_envelope.dart` owns success-envelope parsing.
- `DioFailureMapper` and `ApiRequestException` own established remote failure
  mapping.
- `AuthTokenInterceptor` injects the stored bearer token and emits the accepted
  token-version-aware global invalidation signal for a current authenticated
  `401 authentication_required` response.
- `AuthSessionController` owns local token clearing, bootstrap, sign-in,
  sign-out, lifecycle reconciliation, and stale auth-operation rejection.
- The Platform Owner dashboard provides a useful layered Flutter pattern, but
  its metrics, empty-state meaning, route, and refresh limitations are not the
  Institution Dashboard contract.
- S03-FE-001 is still a planned dependency at this preparation snapshot. Its
  approved contract creates the Institution Admin shell, makes
  `/institution-admin` the Dashboard route, and uses a dedicated static
  Dashboard placeholder until this task replaces it.

Do not copy Platform Owner business/UI behavior blindly. Reuse only the
established architecture, networking, failure, session, and test patterns that
match this task.

## 4. Dependency and Authority Gate

Before implementation, prove all of the following on current `origin/main`:

1. Stage 1 and Stage 2 remain closed with PASS.
2. S03-INT-001 and S03-BE-001 are `Accepted / PASS / Delivered`.
3. S03-FE-001 is `Accepted / PASS / Delivered`, and its real Institution Admin
   desktop shell/routes/tests are present.
4. The Stage 3 index and `tasks/README.md` truthfully identify S03-FE-002 as the
   next executable task.
5. This approved detailed task exists at:

   ```text
   tasks/frontend/stage-03/S03-FE-002-institution-dashboard-real-data-states.md
   ```

6. The paired prompt exists at:

   ```text
   tasks/frontend/stage-03/S03-FE-002-CODEX-PROMPT.md
   ```

7. The current backend route/resource/tests still match Section 5 exactly.
8. No competing Institution Dashboard real-data implementation already exists.
9. The accepted auth/session/Dio/router contracts remain present and green.

Stop before implementation if any dependency, task authority, API contract,
shell boundary, or safe Git condition is missing or conflicting. Task-file
preparation is not dependency delivery.

## 5. Exact Backend Contract Consumed

### 5.1 Endpoint and Request

Public API endpoint:

```text
GET /api/v1/institution/dashboard
```

The existing Dio base URL already owns the `/api/v1` prefix. The remote data
source must therefore issue exactly:

```dart
dio.get<Object?>('/institution/dashboard')
```

The request must have:

```text
query parameters: none
request body/data: none
route Institution UUID: none
institution_id: none
tenant-selection header: none
skip-auth option: false/absent
```

Use the existing authenticated Dio client. Do not manually construct an
Authorization header, accept tenant input, or add a second HTTP client.

### 5.2 Exact Stage 3 Success Response

```json
{
  "data": {
    "users": {
      "teachers": 30,
      "students": 600,
      "parents": 450
    }
  }
}
```

Counting meaning is locked:

- `teachers` is the total of active and inactive Teacher accounts;
- `students` is the total of active and inactive Student accounts;
- `parents` is the total of active and inactive Parent accounts;
- Platform Owner and Institution Admin accounts are excluded by backend;
- other-Institution accounts are excluded by backend;
- activation/deactivation does not change these totals;
- an absent role is numeric `0`;
- no identity, contact, recent User, Group, Topic, task, score, result,
  settings, category, report, or protected learning data is returned.

There is no `total`/`active` nested pair and no `active <= total` frontend
invariant. Do not change the API, invent missing values, or derive inactive
counts.

### 5.3 Strict DTO Rules

`InstitutionDashboardDto.fromJson(Object? json)` must:

1. parse the accepted single-resource envelope through
   `ApiSuccessEnvelope.fromJson`;
2. require `data` to decode through the accepted envelope boundary;
3. require `data.users` to be a JSON object/map;
4. require `teachers`, `students`, and `parents` to each be a Dart JSON integer
   with value `>= 0`;
5. reject missing, `null`, Boolean, string, floating-point, negative, list, or
   object values for any required count;
6. map malformed envelope/shape/value input to the existing local
   `ApiFailureKind.invalidResponse` through the remote data source;
7. never coerce malformed values to `0`, parse numeric strings, truncate
   doubles, or reuse a previous successful value.

Unknown/additional transport keys are ignored for forward-compatible additive
API evolution, consistent with existing client DTO patterns. They must never be
copied into the domain model or rendered. The three required Stage 3 values
remain the only Dashboard data owned by this task.

## 6. Exact Frontend Architecture

Use the feature-first flow required by `frontend/AGENTS.md`:

```text
InstitutionAdminDashboardScreen
  → InstitutionDashboardController / InstitutionDashboardState
  → InstitutionDashboardRepository
  → InstitutionDashboardRemoteDataSource
  → authenticated Dio
```

### 6.1 Required Types and Providers

Use these focused names unless an already-delivered S03-FE-001 collision makes
one impossible and requires a stop:

```text
InstitutionDashboard
InstitutionDashboardRepository
InstitutionDashboardDto
InstitutionDashboardRemoteDataSource
InstitutionDashboardRepositoryImpl
InstitutionDashboardStatus
InstitutionDashboardState
InstitutionDashboardController
InstitutionAdminDashboardScreen

institutionDashboardRemoteDataSourceProvider
institutionDashboardRepositoryProvider
institutionDashboardControllerProvider
```

The domain model contains only:

```text
teachers: int
students: int
parents: int
hasNoUsers: derived bool getter  // true only when all three values are zero
```

The DTO mirrors transport fields and owns parsing. The repository interface
returns the domain model. The repository implementation maps DTO to domain.
The presentation layer receives typed state and never sees raw JSON or Dio.

### 6.2 Responsibility Boundaries

- Widgets render state and dispatch `retry()`/`refresh()` only.
- The controller owns session eligibility, request orchestration, deduplication,
  generation checks, and state transitions.
- The repository owns the domain-facing fetch contract.
- The remote data source owns the exact GET and failure/format mapping.
- Existing core network/session code remains authoritative and unchanged.
- No generic dashboard abstraction shared with Platform Owner is introduced.
- No new package, code generator, cache, service locator, or state-management
  mechanism is added.

## 7. Session Eligibility and Tenant Safety

The controller may fetch only while the current session is all of:

```text
AuthSessionStatus.authenticated
user != null
user.role == UserRole.institutionAdmin
user.isActive == true
user.mustChangePassword == false
user.institutionId is non-empty
user.institution != null
user.institution.id == user.institutionId
user.institution.status == 'active'
```

S03-FE-001 remains the route/device/protected-shell authority. This controller
adds defense in depth and must issue zero Dashboard requests for initial,
bootstrapping, unauthenticated, authenticating, bootstrap-failure,
password-change, wrong-role, missing/mismatched Institution, or inactive
account/Institution context.

Use a session identity containing at least both:

```text
authenticated User ID
authenticated Institution ID
```

Never accept an Institution ID from the route, widget, provider parameter,
query, request body, header, local preference, or cached Dashboard object.

## 8. Exact Request and Freshness Policy

### 8.1 Initial Load and Route Ownership

- Direct/reload-style entry to `/institution-admin` starts one GET for the
  current eligible session.
- Rebuilds caused by the same unchanged eligible session do not start a second
  GET.
- Institution Admin Users, User create/detail, Institution, and Settings routes
  start zero Dashboard GETs.
- The provider is `autoDispose`; leaving the Dashboard disposes its feature
  state.
- Returning to the Dashboard after disposal starts one fresh GET.
- There is no retained cross-route cache, persistence, background refresh,
  polling, timer, or stale-while-revalidate behavior.

### 8.2 Loading, Data, Empty, Error

Use exact state meanings:

```text
initial  = no eligible feature request/data
loading  = one current initial/Refresh request; no counts/failure displayed
data     = one valid response; all three authoritative counts displayed
error    = current request failed; no counts displayed
```

`hasNoUsers` changes only the data presentation. All-zero remains successful
data, never loading or error.

### 8.3 Refresh

- Refresh is available in both non-zero and all-zero data states.
- One activation immediately enters `loading`, removes all prior counts from
  the rendered tree, and issues one GET.
- Refresh is unavailable/disabled while any request is in flight.
- Repeated click, keyboard, or programmatic Refresh intent during the same
  in-flight operation issues no duplicate GET.
- Success replaces all three values atomically; failure shows only error.

### 8.4 Retry

- Error shows exactly one Retry action.
- Retry retains the safe error surface while setting `isRetryInFlight = true`;
  the button is disabled and labelled `Retrying`.
- Repeated Retry intent while in flight issues no duplicate GET.
- Retry success replaces error with data/zero; Retry failure returns to enabled
  error without stale counts.

### 8.5 Stale Completion Rejection

Use a monotonically increasing operation generation or an equivalently tested
mechanism. A completion may update state only when all remain true:

```text
controller/provider is not disposed
operation generation is current
session User ID matches
session Institution ID matches
session is still eligible
```

Reject success and failure from an earlier request after Refresh, Retry,
logout, global invalidation, route disposal, same-role account/tenant switch,
or cross-role switch. No old count or error may flash after the boundary.

### 8.6 Retry Policy

Do not add automatic Dio retry, a retry package, background retry, or recursive
retry loop. The only feature-level retries in this task are explicit user
`Retry` and `Refresh` actions. The existing Dio timeout/interceptor behavior
remains unchanged.

## 9. Error and Session Reconciliation

### 9.1 Central `401`

For `401 authentication_required`, preserve and rely on the accepted
`AuthTokenInterceptor` plus token-version-aware global invalidation signal.
The feature must not clear tokens directly, emit a duplicate invalidation
signal, or implement its own 401 authority. Protected counts disappear because
the feature transitions away from data immediately and the router follows the
central unauthenticated session.

### 9.2 Lifecycle/Password Reconciliation

Follow the accepted dashboard/session pattern for these stable codes:

```text
password_change_required
user_inactive
institution_inactive
```

Trigger the existing `AuthSessionController.bootstrap()` reconciliation only
for the current operation/session. Do not mutate local auth state directly.
The accepted router then chooses password-change, login/unavailable, or other
appropriate flow from the refreshed server identity.

### 9.3 Safe Local Error Copy

Exact user-visible error title:

```text
Dashboard unavailable
```

Exact safe messages:

| Failure | Message |
|---|---|
| `authentication_required` | `Please sign in again.` |
| `password_change_required` | `Password change is required before dashboard access.` |
| `user_inactive` | `This account is inactive.` |
| `institution_inactive` | `This institution is inactive.` |
| `forbidden` | `You do not have permission to view this dashboard.` |
| `validation_failed` | `The dashboard request did not match the API contract.` |
| connection | `Could not reach the server. Check the connection and try again.` |
| timeout | `The dashboard request timed out.` |
| invalid response | `The server returned an unexpected dashboard response.` |
| cancelled | `The dashboard request was cancelled.` |
| server/unknown/other | `The dashboard could not be loaded.` |

Never display raw backend messages, request IDs, stack traces, SQL, URLs,
tokens, transport objects, response bodies, or tenant/user identifiers.

## 10. Exact Presentation Contract

### 10.1 Data and Zero Screen

Exact heading:

```text
Institution Dashboard
```

Render exactly three summary cards in this order:

| Card | Title | Value | Supporting label |
|---:|---|---|---|
| 1 | `Teachers` | exact `teachers.toString()` | `Total accounts` |
| 2 | `Students` | exact `students.toString()` | `Total accounts` |
| 3 | `Parents` | exact `parents.toString()` | `Total accounts` |

Do not add thousands separators through a new package, percentages, combined
total, active/inactive numbers, trend, icon meaning that implies status, or any
derived metric.

When all three values are zero, still render all three zero cards and add:

```text
No users yet.
```

Partial zero is ordinary data and does not show the all-zero message.

The data/zero header includes one accessible `Refresh` action. No create/edit,
navigation shortcut, chart, recent User, report, or settings control belongs to
the Dashboard body.

### 10.2 Loading and Error

Loading shows no card/count/empty/error content and exposes the live-region
semantic label:

```text
Loading institution dashboard
```

Error shows the title/message from Section 9 and one button:

```text
Retry
```

During Retry, its label is:

```text
Retrying
```

No prior count remains mounted below loading or error.

### 10.3 Stable Test Keys

Use these exact public widget keys:

```text
institutionDashboardLoading
institutionDashboardData
institutionDashboardEmpty
institutionDashboardHeading
institutionDashboardRefreshButton
institutionDashboardTeachersCard
institutionDashboardTeachersValue
institutionDashboardStudentsCard
institutionDashboardStudentsValue
institutionDashboardParentsCard
institutionDashboardParentsValue
institutionDashboardError
institutionDashboardErrorMessage
institutionDashboardRetryButton
```

Keys support deterministic tests; visible labels and semantics remain the user
contract.

### 10.4 Responsive and Accessible Behavior

- Keep the accepted S03-FE-001 shell/header/navigation visible around every
  Dashboard feature state while the session remains eligible.
- Use a scrollable, responsive Wrap/grid-like layout that does not assume three
  cards fit one row.
- Verify `800×600` and `1440×900` at text scales `1.0` and `2.0`.
- Long shell identity/Institution names remain S03-FE-001 responsibility, but
  combined shell+Dashboard tests must still prove no overflow.
- Heading hierarchy, card labels/values, loading live region, Refresh, Retry,
  error, and zero message must be discoverable to accessibility tools.
- Keyboard Tab focus order is logical. Enter/Space activates Refresh/Retry.
- Status is never communicated through color alone.

## 11. Exact Files and Scope

### 11.1 Allowed Application Files

Only these frontend application paths may change:

```text
frontend/lib/app/router/app_router.dart
frontend/lib/features/institution_admin/domain/institution_dashboard.dart
frontend/lib/features/institution_admin/domain/institution_dashboard_repository.dart
frontend/lib/features/institution_admin/data/dto/institution_dashboard_dto.dart
frontend/lib/features/institution_admin/data/institution_dashboard_remote_data_source.dart
frontend/lib/features/institution_admin/data/institution_dashboard_repository_impl.dart
frontend/lib/features/institution_admin/application/institution_dashboard_state.dart
frontend/lib/features/institution_admin/application/institution_dashboard_controller.dart
frontend/lib/features/institution_admin/presentation/institution_admin_dashboard_screen.dart
frontend/lib/features/institution_admin/presentation/institution_admin_placeholder_screen.dart
```

Exact responsibility of the two existing files:

- `app_router.dart`: replace only the `/institution-admin` Dashboard child
  builder/import with `InstitutionAdminDashboardScreen`; preserve the S03-FE-001
  route topology, route names, order, guards, shell, and all other children.
- `institution_admin_placeholder_screen.dart`: remove only the now-unused
  Dashboard placeholder class/body. Preserve the five User/Profile/Settings
  placeholder contracts byte-for-byte except unavoidable formatting.

No route constant/path/name/helper change is allowed.

### 11.2 Allowed Test Files

Only these frontend test paths may change:

```text
frontend/test/features/institution_admin/institution_dashboard_dto_test.dart
frontend/test/features/institution_admin/institution_dashboard_remote_data_source_test.dart
frontend/test/features/institution_admin/institution_dashboard_repository_impl_test.dart
frontend/test/features/institution_admin/institution_dashboard_controller_test.dart
frontend/test/features/institution_admin/institution_admin_dashboard_screen_test.dart
frontend/test/features/institution_admin/institution_admin_shell_test.dart
frontend/test/router_bootstrap_test.dart
```

The last two may be modified only to replace S03-FE-001 Dashboard-placeholder/
zero-product-request assumptions with real Dashboard state/repository overrides.
Preserve every unrelated shell, route, role, device, auth, and bootstrap case.

### 11.3 Bookkeeping Files

Only as Section 18 permits:

```text
tasks/frontend/stage-03/S03-FE-002-institution-dashboard-real-data-states.md
tasks/frontend/stage-03/S03-FE-002-CODEX-PROMPT.md
tasks/STAGE_03_TASK_INDEX.md
tasks/README.md
```

### 11.4 Inspect and Preserve

Inspect/reuse but do not modify:

```text
frontend/lib/core/network/**
frontend/lib/core/storage/**
frontend/lib/features/auth/**
frontend/lib/features/platform_admin/**
frontend/lib/features/institution_admin/presentation/institution_admin_shell.dart
frontend/lib/app/router/app_route_paths.dart
frontend/test/app/router/institution_admin_route_paths_test.dart
frontend/test/features/platform_admin/**
frontend/pubspec.yaml
frontend/pubspec.lock
frontend/integration_test/**
backend/**
docker/**
docs/**
```

No other application/test/bookkeeping path may change. Stop instead of
widening scope if the accepted current architecture cannot implement this task
safely within the allowlist.

## 12. Authoritative References

| Source | Exact area | Requirement |
|---|---|---|
| `docs/02-user-roles.md` | `2. Institution Admin` | Own-Institution authority and desktop boundary |
| `docs/03-features.md` | Institution Admin features/dashboard | Basic own-Institution dashboard scope |
| `docs/04-user-flows.md` | Institution Admin Dashboard Flow | Dashboard-first administration flow |
| `docs/05-business-rules.md` | tenant, account, role, data separation | No cross-Institution/client tenant authority |
| `docs/06-roadmap.md` | `8. Stage 3`; `9. Stage 4` | Three totals and later-stage exclusions |
| `docs/07-architecture.md` | Flutter/API/session/tenancy/testing | Layered Riverpod/Dio/server-authoritative design |
| `docs/09-api-contracts.md` | general envelopes/errors; `31.1 Institution Dashboard` | Exact three-total API contract |
| accepted `S03-INT-001` | Stage 3 Dashboard decision | No active split or Group/Learning metrics |
| accepted `S03-BE-001` and implementation/tests | Dashboard API | Exact delivered transport behavior |
| accepted `S03-FE-001` and implementation/tests | shell/routes/placeholders | Dashboard route and protected desktop shell |
| accepted Platform dashboard code/tests | architecture/session/error precedent | Reuse pattern, not business fields |
| `frontend/AGENTS.md` | complete applicable file | Layering, quality, tests, package rules |
| `tasks/STAGE_03_TASK_INDEX.md`, `tasks/README.md` | lifecycle/dependencies | Sequential gate and truthful delivery |

If these conflict, follow the stricter locked contract and stop rather than
silently changing docs, backend, session architecture, or route behavior.

## 13. Acceptance Criteria

- [ ] Both dependencies are proven `Accepted / PASS / Delivered` before work.
- [ ] `/institution-admin` alone loads the exact accepted Dashboard endpoint.
- [ ] Request is one authenticated GET with no body/query/tenant input.
- [ ] DTO requires exactly the three non-negative integer values and accepted
      envelope/objects; malformed data is never coerced.
- [ ] Domain/UI contain exactly Teacher, Student, Parent total counts.
- [ ] No total/active pair, inactive derivation, combined total, or future
      metric is expected or displayed.
- [ ] Initial loading, data, partial-zero, all-zero, error, Retry, and Refresh
      states follow Sections 8–10 exactly.
- [ ] Refresh/Retry deduplicate in-flight intent and stale completions cannot
      overwrite a newer operation/session.
- [ ] AutoDispose/re-entry freshness policy is exact and tested.
- [ ] Invalid/ineligible session context produces zero product requests.
- [ ] Logout, 401 invalidation, same-role cross-tenant switch, and cross-role
      switch expose no old count/error.
- [ ] Existing central invalidation/auth reconciliation remains authoritative;
      no direct token/session mutation is added.
- [ ] Exact headings, card order, labels, values, zero/error/loading copy, keys,
      semantics, keyboard behavior, and responsive layouts are implemented.
- [ ] Non-Dashboard Institution Admin routes issue zero Dashboard requests.
- [ ] S03-FE-001 shell/routes and all prior auth/device/Platform behavior remain
      green.
- [ ] Only the exact allowlisted files change; no backend/docs/package/core
      session/route-path/later-stage drift exists.
- [ ] Format, analyze, focused/full tests, Windows build, and manual smoke pass.
- [ ] Phase 2 has no unresolved P1/P2 before delivery.

## 14. Required Automated Tests

### 14.1 DTO Matrix

Prove:

- exact success and all-zero success;
- each count maps to the correct domain field without swapping;
- `hasNoUsers` is true only when all three are zero;
- missing/invalid envelope, `data`, or `users` fails;
- each missing field fails independently;
- `null`, Boolean, string, double, negative, list, and object fail for each
  required count;
- no malformed value becomes zero;
- harmless additional keys are ignored and never reach the domain.

### 14.2 Remote Data Source and Repository

Prove:

```text
method = GET
relative path = /institution/dashboard
query = none
body/data = none
skip-auth = absent/false
Institution ID = absent everywhere
```

Also prove exact success parsing, Dio error mapping, envelope/format failure to
`invalidResponse`, repository DTO→domain mapping, and failure propagation with
no raw payload disclosure.

### 14.3 Controller and Session Matrix

Prove:

- eligible initial load once and same-session rebuild deduplication;
- non-zero, partial-zero, and all-zero success;
- error with no retained Dashboard;
- Retry transition/success/failure/deduplication;
- Refresh loading/no-stale-count/success/failure/deduplication;
- older completion after Refresh cannot overwrite the newer result;
- completion after provider disposal cannot update state;
- logout while loading removes state and rejects completion;
- Institution Admin A→B with different Institution shows only B;
- A→other role and other role→B do not leak A;
- current `401 authentication_required` reaches central token-version-aware
  invalidation and protected UI disappears;
- stale-token 401 cannot clear a newer session;
- password-change/User-inactive/Institution-inactive code triggers accepted
  bootstrap reconciliation only for current context;
- every ineligible/missing/mismatched session invariant issues zero GETs.

### 14.4 Widget and Accessibility Matrix

Prove:

- exact heading and three ordered cards/values/supporting labels;
- no active/inactive/combined/future text or controls;
- exact partial-zero and all-zero behavior;
- loading has live-region semantics and no counts;
- data/zero Refresh is visible, accessible, keyboard usable, and disabled by
  in-flight state;
- exact safe error messages expose no raw backend detail;
- Retry is accessible, keyboard usable, and deduplicated;
- no stale counts exist in loading/error;
- no overflow/exception at:

  ```text
  800 × 600, text scale 1.0 and 2.0
  1440 × 900, text scale 1.0 and 2.0
  ```

- semantics and focus order remain logical inside the S03-FE-001 shell.

### 14.5 Router, Shell, and Regression Matrix

- direct/reload entry to `/institution-admin` shows one shell and real
  Dashboard state, not the placeholder;
- one root Dashboard GET occurs for eligible entry;
- Users list/create/detail, Institution, and Settings direct entry/navigation
  cause zero Dashboard GETs;
- leaving Dashboard disposes state; returning performs one fresh GET;
- shell navigation, URL reflection, back behavior, title, logout, device/role/
  password guards, malformed-path behavior, and other placeholders remain
  unchanged;
- Platform Owner dashboard and Stage 1 auth/session/router tests remain green.

## 15. Quality and Verification Commands

From `frontend/`, run:

```text
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/features/institution_admin/institution_dashboard_dto_test.dart test/features/institution_admin/institution_dashboard_remote_data_source_test.dart test/features/institution_admin/institution_dashboard_repository_impl_test.dart test/features/institution_admin/institution_dashboard_controller_test.dart test/features/institution_admin/institution_admin_dashboard_screen_test.dart test/features/institution_admin/institution_admin_shell_test.dart test/router_bootstrap_test.dart
flutter test test/features/institution_admin
flutter test
flutter build windows --debug
```

`flutter pub get` must not change `pubspec.yaml` or `pubspec.lock`. Zero tests,
skipped required coverage, warnings, analyzer/format/test/build failure, or an
unexplained environment substitution is not PASS.

Before Phase 2, inspect staged, unstaged, and untracked scope completely:

```text
git status --short
git diff --check
git diff --stat
git diff
git diff --cached --check
git diff --cached --stat
git diff --cached
git ls-files --others --exclude-standard
git status --short -- backend docker docs frontend/pubspec.yaml frontend/pubspec.lock frontend/lib/core frontend/lib/features/auth frontend/lib/features/platform_admin
git diff HEAD -- backend docker docs frontend/pubspec.yaml frontend/pubspec.lock frontend/lib/core frontend/lib/features/auth frontend/lib/features/platform_admin
git diff --cached -- backend docker docs frontend/pubspec.yaml frontend/pubspec.lock frontend/lib/core frontend/lib/features/auth frontend/lib/features/platform_admin
```

Review every changed/untracked file for secrets, bearer tokens, credentials,
private keys, `.env` content, raw sensitive fixtures, tenant IDs used as client
authority, debug output, commented-out code, TODO acceptance gaps, and unrelated
refactors.

## 16. Manual Windows Real-Backend Smoke

Run the Windows app against the accepted Laravel/PostgreSQL stack.

Mandatory sequence:

1. Sign in as an eligible password-complete active Institution Admin.
2. Open `/institution-admin`; verify the shell and one real Dashboard load.
3. Compare displayed Teacher/Student/Parent totals to own-Institution backend
   fixtures containing both active and inactive accounts.
4. Confirm deactivating an eligible account does not reduce the total.
5. Verify an Institution with all three totals zero shows three zero cards plus
   `No users yet.`.
6. Use Refresh and verify one request and an honest loading transition.
7. Stop/unreach the backend safely, Refresh, verify the safe error/no counts,
   restore the backend, and use Retry successfully.
8. Navigate to Users/Institution/Settings and confirm no Dashboard GET occurs.
9. Start a Dashboard request and sign out; confirm protected shell/counts
   disappear immediately and cannot return from a late completion.
10. Sign in as a different Institution Admin and confirm only that Institution's
    totals appear.

Record exact setup, accounts/tenant fixture meaning, observed counts, request
evidence, and PASS/FAIL. Do not fabricate smoke evidence. If the required real
stack cannot be run or a required behavior cannot be verified, Phase 2 cannot
return PASS.

## 17. Explicit Non-Goals and Stop Conditions

### Non-Goals

- Active/inactive User split or any client-derived inactive count.
- Combined User total, percentages, charts, trends, reports, recent Users.
- User list/detail/create/edit/lifecycle UI.
- Institution profile/settings/category UI.
- Groups, relationships, Topics, materials, Homework, Blitz, attempts, scores,
  results, progress, or learning metrics.
- Caching, persistence, polling, background/automatic retry, analytics.
- Backend/schema/docs/API/router topology/core session/package changes.
- S03-FE-003 implementation, S03-INT-002, Closure Review, or Stage 4 work.

### Stop Conditions

Stop on:

- missing/non-delivered dependency;
- response not matching the accepted three-total contract;
- inability to use the current authenticated client/session safely;
- need for client tenant input or backend/docs change;
- conflicting S03-FE-001 route/shell implementation;
- need to change a non-allowlisted application/test path;
- unsafe/dirty/conflicting Git state;
- failed required test/build/smoke;
- material scope expansion.

## 18. Required Four-Phase Workflow and Delivery

Branch:

```text
task/s03-fe-002-institution-dashboard
```

### Phase 0 — Git and Source Preflight

1. Read root `AGENTS.md`, `frontend/AGENTS.md`, this detailed task, paired
   prompt, task README/index, authoritative docs, accepted dependency tasks,
   and current relevant code/tests completely.
2. Record SHA-256 for the approved source task and paired prompt.
3. Verify this task is `Approved` and both dependencies are
   `Accepted / PASS / Delivered` on `origin/main`.
4. Verify remote URL, fetch safely, and prove local `main == origin/main`.
5. Verify the tree is clean except only the owner-prepared S03-FE-002 task and
   paired prompt when they are not yet tracked.
6. Create/switch to the exact branch.
7. Preserve unrelated user work and stop on conflict/unsafe state.
8. Do not commit, push, open a PR, or merge before Phase 2 PASS.

### Phase 1 — Implementation

Implement only this task. Change only the application/test allowlist from
Section 11 plus the permitted bookkeeping files.

During Phase 1:

1. Update only the S03-FE-002 Stage 3 index row to:

   ```text
   In Progress / Not started / Not started
   ```

2. Keep this detailed task `Approved`.
3. Preserve the paired prompt byte-for-byte.
4. Implement the exact API/domain/state/UI/session behavior.
5. Run format, analyze, focused/full tests, Windows build, scope/secret checks,
   and manual smoke.
6. Inspect the complete diff, including untracked owner-prepared task/prompt.
7. Do not stage, commit, push, open a PR, or merge.

### Phase 2 — Strict Read-Only Acceptance Gate

Re-read all authority, the full diff, implementation, tests, exact transport/
parse/state/UI/request/session matrices, scope/secret evidence, commands, and
manual smoke. Phase 2 is strictly read-only:

```text
no edits or auto-fix/write-format
no task/index/README bookkeeping edits
no staging or commit
no push, PR, or merge
no self-fixing findings
```

Classify findings:

- `P1`: auth/session/tenant/cross-account/protected-data/secret exposure,
  destructive Git, or read-only-gate violation;
- `P2`: material API/DTO/request/state/refresh/retry/stale/error/UI/a11y/test/
  build/scope/architecture/workflow mismatch;
- `P3`: non-blocking observation with no correctness, security, required
  evidence, or maintainability-acceptance impact.

Any unresolved P1/P2 returns:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start S03-FE-003. Report every P3; P3 alone
does not block acceptance.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 PASS with no unresolved P1/P2.

1. Change only this detailed task metadata status from `Approved` to
   `Accepted`; do not rewrite approved behavior.
2. Prepare only the S03-FE-002 index row as
   `Accepted / PASS / Delivered` in the delivery commit.
3. Update `tasks/README.md` truthfully: Stage 3 remains `In Progress`,
   S03-FE-002 is the delivered task, and S03-FE-003 is the next execution gate.
4. Preserve later task truth; do not start or accept S03-FE-003.
5. Preserve the paired Codex prompt byte-for-byte and prove its final SHA-256
   equals the Phase 0 source SHA-256.
6. Keep Stage 3 not closed and Stage 4 not started.
7. Re-run non-writing diff, scope, secret, source-integrity, and consistency
   checks.
8. Stage only the exact approved application/test/bookkeeping/task/prompt files.
9. Commit:

   ```text
   feat(institution): add admin dashboard UI
   ```

   Body:

   ```text
   Task: S03-FE-002
   ```

10. Push the exact branch, open a PR to `main`, verify base/head/complete diff,
    and merge only when all required checks are green and merge is safe.
11. Fast-forward local `main` and prove:

    ```text
    local main == origin/main == actual merge commit
    working tree clean
    task commit is ancestor of main
    prompt blob equals approved source bytes
    ```

The prepared Delivered value becomes authoritative only after merge and final
local/remote/clean verification.

If Phase 2 passed but safe delivery cannot finish, return:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Only after complete delivery return:

```text
FINAL STATUS: ACCEPTED
```

## 19. Required Codex Final Report

Report:

1. final status;
2. authority/dependency/preflight/base SHA evidence;
3. source/final task and prompt SHA-256 evidence;
4. implementation summary and every changed file/reason;
5. exact request and DTO/parser matrix;
6. exact controller state/freshness/dedup/stale/session matrix;
7. exact UI/zero/error/Refresh/Retry/a11y/responsive matrix;
8. all acceptance criteria with PASS/FAIL evidence;
9. every command/result and test counts;
10. Windows build and real-backend smoke evidence;
11. P1/P2/P3 findings and Phase 2 decision;
12. scope/secret/no-package/no-backend/no-doc confirmation;
13. task/index/README/prompt-integrity bookkeeping;
14. branch/commit/PR/checks/merge/local-remote-clean delivery evidence.

State exactly:

```text
No active/inactive split, Group/Learning metric, User Management, profile,
settings, category, backend, or route-topology behavior was implemented.
Next implementation gate: S03-FE-003.
```
