# Phase 2 Read-Only Block Review — [Stage / Backend or Frontend]

## 1. Review Metadata

| Field | Value |
|---|---|
| Stage | `[Stage number and exact Stage name]` |
| Block | `[Backend / Frontend]` |
| Review mode | `Read-only` |
| Review date | `[YYYY-MM-DD]` |
| Stage index | `[tasks/STAGE_<NN>_TASK_INDEX.md]` |
| Audited `origin/main` | `[commit SHA]` |
| Local `main` | `[commit SHA]` |
| Ahead/behind | `[0/0 expected]` |
| Verdict | `[Pending]` |

This Phase 2 review runs after all approved tasks in the selected block are
accepted and delivered.

It reviews the complete block as one integrated implementation surface.

During the read-only review:

- do not edit implementation files;
- do not fix findings;
- do not stage changes;
- do not commit;
- do not push;
- do not merge;
- do not modify task or Stage bookkeeping.

ChatGPT owns the review scope, architecture/security analysis, findings, and
verdict. Codex may run explicitly assigned read-only verification commands and
collect evidence, but must not make missing product or architecture decisions.

---

## 2. Entry Conditions

| Condition | Result | Evidence |
|---|---|---|
| Previous required checkpoint passed | `[Pass/N/A/Fail]` | `[Reference]` |
| All approved block tasks are `Accepted` | `[Pass/Fail]` | `[Task IDs]` |
| All approved block tasks are delivered to `origin/main` | `[Pass/Fail]` | `[Commits/PRs]` |
| Local `main == origin/main` | `[Pass/Fail]` | `[SHAs]` |
| Ahead/behind is `0/0` | `[Pass/Fail]` | `[Command output]` |
| Working tree is clean | `[Pass/Fail]` | `[git status evidence]` |
| No unresolved dependency blocks the review | `[Pass/Fail]` | `[Evidence]` |

If a required entry condition fails, record the blocker and stop the checkpoint.

---

## 3. Authoritative Review Inputs

ChatGPT reviews:

- current `origin/main`;
- root `AGENTS.md`;
- applicable `backend/AGENTS.md` or `frontend/AGENTS.md`;
- `tasks/README.md`;
- approved Stage task index;
- every implementation contract in the audited block;
- relevant locked `docs/01–09`;
- current implementation and tests;
- task delivery evidence;
- previous Stage/checkpoint evidence needed to establish dependencies.

The locked product and technical documents are review inputs for ChatGPT.
Codex must not reopen them to reinterpret the implementation contracts.

---

## 4. Audited Block Inventory

| Task ID | Delivered outcome | Main commit/PR | Cross-task dependency | Result |
|---|---|---|---|---|
| `[Task ID]` | `[Outcome]` | `[Reference]` | `[Dependency]` | `[Pass/Fail]` |

Confirm:

- [ ] every approved task in the selected block is represented;
- [ ] every delivered outcome is present on the audited `main`;
- [ ] no unapproved task or hidden scope entered the block;
- [ ] task contracts agree with one another;
- [ ] no accepted task silently overrides another task's contract;
- [ ] prior Stage behavior remains protected.

---

## 5. Scope and Change Audit

| Check | Result | Evidence |
|---|---|---|
| Block changes match approved Stage scope | `[Pass/Fail]` | `[Files/tasks]` |
| No unrelated feature or refactor entered the block | `[Pass/Fail]` | `[Evidence]` |
| Explicit non-goals remain excluded | `[Pass/Fail]` | `[Evidence]` |
| No locked product/API/database behavior changed without approval | `[Pass/Fail]` | `[Evidence]` |
| No duplicate/parallel implementation path exists | `[Pass/Fail]` | `[Evidence]` |
| No debug code, placeholder, dead code, or temporary artifact remains | `[Pass/Fail]` | `[Evidence]` |
| No dependency/lock/generated/platform change lacks justification | `[Pass/Fail/N/A]` | `[Evidence]` |

---

## 6. Architecture and Cross-Task Review

Complete the subsection for the selected block. Mark the other subsection
`N/A — different block`.

### 6.1 Backend Review

