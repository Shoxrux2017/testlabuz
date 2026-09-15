# Stage 8 Closure Review Contract — Blitz Task Workflow

## 1. Closure Metadata

| Field | Value |
|---|---|
| Review ID | `STAGE-08-CLOSURE` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Review mode | `Independent read-only closure audit followed by bookkeeping-only delivery` |
| Verification model | `Workflow v3 — Lean Verification + Backend/Frontend block checkpoints + Integration Harness Preflight` |
| Status | `Pending — execute only after S08-INT-001 PASS + valid owner closure approval and all required fixes/delivery` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Stage index | `tasks/STAGE_08_TASK_INDEX.md` |
| Audited accepted product `origin/main` | `Resolve at closure execution` |
| Local `main` | `Resolve at closure execution` |
| Ahead/behind | `0/0 required` |
| Working tree | `Clean required` |
| Previous Stage | `Stage 7 — Closed / PASS` |
| Backend Phase 2 | `PASS required` |
| Frontend Phase 2 | `PASS required` |
| Integration | `S08-INT-001 — Accepted / Delivered / PASS required` |
| Owner frontend approval | `valid /approve frontend owner comment + matching unedited bot receipt required` |
| Owner integration approval | `valid /approve integration owner comment + matching unedited bot receipt required` |
| Owner closure approval | `valid /approve closure owner comment + matching unedited bot receipt required` |
| Open findings | `P1=0, P2=0 required; default P3=0` |
| Proposed verdict | `Pending` |
| Next permitted gate on closure PASS | `Stage 9 — Checking and Scoring planning/decomposition only` |

This file is a **closure-review contract**, not an implementation task.

Stage Closure Review begins only after all implementation, checkpoint,
integration, focused-fix, delivery, manual-smoke and cleanup work for Stage 8 is
complete **and** the Orchestrator has reached:

```text
OWNER_CLOSURE_APPROVAL_REQUIRED
```

and the repository owner has issued:

```text
/approve closure
```

at that exact stopped state with a valid matching bot receipt.

Integration PASS alone does not release Closure Review.

During the read-only closure audit:

- do not edit production code;
- do not edit tests;
- do not fix findings;
- do not stage;
- do not commit;
- do not push;
- do not merge;
- do not change Stage/task bookkeeping before the substantive verdict is known.

ChatGPT owns:

- closure analysis;
- evidence-validity decisions;
- roadmap/Definition-of-Done mapping;
- finding severity;
- final verdict;
- determination of the minimum sufficient rerun when evidence was invalidated.

Codex is not used merely to collect closure evidence.

If closure finds a production defect, Codex receives a separate focused
implementation contract.

Do **not** create a duplicate `CODEX-PROMPT`.

---

# 2. Closure Entry Conditions

All required conditions must pass.

| Condition | Required closure state |
|---|---|
| Stage 7 explicitly closed | `PASS` |
| Stage 8 decomposition/index approved and delivered | `PASS` |
| `S08-DOC-001` | `Accepted / Delivered` |
| `S08-BE-001…010` | all `Accepted / Delivered` |
| `S08-BE-PHASE-2` | `PASS` |
| `S08-FE-001…006` | all `Accepted / Delivered` |
| `S08-FE-PHASE-2` | `PASS` |
| `S08-INT-001` integration assets | `Accepted / Delivered / PASS` |
| Owner frontend approval evidence | valid `/approve frontend` owner comment + matching unedited receipt |
| Owner integration approval evidence | valid `/approve integration` owner comment + matching unedited receipt |
| Owner closure approval evidence | valid `/approve closure` owner comment + matching unedited receipt |
| Approval invalidation/rejection after receipt | none |
| Integration Harness Preflight | `PASS` |
| Windows real-stack | `PASS` |
| Android Teacher smoke | `PASS` |
| Android Student smoke | `PASS` |
| API/security/Tenant verification | `PASS` |
| DB/private-file oracle | `PASS` |
| Backend restart persistence/idempotency | `PASS` |
| Integration cleanup | `PASS` |
| Required focused fixes | all delivered/reviewed |
| Current accepted Stage 8 result | present on `origin/main` |
| Local `main == origin/main` | required |
| Ahead/behind | `0/0` |
| Working tree | clean |
| Unresolved P1 | `0` |
| Unresolved P2 | `0` |

Any failed required entry condition blocks closure.

Owner approval authority comes from the Stage Orchestrator's validated source
comment + receipt chain, not from a manually written INDEX flag or the mere
existence of this Closure contract.

Each approval must have been issued only at its applicable stopped state:

```text
/approve frontend    -> OWNER_FRONTEND_APPROVAL_REQUIRED
/approve integration -> OWNER_INTEGRATION_APPROVAL_REQUIRED
/approve closure     -> OWNER_CLOSURE_APPROVAL_REQUIRED
```

An early/wrong-gate command is not acceptable closure evidence.

ChatGPT verifies this Stage-control evidence. Codex is not used to inspect or
reconstruct owner-gate authority.

