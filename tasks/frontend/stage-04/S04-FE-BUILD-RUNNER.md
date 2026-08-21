# Stage 4 Frontend Build Runner — Approval-Gated Codex Orchestrator

## Purpose

Orchestrate the Stage 4 frontend implementation queue while preserving the TestLabUz one-task-at-a-time implementation model.

All five task files may already exist in the repository, but **existence is not implementation authorization**.

The runner may implement a task only when the task's own metadata on the latest synchronized `main` says:

```text
Status = Approved
```

Current planning expectation at initial launch:

```text
S04-FE-001 = Approved
S04-FE-002 = Approved
S04-FE-003 = Draft / Review pending
S04-FE-004 = Draft / Review pending
S04-FE-005 = Draft / Review pending
```

This lets Codex start S04-FE-001 immediately. After S04-FE-001 is Accepted / Delivered, S04-FE-002 may continue automatically because it has completed review and is Approved; later Draft tasks remain approval-gated.

Queue:

```text
tasks/frontend/stage-04/S04-FE-001-institution-group-navigation-and-list.md
tasks/frontend/stage-04/S04-FE-002-institution-group-create-and-detail.md
tasks/frontend/stage-04/S04-FE-003-institution-group-edit-and-archive-lifecycle.md
tasks/frontend/stage-04/S04-FE-004-teacher-and-student-group-membership-management.md
tasks/frontend/stage-04/S04-FE-005-parent-student-relationship-management.md
```

Do not run Frontend Phase 2, the full frontend suite, Windows build, broad E2E, Stage integration, or Stage closure from this runner.

---

# 1. Authority Boundary

For implementation Codex may read only:

1. this runner;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. the **currently active Approved task contract**;
5. source code, tests, and configuration directly required by that active task;
6. immediately related implementation patterns needed for consistency.

Do not use these to determine implementation behavior:

```text
docs/
roadmap/specification files
tasks/STAGE_04_TASK_INDEX.md
previous task contracts
future task contract bodies
Stage history
checkpoint reviews
closure reviews
historical CODEX-PROMPT files
```

The active Approved task contract defines WHAT. `AGENTS.md` defines HOW.

If an Approved contract materially conflicts with current source/AGENTS or leaves a required product/API/security/lifecycle/UX decision unresolved:

```text
BLOCKED
```

Stop.

---

# 2. Critical Approval Gate

Before opening the body of each queue task:

1. synchronize local `main` with `origin/main`;
2. inspect **only that task's Metadata section**;
3. require exact:

```text
Status = Approved
```

If the next task says:

```text
Status = Draft
Review = Pending
```

or any status other than `Approved`:

```text
WAITING FOR TASK APPROVAL
```

Stop cleanly.

This is **not** `BLOCKED` and is **not** `DELIVERY BLOCKED`.

Report:

```text
next task
observed status
current main SHA
previous task delivery status
```

Do not open the non-Approved task body and do not implement any part of it.

If ChatGPT/reviewer approves that task later and the approval update reaches `origin/main`, a new runner/Codex invocation may resume from the first not-yet-delivered task.

If the approval update lands on `origin/main` before the runner reaches the next task, the normal synchronization step may observe `Approved` and continue automatically.

---

# 3. Hard Runner Rules

- Work on exactly one implementation task at a time.
- Never implement future-task scope early.
- Never open a future task body before its approval gate opens.
- One focused Git branch and PR per task.
- Start every task from latest synchronized `main`.
- Preserve all pre-existing user work.
- Never force-push, rewrite history, reset/delete user work, or bypass checks.
- Do not modify backend/product docs/task contracts/Stage indexes/Phase 2 files from implementation tasks unless the active contract explicitly authorizes it.
- Do not change a task's `Status`; approval remains ChatGPT/project-owner planning work.
- Do not create duplicate `CODEX-PROMPT` files.
- No speculative infrastructure for later tasks.
- No weakened tests.
- No package/platform changes unless active contract explicitly requires them.
- Verification is proportional and comes from the active task.
- Narrow diagnostic reruns are allowed for focused failures.
- Do not run a per-task Phase 2 review.

---

# 4. Initial Repository Preflight

From TestLabUz repository root verify:

```text
repository = TestLabUz
origin = Shoxrux2017/testlabuz
branch = main
working tree = clean
local main == origin/main
ahead/behind = 0/0
```

Use safe commands:

```powershell
git remote -v
git switch main
git fetch --prune origin
git branch --show-current
git rev-parse HEAD
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
git status --short
```

Fast-forward normally if safe.

Stop `BLOCKED` if synchronization would require:

```text
force
reset --hard over user work
history rewrite
destructive cleanup
discarding modified/untracked user work
```

Verify all queue files are tracked and present:

```powershell
git ls-files --error-unmatch tasks/frontend/stage-04/S04-FE-001-institution-group-navigation-and-list.md
git ls-files --error-unmatch tasks/frontend/stage-04/S04-FE-002-institution-group-create-and-detail.md
git ls-files --error-unmatch tasks/frontend/stage-04/S04-FE-003-institution-group-edit-and-archive-lifecycle.md
git ls-files --error-unmatch tasks/frontend/stage-04/S04-FE-004-teacher-and-student-group-membership-management.md
git ls-files --error-unmatch tasks/frontend/stage-04/S04-FE-005-parent-student-relationship-management.md
```

Read root `AGENTS.md` and `frontend/AGENTS.md` before the first implementation task.

---

# 5. Determine Resume Point

Do not trust runner memory across separate invocations.

At the start of every invocation, inspect `origin/main` and determine the first queue task whose implementation is not yet delivered.

Use safe Git/GitHub evidence such as:

```text
merged implementation presence on origin/main
task-specific production/tests expected by the approved contract
merged PR/commit evidence when available
```

