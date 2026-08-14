# Codex Execution Prompt — S03-BE-004

Execute exactly one approved task:

`S03-BE-004 — Institution User Create API`

Repository: `G:\project\testlabuz`

Remote: `https://github.com/Shoxrux2017/testlabuz.git`

Authority task:

`tasks/backend/stage-03/S03-BE-004-institution-user-create-api.md`

Required branch: `task/s03-be-004-institution-user-create`

Read the detailed task completely. It controls this prompt unless a referenced
locked contract is stricter.

## Authority and Dependency Preflight

Read root `AGENTS.md`, `backend/AGENTS.md`, the detailed task,
`tasks/README.md`, `tasks/STAGE_03_TASK_INDEX.md`, accepted S03-INT-001 and
S03-BE-001/002/003, relevant `docs/02–09`, accepted Stage 1/2 auth/Platform
Admin create patterns, and current code/tests/Git.

Prove before edits:

```text
S03-INT-001 = Accepted / PASS / Delivered on origin/main
S03-BE-001 = Accepted / PASS / Delivered on origin/main
S03-BE-002 = Accepted / PASS / Delivered on origin/main
S03-BE-003 = Accepted / PASS / Delivered on origin/main
local main == origin/main
working tree is clean except the owner-prepared S03-BE-004 task/prompt
origin is the approved remote
```

Create/switch to `task/s03-be-004-institution-user-create`. Stop on unsafe Git,
missing dependency, or contract conflict. Do not commit/push before Phase 2.

## Implement Only This Endpoint

```text
POST /api/v1/institution/users
```

Middleware order:

```text
auth:sanctum → active.account → password.changed → role:institution_admin
```

Derive Institution and creator only from the authenticated actor. Accept no
route/query/body/header tenant or creator override.

Require an `application/json` top-level object with exactly these allowed keys:

```text
role, full_name, login_name, email, phone, password
```

Exact validation:

```text
role: required exact teacher|student|parent string
full_name: required trimmed non-empty string max 200
login_name: required trimmed non-empty string max 191, globally unique
email: optional nullable valid string email max 254; empty/whitespace invalid
phone: optional nullable trimmed non-empty string max 50
password: required string min 8 max 255; never trim/normalize/change
```

Absent/whitespace/malformed/scalar/array/JSON-null or non-JSON-media body
returns `422 validation_failed` with `errors.body`. `{}` returns required-field
errors. Reject every query key and unknown/protected body key with field-level
errors and zero partial side effects. Protected areas include IDs,
Institution/creator, lifecycle/first-login/timestamps, password confirmation,
tokens/abilities/permissions, settings, relationships/Groups, and learning.

Pass the authenticated actor to `CreateInstitutionUser`. In one transaction,
persist one User with server UUID, actor Institution/creator, validated role and
profile, `Hash::make` of the exact password, `is_active=true`,
`must_change_password=true`, null `last_login_at/deactivated_at`, and server
timestamps. Refresh and return committed state. Do not query or accept an
arbitrary Institution ID.

Map both validation-time and concurrent global `login_name` conflicts to
`422 validation_failed` with `errors.login_name`. Catch only SQLSTATE `23505`
for `users_login_name_unique`; expose no constraint/SQL detail. Other failures
must roll back and use safe centralized `500 server_error`.

Return exact `201` top-level `data + message`, reuse S03-BE-003
`InstitutionUserResource` byte-for-byte, and return exact message:

```text
Institution user created successfully.
```

Creation itself must not authenticate the new User, create/change a token,
generate/return/log/notify a credential, or create permissions, invitations,
relationships, Groups, settings, categories, or learning records.

Change exactly these application/test paths:

```text
backend/routes/api.php
backend/app/Http/Controllers/Api/V1/Institution/InstitutionUserController.php
backend/app/Http/Requests/Institution/InstitutionUserCreateRequest.php
backend/app/Actions/Institution/CreateInstitutionUser.php
backend/tests/Feature/Institution/InstitutionUserCreateApiTest.php
```

Inspect and preserve the User model, UserRole enum, User factory, Platform code,
and S03-BE-003 resource/read behavior. Stop if the accepted resource cannot be
reused unchanged. Do not add update/lifecycle/reset, model/enum/factory/schema/
frontend changes, Institution Admin/Platform Owner creation, relationships,
Groups, settings, categories, Learning, or later-stage behavior.

## Mandatory Verification

Test exact route/middleware/request/body/query/allowlist behavior; every role;
field trim/null/type/boundaries; password byte preservation/hash/non-disclosure;
server UUID/tenant/creator/lifecycle/first-login/timestamps; all protected and
forged inputs; shared contacts; existing and concurrent global duplicate
login; transactional rollback and safe `500`; exact response/resource/message;
success/error database and token snapshots; no implicit side effects; auth/
inactive/password/wrong-role precedence; each role login and representative
complete first-login password-change flow; immediate S03-BE-003 list/detail
visibility; and Stage 1/2/Platform/read regressions.

Run from `backend/`:

```text
vendor/bin/pint --test
php artisan test --filter=InstitutionUserCreateApiTest
php artisan test
composer validate --strict
```

Run all additional configured backend gates. If the controlled backend is
available, manual smoke must PASS. A smoke FAIL blocks acceptance. `NOT RUN` is
non-blocking only when the environment is genuinely unavailable, the reason is
explicit, and equivalent automated contract/tenant/atomicity/first-login tests
pass. It cannot hide a startup, configuration, or implementation failure.

During Phase 1, update only the S03-BE-004 Stage 3 index row to
`In Progress / Not started / Not started`. Keep the detailed task `Approved`
and this prompt byte-for-byte unchanged before Phase 2. Do not commit or push.

## Read-Only Gate

After Phase 1, re-read all authority and inspect the complete diff/tests/
validation/tenant/race/atomicity/error/first-login/no-side-effect/smoke
evidence. Phase 2 permits no edit, write-format, bookkeeping change, staging,
commit, push, PR, merge, or self-fix.

Classify findings:

```text
P1 = authorization/tenant/secret-password/protected-field/destructive-Git/read-only breach
P2 = material request/validation/resource/persistence/atomicity/race/error/first-login/test/scope/workflow defect
P3 = non-blocking observation with no correctness/security/evidence impact
```

Any unresolved P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start S03-BE-005. Report P3; P3 alone does
not block acceptance.

## Post-PASS Delivery

After PASS with no unresolved P1/P2 only:

1. change only the detailed task metadata status to `Accepted`;
2. prepare only its Stage 3 index row as `Accepted / PASS / Delivered`;
3. update `tasks/README.md` so Stage 3 remains `In Progress`, S03-BE-004 is
   delivered, and S03-BE-005 is the next execution gate;
4. preserve later-task statuses and do not approve S03-BE-005 unless its own
   reviewed pair is already separately approved;
5. keep this prompt byte-for-byte unchanged and include both owner-prepared
   authority files in delivery;
6. keep Stage 3 not closed and Stage 4 not started;
7. rerun final safe scope/diff/secret/consistency checks and commit:

```text
feat(institution): add user creation API

Task: S03-BE-004
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
smoke decision, race/rollback/no-side-effect/safe-500 evidence, bookkeeping/
delivery evidence, and state:

```text
No User update/lifecycle/password reset, Institution Admin/Platform Owner
creation, relationship, Group, settings, category, or Learning behavior was
implemented.
Next implementation gate: S03-BE-005.
```
