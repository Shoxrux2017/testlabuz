# Codex Task: Role/Device Entry Routing & Session Isolation

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S01-FE-004` |
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Area | `Frontend / navigation and entry boundaries` |
| Status | `Approved` |
| Depends on | `S01-FE-003 — Login & First-Login Password Change UX (Accepted)`; `S01-BE-005 — Role Authorization Foundation (Accepted)` |
| Blocks | `S01-INT-004 — Stage 1 End-to-End Authentication Verification` |

This task is approved for Codex execution.

## 2. Goal

Complete the Stage 1 Flutter navigation boundary so every authenticated,
password-complete user reaches only the entry area approved for that user's
persisted role and current device surface.

The accepted result must provide:

- server-authoritative role-based route resolution;
- explicit desktop/mobile device-surface classification;
- direct-route blocking for wrong roles;
- unsupported-device blocking;
- minimal role entry shells only;
- removal/replacement of the temporary authenticated transition route;
- route/session behavior that cannot expose a previous user's role, identity,
  institution, or shell after logout/account switch;
- regression coverage for auth bootstrap, first-login gate, session
  invalidation, and stale async session results.

This task does not implement Stage 2+ product features.

## 3. Current Context

Repository:

`G:\project\testlabuz`

Approved GitHub remote:

`https://github.com/Shoxrux2017/testlabuz.git`

Required dependencies:

```text
S01-FE-003 = Accepted
S01-BE-005 = Accepted
```

Expected accepted Flutter foundation already provides:

- login and change-password UX;
- `/auth/me` server-authoritative session;
- `AuthUser.role`;
- `AuthUser.must_change_password`;
- secure token/session handling;
- logout/local cleanup;
- stale async result/account-switch protection;
- GoRouter;
- a temporary authenticated transition route.

Backend authorization remains the real security boundary. Flutter route guards
are an additional UX/access boundary only.

## 4. Approved Role / Device Matrix

Approved role/device model:

```text
Platform Owner / Super Admin → desktop
Institution Admin            → desktop
Teacher                      → desktop + mobile
Student                      → desktop + mobile
Parent                       → mobile
```

Canonical runtime surface mapping:

```text
Windows → desktop
macOS   → desktop
Linux   → desktop

Android → mobile
iOS     → mobile

Web     → unsupported for Stage 1
```

Do **not** infer device surface from viewport width.

A narrow Windows window is still desktop.
A large Android/iOS viewport is still mobile.

## 5. Git / Dependency Preflight

Before implementation:

1. Read root `AGENTS.md`.
2. Read `frontend/AGENTS.md`.
3. Read this complete approved task.
4. Read only the locked roadmap/architecture/API sections referenced below.
5. Verify both dependencies are `Accepted`.
6. Verify accepted results are present on `origin/main`.
7. Verify approved `origin`.
8. Fetch safely.
9. Verify local `main == origin/main`.
10. Verify no unrelated dirty state exists.
11. Verify accepted Flutter toolchain/build targets remain available.

Required task branch:

`task/s01-fe-004-role-device-routing`

If the project owner already saved this task and
`S01-FE-004-CODEX-PROMPT.md` under `tasks/frontend/stage-01/`, those exact
preparation files are permitted pre-task additions. Do not commit them on
`main`; create the task branch and carry them into it.

## 6. Device Surface Abstraction

Create one small injectable abstraction:

```text
AppDeviceSurface
  desktop
  mobile
  unsupported
```

Create a resolver/provider based on Flutter platform signals such as
`defaultTargetPlatform` and `kIsWeb`.

Tests must override the surface without relying on the host machine.

Do not put direct platform checks throughout widgets/router code.

## 7. Canonical Role Entry Routes

Production Stage 1 routes:

```text
/platform-owner
/institution-admin
/teacher
/student
/parent
/unsupported-device
```

Teacher and Student use one role route on desktop and mobile. Their minimal
entry shell may adapt its presentation to the current device surface.

Do not create duplicated route URLs such as `/teacher-mobile`.

## 8. Canonical Entry Resolver

Create one pure/testable resolver conceptually equivalent to:

```text
resolveEntryPath(AuthUser user, AppDeviceSurface surface)
```

Required matrix:

### Desktop

```text
platform_owner    → /platform-owner
institution_admin → /institution-admin
teacher           → /teacher
student           → /student
parent            → /unsupported-device
```

