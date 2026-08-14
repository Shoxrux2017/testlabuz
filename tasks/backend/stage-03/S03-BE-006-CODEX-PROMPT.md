# Codex Execution Prompt — S03-BE-006

Execute exactly one approved task:

`S03-BE-006 — Institution Assessment Settings API`

Repository: `G:\project\testlabuz`

Remote: `https://github.com/Shoxrux2017/testlabuz.git`

Authority task:

`tasks/backend/stage-03/S03-BE-006-institution-assessment-settings-api.md`

Required branch: `task/s03-be-006-assessment-settings`

Read the detailed task completely. It controls this prompt unless a referenced
locked contract is stricter.

## Authority and Dependency Preflight

Read root `AGENTS.md`, `backend/AGENTS.md`, the detailed task,
`tasks/README.md`, `tasks/STAGE_03_TASK_INDEX.md`, accepted S03-INT-001 and
S03-BE-001/002/003/004/005, relevant `docs/02–09`, accepted Stage 2 Institution
create/settings persistence/model/enums/tests, and current code/tests/Git.

Prove before edits:

```text
S03-INT-001 = Accepted / PASS / Delivered on origin/main
S03-BE-001 = Accepted / PASS / Delivered on origin/main
S03-BE-002 = Accepted / PASS / Delivered on origin/main
S03-BE-003 = Accepted / PASS / Delivered on origin/main
S03-BE-004 = Accepted / PASS / Delivered on origin/main
S03-BE-005 = Accepted / PASS / Delivered on origin/main
Stage 3 index/README rows and current-state narrative are internally truthful
local main == origin/main
working tree is clean except the owner-prepared S03-BE-006 task/prompt
origin is the approved remote
```

Create/switch to `task/s03-be-006-assessment-settings`. Stop on unsafe Git,
missing/stale dependency bookkeeping, missing invariant, or contract conflict.
Do not commit/push before Phase 2 PASS.

## Implement Only These Endpoints

```text
GET /api/v1/institution/settings/assessment
PUT /api/v1/institution/settings/assessment
```

Middleware order:

```text
auth:sanctum → active.account → password.changed → role:institution_admin
```

Derive scope only from the authenticated actor's non-null `institution_id`.
Accept no route/query/body/header/cookie tenant or updater override. Read/update
only the existing `institution_settings` row keyed by that Institution.

A missing mandatory row is a safe internal invariant failure: create nothing,
modify nothing, and return centralized `500 server_error` without internal
detail. Never use `firstOrCreate`, `updateOrCreate`, or `upsert`.

## Exact GET Behavior

GET accepts no query key and exactly zero raw body bytes. Whitespace, `{}`,
object, array, scalar, JSON null, malformed JSON, text/form/multipart body
returns `422 validation_failed` with `errors.body`; every query key returns a
field-level error. Middleware precedes validation. Success and validation
failure perform zero writes and preserve updater/timestamps.

GET performs one actor-scoped settings read without relations and returns exact
`200` with only top-level `data`:

```text
educational_policy_configured
acceptable_score_difference
blitz_timer_start_mode
student_result_release_mode
parent_result_release_mode
timezone
upload_limits {
  learning_material_max_mb
  student_submission_max_mb
  platform_learning_material_max_mb = 25
  platform_student_submission_max_mb = 15
}
fixed_attempt_rules {
  homework_normal_attempts = 3
  blitz_normal_attempts = 1
  blitz_max_additional_exception_attempts = 1
}
```

Use the exact nested key order from the task. `educational_policy_configured`
is true iff all four educational-policy fields are non-null. Threshold is null
or a JSON number; modes are null or enum strings; upload/attempt values are JSON
integers. Reuse accepted Platform Institution-create constants for platform
maxima and define fixed output values once as named private resource constants.

Return no `message`, `meta`, `links`, tenant/updater/timestamps/relations,
categories/files/attempts/scores/results, or other private/additional fields.

## Exact PUT Request

Require `application/json` with exactly all seven top-level keys:

```text
acceptable_score_difference
blitz_timer_start_mode
student_result_release_mode
parent_result_release_mode
timezone
learning_material_max_mb
student_submission_max_mb
```

Validation:

```text
acceptable_score_difference: required JSON number, 0..100 inclusive,
                             max 8 fractional places, no silent rounding
blitz_timer_start_mode: required exact synchronized|individual string
student_result_release_mode: required exact automatic|manual_teacher string
parent_result_release_mode: required exact with_student|manual_teacher|hidden string
timezone: required exact runtime-supported IANA identifier string, max 64
learning_material_max_mb: required JSON integer 1..25
student_submission_max_mb: required JSON integer 1..15
```

Reject numeric strings, bool/null, float upload limits, invalid/case/whitespace
enum/timezone values, fixed offsets, and over-eight-place thresholds. Do not
trim/lowercase/alias/coerce. Persist the accepted threshold safely in
`numeric(12,8)` and serialize it as a JSON number without locale/binary
artifacts. Use approved enums and existing platform-limit constants.

Absent/whitespace/malformed/scalar/array/null/non-JSON body returns
`422 validation_failed` with `errors.body`. `{}` and every missing field return
field-level required errors. Reject every query and every unknown/protected key
with field-level errors and zero partial mutation. Protected input includes
tenant/updater/IDs/timestamps, configured flag, nested upload/platform maxima,
fixed/attempt limits, categories/ranges, users/files/results/history, and every
other non-allowlisted key.

