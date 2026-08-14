# Codex Task: Understanding Category Persistence and API

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-BE-007` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Backend` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Depends on | `S03-BE-006 — Accepted / PASS / Delivered` |
| Blocks | `S03-FE-001`, `S03-FE-009`, `S03-INT-002` |

This pair may be prepared before its dependency is accepted, but execution must
not start until S03-BE-006 is `Accepted / PASS / Delivered` on `origin/main`.

## 2. Goal

Create the locked Institution understanding-category persistence and allow an
eligible Institution Admin to read or atomically replace the complete fixed
five-category configuration for the authenticated Institution.

Endpoints:

```text
GET /api/v1/institution/understanding-categories
PUT /api/v1/institution/understanding-categories
```

The task owns only the category table/model/fixed-code domain/API. It does not
calculate Topic results, assign categories to results, enforce later dependent
operation errors, or rewrite historical/category snapshots.

## 3. Current Context

Stage 1/2 did not create `institution_understanding_categories`. New
Institutions intentionally start with no category rows and no silent default
ranges. S03-BE-006 depends on the accepted Stage 2 invariant that every
Institution already has exactly one `institution_settings` row. This existing
row is the stable same-Institution PostgreSQL lock target for category PUTs.

Four numeric categories must form one inclusive, high-to-low partition of every
integer score from 0 through 100. `not_completed` is the fifth fixed category
and is always non-numeric.

The only valid persisted states exposed by this API are:

```text
0 rows  = unconfigured
5 rows  = configured only when the complete fixed set passes every invariant
1–4 rows, more than 5 rows, or an invalid five-row set = internal invariant failure
```

GET and PUT must never silently seed, complete, repair, delete, or reinterpret a
partial/corrupt persisted set.

## 4. Included Scope

- Add one forward/rollback-safe PostgreSQL migration matching locked docs 08.
- Add the category model, focused factory, fixed-code enum, and pure complete-set
  validator.
- Add exact GET/PUT routes inside the existing Institution Admin middleware
  group.
- Add separate strict GET and PUT Form Requests, a thin controller, read and
  replacement actions, exact item resource, and exact collection envelope.
- Read and mutate only the authenticated actor's Institution categories.
- Validate the complete five-entry representation before any category write.
- Serialize concurrent first configuration and later replacements by locking
  the actor's mandatory `institution_settings` row.
- Preserve category row identity on replacement and define exact no-op/updater/
  timestamp behavior.
- Add schema/model/domain/API/tenant/security/transaction/concurrency/rollback/
  disclosure/preservation tests.
- During Phase 1, mark only the S03-BE-007 Stage 3 index row as
  `In Progress / Not started / Not started`.
- After Phase 2 PASS, perform only the acceptance/delivery bookkeeping defined
  in Section 14.

## 5. Exact Persistence Contract

### 5.1 Table and Columns

Create exactly one table:

```text
institution_understanding_categories
```

Columns:

```text
id uuid primary key
institution_id uuid not null
code varchar(40) not null
min_score smallint nullable
max_score smallint nullable
sort_order smallint not null
updated_by_user_id uuid not null
created_at timestamptz not null
updated_at timestamptz not null
```

Use the repository's accepted UUID and timezone-aware timestamp conventions.
Application-created identifiers and timestamps are server-owned. The client
cannot submit them.

### 5.2 Fixed Codes, Labels, and Order

One enum is the sole application source of truth for code, label, fixed order,
and numeric/non-numeric behavior:

| Order | Code | Fixed label | Persisted range shape |
|---:|---|---|---|
| 1 | `understood_well` | `Understood well` | integer/integer |
| 2 | `partially_understood` | `Partially understood` | integer/integer |
| 3 | `needs_revision` | `Needs revision` | integer/integer |
| 4 | `needs_teacher_support` | `Needs teacher support` | integer/integer |
| 5 | `not_completed` | `Not completed` | null/null |

Labels are derived at serialization time and are never stored or accepted from
the client.

### 5.3 Required Database Constraints

Use explicit deterministic names within PostgreSQL identifier limits for all
foreign keys, unique constraints, and CHECK constraints. The migration must
enforce:

- primary key on `id`;
- foreign key `institution_id → institutions.id` with `ON DELETE RESTRICT`;
- foreign key `updated_by_user_id → users.id` with `ON DELETE RESTRICT`;
- unique `(institution_id, code)`;
- `code` is exactly one of the five fixed values;
- each fixed code maps to its exact `sort_order` 1–5;
- the first four codes require non-null smallint min/max with
  `0 <= min_score <= max_score <= 100`;
- `not_completed` requires `min_score IS NULL AND max_score IS NULL`.

The unique constraint supplies the required actor-Institution/code lookup
prefix. Add no speculative index that is not required by the locked docs or an
evidenced current query.

