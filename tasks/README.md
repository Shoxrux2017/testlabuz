# TestLabUz Implementation Workflow — v3 Lean Verification

This directory stores Stage indexes, implementation contracts, checkpoint
reviews, integration evidence, and Stage closure records for the locked
TestLabUz MVP.

This workflow applies to **Stage 5 and later**.

Historical Stage 0–4 task, review, verification, delivery, and closure files
remain valid audit evidence. They are not rewritten retroactively to match this
workflow.

---

## 1. Authority and Responsibility

The project uses the following responsibility split:

```text
ChatGPT       = requirements, architecture, task design, minimum verification
                scope, review, evidence-validity decisions, and Stage closure
Codex         = implementation + focused task verification only
Project Owner = routine Git/GitHub delivery, checkpoint verification,
                real-stack execution, and manual smoke by default
CI            = checkpoint/integration verification executor when configured
```

### 1.1 Product and technical authority

The locked MVP product and technical specification remains:

```text
docs/
  01-business-overview.md
  02-user-roles.md
  03-features.md
  04-user-flows.md
  05-business-rules.md
  06-roadmap.md
  07-architecture.md
  08-database.md
  09-api-contracts.md
```

These documents define approved product behavior, roles, workflows, business
rules, Stage scope, architecture, persistence, and API contracts.

### 1.2 ChatGPT responsibility

ChatGPT must read and reconcile the relevant repository inputs before planning
or approving implementation:

- current `origin/main`;
- relevant locked `docs/01–09`;
- roadmap Stage scope and Definition of Done;
- root and applicable nested `AGENTS.md`;
- relevant current implementation and tests;
- current Stage/task status;
- previous closure evidence needed to establish dependencies.

ChatGPT owns:

- requirements engineering;
- software architecture and system design;
- business and lifecycle decisions;
- API and database design;
- authorization, security, and tenant-isolation rules;
- Stage/task decomposition;
- implementation-readiness decisions;
- acceptance criteria and test strategy;
- proportional verification scope;
- evidence-validity and minimum-rerun decisions after later fixes;
- implementation contracts;
- backend/frontend Phase 2 checkpoint reviews;
- integration review;
- Stage Closure Review.

GitHub is the source of truth. ChatGPT must re-check current repository state
when preparing a task, checkpoint review, integration gate, or closure review
instead of relying only on previous chat memory.

### 1.3 Codex responsibility

Codex is primarily an implementation agent.

Codex receives one approved, compact, self-contained implementation contract
and may inspect only:

1. the current approved implementation contract;
2. root `AGENTS.md`;
3. the applicable nested `backend/AGENTS.md` and/or `frontend/AGENTS.md`;
4. source code, tests, migrations, configuration, and infrastructure directly
   required by the assigned change;
5. immediately related implementation patterns required for consistency.

Codex must not read product specifications, roadmap files, architecture or
database/API specification documents, previous task files, Stage history, or
closure reviews to determine what to implement.

Codex must not make product, business, architecture, public API, database,
security, tenant-isolation, lifecycle, concurrency, idempotency, or unresolved
UX decisions.

If the approved implementation contract is materially incomplete or conflicts
with the current implementation or applicable `AGENTS.md`, Codex must report
the exact blocker instead of inventing a reconciliation.

Codex runs only the task-level focused verification explicitly defined by the
approved implementation contract. Full backend/frontend suites, full builds,
broad E2E, Phase 2 evidence collection, and Stage closure verification are not
normal per-task Codex work.

Routine Git/GitHub delivery is owned by the Project Owner by default. Codex may
perform delivery only when the active implementation contract explicitly
assigns that delivery step.

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
    TASK_REVIEW_TEMPLATE.md

  backend/
    stage-<NN>/

  frontend/
    stage-<NN>/

  integration/
    stage-<NN>/
