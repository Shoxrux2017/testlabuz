# Stage [Number] Closure Review — [Stage Name]

## 1. Closure Metadata

| Field | Value |
|---|---|
| Stage | `[Stage number and exact Stage name]` |
| Review mode | `Read-only` |
| Verification model | `Workflow v3 — Lean Verification` |
| Review date | `[YYYY-MM-DD]` |
| Stage index | `[tasks/STAGE_<NN>_TASK_INDEX.md]` |
| Audited `origin/main` | `[commit SHA]` |
| Local `main` | `[commit SHA]` |
| Ahead/behind | `[0/0 expected]` |
| Working tree | `[Clean / Not clean]` |
| Proposed verdict | `[Pending]` |

Stage Closure Review begins only after all required implementation,
checkpoint, integration, fix, and delivery work is complete.

The review verifies the complete accepted Stage state on `origin/main`.

During the read-only review:

- do not edit implementation files;
- do not fix findings;
- do not stage changes;
- do not commit;
- do not push;
- do not merge;
- do not change task or Stage bookkeeping until the verdict is determined.

ChatGPT owns the closure analysis, acceptance mapping,
evidence-validity decisions, findings, and final verdict.

Codex is not used merely to collect Stage Closure evidence.

If an additional command is genuinely required because existing evidence is
missing or materially invalidated, the Project Owner or approved CI executes
the exact verification selected by ChatGPT.

Codex is used only if closure identifies a focused implementation defect that
requires an approved code fix. Codex must not make missing product,
architecture, API, database, security, tenant, lifecycle, concurrency,
idempotency, or unresolved UX decisions.

---

## 2. Closure Entry Conditions

| Condition | Result | Evidence |
|---|---|---|
| Previous Stage is explicitly closed | `[Pass/N/A/Fail]` | `[Reference]` |
| Stage decomposition was approved | `[Pass/Fail]` | `[Stage index]` |
| Every approved task is `Accepted` | `[Pass/Fail]` | `[Task IDs]` |
| Every accepted task is delivered to `origin/main` | `[Pass/Fail]` | `[Commits/PRs]` |
| Backend Phase 2 checkpoint is `PASS` or justified `N/A` | `[Pass/N/A/Fail]` | `[Review file + audited SHA]` |
| Frontend Phase 2 checkpoint is `PASS` or justified `N/A` | `[Pass/N/A/Fail]` | `[Review file + audited SHA]` |
| Integration gate is `PASS` or justified `N/A` | `[Pass/N/A/Fail]` | `[Integration evidence]` |
| Required focused fixes are delivered | `[Pass/N/A/Fail]` | `[Task/commit/PR references]` |
| Current `origin/main` contains the complete accepted Stage result | `[Pass/Fail]` | `[SHA]` |
| Local `main == origin/main` | `[Pass/Fail]` | `[SHAs]` |
| Ahead/behind is `0/0` | `[Pass/Fail]` | `[Command output]` |
| Working tree is clean | `[Pass/Fail]` | `[git status evidence]` |

Any failed required entry condition blocks Stage closure.

---

## 3. Authoritative Review Inputs

ChatGPT reviews:

- current `origin/main`;
- root `AGENTS.md`;
- applicable `backend/AGENTS.md` and/or `frontend/AGENTS.md`;
- `tasks/README.md`;
- relevant locked `docs/01–09`;
- roadmap Stage scope, acceptance criteria, and Definition of Done;
- approved Stage task index;
- every approved implementation contract;
- current implementation and tests;
- backend/frontend block-review evidence;
- integration, real-stack, E2E, and manual-smoke evidence;
- GitHub delivery evidence;
- required task and Stage bookkeeping.

These sources are closure-review inputs for ChatGPT.

Project Owner/CI does not need to read or reinterpret these sources merely to
execute an approved verification command.

