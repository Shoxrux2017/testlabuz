# Codex Task: Authentication Data & Session Foundation

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S01-FE-002` |
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Area | `Frontend / authentication data and session` |
| Status | `Approved` |
| Depends on | `S01-FE-001 — Flutter Client Scaffold & Core Infrastructure (Accepted)`; `S01-BE-003 — Sanctum Authentication & Session API (Accepted)` |
| Blocks | `S01-FE-003 — Login & First-Login Password Change UX` |

This task is approved for Codex execution.

Codex must still enforce all dependency, Git preflight, scope, verification,
read-only acceptance, and GitHub delivery gates defined below.

## 2. Goal

Implement the Flutter authentication **data/session foundation** on top of the
accepted core client infrastructure and accepted backend auth API.

The accepted result must provide:

- typed auth DTO/domain models for the locked backend contract;
- `AuthRemoteDataSource` / `AuthRepository` boundaries;
- login, logout, and `/auth/me` data operations;
- secure Sanctum access-token persistence;
- Bearer-token injection for authenticated API requests;
- no token attachment to public login requests;
- app-start session restoration through `/api/v1/auth/me`;
- current authenticated session state driven by server data;
- invalid/revoked-token session invalidation;
- local logout/session cleanup;
- account-switch/race protection so stale previous-user results cannot overwrite
  the current session;
- Riverpod providers/controllers needed by later Stage 1 UI tasks;
- comprehensive unit/provider tests.

This task does **not** implement login/password-change screens or role/device
navigation.

## 3. Current Context

Repository:

`G:\project\testlabuz`

Approved GitHub remote:

`https://github.com/Shoxrux2017/testlabuz.git`

Required dependencies:

```text
S01-FE-001 = Accepted
S01-BE-003 = Accepted
```

Accepted frontend foundation is expected to provide:

- Flutter application scaffold;
- ProviderScope / Riverpod;
- MaterialApp.router / GoRouter foundation;
- validated `/api/v1` `AppConfig`;
- central Dio construction boundary;
- typed generic API failure/error parsing;
- secure-storage abstraction backed by `flutter_secure_storage`;
- Flutter analyze/test/build quality baseline.

Accepted backend auth API is expected to provide:

```text
POST /api/v1/auth/login
POST /api/v1/auth/logout
GET  /api/v1/auth/me
```

with Sanctum Bearer tokens and server-authoritative user/role/institution state.

`S01-BE-004` may later add `/auth/change-password`, but this frontend task must
not depend on that endpoint. `S01-FE-003` owns password-change UI/API wiring.

Codex must independently verify the actual accepted dependencies on
`origin/main`.

## 4. Locked Authentication Client Contract

### 4.1 Login

Endpoint relative to accepted `/api/v1` base:

```text
POST /auth/login
```

Request:

```json
{
  "login": "teacher01",
  "password": "secret"
}
```

The public field is exactly:

```text
login
```

Do not send `login_name` as the public request field.

Do not send client-authoritative:

```text
role
institution_id
must_change_password
is_active
```

Success body contains:

```text
data.token
data.token_type
data.user
```

with user fields:

```text
id
institution_id
role
full_name
login_name
email
phone
is_active
must_change_password
```

### 4.2 Current session

Endpoint:

```text
GET /auth/me
```

Returns server-authoritative current user plus:

```text
institution
```

For institution users:

```text
institution.id
institution.name
institution.status
institution.timezone
```

For Platform Owner:

```text
institution_id = null
institution = null
```

Flutter must treat this response as the authoritative restored session profile.

### 4.3 Logout

Endpoint:

```text
POST /auth/logout
```

Success:

```text
204 No Content
```

The backend revokes the current token.

### 4.4 Authentication errors

Use accepted generic API failure parsing.

Relevant server codes include:

```text
validation_failed
invalid_credentials
authentication_required
user_inactive
institution_inactive
rate_limited
forbidden
```

Do not invent frontend versions of backend stable codes.

Client behavior must branch on typed status/server code, not human-readable
message text.

## 5. Included Scope

### 5.1 Git / dependency preflight

Before implementation:

1. Read root `AGENTS.md`.
2. Read `frontend/AGENTS.md`.
3. Read this complete approved task.
4. Read only the locked specification sections referenced below.
5. Verify both dependencies are `Accepted`.
6. Verify their accepted results are present on `origin/main`.
7. Verify approved `origin`.
8. Fetch safely.
9. Verify local `main == origin/main`.
10. Verify no unrelated dirty state exists.
11. Verify accepted Flutter tests/toolchain remain available.

Required task branch:

`task/s01-fe-002-auth-session`

If the project owner already saved this approved task and
`S01-FE-002-CODEX-PROMPT.md` under `tasks/frontend/stage-01/`, those exact
preparation files are permitted pre-task additions.

Do not commit them on `main`; create the task branch immediately and carry them
into the branch.

### 5.2 Auth domain/session models

Create small immutable Flutter models for the current auth/session scope.

At minimum:

`UserRole`

Exact values:

```text
platform_owner
institution_admin
teacher
student
parent
```

Unknown role values from the server must fail parsing safely. Do not silently
map them to another role.

`AuthUser`

Fields:

```text
id
institution_id
role
full_name
login_name
email
phone
is_active
must_change_password
institution
```

`AuthInstitution`

Fields:

```text
id
name
status
timezone
```

Do not create general Stage 2 Institution/User-management domain models here.

These models represent server-returned session identity, not client authority.

### 5.3 DTO parsing

Create explicit DTO/mapping boundaries for:

- login response;
- login user;
- `/auth/me` response;
- institution context.

Requirements:

- validate required JSON structure;
- preserve nullable fields correctly;
- reject malformed role values;
- reject impossible missing required identifiers;
- do not serialize password/token hash/internal fields into domain models;
- do not leak raw JSON maps into widgets/controllers.

Do not add `freezed`, `json_serializable`, or `build_runner` merely for this
task. Manual focused parsing is acceptable and preferred unless the accepted
frontend foundation already standardized generated DTOs.

### 5.4 Auth token store

Build an auth-specific token storage wrapper on top of the accepted secure
storage abstraction.

Conceptual interface:

```text
read()
write(token)
delete()
```

Use one stable internal key, for example:

```text
auth_access_token
```

Requirements:

- token stored only in secure storage;
- no token in SharedPreferences;
- no token in plain file/cache;
- no token in logs;
- no role/institution cached beside token as authority;
- token deletion is idempotent;
- implementation injectable/fakeable in tests.

Do not store password.

### 5.5 Bearer-token Dio interceptor

Add one focused authentication interceptor to the accepted Dio client.

Behavior:

- before an authenticated request, read current token from `AuthTokenStore`;
- if present, attach:

```http
Authorization: Bearer <token>
```

- never log that header/token;
- do not attach stale token to the public login request;
- do not attach token to requests explicitly marked as public/skip-auth;
- do not mutate base URL;
- do not implement refresh-token retry;
- do not retry a 401 automatically.

Use a clear internal request-extra flag or equivalent server-independent
mechanism for public requests.

Do not match public/auth requests through fragile full-URL string comparisons
if a safer request option exists.

### 5.6 Unauthorized session signal

The accepted client must react to a server session becoming invalid.

Create a small one-way session invalidation signal/event boundary.

When an authenticated API response returns:

```text
401 authentication_required
```

the network layer must signal session invalidation without creating a circular
dependency between Dio and the session controller.

A small stream/notifier/callback boundary is acceptable.

Requirements:

- no automatic login retry;
- no refresh token;
- no recursive network request from interceptor;
- no logout HTTP request triggered merely because server already said the token
  is invalid;
- local token/session state is cleared;
- future feature requests can reuse the same mechanism.

Do not invalidate the session on:

```text
401 invalid_credentials
```

from public login.

### 5.7 Auth remote data source

Implement focused remote operations:

```text
login(login, password)
me()
logout()
```

`login` must mark the request as public/no-auth.

`me` and `logout` use authenticated Bearer transport.

Do not implement:

```text
changePassword()
refresh()
register()
forgotPassword()
resetPassword()
logoutAll()
```

in this task.

