# Stage 6 Closure Review Contract — Homework Assignment Management

## 1. Closure Metadata

| Field | Value |
|---|---|
| Review ID | `STAGE-06-CLOSURE` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Status | `Approved — Pending execution` |
| Review mode | `Independent read-only closure audit followed by closure/documentation bookkeeping` |
| Verification model | `Workflow v3 — Lean Verification` |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |
| Review date | `[execution date]` |
| Stage index | `tasks/STAGE_06_TASK_INDEX.md` |
| Audited `origin/main` | `[final accepted Stage 6 SHA]` |
| Local `main` | `[same SHA expected]` |
| Ahead/behind | `[0/0 expected]` |
| Working tree | `[Clean expected]` |
| Backend Phase 2 | `[PASS required]` |
| Frontend Phase 2 | `[PASS required]` |
| Integration | `[S06-INT-001 PASS required]` |
| Project Owner smoke | `[Windows + Android PASS required]` |
| Open findings | `[P1=0, P2=0, P3=0 required]` |
| Closure verdict | `PENDING` |

Stage 6 Closure Review begins only after all implementation, delivery, Backend Phase 2, Frontend Phase 2, Integration, required fixes, real-stack verification, and required Project Owner smoke are complete.

This review does not authorize production changes.

ChatGPT owns:

- closure analysis;
- roadmap/Definition-of-Done mapping;
- evidence-validity decisions;
- documentation consistency review;
- findings;
- final verdict.

Codex is not used merely to gather closure evidence.

If closure discovers a production defect, ChatGPT prepares a separate focused fix contract.

If closure discovers documentation/bookkeeping drift only, correct only the affected documentation/bookkeeping before final `STAGE CLOSED`.

---

# 2. Current Planning Baseline

At closure-contract preparation time:

```text
origin/main =
d1678b42009287a56c0b31a053e54109406feb8b
```

This is the Stage 5 closure merge:

```text
docs(stage5): close topics and learning materials
```

It is only the **planning baseline**.

Do not execute Stage 6 closure against this SHA.

At closure time, re-fetch and audit current GitHub `main` as the sole source of truth.

---

# 3. Closure Entry Conditions

All required conditions must pass.

| Condition | Required result | Evidence |
|---|---|---|
| Stage 5 explicitly closed | `PASS` | `tasks/STAGE_05_CLOSURE_REVIEW.md` |
| Stage 6 decomposition approved | `PASS` | Stage 6 planning + `STAGE_06_TASK_INDEX.md` |
| `S06-DOC-001` documentation alignment Accepted / Delivered | `PASS` | documentation PR/merge evidence |
| `S06-BE-001…006` all Accepted | `PASS` | task/index evidence |
| `S06-BE-001…006` all delivered | `PASS` | PR/merge evidence |
| Stage 6 Backend Phase 2 | `PASS` | `S06-BE-PHASE-2-backend-block-review.md` |
| `S06-FE-001…004` all Accepted | `PASS` | task/index evidence |
| `S06-FE-001…004` all delivered | `PASS` | PR/merge evidence |
| Stage 6 Frontend Phase 2 | `PASS` | `S06-FE-PHASE-2-frontend-block-review.md` |
| `S06-INT-001` assets delivered | `PASS` | integration PR/merge |
| Automated real-stack Integration | `PASS` | final Stage 6 runner |
| Required Integration production fixes delivered | `PASS/N/A` | focused fix evidence |
| Project Owner Windows smoke | `PASS` | Stage 6 integration evidence |
| Project Owner Android smoke | `PASS` | Stage 6 integration evidence |
| Documentation contracts synchronized | `PASS` | Section 15 |
| Current `origin/main` contains final accepted Stage 6 product | `PASS` | final SHA |
| Local `main == origin/main` | `PASS` | Git evidence |
| Ahead/behind | `0/0` | Git evidence |
| Working tree | `Clean` | Git evidence |
| Open findings | `P1=0, P2=0, P3=0` | review evidence |

Any failed required entry condition blocks closure.

Do not mark Stage 6 closed with a `CONDITIONAL PASS`.

---

# 4. Approved Stage 6 Task Inventory

Closure must reconcile the exact delivered task inventory.

## Stage-wide documentation gate

| Order | Task | Capability | Required final state |
|---:|---|---|---|
| 0 | `S06-DOC-001` | Stage 6 Homework / staged result-pair documentation alignment | `Accepted / Delivered` |

