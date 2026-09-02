# Stage 6 Task Index — Homework Assignment Management

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `Stage 6 — Homework Assignment Management` |
| Stage status | `In Progress — backend implementation in progress` |
| Verification model | `Workflow v3 — Lean Verification` |
| Decomposition status | `Approved / Delivered` |
| Planning baseline `origin/main` | `d1678b42009287a56c0b31a053e54109406feb8b` |
| Previous Stage | `Stage 5 — Closed` |
| Documentation alignment | `S06-DOC-001 Accepted / Delivered — PR #141, merge a90c9e9697e5e2b7eda332ec9497bd524f008776` |
| Backend implementation | `In Progress — S06-BE-001, S06-BE-002, and S06-BE-003 Accepted / Delivered` |
| Backend checkpoint | `Approved — Pending execution` |
| Frontend implementation | `Not started` |
| Frontend checkpoint | `Approved — Pending execution` |
| Integration gate | `Approved — Pending execution` |
| Stage Closure Review | `Approved — Pending execution` |
| Next permitted implementation gate | `S06-BE-004 — Teacher Question Mutation & Editing Integrity` |

This index is the authoritative Stage 6 implementation map after the approved
planning package is delivered to `origin/main`.

The task contracts were prepared during Stage 6 planning before implementation.

Current planning meaning:

```text
Approved
```

means:

- ChatGPT completed requirements/architecture/API/database/security/lifecycle
  decisions for that task;
- the implementation contract passed the Implementation Readiness Gate;
- the contract is approved for future execution in dependency order.

`Approved` does **not** mean:

- implemented;
- accepted;
- delivered;
- merged;
- verified by Phase 2;
- integrated.

At the planning baseline, no Stage 6 production implementation has started.

---

## 2. Stage Goal

Roadmap goal:

> Allow Teachers to build structured homework connected to a topic.

Stage 6 produces the Teacher-side Homework authoring foundation that later
Student Homework execution will use.

The intended Stage 6 vertical is:

```text
authorized Teacher
→ authorized Topic / Group
→ Homework draft
→ Group or selected-Student assignment
→ typed Questions
→ authoritative points
→ optional Institution-timezone deadline
→ Homework activation
→ recipient snapshot
→ official Homework designation
→ lifecycle / historical preservation
```

Student Attempt execution is **not** part of Stage 6.

---

## 3. Roadmap Acceptance Boundary

Authoritative acceptance criterion:

> A Teacher can create a valid active homework assignment using every supported
> MVP question type without violating topic, group, or institution boundaries.

Stage 6 therefore must prove:

- Teacher ownership and current Group authorization;
- whole-group and selected-Student assignment;
- all nine Question types;
- valid points/configuration;
- fixed three-attempt Homework policy;
- Institution-timezone deadline handling;
- lifecycle integrity;
- scoring-content lock after activity;
- official whole-group Homework designation;
- Tenant isolation;
- desktop authoring and mobile read boundary;
- real-stack persistence/integration.

---

## 4. Included Stage Boundary

### Backend / persistence

Stage 6 includes:

- generic Assessment structural foundation needed by Homework and future Blitz;
- Homework persistence;
- Homework recipient persistence;
- structural Homework Attempt persistence needed for editing/lock readiness;
- Topic result-pair persistence;
- normalized typed Question persistence;
- exact Question configuration validation;
- exact server-derived Assessment total points;
- Teacher eligible Student roster;
- Teacher Homework list/create/detail/update;
- Question add/update/delete/reorder;
- Homework activation/close/archive;
- activation recipient snapshot;
- Topic lifecycle open-Homework guard;
- official Homework designation;
- staged Topic result-pair API;
- concurrency/idempotency/tenant constraints.

### Frontend

Stage 6 includes:

- Teacher Homework list/detail read surfaces;
- desktop Homework create/edit;
- selected-Student picker;
- Institution-timezone deadline input/display;
- fixed three-attempt read-only policy;
- all-nine Question Builder;
- Question add/edit/delete/reorder;
- desktop Homework lifecycle;
- official Homework designation UX;
- official Homework read state on desktop/mobile;
- mobile Homework read-only capability.

### Integration

Stage 6 includes:

