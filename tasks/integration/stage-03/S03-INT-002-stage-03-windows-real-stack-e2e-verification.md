# Codex Task: Stage 3 Windows Real-Stack End-to-End Verification

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-INT-002` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Integration / Windows real-stack verification` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Depends on | `S03-INT-001`, `S03-BE-001 through S03-BE-007`, and `S03-FE-001 through S03-FE-009`; execution is blocked until all 17 are `Accepted / PASS / Delivered` |
| Preparation snapshot | `origin/main = 3d6131c55c4923a3bbf3649bc762f7e836610be6` on `2026-08-14`: `S03-INT-001` and `S03-BE-001..007` delivered; `S03-FE-001..009` not yet implemented |
| Blocks | `Separate Stage 3 Closure Review` |

## 2. Goal

Prove the complete Stage 3 Institution Administration and User Management slice
works through the real Flutter Windows application, real Dio/Laravel/Sanctum
API, and real PostgreSQL testing database, with deterministic fixtures,
tenant/security oracles, restart persistence, sanitized evidence, and a
human-observable smoke check.

This is a verification-assets/evidence task. It must not silently repair an
accepted product defect. Any predecessor defect is a finding and blocks
acceptance.

## 3. Included Scope

- Add/extend deterministic Stage 3 guarded E2E fixture seeding.
- Add Flutter Windows `integration_test` coverage using the real application
  stack and visible UI actions.
- Add focused integration support/guard tests only where required.
- Run all required backend/frontend quality gates.
- Verify all Stage 3 UI/API/security/tenant/persistence scenarios below.
- Obtain truthful project-owner/operator Windows smoke evidence.
- Create sanitized Stage 3 E2E evidence.
- Record only the S03-INT-002 index row as In Progress when execution begins.
- Update truthful task/index/README state after read-only PASS.

## 4. Predecessor and Scope Gate

Before edits, prove every prior Stage 3 row is:

```text
Accepted / PASS / Delivered
```

This includes:

```text
S03-INT-001
S03-BE-001..S03-BE-007
S03-FE-001..S03-FE-009
```

Also prove Stage 2 remains closed and current `origin/main` contains all
required implementation/delivery commits.

Do not infer readiness from task-file presence. Stop on any unaccepted,
undelivered, NOT ACCEPTED, DELIVERY BLOCKED, or contradictory predecessor.

## 5. Allowed Verification Assets

Expected focused files:

```text
frontend/integration_test/stage3_institution_administration_flow_test.dart
frontend/integration_test/run_stage3_windows_e2e.ps1
frontend/integration_test/prepare_stage3_manual_smoke.ps1
frontend/integration_test/stage3_runtime_guard.ps1
frontend/integration_test/verify_stage3_runtime_guard.ps1
frontend/integration_test/stage3_oracle.ps1
backend/database/seeders/Stage3E2eSeeder.php
backend/tests/Feature/Seeders/Stage3E2eSeederTest.php
small focused Stage 3 E2E-only Dart/PowerShell/seeder/guard/oracle support files
tasks/integration/stage-03/S03-INT-002-stage-03-e2e-evidence.md
truthful Phase 1 S03-INT-002 index state and post-PASS task/index/README bookkeeping
```

Reuse the installed Flutter SDK `integration_test` dependency and accepted
Stage 1/2 integration infrastructure. Add no third-party E2E framework.

Application production code may not be changed to fix findings or add test-only
routes/authentication/data bypasses. If an accessibility Semantics target is
missing and cannot be exercised safely, report a predecessor finding rather
than adding a production-only test hook.

The main integration test may orchestrate the Stage 3 journey, but it must not
become a single catch-all/God file. Split reusable E2E-only waiting, fixture,
API-oracle, and scenario responsibilities into focused test support when needed.
Do not create a parallel product client, router, repository, or session model.

## 6. Dedicated Testing Safety

Use exactly one dedicated Stage 3 backend container:

```text
testlabuz-stage3-e2e-app
```

The runner accepts an explicit port, constructs exactly
`http://127.0.0.1:<stage3-e2e-port>/api/v1`, and must never accept a caller-
authorized arbitrary API URL. Before any fixture mutation, login, Flutter
launch, or Stage 3 product endpoint request, a fail-closed runtime guard must
prove:

