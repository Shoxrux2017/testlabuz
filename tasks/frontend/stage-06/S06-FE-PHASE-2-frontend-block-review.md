# Phase 2 Read-Only Block Review Contract — Stage 6 Frontend

## 1. Review Metadata

| Field | Value |
|---|---|
| Review ID | `S06-FE-PHASE-2` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Block | `Frontend` |
| Status | `Approved — Pending execution` |
| Review mode | `Read-only` |
| Depends on | Stage 6 Backend Phase 2 `PASS`; `S06-FE-001…004` all `Accepted / Delivered` |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |
| Audited frontend implementation base | Freeze immediately before execution |
| Audited production head | Freeze current `origin/main` immediately before execution |
| Flutter toolchain | Repository-pinned FVM Flutter; planning pin `3.44.7` |
| Verification executor | `Codex / Project Owner as explicitly assigned for the checkpoint` |
| Final classification owner | `ChatGPT` |
| Verdict | `PENDING` |
| Findings | `P1=?, P2=?, P3=?` |
| Next permitted gate on PASS | `S06-INT-001 — Stage 6 Homework Authoring Real-Stack E2E` |
| Next permitted gate on findings | Focused Frontend Phase 2 fix contract(s) only |

This is a **review/checkpoint contract**, not an implementation task.

Do not create a duplicate `CODEX-PROMPT` file.

---

# 2. Purpose

Perform the mandatory Stage 6 Frontend Phase 2 checkpoint after the complete frontend implementation block has been delivered.

The checkpoint reviews:

```text
S06-FE-001
S06-FE-002
S06-FE-003
S06-FE-004
```

as one integrated Flutter surface.

The review must determine whether the complete Stage 6 frontend is safe for real-stack integration with the already-passed Stage 6 backend.

Primary review areas:

- feature-first architecture;
- strict API/DTO contract;
- Teacher session/state ownership;
- stale async protection;
- GoRouter integration;
- desktop/mobile capability boundaries;
- Homework list/detail read surfaces;
- draft metadata/assignment/deadline authoring;
- selected-Student roster/picker;
- all nine Question types;
- Question add/update/delete/reorder;
- mutation uncertainty/reconciliation;
- Homework lifecycle;
- official Homework/result-pair UX;
- staged result-pair null-Blitz compatibility;
- previous-stage routing and Teacher/Student regression safety;
- accessibility/responsiveness;
- full frontend test/static/build verification.

---

# 3. Entry Gate

Do not execute this checkpoint until:

```text
Stage 6 Backend Phase 2 = PASS

S06-FE-001 = Accepted / Delivered
S06-FE-002 = Accepted / Delivered
S06-FE-003 = Accepted / Delivered
S06-FE-004 = Accepted / Delivered
```

Before review:

1. switch to `main`;
2. fetch/prune origin;
3. confirm local `main == origin/main`;
4. confirm ahead/behind `0/0`;
5. confirm clean worktree;
6. freeze final current `origin/main` SHA;
7. identify the Stage 6 frontend implementation base;
8. confirm the repository-pinned FVM Flutter version.

If Git state is dirty/divergent or one task is not delivered:

```text
BLOCKED
```

Do not review an uncommitted or partial frontend block.

---

# 4. Determining the Frontend Implementation Base

At execution time identify the commit immediately before the first Stage 6 frontend **production implementation** entered `main`.

Preferred audited range:

```text
<stage6_frontend_implementation_base>...origin/main
```

The range must include:

- all production/test changes from S06-FE-001…004;
- all frontend Phase 2 fixes merged before final PASS;
- any tooling/config change that materially affects frontend verification.

Task-contract/bookkeeping-only commits may be present but should be distinguished from application changes.

Do not omit an intermediate frontend task delivery.

---

# 5. Read-Only Rule

Phase 2 execution is strictly read-only.

Allowed:

- inspect source/tests/routes/domain/data/application/presentation;
- inspect Git history/diff;
- run tests;
- run analyze;
- run format **check**;
- run debug builds;
- report findings.

Forbidden:

- edit production code;
- edit tests;
- auto-format;
- auto-fix analyze findings;
- change dependencies;
- change FVM pin;
- stage/commit/push;
- open/merge PR;
- modify task/checkpoint bookkeeping during the review run.

