# TestLabUz Codex Engineering Rules

## 1. Purpose

This file defines **how Codex must implement code** in TestLabUz.

It does not define product requirements, business behavior, API behavior, database behavior, lifecycle rules, or Stage scope.

For every task:

- the approved implementation contract defines **what to build**;
- this file defines the general engineering standard for **how to build it well**;
- `backend/AGENTS.md` defines additional engineering rules for backend work;
- `frontend/AGENTS.md` defines additional engineering rules for frontend work.

The applicable nested `AGENTS.md` applies automatically based on the files being changed. The implementation contract does not need to repeat or explicitly name those rules.

Codex is an implementation agent. It implements an already designed solution; it does not redesign the product.

## 2. Authoritative Input and Context Discipline

The current approved implementation contract is the complete source of task-specific product and implementation requirements.

The applicable `AGENTS.md` files remain authoritative for general engineering, security, quality, and repository-safety rules.

Read only:

1. the current approved implementation contract;
2. this root `AGENTS.md`;
3. the applicable nested `backend/AGENTS.md` and/or `frontend/AGENTS.md` based on the files being changed;
4. existing source code, tests, migrations, configuration, and infrastructure directly required to implement the task.

Do not read product specifications, roadmap files, architecture/specification documents, previous task files, Stage history, closure reviews, or unrelated modules to determine what to implement.

Do not broaden context “just in case.” Inspect additional files only when a concrete code dependency requires them.

Do not modify this file or another instruction file unless the task explicitly requires that change.

## 3. Instruction Priority and Conflict Handling

Use this priority:

1. the current implementation contract controls task-specific scope, behavior, public contracts, allowed files, acceptance criteria, and verification;
2. the applicable root/nested `AGENTS.md` files control general engineering, security, quality, and repository-safety rules;
3. existing code patterns guide local implementation details only when they do not conflict with the contract or applicable `AGENTS.md`.

A task-specific requirement may specialize a general engineering rule when necessary for the approved implementation, but it must never silently weaken:

- authentication or authorization;
- tenant/institution isolation;
- data integrity;
- secret handling;
- repository/Git safety;
- approved public behavior or contracts.

If the task materially conflicts with an engineering rule or the existing implementation, do not choose silently and do not invent a reconciliation. Report:

- the exact conflicting requirement;
- the affected file or implementation boundary;
- why implementation cannot proceed safely as written.

Minor local differences that do not alter public behavior, architecture, security, data integrity, or repository safety are not conflicts.

## 4. Codex Decision Boundary

Codex may make ordinary local implementation choices when they:

- stay inside the approved scope;
- preserve all public behavior and contracts;
- follow an established project pattern;
- do not create a new cross-cutting architecture;
- do not weaken security, tenant isolation, or data integrity.

Examples of allowed local choices:

- private variable and method names;
- extracting a small focused helper;
- choosing between equivalent local control-flow structures;
- reusing an existing abstraction that already owns the responsibility;
- organizing private implementation details inside the approved layer.

Codex must not independently decide or change:

- product or business behavior;
- public API shape or semantics;
- database/schema contracts;
- lifecycle or state transitions;
- authorization or tenant rules;
- error semantics;
- concurrency or idempotency policy;
- cross-feature architecture;
- package/dependency strategy;
- UX behavior not resolved by the task.

If one of these decisions is missing, the task is not implementation-ready; report the exact gap.

## 5. Scope and Change Control

Implement exactly the approved task.

Do not:

- add unrelated functionality;
- perform unrelated refactors;
- redesign working modules;
- create speculative infrastructure for future tasks;
- add a package or dependency unless explicitly required;
- change unrelated public interfaces, serialization, schema, routes, or behavior;
- edit documentation, task history, or Stage bookkeeping unless explicitly required;
- format or reorganize unrelated files.

If an unrelated defect is discovered, report it separately unless it directly blocks the assigned task.

Preserve backward compatibility unless the task explicitly changes the relevant contract.

Do not manually edit generated files. Run an existing generator only when the task requires generated output.

Do not change dependency lockfiles unless dependencies actually change as part of the approved task.

## 6. Production Code Quality

Code must be readable, maintainable, testable, and suitable for a real production project.

### Naming

Use specific names that communicate purpose and responsibility.

Avoid vague catch-all names such as `data`, `temp`, `manager`, `common`, `misc`, `helper2`, or `doSomething` in production code.

### Responsibilities

A function, class, service, widget, file, or module should have one clear reason to change.

Keep unrelated concerns separated. Do not create God classes, God files, catch-all services, or universal helpers.

### Placement

Put code in the feature, module, and layer that owns the responsibility.

Do not add logic to a convenient file when another layer owns it.

### Reuse and Abstraction

Inspect existing patterns before creating a new helper, service, repository, controller, provider, client, or abstraction.

Reuse an existing abstraction only when it genuinely owns the same responsibility.

Avoid both copy-pasting stable shared behavior and creating premature abstractions from superficial similarity.

