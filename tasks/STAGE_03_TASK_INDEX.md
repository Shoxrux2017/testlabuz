# Stage 3 Task Index — Institution Administration and User Management

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Status | `In Progress` |
| Decomposition approved on | `2026-08-13` |
| Implementation started | `S03-BE-001 accepted and delivered; backend production implementation started` |
| Stage closed | `No` |
| Closure review | `Not started` |

This index records the approved 18-task Stage 3 decomposition. It organizes
implementation and dependency control; it does not add or reinterpret product
behavior beyond the locked specifications and approved task contracts.

## 2. Stage Goal and Boundary

**Goal:** Allow an Institution Admin to set up and maintain Teacher, Student,
and Parent accounts and the approved Institution-level learning settings inside
one Institution.

**Included stage boundary:**

- Exact Institution Admin API contract alignment and task control.
- Own-Institution dashboard totals for Teachers, Students, and Parents.
- Own-Institution basic profile view and approved-field editing.
- Own-Institution Teacher, Student, and Parent list, detail, create, update,
  activate, and deactivate behavior.
- Assessment settings and understanding-category persistence/API behavior
  already defined by the locked contracts.
- Institution Admin desktop shell and the corresponding dashboard, profile,
  User, settings, and category-management UI.
- A final Windows real-stack Stage 3 integration task after all backend and
  frontend tasks are accepted and delivered.

**Excluded stage boundary:**

- Groups/classes, Teacher–Group, Student–Group, and Parent–Student
  relationships; these belong to Stage 4.
- Topics, materials, Homework, Blitz, attempts, checking, scores, results,
  reports beyond the Stage 3 dashboard, and later learning workflows.
- Institution Admin management of Institution Admin or Platform Owner accounts.
- Institution type/lifecycle changes, role changes, login-name edits, password
  resets, deletion/archive/import/bulk User operations, billing, deployment,
  CI, and post-MVP features.

Stage 3 production implementation is sequential and acceptance-gated. Preparing
a detailed task or paired prompt is planning work, not implementation.

## 3. Authoritative References

| Document | Exact section | Why it governs this stage |
|---|---|---|
| `docs/02-user-roles.md` | `2. Institution Admin` | Own-Institution authority, User-management boundary, settings, and device scope |
| `docs/03-features.md` | `3. Institution Admin Features` | Approved dashboard, profile, User, and settings feature scope |
| `docs/04-user-flows.md` | `3. Institution Admin Flow` | Desktop administration sequence and allowed actions |
| `docs/05-business-rules.md` | Institution, role, account, tenant, lifecycle, settings, category, and ACL rules | Server authority, isolation, preservation, and role boundaries |
| `docs/06-roadmap.md` | `8. Stage 3 — Institution Administration and User Management` | Stage goal, dependencies, scope, tests, and acceptance criterion |
| `docs/06-roadmap.md` | `9. Stage 4 — Groups and User Relationships` | Adjacent-stage exclusion and closure dependency |
| `docs/07-architecture.md` | API, authorization, tenancy, Flutter, and testing sections | Layering and security boundaries |
| `docs/08-database.md` | Institutions, Users/Roles, Institution Settings, categories, indexes, and isolation | Approved persistence fields, limits, and historical rules |
| `docs/09-api-contracts.md` | General conventions and Institution Admin profile/User/settings/category/dashboard APIs | Exact Laravel–Flutter contract |
| `tasks/README.md` | Entire file | Task lifecycle, review/delivery vocabulary, and four-phase workflow |
| `AGENTS.md` | Applicable scope, security, testing, and delivery rules | Repository execution authority |

## 4. Entry Gate

- [x] Stage 1 is `Closed / PASS`.
- [x] Stage 2 is `Closed / PASS`.
- [x] All 17 Stage 2 tasks are `Accepted / PASS / Delivered`.
- [x] Stage 3 decomposition was approved on `2026-08-13`.
- [x] `S03-INT-001` has a separately approved detailed task and prompt.
- [x] `S03-INT-001` is `Accepted / PASS / Delivered`.
- [x] `S03-BE-001` has a separately reviewed and approved detailed task/prompt
      pair after `S03-INT-001` delivery.

