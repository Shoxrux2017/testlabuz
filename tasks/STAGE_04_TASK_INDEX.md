# Stage 4 Task Index — Groups and User Relationships

## 1. Stage Metadata

| Field | Value |
|---|---|
| Stage | `Stage 4 — Groups and User Relationships` |
| Stage dependency | `Stage 3 closed` |
| Backend implementation | `S04-BE-001…005 Accepted / Delivered` |
| Complete Backend Phase 2 | `PASS` |
| Frontend decomposition | `Approved — 5 implementation tasks` |
| Frontend contracts | `FE-001…005 Approved / Review complete` |
| Frontend implementation | `FE-001…003 Accepted / Delivered; FE-004 next implementation task` |
| Frontend Build Runner | `Prepared — all remaining task approval gates open subject to dependencies` |
| Frontend Phase 2 | `Pending FE-004 and FE-005 delivery` |
| Integration | `Blocked until Frontend Phase 2 PASS` |
| Stage closure | `Pending` |

This is the shared Stage 4 orchestration/status map.

Codex must not read this file to determine implementation behavior. The active Approved task contract is self-contained.

---

## 2. Backend Gate

Stage 4 backend is complete:

```text
S04-BE-001…005 = Accepted / Delivered

Backend Phase 2:
PASS
P1 = 0
P2 = 0
P3 = 0

Recorded checkpoint baseline:
2e9dab8cfeb8a1caed4cc71c361a1f4812a1ce61

Full backend suite:
293 passed
17,306 assertions

git diff --check:
PASS
```

Backend does not block the frontend block.

---

## 3. Frontend Queue

| Order | Task | Title | Dependency | Planning | Implementation |
|---:|---|---|---|---|---|
| 1 | `S04-FE-001` | Institution Group Navigation and List | Backend Phase 2 PASS | `Approved` | `Accepted / Delivered` |
| 2 | `S04-FE-002` | Institution Group Create and Detail | FE-001 delivered | `Approved` | `Accepted / Delivered` |
| 3 | `S04-FE-003` | Institution Group Edit and Archive Lifecycle | FE-002 delivered | `Approved` | `Accepted / Delivered` |
| 4 | `S04-FE-004` | Teacher and Student Group Membership Management | FE-003 delivered | `Approved` | `Ready / next permitted` |
| 5 | `S04-FE-005` | Parent–Student Relationship Management | FE-004 delivered | `Approved` | `Dependency pending` |

Exact chain:

```text
Backend Phase 2 PASS
  ↓
FE-001 Accepted / Delivered
  ↓
FE-002 Accepted / Delivered
  ↓
FE-003 Accepted / Delivered
  ↓
FE-004 Approved / implement next
  ↓ Accepted / Delivered
FE-005 Approved / may continue automatically
  ↓ Accepted / Delivered
Frontend Phase 2
```

All five frontend task contracts have now passed ChatGPT implementation-readiness review.

---

## 4. Verified Frontend Delivery

### S04-FE-001

```text
Accepted / Delivered
PR #89
Merge:
698b611677522071b6dae547c997c3f1a503d19e
```

### S04-FE-002

```text
Accepted / Delivered
PR #90
Merge:
d330d693c02a9a8bed043e5628989bbe56979ccf
```

### S04-FE-003

```text
Accepted / Delivered
PR #91
Merge:
b4e23fc8f230f64b1a7a1160ce93bee904f2d631
```

### S04-FE-004

```text
Status = Approved
Review = Complete
Dependency = FE-003 Accepted / Delivered
Gate = OPEN / next implementation task
```

### S04-FE-005

```text
Status = Approved
Review = Complete
Dependency = FE-004 Accepted / Delivered
Gate = DEPENDENCY PENDING
```

The Runner must recover actual delivery from synchronized `origin/main`; this index is orchestration context, not implementation proof.

---

## 5. Build Runner

File:

```text
tasks/frontend/stage-04/S04-FE-BUILD-RUNNER.md
```

