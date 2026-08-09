# Codex Task: Stage 1 End-to-End Authentication Verification

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S01-INT-004` |
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Area | `Integration / end-to-end verification` |
| Status | `Approved` |
| Depends on | `S01-BE-005 — Role Authorization Foundation (Accepted)`; `S01-FE-004 — Role/Device Entry Routing & Session Isolation (Accepted)` |
| Blocks | `Stage 1 Closure Review` |

This task is approved for Codex execution.

This is the final Stage 1 implementation/verification task. It does **not**
close Stage 1. A separate Stage 1 closure review must run after this task is
`Accepted`.

## 2. Goal

Verify the complete real Stage 1 authentication vertical across:

```text
Flutter UI
→ Riverpod session state
→ Dio
→ Laravel /api/v1
→ Sanctum
→ PostgreSQL
```

and preserve repeatable E2E verification assets for future regression checks.

The accepted result must prove:

- all five approved roles authenticate;
- every role reaches the correct desktop/mobile entry area;
- first-login password change is enforced end to end;
- inactive users are blocked;
- users in inactive institutions are blocked;
- revoked/invalid sessions return to unauthenticated state;
- wrong-role direct Flutter routes are blocked;
- unsupported role/device combinations are blocked;
- logout clears both backend token access and local Flutter session;
- same-role and cross-role account switches do not expose previous-user state;
- the accepted backend role-capability test suite remains green;
- the full backend and frontend regression suites remain green;
- no Stage 2+ feature is required to prove Stage 1.

## 3. Current Context

Repository:

`G:\project\testlabuz`

Approved GitHub remote:

`https://github.com/Shoxrux2017/testlabuz.git`

Required dependencies:

```text
S01-BE-005 = Accepted
S01-FE-004 = Accepted
```

Those dependencies imply all earlier Stage 1 tasks are already accepted.

The accepted stack is expected to contain:

### Backend

- Laravel 13;
- PostgreSQL test runtime;
- UUID Institution/User persistence;
- five exact roles;
- Sanctum login/logout/me;
- active user/institution checks;
- mandatory first-login password change;
- backend role-capability authorization tests.

### Frontend

- Flutter client foundation;
- secure token/session infrastructure;
- login/change-password UX;
- server-authoritative `/auth/me` bootstrap;
- role/device routing;
- desktop/mobile entry shells;
- account-switch/session-isolation guards.

Codex must independently verify dependency status and actual `origin/main`
state before making changes.

## 4. Verification Strategy

Stage 1 verification combines three evidence layers:

### Layer A — Existing automated backend regression

Run the complete accepted Laravel test suite against PostgreSQL.

This proves backend API, identity constraints, Sanctum behavior, password gate,
role authorization, and negative tests.

### Layer B — Existing Flutter unit/widget regression

Run the complete accepted Flutter test suite.

This proves DTO/session/router/role/device/race behavior in deterministic tests.

### Layer C — Real Flutter E2E against real Laravel/PostgreSQL

Add and run Flutter SDK `integration_test` flows against a real local
Stage 1 testing server and real PostgreSQL testing database.

This proves the end-user vertical, not only isolated units.

Do not replace Layer C with mocked HTTP.

## 5. Git / Dependency Preflight

Before implementation:

1. Read root `AGENTS.md`.
2. Read `backend/AGENTS.md`.
3. Read `frontend/AGENTS.md`.
4. Read this complete approved task.
5. Read only the locked specification sections referenced below.
6. Verify both direct dependencies are `Accepted`.
7. Verify their accepted results are on `origin/main`.
8. Verify all prior Stage 1 tasks shown in the Stage 1 index are `Accepted`.
9. Verify approved `origin`.
10. Fetch safely.
11. Verify local `main == origin/main`.
12. Verify no unrelated dirty state exists.
13. Verify Docker/PostgreSQL runtime is available.
14. Verify Flutter Windows target is available.
15. Verify at least one Android emulator/device is available for the required
    mobile E2E verification.

Required task branch:

`task/s01-int-004-stage1-e2e`

If the project owner already saved this approved task and
`S01-INT-004-CODEX-PROMPT.md` under `tasks/integration/stage-01/`, those exact
preparation files are permitted pre-task additions.

Do not commit them on `main`; create the task branch immediately and carry them
into the branch.