Production implementation must not start until the current task and every
direct predecessor are `Accepted / PASS / Delivered`.

## 5. Approved Task Order

| Order | Task ID | Area | Short outcome | Direct dependencies | Task status | Review status | Delivery status | File |
|---:|---|---|---|---|---|---|---|---|
| 1 | `S03-INT-001` | Integration | Stage 3 contract alignment and task control | Stage 2 closed | `Accepted` | `PASS` | `Delivered` | `tasks/integration/stage-03/S03-INT-001-stage-03-contract-alignment-task-control.md` |
| 2 | `S03-BE-001` | Backend | Institution Admin dashboard API | `S03-INT-001` | `Accepted` | `PASS` | `Delivered` | `tasks/backend/stage-03/S03-BE-001-institution-admin-dashboard-api.md` |
| 3 | `S03-BE-002` | Backend | Own Institution profile GET/PATCH API | `S03-BE-001` | `Accepted` | `PASS` | `Delivered` | `tasks/backend/stage-03/S03-BE-002-own-institution-profile-api.md` |
| 4 | `S03-BE-003` | Backend | Institution User list/detail API | `S03-BE-002` | `Accepted` | `PASS` | `Delivered` | `tasks/backend/stage-03/S03-BE-003-institution-user-list-detail-api.md` |
| 5 | `S03-BE-004` | Backend | Teacher/Student/Parent create API | `S03-BE-003` | `Accepted` | `PASS` | `Delivered` | `tasks/backend/stage-03/S03-BE-004-institution-user-create-api.md` |
| 6 | `S03-BE-005` | Backend | Institution User update and lifecycle API | `S03-BE-004` | `Accepted` | `PASS` | `Delivered` | `tasks/backend/stage-03/S03-BE-005-institution-user-update-lifecycle-api.md` |
| 7 | `S03-BE-006` | Backend | Assessment settings GET/PUT API | `S03-BE-005` | `Draft` | `Not started` | `Not started` | `tasks/backend/stage-03/S03-BE-006-institution-assessment-settings-api.md` |
| 8 | `S03-BE-007` | Backend | Understanding-category persistence and API | `S03-BE-006` | `Draft` | `Not started` | `Not started` | `tasks/backend/stage-03/S03-BE-007-understanding-category-persistence-api.md` |
| 9 | `S03-FE-001` | Frontend | Institution Admin desktop shell/navigation | `S03-BE-007` | `Draft` | `Not started` | `Not started` | `tasks/frontend/stage-03/S03-FE-001-institution-admin-desktop-shell-navigation.md` |
| 10 | `S03-FE-002` | Frontend | Institution dashboard real-data UI | `S03-FE-001`, `S03-BE-001` | `Draft` | `Not started` | `Not started` | `tasks/frontend/stage-03/S03-FE-002-institution-dashboard-real-data-states.md` |
| 11 | `S03-FE-003` | Frontend | Institution profile view/edit UI | `S03-FE-002`, `S03-BE-002` | `Draft` | `Not started` | `Not started` | `tasks/frontend/stage-03/S03-FE-003-own-institution-profile-view-edit.md` |
| 12 | `S03-FE-004` | Frontend | User list/search/filter/sort/pagination UI | `S03-FE-003`, `S03-BE-003` | `Draft` | `Not started` | `Not started` | `tasks/frontend/stage-03/S03-FE-004-institution-user-list-search-filters-pagination.md` |
| 13 | `S03-FE-005` | Frontend | Institution User detail UI | `S03-FE-004`, `S03-BE-003` | `Draft` | `Not started` | `Not started` | `tasks/frontend/stage-03/S03-FE-005-institution-user-detail.md` |
| 14 | `S03-FE-006` | Frontend | Teacher/Student/Parent create UI | `S03-FE-005`, `S03-BE-004` | `Draft` | `Not started` | `Not started` | `tasks/frontend/stage-03/S03-FE-006-institution-user-create.md` |
| 15 | `S03-FE-007` | Frontend | Institution User edit/lifecycle UI | `S03-FE-006`, `S03-BE-005` | `Draft` | `Not started` | `Not started` | `tasks/frontend/stage-03/S03-FE-007-institution-user-edit-lifecycle.md` |
| 16 | `S03-FE-008` | Frontend | Assessment settings UI | `S03-FE-007`, `S03-BE-006` | `Draft` | `Not started` | `Not started` | `tasks/frontend/stage-03/S03-FE-008-institution-assessment-settings-ui.md` |
| 17 | `S03-FE-009` | Frontend | Understanding-category range editor | `S03-FE-008`, `S03-BE-007` | `Draft` | `Not started` | `Not started` | `tasks/frontend/stage-03/S03-FE-009-understanding-category-range-editor.md` |
| 18 | `S03-INT-002` | Integration | Stage 3 Windows real-stack E2E verification | All Stage 3 backend/frontend tasks | `Draft` | `Not started` | `Not started` | `tasks/integration/stage-03/S03-INT-002-stage-03-windows-real-stack-e2e-verification.md` |

