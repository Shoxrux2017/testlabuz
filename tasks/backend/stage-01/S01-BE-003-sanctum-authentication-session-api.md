# Codex Task: Sanctum Authentication & Session API

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S01-BE-003` |
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Area | `Backend / authentication` |
| Status | `Approved` |
| Depends on | `S01-BE-002 — Identity Persistence Foundation (Accepted)` |
| Blocks | `S01-BE-004 — Mandatory First-Login Password Change Gate` |

This task is approved for Codex execution.

Codex must still enforce all dependency, Git preflight, scope, testing,
read-only acceptance, and GitHub delivery gates defined below.

## 2. Goal

Implement the locked Stage 1 backend authentication/session API on top of the
accepted UUID identity persistence layer.

The accepted result must provide:

```text
POST /api/v1/auth/login
POST /api/v1/auth/logout
GET  /api/v1/auth/me
```

with:

- Laravel Sanctum Bearer-token authentication;
- login by the public request field `login`, mapped to `users.login_name`;
- persisted server-authoritative role/institution identity;
- inactive-user enforcement;
- inactive-institution enforcement;
- safe current-token logout;
- current-user/session bootstrap payload;
- reusable account/institution active-state middleware for later protected
  endpoints;
- brute-force rate limiting on login;
- strict API response/error-contract tests;
- no first-login password-change endpoint/gate yet;
- no role-capability authorization layer yet.

This task establishes authentication and account-status authority. It does not
implement user management, role permissions, or Flutter.

## 3. Current Context

Repository:

`G:\project\testlabuz`

Approved GitHub remote:

`https://github.com/Shoxrux2017/testlabuz.git`

Required dependency:

`S01-BE-002 = Accepted`

The accepted dependency is expected to provide:

- UUID `institutions`;
- UUID `users`;
- the five exact persisted roles;
- `institution_settings`;
- Sanctum `personal_access_tokens` compatible with UUID users;
- `User` using Sanctum `HasApiTokens`;
- PostgreSQL-backed factories/states for all Stage 1 roles;
- isolated `testlabuz_testing` runtime.

Codex must independently verify the actual accepted dependency on
`origin/main`.

## 4. Locked Public API Contract

### 4.1 Base authentication transport

Protected API requests use:

```http
Authorization: Bearer <token>
Accept: application/json
```

Laravel Sanctum is the approved token authentication baseline.

Do not implement SPA-cookie authentication, OAuth, JWT, Passport, Fortify
application flows, or a second authentication system.

### 4.2 Login

Endpoint:

```text
POST /api/v1/auth/login
```

Public request contract:

```json
{
  "login": "teacher01",
  "password": "secret"
}
```

Important:

- public field is exactly `login`;
- `login` maps to `users.login_name`;
- the client does not send an authoritative role;
- the client does not send an authoritative institution;
- response role/institution come only from persisted server data.

Success:

```text
HTTP 200
```

Shape:

```json
{
  "data": {
    "token": "plain-text-token-returned-once",
    "token_type": "Bearer",
    "user": {
      "id": "uuid",
      "institution_id": "uuid",
      "role": "teacher",
      "full_name": "Teacher Name",
      "login_name": "teacher01",
      "email": null,
      "phone": null,
      "is_active": true,
      "must_change_password": false
    }
  }
}
```

For Platform Owner:

```json
"institution_id": null
```

Login errors:

```text
422 validation_failed
401 invalid_credentials
403 user_inactive
403 institution_inactive
429 rate_limited
```

The 429 code already belongs to the locked general error contract.

### 4.3 Logout

Endpoint:

```text
POST /api/v1/auth/logout
```

Authentication:

```text
auth:sanctum
```

Success:

```text
204 No Content
```

Behavior:

- revoke/delete only the token used for the current request;
- do not revoke every token for the account;
- do not implement "logout all devices";
- return no JSON body on `204`.

A valid current token must be allowed to call logout even if the corresponding
user or institution became inactive after that token was issued. Logout is a
security-cleanup endpoint, not normal application functionality.

