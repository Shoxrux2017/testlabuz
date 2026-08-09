# Codex Task: Project Repository Foundation

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S01-INT-001` |
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Area | `Integration / repository-wide foundation` |
| Status | `Accepted` |
| Depends on | `None` |
| Blocks | `Future Laravel and Flutter scaffolding tasks; IDs are not assigned yet` |

Do not start implementation while the status is `Draft`. The user must approve
this detailed task separately before its status becomes `Approved`.

## 2. Goal

Establish and verify the initial `testlabuz/` repository shell around the
approved locked project artifacts already present in the repository so later
Laravel and Flutter scaffolding tasks begin inside the correct documented
structure.

The approved locked files present in the repository are the authoritative MVP
implementation baseline. This task does not require a separate duplicate source
package, external archive, or checksum baseline to prove that authority.

This task creates the repository foundation only. It does not install,
generate, configure, or implement either application.

## 3. Current Context

- Stage 0 is formally closed.
- The TestLabUz MVP specifications in `01–09` are locked and authoritative.
- The final cross-document audit passed.
- The locked specifications and approved repository instruction/task files
  present in `testlabuz/` are the authoritative implementation baseline.
- No separate external source package is required for integrity comparison.
- Root, backend, and frontend `AGENTS.md` instructions are approved.
- The reusable `tasks/` structure and templates are prepared.
- No Laravel or Flutter source project exists yet.
- The user approved this detailed repository-foundation task for
  implementation on 2026-08-09.

## 4. Included Scope

- Ensure one project root directory named `testlabuz/` exists.
- Ensure the approved root `AGENTS.md` is present at `testlabuz/AGENTS.md`.
- Ensure `testlabuz/docs/` contains the locked `01–09` specification files
  without altering their content during this task.
- Ensure the final passing audit is present at
  `testlabuz/docs/FINAL_AUDIT_REPORT.md` without altering its content during
  this task.
- Ensure the approved implementation-preparation `tasks/` structure is present
  at `testlabuz/tasks/`, including this task file.
- Ensure `testlabuz/backend/` contains the approved backend `AGENTS.md`.
- Ensure `testlabuz/frontend/` contains the approved frontend `AGENTS.md`.
- Ensure an empty `testlabuz/docker/` directory exists.
- Initialize `testlabuz/` as a Git repository whose initial branch is `main`.
- Verify the resulting tree, preservation of locked/approved repository
  artifacts, and Git initialization.

## 5. Relevant Files

Codex must inspect the current repository state before making changes. The
approved locked and instruction/task files already present in `testlabuz/` are
the authoritative baseline for this task. No external duplicate source package,
archive, or checksum reference is required.

| File or directory | Expected action | Reason |
|---|---|---|
| `testlabuz/AGENTS.md` | Inspect and preserve | Repository-wide Codex instructions |
| `testlabuz/docs/01–09` | Inspect presence and preserve | Locked authoritative MVP specification |
| `testlabuz/docs/FINAL_AUDIT_REPORT.md` | Inspect presence and preserve | Final passing cross-document audit |
| `testlabuz/tasks/` | Inspect and preserve | Approval-gated Codex workflow, templates, and task records |
| `testlabuz/backend/AGENTS.md` | Inspect and preserve | Backend-specific instructions before Laravel scaffolding |
| `testlabuz/frontend/AGENTS.md` | Inspect and preserve | Frontend-specific instructions before Flutter scaffolding |
| `testlabuz/docker/` | Ensure empty | Approved local-development structure; configuration is deferred |
| `testlabuz/.git/` | Create through Git initialization if absent | Version-control foundation |

Changes outside this list require a clear technical necessity within the
approved scope and must be reported. Unrelated files must not be changed.

## 6. Authoritative Specification References

| Document | Exact section | Requirement used by this task |
|---|---|---|
| `docs/06-roadmap.md` | `5. Stage 0 — Project Preparation and Technical Planning` → `Project Structure` | Backend, frontend, environment, configuration, storage, authentication, authorization, errors, testing, CI, logging, and seed strategies are approved before production feature coding |
| `docs/06-roadmap.md` | `5. Stage 0 — Project Preparation and Technical Planning` → `Codex Workflow` | Use `tasks/backend/`, `tasks/frontend/`, and `tasks/integration/` with small, explicit task contracts |
| `docs/06-roadmap.md` | `5. Stage 0 — Project Preparation and Technical Planning` → `Acceptance Criteria` and `Exit Gate` | Stage 0 contracts are approved and no ambiguity may be introduced when preparing Stage 1 |
| `docs/07-architecture.md` | `2.6 Local Development` | Use the logical `testlabuz/backend`, `testlabuz/frontend`, and `testlabuz/docker` structure; source must live on the host, not only in a disposable container |
| `docs/07-architecture.md` | `5. Recommended Project Structure` | Defines the approved root, docs, tasks, backend, frontend, and docker layout |
| `docs/07-architecture.md` | `39. CI and Quality Gates` | Framework checks apply only after the corresponding projects and tools exist |
| `docs/07-architecture.md` | `40. Codex Architecture Rules` | Work must remain small, traceable, and free of unrelated architecture or behavior changes |
| `AGENTS.md` | `1. Project Status` | `docs/01–09` are locked for MVP implementation and the audit passed |
| `AGENTS.md` | `2. Authority and Conflict Rule` | Task files narrow current scope but never replace or modify locked product truth |
| `AGENTS.md` | `3. Working Model` | Codex receives one small, precise task at a time |
| `AGENTS.md` | `4. Required Read Order Before a Task` | Read root/nested instructions, the task, relevant specifications, and existing state before changes |
| `AGENTS.md` | `21. Change-Control Rule` and `22. Scope-Control Rules` | Do not alter locked behavior, add unrelated infrastructure, or expand scope |

## 7. Relevant Business Rules

This task implements no runtime business behavior. Its relevant rule is the
authority boundary:

- The in-repository `docs/01–09` remain the only authoritative MVP specification.
- The task and agent instructions must not add, remove, reinterpret, or
  silently resolve product behavior.
- The final audit and Stage 0 closure evidence must remain unchanged by this task.

## 8. Requirements

### 8.1 Functional Requirements

1. Ensure exactly one logical project root named `testlabuz/` exists.
2. Verify all nine locked specification documents are present with their
   approved filenames and do not modify their contents during this task.
3. Verify the final audit is present as `FINAL_AUDIT_REPORT.md` and do not
   modify its contents during this task.
4. Verify the approved root, backend, and frontend `AGENTS.md` files are present
   at their approved locations and do not edit them during this task.
5. Verify the approved `tasks/` structure is present, including its README,
   templates, Stage 0 closure review, area directories, and this Stage 1 task.
6. Ensure `backend/`, `frontend/`, and `docker/` exist even though framework
   source and Docker configuration are intentionally absent.
7. Initialize Git only at the `testlabuz/` root and set the current initial
   branch to `main`.
8. Do not create a commit, configure a remote, or alter global Git settings.
9. Leave locked project artifacts and unrelated workspace files unchanged.
10. Do not require or fabricate comparison against an external approved source
    package; the approved locked files already present in this repository are
    the authoritative baseline.

Expected result:

```text
testlabuz/
  AGENTS.md

  docs/
    01-business-overview.md
    02-user-roles.md
    03-features.md
    04-user-flows.md
    05-business-rules.md
    06-roadmap.md
    07-architecture.md
    08-database.md
    09-api-contracts.md
    FINAL_AUDIT_REPORT.md

  tasks/
    README.md
    STAGE_00_CLOSURE_REVIEW.md
    templates/
    backend/
    frontend/
    integration/
      stage-01/
        S01-INT-001-project-repository-foundation.md

  backend/
    AGENTS.md

  frontend/
    AGENTS.md

  docker/