`S03-INT-001`, `S03-BE-001`, `S03-BE-002`, `S03-BE-003`, `S03-BE-004`, and
`S03-BE-005` are `Accepted / PASS / Delivered`. The remaining 12 rows are
planned paths and remain `Draft` until each detailed task/prompt pair is
separately reviewed, approved, and placed in the project. The next
implementation gate is `S03-BE-006`.

```text
Task/prompt file prepared ≠ implementation started
Task Approved ≠ Accepted
Accepted requires Phase 2 PASS + safe delivery to origin/main
```

Paired execution prompts are preparation artifacts; they are not evidence of
implementation, review PASS, acceptance, or delivery.

## 6. Standard Task Acceptance and GitHub Delivery Workflow

Each task follows:

```text
PHASE 0 - Git Preflight
PHASE 1 - Implementation
PHASE 2 - Read-Only Acceptance Gate
PHASE 3 - Post-Acceptance Git Delivery
```

Production implementation remains sequential. A task may execute only after
all direct dependencies are `Accepted / PASS / Delivered`. Detailed task and
prompt files may be prepared before predecessor delivery, but preparation does
not start the task.

`NOT ACCEPTED` stops delivery and every dependent task. `DELIVERY BLOCKED`
means Phase 2 passed but safe GitHub delivery did not finish; dependents remain
blocked until delivery is completed and verified.

## 7. Dependency and Checkpoint Notes

| Dependency or checkpoint | Required before | Evidence when satisfied |
|---|---|---|
| Stage 2 closure | `S03-INT-001` | Stage 2 index/closure review and closure commit on `origin/main` |
| Exact Stage 3 profile/User/dashboard contracts and task index | `S03-BE-001` | `S03-INT-001` is `Accepted / PASS / Delivered` |
| Dashboard API | `S03-FE-002` | `S03-BE-001` is `Accepted / PASS / Delivered` |
| Own-Institution profile API | `S03-FE-003` | `S03-BE-002` is `Accepted / PASS / Delivered` |
| User list/detail API | `S03-FE-004`, `S03-FE-005` | `S03-BE-003` is `Accepted / PASS / Delivered` |
| User create API | `S03-FE-006` | `S03-BE-004` is `Accepted / PASS / Delivered` |
| User update/lifecycle API | `S03-FE-007` | `S03-BE-005` is `Accepted / PASS / Delivered` |
| Assessment settings API | `S03-FE-008` | `S03-BE-006` is `Accepted / PASS / Delivered` |
| Understanding-category API | `S03-FE-009` | `S03-BE-007` is `Accepted / PASS / Delivered` |
| Every Stage 3 backend/frontend task | `S03-INT-002` | Tasks 2–17 are `Accepted / PASS / Delivered` |
| Stage 3 E2E verification and all 18 task deliveries | Separate Stage 3 Closure Review | All Stage 3 task rows are `Accepted / PASS / Delivered` |
| Delivered Stage 3 Closure Review with `FINAL STATUS: STAGE CLOSED` | Any Stage 4 task | Closure bookkeeping is on `origin/main`, local `main` matches, and the tree is clean |

