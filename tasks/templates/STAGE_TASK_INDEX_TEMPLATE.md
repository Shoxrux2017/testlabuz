# Stage [Number] Task Index — [Stage Name]

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `[Stage number and exact name]` |
| Stage status | `Draft` |
| Verification model | `Workflow v3 — Lean Verification` |
| Decomposition approved on | `[date / Not approved]` |
| Implementation started | `No` |
| Backend checkpoint | `[Not started / PASS / NOT ACCEPTED / N/A]` |
| Frontend checkpoint | `[Not started / PASS / NOT ACCEPTED / N/A]` |
| Integration gate | `[Not started / PASS / NOT ACCEPTED / N/A]` |
| Stage closed | `No` |

Valid Stage statuses: `Draft`, `Approved`, `In Progress`, `Blocked`, `Closed`.

---

## 2. Stage Goal and Boundary

### Goal

[Approved roadmap Stage outcome.]

### Included

- [scope]
- [scope]

### Excluded

- [future Stage behavior]
- [post-MVP/non-goal]
- [unapproved refactor/infrastructure]

---

## 3. Authoritative Planning Inputs

| Source | Reference | Why it governs |
|---|---|---|
| `docs/06-roadmap.md` | `[Stage section]` | scope/acceptance/DoD |
| relevant locked docs | `[sections]` | product/role/business rules |
| `docs/07-architecture.md` | `[section]` | architecture |
| `docs/08-database.md` | `[section]` | persistence |
| `docs/09-api-contracts.md` | `[section]` | API |
| `AGENTS.md` + nested rules | `[section]` | engineering/safety |
| current `origin/main` | `[SHA]` | implementation baseline |
| previous Stage closure | `[reference]` | dependency |

These are ChatGPT planning inputs. Codex does not reopen them to derive task
requirements.

---

## 4. Entry Gate

Before Stage becomes Approved:

- [ ] previous Stage closed;
- [ ] current synchronized clean `main`;
- [ ] relevant locked docs reviewed by ChatGPT;
- [ ] relevant implementation/tests inspected;
- [ ] dependencies available;
- [ ] decomposition/order approved;
- [ ] backend/frontend/integration boundaries explicit;
- [ ] roadmap criteria mapped;
- [ ] no unresolved design/security/tenant/lifecycle/concurrency/UX decision.

---

## 5. Approved Task Order

| Order | Task ID | Area | Outcome | Depends on | Task status | Delivery status | Contract |
|---:|---|---|---|---|---|---|---|
| 1 | `[S00-BE-001]` | Backend | `[outcome]` | `None` | `Draft` | `Not started` | `[path]` |
| 2 | `[S00-FE-001]` | Frontend | `[outcome]` | `[checkpoint/task]` | `Draft` | `Not started` | `[path]` |
| 3 | `[S00-INT-001]` | Integration | `[outcome]` | `[checkpoints]` | `Draft` | `Not started` | `[path]` |

Detailed contracts are prepared/hardened in execution order.

---

## 6. Implementation Readiness Tracking

| Task | Scope/non-goals | Behavior/API/UI | Persistence/lifecycle | Auth/tenant | Errors/concurrency | Tests/verification | Ready |
|---|---|---|---|---|---|---|---|
| `[ID]` | `[Y/N]` | `[Y/N/N/A]` | `[Y/N/N/A]` | `[Y/N/N/A]` | `[Y/N/N/A]` | `[Y/N]` | `[Y/N]` |

For the current task confirm exact scope, behavior, persistence, auth/tenant,
errors/edge cases, concurrency/idempotency/stale async, acceptance criteria,
focused tests, verification commands, and delivery mode.

---

## 7. Dependency and Checkpoint Map

| Dependency/checkpoint | Required before | Evidence |
|---|---|---|
| Backend block complete | Backend Phase 2 | `[Accepted IDs]` |
| Backend Phase 2 PASS | Frontend block when required | `[review+SHA]` |
| Frontend block complete | Frontend Phase 2 | `[Accepted IDs]` |
| Frontend Phase 2 PASS | Integration | `[review+SHA]` |
| Integration PASS | Closure | `[evidence]` |