### 5.8 Auth repository

Create a repository boundary that converts remote DTOs into domain/session
models and coordinates token persistence.

Required login behavior:

1. call public login;
2. receive token;
3. persist token securely;
4. establish canonical authenticated session by calling `/auth/me`;
5. return authoritative `AuthUser` only after `/auth/me` succeeds.

Why:

- login response establishes credentials/token;
- `/auth/me` is the locked session bootstrap authority and includes trusted
  institution context/timezone.

If `/auth/me` after login returns an auth/account-state server rejection:

```text
authentication_required
user_inactive
institution_inactive
```

clear the newly stored token and return the failure.

If `/auth/me` fails only due to a transient transport problem:

- do not claim authenticated session success;
- keep the securely stored token so a later session/bootstrap retry can recover;
- surface a typed transport failure;
- do not fabricate user/role/institution data from the earlier login payload.

Do not use the login payload role as long-term restored authority.

### 5.9 Session bootstrap

Create the session controller/provider used by the app after startup.

Conceptual states should cleanly distinguish at least:

```text
initial / bootstrapping
unauthenticated
authenticated(AuthUser)
bootstrapFailure(ApiFailure)
```

Exact names may differ.

Bootstrap algorithm:

```text
read secure token
  ↓
no token
  → unauthenticated

token exists
  ↓
GET /auth/me
  ↓
success
  → authenticated(server AuthUser)

401 authentication_required
  → clear token
  → unauthenticated

403 user_inactive / institution_inactive
  → clear token
  → unauthenticated with surfaced typed failure/state as appropriate

transport failure
  → keep secure token
  → bootstrapFailure
  → allow explicit retry
```

Do not automatically loop/retry indefinitely.

Do not navigate to login/change-password/role shells in this task.

### 5.10 Session login operation

Expose a UI-agnostic controller method, conceptually:

```text
signIn(login, password)
```

FE-003 will call it from the actual login screen.

Required:

- begin operation without retaining previous-user visible session;
- use repository login;
- session becomes authenticated only from canonical `/auth/me` result;
- propagate typed failure for UI;
- never expose/store plaintext password after the operation;
- support repeated attempt after failure.

Do not build a widget/form here.

### 5.11 Logout operation

Expose:

```text
signOut()
```

Required behavior:

1. if a token exists, attempt backend `/auth/logout`;
2. regardless of backend transport/result, clear local secure token;
3. clear in-memory authenticated user/session state;
4. invalidate current session generation/epoch;
5. never retain previous user's `AuthUser`;
6. return/surface server logout failure separately if useful, but local state
   must still become unauthenticated.

This local-cleanup rule prevents a failed network logout from leaving another
person's data visible on a shared device.

Do not call logout when handling an already-invalid 401; clear local state
directly.

### 5.12 Account-switch / stale-result protection

The Stage 1 acceptance criteria require that previous auth/session state cannot
expose another user's data.

Protect the auth controller from asynchronous stale-result races.

Required behavior:

- each bootstrap/login/logout/session replacement advances a generation/epoch
  or equivalent cancellation identity;
- an older async response may not overwrite a newer session;
- after logout, delayed `/auth/me` result from the old token cannot restore the
  old user;
- after User A login attempt is superseded by User B login, delayed User A
  response cannot replace User B;
- unauthorized-session signal from a superseded request cannot corrupt a newer
  valid session incorrectly.

Use the smallest clear mechanism; do not add a reactive concurrency package
solely for this task.

### 5.13 Session-scoped authority

The current session stores only the server-returned current identity.

Do not persist to long-term local storage:

- role;
- institution;
- `must_change_password`;
- full user profile.

Only the secure access token survives app restart.

On restart, authority is reconstructed through:

```text
GET /auth/me
```

This is mandatory.

### 5.14 Riverpod integration

Provide focused Riverpod providers for:

- `AuthTokenStore`;
- unauthorized-session signal;
- auth remote data source;
- auth repository;
- auth session controller/state.

Do not create parallel service-locator globals.

Keep dependencies injectable for tests through Riverpod overrides.

Do not implement UI navigation side effects inside repository/data source.

