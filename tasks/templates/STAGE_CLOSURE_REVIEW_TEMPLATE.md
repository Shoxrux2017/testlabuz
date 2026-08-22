# Stage [Number] Closure Review — [Stage Name]

## 1. Closure Metadata

| Field | Value |
|---|---|
| Stage | `[Stage number and exact name]` |
| Review mode | `Read-only` |
| Review date | `[YYYY-MM-DD]` |
| Stage index | `[path]` |
| Audited `origin/main` | `[SHA]` |
| Local `main` | `[SHA]` |
| Ahead/behind | `[0/0]` |
| Working tree | `[Clean]` |
| Proposed verdict | `[Pending]` |

ChatGPT owns closure analysis, acceptance mapping, evidence-validity decisions,
findings, and verdict.

Codex is **not** used to collect closure evidence by default.

If additional command execution is genuinely required, Project Owner/CI runs
the exact command selected by ChatGPT.

---

## 2. Closure Entry Conditions

| Condition | Result | Evidence |
|---|---|---|
| Previous Stage closed | `[Pass/N/A/Fail]` | `[Reference]` |
| Stage decomposition approved | `[Pass/Fail]` | `[Index]` |
| Every approved task Accepted / Delivered | `[Pass/Fail]` | `[IDs/PRs]` |
| Backend Phase 2 PASS/N/A | `[Pass/N/A/Fail]` | `[Review]` |
| Frontend Phase 2 PASS/N/A | `[Pass/N/A/Fail]` | `[Review]` |
| Integration PASS/N/A | `[Pass/N/A/Fail]` | `[Evidence]` |
| Required fixes delivered | `[Pass/N/A/Fail]` | `[References]` |
| Required manual smoke PASS/N/A | `[Pass/N/A/Fail]` | `[Evidence]` |
| Complete accepted Stage on origin/main | `[Pass/Fail]` | `[SHA]` |
| Local main synchronized and clean | `[Pass/Fail]` | `[Git evidence]` |

Any failed required entry condition blocks closure.

---

## 3. Authoritative Review Inputs

ChatGPT reviews current GitHub state, applicable `AGENTS.md`, `tasks/README.md`,
relevant locked `docs/01–09`, Stage index/contracts, implementation/tests,
checkpoint evidence, integration/E2E/manual-smoke evidence, delivery evidence,
and current bookkeeping.

---

## 4. Scope and Delivery Audit

| Check | Result | Evidence |
|---|---|---|
| Complete approved Stage scope present | `[Pass/Fail]` | `[Evidence]` |
| No approved task missing | `[Pass/Fail]` | `[Evidence]` |
| No hidden/unapproved feature entered | `[Pass/Fail]` | `[Evidence]` |
| Non-goals remain excluded | `[Pass/Fail]` | `[Evidence]` |
| No locked behavior changed without approval | `[Pass/Fail]` | `[Evidence]` |
| Backend/frontend/integration records agree | `[Pass/Fail/N/A]` | `[Evidence]` |
| No temporary workaround/placeholder remains | `[Pass/Fail]` | `[Evidence]` |
| Dependency/platform/lock changes justified | `[Pass/Fail/N/A]` | `[Evidence]` |

---

## 5. Roadmap Acceptance Matrix

| Criterion | Result | Implementation evidence | Verification evidence |
|---|---|---|---|
| `[Exact criterion]` | `[Pass/Fail]` | `[IDs/files]` | `[checks/integration/smoke]` |

Every required criterion must pass.

---

## 6. Stage Definition of Done

| Condition | Result | Evidence |
|---|---|---|
| Approved business behavior implemented | `[Pass/Fail]` | `[Evidence]` |
| Backend/API behavior works | `[Pass/Fail/N/A]` | `[Evidence]` |
| Required UI uses real backend data | `[Pass/Fail/N/A]` | `[Evidence]` |
| No core-path placeholder | `[Pass/Fail/N/A]` | `[Evidence]` |
| Server authorization enforced | `[Pass/Fail/N/A]` | `[Evidence]` |
| Tenant isolation correct | `[Pass/Fail/N/A]` | `[Evidence]` |
| Validation/error behavior matches | `[Pass/Fail/N/A]` | `[Evidence]` |
| Required checkpoints passed | `[Pass/Fail/N/A]` | `[Evidence]` |
| Required integration/E2E passed | `[Pass/Fail/N/A]` | `[Evidence]` |
| Required manual smoke passed | `[Pass/Fail/N/A]` | `[Evidence]` |
| No blocking previous-Stage regression | `[Pass/Fail]` | `[Evidence]` |
| Documentation/task status synchronized | `[Pass/Fail]` | `[Evidence]` |
| No unresolved P1/P2 | `[Pass/Fail]` | `[Evidence]` |