Use:

```text
fvm dart format --output=none --set-exit-if-changed ...
```

or the project-established read-only format command.

Do not run write-format mode.

If a finding is discovered, report it. Fixes happen in separate approved fix task(s), then Phase 2 evidence is refreshed.

---

# 6. Severity Model

Use exactly:

## P1 — Critical

Examples:

- stale async completion mutates/navigates another user/session/target;
- client exposes cross-Tenant/private data because scope is bypassed;
- UI can send authoritative protected ownership/lifecycle/attempt values outside contract;
- official result meaning can be changed after confirmed lock due frontend state defect;
- automatic replay can duplicate or corrupt a mutation;
- unsafe route/session bug exposes another role's protected screen/state.

Any P1:

```text
FAIL
```

Integration prohibited.

## P2 — Major

Examples:

- one or more of nine Question types cannot be authored correctly;
- mutation payload does not match backend;
- selected Students are dropped/mis-sent;
- deadline uses device timezone;
- active locked Homework keeps mutating because conflicts are mishandled;
- result-pair null Blitz treated as invalid;
- mobile gains authoring capability;
- router breaks Stage 1–5 paths;
- full test/analyze/build regression;
- meaningful accessibility/state dead-end;
- official Homework inferred incorrectly.

Any P2:

```text
FAIL
```

Integration prohibited.

## P3 — Minor but actionable

Examples:

- localized UX/state inconsistency;
- missing meaningful edge test;
- unnecessary safe request churn;
- small accessibility defect;
- maintainability issue with concrete future risk.

For final Stage 6 Frontend Phase 2 PASS:

```text
P1 = 0
P2 = 0
P3 = 0
```

No unresolved finding is carried into Integration.

---

# 7. Audited Task Map

At execution time fill exact delivery evidence.

| Task | Responsibility | Delivery evidence |
|---|---|---|
| `S06-FE-001` | Homework client domain, read surfaces and routing | `[PR / merge SHA]` |
| `S06-FE-002` | Homework draft metadata, assignment, deadline | `[PR / merge SHA]` |
| `S06-FE-003` | Nine-type Question Builder | `[PR / merge SHA]` |
| `S06-FE-004` | Homework lifecycle and official designation UX | `[PR / merge SHA]` |

Verify every delivered task commit is an ancestor of audited `origin/main`.

---

# 8. Mandatory Full Frontend Test Suite

Run one normal full suite first:

```bash
cd frontend
fvm flutter test
```

Record:

- exit code;
- total tests passed/failed/skipped when reported;
- duration when available.

Do not hide an initial failure.

If the full suite fails:

1. preserve first-run evidence;
2. identify the failing test(s);
3. use narrow diagnostic reruns only;
4. classify application defect vs environment/flaky issue;
5. do not repeatedly rerun the full suite until it happens to pass.

Any unresolved deterministic failure means:

```text
FAIL
```

If production code/test fixes are subsequently merged, the corrected final frontend head requires a new valid full frontend suite PASS.

---

# 9. Mandatory Static Analysis

Run:

```bash
cd frontend
fvm flutter analyze --no-pub
```

Required:

```text
No issues found
```

Any unresolved analyzer error/warning according to project analysis policy prevents PASS.

Do not auto-edit code during the checkpoint.

---

# 10. Mandatory Full Frontend Format Verification

Run a read-only project-wide format check, for example:

```bash
cd frontend
fvm dart format --output=none --set-exit-if-changed lib test integration_test
```

If current repository policy includes additional Dart directories, include them.

Record:

- number of files checked when reported;
- zero changed required.

Do not run a write-format command.

---

# 11. Mandatory Windows Debug Build

Run:

```bash
cd frontend
fvm flutter build windows --debug
```

Required:

```text
PASS
```

Record final artifact/path when reported.

If Windows tooling is unavailable on the assigned execution environment, this checkpoint cannot silently skip the build.

Classify:

- known external environment blocker -> `BLOCKED` until Project Owner runs it in the approved Windows environment;
- application/compiler failure -> `FAIL`.

Do not change production code merely to bypass a workstation-specific build environment defect unless ChatGPT approves a focused fix.

---

# 12. Mandatory Android Debug Build