### 5.15 App startup integration

Wire session bootstrap into the app architecture so the auth session controller
can initialize at startup.

Do not change production routing yet.

The technical root screen from `S01-FE-001` may remain.

It must not display authenticated user/product data in this task.

Do not implement splash/login redirects here; `S01-FE-003` / `S01-FE-004`
own the UX/navigation layer.

## 6. Error / Failure Handling

Reuse the accepted typed API failure model.

### Login

Preserve:

```text
422 validation_failed
401 invalid_credentials
403 user_inactive
403 institution_inactive
429 rate_limited
```

No UI message copy is implemented here.

### Bootstrap / me

Relevant:

```text
401 authentication_required
403 user_inactive
403 institution_inactive
transport failure
malformed response
```

### Logout

`204` is success.

Local token/session cleanup occurs even if logout request receives a transport
failure.

Do not transform backend codes into new invented server codes.

## 7. Relevant Files

Expected high-value change surface:

| Path | Expected action |
|---|---|
| `frontend/lib/features/auth/domain/*` | Create role/session domain models |
| `frontend/lib/features/auth/data/dto/*` | Create explicit auth DTO parsing |
| `frontend/lib/features/auth/data/auth_remote_data_source.dart` | Create |
| `frontend/lib/features/auth/data/auth_repository_impl.dart` | Create |
| `frontend/lib/features/auth/domain/auth_repository.dart` | Create interface if consistent with accepted architecture |
| `frontend/lib/features/auth/application/auth_session_controller.dart` | Create |
| `frontend/lib/features/auth/application/auth_session_state.dart` | Create if separated |
| `frontend/lib/core/storage/auth_token_store.dart` | Create wrapper over secure storage |
| `frontend/lib/core/network/auth_token_interceptor.dart` | Create |
| `frontend/lib/core/network/session_invalidation_signal.dart` | Create |
| `frontend/lib/core/network/*` accepted Dio provider/factory | Modify minimally to install auth interceptor |
| `frontend/lib/app/*` | Minimal provider/bootstrap wiring only |
| `frontend/test/features/auth/*` | Create focused auth/session tests |
| `frontend/test/core/network/*` | Add interceptor/invalidation tests |
| `tasks/frontend/stage-01/S01-FE-002-authentication-data-session-foundation.md` | Preserve |
| `tasks/frontend/stage-01/S01-FE-002-CODEX-PROMPT.md` | Preserve |
| `tasks/STAGE_01_TASK_INDEX.md` | Lifecycle update only |

Do not modify:

- `docs/01–09`;
- `backend/`;
- `docker/`.

Do not add login/password-change widgets.

## 8. Authoritative Specification References

| Document | Section | Requirement |
|---|---|---|
| `docs/06-roadmap.md` | `6. Stage 1 — Authentication and Role-Based Entry` | Flutter auth/session behavior and previous-session isolation |
| `docs/07-architecture.md` | `9.3 Authentication` | Sanctum token/session identity |
| `docs/07-architecture.md` | `20. Flutter Application Architecture` | Riverpod, Dio, repositories, DTOs, secure storage |
| `docs/07-architecture.md` | `21. Flutter Navigation Architecture` | Routing is later UX layer; backend remains authority |
| `docs/07-architecture.md` | `23. API Boundary Principles` | Server authority / typed error boundary |
| `docs/07-architecture.md` | `32. Testing Architecture` | Flutter session/repository tests |
| `docs/09-api-contracts.md` | `1.4 Authentication` | Sanctum Bearer token |
| `docs/09-api-contracts.md` | `3.1 Login` | Exact request/response/errors |
| `docs/09-api-contracts.md` | `3.2 Logout` | Current-token revoke / 204 |
| `docs/09-api-contracts.md` | `3.3 Current User` | Exact `/auth/me` data |
| `docs/09-api-contracts.md` | `4. Current User / Session Contract` | `/auth/me` is client bootstrap authority |
| `docs/09-api-contracts.md` | `5.1 Stable Error Codes` | Preserve server codes |
| `frontend/AGENTS.md` | API/state/storage/navigation/testing sections | Frontend implementation rules |
| `AGENTS.md` | Current task/Git workflow | Branch/review/delivery/scope |
| `tasks/STAGE_01_TASK_INDEX.md` | `S01-FE-002` row | Approved dependency/order/session scope |

