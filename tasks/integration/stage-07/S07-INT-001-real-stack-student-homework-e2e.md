# Codex Integration Contract: S07-INT-001 — Real-Stack Student Homework E2E

## 1. Metadata and Execution Gate

| Field | Value |
|---|---|
| Task ID | `S07-INT-001` |
| Stage | `Stage 7 — Student Homework and Submission Flow` |
| Area | `Integration / real-stack E2E` |
| Status | `Approved — execution gated by Backend + Frontend Phase 2 PASS` |
| Depends on | `S07-BE-PHASE-2 = PASS`; `S07-FE-PHASE-2 = PASS` |
| Planning baseline | `origin/main @ 294d17317ed0c7428171fc20223da65e7a2cafd1` |
| Implementation baseline | ChatGPT re-checks/freezes current `origin/main` immediately before Codex integration-asset implementation |
| Harness implementation | `Codex — integration/test assets only` |
| Integration Harness Preflight | `ChatGPT — mandatory after harness delivery and before first full real-stack runner` |
| Real-stack automated execution | `Project Owner or approved CI` |
| Manual mobile smoke | `Project Owner` |
| Final integration review/verdict | `ChatGPT` |
| Routine Git/GitHub delivery | `Project Owner` |
| Next gate after final PASS | `Stage 7 Closure Review` |
| Production changes allowed in this task | `No` |

Do not create a duplicate `CODEX-PROMPT`.

This contract is implementation-ready only after both Stage 7 Phase 2 checkpoints pass.

Before Codex begins integration-asset implementation, ChatGPT must re-check/freeze current `origin/main`.

If `origin/main` advances after the baseline is frozen, stop and report the new SHA. ChatGPT decides whether the change is evidence-safe bookkeeping or requires contract revalidation.

---

# 2. Integration Workflow

The Stage 7 integration sequence is fixed:

```text
Backend Phase 2 PASS
+
Frontend Phase 2 PASS
->
freeze current main
->
Codex implements only missing S07 integration assets
->
focused asset verification
->
Project Owner delivers integration assets to origin/main
->
ChatGPT Integration Harness Preflight
->
preflight PASS
->
Project Owner runs full Windows real-stack runner
->
required direct API/security + DB oracle evidence
->
backend restart persistence verification
->
Android real-stack manual smoke
->
final cleanup verification
->
ChatGPT integration review/verdict
```

Do not execute the first full Stage 7 real-stack runner before the Integration Harness Preflight passes.

---

# 3. Integration Principle

This task verifies already-delivered production behavior through the real stack.

It may create or modify only integration/test assets.

It must not repair production code.

If execution exposes a production defect:

```text
production defect
```

then:

1. preserve exact evidence;
2. stop the affected scenario;
3. ChatGPT creates a focused production-fix contract;
4. Codex implements only that production fix;
5. Project Owner delivers it;
6. ChatGPT determines which Backend/Frontend Phase 2 and integration evidence was invalidated;
7. rerun only the materially affected required evidence.

If the failure is:

```text
integration-harness defect
```

fix only the relevant integration asset through a focused integration-fix contract.

If the failure is:

```text
environment/runtime defect
```

fix only the runtime/environment.

Never silently cross these boundaries.

---

# 4. Goal

Prove the complete Stage 7 Student Homework vertical through:

```text
Flutter Windows
-> production GoRouter
-> production Riverpod controllers
-> production repositories/DTOs
-> production configured Dio
-> Laravel/Sanctum
-> PostgreSQL testlabuz_testing
-> private file storage
```

and independently verify:

- Student Homework assignment/read scope;
- safe Student Question projection;
- first official Homework Attempt result-pair lock;
- fixed three normal attempts;
- create-or-resume behavior;
- durable Start idempotency;
- all eight non-file answer mutation types;
- file-based answer upload/replacement;
- private protected Student submission download;
- explicit Student Submit;
- durable Submit idempotency;
- zero-answer Submit;
- deadline auto-finalization;
- Scheduler deadline reconciliation;
- Teacher-close auto-finalization;
- deadline-vs-close precedence;
- exact saved-answer persistence;
- no Stage 7 scoring/checking;
- tenant/ownership/privacy boundaries;
- state persistence after backend restart;
- mobile Student execution smoke.

---

# 5. Explicit Non-Goals

Do not implement or verify as Stage 7 product functionality:

- Blitz;
- automatic answer checking;
- manual Teacher answer review;
- awarded points;
- Attempt normalized score;
- official Homework score selection/reselection;
- Student score release;
- Parent score display;
- final Topic result;
- AI/fuzzy checking;
- Teacher Stage 9 Student submission download;
- production test-only routes;
- auth bypass;
- database mutation API;
- hidden session injection;
- a new E2E framework;
- a new Docker repository configuration;
- full backend/frontend checkpoint reruns merely because integration begins.

Stage 8/9/10 remain out of scope.

---

# 6. Codex Read Boundary

Codex may read only:

1. this integration contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. `frontend/AGENTS.md`;
5. final Stage 7 production source/tests/config directly required to implement integration assets;
6. the immediately relevant existing integration primitives listed below.

Codex must not read:

- product docs;
- roadmap;
- architecture/database/API docs;
- Stage indexes;
- previous task contracts;
- previous Phase 2 review files;
- closure reviews;
- previous integration task contracts

to rediscover requirements.

This contract already defines Stage 7 integration behavior.

---

# 7. Approved Reusable Integration Primitives

Reuse only the source/test primitive whose assumptions still apply.

Codex may inspect these specific existing assets as implementation patterns.

## Runtime / runner

```text
frontend/integration_test/stage5_runtime_guard.ps1
frontend/integration_test/verify_stage5_runtime_guard.ps1
frontend/integration_test/stage6_runtime_guard.ps1
frontend/integration_test/verify_stage6_runtime_guard.ps1
frontend/integration_test/run_stage6_windows_e2e.ps1
```

Use:

- Stage 6 exact backend/container/API/FVM guard pattern;
- Stage 5 private-volume guard pattern.

Do not copy either harness blindly.

## Private files / local native boundaries

```text
frontend/integration_test/stage5_test_files.ps1
frontend/integration_test/stage5_e2e_support.dart
frontend/integration_test/stage5_topics_materials_flow_test.dart
```

Use only:

- deterministic valid/invalid test file generation;
- injectable file picker boundary;
- injectable local file sink/open boundary.

The actual Stage 7 upload/download must still use production repositories/Dio/protected transfer.

## DB oracle / API security

```text
frontend/integration_test/stage6_oracle.ps1
frontend/integration_test/verify_stage6_oracle.ps1
frontend/integration_test/stage6_api_security.ps1
frontend/integration_test/verify_stage6_api_security.ps1
```

Reuse:

- scoped DB-oracle structure;
- exact API error-envelope assertions;
- safe actor/token handling;
- safe PowerShell/container PHP transport.

Do not create a generic cross-Stage E2E framework.

---

# 8. Production Boundaries the Real Stack Must Exercise

The actual E2E process must use production:

```text
GoRouter
AuthSessionController
StudentSessionKey

Student Homework repositories/data sources/DTOs
Student Attempt repositories/data sources/DTOs
Student answer mutation repositories/data sources
Student file-answer repository/data source
Student Submit repository/data source

IdempotencyKeyGenerator provider boundary
StudentSubmissionFilePicker provider boundary
ProtectedLearningMaterialTransfer
LocalFileActions

configured Dio
Laravel Sanctum middleware
real PostgreSQL
real private filesystem disk
```

The integration test may override only approved native/non-deterministic boundaries:

```text
idempotencyKeyGeneratorProvider
studentSubmissionFilePickerProvider
localFileActionsProvider
app/config API target boundary already established by integration architecture
```

Do not override:

```text
repositories
remote data sources
Dio transport
auth session controller
Homework/Attempt controllers
answer controllers
Submit controller
```

in the actual real-stack E2E.

---

# 9. Integration Asset Delivery Boundary

Codex integration implementation may create/modify only:

```text
backend/database/seeders/**
backend/tests/Feature/Seeders/**

frontend/integration_test/**
```

plus an existing integration test helper outside those paths only if directly required and explicitly justified.

Do not modify:

```text
backend/app/**
backend/routes/**
backend/database/migrations/**
frontend/lib/**
frontend/pubspec.yaml
frontend/pubspec.lock
platform production files
```

If an integration asset cannot be implemented without production change:

```text
BLOCKED
```

Report the exact production gap.

---

# 10. Dedicated Stage 7 Runtime

Use a dedicated restartable Stage 7 backend container.

Required logical identity:

```text
backend container:
testlabuz-stage7-e2e-app

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
```

Backend source mount:

```text
current repository backend directory
-> /var/www/html
read/write bind mount
```

App container:

```text
AutoRemove = false
WorkingDir = /var/www/html
```

No repository Docker configuration change.

---

# 11. Stage 7 Private File Runtime

Stage 7 requires persistent private Student submission storage.

Required named volume:

```text
testlabuz-stage7-e2e-private-files
```

mounted:

```text
-> /var/www/html/storage/app/private
read/write
```

The runtime guard must prove:

- exactly one Stage 7 private named volume owns the private root;
- it is read/write;
- it is not also mounted to public storage;
- no alias mount exposes the same named volume at another app path;
- configured private disk resolves under the private root;
- configured disk is not public.

Do not bind private storage to:

```text
storage/app/public
```

or any web-served path.

---

# 12. Runtime Guard Assets

Create:

```text
frontend/integration_test/stage7_runtime_guard.ps1
frontend/integration_test/verify_stage7_runtime_guard.ps1
```

The guard must fail closed unless all approved runtime identities are proven.

---

# 13. Runtime Guard — Backend Identity

Require:

```text
container name = testlabuz-stage7-e2e-app
exactly one inspected backend container
running
AutoRemove = false
WorkingDir = /var/www/html
```

Require exactly one read/write bind mount:

```text
current repo backend
-> /var/www/html
```

Reject:

- missing bind;
- read-only bind;
- wrong source;
- duplicate owning mounts;
- ambiguous aliases.

---

# 14. Runtime Guard — API Target Identity

Accept only exact:

```text
http://127.0.0.1:<ApiPort>/api/v1
```

Reject:

- HTTPS;
- `localhost`;
- IPv6 loopback;
- wildcard host;
- userinfo/credentials;
- query;
- fragment;
- trailing slash;
- alternate API version/path;
- missing/implicit port;
- wrong published port.

Container `8000/tcp` must publish exactly once to:

```text
127.0.0.1:<ApiPort>
```

---

# 15. Runtime Guard — Laravel Identity

Probe inside the real container and require:

```text
app()->environment() = testing
config('app.debug') = false
config('database.default') = pgsql
PDO driver = pgsql
current_database() = testlabuz_testing
```

Require:

```text
configured private disk exists
configured private disk visibility is not public
configured private root is under /var/www/html/storage/app/private
```

No current migration may be pending.

Do not dump all environment variables.

---

# 16. Runtime Guard — PostgreSQL Identity

Require:

```text
container = testlabuz-postgres-1
running = true
image = postgres:18.4
network contains testlabuz_default
backend container network contains testlabuz_default
DB_HOST = postgres
```

---

# 17. Runtime Guard — Private Volume Identity

Require exact:

```text
volume name = testlabuz-stage7-e2e-private-files
destination = /var/www/html/storage/app/private
read/write
```

Reject:

- missing volume;
- wrong named volume;
- read-only;
- public-root mount;
- duplicate volume ownership;
- alias mount into another app path;
- same private volume mounted into public root.

---

# 18. Runtime Guard — HTTP Boundary

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

No token/secret may be logged.

---

# 19. Runtime Guard Negative Verifier

`verify_stage7_runtime_guard.ps1` must test pure guard functions plus the approved actual runtime.

At minimum reject:

```text
bad/non-loopback API URL
localhost/IPv6/wildcard API URL
query/fragment/trailing slash
wrong path/port

wrong/missing/stopped backend container
AutoRemove=true
wrong working directory
missing/read-only/wrong source bind
ambiguous source bind
wildcard/duplicate port publish

wrong APP_ENV/debug state
wrong DB driver/name/host
pending migration

wrong/stopped PostgreSQL container
wrong PostgreSQL image/network

missing/wrong/read-only private volume
private volume mapped to public storage
private volume duplicate/alias mount

wrong unauthenticated /auth/me boundary
```

Do not print:

```text
database password
APP_KEY
bearer tokens
full Docker env
raw inspect JSON with secrets
```

---

# 20. Flutter Toolchain Guard

The Stage 7 runner parameters must match the existing Stage 6 style:

```powershell
param(
  [Parameter(Mandatory = $true)][string] $FlutterExecutable,
  [Parameter(Mandatory = $true)][ValidateRange(1,65535)][int] $ApiPort
)
```

Runner must compare:

```text
$FlutterExecutable --version --machine
```

against:

```text
frontend/.fvmrc
```

Planning pin:

```text
3.44.7
```

At execution use the actual final accepted `.fvmrc`.

Do not modify `.fvmrc`.

---

# 21. Stage 7 Seeder Assets

Create:

```text
backend/database/seeders/Stage7E2eSeeder.php
backend/tests/Feature/Seeders/Stage7E2eSeederTest.php
```

Seeder must be:

```text
deterministic in structure
repeatable
fail-closed
manifest-owned
Tenant-safe
FK-safe
```

---

# 22. Seeder Fail-Closed Guard

Before any mutation require:

```text
app environment = testing
database driver = pgsql
current_database() = testlabuz_testing
STAGE7_E2E_PASSWORD exists
STAGE7_E2E_PASSWORD non-blank
```

If any fails:

```text
throw
write nothing
```

Do not print password.

---

# 23. Reserved Stage 7 Namespace

Use:

```text
UUID prefix:
07000000-...

login prefix:
e2e_s07_

display/title prefix:
E2E S07

password environment:
STAGE7_E2E_PASSWORD
```

Every owned DB row must be declared in an explicit manifest/constant set.

Do not delete unrelated rows merely because text begins with a Stage prefix.

---

# 24. Seeder Cleanup Responsibility

`Stage7E2eSeeder` must expose one guarded reusable cleanup method for its own integration namespace.

Conceptual:

```text
cleanupOwnedState()
```

It must:

1. perform the same environment/database guard;
2. delete only manifest-owned Stage 7 DB rows in child-to-parent FK-safe order;
3. delete only manifest-owned Stage 7 private blobs/keys;
4. never prefix-delete unrelated rows;
5. be safe to call before reseed and during final cleanup.

`run()`:

```text
guard
-> cleanupOwnedState()
-> seed deterministic Stage 7 fixtures
```

The final runner may invoke the guarded cleanup through a short safe container wrapper.

Do not create a production cleanup API.

---

# 25. Fixture Institutions

Create:

## Target Institution

```text
E2E S07 Target Institution
active
timezone = Asia/Tashkent
student_submission_max_mb = 2
```

The 2 MiB setting intentionally makes file-limit E2E practical.

## Foreign Institution

```text
E2E S07 Foreign Institution
active
timezone = Asia/Tashkent
```

No relationship may cross Institutions.

---

# 26. Target Actors

Create active users:

```text
e2e_s07_teacher
role = Teacher
Target Institution

e2e_s07_student
role = Student
Target Institution

e2e_s07_peer_student
role = Student
Target Institution

e2e_s07_unassigned_student
role = Student
Target Institution

e2e_s07_parent
role = Parent
Target Institution

e2e_s07_foreign_student
role = Student
Foreign Institution

e2e_s07_foreign_teacher
role = Teacher
Foreign Institution
```

All:

```text
active
must_change_password = false
```

Use the shared guarded password.

---

# 27. Groups and Memberships

Create:

## Main Group

```text
E2E S07 Main Group
active
Target Institution
Teacher = e2e_s07_teacher
Students = target + peer
```

Current memberships active.

## Historical Group

```text
E2E S07 Historical Group
```

Target Student had a valid membership at activation/snapshot time, but current membership is ended in final seeded state.

Use this fixture to prove Stage 7 frozen assessment assignment remains authoritative.

## Foreign Group

Foreign Institution only.

No cross-Tenant membership.

---

# 28. Main Topic / Official Homework Fixture

Create:

```text
Topic:
E2E S07 Main Topic
active

Homework:
E2E S07 Official Homework
active
group assignment
deadline = far future fixed UTC instant
```

Use a fixed far-future deadline that remains safely future for Stage 7 execution, e.g. year 2099.

Recipient snapshot:

```text
assessment_students includes:
target student
peer student
```

Result pair:

```text
topic_id = Main Topic
homework_assessment_id = Official Homework
blitz_assessment_id = null
cohort_snapshotted_at != null
locked_at = null
```

There must be:

```text
zero AssessmentAttempt rows
```

for this Homework before the real Student flow.

This allows the first real Start to prove official-pair locking.

---

# 29. Main Homework — Nine Questions

Create exactly one Question of every Stage 7 type, deterministic positions `1..9`.

## Q1 — Single Choice

At least two options.

Student E2E will choose a non-first option.

## Q2 — Multiple Choice

At least three options.

Safe `max_selections = 2`.

Student E2E selects exactly two.

## Q3 — True / False

Student E2E saves one boolean.

## Q4 — Short Written

Student E2E saves exact Unicode/apostrophe-containing text.

## Q5 — Open Written

Student E2E saves multiline text.

## Q6 — File Based

Allowed:

```text
pdf
docx
ppt
pptx
```

Effective max:

```text
2 MiB
```

via Institution setting.

## Q7 — Matching

At least two left and two right items.

Student E2E saves a partial mapping.

## Q8 — Ordering

At least three items.

Student E2E saves a partial ordering.

## Q9 — Fill in Blank

At least two blanks.

Student E2E saves a partial answer.

Backend Teacher correctness configuration exists as required by persistence, but Student APIs must not expose it.

---

# 30. Main Homework Attempt Policy

Initial:

```text
allowed = 3
used = 0
remaining = 3
in_progress_attempt = null
```

The Windows UI flow will create and finalize exactly three normal attempts.

After third terminal Attempt:

```text
used = 3
remaining = 0
Start Attempt absent in UI
fourth Start API = 409 attempts_exhausted
```

---

# 31. Direct Idempotency Homework Fixture

Create a separate active practice Homework:

```text
E2E S07 Idempotency Homework
```

Assigned to target Student.

Far-future deadline.

At least one simple non-file Question.

Initial:

```text
zero Attempts
```

Use only for direct real-API idempotency/no-op verification.

Do not mark official.

---

# 32. Unassigned Same-Institution Homework Fixture

Create:

```text
E2E S07 Peer-Only Homework
```

Assigned only to:

```text
e2e_s07_peer_student
```

Target Student must not see/access it.

Use for same-Institution assignment privacy checks.

---

# 33. Historical Frozen Assignment Fixture

Create:

```text
E2E S07 Historical Homework
```

with:

```text
assessment_students contains target Student
current Historical Group membership ended
status = closed or archived
```

Target Student direct Homework read must remain valid according to persisted assessment assignment.

Student Topic visibility may differ because Stage 5 Topic access is membership-based; this fixture specifically proves the Stage 7 Homework assignment contract.

A direct canonical Homework deep-link may be used in Flutter only if the delivered frontend can enter that route independently without requiring current Topic membership.

Do not change Stage 5 Topic rules to make this fixture discoverable.

---

# 34. Deadline Read-Reconciliation Fixture

Create:

```text
E2E S07 Deadline Read Homework
status = active
deadline = fixed past UTC instant
```

Recipient:

```text
target Student
peer Student
```

Preseed exactly one target Student Attempt:

```text
attempt_number = 1
status = in_progress
started_at < deadline
submitted_at = null
finalized_at = null
locked_at = null
```

Preseed one valid saved non-file answer:

```text
checking_status = pending
no score/review
```

Peer Student has no Attempt.

The exact Student Attempt GET in Section 76, executed in the Section 38A order before any broad Student Homework list, must reconcile the target Attempt to:

```text
status = submitted
submitted_at = null
finalized_at = exact Homework deadline
locked_at = exact Homework deadline
reason = homework_deadline_auto_submit
```

No peer Attempt may be fabricated.

---

# 35. Scheduler Deadline Fixture

Create another independent due active Homework:

```text
E2E S07 Scheduler Homework
deadline = fixed past UTC instant
```

Preseed one in-progress target Attempt + one saved answer.

Runner invokes:

```text
php artisan homework:reconcile-deadlines
```

through the guarded backend container only after the targeted lifecycle scenarios and the global candidate-set guard in Section 77.

Oracle requires the exact deadline finalization state.

No fake Attempt for never-started recipient.

---

# 36. Teacher-Close Fixture

Create:

```text
E2E S07 Teacher Close Homework
active
future deadline
```

Preseed:

```text
target Student in_progress Attempt
one saved answer
```

Teacher real API:

```text
POST /api/v1/teacher/homework/{homework}/close
```

must produce atomically:

```text
Homework.status = closed
Attempt.status = submitted
Attempt.submitted_at = null
Attempt.finalized_at = Homework.closed_at
Attempt.locked_at = Homework.closed_at
Attempt.finalization_reason = task_closed_auto_finalize
```

Saved answer remains unchanged.

---

# 37. Close-After-Deadline Precedence Fixture

Create:

```text
E2E S07 Due Teacher Close Homework
active
deadline = fixed past UTC instant
```

Preseed one in-progress target Attempt + saved answer.

Do not pre-reconcile.

Teacher real API close must:

```text
close Homework
```

but the Attempt finalization must be:

```text
homework_deadline_auto_submit
finalized_at = deadline
locked_at = deadline
submitted_at = null
```

not:

```text
task_closed_auto_finalize
```

This proves deadline precedence.

---

# 38. Android Manual Smoke Fixture

Create:

```text
E2E S07 Android Smoke Homework
active
far-future deadline
assigned target Student
```

Use a small subset of Question types sufficient for mobile execution, for example:

```text
single_choice
short_written
```

No existing Attempts.

The automated Windows runner must leave this fixture untouched.

---

# 38A. Lifecycle Fixture Consumption Order

The original runner order seeded multiple due `in_progress` lifecycle fixtures before the Main Student UI flow. That order was an integration-harness contract defect, not a production defect.

Production intentionally performs:

```text
ListStudentHomework
-> ReconcileStudentHomeworkDeadlines::all(...)
-> only afterward apply Topic/status filtering
```

The first normal Student Homework list can therefore reconcile other due Homework assigned to that Student. Also, `homework:reconcile-deadlines` is a global due-Homework reconciler with no integration-fixture scope; it consumes every active due Homework with an `in_progress` Attempt.

Before the first Flutter Student Homework list/read flow that can invoke broad Student deadline reconciliation, consume the dedicated lifecycle fixtures exactly once in this order:

```text
1. Deadline Read fixture
2. Due Teacher Close fixture
3. Future Teacher Close fixture
4. Scheduler fixture
5. only then Main Windows Student UI flow
```

Deadline Read uses the exact Student Attempt GET to exercise the specific Homework read-reconciliation path. Due Teacher Close uses the exact Teacher close endpoint to prove deadline precedence. Future Teacher Close uses the exact Teacher close endpoint to prove normal task-close finalization.

After those targeted scenarios become terminal/closed, the only remaining Stage 7 active-due `in_progress` lifecycle fixture must be `E2E S07 Scheduler Homework`. Only then may the global scheduler run, subject to the global candidate-set guard in Sections 77 and 83. After scheduler reconciliation, no Stage 7 due `in_progress` lifecycle fixture may remain before Main UI starts.

Immediately after seeding and before any lifecycle-triggering request, the baseline DB oracle must prove:

```text
Deadline Read Attempt = in_progress
Scheduler Attempt = in_progress
Teacher Close Attempt = in_progress; Homework deadline is future
Due Teacher Close Attempt = in_progress; Homework deadline is past

Main Homework:
used = 0
remaining = 3
no Attempts
far-future deadline
```

No Student Homework list request may occur before baseline evidence is captured or before all four lifecycle scenarios are consumed. Authenticate through the real direct API for the targeted lifecycle requests; do not navigate Flutter for those scenarios.

The Stage 7 seed remains one deterministic baseline. Do not introduce scenario-specific DB resets, partial reseeding between lifecycle phases, test-only production endpoints, scheduler scope options, or production behavior changes. A full runner retry may perform the existing guarded full Stage 7 manifest cleanup/reseed; individual lifecycle scenarios must not rewind committed evidence.

Earlier lifecycle consumption must leave Main Homework untouched. Sections 47–61 remain unchanged, including the initial three-attempt allowance and all Main UI assertions. The API/security matrix remains unchanged and runs after Main UI. Restart occurs after all automated mutation/oracle phases without reseeding, preserving the earlier lifecycle results as well as Main flow state.

Existing Backend Phase 2 and Frontend Phase 2 PASS evidence remains valid; this correction changes integration sequencing only.

---

# 39. Seeder Test Requirements

`Stage7E2eSeederTest` must prove:

- fails outside `testing`;
- fails on non-PostgreSQL;
- fails on wrong DB name;
- fails without password;
- fails with blank password;
- unsafe failure writes zero Stage 7 rows;
- run twice produces the same structural manifest state;
- all actor roles/Institutions are correct;
- no cross-Tenant relationships;
- main Homework has exactly 9 Question types/positions;
- main recipient snapshot target+peer;
- main result pair cohort snapshotted/unlocked;
- main initial Attempt count zero;
- due fixtures contain exact in-progress rows;
- answer fixtures use `pending` and no scoring;
- historical current membership is ended while `assessment_students` remains;
- target `student_submission_max_mb = 2`;
- cleanup deletes only manifest-owned state;
- unrelated sentinel DB row survives cleanup/reseed.

No real network.

---

# 40. Stage 7 Test File Assets

Create:

```text
frontend/integration_test/stage7_test_files.ps1
frontend/integration_test/verify_stage7_test_files.ps1
```

Do not commit large binary fixtures.

Generate deterministic runtime files under a temporary Stage 7 test directory.

At minimum:

| Key | Filename | Purpose |
|---|---|---|
| `valid_pdf` | `e2e_s07_answer.pdf` | small valid PDF |
| `replacement_pptx` | `e2e_s07_replacement.pptx` | small valid PPTX with different bytes |
| `fake_pdf` | `e2e_s07_fake.pdf` | `.pdf` extension but unsupported content |
| `over_limit_pdf` | `e2e_s07_over_limit.pdf` | valid/sized PDF > 2 MiB effective limit |

Use Stage 5 proven file-generation primitives where assumptions apply.

Generated files must be:

```text
deterministic
non-secret
cleaned in finally
```

Do not rely on external downloads/network.

---

# 41. Test File Verifier

`verify_stage7_test_files.ps1` must prove:

- expected names;
- expected extension;
- expected size boundary;
- valid PDF signature for valid PDF;
- valid OOXML/PPTX structure for replacement;
- fake PDF intentionally fails PDF content identity;
- over-limit file is `> 2 MiB`;
- generated files are under the approved temporary root;
- cleanup removes all generated Stage 7 files.

Do not print raw file bytes.

---

# 42. Stage 7 Integration Dart Support

Create:

```text
frontend/integration_test/stage7_e2e_support.dart
```

It may provide only integration-test support such as:

- deterministic keyed/hit-testable widget waits;
- scoped widget lookup;
- production app bootstrap with real API target;
- deterministic `IdempotencyKeyGenerator` test implementation;
- deterministic `StudentSubmissionFilePicker` queue backed by generated file manifest;
- test `LocalFilePlatformAdapter` sink for Open/Save As assertions;
- login/navigation helpers;
- safe JSON utility for direct client evidence only when existing harness requires it.

Do not place product business rules in the harness.

Do not fake repositories/controllers/Dio.

---

# 43. Stable Selector Discipline

Integration selectors must prefer:

```text
Key
route target identity
specific dialog/card scope
semantic label
```

over globally matching visible text.

At minimum use production keys added by Stage 7 tasks where available:

```text
studentHomeworkSection
studentHomeworkDetailScreen
studentHomeworkStartAttemptButton
studentHomeworkResumeAttemptButton
studentHomeworkAttemptScreen
studentHomeworkSubmitAttemptButton
studentHomeworkSubmitConfirmDialog
studentHomeworkSubmitConfirmButton
```

For dynamic Question editors, scope to:

```text
Question ID/Question card
```

before finding controls.

Do not use ambiguous global:

```text
find.text("Save")
```

when several Questions can render Save.

---

# 44. Async Wait Discipline

Do not assume:

```text
API completed
-> next widget is ready in same frame
```

Use bounded condition-based waits.

For interaction require target control to be:

```text
present
enabled
hit-testable
```

where needed.

Do not use arbitrary sleeps as correctness synchronization.

Polling may use a small bounded pump interval only as the implementation of a condition-based wait.

Timeout failure must report the intended state/key, not dump secrets.

---

# 45. Windows E2E Test Asset

Create:

```text
frontend/integration_test/stage7_student_homework_flow_test.dart
```

The test must run the real production application/client stack.

It may use deterministic provider overrides only for:

```text
idempotency-key generator
native file picker
local Open/Save sink
API target configuration
```

No fake repository/data source.

---

# 46. Deterministic UI Idempotency Keys

The E2E test must inject a deterministic queue of valid UUID-v4 values.

Example valid shape:

```text
07111111-1111-4111-8111-111111111111
07222222-2222-4222-8222-222222222222
07333333-3333-4333-8333-333333333333
...
```

Use unique known keys for:

- Main Attempt #1 Start;
- Main Attempt #1 Submit;
- Attempt #2 Start/Submit;
- Attempt #3 Start/Submit;
- any dedicated UI Start/Submit scenario.

Do not reuse a deterministic key accidentally across different logical operations unless a test explicitly verifies operation-scope independence.

The E2E only overrides randomness for deterministic evidence; production generator behavior was already Phase-2 tested.

---

# 47. Windows UI Flow — Login / Homework Read

Through production UI:

1. login as `e2e_s07_student`;
2. reach Student workspace;
3. open `E2E S07 Main Topic`;
4. find the independent Homework section;
5. open `E2E S07 Official Homework`;
6. verify:
   ```text
   status = Active
   attempts used = 0
   remaining = 3
   no current in-progress Attempt
   no score
   ```
7. verify all nine safe Question read surfaces;
8. verify no correct-answer/checking labels appear.

Do not inspect hidden Teacher configuration through test-only product APIs.

---

# 48. Windows UI Flow — Attempt #1 Start

Press:

```text
Start Attempt
```

Require:

```text
production POST
201 or expected normal create response
canonical nested Attempt route
Attempt 1
status in_progress
```

No optimistic-only route entry.

The final DB oracle must prove:

```text
topic_result_pairs.locked_at = attempt1.started_at
```

and that first Attempt/pair lock are atomically persisted.

---

# 49. Windows UI Flow — Eight Non-File Answers

Save deterministic answers.

## Single

Choose known non-first option.

## Multiple

Select exactly two safe options.

## True / False

Save deterministic boolean.

## Short Written

Use exact Unicode/apostrophe test text, for example:

```text
O‘zbekiston — E2E S07
```

Oracle later requires exact stored value.

## Open Written

Use multiline deterministic text.

## Matching

Save a partial mapping.

## Ordering

Save a partial ordering.

## Fill Blank

Save one of at least two blanks.

After each save:

- wait for server-confirmed saved state;
- do not use arbitrary sleep;
- no correctness/scoring feedback may appear.

---

# 50. Windows UI Flow — File Unsupported Content

For the File Question:

1. deterministic picker returns:
   ```text
   e2e_s07_fake.pdf
   ```
2. local extension/size validation allows selection;
3. press upload;
4. real backend binary inspector returns:
   ```text
   422 unsupported_file_type
   ```
5. UI shows safe unsupported-content message;
6. no saved server file answer exists;
7. no orphan Student submission File row/blob may survive.

This proves backend content authority over client extension.

---

# 51. Windows UI Flow — First Valid File Upload

Choose:

```text
e2e_s07_answer.pdf
```

Then explicit:

```text
Upload answer
```

Require:

- production multipart PUT;
- progress state;
- confirmed 200;
- saved file metadata visible;
- no storage path/checksum exposed.

Oracle later verifies:

```text
File.category = student_submission
uploaded_by = target Student
private storage key
correct checksum/size
AnswerFile link
AttemptAnswer.pending
```

---

# 52. Windows UI Flow — File Replacement

Choose:

```text
e2e_s07_replacement.pptx
```

as replacement.

Upload replacement.

Require:

```text
confirmed 200
same server File ID as first upload
new original_name/extension/size
```

Oracle verifies:

- same `attempt_answers.id`;
- same `answer_files.id`;
- same `files.id`;
- DB points to replacement blob;
- previous blob is no longer authoritative;
- old blob cleanup completed best-effort as expected by production;
- replacement blob exists privately.

---

# 53. Windows UI Flow — Protected Open / Save As

Use current saved replacement file.

## Open

Production:

```text
GET /files/{fileId}/download
```

must run.

Integration local sink receives:

```text
same File ID
pptx extension
exact replacement bytes
```

## Save As

Production protected download runs.

Local save sink receives:

```text
dialog title = Save submitted answer
safe filename
exact replacement bytes
canonical MIME
```

No public URL.

---

# 54. Windows UI Flow — Attempt Re-entry

With all nine answers confirmed:

1. navigate back using clean route;
2. open/resume the current Attempt;
3. Resume must navigate directly;
4. no redundant Start POST;
5. GET Attempt must restore all saved answer states;
6. file metadata remains current;
7. no dirty local state appears.

This proves persisted resume.

---

# 55. Windows UI Flow — Attempt #1 Submit

Before Submit:

```text
confirmed answered count = 9
unanswered = 0
```

Press Submit.

Confirmation must show:

```text
9 of 9 answers are saved
Attempt will become locked/read-only
```

Confirm.

Require:

```text
POST /student/attempts/{attempt1}/submit
200
```

UI immediately becomes terminal:

```text
Submitted by you
no editors
no file upload
no Submit button
```

No score/checking.

---

# 56. Windows UI Flow — Attempt #2 Zero-Answer Submit

Return to refreshed Homework detail.

Require:

```text
used = 1
remaining = 2
Start Attempt available
```

Start Attempt #2.

Do not save any answers.

Submit.

Confirmation must show:

```text
0 of 9 answers are saved
9 Questions have no saved answer
```

Confirm remains enabled.

Require successful terminal explicit Submit.

Oracle later proves:

```text
Attempt #2 has zero attempt_answers
reason = student_submit
```

---

# 57. Windows UI Flow — Attempt #3 and Exhaustion

Return to Homework.

Require:

```text
used = 2
remaining = 1
```

Start Attempt #3.

Zero-answer Submit is sufficient.

After terminal:

```text
used = 3
remaining = 0
Start Attempt absent
```

Direct API later verifies:

```text
fourth Start
-> 409 attempts_exhausted
```

No Attempt #4 DB row.

---

# 58. Main Official Pair Oracle

After first Start and final main flow, independent DB oracle must prove:

```text
pair.locked_at != null
pair.locked_at = Attempt #1.started_at
pair.cohort_snapshotted_at unchanged
homework_assessment_id unchanged
blitz_assessment_id remains null
```

Attempt #2/#3 must not change pair lock timestamp.

---

# 59. Main Attempt #1 DB Oracle

Require exact:

```text
attempt_number = 1
status = submitted
submitted_at != null
finalized_at = submitted_at
locked_at = submitted_at
finalization_reason = student_submit
official_score_eligible = true
possible_points = Assessment total snapshot

earned_points = null
normalized_score = null
scoring_completed_at = null
```