Run:

```bash
cd frontend
fvm flutter build apk --debug
```

Required:

```text
PASS
```

Record artifact/path when reported.

Use repository FVM pin and approved cache/tooling configuration.

If a cross-drive/cache/Gradle environment issue similar to Stage 5 occurs:

- classify it explicitly;
- do not mislabel it as application defect without evidence;
- remediate the workstation/tool cache, not product code, when appropriate;
- final Phase 2 still requires a valid Android debug build PASS.

---

# 13. Stage-Wide Diff Hygiene

Run:

```bash
git diff --check <stage6_frontend_implementation_base>...origin/main
```

Required:

```text
PASS
```

Also inspect:

```bash
git diff --stat <stage6_frontend_implementation_base>...origin/main
git diff --name-status <stage6_frontend_implementation_base>...origin/main
```

Confirm:

- no backend production implementation entered the frontend block unexpectedly;
- no unrelated platform/admin/student changes beyond justified router regression work;
- no accidental pubspec/lock/package change;
- no generated junk;
- no build artifact committed;
- no secret/debug data;
- no broad formatting churn;
- no tests weakened.

---

# 14. Architecture Review

Verify final flow remains:

```text
Presentation
-> Application / Riverpod Controller
-> Repository contract
-> Repository implementation
-> Remote data source / DTO
-> configured Dio
```

PASS requires:

- Widgets do not call Dio;
- Widgets do not parse JSON;
- Controllers do not build raw URLs;
- DTOs own strict transport parsing;
- repositories expose typed operations;
- no second Router;
- no second HTTP client;
- no second state-management framework;
- no global mutable Homework cache;
- no speculative generic Assessment framework;
- shared timezone boundary reused;
- one Teacher session ownership model remains authoritative.

---

# 15. Domain / DTO Strictness Review

Audit all Stage 6 success payload parsing.

Verify:

- exact key validation;
- canonical UUID validation;
- UTC timestamp validation;
- enum machine values;
- numeric finite/non-negative parsing;
- lifecycle cross-field shape;
- attempt policy fixed `3`;
- result-pair nullable Blitz accepted;
- malformed success becomes invalid-response failure, not partially rendered data.

No raw:

```text
Map<String, dynamic>
```

may become presentation/application authority for typed Homework/Question configuration.

---

# 16. Homework Read Surfaces Review

Verify FE-001 integration:

- Topic Homework section loads independently from Topic detail;
- list loading/error/empty/data states;
- search/status/assignment filters;
- pagination;
- Institution-timezone deadline display;
- Homework detail route;
- desktop/mobile read support;
- 404 unavailable state;
- all nine Question configurations read correctly;
- no raw Student UUID display;
- no raw Matching server key display;
- fixed attempt policy display;
- Topic/Material read behavior remains intact.

Result-pair read failure must not break Homework list/detail.

---

# 17. Router Review

Audit final Teacher route family.

Expected routes:

```text
/teacher
/teacher/topics/new
/teacher/topics/:topicId
/teacher/topics/:topicId/edit

/teacher/topics/:topicId/homework/new
/teacher/topics/:topicId/homework/:homeworkId
/teacher/topics/:topicId/homework/:homeworkId/edit
/teacher/topics/:topicId/homework/:homeworkId/questions
```

Verify exact path parsing.

Desktop Teacher:

- all Stage 5 Teacher routes;
- Homework read;
- Homework create/edit;
- Question Builder.

Mobile Teacher:

- `/teacher`;
- Topic detail;
- Homework detail;
- no Topic create/edit;
- no Homework create/edit;
- no Question Builder.

Verify unsupported authoring deep links redirect to the canonical supported read destination without transient protected form rendering.

Query/fragment sanitization must preserve prior approved Institution Admin behavior.

---

# 18. Session / Stale Async Review

Audit every Stage 6 Riverpod controller.

Required ownership should materially bind to:

```text
TeacherSessionKey
Topic ID
Homework target
Question ID/editor target where needed
route generation
operation/read generation
active request identity
```

Verify stale completion cannot:

- overwrite a newer Homework;
- overwrite another Topic;
- publish an old roster search;
- apply a canceled Student selection;
- close a newer dialog;
- navigate from an obsolete create/edit route;
- move Official badge in a newer session;
- reset newer Question order;
- show stale SnackBar/feedback.

