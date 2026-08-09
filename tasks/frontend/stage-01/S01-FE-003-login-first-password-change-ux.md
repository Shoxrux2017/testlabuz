# Codex Task: Login & First-Login Password Change UX

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S01-FE-003` |
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Area | `Frontend / authentication UX` |
| Status | `Approved` |
| Depends on | `S01-FE-002 — Authentication Data & Session Foundation (Accepted)`; `S01-BE-004 — Mandatory First-Login Password Change Gate (Accepted)` |
| Blocks | `S01-FE-004 — Role/Device Entry Routing & Session Isolation` |

This task is approved for Codex execution.

Codex must still enforce all dependency, Git preflight, scope, verification,
read-only acceptance, and GitHub delivery gates defined below.

## 2. Goal

Implement the real Flutter authentication user experience for Stage 1:

- login screen;
- login form validation and submission;
- authentication/loading/error feedback;
- mandatory first-login password-change screen;
- `POST /api/v1/auth/change-password` integration;
- server-authoritative `must_change_password` routing;
- secure post-password-change session refresh;
- authenticated/unauthenticated auth-route transitions;
- accessibility and keyboard usability suitable for desktop and mobile.

This task must **not** implement the final role/device entry routing or role
shells. Those belong to `S01-FE-004`.

The accepted result must make the authentication flow complete up to the point
where an authenticated, password-complete session is ready to be handed to the
next routing layer.

## 3. Current Context

Repository:

`G:\project\testlabuz`

Approved GitHub remote:

`https://github.com/Shoxrux2017/testlabuz.git`

Required dependencies:

```text
S01-FE-002 = Accepted
S01-BE-004 = Accepted
```

Accepted frontend session foundation is expected to provide:

- `AuthUser` / `AuthInstitution`;
- exact five-role session model;
- `AuthRepository`;
- `AuthRemoteDataSource`;
- secure token persistence;
- Bearer interceptor;
- `/auth/me` bootstrap;
- `signIn(login, password)`;
- `signOut()`;
- session invalidation handling;
- stale async result/account-switch protection;
- Riverpod auth session state/controller.

Accepted backend first-login task is expected to provide:

```text
POST /api/v1/auth/change-password
```

with:

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

Errors:

```text
422 validation_failed
409 current_password_invalid
401 authentication_required
403 user_inactive
403 institution_inactive
```

and server-side first-login enforcement through:

```text
must_change_password = true
```

Codex must independently verify the accepted dependencies on `origin/main`.

## 4. UX Boundary

This task owns only authentication UX.

### Included routes

The Flutter router may now expose:

```text
/login
/change-password
```

and one existing/minimal authenticated transition target needed to represent:

```text
authenticated + must_change_password = false
```

before `S01-FE-004` adds final role/device destinations.

Do not create role-specific production routes in this task.

Do not create:

```text
/platform-owner
/institution-admin
/teacher
/student
/parent
```

or dashboards/shells yet.

### Auth flow

Expected logical flow:

```text
App bootstrap
  ↓
no session
  → /login

login succeeds
  ↓
session.must_change_password == true
  → /change-password

login succeeds
  ↓
session.must_change_password == false
  → authenticated transition state
  → final role/device destination is deferred to S01-FE-004
```

After successful password change:

```text
POST /auth/change-password
→ 204
→ refresh current session through /auth/me
→ must_change_password == false
→ leave /change-password
→ authenticated transition state
```

Flutter must not clear the flag locally without re-reading server authority.

## 5. Included Scope

### 5.1 Git / dependency preflight

Before implementation:

1. Read root `AGENTS.md`.
2. Read `frontend/AGENTS.md`.
3. Read this complete approved task.
4. Read only the locked specification sections referenced by this task.
5. Verify both dependencies are `Accepted`.
6. Verify their accepted results are present on `origin/main`.
7. Verify approved `origin`.
8. Fetch safely.
9. Verify local `main == origin/main`.
10. Verify no unrelated dirty state exists.
11. Verify accepted Flutter toolchain/build baseline remains available.

Required task branch:

`task/s01-fe-003-auth-ux`

