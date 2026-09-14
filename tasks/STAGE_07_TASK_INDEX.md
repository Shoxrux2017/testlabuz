# Stage 7 Task Index — Student Homework and Submission Flow

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `Stage 7 — Student Homework and Submission Flow` |
| Stage status | `Closed / PASS` |
| Verification model | `Workflow v3 — Lean Verification + Integration Harness Preflight discipline` |
| Decomposition status | `Approved / Delivered` |
| Planning baseline `origin/main` | `294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Final accepted product main before closure bookkeeping | `3d71a58a375ac4473594c3b7fe79a9ca6de7d099` |
| Closure review date | `2026-09-14` |
| Backend Phase 2 audited revision | `4780c56d36816ac0f7b1ab381c28c7387a2804c6` |
| Previous Stage | `Stage 6 — Closed / PASS` |
| Documentation contract | `S07-DOC-001 — Accepted / Delivered via PR #187` |
| Final documentation synchronization review | `PASS — no additional docs/01–09 correction required by closure` |
| Backend implementation | `Complete — S07-BE-001…007 Accepted / Delivered` |
| Backend Phase 2 | `PASS` |
| Backend checkpoint findings | `P1=0, P2=0, P3=0` |
| Frontend implementation | `Complete — S07-FE-001…005 Accepted / Delivered` |
| Frontend Phase 2 | `PASS` |
| Frontend checkpoint findings | `P1=0, P2=0, P3=0` |
| Integration | `S07-INT-001 — Accepted / Delivered / PASS` |
| Integration assets | `PR #225 / merge 30e29b0382a05067af2faef4fb0e509bef38aa4f` |
| Focused integration findings/corrections | `PR #226 / merge 3d71a58a375ac4473594c3b7fe79a9ca6de7d099` |
| Windows real-stack | `PASS` |
| Android manual smoke | `PASS` |
| DB/private-file oracle | `PASS` |
| Cleanup | `PASS` |
| Closure | `STAGE CLOSED` |
| Closure findings | `P1=0, P2=0, P3=0` |
| Next permitted gate | `Stage 8 planning/decomposition only` |

This index records the completed Stage 7 orchestration map. ChatGPT's Closure
Read-Only Review is `PASS` on accepted product `origin/main`
`3d71a58a375ac4473594c3b7fe79a9ca6de7d099`; local `main` matched that SHA,
ahead/behind was `0/0`, and the working tree was clean.

All 16 pre-closure Stage items reached their appropriate final states. The
planning-package labels below are historical; completed delivery/checkpoint
states govern this closure record. ChatGPT determined that both Phase 2
checkpoints and accepted integration evidence remain valid. Detailed closure
evidence is recorded in `tasks/STAGE_07_CLOSURE_REVIEW.md`.

Stage 8 — Blitz Task Workflow may proceed to planning/decomposition only.
Stage 8 implementation is not authorized by this closure.

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

