# S04-INT-001 — Stage 4 Windows Real-Stack E2E Verification

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S04-INT-001` |
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | `Integration / Windows real-stack verification` |
| Status | `Approved` |
| Depends on | Stage 4 Backend Phase 2 `PASS`; Stage 4 Frontend Phase 2 `PASS` |
| Planning baseline | `origin/main = b7e452961b24428b3cde5413b0257bb33a680274` |
| Blocks | Stage 4 Closure Review |
| Delivery | Integration assets/evidence may be delivered after automated PASS; final task acceptance remains pending until Project Owner manual smoke PASS |

This is the only Stage 4 integration task.

## 2. Goal

Prove the delivered Stage 4 organizational graph through the real stack:

```text
Flutter Windows UI
→ real Riverpod/router/repositories/DTOs/Dio
→ real Laravel/Sanctum API
→ real PostgreSQL testlabuz_testing
```

The task verifies Groups, Teacher/Student Group memberships, Parent–Student relationships, persistence, tenant isolation, and privacy-safe direct-ID behavior.

This task creates verification assets only. It must not repair product code.

If real-stack verification exposes a production defect:

```text
INTEGRATION FINDING
```

Report it and stop the affected scenario. Do not change production code inside this task.

## 3. Context Discipline

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. `frontend/AGENTS.md`;
5. current source/tests/config needed for Stage 4 integration;
6. existing Stage 1–3 integration source assets only as implementation patterns.

Codex must not read roadmap/docs, previous task contracts/prompts, Stage history, Phase 2 reviews, closure files, or the Stage index to rediscover requirements.

Reuse the existing Stage 3 integration design patterns where directly useful. Do not generalize/refactor the old Stage 1–3 E2E infrastructure merely to reduce duplication.

## 4. Entry Gate

Before edits:

```text
branch = main
HEAD == origin/main
origin/main == b7e452961b24428b3cde5413b0257bb33a680274
ahead/behind = 0/0
worktree = clean
origin = expected TestLabUz repository
```

If `origin/main` has advanced, stop and report the new SHA instead of silently rebasing the approved contract.

Create one focused branch from the approved baseline.

## 5. Strict Scope

### Allowed integration assets

Expected files:

```text
backend/database/seeders/Stage4E2eSeeder.php
backend/tests/Feature/Seeders/Stage4E2eSeederTest.php

frontend/integration_test/stage4_groups_relationships_flow_test.dart
frontend/integration_test/run_stage4_windows_e2e.ps1
frontend/integration_test/stage4_runtime_guard.ps1
frontend/integration_test/verify_stage4_runtime_guard.ps1
frontend/integration_test/stage4_oracle.ps1
frontend/integration_test/prepare_stage4_manual_smoke.ps1