- guarded real Laravel/PostgreSQL runtime;
- deterministic Stage 6 fixtures;
- real Windows Flutter authoring vertical;
- all-nine Question E2E;
- security/Tenant matrix;
- independent PostgreSQL oracle;
- backend restart persistence;
- Windows manual smoke;
- Android Teacher read-only smoke.

---

## 5. Explicit Excluded Stage Boundary

Stage 6 does **not** implement:

- public Student Homework Attempt start;
- Student answer save;
- Student final submit;
- Student file-answer upload;
- automatic answer execution/scoring;
- manual Teacher grading;
- official Homework score selection;
- Blitz authoring;
- Blitz attempts/timing;
- official Blitz designation;
- Homework–Blitz comparison;
- Topic final score;
- understanding category calculation;
- Student/Parent result release;
- notifications;
- AI/fuzzy answer checking;
- configurable Homework attempt count;
- arbitrary client status assignment;
- destructive deletion of historical activity;
- mobile Teacher Homework authoring.

Structural `assessment_attempts` rows are allowed only as persistence/integrity
foundation until Stage 7.

---

## 6. Approved Core Business Rules

### 6.1 Homework attempts

Every assigned Student receives exactly:

```text
3 normal Homework attempts
```

The count is fixed.

It cannot be changed by:

- Institution Admin;
- Teacher;
- frontend;
- create/update API.

Future official Homework score:

```text
highest valid completed score among the three attempts
```

Actual Student attempt execution belongs to Stage 7.

### 6.2 Homework lifecycle

Exact lifecycle:

```text
draft -> active
draft -> archived
active -> closed
closed -> archived
archived -> terminal
```

No reopen.

No implicit:

```text
active -> archived
```

Same-target lifecycle calls are idempotent.

### 6.3 Deadline

- optional;
- Teacher enters Institution-local wall clock;
- Flutter sends explicit RFC3339 numeric offset;
- backend validates against Institution IANA timezone;
- backend persists UTC;
- server time is authoritative;
- draft may store a past deadline;
- activation requires:
  `deadline_at > server now`;
- device time cannot extend the deadline.

### 6.4 Editing integrity

Before Student activity, scoring-relevant content may be changed while the
Homework lifecycle permits it.

After any Assessment Attempt exists:

- Question scoring content is locked;
- recipient/scoring-relevant Homework changes are locked;
- safe metadata behavior follows the approved backend contract;
- no historical scoring meaning may be silently rewritten.

### 6.5 Historical preservation

Homework with activity is not destructively deleted.

Lifecycle uses:

```text
closed
archived
```

and preserves historical rows.

---

## 7. Nine Supported Question Types

Exactly:

1. `single_choice`
2. `multiple_choice`
3. `true_false`
4. `short_written`
5. `open_written`
6. `file_based`
7. `matching`
8. `ordering`
9. `fill_in_blank`

### Single Choice

- at least 2 options;
- exactly 1 correct;
- automatic.

### Multiple Choice

- at least 2 options;
- at least 1 correct;
- automatic;
- max selections derived from correct-option count;
- future approved partial-credit rule;
- no negative points.

### True / False

- one Boolean correct answer;
- automatic.

### Short Written

Modes:

```text
automatic
manual
```

Automatic:

- accepted answers required;
- deterministic exact normalization belongs to backend Student checking later;
- no fuzzy/semantic/AI equality.

Manual:

- no machine answer key required.

### Open Written

- manual only.

### File Based

- manual only;
- supported Student file types contract:
  `PDF`, `DOCX`, `PPT`, `PPTX`;
- actual Student upload belongs Stage 7.

### Matching

- valid semantic pairs;
- normalized persistence;
- future partial credit by correct pair.

### Ordering

- at least 2 items;
- explicit correct order;
- future partial credit by exact position.

### Fill in the Blank

- one or more blanks;
- each blank has accepted answers;
- exact prompt placeholder mapping:
  `{{blank_key}}`;
- future partial credit by blank.

---

## 8. Question Authoring Limits

Approved fixed limits:

```text
max Questions per Assessment       = 100
Question prompt                    = 10,000 chars
Question instructions              = 5,000 chars

Choice options                     = 20
Choice option text                 = 2,000 chars

Short accepted answers             = 20
Accepted answer text               = 1,000 chars

Matching pairs                     = 50
Matching item text                 = 2,000 chars
Matching request client key        = 80 chars

Ordering items                     = 50
Ordering item text                 = 2,000 chars

Fill blanks                        = 50
Accepted answers per blank         = 20
```

