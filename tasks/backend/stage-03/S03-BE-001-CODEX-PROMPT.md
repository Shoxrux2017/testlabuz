# Codex Execution Prompt — S03-BE-001

Execute exactly one approved task:

`S03-BE-001 — Institution Admin Dashboard API`

Repository: `G:\project\testlabuz`

Remote: `https://github.com/Shoxrux2017/testlabuz.git`

Authority task:

`tasks/backend/stage-03/S03-BE-001-institution-admin-dashboard-api.md`

Required branch: `task/s03-be-001-institution-dashboard`

Read the detailed task completely. It controls this prompt unless a referenced
locked contract is stricter.

## Authority and Dependency Preflight

Read root `AGENTS.md`, `backend/AGENTS.md`, the detailed task,
`tasks/README.md`, `tasks/STAGE_03_TASK_INDEX.md`, S03-INT-001, relevant
`docs/02–09`, accepted Stage 1/2 auth/platform patterns, and current code/tests.

Prove before edits:

```text
S03-INT-001 = Accepted / PASS / Delivered
local main == origin/main
working tree is clean except the owner-prepared S03-BE-001 task/prompt
origin is the approved remote
```

Create/switch to `task/s03-be-001-institution-dashboard`. Stop on unsafe Git,
missing dependency, or contract conflict. Do not commit/push before Phase 2.

## Implement Only This Endpoint

```text
GET /api/v1/institution/dashboard
```

Middleware order:

```text
auth:sanctum → active.account → password.changed → role:institution_admin
```

Return exact own-Institution counts:

```text
users.teachers
users.students
users.parents
```

Each number includes active and inactive accounts of its role. Exclude Platform
Owner, Institution Admin, and every other Institution. Activating/deactivating
an eligible account does not change these totals. Return numeric zeroes for
empty roles.

Accept only zero raw request-body bytes. Reject all query keys and any
transmitted body with `422 validation_failed` and field errors, including
whitespace, `{}`, keyed object, array, scalar, JSON `null`, and malformed JSON.

Create exactly these focused boundaries:

```text
backend/app/Http/Requests/Institution/InstitutionDashboardRequest.php
backend/app/Http/Controllers/Api/V1/Institution/InstitutionDashboardController.php
backend/app/Actions/Institution/ShowInstitutionDashboard.php
backend/app/Http/Resources/Institution/InstitutionDashboardResource.php
backend/tests/Feature/Institution/InstitutionDashboardApiTest.php
```

`ShowInstitutionDashboard` must issue exactly one tenant-first conditional
aggregate query against `users`. Do not hydrate User rows, query once per role,
or add N+1 queries.

Do not add Group/Learning metrics, profile/users/settings/categories behavior,
frontend code, migrations, or later-stage scope.

## Mandatory Verification

Test exact response/types/counts, zeroes, cross-tenant exclusion, excluded
roles, unauthenticated/wrong-role/inactive/password-gate precedence, body/query
rejection, activation/deactivation total stability, disclosure boundary,
success/failure no-write snapshots, safe centralized `500 server_error`, and
exactly one action-level User aggregate query.

Run from `backend/`:

```text
vendor/bin/pint --test
php artisan test --filter=InstitutionDashboardApiTest
php artisan test
composer validate --strict
```

Run all additional configured backend gates. If the controlled backend is
available, manual smoke must PASS; FAIL blocks acceptance. `NOT RUN` is
non-blocking only when the environment is genuinely unavailable, the reason is
explicit, and equivalent automated contract/tenant/count tests pass. It cannot
hide a startup, configuration, or implementation failure.

During Phase 1, update only the S03-BE-001 Stage 3 index row to
`In Progress / Not started / Not started`. Keep the detailed task `Approved`
and this prompt byte-for-byte unchanged before Phase 2. Do not commit or push.

## Read-Only Gate

After Phase 1, re-read all authority and inspect complete diff/tests/security/
tenant/input/error/query/no-write/smoke evidence. Phase 2 permits no edit,
write-format, bookkeeping change, staging, commit, push, PR, merge, or
self-fix.

Classify findings:

```text
P1 = authorization/tenant/protected-data/secret/destructive-Git/read-only breach
P2 = material contract/count/input/error/architecture/query/test/scope/workflow defect
P3 = non-blocking observation with no correctness/security/evidence impact
```

Any unresolved P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start S03-BE-002. Report P3; P3 alone does not
block acceptance.

## Post-PASS Delivery

After PASS with no unresolved P1/P2 only:

1. change only the detailed task metadata status to `Accepted`;
2. prepare only its Stage 3 index row as `Accepted / PASS / Delivered`;
3. update `tasks/README.md` so Stage 3 remains `In Progress` and S03-BE-002 is
   the next execution gate;
4. preserve later-task statuses and do not approve S03-BE-002 unless its own
   reviewed pair is already separately approved;
5. keep this prompt byte-for-byte unchanged and include both owner-prepared
   authority files in delivery;
6. keep Stage 3 not closed and Stage 4 not started;
7. rerun final safe scope/diff/secret/consistency checks and commit:

```text
feat(institution): add admin dashboard aggregates

Task: S03-BE-001
```

Stage only approved implementation/tests, the detailed task, this unchanged
prompt, Stage 3 index, and README. Push the task branch, open PR to main, verify
base/head/diff, merge only safe/green, fast-forward local main, and prove local
main equals origin/main with a clean tree.

Prepared `Accepted / PASS / Delivered` bookkeeping becomes authoritative only
after successful merge and local/remote/clean verification.

Delivery failure after PASS: `FINAL STATUS: DELIVERY BLOCKED`.
Complete delivery: `FINAL STATUS: ACCEPTED`.

Final response must include all task-required evidence, P1/P2/P3 findings,
smoke decision, exact one-query and no-write evidence, bookkeeping/delivery
evidence, and state:

```text
No Group or Learning dashboard metrics were implemented.
Next implementation gate: S03-BE-002.
```