## Backend block

| Order | Task | Capability | Required final state |
|---:|---|---|---|
| 1 | `S06-BE-001` | Assessment & Homework Persistence Foundation | `Accepted / Delivered` |
| 2 | `S06-BE-002` | Typed Question Persistence & Domain Contracts | `Accepted / Delivered` |
| 3 | `S06-BE-003` | Teacher Homework Authoring & Recipient Discovery API | `Accepted / Delivered` |
| 4 | `S06-BE-004` | Teacher Question Mutation & Editing Integrity | `Accepted / Delivered` |
| 5 | `S06-BE-005` | Homework Lifecycle, Recipient Snapshot & Topic Integration | `Accepted / Delivered` |
| 6 | `S06-BE-006` | Official Homework Designation & Staged Result-Pair Contract | `Accepted / Delivered` |

Then:

```text
Stage 6 Backend Phase 2 = PASS
P1=0, P2=0, P3=0
```

## Frontend block

| Order | Task | Capability | Required final state |
|---:|---|---|---|
| 7 | `S06-FE-001` | Homework Client Domain, Read Surfaces & Routing | `Accepted / Delivered` |
| 8 | `S06-FE-002` | Homework Draft Builder: Metadata, Assignment & Deadline | `Accepted / Delivered` |
| 9 | `S06-FE-003` | Nine-Type Question Builder | `Accepted / Delivered` |
| 10 | `S06-FE-004` | Homework Lifecycle & Official Designation UX | `Accepted / Delivered` |

Then:

```text
Stage 6 Frontend Phase 2 = PASS
P1=0, P2=0, P3=0
```

## Integration

| Order | Task | Capability | Required final state |
|---:|---|---|---|
| 11 | `S06-INT-001` | Stage 6 Homework Authoring Real-Stack E2E | `Accepted / Delivered / PASS` |

No approved Stage 6 task may remain open.

---

# 5. Locked Roadmap Goal

Authoritative roadmap Stage:

```text
Stage 6 — Homework Assignment Management
```

Roadmap goal:

> Allow Teachers to build structured homework connected to a topic.

Business value:

> Homework captures the Student’s home-learning performance, which later becomes the first input to the TestLabUz verification model.

Closure must verify that Stage 6 delivers the **Teacher authoring foundation** only.

Student-facing Homework execution remains Stage 7.

---

# 6. Roadmap Acceptance Criterion

Authoritative Stage 6 acceptance criterion:

> A Teacher can create a valid active homework assignment using every supported MVP question type without violating topic, group, or institution boundaries.

Closure verdict cannot be `STAGE CLOSED` unless this complete criterion is verified through:

- backend implementation;
- frontend implementation;
- Phase 2 checkpoints;
- real-stack Integration;
- security/Tenant matrix.

---

# 7. Roadmap Required-Test Matrix

Closure must map every Stage 6 roadmap test requirement.

| Roadmap required test | Required result | Expected evidence |
|---|---|---|
| Builder validation for all nine types | `PASS` | BE-002/004, FE-003, Phase 2, Integration |
| Question/answer validation | `PASS` | typed persistence/domain + all-nine E2E |
| Points validation | `PASS` | exact numeric validation/math + E2E DB oracle |
| Fixed 3-attempt rule | `PASS` | schema/API/resource/frontend + regression |
| Teacher/Admin cannot override attempt count | `PASS` | API validation + UI absence + Integration |
| Deadline/timezone validation | `PASS` | backend UTC authority + frontend Institution time + E2E |
| Unauthorized Group/Student assignment blocked | `PASS` | tenant/auth tests + Integration security matrix |
| Scoring content locked after Attempt begins | `PASS` | structural Attempt lock tests + Integration locked fixture |
| Official Homework designation locks appropriately after Attempts begin | `PASS` | pair lock tests + Integration |
| Draft/active/closed/archived rules | `PASS` | BE/FE lifecycle + Integration |
| Common 0–100 normalization contract supported | `PASS` | structural persistence/API contract support; actual Student scoring remains later Stage |

## 7.1 Normalization boundary

Stage 6 is not required to execute Student scoring.

The roadmap wording:

```text
Common 0–100 normalization contract supported
```

is satisfied in Stage 6 by structural/contract readiness for later scoring, including approved Attempt score storage/range and no conflicting Homework authoring behavior.

Do not require Stage 6 to implement the Stage 7/9 scoring engine merely to close Stage 6.

