# S03-INT-002 Stage 3 Windows Real-Stack E2E Evidence

Automated evidence recorded at: `2026-08-20T10:19:25Z`.

Focused oracle correction rerun recorded at: `2026-08-20T11:36:33Z`.

Branch under test: `task/s03-int-002-stage3-windows-e2e`

Pre-delivery base commit: `0d96467587cfccb134df51623c165fc45cc54de4`

Phase 1 automated verification: PASS.

Mandatory project-owner Windows smoke: PASS (`Project Owner`, `2026-08-20`
UTC).

Phase 2: PASS at `2026-08-20T11:40:24Z` (`P1=0`, `P2=0`, `P3=0`).

This is the pre-acceptance Phase 1 record. It contains no delivery claim and
does not mark Stage 3 closed.

## Git and Predecessor Preflight

- Approved origin: `https://github.com/Shoxrux2017/testlabuz.git`: PASS.
- Clean synchronized local `main` and `origin/main` at the recorded base before
  activation: PASS.
- GitHub CLI authenticated as the expected repository owner and no open pull
  request existed for this task at preflight: PASS.
- Stage 2 remained closed: PASS.
- `S03-INT-001`, `S03-BE-001..007`, and `S03-FE-001..009` were all
  `Accepted / PASS / Delivered`: PASS, 17 predecessor rows.
- Only the `S03-INT-002` index row was activated as
  `In Progress / Not started / Not started`; the detailed task remains
  `Approved`: PASS.
- Stage 3 remains open and Stage 4 remains not started.
- The owner-prepared task and prompt were copied byte-for-byte from the
  immutable external queue: PASS.
- Task SHA-256:
  `8708A24DC732CE413896BA5DA18BE029306B962F6FCCB0E32DC88C3524FA5625`.
- Prompt SHA-256:
  `B578B16F9941240F142C3709624325388B60D446236E181479A31B48AF2E83D4`.
- The external queue still contains exactly its 20 expected files; its task
  and prompt hashes remain the values above: PASS.

## Environment

- Host: Microsoft Windows `10.0.19045`, Windows x64 target.
- Docker: `29.4.1`, build `055a478`.
- Docker Compose: `v5.1.3`.
- Dedicated PHP: `8.4.24`.
- Laravel: `13.24.0`.
- Composer: `2.10.2`.
- PostgreSQL client/server family: `18.4`.
- Flutter: `3.44.7 stable`.
- Dart: `3.12.2`.
- Git: `2.54.0.windows.1`.
- GitHub CLI: `2.94.0`.
- The already-installed Flutter 3.44.7 toolchain was used because it satisfies
  the repository Dart SDK constraint.

## Dedicated Runtime and Database Safety

- Exact application container: `testlabuz-stage3-e2e-app`.
- Exact loopback binding: container `8000/tcp` published once to
  `127.0.0.1:8816`.
- Constructed API base: `http://127.0.0.1:8816/api/v1`; the runner accepts only
  a port and cannot accept an arbitrary URL.
- `APP_ENV=testing`: PASS.
- `DB_CONNECTION=pgsql` with `pdo_pgsql` loaded: PASS.
- `DB_HOST=postgres`: PASS.
- `current_database()=testlabuz_testing`: PASS.
- Approved PostgreSQL container/service: `testlabuz-postgres-1` on
  `testlabuz_default`: PASS.
- Protected `/api/v1/auth/me` returned the expected unauthenticated boundary
  before fixture mutation or product login: PASS.
- Fail-closed guard matrix: PASS; 14 malformed/non-loopback targets, 4 invalid
  runtime identities, and 1 valid-looking but unbound loopback port were
  rejected; only the exact approved runtime was accepted.
- No ordinary development, external, or production API/database was seeded or
  reset.

## Guarded Fixture World

- `Stage3E2eSeeder` independently refuses a non-testing environment, any
  database other than `testlabuz_testing`, and each missing transient
  credential input before mutation: PASS.
- Four distinct credentials are generated in process memory for
  password-complete actors, first-login actors, newly created accounts, and
  changed passwords. Values are not hardcoded, printed, returned, or recorded.
- Fixture ownership uses deterministic UUIDs plus an enumerated manifest with
  exact Institution, login, role, and ownership expectations. Prefix matching
  alone is never accepted as ownership: PASS.
- Reserved Institution and User collision refusal before mutation: PASS.
- Reset scope is limited to explicitly owned Stage 3 fixture rows in
  foreign-key-safe order. There is no truncate, global sequence reset,
  constraint disabling, or hard deletion of unrelated rows: PASS.
