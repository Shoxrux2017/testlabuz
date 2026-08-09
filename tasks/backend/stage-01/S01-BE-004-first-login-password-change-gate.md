# Codex Task: Mandatory First-Login Password Change Gate

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S01-BE-004` |
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Area | `Backend / authentication security` |
| Status | `Accepted` |
| Depends on | `S01-BE-003 — Sanctum Authentication & Session API (Accepted)` |
| Blocks | `S01-BE-005 — Role Authorization Foundation` |

This task is approved for Codex execution.

Codex must still enforce all dependency, Git preflight, scope, testing,
read-only acceptance, and GitHub delivery gates defined below.

## 2. Goal

Implement the mandatory first-login password-change backend behavior required by
Stage 1, while preserving the locked authentication contract and keeping role
authorization separate for `S01-BE-005`.

The accepted result must provide:

```text
POST /api/v1/auth/change-password
```

and a reusable backend gate that enforces:

```text
must_change_password = true
→ normal protected application endpoints are not usable
```

while still allowing the authenticated user to use:

```text
GET  /api/v1/auth/me
POST /api/v1/auth/change-password
POST /api/v1/auth/logout
```

The password-change operation must:

- verify the authenticated user's current password;
- validate/confirm the new password;
- hash the new password;
- set `must_change_password = false`;
- persist both changes atomically;
- return `204 No Content`;
- preserve the accepted Sanctum session/token behavior unless a locked contract
  explicitly requires otherwise.

This task implements the backend first-login gate. It does not implement
Flutter password-change UX or role-capability authorization.

## 3. Current Context

Repository:

`G:\project\testlabuz`

Approved GitHub remote:

`https://github.com/Shoxrux2017/testlabuz.git`

Required dependency:

`S01-BE-003 = Accepted`

The accepted dependency is expected to provide:

- `POST /api/v1/auth/login`;
- `POST /api/v1/auth/logout`;
- `GET /api/v1/auth/me`;
- Laravel Sanctum Bearer-token authentication;
- current-user active-state enforcement;
- current-institution active-state enforcement;
- `must_change_password` in login/current-user payloads;
- PostgreSQL-backed authentication tests.

The accepted `S01-BE-002` persistence foundation is expected to enforce that
administrator-created Institution Admin/Teacher/Student/Parent onboarding
accounts can carry:

```text
must_change_password = true
```

Codex must independently verify all accepted dependencies on `origin/main`.

## 4. Source-Contract Boundary

### 4.1 Locked change-password endpoint

The locked API contract defines:

```text
POST /api/v1/auth/change-password
```

Allowed:

```text
Authenticated users
```

Request:

```json
{
  "current_password": "old-password",
  "new_password": "new-password",
  "new_password_confirmation": "new-password"
}
```

Success:

```text
204 No Content
```

Endpoint-specific errors:

```text
422 validation_failed
409 current_password_invalid
```

The locked API document mentions that an onboarding variant *may* omit
`current_password` if such behavior is explicitly documented before
implementation.

This task does **not** approve that optional variant.

Therefore, the current implementation contract requires `current_password` for
both:

- mandatory first-login password change;
- normal authenticated password change.

Do not create a second endpoint such as:

```text
/auth/change-initial-password
```

and do not omit current-password verification.

### 4.2 Password-change gate contract

The approved Stage 1 task index requires:

```text
must_change_password = true
```

to block normal protected application functionality while still allowing:

```text
/auth/me
/auth/change-password
/auth/logout
```

This must be a server-side backend gate.

A Flutter redirect alone is insufficient.

### 4.3 Machine-code rule for the gate

The locked API contract explicitly defines the stable machine code:

```text
password_change_required
```

for authenticated users whose persisted session state still has:

```text
must_change_password = true
```

A normal protected endpoint denied by this mandatory first-login gate must
return exactly:

```text
HTTP 403
code = password_change_required
errors = {}
```

Do not replace this specific gate result with generic:

```text
403 forbidden
```

because `password_change_required` is an authoritative Stage 1 API contract
used by the Flutter client to distinguish mandatory onboarding from ordinary
authorization denial.

The server-authoritative session flag:

```text
must_change_password = true
```

returned by `/auth/me` remains the corresponding session state.

Flutter control flow may use the stable machine code and/or the authoritative
session flag, but must never parse human-readable `message` text.

If the current locked `docs/09-api-contracts.md` on the execution branch differs
materially from this approved contract, stop and report the specification
conflict instead of silently choosing another code.

## 5. Included Scope

### 5.1 Git / dependency preflight

Before implementation:

1. Read root `AGENTS.md`.
2. Read `backend/AGENTS.md`.
3. Read this complete approved task.
4. Read only the locked specification sections referenced by this task.
5. Verify `S01-BE-003` is `Accepted`.
6. Verify its accepted implementation is present on `origin/main`.
7. Verify approved `origin`.
8. Fetch remote state safely.
9. Verify local `main == origin/main`.
10. Verify no unrelated dirty state exists.
11. Verify accepted PostgreSQL test runtime is usable.

Required task branch:

`task/s01-be-004-first-password-change`

If the project owner already saved this approved task and
`S01-BE-004-CODEX-PROMPT.md` under `tasks/backend/stage-01/` before execution,
those exact preparation files are permitted pre-task additions.

In that case:

- verify they are the only permitted pre-task additions;
- do not commit them on `main`;
- create the task branch immediately from synchronized `main`;
- carry them into the task branch;
- perform implementation/delivery only from the task branch.

Any other unexplained dirty state is a blocker.

### 5.2 Change-password request

Create a focused request object, for example:

`ChangePasswordRequest`

Public fields are exactly:

```text
current_password
new_password
new_password_confirmation
```

Do not accept:

```text
user_id
login
role
institution_id
must_change_password
```

as authoritative mutation targets.

The authenticated user is always the password-change target.

### 5.3 New-password validation

The locked product/API documents do not define a complete user-facing password
complexity policy.

This approved task therefore selects only a conservative technical Stage 1
minimum and does not claim that it is a permanent product password policy.

Required technical validation baseline:

```text
current_password:
  required
  string
  bounded request length

new_password:
  required
  string
  confirmed
  minimum 8 characters
  maximum 255 characters
  different from current_password

new_password_confirmation:
  required through confirmed semantics
```

Do not invent composition requirements such as mandatory:

```text
uppercase
lowercase
digit
symbol
compromised-password network lookup
```

unless the current locked repository contract already defines them.

A future approved password-policy change may strengthen this baseline through
normal change control.

### 5.4 Current-password verification

The request must be authenticated with Sanctum first.

Verify:

```text
current_password
```

against the authenticated user's current password hash using Laravel Hash
services.

If it does not match:

```text
HTTP 409
code = current_password_invalid
errors = {}
```

Requirements:

- no password change;
- `must_change_password` remains unchanged;
- current token/session remains unchanged;
- do not reveal hash details;
- do not log submitted current/new password.

Do not return `invalid_credentials` for this endpoint because the locked
endpoint defines `current_password_invalid`.

### 5.5 Password update transaction

Implement one focused application action/service, conceptually:

`ChangePassword`

On valid request/current password:

1. hash `new_password`;
2. update authenticated user password;
3. set:
   `must_change_password = false`;
4. persist both in one database transaction;
5. return `204 No Content`.

The final stored password must never equal the submitted plaintext value.

The update must not modify:

```text
role
institution_id
is_active
last_login_at
created_by_user_id
```

### 5.6 Token/session behavior after change

The locked Stage 1 API contract does not require token rotation or
all-session revocation after password change.

Therefore this task must not invent:

- token-family rotation;
- refresh-token rotation;
- logout-all;
- other-device revocation;
- new token issuance.

The current authenticated Sanctum token remains valid after a successful
password change.

