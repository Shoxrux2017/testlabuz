# Stage 5 Task Index — Topics and Learning Materials

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `Stage 5 — Topics and Learning Materials` |
| Stage status | `In Progress` |
| Verification model | `Workflow v3 — Lean Verification` |
| Decomposition approved on | `2026-08-22` |
| Planning baseline `origin/main` | `de9a8fee099a2947f6687ee9e6b219e612c93bff` |
| Implementation started | `Yes — S05-BE-001…005 and S05-FE-001…004 Accepted / Delivered` |
| Backend checkpoint | `PASS — audited origin/main @ 999f477f6a281f2266ad4abbded8b0732b5d789c` |
| Frontend checkpoint | `Not started` |
| Integration gate | `Not started` |
| Stage closed | `No` |

This index is the authoritative implementation map for Stage 5 after this
planning package is delivered to `origin/main`.

The `Approved` state records that a detailed implementation contract has passed
the Implementation Readiness Gate and has been approved by the Project Owner.
`Approved` does not mean implemented, accepted, or delivered.

The Stage 5 frontend contracts `S05-FE-001…004` are prepared and approved in
advance as one planning package, but frontend implementation remains strictly
sequential:

```text
S05-FE-001
→ S05-FE-002
→ S05-FE-003
→ S05-FE-004
```

Before each frontend task is given to Codex, ChatGPT must re-check current
`origin/main`, the actual implementation/tests produced by the previous task,
and dependency delivery state, then freeze the current implementation baseline.

Frontend implementation must not start until this frontend planning package is
delivered to `origin/main` and `S05-FE-001` passes that immediate pre-execution
baseline revalidation.

This index organizes approved work but does not create or change product
behavior.


---

## 2. Stage Goal and Boundary

### Goal

Allow Teachers to create the central learning object and provide Students with
approved, protected study resources.

The Stage 5 vertical outcome is:

```text
authorized Teacher
→ assigned Group
→ Topic
→ private Learning Material
→ Topic activation
→ assigned Student access
→ protected file download
```

### Included Stage Boundary

Stage 5 includes:

- Topic persistence and lifecycle foundation;
- Learning Material and private-file persistence foundation;
- Teacher read access to currently assigned active Groups for Topic authoring;
- Teacher Topic list, create, detail, and metadata update;
- Topic lifecycle:
  - `draft → active`;
  - `draft → archived`;
  - `active → closed`;
  - `closed → archived`;
- Learning Material list, upload, replace, title update, remove, open/download;
- approved learning-material formats:
  - PDF;
  - DOCX;
  - PPT;
  - PPTX;
- platform hard maximum of 25 MiB per learning-material file;
- lower Institution-configured learning-material limit;
- private storage with no public storage-key/path authority;
- Student Topic list and detail for currently authorized Group scope;
- Student access to eligible non-draft Topic learning materials;
- protected Learning Material download for authorized Teacher/Student scope;
- Teacher desktop authoring experience;
- Teacher mobile read/basic Topic status experience;
- Student desktop and mobile Topic/material experience;
- server-side role, Institution, Group membership, Topic ownership, lifecycle,
  and file authorization;
- real-stack integration, cross-tenant/direct-ID denial, persistence/restart
  verification, and required Project Owner manual smoke.

### Excluded Stage Boundary

Stage 5 does not implement:

- Homework authoring or Homework lifecycle;
- Homework attempts or Student submissions;
- Blitz authoring, activation, timing, or attempts;
- Question authoring;
- automatic/manual assessment checking;
- official assessment scores;
- Homework–Blitz pairing;
- Topic result calculation;
- understanding-category calculation;
- Student/Parent result release;
- Parent learning-material access;
- Institution Admin learning-content authoring;
- public file URLs;
- client-supplied storage keys/paths;
- full Learning Material version-history UI/API;
- destructive deletion of historical learning records;
- advanced course builders, AI, notifications, chat, billing, or other
  Post-MVP behavior.

Any scope change requires explicit planning approval and an index update. Do not
silently broaden an implementation task.

---

## 3. Authoritative Planning Inputs

ChatGPT prepared and reviewed this Stage using the following planning inputs.

| Source | Exact section/reference | Why it governs Stage 5 |
|---|---|---|
| `docs/05-business-rules.md` | Topic and Learning Material rules (`BR-TOP-*`, `BR-MAT-*`) | Topic ownership, lifecycle, Student visibility, material authorization, file constraints, historical preservation |
| `docs/06-roadmap.md` | `Stage 5 — Topics and Learning Materials` | Stage goal, dependencies, device scope, tests, acceptance boundary |
| `docs/07-architecture.md` | Topic/learning-content aggregate, authorization, file-storage sections | Modular-monolith boundaries, private storage, tenant authorization, backend authority |
| `docs/08-database.md` | `topics`, `files`, `learning_materials`, Institution upload setting | Persistence shape, UUID/tenant integrity, lifecycle timestamps, indexes, file metadata |
| `docs/09-api-contracts.md` | Teacher Groups, Topic APIs, Learning Material APIs, Student Topics, protected download | Public API, resource, lifecycle, validation, upload capability, download authorization |
| `AGENTS.md` | Workflow v3 execution rules | Codex scope, proportional task verification, delivery boundaries |
| `backend/AGENTS.md` | Backend architecture and security rules | HTTP→Action→Domain→Eloquent, strict requests, tenant-first resolution, PostgreSQL integrity |
| `frontend/AGENTS.md` | Flutter feature/layer/state rules | Presentation→Application→Repository→Data, strict DTOs, async ownership, router/session boundaries |
| `tasks/README.md` | Workflow v3 — Lean Verification | Stage/task readiness, block checkpoints, integration, evidence reuse, closure |
| Current `origin/main` planning baseline | `de9a8fee099a2947f6687ee9e6b219e612c93bff` | Authoritative repository state used for decomposition |
| `tasks/STAGE_04_CLOSURE_REVIEW.md` | Stage 4 final verdict | Confirms Stage 4 Group/relationship graph is a closed dependency |

