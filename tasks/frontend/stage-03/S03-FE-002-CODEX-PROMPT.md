# Codex Execution Prompt — S03-FE-002

Execute only:

```text
S03-FE-002 — Institution Dashboard Real Data and States
```

Repository:

```text
G:\project\testlabuz
```

Approved detailed task:

```text
tasks/frontend/stage-03/S03-FE-002-institution-dashboard-real-data-states.md
```

Exact branch:

```text
task/s03-fe-002-institution-dashboard
```

Do not ask for implementation confirmation. Execute autonomously only if every
Phase 0 dependency/authority/safety gate passes. Stop and report the exact
blocker if a gate fails.

## 1. Authority Order

Read completely before editing:

1. root `AGENTS.md`;
2. `frontend/AGENTS.md`;
3. the approved detailed S03-FE-002 task;
4. this paired prompt;
5. `tasks/README.md` and `tasks/STAGE_03_TASK_INDEX.md`;
6. relevant locked `docs/02–07` and `docs/09-api-contracts.md`, especially
   Section `31.1 Institution Dashboard`;
7. accepted S03-INT-001, S03-BE-001, and S03-FE-001 tasks/evidence;
8. current backend Dashboard route/resource/tests;
9. current S03-FE-001 Institution Admin router/shell/placeholders/tests;
10. accepted auth/session/Dio/error and Platform dashboard patterns/tests;
11. complete current Git state.

Locked docs and delivered backend are authoritative. The detailed task is the
exact execution/scope/test/workflow contract. This prompt cannot widen it.

## 2. Hard Dependency Gate

Before creating the branch or changing code, prove on current `origin/main`:

```text
S03-BE-001 = Accepted / PASS / Delivered
S03-FE-001 = Accepted / PASS / Delivered
S03-FE-002 task = Approved
Stage 3 index/README = truthful and S03-FE-002 next executable gate
local main = origin/main
tree clean except only owner-prepared S03-FE-002 task/prompt if untracked
```

Also prove the accepted backend still returns exactly three totals and the
S03-FE-001 root Dashboard route still owns its placeholder.

If any proof fails, return a blocked preflight report. Preparation of this pair
does not satisfy dependency delivery.

Record SHA-256 of both approved source files. Preserve this prompt byte-for-
byte throughout implementation and delivery.

No commit, push, PR, or merge is allowed before Phase 2 PASS.

## 3. Exact API Contract

Consume only:

```text
GET /api/v1/institution/dashboard
```

The configured Dio base URL already owns `/api/v1`; the remote call is exactly:

```dart
dio.get<Object?>('/institution/dashboard')
```

Send no query, body/data, Institution UUID, `institution_id`, tenant header, or
skip-auth option. Reuse the authenticated Dio client; do not build auth headers
or a second client.

Exact response:

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

Each value is one non-negative integer total containing active and inactive
accounts. There are exactly three product values. There is no total/active pair,
no `active <= total` rule, and no inactive/combined count to derive.

Strict DTO behavior:

- use `ApiSuccessEnvelope.fromJson`;
- require `data.users` map;
- require non-negative Dart integers for `teachers`, `students`, `parents`;
- reject missing/null/Boolean/string/double/negative/list/object values;
- never coerce or retain old values;
- map envelope/format defects to existing `invalidResponse` failure;
- ignore additional transport keys but never expose/render them.

## 4. Required Architecture and Names

Implement the exact layered flow:

```text
InstitutionAdminDashboardScreen
→ InstitutionDashboardController / InstitutionDashboardState
→ InstitutionDashboardRepository
→ InstitutionDashboardRemoteDataSource
→ authenticated Dio
```

Use the detailed task's exact focused type/provider names and keep domain data
limited to:

```text
teachers
students
parents
hasNoUsers
```

Widgets never call Dio/parse JSON. Core network/session code remains unchanged.
Do not create a shared generic dashboard abstraction, new package, cache,
automatic retry, polling, persistence, or alternative framework/client.

## 5. Exact Session and Request Behavior

Fetch only for an authenticated, active, password-complete Institution Admin
whose non-empty `institutionId` matches a non-null Institution object with
status exactly `'active'`.
Use at least User ID + Institution ID as the session identity.

Every invalid, transitional, wrong-role, password-change, missing/mismatched,
inactive session context issues zero Dashboard GETs.

Exact freshness/state policy:

