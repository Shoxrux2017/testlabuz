# Stage 7 Task Index — Student Homework and Submission Flow

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `Stage 7 — Student Homework and Submission Flow` |
| Stage status | `Backend implementation in progress — S07-BE-001…002 Accepted / Delivered` |
| Verification model | `Workflow v3 — Lean Verification + Integration Harness Preflight discipline` |
| Decomposition status | `Approved` |
| Planning baseline `origin/main` | `294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Current review baseline `origin/main` | `a145d7bc9146a0d8470693449961771824663676` |
| Previous Stage | `Stage 6 — Closed / PASS` |
| GitHub source of truth | `Current main must be re-checked before every executable task` |
| Documentation contract | `S07-DOC-001 — Accepted / Delivered via PR #187` |
| Backend implementation | `S07-BE-001…002 Accepted / Delivered; S07-BE-003 is the next executable task; S07-BE-004 remains PASS but blocked by dependency` |
| Backend checkpoint | `S07-BE-PHASE-2 — prepared, not executed` |
| Frontend implementation | `Not started` |
| Frontend checkpoint | `S07-FE-PHASE-2 — prepared, not executed` |
| Integration | `S07-INT-001 — prepared, not executed` |
| Closure | `STAGE_07_CLOSURE_REVIEW — prepared, not executed` |
| Next permitted executable gate | `S07-BE-003 after Project Owner Git preflight and ChatGPT current-main recheck` |

This index is the authoritative Stage 7 orchestration map. The planning package
has already been delivered to `origin/main`; the current review baseline above
records the main revision re-checked by ChatGPT before executable Stage 7 work.

The planning package originally marked implementation contracts as `Approved`.
For execution, that historical planning label is **not sufficient by itself**.

Before ChatGPT hands any task to Codex, the task must also pass current-main
Implementation Readiness revalidation:

```text
PASS
```

with its dependencies satisfied.

If current revalidation finds a material gap, the contract must be corrected
before execution even when its existing task-file metadata still says
`Approved`.

`Approved` / prepared contract content does **not** mean:

```text
implemented
accepted
delivered
merged
Phase 2 verified
integrated
closed
```

Stage 7 backend implementation is in progress. S07-BE-001 and S07-BE-002 are Accepted / Delivered, and S07-BE-003 is the next executable backend task.

---

## 2. Stage Goal

Roadmap goal:

> Allow Students to complete assigned homework and create protected attempt/submission records.

Roadmap acceptance criterion:

> A Student can complete up to three valid Homework attempts while the system
> preserves each attempt and enforces deadline, timezone, relationship,
> institution, and file-limit rules.

Stage 7 produces the Student's real Homework execution data while deliberately
deferring checking/scoring and final result calculation.

The Stage 7 vertical is:

```text
authorized assigned Student
→ Student-safe Homework read
→ create/resume one in-progress Attempt
→ save/replace typed answers
→ private file answer
→ explicit Submit OR authoritative deadline/Teacher-close finalization
→ immutable Attempt history
→ Stage 9 later checks/scores frozen work
```

---

## 3. Locked Stage Boundary

### Included

- Student Homework list/detail;
- Student-safe Question projection;
- frozen `assessment_students` assignment scope;
- exactly 3 normal Homework attempts;
- at most one `in_progress` Attempt per Student/Homework;
- idempotent Start/create-or-resume;
- all nine Student answer types;
- normalized answer persistence;
- private file upload/replacement/download;
- explicit final Submit;
- deadline request-path reconciliation;
- scheduled deadline reconciliation;
- Teacher-close auto-finalization;
- durable DB-backed Start/Submit idempotency;
- first official Homework Attempt locks the official pair/cohort meaning;
- Tenant/ownership/privacy enforcement;
- concurrency-safe finalization;
- concurrency-safe answer/file-write vs finalization exclusion;
- late high-risk Start/Submit deadline reconciliation without a committed incomplete idempotency claim;
- desktop/mobile Student execution UX;
- backend/frontend Phase 2 checkpoints;
- real-stack integration with independent DB/private-file oracle.

### Excluded

- Blitz workflow;
- automatic answer checking;
- Teacher manual marking/review;
- `awarded_points`;
- Attempt normalized score;
- official Homework score/attempt selection;
- result release;
- Homework–Blitz comparison;
- Topic final score;
- understanding category;
- Parent result UI;
- AI/fuzzy checking.

The primary later-stage boundary is:

```text
Stage 7 = capture/freeze Homework work
Stage 8 = Blitz
Stage 9 = checking/scoring/official Homework score
Stage 10 = final Topic result
```

---

## 4. Critical Architecture Decisions