### Mobile

```text
platform_owner    → /unsupported-device
institution_admin → /unsupported-device
teacher           → /teacher
student           → /student
parent            → /parent
```

### Unsupported platform

```text
all authenticated users
→ /unsupported-device
```

Use only the current server-restored `AuthUser.role`.

Do not persist role as long-term routing authority.

## 9. Unsupported Device Screen

Create one minimal authenticated `/unsupported-device` screen.

It may show:

- a concise device-not-supported message;
- current role label if useful;
- logout action.

It must not expose product data or future navigation.

Examples:

```text
Parent on Windows → /unsupported-device
Platform Owner on Android → /unsupported-device
Institution Admin on Android → /unsupported-device
```

Do not remap unsupported roles into another role's shell.

## 10. Minimal Entry Shells

Create minimal Stage 1 entry shells for:

- Platform Owner;
- Institution Admin;
- Teacher;
- Student;
- Parent.

These are **not dashboards**.

Allowed visible content:

```text
role title
current user's full name
institution name when applicable
device surface label where useful
logout action
```

Platform Owner must not display a fabricated institution.

Do not add:

- KPIs;
- cards for future features;
- Groups;
- Topics;
- Homework;
- Blitz;
- Reports;
- Institution management;
- User management;
- role navigation menus for later stages.

Teacher and Student shells must let tests distinguish desktop vs mobile entry
without duplicating business logic.

## 11. Router Guard Precedence

Preserve this strict order:

```text
1. session bootstrapping
2. unauthenticated
3. must_change_password
4. role/device canonical entry
```

Required:

```text
bootstrapping
→ neutral loading screen
```

```text
unauthenticated + protected route
→ /login
```

```text
authenticated + must_change_password=true
→ /change-password
```

```text
authenticated + password complete
→ canonical role/device entry
```

The first-login gate always precedes unsupported-device or role routing.

## 12. Direct Route Blocking

Authenticated password-complete users must never render another role's shell.

Examples:

```text
Student → /teacher
→ /student
```

```text
Teacher → /institution-admin
→ /teacher
```

```text
Institution Admin → /platform-owner
→ /institution-admin
```

```text
Platform Owner → /teacher
→ /platform-owner
```

```text
Parent mobile → /student
→ /parent
```

Wrong-role route attempts redirect directly to the current user's canonical
entry without flashing the requested shell.

## 13. Unsupported-Device Precedence

Password-complete unsupported role/device combinations remain:

```text
/unsupported-device
```

even if the user manually enters another role route.

Examples:

```text
Parent desktop:
  /parent
  /student
  /teacher
→ /unsupported-device
```

```text
Platform Owner mobile:
  /platform-owner
  /teacher
→ /unsupported-device
```

If `must_change_password=true`, `/change-password` still has higher precedence.

## 14. Auth Route Cleanup

Password-complete supported users:

```text
/login
/change-password
temporary /authenticated transition route
→ canonical role/device entry
```

Password-complete unsupported users:

```text
/login
/change-password
temporary transition route
→ /unsupported-device
```

Remove the temporary authenticated transition screen or convert it to a pure
redirect. It must not remain as an additional product entry area.

## 15. Unknown / Corrupt Role Safety

FE-002 should already reject unknown backend roles.

Navigation must still fail closed if an impossible role reaches routing due to
a local programming defect.

Do not map an unknown role to Teacher, Student, or another valid role.

Use a safe local invariant-error/fallback surface with no product content and a
safe logout path where possible.

Do not invent a backend machine error code.

## 16. Session Isolation

Stage 1 requires that previous auth/session state cannot expose another user's
data.

Mandatory rules:

- entry shells read identity only from the **current** session provider;
- no user/role/institution is copied into a long-lived global routing cache;
- logout removes the current shell immediately;
- after logout, protected routes resolve to `/login`;
- same-role account switch shows only the new user's identity;
- cross-role account switch routes to the new role;
- stale route callbacks use current session state;
- delayed prior `/auth/me` or login results cannot restore a previous shell;
- do not create a second session controller/source.

### Same-role example

```text
Teacher A
→ logout
→ Teacher B
→ /teacher shows only B
```

### Cross-role example

```text
Teacher A
→ logout
→ Student B
→ /student
→ no Teacher A identity/shell remains
```

## 17. Shell-Local State Reset