- `/institution-admin` eligible entry → one GET;
- same eligible-session rebuild → no duplicate;
- every other Institution Admin route → zero Dashboard GETs;
- provider is `autoDispose`;
- leave Dashboard → dispose; return → one fresh GET;
- initial/Refresh request → loading with no counts;
- valid response → data; all three zeroes → data plus empty message;
- failure → error with no counts;
- data/zero Refresh → loading, one GET, no duplicate;
- error Retry → same safe error with disabled `Retrying`, one GET;
- no cache, stale-while-revalidate, automatic retry, polling, or background
  refresh.

Use operation generation and current session checks so success/failure after a
newer Refresh/Retry, logout, invalidation, account/tenant/role switch, route
disposal, or provider disposal cannot update UI.

For `401 authentication_required`, rely on the accepted token-version-aware
interceptor/global invalidation. Never clear tokens or emit a second signal in
the feature.

For current `password_change_required`, `user_inactive`, and
`institution_inactive`, invoke accepted `AuthSessionController.bootstrap()`
reconciliation only. Do not mutate auth state directly.

## 6. Exact UI Contract

Heading:

```text
Institution Dashboard
```

Exactly three cards, in order:

```text
Teachers — <teachers.toString()> — Total accounts
Students — <students.toString()> — Total accounts
Parents  — <parents.toString()>  — Total accounts
```

All-zero keeps the three zero cards and adds:

```text
No users yet.
```

Loading semantic label:

```text
Loading institution dashboard
```

Data/zero has one `Refresh`. Error has:

```text
Dashboard unavailable
<exact safe mapped message from detailed task>
Retry
```

Retry-in-flight label is `Retrying`. Use every exact widget key from the
detailed task.

Do not render active/inactive values, combined total, Group/Learning data,
charts, trends, recent Users, reports, identities, contact data, settings,
create/edit shortcuts, or any later-task control.

Keep the accepted shell around valid-session loading/data/zero/error. Ensure
keyboard/semantics/non-color meaning and no overflow at `800×600` and
`1440×900`, text scale `1.0` and `2.0`.

## 7. Exact Application/Test Allowlist

Only these application paths may change:

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

In `app_router.dart`, replace only the root Dashboard placeholder child/import.
Do not change route topology/names/paths/order/guards/other children.

In the placeholder file, remove only the obsolete Dashboard placeholder;
preserve all five remaining placeholders.

Only these test paths may change:

```text
frontend/test/features/institution_admin/institution_dashboard_dto_test.dart
frontend/test/features/institution_admin/institution_dashboard_remote_data_source_test.dart
frontend/test/features/institution_admin/institution_dashboard_repository_impl_test.dart
frontend/test/features/institution_admin/institution_dashboard_controller_test.dart
frontend/test/features/institution_admin/institution_admin_dashboard_screen_test.dart
frontend/test/features/institution_admin/institution_admin_shell_test.dart
frontend/test/router_bootstrap_test.dart
```

The existing shell/bootstrap tests may change only for the real Dashboard
repository/state/request expectation. Preserve unrelated S03-FE-001 and Stage
1/2 assertions.

Permitted bookkeeping/authority files only:

```text
tasks/frontend/stage-03/S03-FE-002-institution-dashboard-real-data-states.md
tasks/frontend/stage-03/S03-FE-002-CODEX-PROMPT.md
tasks/STAGE_03_TASK_INDEX.md
tasks/README.md
```

Preserve everything else, especially:

```text
backend/**
docker/**
docs/**
frontend/lib/core/**
frontend/lib/features/auth/**
frontend/lib/features/platform_admin/**
frontend/lib/features/institution_admin/presentation/institution_admin_shell.dart
frontend/lib/app/router/app_route_paths.dart
frontend/test/app/router/institution_admin_route_paths_test.dart
frontend/test/features/platform_admin/**
frontend/pubspec.yaml
frontend/pubspec.lock
frontend/integration_test/**
```

Stop instead of widening the allowlist.

## 8. Required Tests

Implement every detailed-task matrix:

1. DTO exact/zero/missing/shape/type/negative/additional-key cases.
2. Exact GET relative path, no query/body/tenant/skip-auth, authenticated
   transport, Dio/format failure mapping.
3. Repository DTO→domain mapping/failure propagation.
4. Controller initial/data/partial-zero/all-zero/error/Retry/Refresh/in-flight
   dedup/stale-generation/disposal behavior.