- Seeder executed successfully twice before the product flow: PASS.
- Focused seeder suite: PASS, 10 tests and 58 assertions. It covers all safety
  guards, exact fixture state, repeatability, reserved cleanup for all three
  UI-created roles, collision refusal, and unrelated-row preservation.
- Four deterministic Institutions exist: target active, foreign active,
  inactive, and separate active all-zero Institution.
- The fixture includes target/foreign/inactive/empty Institution Admins,
  first-login Admin, Platform Owner and Teacher/Student/Parent wrong-role
  actors, active/inactive role baselines, 24 pagination Users, literal `%`,
  `_`, and `!` search fixtures, deterministic timestamps/ties, and three exact
  unused UI-create login slots.
- Initial target totals are 9 Teachers, 9 Students, and 9 Parents, including
  active and inactive accounts. The separate Institution baseline is 0/0/0.
- Target educational settings begin unconfigured with initialized
  `Asia/Tashkent`, 25 MB, and 15 MB values; target categories begin empty.
- Foreign settings/categories are distinct and configured; they remain an
  isolation oracle throughout the run.
- Two seeded lifecycle-target token rows are present for byte-for-byte command
  preservation checks; no plaintext token is seeded or exposed.
- No Group, relationship, learning, result, or history record was invented.

## Independent PostgreSQL Oracle

After the second guarded seed and before any Stage 3 product endpoint request,
the runner created a read-only PostgreSQL oracle in the system temporary
directory. It established:

- exact target 9/9/9 and separate 0/0/0 Dashboard totals;
- default User page 1/page 2 identities, ranges, order, and total;
- page sizes 20/50/100;
- role, status, combined, name, login, email, phone, case-insensitive, literal
  `%`, `_`, and `!` search results;
- every allowed sort field in both directions with deterministic UUID ties;
- exact target, foreign, and empty Institution profiles;
- exact target/foreign/empty settings and category baselines;
- token-row metadata without token value/hash; and
- the explicit table/target-exclusion manifest used by the frozen unrelated-
  state oracle.

The expectations were not manufactured from Dashboard, User, profile,
settings, or category product endpoints. The oracle schema was strictly
validated by the Windows test. Its temporary file was removed in `finally` and
no oracle file exists in the repository: PASS.

Immediately after that safe oracle and still before any Stage 3 product
endpoint, the runner persisted a second baseline only inside the dedicated
container. It canonicalized every persisted column, in deterministic primary-
key/order-key order, for `institutions`, `users`, `institution_settings`,
`institution_understanding_categories`, and `personal_access_tokens` outside
the intentional mutation targets. The exact exclusions are:

- the target Institution row, target settings row, and target category rows;
- the eight fixture actors whose login/profile/lifecycle state the flow
  intentionally exercises;
- the three exact reserved UI-created User login slots; and
- authentication-owned token rows for those exercised actors, except that the
  two seeded lifecycle-preservation rows remain included and frozen.

All other rows and all their columns are included. The baseline bytes are held
in a mode-`0600` container `/tmp` file, never copied into the host oracle,
console, or evidence. Exact byte comparisons passed after the mutation flow
and again after backend restart plus the fresh persistence process. The runner
removed the baseline in `finally`; explicit host/container cleanup checks found
zero temporary oracle/snapshot files: PASS.

## Automated Quality Results

### Backend

- Full `php artisan test` in the dedicated Docker PHP/PostgreSQL runtime:
  PASS, 237 tests and 15,414 assertions.
- Focused `Stage3E2eSeederTest`: PASS, 10 tests and 58 assertions.
- `vendor/bin/pint --test`: PASS, 173 files.
- `composer validate --strict`: PASS.
- No additional configured backend static-analysis command was found.

### Flutter and Windows

- `flutter pub get`: PASS; existing lockfile/dependencies remained unchanged.
- `flutter analyze`: PASS, no issues.
- `flutter test`: PASS, 795 tests.
- `dart format --output=none --set-exit-if-changed lib test integration_test`:
  PASS, 270 files checked, zero changed.
- `flutter build windows --debug`: PASS; Windows x64 debug executable built.
- PowerShell parser: PASS for all five Stage 3 `.ps1` files.
- Runtime guard matrix: PASS with the counts recorded above.
- Focused manual-smoke working-directory harness check: PASS. A parser/source-
  order assertion and PowerShell path-resolution probe from both the repository
  root and `C:\Windows` proved that the script resolves
  `G:\project\testlabuz\frontend`, finds its `pubspec.yaml`, enters that
  directory for the Flutter invocation, and restores the caller directory.
  The Windows application was not launched by this focused check.