The Runner:

- recovers the first not-yet-delivered task from `origin/main`;
- verifies the immediately preceding dependency is Accepted / Delivered;
- verifies the active task's own `Status = Approved`;
- reads only that active contract body;
- implements one task at a time;
- runs only contract-proportional verification;
- performs focused GitHub delivery;
- re-synchronizes main;
- continues to the next Approved task automatically;
- stops on `WAITING FOR TASK APPROVAL`, `BLOCKED`, or `DELIVERY BLOCKED`;
- does not run Frontend Phase 2, integration, or Stage closure.

Because FE-005 is now Approved, there should be no planning approval stop after FE-004 if the FE-004 implementation is Accepted / Delivered and synchronized `main` contains this planning update.

---

## 6. Per-Task Acceptance

A frontend task is `Accepted / Delivered` only after:

```text
approved contract satisfied
focused tests PASS
directly affected regressions PASS
static/format checks PASS
git diff --check PASS
focused scope/diff self-review PASS
focused PR merged
implementation present on origin/main
local main == origin/main
ahead/behind = 0/0
working tree clean
```

There is no per-task Phase 2 review.

---

## 7. Verification Policy

Each implementation task runs only:

```text
focused functionality tests
necessary directly affected regressions
static/format checks
git diff --check
focused scope/diff self-review
```

Do not run after each task:

```text
full frontend suite
Windows build
broad E2E
Frontend Phase 2
```

unless a specific contract requires broader verification for a concrete shared risk.

---

## 8. Frontend Phase 2 Gate

Blocked until:

```text
FE-001 Accepted / Delivered
FE-002 Accepted / Delivered
FE-003 Accepted / Delivered
FE-004 Accepted / Delivered
FE-005 Accepted / Delivered

main == origin/main
ahead/behind = 0/0
working tree clean
```

Then perform one complete frontend-block Phase 2 read-only review with:

```text
complete Stage 4 frontend diff review
full frontend test suite
static analysis
format checks
required Windows build
routing/session/state architecture
API/DTO/error integration
stale async ownership
mutation uncertainty/reconciliation
cache/invalidation and cross-task interactions
accessibility/focus/responsiveness
regression risk
```

Verdict:

```text
PASS
NOT ACCEPTED
```

Fix findings before Stage integration.

---

## 9. Integration and Closure

Integration planning is authorized only after:

```text
Backend Phase 2 PASS
Frontend Phase 2 PASS
```

Then perform Stage 4 real-stack/E2E/security/tenant integration verification.

Stage closure requires integration/fixes/delivery plus Stage Closure Review PASS.

Completion of FE-001…005 alone does not close Stage 4.

---

## 10. Current Progress

| Item | State |
|---|---|
| Backend implementation | `Complete` |
| Backend Phase 2 | `PASS` |
| `S04-FE-001` | `Accepted / Delivered` |
| `S04-FE-002` | `Accepted / Delivered` |
| `S04-FE-003` | `Accepted / Delivered` |
| `S04-FE-004` | `Approved / Ready` |
| `S04-FE-005` | `Approved / Dependency pending` |
| Frontend contract review | `Complete — all five Approved` |
| Build Runner | `Prepared / approval-gated` |
| Frontend Phase 2 | `Pending` |
| Integration | `Blocked until Frontend Phase 2 PASS` |
| Stage Closure | `Pending` |

---

## 11. Next Gates

Next implementation task:

```text
S04-FE-004 — Teacher and Student Group Membership Management
```

After FE-004 `Accepted / Delivered`, Runner may continue directly to:

```text
S04-FE-005 — Parent–Student Relationship Management
```

No further frontend implementation-contract review remains.

Safe sequence:

```text
FE-004 implementation/delivery
→ FE-005 implementation/delivery
→ final main sync
→ READY FOR CHATGPT FRONTEND PHASE 2
→ Frontend Phase 2
→ integration planning only after Phase 2 PASS
```