Exactly 9 persisted AttemptAnswer parents after all nine Questions were answered.

Each:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

No Stage 9 scoring data.

---

# 60. Typed Answer DB Oracle

Verify each answer lands only in the expected normalized table.

At minimum:

```text
single_choice
-> answer_choice_selections exactly one

multiple_choice
-> answer_choice_selections exactly selected safe IDs

true_false
-> answer_boolean_values exact bool

short_written
-> answer_text_values exact Unicode text

open_written
-> answer_text_values exact multiline text

matching
-> answer_matching_pairs exact partial mapping

ordering
-> answer_ordering_items exact partial positions

fill_in_blank
-> answer_fill_blank_values exact partial value

file_based
-> answer_files exactly one -> same File ID after replacement
```

No generic JSON fallback.

No wrong typed-child residue.

---

# 61. Attempt #2/#3 Oracle

Attempt #2:

```text
attempt_number = 2
status = submitted
reason = student_submit
zero AttemptAnswer rows
```

Attempt #3:

```text
attempt_number = 3
status = submitted
reason = student_submit
zero or intentionally minimal AttemptAnswer rows according to UI flow
```

No Attempt #4.

---

# 62. Direct API Security / Business Assets

Create:

```text
frontend/integration_test/stage7_api_security.ps1
frontend/integration_test/verify_stage7_api_security.ps1
```

It must use real API/Sanctum actors.

No DB mutation through fake API.

---

# 63. API Security — Unauthenticated / Wrong Role

Verify Student Stage 7 endpoints deny unauthenticated access.

At minimum:

```text
GET /student/homework
GET /student/homework/{id}
POST /student/homework/{id}/attempts
GET /student/attempts/{id}
PUT /student/attempts/{id}/answers/{question}
POST /student/attempts/{id}/submit
```

Unauthenticated:

```text
401 authentication_required
```

Teacher/Parent wrong role:

```text
403 forbidden
```

according to existing middleware/error contract.

Do not expose target existence.

---

# 64. API Security — Same-Institution Unassigned Student

As:

```text
e2e_s07_unassigned_student
```

verify:

- target main Homework does not appear in list;
- direct main Homework ID => `404 resource_not_found`;
- direct target Attempt ID => `404`;
- target Student submission File ID => `404`;
- no side-effect deadline reconciliation can be triggered against inaccessible target beyond behavior already authorized by scoped reads.

---

# 65. API Security — Cross-Institution Student

As:

```text
e2e_s07_foreign_student
```

same direct IDs:

```text
404 resource_not_found
```

No Tenant data leaks.

---

# 66. API Security — Student Submission Download

Verify:

## Owner Student

```text
GET /files/{current submission file}/download
-> 200
```

Headers:

```text
Content-Type canonical
Content-Disposition attachment
Cache-Control private, no-store
X-Content-Type-Options nosniff
```

Bytes equal replacement fixture.

## Same-Institution other Student

```text
404
```

## Foreign Student

```text
404
```

## Teacher

```text
404
```

Stage 7 Teacher download remains deferred to Stage 9.

---

# 67. API Security — Correct Answer Leakage

Recursively inspect real Student Homework/Attempt success JSON.

Assert absent at every depth:

```text
is_correct
correct_value
accepted_answers
correct_position
match_key
checking_mode
configuration
client_key
```

Student-safe responses may include:

```text
max_selections
```

but must not identify correct options.

Any prohibited key is an integration P1.

---

# 68. API Security — Foreign Nested Answer IDs

Against an owned in-progress direct-API fixture, verify:

- foreign Question ID;
- another Question's option ID;
- foreign matching item;
- foreign ordering item;
- foreign blank ID

cannot widen scope.

Expected privacy-safe/validation response according to final backend contract, with no foreign entity disclosure.

No cross-Tenant answer row may be written.

---

# 69. API Strict Transport Matrix

At minimum verify:

## Start

Missing/malformed:

```text
Idempotency-Key
```

=> `422 validation_failed`.

Unknown body/query rejected.

## Submit

Missing/malformed key => `422`.

Non-empty body/query rejected.

## Answer JSON

Unknown protected fields rejected.

## File answer

JSON `file_based` rejected.

Multipart `file_based` accepted.

Multipart non-file answer rejected.

Do not require exhaustive every-invalid-field E2E if focused backend tests already cover them; keep this matrix to cross-layer high-risk transport boundaries.

---

# 70. Direct API Idempotency Fixture — Start

Use `E2E S07 Idempotency Homework`.

Use one deterministic valid UUID key:

```text
K
```

First:

```text
POST Start with K
-> 201
-> Attempt A
```

Repeat exact same request/key:

```text
-> same original logical status
-> same Attempt A
```

Use another valid key:

```text
K2
```

while A remains in progress:

```text
-> 200
-> same Attempt A
```

DB:

```text
exactly one in_progress Attempt
one completed idempotency row for K
one completed idempotency row for K2 if backend completes resume request as designed
```

Record actual final contract semantics.

---

# 71. Idempotency Operation Scope Independence

Use the same UUID value:

```text
K
```

for:

```text
student.homework.attempt.start
student.homework.attempt.submit
```

on the same Student.

Both operations are independently valid because `operation` is part of idempotency scope.

DB must contain separate records with distinct operation codes.

---

# 72. Direct API Answer No-Op

On direct idempotency fixture Attempt A:

1. save one non-file answer;
2. record:
   ```text
   AttemptAnswer.updated_at
   ```
3. repeat exact semantic answer PUT;
4. require:
   ```text
   200
   same semantic response
   AttemptAnswer.updated_at unchanged
   ```
5. `AssessmentAttempt.updated_at` also remains unchanged by answer save.

This proves backend no-op behavior through real API/PostgreSQL.

---

# 73. Direct API Submit Idempotency

Submit Attempt A using key `K`.

First:

```text
200
student_submit
```

Repeat same key:

```text
200
same Attempt
no finalization timestamp rewrite
```

Use different new key after terminal:

```text
409 attempt_not_editable
```

No completed success idempotency row may be created for losing new key.

---

# 74. Attempts Exhaustion API

After UI main Homework has terminal Attempts #1..3:

```text
POST Start with valid new key
-> 409 attempts_exhausted
```

DB:

```text
no Attempt #4
```

No committed incomplete idempotency row for rejected fourth Start.

---

# 75. Historical Assignment API

As target Student after current Historical Group membership ended:

```text
GET /student/homework/{historical}
```

must succeed according to frozen `assessment_students` assignment.

If status permits a Start in the final fixture, Start may also be verified.

Do not change current Group membership to make this pass.

This scenario verifies Stage 7 assignment scope is independent of current membership.

---

# 76. Deadline Read Reconciliation — Real Request

Execute this scenario first, before any broad Student Homework list, following Section 38A.

Authenticate the target Student through the real direct API. Do not navigate the Flutter Student Homework UI for this scenario.

Before request oracle confirms:

```text
Deadline Read Attempt = in_progress
```

Call only the exact required Attempt read:

```text
GET /student/attempts/{deadlineReadAttempt}
```

Expected API resource now terminal:

```text
status = submitted
submitted_at = null
finalized_at = exact Homework deadline
locked_at = exact Homework deadline
reason = homework_deadline_auto_submit
```

Additionally, the oracle must prove:

```text
Scheduler Attempt remains in_progress
Due Teacher Close Attempt remains in_progress
Future Teacher Close Attempt remains in_progress
```

This confirms the specific read did not consume unrelated lifecycle fixtures.

Then answer PUT:

```text
-> 409 deadline_passed or attempt_not_editable according to exact final endpoint precedence
```

No answer mutation occurs.

Oracle proves pre-existing saved answer remains.

Peer recipient still has no Attempt.

---

# 77. Scheduler Deadline Reconciliation

Run the global scheduler only after the Deadline Read, Due Teacher Close, and Future Teacher Close scenarios have been consumed in the Section 38A order.

Immediately before the first command, the DB/oracle guard must enumerate the actual global production scheduler candidate set, using the production predicate and current DB/application time:

```text
active Homework
deadline_at <= current DB/application time
at least one in_progress Attempt
```

Require exactly one global candidate, whose identity and relationships match the explicit Stage 7 manifest:

```text
E2E S07 Scheduler Homework
Scheduler fixture Attempt = in_progress
```

Do not infer safety from Stage 7-scoped queries alone. If any non-Stage-7 or unexpected Homework would be mutated, STOP before executing the command. Do not delete, reset, or rewrite unrelated rows to make the guard pass. Classify an unexpected non-Stage-7 candidate as an `environment/runtime isolation failure` within the `environment/runtime defect` category; incorrect Stage 7-owned fixture state is an `integration-harness defect`.

Only after the exact candidate-set guard passes, run in the guarded backend container:

```bash
php artisan homework:reconcile-deadlines
```

Require exit code 0.

Oracle:

```text
status = submitted
submitted_at = null
finalized_at = deadline
locked_at = deadline
reason = homework_deadline_auto_submit
```

No never-started recipient Attempt fabricated.

