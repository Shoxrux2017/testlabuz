# S04-FE-003 — Institution Group Edit and Archive Lifecycle

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S04-FE-003` |
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | `Frontend` |
| Status | `Draft` |
| Review | `Pending` |
| Depends on | `S04-FE-002 Accepted / Delivered` |
| Delivery | `Implementation + GitHub delivery` |

This file is the complete task-specific implementation contract for Codex.

> **Execution gate:** This file is intentionally stored before final review. Codex must not implement this task while `Status = Draft`. ChatGPT/reviewer must complete read-only review, resolve findings, change the task to `Approved`, and deliver that planning update to `main` first.

Codex must use only this contract, applicable `AGENTS.md` files, and directly relevant source/tests. Do not read product docs, roadmap, previous tasks, Stage history, or closure reviews to determine behavior.

---

## 2. Goal

Extend the S04-FE-002 Group Detail experience with safe Institution Admin lifecycle actions:

1. edit an active Group through:

```text
PATCH /api/v1/institution/groups/{group}
```

2. archive an active Group through:

```text
POST /api/v1/institution/groups/{group}/archive
```

The frontend must preserve backend authority, reject stale mutation completions, handle uncertain mutation outcomes through authoritative read reconciliation, and make archived Groups read-only.

---

## 3. Scope

### Included

- Add active-Group `Edit` action to Group Detail.
- Add active-Group `Archive Group` action with explicit confirmation.
- Implement controlled edit form with exact partial PATCH semantics.
- Detect client-side no-op and send no empty/unchanged PATCH.
- Implement archive request with no body/query.
- Add strict mutation success/error parsing.
- Add `business_conflict` stable code support required by Group lifecycle.
- Reconcile uncertain mutation outcomes with authoritative Group Detail GET.
- Reconcile stale active UI when edit loses a race to archive.
- Replace Group Detail from confirmed/reconciled server state only.
- Mark retained Group-list data stale after mutations/current-state changes without clearing retained query/filter/page state.
- Make archived Group Detail read-only.
- Preserve dialog focus, keyboard, accessibility, session/tenant, and stale-async ownership.
- Add focused deterministic tests.

### Non-goals

Do **not** implement:

- Group reactivation;
- hard delete;
- Group create/detail/list behavior beyond integration required by this task;
- Teacher membership management;
- Student membership management;
- Parent–Student relationships;
- membership count editing;
- client-created `archived_at`;
- optimistic lifecycle state;
- automatic mutation retry/replay;
- route changes or a separate Group edit route;
- backend/schema/API changes;
- dependency/package changes.

---

## 4. Current Implementation Context

S04-FE-001 owns Group navigation/list/query/DTO/read state.

S04-FE-002 owns:

- `/institution-admin/groups/new`;
- `/institution-admin/groups/:groupId`;
- Create Group;
- Group Detail GET;
- strict Group DTO/model;
- detail controller/state;
- authoritative detail refresh/not-found behavior;
- retained list state across Group routes.

Reuse the established Institution User mutation/action architecture as a local pattern:

```text
Detail Screen
  -> Action Controller / State
  -> Mutation Repository
  -> Mutation Remote Data Source
  -> configured Dio
