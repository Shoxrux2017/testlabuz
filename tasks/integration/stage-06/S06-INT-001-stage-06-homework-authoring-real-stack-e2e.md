# S06-INT-001 — Stage 6 Homework Authoring Real-Stack E2E Verification

## 1. Metadata and Execution Gate

| Field | Value |
|---|---|
| Task ID | `S06-INT-001` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Area | `Integration / real-stack E2E` |
| Status | `Approved` |
| Depends on | Stage 6 Backend Phase 2 `PASS`; Stage 6 Frontend Phase 2 `PASS` |
| Planning/readiness baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` immediately before Codex execution |
| Verification model | `Project Workflow v3 — Lean Verification` |
| Codex ownership | Integration assets + focused asset verification only |
| Real-stack automated execution | `Project Owner` |
| Windows real-stack process | Required |
| Android real-stack smoke | Required — read-only Teacher Stage 6 boundary |
| Routine Git/GitHub delivery | `Project Owner` |
| Implementation Readiness Gate | `PASS — planning contract`; execution remains Phase-2 gated |
| Next gate on final PASS | `Stage 6 Closure Review` |

This file is the complete task-specific implementation contract. Do not create a duplicate `CODEX-PROMPT` file.

Before Codex execution, ChatGPT must re-check current `origin/main` after both Stage 6 Phase 2 checkpoints have passed and supply/freeze that exact SHA as the implementation baseline.

Codex may start only when safe Git preflight proves:

```text
current branch = main
local main == origin/main == supplied implementation baseline
ahead/behind = 0/0
worktree = clean
origin = expected Shoxrux2017/testlabuz repository
Backend Phase 2 = PASS
Frontend Phase 2 = PASS
```

If `origin/main` advances after the implementation baseline is frozen, stop and report the new SHA. ChatGPT decides whether the change is evidence-safe bookkeeping or requires contract revalidation.

---

# 2. Integration Principle

This task verifies the already-delivered production behavior.

It may create only integration/test assets.

It must **not** repair production code.

If a real-stack run exposes a production defect:

```text
INTEGRATION FINDING
```

Stop the affected scenario, preserve exact evidence, and report the production boundary.

ChatGPT then creates a separate focused production-fix contract.

Do not silently patch:

```text
backend/app/**
frontend/lib/**
backend/routes/**
backend/database/migrations/**
```

inside this integration task.

Fresh Backend/Frontend Phase 2 evidence remains valid.

Do **not** rerun:

- full backend suite;
- full frontend suite;
- full frontend analyze;
- full format checkpoints;
- standalone Windows debug build;
- standalone Android debug build;
- Backend Phase 2;
- Frontend Phase 2;
- broad previous-Stage E2E

merely because Integration starts.

Only rerun evidence invalidated by an actual integration fix.

---

# 3. Goal

Prove the complete Stage 6 Teacher Homework authoring vertical through the real stack:

```text
Flutter Windows
-> production GoRouter/Riverpod/controllers
-> production repositories/DTOs
-> production configured Dio
-> Laravel/Sanctum
-> PostgreSQL testlabuz_testing
```

and independently verify:

- database persistence;
- Tenant isolation;
- Teacher ownership/current Group authorization;
- recipient integrity;
- exact nine-type Question persistence;
- server-derived points;
- Homework lifecycle;
- official Homework staged result pair;
- `blitz_assessment_id = null` compatibility;
- scoring-content lock behavior using structural Stage 6 Attempt fixtures;
- Topic lifecycle integration;
- state persistence after backend restart;
- Android real-stack read-only capability boundary.

---

# 4. Included Integration Coverage

## 4.1 Real Windows Flutter vertical

Exercise through production UI/client code:

- real Teacher login;
- active Topic detail;
- Homework empty/list state;
- whole-group draft Homework create;
- selected-Student practice Homework create/edit/archive;
- Institution-timezone deadline input/display;
- fixed three-attempt display;
- all nine Question types;
- automatic and manual Short Written variants;
- Question add;
- Question edit;
- Question delete;
- Question reorder;
- server-authoritative total points;
- official Homework designation while draft;
- activation;
- Group recipient snapshot;
- official cohort snapshot;
- Topic-close blocked by open Homework;
- close;
- archive;
- official historical badge after archive;
- Topic close after open Homework is resolved;
- locked official fixture read;
- Question lock conflict against structural Attempt/result-pair state;
- state after backend application restart.

## 4.2 Direct real-API security/business matrix

Verify with real Sanctum-authenticated actors:

- unauthenticated denial;
- wrong-role denial;
- same-Institution unrelated Teacher denial;
- cross-Institution Topic/Homework/Question denial;
- foreign Student selection cannot expand Tenant scope;
- selected-Student Homework cannot become official;
- locked official Homework cannot be replaced;
- locked pair remains valid with null Blitz;
- in-progress structural Attempt blocks Stage 6 close;
- Question mutation blocked after activity/locked pair;
- expired valid draft cannot activate;
- same-target result-pair PUT idempotency;
- no fake Blitz;
- no fake empty Attempts.

## 4.3 Independent DB oracle

Verify final persisted state independently of Flutter's displayed state.

## 4.4 Android manual real-stack smoke

Verify Teacher can read Stage 6 Homework/Official state and cannot access desktop authoring controls.

---

# 5. Explicit Non-Goals

Do not implement or verify as Stage 6 functionality:

- Student Homework execution;
- Student Attempt start through public API;
- Student answer save;
- Student final submit;
- file-answer upload;
- answer checking;
- manual marking;
- official Student score selection;
- Blitz creation/designation;
- Topic score/category;
- result release;
- Parent result UI;
- Stage 7 close auto-finalization from real saved answers;
- Stage 8 Blitz-slot completion;
- Stage 9 scoring engine;
- AI/fuzzy answer checking;
- production test-only routes;
- auth bypass;
- database mutation endpoint;
- hidden session injection;
- new E2E framework;
- new Docker repository configuration;
- full checkpoint reruns.

The structural `assessment_attempts` rows used by fixtures are only to verify Stage 6 editing/close/result-pair locks. They are not a public Attempt workflow.

---

# 6. Codex Read Boundary

Codex may read only:

1. this approved integration contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. `frontend/AGENTS.md`;
5. current Stage 6 production source/tests/configuration directly required to implement integration assets;
6. existing Stage 2–5 **source integration assets** as implementation patterns only.

Allowed pattern sources include:

```text
backend/database/seeders/Stage2E2eSeeder.php
backend/database/seeders/Stage3E2eSeeder.php
backend/database/seeders/Stage4E2eSeeder.php
backend/database/seeders/Stage5E2eSeeder.php

backend/tests/Feature/Seeders/Stage2E2eSeederTest.php
backend/tests/Feature/Seeders/Stage3E2eSeederTest.php
backend/tests/Feature/Seeders/Stage4E2eSeederTest.php
backend/tests/Feature/Seeders/Stage5E2eSeederTest.php

frontend/integration_test/stage2_*
frontend/integration_test/stage3_*
frontend/integration_test/stage4_*
frontend/integration_test/stage5_*
frontend/integration_test/run_stage2_*
frontend/integration_test/run_stage3_*
frontend/integration_test/run_stage4_*
frontend/integration_test/run_stage5_*
frontend/integration_test/verify_stage2_*
frontend/integration_test/verify_stage3_*
frontend/integration_test/verify_stage4_*
frontend/integration_test/verify_stage5_*
frontend/integration_test/prepare_stage2_*
frontend/integration_test/prepare_stage3_*
frontend/integration_test/prepare_stage4_*
frontend/integration_test/prepare_stage5_*
```

Codex must **not** read:

- roadmap/product docs;
- architecture/database/API docs;
- Stage indexes;
- previous implementation contracts;
- Phase 2 review files;
- closure reviews;
- prior integration task contracts

to rediscover requirements.

This contract already contains the Stage 6 integration behavior.

---

# 7. Production Boundaries to Reuse

Inspect only directly relevant final code under:

```text
backend/routes/api.php
backend/app/Actions/Teacher/**
backend/app/Domain/Assessment/**
backend/app/Support/Teacher/**
backend/app/Support/Assessment/**
backend/app/Models/**
backend/app/Http/Requests/Teacher/**
backend/app/Http/Resources/Teacher/**
backend/tests/Feature/Teacher/**
backend/tests/Feature/Persistence/**

frontend/lib/app/router/**
frontend/lib/core/network/**
frontend/lib/core/time/**
frontend/lib/features/auth/**
frontend/lib/features/teacher/**
frontend/test/features/teacher/**
```

The integration test must exercise production:

```text
GoRouter
AuthSessionController
TeacherSessionKey
Teacher Homework repositories
Teacher result-pair repository
configured Dio
strict DTO parsing
Laravel Sanctum middleware
real PostgreSQL
```

Do not substitute fake repositories in the actual E2E process.

---

# 8. Dedicated Stage 6 Runtime

## 8.1 Project Owner provisioning

Provision outside repository changes:

```text
backend container:
testlabuz-stage6-e2e-app

container port:
8000/tcp

API:
http://127.0.0.1:<ApiPort>/api/v1

Laravel:
APP_ENV=testing
APP_DEBUG=false
DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=testlabuz_testing

PostgreSQL container:
testlabuz-postgres-1

PostgreSQL image:
postgres:18.4

Docker network:
testlabuz_default

backend source mount:
current repository backend directory
-> /var/www/html
read/write bind mount
```

The app container must be restartable:

```text
AutoRemove = false
WorkingDir = /var/www/html
```

No new repository `docker/**` change is allowed.

Stage 6 does not require a dedicated private-file volume because no Stage 6 Student file submission exists.

Existing normal Laravel storage may remain configured by the current project runtime, but Stage 6 runtime guard does not claim file-storage persistence as an integration requirement.

---

# 9. Runtime Guard Assets

Create:

```text
frontend/integration_test/stage6_runtime_guard.ps1
frontend/integration_test/verify_stage6_runtime_guard.ps1
```

The guard must fail closed unless it proves the approved runtime identity.

## 9.1 Container/source identity

Require:

- exact container name:
  `testlabuz-stage6-e2e-app`;
- exactly one inspected backend container;
- running;
- `AutoRemove = false`;
- working directory:
  `/var/www/html`;
- exactly one read/write bind mount owns `/var/www/html`;
- bind source resolves to the current repository `backend` directory.

Reject ambiguous/missing/read-only/wrong mounts.

## 9.2 API target identity

Accept only exact:

```text
http://127.0.0.1:<ApiPort>/api/v1
```

Reject:

- HTTPS;
- localhost;
- IPv6 loopback;
- wildcard host;
- credentials/userinfo;
- query;
- fragment;
- trailing slash;
- alternate API version/path;
- implicit port;
- wrong port.

`8000/tcp` must be published exactly once to:

```text
127.0.0.1:<ApiPort>
```

## 9.3 Laravel identity

Probe through the real container and require:

```text
app()->environment() = testing
config('app.debug') = false
config('database.default') = pgsql
PDO driver = pgsql
current_database() = testlabuz_testing
```

No current migration may be pending.

Do not print environment values wholesale.

## 9.4 PostgreSQL identity

Require:

```text
container = testlabuz-postgres-1
running = true
image = postgres:18.4
network includes testlabuz_default
backend network includes testlabuz_default
DB_HOST = postgres
```

## 9.5 HTTP boundary

Unauthenticated:

```text
GET /api/v1/auth/me
Accept: application/json
```

must return:

```text
401
code = authentication_required
errors = {}
```

`request_id` may be present.

---

# 10. Runtime Guard Negative Matrix

`verify_stage6_runtime_guard.ps1` must test pure guard functions and the actual approved runtime.

At minimum reject:

- malformed/non-loopback API target;
- localhost/IPv6/wildcard target;
- query/fragment/trailing slash;
- wrong path/port;
- wrong/missing/stopped/ambiguous backend container;
- `AutoRemove=true`;
- wrong working directory;
- missing/read-only/wrong source bind;
- wildcard/duplicate/inactive port mapping;
- wrong environment/debug state;
- wrong database driver/name/host;
- pending migrations;
- wrong/missing/stopped PostgreSQL container;
- wrong PostgreSQL image;
- missing Docker network;
- wrong `/auth/me` boundary.

Do not print:

- database passwords;
- app secrets;
- bearer tokens;
- Docker env dump;
- raw inspection JSON containing secrets.

---

# 11. Flutter Toolchain Guard

The Stage 6 runner must verify the supplied Flutter executable exists and reports the exact repository-pinned framework version.

Planning pin:

```text
3.44.7
```

At implementation time the runner must read/reflect the final accepted `.fvmrc` pin, not hardcode a stale planning version if the repository intentionally changed it before Stage 6 integration.

Preferred safe rule:

- compare supplied Flutter `--version --machine` framework version to `.fvmrc`;
- fail if they differ.

Do not change `.fvmrc` in this integration task.

---

# 12. Stage 6 Seeder Assets

Create:

```text
backend/database/seeders/Stage6E2eSeeder.php
backend/tests/Feature/Seeders/Stage6E2eSeederTest.php
```

The seeder must be deterministic and rerun-safe.

---

# 13. Seeder Fail-Closed Environment Guard

Before mutation, the seeder must require:

```text
app environment = testing
database driver = pgsql
current_database() = testlabuz_testing
STAGE6_E2E_PASSWORD exists
STAGE6_E2E_PASSWORD is non-blank
```

If any check fails:

- throw;
- write nothing.

Do not accept production/development DB.

Do not print the password.

---

# 14. Reserved Stage 6 Fixture Namespace

Use:

```text
UUID prefix:
06000000-...

login prefix:
e2e_s06_

display/title prefix:
E2E S06

password environment:
STAGE6_E2E_PASSWORD
```

Every owned row must be identified by an explicit manifest, not merely prefix matching.

Do not delete unrelated rows based only on string prefixes.

Seeder cleanup/reseed must delete only manifest-owned Stage 6 rows in correct FK-safe child-to-parent order.

---

# 15. Fixture Institutions

Create exactly these logical Institutions.

## Target Institution

```text
name: E2E S06 Target Institution
timezone: Asia/Tashkent
active
```

Assessment settings must preserve current product defaults/contracts and, critically:

```text
Homework normal attempts = fixed/read-only 3
```

Do not invent future Stage 7/8 settings.

## Foreign Institution

```text
name: E2E S06 Foreign Institution
timezone: Asia/Tashkent
active
```

Used only for Tenant denial.

No cross-Institution fixture relation may exist.

---

# 16. Target Actors

Create active users with:

```text
must_change_password = false
```

| Login | Role | Purpose |
|---|---|---|
| `e2e_s06_target_admin` | Institution Admin | real admin actor if membership mutation/security setup needs API |
| `e2e_s06_target_teacher` | Teacher | main Windows/Android actor |
| `e2e_s06_student_alpha` | Student | current eligible recipient |
| `e2e_s06_student_beta` | Student | current eligible recipient |
| `e2e_s06_student_ended` | Student | ended Group membership, must not snapshot |
| `e2e_s06_student_inactive` | Student | inactive user, must not snapshot |
| `e2e_s06_unrelated_teacher` | Teacher | same-Institution unauthorized Teacher |
| `e2e_s06_unrelated_student` | Student | same-Institution unrelated Student |

`student_inactive` must have:

```text
is_active = false
```

All other Target actors active.

---

# 17. Foreign Actors

Create:

| Login | Role |
|---|---|
| `e2e_s06_foreign_admin` | Institution Admin |
| `e2e_s06_foreign_teacher` | Teacher |
| `e2e_s06_foreign_student` | Student |

All belong only to Foreign Institution.

---

# 18. Groups and Memberships

## 18.1 Main Target Group

```text
E2E S06 Main Group
status = active
```

Current Teacher membership:

```text
target_teacher
ended_at = null
```

Current Student memberships:

```text
student_alpha
student_beta
```

Ended membership:

```text
student_ended
ended_at != null
```

Inactive user may have current membership:

```text
student_inactive
ended_at = null
```

but must still be ineligible because user is inactive.

Unrelated Teacher has **no** current membership in Main Group.

Unrelated Student has no current membership.

## 18.2 Unrelated Target Group

Active.

Current Teacher:

```text
unrelated_teacher
```

Current Student:

```text
unrelated_student
```

Used for same-Institution scope isolation.

## 18.3 Foreign Group

Active.

Owned only by Foreign Institution with foreign Teacher/Student memberships.

---

# 19. Topics

Seed deterministic Topics.

## `authoring_topic`

```text
title = E2E S06 Authoring Topic
institution = Target
teacher = target_teacher
group = Main Group
status = active
activated_at != null
```

This is the main Windows authoring flow Topic.

## `locked_topic`

```text
title = E2E S06 Locked Topic
Target / target_teacher / Main Group
status = active
```

Contains a pre-seeded locked official Homework with structural Attempt.

## `expired_topic`

```text
title = E2E S06 Expired Deadline Topic
Target / target_teacher / Main Group
status = active
```

Contains a valid draft Homework whose deadline is already past.

## `unrelated_topic`

```text
Target Institution
unrelated_teacher
Unrelated Group
status = active
```

## `foreign_topic`

```text
Foreign Institution
foreign_teacher
Foreign Group
status = active
```

All seeded active Topics must have valid lifecycle timestamp shape.

Do not depend on Stage 5 E2E fixtures.

---

# 20. Seeded Locked Official Homework

Under `locked_topic`, create:

```text
title = E2E S06 Locked Official Homework
type = homework
assignment_mode = group
status = active
total_possible_points = exact Question sum
```

Include at least one valid automatic Question, e.g.:

```text
true_false
prompt = "DNS uses domain names."
points = 1
correct_value = true
```

Create active Group recipient snapshot exactly for:

```text
student_alpha
student_beta
```

Exclude:

```text
student_ended
student_inactive
```

Create one Topic result pair:

```text
homework_assessment_id = locked Homework
blitz_assessment_id = null
cohort_snapshotted_at != null
locked_at != null
```

This locked/null-Blitz shape is intentionally valid and must survive frontend parsing.

Create one structural Attempt for `student_alpha`:

```text
attempt_number = 1
status = in_progress
official_score_eligible = true
possible_points = locked Homework total
started_at < locked_at or equal according to final schema-compatible fixture order
```

Ensure all Attempt/recipient IDs and Institution relations satisfy final schema.

No answer rows are created.

---

# 21. Seeded Expired Draft Homework

Under `expired_topic`, create:

```text
title = E2E S06 Expired Draft Homework
assignment_mode = group
status = draft
deadline_at < fixed/current authoritative runtime now
```

To avoid time-fragile fixtures, derive:

```text
deadline_at = seeder server now - 1 day
```

Include one valid scoreable Question.

No recipient snapshot.

No Attempts.

Direct API activation must return:

```text
409 deadline_passed
```

---

# 22. Foreign Homework Fixture

Under `foreign_topic`, create a valid draft or active whole-group Homework and at least one valid Question.

Used for:

- cross-Tenant Homework GET denial;
- cross-Tenant Question mutation denial;
- result-pair candidate denial.

No Target actor relation may point to it.

---

# 23. Seeder Repeatability

Running `Stage6E2eSeeder` twice with the same password must produce the same deterministic fixture state before test mutations.

Required test:

```text
seed
snapshot manifest-owned baseline
seed again
snapshot
equal
```

No duplicate rows.

No unrelated row mutation.

---

# 24. Frozen Unrelated-State Oracle

Create Stage 6 oracle support that can capture/compare non-Stage6 state.

Recommended asset:

```text
frontend/integration_test/stage6_oracle.ps1
```

It must support an operation equivalent to:

```text
CaptureFrozenUnrelatedState
CompareFrozenUnrelatedState
RemoveFrozenSnapshot
```

Exclude expected volatile authentication/session records if the current application creates them during login.

Do not exclude educational production tables broadly.

The purpose is to prove Stage 6 E2E only mutates:

- explicit Stage 6 fixture-owned rows;
- new rows created under the Stage 6 Target fixture context;
- expected auth/session records.

It must not mutate existing unrelated Institutions/Topics/Assessments.

---

# 25. Sanitized Fixture Manifest / Oracle

The Windows Flutter E2E may receive a host-side JSON oracle/manifest containing only non-secret deterministic identifiers needed to independently assert expected fixture identity.

Allowed:

- UUIDs;
- login names;
- expected titles;
- expected timezone;
- expected fixture counts;
- expected canonical Homework/question IDs for seeded fixtures.

Forbidden:

- password;
- bearer tokens;
- DB credentials;
- app secret;
- raw hashed passwords.

The oracle path must be a controlled temp file, not repository output.

Mandatory cleanup removes it.

---

# 26. Integration Assets

Create only focused Stage 6 assets equivalent to:

```text
backend/database/seeders/Stage6E2eSeeder.php
backend/tests/Feature/Seeders/Stage6E2eSeederTest.php

frontend/integration_test/stage6_homework_authoring_flow_test.dart
frontend/integration_test/run_stage6_windows_e2e.ps1
frontend/integration_test/stage6_runtime_guard.ps1
frontend/integration_test/verify_stage6_runtime_guard.ps1
frontend/integration_test/stage6_oracle.ps1
frontend/integration_test/verify_stage6_oracle.ps1
frontend/integration_test/stage6_api_security.ps1
frontend/integration_test/verify_stage6_api_security.ps1
frontend/integration_test/prepare_stage6_manual_smoke.ps1
```

If existing integration architecture reasonably combines some `verify_*` responsibilities, fewer files are allowed.

Do not create a generic new cross-Stage E2E framework.

Reuse Stage 5 helper patterns locally without refactoring Stage 2–5 assets.

---

# 27. Stage 6 Windows Runner

`run_stage6_windows_e2e.ps1` must:

1. validate supplied Flutter executable against repository FVM pin;
2. resolve exact API target;
3. run Stage 6 runtime guard;
4. run guard negative-matrix verifier;
5. generate unpredictable strong shared password in memory;
6. run Stage6E2eSeeder twice;
7. prove seeder repeatability;
8. create sanitized fixture/oracle file;
9. capture frozen unrelated-state snapshot;
10. run real API security/business matrix;
11. launch first fresh Windows Flutter integration process;
12. run DB postcondition oracle;
13. compare frozen unrelated state;
14. stop Stage 6 app container only;
15. restart Stage 6 app container;
16. re-run full runtime guard for the new container epoch;
17. launch second fresh Windows Flutter integration process for persistence;
18. run persistence DB oracle;
19. compare frozen unrelated state again;
20. mandatory cleanup;
21. leave the Stage 6 backend container running.

Do not restart PostgreSQL as part of the normal scenario.

Do not reuse an already-running Flutter process across the backend restart.

---

# 28. Flutter E2E Secrets

Pass through `--dart-define` only the minimum values required by the Stage 6 test, e.g.:

```text
API_BASE_URL
STAGE6_E2E_PASSWORD
STAGE6_E2E_ORACLE_PATH
```

Do not pass:

- DB password;
- app secret;
- Docker credentials.

Integration test logs must not print the shared password or auth token.

---

# 29. Main Windows E2E Test Names

The Dart integration test must expose at least two deterministic top-level tests that the PowerShell runner can invoke independently:

```text
Stage 6 Homework authoring uses the real Windows stack
Stage 6 Homework state persists after backend restart
```

Use exact or equivalently stable plain names and have the runner reference them explicitly.

Do not execute the whole integration test file blindly when test ordering/state matters.

---

# 30. Main Windows Flow — Login and Topic Entry

In:

```text
Stage 6 Homework authoring uses the real Windows stack
```

use the real app.

Required:

1. launch with exact real API base URL;
2. login:
   `e2e_s06_target_teacher`;
3. verify authenticated Teacher workspace;
4. open:
   `E2E S06 Authoring Topic`;
5. verify Topic detail;
6. verify Homework section loads;
7. confirm no main-flow-created Homework exists yet.

Do not use repository fakes or injected session.

---

# 31. Create Whole-Group Draft Homework

Through production UI:

Create:

```text
title:
E2E S06 Official Homework

description:
E2E S06 official draft description

student instructions:
Complete every question carefully.

assignment:
Whole group

deadline:
2035-06-15 18:00 in Asia/Tashkent
```

Expected request deadline:

```text
2035-06-15T18:00:00+05:00
```

Expected persisted/returned UTC:

```text
2035-06-15T13:00:00Z
```

No Questions on initial create.

After confirmed success verify:

```text
status = Draft
normal attempts = 3
question count = 0
total points = 0
deadline displays 2035-06-15 18:00 in Institution timezone
```

Do not activate yet.

---

# 32. Nine-Type Question Authoring Matrix

Open real Question Builder.

Create and retain these ten Questions, covering all nine types plus both Short Written modes.

## Q1 — Single Choice

```text
prompt:
What does DNS primarily do?

points:
1

options:
1. Resolves domain names — correct
2. Compresses files
3. Encrypts all traffic
```

## Q2 — Multiple Choice

```text
prompt:
Select valid network protocols.

points:
2

options:
1. HTTP — correct
2. DNS — correct
3. PNG
4. JPEG
```

## Q3 — True / False

```text
prompt:
An IP address can identify a network endpoint.

points:
1

correct:
True
```

## Q4 — Short Written Automatic

```text
prompt:
Write the abbreviation for Domain Name System.

points:
1

checking:
automatic

accepted answers:
DNS
```

## Q5 — Short Written Manual

```text
prompt:
Describe DNS in one sentence.

points:
2

checking:
manual
```

## Q6 — Open Written

```text
prompt:
Explain the steps of a DNS lookup.

points:
3
```

## Q7 — File Based

```text
prompt:
Upload the completed network presentation.

points:
4
```

Verify UI shows fixed:

```text
PDF
DOCX
PPT
PPTX
Manual review
```

## Q8 — Matching

```text
prompt:
Match each term to its meaning.

points:
2

pairs:
DNS -> Domain name resolution
IP -> Network address
```

## Q9 — Ordering

```text
prompt:
Put the simplified lookup steps in order.

points:
2

correct order:
1. Enter domain
2. Resolve address
3. Contact server
```

## Q10 — Fill in Blank

```text
prompt:
DNS converts {{host}} into an {{address}}.

points:
2

blank host:
accepted = domain name

blank address:
accepted = IP address
```

After each confirmed add, UI must use the authoritative full Homework response.

At the end:

```text
question count = 10
total points = 20
```

Do not calculate final pass solely from local UI arithmetic; DB oracle verifies the same total.

---

# 33. Question Update Scenario

Edit Q1 through real UI:

Change:

```text
points:
1 -> 1.5

prompt:
What is the primary purpose of DNS?
```

Keep valid Single Choice config.

After confirmed update:

```text
server total = 20.5
```

DB oracle must confirm exact numeric value:

```text
20.500000
```

or equivalent exact PostgreSQL numeric representation.

---

# 34. Question Delete Scenario

Add one sacrificial extra Question:

```text
type = true_false
prompt = E2E S06 Temporary Question
points = 0.5
correct = false
```

Expected transient:

```text
count = 11
total = 21
```

Delete it through real confirmation UI.

Expected authoritative final:

```text
count = 10
total = 20.5
```

DB oracle confirms:

- temporary Question absent;
- its typed child absent;
- retained Questions remain.

---

# 35. Question Reorder Scenario

Use Builder move controls.

Move Q10 Fill-in-the-Blank to position `1`.

Save order once.

Expected authoritative order begins:

```text
1. Fill in Blank
```

and contains the same ten retained Question IDs exactly once.

Verify:

```text
total remains 20.5
```

Do not use per-move server calls.

DB oracle confirms exact contiguous positions `1..10`.

---

# 36. Official Designation While Draft

Return to Homework detail.

Set:

```text
E2E S06 Official Homework
```

as official through real confirmation UI.

Expected:

- Official badge visible;
- pair exists;
- `homework_assessment_id` = created Homework;
- `blitz_assessment_id = null`;
- `cohort_snapshotted_at = null`;
- `locked_at = null`.

UI text indicates cohort will be prepared on activation.

No fake Blitz row may exist.

---

# 37. Create Selected-Student Practice Homework

Return to Authoring Topic.

Create second Homework:

```text
title:
E2E S06 Selected Practice Homework

description:
Practice assignment

student instructions:
Complete this practice Homework.

assignment:
Selected students

selected:
student_alpha
student_beta

deadline:
none
questions:
[]
```

Use real searchable Student picker.

Verify picker does **not** show:

```text
student_ended
student_inactive
student_unrelated
foreign_student
```

as eligible Target Main Group selections.

After create:

```text
Selected students: 2
status = Draft
normal attempts = 3
```

No official designation action is shown.

---

# 38. Edit Selected Practice Recipients

Open Edit.

Remove:

```text
student_beta
```

Keep:

```text
student_alpha
```

Save.

Expected authoritative:

```text
Selected students: 1
```

Then archive the draft practice Homework through real lifecycle UI.

Expected:

```text
status = Archived
```

It must no longer block Topic closure later.

DB oracle confirms exactly one direct recipient row survived before archive and historical row remains after archive.

---

# 39. Activate Official Group Homework

Return to official draft Homework.

Activate through confirmation.

Expected:

```text
status = Active
```

Official UI after pair refresh:

```text
Official Homework
Official cohort prepared
```

Backend snapshot must include exactly:

```text
student_alpha
student_beta
```

and exclude:

```text
student_ended
student_inactive
student_unrelated
foreign_student
```

Pair:

```text
homework_assessment_id = official Homework
blitz_assessment_id = null
cohort_snapshotted_at != null
locked_at = null
```

No Attempt row is created by activation.

---

# 40. Topic Close Conflict

Navigate back to `E2E S06 Authoring Topic`.

Attempt real Topic:

```text
Close
```

while official Homework is Active.

Expected definite server/UI conflict:

```text
topic_has_open_assessments
```

UI tells Teacher to resolve draft/active Homework.

Topic remains:

```text
Active
```

No Homework state is cascaded.

---

# 41. Close Official Homework

Open official active Homework.

Close via real UI.

There are no Attempts in the main flow, so success is expected:

```text
status = Closed
```

Recipient snapshot remains unchanged.

Pair remains:

```text
official
blitz = null
cohort snapshotted
locked = null
```

No fake Attempt created.

---

# 42. Archive Official Closed Homework

Archive via real UI.

Expected:

```text
status = Archived
Official badge still visible
```

Pair still points to this historical Homework.

No result-pair deletion.

No Blitz created.

---

# 43. Close Topic After Open Homework Resolved

Return to Authoring Topic.

At this point:

```text
official Homework = archived
selected practice Homework = archived
```

No draft/active child Homework remains.

Close Topic through real Stage 5 lifecycle UI.

Expected:

```text
Topic status = Closed
```

This proves Stage 6 child guard allows parent close after open Homework is explicitly resolved.

---

# 44. Locked Official Fixture UI Scenario

Navigate to:

```text
E2E S06 Locked Topic
E2E S06 Locked Official Homework
```

Expected read state:

```text
status = Active
Official Homework
Official selection locked
```

The pair has:

```text
locked_at != null
blitz_assessment_id = null
```

The frontend must render this as valid.

No replacement action appears.

---

# 45. Locked Question Mutation Real-Stack Scenario

On desktop, enter Manage Questions for the locked active Homework.

Attempt one valid new Question add.

Backend must return the documented lock conflict:

```text
409 result_pair_locked
```

or, only if final backend precedence contract after Phase 2 intentionally uses the already-approved activity lock before pair lock, the exact final accepted Stage 6 code must be frozen by ChatGPT before integration implementation.

Planning contract expects:

```text
result_pair_locked
```

because S06-BE-004 defined pair-lock precedence when both pair lock and Attempt exist.

Frontend must:

- not show success;
- refresh authoritative Homework;
- show Question editing locked;
- disable further Question mutations in this Builder instance.

DB oracle confirms no new Question was created.

---

# 46. Persistence After Backend Restart

After first flow/oracle:

```text
docker stop testlabuz-stage6-e2e-app
docker start testlabuz-stage6-e2e-app
```

Then:

- wait for exact 401 HTTP boundary;
- rerun Stage 6 runtime guard;
- launch a **fresh** Windows Flutter process;
- login target Teacher again.

Second test:

```text
Stage 6 Homework state persists after backend restart
```

Verify:

- Authoring Topic remains Closed;
- official Homework remains Archived;
- official badge remains;
- official pair still:
  - same Homework;
  - Blitz null;
  - cohort snapshotted;
- ten retained Questions exist;
- reordered Fill Blank is first;
- total remains `20.5`;
- selected Practice Homework remains Archived;
- Locked Topic fixture remains readable and locked.

DB oracle repeats persistence assertions.

---

# 47. Real API Security Script

Create:

```text
frontend/integration_test/stage6_api_security.ps1
```

Use real login endpoints and real Sanctum bearer tokens.

Never print tokens.

Use the Stage 6 shared password from the runner environment.

The script must cleanly logout/revoke its own sessions where practical.

---

# 48. API Security — Unauthenticated / Wrong Role

## Unauthenticated

At minimum:

```text
GET /teacher/topics/{authoring_topic}/homework
```

must return:

```text
401 authentication_required
```

## Student wrong role

Login:

```text
e2e_s06_student_alpha
```

Call a Teacher Homework endpoint.

Expected existing wrong-role contract:

```text
403
```

with exact final backend role middleware code verified at implementation time.

Do not broaden accepted codes.

## Institution Admin wrong role

Same principle.

---

# 49. API Security — Same-Institution Unrelated Teacher

Login:

```text
e2e_s06_unrelated_teacher
```

Attempt:

```text
GET target authoring Topic Homework list
GET target official/locked Homework
PATCH target Homework
POST target Homework Question
GET target Topic result pair
PUT target Topic result pair
```

Expected privacy-safe:

```text
404 resource_not_found
```

No Target resource content in response.

---

# 50. API Security — Cross-Institution

Login Target Teacher.

Attempt direct access to Foreign fixtures:

```text
GET foreign Topic Homework list
GET foreign Homework
PATCH foreign Homework
POST Question to foreign Homework
GET foreign Topic result pair
PUT foreign Topic result pair
```

Expected:

```text
404 resource_not_found
```

No Foreign title/user/institution detail in response.

---

# 51. Foreign Student Selection Isolation

Login Target Teacher.

POST a selected-Student draft under authorized Target `authoring_topic` with:

```text
student_ids = [foreign_student_uuid]
```

Expected:

```text
422 validation_failed
errors.student_ids
```

The response must not disclose that the UUID belongs to another Institution.

DB oracle confirms no Homework/recipient partial row from this failed create.

---

# 52. Selected Homework Cannot Become Official

Use the real selected Practice Homework before/after archive as appropriate, or seed a dedicated selected draft candidate if the main-flow practice has already archived when this script runs.

Preferred security script runs before the main Flutter mutation flow and uses a seeded selected practice candidate or creates one through API inside Stage 6 fixture namespace.

PUT:

```text
/teacher/topics/{topic}/result-pair
homework_assessment_id = selected Homework
```

Expected:

```text
409 official_task_requires_group_assignment
```

No pair change.

The security script must not disturb the main Authoring Topic's future no-pair starting state.

Use a dedicated security Topic/candidate if needed.

---

# 53. Locked Official Replacement

On `locked_topic`, attempt to replace the current locked official Homework with another eligible whole-group candidate belonging to the same locked Topic.

Seeder must therefore create a dedicated:

```text
E2E S06 Locked Replacement Candidate
```

under `locked_topic`:

```text
type = homework
assignment = group
status = draft
no attempts
```

PUT replacement.

Expected:

```text
409 result_pair_locked
```

Pair remains unchanged.

Then repeat same-target PUT with the already official locked Homework ID.

Expected:

```text
200
same pair ID
same homework_assessment_id
same designated_at
same locked_at
same updated_at
blitz_assessment_id = null
```

DB oracle verifies timestamp no-op.

---

# 54. Stage 6 In-Progress Close Guard

Call:

```text
POST /teacher/homework/{locked_official}/close
```

The seeded Attempt is:

```text
in_progress
```

Expected Stage 6 boundary:

```text
409 business_conflict
```

Homework remains Active.

Attempt remains `in_progress`.

No finalization timestamp/reason is fabricated.

No answer rows are invented.

---

# 55. Question Mutation After Activity / Pair Lock

Call a valid Question mutation against `locked_official`.

Expected exact precedence:

```text
409 result_pair_locked
```

No Question/config/total timestamp mutation.

DB oracle verifies unchanged Question count/total.

---

# 56. Expired Draft Activation

Call:

```text
POST /teacher/homework/{expired_draft}/activate
```

Expected:

```text
409 deadline_passed
```

Homework remains Draft.

No recipient snapshot.

No Attempt.

---

# 57. No Fake Attempts / No Fake Blitz

After all Stage 6 scenarios:

DB oracle must verify:

## Main official Homework

Activation created:

```text
0 assessment_attempts
```

because no Student Attempt API was used.

## Students who never started

No empty/fabricated Attempt rows.

## Result pair

For every Stage 6 pair created by the main flow:

```text
blitz_assessment_id = null
```

No Assessment row with fake placeholder Blitz title/type was inserted by Stage 6 lifecycle/designation.

## Locked fixture

Its single structural Attempt is exactly the seeded fixture Attempt.

No additional Attempt generated by close failure or UI reads.

---

# 58. Independent Database Postconditions — Main Official Homework

The oracle must identify the main-flow-created Homework by exact:

```text
Target Institution
target_teacher
authoring_topic
title = E2E S06 Official Homework
```

Require exactly one.

Verify:

```text
assessment.type = homework
assignment_mode = group
total_possible_points = 20.500000
homework status = archived
deadline_at = 2035-06-15T13:00:00Z
attempt count = 0
```

Recipient rows exactly:

```text
student_alpha
student_beta
assignment_source = group
```

No others.

Question rows:

```text
count = 10
positions = 1..10
```

Position 1 type:

```text
fill_in_blank
```

All nine types present.

Short Written appears in both:

```text
automatic
manual
```

No generic JSON Question config column is used as oracle authority.

---

# 59. Question Typed Oracle

Verify final normalized data.

At minimum:

## Single Choice

- three options;
- exactly one correct;
- updated prompt;
- points `1.5`.

## Multiple Choice

- four options;
- exactly HTTP/DNS correct.

## True/False

- correct true.

## Short Automatic

- accepted answer `DNS`.

## Short Manual

- zero accepted-answer rows.

## Open Written

- no typed answer-key rows.

## File Based

- no Teacher-configurable child extension row;
- type/manual mode is correct.

## Matching

- two semantic pair keys;
- each key has exactly one left and one right row.

## Ordering

- three items;
- positions `1..3`.

## Fill Blank

- keys:
  `host`, `address`;
- each accepted-answer row exists;
- prompt contains both exact placeholders.

Sacrificial temporary Question absent.

---

# 60. Official Result-Pair Oracle

For `authoring_topic`:

Exactly one pair.

Verify:

```text
homework_assessment_id = main official Homework
blitz_assessment_id = null
cohort_snapshotted_at != null
locked_at = null
```

The main flow has no Student activity, so pair stays unlocked.

Official cohort identity is represented by main official Homework recipient rows:

```text
student_alpha
student_beta
```

No separate fake Blitz or duplicate pair.

For `locked_topic`:

```text
blitz_assessment_id = null
locked_at != null
```

valid.

---

# 61. Practice Homework Oracle

Main-flow selected Practice Homework:

```text
assignment_mode = selected_students
status = archived
student_ids = exactly [student_alpha]
assignment_source = direct
question_count = 0
total_possible_points = 0
```

It must not appear as:

```text
topic_result_pairs.homework_assessment_id
```

for Authoring Topic.

---

# 62. Topic Oracle

Final main-flow:

```text
authoring_topic.status = closed
```

No child Homework in:

```text
draft
active
```

under Authoring Topic.

The earlier failed close must not have changed Topic status before Homework resolution.

No cascade timestamps may have altered Homework unexpectedly.

---

# 63. Unrelated-State Oracle

After the complete mutation flow and after restart persistence flow:

- Foreign Institution fixture remains unchanged;
- unrelated Target Group/Topic remains unchanged;
- pre-existing non-Stage6 educational rows remain unchanged;
- no Stage5 fixture is mutated;
- no mass delete/update occurred outside Stage6 fixture-owned/new main-flow rows.

Use exact explicit manifest/frozen snapshot evidence.

---

# 64. Stage 6 Oracle Verification Script

Create:

```text
frontend/integration_test/verify_stage6_oracle.ps1
```

It must test pure oracle validation functions against:

- valid expected samples;
- missing rows;
- duplicate rows;
- wrong Tenant;
- wrong Question count/position;
- wrong total;
- foreign recipient;
- ended/inactive recipient leakage;
- fake Attempt;
- fake Blitz;
- non-null Blitz where Stage 6 main pair expects null;
- locked pair with null Blitz **accepted**;
- pair locked without cohort rejected;
- selected Practice accidentally official;
- temporary Question still present;
- wrong Topic final state.

Then run against real guarded runtime after the real flow.

---

# 65. Flutter E2E Oracle Use

Flutter E2E may use the sanitized oracle only to identify deterministic seeded fixtures and verify expected IDs/titles.

It must **not** read DB-generated postconditions from a file and then claim UI success.

UI assertions must come from the production app.

Independent DB oracle runs separately after UI/API scenarios.

Do not bypass the production API for mutation.

---

# 66. No Direct Database Mutation During Main Flow

After Stage6E2eSeeder establishes the deterministic baseline, the main E2E flow must mutate educational state only through production APIs/UI.

Allowed direct DB operations after seeding:

- read-only oracle queries;
- frozen-state capture/compare.

Do not use direct SQL/Tinker to:

- create main Homework;
- add main Questions;
- change recipients;
- designate official;
- activate/close/archive;
- close Topic.

The pre-seeded structural locked/expired fixtures are fixture setup, not main-flow mutation.

---

# 67. Rerun Safety

A complete fresh automated Stage 6 run begins by invoking the guarded Stage6E2eSeeder, which resets only Stage 6 manifest-owned fixture state.

The runner must be safe after a previous successful/failed run.

Mandatory cleanup includes:

- sanitized host oracle file;
- container-side frozen snapshot;
- temporary test artifacts;
- in-memory password references;
- any host temp root created by Stage 6 runner.

Do not remove user files or arbitrary temp directories.

Cleanup paths must match strict Stage 6-specific name patterns.

---

# 68. Integration Asset Focused Verification — Seeder

Codex runs:

```bash
cd backend
php artisan test tests/Feature/Seeders/Stage6E2eSeederTest.php
```

or the repository's Docker-equivalent focused test command when local PHP execution is not the established environment.

Required seeder test coverage:

- refuses non-testing environment;
- refuses wrong database;
- requires password env;
- deterministic explicit IDs;
- rerun-safe;
- no unrelated rows changed;
- current/ended/inactive memberships exact;
- active Topic states valid;
- locked official pair:
  `locked_at != null`, `blitz = null`;
- structural Attempt valid;
- expired draft valid;
- Foreign fixtures tenant-separated.

Do not run full backend suite.

---

# 69. Integration Asset Focused Verification — PowerShell

Codex/Project Owner runs, as appropriate:

```powershell
frontend/integration_test/verify_stage6_runtime_guard.ps1
frontend/integration_test/verify_stage6_oracle.ps1
frontend/integration_test/verify_stage6_api_security.ps1
```

Pure negative matrices must pass without needing to mutate production source.

If the actual runtime is required for part of a verifier and Codex cannot access the Project Owner Docker environment, Codex reports the pure verification result and leaves live execution to Project Owner.

---

# 70. Integration Asset Static Verification

Run narrow checks for new integration Dart assets:

```bash
cd frontend
fvm flutter analyze --no-pub integration_test/stage6_homework_authoring_flow_test.dart
```

If the pinned Flutter CLI cannot analyze a single file, use the narrowest supported `integration_test` scope.

Format check:

```bash
fvm dart format --output=none --set-exit-if-changed integration_test
```

If this would recheck old integration files, that is acceptable as read-only format verification but do not rewrite them.

Do not run full frontend analyze/test suite.

---

# 71. `git diff --check`

Always:

```bash
git diff --check
```

Focused diff self-review must prove:

- integration/test assets only;
- no production backend/frontend code;
- no migrations/routes;
- no package/lock/platform changes;
- no Docker repo changes;
- no test auth bypass;
- no secrets;
- no raw password/token logging;
- no Stage2–5 integration asset refactor;
- no unrelated formatting churn.

---

# 72. Project Owner Automated Real-Stack Execution

After integration assets are delivered on clean synchronized `main`, Project Owner runs the Stage 6 Windows runner with:

```text
FlutterExecutable = exact FVM-pinned Flutter executable
ApiPort = dedicated loopback port
```

Runner must print concise PASS markers only.

Suggested evidence markers:

```text
Stage6RuntimeGuard: PASS
Stage6SeederRepeatability: PASS
Stage6ApiSecurity: PASS
Stage6WindowsAuthoringFlow: PASS
Stage6DatabasePostconditions: PASS
Stage6FrozenUnrelatedState: PASS
Stage6BackendRestartGuard: PASS
Stage6WindowsPersistenceFlow: PASS
Stage6PersistencePostconditions: PASS
Stage6MandatoryCleanup: PASS
```

Do not print credentials/tokens.

---

# 73. Project Owner Windows Manual Smoke

Required after automated Windows real-stack PASS.

Use:

```text
prepare_stage6_manual_smoke.ps1
```

The preparation must:

- pass runtime guard;
- seed/reset a deterministic manual-safe Stage 6 state;
- output only non-secret actor/login/topic information;
- rely on `STAGE6_E2E_PASSWORD` supplied privately by Project Owner;
- not alter production code.

Manual Windows smoke checks:

1. login as Target Teacher;
2. open Authoring/Manual Topic;
3. open/create a draft Homework;
4. visually verify desktop Create/Edit route;
5. open selected-Student picker;
6. verify current Students are readable and no raw UUID is exposed;
7. open deadline picker and confirm Institution timezone label;
8. open Question Builder;
9. verify type selector contains exactly the nine supported types;
10. verify Move up/down controls are keyboard reachable;
11. cancel/discard without leaving unintended mutation;
12. open locked official fixture;
13. verify Official + Locked read state.

This smoke need not reproduce the entire automated flow.

Result:

```text
PASS / FAIL
```

Record concise evidence.

---

# 74. Project Owner Android Real-Stack Smoke

Required because Stage 6 explicitly supports Teacher Homework read on mobile while authoring remains desktop-only.

Use the same guarded Stage 6 backend.

Install/run the accepted Android debug app from valid Frontend Phase 2 build evidence, or rebuild only if that evidence has been invalidated.

Smoke:

1. login as:
   `e2e_s06_target_teacher`;
2. open a seeded/mobile-readable Topic;
3. open Homework list;
4. open Homework detail;
5. verify:
   - status;
   - deadline/institution timezone display where present;
   - attempt policy `3`;
   - Question read content;
   - Official badge/status;
6. verify no:
   - Create Homework;
   - Edit Homework;
   - Manage Questions;
   - Activate/Close/Archive;
   - Set/Replace official
   controls exist;
7. attempt direct authoring deep link only if practical through app/navigation tooling; it must normalize to supported read destination and never render authoring form.

Result:

```text
PASS / FAIL
```

No Android Student execution smoke belongs to Stage 6.

---

# 75. Security / Tenant Acceptance Matrix

The final Integration report must explicitly mark PASS/FAIL:

- [ ] Unauthenticated Teacher Homework endpoint denied.
- [ ] Wrong role denied.
- [ ] Same-Institution unrelated Teacher cannot access Target Topic/Homework/Question/result pair.
- [ ] Target Teacher cannot access Foreign Topic/Homework/Question/result pair.
- [ ] Foreign Student UUID cannot be selected into Target Homework.
- [ ] Current eligible recipient snapshot excludes ended/inactive/unrelated/foreign Students.
- [ ] Selected practice Homework cannot become official.
- [ ] Locked official Homework cannot be replaced.
- [ ] Same-target locked official PUT is idempotent/no timestamp churn.
- [ ] Locked result pair with `blitz_assessment_id = null` remains valid.
- [ ] In-progress structural Attempt blocks Stage 6 close without fake finalization.
- [ ] Question mutation after locked/activity state cannot change scoring content.
- [ ] Expired draft cannot activate.
- [ ] Activation creates no Attempt.
- [ ] Stage 6 creates no fake Blitz.
- [ ] Unrelated non-Stage6 data remains unchanged.

Any FAIL is an Integration finding.

---

# 76. Main Functional Acceptance Matrix

Explicit PASS/FAIL:

- [ ] Real Teacher login.
- [ ] Topic Homework list.
- [ ] Whole-group draft create.
- [ ] Selected-Student practice create.
- [ ] Selected recipient edit.
- [ ] Institution-timezone deadline.
- [ ] Fixed 3 attempts.
- [ ] Single Choice.
- [ ] Multiple Choice.
- [ ] True/False.
- [ ] Short Written automatic.
- [ ] Short Written manual.
- [ ] Open Written.
- [ ] File Based.
- [ ] Matching.
- [ ] Ordering.
- [ ] Fill-in-the-Blank.
- [ ] Question update.
- [ ] Question delete.
- [ ] Question reorder.
- [ ] exact server total `20.5`.
- [ ] draft official designation.
- [ ] pair Blitz null.
- [ ] activation.
- [ ] exact Group recipient snapshot.
- [ ] official cohort prepared.
- [ ] Topic close blocked while Homework open.
- [ ] Homework close.
- [ ] selected practice archive.
- [ ] official closed archive.
- [ ] Official badge preserved historically.
- [ ] Topic close after open children resolved.
- [ ] locked official read.
- [ ] locked Question mutation rejected.
- [ ] state persists after backend restart.

---

# 77. Accessibility / Capability Integration Checks

Automated Windows E2E should assert stable keys/semantics where practical:

- Homework search;
- Create Homework;
- selected Student picker;
- normal attempts display;
- Manage Questions;
- Question editor;
- type labels;
- Move up/down;
- Save Order;
- lifecycle buttons;
- Official badge;
- Set official;
- confirmation dialogs.

Do not make pixel/golden appearance the integration authority.

Android smoke verifies read-only capability boundary.

---

# 78. Integration Findings

When a production issue appears, report:

```text
INTEGRATION FINDING

Severity candidate:
P1 / P2 / P3

Scenario:
...

Observed:
...

Expected:
...

Production boundary:
backend/frontend file or endpoint/symbol if known

Evidence:
HTTP status/code
UI state
DB oracle
runner marker
```

Do not fix production source inside this task.

Integration asset defects may be corrected within this integration task if they do not change production behavior.

---

# 79. Production Fix Evidence Validity

If a later focused production fix is required:

## Backend-only fix

Re-run:

- affected focused backend tests;
- backend evidence invalidated by the fix as determined by ChatGPT;
- relevant Stage 6 integration scenarios/security/oracle.

Do not automatically rerun full frontend checkpoint unless client contract changed.

## Frontend-only fix

Re-run:

- affected focused frontend tests/analyze/format;
- build evidence if invalidated;
- relevant Windows/Android integration scenarios.

## Shared contract fix

ChatGPT determines whether Backend/Frontend Phase 2 evidence must be refreshed.

Final integration must run on the final accepted production candidate.

---

# 80. Delivery

Codex owns only integration asset implementation and focused asset verification.

Project Owner owns:

- branch delivery;
- commit;
- push;
- PR;
- merge;
- current-main synchronization;
- dedicated Docker runtime provisioning;
- real Windows E2E execution;
- Windows manual smoke;
- Android real-stack smoke.

Suggested integration-assets delivery:

```text
Branch:
test/s06-int-001-homework-e2e

Commit:
test(stage6): add homework real-stack e2e

PR base:
main
```

Codex must not commit/push/open PR.

---

# 81. Task Acceptance

`S06-INT-001` is not `Accepted` merely because integration assets compile.

Final acceptance requires:

```text
integration assets delivered
runtime guard PASS
seeder repeatability PASS
API security matrix PASS
Windows real-stack authoring flow PASS
DB oracle PASS
unrelated-state oracle PASS
backend restart guard PASS
Windows persistence flow PASS
Windows manual smoke PASS
Android real-stack smoke PASS
all Integration findings resolved
final Git state clean/synchronized
```

Required final finding totals:

```text
P1 = 0
P2 = 0
P3 = 0
```

---

# 82. Final Integration Report

Return:

```text
PASS
FAIL
BLOCKED
```

and include:

1. **Audited Git state**
   - integration implementation baseline;
   - final tested `origin/main`;
   - ahead/behind/worktree.

2. **Phase 2 dependencies**
   - Backend Phase 2 PASS evidence;
   - Frontend Phase 2 PASS evidence;
   - whether evidence remained valid.

3. **Integration assets delivery**
   - PR/merge SHA.

4. **Runtime guard**
   - container;
   - API target;
   - DB identity;
   - PASS/FAIL;
   - no secrets.

5. **Seeder**
   - repeatability;
   - focused test.

6. **Windows real-stack**
   - first flow result;
   - persistence-after-restart result.

7. **Nine-type Question matrix**
   - explicit PASS/FAIL.

8. **Homework lifecycle/official pair**
   - explicit PASS/FAIL;
   - confirm `blitz_assessment_id = null`.

9. **Security/Tenant matrix**
   - explicit PASS/FAIL.

10. **DB oracle**
    - points;
    - recipients;
    - Questions;
    - pair;
    - Attempts;
    - no fake Blitz;
    - no unrelated mutation.

11. **Windows manual smoke**
    - result.

12. **Android real-stack smoke**
    - result and authoring-capability denial.

13. **Findings**
    ```text
    P1 = N
    P2 = N
    P3 = N
    ```

14. **Final verdict**.

Do not reconstruct missing evidence.

If a required smoke/runtime cannot be performed:

```text
BLOCKED
```

not PASS.

---

# 83. Final PASS Gate

`S06-INT-001 = PASS` only when all are true:

- Backend Phase 2 is valid PASS;
- Frontend Phase 2 is valid PASS;
- integration assets are delivered;
- Stage 6 runtime guard passes;
- seeder is deterministic/rerun-safe;
- real API security matrix passes;
- Windows real-stack authoring flow passes;
- all nine Question types pass end-to-end;
- Question update/delete/reorder pass;
- server total-points oracle passes;
- selected recipient behavior passes;
- activation snapshot passes;
- official partial result pair passes;
- locked/null-Blitz fixture passes;
- Topic lifecycle integration passes;
- no fake Attempts/Blitz;
- unrelated-state oracle passes;
- backend restart persistence passes;
- Windows manual smoke passes;
- Android read-only Stage 6 smoke passes;
- no unresolved Integration finding.

Required:

```text
P1 = 0
P2 = 0
P3 = 0
```

---

# 84. Next Gate

After final Integration PASS and delivery evidence is synchronized on `origin/main`, the next permitted gate is:

```text
Stage 6 Closure Review
```

Closure must reuse still-valid Backend Phase 2, Frontend Phase 2, and S06-INT-001 evidence.

Do not rerun broad suites/builds/E2E solely for closure unless a post-integration production change invalidates them.
