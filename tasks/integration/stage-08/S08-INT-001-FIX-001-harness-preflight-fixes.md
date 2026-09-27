# Focused Fix Contract: S08-INT-001-FIX-001 — Integration Harness Preflight #1 Fixes

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-INT-001-FIX-001` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Origin | `S08-INT-001` Integration Harness Preflight #1 on audited `main` `3e54c90` — `NOT ACCEPTED` |
| Findings fixed | `PF1-P2-1` … `PF1-P2-3`, `PF1-P3-1` … `PF1-P3-8` |
| Project Owner decision | `INT-D4` = options 2 + 4 (Б + Г) (2026-09-27) |
| Area | Integration harness only (`frontend/integration_test/`, the Stage 8 seeder and its test) |
| Implementation | Claude (implementation role, as reassigned 2026-09-23) |
| Delivery | Claude opens the PR; Project Owner reviews and merges |
| Depends on | Nothing |

## 2. Goal

Close the three P2 findings and the eight run-relevant P3 findings of preflight #1, so that the
first full real-stack run produces complete evidence and cannot be silently corrupted by the shared
developer machine. No production code, API, route, schema or product behavior changes.

## 3. Scope

### Included

- `PF1-P2-1` — static pre-start configuration check of an existing stopped container, §5.1.
- `PF1-P2-2` — audited checkout: clean tree and unchanged `HEAD` at start and before PASS, §5.2.
- `PF1-P2-3` — before/after comparison for the due-time negative probes, and a second due recipient
  that proves whole-Blitz reconciliation, §5.3.
- `PF1-P3-1` — the file-race frozen check reads the File metadata, not the reused File ID, §5.4.
- `PF1-P3-2` — `start_replacement` and Resume with new keys after Close, §5.5.
- `PF1-P3-3` — container PHP input travels over stdin, never in a file, §5.6.
- `PF1-P3-4` — bounded container PHP and seeder-test execution; no busy polling, §5.7.
- `PF1-P3-5` — the lock observer reads only lock rows of `testlabuz_testing` sessions, §5.8.
- `PF1-P3-6` — exclusive use of `testlabuz_testing` during a run, §5.9.
- `PF1-P3-7` — runner and manual-smoke preparation exclude each other, §5.10.
- `PF1-P3-8` — safe fail-closed reasons from container PHP are reported, §5.11.

### Non-Goals

- Preflight #1 findings accepted without change (INT-D4): the seeder-test folder left in the private
  volume when the test is killed; the partly indirect Scheduler "invoker never called" verifier
  cases; the narrower item-ID oracle check (the seeder test covers both attacks); the recipient and
  cohort re-checks of F13 rows G and H; the verifier-only `Assert-Stage8StartReplay` helper; the
  Windows flow signing out a local desktop TestLabUz session.
- No production source change (`backend/app`, `backend/routes`, `backend/config`, migrations,
  `frontend/lib`, `pubspec`, `docker`).
- No change to existing fixture identities: new seeded rows are appended.
- No new package, framework or dependency.

## 4. Current Implementation Context (audited `3e54c90`)

- `stage8_runtime_guard.ps1:505-516` (`Initialize-Stage8Runtime`) checks name, image, command,
  platform, restart policy, auto-remove, working directory and mounts, then starts a stopped
  container. Port bindings, `Config.Env` and the network are checked only by the live guard
  (`:398-440`), after the container already serves.
- `run_stage8_windows_e2e.ps1:260-262` records `HEAD` once; the tree is never required clean and
  `HEAD` is not re-checked before `Stage8AutomatedEvidence: PASS`. The Stage 8 container bind-mounts
  the live `backend/` working tree.
- `stage8_api_scenarios.ps1:196-242`: the due Resume of #1, the due Resume of #2 and the late Submit
  take no snapshot before the request. `matrix_timeout` and `matrix_late_submit` each have one
  recipient, so whole-Blitz reconciliation (§34.1.4A revalidation "Due Resume target") is never
  exercised.
- `stage8_api_scenarios.ps1:~500-510`: the file race reads the frozen `answer.file.id`. The backend
  replaces a file answer in place (`StudentSubmissionAnswerFiles.php:128-144` refills the existing
  File row), so both branches carry the same File ID and the frozen check is vacuous in the
  write-first branch.
- `stage8_api_scenarios.ps1:551-575`: after Close only `start_normal` and the close fixture's Resume
  are probed with new keys.
- `stage8_runtime_guard.ps1:16-55` (`Invoke-Stage8ContainerPhp`) writes the program **and** the
  base64 input (the seeder input carries the password) into a container `/tmp` file; a killed
  runner leaves it behind. Every failure becomes one generic message.
- `docker exec` calls have no time limit; `stage8_oracle.ps1` `Wait-Stage8TimestampBoundary` polls
  without a pause.
- `stage8_concurrency_probe.ps1:213` reads `pg_locks where not granted` for the whole server.
- `backend/tests/TestCase.php:19-27` forces `testlabuz_testing`; another backend test run during a
  real run would wipe the Stage 8 state.
- `run_stage8_windows_e2e.ps1` and `prepare_stage8_manual_smoke.ps1` clean and reseed the same
  manifest and can run at the same time.

## 5. Exact Implementation Contract

### 5.1 `PF1-P2-1` — static pre-start configuration check

- The static configuration checks of the live guard move into one function that takes a
  `docker inspect` object: container facts, mounts, the **configured** port binding
  (`HostConfig.PortBindings`, exactly one `127.0.0.1:<ApiPort>`), the named environment values
  (`APP_ENV`, `APP_DEBUG`, `DB_CONNECTION`, `DB_HOST`, `DB_PORT`, `DB_DATABASE`,
  `PHP_CLI_SERVER_WORKERS`) and the network (`HostConfig.NetworkMode = testlabuz_default`).
- `Initialize-Stage8Runtime` runs it on an existing container **before** `docker start`. The live
  guard runs it too, plus its live-only checks (active bindings, processes, Laravel/DB identity,
  session correlation, HTTP boundary).
- A mismatch throws before any start. The environment is read only by name and never printed.

### 5.2 `PF1-P2-2` — audited checkout

- At start the runner records `HEAD` and requires `git status --porcelain --untracked-files=all --
  backend frontend docker` to be empty.
- Immediately before the `Stage8AutomatedEvidence: PASS` line it requires the same `HEAD` and the
  same empty status. Otherwise it fails as `environment/runtime defect: the audited checkout changed
  during the run` and prints no PASS.
- The evidence JSON records the audited SHA and `checkout_clean = true`.

### 5.3 `PF1-P2-3` — due-time probes compare before and after

- New oracle helper `Assert-Stage8OnlyTimeoutReconciliation -Before -After -AssessmentId`:
  - every owned table other than `assessment_attempts`, and the private blobs, are unchanged;
  - `assessment_attempts` rows of other Assessments are unchanged;
  - rows of this Blitz that were `in_progress` in `Before` with `deadline_at` at or before
    `After.observed_at` are timeout-finalized (`timed_out_finalized`, `timeout_auto_submit`,
    `finalized_at = locked_at = deadline_at`, `submitted_at = null`) and differ from `Before` only
    in `status`, `finalization_reason`, `finalized_at`, `locked_at` and `updated_at`;
  - every other row of this Blitz is unchanged.
- The due Resume of #1, the due Resume of #2 and the late Submit take `Get-Stage8Facts` immediately
  before the request and call the helper after it. The rejected key has no idempotency record.
- Seeder: a new individual Student `d_timeout_peer` (appended) becomes a second recipient of
  `matrix_timeout` with a seeded due in-progress Attempt `timeout_peer_1` (appended to the seeded
  Attempts; started at `history`, own 3-second duration). The due Resume of #1 must finalize it at
  its own deadline in the same request.
- The seeder test's matrix-timeout recipient and zero-Attempt expectations and the global candidate
  and superset expectations include the new row. Its Scheduler invocation test terminalizes
  `matrix_timeout` like the Close and monitoring fixtures before running the scanner.

### 5.4 `PF1-P3-1` — file race frozen check

- The frozen value of the file race comes from the Submit response's `answer.file.original_name`
  and `size_bytes`, matched against the `answer_pdf` and `replacement_docx` fixtures.
- In both branches the Student has exactly one File row, and its ID is the prior upload's ID. The
  File's checksum decides the branch. The misleading comment is corrected.

### 5.5 `PF1-P3-2` — replacement and Resume after Close

On the closed matrix Blitz, new-key `start_replacement` and new-key Resume of #2 each return
`409 blitz_not_active`. The existing unchanged-rows comparison covers them and their keys have no
idempotency record.

### 5.6 `PF1-P3-3` — input over stdin

`Invoke-Stage8ContainerPhp` writes only the program to the container file. The input JSON is piped
to `php` on stdin (without a byte-order mark; the PHP side strips one defensively). No input value
is ever written to a file or passed in argv.

### 5.7 `PF1-P3-4` — bounded execution

- Container PHP runs under `timeout` inside the container: default 300 s, a caller may pass a larger
  bound. Exit code 124 fails as `environment/runtime defect: Stage 8 container PHP timed out`.
- The focused seeder test in the runner runs under a 900 s `timeout`.
- `Wait-Stage8TimestampBoundary` pauses 200 ms between clock reads.

### 5.8 `PF1-P3-5` — observer scope

The observer's lock rows are limited to sessions of the current database:
`pg_locks where not granted and pid in (select pid from pg_stat_activity where datname =
current_database())`. Transaction-ID lock rows, whose `database` is null, stay included.

### 5.9 `PF1-P3-6` — exclusive test database

- New guard `Assert-Stage8ExclusiveDatabase -ClientAddress`: no `client backend` session on
  `testlabuz_testing` other than the checking session itself comes from an address other than the
  Stage 8 container (a null address, a local socket inside the PostgreSQL container, also counts as
  foreign).
- The runner calls it after the runtime guard, before the guarded Scheduler phase and before PASS.
  The manual-smoke script calls it before preparing and before the completion oracle. A foreign
  session fails as `environment/runtime defect: another client uses testlabuz_testing`.

### 5.10 `PF1-P3-7` — mutual exclusion

- Both scripts hold the named mutex `Local\TestLabUzStage8Harness` for their whole execution and
  stop immediately if it is held.
- Preparation writes the marker `%TEMP%\testlabuz-stage8-manual-smoke.pending`. Completion removes
  it after its cleanup PASS. The runner refuses to start while the marker exists, and preparation
  refuses to start a second time while it exists.

### 5.11 `PF1-P3-8` — safe failure reasons

- The container PHP wrapper catches a `RuntimeException` whose class is exactly `RuntimeException`
  and whose message matches `\A(?:Static |Unowned )?Stage 8 [^\r\n]{0,300}\z`. It prints only that
  message as JSON and exits with code 3. Every other exception keeps today's generic message.
- PowerShell reports `Stage 8 container PHP refused: <message>` after passing it through
  `Protect-Stage8Diagnostic` with every string value of the input as a secret.

## 6. Owner Procedure (`INT-D4`, option 4)

During the full Windows run and the Android manual smoke, no other Claude session works in this
repository: no branch switch, no edit, no backend test run. The executor confirms this before
starting (other local sessions are told to pause), and §§5.2 and 5.9 detect a violation.

## 7. Expected Files

```text
backend/database/seeders/Stage8E2eSeeder.php
backend/tests/Feature/Seeders/Stage8E2eSeederTest.php
frontend/integration_test/stage8_runtime_guard.ps1
frontend/integration_test/verify_stage8_runtime_guard.ps1
frontend/integration_test/stage8_concurrency_probe.ps1
frontend/integration_test/stage8_oracle.ps1
frontend/integration_test/verify_stage8_oracle.ps1
frontend/integration_test/stage8_api_scenarios.ps1
frontend/integration_test/run_stage8_windows_e2e.ps1
frontend/integration_test/prepare_stage8_manual_smoke.ps1
```

## 8. Acceptance Criteria

- [ ] A stopped container with a wrong configured binding, environment value or network is rejected before `docker start`.
- [ ] A dirty tree or a changed `HEAD`, at start or before PASS, stops the run without a PASS line.
- [ ] The three due-time probes fail on any change beyond canonical timeout reconciliation of due Attempts of their Blitz, and the due Resume of #1 finalizes `timeout_peer_1` at its own deadline.
- [ ] The file-race frozen value distinguishes the two branches; one File row with the prior ID remains in both.
- [ ] New-key `start_replacement` and Resume after Close return `blitz_not_active` and change nothing.
- [ ] No input value reaches a container file or argv.
- [ ] Container PHP and the seeder test are time-bounded; no busy polling remains.
- [ ] The observer reports no lock rows of other databases.
- [ ] A foreign `testlabuz_testing` session stops the run at the next check.
- [ ] The runner and the manual-smoke preparation cannot run together or over a pending manual smoke.
- [ ] A seeder fail-closed message reaches the operator; other failures stay generic.
- [ ] No production source change; existing fixture identities unchanged.

## 9. Focused Verification

```text
php artisan test tests/Feature/Seeders/Stage8E2eSeederTest.php   (inside the Stage 8 container)
verify_stage8_runtime_guard.ps1 -ApiPort <port>
verify_stage8_oracle.ps1, verify_stage8_concurrency_probe.ps1, verify_stage8_api_security.ps1, verify_stage8_test_files.ps1
git diff --check
```

The verifiers gain negative cases for §§5.1, 5.3 and 5.9 where they are pure. Deliberate breaks
must be caught for: the pre-start binding/environment/network checks; the audited-checkout
comparison; each allowed-column rule of §5.3; the exclusive-database filter. A development API
shakeout on the live stack (not evidence) must pass all scenarios.

## 10. Evidence Invalidation

Preflight #1 results outside this diff stay valid. Preflight #2 re-reviews this diff and the
§72 items it touches (runtime guard, cleanup/ownership, concurrency, Start/Submit matrices, secret
handling) on the new `main`.

## 11. Delivery

Branch `fix/stage8-int-001-fix-001`, PR to `main` with the verification evidence in the
description. Project Owner merges.

## 12. Planning Provenance

`S08-INT-001` preflight #1 record and Project Owner decisions `INT-D2` … `INT-D4`, in
`tasks/STAGE_08_TASK_INDEX.md` §20.
