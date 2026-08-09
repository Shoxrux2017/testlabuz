# Stage 1 Task Index — Authentication and Role-Based Entry

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Status | `In Progress` |
| Decomposition approved on | `2026-08-09` |
| Implementation started | `Yes — S01-INT-001 is accepted` |
| Stage closed | `No` |

## 2. Stage Goal and Boundary

**Goal:** Allow every approved user type to authenticate securely and enter
only the correct part of TestLabUz.

**Included stage boundary:**

- Secure login/logout/current-session behavior.
- Active/inactive user and institution enforcement.
- Server-authoritative role and institution identity.
- Mandatory first-login password-change gate for administrator-created
  Institution Admin, Teacher, Student, and Parent accounts.
- Protected-endpoint authorization foundation.
- Flutter authentication/session infrastructure.
- Correct desktop/mobile role entry routing and direct-route blocking.
- Previous-session isolation so one user's state cannot leak to another user.
- End-to-end Stage 1 authentication verification across Laravel, PostgreSQL,
  Sanctum, and Flutter.

**Excluded stage boundary:**

- Stage 2 institution-management product features.
- Stage 3 institution user-management product features beyond the minimum
  controlled Stage 1 fixtures needed to verify authentication.
- Groups, relationships, Topics, Materials, Homework, Blitz, checking,
  scoring, results, reports, and other later-stage workflows.
- Advanced session management, two-factor authentication, device management,
  enterprise identity providers, custom roles, and Post-MVP authentication
  infrastructure.

This index organizes implementation. It does not add or reinterpret product
behavior from the locked specification.

## 3. Authoritative References

| Document | Exact section | Why it governs this stage |
|---|---|---|
| `docs/06-roadmap.md` | `6. Stage 1 — Authentication and Role-Based Entry` | Stage goal, backend/desktop/mobile scope, security, required tests, acceptance criteria, exclusions |
| `docs/07-architecture.md` | `2.1 Backend`, `2.2 Frontend`, `2.3 API Style`, `2.4 Database`, `2.6 Local Development` | Laravel/Flutter/PostgreSQL/API/local-runtime baseline |
| `docs/07-architecture.md` | `9. Identity and Authorization Architecture` | Five roles, one primary role, Sanctum baseline, first-login password gate, layered authorization |
| `docs/07-architecture.md` | `20. Flutter Application Architecture` | Riverpod, GoRouter, Dio, DTO/repository boundaries, secure token storage |
| `docs/07-architecture.md` | `21. Flutter Navigation Architecture` | Role-aware routes, route guards, desktop/mobile shell boundaries |
| `docs/07-architecture.md` | `22. Role/Device Feature Boundary` | Approved desktop/mobile role surfaces |
| `docs/07-architecture.md` | `23. API Boundary Principles` | Versioning, server authority, validation/error boundaries |
| `docs/07-architecture.md` | `32. Testing Architecture` | Backend feature tests, Flutter tests, integration/smoke requirements |
| `docs/08-database.md` | `3. Multi-Institution / Tenant Model` | Platform-owner exception and institution ownership rules |
| `docs/08-database.md` | `4. Institutions` | Institution identity/status persistence |
| `docs/08-database.md` | `5. Users and Roles` | User schema, five role values, login identifier, role/institution constraint, Sanctum table |
| `docs/08-database.md` | `8. Institution Settings` | Institution timezone required by authenticated institution context |
| `docs/09-api-contracts.md` | `1–2. API Contract Overview / General API Conventions` | `/api/v1`, bearer token, envelopes, stable errors |
| `docs/09-api-contracts.md` | `3. Authentication Contract` | Login, logout, current user, change password, first-login gate |
| `docs/09-api-contracts.md` | `4. Current User / Session Contract` | `/auth/me` bootstrap authority and shell determination |
| `docs/09-api-contracts.md` | `5. Error Response Contract` | Stable authentication/account/authorization error codes |
| `AGENTS.md` | `3. Working Model`, `19. Testing Requirements`, `20. Quality Gates`, `21. Change-Control Rule`, `22. Scope-Control Rules`, `25. Task Completion Checklist` | One-task workflow, required tests/quality/review discipline |
| `backend/AGENTS.md` | Entire applicable file | Backend-specific implementation rules |
| `frontend/AGENTS.md` | Entire applicable file | Flutter-specific implementation rules |

## 4. Entry Gate

