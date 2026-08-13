# Stage 2 Task Index — Multi-Institution Platform Management

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `Stage 2 — Multi-Institution Platform Management` |
| Status | `Closed` |
| Decomposition approved on | `2026-08-10` |
| Implementation started | `Complete — all 17 tasks are accepted and delivered` |
| Stage closed | `Yes` |
| Closure review | `PASS` |

This index records the approved Stage 2 decomposition only. It does not add,
reinterpret, or approve product behavior beyond the locked specifications and
individually approved task contracts.

## 2. Stage Goal and Boundary

**Goal:** Give the Platform Owner / Super Admin basic control over educational
institutions while preserving strict separation from ordinary institution
learning workflows.

**Included stage boundary:**

- Platform Owner institution list/detail, search, filters, sorting, pagination,
  and basic usage counts.
- Institution creation with safe operational settings initialization.
- Institution basic-profile update through approved platform fields only.
- Idempotent institution activate/deactivate behavior.
- Platform dashboard aggregates where approved.
- Institution Admin list/create/update/activate/deactivate behavior.
- Platform Owner desktop UI for dashboard, institution management, and
  Institution Admin management.
- Full real-stack Stage 2 verification after the implementation tasks.

**Excluded stage boundary:**

- Detailed learning analytics, student submissions, scores, results, reports,
  files, groups, topics, homework, blitz, notifications, billing, impersonation,
  and custom-role systems.
- Any implementation of later Stage 2 tasks before their individual task
  contracts are approved.

## 3. Authoritative References

| Document | Exact section | Why it governs this stage |
|---|---|---|
| `docs/02-user-roles.md` | `1. Platform Owner / Super Admin` | Platform Owner authority and learning-data boundary |
| `docs/04-user-flows.md` | Platform Owner institution-management flow | Platform Owner can locate and view institutions through platform administration |
| `docs/05-business-rules.md` | `2. Institution and Data Separation Rules` | Multi-institution separation, lifecycle values, platform authority, learning boundary |
| `docs/06-roadmap.md` | `7. Stage 2 — Multi-Institution Platform Management` | Stage goal, scope, dependencies, tests, and acceptance criteria |
| `docs/07-architecture.md` | Backend/API/multi-institution/authorization/testing sections | Architecture and implementation boundaries |
| `docs/08-database.md` | Multi-institution, institutions, users, and settings sections | Persistence model and ownership constraints |
| `docs/09-api-contracts.md` | API conventions, errors, pagination, Super Admin institution APIs, authorization scope | Stable client/server contract |
| `AGENTS.md` | Applicable workflow, testing, quality, scope, and completion sections | One-task execution and acceptance/delivery protocol |
| `backend/AGENTS.md` | Entire applicable file | Backend authority, security, code organization, and tests |
| `frontend/AGENTS.md` | Entire applicable file | Frontend implementation rules for later UI tasks |

## 4. Approved Task Order

Tasks are implemented and accepted one at a time. `S02-BE-001` through
`S02-BE-007`, `S02-FE-001`, `S02-FE-002`, `S02-FE-003`, `S02-FE-004`,
`S02-FE-005`, `S02-FE-006`, `S02-FE-007`, and `S02-FE-008` are accepted and
delivered. `S02-FE-009` is accepted and delivered. `S02-INT-001` is accepted
after its corrected read-only gate passed and is delivered.