`context.mounted` alone is insufficient for controller-owned operations.

---

# 19. Mutation Uncertainty Review

Audit:

- Homework create;
- Homework edit;
- Question add;
- Question update;
- Question delete;
- Question reorder;
- Homework lifecycle;
- official Homework PUT;
- existing Topic lifecycle Stage 6 extension.

Verify:

- ambiguous outcome never triggers automatic replay;
- exact recognized failure envelope can be treated as definite;
- malformed mutation success becomes outcome unknown;
- GET reconciliation is operation-specific;
- success is shown only when confirmed;
- stale reconciliation cannot affect newer state.

Important operation-specific rules:

### Homework create

Unknown create -> review Topic Homework list; no invented ID.

### Homework edit

Unknown -> GET Homework + request `matches(current)`.

### Question add

Unknown content equality cannot prove success; authoritative review only.

### Question update

Unknown -> target ID + request `matches(currentQuestion)`.

### Question delete

Unknown -> target absence proves success.

### Reorder

Unknown -> exact authoritative Question ID order proves success.

### Lifecycle

Unknown -> target lifecycle status proves success.

### Official PUT

Unknown -> result-pair GET candidate ID proves success.

Any automatic mutation replay is at least P2.

---

# 20. Homework Draft Builder Review

Verify FE-002 behavior:

- desktop create/edit routes only;
- create sends `questions: []`;
- no status/attempt/total protected fields;
- title/instructions canonical trim;
- description empty -> null and non-empty preserved;
- whole-group has `student_ids: []`;
- selected mode requires selected IDs;
- selected IDs sorted/unique;
- deadline uses Institution IANA timezone;
- past deadline not rejected merely by client time;
- attempt count read-only;
- Edit sends changed fields only;
- selected->group explicitly clears recipients;
- dirty-form protection;
- no-op Edit sends no PATCH.

---

# 21. Selected-Student Picker Review

Verify:

- only Teacher roster endpoint;
- rows expose only full name/login;
- selection survives search/pagination;
- canceled picker cannot mutate parent form;
- unresolved selected IDs never display raw UUID;
- unresolved IDs are not falsely labeled definitively ineligible;
- server `student_ids` validation remains authoritative;
- stale roster response cannot apply to closed/reopened picker.

No global Student cache.

---

# 22. Deadline / Timezone Review

Verify reuse of shared:

```text
InstitutionTimezone
```

No second timezone framework/package.

Required:

- current authenticated Institution IANA timezone is authority;
- device timezone not used;
- wall-clock serialization explicit offset;
- DST nonexistent times rejected;
- edit no-op compares absolute instant;
- display uses Institution timezone;
- backend deadline conflict overrides local assumptions.

Check existing Topic `lesson_at` still works.

---

# 23. Nine-Type Question Builder Review

Audit every type end-to-end from typed form -> mutation payload -> authoritative readback.

## Single Choice

- 2–20;
- exactly one correct;
- positions derived from order.

## Multiple Choice

- 2–20;
- >=1 correct;
- no editable max selections.

## True/False

- Boolean correct answer.

## Short Written

- automatic accepted answers;
- manual empty config;
- destructive mode-switch confirmation.

## Open Written

- manual empty config.

## File Based

- fixed PDF/DOCX/PPT/PPTX;
- no editable file limit.

## Matching

- semantic pairs;
- request-only `pair_N`;
- server readback key never mutation authority.

## Ordering

- UI order -> correct positions.

## Fill Blank

- blank key regex/uniqueness;
- accepted answers;
- exact `{{key}}` mapping.

No Student scoring/checking formulas in Flutter.

---

# 24. Question Add/Edit/Delete/Reorder Review

Verify:

- Add uses latest authoritative `N+1`;
- no insertion position form;
- Edit never sends `position`;
- type/mode change sends full configuration;
- no-op Edit sends no request;
- Delete has confirmation;
- server full Homework response replaces local aggregate after success;
- total points displayed from server only;
- local order staging does one mutation;
- while order dirty, add/edit/delete disabled;
- stale server Question set invalidates stale local order;
- no drag-only accessibility;
- max 100 locally respected.

