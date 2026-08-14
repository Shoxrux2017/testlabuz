# Codex Execution Prompt — S03-BE-007

Execute exactly one approved task:

`S03-BE-007 — Understanding Category Persistence and API`

Repository: `G:\project\testlabuz`

Remote: `https://github.com/Shoxrux2017/testlabuz.git`

Authority task:

`tasks/backend/stage-03/S03-BE-007-understanding-category-persistence-api.md`

Required branch: `task/s03-be-007-understanding-categories`

Read the detailed task completely. It controls this prompt unless a referenced
locked contract is stricter.

## Authority and Dependency Preflight

Read root `AGENTS.md`, `backend/AGENTS.md`, the detailed task,
`tasks/README.md`, `tasks/STAGE_03_TASK_INDEX.md`, accepted S03-INT-001 and
S03-BE-001 through S03-BE-006, relevant `docs/01–09`, accepted Stage 2
Institution/settings persistence, current migration/model/API/test conventions,
and current Git state.

Prove before edits:

```text
S03-INT-001 = Accepted / PASS / Delivered on origin/main
S03-BE-001 through S03-BE-006 = Accepted / PASS / Delivered on origin/main
Stage 3 index/README rows and current-state narrative are internally truthful
local main == origin/main
working tree is clean except only the owner-prepared S03-BE-007 task/prompt
origin is the approved remote
```

This pair may be prepared early, but implementation must stop until S03-BE-006
is delivered. Create/switch to
`task/s03-be-007-understanding-categories`. Stop on unsafe Git, stale/missing
dependency bookkeeping, missing settings-row invariant, schema/contract
conflict, or required scope expansion. Do not commit/push before Phase 2 PASS.

## Implement Only These Endpoints

```text
GET /api/v1/institution/understanding-categories
PUT /api/v1/institution/understanding-categories
```

Middleware order:

```text
auth:sanctum → active.account → password.changed → role:institution_admin
```

Derive the tenant only from the authenticated actor's non-null
`institution_id`. Accept no client tenant, category ID, updater, label,
timestamp, or other ownership override. Scope every category/settings-lock
query to the actor's Institution.

## Exact Persistence and Domain

Create one PostgreSQL `institution_understanding_categories` migration with:

```text
id uuid primary key
institution_id uuid not null → institutions.id ON DELETE RESTRICT
code varchar(40) not null
min_score smallint nullable
max_score smallint nullable
sort_order smallint not null
updated_by_user_id uuid not null → users.id ON DELETE RESTRICT
created_at timestamptz not null
updated_at timestamptz not null
unique(institution_id, code)
```

Use explicit deterministic names for FKs/unique/CHECKs. Database CHECKs enforce
exact fixed codes, exact code-to-sort 1–5, numeric non-null bounds
`0 <= min <= max <= 100`, and `not_completed` null/null. Do not add cross-row
CHECKs, triggers, defaults, seed rows, or speculative indexes.

Create the exact enum/model/factory/domain files from the task. The enum is the
single source for:

```text
1 understood_well          / Understood well          / numeric
2 partially_understood     / Partially understood     / numeric
3 needs_revision           / Needs revision           / numeric
4 needs_teacher_support    / Needs teacher support    / numeric
5 not_completed            / Not completed            / null/null
```

The pure validator canonicalizes arbitrary input array order and requires
exactly one of every fixed code/order. The first four inclusive integer ranges
must cover 0..100 exactly once, high-to-low, with:

```text
order 1 max_score = 100
order 4 min_score = 0
higher.min_score = lower.max_score + 1 for every adjacent pair
```

Reject wrong counts/codes/orders/types/bounds, duplicates, missing entries,
gaps, overlaps, reversal, and non-null `not_completed`. Do not hardcode example
ranges as defaults.

## Exact GET

GET accepts no query key and exactly zero raw body bytes. Any raw body—
whitespace, `{}`, object, array, scalar, JSON null, malformed JSON, text/form/
multipart—returns `422 validation_failed` with `errors.body`; every query key
returns a field-level error. Validation failure and success perform zero writes.

First require the actor's mandatory `institution_settings` row by a scoped
read-only lookup; if missing, return centralized safe `500` without a write or
internal disclosure. Then read only actor-scoped category rows:

```text
0 rows: exact unconfigured 200
5 rows + complete-set validator PASS: exact configured 200
any other count or invalid 5 rows: centralized safe 500; no repair/write/leak
```

Unconfigured response is exactly:

```json
{"data":[],"meta":{"configured":false}}
```