| Order | Task ID | Area | Short outcome | Depends on | Historical planning-package contract status | Completed readiness/review status | Delivery/execution status | Contract file |
|---:|---|---|---|---|---|---|---|---|
| 0 | `S07-DOC-001` | Documentation | Align Stage 7 execution vs Stage 9 checking/scoring contracts | Stage 6 closed + Stage 7 decomposition approved | `Approved` | `PASS — corrected/revalidated and implemented` | `Accepted / Delivered — PR #187, merge 6529ae4b4a114828d0636baec597d10c03ef3164` | `tasks/S07-DOC-001-stage-07-student-homework-execution-contract-alignment.md` |
| 1 | `S07-BE-001` | Backend | Student answer/submission persistence + idempotency foundation | DOC-001 Accepted / Delivered | `Approved` | `PASS — implemented and accepted` | `Accepted / Delivered — PR #190, merge 86067f9a61864a4d313b7ec8b59ee1217218b612` | `tasks/backend/stage-07/S07-BE-001-student-answer-submission-persistence-foundation.md` |
| 2 | `S07-BE-002` | Backend | Homework finalization/deadline engine + Teacher close integration | BE-001 | `Approved` | `PASS — implemented and accepted` | `Accepted / Delivered — PR #192, merge a145d7bc9146a0d8470693449961771824663676` | `tasks/backend/stage-07/S07-BE-002-homework-attempt-finalization-deadline-engine.md` |
| 3 | `S07-BE-003` | Backend | Student Homework read API | BE-001 + BE-002 | `Approved` | `PASS — implemented and accepted` | `Accepted / Delivered — PR #194, merge 1a7e86d3d08902feab3f004b21754aa7e2f1f98a` | `tasks/backend/stage-07/S07-BE-003-student-homework-read-api.md` |
| 4 | `S07-BE-004` | Backend | Idempotent Attempt start/resume + official pair lock | BE-001 + BE-002 + BE-003 | `Approved` | `PASS — implemented and accepted` | `Accepted / Delivered — PR #196, merge 275a1b2087a5d3e5a15c0ef1d3e50bba923236b2` | `tasks/backend/stage-07/S07-BE-004-idempotent-homework-attempt-start-resume.md` |
| 5 | `S07-BE-005` | Backend | Eight non-file typed answer save/replace | BE-004 | `Approved` | `PASS — implemented and accepted` | `Accepted / Delivered — PR #201, merge c03a600a92257a8a64730d603658381fb5ffb854` | `tasks/backend/stage-07/S07-BE-005-typed-student-answer-save-replace.md` |
| 6 | `S07-BE-006` | Backend | File-based answer upload/replace/protected Student download | BE-005 | `Approved` | `PASS — implemented and accepted` | `Accepted / Delivered — PR #204, merge c9a347986493ba8ee813984d4e6bc504edd1e5e9` | `tasks/backend/stage-07/S07-BE-006-file-based-student-answer-flow.md` |
| 7 | `S07-BE-007` | Backend | Idempotent final Homework Submit | BE-002 + BE-005 + BE-006 | `Approved` | `PASS — implemented and accepted` | `Accepted / Delivered — PR #207, merge 22c03f4e9aec8a421bd0edbe02756e557f943d60` | `tasks/backend/stage-07/S07-BE-007-idempotent-final-homework-submit.md` |
| 8 | `S07-BE-PHASE-2` | Backend review | Complete Stage 7 backend read-only block review + full backend regression | BE-001…007 | `Prepared` | `PASS — checkpoint executed at audited revision` | `PASS — audited main 4780c56d36816ac0f7b1ab381c28c7387a2804c6; P1 = 0, P2 = 0, P3 = 0` | `tasks/backend/stage-07/S07-BE-PHASE-2-backend-block-review.md` |
| 9 | `S07-FE-001` | Frontend | Student Homework read foundation | Backend Phase 2 PASS | `Approved` | `PASS — implemented and accepted` | `Accepted / Delivered — PR #212, implementation f3f9c6ce9696da60d8113a06e98cef8b447e0485, merge 252e67b1c43aa21885eb83379d5c0c618d092ca9` | `tasks/frontend/stage-07/S07-FE-001-student-homework-read-foundation.md` |
| 10 | `S07-FE-002` | Frontend | Attempt Start/Resume shell | FE-001 | `Approved` | `PASS — implemented and accepted` | `Accepted / Delivered — PR #215, implementation 3985f94b7eca8a7aa02e09213074471ad5374945, merge ad2bc12f328cd76797b13655eee030528c3c764e` | `tasks/frontend/stage-07/S07-FE-002-attempt-start-resume-shell.md` |
| 11 | `S07-FE-003` | Frontend | Eight non-file answer editors | FE-002 | `Approved` | `PASS — implemented and accepted` | `Accepted / Delivered — PR #218, final head ba7f266161ea5ea77dd4bb982c1b521b16ddef7d, merge 55528f106288527c2443142022ba5df567d019de` | `tasks/frontend/stage-07/S07-FE-003-eight-non-file-answer-editors.md` |
| 12 | `S07-FE-004` | Frontend | File answer UX | FE-002 + FE-003 | `Approved` | `PASS — implemented and accepted` | `Accepted / Delivered — PR #220, final head ba9d8401250a7d9318e87332be054b681ac78b8e, merge 291ee97693cf4ba2242ad30cd39371800760e740` | `tasks/frontend/stage-07/S07-FE-004-file-answer-ux.md` |
| 13 | `S07-FE-005` | Frontend | Submit/finalization UX | FE-002…004 | `Approved` | `PASS — implemented and accepted` | `Accepted / Delivered — PR #222, implementation 947634efd68089b737f6f099fc207081043dbf61, merge 5fd8e0f21916572c47ad7b901fdc607d75e6b1e8` | `tasks/frontend/stage-07/S07-FE-005-submit-finalization-ux.md` |
| 14 | `S07-FE-PHASE-2` | Frontend review | Complete Stage 7 frontend read-only block review + full frontend verification | FE-001…005 | `Prepared` | `PASS — checkpoint executed; final evidence refreshed after Resume correction` | `PASS — 2420 passed, 0 failed; analyze/format/Windows/Android checks PASS; P1=0, P2=0, P3=0` | `tasks/frontend/stage-07/S07-FE-PHASE-2-frontend-block-review.md` |
| 15 | `S07-INT-001` | Integration | Real-stack Student Homework E2E/security/persistence/private-file verification | Both Phase 2 checkpoints PASS | `Approved` | `PASS — assets, focused corrections, and real-stack verification completed` | `Accepted / Delivered / PASS — assets PR #225, merge 30e29b0382a05067af2faef4fb0e509bef38aa4f; focused corrections PR #226, merge 3d71a58a375ac4473594c3b7fe79a9ca6de7d099` | `tasks/integration/stage-07/S07-INT-001-real-stack-student-homework-e2e.md` |
| 16 | `STAGE_07_CLOSURE_REVIEW` | Closure | Final Stage acceptance/evidence/delivery review | Integration PASS + required fixes/delivery | `Prepared` | `PASS — ChatGPT Closure Read-Only Review completed 2026-09-14` | `Completed / PASS — STAGE CLOSED; P1=0, P2=0, P3=0` | `tasks/STAGE_07_CLOSURE_REVIEW.md` |