- Focused correction checks: PowerShell parser PASS for all five Stage 3
  scripts; one-file Dart non-writing format PASS; `git diff --check`, exact
  12-path scope allowlist, sensitive-value scan, trailing-whitespace scan, and
  temporary artifact cleanup PASS.
- Full backend/frontend suites and the standalone Windows build were not
  repeated for this focused oracle correction; the existing PASS results above
  remain the evidence for those unchanged gates.

## Real Windows Runner

Sanitized invocation:

```text
integration_test/run_stage3_windows_e2e.ps1 -FlutterExecutable <installed Flutter 3.44.7 executable> -ApiPort 8816
```

The runner generated credentials only in process memory and passed redacted
Dart defines to the child process. It then performed:

1. runtime guard matrix and exact runtime assertion;
2. two guarded seeds;
3. pre-endpoint independent PostgreSQL oracle creation;
4. pre-run frozen unrelated-state baseline capture;
5. one real Windows mutation-flow process with four command-local token-row
   comparisons;
6. post-run frozen unrelated-state comparison;
7. exact dedicated backend stop/start without PostgreSQL reset;
8. one fresh real Windows persistence process;
9. independent post-restart database assertions;
10. post-restart frozen unrelated-state comparison; and
11. temporary oracle/snapshot/credential cleanup in `finally`.

The first two focused rerun attempts stopped fail-closed before any product
flow because the completed Project Owner smoke had left its target profile edit
and three created smoke accounts in the dedicated fixture world. Read-only
identity/tenant/role inspection confirmed only those owned smoke rows. A
bounded fail-closed recovery normalized them to the already approved manifest
post-flow name and three reserved UI-create slots; the guarded seeder then
performed its normal foreign-key-safe reset. The Project Owner PASS evidence
was preserved and the manual smoke was not repeated.

Results:

- `Stage3Safety`: PASS.
- `Stage3Seeder`: PASS, two consecutive guarded runs.
- `Stage3IndependentOracle`: PASS.
- Frozen unrelated-state pre-run baseline: SAVED.
- Mutation Windows integration test: PASS, 1 test, Flutter-reported 2 minutes
  31 seconds.
- `Stage3WindowsMutationE2E`: PASS.
- Frozen unrelated-state post-run byte comparison: PASS.
- `Stage3BackendRestart`: PASS.
- Fresh-process persistence Windows integration test: PASS, 1 test,
  Flutter-reported 9 seconds.
- `Stage3WindowsPersistenceE2E`: PASS.
- `Stage3DatabasePersistence`: PASS.
- Frozen unrelated-state post-restart byte comparison: PASS.
- Host/container temporary oracle and snapshot cleanup: PASS, zero files.

The application boundary was the production app entry, real visible Flutter
UI/Semantics, Riverpod/session/router, real repositories/DTOs/Dio interceptor,
Laravel middleware/actions/resources, real Sanctum tokens, and PostgreSQL.
There was no mocked repository/HTTP, injected session, direct Flutter database
write, production test route, or authentication bypass.

## Mandatory Scenario Matrix

Each group below has an explicit automated verdict. “Real stack” identifies
observable Windows/API/PostgreSQL coverage; deterministic suites supply cases
that have no faithful Windows gesture or are safer at the accepted component
boundary.

### 10.1 Institution Admin Shell and Session — PASS

- Real UI login, `/auth/me`, canonical Dashboard entry, exact navigation,
  User route selection, Windows navigation/back, identity/Institution context,
  fresh session, and immediate logout data removal: PASS.
- Direct-entry/restart semantics and compact/wide layout: PASS across real
  Windows and deterministic router/widget coverage.
- Browser reload/forward and Institution Admin mobile/web denial have no
  equivalent Windows gesture and remain PASS in deterministic route tests.

### 10.2 Dashboard — PASS

- Target 9/9/9 and separate eligible Institution 0/0/0 baselines: PASS.
- Deterministic partial-zero state: PASS.
- Only Teacher/Student/Parent total blocks are exposed; no active/inactive
  split or unrelated metric block: PASS.
- Creating Teacher, Student, and Parent changed totals exactly
  `9/9/9 -> 10/9/9 -> 10/10/9 -> 10/10/10`: PASS.
