# Stage 4 Task Index — Groups and User Relationships

## 1. Stage Metadata

| Field | Value |
|---|---|
| Stage | `Stage 4 — Groups and User Relationships` |
| Stage dependency | `Stage 3 closed` |
| Backend implementation | `S04-BE-001…005 Accepted / Delivered` |
| Complete Backend Phase 2 | `PASS` |
| Frontend decomposition | `Approved — 5 implementation tasks` |
| Frontend contracts | `FE-001 Approved; FE-002…005 Draft / Review pending` |
| Frontend implementation | `FE-001 ready to start` |
| Frontend Build Runner | `Prepared — approval-gated orchestration only` |
| Frontend Phase 2 | `Pending all FE-001…005 Accepted / Delivered` |
| Integration | `Not decomposed; blocked until Frontend Phase 2 PASS` |
| Stage closure | `Pending` |

This file is the Stage 4 orchestration/status map.

It is for ChatGPT/project tracking. Codex must not read it to determine implementation behavior.

---

## 2. Backend Gate

Stage 4 backend implementation is complete:

| Task | State |
|---|---|
| `S04-BE-001` | `Accepted / Delivered` |
| `S04-BE-002` | `Accepted / Delivered` |
| `S04-BE-003` | `Accepted / Delivered` |
| `S04-BE-004` | `Accepted / Delivered` |
| `S04-BE-005` | `Accepted / Delivered` |

Complete Stage 4 Backend Phase 2:

```text
PASS
P1 = 0
P2 = 0
P3 = 0
```

Verified backend checkpoint baseline:

```text
main / origin/main:
2e9dab8cfeb8a1caed4cc71c361a1f4812a1ce61

Full backend suite:
293 passed
17,306 assertions
350.85s
exit code 0

git diff --check:
PASS
```

Therefore backend does not block the frontend block.

---

## 3. Frontend Task Files

All five frontend task files may be stored/tracked now:

```text
tasks/frontend/stage-04/
  S04-FE-001-institution-group-navigation-and-list.md
  S04-FE-002-institution-group-create-and-detail.md
  S04-FE-003-institution-group-edit-and-archive-lifecycle.md
  S04-FE-004-teacher-and-student-group-membership-management.md
  S04-FE-005-parent-student-relationship-management.md
  S04-FE-BUILD-RUNNER.md
```

Physical presence in the repository does **not** authorize implementation.

Implementation authorization comes only from the current task's own:

```text
Status = Approved
```

---

## 4. Current Frontend Queue

| Order | Task | Title | Dependency | Planning status | Implementation state |
|---:|---|---|---|---|---|
| 1 | `S04-FE-001` | Institution Group Navigation and List | Complete Backend Phase 2 `PASS` | `Approved` | `Ready to start` |
| 2 | `S04-FE-002` | Institution Group Create and Detail | `FE-001 Accepted / Delivered` | `Draft / Review pending` | `Not authorized` |
| 3 | `S04-FE-003` | Institution Group Edit and Archive Lifecycle | `FE-002 Accepted / Delivered` | `Draft / Review pending` | `Not authorized` |
| 4 | `S04-FE-004` | Teacher and Student Group Membership Management | `FE-003 Accepted / Delivered` | `Draft / Review pending` | `Not authorized` |
| 5 | `S04-FE-005` | Parent–Student Relationship Management | `FE-004 Accepted / Delivered` | `Draft / Review pending` | `Not authorized` |

Exact dependency chain:

```text
Backend Phase 2 PASS
    ↓
FE-001 Approved
    ↓ Accepted / Delivered
FE-002 must be Approved
    ↓ Accepted / Delivered
FE-003 must be Approved
    ↓ Accepted / Delivered
FE-004 must be Approved
    ↓ Accepted / Delivered
FE-005 must be Approved
    ↓ Accepted / Delivered
Frontend Phase 2
```

---

## 5. Parallel Planning / Implementation Workflow

The approved working model for the frontend block is:

```text
1. Store all five task files + Build Runner in the repository.
2. Start Codex implementation of FE-001 only because FE-001 is Approved.
3. While Codex implements FE-001, ChatGPT performs read-only review of FE-002.
4. If FE-002 review finds issues:
      fix the task contract;
      keep it Draft until findings are resolved.
5. When FE-002 passes review:
      change FE-002 to Approved;
      deliver the planning update to main.
6. When FE-001 is Accepted / Delivered:
      Codex may start FE-002 only if synchronized main shows FE-002 Approved.
7. Repeat the same pattern for FE-003, FE-004, FE-005.
```

This parallelizes:

```text
ChatGPT task-contract review
```

with:

```text
Codex implementation of the already Approved preceding task
```

It does **not** parallelize implementation tasks.

Codex still implements one task at a time.