| Order | Task ID | Area | Short outcome | Task status | Review status | Delivery status | File |
|---:|---|---|---|---|---|---|---|
| 1 | `S02-BE-001` | Backend | Institution list/detail API, search, filters, sorting, pagination, and basic user counts | `Accepted` | `PASS` | `Delivered` | `tasks/backend/stage-02/S02-BE-001-platform-institution-list-detail-api.md` |
| 2 | `S02-BE-002` | Backend | Atomic institution creation with safe `institution_settings` initialization | `Accepted` | `PASS` | `Delivered` | `tasks/backend/stage-02/S02-BE-002-platform-institution-create-api.md` |
| 3 | `S02-BE-003` | Backend | Institution basic-profile update with a strict platform-field allowlist | `Accepted` | `PASS` | `Delivered` | `tasks/backend/stage-02/S02-BE-003-platform-institution-update-api.md` |
| 4 | `S02-BE-004` | Backend | Idempotent institution activate/deactivate and institution-user access enforcement | `Accepted` | `PASS` | `Delivered` | `tasks/backend/stage-02/S02-BE-004-platform-institution-lifecycle-access-enforcement.md` |
| 5 | `S02-BE-005` | Backend | Platform dashboard aggregate API | `Accepted` | `PASS` | `Delivered` | `tasks/backend/stage-02/S02-BE-005-platform-dashboard-aggregate-api.md` |
| 6 | `S02-BE-006` | Backend | Institution Admin list/create API and first-login password gate | `Accepted` | `PASS` | `Delivered` | `tasks/backend/stage-02/S02-BE-006-platform-institution-admin-list-create-api.md` |
| 7 | `S02-BE-007` | Backend | Institution Admin update/activate/deactivate API | `Accepted` | `PASS` | `Delivered` | `tasks/backend/stage-02/S02-BE-007-platform-institution-admin-update-lifecycle-api.md` |
| 8 | `S02-FE-001` | Frontend | Platform Owner desktop shell and navigation | `Accepted` | `PASS` | `Delivered` | `tasks/frontend/stage-02/S02-FE-001-platform-owner-desktop-shell-navigation.md` |
| 9 | `S02-FE-002` | Frontend | Real Platform dashboard with loading/error/empty/data states | `Accepted` | `PASS` | `Delivered` | `tasks/frontend/stage-02/S02-FE-002-platform-dashboard-real-data-states.md` |
| 10 | `S02-FE-003` | Frontend | Institution list, search, filters, sorting, and pagination | `Accepted` | `PASS` | `Delivered` | `tasks/frontend/stage-02/S02-FE-003-platform-institution-list-search-filters-pagination.md` |
| 11 | `S02-FE-004` | Frontend | Institution detail and basic usage presentation | `Accepted` | `PASS` | `Delivered` | `tasks/frontend/stage-02/S02-FE-004-platform-institution-detail-basic-usage.md` |
| 12 | `S02-FE-005` | Frontend | Create Institution form and mutation flow | `Accepted` | `PASS` | `Delivered` | `tasks/frontend/stage-02/S02-FE-005-platform-institution-create-form-mutation.md` |
| 13 | `S02-FE-006` | Frontend | Edit Institution form for allowed fields | `Accepted` | `PASS` | `Delivered` | `tasks/frontend/stage-02/S02-FE-006-platform-institution-edit-basic-information.md` |
| 14 | `S02-FE-007` | Frontend | Activate/deactivate confirmation, in-flight protection, and refresh | `Accepted` | `PASS` | `Delivered` | `tasks/frontend/stage-02/S02-FE-007-platform-institution-lifecycle-actions.md` |
| 15 | `S02-FE-008` | Frontend | Institution Admin list/create UI within Institution detail | `Accepted` | `PASS` | `Delivered` | `tasks/frontend/stage-02/S02-FE-008-platform-institution-admin-list-create.md` |
| 16 | `S02-FE-009` | Frontend | Institution Admin edit/activate/deactivate UI | `Accepted` | `PASS` | `Delivered` | `tasks/frontend/stage-02/S02-FE-009-platform-institution-admin-update-lifecycle.md` |
| 17 | `S02-INT-001` | Integration | Full real-stack Stage 2 end-to-end verification on Windows | `Accepted` | `PASS` | `Delivered` | `tasks/integration/stage-02/S02-INT-001-stage-02-windows-real-stack-e2e-verification.md` |

All 17 implementation tasks are accepted and delivered. The separate Stage 2
Closure Review passed; this closure bookkeeping closes the stage when delivered
to `origin/main`. The closure review is not an implementation task.

## 5. Entry Gate

- [x] Stage 1 is explicitly closed.
- [x] Stage 1 DoD is `PASS`.
- [x] All 13 Stage 1 tasks are `Accepted` and delivered to `origin/main`.
- [x] Stage 2 decomposition is recorded here from the approved
      `S02-BE-001` contract.