Any shell-local state introduced by this task must be disposed/reset when the
authenticated identity changes.

Do not create global singleton role-shell state.

This task has no product feature cache.

## 18. Logout

Every role entry shell and `/unsupported-device` screen must expose a minimal
logout action using accepted FE-002 `signOut`.

Required:

```text
logout
→ local AuthUser cleared
→ token cleared
→ old shell removed
→ /login
```

Backend logout transport failure must not leave the old user's shell visible
locally.

## 19. Client / Backend Authorization Boundary

Flutter routing never replaces backend role authorization.

Do not:

- suppress backend 403 handling because route guards exist;
- trust route names as API permission;
- infer backend permissions from device surface;
- create client-only product permission matrices.

## 20. Relevant Files

Expected high-value change surface:

| Path | Expected action |
|---|---|
| `frontend/lib/app/router/*` | Implement final Stage 1 auth + role/device routing |
| `frontend/lib/app/device/*` or equivalent | Create injectable device surface resolver |
| `frontend/lib/features/entry/*` or equivalent | Create pure resolver + minimal entry shells |
| `frontend/lib/features/auth/*` | Minimal integration only; reuse accepted session |
| `frontend/test/app/router/*` | Add route guard matrices |
| `frontend/test/features/entry/*` | Add role/device/shell/session-isolation tests |
| `tasks/frontend/stage-01/S01-FE-004-role-device-entry-routing-session-isolation.md` | Preserve |
| `tasks/frontend/stage-01/S01-FE-004-CODEX-PROMPT.md` | Preserve |
| `tasks/STAGE_01_TASK_INDEX.md` | Lifecycle update only |

Do not modify:

- `docs/01–09`;
- `backend/`;
- `docker/`.

Do not add package dependencies unless a material blocker is reported.

## 21. Authoritative Specification References

| Document | Section | Requirement |
|---|---|---|
| `docs/06-roadmap.md` | `2.6 Desktop and Mobile Scope` | Platform Owner/Admin desktop; Teacher/Student desktop+mobile; Parent mobile |
| `docs/06-roadmap.md` | `6. Stage 1 — Authentication and Role-Based Entry` | Correct entry area and protected navigation |
| `docs/07-architecture.md` | `9. Identity and Authorization Architecture` | Server-authoritative role identity |
| `docs/07-architecture.md` | `20. Flutter Application Architecture` | Riverpod/GoRouter session architecture |
| `docs/07-architecture.md` | `21. Flutter Navigation Architecture` | Role-aware routes and route guards |
| `docs/07-architecture.md` | `22. Role/Device Feature Boundary` | Approved role/device surfaces |
| `docs/07-architecture.md` | `23. API Boundary Principles` | Client routing is not backend authority |
| `docs/07-architecture.md` | `32. Testing Architecture` | Flutter navigation/session tests |
| `docs/09-api-contracts.md` | `4. Current User / Session Contract` | `/auth/me` determines session role/context |
| `frontend/AGENTS.md` | Navigation/state/security/testing sections | Frontend implementation discipline |
| `tasks/STAGE_01_TASK_INDEX.md` | `S01-FE-004`; Stage-Wide Verification Map | Entry routing, direct-route blocking, session isolation |

## 22. Acceptance Criteria

- [ ] `S01-FE-003` is `Accepted`.
- [ ] `S01-BE-005` is `Accepted`.
- [ ] Work occurs on `task/s01-fe-004-role-device-routing`.
- [ ] Device surface is injectable/testable.
- [ ] Device surface is not based on viewport width.
- [ ] Windows/macOS/Linux are desktop.
- [ ] Android/iOS are mobile.
- [ ] Web is unsupported for Stage 1.
- [ ] `/platform-owner` exists.
- [ ] `/institution-admin` exists.
- [ ] `/teacher` exists.
- [ ] `/student` exists.
- [ ] `/parent` exists.
- [ ] `/unsupported-device` exists.
- [ ] Temporary authenticated transition screen is removed/reduced to redirect.
- [ ] All 10 role/device combinations resolve exactly as approved.
- [ ] Unauthenticated direct protected routes resolve `/login`.
- [ ] `must_change_password=true` always resolves `/change-password`.
- [ ] Wrong-role direct routes never render the wrong shell.
- [ ] Supported wrong-role user redirects to own canonical role route.
- [ ] Unsupported role/device remains `/unsupported-device`.
- [ ] Role decisions use only current `AuthUser.role`.
- [ ] Role/profile is not persisted as long-term routing authority.
- [ ] Entry shells are minimal and contain no later-stage features.
- [ ] Teacher desktop/mobile entry can be distinguished.
- [ ] Student desktop/mobile entry can be distinguished.
- [ ] All entry/unsupported screens support logout.
- [ ] Backend logout failure cannot keep old shell visible.
- [ ] Teacher A → Teacher B shows only B.
- [ ] Teacher A → Student B routes Student and exposes no A data.
- [ ] Stale previous-session completion cannot restore old shell.
- [ ] Global auth invalidation removes current shell and routes login.
- [ ] No second session source is introduced.
- [ ] No backend/Docker/locked-doc change.
- [ ] No unapproved dependency added.
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] format check passes.
- [ ] Windows debug build passes.
- [ ] Android debug build passes.

