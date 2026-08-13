# S02-INT-001 Stage 2 Windows Real-Stack E2E Evidence

Date: 2026-08-13

Correction and attestation evidence recorded at: `2026-08-13T10:41:54Z`.

Branch under test: `task/s02-int-001-stage2-windows-e2e`

Pre-delivery base commit: `31193e557c1a2be87bbe2a9deea4430c1062d4f6`

Original Phase 1 state: automated verification PASS; mandatory project-owner
Windows smoke PASS.

First Phase 2 state: `NOT ACCEPTED`. Its four findings are preserved below.

Correction-cycle Phase 1 state: PASS.

New strictly read-only Phase 2 state: PASS, recorded at
`2026-08-13T10:53:29Z`.

## Historical Failed Phase 2 and Correction Cycle

The first read-only Phase 2 ended with `FINAL STATUS: NOT ACCEPTED`. No commit,
push, pull request, acceptance bookkeeping, or Stage 2 Closure Review followed
that verdict. Its authoritative findings were:

1. P1: the Windows runner accepted an arbitrary API URL and could therefore
   mutate a non-loopback or non-testing API.
2. P2: dashboard, Institution-list, and Institution-Admin-list expectations
   were manufactured from the same product endpoints later asserted.
3. P2: the exact approved execution prompt was missing from
   `tasks/integration/stage-02/S02-INT-001-CODEX-PROMPT.md`.
4. P2: this evidence recorded only a date, not an actual UTC date/time.

The focused correction cycle resolved each finding without changing product or
backend code:

1. The runner now accepts only an explicit port and constructs exactly
   `http://127.0.0.1:<port>/api/v1`. Before seed, reset, login, Flutter launch,
   or mutation, it binds that port to the exact running dedicated container,
   proves `APP_ENV=testing`, proves PostgreSQL
   `current_database()=testlabuz_testing`, and verifies the served API. It
   fails closed when any binding or identity proof is missing.
2. A guarded read-only PostgreSQL oracle is generated after deterministic
   seeding and before any product-endpoint assertion. Dashboard totals/recent
   order and all baseline Institution/Admin list search, filter, sort, page,
   boundary, and count expectations come from this independent oracle. The
   ephemeral JSON file is placed in the system temporary directory and safely
   removed by the runner.
3. The complete owner-approved prompt was restored byte-for-byte at the exact
   required path. Its SHA-256 is
   `8FAD2B922EB6BDAD32689AB6C8E9F8E8FB243AEA74D66A603C46BB51A9CD6AF9`.
4. The system-clock UTC recording time is now preserved above. The owner smoke
   observation remains dated `2026-08-13 UTC`; no unrecorded execution time was
   invented.

## Environment

- Docker: `29.4.1`, build `055a478`.
- Docker Compose: `v5.1.3`.
- PHP: `8.4.24` in the dedicated Docker app container.
- Laravel: `13.24.0`.
- Composer: `2.10.2`.
- PostgreSQL client/server family: `18.4`.
- Flutter: `3.44.7 stable`.
- Dart: `3.12.2`.
- Windows target: `windows-x64`, Microsoft Windows `10.0.19045`.
- The host PHP runtime lacks the PostgreSQL PDO driver. All authoritative
  backend/database checks therefore ran in the dedicated Docker PHP runtime.
- The default Flutter on `PATH` is older than the accepted Dart SDK constraint.
  Verification used the already-installed Flutter `3.44.7` toolchain.

## Git and Predecessor Preflight

- Branch name: PASS.
- Local HEAD equaled `origin/main` before verification assets were added: PASS.
- Base commit: `31193e557c1a2be87bbe2a9deea4430c1062d4f6`.
- Origin identity: `https://github.com/Shoxrux2017/testlabuz.git`: PASS.
- Stage 1 status was `Closed`: PASS.
- All sixteen Stage 2 predecessor task rows were `Accepted`, `PASS`, and
  `Delivered`: PASS.
- Activation-only dirty state matched the approved task/index preparation:
  PASS.
- GitHub CLI/publishing preflight is intentionally deferred until after Phase
  2 PASS under the project-owner execution instruction. Its absence did not
  block verification.

## Dedicated Runtime and Database Safety

- Dedicated app container: `testlabuz-stage2-e2e-app`.
- Loopback-only binding: `127.0.0.1:8815`.
- Redacted API base: `http://127.0.0.1:8815/api/v1`.
- Runtime `APP_ENV`: `testing`.
- Runtime PostgreSQL database: `testlabuz_testing`.
- Ordinary app remained separate on its existing runtime/database.
- Ordinary app identity remained `APP_ENV=local`, database `testlabuz`.
- Ordinary database contained zero `E2E S02 ` Institution fixture rows after
  the isolated seed: PASS.