The 16 pre-closure items (orders 0–15) are complete. The closure row records the
subsequent ChatGPT verdict. Historical planning-package labels do not describe
unfinished work. The task index itself is bookkeeping and is not counted as an
implementation task. PR #226 corrections are focused Stage 7 integration
findings/corrections; no additional task IDs are introduced.

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
- [x] Current `origin/main` was re-checked at `275a1b2087a5d3e5a15c0ef1d3e50bba923236b2`.
- [x] `S07-BE-001` implementation passed ChatGPT acceptance review.
- [x] PR #190 was merged to `main`.
- [x] `S07-BE-001 = Accepted / Delivered`.
- [x] `S07-BE-002` implementation passed ChatGPT acceptance review.
- [x] PR #192 was merged to `main`.
- [x] `S07-BE-002 = Accepted / Delivered`.
- [x] `S07-BE-003` implementation passed ChatGPT acceptance review.
- [x] PR #194 was merged to `main`.
- [x] `S07-BE-003 = Accepted / Delivered`.
- [x] `S07-BE-004` implementation passed ChatGPT acceptance review.
- [x] PR #196 was merged to `main`.
- [x] `S07-BE-004 = Accepted / Delivered`.
- [x] `S07-BE-005` contract passed ChatGPT current-main Implementation Readiness review.
- [x] `S07-BE-005` implementation passed ChatGPT acceptance review.
- [x] PR #201 was merged to `main`.
- [x] `S07-BE-005 = Accepted / Delivered`.
- [x] Current `origin/main` was re-checked at `c03a600a92257a8a64730d603658381fb5ffb854`.
- [x] `S07-BE-006` contract passed ChatGPT current-main Implementation Readiness review.
- [x] `S07-BE-006` implementation passed ChatGPT acceptance review.
- [x] PR #204 was merged to `main`.
- [x] `S07-BE-006 = Accepted / Delivered`.
- [x] Current `origin/main` was re-checked at `c9a347986493ba8ee813984d4e6bc504edd1e5e9`.
- [x] `S07-BE-007` contract passed ChatGPT current-main Implementation Readiness review.
- [x] `S07-BE-007` implementation passed ChatGPT acceptance review.
- [x] PR #207 was merged to `main`.
- [x] `S07-BE-007 = Accepted / Delivered`.
- [x] Current `origin/main` was re-checked at `22c03f4e9aec8a421bd0edbe02756e557f943d60`.
- [x] `S07-BE-PHASE-2 = PASS` against audited backend main `4780c56d36816ac0f7b1ab381c28c7387a2804c6`.
- [x] Backend checkpoint findings: `P1 = 0`, `P2 = 0`, `P3 = 0`.
- [x] `S07-FE-001` implementation passed ChatGPT acceptance review: `PASS`; findings `P1 = 0`, `P2 = 0`, `P3 = 0`.
- [x] `S07-FE-001 = Accepted / Delivered` via PR #212, implementation `f3f9c6ce9696da60d8113a06e98cef8b447e0485`, merge `252e67b1c43aa21885eb83379d5c0c618d092ca9`.
- [x] `S07-FE-002` implementation passed ChatGPT acceptance review: `PASS`; findings `P1 = 0`, `P2 = 0`, `P3 = 0`.
- [x] `S07-FE-002 = Accepted / Delivered` via PR #215, implementation `3985f94b7eca8a7aa02e09213074471ad5374945`, merge `ad2bc12f328cd76797b13655eee030528c3c764e`.
- [x] `S07-FE-003…005 = Accepted / Delivered` through PR #218, #220, and #222.
- [x] `S07-FE-PHASE-2 = PASS`; final refreshed evidence after the Resume correction remains valid at closure.
- [x] `S07-INT-001 = Accepted / Delivered / PASS` through integration assets PR #225 and focused corrections PR #226.
- [x] Integration Harness Preflight, Windows real-stack, API/security, DB/private-file oracle, restart persistence, Android manual smoke, and guarded cleanup are `PASS`.
- [x] ChatGPT Closure Read-Only Review is `PASS`; findings `P1=0, P2=0, P3=0`.
- [x] Stage 7 is `Closed / PASS`; closure verdict is `STAGE CLOSED`.

