# Codex Task: Role Authorization Foundation

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S01-BE-005` |
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Area | `Backend / authorization` |
| Status | `Approved` |
| Depends on | `S01-BE-004 — Mandatory First-Login Password Change Gate (Accepted)` |
| Blocks | `S01-FE-001 — Flutter Client Scaffold & Core Infrastructure`; `S01-INT-004 — Stage 1 End-to-End Authentication Verification` |

This task is approved for Codex execution.

Codex must enforce all dependency, Git preflight, scope, testing, read-only
acceptance, and GitHub delivery gates below.

## 2. Goal

Implement the reusable backend **role-capability authorization layer** required
by Stage 1, using the five persisted MVP roles as server-authoritative identity.

The accepted authorization order must remain:

```text
1. auth:sanctum
2. active user / active institution
3. mandatory password-change gate
4. role capability
5. later institution ownership
6. later relationship scope
7. later lifecycle/business conditions
```

This task owns **Layer 3 — Role Capability** only.

It must not create speculative product permissions, resource policies, tenant
query scopes, relationship checks, or Stage 2+ endpoints.

## 3. Current Context

Repository:

`G:\project\testlabuz`

Approved GitHub remote:

`https://github.com/Shoxrux2017/testlabuz.git`

Required dependency:

`S01-BE-004 = Accepted`

Accepted backend state is expected to already contain:

- Laravel 13 API foundation;
- exact five-role `UserRole`;
- PostgreSQL identity persistence;
- Sanctum Bearer authentication;
- active user/institution guard;
- mandatory first-login password gate;
- centralized `403 forbidden` API error behavior.

Codex must independently verify the dependency on `origin/main`.

## 4. Locked Role Model

Exact MVP roles:

```text
platform_owner
institution_admin
teacher
student
parent
```

Each account has one primary persisted role.

Do not introduce:

- custom roles;
- multiple roles per user;
- permission tables;
- role-permission tables;
- user-defined permissions;
- per-token role selection;
- arbitrary extra role strings.

Role authority comes only from the authenticated persisted `User`.

## 5. Included Scope

### 5.1 Git / dependency preflight

Before implementation:

1. Read root `AGENTS.md`.
2. Read `backend/AGENTS.md`.
3. Read this complete approved task.
4. Read only the locked specification sections referenced below.
5. Verify `S01-BE-004` is `Accepted`.
6. Verify its accepted implementation is on `origin/main`.
7. Verify approved `origin`.
8. Fetch remote state safely.
9. Verify local `main == origin/main`.
10. Verify no unrelated dirty state exists.
11. Verify accepted PostgreSQL/auth test runtime is usable.

Required task branch:

`task/s01-be-005-role-authorization`

If the project owner already saved this approved task and
`S01-BE-005-CODEX-PROMPT.md` under `tasks/backend/stage-01/`, those exact
preparation files are permitted pre-task additions.

Do not commit them on `main`; create the task branch immediately and carry them
into the branch.

### 5.2 Reusable role middleware

Create one small reusable middleware, conceptually:

`EnsureUserHasRole`

or an equally clear equivalent.

It must support route middleware declarations equivalent to:

```text
role:platform_owner
role:institution_admin
role:teacher
role:student
role:parent
```

and multiple explicitly allowed roles:

```text
role:teacher,student
```

The allowed-role list is trusted server route configuration, never client input.

### 5.3 Role evaluation

The middleware must:

1. operate only after authentication;
2. read the current persisted user role;
3. compare it with the server-configured allowed role(s);
4. allow only exact matches;
5. otherwise return:

```text
HTTP 403
code = forbidden
errors = {}
```

Do not invent:

```text
wrong_role
role_mismatch
teacher_forbidden
```

or any other role-specific stable API code.

### 5.4 Canonical role source

Reuse the accepted `UserRole` enum/model cast.

Do not create a second role enum or duplicate canonical role values.

If server route configuration contains an invalid role value, fail closed.
Treat that as developer/configuration failure, not as an allowed role.

### 5.5 Middleware alias

Register one clear alias, recommended:

```text
role
```

so future route composition can be:

```text
auth:sanctum
→ active-account/institution
→ password-changed
→ role:<allowed roles>
```

Do not create five separate classes such as `EnsureTeacher`,
`EnsureStudent`, etc.

