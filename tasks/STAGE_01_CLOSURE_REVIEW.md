# Stage 1 Closure Review — Authentication and Role-Based Entry

## 1. Closure Metadata

| Field | Value |
|---|---|
| Review ID | `STAGE-01-CLOSURE` |
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Review contract status | `Approved` |
| Review mode | `Read-only stage-wide audit → post-PASS closure bookkeeping/delivery` |
| Stage index | `tasks/STAGE_01_TASK_INDEX.md` |
| Required final task | `S01-INT-004 — Stage 1 End-to-End Authentication Verification (Accepted)` |
| Proposed verdict | `Stage closed` |

This review begins only after every approved Stage 1 task is `Accepted` and its
accepted result is present on `origin/main`.

This file defines the closure audit. It does not itself mean Stage 1 is closed.

## 2. Purpose

Determine, from current repository evidence, whether Stage 1 is genuinely
complete and may become a stable dependency for Stage 2.

The review must verify the stage as one integrated system:

```text
PostgreSQL
↕
Laravel
↕
Sanctum
↕
Dio
↕
Riverpod session state
↕
GoRouter
↕
Flutter Windows / Android entry UX
```

Individual task PASS results are evidence, not substitutes for this stage-wide
audit.

The review must independently detect:

- missing roadmap acceptance criteria;
- cross-task contract mismatches;
- a task contract that conflicts with locked `docs/01–09`;
- backend/frontend disagreement;
- missing negative/security coverage;
- stale task/index/documentation status;
- accepted implementation not delivered to `origin/main`;
- hidden Stage 2+ scope;
- regressions introduced after an earlier task review.

## 3. Authoritative Inputs

Codex must read/inspect:

- root `AGENTS.md`;
- `backend/AGENTS.md`;
- `frontend/AGENTS.md`;
- locked `docs/01–09` sections governing Stage 1;
- `docs/FINAL_AUDIT_REPORT.md`;
- `tasks/README.md`;
- `tasks/STAGE_00_CLOSURE_REVIEW.md`;
- `tasks/STAGE_01_TASK_INDEX.md`;
- every Stage 1 task contract;
- current accepted code/config/migrations/tests;
- every task status/review/delivery record available in repository evidence;
- `S01-INT-004-stage-01-e2e-evidence.md`;
- current Git history, branches/remotes/status;
- current backend/frontend automated test evidence;
- current Windows/Android E2E evidence.

Locked `docs/01–09` outrank task files.

If an accepted task conflicts with locked specification, that is a closure
finding even if the task's individual review previously passed.

## 4. Stage 1 Task Inventory

All of these must be `Accepted` and delivered to `origin/main`:

```text
S01-INT-001 — Project Repository Foundation
S01-INT-002 — GitHub Remote, Repository Baseline & Stage 1 Control
S01-BE-001  — Laravel API Scaffold & Backend Quality Foundation
S01-INT-003 — Local Backend Runtime & PostgreSQL Foundation
S01-BE-002  — Identity Persistence Foundation
S01-BE-003  — Sanctum Authentication & Session API
S01-BE-004  — Mandatory First-Login Password Change Gate
S01-BE-005  — Role Authorization Foundation
S01-FE-001  — Flutter Client Scaffold & Core Infrastructure
S01-FE-002  — Authentication Data & Session Foundation
S01-FE-003  — Login & First-Login Password Change UX
S01-FE-004  — Role/Device Entry Routing & Session Isolation
S01-INT-004 — Stage 1 End-to-End Authentication Verification
```

The review must confirm no unapproved implementation task was silently inserted
into Stage 1 and no approved task was skipped.

## 5. Entry / Git Preflight

Before reviewing:

1. verify local repository root is exactly:
   `G:\project\testlabuz`;
2. verify approved `origin` is exactly:
   `https://github.com/Shoxrux2017/testlabuz.git`;
3. fetch remote safely;
4. verify local `main == origin/main`;
5. verify `main` is clean except, if the project owner pre-saved this approved
   closure-review file and matching Codex prompt, those exact two files may be
   the only permitted preparation additions;
6. verify all Stage 1 task/index statuses;
7. verify `S01-INT-004` is `Accepted`;
8. verify no task remains `Approved`, `In Progress`, `NOT ACCEPTED`,
   `DELIVERY BLOCKED`, `Fix Required`, or equivalent unresolved state;