```text
the inspected running container is exactly testlabuz-stage3-e2e-app
its container port is published exactly once to 127.0.0.1:<requested-port>
APP_ENV = testing
DB_CONNECTION = pgsql with pdo_pgsql loaded
current_database() = testlabuz_testing
the resolved DB server is the inspected approved local Docker PostgreSQL
container/service on the expected Docker network, not an external host
the selected loopback API exposes the expected protected /api/v1 boundary
```

The runner/runtime guard must refuse the container/target failures above. The
guarded Stage 3 seeder independently must refuse:

- any non-testing environment;
- any database other than `testlabuz_testing`;
- missing transient credential inputs;
- unsafe/unrecognized fixture ownership.

Fixture reset may affect only records unmistakably reserved for Stage 3 E2E,
using an enumerated fixture manifest with deterministic UUIDs, exact expected
relationships, and names/login prefixes such as:

```text
E2E S03 ...
e2e_s03_...
```

Prefix matching alone is not proof of ownership. If an existing reserved UUID,
login, Institution, role, creator, or dependency does not match the manifest,
the seeder must refuse before mutation. Exact UI-created login slots must also
be enumerated in that manifest. It must never truncate tables, reset sequences
globally, delete unrelated Stage 1/2/manual/future data, or disable constraints.

The Stage 3 runner generates distinct transient passwords for password-complete
fixtures, first-login fixtures, created-account initial credentials, and changed
credentials. Never hardcode, commit, print, return, log, screenshot, or record
them. Evidence and commands use redacted placeholders. Any temporary credential
artifact must live outside the repository, contain no token/hash, be removed in
`finally`, and never be distributed with a Windows debug build.

Add a focused fail-closed guard test matrix covering malformed/non-loopback
targets, wrong/unbound ports, wrong container identity/binding, wrong Laravel
environment/database/driver, missing `pdo_pgsql`, an unresolved/unapproved or
external DB server, and the one exact accepted dedicated runtime. Do not reuse
an unknown development/production server or expose it publicly.

## 7. Required Deterministic Fixture World

At minimum create:

### 7.1 Actors and Institutions

- active password-complete target Institution Admin in active target
  Institution;
- active password-complete second-Institution Admin and separate active
  Institution;
- first-login Institution Admin for password-gate checks;
- inactive Institution Admin;
- Institution Admin inside inactive Institution;
- active Platform Owner, Teacher, Student, Parent wrong-role actors.

The separate active Institution must contain an eligible password-complete
Institution Admin and no Teacher/Student/Parent accounts so the exact all-zero
Dashboard state can be verified without inventing a no-Institution account.

### 7.2 Target Institution Users

- active and inactive Teacher, Student, Parent;
- enough mixed Users for page 1/2 at page size 20;
- deterministic names/logins/contacts/created/updated timestamps for each
  search/filter/sort case;
- literal `%`, `_`, and escape-character search fixtures;
- duplicate sort values for UUID tie-break evidence;
- known Dashboard Teacher/Student/Parent totals, each including active and
  inactive accounts with no active/inactive split;
- a lifecycle target whose token is obtained by real login before deactivation,
  plus separately stored target token rows for byte-for-byte preservation
  evidence; no seeded plaintext token is exposed;
- one exact unused reserved login slot for each Teacher/Student/Parent create
  flow, removed/reset safely by the next repeatable seed.

### 7.3 Scope and Disclosure Oracles

- same-looking foreign-Institution Teacher/Student/Parent records;
- foreign User UUIDs;
- own/foreign Institution Admin UUIDs that must be safe not-found through
  Institution User routes;
- known protected creator/token/password/settings/relationship placeholders
  that must never appear in responses/UI/evidence.

### 7.4 Profile and Settings

- deterministic target Institution profile and read-only type/status;
- unaffected foreign Institution profile;
- exactly one settings row per Institution;
- target starts with known unconfigured educational policy plus initialized
  timezone/upload limits, unless a repeatable seed mode separately verifies
  configured persistence;