The Stage 5 `docs/09-api-contracts.md` refinement and this index are intended to
be delivered together as one planning/documentation package before
implementation begins.

These sources are planning and review inputs for ChatGPT.

Codex receives only the current approved implementation contract plus applicable
`AGENTS.md` files and directly relevant source/tests. Codex must not open these
planning documents to rediscover or reinterpret product requirements.

---

## 4. Entry Gate

Before `S05-BE-001` implementation begins:

- [x] Stage 4 is explicitly closed.
- [x] Stage 4 current Teacher–Group and Student–Group relationship graph exists.
- [x] Workflow v3 — Lean Verification is delivered on `main`.
- [x] Stage 5 roadmap scope was reviewed by ChatGPT.
- [x] Relevant business, architecture, database, and API contracts were reviewed.
- [x] Relevant backend/frontend implementation and tests were inspected.
- [x] Stage 5 decomposition and task order were discussed with and approved by
      the Project Owner.
- [x] Backend, frontend, integration, and closure boundaries are explicit.
- [x] Stage-level authorization, tenant-isolation, lifecycle, and file-protection
      boundaries are explicit.
- [x] Stage 5 API-contract refinements were prepared.
- [x] Stage 5 planning package is delivered to current `origin/main`.
- [x] Project Owner verifies local repository safety/synchronization before the
      first implementation task.
- [x] `S05-BE-001` detailed implementation contract is created and independently
      passes the Implementation Readiness Gate.

If any remaining entry condition fails, implementation must not begin.

Immediately before preparing or executing each implementation task, ChatGPT must
re-check current `origin/main`, relevant source/tests, and prior task delivery
state.

---

## 5. Approved Task Order

Implementation proceeds one task at a time in dependency order.

| Order | Task ID | Area | Short outcome | Depends on | Task status | Delivery status | Contract file |
|---:|---|---|---|---|---|---|---|
| 1 | `S05-BE-001` | Backend | Topic and Learning Material Persistence Foundation | Stage 4 closed | `Accepted` | `Delivered` | `tasks/backend/stage-05/S05-BE-001-topic-learning-material-persistence-foundation.md` |
| 2 | `S05-BE-002` | Backend | Teacher Topic Authoring API, including assigned Groups projection | `S05-BE-001` + Stage 4 Teacher–Group graph | `Accepted` | `Delivered` | `tasks/backend/stage-05/S05-BE-002-teacher-topic-authoring-api.md` |
| 3 | `S05-BE-003` | Backend | Learning Material Management and Private Storage | `S05-BE-002` | `Accepted` | `Delivered` | `tasks/backend/stage-05/S05-BE-003-learning-material-management-private-storage.md` |
| 4 | `S05-BE-004` | Backend | Topic Lifecycle | `S05-BE-003` | `Accepted` | `Delivered` | `tasks/backend/stage-05/S05-BE-004-topic-lifecycle.md` |
| 5 | `S05-BE-005` | Backend | Student Topic Access and Protected File Download | `S05-BE-003` + `S05-BE-004` + Stage 4 Student–Group graph | `Accepted` | `Delivered` | `tasks/backend/stage-05/S05-BE-005-student-topic-access-protected-file-download.md` |
| 6 | `S05-FE-001` | Frontend | Teacher Learning Workspace, Assigned Groups and Topic List | Backend Phase 2 `PASS` | `Accepted` | `Delivered` | `tasks/frontend/stage-05/S05-FE-001-teacher-learning-workspace-assigned-groups-topic-list.md` |
| 7 | `S05-FE-002` | Frontend | Teacher Topic Create, Detail, Edit and Lifecycle | `S05-FE-001` | `Accepted` | `Delivered` | `tasks/frontend/stage-05/S05-FE-002-teacher-topic-create-detail-edit-lifecycle.md` |
| 8 | `S05-FE-003` | Frontend | Teacher Learning Material Management | `S05-FE-002` | `Accepted` | `Delivered` | `tasks/frontend/stage-05/S05-FE-003-teacher-learning-material-management.md` |
| 9 | `S05-FE-004` | Frontend | Student Topics and Learning Materials | `S05-FE-003` | `Accepted` | `Delivered` | `tasks/frontend/stage-05/S05-FE-004-student-topics-learning-materials.md` |
| 10 | `S05-INT-001` | Integration | Stage 5 Topics and Protected Learning Materials Real-Stack E2E Verification | Backend Phase 2 `PASS` + Frontend Phase 2 `PASS` | `Draft` | `Not started` | `Not created` |

No per-task Phase 2 review exists for Stage 5+.

All four Stage 5 frontend implementation contracts are prepared and approved
before frontend implementation begins. Their approval does not authorize
parallel or out-of-order implementation.

Frontend implementation remains strictly sequential:

```text
S05-FE-001
→ S05-FE-002
→ S05-FE-003
→ S05-FE-004
```

Immediately before each frontend task is given to Codex, ChatGPT must re-check
the current `origin/main`, confirm the previous dependency is
`Accepted / Delivered`, inspect the directly relevant current source/tests, and
freeze the current implementation baseline. If the current implementation
materially conflicts with the pre-approved contract, the contract must be
revalidated before Codex starts.

Do not create duplicated `CODEX-PROMPT` files for the Stage.

---

## 6. Task Outcome Contracts at Decomposition Level

These are Stage-orchestration boundaries only. They do not replace the detailed
implementation contract that must be approved before each task.

### `S05-BE-001` — Topic and Learning Material Persistence Foundation

Focused outcome:

- introduce the Stage 5 persistence foundation for `topics`, `files`, and
  `learning_materials`;
- preserve direct Institution ownership on high-risk rows;
- establish lifecycle/file integrity needed by later Stage 5 APIs;
- add models/factories/enums/relations/constraints/indexes required by the
  approved database contract.

Must not implement Teacher/Student HTTP APIs or file-transfer behavior.

### `S05-BE-002` — Teacher Topic Authoring API

Focused outcome:

- expose current assigned active Groups needed for Teacher Topic authoring;
- Teacher Topic list;
- create Topic;
- Topic detail;
- metadata update;
- tenant-safe/current-membership ownership enforcement;
- strict request/response/error contract.

Must not implement material upload, Student delivery, or later assessment
behavior.

### `S05-BE-003` — Learning Material Management and Private Storage

Focused outcome:

- Teacher material list;
- upload;
- replace;
- title update;
- remove;
- effective upload capability metadata;
- approved extension/MIME/size validation;
- private storage;
- storage/DB failure consistency;
- no public storage key/path leakage.

Must preserve Learning Material identity according to the approved MVP material
model.

### `S05-BE-004` — Topic Lifecycle

Focused outcome:

```text
draft → active
draft → archived
active → closed
closed → archived
```

Also enforce:

- `archived` terminal;
- no arbitrary client status assignment;
- activation requirements;
- at least one current Learning Material before Stage 5 activation;
- Group/membership/lifecycle authorization;
- concurrency-safe lifecycle transitions;
- closed/archived read-only behavior;
- no destructive history loss.

Homework is Stage 6 and is not an activation dependency in Stage 5.

### `S05-BE-005` — Student Topic Access and Protected File Download

Focused outcome:

- Student Topic list;
- Student Topic detail;
- eligible material projection;
- draft invisibility;
- current Student–Group authorization;
- protected binary file download;
- Teacher/Student file authorization;
- removed/out-of-scope/cross-Institution/direct-UUID denial;
- no public storage metadata leakage.

Stage 5 does not add Parent file access or Student submission files.

### `S05-FE-001` — Teacher Learning Workspace, Assigned Groups and Topic List

Focused outcome:

- replace the Teacher placeholder entry with the real Stage 5 Teacher learning
  workspace;
- assigned Group projection;
- Topic list/filter/navigation;
- desktop authoring entry;
- mobile read/basic Topic navigation;
- backend-authoritative scope and error handling.

### `S05-FE-002` — Teacher Topic Create, Detail, Edit and Lifecycle

Focused outcome:

- desktop Topic create;
- Topic detail;
- allowed metadata edit;
- activation/close/archive controls and state reconciliation;
- read-only behavior when lifecycle requires it;
- basic mobile Topic/detail/status view without duplicating complex authoring.

### `S05-FE-003` — Teacher Learning Material Management

Focused outcome:

- list materials;
- select/upload supported files;
- show effective upload rules;
- replace;
- rename title;
- remove;
- authenticated download/open;
- loading/progress/error/success reconciliation;
- platform-specific file handling explicitly resolved in this task contract.

Any new Flutter dependency requires explicit ChatGPT approval in the detailed
task contract; Codex must not choose packages independently.

### `S05-FE-004` — Student Topics and Learning Materials

Focused outcome:

- replace the Student placeholder entry for Stage 5 scope;
- Student Topic list;
- Topic detail/instructions;
- eligible Learning Material list;
- authenticated download/open;
- desktop and Android/mobile behavior;
- draft/out-of-scope/removed content must not become visible through client
  behavior.

### `S05-INT-001` — Stage 5 Real-Stack E2E

Focused outcome:

prove the complete Stage 5 Laravel–Flutter–PostgreSQL/private-storage workflow
against the real stack after both block checkpoints pass.

---

## 7. Implementation Readiness Tracking

A task becomes `Approved` only when its own detailed contract passes the
Implementation Readiness Gate.

| Task ID | Scope/non-goals | Behavior/API/UI | Persistence/lifecycle | Auth/tenant/security | Errors/edge/concurrency | Tests/verification | Ready |
|---|---|---|---|---|---|---|---|
| `S05-BE-001` | `Yes` | `N/A` | `Yes` | `Yes` | `Yes` | `Yes` | `Yes` |
| `S05-BE-002` | `Yes` | `Yes` | `Yes` | `Yes` | `Yes` | `Yes` | `Yes` |
| `S05-BE-003` | `Yes` | `Yes` | `Yes` | `Yes` | `Yes` | `Yes` | `Yes` |
| `S05-BE-004` | `Yes` | `Yes` | `Yes` | `Yes` | `Yes` | `Yes` | `Yes` |
| `S05-BE-005` | `Yes` | `Yes` | `Yes` | `Yes` | `Yes` | `Yes` | `Yes` |
| `S05-FE-001` | `Yes` | `Yes` | `N/A` | `Yes` | `Yes` | `Yes` | `Yes` |
| `S05-FE-002` | `Yes` | `Yes` | `N/A` | `Yes` | `Yes` | `Yes` | `Yes` |
| `S05-FE-003` | `Yes` | `Yes` | `N/A` | `Yes` | `Yes` | `Yes` | `Yes` |
| `S05-FE-004` | `Yes` | `Yes` | `N/A` | `Yes` | `Yes` | `Yes` | `Yes` |
| `S05-INT-001` | `No` | `No` | `N/A` | `No` | `No` | `No` | `No` |

For the current task, ChatGPT must confirm before approval:

- one observable goal;
- complete included scope and explicit non-goals;
- accurate current implementation context;
- exact behavior and state transitions;
- exact API/UI contract where applicable;
- persistence/schema behavior where applicable;
- authorization and tenant isolation;
- validation and stable error semantics;
- edge cases;
- concurrency/idempotency/stale-async behavior where relevant;
- objective acceptance criteria;
- focused tests and exact task-level verification;
- directly affected regression scope;
- Codex verification limited to proportional task scope;
- Project Owner delivery ownership unless explicitly changed;
- explicit allowed bookkeeping;
- no unresolved product/architecture/API/database/security/lifecycle/UX
  decision left to Codex.

---

## 8. Dependency and Checkpoint Map