Other already-issued valid tokens are not automatically revoked by this task.

Advanced session/device management remains excluded from Stage 1.

### 5.7 Reusable mandatory-password gate

Create one reusable middleware/guard, conceptually:

`EnsurePasswordChanged`

It must run only after:

```text
auth:sanctum
EnsureAccountIsActive
```

Behavior:

```text
if authenticated user.must_change_password == true
  → deny normal protected application endpoint
else
  → continue
```

Denial uses exactly:

```text
HTTP 403
code = password_change_required
errors = {}
```

This is a mandatory locked Stage 1 machine code, not a generic authorization
fallback.

Do not hard-code an allow-list of URI strings inside the middleware.

Instead, route composition must ensure the middleware is attached only to
normal protected application routes that require completed onboarding.

The following authentication endpoints must intentionally **not** use this
gate:

```text
GET  /api/v1/auth/me
POST /api/v1/auth/change-password
POST /api/v1/auth/logout
```

This makes the boundary explicit and reusable for future role/product route
groups.

### 5.8 Gate testing without fake product endpoints

Stage 1 does not yet have normal role-specific product endpoints that belong in
this task.

Do **not** create a fake production endpoint solely to test the gate.

Use one of:

- a test-only route registered only in the test environment;
- a direct middleware integration test using the framework test harness.

The test-only protected route should exercise the real middleware order:

```text
auth:sanctum
active-account/institution
password-changed
```

It must not become part of production `route:list`.

### 5.9 Interaction with active-state enforcement

`/auth/change-password` must require:

```text
auth:sanctum
+
accepted active-account/institution guard
```

Therefore:

- inactive user → `403 user_inactive`;
- institution user in inactive institution → `403 institution_inactive`;
- Platform Owner follows its accepted no-institution rule;
- logout remains the security-cleanup endpoint that can revoke a valid token
  even when user/institution has become inactive, as established by
  `S01-BE-003`.

The password-change gate itself must not replace or weaken active-state checks.

### 5.10 Normal password change after onboarding

Because the locked endpoint is allowed for authenticated users, it is not
first-login-only.

A user with:

```text
must_change_password = false
```

may still call:

```text
POST /api/v1/auth/change-password
```

with a valid current password and valid new password.

Success still:

- changes password;
- keeps `must_change_password = false`;
- returns `204`.

Do not create separate "normal" and "initial" password-change endpoints.

## 6. Route Contract

After this task, auth routes are:

```text
POST /api/v1/auth/login
POST /api/v1/auth/logout
GET  /api/v1/auth/me
POST /api/v1/auth/change-password
```

Route intent:

```text
login
  public
  accepted login limiter

logout
  auth:sanctum
  [no active-state requirement, per accepted S01-BE-003 cleanup rule]
  [no password-change gate]

me
  auth:sanctum
  active-account/institution
  [no password-change gate]

change-password
  auth:sanctum
  active-account/institution
  [no password-change gate]
```

Future normal protected route composition after this task becomes:

```text
auth:sanctum
→ active-account/institution
→ password-changed
→ role/scope authorization
```

When the password-changed middleware rejects an authenticated user with
`must_change_password = true`, its exact public response is:

```text
HTTP 403
code = password_change_required
errors = {}
```

Role/scope authorization belongs to `S01-BE-005`.

## 7. Error Contract

Use the accepted centralized error foundation.

### Missing/invalid token

```text
401 authentication_required
errors = {}
```

### Inactive user

```text
403 user_inactive
errors = {}
```

### Inactive institution

```text
403 institution_inactive
errors = {}
```

### Validation

```text
422 validation_failed
errors = field-object
```

Examples:

- missing current password;
- missing new password;
- confirmation mismatch;
- new password shorter than technical minimum;
- new password longer than schema-compatible maximum;
- new password identical to current password input.

### Wrong current password

```text
409 current_password_invalid
errors = {}
```

This endpoint-specific code is explicitly defined by the locked change-password
contract.

