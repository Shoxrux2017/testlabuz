# Phase 2 Read-Only Block Review Contract — Stage 6 Backend

## 1. Review Metadata

| Field | Value |
|---|---|
| Review ID | `S06-BE-PHASE-2` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Block | `Backend` |
| Status | `Approved — Pending execution` |
| Review mode | `Read-only` |
| Depends on | `S06-BE-001…006` all `Accepted / Delivered` |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |
| Audited implementation baseline | Freeze from Git history immediately before execution |
| Audited production head | Freeze current `origin/main` immediately before execution |
| Verification executor | `Codex / Project Owner as explicitly assigned for the checkpoint` |
| Final classification owner | `ChatGPT` |
| Verdict | `PENDING` |
| Findings | `P1=?, P2=?, P3=?` |
| Next permitted gate on PASS | `S06-FE-001` Implementation Readiness / frontend block |
| Next permitted gate on findings | Focused Backend Phase 2 fix contract(s) only |

This is a **review/checkpoint contract**, not an implementation task.

Do not create a duplicate `CODEX-PROMPT` file.

---

# 2. Purpose

Perform the mandatory Stage 6 Backend Phase 2 checkpoint after the complete backend implementation block has been delivered.

The checkpoint verifies the integrated behavior of:

```text
S06-BE-001
S06-BE-002
S06-BE-003
S06-BE-004
S06-BE-005
S06-BE-006
```

as one backend system rather than as six isolated tasks.

The review must determine whether the complete Stage 6 backend is safe to become the API foundation for frontend implementation.

The checkpoint specifically audits:

- architecture and placement;
- PostgreSQL schema and constraints;
- tenant isolation;
- Teacher authorization;
- Topic/Group/Student relationship boundaries;
- typed Question integrity;
- Homework authoring;
- recipient discovery/snapshot;
- deadline/timezone authority;
- lifecycle behavior;
- scoring-content editing locks;
- concurrency and lock ordering;
- official Homework designation;
- staged result-pair semantics;
- Stage 7/Stage 8 compatibility;
- cross-task interaction;
- previous backend regression safety.

---

# 3. Entry Gate

Do not execute Phase 2 until all six backend tasks have been independently accepted and delivered.

Required state:

```text
S06-BE-001 = Accepted / Delivered
S06-BE-002 = Accepted / Delivered
S06-BE-003 = Accepted / Delivered
S06-BE-004 = Accepted / Delivered
S06-BE-005 = Accepted / Delivered
S06-BE-006 = Accepted / Delivered
```

Before review:

1. switch to `main`;
2. fetch/prune origin;
3. confirm local `main == origin/main`;
4. confirm ahead/behind `0/0`;
5. confirm clean worktree;
6. freeze exact current `origin/main` SHA as the audited production head;
7. identify the exact Stage 6 backend implementation base.

If Git state is not clean/synchronized, the checkpoint is:

```text
BLOCKED
```

until the repository state is made safe.

Do not review an uncommitted or partially delivered backend block.

---

# 4. Determining the Stage 6 Backend Diff Base

Do not assume the planning baseline is automatically the correct production diff base.

At execution time, identify the commit immediately before the first Stage 6 backend **production implementation** entered `main`.

Planning/task-file-only commits that occur before S06-BE-001 production implementation may be included or excluded from the diff, but the reviewer must state the chosen baseline explicitly.

Preferred audited range:

```text
<stage6_backend_implementation_base>...origin/main
```

The range must contain the complete production/test implementation of S06-BE-001…006 and all backend Phase 2 fixes, if any.

Do not omit an intermediate backend task delivery from the audited diff.

---

# 5. Read-Only Rule

Phase 2 execution is read-only.

The reviewer may:

- inspect Git history;
- inspect code;
- inspect migrations;
- inspect routes;
- inspect tests;
- inspect diffs;
- run tests/checks;
- query static repository state;
- report findings.

The reviewer must not:

- edit files;
- auto-fix Pint;
- change migrations;
- change tests;
- stage files;
- commit;
- push;
- open/merge PRs;
- update task bookkeeping;
- silently fix a finding during review.

Use:

```text
./vendor/bin/pint --test
```

not formatting mutation mode.

If a finding requires a fix, stop the review with the finding recorded. ChatGPT prepares a focused Phase 2 fix contract; implementation/delivery happens separately; then the checkpoint is rerun/revalidated against the corrected final backend head.

---

# 6. Reviewer Context Discipline

The reviewer receives this checkpoint contract plus current code/tests.

The reviewer may inspect the six delivered S06 backend task contracts **only as implementation contracts being audited**, not to rediscover or redesign the product.

Do not independently make missing:

- product;
- business;
- API;
- database;
- security;
- tenant;
- lifecycle;
- concurrency;
- Stage 7;
- Stage 8

decisions.

If implementation exposes a genuine unresolved design contradiction, report it as a finding/blocker for ChatGPT.

---

# 7. Severity Model

Use exactly:

## P1 — Critical

Examples:

- cross-Institution data exposure/mutation;
- authorization bypass;
- destructive historical corruption;
- scoring/result meaning can change after Student activity;
- race permits conflicting official cohort/scoring definitions;
- schema allows a critical tenant integrity violation not protected at application level.

Any P1 means:

```text
FAIL
```

and frontend is blocked.

## P2 — Major

Examples:

- required business/API/lifecycle rule missing or materially wrong;
- one or more of nine Question types cannot be authored safely;
- recipient snapshot incorrect;
- fixed three-attempt contract made configurable;
- deadline authority incorrect;
- official whole-group rule bypassable;
- staged result pair cannot be safely completed later;
- meaningful N+1 or concurrency defect;
- required test coverage materially absent.

Any P2 means:

```text
FAIL
```

and frontend is blocked.

## P3 — Minor but actionable

Examples:

- localized architecture/maintainability defect;
- non-critical contract inconsistency;
- missing focused edge test;
- safe but unnecessary query/write churn;
- minor error/resource mismatch.

For this project checkpoint, unresolved P3 also prevents final Phase 2 `PASS`.

Required final PASS state:

```text
P1 = 0
P2 = 0
P3 = 0
```

---

# 8. Audited Task Map

At execution time fill exact PR/merge/SHA evidence.

| Task | Responsibility | Delivery evidence |
|---|---|---|
| `S06-BE-001` | Assessment/Homework persistence foundation | `[PR / merge SHA]` |
| `S06-BE-002` | Typed Question persistence/domain contracts | `[PR / merge SHA]` |
| `S06-BE-003` | Teacher Homework authoring + recipient discovery | `[PR / merge SHA]` |
| `S06-BE-004` | Question mutation + editing integrity | `[PR / merge SHA]` |
| `S06-BE-005` | Homework lifecycle + recipient snapshot + Topic integration | `[PR / merge SHA]` |
| `S06-BE-006` | Official Homework + staged result pair | `[PR / merge SHA]` |

Verify every accepted task's production delivery is an ancestor of audited `origin/main`.

---

# 9. Mandatory Full Backend Regression

Run exactly one normal full backend regression attempt first:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app php artisan test
```

Record:

- exit code;
- total passed/failed/skipped tests;
- assertion count if PHPUnit reports it;
- duration if available.

A clean first-run PASS is the desired checkpoint evidence.

If the full suite fails:

1. classify whether failure is deterministic, environment-related, or suspected flaky;
2. use only narrow diagnostic reruns needed to understand the failure;
3. do not hide the first failure;
4. do not repeatedly rerun the complete suite until it happens to pass;
5. any unresolved deterministic failure means Phase 2 `FAIL/BLOCKED`.

If production code is changed later to fix a Phase 2 finding, the final corrected backend head must obtain a new valid full backend regression PASS before final Phase 2 PASS.

---

# 10. Mandatory Backend Format Check

Run:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app ./vendor/bin/pint --test
```

