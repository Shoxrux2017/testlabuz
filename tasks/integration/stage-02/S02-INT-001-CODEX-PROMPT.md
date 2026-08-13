# Codex Execution Prompt — S02-INT-001

Execute exactly one approved TestLabUz task:

`S02-INT-001 — Stage 2 Windows Real-Stack End-to-End Verification`

Repository:

`G:\project\testlabuz`

Approved remote:

`https://github.com/Shoxrux2017/testlabuz.git`

Authority detailed task:

`tasks/integration/stage-02/S02-INT-001-stage-02-windows-real-stack-e2e-verification.md`

Required task branch:

`task/s02-int-001-stage2-windows-e2e`

This prompt does not restate every rule in the detailed task. Read that file
completely before acting. If this prompt and the detailed task appear to differ,
the detailed task controls unless a locked `docs/01–09` contract is stricter.

Do not implement Stage 3.
Do not mark Stage 2 closed.
Do not create or run the Stage 2 closure review.

---

## Mandatory Authority Order

Read and obey, in order:

1. root `AGENTS.md`;
2. `backend/AGENTS.md`;
3. `frontend/AGENTS.md`;
4. the complete S02-INT-001 detailed task;
5. `tasks/STAGE_02_TASK_INDEX.md` and `tasks/README.md`;
6. locked Stage 2 sections in `docs/06-roadmap.md`;
7. applicable locked architecture/database/API sections in `docs/07–09`;
8. accepted `S02-BE-001` through `S02-BE-007` contracts;
9. accepted `S02-FE-001` through `S02-FE-009` contracts;
10. current implementation, tests, integration assets, Git history, and
    `origin/main` state.

Locked documents outrank tasks. Current accepted code is evidence, not
permission to reinterpret the contract.

---

## Required Dependency State

Before changing anything, prove:

```text
S02-BE-001 through S02-BE-007 = Accepted and delivered
S02-FE-001 through S02-FE-009 = Accepted and delivered
```

Direct dependencies:

```text
S02-BE-007 = Accepted
S02-FE-009 = Accepted
```

Verify all sixteen predecessor rows, their review/delivery states, and the
presence of accepted commits on `origin/main`. Do not infer acceptance merely
because a file exists.

Stop if any predecessor is unaccepted, undelivered, `NOT ACCEPTED`,
`DELIVERY BLOCKED`, or unresolved. This task cannot implement missing earlier
scope.

---

## Git Preflight

1. Verify repository root and exact approved `origin`.
2. Fetch safely.
3. Verify clean local `main` and `main == origin/main`.
4. The only allowed preparation additions on `main`, when owner-saved, are:

   ```text
   tasks/integration/stage-02/S02-INT-001-stage-02-windows-real-stack-e2e-verification.md
   tasks/integration/stage-02/S02-INT-001-CODEX-PROMPT.md
   ```

5. Do not commit those files on `main`.
6. Create/switch immediately to:

   `task/s02-int-001-stage2-windows-e2e`

7. Preserve unrelated user work. Stop on unexpected dirty state.
8. Do not commit, push, create a PR, or merge before the read-only gate passes.

Never force-push, rewrite history, use destructive cleanup, bypass checks, or
change global Git configuration.

---

## Verify Only S02-INT-001

This is a verification-assets/evidence task. It may create:

```text
frontend/integration_test/stage2_platform_management_flow_test.dart
backend/database/seeders/Stage2E2eSeeder.php
focused Stage 2 E2E guard/support tests
tasks/integration/stage-02/S02-INT-001-stage-02-e2e-evidence.md
```

Reuse the Flutter SDK `integration_test` dependency and accepted Stage 1 test
infrastructure. Add no third-party E2E framework.

Do not silently repair an earlier accepted production behavior. If the real
stack reveals a product contract defect, stop and report it as a finding.

Do not modify locked `docs/01–09`.

---

## Dedicated Testing Safety