```

Git's internal `.git/` directory is intentionally omitted from the displayed
project tree.

### 8.2 Architecture and Code Organization

- Preserve the exact repository boundaries approved in
  `docs/07-architecture.md`.
- Keep backend-specific instructions under `backend/` and frontend-specific
  instructions under `frontend/`.
- Do not pre-create Laravel or Flutter internal folders. Their official
  scaffolding commands must own those structures in separately approved tasks.
- Do not add placeholder source files, catch-all folders, empty application
  layers, or speculative architecture.
- Do not edit locked specifications to make them fit the new folder structure.
- Empty directories created in this task are filesystem placeholders; this task
  does not add `.gitkeep` files.

### 8.3 Authorization, Security, and Tenant Isolation

No executable application code, database schema, API, authentication flow, or
tenant-owned data is created in this task. Runtime authorization and
cross-institution tests are therefore not applicable.

The security requirement for this foundation task is preservation: all
approved backend-authoritative, role, password, and tenant-isolation
instructions already present in the repository must not be weakened, replaced,
or modified by this task.

### 8.4 Validation, Errors, and Observability

- Stop if any required in-repository authoritative file is missing,
  unreadable, ambiguous, or inconsistent with the approved filename.
- If `testlabuz/` already exists, inspect and preserve its approved contents;
  do not overwrite, merge, or replace existing work ambiguously.
- Do not invent or substitute alternate audit, specification, instruction, or
  task versions from outside the repository.
- Do not log or print secrets. No secrets should be created or copied in this
  task.
- Report filesystem or Git failures clearly; do not claim partial setup is
  complete.

## 9. Acceptance Criteria

- [ ] One `testlabuz/` project root exists and contains the approved top-level
      `AGENTS.md`, `docs/`, `tasks/`, `backend/`, `frontend/`, and `docker/`.
- [ ] `docs/` contains exactly the locked `01–09` filenames plus
      `FINAL_AUDIT_REPORT.md`; these authoritative files were not modified by
      this task.
- [ ] Root, backend, and frontend `AGENTS.md` are present at their approved
      paths and were not modified by this task.
- [ ] The approved `tasks/` preparation structure is present, including this
      task at the expected path.
- [ ] `backend/` contains no Laravel project files and `frontend/` contains no
      Flutter project files.
- [ ] `docker/` contains no Docker configuration files.
- [ ] `testlabuz/` is a Git work tree and its initial branch is `main`.
- [ ] No Git commit, remote, hook, credential, or global Git configuration was
      created or changed.
- [ ] No unrelated file or locked product contract changed.

## 10. Tests and Verification

### 10.1 Automated Structural Checks

- [ ] Verify every required path exists and every prohibited framework/config
      path is absent.
- [ ] Verify all required locked `docs/01–09`, the final audit, and all three
      `AGENTS.md` files are present at their approved repository paths.
- [ ] Verify the reusable task files and task structure required by this task are
      present.
- [ ] Verify the repository-foundation correction did not modify locked
      specifications, the final audit, or approved instruction files.
- [ ] Do not require comparison to an external archive or duplicate source
      package.
- [ ] Verify Git identifies `testlabuz/` as the repository root.
- [ ] Verify the current initial branch is `main`.
- [ ] Verify there are no commits and no configured remotes.

### 10.2 Negative and Security Checks

- [ ] Confirm no `artisan`, backend `composer.json`, frontend `pubspec.yaml`,
      Docker Compose file, CI workflow, environment file, or secret file was
      created.
- [ ] Confirm Git was not initialized above or below the intended project root.
- [ ] Confirm locked repository artifacts and unrelated workspace files were
      not modified.

Authentication, wrong-role, and cross-institution runtime tests are not
applicable because this task creates no runtime behavior.

### 10.3 Quality Gates

Laravel and Flutter quality commands are not applicable until those projects
are created in separately approved tasks. Run only safe repository-foundation
checks available in the implementation environment, including equivalents of:

```text
git -C testlabuz rev-parse --show-toplevel
git -C testlabuz branch --show-current
git -C testlabuz rev-list --count HEAD
git -C testlabuz remote
git -C testlabuz status --short
```

The no-commit check must handle Git's unborn `main` branch without treating the
expected absence of `HEAD` as a setup failure.

### 10.4 Manual Smoke Check

1. Open the `testlabuz/` root and inspect the top-level directories.
2. Confirm `docs/` contains the locked specifications and final audit.
3. Confirm root/backend/frontend instructions are in the correct locations.
4. Confirm the task templates and this draft task are present.
5. Confirm backend, frontend, and docker contain no generated framework or
   configuration files beyond their approved `AGENTS.md` instructions.

## 11. Explicit Non-Goals

- Installing PHP, Composer, Laravel, PostgreSQL, Docker, Flutter, Dart, or any
  package/dependency.
- Running `laravel new`, `composer create-project`, `flutter create`, or any
  other framework scaffolding command.
- Creating Laravel, Flutter, PostgreSQL, Docker Compose, environment, CI, or
  application configuration files.
- Creating migrations, models, endpoints, authentication code, UI screens,
  tests for application behavior, seeders, or demo data.
- Creating placeholder dashboards or any Stage 1 authentication feature.
- Adding `.gitignore`, `.gitattributes`, `.editorconfig`, `.gitkeep`, README,
  license, Git hooks, commit, tag, branch beyond `main`, or remote.
- Changing any locked specification, audit, `AGENTS.md`, reusable template, or
  Stage 0 closure decision, except this task file itself when its approved
  requirements are being corrected.
- Creating the complete Stage 1 task index or decomposing the remaining Stage 1
  work.

## 12. Stop Conditions

Stop and report before making changes if:

- the target `testlabuz/` already exists and is not safely empty;
- any required authoritative in-repository file is missing;
- the repository contains a material ambiguity between duplicate authoritative
  versions that cannot be resolved from the locked project documents and
  applicable `AGENTS.md`;
- the task conflicts with `docs/01–09` or an applicable `AGENTS.md`;
- a required destination or Git behavior is genuinely unspecified;
- a correct result requires installing a framework, dependency, or package;
- a correct result requires overwriting, merging, deleting, or modifying
  unrelated existing work;
- implementation requires a material scope expansion.

Do not guess, silently broaden scope, overwrite existing work, or modify locked
specifications from this task.

## 13. Required Codex Completion Report

Return:

1. **Verdict** — implemented, partially implemented, or blocked.
2. **Summary** — the repository foundation that now exists.
3. **Changed paths** — every created directory/file and why it was created.
4. **Artifact-preservation evidence** — how required locked specifications,
   audit, instructions, and task files were confirmed present and unchanged by
   this task; no external duplicate source package is required.
5. **Acceptance criteria** — evidence for every criterion.
6. **Checks** — exact commands and results, including Git root, branch, no
   commits, no remotes, and tree validation.
7. **Security/scope confirmation** — no secrets, executable project, tenant
   behavior, framework files, or unrelated changes introduced.
8. **Manual smoke status** — passed, failed, or not run with reason.
9. **Risks, deviations, or blockers** — including any pre-existing condition.

Implementation completion does not close the task. The task becomes `Accepted`
only after a separate read-only task review passes.