or, if the established Project Owner execution environment runs directly inside `backend/`:

```bash
./vendor/bin/pint --test
```

Use the environment consistent with the final backend suite evidence.

Record exact PASS/FAIL.

Do not run Pint in write/fix mode during this read-only checkpoint.

---

# 11. Mandatory Stage-Wide Diff Hygiene

Run:

```bash
git diff --check <stage6_backend_implementation_base>...origin/main
```

Required:

```text
PASS
```

Also inspect:

```bash
git diff --stat <stage6_backend_implementation_base>...origin/main
git diff --name-status <stage6_backend_implementation_base>...origin/main
```

Confirm:

- no unexpected frontend implementation entered the backend block;
- no unrelated Stage/business code changed;
- no generated/temporary files;
- no debug artifacts;
- no secrets;
- no weakened tests;
- no accidental migration rewrites;
- no broad formatting churn.

Task/checkpoint `.md` bookkeeping files may appear if delivered separately, but production review must distinguish them from code.

---

# 12. Persistence / Database Review

Audit the final schema as an integrated whole.

## 12.1 Assessment / Homework

Verify:

- direct `institution_id` ownership on high-risk rows;
- same-Institution composite FKs;
- `assessments` supports Homework/Blitz structurally without premature Blitz behavior;
- Homework has no writable/configurable attempt-limit column;
- `total_possible_points >= 0`;
- Homework lifecycle DB shape supports only approved historical states;
- restrictive FKs preserve history.

## 12.2 Recipients / Attempts

Verify:

- one Assessment/Student recipient row;
- direct tenant ownership;
- structural Attempt history is first-class;
- Homework normal attempt structural ceiling cannot enable a fourth attempt;
- no API currently exposes Student attempt execution;
- no fake Attempts are created during recipient snapshot/lifecycle.

## 12.3 Question persistence

Verify:

- all nine types represented;
- normalized typed tables;
- no uncontrolled authoritative JSON/JSONB config;
- type-specific child FKs are tenant-safe;
- positions/uniqueness are structurally sound;
- Fill Blank key constraints;
- no orphan or cross-Tenant typed configuration path.

## 12.4 Staged result pair

Verify:

```text
homework_assessment_id NOT NULL
blitz_assessment_id nullable
```

and:

- one pair row per Topic;
- same-Institution/same-Topic FKs;
- no fake Blitz required;
- schema does not prevent later Stage 8 null-to-valid Blitz completion;
- locked pair may legitimately still have null Blitz.

Any schema mismatch here is at least P2; a tenant/history vulnerability may be P1.

---

# 13. Architecture / Layering Review

Verify Laravel flow remains consistent with project architecture:

```text
HTTP Request/Controller
-> Action/Application
-> focused Domain/Support
-> Eloquent/PostgreSQL
```

Check:

- controllers are thin;
- Form Requests own strict transport validation;
- Actions own transaction/business orchestration;
- models do not perform lifecycle/authorization/scoring workflow;
- Question domain validator is pure and reusable;
- no generic speculative assessment framework;
- no duplicate timezone parser behavior;
- no duplicate point arithmetic;
- no broad repository/service abstraction added without need.

Review namespace/placement consistency across all six tasks.

---

# 14. Teacher Authorization / Tenant Isolation Review

Audit every Teacher endpoint added in Stage 6.

Required Teacher middleware:

```text
auth:sanctum
active.account
password.changed
role:teacher
```

Verify:

- Topic/Group/Homework direct IDs cannot escape Institution scope;
- another Teacher cannot access another Teacher's Topic/Homework/Question;
- current Teacher Group membership is required;
- ended Teacher membership removes normal access;
- foreign UUIDs return privacy-safe 404 where existence must not be disclosed;
- client `institution_id`, `teacher_id`, ownership/status fields cannot expand scope;
- selected Student IDs cannot select foreign/former/inactive Students;
- Question direct ID resolution is scoped through authorized Homework, not globally loaded first;
- result-pair candidate resolution is same Topic + same Teacher + same Institution.

