# Stage 4 Frontend Build Runner — Approval-Gated Codex Orchestrator

## 1. Purpose

Sequentially implement the approved TestLabUz Stage 4 frontend queue while keeping Codex context limited to one task at a time.

Queue:

```text
tasks/frontend/stage-04/S04-FE-001-institution-group-navigation-and-list.md
tasks/frontend/stage-04/S04-FE-002-institution-group-create-and-detail.md
tasks/frontend/stage-04/S04-FE-003-institution-group-edit-and-archive-lifecycle.md
tasks/frontend/stage-04/S04-FE-004-teacher-and-student-group-membership-management.md
tasks/frontend/stage-04/S04-FE-005-parent-student-relationship-management.md
```

Current approval map:

```text
S04-FE-001 = Approved / implementation already delivered
S04-FE-002 = Approved / implementation already delivered
S04-FE-003 = Approved / implementation already delivered
S04-FE-004 = Approved
S04-FE-005 = Approved
```

The runner must always recover the actual first not-yet-delivered task from synchronized `origin/main`. At this planning baseline FE-004 is the first not-yet-delivered task; after FE-004 delivery, FE-005 may continue automatically because its review is complete and it is Approved. This descriptive map is not delivery proof.

Do not run Frontend Phase 2, the full frontend suite, Windows build, broad E2E, Stage integration, or Stage closure from this runner.

---

## 2. Authority Boundary

For one active implementation task, Codex may read only:

1. this Runner;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. the currently active task contract after its approval gate opens;
5. directly relevant production code, tests, and configuration;
6. immediately related implementation patterns required for consistency.

Do not use these to determine implementation behavior:

```text
docs/
roadmap/specification files
tasks/STAGE_04_TASK_INDEX.md
previous task bodies
future task bodies
Stage history
checkpoint/closure reviews
historical CODEX-PROMPT files
```

The active approved task defines WHAT. Applicable `AGENTS.md` files define HOW.

If an approved task conflicts materially with current source/engineering rules or omits a required product/API/security/lifecycle/UX decision:

```text
BLOCKED
```

Stop instead of inventing behavior.

---

## 3. Hard Rules

- Work on exactly one task at a time.
- Never implement future-task scope early.
- Never read a future task body before its approval gate opens.
- Use one branch and one focused PR per task.
- Start each task from latest synchronized `main`.
- Preserve all user work.
- Never force-push, rewrite history, bypass checks, or use destructive cleanup.
- Do not change backend, product docs, task contracts, Stage index, or Phase 2 files from an implementation task unless the active contract explicitly authorizes it.
- Do not change task `Status`; task approval is ChatGPT/project-owner planning work.
- Do not create duplicate Codex prompt files.
- Do not add speculative infrastructure for later tasks.
- Do not weaken tests.
- Do not add package/platform changes unless explicitly required.
- Use only verification required by the active task.
- Do not run a task-level Phase 2 review.

---

## 4. Repository Preflight

From the TestLabUz repository root:

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

Require:

```text
repository = TestLabUz
origin = Shoxrux2017/testlabuz
branch = main
HEAD == origin/main
ahead/behind = 0/0
working tree clean
```

A normal safe fast-forward is allowed.

Return `BLOCKED` if synchronization requires:

```text
force
history rewrite
reset --hard over user work
destructive clean
discarding modified/untracked work
```

Verify all queue files are tracked:

```powershell
git ls-files --error-unmatch tasks/frontend/stage-04/S04-FE-001-institution-group-navigation-and-list.md
git ls-files --error-unmatch tasks/frontend/stage-04/S04-FE-002-institution-group-create-and-detail.md
git ls-files --error-unmatch tasks/frontend/stage-04/S04-FE-003-institution-group-edit-and-archive-lifecycle.md
git ls-files --error-unmatch tasks/frontend/stage-04/S04-FE-004-teacher-and-student-group-membership-management.md
git ls-files --error-unmatch tasks/frontend/stage-04/S04-FE-005-parent-student-relationship-management.md
```

Read root/frontend `AGENTS.md` before the active task.

---

## 5. Determine Resume Point

Do not trust memory across Runner invocations.

Inspect synchronized `origin/main` and determine the first queue task whose implementation is not yet delivered.

Use evidence such as:

```text
merged implementation files/tests on origin/main
merged task PR/commit evidence when available
```

Do not infer implementation delivery from planning `Status = Approved`.

Known delivery evidence currently includes:

```text
S04-FE-001 merge:
698b611677522071b6dae547c997c3f1a503d19e

S04-FE-002 merge:
d330d693c02a9a8bed043e5628989bbe56979ccf
```