### 5.6 No Platform Owner universal bypass

Do **not** make Platform Owner automatically pass all role checks.

Required:

- Platform Owner passes only routes explicitly allowing `platform_owner`;
- Platform Owner fails Teacher-only routes;
- Platform Owner fails Institution Admin-only routes;
- Platform Owner fails Student-only routes;
- Platform Owner fails Parent-only routes.

This preserves the architecture distinction between platform administration
and institution learning operations.

### 5.7 No permission system yet

Do not add:

- Spatie Permission;
- any other RBAC package;
- permission tables;
- capability tables;
- role-permission seeds;
- full future product permission matrix.

Do not predefine speculative permissions such as:

```text
teacher.create_topic
student.submit_homework
parent.view_result
```

Those belong with actual product actions/resources.

### 5.8 No speculative Policies / tenant scopes

Do not create future Laravel Policies or query scopes for:

- Institution management;
- Group;
- Topic;
- Homework;
- Blitz;
- Submission;
- Result.

Role capability is only one authorization layer.

Institution ownership, relationship scope, and lifecycle rules must be added
with real resources later.

### 5.9 Test-only authorization routes

Do not create fake production endpoints just to test authorization.

Use test-only routes/harnesses registered only in testing.

Provide test-only single-role surfaces for all five roles and at least one
multi-role surface:

```text
teacher + student
```

These test routes must be absent from production `route:list`.

### 5.10 Middleware order

Test surfaces must use the real accepted security order:

```text
auth:sanctum
→ active account/institution
→ password changed
→ role capability
```

Expected precedence:

```text
no token
→ 401 authentication_required

inactive user
→ 403 user_inactive

inactive institution
→ 403 institution_inactive

must_change_password = true
→ 403 forbidden from password gate

active + password-complete + wrong role
→ 403 forbidden from role layer

active + password-complete + allowed role
→ success
```

## 6. Tenant Boundary

This task does not implement resource tenant scoping.

Preserve these constraints:

- institution role never implies cross-institution access;
- direct IDs must not bypass future tenant scoping;
- Platform Owner is not automatically unscoped;
- role middleware does not accept `institution_id`;
- future resource policies/query scopes must enforce tenant ownership separately.

True cross-institution resource tests become applicable when institution-owned
resources exist.

## 7. Error Contract

Use accepted centralized errors.

```text
401 authentication_required
403 user_inactive
403 institution_inactive
403 forbidden
```

Wrong role uses:

```text
403 forbidden
errors = {}
```

No new stable role error code.

## 8. Relevant Files

Expected high-value change surface:

| Path | Expected action |
|---|---|
| `backend/app/Http/Middleware/EnsureUserHasRole.php` or equivalent | Create |
| `backend/bootstrap/app.php` or accepted middleware registration location | Register `role` alias |
| `backend/app/Enums/UserRole.php` | Reuse; minimal helper only if justified |
| `backend/app/Models/User.php` | Minimal change only if required |
| `backend/tests/Feature/Authorization/*` | Create role matrix/order tests |
| test-only route support | Create only for test environment |
| `tasks/backend/stage-01/S01-BE-005-role-authorization-foundation.md` | Preserve |
| `tasks/backend/stage-01/S01-BE-005-CODEX-PROMPT.md` | Preserve |
| `tasks/STAGE_01_TASK_INDEX.md` | Lifecycle update only |

Do not modify:

- `docs/01–09`;
- `frontend/`;
- `docker/`;
- DB migrations/schema;
- auth endpoint contracts;
- Composer dependencies.

If those changes become necessary, stop and report.

## 9. Authoritative Specification References

