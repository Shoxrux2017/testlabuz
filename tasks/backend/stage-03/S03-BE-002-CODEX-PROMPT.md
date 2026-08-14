# Codex Execution Prompt — S03-BE-002

Execute exactly one approved task:

`S03-BE-002 — Own Institution Profile API`

Repository: `G:\project\testlabuz`

Remote: `https://github.com/Shoxrux2017/testlabuz.git`

Authority task:

`tasks/backend/stage-03/S03-BE-002-own-institution-profile-api.md`

Required branch: `task/s03-be-002-own-institution-profile`

Read the detailed task completely. It controls this prompt unless a referenced
locked contract is stricter.

## Authority and Dependency Preflight

Read root `AGENTS.md`, `backend/AGENTS.md`, the detailed task,
`tasks/README.md`, `tasks/STAGE_03_TASK_INDEX.md`, accepted S03-INT-001 and
S03-BE-001, relevant `docs/02–09`, accepted Stage 1/2 auth/Institution/Platform
patterns, and current code/tests/Git.

Prove before edits:

```text
S03-INT-001 = Accepted / PASS / Delivered on origin/main
S03-BE-001 = Accepted / PASS / Delivered on origin/main
local main == origin/main
working tree is clean except the owner-prepared S03-BE-002 task/prompt
origin is the approved remote
```

Create/switch to `task/s03-be-002-own-institution-profile`. Stop on unsafe Git,
missing dependency, or contract conflict. Do not commit/push before Phase 2.

## Implement Only These Endpoints

```text
GET   /api/v1/institution/profile
PATCH /api/v1/institution/profile
```

Middleware order:

```text
auth:sanctum → active.account → password.changed → role:institution_admin
```

Derive the Institution only from the authenticated actor. Accept no
Institution ID from route, query, body, or header. Arbitrary tenant-like
headers cannot alter scope.

Exact resource keys in order:

```text
id, name, type, status, contact_email, contact_phone, address, description,
created_at, updated_at
```

GET returns only the normal `data` envelope and has no `message`. It accepts
only zero raw body bytes and no query keys. Whitespace, `{}`, a keyed object,
array, scalar, JSON `null`, malformed JSON, or any query key returns
`422 validation_failed`; body failures include `errors.body`.

PATCH accepts a JSON object with at least one of these keys only:

```text
name, contact_email, contact_phone, address, description
```

Apply the exact detailed-task validation. Reject absent/empty/malformed/
scalar/array/JSON-null bodies, every query key, every unknown key, and all
ownership/type/status/lifecycle/settings/count/user/history keys with `422`
and zero partial mutation. Null clears nullable fields; omitted fields retain
their values; duplicate contact values remain allowed.

A dirty update changes only present validated fields plus backend-managed
`updated_at`. An exact no-op after required `name` trimming returns `200` with
the current resource and exact success message, issues no SQL update, and does
not change `updated_at`. Every successful PATCH returns:

```text
Institution profile updated successfully.
```

Use the existing single-row Eloquent update behavior. Do not invent a
multi-record transaction, optimistic-lock, or idempotency contract.

Create exactly these focused boundaries:

```text
backend/app/Http/Controllers/Api/V1/Institution/InstitutionProfileController.php
backend/app/Http/Requests/Institution/InstitutionProfileShowRequest.php
backend/app/Http/Requests/Institution/InstitutionProfileUpdateRequest.php
backend/app/Actions/Institution/ShowInstitutionProfile.php
backend/app/Actions/Institution/UpdateInstitutionProfile.php
backend/app/Http/Resources/Institution/InstitutionProfileResource.php
backend/tests/Feature/Institution/InstitutionProfileApiTest.php
```

`backend/routes/api.php` is the only other application path allowed to change.
Inspect and preserve the Institution model and accepted Platform code. Request
owns validation, controller stays thin, actions own trusted own-tenant load/
update behavior, and resource owns exact serialization. Never mass-assign raw
request data.

Do not add frontend, migration/model, Institution type/lifecycle/settings,
User Management, Group, Learning, or later-stage behavior.

## Mandatory Verification

Test exact routes/middleware/resource/envelopes/nulls/UTC timestamps; GET body
and query matrix; every allowed PATCH and null clear; omitted retention;
validation limits and all invalid body shapes; protected/unknown/query matrix
with zero partial mutation; exact and trimmed-name no-op with no update query
and unchanged raw `updated_at`; dirty-update field isolation; second-
Institution and fake-header isolation; settings/users/tokens/lifecycle/creator
snapshots; auth/inactive/password/wrong-role precedence; disclosure exclusions;
safe centralized `500 server_error` for controlled load/update failures with
no internal detail or writes; and accepted Platform Institution regressions.

Run from `backend/`:

```text
vendor/bin/pint --test
php artisan test --filter=InstitutionProfileApiTest
php artisan test
composer validate --strict
```

Run all additional configured backend gates. If the controlled backend is
available, manual smoke must PASS. A smoke FAIL blocks acceptance. `NOT RUN` is
non-blocking only when the environment is genuinely unavailable, the reason is
explicit, and equivalent automated contract/tenant/no-op/no-write tests pass.
It cannot hide a startup, configuration, or implementation failure.

During Phase 1, update only the S03-BE-002 Stage 3 index row to
`In Progress / Not started / Not started`. Keep the detailed task `Approved`
and this prompt byte-for-byte unchanged before Phase 2. Do not commit or push.

## Read-Only Gate

After Phase 1, re-read all authority and inspect the complete diff/tests/
security/tenant/input/no-op/no-write/error/smoke evidence. Phase 2 permits no
edit, write-format, bookkeeping change, staging, commit, push, PR, merge, or
self-fix.

Classify findings:

```text
P1 = authorization/tenant/protected-data/secret/destructive-Git/read-only breach
P2 = material GET/PATCH/resource/validation/no-op/error/architecture/test/scope/workflow defect
P3 = non-blocking observation with no correctness/security/evidence impact
```

Any unresolved P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start S03-BE-003. Report P3; P3 alone does
not block acceptance.

## Post-PASS Delivery

After PASS with no unresolved P1/P2 only:

1. change only the detailed task metadata status to `Accepted`;
2. prepare only its Stage 3 index row as `Accepted / PASS / Delivered`;
3. update `tasks/README.md` so Stage 3 remains `In Progress`, S03-BE-002 is
   delivered, and S03-BE-003 is the next execution gate;
4. preserve later-task statuses and do not approve S03-BE-003 unless its own
   reviewed pair is already separately approved;
5. keep this prompt byte-for-byte unchanged and include both owner-prepared
   authority files in delivery;
6. keep Stage 3 not closed and Stage 4 not started;
7. rerun final safe scope/diff/secret/consistency checks and commit:

```text
feat(institution): add own profile management API

Task: S03-BE-002
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
smoke decision, no-op/no-write/safe-500 evidence, bookkeeping/delivery evidence,
and state:

```text
No Institution type/lifecycle mutation, settings, User Management, Group, or
Learning behavior was implemented.
Next implementation gate: S03-BE-003.
```