If the project owner already saved this approved task and
`S01-FE-003-CODEX-PROMPT.md` under `tasks/frontend/stage-01/`, those exact
preparation files are permitted pre-task additions.

Do not commit them on `main`; create the task branch immediately and carry them
into the branch.

### 5.2 Change-password data operation

Extend the existing auth data/repository layer minimally to support:

```text
changePassword(
  currentPassword,
  newPassword,
  newPasswordConfirmation,
)
```

Remote endpoint:

```text
POST /auth/change-password
```

Request keys are exactly:

```text
current_password
new_password
new_password_confirmation
```

Success:

```text
204
```

Do not create a separate first-login endpoint.

Do not send:

```text
user_id
role
institution_id
must_change_password
```

as mutation inputs.

### 5.3 Post-change session refresh

After backend returns `204`:

1. do not manually mutate `must_change_password`;
2. call the accepted authenticated `/auth/me`;
3. replace the current session only with the refreshed server result;
4. require the refreshed session to report:
   `must_change_password = false`;
5. if the refreshed response still reports `true`, remain in the password-change
   state and surface a safe failure rather than bypassing the backend gate.

If refresh gets:

```text
401 authentication_required
```

use the accepted global session invalidation behavior and return to
unauthenticated flow.

If refresh gets:

```text
403 user_inactive
403 institution_inactive
```

clear invalid local session according to accepted FE-002 behavior.

If the 204 succeeded but `/auth/me` then fails only due to transport:

- keep secure token;
- do not claim password-change completion locally;
- surface retryable failure;
- allow the user to retry session refresh without re-submitting the password
  change if the implementation can cleanly distinguish this state.

Do not submit the same password-change mutation automatically on retry.

### 5.4 Login screen

Create a real production login screen.

Required visible fields:

```text
Login
Password
```

Required action:

```text
Sign in
```

Do not show:

- Role selector;
- Institution selector;
- Registration;
- Forgot password;
- Social login;
- Remember me;
- demo account buttons.

The public field label may be localized/user-friendly, but the API request must
use `login`.

### 5.5 Login form behavior

Required:

- login field;
- password field;
- password obscured by default;
- optional local visibility toggle is allowed;
- keyboard submit from password field;
- desktop Enter submit;
- loading state;
- disable duplicate submit while in flight;
- do not clear login on ordinary credential failure;
- do not log password;
- do not persist password;
- trim only the login identifier if consistent with backend contract;
- do not trim/mutate password content before sending.

Local validation is UX-only.

At minimum:

```text
login required
password required
```

Do not duplicate the entire backend validation policy in the UI.

Backend remains authoritative.

### 5.6 Login server-error presentation

Map typed failures without parsing message text.

At minimum support UX behavior for:

```text
422 validation_failed
401 invalid_credentials
403 user_inactive
403 institution_inactive
429 rate_limited
transport failure
timeout
unexpected/malformed response
```

Requirements:

- field errors may be attached to the relevant field where available;
- account-level errors appear in a clear non-field error area;
- human-readable backend message may be displayed when safe;
- control flow must use typed code/status;
- no raw stack trace / Dio exception / token / password in UI.

Do not create client-authoritative role/institution decisions from error text.

### 5.7 Login success routing

`signIn` from accepted FE-002 establishes canonical session through `/auth/me`.

After successful sign-in:

```text
if AuthUser.must_change_password == true
  → /change-password
else
  → authenticated transition target
```

Do not route based on role yet.

Do not persist role/device destination.

### 5.8 Change-password screen

Create a real authenticated password-change screen.

Required fields:

```text
Current password
New password
Confirm new password
```

Required action:

```text
Change password
```

Requirements:

- password fields obscured by default;
- separate or shared visibility toggles are acceptable if accessible;
- loading state;
- duplicate submit blocked;
- keyboard navigation works;
- confirmation field can submit;
- do not display plaintext values after successful completion;
- do not log field contents.

The screen must explain briefly that password change is required when entered
because `must_change_password = true`.

Do not invent a separate onboarding wizard.

### 5.9 Change-password validation

Mirror only the approved technical UX baseline:

```text
current password required
new password required
confirm password required
new password minimum 8 characters
new password maximum 255 characters
confirmation must match
new password should differ from current password
```