The SHA re-checks above record historical delivery checkpoints. The final
accepted product main before closure bookkeeping is
`3d71a58a375ac4473594c3b7fe79a9ca6de7d099`.

The next permitted gate is Stage 8 planning/decomposition only.

---

## 8. Documentation Gate — Completed

`S07-DOC-001 = Accepted / Delivered`: PR #187, merge
`6529ae4b4a114828d0636baec597d10c03ef3164`.

Final documentation synchronization review: `PASS`. No additional `docs/01–09`
correction is required by closure.

The aligned boundary remains: Stage 7 freezes already-saved work, marks the
Attempt submitted/finalized, keeps saved answers pending, and does not fabricate
missing answers. Stage 9 owns checking, points, later review/scoring state, and
official Homework score selection.

---

## 9. Backend Block Gate — Completed

`S07-BE-001…007 = Accepted / Delivered`.

| Backend checkpoint | Accepted result |
|---|---|
| `S07-BE-PHASE-2` | `PASS` |
| Audited revision | `4780c56d36816ac0f7b1ab381c28c7387a2804c6` |
| Findings | `P1=0, P2=0, P3=0` |
| Full backend regression | `PASS` |
| Required backend quality/static/format verification | `PASS` |

The checkpoint covered persistence, API contracts, lifecycle/deadlines,
Start/Submit idempotency, authorization/Tenant isolation, private files, and
concurrency/cross-task interaction. ChatGPT determined that Backend Phase 2
evidence remains valid at closure. No backend test/assertion count is invented.

---

## 10. Frontend Block Gate — Completed

`S07-FE-001…005 = Accepted / Delivered` and `S07-FE-PHASE-2 = PASS`.

The final refreshed checkpoint followed production Back -> Resume authoritative
state restoration in `b1343a70e0282629dc5280726d6faa4d4fe10f9d`:

- Full frontend suite: `2420 passed, 0 failed`.
- `flutter analyze --no-pub`: `PASS / No issues found`.
- Dart format read-only check: `672 files checked, 0 changed`.
- Windows debug build: `PASS`.
- Android debug APK build: `PASS`.
- Stage-wide `git diff --check`: `PASS`.
- Findings: `P1=0, P2=0, P3=0`.

Later accepted changes were integration-harness-only or the final narrow copy
correction in `c392e94988d796575f1d39b0b44e1615584d0d4b`. ChatGPT determined that
Frontend Phase 2 evidence remains valid.

---

## 11. Integration Reliability and Delivery Gate — Completed

`S07-INT-001 = Accepted / Delivered / PASS`.

| Delivery | Evidence |
|---|---|
| Integration assets | PR #225; head `48d93471787a9ce570a1e489032e1a8073d0e1d2`; merge `30e29b0382a05067af2faef4fb0e509bef38aa4f` |
| Focused Stage 7 integration findings/corrections | PR #226; final head `c392e94988d796575f1d39b0b44e1615584d0d4b`; merge `3d71a58a375ac4473594c3b7fe79a9ca6de7d099` |
| Integration Harness Preflight | `PASS` |
| Automated full-run audited SHA | `8e6fc73b327baf921e829a2dcf5c4c829ea3a694` |
| Final automated evidence | `PASS` |