## Exact PUT Persistence and Response

Pass actor plus the complete validated representation to
`UpdateInstitutionAssessmentSettings`. In one transaction, select the existing
actor-Institution row with `lockForUpdate()`, replace all seven values, set
`updated_by_user_id = actor.id`, persist at most one update, refresh, and return
committed state.

Effective-state rules:

```text
same seven values + same updater: no SQL update; preserve updated_at
any changed value: one full replacement update; actor updater; updated_at advances once
same values + different actor: one updater change; updated_at advances once
```

Concurrent same-Institution PUTs must serialize on the same PostgreSQL row. No
mixed fields or stale partial state: final values and updater belong to one
complete winning request, each response reflects its own committed state, and
same-payload/same-actor races produce at most one effective write.

Unexpected failure rolls back all seven values/updater and returns safe
`500 server_error` without SQL/constraint/exception/stack/body/value/tenant
detail.

PUT returns exact `200`, the complete configured resource, and only top-level
`data`. Locked Section 12 defines no PUT success message; do not add one.

Do not create another settings row or modify Institution/User/token/other
settings/categories/files/tasks/active Blitz snapshots/attempts/questions/
answers/scores/results/history. Timezone changes never rewrite existing
absolute timestamps; policy changes affect only future dependent behavior.

## Exact Change Scope

Change exactly these application/test paths:

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

Inspect and preserve model/enums/factory/migrations/schema/Platform actions/
auth middleware and persistence tests byte-for-byte. Do not add category,
configurable-attempt, upload, file, Blitz runtime, result, dependent
`institution_settings_incomplete`, Institution/User/group/relationship,
frontend, schema, locked-doc, or later-stage behavior.

## Mandatory Verification

Test exact routes/middleware/precedence; GET zero-body/query/no-write and exact
configured/unconfigured resource/order/types/exclusions; complete PUT media/
body/query/required/allowlist/protected behavior; JSON type/range/scale/enum/
timezone/upload boundaries; decimal round-trip; tenant/updater authority;
missing-row safe invariant failure; one-row/no-op/one-write/timestamp behavior;
PostgreSQL complete-replacement races; controlled rollback/safe `500` and
non-disclosure; inactive/password/wrong-role gates; fixed attempts/platform
maxima; historical/snapshot/file/category/result/other-row preservation; Stage
2 initialization/persistence and S03-BE-001–005/Stage 1/2/Platform regressions.

Run from `backend/`:

```text
vendor/bin/pint --test
php artisan test --filter=InstitutionAssessmentSettingsApiTest
php artisan test
composer validate --strict
```

Run all additional configured backend gates. If the controlled backend is
available, manual smoke must PASS. A smoke FAIL blocks acceptance. `NOT RUN` is
non-blocking only when the environment is genuinely unavailable, the reason is
explicit, and equivalent automated contract/tenant/precision/atomicity/
concurrency/preservation tests pass. It cannot hide a startup, configuration,
or implementation failure.

During Phase 1, update only the S03-BE-006 Stage 3 index row to
`In Progress / Not started / Not started`. Keep the detailed task `Approved`
and this prompt byte-for-byte unchanged before Phase 2. Do not commit or push.

## Read-Only Gate

After Phase 1, re-read all authority and inspect the complete diff/tests/
request/resource/tenant/type/precision/timezone/invariant/no-op/updater/lock/
concurrency/rollback/preservation/disclosure/smoke evidence. Phase 2 permits no
edit, write-format, bookkeeping change, staging, commit, push, PR, merge, or
self-fix.

Classify findings:

```text
P1 = authorization/tenant/secret-token/protected-field/destructive-Git/read-only breach
P2 = material request/resource/type/precision/timezone/invariant/mutation/no-op/updater/transaction/concurrency/error/test/scope/workflow defect
P3 = non-blocking observation with no correctness/security/evidence impact
```

Any unresolved P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start S03-BE-007. Report P3; P3 alone does
not block acceptance.

## Post-PASS Delivery

After PASS with no unresolved P1/P2 only:

1. change only the detailed task metadata status to `Accepted`;
2. prepare only its Stage 3 index row as `Accepted / PASS / Delivered`;
3. update directly affected Stage 3 index/README current-state narrative
   truthfully so Stage 3 remains `In Progress`, S03-BE-006 is delivered, and
   S03-BE-007 is the next execution gate;
4. preserve later-task statuses and do not approve S03-BE-007 unless its own
   reviewed pair is already separately approved;
5. keep this prompt byte-for-byte unchanged and include both owner-prepared
   authority files in delivery;
6. keep Stage 3 not closed and Stage 4 not started;
7. rerun final safe scope/diff/secret/consistency checks and commit:

```text
feat(institution): add assessment settings API

Task: S03-BE-006
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
smoke decision, exact resource/type/precision/timezone/invariant/no-op/updater/
concurrency/rollback/preservation/safe-500 evidence, bookkeeping/delivery
evidence, and state:

```text
No Understanding-category, configurable-attempt, upload, Blitz timing, result,
file, historical-rewrite, group, relationship, frontend, schema, or later-stage
behavior was implemented.
Next implementation gate: S03-BE-007.
```