---

## 6. FE-001 Current Gate

`S04-FE-001` has completed the additional review/fix cycle and is the only current implementation-authorized frontend task.

State:

```text
S04-FE-001:
Status = Approved
Implementation = Not started
Gate = OPEN
```

Scope remains:

```text
Institution Group Navigation and List only
```

No create/detail/edit/archive/membership behavior is authorized in FE-001.

---

## 7. FE-002…005 Review Gate

Current state:

```text
S04-FE-002 = Draft / Review pending
S04-FE-003 = Draft / Review pending
S04-FE-004 = Draft / Review pending
S04-FE-005 = Draft / Review pending
```

These files may be committed to `main` now for review continuity.

They must not be given to Codex for implementation until each has separately passed ChatGPT read-only review and has been changed to:

```text
Status = Approved
```

A later review may modify requirements inside that task file before approval.

---

## 8. Build Runner Status

File:

```text
tasks/frontend/stage-04/S04-FE-BUILD-RUNNER.md
```

The Build Runner is orchestration only, not a sixth frontend implementation task.

It is approval-gated:

```text
Approved task -> may execute
Draft task    -> stop WAITING FOR TASK APPROVAL
```

Therefore it is safe to store before FE-002…005 review completes.

The runner:

- works one implementation task at a time;
- re-synchronizes `main` before each task;
- reads only the active Approved task body;
- does not implement a Draft future task;
- stops on `WAITING FOR TASK APPROVAL`, `BLOCKED`, or `DELIVERY BLOCKED`;
- does not run Frontend Phase 2;
- does not run Stage integration/closure.

---

## 9. Per-Task Acceptance

An implementation task becomes `Accepted / Delivered` only when:

```text
approved contract satisfied
focused tests PASS
required directly affected regressions PASS
static/format checks PASS
git diff --check PASS
focused scope/diff self-review PASS
focused GitHub delivery complete
result present on origin/main
local main == origin/main
ahead/behind = 0/0
working tree clean
```

No task-level Phase 2 is performed.

---

## 10. Verification Policy

Each FE implementation task runs only verification proportional to its contract:

```text
focused functionality tests
necessary static/format checks
directly affected regressions
git diff --check
focused scope/diff self-check
```

Do not run after every task:

```text
full frontend suite
full Windows build
broad E2E
Frontend Phase 2
```

unless the active contract explicitly requires broader verification for a concrete risk.

---

## 11. Frontend Phase 2

Frontend Phase 2 remains blocked until:

```text
FE-001 Accepted / Delivered
FE-002 Accepted / Delivered
FE-003 Accepted / Delivered
FE-004 Accepted / Delivered
FE-005 Accepted / Delivered

local main == origin/main
ahead/behind = 0/0
working tree clean
```

Then ChatGPT performs the Stage 4 frontend block read-only review, including:

```text
complete Stage 4 frontend diff
full frontend test suite
static analysis
format checks
required Windows build
frontend architecture
API/DTO integration
session/routing/state ownership
stale async safety
mutation uncertainty handling
accessibility/focus/responsiveness
cross-task interactions
regression risk
```

Checkpoint result:

```text
PASS
NOT ACCEPTED
```

---

## 12. Integration and Closure

Integration planning is not authorized until:

```text
Backend Phase 2 PASS
Frontend Phase 2 PASS
```

Backend gate is already satisfied.

Remaining gate:

```text
Frontend Phase 2 PASS
```

Only after that may ChatGPT decompose/create the Stage 4 integration task.

Stage 4 closes only after:

```text
frontend block
→ Frontend Phase 2 PASS
→ integration
→ required fixes
→ Stage Closure Review PASS
```

---

## 13. Current Progress

| Item | State |
|---|---|
| Backend implementation | `Complete` |
| Backend Phase 2 | `PASS` |
| `S04-FE-001` | `Approved / Ready to start` |
| `S04-FE-002` | `Draft / Review pending` |
| `S04-FE-003` | `Draft / Review pending` |
| `S04-FE-004` | `Draft / Review pending` |
| `S04-FE-005` | `Draft / Review pending` |
| Build Runner | `Prepared / approval-gated` |
| Frontend Phase 2 | `Pending` |
| Integration | `Blocked until Frontend Phase 2 PASS` |
| Stage Closure | `Pending` |

---

## 14. Next Permitted Gate

Next implementation gate:

```text
S04-FE-001 — Institution Group Navigation and List
```

Next planning/review work may proceed concurrently:

```text
S04-FE-002 read-only contract review
```

Safe execution sequence:

```text
Commit/store the complete frontend planning package on main
→ verify main sync/clean
→ start FE-001 implementation
→ concurrently review/fix FE-002
→ approve FE-002 only after review PASS
→ continue sequentially
```