1. Stage 7 finalization freezes saved work; it does not perform Stage 9 checking/scoring.
2. Homework execution finalization persists `status = submitted`.
3. Explicit Student Submit sets `submitted_at`; automatic finalization leaves it null.
4. Deadline auto-finalization uses `homework_deadline_auto_submit`.
5. Teacher close before deadline uses `task_closed_auto_finalize`.
6. At/equal/after deadline, deadline semantics win over Teacher-close reason/time.
7. Never-started Students receive no fabricated Attempt.
8. Unanswered Questions receive no fabricated `attempt_answers` row.
9. At most one `in_progress` Attempt exists per Student/Homework.
10. Start is create-or-resume and uses durable DB-backed idempotency.
11. Final Submit uses durable DB-backed idempotency.
12. Ordinary answer/file PUT does not use `Idempotency-Key`.
13. First official Homework Attempt locks `topic_result_pairs.locked_at` atomically.
14. Frozen `assessment_students`, not current Group membership, governs Student Homework assignment/history.
15. Deadline request reconciliation and Scheduler use the same authoritative finalization engine.
16. Public Student Start must not ship while Teacher close still rejects an in-progress Homework Attempt.
17. Submit/deadline/close races must produce one logical finalization.
18. Student APIs never expose Teacher answer-key/checking configuration.
19. File replacement preserves stable server File identity.
20. Student submission files are private; Stage 7 Teacher download remains denied until Stage 9.
21. Answer/file mutation vs Submit/deadline/Teacher-close is serialized: a mutation that commits first is included in the frozen Attempt; finalization that commits first blocks any later Student mutation.
22. A late high-risk Start/Submit may commit mandatory deadline reconciliation and still return the documented failure, but it must leave neither a new successful idempotency result nor a committed incomplete claim.
23. Existing combined Homework/Blitz documentation wording may be split, but Stage 7 alignment must not alter Blitz lifecycle/timeout/checking/scoring semantics.
24. The shared `assessment_attempts` structural rule of at most one `in_progress` Attempt per Student/Assessment applies to all Assessment types. This does not implement Stage 8 Blitz behavior; a future Blitz replacement/exception Attempt cannot coexist as `in_progress` with another Attempt for the same Student/Assessment.

### 4.1 Workflow Ownership and Context Boundary

Stage orchestration follows the project workflow:

```text
ChatGPT
= requirements, architecture, API/database/security/lifecycle decisions
= task decomposition and current-main Readiness Gate
= acceptance criteria and minimum verification scope
= task acceptance review
= Backend/Frontend Phase 2 review and verdict
= Integration Harness Preflight/review
= Stage Closure Review

Codex
= implement one currently approved/revalidated task contract
= inspect only that contract + applicable AGENTS.md + directly required code/tests
= run only task-level focused verification from the contract
= implement focused fixes only from a new/updated ChatGPT contract

Project Owner / CI
= routine Git/GitHub delivery by default
= full checkpoint suites/builds
= real-stack integration execution
= required manual smoke
```

`STAGE_07_TASK_INDEX.md` is a ChatGPT/Project Owner orchestration artifact.
Codex must **not** read this index, roadmap, product docs, architecture/database/API
docs, previous tasks, Stage history, or closure reviews to determine what to
implement. Codex receives the current self-contained implementation contract.

---

## 5. Approved Task Order and Status