---

# 3. Closure Git Preflight

Immediately before substantive closure review:

```bash
git switch main
git fetch --prune origin
git branch --show-current
git rev-parse HEAD
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
git status --short
```

Required:

```text
branch = main
HEAD == origin/main
ahead/behind = 0/0
working tree = clean
```

Freeze:

```text
CLOSURE_AUDITED_MAIN = <sha>
```

Do not use the historical planning baseline as the closure product SHA.

If `origin/main` advances during closure:

- inspect the new commits;
- determine whether they are evidence-safe bookkeeping or materially affect
  accepted product behavior;
- refresh the audit baseline when required;
- do not silently preserve invalidated evidence.

---

# 4. Authoritative Closure Inputs

At execution ChatGPT reviews current authoritative GitHub state.

Required inputs:

```text
AGENTS.md
backend/AGENTS.md
frontend/AGENTS.md

tasks/README.md
tasks/STAGE_08_TASK_INDEX.md

S08-DOC-001
S08-BE-001…010
S08-BE-PHASE-2
S08-FE-001…006
S08-FE-PHASE-2
S08-INT-001

current backend/frontend source
current migrations/routes/config/tests
current integration assets/evidence
delivery PR/merge history
```

Relevant locked project documents:

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
```

Closure must read the **final post-S08-DOC-001 versions**, not assume the
pre-Stage-8 planning wording remained unchanged.

---

# 5. Pre-Closure Task Inventory

Stage 8 has twenty required pre-closure items.

Populate actual final delivery evidence at closure.

| Order | Task | Required final state | Delivery / evidence |
|---:|---|---|---|
| 1 | `S08-DOC-001` | `Accepted / Delivered` | `<PR/SHA>` |
| 2 | `S08-BE-001` | `Accepted / Delivered` | `<PR/SHA>` |
| 3 | `S08-BE-002` | `Accepted / Delivered` | `<PR/SHA>` |
| 4 | `S08-BE-003` | `Accepted / Delivered` | `<PR/SHA>` |
| 5 | `S08-BE-004` | `Accepted / Delivered` | `<PR/SHA>` |
| 6 | `S08-BE-005` | `Accepted / Delivered` | `<PR/SHA>` |
| 7 | `S08-BE-006` | `Accepted / Delivered` | `<PR/SHA>` |
| 8 | `S08-BE-007` | `Accepted / Delivered` | `<PR/SHA>` |
| 9 | `S08-BE-008` | `Accepted / Delivered` | `<PR/SHA>` |
| 10 | `S08-BE-009` | `Accepted / Delivered` | `<PR/SHA>` |
| 11 | `S08-BE-010` | `Accepted / Delivered` | `<PR/SHA>` |
| 12 | `S08-BE-PHASE-2` | `PASS` | `<audited SHA/evidence>` |
| 13 | `S08-FE-001` | `Accepted / Delivered` | `<PR/SHA>` |
| 14 | `S08-FE-002` | `Accepted / Delivered` | `<PR/SHA>` |
| 15 | `S08-FE-003` | `Accepted / Delivered` | `<PR/SHA>` |
| 16 | `S08-FE-004` | `Accepted / Delivered` | `<PR/SHA>` |
| 17 | `S08-FE-005` | `Accepted / Delivered` | `<PR/SHA>` |
| 18 | `S08-FE-006` | `Accepted / Delivered` | `<PR/SHA>` |
| 19 | `S08-FE-PHASE-2` | `PASS` | `<audited SHA/evidence>` |
| 20 | `S08-INT-001` | `Accepted / Delivered / PASS` | `<PR/SHA/evidence>` |

Focused fixes discovered during Phase 2/integration belong to the checkpoint or
integration gate that discovered them.

Do not invent unnecessary extra task IDs merely because a focused correction was
required.

Closure must verify every required implementation/fix commit is an ancestor of
`CLOSURE_AUDITED_MAIN`.

Also record the three validated owner-gate receipts as orchestration evidence:

```text
frontend approval receipt
integration approval receipt
closure approval receipt
```

These are workflow-authority evidence, not implementation task rows.

---

# 6. Stage 8 Product Boundary

The accepted Stage 8 vertical must end at:

```text
Teacher prepares Blitz
-> optionally schedules
-> optional official Blitz designation
-> Teacher activates
-> server freezes synchronized/individual timer mode
-> assigned Student explicitly starts/resumes
-> Student receives safe Questions only after Start
-> Student saves typed/private-file answers
-> explicit Submit OR authoritative timeout/Teacher close freezes Attempt
-> optional one-Student exception excludes #1
-> Student explicitly starts replacement #2
-> Teacher monitors operational state
-> immutable Stage 8 execution history is ready for Stage 9
```

Stage 8 must **not** cross into Stage 9.

---

# 7. Stage 9 Boundary — Mandatory Closure Audit

The next roadmap stage is:

```text
Stage 9 — Checking and Scoring
```

Stage 8 owns execution/finalization only.

Stage 9 owns:

```text
automatic answer checking
Teacher manual review
awarded points
feedback
checking timestamps
Attempt scoring
score normalization
official Homework score selection
official Blitz score selection
replacement #2 score candidacy resolution
zero points for unanswered Questions as scoring behavior
waiting_for_teacher_review transitions created by checking
checked transitions created by checking
```

Closure must explicitly prove Stage 8 did **not** implement Stage 9 behavior.

Stage 8 timeout may freeze:

```text
timed_out_finalized
```

but Stage 8 does not itself calculate points.

Unanswered Questions remain:

```text
no fabricated answer row
```

and are interpreted/scored later by Stage 9.

Answers needing Teacher judgment remain frozen pending data; Stage 8 does not
perform the Teacher review.

Any Stage 9 production scoring/checking/result implementation that entered Stage
8 without an approved boundary change is a closure blocker.

---

# 8. Documentation Alignment Audit

`S08-DOC-001` is a closure-critical dependency.

Review final `docs/01–09` for one consistent contract.

Required final semantics include:

- Stage 8 freezes work; Stage 9 checks/scores;
- timeout does not fabricate unanswered Answer rows;
- no Stage 8 point calculation;
- lifecycle:
  ```text
  Draft -> Scheduled -> Active -> Closed -> Archived
  ```
- whole-Blitz timer only;
- synchronized + individual timer modes only;
- server time authoritative;
- normal Blitz Attempt count = 1;
- one Student-specific additional exception Attempt maximum;
- exception reason required;
- original #1 retained/ineligible;
- replacement #2 full own duration in both timer modes;
- synchronized common end unchanged by replacement;
- monitoring operational/no scoring;
- official pair/cohort semantics aligned.

Search final docs for stale contradictory wording.

Closure result:

```text
Documentation synchronization = PASS | FAIL
```

A material docs/product contradiction blocks closure.

---

# 9. Roadmap Acceptance Criterion

Read the **final accepted Stage 8 section** of `docs/06-roadmap.md`.

The final closure criterion must be semantically equivalent to:

> A Teacher can run a real in-class Blitz using the institution's approved
> timer-start mode, fixed attempt rules, authoritative timeout finalization and
> Student-specific exception while protected Student submissions/history are
> reliably preserved.

If `S08-DOC-001` updates the exact wording, copy the final exact criterion into
the executed closure record.

Do not use stale pre-alignment language to require Stage 9 scoring from Stage 8.

---

# 10. Stage 8 Roadmap Capability Matrix

Every required Stage 8 capability must have implementation and verification
evidence.

| Capability | Required closure result |
|---|---|
| Teacher creates Blitz from Topic | `PASS` |
| Group assignment | `PASS` |
| Selected-Student practice assignment | `PASS` |
| Instructions/Questions/points | `PASS` |
| Whole-Blitz positive duration | `PASS` |
| Normal Attempt rule fixed at 1 | `PASS` |
| Draft/Scheduled/Active/Closed/Archived lifecycle | `PASS` |
| Scheduled state does not auto-activate | `PASS` |
| Teacher activation required | `PASS` |
| Institution timer-start mode snapshotted | `PASS` |
| Server clock authoritative | `PASS` |
| Synchronized common timer | `PASS` |
| Individual Student-start timer | `PASS` |
| No per-question timer | `PASS` |
| Student sees only assigned active eligible Blitz | `PASS` |
| Questions hidden before Start | `PASS` |
| Start/Resume durable idempotency | `PASS` |
| Typed answer persistence | `PASS` |
| Private file answer persistence/protection | `PASS` |
| Explicit Submit durable idempotency | `PASS` |
| Timeout stops late writes | `PASS` |
| Timeout finalizes at exact Attempt deadline | `PASS` |
| Teacher Close finalization | `PASS` |
| Timeout takes precedence once due | `PASS` |
| Never-started Student gets no fabricated Attempt | `PASS` |
| Unanswered Question gets no fabricated Answer row | `PASS` |
| Exactly one Student-specific exception can be granted | `PASS` |
| Exception requires authorized Teacher + reason | `PASS` |
| Original #1 retained | `PASS` |
| Original #1 becomes `official_score_eligible=false` | `PASS` |
| Grant itself creates no #2 | `PASS` |
| Replacement #2 created only by Student Start | `PASS` |
| #2 gets full duration from its own Start | `PASS` |
| Synchronized common end unchanged by #2 | `PASS` |
| Attempt #3 blocked | `PASS` |
| Teacher monitoring operational state | `PASS` |
| Monitoring cannot answer for Student | `PASS` |
| Teacher mobile Activate | `PASS` |
| Teacher mobile basic monitoring | `PASS` |
| Student desktop/mobile execution | `PASS` |
| Cross-Institution access blocked | `PASS` |
| No Stage 9 checking/scoring/result | `PASS` |

Any missing required capability blocks closure.

---

# 11. Required-Test Coverage Mapping

Review final evidence against the Stage 8 roadmap test families.

At minimum closure must map evidence for:

```text
Draft Blitz inaccessible to Student
Scheduled Blitz inaccessible before activation
Teacher activation scope
unassigned Student blocked
synchronized mode
individual mode
configured duration
device clock/timezone cannot extend Blitz
timeout finalization
late write rejection
one normal Attempt
one Student-specific extra Attempt with required reason
more than one extra blocked
original invalid Attempt retained/ineligible
Teacher monitoring scope
Student cannot edit terminal/timed-out Attempt
cross-Institution denial
desktop/mobile security consistency
```

Where final documentation correctly moves:

```text
unanswered zero scoring
manual answer waiting-for-review transitions
```

to Stage 9, closure must not treat absence of those scoring operations as Stage 8
failure.

---

# 12. Stage Definition of Done

Evaluate every item from roadmap `3.2 Stage Definition of Done`.

| Definition-of-Done condition | Required |
|---|---|
| Approved Stage 8 business behavior implemented | `PASS` |
| Required backend/API works | `PASS` |
| Required desktop/mobile UI connected to real data | `PASS` |
| No core-path placeholder remains | `PASS` |
| Server-side permissions enforced | `PASS` |
| Multi-Institution isolation enforced | `PASS` |
| Validation/error behavior matches approved contract | `PASS` |
| Automated tests pass | `PASS` |
| Static/lint/format checks pass | `PASS` |
| Required manual smoke passes | `PASS` |
| No blocking regression in earlier Stages | `PASS` |
| Relevant documentation synchronized | `PASS` |
| ChatGPT review has no unresolved blocker | `PASS` |
| Stage explicitly marked closed before Stage 9 implementation | `PASS` |

No required item may be marked `N/A` merely for convenience.

---

# 13. Backend Phase 2 Evidence Review

Reuse accepted evidence when still valid.

At closure record:

| Field | Value |
|---|---|
| Review | `S08-BE-PHASE-2` |
| Audited SHA | `<sha>` |
| Verdict | `PASS required` |
| Findings | `P1=0, P2=0; final P3 disposition` |
| Full backend regression | `<exact result>` |
| Format/static | `<exact result>` |
| Stage-wide diff | `<exact result>` |
| Later production changes after checkpoint | `<none/list>` |
| Evidence valid at closure | `Yes/No` |
| Additional rerun | `<none/exact commands>` |

Closure does not automatically rerun the backend suite.

If later accepted changes affected:

```text
API
schema/migration
authorization/Tenant
Blitz lifecycle
Attempt timing/finalization
idempotency
answer/file mutation
exception #2
monitoring
shared Homework infrastructure
```

ChatGPT decides the exact invalidated evidence.

A required command that previously failed must eventually pass.

---

# 14. Frontend Phase 2 Evidence Review

At closure record:

| Field | Value |
|---|---|
| Review | `S08-FE-PHASE-2` |
| Audited SHA | `<sha>` |
| Verdict | `PASS required` |
| Findings | `P1=0, P2=0; final P3 disposition` |
| Full Flutter suite | `<exact result>` |
| `flutter analyze --no-pub` | `<exact result>` |
| Read-only format check | `<exact result>` |
| Windows debug build | `<PASS>` |
| Android debug build | `<PASS>` |
| Stage-wide diff | `<PASS>` |
| Later production changes | `<none/list>` |
| Evidence valid at closure | `Yes/No` |
| Additional rerun | `<none/exact commands>` |

Do not rerun the entire frontend checkpoint when later changes are integration
assets/bookkeeping only.

Do rerun affected evidence when a later product fix materially changed the
surface the checkpoint proved.

---

# 15. Integration Evidence Review

Closure requires:

```text
S08-INT-001 = Accepted / Delivered / PASS
```

Record:

```text
integration asset PR/merge
focused production-fix PRs if any
final real-stack audited product SHA
final integration audited main
```

Required evidence families:

- Harness Preflight;
- runtime guard;
- Stage 8 seeder;
- Windows real-stack Teacher flow;
- Windows Student pre-Start privacy;
- Windows Student execution;
- file flow;
- Submit with unanswered Questions;
- monitoring;
- exception grant;
- replacement #2;
- timeout;
- synchronized timing;
- individual timing;
- Teacher Close precedence;
- Scheduler;
- API auth/role;
- Tenant isolation;
- assignment/ownership;
- strict transport;
- durable idempotency;
- DB oracle;
- no-scoring oracle;
- private-file oracle;
- backend restart persistence/idempotency;
- Android Teacher smoke;
- Android Student smoke;
- cleanup.

All required final integration findings:

```text
P1=0
P2=0
```

Default:

```text
P3=0
```

---

# 16. Main Real-System Workflow Audit

Closure must prove the real system supports:

```text
Teacher authenticated
-> Topic
-> Blitz prepared
-> official designation where applicable
-> Activate
-> Student sees Active Blitz
-> pre-Start detail contains no Questions
-> explicit Start
-> server-safe Questions
-> countdown
-> typed/file answers
-> explicit Submit OR timeout/Teacher close
-> immutable terminal execution history
-> Teacher monitoring
-> optional exception grant
-> Student explicit replacement Start #2
-> replacement execution history
-> ready for Stage 9 checking/scoring
```

Evidence must combine:

```text
real Flutter UI
real Laravel API
real PostgreSQL
real private file storage
```

Direct API/DB oracle complements the UI flow; it does not replace the required
real frontend integration.

---

# 17. Official Pair / Cohort Closure Audit

Verify final accepted implementation/evidence proves:

- official Homework side is preserved;
- official Blitz fills the same Topic result-pair row;
- locked partial pair with null Blitz side can be filled once;
- populated locked side cannot be replaced;
- first activated official task establishes common cohort when needed;
- later official task uses exact persisted cohort;
- current Group drift does not redefine official cohort;
- first official Student activity locks pair meaning where required;
- practice selected-Student Blitz never mutates official pair/cohort;
- exception/Submit/monitoring never change pair identity.

Any official cohort corruption is a P1 closure blocker.

---

# 18. Timer Closure Audit

Verify server-authoritative timing.

## Synchronized normal #1

```text
activation -> common end = activation + duration
normal Student deadline = common end
late opener gets remaining common time
```

## Individual normal #1

```text
activation exposes Blitz
Student Start -> deadline = Start + duration
```

## Replacement #2 — both modes

```text
replacement Start -> deadline = replacement Start + duration
```

Synchronized replacement:

```text
common class end remains unchanged
#2 may extend after it
#2 may start after common end while Blitz is Active
```

No device clock/timezone extends execution.

No per-question timer.

---

# 19. Attempt / Exception Closure Audit

Required Attempt policy:

```text
#1 = normal
#2 = one approved Student-specific replacement
#3 = impossible
```

Grant:

```text
requires terminal/due valid #1
required reason
creates one exception row
sets #1 official_score_eligible=false
does not create #2
```

Replacement Start:

```text
creates #2
links exception
#2 official_score_eligible=true
copies no answers/files
```

Original #1 remains immutable history except the explicit eligibility exclusion
and valid due finalization before grant.

No class-wide attempt limit changes.

---

# 20. Finalization Closure Audit

Explicit Submit:

```text
status = submitted
reason = student_submit
submitted_at = finalized_at = locked_at
```

Timeout:

```text
status = timed_out_finalized
reason = timeout_auto_submit
submitted_at = null
finalized_at = locked_at = exact deadline
```

Teacher close before deadline:

```text
status = submitted
reason = task_closed_auto_finalize
submitted_at = null
finalized_at = locked_at = close instant
```

At/equal/after deadline:

```text
timeout wins
```

Verify:

- terminal reason/timestamps immutable;
- repeated reconciliation no churn;
- no Student answer/file write after freeze;
- no fabricated Attempt for never-started Student;
- no fabricated Answer row for unanswered Question.

---

# 21. Idempotency Closure Audit

Durable Stage 8 operations:

```text
teacher.blitz.activate
student.blitz.attempt.start
student.blitz.attempt.submit
teacher.blitz.attempt_exception.grant
```

Closure evidence must prove:

- secure canonical key;
- Institution/user/operation scope;
- authorization before replay;
- same key/fingerprint replay;
- different fingerprint reuse conflict;
- domain result + completed claim atomic;
- no incomplete committed claim;
- restart persistence.

Critical Start rule:

```text
old completed #1 Start key after exception still replays #1
```

It must never create #2.

Replacement #2 uses a new Student Start key.

Frontend recovery uses completed Start replay key, not a new key.

---

# 22. Student Privacy / Security Closure Audit

Verify Student:

- cannot see Questions before Start;
- never receives correct-answer configuration;
- cannot access another Student Attempt/file;
- cannot access foreign Institution resources;
- cannot write after timeout/finalization;
- cannot obtain extra Attempt without valid Teacher grant;
- cannot create #3;
- cannot use direct UUID possession to widen access.

Private Student file:

- stored private;
- protected download;
- no public path;
- survives restart;
- unauthorized Teacher Stage 8 download remains denied.

Any leak is P1.

---

# 23. Teacher Monitoring Closure Audit

Verify monitoring:

```text
operational only
```

It may show:

- assigned Student;
- not-started/in-progress/finalized/waiting operational state;
- Attempt number;
- timing snapshot;
- exception metadata for Teacher.

It must not expose:

```text
Student answer content
Student file metadata
correct answers
checking data
awarded points
score
official result
```

Monitoring GET may trigger shared timeout reconciliation only.

It must not mutate:

```text
answers
pair
exception
task lifecycle
score
```

otherwise.

---

# 24. Desktop / Mobile Closure Audit

Teacher:

## Desktop

Required Stage 8 capability:

```text
read
create/edit
Question Builder
Schedule/Reschedule
official designation
Activate
Close
Archive
Monitor
grant exception
```

## Mobile

Required:

```text
read Blitz
Activate Draft/Scheduled
basic Monitor Active
```

Must not expose:

```text
Create/Edit/Questions
Schedule
official mutation
Close
Archive
exception grant
```

Student desktop/mobile:

```text
Active Blitz
pre-Start detail
Start/Resume/replacement Start
countdown
answer/file execution
Submit
terminal summary
```

Device-specific UX may differ, but security/business rules must match.

---

# 25. Previous-Stage Regression Audit

Closure must confirm no blocking regression in:

```text
Stage 1 auth/role/session
Stage 2 Institution lifecycle
Stage 3 Institution settings
Stage 4 Group/membership relationships
Stage 5 Topic/material lifecycle
Stage 6 Homework authoring/result-pair
Stage 7 Student Homework execution/files/Submit
```

High-risk shared Stage 8 changes include:

```text
Question authoring
Assessment recipient snapshot
Topic open-assessment guard
result-pair API
Student answer PUT
protected Student file access
Submit dispatcher
idempotency infrastructure
Teacher/Student router
shared Student Question/answer domains
```

Backend/Frontend Phase 2 evidence should cover these regressions.

Any known blocking earlier-Stage regression prevents closure.

---

# 26. Stage 8 Explicit Non-Goals Audit

Closure must confirm these did **not** enter production as Stage 8 behavior:

```text
automatic Question scoring
Teacher manual marking/review
awarded points
Attempt normalized score
official Homework score selection
official Blitz score selection
Homework-Blitz score comparison
final Topic result
understanding category calculation
Student/Parent result release
AI/fuzzy checking
exception revoke/edit
more than one replacement Attempt
Attempt #3
per-question Blitz timer
automatic Schedule->Activate transition
Teacher answering for Student through monitoring
```

If found, classify whether:

- accidental scope creep;
- approved prerequisite/refactor;
- Stage 9 implementation improperly pulled forward.

Unapproved product behavior blocks closure.

---

# 27. Security / Tenant Matrix

Final accepted evidence must include:

| Boundary | Required result |
|---|---|
| unauthenticated Stage 8 API | denied |
| wrong role Teacher endpoint | denied |
| wrong role Student endpoint | denied |
| foreign Institution Blitz | privacy-safe denied |
| foreign Student exception target | denied |
| unassigned Student Start | denied |
| Student outside frozen official cohort | denied |
| another Student's Attempt mutation | denied |
| another Student's file download | denied |
| Teacher Student-submission download in Stage 8 | denied |
| direct UUID probing | no scope widening |
| idempotency record lookup | no authorization bypass |

Any Tenant/ownership leak is P1.

---

# 28. Persistence / Restart Audit

Closure must preserve integration proof that after restarting only the dedicated
backend app process/container:

```text
Blitz lifecycle
pair/cohort
Attempt #1
answers/files
terminal history
exception row
Attempt #2
idempotency records
```

remain intact.

Private file volume remains available.

No history is reconstructed from client state.

No timestamp/reason changes merely because app restarted.

---

# 29. Integration Cleanup Audit

Required cleanup:

```text
manifest-owned Stage 8 DB fixtures removed
manifest-owned private blobs removed
temporary local Stage 8 test files removed
temporary Android reverse mapping removed
unrelated sentinel preserved
```

The dedicated empty Stage 8 Docker/private named volume may remain provisioned if
the integration contract permits it.

Do not require deleting unrelated test database state.

---

# 30. Evidence Validity Policy

Closure reuses valid evidence.

Do not rerun:

```text
full backend suite
full Flutter suite
builds
full real-stack E2E
Android smoke
```

merely because closure started.

ChatGPT determines whether later changes invalidate evidence.

Default guidance:

| Later change | Closure evidence effect |
|---|---|
| docs/bookkeeping only | product evidence normally remains valid |
| comments/rename only | normally no broad rerun |
| isolated test strengthening | production evidence remains; run affected test/static checks as needed |
| narrow feature production fix | rerun focused checks + affected integration path |
| shared auth/session/router/network/idempotency change | broader evidence may be invalidated |
| schema/API/authorization/Tenant/security change | corresponding backend/integration evidence normally invalidated |
| dependency/platform/build-system change | relevant analyze/build evidence invalidated |
| previously failed required command | it must eventually pass |
| integration failed before later phases | rerun enough final flow to prove complete final state |

Do not preserve invalid evidence.

Do not rerun valid evidence by habit.

---

# 31. Closure Findings Severity

## P1 — closure blocker

Examples:

- Tenant/privacy/security leak;
- pre-Start Question leak;
- timer can be extended client-side;
- Attempt #3 possible;
- official cohort corruption;
- terminal history overwrite;
- protected file leak;
- Stage 8 scoring corrupts later result semantics.

## P2 — closure blocker

Examples:

- material API/lifecycle mismatch;
- wrong replacement duration;
- broken durable idempotency;
- monitoring material state error;
- mobile capability overreach;
- missing roadmap capability;
- deterministic required test/build/E2E failure;
- earlier Stage regression.

## P3

Minor maintainability/clarity/test-quality issue.

Closure target:

```text
P1 = 0
P2 = 0
P3 = 0
```

A deliberately deferred P3 requires explicit rationale.

---

# 32. Closure PASS Conditions

Closure may return:

```text
STAGE CLOSED
```

only when all are true:

```text
Stage 7 remains Closed/PASS