For every already-delivered earlier task, record runner-local:

```text
ACCEPTED / DELIVERED
```

Then apply the dependency and approval gates to the first not-yet-delivered task.

---

## 6. Approval and Dependency Gate

Before opening the active task body:

1. synchronize `main`;
2. inspect only the task Metadata section;
3. require:

```text
Status = Approved
```

4. for FE-002 and later, require the immediately preceding task to be Accepted / Delivered.

When the dependency is delivered but task status is not Approved:

```text
WAITING FOR TASK APPROVAL
```

Report:

```text
next task
observed status/review
current main SHA
previous task delivery evidence
```

Do not open or implement the Draft task body.

When dependency is not delivered:

```text
BLOCKED
```

Report the missing dependency evidence.

---

## 7. Per-Task Execution Loop

For the active approved task:

```text
Synchronize main
→ verify dependency
→ approval gate
→ read active contract
→ create exact task branch
→ inspect directly relevant source/tests
→ implement only active scope
→ run contract-required focused verification
→ complete scope/diff self-review
→ focused GitHub delivery
→ verify merged result on origin/main
→ resynchronize main
→ next task gate
```

### Implementation

Follow:

```text
active task contract
root AGENTS.md
frontend/AGENTS.md
```

Do not implement adjacent tasks.

### Verification

Run exactly the active task's:

```text
focused tests
named directly affected regressions
static analysis
format check
git diff --check
focused scope/diff self-review
```

Narrow diagnostic reruns are allowed.

Do not independently run:

```text
full frontend suite
Windows build
broad E2E
Frontend Phase 2
Stage integration
```

Fix ordinary in-scope defects without asking for confirmation.

Return `BLOCKED` only when continuing requires an unapproved decision/scope or unsafe Git action.

### Delivery

Follow the task's exact branch/commit/PR contract.

After merge require:

```text
implementation present on origin/main
local main == origin/main
ahead/behind = 0/0
working tree clean
```

If implementation and verification pass but safe delivery cannot complete:

```text
DELIVERY BLOCKED
```

Stop.

### Task checkpoint

After successful delivery report:

```text
S04-FE-00N ACCEPTED / DELIVERED
PR: <number/url>
merge: <sha>
focused verification: PASS
main sync: PASS
```

Then continue automatically only when the next task is already Approved.

---

## 8. Stop Statuses

### `WAITING FOR TASK APPROVAL`

Use only when:

```text
previous dependency delivered
next task exists
next task metadata is not Approved
```

### `BLOCKED`

Use for:

```text
unsafe Git state
dependency not delivered
contract/source conflict requiring a decision
missing required implementation decision
verification cannot be made safe inside approved scope
unexpected shared-infrastructure risk requiring unapproved scope
```

### `DELIVERY BLOCKED`

Use when:

```text
implementation and verification pass
but GitHub delivery cannot complete safely
```

Stop after any status above.

---

## 9. Queue Order

Execute exactly:

```text
1. S04-FE-001 — Institution Group Navigation and List
2. S04-FE-002 — Institution Group Create and Detail
3. S04-FE-003 — Institution Group Edit and Archive Lifecycle
4. S04-FE-004 — Teacher and Student Group Membership Management
5. S04-FE-005 — Parent–Student Relationship Management
```

Never reorder or parallelize implementation.

ChatGPT may review a future task while Codex implements the current approved task.

---

## 10. Final Frontend Implementation Block Gate

After FE-005 is Accepted / Delivered:

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

Do not run new broad verification.

Final success:

```text
STAGE 4 FRONTEND IMPLEMENTATION BLOCK COMPLETE
READY FOR CHATGPT FRONTEND PHASE 2
```

Do not declare Stage 4 closed.

---

## 11. Completion Report

On complete queue delivery:

| Task | Result | PR | Merge SHA | Focused verification |
|---|---|---|---|---|
| S04-FE-001 | ACCEPTED / DELIVERED | ... | ... | PASS |
| S04-FE-002 | ACCEPTED / DELIVERED | ... | ... | PASS |
| S04-FE-003 | ACCEPTED / DELIVERED | ... | ... | PASS |
| S04-FE-004 | ACCEPTED / DELIVERED | ... | ... | PASS |
| S04-FE-005 | ACCEPTED / DELIVERED | ... | ... | PASS |

Final evidence:

```text
branch: main
HEAD: <sha>
origin/main: <sha>
ahead/behind: 0/0
working tree: clean
Frontend Phase 2: NOT RUN
Full frontend suite: NOT RUN by this Runner
Windows build: NOT RUN by this Runner
Broad E2E: NOT RUN by this Runner
```