Configured response has only top-level `data`, exactly five fixed-order items,
and each item has exactly these keys in this order:

```text
code
label
min_score
max_score
sort_order
```

Use JSON integers/nulls and enum-derived labels. Return no `message`, `meta`,
`links`, pagination, IDs, tenant/updater/timestamps, relations, counts,
settings, result/history, or other fields. `meta.configured` appears only in the
unconfigured GET response.

## Exact PUT Request

Require `application/json` with an optional charset. The root must be an object
with exactly one key, `categories`, whose value is an array of exactly five
objects. Every object contains exactly:

```text
code
min_score
max_score
sort_order
```

Numeric categories require exact fixed code strings and JSON-integer min/max
0..100 plus the code's exact JSON-integer sort order. `not_completed` requires
min/max present and exactly JSON null, sort 5. Reject numeric strings, floats,
booleans, missing/null numeric values, trimmed/case-folded/aliased codes, and
all unknown/protected root/item fields. Labels are not accepted.

Input array position is not authority: any order may be accepted when the five
objects form the exact fixed code/sort/range set; persistence/output is always
canonical 1–5.

Error rules:

```text
absent/whitespace/malformed/scalar/array/null/non-JSON body → errors.body
{} or invalid count/non-array categories → errors.categories
non-object/missing/unknown/protected/wrong-type item → indexed field error
duplicate/missing/gap/overlap/coverage cross-set failure → errors.categories
every query key → field-level error
```

Use the existing `422 validation_failed` envelope. Every failure leaves all
category/settings/unrelated rows unchanged.

## Exact PUT Transaction, Locking, and State Gate

Pass actor plus the complete normalized set to
`ReplaceInstitutionUnderstandingCategories`. In one transaction:

1. require actor Institution scope;
2. lock the existing actor `institution_settings` row with `lockForUpdate()`;
3. missing lock row → safe `500 server_error`, create/modify nothing;
4. inspect current actor categories: zero permits first creation; exactly five
   valid rows permits no-op/replacement; any partial/corrupt state → safe `500`
   with zero repair/write;
5. validate/canonicalize the incoming full set before category writes;
6. create/upsert all five rows atomically for first configuration, or update/
   upsert all five matched by `(institution_id, code)` for an effective
   replacement;
7. re-read inside the transaction and require the exact valid five-row set.

Locking an empty category query is insufficient. Never create/modify the
settings lock row. Never delete/recreate existing category rows. Preserve every
existing `id` and `created_at`; update only min/max/sort/updater/`updated_at`.

Exact state rules:

```text
same values + every updater already actor:
  zero category DML; preserve all ids/created_at/updated_at

any changed category value:
  replace all five; actor updater on all; same authoritative updated_at on all

same values + any different updater:
  effective all-five updater replacement; same new updated_at on all

first configuration:
  five server UUIDs; actor updater; same server created_at/updated_at on all
```

Concurrent same-Institution first/update operations serialize on the stable
settings row. Prove same-payload no-op, different complete winner without mixed
ranges, exact-five invariant, actor/updater consistency, rollback from empty or
prior valid state, and different-Institution independence using PostgreSQL—not
only mocks/SQLite.

Unexpected failure rolls back the full set and returns safe centralized `500`
without SQL/constraint/exception/stack/body/range/UUID/tenant detail.

PUT success returns exact `200` configured collection with only `data`. Locked
Section 26 defines no success message; do not invent one or return meta/links.

## Exact Change Scope

Change exactly these application/test paths:

```text
backend/database/migrations/<timestamp>_create_institution_understanding_categories_table.php
backend/app/Enums/UnderstandingCategoryCode.php
backend/app/Models/InstitutionUnderstandingCategory.php
backend/database/factories/InstitutionUnderstandingCategoryFactory.php
backend/app/Domain/Institution/UnderstandingCategorySetValidator.php
backend/routes/api.php
backend/app/Http/Controllers/Api/V1/Institution/InstitutionUnderstandingCategoryController.php
backend/app/Http/Requests/Institution/InstitutionUnderstandingCategoryIndexRequest.php
backend/app/Http/Requests/Institution/InstitutionUnderstandingCategoryUpdateRequest.php
backend/app/Actions/Institution/ListInstitutionUnderstandingCategories.php
backend/app/Actions/Institution/ReplaceInstitutionUnderstandingCategories.php
backend/app/Http/Resources/Institution/InstitutionUnderstandingCategoryResource.php
backend/app/Http/Resources/Institution/InstitutionUnderstandingCategoryCollection.php
backend/tests/Feature/Persistence/InstitutionUnderstandingCategoryPersistenceTest.php
backend/tests/Unit/Domain/Institution/UnderstandingCategorySetValidatorTest.php
backend/tests/Feature/Institution/InstitutionUnderstandingCategoryApiTest.php
```