After logout, that revoked token must no longer authenticate protected access.

### 4.4 Current user/session

Endpoint:

```text
GET /api/v1/auth/me
```

Authentication and account-state layers:

```text
auth:sanctum
+
active account/institution guard
```

Institution-user success:

```json
{
  "data": {
    "id": "uuid",
    "institution_id": "uuid",
    "role": "teacher",
    "full_name": "Teacher Name",
    "login_name": "teacher01",
    "email": null,
    "phone": null,
    "is_active": true,
    "must_change_password": false,
    "institution": {
      "id": "uuid",
      "name": "Example School",
      "status": "active",
      "timezone": "Asia/Tashkent"
    }
  }
}
```

Platform Owner:

```json
"institution_id": null,
"institution": null
```

The payload must not include:

- password/password hash;
- token hash;
- current plaintext token;
- creator/audit-only fields not defined by the contract;
- arbitrary model attributes added through accidental Eloquent serialization.

Use an explicit API Resource / response mapping.

## 5. Included Scope

### 5.1 Git / dependency preflight

Before implementation:

1. Read root `AGENTS.md`.
2. Read `backend/AGENTS.md`.
3. Read this complete approved task.
4. Read only the locked specification sections referenced by this task.
5. Verify `S01-BE-002` is `Accepted`.
6. Verify its accepted implementation is present on `origin/main`.
7. Verify approved `origin`.
8. Fetch remote state safely.
9. Verify local `main == origin/main`.
10. Verify no unrelated dirty state exists.
11. Verify accepted PostgreSQL test runtime is healthy/usable.

Required task branch:

`task/s01-be-003-sanctum-auth-session`

If the project owner already saved this approved task and
`S01-BE-003-CODEX-PROMPT.md` under `tasks/backend/stage-01/` before execution,
those exact preparation files are permitted pre-task additions.

In that case:

- verify they are the only permitted pre-task additions;
- do not commit them on `main`;
- create the task branch immediately from synchronized `main`;
- carry them into the task branch;
- perform all implementation/delivery from the task branch.

Any other unexplained dirty state is a blocker.

### 5.2 Login request validation

Create a focused request object, for example:

`LoginRequest`

Rules must validate only the public contract fields.

At minimum:

```text
login:
  required
  string
  non-empty after normal request validation
  max compatible with users.login_name (191)

password:
  required
  string
  non-empty
  bounded to a safe reasonable request length
```

Do not rename the public request field to `login_name`.

When reading validated input, use only validated contract fields. Additional
client fields such as:

```text
role
institution_id
is_active
must_change_password
```

must never influence authentication identity or returned authority.

Do not mass-assign request data into User.

### 5.3 Credential verification

Implement one focused authentication action/service.

Recommended conceptual boundary:

```text
AuthenticateUser
```

The controller should remain HTTP-focused.

Credential sequence:

1. Resolve account by exact stable `login_name`.
2. Verify password with Laravel Hash services.
3. If login does not exist or password is wrong:
   - return the same public error:
     `401 invalid_credentials`;
   - do not reveal whether the login exists.
4. Only after valid credentials:
   - check user active state;
   - check institution active state where applicable;
   - issue token.

Avoid a trivial timing oracle for "unknown login" vs "known login with wrong
password". Use an appropriate framework-compatible dummy password-hash check or
equivalent constant-work strategy where practical.

Do not log:

- submitted login password;
- plaintext issued token;
- persisted token hash;
- Authorization header.

### 5.4 Active user / institution checks at login

After credentials are proven valid:

#### User inactive

If:

```text
users.is_active = false
```

return:

```text
HTTP 403
code = user_inactive
errors = {}
```

No token is created.

#### Institution inactive

For non-Platform Owner accounts:

```text
user.institution.status != active
```

return:

```text
HTTP 403
code = institution_inactive
errors = {}
```

No token is created.

Platform Owner has:

```text
institution_id = null
```