| Check | Result | Evidence |
|---|---|---|
| Controllers remain thin | `[Pass/N/A/Fail]` | `[Files]` |
| Validation and stateful business rules are correctly separated | `[Pass/N/A/Fail]` | `[Files]` |
| Actions/services have focused responsibilities | `[Pass/N/A/Fail]` | `[Files]` |
| Domain rules are centralized rather than duplicated | `[Pass/N/A/Fail]` | `[Files]` |
| API responses/errors are consistent across tasks | `[Pass/N/A/Fail]` | `[Evidence]` |
| Migrations/schema/constraints/indexes agree across tasks | `[Pass/N/A/Fail]` | `[Evidence]` |
| Queries are tenant-safe, bounded, deterministic, and free of obvious N+1 | `[Pass/N/A/Fail]` | `[Evidence]` |
| Multi-write operations are atomic where required | `[Pass/N/A/Fail]` | `[Evidence]` |
| Locks/concurrency/idempotency rules compose correctly | `[Pass/N/A/Fail]` | `[Evidence]` |
| Resources/models do not contain hidden workflow decisions | `[Pass/N/A/Fail]` | `[Evidence]` |
| Shared infrastructure changes are coherent and justified | `[Pass/N/A/Fail]` | `[Evidence]` |
| Cross-task lifecycle/state transitions are consistent | `[Pass/N/A/Fail]` | `[Evidence]` |

Backend notes:

[Evidence, concerns, or `No issue found`.]

### 6.2 Frontend Review

| Check | Result | Evidence |
|---|---|---|
| Feature-first/module placement is correct | `[Pass/N/A/Fail]` | `[Files]` |
| Data/domain/presentation responsibilities are separated | `[Pass/N/A/Fail]` | `[Files]` |
| Widgets do not call Dio or parse raw JSON | `[Pass/N/A/Fail]` | `[Evidence]` |
| DTO/repository/controller/provider contracts agree across tasks | `[Pass/N/A/Fail]` | `[Evidence]` |
| Router/session/auth state behavior is consistent | `[Pass/N/A/Fail]` | `[Evidence]` |
| Stale async completions cannot affect current state | `[Pass/N/A/Fail]` | `[Evidence]` |
| Loading/empty/data/error/mutation states compose correctly | `[Pass/N/A/Fail]` | `[Evidence]` |
| Cache ownership and invalidation are coherent and narrow | `[Pass/N/A/Fail]` | `[Evidence]` |
| Backend-authoritative rules were not reimplemented in Flutter | `[Pass/N/A/Fail]` | `[Evidence]` |
| Machine values remain separate from UI labels | `[Pass/N/A/Fail]` | `[Evidence]` |
| Focus/keyboard/accessibility/responsiveness requirements are met | `[Pass/N/A/Fail]` | `[Evidence]` |
| No competing router/client/state/cache architecture was introduced | `[Pass/N/A/Fail]` | `[Evidence]` |
| Generated/platform/lock changes are justified | `[Pass/N/A/Fail]` | `[Evidence]` |

Frontend notes:

[Evidence, concerns, or `No issue found`.]

---

## 7. Authorization, Security, and Tenant Isolation

| Check | Result | Evidence |
|---|---|---|
| Unauthenticated access is denied where required | `[Pass/N/A/Fail]` | `[Evidence]` |
| Active-user and active-institution rules are enforced | `[Pass/N/A/Fail]` | `[Evidence]` |
| Correct-role positive cases work | `[Pass/N/A/Fail]` | `[Evidence]` |
| Wrong-role cases are denied | `[Pass/N/A/Fail]` | `[Evidence]` |
| Tenant scope derives from trusted authenticated context | `[Pass/N/A/Fail]` | `[Evidence]` |
| Foreign/direct identifiers cannot widen scope | `[Pass/N/A/Fail]` | `[Evidence]` |
| Lists, filters, pagination, aggregates, and relationships remain tenant-safe | `[Pass/N/A/Fail]` | `[Evidence]` |
| Scope-safe not-found/existence privacy is preserved | `[Pass/N/A/Fail]` | `[Evidence]` |
| Ownership and relationship rules cannot be bypassed | `[Pass/N/A/Fail]` | `[Evidence]` |
| Lifecycle/timing/visibility restrictions are enforced | `[Pass/N/A/Fail]` | `[Evidence]` |
| Sensitive fields, logs, errors, files, and tokens are protected | `[Pass/N/A/Fail]` | `[Evidence]` |
| Frontend UI does not substitute for backend authorization | `[Pass/N/A/Fail]` | `[Evidence]` |

Any unresolved authorization, tenant-isolation, secret-exposure, or protected
data-access defect is blocking.