S08-DOC-001 accepted/delivered
S08-BE-001…010 accepted/delivered
S08-BE-PHASE-2 PASS
S08-FE-001…006 accepted/delivered
S08-FE-PHASE-2 PASS
S08-INT-001 accepted/delivered/PASS

owner frontend approval receipt VALID
owner integration approval receipt VALID
owner closure approval receipt VALID
no later rejection/invalidation of those approvals

roadmap acceptance PASS
Stage Definition of Done PASS
documentation synchronization PASS

official pair/cohort PASS
synchronized timing PASS
individual timing PASS
timeout/close PASS
normal #1 PASS
exception/replacement #2 PASS
no #3 PASS

Student Question privacy PASS
Tenant/security PASS
private files PASS
idempotency PASS
monitoring PASS
desktop/mobile PASS
restart persistence PASS
cleanup PASS

Stage 9 boundary PASS
earlier-Stage regressions PASS

current accepted result is on origin/main
local main == origin/main
ahead/behind = 0/0
worktree clean

P1=0
P2=0
final P3 disposition accepted
```

---

# 33. Closure Failure Conditions

Return:

```text
FIXES REQUIRED BEFORE CLOSURE
```

when any required condition is missing or invalid.

Do not mark Stage 8 closed when:

- a task is not delivered;
- a checkpoint is not PASS;
- Integration is not PASS;
- any required owner approval receipt is missing, edited, rejected, invalidated or was issued at the wrong gate;
- required Android smoke is missing;
- required security/oracle evidence is missing;
- current main differs from accepted audited state without review;
- P1/P2 exists;
- docs materially contradict implementation;
- Stage 9 boundary was crossed incorrectly;
- required evidence was invalidated and not refreshed.

---

# 34. Substantive Closure Report Template

Before bookkeeping, ChatGPT should produce/record:

```text
Stage 8 Closure Read-Only Review

