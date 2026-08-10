# S01-INT-004 Stage 1 E2E Evidence

Date: 2026-08-10

Branch under test: `task/s01-int-004-stage1-e2e`

Pre-delivery base commit: `947bedc7d308a1d3080aee3afd828f778684ddec`

## Environment

- Docker: `Docker version 29.4.1, build 055a478`
- Docker Compose: `v5.1.3`
- PHP runtime: `PHP 8.4.24` in the Docker app container
- Laravel: `Laravel Framework 13.24.0`
- Composer: `2.10.2` in the Docker app container
- PostgreSQL: `PostgreSQL 18.4 (Debian 18.4-1.pgdg13+1)`
- Flutter: `3.44.7 stable`
- Dart: `3.12.2`
- Windows target: `windows-x64`, Microsoft Windows `10.0.19045.6466`
- Android target: `emulator-5554`, `sdk_gphone64_x86_64`, Android 16 API 36

## E2E Runtime

- Backend served from dedicated Docker app container on loopback-only `127.0.0.1:8814`.
- Backend runtime used `APP_ENV=testing`.
- Backend runtime used `DB_DATABASE=testlabuz_testing`.
- Windows Flutter E2E API base: `http://127.0.0.1:8814/api/v1`.
- Android Flutter E2E API base: `http://10.0.2.2:8814/api/v1`.
- Fixture passwords were supplied only through transient local process environment / Dart defines and are not recorded here.

## Fixture Safety

- `Stage1E2eSeeder` checks `APP_ENV=testing` before reading fixture credentials.
- `Stage1E2eSeeder` checks PostgreSQL `current_database() = testlabuz_testing` before reset/seeding.
- Wrong database guard result: PASS, seeder refused `DB_DATABASE=testlabuz`.
- Wrong environment guard result: PASS, seeder refused `APP_ENV=local`.
- Missing local password guard result: PASS, covered by `Stage1E2eSeederTest`.
- Seeder resets only the explicit `e2e_*` users and the two `E2E ... Institution` fixture institutions.

## Backend Results

- `php artisan test`: PASS, 68 tests, 1394 assertions.
- `vendor/bin/pint --test`: PASS, 77 files.
- `composer validate --strict`: PASS.
- Accepted backend role matrix: PASS via `RoleAuthorizationMiddlewareTest`, including the single-role 5 allow / 20 deny suite.
- Production role-test route hygiene: PASS.

## Frontend Results

- `flutter analyze`: PASS.
- `flutter test`: PASS, 135 tests.
- `dart format --output=none --set-exit-if-changed lib test integration_test`: PASS.
- `flutter build windows --debug`: PASS.
- `flutter build apk --debug`: PASS.

## Windows E2E Matrix

- Platform Owner -> `/platform-owner`: PASS.
- Institution Admin -> `/institution-admin`: PASS.
- Teacher -> `/teacher` desktop entry: PASS.
- Student -> `/student` desktop entry: PASS.
- Parent -> `/unsupported-device`: PASS.

## Android E2E Matrix

- Platform Owner -> `/unsupported-device`: PASS.
- Institution Admin -> `/unsupported-device`: PASS.
- Teacher -> `/teacher` mobile entry: PASS.
- Student -> `/student` mobile entry: PASS.
- Parent -> `/parent`: PASS.

## Security / Negative E2E

- All five active roles authenticate through real UI/API: PASS.
- Invalid credentials blocked with safe login UX: PASS.
- Inactive user blocked with safe login UX and no local session retained: PASS.
- Inactive institution user blocked with safe login UX and no local session retained: PASS.
- Mandatory first-login password change routes to `/change-password`: PASS.
- Direct `/teacher` navigation remains blocked before password change: PASS.
- Wrong current password handled safely: PASS.
- Valid password change reaches Teacher entry after `/auth/me` refresh: PASS.
- Old password fails after change: PASS.
- New password succeeds after change: PASS.
- Logout clears Flutter local session: PASS.
- Logout revokes the current backend Sanctum token: PASS.
- Revoked token cannot authenticate against `/auth/me`: PASS.
- Teacher A -> Teacher B same-role switch exposes only Teacher B: PASS.
- Teacher A -> Student cross-role switch exposes only Student: PASS.
- Wrong-role direct Flutter routes remain blocked: PASS.
- Unsupported role/device combinations remain blocked: PASS.

## Real E2E Commands

Commands were run with transient local secret values and are recorded here with secret inputs redacted.

- Windows: `flutter test integration_test/stage1_auth_flow_test.dart -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8814/api/v1 --dart-define=STAGE1_E2E_PASSWORD=<redacted> --dart-define=STAGE1_E2E_NEW_PASSWORD=<redacted>`: PASS.
- Android: `flutter test integration_test/stage1_auth_flow_test.dart -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8814/api/v1 --dart-define=STAGE1_E2E_PASSWORD=<redacted> --dart-define=STAGE1_E2E_NEW_PASSWORD=<redacted>`: PASS.

## Evidence Layers

- Automated real-stack E2E = PASS. Codex executed the accepted Flutter integration tests against the real Laravel/PostgreSQL backend, as recorded above.
- Human-observable manual smoke = PASS. The project owner reported and attested that the human-observable manual smoke completed successfully after the automated E2E evidence was accepted.

## Manual Smoke Verification

Performed by: Project owner

Verification type: Human-observable manual smoke

Date: 2026-08-10

Windows: PASS

Android: PASS

The owner-attested human smoke used the real accepted Stage 1 application flow against the Laravel/PostgreSQL backend and covered the Stage 1 authentication/entry behavior required for closure. Codex did not personally observe or execute these manual tests.

### Windows Manual Smoke

- Platform Owner -> Platform Owner entry: PASS.
- Institution Admin -> Institution Admin entry: PASS.
- Teacher -> Teacher desktop entry: PASS.
- Student -> Student desktop entry: PASS.
- Parent -> Unsupported device: PASS.
- Invalid credentials blocked: PASS.
- Inactive user blocked: PASS.
- Inactive-institution user blocked: PASS.
- Mandatory first-login redirect to Change Password: PASS.
- Wrong current password rejected: PASS.
- Valid password change succeeded: PASS.
- Old password rejected after change: PASS.
- New password accepted after change: PASS.
- Logout returned to login and cleared the active UI session: PASS.

### Android Manual Smoke

- Platform Owner -> Unsupported device: PASS.
- Institution Admin -> Unsupported device: PASS.
- Teacher -> Teacher mobile entry: PASS.
- Student -> Student mobile entry: PASS.
- Parent -> Parent mobile entry: PASS.
- Authentication/session behavior manually exercised during the Android smoke: PASS.

## Acceptance Gate

- Phase 2 read-only acceptance gate: PASS.
- Blocking findings: none.
- Current evidence state for Stage 1 closure reassessment: automated real-stack E2E = PASS; human-observable manual smoke = PASS.

## Known Non-Blocking Limitations

- Host PHP lacks the PostgreSQL PDO driver, so backend commands were run inside the accepted Docker PHP runtime.
- The default `flutter` on PATH points to Flutter 3.41.7 / Dart 3.11.5, which cannot satisfy the accepted `sdk: ^3.12.2` constraint. Frontend verification used the already-installed FVM Flutter 3.44.7 / Dart 3.12.2 SDK.

No passwords, bearer tokens, password hashes, private keys, or environment dumps are included in this evidence.