| Dependency or checkpoint | Required before | Evidence when satisfied |
|---|---|---|
| Stage 4 closure | Stage 5 implementation | `tasks/STAGE_04_CLOSURE_REVIEW.md` = `STAGE CLOSED` |
| Stage 4 Teacher–Group graph | `S05-BE-002`, Teacher Topic authorization | Current membership persistence/API from Stage 4 |
| Stage 4 Student–Group graph | `S05-BE-005`, Student Topic delivery | Current membership persistence/API from Stage 4 |
| Stage 5 persistence foundation | `S05-BE-002` | `S05-BE-001 Accepted / Delivered — PR #102, merge 17129ede0e266087c23355f135f9a340ccdaaf92` |
| Teacher Topic authoring | material management | `S05-BE-002 Accepted / Delivered — PR #105, merge 08fc5bca465562bf88f2824dd62f0d13aa29a478` |
| material management | Topic activation/lifecycle | `S05-BE-003 Accepted / Delivered — PR #108, merge dbcaaf02073bab269ce729173795f7ee55ea0909` |
| Topic lifecycle + materials | Student delivery/download | `S05-BE-004 Accepted / Delivered — PR #110, merge 8dee9f91f08a7c032429ab7c07e31d911c67b065` |
| backend task block complete | Backend Phase 2 | `S05-BE-001…005 Accepted / Delivered — final backend delivery PR #112, merge 3ec963c682b14c08cd4b8a8eee606756bd6fa8de` |
| Backend Phase 2 `PASS` | frontend implementation | `PASS — audited origin/main @ 999f477f6a281f2266ad4abbded8b0732b5d789c` |
| Frontend implementation contracts approved and delivered | `S05-FE-001` implementation | `S05-FE-001…004` detailed contracts = `Approved`; contract files and updated Stage index are present on current `origin/main` |
| `S05-FE-001` Teacher learning workspace | `S05-FE-002` implementation | `S05-FE-001 Accepted / Delivered — PR #116, merge 41e6595589c9c92a079659639f69953d007066dd` |
| `S05-FE-002` Teacher Topic authoring and lifecycle | `S05-FE-003` implementation | `S05-FE-002 Accepted / Delivered — PR #118, merge cfa6b9cb1981ea5c3e5416cf6e343319718044fb` |
| `S05-FE-003` Teacher Learning Material management | `S05-FE-004` implementation | `S05-FE-003 Accepted / Delivered — PR #120, merge 5679b63ea3964bbefd71b82950be6593021e724c` |
| frontend task block complete | Frontend Phase 2 | `S05-FE-001…004 Accepted / Delivered` |
| Frontend Phase 2 `PASS` | `S05-INT-001` | frontend block review + audited `origin/main` |
| Integration `PASS` + manual smoke `PASS` | Stage Closure Review | accepted integration evidence |
| Stage Closure `PASS` | Stage 6 planning | `tasks/STAGE_05_CLOSURE_REVIEW.md` |



Exact implementation chain:

```text
Stage 4 CLOSED
  ↓
Stage 5 planning package delivered
  ↓
S05-BE-001
  ↓
S05-BE-002
  ↓
S05-BE-003
  ↓
S05-BE-004
  ↓
S05-BE-005
  ↓
Backend Phase 2 PASS
  ↓
S05-FE-001
  ↓
S05-FE-002
  ↓
S05-FE-003
  ↓
S05-FE-004
  ↓
Frontend Phase 2 PASS
  ↓
S05-INT-001 PASS
  ↓
Project Owner manual smoke PASS
  ↓
Stage 5 Closure Review
  ↓
STAGE CLOSED
```

---

## 9. Per-Task Verification Map

Each detailed task contract defines exact commands based on the current
repository at task-preparation time.

| Task ID | Focused verification target | Static/format | Direct regression | Task executor | Delivery owner | `git diff --check` |
|---|---|---|---|---|---|---|
| `S05-BE-001` | migrations/models/constraints/relations | backend required checks | Stage 4 persistence integrity where affected | `Codex` | `Project Owner` | `Required` |
| `S05-BE-002` | Teacher Groups + Topic authoring API | backend required checks | auth/role/current membership/tenant API | `Codex` | `Project Owner` | `Required` |
| `S05-BE-003` | material/storage/limits/replacement/removal | backend required checks | settings + private storage/file integrity | `Codex` | `Project Owner` | `Required` |
| `S05-BE-004` | lifecycle/transition/concurrency | backend required checks | Topic edit/material mutability | `Codex` | `Project Owner` | `Required` |
| `S05-BE-005` | Student Topic + protected download auth | backend required checks | auth/current Student membership/existence privacy | `Codex` | `Project Owner` | `Required` |
| `S05-FE-001` | Teacher workspace/groups/topic list | Flutter required checks | auth/entry/router/session | `Codex` | `Project Owner` | `Required` |
| `S05-FE-002` | create/detail/edit/lifecycle UI | Flutter required checks | FE-001 navigation/state | `Codex` | `Project Owner` | `Required` |
| `S05-FE-003` | upload/manage/download/open material UI | Flutter required checks | API/error/session + file handling | `Codex` | `Project Owner` | `Required` |
| `S05-FE-004` | Student Topic/material experience | Flutter required checks | Student entry/router/session | `Codex` | `Project Owner` | `Required` |
| `S05-INT-001` | focused integration assets/fixes only | as contract requires | real Stage 5 vertical flow | `Codex` only for implementation assets/fixes | `Project Owner` | `Required` |

Normal implementation-task verification includes only:

- focused tests for changed behavior;
- required formatter/linter/static checks;
- directly affected regression tests when justified;
- `git diff --check`;
- focused scope/diff self-check.

Do not run full backend/frontend suites, broad builds, broad E2E, or Phase 2
reviews after each small implementation task unless a concrete regression risk
requires it.

---

## 10. Backend Phase 2 Checkpoint

Run only after:

```text
S05-BE-001…005 = Accepted / Delivered
```

Planned review file:

```text
tasks/backend/stage-05/S05-BE-PHASE-2-backend-block-review.md
```

| Field | Value |
|---|---|
| Audited `origin/main` | `999f477f6a281f2266ad4abbded8b0732b5d789c` |
| Review date | `2026-08-23` |
| Verification executor | `Project Owner` |
| Verdict | `PASS` |
| Findings | `P1=0, P2=0, P3=0` |

