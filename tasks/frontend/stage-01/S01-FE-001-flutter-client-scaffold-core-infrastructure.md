# Codex Task: Flutter Client Scaffold & Core Infrastructure

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S01-FE-001` |
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Area | `Frontend / Flutter foundation` |
| Status | `Approved` |
| Depends on | `S01-BE-005 — Role Authorization Foundation (Accepted)` |
| Blocks | `S01-FE-002 — Authentication Data & Session Foundation` |

This task is approved for Codex execution.

Codex must still enforce all dependency, Git preflight, scope, verification,
read-only acceptance, and GitHub delivery gates defined below.

## 2. Goal

Create the real Flutter client application under `frontend/` and establish the
smallest production-quality client architecture required by the remaining
Stage 1 frontend tasks.

The accepted result must provide:

- a genuine Flutter application scaffold;
- Riverpod application bootstrap and dependency injection;
- GoRouter navigation foundation;
- Dio HTTP client foundation;
- typed API envelope/error parsing aligned with the locked Laravel contract;
- secure-storage abstraction backed by `flutter_secure_storage`;
- validated compile-time API configuration;
- a minimal technical root screen only for scaffold verification;
- unit/widget tests for the core client infrastructure;
- clean Flutter analysis/format/test/build gates.

This task is a **client foundation** task.

It must not implement:

- login UI;
- login/logout API calls;
- `/auth/me` session bootstrap;
- token injection/interceptors;
- authentication state;
- first-login password-change UX;
- role/device route guards;
- role entry shells;
- Stage 2+ product UI.

## 3. Current Context

Repository:

`G:\project\testlabuz`

Approved GitHub remote:

`https://github.com/Shoxrux2017/testlabuz.git`

Required dependency:

`S01-BE-005 = Accepted`

The Stage 1 index defines this task as:

> Flutter scaffold, Riverpod/GoRouter/Dio/core client quality foundation.

The locked architecture assigns Flutter:

- desktop and mobile client responsibilities;
- Riverpod for state management/dependency injection;
- GoRouter for navigation;
- Dio for HTTP;
- DTO/repository boundaries;
- secure token storage;
- route guards and role/device routing in later focused tasks.

The approved role/device model is:

```text
Platform Owner / Super Admin → desktop
Institution Admin            → desktop
Teacher                      → desktop + mobile
Student                      → desktop + mobile
Parent                       → mobile
```

This task prepares one Flutter codebase for those later surfaces but does not
implement their role routing yet.

## 4. Flutter / Package Baseline

### 4.1 Flutter SDK

Task-preparation baseline on `2026-08-09`:

- stable Flutter release family: `3.44.x`;
- Flutter documentation currently reflects `3.44.7`;
- bundled Dart line is compatible with Dart `3.12`.

Preferred execution baseline:

```text
Flutter 3.44.7 stable
```

Codex must verify the actual installed Flutter SDK before scaffolding.

Do not:

- silently downgrade Flutter;
- switch to beta/dev/master;
- modify a global Flutter installation without explicit user approval;
- install or change FVM globally merely for this task.

If the required stable Flutter toolchain is not safely available, stop and
report the environment blocker.

### 4.2 Approved foundation dependencies

Use these current stable package baselines unless the exact installed Flutter
3.44.x resolver proves a documented incompatibility:

```yaml
flutter_riverpod: ^3.4.2
go_router: ^17.4.0
dio: ^5.11.0
flutter_secure_storage: ^11.0.0
```

Use the framework-generated supported `flutter_lints` dev dependency.

Do not add a dependency merely because it is popular.

Specifically do not add in this task:

- Bloc / Provider / GetX / MobX;
- get_it;
- auto_route;
- retrofit;
- freezed;
- json_serializable;
- build_runner;
- hive / isar / drift / sqflite;
- shared_preferences for auth secrets;
- logger packages;
- dotenv packages;
- Firebase;
- analytics/crash-reporting SDKs;
- localization packages beyond Flutter SDK defaults;
- UI/design-system packages.