- [x] Stage 0 is explicitly closed.
- [x] Locked `docs/01–09` contracts are approved and cross-document audited.
- [x] `S01-INT-001 — Project Repository Foundation` passed read-only review.
- [x] Local repository root is `G:\project\testlabuz` on unborn `main`.
- [x] Stage 1 decomposition was discussed and approved on 2026-08-09.
- [x] GitHub repository is user-approved as the project remote:
      `https://github.com/Shoxrux2017/testlabuz.git`.
- [x] `S01-INT-002` must establish the first committed/pushed baseline before
      production framework implementation starts.

## 5. Approved Task Order

Tasks are implemented and accepted one at a time. Except for the initial
baseline task, production tasks use one task branch and are delivered to
`origin/main` only after their read-only acceptance gate passes.

| Order | Task ID | Area | Short outcome | Depends on | Task status | Review status | Delivery status | File |
|---:|---|---|---|---|---|---|---|---|
| 1 | `S01-INT-001` | Integration | Project repository foundation and unborn `main` Git work tree | None | `Accepted` | `PASS` | `Not applicable` | `tasks/integration/stage-01/S01-INT-001-project-repository-foundation.md` |
| 2 | `S01-INT-002` | Integration | GitHub remote, initial repository baseline, Stage 1 control files, and permanent task Git-delivery workflow | `S01-INT-001` | `Accepted` | `PASS` | `Delivered` | `tasks/integration/stage-01/S01-INT-002-github-remote-repository-baseline-stage-control.md` |
| 3 | `S01-BE-001` | Backend | Laravel API scaffold and backend quality/error foundation | `S01-INT-002` | `Accepted` | `PASS` | `Delivered` | `tasks/backend/stage-01/S01-BE-001-laravel-api-scaffold-quality-foundation.md` |
| 4 | `S01-INT-003` | Integration | Local Laravel runtime and PostgreSQL development/test foundation | `S01-BE-001` | `Approved` | `Not started` | `Not started` | `tasks/integration/stage-01/S01-INT-003-local-backend-runtime-postgresql-foundation.md` |
| 5 | `S01-BE-002` | Backend | Institution/user identity persistence, Sanctum token persistence, and controlled Stage 1 fixtures | `S01-INT-003` | `Approved` | `Not started` | `Not started` | `tasks/backend/stage-01/S01-BE-002-identity-persistence-foundation.md` |
| 6 | `S01-BE-003` | Backend | Sanctum login, logout, `/auth/me`, active-user/institution enforcement | `S01-BE-002` | `Approved` | `Not started` | `Not started` | `tasks/backend/stage-01/S01-BE-003-sanctum-authentication-session-api.md` |
| 7 | `S01-BE-004` | Backend | Mandatory first-login password-change endpoint and backend gate | `S01-BE-003` | `Approved` | `Not started` | `Not started` | `tasks/backend/stage-01/S01-BE-004-first-login-password-change-gate.md` |
| 8 | `S01-BE-005` | Backend | Reusable role-authorization foundation and cross-role denial tests | `S01-BE-004` | `Approved` | `Not started` | `Not started` | `tasks/backend/stage-01/S01-BE-005-role-authorization-foundation.md` |
| 9 | `S01-FE-001` | Frontend | Flutter scaffold, Riverpod/GoRouter/Dio/core client quality foundation | `S01-BE-005` | `Approved` | `Not started` | `Not started` | `tasks/frontend/stage-01/S01-FE-001-flutter-client-scaffold-core-infrastructure.md` |
| 10 | `S01-FE-002` | Frontend | Auth API/repository/session bootstrap and secure token/state isolation | `S01-FE-001`, `S01-BE-003` | `Approved` | `Not started` | `Not started` | `tasks/frontend/stage-01/S01-FE-002-authentication-data-session-foundation.md` |
| 11 | `S01-FE-003` | Frontend | Login and mandatory first-login password-change UX | `S01-FE-002`, `S01-BE-004` | `Approved` | `Not started` | `Not started` | `tasks/frontend/stage-01/S01-FE-003-login-first-password-change-ux.md` |
| 12 | `S01-FE-004` | Frontend | Role/device route guards, minimal entry shells, direct-route denial, session isolation | `S01-FE-003`, `S01-BE-005` | `Approved` | `Not started` | `Not started` | `tasks/frontend/stage-01/S01-FE-004-role-device-entry-routing-session-isolation.md` |
| 13 | `S01-INT-004` | Integration | Real Stage 1 end-to-end authentication and role-entry verification | `S01-BE-005`, `S01-FE-004` | `Approved` | `Not started` | `Not started` | `tasks/integration/stage-01/S01-INT-004-stage-01-e2e-authentication-verification.md` |