Before the second command, enumerate the global candidate set again and require it to be empty; stop if an unexpected candidate would be mutated. Then run the command a second time:

```text
exit code 0
zero additional transition/write effect
terminal timestamps unchanged
```

This proves idempotent reconciliation.

Afterward the oracle must require:

```text
zero active due Stage 7 Homework with in_progress Attempts
```

Main Windows UI may start only after this evidence is captured.

---

# 78. Teacher Close Auto-Finalization

Execute after Due Teacher Close and before the global scheduler, following Section 38A.

Login/authenticate real target Teacher via direct API helper.

Before:

```text
Homework.status = active
Close fixture Attempt = in_progress
future deadline
```

Call only the exact Teacher close endpoint:

```text
POST /teacher/homework/{homework}/close
```

Expected 200/contract success.

Oracle exact:

```text
Homework.status = closed
Attempt.status = submitted
submitted_at = null
finalized_at = Homework.closed_at
locked_at = Homework.closed_at
reason = task_closed_auto_finalize
saved answer preserved
```

Student later GET sees terminal state.

After close, the oracle must also prove `Scheduler Attempt remains in_progress`.

---

# 79. Teacher Close After Deadline — Deadline Wins

Execute after Deadline Read and before Future Teacher Close and the global scheduler, following Section 38A.

Before the targeted Teacher close, the oracle must prove:

```text
Due Teacher Close Homework = active
deadline < now
Due Teacher Close Attempt = in_progress
```

Authenticate the real target Teacher and call only:

```text
POST /teacher/homework/{dueCloseHomework}/close
```

The Teacher close path must not be replaced by scheduler reconciliation for this scenario.

Oracle:

```text
Homework.status = closed
Attempt.status = submitted
submitted_at = null
finalized_at = exact deadline
locked_at = exact deadline
reason = homework_deadline_auto_submit
```

Teacher close must not overwrite:

```text
task_closed_auto_finalize
```

onto the due Attempt.

Afterward the oracle must also prove `Scheduler Attempt remains in_progress`.

---

# 80. No Fabricated Attempts

Across:

- deadline read fixture;
- scheduler fixture;
- teacher-close fixture;
- due-close fixture;

the oracle must explicitly verify every assigned never-started Student still has:

```text
zero AssessmentAttempt rows
```

Stage 7 auto-finalization operates only on existing in-progress Attempts.

---

# 81. Database Oracle Assets

Create:

```text
frontend/integration_test/stage7_oracle.ps1
frontend/integration_test/verify_stage7_oracle.ps1
```

The oracle must inspect authoritative backend/PostgreSQL state independently of Flutter.

---

# 82. Oracle Safe Execution

Do not pass large PHP programs through command-line arguments.

Use the existing proven repository-safe pattern when applicable:

```text
PowerShell creates script content
-> stdin
-> restricted temporary container file
-> short PHP execution wrapper
-> guaranteed cleanup
```

or another already-established Stage 6 safe primitive with equivalent guarantees.

Temporary files:

- restricted;
- Stage 7-specific names;
- deleted in finally;
- no secret output.

Do not print DB credentials/tokens.

---

# 83. Oracle Scope Guard

Fixture DB queries must scope to explicit Stage 7 manifest IDs. The sole global read exception is the read-only scheduler candidate enumeration required below; it protects unrelated test DB state and never grants mutation or cleanup ownership.

Do not use broad prefix matching as the authority.

The oracle must first verify expected:

```text
Institution IDs
User IDs
Topic IDs
Assessment IDs
Question IDs
Attempt IDs where created
File IDs where created
```

belong to Stage 7 fixture relationships.

If manifest identity is inconsistent:

```text
fail
```

Do not continue with broad queries.

Before the first global scheduler command, enumerate its actual global candidates using the Section 77 production predicate. Validate that the complete candidate set contains exactly the expected manifest-owned `E2E S07 Scheduler Homework`, with its expected Institution and Homework/Assessment identity.

If any candidate exists outside that exact expected Homework, STOP before the scheduler. A Stage 7-only query cannot prove this safety condition. Do not mutate, delete, or rewrite unexpected rows to make the guard pass. Before the second idempotency invocation, repeat the global enumeration and require zero candidates as specified in Section 77.

---

# 84. Oracle Core Tables

Inspect at minimum:

```text
institutions
institution_settings
users
groups
group_teacher_memberships
group_student_memberships

topics
assessments
homework_assignments
assessment_students
topic_result_pairs

questions
question_choice_options
question_matching_items
question_ordering_items
question_fill_blanks

assessment_attempts
attempt_answers
answer_choice_selections
answer_text_values
answer_boolean_values
answer_matching_pairs
answer_ordering_items
answer_fill_blank_values
answer_files

files
idempotency_records
```

Use actual final table names from delivered Stage 7 schema if minor naming differs, but do not reinterpret behavior.

---

# 85. Oracle File Storage Verification

For current saved Student submission File:

require:

```text
category = student_submission
uploaded_by_user_id = target Student
removed_at = null
storage_disk = configured private disk
storage_key under Stage 7 Student submission namespace
extension/mime/size/checksum match replacement fixture
```

Physical blob:

```text
exists on private volume
bytes/checksum match replacement
```

Old replacement predecessor blob:

```text
not authoritative
```

If production cleanup deletes old blob after commit, require it absent.

No blob under public storage.

---

# 86. Oracle Idempotency Verification

Inspect relevant Stage 7 idempotency records.

Require scope:

```text
institution_id = target
user_id = target Student
operation exact
idempotency_key exact
request_fingerprint non-empty SHA-256 form
result_resource_type = assessment_attempt on success
result_resource_id = expected Attempt
response_status expected
completed_at non-null on success
```

Rejected operations:

```text
no committed incomplete/success record
```

Operation separation:

```text
student.homework.attempt.start
student.homework.attempt.submit
```

must remain distinct.

---

# 87. Oracle No-Scoring Verification

Across every Stage 7 Student-saved/finalized Attempt:

require:

```text
earned_points = null
normalized_score = null
scoring_completed_at = null
```

Every Student-saved AttemptAnswer:

```text
checking_status = pending
awarded_points = null
feedback = null
checked_by_user_id = null
checked_at = null
```

No Stage 9 result artifacts may be created by Stage 7 execution.

---

# 88. Oracle Verifier Unit-Like Coverage

`verify_stage7_oracle.ps1` should test pure validation helpers using synthetic safe objects.

At minimum prove verifier rejects:

- wrong Attempt status/reason/timestamps;
- wrong answer child table;
- scoring data present;
- pair lock changed on later Attempt;
- File ID changed on replacement;
- public storage path;
- incorrect checksum/size;
- fabricated recipient Attempt;
- incomplete idempotency record;
- wrong operation/key/result;
- cross-Tenant row;
- unexpected extra Attempt #4.

The pure scheduler candidate-set validator must additionally reject:

- zero candidates before the first scheduler invocation;
- two Stage 7 scheduler candidates;
- Deadline Read still `in_progress` when the scheduler is about to run;
- Due Teacher Close still `in_progress` when the scheduler is about to run;
- an unexpected non-Stage-7 global scheduler candidate;
- the wrong expected scheduler Homework ID.

For the first invocation, accept only exactly one global candidate equal to the explicit manifest-owned `E2E S07 Scheduler Homework`. Separately verify the second-invocation guard accepts only an empty global candidate set.

Then invoke the actual oracle during the real runner.

---

# 89. API Security Verifier

`verify_stage7_api_security.ps1` must exercise pure response assertions without network where practical.

Validate:

- expected success envelope shapes;
- error code/status mapping;
- recursive prohibited-key detector;
- protected download security-header parser expectations;
- token redaction/no token logging helper;
- idempotency status assertions.

Then the real runner invokes the actual API security matrix.

---

# 90. Windows Runner Asset

Create:

```text
frontend/integration_test/run_stage7_windows_e2e.ps1
```

Parameters:

```powershell
[Parameter(Mandatory = $true)][string] $FlutterExecutable
[Parameter(Mandatory = $true)][ValidateRange(1,65535)][int] $ApiPort
```

Use:

```text
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

Dedicated:

```text
backend container = testlabuz-stage7-e2e-app
API = http://127.0.0.1:$ApiPort/api/v1
```

---

# 91. Runner Secret Handling

Generate a strong random Stage 7 password in memory using cryptographic RNG.

Set only for seeder execution:

```text
STAGE7_E2E_PASSWORD
```

Never:

- print it;
- write it to repository file;
- expose it in command diagnostics;
- persist bearer tokens.

Dart integration receives required login password through the established safe process/environment boundary.

Clear sensitive in-memory references/environment variables in finally where applicable.

---

# 92. Runner Preparation Order

Before any full UI flow:

1. validate Flutter executable/pin;
2. execute runtime guard;
3. execute runtime-guard verifier;
4. generate/verify Stage 7 runtime files;
5. run focused Seeder verification as required;
6. seed one deterministic Stage 7 baseline;
7. run baseline DB oracle, including all Section 38A lifecycle and Main Homework preconditions;
8. run API-security pure verifier;
9. execute the pre-UI lifecycle phase in this exact order: Deadline Read reconciliation; Due Teacher Close / deadline precedence; Future Teacher Close; guarded global Scheduler reconciliation;
10. run lifecycle oracle confirming all dedicated due fixtures are consumed;
11. start the Main Windows real-stack Flutter UI flow.

No Student Homework list/UI flow may occur between seeding in Step 6 and completion of the guarded scheduler phase in Step 9. Capture baseline evidence before any lifecycle-triggering request. Only the targeted lifecycle API requests and the guarded scheduler may trigger lifecycle transitions before Main UI.

Do not rerun Backend/Frontend Phase 2 suites.

---

# 93. Integration Harness Preflight — Mandatory

After integration assets are delivered to `origin/main` and before the first full runner, including its pre-UI lifecycle phase, ChatGPT performs a focused read-only preflight.

Review at minimum:

```text
Stage7E2eSeeder
Stage7E2eSeederTest

stage7_runtime_guard.ps1
verify_stage7_runtime_guard.ps1

stage7_test_files.ps1
verify_stage7_test_files.ps1

stage7_oracle.ps1
verify_stage7_oracle.ps1

stage7_api_security.ps1
verify_stage7_api_security.ps1

stage7_e2e_support.dart
stage7_student_homework_flow_test.dart
run_stage7_windows_e2e.ps1
prepare_stage7_manual_smoke.ps1
```

Preflight validates:

- stable Key/ID/scoped selectors;
- no ambiguous global text assertions;
- bounded condition waits;
- hit-testability before interaction;
- no arbitrary sleep synchronization;
- deterministic file/idempotency fixture queues;
- safe private-volume assumptions;
- correct API expectations;
- exact Stage 7 lifecycle expectations;
- no Student Homework list occurs before lifecycle consumption;
- Deadline Read precedes scheduler execution;
- Due Teacher Close precedes scheduler execution;
- Future Teacher Close precedes scheduler execution;
- the global scheduler has a fail-closed exact candidate-set guard;
- Main UI begins only after zero Stage 7 due `in_progress` lifecycle fixtures remain;
- no partial scenario reset/reseed hides sequencing defects;
- tenant-safe fixture ownership;
- DB oracle scoping;
- cleanup paths;
- safe PowerShell/container transport;
- restart checks;
- no production behavior modifications hidden in harness.

If preflight finds a harness defect:

```text
do not run full runner
```

Issue a focused integration-asset fix first.

---

# 94. Full Windows Runner Invocation

After preflight PASS, Project Owner runs from repository context:

```powershell
powershell -ExecutionPolicy Bypass `
  -File frontend/integration_test/run_stage7_windows_e2e.ps1 `
  -FlutterExecutable "<repository-pinned Flutter executable>" `
  -ApiPort <dedicated-loopback-port>
```

Exact executable path/port are environment values, not hardcoded repository secrets.

Record:

- command;
- audited SHA;
- exit code;
- scenario PASS/FAIL;
- duration;
- relevant artifact/output summary.

---

# 95. Runner Phase Order

The full runner must execute these deterministic phases in order:

```text
A. Runtime guard
B. Seed baseline
C. Baseline oracle

D. Deadline Read reconciliation
E. Deadline Read oracle

F. Due Teacher Close / deadline precedence
G. Due Teacher Close oracle

H. Future Teacher Close auto-finalization
I. Future Teacher Close oracle

J. Global Scheduler candidate-set fail-closed guard
K. Scheduler reconciliation
L. Scheduler/idempotency oracle

M. Main Windows Student UI flow
N. Main-flow oracle

O. Direct API idempotency/security/business matrix
P. API/DB oracle

Q. Backend restart
R. Post-restart API/file/persistence verification
S. Final automated oracle

T. Preserve manual-smoke fixture
U. Cleanup generated local test files
```

Required Android manual smoke follows automated runner evidence. Final DB fixture cleanup waits until required Android manual smoke evidence is complete.

---

# 96. Backend Restart Persistence Verification

After automated mutation/oracle phases:

1. restart:
   ```text
   testlabuz-stage7-e2e-app
   ```
2. wait through exact runtime HTTP boundary;
3. rerun runtime guard;
4. do not reseed;
5. verify:
   - main Homework three Attempts still exist;
   - result pair lock timestamp unchanged;
   - idempotency records persist;
   - explicit Submit timestamps/reasons persist;
   - deadline/close finalizations persist;
   - current Student submission File row persists;
   - private replacement blob persists;
   - protected owner download still returns exact replacement bytes.

A backend restart must not lose private submission state.

Lifecycle results created before Main UI must remain persisted through restart alongside Main flow state. Do not reseed or reset lifecycle fixtures before restart.

---

# 97. Post-Restart Flutter/API Check

After restart, perform a small real-stack read using the production Student frontend or direct API:

```text
login target Student
open main Homework/Attempt historical state
confirm terminal read-only
download current saved submission
```

No mutation required.

This is not a second full E2E run.

---

# 98. Android Manual Smoke Preparation

Create:

```text
frontend/integration_test/prepare_stage7_manual_smoke.ps1
```

It must:

- run the same runtime guard;
- confirm target backend/API identity;
- confirm Stage 7 manual-smoke fixture exists and remains unmutated;
- if reset is required, use the guarded full Stage 7 manifest cleanup/reseed only as a new full runner retry, never a partial scenario reset;
- print only non-secret manual actor login and safe fixture labels;
- never print password unless the Project Owner explicitly supplies/handles it through the established secure workflow;
- leave backend ready for Android app connection.

Do not bypass real auth.

---

# 99. Android Manual Smoke Scope

On a real Android target/build using the Stage 7 backend:

1. login as target Student;
2. open:
   ```text
   E2E S07 Android Smoke Homework
   ```
3. verify mobile Homework detail;
4. Start Attempt;
5. answer Single Choice;
6. answer Short Written;
7. Save both;
8. open Submit confirmation;
9. verify partial/unanswered count is shown;
10. Submit;
11. verify terminal:
    ```text
    Submitted by you
    ```
12. Back to Homework;
13. verify used/remaining state refreshed.

Do not require Android file picker/upload for the manual smoke because the full Windows real-stack flow already verifies production file upload/download and Phase 2 verifies mobile file UX.

---

# 100. Android Manual Smoke DB Verification

After manual smoke, use the same Stage 7 oracle in manual-smoke mode.

Require:

```text
one Android Smoke Attempt
status = submitted
reason = student_submit
exact two saved answers
remaining scoring fields null
```

No hidden score/checking.

If manual smoke fails, classify:

```text
production
harness/manual setup
environment/device
```

before any fix.

---

# 101. Final Cleanup

After all automated and manual required evidence is collected:

1. invoke guarded Stage 7 cleanup;
2. delete manifest-owned Stage 7 DB rows only;
3. delete manifest-owned Stage 7 private blobs only;
4. delete generated local Stage 7 test files;
5. remove temporary container scripts/files;
6. clear runner temporary secret/token variables;
7. preserve unrelated DB rows;
8. preserve unrelated private files/volumes.

Do not delete the named private volume itself unless the Project Owner explicitly chooses environment cleanup after evidence, because runtime provisioning is external.

---

# 102. Cleanup Oracle

Final cleanup verification must prove:

```text
zero manifest-owned Stage 7 fixture rows
zero manifest-owned Stage 7 private blobs
zero generated Stage 7 local test files
```

and at least one unrelated sentinel row/file remains unchanged where the verifier created/identified one safely.

No prefix-only broad delete.

---

# 103. Integration Asset Focused Verification — Seeder

Before delivery, Codex runs only focused integration-asset verification.

Backend:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app \
  php artisan test tests/Feature/Seeders/Stage7E2eSeederTest.php
```

Use the repository's normal container command form.

No full backend suite.

---

# 104. Integration Asset Focused Verification — PowerShell

Run the pure/safe verifiers that do not require the full Stage 7 runtime where possible:

```text
verify_stage7_runtime_guard.ps1
verify_stage7_test_files.ps1
verify_stage7_oracle.ps1
verify_stage7_api_security.ps1
```

If a verifier includes an "actual runtime" branch, run only the pure branch during Codex focused asset verification unless the contract/runtime is explicitly available.

The Project Owner runs actual-runtime guard verification during integration.

---

# 105. Integration Asset Focused Verification — Dart

From `frontend/`:

```bash
fvm dart format --output=none --set-exit-if-changed \
  integration_test/stage7_e2e_support.dart \
  integration_test/stage7_student_homework_flow_test.dart
```

Run targeted analysis:

```bash
fvm flutter analyze --no-pub \
  integration_test/stage7_e2e_support.dart \
  integration_test/stage7_student_homework_flow_test.dart