### Mandatory-password gate

```text
403 password_change_required
errors = {}
```

This stable machine code is explicitly defined by the locked Stage 1 API
contract.

Do not replace it with generic `forbidden`.

## 8. Relevant Files

Expected high-value change surface:

| Path | Expected action | Reason |
|---|---|---|
| `backend/routes/api.php` | Add change-password route / middleware composition | Locked endpoint |
| `backend/app/Http/Requests/Auth/ChangePasswordRequest.php` | Create | Exact request validation |
| `backend/app/Actions/Auth/ChangePassword.php` or equivalent | Create | Atomic password + flag update |
| `backend/app/Http/Controllers/Api/V1/Auth/*` | Add focused endpoint controller/method | HTTP boundary |
| `backend/app/Http/Middleware/EnsurePasswordChanged.php` | Create | Mandatory backend first-login gate |
| `backend/bootstrap/app.php` or accepted middleware-registration location | Register middleware alias if needed | Reusable future route composition |
| `backend/tests/Feature/Auth/*` | Add change-password/gate tests | Acceptance evidence |
| `backend/tests/*` test-only route support | Add only if necessary | Gate verification without production fake endpoint |
| `tasks/backend/stage-01/S01-BE-004-first-login-password-change-gate.md` | Preserve | Approved task |
| `tasks/backend/stage-01/S01-BE-004-CODEX-PROMPT.md` | Preserve | Manual execution prompt |
| `tasks/STAGE_01_TASK_INDEX.md` | Lifecycle update only | Stage control |

Do not modify:

- locked `docs/01–09`;
- `frontend/`;
- `docker/`;
- identity migrations/schema;
- Sanctum token schema.

If an accepted dependency defect requires changing one of those boundaries,
stop and report instead of silently expanding scope.

## 9. Authoritative Specification References

| Document | Exact section | Requirement used |
|---|---|---|
| `docs/05-business-rules.md` | User/account onboarding rules where applicable | Administrator-created institution accounts use first-login password change |
| `docs/06-roadmap.md` | `6. Stage 1 — Authentication and Role-Based Entry` | Authentication/security/protected endpoint foundation |
| `docs/07-architecture.md` | `9. Identity and Authorization Architecture` | `must_change_password`, backend authority, layered authorization |
| `docs/09-api-contracts.md` | `2.2 Empty Success` | 204 response has no JSON body |
| `docs/09-api-contracts.md` | `2.3 Error Envelope` | Expected API error shape |
| `docs/09-api-contracts.md` | `2.6 Authorization Error` | Existing `403 forbidden` contract |
| `docs/09-api-contracts.md` | `3.2 Logout` | Logout security-cleanup behavior |
| `docs/09-api-contracts.md` | `3.3 Current User` | `must_change_password` is exposed by server session profile |
| `docs/09-api-contracts.md` | `3.4 Change Password` | Exact endpoint/request/success/errors |
| `docs/09-api-contracts.md` | `4. Current User / Session Contract` | `/auth/me` is Flutter session authority |
| `docs/09-api-contracts.md` | `5.1 Stable Error Codes` | No unapproved stable error-code additions |
| `backend/AGENTS.md` | Auth/security/API/testing rules | Backend implementation discipline |
| `AGENTS.md` | Current task/Git workflow | Branch/review/delivery/scope |
| `tasks/STAGE_01_TASK_INDEX.md` | `S01-BE-004` row and additional auth contract map | Dependency, mandatory password-change gate, allowed endpoints |

## 10. Security Requirements

### 10.1 Password secrecy

Never:

- log current password;
- log new password;
- log password confirmation;
- return password/hash in API;
- include passwords in exception messages;
- include passwords in final Codex report;
- persist plaintext password.

### 10.2 Hashing

Use Laravel's accepted password hashing facilities.

Do not:

- call raw SHA/MD5;
- choose a custom cryptographic format;
- store both old/new hashes;
- create password history tables in this task.