If Android E2E cannot run because no emulator/device/toolchain is available,
this task cannot claim full Stage 1 device-surface verification. Report the
environment blocker rather than silently substituting widget tests.

## 6. Flutter Integration Test Infrastructure

Use Flutter's official SDK integration testing package.

Add only:

```yaml
dev_dependencies:
  integration_test:
    sdk: flutter
```

if not already present.

Do not add Patrol, Appium, Selenium, third-party E2E frameworks, or another
test runner.

Create:

```text
frontend/integration_test/stage1_auth_flow_test.dart
```

and small support files under `frontend/integration_test/` only when needed.

The integration test must launch the real Flutter app and use the real accepted
network/session/router stack.

Do not mock Dio/AuthRepository for the E2E test.

## 7. Dedicated E2E Data Safety

E2E verification must never use the normal development database.

Required database:

```text
testlabuz_testing
```

Before any fixture reset/seeding, prove the active backend connection database
is exactly `testlabuz_testing`.

Never run destructive E2E fixture reset against:

```text
testlabuz
```

or another database.

Do not introduce a production database.

## 8. Stage 1 E2E Fixture Seeder

Create one explicit local/testing-only fixture seeder, for example:

```text
backend/database/seeders/Stage1E2eSeeder.php
```

It is permitted because `S01-BE-002` intentionally deferred runtime smoke
accounts to a later integration task.

### 8.1 Environment guard

The seeder must refuse to execute unless:

```text
APP_ENV = testing
```

and the current PostgreSQL database is exactly:

```text
testlabuz_testing
```

Fail closed otherwise.

### 8.2 Credential input

Do not commit passwords.

Seeder must receive the E2E password through local process/environment input,
for example:

```text
STAGE1_E2E_PASSWORD
```

and must fail if it is absent.

A second local value may be used for the first-login change scenario:

```text
STAGE1_E2E_NEW_PASSWORD
```

Do not print either value.

Do not store them in a tracked file.

### 8.3 Repeatability

The seeder may deterministically reset only its own clearly prefixed Stage 1
E2E fixtures so repeated runs begin from the same state.

Use reserved test identifiers/login names such as:

```text
e2e_platform_owner
e2e_institution_admin
e2e_teacher_a
e2e_teacher_b
e2e_student
e2e_parent
e2e_teacher_must_change
e2e_inactive_user
e2e_inactive_institution_user
```

Exact names may differ, but must be clearly E2E-only.

Do not truncate unrelated tables/data beyond what is necessary for the isolated
`testlabuz_testing` reset.

### 8.4 Required fixtures

Create at minimum:

- active institution with settings/timezone;
- inactive institution with settings;
- Platform Owner, password-complete;
- Institution Admin, password-complete;
- Teacher A, password-complete;
- Teacher B, password-complete;
- Student, password-complete;
- Parent, password-complete;
- one active Teacher with `must_change_password = true`;
- one inactive user with valid credentials;
- one active user in inactive institution.

All role/institution relationships must satisfy accepted DB constraints.

No fixture password is hard-coded in source.

## 9. Dedicated E2E Backend Runtime

Run the real Laravel API against:

```text
APP_ENV=testing
DB_DATABASE=testlabuz_testing
```

using the accepted Docker/PHP/PostgreSQL infrastructure.

The E2E HTTP server must bind only to loopback on the host.

Use a dedicated local E2E port so it does not silently reuse a normal
development server.

An example conceptual URL:

```text
http://127.0.0.1:<e2e-port>/api/v1
```

For Android emulator:

```text
http://10.0.2.2:<e2e-port>/api/v1
```

The exact port must be configurable and non-secret.

Do not modify production deployment configuration.

Do not expose the testing backend publicly.

## 10. E2E Credential Delivery to Flutter Tests

The integration test may read E2E-only compile-time values such as:

```text
STAGE1_E2E_PASSWORD
STAGE1_E2E_NEW_PASSWORD
```

through `String.fromEnvironment` or an equivalent test-only mechanism.

The actual secret values must come from the local execution environment.

Do not:

- commit them;
- print them;
- include them in the evidence report;
- put them in production app configuration.

The test should fail clearly if required E2E values are absent.

## 11. Windows Desktop E2E Matrix

Run the real Flutter integration test on Windows.

Required role/device outcomes:

```text
Platform Owner
→ /platform-owner

Institution Admin
→ /institution-admin

Teacher
→ /teacher desktop entry

Student
→ /student desktop entry

Parent
→ /unsupported-device
```

For each account:

1. start from unauthenticated login;
2. enter real test credentials through UI;
3. submit login;
4. wait for real API/session bootstrap;
5. assert expected route/shell;
6. assert current fixture identity is visible where designed;
7. logout through UI;
8. assert `/login`;
9. verify old protected shell is no longer visible.

Do not bypass UI login by directly injecting session state for the E2E matrix.

## 12. Android Mobile E2E Matrix

Run the same real integration flow on an Android emulator/device.

Required:

```text
Platform Owner
→ /unsupported-device

Institution Admin
→ /unsupported-device

Teacher
→ /teacher mobile entry

Student
→ /student mobile entry

Parent
→ /parent
```

Use the accepted Android-accessible loopback mapping for the local backend.

All five role/device outcomes are mandatory.

## 13. First-Login Password Change E2E

Using the dedicated must-change Teacher fixture:

```text
login
→ /change-password
```

Prove through real UI/API:

1. login succeeds;
2. cannot reach `/teacher` before password change;
3. wrong current password returns safe UI error;
4. valid current + new + confirmation succeeds;
5. backend returns 204;
6. Flutter refreshes `/auth/me`;
7. server returns `must_change_password = false`;
8. user reaches the correct Teacher entry for the current device;
9. logout works;
10. old password no longer authenticates;
11. new password authenticates.

Run this flow on at least one real target.

Router/widget regression must continue to prove the gate on both surfaces.

## 14. Invalid Credentials E2E

Through real login UI/API:

```text
unknown/wrong credentials
→ invalid_credentials UX
→ no authenticated shell
→ no token-backed session
```

Do not reveal whether login name exists.

## 15. Inactive User E2E

Using valid credentials for the inactive-user fixture:

```text
login
→ 403 user_inactive
→ safe UX
→ no authenticated shell
→ no local session retained
```

## 16. Inactive Institution E2E

Using valid credentials for a user in the inactive institution:

```text
login
→ 403 institution_inactive
→ safe UX
→ no authenticated shell
→ no local session retained
```

## 17. Logout / Revoked Session E2E

Through real UI/API:

```text
login
→ role shell
→ logout
→ backend revokes current Sanctum token
→ Flutter clears local token/session
→ /login
```

Then verify a protected real backend request with the revoked token cannot
authenticate.

Do not print the token.

If test harness needs to inspect this condition, keep token only in test memory
and redact it from logs.

## 18. Same-Role Account Switch E2E

Required:

```text
Teacher A
→ /teacher
→ logout
→ Teacher B
→ /teacher
```

Assert:

- Teacher B identity is visible;
- Teacher A identity is absent;
- old institution/profile state is absent;
- no shell flash restores A.

## 19. Cross-Role Account Switch E2E

Required:

```text
Teacher A
→ /teacher
→ logout
→ Student
→ /student
```

Assert:

- Student shell is current;
- Teacher shell absent;
- Teacher A identity absent;
- no stale redirect/session result restores Teacher.

## 20. Direct Route / Backend Authorization Evidence

### 20.1 Flutter direct-route denial

Use accepted Flutter router tests and, where safely possible in integration
test, direct navigation attempts to prove users cannot render another role's
shell.

At minimum preserve/execute FE-004 cross-route matrix.

### 20.2 Backend role authorization

Do not create a fake production product endpoint for E2E.

Run the complete accepted `S01-BE-005` role authorization suite as integration
evidence, including:

```text
5 allowed role cases
20 cross-role denials
```

The lack of a Stage 1 role-specific production resource endpoint is intentional
and must not be "fixed" by inventing Stage 2 product APIs.

## 21. Full Regression Gates

### Backend

Using accepted PostgreSQL test runtime:

```text
php artisan test
vendor/bin/pint --test
composer validate --strict
```

Run all additional accepted mandatory backend checks.

### Frontend