```

### 2.1 Task areas

| Area | Primary ownership |
|---|---|
| `backend/` | Laravel, PostgreSQL, server-side authorization, domain rules, persistence, storage, and backend tests |
| `frontend/` | Flutter data/domain/presentation, routing, state, API integration, accessibility, and frontend tests |
| `integration/` | Laravel–Flutter contract verification, real-stack/E2E workflows, cross-layer security, and tenant verification |

A task belongs to the area that owns its principal change.

Do not silently expand a backend or frontend task into cross-layer integration
work. Cross-layer behavior must be assigned to an explicit integration task or
an explicitly approved shared-infrastructure task.

---

## 3. Naming Convention

Implementation task files use:

```text
S<stage>-<area>-<number>-<short-description>.md
```

Examples:

```text
S04-BE-001-short-description.md
S04-FE-001-short-description.md
S04-INT-001-short-description.md
```

Area codes:

- `BE` — backend;
- `FE` — frontend;
- `INT` — integration.

Checkpoint and closure files should identify the Stage and review boundary
clearly, for example:

```text
STAGE_04_BACKEND_BLOCK_REVIEW.md
STAGE_04_FRONTEND_BLOCK_REVIEW.md
STAGE_04_CLOSURE_REVIEW.md
```

---

## 4. Stage Planning and Decomposition

Before Stage implementation begins:

1. ChatGPT verifies the previous Stage is explicitly closed.
2. ChatGPT verifies current `origin/main`.
3. ChatGPT reads the roadmap Stage scope and relevant locked contracts.
4. ChatGPT inspects the relevant current implementation and tests.
5. ChatGPT resolves architecture, business behavior, API/database behavior,
   security, tenant isolation, lifecycle, and cross-layer dependencies.
6. ChatGPT proposes the Stage task decomposition and implementation order.
7. The project owner reviews and approves the decomposition.
8. The Stage task index records tasks, dependencies, checkpoints, integration,
   and closure mapping.

Implementation normally proceeds one task at a time.

The Stage index may list future tasks and dependencies, but detailed
implementation contracts should be prepared or hardened in execution order.
Do not create unnecessary detailed files for future tasks merely to populate
the entire Stage in advance.

---

## 5. Implementation Readiness Gate

A task may become `Approved` only when ChatGPT has resolved every relevant
implementation decision.

The implementation contract must define, where applicable:

- one clear goal;
- included scope;
- explicit non-goals;
- current implementation context;
- exact business behavior;
- exact API request/response behavior;
- persistence and schema behavior;
- lifecycle and state transitions;
- validation and normalization;
- authorization;
- tenant isolation and existence privacy;
- error behavior;
- edge cases;
- concurrency, transactions, locking, uniqueness, and idempotency;
- acceptance criteria;
- required focused tests;
- required negative/security tests;
- proportional task-level verification commands;
- explicitly justified directly affected regression checks;
- allowed files/areas and scope boundaries;
- delivery owner and delivery expectations;
- required Codex completion evidence.

Codex must not need to choose between competing product, architecture, API,
database, security, lifecycle, or UX behaviors.

If such a decision remains unresolved, the task stays `Draft` or becomes
`Blocked`.

---

## 6. Implementation Contract Rules

Each implementation task is the complete task-specific contract given to
Codex.

It must be compact and self-contained. It should include only the context and
requirements Codex needs to implement and verify the assigned change.

Do not create a second large `CODEX-PROMPT` file that duplicates the detailed
task.

Product-document references may be retained as provenance for ChatGPT and
review, but Codex must not be instructed to open those documents to discover
implementation behavior.

The implementation contract must not delegate product, architecture, API,
database, security, tenant, lifecycle, concurrency, idempotency, or unresolved
UX decisions to Codex.

---

## 7. Task Lifecycle

Stage 5+ implementation tasks use these statuses:

| Status | Meaning |
|---|---|
| `Draft` | Proposed task; implementation-readiness gate has not passed |
| `Approved` | Complete implementation contract approved and ready for Codex |
| `In Progress` | Codex is implementing or verifying the task |
| `Accepted` | Contract satisfied, required focused verification passed, approved delivery completed, accepted result is on `origin/main`, and local `main` is synchronized and clean |
| `Blocked` | Implementation cannot safely continue without a planning, dependency, environment, or contract decision |
| `Delivery Blocked` | Implementation and required verification passed, but safe GitHub delivery could not be completed |

Delivery tracking may use:

| Delivery status | Meaning |
|---|---|
| `Not started` | No GitHub delivery started |
| `Delivered` | Accepted result is present on `origin/main` |
| `Blocked` | Safe delivery could not complete |
| `Not applicable` | Delivery does not apply to the item |

`Accepted` is a **task-level implementation and delivery state**.

It does not mean that the complete backend or frontend Stage block has passed
Phase 2. A later block review may identify a cross-task defect in already
accepted work. That defect must be corrected through a focused fix, and the
affected checkpoint must be re-verified.

---

## 8. Per-Task Implementation Workflow

Each normal implementation task follows:

```text
A. Git Preflight
B. Implementation
C. Focused Verification
D. Scope/Diff Self-Check
E. GitHub Delivery
F. Task Acceptance
```

There is no individual Phase 2 Read-Only Review after every Stage 5+ task.

### 8.1 A — Git Preflight

Before editing:

1. verify the task status is `Approved`;
2. verify required dependencies are accepted and delivered;
3. verify local `main` is clean;
4. fetch and verify local `main == origin/main`;
5. verify `origin` is the expected repository;
6. create one focused task branch from current `main`;
7. inspect and preserve pre-existing user work and untracked files;
8. stop if safe isolation would require force-push, history rewrite,
   destructive cleanup, or bypassing checks.

### 8.2 B — Implementation

Codex:

- implements only the approved contract;
- follows root and applicable nested `AGENTS.md`;
- inspects only directly relevant source code and tests;
- adds or updates focused tests required by the contract;
- preserves explicit non-goals;
- avoids unrelated refactoring, formatting churn, speculative infrastructure,
  dependency changes, generated output, or documentation changes.

### 8.3 C — Focused Verification

ChatGPT defines the minimum sufficient task verification in the implementation
contract.

After each task, Codex must run only:

- focused tests for changed functionality;
- necessary formatter/linter/static checks;
- specifically named directly affected regression tests when justified;
- `git diff --check`.

Additional narrow diagnostic commands or focused reruns are allowed when needed
to understand a concrete failure.

Do not independently run full backend/frontend suites, full builds, broad E2E,
Phase 2 verification, or unrelated regression areas unless the contract
explicitly requires broader task-level verification for a concrete regression
risk.

If implementation reveals that shared infrastructure was necessarily changed
outside the contract's verification assumptions, Codex must report the mismatch
or material regression risk rather than silently expanding verification.

### 8.4 D — Scope/Diff Self-Check

Before delivery, Codex inspects the complete diff and verifies:

- every changed file is necessary;
- implementation matches the contract;
- acceptance criteria have evidence;
- non-goals remain excluded;
- no unrelated refactor or formatting churn exists;
- no public API/schema/route/serialization behavior changed unintentionally;
- authorization and tenant boundaries remain intact;
- no test was weakened to hide a defect;
- no debug code, secrets, generated junk, or temporary artifacts are included;
- existing user work remains untouched.

### 8.5 E — GitHub Delivery

For Stage 5+ routine delivery is owned by the Project Owner by default.

Codex performs Git/GitHub delivery only when the current implementation
contract explicitly assigns that responsibility to Codex.

Normal Project Owner delivery:

1. stage only task-owned files;
2. run staged diff and secret/safety checks required by the contract;
3. create one focused commit;
4. push the task branch;
5. open or update a Pull Request to `main`;
6. merge only when required checks pass and merge is permitted;
7. fetch and resynchronize local `main`;
8. verify local `main == origin/main`;
9. verify ahead/behind is `0/0`;
10. verify the working tree is clean.

If Codex was explicitly assigned delivery and safe delivery cannot complete,
use `Delivery Blocked` and stop.

When delivery is Project Owner-owned, Codex stops after focused verification
and scope/diff self-check and reports the Git state needed for handoff.

### 8.6 F — Task Acceptance

A task becomes `Accepted` only after:

- its implementation contract is satisfied;
- required focused verification passes;
- `git diff --check` passes;
- focused scope/diff self-check passes;
- approved delivery completes;
- accepted result is on `origin/main`;
- local `main` matches `origin/main`;
- the working tree is clean.

No per-task Phase 2 verdict is required for Stage 5+ task acceptance.

---

## 9. Backend Phase 2 Checkpoint

Run the backend Phase 2 checkpoint only after all approved backend Stage tasks
are accepted and delivered.

Phase 2 is a read-only block review of the complete backend Stage scope.

ChatGPT owns the review scope, architecture/security analysis, findings,
evidence-validity decisions, and final verdict.

Project Owner or approved CI executes the required Phase 2 verification
commands. Codex is not used merely to run the full suite or collect checkpoint
evidence.

Codex is used only if the checkpoint identifies a focused implementation defect
that requires code changes. The resulting fix receives its own compact
implementation contract and focused verification scope.

The backend checkpoint must include:

- current `origin/main` verification;
- complete backend Stage-scope review;
- full backend regression suite;
- required backend format/static checks;
- architecture and responsibility-boundary review;
- API contract consistency;
- persistence, migrations, constraints, indexes, and query behavior;
- transactions, concurrency, idempotency, and lifecycle behavior where
  relevant;
- authorization and tenant isolation;
- existence privacy and cross-tenant negative behavior;
- cross-task interactions;
- regression risk to previous Stages;
- complete diff/scope review of the backend block.

During the read-only review:

- do not edit implementation files;
- do not fix findings;
- do not stage, commit, push, or merge review-time changes.

Checkpoint verdicts:

- `PASS`;
- `NOT ACCEPTED`.

`PASS` requires:

- no P1 findings;
- no P2 findings;
- required full backend verification passes;
- no unresolved architecture, API, database, security, tenant, lifecycle, or
  cross-task conflict.

If the verdict is `NOT ACCEPTED`:

1. record findings by severity;
2. ChatGPT creates one or more focused fix contracts;
3. Codex implements and focused-verifies only the approved fix scope;
4. Project Owner/CI reruns only the backend checkpoint evidence materially
   invalidated by the fix, while every previously failing required command must
   eventually pass;
5. obtain `PASS` before frontend implementation proceeds.

---

## 10. Frontend Phase 2 Checkpoint

Run the frontend Phase 2 checkpoint only after:

- the backend checkpoint is `PASS`, when the Stage has a backend block;
- all approved frontend Stage tasks are accepted and delivered.

Phase 2 is a read-only block review of the complete frontend Stage scope.

ChatGPT owns the review scope, architecture/API/state analysis, findings,
evidence-validity decisions, and final verdict.

Project Owner or approved CI executes the required frontend Phase 2 commands,
including the full suite, static/format checks, and required target build.

Codex is not used merely to collect checkpoint evidence. Codex is used only
when Phase 2 identifies a focused implementation defect that requires code.

The frontend checkpoint must include:

- current `origin/main` verification;
- complete frontend Stage-scope review;
- full frontend test suite;
- required static analysis and format checks;
- required target build;
- feature/module/layer responsibility review;
- API, DTO, error, and transport integration;
- authentication/session/routing/state handling;
- stale async completion safety;
- loading/error/empty/success and mutation states;
- cache ownership and invalidation;
- accessibility, keyboard, focus, responsiveness, and overflow behavior where
  required;
- backend-authoritative rule boundaries;
- cross-task interactions;
- regression risk to previous Stages;
- complete diff/scope review of the frontend block.

During the read-only review:

- do not edit implementation files;
- do not fix findings;
- do not stage, commit, push, or merge review-time changes.

Checkpoint verdicts:

- `PASS`;
- `NOT ACCEPTED`.

`PASS` requires:

- no P1 findings;
- no P2 findings;
- required full frontend tests/static checks/build pass;
- no unresolved architecture, API integration, session, routing, state, or
  cross-task conflict.

If the verdict is `NOT ACCEPTED`:

1. record findings by severity;
2. ChatGPT creates one or more focused fix contracts;
3. Codex implements and focused-verifies only the approved fix scope;
4. Project Owner/CI reruns only the frontend checkpoint evidence materially
   invalidated by the fix, while every previously failing required command must
   eventually pass;
5. obtain `PASS` before Stage integration proceeds.

---

## 11. Finding Severity

Block-level reviews use:

| Severity | Meaning |
|---|---|
| `P1` | Security, tenant isolation, data loss/corruption, secret exposure, or core public-contract breach |
| `P2` | Material functional, architecture, lifecycle, integration, or regression defect that blocks the checkpoint |
| `P3` | Non-blocking maintainability, clarity, or test-quality improvement |

P3 findings do not automatically expand Stage scope. Record them separately
unless the project owner approves a focused correction.

---

## 12. Integration Gate

Stage integration begins only after required backend and frontend checkpoints
are `PASS`.

Ownership:

```text
ChatGPT       = integration scope, security/tenant review, acceptance, verdict
Codex         = missing/focused integration assets or focused production fixes only
Project Owner = real-stack runner execution and required manual smoke by default
CI            = approved deterministic integration automation when configured
```

Fresh Backend/Frontend Phase 2 PASS evidence must be reused. Do not rerun full
backend/frontend suites or standalone builds merely because integration began.

The approved integration task must define:

- real Laravel–Flutter workflow scope;
- real-stack environment and fixtures;
- exact API/DTO/error boundaries;
- authentication/session behavior;
- lifecycle/state progression;
- cross-layer security and tenant-isolation cases;
- real-stack/E2E commands;
- required manual smoke steps;
- acceptance criteria;
- focused cleanup and delivery rules.

Integration verification must include, where applicable:

- real backend and frontend working together;
- request/response/error contract agreement;
- role and active-state behavior;
- direct-ID and cross-tenant denial;
- routing/session/state behavior;
- lifecycle transitions;
- persistence effects;
- required Windows/desktop/mobile target behavior;
- required manual smoke flow.

Integration findings must be fixed before Stage closure begins.

If a production finding requires code:

1. ChatGPT prepares a focused fix contract;
2. Codex implements and focused-verifies that fix only;
3. ChatGPT determines which earlier PASS evidence remains valid;
4. Project Owner/CI reruns the affected real-stack/integration path needed to
   establish the complete final scenario.

The accepted integration state must be delivered to `origin/main`.

---

## 12A. Evidence Validity and Minimum Rerun Policy

Fresh PASS evidence remains valid until a later change materially affects the
surface that evidence proved.

ChatGPT decides whether evidence is still valid and selects the minimum
sufficient rerun scope.

Default guidance:

| Later change | Effect on existing PASS evidence |
|---|---|
| Docs/bookkeeping-only | Does not invalidate product verification |
| Comment/rename-only with no behavior change | Normally does not invalidate broad evidence |
| Isolated test-only strengthening/cleanup | Production evidence remains valid; run affected tests/static checks as needed |
| Narrow production fix in one feature | Preserve unrelated checkpoint evidence; run focused affected checks and the affected integration path |
| Shared auth/session/router/client/middleware/error infrastructure | May invalidate the corresponding checkpoint; ChatGPT decides exact rerun |
| Public API/schema/migration/authorization/tenant/security change | Normally invalidates the corresponding checkpoint/integration surface |
| Dependency/platform/build-system change | Normally invalidates relevant static/build/checkpoint evidence |
| Required command previously failed | That command must eventually pass after correction |
| Integration run failed before later phases were reached | Rerun enough of the integration flow to prove the complete final scenario |

Do not rerun by habit, and do not skip a rerun when evidence is materially
invalidated.

Evidence age alone is not a reason to rerun when the proven production surface
has not changed.

---

## 13. Stage Closure Review

Stage Closure Review begins only after:

- all approved tasks are accepted and delivered;
- backend Phase 2 checkpoint is `PASS` or justified `N/A`;
- frontend Phase 2 checkpoint is `PASS` or justified `N/A`;
- integration gate is `PASS` or justified `N/A`;
- required fixes are delivered;
- current `origin/main` contains the complete accepted Stage result.

ChatGPT performs the closure review. Codex is not used for closure evidence
collection by default.

Project Owner/CI executes an additional command only when ChatGPT determines
that required evidence is missing or materially invalidated.

ChatGPT reviews:

- current `origin/main`;
- roadmap Stage scope and acceptance criteria;
- Stage Definition of Done;
- relevant locked `docs/01–09`;
- Stage task index;
- current implementation and tests;
- backend/frontend checkpoint evidence;
- integration/E2E evidence;
- GitHub delivery evidence;
- documentation and task bookkeeping state.

Closure must verify:

- every roadmap acceptance criterion;
- approved business behavior;
- backend/frontend contract agreement;
- permissions and tenant isolation;
- validation and error behavior;
- required checkpoint verification;
- required real-stack/E2E and manual smoke evidence;
- absence of blocking regression;
- current documentation/task status;
- final Git state.

Do not rerun broad suites, builds, or E2E during closure when fresh
checkpoint/integration evidence remains valid.

When later changes occurred, apply Section 12A and rerun only the materially
invalidated verification surface.

Closure verdicts:

- `STAGE CLOSED`;
- `FIXES REQUIRED BEFORE CLOSURE`;
- `CLOSURE BLOCKED`.

A Stage is closed only when all required implementation, verification,
checkpoint, integration, fix, delivery, and closure gates pass.

The next Stage may enter planning/decomposition only after the current Stage is
explicitly closed.

---

## 14. Git and Repository Safety

Never:

- force-push shared history;
- rewrite `main`;
- bypass hooks or checks with `--no-verify`;
- silently replace an unexpected `origin`;
- modify global Git configuration as part of a task;
- use destructive `git reset --hard` or destructive `git clean` as normal
  workflow;
- commit passwords, tokens, credentials, private keys, certificates,
  environment secrets, local-only files, or sensitive generated artifacts;
- overwrite, stage, revert, format, move, or delete unrelated user work.

If repository state is unsafe or cannot be isolated without destructive action,
stop and report the exact condition.

---

## 15. Templates

Stage 5+ uses:

| Template | Purpose |
|---|---|
| `CODEX_TASK_TEMPLATE.md` | Compact, implementation-ready Codex contract |
| `BLOCK_REVIEW_TEMPLATE.md` | Backend or frontend Phase 2 read-only checkpoint |
| `STAGE_TASK_INDEX_TEMPLATE.md` | Stage task/dependency/checkpoint/integration map |
| `STAGE_CLOSURE_REVIEW_TEMPLATE.md` | Final Stage closure review |
| `TASK_REVIEW_TEMPLATE.md` | Legacy reference for Stage 0–3 individual task reviews |

`TASK_REVIEW_TEMPLATE.md` must not be used as the normal Stage 5+ per-task
workflow.

---

## 16. Historical Compatibility

Stage 0–3 used an earlier workflow with individual task-level read-only
acceptance reviews. Stage 4 used the preceding block-checkpoint workflow and is
also closed historical evidence.

Those historical files remain correct evidence of how those Stages were
implemented and closed.

Do not:

- rewrite Stage 0–4 tasks/reviews to match Workflow v3 terminology;
- remove historical review/delivery evidence;
- reinterpret old `Accepted`, `PASS`, or delivery statuses;
- regenerate old prompts or closure files.

Workflow v3 governs new Stage 5+ work only.

---

## 17. Current Project State

| Stage | Status | Next permitted gate |
|---|---|---|
| Stage 0 — Project Preparation and Technical Planning | `Closed` | Historical |
| Stage 1 — Authentication and Role-Based Entry | `Closed` | Historical |
| Stage 2 — Multi-Institution Platform Management | `Closed` | Historical |
| Stage 3 — Institution Administration and User Management | `Closed` | Historical |
| Stage 4 — Groups and User Relationships | `Closed` | Stable dependency for Stage 5 |
| Stage 5 — Topics and Learning Materials | `Not started` | Workflow v3 delivery, then Stage 5 planning/decomposition |

Before Stage 5 planning/decomposition:

- Workflow v3 files must be delivered to `origin/main`;
- local `main` must match `origin/main`, ahead/behind `0/0`, with a clean
  working tree;
- ChatGPT must re-read the current Stage 5 roadmap/specification scope and
  current implementation/tests;
- Stage 5 decomposition must be discussed and approved;
- Stage 5 implementation remains unauthorized until its first task passes the
  Implementation Readiness Gate.

---

## Core Principle

> ChatGPT designs the solution, defines the minimum sufficient verification,
> reviews evidence, and assigns verdicts. Codex implements the exact approved
> contract and runs only focused task verification. Project Owner/CI executes
> heavy checkpoint/integration verification and routine delivery by default.
> Context and verification are reduced only where duplication is unnecessary;
> architecture quality, security, tenant isolation, acceptance criteria, and
> final Stage assurance are never reduced.