Question positions are canonical:

```text
1..N
```

New FE-003 Question creation appends at:

```text
N + 1
```

Global ordering changes use the dedicated reorder API.

---

## 9. Assignment and Recipient Rules

### Group assignment

Draft:

- does not create recipient snapshot.

Activation:

- snapshots exactly current eligible Students in the Topic Group.

Eligible Student:

```text
same Institution
role = Student
is_active = true
current GroupStudentMembership
ended_at = null
```

At least one recipient required.

Later Group membership changes do not rewrite the active snapshot.

### Selected Students

Draft stores the selected direct recipient set.

Each Student must be currently eligible.

Activation revalidates the exact selected set.

If one becomes ineligible:

- activation rejects;
- Student is not silently dropped.

Selected-Student Homework is:

```text
practice-only
```

and cannot become official.

---

## 10. Official Homework / Staged Result Pair

A Topic may contain multiple Homework tasks.

Exactly one whole-group Homework may be the official result-bearing Homework.

Selected-Student Homework cannot be official.

### Stage 6 staged pair

Approved Stage 6 persistence/API state:

```text
homework_assessment_id = NOT NULL
blitz_assessment_id    = NULL until Stage 8
```

No fake/placeholder Blitz.

One Topic result-pair row is reused later.

### Official cohort

When the official Homework recipient snapshot exists, that persisted Student set
is the official Topic cohort.

Current Group membership does not rewrite the historical official cohort.

### Lock

The Homework side / official meaning becomes immutable when official Student
activity begins.

Stage 7 first official Homework Attempt must set:

```text
locked_at
```

before inserting the first Attempt.

### Stage 8 completion

Stage 8 may later fill:

```text
blitz_assessment_id: null -> official Blitz UUID
```

in the same pair row even when:

```text
locked_at != null
```

because this is pair completion, not Homework replacement.

---

## 11. Mandatory Planning Documentation Alignment Gate

At the Stage 6 planning baseline, the locked documentation contained an older
result-pair sequencing assumption.

In particular, `docs/08-database.md` described:

```text
topic_result_pairs.blitz_assessment_id
```

as non-nullable.

That conflicted with the approved Stage 6 sequencing above.

`S06-DOC-001` resolved the contradiction and synchronized the affected
product/technical documentation for Stage 6 implementation. The alignment was
delivered through PR #141 and merge
`a90c9e9697e5e2b7eda332ec9497bd524f008776`.

The delivered alignment re-checked:

```text
docs/02-user-roles.md
docs/04-user-flows.md
docs/05-business-rules.md
docs/06-roadmap.md
docs/07-architecture.md
docs/08-database.md
docs/09-api-contracts.md
```

Required alignment:

- official Homework may be designated before official Blitz exists;
- one partial pair row is valid;
- `blitz_assessment_id` nullable until Stage 8;
- no fake Blitz;
- official cohort semantics remain coherent;
- Homework side locks after first official Homework activity;
- Stage 8 may fill null Blitz without replacing locked Homework.

This is a planning/documentation alignment, not a new implementation task.

Codex must not decide this contract from docs.

---

## 12. Stage Entry Gate

Before `S06-BE-001` implementation:

- [x] Stage 5 is explicitly closed.
- [x] Stage 5 Topic/Learning Material implementation is stable.
- [x] Stage 4 Teacher/Student Group membership graph is available.
- [x] Stage 6 roadmap scope was analyzed.
- [x] Stage 6 decomposition was approved.
- [x] Backend task decomposition is approved.
- [x] Frontend task decomposition is approved.
- [x] Backend Phase 2 contract is prepared.
- [x] Frontend Phase 2 contract is prepared.
- [x] Integration contract is prepared.
- [x] Closure contract is prepared.
- [x] All Stage 6 implementation task contracts pass planning Readiness Gate.
- [x] Stage 6 planning/task package is delivered to `origin/main`.
- [x] Required Stage 6 documentation alignment from Section 11 is delivered.
- [x] Project Owner confirms clean synchronized local `main`.
- [x] ChatGPT re-checks current `origin/main` after delivery.
- [x] ChatGPT confirms `S06-BE-001` is still the next permitted implementation task.

If any unchecked required entry condition remains, production implementation
must not begin.

