# Codex Execution Prompt — S03-INT-002

Execute exactly one approved task:

`S03-INT-002 — Stage 3 Windows Real-Stack End-to-End Verification`

Repository: `G:\project\testlabuz`

Remote: `https://github.com/Shoxrux2017/testlabuz.git`

Authority task:

`tasks/integration/stage-03/S03-INT-002-stage-03-windows-real-stack-e2e-verification.md`

Branch: `task/s03-int-002-stage3-windows-e2e`

Read the detailed task completely. Do not implement or repair product behavior.
Do not close Stage 3 or start Stage 4.

## Mandatory Authority and Dependency Gate

Read root/backend/frontend AGENTS, detailed task, README/Stage 3 index,
S03-INT-001, all accepted Stage 3 detailed contracts, relevant docs 01–09,
current implementation/tests/integration assets/Git/origin state.

The task preparation snapshot was
`origin/main = 3d6131c55c4923a3bbf3649bc762f7e836610be6` on `2026-08-14`, when
S03-INT-001 and BE001–BE007 were delivered but FE001–FE009 were not. This is
historical planning context only. Execution must use and record current
synchronized `origin/main` and must not claim readiness from the snapshot.

Prove every predecessor is `Accepted / PASS / Delivered`:

```text
S03-INT-001
S03-BE-001..S03-BE-007
S03-FE-001..S03-FE-009
```

Also prove Stage 2 closed, approved origin, clean synchronized main, and only
the owner-prepared S03-INT-002 task/prompt additions. Create required branch.
No commit/push before Phase 2.

Stop on missing/undelivered predecessor or product-contract contradiction.
In particular, do not repair an older FE contract in this integration task.
Every delivered Stage 3 mutation contract must already agree that exact direct
response is the only causal success proof and a reconciliation GET is current-
state-only, never mutation-success proof.

## Dedicated Runtime and Testing Database Safety

Use exactly the dedicated container:

```text
testlabuz-stage3-e2e-app
```

The runner accepts only `-ApiPort` and constructs exactly
`http://127.0.0.1:<port>/api/v1`; never accept an arbitrary API URL. Before
fixture mutation, login, Flutter launch, or any Stage 3 product endpoint
request, prove:

```text
exact running container identity
exact single 127.0.0.1:<port> publish binding
APP_ENV = testing
DB_CONNECTION = pgsql with pdo_pgsql loaded
current_database() = testlabuz_testing
resolved DB server belongs to the inspected approved local Docker PostgreSQL
container/service and expected Docker network, not an external host
served protected /api/v1 boundary
```

Create a fail-closed runtime guard plus a test matrix for malformed/non-loopback
targets, wrong/unbound port, wrong/stopped/ambiguous container or binding, wrong
environment/database/driver/DB server boundary, unrelated server, and the one
exact accepted runtime.

Create guarded repeatable `Stage3E2eSeeder` only for an enumerated deterministic
UUID/login/dependency manifest under reserved `E2E S03` / `e2e_s03_` names.
Prefix alone is not ownership. Refuse an environment/database/credential/
manifest mismatch before mutation. Include exact unused UI-create login slots.
Never truncate, reset globally, disable constraints, or delete unrelated Stage
1/2/manual/future data. Seed twice and prove logical repeatability/unrelated-row
preservation with focused tests.

Generate distinct credentials through transient local input only. Never
hardcode, print, commit, log, screenshot, return, or evidence them. Any
temporary credential artifact stays outside the repository and is removed in
`finally`.

After the second seed and before any Stage 3 product endpoint call, generate a
guarded read-only PostgreSQL oracle in the system temporary directory. It must
independently establish Dashboard totals/zero baseline, User-list identities/
order/filter/sort/pagination, and target/foreign settings/category/User/token/
unrelated snapshots. Never derive an expectation from the same product
endpoint later asserted. The oracle contains no credential/token/hash/private
payload and is removed in `finally`.

## Real Stack Only

Use real Flutter Windows UI, Riverpod/session/router/repositories/Dio, Laravel
API/middleware/Sanctum, and PostgreSQL. No fake/mock HTTP/repository/session,
provider injection, web/widget substitute, production test hooks, or direct DB
writes from Flutter.

Allowed assets are the focused Windows integration test and E2E-only support,
`run_stage3_windows_e2e.ps1`, `prepare_stage3_manual_smoke.ps1`, Stage 3 runtime
guard/guard verification/PostgreSQL oracle scripts, guarded seeder and focused
tests, sanitized evidence, the Phase 1 S03-INT-002 index state, and post-PASS
bookkeeping. Keep responsibilities focused; do not create one God integration
file or parallel product client. Do not change production code to fix findings.

## Mandatory Scenario Groups

Run and record every detailed-task group:

1. shell/navigation/session/device routing;
2. exact three Dashboard totals and refresh/invalidation: create changes only
   the created role total once; activate/deactivate changes no total;
3. profile view/edit/null/no-change/protected fields;
4. User list search/filter/sort/pagination/stale response;
5. User detail/direct/safe-not-found/disclosure;
6. create Teacher/Student/Parent and first-login password change;
7. User edit/activate/deactivate/idempotency, byte-for-byte token-row
   preservation, inactive login/retained-token denial, and retained-token
   otherwise-authorized resumption after reactivation without token restore;
8. assessment settings unconfigured/configured/validation/fixed attempts/IANA/
   upload/history boundary;
9. categories unconfigured/valid/invalid/atomic/foreign/history boundary;
10. authorization/input/tenant/disclosure matrix;
11. mutation direct-success-only/no-replay/current-state-only reconciliation/
    stale isolation;
12. cross-role logout/account-switch isolation;
13. Laravel+Flutter restart persistence without mutation replay.