Before any fixture mutation, prove inside the actual backend runtime:

```text
APP_ENV = testing
current_database() = testlabuz_testing
```

The guarded Stage 2 seeder must refuse:

- any other environment;
- any other database;
- missing transient credential input.

It may reset only records unmistakably owned by the Stage 2 E2E fixture set,
using reserved names such as `E2E S02 ...` / `e2e_s02_...`. It must not
truncate the database or delete unrelated Stage 1/manual/future records.

Supply passwords only through transient local input. Never commit, print,
return, screenshot, or record them. Use redacted placeholders in evidence and
commands.

Run the real Laravel testing API on a dedicated loopback-only address:

```text
http://127.0.0.1:<stage2-e2e-port>/api/v1
```

Do not expose it publicly or reuse an unknown development server.

---

## Required Fixture World

Create a deterministic, repeatable Stage 2 fixture world containing at least:

- active password-complete Platform Owner;
- active target, inactive target, and unaffected active Institutions;
- enough Institutions for page `1`/`2` with page size `20`;
- names/statuses/types for combined filters and literal `%`/`_` search;
- deterministic recent-Institution timestamps;
- enough target-Institution admins for search/filter/sort/pagination;
- active and inactive admins;
- active admin in an inactive Institution;
- admin in another Institution;
- one non-admin User for specialized-route safe-not-found checks;
- known per-Institution/global user counts;
- exactly one safe settings row per fixture Institution.

All UUID, role, ownership, login-name, lifecycle, settings, and password
constraints must remain valid.

---

## Real Windows Test Boundary

Launch the real Flutter Windows app and use:

```text
real UI
real Riverpod/session/router
real repositories/data sources
real Dio
real Laravel API
real Sanctum
real PostgreSQL testlabuz_testing
```

Do not mock HTTP, inject an authenticated provider, fake the repository, or
replace Windows E2E with widget/web tests.

Use visible UI actions for product flows. Direct real API calls are allowed
only for independent postcondition/security assertions that cannot be safely
observed through UI.

Use bounded waits on observable application state. Do not use long arbitrary
sleeps or production-only test hooks.

---

## Mandatory Real-Stack Scenario Matrix

Run and record explicit PASS/FAIL for every group below.

### 1. Platform Owner shell

- login through UI;
- `/auth/me` bootstrap;
- `/platform-owner` shell;
- only Dashboard/Institutions navigation;
- direct URL/reload;
- logout and protected-data clearing.

### 2. Dashboard

- exact Institution total/active/inactive;
- exact User total/active;
- exact newest five Institutions/order;
- no invented/protected metric blocks;
- refresh/navigation/session freshness.

### 3. Institution list

- server search including case and literal `%`/`_`;
- status/type and combined filters;
- accepted sorting/direction;
- `20/50/100` page size;
- Previous/Next and truthful pagination;
- stale-response suppression and filter clearing.

### 4. Institution detail

- row navigation and direct UUID URL;
- exact public fields and total/active user counts;
- unknown UUID not-found;
- rapid target change safety;
- no settings/user identity/creator/token/learning-data leakage.

### 5. Institution create

- exact seven fields;
- duplicate-submit protection;
- confirmed server resource;
- list/detail/dashboard refresh/invalidation;
- exactly one settings row with `Asia/Tashkent`, `25`, `15`, and all four
  educational policy fields plus `updated_by_user_id` equal to `null`;
- no implicit admin/token/category/learning record.

### 6. Institution edit

- current-data load;
- six-field allowlist and nullable clears;
- changed-fields-only PATCH;
- no-change means no PATCH;
- status/settings/creator/lifecycle/count protection;
- detail/list/dashboard server-authoritative refresh.

### 7. Institution lifecycle

