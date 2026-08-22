# Stage [Number] Task Index — [Stage Name]

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `[Stage number and exact roadmap name]` |
| Stage status | `Draft` |
| Verification model | `Workflow v3 — Lean Verification` |
| Decomposition approved on | `[YYYY-MM-DD or Not approved]` |
| Implementation started | `No` |
| Backend checkpoint | `[Not started / PASS / NOT ACCEPTED / N/A]` |
| Frontend checkpoint | `[Not started / PASS / NOT ACCEPTED / N/A]` |
| Integration gate | `[Not started / PASS / NOT ACCEPTED / N/A]` |
| Stage closed | `No` |

Valid Stage statuses:

- `Draft` — Stage is being analysed or decomposed;
- `Approved` — decomposition and entry gate are approved;
- `In Progress` — implementation/checkpoint/integration work has started;
- `Blocked` — a required decision, dependency, or safety condition is unresolved;
- `Closed` — Stage Closure Review passed and final delivery is complete.

This index is the authoritative implementation map for the Stage. It organizes
approved work but does not create or change product behavior.

---

## 2. Stage Goal and Boundary

### Goal

[Copy or closely summarize the approved roadmap Stage outcome.]

### Included Stage Boundary

- [Approved Stage outcome]
- [Approved role/workflow/API/UI/persistence boundary]
- [Required Stage-level verification outcome]

### Excluded Stage Boundary

- [Adjacent future Stage behavior]
- [Post-MVP behavior]
- [Refactor, platform, role, integration, or infrastructure work not included]

Any scope change requires explicit planning approval and an index update. Do not
silently broaden an implementation task.

---

## 3. Authoritative Planning Inputs

ChatGPT prepares and reviews this Stage using:

| Source | Exact section/reference | Why it governs the Stage |
|---|---|---|
| `docs/06-roadmap.md` | `[Stage section]` | Stage scope, dependencies, acceptance criteria, Definition of Done |
| `[docs/0X-name.md]` | `[Exact section]` | `[Resolved business/role/workflow rule]` |
| `[docs/07-architecture.md]` | `[Exact section]` | `[Resolved architecture boundary]` |
| `[docs/08-database.md]` | `[Exact section]` | `[Resolved persistence requirement]` |
| `[docs/09-api-contracts.md]` | `[Exact section]` | `[Resolved API behavior]` |
| `AGENTS.md` and applicable nested `AGENTS.md` | `[Relevant rule]` | Engineering and repository-safety constraints |
| Current `origin/main` | `[Commit SHA]` | Authoritative implementation baseline |
| Previous Stage closure | `[Review/commit/PR]` | Entry dependency |

These sources are planning and review inputs for ChatGPT.

Codex receives the current approved implementation contract and must not open
these sources to rediscover or reinterpret task requirements.

---

## 4. Entry Gate

Before the Stage becomes `Approved`:

- [ ] Previous Stage is explicitly closed.
- [ ] Current `origin/main` is verified.
- [ ] Local `main` matches `origin/main`.
- [ ] Relevant product, architecture, database, and API contracts were reviewed
      by ChatGPT.
- [ ] Relevant current implementation and tests were inspected.
- [ ] Stage dependencies are available.
- [ ] Stage decomposition and task order were discussed and approved.
- [ ] Backend/frontend/integration boundaries are explicit.
- [ ] Every roadmap acceptance criterion is mapped.
- [ ] No unresolved product, architecture, API, database, security,
      tenant-isolation, lifecycle, concurrency, idempotency, or UX decision
      blocks the first task.

If a required entry condition fails, keep the Stage `Draft` or mark it
`Blocked`. Do not begin implementation.

---

## 5. Approved Task Order

Implementation normally proceeds one task at a time in dependency order.

| Order | Task ID | Area | Short outcome | Depends on | Task status | Delivery status | Contract file |
|---:|---|---|---|---|---|---|---|
| 1 | `[S00-BE-001]` | Backend | `[One focused outcome]` | `None` | `Draft` | `Not started` | `[path or Not created]` |
| 2 | `[S00-BE-002]` | Backend | `[One focused outcome]` | `[Task ID]` | `Draft` | `Not started` | `[path or Not created]` |
| 3 | `[S00-FE-001]` | Frontend | `[One focused outcome]` | `[Task/checkpoint]` | `Draft` | `Not started` | `[path or Not created]` |
| 4 | `[S00-INT-001]` | Integration | `[One cross-layer outcome]` | `[Tasks/checkpoints]` | `Draft` | `Not started` | `[path or Not created]` |

