# Codex Integration Contract: S08-INT-001 — Stage 8 Real-Stack Blitz Integration

## 1. Metadata and Execution Gate

| Field | Value |
|---|---|
| Task ID | `S08-INT-001` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Area | `Integration / real-stack E2E / security / persistence` |
| Status | `Approved — execution gated by both Phase 2 PASS + owner integration approval` |
| Depends on | `S08-BE-PHASE-2 = PASS`; `S08-FE-PHASE-2 = PASS` |
| Owner integration gate | `Required: valid /approve integration receipt at OWNER_INTEGRATION_APPROVAL_REQUIRED` |
| Planning baseline | `origin/main @ 962ef5d02a7b2e379c401a2083106abbdf42bb1c` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` immediately before Codex integration-asset implementation |
| Harness implementation | `Codex — integration/test assets only` |
| Integration Harness Preflight | `ChatGPT — mandatory after harness delivery and before first full real-stack runner` |
| Windows real-stack automated execution | `Project Owner / approved CI` |
| Android real-stack manual smoke | `Project Owner` |
| Final integration review/verdict | `ChatGPT` |
| Production changes allowed in this task | `No` |
| Next gate after final PASS | `OWNER_CLOSURE_APPROVAL_REQUIRED` → owner `/approve closure` → valid receipt → `STAGE_08_CLOSURE_REVIEW` |

This task becomes eligible for the owner integration gate only after:

```text
S08-BE-PHASE-2 = PASS
S08-FE-PHASE-2 = PASS
```

At that point the Stage must stop at:

```text
OWNER_INTEGRATION_APPROVAL_REQUIRED
```

The repository owner must send:

```text
/approve integration
```

at that exact stopped state.

The Stage Orchestrator must validate the original owner comment and matching
bot-created receipt before this contract is handed to Codex.

A cached INDEX/issue-body flag or an early owner command is not approval.

The complete accepted Stage 8 implementation must also be present on current
`origin/main`.

Before Codex begins integration-asset implementation, ChatGPT/orchestration must:

1. confirm both Phase 2 PASS records remain valid;
2. confirm the Orchestrator has a valid current integration-approval receipt;
3. re-check current `origin/main`;
4. freeze the implementation SHA;
5. confirm Git preflight is safe.

Codex must not inspect Stage history, the task index, the control issue, owner
comments or approval receipts to rediscover this authorization. Receiving this
contract for implementation means orchestration already confirmed the gate.

If `origin/main` advances afterward, stop and report the new SHA.

ChatGPT decides whether the change is evidence-safe bookkeeping or requires
contract revalidation.

Do **not** create a duplicate `CODEX-PROMPT`.

---

# 2. Integration Workflow

The Stage 8 integration sequence is fixed:

```text
Backend Phase 2 PASS
+
Frontend Phase 2 PASS
->
OWNER_INTEGRATION_APPROVAL_REQUIRED
->
repository owner: /approve integration
->
valid integration approval receipt
->
freeze current main
->
Codex implements only missing Stage 8 integration assets
->
Codex runs focused asset tests/verifiers
->
Project Owner delivers integration assets to origin/main
->
ChatGPT Integration Harness Preflight
->
Preflight PASS
->
Project Owner runs full Windows real-stack Stage 8 runner
->
direct API/security verification
->
DB/private-file oracle verification
->
backend restart persistence/idempotency verification
->
Android Teacher + Student real-stack manual smoke
->
final cleanup verification
->
ChatGPT final integration read-only review
->
PASS | NOT ACCEPTED

if PASS:
->
OWNER_CLOSURE_APPROVAL_REQUIRED
->
repository owner: /approve closure
->
valid closure approval receipt
->
ChatGPT Stage Closure Review may begin
```

Do not execute the first full Stage 8 real-stack runner before:

```text
Integration Harness Preflight = PASS
```

---

# 3. Integration Principle

This task verifies **already-delivered production behavior**.

It may create or modify only integration/test assets.

It must not repair production code.

If execution reveals:

## Production defect

1. preserve exact evidence;
2. stop the affected scenario;
3. report:
   ```text
   production defect
   ```
4. ChatGPT creates a focused production-fix contract;
5. Codex implements only that fix;
6. Project Owner delivers it;
7. ChatGPT determines which Backend/Frontend Phase 2 and integration evidence is
   invalidated;
8. rerun only the materially affected evidence.

## Integration-harness defect

Fix only the relevant integration asset under a focused integration-fix contract.

## Runtime/environment defect

Fix only runtime/environment.

Never silently cross these boundaries.

---

# 4. Goal

Prove the complete Stage 8 Blitz vertical through the real stack:

```text
Flutter Windows
-> production GoRouter
-> production Riverpod controllers
-> production repositories / DTOs
-> production configured Dio
-> Laravel / Sanctum
-> PostgreSQL testlabuz_testing
-> private Student submission storage
```

and independently verify:

- Teacher Blitz read/authoring integration;
- Schedule is preparation only;
- official Blitz designation;
- locked partial result-pair fill;
- official cohort preservation;
- synchronized activation;
- individual activation behavior;
- activation durable idempotency;
- Student pre-Start Question secrecy;
- Student active Blitz discovery;
- normal Attempt #1 Start/Resume;
- synchronized common deadline;
- individual full-duration deadline;
- server-authoritative countdown;
- all eight non-file answer mutations;
- file upload/replacement/protected own download;
- explicit Submit with unanswered Questions;
- Submit durable idempotency;
- timeout finalization;
- Teacher Close finalization;
- timeout-vs-Close precedence;
- Teacher monitoring;
- Student-specific additional-attempt grant;
- exception durable idempotency;
- original Attempt #1 retained and official-score-ineligible;
- replacement Attempt #2 only;
- full replacement duration in both timer modes;
- synchronized common end unchanged by replacement;
- no Attempt #3;
- Scheduler timeout reconciliation;
- no Stage 8 scoring/checking/results;
- Tenant/ownership/privacy boundaries;
- persistence after backend restart;
- Teacher mobile Activate/basic monitoring;
- Student mobile Blitz execution smoke.

---

# 5. Explicit Non-Goals

Do not implement or verify as Stage 8 product functionality:

- Stage 9 answer checking;
- Teacher manual answer review;
- awarded points;
- normalized Attempt score;
- official Homework/Blitz score selection;
- Topic result calculation;
- score/result release;
- Parent result display;
- AI/fuzzy checking;
- Teacher Student-submission file review/download;
- exception revoke/edit;
- more than one exception;
- Attempt #3;
- automatic activation at schedule time;
- production test-only routes;
- auth bypass;
- database mutation HTTP API;
- hidden session injection;
- a new E2E framework;
- a new Docker repository configuration;
- broad Backend/Frontend Phase 2 reruns merely because integration starts.

---

# 6. Codex Read Boundary

Codex may read only:

1. this integration contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. `frontend/AGENTS.md`;
5. final Stage 8 production source/tests/config directly required to implement
   integration assets;
6. current reusable integration source assets explicitly listed below.

Codex must not read:

- product docs;
- roadmap;
- architecture/database/API docs;
- Stage indexes;
- previous task contracts;
- previous Phase 2 review files;
- closure reviews

to rediscover requirements.

This contract defines the Stage 8 integration behavior.

---

# 7. Approved Reusable Integration Source Primitives

Codex may inspect current Stage 7 **integration source assets** as implementation
patterns:

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

Reuse the proven patterns for:

- fail-closed runtime identity;
- dedicated restartable backend container;
- private named-volume verification;
- manifest-owned fixture cleanup;
- deterministic test files;
- real configured Dio;
- injected native file-picker/local-file boundaries only;
- API security probes;
- DB/private-file oracle;
- backend restart;
- Android smoke preparation.

Do not copy Stage 7 blindly.

Do not modify Stage 7 assets merely to make Stage 8 work unless a truly generic
helper already exists and a narrow compatible extension is explicitly justified.

Prefer Stage 8-namespaced assets.

---

# 8. Production Boundaries the E2E Must Exercise

Actual Windows E2E must use production:

```text
GoRouter
AuthSessionController
TeacherSessionKey
StudentSessionKey

Teacher Blitz repositories/data sources/DTOs/controllers
Teacher result-pair repository/controller
Teacher Blitz lifecycle controller
Teacher monitoring controller
Teacher attempt-exception controller

Student Blitz repositories/data sources/DTOs/controllers
Student Start/Resume
Student completed Start replay mechanism
Student answer/file controllers
Student Submit controller

IdempotencyKeyGenerator
StudentSubmissionFilePicker provider boundary
ProtectedLearningMaterialTransfer
LocalFileActions