- state-appropriate action;
- cancel sends nothing;
- confirm sends one empty POST;
- in-flight duplicate protection;
- no optimistic success;
- detail/list/dashboard refresh;
- idempotent no-op/concurrency tests;
- target Institution login/token block after deactivation;
- unrelated Institution unaffected;
- reactivation restores only eligible active users;
- inactive user and first-login states remain enforced;
- settings/users/tokens/history preserved.

### 8. Institution Admin list/create

- path + role scoped list;
- search/status/sort/`20/50/100` pagination;
- no cross-Institution row;
- exact public Resource boundary;
- exact five-field create;
- server-derived role/Institution/creator/state;
- password clearing and non-return/non-log;
- new admin first-login `/change-password` gate;
- password change, old-password failure, new-password success.

### 9. Institution Admin update/lifecycle

- exact three-field profile update;
- changed-fields-only/no-change behavior;
- protected login/role/Institution/password/first-login/last-login/token state;
- cancel/confirm/body-less lifecycle behavior;
- no optimistic or duplicate mutation;
- deactivated admin access blocked;
- activation preserves password/first-login state;
- inactive parent Institution still blocks access;
- unrelated admin/Institution unchanged.

### 10. Authorization/disclosure

- `401` unauthenticated;
- `403` for each of four Institution roles with correct middleware precedence;
- inactive-user/inactive-Institution/password-change gates;
- scope-safe `404` for unknown resource and wrong-role admin target;
- `422` unknown/protected query/body keys with no mutation;
- no credentials, settings policies, creator data, tokens, relationship graph,
  or learning data exposed.

### 11. Session isolation

```text
Platform Owner with loaded platform data
→ logout
→ Institution Admin login/direct Platform URL/back navigation
```

No Platform shell, KPI, Institution, or admin data may remain or flash.
Returning as Platform Owner must load fresh server state.

### 12. Restart/persistence

Restart the dedicated Laravel E2E runtime without resetting PostgreSQL, then
rebootstrap Flutter and prove created/edited/final lifecycle/settings/count
state persists without mutation replay.

Do not omit a scenario silently. If a scenario cannot run, Phase 2 cannot PASS.

---

## Deterministic UI Coverage

In addition to the real populated Windows flow, the normal Flutter tests must
pass for:

- loading/data/global-empty/filtered-empty/partial-empty/error/Retry;
- validation and server field errors;
- `401/403/404/409/422` and transport/server failures;
- mutation in-flight state;
- confirmation cancellation;
- no automatic mutation retry;
- uncertain-outcome read-only reconciliation;
- stale target/query/session response rejection;
- keyboard, focus, and accessibility behavior;
- Stage 1 session/router regressions.

Do not weaken these tests because real E2E uses a populated fixture world.

---

## Required Verification Commands

Use current repository-valid commands. At minimum, when still accepted:

Backend:

```text
php artisan test
vendor/bin/pint --test
composer validate --strict
```