## 9. Security Requirements

### 9.1 Token secrecy

Never:

- log access token;
- print Authorization header;
- include token in exception message;
- store token outside secure storage;
- expose token through UI state;
- include token in persisted debug/cache files.

### 9.2 Password lifetime

Plaintext password exists only as short-lived input to `signIn`.

Do not:

- store password in provider state longer than the request operation;
- store password in secure storage;
- log password;
- return password in failure objects.

### 9.3 Server authority

The following come only from backend response:

```text
user id
role
institution_id
institution
must_change_password
is_active
```

Do not derive role from login name or local settings.

Do not persist role as long-term authority.

### 9.4 Shared-device session isolation

After logout/account switch:

- old `AuthUser` removed;
- old token deleted;
- stale async results ignored;
- no previous role/institution remains in current session state.

This is a Stage 1 acceptance requirement.

## 10. Functional Requirements

1. `S01-FE-001` verified `Accepted`.
2. `S01-BE-003` verified `Accepted`.
3. Work occurs on `task/s01-fe-002-auth-session`.
4. Exact five-role Flutter `UserRole` exists.
5. Auth user/institution models match locked session fields.
6. Login DTO/request uses public `login`.
7. Auth remote data source implements login/me/logout only.
8. Auth repository exists with explicit DTO→domain mapping.
9. Auth token is stored only through secure storage.
10. Bearer interceptor injects token on authenticated requests.
11. Public login does not receive stale Bearer token.
12. No refresh/retry auth logic exists.
13. `401 authentication_required` can invalidate local session.
14. Public `invalid_credentials` does not trigger global session invalidation.
15. App bootstrap reads secure token.
16. No token at bootstrap → unauthenticated.
17. Token + successful `/auth/me` → authenticated server session.
18. Invalid/revoked token → token cleared + unauthenticated.
19. Inactive user/institution bootstrap rejection clears local token/session.
20. Transport bootstrap failure keeps token but does not claim authenticated
    session.
21. Explicit bootstrap retry is possible.
22. `signIn` stores successful token securely.
23. `signIn` establishes final session from `/auth/me`.
24. `/auth/me` auth/account rejection after login clears stored new token.
25. `/auth/me` transport failure after login does not fabricate authenticated
    role/institution.
26. `signOut` attempts backend logout when applicable.
27. `signOut` always clears local token/session.
28. Logout failure does not leave previous user visible locally.
29. Stale bootstrap/login results cannot restore/overwrite a newer session.
30. User A → logout → User B cannot expose User A session identity.
31. Auth role/institution/profile are not persisted as authority.
32. `must_change_password` is preserved in current session state.
33. No login UI exists.
34. No change-password API/UI exists.
35. No role/device route guard/shell exists.
36. `flutter analyze` passes.
37. `flutter test` passes.
38. format check passes.
39. accepted Windows/Android builds remain green.
40. docs/backend/docker remain unchanged.

## 11. Required Automated Tests

### 11.1 DTO / model parsing

Test:

- all five roles;
- institution user `/auth/me`;
- Platform Owner null institution;
- nullable email/phone;
- `must_change_password` true/false;
- malformed role rejected;
- missing required ID rejected;
- malformed institution data rejected.

### 11.2 Auth token store

Using fake accepted secure-storage boundary:

- read none;
- write/read;
- overwrite;
- delete;
- idempotent delete;
- no role/user profile stored.

### 11.3 Bearer interceptor

Test:

- authenticated request + token → Authorization Bearer header;
- no token → no Authorization header;
- public/skip-auth login request → no Authorization header even if stale token
  exists;
- existing unrelated headers preserved;
- token never appears in mapped failure/log output.

### 11.4 Unauthorized session signal

Test:

- `401 authentication_required` on authenticated request emits invalidation;
- `401 invalid_credentials` from public login does not invalidate a current
  unrelated session through the global signal;