Codex must not reopen product or architecture sources to reinterpret approved
implementation contracts. If a focused fix is required, Codex receives only
the focused fix contract, applicable `AGENTS.md`, and directly relevant
source/tests.

---

## 4. Stage Scope and Delivery Audit

| Check | Result | Evidence |
|---|---|---|
| Complete approved Stage scope is present | `[Pass/Fail]` | `[Tasks/files]` |
| No approved task is missing | `[Pass/Fail]` | `[Task index]` |
| No unapproved feature or hidden scope entered the Stage | `[Pass/Fail]` | `[Evidence]` |
| Explicit non-goals remain excluded | `[Pass/Fail]` | `[Evidence]` |
| No locked product/API/database behavior changed without approval | `[Pass/Fail]` | `[Evidence]` |
| Backend, frontend, and integration delivery records agree | `[Pass/Fail/N/A]` | `[Evidence]` |
| No duplicate implementation path, temporary workaround, or hidden placeholder remains | `[Pass/Fail]` | `[Evidence]` |
| No dependency, generated, platform, or lock-file change lacks justification | `[Pass/Fail/N/A]` | `[Evidence]` |

---

## 5. Roadmap Acceptance-Criteria Matrix

Copy every acceptance criterion from the roadmap Stage section.

| Roadmap acceptance criterion | Result | Implementation evidence | Verification evidence |
|---|---|---|---|
| `[Exact criterion]` | `[Pass/Fail/Not verified]` | `[Task IDs/files]` | `[Tests/checkpoint/integration/smoke]` |

Every required criterion must pass.

A missing criterion, missing implementation owner, or missing verification
evidence blocks closure.

---

## 6. Stage Definition-of-Done Review

Use the roadmap Stage Definition of Done.

| Definition-of-Done condition | Result | Evidence or N/A reason |
|---|---|---|
| Approved business behavior is implemented | `[Pass/Fail]` | `[Evidence]` |
| Required backend/API behavior works | `[Pass/Fail/N/A]` | `[Evidence]` |
| Required frontend UI uses real backend data | `[Pass/Fail/N/A]` | `[Evidence]` |
| No core-path placeholder remains | `[Pass/Fail/N/A]` | `[Evidence]` |
| Authorization is enforced server-side | `[Pass/Fail/N/A]` | `[Evidence]` |
| Institution data is isolated correctly | `[Pass/Fail/N/A]` | `[Evidence]` |
| Validation and error behavior match the approved contract | `[Pass/Fail/N/A]` | `[Evidence]` |
| Required backend checkpoint passed | `[Pass/Fail/N/A]` | `[Review evidence]` |
| Required frontend checkpoint passed | `[Pass/Fail/N/A]` | `[Review evidence]` |
| Required integration/real-stack/E2E checks passed | `[Pass/Fail/N/A]` | `[Evidence]` |
| Required Project Owner manual smoke passed | `[Pass/Fail/N/A/Not run]` | `[Evidence]` |
| No blocking regression affects earlier Stages | `[Pass/Fail]` | `[Evidence]` |
| Relevant documentation and task status are synchronized | `[Pass/Fail]` | `[Evidence]` |
| Accepted result is present on `origin/main` | `[Pass/Fail]` | `[SHA/PR]` |
| No unresolved P1 or P2 finding remains | `[Pass/Fail]` | `[Finding status]` |

Every `N/A` requires a Stage-specific reason.

`Not run` is not a pass when manual smoke is required.

---

## 7. Backend and Frontend Checkpoint Evidence

Closure should reuse valid checkpoint evidence instead of rerunning broad
verification without a concrete reason.

Fresh PASS evidence remains valid until a later change materially affects the
surface that evidence proved. ChatGPT decides whether evidence remains valid and
selects the minimum sufficient rerun scope.

### 7.1 Backend Checkpoint

