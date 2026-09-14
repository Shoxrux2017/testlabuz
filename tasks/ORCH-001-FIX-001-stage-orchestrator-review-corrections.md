# ORCH-001-FIX-001 — Stage Orchestrator acceptance-review corrections

## Status

`Approved`

## Scope

Fix only the Stage Orchestrator implementation introduced by `ORCH-001`.

Allowed files:

```text
.github/stage-orchestrator/orchestrator.py
.github/stage-orchestrator/tests/test_orchestrator.py
.github/stage-orchestrator/README.md
```

Change `.github/workflows/stage-orchestrator.yml` only if a correction is strictly
required by these findings.

Do not change Stage 7/8 task files, indexes, product docs, backend, frontend,
integration assets, or `AGENTS.md`.

---

## Finding 1 — P1: Implementation Readiness Gate can be bypassed

Current behavior hands any incomplete DOC/BE/FE/INT task with an existing contract
file to Codex, even when the authoritative current task status is `Draft`,
`Blocked`, `Prepared`, `NOT ACCEPTED`, `Rejected`, `Implementation complete`,
or similar.

This violates the preserved TestLabUz role boundary:

```text
Codex = implement one approved implementation contract
```

### Required correction

For every normal implementation task (`DOC-*`, numbered `BE-*`, numbered `FE-*`,
numbered `INT-*`):

1. Completed tasks keep the existing final-state semantics.
2. An incomplete task may become a Codex candidate only when the **current
   authoritative readiness/review status** explicitly indicates `Approved`
   (or an already-established equivalent current-ready wording supported by the
   Stage index format).
3. Historical/planning-only approval columns must not authorize current execution.
4. `Draft`, `Blocked`, `Prepared`, `NOT ACCEPTED`, `Rejected`, `Not started`,
   `Implementation complete`, `PR merged`, `PASS` alone, and unknown status text
   must never produce `TASK_READY`, `FRONTEND_TASK_READY`, or
   `INTEGRATION_TASK_READY`.
5. If an incomplete normal task is not currently approved, stop safely with
   `BLOCKED` and an exact reason telling the Project Owner that ChatGPT must
   perform/re-record the Implementation Readiness or fix/review decision.
6. Phase-2 checkpoint rows are not Codex implementation tasks. Preserve their
   separate prepared/review semantics.

Do not infer current readiness merely from contract-file existence.

---

## Finding 2 — P1: Owner approval state is forgeable through issue-body editing

The hidden issue marker is currently trusted as approval authority on refresh.

For a personal-account GitHub repository, collaborators can edit issue
descriptions. Therefore a non-owner collaborator could alter:

```json
{"stage":8,"approvals":[]}
```

to:

```json
{"stage":8,"approvals":["frontend"]}
```

and a later refresh would accept that approval without an owner `/approve ...`
command.

This violates:

```text
only repository owner can change approval state
```

### Required correction

Keep the hidden marker because ORCH-001 requires it, but make it a **cache/display
projection**, not the security authority.

Use GitHub issue comments as verifiable approval receipts, with these rules:

1. A state-changing approval/rejection originates only from a `created`
   `issue_comment` event whose exact author login equals the repository owner.
2. Record an orchestrator receipt using a bot-created comment that contains at
   minimum:
   - Stage;
   - source owner-comment ID;
   - exact command;
   - machine-readable receipt marker.
3. Extend comment validation to inspect `created_at` and `updated_at`.
4. A source owner command used as authority must still exist, still have the exact
   owner login, still contain the exact command, and be unedited
   (`created_at == updated_at`).
5. A bot receipt used as authority must still exist, be authored by
   `github-actions[bot]`, contain the expected source comment ID/command, and be
   unedited.
6. Reconstruct approval state from valid receipts in deterministic comment order
   on every refresh.
7. The hidden marker must never be accepted as sufficient proof of approval.
8. If marker state disagrees with reconstructed receipt state, fail safely as
   `BLOCKED` (or repair only through a deterministic owner-safe path that cannot
   grant an approval absent a valid owner receipt).
9. A collaborator editing/deleting an owner command or bot receipt may cause a
   safe block/approval loss, but must never be able to create or retain an
   unauthorized approval.
10. No new secret, external database, OpenAI API, third-party package, or
    repository-content write is allowed.

Crash/idempotency behavior must remain safe. Prefer receipt-first persistence so
a failed issue-body update cannot create an approval that has no authoritative
receipt.

---

## Finding 3 — P2: Future gates can be pre-approved before the orchestrator stops there

Current command handling accepts:

```text
/approve frontend
/approve integration
/approve closure
```