Required checkpoint evidence:

- [x] complete Stage 5 backend block reviewed read-only;
- [x] full backend regression suite passes;
- [x] required backend format/static checks pass;
- [x] `git diff --check` passes;
- [x] modular-monolith responsibilities remain coherent;
- [x] Topic/File/LearningMaterial schema, constraints, indexes, and relations are
      coherent;
- [x] current Teacher/Student Group membership is consumed correctly;
- [x] tenant-first resource resolution and existence privacy are correct;
- [x] Topic lifecycle transitions compose correctly;
- [x] lifecycle concurrency/locking is sufficient and not excessive;
- [x] upload extension + MIME + exact size enforcement is correct;
- [x] Institution lower upload limit is authoritative;
- [x] private storage is not publicly addressable;
- [x] upload/replace/remove DB-storage consistency is reviewed;
- [x] protected download never authorizes by File UUID alone;
- [x] removed/unavailable file behavior is correct;
- [x] closed/archived history remains non-destructive;
- [x] Stage 4 authorization/membership behavior has no blocking regression;
- [x] cross-task API/resource/error behavior is consistent;
- [x] `P1 = 0`;
- [x] `P2 = 0`.

Backend Phase 2 `PASS` is required before frontend Stage 5 implementation begins.

If the checkpoint is `NOT ACCEPTED`, ChatGPT creates only the focused fix
contract(s) required by the findings. Previously valid evidence is reused unless
a later change materially invalidates it.

---

## 11. Frontend Phase 2 Checkpoint

Run only after:

```text
Backend Phase 2 = PASS
S05-FE-001…004 = Accepted / Delivered
```

Planned review file:

```text
tasks/frontend/stage-05/S05-FE-PHASE-2-frontend-block-review.md
```

| Field | Value |
|---|---|
| Audited `origin/main` | `To be recorded at checkpoint` |
| Review date | `Not started` |
| Verification executor | `Project Owner` |
| Verdict | `Not started` |
| Findings | `N/A` |

Required checkpoint evidence:

- [ ] complete Stage 5 frontend block reviewed read-only;
- [ ] full frontend test suite passes;
- [ ] Flutter static analysis passes;
- [ ] Flutter format check passes;
- [ ] required Windows debug build passes;
- [ ] required Android debug build passes;
- [ ] `git diff --check` passes;
- [ ] Teacher/Student feature-layer boundaries are coherent;
- [ ] DTO parsing and API/error integration match backend contracts;
- [ ] auth/session/role/router boundaries remain correct;
- [ ] stale async completion safety is preserved;
- [ ] list/detail/mutation cache invalidation and reconciliation are correct;
- [ ] loading/error/empty/success/mutation states are complete;
- [ ] backend remains authoritative for Group scope, Topic lifecycle, upload
      limits, and file authorization;
- [ ] Teacher desktop vs mobile feature boundary matches roadmap scope;
- [ ] Student desktop/mobile Topic/material path is usable;
- [ ] file selection/upload/download/open behavior is safe on required targets;
- [ ] accessibility/focus/keyboard/responsiveness is reviewed where required;
- [ ] Stage 1–4 entry/navigation behavior has no blocking regression;
- [ ] `P1 = 0`;
- [ ] `P2 = 0`.

If the checkpoint is `NOT ACCEPTED`, use focused fix contracts and minimum
sufficient reruns according to Workflow v3 evidence-validity rules.

---

## 12. Integration Gate

Integration begins only after:

```text
Backend Phase 2 PASS
+
Frontend Phase 2 PASS
```

Integration task:

```text
S05-INT-001 — Stage 5 Topics and Protected Learning Materials Real-Stack E2E Verification
```

Planned contract path:

```text
tasks/integration/stage-05/S05-INT-001-stage-05-topics-protected-learning-materials-e2e-verification.md
```

| Field | Value |
|---|---|
| Audited `origin/main` | `To be recorded at integration` |
| Automated execution owner | `Project Owner` |
| Manual smoke owner | `Project Owner` |
| Verdict | `Not started` |

Fresh Backend/Frontend Phase 2 PASS evidence is reused. Do not rerun broad
backend/frontend suites or standalone builds merely because integration begins.

Required real-stack scenarios include:

1. Teacher authenticates and sees only currently assigned active Groups.
2. Teacher cannot create a Topic for an unrelated/cross-Institution Group.
3. Teacher creates a valid `draft` Topic.
4. Student cannot see the draft Topic.
5. Teacher uploads approved PDF/DOCX/PPT/PPTX learning materials.
6. Unsupported format is rejected.
7. platform 25 MiB maximum is enforced.
8. lower Institution material limit is enforced.
9. Teacher activates only an activation-eligible Topic.
10. current assigned Student sees the active Topic and material metadata.
11. unrelated/cross-Institution/ended-membership Student does not receive access.
12. direct foreign File UUID does not bypass authorization.
13. Student downloads only an authorized current material.
14. Teacher replaces a material while preserving logical Learning Material
    identity according to the backend contract.
15. old/removed file access becomes unavailable according to the approved API
    behavior.
16. Teacher closes the Topic and content becomes read-only.
17. Teacher archives the Topic and historical records remain preserved.
18. archived Group/current-membership edge behavior matches the approved Stage 5
    contract.
19. backend restart preserves Topic/material metadata and authorized private-file
    behavior.
20. Windows Teacher/Student workflow smoke passes.
21. Android Student material access/download/open smoke passes.
22. Project Owner manual smoke passes.

Integration findings must be fixed and re-verified before `S05-INT-001` is
Accepted / Delivered.

---

## 13. Evidence Validity and Minimum Rerun Tracking

Fresh PASS evidence remains valid until a later change materially affects the
surface that evidence proved.

ChatGPT determines validity and minimum sufficient rerun scope using Workflow v3.

