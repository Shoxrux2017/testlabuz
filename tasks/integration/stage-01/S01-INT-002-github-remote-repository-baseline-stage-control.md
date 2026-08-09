# Codex Task: GitHub Remote, Repository Baseline & Stage 1 Control

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S01-INT-002` |
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Area | `Integration / repository and workflow control` |
| Status | `Accepted` |
| Depends on | `S01-INT-001 — Project Repository Foundation (Accepted)` |
| Blocks | `S01-BE-001 and all later Stage 1 implementation tasks` |

This detailed task was approved by the project owner on `2026-08-09` and may
now be executed by Codex. Codex must still follow all preflight, acceptance,
scope, and delivery gates in this task.

## 2. Goal

Create the first safe, reviewable, GitHub-backed TestLabUz repository baseline
and permanently encode the approved task acceptance/delivery workflow before
Laravel or Flutter implementation begins.

This task must:

1. Formalize the already-passed `S01-INT-001` result as `Accepted`.
2. Add the approved Stage 1 task index.
3. Synchronize task workflow documentation/templates with the approved
   implementation → read-only acceptance → GitHub delivery lifecycle.
4. Add only the minimum repository hygiene required before the first commit.
5. Configure the user-approved GitHub repository as `origin`.
6. Create the first atomic repository baseline commit.
7. Push that baseline to the empty GitHub repository as `main`.
8. Verify that local `main` and `origin/main` are identical and clean.

No product/framework implementation belongs in this task.

## 3. Current Context

The current local repository is:

`G:\project\testlabuz`

The accepted `S01-INT-001` review established:

- Git repository root is exactly `G:\project\testlabuz`.
- Current branch is unborn `main`.
- There are zero commits.
- There are zero remotes.
- There are zero tags.
- There is no nested or parent Git repository.
- Only normal Git metadata exists under `.git/`.
- Locked `docs/01–09`, `FINAL_AUDIT_REPORT.md`, root/backend/frontend
  `AGENTS.md`, and task preparation files are present.
- No Laravel scaffold, Flutter scaffold, Docker configuration, CI, environment
  file, or application code exists.

The project owner has created and approved this GitHub repository URL:

`https://github.com/Shoxrux2017/testlabuz.git`

At planning time the GitHub repository is publicly visible and empty. Codex
must independently verify remote state before any push and must not rely on the
planning-time observation.

## 4. Included Scope

### 4.1 Stage/task bookkeeping

- Change
  `tasks/integration/stage-01/S01-INT-001-project-repository-foundation.md`
  from `Status: Implemented` to `Status: Accepted`.
- Do not alter the already-reviewed requirements of `S01-INT-001`; only its
  lifecycle/status bookkeeping may change.
- Add:
  `tasks/STAGE_01_TASK_INDEX.md`
  using the project-owner-approved Stage 1 decomposition.
- Update `tasks/README.md` so it no longer says Stage 1 has no task directory or
  task file.
- Update Stage 1 status/bookkeeping to reflect the approved decomposition and
  current in-progress stage.

### 4.2 Permanent Codex task workflow

Update the reusable task workflow so future tasks use these phases:

```text
PHASE 0 — Git Preflight
PHASE 1 — Implementation
PHASE 2 — Read-Only Acceptance Gate
PHASE 3 — Post-Acceptance Git Delivery
```

Required final task states:

```text
ACCEPTED
NOT ACCEPTED
DELIVERY BLOCKED
```

The workflow must enforce:

- `NOT ACCEPTED` → no commit, no push, no merge, stop.
- Acceptance gate passed but GitHub delivery failed → `DELIVERY BLOCKED`, stop.
- `ACCEPTED` only after the approved result exists on `origin/main`, local
  `main` is synchronized to it, and the working tree is clean.

Apply this workflow consistently to the relevant reusable files:

- `tasks/README.md`
- `tasks/templates/CODEX_TASK_TEMPLATE.md`
- `tasks/templates/TASK_REVIEW_TEMPLATE.md`
- `tasks/templates/STAGE_TASK_INDEX_TEMPLATE.md`
- `tasks/templates/STAGE_CLOSURE_REVIEW_TEMPLATE.md`

Update root `AGENTS.md` only if needed to make these Git/GitHub safety rules
repository-wide Codex instructions. Do not change product behavior.

### 4.3 Minimal repository hygiene

Create a root `.gitignore` limited to repository-level local/security artifacts
that should never be committed.