- [x] `S02-BE-001` is accepted and delivered.
- [x] `S02-BE-004` is accepted and delivered.
- [x] `S02-BE-005` is accepted and delivered.
- [x] `S02-BE-006` is accepted and delivered.
- [x] `S02-BE-007` is accepted and delivered.
- [x] `S02-FE-004` is accepted and delivered.
- [x] `S02-FE-007` is accepted and delivered after read-only review and manual PR merge.
- [x] `S02-FE-009` and `S02-INT-001` are accepted and delivered; the corrected
      S02-INT-001 Phase 2 result remains `PASS`.

## 6. Standard Task Acceptance and GitHub Delivery Workflow

Production tasks use one task branch and are delivered to `origin/main` only
after their read-only acceptance gate passes.

### Phase 0 - Git Preflight

1. Start from a clean local `main` synchronized with `origin/main`.
2. Verify the approved remote and required dependency closure.
3. Create the required task branch from current `main`.
4. Verify no conflicting Stage 2 implementation exists.

### Phase 1 - Implementation

- Implement only the approved task.
- Run task-specific tests, full relevant regression, format/static checks, and
  smoke checks where possible.
- Do not push implementation work during this phase.

### Phase 2 - Read-Only Acceptance Gate

- Re-read the task, applicable instructions, referenced locked contracts, and
  complete diff.
- Do not edit files, stage, commit, push, merge, or self-fix findings during
  this gate.
- If any P1/P2 finding remains, stop with `NOT ACCEPTED`.

### Phase 3 - Post-Acceptance Git Delivery

Run only after Phase 2 passes. Update necessary bookkeeping, commit the focused
task result, push the task branch, open a PR when tooling permits, merge only
when safe, synchronize local `main`, and verify a clean final state.

## 7. Stage Risks and Stop Conditions

- Platform Owner endpoints must stay explicit platform actions, not a universal
  bypass for ordinary institution-scoped learning routes.
- Search, filters, pagination, and direct UUID access must not expose protected
  learning data or user identities.
- Later Stage 2 task behavior must not be implemented before approval.
- Any locked-spec conflict, unsafe git state, missing accepted dependency,
  authorization gap, schema dependency, or required scope expansion blocks the
  affected task.

## 8. Change Log