---

## 13. Approved Task Order

Implementation proceeds in exact dependency order.

| Order | Task ID | Area | Short outcome | Depends on | Contract status | Delivery status | Contract file |
|---:|---|---|---|---|---|---|---|
| 0 | `S06-DOC-001` | Documentation | Stage 6 Homework & staged result-pair contract alignment | Stage 6 decomposition approved | `Accepted` | `Delivered` | `tasks/S06-DOC-001-stage-06-contract-alignment.md` |
| 1 | `S06-BE-001` | Backend | Assessment & Homework Persistence Foundation | Stage 5 closed + Stage 6 docs alignment | `Accepted` | `Delivered — PR #143, merge ab9c826b626891d119d5c8f674dff212ebe7a806` | `tasks/backend/stage-06/S06-BE-001-assessment-homework-persistence-foundation.md` |
| 2 | `S06-BE-002` | Backend | Typed Question Persistence & Domain Contracts | `S06-BE-001 Accepted / Delivered` | `Accepted` | `Delivered — PR #145, merge b85fc01604d7326104988d1cd3ffd3117c2eece5` | `tasks/backend/stage-06/S06-BE-002-typed-question-persistence-domain-contracts.md` |
| 3 | `S06-BE-003` | Backend | Teacher Homework Authoring & Recipient Discovery API | `S06-BE-001` + `S06-BE-002` Accepted / Delivered | `Accepted` | `Delivered — PR #147, merge 503f5702b7db536610b2772f2940f32028f8f4af` | `tasks/backend/stage-06/S06-BE-003-teacher-homework-authoring-recipient-discovery-api.md` |
| 4 | `S06-BE-004` | Backend | Teacher Question Mutation & Editing Integrity | `S06-BE-001…003 Accepted / Delivered` | `Approved` | `Not delivered` | `tasks/backend/stage-06/S06-BE-004-teacher-question-mutation-editing-integrity.md` |
| 5 | `S06-BE-005` | Backend | Homework Lifecycle, Recipient Snapshot & Topic Integration | `S06-BE-001…004 Accepted / Delivered` | `Approved` | `Not delivered` | `tasks/backend/stage-06/S06-BE-005-homework-lifecycle-recipient-snapshot-topic-integration.md` |
| 6 | `S06-BE-006` | Backend | Official Homework Designation & Staged Result Pair | `S06-BE-001…005 Accepted / Delivered` | `Approved` | `Not delivered` | `tasks/backend/stage-06/S06-BE-006-official-homework-designation-staged-result-pair.md` |
| 7 | `S06-FE-001` | Frontend | Homework Client Domain, Read Surfaces & Routing | Backend Phase 2 `PASS` | `Approved` | `Not delivered` | `tasks/frontend/stage-06/S06-FE-001-homework-client-domain-read-surfaces-routing.md` |
| 8 | `S06-FE-002` | Frontend | Homework Draft Builder: Metadata, Assignment & Deadline | `S06-FE-001 Accepted / Delivered` | `Approved` | `Not delivered` | `tasks/frontend/stage-06/S06-FE-002-homework-draft-builder-metadata-assignment-deadline.md` |
| 9 | `S06-FE-003` | Frontend | Nine-Type Question Builder | `S06-FE-001` + `S06-FE-002 Accepted / Delivered` | `Approved` | `Not delivered` | `tasks/frontend/stage-06/S06-FE-003-nine-type-question-builder.md` |
| 10 | `S06-FE-004` | Frontend | Homework Lifecycle & Official Designation UX | `S06-FE-001…003 Accepted / Delivered` | `Approved` | `Not delivered` | `tasks/frontend/stage-06/S06-FE-004-homework-lifecycle-official-designation-ux.md` |
| 11 | `S06-INT-001` | Integration | Stage 6 Homework Authoring Real-Stack E2E | Backend Phase 2 `PASS` + Frontend Phase 2 `PASS` | `Approved` | `Not delivered` | `tasks/integration/stage-06/S06-INT-001-stage-06-homework-authoring-real-stack-e2e.md` |

No duplicate `CODEX-PROMPT` files are used.

Each detailed task file is the Codex implementation contract.

---

## 14. Backend Block Mapping

### `S06-BE-001` — Assessment & Homework Persistence Foundation

Owns:

- Assessment generic structural table;
- Homework lifecycle table;
- recipients;
- structural Attempts;
- Topic result pair;
- enums/models/factories/constraints.

Does not own:

- Question tables;
- public API;
- Student Attempt API.

### `S06-BE-002` — Typed Question Persistence & Domain Contracts

Owns:

- normalized Question tables;
- exact nine types;
- type/checking compatibility;
- authoring limits;
- pure configuration validation;
- canonical positions.

Does not own public Teacher API.

### `S06-BE-003` — Teacher Homework Authoring & Recipient Discovery API

Owns:

- Teacher Group Student roster;
- Homework list/create/detail/update;
- strict metadata/assignment/deadline contract;
- selected Student validation;
- exact point math;
- full Teacher Question read resource.

Does not own lifecycle or dedicated Question mutations.

### `S06-BE-004` — Teacher Question Mutation & Editing Integrity

Owns:

- add Question;
- update Question;
- delete Question;
- reorder;
- exact aggregate total recalculation;
- scoring-content activity lock;
- result-pair defensive lock;
- concurrency with future first Attempt.

### `S06-BE-005` — Homework Lifecycle, Recipient Snapshot & Topic Integration

Owns:

- activate;
- close;
- archive;
- activation validation;
- deadline enforcement;
- Group recipient snapshot;
- selected-recipient revalidation;
- Topic close/archive open-Homework guard;
- Stage 6 in-progress close guard.

### `S06-BE-006` — Official Homework Designation & Staged Result Pair

Owns:

- GET Topic result pair;
- PUT official Homework;
- whole-group-only official rule;
- active candidate cohort adoption;
- designated-draft activation cohort integration;
- pre-lock replacement;
- lock/integrity behavior;
- staged null Blitz contract.

---

## 15. Backend Phase 2 Checkpoint

Contract:

```text
tasks/backend/stage-06/S06-BE-PHASE-2-backend-block-review.md
```

Status:

```text
Approved — Pending execution
```

Entry gate:

```text
S06-BE-001…006 = Accepted / Delivered
```

Required final verification:

- full backend regression suite;
- Pint;
- Stage-wide `git diff --check`;
- architecture review;
- persistence/schema review;
- authorization/Tenant review;
- all-nine Question review;
- lifecycle/recipient/deadline review;
- result-pair review;
- concurrency/lock-order review;
- Stage 7 compatibility;
- Stage 8 compatibility.

Final PASS requires:

```text
P1 = 0
P2 = 0
P3 = 0
```

Frontend implementation is prohibited until this checkpoint passes.

---

## 16. Frontend Block Mapping

### `S06-FE-001` — Homework Client Domain, Read Surfaces & Routing

Owns:

- strict typed Homework/Question DTO/domain;
- Teacher roster client;
- Homework list/detail reads;
- Homework section in Topic detail;
- read-only nested route;
- desktop/mobile read behavior.

No authoring controls.

### `S06-FE-002` — Homework Draft Builder: Metadata, Assignment & Deadline

Owns:

- desktop Homework create/edit;
- metadata form;
- Group/selected assignment;
- selected Student picker;
- deadline input;
- fixed attempt read-only UX;
- safe mutation uncertainty/reconciliation.

Creates draft with:

```text
questions = []
```

### `S06-FE-003` — Nine-Type Question Builder

Owns:

- desktop Question Builder route;
- all nine typed forms;
- add/edit/delete;
- staged reorder;
- exact request serialization;
- server lock/conflict handling;
- mutation reconciliation.

### `S06-FE-004` — Homework Lifecycle & Official Designation UX

Owns:

- desktop activate/close/archive;
- official result-pair read;
- Official badge on desktop/mobile;
- desktop Set/Replace official;
- lifecycle/designation reconciliation;
- Topic `topic_has_open_assessments` frontend integration.

---

## 17. Frontend Phase 2 Checkpoint

Contract:

```text
tasks/frontend/stage-06/S06-FE-PHASE-2-frontend-block-review.md
```

Status:

```text
Approved — Pending execution
```

Entry gate:

```text
S06-FE-001…004 = Accepted / Delivered
Backend Phase 2 = PASS
```

Required:

- full frontend test suite;
- full `flutter analyze`;
- full format verification;
- Windows debug build;
- Android debug build;
- Stage-wide `git diff --check`;
- architecture/API/session review;
- route/mobile capability review;
- all-nine Question Builder review;
- mutation uncertainty review;
- lifecycle/result-pair review;
- previous-stage regression review.

Final PASS:

```text
P1 = 0
P2 = 0
P3 = 0
```

Integration is prohibited until this checkpoint passes.

---

## 18. Integration Gate

Task:

```text
S06-INT-001 — Stage 6 Homework Authoring Real-Stack E2E
```

Contract:

```text
tasks/integration/stage-06/S06-INT-001-stage-06-homework-authoring-real-stack-e2e.md
```

Status:

```text
Approved — Pending execution
```

Entry:

```text
Backend Phase 2 = PASS
Frontend Phase 2 = PASS
```

Required integrated evidence:

- guarded dedicated Stage 6 Laravel/PostgreSQL runtime;
- deterministic seeder;
- real Teacher Windows login;
- whole-group Homework;
- selected practice Homework;
- all nine Question types;
- Question update/delete/reorder;
- server total-points oracle;
- official designation;
- activation recipient/cohort snapshot;
- Topic close conflict;
- close/archive;
- cross-Tenant/wrong-role security;
- locked pair with `blitz = null`;
- Stage 6 in-progress close guard;
- no fake Attempts/Blitz;
- backend restart persistence;
- Windows manual smoke;
- Android read-only Teacher smoke.

Final Integration PASS requires:

```text
P1 = 0
P2 = 0
P3 = 0
```

---

## 19. Stage Closure Gate

Closure contract:

```text
tasks/STAGE_06_CLOSURE_REVIEW.md
```

Status:

```text
Approved — Pending execution
```

Stage Closure Review begins only after:

```text
S06-BE-001…006 Accepted / Delivered
Backend Phase 2 PASS
S06-FE-001…004 Accepted / Delivered
Frontend Phase 2 PASS
S06-INT-001 Accepted / Delivered / PASS
Windows smoke PASS
Android smoke PASS
all required production fixes delivered
all documentation contracts synchronized
current Git state clean/synchronized
```

Closure reuses still-valid verification evidence under Workflow v3.

No broad suite/build/E2E rerun merely because closure starts.

Final:

```text
STAGE CLOSED
```

requires:

```text
P1 = 0
P2 = 0
P3 = 0
```

---

## 20. Dependency / Gate Matrix

| Completed gate | Unlocks | Current planning status |
|---|---|---|
| Stage 5 closure | Stage 6 planning | `PASS` |
| Stage 6 decomposition approved | Stage 6 task-contract preparation | `PASS` |
| All Stage 6 task/checkpoint/integration/closure contracts prepared | planning package delivery | `PASS` |
| `S06-DOC-001 Accepted / Delivered` + planning package delivered | `S06-BE-001` implementation | `PASS — completed` |
| `S06-BE-001 Accepted / Delivered` | `S06-BE-002` | `PASS — unlocked` |
| `S06-BE-002 Accepted / Delivered` | `S06-BE-003` | `PASS — unlocked` |
| `S06-BE-003 Accepted / Delivered` | `S06-BE-004` | `PASS — unlocked` |
| `S06-BE-004 Accepted / Delivered` | `S06-BE-005` | `Pending` |
| `S06-BE-005 Accepted / Delivered` | `S06-BE-006` | `Pending` |
| `S06-BE-006 Accepted / Delivered` | Backend Phase 2 | `Pending` |
| Backend Phase 2 `PASS` | `S06-FE-001` | `Pending` |
| `S06-FE-001 Accepted / Delivered` | `S06-FE-002` | `Pending` |
| `S06-FE-002 Accepted / Delivered` | `S06-FE-003` | `Pending` |
| `S06-FE-003 Accepted / Delivered` | `S06-FE-004` | `Pending` |
| `S06-FE-004 Accepted / Delivered` | Frontend Phase 2 | `Pending` |
| Frontend Phase 2 `PASS` | `S06-INT-001` | `Pending` |
| `S06-INT-001 PASS` + delivery/smoke | Closure Review | `Pending` |
| Closure `STAGE CLOSED` | Stage 7 planning | `Pending` |

---

## 21. Implementation Readiness Rule

Before every task execution, ChatGPT must re-check:

```text
current GitHub origin/main
dependency delivery state
relevant production source
relevant tests
final accepted backend/frontend contract
```