Future tasks may add a package only when a concrete approved requirement needs
it.

Commit `pubspec.lock`.

## 5. Included Scope

### 5.1 Git / dependency preflight

Before implementation:

1. Read root `AGENTS.md`.
2. Read `frontend/AGENTS.md`.
3. Read this complete approved task.
4. Read only the locked specification sections referenced by this task.
5. Verify `S01-BE-005` is `Accepted`.
6. Verify its accepted result is present on `origin/main`.
7. Verify the approved `origin`.
8. Fetch remote state safely.
9. Verify local `main == origin/main`.
10. Verify no unrelated dirty state exists.

Required task branch:

`task/s01-fe-001-flutter-foundation`

If the project owner already saved this approved task and
`S01-FE-001-CODEX-PROMPT.md` under `tasks/frontend/stage-01/` before execution,
those exact preparation files are permitted pre-task additions.

In that case:

- verify they are the only permitted pre-task additions;
- do not commit them on `main`;
- create the task branch immediately from synchronized `main`;
- carry them into the task branch;
- perform implementation/delivery only from the task branch.

Any other unexplained dirty state is a blocker.

### 5.2 Flutter environment preflight

Run safe equivalents:

```text
flutter --version
dart --version
flutter doctor -v
flutter config
```

Required:

- stable Flutter `3.44.x`;
- Dart compatible with selected package constraints;
- Windows desktop toolchain available for canonical desktop verification;
- Android toolchain sufficiently available for canonical mobile build
  verification.

Do not change global Android/Visual Studio/Flutter configuration automatically.

If Windows or Android build tooling is missing, report the environment blocker
instead of pretending target verification passed.

iOS/macOS compilation is not required from the Windows development host.

### 5.3 Genuine Flutter scaffold

Create a real Flutter application under:

`frontend/`

Preserve existing:

`frontend/AGENTS.md`

exactly.

Because `frontend/` already contains `AGENTS.md`, use a safe temporary scaffold
approach:

1. create a fresh Flutter app in a safe temporary directory outside the
   repository;
2. verify the generated scaffold;
3. copy/move the generated Flutter app into `frontend/` while preserving
   `frontend/AGENTS.md`;
4. ensure no nested `.git/` is introduced;
5. remove temporary scaffold artifacts when safe.

Do not hand-build a fake Flutter project tree.

Project package/name should be a valid Dart package form related to TestLabUz.

Do not treat generated bundle/application identifiers as finalized production
distribution identifiers unless they are already locked elsewhere in the
repository. Do not spend this task inventing release-store metadata.

A standard Flutter scaffold may contain platform support directories produced
by Flutter. Do not add web-specific product behavior merely because Flutter can
generate web support.

### 5.4 Application bootstrap

Create a clean bootstrap:

```text
main()
→ WidgetsFlutterBinding.ensureInitialized()
→ ProviderScope
→ TestLabUzApp
```

`TestLabUzApp` must use:

```text
MaterialApp.router
```

with the accepted GoRouter instance.

Do not perform auth bootstrap in `main()`.

Do not read/write auth token in this task.

Do not perform network calls during app construction.

### 5.5 Minimal source organization

Use the locked architectural direction without creating empty speculative
layers.

Expected logical foundation:

```text
frontend/lib/
  main.dart

  app/
    app.dart
    config/
    router/

  core/
    network/
    storage/

  shared/
    ...
```

Create only directories/files actually used by this task.

Do not pre-create every future feature folder.

`features/auth/` should not contain implemented auth behavior in this task.

Do not create:

```text
features/topics/
features/homework/
features/blitz/
features/reports/
```

or other later feature trees.

### 5.6 App configuration

Create a small immutable `AppConfig` abstraction.

API base URL must come from a compile-time environment value such as:

```text
--dart-define=API_BASE_URL=...
```