---

# 25. Question Editing Lock Review

Active Homework may expose builder controls because Attempt existence is hidden.

Verify on exact backend:

```text
business_conflict
result_pair_locked
```

frontend:

- refreshes authoritative state;
- disables further Question mutation in current builder instance;
- does not claim hidden Student/Attempt details;
- does not replay.

`assessment_has_no_scoreable_points`:

- does not incorrectly set permanent server lock;
- keeps authoring recoverable.

---

# 26. Homework Lifecycle Review

Verify desktop controls only.

Expected action projection:

```text
draft  -> Activate, Archive
active -> Close
closed -> Archive
archived -> none
```

Official-draft archive special case reviewed separately.

Verify:

- confirmation required;
- no body POST;
- full authoritative Homework returned/accepted;
- list invalidated;
- activation conflict UX;
- close conflict UX;
- archive conflict UX;
- no client-time automatic transition;
- no lifecycle mutation on mobile.

---

# 27. Activation Conflict Review

Verify stable code UX:

```text
assessment_has_no_scoreable_points
assessment_not_assigned
deadline_passed
topic_not_editable
business_conflict
```

Frontend must not independently derive these conditions as authoritative.

Helpful navigation to:

- Manage Questions;
- Edit Homework;
- Back to Topic

is allowed only as working destinations.

No dead control.

---

# 28. Result-Pair / Official Homework Review

Verify typed pair supports:

```text
homeworkAssessmentId required
blitzAssessmentId nullable
cohortSnapshottedAt nullable
lockedAt nullable
```

Critical valid Stage 6 state:

```text
lockedAt != null
blitzAssessmentId == null
```

must parse/render.

Verify:

- GET `data:null` distinct from error;
- official status read independent from list/detail;
- badge only from pair ID match;
- no inference from group/status/title/order;
- selected Homework practice-only;
- active whole-group may be candidate;
- locked/non-null-Blitz pair prevents replacement UI;
- PUT sends only Homework ID;
- no fake Blitz;
- no Stage 8 controls.

---

# 29. Official Draft Archive Review

When pair confirms draft Homework is official:

- Archive predictable-conflict action hidden;
- explanatory text shown.

When official Homework is closed:

- Archive remains available.

When pair read is unavailable:

- frontend must not falsely assume not official;
- backend conflict still reconciled safely if Archive is attempted.

---

# 30. Topic Lifecycle Stage 6 Integration Review

Audit existing Stage 5 Topic lifecycle extension.

Exact new code:

```text
topic_has_open_assessments
```

must be definite for Topic lifecycle.

Verify:

- close/archive failure refreshes authoritative Topic;
- UX directs Teacher to resolve open Homework;
- no automatic Homework cascade;
- no automatic replay;
- other unknown 409 behavior remains unchanged;
- Learning Material mutation coordination remains intact.

This is a high-risk previous-stage regression area.

---

# 31. Mobile Capability Review

Explicit PASS/FAIL:

- [ ] Teacher mobile may read Topic detail.
- [ ] Teacher mobile may read Homework list/detail.
- [ ] Teacher mobile may see official status.
- [ ] Teacher mobile cannot create/edit Topic.
- [ ] Teacher mobile cannot create/edit Homework.
- [ ] Teacher mobile cannot manage Questions.
- [ ] Teacher mobile cannot lifecycle mutate Homework.
- [ ] Teacher mobile cannot Set/Replace official.
- [ ] viewport resize does not grant desktop authoring capability.

Capability must derive from `AppDeviceSurface`, not only width.

---

# 32. Accessibility Review

Audit:

- search labels;
- assignment filters;
- Student picker checkboxes;
- unresolved selections;
- deadline controls;
- lifecycle buttons;
- official buttons/badges;
- Question editor labels;
- correct-answer states;
- add/remove/move controls;
- confirmation dialogs;
- busy progress;
- error association;
- keyboard search submit;
- keyboard Question move up/down;
- no color-only meaning;
- long content/text scaling;
- desktop overflow;
- mobile read overflow.

No drag-only reorder.

Any inaccessible core authoring operation is at least P2/P3 based on impact.

---

# 33. State / Cache Review

Verify no competing authoritative caches.