tasks/integration/stage-04/S04-INT-001-stage-04-e2e-evidence.md
```

One small `stage4_*` integration-test support file is allowed only if it prevents the main Dart/PowerShell file from becoming a God file.

### Forbidden changes

Do not change:

```text
backend/app/**
backend/routes/**
backend/database/migrations/**
frontend/lib/**
pubspec.yaml / pubspec.lock
platform files
docker compose/config files
docs/**
AGENTS.md
Stage 4 backend/frontend task files
Phase 2 review files
Stage closure files
```

If a production/config/schema change is required for the E2E to pass, report the exact blocker/finding.

No new package or third-party E2E framework.

## 6. Reuse of Existing Verification Evidence

The following fresh Stage 4 checkpoint evidence is authoritative and must NOT be rerun merely for this task:

```text
Backend Phase 2:
PASS
full backend suite = 293 passed / 17,306 assertions

Frontend Phase 2:
PASS
full frontend suite = 991 passed
flutter analyze = PASS
format = PASS
Windows debug build = PASS
```

Therefore this task must NOT rerun:

```text
full backend suite
full frontend suite
full-project flutter analyze
full-project format
standalone Windows build
Stage 1/2/3 broad E2E
Backend Phase 2
Frontend Phase 2
```

Only the focused integration-asset checks and the Stage 4 real-stack E2E defined below are required.

A broad rerun is allowed only if this task unexpectedly changes shared/production infrastructure, which is outside approved scope and should normally cause `BLOCKED` instead.

## 7. Dedicated Testing Safety

Use one dedicated Stage 4 backend runtime:

```text
container:
testlabuz-stage4-e2e-app

Laravel:
APP_ENV=testing

database:
pgsql
current_database() = testlabuz_testing

API:
http://127.0.0.1:<ApiPort>/api/v1
```

The Stage 4 runtime guard must fail closed before any seed, login, mutation, or product request unless it proves:

- exact container identity;
- container is running;
- requested API port is published exactly once to loopback `127.0.0.1`;
- API base URL is exactly loopback HTTP + `/api/v1`;
- Laravel environment is `testing`;
- PostgreSQL driver and `pdo_pgsql` are active;
- current database is exactly `testlabuz_testing`;
- database server is the approved local Docker PostgreSQL service/container on the expected Docker network;
- protected `/api/v1` boundary is reachable.

If the dedicated container cannot be provisioned safely from existing local Docker infrastructure without repository/config changes, report `ENVIRONMENT BLOCKED`.

The guard verification script must contain a focused negative matrix for malformed/non-loopback URL, wrong port/binding/container/environment/database/driver/server plus the exact accepted runtime.

## 8. Deterministic Stage 4 Fixture World

`Stage4E2eSeeder` owns an explicit deterministic manifest.

Use reserved Stage 4 identities:

```text
UUID namespace/prefix:
04000000-...

login prefix:
e2e_s04_

display-name prefix:
E2E S04
```

Prefix matching alone is not ownership proof. The seeder must know every owned UUID/login/relationship from an explicit manifest and refuse before mutation if an existing reserved identity has incompatible institution/role/ownership.

Minimum fixtures:

### Institutions and actors

- active target Institution;
- active foreign Institution;
- active password-complete target Institution Admin;
- active password-complete foreign Institution Admin;
- target active + inactive Teacher;
- target active + inactive Student;
- target active + inactive Parent;
- foreign active Teacher;
- foreign active Student;
- foreign active Parent;
- at least one wrong-role target actor usable for API authorization denial.

### Groups

- target active seeded Group;
- target archived seeded Group;
- foreign active Group.

### Memberships

- one target current Teacher membership;
- one target current Student membership;
- foreign current Teacher/Student memberships.

### Parent–Student

- one target current relationship;
- one foreign current relationship;
- one target pair reserved for UI connect → disconnect → reconnect history verification.

Seeder rules:

- require one transient password from `STAGE4_E2E_PASSWORD`;
- password is generated/prompted outside the repository and never printed, committed, logged, or placed in evidence;
- refuse non-testing environment, non-PostgreSQL, or database != `testlabuz_testing`;
- never truncate, globally reset sequences, disable constraints, or delete unrelated rows;
- clean/recreate only explicit Stage 4 manifest rows, in FK-safe order;
- preserve all non-Stage-4 rows byte-for-byte;
- be repeatable.

Run the guarded seeder twice before the real product flow. The focused seeder test must prove repeatability, guard refusal, manifest ownership safety, and unrelated-row preservation.

## 9. Independent Oracle

`stage4_oracle.ps1` must create a temporary read-only PostgreSQL oracle after the second seed and before Stage 4 product mutations.

It must capture enough sanitized state to verify:

- target/foreign Institution and User identities;
- target active/archived and foreign Group baseline;
- target/foreign membership baseline;
- target/foreign Parent–Student relationship baseline;
- foreign/unrelated rows that must not change;
- IDs required by security probes and persistence assertions.

Do not manufacture expected results by calling the same Stage 4 product endpoint being tested.

The oracle artifact:

- lives only under the system temp directory;
- contains no password, bearer token, token hash, or unnecessary PII;
- is strictly validated by the E2E test;
- is removed in `finally`.

## 10. Real Windows Product Flow

The main integration test must use the real application and visible UI actions for product flows.

Forbidden in the Flutter E2E product flow:

- mocked/fake HTTP/repositories;
- injected authenticated session;
- direct database writes;
- bypassing login/router/UI;
- production test-only routes/hooks;
- arbitrary long sleeps.

Use bounded waits on observable UI state.

### 10.1 Authentication and Stage 4 entry

Through real Windows UI:

1. login as target Institution Admin;
2. reach canonical Institution Admin shell;
3. navigate to `Groups`;
4. confirm `Parent–Student Connections` is reachable from the Users area and remains nested under Users.

Do not re-test the complete Stage 1/3 authentication matrix.

### 10.2 Group lifecycle vertical flow

Through UI:

1. create one new active Group with deterministic E2E values;
2. confirm navigation to authoritative Group Detail;
3. edit allowed fields and confirm refreshed server values;
4. return/list-refresh as needed and confirm the Group exists;
5. archive the Group;
6. confirm archived state is visible and mutation actions that require an active Group are unavailable/read-only.

The flow must prove real frontend DTO/API agreement for create/detail/edit/archive. Do not repeat every list filter/sort/widget case already covered by Frontend Phase 2.

### 10.3 Teacher membership vertical flow

On the created active Group before archive:

1. assign the reserved active target Teacher through UI;
2. confirm Teacher membership projection;
3. remove the Teacher through UI;
4. confirm current projection no longer contains that membership;
5. assign the same Teacher again;
6. confirm current membership returns.

Database/oracle postconditions must prove:

```text
same group + teacher pair:
at least one ended historical row
exactly one current row
current membership id != ended membership id
```

### 10.4 Student membership vertical flow

Repeat the same vertical sequence for the reserved active target Student:

```text
assign
→ visible current membership
→ remove
→ absent from current projection
→ reassign
→ visible current membership
```

Database/oracle postconditions must prove ended history plus one distinct current membership row.

### 10.5 Parent–Student vertical flow

Use the reserved unconnected target Parent/Student pair.

Through UI:

1. open `Parent–Student Connections`;
2. default `By Parent`;
3. choose the target Parent anchor;
4. connect the target Student;
5. confirm current relationship row;
6. switch to `By Student`;
7. choose the same Student anchor;
8. confirm the Parent is visible;
9. disconnect the current relationship;
10. confirm the pair is absent from current projections;
11. reconnect the same pair;
12. confirm both perspectives show the current relationship.

Database/oracle postconditions must prove:

```text
same parent + student pair:
one ended relationship from the first connection
one current relationship after reconnect
current relationship id != ended relationship id
```

## 11. Cross-Layer Security and Tenant Checks

Direct real API calls are allowed only for security/postcondition oracles.

Using a real authenticated target Institution Admin session/token, verify:

```text
GET foreign Group detail -> privacy-safe 404

GET foreign Group Teacher memberships -> privacy-safe 404
GET foreign Group Student memberships -> privacy-safe 404

POST own Group with foreign Teacher id in teacher_ids -> privacy-safe 404
POST own Group with foreign Student id in student_ids -> privacy-safe 404

POST Parent–Student with target Parent + foreign Student -> privacy-safe 404
POST Parent–Student with foreign Parent + target Student -> privacy-safe 404

DELETE foreign Parent–Student relationship id -> privacy-safe 404
```

Using a real wrong-role authenticated actor:

```text
GET /institution/groups -> 403
```

Verify no response/evidence leaks:

- foreign record details;
- institution ownership fields not in approved resources;
- passwords/tokens;
- SQL/stack/internal exception text.

After the complete run, foreign Institution Group/membership/relationship rows must equal the pre-run oracle.

## 12. Restart Persistence

After the mutation flow:

1. stop/start only `testlabuz-stage4-e2e-app`;
2. re-run the runtime guard;
3. launch a fresh Windows integration-test process;
4. login again normally;
5. verify persisted visible state.

Required persisted state:

- UI-created Group exists with edited values and archived lifecycle;
- current Teacher membership from the reassign remains;
- previous Teacher membership history remains ended;
- current Student membership from the reassign remains;
- previous Student membership history remains ended;
- current Parent–Student reconnect remains;
- previous Parent–Student relationship history remains ended;
- foreign/unrelated fixture state is unchanged.

The persistence test is a second named Stage 4 E2E test, not a full regression suite.

## 13. Manual Project-Owner Smoke

Automated integration PASS does not replace the short human smoke.

`prepare_stage4_manual_smoke.ps1` must:

- use the same fail-closed Stage 4 runtime guard;
- prompt for the transient shared password with `Read-Host -AsSecureString`;
- seed the deterministic Stage 4 fixture world;
- print only the login name `e2e_s04_target_admin`;
- launch the real Windows app with the guarded API base URL;
- clear password variables/secure-string memory in `finally`.

Project Owner checklist:

```text
1. Login as e2e_s04_target_admin.
2. Open Groups and visually confirm seeded active + archived Groups.
3. Open the active Group and confirm Teacher/Student membership sections render normally.
4. Open Users → Parent–Student Connections.
5. Select one seeded Parent and one seeded Student perspective and confirm current relationship UI is understandable and usable.
6. Confirm no obvious overflow, broken navigation, raw error/JSON, or foreign-Institution data appears.
```

No second broad automated suite is required around this smoke.

Codex may deliver automated integration assets/evidence after automated PASS with:

```text
AUTOMATED INTEGRATION PASS
OWNER SMOKE PENDING
```

Final `S04-INT-001 Accepted / Delivered` is assigned by ChatGPT only after the Project Owner reports manual smoke `PASS`. This avoids reopening Codex merely for bookkeeping.

## 14. Focused Verification Only

### 14.1 Focused backend verification

From repository root:

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app `
  php artisan test tests/Feature/Seeders/Stage4E2eSeederTest.php
```

Run Pint only on changed Stage 4 PHP files:

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app `
  ./vendor/bin/pint --test `
  database/seeders/Stage4E2eSeeder.php `
  tests/Feature/Seeders/Stage4E2eSeederTest.php
```

### 14.2 Focused Dart format

```powershell
C:\Users\Administrator\fvm\versions\3.44.7\bin\cache\dart-sdk\bin\dart.exe `
  format --output=none --set-exit-if-changed `
  frontend/integration_test/stage4_groups_relationships_flow_test.dart
```

If one additional Stage 4 Dart support file is created, include only that file too.

### 14.3 Stage 4 real-stack E2E

Run exactly one Stage 4 runner invocation after focused checks PASS:

```powershell
powershell -ExecutionPolicy Bypass -File frontend/integration_test/run_stage4_windows_e2e.ps1 `
  -FlutterExecutable C:\Users\Administrator\fvm\versions\3.44.7\bin\flutter.bat `
  -ApiPort <dedicated-loopback-port>
```

The runner itself must execute:

```text
runtime guard matrix
guarded seeder twice
independent oracle
one mutation-flow Windows E2E
foreign/unrelated preservation checks
backend restart
one persistence Windows E2E
final database/oracle checks
temporary-artifact cleanup
```

Do not rerun the runner after PASS.

### 14.4 Git checks

```powershell
git diff --check
git status --short
```

Inspect the complete task diff and confirm only approved integration assets/evidence changed.

## 15. Evidence File

Create:

```text
tasks/integration/stage-04/S04-INT-001-stage-04-e2e-evidence.md
```

Record only sanitized evidence:

- audited baseline SHA;
- dedicated container/API port identity without secrets;
- focused seeder test result;
- focused Pint result;
- focused Dart format result;
- runtime guard result;
- seeder repeatability result;
- mutation-flow E2E result;
- tenant/security matrix result;
- restart/persistence result;
- foreign/unrelated preservation result;
- cleanup result;
- `git diff --check`;
- changed-file scope;
- manual smoke status (`Pending` until Project Owner reports it).

Never record passwords or tokens.

## 16. Delivery

If all automated checks PASS:

1. focused diff/scope/security self-check;
2. commit only task-owned files;
3. push focused branch;
4. open PR to `main`;
5. merge;
6. fetch/synchronize `main`;
7. verify:

```text
main == origin/main
ahead/behind = 0/0
worktree = clean
```

Suggested:

```text
branch:
task/s04-int-001-stage4-real-stack-e2e

commit:
test(integration): verify stage 4 real stack
```

Do not modify the Stage index or declare Stage 4 closed.

## 17. Acceptance Criteria

Automated portion is PASS only if:

- all integration assets stay test/evidence-only;
- guarded seeder is repeatable and cannot touch non-owned data;
- real Windows app authenticates against the real Laravel/Sanctum/PostgreSQL stack;
- Group create/edit/membership/archive vertical flow passes;
- Parent–Student connect/disconnect/reconnect vertical flow passes;
- historical membership/relationship rows are preserved with distinct replacement IDs;
- cross-tenant/direct-ID checks return the required private behavior;
- wrong-role Institution Group access is denied;
- foreign/unrelated rows remain unchanged;
- state persists across backend restart/fresh Windows process;
- focused verification and `git diff --check` pass;
- automated evidence is delivered safely.

Final task acceptance additionally requires:

```text
Project Owner manual smoke = PASS
```

No full backend/frontend suite, full analyze, full format, standalone build, or prior-Stage E2E rerun is part of this task.

## 18. Codex Completion Report

Return only:

```text
AUTOMATED INTEGRATION PASS / BLOCKED / FINDING

changed files
focused seeder test result
focused Pint result
focused Dart format result
runtime guard result
Stage 4 mutation E2E result
tenant/security result
restart/persistence result
foreign/unrelated preservation result
git diff --check
PR + merge SHA
final Git state
manual smoke command/status
```

Do not repeat this contract in the report.