---

## 8. Per-Task Verification Map

| Task | Focused tests | Static/format | Direct regression | Task executor | Delivery owner | `git diff --check` |
|---|---|---|---|---|---|---|
| `[ID]` | `[command]` | `[command]` | `[command/None]` | `Codex` | `Project Owner` | `Required` |

Per-task Codex verification is focused only.

Full suites/builds/broad E2E are checkpoint/integration work unless a concrete
task-specific risk explicitly justifies broader verification.

---

## 9. Backend Phase 2

| Field | Value |
|---|---|
| Review file | `[path]` |
| Audited SHA | `[SHA]` |
| Verification executor | `Project Owner` |
| Verdict | `[Not started / PASS / NOT ACCEPTED / N/A]` |
| Findings | `[P1/P2/P3]` |

Required initial evidence:

- complete backend read-only review;
- full backend suite;
- required format/static checks;
- architecture/API/database/tenant/security review;
- cross-task/regression review.

After a finding/fix, rerun only invalidated checkpoint evidence; any previously
failing required command must pass.

---

## 10. Frontend Phase 2

| Field | Value |
|---|---|
| Review file | `[path]` |
| Audited SHA | `[SHA]` |
| Verification executor | `Project Owner` |
| Verdict | `[Not started / PASS / NOT ACCEPTED / N/A]` |
| Findings | `[P1/P2/P3]` |

Required initial evidence:

- complete frontend read-only review;
- full frontend suite;
- analyze;
- format;
- required target build;
- architecture/API/session/state/accessibility/regression review.

After a focused fix, preserve still-valid evidence and rerun only invalidated
surfaces.

---

## 11. Integration Gate

| Field | Value |
|---|---|
| Integration task(s) | `[IDs]` |
| Verification reference | `[path]` |
| Automated execution owner | `Project Owner` |
| Manual smoke owner | `Project Owner` |
| Verdict | `[Not started / PASS / NOT ACCEPTED / N/A]` |

Required evidence where applicable:

- real backend/frontend contract;
- auth/session;
- role/active state;
- direct-ID/cross-tenant denial;
- lifecycle;
- persistence;
- routing/state/reconciliation;
- target platform;
- manual smoke;
- findings fixed and affected integration rerun.

Reuse fresh checkpoint evidence; do not rerun full suites merely for integration.

---

## 12. Roadmap Acceptance Matrix

| Criterion | Implementing task(s) | Verification owner | Evidence | Status |
|---|---|---|---|---|
| `[criterion]` | `[IDs]` | `[Task/Phase2/Integration/Closure]` | `[reference]` | `Not started` |

Every required criterion must pass before closure.

---

## 13. Evidence Validity Notes

| Change | Evidence considered | Valid? | Required rerun |
|---|---|---|---|
| `[change]` | `[suite/build/E2E/etc.]` | `[Yes/No]` | `[None/command]` |

Use `tasks/README.md` Section 13A.

---

## 14. Risks and Stop Conditions

Stop affected work when:

- contract not ready;
- locked requirements conflict;
- auth/tenant safety unresolved;
- dependency missing;
- scope expansion required;
- Git state unsafe;
- required verification fails;
- unresolved P1/P2 remains.

---

## 15. Closure Readiness

- [ ] every task Accepted / Delivered;
- [ ] Backend Phase 2 PASS/N/A;
- [ ] Frontend Phase 2 PASS/N/A;
- [ ] Integration PASS/N/A;
- [ ] roadmap criteria pass;
- [ ] required security/tenant checks pass;
- [ ] checkpoint/integration evidence current and valid;
- [ ] manual smoke PASS where required;
- [ ] no unresolved P1/P2;
- [ ] accepted result on `origin/main`;
- [ ] local main synchronized `0/0` and clean;
- [ ] Stage Closure Review passes;
- [ ] Stage explicitly marked Closed.