Expected:

```text
Topic detail state
Homework list state scoped by Topic
Homework detail state scoped by Topic+Homework
Result-pair state scoped by Topic
local form/editor/order state
```

Check:

- mutation successes accept/invalidate narrowly;
- list ordering/pagination not optimistically patched;
- result-pair PUT does not unnecessarily invalidate Homework list;
- pair error not treated as no pair;
- Homework failure not corrupt Topic state;
- route-local feedback is not stored in shared read provider.

---

# 34. API Error-Code Review

Verify only required stable Stage 6 codes are added and used by machine value.

Relevant frontend codes include:

```text
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

No branching on backend human-readable messages.

Check exact error-envelope parsing remains strict.

---

# 35. Privacy Review

Verify UI does not expose:

- raw selected Student UUID;
- internal result-pair IDs where not needed;
- internal Matching server key;
- cross-scope backend details from 404;
- bearer tokens;
- raw private error response;
- URLs with private identifiers in displayed error text.

Teacher roster does not add email/phone.

Frontend UI hiding remains UX only; backend is authorization authority.

---

# 36. Performance / UI State Review

Look for concrete performance/state defects, not speculative micro-optimization.

Audit:

- Homework list pagination;
- no per-row network requests to determine official status;
- one topic-scoped pair provider;
- no roster request per selected Student;
- no uncontrolled rebuild loop from controller side effects;
- no repeated pair refresh on every widget rebuild;
- Question Builder handles max 100 Questions without pathological network-per-row behavior;
- local order moves do not network-call per move.

---

# 37. Previous-Stage Regression Review

Full frontend suite provides broad evidence, but explicitly inspect shared high-risk changes:

```text
app_router.dart
app_route_paths.dart
ApiErrorCodes
InstitutionTimezone
TeacherTopicDetailScreen
TeacherTopic lifecycle data/controller
Teacher test support
```

Confirm Stage 1–5 behavior:

- auth/bootstrap;
- Platform Owner;
- Institution Admin;
- Group/member UI;
- Teacher workspace;
- Topic create/detail/edit/lifecycle;
- Learning Material UI;
- Student Topic/material read;
- protected file flow.

Stage 5 shared-router regression history makes router inspection mandatory.

---

# 38. Required Debug Build Review

Both debug builds are required because Stage 6 adds substantial:

- routes;
- dialogs/forms;
- generic typed models;
- desktop authoring UI;
- mobile read routing.

Verify no platform-specific compile issue is hidden by widget/unit tests.

Required:

```text
Windows debug PASS
Android debug PASS
```

No release build required at this checkpoint unless a concrete Stage 6 risk is discovered.

---

# 39. Security / Integrity Checklist

Explicitly report PASS/FAIL:

- [ ] UI cannot choose Institution/Teacher ownership.
- [ ] Attempt count never writable.
- [ ] Selected Student UUIDs never displayed raw.
- [ ] Device time does not decide deadline authority.
- [ ] Mobile cannot mutate Stage 6 authoring/lifecycle.
- [ ] Mutation unknown state cannot auto-replay.
- [ ] Stale async cannot affect another session/target.
- [ ] Question Matching server key not mutation authority.
- [ ] Homework total remains server-authoritative.
- [ ] Official Homework derived only from result-pair API.
- [ ] Null Blitz staged pair accepted.
- [ ] Locked official selection cannot expose replacement control.
- [ ] Topic lifecycle open-Homework conflict does not cascade.
- [ ] Result-pair read error not treated as no designation.
- [ ] Backend 404 scope remains privacy-safe in UI.

Any FAIL gets a severity finding.

---

# 40. Findings Format

For every finding:

```text
[P1|P2|P3] Short title

Location:
- file/path:line or exact symbol

Problem:
- concrete observed behavior

Impact:
- user/security/data/state consequence

Evidence:
- code/test/verification evidence

