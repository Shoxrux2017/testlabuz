# Codex Execution Prompt — S03-FE-003

Execute only:

```text
S03-FE-003 — Own Institution Profile View and Edit
```

Repository:

```text
G:\project\testlabuz
```

Detailed task authority:

```text
tasks/frontend/stage-03/S03-FE-003-own-institution-profile-view-edit.md
```

Required branch:

```text
task/s03-fe-003-own-institution-profile
```

## 1. Authority and Scope

Read completely before any code change:

1. root `AGENTS.md`;
2. `frontend/AGENTS.md`;
3. the full detailed S03-FE-003 task;
4. `tasks/README.md` and `tasks/STAGE_03_TASK_INDEX.md`;
5. accepted `S03-INT-001`;
6. relevant locked `docs/02–09`, especially API Section 8.1 and general
   envelope/error/time/session rules;
7. accepted S03-BE-002 task, implementation, and tests;
8. accepted S03-FE-001/S03-FE-002 tasks, implementation, and tests;
9. accepted Platform Institution detail/edit implementation only as a safe
   architectural/testing pattern; and
10. current frontend code/tests and Git/GitHub state.

Authority order is AGENTS → locked docs → accepted Stage 3 contracts/delivered
backend → detailed task → this invocation prompt. Stop and report any conflict;
do not reinterpret or modify a locked contract.

Implement no other task. Do not modify backend, docs, Docker, dependencies,
Platform behavior, Dashboard behavior, later Stage 3 features, or Stage 4 work.

## 2. Phase 0 — Mandatory Preflight

Before implementation:

- verify the detailed task status is `Approved`;
- record SHA-256 of the task and this paired prompt;
- prove Stage 1/2 closure remains PASS;
- prove S03-INT-001, S03-BE-002, S03-FE-001, and S03-FE-002 are each
  `Accepted / PASS / Delivered` on current `origin/main`;
- verify the delivered profile API and Institution Admin shell/Dashboard still
  match the detailed task;
- prove the Stage 3 index/README identify S03-FE-003 as the next execution gate;
- verify exact approved `origin`, fetch safely, and prove clean
  `local main == origin/main` at the intended base;
- allow only the owner-prepared S03-FE-003 task/prompt as pre-existing task
  artifacts when applicable;
- stop on unrelated dirty work, missing authority, contract drift, competing
  implementation, or unsafe Git state; and
- create/switch to `task/s03-fe-003-own-institution-profile`.

Do not stage, commit, push, create a PR, merge, or change acceptance bookkeeping
before Phase 2 PASS.

## 3. Exact Feature Outcome

Replace only the Institution placeholder at:

```text
/institution-admin/institution
```

with `InstitutionAdminProfileScreen` using the exact layered flow:

```text
screen/controller/state
→ repository
→ remote data source
→ existing authenticated Dio
```

Consume exactly:

```dart
dio.get<Object?>('/institution/profile')
```

and, only for non-empty normalized changed fields:

```dart
dio.patch<Object?>(
  '/institution/profile',
  data: request.toJson(),
)
```

GET has no query/body. PATCH has no query and only the exact changed-fields
JSON body. Never send an Institution ID in path/query/body/header and never
construct a second Authorization/client boundary.

## 4. Exact Resource and DTO Rules

Parse the normal `data` envelope through `ApiSuccessEnvelope` and require:

```text
id
name
type
status
contact_email
contact_phone
address
description
created_at
updated_at
```

Require canonical UUID shape, non-empty required strings, exact nine Institution
types, `active|inactive`, present nullable strings, and valid UTC timestamps.
The response ID must equal the current eligible session Institution ID before
any protected profile state is displayed.

The DTO parses both statuses, but a successful own-profile response with
inactive status contradicts the protected active-Institution route. Clear
feature state, render no profile, and run the task's current-session lifecycle
bootstrap reconciliation.

PATCH trusted success additionally requires status `200` and exact message:

