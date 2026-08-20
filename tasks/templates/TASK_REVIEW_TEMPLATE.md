# Legacy Individual Task Review Template

## Status

`LEGACY — STAGE 0–3 ONLY`

This template is preserved as historical workflow documentation for TestLabUz
Stages 0–3.

It must not be used as the normal review workflow for Stage 4 or later.

---

## 1. Historical Purpose

Stages 0–3 used an earlier implementation workflow in which each individual
implementation task passed a separate read-only acceptance review before final
delivery and acceptance.

Historical task/review/closure files created under that workflow remain valid
audit evidence.

Do not rewrite those historical records to match the Stage 4+ workflow.

---

## 2. Stage 4+ Replacement

For Stage 4 and later:

### Per implementation task

Use:

```text
approved implementation contract
→ Git preflight
→ implementation
→ focused verification
→ scope/diff self-check
→ GitHub delivery
→ task Accepted
```

There is no normal individual Phase 2 Read-Only Review after every task.

### After the backend task block

Use:

```text
tasks/templates/BLOCK_REVIEW_TEMPLATE.md
```

for the Backend Phase 2 Read-Only Checkpoint.

### After the frontend task block

Use:

```text
tasks/templates/BLOCK_REVIEW_TEMPLATE.md
```

for the Frontend Phase 2 Read-Only Checkpoint.

### After integration

Use:

```text
tasks/templates/STAGE_CLOSURE_REVIEW_TEMPLATE.md
```

for the final Stage Closure Review.

---

## 3. Current Workflow Authority

For Stage 4+ implementation and review flow, follow:

```text
AGENTS.md
backend/AGENTS.md
frontend/AGENTS.md
tasks/README.md
tasks/templates/CODEX_TASK_TEMPLATE.md
tasks/templates/BLOCK_REVIEW_TEMPLATE.md
tasks/templates/STAGE_TASK_INDEX_TEMPLATE.md
tasks/templates/STAGE_CLOSURE_REVIEW_TEMPLATE.md
```

The current approved implementation contract defines the task-specific
requirements given to Codex.

Codex must not use this legacy file to infer current review or delivery
requirements.

---

## 4. Historical Compatibility Rules

Do not:

- delete this file while Stage 0–3 history depends on the old workflow;
- reinterpret historical `PASS`, `NOT ACCEPTED`, `Accepted`, or delivery status
  using Stage 4+ semantics;
- regenerate historical task-review files;
- rewrite Stage 0–3 closure evidence;
- instruct Codex to run this legacy template for new implementation tasks.

This file exists only to explain the historical review model and prevent it
from being accidentally reused.

---

## Final Rule

> Stage 0–3 individual task reviews remain valid historical evidence.
> Stage 4+ uses proportional per-task verification plus backend/frontend
> block-level Phase 2 reviews.