```

Relevant existing patterns include:

- `InstitutionUserActionController`;
- `InstitutionUserActionState`;
- edit/lifecycle dialogs inside the detail screen;
- mutation uncertain-outcome reconciliation via authoritative detail GET;
- focus restoration after dialogs;
- list stale marking without losing retained query state.

Do not refactor Institution User code into a speculative generic mutation framework.

---

# 5. Exact Implementation Contract

## 5.1 Group lifecycle visible in UI

A Group has only:

```text
active
archived
```

For this task:

### Active Group

Show:

```text
Edit
Archive Group
```

### Archived Group

Do **not** show enabled Edit or Archive actions.

Show a clear read-only indication:

```text
Archived groups are read-only.
```

There is no Group reactivation endpoint in Stage 4. Do not add a `Reactivate`, `Restore`, or `Delete` action.

Backend remains authoritative if the locally displayed state becomes stale.

---

## 5.2 Edit UX boundary

Edit is implemented as a modal dialog opened from the existing Group Detail screen.

Do **not** create a new route.

Dialog title:

```text
Edit Group
```

Fields:

```text
Name
Level
Subject direction
Description
```

Actions:

```text
Cancel
Save changes
```

The form is initialized from the exact currently confirmed Group object owned by the Group Detail controller.

Opening Edit is allowed only when:

- Group Detail is in confirmed `data`;
- target is the current route Group;
- Group status is `active`;
- no other Group action is active;
- current Institution Admin session/device ownership remains eligible.

---

## 5.3 Edit field normalization and validation

Use the same field limits and normalization as Group create/backend update.

### Name

- required;
- trim before comparison/request;
- normalized value must be non-empty;
- maximum 160 Unicode code points;
- cannot become JSON `null`;
- do not rewrite case, punctuation, or internal whitespace.

Safe messages:

```text
Group name is required.
Group name must be 160 characters or fewer.
```

### Level

- UI value is `group.level ?? ''`;
- maximum 100 code points after trim;
- exact empty UI value `""` represents JSON `null`;
- non-empty input is trimmed;
- spaces-only non-empty input is invalid;
- no other normalization.

Safe messages:

```text
Level must not contain only spaces.
Level must be 100 characters or fewer.
```

### Subject direction

- UI value is `group.subjectDirection ?? ''`;
- maximum 160 code points after trim;
- exact empty UI value represents JSON `null`;
- non-empty input is trimmed;
- spaces-only non-empty input is invalid.

Safe messages:

```text
Subject direction must not contain only spaces.
Subject direction must be 160 characters or fewer.
```

### Description

- UI value is `group.description ?? ''`;
- multiline input;
- no client-invented maximum;
- exact empty UI value represents JSON `null`;
- non-empty input is trimmed;
- spaces-only non-empty input is invalid;
- preserve internal whitespace/newlines/punctuation/case.

Safe message:

```text
Description must not contain only spaces.
```

Duplicate Group names are allowed. Do not add uniqueness validation.

---

## 5.4 Exact partial update request

Endpoint:

```text
PATCH /institution/groups/{groupId}
```

No query parameters.

Send an `application/json` object containing **only normalized fields whose values differ from the selected confirmed Group**.

Allowed keys:

```text
name
level
subject_direction
description
```

Examples:

Change only name:

```json
{
  "name": "10-B"
}
```

Clear description:

```json
{
  "description": null
}
```

Never send:

```text
id
institution_id
status
created_by_user_id
teachers_count
students_count
archived_at
created_at
updated_at
```

or any other key.

### Local no-op

If normalized form values equal the selected Group:

- do not send PATCH;
- keep the dialog open;
- show:

```text
No group changes to save.
```

The frontend must not intentionally send `{}`.

The backend still remains no-op safe if equal values are ever sent, but this client must avoid the request.

---

## 5.5 Update success contract

Confirmed update success requires:

```text
200 OK
```

and exact top-level envelope:

```json
{
  "data": {
    "...": "exact Group resource"
  },
  "message": "Group updated successfully."
}
```

Require exact message:

```text
Group updated successfully.
```

Parse `data` with the strict S04-FE-001 Group DTO.

The returned Group must satisfy:

- returned UUID equals route target UUID;
- `status == active`;
- `archived_at == null`;
- every field included in the PATCH equals the normalized submitted value.

Do **not** require untouched fields or membership counts to equal the pre-request object because another serialized operation may have changed unrelated current values before this mutation acquired the backend lock.

Malformed 200, wrong message, mismatched target, mismatched submitted field, invalid Group resource, or any unexpected status is not confirmed success.

### Confirmed update UI

On direct confirmed success:

1. replace the current Group Detail with the returned authoritative Group only if the selected object/session/target operation still owns publication;
2. mark the Group list stale without clearing its retained query/search/filter/sort/page state;
3. close the edit dialog;
4. show live-region feedback on Group Detail:

```text
Group updated successfully.
```

5. restore focus to `Edit` if that action still exists/currently owns focus restoration.

Do not patch Group list rows optimistically.

---

## 5.6 Archived-update conflict

Backend behavior is authoritative:

```text
PATCH active Group    -> may update
PATCH archived Group  -> 409 business_conflict
```

Archived precedence applies even when submitted values would otherwise be an exact no-op.

Add/reuse stable machine code:

```text
business_conflict
```

in the existing frontend error-code boundary if it does not already exist.

For exact:

```text
409 business_conflict
```

during Group edit:

- treat the PATCH as definitely rejected;
- do not retry the PATCH;
- mark Group list data stale;
- perform one authoritative Group Detail GET reconciliation for the current target.

After reconciliation:

### Current Group is archived

Replace Detail with current archived Group, close stale edit dialog, and show:

```text
Group is archived and can no longer be edited.
```

### Current Group remains active

Replace Detail with the current Group and show:

```text
The group update was not accepted in its current state.
```

### Reconciliation returns 404

Move Group Detail to the same not-found state used by S04-FE-002.

### Reconciliation cannot safely read current state

Do not invent lifecycle state. Close/settle the mutation safely and expose:

```text
The group update was not accepted. Refresh the group to review its current state.
```

The existing Group Detail `Refresh` remains the recovery path.

Do not branch on backend human-readable message text.

---

## 5.7 Edit validation and definite errors

A mutation failure may be treated as definite only when the response has an exact expected error envelope.

Recognized definite errors:

```text
401 authentication_required