If the final implementation accidentally performs speculative Student scoring, classify it as scope leakage.

---

# 8. Stage 6 Scope Audit

Closure must verify the complete approved scope.

## 8.1 Homework Builder

PASS requires Teacher desktop support for:

- create Homework from Topic;
- title;
- description;
- Student instructions;
- whole Group assignment;
- selected Student assignment;
- Questions;
- points;
- fixed 3-attempt policy;
- optional deadline;
- lifecycle state.

## 8.2 Lifecycle

Exact:

```text
draft -> active
draft -> archived
active -> closed
closed -> archived
archived -> terminal
```

No reopen.

No implicit active -> archived.

Same-target lifecycle is idempotent.

## 8.3 Nine Question Types

Exactly:

1. Single Choice
2. Multiple Choice
3. True / False
4. Short Written
5. Open Written
6. File Based
7. Matching
8. Ordering
9. Fill in the Blank

No supported type may be missing from backend or frontend.

## 8.4 Official Homework

A Topic may contain multiple Homework tasks, but:

```text
exactly one whole-group Homework may be designated official
selected-student Homework is practice-only
```

Stage 6 must support the Homework side of the official pair without requiring a fake Blitz.

---

# 9. Explicit Stage 6 Non-Goals Audit

Closure must confirm these did **not** enter Stage 6 as production behavior:

- Student Homework execution;
- public Attempt start;
- answer save;
- final submit;
- Student file answer upload;
- answer checking;
- manual grading;
- official Homework score selection;
- Blitz authoring/execution;
- final Topic score/category;
- result release;
- Parent result view;
- AI/fuzzy checking;
- arbitrary attempt-count configuration.

Structural Attempt persistence and test fixtures are allowed only for integrity/lock readiness.

No production Student Attempt route may be live in Stage 6.

---

# 10. Backend Definition-of-Done Review

Required PASS areas:

- PostgreSQL Assessment/Homework persistence;
- direct Institution ownership;
- tenant-safe composite foreign keys;
- fixed attempt structural contract;
- normalized typed Question persistence;
- no uncontrolled authoritative Question JSON blob;
- all-nine domain validation;
- exact Question limits;
- exact point arithmetic;
- Teacher Homework list/create/detail/update;
- Teacher eligible Student roster;
- privacy-safe direct UUID resolution;
- Institution-timezone deadline input and UTC persistence;
- recipient selection and snapshot;
- Question add/update/delete/reorder;
- scoring-content lock after activity;
- Homework lifecycle;
- Topic close/archive open-Homework guard;
- official Homework designation;
- staged result pair;
- concurrency/lock ordering;
- no-op/idempotency;
- safe errors.

Backend Phase 2 must have:

```text
PASS
P1=0
P2=0
P3=0
```

with valid full backend regression evidence.

---

# 11. Frontend Definition-of-Done Review

Required PASS areas:

- typed Homework domain;
- typed all-nine Question domain;
- strict DTO parsing;
- one configured Dio architecture;
- Riverpod session/target/generation safety;
- Homework list/detail;
- desktop create/edit Homework;
- selected Student picker;
- Institution-timezone deadline authoring;
- fixed attempt read-only UX;
- all-nine Question Builder;
- Question mutation/reorder reconciliation;
- no automatic mutation replay;
- desktop lifecycle;
- official designation;
- official read badge on desktop/mobile;
- null-Blitz pair parsing;
- mobile read-only capability boundary;
- existing Stage 1–5 routing preserved;
- accessibility/responsive behavior.

Frontend Phase 2 must have:

```text
PASS
P1=0
P2=0
P3=0
```

with valid:

- full frontend suite;
- analyze;
- format;
- Windows debug build;
- Android debug build;
- stage-wide diff check.

---

# 12. Real-Stack Vertical Review

Accepted Integration must prove the real chain:

```text
Flutter Windows
-> production Router/Riverpod/controllers
-> production repositories/DTOs/Dio
-> Laravel/Sanctum
-> PostgreSQL
```

Required integrated scenarios include:

- real Teacher login;
- whole-group Homework create;
- selected practice Homework create/edit;
- deadline in `Asia/Tashkent`;
- fixed 3 attempts;
- all nine Question types;
- Short Written automatic + manual;
- Question update;
- Question delete;
- Question reorder;
- authoritative total points;
- draft official designation;
- activation;
- Group recipient snapshot;
- official cohort snapshot;
- Topic close blocked by open Homework;
- Homework close/archive;
- Topic close after child resolution;
- locked official pair read;
- scoring-content lock;
- persistence after backend restart.

