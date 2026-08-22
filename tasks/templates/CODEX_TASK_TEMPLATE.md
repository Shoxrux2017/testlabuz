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

Start only when status is `Approved`, dependencies are satisfied, and Git
preflight is safe.

This is the complete task-specific contract. Do not create a duplicate
`CODEX-PROMPT` file.

---

## 2. Goal

[One observable implementation outcome.]

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
- [Existing model/resource/DTO/state pattern]
- [Relevant test file]
- [Current behavior/boundary that must remain unchanged]

Inspect only directly relevant implementation/tests plus applicable
`AGENTS.md`. Do not read product docs, roadmap, previous tasks, Stage history,
checkpoint reviews, or closure reviews to determine requirements.

---

## 5. Exact Implementation Contract

Use `N/A — [reason]` when a subsection does not apply.

### 5.1 Behavior and Lifecycle

- [Exact success behavior]
- [State transition/no-op/timestamp/history behavior]
- [Forbidden behavior]
- [Relevant edge case]

### 5.2 API or UI

**API**

- Method/path: `[METHOD /api/v1/...]`
- Input: `[Exact query/body/headers]`
- Success: `[Status + exact response/envelope]`
- Filters/sort/pagination: `[Rules or N/A]`

**UI**

- Route/screen/dialog: `[Location or N/A]`
- States: `[loading/empty/data/error/mutation]`
- Actions/feedback: `[Exact behavior]`
- Navigation/focus/accessibility: `[Rules or N/A]`
- Cache/invalidation/retained state: `[Rules or N/A]`

### 5.3 Persistence and Application State

- Schema/migration: `[Exact change or N/A]`
- Query/read: `[Scope/order/eager loading/query limits]`
- Write/transaction: `[Rows/fields/atomic boundary]`
- No-op/history: `[Rules or N/A]`
- Frontend state/cache: `[Rules or N/A]`

### 5.4 Authorization and Tenant Isolation

- Actor/active-state requirements: `[Exact rules]`
- Trusted tenant scope: `[How derived]`
- Ownership/relationship rule: `[Exact rule]`
- Wrong role/unauthenticated: `[Exact result]`
- Foreign/direct ID: `[Privacy-safe result]`
- Client IDs that must not widen scope: `[Fields/IDs]`

### 5.5 Validation and Errors

| Case | Required result |
|---|---|
| `[Malformed/unknown/protected input]` | `[Status/code/field errors]` |
| `[Scope-safe not found]` | `[Status/code]` |
| `[Business/lifecycle conflict]` | `[Status/code]` |
| `[Unexpected failure]` | `[Safe behavior]` |

Normalization/strict-input rules:

- [Exact trim/case/UUID/timestamp/enum/content-type/body/query behavior]

### 5.6 Concurrency, Idempotency, Async Ownership

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

Changes outside these areas require concrete necessity within scope and must be
reported.

---

## 7. Acceptance Criteria

- [ ] [Primary behavior]
- [ ] [API/UI contract]
- [ ] [Persistence/lifecycle/no-op behavior]
- [ ] [Validation/error behavior]
- [ ] [Authorized case]
- [ ] [Wrong-role/cross-tenant negative case or justified N/A]
- [ ] [Concurrency/idempotency/stale-async case or justified N/A]
- [ ] [Architecture/placement requirement]
- [ ] Focused tests are added/updated and pass.
- [ ] Required focused static/format/regression checks pass.
- [ ] `git diff --check` passes.
- [ ] No unrelated public behavior changed.

---

## 8. Focused Verification

Run only the commands explicitly listed below.

### Focused Tests

```text
[Exact command]
```

Required cases:

- [positive];
- [validation/error];
- [authorization/tenant where applicable];
- [edge/lifecycle/concurrency/async where applicable].

### Format / Static Checks

```text
[Exact command]
```

### Directly Affected Regression

```text
[Exact command]
```

or:

```text
None required — [specific isolation reason].
```

### Always

```text
git diff --check
```

### Boundary

Do not run full backend/frontend suites, full builds, broad E2E, or Phase 2
unless ChatGPT explicitly includes one for a concrete task-specific risk.

Narrow diagnostics/reruns are allowed only to understand a failure.

---

## 9. Delivery Plan

Default execution owner:

```text
Project Owner
```

Recommended branch:

```text
[task/<id>-<short-name>]
```

Recommended commit:

```text
[subject]
```

Allowed bookkeeping files:

```text
[None / exact paths]
```

If Project Owner owns delivery, Codex must not commit, push, open/merge PRs, or
update task/Stage status.

Task acceptance occurs only after focused verification + delivery + final Git
synchronization.

---

## 10. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to
rediscover requirements.

| Source/reference | Decision already encoded above |
|---|---|
| `[spec/Stage reference]` | `[Resolved decision]` |

---

## 11. Codex Final Report

Return:

1. **Implementation:** concise summary.
2. **Changed files:** file → purpose.
3. **Verification:** exact focused commands/results.
4. **Security/tenant:** evidence or justified N/A.
5. **Scope/diff:** non-goals + `git diff --check`.
6. **Delivery:** `Project Owner` by default; no Git delivery performed.
7. **Deviations/blockers:** exact facts.

Do not output `ACCEPTED`; ChatGPT assigns task acceptance after required
delivery.

Do not repeat the contract.