and does not require an institution-status check.

Do not use client-supplied institution information for these checks.

### 5.5 Existing-session active-state guard

Create one reusable middleware / guard for protected requests, conceptually:

`EnsureAccountIsActive`

It must execute after `auth:sanctum`.

For an already-authenticated token:

1. if current user is inactive:
   - `403 user_inactive`;
2. if institution user belongs to inactive institution:
   - `403 institution_inactive`;
3. Platform Owner skips institution-active check;
4. otherwise continue.

This guard must be reusable by later protected endpoint groups.

Apply it to:

```text
GET /api/v1/auth/me
```

Do not apply it to logout, so an already-issued token can still be revoked if
the account/institution became inactive.

Do not implement:

```text
password_change_required
```

in this middleware yet. That is `S01-BE-004`.

Do not implement role-capability checks here. That is `S01-BE-005`.

### 5.6 Sanctum token issuance

Use Laravel Sanctum's `HasApiTokens::createToken` mechanism.

Requirements:

- one new API token per successful login;
- return `plainTextToken` only in the login response;
- persisted Sanctum token remains hashed;
- do not store plaintext token elsewhere;
- do not put role/institution as independent token authority;
- do not use user-controlled token abilities as role permissions;
- use a stable internal technical token name suitable for the Flutter client,
  e.g. `flutter-client`;
- default/full Sanctum token ability is acceptable because authorization comes
  from persisted account/role/scope, not token-supplied role;
- do not add device registration/device metadata;
- do not add "remember me";
- do not add refresh-token family logic;
- do not add custom token expiration policy unless already required by the
  accepted locked repository contract.

Advanced session management is explicitly outside Stage 1.

Successful login should also update:

`users.last_login_at`

after credentials/account checks succeed.

Prefer one transactional application operation for:

- successful account check;
- token persistence;
- `last_login_at` update;

so a partial successful-login state is avoided.

### 5.7 Login rate limiting

Protect the public login endpoint against straightforward brute-force abuse
using Laravel's built-in rate limiter.

Use a named limiter such as:

`auth.login`

Implementation-level baseline:

```text
5 attempts per minute
```

keyed by a normalized combination of:

```text
login + client IP
```

Requirements:

- do not expose the password in limiter keys/logs;
- limiter does not change invalid-credential response semantics before the
  threshold;
- after threshold, use the existing locked:
  `429 rate_limited`;
- successful authentication clears/reset the relevant limiter attempt state
  where appropriate;
- do not install Redis only for rate limiting in this task;
- use the accepted cache/runtime baseline.

This numeric limiter is an implementation security default, not a new public
product behavior contract.

### 5.8 Login response resource

Create an explicit response/resource mapping for the login user payload.

Exact user fields:

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

No password.
No password hash.
No token relationship.
No created_by_user_id.
No accidental extra fields.

`token_type` is exactly:

```text
Bearer
```

### 5.9 Current-user response resource

Create an explicit current-session resource.

Exact top-level data fields:

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

Institution object for institution users:

```text
id
name
status
timezone
```

`timezone` comes from persisted trusted institution settings.

The client may not supply/override it.

For Platform Owner:

```text
institution_id = null
institution = null
```

Load the required relation/settings without producing avoidable N+1 queries.

A missing institution/settings relation in a state that should satisfy this
contract is a server/data invariant problem. Do not silently fabricate an
institution or timezone from client/device input.

### 5.10 Logout current token only

Implement current-token revocation using Sanctum's authenticated
`currentAccessToken()` / standard token relationship semantics.

Requirements:

- current token deleted/revoked;
- response `204`;
- same token then gets `401 authentication_required`;
- another independently issued token for the same user is not silently revoked;
- no "logout all";
- no device/session list endpoint.

### 5.11 Route organization

All endpoints live under:

`/api/v1/auth`

Expected:

```text
POST /api/v1/auth/login
POST /api/v1/auth/logout
GET  /api/v1/auth/me
```