No closure PASS if the final real-stack scenario did not complete on the final accepted production candidate.

---

# 13. Authorization and Multi-Institution Closure Audit

Required PASS:

- unauthenticated Teacher endpoints denied;
- wrong role denied;
- same-Institution unrelated Teacher denied;
- cross-Institution Topic/Homework/Question denied;
- direct foreign UUID knowledge grants no access;
- foreign Student ID cannot expand selected recipient scope;
- ended/inactive Students excluded from activation recipient snapshot;
- Teacher only manages own authorized Topic/Group;
- selected-student Homework cannot become official;
- locked official Homework cannot be replaced;
- client cannot supply Institution/Teacher/status/total/attempt-count authority;
- frontend hiding does not replace server authorization.

Any unresolved cross-Institution or authorization defect is:

```text
P1
```

and blocks closure.

---

# 14. Editing Integrity / Historical Integrity Review

Required PASS:

- any Assessment Attempt locks scoring-relevant Question content;
- recipient/scoring-relevant Homework fields are locked according to approved backend behavior after activity;
- active history is not destructively deleted;
- archived Homework preserves Questions/recipients/Attempts;
- same-target lifecycle does not churn timestamps;
- same-target official PUT does not churn designation timestamps;
- Question no-op does not rewrite typed configuration;
- active official semantics cannot be replaced after lock;
- old Homework recipients/history survive pre-lock official replacement;
- no fake Attempt is created for never-started Student.

---

# 15. Staged Result-Pair Documentation and Implementation Alignment

This is a **known mandatory closure check**.

The approved Stage 6 implementation sequence requires:

```text
topic_result_pairs.homework_assessment_id NOT NULL
topic_result_pairs.blitz_assessment_id NULL until Stage 8
```

and permits:

```text
locked_at IS NOT NULL
while blitz_assessment_id IS NULL
```

Stage 8 later fills the nullable Blitz slot in the same row.

No fake Blitz is allowed.

## 15.1 Known planning-baseline documentation drift

At the Stage 6 planning baseline, current locked documentation included older text in `docs/08-database.md` describing:

```text
blitz_assessment_id
uuid
not nullable
```

and older result-pair API text may assume both official task IDs are supplied together.

The approved Stage 6 decomposition intentionally superseded that sequencing.

Therefore final closure must re-check at least:

```text
docs/08-database.md
docs/09-api-contracts.md
```

and all directly related result-pair statements in:

```text
docs/02-user-roles.md
docs/04-user-flows.md
docs/05-business-rules.md
docs/06-roadmap.md
docs/07-architecture.md
```

## 15.2 Closure requirement

If final docs still conflict with the accepted implementation:

```text
Stage 6 closure is BLOCKED
```

until a focused documentation-alignment change synchronizes the approved staged-pair contract.

The documentation correction must not reopen product design.

It must encode only the already-approved behavior:

- official Homework may be designated before official Blitz exists;
- partial Topic result-pair row is valid;
- `blitz_assessment_id` is nullable until Stage 8;
- the first official task/cohort rules remain consistent;
- Homework side becomes immutable after first official Homework activity;
- Stage 8 may fill the null Blitz slot even when Homework side is locked;
- that fill is pair completion, not replacement.

Do not create a second official-designation table.

---

# 16. No Fake Blitz Audit

Closure must explicitly confirm:

```text
Stage 6 created no placeholder/fake Blitz Assessment
```

Evidence should include:

- persistence schema;
- result-pair tests;
- Integration DB oracle.

The official Stage 6 pair may legitimately be:

```text
homework = UUID
blitz = null
cohort = timestamp
locked = null or timestamp
```

Frontend must render this state successfully.

---

# 17. Fixed Three-Attempt Rule Audit

Closure must confirm all layers agree:

```text
Every assigned Student receives exactly 3 normal Homework attempts.
```

Required:

- no Institution Admin override;
- no Teacher override;
- no create/edit request field;
- no frontend input;
- no configuration table value overriding it;
- resource/UI reports fixed 3;
- structural Attempt number range cannot create attempt 4.

Student Attempt allocation remains Stage 7.

---

# 18. Deadline / Timezone Closure Audit

Required PASS:

- Teacher input uses Institution timezone;
- client serializes explicit numeric offset;
- backend verifies offset against Institution IANA timezone;
- backend persists UTC;
- API returns authoritative UTC;
- frontend displays deadline in Institution time;
- device timezone/clock is not enforcement authority;
- draft may hold a past deadline;
- activation rejects deadline `<= server now`;
- timezone changes do not rewrite stored absolute instant.

No Stage 6 client-side scheduler.

---

# 19. Question Contract Closure Audit

## Single Choice

- >=2 options;
- exactly one correct;
- automatic;
- all-or-nothing future scoring contract.

## Multiple Choice

- >=2;
- >=1 correct;
- automatic;
- no editable max-selections;
- approved partial-credit contract remains future execution rule.

## True/False

- one Boolean;
- automatic.

## Short Written

- automatic accepted answers OR manual;
- no fuzzy/AI equality;
- manual has no machine answer key.

## Open Written

- manual only.

## File Based

- manual;
- fixed PDF/DOCX/PPT/PPTX authoring contract;
- Student file submission remains Stage 7.

## Matching

- normalized semantic pairs;
- no server key used as client mutation authority.

## Ordering

- >=2;
- correct order represented explicitly.

## Fill Blank

- valid keys;
- accepted answers;
- exact `{{key}}` mapping.

All nine must be verified through backend, frontend, and Integration.

---

# 20. Recipient / Cohort Closure Audit

## Group Homework

On activation snapshot exactly current eligible Students:

- same Institution;
- active Student;
- current Group membership.

Exclude:

- ended membership;
- inactive user;
- unrelated Student;
- foreign Student.

Snapshot remains historical after later membership changes.

## Selected Homework

- selected set is validated against current eligible Students;
- activation revalidates the exact selected set;
- selected Homework is practice-only;
- no silent dropping of ineligible Student at activation.

## Official cohort

Official cohort is derived from the persisted official whole-group Homework recipient snapshot.

No current Group membership resnapshot may rewrite a locked official cohort.

---

# 21. Topic Lifecycle Integration Closure Audit

Required PASS:

A real Topic close/archive must reject when child Homework exists in:

```text
draft
active
```

with:

```text
topic_has_open_assessments
```

No cascade.

Teacher explicitly resolves child Homework.

After all child Homework is:

```text
closed
archived
```

Topic lifecycle may proceed according to its own state rules.

Stage 5 Topic lifecycle behavior must otherwise remain intact.

---

# 22. Stage 7 Boundary Review

Closure must confirm Stage 6 is ready for Stage 7 without prematurely implementing it.

Required forward contract:

- Student Attempt start will lock Assessment before first Attempt insertion;
- official Homework first Attempt also locks result-pair meaning;
- Student belongs to persisted recipient snapshot;
- fixed 3-attempt allocation remains enforceable;
- close Action has a clean insertion point for future in-progress auto-finalization;
- Stage 6 temporary close guard blocks structural `in_progress` Attempt rather than fabricating incomplete answer finalization.

No public Stage 7 Student execution endpoint may be present yet.

---

# 23. Stage 8 Boundary Review

Closure must confirm Stage 8 can later:

```text
blitz_assessment_id: null -> official Blitz UUID
```

in the same Topic result-pair row.

This must remain possible even after:

```text
locked_at != null
```

on the Homework side.

The schema/application must not require:

- clearing the lock;
- replacing Homework;
- creating another result-pair row;
- fake Blitz.

Official cohort must be reusable for the future official Blitz.

Any Stage 6 implementation that requires a breaking result-pair redesign in Stage 8 is at least P2 and blocks closure.

---

# 24. Backend Phase 2 Evidence Validity

At closure fill:

| Field | Value |
|---|---|
| Review | `S06-BE-PHASE-2` |
| Audited SHA | `[SHA]` |
| Verdict | `[PASS required]` |
| Findings | `[P1=0,P2=0,P3=0]` |
| Full backend suite | `[PASS evidence]` |
| Pint | `[PASS]` |
| Stage-wide diff | `[PASS]` |
| Later backend production changes | `[None / list]` |
| Evidence still valid | `[Yes/No]` |
| Additional rerun required | `[None / exact commands]` |
| Additional rerun result | `[N/A / result]` |

Do not rerun the full backend suite during closure merely by habit.

If Integration later required a narrow backend production fix, decide whether:

- focused tests + final Integration are sufficient;
- or the full backend suite evidence was materially invalidated.