at any Stage state. The approval is stored and later causes the corresponding
future owner gate to be skipped as soon as its prerequisite checkpoint becomes
PASS.

This contradicts the required behavior:

```text
reach important gate
→ stop
→ ask owner
→ receive owner decision
→ continue
```

### Required correction

Accept an `/approve <gate>` only when the **pre-command evaluated state** is the
matching gate:

```text
/approve frontend
    only in OWNER_FRONTEND_APPROVAL_REQUIRED

/approve integration
    only in OWNER_INTEGRATION_APPROVAL_REQUIRED

/approve closure
    only in OWNER_CLOSURE_APPROVAL_REQUIRED
```

If approval is issued early, late, or at a different gate:

- do not change approval state;
- post a concise non-secret "not applicable in current state" result;
- keep the Stage at its correct current state.

`/reject <gate>` may remove only the named existing approval, preserving the
ORCH-001 rule.

---

## Finding 4 — P2: Contradictory negative task/checkpoint statuses can be ignored

Current conflict detection recognizes `FAIL`/`Rejected` but can miss negative
forms such as `NOT ACCEPTED` or `NOT PASS` when another authoritative column
contains positive completion evidence.

Examples that must not advance:

```text
Completed readiness/review status = NOT ACCEPTED
Delivery/execution status = Accepted / Delivered

Completed readiness/review status = NOT ACCEPTED
Delivery/execution status = PASS
```

### Required correction

Introduce explicit positive/negative outcome classification.

At minimum treat these as negative/conflicting evidence when applicable:

```text
NOT ACCEPTED
REJECTED
FAIL
FAILED
NOT PASS
BLOCKED
NOT DELIVERED
```

If positive final evidence and negative final/review evidence coexist for the
same task/checkpoint, return `BLOCKED` with the exact Task ID.

Do not silently choose one column over the other.

Unknown status wording that materially affects readiness/completion must fail
safe rather than authorize the next step.

---

## Required tests

Keep all existing valid tests and add focused coverage for at least:

1. incomplete normal task `Draft` -> not Codex-ready;
2. incomplete normal task `Blocked` -> not Codex-ready;
3. incomplete normal task `Prepared` -> not Codex-ready;
4. incomplete normal task `NOT ACCEPTED` -> not Codex-ready;
5. incomplete normal task `Rejected` -> not Codex-ready;
6. incomplete normal task `Implementation complete` -> not Codex-ready;
7. normal task with current `Approved` status -> ready when dependencies and
   contract are valid;
8. historical/planning approval alone does not authorize execution;
9. early `/approve frontend` before backend Phase 2 PASS is not persisted;
10. after the backend later becomes PASS, the orchestrator still stops at
    `OWNER_FRONTEND_APPROVAL_REQUIRED`;
11. early `/approve integration` is not persisted;
12. early `/approve closure` is not persisted;
13. correct gate-time owner approval advances exactly one gate;
14. non-owner cannot create approval by editing the hidden marker;
15. marker approval without valid owner command + bot receipt is rejected;
16. edited owner command cannot authorize approval;
17. edited bot receipt cannot authorize approval;
18. deleted/missing authoritative receipt cannot preserve approval;
19. duplicate owner event/receipt remains idempotent;
20. API failure between receipt/body operations fails safe without creating
    marker-only authority;
21. `NOT ACCEPTED` + `Accepted / Delivered` -> `BLOCKED`;
22. `NOT ACCEPTED` + `PASS` checkpoint evidence -> `BLOCKED`;
23. `NOT DELIVERED` conflicting with delivered completion -> `BLOCKED`;
24. existing Stage-7-style extra-column fixture still parses correctly.

No real GitHub network in unit tests.

---

## Verification

Run:

```text
python3 -m unittest discover -s .github/stage-orchestrator/tests -p 'test_*.py'
python3 .github/stage-orchestrator/orchestrator.py --self-check
git diff --check
```

Also perform focused diff review proving:

- only approved orchestrator files changed;
- no product/Stage task/index file changed;
- owner approval cannot be derived from issue marker alone;
- only a current owner command at the matching gate can grant approval;
- non-approved implementation tasks can never be handed to Codex;
- contradictory authoritative statuses fail safe;
- no OpenAI/Codex API, new secret, auto-merge, or automatic Stage-close path was added.

Do not run backend/frontend full suites or builds.

---

## Delivery

Do not commit, push, create PR, merge, or update Stage bookkeeping.

Return:

```text
IMPLEMENTATION COMPLETE
```

or:

```text
BLOCKED
```

with changed files, focused verification results, security/gate confirmation,
scope confirmation, `git diff --check`, and current `git status --short`.
