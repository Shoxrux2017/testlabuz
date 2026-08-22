# TestLabUz Implementation Workflow — v3 Lean Verification

This directory stores Stage indexes, implementation contracts, checkpoint
reviews, integration evidence, and Stage closure records for the locked
TestLabUz MVP.

This workflow applies to **Stage 5 and later**.

Historical Stage 0–4 task, review, verification, delivery, and closure evidence
remains valid and must not be rewritten retroactively to match v3.

---

## 1. Responsibility Model

```text
ChatGPT       = requirements, architecture, task design, minimum verification
                scope, read-only review, findings, acceptance, Stage closure
Codex         = implementation + task-level focused verification
Project Owner = default checkpoint/integration/manual-smoke verification
                executor + Git/GitHub delivery executor
CI            = checkpoint/integration verification executor when configured
```

GitHub `main` / `origin/main` is the authoritative project state.

### 1.1 ChatGPT owns

- requirements engineering;
- product/business/lifecycle decisions;
- software architecture and system design;
- API and database design;
- authorization, security, tenant isolation, existence privacy;
- concurrency/idempotency decisions;
- Stage decomposition and task order;
- implementation-readiness decisions;
- acceptance criteria and test strategy;
- the **minimum sufficient per-task verification scope**;
- evidence-validity and rerun decisions;
- backend/frontend Phase 2 reviews;
- integration review;
- Stage Closure Review;
- final task/checkpoint/Stage verdicts.

Before a state-sensitive decision, ChatGPT re-checks current GitHub state and
the relevant source/tests instead of relying only on previous chat memory.

### 1.2 Codex owns

Codex implements one approved, self-contained contract at a time and performs
only the focused task verification explicitly defined in that contract.

Codex may inspect only:

1. the current approved implementation contract;
2. root `AGENTS.md`;
3. applicable nested `backend/AGENTS.md` and/or `frontend/AGENTS.md`;
4. source code, tests, migrations, configuration, and infrastructure directly
   required by the assigned change;
5. immediately related implementation patterns needed for consistency.

Codex must not read product docs, roadmap, previous task files, Stage history,
checkpoint reviews, or closure files to decide what to build.

Codex must not make product, architecture, public API, database, security,
tenant, lifecycle, concurrency, idempotency, or unresolved UX decisions.

### 1.3 Project Owner / CI own heavy verification

Codex does **not** run full backend/frontend suites, full builds, broad E2E, or
checkpoint/closure verification merely to complete a task.

Project Owner/CI executes those heavier checks at the approved Stage checkpoint
or integration gate.

Git/GitHub delivery is Project Owner-owned by default.

---

## 2. Directory Structure

```text
tasks/
  README.md
  STAGE_<NN>_TASK_INDEX.md
  STAGE_<NN>_CLOSURE_REVIEW.md

  templates/
    CODEX_TASK_TEMPLATE.md
    BLOCK_REVIEW_TEMPLATE.md
    STAGE_TASK_INDEX_TEMPLATE.md
    STAGE_CLOSURE_REVIEW_TEMPLATE.md

  backend/stage-<NN>/
  frontend/stage-<NN>/
  integration/stage-<NN>/
```

Do not create duplicate large `CODEX-PROMPT` files. One implementation contract
is the task-specific source of truth.

---

## 3. Stage Planning and Decomposition

Before implementation begins:

1. verify the previous Stage is explicitly closed;
2. verify current `origin/main`;
3. read the relevant locked `docs/01–09`;
4. inspect applicable current source/tests;
5. resolve architecture, API/database, lifecycle, security, tenant, concurrency,
   error, and cross-layer decisions;
6. propose Stage decomposition and dependency order;
7. obtain Project Owner approval;
8. record the approved map in `STAGE_<NN>_TASK_INDEX.md`.

Implementation normally proceeds one task at a time.

Future tasks may be listed in the Stage index before their detailed contracts
exist. Detailed contracts should be prepared/hardened in execution order.

---