### 10.3 Atomic state transition

The successful onboarding transition is:

```text
password = hash(new_password)
must_change_password = false
```

Both must persist atomically.

Do not clear `must_change_password` before password update succeeds.

### 10.4 Server-side enforcement

The frontend route guard is not security enforcement.

Later protected API routes must be able to compose the reusable password gate.

A client manually calling a protected endpoint must still be denied when the
flag is true.

### 10.5 No authority mutation

Password change cannot mutate:

- role;
- institution;
- active status;
- tenant ownership;
- token abilities;
- permissions.

## 11. Functional Requirements

1. `S01-BE-003` is independently verified as `Accepted`.
2. Work occurs on `task/s01-be-004-first-password-change`.
3. `POST /api/v1/auth/change-password` exists.
4. Endpoint requires Sanctum authentication.
5. Endpoint requires accepted active-user/institution guard.
6. Request requires `current_password`.
7. Request requires `new_password`.
8. Request requires matching `new_password_confirmation`.
9. New password follows the approved technical Stage 1 validation baseline.
10. Wrong current password returns `409 current_password_invalid`.
11. Validation failures return `422 validation_failed`.
12. Successful password is hashed.
13. Successful change atomically sets `must_change_password = false`.
14. Success returns empty `204`.
15. User with `must_change_password = true` can call `/auth/me`.
16. User with `must_change_password = true` can call `/auth/change-password`.
17. User with `must_change_password = true` can call `/auth/logout`.
18. User with `must_change_password = true` is denied from a normal protected
    middleware test surface.
19. Mandatory gate denial uses exact locked
    `403 password_change_required`.
20. `password_change_required` is treated as an existing authoritative stable
    API code, not a newly invented code.
21. User with `must_change_password = false` passes the reusable password gate.
22. After successful first-login change, the same user passes that gate.
23. A normal authenticated user with flag false may also change password.
24. Wrong current password does not change password or flag.
25. Invalid new-password request does not change password or flag.
26. Successful change does not mutate role/institution/active state.
27. Current Sanctum token remains valid after successful password change.
28. No automatic logout-all/token rotation is introduced.
29. Full backend tests pass against PostgreSQL.
30. Pint and Composer validation remain green.
31. Locked docs/frontend/docker/schema remain unchanged.
32. No role-capability authorization is implemented.

## 12. Required Automated Tests

### 12.1 Authentication requirement

No token:

```text
POST /api/v1/auth/change-password
→ 401 authentication_required
```

### 12.2 Request validation

Test at minimum:

- missing current_password;
- missing new_password;
- missing confirmation;
- confirmation mismatch;
- too-short new password;
- too-long new password;
- new password equal to current password input.

Each:

```text
422 validation_failed
```

with field error object.

### 12.3 Wrong current password

For valid active account/token:

```text
wrong current password
→ 409 current_password_invalid
```

Then prove:

- password hash unchanged;
- `must_change_password` unchanged;
- token remains usable;
- no secret leaked.

### 12.4 Successful first-login change

For each administrator-created institution role:

```text
institution_admin
teacher
student
parent
```

with:

```text
must_change_password = true
```

prove:

```text
valid current password
+ valid confirmed new password
→ 204
```

Then prove:

- old password no longer authenticates;
- new password authenticates;
- DB password is hashed;
- `must_change_password = false`;
- role unchanged;
- institution_id unchanged;
- is_active unchanged.

Do not require Platform Owner to start with the flag true.

### 12.5 Platform Owner / normal authenticated change

For Platform Owner or another active user with:

```text
must_change_password = false
```

prove normal authenticated password change works through the same endpoint and
the flag remains false.

### 12.6 Active-state interaction

Issue token while active.

Then:

User inactive:

```text
POST /auth/change-password
→ 403 user_inactive
```

Institution inactive:

```text
POST /auth/change-password
→ 403 institution_inactive
```

Logout behavior from accepted `S01-BE-003` must still remain available for
cleanup.