After all 13 tasks are accepted, run:

`tasks/STAGE_01_CLOSURE_REVIEW.md`

The closure review is not an implementation task.

## 6. Standard Task Acceptance and GitHub Delivery Workflow

`S01-INT-002` must encode this workflow into the repository task guidance and
reusable templates.

### Phase 0 — Git Preflight

For every production task after the initial baseline:

1. Repository must be clean before task work starts.
2. Local `main` must be synchronized from `origin/main` using safe
   fast-forward-only operations.
3. Create one task branch from current `main`.
4. Recommended branch naming:
   `task/<lowercase-task-id>-<short-slug>`.
5. Never start implementation on a stale or dirty `main`.

### Phase 1 — Implementation

- Implement only the approved task.
- Run task-specific tests, security checks, static analysis, formatting, and
  smoke checks.
- Do not push the implementation during this phase.

### Phase 2 — Read-Only Acceptance Gate

- Re-read the current task and independently inspect the resulting diff/state.
- Do not modify implementation while the acceptance gate is running.
- Return `PASS` or `NOT ACCEPTED`.
- If `NOT ACCEPTED`, stop. Do not commit, push, merge, or start another task.
- Findings are returned to the user/ChatGPT for a focused correction cycle.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 passes.

1. Update task/index bookkeeping required to record acceptance.
2. Re-run safe final diff/secret checks for the bookkeeping-only changes.
3. Create one focused task commit using an appropriate Conventional Commit
   type and include the task ID in the commit body.
4. Push the task branch to the approved `origin`.
5. Create a Pull Request to `main` when GitHub tooling/authentication permits.
6. Merge only when required checks pass and the merge is permitted.
7. Never bypass required checks or branch protection.
8. Synchronize local `main` with merged `origin/main`.
9. Verify the working tree is clean and local `main` equals `origin/main`.
10. Only then report final task status `ACCEPTED`.

### Final statuses

- `ACCEPTED` — acceptance gate passed and approved result is present on
  `origin/main`.
- `NOT ACCEPTED` — implementation/review failed; no GitHub delivery.
- `DELIVERY BLOCKED` — implementation acceptance passed, but safe delivery to
  `origin/main` could not be completed. Do not start another task.

### Git safety rules

Unless a separately approved recovery task explicitly requires otherwise:

- no `git push --force`;
- no `git push --force-with-lease`;
- no direct production-task push to `main` after the initial repository
  baseline;
- no `git reset --hard` or destructive `git clean`;
- no rebasing shared/pushed task history;
- no `--no-verify` bypass;
- no credentials/tokens committed to the repository;
- no modification of global Git configuration;
- no silent replacement of an unexpected `origin`;
- no merge when required GitHub checks are failing.

## 7. Dependency and Checkpoint Notes

| Dependency or checkpoint | Required before | Evidence when satisfied |
|---|---|---|
| Accepted repository foundation | `S01-INT-002` | `S01-INT-001` read-only review PASS |
| Initial committed GitHub baseline on `origin/main` | `S01-BE-001` | `S01-INT-002` final `ACCEPTED`, local `main == origin/main`, clean tree |
| Laravel API scaffold | `S01-INT-003` | `S01-BE-001` accepted |
| Working PostgreSQL-backed local/test runtime | `S01-BE-002` | `S01-INT-003` accepted |
| Institution/user identity schema | `S01-BE-003` | `S01-BE-002` accepted |
| Login/logout/current-session API | `S01-BE-004`, `S01-FE-002` | `S01-BE-003` accepted |
| First-login backend gate | `S01-FE-003` | `S01-BE-004` accepted |
| Role authorization primitives | `S01-FE-004`, `S01-INT-004` | `S01-BE-005` accepted |
| Flutter core client infrastructure | `S01-FE-002` | `S01-FE-001` accepted |
| Flutter auth/session foundation | `S01-FE-003` | `S01-FE-002` accepted |
| Login/password-change UX | `S01-FE-004` | `S01-FE-003` accepted |
| Role/device routing | `S01-INT-004` | `S01-FE-004` accepted |
| Full real-stack verification | Stage closure review | `S01-INT-004` accepted |

## 8. Stage-Wide Verification Map

