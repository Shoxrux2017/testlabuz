# Codex Task: [Short Task Title]

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `[S00-AREA-000]` |
| Roadmap stage | `[Stage number and name]` |
| Area | `[Backend / Frontend / Integration]` |
| Status | `Draft` |
| Depends on | `[Task IDs or None]` |
| Blocks | `[Task IDs or None]` |

Do not start implementation while the status is `Draft` or a dependency is not
accepted.

## 2. Goal

[Describe one observable result this task must deliver. Keep the goal small
enough for one focused Codex implementation cycle.]

## 3. Current Context

[Briefly describe the relevant existing behavior, implementation state, and why
this task is the next approved slice. Do not restate the whole project.]

## 4. Included Scope

- [Included change 1]
- [Included change 2]
- [Included change 3]

## 5. Relevant Files

List expected files or focused areas. Codex must inspect the repository before
assuming every path already exists.

| File or directory | Expected action | Reason |
|---|---|---|
| `[path]` | `[Inspect / Create / Modify / Test]` | `[Why it is relevant]` |

Changes outside this list require a clear technical necessity within the
approved scope and must be reported. Unrelated files must not be changed.

## 6. Authoritative Specification References

Use exact document and section names. The locked specification remains
authoritative over this task.

| Document | Exact section | Requirement used by this task |
|---|---|---|
| `[docs/0X-name.md]` | `[Section number and title]` | `[Concise rule]` |
| `[AGENTS.md or nested AGENTS.md]` | `[Section number and title]` | `[Coding or workflow rule]` |

## 7. Relevant Business Rules

- [Business rule 1]
- [Business rule 2]

State only rules relevant to this task. Do not invent defaults or resolve an
ambiguity in the task file.

## 8. Requirements

### 8.1 Functional Requirements

1. [Required behavior]
2. [Required validation or state behavior]
3. [Required response or visible result]

### 8.2 Architecture and Code Organization

- Follow the locked Laravel/Flutter architecture and the nearest `AGENTS.md`.
- Keep controllers/widgets thin and responsibilities focused.
- Place business rules in the correct domain/application layer.
- Reuse an existing abstraction when it genuinely owns the behavior.
- Do not create unrelated abstractions, duplicate logic, or hidden parallel
  implementations.
- Preserve established naming, error, DTO/resource, and testing conventions.

Add task-specific architecture requirements here:

- [Task-specific requirement]

### 8.3 Authorization, Security, and Tenant Isolation

- Backend authorization is authoritative; UI hiding alone is never sufficient.
- Client-provided identifiers must never expand the authenticated user's scope.
- Cross-institution records must not be readable, writable, inferable, or
  attachable by direct IDs, filters, pagination, or related-resource lookups.
- Validate active-user, active-institution, role, ownership/relationship, and
  lifecycle requirements relevant to the operation.

Task-specific positive and negative access cases:

- [Authorized case]
- [Unauthorized or cross-tenant case]

If this section is genuinely not applicable, explain why; do not simply delete
it.

### 8.4 Validation, Errors, and Observability

- Follow the locked API/error contract and do not expose sensitive internals.
- Use validation errors for malformed input and the approved authorization,
  not-found, conflict, or lifecycle response for domain failures.
- Add only safe, useful logs; never log passwords, tokens, private file data, or
  other secrets.

Add exact task-specific cases:

- [Case → expected response/behavior]

## 9. Acceptance Criteria

Use objective, testable outcomes.

- [ ] [Observable success criterion]
- [ ] [Validation/lifecycle criterion]
- [ ] [Authorized-access criterion]
- [ ] [Unauthorized/cross-tenant criterion]
- [ ] [Architecture/code-organization criterion]
- [ ] No unrelated behavior or locked product contract changed.

## 10. Tests and Verification

### 10.1 Automated Tests

- [ ] [Unit or domain test]
- [ ] [Feature/widget/repository test]
- [ ] [Regression test]

### 10.2 Negative and Security Tests

- [ ] [Unauthenticated case]
- [ ] [Wrong-role case]
- [ ] [Cross-institution/direct-ID case]
- [ ] [Invalid lifecycle or malformed-input case]

