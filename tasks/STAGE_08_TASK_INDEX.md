# Stage 8 Task Index — Blitz Task Workflow

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `Stage 8 — Blitz Task Workflow` |
| Stage status | `Approved — implementation proceeds only through current per-task readiness` |
| Verification model | `Workflow v3 — Lean Verification + Backend/Frontend Phase 2 + Real-Stack Integration` |
| Decomposition status | `Approved` |
| Historical planning baseline `origin/main` | `962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Planning date | `2026-09-14` |
| Previous Stage | `Stage 7 — Closed / PASS` |
| Previous Stage closure merge | `962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Current source of truth | `GitHub main — ChatGPT must re-check it before any readiness/handoff decision` |
| Stage 8 implementation | `In progress — S08-DOC-001, S08-BE-001…010 and S08-BE-PHASE-2-FIX-001…003 Accepted / Delivered; S08-BE-PHASE-2 PASS (run #2, 1c56cde); S08-FE-001 Accepted / Delivered (PR #262, 15508f3); S08-FE-002 Accepted / Delivered (PR #264, b5b24b1); S08-FE-003 Accepted / Delivered (PR #266, a37dd02); S08-FE-004 Accepted / Delivered (PR #268, 466119a); S08-FE-005 Accepted / Delivered (PR #270, 05d06ec); S08-FE-006 Accepted / Delivered (PR #272, 48776a1); S08-FE-PHASE-2-FIX-001 Accepted / Delivered (PR #275, 2a59651); S08-FE-PHASE-2 PASS (run #2, 2a59651); S08-INT-001 Approved / In progress (assets delivered PR #278, 3e54c90; preflight #1 NOT ACCEPTED; S08-INT-001-FIX-001 Approved / Not started); closure Prepared / Not started` |
| Detailed task contracts | `Final planning package reviewed and approved; execution remains per-task gated` |
| Backend Phase 2 | `PASS — run #2 on 1c56cde (run #1 on 232ebcd NOT ACCEPTED; fixes FIX-001…003 delivered; see §17)` |
| Frontend Phase 2 | `PASS — run #2 on 2a59651 (run #1 on 03c6581 NOT ACCEPTED; fix FIX-001 delivered; see §18)` |
| Integration | `S08-INT-001 Approved / In progress — assets delivered (PR #278, 3e54c90); Harness Preflight #1 NOT ACCEPTED; S08-INT-001-FIX-001 Approved / Not started (see §20)` |
| Closure | `Not started` |
| Next permitted gate | `S08-INT-001-FIX-001 implementation, then Integration Harness Preflight #2` |

This index is the ChatGPT / Project Owner orchestration map for Stage 8.

The SHA above is the **historical planning baseline**, not permission to rely on
that revision for implementation. GitHub `main` is the current source of truth
and must be re-checked by ChatGPT before any task receives current readiness.