---

## 7. Checkpoint Evidence Validity

Closure reuses valid checkpoint evidence.

### Backend

| Field | Value |
|---|---|
| Verdict | `[PASS/N/A]` |
| Audited SHA | `[SHA]` |
| Full regression result | `[Result]` |
| Later change affecting backend? | `[None/description]` |
| Evidence still valid? | `[Yes/No]` |
| Additional rerun | `[None / exact command+result]` |

### Frontend

| Field | Value |
|---|---|
| Verdict | `[PASS/N/A]` |
| Audited SHA | `[SHA]` |
| Tests/analyze/format/build result | `[Result]` |
| Later change affecting frontend? | `[None/description]` |
| Evidence still valid? | `[Yes/No]` |
| Additional rerun | `[None / exact command+result]` |

Rules:

- docs/bookkeeping-only changes do not invalidate product verification;
- test-only strengthening/cleanup normally does not invalidate production
  evidence;
- narrow production fixes invalidate only the affected surface unless shared
  infrastructure changed;
- shared API/schema/auth/security/router/client/platform changes may require
  broader rerun;
- a previously failed required command must eventually pass.

Do not rerun broad suites/builds/E2E during closure without a concrete
invalidation reason.

---

## 8. Complete Working Scenario

| Workflow | Expected | Integration evidence | Result |
|---|---|---|---|
| `[main workflow]` | `[expected]` | `[reference]` | `[Pass/Fail/N/A]` |
| `[lifecycle/error]` | `[expected]` | `[reference]` | `[Pass/Fail/N/A]` |
| `[security/cross-role]` | `[expected]` | `[reference]` | `[Pass/Fail/N/A]` |

---

## 9. Security and Tenant Isolation

| Check | Result | Evidence |
|---|---|---|
| Unauthenticated access denied | `[Pass/N/A/Fail]` | `[Evidence]` |
| Role/active-state enforced | `[Pass/N/A/Fail]` | `[Evidence]` |
| Cross-tenant reads blocked | `[Pass/N/A/Fail]` | `[Evidence]` |
| Cross-tenant writes blocked | `[Pass/N/A/Fail]` | `[Evidence]` |
| Foreign UUID does not grant access | `[Pass/N/A/Fail]` | `[Evidence]` |
| Lists/relationships do not leak | `[Pass/N/A/Fail]` | `[Evidence]` |
| Frontend does not replace backend auth | `[Pass/N/A/Fail]` | `[Evidence]` |
| Sensitive fields/logs/errors/tokens protected | `[Pass/N/A/Fail]` | `[Evidence]` |

Any unresolved security/tenant issue is P1.

---

## 10. Project Owner Manual Smoke

| Scenario | Steps | Expected | Result |
|---|---|---|---|
| `[primary]` | `[steps]` | `[expected]` | `[PASS/FAIL/N/A]` |

Do not repeat manually what automated E2E already proves reliably.

---

## 11. Final Repository State

| Check | Expected | Actual | Result |
|---|---|---|---|
| origin/main | Accepted Stage state | `[SHA]` | `[Pass/Fail]` |
| local main | same SHA | `[SHA]` | `[Pass/Fail]` |
| ahead/behind | `0/0` | `[actual]` | `[Pass/Fail]` |
| working tree | clean | `[actual]` | `[Pass/Fail]` |
| unexpected files | none | `[actual]` | `[Pass/Fail]` |

---

## 12. Findings

| ID | Severity | Finding | Evidence | Blocks closure? | Action |
|---|---|---|---|---|---|
| `[SC-01]` | `[P1/P2/P3]` | `[problem]` | `[evidence]` | `[Yes/No]` | `[action]` |

If none:

```text
No findings.
P1 = 0
P2 = 0
P3 = 0
```

---

## 13. Final Verdict

Choose exactly:

```text
STAGE CLOSED
FIXES REQUIRED BEFORE CLOSURE
CLOSURE BLOCKED
```

`STAGE CLOSED` requires all required entry/roadmap/DoD/checkpoint/integration/
security/manual-smoke conditions to pass with P1=0 and P2=0 on synchronized
clean `main`.

---

## 14. Closure Bookkeeping and Delivery

Only after the read-only verdict permits closure:

1. update Stage index to `Closed`;
2. record final checkpoint/integration/manual-smoke evidence;
3. add/update Stage Closure Review;
4. change only approved bookkeeping docs;
5. `git diff --check`;
6. Project Owner delivers by default;
7. resync `main` and verify `0/0` + clean.

No production code change belongs in closure bookkeeping.