The planning SHA in a task file is historical planning evidence only.

It is not permission for Codex to implement against stale source.

ChatGPT freezes the current implementation baseline immediately before the task
is given to Codex.

---

## 22. Codex Context Rule

For each implementation task, Codex receives only:

1. the current approved task contract;
2. root `AGENTS.md`;
3. applicable backend/frontend `AGENTS.md`;
4. directly relevant existing source/tests.

Codex must not read:

- product docs;
- roadmap;
- architecture/database/API docs;
- previous Stage tasks;
- previous Stage history;
- Stage index;
- checkpoint review;
- closure review

to decide what to implement.

Those are ChatGPT planning/review inputs.

---

## 23. Per-Task Verification Policy

Each implementation task runs only proportional focused verification:

- focused changed-feature tests;
- required format/static checks;
- directly affected regression tests;
- `git diff --check`;
- focused scope/diff review.

Do not run after every task:

- full backend suite;
- full frontend suite;
- full builds;
- broad E2E

unless a concrete task-specific regression risk justifies it.

Broad evidence is concentrated at:

- Backend Phase 2;
- Frontend Phase 2;
- Integration.

---

## 24. Delivery Policy

Codex does not:

- commit;
- push;
- open PR;
- merge;
- update task bookkeeping.

Project Owner owns routine Git/GitHub delivery.

A task becomes:

```text
Accepted / Delivered
```

only after:

- implementation/review passes;
- approved delivery is merged to `origin/main`;
- local `main == origin/main`;
- ahead/behind `0/0`;
- working tree clean.

Only then can the dependent task execute.

---

## 25. Backend Security / Tenant Requirements

Every Stage 6 Teacher operation must preserve:

- authenticated Teacher role;
- active user;
- active Institution;
- same Institution;
- Teacher owns/has approved Topic relation;
- current Teacher–Group membership;
- privacy-safe direct UUID resolution;
- selected Student same Institution/current Group/active status;
- no client-controlled Institution/Teacher scope;
- no foreign resource existence leak.

Foreign/unrelated direct UUID should normally produce:

```text
404 resource_not_found
```

according to the task-specific contract.

Cross-Institution access is a closure-blocking P1.

---

## 26. Frontend Security / State Requirements

Frontend must preserve:

- backend authority;
- no client ownership inference;
- no client lifecycle authority;
- no client attempt-count override;
- no raw Student UUID display;
- no raw Matching server-key mutation authority;
- no device-time deadline authority;
- no automatic mutation replay;
- stale async session/route/target protection;
- desktop-only Stage 6 authoring;
- mobile read-only Stage 6 behavior.

Hidden UI is not authorization.

---

## 27. Concurrency / Idempotency Map

Critical Stage 6 interactions:

```text
Homework metadata update
vs first Attempt

Question mutation
vs first Attempt

Question add/reorder
vs position uniqueness

Homework activation
vs Topic close/archive

Homework activation
vs Student membership removal/deactivation

official designation/replacement
vs Homework activation

official replacement
vs first Attempt

same-target lifecycle
vs concurrent same-target lifecycle

concurrent initial Topic result-pair PUT
```

The Assessment row is a major serialization boundary for scoring-content
integrity.

The Topic row is a major parent serialization boundary for Topic/Homework
lifecycle and official relationship integrity.

---

## 28. Stage 7 Forward Contract

Stage 7 starts only after Stage 6 closes.

Stage 6 must leave exact forward readiness for:

- assigned Student Homework list/detail;
- fixed three normal Attempts;
- first Attempt creation;
- answer persistence;
- deadline enforcement;
- close/deadline auto-finalization;
- manual-review waiting state;
- official Homework first-Attempt pair lock.

Stage 7 must not need to redesign Stage 6 Homework authoring contracts merely to
start Student execution.

---

## 29. Stage 8 Forward Contract

Stage 8 later implements Blitz.

Stage 6 must leave:

```text
topic_result_pairs.blitz_assessment_id = null
```

as a valid state.

Stage 8 fills the same row.

It does not replace the locked Homework side.

The official cohort is reused.

No second result-pair structure is allowed.

---

## 30. Planning Artifact Inventory

Prepared Stage 6 planning files:

### Stage-wide documentation

```text
S06-DOC-001-stage-06-contract-alignment.md
```

