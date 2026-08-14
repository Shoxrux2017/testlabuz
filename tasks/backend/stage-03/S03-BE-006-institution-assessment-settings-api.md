# Codex Task: Institution Assessment Settings API

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-BE-006` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Backend` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Depends on | `S03-BE-005 — Accepted / PASS / Delivered` |
| Blocks | `S03-BE-007`, `S03-FE-008`, `S03-INT-002` |

This pair may be prepared before its dependency is accepted, but execution must
not start until S03-BE-005 is `Accepted / PASS / Delivered` on `origin/main`.

## 2. Goal

Allow an eligible Institution Admin to read and completely replace the current
assessment-policy settings for the authenticated Institution while preserving
fixed MVP attempt rules, platform upload maxima, active-operation snapshots,
absolute historical timestamps, calculated results, and strict tenant
authority.

Endpoints:

```text
GET /api/v1/institution/settings/assessment
PUT /api/v1/institution/settings/assessment
```

## 3. Current Context

Stage 2 creates exactly one `institution_settings` row in the same transaction
as each Institution. The accepted persistence already provides:

```text
timezone = Asia/Tashkent
learning_material_max_mb = 25
student_submission_max_mb = 15
acceptable_score_difference = null
blitz_timer_start_mode = null
student_result_release_mode = null
parent_result_release_mode = null
updated_by_user_id = null
```

The existing `InstitutionSetting` model, enum casts, database precision/checks,
foreign keys, and `CreatePlatformInstitution` platform-limit constants are
sufficient and must be reused unchanged. This task adds only the Section 12
GET/PUT HTTP boundary and current-row mutation behavior. Understanding-category
persistence/API remains S03-BE-007.

## 4. Included Scope

- Register the exact GET/PUT routes once in the existing Institution Admin
  middleware group.
- Add one thin singleton settings controller.
- Add separate strict GET and PUT Form Requests.
- Add one own-Institution read action and one transaction/row-lock update
  action.
- Add one exact assessment-settings resource.
- Read/update only the existing row keyed by the authenticated actor's
  Institution.
- Require a complete seven-field PUT representation with exact JSON types,
  enum values, IANA timezone, decimal precision, and upload limits.
- Set `updated_by_user_id` from the authenticated actor on every effective
  replacement.
- Return the locked Section 12 resource with no invented mutation message.
- Add tenant, authorization, validation, no-op, concurrency, invariant,
  rollback, disclosure, preservation, and regression tests.
- During Phase 1, mark only the S03-BE-006 Stage 3 index row as
  `In Progress / Not started / Not started`.
- After Phase 2 PASS, perform only the exact acceptance/delivery bookkeeping in
  Section 13.

## 5. Exact API Contract

### 5.1 Middleware and Tenant Authority

