# S04-INT-001 — Stage 4 E2E Evidence

## Result

```text
AUTOMATED INTEGRATION PASS
PROJECT OWNER MANUAL SMOKE PASS
S04-INT-001 ACCEPTED / DELIVERED
```

Stage 4 real-stack integration completed successfully after the production
presentation findings discovered during the initial run were fixed separately
in PR #95.

## Audited Runtime

- final product baseline after production fix: `3d62def08093507edf21ec9747537e1f4a524ac3`
- backend container: `testlabuz-stage4-e2e-app`
- API: `http://127.0.0.1:8817/api/v1`
- Laravel environment: `testing`
- database/driver: `testlabuz_testing` / Laravel `pgsql` / PDO `pgsql`
- PostgreSQL/network: `testlabuz-postgres-1` / `testlabuz_default`
- transient password/token evidence: not recorded

## Focused Integration-Asset Verification

- Stage 4 seeder test: `PASS` — 6 tests, 38 assertions.
- focused Pint: `PASS` — 2 Stage 4 PHP files.
- focused Dart format: `PASS` — 1 Stage 4 Dart file, 0 changes.
- Stage 4 PowerShell parse check: `PASS` — runtime guard, guard verifier, oracle,
  runner, and manual-smoke scripts.
- runtime guard negative matrix: `PASS` — invalid target/runtime/database/binding
  shapes were rejected and the exact dedicated runtime was accepted.
- guarded seeder repeatability: `PASS` — two consecutive runs.
- independent sanitized PostgreSQL oracle: `PASS`.
- pre-mutation foreign/unrelated baseline capture: `PASS`.
- `git diff --check`: `PASS`.

## Initial Integration Finding and Resolution

The first Windows mutation run reached the real UI and completed the intended
Stage 4 mutations in the database, but Flutter reported two production
presentation defects:

1. Stage 4 horizontal tables used `Scrollbar` without an attached shared
   horizontal `ScrollController`.
2. Parent–Student feedback could build `MaterialBanner` with an empty
   `actions` list.

The integration task itself did not repair production code. The findings were
fixed separately through:

```text
PR #95
merge:
3d62def08093507edf21ec9747537e1f4a524ac3
```

The fix changed only the three affected Institution Admin presentation files
and their three focused widget-test files. Focused widget tests, Flutter
analysis, focused format verification, and `git diff --check` passed.

## Final Automated Real-Stack Verification

After PR #95 was merged, the Stage 4 runner was executed again against the
dedicated guarded runtime.

Final results:

```text
Stage4RuntimeGuardMatrix: PASS
Stage4RuntimeGuard: PASS
Stage4SeederRepeatability: PASS
Stage4IndependentOracle: PASS
Stage4ForeignUnrelatedBaseline: SAVED
Stage4WindowsMutationE2E: PASS
Stage4MutationDatabasePostconditions: PASS
Stage4ForeignUnrelatedPostMutation: PASS (byte-for-byte)
Stage4BackendRestart: PASS
Stage4WindowsPersistenceE2E: PASS
Stage4PersistenceDatabasePostconditions: PASS
Stage4ForeignUnrelatedPostRestart: PASS (byte-for-byte)
Stage4TemporaryArtifactCleanup: PASS
```

The final automated run proved:

- real Flutter Windows → Laravel → PostgreSQL operation;
- normal Institution Admin login/session path;
- Group create/detail/edit/archive lifecycle;
- Teacher membership assign/remove/reassign history;
- Student membership assign/remove/reassign history;
- Parent–Student connect/disconnect/reconnect history;
- privacy-safe direct-ID and cross-Institution behavior;
- wrong-role authorization denial;
- foreign/unrelated row preservation;
- persistence after dedicated backend restart.

## Project Owner Manual Smoke

Final Project Owner manual smoke: `PASS`.

Verified manually:

- login as `e2e_s04_target_admin`;
- Groups navigation and seeded active/archived Groups;
- active Group Teacher/Student membership sections;
- Users → Parent–Student Connections;
- current relationship visibility from both `By Parent` and `By Student`
  perspectives;
- no obvious overflow, broken navigation, raw JSON/stack output, or
  foreign-Institution data.

## Delivery

Integration assets and PASS evidence were delivered through:

```text
PR #96
merge:
d9eb303719a1c6de5d161f905de9892596a91ae3
```

Final integration-status bookkeeping was delivered through PR #97.

## Final Verdict

```text
S04-INT-001 — ACCEPTED / DELIVERED
Stage 4 Integration Gate — PASS
```

Next permitted gate: `Stage 4 Closure Review`.