- No production, ordinary local, or non-testing database was reset or seeded.
- The correction runner accepts a port, not a caller-authorized API URL, and
  constructs only `http://127.0.0.1:<explicit-port>/api/v1`: PASS.
- Scheme, exact IPv4 host, explicit port, exact path, absent userinfo/query/
  fragment, exact Docker publish binding, container identity, Laravel
  environment, PostgreSQL database, and served-API checks all run before the
  first possible mutation: PASS.
- Fail-closed guard matrix: PASS; 14 invalid targets, 2 invalid runtime
  identities, and 1 syntactically valid but unbound loopback port were rejected
  before mutation, while the exact approved dedicated runtime was accepted.

## Guarded Fixture Evidence

- `Stage2E2eSeeder` checks `APP_ENV=testing` before reading credentials or
  mutating data: PASS.
- It checks PostgreSQL `current_database() = testlabuz_testing`: PASS.
- Wrong-environment refusal: PASS.
- Wrong-database refusal: PASS.
- Missing shared, initial-admin, and new-admin transient credential refusal:
  PASS.
- Reset scope is limited to exact Stage 2 fixture prefixes and directly owned
  fixture rows; no table truncation is used: PASS.
- Seeder ran successfully twice in succession before the real E2E run: PASS.
- Repeatability, exact fixture counts, one safe settings row per Institution,
  and unrelated-row preservation are covered by focused tests: PASS.
- Independent read-only PostgreSQL oracle generation after seeding and before
  product endpoint verification: PASS.
- The oracle established exact dashboard Institution/User totals, exact five
  recent-Institution identities/order, Institution search/filter/sort/page
  identities/counts/boundaries, and Admin search/filter/sort/page identities/
  counts/boundaries: PASS.
- No dashboard, Institution-list, or Admin-list product endpoint was used to
  derive a baseline expectation: PASS.
- The ephemeral oracle contained no credential and was removed from the system
  temporary directory after the run: PASS; no oracle artifact exists in the
  repository or evidence directory.
- Credentials were generated or entered only in transient local process memory.
  They were not committed, echoed, returned, or placed in this evidence.

## Automated Quality Results

### Backend

- `php artisan test` in the Docker PHP runtime: PASS, 146 tests and 6,709
  assertions.
- `vendor/bin/pint --test`: PASS, 121 files.
- `composer validate --strict`: PASS.
- No additional accepted static-analysis/security command is configured.

### Flutter

- `flutter analyze` after the correction: PASS, no issues.
- `flutter test` after the correction: PASS, 389 tests.
- `dart format --output=none --set-exit-if-changed lib test integration_test`:
  PASS, 158 files checked and zero changed.
- `flutter build windows --debug` after the correction: PASS.
- No package or lockfile change was required; Flutter SDK `integration_test`
  infrastructure was reused.

## Real Windows E2E Commands

The repeatable runner generated all credential values in process memory. Its
sanitized invocation was:

```text
integration_test/run_stage2_windows_e2e.ps1 -FlutterExecutable <installed Flutter 3.44.7 executable> -ApiPort 8815
```

It executed these logical commands with credential Dart defines redacted:

```text
integration_test/verify_stage2_runtime_guard.ps1 -ApiPort 8815
New-Stage2OracleFile -BackendContainerName testlabuz-stage2-e2e-app -DestinationPath <ephemeral system-temporary path>
flutter test integration_test/stage2_platform_management_flow_test.dart -d windows --plain-name <mutation flow> --dart-define=API_BASE_URL=http://127.0.0.1:8815/api/v1 --dart-define=STAGE2_E2E_ORACLE_PATH=<ephemeral system-temporary path> --dart-define=<credentials redacted>
docker stop testlabuz-stage2-e2e-app
docker start testlabuz-stage2-e2e-app
flutter test integration_test/stage2_platform_management_flow_test.dart -d windows --plain-name <restart persistence> --dart-define=API_BASE_URL=http://127.0.0.1:8815/api/v1 --dart-define=STAGE2_E2E_ORACLE_PATH=<ephemeral system-temporary path> --dart-define=<credentials redacted>
```

- Corrected runner end-to-end duration: PASS, 220.8 seconds.
- Full mutation flow: PASS, one named Windows integration test (2 minutes 3
  seconds reported by Flutter).
- Explicit dedicated-backend stop/start: PASS.
- Fresh Windows process restart-persistence flow: PASS, one named integration
  test (8 seconds reported by Flutter).
- Database-level restart retention assertions: `Stage2DatabasePersistence:
  PASS`.