403 forbidden
403 password_change_required
403 user_inactive
403 institution_inactive

404 resource_not_found

409 business_conflict

422 validation_failed

429 rate_limited
```

For edit `422 validation_failed`, map known keys:

```text
name              -> Review the group name.
level             -> Review the level.
subject_direction -> Review the subject direction.
description       -> Review the description.
```

If validation contains only protocol/body/unknown keys or cannot be safely mapped, show form-level:

```text
The update request did not match the server contract.
```

Other safe edit messages:

```text
forbidden    -> You do not have permission to change this group.
rate_limited -> Too many requests. Wait before trying again.
default      -> The group update was not accepted.
```

`404 resource_not_found` moves Detail to not-found and closes the stale action.

Session-authority failures use existing auth/session reconciliation and must not leave stale Group mutation state visible.

---

## 5.8 Update uncertain outcome

PATCH has no client idempotency-key contract. Do not automatically replay it after an uncertain result.

Treat update as **outcome unknown** when commit success cannot be proven, including:

- connection interruption after dispatch;
- timeout;
- 5xx;
- malformed/unexpected error envelope;
- unexpected HTTP status;
- malformed/mismatched `200` success;
- unexpected post-dispatch exception.

On unknown outcome:

1. keep mutation ownership bound to the original immutable request snapshot/session/target;
2. mark Group list data stale;
3. show busy reconciliation state:

```text
The request result could not be confirmed. Checking the current server state…
```

4. issue one authoritative:

```text
GET /institution/groups/{groupId}
```

5. do not replay PATCH.

If current Group is returned:

- replace Group Detail with current server state;
- close the edit dialog after reconciliation settles;
- compare **only submitted changed fields** with current values.

If all submitted fields match:

```text
Current server state includes your requested values, but the update result could not be confirmed.
```

If any submitted field differs:

```text
Current server state differs from your requested values. The update result remains unconfirmed.
```

If current Group is archived, the Detail becomes read-only regardless of field comparison.

If reconciliation returns 404:

- move detail to not-found;
- no stale Group object remains authoritative.

If reconciliation fails or is malformed:

```text
The update result could not be confirmed. Current server state is unavailable.
```

Do not present confirmed success or confirmed failure.

A later user action must begin from newly confirmed Detail state.

---

## 5.9 Archive confirmation UX

Archive is initiated only from an active confirmed Group Detail.

Open a modal confirmation dialog.

Title:

```text
Archive group?
```

Show the Group name.

Explanation:

```text
Archiving makes this group read-only for future management. Historical relationships and learning records are preserved. Groups cannot be reactivated in the current MVP.
```

Actions:

```text
Cancel
Archive Group
```

Before request:

- Cancel/Escape/dismissal follows the established Institution Admin action-dialog behavior;
- no mutation occurs until explicit confirmation.

While archive/reconciliation is busy:

- prevent duplicate confirmation;
- disable Cancel and Archive actions;
- prevent pop/dismissal through `PopScope`/equivalent;
- expose semantic progress.

Progress labels:

```text
Archiving group
Checking current server state
```

---

## 5.10 Exact archive request

Endpoint:

```text
POST /institution/groups/{groupId}/archive
```

Send:

```text
no request body
no query parameters
```

Do not send `{ "status": "archived" }`, reason, timestamp, force flag, tenant ID, or any other data.

Backend controls the authoritative archive timestamp.

---

## 5.11 Archive backend lifecycle semantics consumed by UI

Backend semantics:

```text
active
  -> archived
  -> status = archived
  -> archived_at = authoritative server time
  -> updated_at advances

