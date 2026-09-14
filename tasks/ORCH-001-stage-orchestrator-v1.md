# ORCH-001 — TestLabUz Stage Orchestrator v1

## Status

`Approved`

## Type

Cross-stage workflow infrastructure.

This is **not** a Stage 8 product task and must not change Stage 8 business, API,
database, frontend, lifecycle, scoring, authorization, or tenant-isolation
behavior.

---

## 1. Goal

Implement a lightweight GitHub-native Stage Orchestrator that:

1. reads the authoritative Stage task index;
2. determines the next permitted workflow step;
3. maintains one GitHub Stage Control issue;
4. stops at explicit Project Owner approval gates;
5. resumes only after the Project Owner gives the required command;
6. never replaces ChatGPT architecture/review decisions;
7. never replaces Codex as implementation agent;
8. never marks a Stage closed by itself.

The orchestrator is a workflow/state-machine controller only.

---

## 2. Existing workflow that must be preserved

Roles remain:

```text
ChatGPT
= requirements / architecture / API / DB / security / lifecycle decisions
= task decomposition
= Implementation Readiness Gate
= task acceptance review
= Backend Phase 2 review
= Frontend Phase 2 review
= Integration review
= Stage Closure Review

Codex
= implement one approved implementation contract
= run only contract-defined focused verification
= do not redesign product/API/DB/security/lifecycle behavior

Project Owner / CI
= routine Git/GitHub delivery
= broad checkpoint suites/builds
= real-stack execution
= manual approvals
```

Do not change this role separation.

---

## 3. Source of truth

For Stage `N`, the authoritative orchestration input is:

```text
tasks/STAGE_<NN>_TASK_INDEX.md
```

Examples:

```text
tasks/STAGE_07_TASK_INDEX.md
tasks/STAGE_08_TASK_INDEX.md
```

Do **not** create a second task/dependency/status database.

The GitHub control issue may persist only orchestrator-specific owner approvals
that do not belong in the Stage task index.

The orchestrator must never modify product/task state merely because it observes
a PR merge.

---

## 4. Required files

Create only:

```text
.github/workflows/stage-orchestrator.yml
.github/stage-orchestrator/orchestrator.py
.github/stage-orchestrator/README.md
.github/stage-orchestrator/tests/test_orchestrator.py
```

A tiny local test fixture may be added under:

```text
.github/stage-orchestrator/tests/fixtures/
```

only if genuinely required.

Do not modify:

```text
docs/01-business-overview.md
docs/02-user-roles.md
docs/03-features.md
docs/04-user-flows.md
docs/05-business-rules.md
docs/06-roadmap.md
docs/07-architecture.md
docs/08-database.md
docs/09-api-contracts.md

backend/
frontend/
docker/

tasks/STAGE_07_*
tasks/STAGE_08_*
tasks/backend/
tasks/frontend/
tasks/integration/
tasks/README.md
AGENTS.md
backend/AGENTS.md
frontend/AGENTS.md
```

This task is workflow infrastructure only.

---

## 5. Technology constraints

Use:

```text
GitHub Actions
Python 3 standard library only
GitHub REST API through repository-provided GITHUB_TOKEN
```

Do not add:

```text
OpenAI API
Codex API
third-party Python packages
new repository secrets
external database
Redis
external queue
external SaaS workflow engine
```

This v1 must not consume ChatGPT/Codex quota during ordinary orchestration.

---

## 6. GitHub token permissions

The workflow must use least privilege:

```yaml
permissions:
  contents: read
  issues: write
  pull-requests: read
```

Do not request:

```text
contents: write
actions: write
deployments: write
packages: write
administration permissions
```

No auto-merge capability is allowed.

---

## 7. Workflow triggers

Support these triggers.

### 7.1 Manual refresh

```text
workflow_dispatch
```

Input:

```text
stage
```

Stage must be a positive integer.

Example:

```text
8
```

### 7.2 Stage-index update

On push to `main` when a file matching:

```text
tasks/STAGE_*_TASK_INDEX.md
```

changes.

Detect the Stage number from the changed path safely.

### 7.3 Owner command

```text
issue_comment
```

Only act when the issue title exactly follows:

```text
[Orchestrator] Stage <N> Control
```

### 7.4 Merged PR refresh

On merged PR, attempt to detect a Stage task ID from the PR title/body/head branch:

```text
S<NN>-...
```

A merged PR may trigger a **refresh only**.

A PR merge must never by itself mark a task:

```text
Accepted
Delivered
PASS
```

The Stage index remains authoritative.

---

## 8. Stage Control issue

For every active Stage maintain at most one open issue:

```text
[Orchestrator] Stage <N> Control
```

Example:

```text
[Orchestrator] Stage 8 Control
```

Repeated workflow runs must reuse the same issue.

Do not create duplicates.

### 8.1 Issue body

The generated body must show:

```text
Stage
Current state
Authoritative Stage index path
Observed Stage status
Current/next task
Current/next checkpoint
Dependency result
Owner approvals already granted
Exact next action
Exact contract file path when applicable
Blocking/error reason when applicable
Supported owner commands
Last refresh SHA/time
```

Keep the body concise.

### 8.2 Machine-readable metadata

Persist orchestrator-only approvals in a hidden HTML comment.

Example format:

```html
<!-- TESTLABUZ_ORCHESTRATOR
{"stage":8,"approvals":["frontend"]}
-->
```

Validate the JSON before using it.

Do not persist product state in this marker.

---

## 9. Owner commands

Support exactly:

```text
/status

/approve frontend
/reject frontend

/approve integration
/reject integration

/approve closure
/reject closure
```

### 9.1 Authorization

Only the GitHub repository owner may execute state-changing commands.

Determine the repository owner from:

```text
GITHUB_REPOSITORY
```

For:

```text
Shoxrux2017/testlabuz
```

only:

```text
Shoxrux2017
```

may approve/reject.

Do not trust:

```text
author_association
display name
issue assignee
PR author
```

as a substitute for exact owner login.

An unauthorized state-changing command must:

1. make no state change;
2. leave approvals unchanged;
3. post one concise denial comment.

`/status` may be allowed as read-only refresh, but it must never change approvals.

---

## 10. Required states

Support at minimum:

```text
WAITING_FOR_STAGE_INDEX
WAITING_FOR_STAGE_APPROVAL
WAITING_FOR_TASK_CONTRACT

TASK_READY

BACKEND_PHASE_2_READY
OWNER_FRONTEND_APPROVAL_REQUIRED
FRONTEND_TASK_READY

FRONTEND_PHASE_2_READY
OWNER_INTEGRATION_APPROVAL_REQUIRED
INTEGRATION_TASK_READY

OWNER_CLOSURE_APPROVAL_REQUIRED
CLOSURE_REVIEW_READY

BLOCKED
STAGE_CLOSED
```

---

## 11. Task ID recognition

Recognize task/checkpoint IDs by strict regex.

Supported forms:

```text
S<NN>-DOC-<number>
S<NN>-BE-<number>
S<NN>-BE-PHASE-2
S<NN>-FE-<number>
S<NN>-FE-PHASE-2
S<NN>-INT-<number>
```

Do not accept arbitrary strings as task IDs.

Parser must tolerate existing TestLabUz Stage-index table variants with extra
review/status/delivery columns.

Do not depend on one fixed column count.

---

## 12. Completion semantics

### 12.1 Normal implementation task

A normal task is complete only when the authoritative Stage index represents the
required accepted/delivered state.

The parser must tolerate existing wording variants such as:

```text
Accepted
Accepted / Delivered
Accepted / Delivered / PASS
PASS — implemented and accepted
```

Do not treat:

```text
Approved
Prepared
Implementation complete
PR merged
```

alone as final acceptance.

### 12.2 Phase 2 checkpoint

A Phase 2 checkpoint is complete only when its authoritative row clearly contains:

```text
PASS
```

### 12.3 Integration

Integration is complete only when the authoritative Stage index clearly records
its required accepted/delivered/PASS state according to the index format.

### 12.4 Stage closure

`STAGE_CLOSED` may be recognized only when authoritative Stage bookkeeping
already indicates the Stage is closed/PASS.

Owner `/approve closure` does **not** close the Stage.

---

## 13. Transition rules

### 13.1 No Stage index

If:

```text
tasks/STAGE_<NN>_TASK_INDEX.md
```

does not exist:

```text
WAITING_FOR_STAGE_INDEX
```

Next action must explain that Stage planning files must first be saved/merged.

### 13.2 Stage not approved

If the index exists but Stage/decomposition status is still Draft/not approved:

```text
WAITING_FOR_STAGE_APPROVAL
```

Do not authorize implementation.

### 13.3 Documentation / entry tasks

If Stage has `S<NN>-DOC-*` entry tasks, they must complete in index/dependency
order before backend production work.

If the next contract path is missing from repository:

```text
WAITING_FOR_TASK_CONTRACT
```

### 13.4 Backend

Backend production tasks proceed only in the Stage index dependency/order.

When a backend task is the next valid candidate:

```text
TASK_READY
```

The control issue must display:

```text
Next implementation candidate: <task ID>
Contract: <exact path>
Give this exact contract to Codex.
```

Do not tell Codex to read:

```text
STAGE task index
roadmap
previous tasks
Stage history
closure reviews
product docs
```

unless the implementation contract itself explicitly permits a particular file.

### 13.5 Backend checkpoint

After all backend implementation tasks are accepted/delivered:

```text
BACKEND_PHASE_2_READY
```

Frontend must remain blocked until backend Phase 2 is authoritative `PASS`.

If backend implementation tasks exist but the Stage index has no backend Phase 2
checkpoint:

```text
BLOCKED
```

Do not guess that the checkpoint is unnecessary.

### 13.6 Frontend owner gate

After backend Phase 2 `PASS`:

```text
OWNER_FRONTEND_APPROVAL_REQUIRED
```

Remain stopped until repository owner comments:

```text
/approve frontend
```

After approval, proceed to first incomplete frontend task.

`/reject frontend` removes only the frontend approval.

### 13.7 Frontend

For valid next frontend task:

```text
FRONTEND_TASK_READY
```

After all frontend tasks are accepted/delivered:

```text
FRONTEND_PHASE_2_READY
```

If frontend tasks exist but the Stage index has no frontend Phase 2 checkpoint:

```text
BLOCKED
```

Integration remains forbidden until frontend Phase 2 is `PASS`.

### 13.8 Integration owner gate

After both backend and frontend Phase 2 are `PASS`:

```text
OWNER_INTEGRATION_APPROVAL_REQUIRED
```

Remain stopped until:

```text
/approve integration
```

`/reject integration` removes only integration approval.

### 13.9 Integration

After approval:

```text
INTEGRATION_TASK_READY
```

Use Stage-index order/dependencies if more than one integration task exists.

Do not bypass required integration because implementation tasks are green.

### 13.10 Closure owner gate

After required integration is authoritative PASS:

```text
OWNER_CLOSURE_APPROVAL_REQUIRED
```

Remain stopped until:

```text
/approve closure
```

After approval:

```text
CLOSURE_REVIEW_READY
```

This means only:

```text
ChatGPT Stage Closure Review may now be performed.
```

It does not mean:

```text
Stage Closed
PASS
merge automatically
```

### 13.11 Final close

Only when normal ChatGPT/Project Owner closure bookkeeping already records the
Stage closed:

```text
STAGE_CLOSED
```

At that point the orchestrator may close the control issue.

---

## 14. BLOCKED behavior

Return:

```text
BLOCKED
```

for any material ambiguity such as:

```text
malformed task table
duplicate Task ID
task belongs to wrong Stage
impossible task order
dependency references unknown task
frontend marked ready before backend Phase 2 PASS
integration ready before both checkpoints PASS
missing mandatory Phase 2 checkpoint
multiple conflicting Stage statuses
invalid hidden orchestrator metadata
invalid Stage number
unsafe GitHub API response
```

The issue must show the exact reason.

Do not invent a reconciliation.

---

## 15. GitHub API requirements

Use Python standard library only.

Use:

```text
GITHUB_TOKEN
GITHUB_REPOSITORY
GITHUB_EVENT_PATH
GITHUB_SHA
```

as appropriate.

Allowed API operations:

```text
find Stage Control issue
create Stage Control issue
update generated issue body
add concise command/result comment
close Stage Control issue after authoritative Stage closure
```

Not allowed:

```text
edit repository files
commit
push
create branch
merge PR
modify Stage index
modify task contracts
change product code
```

---

## 16. Idempotency

These must be safe to repeat:

```text
/status
workflow rerun
duplicate issue_comment delivery
duplicate merged-PR event
duplicate Stage-index push event
```

Required results:

```text
one control issue only
no duplicate approval values
no duplicate state transitions
no accidental approval removal
no Stage advancement from event duplication
```

---

## 17. Security

Mandatory:

1. Never print `GITHUB_TOKEN`.
2. Never store token in issue body/log.
3. Treat Markdown/task/index content strictly as data.
4. Never execute text parsed from Markdown.
5. Never build shell commands from task text.
6. Never allow task/index text to control arbitrary GitHub API URLs.
7. Validate repository-relative paths.
8. Validate Stage number.
9. Validate Task IDs.
10. Escape/encode GitHub API payloads through JSON.
11. Do not evaluate workflow expressions obtained from repository text.
12. On GitHub API failure, fail clearly without leaking secrets.

---

## 18. README

`.github/stage-orchestrator/README.md` must document only operational usage:

```text
purpose
states
triggers
owner commands
what the orchestrator does not do
how Stage task index remains authoritative
how Codex handoff works
how ChatGPT review gates remain authoritative
how to manually run workflow_dispatch
```

Keep it concise.

Do not duplicate product architecture.

---

## 19. Tests

Use:

```text
unittest
```

No network in unit tests.

Use pure fixture strings/data.

Cover at least:

1. missing Stage index -> `WAITING_FOR_STAGE_INDEX`;
2. Draft/not-approved Stage -> `WAITING_FOR_STAGE_APPROVAL`;
3. documentation entry task pending;
4. backend task ready;
5. next backend contract path missing;
6. backend Phase 2 ready;
7. backend Phase 2 PASS -> owner frontend gate;
8. `/approve frontend` -> first valid frontend task;
9. `/reject frontend` removes only frontend approval;
10. frontend Phase 2 ready;
11. frontend Phase 2 PASS -> owner integration gate;
12. `/approve integration` -> integration task;
13. `/reject integration` removes only integration approval;
14. integration PASS -> closure owner gate;
15. `/approve closure` -> `CLOSURE_REVIEW_READY`;
16. closure approval does not produce `STAGE_CLOSED`;
17. authoritative closed Stage -> `STAGE_CLOSED`;
18. malformed task table -> `BLOCKED`;
19. duplicate task ID -> `BLOCKED`;
20. missing backend Phase 2 -> `BLOCKED` when backend block exists;
21. missing frontend Phase 2 -> `BLOCKED` when frontend block exists;
22. unknown dependency -> `BLOCKED`;
23. duplicate events are idempotent;
24. unauthorized owner command is rejected;
25. current Stage 7 index-style table with extra columns is parsed correctly;
26. Stage 8-style task IDs including DOC/BE/FE/INT are recognized.

---

## 20. Self-check mode

Implement:

```text
python3 .github/stage-orchestrator/orchestrator.py --self-check
```

It must perform local, non-network validation of:

```text
configuration/constants
regexes
state definitions
supported commands
basic parser fixture
```

Exit non-zero on failure.

---

## 21. Focused verification

Run exactly the relevant workflow checks:

```text
python3 -m unittest discover -s .github/stage-orchestrator/tests -p 'test_*.py'
python3 .github/stage-orchestrator/orchestrator.py --self-check
git diff --check
```

Do not run:

```text
full backend suite
full frontend suite
Flutter build
real-stack E2E
database migrations
```

because this task changes no product runtime.

---

## 22. Final diff self-review

Before completion verify:

- every changed file is required for Orchestrator v1;
- no Stage 8 product contract was changed;
- no Stage 7 history was changed;
- no backend/frontend file changed;
- no product docs changed;
- no task index changed;
- permissions are least privilege;
- no API key/OpenAI secret exists;
- no paid agent invocation exists;
- no auto-merge path exists;
- no automatic Stage-close path exists;
- task Markdown is never executed as commands;
- owner approval authentication is exact.

---

## 23. Delivery boundary

Routine Git/GitHub delivery remains Project Owner-owned.

Codex must not:

```text
commit
push
create PR
merge
modify Stage bookkeeping
```

unless separately instructed by the Project Owner.

This task ends after implementation + focused verification + final diff review.

---

## 24. Required Codex completion report

Return exactly one status:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

Then report only:

1. implementation summary;
2. changed files and purpose;
3. exact verification commands and results;
4. state-machine/unit-test result;
5. `--self-check` result;
6. `git diff --check` result;
7. least-permission/security confirmation;
8. scope/non-goal confirmation;
9. blockers/deviations if any;
10. current `git status --short`.

Do not claim:

```text
Accepted
Stage 8 started
Stage 8 closed
```

ChatGPT / Project Owner own those decisions.

---

## 25. Acceptance criteria

This infrastructure task is acceptable only when all are true:

- one Stage Control issue is maintained per Stage;
- Stage task index remains authoritative;
- Stage 8 task files do not need rewriting;
- the next valid task/checkpoint can be derived from index state;
- missing contracts block safely;
- backend Phase 2 blocks frontend;
- frontend Phase 2 blocks integration;
- explicit owner approval blocks frontend entry;
- explicit owner approval blocks integration entry;
- explicit owner approval blocks closure review entry;
- owner closure approval cannot close the Stage;
- only repository owner can change approval state;
- duplicate events are idempotent;
- no repository write/merge occurs from the orchestrator;
- no OpenAI/Codex API is used;
- no ChatGPT/Codex subscription quota is consumed by ordinary orchestration;
- focused tests and self-check pass;
- `git diff --check` passes.