| Document | Section | Requirement |
|---|---|---|
| `docs/06-roadmap.md` | `6. Stage 1 — Authentication and Role-Based Entry` | Unauthorized protected access must be blocked |
| `docs/07-architecture.md` | `8.2 Institution Context` | Institution context comes from authenticated account |
| `docs/07-architecture.md` | `8.3 Platform-Level Super Admin` | No automatic unscoped institution access |
| `docs/07-architecture.md` | `8.4 Query Scoping` | Direct IDs cannot bypass future tenant scope |
| `docs/07-architecture.md` | `9.1 MVP Roles` | Exact five primary roles |
| `docs/07-architecture.md` | `9.2 One Primary Role Per MVP Account` | No custom/multiple roles |
| `docs/07-architecture.md` | `9.4 Authorization Layers` | Layer 3 = Role Capability |
| `docs/09-api-contracts.md` | `2.6 Authorization Error` | `403 forbidden` |
| `docs/09-api-contracts.md` | `5.1 Stable Error Codes` | No invented role-specific codes |
| `docs/09-api-contracts.md` | `33.1 Server Scope Order` | Security/authorization order |
| `backend/AGENTS.md` | Authorization/security/testing sections | Backend enforcement |
| `tasks/STAGE_01_TASK_INDEX.md` | `S01-BE-005` | Reusable role foundation + cross-role denial |

## 10. Functional Requirements

1. `S01-BE-004` verified `Accepted`.
2. Work occurs on `task/s01-be-005-role-authorization`.
3. One reusable role middleware exists.
4. It uses canonical `UserRole`.
5. It supports one allowed role.
6. It supports multiple allowed roles.
7. Correct persisted role succeeds.
8. Wrong persisted role returns `403 forbidden`.
9. Platform Owner is not universal bypass.
10. Client-supplied role cannot alter authorization.
11. Invalid server role configuration fails closed.
12. Alias is registered cleanly.
13. Middleware composes after auth/status/password gates.
14. Unauthenticated remains `401 authentication_required`.
15. Inactive user remains `403 user_inactive`.
16. Inactive institution remains `403 institution_inactive`.
17. `must_change_password=true` is denied before role capability.
18. Correct-role active/password-complete request succeeds.
19. Multi-role test surface allows exactly configured roles.
20. Test surfaces absent from production routes.
21. No product endpoint added.
22. No RBAC package added.
23. No permission/migration/seeder added.
24. No speculative resource Policy/query scope added.
25. Full backend tests pass on PostgreSQL.
26. Pint passes.
27. Composer validation passes.
28. Locked docs/frontend/docker/schema/auth contracts unchanged.

## 11. Required Automated Tests

### 11.1 Full five-role matrix

Test five single-role surfaces.

Rows and columns:

```text
platform_owner
institution_admin
teacher
student
parent
```

Expected:

```text
5 matching-role successes
20 cross-role 403 forbidden denials
```

Do not reduce this to a few spot checks.

### 11.2 Multi-role surface

For a surface allowing:

```text
teacher
student
```

prove:

- teacher succeeds;
- student succeeds;
- platform_owner denied;
- institution_admin denied;
- parent denied.

### 11.3 Security-order matrix

Prove:

```text
no token
→ 401 authentication_required

inactive correct-role user
→ 403 user_inactive

active correct-role user in inactive institution
→ 403 institution_inactive

active correct-role + must_change_password=true
→ 403 forbidden before role layer

active password-complete wrong role
→ 403 forbidden from role layer

active password-complete correct role
→ success
```

### 11.4 Authority spoofing

For persisted Student, attempt request/header/query data claiming another role.

Authorization must remain Student-only.

### 11.5 Platform Owner explicitness

Prove Platform Owner:

- succeeds only on Platform Owner surface;
- fails the other four single-role surfaces;
- fails Teacher+Student multi-role surface.

### 11.6 Invalid configuration

Register an invalid test-only role value.

Prove fail-closed behavior.

Do not map invalid configuration to a real role.

### 11.7 Production route hygiene

Prove no test authorization route is registered in production route list.

### 11.8 Regression

All accepted prior backend tests remain green:

- API foundation;
- PostgreSQL persistence;
- login/logout/me;
- active-state enforcement;
- rate limiting;
- password change;
- mandatory password gate;
- Sanctum behavior.

## 12. Quality / Scope Verification

Run accepted equivalents:

```text
php artisan route:list
php artisan test
vendor/bin/pint --test
composer validate --strict
```

Before acceptance gate:

```text
git status --short
git diff --check
git diff main...HEAD -- docs
git diff main...HEAD -- frontend
git diff main...HEAD -- docker
git diff main...HEAD -- backend/database/migrations
git diff main...HEAD -- backend/composer.json backend/composer.lock
```

Expected:

- no docs/frontend/docker/migration/dependency change.

Inspect changed content for secrets, tokens, `.env`, hard-coded bypasses, and
hard-coded production user/institution identifiers.