Task and delivery status meanings are defined in `tasks/README.md`.

Do not add a per-task Phase 2 review column for Stage 5+.

The Stage index may list future tasks before their detailed contracts exist.
Detailed implementation contracts should be prepared or hardened in execution
order. Do not create unnecessary task files or duplicated `CODEX-PROMPT` files
for the whole Stage in advance.

---

## 6. Implementation Readiness Tracking

A task becomes `Approved` only when its implementation contract passes the
Implementation Readiness Gate.

| Task ID | Scope/non-goals | Behavior/API/UI | Persistence/lifecycle | Auth/tenant/security | Errors/edge/concurrency | Tests/verification | Ready |
|---|---|---|---|---|---|---|---|
| `[Task ID]` | `[Yes/No/N/A]` | `[Yes/No/N/A]` | `[Yes/No/N/A]` | `[Yes/No/N/A]` | `[Yes/No/N/A]` | `[Yes/No]` | `[Yes/No]` |

For the current task, confirm:

- [ ] one observable goal is defined;
- [ ] included scope and explicit non-goals are complete;
- [ ] current implementation context is accurate;
- [ ] exact behavior and state transitions are resolved;
- [ ] API/UI contract is resolved where applicable;
- [ ] persistence/schema behavior is resolved where applicable;
- [ ] authorization and tenant isolation are explicit;
- [ ] validation and error semantics are explicit;
- [ ] edge cases are explicit;
- [ ] concurrency/idempotency/stale-async behavior is explicit where relevant;
- [ ] acceptance criteria are objective;
- [ ] focused tests and exact task-level verification commands are defined;
- [ ] directly affected regression scope is explicit or justified `None`;
- [ ] normal task verification is assigned to Codex as focused verification only;
- [ ] delivery owner is explicit; `Project Owner` is the Stage 5+ default;
- [ ] allowed bookkeeping is explicit;
- [ ] Codex does not need to make a product or architecture decision.

---

## 7. Dependency and Checkpoint Map

| Dependency or checkpoint | Required before | Evidence when satisfied |
|---|---|---|
| `[Migration/API/shared infrastructure]` | `[Task ID]` | `[Task/commit/test]` |
| Backend task block complete | Backend Phase 2 | `[Accepted task IDs]` |
| Backend Phase 2 `PASS` | Frontend block, when required | `[Review file + audited SHA]` |
| Frontend task block complete | Frontend Phase 2 | `[Accepted task IDs]` |
| Frontend Phase 2 `PASS` | Integration gate | `[Review file + audited SHA]` |
| Integration gate `PASS` | Stage Closure Review | `[Integration evidence]` |

Do not hide a cross-layer dependency inside an unrelated backend or frontend
task.

A Stage without a backend or frontend block may mark the corresponding
checkpoint `N/A` only with a clear Stage-specific reason.

---

## 8. Per-Task Verification Map

Each task contract defines proportional verification.

| Task ID | Focused tests | Static/format checks | Direct regression | Manual check | Task verification executor | Delivery owner | `git diff --check` |
|---|---|---|---|---|---|---|---|
| `[Task ID]` | `[Command/reference]` | `[Command/reference]` | `[Command or justified None]` | `[Steps or N/A]` | `Codex` | `Project Owner` | `Required` |

Per-task verification normally includes:

- focused tests for changed behavior;
- required formatter/linter/static checks;
- directly affected regression tests when justified;
- `git diff --check`;
- focused scope/diff self-check.

Full backend/frontend suites, full builds, broad E2E, and Phase 2 reviews are
checkpoint/integration work and are executed by the Project Owner or approved
CI by default. A task contract may require broader Codex verification only for
a concrete task-specific regression risk.

---

## 9. Backend Phase 2 Checkpoint

Run after all approved backend Stage tasks are `Accepted` and delivered.

| Field | Value |
|---|---|
| Review file | `[tasks/.../STAGE_<NN>_BACKEND_BLOCK_REVIEW.md]` |
| Audited `origin/main` | `[SHA]` |
| Review date | `[YYYY-MM-DD]` |
| Verification executor | `Project Owner` |
| Verdict | `[Not started / PASS / NOT ACCEPTED / N/A]` |
| Findings | `[P1/P2/P3 counts or N/A]` |