configured Dio
Laravel Sanctum middleware
real PostgreSQL
real private filesystem disk
```

E2E may override only approved native/non-deterministic boundaries:

```text
idempotencyKeyGeneratorProvider
studentSubmissionFilePickerProvider
localFileActionsProvider
existing API base target boundary
```

Do not override:

```text
repositories
remote data sources
Dio
auth controllers
Teacher/Student Blitz controllers
monitoring controller
answer/file/Submit controllers
```

in real-stack E2E.

---

# 9. Integration Asset Delivery Boundary

Codex may create/modify only:

```text
backend/database/seeders/**
backend/tests/Feature/Seeders/**

frontend/integration_test/**
```

plus one existing integration-only helper outside those paths only if directly
required and justified.

Do not modify:

```text
backend/app/**
backend/routes/**
backend/database/migrations/**
frontend/lib/**
frontend/pubspec.yaml
frontend/pubspec.lock
platform production files
docs/**
tasks/**
```

If real integration cannot be built without a production change:

```text
BLOCKED
```

Report the exact production gap.

---

# 10. Dedicated Stage 8 Runtime

Use a dedicated restartable Stage 8 backend container:

```text
container:
testlabuz-stage8-e2e-app

container app port:
8000/tcp

API:
http://127.0.0.1:<ApiPort>/api/v1

WorkingDir:
/var/www/html

AutoRemove:
false
```

Laravel:

```text
APP_ENV=testing
APP_DEBUG=false
DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=testlabuz_testing
```

## Integration-only concurrent HTTP runtime

For Stage 8 real concurrency evidence, start the dedicated Linux container with:

```text
PHP_CLI_SERVER_WORKERS=4
```

and keep the existing server command:

```text
php artisan serve --host=0.0.0.0 --port=8000
```

This worker setting is integration-runtime configuration only.

Do not modify the repository's production Docker files merely to enable this
Stage 8 test runtime.

The worker count is only a prerequisite. It does **not** by itself prove that
the race requests overlapped inside the backend. Section 14.1 defines the
mandatory dynamic PostgreSQL proof.

Current planning runtime dependency:

```text
PostgreSQL container: testlabuz-postgres-1
PostgreSQL image: postgres:18.4
Docker network: testlabuz_default
```

If the final accepted runtime infrastructure legitimately changes before
execution, stop and ask ChatGPT to revalidate this identity.

Backend source:

```text
current repository backend
-> /var/www/html
read/write bind
```

Do not change repository Docker configuration.

---

# 11. Stage 8 Private File Runtime

Use dedicated named volume:

```text
testlabuz-stage8-e2e-private-files
```

mounted:

```text
/var/www/html/storage/app/private
read/write
```

Guard must prove:

- exact Stage 8 named volume;
- one owning private-root mount;
- read/write;
- not mounted to public storage;
- no alias exposing same volume through another app path;
- configured private disk resolves below the private root;
- configured disk is not public.

Never map private volume to:

```text
storage/app/public
public/
```

or any web-served location.

---

# 12. Stage 8 Runtime Guard Assets

Create:

```text
frontend/integration_test/stage8_runtime_guard.ps1
frontend/integration_test/verify_stage8_runtime_guard.ps1
```

The guard fails closed unless all runtime identities are proven.

---

# 13. Runtime Guard Requirements

Verify exactly:

## Backend container

```text
name = testlabuz-stage8-e2e-app
running
AutoRemove = false
WorkingDir = /var/www/html
```

Exactly one read/write source bind:

```text
current repo backend -> /var/www/html
```

## API target

Only:

```text
http://127.0.0.1:<ApiPort>/api/v1
```

Reject:

```text
https
localhost
IPv6
wildcard host
userinfo
query
fragment
trailing slash
alternate API path/version
missing port
wrong published port
```

Container port `8000/tcp` must publish exactly once to:

```text
127.0.0.1:<ApiPort>
```

## Laravel identity

Inside real container:

```text
environment = testing
debug = false
database.default = pgsql
PDO driver = pgsql
current_database() = testlabuz_testing
```

No current migration pending.

## Concurrent-worker prerequisite

Without dumping the full Docker environment, require exactly:

```text
PHP_CLI_SERVER_WORKERS=4
```

and a Unix/Linux container runtime capable of PHP CLI server worker forking.

The guard may inspect only the named worker environment value and narrowly
required `/proc` facts.

The static worker check is necessary but is not authoritative concurrency
evidence. Section 14.1 dynamic lock-wait evidence is authoritative.

## PostgreSQL identity

Require:

```text
testlabuz-postgres-1
running
postgres:18.4
testlabuz_default network
DB_HOST=postgres
```

## Private disk

Require approved private root/visibility and Stage 8 named volume.

## HTTP boundary

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

Never print secrets.

---

# 14. Runtime Guard Negative Verifier

`verify_stage8_runtime_guard.ps1` must exercise pure guard functions and approved
actual runtime.

Reject at minimum:

```text
bad/non-loopback URL
localhost/IPv6/wildcard
query/fragment/trailing slash
wrong path/port

wrong/stopped/missing backend container
AutoRemove=true
wrong WorkingDir
missing/read-only/wrong source bind
ambiguous bind
wildcard/duplicate port publish

wrong APP_ENV/debug
wrong DB driver/name/host
pending migration
missing/wrong `PHP_CLI_SERVER_WORKERS`
non-Unix/non-fork-capable concurrency runtime

wrong/stopped PostgreSQL
wrong image/network

missing/wrong/read-only private volume
private volume mounted public
private volume alias/duplicate mount

wrong unauthenticated /auth/me boundary
```

Do not print:

```text
DB password
APP_KEY
bearer token
full Docker environment
raw inspect JSON containing secrets
```

---

# 14.1 Mandatory Real Backend Overlap / Lock-Contention Proof

A client-side start barrier is not sufficient concurrency evidence.

For every Stage-level race that claims real backend concurrency, the harness must
prove that **two distinct real HTTP requests are simultaneously inside the
PostgreSQL lock path**.

## 14.1.1 Probe sessions

Use:

```text
one harness blocker PostgreSQL session
one independent observer PostgreSQL session
application PostgreSQL sessions created by real HTTP workers
```

The blocker/observer are integration-harness sessions only.

They do not change production code.

The blocker starts:

```sql
BEGIN;

SELECT id
FROM assessment_attempts
WHERE id = :manifest_attempt_id
FOR UPDATE;
```

and keeps that transaction open.

The target Attempt must be:

```text
Stage 8 manifest-owned
the same Attempt used by the real race
comfortably before its authoritative deadline
```

The blocker must not update the row.

## 14.1.2 Launch real HTTP requests

After the blocker owns the Attempt lock, launch race requests A and B through
two independent real HTTP client processes.

Both requests must traverse:

```text
real HTTP
-> Laravel auth/route
-> production Action/support
-> PostgreSQL Attempt lock acquisition
```

Do not release the blocker yet.

No repository mock.

No fake controller.

No production sleep/debug/test hook.

## 14.1.3 Observer evidence

From the observer connection, poll bounded facts from:

```text
pg_stat_activity
pg_locks
pg_blocking_pids(...)
```

Scope application sessions by:

```text
database = testlabuz_testing
client_addr = exact Docker-network IPv4 of testlabuz-stage8-e2e-app
```

Require one observer sample proving:

```text
at least 2 distinct application PostgreSQL PIDs
state = active
wait_event_type = Lock
both present simultaneously
both blocked in the manifest Attempt lock queue
blocking chain rooted in the harness blocker transaction
```

Do not count:

```text
observer PID
blocker PID
unrelated application/database session
same PID twice
```

A bounded evidence object may be equivalent to:

```json
{
  "overlap_observed": true,
  "waiting_application_pids": [101, 102],
  "waiting_count": 2,
  "wait_event_type": "Lock",
  "manifest_attempt_id": "<uuid>",
  "blocker_pid": 77
}
```

Do not use elapsed time alone as proof.

Do not print unrelated full SQL text or secrets.

## 14.1.4 Release and finish

Only after:

```text
overlap_observed = true
waiting_count >= 2
waiting_application_pids are distinct
```

may the harness commit/rollback the blocker transaction.

Then both HTTP requests finish naturally and the normal business-state oracle
determines which valid serialization occurred.

The harness does not force a winner.

## 14.1.5 Bounded failure

If the observer does not prove two simultaneous application lock waiters within
the approved bounded window:

```text
CONCURRENCY EVIDENCE = INCOMPLETE
```

The race is **not PASS** even if its final state happens to match one legal
sequential branch.

Always release/rollback the blocker in a `finally` path.

## 14.1.6 Deadline safety

At probe start, require enough authoritative remaining time that the entire
maximum overlap-probe window plus a safety margin cannot reach the Attempt
deadline.

Minimum remaining margin after accounting for the configured maximum probe
window:

```text
60 seconds
```

If that cannot be proven, use another fixture.

## 14.1.7 Per-race proof

Run this proof separately for:

```text
47A.7 typed answer PUT vs Submit
47A.8 file replacement vs Submit
```

One successful overlap probe cannot certify both races.

---

# 15. Flutter Toolchain Guard

Stage 8 Windows runner parameters:

```powershell
param(
  [Parameter(Mandatory = $true)][string] $FlutterExecutable,
  [Parameter(Mandatory = $true)][ValidateRange(1,65535)][int] $ApiPort
)
```

Compare:

```text
$FlutterExecutable --version --machine
```

against current:

```text
frontend/.fvmrc
```

Do not modify `.fvmrc`.

---

# 16. Stage 8 Seeder

Create:

```text
backend/database/seeders/Stage8E2eSeeder.php
backend/tests/Feature/Seeders/Stage8E2eSeederTest.php
```

Seeder properties:

```text
deterministic structure
repeatable
fail-closed
manifest-owned
Tenant-safe
FK-safe
safe cleanup
```

---

# 17. Seeder Fail-Closed Guard

Before any DB/private-file mutation require:

```text
app environment = testing
database driver = pgsql
current_database() = testlabuz_testing
STAGE8_E2E_PASSWORD exists
STAGE8_E2E_PASSWORD non-blank
```

If any fails:

```text
throw
write nothing
```

Never print password.

## 17.1 Actual-runtime prior-run cleanup boundary

The Windows runner must clean any previous **manifest-owned** Stage 8 state
before the focused seeder test runs.

This cleanup executes inside the already-validated dedicated Stage 8 app
container and must use the application's **actual currently configured private
file disk**, which resolves into:

```text
testlabuz-stage8-e2e-private-files
-> /var/www/html/storage/app/private
```

for the dedicated Stage 8 runtime.

Do **not** override `filesystems.private_files_disk` to an isolated test disk for
this prior-run cleanup.

Invoke:

```text
Stage8E2eSeeder::cleanupOwnedState()
```

or an exact responsibility-equivalent entry point on the same integration
seeder.

Normal environment/database/password guards plus manifest/file ownership guards
remain authoritative.

If a manifest candidate `files` row has an unexpected storage disk/key,
public/out-of-namespace path or non-manifest owner, cleanup must fail closed
before deleting that unsafe object/state.

Capture bounded unrelated DB/private-file sentinel facts before cleanup and
prove they are unchanged afterward.

## 17.2 Focused seeder-test disk remains isolated

`Stage8E2eSeederTest` may temporarily use a dedicated test-only private disk/root,
following the established Stage 7 test pattern.

Mandatory order:

```text
validate real Stage 8 runtime/private volume
-> cleanup prior real manifest using real configured private disk
-> verify real manifest cleanup
-> run Stage8E2eSeederTest on isolated test disk
-> seed fresh real Stage 8 fixtures on real configured private disk
-> capture baseline
```

This prevents a leftover real `File` row from being interpreted under the
transactional test's different isolated storage disk.

---

# 18. Reserved Stage 8 Namespace

Use:

```text
UUID prefix:
08000000-...

login prefix:
e2e_s08_

display/title prefix:
E2E S08

password env:
STAGE8_E2E_PASSWORD
```

Every owned row/file must be in an explicit manifest.

Do not delete unrelated rows simply because visible text has an `E2E` prefix.

---

# 19. Fixture Actors

Create deterministic actors sufficient for all scenarios.

At minimum:

```text
Institution A
  Teacher A
  Student A1
  Student A2
  Student A3

Institution B
  Teacher B
  Student B1

Institution C
  Teacher C
  Student C1
```

Institution C exists only for isolated configuration-negative integration
coverage such as `blitz_timer_start_mode = null`; it must not share mutable
Stage 8 execution aggregates with Institution A.

Requirements:

- active accounts;
- correct roles;
- current Teacher/Student group membership where scenario requires;
- separate Tenant B for cross-Tenant probes.

Use deterministic credentials through:

```text
STAGE8_E2E_PASSWORD
```

Do not hardcode password in repository.

---

# 20. Required Topic / Pair Fixture Families

Create isolated Topic families so one scenario cannot invalidate another.

At minimum:

## A. Builder smoke Topic

```text
active Topic
Teacher A group
no Stage 8 execution history
```

Used for Teacher Create/Edit/Question/Schedule/Archive UI smoke.

## B. Official locked-partial Topic

```text
active Topic
official Homework already designated
official cohort already established/locked
blitz_assessment_id = null
```

Used to prove:

```text
locked partial pair can receive official Blitz
activation reuses frozen cohort
```

## C. Synchronized execution Topic

Prepared whole-group Draft/Scheduled Blitz with safe Questions.

## D. Individual execution Topic

Prepared Blitz isolated from synchronized scenario.

## E. Timeout / Scheduler Topic

Short-duration deterministic Blitz fixtures.

## F. Tenant B privacy Topic

Foreign Tenant resources for direct-ID probes.

## G. Selected-Student practice Topic

Institution A isolated Topic with:

```text
one valid official Homework already present in the Topic pair
candidate Blitz assignment_mode = selected_students
candidate Blitz status = draft|scheduled
persisted Direct recipients = deterministic selected subset
no Blitz Attempt history
```

Used to prove both:

```text
selected-Student Blitz cannot become official
selected-Student Blitz can still activate/run as practice
```

The official-designation rejection must not mutate the result pair.

## H. Blitz-first official cohort / Homework compatibility Topic

Institution A isolated Topic with:

```text
official Homework designated, preactivation, zero recipients/Attempts
official whole-group Blitz designated, preactivation, zero recipients/Attempts
pair.cohort_snapshotted_at = null
pair.locked_at = null
```

Used to prove, in one ordered real-API scenario:

```text
official Blitz activation establishes the first common cohort
Blitz Student Start is the first official Student activity and locks the pair
Homework activation later reuses the Blitz-established cohort despite the Blitz-origin lock
first Homework Start then succeeds and does not rewrite the historical pair lock
```

## I. Missing timer-setting activation Topic

Institution C isolated Topic/Blitz with:

```text
blitz_timer_start_mode = null
eligible Draft/Scheduled Blitz
valid Questions/points/assignment
```

Used only for the exact failed activation/rollback proof.

## J. Late-write / finalization-race Topics

Create separate short-duration or independently terminalizable Blitz aggregates
for:

```text
late typed-answer replacement
late file-answer replacement
typed-answer write vs explicit Submit race
file-answer replacement vs explicit Submit race
```

Each probe owns a distinct Attempt so one terminalization cannot invalidate the
next probe.

Do not reuse one mutable aggregate for every scenario.

## 20.1 Mandatory F13 Coverage Map

These are required integration scenarios, not optional examples.

| Stage-level requirement | Fixture | Required execution evidence | Required persistence/oracle evidence |
|---|---|---|---|
| selected-Student practice + official prohibition | G | result-pair PUT rejects candidate; separate practice Activate succeeds | pair unchanged by failed designation; direct recipients preserved; only selected Students receive practice access |
| first activation establishes official cohort | H | official Blitz activates first | pair cohort timestamp is established once; Blitz recipient set becomes authoritative cohort; no Homework recipients fabricated at Blitz activation |
| Blitz-first → Homework compatibility | H | Blitz Start first; then Homework Activate; then Homework Start | Blitz-origin pair lock preserved; Homework cohort equals Blitz cohort; first Homework Attempt #1 exists; pair lock/identity unchanged |
| unset timer mode blocks activation | I | Activate returns exact settings conflict | no activation/timer snapshot/recipients/cohort/idempotency success |
| late typed write | J | direct PUT at/after deadline returns exact timing conflict | only canonical timeout finalization may change; prior answer state unchanged |
| late file write | J | direct multipart PUT at/after deadline returns exact timing conflict | prior file graph/blob unchanged; rejected staged blob compensated; only canonical timeout finalization may change |
| finalization/write concurrency | J | real typed-write-vs-Submit and file-write-vs-Submit races | exactly one legal serialization per race; no write commits after Submit freeze; file loser leaves no staged blob |

The final integration evidence must identify the concrete manifest IDs and PASS
evidence for every row.

Do not claim an INDEX-required scenario is covered merely because a backend unit
test exists.

---

# 21. Frozen Official Cohort Fixture

For locked-partial official pair, create a historical official Homework cohort:

```text
Student A1
Student A2
```

Then deliberately change current Group membership so:

```text
Student A3 currently in Group but NOT in frozen official cohort
```

or remove one current membership while keeping persisted cohort, as safe fixture
design permits.

Integration must prove the later official Blitz activation uses the persisted
official cohort, not current membership.

Expected official Blitz recipient set:

```text
exactly frozen cohort
```

No A3 merely because currently in Group.

---

# 22. Question Fixture Coverage

The primary Student execution fixture must contain all nine safe Question types:

```text
single_choice
multiple_choice
true_false
short_written
open_written
file_based
matching
ordering
fill_in_blank
```

Use deterministic IDs/text/points.

Ensure Student-safe resource contains no correct-answer data.

At least one separate Builder smoke scenario must exercise real Teacher Question
mutation through Flutter UI, but the full nine-type authoring matrix need not be
rebuilt manually in E2E because focused frontend/backend tests already cover it.

---

# 23. Test File Assets

Create:

```text
frontend/integration_test/stage8_test_files.ps1
frontend/integration_test/verify_stage8_test_files.ps1
```

Generate deterministic valid:

```text
PDF
DOCX
PPTX
```

as needed.

At least one file uploaded through Student Blitz UI must be server-valid.

Optionally include one deliberately invalid file/signature for direct API
security/content-validation proof if current Stage 7 helper pattern supports it.

Never commit real user documents.

---

# 24. Stage 8 DB / Private-File Oracle

Create:

```text
frontend/integration_test/stage8_oracle.ps1
frontend/integration_test/verify_stage8_oracle.ps1
```

The ordinary oracle must query only manifest-owned Stage 8 fixture IDs plus
explicitly declared unrelated sentinels.

One narrow exception is mandatory:

```text
global Scheduler candidate-safety scan
```

defined in Section 44.

That scan is **read-only** and may inspect the minimum global Blitz/Attempt
columns required to prove that `blitz:reconcile-timeouts` cannot mutate
non-manifest data.

It must not:

- update/delete unrelated rows;
- clean unrelated candidates to make the test pass;
- expose unrelated Student/user content;
- read answer/file payloads;
- become a general whole-database oracle.

If the global safety scan finds non-manifest mutable Scheduler state, stop before
the command and report an environment/runtime isolation failure.

---

# 25. Oracle Must Verify Blitz Lifecycle

For relevant fixture Blitz rows assert exact:

```text
status
duration_seconds
scheduled_at
timer_start_mode_snapshot
activated_at
synchronized_ends_at
closed_at
archived_at
```

Synchronized:

```text
common end = activated_at + duration
```

Individual:

```text
common end = null
```

No device/client timestamp source.

---

# 26. Oracle Must Verify Official Pair / Cohort

Assert:

```text
topic_result_pairs.homework_assessment_id unchanged
blitz_assessment_id exact
locked_at preserved/valid
cohort snapshot identity preserved
```

Assert official Blitz recipients equal frozen official cohort.

Assert current Group membership changes did not redefine the cohort.

For fixture H also assert the **newly established** cohort path:

```text
before Blitz activation:
  cohort_snapshotted_at = null
  locked_at = null
  Homework recipients = empty
  Blitz recipients = empty

after official Blitz activation:
  cohort_snapshotted_at = Blitz activated_at
  locked_at = null
  Blitz recipients = exact eligible whole-group set
  Homework recipients = empty
  pair identities/designation history preserved
```

After Blitz Start first:

```text
pair.locked_at = Blitz Attempt #1.started_at
pair has real official Blitz activity
Homework Attempts = empty
```

After later Homework activation and first Homework Start:

```text
Homework recipients = exact established Blitz cohort
Homework Attempt #1 exists
pair.locked_at unchanged from Blitz first activity
pair.updated_at not churned by later Homework Start
homework_assessment_id / blitz_assessment_id / cohort_snapshotted_at unchanged
```

No exception/Submit/monitoring flow changes pair identity.

---

# 27. Oracle Must Verify Attempt #1

For normal Attempt:

```text
attempt_number = 1
```

Validate:

- ownership;
- recipient;
- `official_score_eligible` initial true;
- start/deadline semantics;
- terminal reason/timestamps where applicable;
- only persisted answers exist;
- no fabricated rows for unanswered Questions.

For fixture H cross-side first activity additionally assert:

```text
Blitz Attempt #1 does not consume Homework Attempt capacity
first later Homework Start creates Homework Attempt #1
Homework public three-normal-Attempt policy remains independent
```

---

# 28. Oracle Must Verify Replacement Exception

After Teacher grant:

```text
one blitz_attempt_exceptions row
invalidated_attempt_id = Attempt #1
replacement_attempt_id initially null
reason_type exact
reason exact
granted_by_user_id exact
granted_at non-null
```

Attempt #1:

```text
official_score_eligible = false
```

No #2 created by grant.

Pair/class timer unchanged.

---

# 29. Oracle Must Verify Attempt #2

After Student starts replacement:

```text
attempt_number = 2
official_score_eligible = true
exception.replacement_attempt_id = Attempt #2
```

Require:

```text
deadline_at = started_at + duration_seconds
```

for both:

```text
synchronized
individual
```

For synchronized replacement:

```text
blitz.synchronized_ends_at unchanged
Attempt #2 deadline may be later than common end
```

No Attempt #3.

---

# 30. Oracle Must Verify Terminal State

Explicit Submit:

```text
status = submitted
reason = student_submit
submitted_at = finalized_at = locked_at
finalized_at < deadline_at
```

Timeout:

```text
status = timed_out_finalized
reason = timeout_auto_submit
submitted_at = null
finalized_at = locked_at = exact deadline_at
```

Teacher close before deadline:

```text
status = submitted
reason = task_closed_auto_finalize
submitted_at = null
finalized_at = locked_at = close instant
```

At/equal/after deadline:

```text
timeout wins
```

Terminal reason/timestamps do not churn after repeated reconciliation.

---

# 31. Oracle Must Verify No Stage 9 Scoring

For Stage 8 attempts/answers assert:

```text
earned_points is null
normalized_score is null
scoring_completed_at is null
answer checking state remains pending where applicable
awarded points/review fields remain null
```

Do not require Stage 9 tables to exist/populate.

No official score/result created by Stage 8.

---

# 32. Oracle Must Verify Files

For Student file answer:

- private File row belongs to correct Institution/Attempt/Question;
- private storage key is under approved private root;
- no corresponding public storage file;
- replacement behavior preserves stable File ID where contract requires;
- current file bytes exist before restart;
- same bytes/file remain available after restart;
- cleanup removes only manifest-owned private blobs.

Never print storage secrets or file content unnecessarily.

---

# 33. Oracle Must Verify Idempotency Records

Inspect manifest-owned high-risk operations:

```text
teacher.blitz.activate
student.blitz.attempt.start
student.blitz.attempt.submit
teacher.blitz.attempt_exception.grant
```

Verify completed record:

```text
Institution/User ownership
operation
normalized key
result resource type/id
response status
```

Do not log tokens/passwords.

Verify failed/late operations do not leave incomplete committed claims where the
production contract forbids them.

---

# 34. API Security Assets

Create:

```text
frontend/integration_test/stage8_api_security.ps1
frontend/integration_test/verify_stage8_api_security.ps1
```

Reuse Stage 7 safe transport/error-envelope conventions.

No bearer token may be printed.

---

# 34.1 Authoritative Negative-Probe Oracle

The Stage 8 integration harness must not accept merely "an error occurred".

For every negative API probe in Sections 35–39 and 42–43, assert:

```text
actor / Institution scope
HTTP method + exact route
request body/query/header variant
exact HTTP status
exact machine code
error-envelope class
allowed persistence mutation
required unchanged state
idempotency-record outcome when relevant
private-file byte outcome when relevant
```

Codex must implement these expectations from this contract. It must not choose a
different acceptable status/code by inspecting whichever production branch
happens to run.

## 34.1.1 Common error envelope

Every JSON API error in this matrix must have exactly the normal API error
surface:

```json
{
  "message": "<non-blank safe string>",
  "code": "<exact machine code below>",
  "errors": {}
}
```

An optional already-standard request-tracing field may be accepted only if the
delivered common API error layer already emits it globally; no Stage 8-specific
extra error fields are allowed.

For non-validation errors in this matrix:

```text
errors = empty object
```

For:

```text
422 validation_failed
```

require:

```text
errors = non-empty object
every error value = non-empty array of non-blank strings
only fields belonging to the deliberately invalid request vector may appear
```

Do not assert human message copy beyond non-blank/privacy-safe content. Machine
code and status are authoritative.

## 34.1.2 Authentication / role matrix

| Probe | Expected | Persistence / bytes |
|---|---|---|
| Unauthenticated protected Stage 8 request | `401 authentication_required` | zero domain mutation; no idempotency claim; protected download returns no file bytes |
| Authenticated wrong role calling a Teacher/Student Stage 8 operation | `403 forbidden` | zero domain mutation; no idempotency claim |
| Teacher directly requesting a Student-submission File ID | `404 resource_not_found` | zero DB mutation; zero file bytes returned |

The Student-submission protected-file denial deliberately uses privacy-safe
`404`, not generic wrong-role `403`.

## 34.1.3 Tenant / ownership / assignment matrix

| Probe | Expected | Persistence / bytes |
|---|---|---|
| Institution A actor targets Institution B Blitz/Attempt/Student | `404 resource_not_found` | zero domain mutation; no idempotency claim |
| Institution A Student targets Institution B Student-submission File | `404 resource_not_found` | zero DB mutation; zero file bytes |
| Student A3, not in frozen official recipient cohort, directly reads/starts that official Blitz | `404 resource_not_found` | zero Attempt creation; zero pair change; zero Start idempotency success |
| Another Student mutates A1 answer | `404 resource_not_found` | A1 Attempt/answers/files unchanged |
| Another Student submits A1 Attempt | `404 resource_not_found` | Attempt unchanged; no Submit idempotency claim |
| Another Student downloads A1 Student-submission File | `404 resource_not_found` | zero DB mutation; zero file bytes |

Malformed direct resource UUIDs in these privacy-scoped resource paths are also:

```text
404 resource_not_found
```

when the route reaches the resource-resolution boundary.

## 34.1.4 Strict request-validation matrix

These are request-shape failures and therefore must be exactly:

```text
422 validation_failed
```

with zero domain mutation and zero successful/incomplete idempotency claim:

| Invalid request vector |
|---|
| missing required `Idempotency-Key` |
| malformed required `Idempotency-Key` |
| forbidden query parameter |
| non-empty body on an empty-body-only command |
| Student Blitz Start missing body or `{}` |
| Student Blitz Start unknown `intent` |
| Student Blitz Start unknown JSON body key |
| Student Blitz Resume missing `attempt_id` |
| Student Blitz `start_normal` with forbidden `attempt_id` |
| Student Blitz `start_replacement` with forbidden `attempt_id` |
| Student Blitz Resume malformed/non-canonical `attempt_id` |
| unknown JSON body key on other strict commands |
| null/malformed result-pair `blitz_assessment_id` |
| invalid exception `reason_type` |
| blank exception `reason` |

Do not accept `404` or `409` for these deliberately malformed request shapes.

A separate well-formed request may of course later fail a business/resource
predicate with the exact business/privacy code defined elsewhere in this matrix.

## 34.1.4A Student Start intent/idempotency matrix

All probes use:

```text
POST /student/blitz/{blitz}/attempts
operation = student.blitz.attempt.start
```

| Probe | Exact body | Expected | Persistence / idempotency |
|---|---|---|---|
| Fresh normal Start with no #1 | `{"intent":"start_normal"}` | `201` | exactly one #1; no #2; completed Start claim records #1 |
| New normal Start key while #1 is in progress | `{"intent":"start_normal"}` | `200` | same #1; no timer reset; no #2 |
| Same completed normal key + same body | identical `start_normal` body | original logical `200/201` | same #1; zero timing/history churn |
| Exact Resume of own in-progress #1/#2 | `{"intent":"resume","attempt_id":"<exact-own-id>"}` | `200` | no creation; exact target only; timestamps unchanged |
| Same completed Resume key + same body/attempt_id | identical Resume body | original logical `200` | same exact Attempt; zero timing/history churn |
| Stale Resume target is own terminal Attempt | well-formed Resume body | `409 attempt_not_editable` for a new key | zero new Attempt; zero switch |
| Resume target is due in-progress | well-formed Resume body | `409 blitz_time_expired` | only canonical timeout reconciliation may commit; zero new Attempt |
| Foreign/other-Student/other-Blitz Resume target | exact Resume body | `404 resource_not_found` | zero mutation; zero successful Start claim |
| Fresh valid replacement Start | `{"intent":"start_replacement"}` | `201` | exactly one #2 linked to exception; no #3 |
| New replacement Start key while valid #2 is in progress | replacement body | `200` | same #2; zero timer reset |
| Same completed replacement key + same body | identical replacement body | original logical `200/201` | same #2; zero history churn |
| `start_normal` after terminal #1 when replacement capacity exists | `{"intent":"start_normal"}` | `409 attempts_exhausted` | zero #2 creation |
| Stale `resume` after exception/replacement capacity appears | exact original Resume body | `409 attempt_not_editable` or `409 blitz_time_expired` according to exact target | zero switch; zero #2 creation |
| Same key reused with different intent | changed body | `409 idempotency_key_reused` | zero domain mutation |
| Same Resume key reused with different `attempt_id` | changed Resume target | `409 idempotency_key_reused` | zero domain mutation |

For non-validation negative rows require:

```text
errors = {}
```

and assert Attempt history is unchanged except where canonical timeout
reconciliation is explicitly allowed.

The harness must prove `intent` and Resume `attempt_id` are semantic request
identity and must never reconstruct them from current server state.

## 34.1.5 Submit terminal/idempotency matrix

| Probe | Expected | Allowed persistence outcome |
|---|---|---|
| Same completed Submit key + same Attempt/fingerprint | `200` success | zero Submit transition/timestamp/reason churn; same logical Attempt |
| Same Submit key reused for different Attempt/fingerprint | `409 idempotency_key_reused` | target Attempt unchanged; no new claim/result |
| New Submit key against `timed_out_finalized + timeout_auto_submit` | `409 blitz_time_expired` | existing timeout history unchanged; no successful/incomplete Submit claim |
| New Submit key against any other valid terminal Attempt (`student_submit`, Teacher-close terminal, forward-compatible waiting/checked) | `409 attempt_not_editable` | terminal status/reason/timestamps/answers/files unchanged; no successful/incomplete Submit claim |
| Late request that itself discovers an `in_progress` Attempt is due | `409 blitz_time_expired` | **only** canonical timeout reconciliation may commit; requested explicit Submit does not commit and no Submit claim remains |

The last row is intentionally not "zero writes": deadline reconciliation is the
one allowed authoritative mutation and must persist only the canonical timeout
fields owned by the timeout engine.

## 34.1.6 Exception-grant idempotency matrix

| Probe | Expected | Allowed persistence outcome |
|---|---|---|
| Same completed grant key + same Student/Blitz/reason fingerprint | `201` success | same exception; zero duplicate grant; no second eligibility mutation; no Attempt #2 creation merely from replay |
| Same grant key + changed reason/Student/Blitz fingerprint | `409 idempotency_key_reused` | existing exception/#1 eligibility unchanged; no new claim/result |
| Different new key after exception already exists | `409 blitz_attempt_exception_already_granted` | exactly one existing exception remains; original reason/timestamp unchanged; #1 eligibility not toggled again; no Attempt #2; no successful/incomplete new grant claim |

## 34.1.7 Persistence comparison rule

For every negative probe, take a bounded pre-request snapshot of the
manifest-owned rows/files that the request could mutate and compare it after the
response.

Unless an individual row above explicitly permits timeout reconciliation:

```text
before == after
```

for all relevant:

```text
Blitz lifecycle/timing rows
topic_result_pairs
assessment_students
assessment_attempts
attempt_answers / typed child rows
answer_files / files
blitz_attempt_exceptions
idempotency_records
manifest-owned private blobs
```

Do not use whole-database equality where another deliberate scenario may be
running. Compare the exact manifest-owned aggregate/probe target.

---

# 35. API Security — Authentication / Role

Use the Section 34.1 exact oracle.

For unauthenticated protected Stage 8 endpoints require:

```text
HTTP 401
code = authentication_required
errors = {}
zero domain mutation
```

For an authenticated actor with the wrong role on Teacher/Student Stage 8
operations require:

```text
HTTP 403
code = forbidden
errors = {}
zero domain mutation
```

At minimum probe:

```text
Teacher Blitz detail/activate/monitor/grant
Student Blitz detail/start
Student answer PUT
Student Submit
protected file download
```

Protected Student-submission download has the narrower privacy rule:

```text
Teacher direct Student-submission File ID
-> HTTP 404
-> code = resource_not_found
-> errors = {}
-> zero file bytes
```

Do not weaken that probe to `403 forbidden`.

---

# 36. API Security — Tenant Isolation

Using Institution B actors/resources verify Institution A cannot:

```text
read foreign Blitz
activate foreign Blitz
monitor foreign Blitz
grant exception to foreign Student/Blitz
start foreign Student Blitz
write foreign Attempt answer
submit foreign Attempt
download foreign Student file
```

Every cross-Tenant direct resource probe above must return exactly:

```text
HTTP 404
code = resource_not_found
errors = {}
```

Required:

```text
zero domain mutation
zero successful/incomplete idempotency claim
zero protected-file bytes when the target is a file
```

No existence leak.

Do not accept `403`, generic `409`, or any successful empty response as an
alternative.

---

# 37. API Security — Assignment / Ownership

Verify Student A3 not in frozen official cohort cannot directly:

```text
GET official locked-cohort Blitz detail
POST Start for that Blitz
```

even if A3 currently belongs to Group.

Both must return exactly:

```text
HTTP 404
code = resource_not_found
errors = {}
```

and create:

```text
zero Attempt rows
zero Start idempotency success
zero pair/cohort mutation
```

Verify Student A1/A2 can according to persisted assignment.

For another Student targeting A1's owned resources require exactly:

```text
answer mutation -> 404 resource_not_found
Submit          -> 404 resource_not_found
file download   -> 404 resource_not_found
```

with A1's persisted Attempt/answers/file graph unchanged and no protected file
bytes returned.

Teacher direct download of an A1 Student-submission File must also be exactly:

```text
404 resource_not_found
```

Teacher ownership of the Blitz does not grant Stage 8 Student-submission access.

---

# 38. API Security — Pre-Start Question Privacy

Direct:

```text
GET /student/blitz/{blitz}
```

before Start must contain no:

```text
questions
answers
correct-answer fields
```

Strictly assert keys.

Then Start with the exact normal-Start contract:

```http
POST /student/blitz/{blitz}/attempts
Idempotency-Key: <fresh-uuid>
Content-Type: application/json
```

```json
{"intent":"start_normal"}
```

Require:

```text
HTTP 201 for a fixture with no prior #1
same Blitz/Student
Attempt #1 only
Questions present
safe Student Question projection only
```

No answer key.

This is a required P1 oracle.

---

# 39. API Security — Strict Transport

Probe each malformed/unsupported request separately:

```text
bad Idempotency-Key where required
missing Idempotency-Key where required
query parameters where forbidden
non-empty body where empty-only
unknown JSON keys
null result-pair Blitz ID
malformed result-pair Blitz ID
invalid exception reason type
blank exception reason
```

Every one of these deliberately malformed request-shape probes must return
exactly:

```text
HTTP 422
code = validation_failed
errors = non-empty validation object
```

and must produce:

```text
zero domain mutation
zero completed idempotency result
zero committed incomplete idempotency claim
```

The validator helper must reject an unexpected `404` or `409` for these exact
malformed vectors.

Do not print raw SQL/internal errors.

Do not conflate this section with a separate well-formed request that fails
privacy/lifecycle/business validation after request parsing.

---

# 40. Durable Idempotency — Activation

Direct API fixture:

1. send Activate with key K;
2. record returned Blitz;
3. replay same K/body/route;
4. require same logical result;
5. no second activation timestamp;
6. reuse K with different route/fingerprint;
7. require:
   ```text
   409 idempotency_key_reused
   ```

After later lifecycle progression/restart, same completed key must remain
historically replayable as defined by production contract.

---

# 41. Durable Idempotency — Student Start

Use Section 34.1.4A as the exact oracle.

## Normal #1

1. send K1 with:
   ```json
   {"intent":"start_normal"}
   ```
2. record Attempt #1 and original response status;
3. replay K1 with the **identical body**;
4. require same Attempt/start/deadline and original logical status;
5. require no #2 and no timestamp churn.

After #1 becomes terminal and an exception is granted:

```text
replay old K1 + original start_normal body
-> original #1 logical result
-> never #2
```

## Exact Resume

Use KR:

```json
{"intent":"resume","attempt_id":"<exact-attempt-id>"}
```

Valid target:

```text
200
same exact Attempt
same started_at/deadline_at
no creation
```

Replay KR with the exact same body/key.

Fingerprint mismatch probes:

```text
KR + different attempt_id
-> 409 idempotency_key_reused

KR + start_normal body
-> 409 idempotency_key_reused

KR + start_replacement body
-> 409 idempotency_key_reused
```

For a new Resume key targeting an own terminal Attempt:

```text
409 attempt_not_editable
```

For a new Resume key whose exact target is due:

```text
409 blitz_time_expired
```

Only canonical timeout reconciliation may mutate persistence.

No Resume may switch to another Attempt or create replacement #2.

## Replacement #2

Use fresh K2:

```json
{"intent":"start_replacement"}
```

Valid unused exception + no #2:

```text
201
exactly one #2
```

Replay K2 with identical body/key -> same #2.

A completed normal/Resume key reused with replacement body must be:

```text
409 idempotency_key_reused
```

This is a critical Stage 8 invariant.

---

# 42. Durable Idempotency — Submit

Use Section 34.1.5 as the exact oracle.

1. Submit current Attempt with key KS:
   ```text
   HTTP 200
   ```
2. replay the same KS/same Attempt fingerprint:
   ```text
   HTTP 200
   same logical Attempt
   zero submitted_at/finalized_at/locked_at/reason churn
   ```
3. reuse KS against a different Attempt/fingerprint:
   ```text
   HTTP 409
   code = idempotency_key_reused
   errors = {}
   zero mutation on the second Attempt
   ```
4. create/use a **new** Submit key against timeout-finalized Attempt:
   ```text
   HTTP 409
   code = blitz_time_expired
   errors = {}
   ```
   Require the existing timeout terminal fields unchanged and no successful or
   incomplete Submit idempotency claim for the new key.
5. create/use a **new** Submit key against another valid terminal Attempt,
   including:
   ```text
   submitted + student_submit
   submitted + task_closed_auto_finalize
   waiting_for_teacher_review
   checked
   ```
   Require:
   ```text
   HTTP 409
   code = attempt_not_editable
   errors = {}
   ```
   with terminal state/timestamps/reason/answers/files unchanged and no
   successful/incomplete Submit claim.

For a late request that reaches the backend while the Attempt is still persisted
`in_progress` but the authoritative deadline has arrived:

```text
HTTP 409
code = blitz_time_expired
```

The only permitted persistence change is canonical timeout reconciliation:

```text
status = timed_out_finalized
reason = timeout_auto_submit
submitted_at = null
finalized_at = locked_at = exact deadline_at
```

The explicit Submit transition itself must not commit and no Submit idempotency
claim may remain.

Do not accept a generic "terminal conflict".

---

# 43. Durable Idempotency — Exception Grant

Use Section 34.1.6 as the exact oracle.

1. grant exception with key KG:
   ```text
   HTTP 201
   ```
2. replay KG with the exact same Student/Blitz/reason fingerprint:
   ```text
   HTTP 201
   same exception ID
   ```
   Require zero duplicate exception, zero repeated #1 eligibility mutation and
   no Attempt #2 merely from replay.
3. reuse KG with different reason, Student or Blitz fingerprint:
   ```text
   HTTP 409
   code = idempotency_key_reused
   errors = {}
   ```
   Existing exception, #1 eligibility and Attempt history remain unchanged.
4. use a **different new key** after the exception already exists:
   ```text
   HTTP 409
   code = blitz_attempt_exception_already_granted
   errors = {}
   ```
   Require:
   ```text
   exactly one exception row remains
   original reason unchanged
   original granted_at unchanged
   #1 official_score_eligible remains false without second toggle/churn
   no Attempt #2 created
   no successful/incomplete idempotency claim for the rejected new key
   ```
5. no Attempt #2 is created merely by grant.

Do not accept a generic "already-granted conflict".

---

# 44. Scheduler Verification — Global Candidate Ownership Guard

`blitz:reconcile-timeouts` is a **global** command against the shared
`testlabuz_testing` database.

The dedicated Stage 8 app container/private volume does not isolate PostgreSQL
rows.

Therefore the command must never be invoked directly by the runner.

Create one guarded integration helper equivalent to:

```text
Get-Stage8SchedulerSafetyFacts
Assert-Stage8SchedulerSafeToRun
Invoke-Stage8GuardedScheduler
```

or exact responsibility-equivalent names.

Every real invocation of:

```bash
php artisan blitz:reconcile-timeouts
```

must flow through that helper.

## 44.1 Exact production candidate predicate

The pre-command read-only candidate query must mirror the accepted BE-007
production scanner exactly.

Capture one database-server:

```text
guardScanNow
```

and scan distinct:

```text
institution_id
assessment_id
```

where:

```text
blitz_tasks.status = active

AND EXISTS assessment_attempts:
  same institution_id
  same assessment_id
  status = in_progress
  deadline_at <= guardScanNow
```

Do not substitute:

- `synchronized_ends_at`;
- Blitz `activated_at + duration`;
- client/device time;
- scheduler command output;
- a manifest-only query.

The guard query itself must discover **all** current global candidates first and
then prove ownership.

## 44.2 Exact candidate ownership

For every discovered candidate pair require:

```text
(institution_id, assessment_id)
```

to equal an exact Stage 8 manifest-owned Blitz pair.

A candidate with:

```text
assessment_id not in Stage 8 manifest
OR
institution_id != manifest owner of that assessment
```

must cause:

```text
STOP BEFORE COMMAND
environment/runtime isolation failure
```

Do not delete, close, finalize, reschedule, or otherwise "fix" the unrelated
candidate.

## 44.3 TOCTOU safety superset

A current-candidate-only check has a time gap before the global Artisan command.

To prevent a non-manifest Attempt from becoming due inside that gap, the same
read-only guard must also scan the safety superset:

```text
blitz_tasks.status = active
AND assessment_attempts.status = in_progress
AND assessment_attempts.deadline_at IS NOT NULL
```

with the same Institution/Assessment relationship.

Every row/aggregate in this safety superset must also be Stage 8 manifest-owned.

This is intentionally stricter than the production candidate predicate.

If any non-manifest active in-progress Blitz Attempt exists, even if its deadline
is still future:

```text
STOP BEFORE COMMAND
```

This fail-closed integration restriction is allowed because safety of unrelated
shared-test data is more important than forcing the global command to run.

Do not clean unrelated rows to satisfy the guard.

## 44.4 Expected first invocation

Fixture design must ensure that immediately before the first Scheduler command:

```text
global exact candidate set
=
exactly one manifest Scheduler Blitz aggregate
```

and that this aggregate contains:

```text
at least one due in_progress Attempt
at least one manifest future in_progress Attempt
```

whose future deadline is deliberately far enough beyond the two-command
Scheduler proof that it cannot become due during that proof.

The guard must assert the exact manifest Scheduler assessment/institution pair,
not merely "all candidates are ours."

Only after this assertion passes may it invoke:

```bash
php artisan blitz:reconcile-timeouts
```

inside the Stage 8 app container.

After the command verify:

- command exit success;
- output `Candidates` equals the expected guarded candidate count;
- due manifest Attempt finalized at exact persisted deadline;
- future manifest Attempt remains `in_progress`;
- replacement #2 uses its own deadline;
- synchronized common end does not prematurely timeout #2;
- Blitz remains Active unless another explicit scenario changed it;
- no unrelated sentinel changed.

## 44.5 Expected second invocation

Immediately before the second real command:

1. rerun the **same global exact candidate scan**;
2. rerun the **same global TOCTOU safety-superset ownership scan**;
3. require:
   ```text
   exact candidate set = empty
   ```
4. only then invoke the command again.

After the second command require:

```text
Candidates = 0
finalized attempts = 0
failures = 0
```

and:

- zero terminal timestamp/reason churn;
- future manifest Attempt still in-progress;
- no unrelated sentinel change.

Do not reuse the first guard result for the second invocation.

## 44.6 Unrelated-state before/after evidence

Before each guarded command capture the bounded read-only state of explicitly
declared unrelated sentinel rows.

After each command compare them exactly.

At minimum include unrelated sentinels whose row families could expose an unsafe
global scheduler side effect:

```text
Blitz task
Assessment
AssessmentAttempt
Topic/result-pair identity where present
```

The sentinel need not itself be an active in-progress candidate; in fact Section
44.3 forbids a non-manifest active in-progress Blitz Attempt at command time.

The global ownership scans prevent an unrelated candidate from being touched;
the sentinel comparison additionally proves the command did not mutate declared
unrelated state unexpectedly.

## 44.7 Negative guard verifier

`verify_stage8_oracle.ps1` must test the guard with synthetic facts.

At minimum prove the guard rejects **before any command callback/invoker can be
called**:

1. one current candidate with non-manifest `assessment_id`;
2. one candidate with manifest assessment ID but wrong Institution;
3. zero current candidates but one non-manifest future active/in-progress Attempt
   in the TOCTOU safety superset;
4. first invocation with an extra manifest candidate beyond the one exact
   Scheduler fixture;
5. second invocation with any candidate remaining.

The verifier must also prove a valid first-invocation fact set and a valid
second-invocation empty-candidate fact set are accepted.

## 44.8 Production-predicate preflight

During Integration Harness Preflight, ChatGPT must compare the delivered
`Get-Stage8SchedulerSafetyFacts` candidate predicate with the actual delivered
production `ReconcileDueBlitzTimeouts` scanner.

If production implementation materially differs from the accepted predicate in
this contract:

```text
Preflight = NOT ACCEPTED
```

Do not improvise a different integration expectation.

## 44.9 Failure isolation remains production behavior

The global command may still have BE-007 candidate-level failure isolation for
manifest-owned candidates.

Do not create a corrupt **non-manifest** real DB candidate merely to test failure
isolation.

A safe manifest-owned corrupt-candidate scenario may be used only if it cannot
escape manifest cleanup and does not weaken Sections 44.1–44.8.

Do not auto-close Blitz.

---

# 45. Short-Duration Timeout Fixture

Use an isolated fixture with short positive duration suitable for real integration
without long sleeps.

Recommended:

```text
3–8 seconds
```

The exact duration must be long enough for deterministic request setup on the
target machine.

Runner may wait until:

```text
server-side deadline has definitely passed
```

using bounded polling/sleep.

Do not modify production clock.

Do not depend on device clock for correctness.

Oracle checks exact persisted deadline finalization.

---

# 46. Synchronized Replacement After Common End

Create an isolated synchronized scenario proving the narrow exception rule:

1. activate synchronized Blitz;
2. normal Attempt #1 exists and becomes terminal;
3. wait until class common end is past;
4. Blitz remains Active;
5. Teacher grants exception;
6. Student sends a fresh key with exact body:
   ```json
   {"intent":"start_replacement"}
   ```
7. require `201` and creation of Attempt #2 despite common end being past;
8. #2 deadline:
   ```text
   #2.started_at + duration
   ```
9. common `synchronized_ends_at` unchanged;
10. #2 can accept answer before its own deadline;
11. no #3.

This must be verified by API + DB oracle even if Windows UI flow starts #2
before common end.

---

# 47. Individual Timing Scenario

Use isolated Institution/Blitz whose activation snapshot is:

```text
individual
```

Verify:

- pre-Start Student detail effective deadline/remaining null;
- Start #1 is sent with:
  ```json
  {"intent":"start_normal"}
  ```
  and receives:
  ```text
  deadline = started + duration
  ```
- another Student starting later receives its own full duration;
- class common end is null;
- replacement #2 also receives full duration from own start.

The UI or direct API may cover this, but DB oracle must prove timestamps.

---

# 47A. Mandatory Direct API / DB Scenarios for Stage-Level Coverage

These scenarios are intentionally direct real-API/DB integration coverage.
They do not require a separate full Flutter UI run.

## 47A.1 Selected-Student Practice and Official-Designation Denial

Using fixture G:

1. snapshot the current Topic result pair;
2. attempt:
   ```text
   PUT /teacher/topics/{topic}/result-pair
   ```
   with the current official Homework ID and the selected-Student Blitz ID;
3. require exactly:
   ```text
   HTTP 409
   code = official_task_requires_group_assignment
   errors = {}
   ```
4. oracle proves the pair is byte/field-equivalent for all authoritative pair
   identity/history fields and no recipient/Attempt/idempotency side effect was
   created by the failed designation;
5. activate the same Blitz as **practice** with a fresh activation key;
6. require `200` and current Direct recipient set preserved exactly;
7. require no official pair/cohort mutation from practice activation;
8. selected recipient Student can read/start according to normal practice rules;
9. a non-recipient Student receives privacy-safe:
   ```text
   404 resource_not_found
   ```
   and no Attempt is created.

This proves "not official" does not mean "cannot be used as valid practice."

## 47A.2 First Official Cohort Established by Blitz Activation

Using fixture H, start with:

```text
pair has official Homework + official Blitz
cohort_snapshotted_at = null
locked_at = null
zero official recipients
zero official Attempts
```

Then:

1. activate the official Blitz;
2. require `200`;
3. DB oracle proves:
   ```text
   pair.cohort_snapshotted_at = blitz.activated_at
   Blitz recipients = exact current eligible whole-group Student set
   Homework recipients = empty
   pair.locked_at = null
   ```
4. activation itself creates no Student Attempt.

This is a different proof from the locked-partial/frozen-cohort scenario: here
the Stage 8 Blitz activation is the operation that establishes the common cohort.

## 47A.3 Blitz-First Student Activity → Homework Activation → Homework Start

Continue fixture H.

1. Student A1 starts official Blitz Attempt #1:
   ```http
   POST /student/blitz/{blitz}/attempts
   Idempotency-Key: <manifest key>
   Content-Type: application/json
   ```
   ```json
   {"intent":"start_normal"}
   ```
2. require `201`;
3. oracle proves:
   ```text
   pair.locked_at = Blitz Attempt.started_at
   Homework Attempts = 0
   ```
4. Teacher activates the already-designated official Homework through:
   ```text
   POST /teacher/homework/{homework}/activate
   ```
5. require successful normal Homework activation;
6. oracle proves Homework recipients equal the established Blitz cohort exactly,
   with no pair identity/cohort/lock rewrite;
7. Student A1 then calls the delivered canonical Homework Start:
   ```text
   POST /student/homework/{homework}/attempts
   Idempotency-Key: <fresh Homework key>
   ```
8. require:
   ```text
   HTTP 201
   Homework Attempt #1
   ```
9. oracle proves:
   ```text
   pair.locked_at unchanged from the earlier Blitz Start
   pair.updated_at unchanged by this later Homework Start
   Blitz Attempt history unchanged
   Homework Attempt number = 1
   ```

A `409 business_conflict` merely because the Homework had zero prior Attempts is
a production defect.

## 47A.4 Activation Blocked When Institution Timer Mode Is Unset

Using fixture I:

1. prove before request:
   ```text
   institution_settings.blitz_timer_start_mode = null
   Blitz = draft|scheduled
   activated_at = null
   timer_start_mode_snapshot = null
   no activation recipients
   ```
2. send Activate with a fresh key;
3. require exactly:
   ```text
   HTTP 409
   code = institution_settings_incomplete
   errors = {}
   meta.missing_fields = ["blitz_timer_start_mode"]
   ```
4. after request require complete rollback/no activation:
   ```text
   Blitz lifecycle/timer fields unchanged
   no assessment_students activation snapshot created
   no pair cohort mutation
   no Student Attempt
   no completed or incomplete activation idempotency record for that key
   ```

Do not substitute a generic `business_conflict`.

## 47A.5 Direct Late Typed-Answer Write

Using an isolated fixture J Attempt:

1. while pre-deadline, persist one known typed answer value;
2. wait until the server-side persisted `deadline_at` has definitely passed
   without first invoking another reconciliation path;
3. snapshot Attempt + exact target answer state;
4. send a direct typed-answer replacement PUT;
5. require:
   ```text
   HTTP 409
   code = blitz_time_expired
   errors = {}
   ```
6. allow exactly one persistence change family:
   ```text
   Attempt -> timed_out_finalized
   finalization_reason = timeout_auto_submit
   submitted_at = null
   finalized_at = locked_at = exact deadline_at
   ```
7. require the previous answer row/value/checking fields unchanged;
8. require no new/extra answer row.

The late PUT must never become part of the frozen Attempt.

## 47A.6 Direct Late File-Answer Write

Using a different isolated fixture J Attempt:

1. upload and persist deterministic File A before deadline;
2. record File/AnswerFile IDs, metadata and File A blob hash/path ownership;
3. allow authoritative deadline to pass without another reconciliation request;
4. attempt multipart replacement with deterministic File B;
5. require:
   ```text
   HTTP 409
   code = blitz_time_expired
   errors = {}
   ```
6. allow only the same canonical timeout transition on the Attempt;
7. require persisted answer/file graph still references File A;
8. require File A blob still exists unchanged;
9. require no new manifest DB File/AnswerFile row for File B;
10. require no leaked/stale File B private blob after compensation.

A rejected late replacement must not delete or replace the prior current file.

## 47A.7 Real Concurrent Typed Write vs Explicit Submit

Use a fresh in-progress fixture J Attempt comfortably before deadline.

Use the full Section 14.1 overlap protocol for this exact fixture Attempt.

First hold the Attempt row with the harness blocker.

Then launch through two independent real HTTP clients/processes:

```text
A = typed answer PUT
B = POST /student/attempts/{attempt}/submit with fresh Submit key
```

Before blocker release require one PostgreSQL observer sample proving:

```text
2 distinct application DB PIDs
simultaneously waiting with wait_event_type = Lock
same manifest Attempt lock queue
overlap_observed = true
```

If not observed:

```text
47A.7 = INCOMPLETE / NOT PASS
```

Do not use repository mocks or a production test hook.

Only after overlap evidence may the blocker release and both requests complete.

Exactly one of these serialized outcomes is valid:

### Write commits first

```text
A -> 200
B -> 200
final Attempt = submitted + student_submit
frozen answer = newly committed A value
```

### Submit commits first

```text
B -> 200
A -> 409 attempt_not_editable
final Attempt = submitted + student_submit
answer remains the pre-race server value
```

Both branches require:

```text
overlap_observed = true
at least 2 distinct application DB lock-wait PIDs
one terminal Submit transition
no answer write after freeze
no terminal timestamp/reason rewrite
one successful Submit idempotency result
```

## 47A.8 Real Concurrent File Replacement vs Explicit Submit

Use a different fresh in-progress fixture J Attempt with persisted File A.

Use the full Section 14.1 overlap protocol for this separate fixture Attempt.

First hold that Attempt row with the harness blocker.

Then launch:

```text
A = multipart replacement with deterministic File B
B = explicit Submit with fresh Submit key
```

Before blocker release require:

```text
2 distinct application PostgreSQL PIDs
simultaneously waiting with wait_event_type = Lock
same manifest Attempt lock queue
overlap_observed = true
```

If not observed:

```text
47A.8 = INCOMPLETE / NOT PASS
```

Only after overlap evidence may the blocker release and both requests complete.

Valid branches only:

### File replacement commits first

```text
A -> 200
B -> 200
final Attempt = submitted + student_submit
frozen current file = File B
superseded File A cleanup follows the delivered replacement contract
```

### Submit commits first

```text
B -> 200
A -> 409 attempt_not_editable
final Attempt = submitted + student_submit
current persisted file remains File A
staged File B blob compensated
no new current File/AnswerFile identity survives
```

No branch may produce a file mutation committed after terminalization.

The harness need not force which worker wins.

It must prove both:

```text
real backend overlap/lock contention observed before blocker release
+
observed final result matches exactly one complete serialized branch
```

A correct final branch without overlap evidence is not concurrency PASS.

---

# 48. Windows E2E Assets

Create:

```text
frontend/integration_test/stage8_e2e_support.dart
frontend/integration_test/stage8_blitz_flow_test.dart
frontend/integration_test/run_stage8_windows_e2e.ps1
```

The test must use production Flutter layers and real backend.

---

# 49. Windows E2E Main Flow — Teacher Preparation Smoke

Using Builder smoke Topic:

1. login Teacher A through production auth UI;
2. open Topic;
3. verify Blitz section;
4. create Draft Blitz through production Builder;
5. use whole-group assignment;
6. set duration;
7. verify Create result/detail;
8. edit one metadata field;
9. open Question Builder;
10. add at least one Question through real UI;
11. verify server-authoritative points/detail;
12. schedule it;
13. verify Scheduled state and UI copy that scheduling does not auto-activate;
14. archive this isolated practice preparation fixture if its final state permits
    and doing so does not interfere with later execution fixtures.

This proves the Teacher authoring route against the real API.

Do not use this fixture for every timer scenario.

---

# 50. Windows E2E Main Flow — Locked Partial Official Designation

Using locked-partial Topic:

1. Teacher opens prepared whole-group Blitz;
2. result pair already contains official Homework and locked cohort;
3. verify UI still offers:
   ```text
   Set as Official Blitz
   ```
   despite pair lock and null Blitz side;
4. confirm designation;
5. verify Official badge;
6. activate via production UI;
7. verify Active resource/timer snapshot;
8. DB oracle proves:
   - Homework ID unchanged;
   - locked cohort preserved;
   - Blitz recipients equal frozen cohort.

This is a required cross-Stage 6/8 integration proof.

---

# 51. Windows E2E Main Flow — Pre-Start Student Privacy

Login Student A1.

Before Start:

1. Active Blitz appears in Student workspace;
2. open Blitz;
3. verify instructions/timing;
4. assert no Question prompt/Question widget visible;
5. no Start occurred merely by opening/reloading detail.

Then explicitly Start.

Questions may appear only after Start response.

---

# 52. Windows E2E Main Flow — Student Execution

For main synchronized Attempt #1:

1. Start through production UI;
2. verify Attempt 1;
3. verify visible server-anchored countdown;
4. answer several non-file types through production editors;
5. leave at least one Question unanswered;
6. upload one real valid file through production file picker override;
7. verify current uploaded file;
8. optionally Open/Save As through production protected transfer and injected
   local native sink;
9. Submit with unanswered Question(s);
10. confirmation must allow Submit;
11. verify terminal:
    ```text
    Submitted
    ```
12. verify no score/checking/result.

DB oracle verifies exact persisted answers/file/terminal metadata.

---

# 53. Windows E2E Main Flow — Monitoring and Exception

Teacher A returns to Active Blitz monitoring:

1. open Monitor;
2. verify Student A1 finalized;
3. verify no score/answers shown;
4. open desktop:
   ```text
   Grant additional attempt
   ```
5. choose:
   ```text
   technical
   ```
6. enter deterministic reason;
7. grant;
8. monitoring refresh must show:
   ```text
   Additional attempt granted
   current operational path not started
   ```
9. no Attempt #2 exists yet according to DB oracle.

---

# 54. Windows E2E Main Flow — Replacement #2

Student A1:

1. refresh/open Active Blitz;
2. see:
   ```text
   Start additional attempt
   ```
3. confirm;
4. Start #2;
5. verify:
   ```text
   Additional attempt
   ```
6. countdown begins from returned full configured duration;
7. save at least one answer;
8. optionally leave/resume once to prove explicit Resume reload;
9. terminalize by Submit or controlled close according to fixture plan.

Oracle proves:

```text
#1 official_score_eligible=false
#2 official_score_eligible=true
exception links #1 -> #2
no #3
```

---

# 55. Windows E2E — Question/Answer Coverage

The primary fixture contains all nine Question types.

The Windows main path must exercise enough real UI controls to prove integration
of:

```text
choice
written
complex structured answer
file
```

At minimum save through UI:

```text
single_choice
multiple_choice
true_false
short_written
open_written
matching
ordering
fill_in_blank
file_based
```

when practical and stable within the runner.

If real-stack UI runtime becomes prohibitively long, all nine may be split
across isolated Windows scenarios in the same integration test file, but each
must still hit production UI/controllers/repository/Dio.

Do not replace them with mocked repository tests.

---

# 56. Windows E2E — Countdown Proof

Do not assert exact second-by-second equality vulnerable to process scheduling.

Prove:

- synchronized pre-Start countdown is visible and decreases;
- individual pre-Start has no effective countdown;
- active Attempt countdown decreases;
- ordinary Widget rebuild/navigation state does not reset remaining time;
- leaving/resuming does not reset deadline;
- replacement uses its own full-duration countdown.

DB/API oracle remains exact timing authority.

---

# 57. Windows E2E — Timeout UI

Use isolated short-duration Student fixture:

1. Start Attempt;
2. allow authoritative deadline to pass;
3. verify frontend reaches local non-editable reconciliation;
4. real backend detail/replay resolves:
   ```text
   Time expired
   ```
5. saved-before-deadline answer remains;
6. unsaved local draft is not claimed persisted;
7. no automatic Submit.

DB oracle verifies exact deadline finalization.

---

# 58. Windows E2E — Teacher Mobile Scope Is Not Tested on Windows

Do not emulate mobile by merely shrinking Windows viewport as final evidence.

Widget tests already cover responsive routing.

Actual mobile runtime verification is the Android manual smoke defined later.

Windows may still use narrow viewport as supplementary evidence only.

---

# 59. API / DB Teacher Close Scenario

Use isolated active Blitz with mixed Attempt deadlines.

Prove:

- future in-progress Attempt:
  ```text
  task_closed_auto_finalize
  ```
- already-due Attempt:
  ```text
  timeout_auto_submit
  ```
- exact terminal timestamps/reasons;
- no terminal rewrite;
- no fabricated never-started Attempt.

Do not rely solely on UI Close.

Use direct API + oracle for exact mixed timing semantics.

---

# 60. Monitoring API Scenario

Direct API monitoring must prove:

```text
assigned count exact
status partition exact
exception count exact
due Attempt reconciled before response
score = null
no Questions/answers/files
```

Also prove:

- unused exception projects current `not_started`;
- replacement #2 becomes current when started;
- inactive historical recipient remains in assignment roster where fixture
  supports that state.

---

# 61. Monitoring Frontend Polling Evidence

Windows E2E should prove at least:

- initial monitoring load;
- one automatic refresh after server-side Student state change;
- no user action needed for the row to update;
- page remains usable;
- no score/answer content.

Exact 5-second/non-overlap/background behavior remains primarily Phase 2 unit/
widget evidence; integration confirms real repeated GET path works.

Do not add instrumentation-only production hooks.

---

# 62. Direct API Pre-Start / Start Contract

## 62.1 Pre-Start privacy

Assert:

```text
GET /student/blitz/{blitz}
before Start:
no Questions
no answers
no correct-answer/checking configuration
```

## 62.2 Exact request matrix

All requests use:

```text
POST /student/blitz/{blitz}/attempts
Idempotency-Key required
no query
```

Normal Start:

```json
{"intent":"start_normal"}
```

Fresh no-#1 fixture:

```text
201
Attempt #1
```

Existing in-progress #1 with a new normal key:

```text
200
same #1
```

Resume exact target:

```json
{"intent":"resume","attempt_id":"<exact-own-attempt-uuid>"}
```

Valid exact own in-progress target:

```text
200
same exact Attempt ID
no new Attempt
```

Replacement Start:

```json
{"intent":"start_replacement"}
```

Valid unused exception:

```text
201
Attempt #2
exception.replacement_attempt_id = #2.id
```

Existing valid in-progress #2 with an accepted new replacement key:

```text
200
same #2
```

## 62.3 Timing

Synchronized normal #1:

```text
deadline_at = synchronized_ends_at
```

Individual normal #1:

```text
deadline_at = started_at + duration_seconds
```

Replacement #2 in either timer mode:

```text
deadline_at = replacement_started_at + duration_seconds
```

Replacement never changes synchronized common end.

## 62.4 Stale Resume / no-switch

Arrange state change before the Resume wins the decisive lock.

Required:

```text
exact own target terminal
-> 409 attempt_not_editable

exact own target due
-> 409 blitz_time_expired
   only timeout reconciliation may mutate

foreign/other Student/other Blitz target
-> 404 resource_not_found
```

For every case:

```text
no new Attempt
no switch to another Attempt
no replacement #2
```

Repeat after a valid exception exists and replacement capacity is available.
Stale Resume still cannot switch/create #2.

## 62.5 Body/fingerprint mismatch

With a completed Start key:

```text
same key + different intent
-> 409 idempotency_key_reused

same Resume key + different attempt_id
-> 409 idempotency_key_reused
```

Require:

```text
errors = {}
Attempt history unchanged
exception linkage unchanged
pair/cohort unchanged
no new completed/incomplete claim for mismatched request
```

Malformed body combinations belong to Section 34.1.4 and must be:

```text
422 validation_failed
```

not an idempotency/business error.

## 62.6 Completed immutable request replay

For each originating request:

```text
start_normal
resume #1
resume #2
start_replacement
```

record the exact:

```text
intent
attempt_id when applicable
Idempotency-Key
```

and replay that exact tuple during later reconciliation/restart checks.

The harness must not reconstruct the replay body from current Attempt/detail
state.

Questions are present only after a successful execution request and remain
Student-safe.

---

# 63. Answer Mutation API / Oracle

For each type verify server stores canonical normalized persistence without
scoring.

At least direct API oracle additionally validates:

```text
clearable answer removal
no placeholder rows
no checking/awarded points
```

Windows UI proves Student editor integration.

Direct late-write immutability is mandatory through Section 47A.5; it is not
satisfied only by ordinary pre-deadline answer saves.

---

# 64. File Security / Persistence

Verify:

- valid upload stored private;
- wrong Student cannot download;
- Teacher cannot download Stage 8 Student submission;
- unauthenticated denied;
- public URL/path cannot retrieve it;
- current Student can Open/Save through protected endpoint;
- file persists after app-container restart because private named volume persists;
- Section 47A.6 proves late replacement preserves the prior current file and
  compensates the rejected staged blob;
- Section 47A.8 proves real file-replacement-vs-Submit serialization.

---

# 65. Backend Restart Verification

After meaningful state is established:

```text
Blitz activation
Attempt(s)
answers
file
terminal state
exception
idempotency records
```

restart only the dedicated:

```text
testlabuz-stage8-e2e-app
```

container.

Do not recreate PostgreSQL/private volume.

After restart verify:

- app runtime identity still passes guard;
- DB state unchanged;
- private file still exists/downloads;
- monitoring returns same logical state;
- completed activation replay works;
- completed Start replay works with exact original `intent + attempt_id? + Idempotency-Key`;
- replay never reconstructs/switches Start intent after restart;
- completed Submit replay works where fixture exists;
- completed exception grant replay works;
- no timestamps/reasons churn.

This proves persistence across backend process restart.

---

# 66. Windows Runner

Create:

```text
frontend/integration_test/run_stage8_windows_e2e.ps1
```

Responsibilities:

1. fail closed on parameters;
2. validate Flutter pin;
3. provision/validate dedicated Stage 8 app container;
4. provision/validate Stage 8 private named volume;
5. run runtime guard;
6. run pure integration verifiers;
7. capture unrelated-sentinel facts for prior-run cleanup proof;
8. run `Invoke-Stage8PriorManifestCleanup` against the **actual configured Stage 8 private disk/volume**;
9. verify every prior manifest-owned DB/private-file artifact is absent and unrelated sentinels are unchanged;
10. only now run focused `Stage8E2eSeederTest` on its isolated test-only disk;
11. seed deterministic fixtures into the actual Stage 8 runtime/private volume;
12. run baseline oracle;
13. prepare deterministic test files;
14. run Windows Flutter real-stack test;
15. run API/security scenarios;
16. run the Section 47A Stage-level direct API scenarios, including the two real concurrent races;
17. prepare the Scheduler phase so only the manifest Scheduler aggregate owns any
    active in-progress Blitz Attempts eligible under Section 44 safety rules;
18. run timeout/Scheduler/Close/idempotency scenarios, invoking every global
    `blitz:reconcile-timeouts` only through `Invoke-Stage8GuardedScheduler`;
19. run post-flow DB/private-file oracle;
20. restart backend;
21. rerun runtime guard;
22. run restart persistence/idempotency oracle;
23. cleanup manifest-owned DB/private-file/local fixture state;
24. verify cleanup;
25. preserve only approved evidence logs.

Fail immediately on a failed required phase.

Do not continue and report false aggregate PASS.

## 66.1 `Invoke-Stage8PriorManifestCleanup`

Implement one runner helper/responsibility-equivalent operation before the
focused seeder test.

It must:

1. require runtime guard PASS;
2. require exact Stage 8 container/private-volume identity;
3. invoke Stage 8 seeder cleanup inside that container with
   `STAGE8_E2E_PASSWORD` supplied only to the child process/environment;
4. use the real configured `private_files_disk`;
5. never switch to the isolated seeder-test disk;
6. delete only manifest-owned rows/blobs;
7. preserve unrelated sentinels;
8. be idempotent when no prior Stage 8 state exists;
9. return structured `cleaned=true` confirmation;
10. clear password material afterward.

Conceptual container-side call:

```php
try {
    putenv('STAGE8_E2E_PASSWORD='.$input['password']);
    (new Database\Seeders\Stage8E2eSeeder)->cleanupOwnedState();
    echo json_encode(['cleaned' => true], JSON_THROW_ON_ERROR);
} finally {
    putenv('STAGE8_E2E_PASSWORD');
}
```

The exact safe wrapper may follow the established Stage 7 runner pattern.

Reject:

```text
cleaned != true
```

and independently run the cleanup oracle afterward.

## 66.2 Prior-run cleanup oracle

After cleanup require:

```text
all manifest-owned Stage 8 DB rows absent
all manifest-owned answer_files links absent
all manifest-owned files rows absent
all manifest-owned private blobs absent
all manifest-owned idempotency/token rows absent where applicable
unrelated DB sentinel unchanged
unrelated private-file sentinel unchanged
```

Do not assert the whole testing DB/private volume is empty.

Do not clean by textual prefix alone.

## 66.3 Full-invocation retry semantics

A new `run_stage8_windows_e2e.ps1` invocation must be safe after an earlier run
stopped after creating any subset of:

```text
AssessmentAttempt
AttemptAnswer
AnswerFile
File
private blob
IdempotencyRecord
```

Retry sequence:

```text
runtime guard
-> actual-disk prior-manifest cleanup
-> cleanup oracle
-> focused isolated seeder test
-> fresh real seed
-> baseline oracle
```

It must not require the previous failed invocation to have reached final cleanup.

---

# 67. Runner Environment Variables

Use scoped environment names such as:

```text
STAGE8_E2E_PASSWORD
STAGE8_E2E_API_BASE_URL
STAGE8_E2E_MODE
STAGE8_E2E_FIXTURE_ROOT
STAGE8_E2E_FLUTTER_EXECUTABLE
```

Never commit secrets.

Never print password/token values.

Child process environment must be cleared/restored when feasible after run.

---

# 68. Flutter E2E Launch

Runner invokes current pinned Flutter, conceptually:

```powershell
& $FlutterExecutable test `
  integration_test/stage8_blitz_flow_test.dart `
  -d windows `
  --no-pub `
  "--dart-define=API_BASE_URL=http://127.0.0.1:$ApiPort/api/v1"
```

Use the established repository's proven process-launch/evidence pattern.

Do not add a second Flutter integration framework.

---

# 69. E2E Authentication

Use production login UI/API flow.

Do not inject authenticated session.

The harness may know deterministic Stage 8 fixture login names/password through
environment/config, but production:

```text
AuthSessionController
Dio cookies/tokens
role routing
```

must be exercised.

Never print credentials.

---

# 70. Native Boundary Overrides

Allowed E2E overrides:

## File picker

Returns deterministic local Stage 8 fixture file.

## Local Open / Save As

Capture safe bytes/path outcome without requiring external desktop application.

## Idempotency key generator

May return deterministic canonical UUID sequence to allow oracle assertions.

The requests must still travel through production repositories/Dio/backend.

No repository/controller override.

---

# 71. Deterministic Idempotency Keys

If E2E overrides key generator, use explicit manifest-owned UUIDs under:

```text
08000000-...
```

Sequence must be deterministic and scenario-specific.

Never reuse one key accidentally across unrelated actors/operations unless the
scenario intentionally tests `idempotency_key_reused`.

---

# 72. Integration Harness Preflight

After integration assets are delivered to `origin/main`, ChatGPT performs a
read-only preflight before the first full runner.

Preflight checks:

- valid `/approve integration` owner comment + matching unedited Orchestrator receipt is still present/current;
- integration approval was issued only at `OWNER_INTEGRATION_APPROVAL_REQUIRED`;
- exact integration diff scope;
- no production source changes;
- runtime guard fail-closed logic;
- seeder guard/manifest cleanup;
- runner performs actual-private-disk prior-manifest cleanup **before** focused seeder tests;
- prior-manifest cleanup uses the real Stage 8 configured private disk/volume and never the isolated seeder-test disk;
- cleanup oracle proves manifest rows/AnswerFile/File/blob removal while preserving unrelated sentinels;
- focused seeder test covers residual AnswerFile/File/private-blob cleanup + reseed convergence;
- runner retry semantics do not depend on a previous failed invocation reaching final cleanup;
- private volume safety;
- no secret logging;
- deterministic fixture ownership;
- E2E does not override repositories/Dio/business controllers;
- API security probes use real auth/transport;
- Start API assets implement the complete Section 34.1.4A / 62 exact-intent matrix;
- completed Start replay preserves original `intent + attempt_id? + Idempotency-Key`;
- stale Resume/no-switch and body/fingerprint mismatch probes assert exact status/code and unchanged history;
- every Section 20.1 F13 coverage-map row has a concrete manifest fixture,
  executable scenario and oracle assertion;
- dedicated Stage 8 runtime sets `PHP_CLI_SERVER_WORKERS=4`;
- Section 14.1 can correlate application DB sessions to the exact Stage 8 container client address;
- Section 47A.7 and 47A.8 each require two distinct simultaneous application PostgreSQL lock waiters before blocker release;
- a correct serialized final branch without overlap evidence is rejected as incomplete;
- Section 47A concurrency uses real API workers/barriers rather than mocked repositories;
- Scheduler guard globally discovers the exact BE-007 candidate predicate before every command invocation;
- Scheduler TOCTOU safety superset rejects non-manifest active in-progress Blitz Attempts;
- all global `blitz:reconcile-timeouts` invocations are routed through the guarded helper;
- no direct unguarded Scheduler command remains in runner/API helper code;
- first/second invocation exact candidate expectations are implemented;
- guard negative verifier proves non-manifest facts stop before command invocation;
- DB oracle ordinary reads remain manifest/sentinel scoped except the narrowly approved read-only Scheduler safety scans;
- restart procedure preserves DB/private volume;
- cleanup preserves unrelated sentinel data;
- no Stage 9 scoring assumptions;
- no new E2E framework.

Preflight verdict:

```text
PASS
or
NOT ACCEPTED
```

Do not run full real-stack before PASS.

---

# 73. Focused Asset Verification Before Delivery

Codex must run proportional checks.

Backend:

```bash
php artisan test tests/Feature/Seeders/Stage8E2eSeederTest.php
```

PowerShell pure verifiers:

```text
verify_stage8_runtime_guard.ps1
verify_stage8_test_files.ps1
verify_stage8_oracle.ps1
verify_stage8_api_security.ps1
```

Dart static/format for created integration files as current repository tooling
permits.

Run:

```bash
git diff --check
```

Do not run:

- full backend suite;
- full frontend suite;
- Windows real-stack full runner

during Codex integration-asset implementation.

The full runner waits for ChatGPT preflight PASS.

---

# 74. Seeder Test Coverage

`Stage8E2eSeederTest` must verify:

- rejects non-testing environment;
- rejects wrong DB driver/database;
- rejects missing/blank password;
- deterministic IDs;
- repeated seed converges;
- manifest cleanup removes only owned rows;
- unrelated sentinel row survives;
- FK-safe cleanup order;
- correct Tenant isolation;
- required Blitz/pair/cohort/Attempt/Question fixtures;
- selected-Student practice fixture G;
- Blitz-first no-cohort fixture H;
- isolated null-timer Institution/fixture I;
- isolated late-write/concurrency fixtures J;
- one dedicated manifest Scheduler Blitz aggregate whose first-run candidate set
  can be asserted exactly;
- one future in-progress Attempt in that same manifest Scheduler aggregate with a
  deadline safely beyond the two-command Scheduler proof;
- explicit unrelated sentinel Blitz/Assessment/Attempt rows that are not active
  in-progress Scheduler candidates and must remain byte/field unchanged;
- no score/checking data;
- private fixture cleanup only within approved Stage 8 namespace/root;
- dynamic manifest-owned Attempt/Answer/AnswerFile/File/private-blob cleanup;
- cleanup idempotency when invoked twice;
- unrelated DB/private-file sentinel survives cleanup;
- reseeding after cleanup converges to the exact deterministic baseline.

Add focused coverage equivalent to:

```text
test_cleanup_removes_dynamic_file_answer_and_blob_then_reseed_converges
```

The test must:

1. use the isolated `Stage8E2eSeederTest` private test disk/root;
2. seed the deterministic structure;
3. create a real manifest-owned Student Attempt/file-answer path using delivered
   application actions where practical;
4. prove `attempt_answers`, `answer_files`, `files` and a real private blob exist;
5. capture `ownedState()`/manifest facts;
6. invoke `cleanupOwnedState()` twice;
7. prove all captured manifest-owned DB/file/blob state is gone;
8. prove unrelated sentinels are unchanged;
9. run the seeder again;
10. prove the deterministic structural baseline is restored.

Do not disable ownership guards or broaden cleanup to unrelated rows/files.

This proves the cleanup algorithm. Section 66 separately proves the runner uses
that cleanup on the **actual private disk before** the isolated seeder test.

---

# 75. Oracle Verifier Coverage

`verify_stage8_oracle.ps1` must test pure assertion/manifest functions with
synthetic data.

At minimum reject:

```text
wrong Blitz lifecycle timestamps
wrong synchronized common end
individual common end non-null
pair/cohort mismatch
extra/missing recipient
Attempt #3
replacement #2 without exception
wrong official_score_eligible
replacement deadline using common end instead of own start+duration
timeout finalized at scheduler time instead of deadline
wrong terminal reason
fabricated unanswered answer row
non-null score/checking
wrong exception link
public/private file mismatch
wrong idempotency result metadata
Start request missing/using wrong intent body
Resume replay changing/dropping original attempt_id
same Start key changing intent without idempotency_key_reused
stale Resume creating/switching to replacement #2
selected-Student official designation unexpectedly mutating pair
first official Blitz activation failing to establish cohort
Blitz-first pair lock being rejected by later Homework activation/Start
null timer-mode activation leaving recipients/cohort/idempotency writes
late typed/file write altering frozen answer/file state
file loser leaving an uncompensated staged blob
concurrent write/Submit result that matches neither approved serialized branch
concurrency evidence with fewer than 2 distinct application DB waiters
concurrency evidence whose waiters were never simultaneous
concurrency evidence counting blocker/observer/unrelated DB sessions
concurrency evidence without `wait_event_type = Lock`
47A.7/47A.8 marked PASS when `overlap_observed = false`
missing/wrong `PHP_CLI_SERVER_WORKERS`
Scheduler current candidate outside manifest
Scheduler manifest assessment paired with wrong Institution
Scheduler TOCTOU safety superset containing a future non-manifest active in-progress Attempt
Scheduler first invocation with an extra candidate
Scheduler second invocation with any remaining candidate
guard attempting to invoke command after a rejected safety fact set
unrelated Scheduler sentinel changed after command
cleanup touching sentinel
runner plan where Stage8E2eSeederTest executes before prior-manifest cleanup
runner plan where fresh seed/baseline executes before prior-cleanup verification
prior-manifest cleanup that swaps `private_files_disk` to isolated seeder-test disk
prior-manifest cleanup that deletes non-manifest DB/file/blob sentinel
retry plan that requires the previous invocation's final cleanup to have completed
```


## 75.1 Concurrency Probe Verifier Coverage

Create:

```text
frontend/integration_test/stage8_concurrency_probe.ps1
frontend/integration_test/verify_stage8_concurrency_probe.ps1
```

The probe helper owns only:

```text
blocker transaction lifecycle
observer sampling
application-session correlation
bounded overlap evidence
finally-release safety
```

It does not own business-result assertions.

`verify_stage8_concurrency_probe.ps1` must reject synthetic fact sets such as:

```text
worker count missing or != 4
observer database != testlabuz_testing
wrong application client address
waiting_count < 2
duplicate waiter PID counted twice
waiter PID equals blocker/observer PID
wait_event_type != Lock
waiters appear in different samples but never together
blocking chain not rooted in approved blocker
manifest Attempt mismatch
timeout reached but PASS emitted
blocker released before overlap evidence
overlap_observed=false while race marked PASS
```

No production route/action is modified to expose concurrency identity.

---

# 76. API Security Verifier Coverage

`verify_stage8_api_security.ps1` must test pure response assertion helpers without
real secrets.

At minimum verify assertion helpers reject:

```text
wrong status
wrong machine code
missing/extra required error-envelope fields
non-empty errors object for a non-validation conflict/privacy error
empty validation errors for 422 validation_failed
unexpected validation field errors
accepting 403 where protected Student-submission privacy requires 404
accepting 404/409 for Section 39 malformed request vectors that require 422
Question leakage in pre-Start detail
non-null monitoring score
answer/file leakage in monitoring
cross-Tenant success where 404 expected
incorrect Submit terminal conflict
incorrect already-granted conflict
incorrect idempotency replay result
unexpected persistence mutation for a negative probe
```

Add pure/synthetic assertion tests for the Section 34.1 matrix so the verifier
itself proves it distinguishes every exact status/code class before any real
secret-bearing request is executed.

Scheduler candidate ownership is verified separately by
`verify_stage8_oracle.ps1` under Section 44.7; do not hide that safety check
inside the API-security verifier.

---

# 77. Android Manual Smoke Preparation

Create:

```text
frontend/integration_test/prepare_stage8_manual_smoke.ps1
```

It must:

1. validate Stage 8 runtime guard;
2. cleanup/seed dedicated manual-smoke fixture state;
3. output only safe:
   - API base/port instructions;
   - fixture display/login identifiers needed by Project Owner;
   - scenario checklist;
4. never print password;
5. prepare state isolated from Windows completed-flow fixtures;
6. provide cleanup command/mode.

Use:

```text
STAGE8_E2E_PASSWORD
```

from Project Owner environment.

---

# 78. Android Manual Smoke — Teacher

Required real Android/emulator Teacher smoke:

1. login as Stage 8 Teacher;
2. open prepared Draft/Scheduled Blitz;
3. confirm mobile does **not** show:
   ```text
   Edit
   Manage Questions
   Schedule
   Official designation
   Archive
   Close
   ```
4. press:
   ```text
   Activate
   ```
5. confirm activation dialog;
6. verify Active detail;
7. press:
   ```text
   Monitor
   ```
8. verify basic monitoring Student cards;
9. confirm no:
   ```text
   exception reason
   Grant additional attempt
   score
   answer/file content
   ```
10. navigate/back successfully.

This proves the approved mobile Teacher capability matrix.

---

# 79. Android Manual Smoke — Student

Required real Android/emulator Student smoke:

1. login as assigned Student;
2. see Active Blitz in workspace;
3. open detail;
4. confirm Questions hidden before Start;
5. press Start/Resume;
6. confirm countdown;
7. answer at least:
   ```text
   one non-file Question
   ```
8. save;
9. if reliable on target emulator, upload prepared supported file through native
   picker;
10. Submit with at least one unanswered Question;
11. confirm terminal summary;
12. confirm no score/checking/result.

If file picker cannot be reliably automated manually on target emulator,
Windows real-stack file flow remains required and Android manual smoke may omit
file upload with explicit evidence note.

Student core Start/save/Submit remains mandatory.

---

# 80. Android Mobile Timing Smoke

At least one mobile Student scenario should visibly confirm:

```text
countdown decreases
leaving/reopening Resume does not reset timer
```

Do not require waiting for full timeout if Windows/API oracle already proves
exact timer finalization.

---

# 81. Integration Cleanup

The same Stage 8 manifest/ownership rules apply to both:

```text
prior-run cleanup before focused seeder tests
final cleanup after integration evidence
```

Cleanup must remove only manifest-owned:

```text
Stage 8 DB rows
Stage 8 private blobs
temporary fixture files
generated local evidence files marked disposable
temporary Android port-reverse mapping
```

Preserve:

- unrelated DB sentinel;
- unrelated files;
- repository files;
- PostgreSQL container/data;
- unrelated Docker volumes.

The dedicated Stage 8 private named volume may remain provisioned if empty and
the existing workflow allows it.

---

# 82. Cleanup Oracle

After cleanup verify:

```text
all Stage 8 manifest DB rows absent
all Stage 8 manifest private blobs absent
unrelated sentinel present
temporary local fixture root removed
temporary Android reverse mapping removed
```

Do not assert whole testing DB is empty.

Run this bounded cleanup oracle immediately after the Section 66 prior-run
cleanup and again after final cleanup.

Prior-run cleanup evidence records:

```text
actual configured private disk/volume identity
cleanup confirmed before Stage8E2eSeederTest
prior manifest present? yes/no
bounded manifest-owned DB/File/blob removal facts
unrelated sentinels unchanged
```

Do not print secrets or any path outside the approved Stage 8 private root.

---

# 83. Security / Secret Hygiene

Integration assets and logs must never expose:

```text
password
bearer token
Sanctum token
APP_KEY
DB password
full env dumps
raw Docker inspect secrets
private file content unless deterministic fixture assertion requires a bounded hash/length
```

If evidence needs an idempotency key, deterministic Stage 8 test UUID is allowed
because it is not an auth secret.

---

# 84. Production Scope Integrity

Before final integration PASS verify:

```text
git diff <pre-integration-production-SHA>...<integration-assets-SHA>
```

contains only approved integration/test assets.

If production source was modified during integration asset task:

```text
NOT ACCEPTED / BLOCKED
```

unless it came from a separately approved focused production-fix contract.

---

# 85. Required Cross-Task Real-Stack Invariants

The final integration evidence must jointly prove:

```text
Teacher can prepare Blitz
selected-Student practice cannot become official but can execute as practice
official pair/cohort remains correct
first official Blitz activation can establish a previously-null common cohort
Blitz-first Student activity still permits later Homework activation/first Homework Start
activation freezes timer mode
unset Institution timer mode blocks activation atomically
Student cannot see Questions pre-Start
Start creates/resumes only allowed Attempt
server timing controls countdown
answers/files persist
late typed/file writes cannot change frozen state
Submit freezes without scoring
real write-vs-Submit races first prove two simultaneous application PostgreSQL lock waiters, then serialize without post-freeze mutation
timeout freezes at deadline
global Scheduler never runs while a non-manifest active in-progress Blitz could be mutated
monitoring reflects authoritative state
exception invalidates #1 eligibility
grant creates no #2
Student explicit Start creates #2
#2 gets full own duration
no #3
mobile Teacher scope restricted
mobile Student execution works
```

No one isolated oracle substitutes for the whole vertical.

---

# 86. Integration Findings

Use severity:

## P1

Security/Tenant/privacy/timer/attempt-history corruption.

Examples:

- pre-Start Question leak;
- cross-Tenant access;
- Attempt #3;
- replacement recovery accidentally created by a read/replay action;
- private file leak;
- terminal history overwritten;
- device time extends server execution.

## P2

Major real-stack contract break.

Examples:

- official cohort wrong;
- #2 duration wrong;
- activation/Submit/grant idempotency broken;
- monitoring state materially wrong;
- mobile capability overreach;
- answer/file/Submit production UI fails;
- restart loses DB/private file/idempotency state;
- runner executes focused seeder tests before real prior-manifest cleanup;
- prior-run cleanup cannot safely remove manifest-owned AnswerFile/File/private blobs;
- dedicated concurrency runtime is not multi-worker;
- either real race lacks two simultaneous application PostgreSQL lock waiters;
- a race is reported PASS from sequential-valid outcomes without overlap evidence;
- global Scheduler runs without proving all mutable candidates are Stage 8 manifest-owned;
- Scheduler mutates an unrelated sentinel row.

## P3

Minor integration-specific issue.

Final PASS target:

```text
P1=0
P2=0
P3=0
```

---

# 87. Evidence Rerun Policy After Fix

If integration reveals a defect and a fix is delivered, ChatGPT decides exactly
which evidence is invalidated.

Examples:

## Student countdown presentation-only fix

May require:

```text
focused frontend verification
affected Windows Student timing scenario
Android Student smoke if mobile affected
```

Not automatically every API oracle.

## Backend Start/exception timing fix

Normally requires rerun:

```text
affected Backend Phase 2 evidence
Start/exception API oracle
Windows replacement scenario
DB oracle
restart persistence
possibly Student mobile smoke
```

## Shared auth/Tenant/file fix

May require broad integration rerun.

Do not rerun everything ritualistically; do not retain invalid evidence.

---

# 88. Integration PASS Conditions

`S08-INT-001 = PASS` only when all required evidence is green:

```text
Backend Phase 2 PASS remains valid
Frontend Phase 2 PASS remains valid

integration assets accepted/delivered
Integration Harness Preflight PASS

runtime guard PASS
seeder focused test PASS
pure asset verifiers PASS

Windows real-stack main flow PASS
Teacher authoring/lifecycle flow PASS
Student pre-Start privacy PASS
Student execution/Submit PASS
monitoring/exception/replacement PASS

direct API/security PASS
Tenant/ownership/privacy PASS
idempotency PASS
Start exact-intent/replay/no-switch oracle PASS
selected-Student practice/official prohibition PASS
first-activation cohort + Blitz-first Homework compatibility PASS
unset timer-mode activation rollback PASS
late typed/file write immutability PASS
real backend overlap/lock-contention proof PASS for 47A.7 and 47A.8
write-vs-Submit concurrency PASS
synchronized/individual timing PASS
Scheduler global candidate guard PASS
Scheduler first/second guarded invocation PASS
unrelated Scheduler sentinel unchanged PASS
timeout/Scheduler/Close precedence PASS
DB oracle PASS
private-file oracle PASS

backend restart persistence PASS
post-restart idempotency replay PASS

Android Teacher smoke PASS
Android Student smoke PASS

prior-run cleanup/retry safety PASS
cleanup PASS
final Git state clean/synchronized
P1=0
P2=0
P3=0
```

After all Integration PASS conditions are satisfied and the integration result is
accepted/delivered, stop.

The next state must be:

```text
OWNER_CLOSURE_APPROVAL_REQUIRED
```

Do not start Closure Review merely because this task is PASS.

Only a new repository-owner:

```text
/approve closure
```

comment at that exact state, with a valid matching bot receipt, releases ChatGPT
Stage Closure Review.

---

# 89. Integration NOT ACCEPTED Conditions

Return:

```text
S08-INT-001: NOT ACCEPTED
```

for any unresolved:

- P1;
- P2;
- real-stack production failure;
- security/Tenant leak;
- pre-Start Question leak;
- timer/deadline mismatch;
- idempotency failure;
- exception/#2 policy violation;
- Attempt #3;
- monitoring privacy/state failure;
- restart persistence failure;
- private-file failure;
- required Windows run failure;
- required Android smoke failure;
- missing/invalid multi-worker runtime prerequisite;
- either 47A.7 or 47A.8 lacks two simultaneous application lock waiters;
- cleanup failure.

Do not proceed to Stage Closure while NOT ACCEPTED.

---

# 90. Final Integration Report Template

ChatGPT final integration review should record:

```text
Stage 8 Integration — S08-INT-001

Audited product main before assets: <sha>
Integration assets delivery: <PR/SHA>
Audited integration main: <sha>

Backend Phase 2: PASS
Frontend Phase 2: PASS
Owner integration approval receipt: PASS
Harness Preflight: PASS

Runtime:
Stage 8 container: PASS
PostgreSQL identity: PASS
PHP_CLI_SERVER_WORKERS=4: PASS
Concurrent DB-session correlation: PASS
Private volume: PASS
API boundary: PASS
Flutter pin: PASS

Windows real-stack:
Teacher preparation: PASS
Locked partial official designation: PASS
Activation: PASS
Student pre-Start privacy: PASS
Student execution: PASS
File flow: PASS
Submit with unanswered: PASS
Monitoring: PASS
Exception grant: PASS
Replacement #2: PASS
Timeout UI: PASS

API/security:
Auth/role: PASS
Tenant isolation: PASS
Assignment/ownership: PASS
Pre-Start safe projection: PASS
Strict transport: PASS
Start intent/replay/no-switch oracle: PASS

Stage-level direct API:
Selected-Student practice + official prohibition: PASS
First official cohort establishment: PASS
Blitz-first -> Homework activation/Start: PASS
Unset timer-mode activation rollback: PASS
Late typed write immutability: PASS
Late file write/blob compensation: PASS
Typed write vs Submit overlap evidence: PASS
Typed write vs Submit concurrency: PASS
File write vs Submit overlap evidence: PASS
File write vs Submit concurrency: PASS

Idempotency:
Activate: PASS
Start #1/#2: PASS
Submit: PASS
Grant exception: PASS

Timing/lifecycle:
Synchronized: PASS
Individual: PASS
Replacement own duration: PASS
Scheduler candidate guard: PASS
Scheduler first invocation: PASS
Scheduler second no-op invocation: PASS
Scheduler unrelated sentinel: PASS
Teacher Close precedence: PASS

Oracle:
DB state: PASS
No scoring/checking: PASS
Private file: PASS

Restart:
Persistence: PASS
Idempotency replay: PASS

Android:
Teacher mobile Activate/Monitor: PASS
Student mobile Start/Save/Submit: PASS

Prior-run cleanup/retry safety: PASS
Cleanup: PASS
Final Git state: clean/synchronized

Findings:
P1 = 0
P2 = 0
P3 = 0

Verdict:
PASS

Next required gate:
OWNER_CLOSURE_APPROVAL_REQUIRED

Closure approval:
NOT YET GRANTED BY THIS PASS
```

Do not paste huge successful logs.

---

# 91. Integration Asset Expected File Scope

Create likely:

```text
backend/database/seeders/Stage8E2eSeeder.php
backend/tests/Feature/Seeders/Stage8E2eSeederTest.php

frontend/integration_test/stage8_runtime_guard.ps1
frontend/integration_test/verify_stage8_runtime_guard.ps1

frontend/integration_test/stage8_concurrency_probe.ps1
frontend/integration_test/verify_stage8_concurrency_probe.ps1

frontend/integration_test/stage8_test_files.ps1
frontend/integration_test/verify_stage8_test_files.ps1

frontend/integration_test/stage8_oracle.ps1
frontend/integration_test/verify_stage8_oracle.ps1

frontend/integration_test/stage8_api_security.ps1
frontend/integration_test/verify_stage8_api_security.ps1

frontend/integration_test/stage8_e2e_support.dart
frontend/integration_test/stage8_blitz_flow_test.dart
frontend/integration_test/run_stage8_windows_e2e.ps1
frontend/integration_test/prepare_stage8_manual_smoke.ps1
```

A small Stage 8-specific helper under:

```text
frontend/integration_test/
```

is allowed if required.

Do not create production helpers for tests.

---

# 92. Codex Focused Verification Before Asset Delivery

Codex must report exact results for:

```text
Stage8E2eSeederTest
verify_stage8_runtime_guard.ps1
verify_stage8_concurrency_probe.ps1
verify_stage8_test_files.ps1
verify_stage8_oracle.ps1
verify_stage8_api_security.ps1
Dart format check for Stage 8 integration Dart files
focused analyze/compile check for integration Dart where repository tooling supports it
git diff --check
```

Do not run full real-stack Windows Stage 8 flow before preflight.

Do not run full backend/frontend suites again merely for asset creation.

---

# 93. Codex Delivery Report

Codex must report:

1. implementation summary;
2. exact integration assets created/modified;
3. Stage 8 runtime/container/private-volume design;
4. seeder manifest/scenario fixtures;
5. locked official-cohort fixture;
6. test-file fixtures;
7. Windows E2E scenario composition;
8. direct API/security coverage;
9. DB/private-file oracle coverage;
10. F13 Stage-level direct API/concurrency coverage and manifest mapping;
11. multi-worker runtime + PostgreSQL lock-overlap evidence design;
12. idempotency coverage;
13. synchronized/individual/replacement timing coverage;
14. global Scheduler candidate-guard/TOCTOU/unrelated-sentinel coverage;
15. backend restart/persistence procedure;
16. Android manual smoke preparation;
17. prior-run actual-disk cleanup ordering and retry-safety design;
18. cleanup safety;
19. focused seeder test result including residual AnswerFile/File/blob cleanup + reseed convergence;
20. pure verifier results;
21. integration Dart format/analyze result;
22. `git diff --check`;
23. final `git status --short`;
24. focused scope/diff self-check;
25. any blocker/deviation.

Do not claim real-stack PASS merely because integration assets compile.

Full real-stack PASS occurs only after:

```text
asset delivery
+
ChatGPT Harness Preflight PASS
+
Project Owner/CI execution
+
ChatGPT final review
```

---

# 94. Integration Readiness Verdict

```text
Integration scope                   = RESOLVED
Production-change boundary          = RESOLVED
Runtime identity                    = RESOLVED
Multi-worker concurrency runtime     = RESOLVED
PostgreSQL overlap/lock-wait oracle  = RESOLVED
Private-volume identity             = RESOLVED
Seeder namespace/cleanup            = RESOLVED
Prior-run cleanup ordering          = RESOLVED
Retry after residual file state      = RESOLVED
Official pair/cohort fixtures       = RESOLVED
Selected practice/official denial     = RESOLVED
First-activation cohort proof         = RESOLVED
Blitz-first Homework compatibility    = RESOLVED
Missing timer-mode rollback proof     = RESOLVED
Late write immutability proof         = RESOLVED
Finalization/write concurrency proof  = RESOLVED
Question/file fixtures                = RESOLVED
Windows real-stack flow               = RESOLVED
Pre-Start privacy proof             = RESOLVED
Synchronized timing proof           = RESOLVED
Individual timing proof             = RESOLVED
Answer/file proof                   = RESOLVED
Submit proof                        = RESOLVED
Timeout/Scheduler/Close proof       = RESOLVED
Global Scheduler candidate guard     = RESOLVED
Scheduler TOCTOU isolation           = RESOLVED
Scheduler unrelated-state oracle     = RESOLVED
Monitoring proof                    = RESOLVED
Exception/#2 proof                  = RESOLVED
No Attempt #3 proof                 = RESOLVED
Tenant/security proof               = RESOLVED
Exact negative-probe oracle         = RESOLVED
Idempotency proof                   = RESOLVED
DB/private-file oracle              = RESOLVED
Restart persistence                 = RESOLVED
Teacher Android smoke               = RESOLVED
Student Android smoke               = RESOLVED
Cleanup                             = RESOLVED
Harness Preflight                   = RESOLVED
Findings/rerun policy               = RESOLVED

Implementation Readiness Gate       = PASS
Execution dependency                = S08-BE-PHASE-2 PASS + S08-FE-PHASE-2 PASS
Owner integration approval          = REQUIRED before Codex handoff
Next gate after final integration PASS = OWNER_CLOSURE_APPROVAL_REQUIRED
Closure Review release              = valid /approve closure receipt only
```