## 13. Manual Smoke

Using controlled local/test users:

1. Authenticate each of five roles.
2. Exercise role middleware through test-only harness.
3. Confirm all 5 correct-role successes.
4. Confirm all 20 cross-role denials.
5. Confirm Teacher+Student surface allows only those two.
6. Confirm Platform Owner is not universal bypass.
7. Confirm auth/status/password gates still precede role check.
8. Confirm production routes contain no test authorization surface.

## 14. Explicit Non-Goals

- Tenant resource ownership Policies.
- Tenant query scopes.
- Group/Topic/Homework/Blitz/Submission/Result authorization.
- Relationship authorization.
- Lifecycle/business authorization.
- Permission tables.
- Custom/multiple roles.
- Spatie Permission.
- Role assignment API.
- Institution/User management API.
- Platform administration product endpoints.
- Teacher/Student/Parent product endpoints.
- Flutter.
- DB schema changes.
- Docker changes.
- CI changes.
- New role-specific error codes.

## 15. Stop Conditions

Stop and report if:

- `S01-BE-004` is not `Accepted`;
- accepted auth/password gate is absent from `origin/main`;
- canonical `UserRole` is missing/broken;
- local `main` cannot synchronize with `origin/main`;
- unrelated dirty state exists;
- task branch cannot be created safely;
- locked architecture defines a different role model;
- correct work requires resource/tenant/relationship scope not yet present;
- implementation appears to require RBAC package or migration;
- correct work requires Stage 2+ endpoints;
- secret/credential exposure would be required;
- safe completion requires force-push/history rewrite/check bypass;
- material scope expansion is required.

## 16. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git Preflight

Create/switch to:

`task/s01-be-005-role-authorization`

Ensure approved task/prompt are on task branch.

Do not commit/push.

### Phase 1 — Implementation

Implement only this task.

Run:

- five-role matrix;
- multi-role tests;
- middleware-order tests;
- spoofing tests;
- Platform Owner explicitness;
- invalid config fail-closed test;
- production-route hygiene;
- full backend regression suite;
- Pint;
- Composer validation;
- scope/security checks.

Do not commit/push.

### Phase 2 — Read-Only Acceptance Gate

Re-read task, applicable locked docs, AGENTS, complete diff, routes, tests.

No edits, auto-fixes, staging, commit, push, or merge.

Findings:

- `P1` blocking authorization/security;
- `P2` material architecture/test/scope mismatch;
- `P3` non-blocking observation.

If P1/P2 remains:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop. Do not self-fix after Phase 2 begins.

### Phase 3 — Post-Acceptance Git Delivery

Only after Phase 2 PASS:

1. Set this task `Accepted`.
2. Update Stage 1 index:
   - Task = `Accepted`;
   - Review = `PASS`;
   - Delivery finalized after merge.
3. Re-run final diff/security/route checks.
4. Stage only approved changes.
5. Commit:

```text
feat(authz): add role authorization foundation
```

Body:

```text
Task: S01-BE-005
```

6. Push task branch.
7. Create PR to `main`.
8. Do not bypass checks/protection.
9. Merge only when safe/checks pass.
10. Sync local `main` from `origin/main`.
11. Verify local `main == origin/main` and clean tree.

If delivery fails after review PASS:

```text
FINAL STATUS: DELIVERY BLOCKED
```

If all succeeds:

```text
FINAL STATUS: ACCEPTED
```

Do not start `S01-FE-001`.

## 17. Required Codex Final Report

Return:

1. Final status: `ACCEPTED`, `NOT ACCEPTED`, or `DELIVERY BLOCKED`.
2. Dependency/Git preflight.
3. Implementation summary.
4. Changed files.
5. Role middleware/alias/canonical role evidence.
6. Five-role matrix: 5 allow / 20 deny.
7. Multi-role evidence.
8. Middleware-order evidence.
9. Spoofing/Platform Owner explicitness evidence.
10. Production route hygiene.
11. Acceptance findings.
12. Acceptance criteria PASS/FAIL.
13. Tests/quality exact commands/results.
14. Security/scope evidence.
15. GitHub delivery evidence.
16. Manual smoke.
17. Remaining blockers/deviations.

Do not start `S01-FE-001`.