- foreign Institution has distinct settings that must remain unchanged;
- target starts with no categories for unconfigured flow;
- foreign Institution has a distinct complete category set;
- no Group/relationship/learning/result records need be invented for Stage 3.

Seeder must be repeatable and leave all UUID/role/ownership/settings/category/
password constraints valid.

Run the seeder twice before the product flow. Focused tests must prove the same
logical fixture state on both runs, refusal before mutation for every guard,
reserved-row cleanup in foreign-key-safe order, exact token/relationship
handling, and unrelated Stage 1/2/manual rows unchanged.

## 8. Independent Baseline Oracle

After the second guarded seed and before calling any Stage 3 product endpoint,
generate one guarded read-only PostgreSQL oracle artifact in the system
temporary directory. It must derive at least:

- exact Dashboard role totals and the separate all-zero Institution baseline;
- exact User-list identities/order/search/filter/sort/page boundaries and
  pagination totals;
- target/foreign Institution, User, settings, category, token-row, and
  unrelated-row preservation snapshots;
- exact initial configured/unconfigured persistence state needed by the
  scenario matrix.

Do not call a Dashboard/User/profile/settings/category product endpoint to
manufacture the expectation later asserted against that same endpoint. Direct
API calls may test authorization/input/disclosure and postconditions, but they
are not an independent baseline oracle.

The oracle artifact contains no password, token value, password/token hash,
private response, or unnecessary PII. Pass only its temporary path to the test,
validate it strictly, and remove it in `finally` after the complete run.

## 9. Real Windows Stack Boundary

Launch the real Flutter Windows app using:

```text
real UI and Semantics
real Riverpod/session/router
real repositories/data sources/DTOs
real Dio/auth interceptor
real Laravel API/middleware/requests/actions/resources
real Sanctum tokens
real PostgreSQL testlabuz_testing
```

Forbidden:

- mocked/fake HTTP or repository;
- injected authenticated provider/session;
- direct database writes from Flutter test;
- bypassing login/first-login/router/UI;
- web/widget-only substitution for required Windows flow;
- production test/debug endpoints or hardcoded credentials;
- arbitrary long sleeps.

Use visible UI actions for product flows. Direct real API calls are allowed only
for independent postcondition/security oracles that cannot be safely observed
through UI. Use bounded waits on observable state.

## 10. Mandatory Scenario Matrix

Record explicit PASS/FAIL for every group.

### 10.1 Institution Admin Shell and Session

- login through real UI and `/auth/me` bootstrap;
- canonical `/institution-admin` dashboard entry;
- exact Dashboard/Users/Institution/Settings navigation;
- User new/detail routes select Users;
- visible navigation and supported Windows back behavior through the real app;
- direct-entry and restart-at-location semantics through the delivered router
  boundary; browser-only reload/forward and mobile/web denial remain covered by
  deterministic router/widget tests when Windows has no equivalent user action;
- desktop compact/wide behavior and no overflow;
- identity/Institution context;
- logout immediate protected-data removal;
- Institution Admin mobile/web unsupported boundary through automated route
  tests (Windows E2E does not impersonate device surface).

### 10.2 Dashboard

- exact target Teacher/Student/Parent total counts, each including active and
  inactive accounts and exposing no active/inactive split;
- partial-zero and all-zero behavior through the separate eligible active
  Institution Admin/Institution fixture;
- Refresh and navigation freshness;
- creating one Teacher/Student/Parent increases only that role total exactly
  once; deactivation/reactivation leaves every Dashboard total unchanged;
- no Platform/Institution Admin, Group, Learning, identity, contact, settings,
  or protected metric blocks.

### 10.3 Institution Profile

- exact own profile load;
- read-only type/status;
- edit each allowed field and nullable clears;
- changed-fields-only/no-change/no-request behavior;
- cancel sends nothing;
- protected type/status/Institution/creator/settings/count/lifecycle behavior;
- refresh/reload server authority;
- foreign Institution remains unchanged.

### 10.4 User List