Do not use a committed `.env` file.

Required validation:

- non-empty;
- valid absolute URI;
- scheme is `http` or `https`;
- no embedded username/password;
- no query/fragment;
- client API base path resolves to `/api/v1`.

Recommended examples for documentation only:

Windows desktop local runtime:

```text
http://127.0.0.1:<port>/api/v1
```

Android emulator local runtime:

```text
http://10.0.2.2:<port>/api/v1
```

Do not hard-code either address as global authority.

Tests may create `AppConfig` directly without compile-time environment.

If the real app launches without a required API base URL, fail early with a
clear non-secret configuration error rather than silently using an unexpected
server.

### 5.7 Riverpod foundation

Wrap the application in `ProviderScope`.

Create only providers required now, such as:

- app configuration provider;
- Dio/client provider;
- secure-storage provider;
- GoRouter provider if that matches the clean accepted architecture.

Prefer Riverpod 3 current APIs.

Do not introduce deprecated StateNotifier-based architecture merely from old
examples when a simpler current Provider/Notifier-compatible foundation is
available.

Do not create auth/session providers yet.

### 5.8 Dio client foundation

Create one central Dio construction boundary.

Requirements:

- base URL comes only from validated `AppConfig`;
- JSON request/response expectation;
- reasonable connect/send/receive timeouts;
- no hard-coded production URL;
- no Bearer token interceptor yet;
- no refresh-token interceptor;
- no retry package/interceptor;
- no cookie session handling;
- no request body/token logging.

Do not enable a Dio `LogInterceptor` that can expose sensitive headers or
payloads later.

If basic diagnostic logging is added, it must be metadata-only and safe by
construction.

### 5.9 API success/error envelope model

Align with the accepted TestLabUz backend API contract.

Create a small typed representation for success payload extraction as needed.

For API errors, support:

```json
{
  "message": "Human-readable message.",
  "code": "stable_machine_code",
  "errors": {},
  "request_id": "optional-id"
}
```

Client failure model should preserve at minimum:

```text
HTTP status (when available)
server code (when available)
message
field errors
request_id
failure kind
```

`errors` must be treated as an object/map.

Validation errors may map:

```text
field -> list of messages
```

Do not parse human-readable message text to decide application control flow.

Do not invent new backend stable machine codes.

Local-only transport failure categories may include concepts such as:

```text
connection
timeout
cancelled
invalid_response
unknown
```

These are Flutter-internal failure categories and must not be represented as
server API codes.

### 5.10 Dio failure mapper

Create one centralized mapping from `DioException` / malformed response into
the typed client failure model.

Required behavior:

- correctly parse the backend error envelope when available;
- preserve backend machine code;
- preserve field validation errors;
- preserve optional request ID;
- distinguish transport/timeout/cancellation failures from server responses;
- tolerate malformed/non-JSON upstream failures without crashing;
- never expose authorization tokens or request secrets in user-facing failure
  objects.

Do not implement UI error messages beyond minimal technical scaffold behavior.

### 5.11 Secure storage foundation

Create a small testable secure-storage boundary backed by:

`flutter_secure_storage`

This task must prove that sensitive-value storage is encapsulated and not mixed
through widgets/repositories.

The abstraction may be generic or token-oriented, but this task must **not**
implement actual auth-session persistence behavior.

Requirements:

- no token key is written during normal foundation app startup;
- storage implementation is injectable/testable;
- no secret value is logged;
- no fallback to `SharedPreferences` for authentication secrets;
- platform plugin is not called from pure domain/model objects;
- FE-002 can reuse this boundary for the real auth token.

Do not add encryption keys to source control.

### 5.12 GoRouter foundation

Create the central GoRouter instance and route constants.

This task needs only a minimal technical root route proving router/bootstrap
correctness.

Do not add production:

```text
/login
/change-password
/platform-owner
/institution-admin
/teacher
/student
/parent
```