It must not ignore project source, locked docs, task files, dependency lock
files, or future `.env.example` files.

At minimum cover:

- local environment files such as `.env`, `.env.local`, and safe local
  environment overrides;
- common private key/certificate artifacts;
- common OS metadata;
- common local IDE metadata that is not intended as shared project
  configuration.

Do not pre-create Laravel- or Flutter-specific generated ignore rules that
their official scaffolds should own later.

Because Git does not track empty directories, add a minimal tracked placeholder
under `docker/` only if necessary to preserve the approved root layout in the
first clone. Prefer the smallest neutral placeholder and do not add Docker
configuration in this task.

### 4.4 GitHub remote and initial baseline

- Verify the local repository is still on unborn `main` with zero commits.
- Verify there is no existing remote, or if `origin` exists, that it already
  exactly matches the approved URL.
- Configure:
  `origin = https://github.com/Shoxrux2017/testlabuz.git`
  only when safe.
- Verify the remote repository has no branch/history that would be overwritten.
- Never force-push or replace conflicting remote history.
- Verify Git commit identity is already valid without changing global Git
  configuration. If commit identity is missing, stop and report rather than
  inventing user identity.
- Perform a secret/sensitive-file scan suitable for the current repository
  contents before staging.
- Stage only approved baseline files.
- Inspect the staged diff/tree before commit.
- Create one initial atomic commit on `main`.

Preferred commit subject:

`chore(project): establish TestLabUz repository baseline`

Commit body must include:

`Task: S01-INT-002`

- Push the initial `main` to `origin`.
- Do not create an unnecessary Pull Request for this first push when the remote
  truly has no existing `main`; this task establishes the first shared
  `origin/main`.

## 5. Relevant Files

| File or directory | Expected action | Reason |
|---|---|---|
| `AGENTS.md` | Inspect; modify only for repository-wide Git workflow rules if needed | Root Codex workflow authority |
| `docs/01–09` | Inspect and preserve | Locked MVP authority; must not change |
| `docs/FINAL_AUDIT_REPORT.md` | Inspect and preserve | Passing audit evidence |
| `tasks/README.md` | Modify | Remove stale Stage 1 statement; encode lifecycle/Git delivery |
| `tasks/STAGE_01_TASK_INDEX.md` | Create | Approved Stage 1 decomposition/control record |
| `tasks/templates/CODEX_TASK_TEMPLATE.md` | Modify | Add standard execution/acceptance/delivery phases |
| `tasks/templates/TASK_REVIEW_TEMPLATE.md` | Modify | Align read-only gate with `PASS` / `NOT ACCEPTED` and no-fix rule |
| `tasks/templates/STAGE_TASK_INDEX_TEMPLATE.md` | Modify | Track review and GitHub delivery status |
| `tasks/templates/STAGE_CLOSURE_REVIEW_TEMPLATE.md` | Modify | Require delivered accepted tasks and synchronized repository state |
| `tasks/integration/stage-01/S01-INT-001-project-repository-foundation.md` | Modify status only | Record passed acceptance review |
| `tasks/integration/stage-01/S01-INT-002-github-remote-repository-baseline-stage-control.md` | Create/preserve current approved task | Current task contract |
| `.gitignore` | Create | Minimal repository hygiene/security |
| `docker/` | Preserve; add only minimal tracked placeholder if needed | Preserve approved logical root structure after clone |
| `.git/config` | Modify through normal Git remote configuration only | Add approved `origin` |
| `.git/` other metadata | Normal Git commit/push updates only | Establish baseline history |

Changes outside this list require a clear technical necessity inside this task
and must be reported. Do not change backend/frontend application structure or
locked product contracts.

## 6. Authoritative Specification References