archived
  -> archived
  -> idempotent 200
  -> no new archive timestamp
  -> archived_at preserved
  -> updated_at preserved
```

Frontend must not calculate/archive timestamp locally.

Frontend normally hides the action after confirmed archived state, but if another actor archives first and this request reaches an already archived Group, the backend's idempotent `200` remains a valid confirmed success.

Archiving does not delete Group relationships/history.

---

## 5.12 Archive success contract

Confirmed archive success requires:

```text
200 OK
```

with exact:

```json
{
  "data": {
    "...": "exact Group resource"
  },
  "message": "Group archived successfully."
}
```

Require exact message:

```text
Group archived successfully.
```

Returned Group must:

- match route target UUID;
- have `status == archived`;
- have non-null valid `archived_at`.

Do not require `archived_at` to differ from the selected Group because archive is backend-idempotent.

### Confirmed archive UI

On confirmed success:

1. replace Group Detail with returned server Group;
2. mark Group list stale while retaining list query/filter/page state;
3. close archive dialog;
4. remove Edit/Archive actions because Detail is archived;
5. show live-region feedback:

```text
Group archived successfully.
```

6. restore focus to the Group Detail heading/read-only surface rather than a removed Archive button.

Do not invalidate Institution Admin dashboard solely for Group lifecycle in this Stage: the current dashboard contract contains only user counts, not Group metrics.

---

## 5.13 Archive definite errors

Recognized definite errors use the same strict envelope set:

```text
401 authentication_required
403 forbidden
403 password_change_required
403 user_inactive
403 institution_inactive
404 resource_not_found
409 business_conflict
422 validation_failed
429 rate_limited
```

Current backend archive is idempotent and does not normally return lifecycle `409`; if an exact future/current `409 business_conflict` is received, do not reinterpret the human message or invent a state. Reconcile current Group through GET and show safe general lifecycle feedback.

Safe archive messages:

```text
forbidden    -> You do not have permission to archive this group.
validation_failed -> The archive request did not match the server contract.
rate_limited -> Too many requests. Wait before trying again.
default      -> The archive request was not accepted.
```

`404 resource_not_found` moves Detail to not-found.

Session failures use normal auth/session reconciliation.

---

## 5.14 Archive uncertain outcome

Although archive is backend-idempotent, the client must not silently auto-replay an uncertain lifecycle mutation.

For connection/timeout/5xx/malformed success/unexpected status/malformed error/unknown post-dispatch result:

1. mark list stale;
2. do not replay POST;
3. reconcile with one authoritative Group Detail GET.

If current status is `archived`:

```text
The group is currently archived, but this archive request result could not be confirmed.
```

If current status is `active`:

```text
The group is still active. The archive request result could not be confirmed.
```

If current target is 404:

- move Detail to not-found.

If current state cannot be read:

```text
The archive result could not be confirmed. Current server state is unavailable.
```

Never manufacture success from device time or local state.

---

## 5.15 Mutation ownership and stale completion safety

Implement a focused Group action controller/state family keyed by route `groupId`, consistent with the existing Institution User action pattern.

An operation owns:

- exact eligible Institution Admin session key;
- authenticated user instance;
- institution ID;
- route Group UUID;
- identity of the confirmed selected Group object used to open the action;
- operation kind: edit/archive;
- immutable normalized submitted edit request where applicable;
- operation generation;
- focus-restoration key.

A completion/reconciliation may publish only when all ownership still matches.

Reject stale publication when:

- session/user instance changes;
- institution changes;
- device eligibility changes;
- route target changes;
- selected confirmed Group object is replaced;
- provider/action is disposed;
- a newer operation supersedes it.

A stale completion must not:

- replace a newer Group Detail;
- reopen/close the wrong dialog;
- show feedback in a later session;
- restore focus to an obsolete button;
- navigate.

Actual Dio cancellation is not required.

---

## 5.16 Detail controller mutation integration

Extend the S04-FE-002 Group Detail controller only with narrowly required mutation hooks equivalent to the existing Institution User pattern.

Required safe operations include behavior equivalent to:

```text
replaceFromMutation(selectedGroup, returnedGroup)
markNotFoundFromMutation(selectedGroup)
```

Replacement is allowed only when:

- current target matches;
- current detail Group is the exact selected object owned by the action;
- returned Group UUID matches target;
- current session ownership remains valid.

On replacement, use the returned/reconciled authoritative Group as the new confirmed Detail state.

Do not create a parallel Group detail cache.

---

## 5.17 Group-list stale/invalidation behavior

Any mutation that:

- is confirmed successful;
- has uncertain commit outcome;
- returns 404 for a previously displayed target;
- reveals stale lifecycle through `409 business_conflict`;

must ensure S04-FE-001 Group-list data is reloaded before being treated as current again.

Preserve:

```text
search draft
committed search
status filter
sort
direction
page
per-page
```

for the same eligible session.

Do not optimistically patch Group ordering, totals, status, pagination, or row values.

A definite validation/forbidden/rate-limit failure that proves no mutation/current-state change does not require list invalidation unless reconciliation identified stale server state.

---

## 5.18 Dialog close and focus behavior

Follow existing Institution Admin edit/lifecycle accessibility behavior.

### Before submit

- Cancel closes dialog and discards action draft;
- Escape/back may close when not busy;
- restore focus to the triggering action if it still exists/current ownership remains valid.

### During submit/reconciliation

- dialog cannot be dismissed;
- controls disabled;
- progress announced.

### After edit success

- dialog closes;
- focus returns to `Edit`.

### After archive success

- dialog closes;
- Edit/Archive actions disappear;
- focus moves to Group Detail heading/read-only content.

### After stale state invalidates action

- stale dialog closes automatically;
- do not restore focus to a control that no longer exists.

### Validation/form error

- keep edit dialog open;
- focus first invalid field;
- if only form/protocol feedback exists, focus/announce the feedback region.

---

## 5.19 Security and tenant isolation

Eligible frontend actor remains exactly:

```text
authenticated
role = institution_admin
active user
must_change_password = false
active own institution
desktop surface
```

Mutation target UUID does not select tenant scope.

Do not send:

```text
institution_id
created_by_user_id
status
archived_at
tenant selector
```

Backend is authoritative for:

- Institution scope;
- target existence privacy;
- archived lifecycle;
- locking/concurrency;
- timestamps;
- persistence.

Missing and foreign Group targets both remain:

```text
404 resource_not_found
```

and must have the same frontend not-found behavior.

Do not expose edit/archive to other role surfaces.

---

## 5.20 Persistence / concurrency / idempotency boundary

Frontend schema/persistence:

```text
N/A
```

Backend concurrency already serializes Group update/archive with row locks.

Frontend must not reproduce locking rules.

Relevant client behavior:

- update loses to earlier archive -> backend `409 business_conflict`;
- update followed by archive may both succeed in serialization order;
- repeated archive is idempotent;
- no optimistic state;
- no automatic mutation replay;
- uncertain result uses authoritative GET reconciliation.

---

# 6. Architecture and Placement

Expected new files may include:

```text
frontend/lib/features/institution_admin/domain/institution_group_mutation.dart
frontend/lib/features/institution_admin/domain/institution_group_mutation_repository.dart

