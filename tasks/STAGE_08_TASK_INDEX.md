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
| Stage 8 implementation | `In progress — S08-DOC-001 and S08-BE-001…002 Accepted / Delivered; backend implementation in progress` |
| Detailed task contracts | `Final planning package reviewed and approved; execution remains per-task gated` |
| Backend Phase 2 | `Not started` |
| Frontend Phase 2 | `Not started` |
| Integration | `Not started` |
| Closure | `Not started` |
| Next permitted gate | `S08-BE-003 implementation handoff` |

This index is the ChatGPT / Project Owner orchestration map for Stage 8.

The SHA above is the **historical planning baseline**, not permission to rely on
that revision for implementation. GitHub `main` is the current source of truth
and must be re-checked by ChatGPT before any task receives current readiness.

Stage 8 planning/decomposition is approved. `S08-DOC-001` documentation alignment,
`S08-BE-001` persistence/domain foundation and `S08-BE-002` Teacher Blitz authoring
are `Accepted / Delivered`.
Stage 8 backend implementation is now in progress. `S08-BE-003` is the only
currently `Approved` next implementation task.

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
| `3` | `S08-BE-003` | `Backend` | `Blitz Question authoring integration` | `DOC-001 + BE-001…002 Accepted / Delivered` | `Approved` | `Approved` | `Not started` | `tasks/backend/stage-08/S08-BE-003-blitz-question-authoring-integration.md` |
| `4` | `S08-BE-004` | `Backend` | `Official Blitz designation + activation engine` | `DOC-001 + BE-001…003 Accepted / Delivered` | `Approved` | `Prepared` | `Not started` | `tasks/backend/stage-08/S08-BE-004-official-blitz-designation-activation-engine.md` |
| `5` | `S08-BE-005` | `Backend` | `Student Blitz read + explicit Start/Resume + Blitz-first Homework Start compatibility` | `DOC-001 + BE-001…004 Accepted / Delivered` | `Approved` | `Prepared` | `Not started` | `tasks/backend/stage-08/S08-BE-005-student-blitz-read-start-resume.md` |
| `6` | `S08-BE-006` | `Backend` | `Student typed/file answer mutation with timer enforcement` | `DOC-001 + BE-001…005 Accepted / Delivered` | `Approved` | `Prepared` | `Not started` | `tasks/backend/stage-08/S08-BE-006-student-blitz-answer-file-mutation.md` |
| `7` | `S08-BE-007` | `Backend` | `Timeout/Teacher-close/Scheduler finalization engine` | `DOC-001 + BE-001…006 Accepted / Delivered` | `Approved` | `Prepared` | `Not started` | `tasks/backend/stage-08/S08-BE-007-blitz-finalization-timeout-close-scheduler.md` |
| `8` | `S08-BE-008` | `Backend` | `Idempotent Student Blitz Submit + finalization races` | `DOC-001 + BE-001…007 Accepted / Delivered` | `Approved` | `Prepared` | `Not started` | `tasks/backend/stage-08/S08-BE-008-idempotent-student-blitz-submit.md` |
| `9` | `S08-BE-009` | `Backend` | `Student-specific technical exception + replacement Attempt #2` | `DOC-001 + BE-001…008 Accepted / Delivered` | `Approved` | `Prepared` | `Not started` | `tasks/backend/stage-08/S08-BE-009-student-specific-blitz-attempt-exception.md` |
| `10` | `S08-BE-010` | `Backend` | `Teacher Blitz live monitoring API` | `DOC-001 + BE-001…009 Accepted / Delivered` | `Approved` | `Prepared` | `Not started` | `tasks/backend/stage-08/S08-BE-010-teacher-blitz-monitoring-api.md` |
| `11` | `S08-BE-PHASE-2` | `Backend review` | `Full Stage 8 backend review + full backend regression` | `BE-001…010 Accepted / Delivered` | `Approved` | `Prepared` | `Not started` | `tasks/backend/stage-08/S08-BE-PHASE-2-backend-block-review.md` |
| `12` | `S08-FE-001` | `Frontend` | `Teacher Blitz frontend foundation` | `Backend Phase 2 PASS` | `Approved` | `Prepared` | `Not started` | `tasks/frontend/stage-08/S08-FE-001-teacher-blitz-frontend-foundation.md` |
| `13` | `S08-FE-002` | `Frontend` | `Teacher Blitz Builder` | `FE-001 Accepted / Delivered + Backend Phase 2 PASS` | `Approved` | `Prepared` | `Not started` | `tasks/frontend/stage-08/S08-FE-002-teacher-blitz-builder.md` |
| `14` | `S08-FE-003` | `Frontend` | `Teacher official designation, scheduling and lifecycle UX` | `FE-001…002 Accepted / Delivered + Backend Phase 2 PASS` | `Approved` | `Prepared` | `Not started` | `tasks/frontend/stage-08/S08-FE-003-teacher-blitz-lifecycle-ux.md` |
| `15` | `S08-FE-004` | `Frontend` | `Student active detail, Start/Resume/replacement and authoritative countdown` | `FE-001…003 Accepted / Delivered + Backend Phase 2 PASS` | `Approved` | `Prepared` | `Not started` | `tasks/frontend/stage-08/S08-FE-004-student-active-detail-start-resume-countdown.md` |
| `16` | `S08-FE-005` | `Frontend` | `Student execution + Submit + terminal reconciliation UX` | `FE-001…004 Accepted / Delivered + Backend Phase 2 PASS` | `Approved` | `Prepared` | `Not started` | `tasks/frontend/stage-08/S08-FE-005-student-execution-submit-terminal-reconciliation-ux.md` |
| `17` | `S08-FE-006` | `Frontend` | `Teacher monitoring + exception grant + approved mobile quick actions` | `FE-001…005 Accepted / Delivered + Backend Phase 2 PASS` | `Approved` | `Prepared` | `Not started` | `tasks/frontend/stage-08/S08-FE-006-teacher-live-monitoring-exception-mobile.md` |
| `18` | `S08-FE-PHASE-2` | `Frontend review` | `Full Stage 8 frontend review + full verification` | `FE-001…006 Accepted / Delivered + Backend Phase 2 PASS` | `Approved` | `Prepared` | `Not started` | `tasks/frontend/stage-08/S08-FE-PHASE-2-frontend-block-review.md` |
| `19` | `S08-INT-001` | `Integration` | `Guarded real-stack Blitz E2E/security/persistence verification` | `Both Phase 2 checkpoints PASS` | `Approved` | `Prepared` | `Not started` | `tasks/integration/stage-08/S08-INT-001-stage-08-real-stack-integration.md` |
| `20` | `STAGE_08_CLOSURE_REVIEW` | `Closure` | `Final Stage-wide architecture/security/delivery review` | `S08-INT-001 PASS + required fixes/delivery` | `Approved` | `Prepared` | `Not started` | `tasks/STAGE_08_CLOSURE_REVIEW.md` |