| Later change | Evidence considered | Still valid? | Required rerun / reason |
|---|---|---|---|
| `Not applicable yet` | `N/A` | `N/A` | `N/A` |

Default Stage 5 expectations:

- docs/bookkeeping-only changes do not invalidate product verification;
- isolated test-only strengthening does not invalidate production evidence;
- narrow production fixes preserve unrelated PASS evidence;
- shared auth/session/router/client/middleware/error changes may invalidate
  broader affected evidence;
- public API/schema/migration/authorization/tenant/file-security changes
  invalidate the corresponding checkpoint/integration surface;
- dependency/platform/build-system changes invalidate relevant build/static
  evidence;
- any required command that previously failed must eventually pass.

Do not rerun by habit, and do not preserve materially invalidated evidence.

---

## 14. Roadmap Acceptance Matrix

| Stage 5 criterion | Implementing task(s) | Verification owner/gate | Status |
|---|---|---|---|
| Teacher can view the Groups currently available for Topic authoring | `S05-BE-002`, `S05-FE-001` | Backend Phase 2 + Frontend Phase 2 + Integration | `Not started` |
| Teacher can create a Topic only for an authorized assigned Group with approved metadata | `S05-BE-002`, `S05-FE-002` | Focused tests + Backend/Frontend Phase 2 + Integration | `Not started` |
| Teacher can view and edit own eligible Topic without changing protected ownership fields | `S05-BE-002`, `S05-FE-002` | Backend/Frontend Phase 2 | `Not started` |
| Topic lifecycle supports draft/active/closed/archived behavior without destructive history loss | `S05-BE-004`, `S05-FE-002` | Backend/Frontend Phase 2 + Integration | `Not started` |
| Teacher can upload, view, replace, update, remove, open, and download protected Learning Materials | `S05-BE-003`, `S05-FE-003` | Backend/Frontend Phase 2 + Integration | `Not started` |
| Learning Material formats and platform/Institution size limits are enforced server-side | `S05-BE-003`, `S05-FE-003` | Backend Phase 2 + Integration | `Not started` |
| Student cannot see draft or unrelated/cross-Institution Topics | `S05-BE-005`, `S05-FE-004` | Backend Phase 2 + Integration | `Not started` |
| Assigned Student can view eligible active Topic instructions and materials on required devices | `S05-BE-005`, `S05-FE-004` | Frontend Phase 2 + Integration + manual smoke | `Not started` |
| Direct File UUID/path knowledge never bypasses learning-resource authorization | `S05-BE-005`, `S05-INT-001` | Backend Phase 2 + Integration | `Not started` |
| Closed/archived Topic/material history is preserved and inappropriate new mutations are blocked | `S05-BE-004`, `S05-BE-005`, `S05-FE-002`, `S05-FE-004` | Both checkpoints + Integration | `Not started` |
| Final Stage outcome: Teacher can create an active Topic with protected study materials accessible only to eligible Students | `S05-BE-001…005`, `S05-FE-001…004`, `S05-INT-001` | Stage Closure Review | `Not started` |

A roadmap criterion with no implementation owner or verification owner is a
decomposition defect.

---

## 15. Stage 5 Resolved Design Decisions

The following decisions are part of the approved Stage 5 planning boundary and
must not be reopened by Codex.

### Topic lifecycle

Allowed:

```text
draft → active
draft → archived
active → closed
closed → archived
```

Not allowed:

```text
active → draft
active → archived
closed → active
archived → *
```

`archived` is terminal.

Topic `status` is server-controlled and changes only through lifecycle endpoints.

### Stage 5 activation gate

Topic activation requires:

- valid Topic ownership/scope;
- current Teacher assignment to the Group;
- active Group;
- required Topic metadata;
- at least one current Learning Material.

Homework is not required for Stage 5 activation because Homework begins in
Stage 6.

### Group archive boundary

Create/activate/content mutation requires an active Group.

If a Group is archived after Topic/content creation:

- Topic/material history is preserved;
- no automatic destructive deletion occurs;
- new learning-content authoring/delivery is not created from the archived
  Group;
- allowed close/archive cleanup remains lifecycle-controlled.

### Membership revocation boundary

Ended current Teacher/Student membership revokes future current learning access
that depends on that membership.

Historical database records are preserved. Broader historical reporting access
belongs to the relevant later reporting rules and is not invented in Stage 5.

### Protected file boundary

File UUID, original filename, storage disk, storage key, physical path, or URL
is never authorization.

Learning Material file access must resolve the connected Topic/material and
current authorized role/Institution/relationship context first.

### Teacher Group projection

Stage 5 exposes a read-only Teacher Group projection required for Topic
authoring. Teacher Group membership mutation remains Institution Admin scope
from Stage 4.

---

## 16. Stage Risks and Stop Conditions

| Risk or stop condition | Affected task/checkpoint | Mitigation / required decision | Status |
|---|---|---|---|
| Stage 5 API refinement delivery | Stage entry | Updated `docs/09-api-contracts.md` and Stage 5 planning package delivered in PR #101 | `Resolved` |
| Topic activation wording in general business rules mentions Homework preparation, while Homework starts Stage 6 | `S05-BE-004` | Stage 5 specialization: require at least one current Learning Material; Homework gate begins when Stage 6 contract is available | `Resolved` |
| Exact storage replacement/cleanup transaction strategy is implementation-sensitive | `S05-BE-003` | Transaction-aware compensation plus after-commit/after-rollback cleanup implemented and independently reviewed | `Resolved — S05-BE-003 / Backend Phase 2 PASS` |
| Flutter timezone/file select/save/open package and shared platform strategy | `S05-FE-002`, `S05-FE-003`, `S05-FE-004` | Approved: `timezone ^0.11.1` with shared `core/time`; `file_picker ^12.0.0` + `open_file ^4.0.0` with shared protected `core/files` boundary; FE-004 adds no new package | `Resolved — frontend contracts approved` |
| Private file handling can create DB/storage inconsistency on partial failure | `S05-BE-003`, Backend Phase 2 | Upload/replace/remove failure semantics and transaction-aware cleanup implemented and reviewed | `Resolved — Backend Phase 2 PASS` |
| Direct IDs/cross-tenant file access could leak existence/content | `S05-BE-005`, Backend Phase 2, Integration | Tenant-first connected-resource resolution, privacy-safe denial and protected streaming implemented; integration remains later confirmation | `Resolved for backend — Backend Phase 2 PASS` |
| Mobile file behavior may differ from Windows | `S05-FE-003`, `S05-FE-004`, Frontend Phase 2 | verify required Windows + Android paths; do not assume desktop-only behavior | `Open — implementation pending` |