Flutter:

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test integration_test
flutter build windows --debug
```

Run configured static/security/build checks additionally when required by the
current repository. Do not invent unconfigured tools.

Run the Stage 2 Windows integration test explicitly against the dedicated real
backend with secret values redacted from evidence.

Any required failure blocks acceptance.

---

## Human-Observable Windows Smoke

Obtain truthful project-owner/operator observation of the real Windows app:

```text
login
→ Dashboard
→ Institution list/search/filter/page
→ detail
→ create/edit Institution
→ cancel and confirm Institution lifecycle
→ list/create/edit Institution Admin
→ cancel and confirm Admin lifecycle
→ direct URL/reload/error recovery
→ logout and verify protected data absent
```

Record performer role, UTC date, and PASS/FAIL by group. Never record
credentials.

Do not claim Codex observed an owner-run check. Missing mandatory human smoke
is a P2 and results in `NOT ACCEPTED`.

---

## Sanitized Evidence

Create:

`tasks/integration/stage-02/S02-INT-001-stage-02-e2e-evidence.md`

Record:

- branch/base/hash context;
- runtime versions and Windows target;
- loopback/testing DB identity;
- fixture guard/repeatability results;
- backend/frontend commands and counts;
- every mandatory scenario PASS/FAIL;
- settings/retention/restart evidence;
- authorization/leakage matrix;
- human-smoke attestation;
- Phase 2 findings/verdict;
- non-blocking limitations.

Do not include passwords, tokens, hashes, private keys, full environment dumps,
private sensitive responses, or secret-bearing screenshots.

---

## Explicit Non-Goals

Do not include:

- Stage 2 closure;
- Stage 3 tasks or product behavior;
- Teacher/Student/Parent management;
- Groups/relationships/learning content/scoring/results;
- Institution settings management;
- hard delete/archive/suspend/merge/transfer;
- billing/licensing/support/advanced analytics;
- Android or web Stage 2 real E2E;
- production deployment/load/chaos testing;
- third-party E2E packages;
- production test/debug routes or credentials;
- unrelated refactors;
- product bug fixes discovered by verification.

---

## Mandatory Read-Only Acceptance Gate

After all implementation, automated checks, real E2E, restart verification,
human smoke, evidence, and secret/scope checks are complete, begin Phase 2.

Re-read the authority files and inspect:

- all predecessor states;
- complete diff including untracked files;
- exact backend/frontend output;
- every real E2E result;
- fixture/database safety;
- persistence/restart result;
- human-smoke evidence;
- sanitized evidence;
- locked-doc/scope/secret checks.

Phase 2 is read-only. Do not edit, auto-fix, format-write, mutate fixtures,
stage, commit, push, open a PR, or merge.

Classify:

- `P1`: security/tenant/secret/database/destructive lifecycle/core E2E failure;
- `P2`: material contract/test/reproducibility/persistence/evidence/manual-smoke/
  scope mismatch;
- `P3`: non-blocking observation.

Any P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop. Do not self-fix or deliver.

---

## Post-PASS GitHub Delivery

Only after Phase 2 PASS:

1. mark only S02-INT-001 `Accepted`;
2. update its Stage 2 index row to truthful `Accepted` / `PASS`;
3. update `tasks/README.md` so the next action is the separate Stage 2 Closure
   Review;
4. keep Stage 2 explicitly not `Closed`;
5. finalize only safe lifecycle/hash evidence metadata when required;
6. rerun final non-writing diff/secret/scope checks;
7. stage only approved S02-INT-001 files;
8. commit:

   ```text
   test(stage2): add platform management end-to-end verification
   ```

   Body:

   ```text
   Task: S02-INT-001
   ```

9. push `task/s02-int-001-stage2-windows-e2e`;
10. open a PR to `main`;
11. wait for required checks;
12. merge only when safe/green;
13. synchronize local `main` by fast-forward only;
14. verify local `main == origin/main` and clean tree.

Never bypass checks or push the production task directly to `main`.

If delivery fails after PASS:

```text
FINAL STATUS: DELIVERY BLOCKED
```

If delivery fully succeeds:

```text
FINAL STATUS: ACCEPTED
```

Next action: separate Stage 2 Closure Review.

---

## Required Final Response

Report:

1. final status;
2. all-predecessor/Git preflight;
3. environment and Windows target;
4. testing database and fixture safety;
5. changed verification assets;
6. backend results/counts;
7. Flutter results/counts;
8. every mandatory scenario group PASS/FAIL;
9. settings/lifecycle/admin first-login/security evidence;
10. session isolation and restart persistence;
11. human-observable Windows smoke;
12. evidence file;
13. P1/P2/P3 findings;
14. acceptance checklist summary;
15. secret/scope/locked-doc checks;
16. commit/branch/PR/checks/merge/hash/clean delivery evidence;
17. explicit statement:
    `Stage 2 was NOT marked Closed by this task.`;
18. next action:
    `Run the separate Stage 2 Closure Review.`;
19. remaining blockers/deviations.

Do not start Stage 3.