| Date | Change | Reason | Approved by |
|---|---|---|---|
| `2026-08-10` | Recorded Stage 2's 17-task decomposition and first approved task | `S02-BE-001` control-file entry gate | Project owner |
| `2026-08-11` | Accepted and delivered `S02-BE-001` | Read-only gate passed and platform institution read API delivery completed | Codex |
| `2026-08-11` | Accepted and delivered `S02-BE-002` | Read-only gate passed and atomic institution creation API delivery completed | Codex |
| `2026-08-11` | Accepted and delivered `S02-BE-003` | Read-only gate passed and platform institution update API delivery completed | Codex |
| `2026-08-11` | Accepted and delivered `S02-BE-004` | Read-only gate passed and platform institution lifecycle/access delivery completed | Codex |
| `2026-08-11` | Accepted and delivered `S02-BE-005` | Read-only gate passed and platform dashboard aggregate API delivery completed | Codex |
| `2026-08-11` | Accepted and delivered `S02-BE-006` | Read-only gate passed and institution admin list/create API delivery completed | Codex |
| `2026-08-11` | Recorded `S02-BE-006` correction cycle | Delivery-integrity verification found the GET admin-list body rejection defect; correction re-verification is required before the existing accepted/delivered state remains authoritative | Codex |
| `2026-08-11` | Accepted and delivered `S02-BE-007` | Read-only gate passed and institution admin update/lifecycle API delivery completed | Codex |
| `2026-08-11` | Delivery blocked for `S02-FE-002` | Read-only gate passed and branch pushed, but PR creation was blocked by unavailable GitHub delivery tooling/permissions | Codex |
| `2026-08-11` | Accepted and delivered `S02-FE-002` | Manual PR merge completed; final delivery inspection confirmed required commits on `origin/main` and no implementation contradiction | Codex |
| `2026-08-11` | Accepted and delivered `S02-FE-003` | Read-only gate passed and Platform Owner Institution list delivery completed | Codex |
| `2026-08-11` | Delivery blocked for `S02-FE-004` | Read-only gate passed and branch pushed, but PR creation was blocked by GitHub connector permissions and unavailable GitHub CLI | Codex |
| `2026-08-12` | Accepted and delivered `S02-FE-004` | Manual PR #29 merge completed; final delivery inspection confirmed required commits on `origin/main` and no implementation contradiction | Codex |
| `2026-08-12` | Accepted and delivered `S02-FE-005` | Read-only gate passed and Platform Owner Institution create flow delivery completed | Codex |
| `2026-08-12` | Accepted and delivered `S02-FE-006` | Read-only gate passed and Platform Owner Institution basic-information edit flow delivery completed | Codex |
| `2026-08-12` | Recorded approval for `S02-FE-007` | Project owner approved Platform Owner Institution lifecycle action implementation | Project owner |
| `2026-08-12` | Accepted `S02-FE-007` | Read-only gate passed for Platform Owner Institution lifecycle actions; manual real-stack Windows smoke was not run because a controlled backend, credentials, and test data were unavailable | Codex |
| `2026-08-12` | Accepted and delivered `S02-FE-007` | Manual PR #34 merge completed; final delivery inspection confirmed required commit `025861380861c4764f8eeb21650bf12e87373d08` on `origin/main`, merge commit `2f8e902e8073eeec847d8108f7600a486b0302a8`, and no implementation contradiction | Codex |
| `2026-08-13` | Accepted `S02-FE-008` | Read-only gate passed for Institution Admin list/create UI; manual live smoke was not run because no running backend or Platform Owner credentials were available | Codex |
| `2026-08-13` | Delivery blocked for `S02-FE-008` | Accepted branch was pushed, but PR creation was blocked by GitHub connector permission `403`; manual PR creation and merge were required | Codex |
| `2026-08-13` | Accepted and delivered `S02-FE-008` | Manual PR #36 merge completed; final delivery inspection confirmed required commit `86fd616eab3a55e7d38116b203d67f80881cea69` on `origin/main`, merge commit `37a154d2d40d408df86b9b39263289cbe082187c`, and no implementation/security/contract contradiction. Manual live smoke remains NOT RUN because no running backend or Platform Owner credentials were available | Codex |
| `2026-08-13` | Accepted `S02-FE-009` | Read-only gate passed with zero unresolved P1/P2/P3 findings; required checks and real-stack smoke passed | Codex |
| `2026-08-13` | Accepted and delivered `S02-FE-009` | Manual PR #38 merge completed; final delivery inspection confirmed required commit `01417ae9d843c6b06f90b3d169609cfab483051a` on `origin/main`, merge commit `ce6d037e97015298788db3f4f3f73046d9674c60`, and no implementation/security/API-contract/scope contradiction | Codex |
| `2026-08-13` | Accepted `S02-INT-001` | Corrected strictly read-only Phase 2 passed with no unresolved P1/P2/P3; Windows real-stack E2E, independent PostgreSQL oracle, owner smoke, and quality gates passed. Delivery remains pending | Codex |
| `2026-08-13` | Accepted and delivered `S02-INT-001` | Manual PR #40 merge completed; final delivery inspection confirmed required commit `4f2c4a16f43a0958312441a9b8b3af6d2c9c84a6` on `origin/main`, merge commit `aa223890c26bb9a5f4704c7d2efe1bd92e7786e8`, and no implementation, security, evidence, or scope contradiction. Stage 2 remains not closed | Codex |
| `2026-08-13` | Stage 2 Closure Review `PASS` | Renewed read-only stage-wide audit at `8b43abc614fdd5c66760c4f26f48aab4e8947f9d` found no unresolved P1/P2; closure bookkeeping marks Stage 2 `Closed` / `Stage closed: Yes` for delivery through the closure PR | Codex |

## 9. Closure Readiness

- [x] Every approved Stage 2 implementation task is `Accepted`.
- [x] Every accepted production task is present on `origin/main`.
- [x] Local `main` matched `origin/main` and the working tree was clean except
      the owner-prepared closure-review file at audit preflight.
- [x] Required backend, frontend, and integration quality gates pass.
- [x] Required manual smoke paths pass.
- [x] No blocking regression remains.
- [x] Task/index/documentation statuses are current in this closure bookkeeping.
- [x] Stage 2 closure review is `PASS`; formal delivery is completed by merging
      this closure bookkeeping to `origin/main` and final synchronization.