---

## 8. Required Checkpoint Verification

Record exact commands and exact observed results.

### 8.1 Backend Checkpoint

Use for a backend block; otherwise mark `N/A`.

| Verification | Command | Result | Status |
|---|---|---|---|
| Full backend regression suite | `[command]` | `[observed result]` | `[Pass/Fail/N/A]` |
| Backend format check | `[command]` | `[observed result]` | `[Pass/Fail/N/A]` |
| Backend static/lint check | `[command]` | `[observed result]` | `[Pass/Fail/N/A]` |
| Database/migration verification | `[command/method]` | `[observed result]` | `[Pass/Fail/N/A]` |
| Stage-specific security/tenant verification | `[command/method]` | `[observed result]` | `[Pass/Fail/N/A]` |

### 8.2 Frontend Checkpoint

Use for a frontend block; otherwise mark `N/A`.

| Verification | Command | Result | Status |
|---|---|---|---|
| Full frontend test suite | `[command]` | `[observed result]` | `[Pass/Fail/N/A]` |
| Static analysis | `[command]` | `[observed result]` | `[Pass/Fail/N/A]` |
| Format check | `[command]` | `[observed result]` | `[Pass/Fail/N/A]` |
| Required target build | `[command]` | `[observed result]` | `[Pass/Fail/N/A]` |
| Stage-specific routing/session/accessibility verification | `[command/method]` | `[observed result]` | `[Pass/Fail/N/A]` |

Do not report a command as passing unless it was actually run and passed.
Record unavailable tooling and pre-existing failures separately.

---

## 9. Cross-Task and Previous-Stage Regression Review

| Risk surface | Expected behavior | Evidence | Result |
|---|---|---|---|
| `[Cross-task workflow]` | `[Expected]` | `[Tests/code]` | `[Pass/Fail]` |
| `[Shared API/state/schema boundary]` | `[Expected]` | `[Tests/code]` | `[Pass/Fail]` |
| `[Previous Stage path]` | `[Expected]` | `[Regression evidence]` | `[Pass/Fail]` |

Confirm:

- [ ] task-local implementations compose into one coherent block;
- [ ] shared routes/resources/DTOs/state/schema remain compatible;
- [ ] no later task invalidated an earlier task's assumptions;
- [ ] previous accepted Stage paths remain green;
- [ ] no hidden migration/order/session/cache regression exists.

---

## 10. Acceptance-Criteria Coverage

Map every relevant Stage criterion owned or partially owned by this block.

| Stage criterion | Implementing task(s) | Verification evidence | Result |
|---|---|---|---|
| `[Criterion]` | `[Task IDs]` | `[Tests/review evidence]` | `[Pass/Fail/Not verified]` |

A required criterion with missing evidence is not a pass.

---

## 11. Findings

List findings from highest severity to lowest.

| ID | Severity | Finding | Evidence | Required correction |
|---|---|---|---|---|
| `[BR-01]` | `[P1/P2/P3]` | `[Problem]` | `[File/test/location]` | `[Focused fix]` |

Severity:

- `P1` — security, tenant isolation, secret exposure, data loss/corruption, or
  core public-contract breach;
- `P2` — material functional, architecture, lifecycle, integration, or
  regression defect that blocks the checkpoint;
- `P3` — non-blocking maintainability, clarity, or test-quality improvement.

If no findings:

```text
No findings.
P1 = 0
P2 = 0
P3 = 0
```

P3 findings do not automatically expand Stage scope.

---

## 12. Verdict

Choose exactly one:

- `PASS`
- `NOT ACCEPTED`

`PASS` requires:

- all required entry conditions pass;
- `P1 = 0`;
- `P2 = 0`;
- required checkpoint verification passes;
- no unresolved cross-task contract conflict;
- required Stage criteria owned by the block have evidence.

**Verdict:** `[Pending]`

**Reason:** [Concise evidence-based explanation.]

---

## 13. Required Follow-Up

If `PASS`:

- [State the next permitted gate: frontend implementation/checkpoint or Stage
  integration.]

If `NOT ACCEPTED`:

1. preserve this review as read-only evidence;
2. prepare focused implementation contract(s) for the findings;
3. implement, verify, and deliver the fixes;
4. re-run the affected checkpoint verification;
5. obtain `PASS` before proceeding.

Do not fix findings inside this review.
