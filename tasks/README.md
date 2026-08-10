# TestLabUz Codex Tasks

This directory controls implementation work for the locked TestLabUz MVP.
It organizes small Codex tasks; it does not define or change product behavior.

## 1. Authority

The authoritative product and technical specification is `docs/01–09` from
`TestLabUz-MVP-Specifications-LOCKED`.

Before implementing a task, follow this order:

1. Read the root `AGENTS.md`.
2. Read the nearest backend or frontend `AGENTS.md` when applicable.
3. Read the approved task file.
4. Read only the task's referenced sections from `docs/01–09`.
5. Inspect the existing code and tests affected by the task.

If a task conflicts with a locked specification, stop and report the exact
conflict. A task may narrow implementation scope, but it must never create,
reinterpret, or remove business behavior.

## 2. Directory Structure

```text
tasks/
  README.md
  STAGE_00_CLOSURE_REVIEW.md
  STAGE_01_TASK_INDEX.md

  templates/
    CODEX_TASK_TEMPLATE.md
    STAGE_TASK_INDEX_TEMPLATE.md
    TASK_REVIEW_TEMPLATE.md
    STAGE_CLOSURE_REVIEW_TEMPLATE.md

  backend/
  frontend/
  integration/
```

Stage directories are created only after that stage is approved for
decomposition, for example:

```text
tasks/backend/stage-01/
tasks/frontend/stage-01/
tasks/integration/stage-01/
```

Stage 1 has an approved task index at `tasks/STAGE_01_TASK_INDEX.md`.
Detailed task files are created only when their individual scopes are approved.

## 3. Task Areas

| Area | Contains |
|---|---|
| `backend/` | Laravel, PostgreSQL, server-side authorization, domain rules, storage, and backend tests |
| `frontend/` | Flutter data, domain, presentation, routing, state management, and frontend tests |
| `integration/` | Laravel–Flutter contract verification, cross-layer workflows, and end-to-end smoke checks |

A task belongs to the area that owns its main change. Cross-layer work should
be a separate integration task rather than silently expanding a backend or
frontend task.

## 4. Naming Convention

```text
S<stage>-<area>-<number>-<short-description>.md
```

Examples:

```text
S01-BE-001-short-description.md
S01-FE-001-short-description.md
S01-INT-001-short-description.md
```

Area codes:

- `BE` — backend
- `FE` — frontend
- `INT` — integration

These examples define naming only; they are not Stage 1 tasks.

## 5. Task Lifecycle

Use these statuses consistently:

| Status | Meaning |
|---|---|
| `Draft` | Proposed but not approved for implementation |
| `Approved` | Scope and task contract approved; ready for Codex |
| `In Progress` | Codex is implementing the task |
| `Accepted` | Read-only acceptance passed, approved delivery is on `origin/main`, local `main` matches it, and the working tree is clean |
| `Not Accepted` | Read-only acceptance found a blocking or material issue; no commit, push, merge, or later task may proceed from that result |
| `Delivery Blocked` | Read-only acceptance passed, but safe GitHub delivery could not be completed |
| `Blocked` | Work cannot safely continue without an approved decision or dependency |

Only one small, precise implementation task should normally be `In Progress`.
Do not mark a task `Accepted` only because work was implemented or reviewed.
Acceptance requires the approved result to be delivered to `origin/main`.

Review status values:

| Status | Meaning |
|---|---|
| `Not started` | The read-only acceptance gate has not run |
| `PASS` | The read-only acceptance gate found no blocking or material issue |
| `NOT ACCEPTED` | The read-only acceptance gate found a blocking or material issue |

Delivery status values:

| Status | Meaning |
|---|---|
| `Not started` | No post-acceptance GitHub delivery has started |
| `Not applicable` | Delivery does not apply to the specific pre-baseline task |
| `Delivered` | The accepted result is present on `origin/main` and local `main` is synchronized |
| `Blocked` | Safe GitHub delivery could not be completed |