Stop affected work when:

- a detailed task contract is not implementation-ready;
- a locked product/architecture/API/database rule conflicts;
- safe authorization or tenant isolation is unresolved;
- a required dependency is missing;
- Codex would need to choose product, API, database, security, lifecycle,
  concurrency, or UX behavior;
- implementation requires material scope expansion;
- Git/repository state is unsafe;
- required focused verification fails;
- a block checkpoint/integration verification fails;
- any P1/P2 finding remains unresolved.

---

## 17. Stage Checkpoint and Closure Ownership

### Task implementation

- Requirements/design owner: `ChatGPT`
- Implementation agent: `Codex`
- Normal task verification: `Codex`, focused/proportional only
- Routine Git/GitHub delivery: `Project Owner`

### Backend Phase 2

- Review/design authority: `ChatGPT`
- Full checkpoint execution: `Project Owner` or approved CI
- Required verdict before frontend: `PASS`

### Frontend Phase 2

- Review/design authority: `ChatGPT`
- Full checkpoint execution: `Project Owner` or approved CI
- Required verdict before integration: `PASS`

### Integration

- Integration implementation assets/focused fixes: `Codex` when required
- Real-stack execution: `Project Owner` or approved CI
- Manual user-facing smoke: `Project Owner`

### Closure

Planned review file:

```text
tasks/STAGE_05_CLOSURE_REVIEW.md
```

Closure must reuse valid prior evidence rather than automatically repeating
broad suites/builds/E2E.

Stage 5 closes only when:

```text
S05-BE-001…005 Accepted / Delivered
+
Backend Phase 2 PASS
+
S05-FE-001…004 Accepted / Delivered
+
Frontend Phase 2 PASS
+
S05-INT-001 Accepted / Delivered / PASS
+
Project Owner manual smoke PASS
+
no unresolved P1/P2
+
Stage Closure Review PASS
+
closure bookkeeping delivered to origin/main
```

---

## 18. Change Log

| Date | Change | Reason | Approved by |
|---|---|---|---|
| `2026-08-22` | Initial Stage 5 decomposition: 5 Backend + 4 Frontend + 1 Integration task, Workflow v3 checkpoints and closure map | Prepare Stage 5 Topics and Learning Materials implementation under Lean Verification | `Project Owner` |
| `2026-08-22` | Teacher assigned-Groups projection folded into `S05-BE-002` instead of a separate backend task | Reduce unnecessary task/Codex overhead without weakening architecture or verification | `Project Owner` |
| `2026-08-22` | `S05-BE-001` Accepted / Delivered — PR #102, merge `17129ede0e266087c23355f135f9a340ccdaaf92` | Topic and Learning Material persistence foundation implemented, focused-verified, independently reviewed, and delivered | `Project Owner / ChatGPT review` |
| `2026-08-22` | `S05-BE-002` Accepted / Delivered — PR #105, merge `08fc5bca465562bf88f2824dd62f0d13aa29a478` | Teacher assigned-Group projection and Topic authoring API implemented, focused-verified, independently reviewed, and delivered | `Project Owner / ChatGPT review` |
| `2026-08-22` | `S05-BE-003` Accepted / Delivered — PR #108, merge `dbcaaf02073bab269ce729173795f7ee55ea0909` | Teacher Learning Material management/private storage implemented; transaction-aware blob cleanup P2 fixed, focused-verified, independently re-reviewed, and delivered | `Project Owner / ChatGPT review` |
| `2026-08-22` | `S05-BE-004` Accepted / Delivered — PR #110, merge `8dee9f91f08a7c032429ab7c07e31d911c67b065` | Controlled Teacher Topic lifecycle implemented, focused-verified, independently reviewed, and delivered | `Project Owner / ChatGPT review` |
| `2026-08-23` | `S05-BE-005` Accepted / Delivered — PR #112, merge `3ec963c682b14c08cd4b8a8eee606756bd6fa8de` | Student Topic access and protected Teacher/Student Learning Material download implemented, focused-verified, independently reviewed, and delivered | `Project Owner / ChatGPT review` |
| `2026-08-23` | Stage 5 Backend Phase 2 `PASS` — audited `origin/main` @ `999f477f6a281f2266ad4abbded8b0732b5d789c` | Full backend regression suite PASS, Pint PASS, Stage-wide diff hygiene PASS after docs-only PR #113; read-only architecture/API/database/authorization/tenant/concurrency review found P1=0, P2=0, P3=0 | `Project Owner / ChatGPT review` |
| `2026-08-23` | `S05-FE-001…004` detailed frontend contracts prepared, cross-task reviewed, and Approved before implementation | Frontend planning timing changed to prepare the complete Stage 5 frontend contract block first while preserving strict sequential implementation and per-task `origin/main` revalidation; shared `core/time` and `core/files` boundaries and required Flutter dependencies were resolved before Codex execution | `Project Owner / ChatGPT review` |
| `2026-08-23` | `S05-FE-001` Accepted / Delivered — PR #116, merge `41e6595589c9c92a079659639f69953d007066dd` | Teacher Learning Workspace, assigned Groups and Topic list implemented and focused-verified; independent review P2 for retry/search-validation interaction was fixed and re-reviewed with final P1=0, P2=0, P3=0 | `Project Owner / ChatGPT review` |
| `2026-08-23` | `S05-FE-002` Accepted / Delivered — PR #118, merge `cfa6b9cb1981ea5c3e5416cf6e343319718044fb` | Teacher Topic create/detail/edit/lifecycle, Institution-timezone handling, routing and mutation reconciliation implemented and focused-verified; independent review findings were fixed and re-reviewed with final P1=0, P2=0, P3=0 | `Project Owner / ChatGPT review` |
| `2026-08-23` | `S05-FE-003` Accepted / Delivered — PR #120, merge `5679b63ea3964bbefd71b82950be6593021e724c` | Teacher Learning Material management, protected file transfer, Save/Open, binary API-error handling and lifecycle coordination implemented and focused-verified; independent review findings were fixed and re-reviewed with final P1=0, P2=0, P3=0 | `Project Owner / ChatGPT review` |
| `2026-08-23` | `S05-FE-004` Accepted / Delivered — PR #122, merge `d5d5a4fcc400e45e75ec58605f74eca3f1b4f18d` | Student Topics workspace/detail, protected Learning Material Open/Save, desktop/mobile routing, Institution-time display and Student authorization-safe reconciliation implemented and focused-verified; independent review PASS with P1=0, P2=0, P3=0 | `Project Owner / ChatGPT review` |
---