| Order | Task ID | Area | Short outcome | Depends on | Planning-package contract status | Current readiness revalidation | Delivery/execution status | Contract file |
|---:|---|---|---|---|---|---|---|---|
| 0 | `S07-DOC-001` | Documentation | Align Stage 7 execution vs Stage 9 checking/scoring contracts | Stage 6 closed + Stage 7 decomposition approved | `Approved` | `PASS — corrected/revalidated and implemented` | `Accepted / Delivered — PR #187, merge 6529ae4b4a114828d0636baec597d10c03ef3164` | `tasks/S07-DOC-001-stage-07-student-homework-execution-contract-alignment.md` |
| 1 | `S07-BE-001` | Backend | Student answer/submission persistence + idempotency foundation | DOC-001 Accepted / Delivered | `Approved` | `PASS — implemented and accepted` | `Accepted / Delivered — PR #190, merge 86067f9a61864a4d313b7ec8b59ee1217218b612` | `tasks/backend/stage-07/S07-BE-001-student-answer-submission-persistence-foundation.md` |
| 2 | `S07-BE-002` | Backend | Homework finalization/deadline engine + Teacher close integration | BE-001 | `Approved` | `PASS — implemented and accepted` | `Accepted / Delivered — PR #192, merge a145d7bc9146a0d8470693449961771824663676` | `tasks/backend/stage-07/S07-BE-002-homework-attempt-finalization-deadline-engine.md` |
| 3 | `S07-BE-003` | Backend | Student Homework read API | BE-001 + BE-002 | `Approved` | `PASS — corrected/revalidated` | `Not started — next executable task` | `tasks/backend/stage-07/S07-BE-003-student-homework-read-api.md` |
| 4 | `S07-BE-004` | Backend | Idempotent Attempt start/resume + official pair lock | BE-001 + BE-002 + BE-003 | `Approved` | `PASS — corrected/revalidated` | `Not started — blocked by dependencies` | `tasks/backend/stage-07/S07-BE-004-idempotent-homework-attempt-start-resume.md` |
| 5 | `S07-BE-005` | Backend | Eight non-file typed answer save/replace | BE-004 | `Approved` | `Pending sequential current-main review` | `Not started` | `tasks/backend/stage-07/S07-BE-005-typed-student-answer-save-replace.md` |
| 6 | `S07-BE-006` | Backend | File-based answer upload/replace/protected Student download | BE-005 | `Approved` | `Pending sequential current-main review` | `Not started` | `tasks/backend/stage-07/S07-BE-006-file-based-student-answer-flow.md` |
| 7 | `S07-BE-007` | Backend | Idempotent final Homework Submit | BE-002 + BE-005 + BE-006 | `Approved` | `Pending sequential current-main review` | `Not started` | `tasks/backend/stage-07/S07-BE-007-idempotent-final-homework-submit.md` |
| 8 | `S07-BE-PHASE-2` | Backend review | Complete Stage 7 backend read-only block review + full backend regression | BE-001…007 | `Prepared` | `Pending review before checkpoint execution` | `Not executed` | `tasks/backend/stage-07/S07-BE-PHASE-2-backend-block-review.md` |
| 9 | `S07-FE-001` | Frontend | Student Homework read foundation | Backend Phase 2 PASS | `Approved` | `Pending sequential current-main review` | `Not started` | `tasks/frontend/stage-07/S07-FE-001-student-homework-read-foundation.md` |
| 10 | `S07-FE-002` | Frontend | Attempt Start/Resume shell | FE-001 | `Approved` | `Pending sequential current-main review` | `Not started` | `tasks/frontend/stage-07/S07-FE-002-attempt-start-resume-shell.md` |
| 11 | `S07-FE-003` | Frontend | Eight non-file answer editors | FE-002 | `Approved` | `Pending sequential current-main review` | `Not started` | `tasks/frontend/stage-07/S07-FE-003-eight-non-file-answer-editors.md` |
| 12 | `S07-FE-004` | Frontend | File answer UX | FE-002 + FE-003 | `Approved` | `Pending sequential current-main review` | `Not started` | `tasks/frontend/stage-07/S07-FE-004-file-answer-ux.md` |
| 13 | `S07-FE-005` | Frontend | Submit/finalization UX | FE-002…004 | `Approved` | `Pending sequential current-main review` | `Not started` | `tasks/frontend/stage-07/S07-FE-005-submit-finalization-ux.md` |
| 14 | `S07-FE-PHASE-2` | Frontend review | Complete Stage 7 frontend read-only block review + full frontend verification | FE-001…005 | `Prepared` | `Pending review before checkpoint execution` | `Not executed` | `tasks/frontend/stage-07/S07-FE-PHASE-2-frontend-block-review.md` |
| 15 | `S07-INT-001` | Integration | Real-stack Student Homework E2E/security/persistence/private-file verification | Both Phase 2 checkpoints PASS | `Approved` | `Pending current-main review before integration asset execution` | `Not started` | `tasks/integration/stage-07/S07-INT-001-real-stack-student-homework-e2e.md` |
| 16 | `STAGE_07_CLOSURE_REVIEW` | Closure | Final Stage acceptance/evidence/delivery review | Integration PASS + required fixes/delivery | `Prepared` | `Pending current-main review before closure` | `Not executed` | `tasks/STAGE_07_CLOSURE_REVIEW.md` |

The planning-package status records how the file entered the Stage 7 planning
package. The **Current readiness revalidation** column controls whether ChatGPT
may hand the task to Codex now.

Only:

```text
Current readiness revalidation = PASS
+
all dependencies Accepted / Delivered
```

permits task execution.

The task index itself is planning/bookkeeping and is not counted as an implementation task.

---

## 6. Dependency Graph