Record the reason.

---

# 25. Frontend Phase 2 Evidence Validity

At closure fill:

| Field | Value |
|---|---|
| Review | `S06-FE-PHASE-2` |
| Audited SHA | `[SHA]` |
| Verdict | `[PASS required]` |
| Findings | `[P1=0,P2=0,P3=0]` |
| Full frontend suite | `[PASS evidence]` |
| Analyze | `[PASS]` |
| Format | `[PASS]` |
| Windows debug build | `[PASS]` |
| Android debug build | `[PASS]` |
| Stage-wide diff | `[PASS]` |
| Later frontend production changes | `[None / list]` |
| Evidence still valid | `[Yes/No]` |
| Additional rerun required | `[None / exact commands]` |
| Additional rerun result | `[N/A / result]` |

Do not rerun full frontend suite/builds during closure if current accepted evidence remains valid.

---

# 26. Integration Evidence Validity

At closure fill:

| Field | Value |
|---|---|
| Task | `S06-INT-001` |
| Final tested production SHA | `[SHA]` |
| Runtime guard | `[PASS]` |
| Seeder repeatability | `[PASS]` |
| API security matrix | `[PASS]` |
| Windows real-stack authoring flow | `[PASS]` |
| Nine-type matrix | `[PASS]` |
| DB oracle | `[PASS]` |
| Unrelated-state oracle | `[PASS]` |
| Restart persistence | `[PASS]` |
| Windows manual smoke | `[PASS]` |
| Android real-stack smoke | `[PASS]` |
| Findings | `[P1=0,P2=0,P3=0]` |
| Later production changes | `[None / list]` |
| Evidence still valid | `[Yes/No]` |
| Required rerun | `[None / exact scenario]` |

Final closure requires Integration evidence valid for the final accepted Stage 6 product.

---

# 27. Project Owner Manual Smoke Review

Closure reuses the required Integration manual smoke.

## Windows

Required final evidence includes:

- real Teacher login;
- Homework authoring surface;
- selected Student picker;
- Institution timezone deadline;
- Question Builder type selector;
- keyboard-accessible Question ordering;
- locked official read state.

## Android

Required final evidence includes:

- real Teacher login;
- Homework list/detail;
- official read state;
- fixed attempt display;
- Question read content;
- no Stage 6 mutation/authoring controls.

Do not claim PASS if Project Owner did not run required smoke.

Record:

```text
Windows smoke: PASS / FAIL / Not run
Android smoke: PASS / FAIL / Not run
Confirmed by: Project Owner
Date: ...
```

`Not run` blocks closure.

---

# 28. Previous-Stage Regression Review

Closure must confirm no unresolved regression in:

- Stage 1 authentication/session;
- Stage 2 Platform Owner;
- Stage 3 Institution Admin/settings;
- Stage 4 Group/membership/parent relationship;
- Stage 5 Topic/Learning Material workflows.

High-risk shared changes to inspect:

```text
backend/routes/api.php
Topic lifecycle Actions
InstitutionLessonAt / shared Institution datetime parser
User/Institution/Topic relationships
frontend app_router.dart
frontend app_route_paths.dart
frontend ApiErrorCodes
frontend InstitutionTimezone
TeacherTopicDetailScreen
Teacher Topic lifecycle controller/data source
```

Phase 2 full suites are the broad regression evidence.

Integration provides the final Stage 6 vertical evidence.

---

# 29. Architecture Closure Review

Required PASS:

## Backend

```text
Request/Controller
-> Action
-> focused Domain/Support
-> Eloquent/PostgreSQL
```

No business workflow in controllers/models.

## Frontend

```text
Presentation
-> Application/Riverpod
-> Repository
-> Remote data source/DTO
-> configured Dio
```

No Dio/JSON in Widgets.

No second router/state/client architecture.

No speculative generalized Assessment framework introduced without need.

---

# 30. Concurrency Closure Review

Required evidence covers:

- Homework edit vs first Attempt boundary;
- Question mutation vs first Attempt boundary;
- Question add/reorder uniqueness;
- lifecycle same-target concurrency;
- activation vs Topic close/archive;
- activation vs membership removal;
- official designation/replacement vs activation;
- official replacement vs first Attempt;
- one pair row per Topic.

Expected shared serialization principle:

```text
Group
-> Teacher membership
-> Topic
-> Assessment
-> task-specific child locks
```

No unresolved deadlock/data-race finding.