routes yet.

Those routes belong to later Stage 1 tasks.

Do not implement authentication redirect logic yet.

The temporary technical root screen must not pretend to be a real dashboard or
product feature.

It may display a simple technical TestLabUz foundation label solely to prove
the app renders.

### 5.13 Theme / UI boundary

Use a minimal app theme based on standard Flutter Material APIs.

Do not build the project design system in this task.

Do not invent product dashboards, cards, navigation rails, role menus, or
feature placeholders.

The only required visible UI is enough to verify:

- Flutter boots;
- router resolves;
- widget tree is stable.

### 5.14 Generated sample cleanup

Remove/rewrite default Flutter counter-demo content.

The repository must not retain:

- counter demo state;
- sample increment button;
- meaningless default widget test asserting counter behavior.

Keep only relevant foundation tests.

### 5.15 Documentation

Add concise frontend development instructions in the appropriate existing
frontend/project documentation location.

Document:

- required Flutter stable line;
- `flutter pub get`;
- API base URL via `--dart-define`;
- Windows local example;
- Android emulator local example;
- analyze/test/format commands;
- Windows and Android build verification commands.

Do not duplicate the entire architecture document.

## 6. Architecture Boundaries

### 6.1 Flutter layers

This task establishes the foundation for:

```text
presentation
→ Riverpod controller/provider
→ repository
→ remote/local data source
```

but does not create feature repositories/controllers without a real feature.

For this task, only core infrastructure is needed.

### 6.2 DTO/domain boundary

API JSON should not leak directly into widgets.

However, no auth DTO/domain model is implemented yet.

The generic API parsing foundation should be sufficient for `S01-FE-002` to add
real authentication DTOs cleanly.

Do not create speculative Topic/User/Institution Flutter domain models here.

### 6.3 Client authority

Flutter never becomes authorization authority.

This task must not create client-side role rules.

Later route guards improve UX, but backend remains authoritative.

## 7. Relevant Files

Expected high-value change surface:

| Path | Expected action |
|---|---|
| `frontend/AGENTS.md` | Preserve |
| `frontend/pubspec.yaml` | Create via scaffold and add approved dependencies |
| `frontend/pubspec.lock` | Create/commit |
| `frontend/analysis_options.yaml` | Preserve scaffold quality baseline; minimal refinement only if justified |
| `frontend/lib/main.dart` | Create clean bootstrap |
| `frontend/lib/app/app.dart` | Create app root |
| `frontend/lib/app/config/*` | Create validated AppConfig/provider |
| `frontend/lib/app/router/*` | Create GoRouter foundation |
| `frontend/lib/core/network/*` | Create Dio/API envelope/failure infrastructure |
| `frontend/lib/core/storage/*` | Create secure storage abstraction |
| `frontend/test/*` | Replace sample test/add focused foundation tests |
| platform directories from official Flutter scaffold | Preserve official scaffold |
| `tasks/frontend/stage-01/S01-FE-001-flutter-client-scaffold-core-infrastructure.md` | Preserve |
| `tasks/frontend/stage-01/S01-FE-001-CODEX-PROMPT.md` | Preserve |
| `tasks/STAGE_01_TASK_INDEX.md` | Lifecycle update only |

Do not modify:

- locked `docs/01–09`;
- `backend/`;
- `docker/`.

If a dependency defect requires those changes, stop and report.

## 8. Authoritative Specification References