- Lifecycle deactivate/reactivate left all totals at 10/10/10: PASS.
- Refresh and navigation freshness: PASS.

### 10.3 Institution Profile — PASS

- Exact own profile and read-only type/status: PASS.
- Visible edit of allowed fields and nullable phone/description clears: PASS.
- Cancel, changed-only/no-change/no-request behavior: PASS across real flow and
  deterministic tests.
- Protected ownership/settings/lifecycle fields and foreign Institution
  preservation: PASS.
- Reload and post-restart server authority: PASS.

### 10.4 User List — PASS

- Own Teacher/Student/Parent boundary; page 1/2 at 20; page sizes 20/50/100;
  truthful metadata/ranges; Previous/Next: PASS.
- Role/status/combined filters and global/filtered empty behavior: PASS.
- Name/login/email/phone, case, literal `%`, `_`, and `!` searches: PASS.
- All allowed sorts/directions and deterministic ties: PASS against the
  independent oracle.
- Institution Admin, Platform Owner, and foreign rows absent: PASS.
- Rapid-query stale suppression and public resource allowlist: PASS across
  real-stack assertions and deterministic tests.

### 10.5 User Detail — PASS

- List-row and direct UUID route, exact public fields/nulls/status/first-login/
  timestamps: PASS.
- Unknown, foreign, own Institution Admin, and Platform Owner UUIDs returned
  scope-safe not-found: PASS.
- Rapid-target/reload safety and protected-data non-disclosure: PASS.

### 10.6 User Creation and First Login — PASS

- Teacher, Student, and Parent were each created exactly once through the real
  UI with server-owned Institution/creator/default state: PASS.
- Form role allowlist, validation, cancel, duplicate-login, duplicate-submit
  protection, and no implicit relationship/group/settings/learning row: PASS
  across real-stack postconditions and deterministic tests.
- List/detail/dashboard invalidation: PASS.
- Each new account reached mandatory password change; the change succeeded,
  old credential failed, new credential succeeded, and the correct device/role
  entry resumed. Parent correctly reached the Windows unsupported-device
  boundary: PASS.
- No credential or hash was returned, logged, or evidenced: PASS.

### 10.7 User Edit and Lifecycle — PASS

- Visible full-name/email/phone edit with nullable clears; protected fields,
  cancel, changed-only, and no-change semantics: PASS.
- Body-less active-to-inactive, repeated inactive no-op, inactive-to-active,
  and repeated active no-op commands: PASS.
- Four command-local checks covered active-to-inactive, repeated inactive
  no-op, inactive-to-active, and repeated active no-op. Each independently
  captured exactly two rows immediately before its command and compared the
  complete deterministic persisted-column snapshot immediately afterward:
  `id`, tokenable type/id, name, token field, abilities, last-use/expiry, and
  creation/update timestamps. All four byte-for-byte comparisons: PASS.
- Snapshot contents, token fields, hashes, and comparison digests were never
  printed, returned to Flutter, copied to the host oracle, or evidenced. Only
  sanitized action verdicts were accepted: PASS.
- A real retained token was blocked while inactive and resumed only otherwise
  authorized access after activation: PASS.
- A separately revoked token stayed unauthorized and was not restored: PASS.
- Activation created/restored/rotated/deleted no token and did not alter
  password, first-login, or last-login state: PASS.
- Dashboard totals remained 10/10/10; every non-excluded frozen row/column in
  the five named Stage 3 domain/auth tables remained byte-identical: PASS.
- Relationship/history preservation is not applicable because no predecessor
  fixture existed; none was invented.

### 10.8 Assessment Settings — PASS

- Initial unconfigured resource/form and one complete seven-field PUT through
  real UI: PASS.
- Persisted values include threshold `12.5`, synchronized timer, automatic
  Student release, with-student Parent release, `Asia/Tashkent`, and 24/14 MB:
  PASS.
- Threshold 0/100/decimal, all release/timer modes, IANA/offset validation,
  upload bounds, non-editable fixed rules/maxima, protected-field rejection,
  cancel/no-change/one-PUT/no-retry, and failure states: PASS in deterministic
  frontend/backend suites.
- One-row/updater invariant, foreign preservation, and absence of unrelated
  rewrites: PASS.

### 10.9 Understanding Categories — PASS

- Initial empty state, fixed code/label/order, and non-numeric Not completed:
  PASS.
- Exact five-row 0–100 save/reload through real UI: PASS; persisted lower
  bounds are 91, 71, 41, 1, and non-numeric.