Route intent:

```text
login
  public
  login rate limiter

logout
  auth:sanctum

me
  auth:sanctum
  active-account/institution guard
```

Do not add `change-password` in this task.

Do not add role-specific product routes.

## 6. Error Contract

Use the centralized error foundation accepted from `S01-BE-001`.

Expected errors in this task:

### Validation

```text
HTTP 422
code = validation_failed
errors = field-object
```

### Invalid credentials

```text
HTTP 401
code = invalid_credentials
errors = {}
```

Unknown login and wrong password must be indistinguishable through this public
machine code/message contract.

### Missing/invalid/revoked token

```text
HTTP 401
code = authentication_required
errors = {}
```

### Inactive user

```text
HTTP 403
code = user_inactive
errors = {}
```

### Inactive institution

```text
HTTP 403
code = institution_inactive
errors = {}
```

### Login rate limit

```text
HTTP 429
code = rate_limited
errors = {}
```

Do not invent a new machine code.

## 7. Relevant Files

Expected high-value change surface:

| Path | Expected action | Reason |
|---|---|---|
| `backend/routes/api.php` | Add auth routes | Locked auth endpoints |
| `backend/app/Http/Controllers/Api/V1/Auth/*` | Create focused controllers | HTTP boundary |
| `backend/app/Http/Requests/Auth/LoginRequest.php` | Create | Login validation |
| `backend/app/Actions/Auth/AuthenticateUser.php` or equivalent | Create | Authentication application operation |
| `backend/app/Http/Middleware/EnsureAccountIsActive.php` | Create | Active user/institution guard |
| `backend/app/Http/Resources/Auth/*` | Create | Explicit response serialization |
| `backend/app/Providers/*` or accepted routing/bootstrap location | Configure named login limiter/middleware alias | Auth infrastructure |
| `backend/app/Models/User.php` | Minimal change only if needed for auth behavior | Existing identity model |
| `backend/tests/Feature/Auth/*` | Create | Full API authentication tests |
| `tasks/backend/stage-01/S01-BE-003-sanctum-authentication-session-api.md` | Preserve | Approved task |
| `tasks/backend/stage-01/S01-BE-003-CODEX-PROMPT.md` | Preserve | Manual execution prompt |
| `tasks/STAGE_01_TASK_INDEX.md` | Lifecycle update only | Stage control |

Do not modify locked `docs/01–09`.

Do not modify `frontend/`.

Do not add/change Docker services.

Do not redesign identity migrations from accepted `S01-BE-002` unless an actual
blocking defect is found; report such a defect instead of silently expanding
scope.

## 8. Authoritative Specification References

| Document | Exact section | Requirement used |
|---|---|---|
| `docs/06-roadmap.md` | `6. Stage 1 — Authentication and Role-Based Entry` | Login/logout/current session, active user/institution checks, role/institution identity, protected foundation, tests |
| `docs/07-architecture.md` | `8.2 Institution Context` | Trusted institution derives from authenticated account |
| `docs/07-architecture.md` | `9.1 MVP Roles` | Five roles |
| `docs/07-architecture.md` | `9.2 One Primary Role Per MVP Account` | One persisted role |
| `docs/07-architecture.md` | `9.3 Authentication` | Sanctum, login/logout/current user, role/institution/status, must-change state |
| `docs/07-architecture.md` | `9.4 Authorization Layers` | Authentication then account/institution status before later role/scope layers |
| `docs/09-api-contracts.md` | `1.1 Base URL` | `/api/v1` |
| `docs/09-api-contracts.md` | `1.4 Authentication` | Sanctum Bearer token |
| `docs/09-api-contracts.md` | `2.2 Empty Success` | 204 has no JSON body |
| `docs/09-api-contracts.md` | `2.3 Error Envelope` | Stable machine error shape |
| `docs/09-api-contracts.md` | `2.5 Authentication Error` | `authentication_required`, `invalid_credentials` |
| `docs/09-api-contracts.md` | `2.9 Rate Limit` | `429 rate_limited` |
| `docs/09-api-contracts.md` | `3.1 Login` | Exact login request/response/errors/rules |
| `docs/09-api-contracts.md` | `3.2 Logout` | Current token/session revoke, 204 |
| `docs/09-api-contracts.md` | `3.3 Current User` | Exact `/auth/me` response |
| `docs/09-api-contracts.md` | `4. Current User / Session Contract` | Server bootstrap authority |
| `docs/09-api-contracts.md` | `5.1 Stable Error Codes` | Allowed machine codes |
| `docs/09-api-contracts.md` | `33.1 Server Scope Order` | auth → user active → institution active → later authorization layers |
| `backend/AGENTS.md` | Auth/API/security/testing sections | Backend implementation quality |
| `AGENTS.md` | Current task/Git workflow | Branch/review/delivery/scope |
| `tasks/STAGE_01_TASK_INDEX.md` | `S01-BE-003` row | Approved dependency/order |