## Stage 2 Real-Stack Scenario Matrix

### Authentication, authorization, and disclosure

- No protected Platform content before authentication: PASS.
- All twelve Platform endpoints returned the accepted unauthenticated denial:
  PASS.
- Institution Admin, Teacher, Student, and Parent were each denied on all
  twelve Platform endpoints (48 wrong-role checks): PASS.
- Active-state, Institution-state, and password-change gate precedence: PASS.
- Unknown Institution and non-admin UUIDs returned scope-safe not-found: PASS.
- Unsupported query/body/protected ownership fields returned validation errors
  and caused no mutation: PASS.
- Exact `/auth/me`, dashboard, Institution, and Admin response allowlists were
  asserted; passwords, hashes, tokens, settings internals, and ownership fields
  were absent: PASS.

### Dashboard

- Populated dashboard used authoritative values: 31 Institutions, 23 active,
  8 inactive; 31 Users, 29 active: PASS.
- Exact newest Institution order `Recent 05` through `Recent 01`: PASS.
- No billing, health, learning-activity, attention, or invented analytics:
  PASS.
- A safe loopback outage produced the real dashboard error state; restart plus
  visible Retry restored authoritative data: PASS.

### Institution list and detail

- Default ordering/page size, page navigation, and 20/50/100 page sizes: PASS.
- Case-insensitive substring search: PASS.
- Literal `%` and `_` search behavior: PASS.
- Status, type, and combined filters: PASS.
- Name/status/created/updated sorting and direction changes: PASS.
- Rapid successive search and detail-route changes did not show stale data:
  PASS.
- Direct detail route, unknown UUID, route refresh, counts, nullable fields,
  and disclosure boundaries: PASS.

### Institution create, edit, and lifecycle

- Visible create form persisted one active Institution and exactly one safe
  settings row: PASS.
- Duplicate create submission was suppressed; total increased exactly once:
  PASS.
- Unchanged edit produced the accepted no-change state and no API mutation:
  PASS.
- Changed-field edit, nullable clears, and post-save reload: PASS.
- Lifecycle cancel caused no change: PASS.
- Confirmed deactivate blocked an Institution user without deleting data:
  PASS.
- Confirmed reactivate restored access only for otherwise eligible users:
  PASS.
- Unaffected control Institution remained active and accessible: PASS.

### Institution Admin list, create, edit, and lifecycle

- Institution-scoped list, search/filter, literal wildcard, sort/direction,
  20/50/100 page sizes, and pagination: PASS.
- One Admin was created exactly once with server-owned role/Institution/status
  and mandatory first-login state: PASS.
- Duplicate login validation caused no duplicate row: PASS.
- First-login password gate, password change, old-password rejection, and
  new-password login: PASS.
- Password values were absent from API responses and persistent Flutter state:
  PASS.
- Unchanged Admin edit produced the accepted no-change error and no mutation:
  PASS.
- Admin profile edit preserved login, role, Institution, password state, and
  lifecycle state: PASS.
- Admin lifecycle cancel, deactivate/access denial, token behavior,
  reactivate, and restored eligibility: PASS.
- Non-admin target and other-Institution control rows remained unchanged: PASS.

### Session isolation

- Platform Owner logout cleared local secure-token state and protected shell:
  PASS.
- Institution Admin login exposed no prior Platform KPI/Institution/Admin data:
  PASS.
- Direct Platform URL and window-back attempts could not restore Platform
  content: PASS.
- Returning as Platform Owner performed a fresh authoritative load: PASS.

## Restart and Persistence Evidence

After the mutation flow, the dedicated Laravel app container was stopped and
started while PostgreSQL remained intact. A new Windows test process then
verified:

- exactly one edited Institution persisted in final inactive state: PASS;
- exactly one safe settings row persisted with `Asia/Tashkent`, 25 MB learning
  material limit, 15 MB submission limit, and all four educational policy
  values still unconfigured: PASS;
- exactly one edited Admin persisted, active and password-change-complete:
  PASS;
- dashboard/list/detail API behavior remained authoritative: PASS;
- inactive Institution authentication denial remained enforced: PASS;
- target settings and unaffected Institution state remained unchanged: PASS;
- no mutation was replayed or duplicated during recovery: PASS.

## Human-Observable Windows Smoke

Performer: Project owner.

UTC date: 2026-08-13.

Windows result: PASS.

The project owner truthfully attested the following human-observed results:

1. Dashboard: PASS.
2. Institution search: PASS.
3. Filters and Reset: PASS.
4. Pagination: PASS.
5. Institution details: PASS.
6. Institution validation and create: PASS.
7. Institution edit: PASS.
8. Institution lifecycle cancel/confirm: PASS.
9. Admin list and create: PASS.
10. Admin edit: PASS.
11. Admin lifecycle cancel/confirm: PASS.
12. Hot restart and persisted data: PASS.
13. Logout and protected-data absence: PASS.