| Document | Exact section | Requirement used by this task |
|---|---|---|
| `docs/06-roadmap.md` | `2.2 One Stage at a Time` | Stage work must remain controlled and explicitly verified |
| `docs/06-roadmap.md` | `3. Stage Structure and Definition of Done` | Stage completion requires implementation and verification evidence |
| `docs/06-roadmap.md` | `5. Stage 0 — Project Preparation and Technical Planning` → `Project Structure` | Approved repository structure precedes production feature work |
| `docs/06-roadmap.md` | `5. Stage 0 — Project Preparation and Technical Planning` → `Codex Workflow` | Use small backend/frontend/integration task contracts |
| `docs/06-roadmap.md` | `6. Stage 1 — Authentication and Role-Based Entry` | Current roadmap stage identity and boundary |
| `docs/07-architecture.md` | `2.6 Local Development` | Host source under `backend/`, `frontend/`, and `docker/` logical structure |
| `docs/07-architecture.md` | `5. Recommended Project Structure` | Approved repository organization |
| `docs/07-architecture.md` | `32. Testing Architecture` | Verification is part of architecture |
| `AGENTS.md` | `3. Working Model` | One small precise task at a time |
| `AGENTS.md` | `20. Quality Gates` | Failed checks block closure |
| `AGENTS.md` | `21. Change-Control Rule` | Workflow changes must remain documented/traceable |
| `AGENTS.md` | `22. Scope-Control Rules` | No unrelated infrastructure or product changes |
| `AGENTS.md` | `23.12 Code Review Standard` | Review is broader than tests alone |
| `AGENTS.md` | `25. Task Completion Checklist` | Task closure requires scope/tests/quality/documentation evidence |

GitHub delivery mechanics are a project workflow decision approved by the
project owner. They do not alter product behavior in `docs/01–09`.

## 7. Relevant Business / Workflow Rules

- Locked `docs/01–09` remain the only MVP product/technical authority.
- Git history and GitHub delivery must never be used to silently change a
  locked product rule.
- Each future production task must be isolated in one task branch.
- A failed acceptance gate must not be hidden by committing or pushing the
  rejected result.
- A technically accepted result is not finally `Accepted` until safe GitHub
  delivery to `origin/main` is complete.
- The initial repository baseline is the one exception allowed to push directly
  to `main`, because the approved remote has no established shared baseline yet.
- Never overwrite unexpected remote history.

## 8. Requirements

### 8.1 Functional Requirements

1. Preserve all locked project artifacts and accepted `S01-INT-001`
   implementation state.
2. Mark only the lifecycle status of `S01-INT-001` as `Accepted`.
3. Add the approved `tasks/STAGE_01_TASK_INDEX.md`.
4. Correct stale Stage 1 statements in `tasks/README.md`.
5. Encode the approved four-phase task workflow and three final states into the
   relevant task templates/guidance.
6. Encode future task-branch/PR delivery rules:
   - clean/synced `main`;
   - one task branch;
   - no push before acceptance;
   - post-acceptance atomic commit;
   - push task branch;
   - PR to `main`;
   - merge only with passing required checks;
   - local `main` resynchronized after merge.
7. Encode safe Git prohibitions, including no force-push, no bypassing checks,
   no global Git config mutation, and no secret/token commits.
8. Create only minimal root repository hygiene needed before the initial
   commit.
9. Configure the approved GitHub repository as `origin` only after verifying
   that doing so is safe.
10. Verify the remote is empty/no conflicting branch history before the first
    push.
11. Create one initial baseline commit on local `main`.
12. Push local `main` to `origin/main`.
13. Verify local `main` and `origin/main` resolve to the same commit.
14. Verify final working tree is clean.
15. Do not implement Laravel, Flutter, PostgreSQL runtime, authentication, or
    any Stage 1 product behavior.

### 8.2 Architecture and Organization

- Keep workflow policy in `tasks/` templates/guidance and repository-wide
  agent instructions only where appropriate.
- Do not duplicate the entire workflow text inconsistently across many files;
  keep one authoritative detailed description and concise references where
  possible.
- Keep the Stage 1 index factual and traceable to locked contracts.
- Do not create future detailed task files beyond `S01-INT-002` in this task.
  The index may reference their planned paths.
- Do not create Laravel/Flutter internal folders manually.
- Do not add speculative CI, release, deployment, or GitHub automation.
- Do not create GitHub Actions in this task.

### 8.3 Authorization, Security, and Tenant Isolation

Runtime tenant/role authorization is not implemented in this task.

Repository security requirements are applicable:

- Do not commit passwords, tokens, `.env` secrets, private keys, certificates,
  credentials, or generated authentication artifacts.
- Do not print GitHub authentication tokens.
- Do not store GitHub credentials in tracked files.
- Do not change credential helpers unless explicitly required and approved.
- Do not modify global Git configuration.
- Verify the staged baseline contains no obvious secret-bearing files.
- Locked tenant/authorization contracts must remain preserved.

### 8.4 Validation, Errors, and Delivery Safety