## 9. External Technical Reference

Laravel Sanctum 13.x official documentation is the implementation reference for:

- `HasApiTokens`;
- `createToken`;
- Bearer token authentication;
- protected routes;
- current token revocation.

Laravel's official rate-limiter abstraction is the implementation reference for
the login limiter.

These framework references do not replace the locked TestLabUz API contract.

## 10. Security Requirements

### 10.1 Credential disclosure resistance

- Never log plaintext password.
- Never log plaintext issued token.
- Never log Authorization header.
- Never serialize password/password hash.
- Invalid login and wrong password use the same public response.
- Do not return "user not found".
- Status-specific `user_inactive` / `institution_inactive` occurs only after
  valid credentials at login.

### 10.2 Server authority

The following are read only from persisted authenticated identity:

```text
user id
role
institution_id
institution status
is_active
must_change_password
institution timezone
```

The client cannot select/override them.

### 10.3 Token safety

- Sanctum token persisted hash only.
- Plaintext token returned exactly at successful login response boundary.
- No plaintext token persisted in logs/cache/custom table.
- Logout revokes current token only.
- No token list/device-management endpoint.
- No role authority encoded as client-selectable token scope.

### 10.4 Existing token after deactivation

A token that was issued while active must not preserve normal access after:

```text
user becomes inactive
```

or:

```text
institution becomes inactive
```

`/auth/me` and later active-protected routes must fail immediately using the
active-account guard.

This check must use current persisted state per request, not stale role/status
copied into the token.

## 11. Requirements

### 11.1 Functional Requirements

1. `S01-BE-002` is independently verified as `Accepted`.
2. Work occurs on `task/s01-be-003-sanctum-auth-session`.
3. `POST /api/v1/auth/login` exists.
4. Login public input uses `login`, not `login_name`.
5. `login` resolves `users.login_name`.
6. Wrong password returns `401 invalid_credentials`.
7. Unknown login returns the same `401 invalid_credentials`.
8. No token is issued for invalid credentials.
9. Valid inactive user returns `403 user_inactive`.
10. Valid user in inactive institution returns `403 institution_inactive`.
11. Platform Owner does not require institution context.
12. All five roles can log in when valid/active.
13. Successful login returns exact locked token/user shape.
14. Successful login updates `last_login_at`.
15. Successful login issues one Sanctum Bearer token.
16. Persisted token is hashed.
17. Login is rate-limited with existing `429 rate_limited`.
18. `POST /api/v1/auth/logout` exists.
19. Logout revokes current token only.
20. Logout returns `204` with no response body.
21. Revoked token then returns `401 authentication_required`.
22. Logout remains usable with a currently valid token even when user/
    institution became inactive after issuance.
23. `GET /api/v1/auth/me` exists.
24. `/auth/me` requires Sanctum.
25. `/auth/me` checks current user active state.
26. `/auth/me` checks current institution active state for institution users.
27. `/auth/me` returns exact locked user/institution context.
28. Platform Owner `/auth/me` returns null institution.
29. `must_change_password` is returned accurately but is not yet enforced as a
    normal-endpoint gate.
