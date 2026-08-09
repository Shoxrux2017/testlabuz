# Stage [Number] Task Index — [Stage Name]

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `[Stage number and exact roadmap name]` |
| Status | `Draft` |
| Decomposition approved on | `[YYYY-MM-DD or Not approved]` |
| Implementation started | `No` |
| Stage closed | `No` |

## 2. Stage Goal and Boundary

**Goal:** [Copy or closely summarize the approved roadmap goal.]

**Included stage boundary:**

- [Approved stage outcome]

**Excluded stage boundary:**

- [Behavior belonging to another stage or post-MVP]

This index organizes implementation. It does not add product behavior to the
locked specification.

## 3. Authoritative References

| Document | Exact section | Why it governs this stage |
|---|---|---|
| `docs/06-roadmap.md` | `[Stage section]` | Stage scope, dependencies, verification, and acceptance criteria |
| `[docs/0X-name.md]` | `[Exact section]` | `[Relevant business/technical contract]` |

## 4. Entry Gate

- [ ] Previous stage is explicitly closed.
- [ ] Required specification contracts are approved and non-conflicting.
- [ ] All stage dependencies are available.
- [ ] Task decomposition has been discussed and approved.
- [ ] No unresolved business rule blocks the first task.

If an entry-gate item fails, keep this stage `Draft` or `Blocked` and do not
start production implementation.

## 5. Approved Task Order

Tasks are implemented and reviewed one at a time unless an approved dependency
plan explicitly allows otherwise.

| Order | Task ID | Area | Short outcome | Depends on | Task status | Review status | Delivery status | File |
|---:|---|---|---|---|---|---|---|---|
| 1 | `[S00-BE-001]` | `[Backend]` | `[One small outcome]` | `[None]` | `Draft` | `Not started` | `Not started` | `[relative path]` |
| 2 | `[S00-FE-001]` | `[Frontend]` | `[One small outcome]` | `[Task ID]` | `Draft` | `Not started` | `Not started` | `[relative path]` |
| 3 | `[S00-INT-001]` | `[Integration]` | `[One cross-layer outcome]` | `[Task IDs]` | `Draft` | `Not started` | `Not started` | `[relative path]` |

Valid task statuses are defined in `tasks/README.md`. Each row must point to one
detailed task created from `CODEX_TASK_TEMPLATE.md` before implementation.

Valid review statuses are `Not started`, `PASS`, and `NOT ACCEPTED`.

Valid delivery statuses are `Not started`, `Delivered`, `Blocked`, and
`Not applicable`.

An implementation task may become `Accepted` only when its review status is
`PASS`, delivery status is `Delivered`, the accepted result is on
`origin/main`, local `main` matches `origin/main`, and the working tree is
clean.

## 6. Standard Task Acceptance and GitHub Delivery Workflow

Each task follows:

```text
PHASE 0 - Git Preflight
PHASE 1 - Implementation
PHASE 2 - Read-Only Acceptance Gate
PHASE 3 - Post-Acceptance Git Delivery
```

`NOT ACCEPTED` means no commit, push, merge, or later task may proceed from that
result. `DELIVERY BLOCKED` means the acceptance gate passed but safe GitHub
delivery could not finish. Future production tasks use task branches and PRs;
direct pushes to `main` are reserved for an explicitly approved empty-repository
baseline task.

## 7. Dependency and Checkpoint Notes

| Dependency or checkpoint | Required before | Evidence when satisfied |
|---|---|---|
| `[Contract, migration, endpoint, UI, fixture, etc.]` | `[Task ID]` | `[Task/review/test evidence]` |

Do not hide a cross-layer dependency inside an unrelated task.

## 8. Stage-Wide Verification Map

| Roadmap acceptance criterion | Task(s) that implement it | Task(s) that verify it | Status |
|---|---|---|---|
| `[Exact criterion]` | `[Task IDs]` | `[Task/review IDs]` | `Not started` |

Every roadmap criterion must be mapped. A criterion with no implementing or
verifying task is a decomposition gap.

## 9. Stage Risks and Stop Conditions

- [Known dependency or risk]
- [Security/tenant/lifecycle risk]
- [Git/GitHub delivery risk]

Stop affected work if a locked-contract conflict, missing decision, tenant
isolation gap, unsafe Git state, failed acceptance gate, failed required GitHub
check, or material scope expansion is discovered. Record the blocker here and
resolve it through the approved planning process.

## 10. Change Log

| Date | Change | Reason | Approved by |
|---|---|---|---|
| `[YYYY-MM-DD]` | `[Index/task-order change]` | `[Reason]` | `[User / project owner]` |

Updating task order or scope must not silently alter locked product behavior.

## 11. Closure Readiness

- [ ] Every approved task is `Accepted` after read-only review.
- [ ] Every accepted implementation task is delivered to `origin/main`.
- [ ] Local `main` matches `origin/main` and the working tree is clean.
- [ ] All stage-wide acceptance criteria are mapped and satisfied.
- [ ] Backend, frontend, and integration behavior agree.
- [ ] Required automated tests and quality gates pass.
- [ ] Required manual smoke paths pass.
- [ ] Negative authorization and tenant-isolation checks pass.
- [ ] No blocking regression remains.
- [ ] Relevant documentation and task statuses are current.
- [ ] A stage closure review has been completed.
- [ ] The stage has been explicitly marked `Closed`.