| Field | Value |
|---|---|
| Required for this Stage | `[Yes/No]` |
| Review file | `[Reference or N/A]` |
| Audited `origin/main` | `[SHA or N/A]` |
| Verdict | `[PASS / NOT ACCEPTED / N/A]` |
| Findings | `[P1/P2/P3 counts or N/A]` |
| Full backend regression result | `[Result or N/A]` |
| Later change after checkpoint | `[None / Description]` |
| Evidence still valid at closure | `[Yes/No/N/A]` |
| Validity reason | `[Why the proven surface is unchanged / invalidated]` |
| Additional rerun required | `[None / Exact affected command(s)]` |
| Additional rerun result | `[N/A / Observed result]` |

### 7.2 Frontend Checkpoint

| Field | Value |
|---|---|
| Required for this Stage | `[Yes/No]` |
| Review file | `[Reference or N/A]` |
| Audited `origin/main` | `[SHA or N/A]` |
| Verdict | `[PASS / NOT ACCEPTED / N/A]` |
| Findings | `[P1/P2/P3 counts or N/A]` |
| Full frontend tests/static/build result | `[Result or N/A]` |
| Later change after checkpoint | `[None / Description]` |
| Evidence still valid at closure | `[Yes/No/N/A]` |
| Validity reason | `[Why the proven surface is unchanged / invalidated]` |
| Additional rerun required | `[None / Exact affected command(s)]` |
| Additional rerun result | `[N/A / Observed result]` |

Default evidence-validity guidance:

| Later change | Effect on existing PASS evidence |
|---|---|
| Docs/bookkeeping-only | Does not invalidate product verification |
| Comment/rename-only with no behavior change | Normally does not invalidate broad evidence |
| Isolated test-only strengthening/cleanup | Production evidence remains valid; run affected tests/static checks as needed |
| Narrow production fix in one feature | Preserve unrelated PASS evidence; run focused affected checks and the affected integration path |
| Shared auth/session/router/client/middleware/error infrastructure | May invalidate broader checkpoint evidence; ChatGPT decides the exact rerun |
| Public API/schema/migration/authorization/tenant/security change | Normally invalidates the corresponding checkpoint/integration surface |
| Dependency/platform/build-system change | Normally invalidates relevant static/build/checkpoint evidence |
| Required command previously failed | That command must eventually pass after correction |
| Real-stack scenario failed before later phases ran | Rerun enough integration to prove the complete final scenario |

Do not rerun full backend/frontend suites, standalone builds, or broad E2E
during closure when fresh checkpoint/integration evidence remains valid.

Do not rerun by habit, and do not preserve evidence that a later change
materially invalidated.

---

## 8. Complete Working Scenario: Frontend ↔ Backend ↔ Database

This section verifies that the Stage works as one real system, not only as
separate backend and frontend units.

Reuse accepted integration evidence when it remains valid. Do not rerun the
real-stack runner merely because closure has started. If later changes
materially affected the integrated surface, ChatGPT determines the exact
integration path that the Project Owner/CI must rerun.

| Workflow | Expected result | Real-stack/E2E evidence | Result |
|---|---|---|---|
| `[Main Stage workflow]` | `[Expected end-to-end result]` | `[Command/test/reference]` | `[Pass/Fail/N/A]` |
| `[Error/lifecycle workflow]` | `[Expected result]` | `[Command/test/reference]` | `[Pass/Fail/N/A]` |
| `[Cross-role workflow]` | `[Expected result]` | `[Command/test/reference]` | `[Pass/Fail/N/A]` |

Verify where applicable:

- [ ] Flutter sends the approved request to the real Laravel API;
- [ ] Laravel applies the approved validation, authorization, tenant, and
      lifecycle rules;
- [ ] PostgreSQL persistence matches the approved contract;
- [ ] Laravel returns the approved success/error response;
- [ ] Flutter maps and displays the response correctly;
- [ ] authentication and session behavior remain correct;
- [ ] navigation and application state remain correct;
- [ ] failure/retry/reconciliation behavior is safe;
- [ ] the required target platform works.