Cross-row completeness, coverage, adjacency, gap, overlap, duplicate sort, and
high-to-low rules must be enforced by the pure domain validator inside the
transaction. Do not attempt an unsafe cross-row CHECK and do not add a trigger,
generated default ranges, or seed data.

### 5.4 Model and Factory Boundary

`InstitutionUnderstandingCategory` must:

- use the accepted UUID model convention;
- map `code` to the fixed enum;
- cast `min_score`, `max_score`, and `sort_order` as nullable/integer values as
  applicable;
- expose only the fields required by trusted action persistence in its
  mass-assignment boundary;
- define focused `belongsTo` Institution and updater relations used by model
  contract tests, without eager loading them in this API.

The focused factory exists only for deterministic persistence/API test setup.
It must not create an arbitrary invalid default category set or silently seed
production data.

## 6. Exact Complete-Set Domain Contract

`UnderstandingCategorySetValidator` is a pure, independently testable domain
component. It accepts normalized category entries and either returns the
canonical fixed-order representation or reports validation failure without
querying or mutating the database.

Input array position is not authority. The client may send the five objects in
any array order, but `code` and `sort_order` must describe the exact fixed map,
and all output/persistence processing is canonical order 1–5.

The validator must enforce all of the following together:

- exactly five entries;
- exactly one entry for each fixed code;
- no duplicate, missing, or unknown code;
- exact code-to-sort-order mapping and no duplicate/missing order;
- numeric categories have JSON-integer-normalized min/max values;
- `not_completed` has exact null/null min/max;
- every numeric bound is within 0..100 and `min_score <= max_score`;
- `understood_well.max_score = 100`;
- `needs_teacher_support.min_score = 0`;
- for each adjacent high-to-low numeric pair:

  ```text
  higher.min_score = lower.max_score + 1
  ```

- therefore the four inclusive ranges cover every integer 0..100 exactly once,
  with no gap, overlap, reversal, or out-of-order interpretation.

Document examples such as 86–100 are examples, not hardcoded universal
defaults. This task must accept every complete integer partition that satisfies
the locked invariants.

## 7. Exact API Contract

### 7.1 Middleware and Tenant Authority

Both endpoints use this exact middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:institution_admin
```

The authenticated Institution Admin's non-null `institution_id` is the only
tenant authority. No route parameter, query key, body field, header, cookie,
category UUID, Institution UUID, or updater UUID may choose or override scope.

Middleware runs before Form Request validation. Every category query includes:

```text
institution_understanding_categories.institution_id = actor.institution_id
```

### 7.2 Missing Stable Lock Row

For GET, require the actor's existing `institution_settings` row with a scoped
read-only existence lookup before interpreting categories. For PUT, select that
same row with `lockForUpdate()` inside the category transaction before
inspecting or writing category rows. Locking an empty category query is
insufficient for first configuration.

For either endpoint, if the mandatory settings row is missing:

- treat it as an internal persistence invariant failure;
- create no settings or category row and modify nothing;
- return the centralized safe `500 server_error`;
- reveal no tenant UUID, table, SQL, constraint, exception, stack, payload, or
  internal detail.

Never use `firstOrCreate`, `updateOrCreate`, or another repair path for the lock
row.

### 7.3 GET Transport Contract

```text
GET /api/v1/institution/understanding-categories
```

GET accepts no query key and exactly zero raw request-body bytes.

- every query key returns `422 validation_failed` with a field-level error;
- whitespace, `{}`, keyed object, array, scalar, JSON `null`, malformed JSON,
  raw text, form, or multipart body returns `422` with `errors.body`;
- a content-type header with an empty body does not add input, but any raw body
  bytes are rejected regardless of media type;
- validation failure and successful GET perform zero writes and preserve every
  category/settings updater and timestamp;
- after validation, the read action verifies the actor-scoped mandatory
  settings row, then loads only actor-scoped categories ordered canonically,
  without loading Institution, updater, User, file, learning, result, or
  history relationships.

### 7.4 GET State Interpretation

After the scoped read:

```text
0 category rows:
  return the exact unconfigured response

exactly 5 rows and complete-set validator passes:
  return the exact configured response

any other count or validator failure:
  return centralized safe 500 server_error