Stop and report if:

- local repository root/branch/commit state differs materially from the
  accepted `S01-INT-001` baseline;
- `origin` exists with a different URL;
- the GitHub repository is not safely empty or contains history that would
  conflict with the first baseline;
- GitHub authentication is unavailable for required push;
- Git commit identity is unavailable;
- a remote operation would require force-push/history rewrite;
- unexpected secret/private files are present;
- the user-approved Stage 1 index content cannot be placed without changing a
  locked product contract.

Do not "fix" those conditions with destructive Git commands.

## 9. Acceptance Criteria

- [ ] `S01-INT-001` is recorded as `Accepted` without changing its reviewed
      implementation requirements.
- [ ] `tasks/STAGE_01_TASK_INDEX.md` exists and contains the approved 13-task
      Stage 1 decomposition and dependency/verification map.
- [ ] `tasks/README.md` no longer falsely states that Stage 1 has no task.
- [ ] Reusable task/review/index/closure templates reflect the approved
      implementation → read-only acceptance → post-acceptance GitHub delivery
      lifecycle.
- [ ] Future task workflow defines `ACCEPTED`, `NOT ACCEPTED`, and
      `DELIVERY BLOCKED` unambiguously.
- [ ] Future production tasks are required to use task branches and PR-based
      delivery rather than direct pushes to `main`.
- [ ] Safe Git rules prohibit force-push/history rewrite/check bypass and
      credential/secret commits.
- [ ] Root `.gitignore` provides minimal repository-level protection without
      hiding future project source, task files, lock files, or `.env.example`.
- [ ] Locked `docs/01–09`, audit, and unrelated project files remain unchanged.
- [ ] `origin` is exactly
      `https://github.com/Shoxrux2017/testlabuz.git`.
- [ ] Remote state was verified safe for the first baseline; no existing remote
      history was overwritten.
- [ ] Exactly one initial repository baseline commit exists after this task.
- [ ] The initial baseline commit is present on `origin/main`.
- [ ] Local `main` and `origin/main` point to the same commit.
- [ ] Final `git status --short` is empty.
- [ ] No Laravel/Flutter/Docker runtime/application implementation or CI was
      introduced.
- [ ] No secrets or credentials were committed.
- [ ] No unrelated product behavior or locked contract changed.

## 10. Tests and Verification

### 10.1 Repository and Workflow Checks

Verify the updated task system is internally consistent:

- [ ] `tasks/README.md` lifecycle/status definitions agree with the reusable
      templates.
- [ ] `STAGE_01_TASK_INDEX.md` uses only valid task statuses and has no missing
      roadmap acceptance criterion.
- [ ] `CODEX_TASK_TEMPLATE.md` clearly distinguishes implementation,
      read-only acceptance, and GitHub delivery.
- [ ] `TASK_REVIEW_TEMPLATE.md` forbids fixing during the acceptance gate.
- [ ] `STAGE_TASK_INDEX_TEMPLATE.md` can record review/delivery status.
- [ ] `STAGE_CLOSURE_REVIEW_TEMPLATE.md` requires delivered accepted tasks and
      synchronized repository state.

### 10.2 Git / Remote Checks

Run safe equivalents of:

```text
git rev-parse --show-toplevel
git branch --show-current
git status --short
git remote -v
git config --get remote.origin.url
git ls-remote origin
git log --oneline --decorate --all
git rev-list --all --count
git ls-tree -r --name-only HEAD
git rev-parse HEAD
git rev-parse origin/main
git diff --check
```

Before the initial commit, correctly handle unborn `HEAD`.

After push:

```text
git fetch origin
git rev-parse main
git rev-parse origin/main
git status --short
```

The two commit IDs must match and status must be clean.

### 10.3 Security Checks

- [ ] Inspect tracked/staged filenames for `.env`, private key/certificate, and
      credential artifacts.
- [ ] Search current tracked/staged text for obvious token/password/secret
      patterns without printing secret values.
- [ ] Verify `.git/config` contains only the approved remote information and no
      embedded credentials.
- [ ] Verify no global Git configuration was changed by this task.

### 10.4 Manual Smoke Check

1. Open the GitHub repository after push.
2. Confirm `main` exists.
3. Confirm the baseline commit is visible.
4. Confirm `docs/`, `tasks/`, `backend/AGENTS.md`, `frontend/AGENTS.md`, and the
   repository hygiene file are visible.
