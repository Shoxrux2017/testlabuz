# S04-INT-001 — Stage 4 E2E Evidence

## Result

```text
AUTOMATED INTEGRATION FINDING
OWNER SMOKE NOT STARTED
```

Automated acceptance and delivery are blocked by real Windows UI assertions in existing production presentation code. No production file was changed by this integration task.

## Audited Runtime

- execution baseline: `ce373fbcb9540f000dc32961be81dea433a89ec7`
- backend container: `testlabuz-stage4-e2e-app`
- API: `http://127.0.0.1:8817/api/v1`
- Laravel environment: `testing`
- database/driver: `testlabuz_testing` / Laravel `pgsql` / PDO `pgsql`
- PostgreSQL/network: `testlabuz-postgres-1` / `testlabuz_default`
- transient password/token evidence: not recorded

## Focused Verification

- Stage 4 seeder test: `PASS` — 6 tests, 38 assertions.
- focused Pint: `PASS` — 2 Stage 4 PHP files.
- focused Dart format: `PASS` — 1 Stage 4 Dart file, 0 changes.
- Stage 4 PowerShell parse check: `PASS` — runtime guard, guard verifier, oracle, runner, and manual-smoke scripts.
- runtime guard negative matrix: `PASS` — 14 invalid targets, 4 invalid runtime identities, 6 invalid database-server identities, 5 invalid binding shapes, wrong container, and unbound port rejected; exact runtime accepted.
- guarded seeder repeatability: `PASS` — two consecutive runs.
- independent sanitized PostgreSQL oracle: `PASS`.
- pre-mutation frozen foreign/unrelated baseline capture: `PASS`.
- temporary oracle/frozen-artifact cleanup after failed runs: `PASS`.
- `git diff --check`: `PASS`.

## Real-Stack Finding

The mutation test reached real UI login, Group create/edit, Teacher and Student assign/remove/reassign, Parent–Student connect/disconnect/reconnect, security probes, and Group archive. The resulting sanitized database state was:

```text
UI Group: exactly 1, status archived
Teacher history: 2 total / 1 ended / 1 current
Student history: 2 total / 1 ended / 1 current
Parent–Student history: 2 total / 1 ended / 1 current
```

The Windows test nevertheless failed because Flutter reported production presentation assertions:

1. Stage 4 horizontal tables create `Scrollbar` widgets without a controller attached to the corresponding horizontal `SingleChildScrollView`. `ensureVisible`/scroll notifications triggered `Scrollbar's ScrollController has no ScrollPosition attached` in:
   - `frontend/lib/features/institution_admin/presentation/institution_admin_groups_screen.dart`
   - `frontend/lib/features/institution_admin/presentation/institution_group_membership_sections.dart`
   - `frontend/lib/features/institution_admin/presentation/institution_admin_parent_student_connections_screen.dart`
2. Parent–Student list feedback can build `MaterialBanner` with an empty `actions` list, triggering `widget.actions.isNotEmpty` in `frontend/lib/features/institution_admin/presentation/institution_admin_parent_student_connections_screen.dart`.

These are production-code defects outside the integration task's allowed files. Per contract, they were reported and not repaired here.

## Incomplete Acceptance Evidence

- Stage 4 mutation E2E: `FINDING` — database mutations completed, but the Flutter test failed on the production assertions above.
- tenant/security matrix: probe code completed without a direct assertion failure, but is not credited as an overall PASS because the containing Windows test failed.
- post-mutation foreign/unrelated byte comparison: not reached after the Windows test failure.
- backend restart and fresh-process persistence E2E: not run.
- final foreign/unrelated preservation comparison: not run.
- Project Owner manual smoke: `Pending`; do not run until the automated finding is fixed and S04-INT-001 is re-authorized.

## Delivery

No commit, push, PR, or merge was performed because automated integration did not pass.


## Final Result

- Automated Stage 4 real-stack E2E: PASS
- Runtime guard matrix: PASS
- Seeder repeatability: PASS
- Independent PostgreSQL oracle: PASS
- Windows mutation flow: PASS
- Mutation database postconditions: PASS
- Foreign/unrelated preservation after mutation: PASS
- Backend restart: PASS
- Windows persistence flow: PASS
- Persistence database postconditions: PASS
- Foreign/unrelated preservation after restart: PASS
- Temporary artifact cleanup: PASS
- Project Owner manual smoke: PASS

Production finding discovered during the first integration attempt was resolved separately by PR #95 and merged as `3d62def08093507edf21ec9747537e1f4a524ac3`.

Final verdict: `S04-INT-001 — ACCEPTED`.