### 12.7 Allowed endpoints while first-login flag is true

With active authenticated user and `must_change_password = true`:

```text
GET /auth/me
→ allowed

POST /auth/change-password
→ allowed

POST /auth/logout
→ allowed
```

Use separate tokens/users as needed so logout does not invalidate subsequent
assertions accidentally.

### 12.8 Normal protected-route gate

Using test-only middleware surface:

Before change:

```text
must_change_password = true
→ 403 password_change_required
```

Response:

```text
errors = {}
```

After successful password change:

```text
must_change_password = false
→ protected test route succeeds
```

User already false:

```text
→ protected test route succeeds
```

Do not add a production fake route.

### 12.9 Middleware order

Prove on the protected test surface:

```text
unauthenticated
→ 401 authentication_required

inactive user
→ 403 user_inactive

inactive institution
→ 403 institution_inactive

active + must_change_password
→ 403 password_change_required

active + password changed
→ success
```

This confirms order:

```text
auth
→ active status
→ password gate
```

### 12.10 Token behavior

After successful password change:

- current token still authenticates `/auth/me`;
- another already-valid token for same user is not silently revoked;
- no new token is issued by change-password response;
- response remains `204`.

### 12.11 Regression tests

All accepted `S01-BE-003` tests remain green, including:

- login;
- logout current token;
- `/auth/me`;
- active/inactive enforcement;
- invalid credentials;
- rate limiting;
- token hashing.

## 13. Quality / Verification Commands

Using the accepted PostgreSQL runtime, run safe equivalents:

```text
php artisan route:list --path=api/v1/auth
php artisan test
vendor/bin/pint --test
composer validate --strict
```

Run additional mandatory backend checks established by accepted dependencies.

### 13.1 Route verification

Expected production auth route set after this task:

```text
POST api/v1/auth/login
POST api/v1/auth/logout
GET  api/v1/auth/me
POST api/v1/auth/change-password
```

Do not add:

```text
auth/change-initial-password
auth/register
auth/forgot-password
auth/reset-password
auth/refresh
auth/logout-all
auth/tokens
```

### 13.2 Test database safety

All persistence tests use:

`testlabuz_testing`

Never destructive-test the normal development DB.

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

- locked docs unchanged;
- frontend unchanged;
- docker unchanged;
- identity migrations unchanged.

Also inspect for:

- `.env`;
- plaintext passwords;
- tokens;
- app keys;
- private keys/certificates;
- credential-bearing URLs.

Do not print secret values.

## 14. Manual Smoke Check

Using controlled local/test accounts without committing credentials:

1. Login as an active Teacher with `must_change_password = true`.
2. Confirm `/auth/me` returns flag true.
3. Confirm normal password-gated test surface is denied.
4. Change password through `/auth/change-password`.
5. Confirm `204`.
6. Confirm same token can call `/auth/me`.
7. Confirm `/auth/me` now returns flag false.
8. Confirm normal password-gated test surface now succeeds.
9. Confirm old password cannot login.
10. Confirm new password can login.
11. Confirm logout still revokes current token.
12. Confirm no password/token appears in logs/report.

No production fake endpoint should be added for this smoke check.

## 15. Explicit Non-Goals

- Role authorization policies.
- Role middleware/capability map.
- Cross-role product endpoint tests.
- Flutter change-password UI.
- Flutter routing.
- Password reset / forgot-password.
- Admin password reset.
- Registration.
- MFA/2FA.
- Password history.
- Password expiration.
- Compromised-password external lookup.
- Account lockout policy beyond accepted login rate limit.
- Refresh tokens.
- Token rotation after password change.
- Logout all sessions.
- Device/session management.
- User CRUD.
- Institution CRUD.
- Stage 2+ APIs.
- New DB table/migration.
- New Docker service.
- CI changes.
- Replacing/removing the locked `password_change_required` API code.

## 16. Stop Conditions

Stop and report instead of improvising if:

- `S01-BE-003` is not `Accepted`;
- accepted auth/session endpoints are absent from `origin/main`;
- accepted active-account/institution middleware is unavailable/broken;
- local `main` cannot safely synchronize with `origin/main`;
- unrelated dirty state exists;
- approved task branch cannot be created safely;
- the current locked API contract has changed the change-password request,
  response, or error behavior;
- the current locked API contract differs materially from the approved
  `password_change_required` first-login gate contract;
- implementing the gate requires modifying locked docs;
- a correct solution requires role authorization from `S01-BE-005`;
- a correct solution requires Flutter behavior;
- an accepted dependency defect would require schema/Docker changes;
- a password/token/credential would need to be logged or committed;
- safe completion requires destructive Git operations, force-push, history
  rewrite, check bypass, or material scope expansion.

Do not invent a new stable API error code to avoid a stop condition.

## 17. Execution, Acceptance, and GitHub Delivery Workflow

### Phase 0 — Git Preflight

1. Complete Section 5.1.
2. Verify accepted authentication runtime.
3. Create/switch to:
   `task/s01-be-004-first-password-change`.
4. Ensure this approved task and matching Codex prompt exist on the task branch.
5. Update only the `S01-BE-004` Stage 1 index row to `Approved` if required by
   current workflow.
6. Do not commit/push.

### Phase 1 — Implementation

Implement only this task.

Run:

- change-password validation/behavior tests;
- first-login gate tests;
- active-state interaction tests;
- token-regression tests;
- full backend suite;
- Pint;
- Composer validation;
- route checks;
- secret/scope checks;
- manual smoke where environment permits.

Do not commit/push.

### Phase 2 — Read-Only Acceptance Gate

Re-read:

- complete `S01-BE-004`;
- root/backend `AGENTS.md`;
- referenced locked contracts;
- full task-branch diff;
- route list;
- test/security evidence.

During Phase 2:

- no file edits;
- no automated fixes;
- no new staging;
- no commit;
- no push;
- no merge.

Classify findings:

- `P1` — blocking security/contract issue;
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
   - secret scan;
   - locked docs/frontend/docker/schema scope checks.
4. Stage only approved task changes.
5. Create one focused commit.

Preferred commit subject:

`feat(auth): enforce first-login password change`

Commit body:

`Task: S01-BE-004`

6. Push task branch to `origin`.
7. Open PR to `main` when authenticated GitHub tooling permits.
8. Never bypass branch protection/checks.
9. Merge only when safely mergeable and required checks pass.
10. Delete remote task branch after successful merge if normal policy permits.
11. Synchronize local `main` from `origin/main` using fast-forward-safe
    operations.
12. Verify:
    - local `main == origin/main`;
    - working tree clean;
    - accepted task/index state exists on `origin/main`.

If review passed but safe delivery cannot complete:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Do not start `S01-BE-005`.

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
   - request/action/controller;
   - middleware/route registration;
   - tests;
   - task bookkeeping.
5. **Change-password contract evidence**:
   - exact route;
   - exact request fields;
   - `204`;
   - `422 validation_failed`;
   - `409 current_password_invalid`.
6. **First-login gate evidence**:
   - allowed auth endpoints;
   - normal protected denial;
   - middleware order;
   - exact `403 password_change_required` use.
7. **Password security evidence** without exposing password/hash values.
8. **Token behavior evidence**.
9. **Acceptance gate findings**.
10. **Acceptance criteria** PASS/FAIL individually.
11. **Tests/quality gates** exact commands/results.
12. **Scope confirmation** — no role authorization/Flutter/Stage 2+ behavior.
13. **GitHub delivery evidence**:
    - commit hash/subject;
    - pushed branch;
    - PR reference if available;
    - merge result;
    - local main hash;
    - origin/main hash;
    - final clean state.
14. **Manual smoke status**.
15. **Remaining blockers/deviations**.

Do not start `S01-BE-005`.