## 23. Required Automated Tests

### 23.1 Device Resolver

Test:

```text
Windows → desktop
macOS   → desktop
Linux   → desktop
Android → mobile
iOS     → mobile
Web     → unsupported
```

Also prove changing only viewport size does not change device authorization.

### 23.2 All 10 Role/Device Combinations

| Role | Desktop | Mobile |
|---|---|---|
| Platform Owner | `/platform-owner` | `/unsupported-device` |
| Institution Admin | `/institution-admin` | `/unsupported-device` |
| Teacher | `/teacher` | `/teacher` |
| Student | `/student` | `/student` |
| Parent | `/unsupported-device` | `/parent` |

All 10 are mandatory.

### 23.3 Unauthenticated Protected Route Matrix

Directly attempt:

```text
/platform-owner
/institution-admin
/teacher
/student
/parent
/unsupported-device
```

Expected:

```text
/login
```

### 23.4 Mandatory Password Gate Matrix

For each role with:

```text
must_change_password=true
```

attempt canonical/role routes.

Expected:

```text
/change-password
```

This must take precedence over unsupported-device routing.

### 23.5 Wrong-Role Direct Routes

Test cross-role route attempts on supported surfaces.

Required:

- own route succeeds;
- wrong role route never renders;
- canonical redirect occurs;
- Platform Owner is not a universal bypass.

### 23.6 Unsupported Device

Test at minimum:

```text
Parent + desktop → unsupported
Platform Owner + mobile → unsupported
Institution Admin + mobile → unsupported
```

Attempts to other role routes remain unsupported.

### 23.7 Auth Route Regression

Password-complete supported user:

```text
/login
/change-password
old transition route
→ canonical entry
```

Password-complete unsupported user:

```text
→ /unsupported-device
```

### 23.8 Shell Content

For each shell verify:

- correct role label;
- current full name;
- institution name where applicable;
- Platform Owner has no fake institution;
- logout action;
- no later-feature cards/navigation.

### 23.9 Teacher / Student Surface Presentation

Test:

```text
Teacher desktop
Teacher mobile
Student desktop
Student mobile
```

with correct role and surface presentation.

### 23.10 Same-Role Account Switch

```text
Teacher A
→ logout
→ Teacher B
→ B visible
→ A absent
```

### 23.11 Cross-Role Account Switch

```text
Teacher A
→ logout
→ Student B
→ /student
→ no Teacher shell/A identity
```

### 23.12 Supported / Unsupported Switches

```text
Parent desktop unsupported
→ logout
→ Teacher
→ /teacher
```

and:

```text
Teacher
→ logout
→ Parent desktop
→ /unsupported-device
```

No state leakage.

### 23.13 Stale Session / Router Race

Extend FE-002 regression at UI/router level:

```text
Teacher A /auth/me delayed
→ logout
→ Student B current
→ A completes
→ route remains /student
```

Old captured redirect state must not override current session.

### 23.14 Global Session Invalidation

While a role shell is visible:

```text
authentication_required signal
→ session cleared
→ /login
→ old shell removed
```

### 23.15 Regression

All FE-001/FE-002/FE-003 tests remain green.

## 24. Quality / Verification Commands