9. verify accepted task results are present in the history of `origin/main`.

Required closure-review branch:

`review/stage-01-closure`

If the two closure preparation files are present on local `main`, do not commit
them on `main`; create the review branch immediately and carry them into it.

During the read-only audit, do not modify application code, tests, configs,
migrations, task contracts, or locked docs.

## 6. Exact Roadmap Acceptance-Criteria Matrix

These criteria come from `docs/06-roadmap.md`,
`Stage 1 — Authentication and Role-Based Entry`.

Every item must be `PASS`.

| Exact Stage 1 acceptance criterion | Required evidence |
|---|---|
| All five roles can authenticate through their approved device surface. | Backend auth tests + Windows/Android real E2E |
| Each role reaches the correct entry area. | FE route/device matrix + real Windows/Android E2E |
| Inactive users are blocked. | Backend negative tests + real E2E |
| Users in inactive institutions are blocked. | Backend negative tests + real E2E |
| Unauthorized protected pages and endpoints are blocked. | Backend role matrix + Flutter direct-route tests + E2E/regression evidence |
| Previous auth/session state cannot expose another user’s data. | FE race/account-switch tests + same-role/cross-role real E2E |

Missing or only partially verified criteria block closure.

## 7. Required Stage 1 Backend / API Contract Audit

Verify current implementation against locked contracts, not merely against
task wording.

### 7.1 Authentication routes

Production API must include the approved Stage 1 auth contract:

```text
POST /api/v1/auth/login
POST /api/v1/auth/logout
GET  /api/v1/auth/me
POST /api/v1/auth/change-password
```

No unapproved Stage 1 auth endpoint is required.

### 7.2 Login

Verify:

- public request field is `login`;
- `login` maps to `users.login_name`;
- client cannot choose role;
- client cannot choose institution;
- role/institution come from persisted account data;
- all five valid roles can authenticate;
- invalid credentials are generic;
- token is Sanctum Bearer token;
- token/password are never logged.

### 7.3 Current user / session

Verify `/auth/me` is the Flutter bootstrap authority for:

- authentication validity;
- current role;
- institution;
- account status;
- institution status;
- correct application shell.

Flutter must not persist role as independent long-term authority.

### 7.4 Active-state enforcement

Verify both at login and for already-issued sessions where applicable:

```text
user inactive
→ 403 user_inactive

institution inactive
→ 403 institution_inactive
```

### 7.5 Mandatory first-login password change

This is a **critical locked contract**.

Administrator-created:

```text
institution_admin
teacher
student
parent
```

must use:

```text
must_change_password = true
```

Until successful password change, Laravel allows only:

```text
GET  /api/v1/auth/me
POST /api/v1/auth/change-password
POST /api/v1/auth/logout
```

Normal protected application endpoints must return:

```text
HTTP 403
code = password_change_required
```

The stable code `password_change_required` is explicitly present in
`docs/09-api-contracts.md`.

A Stage 1 implementation that uses only generic `forbidden` for this locked
first-login gate does **not** satisfy the current authoritative API contract.

Successful change must:

- require `current_password`;
- accept `new_password`;
- require confirmation;
- return `204`;
- return `409 current_password_invalid` when current password is wrong;
- atomically persist new hash and clear `must_change_password`.

### 7.6 Logout

Verify:

- current token is revoked;
- success is `204 No Content`;
- revoked token no longer has normal protected access;
- local Flutter session is cleared.

### 7.7 Stable API errors

At minimum Stage 1 must preserve the locked machine codes relevant to this
stage:

```text
authentication_required
invalid_credentials
user_inactive
institution_inactive
forbidden
resource_not_found
password_change_required
validation_failed
rate_limited
server_error
current_password_invalid
```

`current_password_invalid` is the endpoint-specific change-password code from
the locked authentication contract.

Flutter must not parse human-readable messages as control flow.

## 8. Identity / Database Audit

Verify accepted PostgreSQL schema and models against `docs/08-database.md`.

At minimum:

- UUID `institutions`;
- UUID `users`;
- exact five role values;
- one primary role;
- only Platform Owner may have `institution_id = null`;
- every institution role has institution;
- globally unique `login_name`;
- phone is not incorrectly globally unique;
- no unapproved email uniqueness;
- active/inactive institution state;
- `must_change_password`;
- `last_login_at`;
- Sanctum token owner compatible with UUID user;
- `institution_settings`;
- timezone available to `/auth/me`;
- historical-safety FK behavior from the approved Stage 1 subset;
- PostgreSQL testing database remains isolated from development DB.

No Stage 2+ schema should have been introduced merely for Stage 1.

## 9. Authorization Audit

Verify backend authorization layers implemented in Stage 1 are correctly
separated:

```text
Authentication
→ User active
→ Institution active
→ First-login password gate
→ Role capability
```

Verify:

- canonical five-role role middleware/primitive;
- current persisted role is authority;
- client-supplied role cannot elevate;
- Platform Owner is not a universal role bypass;
- wrong role returns `403 forbidden`;
- complete accepted backend role matrix remains green:
  `5 allowed + 20 cross-role denied`;
- no speculative permission/RBAC package/tables;
- no fake Stage 2 production resource endpoint created for authorization tests.

Institution ownership / relationship scope for product resources is not yet a
Stage 1 product-resource implementation requirement because those resources
belong to later stages.

Mark such product-resource tenant tests `N/A for Stage 1` only with this
explicit stage-boundary reason.

## 10. Flutter Session / Security Audit

Verify:

- secure token storage;
- token only is long-term auth persistence;
- no password persistence;
- no role/institution/profile persisted as long-term authority;
- Bearer token added only to authenticated requests;
- public login does not receive stale Bearer token;
- `401 authentication_required` invalidates local session;
- public `invalid_credentials` does not incorrectly invalidate another active
  session;
- logout clears local token/user even if backend logout transport fails;
- `/auth/me` reconstructs current session after restart;
- bootstrap transport failure does not fabricate authenticated state;
- stale async result protection exists;
- old user cannot overwrite a newer user/session.

## 11. Flutter Authentication UX Audit

Verify:

```text
/login
/change-password
```

and:

- no role selector;
- no institution selector;
- login uses public `login`;
- server errors handled by typed code/status;
- no password/token leakage;
- `must_change_password` comes from server session;
- first-login user is forced to change-password UX;
- successful password mutation is followed by authoritative `/auth/me`
  refresh;
- client does not locally clear first-login state without server refresh.

## 12. Role / Device Routing Audit

Exact MVP device boundary:

```text
Platform Owner / Super Admin → desktop only
Institution Admin            → desktop only
Teacher                      → desktop + mobile
Student                      → desktop + mobile
Parent                       → mobile only
```

For canonical Stage 1 targets verify:

### Windows / desktop

```text
platform_owner    → Platform Owner entry
institution_admin → Institution Admin entry
teacher           → Teacher desktop entry
student           → Student desktop entry
parent            → unsupported-device
```

### Android / mobile

```text
platform_owner    → unsupported-device
institution_admin → unsupported-device
teacher           → Teacher mobile entry
student           → Student mobile entry
parent            → Parent mobile entry
```

Verify:

- device surface is not inferred from viewport width;
- direct wrong-role routes never render wrong shell;
- unsupported-device combinations cannot access another shell;
- Platform Owner is not a client-side universal bypass;
- first-login password gate precedes role/device resolution;
- minimal Stage 1 shells contain no Stage 2+ product feature.

## 13. Session Isolation / Account Switch Audit

Must pass:

### Same role

```text
Teacher A
→ logout
→ Teacher B
→ only B identity/session visible
```

### Cross role

```text
Teacher
→ logout
→ Student
→ Student entry
→ no Teacher identity/shell
```

### Stale async

Old bootstrap/login `/auth/me` response must not restore a superseded user or
route after logout/new login.

### Invalidated session

```text
authentication_required
→ local session cleared
→ /login
→ old shell removed
```

Any previous-user data exposure is a P1 closure blocker.

## 14. Stage 1 E2E Evidence Audit

Inspect:

```text
tasks/integration/stage-01/
S01-INT-004-stage-01-e2e-evidence.md
```

The evidence must be sanitized and must show PASS for:

### Five-role authentication

```text
platform_owner
institution_admin
teacher
student
parent
```

### Windows

```text
Platform Owner entry
Institution Admin entry
Teacher desktop entry
Student desktop entry
Parent unsupported
```

### Android

