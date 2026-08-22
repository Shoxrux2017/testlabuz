# Phase 2 Read-Only Block Review — [Stage / Backend or Frontend]

## 1. Review Metadata

| Field | Value |
|---|---|
| Stage | `[Stage number and exact Stage name]` |
| Block | `[Backend / Frontend]` |
| Review mode | `Read-only` |
| Review date | `[YYYY-MM-DD]` |
| Stage index | `[path]` |
| Audited `origin/main` | `[SHA]` |
| Verification execution | `Project Owner` |
| Verdict | `[Pending]` |

ChatGPT owns the review, findings, evidence-validity decisions, and verdict.

Project Owner/CI executes required checkpoint commands.

**Do not use Codex merely to collect Phase 2 evidence.** Codex is used only
after ChatGPT identifies a focused implementation finding that requires code.

---

## 2. Entry Conditions

| Condition | Result | Evidence |
|---|---|---|
| Previous required checkpoint passed | `[Pass/N/A/Fail]` | `[Reference]` |
| All block tasks Accepted / Delivered | `[Pass/Fail]` | `[Task IDs]` |
| Local `main == origin/main` | `[Pass/Fail]` | `[SHAs]` |
| Ahead/behind `0/0` | `[Pass/Fail]` | `[Output]` |
| Working tree clean | `[Pass/Fail]` | `[Status]` |

Any failed required entry condition blocks the checkpoint.

---

## 3. Authoritative Review Inputs

ChatGPT reviews:

- current `origin/main`;
- root/applicable nested `AGENTS.md`;
- `tasks/README.md`;
- Stage index;
- implementation contracts in the block;
- relevant locked `docs/01–09`;
- current implementation/tests;
- delivery evidence;
- prior checkpoint/Stage evidence needed for dependencies.

Codex must not reopen these sources to reinterpret requirements.

---

## 4. Audited Block Inventory

| Task | Delivered outcome | Commit/PR | Result |
|---|---|---|---|
| `[ID]` | `[Outcome]` | `[Reference]` | `[Pass/Fail]` |

Confirm all approved tasks, no hidden scope, coherent cross-task contracts, and
protected previous-Stage behavior.

---

## 5. Scope and Architecture Review

### Backend when applicable

- thin Controllers;
- validation vs stateful rules separated;
- focused Actions/services;
- coherent API/error contracts;
- migrations/schema/constraints/indexes coherent;
- tenant-safe bounded deterministic queries;
- atomic multi-write operations;
- locking/concurrency/idempotency coherent;
- no hidden workflow in Resources/Models;
- no N+1/unbounded reads;
- no unjustified shared infrastructure.

### Frontend when applicable

- feature-first/layer placement;
- data/domain/presentation separated;
- widgets do not call Dio/parse JSON;
- DTO/repository/controller/provider contracts agree;
- router/session/auth state coherent;
- stale async completions safe;
- loading/empty/data/error/mutation states coherent;
- cache ownership/invalidation narrow;
- backend authority preserved;
- focus/keyboard/accessibility/responsiveness where required;
- no competing router/client/state/cache architecture.

---

## 6. Security and Tenant Isolation

Verify where applicable:

- unauthenticated denial;
- active-user/institution gates;
- correct-role positive behavior;
- wrong-role denial;
- trusted tenant scope;
- foreign/direct IDs cannot widen scope;
- lists/filters/pagination/relationships tenant-safe;
- existence privacy;
- ownership/relationship restrictions;
- lifecycle/timing/visibility restrictions;
- sensitive fields/logs/errors/files/tokens protected;
- frontend visibility does not replace backend authorization.

Any unresolved access/tenant/secret defect is P1.

---

## 7. Checkpoint Verification

Execution owner:

```text
Project Owner
```

or approved CI.

### Backend

| Verification | Command | Result |
|---|---|---|
| Full backend suite | `[command]` | `[result]` |
| Format/static | `[command]` | `[result]` |
| DB/migration/security checks | `[command/method]` | `[result]` |

### Frontend

| Verification | Command | Result |
|---|---|---|
| Full frontend suite | `[command]` | `[result]` |
| Analyze | `[command]` | `[result]` |
| Format | `[command]` | `[result]` |
| Target build | `[command]` | `[result]` |
| Stage-specific routing/accessibility | `[method]` | `[result]` |

Never claim PASS for a command that was not run.

---

## 8. Evidence Validity After Findings/Fixes

The initial checkpoint requires its complete planned evidence.

If a finding later requires a focused fix:

- Codex implements + runs only focused task verification for the fix;
- ChatGPT decides which already-PASS checkpoint evidence remains valid;
- Project Owner/CI reruns only materially invalidated checkpoint checks;
- any required command that previously failed must eventually pass;
- shared auth/API/schema/security/router/client/infrastructure changes receive
  conservative rerun treatment.

| Evidence | Prior result | Still valid? | Rerun reason/result |
|---|---|---|---|
| `[check]` | `[PASS/FAIL]` | `[Yes/No]` | `[reason/result]` |

---

## 9. Cross-Task / Previous-Stage Regression Review

| Risk surface | Expected | Evidence | Result |
|---|---|---|---|
| `[workflow]` | `[expected]` | `[evidence]` | `[Pass/Fail]` |

---

## 10. Acceptance-Criteria Coverage

| Stage criterion | Implementing task(s) | Evidence | Result |
|---|---|---|---|
| `[criterion]` | `[IDs]` | `[tests/review]` | `[Pass/Fail]` |

Missing required evidence is not a pass.

---

## 11. Findings

| ID | Severity | Finding | Evidence | Required correction |
|---|---|---|---|---|
| `[BR-01]` | `[P1/P2/P3]` | `[problem]` | `[location]` | `[focused fix]` |

If none:

```text
No findings.
P1 = 0
P2 = 0
P3 = 0
```

---

## 12. Verdict

Choose exactly:

```text
PASS
NOT ACCEPTED
```

PASS requires entry conditions, valid checkpoint verification, P1=0, P2=0, no
unresolved cross-task conflict, and required Stage-criterion evidence.

If NOT ACCEPTED:

1. preserve review evidence;
2. ChatGPT prepares focused fix contract(s);
3. Codex implements + focused-verifies the fix;
4. Project Owner/CI executes any invalidated checkpoint rerun;
5. ChatGPT re-evaluates evidence validity and verdict.

Do not fix code inside the read-only review.