From `frontend/`:

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test integration_test
flutter build windows --debug
flutter build apk --debug
```

### Real integration tests

Run Windows integration test using the real E2E backend.

Use the official Flutter integration-test invocation appropriate to the
accepted Flutter version, targeting Windows explicitly when possible.

Run the same Stage 1 E2E test on a connected Android emulator/device.

Commands in the final evidence/report must redact actual password values.

## 22. Evidence Artifact

Create:

```text
tasks/integration/stage-01/S01-INT-004-stage-01-e2e-evidence.md
```

Only after verification.

It must record:

- date;
- commit/branch under test;
- Docker/PHP/PostgreSQL/Laravel versions;
- Flutter/Dart versions;
- Windows target;
- Android device/emulator identifier/model without sensitive personal device
  data;
- backend quality command results;
- frontend quality command results;
- Windows E2E scenario results;
- Android E2E scenario results;
- first-login flow result;
- inactive user/institution results;
- logout/revoked-session result;
- same-role account-switch result;
- cross-role account-switch result;
- direct-route test result;
- backend role-matrix regression result;
- known non-blocking limitations.

Do **not** include:

- passwords;
- access tokens;
- password hashes;
- secrets;
- full environment dumps.

The evidence file is a Stage 1 closure input. It is not itself the closure
decision.

## 23. Relevant Files

Expected high-value change surface:

| Path | Expected action |
|---|---|
| `frontend/pubspec.yaml` | Add only Flutter SDK `integration_test` dev dependency if needed |
| `frontend/pubspec.lock` | Update reproducibly |
| `frontend/integration_test/stage1_auth_flow_test.dart` | Create real-stack E2E test |
| `frontend/integration_test/*` | Small E2E support only if required |
| `backend/database/seeders/Stage1E2eSeeder.php` | Create guarded testing-only fixture seeder |
| `backend/tests/*` | Add only seeder/environment guard test if needed |
| `tasks/integration/stage-01/S01-INT-004-stage-01-e2e-authentication-verification.md` | Preserve |
| `tasks/integration/stage-01/S01-INT-004-CODEX-PROMPT.md` | Preserve |
| `tasks/integration/stage-01/S01-INT-004-stage-01-e2e-evidence.md` | Create sanitized evidence |
| `tasks/STAGE_01_TASK_INDEX.md` | Lifecycle update only |

Do not modify locked `docs/01–09`.

Do not add Stage 2+ feature code.

## 24. Authoritative Specification References

| Document | Section | Requirement |
|---|---|---|
| `docs/06-roadmap.md` | `6. Stage 1 — Authentication and Role-Based Entry` | Five-role authentication, device surfaces, inactive-state blocking, protected access, session isolation |
| `docs/07-architecture.md` | `9. Identity and Authorization Architecture` | Sanctum, persisted roles, account/institution state, layered authorization |
| `docs/07-architecture.md` | `20. Flutter Application Architecture` | Real client data/session boundaries |
| `docs/07-architecture.md` | `21. Flutter Navigation Architecture` | Role-aware guards |
| `docs/07-architecture.md` | `22. Role/Device Feature Boundary` | Desktop/mobile role surfaces |
| `docs/07-architecture.md` | `32. Testing Architecture` | Backend/Flutter/integration verification |
| `docs/09-api-contracts.md` | `3. Authentication Contract` | login/logout/me/change-password |
| `docs/09-api-contracts.md` | `4. Current User / Session Contract` | Server session bootstrap authority |
| `docs/09-api-contracts.md` | `5. Stable Error Codes` | Auth/account/authorization machine codes |
| `backend/AGENTS.md` | Testing/security/authorization rules | Backend quality |
| `frontend/AGENTS.md` | Testing/session/navigation rules | Frontend quality |
| `tasks/STAGE_01_TASK_INDEX.md` | Stage-Wide Verification Map | Final Stage 1 scenario ownership |

## 25. Acceptance Criteria

- [ ] Both direct dependencies are `Accepted` on `origin/main`.
- [ ] All earlier Stage 1 tasks are recorded `Accepted`.
- [ ] Work occurs on `task/s01-int-004-stage1-e2e`.
- [ ] E2E uses `testlabuz_testing`, never development DB.
- [ ] E2E seeder refuses non-testing / wrong-database execution.
- [ ] No E2E password is committed.
- [ ] Flutter SDK `integration_test` is the only newly approved test dependency.
- [ ] Real Windows Flutter E2E runs against real Laravel/PostgreSQL.
- [ ] Real Android Flutter E2E runs against real Laravel/PostgreSQL.
- [ ] Windows matrix passes all 5 role outcomes.
- [ ] Android matrix passes all 5 role outcomes.
- [ ] All five roles successfully authenticate while active/valid.
- [ ] First-login must-change flow passes end to end.
- [ ] Wrong current password is handled safely.
- [ ] Old password fails after successful change.
- [ ] New password succeeds after successful change.
- [ ] Invalid credentials are blocked.
- [ ] Inactive user is blocked.
- [ ] Inactive institution user is blocked.
- [ ] Logout clears Flutter session and backend current token.
- [ ] Revoked token cannot authenticate.
- [ ] Same-role Teacher A → Teacher B exposes only B.
- [ ] Cross-role Teacher → Student exposes only Student.
- [ ] Wrong-role direct Flutter routes remain blocked.
- [ ] Unsupported device/role combinations remain blocked.
- [ ] Backend 5-allow/20-deny role matrix remains green.
- [ ] Full backend test suite passes.
- [ ] Backend Pint passes.
- [ ] Composer validation passes.
- [ ] Flutter analyze passes.
- [ ] Flutter unit/widget tests pass.
- [ ] Flutter formatting passes.
- [ ] Windows debug build passes.
- [ ] Android debug build passes.
- [ ] Sanitized E2E evidence file exists.
- [ ] No locked doc/product contract changed.
- [ ] No Stage 2+ product feature was added.
- [ ] No secret/token/password was committed or reported.

## 26. Required Scenario Summary

The final evidence must explicitly list PASS/FAIL for:

### Authentication

```text
Platform Owner
Institution Admin
Teacher
Student
Parent
```

### Desktop

```text
Platform Owner → Platform Owner entry
Institution Admin → Institution Admin entry
Teacher → Teacher desktop entry
Student → Student desktop entry
Parent → Unsupported Device
```

### Mobile

```text
Platform Owner → Unsupported Device
Institution Admin → Unsupported Device
Teacher → Teacher mobile entry
Student → Student mobile entry
Parent → Parent mobile entry
```

### Negative / security

```text
invalid credentials
inactive user
inactive institution
must_change_password
wrong current password
revoked token
wrong-role direct route
unsupported role/device
same-role account switch
cross-role account switch
```

No scenario may be silently omitted.

## 27. Quality / Scope Checks

Before acceptance gate:

```text
git status --short
git diff --check
git diff main...HEAD -- docs
```

Locked docs must remain unchanged.

Inspect all task changes for:

- hard-coded E2E passwords;
- `.env`;
- access tokens;
- password hashes;
- private keys;
- production fixture credentials;
- production-only test routes;
- Stage 2+ APIs/features.

Verify E2E fixture seeder is guarded against development/production use.

Verify test routes from prior backend authorization work remain absent from
production runtime.

## 28. Manual Smoke Requirement

Even with automated integration tests, perform one human-observable smoke on:

### Windows

At minimum:

```text
Teacher login
→ Teacher desktop entry
→ logout
→ Student login
→ Student desktop entry
```

### Android

At minimum:

```text
Parent login
→ Parent mobile entry
→ logout
→ Teacher login
→ Teacher mobile entry
```

Do not store/report credentials.

If Codex environment cannot perform a required human-observable check but
automated E2E passes, record that limitation. It is a closure-review input; do
not silently claim the manual check ran.

## 29. Explicit Non-Goals

- Stage 1 closure decision.
- Stage 2 institution management.
- Stage 3 user management.
- Groups/Topics/Materials/Homework/Blitz.
- Real role dashboards.
- Product navigation beyond accepted entry shells.
- New production auth endpoint.
- New production test/debug endpoint.
- New role/permission system.
- CI/GitHub Actions.
- Cloud device lab.
- Production deployment.
- Web support.
- MFA.
- Refresh tokens.
- Device/session management.
- Demo credentials committed to repository.

## 30. Stop Conditions

Stop and report if:

- either direct dependency is not `Accepted`;
- any prior required Stage 1 task is not actually accepted/delivered;
- local `main` cannot synchronize with `origin/main`;
- unrelated dirty state exists;
- task branch cannot be created safely;
- Docker/PostgreSQL testing runtime is unavailable;
- testing DB cannot be proven as `testlabuz_testing`;
- E2E seeder cannot be safely environment/database guarded;
- Windows Flutter integration test cannot run;
- Android emulator/device integration test cannot run;
- accepted backend/frontend contract is inconsistent;
- completing verification requires a Stage 2+ production endpoint;
- a password/token/secret would need to be committed/reported;
- safe completion requires destructive Git, force-push, history rewrite, or
  check bypass;
- material scope expansion is required.

Do not downgrade E2E requirements to mock/unit tests merely to obtain PASS.

## 31. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git / Environment Preflight

1. Complete Section 5.
2. Create/switch to:
   `task/s01-int-004-stage1-e2e`.
3. Ensure approved task/prompt are on task branch.
4. Verify test DB, Windows target, Android target.
5. Do not commit/push.

### Phase 1 — Implementation / Verification

Implement only verification assets required by this task.

Then:

1. run full backend regression;
2. run full frontend regression/builds;
3. safely prepare/reset E2E fixtures;
4. run real Windows E2E;
5. safely reset E2E fixtures where necessary;
6. run real Android E2E;
7. run required manual smoke;
8. create sanitized evidence file;
9. run scope/secret checks.

Do not commit/push.

### Phase 2 — Read-Only Acceptance Gate

Re-read:

- complete `S01-INT-004`;
- root/backend/frontend `AGENTS.md`;
- referenced locked contracts;
- complete branch diff;
- all backend/frontend results;
- Windows/Android E2E results;
- evidence file;
- secret/scope checks.

No edits, auto-fixes, new staging, commit, push, or merge.

Findings:

- `P1` — Stage 1 auth/security/E2E failure or data-leak issue;
- `P2` — material verification/scope/test/reproducibility mismatch;
- `P3` — non-blocking observation.

If any P1/P2 remains:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop. Do not self-fix after Phase 2 starts.

### Phase 3 — Post-Acceptance Git Delivery

Only after Phase 2 PASS:

1. Set this task `Accepted`.
2. Update Stage 1 index:
   - Task `Accepted`;
   - Review `PASS`;
   - Delivery finalized after merge;
   - Stage itself remains **In Progress / Not Closed**.
3. Update finalized sanitized evidence if only lifecycle/hash metadata is needed.
4. Re-run final secret/scope checks.
5. Stage only approved verification/task changes.
6. Commit:

```text
test(stage1): add authentication end-to-end verification
```

Body:

```text
Task: S01-INT-004
```

7. Push task branch.
8. Create PR to `main`.
9. Do not bypass checks.
10. Merge only when safe/green.
11. Sync local `main` with `origin/main`.
12. Verify local `main == origin/main` and clean tree.
13. Do **not** mark Stage 1 closed.

If review PASS but delivery fails:

```text
FINAL STATUS: DELIVERY BLOCKED
```

If all succeeds:

```text
FINAL STATUS: ACCEPTED
```

The next action is the separate Stage 1 Closure Review, not Stage 2.

## 32. Required Codex Final Report

Return:

1. Final status: `ACCEPTED`, `NOT ACCEPTED`, or `DELIVERY BLOCKED`.
2. Dependency / all-Stage-1-task preflight.
3. Environment:
   - Docker;
   - PHP/Laravel;
   - PostgreSQL;
   - Flutter/Dart;
   - Windows target;
   - Android target.
4. Verification assets changed/created.
5. Test fixture safety evidence.
6. Backend full regression results.
7. Frontend full regression/build results.
8. Windows E2E matrix — all five roles.
9. Android E2E matrix — all five roles.
10. First-login password-change E2E result.
11. Invalid/inactive negative E2E results.
12. Logout/revoked-token result.
13. Same-role account-switch result.
14. Cross-role account-switch result.
15. Direct-route / unsupported-device result.
16. Backend role-matrix regression result.
17. Manual smoke result.
18. Sanitized evidence-file path.
19. Acceptance findings.
20. Acceptance criteria PASS/FAIL.
21. Security/scope evidence.
22. GitHub delivery evidence:
    - commit hash/subject;
    - task branch;
    - PR reference;
    - merge result;
    - local/main hashes;
    - clean status.
23. Confirmation:
    `Stage 1 was NOT marked Closed by this task.`
24. Remaining blockers/deviations.

Do not start Stage 2.
Do not perform the Stage 1 closure review inside this task.