- default own Teacher/Student/Parent only;
- role/status and combined filters;
- search name/login/email/phone, case, literal `%`/`_`/escape;
- each allowed sort/direction and deterministic ties;
- page size 20/50/100, Previous/Next, truthful metadata/ranges;
- global empty/filtered empty/clear filters where fixtures allow;
- rapid query stale-response suppression;
- no own/foreign Institution Admin or foreign User row;
- exact public resource boundary.

### 10.5 User Detail

- list-row navigation and direct UUID route;
- exact public fields/nulls/status/first-login/timestamps;
- unknown, foreign, own Institution Admin, and Platform Owner UUID safe not-found;
- rapid target/reload safety;
- no tenant/creator/password/token/permissions/settings/relationship/learning
  disclosure.

### 10.6 User Creation and First Login

For Teacher, Student, and Parent:

- exact form fields and role allowlist;
- cancel sends nothing;
- validation and duplicate login behavior;
- one submit/duplicate-submit protection;
- exact confirmed server User and own-Institution/creator/default state oracle;
- password/hash never returned/logged/evidenced;
- list/detail/dashboard refresh/invalidation;
- no implicit token/relationship/group/settings/learning record;
- new account login reaches mandatory `/change-password`;
- password change succeeds, old password fails, new password succeeds, correct
  role entry resumes.

### 10.7 User Edit and Lifecycle

- edit exact full name/email/phone, nullable clears, changed-only/no-change;
- login/role/Institution/password/first-login/last-login/creator/token protected;
- cancel/confirm behavior;
- one body-less lifecycle POST and no optimistic success;
- active→inactive, repeated inactive, inactive→active, repeated active;
- real and no-op lifecycle commands preserve every stored target Sanctum token
  row byte-for-byte when snapshotted immediately before/after each command;
- while inactive, new login and protected use of the retained valid token are
  blocked by account-state enforcement;
- activation creates/restores/rotates/deletes no token and alters no password,
  first-login, or last-login state; the retained still-valid token may resume
  only otherwise-authorized access after reactivation;
- a token separately removed by explicit logout/revocation is not restored;
- access probes occur outside the command-local byte-for-byte snapshot window,
  so normal authentication-owned `last_used_at` behavior is not misattributed
  to the lifecycle command;
- list/detail refresh and pagination/filter correction are authoritative;
  Dashboard refresh, when exercised, proves all three totals remain unchanged;
- relationships/history preservation at persistence oracle level if such
  predecessor fixtures exist; absence is recorded, not invented;
- foreign/unrelated Users/Institution unchanged.

### 10.8 Assessment Settings

- initial unconfigured resource and form state;
- all seven fields valid complete PUT;
- threshold 0/100 and representative decimal boundary through API/widget tests;
- both timer modes, both Student modes, all Parent modes;
- multiple valid IANA timezones and invalid/offset values;
- upload min/max and >25/>15 rejection;
- fixed attempt rules/platform maxima visible and non-editable;
- attempt/platform/category/protected fields rejected through API oracle;
- cancel/no-change/one PUT/no automatic retry behavior covered by deterministic
  Flutter tests and observable flow;
- updater actor/one-row invariant/foreign settings unchanged;
- no historical timestamp/result/file/category/User rewrite.

### 10.9 Understanding Categories

- unconfigured exact state;
- fixed labels/codes/order and non-numeric Not completed;
- valid full 0–100 save/reload;
- boundary and representative range sets;
- gap/overlap/decimal/duplicate/missing/unknown/order/label invalid rejection;
- cancel/no-change/one PUT/no automatic retry behavior;
- atomic rollback preserves prior set after invalid request;
- actor updater/exactly five rows/concurrent safety through backend oracle/tests;
- foreign categories unchanged;
- no result/history/settings rewrite.

### 10.10 Authorization, Input, and Disclosure

- `401` unauthenticated for every Stage 3 endpoint family;
- middleware precedence for inactive User, inactive Institution, and first-login;
- `403` wrong role for Platform Owner/Teacher/Student/Parent;
- safe `404` User target scope cases;
- `422` unknown/protected query/body keys with no mutation;
- no client `institution_id` override anywhere;
- no credentials, hashes, tokens, creator data, foreign tenant data,
  relationships, answers, scores, results, or unnecessary protected fields in
  responses/UI/logs/evidence.