## 6. Approved Workflow

1. Discuss and approve a roadmap stage for decomposition.
2. Create its stage task index from `STAGE_TASK_INDEX_TEMPLATE.md`.
3. Agree on the small task list, order, and dependencies.
4. Create or approve one detailed task from `CODEX_TASK_TEMPLATE.md`.
5. Give Codex that one task.
6. Run the task through the four required phases below.
7. If necessary, create a focused fix task; do not silently expand the original.
8. Continue with the next approved task only after the current task is
   `Accepted` and delivered.
9. After all tasks pass, run `STAGE_CLOSURE_REVIEW_TEMPLATE.md` and explicitly
    close the stage before starting the next stage.

### 6.1 Required Task Phases

Every implementation task uses these phases unless its approved task file
defines a stricter baseline exception.

```text
PHASE 0 - Git Preflight
PHASE 1 - Implementation
PHASE 2 - Read-Only Acceptance Gate
PHASE 3 - Post-Acceptance Git Delivery
```

Phase 0 requires a clean repository, synchronized `main`, one task branch from
`origin/main`, confirmed dependencies, and safe GitHub state.

Phase 1 implements only the approved task and runs the required checks. Do not
push implementation work during this phase.

Phase 2 is read-only. Review the complete result against the task contract,
acceptance criteria, security requirements, and relevant locked specifications.
Do not edit files, stage changes, commit, push, merge, or fix findings during
this gate. If the gate fails, return `FINAL STATUS: NOT ACCEPTED` and stop.

Phase 3 runs only after Phase 2 returns `PASS`. Update acceptance bookkeeping,
rerun final safe checks, create one focused commit, push the task branch, open a
Pull Request to `main` when tooling permits, merge only with required checks
passing, resynchronize local `main`, and verify local `main == origin/main` with
a clean working tree. Only then return `FINAL STATUS: ACCEPTED`.

If Phase 2 passes but safe GitHub delivery cannot finish, return
`FINAL STATUS: DELIVERY BLOCKED` and stop.

### 6.2 GitHub Delivery Rules

- Future production tasks use a task branch and Pull Request; direct pushes to
  `main` are allowed only for the approved initial empty-repository baseline.
- Do not commit or push before the read-only acceptance gate passes.
- Do not force-push, rewrite shared history, bypass hooks/checks with
  `--no-verify`, or merge with failing required checks.
- Do not use destructive cleanup such as `git reset --hard` or destructive
  `git clean` unless a separate approved recovery task explicitly requires it.
- Do not modify global Git configuration.
- Do not replace an unexpected `origin` silently.
- Do not commit credentials, tokens, environment secrets, private keys, or
  certificate artifacts.
- `ACCEPTED` means the accepted result is on `origin/main`, local `main` matches
  it, and `git status --short` is empty.

## 7. Non-Negotiable Task Rules

Every implementation task must include:

- one clear goal;
- included scope and explicit non-goals;
- relevant files;
- exact specification references;
- relevant business rules;
- functional and architectural requirements;
- server-side authorization and tenant-isolation requirements where applicable;
- acceptance criteria;
- automated tests and negative/security cases;
- quality gates and manual smoke checks where applicable;
- stop conditions;
- the required Codex completion report.

All implementation must follow the locked architecture, Clean Code, proper
separation of concerns, focused responsibilities, testing, security, and strict
multi-institution isolation rules in the applicable `AGENTS.md` files.

## 8. Stage Status

| Stage | Status | Evidence / next gate |
|---|---|---|
| Stage 0 — Project Preparation and Technical Planning | `Closed` | See `STAGE_00_CLOSURE_REVIEW.md` |
| Stage 1 — Authentication and Role-Based Entry | `Closed` | See `STAGE_01_CLOSURE_REVIEW.md`; next gate is Stage 2 decomposition/planning only |

Stage 2 is eligible for decomposition/planning only. Do not start Stage 2
implementation until its task index and first task are explicitly approved.