5. Confirm no secret/environment file is visible.
6. Confirm the Stage 1 index and task workflow documentation are readable.

If GitHub UI verification is unavailable to Codex, verify via authenticated
Git/GitHub CLI/API where safely available and report the limitation.

## 11. Explicit Non-Goals

- Laravel scaffolding.
- Flutter scaffolding.
- PostgreSQL/Docker runtime configuration.
- Docker Compose.
- GitHub Actions / CI.
- Authentication implementation.
- Database migrations/models.
- API endpoints.
- UI screens.
- Stage 2+ product features.
- Creating all remaining detailed Stage 1 task files.
- Creating releases/tags.
- Creating or changing GitHub repository visibility.
- Force-pushing, rewriting history, or importing unrelated remote history.
- Configuring organization-level GitHub settings.
- Changing global Git configuration.
- Inventing Git identity or GitHub credentials.

## 12. Stop Conditions

Stop before a destructive or ambiguous action if:

- `S01-INT-001` is not actually in a review-passed state;
- locked docs differ unexpectedly;
- a required task/template file is missing;
- current local Git state is not the accepted unborn-`main` baseline;
- the approved remote URL cannot be verified;
- `origin` points elsewhere;
- the remote contains unexpected commits/branches/tags;
- GitHub authentication does not permit safe push;
- commit identity is missing;
- secret/private artifacts would be included;
- safe completion would require force-push, reset-hard, destructive clean,
  history rewrite, branch-protection bypass, or material scope expansion.

Report the exact blocker. Do not improvise around it.

## 13. Execution and Acceptance Workflow for This Task

This task is the baseline exception because no shared `origin/main` exists yet.

### Phase 0 — Preflight

Read:

1. root `AGENTS.md`;
2. this complete task;
3. relevant current task/templates;
4. referenced locked specification sections;
5. current Git state;
6. current GitHub remote state.

Do not change anything until the preflight confirms safe baseline conditions.

### Phase 1 — Implementation

Perform only Sections 4 and 8 of this task.

Before commit/push:

- complete all repository/workflow/security checks;
- inspect every intended staged path;
- confirm no product/framework implementation was introduced.

At the end of Phase 1, do **not** commit yet.

### Phase 2 — Read-Only Acceptance Gate

Review the complete Phase 1 working-tree result against every requirement and
acceptance criterion in this task.

During Phase 2:

- make no file changes;
- make no Git configuration changes;
- do not stage additional changes;
- do not commit;
- do not push.

If any blocking/material finding exists:

```text
FINAL STATUS: NOT ACCEPTED
```

Return findings with severity and evidence, then stop.

Do not self-fix after the gate begins.

### Phase 3 — Initial Baseline GitHub Delivery

Run only if Phase 2 returns PASS.

1. Apply only required acceptance bookkeeping:
   - set this task to `Accepted`;
   - update the Stage 1 index/task status/delivery status consistently.
2. Re-run `git diff --check`, secret scan, and inspect the final staged tree.
3. Create the one baseline commit.
4. Push `main` to the verified empty `origin`.
5. Fetch/verify `origin/main`.
6. Confirm local `main == origin/main`.
7. Confirm clean working tree.

If implementation passed but safe delivery cannot complete:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Do not start another task.

If all delivery checks pass:

```text
FINAL STATUS: ACCEPTED
```

## 14. Required Codex Final Report

Return:

1. **Final status** — exactly one of:
   - `ACCEPTED`
   - `NOT ACCEPTED`
   - `DELIVERY BLOCKED`
2. **Phase 0 preflight** — local Git and remote safety evidence.
3. **Implementation summary** — workflow/bookkeeping/hygiene changes.
4. **Changed files** — each path and reason.
5. **Acceptance gate findings** — `No blocking or material findings` or the
   exact findings that caused `NOT ACCEPTED`.
6. **Acceptance criteria** — PASS/FAIL evidence for every criterion.
7. **Security evidence** — secret scan, credential safety, locked-doc
   preservation.
8. **Git delivery evidence**:
   - remote URL;
   - commit hash and subject;
   - local `main` hash;
   - `origin/main` hash;
   - push result;
   - final clean status.
9. **GitHub verification** — baseline visible/reachable on `origin/main`.
10. **Scope confirmation** — no product/framework/CI implementation.
11. **Remaining blockers/deviations**.

Do not start `S01-BE-001` in this task.