| Document | Section | Requirement |
|---|---|---|
| `docs/06-roadmap.md` | `2.1 Vertical Development` | Stage 1 integrates required backend + desktop/mobile layers |
| `docs/06-roadmap.md` | `2.6 Desktop and Mobile Scope` | Platform Owner/Admin desktop; Teacher/Student both; Parent mobile |
| `docs/06-roadmap.md` | `6. Stage 1 — Authentication and Role-Based Entry` | Desktop/mobile login, protected navigation, correct role entry are Stage 1 |
| `docs/07-architecture.md` | `2.2 Frontend` | Flutter client baseline |
| `docs/07-architecture.md` | `20. Flutter Application Architecture` | Riverpod, GoRouter, Dio, DTO/repository boundaries, secure storage |
| `docs/07-architecture.md` | `21. Flutter Navigation Architecture` | Central role-aware navigation foundation |
| `docs/07-architecture.md` | `22. Role/Device Feature Boundary` | Approved desktop/mobile role surfaces |
| `docs/07-architecture.md` | `23. API Boundary Principles` | Backend remains authority; versioned API/error contracts |
| `docs/07-architecture.md` | `32. Testing Architecture` | Flutter tests are architectural requirement |
| `docs/07-architecture.md` | `39. CI and Quality Gates` | Flutter analyze/test/format are quality gates when project exists |
| `frontend/AGENTS.md` | Entire applicable file | Frontend-specific implementation rules |
| `AGENTS.md` | Current task/Git workflow | Branch/review/delivery/scope |
| `tasks/STAGE_01_TASK_INDEX.md` | `S01-FE-001` row | Approved Flutter foundation dependency/order |

## 9. External Technical Baseline

These current framework/package references guide implementation but do not
replace locked TestLabUz product contracts.

At task preparation time (`2026-08-09`):

- Flutter stable release family is `3.44.x`;
- official Flutter docs reflect `3.44.7`;
- `flutter_riverpod 3.4.2` is current stable and requires Dart `3.12`;
- `go_router 17.4.0` is current stable;
- `dio 5.11.0` is current stable;
- `flutter_secure_storage 11.0.0` is current stable.

If package state materially changes before execution and the approved exact
versions no longer resolve with Flutter 3.44.x, do not silently jump major
versions. Report the compatibility blocker.

## 10. Functional Requirements

1. `S01-BE-005` independently verified `Accepted`.
2. Work occurs on `task/s01-fe-001-flutter-foundation`.
3. Genuine Flutter 3.44.x scaffold exists under `frontend/`.
4. `frontend/AGENTS.md` preserved.
5. No nested `.git/` exists under frontend.
6. Default counter demo removed.
7. `ProviderScope` is application root infrastructure.
8. App uses `MaterialApp.router`.
9. GoRouter central router exists.
10. No auth/role route guards implemented.
11. Dio central client exists.
12. API base URL comes from validated compile-time config.
13. No hard-coded authoritative local/production API URL.
14. API base resolves to `/api/v1`.
15. No Bearer-token interceptor implemented.
16. Typed API error/failure model exists.
17. Backend `message`, `code`, `errors`, `request_id` can be parsed.
18. Validation field errors are preserved.
19. Transport failures are represented separately from server API codes.
20. Secure storage abstraction backed by flutter_secure_storage exists.
21. No real auth token is written/read as session behavior.
22. Core infrastructure is provider-injectable/testable.
23. Minimal technical root renders.
24. No login/change-password/dashboard/product UI exists.
25. `pubspec.lock` committed.
26. `flutter analyze` passes.
27. `flutter test` passes.
28. Dart formatting check passes.
29. Windows debug build passes on the canonical Windows development host.
30. Android debug APK build passes on the canonical mobile verification target.
31. No backend/docker/locked-doc change occurs.
32. No secret/config file containing credentials is committed.

## 11. Required Automated Tests

### 11.1 AppConfig tests

Test:

- valid HTTPS `/api/v1` URL accepted;
- valid HTTP local `/api/v1` URL accepted;
- empty rejected;
- relative URI rejected;
- unsupported scheme rejected;
- embedded credentials rejected;
- query/fragment rejected;
- wrong/missing API base path rejected.

### 11.2 API error parsing tests

Test representative backend payloads:

- `422 validation_failed` with multiple field errors;
- `401 authentication_required`;
- `403 forbidden`;
- `404 resource_not_found`;
- `429 rate_limited`;
- `500 server_error`;
- optional `request_id`;
- `errors = {}`.