```text
Platform Owner unsupported
Institution Admin unsupported
Teacher mobile entry
Student mobile entry
Parent mobile entry
```

### Security / negative flows

```text
invalid credentials
inactive user
inactive institution
mandatory first-login password change
wrong current password
old password invalid after successful change
new password valid after successful change
logout
revoked token
wrong-role direct route
unsupported role/device
same-role account switch
cross-role account switch
```

Verify E2E actually used:

- real Flutter app;
- real Laravel API;
- real Sanctum;
- real PostgreSQL `testlabuz_testing`;
- Windows target;
- Android emulator/device.

Mock-only E2E evidence cannot close Stage 1.

## 15. Stage Definition of Done

Use exact `docs/06-roadmap.md` section `3.2 Stage Definition of Done`.

Evaluate each:

| Definition-of-Done condition | Closure requirement |
|---|---|
| Approved business behavior is implemented | PASS |
| Required backend/API behavior works | PASS |
| Required desktop/mobile UI is connected to real data | PASS |
| No placeholder flow remains for the stage core path | PASS |
| Required permissions are enforced server-side | PASS |
| Multi-institution scope is enforced where applicable | PASS / explicit Stage 1 N/A only for future product-resource scope |
| Validation and error behavior are defined | PASS |
| Automated tests pass | PASS |
| Static analysis/lint/format checks pass | PASS |
| Required manual smoke tests pass | PASS |
| No blocking regression in previous stages | PASS |
| Relevant project documentation is updated | PASS |
| Review finds no unresolved blocker | PASS |
| Stage explicitly marked closed before Stage 2 | Done only after audit PASS + closure delivery |

## 16. Required Current Quality Gates

Do not rely solely on old task reports. Run current regression on the exact
closure candidate.

### Backend

Using accepted PostgreSQL testing runtime:

```text
php artisan test
vendor/bin/pint --test
composer validate --strict
```

Run any additional mandatory backend quality command currently established in
the repository.

