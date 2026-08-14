# Codex Execution Prompt — S03-BE-003

Execute exactly one approved task:

`S03-BE-003 — Institution User List and Detail API`

Repository: `G:\project\testlabuz`

Remote: `https://github.com/Shoxrux2017/testlabuz.git`

Authority task:

`tasks/backend/stage-03/S03-BE-003-institution-user-list-detail-api.md`

Required branch: `task/s03-be-003-institution-user-read`

Read the detailed task completely. It controls this prompt unless a referenced
locked contract is stricter.

## Authority and Dependency Preflight

Read root `AGENTS.md`, `backend/AGENTS.md`, the detailed task,
`tasks/README.md`, `tasks/STAGE_03_TASK_INDEX.md`, accepted S03-INT-001 and
S03-BE-001/002, relevant `docs/02–09`, accepted Stage 1/2 auth/Platform User
list patterns, and current code/tests/Git.

Prove before edits:

```text
S03-INT-001 = Accepted / PASS / Delivered on origin/main
S03-BE-001 = Accepted / PASS / Delivered on origin/main
S03-BE-002 = Accepted / PASS / Delivered on origin/main
local main == origin/main
working tree is clean except the owner-prepared S03-BE-003 task/prompt
origin is the approved remote
```

Create/switch to `task/s03-be-003-institution-user-read`. Stop on unsafe Git,
missing dependency, or contract conflict. Do not commit/push before Phase 2.

## Implement Only These Endpoints

```text
GET /api/v1/institution/users
GET /api/v1/institution/users/{user}
```

Middleware order:

```text
auth:sanctum → active.account → password.changed → role:institution_admin
```

Derive Institution only from the authenticated actor. Eligible target roles
are exactly `teacher|student|parent`. No route/query/body/header Institution
input may affect scope.

Exact resource keys in order:

```text
id, role, full_name, login_name, email, phone, is_active,
must_change_password, last_login_at, deactivated_at, created_at, updated_at
```

List query allowlist and defaults:

```text
role = teacher|student|parent|omitted
status = active|inactive|omitted
search = trimmed literal string max 254
page = integer >= 1, default 1
per_page = integer 1..100, default 20
sort = full_name|login_name|created_at|updated_at, default full_name
direction = asc|desc, default asc
```

Omitted role includes all three roles; omitted status includes active and
inactive Users. Status maps to `is_active`. Search is case-insensitive across
name/login/email/phone using bound PostgreSQL `ILIKE ? ESCAPE '!'`; escape
literal `!`, `%`, and `_`. Text sorting is case-insensitive and every sort uses
UUID `id` as final tie-break in the same direction. Whitelist all raw ordering
values.

List returns exactly `data + meta.pagination` with integer
`page,per_page,total,last_page`; no message/links/default Laravel pagination.
Tenant and eligible-role predicates apply before filters/search/order/
pagination, including metadata. At action level use exactly two scoped User
queries: count plus page select. Select only resource fields; no relationships,
per-role queries, unbounded loads, or N+1.

Detail accepts the raw `{user}` string. Do not use implicit model binding or a
route UUID constraint. Middleware runs first, then Form Request input
validation, then UUID/target resolution. A clean malformed, unknown, foreign,
Platform Owner, or Institution Admin target returns the same scope-safe
`404 resource_not_found`. Resolve valid syntax with one User query containing
UUID + actor Institution + eligible-role predicates. Detail success returns
only the normal `data` envelope with no message/meta/links.

Both endpoints accept only zero raw body bytes. Whitespace, `{}`, keyed object,
array, scalar, JSON `null`, malformed JSON, raw text, or form content returns
`422 validation_failed` with `errors.body`. Detail rejects every query key;
list rejects unknown/invalid query input with field-level errors.

Create exactly these focused boundaries:

```text
backend/app/Http/Controllers/Api/V1/Institution/InstitutionUserController.php
backend/app/Http/Requests/Institution/InstitutionUserIndexRequest.php
backend/app/Http/Requests/Institution/InstitutionUserShowRequest.php
backend/app/Actions/Institution/ListInstitutionUsers.php
backend/app/Actions/Institution/ShowInstitutionUser.php
backend/app/Http/Resources/Institution/InstitutionUserResource.php
backend/app/Http/Resources/Institution/InstitutionUserCollection.php
backend/tests/Feature/Institution/InstitutionUserReadApiTest.php
```