30. Client-supplied role/institution cannot alter identity.
31. No change-password endpoint is added.
32. No `password_change_required` guard is added.
33. No role-capability policy/middleware is added.
34. Full backend tests pass against PostgreSQL.
35. Pint and Composer validation remain green.
36. Locked docs/frontend/docker remain unchanged.

## 12. Required Automated Tests

Create focused feature tests under an auth test namespace.

### 12.1 Login validation

Test:

- missing login;
- empty login;
- oversized login;
- missing password;
- empty password;
- response `422 validation_failed`;
- `errors` object contains relevant fields.

### 12.2 Successful login — every role

Test each:

```text
platform_owner
institution_admin
teacher
student
parent
```

For each:

- valid `login` + password returns 200;
- token is non-empty string;
- token_type = `Bearer`;
- user payload fields match persisted user;
- role comes from DB;
- institution_id comes from DB;
- must_change_password is accurate;
- password absent;
- token relation/internal fields absent.

For Platform Owner:

```text
institution_id = null
```

For administrator-created institution-role fixture with
`must_change_password = true`, login must still succeed and return the flag
`true`.

The first-login gate itself belongs to `S01-BE-004`.

### 12.3 Invalid credentials

Test separately:

- unknown login;
- known login + wrong password.

Both must return indistinguishable:

```text
401 invalid_credentials
errors = {}
```

No token created.
No `last_login_at` update.

### 12.4 Inactive user

With correct credentials:

- response `403 user_inactive`;
- errors `{}`;
- no token;
- no successful-login timestamp update.

### 12.5 Inactive institution

With correct credentials:

- institution user + inactive institution:
  `403 institution_inactive`;
- no token;
- no successful-login timestamp update.

Platform Owner is unaffected by institution status because it has no
institution.

### 12.6 Authority spoofing

Send valid credentials plus client data attempting to spoof:

```json
{
  "role": "platform_owner",
  "institution_id": "other-uuid"
}
```

The authenticated result must remain exactly the persisted user's real role and
institution.

The test does not require extra unknown fields to be rejected if the accepted
request-validation style safely ignores them; it requires that they can never
become authority.

### 12.7 Token persistence

After success:

- exactly expected new Sanctum token exists;
- token owner is UUID user;
- persisted token value is not plaintext token;
- token does not become independent role/institution authority;
- last_login_at updated.

Do not print plaintext token in test output.

### 12.8 Login rate limit

Prove:

- attempts below threshold preserve normal invalid-credential behavior;
- threshold exhaustion returns:
  `429 rate_limited`;
- response matches locked error shape;
- password is not in limiter key;
- successful login reset/clear behavior matches implementation.

Tests must not become flaky from shared limiter state.

### 12.9 `/auth/me`

Institution user:

- no token → `401 authentication_required`;
- valid active token → 200;
- exact user fields;
- exact institution fields:
  `id`, `name`, `status`, `timezone`;
- timezone comes from persisted `institution_settings`;
- no password/token/internal field.

Platform Owner:

- 200;
- institution_id null;
- institution null.

### 12.10 Existing-session deactivation

Issue token first, then mutate state.

User case:

```text
active login
→ token issued
→ user deactivated
→ GET /auth/me
→ 403 user_inactive
```

Institution case:

```text
active institution login
→ token issued
→ institution deactivated
→ GET /auth/me
→ 403 institution_inactive
```

This proves tokens do not cache active status as authority.

### 12.11 Logout

Test:

```text
login
→ logout with token
→ 204 empty
→ same token /auth/me
→ 401 authentication_required
```

Also test current-token-only behavior:

```text
same user has token A and token B
→ logout using token A
→ token A invalid
→ token B remains valid
```

Also test cleanup behavior:

```text
login while active
→ deactivate user or institution
→ logout using issued token
→ 204
→ token removed
```

### 12.12 No first-login gate yet