```

A corrupt state must not be returned as configured or unconfigured and must not
be silently repaired, deleted, reseeded, or exposed. GET still performs no
write.

### 7.5 Exact GET Success Responses

Unconfigured `200 OK` returns exactly:

```json
{
  "data": [],
  "meta": {
    "configured": false
  }
}
```

`meta.configured` is a JSON boolean and appears only for the unconfigured GET.
There are no other top-level or nested metadata keys.

Configured `200 OK` returns exactly one top-level key, `data`, containing all
five items in fixed order:

```json
{
  "data": [
    {
      "code": "understood_well",
      "label": "Understood well",
      "min_score": 86,
      "max_score": 100,
      "sort_order": 1
    },
    {
      "code": "partially_understood",
      "label": "Partially understood",
      "min_score": 71,
      "max_score": 85,
      "sort_order": 2
    },
    {
      "code": "needs_revision",
      "label": "Needs revision",
      "min_score": 51,
      "max_score": 70,
      "sort_order": 3
    },
    {
      "code": "needs_teacher_support",
      "label": "Needs teacher support",
      "min_score": 0,
      "max_score": 50,
      "sort_order": 4
    },
    {
      "code": "not_completed",
      "label": "Not completed",
      "min_score": null,
      "max_score": null,
      "sort_order": 5
    }
  ]
}
```

The numbers above are a valid example only. Every configured response uses the
stored valid ranges.

Each item has exactly the five keys shown in that order. Scores/order are JSON
integers or the required JSON nulls. Return no success `message`, `meta`,
`links`, pagination, category/Institution/User UUID, updater, timestamps,
relations, counts, settings, results, history, or other field.

### 7.6 PUT Transport and Root Shape

```text
PUT /api/v1/institution/understanding-categories
```

PUT requires `Content-Type: application/json`; an optional charset parameter is
allowed. The top-level JSON value must be an object containing exactly one key:

```text
categories
```

`categories` must be a JSON array of exactly five JSON objects. Each object
must contain exactly these four keys:

```text
code
min_score
max_score
sort_order
```

Example:

```json
{
  "categories": [
    {
      "code": "understood_well",
      "min_score": 86,
      "max_score": 100,
      "sort_order": 1
    },
    {
      "code": "partially_understood",
      "min_score": 71,
      "max_score": 85,
      "sort_order": 2
    },
    {
      "code": "needs_revision",
      "min_score": 51,
      "max_score": 70,
      "sort_order": 3
    },
    {
      "code": "needs_teacher_support",
      "min_score": 0,
      "max_score": 50,
      "sort_order": 4
    },
    {
      "code": "not_completed",
      "min_score": null,
      "max_score": null,
      "sort_order": 5
    }
  ]
}
```

Body-shape/error-key rules:

- absent raw body, whitespace-only body, malformed JSON, scalar, array, JSON
  `null`, form, multipart, text, or other non-JSON media returns
  `422 validation_failed` with `errors.body`;
- `{}` is a valid object but returns a required error in `errors.categories`;
- every query key is rejected with a field-level error;
- every unknown/protected root key rejects the entire request under its field
  key;
- non-array or wrong-length `categories` fails under `errors.categories`;
- a non-object array entry fails under `errors.categories.<index>`;
- a missing, unknown, protected, or wrong-type item field fails under its
  indexed path when attributable;
- duplicate/missing-set, gap/overlap/coverage, or other cross-entry invariant
  failure is reported under `errors.categories`;
- every validation failure performs zero category/settings/unrelated mutation.

Use the existing locked validation envelope/messages. Do not invent a new error
envelope or disclose internal validation/SQL implementation.

### 7.7 PUT Exact Field Rules

For each numeric category:

```text
code:       required exact fixed JSON string
min_score:  required JSON integer, inclusive 0..100
max_score:  required JSON integer, inclusive 0..100
sort_order: required JSON integer equal to the code's fixed order
```

For `not_completed`:

```text
code:       exact "not_completed"
min_score:  required and exactly JSON null
max_score:  required and exactly JSON null
sort_order: required JSON integer 5
```

Do not coerce numeric strings, floats such as `1.0`, booleans, nulls for numeric
categories, or strings for required nulls/integers. Do not trim, lowercase,
case-fold, alias, or silently normalize code strings. Item array order may vary,
but codes, fixed sort values, complete-set invariants, persisted order, and
response order may not.

Labels are server-fixed and are not input. Protected item keys include at
least:

```text
label
id
category_id
institution_id
updated_by_user_id
created_at
updated_at
configured
meta
links
color
icon
name
result_id
score
```

Any other non-allowlisted root or item key is also rejected; valid fields are
never partially applied.

### 7.8 Existing-State Gate Before PUT

After validating the complete incoming representation and locking the settings
row, read the current actor-scoped categories in the same transaction:

```text
0 rows:
  first configuration is allowed

exactly 5 rows and complete-set validator passes:
  replacement/no-op evaluation is allowed

any other count or validator failure:
  safe invariant 500; zero writes; no repair