```

If the Flutter analyzer CLI accepts directory/file targets differently in the delivered toolchain, use the established repository-equivalent targeted command and report exact invocation.

Do not run full frontend suite/build during integration-asset implementation.

---

# 106. Integration Asset Diff Verification

Repository root:

```bash
git diff --check
```

Then focused diff review:

- only integration/test assets;
- no production changes;
- no secrets;
- no binaries/generated test files committed;
- no broad previous harness refactor;
- no weakened assertions;
- no arbitrary sleeps;
- no unsafe PowerShell shell-argument payload transport.

---

# 107. Integration Failure Classification

Every material failed assertion/command must be classified before a fix.

Exactly one:

```text
production defect
integration-harness defect
environment/runtime defect
```

Examples:

## Production

```text
backend returns correct-looking 200 but DB row violates contract
Student sees answer key
same-key Start creates two Attempts
file replacement creates a new File ID
Submit allows post-terminal mutation
```

## Harness

```text
global text selector hits two Save buttons
test assumes same-frame UI transition
oracle expects task_closed when deadline should win
generated fake PDF accidentally becomes valid
```

## Environment

```text
dedicated container stopped
wrong private volume
Docker port not loopback
Flutter executable does not match .fvmrc
Android device cannot reach configured host
```

Do not modify production to satisfy harness/environment defects.

---

# 108. Evidence Reuse Policy

Fresh Backend/Frontend Phase 2 PASS evidence is reused.

Do not rerun:

```text
full backend suite
full frontend suite
full frontend analyze
full format checkpoint
standalone Windows build
standalone Android build
```

merely because integration begins.

If a production fix is later delivered, ChatGPT decides exact invalidated checkpoint/integration evidence.

Examples:

```text
narrow file download fix
-> file focused tests + affected integration file path, maybe frontend file regressions

shared Student session/router fix
-> may invalidate Frontend Phase 2 routing/session evidence + broader integration

schema/idempotency fix
-> may invalidate Backend Phase 2 + Start/Submit integration/oracle
```

Every previously failing mandatory command/path must eventually pass.

---

# 109. Integration Acceptance Criteria — Real UI

PASS requires the Windows production UI proves:

- Student login;
- Homework section/detail;
- all nine safe Question surfaces;
- first Attempt Start;
- all eight non-file saves;
- fake-extension content rejected by backend;
- valid file upload;
- file replacement;
- protected Open/Save As;
- persisted Resume;
- Attempt #1 explicit Submit;
- Attempt #2 zero-answer Submit;
- Attempt #3 explicit Submit;
- remaining becomes zero;
- terminal screens are read-only;
- no score/checking shown.

---

# 110. Integration Acceptance Criteria — Backend Persistence

PASS requires oracle proves:

- official pair locks on first Attempt only;
- pair lock equals Attempt #1 start;
- three normal Attempts only;
- typed answer normalized persistence;
- exact written text;
- partial Matching/Ordering/Fill persistence;
- file same-ID replacement;
- private blob integrity;
- explicit Submit timestamps/reason;
- zero-answer Attempt has no fabricated answers;
- no scoring/checking;
- idempotency records correct;
- no Attempt #4.

---

# 111. Integration Acceptance Criteria — Lifecycle

PASS requires:

- baseline lifecycle preconditions proven before the first trigger;
- the specific Deadline Read does not consume other lifecycle fixtures;
- Due Teacher Close proves deadline precedence before scheduler execution;
- Future Teacher Close proves task-close behavior before scheduler execution;
- the scheduler executes only after its exact expected global candidate set is proven;
- any unexpected global scheduler candidate causes a fail-closed stop;
- Main UI cannot prematurely consume lifecycle evidence;
- request-path deadline finalization exact;
- scheduler deadline finalization exact/idempotent;
- Teacher close before deadline uses `task_closed_auto_finalize`;
- Teacher close after deadline preserves deadline reason/time;
- saved answers preserved;
- never-started recipients get no Attempt.

---

# 112. Integration Acceptance Criteria — Security

PASS requires:

- unauthenticated denied;
- wrong role denied;
- same-Institution unassigned denied;
- cross-Institution denied;
- direct Attempt/File ownership protected;
- Teacher Student-submission download denied in Stage 7;
- historical frozen assignment remains readable;
- correct-answer fields absent recursively;
- foreign nested IDs cannot widen scope;
- protected download headers/bytes valid.

Any Tenant/privacy leak:

```text
P1 / integration FAIL
```

---

# 113. Integration Acceptance Criteria — Idempotency

PASS requires real API proves:

- Start same-key replay returns same logical Attempt;
- Start different key with current in-progress resumes same Attempt;
- same UUID can scope independently to Start vs Submit operation;
- Submit same-key replay is successful and timestamp-stable;
- different new Submit key after terminal is rejected;
- rejected operations leave no completed/incomplete success record;
- answer semantic no-op does not rewrite timestamp.

---

# 114. Integration Acceptance Criteria — Restart / Mobile

PASS requires:

- backend restart preserves DB state;
- private saved replacement file remains downloadable after restart;
- Android manual Student flow passes;
- Android partial answer Submit is valid;
- mobile terminal state is read-only;
- Android manual-smoke DB oracle passes.

---

# 115. Integration Acceptance Criteria — Harness Reliability

PASS requires:

- ChatGPT Harness Preflight passed before first full runner;
- stable selectors;
- scoped assertions;
- bounded condition waits;
- no arbitrary sleeps as synchronization;
- hit-testability checks where needed;
- deterministic fixtures;
- deterministic idempotency/file queues;
- fixture DB oracle scoped to manifest, with only the read-only global scheduler candidate guard exception in Section 83;
- cleanup verified;
- no test-only production branches.

---

# 116. Expected Files

## Create

```text
backend/database/seeders/Stage7E2eSeeder.php
backend/tests/Feature/Seeders/Stage7E2eSeederTest.php

frontend/integration_test/stage7_runtime_guard.ps1
frontend/integration_test/verify_stage7_runtime_guard.ps1

frontend/integration_test/stage7_test_files.ps1
frontend/integration_test/verify_stage7_test_files.ps1

frontend/integration_test/stage7_oracle.ps1
frontend/integration_test/verify_stage7_oracle.ps1

frontend/integration_test/stage7_api_security.ps1
frontend/integration_test/verify_stage7_api_security.ps1

frontend/integration_test/stage7_e2e_support.dart
frontend/integration_test/stage7_student_homework_flow_test.dart

frontend/integration_test/run_stage7_windows_e2e.ps1
frontend/integration_test/prepare_stage7_manual_smoke.ps1
```

A separate cleanup PS1 is not required if the guarded Seeder cleanup method + runner safe wrapper cleanly own final cleanup.

## Modify

Only immediately relevant shared integration helper/test assets if strictly required.

Do not modify Stage 2–6 assets merely to generalize/refactor them.

---

# 117. Integration Asset Completion Report

After Codex implements only integration assets, return:

```text
IMPLEMENTATION COMPLETE
```

or:

```text
BLOCKED
```

with:

1. created/modified integration files;
2. focused Seeder test result;
3. PowerShell verifier results;
4. Dart targeted format/analyze result;
5. `git diff --check`;
6. explicit production-code unchanged confirmation;
7. stable selector/wait strategy summary;
8. runtime/private-volume guard summary;
9. deterministic fixture/file summary;
10. cleanup strategy summary;
11. deviations/blockers;
12. final `git status --short`.

Do not claim Integration PASS.

Do not run the full Stage 7 Windows E2E as Codex task-level verification.

Do not commit/push/create PR unless explicitly assigned later.

---

# 118. Final Integration Review Record

After:

- harness delivery;
- Harness Preflight;
- Windows runner;
- direct API/security;
- DB oracle;
- restart;
- Android manual smoke;
- final cleanup;

ChatGPT records:

```text
S07-INT-001

Audited origin/main:
<sha>

Backend Phase 2:
PASS

Frontend Phase 2:
PASS

Integration Harness Preflight:
PASS / FAIL

Windows real-stack runner:
PASS / FAIL

Main Student UI flow:
PASS / FAIL

Nine Question types:
PASS / FAIL

File upload/replacement/download:
PASS / FAIL

Official pair lock:
PASS / FAIL

Three-attempt policy:
PASS / FAIL

Start idempotency:
PASS / FAIL

Answer persistence/no-op:
PASS / FAIL

Submit idempotency:
PASS / FAIL

Deadline read reconciliation:
PASS / FAIL

Scheduler reconciliation:
PASS / FAIL

Teacher close auto-finalization:
PASS / FAIL

Deadline-vs-close precedence:
PASS / FAIL

Tenant/security/privacy:
PASS / FAIL

DB oracle:
PASS / FAIL

Backend restart persistence:
PASS / FAIL

Android manual smoke:
PASS / FAIL

Final cleanup:
PASS / FAIL

Findings:
P1 = <n>
P2 = <n>
P3 = <n>

Verdict:
PASS / NOT ACCEPTED

Next permitted gate:
Stage 7 Closure Review only if PASS
```

---

# 119. Final Rule

Stage 7 integration is complete only when the real production frontend/backend/database/private-storage stack proves the intended Student Homework behavior **and** independent API/DB evidence proves that the UI did not merely look correct.

No Stage 7 Closure Review may begin until:

```text
S07-INT-001 = PASS
```