- `403 forbidden` does not mean token invalid;
- no recursive retry/request occurs.

### 11.5 Bootstrap

Test:

#### No token

```text
→ unauthenticated
```

No `/auth/me` call.

#### Valid token

```text
→ /auth/me
→ authenticated(AuthUser)
```

#### Invalid/revoked token

```text
→ 401 authentication_required
→ token deleted
→ unauthenticated
```

#### Inactive user

```text
→ 403 user_inactive
→ token deleted
→ unauthenticated/failure state according to implementation
```

#### Inactive institution

Same behavior with `institution_inactive`.

#### Transport failure

```text
token preserved
authenticated user not fabricated
bootstrapFailure
retry available
```

### 11.6 Sign-in

Use fake repository/remote layers.

Test:

- request sends `login`, password;
- success stores token;
- canonical session comes from `/auth/me`, not login payload;
- login payload role differing from `/auth/me` test fixture cannot become
  current authority;
- invalid credentials leaves token absent/session unauthenticated;
- account-status rejection leaves token absent;
- transient `/auth/me` failure after token issuance keeps token but does not
  expose authenticated session;
- retry bootstrap can recover using stored token;
- password is not retained in session state.

### 11.7 Sign-out

Test:

- authenticated sign-out calls backend logout;
- local token cleared;
- AuthUser cleared;
- state unauthenticated;
- backend transport failure still clears local token/session;
- already-invalid/no-token sign-out safely clears local state without crash.

### 11.8 Unauthorized response during active session

With active session:

```text
authenticated
→ global authentication_required signal
→ token deleted
→ user cleared
→ unauthenticated
```

No logout HTTP recursion.

### 11.9 Account-switch / race tests

These are mandatory.

#### Delayed bootstrap after logout

```text
bootstrap User A begins
→ logout occurs
→ old /auth/me A completes
→ User A must NOT be restored
```

#### Overlapping login

```text
signIn A begins
→ signIn B supersedes
→ B completes
→ delayed A completion
→ current session remains B
```

#### Logout supersedes login

```text
signIn begins
→ logout
→ delayed signIn/me result
→ session remains unauthenticated
```

No stale operation may expose previous user state.

### 11.10 Riverpod provider tests

Use provider overrides/fakes to prove:

- controller dependencies injectable;
- startup/bootstrap state transitions deterministic;
- repository/network/storage not global singletons outside Riverpod.

### 11.11 Regression

All accepted `S01-FE-001` tests remain green.

## 12. Quality / Verification Commands