Audited accepted product main: <sha>
Local main: <sha>
origin/main: <sha>
ahead/behind: 0/0
working tree: clean

Previous Stage:
Stage 7 = Closed / PASS

Delivery:
S08-DOC-001 = Accepted / Delivered
S08-BE-001…010 = Accepted / Delivered
S08-BE-PHASE-2 = PASS
S08-FE-001…006 = Accepted / Delivered
S08-FE-PHASE-2 = PASS
S08-INT-001 = Accepted / Delivered / PASS

Owner gates:
frontend approval = VALID /approve frontend receipt
integration approval = VALID /approve integration receipt
closure approval = VALID /approve closure receipt

Evidence:
Backend Phase 2 = PASS
Frontend Phase 2 = PASS
Integration Harness Preflight = PASS
Windows real-stack = PASS
Android Teacher smoke = PASS
Android Student smoke = PASS
API/security = PASS
DB/private-file oracle = PASS
Restart persistence/idempotency = PASS
Cleanup = PASS

Closure audit:
Roadmap acceptance = PASS
Definition of Done = PASS
Docs synchronization = PASS
Pair/cohort = PASS
Timing = PASS
Attempt #1/#2 = PASS
Timeout/Close = PASS
Question privacy = PASS
Tenant/security = PASS
Idempotency = PASS
Monitoring = PASS
Mobile/Desktop scope = PASS
Stage 9 boundary = PASS
Earlier-stage regression = PASS