### 10.11 Mutation Uncertainty and Stale Isolation

Deterministic Flutter tests must prove every POST/PATCH/PUT mutation:

- no automatic retry/replay;
- one read-only reconciliation at most where specified;
- causal success only after the exact direct endpoint status/envelope/message/
  resource required by that accepted mutation contract;
- a reconciliation GET may publish only current server state and remains
  explicitly unconfirmed even when it exactly matches submitted intent;
- duplicate intent blocked;
- stale target/query/session/account-switch completion ignored.

Real-stack smoke must observe at least one controlled uncertain/no-replay path
if the environment can safely induce it. If it cannot, record automated
deterministic evidence and the manual limitation truthfully; do not fake a
network failure.

### 10.12 Cross-Role Session Isolation

Execute:

```text
Institution Admin with loaded dashboard/profile/users/settings/categories
→ logout
→ Teacher/Student/Parent or Platform Owner login/direct Institution Admin URL/back
```

No prior Institution Admin shell, count, profile, User, settings, category,
form draft, password, mutation, or error data may remain or flash. Returning as
the Institution Admin loads fresh server state.

### 10.13 Restart and Persistence

After successful profile/User/lifecycle/settings/category changes:

1. restart the dedicated Laravel API without resetting PostgreSQL;
2. restart/rebootstrap Flutter;
3. login again;
4. prove all committed profile, User, lifecycle, dashboard count, settings, and
   category state persists;
5. prove no mutation replay occurred during restart/bootstrap;
6. prove foreign/unrelated fixtures remain unchanged.

## 11. Deterministic Non-E2E Coverage

In addition to Windows real flow, normal tests must remain green for:

- DTO malformed/missing/wrong-type/inconsistent cases;
- loading/data/global-empty/filtered-empty/unconfigured/partial/error/Retry;
- validation and server field errors;
- `401/403/404/409/422` and transport/server failures;
- mutation in-flight/cancel/no-change/no automatic retry/reconciliation;
- stale target/query/session/account-switch behavior;
- compact/wide/text scale/keyboard/focus/semantics;
- Stage 1 session/router and Stage 2 Platform regressions.

Do not weaken deterministic tests because E2E uses populated fixtures.

## 12. Required Quality Gates

Use current repository-valid commands. Backend tests are authoritative only in
the dedicated Docker PHP runtime using PostgreSQL `testlabuz_testing`; do not
substitute host PHP without `pdo_pgsql`, SQLite, or an in-memory database.

Run every backend test/check capable of migrating or resetting the testing
database before the final two guarded seeds, oracle creation, and Windows flow.
If any such check must run again in Phase 1, regenerate the exact guarded
fixture baseline and independent oracle before continuing.

At minimum:

Backend:

```text
cd backend
php artisan test
vendor/bin/pint --test
composer validate --strict
```

Frontend:

```text
cd frontend
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test integration_test
flutter build windows --debug
```

Run the Stage 3 Windows integration test explicitly against the dedicated real
backend through the focused runner, for example:

```text
integration_test/run_stage3_windows_e2e.ps1 \
  -FlutterExecutable <approved-flutter-executable> \
  -ApiPort <dedicated-loopback-port>
```

The runner must execute the runtime-guard matrix, seed twice, create the
independent oracle, run the complete mutation flow, restart the exact dedicated
backend without resetting PostgreSQL, start a fresh Windows test process for
persistence, and clean temporary artifacts in `finally`.

Also run PowerShell parser checks for every changed `.ps1`, focused seeder and
runtime-guard tests, `git diff --check`, prompt byte/hash verification, a
sensitive-pattern scan over changed verification assets, and non-writing scope
checks proving no locked docs, production source, package manifest, or lockfile
changed. Run all additional configured security/static/build gates. Any
required failure blocks acceptance.

## 13. Human-Observable Windows Smoke

Obtain truthful project-owner/operator observation against the real stack:

```text
login
→ shell/direct routes/navigation
→ dashboard counts/refresh
→ profile view/edit/cancel/no-change
→ User list/search/filter/sort/page
→ User detail/create each role/first-login
→ User edit/lifecycle cancel+confirm
→ settings configure/invalid/no-change
→ categories configure/invalid/no-change
→ reload/restart persistence
→ logout/account switch/no stale protected data
```