From `frontend/` run:

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
flutter build windows --debug
flutter build apk --debug
```

Do not add package dependencies unless implementation genuinely cannot be
completed with the accepted FE-001 dependency set.

If an additional package becomes technically necessary, stop and report the
need instead of silently changing architecture/dependencies.

### 12.1 Scope checks

Before acceptance gate:

```text
git status --short
git diff --check
git diff main...HEAD -- docs
git diff main...HEAD -- backend
git diff main...HEAD -- docker
```

Expected: no changes.

Review `pubspec.yaml` / `pubspec.lock` and verify no unapproved new package.

Scan changes for:

- plaintext token;
- Authorization header logging;
- password logging/storage;
- `.env`;
- hard-coded user/role/institution authority.

## 13. Manual Smoke Check

This task has no real login UI.

Use a test/dev harness or provider-level smoke only.

1. Start accepted backend runtime.
2. Use controlled credentials outside repository to invoke the auth repository
   / session controller through a temporary test/debug harness only if needed.
3. Confirm successful login stores token securely and current session comes
   from `/auth/me`.
4. Recreate ProviderContainer/app session and confirm token bootstrap restores
   the user through `/auth/me`.
5. Revoke/invalid token and confirm local session clears.
6. Logout and confirm local session/token clears.
7. Simulate User A then User B and confirm no User A auth state remains.
8. Remove any temporary debug harness if it is not an approved test-only file.

Do not add production login UI to perform smoke testing.

## 14. Explicit Non-Goals

- Login screen/form.
- Password visibility UI.
- Loading/error UI.
- Change-password API integration.
- Change-password screen.
- First-login redirect.
- Route guards.
- Role/device shell routing.
- Platform Owner/Admin/Teacher/Student/Parent shells.
- Dashboard/navigation.
- Feature data caches.
- Refresh tokens.
- Token rotation.
- Logout-all/device sessions.
- Registration/password reset/MFA.
- Offline auth.
- Persisting role/profile locally.
- Analytics.
- New backend/Docker behavior.
- Stage 2+ functionality.

## 15. Stop Conditions

Stop and report if:

- `S01-FE-001` is not `Accepted`;
- `S01-BE-003` is not `Accepted`;
- accepted auth API contract differs materially from this task;
- accepted Flutter network/storage foundation is absent/broken;
- local `main` cannot synchronize with `origin/main`;
- unrelated dirty state exists;
- task branch cannot be created safely;
- implementation requires adding refresh-token behavior;
- implementation requires new UI/routing from FE-003/FE-004;
- correct session restoration cannot use `/auth/me`;
- a package addition is materially required but not approved;
- secure token storage cannot function with accepted foundation;
- a secret/password/token would need to be committed/logged;
- safe completion requires destructive Git operation/force-push/history
  rewrite/check bypass;
- material scope expansion is required.

## 16. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git Preflight

Create/switch to:

`task/s01-fe-002-auth-session`

Ensure approved task/prompt are on task branch.

Do not commit/push.

### Phase 1 — Implementation

Implement only this task.

Run:

- DTO/model tests;
- token-store tests;
- Bearer interceptor tests;
- unauthorized invalidation tests;
- repository tests;
- bootstrap tests;
- sign-in/sign-out tests;
- mandatory race/account-switch tests;
- Riverpod provider tests;
- full Flutter tests;
- analyze;
- format;
- Windows/Android builds;
- scope/security checks.

Do not commit/push.

### Phase 2 — Read-Only Acceptance Gate

Re-read task, applicable locked docs, root/frontend AGENTS, complete diff,
tests/build/security evidence.

No edits, auto-fixes, new staging, commit, push, or merge.

Findings:

- `P1` blocking token/session/security/state-leak issue;
- `P2` material API/architecture/test/scope mismatch;
- `P3` non-blocking observation.

If P1/P2 remains:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop. Do not self-fix after Phase 2 begins.

### Phase 3 — Post-Acceptance Git Delivery

Only after Phase 2 PASS:

1. Set task `Accepted`.
2. Update Stage 1 index:
   - Task `Accepted`;
   - Review `PASS`;
   - Delivery finalized after merge.
3. Re-run final test/scope/secret checks.
4. Stage only approved changes.
5. Commit:

```text
feat(auth): add Flutter session foundation
```

Body:

```text
Task: S01-FE-002
```

6. Push task branch.
7. Create PR to `main`.
8. Do not bypass checks.
9. Merge only when safe/green.
10. Sync local `main` from `origin/main`.
11. Verify local `main == origin/main` and clean tree.

If review PASS but delivery fails:

```text
FINAL STATUS: DELIVERY BLOCKED
```

If all succeeds:

```text
FINAL STATUS: ACCEPTED
```

Do not start `S01-FE-003`.

## 17. Required Codex Final Report

Return:

1. Final status: `ACCEPTED`, `NOT ACCEPTED`, or `DELIVERY BLOCKED`.
2. Dependency/Git preflight.
3. Implementation summary.
4. Changed files grouped by:
   - auth domain/DTO;
   - remote/repository;
   - token/network;
   - session/Riverpod;
   - tests;
   - task bookkeeping.
5. API contract evidence.
6. Secure token evidence.
7. Bearer/public-request evidence.
8. `/auth/me` bootstrap authority evidence.
9. Logout/local-cleanup evidence.
10. Unauthorized invalidation evidence.
11. Race/account-switch isolation evidence.
12. Acceptance findings.
13. Acceptance criteria PASS/FAIL.
14. Analyze/test/format/build evidence.
15. Security/scope evidence.
16. GitHub delivery evidence.
17. Manual smoke status.
18. Remaining blockers/deviations.

Do not start `S01-FE-003`.