Never infer `Accepted` merely from the task file's planning status.

For each earlier task already delivered, record runner-local:

```text
accepted / delivered
```

Then apply the approval gate to the first not-yet-delivered task.

Initial expected resume point:

```text
S04-FE-001
```

---

# 6. Per-Task Execution Loop

For the active task, perform:

```text
Synchronize main
→ Approval Gate
→ Read Active Contract
→ Create Task Branch
→ Inspect Relevant Source/Tests
→ Implement
→ Focused Verification
→ Scope/Diff Self-Check
→ GitHub Delivery
→ Main Sync / Acceptance Evidence
→ Next Task Approval Gate
```

## 6.1 Synchronize

Before each task:

```powershell
git switch main
git fetch --prune origin
```

Require:

```text
HEAD == origin/main
ahead/behind = 0/0
working tree clean
```

For S04-FE-002 and later, require the immediately preceding implementation task to be accepted/delivered.

---

## 6.2 Approval Gate

Inspect only the active task Metadata section.

Require:

```text
Status = Approved
```

If not Approved:

```text
WAITING FOR TASK APPROVAL
```

Stop without implementation.

---

## 6.3 Read Active Contract

Only after approval is proven, read the complete active task contract.

Do not read previous/future task bodies.

If a required implementation decision is absent or conflicting:

```text
BLOCKED
```

Stop instead of inventing behavior.

---

## 6.4 Branch and Implementation

Create the exact branch required by the active task's Delivery section from synchronized `main`.

Implement only the active task.

Follow:

```text
root AGENTS.md
frontend/AGENTS.md
active task contract
```

Do not implement adjacent future task scope.

---

## 6.5 Verification

Run exactly the focused verification required by the active task contract, including its:

```text
focused tests
directly affected regressions
static analysis
format check
git diff --check
focused diff/scope self-review
```

Do not run full frontend suite/build/E2E/Phase 2 unless the active contract explicitly requires it.

Fix ordinary in-scope implementation/test defects and rerun only necessary focused checks.

If continuing requires unapproved architecture/product/API/security/lifecycle scope:

```text
BLOCKED
```

---

## 6.6 Delivery

Follow the active task's exact branch/commit/PR delivery contract.

After merge require:

```text
implementation present on origin/main
local main == origin/main
ahead/behind = 0/0
working tree clean
```

If implementation and verification pass but safe GitHub delivery cannot complete:

```text
DELIVERY BLOCKED
```

Stop.

---

## 6.7 Task Checkpoint

After successful delivery print:

```text
S04-FE-00N ACCEPTED / DELIVERED
PR: <number/url>
merge: <sha>
focused verification: PASS
main sync: PASS
```

Then synchronize `main` again and apply the **approval gate** to the next queue task.

Do not ask for user confirmation if the next task is already Approved.

---

# 7. Queue Order

Exact order:

```text
1. S04-FE-001 — Institution Group Navigation and List
2. S04-FE-002 — Institution Group Create and Detail
3. S04-FE-003 — Institution Group Edit and Archive Lifecycle
4. S04-FE-004 — Teacher and Student Group Membership Management
5. S04-FE-005 — Parent–Student Relationship Management
```

Never reorder or parallelize implementation tasks.

Parallel work is limited to **ChatGPT reviewing future task contracts while Codex implements the current Approved task**.

---

# 8. Stop Statuses

Use exactly:

### `WAITING FOR TASK APPROVAL`

Use when:

```text
next implementation dependency is delivered
but the next task metadata on synchronized main is not Approved
```

No implementation defect is implied.

### `BLOCKED`

Use for:

```text
unsafe Git state
contract/source conflict requiring a decision
missing required implementation decision
focused verification cannot be made safe within task scope
unexpected shared-infrastructure issue requiring unapproved scope
```

### `DELIVERY BLOCKED`

Use when:

```text
implementation + focused verification pass
but safe GitHub delivery cannot complete
```

Do not continue after any stop status.

---

# 9. Final Frontend Implementation Block Gate

After S04-FE-005 is accepted/delivered, perform only final Git synchronization:

```powershell
git switch main
git fetch --prune origin
git rev-parse HEAD
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
git status --short
```

Require:

```text
HEAD == origin/main
ahead/behind = 0/0
working tree clean
```

Do not run broad verification here.

Final success:

```text
STAGE 4 FRONTEND IMPLEMENTATION BLOCK COMPLETE
READY FOR CHATGPT FRONTEND PHASE 2
```

Do not declare Stage 4 closed.

---

# 10. Completion Report

On a complete five-task run, return:

| Task | Result | PR | Merge SHA | Focused verification |
|---|---|---|---|---|
| S04-FE-001 | ACCEPTED / DELIVERED | ... | ... | PASS |
| S04-FE-002 | ACCEPTED / DELIVERED | ... | ... | PASS |
| S04-FE-003 | ACCEPTED / DELIVERED | ... | ... | PASS |
| S04-FE-004 | ACCEPTED / DELIVERED | ... | ... | PASS |
| S04-FE-005 | ACCEPTED / DELIVERED | ... | ... | PASS |

Final Git evidence:

```text
branch: main
HEAD: <sha>
origin/main: <sha>
ahead/behind: 0/0
working tree: clean
Frontend Phase 2: NOT RUN
Full frontend suite: NOT RUN by this runner
Windows build: NOT RUN by this runner
Broad E2E: NOT RUN by this runner
```

If the runner stops after an individual task because the next contract is still under review, finish with:

```text
WAITING FOR TASK APPROVAL
```

and identify the next task.

If implementation cannot continue for another reason, finish with:

```text
BLOCKED
```

or:

```text
DELIVERY BLOCKED
```