Assert stable server code remains unchanged.

### 11.3 Dio failure mapping tests

Test:

- valid JSON API error;
- malformed server body;
- connection failure;
- connection timeout;
- receive timeout;
- cancellation;
- unexpected failure.

No test should require a real production backend.

### 11.4 Secure storage boundary tests

Use fake/mock boundary behavior without persisting real secrets.

Prove:

- callers depend on abstraction;
- write/read/delete behavior can be substituted in tests;
- implementation does not log values.

Do not require actual platform Keychain/Keystore in pure unit tests.

### 11.5 Router/bootstrap widget tests

Prove:

- app creates with ProviderScope;
- MaterialApp.router resolves the technical root;
- technical root renders;
- no default counter demo remains;
- no login/role route is accidentally introduced.

### 11.6 Dependency boundary tests/review

Verify no auth session/controller/repository implementation exists yet.

A code review/grep-based guard may be used in addition to tests.

## 12. Quality / Verification Commands

From `frontend/`, run:

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
flutter build windows --debug
flutter build apk --debug
```

Also inspect:

```text
flutter --version
dart --version
flutter doctor -v
flutter pub deps
```

If supported by the current Flutter version, run dependency validation/reporting
commands such as:

```text
flutter pub outdated
```

for evidence only; do not perform unrelated upgrades after the approved
dependency baseline is resolved.

### 12.1 Source-control checks

Before acceptance gate:

```text
git status --short
git diff --check
git diff main...HEAD -- docs
git diff main...HEAD -- backend
git diff main...HEAD -- docker
```

Expected:

- docs unchanged;
- backend unchanged;
- docker unchanged.

Scan tracked/staged files for:

- `.env`;
- API tokens;
- passwords;
- private keys/certificates;
- credential-bearing URLs.

Do not print secrets.

## 13. Manual Smoke Check

On Windows:

1. Start the accepted backend runtime separately if needed only to know a local
   API URL; no network call is required by the foundation app.
2. Run Flutter with a valid desktop API base define, for example:
   `--dart-define=API_BASE_URL=http://127.0.0.1:<port>/api/v1`.
3. Confirm app launches.
4. Confirm technical TestLabUz root renders.
5. Confirm no counter demo/login/dashboard/product placeholder appears.
6. Confirm app startup makes no unintended auth/network call.
7. Confirm no secret/token is written to secure storage merely from startup.

For Android emulator build verification, use a mobile-appropriate local URL
when an actual runtime launch is performed.

## 14. Explicit Non-Goals

- Login UI.
- Login API integration.
- Logout API integration.
- `/auth/me` API integration.
- Auth DTOs/domain user model.
- Auth repository.
- Session controller/provider.
- Token Authorization header interceptor.
- Refresh/retry auth.
- First-login password-change UI.
- Role/device guards.
- Platform Owner/Admin/Teacher/Student/Parent entry shells.
- Dashboard/navigation rail/tab bar.
- Feature placeholders.
- Design system.
- Localization implementation.
- Offline/cache database.
- Analytics/crash reporting.
- Firebase.
- CI.
- Backend/Docker changes.
- Stage 2+ features.
- Production store signing/release metadata.

## 15. Stop Conditions

Stop and report instead of improvising if:

- `S01-BE-005` is not `Accepted`;
- accepted Stage 1 backend result is absent from `origin/main`;
- local `main` cannot safely synchronize;
- unrelated dirty state exists;
- required task branch cannot be created safely;
- Flutter stable 3.44.x is unavailable;
- Dart/package resolver cannot support approved dependency set;
- Windows or Android toolchain required for canonical builds is missing;
- scaffolding requires deleting/overwriting `frontend/AGENTS.md`;
- correct implementation requires inventing final distribution identifiers;
- locked architecture conflicts with Riverpod/GoRouter/Dio/secure storage;
- auth behavior from `S01-FE-002` is required to make this task pass;
- product UI from later tasks is required;
- secret material would need to be committed;
- safe completion requires destructive Git operations/force-push/history
  rewrite/check bypass;