Required checkpoint evidence:

- [ ] complete backend Stage scope reviewed read-only;
- [ ] full backend regression suite passed;
- [ ] required backend format/static checks passed;
- [ ] architecture and responsibility boundaries reviewed;
- [ ] API and error contracts are consistent;
- [ ] migrations/schema/constraints/indexes/queries are coherent;
- [ ] transactions/concurrency/idempotency/lifecycle rules compose correctly;
- [ ] authorization and tenant isolation reviewed;
- [ ] cross-tenant/existence-privacy behavior verified;
- [ ] cross-task interactions reviewed;
- [ ] prior Stage regression risk reviewed;
- [ ] `P1 = 0`;
- [ ] `P2 = 0`.

If `NOT ACCEPTED`:

1. ChatGPT prepares focused fix contract(s);
2. Codex implements and runs only focused task-level verification for the fix;
3. the Project Owner performs routine Git/GitHub delivery by default;
4. ChatGPT decides which prior PASS checkpoint evidence remains valid;
5. Project Owner/CI reruns only the materially invalidated backend checkpoint
   checks, while every previously failing required command must eventually pass;
6. obtain `PASS` before frontend implementation continues.

---

## 10. Frontend Phase 2 Checkpoint

Run after:

- backend checkpoint `PASS`, when the Stage has a backend block;
- all approved frontend Stage tasks are `Accepted` and delivered.

| Field | Value |
|---|---|
| Review file | `[tasks/.../STAGE_<NN>_FRONTEND_BLOCK_REVIEW.md]` |
| Audited `origin/main` | `[SHA]` |
| Review date | `[YYYY-MM-DD]` |
| Verification executor | `Project Owner` |
| Verdict | `[Not started / PASS / NOT ACCEPTED / N/A]` |
| Findings | `[P1/P2/P3 counts or N/A]` |

Required checkpoint evidence:

- [ ] complete frontend Stage scope reviewed read-only;
- [ ] full frontend test suite passed;
- [ ] static analysis and format checks passed;
- [ ] required target build passed;
- [ ] frontend feature/layer boundaries reviewed;
- [ ] API/DTO/error integration reviewed;
- [ ] auth/session/routing/state behavior reviewed;
- [ ] stale async completion safety reviewed;
- [ ] loading/error/empty/success/mutation states reviewed;
- [ ] cache/invalidation behavior reviewed;
- [ ] backend-authoritative rule boundary preserved;
- [ ] accessibility/focus/keyboard/responsiveness reviewed where required;
- [ ] cross-task interactions reviewed;
- [ ] prior Stage regression risk reviewed;
- [ ] `P1 = 0`;
- [ ] `P2 = 0`.

If `NOT ACCEPTED`:

1. ChatGPT prepares focused fix contract(s);
2. Codex implements and runs only focused task-level verification for the fix;
3. the Project Owner performs routine Git/GitHub delivery by default;
4. ChatGPT decides which prior PASS checkpoint evidence remains valid;
5. Project Owner/CI reruns only the materially invalidated frontend checkpoint
   checks, while every previously failing required command must eventually pass;
6. obtain `PASS` before integration begins.

---

## 11. Integration Gate

Run only after all required block checkpoints are `PASS`.

| Field | Value |
|---|---|
| Integration task(s) | `[Task IDs]` |
| Verification reference | `[File/command/evidence]` |
| Audited `origin/main` | `[SHA]` |
| Automated execution owner | `Project Owner` |
| Manual smoke owner | `Project Owner` |
| Verdict | `[Not started / PASS / NOT ACCEPTED / N/A]` |


Fresh Backend/Frontend Phase 2 PASS evidence is reused. Do not rerun full
backend/frontend suites or standalone builds merely because integration starts.

Codex is used for missing/focused integration assets or focused production fixes
only. Project Owner/CI executes the real-stack runner by default, and the
Project Owner performs the required user-facing manual smoke.

Required integration evidence:

- [ ] backend and frontend use the real agreed contract;
- [ ] real-stack/E2E workflow passes;
- [ ] authentication/session behavior passes;
- [ ] role and active-state behavior passes;
- [ ] direct-ID and cross-tenant denial passes;
- [ ] lifecycle/state progression passes;
- [ ] persistence effects match the contract;
- [ ] routing/state/error reconciliation passes;
- [ ] required platform/build target works;
- [ ] required manual smoke path passes;
- [ ] integration findings are fixed and re-verified;
- [ ] accepted integration result is delivered to `origin/main`.

---

## 11A. Evidence Validity and Minimum Rerun Tracking

Fresh PASS evidence remains valid until a later change materially affects the
surface that evidence proved.

ChatGPT determines validity and the minimum sufficient rerun scope using
`tasks/README.md` Section `12A`.

Record only changes that could affect existing verification evidence:

| Later change | Evidence considered | Still valid? | Required rerun / reason |
|---|---|---|---|
| `[Change/commit/PR]` | `[Backend Phase 2 / Frontend Phase 2 / build / E2E / smoke]` | `[Yes/No]` | `[None / exact affected check]` |

Default expectations:

- docs/bookkeeping-only changes do not invalidate product verification;
- isolated test-only strengthening/cleanup does not invalidate production
  evidence;
- a narrow production fix preserves unrelated PASS evidence;
- shared auth/session/router/client/middleware/error changes may require a
  broader affected checkpoint rerun;
- public API/schema/migration/authorization/tenant/security changes normally
  invalidate the corresponding checkpoint/integration surface;
- dependency/platform/build-system changes normally invalidate relevant
  static/build evidence;
- a required command that previously failed must eventually pass.

Do not rerun by habit, and do not preserve evidence that a later change
materially invalidated.

---

## 12. Roadmap Acceptance Matrix

Map every roadmap Stage acceptance criterion.

| Roadmap criterion | Implementing task(s) | Verification gate/owner | Evidence | Status |
|---|---|---|---|---|
| `[Exact criterion]` | `[Task IDs]` | `[Task / Backend checkpoint / Frontend checkpoint / Integration / Closure]` | `[Reference]` | `Not started` |

A criterion with no implementation owner or verification owner is a
decomposition gap.

Every required criterion must pass before Stage closure.

---

## 13. Stage Risks and Stop Conditions

| Risk or stop condition | Affected task/checkpoint | Mitigation or required decision | Status |
|---|---|---|---|
| `[Risk]` | `[Task/checkpoint]` | `[Mitigation]` | `[Open/Resolved]` |

Stop affected work when:

- the implementation contract is not ready;
- a locked product/architecture/API/database rule conflicts;
- safe authorization or tenant isolation is unresolved;
- a required dependency is missing;
- implementation requires material scope expansion;
- Git/repository state is unsafe;
- a required task/checkpoint/integration verification fails;
- a P1 or P2 finding remains unresolved.

Codex reports implementation-contract gaps. ChatGPT resolves planning and design
decisions before work resumes.

---

## 14. Change Log

| Date | Change | Reason | Approved by |
|---|---|---|---|
| `[YYYY-MM-DD]` | `[Decomposition/order/scope/checkpoint update]` | `[Reason]` | `[Project owner]` |

Task order, scope, dependencies, or acceptance mapping must not change silently.

---

## 15. Closure Readiness

- [ ] Every approved task is `Accepted`.
- [ ] Every accepted task is delivered to `origin/main`.
- [ ] Backend Phase 2 checkpoint is `PASS` or justified `N/A`.
- [ ] Frontend Phase 2 checkpoint is `PASS` or justified `N/A`.
- [ ] Integration gate is `PASS` or justified `N/A`.
- [ ] All roadmap acceptance criteria are satisfied.
- [ ] Required security and tenant-isolation checks pass.
- [ ] Required full suites/static checks/builds/E2E/smoke evidence is current
      and valid under the evidence-validity policy.
- [ ] No unresolved P1 or P2 finding remains.
- [ ] No blocking regression affects earlier Stages.
- [ ] Relevant task, checkpoint, integration, and documentation state is current.
- [ ] Complete accepted Stage result is on `origin/main`.
- [ ] Local `main == origin/main`.
- [ ] Ahead/behind is `0/0`.
- [ ] Working tree is clean.
- [ ] Stage Closure Review is completed.
- [ ] Stage is explicitly marked `Closed`.

The next Stage may enter planning/decomposition only after this Stage is
explicitly closed.