## 4. Implementation Readiness Gate

A task may become `Approved` only when its contract resolves every relevant:

- goal;
- included scope;
- non-goals;
- current implementation context;
- business behavior;
- API/UI behavior;
- persistence/schema behavior;
- lifecycle/state transitions;
- validation/normalization;
- authorization and tenant isolation;
- error behavior;
- edge cases;
- concurrency/transactions/locking/idempotency;
- acceptance criteria;
- focused tests;
- exact task-level verification commands;
- directly affected regression scope;
- delivery owner;
- allowed files/areas.

Codex must not need to make a design or product decision.

If such a decision remains unresolved, the task stays `Draft` or becomes
`Blocked`.

---

## 5. Task Lifecycle

| Status | Meaning |
|---|---|
| `Draft` | Contract is not implementation-ready |
| `Approved` | Contract is complete and implementation may start |
| `In Progress` | Implementation / focused verification / delivery is active |
| `Accepted` | Contract satisfied, focused verification passed, approved delivery completed, result is on `origin/main`, local `main` synchronized and clean |
| `Blocked` | A design/dependency/environment/safety decision blocks progress |
| `Delivery Blocked` | Implementation + focused verification passed, but required delivery could not complete safely |

Codex may report implementation completion, but ChatGPT assigns task
`Accepted` only after required delivery evidence is complete.

---

## 6. Lean Per-Task Workflow

```text
A. Git Preflight
B. Codex Implementation
C. Codex Focused Verification
D. Codex Scope/Diff Self-Check
E. Project Owner GitHub Delivery
F. ChatGPT Task Acceptance
```

### 6.1 A — Git Preflight

Before implementation:

- local `main` is clean;
- fetch `origin`;
- local `main == origin/main`;
- ahead/behind is `0/0`;
- `origin` is the expected TestLabUz repository;
- preserve unrelated user work/untracked files;
- create one focused task branch when needed.

Never use destructive cleanup to force a clean state.

### 6.2 B — Codex Implementation

Codex:

- changes only approved scope;
- follows root/nested `AGENTS.md`;
- adds/updates focused tests required by the contract;
- does not perform unrelated refactors;
- does not perform Git delivery by default.

### 6.3 C — Codex Focused Verification

The contract defines the minimum sufficient verification.

After each implementation task, Codex runs only:

- focused tests for changed behavior;
- necessary formatter/linter/static checks;
- directly affected regression tests when justified;
- `git diff --check`.

Additional narrow diagnostics/reruns are allowed only to understand a concrete
failure.

Do **not** run:

```text
full backend suite
full frontend suite
full build
broad E2E
Phase 2
```

unless ChatGPT explicitly requires a broader check for a concrete task-specific
regression risk.

### 6.4 D — Codex Scope/Diff Self-Check

Before reporting completion, Codex verifies:

- every changed file is necessary;
- implementation matches the contract;
- non-goals remain excluded;
- no unrelated refactor/format churn;
- no unintended API/schema/route/serialization change;
- authorization and tenant boundaries remain intact;
- no test was weakened to hide a defect;
- no debug code, secrets, generated junk, or temporary artifacts remain.

### 6.5 E — Project Owner GitHub Delivery

Default executor:

```text
Project Owner
```

Normal manual delivery:

1. stage only task-owned files;
2. `git diff --cached --check`;
3. focused commit;
4. push task branch;
5. PR to `main`;
6. merge after required checks;
7. resync local `main`;
8. verify local `main == origin/main`;
9. verify ahead/behind `0/0`;
10. verify clean worktree.

Codex performs delivery only when explicitly assigned by the contract.

### 6.6 F — Task Acceptance

ChatGPT assigns `Accepted` only after:

- contract is satisfied;
- focused verification passed;
- `git diff --check` passed;
- no blocking scope/security/tenant finding remains;
- required delivery completed;
- accepted result is on `origin/main`;
- local `main` is synchronized and clean.

There is no per-task Phase 2 review.

---