---

# 31. Error Contract Closure Review

Required stable Stage 6 errors are consistently handled:

```text
resource_not_found
validation_failed
business_conflict
topic_not_editable
topic_has_open_assessments
task_not_active
task_closed
task_archived
assessment_has_no_scoreable_points
assessment_not_assigned
deadline_passed
official_task_requires_group_assignment
result_pair_locked
```

Verify:

- correct HTTP category;
- privacy-safe 404;
- no SQL/stack leak;
- frontend branches on machine code;
- frontend does not parse human message for authority.

---

# 32. Documentation Synchronization Review

Before final closure bookkeeping, verify:

- `docs/01–09` reflect the accepted Stage 6 contracts;
- Stage 6 roadmap scope remains coherent;
- result-pair nullable Blitz sequencing is synchronized;
- no docs still describe Teacher/Admin-configurable Homework attempt count;
- no docs accidentally move Student execution into Stage 6;
- no docs imply selected Homework can be official;
- no docs contradict the nine Question types;
- no docs contradict server/UTC deadline authority.

If documentation changes are needed:

- make a focused documentation-only change;
- do not change production behavior;
- `git diff --check`;
- verify affected docs only;
- preserve valid Phase 2/Integration evidence because docs-only alignment does not alter runtime behavior.

---

# 33. Stage 6 Task/Bookkeeping Synchronization

Final closure package must synchronize actual status.

Expected bookkeeping surfaces:

```text
tasks/STAGE_06_CLOSURE_REVIEW.md
tasks/STAGE_06_TASK_INDEX.md
tasks/README.md
tasks/integration/stage-06/S06-INT-001-stage-06-homework-authoring-real-stack-e2e.md
```

and, if the project stores checkpoint final evidence in their contract files:

```text
tasks/backend/stage-06/S06-BE-PHASE-2-backend-block-review.md
tasks/frontend/stage-06/S06-FE-PHASE-2-frontend-block-review.md
```

Do not rewrite implementation task histories inaccurately.

Do not mark tasks Accepted/Delivered without actual delivery evidence.

---

# 34. Closure Delivery Scope

The final closure delivery must be documentation/bookkeeping only.

Expected possible files:

```text
tasks/STAGE_06_CLOSURE_REVIEW.md
tasks/STAGE_06_TASK_INDEX.md
tasks/README.md
tasks/integration/stage-06/S06-INT-001-stage-06-homework-authoring-real-stack-e2e.md
tasks/backend/stage-06/S06-BE-PHASE-2-backend-block-review.md
tasks/frontend/stage-06/S06-FE-PHASE-2-frontend-block-review.md
```

plus only the focused `docs/01–09` files that need Stage 6 contract synchronization.

No closure-time changes to:

```text
backend/app/**
backend/routes/**
backend/database/migrations/**
frontend/lib/**
frontend/android/**
frontend/windows/**
pubspec.yaml
pubspec.lock
composer.*
```

unless closure first fails and a separately approved production fix is completed before the final closure audit.

---

# 35. Closure Bookkeeping Verification

After preparing the closure/documentation package, before merge:

```bash
git diff --check
git diff --name-only
git status --short
```

Review every changed file.

Required:

- no production code;
- no test weakening;
- no secret;
- no generated file;
- no unrelated formatting;
- only approved documentation/bookkeeping.

No broad backend/frontend/E2E rerun is required for docs-only closure changes when existing evidence remains valid.

---

# 36. Final Repository State

Before formal final verdict/delivery:

| Check | Required |
|---|---|
| `origin/main` | final accepted Stage 6 implementation + evidence |
| local `main` | same as `origin/main` |
| ahead/behind | `0/0` |
| working tree | clean |
| unexpected files | none |
| open production PR/fix required | none |
| unresolved findings | none |

After closure PR merge:

1. switch/update local `main`;
2. fetch origin;
3. verify local `main == origin/main`;
4. ahead/behind `0/0`;
5. working tree clean;
6. closure commit is ancestor of `origin/main`.

Only then is formal repository closure complete.

---

# 37. Findings

Closure findings use:

```text
P1 — critical/security/cross-tenant/historical corruption
P2 — major product/API/lifecycle/integration/Stage-boundary failure
P3 — minor actionable quality/documentation inconsistency
```

Final closure requires:

```text
P1 = 0
P2 = 0
P3 = 0
```

Known planning-baseline documentation drift from Section 15 is not allowed to remain as an unresolved P3 at final closure.