Any cross-Tenant read/write defect is P1.

---

# 15. Teacher Group Student Roster Review

Verify:

- only authorized active Group;
- only current active Students;
- former Student memberships excluded;
- inactive Student users excluded;
- minimal fields only;
- no email/phone/private relationship leakage;
- deterministic pagination/search;
- literal LIKE escaping;
- no N+1.

---

# 16. Homework Authoring Review

Verify:

- create allowed only under authorized draft/active Topic;
- newly created Homework always draft;
- protected fields rejected;
- Group draft has no premature snapshot;
- selected draft persists exact eligible direct recipients;
- selected Homework remains practice-only;
- nested initial Questions can be empty in draft;
- nested all-nine type create is valid;
- transaction rolls back complete aggregate on child failure;
- total points are server-derived;
- exact decimal point math is used;
- no binary-float authority;
- `attempt_policy.normal_attempts = 3`;
- no writable `attempt_limit`;
- full detail reconstructs normalized Question config safely;
- no child internal IDs leak as public authoring authority.

---

# 17. Deadline / Institution Timezone Review

Verify one shared institution educational date-time parser is used consistently.

Required:

- Teacher input requires explicit RFC3339 numeric offset;
- offset/local wall-clock must match Institution IANA timezone;
- persisted deadline is UTC;
- API returns UTC plus Institution timezone context;
- device clock/timezone never authoritative;
- draft may hold past deadline;
- activation requires `deadline_at > authoritative server now`;
- timezone changes do not rewrite stored absolute deadline;
- Stage 5 Topic `lesson_at` behavior remains unchanged after parser refactor.

---

# 18. Typed Question Domain Review

Audit all nine Question types end to end from request validation to normalized readback.

## Single Choice

- >=2 options;
- exactly one correct;
- automatic only.

## Multiple Choice

- >=2 options;
- >=1 correct;
- automatic only;
- `max_selections` derived, not persisted/writable.

## True/False

- one Boolean correct value;
- automatic only.

## Short Written

- automatic requires accepted answers;
- manual has no accepted-answer config;
- no fuzzy/AI behavior.

## Open Written

- manual only;
- no answer-key config.

## File Based

- manual only;
- fixed PDF/DOCX/PPT/PPTX;
- no per-Question upload size.

## Matching

- correct one-left/one-right pair identity;
- request correlation key not trusted/persisted as authorization;
- readback deterministic.

## Ordering

- >=2 items;
- canonical correct positions.

## Fill-in-the-Blank

- strict blank keys;
- exact `{{blank_key}}` correspondence;
- accepted values per blank.

Check fixed authoring limits, unknown-key rejection, canonical 1-based positions, and absence of uncontrolled blob persistence.

---

# 19. Question Mutation / Editing Integrity Review

Verify:

- add/update/delete/reorder endpoints exist;
- Stage 6 shared Assessment routes accept Homework only;
- add safely shifts positions;
- PATCH cannot directly set position;
- reorder owns ordering changes;
- type/mode changes require complete valid configuration;
- obsolete typed rows are removed transactionally;
- delete compacts positions;
- active Homework cannot become zero-question/zero-point;
- add/update/delete recalculate authoritative total exactly;
- reorder preserves total;
- no-op PATCH/reorder cause no write/timestamp churn;
- semantic Question mutation touches Assessment aggregate timestamp;
- any Assessment Attempt locks all scoring/fairness Question content;
- defensive `result_pair_locked` works.

---

# 20. Homework Lifecycle Review

Verify exact lifecycle:

```text
draft -> active
draft -> archived
active -> closed
closed -> archived
```

and no reopen/direct active-archive.

Check:

- activate active = idempotent;
- close closed = idempotent;
- archive archived = idempotent;
- no-op preserves timestamps/recipients/points;
- activation revalidates persisted Question aggregate;
- activation recalculates total;
- activation requires positive total;
- activation deadline check;
- no Attempts created by activation;
- archive preserves historical rows;
- no hidden cascade.

