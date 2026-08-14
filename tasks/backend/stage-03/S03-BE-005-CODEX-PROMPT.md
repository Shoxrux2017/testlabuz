# Codex Execution Prompt — S03-BE-005

Execute exactly one approved task:

`S03-BE-005 — Institution User Update and Lifecycle API`

Repository: `G:\project\testlabuz`

Remote: `https://github.com/Shoxrux2017/testlabuz.git`

Authority task:

`tasks/backend/stage-03/S03-BE-005-institution-user-update-lifecycle-api.md`

Required branch: `task/s03-be-005-institution-user-lifecycle`

Read the detailed task completely. It controls this prompt unless a referenced
locked contract is stricter.

## Authority and Dependency Preflight

Read root `AGENTS.md`, `backend/AGENTS.md`, the detailed task,
`tasks/README.md`, `tasks/STAGE_03_TASK_INDEX.md`, accepted S03-INT-001 and
S03-BE-001/002/003/004, relevant `docs/02–09`, accepted Stage 2 Platform Admin
update/lifecycle patterns, and current code/tests/Git.

Prove before edits:

```text
S03-INT-001 = Accepted / PASS / Delivered on origin/main
S03-BE-001 = Accepted / PASS / Delivered on origin/main
S03-BE-002 = Accepted / PASS / Delivered on origin/main
S03-BE-003 = Accepted / PASS / Delivered on origin/main
S03-BE-004 = Accepted / PASS / Delivered on origin/main
local main == origin/main
working tree is clean except the owner-prepared S03-BE-005 task/prompt
origin is the approved remote
```

Create/switch to `task/s03-be-005-institution-user-lifecycle`. Stop on unsafe
Git, missing dependency, or contract conflict. Do not commit/push before Phase
2 PASS.

## Implement Only These Endpoints

```text
PATCH /api/v1/institution/users/{user}
POST  /api/v1/institution/users/{user}/activate
POST  /api/v1/institution/users/{user}/deactivate
```

Middleware order:

```text
auth:sanctum → active.account → password.changed → role:institution_admin
```

Derive Institution only from the authenticated actor. Eligible targets are
exactly own-Institution `teacher|student|parent` Users. Accept no route/query/
body/header tenant override.

Keep `{user}` raw: no implicit model binding or route UUID constraint.
Middleware runs first, then Form Request validation, then action-level UUID and
target resolution. Malformed, unknown, foreign, Platform Owner, and Institution
Admin targets share the same safe `404 resource_not_found`. Invalid input is
rejected before hidden-target lookup.

## Exact PATCH Behavior

Require `application/json` with a non-empty top-level object and only:

```text
full_name, email, phone
```

Validation/normalization:

```text
full_name: present required, trimmed non-empty string, max 200
email: present nullable valid string email, max 254; empty/whitespace invalid
phone: present nullable, trimmed non-empty string when non-null, max 50
```

Omission preserves; explicit null clears email/phone; contacts are not unique.
Absent/whitespace/malformed/scalar/array/JSON-null/non-JSON body returns
`422 validation_failed` with `errors.body`; `{}` also returns `errors.body`.
Reject every query key and every unknown/protected JSON key with field-level
errors and zero partial mutation. Protected areas include IDs, Institution,
role/login/password, lifecycle/first-login/last-login/creator/timestamps,
tokens/abilities/permissions, relationships/Groups/settings/learning data.

Pass actor, raw target ID, and only validated normalized values to
`UpdateInstitutionUser`. In one transaction, validate UUID, select by target ID
+ actor Institution + eligible roles using `lockForUpdate()`, mutate only the
three allowed fields, and refresh committed state. If normalized values equal
the fresh locked values, execute no User update and preserve exact
`updated_at`. A real update advances `updated_at` once using server time and
cannot alter lifecycle/protected/token/unrelated state. Unexpected failure must
roll back fully and use safe centralized `500 server_error`.

PATCH returns exact `200`, unchanged S03-BE-003 User resource, only top-level
`data + message`, and:

```text
Institution user updated successfully.
```

## Exact Lifecycle Behavior

Both lifecycle endpoints accept no body or empty JSON object `{}` and no query.
Reject non-empty object, malformed JSON, scalar/array/null, non-empty non-JSON
media, and every query key with `422 validation_failed` and zero mutation.

Pass actor and raw target ID to `ChangeInstitutionUserLifecycle`. Resolve the
fresh scoped target inside one transaction with the same
`lockForUpdate()` strategy used by PATCH.

Required transitions:

```text
activate inactive: is_active=true, deactivated_at=null, one User update,
                   updated_at advances once
activate active:   idempotent 200, no User update, preserve updated_at
deactivate active: is_active=false, deactivated_at=server time, one User update,
                   updated_at advances once
deactivate inactive: idempotent 200, no User update, preserve original
                     deactivated_at and updated_at
```

Exact messages:

```text
Institution user activated successfully.
Institution user deactivated successfully.
```

Every success returns exact `200`, only `data + message`, and the unchanged
12-key resource:

```text
id, role, full_name, login_name, email, phone, is_active,
must_change_password, last_login_at, deactivated_at, created_at, updated_at
```

## Locked Token and Preservation Rules

Do not create, delete, update, rotate, revoke, restore, or replace target
Sanctum token rows in PATCH or lifecycle. Deactivation blocks new login and
existing-token protected access through accepted `active.account` behavior,
while token rows remain stored. Reactivation creates/restores no token; a
retained still-valid token may resume only otherwise-authorized access. A token
separately removed by logout/expiry/revocation remains removed.