`backend/routes/api.php` is the only other application path allowed to change.
Inspect and preserve User model/enum and Platform code. Requests validate,
controller stays thin, actions query trusted scope, and resource/collection
serialize exact contracts.

Do not add User mutation, model/enum/schema/factory/seeder/frontend changes,
Institution Admin/Platform Owner management, relationships, Groups, settings,
categories, Learning, or later-stage behavior.

## Mandatory Verification

Test exact routes/middleware/envelopes/resource/types/nulls/UTC; three roles and
both lifecycle states; tenant/disallowed-role exclusion from data and totals;
all filters/search/sorts/directions/pagination/defaults/boundaries/out-of-range;
literal `!/%/_`; invalid/unknown/array/SQL/raw-sort inputs; complete GET-body
matrix for both endpoints; clean own/malformed/unknown/foreign/disallowed
details and precedence; fake tenant headers; exact disclosure exclusions;
action-level two-query list and one-query detail evidence; success/error
Institution/settings/User/token snapshots; safe centralized
`500 server_error` for controlled list/detail failures without internal detail
or writes; and accepted Stage 1/2 auth/Platform regressions.

Run from `backend/`:

```text
vendor/bin/pint --test
php artisan test --filter=InstitutionUserReadApiTest
php artisan test
composer validate --strict
```

Run all additional configured backend gates. If the controlled backend is
available, manual smoke must PASS. A smoke FAIL blocks acceptance. `NOT RUN` is
non-blocking only when the environment is genuinely unavailable, the reason is
explicit, and equivalent automated contract/tenant/query/no-write tests pass.
It cannot hide a startup, configuration, or implementation failure.

During Phase 1, update only the S03-BE-003 Stage 3 index row to
`In Progress / Not started / Not started`. Keep the detailed task `Approved`
and this prompt byte-for-byte unchanged before Phase 2. Do not commit or push.

## Read-Only Gate

After Phase 1, re-read all authority and inspect the complete diff/tests/
security/tenant/input/envelope/query/error/no-write/smoke evidence. Phase 2
permits no edit, write-format, bookkeeping change, staging, commit, push, PR,
merge, or self-fix.

Classify findings:

```text
P1 = authorization/tenant/protected-data/secret/destructive-Git/read-only breach
P2 = material resource/list/detail/input/pagination/not-found/error/query/architecture/test/scope/workflow defect
P3 = non-blocking observation with no correctness/security/evidence impact
```

Any unresolved P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start S03-BE-004. Report P3; P3 alone does
not block acceptance.

## Post-PASS Delivery

After PASS with no unresolved P1/P2 only:

1. change only the detailed task metadata status to `Accepted`;
2. prepare only its Stage 3 index row as `Accepted / PASS / Delivered`;
3. update `tasks/README.md` so Stage 3 remains `In Progress`, S03-BE-003 is
   delivered, and S03-BE-004 is the next execution gate;
4. preserve later-task statuses and do not approve S03-BE-004 unless its own
   reviewed pair is already separately approved;
5. keep this prompt byte-for-byte unchanged and include both owner-prepared
   authority files in delivery;
6. keep Stage 3 not closed and Stage 4 not started;
7. rerun final safe scope/diff/secret/consistency checks and commit:

```text
feat(institution): add user read APIs

Task: S03-BE-003
```

Stage only approved implementation/tests, the detailed task, this unchanged
prompt, Stage 3 index, and README. Push the task branch, open a PR to `main`,
verify base/head/diff, merge only when safe/green, fast-forward local main, and
prove local main equals origin/main with a clean tree.

Prepared `Accepted / PASS / Delivered` bookkeeping becomes authoritative only
after successful merge and local/remote/clean verification.

Delivery failure after PASS: `FINAL STATUS: DELIVERY BLOCKED`.
Complete delivery: `FINAL STATUS: ACCEPTED`.

Final response must include every detailed-task report item, P1/P2/P3 findings,
smoke decision, exact query/no-write/safe-500 evidence, bookkeeping/delivery
evidence, and state:

```text
No User mutation, Institution Admin/Platform Owner management, relationship,
Group, settings, category, or Learning behavior was implemented.
Next implementation gate: S03-BE-004.
```