```text
Stage 6 CLOSED
        |
        v
S07-DOC-001
        |
        v
S07-BE-001
        |
        v
S07-BE-002
        |
        +--------------+
        |              |
        v              |
S07-BE-003             |
        |              |
        v              |
S07-BE-004             |
        |              |
        v              |
S07-BE-005             |
        |              |
        v              |
S07-BE-006             |
        |              |
        +-------> S07-BE-007
                       |
                       v
               S07-BE-PHASE-2 PASS
                       |
                       v
                  S07-FE-001
                       |
                       v
                  S07-FE-002
                    /      \
                   v        v
              S07-FE-003  (read shell base)
                   |
                   v
              S07-FE-004
                   |
                   v
              S07-FE-005
                   |
                   v
              S07-FE-PHASE-2 PASS
                   |
                   v
              S07-INT-001
                   |
          Harness Preflight PASS
                   |
          real-stack integration PASS
                   |
                   v
          STAGE_07_CLOSURE_REVIEW
```

Important backend dependency:

```text
S07-BE-002 -> S07-BE-004
```

is non-negotiable.

Do not expose public Student Attempt Start while the production Teacher Homework
close path still rejects an existing `in_progress` Attempt instead of
auto-finalizing it.

---

## 7. Stage Entry and Documentation Gate — Completed

Stage entry and mandatory documentation alignment are complete:

- [x] Stage 6 is `Closed / PASS`.
- [x] Stage 7 decomposition/planning package was delivered.
- [x] `S07-DOC-001` contract was corrected/revalidated.
- [x] `S07-DOC-001` implementation passed ChatGPT read-only acceptance review.
- [x] PR #187 was merged to `main`.
- [x] `S07-DOC-001 = Accepted / Delivered`.
- [x] `S07-BE-001…004` contracts were corrected/revalidated `PASS`.
- [x] Corrected `S07-BE-001…004` contracts were delivered through PR #188.
- [x] Current `origin/main` was re-checked at `a145d7bc9146a0d8470693449961771824663676`.
- [x] `S07-BE-001` implementation passed ChatGPT acceptance review.
- [x] PR #190 was merged to `main`.
- [x] `S07-BE-001 = Accepted / Delivered`.
- [x] `S07-BE-002` implementation passed ChatGPT acceptance review.
- [x] PR #192 was merged to `main`.
- [x] `S07-BE-002 = Accepted / Delivered`.

The next executable task is:

```text
S07-BE-003
```

Before Codex starts `S07-BE-003`, Project Owner must perform a fresh Git preflight and ChatGPT
must re-check the current `origin/main` implementation baseline and dependency
state.

Later tasks still require their dependencies to become `Accepted / Delivered`
before execution.

---

## 8. Documentation Gate

Status:

```text
PASS — S07-DOC-001 Accepted / Delivered
PR #187
merge = 6529ae4b4a114828d0636baec597d10c03ef3164
```

This gate is satisfied. Backend implementation is in progress: `S07-BE-001` and
`S07-BE-002` are Accepted / Delivered, and `S07-BE-003` is the next backend task.

`S07-DOC-001` aligned live `docs/01–09` so Stage 7 execution/finalization no longer
implies that Stage 7 immediately:

```text
checks answers
awards zero
moves manual answers to Teacher review
computes scores
```

Locked meaning:

```text
Stage 7:
freeze already-saved work
mark Attempt submitted/finalized
keep saved answers pending
do not fabricate missing answers

Stage 9:
perform automatic/manual checking
treat missing answers as zero
award points
advance review/checking/scoring state
choose official Homework score later
```

`docs/FINAL_AUDIT_REPORT.md` remains historical audit evidence and was not edited
by `S07-DOC-001`.

---

## 9. Backend Block Gate

Backend tasks execute one at a time in dependency order.

Each task requires:

- current-main re-check by ChatGPT;
- `Current readiness revalidation = PASS` by ChatGPT;
- dependency confirmation;
- compact existing task contract;
- focused tests;
- required static/format checks;
- `git diff --check`;
- focused scope/diff self-review.

Codex receives only the current task contract, applicable `AGENTS.md`, and directly required source/tests. Routine delivery is Project Owner-owned unless the task explicitly says otherwise.

Do not run the full backend suite after every small backend task.

After BE-001…007 are accepted/delivered:

```text
S07-BE-PHASE-2
```

must run as a ChatGPT-owned read-only review and include the full backend regression suite executed by Project Owner/CI. Codex is used only for approved focused fixes.

Frontend implementation remains blocked until:

```text
S07-BE-PHASE-2 = PASS
```

---

## 10. Frontend Block Gate

Frontend tasks execute after backend checkpoint PASS.

Required sequence:

```text
FE-001
-> FE-002
-> FE-003
-> FE-004
-> FE-005
-> Frontend Phase 2
```