frontend/lib/features/institution_admin/data/dto/institution_group_mutation_dto.dart
frontend/lib/features/institution_admin/data/institution_group_mutation_remote_data_source.dart
frontend/lib/features/institution_admin/data/institution_group_mutation_repository_impl.dart

frontend/lib/features/institution_admin/application/institution_group_action_controller.dart
frontend/lib/features/institution_admin/application/institution_group_action_state.dart
```

Expected modifications:

```text
frontend/lib/core/network/api_error_codes.dart
frontend/lib/features/institution_admin/application/institution_group_detail_controller.dart
frontend/lib/features/institution_admin/presentation/institution_admin_group_detail_screen.dart
```

May modify the S04-FE-001 Group-list retained-state/controller boundary only as narrowly necessary to mark list data stale while preserving retained query state.

If S04-FE-001/S04-FE-002 established equivalent filenames or combined DTO files, extend the existing ownership rather than duplicating types.

Do not:

- call Dio from Widgets;
- parse JSON in controller/presentation;
- create a second detail cache;
- create a new route for edit;
- create a generic mutation framework spanning unrelated features;
- change backend/docs/schema/packages/platform files.

Any additional file requires concrete in-scope necessity and must be reported.

---

# 7. Acceptance Criteria

- [ ] Active Group Detail exposes `Edit` and `Archive Group`.
- [ ] Archived Group Detail is read-only with no edit/archive/reactivate/delete action.
- [ ] Edit uses a modal dialog, not a new route.
- [ ] Edit fields/normalization/max/null semantics exactly match backend contract.
- [ ] Edit PATCH contains only actually changed allowed fields.
- [ ] Normalized no-op sends no PATCH and reports `No group changes to save.`
- [ ] Duplicate Group names remain allowed.
- [ ] Strict 200 update envelope/message/resource validation is implemented.
- [ ] Exact `409 business_conflict` edit race reconciles current Group state without replay.
- [ ] Unknown update outcomes reconcile through one authoritative GET and never auto-replay.
- [ ] Archive requires confirmation and sends POST with no query/body.
- [ ] Confirmed archive adopts backend `archived_at`; client never invents timestamp.
- [ ] Repeated/already-archived backend success is accepted as idempotent.
- [ ] Unknown archive result reconciles through GET and never auto-replays.
- [ ] Mutation 404 moves Group Detail to the same scope-safe not-found state.
- [ ] Session-authority failures clear stale action ownership.
- [ ] Direct/reconciled returned Group can replace Detail only under exact target/session/selected-object ownership.
- [ ] Group-list data is marked stale when necessary without losing retained query/filter/page state.
- [ ] No optimistic list/detail lifecycle patching.
- [ ] Focus/keyboard/dialog dismissal/progress semantics are safe.
- [ ] No Teacher/Student membership or Parent relationship behavior is introduced.
- [ ] No backend/schema/dependency/public API change.
- [ ] Focused verification and directly affected regressions pass.
- [ ] `git diff --check` passes.
- [ ] Diff has no unrelated changes.

---

# 8. Focused Tests and Verification

## Required focused coverage

### Mutation domain/form

- edit form initializes from active Group;
- name required/trim/max;
- optional empty => null;
- spaces-only optional invalid;
- level/subject max;
- description no invented max;
- changed-fields-only PATCH request;
- clear nullable field -> JSON null;
- normalized no-op -> empty request/no transport;
- duplicate name not rejected;
- submitted request snapshot matching against returned/current Group.

### Mutation DTO/remote data source

Update:

- exact PATCH path;
- exact changed JSON;
- no query;
- exact `200 {data,message}`;
- exact `Group updated successfully.`;
- strict Group DTO;
- target/submitted-field mismatch -> unknown;
- exact definite 401/403/404/409/422/429 envelopes;
- 5xx/timeout/connection/malformed/unexpected status -> unknown.

Archive:

- exact POST path;
- no body/query;
- exact `200 {data,message}`;
- exact `Group archived successfully.`;
- returned target/status/archive invariant;
- exact definite errors;
- malformed/unexpected result -> unknown.

### Repository

- confirmed update requires same ID, active status, changed-field match;
- untouched fields/counts are not compared against stale pre-mutation snapshot;
- confirmed archive requires same ID + archived status + non-null archived_at;
- DTO -> domain mapping;
- unknown outcome propagation.

### Action controller

- action only begins for exact active confirmed Group;
- archived Group cannot begin edit/archive;
- duplicate action/submission suppression;
- local validation/no-op behavior;
- direct edit success replaces Detail and marks list stale;
- direct archive success replaces Detail, makes read-only, marks list stale;
- 422 field mapping/protocol feedback;
- 404 -> not found;
- `409 business_conflict` -> authoritative current-state reconciliation;
- update unknown -> GET reconciliation match/differ/unavailable/not-found;
- archive unknown -> GET reconciliation archived/active/unavailable/not-found;
- no mutation replay;
- session/target/selected-object/generation/dispose stale-completion rejection;
- list retained query preserved;
- focus ownership survives only current action.

### Group Detail widget

- active Edit/Archive buttons;
- archived read-only message and absent actions;
- edit dialog field values, Cancel, Save, validation focus, busy progress;
- no-op message;
- direct success feedback;
- uncertain-current-state feedback;
- archive confirmation content and actions;
- archive busy/dismissal protection;
- success focus moves to heading;
- stale dialog closes;
- 409 archived reconciliation removes actions;
- keyboard/text-scale/desktop overflow/accessibility semantics.

### Existing Group regressions directly affected

- S04-FE-002 Group Detail loading/data/refresh/not-found/error still works;
- S04-FE-001 list retains query and reloads stale data correctly;
- create/detail navigation remains unchanged.

---

## Focused test command

Run only new S04-FE-003 tests plus directly changed Group tests.

Expected shape:

```powershell
fvm spawn 3.44.7 test `
  test/features/institution_admin/institution_group_mutation_domain_test.dart `
  test/features/institution_admin/institution_group_mutation_remote_data_source_test.dart `
  test/features/institution_admin/institution_group_mutation_repository_impl_test.dart `
  test/features/institution_admin/institution_group_action_controller_test.dart `
  test/features/institution_admin/institution_admin_group_detail_screen_test.dart
```