Always preserve password hash, `must_change_password`, `last_login_at`,
identity, login, role, Institution, creator, relationships, history, learning
data, all other Users, Institution/settings, and unrelated rows. Reactivation
does not bypass Institution, first-login, role, or permission gates.

All same-target PATCH/activate/deactivate operations must serialize on the same
PostgreSQL row lock and use fresh committed state. Prove no stale overwrite for
overlapping profile updates, PATCH/lifecycle, same lifecycle, and opposite
lifecycle races; final state/timestamps must be internally valid and token/
relationship/history/unrelated snapshots unchanged.

## Exact Change Scope

Change exactly these application/test paths:

```text
backend/routes/api.php
backend/app/Http/Controllers/Api/V1/Institution/InstitutionUserController.php
backend/app/Http/Requests/Institution/InstitutionUserUpdateRequest.php
backend/app/Http/Requests/Institution/InstitutionUserLifecycleRequest.php
backend/app/Actions/Institution/UpdateInstitutionUser.php
backend/app/Actions/Institution/ChangeInstitutionUserLifecycle.php
backend/tests/Feature/Institution/InstitutionUserUpdateLifecycleApiTest.php
```

Reuse `InstitutionUserResource` byte-for-byte. Inspect and preserve S03-BE-003
read actions, User model/enum/factory, auth middleware, and Platform code. Do
not add create/delete/reset, token management, Institution Admin/Platform Owner
management, model/enum/factory/schema/migration/index/auth/frontend changes,
relationships, Groups, settings, categories, Learning, or later-stage behavior.

## Mandatory Verification

Test exact routes/middleware/precedence; PATCH media/body/query/allowlist and
every field/null/trim/boundary/protected/no-op case; lifecycle empty/`{}` and
complete invalid body/query matrix; all three eligible roles and active/inactive
targets; malformed/unknown/foreign/disallowed safe 404; exact resource/messages/
timestamps; one-write real transitions and zero-write no-ops; complete success/
failure row snapshots; stored-token retention, inactive login/token blocking,
reactivation/no token creation/retained-token behavior; password/first-login/
last-login/relationships/history preservation; PostgreSQL row locks and
controlled same-target races; rollback/safe `500`/non-disclosure; auth/inactive
Institution/password/wrong-role gates; S03-BE-003 list/detail visibility; and
S03-BE-004/Stage 1/2/Platform regressions.

Run from `backend/`:

```text
vendor/bin/pint --test
php artisan test --filter=InstitutionUserUpdateLifecycleApiTest
php artisan test
composer validate --strict
```

Run all additional configured backend gates. If the controlled backend is
available, manual smoke must PASS. A smoke FAIL blocks acceptance. `NOT RUN` is
non-blocking only when the environment is genuinely unavailable, the reason is
explicit, and equivalent automated contract/tenant/atomicity/concurrency/
token-preservation tests pass. It cannot hide a startup, configuration, or
implementation failure.

During Phase 1, update only the S03-BE-005 Stage 3 index row to
`In Progress / Not started / Not started`. Keep the detailed task `Approved`
and this prompt byte-for-byte unchanged before Phase 2. Do not commit or push.

## Read-Only Gate

After Phase 1, re-read all authority and inspect the complete diff/tests/
request/resource/tenant/locking/no-op/timestamp/token/concurrency/rollback/
preservation/disclosure/smoke evidence. Phase 2 permits no edit, write-format,
bookkeeping change, staging, commit, push, PR, merge, or self-fix.

Classify findings:

```text
P1 = authorization/tenant/secret-token/protected-field/destructive-Git/read-only breach
P2 = material request/resource/mutation/no-op/timestamp/token/transaction/concurrency/error/test/scope/workflow defect
P3 = non-blocking observation with no correctness/security/evidence impact
```

Any unresolved P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start S03-BE-006. Report P3; P3 alone does
not block acceptance.

## Post-PASS Delivery

After PASS with no unresolved P1/P2 only:

1. change only the detailed task metadata status to `Accepted`;
2. prepare only its Stage 3 index row as `Accepted / PASS / Delivered`;
3. update `tasks/README.md` so Stage 3 remains `In Progress`, S03-BE-005 is
   delivered, and S03-BE-006 is the next execution gate;
4. preserve later-task statuses and do not approve S03-BE-006 unless its own
   reviewed pair is already separately approved;
5. keep this prompt byte-for-byte unchanged and include both owner-prepared
   authority files in delivery;
6. keep Stage 3 not closed and Stage 4 not started;
7. rerun final safe scope/diff/secret/consistency checks and commit:

```text
feat(institution): add user update and lifecycle APIs

Task: S03-BE-005
```

Stage only approved implementation/tests, the detailed task, this unchanged
prompt, Stage 3 index, and README. Push the exact branch, open a PR to `main`,
verify base/head/diff, merge only when safe/green, fast-forward local main, and
prove local main equals origin/main with a clean tree.

Prepared `Accepted / PASS / Delivered` bookkeeping becomes authoritative only
after successful merge and local/remote/clean verification.

Delivery failure after PASS: `FINAL STATUS: DELIVERY BLOCKED`.
Complete delivery: `FINAL STATUS: ACCEPTED`.

Final response must include every detailed-task report item, P1/P2/P3 findings,
smoke decision, exact no-op/timestamp/token-retention/concurrency/rollback/
safe-500 evidence, bookkeeping/delivery evidence, and state:

```text
No User create/delete/password reset, token revocation, Institution Admin/
Platform Owner management, relationship, Group, settings, category, frontend,
or Learning behavior was implemented.
Next implementation gate: S03-BE-006.
```