Remove a listed case only when it is not applicable and explain why in the
completion report.

### 10.3 Quality Gates

Run the applicable project commands defined by the repository and nested
`AGENTS.md` files:

```text
[format command]
[static-analysis/lint command]
[focused test command]
[required broader regression command]
```

### 10.4 Manual Smoke Check

1. [Action]
2. [Expected result]

If manual verification is not possible in the environment, report it clearly;
do not claim it passed.

## 11. Explicit Non-Goals

- [Not included behavior 1]
- [Adjacent stage or feature not included]
- [Refactor/migration/UI work intentionally excluded]

## 12. Stop Conditions

Stop and report before changing product behavior if:

- this task conflicts with `docs/01–09` or an applicable `AGENTS.md`;
- two authoritative documents appear to conflict;
- a required behavior is genuinely unspecified;
- a dependency is missing or not accepted;
- correct implementation requires a material scope expansion;
- safe tenant isolation or authorization cannot be established from the
  approved contracts.

Do not guess, silently broaden scope, or modify locked specifications from an
implementation task.

## 13. Execution and Acceptance Workflow

Use this workflow unless this task file defines a stricter task-specific
exception.

### Phase 0 - Git Preflight

Before changing files:

1. Verify the task status is `Approved` and all dependencies are `Accepted`.
2. Verify local `main` is clean and synchronized with `origin/main`.
3. Create one task branch from current `main`.
4. Verify `origin` is the approved remote.
5. Verify no existing Git state would require force-push, history rewrite,
   destructive cleanup, or bypassing required checks.

Stop and report if preflight is unsafe.

### Phase 1 - Implementation

Implement only this task. Run the task's tests, quality gates, security checks,
and smoke checks before requesting acceptance.

Do not commit or push during Phase 1.

### Phase 2 - Read-Only Acceptance Gate

Review the complete Phase 1 result against this task, referenced locked
specifications, `AGENTS.md`, tests, security requirements, and acceptance
criteria.

During Phase 2:

- make no file changes;
- make no Git configuration changes;
- do not stage additional changes;
- do not commit;
- do not push;
- do not fix findings.

If any blocking or material finding exists, return:

```text
FINAL STATUS: NOT ACCEPTED
```

Then stop. Do not start another task.

### Phase 3 - Post-Acceptance Git Delivery

Run only if Phase 2 returns `PASS`.

1. Apply only required task/index acceptance bookkeeping.
2. Re-run final diff, format, security, and secret checks required by the task.
3. Create one focused commit with the task ID in the commit body.
4. Push the task branch to `origin`.
5. Open a Pull Request to `main` when tooling/authentication permits.
6. Merge only when required checks pass and the merge is permitted.
7. Resynchronize local `main` from `origin/main`.
8. Verify local `main == origin/main`.
9. Verify `git status --short` is empty.

If acceptance passed but delivery cannot safely complete, return:

```text
FINAL STATUS: DELIVERY BLOCKED
```

If delivery completes, return:

```text
FINAL STATUS: ACCEPTED
```

Never force-push, rewrite history, bypass checks with `--no-verify`, modify
global Git configuration, silently replace `origin`, or commit credentials,
tokens, private keys, certificates, or environment secrets.

## 14. Required Codex Final Report

Return:

1. **Final status** — exactly one of `ACCEPTED`, `NOT ACCEPTED`, or
   `DELIVERY BLOCKED`.
2. **Phase 0 preflight** — dependency, branch, remote, and safety evidence.
3. **Implementation summary** — what changed and what now works.
4. **Changed files** — each file and why it changed.
5. **Acceptance gate findings** — `No blocking or material findings` or exact
   findings.
6. **Acceptance criteria** — PASS/FAIL evidence for every criterion.
7. **Tests and quality gates** — exact commands and results.
8. **Security and tenant checks** — positive and negative cases verified, or
   N/A with reason.
9. **Git delivery evidence** — commit hash, remote branch/PR/merge evidence,
   local/remote synchronization, and clean status.
10. **Scope confirmation** — non-goals preserved and unrelated changes avoided.
11. **Manual smoke status** — passed, failed, or not run with reason.
12. **Risks, deviations, or blockers** — including any pre-existing failures.
