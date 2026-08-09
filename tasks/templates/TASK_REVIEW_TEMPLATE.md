# Read-Only Task Review: [Task ID — Task Title]

## 1. Review Metadata

| Field | Value |
|---|---|
| Roadmap stage | `[Stage number and name]` |
| Task file | `[relative path]` |
| Implementation reference | `[commit, branch, diff, or worktree state]` |
| Review mode | `Read-only` |
| Review date | `[YYYY-MM-DD]` |
| Gate result | `[Pending]` |

This review inspects and reports. It does not modify code, task scope, or locked
specifications. The reviewer must not stage, commit, push, merge, update Git
configuration, or fix findings during this gate. Any required correction becomes
a separate approved focused-fix task.

## 2. Review Inputs

- [ ] Root `AGENTS.md`
- [ ] Applicable nested `AGENTS.md`
- [ ] Approved implementation task
- [ ] Every specification section referenced by the task
- [ ] Changed code and tests
- [ ] Relevant existing implementation and regression surface

## 3. Scope and Change Audit

| Check | Result | Evidence / note |
|---|---|---|
| Changed files match the approved scope | `[Pass/Fail]` | `[Details]` |
| No unrelated behavior changed | `[Pass/Fail]` | `[Details]` |
| Explicit non-goals remain excluded | `[Pass/Fail]` | `[Details]` |
| No locked specification was changed by implementation | `[Pass/Fail]` | `[Details]` |
| No hidden placeholder, duplicate path, or dead code remains | `[Pass/Fail]` | `[Details]` |

## 4. Requirement and Acceptance-Criteria Review

| Requirement / criterion | Result | Evidence |
|---|---|---|
| `[Task requirement or AC]` | `[Pass/Fail/Not verified]` | `[File, test, or observed behavior]` |

Every acceptance criterion from the task must have a row. Missing evidence is
not a pass.

## 5. Architecture and Code Quality

- [ ] Responsibilities are in the correct layer/module.
- [ ] Controllers/widgets remain thin and focused.
- [ ] Business rules are centralized rather than duplicated.
- [ ] Names and abstractions communicate intent.
- [ ] Error, DTO/resource, repository, and state patterns follow project rules.
- [ ] No unnecessary refactor or over-engineering expanded the task.
- [ ] Code is clean, maintainable, formatted, and free of debug/dead code.

Evidence and notes:

[Findings or `No issue found`.]

## 6. Authorization, Security, and Tenant Isolation

| Check | Result | Evidence |
|---|---|---|
| Authentication and active-state rules | `[Pass/N/A/Fail]` | `[Details]` |
| Correct-role positive case | `[Pass/N/A/Fail]` | `[Details]` |
| Wrong-role/unauthenticated negative case | `[Pass/N/A/Fail]` | `[Details]` |
| Institution/relationship scope | `[Pass/N/A/Fail]` | `[Details]` |
| Cross-institution/direct-ID negative case | `[Pass/N/A/Fail]` | `[Details]` |
| Lifecycle, timing, attempt, or visibility rule | `[Pass/N/A/Fail]` | `[Details]` |
| Sensitive data, logging, and error exposure | `[Pass/N/A/Fail]` | `[Details]` |

Any `N/A` must include a reason. A critical authorization or tenant-isolation
gap is always blocking.

## 7. Tests and Verification

| Command or check | Expected | Actual result | Status |
|---|---|---|---|
| `[focused test command]` | `[Expected result]` | `[Observed output]` | `[Pass/Fail/Not run]` |
| `[lint/static analysis]` | `[Expected result]` | `[Observed output]` | `[Pass/Fail/Not run]` |
| `[broader regression command]` | `[Expected result]` | `[Observed output]` | `[Pass/Fail/Not run]` |
| `[manual smoke check]` | `[Expected result]` | `[Observed behavior]` | `[Pass/Fail/Not run]` |

Distinguish verified results from claims in the implementation report. Record
pre-existing failures separately from task-caused failures.

## 8. Findings

List findings from highest to lowest severity.

| ID | Severity | Finding | Evidence | Required correction |
|---|---|---|---|---|
| `[F-01]` | `[Critical/High/Medium/Low]` | `[Problem]` | `[Location/test]` | `[Focused correction]` |

If none: `No findings.`

Severity guidance:

- `Critical` — security, cross-tenant access, data loss, or core contract breach.
- `High` — acceptance criterion fails or required behavior is unusable.
- `Medium` — maintainability, validation, or test gap that prevents acceptance.
- `Low` — non-blocking improvement; must not be used to expand scope.

## 9. Acceptance Gate Result

Choose exactly one:

- `PASS`
- `NOT ACCEPTED`

`PASS` means there are no blocking or material findings and every task
acceptance criterion has evidence.

`NOT ACCEPTED` means at least one blocking/material finding, failed required
check, unsafe Git/security condition, scope breach, or unverified required
criterion remains. Do not commit, push, merge, or start another task from a
`NOT ACCEPTED` result.

**Gate result:** `[Pending]`

**Reason:** [Concise evidence-based explanation.]

## 10. Required Follow-Up

- [None, or the precise focused-fix/planning action required]

Do not close the task when a blocking finding, required test failure, or
unverified acceptance criterion remains.
