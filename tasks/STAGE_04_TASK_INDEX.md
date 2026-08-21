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
| Integration | `S04-INT-001 Approved / Not started` |
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

Integration planning/decomposition is now authorized because:

```text
Backend Phase 2 PASS
Frontend Phase 2 PASS
```

The next Stage 4 work must be an explicit integration task covering, where applicable:

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
required Windows/E2E/security verification
manual smoke evidence where required
```

Integration implementation/verification must be completed and accepted before Stage Closure Review.

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
Implementation = Not started
Automated integration = Pending
Project Owner manual smoke = Pending
```

Verification policy:

```text
Reuse fresh Backend/Frontend Phase 2 PASS evidence.
Do not rerun full backend/frontend suites, full analyze/format, standalone build,
or previous-Stage broad E2E merely for integration.
Run only focused integration-asset checks + one Stage 4 real-stack runner.
```

After automated integration assets are delivered:

```text
Project Owner manual smoke
→ ChatGPT final integration verdict
→ Stage Closure Review
```

---

## 12. Stage Closure Gate

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
| Integration | `S04-INT-001 Approved / Not started` |
| Stage Closure | `Pending` |

---

## 14. Next Permitted Gate

```text
S04-INT-001 implementation / automated real-stack verification
```

Safe sequence:

```text
S04-INT-001 Approved
→ implement focused E2E assets + run Stage 4 real-stack verification
→ fix/reverify integration findings if any
→ deliver automated integration assets/evidence
→ Project Owner manual smoke PASS
→ ChatGPT integration PASS
→ Stage Closure Review
```

Do not declare Stage 4 closed before integration and closure gates pass.
