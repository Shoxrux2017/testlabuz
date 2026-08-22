# TestLabUz Codex Engineering Rules — Lean Verification

## 1. Purpose

This file defines how Codex implements approved TestLabUz changes.

It does not define product requirements, business behavior, API behavior,
database behavior, lifecycle rules, or Stage scope.

For every task:

- the approved implementation contract defines **what** to build;
- this file defines **how** to build it safely and well;
- applicable nested `backend/AGENTS.md` / `frontend/AGENTS.md` add
  implementation-specific rules.

Codex is an implementation agent, not the product/architecture decision maker.

---

## 2. Context Discipline

Read only:

1. the current approved implementation contract;
2. this root `AGENTS.md`;
3. applicable nested `AGENTS.md`;
4. source/tests/migrations/config/infrastructure directly required by the task.

Do not read product specifications, roadmap, architecture/API/database docs,
previous task files, Stage history, checkpoint reviews, or closure reviews to
decide what to implement.

Do not broaden context “just in case”.

If the contract is materially incomplete or conflicts with current
implementation or applicable engineering rules, return `BLOCKED`.

---

## 3. Decision Boundary

Codex may make ordinary local implementation choices when they:

- stay inside approved scope;
- preserve public behavior/contracts;
- follow established project patterns;
- do not create new cross-cutting architecture;
- do not weaken security, tenant isolation, or data integrity.

Codex must not independently decide/change:

- product/business behavior;
- public API semantics;
- schema/database contracts;
- lifecycle/state transitions;
- authorization/tenant rules;
- error semantics;
- concurrency/idempotency policy;
- cross-feature architecture;
- package/dependency strategy;
- unresolved UX behavior.

---

## 4. Scope and Change Control

Implement exactly the approved contract.

Do not:

- add unrelated functionality;
- perform unrelated refactors;
- create speculative future infrastructure;
- add packages/dependencies unless explicitly approved;
- change unrelated public API/schema/routes/serialization;
- edit docs/task history/Stage bookkeeping unless explicitly approved;
- format/reorganize unrelated files.

Report unrelated defects separately unless they directly block the task.

---

## 5. Production Code Quality

Code must be readable, maintainable, testable, and production-suitable.

### Responsibilities and placement

- one clear responsibility per class/module/widget/action;
- put logic in the owning feature/layer;
- avoid God classes/files and catch-all services;
- reuse existing abstractions only when they genuinely own the responsibility;
- avoid premature generic abstractions.

### Errors and edge cases

- implement contract-defined negative/edge behavior;
- do not swallow unexpected failures;
- do not expose stack traces, SQL, secrets, or internal exceptions;
- atomic operations must not leave partial persistent state.

### Dead/debug code

Do not leave debug output, commented-out alternatives, obsolete code, unused
code, or TODOs that hide incomplete acceptance criteria.

---

## 6. Security and Data Protection

Never weaken:

- authentication;
- authorization;
- tenant/institution isolation;
- ownership/relationship checks;
- protected-resource access;
- secret/token handling;
- historical-data integrity.

A valid UUID is not authorization.

For tenant-owned access:

```text
trusted authenticated context
→ tenant-scoped resolution
→ role/relationship/lifecycle checks
→ read/write
```

Do not log/expose passwords, bearer tokens, credentials, private keys, secrets,
or sensitive internal payloads.

---

## 7. Tests

Tests are production-quality implementation.

Add/update the focused tests required by the contract.

Tests must:

- exercise the boundary that owns the behavior;
- include required positive/negative/tenant/security/lifecycle/concurrency/async
  cases where relevant;
- remain deterministic.

Do not delete/skip/weaken tests merely to make code pass.
Do not hide defects by changing fixtures/mocks only.
Avoid arbitrary sleeps, uncontrolled time, and real external networks.

---

## 8. Proportional Verification

The contract defines the minimum sufficient task verification.

After each implementation task, Codex runs:

- focused tests for changed functionality;
- necessary format/static checks;
- specifically named directly affected regression tests when justified;
- `git diff --check`;
- focused scope/diff self-review.

Additional narrow diagnostics/reruns are allowed only to understand a concrete
failure.

Do not independently expand to:

```text
full backend suite
full frontend suite
full build
broad E2E
Phase 2
```

unless the contract explicitly requires broader verification for a concrete
risk.

Heavy checkpoint/build/E2E verification is orchestrated outside the task and is
normally executed by Project Owner/CI.

Never claim a command passed when it was not run or did not pass.

---

## 9. Preserve Existing User Work

Before editing, inspect repository status.

Do not overwrite, revert, delete, move, format, stage, or include unrelated
existing work.

If safe isolation is impossible, return `BLOCKED`.

---

## 10. Git Safety and Delivery

Do not:

- force-push;
- rewrite shared history;
- bypass hooks/checks;
- modify global Git configuration;
- silently replace an unexpected remote;
- use destructive reset/clean as normal workflow;
- commit secrets/local-only files.

Git/GitHub delivery is Project Owner-owned by default.

Codex must not commit, push, open/merge PRs, or update task/Stage bookkeeping
unless the task explicitly assigns delivery to Codex.

---

## 11. Final Diff Self-Review

Before reporting implementation complete, inspect the complete diff and verify:

- every changed file is necessary;
- implementation matches contract;
- non-goals remain excluded;
- no unrelated refactor/format churn;
- correct feature/module/layer placement;
- no unintended API/schema/route/serialization behavior change;
- security and tenant boundaries intact;
- task-defined edge/error behavior covered;
- focused tests cover actual change;
- no debug code, secrets, generated junk, or temporary artifacts.

---

## 12. Completion Report

Return concise evidence:

1. implementation summary;
2. changed files and purpose;
3. exact focused verification commands/results;
4. directly affected regression results;
5. `git diff --check`;
6. scope/non-goal confirmation;
7. deviations/blockers;
8. current Git status when relevant.

Do not repeat the full contract.

Do not report task `Accepted`; ChatGPT assigns acceptance after approved delivery.

---

## Final Rule

> The approved contract defines what to build. Codex implements it with
> production-quality code/tests and only the minimum focused verification.
> Heavy checkpoint/integration verification and routine Git delivery stay
> outside Codex by default.