- Boundary/range variants and gap/overlap/decimal/duplicate/missing/unknown/
  order/label validation: PASS in deterministic frontend/backend suites.
- Cancel/no-change/one-PUT/no-retry, atomic invalid rollback, updater/exactly
  five/concurrency, foreign preservation, and no unrelated rewrite: PASS.

### 10.10 Authorization, Input, and Disclosure — PASS

- All 13 Stage 3 endpoint families returned `401` unauthenticated: PASS.
- Platform Owner, Teacher, Student, and Parent were denied on all 13 families:
  PASS, 52 wrong-role checks.
- First-login, inactive User, and inactive Institution precedence: PASS.
- Safe User-target `404` cases and unknown/protected query/body `422` with no
  mutation: PASS.
- Client `institution_id` never expanded scope: PASS.
- Exact allowlists excluded credentials/hashes/tokens/creator/foreign tenant/
  relationship/answer/score/result/protected fields: PASS.

### 10.11 Mutation Uncertainty and Stale Isolation — PASS

- Deterministic Flutter suites prove one request, duplicate-intent blocking,
  no automatic replay, at-most-one read-only reconciliation, unconfirmed
  reconciliation semantics, direct-response-only confirmation, and stale
  target/query/session/account-switch suppression for every mutation surface:
  PASS.
- Real Windows flow safely stopped the dedicated backend during a mutation,
  observed explicit unknown outcome, made no replay POST, restarted the
  backend, and recovered via read-only reload: PASS.

### 10.12 Cross-Role Session Isolation — PASS

- A loaded Institution Admin session was logged out and replaced by a foreign
  Institution Admin account; no target Dashboard/profile/User/settings/
  category/form/error state remained or flashed: PASS.
- Teacher/Student/Parent/Platform Owner direct Institution Admin route denial,
  back behavior, token-version invalidation, and returning Admin fresh-load
  semantics: PASS across real protected-route probes and deterministic route/
  session suites.

### 10.13 Restart and Persistence — PASS

- After committed mutations, only `testlabuz-stage3-e2e-app` was restarted;
  PostgreSQL was not reset: PASS.
- A new Windows process logged in and observed the edited profile, all three
  created Users, lifecycle User, Dashboard 10/10/10, seven settings fields,
  and five categories: PASS.
- No mutation replay occurred during restart/bootstrap: PASS.
- Independent DB assertions proved target persistence. The post-restart frozen
  comparison separately proved unchanged full-row content for every included
  foreign/empty/inactive/manual row plus both seeded lifecycle token rows:
  PASS.

## Tenant, Token, Disclosure, and Mutation Oracles

- Target and foreign account switches always loaded only their own profile,
  settings, categories, and Users: PASS.
- Foreign Institution profile/settings/categories and same-looking Users were
  unchanged: PASS.
- The separate empty Institution remained free of Teacher/Student/Parent
  records: PASS.
- All three UI-created accounts exist once in the target Institution, retain
  server-owned roles/default state, and add no implicit domain relationship:
  PASS.
- Seeded token-row metadata remains present; all four lifecycle commands
  preserved every persisted column of both seeded rows byte-for-byte, the
  whole-run/restart frozen comparison preserved those rows again, account-state
  middleware blocked retained-token access while inactive, and revocation
  remained final: PASS.
- Direct response envelopes/messages were required to confirm mutations.
  Unknown outcomes were not converted into success by matching current state:
  PASS.
- Sensitive response/UI/log/evidence scan found no credential value, password
  hash, bearer token, private key, DSN, creator data, or foreign payload: PASS.

## Human-Observable Windows Smoke

Status: PASS.

- Executor: `Project Owner`.
- UTC date: `2026-08-20`.
- Environment: `Windows / 127.0.0.1:8816 / testlabuz_testing`.
- Functional application problems: none.

| Group | Result |
|---:|---|
| 1. Shell/session | PASS |
| 2. Dashboard | PASS |
| 3. Institution profile | PASS |
| 4. User list/detail | PASS |
| 5. User creation and first login | PASS |
| 6. User edit/lifecycle | PASS |
| 7. Assessment settings | PASS |
| 8. Understanding categories | PASS |
| 9. Backend restart persistence | PASS |
| 10. Logout/account switch | PASS |

The only observed launch issue was in the harness, not the application. The
documented repository-root command completed the guarded seed and then Flutter
exited with `No pubspec.yaml file found`; invoking the same script from
`frontend` launched the application successfully. The harness now derives the
`frontend` directory from `$PSScriptRoot` and wraps the Flutter invocation in a
balanced `Push-Location`/`Pop-Location`, so caller location is irrelevant. No
additional project-owner smoke was requested and the Windows application was
not launched again.