For user with:

```text
must_change_password = true
```

prove:

- login succeeds;
- `/auth/me` succeeds while account/institution are active;
- flag is true;
- no normal product endpoint is created just to test password gate.

`S01-BE-004` owns the actual gate.

## 13. Quality / Verification Commands

Using the accepted PostgreSQL runtime, run safe equivalents:

```text
php artisan route:list --path=api/v1/auth
php artisan test
vendor/bin/pint --test
composer validate --strict
```

Run accepted earlier mandatory backend checks too.

If network is available and prior workflow uses it, report `composer audit`
without changing unrelated dependencies.

### 13.1 Route verification

Expected public routes only from this task:

```text
POST api/v1/auth/login
POST api/v1/auth/logout
GET  api/v1/auth/me
```

Do not add:

```text
auth/change-password
auth/register
auth/forgot-password
auth/reset-password
auth/refresh
auth/logout-all
auth/tokens
```

### 13.2 Database/test safety

All tests must run against:

`testlabuz_testing`

not normal development DB.

Do not print hashes/tokens.

### 13.3 Scope checks

Before acceptance gate:

```text
git status --short
git diff --check
git diff main...HEAD -- docs
git diff main...HEAD -- frontend
git diff main...HEAD -- docker
git diff main...HEAD -- backend/database/migrations
```

Expected:

- docs unchanged;
- frontend unchanged;
- docker unchanged;
- identity migrations from accepted S01-BE-002 unchanged.

If an accepted dependency defect requires such a change, stop and report it
instead of expanding this task silently.

## 14. Manual Smoke Check

Using controlled test/local accounts without committing credentials:

1. Start accepted backend/PostgreSQL runtime.
2. Login as one active institution user.
3. Confirm 200 token response.
4. Call `/auth/me` with Bearer token.
5. Confirm role/institution/timezone match persisted data.
6. Logout.
7. Confirm same token no longer works.
8. Login with invalid password and confirm generic invalid-credentials error.
9. Verify inactive user login denial.
10. Verify inactive institution user login denial.
11. Verify must-change-password user may authenticate and receives the flag,
    without implementing its gate yet.

Do not place smoke credentials in the repository or final report.

## 15. Explicit Non-Goals

- `POST /api/v1/auth/change-password`.
- Mandatory first-login endpoint gate.
- `password_change_required` middleware/error behavior.
- Role-capability middleware/policies.
- Cross-role product endpoint authorization.
- Institution CRUD.
- User CRUD/account management.
- Refresh tokens.
- Token rotation families.
- Logout all sessions/devices.
- Token/session management UI/API.
- Device registration.
- MFA/2FA.
- Password reset / forgot password.
- Registration.
- Email verification.
- OAuth/OIDC/SSO.
- JWT/Passport.
- SPA cookie/session authentication.
- Flutter.
- CI.
- New Docker service.
- Stage 2+ product APIs.

## 16. Stop Conditions

Stop and report instead of improvising if:

- `S01-BE-002` is not `Accepted`;
- accepted identity schema/factories are absent from `origin/main`;
- Sanctum UUID token persistence is broken in the accepted dependency;
- accepted PostgreSQL test runtime is unavailable;
- local `main` cannot safely synchronize with `origin/main`;
- unrelated dirty state exists;
- approved task branch cannot be created safely;
- locked login/request/response contract differs from this task;
- correct `/auth/me` payload cannot be produced from accepted persisted data;
- a correct solution requires changing locked docs;
- a correct solution requires first-login gate behavior from `S01-BE-004`;
- a correct solution requires role authorization from `S01-BE-005`;
- a secret/token/password would need to be committed/logged;
- safe completion requires destructive Git operations, force-push, history
  rewrite, check bypass, or material scope expansion.

Do not weaken authentication/status checks to avoid a stop condition.

## 17. Execution, Acceptance, and GitHub Delivery Workflow

### Phase 0 — Git Preflight