Backend remains authoritative.

Do not invent mandatory uppercase/lowercase/digit/symbol rules.

### 5.10 Change-password error presentation

Handle:

```text
422 validation_failed
409 current_password_invalid
401 authentication_required
403 user_inactive
403 institution_inactive
transport failure
timeout
unexpected failure
```

`current_password_invalid` should attach to current-password UX where
appropriate.

Do not invent:

```text
password_change_required
```

as a backend machine code.

### 5.11 Auth route guards owned by this task

Implement only authentication-state and first-login-state redirects required for
these two auth screens.

Required behavior:

#### Unauthenticated

```text
/login
→ allowed

/change-password
→ redirect /login

authenticated transition route
→ redirect /login
```

#### Authenticated + must_change_password = true

```text
/login
→ redirect /change-password

/change-password
→ allowed

authenticated transition route
→ redirect /change-password
```

#### Authenticated + must_change_password = false

```text
/login
→ redirect authenticated transition route

/change-password
→ redirect authenticated transition route
```

Do not add role/device authorization logic.

### 5.12 Bootstrapping UX

While FE-002 session bootstrap is unresolved:

- do not briefly show login then authenticated content;
- do not briefly show an authenticated transition route then login;
- render a neutral loading/bootstrap surface.

This surface must not be a product dashboard.

After bootstrap resolves:

```text
unauthenticated
→ /login

authenticated + must_change_password
→ /change-password

authenticated + password complete
→ authenticated transition route
```

### 5.13 Authenticated transition target

Because `S01-FE-004` owns role/device routing, use the smallest possible
temporary authenticated transition screen/route.

It must:

- be clearly technical/transitional;
- not pretend to be a role dashboard;
- not expose later feature UI;
- provide no role-specific navigation;
- be easy for `S01-FE-004` to replace/remove.

A route such as:

```text
/authenticated
```

is acceptable.

Do not use `/home` if that would imply a locked product destination not yet
defined.

### 5.14 Logout access from transition screen

The authenticated transition screen may expose one minimal technical logout
action so Stage 1 auth UX can be manually verified before FE-004.

If included:

- call accepted `signOut`;
- after local session clears, router goes to `/login`;
- no role/product navigation added.

Do not add logout to password-change screen as a replacement for completing
required change; however logout may be available as a secondary safe escape
action because the backend explicitly permits it during the first-login gate.

If logout is exposed on password-change screen, it must be clearly secondary.

### 5.15 UI architecture

Use the accepted architecture:

```text
Widget
→ Riverpod controller/session operation
→ AuthRepository
→ remote data source
```

Do not call Dio directly from widgets.

Do not read secure storage directly from widgets.

Do not place routing decisions inside repositories.

### 5.16 Responsive boundary

The same login/change-password screens must be usable on:

- Windows desktop;
- Android/mobile-sized viewport.

Do not build separate business logic per device.

Use responsive constraints so forms do not stretch unreasonably on desktop.

No final role-specific desktop/mobile shell is implemented.

### 5.17 Accessibility / keyboard

At minimum:

- logical tab order;
- Enter/submit behavior;
- semantic labels for password visibility controls;
- visible validation/error text;
- loading does not silently accept duplicate clicks;
- focus can move to relevant invalid field where reasonable;
- text remains readable at common text scale.

Do not add a new accessibility package.

## 6. Session / Security Rules

### 6.1 Server-authoritative first-login state

Routing uses only:

```text
AuthUser.must_change_password
```

returned by backend `/auth/me`.

Do not infer required password change from:

- role;
- local flag;
- whether user has logged in before;
- client timestamp;
- route history.

### 6.2 No local bypass

Never set:

```text
must_change_password = false
```

locally merely because the password-change endpoint returned 204.

Only refreshed `/auth/me` may establish the false state.

### 6.3 Password secrecy

Never:

- persist current/new passwords;
- log them;
- place them in route arguments;
- put them in provider state longer than the form/request lifecycle;
- include them in error objects/reports.

Controllers should not retain completed password values after success.

### 6.4 Token behavior

Use accepted FE-002 token/session infrastructure.

Do not:

- read token in widget;
- show token;
- rotate token after password change;
- create refresh-token logic.

### 6.5 Stale operation safety

Respect FE-002 generation/race protection.

Examples:

```text
login request in flight
→ user triggers another auth state transition
→ old login result must not force wrong route
```

```text
password-change refresh in flight
→ session invalidated/logout
→ delayed refresh must not restore old session
```

Do not introduce a second competing session controller.

## 7. Relevant Files

Expected high-value change surface:

| Path | Expected action |
|---|---|
| `frontend/lib/features/auth/presentation/login/*` | Create real login screen/form |
| `frontend/lib/features/auth/presentation/change_password/*` | Create password-change screen/form |
| `frontend/lib/features/auth/application/*` | Add small form/controller state if needed |
| `frontend/lib/features/auth/data/auth_remote_data_source.dart` | Add changePassword |
| `frontend/lib/features/auth/domain/auth_repository.dart` | Add changePassword contract |
| `frontend/lib/features/auth/data/auth_repository_impl.dart` | Add change + session refresh behavior |
| `frontend/lib/features/auth/application/auth_session_controller.dart` | Minimal refresh/change-password orchestration |
| `frontend/lib/app/router/*` | Add auth routes + auth/password-state redirects |
| `frontend/lib/shared/*` | Add only genuinely reusable tiny auth UI helpers if needed |
| `frontend/test/features/auth/*` | Add widget/controller/repository tests |
| `frontend/test/app/router/*` | Add auth redirect/bootstrap tests |
| `tasks/frontend/stage-01/S01-FE-003-login-first-password-change-ux.md` | Preserve |
| `tasks/frontend/stage-01/S01-FE-003-CODEX-PROMPT.md` | Preserve |
| `tasks/STAGE_01_TASK_INDEX.md` | Lifecycle update only |

Do not modify:

- locked `docs/01–09`;
- `backend/`;
- `docker/`.

Do not add role-specific shells/routes.

## 8. Authoritative Specification References

| Document | Section | Requirement |
|---|---|---|
| `docs/05-business-rules.md` | User/onboarding rules | Admin-created institution accounts must change initial password |
| `docs/06-roadmap.md` | `6. Stage 1 — Authentication and Role-Based Entry` | Login screen, password handling, protected navigation, role entry stage |
| `docs/07-architecture.md` | `9.3 Authentication` | `must_change_password`, Sanctum session authority |
| `docs/07-architecture.md` | `20. Flutter Application Architecture` | Riverpod, repository/data-source, secure storage |
| `docs/07-architecture.md` | `21. Flutter Navigation Architecture` | Route guards and session-aware navigation |
| `docs/09-api-contracts.md` | `3.1 Login` | Exact login request/errors |
| `docs/09-api-contracts.md` | `3.3 Current User` | `must_change_password` session state |
| `docs/09-api-contracts.md` | `3.4 Change Password` | Exact request/204/errors |
| `docs/09-api-contracts.md` | `4. Current User / Session Contract` | `/auth/me` is authoritative bootstrap |
| `docs/09-api-contracts.md` | `5.1 Stable Error Codes` | Preserve server codes |
| `frontend/AGENTS.md` | UI/state/routing/API/testing rules | Frontend implementation discipline |
| `AGENTS.md` | Current Git/task workflow | Branch/review/delivery/scope |
| `tasks/STAGE_01_TASK_INDEX.md` | `S01-FE-003` row | Approved scope/dependency |

## 9. Functional Requirements

