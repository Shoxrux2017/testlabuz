# Stage Orchestrator

This standard-library Python controller maintains one `[Orchestrator] Stage N
Control` issue. `tasks/STAGE_<NN>_TASK_INDEX.md` remains the sole source of task
order, dependencies, acceptance, delivery, checkpoint results, and Stage closure.
The hidden JSON marker is only a cache/display projection of owner approvals.
Approval authority comes from bot-created receipts and their original owner
comments. Both must still exist, match exactly, and be unedited. Every refresh
reconstructs approvals from those receipts in source-comment order. Editing the
marker cannot grant approval; invalid evidence or a cache disagreement stops
with `BLOCKED` and a reason.

## Run and refresh

In GitHub, open **Actions → Stage Orchestrator → Run workflow**, select `main`,
enter a positive integer in **stage** (for example `8`), and run. The workflow
always checks out trusted `main`, including for manual runs and PR events.

Other refresh triggers are Stage-index changes pushed to `main`, a supported
comment on the exact control issue title, and a merged PR targeting `main` whose
title, body, or branch contains a supported Stage task ID. PR merges only refresh
the issue; they never change acceptance, delivery, or PASS evidence. Runs are
serialized to prevent duplicate issue creation and lost concurrent updates.

## Owner commands

```text
/status
/approve frontend
/reject frontend
/approve integration
/reject integration
/approve closure
/reject closure
```

Only a newly created comment by the exact owner login from `GITHUB_REPOSITORY`
may originate an approval/rejection. Other users receive one denial per command.
`/status` never grants approval. Each rejection removes only its named approval.
An approval is applicable only at its matching stopped gate:

| Command | Required pre-command state |
|---|---|
| `/approve frontend` | `OWNER_FRONTEND_APPROVAL_REQUIRED` |
| `/approve integration` | `OWNER_INTEGRATION_APPROVAL_REQUIRED` |
| `/approve closure` | `OWNER_CLOSURE_APPROVAL_REQUIRED` |

Early, late, or wrong-gate approvals receive a not-applicable result and cannot
skip a later gate. Send a new owner comment after the gate is reached. Repeated
events and identical receipts are idempotent; delayed older commands cannot undo
later owner commands.

Each bot receipt records the Stage, source comment ID, exact command, evaluated
state, and result. The controller validates both `created_at` and `updated_at`
and rejects edited authority. Receipts are saved before the issue-body cache.
If the body update fails, rerun the original owner-comment workflow event to
finish that exact receipt's cache update. A normal refresh blocks on a mismatch.
Missing or edited evidence requires repair; cached approvals alone cannot keep
a gate open. Legacy markers without valid receipts require fresh gate-time owner
decisions, after unproven cached approvals are cleared.

## States and handoff

| State | Next action |
|---|---|
| `WAITING_FOR_STAGE_INDEX` | Save/merge the Stage planning files. |
| `WAITING_FOR_STAGE_APPROVAL` | Obtain and record ChatGPT decomposition approval. |
| `WAITING_FOR_TASK_CONTRACT` | Save/merge the indicated approved contract. |
| `TASK_READY` | Give the exact DOC/backend contract shown to Codex. |
| `BACKEND_PHASE_2_READY` | ChatGPT performs Backend Phase 2; Owner/CI executes its checks. |
| `OWNER_FRONTEND_APPROVAL_REQUIRED` | Owner comments `/approve frontend`. |
| `FRONTEND_TASK_READY` | Give the exact frontend contract shown to Codex. |
| `FRONTEND_PHASE_2_READY` | ChatGPT performs Frontend Phase 2; Owner/CI executes its checks. |
| `OWNER_INTEGRATION_APPROVAL_REQUIRED` | Owner comments `/approve integration`. |
| `INTEGRATION_TASK_READY` | Give the exact integration contract shown to Codex. |
| `OWNER_CLOSURE_APPROVAL_REQUIRED` | Owner comments `/approve closure`. |
| `CLOSURE_REVIEW_READY` | ChatGPT Stage Closure Review may be performed. |
| `BLOCKED` | Resolve the displayed ambiguity and refresh. |
| `STAGE_CLOSED` | Closure already exists in authoritative bookkeeping; close the control issue. |

An incomplete DOC/BE/FE/INT task is offered to Codex only when its current
authoritative readiness/review status explicitly approves execution. Historical
or planning approval and an existing contract file cannot authorize execution.
Non-approved tasks block until ChatGPT performs/re-records the Implementation
Readiness or fix/review decision. Phase 2 keeps its separate review semantics.
Positive completion evidence conflicting with negative review/final evidence
(including NOT ACCEPTED, NOT PASS, or NOT DELIVERED), and material unknown status
wording, block with the exact Task ID.

Codex receives only the indicated implementation contract and follows applicable
engineering rules and that contract's context/verification boundaries. ChatGPT
retains architecture, readiness, acceptance, Phase 2, integration, and closure
review authority. Project Owner/CI retains delivery, broad suites/builds,
real-stack execution, and manual approvals.

The controller reads table columns by name, including separate review/delivery
columns, strict task IDs, shorthand task dependencies and ranges, Phase 2
dependency names, and the existing closure bookkeeping row. Unknown dependency
wording, contradictory statuses, unsafe paths, and missing mandatory checkpoints
block instead of being guessed. Missing contract files prevent task handoff.

The workflow only reads repository contents/PRs and writes control issues and
command result comments. It does not edit indexes/contracts/product code, invoke
agents, use OpenAI/Codex APIs or quota, execute Markdown, create branches, commit,
push, merge, or close a Stage. Closure approval only releases ChatGPT review; the
control issue closes only after authoritative Stage closure is recorded. If an
active control issue is manually closed, reopen it and refresh to resume.

## Local verification

```text
python3 -m unittest discover -s .github/stage-orchestrator/tests -p 'test_*.py'
python3 .github/stage-orchestrator/orchestrator.py --self-check
git diff --check
```

Tests and self-check use no network. Normal Actions runs use only the provided
`GITHUB_TOKEN` with `contents: read`, `issues: write`, and `pull-requests: read`.