1. Complete Section 5.1.
2. Verify PostgreSQL runtime and Sanctum persistence.
3. Create/switch to:
   `task/s01-be-003-sanctum-auth-session`.
4. Ensure this approved task and matching Codex prompt exist on the task branch.
5. Update only the `S01-BE-003` Stage 1 index row to `Approved` if required by
   current workflow.
6. Do not commit/push.

### Phase 1 — Implementation

Implement only this task.

Run:

- auth feature tests;
- active-state tests;
- rate-limit tests;
- token persistence/revocation tests;
- route checks;
- full backend suite;
- Pint;
- Composer validation;
- secret/scope checks;
- manual smoke where environment permits.

Do not commit/push.

### Phase 2 — Read-Only Acceptance Gate

Re-read:

- complete `S01-BE-003`;
- root/backend `AGENTS.md`;
- referenced locked API/architecture/roadmap sections;
- full task branch diff;
- route list;
- all test/security evidence.

During Phase 2:

- no file edits;
- no automated fixes;
- no new staging;
- no commit;
- no push;
- no merge.

Classify findings:

- `P1` — blocking security/contract/data-authority issue;
- `P2` — material architecture/test/scope mismatch;
- `P3` — non-blocking observation.

If any P1/P2 remains:

```text
FINAL STATUS: NOT ACCEPTED
```

Return exact evidence and stop.

Do not self-fix after Phase 2 starts.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 passes.

1. Change this task status to `Accepted`.
2. Update `tasks/STAGE_01_TASK_INDEX.md`:
   - Task status `Accepted`;
   - Review status `PASS`;
   - Delivery status finalized after merge.
3. Re-run:
   - `git diff --check`;
   - full secret scan;
   - locked docs/frontend/docker/migration scope checks.
4. Stage only approved task changes.
5. Create one focused commit.

Preferred commit subject:

`feat(auth): add Sanctum session API`

Commit body:

`Task: S01-BE-003`

6. Push task branch to `origin`.
7. Open PR to `main` when authenticated GitHub tooling permits.
8. Never bypass branch protection/checks.
9. Merge only when safely mergeable and required checks pass.
10. Delete remote task branch after merge if normal project policy permits.
11. Synchronize local `main` from `origin/main` with safe fast-forward
    operations.
12. Verify:
    - local `main == origin/main`;
    - working tree clean;
    - accepted task/index exists on `origin/main`.

If review passed but safe delivery cannot complete:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Do not start `S01-BE-004`.

If everything succeeds:

```text
FINAL STATUS: ACCEPTED
```

## 18. Required Codex Final Report

Return:

1. **Final status** — exactly one:
   - `ACCEPTED`
   - `NOT ACCEPTED`
   - `DELIVERY BLOCKED`
2. **Dependency/Git preflight evidence**.
3. **Implementation summary**.
4. **Changed files** grouped by:
   - requests/controllers/actions;
   - middleware/resources/routes/limiter;
   - tests;
   - task bookkeeping.
5. **Authentication contract evidence**:
   - exact routes;
   - login request field;
   - success shape;
   - machine error codes.
6. **Status-authority evidence**:
   - inactive login;
   - existing-token user deactivation;
   - existing-token institution deactivation.
7. **Sanctum evidence**:
   - hashed persistence;
   - Bearer protection;
   - current-token logout;
   - second-token preservation.
8. **Rate-limit evidence**.
9. **Acceptance gate findings**.
10. **Acceptance criteria** PASS/FAIL individually.
11. **Tests/quality gates** exact commands/results.
12. **Security evidence** without exposing credentials/tokens.
13. **Scope confirmation** — no password-change gate/role policy/Stage 2+
    behavior.
14. **GitHub delivery evidence**:
    - commit hash/subject;
    - pushed branch;
    - PR reference if available;
    - merge result;
    - local main hash;
    - origin/main hash;
    - final clean state.
15. **Manual smoke status**.
16. **Remaining blockers/deviations**.

Do not start `S01-BE-004`.
