# Codex Implementation Contract: [Task ID — Short Title]

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `[S00-AREA-000]` |
| Stage | `[Stage number and exact name]` |
| Area | `[Backend / Frontend / Integration]` |
| Status | `Draft` |
| Depends on | `[Task IDs or None]` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |

Start only when status is `Approved`, required dependencies are
`Accepted / Delivered`, and Git preflight from `tasks/README.md` is safe.

This is the complete task-specific contract. Do not create a duplicate
`CODEX-PROMPT` file.

---

## 2. Goal

[One observable outcome.]

---

## 3. Scope

### Included

- [Required change]
- [Required change]

### Non-Goals

- [Explicitly excluded adjacent behavior]
- [Refactor/package/schema/API/UI work not included]

---

## 4. Current Implementation Context

Only record facts Codex needs to find the correct code quickly.

- [Existing route/controller/action/repository/provider/widget]
- [Existing model/resource/DTO/state pattern to reuse]
- [Relevant test file]
- [Current behavior and boundary that must remain unchanged]

Inspect only the directly relevant implementation and tests. Do not read product
specifications, roadmap, architecture/database/API documents, previous tasks,
Stage history, or closure reviews to determine requirements.

---

## 5. Exact Implementation Contract

Use `N/A — [reason]` for an inapplicable subsection.

### 5.1 Behavior and Lifecycle

- [Exact success behavior]
- [State transition / no-op / timestamp / history behavior]
- [Forbidden behavior]
- [Relevant edge case]

### 5.2 API or UI

**API**

- Method/path: `[METHOD /api/v1/...]`
- Input: `[Exact query/body/headers]`
- Success: `[Status + exact response/envelope]`
- List/filter/sort/pagination: `[Rules or N/A]`

**UI**

- Route/screen/dialog: `[Location or N/A]`
- States: `[loading/empty/data/error/mutation states]`
- Actions and feedback: `[Exact behavior]`
- Navigation/focus/accessibility: `[Rules or N/A]`
- Cache/invalidation/retained state: `[Rules or N/A]`

### 5.3 Persistence and Application State

- Schema/migration: `[Exact change or N/A]`
- Query/read: `[Scope, ordering, eager loading, query limits]`
- Write/transaction: `[Rows/fields/atomic boundary]`
- No-op/history: `[Rules or N/A]`
- Frontend state/cache: `[Rules or N/A]`

### 5.4 Authorization and Tenant Isolation

- Actor and active-state requirements: `[Exact roles/checks]`
- Trusted tenant scope: `[How derived]`
- Ownership/relationship rule: `[Exact rule]`
- Wrong role/unauthenticated: `[Exact result]`
- Foreign/direct ID: `[Privacy-safe result]`
- Client identifiers that must not expand scope: `[Fields/IDs]`

### 5.5 Validation and Errors

| Case | Required result |
|---|---|
| `[Malformed/unknown/protected input]` | `[Status/code/field errors]` |
| `[Scope-safe not found]` | `[Status/code]` |
| `[Business/lifecycle conflict]` | `[Status/code]` |
| `[Unexpected failure]` | `[Safe behavior]` |

Normalization/strict-input rules:

- [Exact trimming/case/UUID/timestamp/enum/content-type/body/query behavior]

### 5.6 Concurrency, Idempotency, and Async Ownership

- Transaction/lock/constraint: `[Rule or N/A]`
- Idempotency/replay/duplicate mutation: `[Rule or N/A]`
- Concurrent conflict response: `[Rule or N/A]`
- Frontend stale-completion protection: `[Rule or N/A]`

### 5.7 Architecture and Placement

- Owning feature/layer: `[Exact boundary]`
- Existing abstraction to reuse: `[Name/path or None]`
- New abstraction allowed: `[Exact boundary or None]`
- Logic forbidden in controller/widget/resource/model/etc.: `[Restriction]`
- Shared infrastructure that must remain unchanged: `[Boundary]`

---

## 6. Expected Files and Areas

| Path or area | Action | Reason |
|---|---|---|
| `[path]` | `[Inspect/Modify/Create/Test]` | `[Reason]` |
| `[path]` | `[Inspect/Modify/Create/Test]` | `[Reason]` |

Changes outside these areas require a concrete necessity within scope and must
be reported. Unrelated files must not change.

---

## 7. Acceptance Criteria