### Backend

```text
S06-BE-001-assessment-homework-persistence-foundation.md
S06-BE-002-typed-question-persistence-domain-contracts.md
S06-BE-003-teacher-homework-authoring-recipient-discovery-api.md
S06-BE-004-teacher-question-mutation-editing-integrity.md
S06-BE-005-homework-lifecycle-recipient-snapshot-topic-integration.md
S06-BE-006-official-homework-designation-staged-result-pair.md
S06-BE-PHASE-2-backend-block-review.md
```

### Frontend

```text
S06-FE-001-homework-client-domain-read-surfaces-routing.md
S06-FE-002-homework-draft-builder-metadata-assignment-deadline.md
S06-FE-003-nine-type-question-builder.md
S06-FE-004-homework-lifecycle-official-designation-ux.md
S06-FE-PHASE-2-frontend-block-review.md
```

### Integration / Closure

```text
S06-INT-001-stage-06-homework-authoring-real-stack-e2e.md
STAGE_06_CLOSURE_REVIEW.md
STAGE_06_TASK_INDEX.md
```

The Stage 6 planning package was delivered through PR #140 and merge
`dc4d78c3a8d2072ae44710e433956572c1d011ce`. `S06-DOC-001` was delivered
through PR #141 and merge `a90c9e9697e5e2b7eda332ec9497bd524f008776`.
The remaining implementation, checkpoint, integration, and closure contracts
are delivered planning contracts, but their executions remain pending.

---

## 31. Current Planning Status

Current Stage 6 state:

```text
Stage 6 decomposition: Approved / Delivered

Stage 6 planning package:
Delivered — PR #140, merge dc4d78c3a8d2072ae44710e433956572c1d011ce

S06-DOC-001: Accepted / Delivered — PR #141

S06-BE-001: Accepted / Delivered — PR #143,
merge ab9c826b626891d119d5c8f674dff212ebe7a806
S06-BE-002: Accepted / Delivered — PR #145,
merge b85fc01604d7326104988d1cd3ffd3117c2eece5
S06-BE-003: Accepted / Delivered — PR #147,
merge 503f5702b7db536610b2772f2940f32028f8f4af
S06-BE-004: Approved / Not delivered
S06-BE-005: Approved / Not delivered
S06-BE-006: Approved / Not delivered

Backend Phase 2:
Pending

S06-FE-001: Approved / Not delivered
S06-FE-002: Approved / Not delivered
S06-FE-003: Approved / Not delivered
S06-FE-004: Approved / Not delivered

Frontend Phase 2:
Approved — Pending execution

S06-INT-001:
Approved / Not delivered / Not executed

Stage 6 Closure Review:
Approved — Pending execution

Stage 6:
In Progress — backend implementation in progress

Next permitted gate:
S06-BE-004 — Teacher Question Mutation & Editing Integrity
```

---

## 32. Next Permitted Action

Current implementation sequence:

1. `S06-BE-003` accepted and delivered — PR #147, merge
   `503f5702b7db536610b2772f2940f32028f8f4af`.
2. This bookkeeping must be delivered to `origin/main`.
3. Project Owner synchronizes local `main`.
4. ChatGPT re-checks the new current `origin/main`.
5. ChatGPT re-checks the `S06-BE-004` contract against the delivered
   `S06-BE-001`…`S06-BE-003` implementation and freezes the new `S06-BE-004`
   implementation baseline.
6. Only then execute:

```text
S06-BE-004 — Teacher Question Mutation & Editing Integrity
```

Do not start:

- multiple backend tasks in parallel;
- frontend before Backend Phase 2;
- Integration before both Phase 2 checkpoints;
- Stage 7 before Stage 6 closure.

---

## 33. Final Stage 6 Closure Target

The final desired state is:

```text
S06-BE-001…006 = Accepted / Delivered
Backend Phase 2 = PASS

S06-FE-001…004 = Accepted / Delivered
Frontend Phase 2 = PASS

S06-INT-001 = Accepted / Delivered / PASS

Windows smoke = PASS
Android smoke = PASS

docs = synchronized
P1 = 0
P2 = 0
P3 = 0

Stage 6 Closure Review = STAGE CLOSED
```

Only after that:

```text
Stage 7 — Student Homework and Submission Flow
planning and decomposition
```

becomes permitted.