Record performer role, UTC date, environment, and PASS/FAIL by group. Never
record credentials/tokens/private responses.

Codex must not self-attest, infer, or fabricate human observation from automated
output. After automated Phase 1 and the runnable smoke checklist are ready,
pause explicitly with:

```text
EXECUTION PAUSED: AWAITING PROJECT-OWNER WINDOWS SMOKE
```

This pause is not a Phase 2 verdict. Continue only after the project owner or
authorized operator returns the grouped attestation. A reported FAIL blocks
acceptance. If the required attestation remains missing when the acceptance
gate is requested, classify it as material P2 and return `NOT ACCEPTED`.

## 14. Sanitized Evidence

Create:

`tasks/integration/stage-03/S03-INT-002-stage-03-e2e-evidence.md`

Before Phase 2, record and freeze:

- branch, audited `origin/main` base, frozen changed-file list and SHA-256
  hashes, runtime versions, and Windows target;
- loopback address and testing DB identity;
- exact container/binding/runtime guard matrix;
- fixture guard/repeatability/reset ownership;
- independent pre-endpoint PostgreSQL oracle and its safe cleanup;
- backend/frontend command outputs/counts;
- every scenario group PASS/FAIL;
- independent database/API tenant/disclosure/state oracles;
- mutation request counts/no replay/reconciliation evidence;
- restart persistence;
- human smoke attestation;
- `Phase 2: Pending` at the Phase 1 freeze;
- non-blocking limitations.

Never include passwords, password hashes, tokens, keys, environment dumps,
private sensitive payloads, or secret-bearing screenshots/commands.

Phase 2 reports P1/P2/P3 and its verdict in the read-only execution report; it
must not edit this evidence. After PASS only, Phase 3 may change the evidence
solely to replace `Phase 2: Pending` with the exact PASS UTC timestamp and
P1/P2/P3 summary. No scenario, command, oracle, smoke, hash, or limitation may
be rewritten after the gate. Re-run non-writing scope, hash, and secret checks.
Commit/PR/merge/final-main facts belong in the final delivery report because
they do not exist when Phase 1 evidence is frozen.

## 15. Acceptance Criteria

- [ ] All 17 predecessors are accepted/delivered and unchanged by verification.
- [ ] Seeder is guarded, repeatable, tenant-safe, and touches reserved fixtures
      only in `testlabuz_testing`.
- [ ] Exact dedicated container/loopback/runtime guard and its fail-closed test
      matrix pass before every possible mutation or product request.
- [ ] The app uses `pgsql`/`pdo_pgsql` and the inspected approved local Docker
      PostgreSQL endpoint, not SQLite/in-memory/external database substitution.
- [ ] Independent PostgreSQL baselines are created before product endpoint use,
      are not derived from the endpoints under test, and are safely removed.
- [ ] Real Flutter Windows→Dio→Laravel→Sanctum→PostgreSQL path runs.
- [ ] Every mandatory scenario group has explicit PASS with evidence.
- [ ] Dashboard exposes only the three total role counts; create increments the
      correct total once and lifecycle leaves all totals unchanged.
- [ ] Lifecycle command-local snapshots preserve token rows, retained-token
      access is blocked while inactive, reactivation creates/restores no token,
      and a retained valid token may resume only otherwise-authorized access.
- [ ] Tenant/auth/input/disclosure oracles pass.
- [ ] All mutations prove no automatic replay; only exact direct responses
      confirm success and reconciliation GETs remain explicitly unconfirmed.
- [ ] Restart persistence and foreign/unrelated preservation pass.
- [ ] Backend/frontend full gates and Windows build pass.
- [ ] Human Windows smoke passes.
- [ ] Evidence is complete, reproducible, and secret-safe.
- [ ] No predecessor product behavior is silently fixed.
- [ ] Stage 3 is not marked closed by this task.

## 16. Explicit Non-Goals