---

# 38. Closure Review Output Format

At execution, produce:

## Git state

```text
origin/main:
local main:
ahead/behind:
worktree:
```

## Task delivery

```text
S06-BE-001…006
Backend Phase 2
S06-FE-001…004
Frontend Phase 2
S06-INT-001
```

with exact PR/merge evidence.

## Roadmap

Report:

```text
Stage 6 Goal: PASS/FAIL
Acceptance Criterion: PASS/FAIL
Required Tests: PASS/FAIL matrix
```

## Evidence validity

Report whether:

- Backend Phase 2;
- Frontend Phase 2;
- Integration;
- Windows smoke;
- Android smoke

remain valid for final production head.

## Documentation

Report:

```text
docs/01–09 alignment: PASS/FAIL
staged result pair docs: PASS/FAIL
```

## Findings

```text
P1 = N
P2 = N
P3 = N
```

## Verdict

One of:

```text
STAGE CLOSED
NOT CLOSED
BLOCKED
```

---

# 39. Final `STAGE CLOSED` Gate

Use:

```text
STAGE CLOSED
```

only if all are true:

- Stage 5 was closed;
- Stage 6 approved decomposition is fully accounted for;
- S06-DOC-001 Accepted / Delivered;
- all six backend tasks Accepted/Delivered;
- Backend Phase 2 PASS;
- all four frontend tasks Accepted/Delivered;
- Frontend Phase 2 PASS;
- S06-INT-001 Accepted/Delivered/PASS;
- Windows automated real-stack PASS;
- all-nine Question matrix PASS;
- security/Tenant matrix PASS;
- DB oracle PASS;
- backend-restart persistence PASS;
- Windows manual smoke PASS;
- Android real-stack smoke PASS;
- fixed 3-attempt contract intact;
- server-authoritative deadline/timezone intact;
- editing integrity intact;
- Topic lifecycle integration intact;
- official whole-group Homework rule intact;
- selected Homework practice-only;
- staged pair with nullable Blitz intact;
- no fake Blitz;
- no fake Student Attempts;
- Stage 7 boundary intact;
- Stage 8 null-to-Blitz completion path intact;
- previous-stage regressions cleared;
- docs synchronized;
- task bookkeeping synchronized;
- final Git state clean/synchronized;
- no unresolved P1/P2/P3.

Otherwise:

```text
NOT CLOSED
```

or:

```text
BLOCKED
```

with exact reason.

---

# 40. Closure Verdict Template

If everything passes:

```text
STAGE CLOSED

Stage 6 — Homework Assignment Management satisfies its roadmap acceptance
criterion and Definition of Done.

Backend Phase 2: PASS
Frontend Phase 2: PASS
S06-INT-001: PASS
Windows smoke: PASS
Android smoke: PASS
Security/Tenant isolation: PASS
Nine Question types: PASS
Homework lifecycle: PASS
Official Homework/staged result pair: PASS
Documentation alignment: PASS

P1 = 0
P2 = 0
P3 = 0
```

Do not populate this template with PASS values until actual evidence exists.

---

# 41. Next Stage

After closure bookkeeping is merged and final Git synchronization passes, the next permitted gate is:

```text
Stage 7 — Student Homework and Submission Flow
planning and decomposition
```

A new Stage 7 chat must recover current project state from GitHub `main`.

Do not begin Stage 7 implementation from this planning baseline or from memory.

---

# 42. Planning Provenance

For ChatGPT/reviewer traceability:

| Source | Closure requirement encoded |
|---|---|
| `docs/06-roadmap.md` Stage 6 | Goal, included scope, required tests, acceptance criterion |
| Stage 6 approved decomposition | BE-001…006, Backend Phase 2, FE-001…004, Frontend Phase 2, INT-001 |
| S06-BE-001…006 contracts | Persistence/API/lifecycle/security/staged-pair contracts |
| S06-FE-001…004 contracts | Read/authoring/Question/lifecycle/official UX contracts |
| S06-INT-001 contract | Real-stack, tenant/security, persistence, manual smoke |
| Closure template | Read-only closure + evidence-validity + bookkeeping discipline |
| Stage 5 closure pattern | Reuse valid checkpoint/integration evidence; closure delivery remains documentation-only |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |

At actual closure, ChatGPT must re-read the **current** GitHub main and current accepted evidence. This provenance table is not a substitute for that re-check.