No Codex self-attestation was substituted for this project-owner report.

## Frozen Phase 1 File Manifest

These are the final pre-Phase-2 SHA-256 values for all changed files except this
evidence file. Embedding this file's own digest in itself is self-referential;
its digest is frozen externally with the complete Phase 1 manifest before
Phase 2.

| File | SHA-256 |
|---|---|
| `backend/database/seeders/Stage3E2eSeeder.php` | `60D782F02A89BDB29EF570A3B785390686642B75694F63E466B4AB54F05A9AAF` |
| `backend/tests/Feature/Seeders/Stage3E2eSeederTest.php` | `D4B4BCD2B4B046BC5DB49897BF684F07AD5074A4A0A78C8AF73EDC9F0B60B581` |
| `frontend/integration_test/prepare_stage3_manual_smoke.ps1` | `8390ED3424A0B5BE8D46159B3586A9F163354248E1FADD8D25F8CE927250EA5C` |
| `frontend/integration_test/run_stage3_windows_e2e.ps1` | `459C704B4975BDFAC1FB2E500D96A88AB81A83024E3D5EADD45F1032AFD1A0BC` |
| `frontend/integration_test/stage3_institution_administration_flow_test.dart` | `3568AF297B0F86B2FE6D62E6B0537DD2BC3CD3176FCD847F5AA01C47E1AAEFDA` |
| `frontend/integration_test/stage3_oracle.ps1` | `4EC06A01045C22A7C76DE52D368A8D152EDC7523B4AE9B26D001357F60FAEFBB` |
| `frontend/integration_test/stage3_runtime_guard.ps1` | `D26F3DC8D13AB3B5257F7CE71DE5283AEC136F2C749C9B94678A73D3B4AB7C1C` |
| `frontend/integration_test/verify_stage3_runtime_guard.ps1` | `8FD14799F3CFA3C30573895A0D32B4E8408EF8E6CC6A9D47BC520D6F4D844B26` |
| `tasks/integration/stage-03/S03-INT-002-CODEX-PROMPT.md` | `B578B16F9941240F142C3709624325388B60D446236E181479A31B48AF2E83D4` |
| `tasks/integration/stage-03/S03-INT-002-stage-03-windows-real-stack-e2e-verification.md` | `8708A24DC732CE413896BA5DA18BE029306B962F6FCCB0E32DC88C3524FA5625` |
| `tasks/STAGE_03_TASK_INDEX.md` | `E8E278743507B91982938FCC778D38AA897D8A48ABA2402E33BE3AF8EA4A46F7` |

## Scope, Secret, and Acceptance State

- Locked `docs/01-09`: unchanged.
- Production `backend/app` and `frontend/lib`: unchanged.
- Package manifests and lockfiles: unchanged.
- No third-party E2E framework or product test hook was added.
- Verification changes are limited to the approved seeder/test, six focused
  integration assets, exact owner task/prompt, this evidence, and the single
  index activation row.
- No predecessor product behavior was repaired or changed.
- `git diff --check`: PASS.
- Final changed-path allowlist: PASS, 12 approved paths and no locked doc,
  production source, package manifest, or lockfile change.
- Task/prompt byte and SHA-256 verification: PASS.
- External queue file count and task/prompt immutability: PASS.
- Sensitive-pattern scan, Stage 2 stale-reference scan, trailing-whitespace
  scan, and temporary-oracle cleanup: PASS.
- The focused harness, diff, scope, hash, and secret checks passed again at the
  Phase 1 freeze.
- P1 findings: 0.
- P2 findings: 0.
- P3 findings: 0.
- Acceptance verdict: PASS at `2026-08-20T11:40:24Z`.

## Non-Blocking Limitations

- Windows has no browser reload/forward gesture and cannot truthfully
  impersonate mobile/web surfaces; accepted deterministic router/widget tests
  cover those boundaries.
- No predecessor Group, relationship, learning, result, or history fixture
  exists in this Stage 3 slice. The verification does not invent Stage 4 or
  learning-domain data merely to claim preservation coverage.
- Project-owner observation passed; no additional manual run was performed
  after the working-directory-only harness fix.

## Stage Boundaries

```text
Stage 3 was NOT marked Closed by this task.
Stage 4 was NOT started.
Next action after acceptance: Run the separate Stage 3 Closure Review.
```