---

# 21. Recipient Snapshot Review

## Group

At activation:

- derive current active Student/current membership set after locks;
- require at least one;
- create exactly one snapshot row per eligible Student;
- source = group;
- no former/inactive/foreign Student;
- later Group membership changes do not rewrite active snapshot.

## Selected

At activation:

- preserve selected recipient row IDs/assigned_at;
- revalidate exact set;
- any Student becoming ineligible blocks activation;
- do not silently drop/rewrite cohort.

Check concurrent membership removal/deactivation behavior.

---

# 22. Stage 6 Close Boundary Review

Stage 6 has structural Attempts but no Student answer execution.

Verify close currently:

- does not fabricate Attempt finalization;
- does not create empty Attempts;
- blocks if structural `in_progress` Attempt exists;
- preserves completed/finalized history.

Confirm code structure allows Stage 7 to insert the required finalizer before public Attempt start is released.

This temporary Stage 6 guard is acceptable only because no public Stage 7 execution exists yet.

If Student attempt execution accidentally became public in the Stage 6 backend while close still only blocks, classify as P1/P2 depending on reachable data-integrity impact.

---

# 23. Topic Lifecycle Integration Review

Verify Stage 5 Topic behavior remains compatible.

A real Topic close/archive must reject if any child Homework is:

```text
draft
active
```

with:

```text
409 topic_has_open_assessments
```

Check:

- no hidden cascade;
- closed/archived Homework does not block parent transition;
- same-target Topic lifecycle remains idempotent;
- Topic activation does not require Homework;
- Topic close/archive versus Homework activation is race-safe.

---

# 24. Official Homework / Staged Result-Pair Review

Verify:

- GET returns `data:null` when not designated;
- Stage 6 PUT accepts only `homework_assessment_id`;
- candidate must be same Topic/Teacher/Institution Homework;
- candidate must be group assignment;
- selected Homework cannot be official;
- candidate is draft/active for new designation;
- candidate with any Attempt cannot newly become official;
- active candidate adopts existing persisted recipient snapshot;
- draft candidate cohort remains null until activation;
- designated draft activation sets pair cohort timestamp atomically;
- no separate cohort table duplicates Student identity unnecessarily;
- replacement allowed only before activity/lock and while Blitz slot null;
- old Homework history/recipient rows preserved;
- same-target PUT no-op even after later close/archive/lock;
- official Homework cannot PATCH group -> selected;
- designated draft cannot archive until replaced;
- designated closed may archive historically;
- designation alone does not freeze pre-attempt Questions.

---

# 25. Stage 7 Compatibility Audit

This checkpoint must explicitly confirm the backend leaves a viable Stage 7 implementation path.

Required frozen boundaries:

## First Attempt serialization

Stage 7 must:

```text
lock Assessment
```

before inserting first Attempt.

For official Homework it must also:

```text
lock topic_result_pair
require official cohort snapshot
set locked_at once
then insert Attempt
```

Verify Stage 6 code does not make this impossible or require a schema rewrite.

## Fixed attempts

Verify structural/API design preserves exactly:

```text
3 normal Homework attempts
```

and no admin/Teacher/client field can override it.

## Close extension

Verify Stage 7 can replace the temporary `in_progress` close guard with full auto-finalization without changing the public lifecycle endpoint.

Any Stage 6 decision that makes Stage 7 require a breaking Homework schema/API redesign is at least P2.

---

# 26. Stage 8 Compatibility Audit

This checkpoint must explicitly confirm staged result-pair correctness.

Required:

```text
blitz_assessment_id = null
```

is valid after Stage 6, including when:

```text
locked_at IS NOT NULL
```

Future Stage 8 must be able to fill:

```text
null -> official Blitz UUID
```

in the **same pair row**.

This null-to-valid Blitz operation is pair completion, not replacement.