Required correction:
- exact required behavior
```

Do not report subjective styling preference as a finding.

---

# 41. Phase 2 Fix Workflow

If any P1/P2/P3 exists:

1. Phase 2 final verdict is not PASS;
2. `S06-INT-001` is blocked;
3. ChatGPT reviews the finding;
4. ChatGPT creates a compact focused fix contract;
5. Codex implements only approved fix;
6. Project Owner delivers fix;
7. current `origin/main` rechecked;
8. affected focused tests rerun;
9. full frontend suite rerun if production code/test behavior changed;
10. analyze rerun;
11. relevant format verification rerun;
12. relevant debug build evidence rerun if change could invalidate build;
13. stage-wide `git diff --check` rerun;
14. read-only changed-area review repeated;
15. only `P1=0,P2=0,P3=0` can PASS.

Do not carry a “conditional PASS” into Integration.

---

# 42. Evidence Validity Rules

Fresh evidence may be reused only if a later change cannot invalidate it.

Examples:

## Docs/task-bookkeeping-only commit after valid frontend evidence

May preserve:

- test suite;
- analyze;
- builds

if reviewer confirms no production/test/dependency/toolchain change.

## Pure Dart UI/router production fix

Invalidates:

- relevant focused tests;
- full frontend suite final evidence;
- analyze;
- format.

A prior native build may remain valid only if the change cannot affect build compilation and the reviewer explicitly justifies reuse. Prefer conservative rerun when uncertain.

## Dependency/FVM/platform change

Invalidates relevant:

- analyze;
- tests;
- both builds.

Final checkpoint record must identify which audited SHA each reused/rerun evidence covers.

---

# 43. Required Final Report

Return one status:

```text
PASS
FAIL
BLOCKED
```

Report:

1. **Audited Git state**
   - frontend implementation base;
   - audited `origin/main`;
   - local main;
   - ahead/behind;
   - clean status.

2. **Backend dependency**
   - Stage 6 Backend Phase 2 PASS evidence.

3. **Delivered frontend tasks**
   - S06-FE-001…004 PR/merge evidence.

4. **Full frontend suite**
   - exact command;
   - result;
   - count/duration if available.

5. **Analyze**
   - exact command/result.

6. **Format**
   - exact command/result.

7. **Windows debug build**
   - exact command/result/artifact.

8. **Android debug build**
   - exact command/result/artifact.

9. **Stage-wide diff**
   - exact range;
   - `git diff --check`.

10. **Read-only architecture/API/state review**
    - concise PASS areas.

11. **Routing/mobile review**
    - explicit.

12. **Nine-type Question Builder**
    - explicit.

13. **Mutation uncertainty**
    - explicit.

14. **Lifecycle/result-pair**
    - explicit null-Blitz staged compatibility.

15. **Security/privacy/accessibility**
    - explicit.

16. **Findings**
    ```text
    P1 = N
    P2 = N
    P3 = N
    ```

17. **Final verdict**.

Do not modify files while producing this report.

---

# 44. PASS Gate

Phase 2 may be marked:

```text
PASS
```

only when all are true:

- Backend Phase 2 PASS;
- S06-FE-001…004 Accepted / Delivered;
- local/main Git state clean and synchronized;
- full frontend suite PASS on evidence valid for final head;
- full analyze PASS;
- full format check PASS;
- Windows debug build PASS;
- Android debug build PASS;
- stage-wide `git diff --check` PASS;
- architecture PASS;
- DTO/API strictness PASS;
- router/session PASS;
- desktop/mobile capability PASS;
- Homework create/edit PASS;
- selected roster/picker PASS;
- deadline/timezone PASS;
- all-nine Question Builder PASS;
- Question mutation/reorder PASS;
- lifecycle PASS;
- result-pair/official UX PASS;
- staged null-Blitz compatibility PASS;
- previous-stage regression review PASS;
- no unresolved P1/P2/P3.

Required:

```text
P1 = 0
P2 = 0
P3 = 0
```

---

# 45. Next Gate

If Phase 2 PASS:

```text
S06-INT-001 — Stage 6 Homework Authoring Real-Stack E2E
```

becomes the next permitted gate.

Integration must reuse valid Backend/Frontend Phase 2 evidence rather than rerunning both complete checkpoints by default.

If integration reveals a production defect:

- prepare focused fix;
- rerun only invalidated checkpoint evidence plus integration scenarios;
- do not blindly rerun every prior suite/build.

If Frontend Phase 2 is not PASS:

```text
S06-INT-001 is prohibited
```

until every finding is resolved and the checkpoint reaches final PASS.