```

The incoming valid representation is not permission to repair an invalid
stored representation.

### 7.9 Atomic First Configuration and Replacement

`ReplaceInstitutionUnderstandingCategories` owns one transaction:

1. require the actor's non-null Institution scope;
2. lock the actor's existing `institution_settings` row with
   `lockForUpdate()`; missing row follows Section 7.2;
3. load and classify the existing actor-scoped category set under Section 7.8;
4. validate/canonicalize the complete incoming set before category writes;
5. determine the effective no-op/replacement state;
6. for first configuration, generate five server UUIDs and insert/upsert the
   canonical set with one authoritative server timestamp and actor updater;
7. for an effective replacement, update/upsert all five matched-by-code rows as
   one complete set with actor updater and one authoritative server timestamp;
8. re-read the exact actor-scoped canonical set inside the transaction, require
   exactly five valid rows, and return that committed representation.

Existing replacement rows must preserve their `id` and `created_at`. Never
delete/recreate them. An upsert may use only `(institution_id, code)` as its
conflict identity and may update only:

```text
min_score
max_score
sort_order
updated_by_user_id
updated_at
```

Never accept or update `institution_id`, `id`, or `created_at` from client data.
Never write categories before the stable lock and complete validation. Never
touch the lock/settings row except to read and lock it.

Incoming complete-set validation failures return the existing atomic `422`
contract before category writes. Stored-invariant, constraint, or unexpected
application/database failures roll back the entire set and return centralized
safe `500 server_error` without SQL, constraint, exception, stack, payload,
range, UUID, actor, or tenant detail.

### 7.10 Exact No-Op, Updater, and Timestamp Rules

Compare the canonical incoming ranges/order and the server-derived updater to
the fresh valid rows after the stable lock:

- same five values and every row already has `updated_by_user_id = actor.id`:
  execute no category insert/update/upsert, preserve every exact `updated_at`,
  `id`, and `created_at`, and return the current canonical collection;
- any range/order-effective value differs: replace all five as one complete
  representation, set every updater to the actor, and set every `updated_at` to
  the same authoritative server time;
- same category values but at least one row has another updater: this is an
  effective replacement; set all five updaters to the actor and advance all
  five `updated_at` values to the same authoritative server time;
- first configuration gives all five rows the same server-owned `created_at`
  and `updated_at` and the actor updater;
- public responses never expose identifiers, updater, or timestamps.

### 7.11 Concurrent Behavior

PostgreSQL evidence must prove the stable settings-row lock provides these
semantics:

- concurrent first configurations for one Institution serialize and never
  create duplicate/partial rows;
- same-payload/same-actor races produce at most one effective transition; the
  later transaction sees the committed set and becomes an exact no-op;
- different valid payloads for one Institution never mix fields/ranges; final
  storage equals one complete request, belonging to the transaction that wins
  after serialization;
- same values from a different eligible actor are an effective updater change
  across all five rows;
- every successful response represents that transaction's own complete valid
  set;
- each failure leaves either the prior valid five rows or the prior empty state,
  never 1–4 rows;
- different Institutions lock different settings rows and remain tenant-
  independent.

A mocked, SQLite-only, or empty-category-query locking assertion is
insufficient.

### 7.12 PUT Success — `200 OK`

PUT returns the exact configured collection shape from Section 7.5:

```text
only top-level data
exactly five fixed-order items
exact item keys/types/labels
```

The locked Section 26 contract defines no PUT success message. Do not return:

```text
Institution understanding categories updated successfully.
```

Do not add `message`, `meta`, `links`, pagination, or any private/additional
field.

### 7.13 Historical and Later-Operation Preservation

Changing ranges makes the current valid configuration available only to future
or explicitly recalculated eligible operations owned by later tasks. This task
must not:

- calculate a Topic/Student result or assign a category;
- implement later result-time `409 category_configuration_invalid` behavior;
- silently recalculate or rewrite closed/calculated results;
- rewrite a stored category code/label/range snapshot;
- alter learning material, submission, Homework, Blitz, attempt, question,
  answer, score, release, file, group, relationship, or history data;
- mutate `institution_settings`, Institution, User, token, or another tenant's
  category row;
- add future result/snapshot tables merely to test non-goals.

Where a later table does not yet exist, preservation is proven by exact change
scope and absence of that behavior, not by inventing premature schema.

## 8. Exact Files and Responsibilities

Codex must inspect accepted patterns but change only these application/test
paths:

| File | Expected action | Responsibility |
|---|---|---|
| `backend/database/migrations/<timestamp>_create_institution_understanding_categories_table.php` | Create one file | Exact table/explicit constraints/rollback |
| `backend/app/Enums/UnderstandingCategoryCode.php` | Create | Sole fixed code/label/order/range-kind source |
| `backend/app/Models/InstitutionUnderstandingCategory.php` | Create | UUID persistence/casts/focused relations |
| `backend/database/factories/InstitutionUnderstandingCategoryFactory.php` | Create | Focused deterministic test support |
| `backend/app/Domain/Institution/UnderstandingCategorySetValidator.php` | Create | Pure canonical complete-set validation |
| `backend/routes/api.php` | Modify | Register exact GET/PUT routes once |
| `backend/app/Http/Controllers/Api/V1/Institution/InstitutionUnderstandingCategoryController.php` | Create | Thin `index`/`update` adapters |
| `backend/app/Http/Requests/Institution/InstitutionUnderstandingCategoryIndexRequest.php` | Create | Zero-body/query GET contract |
| `backend/app/Http/Requests/Institution/InstitutionUnderstandingCategoryUpdateRequest.php` | Create | Strict complete PUT JSON/allowlist/types |
| `backend/app/Actions/Institution/ListInstitutionUnderstandingCategories.php` | Create | Scoped read/state classification |
| `backend/app/Actions/Institution/ReplaceInstitutionUnderstandingCategories.php` | Create | Lock/transaction/state gate/no-op/upsert/rollback |
| `backend/app/Http/Resources/Institution/InstitutionUnderstandingCategoryResource.php` | Create | Exact item keys/types/fixed label |
| `backend/app/Http/Resources/Institution/InstitutionUnderstandingCategoryCollection.php` | Create | Exact configured/unconfigured envelopes/order |
| `backend/tests/Feature/Persistence/InstitutionUnderstandingCategoryPersistenceTest.php` | Create | Migration/model/constraint/rollback evidence |
| `backend/tests/Unit/Domain/Institution/UnderstandingCategorySetValidatorTest.php` | Create | Pure complete-set matrix |
| `backend/tests/Feature/Institution/InstitutionUnderstandingCategoryApiTest.php` | Create | HTTP/security/tenant/transaction/concurrency proof |
| existing Institution/User/InstitutionSetting models and settings migration | Inspect/reuse unchanged | Existing ownership/updater/stable-lock persistence |
| `tasks/STAGE_03_TASK_INDEX.md` | Modify only as Section 14 permits | Truthful execution/review/delivery state |
| `tasks/README.md` | Modify only after Phase 2 PASS | Truthful Stage 3 current/next gate |
| this detailed task | Status metadata only after Phase 2 PASS | Final accepted task state |
| paired Codex prompt | Preserve byte-for-byte | Approved execution authority |

Do not modify existing Institution/User/InstitutionSetting models merely to add
optional reverse relations; the new model's forward relations are sufficient.
No additional application/test path may change. Stop instead of widening the
allowlist if accepted current persistence cannot support the task safely.

## 9. Authoritative References

| Document | Exact area | Requirement |
|---|---|---|
| `docs/01-project-overview.md`, `docs/03-features.md` | understanding categories | Product meaning and fixed MVP behavior |
| `docs/02-user-roles.md`, `docs/04-user-flows.md` | Institution Admin authority/settings flow | Actor and flow boundary |
| `docs/05-business-rules.md` | BR-CAT-001–016 and result/history rules | Fixed meanings, integer partition, preservation |
| `docs/06-roadmap.md` | `8. Stage 3` | Stage ownership and non-goals |
| `docs/07-architecture.md` | auth/tenant/layer/transaction/testing | Organization/security/concurrency |
| `docs/08-database.md` | Section 8.2 and constraint/FK/history rules | Exact schema and persistence invariants |
| `docs/09-api-contracts.md` | Sections 1–3, 26 and error registry | Exact requests/responses/errors |
| accepted S03-BE-006 and Stage 2 Institution settings persistence | mandatory settings row | Stable lock target/invariant |
| `backend/AGENTS.md` | entire applicable file | Backend rules and gates |

If this task conflicts with a stricter locked document, stop and report the
conflict instead of silently changing the contract or locked docs.

## 10. Architecture, Security, and Error Requirements

- Request classes own raw-body/media/query/root/item allowlists and simple JSON
  shape/type validation.
- The pure validator owns the canonical complete-set rules and performs no I/O.
- The controller obtains the authenticated actor, calls one action, and returns
  the exact collection without adding messages/metadata.
- The read action owns tenant scope and stored-state classification.
- The replacement action owns stable locking, transaction, stored-state gate,
  no-op/effective decision, first insert/upsert, identity preservation, updater,
  timestamps, re-read, and rollback.
- Resource classes own only exact public shape/types/labels/envelopes and perform
  no query or mutation.
- Never mass-assign raw request data, trust client identifiers/updater/labels,
  use unscoped category queries, eager-load private relations, or repair an
  invariant failure.
- Preserve centralized middleware/error precedence for unauthenticated,
  inactive actor, inactive Institution, first-login actor, wrong role,
  validation, and unexpected failures.
- Safe `500` responses/logging must not disclose credentials, tokens, request
  bodies, ranges, PII, Institution/User/category UUIDs, SQL, constraints,
  exceptions, or stack traces.

## 11. Acceptance Criteria

- [ ] The exact migration/table/types/nullability/explicit named constraints/
      RESTRICT FKs/unique/checks and isolated rollback match locked docs.
- [ ] The enum is the sole fixed code/label/order/range-kind authority.
- [ ] The model/factory contracts are focused, UUID-safe, and do not seed
      production/default ranges.
- [ ] The pure validator accepts every valid integer partition and rejects every
      incomplete/duplicate/unknown/order/type/boundary/gap/overlap case.
- [ ] Exact GET/PUT routes exist once with exact middleware order and actor-only
      tenant authority.
- [ ] GET rejects every body/query input, performs zero writes, and returns the
      exact unconfigured or configured envelope/order/types/exclusions.
- [ ] A partial/corrupt stored set returns safe `500` on GET and PUT with zero
      repair/mutation/disclosure.
- [ ] PUT requires JSON with exactly `categories` and exactly five exact-shaped
      objects; every body/media/query/root/item/type/protected violation is
      atomic.
- [ ] First PUT locks the mandatory settings row and creates exactly five
      server-owned actor-scoped rows atomically.
- [ ] Replacement preserves IDs/`created_at`, never delete/recreates, and uses
      one complete actor-updated representation and authoritative timestamp.
- [ ] Exact same-actor no-op executes no category write and preserves every
      `updated_at`; updater change is an effective all-five replacement.
- [ ] Same-Institution concurrent first/update calls serialize without partial,
      duplicate, mixed, stale, or cross-tenant state; different tenants remain
      independent.
- [ ] Missing settings lock row and controlled failures roll back fully and
      return safe non-disclosing `500 server_error`.
- [ ] PUT returns only the exact configured `data` collection; no invented
      message/meta/links/private fields.
- [ ] Settings, Institution, Users, tokens, other tenants, learning/results/
      history and every unrelated row remain unchanged.
- [ ] Full Stage 1/2 and accepted Stage 3 predecessor/backend regressions pass.
- [ ] No result calculation, category assignment/snapshot, frontend, settings
      API/schema, later-operation error, or other later-stage behavior appears.

## 12. Tests and Verification

### 12.1 Persistence Tests

- fresh PostgreSQL migration verifies exact table/column types/nullability,
  UUID PK, timestamptz, unique and every named CHECK/FK with RESTRICT behavior;
- valid insertion for each fixed code and complete five-row set;
- reject unknown code, wrong code/order mapping, numeric null, out-of-bounds,
  min greater than max, non-null `not_completed`, duplicate Institution/code,
  missing Institution/updater, and restricted parent deletion;
- same code may exist independently for two Institutions;
- model UUID generation, enum/integer casts, fillable boundary, and focused
  Institution/updater relations;
- rollback removes only the new table; accepted earlier tables/data survive;
  fresh migrate → rollback → remigrate succeeds.

### 12.2 Pure Domain Tests

- representative valid partitions including single-point and wide ranges;
- arbitrary input array order canonicalizes to fixed output order;
- first numeric max not 100, last numeric min not 0, gap, overlap, reversed
  bound, out-of-range bound, duplicate/missing/unknown code, duplicate/missing/
  wrong sort order, invalid `not_completed`, wrong count, and every adjacent
  boundary failure;
- validator performs no database query/write and does not invent defaults.

### 12.3 API, Transaction, and Security Tests

- routes registered once with exact methods/paths/middleware order;
- GET body matrix: whitespace, `{}`, keyed object, array, scalar, null,
  malformed JSON, text/form/multipart; every query key; exact validation errors
  and zero writes/timestamp/updater changes;
- unconfigured GET exact `data=[]` plus only `meta.configured=false`;
- configured GET exact five resources, key order, labels, fixed order, integer/
  null types, only top-level `data`, and no metadata/private disclosure;
- PUT media/body matrix: absent, whitespace, malformed, scalar, array, null,
  non-JSON, `{}`, missing/wrong-length/non-array categories, non-object item;
- omission of every item field; numeric strings, floats, booleans/nulls, invalid
  code case/spacing, invalid numeric/null shapes, bounds and order;
- every protected item key from Section 7.7, representative arbitrary unknown
  item/root keys, every query key, and valid+invalid mixed payloads prove zero
  partial write;
- every valid complete partition and arbitrary input order returns/persists
  canonical order; duplicate/missing/unknown code/order, gap, overlap, uncovered
  boundary, and reversal return `422` with old state byte-for-byte unchanged;
- first configuration creates exactly five server UUID rows with one tenant,
  actor updater, same authoritative timestamps, and exact values;
- configured replacement preserves all IDs/`created_at`, updates the complete
  five-row representation/updater/timestamp together, and never delete/recreates;
- same-values/same-actor no-op proves zero category DML and exact unchanged
  timestamps; same-values/different-actor proves effective all-five updater/
  timestamp change;
- current partial or cross-row-invalid five-row set makes both GET and PUT
  return safe `500`, performs zero repair/write, and reveals no internal detail;
- missing settings row makes GET and PUT return safe `500`, creates no settings
  or category row, and reveals no internal detail;
- controlled failure during first configuration leaves zero rows; failure
  during replacement preserves the prior valid rows byte-for-byte; both return
  centralized safe `500` without SQL/constraint/exception/stack/body/range/UUID
  disclosure;
- real PostgreSQL races cover same/different first payloads, same payload/same
  actor update, different payload update, different actor same values, complete
  winner semantics, exact-five invariant, and different-Institution independence;
- own versus second Institution reads/updates and before/after snapshots prove
  no tenant identifier/header/query/body can cross scope;
- unauthenticated, inactive actor, inactive actor Institution,
  `must_change_password = true`, and Platform Owner/Teacher/Student/Parent
  wrong-role precedence, including invalid input where required;
- settings lock row remains byte-for-byte unchanged after GET, success, no-op,
  validation failure, invariant failure, and rollback;
- Institution/User/token/other settings and all existing unrelated rows remain
  unchanged; no result/history/future table is introduced or rewritten;
- accepted Stage 2 Institution initialization/settings persistence,
  S03-BE-001–006, and full Stage 1/2/backend regressions remain green.

### 12.4 Quality Gates

From `backend/`, run current repository-valid equivalents of:

```text
vendor/bin/pint --test
php artisan test --filter=InstitutionUnderstandingCategory
php artisan test
composer validate --strict
```

Run every additional configured backend security/static gate required by
`backend/AGENTS.md`. Any required failure blocks acceptance.

### 12.5 Manual Smoke

Using controlled Institution Admin credentials that are never recorded in
reports or logs:

1. GET an unconfigured Institution and verify the exact unconfigured envelope.
2. PUT one complete valid partition, reload, and verify exact canonical output.
3. Repeat the same PUT and verify exact no-op/timestamp behavior.
4. PUT a different valid partition and verify identity preservation and full
   replacement.
5. Submit malformed, missing, protected, gap, overlap, and query cases and prove
   the prior set is unchanged.
6. Use a second Institution and prove strict isolation.
7. Confirm the settings lock row and all existing unrelated rows are unchanged.

If the controlled backend is available, smoke must PASS. A smoke `FAIL` always
blocks acceptance. `NOT RUN` is non-blocking only when the environment is
genuinely unavailable, the exact reason is reported, and equivalent automated
PostgreSQL contract/tenant/atomicity/concurrency/preservation tests pass. Do not
use `NOT RUN` to hide a startup, configuration, or implementation failure.

## 13. Explicit Non-Goals and Stop Conditions

### 13.1 Non-Goals

- Custom category codes, names, labels, colors, icons, or decimal ranges.
- Automatic default seeding/configuration or repair of corrupt data.
- Topic/Student result calculation, comparison, category assignment,
  recalculation, release, snapshot creation, or history rewrite.
- Implementing later `409 category_configuration_invalid` enforcement.
- Settings API/schema/model changes or configurable attempt/upload policy.
- Frontend, reports, files, groups, relationships, learning flows, or Stage 4.
- Editing the fixed meaning or numeric shape of `not_completed`.
- Adding future result/history tables solely for this task.

### 13.2 Stop Conditions

Stop on missing accepted S03-BE-006 dependency, stale Stage 3 bookkeeping,
missing mandatory settings-row invariant, schema/locked-contract conflict,
inability to enforce a stable transaction lock or atomic complete set,
requirement to modify existing settings/Institution/User persistence, need to
repair corrupt data, need to alter results/history, unsafe Git state, or any
material expansion beyond the exact file allowlist.

## 14. Required Workflow and Delivery

### Phase 0 — Git and Authority Preflight

1. Read the paired execution prompt and this task completely.
2. Verify this detailed task is `Approved` and the prompt/task pair is the only
   owner-prepared S03-BE-007 authority.
3. Read root `AGENTS.md`, `backend/AGENTS.md`, `tasks/README.md`, Stage 3 index,
   S03-INT-001, accepted S03-BE-001 through S03-BE-006, locked references, and
   current migration/model/API/test conventions.
4. Prove S03-INT-001 and S03-BE-001 through S03-BE-006 are each
   `Accepted / PASS / Delivered` on `origin/main`.
5. Verify Stage 3 index/README rows and current-state narrative are internally
   truthful; stop on stale dependency bookkeeping instead of assuming delivery.
6. Verify the exact approved remote, fetch safely, and prove
   `local main == origin/main`.
7. Verify the working tree is clean except only the owner-prepared S03-BE-007
   detailed task and paired prompt.
8. Create/switch to `task/s03-be-007-understanding-categories`.
9. Preserve unrelated user work and stop on unsafe/dirty/conflicting state.
10. Do not commit, push, create a PR, or merge before Phase 2 PASS.

### Phase 1 — Implementation

Implement only this task. Application/test changes are limited to the exact
paths in Section 8, including exactly one timestamped migration. Existing
Institution/User/InstitutionSetting/settings persistence must remain unchanged.

Update only the S03-BE-007 row in `tasks/STAGE_03_TASK_INDEX.md` to:

```text
In Progress / Not started / Not started
```

Keep this detailed task `Approved` and preserve the paired prompt byte-for-byte
before Phase 2. Run all automated gates, scope/secret checks, and the manual
smoke rule. Inspect the complete diff including the owner-prepared task/prompt.
Do not commit or push.

### Phase 2 — Strict Read-Only Acceptance Gate

Re-read the authority task, locked Section 26 and database/business rules,
accepted settings-lock persistence, complete diff, code/tests, schema/
constraints/enum/model/domain/request/resource/tenant/state-machine/no-op/
identity/updater/timestamp/lock/concurrency/rollback/preservation/disclosure and
smoke evidence. Phase 2 is strictly read-only:

```text
no edits or auto-fix/write-format
no task/index/README bookkeeping edits
no staging or commit
no push, PR, or merge
no self-fixing findings
```

Classify findings:

- `P1`: authorization/tenant/secret/token/protected-field/destructive-Git or
  read-only-gate violation;
- `P2`: material schema/constraint/model/domain/request/resource/state/no-op/
  identity/updater/transaction/lock/concurrency/error/preservation/test/scope/
  workflow/bookkeeping mismatch;
- `P3`: non-blocking observation with no correctness, security, required
  evidence, or maintainability-acceptance impact.

Any unresolved P1 or P2 requires:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start S03-FE-001. Report every P3; P3 alone
does not block acceptance.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 PASS with no unresolved P1/P2.

1. Change only this detailed task's metadata status from `Approved` to
   `Accepted`; do not rewrite approved behavior.
2. Prepare only the S03-BE-007 index row as
   `Accepted / PASS / Delivered` in the delivery commit.
3. Update directly affected Stage 3 index/README current-state narrative
   truthfully: Stage 3 remains `In Progress`, S03-BE-007 is delivered, and
   S03-FE-001 is the next implementation gate.
4. Preserve all later-task statuses; do not mark S03-FE-001 accepted or started.
5. Keep the paired Codex prompt byte-for-byte unchanged and include both
   owner-prepared authority files in the focused delivery commit.
6. Keep Stage 3 not closed and Stage 4 not started.
7. Re-run final non-writing diff, scope, secret, migration, and consistency
   checks.
8. Stage only the approved implementation/tests, this task, its unchanged
   prompt, `tasks/STAGE_03_TASK_INDEX.md`, and `tasks/README.md`.
9. Commit:

   ```text
   feat(institution): add understanding category configuration
   ```

   Body:

   ```text
   Task: S03-BE-007
   ```

10. Push the exact task branch, open a PR to `main`, verify base/head/diff, and
    merge only when required checks are safe/green and merge is permitted.
11. Fast-forward local `main` and verify local `main == origin/main` with a clean
    working tree.

Prepared `Accepted / PASS / Delivered` bookkeeping becomes authoritative only
after the delivery commit is merged and local/remote/clean verification passes.
If Phase 2 passed but safe delivery cannot complete, return:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Only after complete delivery return:

```text
FINAL STATUS: ACCEPTED
```

## 15. Required Codex Final Report

Report final status, dependency/index/Git preflight evidence, exact changed
files, migration/schema/constraint/model/enum/domain/API implementation, every
acceptance criterion and command/result, request/response/type/tenant/state/
no-op/identity/updater/timestamp/lock/concurrency/rollback/safe-500/disclosure/
preservation evidence, PostgreSQL migration/rollback and race evidence, Stage
1/2 and S03-BE-001–006 regressions, P1/P2/P3 findings, smoke status/blocking
decision, scope/secret checks, bookkeeping, PR/merge/local-remote-clean delivery
evidence.

State exactly:

```text
No Topic-result calculation, category assignment/snapshot, historical rewrite,
settings mutation, frontend, group, relationship, file, report, or later-stage
behavior was implemented.
Next implementation gate: S03-FE-001.
```