### Status-column semantics

- `Historical planning-package contract status` records planning-time contract
  preparation/approval only. It is intentionally non-authoritative for execution.
- `Current readiness / review status` is authoritative for task execution.
  `S08-DOC-001` and `S08-BE-001…002` are `Accepted / Delivered`. `S08-BE-003` is the
  only current `Approved` implementation task. All later tasks remain
  `Prepared / Not started`.
- ChatGPT changes the exact next implementation task to current `Approved` only
  after re-checking current `origin/main`, dependency delivery and the final
  self-contained contract.
- `Delivery / execution status` records actual implementation/checkpoint/integration
  execution. `Not started` is not acceptance or delivery evidence.
- Saving/merging this planning package does not itself authorize implementation.

The canonical Stage 8 package contains the 21 rows above plus this
`tasks/STAGE_08_TASK_INDEX.md` file = **22 files**.

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
S08-BE-003 Approved / Not started
    ↓
S08-BE-004
    ↓
S08-BE-005
    ↓
S08-BE-006
    ↓
S08-BE-007
    ↓
S08-BE-008
    ↓
S08-BE-009
    ↓
S08-BE-010
    ↓
S08-BE-PHASE-2 PASS
    ↓
ChatGPT re-checks current main and S08-FE-001 readiness
    ↓
S08-FE-001
    ↓
S08-FE-002
    ↓
S08-FE-003
    ↓
S08-FE-004
    ↓
S08-FE-005
    ↓
S08-FE-006
    ↓
S08-FE-PHASE-2 PASS
    ↓
ChatGPT re-checks current main and S08-INT-001 readiness
    ↓
S08-INT-001 Accepted / Delivered / PASS
    ↓
ChatGPT verifies closure entry conditions on current main
    ↓
STAGE_08_CLOSURE_REVIEW
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

After `S08-BE-001…010` are `Accepted / Delivered`, execute:

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
Stage 8 implementation           = In progress — S08-DOC-001 and S08-BE-001…002 Accepted / Delivered; backend implementation in progress
Detailed task contracts          = Final planning package reviewed and approved; execution remains per-task gated
Current per-task readiness       = S08-DOC-001 and S08-BE-001…002 Accepted / Delivered; S08-BE-003 Approved / Not started; all later tasks Prepared / Not started
Backend Phase 2                  = NOT STARTED
Frontend Phase 2                 = NOT STARTED
Integration                      = NOT STARTED
Closure                          = NOT STARTED
STAGE_08_PROPOSED_DECOMPOSITION  = OBSOLETE / EXCLUDED
```

The next permitted workflow action is:

```text
S08-BE-003 implementation handoff
```

Do not regenerate duplicate task contracts merely because this index previously
said they were not created.

Saving the planning package to GitHub does **not** make all rows implementation-ready.

Work one implementation task at a time. Before each task reaches Codex, ChatGPT
must re-check current `origin/main`, delivered dependency state, current code/tests,
and the exact self-contained contract, then explicitly record current readiness
for that task.
