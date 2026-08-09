# Stage [Number] Closure Review — [Stage Name]

## 1. Closure Metadata

| Field | Value |
|---|---|
| Roadmap stage | `[Stage number and exact name]` |
| Review date | `[YYYY-MM-DD]` |
| Review mode | `Read-only` |
| Stage index | `[relative path]` |
| Proposed verdict | `[Pending]` |

This review begins only after every approved task in the stage has completed an
individual read-only review.

## 2. Authoritative Inputs

- [ ] Root and applicable nested `AGENTS.md` files
- [ ] Locked `docs/01–09` sections governing the stage
- [ ] Roadmap stage definition, dependencies, verification, and acceptance criteria
- [ ] Approved stage task index
- [ ] Every approved task and task-review result
- [ ] GitHub delivery evidence for every accepted task
- [ ] Current implementation and repository status
- [ ] Automated test, quality-gate, and manual-smoke evidence

## 3. Entry and Dependency Verification

| Dependency or entry condition | Result | Evidence |
|---|---|---|
| Previous stage explicitly closed | `[Pass/Fail]` | `[Reference]` |
| Required contracts remained stable | `[Pass/Fail]` | `[Reference]` |
| All approved stage tasks are `Accepted` | `[Pass/Fail]` | `[Task IDs/reviews]` |
| Every accepted task is delivered to `origin/main` | `[Pass/Fail]` | `[Task IDs/commits/PRs]` |
| Local `main` matches `origin/main` and working tree is clean | `[Pass/Fail]` | `[Git commands and hashes]` |
| No unapproved task or scope expansion entered the stage | `[Pass/Fail]` | `[Evidence]` |

## 4. Roadmap Acceptance-Criteria Matrix

Copy every acceptance criterion from the roadmap stage section.

| Roadmap acceptance criterion | Result | Implementation evidence | Verification evidence |
|---|---|---|---|
| `[Exact criterion]` | `[Pass/Fail/Not verified]` | `[Files/task IDs]` | `[Tests/reviews/smoke]` |

Every criterion must pass. A missing or unverified criterion blocks closure.

## 5. Stage Definition-of-Done Review

Use `06-roadmap.md`, section `3.2 Stage Definition of Done`.

| Definition-of-Done condition | Result | Evidence / N/A reason |
|---|---|---|
| Approved business behavior is implemented | `[Pass/Fail]` | `[Evidence]` |
| Required backend/API behavior works | `[Pass/Fail/N/A]` | `[Evidence]` |
| Required desktop/mobile UI uses real data | `[Pass/Fail/N/A]` | `[Evidence]` |
| No core-path placeholder remains | `[Pass/Fail/N/A]` | `[Evidence]` |
| Permissions are enforced server-side | `[Pass/Fail/N/A]` | `[Evidence]` |
| Multi-institution scope is enforced | `[Pass/Fail/N/A]` | `[Evidence]` |
| Validation and error behavior are defined | `[Pass/Fail/N/A]` | `[Evidence]` |
| Automated tests pass | `[Pass/Fail]` | `[Commands/results]` |
| Static analysis, linting, and formatting pass | `[Pass/Fail]` | `[Commands/results]` |
| Required manual smoke tests pass | `[Pass/Fail/N/A]` | `[Evidence]` |
| No blocking regression affects earlier stages | `[Pass/Fail]` | `[Evidence]` |
| Project documentation is synchronized | `[Pass/Fail]` | `[Files]` |
| Accepted work is present on `origin/main` | `[Pass/Fail]` | `[Commits/PRs]` |
| Review finds no unresolved blocker | `[Pass/Fail]` | `[Finding status]` |

`N/A` requires an explicit stage-specific explanation.

## 6. End-to-End and Cross-Layer Verification

| Workflow or contract boundary | Expected result | Actual evidence | Status |
|---|---|---|---|
| `[Backend ↔ frontend flow]` | `[Expected]` | `[Integration test/smoke]` | `[Pass/Fail]` |
| `[Lifecycle/error flow]` | `[Expected]` | `[Evidence]` | `[Pass/Fail]` |

Verify that Flutter and Laravel agree on requests, responses, errors, lifecycle
states, and authorization. Do not close a stage whose layers work only in
isolation.

## 7. Security and Data-Separation Verification

- [ ] Unauthenticated access is denied where required.
- [ ] Each approved role has only its allowed operations.
- [ ] Inactive user/institution behavior is enforced.
- [ ] Cross-institution access is denied through direct IDs, lists, filters,
      pagination, files, and related-resource lookups.
- [ ] Relationship and ownership checks cannot be bypassed.
- [ ] Lifecycle, timing, attempt, and visibility restrictions are enforced.
- [ ] Sensitive fields, files, logs, and errors are protected.
- [ ] Negative authorization tests pass.

Record any stage-specific checks and evidence:

[Evidence or justified N/A items.]

Any unresolved critical access-control issue blocks closure.

## 8. Test and Quality-Gate Summary

| Verification | Command / method | Result | Status |
|---|---|---|---|
| Backend focused tests | `[command]` | `[result]` | `[Pass/Fail/N/A]` |
| Backend regression suite | `[command]` | `[result]` | `[Pass/Fail/N/A]` |
| Frontend focused tests | `[command]` | `[result]` | `[Pass/Fail/N/A]` |
| Frontend regression suite | `[command]` | `[result]` | `[Pass/Fail/N/A]` |
| Static analysis / lint / format | `[commands]` | `[result]` | `[Pass/Fail]` |
| Integration tests | `[command]` | `[result]` | `[Pass/Fail/N/A]` |
| Manual stage smoke path | `[steps/reference]` | `[result]` | `[Pass/Fail]` |

## 9. Regression and Documentation Review

- [ ] Previous accepted stage paths remain green.
- [ ] Database migrations and backward compatibility are safe where applicable.
- [ ] API and Flutter contracts remain synchronized.
- [ ] Stage task index and individual task statuses are current.
- [ ] Every accepted task has `PASS` review status and delivered GitHub status.
- [ ] Local `main` is synchronized with `origin/main` and `git status --short`
      is empty.
- [ ] Relevant technical documentation reflects implemented behavior.
- [ ] No temporary workaround or TODO hides incomplete acceptance criteria.

## 10. Outstanding Findings and Risks

| ID | Severity | Finding or risk | Blocks closure? | Required action |
|---|---|---|---|---|
| `[SC-01]` | `[Critical/High/Medium/Low]` | `[Description]` | `[Yes/No]` | `[Action]` |

If none: `No outstanding findings or risks.`

## 11. Final Verdict

Choose exactly one:

- `Stage closed`
- `Fixes required before closure`
- `Closure blocked by specification or dependency`

**Verdict:** `[Pending]`

**Reason:** [Concise evidence-based explanation.]

## 12. Next Gate

[State the next allowed planning or implementation action. The next stage must
not begin until this stage is explicitly marked closed.]