- [ ] [Primary behavior]
- [ ] [API/UI contract]
- [ ] [Persistence/lifecycle/no-op behavior]
- [ ] [Validation/error behavior]
- [ ] [Authorized case]
- [ ] [Wrong-role/cross-tenant negative case, or justified N/A]
- [ ] [Concurrency/idempotency/stale-async case, or justified N/A]
- [ ] [Architecture/placement requirement]
- [ ] Required focused tests/checks pass.
- [ ] `git diff --check` passes.
- [ ] No unrelated behavior or public contract changed.
- [ ] No blocking security/tenant/scope finding remains.

---

## 8. Focused Tests and Verification

ChatGPT defines the minimum sufficient task-level verification in this contract.

Codex runs only the focused verification explicitly listed below. Full
backend/frontend suites, full builds, broad E2E, Phase 2, and Stage-level
verification belong to later checkpoints unless this contract explicitly
requires broader verification for a concrete task-specific regression risk.

### Focused Tests

```text
[Exact command]
```

Required cases:

- [positive];
- [validation/error];
- [authorization/tenant, if applicable];
- [edge/lifecycle/concurrency/async, if applicable].

### Format / Static Checks

```text
[Exact command]
```

### Directly Affected Regression

```text
[Exact command]
```

Or:

```text
None required — [specific isolation reason].
```

### Project Owner Manual Check

```text
[Exact steps and expected result]
```

Or:

```text
Not required — [reason].
```

This check is Project Owner-owned unless the contract explicitly states
otherwise. Codex must not claim it passed unless Codex was explicitly assigned
to execute it.

### Always

```text
git diff --check
```

Then verify the complete diff:

- only necessary files changed;
- contract and non-goals are preserved;
- no unrelated refactor/format churn;
- no weakened tests, debug code, secrets, or temporary artifacts;
- no unintended API/schema/route/serialization change;
- security/tenant boundaries and pre-existing user work are intact.

Narrow diagnostic reruns are allowed only to understand or confirm a concrete
failure.

Do not independently expand into full backend/frontend suites, full builds,
broad E2E, Phase 2, or unrelated regression areas. If implementation necessarily
touches shared infrastructure beyond the verification assumptions above, report
the exact regression risk or contract mismatch instead of silently launching
broader verification.

---

## 9. Delivery

Follow root `AGENTS.md` and `tasks/README.md`.

Default Stage 5+ owner:

```text
Project Owner
```

Delivery plan:

- Branch: `[Name/rule]`
- Commit: `[Subject/convention]`
- PR: `[Requirement or N/A]`
- Allowed bookkeeping files: `[Paths or None]`

When `Delivery execution = Project Owner`:

- Codex must not commit;
- Codex must not push;
- Codex must not open or merge a PR;
- Codex must not update task/Stage bookkeeping;
- Codex stops after implementation, focused verification, and scope/diff
  self-check;
- Codex reports the current Git state required for safe handoff.

Task acceptance occurs only after the approved delivery completes, the accepted
result is present on `origin/main`, local `main == origin/main`, ahead/behind is
`0/0`, and the worktree is clean.

Only if this contract explicitly changes `Delivery execution` to `Codex` may
Codex perform the assigned delivery steps. In that exceptional case, if safe
delivery cannot complete, report `DELIVERY BLOCKED`.

---

## 10. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to
rediscover or reinterpret requirements.

| Source/reference | Decision already encoded above |
|---|---|
| `[Stage index / specification section]` | `[Resolved decision]` |

---

## 11. Codex Final Report

Return one implementation status:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

Use `DELIVERY BLOCKED` only when this contract explicitly assigns delivery to
Codex and that delivery cannot complete safely.

Return:

1. **Status:** `IMPLEMENTATION COMPLETE`, `BLOCKED`, or justified
   `DELIVERY BLOCKED`.
2. **Implementation:** concise result.
3. **Changed files:** file → purpose.
4. **Acceptance criteria:** concise PASS/FAIL evidence for implementation-owned
   criteria.
5. **Focused verification:** exact commands and results.
6. **Security/tenant:** evidence or justified N/A.
7. **Scope/diff:** non-goals, `git diff --check`, no unrelated changes.
8. **Delivery handoff:** `Project Owner` by default, plus current Git state.
9. **Deviations/blockers:** exact facts.

Do not output task `Accepted`. ChatGPT assigns acceptance only after required
focused verification and approved delivery are complete.

Do not repeat the contract or paste large successful command logs. Summarize
successful evidence compactly. Include detailed output only when it is needed to
explain a failure or blocker.

If a product, architecture, API, database, security, tenant, lifecycle,
concurrency, idempotency, or unresolved UX decision is missing, return
`BLOCKED` instead of making that decision.