Both endpoints use this exact middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:institution_admin
```

The authenticated Institution Admin's non-null `institution_id` is the only
tenant authority. No route parameter, query key, body field, header, cookie, or
client-provided settings/Institution identifier may choose or override scope.

Resolve the settings row only by:

```text
institution_settings.institution_id = authenticated actor.institution_id
```

There is no public settings identifier and no cross-Institution lookup path.
Middleware runs before Form Request validation; the applicable request validates
input before the controller calls its action.

### 5.2 Missing Invariant Row

An Institution without its mandatory `institution_settings` row is an internal
persistence invariant failure, not a client-addressable `404` and not permission
to create a replacement row.

For GET or PUT, a missing row must:

- create no row and modify nothing;
- return the centralized safe `500 server_error`;
- expose no Institution UUID, table/SQL/constraint/exception/stack detail;
- be covered by a controlled test.

### 5.3 GET Request Contract

```text
GET /api/v1/institution/settings/assessment
```

The GET accepts no query key and exactly zero raw request-body bytes.

- every query key, including an allowed PUT field name, returns
  `422 validation_failed` with a field-level error;
- whitespace, `{}`, keyed object, array, scalar, JSON `null`, malformed JSON,
  raw text, form, or multipart body returns `422` with `errors.body`;
- validation failure and successful GET perform no write, do not change
  `updated_at`/`updated_by_user_id`, and do not create a row;
- after validation, read exactly one actor-scoped settings row without loading
  Institution, updater, User, category, file, or learning relationships.

### 5.4 Exact Resource and GET Success — `200 OK`

Successful GET returns exactly one top-level key:

```text
data
```

The exact nested key order and shape are:

```json
{
  "data": {
    "educational_policy_configured": false,
    "acceptable_score_difference": null,
    "blitz_timer_start_mode": null,
    "student_result_release_mode": null,
    "parent_result_release_mode": null,
    "timezone": "Asia/Tashkent",
    "upload_limits": {
      "learning_material_max_mb": 25,
      "student_submission_max_mb": 15,
      "platform_learning_material_max_mb": 25,
      "platform_student_submission_max_mb": 15
    },
    "fixed_attempt_rules": {
      "homework_normal_attempts": 3,
      "blitz_normal_attempts": 1,
      "blitz_max_additional_exception_attempts": 1
    }
  }
}
```

Type rules:

- `educational_policy_configured` is a JSON boolean;
- `acceptable_score_difference` is JSON `null` or a JSON number, never a
  quoted decimal string and never locale-formatted;
- mode fields are JSON `null` or exact enum strings;
- timezone is a JSON string;
- all upload-limit and fixed-attempt values are JSON integers.

`educational_policy_configured` is true if and only if all four educational
policy fields are non-null:

```text
acceptable_score_difference
blitz_timer_start_mode
student_result_release_mode
parent_result_release_mode
```

Timezone/upload defaults alone do not make it true. A partially populated
legacy/corrupt row remains `false`; the resource reflects current stored values
without inventing educational defaults.

The resource must not return a success `message`, `meta`, `links`,
`institution_id`, `updated_by_user_id`, `created_at`, `updated_at`, updater/
Institution/User data, category configuration, file data, attempts, questions,
answers, scores, results, or any other setting/relationship.

Reuse the accepted `CreatePlatformInstitution` platform constants for the two
platform maxima; do not duplicate `25`/`15` as independent application-policy
copies. Define each fixed-attempt output value once as a named private constant
inside the resource (the only Stage 3 serializer that currently needs it).

### 5.5 PUT Transport and Complete Body Shape

```text
PUT /api/v1/institution/settings/assessment
```

PUT requires `Content-Type: application/json`; an optional charset parameter
is allowed. The top-level value must be a JSON object containing exactly all
seven keys:

```text
acceptable_score_difference
blitz_timer_start_mode
student_result_release_mode
parent_result_release_mode
timezone
learning_material_max_mb
student_submission_max_mb
```

Example:

```json
{
  "acceptable_score_difference": 10,
  "blitz_timer_start_mode": "individual",
  "student_result_release_mode": "manual_teacher",
  "parent_result_release_mode": "with_student",
  "timezone": "Asia/Tashkent",
  "learning_material_max_mb": 20,
  "student_submission_max_mb": 10
}
```

Body-shape rules:

- absent raw body, whitespace-only body, malformed JSON, scalar, array, or JSON
  `null` returns `422 validation_failed` with `errors.body`;
- form-encoded, multipart, text, or other non-JSON media returns `422` with
  `errors.body`;
- `{}` is a valid JSON object but returns field-level required errors for all
  seven fields;
- omission of any one or several required fields returns field-level errors;
- every query key is rejected with a field-level validation error;
- every unknown/protected JSON key rejects the entire request with a field-level
  error; allowed fields are never partially applied;
- every validation failure performs zero mutation.

### 5.6 Exact PUT Validation and Normalization

```text
acceptable_score_difference:
  required JSON number (integer or decimal), not numeric string/bool/null;
  inclusive 0..100; maximum 8 fractional decimal places; no silent rounding