Each task requires ChatGPT current-main readiness PASS and uses focused verification only. Codex implements the approved contract; routine delivery remains Project Owner-owned unless explicitly reassigned.

After FE-001…005 are accepted/delivered:

```text
S07-FE-PHASE-2
```

must run as a ChatGPT-owned read-only review, with Project Owner/CI executing:

- full frontend test suite;
- static analysis;
- full read-only format check;
- required Windows debug build;
- required Android debug build;
- stage-wide diff review.

Integration remains blocked until:

```text
Backend Phase 2 = PASS
Frontend Phase 2 = PASS
```

---

## 11. Integration Reliability Gate

`S07-INT-001` first implements/delivers integration assets only. Codex may implement only the approved integration assets/focused fixes; ChatGPT owns the harness preflight/review, and Project Owner/CI executes the real-stack runner and manual smoke.

Before the first full Stage 7 real-stack runner:

```text
ChatGPT Integration Harness Preflight = PASS
```

The preflight checks:

- stable IDs/Keys/scoped selectors;
- condition-based bounded waits;
- hit-testability for interactive controls;
- no arbitrary-sleep synchronization;
- deterministic Stage 7 fixtures;
- tenant-safe ownership;
- deterministic test-file/idempotency queues;
- runtime/private-volume guards;
- independent DB/private-file oracle;
- cleanup;
- exact lifecycle/API expectations.

Every material integration failure is classified before fixing:

```text
production defect
integration-harness defect
environment/runtime defect
```

No production behavior may be changed merely to satisfy an incorrect harness expectation.

---

## 12. Integration Scope Summary

Required final real-stack proof includes:

- Windows Student Homework execution through production Flutter/Laravel/PostgreSQL;
- all nine answer types;
- file upload/replacement/protected download;
- exactly three Attempts;
- fourth Attempt blocked;
- first official Attempt result-pair lock;
- Start idempotency;
- answer semantic no-op;
- Submit idempotency;
- request-path deadline reconciliation;
- Scheduler reconciliation;
- Teacher close auto-finalization;
- deadline-vs-close precedence;
- answer/file-write vs Submit/deadline/close race ordering;
- late Start/Submit deadline reconciliation leaves no committed incomplete idempotency claim;
- Tenant/ownership/privacy matrix;
- recursive correct-answer leakage check;
- independent DB/private-file oracle;
- backend restart persistence;
- Android Student manual smoke;
- manifest-safe cleanup.

Fresh Phase 2 PASS evidence is reused; do not rerun broad suites merely because
integration starts.

---

## 13. Closure Rule

Stage Closure Review is owned by ChatGPT. Project Owner/CI supplies the required delivery/checkpoint/integration/manual-smoke evidence; Codex is used only for approved focused fixes.

Stage 7 closes only after:

```text
S07-DOC-001 Accepted / Delivered
→ S07-BE-001…007 Accepted / Delivered
→ Backend Phase 2 PASS
→ S07-FE-001…005 Accepted / Delivered
→ Frontend Phase 2 PASS
→ S07-INT-001 assets Accepted / Delivered
→ Integration Harness Preflight PASS
→ real-stack Integration PASS
→ required Android smoke PASS
→ cleanup PASS
→ all required fixes delivered
→ Stage Closure Review
```

Closure verdict is exactly:

```text
STAGE CLOSED
```

or:

```text
NOT ACCEPTED
```

After `STAGE CLOSED`, the next permitted product gate is:

```text
Stage 8 planning/decomposition only
```

---

## 14. Planning Package Delivery — Completed

The original Stage 7 planning package was documentation/task-contract content
only and was delivered to `origin/main` through PR #184:

```text
merge: 19d90f23ffc02d7341d78433cc825d4403da89f4
```

It contained 18 Stage 7 planning files:

```text
tasks/S07-DOC-001-stage-07-student-homework-execution-contract-alignment.md
tasks/STAGE_07_TASK_INDEX.md
tasks/STAGE_07_CLOSURE_REVIEW.md
tasks/backend/stage-07/**
tasks/frontend/stage-07/**
tasks/integration/stage-07/**
```

The corrected/revalidated `S07-DOC-001` contract was then delivered through
PR #185:

```text
current review baseline:
a538e1fd02722316ea12a688b1d3f044b96f4129
```

Those planning/contract deliveries did not constitute Stage 7 production
implementation.

At this baseline the next permitted executable task is:

```text
S07-DOC-001
```

after normal Project Owner Git preflight/local-main synchronization.

Before every later executable task, ChatGPT must re-check the then-current
`origin/main`, dependency state, and that task's current implementation
readiness rather than relying on the original planning-package approval.