If this Stage has no cross-layer behavior, record a precise `N/A` reason.

---

## 9. Access Rights and Institution Data Isolation

This section verifies that users can access only the data and actions allowed by
their role and institution.

| Check | Result | Evidence |
|---|---|---|
| Unauthenticated access is denied where required | `[Pass/N/A/Fail]` | `[Evidence]` |
| Active-user and active-institution rules are enforced | `[Pass/N/A/Fail]` | `[Evidence]` |
| Each role can perform only approved operations | `[Pass/N/A/Fail]` | `[Evidence]` |
| A user from one institution cannot read another institution's data | `[Pass/N/A/Fail]` | `[Evidence]` |
| A user from one institution cannot modify another institution's data | `[Pass/N/A/Fail]` | `[Evidence]` |
| Knowing a foreign UUID does not grant access | `[Pass/N/A/Fail]` | `[Evidence]` |
| Lists, filters, pagination, aggregates, and relationships do not leak foreign data | `[Pass/N/A/Fail]` | `[Evidence]` |
| Ownership and relationship restrictions cannot be bypassed | `[Pass/N/A/Fail]` | `[Evidence]` |
| Frontend visibility does not replace backend authorization | `[Pass/N/A/Fail]` | `[Evidence]` |
| Sensitive fields, files, logs, errors, and tokens remain protected | `[Pass/N/A/Fail]` | `[Evidence]` |

Any unresolved access-control, institution-isolation, secret-exposure, or
protected-data defect is a P1 finding and blocks closure.

---

## 10. Project Owner Manual Smoke

Manual smoke is a short final check of the most important user workflows in the
running application.

ChatGPT defines the required smoke steps.

The Project Owner performs the user-facing actions and reports the observed
result.

Codex is not used merely to perform or attest manual smoke. If integration
requires missing setup automation, Codex may prepare that automation only
through a separately approved focused integration contract.

| Scenario | Steps | Expected result | Project Owner result |
|---|---|---|---|
| `[Primary happy path]` | `[Exact short steps]` | `[Expected]` | `[PASS/FAIL/Not run]` |
| `[Important negative path]` | `[Exact short steps]` | `[Expected]` | `[PASS/FAIL/Not run]` |
| `[Critical cross-role or lifecycle path]` | `[Exact short steps]` | `[Expected]` | `[PASS/FAIL/Not run/N/A]` |

Rules:

- do not repeat manually everything already covered reliably by automated/E2E
  tests;
- keep smoke scope proportional to the Stage;
- record the actual Project Owner result;
- do not claim `PASS` when the Project Owner did not run the scenario;
- `Not run` blocks closure only when that smoke scenario is required;
- a failed required smoke scenario must be investigated and fixed before
  closure.

Project Owner confirmation:

```text
Manual smoke status: [PASS / FAIL / Not run / N/A]
Confirmed by: [Project Owner]
Date: [YYYY-MM-DD]
Notes: [Observed result]
```

---

## 11. Regression and Documentation Review

- [ ] Previous accepted Stage workflows remain green.
- [ ] Database migrations and compatibility are safe where applicable.
- [ ] Backend and frontend public contracts remain synchronized.
- [ ] Stage task index reflects actual task/checkpoint/integration status.
- [ ] Every accepted task is delivered.
- [ ] Block-review and integration evidence references are current.
- [ ] Required implementation documentation reflects actual behavior.
- [ ] No TODO, placeholder, or temporary workaround hides incomplete Stage
      behavior.
- [ ] No historical Stage 0–4 evidence was rewritten to match Workflow v3.
- [ ] Closure documentation changes do not modify production behavior.

---

## 12. Final Repository State