### Frontend

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test integration_test
flutter build windows --debug
flutter build apk --debug
```

### Integration

Re-run the Stage 1 E2E suite on:

- Windows;
- Android emulator/device.

If a full E2E rerun is impossible because an external environment/tool target
is unavailable, closure is not automatically granted from stale evidence.
Report `Closure blocked by dependency/environment` unless the current
repository's approved closure policy explicitly permits a still-valid recent
artifact instead.

## 17. Repository / GitHub Audit

Verify:

- every accepted Stage 1 task result is reachable from `origin/main`;
- no accepted task remains only on an unmerged task branch;
- no `DELIVERY BLOCKED` task remains;
- no unreviewed code exists outside `origin/main`;
- local `main == origin/main`;
- no unexpected remote;
- no force-push/history-rewrite evidence required Stage 1 recovery without an
  approved recovery record;
- working tree is clean aside from the two closure-review preparation files
  before closure branch creation;
- locked `docs/01–09` were not modified by Stage 1 implementation;
- current Stage 1 index matches actual task statuses.

## 18. Scope / Regression Audit

Verify Stage 1 did **not** silently implement Stage 2+ product functionality.

Stage 1 may contain only minimal role entry shells.

Block closure for material premature product scope such as:

- institution management CRUD/dashboard;
- user management CRUD;
- groups/relationships;
- Topics;
- Materials;
- Homework;
- Blitz;
- submissions/results/reports;
- real role dashboards/KPIs;
- advanced session/device management;
- MFA/SSO.

Framework/test support needed to verify Stage 1 is not itself scope creep.

## 19. Documentation / Bookkeeping Audit

Before closure PASS, verify:

- `tasks/README.md` Stage 1 status is current;
- `tasks/STAGE_01_TASK_INDEX.md` lists all 13 tasks;
- all 13 task statuses are `Accepted`;
- all review statuses are PASS;
- all delivery statuses indicate accepted result on `origin/main`;
- `S01-INT-004` evidence exists;
- no stale statement says Stage 1 is Planned/not decomposed;
- closure record is the only remaining Stage 1 status action.

Locked `docs/01–09` must not be edited merely to record implementation status.

## 20. Findings Severity

Use:

- `P1` — security, authentication, authorization, data/session leakage,
  locked-contract violation, wrong device/role access, failed acceptance
  criterion, or broken real E2E; blocks closure.
- `P2` — material architecture, API, DB, test, GitHub delivery, documentation,
  or scope mismatch; blocks closure.
- `P3` — non-blocking observation/risk that does not invalidate Stage 1.

Any P1/P2 means:

```text
VERDICT: FIXES REQUIRED BEFORE CLOSURE
```

Do not fix findings during the read-only audit.

## 21. Read-Only Review Phase

During the audit phase Codex must not:

- edit code;
- edit tests;
- edit config;
- edit migrations;
- edit task contracts;
- edit task statuses;
- edit Stage 1 index;
- edit `tasks/README.md`;
- edit closure file verdict;
- commit;
- push;
- merge.

The audit must be independent of previous task self-reports.

## 22. Final Review Verdicts

Choose exactly one before closure delivery:

```text
AUDIT PASS — Stage 1 is ready for closure.
```

or:

```text
FIXES REQUIRED BEFORE CLOSURE
```

or:

```text
CLOSURE BLOCKED BY SPECIFICATION OR DEPENDENCY
```

If not `AUDIT PASS`, stop with no closure modifications.

## 23. Post-PASS Closure Bookkeeping

Only if the read-only audit returns `AUDIT PASS`:

1. update this closure review with:
   - actual review date;
   - complete evidence summary;
   - acceptance matrix results;
   - Definition-of-Done results;
   - findings;
   - final verdict `Stage closed`;
2. update `tasks/STAGE_01_TASK_INDEX.md`:
   - Stage status → `Closed`;
   - Stage closed → `Yes`;
   - closure-readiness checklist → complete based on evidence;
3. update `tasks/README.md` Stage Status:
   - Stage 1 → `Closed`;
   - next gate → Stage 2 decomposition/planning;
4. do not modify locked `docs/01–09`;
5. do not start Stage 2 implementation.

No application code should need modification after an audit PASS.

If application code would need modification, the audit did not truly pass.

## 24. Closure GitHub Delivery

After PASS bookkeeping only:

1. re-run:
   - `git diff --check`;
   - closure-bookkeeping scope review;
   - secret scan;
2. verify no application code changed during closure bookkeeping;
3. stage only:
   - this closure review;
   - Stage 1 index bookkeeping;
   - `tasks/README.md` Stage status;
   - matching closure prompt if repository policy tracks prompts;
4. create one focused closure commit.

Preferred subject:

```text
docs(stage1): close authentication and role entry
```

Body:

```text
Review: STAGE-01-CLOSURE
```

5. push `review/stage-01-closure`;
6. open PR to `main`;
7. do not bypass branch protection/checks;
8. merge only when safe and required checks pass;
9. synchronize local `main` with `origin/main`;
10. verify:
    - local `main == origin/main`;
    - clean working tree;
    - Stage 1 closure record exists on `origin/main`.

If audit passed but safe delivery fails:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Stage 1 remains **not formally Closed** until closure bookkeeping is present on
`origin/main`.

## 25. Final Closure States

Final result must be exactly one of:

```text
FINAL STATUS: STAGE CLOSED
```

```text
FINAL STATUS: FIXES REQUIRED BEFORE CLOSURE
```

```text
FINAL STATUS: CLOSURE BLOCKED
```

```text
FINAL STATUS: DELIVERY BLOCKED
```

`STAGE CLOSED` is valid only when:

- read-only audit passed;
- closure bookkeeping completed;
- closure commit merged to `origin/main`;
- local `main == origin/main`;
- working tree clean.

## 26. Next Gate

If final status is:

```text
STAGE CLOSED
```

then Stage 2 becomes eligible for **decomposition/planning only**:

```text
Stage 2 — Multi-Institution Platform Management
```

Do not start Stage 2 implementation automatically.

If any other final status occurs, Stage 2 remains blocked.

## 27. Required Codex Closure Report

Return:

1. **Final status** — exactly one:
   - `STAGE CLOSED`
   - `FIXES REQUIRED BEFORE CLOSURE`
   - `CLOSURE BLOCKED`
   - `DELIVERY BLOCKED`
2. **Preflight**:
   - repository;
   - branch;
   - local/origin main hashes;
   - all 13 task statuses;
   - `S01-INT-004` evidence presence.
3. **Findings**, ordered P1 → P2 → P3.
4. **Exact Stage 1 roadmap acceptance matrix** — PASS/FAIL each.
5. **Stage Definition-of-Done matrix** — PASS/FAIL/N/A with reasons.
6. **Backend/API contract audit**.
7. **Mandatory first-login contract evidence**, including exact
   `403 password_change_required`.
8. **Identity/PostgreSQL audit**.
9. **Backend role authorization audit**, including `5 allow / 20 deny`.
10. **Flutter session/security audit**.
11. **Login/password-change UX audit**.
12. **Role/device matrix**:
    - Windows all five;
    - Android all five.
13. **Session-isolation audit**.
14. **Current backend quality-gate results**.
15. **Current frontend quality/build results**.
16. **Current Windows/Android E2E results**.
17. **Manual smoke evidence**.
18. **Scope/regression audit**.
19. **GitHub delivery/task-history audit**.
20. **Documentation/bookkeeping audit**.
21. If audit PASS:
    - closure files changed;
    - closure commit hash/subject;
    - PR reference;
    - merge result;
    - final local/main hashes;
    - final clean status.
22. **Next gate**.
23. Explicit confirmation:
    - `Stage 2 implementation was NOT started.`

Do not fix implementation findings inside this closure review.

---

## 28. Completed Review Record

| Field | Result |
|---|---|
| Actual review date | `2026-08-10` |
| Review branch | `review/stage-01-closure` |
| Audit verdict | `AUDIT PASS - Stage 1 is ready for closure` |
| Closure verdict | `Stage closed` |
| Base hash audited | `f8193f67aaf908e430516548b4696551753fb694` |
| Scope | Closure review, Stage 1 index, and task README bookkeeping only |

### 28.1 Evidence Summary

- Root, backend, and frontend `AGENTS.md` instructions were read.
- All Stage 1 task contracts/statuses were read from the approved task files and task index.
- Locked Stage 1 sections from `docs/01-09` were checked for roadmap acceptance, auth/session API, first-login gate, identity persistence, role/device boundaries, Flutter architecture, and testing/DoD requirements.
- All 13 Stage 1 tasks were `Accepted` with `PASS` review status; accepted production results were present in `origin/main` history.
- `S01-INT-004` evidence exists at `tasks/integration/stage-01/S01-INT-004-stage-01-e2e-evidence.md`.
- Local `main` and `origin/main` matched at `f8193f67aaf908e430516548b4696551753fb694` before the closure branch audit.

### 28.2 Roadmap Acceptance Matrix

| Exact Stage 1 acceptance criterion | Result | Current evidence |
|---|---|---|
| All five roles can authenticate through their approved device surface. | `PASS` | Backend auth tests plus current Windows and Android real-stack E2E |
| Each role reaches the correct entry area. | `PASS` | Flutter route/device matrix tests plus current Windows and Android real-stack E2E |
| Inactive users are blocked. | `PASS` | Backend negative tests plus current E2E |
| Users in inactive institutions are blocked. | `PASS` | Backend negative tests plus current E2E |
| Unauthorized protected pages and endpoints are blocked. | `PASS` | Backend first-login/role middleware tests, Flutter direct-route tests, and E2E |
| Previous auth/session state cannot expose another user's data. | `PASS` | Frontend race/account-switch tests and E2E Teacher A -> Teacher B / Teacher -> Student flows |

### 28.3 Stage Definition of Done

| `docs/06-roadmap.md` section 3.2 item | Result | Reason |
|---|---|---|
| Stage goal is implemented. | `PASS` | Stage 1 auth/session/entry goal is covered by accepted tasks and E2E. |
| Required backend/API/database work is complete. | `PASS` | Laravel `/api/v1` auth contract, Sanctum tokens, identity schema, active gates, first-login gate, and role middleware are present. |
| Required frontend work is complete. | `PASS` | Flutter auth repository/session state, login/change-password UX, role/device routing, and minimal entry shells are present. |
| Locked contracts are followed. | `PASS` | No Stage 1 conflict with locked docs was found. |
| Multi-institution scope is enforced where applicable. | `PASS` | Institution users require an active institution; product-resource tenant tests are N/A for Stage 1 because later product resources are not implemented. |
| Authorization/security negative cases pass. | `PASS` | Inactive account/institution, first-login, role, direct-route, and session-isolation negative paths are covered. |
| Required automated tests/checks pass. | `PASS` | Backend, frontend, formatting, static analysis, build, and E2E checks passed in the current audit. |
| Required smoke evidence exists. | `PASS` | Manual smoke evidence is recorded in the accepted Stage 1 evidence file. |
| Stage documentation/bookkeeping is current. | `PASS` | This closure commit updates the remaining Stage 1 status records. |
| No blocking regression remains. | `PASS` | No P1/P2 finding remains after current audit. |

### 28.4 Contract Audit Results

- Backend auth routes match the locked Stage 1 API contract:
  `POST /api/v1/auth/login`, `POST /api/v1/auth/logout`,
  `GET /api/v1/auth/me`, and `POST /api/v1/auth/change-password`.
- Login uses `login`, maps it to `users.login_name`, does not accept client role or institution authority, and returns Sanctum bearer tokens.
- `/auth/me` remains the Flutter bootstrap authority for current user, role, institution, account state, and required password-change state.
- Inactive users return `403 user_inactive`; inactive-institution users return `403 institution_inactive`.
- Mandatory first-login gate is backend-enforced. While `must_change_password = true`, only `/auth/me`, `/auth/change-password`, and `/auth/logout` are allowed; normal protected endpoints return `403 password_change_required`.
- The stable machine code `password_change_required` is implemented directly; the first-login gate is not generic-only `403 forbidden`.
- Identity persistence uses the approved five role values, institution/user UUIDs, Sanctum token persistence, platform-owner null-institution allowance only, and controlled institution settings defaults.
- Backend role authorization foundation passed the required `5 allowed / 20 cross-role denied` coverage with no Platform Owner universal bypass.
- Flutter uses `/auth/me` rather than cached role as long-term authority, clears token/session state on logout and invalid session, and guards stale async restoration.
- Login and first-login UX handle invalid credentials, inactive states, current-password validation, and successful password change with session refresh.

### 28.5 Role/Device Matrix

| Role | Windows result | Android result |
|---|---|---|
| `platform_owner` | Platform Owner entry | Unsupported device |
| `institution_admin` | Institution Admin entry | Unsupported device |
| `teacher` | Teacher desktop entry | Teacher mobile entry |
| `student` | Student desktop entry | Student mobile entry |
| `parent` | Unsupported device | Parent mobile entry |

### 28.6 Current Quality Gates

Backend checks were run inside the accepted Docker Laravel/PostgreSQL runtime because the host PHP installation lacks `pdo_pgsql`.

| Check | Result |
|---|---|
| `php artisan test` | `PASS` - 68 tests, 1412 assertions |
| `vendor/bin/pint --test` | `PASS` |
| `composer validate --strict` | `PASS` |
| `flutter pub get` | `PASS` using Flutter `3.44.7` / Dart `3.12.2` |
| `flutter analyze` | `PASS` |
| `flutter test` | `PASS` - 135 tests |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | `PASS` |
| `flutter build windows --debug` | `PASS` |
| `flutter build apk --debug` | `PASS` |
| Windows Stage 1 E2E | `PASS` against real Laravel/PostgreSQL testing stack |
| Android Stage 1 E2E | `PASS` against real Laravel/PostgreSQL testing stack |

### 28.7 Manual Smoke Evidence

Manual smoke evidence is recorded in
`tasks/integration/stage-01/S01-INT-004-stage-01-e2e-evidence.md` and was treated as supporting evidence only; closure relied on the current automated regression and E2E rerun.

### 28.8 Findings

| Severity | Finding | Closure impact |
|---|---|---|
| `P3` | A bare unauthenticated request to `/api/v1/auth/me` without `Accept: application/json` returns a Laravel redirect-route 500 instead of the JSON `401 authentication_required` envelope. The locked API default requires `Accept: application/json`, and all current backend/Flutter/E2E API paths use that header, so this did not invalidate Stage 1 closure. | Non-blocking hardening follow-up |

No P1 or P2 findings were found.

### 28.9 Scope, Git, and Documentation

- No Stage 2 implementation was found or started.
- No application code, tests, migrations, config, or locked `docs/01-09` files were modified during closure bookkeeping.
- Closure bookkeeping updates are limited to this file, `tasks/STAGE_01_TASK_INDEX.md`, and `tasks/README.md`.
- Stage 2 is eligible for decomposition/planning only after this closure record is delivered to `origin/main`.