Failed observations or limitations: none reported.

## Scope and Secret Review State

- Locked `docs/01-09`: unchanged.
- Accepted production backend/frontend source: unchanged.
- Verification-only assets are confined to the approved seeder, focused seeder
  test, Flutter integration test/support scripts, exact approved prompt, and
  this evidence file.
- The backend seeder SHA-256 remains
  `AC08830F7C0E323FDB2BF91CC089B8BD0A068677A97190781163BE497D023B10`
  and its focused test remains
  `A7F2D6B450EA5CCA1CCFD0ADEEAAD22757B81664ECD9AAD8DC097C7D02036760`,
  exactly matching their pre-correction snapshots: PASS. The earlier full
  backend PostgreSQL and backend quality PASS therefore remains authoritative.
- No new dependency or product behavior was introduced.
- No credential, bearer token, hash, private key, DSN, or environment dump is
  included here.
- `git diff --check`: PASS.
- Locked-doc, production-source, package-manifest, and lockfile diff check:
  PASS, no changes.
- Verification-file sensitive-pattern scan: PASS.
- PowerShell parser check: PASS, all five Stage 2 support/runner scripts.
- Exact approved prompt hash check: PASS.
- Ephemeral oracle cleanup check: PASS; no matching artifact remained in the
  system temporary directory or repository.
- Focused post-review seeder suite: PASS, 7 tests and 40 assertions.
- Focused post-review Pint check: PASS, 2 files.
- Correction-cycle diff/scope/secret inspection: PASS, 11 approved Git status
  entries and no out-of-scope path.

## Acceptance Gate

This section records the historical pre-delivery acceptance state. The current
authoritative delivery state is recorded in `Final GitHub Delivery` below.

- Automated Phase 1 verification: PASS.
- Mandatory human-observable Windows smoke: PASS.
- Historical first Phase 2 read-only acceptance gate: NOT ACCEPTED.
- Correction-cycle Phase 1 verification: PASS.
- New Phase 2 read-only acceptance gate: PASS.
- P1 findings: none.
- P2 findings: none.
- P3 findings: none.
- Read-only discipline: PASS; all 12 frozen file hashes remained unchanged and
  no content was staged throughout the gate.
- Corrected runner target/runtime boundary: PASS.
- Independent PostgreSQL oracle and exact baseline assertion coverage: PASS.
- Exact owner-approved prompt, UTC metadata, historical failed-review record,
  human smoke, scope, secret, and locked-document checks: PASS.
- Historical pre-delivery task acceptance verdict: `Accepted`; delivery was
  pending at that checkpoint.

## Final GitHub Delivery

This is the authoritative current delivery record for `S02-INT-001`.

Documentation remediation recorded at: `2026-08-13T11:36:54Z`.

### Implementation

- Branch: `task/s02-int-001-stage2-windows-e2e`.
- Accepted commit: `4f2c4a16f43a0958312441a9b8b3af6d2c9c84a6`.
- Pull request: `#40`.
- Implementation merge commit:
  `aa223890c26bb9a5f4704c7d2efe1bd92e7786e8`.
- Merge parents:
  - `31193e557c1a2be87bbe2a9deea4430c1062d4f6`.
  - `4f2c4a16f43a0958312441a9b8b3af6d2c9c84a6`.

### Delivery Bookkeeping

- Branch: `codex/s02-int-001-delivery-bookkeeping`.
- Bookkeeping commit: `90d1aaa45c20bdb8068a57f46373b8ce0760b1b5`.
- Pull request: `#41`.
- Bookkeeping merge commit:
  `f9cb4346fcab1c61f5bb43fdcda9eaedb290ee47`.
- Merge parents:
  - `aa223890c26bb9a5f4704c7d2efe1bd92e7786e8`.
  - `90d1aaa45c20bdb8068a57f46373b8ce0760b1b5`.

### Final Verified State

- Both required commits are ancestors of `origin/main`.
- Local `main` and `origin/main` were synchronized at
  `f9cb4346fcab1c61f5bb43fdcda9eaedb290ee47`.
- The working tree was clean after final delivery verification.
- `S02-INT-001` = `Accepted / PASS / Delivered`.
- All sixteen predecessors remain `Accepted / PASS / Delivered`.
- Stage 2 = `In Progress / Verified / Not Closed`.
- Stage closed = `No`.
- Next gate = separate Stage 2 Closure Review.
- Stage 3 was not started.