Verify Stage 6 code does not:

- block all changes whenever `locked_at` non-null at a database level;
- require pair unlock before setting Blitz;
- create fake Blitz;
- create a second pair;
- tie the official cohort to current Group membership after snapshot.

If the schema/application contract would prevent Stage 8 completion after Homework activity, classify P2.

---

# 27. Cross-Task Lock-Ordering Audit

Build a concrete lock-order matrix from implemented Actions.

Expected Teacher parent order should be materially consistent around:

```text
Group
-> current TeacherGroupMembership
-> Topic
-> Assessment
-> HomeworkAssignment
-> TopicResultPair / Attempts / Questions / Recipients as task-specific children
```

Audit interactions:

- Homework PATCH vs first Attempt fixture;
- Question mutation vs first Attempt fixture;
- Homework activate vs Topic close/archive;
- Homework activate vs selected membership removal;
- result-pair set/replace vs activation;
- result-pair replace vs first Attempt fixture;
- concurrent Question add/reorder;
- concurrent same-target lifecycle commands.

Look for cycles/inconsistent reverse ordering that could deadlock or allow stale authorization.

A plausible high-risk deadlock/data-race is P2 or P1 according to impact.

---

# 28. API / Error Contract Review

Verify consistent envelopes/statuses.

Key Stage 6 machine codes include:

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

Check:

- existence privacy;
- no SQL/stack leakage;
- strict JSON object/allowlist handling;
- mutation query rejection;
- lifecycle empty-body handling;
- resources return server-authoritative state;
- no client parses human message as authority requirement.

---

# 29. Query / Performance Review

Audit obvious N+1 or unbounded-query risks.

At minimum:

- Homework list uses question count without per-row Question query;
- Homework detail loads typed Question graph in bounded relation queries;
- roster is one scoped paginated query;
- active recipient snapshot does not query membership one Student at a time;
- Question serialization does not issue per-Question type queries;
- result-pair GET/PUT uses bounded eager loading;
- lifecycle validation of up to 100 Questions remains bounded and intentional.

No micro-optimization requirement; report meaningful scale/pathology only.

---

# 30. Previous Backend Regression Review

The full backend suite is the principal evidence that Stage 1–5 behavior remains intact.

Read-only diff review must additionally check likely shared-impact areas:

- `routes/api.php`;
- `InstitutionLessonAt` refactor;
- Topic lifecycle Actions;
- Topic/User/Institution/Assessment relationships;
- authentication/Teacher middleware;
- existing Group membership semantics;
- Institution assessment settings fixed-attempt response;
- Stage 5 Topic/Material behavior.

Stage 6 must not silently change:

- Stage 5 Topic authorization;
- Topic activation material prerequisite;
- protected material/file access;
- Group relationships;
- Institution settings;
- fixed Homework attempt count already exposed as read-only policy.

---

# 31. Security / Data Integrity Review Checklist

Explicitly answer PASS/FAIL for:

- [ ] Cross-Institution Homework direct ID cannot read/write.
- [ ] Cross-Institution Question direct ID cannot read/write.
- [ ] Cross-Institution selected Student cannot be assigned.
- [ ] Another Teacher cannot mutate Topic Homework.
- [ ] Former Teacher membership removes access.
- [ ] Group snapshot cannot include foreign/former/inactive Student.
- [ ] Client cannot choose Institution/Teacher/status/total/attempt count.
- [ ] Student activity prevents scoring-content mutation.
- [ ] Official Homework cannot become selected-student.
- [ ] Locked official Homework cannot be replaced.
- [ ] Topic cannot close/archive with open Homework.
- [ ] Historical referenced rows cannot be destructively deleted.
- [ ] No fake Attempt/fake Blitz is generated.
- [ ] Deadline authority is server/UTC based.
- [ ] Concurrency does not split scoring definition from Attempt history.

Any FAIL must have a severity finding.

---

# 32. Findings Format

For every finding report:

```text
[P1|P2|P3] Short title

Location:
- file/path:line or exact symbol

Problem:
- concrete observed behavior

Impact:
- why it matters

Evidence:
- code/test/diff evidence

Required correction:
- exact behavioral requirement, not implementation guess
```

Do not mix multiple unrelated defects into one finding.

Do not report speculative style preferences as findings.

---

# 33. Fix Workflow

If any P1/P2/P3 exists:

1. final Phase 2 verdict is not PASS;
2. frontend is blocked;
3. ChatGPT evaluates the finding;
4. ChatGPT prepares one or more compact focused fix implementation contracts;
5. Codex implements only approved fixes;
6. Project Owner delivers fixes;
7. ChatGPT re-checks final `origin/main`;
8. rerun affected focused tests;
9. rerun final mandatory full backend suite if production code changed;
10. rerun Pint;
11. rerun stage-wide `git diff --check`;
12. re-review changed/cross-task areas;
13. only `P1=0,P2=0,P3=0` may become PASS.

Do not “conditionally pass” unresolved findings into frontend implementation.

---

# 34. Evidence Validity

Workflow v3 allows reuse of evidence only when the evidence remains valid.

Examples:

A docs/task-bookkeeping-only follow-up commit may preserve prior backend suite evidence if:

- production code did not change;
- backend tests did not change materially;
- runtime/dependency/config did not change;
- reviewer explicitly verifies this.

Any production backend fix after the full suite invalidates the prior final-suite evidence for the corrected head.

The final Phase 2 record must clearly identify which commit the full-suite PASS actually covers.

---

# 35. Required Final Report

Return one status:

```text
PASS
FAIL
BLOCKED
```

Then provide:

1. **Audited Git state**
   - implementation base;
   - audited `origin/main`;
   - clean/synced confirmation.

2. **Delivered backend tasks**
   - exact PR/merge evidence for S06-BE-001…006.

3. **Full backend suite**
   - exact command;
   - result;
   - tests/assertions/duration when available.

4. **Pint**
   - exact command/result.

5. **Stage-wide diff hygiene**
   - exact range;
   - `git diff --check` result.

6. **Read-only review**
   - concise PASS areas;
   - findings with P1/P2/P3 severity.

7. **Security/tenant verdict**
   - explicit.

8. **Concurrency/locking verdict**
   - explicit.

9. **Stage 7 compatibility**
   - explicit.

10. **Stage 8 staged-pair compatibility**
    - explicit.

11. **Finding totals**
   ```text
   P1 = N
   P2 = N
   P3 = N
   ```

12. **Final verdict**
   - `PASS` only when all findings are zero and required verification passes.

Do not modify any file while producing this review.

---

# 36. PASS Gate

Phase 2 may be marked:

```text
PASS
```

only if all are true:

- S06-BE-001…006 accepted/delivered;
- final audited Git state clean/synchronized;
- full backend suite PASS on evidence valid for final production head;
- Pint PASS;
- stage-wide `git diff --check` PASS;
- architecture review PASS;
- API review PASS;
- persistence/schema review PASS;
- authorization/tenant review PASS;
- Question all-nine review PASS;
- lifecycle/deadline/recipient review PASS;
- official Homework/staged pair review PASS;
- concurrency/lock-order review PASS;
- Stage 7 compatibility PASS;
- Stage 8 compatibility PASS;
- no unresolved P1/P2/P3.

Required totals:

```text
P1 = 0
P2 = 0
P3 = 0
```

---

# 37. Next Gate

If Phase 2 is `PASS`, the next permitted gate is:

```text
S06-FE-001 — Homework Client Domain, Read Surfaces and Routing
```

Before preparing/implementing it, ChatGPT must re-check current GitHub `main`, the final Stage 6 backend API implementation, relevant frontend code/tests, and task status.

If Phase 2 is not PASS:

```text
frontend implementation is prohibited
```

until all findings are fixed and Backend Phase 2 reaches final PASS.