| Roadmap acceptance criterion | Task(s) that implement it | Task(s) that verify it | Status |
|---|---|---|---|
| All five roles can authenticate through their approved device surface. | `S01-BE-002`, `S01-BE-003`, `S01-FE-002`, `S01-FE-003`, `S01-FE-004` | Task reviews + `S01-INT-004` | `Not started` |
| Each role reaches the correct entry area. | `S01-FE-004` | `S01-FE-004` review + `S01-INT-004` | `Not started` |
| Inactive users are blocked. | `S01-BE-003` | `S01-BE-003` tests/review + `S01-INT-004` | `Not started` |
| Users in inactive institutions are blocked. | `S01-BE-003` | `S01-BE-003` tests/review + `S01-INT-004` | `Not started` |
| Unauthorized protected pages and endpoints are blocked. | `S01-BE-004`, `S01-BE-005`, `S01-FE-004` | Backend negative tests, frontend guard tests, `S01-INT-004` | `Not started` |
| Previous auth/session state cannot expose another user's data. | `S01-FE-002`, `S01-FE-004` | Session-isolation tests + `S01-INT-004` account-switch smoke | `Not started` |

Additional locked authentication contracts that must also pass even though they
are more specific than the roadmap's six top-level acceptance bullets:

| Contract | Owner task(s) | Final verification |
|---|---|---|
| Client cannot choose role or institution during login. | `S01-BE-003`, `S01-FE-003` | `S01-INT-004` |
| Institution context comes from trusted persisted account data. | `S01-BE-002`, `S01-BE-003` | `S01-INT-004` |
| Administrator-created Institution Admin/Teacher/Student/Parent accounts must change the initial password. | `S01-BE-002`, `S01-BE-004`, `S01-FE-003` | `S01-INT-004` |
| While `must_change_password = true`, only `/auth/me`, `/auth/change-password`, and `/auth/logout` remain available. | `S01-BE-004` | Backend negative tests + `S01-INT-004` |
| Flutter bootstrap restores authority through `/api/v1/auth/me`; cached role is not long-term authority. | `S01-FE-002` | Frontend tests + `S01-INT-004` |
| Tokens/passwords are never logged or exposed. | `S01-BE-003`, `S01-FE-002` | Task security reviews + `S01-INT-004` |

## 9. Stage Risks and Stop Conditions

- Authentication/session work is security-sensitive; client routing can never
  substitute for backend authorization.
- Platform Owner is the only Stage 1 role allowed to have
  `institution_id = null`.
- Institution users must be denied when their institution is inactive.
- `must_change_password` must be a backend gate, not only a Flutter redirect.
- The repository must not proceed past `S01-INT-002` without a clean
  `origin/main` baseline.
- An unexpected non-empty GitHub remote, conflicting remote history, wrong
  `origin`, missing GitHub authentication, or failed required GitHub checks
  must stop delivery; never force-push or rewrite remote history.
- Framework/package versions must be resolved by the corresponding approved
  scaffold task from installed/current supported tooling; do not silently
  revise locked architecture.
- Cross-role authorization must be tested without inventing fake production
  product APIs solely for Stage 1.
- No later-stage product feature may be added to make an entry shell look
  "complete".

Stop affected work if a locked-contract conflict, missing dependency, unsafe
Git state, authorization gap, tenant-isolation gap, or material scope expansion
is discovered.

## 10. Change Log

| Date | Change | Reason | Approved by |
|---|---|---|---|
| `2026-08-09` | Added final Stage 1 decomposition with 13 tasks | User approved stage decomposition workflow | Project owner |
| `2026-08-09` | Added post-acceptance GitHub delivery policy and changed `S01-INT-002` to establish remote/baseline control | User requires professional GitHub delivery after every accepted task | Project owner |
| `2026-08-09` | Approved `S01-INT-002` for Codex execution | Project owner explicitly approved the detailed task | Project owner |
| `2026-08-09` | Accepted and delivered `S01-INT-002` baseline workflow | Read-only gate passed and initial baseline delivery completed | Codex |

## 11. Closure Readiness

- [ ] Every approved task is `Accepted`.
- [ ] Every accepted production task is present on `origin/main`.
- [ ] Local `main` matches `origin/main` and the working tree is clean.
- [ ] All stage-wide acceptance criteria are mapped and satisfied.
- [ ] Backend, frontend, database, and integration behavior agree.
- [ ] Required automated tests and quality gates pass.
- [ ] Required manual smoke paths pass.
- [ ] Negative authorization and institution-status checks pass.
- [ ] Previous-session/account-switch isolation is verified.
- [ ] No blocking regression remains.
- [ ] Task/index/documentation statuses are current.
- [ ] `tasks/STAGE_01_CLOSURE_REVIEW.md` has been completed.
- [ ] Stage 1 has been explicitly marked `Closed`.