Also run the exact existing S04-FE-001/S04-FE-002 Group-list/detail/controller test files modified by this task.

If actual filenames established by earlier tasks differ, use those real files and report the exact command.

## Directly affected regression

At minimum rerun the existing focused tests for:

```text
Group list retained-state behavior
Group Detail controller
Group Detail screen
```

No unrelated Institution User regression is required unless shared Institution User code was changed, which this contract does not authorize.

## Static analysis

```powershell
fvm spawn 3.44.7 analyze
```

## Format check

```powershell
C:\Users\Administrator\fvm\versions\3.44.7\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed lib test
```

## Build

```text
Not required for this task.
```

## Always

```text
git diff --check
```

Then inspect the complete diff for:

- exact task scope;
- no route/package/backend/schema changes;
- no unrelated refactor/format churn;
- no weakened tests;
- no automatic mutation replay;
- no optimistic authoritative state;
- safe `business_conflict` handling;
- safe uncertain-outcome reconciliation;
- stale session/target completion rejection;
- no raw exceptions/JSON/tokens/debug output/secrets.

Do not run the full frontend suite, Windows build, broad E2E, or Frontend Phase 2 in this task. Those belong to the frontend block checkpoint unless a concrete unexpected shared-infrastructure risk invalidates this verification scope; report that mismatch instead of silently broadening verification.