From `frontend/`:

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
flutter build windows --debug
flutter build apk --debug
```

Before acceptance gate:

```text
git status --short
git diff --check
git diff main...HEAD -- docs
git diff main...HEAD -- backend
git diff main...HEAD -- docker
```

Expected: no changes in docs/backend/docker.

Review `pubspec.yaml` / `pubspec.lock` for unapproved dependencies.

Scan for:

- token/password logging;
- persisted cached role authority;
- hard-coded production user/institution IDs;
- Platform Owner bypass;
- viewport-width authorization;
- future feature placeholders.

## 25. Manual Smoke

### Windows desktop

Verify:

```text
Platform Owner → /platform-owner
Institution Admin → /institution-admin
Teacher → /teacher desktop
Student → /student desktop
Parent → /unsupported-device
```

Attempt at least one wrong-role URL and confirm canonical redirect.

Logout and confirm `/login`.

### Android/mobile

Verify:

```text
Platform Owner → /unsupported-device
Institution Admin → /unsupported-device
Teacher → /teacher mobile
Student → /student mobile
Parent → /parent
```

Attempt at least one wrong-role URL.

### Account Switch

```text
User A
→ shell
→ logout
→ User B
→ correct B shell
→ no A data
```

Do not store smoke credentials in repository/report.

## 26. Explicit Non-Goals

- Stage 2 institution management.
- Stage 3 user management.
- Groups.
- Topics.
- Materials.
- Homework.
- Blitz.
- Submissions.
- Results.
- Reports.
- Real dashboards/KPIs.
- Product navigation menus/sidebars.
- Tenant-resource authorization.
- Backend role API changes.
- Device registration/session management.
- Web support.
- Push notifications.
- Offline mode.
- Backend/Docker/CI changes.
- Design-system overhaul.

## 27. Stop Conditions

Stop and report if:

- either dependency is not `Accepted`;
- accepted session/navigation foundation is absent/broken;
- locked role/device boundary differs materially;
- local `main` cannot synchronize;
- unrelated dirty state exists;
- task branch cannot be created safely;
- routing requires Stage 2+ product destination;
- implementation requires persisting role locally as authority;
- a new package is materially required but unapproved;
- backend change is required;
- secret/token/password exposure would be required;
- safe completion requires destructive Git, force-push, history rewrite, or
  check bypass;
- material scope expansion is required.

## 28. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git Preflight

Create/switch to:

`task/s01-fe-004-role-device-routing`

Ensure approved task/prompt are on task branch.

Do not commit/push.

### Phase 1 — Implementation

Implement only this task.

Run:

- device resolver tests;
- all 10 role/device matrix tests;
- auth/first-login precedence tests;
- wrong-role direct-route tests;
- unsupported-device tests;
- minimal shell tests;
- account-switch tests;
- stale session/router regression;
- session invalidation tests;
- full Flutter regression;
- analyze;
- format;
- Windows/Android builds;
- scope/security checks.

Do not commit/push.

### Phase 2 — Read-Only Acceptance Gate

Re-read task, root/frontend AGENTS, referenced locked contracts, complete diff,
route matrix, session-isolation evidence, and build/test evidence.

No edits, auto-fixes, staging, commit, push, or merge.

Findings:

- `P1` route/security/session-leak bypass;
- `P2` material role/device/test/scope mismatch;
- `P3` non-blocking observation.

If P1/P2 remains:

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
   - Delivery finalized after merge.
3. Re-run final test/scope/security checks.
4. Stage only approved changes.
5. Commit:

```text
feat(navigation): add role device entry routing
```

Body:

```text
Task: S01-FE-004
```

6. Push task branch.
7. Create PR to `main`.
8. Do not bypass required checks.
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

Do not start `S01-INT-004`.

## 29. Required Codex Final Report

Return:

1. Final status: `ACCEPTED`, `NOT ACCEPTED`, or `DELIVERY BLOCKED`.
2. Dependency/Git preflight.
3. Implementation summary.
4. Changed files.
5. Device-surface resolver evidence.
6. All 10 role/device mapping results.
7. Direct-route denial evidence.
8. First-login/auth guard precedence.
9. Unsupported-device evidence.
10. Minimal-shell scope evidence.
11. Same-role/cross-role account-switch evidence.
12. Stale session/router evidence.
13. Session invalidation evidence.
14. Acceptance findings.
15. Acceptance criteria PASS/FAIL.
16. Analyze/test/format/build evidence.
17. Security/scope evidence.
18. GitHub delivery evidence.
19. Manual desktop/mobile smoke.
20. Remaining blockers/deviations.

Do not start `S01-INT-004`.