### Complexity

Prefer focused, composable code with clear inputs and outputs.

Refactor when code mixes layers, contains multiple independent responsibilities, has difficult nesting, or cannot be tested without unrelated setup.

Do not split straightforward code into meaningless tiny methods merely to reduce line count.

### Errors and Edge Cases

Implement all task-defined failure and edge behavior, not only the happy path.

Do not swallow exceptions, hide programming errors behind broad catch-all handling, or expose internal exceptions, stack traces, SQL details, or secrets.

Operations defined as atomic by the task must not leave partial persistent state.

### Comments and Dead Code

Prefer clear code over comments that restate it.

Use comments only for non-obvious reasons, security boundaries, compatibility constraints, concurrency safeguards, or technical invariants.

Do not leave debug output, commented-out code, obsolete alternatives, unused code, or TODOs that hide incomplete acceptance criteria.

## 7. Security and Data Protection

Never weaken existing:

- authentication;
- authorization;
- tenant/institution isolation;
- ownership and relationship checks;
- protected-resource access;
- secret and token handling;
- historical-data integrity.

A syntactically valid identifier does not grant access.

For tenant-owned operations, resolve and scope access from trusted authenticated context before returning or mutating records.

Do not allow direct identifiers, filters, pagination, routes, URLs, cache state, or stale asynchronous results to bypass security boundaries.

Do not log or expose passwords, bearer tokens, credentials, private keys, secrets, or sensitive internal payloads.

Security-sensitive behavior must be explicit and testable.

## 8. Tests

Tests are production-quality code.

Add or update focused tests for the behavior changed by the task, including required negative and edge cases.

Use behavior-oriented test names and keep important actor, scope, state, and input setup understandable.

Do not:

- delete, skip, weaken, or rewrite an existing test merely to make implementation pass;
- relax an assertion without an explicit contract change;
- hide a defect by changing only fixtures or mocks;
- use arbitrary sleeps, real external networks, uncontrolled current time, or other avoidable nondeterminism.

An existing test may change only when the implementation task explicitly changes the behavior that test represents.

## 9. Proportional Verification

The implementation contract defines the required verification scope and commands.

After each implementation task, run the required:

- focused tests for the changed functionality;
- format/static checks;
- specifically named affected regression tests;
- `git diff --check`;
- focused scope/diff self-review.

Additional narrow diagnostic commands or focused reruns are allowed when needed to understand or confirm a failure.

Do not independently expand verification to full backend/frontend suites, full builds, broad E2E, or unrelated regression areas unless the implementation contract explicitly requires them.

If implementation necessarily touches shared infrastructure beyond the verification scope defined by the contract, report the contract mismatch or material regression risk rather than silently launching broad verification.

Block-level full suites, required builds, E2E, and Phase 2 reviews are orchestrated at Stage checkpoints outside this file.

Never claim that a command passed when it was not run or did not pass. Report unavailable tooling and pre-existing failures truthfully.

## 10. Preserve Existing User Work

Preserve all pre-existing user changes and untracked files.

Do not overwrite, revert, delete, move, format, stage, or include unrelated existing work in the task result.

Before editing, inspect repository status and identify changes that do not belong to the task.

If safe isolation is not possible, report the exact conflict.

## 11. Git Safety

Do not:

- force-push;
- rewrite shared history;
- bypass hooks or checks with `--no-verify`;
- modify global Git configuration;
- silently replace an unexpected remote;
- use destructive `git reset --hard` or destructive `git clean` as normal workflow;
- commit credentials, tokens, private keys, certificates, environment secrets, or local-only files.

Codex must not perform GitHub delivery merely because implementation and verification passed.

Commit, push, PR creation, merge, or task/Stage bookkeeping are performed only when the current implementation contract or active workflow explicitly assigns that delivery step.

## 12. Final Diff Review

Before reporting implementation complete, inspect the complete diff and verify:

- every changed file is necessary;
- the implementation matches the task exactly;
- non-goals remain excluded;
- no unrelated refactor or formatting churn exists;
- code is in the correct feature/module/layer;
- responsibilities and names are clear;
- established patterns are reused appropriately;
- no public API, schema, serialization, route, or behavior changed unintentionally;
- security and tenant boundaries remain intact;
- task-defined error and edge behavior is covered;
- focused tests cover the actual change;
- no debug code, secrets, generated junk, or temporary artifacts are included.

## 13. Completion Report

Return a concise evidence-based report containing:

- implementation summary;
- changed files and purpose;
- exact verification commands and results;
- any directly affected regression checks required by the task;
- scope/non-goal confirmation;
- deviations, pre-existing failures, unresolved conflicts, or blockers;
- current Git status when relevant.

Do not repeat the full task contract in the report.

## Final Rule

> The approved implementation contract defines exactly **what** to build. The applicable `AGENTS.md` files define **how** to build it well and safely. Codex implements the approved design; it does not create a new one.