## 7. Verification Economy Rules

Per-task verification must be proportional.

Prefer:

```text
changed behavior tests
+ necessary static/format
+ directly affected regression
+ git diff --check
```

Avoid:

```text
full suites
full builds
broad E2E
unrelated regression areas
```

until their Stage checkpoint.

ChatGPT explicitly names any broader task-level check only when a concrete risk
justifies it.

---

## 8. Backend Phase 2 Checkpoint

Run only after all approved backend tasks are Accepted / Delivered.

### Ownership

```text
ChatGPT       = read-only backend review + findings + verdict
Project Owner = default full-suite/static verification executor
CI            = allowed verification executor
Codex         = not used merely to collect Phase 2 evidence
```

Required checkpoint scope includes:

- current `origin/main`;
- complete backend Stage delta;
- full backend regression suite;
- required backend format/static checks;
- architecture/responsibility boundaries;
- API/error contracts;
- persistence/migrations/constraints/indexes/query behavior;
- transactions/concurrency/idempotency/lifecycle;
- authorization/tenant isolation/existence privacy;
- cross-task interactions;
- previous-Stage regression risk;
- complete diff/scope review.

Verdict:

```text
PASS
NOT ACCEPTED
```

If a finding requires code changes, ChatGPT prepares a focused fix contract.
Codex implements + runs the focused fix verification only. Project Owner/CI
runs any checkpoint rerun that ChatGPT determines was invalidated.

---

## 9. Frontend Phase 2 Checkpoint

Run only after:

- Backend Phase 2 is `PASS` when required;
- all approved frontend tasks are Accepted / Delivered.

### Ownership

```text
ChatGPT       = read-only frontend review + findings + verdict
Project Owner = default full-suite/analyze/format/build executor
CI            = allowed verification executor
Codex         = not used merely to collect Phase 2 evidence
```

Required checkpoint scope includes:

- current `origin/main`;
- complete frontend Stage delta;
- full frontend test suite;
- static analysis;
- format check;
- required target build;
- architecture/layer placement;
- API/DTO/error integration;
- auth/session/router/state;
- stale async ownership;
- loading/error/empty/data/mutation states;
- cache ownership/invalidation;
- accessibility/focus/keyboard/responsiveness where required;
- backend-authoritative rule boundaries;
- cross-task interactions;
- previous-Stage regression risk;
- complete diff/scope review.

After a focused fix, rerun only verification surfaces invalidated by that fix,
except that any previously failing required checkpoint command must eventually
pass.

---

## 10. Finding Severity

| Severity | Meaning |
|---|---|
| `P1` | Security, tenant isolation, secret exposure, data loss/corruption, or core public-contract breach |
| `P2` | Material functional, architecture, lifecycle, integration, regression, or required-verification defect |
| `P3` | Non-blocking maintainability, clarity, or test-quality improvement |

P3 does not automatically expand Stage scope.

---

## 11. Integration Gate

Integration begins only after required block checkpoints are `PASS`.

### Ownership

```text
ChatGPT       = integration design/review + acceptance
Codex         = creates/fixes only missing integration assets/code when needed
Project Owner = default real-stack runner + manual smoke executor
CI            = may execute deterministic integration automation
```

Integration verifies where applicable:

- real backend/frontend agreement;
- API/DTO/error contracts;
- authentication/session;
- roles/active-state;
- direct-ID and cross-tenant denial;
- lifecycle/state progression;
- persistence effects;
- routing/state/reconciliation;
- required target platform;
- Project Owner manual smoke.

Reuse fresh Backend/Frontend Phase 2 evidence. Do not rerun full suites/builds
inside integration merely because integration started.

If integration finds a production defect:

1. record the finding;
2. prepare focused fix contract;
3. Codex edits + runs focused fix verification only;
4. Project Owner/CI reruns the integration path required to establish the
   complete final scenario.

---

## 12. Stage Closure Review

Closure begins only after:

