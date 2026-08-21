# Stage 4 Task Index — Groups and User Relationships

## 1. Stage Metadata

| Field | Value |
|---|---|
| Stage | `Stage 4 — Groups and User Relationships` |
| Stage dependency | `Stage 3 closed` |
| Backend implementation | `S04-BE-001…005 Accepted / Delivered` |
| Complete Backend Phase 2 | `PASS` |
| Frontend decomposition | `Approved — 5 implementation tasks` |
| Frontend contracts | `S04-FE-001…005 Approved / Review complete` |
| Frontend implementation | `S04-FE-001…004 Accepted / Delivered; S04-FE-005 In Progress` |
| Frontend Phase 2 contract | `Prepared — entry gate pending S04-FE-005 delivery` |
| Frontend Phase 2 verdict | `Pending` |
| Integration | `Blocked until Frontend Phase 2 PASS` |
| Stage closure | `Pending` |

This is the shared Stage 4 orchestration/status map.

Codex must not read this file to determine implementation behavior. The active Approved implementation contract or read-only review contract is self-contained.

---

## 2. Backend Gate

```text
S04-BE-001…005:
Accepted / Delivered

Complete Stage 4 Backend Phase 2:
PASS
P1 = 0
P2 = 0
P3 = 0

Recorded complete-backend checkpoint main:
2e9dab8cfeb8a1caed4cc71c361a1f4812a1ce61

Full backend suite:
293 passed
17,306 assertions

git diff --check:
PASS
```

Backend does not block frontend or Frontend Phase 2.

---

## 3. Frontend Implementation Queue

| Order | Task | Title | Dependency | Contract | Implementation |
|---:|---|---|---|---|---|
| 1 | `S04-FE-001` | Institution Group Navigation and List | Backend Phase 2 PASS | `Approved` | `Accepted / Delivered` |
| 2 | `S04-FE-002` | Institution Group Create and Detail | FE-001 delivered | `Approved` | `Accepted / Delivered` |
| 3 | `S04-FE-003` | Institution Group Edit and Archive Lifecycle | FE-002 delivered | `Approved` | `Accepted / Delivered` |
| 4 | `S04-FE-004` | Teacher and Student Group Membership Management | FE-003 delivered | `Approved` | `Accepted / Delivered` |
| 5 | `S04-FE-005` | Parent–Student Relationship Management | FE-004 delivered | `Approved` | `In Progress` |

Exact implementation chain:

```text
Backend Phase 2 PASS
  ↓
FE-001 Accepted / Delivered
  ↓
FE-002 Accepted / Delivered
  ↓
FE-003 Accepted / Delivered
  ↓
FE-004 Accepted / Delivered
  ↓
FE-005 Approved / In Progress
  ↓ Accepted / Delivered
Frontend Phase 2
```

No additional frontend implementation task is currently planned.

---

## 4. Frontend Delivery Evidence

### S04-FE-001

```text
PR #89
merge:
698b611677522071b6dae547c997c3f1a503d19e
```

### S04-FE-002

```text
PR #90
merge:
d330d693c02a9a8bed043e5628989bbe56979ccf
```

### S04-FE-003

```text
PR #91
merge:
b4e23fc8f230f64b1a7a1160ce93bee904f2d631
```

### S04-FE-004

```text
PR #92
merge:
0c1ecd80ac3cbb9db1e60582c08ab51dbebb2147
```

### S04-FE-005

```text
Contract:
Approved / Review Complete

Dependency:
S04-FE-004 Accepted / Delivered

Implementation:
In Progress

Delivery:
Pending
```

The Runner and Phase 2 review must recover actual delivery evidence from synchronized `origin/main`; this index is orchestration context, not implementation proof.

---

## 5. Stage 4 Frontend Baseline

The frontend implementation baseline is:

```text
1bc138a29250f575bc000c4be3e22d72f5b68e55
```

This is the first parent of the S04-FE-001 merge and contains the approved planning package immediately before Stage 4 frontend production implementation began.

Frontend Phase 2 reviews:

```text
baseline
  ->
final origin/main after S04-FE-005 delivery
```

for the complete `frontend/` delta.