1. `S01-FE-002` verified `Accepted`.
2. `S01-BE-004` verified `Accepted`.
3. Work occurs on `task/s01-fe-003-auth-ux`.
4. `/login` production route exists.
5. `/change-password` production route exists.
6. Login screen has Login + Password + Sign in.
7. No role/institution selector exists.
8. Login sends exact backend `login` field.
9. Password is not trimmed/mutated/persisted/logged.
10. Duplicate login submit is blocked.
11. Login loading state exists.
12. Login validation/error presentation works.
13. Login uses FE-002 `signIn`.
14. Session authority after login remains `/auth/me`.
15. `must_change_password=true` routes to `/change-password`.
16. Password-complete auth routes to minimal authenticated transition target.
17. Change-password screen has current/new/confirmation fields.
18. `changePassword` data/repository operation exists.
19. Request keys exactly match backend.
20. Successful 204 refreshes `/auth/me`.
21. Flutter does not locally clear must-change flag before refresh.
22. Refreshed false flag exits password-change screen.
23. Refreshed true flag does not bypass the gate.
24. `409 current_password_invalid` handled correctly.
25. `422 validation_failed` field errors handled.
26. Auth/account-state failures use typed server codes.
27. Unauthenticated cannot remain on `/change-password`.
28. Must-change authenticated user cannot escape to authenticated transition.
29. Password-complete authenticated user is redirected away from auth screens.
30. Bootstrap has neutral loading state with no auth-content flash.
31. No role/device route logic exists.
32. No role-specific shell/dashboard exists.
33. Same UX is usable on desktop/mobile viewport.
34. Keyboard submit/navigation works.
35. Password visibility controls, if present, are accessible.
36. Full FE-002 regression tests remain green.
37. `flutter analyze` passes.
38. `flutter test` passes.
39. format check passes.
40. Windows debug build passes.
41. Android debug build passes.
42. docs/backend/docker unchanged.

## 10. Required Automated Tests

### 10.1 Login widget tests

Test:

- renders Login/Password/Sign in;
- password obscured by default;
- no role selector;
- no institution selector;
- empty submit shows validation;
- one field missing;
- keyboard submit;
- loading disables duplicate submit;
- invalid credentials shows safe account error;
- inactive user error;
- inactive institution error;
- rate-limited error;
- backend field validation mapping;
- transport failure;
- password never rendered in error/debug text.

### 10.2 Login routing tests

Using provider/router overrides:

```text
unauthenticated
→ /login
```

Successful sign-in +:

```text
must_change_password=true
→ /change-password
```

Successful sign-in +:

```text
must_change_password=false
→ authenticated transition route
```

No role-specific route assertion belongs here.

### 10.3 Change-password repository tests

Test exact request:

```text
current_password
new_password
new_password_confirmation
```

Success 204 then `/auth/me` refresh.

Cases:

- refresh false flag → success;
- refresh still true → failure/remain gated;
- 409 current_password_invalid;
- 422 validation;
- 401 invalidated session;
- inactive user/institution;
- transport failure after 204 does not locally claim flag false;
- retry refresh does not resubmit password mutation.

### 10.4 Change-password widget tests

Test:

- required three fields;
- obscured values;
- confirmation mismatch;
- short password;
- too-long password;
- new == current;
- current-password-invalid field error;
- loading/duplicate submit;
- success flow;
- no password leakage.

### 10.5 Router guard tests

#### Unauthenticated

```text
/login allowed
/change-password → /login
/authenticated → /login
```

#### Authenticated must-change

```text
/login → /change-password
/change-password allowed
/authenticated → /change-password
```

#### Authenticated password-complete

```text
/login → authenticated
/change-password → authenticated
authenticated allowed
```

#### Bootstrapping

Neutral loading surface, no flash of login/authenticated content.

### 10.6 Logout transition tests

If logout is exposed by auth UX:

- transition target logout → unauthenticated `/login`;
- password-change secondary logout → unauthenticated `/login`;
- local state clears even if backend logout fails, per FE-002.

### 10.7 Stale operation regression

Prove FE-003 routing does not defeat FE-002 race protection.

Examples:

- delayed sign-in after logout does not force auth route;
- delayed password-change refresh after logout does not restore session;
- route redirect reads current session, not old captured user.

### 10.8 Responsive/widget smoke tests

At minimum test representative:

- narrow mobile viewport;
- desktop-sized viewport.

No overflow in login/password-change forms.

### 10.9 Regression

All accepted FE-001/FE-002 tests remain green.

## 11. Quality / Verification Commands