```text
Institution profile updated successfully.
```

Ignore additive transport keys but never expose/copy them into domain/UI. Never
render/send creator, lifecycle metadata beyond public status, settings, counts,
Users, tokens, relationships, learning data, or raw transport values.

Use focused Institution Admin domain types; do not import Platform domain
models as authority.

## 5. Exact Form Boundary

Editable only, in order:

```text
name
contact_email
contact_phone
address
description
```

Read-only/backend-controlled:

```text
id, type, status, created_at, updated_at, every other key
```

Normalize exactly as the task requires:

- trim name;
- trim email/phone and map blank to null;
- map whitespace-only address/description to null while preserving non-empty
  multiline values exactly;
- compare to a normalized snapshot from the current verified profile;
- serialize only actually changed keys; and
- send explicit null only for a changed nullable clear.

Client validation is UX only: name required/max 200, email nullable/permissive
single-`@`/no whitespace/max 254, phone nullable/max 50, no invented address or
description maximum.

Cancel sends nothing. No-change sends no PATCH and shows `No changes to save.`.
Local/server validation maps only approved fields and focuses the first invalid
control. One active submit produces one PATCH.

## 6. State, Session, and Freshness

Use the task's exact semantic states for initial/loading/data/editing/
submitting/validation/failure/reconciling/confirmed-direct-success/
unconfirmed-current-state/outcome-unknown/load-error.

The profile provider must be `autoDispose`, created only by the Institution
route, and keyed by current User ID + Institution ID without sending either to
the endpoint. Enforce the complete task eligibility matrix. Other Institution
Admin routes issue zero profile requests. Leaving disposes state; returning
loads fresh data.

Use current-operation generation plus live User/Institution/eligibility and
response-ID checks. Reject every stale success/failure after Refresh, Retry,
newer operation, logout, central invalidation, disposal, account/tenant/role
switch, or router/ProviderScope recreation.

Preserve central token-version-aware `401` invalidation. Do not clear tokens or
emit a second signal. For current `password_change_required`, `user_inactive`,
or `institution_inactive`, clear protected feature state and invoke the existing
session bootstrap exactly once. Do not invent meaning for an unrecognized
`409` or other code.

## 7. Mutation Safety and Reconciliation

Never automatically retry PATCH.

Treat received HTTP error responses and bad certificate as definite failures.
Treat current-operation connection/send/receive/transform timeouts, connection
error, cancel, unknown transport error, unexpected 2xx, malformed/missing
success resource/message, and response-ID mismatch as a typed uncertain
mutation outcome.

For one uncertain PATCH:

1. enter reconciling;
2. issue at most one automatic read-only profile GET;
3. never resend PATCH;
4. require the same current eligible session and matching response ID;
5. compare only originally changed keys to fetched normalized server values;
6. equal → publish fetched complete current server state and remain
   unconfirmed with no success wording;
7. different → publish fetched complete current server state and remain
   unconfirmed with no success/failure claim; and
8. a current-session reconciliation failure/malformed/wrong-ID result → locked
   outcome-unknown surface with GET-only `Reload profile`, never mutation
   replay.

A reconciliation GET proves only current server state. Even an exact match
cannot prove that this client PATCH caused the values. Only the exact direct
PATCH `200` response with the required envelope, resource, message, current
session, and matching Institution ID may enter success. Use the task's exact
equal/different unconfirmed copy and keep direct success distinct from
`unconfirmedCurrentState` through the task's `confirmedDirectSuccess` state.
Both valid current-state outcomes permit only a later new explicit edit from
the fetched baseline; neither retries or continues the earlier PATCH.

A stale reconciliation completion is ignored and must not alter the newer or
disposed context.

Manual reload is deduplicated and creates a fresh verified baseline before any
new conscious edit.

## 8. Shell Institution Name

Add exactly the detailed task's bounded method:

```dart
bool reconcileInstitutionNameFromServer({
  required String expectedUserId,
  required String expectedInstitutionId,
  required String institutionName,
});
```

