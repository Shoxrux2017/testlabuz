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
| Frontend implementation | `S04-FE-001…005 Accepted / Delivered — complete` |
| Frontend Phase 2 contract | `Complete` |
| Frontend Phase 2 verdict | `PASS — P1=0, P2=0, P3=1` |
| Integration | `S04-INT-001 Accepted / Delivered — PASS` |
| Stage closure | `Closed — PASS` |

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
| 5 | `S04-FE-005` | Parent–Student Relationship Management | FE-004 delivered | `Approved` | `Accepted / Delivered` |

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
FE-005 Accepted / Delivered
  ↓
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
Accepted / Delivered
PR #93
merge:
314afd43da521ddbfd486309fb3a7199e6479e29
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

## 7. Frontend Phase 2

Review file:

```text
tasks/frontend/stage-04/S04-FE-PHASE-2-frontend-block-review.md
```

Official result:

```text
PASS
P1 = 0
P2 = 0
P3 = 1
```

Final audited main:

```text
c2adec99344b86f18684974295df19011651a9b6
```

Verification:

```text
full frontend suite:
991 passed

flutter analyze:
PASS

format check:
PASS

Windows debug build:
PASS

git diff --check:
PASS
```

One blocking checkpoint regression-test compatibility finding was corrected through:

```text
PR #94
merge:
360c16ab29e192431c2c81f4ab20d6cd67c30a31

final cleanup:
c2adec99344b86f18684974295df19011651a9b6
```

The remaining P3 debounce-test timing observation is non-blocking and does not expand Stage 4 scope.

---

## 9. Frontend Phase 2 Fix History

The checkpoint initially identified one P2 regression-test compatibility issue.

It was corrected and reverified. No blocking Frontend Phase 2 finding remains.

Current checkpoint state:

```text
PASS
P1 = 0
P2 = 0
P3 = 1
```

---

## 10. Integration Gate

Integration has been completed and accepted.

Required entry checkpoints were satisfied:

```text
Backend Phase 2 PASS
Frontend Phase 2 PASS
```

S04-INT-001 verified the Stage 4 scope through the real stack:

```text
real Laravel–Flutter stack
authentication/session
Institution Admin role
tenant isolation/existence privacy
Groups
Group create/detail/edit/archive
Teacher/Student memberships
Parent–Student relationships
API/DTO/error agreement
Windows mutation E2E
database postconditions
backend restart
Windows persistence E2E
foreign/unrelated data preservation
Project Owner manual smoke
```

Final integration result:

```text
AUTOMATED INTEGRATION PASS
PROJECT OWNER MANUAL SMOKE PASS
S04-INT-001 ACCEPTED / DELIVERED
```

The production presentation defects discovered during the first integration attempt were fixed separately in PR #95 and merged as:

```text
3d62def08093507edf21ec9747537e1f4a524ac3
```

The integration assets and final PASS evidence were delivered in PR #96 and merged as:

```text
d9eb303719a1c6de5d161f905de9892596a91ae3
```

Integration no longer blocks Stage Closure Review.

---

## 11. Stage 4 Integration Task

Approved task:

```text
S04-INT-001 — Stage 4 Windows Real-Stack E2E Verification
```

Contract:

```text
tasks/integration/stage-04/S04-INT-001-stage-04-windows-real-stack-e2e-verification.md
```

Status:

```text
Approved
Implementation = Accepted / Delivered
Automated integration = PASS
Project Owner manual smoke = PASS
Final verdict = ACCEPTED
```

Verification policy:

```text
Reuse fresh Backend/Frontend Phase 2 PASS evidence.
Do not rerun full backend/frontend suites, full analyze/format, standalone build,
or previous-Stage broad E2E merely for integration.
Run only focused integration-asset checks + one Stage 4 real-stack runner.
```

Delivered integration evidence:

```text
tasks/integration/stage-04/S04-INT-001-stage-04-e2e-evidence.md
```

Current gate transition:

```text
S04-INT-001 Accepted / Delivered
→ Stage Closure Review
```

---

## 12. Stage Closure Gate

Stage 4 closure requirements are satisfied:

```text
all implementation delivered
Backend Phase 2 PASS
Frontend Phase 2 PASS
integration PASS
required fixes delivered
Project Owner manual smoke PASS
Stage Closure Review PASS
pre-closure main synchronized and clean
```

Closure review:

```text
tasks/STAGE_04_CLOSURE_REVIEW.md
audited pre-closure baseline:
68a73a6253b81f9f8ee1ac0401e0ca12d7ce7fbb
verdict:
STAGE CLOSED
```

The closure/bookkeeping delivery changes documentation only and does not alter
production behavior.

---

## 13. Current Progress

| Item | State |
|---|---|
| Backend implementation | `Complete` |
| Backend Phase 2 | `PASS` |
| `S04-FE-001` | `Accepted / Delivered` |
| `S04-FE-002` | `Accepted / Delivered` |
| `S04-FE-003` | `Accepted / Delivered` |
| `S04-FE-004` | `Accepted / Delivered` |
| `S04-FE-005` | `Accepted / Delivered` |
| Frontend contract review | `Complete — all five Approved` |
| Frontend implementation block | `Complete` |
| Frontend Phase 2 contract | `Complete` |
| Frontend Phase 2 | `PASS — P1=0, P2=0, P3=1` |
| Integration | `S04-INT-001 Accepted / Delivered — PASS` |
| Stage Closure | `Closed — PASS` |

---

## 14. Next Permitted Gate

Stage 4 is closed.

Before Stage 5 planning/decomposition, the project workflow may be aligned to
the approved lean-verification direction without changing Stage 4 historical
evidence.

```text
Stage 4 Closed
→ Workflow v3 — Lean Verification alignment
→ Stage 5 planning/decomposition
```

Stage 5 implementation is not authorized until its own decomposition,
implementation-readiness gates, and approved task contracts are in place.