blitz_timer_start_mode:
  required JSON string; exactly synchronized|individual

student_result_release_mode:
  required JSON string; exactly automatic|manual_teacher

parent_result_release_mode:
  required JSON string; exactly with_student|manual_teacher|hidden

timezone:
  required JSON string; non-empty; maximum 64 characters;
  exact identifier from the runtime-supported IANA timezone database

learning_material_max_mb:
  required JSON integer, not numeric string/float/bool/null; inclusive 1..25

student_submission_max_mb:
  required JSON integer, not numeric string/float/bool/null; inclusive 1..15
```

Exact normalization rules:

- do not trim, lowercase, case-fold, alias, or silently convert enum/timezone
  strings; they must already match accepted values;
- fixed numeric timezone offsets such as `+05:00`, blank/whitespace values,
  invalid identifiers, and oversized values are rejected;
- validate timezone against the server/runtime IANA identifier source (for
  example Laravel/PHP timezone validation), not regex alone and not a hardcoded
  Uzbekistan-only list;
- accept valid supported identifiers from multiple regions, including those
  with normal IANA separators; tests must use the same runtime source rather
  than assume an unsupported alias;
- persist the accepted score threshold into PostgreSQL `numeric(12,8)` without
  binary-float artifacts or rounding beyond the submitted maximum-eight-decimal
  value;
- serialize the stored threshold back as a JSON number; lexical trailing zeroes
  are not a separate public contract;
- `1 MB = 1,048,576 bytes` for later file validation, but this task stores and
  returns the approved integer MB limits only and implements no upload flow.

Use the accepted enum classes for all three mode fields and the accepted
`CreatePlatformInstitution` constants for the two upper bounds.

### 5.7 Protected and Unknown PUT Keys

Protected-key tests must include at least:

```text
institution_id
settings_id
id
updated_by_user_id
created_at
updated_at
educational_policy_configured
upload_limits
platform_learning_material_max_mb
platform_student_submission_max_mb
fixed_attempt_rules
homework_normal_attempts
homework_attempt_limit
blitz_normal_attempts
blitz_attempt_limit
blitz_max_additional_exception_attempts
blitz_exception_attempt_limit
understanding_categories
categories
category_ranges
users
files
results
history
```

Any other non-allowlisted key is also rejected. Nested attempts to submit these
values inside `upload_limits`, `fixed_attempt_rules`, or any arbitrary container
are unknown top-level input and reject the whole request.

Parent result visibility remains Student-first at runtime. This endpoint stores
only the approved enum value and does not invent a forbidden combination beyond
the locked independent enum sets.

### 5.8 Atomic PUT Persistence

Pass the authenticated actor and a complete validated representation to
`UpdateInstitutionAssessmentSettings`.

Inside one database transaction:

1. require the actor's non-null Institution scope;
2. select the existing row by actor `institution_id` using
   `FOR UPDATE`/Laravel `lockForUpdate()`;
3. if missing, throw the safe invariant failure from Section 5.2 and do not
   create a row;
4. replace all seven persisted setting values from the validated complete
   representation;
5. set `updated_by_user_id = authenticated actor.id`;
6. persist at most one settings-row update, refresh, and return committed state.

Never use `updateOrCreate`, `firstOrCreate`, `upsert`, an unscoped settings
query, raw request mass assignment, or a client-supplied actor/Institution ID.

The update must not create a second row or touch the Institution, actor, any
other User/settings row, token, category, file, task, snapshot, attempt,
question, answer, score, result, or history row.

Unexpected database/application failure must roll back the entire replacement
and updater change and return centralized safe `500 server_error` without SQL,
constraint, exception, stack, body, threshold, timezone, PII, or unrelated
sensitive detail.

### 5.9 Exact PUT No-Op and Updater/Timestamp Rules

Compare the complete validated values and server-derived updater against the
fresh locked row after enum/decimal persistence normalization.

- If all seven values and `updated_by_user_id` already equal the requested
  effective state, execute no settings `UPDATE`, preserve exact `updated_at`,
  and return the current resource.
- If any one setting differs, replace the full seven-field representation, set
  updater to the actor, execute exactly one settings update, and advance
  `updated_at` once using server time.
- If all seven values match but a different eligible Institution Admin submits
  them, changing `updated_by_user_id` is an effective update; execute one update
  and advance `updated_at` once.
- `created_at` never changes and neither timestamp/updater appears in the public
  resource.

### 5.10 Concurrent Complete Replacements

Concurrent PUT operations for the same Institution must serialize on the same
settings row.

- each transaction reads the fresh locked row;
- each successful effective PUT writes one complete seven-field representation,
  never a field mixture assembled from competing requests;
- final stored settings equal the complete request of the transaction that
  commits last after obtaining the lock;
- `updated_by_user_id` corresponds to the complete winning replacement;
- each response serializes the state committed by its own transaction;
- same-payload/same-actor races result in at most one effective transition and
  no duplicate second write after the later transaction sees committed state;
- no second row, stale partial state, or unrelated/historical mutation occurs.

PostgreSQL row-lock/concurrency evidence is mandatory; a purely mocked or
SQLite-only assertion is insufficient.

### 5.11 PUT Success — `200 OK`

PUT returns the complete updated resource from Section 5.4 with:

```text
educational_policy_configured = true
```

It returns exactly one top-level key:

```text
data
```

The locked Section 12 contract does not define a PUT success message. Do not
invent `message`, `meta`, `links`, or any additional field.

### 5.12 Historical and Dependent-Operation Preservation

Changing settings affects only future dependent behavior owned by later stages.
This task must not:

- rewrite any already-stored absolute `timestamptz` instant because timezone
  changed;
- change an active or previously activated Blitz timer-start snapshot;
- recalculate or rewrite an already-calculated/closed result, numeric score,
  release state, or category snapshot;
- alter an understanding-category row/range;
- change a file row or revalidate/delete an existing file because a lower
  upload limit was saved;
- create or mutate Homework/Blitz attempts or fixed-attempt configuration;
- implement the later dependent-operation `409 institution_settings_incomplete`
  enforcement beyond preserving the locked contract for its owning stages.

## 6. Exact Files and Responsibilities

Codex must inspect accepted patterns but change only these exact
application/test paths:

| File | Expected action | Responsibility |
|---|---|---|
| `backend/routes/api.php` | Modify | Register exact GET/PUT routes once |
| `backend/app/Http/Controllers/Api/V1/Institution/InstitutionAssessmentSettingsController.php` | Create | Thin `show`/`update` adapters |
| `backend/app/Http/Requests/Institution/InstitutionAssessmentSettingsShowRequest.php` | Create | Zero-body/query GET contract |
| `backend/app/Http/Requests/Institution/InstitutionAssessmentSettingsUpdateRequest.php` | Create | Strict complete PUT JSON/type/allowlist validation |
| `backend/app/Actions/Institution/ShowInstitutionAssessmentSettings.php` | Create | Actor-scoped existing-row read/invariant handling |
| `backend/app/Actions/Institution/UpdateInstitutionAssessmentSettings.php` | Create | Scoped locked replacement/no-op/rollback behavior |
| `backend/app/Http/Resources/Institution/InstitutionAssessmentSettingsResource.php` | Create | Exact nested resource/types/derived constants |
| `backend/tests/Feature/Institution/InstitutionAssessmentSettingsApiTest.php` | Create | Complete contract/security/concurrency evidence |
| `backend/app/Models/InstitutionSetting.php`, approved mode enums | Inspect/reuse unchanged | Existing casts/relations are sufficient |
| `backend/app/Actions/Platform/CreatePlatformInstitution.php` | Inspect/reuse unchanged | Canonical platform max/default constants |
| migrations/factories/persistence tests | Inspect/reuse unchanged | Existing schema/invariant evidence |
| `tasks/STAGE_03_TASK_INDEX.md` | Modify only as Section 13 permits | Truthful execution/review/delivery state |
| `tasks/README.md` | Modify only after Phase 2 PASS | Truthful Stage 3 current/next gate |
| this detailed task | Status metadata only after Phase 2 PASS | Final accepted task state |
| paired Codex prompt | Preserve byte-for-byte | Approved execution authority |

No other application/test path may change. No model, enum, factory, migration,
schema/check/index, Platform action, auth middleware, frontend, category,
dependent learning operation, or locked-document change belongs here. Stop
instead of widening the allowlist if accepted persistence cannot support the
task unchanged.

## 7. Authoritative References

| Document | Exact area | Requirement |
|---|---|---|
| `docs/02-user-roles.md` | Institution Admin settings authority | Actor boundary |
| `docs/03-features.md` / `docs/04-user-flows.md` | Institution settings flow | Approved management behavior |
| `docs/05-business-rules.md` | BR-OV-011, BR-INST-016–017, file/attempt/time/result rules | Scope, fixed rules, preservation |
| `docs/06-roadmap.md` | `8. Stage 3` | Assessment-settings scope |
| `docs/07-architecture.md` | auth/tenant/layer/transaction/time/testing | Organization/security |
| `docs/08-database.md` | Sections 3, 8 and dependent snapshot/history tables | Existing fields/precision/invariant |
| `docs/09-api-contracts.md` | Sections 1–3, 12.1–12.2 and error registry | Exact GET/PUT/resource/error contract |
| accepted Stage 2 Institution create/persistence code/tests | settings initialization and constraints | Existing row/defaults/constants |
| `backend/AGENTS.md` | entire applicable file | Backend rules and gates |

## 8. Architecture, Security, and Error Requirements

- Requests own raw body/media/query/allowlist/simple type/range/enum/timezone
  validation and conversion to approved enum/decimal/integer values.
- Controller receives the authenticated actor, calls one action per method, and
  returns the resource without adding fields/messages.
- Read action owns trusted scope and invariant handling; update action owns
  trusted scope, transaction, row lock, full replacement, dirty/no-op decision,
  updater, refresh, and committed state.
- Resource owns exact public types/shape and derived configured flag/constants;
  it performs no query or mutation.
- Never trust client tenant/updater/derived fields, mass-assign raw input, load
  updater/Institution relations, or create a missing row.
- Preserve centralized middleware and error envelopes for unauthenticated,
  inactive User, inactive Institution, first-login actor, wrong role,
  validation, and unexpected failures.
- Do not log request bodies, threshold/timezone values unnecessarily,
  Institution/User identifiers, SQL, exception internals, credentials, or
  tokens.

## 9. Acceptance Criteria

- [ ] Exact GET/PUT routes exist once with exact middleware order.
- [ ] Tenant scope and updater derive only from the authenticated eligible
      Institution Admin.
- [ ] GET rejects every body/query input, performs one scoped read and zero
      writes, and returns exact configured/unconfigured resource/types/order.
- [ ] Missing invariant row returns safe `500`, creates nothing, and reveals no
      internal detail.
- [ ] PUT requires JSON and exactly all seven allowed fields; every missing,
      unknown, protected, query, body-shape, and media violation is atomic.
- [ ] JSON number/integer types, decimal scale/range, exact enums, supported IANA
      timezone, and upload min/max boundaries are enforced without coercion or
      silent rounding.
- [ ] Platform maxima and fixed attempt rules are returned but never accepted
      as configurable/persisted inputs.
- [ ] PUT locks/replaces only the existing own-Institution row, sets updater,
      and preserves the one-row invariant.
- [ ] Exact same-actor no-op writes nothing/preserves `updated_at`; effective
      value/updater change writes once/advances `updated_at` once.
- [ ] Concurrent complete replacements serialize without mixed/stale fields and
      keep winner/updater consistency.
- [ ] Controlled unexpected failures roll back fully and return safe
      `500 server_error` without internal/sensitive disclosure.
- [ ] GET and PUT return exactly `data`; no message/meta/links/private fields.
- [ ] Historical timestamps, files, categories, active snapshots, attempts,
      scores/results, Users, other settings, and unrelated rows remain unchanged.
- [ ] Existing Stage 2 initialization/persistence, Stage 3 predecessors, auth,
      and Platform behavior remains green.
- [ ] No schema/frontend/category/dependent-operation/later-stage or unrelated
      file change is introduced.

## 10. Tests and Verification

### 10.1 Required Feature and Action Tests

- routes registered once with exact methods/paths and middleware order;
- initial row returns exact configured-false resource, nested key order,
  booleans/nulls/strings/integers/JSON-number contract, fixed/platform constants,
  only top-level `data`, and no private/additional keys;
- fully configured row and successful PUT return configured true with every
  exact mode/value/type and no `message`;
- GET body matrix: whitespace, `{}`, keyed object, array, scalar, null,
  malformed, text/form/multipart; every query key including PUT names;
  validation errors and success prove zero write/query-side mutation;
- PUT body matrix: absent, whitespace, malformed, scalar, array, null,
  unsupported media; `{}` and omission of each required field; all prove exact
  errors and zero mutation;
- score threshold accepts JSON numeric 0, 100, integer/decimal and representative
  1–8 fractional-place values; rejects numeric strings, bool/null, negative,
  above 100, and more than 8 places without silent database rounding;
- stored decimal precision and JSON-number serialization round-trip without
  locale or binary artifact;
- every valid/invalid/type/case/whitespace value for each enum;
- multiple runtime-supported IANA zones across regions and relevant 64-character
  boundary; blank/whitespace, fixed offset, invalid/case-altered, oversized, and
  non-string timezone failures;
- upload-limit min/max, each out-of-range, JSON float, numeric string, bool/null,
  and cross-field combinations;
- every protected key from Section 5.7, arbitrary unknown and nested container,
  every query key, and combined valid+invalid payload proving zero partial write;
- same Institution actor sets updater; no identifier/header/query/body can
  select or modify a second Institution; exact before/after second-row snapshot;
- no-op same values/same actor proves row lock, zero settings UPDATE, unchanged
  `updated_at`; changed field and different-updater same-values cases prove
  exactly one update and authoritative timestamp;
- controlled PostgreSQL same-payload and distinct complete-replacement races
  prove row lock, no mixed representation, last committed complete winner,
  winner/updater consistency, and one-row invariant;
- controlled missing-row GET/PUT returns safe `500`, creates no row, and leaks no
  Institution/table/SQL/exception detail;
- controlled post-lock update failure proves full rollback of all seven fields
  and updater, safe centralized `500`, and no SQL/constraint/stack/body/value/
  identifier disclosure;
- unauthenticated, inactive actor, inactive actor Institution,
  `must_change_password = true` actor, and Platform Owner/Teacher/Student/Parent
  wrong-role precedence, including invalid input where needed;
- exact response/log disclosure matrix excludes tenant/updater/timestamps/
  relations/categories/files/learning/credentials/tokens/internal values;
- snapshots prove no changes to Institution/User/token/other settings/category/
  file/task/snapshot/attempt/answer/score/result/history rows and no historical
  absolute timestamp rewrite after timezone change;
- accepted Institution creation still creates one default/null settings row;
  persistence constraints/enums/casts and S03-BE-001–005/Stage 1/2/Platform
  regressions remain green.

### 10.2 Quality Gates

From `backend/`, run current repository-valid equivalents of:

```text
vendor/bin/pint --test
php artisan test --filter=InstitutionAssessmentSettingsApiTest
php artisan test
composer validate --strict
```

Run all configured security/static checks required by `backend/AGENTS.md`. Any
required failure blocks acceptance.

### 10.3 Manual Smoke

Using controlled Institution Admin credentials that are never recorded in
reports/logs:

1. GET the unconfigured row and verify exact defaults/nulls/constants.
2. PUT one complete valid policy, reload, and verify exact persisted resource.
3. Repeat the same request and verify no-op timestamp behavior.
4. Submit an over-limit upload value, invalid timezone, missing field,
   protected/fixed-attempt key, unknown key, and query key; prove zero mutation.
5. Use a second Institution Admin/Institution and prove strict isolation.
6. Confirm existing historical timestamps/files/categories/results and the
   one-row invariant remain unchanged.

If the controlled backend is available, smoke must PASS. A smoke `FAIL` always
blocks acceptance. `NOT RUN` is non-blocking only when the environment is
genuinely unavailable, the reason is reported explicitly, and all equivalent
automated contract/tenant/atomicity/concurrency/preservation tests pass. Do not
use `NOT RUN` to hide a startup, configuration, or implementation failure.

## 11. Explicit Non-Goals

- Understanding-category persistence/API/UI (S03-BE-007/S03-FE-009).
- Configurable Homework/Blitz attempt counts or exception policy changes.
- Upload endpoints, file revalidation/deletion, or byte-limit enforcement.
- Blitz activation/timing, result calculation/release, category assignment, or
  `institution_settings_incomplete` enforcement for later dependent operations.
- Rewriting active snapshots, calculated/closed results, release/category
  snapshots, files, historical rows, or absolute timestamps.
- Settings history/audit-version subsystem.
- Institution/profile/User/group/relationship/learning/frontend work.
- Model/enum/factory/migration/schema/check/index/auth-middleware/locked-doc
  changes.

## 12. Stop Conditions

Stop on missing accepted S03-BE-005 dependency, missing settings-row invariant,
contract/schema/model/enum conflict, inability to validate exact supported IANA
zones or decimal precision safely, required model/migration/Platform/dependent-
operation change, inability to preserve historical state, unsafe Git state, or
material scope expansion.

## 13. Required Workflow and Delivery

### Phase 0 — Git Preflight

1. Read the paired execution prompt and its authority order completely.
2. Verify this detailed task is `Approved`.
3. Verify S03-INT-001 and S03-BE-001 through S03-BE-005 are each
   `Accepted / PASS / Delivered` on `origin/main`.
4. Verify Stage 3 index/README narrative and rows are internally truthful; stop
   on stale dependency bookkeeping instead of assuming delivery.
5. Verify the exact approved remote, fetch safely, and prove
   `local main == origin/main`.
6. Verify the working tree is clean except for only the owner-prepared
   S03-BE-006 detailed task and paired prompt.
7. Create/switch to `task/s03-be-006-assessment-settings`.
8. Preserve unrelated user work and stop on unsafe/dirty/conflicting state.
9. Do not commit, push, create a PR, or merge before Phase 2 PASS.

### Phase 1 — Implementation

Implement only this task. The only application/test paths allowed to change
are:

```text
backend/routes/api.php
backend/app/Http/Controllers/Api/V1/Institution/InstitutionAssessmentSettingsController.php
backend/app/Http/Requests/Institution/InstitutionAssessmentSettingsShowRequest.php
backend/app/Http/Requests/Institution/InstitutionAssessmentSettingsUpdateRequest.php
backend/app/Actions/Institution/ShowInstitutionAssessmentSettings.php
backend/app/Actions/Institution/UpdateInstitutionAssessmentSettings.php
backend/app/Http/Resources/Institution/InstitutionAssessmentSettingsResource.php
backend/tests/Feature/Institution/InstitutionAssessmentSettingsApiTest.php
```

Preserve the model/enums/factory/migration/schema/Platform code byte-for-byte.
Also update only the S03-BE-006 row in `tasks/STAGE_03_TASK_INDEX.md` to
`In Progress / Not started / Not started`. Keep this detailed task's status
`Approved` and preserve the paired prompt byte-for-byte before Phase 2.

Run all required automated checks, scope/secret checks, and the manual smoke
rule from Section 10. Inspect the complete diff including the owner-prepared
task/prompt. Do not commit or push.

### Phase 2 — Read-Only Acceptance Gate

Re-read the authority task, locked Section 12, accepted persistence and Stage 3
predecessors, complete diff, code/tests, request/resource/tenant/type/precision/
timezone/invariant/no-op/updater/locking/concurrency/rollback/preservation/
disclosure evidence, and smoke result. Phase 2 is strictly read-only:

```text
no edits or auto-fix/write-format
no task/index/README bookkeeping edits
no staging or commit
no push, PR, or merge
no self-fixing findings
```

Classify findings:

- `P1`: authorization/tenant or secret/credential/token disclosure,
  protected-field control, destructive Git, or violation of the read-only gate;
- `P2`: material request/resource/type/precision/timezone/invariant/mutation/
  no-op/updater/transaction/concurrency/error/preservation/test mismatch, scope
  drift, or workflow/bookkeeping defect;
- `P3`: non-blocking observation that does not affect correctness, security,
  required evidence, or maintainability acceptance.

Any unresolved P1 or P2 results in:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start `S03-BE-007`. Report every P3 finding;
P3 alone does not block acceptance.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 PASS with no unresolved P1/P2.

1. Change only this detailed task's metadata status from `Approved` to
   `Accepted`; do not rewrite its approved behavior.
2. Prepare only the S03-BE-006 index row as
   `Accepted / PASS / Delivered` in the delivery commit.
3. Update all directly affected Stage 3 index/README current-state narrative
   truthfully: Stage 3 remains `In Progress`, S03-BE-006 is delivered, and
   S03-BE-007 is the next execution gate. Remove no history and change no
   unrelated task status.
4. Preserve later-task statuses; do not mark S03-BE-007 Approved unless its own
   reviewed pair is already present and separately approved.
5. Keep the paired Codex prompt byte-for-byte unchanged and include both
   owner-prepared authority files in the focused delivery commit.
6. Keep Stage 3 not closed and Stage 4 not started.
7. Re-run final non-writing diff, scope, secret, and consistency checks.
8. Stage only the approved implementation/test files, this task, its unchanged
   prompt, `tasks/STAGE_03_TASK_INDEX.md`, and `tasks/README.md`.
9. Commit:

   ```text
   feat(institution): add assessment settings API
   ```

   Body:

   ```text
   Task: S03-BE-006
   ```

10. Push the exact task branch, open a PR to `main`, verify base/head/diff, and
    merge only when required checks are safe/green and merge is permitted.
11. Fast-forward local `main` and verify local `main == origin/main` with a
    clean working tree.

The prepared `Accepted / PASS / Delivered` values become authoritative only
after the delivery commit is merged and local/remote/clean verification passes.
If Phase 2 passed but safe delivery cannot complete, return:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Only after complete delivery return:

```text
FINAL STATUS: ACCEPTED
```

## 14. Required Codex Final Report

Report final status, preflight/dependency/index truth evidence, implementation
and every changed file, exact GET/PUT/resource behavior, every acceptance
criterion and command/result, request/type/precision/timezone/tenant/updater/
invariant/no-op/concurrency/rollback/fixed-attempt/platform-max/history/
disclosure evidence, Stage 2 initialization/persistence and Stage 3 predecessor
regressions, P1/P2/P3 findings, smoke status/blocking decision, scope/secret
checks, bookkeeping result, and complete Git/PR/merge/local-remote-clean
evidence.

State:

```text
No Understanding-category, configurable-attempt, upload, Blitz timing, result,
file, historical-rewrite, group, relationship, frontend, schema, or later-stage
behavior was implemented.
Next implementation gate: S03-BE-007.
```