---

## 6. Frontend Build Runner

File:

```text
tasks/frontend/stage-04/S04-FE-BUILD-RUNNER.md
```

The Runner:

- executes one Approved implementation task at a time;
- recovers actual delivery from `origin/main`;
- performs focused per-task verification and delivery;
- does not run Frontend Phase 2;
- stops after FE-005 delivery with:

```text
STAGE 4 FRONTEND IMPLEMENTATION BLOCK COMPLETE
READY FOR CHATGPT FRONTEND PHASE 2
```

The Runner must not begin integration or closure.

---

## 7. Frontend Phase 2 Contract

Prepared file:

```text
tasks/frontend/stage-04/S04-FE-PHASE-2-frontend-block-review.md
```

Current status:

```text
Prepared
Review mode = Read-only
Entry gate pending S04-FE-005 Accepted / Delivered
Verdict = Pending
```

Phase 2 begins only after:

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

---

## 8. Frontend Phase 2 Required Verification

The checkpoint includes:

```text
complete Stage 4 frontend diff review
full frontend test suite
Flutter static analysis
Dart format check
required Windows debug build
route/shell review
API/DTO/error/transport review
session/tenant/stale-async review
cache/invalidation review
mutation uncertainty/reconciliation review
accessibility/keyboard/focus/responsiveness review
cross-task and previous-Stage regression review
```

Verdict:

```text
PASS
NOT ACCEPTED
```

PASS requires:

```text
P1 = 0
P2 = 0
full frontend suite PASS
static analysis PASS
format check PASS
Windows build PASS
no unresolved cross-task/frontend architecture conflict
```

The checkpoint is read-only. Findings are not fixed inside the review.

---

## 9. Fix Flow After Frontend Phase 2

If:

```text
NOT ACCEPTED
```

then:

```text
record findings
→ ChatGPT prepares focused fix contract(s)
→ Codex implements/verifies/delivers fixes
→ rerun affected Frontend Phase 2 checks
→ obtain PASS
```

Stage integration remains blocked until Frontend Phase 2 PASS.

---

## 10. Integration Gate

Integration planning is authorized only after:

```text
Backend Phase 2 PASS
Frontend Phase 2 PASS
```

Backend gate is already satisfied.

Remaining gate:

```text
Frontend Phase 2 PASS
```

Only then may ChatGPT prepare Stage 4 integration task(s) for:

```text
real Laravel–Flutter stack
authentication/session
Institution Admin role
tenant isolation/existence privacy
Groups
Group lifecycle
Teacher/Student memberships
Parent–Student relationships
API/DTO/error agreement
required Windows/E2E/security verification
```

---

## 11. Stage Closure Gate

Stage 4 closes only after:

```text
all implementation delivered
Backend Phase 2 PASS
Frontend Phase 2 PASS
integration PASS
required fixes delivered
Stage Closure Review PASS
final main synchronized and clean
```

Completion of FE-005 alone does not close Stage 4.

---

## 12. Current Progress

| Item | State |
|---|---|
| Backend implementation | `Complete` |
| Backend Phase 2 | `PASS` |
| `S04-FE-001` | `Accepted / Delivered` |
| `S04-FE-002` | `Accepted / Delivered` |
| `S04-FE-003` | `Accepted / Delivered` |
| `S04-FE-004` | `Accepted / Delivered` |
| `S04-FE-005` | `Approved / In Progress` |
| Frontend contract review | `Complete — all five Approved` |
| Frontend implementation block | `Pending FE-005 delivery` |
| Frontend Phase 2 contract | `Prepared` |
| Frontend Phase 2 | `Entry gate pending` |
| Integration | `Blocked until Frontend Phase 2 PASS` |
| Stage Closure | `Pending` |

---

## 13. Next Permitted Gates

Current implementation gate:

```text
Complete S04-FE-005 implementation, focused verification, and delivery
```

Then:

```text
verify final main sync/clean
→ execute S04-FE-PHASE-2-frontend-block-review.md
→ ChatGPT verdict PASS or NOT ACCEPTED
```

Do not begin Stage 4 integration planning before Frontend Phase 2 PASS.