---

# 9. Delivery

Future Build Runner/Codex execution uses:

```text
branch: task/s04-fe-003-group-edit-archive
commit: feat(frontend): add group edit and archive
PR: focused PR to main
```

After merge:

```text
local main == origin/main
ahead/behind = 0/0
working tree = clean
```

Do not modify Stage/task bookkeeping during implementation unless the active orchestration step explicitly assigns it.

If implementation/verification passes but safe GitHub delivery cannot complete:

```text
DELIVERY BLOCKED
```

---

# 10. Codex Completion Report

Return concise evidence:

1. `ACCEPTED`, `BLOCKED`, or `DELIVERY BLOCKED`.
2. Implementation summary.
3. Changed files and purpose.
4. Acceptance-criteria evidence.
5. Exact verification commands/results.
6. Update/archive direct-success and uncertain-outcome evidence.
7. `409 business_conflict`/404/session/tenant evidence.
8. Stale async/focus ownership evidence.
9. `git diff --check` + focused scope/diff self-review.
10. Commit/PR/merge/main-sync evidence.
11. Exact deviations/blockers.

If any product, architecture, API, security, tenant, lifecycle, concurrency, mutation-outcome, async-ownership, or UX decision required by this task is missing or conflicts with current implementation, return `BLOCKED` instead of inventing behavior.