PR #226 delivered the accepted focused sequence: Topic-card E2E locator
correction, UUID v7 integration-harness support, dropdown integration-harness
correction, production Back -> Resume authoritative state restoration, awaited
logout teardown correction, and singular/plural unanswered-question copy
correction. These corrections do not introduce new task IDs.

The final `c392e94988d796575f1d39b0b44e1615584d0d4b` change was copy-only plus
focused regression coverage. ChatGPT determined that it does not invalidate
Windows real-stack, Android manual smoke, API/security, persistence, Backend
Phase 2, or Frontend Phase 2 evidence. No GitHub workflow run for that commit was
used as closure evidence; no CI run is claimed for it.

---

## 12. Completed Integration Evidence

| Evidence | Accepted result |
|---|---|
| Windows real-stack Student Homework flow | `PASS — production UI process exit code 0` |
| Runtime guard / runtime guard matrix / test-file verifier | `PASS` |
| Stage 7 pure oracle | `PASS — 59 checks` |
| Seeder verification | `17 passed, 1544 assertions` |
| Baseline DB oracle / DB/private-file oracle | `PASS` |
| API security pure verifier | `PASS — 52 checks` |
| Authentication/role/assignment/Tenant/privacy matrix | `PASS` |
| Protected Student submission download matrix | `PASS` |
| Start idempotency / nested answer scope / strict transport validation | `PASS` |
| File authority/replacement/no-op | `PASS` |
| Submit operation-scope independence / replay / terminal rejection | `PASS` |
| Three-attempt exhaustion | `PASS` |
| Deadline Read reconciliation | `PASS` |
| Due Teacher Close / deadline precedence | `PASS` |
| Future Teacher Close finalization | `PASS` |
| Global Scheduler candidate guard/reconciliation/idempotency | `PASS` |
| Backend restart persistence / post-restart protected replacement download | `PASS` |
| Android manual smoke | `PASS — Project Owner, 2026-09-14, Android emulator Android 17 / API 37` |
| Manual DB oracle and cleanup | `Stage7ManualSmokeOracleAndCleanup = PASS` |
| Guarded cleanup | `PASS` |

Android smoke used `E2E S07 Android Smoke Homework`: real Student login, assigned
Homework, Start Attempt, Single Choice and Short Written saves, confirmation of
2 of 3 saved and one unanswered, explicit Submit, terminal `Submitted by you`,
and Back to Homework with Allowed attempts = 3, Used = 1, Remaining = 2.

Cleanup removed manifest-owned DB fixtures, private blobs, generated local Stage
7 files, and the temporary Android reverse mapping; unrelated sentinel state was
preserved. The final `adb reverse` list was empty. The external dedicated
Docker/private named volume may remain provisioned; no deletion is claimed.

The full accepted evidence and roadmap/Definition of Done mapping are in
`tasks/STAGE_07_CLOSURE_REVIEW.md`. ChatGPT retained valid Phase 2/integration
results; no product verification is rerun for closure bookkeeping.

---

## 13. Closure — Completed

ChatGPT Closure Read-Only Review: `PASS`, dated `2026-09-14`.

```text
Stage 7 = Closed / PASS
Closure verdict = STAGE CLOSED
P1 = 0
P2 = 0
P3 = 0
Roadmap acceptance = PASS
Stage Definition of Done = PASS
Stage 8 compatibility boundary = PASS
Stage 9/10 scope boundary = PASS
```

No findings. The Android wording issue was resolved by
`c392e94988d796575f1d39b0b44e1615584d0d4b` and is not open. No blocking regression
is known.

Final accepted product main before closure bookkeeping:
`3d71a58a375ac4473594c3b7fe79a9ca6de7d099`.

Closure bookkeeping is delivered through the closure-only `docs/stage7-closure`
PR. Final post-merge `main` synchronization is a Project Owner/ChatGPT gate after
that PR merges; no future closure merge SHA is asserted here.

Next permitted gate: Stage 8 — Blitz Task Workflow planning/decomposition only.
Stage 8 implementation is not authorized.

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

At that historical planning baseline, `S07-DOC-001` was the next executable task
subject to normal current-main readiness and dependency checks. The completed
Stage 7 delivery and closure states above supersede that historical handoff.