Use visible UI actions. Direct API/DB queries only as independent sanitized
oracles where UI cannot prove a security/persistence fact.

For every Stage 3 POST/PATCH/PUT, only the exact direct endpoint status,
envelope, message, and resource required by its accepted contract may confirm
success. At most one allowed reconciliation GET may publish current server
state, but it remains explicitly unconfirmed even on an exact match. Never
replay a mutation or turn a matching GET into causal success.

The Dashboard has no active/inactive split: each of Teachers, Students, and
Parents is one total including both states. Use a separate eligible active
Institution Admin in an active Institution with no managed Users for all-zero
behavior; never invent a no-Institution Institution Admin.

Lifecycle never revokes, rotates, deletes, creates, or restores token rows.
While inactive, login and retained-token protected access fail. After
reactivation, a retained still-valid token may resume only otherwise-authorized
access; a separately logged-out/revoked token is not restored. Prove token-row
byte equality in command-local before/after snapshots. Run protected access
probes outside those windows so authentication-owned `last_used_at` behavior is
not falsely attributed to lifecycle.

## Required Quality Gates

Run backend tests inside the dedicated Docker PHP runtime against PostgreSQL
`testlabuz_testing`. Do not substitute host PHP without `pdo_pgsql`, SQLite, or
an in-memory database.

Run all backend tests/checks capable of migrating/resetting the testing database
before the final two seeds, oracle creation, and Windows flow. If such a check
is repeated during Phase 1, regenerate the guarded baseline and oracle.

Backend logical commands:

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

Run the real Windows integration test explicitly against the dedicated backend
through:

```text
integration_test/run_stage3_windows_e2e.ps1 \
  -FlutterExecutable <approved-flutter-executable> \
  -ApiPort <dedicated-loopback-port>
```

The runner must guard first, seed twice, create the independent oracle, run the
complete Windows mutation flow, restart only the exact dedicated backend
without resetting PostgreSQL, launch a fresh Windows persistence test process,
and clean temporary artifacts in `finally`.

Also run focused seeder/runtime-guard tests, PowerShell parser checks, prompt
byte/hash verification, `git diff --check`, changed-asset sensitive-pattern
scan, and non-writing scope checks proving no locked docs, production source,
package manifest, or lockfile changed. Run all additional configured gates.
Any required failure blocks acceptance.

## Human Windows Smoke

Obtain truthful project-owner/operator PASS for shell, dashboard, profile,
User list/detail/create/first-login/edit/lifecycle, settings, categories,
reload/restart, logout/account switch. Record role, UTC date, environment, and
group PASS/FAIL without secrets.

Codex cannot self-attest or infer human observation from automation. After all
automated Phase 1 work and the runnable smoke checklist are ready, pause with:

```text
EXECUTION PAUSED: AWAITING PROJECT-OWNER WINDOWS SMOKE
```

This is not Phase 2 and not `NOT ACCEPTED`. Continue only after the owner or an
authorized operator supplies grouped PASS/FAIL. A FAIL blocks. If attestation
is still missing when acceptance is requested, classify P2 → `NOT ACCEPTED`.

## Evidence

Create:

`tasks/integration/stage-03/S03-INT-002-stage-03-e2e-evidence.md`

Before Phase 2, include and freeze: audited base, branch, changed-file list and
SHA-256 hashes, runtime/Windows versions, exact container/binding/environment/
database guard matrix, seed repeatability/ownership, independent pre-endpoint
PostgreSQL oracle, commands/counts, every scenario, security/persistence/
mutation/restart oracles, human attestation, limitations, and
`Phase 2: Pending`.

Exclude passwords/hashes/tokens/keys/env dumps/private payloads. Do not claim a
future implementation commit, PR, merge, or final-main SHA in Phase 1 evidence.

## Read-Only Acceptance Gate

Before this gate, mark only the S03-INT-002 index row
`In Progress / Not started / Not started`; keep the detailed task `Approved`,
all other task states unchanged, Stage 3 open, and Stage 4 blocked.

After all Phase 1 work and owner attestation, re-read authority and inspect the
complete diff, predecessor states, exact runtime binding, test outputs, fixture
safety, independent oracle, every scenario, persistence, human smoke, frozen
evidence/hashes, scope, and secrets.

Phase 2: no edits, fixture/database mutation, test rerun, app/backend restart,
auto-fix/write-format, staging, commit, push, PR, merge, or self-fix. Read-only
inspection and read-only database queries are allowed.

Any P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop.

## Post-PASS Delivery

Phase 2 returns its P1/P2/P3 and verdict in the read-only report; it does not
edit evidence. After PASS only, update the evidence solely from
`Phase 2: Pending` to the exact PASS UTC timestamp plus P1/P2/P3 summary. Do not
rewrite scenario, command, oracle, smoke, hash, or limitation evidence.

Then mark S03-INT-002 truthful, set next action to separate Closure Review, keep
Stage 3 not closed/Stage 4 not started, rerun non-writing scope/secret/diff/hash
checks, and commit:

```text
test(stage3): add institution administration end-to-end verification

Task: S03-INT-002
```

Push branch, PR, safe green merge, fast-forward local main, prove local/remote
equality and clean tree.

Delivery failure → `FINAL STATUS: DELIVERY BLOCKED`.
Full delivery → `FINAL STATUS: ACCEPTED`.

Return every detailed-task report item, including exact runtime guard, pre-
endpoint oracle, three-total Dashboard behavior, token preservation/access,
direct-success-only and unconfirmed-GET behavior, frozen hashes, owner smoke,
and final delivery facts. Explicitly state:

```text
Stage 3 was NOT marked Closed by this task.
Stage 4 was NOT started.
Next action: Run the separate Stage 3 Closure Review.
```