## 19. Next Permitted Action

Stage 5 backend implementation block is complete:

```text
S05-BE-001 = Accepted / Delivered
S05-BE-002 = Accepted / Delivered
S05-BE-003 = Accepted / Delivered
S05-BE-004 = Accepted / Delivered
S05-BE-005 = Accepted / Delivered
Backend Phase 2 = PASS
```

Stage 5 frontend implementation block is also complete:

```text
S05-FE-001 = Accepted / Delivered
S05-FE-002 = Accepted / Delivered
S05-FE-003 = Accepted / Delivered
S05-FE-004 = Accepted / Delivered
```

`S05-FE-004` delivery evidence:

```text
PR #122
implementation head: fa19764a1843075769032e0ef46101dfb793919c
merge: d5d5a4fcc400e45e75ec58605f74eca3f1b4f18d
acceptance review: PASS — P1=0, P2=0, P3=0
```

The current authoritative implementation state after `S05-FE-004` delivery is:

```text
origin/main @ d5d5a4fcc400e45e75ec58605f74eca3f1b4f18d
```

The next permitted action is delivery of this docs-only `S05-FE-004`
bookkeeping update to `origin/main`.

No additional frontend implementation task may start before this bookkeeping
delivery is confirmed.

After the bookkeeping update is merged and current `origin/main` is re-checked,
the next mandatory Stage 5 gate is:

```text
Frontend Phase 2 Read-Only Review
```

Frontend Phase 2 covers the complete delivered Stage 5 frontend block:

```text
S05-FE-001
S05-FE-002
S05-FE-003
S05-FE-004
```

The review must evaluate the complete frontend implementation as one integrated
block rather than re-running per-task acceptance reviews.

Frontend Phase 2 must review at minimum:

1. frontend architecture and feature/layer boundaries;
2. Teacher and Student routing and direct deep-link behavior;
3. authentication bootstrap and role/device entry behavior;
4. Teacher and Student session ownership and stale async publication safety;
5. API request/response integration and strict DTO parsing;
6. Teacher Topic list/create/detail/edit/lifecycle cross-task interactions;
7. Teacher Learning Material list/mutation/download interactions;
8. Student Topic list/detail/material interactions;
9. protected file-transfer reuse through the shared `core/files` boundary;
10. Institution-time conversion through the shared `core/time` boundary;
11. Teacher/Student role isolation and absence of client-side authorization
    assumptions;
12. privacy-safe Topic/Material `404` behavior;
13. lifecycle/material mutation coordination;
14. desktop and mobile/Android behavior;
15. router regression risk for existing Platform Owner, Institution Admin,
    Teacher, Student, and Parent flows;
16. dependency and native-plugin integration;
17. cross-task state/reconciliation behavior;
18. absence of Stage 6+ scope leakage;
19. final frontend diff/scope consistency against the approved Stage 5 boundary.

Frontend Phase 2 must run the full frontend verification required by
Workflow v3, including:

```text
full frontend test suite
static analysis
format verification
required frontend build(s)
git diff --check
```

Because Stage 5 includes Student Android/mobile protected file behavior,
Frontend Phase 2 must include the required Android build verification.

Any Phase 2 finding must be classified as:

```text
P1
P2
P3
```

If findings exist:

```text
Frontend Phase 2 = NOT PASS
→ fix findings
→ run proportional focused verification for the fixes
→ repeat the affected Phase 2 review/verification
```

Frontend Phase 2 reaches PASS only when:

```text
P1 = 0
P2 = 0
P3 = 0
full required frontend verification = PASS
```

Integration remains blocked until all of the following are true:

```text
S05-BE-001…005 = Accepted / Delivered
Backend Phase 2 = PASS
S05-FE-001…004 = Accepted / Delivered
Frontend Phase 2 = PASS
```

Only after Frontend Phase 2 PASS may Stage 5 proceed to:

```text
S05-INT-001 — Stage 5 Topics and Protected Learning Materials Real-Stack E2E Verification
```

Stage Closure Review remains blocked until Integration passes and all required
real-stack, security/tenant-isolation, file-access, persistence/restart, and
Project Owner manual-smoke evidence is complete.

Therefore the immediate sequence is:

```text
deliver S05-FE-004 bookkeeping to origin/main
→ Frontend Phase 2 Read-Only Review
→ resolve any Phase 2 findings
→ Frontend Phase 2 PASS
→ S05-INT-001
→ Stage 5 Closure Review
```

Do not start Integration before Frontend Phase 2 PASS.

---

# Final Stage 5 Planning Principle

> Stage 5 introduces the first protected learning-content vertical on top of the
> closed Stage 4 relationship graph. Teacher and Student access must always be
> derived from current authenticated Institution/Group relationships, Topic
> ownership/lifecycle, and connected private-file authorization; the Flutter
> client never becomes the authority for those rules.