Findings:
P1 = 0
P2 = 0
P3 = 0

Verdict:
STAGE CLOSED
```

Do not update bookkeeping before this substantive verdict exists.

---

# 35. Closure Bookkeeping Delivery

Only after:

```text
Closure Read-Only Review = PASS
Closure verdict = STAGE CLOSED
```

prepare a **bookkeeping-only** closure delivery.

Expected files:

```text
tasks/STAGE_08_CLOSURE_REVIEW.md
tasks/STAGE_08_TASK_INDEX.md
tasks/README.md
```

`STAGE_08_CLOSURE_REVIEW.md` changes from this pending contract into the executed
closure record.

`STAGE_08_TASK_INDEX.md` records:

```text
all tasks final
Backend Phase 2 PASS
owner frontend approval evidence recorded
Frontend Phase 2 PASS
owner integration approval evidence recorded
S08-INT-001 PASS
owner closure approval evidence recorded
Stage 8 Closed/PASS
next gate = Stage 9 planning/decomposition only
```

`tasks/README.md` current project-state section records equivalent final Stage 8
handoff.

Do not modify product code in closure bookkeeping.

---

# 36. Documentation Changes at Closure

Default:

```text
no docs/01–09 product-contract edit during bookkeeping
```

because product documentation should already have been synchronized by:

```text
S08-DOC-001
```

and any later required focused documentation correction must be resolved before
the substantive closure verdict.

If closure discovers a real docs contradiction:

```text
Closure = NOT READY
```

Fix/review/deliver the documentation first.

Do not silently mix a new business decision into closure bookkeeping.

---

# 37. Closure Bookkeeping Branch / Commit

Use the repository's current Stage closure delivery convention.

Recommended branch:

```text
docs/stage8-closure
```

Recommended commit:

```text
docs(stage8): close blitz task workflow
```

The exact routine Git/GitHub delivery is executed by the Project Owner.

ChatGPT does not claim the Stage fully synchronized after merge until the
post-merge Git verification below passes.

---

# 38. Verification of Closure Bookkeeping

Because closure bookkeeping changes no production code, do not automatically
rerun product suites/E2E.

Before delivery:

```bash
git diff --check
```

Review the bookkeeping diff and ensure it contains only approved closure
records.

After merge:

```bash
git switch main
git fetch --prune origin
git pull --ff-only origin main
git branch --show-current
git rev-parse HEAD
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
git status --short
```

Required:

```text
branch = main
HEAD == origin/main
ahead/behind = 0/0
working tree clean
```

Then confirm the closure commit is an ancestor of both local and remote `main`.

---

# 39. Evidence Validity After Bookkeeping Merge

A closure-only bookkeeping merge does not invalidate:

```text
Backend Phase 2
Frontend Phase 2
Windows/Android builds
real-stack integration
API/security
DB/private-file oracle
restart persistence
manual mobile smoke
```

provided the closure diff is truly bookkeeping only.

Record:

```text
No product verification rerun required for closure bookkeeping
```

only after ChatGPT reviews the closure diff and confirms that condition.

---

# 40. Final Executed Closure Record

After bookkeeping delivery and post-merge sync, the executed
`STAGE_08_CLOSURE_REVIEW.md` should record at minimum:

```text
review date
accepted product SHA before closure bookkeeping
closure bookkeeping PR
closure bookkeeping merge SHA
post-merge main SHA
task delivery table
Backend Phase 2 evidence
Frontend Phase 2 evidence
Integration evidence
owner frontend approval receipt
owner integration approval receipt
owner closure approval receipt
Android Teacher smoke
Android Student smoke
cleanup
roadmap acceptance
Definition of Done
Stage 9 boundary
P1/P2/P3
STAGE CLOSED
```

Do not invent test counts/SHAs not present in accepted evidence.

---

# 41. Final Stage 8 Status

Only after substantive PASS + bookkeeping merge + final main sync:

```text
Closure Read-Only Review = PASS
Closure verdict = STAGE CLOSED
Stage 8 status = Closed / PASS
```

The Stage is then no longer an active implementation Stage.

---

# 42. Next Permitted Gate

After Stage 8 is fully closed:

```text
Stage 9 — Checking and Scoring
```

may proceed to:

```text
planning / analysis / decomposition only
```

Stage 8 closure does **not** authorize Stage 9 implementation automatically.

Required next workflow:

```text
re-check current GitHub main
read final Stage 8 handoff
read current Stage 9 roadmap/docs/current code
resolve Stage 9 architecture/business behavior
propose Stage 9 decomposition
obtain approval
prepare one implementation-ready task at a time
```

No Stage 9 Codex implementation before its planning/readiness gates are approved.

---

# 43. Closure Contract Readiness Verdict

```text
Closure entry gate                    = DEFINED
Git synchronization gate              = DEFINED
Task inventory                         = DEFINED
Stage 8 product boundary               = DEFINED
Stage 9 checking/scoring boundary      = DEFINED
Documentation synchronization audit    = DEFINED
Roadmap acceptance audit               = DEFINED
Definition of Done                     = DEFINED
Backend evidence validity              = DEFINED
Frontend evidence validity             = DEFINED
Integration evidence validity          = DEFINED
Official pair/cohort audit             = DEFINED
Timer audit                            = DEFINED
Attempt #1/#2/exception audit          = DEFINED
Timeout/Close audit                    = DEFINED
Idempotency audit                      = DEFINED
Student privacy/security audit         = DEFINED
Monitoring audit                       = DEFINED
Desktop/mobile audit                   = DEFINED
Previous-stage regression audit        = DEFINED
Persistence/restart audit              = DEFINED
Cleanup audit                          = DEFINED
Severity/verdict rules                 = DEFINED
Bookkeeping-only closure delivery      = DEFINED
Post-merge synchronization             = DEFINED
Evidence rerun policy                  = DEFINED
Next Stage gate                        = DEFINED

Closure contract readiness              = PASS
Execution state                         = BLOCKED until S08-INT-001 final PASS + valid /approve closure receipt
Owner gate evidence                     = all three receipts must be valid at closure
Next gate after full closure             = Stage 9 planning/decomposition only
```