5. No request for ineligible session or non-Dashboard route.
6. Logout, central current/stale-token 401 behavior, password/lifecycle
   reconciliation, A→B Institution Admin, and cross-role isolation.
7. Exact cards/labels/values/keys and forbidden-content absence.
8. Loading/zero/error/Retry/Refresh semantics, keyboard, responsive/text-scale
   behavior.
9. Direct/reload/navigation/back/autoDispose/fresh re-entry and S03-FE-001
   shell/guard regression.
10. Full Platform/Auth/Router/frontend regression.

## 9. Verification

From `frontend/`:

```text
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/features/institution_admin/institution_dashboard_dto_test.dart test/features/institution_admin/institution_dashboard_remote_data_source_test.dart test/features/institution_admin/institution_dashboard_repository_impl_test.dart test/features/institution_admin/institution_dashboard_controller_test.dart test/features/institution_admin/institution_admin_dashboard_screen_test.dart test/features/institution_admin/institution_admin_shell_test.dart test/router_bootstrap_test.dart
flutter test test/features/institution_admin
flutter test
flutter build windows --debug
```

No pubspec/lock change is allowed. Run complete diff/untracked/scope/secret
checks from the detailed task. Inspect every changed file. Do not claim PASS for
zero/skipped tests, warning, failure, or fabricated evidence.

Run the complete mandatory Windows real-Laravel/PostgreSQL smoke from the task:
real mixed active/inactive totals, all-zero, Refresh, offline error→Retry,
non-Dashboard no-request, logout-during-load, and second-Institution isolation.
Failure/inability to verify blocks Phase 2 PASS.

## 10. Four-Phase Workflow

### Phase 0 — Preflight

- Read all authority/current code/tests.
- Hash source task/prompt.
- Prove dependency delivery, current remote/main equality, safe tree.
- Create exact branch.
- No implementation on failed gate.
- No commit/push/PR/merge before Phase 2 PASS.

### Phase 1 — Implementation

- Change only the exact allowlist.
- Mark only S03-FE-002 index row
  `In Progress / Not started / Not started`.
- Keep task `Approved` and prompt byte-identical.
- Implement, test, build, smoke, and inspect complete scope.
- Do not stage/commit/push/PR/merge.

### Phase 2 — Strict Read-Only Acceptance

No edit, formatter write, auto-fix, bookkeeping change, staging, commit, push,
PR, merge, or self-fix is allowed.

Classify:

```text
P1 = auth/session/tenant/cross-account/protected-data/secret/destructive-Git/read-only breach
P2 = material API/DTO/request/state/refresh/retry/stale/error/UI/a11y/test/build/scope/architecture/workflow defect
P3 = non-blocking observation with no correctness/security/evidence/maintainability impact
```

Any unresolved P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop with no delivery and do not start S03-FE-003. Report P3; P3 alone does not
block acceptance.

### Phase 3 — Delivery After PASS Only

1. Change only task status `Approved` → `Accepted`.
2. Prepare only S03-FE-002 row as `Accepted / PASS / Delivered` in the delivery
   commit.
3. Update README truthfully: Stage 3 In Progress, S03-FE-002 delivered,
   S03-FE-003 next gate.
4. Preserve later task states and Stage 4 block.
5. Prove prompt final SHA equals source SHA.
6. Stage only exact approved files.
7. Commit:

   ```text
   feat(institution): add admin dashboard UI

   Task: S03-FE-002
   ```

8. Push exact branch; open/verify PR to `main`; require safe green checks; merge.
9. Fast-forward local main and prove local main/origin main/merge equality,
   ancestry, clean tree, and prompt blob integrity.

If Phase 2 passed but delivery cannot finish:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Only complete verified delivery:

```text
FINAL STATUS: ACCEPTED
```

## 11. Required Final Response

Return every detailed-task report item: final status, dependency/base evidence,
source/final hashes, changed files, request/parser/state/session/UI matrices,
all acceptance results, commands/test counts/build/smoke, P1/P2/P3 findings,
scope/secret/bookkeeping/prompt integrity, and PR/merge/local-remote-clean
delivery evidence.

End with:

```text
No active/inactive split, Group/Learning metric, User Management, profile,
settings, category, backend, or route-topology behavior was implemented.
Next implementation gate: S03-FE-003.
```