Stage 8 planning/decomposition is approved. `S08-DOC-001` documentation alignment,
`S08-BE-001` persistence/domain foundation, `S08-BE-002` Teacher Blitz authoring,
`S08-BE-003` Blitz Question authoring integration, `S08-BE-004` Official Blitz
designation + activation, `S08-BE-005` Student Read + Start/Resume,
`S08-BE-006` Student Answer/File Mutation, `S08-BE-007` Finalization Engine,
`S08-BE-008` Student Submit, `S08-BE-009` Technical Attempt Exception and
`S08-BE-010` Teacher Monitoring are `Accepted / Delivered`.
`S08-BE-PHASE-2` run #1 (2026-09-23, audited `232ebcd`) was `NOT ACCEPTED`; the
focused fixes `S08-BE-PHASE-2-FIX-001…003` are `Accepted / Delivered`, and run #2
(2026-09-24, audited `1c56cde`) is `PASS` (see §17). `S08-FE-001` (PR #262) and
`S08-FE-002` (PR #264), `S08-FE-003` (PR #266), `S08-FE-004` (PR #268), `S08-FE-005`
(PR #270) and `S08-FE-006` (PR #272) are `Accepted / Delivered`. `S08-FE-PHASE-2` run #1
(2026-09-26, audited `03c6581`) was `NOT ACCEPTED`; the focused fix `S08-FE-PHASE-2-FIX-001`
(PR #275) is `Accepted / Delivered`, and run #2 (2026-09-27, audited `2a59651`) is `PASS` (see
§18). `S08-INT-001` readiness is `Approved` (revalidated 2026-09-27 on `d96b569`, see §19);
its assets are delivered (PR #278), Harness Preflight #1 is `NOT ACCEPTED` and the focused fix
`S08-INT-001-FIX-001` is `Approved / Not started` (see §20). The closure review remains
`Prepared / Not started`.

All detailed Stage 8 task/checkpoint/integration/closure contracts form the final
reviewed and approved planning package. Their existence or historical planning
approval does **not** authorize all tasks. Only the exact task whose
`Current readiness / review status` is `Approved` may be handed to Codex.

Before Codex receives a task, ChatGPT must re-check current `origin/main`,
confirm delivered dependencies, inspect the directly relevant implementation/tests,
revalidate the exact task contract, and record current Implementation Readiness
for that exact next task.

This index must not be used by Codex as a substitute for the current
self-contained task implementation contract.

---

## 2. Stage Goal

Roadmap goal:

> Implement the central in-class Blitz verification workflow used to compare controlled classroom performance with Homework performance.

The Stage 8 vertical is:

```text
Teacher authors Blitz
→ optional scheduling
→ official Blitz designation when result-bearing
→ Teacher activation
→ server-authoritative timer
→ Student Start/Resume
→ Student answer/file execution
→ explicit Submit OR authoritative timeout/Teacher-close finalization
→ immutable Blitz Attempt history
→ optional Student-specific technical replacement Attempt
→ Teacher live monitoring
→ Stage 9 later performs checking/scoring
```

Stage 8 must support both institution-configured timer modes:

```text
synchronized
individual
```

and must preserve one normal Blitz Attempt plus at most one authorized Student-specific replacement Attempt.

---

## 3. Locked Stage Boundary

### Included

- Blitz persistence/domain foundation;
- Teacher Blitz create/list/detail/update;
- whole-group or selected-Student assignment;
- instructions;
- whole-Blitz duration;
- scheduling;
- archive;
- all nine approved Question types;
- Blitz-specific Question editing integrity;
- official Blitz designation;
- completion of the existing Topic result pair;
- preservation/establishment of the official Topic cohort;
- Blitz lifecycle:
  - `draft`
  - `scheduled`
  - `active`
  - `closed`
  - `archived`;
- Teacher activation;
- institution timer-start-mode snapshot at activation;
- synchronized timer mode;
- individual timer mode;
- server-authoritative timing;
- Student active Blitz list/detail;
- Student Start/Resume;
- exactly one normal Blitz Attempt;
- all nine Student answer types;
- Student private file answer flow;
- authoritative write eligibility;
- explicit Student Submit;
- timeout reconciliation;
- Scheduler timeout reconciliation;
- Teacher-close finalization;
- terminal immutability;
- Student-specific technical attempt exception;
- exactly one replacement Attempt;
- original Attempt history preservation;
- original Attempt exclusion from later official scoring eligibility;
- Teacher live monitoring;
- Teacher mobile quick classroom actions;
- Student desktop/mobile execution;
- durable idempotency for required high-risk mutations;
- Tenant/authorization/privacy enforcement;
- concurrency-safe activation/start/finalization/exception behavior;
- backend Phase 2;
- frontend Phase 2;
- real-stack Blitz integration/E2E;
- Stage closure review.

### Excluded

Stage 8 must not own the broader Stage 9 checking/scoring pipeline.

Excluded unless `S08-DOC-001` explicitly proves that a minimal execution-state transition is required by the locked contract:

- automatic answer checking engine;
- Teacher manual marking implementation;
- awarding Question points;
- complete Attempt scoring;
- normalized Blitz score calculation;
- official Blitz score selection;
- official Homework score selection;
- Homework–Blitz score comparison;
- Topic final score;
- understanding category;
- result release;
- Parent result UI;
- AI/fuzzy checking.

The primary later-stage boundary is:

```text
Stage 7 = capture/freeze Homework work
Stage 8 = capture/freeze Blitz work
Stage 9 = checking/scoring + official task scores
Stage 10 = final Topic result
```

---

## 4. Existing Foundation Reused by Stage 8

Stage 8 must extend the delivered common Assessment infrastructure rather than create a parallel Blitz execution subsystem.

Reuse the existing:

```text
assessments
assessment_students
questions
assessment_attempts
attempt_answers
idempotency_records
private Student submission-file infrastructure
```

Existing Stage 6/7 persistence already contains forward-compatible Blitz fields and states such as:

```text
assessment.type = blitz
assessment_attempts.deadline_at
assessment_attempts.status = timed_out_finalized
assessment_attempts.finalization_reason = timeout_auto_submit
assessment_attempts.official_score_eligible
topic_result_pairs.blitz_assessment_id nullable
```

Stage 8 must **not** create duplicated mutable infrastructure such as:

```text
blitz_attempts
blitz_answers
blitz_question_options
```

unless a later ChatGPT architecture review explicitly changes the approved design.

Homework and Blitz share lower-level Assessment/Question/Attempt/Answer infrastructure but remain separate lifecycle/domain objects.

---

## 5. Critical Architecture Decisions

1. Stage 8 owns Blitz execution/finalization; Stage 9 owns the broader checking/scoring pipeline.
2. Blitz uses the existing shared `assessments` base plus a Blitz-specific detail/lifecycle model.
3. Blitz Questions reuse the existing nine-type Question persistence, but current Homework-specific mutation access must be extended safely rather than bypassed.
4. Homework-specific lifecycle Actions/guards must not simply accept `type = blitz`.
5. Only a whole-group Blitz may become the official result-bearing Blitz.
6. Selected-Student Blitz tasks remain practice/supplementary.
7. Stage 8 fills `topic_result_pairs.blitz_assessment_id` in the existing result-pair row; it does not create a second pair.
8. Existing official Homework meaning must not be replaced by Stage 8.
9. If the official Topic cohort already exists, the official Blitz must use exactly that persisted cohort.
10. Later current Group membership must not silently redefine an established official cohort.
11. If the Blitz is the first activated official assessment and no official cohort exists yet, its persisted whole-group recipient snapshot establishes the common cohort.
12. A pair lock protecting established official meaning does not forbid the approved one-time completion of the previously-null Blitz side when all same-Topic/cohort rules pass.
13. Institution `blitz_timer_start_mode` is snapshotted into the Blitz at activation.
14. Changing Institution settings later must not reinterpret an already-activated Blitz.
15. Missing timer-start configuration blocks only the dependent activation operation.
16. Teacher configures one whole-Blitz duration; Stage 8 has no per-question timer.
17. Server time is authoritative for activation, Student Start, remaining time, deadline, Submit eligibility, timeout, and close.
18. Device clock/timezone must never extend legal execution time.
19. Synchronized mode uses one common end time derived from Teacher activation.
20. Individual mode creates a Student-specific persisted `deadline_at` from server-authoritative Student Start.
21. Student normally receives exactly one Blitz Attempt.
22. An authorized technical exception may allow exactly one replacement Attempt for one Student.
23. The exception requires a reason and preserves the original Attempt as history.
24. The original affected Attempt becomes ineligible for later official scoring.
25. The replacement Attempt is the only potential official candidate after later Stage 9 checking/scoring.
26. The exception does not raise the class-wide normal attempt limit.
27. Never-started Students receive no fabricated Attempt at timeout or Teacher Close.
28. Unanswered Questions receive no fabricated `attempt_answers` row.
29. Student answer/file writes remain pending execution data; Stage 8 must not award points.
30. Timeout, explicit Submit, Teacher Close, Scheduler, and answer/file writes must serialize to one authoritative result.
31. A mutation that commits before finalization is included in the frozen Attempt.
32. A finalization that commits first blocks later answer/file mutation.
33. Repeated reconciliation must not rewrite an already-committed terminal reason/timestamp.
34. High-risk mutations use durable idempotency according to the approved API contract.
35. All direct-ID operations must preserve cross-Tenant and existence privacy.
36. Teacher monitoring must never permit Teacher answer mutation on behalf of a Student.
37. Student submission files remain private and authorized through the existing protected file model.
38. Frontend countdown is a projection of backend timestamps, not an authority for legal write acceptance.
39. Backend and frontend Phase 2 checkpoints are required before Stage integration.
40. Stage 8 cannot close until the real stack proves both timer modes, timeout/close behavior, technical exception, and Tenant/security boundaries.

---

## 6. Workflow Ownership and Context Boundary

Stage orchestration follows the project workflow:

```text
ChatGPT
= current-main recovery
= requirements/business behavior
= architecture
= API/database/security/lifecycle decisions
= task decomposition
= Implementation Readiness Gate
= implementation contract
= acceptance criteria
= minimum verification scope
= task acceptance review
= Backend/Frontend Phase 2 review
= Integration review
= Stage Closure Review

Codex
= implement one currently approved/revalidated task contract
= inspect only that contract + applicable AGENTS.md + directly required code/tests
= run focused task-level verification
= return BLOCKED instead of inventing product/architecture decisions

Project Owner / CI
= routine Git/GitHub delivery
= checkpoint suite/build execution where required
= real-stack execution
= required manual smoke
```

`STAGE_08_TASK_INDEX.md` is an orchestration artifact.

Codex must **not** read this index, roadmap, product specifications, architecture/database/API docs, previous Stage task files, Stage history, or closure reviews to infer implementation requirements.

Every implementation task must receive one compact, self-contained implementation contract.

Do not create a second large duplicate `CODEX-PROMPT` file.

---

## 7. Approved Task Order and Current Status

| Order | Task ID | Area | Short outcome | Depends on | Historical planning-package contract status | Current readiness / review status | Delivery / execution status | Contract file |
|---|---|---|---|---|---|---|---|---|
| `0` | `S08-DOC-001` | `Documentation / Contract alignment` | `Freeze Stage 8 execution contract and Stage 8/9 boundary` | `Stage 7 closed + Stage 8 decomposition approved` | `Approved` | `Accepted` | `Delivered — PR #233, merge 4d6039cae5a0561f2e2c540748c76a3f3f5a1039` | `tasks/S08-DOC-001-stage-08-blitz-execution-contract-alignment.md` |
| `1` | `S08-BE-001` | `Backend` | `Blitz persistence/domain foundation` | `DOC-001 Accepted / Delivered` | `Approved` | `Accepted` | `Delivered — PR #236, merge 45ce101b97a34ac2f29d660ca30236c16845ab37` | `tasks/backend/stage-08/S08-BE-001-blitz-persistence-domain-foundation.md` |
| `2` | `S08-BE-002` | `Backend` | `Teacher Blitz authoring/read/update lifecycle API` | `DOC-001 + BE-001 Accepted / Delivered` | `Approved` | `Accepted` | `Delivered — PR #238, merge 87a071dbddd7887b5b61b99a9727754b9839fba7` | `tasks/backend/stage-08/S08-BE-002-teacher-blitz-authoring-lifecycle-api.md` |
| `3` | `S08-BE-003` | `Backend` | `Blitz Question authoring integration` | `DOC-001 + BE-001…002 Accepted / Delivered` | `Approved` | `Accepted` | `Delivered — PR #241, merge eedb63838e09aa2e122520a4ca706c63076f6a57` | `tasks/backend/stage-08/S08-BE-003-blitz-question-authoring-integration.md` |
| `4` | `S08-BE-004` | `Backend` | `Official Blitz designation + activation engine` | `DOC-001 + BE-001…003 Accepted / Delivered` | `Approved` | `Accepted` | `Delivered — PR #243, merge be2f246be4342ed87144278217d8f804528fd1c0` | `tasks/backend/stage-08/S08-BE-004-official-blitz-designation-activation-engine.md` |
| `5` | `S08-BE-005` | `Backend` | `Student Blitz read + explicit Start/Resume + Blitz-first Homework Start compatibility` | `DOC-001 + BE-001…004 Accepted / Delivered` | `Approved` | `Accepted` | `Delivered — PR #245, merge a392c6e73a8c8ead2ed989a3c02bfa2b63f1e3e3` | `tasks/backend/stage-08/S08-BE-005-student-blitz-read-start-resume.md` |
| `6` | `S08-BE-006` | `Backend` | `Student typed/file answer mutation with timer enforcement` | `DOC-001 + BE-001…005 Accepted / Delivered` | `Approved` | `Accepted` | `Delivered — PR #247, merge cc2ffd348417d8980a459b3eefa056e61563b45e` | `tasks/backend/stage-08/S08-BE-006-student-blitz-answer-file-mutation.md` |
| `7` | `S08-BE-007` | `Backend` | `Timeout/Teacher-close/Scheduler finalization engine` | `DOC-001 + BE-001…006 Accepted / Delivered` | `Approved` | `Accepted` | `Delivered — PR #249, merge ae2e40c2eea223f3907d1ca2f9b44e619d036d5c` | `tasks/backend/stage-08/S08-BE-007-blitz-finalization-timeout-close-scheduler.md` |
| `8` | `S08-BE-008` | `Backend` | `Idempotent Student Blitz Submit + finalization races` | `DOC-001 + BE-001…007 Accepted / Delivered` | `Approved` | `Accepted` | `Delivered — PR #251, merge 2aaeccba1738fe0d1fce1d04b6e2ad9caeb65716` | `tasks/backend/stage-08/S08-BE-008-idempotent-student-blitz-submit.md` |
| `9` | `S08-BE-009` | `Backend` | `Student-specific technical exception + replacement Attempt #2` | `DOC-001 + BE-001…008 Accepted / Delivered` | `Approved` | `Accepted` | `Delivered — PR #253, merge b93f62c92590fbb12a977393fce0f286f5421b3a` | `tasks/backend/stage-08/S08-BE-009-student-specific-blitz-attempt-exception.md` |
| `10` | `S08-BE-010` | `Backend` | `Teacher Blitz live monitoring API` | `DOC-001 + BE-001…009 Accepted / Delivered` | `Approved` | `Accepted` | `Delivered — PR #255, merge c80c2af4d0889aaabe06dc64b3db0243bb94600c` | `tasks/backend/stage-08/S08-BE-010-teacher-blitz-monitoring-api.md` |
| `11` | `S08-BE-PHASE-2` | `Backend review` | `Full Stage 8 backend review + full backend regression` | `BE-001…010 Accepted / Delivered` | `Approved` | `PASS` | `Run #1 on 232ebcd NOT ACCEPTED; run #2 on 1c56cde PASS — P1=0, P2=0, P3 fixed/accepted, §40 suite 2354 passed (see §17)` | `tasks/backend/stage-08/S08-BE-PHASE-2-backend-block-review.md` |
| `11a` | `S08-BE-PHASE-2-FIX-001` | `Backend fix` | `Item-ID key leak, Blitz-first Homework authoring, one decision clock, activation replay fail-closed, monitoring lock pre-check` | `Phase 2 run #1 + owner decisions D1/D2/D3/D5` | `Approved` | `Accepted` | `Delivered — PR #260, merge 1c56cde0e2d32883866f9f68fa3445ed8232d839` | `tasks/backend/stage-08/S08-BE-PHASE-2-FIX-001-blitz-execution-integrity-fixes.md` |
| `11b` | `S08-BE-PHASE-2-FIX-002` | `Documentation fix` | `Start error matrix for timeout-finalized Attempts; scheduled_at precision; item-ID convention exception` | `Phase 2 run #1 + owner decisions D1/D3/D5` | `Approved` | `Accepted` | `Delivered — PR #258, merge edb3be86aa855fff1f87245ec367117cc9554a24` | `tasks/backend/stage-08/S08-BE-PHASE-2-FIX-002-start-error-and-schema-docs.md` |
| `11c` | `S08-BE-PHASE-2-FIX-003` | `Test config fix` | `phpunit.xml memory_limit 512M for the §40 full-suite gate` | `Phase 2 run #1 + owner decision D4` | `Approved` | `Accepted` | `Delivered — PR #259, merge 2bb5b406ae9f77ed6b1e85a2ca56bea19623fbe5` | `tasks/backend/stage-08/S08-BE-PHASE-2-FIX-003-phpunit-memory-limit.md` |
| `12` | `S08-FE-001` | `Frontend` | `Teacher Blitz frontend foundation` | `Backend Phase 2 PASS` | `Approved` | `Accepted` | `Delivered — PR #262, merge 15508f3cdfc337a299bd2f002896e6ee9de70137` | `tasks/frontend/stage-08/S08-FE-001-teacher-blitz-frontend-foundation.md` |
| `13` | `S08-FE-002` | `Frontend` | `Teacher Blitz Builder` | `FE-001 Accepted / Delivered + Backend Phase 2 PASS` | `Approved` | `Accepted` | `Delivered — PR #264, merge b5b24b1690023a5c834cebcbb574ac50ecf73d31` | `tasks/frontend/stage-08/S08-FE-002-teacher-blitz-builder.md` |
| `14` | `S08-FE-003` | `Frontend` | `Teacher official designation, scheduling and lifecycle UX` | `FE-001…002 Accepted / Delivered + Backend Phase 2 PASS` | `Approved` | `Accepted` | `Delivered — PR #266, merge a37dd0204738b96aa69f0f471f9e4befa564c4be` | `tasks/frontend/stage-08/S08-FE-003-teacher-blitz-lifecycle-ux.md` |
| `15` | `S08-FE-004` | `Frontend` | `Student active detail, Start/Resume/replacement and authoritative countdown` | `FE-001…003 Accepted / Delivered + Backend Phase 2 PASS` | `Approved` | `Accepted` | `Delivered — PR #268, merge 466119ad96beb7ce8da56ef107bda587a58d7980` | `tasks/frontend/stage-08/S08-FE-004-student-active-detail-start-resume-countdown.md` |
| `16` | `S08-FE-005` | `Frontend` | `Student execution + Submit + terminal reconciliation UX` | `FE-001…004 Accepted / Delivered + Backend Phase 2 PASS` | `Approved` | `Accepted` | `Delivered — PR #270, merge 05d06ec8a9133081fc77adf04d9af668ff3f5e04` | `tasks/frontend/stage-08/S08-FE-005-student-execution-submit-terminal-reconciliation-ux.md` |
| `17` | `S08-FE-006` | `Frontend` | `Teacher monitoring + exception grant + approved mobile quick actions` | `FE-001…005 Accepted / Delivered + Backend Phase 2 PASS` | `Approved` | `Accepted` | `Delivered — PR #272, merge 48776a1a6936feab158338c4385169911400d24d` | `tasks/frontend/stage-08/S08-FE-006-teacher-live-monitoring-exception-mobile.md` |
| `18` | `S08-FE-PHASE-2` | `Frontend review` | `Full Stage 8 frontend review + full verification` | `FE-001…006 Accepted / Delivered + Backend Phase 2 PASS` | `Approved` | `PASS` | `Run #1 on 03c6581 NOT ACCEPTED; run #2 on 2a59651 PASS — P1 = 0, P2 = 0, P3 = 0, flutter test 3422 passed (see §18)` | `tasks/frontend/stage-08/S08-FE-PHASE-2-frontend-block-review.md` |
| `18a` | `S08-FE-PHASE-2-FIX-001` | `Frontend fix` | `Countdown baseline at adoption, detail re-read on app return, Teacher route-owner generations, test gaps` | `Phase 2 run #1 + owner decisions FE-D1/FE-D2` | `Approved` | `Accepted` | `Delivered — PR #275, merge 2a5965182a3a30fc0f2e44c4c59fbedd8e0ce854` | `tasks/frontend/stage-08/S08-FE-PHASE-2-FIX-001-countdown-baseline-and-route-ownership.md` |
| `19` | `S08-INT-001` | `Integration` | `Guarded real-stack Blitz E2E/security/persistence verification` | `Both Phase 2 checkpoints PASS` | `Approved` | `Approved — revalidated 2026-09-27 on d96b569 (see §19)` | `In progress — assets delivered PR #278 (3e54c90); Harness Preflight #1 NOT ACCEPTED (see §20)` | `tasks/integration/stage-08/S08-INT-001-stage-08-real-stack-integration.md` |
| `19a` | `S08-INT-001-FIX-001` | `Integration fix` | `Harness preflight #1 fixes: pre-start guard, audited checkout, due-time comparisons, run-safety P3s` | `Preflight #1 + owner decision INT-D4` | `Approved` | `Approved` | `Not started` | `tasks/integration/stage-08/S08-INT-001-FIX-001-harness-preflight-fixes.md` |
| `20` | `STAGE_08_CLOSURE_REVIEW` | `Closure` | `Final Stage-wide architecture/security/delivery review` | `S08-INT-001 PASS + required fixes/delivery` | `Approved` | `Prepared` | `Not started` | `tasks/STAGE_08_CLOSURE_REVIEW.md` |

### Status-column semantics

- `Historical planning-package contract status` records planning-time contract
  preparation/approval only. It is intentionally non-authoritative for execution.
- `Current readiness / review status` is authoritative for task execution.
  `S08-DOC-001`, `S08-BE-001…010` and `S08-BE-PHASE-2-FIX-001…003` are `Accepted / Delivered`.
  `S08-BE-PHASE-2` is `PASS` (run #2, see §17). `S08-FE-001…006` are
  `Accepted / Delivered`. `S08-FE-PHASE-2-FIX-001` is `Accepted / Delivered` and
  `S08-FE-PHASE-2` is `PASS` (run #2, see §18). `S08-INT-001` is `Approved / In progress`
  (assets delivered, Harness Preflight #1 `NOT ACCEPTED`, see §20); `S08-INT-001-FIX-001` is
  `Approved / Not started`; the closure review remains `Prepared / Not started`.
- ChatGPT changes the exact next implementation task to current `Approved` only
  after re-checking current `origin/main`, dependency delivery and the final
  self-contained contract.
- `Delivery / execution status` records actual implementation/checkpoint/integration
  execution. `Not started` is not acceptance or delivery evidence.
- Saving/merging this planning package does not itself authorize implementation.

The canonical Stage 8 planning package contains the 21 original rows above plus this
`tasks/STAGE_08_TASK_INDEX.md` file = **22 files**. Rows `11a`–`11c` are Phase 2 fix
contracts added on 2026-09-23 and are not part of the original package count.

`STAGE_08_PROPOSED_DECOMPOSITION.md` is obsolete planning scaffolding and is
excluded from the canonical Stage 8 package.

---

## 8. Dependency Chain and Manual Readiness Gates

Primary execution order:

```text
S08-DOC-001 Accepted / Delivered
    ↓
S08-BE-001 Accepted / Delivered
    ↓
S08-BE-002 Accepted / Delivered
    ↓
S08-BE-003 Accepted / Delivered
    ↓
S08-BE-004 Accepted / Delivered
    ↓
S08-BE-005 Accepted / Delivered
    ↓
S08-BE-006 Accepted / Delivered
    ↓
S08-BE-007 Accepted / Delivered
    ↓
S08-BE-008 Accepted / Delivered
    ↓
S08-BE-009 Accepted / Delivered
    ↓
S08-BE-010 Accepted / Delivered
    ↓
S08-BE-PHASE-2 run #1 NOT ACCEPTED (2026-09-23, audited 232ebcd)
    ↓
S08-BE-PHASE-2-FIX-001…003 Accepted / Delivered (PRs #258–#260)
    ↓
S08-BE-PHASE-2 run #2 PASS (2026-09-24, audited 1c56cde)
    ↓
ChatGPT re-checks current main and S08-FE-001 readiness
    ↓
S08-FE-001 Accepted / Delivered (PR #262, 15508f3)
    ↓
S08-FE-002 Accepted / Delivered (PR #264, b5b24b1)
    ↓
S08-FE-003 Accepted / Delivered (PR #266, a37dd02)
    ↓
S08-FE-004 Accepted / Delivered (PR #268, 466119a)
    ↓
S08-FE-005 Accepted / Delivered (PR #270, 05d06ec)
    ↓
S08-FE-006 Accepted / Delivered (PR #272, 48776a1)
    ↓
S08-FE-PHASE-2 PASS (run #2, 2a59651; run #1 on 03c6581 NOT ACCEPTED; FIX-001 PR #275)
    ↓
S08-INT-001 readiness Approved (2026-09-27, d96b569; see §19)
    ↓
S08-INT-001 assets delivered (PR #278, 3e54c90); Harness Preflight #1 NOT ACCEPTED (see §20)
    ↓
S08-INT-001-FIX-001 Approved / Not started -> Harness Preflight #2 -> full run
    ↓
S08-INT-001 PASS required before proceeding
    ↓
ChatGPT verifies closure entry conditions on current main
    ↓
STAGE_08_CLOSURE_REVIEW Prepared / Not started
```

### 8.1 Manual task workflow

Work proceeds one task at a time:

```text
ChatGPT current-main/readiness review
→ one approved task contract
→ Codex implementation + focused verification
→ ChatGPT acceptance/review
→ GitHub delivery
→ Stage index bookkeeping
→ next task
```

The Project Owner normally executes GitHub delivery unless the current contract
explicitly assigns it to Codex. The Project Owner may explicitly tell ChatGPT to
continue at any point; ChatGPT must still verify the next task's readiness.

### 8.2 Readiness authority

Only the exact task whose current readiness/review status is `Approved` may be
handed to Codex. Historical planning approval or the mere existence of a contract
does not authorize execution.

ChatGPT changes the exact next task from `Prepared` to `Approved` only after
re-checking current `origin/main`, delivered dependencies, directly relevant
implementation/tests, and the exact self-contained contract.

### 8.3 ChatGPT/Codex boundary

Before handing the first task of a new block to Codex:

1. ChatGPT confirms the previous checkpoint/integration evidence remains valid;
2. ChatGPT re-checks current `origin/main` and delivered dependencies;
3. ChatGPT inspects directly relevant implementation/tests and revalidates the
   exact next contract;
4. ChatGPT records current readiness as `Approved` for that exact task;
5. only then may that contract be handed to Codex.

Codex receives the approved self-contained contract and must not inspect the
INDEX or Stage history to infer implementation requirements or readiness.

Implementation contracts may record narrower direct task dependencies where
safe.

---

## 9. Task Readiness Policy

Before each implementation task is handed to Codex, ChatGPT must:

1. re-check current `origin/main`;
2. confirm all required dependencies are `Accepted / Delivered`;
3. inspect the directly relevant implementation/tests;
4. verify no parallel merged change invalidated assumptions;
5. resolve scope and non-goals;
6. resolve business behavior;
7. resolve exact public API behavior;
8. resolve persistence/schema behavior;
9. resolve lifecycle/state transitions;
10. resolve validation;
11. resolve authorization/Tenant isolation;
12. resolve error behavior;
13. resolve edge cases;
14. resolve concurrency/idempotency where relevant;
15. define acceptance criteria;
16. define focused task verification;
17. pass the Implementation Readiness Gate.

Codex must not make unresolved product, business, architecture, API, database, authorization, Tenant, lifecycle, timing, concurrency, or idempotency decisions.

---

## 10. Backend Task Intent

### S08-DOC-001 — Blitz Execution Contract Alignment

Must freeze before backend implementation:

- Stage 8 vs Stage 9 ownership;
- exact Blitz Attempt execution statuses;
- timeout semantics;
- unanswered Question representation;
- manual-review state boundary;
- terminal reason/timestamp semantics;
- Teacher Close semantics;
- synchronized/individual timing;
- technical replacement Attempt semantics;
- official Blitz designation;
- official pair/cohort behavior;
- exact high-risk idempotency requirements;
- exact execution-state fields Stage 8 may or may not mutate.

This task must correct locked contract wording only where actual contradictions/ambiguity exist. It must not casually redesign completed Stage 6/7 behavior.

### S08-BE-001 — Blitz Persistence/Domain Foundation

Owns only the missing Blitz-specific persistence/domain foundation.

Expected direction includes:

```text
blitz_tasks
blitz_attempt_exceptions
BlitzStatus
TimerStartMode representation/reuse
Assessment ↔ BlitzTask relation
exception relations
database constraints/indexes
```

It must extend delivered migrations safely through new migrations; never rewrite delivered migrations.

### S08-BE-002 — Teacher Blitz Authoring API

Owns Teacher:

- create;
- list;
- detail;
- update;
- recipient/assignment configuration;
- duration;
- scheduling;
- archive according to the frozen lifecycle contract.

No Student execution.

### S08-BE-003 — Blitz Question Authoring Integration

Must safely extend the delivered shared Question system so a Blitz can use the nine approved Question types.

It must preserve Homework rules and introduce Blitz-specific edit locks instead of weakening existing Homework access guards.

### S08-BE-004 — Official Blitz Designation + Activation

This is one of the highest-risk Stage 8 tasks.

Must own:

- eligible whole-group official Blitz designation;
- completion of existing `topic_result_pairs.blitz_assessment_id`;
- same-Topic/Tenant/Teacher enforcement;
- official cohort establishment or exact reuse;
- result-pair locking semantics;
- activation validation;
- timer-mode snapshot;
- authoritative activation timestamp;
- synchronized common end timestamp;
- durable activation idempotency where required.

### S08-BE-005 — Student Read + Start/Resume

Must own:

- active eligible Blitz discovery;
- Student-safe detail;
- recipient/ownership checks;
- no draft/scheduled Student access;
- one normal Attempt;
- resume semantics;
- synchronized effective deadline;
- individual Start-derived deadline;
- durable Start idempotency;
- pair-wide official-activity compatibility so Blitz-first activity does not
  block the later first Homework Start;
- separate Homework Attempt numbering/capacity from Blitz Attempt history;
- preserve an existing valid pair `locked_at` established by the Blitz side
  rather than rewriting it during later Homework Start;
- no device-clock authority.

### S08-BE-006 — Student Answer/File Mutation

Must reuse delivered Stage 7 lower-level answer/file semantics where genuinely shared while preserving Blitz-specific:

- timer/deadline guard;
- status guard;
- ownership;
- same-Assessment Question binding;
- file privacy;
- terminal immutability;
- no checking/scoring.

### S08-BE-007 — Finalization Engine

Must define one authoritative Blitz finalization mechanism reused by:

- request-path deadline reconciliation;
- Scheduler reconciliation;
- Teacher Close;
- later Submit race resolution as applicable.

It must preserve deterministic lock ordering and terminal event precedence.

### S08-BE-008 — Student Submit

Must own explicit Student Submit and its durable idempotency.

It must define exact races with:

- timeout;
- Teacher Close;
- answer/file mutation;
- repeated Submit.

### S08-BE-009 — Technical Attempt Exception

Must guarantee:

```text
normal Attempt #1
+ at most one authorized replacement Attempt #2
```

with:

- required reason;
- authorized Teacher only;
- preserved original Attempt;
- original `official_score_eligible = false`;
- no third Attempt;
- no class-wide attempt-limit mutation;
- concurrency-safe duplicate-exception protection.

### S08-BE-010 — Teacher Monitoring

Must expose only authorized, Tenant-safe monitoring state required for classroom operation.

Teacher observes Student execution but never writes answers for the Student.

---

## 11. Backend Phase 2 Gate

`S08-BE-001…010` are `Accepted / Delivered`. `S08-BE-PHASE-2` run #1 (2026-09-23) was
`NOT ACCEPTED`; after `S08-BE-PHASE-2-FIX-001…003` were delivered, run #2 (2026-09-24,
audited `1c56cde`) is `PASS` (§17). `S08-FE-001` was revalidated on `1c56cde` and released:

```text
S08-BE-PHASE-2
```

Minimum checkpoint scope:

- full Stage 8 backend read-only review;
- full backend regression suite;
- required backend format/static checks;
- `git diff --check`;
- migration/schema/constraint/index review;
- common-vs-Blitz domain separation;
- API contract review;
- authorization/Tenant isolation;
- direct-ID existence privacy;
- result-pair/cohort semantics;
- timer authority;
- timer setting snapshot;
- activation idempotency;
- Start idempotency;
- Submit idempotency;
- technical exception idempotency/concurrency;
- timeout reconciliation;
- Teacher Close;
- Scheduler;
- lock ordering;
- write-vs-finalization races;
- terminal immutability;
- file privacy;
- Stage 6/7 regression;
- Stage 9 boundary.

A Backend Phase 2 `PASS` does not directly authorize the frontend block.

After:

```text
S08-BE-PHASE-2 = PASS
P1 = 0
P2 = 0
```

ChatGPT re-checks current `origin/main`, confirms Backend Phase 2 PASS remains
valid, revalidates `S08-FE-001`, and records its current readiness as `Approved`.
Only then may `S08-FE-001` be handed to Codex.

Any P3 findings must be explicitly accepted or fixed before the Backend Phase 2
PASS is considered valid for this transition.

ChatGPT owns this readiness review; Codex receives only the approved contract.

---

## 12. Frontend Task Intent

### S08-FE-001 — Teacher Blitz Frontend Foundation

Create the typed frontend foundation:

- domain models;
- DTOs;
- repositories;
- Dio data sources;
- Riverpod providers/controllers;
- route targets;
- Teacher Blitz list/detail.

### S08-FE-002 — Teacher Blitz Builder

Own:

- assignment mode;
- Student selection where allowed;
- title/description/instructions;
- whole-Blitz duration;
- nine-type Question Builder integration;
- create/edit Builder state and validation only.

Do **not** assign official designation or Schedule/reschedule lifecycle actions
to FE-002.

### S08-FE-003 — Teacher Lifecycle UX

Own:

- official Blitz designation UX;
- Schedule/reschedule UX;
- activation;
- close;
- archive;
- authoritative server state;
- timer-mode display;
- mutation uncertainty/reconciliation;
- no client-owned lifecycle truth.

### S08-FE-004 — Student Start + Countdown

Own:

- active Blitz discovery/detail;
- Start/Resume;
- server-derived synchronized countdown;
- server-derived individual countdown;
- reload/resume correctness;
- device clock never used as permission authority.

### S08-FE-005 — Student Execution/Finalization UX

Own:

- nine answer types;
- file answer flow;
- Submit;
- timeout response/reconciliation;
- Teacher-close response/reconciliation;
- terminal read-only UX;
- no client-side scoring.

### S08-FE-006 — Teacher Monitoring/Exception/Mobile

Own:

- live participation projection;
- attempt/status projection;
- technical exception action;
- required reason UX;
- quick Teacher mobile classroom actions;
- reuse of lifecycle/application state rather than duplicating business logic.

---

## 13. Frontend Phase 2 Gate

After `S08-FE-001…006` are `Accepted / Delivered`, execute:

```text
S08-FE-PHASE-2
```

Minimum checkpoint scope:

- full Stage 8 frontend read-only review;
- full Flutter test suite;
- `flutter analyze`;
- required format verification;
- required Windows build;
- required Android build;
- routing/session ownership;
- stale async ownership;
- typed DTO contract integrity;
- Teacher lifecycle state;
- Student timer state;
- countdown/reload behavior;
- server-authoritative timing;
- mutation uncertainty;
- terminal-state reconciliation;
- answer/file UX;
- monitoring;
- technical exception UX;
- mobile quick actions;
- Stage 6/7 frontend regressions.

A Frontend Phase 2 `PASS` does not directly authorize integration.

After:

```text
S08-FE-PHASE-2 = PASS
P1 = 0
P2 = 0
```

and with Backend Phase 2 PASS still valid, ChatGPT re-checks current
`origin/main`, confirms both checkpoint PASS records, and revalidates
`S08-INT-001`. After ChatGPT records current readiness as `Approved`, Codex may
receive the released integration contract.

---

## 14. Integration Gate

`S08-INT-001` must exercise the real Laravel + Flutter stack rather than only isolated unit/widget behavior.

Minimum required scenarios:

1. Teacher creates a Blitz.
2. Teacher configures supported Questions.
3. Teacher creates whole-group and selected-Student Blitz variants.
4. Selected-Student Blitz cannot become official.
5. Eligible whole-group Blitz can complete the Topic result pair.
6. Existing official Homework is preserved.
7. Established official cohort is preserved exactly.
8. First official activation establishes cohort when no cohort exists.
9. Activation is blocked when the required Institution timer mode is unset.
10. Synchronized activation captures authoritative start/end.
11. Late Student receives only remaining synchronized time.
12. Individual Student Start receives full configured duration.
13. Device clock/timezone cannot extend execution.
14. Draft/scheduled Blitz is inaccessible to Student.
15. Unassigned Student cannot access/start.
16. Normal Student can have exactly one normal Attempt.
17. Student can save/replace supported typed answers.
18. Student file upload/replacement/private access works.
19. Explicit Submit freezes the Attempt.
20. Timeout auto-finalizes committed work.
21. Late answer/file writes are rejected.
22. Teacher Close blocks new starts/writes and finalizes in-progress Attempts.
23. Never-started Student receives no fabricated Attempt.
24. Unanswered Question receives no fabricated answer row.
25. Submit/timeout/Teacher-close/write races result in one valid terminal history.
26. Technical exception requires an authorized Teacher and reason.
27. Original Attempt remains historical and becomes ineligible for official scoring.
28. Exactly one replacement Attempt is permitted.
29. A second exception/third Attempt is rejected.
30. Teacher monitoring is scoped to the authorized Blitz/Group/Tenant.
31. Cross-Tenant/direct-ID access remains private.
32. Student desktop execution works.
33. Student mobile execution works.
34. Required Teacher desktop/mobile classroom actions work.
35. Required persistence/restart behavior is verified.
36. Cleanup removes only Stage 8-owned test artifacts.
37. Blitz-first Student activity still permits official Homework activation and
    the first Homework Start without rewriting the existing pair lock/cohort.

Integration verdict must be:

```text
PASS
```

but Integration PASS alone does not authorize Stage Closure Review.

After accepted/delivered Integration PASS, ChatGPT verifies Stage Closure Review
entry conditions on current `origin/main` before beginning
`STAGE_08_CLOSURE_REVIEW`.

Meeting closure entry conditions releases review only; it does not itself mark
Stage 8 closed. ChatGPT owns the Stage Closure Review verdict.

---

## 15. Stage 8 Closure Gate

Stage 8 can be marked `STAGE CLOSED` only after all of the following are true:

- `S08-DOC-001` Accepted / Delivered;
- `S08-BE-001…010` Accepted / Delivered;
- `S08-BE-PHASE-2 = PASS`;
- backend checkpoint `P1 = 0`, `P2 = 0`;
- `S08-FE-001…006` Accepted / Delivered;
- `S08-FE-PHASE-2 = PASS`;
- frontend checkpoint `P1 = 0`, `P2 = 0`;
- `S08-INT-001 = Accepted / Delivered / PASS`;
- all required focused fixes and delivery are complete;
- current `origin/main` contains the complete accepted Stage 8 result;
- repository synchronization/cleanliness meets the closure contract;
- ChatGPT has verified closure entry conditions on current `origin/main`;
- required real-stack desktop/mobile evidence accepted;
- required Tenant/security checks pass;
- technical exception behavior is verified;
- timeout/Teacher-close/Scheduler behavior is verified;
- result-pair/cohort semantics are verified;
- no unresolved Stage 8 regression affects completed Stage 6/7 behavior;
- Stage 8 did not absorb Stage 9 checking/scoring responsibilities;
- closure review finds no blocking architecture/security/delivery issue.

Final closure artifact:

```text
tasks/STAGE_08_CLOSURE_REVIEW.md
```

Stage 9 planning is permitted only after Stage 8 closure is `PASS`.

---

## 16. Current Stage State

Current planning-package state:

```text
Stage 7 closure                  = PASS
Stage 8 decomposition            = Approved
Stage 8 Stage status             = Approved
Stage 8 implementation           = In progress — S08-DOC-001, S08-BE-001…010 and S08-BE-PHASE-2-FIX-001…003 Accepted / Delivered; S08-BE-PHASE-2 PASS (run #2, 1c56cde); S08-FE-001 Accepted / Delivered (PR #262, 15508f3); S08-FE-002 Accepted / Delivered (PR #264, b5b24b1); S08-FE-003 Accepted / Delivered (PR #266, a37dd02); S08-FE-004 Accepted / Delivered (PR #268, 466119a); S08-FE-005 Accepted / Delivered (PR #270, 05d06ec); S08-FE-006 Accepted / Delivered (PR #272, 48776a1); S08-FE-PHASE-2-FIX-001 Accepted / Delivered (PR #275, 2a59651); S08-FE-PHASE-2 PASS (run #2, 2a59651); S08-INT-001 Approved / In progress (assets delivered PR #278, 3e54c90; preflight #1 NOT ACCEPTED; S08-INT-001-FIX-001 Approved / Not started); closure Prepared / Not started
Detailed task contracts          = Final planning package reviewed and approved; execution remains per-task gated
Current per-task readiness       = S08-DOC-001, S08-BE-001…010 and S08-BE-PHASE-2-FIX-001…003 Accepted / Delivered; S08-BE-PHASE-2 PASS; S08-FE-001 Accepted / Delivered (PR #262, 15508f3); S08-FE-002 Accepted / Delivered (PR #264, b5b24b1); S08-FE-003 Accepted / Delivered (PR #266, a37dd02); S08-FE-004 Accepted / Delivered (PR #268, 466119a); S08-FE-005 Accepted / Delivered (PR #270, 05d06ec); S08-FE-006 Accepted / Delivered (PR #272, 48776a1); S08-FE-PHASE-2-FIX-001 Accepted / Delivered (PR #275, 2a59651); S08-FE-PHASE-2 PASS (run #2, 2a59651); S08-INT-001 Approved / In progress (assets delivered PR #278, 3e54c90; preflight #1 NOT ACCEPTED; S08-INT-001-FIX-001 Approved / Not started); closure Prepared / Not started
Backend Phase 2                  = PASS (run #2, 1c56cde; run #1 on 232ebcd NOT ACCEPTED)
Frontend Phase 2                 = PASS (run #2, 2a59651; run #1 on 03c6581 NOT ACCEPTED)
Integration                      = S08-INT-001 Approved / In progress (assets PR #278; Harness Preflight #1 NOT ACCEPTED; FIX-001 Approved / Not started)
Closure                          = NOT STARTED
STAGE_08_PROPOSED_DECOMPOSITION  = OBSOLETE / EXCLUDED
```

The next permitted workflow action is:

```text
S08-INT-001-FIX-001 implementation, then Integration Harness Preflight #2
```

Do not regenerate duplicate task contracts merely because this index previously
said they were not created.

Saving the planning package to GitHub does **not** make all rows implementation-ready.

Work one implementation task at a time. Before each task reaches Codex, ChatGPT
must re-check current `origin/main`, delivered dependency state, current code/tests,
and the exact self-contained contract, then explicitly record current readiness
for that task.

---

## 17. Backend Phase 2 Run #1 Record (2026-09-23)

Roles: from 2026-09-23 the Project Owner assigned Claude both the ChatGPT role
(requirements, contracts, review, acceptance, bookkeeping) and the Codex role
(implementation). Git delivery: Claude opens PRs; the Project Owner merges.
References to ChatGPT/Codex in this index apply to Claude accordingly.

### Execution

```text
Audited main       = 232ebcd80c883e400bccf2aa4db4c5bbaccac2a0
Diff base          = e0e8bad (first parent before PR #236)
Git state          = main == origin/main, 0/0; working tree clean after the Project Owner
                     moved 2 untracked personal setup files out of frontend/ (decision D6)
Review             = read-only, 7 parallel area reviews; every P1/P2 re-verified against code,
                     P1-1 and P2-1 with executable API proofs in an isolated scratch database
```

Task delivery: BE-001 #236 · BE-002 #238 · BE-003 #241 · BE-004 #243 · BE-005 #245 ·
BE-006 #247 · BE-007 #249 · BE-008 #251 · BE-009 #253 · BE-010 #255 · post-release test
alignment #257 (`IdempotencyOperation` exact-list test, stale since BE-004).

### Verification

| Check | Result |
|---|---|
| §40 `php artisan test` | `FAIL` — exit 2 after 597 s, PHP 128M `memory_limit` exhausted (no product/test failure) |
| Diagnostic `php -d memory_limit=2G vendor/bin/phpunit` (same SHA) | 2338 tests, 55,540 assertions, 0 failures, exit 0, 30:30, peak 167 MB; 2 PHPUnit notices in a pre-Stage-8 test (mocks without expectations) |
| `pint --test` | PASS (728 files) |
| PHP lint/static | N/A — no established tool |
| `git diff --check e0e8bad...232ebcd` | PASS |

Areas without blocking findings: architecture, DB/migrations, authorization/Tenant (cross-Tenant
negative tests for every Stage 8 endpoint), exception/replacement, monitoring projection,
concurrency (no opposite lock order; all §32 races coherent; terminal immutability),
Homework regressions, scope/diff (no Stage 9 code).

### Findings

| ID | Severity | Finding | Decision |
|---|---|---|---|
| `P1-1` | P1 | Matching/Ordering item IDs are time-ordered UUIDv7 in answer order; sorting IDs from the Student Start payload recovers the key (proved 6/6 pairs, 7/7 positions). Shared with Stage 7 Homework projection | D1 = A + D → FIX-001 |
| `P2-1` | P2 | Blitz-first pair lock blocks official Homework Question authoring; Homework can never be activated or replaced (proved via API) | D2 = A + D → FIX-001 |
| `P2-2` | P2 | Start/Resume on a timeout-finalized Attempt returns `blitz_time_expired`, contradicting DOC-001 §13.9 | D3 = B → FIX-002 (docs) + FIX-001 (test) |
| `P3-1` | P3 | Final reads use the PostgreSQL clock, reconciliation the PHP clock; DB-ahead skew gives 500 at the deadline | D5 fix → FIX-001 |
| `P3-2` | P3 | Activation replay does not fail closed for `draft`/`scheduled` history | D5 fix → FIX-001 |
| `P3-3` | P3 | Monitoring takes row locks through the reconciler on every poll | D5 fix → FIX-001 |
| `P3-4` | P3 | Scheduler scan has no `blitz_tasks` index leading with `status` | Accepted follow-up |
| `P3-5` | P3 | File-answer deadline check precedes some lock waits; stored timestamps may postdate the deadline under contention | Accepted follow-up |
| `P3-6` | P3 | Blitz-wide helpers under `App\Support\Student`, Homework-named shared writers, inline error strings, pair-lock rule duplicated | Accepted follow-up |
| `P3-7` | P3 | `scheduled_at` precision migration outside BE-002 scope, undocumented | Docs part → FIX-002; scope note accepted |
| `P3-8` | P3 | Test gaps (activation vs preparation race, membership end after activation, Homework GET with Blitz Attempt ID) | Matching/Ordering privacy covered by FIX-001; rest accepted follow-up |
| `P3-9` | P3 | Test portability (hard-coded worker DB env, `session_replication_role` privilege) | Accepted follow-up |
| Gate | — | §40 full-suite command fails on memory | D4 = A → FIX-003 |

### Verdict

```text
S08-BE-PHASE-2 run #1 = NOT ACCEPTED (P1 = 1, P2 = 2, P3 = 9, §40 gate failure)
Refreshed verdict requires: FIX-001…003 delivered to main; the two review proofs rerun (key no
longer recoverable; Homework authoring allowed after Blitz-first activity); focused evidence of
FIX-001; exact §40 command once on the new main; targeted read-only re-review of the fix diff.
Frontend (S08-FE-001) stays blocked until the refreshed verdict is PASS.
```

### Run #2 (2026-09-24) — refreshed verdict

```text
Audited main       = 1c56cde0e2d32883866f9f68fa3445ed8232d839
Delivered fixes    = FIX-002 + run #1 record: PR #258 (edb3be8) · FIX-003: PR #259 (2bb5b40) ·
                     FIX-001: PR #260 (1c56cde)
Merge integrity    = 232ebcd..1c56cde touches exactly the 24 files of #258/#259/#260
                     (7 + 1 + 16); no merge-resolution changes
Git state          = main == origin/main, 0/0, clean
```

| Check | Result |
|---|---|
| §40 `php artisan test` (exact command) | PASS — 2354 passed, 55,701 assertions, 2279 s, exit 0; no failed/skipped/incomplete/risky test (the 2 pre-existing PHPUnit notices from Stage 5 `ProtectedLearningMaterialDownloadApiTest` mocks remain, as in run #1) |
| `pint --test` | PASS (733 files) |
| `git diff --check 232ebcd..1c56cde` and `e0e8bad..1c56cde` | PASS |
| P1-1 review proof rerun (sort item IDs from Start payload) | Key no longer recoverable (pairs and order random) |
| P2-1 review proof rerun (Blitz-first) | Homework Question add `201`, Homework activation `200`, Homework replacement still `409 result_pair_locked` |
| FIX-001 independent fresh-context review (pre-merge, identical diff) | P1 = 0, P2 = 0; three P3 notes resolved; `HasVersion4Uuids` suggestion rejected (timestamp-first ordered UUIDs would re-leak) |

Evidence validity: FIX-001 changed the shared timeout reconciler, Question mutation access,
monitoring, activation replay and two item models, so the full suite was rerun (above). Lock
order is unchanged (one unlocked read under the held Topic lock; one lock-free monitoring
pre-check), so the run #1 §31/§32 concurrency conclusions remain valid. No route, request,
resource shape or schema changed.

```text
S08-BE-PHASE-2 run #2 = PASS
P1 = 0, P2 = 0
P3: P3-1, P3-2, P3-3 fixed (FIX-001); P3-7 documentation part fixed (FIX-002);
    P3-4, P3-5, P3-6, P3-7 scope note, remaining P3-8, P3-9 accepted as follow-ups (decision D5)
```

### S08-FE-001 readiness revalidation (2026-09-24, main 1c56cde)

Revalidated against the delivered backend and the current Flutter code: every endpoint, query
key, resource key, envelope, enum and error status in scope matches; every named frontend
class/helper exists; no undelivered dependency. Twelve contract corrections were applied (three
behavior-relevant: explicit mobile allowlist + bootstrap keep-location for the Blitz detail
route; malformed route redirects to the Teacher workspace, not TechnicalRoot; `group_id` is not
sent). Current readiness: `Approved / Not started`.

### S08-FE-001 acceptance (2026-09-24)

```text
Delivered          = PR #262, merge 15508f3cdfc337a299bd2f002896e6ee9de70137 (feature commit 434de39)
Merge integrity    = frontend tree of 15508f3 identical to the reviewed commit 434de39
```

Focused evidence on the delivered diff: 109 Blitz tests (9 files) and 159 directly affected
Topic/Homework/router regression tests pass; `flutter analyze --no-pub` on `lib/features/teacher`,
`lib/app/router` and `test/features/teacher` reports no issues; `dart format --set-exit-if-changed`
and `git diff --check` pass; committed blobs are LF. Deliberate-break checks on DTO lifecycle rules,
controller stale/duplicate guards and the three routing integration points all turned tests red. An
independent fresh-context review found P1 = 0, P2 = 0; its four P3 notes (disposal assertion,
detail surface-change test, widget-reuse test, Back comment) were fixed before merge. The only
touched existing production behavior is the shared Question-list parser extraction; Homework
messages are byte-identical and Homework parsing tests pass. Verdict: `Accepted / Delivered`.

### S08-FE-002 readiness revalidation (2026-09-24, main 15508f3)

Revalidated against the delivered backend (`TeacherBlitzCreateRequest`/`TeacherBlitzUpdateRequest`,
`CreateTeacherBlitz`/`UpdateTeacherBlitz`, `TeacherBlitzPreparationGuard`, `TeacherQuestionController`,
`TeacherQuestionMutationAccess`, `ApiErrorResponse`) and the delivered FE-001/Stage 6 Flutter code.
Create/PATCH key sets, limits (title 255, description/instructions 10000, duration JSON integer
1..2147483647), server trimming, success statuses and messages, Blitz Question editability
(`draft|scheduled`; Active → `business_conflict`; Closed/Archived → `task_closed`/`task_archived`;
closed Topic → `topic_not_editable`; `result_pair_locked` is Homework-only) and
`official_task_requires_group_assignment` all match the contract. Every named frontend
type/helper exists; all required error codes already exist in `ApiErrorCodes`. Corrections marked
"revalidation 2026-09-24" make the PATCH success envelope exact (the backend does define a message),
record the confirmed conflict matrix, name the current mutation-activity files, and explicitly
authorize updating the FE-001 routing assertions whose `/blitz/new` and `/blitz/<id>/edit` behavior
FE-002 intentionally changes. No material conflict. Current readiness: `Approved / Not started`.

### S08-FE-002 acceptance (2026-09-24)

```text
Delivered          = PR #264, merge b5b24b1690023a5c834cebcbb574ac50ecf73d31 (feature commit e8a2c44)
Merge integrity    = tree of b5b24b1 identical to the reviewed commit e8a2c44
```

Focused evidence on the delivered diff: 134 FE-002 tests (11 files), 104 FE-001 Blitz regression
tests and 222 directly affected Homework/Question/router regression tests pass;
`flutter analyze --no-pub` on `lib/features/teacher`, `lib/app/router`, `test/features/teacher` and
`test/router_bootstrap_test.dart` reports no issues; `dart format --set-exit-if-changed` and
`git diff --check` pass; committed blobs are LF. Deliberate-break checks on the official
assignment lock, edit reconciliation match, edit stale-completion guard, Blitz Question conflict set,
Active Question lock (builder and editor), Draft-only create success and the confirmed-pair guard for
an inconsistent official state all turned tests red. An independent fresh-context review found no
blocking defect; the official-contradiction guard and the §63 Refresh dialog copy were fixed and four
test gaps closed before merge. The shared Question-editor/transport extraction keeps Homework
behavior, copy and test keys; the Blitz Question builder/editor controllers deliberately mirror the
Homework ones (contract §8/§83). The FE-001 routing and section assertions changed only where the
contract changes behavior (§17, §93). Verdict: `Accepted / Delivered`.

### S08-FE-003 readiness revalidation (2026-09-24, main b5b24b1)

Revalidated against the delivered backend (`routes/api.php` teacher group; `TeacherBlitzController`
schedule/activate/close/archive; `ScheduleTeacherBlitz`, `ActivateTeacherBlitz`, `CloseTeacherBlitz`,
`ArchiveTeacherBlitz`, `TeacherBlitzPreparationGuard`, `InstitutionBlitzScheduledAt`,
`IdempotencyGuard`, `TeacherOfficialAssessmentCohort`, `SetTeacherTopicResultPair`,
`TeacherTopicResultPairUpdateRequest`, `TeacherTopicOpenAssessmentGuard`, `ApiErrorResponse`) and
the delivered FE-001/FE-002/Stage 6 Flutter code. Routes, request bodies, success statuses and exact
success messages, the no-auto-activation boundary, Idempotency-Key requirement and completed-replay
semantics (the current Blitz is replayed, including `closed|archived`), the no-pair / locked-partial
fill / unlocked replacement result-pair rules, the preserved Blitz side on the Stage 6 Homework-only
body, and the Topic open-assessment rule (Homework draft/active or Blitz draft/scheduled/active) all
match the contract. `InstitutionTimezone.serializeWallClock` already emits the numeric offset the
backend requires (`Z` is rejected), and `SecureIdempotencyKeyGenerator` emits lowercase UUIDv4.
Corrections marked "revalidation 2026-09-24" record the delivered Schedule/Archive/Close/Activate
conflict matrices and copy, the `200` returned when an already-Active Blitz is activated with a new
key, the Activation `meta` envelope that the delivered FE-002 exact error reader currently rejects,
the two missing `ApiErrorCodes` constants, the delivered same-route serialization pieces, and the
current Topic open-assessment behavior. No material conflict. Current readiness:
`Approved / Not started`.

### S08-FE-003 acceptance (2026-09-26)

```text
Delivered          = PR #266, merge a37dd0204738b96aa69f0f471f9e4befa564c4be (feature commit f88c179)
Merge integrity    = tree of a37dd02 identical to the reviewed commit f88c179
```

Focused evidence on the delivered diff: 146 FE-003 tests (schedule, lifecycle domain/data
source/controller/screen, official Blitz controller, result-pair data, Blitz detail, Topic
controller), 221 FE-001/FE-002 Blitz regression tests (18 files) and 246 directly affected Stage 6
official Homework/result-pair, Homework, Question transport and Topic routing/operation tests pass;
`flutter analyze --no-pub` on `lib/features/teacher`, `lib/core/network` and `test/features/teacher`
reports no issues (the router is unchanged); `dart format --set-exit-if-changed` and
`git diff --check` pass; committed blobs are LF. Twelve deliberate-break checks (locked partial
fill, same-key replay acceptance, key reuse on Retry, preparation Archive safety, Scheduled
same-instant no-op, `meta` restricted to the settings error, Question-lease serialization, Topic
list refresh, FE-002 Edit lease guard, key kept across Schedule/Archive, Refresh clearing a settled
notice, Scheduled replay rejected even with activation evidence) all turned tests red. An
independent fresh-context review found no regression or security issue; Schedule/Archive no
longer discard an unresolved activation key, a stale Question reload flag no longer blocks
lifecycle actions, unused code was removed and five test gaps were closed before merge. FE-001/002
detail, Topic controller/routing and Stage 6 fake changes are limited to contract-directed behavior
(§8/§96, §70/§97) and a throwing `setOfficialBlitz` fake override. Verdict: `Accepted / Delivered`.

### S08-FE-004 readiness revalidation (2026-09-26, main a37dd02)

Revalidated against the delivered backend (`routes/api.php` Student group,
`StudentBlitzController`, `StudentBlitzAttemptController`, `StudentBlitzShowRequest`,
`StudentBlitzAttemptStartRequest`, `ReadStudentBlitz`, `StartStudentBlitzAttempt`,
`StudentBlitzAccess`, `StudentBlitzTiming`, `StudentBlitzAttemptSummary`, the three Student Blitz
resources, `IdempotencyGuard`, `ApiErrorResponse` and their feature tests) and the delivered Stage 7
Student code. Routes, the absence of any Blitz Attempt GET, the intent bodies, success statuses and
exact messages, list/detail/Attempt key sets, timing and attempt-summary keys, the whole-second `Z`
timestamps, intent-specific same-key replay (stored status, current state, terminal allowed), the
per-intent Start error matrix, the `{message, code, errors}` envelope, and the identical Homework
Question/answer shapes all match the contract. `IdempotencyKeyGenerator`, `StudentSessionKey`,
`StudentQuestion`/`StudentQuestionDto`/`StudentQuestionReadView` and the strict whole-second UTC
parser already exist. One behavior-relevant correction: a detail whose latest Attempt is finished
(no replacement) is a valid `200` with `deadline_at` = that Attempt's deadline and
`remaining_seconds = 0`, and the deadline may be earlier or later than `server_now`; the original
§18 equality/ordering rule would have rejected it despite §118 requiring it to parse. The contract
now accepts that shape and shows "You have already finished this Blitz." with no Start control.
Other corrections marked "revalidation 2026-09-26" record the delivered facts, list membership and
order, detail conflict conditions, the nullable/number value types, the non-null Attempt deadline,
fresh-send terminal results, the two missing `ApiErrorCodes` constants, and a re-export approach
that keeps the shared answer extraction inside the §116 file scope. No material conflict. Current
readiness: `Approved / Not started`.

### S08-FE-004 acceptance (2026-09-26)

```text
Delivered          = PR #268, merge 466119ad96beb7ce8da56ef107bda587a58d7980 (feature commit 3dc0d36)
Merge integrity    = tree of 466119a identical to the reviewed commit 3dc0d36
```

Focused evidence on the delivered diff:
- **Tests:**
  - 208 FE-004 tests across 12 files: list/detail DTO, Attempt DTO, domain, both data sources, active-list/detail/Start controllers, countdown, Active Blitz section, detail screen, routing;
  - 1523 tests overall, covering the whole `test/features/student` suite, `router_bootstrap_test` and every other full-app test (Teacher routing/material, Institution Admin, Platform Owner).
- **Static checks:**
  - `flutter analyze --no-pub` on `lib/features/student`, `lib/app/router`, `lib/core/network`, `test/features/student` and `test/router_bootstrap_test.dart` reports no issues;
  - `dart format --set-exit-if-changed` and `git diff --check` pass;
  - committed blobs are LF.
- **Deliberate-break checks:** 19 checks all turned tests red:
  - finished-attempt timing;
  - replacement deadline;
  - Question-key leak;
  - Resume accepting another Attempt;
  - normal Start accepting #2;
  - timer-mode mismatch;
  - Retry with a new key;
  - shell kept after time expiry;
  - expiry read not de-duplicated;
  - expiry read skipped while another read is in flight;
  - unexpected Start error dropping the frozen request;
  - stale list owner;
  - countdown reset on rebuild;
  - countdown ticking after zero;
  - Start without confirmation;
  - pre-Start zero without a read;
  - Start offered while a request is pending;
  - Active Blitz section missing;
  - bootstrap dropping the deep link.
- **Independent fresh-context review, fixed before merge:**
  - P1: two Admin/Platform full-app tests hung. The new controllers now end unexpected failures in a retryable `unknown` error (Start becomes `uncertain` and keeps the frozen request), following the adjacent Topic controllers.
  - P2: the zero-time read now supersedes an in-flight read.
  - P3 cleanups.
- **Changes outside the new files:**
  - The Stage 7 saved-answer extraction keeps Homework behaviour and messages. The Homework files re-export the moved classes and parser.
  - The Homework DTO also uses the new shared required-timestamp helper, with an identical message.
  - Four existing full-app tests only gained a `studentBlitzRepositoryProvider` override.

Verdict: `Accepted / Delivered`.

### S08-FE-005 readiness revalidation (2026-09-26, main 466119a)

Revalidated against the delivered backend (shared answer PUT/multipart, Blitz Submit, protected
download and Start replay: `StudentAttemptAnswerRequest`, `SaveStudentBlitzAttemptAnswer`,
`SaveStudentBlitzFileAnswer`, `StudentBlitzAttemptAccess`, `StudentAttemptSubmitRequest`,
`SubmitStudentBlitzAttempt`, `StartStudentBlitzAttempt`, `ProtectedStudentSubmissionAccess`,
`CloseTeacherBlitz`, `FinalizeTimedOutBlitzAttempts` and their tests) and the delivered FE-004 and
Stage 7 Student code. What matches the contract:
- the answer route and bodies (the Stage 7 `StudentAnswerMutation` JSON and multipart upload are
  accepted unchanged for Blitz);
- the cleared-answer shape and clear rules, which the delivered `canClear` already encodes;
- the success envelopes and the exact Submit message, with the Attempt resource shape;
- the Submit idempotency and same-key replay semantics;
- the reachable error codes (no `submission_locked` or `deadline_passed` for Blitz);
- the protected download rules;
- the completed Start replay as the only re-read (it returns the same Attempt's current state with
  the stored status and finalizes a due Attempt during the replay).

Every named Stage 7 primitive exists, and the shared editors are callback-driven. Behavior-relevant
corrections marked "Revalidation 2026-09-26":
- the delivered FE-004 start state still owns the execution Attempt, anchor and expiry flag; FE-005
  moves them to the execution controller;
- local zero and detail conflicts during execution reconcile through the completed Start replay, so
  timeout and Teacher Close end in the finalization summary instead of FE-004 dropping the shell;
- the shared answer transport is extracted once, while the Homework repository methods stay as
  thin delegates, so the Homework controllers and 13 Stage 7 test fakes stay unchanged.

Other corrections record the delivered facts, the Submit check order after Close, the
recovery-label parameter, existing error constants and the actual Stage 7 test file names. No
material conflict. Current readiness: `Approved / Not started`.

### S08-FE-005 acceptance (2026-09-26)

```text
Delivered          = PR #270, merge 05d06ec8a9133081fc77adf04d9af668ff3f5e04 (feature commit 14848e9)
Merge integrity    = tree of 05d06ec identical to the reviewed commit 14848e9
```

Focused evidence on the delivered diff:
- **Tests:**
  - 265 FE-005 tests across 13 new files: shared answer transport, Submit DTO and data source, execution, answer, file, transfer, readiness and Submit controllers, finalization summary, execution screen (desktop and mobile), replay safety (4 request shapes × 7 recovery paths) and countdown races;
  - 1391 tests in `test/features/student` plus `router_bootstrap_test`, including the updated FE-004 tests and every Stage 7 answer/file/Submit/Homework test named in §112.
- **Static checks:**
  - `flutter analyze --no-pub` on `lib/features/student`, `lib/core/network`, `test/features/student` and `test/router_bootstrap_test.dart` reports no issues;
  - `dart format --set-exit-if-changed` on all 50 changed files and `git diff --check` pass;
  - committed blobs are LF.
- **Deliberate-break checks:** 27 checks all turned tests red, among them:
  - a replay rebuilt from the current Attempt, or adopting another Attempt;
  - a replay racing an in-flight write;
  - a stale publication patch applied;
  - zero server time reopening writes;
  - an older detail snapshot re-anchoring;
  - detail conflicts dropping the shell;
  - a rebuilt handoff request;
  - an auto-retried save;
  - matching metadata proving an upload;
  - a new key or a fresh expectation on Retry Submit;
  - a timeout or Teacher-close lineage accepted as a Submit;
  - unanswered Questions blocking Submit;
  - Leave offered while a Submit is in flight;
  - a retried answer PUT.
- **Independent fresh-context review, fixed before merge with failing-first tests:**
  - no P1;
  - P2: a confirmed file upload outrun by a typed save now counts once the replay shows exactly that file (id, name, extension, size, `updatedAt`); the contract's token rules are unchanged;
  - P3:
    - a Submit that completes after its controller is disposed still ends its write;
    - the summary shows no review status;
    - a 404 on a final Attempt's file revokes that link;
    - a Submit or replay 404 refreshes detail and the active list;
    - leaving during a reconciliation has its own copy.
- **Found during implementation:** the re-anchor rule moved from FE-004 accepted an older detail snapshot, which could show more time than the server has left. Only a newer snapshot re-anchors now.
- **Changes outside the new files:**
  - The raw answer PUT and multipart upload moved once into `StudentAttemptAnswerRemoteDataSource`; the Homework data source methods are thin delegates.
  - `StudentHomeworkAttemptPublicationToken` is a typedef of the neutral token.
  - The two shared editors gained an optional `recoveryLabel` (default `Reload attempt`).
  - The answer-mutation DTO and domain import the neutral saved-answer files.
  - Homework behaviour and messages are unchanged.
- **Note:** the explicit `finalization_reason == student_submit` check in the Submit DTO (§50) cannot be reached through JSON, because the FE-004 Attempt DTO already rejects Submit-like timestamps on another reason. It is kept as the contract's explicit rule; the Submit controller's own check is covered by a test.

Verdict: `Accepted / Delivered`.

### S08-FE-006 readiness revalidation (2026-09-26, main 05d06ec)

Revalidated against the delivered backend (Teacher monitoring, attempt-exception grant and
activation: `TeacherBlitzShowRequest`, `ShowTeacherBlitzMonitoring`,
`TeacherBlitzMonitoringResource`, `FinalizeTimedOutBlitzAttempts`,
`TeacherBlitzAttemptExceptionRequest`, `GrantTeacherBlitzAttemptException`,
`TeacherBlitzAttemptExceptionResource`, `ActivateTeacherBlitz` and their feature tests) and
the delivered FE-001…003 Teacher code. What matches the contract:
- the monitoring route, exact response shape, row status mapping (`checked` and
  `submitted` are `finalized`), row field rules, `score` always `null`, summary invariants,
  Student ordering and the absence of answers, files and scores;
- the lifecycle `409` codes and the server-side timeout finalization before the response;
- the grant route, body, reason types, `201` message, exact resource keys and the
  `replacement_attempt_available` truth table, with the completed replay checked before
  lifecycle;
- the grant error codes, and activation replay after Close/Archive returning `200` with the
  current Blitz;
- activation has no device restriction, and the FE-001 detail controller already turns a
  `404` or a Topic mismatch into `notFound` on both surfaces.

Behavior-relevant corrections marked "Revalidation 2026-09-26":
- every FE-003 lifecycle layer is desktop-only today; the lifecycle controller, the route
  mutation lease (for `activate` only), the controls and the detail screen are opened to
  mobile for Activate, Retry activation and Check current Blitz, and nothing else;
- the FE-003 and routing tests that assert no mobile Activate, no Monitor and an invalid
  monitoring path change with the sections that authorize it; the Topic Blitz section test
  stays unchanged;
- the reason limit is counted in code points, and the grant uses the delivered exact
  mutation transport.

Other corrections record the delivered facts, the absent Teacher throttle (the `429` pause
stays defensive), the grant check order, the detail guard projection, the router shape, the
Institution-timezone formatter, the three missing error constants and the actual test file
names. No material conflict. Current readiness: `Approved / Not started`.

### S08-FE-006 acceptance (2026-09-26)

```text
Delivered          = PR #272, merge 48776a1a6936feab158338c4385169911400d24d (feature commit 4651bc9)
Merge integrity    = tree of 48776a1 identical to the reviewed commit 4651bc9
```

Focused evidence on the delivered diff:
- **Tests:**
  - 190 focused FE-006 tests: monitoring DTO, grant request/DTO, both data sources, monitoring and grant controllers, monitoring screen (desktop and mobile), routing and formatters;
  - 148 direct FE-001…003 regression tests, including the unchanged `teacher_blitz_section_test`;
  - 1050 tests in `test/features/teacher`, `test/app/router` and `test/router_bootstrap_test.dart`.
- **Static checks:**
  - `flutter analyze --no-pub` on `lib/features/teacher`, `lib/app/router`, `lib/core/network` and `test/features/teacher` reports no issues;
  - `dart format --set-exit-if-changed` on all 37 changed files and `git diff --check` pass;
  - committed blobs are LF.
- **Deliberate-break checks:** 38 production mutations.
  - 32 turned tests red, among them:
    - a new key on Retry grant;
    - skipped candidate, ticket-epoch or parent-identity checks;
    - an unknown outcome shown as a failure;
    - Check monitoring confirming without the exception;
    - no monitoring refresh after a definite failure;
    - overlapping polls;
    - no 429 pause;
    - polling during app pause or after a lifecycle end;
    - a monitoring snapshot of another Blitz;
    - a dropped Idempotency-Key;
    - `already_granted` treated as unknown;
    - mobile Close, Official or Grant surfaces;
    - a lost monitoring deep link.
  - 6 were masked by a second guard for the same rule:
    - desktop-only in the grant session check;
    - the grant operation generation;
    - the identity check in `_startRead`;
    - the generation bump on route leave;
    - no Grant control on the mobile card;
    - autoDispose cancelling the timer.
  - 4 gaps the check exposed got new tests.
- **Found during implementation:** a session switch could let the previous session's Blitz detail confirm the parent identity for the new session. Ownership sync is now deferred to a microtask, with a failing-first test.
- **Independent fresh-context review, fixed before merge with failing-first tests:**
  - P1: the desktop grant banner (Retry grant, the §66 guidance, a confirmed grant) was hidden once live monitoring ended or became unavailable, which made the same-key recovery of §§65-66 unreachable. It is now shown beside the ended notice.
  - P3:
    - the stale Active chip after a lifecycle end is hidden;
    - an individual `not_started` row requires null remaining time (§18);
    - Monitor is disabled while a lifecycle mutation owns the route.
- **Design notes:**
  - The monitoring controller listens to the session, device surface and parent identity instead of watching them, so its single poll timer survives notifications.
  - The grant controller depends on monitoring in one direction only (Riverpod 3 treats `ref.read` as a dependency). It hands route ownership over with `setGrantOwnership`.
  - The grant dialog carries a ticket (session, Student and monitoring route epoch).
- **Contract-directed test changes:**
  - the FE-003 "mobile never owns lifecycle mutations" and "mobile shows no lifecycle or designation controls" tests became the mobile Activate tests;
  - the "no Monitor on an Active Blitz" assertions changed;
  - the routing tests now treat `/monitoring` as valid.

Verdict: `Accepted / Delivered`.

### S08-FE-PHASE-2 readiness revalidation (2026-09-26, main 48776a1)

Entry gate on `origin/main` `48776a1`:
- `S08-BE-PHASE-2` is `PASS` (run #2, `1c56cde`).
- `S08-FE-001…006` are delivered by the first-parent merges `15508f3` (#262), `b5b24b1` (#264), `a37dd02` (#266), `466119a` (#268), `05d06ec` (#270) and `48776a1` (#272), all ancestors of the audited main.
- No other Stage 8 frontend production change entered `main`.
- The frontend diff base is `f6618937ea19fe60ebd67c03954f34caf0284cf8`, the first parent of `15508f3`. `frontend/` is unchanged between the Stage 7 closure `962ef5d` and that commit.

Checked against the delivered code, and matching the contract:
- the five Teacher Blitz routes and their exact classifiers;
- the final desktop and mobile Teacher matrices;
- Student Start/Resume and the replay values `_pendingRequest` (start controller) and `_completedStartRequest` (execution controller);
- the five Attempt statuses;
- no Blitz Attempt GET;
- the monitoring and grant behaviour;
- the Topic open-assessment copy ("Homework and Blitz");
- the Builder duration bound;
- all 25 §42 error codes, each declared once in `ApiErrorCodes`;
- the Windows (Visual Studio Community 2026) and Android (SDK 37, licenses accepted) toolchains on this machine, so §§10-11 can run here.

Corrections marked "Revalidation 2026-09-26" in the contract:
- §1: Claude executes the read-only review and the verification commands, as for `S08-BE-PHASE-2` (§17). The Project Owner or CI may run them instead.
- §3: the diff base is recorded.
- §§7-11: run with the pinned SDK in `frontend/.fvm/flutter_sdk` (3.44.7), because the `fvm` CLI is not on PATH.
- §21: the mobile Activate recovery controls (Retry activation, Check current Blitz) are part of Activate.
- §25: the delivered Start matrix. A `start_normal` on a `timed_out_finalized` #1 without an exception returns `blitz_time_expired`; a timed-out Resume target returns `blitz_time_expired`, other terminal targets `attempt_not_editable`.
- §26: the delivered names of the two request values.
- §31: only a strict `200` for the upload itself proves the bytes. The FE-005 metadata match only checks that the server file is still that confirmed upload.

No material conflict. Current readiness: `Approved / Not started`.

## 18. Frontend Phase 2 Run #1 Record (2026-09-26)

### Execution

```text
Audited main       = 03c6581ee83ab35c5f17c89bcb4b959006cda7b9
Diff base          = f6618937ea19fe60ebd67c03954f34caf0284cf8 (first parent of the FE-001 merge)
Git state          = main == origin/main, 0/0, clean before and after all commands
Delivery           = FE-001 #262 (15508f3) · FE-002 #264 (b5b24b1) · FE-003 #266 (a37dd02) ·
                     FE-004 #268 (466119a) · FE-005 #270 (05d06ec) · FE-006 #272 (48776a1),
                     all first-parent ancestors of the audited main
Review             = read-only, six parallel fresh-context area audits covering §§13-47; every
                     finding re-verified against the code
```

### Verification

| Check | Result |
|---|---|
| §7 `flutter test` (pinned SDK 3.44.7) | PASS — exit 0, 3402 passed, 0 failed, 0 skipped, 214 s |
| §8 `flutter analyze --no-pub` | PASS — no issues, exit 0 |
| §9 `dart format --output=none --set-exit-if-changed lib test integration_test` | PASS — 837 files, 0 changed |
| §10 `flutter build windows --debug` | PASS — `build\windows\x64\runner\Debug\testlabuz_client.exe` |
| §11 `flutter build apk --debug` | PASS — `build\app\outputs\flutter-apk\app-debug.apk` |
| §12 `git diff --check f661893...03c6581` | PASS — 218 files, only `frontend/lib`, `frontend/test` and `tasks/`; no backend, package, platform, `integration_test` or generated change |

Areas without findings:
- architecture;
- Teacher read, Builder, routing and the Topic Blitz section;
- mutation uncertainty, schedule and official pair;
- lifecycle and the mobile matrix;
- Student active list, pre-Start privacy and route;
- Start/Resume and the immutable request replay;
- Attempt DTO;
- countdown zero;
- answer/file, Submit/terminal and leave/resume;
- monitoring privacy/state/polling, exception grant and mobile monitoring;
- error codes;
- accessibility/responsive, timer cleanup and request churn;
- security search;
- Stage 6/7 regressions and Topic integration.

### Findings

| ID | Severity | Finding | Decision |
|---|---|---|---|
| `P2-1` | P2 | The Student countdown starts its Stopwatch when the widget is first built, not when the controller adopts the server snapshot (FE-004 §85). A snapshot adopted while the app renders no frames shows the full old remaining time on return, and local writes stay enabled past the real deadline until the server's `blitz_time_expired`. This matches the §5 P2 example "countdown reset grants apparent extra time" | Fix → FIX-001 |
| — | Design gap | No contract re-reads on app return. Dart's Stopwatch is monotonic and probably stands still during Android device suspend (not confirmed on a device), so a sleeping phone can show extra time | `FE-D1 = B` → FIX-001 |
| `P3-1` | P3 | Uncertain Start Retry is tested for normal Start and Resume #1 only, not for `start_replacement` or Resume #2. The code resends the same request for every intent | `FE-D2 = A` → FIX-001 |
| `P3-2` | P3 | An older screen instance's route leave (`leaveLiveRoute`, and on detail `invalidateRouteCompletions` / `leaveRoute` / `endRoute`) acts on the shared family notifier and can stop a newer instance of the same Blitz route (Back, then Monitor during the pop transition). The monitoring screen shows "Live updates paused" | `FE-D2 = A` → FIX-001 |
| `P3-3` | P3 | The pair-lock Blitz Question-authoring test fakes a `409 result_pair_locked` the data source cannot produce. No test covers a confirmed locked pair whose Blitz side is this Draft/Scheduled Blitz | `FE-D2 = A` → FIX-001 |
| `P3-4` | P3 | Stale doc comment `teacher_blitz_section.dart:18-19` | `FE-D2 = A` → FIX-001 |

Observation (not a finding): the Blitz Question builder/editor and submission-transfer controllers
are near-verbatim copies of their Homework/Stage 7 counterparts. FE-002 §8 and FE-005 §§20/32 allow
Blitz-specific orchestration controllers.

### Project Owner decisions (2026-09-27)

- `FE-D1 = B`: when the app becomes visible again, re-read the Blitz detail once (GET). There is no
  POST and no Start replay on return. The fix also moves the countdown baseline to adoption.
- `FE-D2 = A`: all four P3 findings are fixed in `S08-FE-PHASE-2-FIX-001`.

### Verdict

```text
S08-FE-PHASE-2 run #1 = NOT ACCEPTED (P1 = 0, P2 = 1, P3 = 4)
Refreshed verdict requires: S08-FE-PHASE-2-FIX-001 delivered to main; §§7-12 rerun once on the new
main (the fix changes shared Student runtime and Teacher route controllers, so run #1 suite, analyze,
format and build evidence is invalidated); targeted read-only re-review of the fix diff and of
§§29, 30, 36, 39 and 44.
Integration (S08-INT-001) stays blocked until the refreshed verdict is PASS.
```

### S08-FE-PHASE-2-FIX-001 acceptance (2026-09-27)

```text
Delivered          = PR #275, merge 2a5965182a3a30fc0f2e44c4c59fbedd8e0ce854 (feature commit 76b5a5d)
Merge integrity    = tree of 2a59651 identical to 76b5a5d; 7d5acc5..2a59651 touches exactly the
                     25 files of PR #275
```

Focused evidence on the delivered diff:
- **Tests:** 2440 tests pass in `test/features/student`, `test/features/teacher`, `test/app/router` and `test/router_bootstrap_test.dart`.
- **Static checks:** analyze, format (25 files) and `git diff --check` are clean.
- **Deliberate breaks:** 15 mutations, all caught.
- **Route races:** two routing tests reproduce the Back-transition race (monitoring, and reopening a Blitz). They fail without the screen generations.
- **Independent review:** found one P2 and one P3, both fixed test-first before merge.
  - P2: screen tests proving the countdown counts from adoption were missing.
  - P3: an equal detail re-read restarted the baseline.
- **Owner clarification (FE-D1):** returning to the app sends only a GET. If that GET shows the Attempt ended, the existing FE-005 completed-Start replay still adopts the terminal Attempt with its original key, as contract §5.2 keeps.

Verdict: `Accepted / Delivered`.

### Run #2 (2026-09-27) — refreshed verdict

```text
Audited main       = 2a5965182a3a30fc0f2e44c4c59fbedd8e0ce854
Diff base          = f6618937ea19fe60ebd67c03954f34caf0284cf8
Git state          = main == origin/main, 0/0, clean before and after all commands
Review             = targeted read-only fresh-context re-review of the fix diff and of §§29, 30, 36,
                     39 and 44; every run #1 finding re-verified as resolved
```

| Check | Result |
|---|---|
| §7 `flutter test` (pinned SDK 3.44.7) | PASS — exit 0, 3422 passed, 0 failed, 0 skipped, 182 s |
| §8 `flutter analyze --no-pub` | PASS — no issues, exit 0 |
| §9 `dart format --output=none --set-exit-if-changed lib test integration_test` | PASS — 838 files, 0 changed |
| §10 `flutter build windows --debug` | PASS — `build\windows\x64\runner\Debug\testlabuz_client.exe` |
| §11 `flutter build apk --debug` | PASS — `build\app\outputs\flutter-apk\app-debug.apk` |
| §12 `git diff --check f661893...2a59651` | PASS — 220 files, only `frontend/lib`, `frontend/test` and `tasks/` |

Execution note: the first run #2 execution of §§7-11 lost its logs, because the session's temporary
directory holding the script and logs was deleted mid-run, and its `flutter test` process hung. That
process tree was stopped and the unchanged sequence was run once more, from a stable directory. The
results above are from that run. No result was discarded.

Evidence validity:
- Run #1 area results outside the fix diff stay valid; the fix touched only the files listed in its contract §6.
- The full suite, analyze, format and both builds were rerun on the new main (above).

```text
S08-FE-PHASE-2 run #2 = PASS
P1 = 0, P2 = 0, P3 = 0
Next required activity = S08-INT-001 readiness revalidation on current main (checkpoint §53); both
Phase 2 PASS records (backend run #2 on 1c56cde, frontend run #2 on 2a59651) are valid.
```

## 19. Integration Readiness (2026-09-27)

### S08-INT-001 readiness revalidation (2026-09-27, main d96b569)

Entry gate on `origin/main` `d96b569720dd7b232ccf0fdd8cb0e14bfefb3964` (PR #276; tree
identical to `f4dbb2b`):
- Both Phase 2 PASS records remain valid.
  - `S08-BE-PHASE-2` PASS (run #2, `1c56cde`): `backend/` and `docker/` are unchanged between `1c56cde` and `d96b569`.
  - `S08-FE-PHASE-2` PASS (run #2, `2a59651`): only `tasks/STAGE_08_TASK_INDEX.md` changed after `2a59651`.
- The complete accepted Stage 8 implementation is on the audited main.

**Checked against the delivered code.** Five independent read-only reviews covered the items below, and a sixth fact-checked the corrections against the code:
- the Student Start/Resume, Submit and answer PUT matrices and their lock order;
- Teacher activation, the result pair and cohort, Blitz-first Homework compatibility, the grant, Close, monitoring and the Scheduler scanner;
- authentication, roles, Tenant isolation, the protected download, request-validation order, the error envelope, the pre-Start keys and the Student item IDs;
- the Flutter keys, labels and native boundaries (`idempotencyKeyGeneratorProvider`, `studentSubmissionFilePickerProvider`, `localFileActionsProvider`, `appConfigProvider` / `API_BASE_URL`), and the desktop/mobile matrix;
- the Stage 7 harness patterns.

**Two runtime measurements on the `testlabuz-app:latest` image**, with `PHP_CLI_SERVER_WORKERS=4`:
- `php -S` alone: one master and four workers.
- `php artisan serve`: a single server plus a warning without `--no-reload`; one master and four workers with it.

**Corrections marked "Revalidation 2026-09-27" in the contract:**
- §1: Claude holds both roles, with a fresh-context reviewer at preflight and at the final review; owner decision INT-D1; option A delivery; the implementation baseline.
- §10: `--no-reload` is required for the four workers (Laravel `v13.24.0`). The runner creates the container only when it is absent, with the exact spec in §10, and never recreates it. The database password is passed by name.
- §13: the guard checks the command and the `/proc` worker count, and that no scheduler process runs in the container.
- §14.1.3: the delivered lock shape is accepted: the second waiter waits on the first waiter's tuple lock, and the chain ends at the blocker. The blocker runs only its `SELECT ... FOR UPDATE`. The blocker and observer run inside the container and are excluded by PID.
- §22: seeded matching and ordering item IDs must not sort into answer order (D1).
- §26: schema facts; a locked-pair designation sets `updated_at`.
- §33: the `idempotency_records` columns.
- §34.1.1: `meta.missing_fields` is allowed only for `institution_settings_incomplete`.
- §34.1.4: which endpoints need `Idempotency-Key` or an empty body; queries are rejected everywhere except the Teacher Blitz list; validation runs before the `404` lookup on detail and command endpoints; UUIDs are case-insensitive.
- §34.1.4A: the delivered Start matrix (D3):
  - a timed-out Resume target → `blitz_time_expired`;
  - after Close, with a new key → `blitz_not_active`;
  - `start_normal` when an exception row exists → `attempts_exhausted`;
  - a reused key with a foreign `attempt_id` → `idempotency_key_reused`;
  - a due read reconciles the whole Blitz.
- §34.1.5: Close-finalized Attempts → `attempt_not_editable`; `waiting_for_teacher_review` and `checked` only through seeded Attempts.
- §34.1.6: only Blitz visibility and the recipient are checked before the claim, so a reused key with any other visible recipient or Blitz → `idempotency_key_reused`; the eligibility codes.
- §35: probes send `Accept: application/json`; the file route; Teacher answer PUT returns `403`.
- §40: the activation fingerprint and the replay after Close.
- §44.1: the scanner uses the application clock; the command output; which Student, monitoring, Close and grant paths also finalize due Attempts, and that none of them may reach the Scheduler Blitz before the first command.
- §47A.5 and §47A.8: due-time PUT reconciliation; the file blob is staged before the lock.
- §59 and §60: Close has no key; monitoring serves only an Active Blitz.
- §66: the container rule; `-FlutterExecutable` is the pinned SDK; the password source.
- §72 and §73: the preflight additions; where the focused checks run.
- §77: the Android preparation hand-off to the Project Owner.
- §94: current readiness.

**Observations outside this task. Nothing is changed for them:**
- `Stage7E2eSeeder.php:348,354` assigns ordered matching and ordering item IDs. This is fixture data from a closed Stage.
- By code reading, not executed: an unauthenticated API request without `Accept: application/json` probably reaches Laravel's default guest redirect to a missing `login` route. It would then return `500 server_error` instead of `401`. The Flutter client sends that header. This will be checked during execution and reported separately.
- `testlabuz-postgres-1` has been stopped since the host restart. The executor starts it; `testlabuz-demo-app` is not touched.

### Project Owner decision INT-D1 (2026-09-27)

Question: who executes the Windows real-stack runner and the Android manual smoke, which
contract §1 assigned to the Project Owner or CI?

Decision: **A**.
- Claude executes the Windows runner and the direct API/DB scenarios.
- The Project Owner performs the Android manual smoke (§§78-80) by hand, from the checklist that `prepare_stage8_manual_smoke.ps1` prints.

Reason: it is the only evidence not produced by the same agent that wrote the code and the
harness.

### Verdict

No material conflict. Current readiness: `Approved / Not started`.

```text
Implementation baseline = origin/main after this docs PR merges (tree outside tasks/ = d96b569)
Next permitted gate     = S08-INT-001 integration-asset implementation
                          -> Integration Harness Preflight (Claude + fresh-context reviewer)
                          -> Windows real-stack execution (Claude)
                          -> Android manual smoke (Project Owner)
```

## 20. Integration Assets and Harness Preflight #1 (2026-09-27)

### S08-INT-001 integration assets delivered

```text
Delivered          = PR #278, merge 3e54c90c665d821da820d2f1cc136906e153dee7 (head a139118)
Diff               = 17 new files: the §91 list plus frontend/integration_test/stage8_api_scenarios.ps1
                     (a Stage 8-specific helper, which §91 allows); no production source, package,
                     platform or docker change
```

Focused evidence (contract §73), on the branch before merge:
- `Stage8E2eSeederTest` 31 passed, inside the Stage 8 container.
- Pure verifiers PASS: runtime guard (live runtime too), oracle 164 checks, API security 63, concurrency probe 34, test files 11.
- `flutter analyze` and `dart format` on the two Dart files are clean; `git diff --check` is clean.
- 31 deliberate breaks were all caught.
- A development shakeout passed all 15 API scenarios on the live stack. It is not evidence, because the Windows UI was replaced by the same API calls.
- Three fresh-context reviews ran before the PR; their findings were fixed in `583c8c0`.

### Project Owner decisions taken during implementation (2026-09-27)

- **`INT-D2` = option 1 (А).** The owner would rather have no per-Question "Save answer" button.
  Explicit per-Question Save with no autosave is the locked Stage 7/8 decision
  (`S07-FE-003` §§2980-2985, `S07-FE-005`, `S08-FE-005`). Removing the button alone would lose
  answers, because Submit freezes only saved answers and a Blitz timeout keeps only saved ones.
  Stage 8 keeps the button. Autosave is recorded as a candidate for the next stage
  (`docs/06-roadmap.md:2513` lists it as future).
- **`INT-D3` = options 2 + 3 (Б + В).** Each §47A.7/§47A.8 write-vs-Submit race runs in both queue
  orders, each on its own isolated Attempt (new fixtures `race_typed_2`, `race_file_2`). The oracle
  requires the request queued first on the Attempt lock to win. The contract allowed a random
  winner ("need not force"). This makes every run prove both serialized branches, including the
  compensation of the staged file blob.

### Integration Harness Preflight #1 (contract §72)

```text
Audited main       = 3e54c90c665d821da820d2f1cc136906e153dee7
Review             = read-only; Claude plus two fresh-context reviewers (safety/runtime, and
                     coverage/behavior); every finding re-verified against the code
```

Checks that passed:
- Both Phase 2 PASS records remain valid. Since `1c56cde`, `backend/` changed only in the Stage 8
  seeder and its test, and `docker/` did not change. Since `2a59651`, `frontend/` changed only in
  `integration_test/`.
- Exact diff scope; no production source change.
- §44.8: the harness candidate predicate matches `ReconcileDueBlitzTimeouts` exactly (same filters,
  application `now()`). The only global `blitz:reconcile-timeouts` call is inside the guarded
  helper.
- Runtime identity, `--no-reload`, the `/proc` worker count and session correlation on a running
  container; seeder guards, fail-closed ownership and cleanup; prior cleanup on the real private disk
  before the seeder test; restart preservation; no secret logging; the Scheduler guard.
- Every §20.1 F13 coverage row has a fixture, an executable step and an oracle assertion.
- The Start, Submit and grant matrices including the revalidation list; original replay tuples; the
  §47A overlap proof and the §14.1.3 lock shape; the E2E overrides (app config, key generator, file
  picker, local file actions only); real auth and transport; §22 item-ID privacy; no Stage 9
  scoring; no new framework.

Findings:

| ID | Severity | Finding | Decision |
|---|---|---|---|
| `PF1-P2-1` | P2 | A stopped Stage 8 container is started after only a partial static check; port binding, environment and network are checked only after it already serves | Fix → FIX-001 |
| `PF1-P2-2` | P2 | The runner records `HEAD` once and never requires a clean tree; the container bind-mounts the live `backend/` tree, so a change mid-run makes the evidence name code it did not run | Fix → FIX-001 |
| `PF1-P2-3` | P2 | The due Resume of #1, the due Resume of #2 and the late Submit take no before snapshot (§34.1.7), and whole-Blitz due reconciliation is never exercised (one recipient per fixture) | Fix → FIX-001 |
| `PF1-P3-1` | P3 | The file-race frozen check reads the File ID, but a replacement refills the same File row, so the check is vacuous in the write-first branch | Fix → FIX-001 |
| `PF1-P3-2` | P3 | No new-key `start_replacement` or Resume probe after Close | Fix → FIX-001 |
| `PF1-P3-3` | P3 | Container PHP input, including the password, is written to a container `/tmp` file | Fix → FIX-001 |
| `PF1-P3-4` | P3 | `docker exec` calls are unbounded; one wait loop polls without a pause | Fix → FIX-001 |
| `PF1-P3-5` | P3 | The lock observer reads ungranted lock rows of the whole server | Fix → FIX-001 |
| `PF1-P3-6` | P3 | A backend test run elsewhere during a run would wipe `testlabuz_testing` | Fix → FIX-001 |
| `PF1-P3-7` | P3 | The runner and the manual-smoke preparation can run at the same time | Fix → FIX-001 |
| `PF1-P3-8` | P3 | Safe fail-closed reasons from container PHP are replaced by one generic message | Fix → FIX-001 |
| `PF1-P3-9`…`14` | P3 | Seeder-test folder left in the volume when killed; partly indirect Scheduler "invoker never called" cases; narrower item-ID oracle check; loose recipient/cohort re-checks of F13 rows G and H; verifier-only `Assert-Stage8StartReplay`; the Windows flow signs out a local desktop session | Accepted, no change |

### Project Owner decision INT-D4 (2026-09-27)

Question: which preflight #1 findings are fixed before preflight #2?

Decision: **options 2 + 4 (Б + Г).**
- Fix the three P2 findings and the eight run-relevant P3 findings (`PF1-P3-1`…`8`) in
  `S08-INT-001-FIX-001`.
- Procedure: during the full run and the Android manual smoke, no other Claude session works in this
  repository. The fix's audited-checkout and exclusive-database checks detect a violation.

### Verdict

```text
S08-INT-001 Integration Harness Preflight #1 = NOT ACCEPTED (P1 = 0, P2 = 3, P3 = 14; 8 P3 fixed, 6 accepted)
S08-INT-001-FIX-001 = Approved / Not started
  (tasks/integration/stage-08/S08-INT-001-FIX-001-harness-preflight-fixes.md)
Next permitted gate = S08-INT-001-FIX-001 implementation
                      -> Integration Harness Preflight #2 (fix diff + touched §72 items)
                      -> Windows real-stack execution (Claude)
                      -> Android manual smoke (Project Owner)
The full real-stack runner stays blocked until a preflight PASS.
```