## 8. Stage-Wide Verification Map

| Roadmap acceptance outcome | Task(s) that implement it | Task(s) that verify it | Status |
|---|---|---|---|
| Institution Admin sees exact own-Institution Teacher/Student/Parent totals. | `S03-BE-001`, `S03-FE-002` | `S03-INT-002`, Closure Review | `Not started` |
| Institution Admin views and edits only approved own-Institution profile fields. | `S03-BE-002`, `S03-FE-003` | `S03-INT-002`, Closure Review | `Not started` |
| Teacher/Student/Parent accounts can be listed, viewed, created, edited, activated, and deactivated inside one Institution. | `S03-BE-003`–`S03-BE-005`, `S03-FE-004`–`S03-FE-007` | `S03-INT-002`, Closure Review | `Not started` |
| Approved Institution learning settings are manageable without changing fixed attempt rules. | `S03-BE-006`, `S03-BE-007`, `S03-FE-008`, `S03-FE-009` | `S03-INT-002`, Closure Review | `Not started` |
| Cross-Institution access, disallowed roles, protected fields, and stale-session disclosure are blocked. | All Stage 3 backend/frontend tasks | `S03-INT-002`, Closure Review | `Not started` |
| Complete Stage 3 behavior works through the real Windows/Laravel/PostgreSQL stack. | Tasks 2–17 | `S03-INT-002`, Closure Review | `Not started` |

## 9. Stage Risks and Stop Conditions

- Tenant scope must always come from the authenticated Institution Admin;
  filters, pagination, direct UUIDs, and mutations must not widen it.
- Shared User resources must exclude Institution IDs, creator data,
  credentials, tokens, settings, relationships, answers, scores, and results.
- Institution Admin must not manage Platform Owner or Institution Admin
  accounts, edit role/login/password through normal User update, or change
  Institution type/lifecycle.
- User create must preserve global login-name uniqueness and atomic failure;
  lifecycle commands must preserve tokens/history and be idempotent by state.
- Dashboard metrics must remain limited to the Stage 3 User totals until later
  stages own Group/Learning data.
- Assessment settings/category contracts must not drift during unrelated User
  work, and fixed Homework/Blitz attempt rules must remain unchanged.
- Task preparation must not be mistaken for implementation or acceptance.
- Stage 4 remains blocked until the separate Stage 3 Closure Review is
  delivered with `FINAL STATUS: STAGE CLOSED`.

Stop affected work for a locked-contract conflict, missing dependency,
unapproved task authority, tenant/security gap, application scope drift, failed
read-only gate, unsafe Git/GitHub state, or material expansion beyond the
current approved task.

## 10. Change Log

| Date | Change | Reason | Approved by |
|---|---|---|---|
| `2026-08-13` | Approved the 18-task Stage 3 decomposition and `S03-INT-001` contract/control entry gate | Establish exact Stage 3 contract and sequential task control before production implementation | Project owner |
| `2026-08-14` | Accepted and delivered `S03-INT-001` | Read-only gate passed and the Stage 3 contract/control result was prepared for delivery to `origin/main` | Codex |

## 11. Closure Readiness

- [ ] Every one of the 18 Stage 3 tasks is `Accepted / PASS / Delivered`.
- [ ] Local `main` matches `origin/main` and the working tree is clean.
- [ ] Dashboard, profile, User, settings, and category contracts agree across
      Laravel and Flutter.
- [ ] Required backend, frontend, integration, and real-stack checks pass.
- [ ] Cross-Institution, wrong-role, lifecycle, validation, historical, and
      session-isolation checks pass.
- [ ] No Stage 4+ production behavior was introduced.
- [ ] A separate Stage 3 Closure Review has returned and been delivered as
      `FINAL STATUS: STAGE CLOSED`.
- [ ] Stage 3 is explicitly marked `Closed` only after closure delivery.

The closure review is separate from the 18 tasks in this index. Stage 4 must
not start before that separate closure gate is fully delivered.