From `frontend/`:

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
flutter build windows --debug
flutter build apk --debug
```

Do not add a new package unless materially necessary and separately reported.

### Scope checks

Before acceptance gate:

```text
git status --short
git diff --check
git diff main...HEAD -- docs
git diff main...HEAD -- backend
git diff main...HEAD -- docker
```

Expected: no changes.

Review dependency files for unexpected package additions.

Scan for:

- plaintext passwords;
- token logging;
- `.env`;
- hard-coded role/institution authority;
- role-specific route implementations.

## 12. Manual Smoke Check

Using controlled local accounts outside the repository:

1. Launch backend runtime.
2. Launch Flutter desktop with valid API base.
3. Confirm bootstrap goes to login.
4. Login with invalid credentials.
5. Login with active user whose `must_change_password=true`.
6. Confirm forced change-password screen.
7. Confirm user cannot navigate to authenticated transition route before
   password change.
8. Submit wrong current password and verify safe error.
9. Submit valid password change.
10. Confirm session refresh and exit from password-change screen.
11. Logout and confirm return to login.
12. Login with password-complete account and confirm authenticated transition.
13. Repeat core flow on Android/mobile viewport/device/emulator where available.
14. Confirm no role-specific final destination is implemented yet.

Do not store smoke credentials in repository/report.

## 13. Explicit Non-Goals

- Final role/device route mapping.
- Platform Owner shell.
- Institution Admin shell.
- Teacher desktop/mobile shell.
- Student desktop/mobile shell.
- Parent mobile shell.
- Role-specific navigation/menu/dashboard.
- Stage 2+ product UI.
- Registration.
- Forgot/reset password.
- Admin reset password.
- MFA.
- Remember me.
- Refresh tokens.
- Device/session management.
- Design system overhaul.
- Backend/Docker changes.
- New stable backend error codes.

## 14. Stop Conditions

Stop and report if:

- `S01-FE-002` is not `Accepted`;
- `S01-BE-004` is not `Accepted`;
- accepted session controller/repository is absent/broken;
- accepted backend change-password contract differs materially;
- local `main` cannot synchronize;
- unrelated dirty state exists;
- task branch cannot be created safely;
- correct UX requires final role/device routes from FE-004;
- correct implementation requires backend contract changes;
- a new package is materially required but unapproved;
- password/token would need to be logged/persisted;
- safe completion requires destructive Git/force-push/history rewrite/check
  bypass;
- material scope expansion is required.

## 15. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git Preflight

Create/switch to:

`task/s01-fe-003-auth-ux`

Ensure approved task/prompt are on task branch.

Do not commit/push.

### Phase 1 — Implementation

Implement only this task.

Run:

- login widget/controller tests;
- change-password data/widget tests;
- router/guard tests;
- bootstrap UX tests;
- responsive tests;
- FE-002 race/session regression;
- full Flutter tests;
- analyze;
- format;
- Windows/Android builds;
- scope/security checks.

Do not commit/push.

### Phase 2 — Read-Only Acceptance Gate

Re-read task, locked docs, root/frontend AGENTS, complete diff, route behavior,
tests/build/security evidence.

No edits, auto-fixes, new staging, commit, push, or merge.

Findings:

- `P1` blocking auth/security/gate bypass issue;
- `P2` material API/UX/routing/test/scope mismatch;
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
3. Re-run final tests/scope/secret checks.
4. Stage only approved changes.
5. Commit:

```text
feat(auth): add login and password-change UX
```

Body:

```text
Task: S01-FE-003
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

Do not start `S01-FE-004`.

## 16. Required Codex Final Report

Return:

1. Final status: `ACCEPTED`, `NOT ACCEPTED`, or `DELIVERY BLOCKED`.
2. Dependency/Git preflight.
3. Implementation summary.
4. Changed files grouped by:
   - login UI;
   - change-password UI/data;
   - router/auth redirects;
   - tests;
   - task bookkeeping.
5. Login contract/UX evidence.
6. Change-password contract/refresh evidence.
7. `must_change_password` server-authority evidence.
8. Auth-route guard evidence.
9. Bootstrap no-flash evidence.
10. Accessibility/responsive evidence.
11. Session/race regression evidence.
12. Acceptance findings.
13. Acceptance criteria PASS/FAIL.
14. Analyze/test/format/build evidence.
15. Security/scope evidence.
16. GitHub delivery evidence.
17. Manual smoke status.
18. Remaining blockers/deviations.

Do not start `S01-FE-004`.