- all approved tasks Accepted / Delivered;
- required Phase 2 checkpoints `PASS`;
- integration `PASS` or justified `N/A`;
- required fixes delivered;
- required manual smoke `PASS`;
- current `origin/main` contains complete accepted Stage result.

ChatGPT performs closure review.

Codex is **not** used for closure evidence collection by default.

Project Owner/CI runs an additional command only when ChatGPT determines that
existing evidence is missing or invalidated.

Closure verdicts:

```text
STAGE CLOSED
FIXES REQUIRED BEFORE CLOSURE
CLOSURE BLOCKED
```

---

## 13A. Evidence Validity and Rerun Policy

Fresh PASS evidence remains valid until a later change materially affects the
surface that evidence proved.

ChatGPT decides validity and minimum rerun scope.

| Later change | Broad evidence effect |
|---|---|
| Docs/bookkeeping-only | Does not invalidate product verification |
| Comment/rename-only, no behavior change | Normally no broad invalidation |
| Isolated test-only strengthening/cleanup | Production evidence remains valid; run affected tests/static checks as needed |
| Narrow production fix in one feature | Preserve unrelated checkpoint evidence; run focused affected verification + affected integration path |
| Shared router/session/client/middleware/error/auth infrastructure | May invalidate corresponding checkpoint; ChatGPT decides |
| Public API/schema/migration/authorization/tenant/security change | Normally invalidates corresponding checkpoint/integration surface |
| Dependency/platform/build-system change | Normally invalidates relevant static/build/checkpoint evidence |
| Required command previously failed | That command must eventually pass after correction |
| Real-stack scenario failed before later phases ran | Rerun enough integration to prove the complete final scenario |

Rules:

- do not rerun by habit;
- do not skip a rerun when evidence is materially invalidated;
- evidence age alone is not sufficient reason to rerun if the proven surface is
  unchanged;
- docs-only merges do not invalidate prior product verification;
- focused fixes do not automatically force every suite/build/E2E;
- security/tenant/API/schema changes receive conservative rerun treatment.

---

## 14. Git and Repository Safety

Never:

- force-push shared history;
- rewrite `main`;
- bypass checks with `--no-verify`;
- silently replace an unexpected `origin`;
- modify global Git configuration;
- use destructive reset/clean as normal workflow;
- overwrite/stage unrelated user work;
- commit passwords, tokens, credentials, private keys, certificates, or local
  secret/environment files.

---

## 15. Templates

| Template | Purpose |
|---|---|
| `CODEX_TASK_TEMPLATE.md` | Compact implementation + focused-verification contract |
| `BLOCK_REVIEW_TEMPLATE.md` | Backend/Frontend Phase 2 read-only review |
| `STAGE_TASK_INDEX_TEMPLATE.md` | Stage dependency/readiness/verification map |
| `STAGE_CLOSURE_REVIEW_TEMPLATE.md` | Final Stage closure review |

---

## 16. Historical Compatibility

Do not rewrite Stage 0–4 task/review/delivery/closure evidence to match v3.

v3 governs Stage 5+ work.

---

## 17. Current Project State

| Stage | Status | Next permitted gate |
|---|---|---|
| Stage 0 — Project Preparation and Technical Planning | `Closed` | Historical |
| Stage 1 — Authentication and Role-Based Entry | `Closed` | Historical |
| Stage 2 — Multi-Institution Platform Management | `Closed` | Historical |
| Stage 3 — Institution Administration and User Management | `Closed` | Historical |
| Stage 4 — Groups and User Relationships | `Closed` | Stable dependency for Stage 5 |
| Stage 5 — Topics and Learning Materials | `Not started` | Stage 5 planning/decomposition |

---

## Core Principle

> ChatGPT designs the solution and minimum verification contract. Codex writes
> code/tests and runs only the focused task verification. Project Owner/CI owns
> heavy checkpoint/integration execution and Git delivery by default. Reduce
> duplicated context and execution, never architecture quality, security,
> tenant isolation, acceptance criteria, or final Stage assurance.