| Check | Expected | Actual | Result |
|---|---|---|---|
| `origin/main` SHA | Accepted Stage state | `[SHA]` | `[Pass/Fail]` |
| Local `main` SHA | Same as `origin/main` | `[SHA]` | `[Pass/Fail]` |
| Ahead/behind | `0/0` | `[Result]` | `[Pass/Fail]` |
| Working tree | Clean | `[Result]` | `[Pass/Fail]` |
| Unexpected files | None | `[Result]` | `[Pass/Fail]` |
| Closure branch/PR state | Safe and traceable | `[Reference]` | `[Pass/Fail/N/A]` |

---

## 13. Findings

List findings from highest severity to lowest.

| ID | Severity | Finding | Evidence | Blocks closure? | Required action |
|---|---|---|---|---|---|
| `[SC-01]` | `[P1/P2/P3]` | `[Problem]` | `[Location/test/evidence]` | `[Yes/No]` | `[Focused correction]` |

Severity:

- `P1` — security, institution isolation, secret exposure, data loss/corruption,
  or core public-contract breach;
- `P2` — material functional, architecture, lifecycle, integration, regression,
  or required-verification failure;
- `P3` — non-blocking maintainability, clarity, or test-quality improvement.

If no findings:

```text
No findings.
P1 = 0
P2 = 0
P3 = 0
```

Closure requires `P1 = 0` and `P2 = 0`.

P3 findings do not automatically expand Stage scope.

---

## 14. Final Verdict

Choose exactly one:

- `STAGE CLOSED`
- `FIXES REQUIRED BEFORE CLOSURE`
- `CLOSURE BLOCKED`

### `STAGE CLOSED`

Use only when:

- every required entry condition passes;
- every roadmap acceptance criterion passes;
- Stage Definition of Done passes;
- required backend/frontend checkpoint evidence is current and valid under
  the evidence-validity policy;
- required integration/real-stack evidence is current and valid;
- required complete working scenarios pass;
- required access-rights and institution-isolation checks pass;
- required Project Owner manual smoke passes;
- `P1 = 0`;
- `P2 = 0`;
- accepted result is on `origin/main`;
- local `main` is synchronized and clean.

### `FIXES REQUIRED BEFORE CLOSURE`

Use when implementation or verification findings can be corrected through
focused approved fixes.

### `CLOSURE BLOCKED`

Use when closure cannot proceed because of a missing specification decision,
dependency, unavailable required evidence, unsafe repository state, or another
condition that cannot be resolved as a normal implementation fix.

**Verdict:** `[Pending]`

**Reason:** [Concise evidence-based explanation.]

---

## 15. Closure Bookkeeping and Delivery

Run only after the read-only verdict permits closure documentation updates.

Routine closure bookkeeping and Git/GitHub delivery are Project Owner-owned by
default. Codex is not used for documentation-only closure delivery unless
explicitly approved for a concrete reason.

When verdict is `STAGE CLOSED`:

1. update the Stage index to `Closed`;
2. record final checkpoint/integration/manual-smoke evidence;
3. add or update the Stage Closure Review file;
4. change only approved closure/bookkeeping documentation;
5. run `git diff --check`;
6. verify no production code or locked product specification changed unless
   separately approved;
7. do **not** rerun backend/frontend suites, builds, or E2E merely because the
   closure bookkeeping changed;
8. create a focused closure commit;
9. push the closure branch;
10. open and merge the closure Pull Request when permitted;
11. synchronize local `main`;
12. verify local `main == origin/main`, ahead/behind `0/0`, and clean worktree.

If safe closure delivery cannot complete, record the exact delivery blocker.
Do not claim the Stage is fully closed on GitHub until closure evidence is
present on `origin/main`.

---

## 16. Next Gate

If verdict is `STAGE CLOSED`:

```text
The next permitted action is planning/decomposition of the next roadmap Stage.
Planning/decomposition of the next Stage may begin only after closure delivery
is verified on synchronized clean `main`. Implementation of the next Stage must
not begin before its own entry gate, approved decomposition, and Implementation
Readiness Gate pass.
```

If verdict is not `STAGE CLOSED`, state the exact required fix, evidence, or
decision before closure can be retried.