Inspect/reuse existing Institution/User/InstitutionSetting/settings persistence
unchanged. Add no reverse relation merely for convenience. Do not change
settings APIs/schema, auth middleware, locked docs, frontend, learning/result/
snapshot/history, groups, relationships, files, reports, or later-stage code.

## Mandatory Verification

Test every detailed-task requirement, including exact migration/types/named
constraints/RESTRICT FKs/rollback-remigrate; enum/model/factory; pure valid and
invalid set matrix; exact GET/PUT transport/envelopes/key order/types/labels/
exclusions; tenant and middleware precedence; partial/corrupt and missing-
settings safe `500` on GET/PUT; first create/replacement/identity/no-op/updater/
timestamps; complete
rollback; PostgreSQL concurrency; settings/unrelated-row preservation; no
history/result/future-schema behavior; and all Stage 1/2 plus S03-BE-001–006
regressions.

Run from `backend/`:

```text
vendor/bin/pint --test
php artisan test --filter=InstitutionUnderstandingCategory
php artisan test
composer validate --strict
```

Run additional configured backend gates. Manual smoke must PASS when the
controlled backend is available. `NOT RUN` is non-blocking only for a genuine
environment unavailability stated explicitly and only when equivalent automated
PostgreSQL tests pass; smoke FAIL blocks acceptance.

During Phase 1, update only the S03-BE-007 Stage 3 index row to:

```text
In Progress / Not started / Not started
```

Keep the detailed task `Approved` and this prompt byte-for-byte unchanged before
Phase 2. Do not commit or push.

## Strict Read-Only Phase 2

After Phase 1, re-read all authority and inspect the complete diff/tests/
schema/domain/request/resource/tenant/state/no-op/identity/updater/timestamp/
lock/concurrency/rollback/preservation/disclosure/smoke evidence. Phase 2
permits no edit, auto-fix/write-format, bookkeeping change, staging, commit,
push, PR, merge, or self-fix.

Classify findings:

```text
P1 = authorization/tenant/secret-token/protected-field/destructive-Git/read-only breach
P2 = material schema/domain/request/resource/state/no-op/identity/updater/transaction/lock/concurrency/error/test/scope/workflow defect
P3 = non-blocking observation with no correctness/security/evidence impact
```

Any unresolved P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start S03-FE-001. Report P3; P3 alone does
not block acceptance.

## Post-PASS Delivery

After PASS with no unresolved P1/P2 only:

1. change only the detailed task metadata status to `Accepted`;
2. prepare only its Stage 3 index row as `Accepted / PASS / Delivered`;
3. update directly affected Stage 3 index/README narrative truthfully so Stage
   3 remains `In Progress`, S03-BE-007 is delivered, and S03-FE-001 is next;
4. preserve later statuses; do not start/accept S03-FE-001;
5. keep this prompt byte-for-byte unchanged and include both owner-prepared
   authority files in delivery;
6. keep Stage 3 not closed and Stage 4 not started;
7. rerun final safe scope/diff/secret/migration/consistency checks and commit:

```text
feat(institution): add understanding category configuration

Task: S03-BE-007
```

Stage only approved implementation/tests, the task, this unchanged prompt,
Stage 3 index, and README. Push the exact branch, open a PR to `main`, verify
base/head/diff, merge only when safe/green, fast-forward local main, and prove
local main equals origin/main with a clean tree.

Prepared `Accepted / PASS / Delivered` bookkeeping becomes authoritative only
after successful merge and local/remote/clean verification.

Delivery failure after PASS: `FINAL STATUS: DELIVERY BLOCKED`.

Complete delivery: `FINAL STATUS: ACCEPTED`.

Final response must include every detailed-task report item, P1/P2/P3 findings,
smoke decision, exact schema/domain/request/resource/tenant/state/no-op/identity/
updater/timestamp/lock/concurrency/rollback/preservation/safe-500 evidence,
bookkeeping and Git delivery evidence, and state:

```text
No Topic-result calculation, category assignment/snapshot, historical rewrite,
settings mutation, frontend, group, relationship, file, report, or later-stage
behavior was implemented.
Next implementation gate: S03-FE-001.
```