It may update only cached nested `AuthInstitution.name` from a verified matching
profile for the same eligible User/Institution. Preserve every other auth/User/
Institution/token/generation value; perform no HTTP/storage/router action; emit
no state when unchanged; reject stale/mismatched/noneligible calls.

Call it after every verified matching GET/direct PATCH/reconciliation GET. A
valid reconciliation GET may synchronize the current server name without
confirming the earlier mutation. If the live session rejects the
reconciliation, treat the feature completion as stale and do not render it. Do
not call `/auth/me` merely to refresh the shell name.

## 9. Presentation Contract

Use one inline form on the same route, not a second route/dialog.

Exact heading:

```text
Institution Profile
```

View rows, in order:

```text
Name
Type
Status
Contact email
Contact phone
Address
Description
Created at
Updated at
```

Use exact type/status labels, `Not provided` for nullable values, and
`yyyy-MM-dd HH:mm UTC` timestamps. Do not display the UUID.

Implement exact Refresh/Edit profile/Cancel/Save changes/Saving/Verifying,
loading/error/Retry/Retrying, notices, outcome-unknown/Reload profile/Reloading,
messages, and widget keys from the task.

Preserve the shell around every eligible state. Prove responsive scrolling,
long/null/multiline values, `800×600` and `1440×900`, text scales `1.0`/`2.0`,
keyboard/focus/live-region semantics, first-error focus, disabled semantics, and
non-color-only status.

## 10. Exact Application/Test Allowlist

Only these application paths may change:

```text
frontend/lib/app/router/app_router.dart
frontend/lib/features/auth/application/auth_session_controller.dart
frontend/lib/features/institution_admin/domain/institution_profile.dart
frontend/lib/features/institution_admin/domain/institution_profile_update.dart
frontend/lib/features/institution_admin/domain/institution_profile_repository.dart
frontend/lib/features/institution_admin/data/dto/institution_profile_dto.dart
frontend/lib/features/institution_admin/data/institution_profile_remote_data_source.dart
frontend/lib/features/institution_admin/data/institution_profile_repository_impl.dart
frontend/lib/features/institution_admin/application/institution_profile_state.dart
frontend/lib/features/institution_admin/application/institution_profile_controller.dart
frontend/lib/features/institution_admin/presentation/institution_profile_formatters.dart
frontend/lib/features/institution_admin/presentation/institution_admin_profile_screen.dart
frontend/lib/features/institution_admin/presentation/institution_admin_placeholder_screen.dart
```

Only these test paths may change:

```text
frontend/test/features/auth/auth_session_controller_test.dart
frontend/test/features/institution_admin/institution_profile_dto_test.dart
frontend/test/features/institution_admin/institution_profile_edit_form_value_test.dart
frontend/test/features/institution_admin/institution_profile_remote_data_source_test.dart
frontend/test/features/institution_admin/institution_profile_repository_impl_test.dart
frontend/test/features/institution_admin/institution_profile_controller_test.dart
frontend/test/features/institution_admin/institution_profile_formatters_test.dart
frontend/test/features/institution_admin/institution_admin_profile_screen_test.dart
frontend/test/features/institution_admin/institution_admin_shell_test.dart
frontend/test/router_bootstrap_test.dart
```

Bookkeeping is limited to this task/prompt, `tasks/STAGE_03_TASK_INDEX.md`, and
`tasks/README.md` exactly as the detailed task's phases permit.

In `app_router.dart`, replace only the Institution placeholder builder/import.
In the placeholder file, remove only that placeholder. Preserve route constants,
topology/order/guards/shell and all other real/placeholder children. The auth
controller change is only the bounded server-name reconciliation method.

No other application/test/task/package/backend/docs/generated path may change.
Stop rather than widen the allowlist.

## 11. Required Verification

Implement the complete detailed-task test matrices for:

- DTO/envelope/types/nulls/enums/UUID/timestamps/exact PATCH message;
- form normalization/validation/diff/null/allowlist/no-change;
- exact GET/PATCH requests and no tenant input;
- definite versus uncertain failure mapping and zero mutation replay;
- repository/domain mapping;
- controller states/dedup/freshness/session/ID/stale boundaries;
- one-GET reconciliation equal-unconfirmed/different-unconfirmed/error/wrong-
  ID/stale cases and direct-success-only proof;
- central 401 and lifecycle bootstrap behavior;
- bounded auth session name sync and all rejection/no-op cases;
- exact UI labels/keys/messages/actions/formatting;
- responsive, text-scale, keyboard, focus, semantics, live regions;
- shell name update without auth GET/route reset/duplicate profile GET; and
- full auth/router/Dashboard/Platform/shell regression.

Run from `frontend/`:

```text
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/features/institution_admin
flutter test test/features/auth/auth_session_controller_test.dart
flutter test
flutter build windows --debug
```

Run all additional checks required by `frontend/AGENTS.md`, complete scope/
secret/diff verification, and the detailed task's controlled Windows real-stack
smoke. `FAIL` blocks. `NOT RUN` is allowed only under the task's exact genuine-
unavailability rule with equivalent automated coverage.

## 12. Phase 1 Bookkeeping

During Phase 1 only:

- set only the S03-FE-003 index row to
  `In Progress / Not started / Not started`;
- keep this detailed task `Approved`;
- preserve this prompt byte-for-byte;
- keep README on the truthful pre-acceptance gate;
- inspect the complete diff including owner-prepared authority files; and
- do not commit or push.

## 13. Phase 2 — Strict Read-Only Gate

After all Phase 1 work/checks, perform a separate read-only acceptance review.

During Phase 2:

```text
no edits or formatter/auto-fix
no generated writes
no bookkeeping changes
no staging/commit
no push/PR/merge
no self-fixing findings
```

Classify all findings using the detailed task:

- P1: security/tenant/secret/destructive/replay/read-only-gate violation;
- P2: material contract/state/reconciliation/session/UI/test/scope/workflow
  defect;
- P3: genuinely non-blocking observation.

Any unresolved P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start S03-FE-004.

## 14. Phase 3 — Delivery After PASS Only

Only after zero unresolved P1/P2:

1. mark this detailed task `Accepted` without changing approved behavior;
2. prepare only the S03-FE-003 index row as
   `Accepted / PASS / Delivered` in the delivery commit;
3. update README truthfully: Stage 3 `In Progress`, S03-FE-003 delivered,
   S03-FE-004 next gate;
4. preserve all later task states, Stage 3 open, and Stage 4 not started;
5. verify this prompt remains byte-for-byte equal to its Phase 0 SHA;
6. rerun final non-writing scope/secret/diff/status checks;
7. stage only exact allowed implementation/tests/bookkeeping; and
8. commit exactly:

```text
feat(institution): add own profile UI

Task: S03-FE-003
```

Push without force, open a focused PR to `main`, verify exact base/head/commits/
files/title/body/checks/reviews/mergeability, and merge only the reviewed head
through the repository-approved normal merge-commit flow. Never squash, rebase,
rewrite history, bypass checks, or silently replace the remote.

Fetch/sync non-destructively and prove implementation ancestry, expected merge
parents, `local main == origin/main`, clean tree, truthful delivered statuses,
Stage 3 still In Progress, and Stage 4 not started.

Phase 2 PASS but incomplete safe delivery:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Complete verified delivery:

```text
FINAL STATUS: ACCEPTED
```

Only after ACCEPTED state:

```text
Next implementation gate: S03-FE-004.
```

Return every evidence item required by the detailed task, including source
hashes, exact files, requests, DTO/form/state/reconciliation/session/shell/UI
proof, tests/build/smoke, Phase 2 findings, scope/secret integrity, and complete
GitHub delivery verification.