- Product bug fixes or refactors.
- Stage 3 Closure Review/closure bookkeeping.
- Stage 4 Groups/relationships or any learning workflow.
- Android/web real E2E.
- Production deployment/load/chaos/security penetration testing.
- Third-party E2E packages.
- Production debug/test routes, credentials, or bypasses.
- Hard delete/import/export/bulk/password-reset/custom roles/categories.

## 17. Stop Conditions

Stop on predecessor failure/undelivered state, non-testing DB/environment,
wrong/unsafe dedicated runtime binding, unsafe fixture ownership, missing
independent oracle, required credential exposure, real-stack substitution,
missing mandatory scenario, failed/missing human attestation at the gate,
failing required check, predecessor product/contract defect, scope drift, or
need for destructive cleanup.

## 18. Execution and Acceptance Workflow

### Phase 0 — Git/Environment Preflight

- Verify approved remote, clean synchronized main, all predecessor states.
- Treat the preparation snapshot only as historical planning context; execution
  must use and record the then-current synchronized `origin/main`.
- Only owner-prepared S03-INT-002 task/prompt may be untracked.
- Create/switch to:

  `task/s03-int-002-stage3-windows-e2e`

- Prove exact dedicated container/loopback/environment/database/served-API
  identity before fixture mutation, login, Flutter launch, or product request.
- Do not commit/push before Phase 2.

### Phase 1 — Verification Assets and Execution

Before Phase 2, mark only the S03-INT-002 Stage 3 index row
`In Progress / Not started / Not started`; keep the detailed task `Approved`,
every other task state unchanged, Stage 3 open, and Stage 4 blocked.

Create only approved assets. Run the guard matrix, seed twice, generate the
independent pre-endpoint oracle, and all automated/real-stack/restart scenarios.
Prepare automated evidence, but do not freeze it yet. Do not fix predecessor
findings. Then pause for truthful project-owner smoke as required by Section 13.
After its attestation is recorded, complete and freeze the Phase 1 evidence;
only then may Phase 2 begin.

### Phase 2 — Strictly Read-Only Acceptance Gate

Re-read all authority, predecessor states, complete diff/untracked files,
commands, scenarios, container/fixture/database safety, independent oracle,
persistence, human smoke, frozen evidence/hashes, scope, and secret checks.

During Phase 2: no edits, fixture/database mutation, test rerun, app/server
restart, write-format, stage, commit, push, PR, merge, or self-fix. Read-only
inspection and read-only database queries are allowed.

Classify:

- P1: tenant/auth/secret/database/destructive/core real-stack failure;
- P2: material contract/test/scenario/reproducibility/persistence/evidence/human
  smoke/scope failure;
- P3: non-blocking observation.

Any P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

### Phase 3 — Post-PASS Delivery

After PASS only:

1. mark only S03-INT-002 `Accepted` and index review truthfully;
2. update README/index so next action is separate Stage 3 Closure Review;
3. keep Stage 3 explicitly not closed and Stage 4 not started;
4. apply only the bounded Phase 2 PASS evidence annotation from Section 14;
5. rerun final non-writing scope/secret/diff/hash checks;
6. commit:

   ```text
   test(stage3): add institution administration end-to-end verification

   Task: S03-INT-002
   ```

7. push branch, open PR, merge only safe/green;
8. fast-forward local main and prove local main == origin/main, clean tree.

Delivery failure after PASS: `FINAL STATUS: DELIVERY BLOCKED`.
Complete delivery: `FINAL STATUS: ACCEPTED`.

Next action is the separate Stage 3 Closure Review.

## 19. Required Final Report

Report final status; all predecessor/Git/container/environment/DB/fixture
preflight; changed verification assets; runtime/Windows target; independent
baseline oracle; backend/frontend command results/counts; every scenario group
PASS/FAIL; exact Dashboard and token-lifecycle semantics; tenant/auth/disclosure/
mutation/direct-success/no-replay/unconfirmed-reconciliation/restart oracles;
human smoke; evidence path/frozen hashes; P1/P2/P3; criteria; scope/secret
checks; commit/branch/PR/checks/merge/hash/clean delivery; and blockers/
deviations.

Explicitly state:

```text
Stage 3 was NOT marked Closed by this task.
Stage 4 was NOT started.
Next action: Run the separate Stage 3 Closure Review.
```