- material scope expansion is required.

## 16. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git Preflight

1. Complete Git/environment preflight.
2. Create/switch to:
   `task/s01-fe-001-flutter-foundation`.
3. Ensure approved task/prompt are on task branch.
4. Update only `S01-FE-001` Stage 1 index row to `Approved` if required by
   current repository workflow.
5. Do not commit/push.

### Phase 1 — Implementation

Implement only this task.

Run:

- scaffold verification;
- dependency resolution;
- AppConfig tests;
- API envelope/failure tests;
- secure storage abstraction tests;
- router/bootstrap tests;
- full Flutter tests;
- analyze;
- format;
- Windows debug build;
- Android debug build;
- secret/scope checks.

Do not commit/push.

### Phase 2 — Read-Only Acceptance Gate

Re-read:

- complete `S01-FE-001`;
- root/frontend `AGENTS.md`;
- referenced locked contracts;
- complete task branch diff;
- dependency state;
- all test/analyze/build evidence.

No edits, fixes, new staging, commit, push, or merge.

Findings:

- `P1` blocking security/architecture/build issue;
- `P2` material contract/test/scope mismatch;
- `P3` non-blocking observation.

If any P1/P2 remains:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop and do not self-fix after Phase 2 starts.

### Phase 3 — Post-Acceptance Git Delivery

Only after Phase 2 PASS:

1. Change this task status to `Accepted`.
2. Update Stage 1 index:
   - Task `Accepted`;
   - Review `PASS`;
   - Delivery finalized after merge.
3. Re-run final analyze/test/format if bookkeeping unexpectedly touched
   executable files, plus:
   - `git diff --check`;
   - secret scan;
   - backend/docker/docs scope checks.
4. Stage only approved changes.
5. Create one focused commit.

Preferred commit subject:

```text
feat(frontend): scaffold Flutter client foundation
```

Body:

```text
Task: S01-FE-001
```

6. Push task branch.
7. Create PR to `main`.
8. Do not bypass branch protection/checks.
9. Merge only when safely mergeable and required checks pass.
10. Delete remote task branch after merge if normal policy permits.
11. Synchronize local `main` with `origin/main` using fast-forward-safe
    operations.
12. Verify:
    - local `main == origin/main`;
    - working tree clean;
    - accepted task/index state exists on `origin/main`.

If Phase 2 passed but delivery cannot safely complete:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Do not start `S01-FE-002`.

If all succeeds:

```text
FINAL STATUS: ACCEPTED
```

## 17. Required Codex Final Report

Return:

1. Final status: `ACCEPTED`, `NOT ACCEPTED`, or `DELIVERY BLOCKED`.
2. Dependency/Git/environment preflight:
   - Flutter/Dart versions;
   - doctor summary;
   - task branch.
3. Implementation summary.
4. Changed files grouped by:
   - Flutter scaffold;
   - app/config/router;
   - network;
   - storage;
   - tests;
   - task bookkeeping.
5. Dependency versions resolved in `pubspec.lock`.
6. AppConfig/API base validation evidence.
7. API error/failure parsing evidence.
8. Secure storage abstraction evidence.
9. Router/bootstrap evidence.
10. Acceptance findings.
11. Acceptance criteria PASS/FAIL individually.
12. Quality gates:
    - analyze;
    - tests;
    - format;
    - Windows build;
    - Android build.
13. Security/scope evidence.
14. GitHub delivery evidence:
    - commit hash/subject;
    - branch;
    - PR reference;
    - merge result;
    - local/main hashes;
    - clean status.
15. Manual smoke status.
16. Remaining blockers/deviations.

Do not start `S01-FE-002`.
