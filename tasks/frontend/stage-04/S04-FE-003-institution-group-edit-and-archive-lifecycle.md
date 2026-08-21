# S04-FE-003 — Institution Group Edit and Archive Lifecycle

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S04-FE-003` |
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | `Frontend` |
| Status | `Approved` |
| Review | `Complete` |
| Depends on | `S04-FE-002 Accepted / Delivered` |
| Delivery | `Implementation + GitHub delivery` |

Start implementation only when S04-FE-002 is present on synchronized `origin/main` as Accepted / Delivered.

This file is the complete task-specific implementation contract for Codex.

Codex must use only this contract, applicable `AGENTS.md` files, and directly relevant source/tests. Do not read product docs, roadmap, previous/future task contracts, Stage history, checkpoint reviews, or closure reviews to determine behavior.

---

## 2. Goal

Extend the delivered Group Detail experience with safe Institution Admin lifecycle actions:

```text
PATCH /api/v1/institution/groups/{group}
POST  /api/v1/institution/groups/{group}/archive
```

The task must:

- edit only active Groups;
- archive active Groups with confirmation;
- make archived Groups read-only;
- preserve backend lifecycle/tenant authority;
- avoid optimistic authoritative state;
- avoid automatic mutation replay;
- reconcile mutation uncertainty and lifecycle races through authoritative Group Detail GET;
- prevent stale mutation completions from replacing newer session/target/detail state.

---

## 3. Scope

### Included

- Add `Edit` and `Archive Group` actions to confirmed active Group Detail.
- Add read-only archived Group Detail indication.
- Implement modal edit dialog.
- Implement modal archive confirmation.
- Implement exact changed-fields-only partial PATCH.
- Detect normalized client-side no-op and send no PATCH.
- Implement archive POST with no query and zero request-body bytes.
- Add strict mutation DTO, repository, remote data source, action controller/state.
- Add stable frontend `business_conflict` machine code if absent.
- Parse exact mutation success/error envelopes.
- Reconcile edit `409 business_conflict`.
- Reconcile uncertain update/archive outcomes through one authoritative Group Detail GET.
- Reconcile mutation `404` to the existing privacy-safe Detail not-found state.
- Discard stale confirmed Detail when reconciliation cannot establish current server state.
- Mark Group-list data stale only when required, preserving retained query state.
- Preserve focus/keyboard/dialog/accessibility/session/tenant/stale-async correctness.
- Add focused deterministic tests.

### Non-goals

Do **not** implement:

- Group reactivation/restore;
- hard delete;
- separate Group edit route;
- route changes;
- Group create behavior changes except compatibility regression;
- Teacher membership management;
- Student membership management;
- Parent–Student relationships;
- membership-count editing;
- client-generated `status`, `archived_at`, or `updated_at`;
- optimistic Group Detail lifecycle mutation;
- optimistic Group-list row/order/pagination/count mutation;
- automatic PATCH replay;
- automatic archive POST replay;
- Idempotency-Key;
- Institution Dashboard invalidation;
- backend/schema/API changes;
- package/dependency/platform changes;
- generic mutation infrastructure spanning unrelated features;
- refactor of Institution User action code.

---

## 4. Current Implementation Context

Implementation starts only after S04-FE-002 is delivered.

Reuse the **delivered** Group ownership boundaries instead of creating parallel state:

```text
InstitutionGroup
strict Group DTO
Group Detail repository/controller/state/screen
Group-list retained query + stale/reload owner
Group route/session key conventions
```

Use the established local Institution User mutation pattern where responsibilities match:

```text
Detail Screen
  -> Action Controller / State
  -> Mutation Repository
  -> Mutation Remote Data Source
  -> configured Dio
```

Relevant existing behavior pattern:

- controlled edit dialog;
- action family keyed by route resource ID;
- exact selected-object/session/target ownership;
- immutable submitted request snapshot;
- strict mutation success parsing;
- exact definite-error recognition;
- unknown mutation outcome -> authoritative detail read;
- safe Detail replacement/not-found hooks;
- list retained query + stale-session marker;
- focus restoration only for current controls.

Do not copy User-specific business behavior or create a cross-feature generic action framework.

---

# 5. Exact Backend Contract Consumed by Frontend

## 5.1 Group lifecycle

Machine states:

```text
active
archived
```

Frontend presentation:

```text
active:
  Edit
  Archive Group

archived:
  no Edit
  no Archive Group
  no Reactivate
  no Restore
  no Delete

  Archived groups are read-only.
```

Backend remains authoritative when displayed active state becomes stale.

There is no Group reactivation endpoint in this Stage.

---

## 5.2 Update endpoint

Exact endpoint:

```text
PATCH /institution/groups/{groupId}
```

Requirements:

```text
canonical validated Group UUID
application/json object
no query parameters
at least one allowed changed field
```

Allowed JSON keys only:

```text
name
level
subject_direction
description
```

Do not send:

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
any unknown key
```

The backend:

- scopes Group through authenticated institution;
- locks the fresh Group row;
- rejects archived Group before update/no-op comparison;
- applies only supplied fields;
- performs no SQL UPDATE when supplied normalized values are already current;
- returns a fresh exact Group resource with membership counts.

Frontend must not reproduce backend row-locking or tenant resolution.

---

## 5.3 Archive endpoint

Exact endpoint:

```text
POST /institution/groups/{groupId}/archive
```

Frontend sends:

```text
no query parameters
zero request-body bytes
```

Call the configured Dio client without a `data` argument.

Do not send even an empty JSON object from this frontend flow:

```text
data: {}
data: null
"{}"
JSON null
FormData
status
reason
timestamp
force
tenant/institution ID
```

Backend may accept an empty JSON object as an API shape, but this frontend contract deliberately uses zero body bytes.

Backend lifecycle:

```text
active
  -> archived
  -> archived_at = authoritative server time
  -> updated_at advances

archived
  -> archived
  -> idempotent HTTP 200
  -> archived_at preserved
  -> updated_at preserved
```

Archive preserves memberships/history.

---

# 6. Edit Domain and UX

## 6.1 Opening Edit

Edit is a modal dialog on the existing Group Detail route.

No new route.

Dialog title:

```text
Edit Group
```

Fields, exact order:

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

`beginEdit(selectedGroup)` succeeds only when all are true:

```text
Group Detail status = confirmed data
detail target == route groupId
detail.group is identical to selectedGroup
selectedGroup.id matches route target
selectedGroup.status == active
eligible Institution Admin desktop session
no current Group action owns the target
```

The form initializes from that exact selected confirmed Group object.

---

## 6.2 Unicode length and normalization

Defined string maximums use Unicode code points:

```text
Dart: value.runes.length
```

Do not use UTF-8 byte length or UTF-16 code-unit `String.length` semantics as the contract boundary.

Do not silently truncate drafts.

### Name

```text
UI initial = group.name
required
request normalization = trim outer whitespace
normalized non-empty
max = 160 Unicode code points after trim
preserve internal whitespace/case/punctuation
never null
```

Safe messages:

```text
Group name is required.
Group name must be 160 characters or fewer.
```

### Level

```text
UI initial = group.level ?? ''
exact draft "" -> normalized null
non-empty draft -> trim outer whitespace
spaces-only non-empty draft -> local validation error
max = 100 Unicode code points after trim
```

Safe messages:

```text
Level must not contain only spaces.
Level must be 100 characters or fewer.
```

### Subject direction

```text
UI initial = group.subjectDirection ?? ''
exact draft "" -> normalized null
non-empty draft -> trim outer whitespace
spaces-only non-empty draft -> local validation error
max = 160 Unicode code points after trim
```

Safe messages:

```text
Subject direction must not contain only spaces.
Subject direction must be 160 characters or fewer.
```

### Description

```text
UI initial = group.description ?? ''
multiline
no client-defined maximum
exact draft "" -> normalized null
non-empty draft -> trim outer whitespace only
spaces-only non-empty draft -> local validation error
preserve internal whitespace/newlines/case/punctuation
```

Safe message:

```text
Description must not contain only spaces.
```

Description keyboard behavior:

```text
Enter inserts newline
Enter does not submit
```

Duplicate Group names are valid; do not perform uniqueness checks.

---

## 6.3 Changed-fields-only request

After local validation, compare normalized form values to the exact selected confirmed Group.

Create an immutable request containing only fields whose normalized values differ.

Example:

```json
{
  "name": "10-B"
}
```

Clear nullable field:

```json
{
  "description": null
}
```

A changed request may contain 1..4 allowed keys.

Never intentionally send `{}`.

The request object must:

- freeze changed fields;
- reject unsupported keys;
- expose `isEmpty`;
- serialize exactly the changed map;
- support comparing only submitted changed fields against an authoritative Group during success/reconciliation.

---

## 6.4 Local no-op

If all normalized form values equal the selected Group:

```text
zero PATCH
zero reconciliation GET
zero Group-list invalidation
dialog remains open
```

Show exact live-region form message:

```text
No group changes to save.
```

When any edit field changes after that message:

- clear the no-op form message;
- clear only the changed field's stale field error;
- keep other applicable errors.

Client no-op is not an authoritative lifecycle refresh.

If another actor archived the Group after Detail was loaded, a local no-op does not issue a server request merely to detect that race. The next authoritative Detail refresh or a later non-empty mutation reveals current backend state.

---

# 7. Mutation Transport / DTO Contract

## 7.1 Common success envelope

Update and Archive use the same exact structural envelope:

```json
{
  "data": {
    "...": "exact S04-FE-001 Group resource"
  },
  "message": "endpoint-specific exact message"
}
```

Top-level keys must be exactly:

```text
data
message
```

No unknown/missing keys.

`data` uses the delivered strict Group DTO.

Valid HTTP success:

```text
exactly 200 OK
```

Any other 2xx is not confirmed success.

Configure mutation requests with the existing mutation-safe Dio convention:

```text
followRedirects = false
```

where the delivered project pattern uses it.

---

## 7.2 Update success validation

Exact success message:

```text
Group updated successfully.
```

Confirmed direct update success requires all:

```text
HTTP 200
exact {data,message}
exact message
strict Group resource

routeTarget.id == selected.id == returned.id
UUID comparison case-insensitive

selected.createdAt == returned.createdAt

returned.status == active
returned.archivedAt == null

every field included in immutable PATCH request
    == returned authoritative value
```

Do **not** require these to equal the pre-request selected object:

```text
fields not submitted
teachersCount
studentsCount
updatedAt
```

Another serialized backend operation may have changed unrelated mutable/current values before this mutation acquired the row lock.

Any malformed envelope/resource/message/status, immutable-identity mismatch, target mismatch, lifecycle mismatch, or submitted-field mismatch means:

```text
InstitutionGroupMutationOutcomeUnknownException
```

or equivalent typed unknown outcome.

It is not direct confirmed success.

---

## 7.3 Archive success validation

Exact success message:

```text
Group archived successfully.
```

Confirmed direct archive success requires all:

```text
HTTP 200
exact {data,message}
exact message
strict Group resource

routeTarget.id == selected.id == returned.id
UUID comparison case-insensitive

selected.createdAt == returned.createdAt

returned.status == archived
returned.archivedAt != null
```

Do not require returned `archivedAt` or `updatedAt` to differ from the selected Group because the backend archive endpoint is idempotent.

A stale active frontend can receive the already-archived backend resource from a concurrent earlier archive. That exact 200 is a valid confirmed archive request result.

Any malformed/mismatched result becomes unknown outcome.

---

# 8. Exact Mutation Error Envelope

A mutation response may be treated as a **definite failure** only when both HTTP status/code pairing and exact envelope are valid.

Exact structural envelope:

```json
{
  "message": "non-blank string",
  "code": "non-empty string",
  "errors": {},
  "request_id": "optional non-empty string"
}
```

Required keys:

```text
message
code
errors
```

Only optional key:

```text
request_id
```

No other key is allowed.

Rules:

```text
message = non-blank string
code = non-empty string
request_id, if present = non-empty string
errors = JSON object
```

Every `errors` entry when present:

```text
key = string
value = non-empty JSON array
each item = non-empty string
```

For definite non-422 failures:

```text
errors must be empty
```

Allowed status/code pairs:

```text
401 -> authentication_required

403 -> forbidden
403 -> password_change_required
403 -> user_inactive
403 -> institution_inactive

404 -> resource_not_found

409 -> business_conflict

422 -> validation_failed

429 -> rate_limited
```

Add/reuse exact frontend machine constant:

```text
ApiErrorCodes.businessConflict = business_conflict
```

Do not branch on backend human-readable `message`.

Any malformed envelope, unsupported status/code pair, or unexpected HTTP failure status is an uncertain mutation outcome after dispatch.

---

## 8.1 Edit 422 mapping

Known field keys:

```text
name
level
subject_direction
description
```

Safe messages:

```text
name              -> Review the group name.
level             -> Review the level.
subject_direction -> Review the subject direction.
description       -> Review the description.
```

Protocol/unknown keys include:

```text
body
query key
protected key
unknown key
```

Rules:

- map all known fields to safe local field errors;
- if **any** protocol/unknown key exists, also show:

```text
The update request did not match the server contract.
```

- empty/unusable 422 field-error set shows the same form-level message;
- never render raw backend field-error strings.

---

## 8.2 Safe definite messages

### Edit

```text
forbidden:
You do not have permission to change this group.

rate_limited:
Too many requests. Wait before trying again.

other definite edit failure:
The group update was not accepted.
```

### Archive

```text
forbidden:
You do not have permission to archive this group.

validation_failed:
The archive request did not match the server contract.

rate_limited:
Too many requests. Wait before trying again.

other definite archive failure:
The archive request was not accepted.
```

`404`, `409`, and session failures use dedicated flows below.

---

# 9. Action State / Ownership

Implement a focused Group action controller/state family keyed by route `groupId`.

One operation owns:

```text
eligible Group Detail session key
authenticated user ID
exact AuthUser object instance identity
institution ID
desktop eligibility
route Group UUID
identity of exact selected confirmed InstitutionGroup object
selected.createdAt
operation kind = edit | archive
immutable edit request snapshot when submitted
operation generation
focus-restoration key
```

The action controller watches the delivered Group Detail owner.

If the Detail controller replaces the current Group object with another authoritative object while an action is still bound to the previous selected object:

```text
invalidate the stale operation
close stale dialog
do not publish its later completion
```

Publication requires exact current ownership.

Reject stale completion after:

```text
session/bootstrap replacement
account/user-instance change
institution change
role eligibility loss
user/institution inactive
must-change-password transition
desktop eligibility loss
route target change
detail selected-object replacement
provider/controller dispose
newer operation generation
```

A stale completion must not:

```text
replace newer Detail
change list stale state for another session
close/reopen wrong dialog
show feedback in later session
restore obsolete focus
navigate
```

Actual Dio cancellation is not required.

---

# 10. Dialog / Action Transition Matrix

## 10.1 Detail action availability

Actions are enabled only when:

```text
Detail = confirmed data
Group = active
action controller has no open/busy operation
```

When any edit/archive dialog is open or mutation/reconciliation is active:

```text
Detail Refresh disabled
Edit disabled
Archive disabled
no second Group action dialog
```

Archived Detail has no mutation actions.

---

## 10.2 Edit dialog before submit

Allowed:

```text
Cancel
Escape/back dismissal
normal dialog dismissal
```

Cancel/dismiss:

- discards edit draft/action;
- sends no mutation;
- restores focus to `Edit` only if the same current active Group/detail/session still owns that control.

---

## 10.3 Edit local/definite recoverable failures

For:

```text
local validation
local no-op
422 validation_failed
403 forbidden
429 rate_limited
other non-session definite edit failure
```

the Edit dialog remains open.

After server response:

- fields become editable again;
- Save becomes available again;
- draft is preserved;
- no automatic PATCH retry;
- a later Save is a new explicit user submit.

Focus:

```text
field errors -> first invalid field
form/protocol-only feedback -> feedback region
```

`403`/`429`/general form feedback is announced and dialog stays open.

---

## 10.4 Edit terminal/stale paths

These close the Edit dialog after the state transition/reconciliation settles:

```text
confirmed direct success
409 business_conflict
404 resource_not_found
session authority loss
unknown outcome after reconciliation
selected Detail object replacement
route/session ownership loss
```

Do not restore Edit focus when:

```text
Detail no longer has confirmed active Group
action/session/target ownership is lost
```

---

## 10.5 Archive confirmation before submit

Dialog:

```text
Archive group?
```

Show current Group name.

Exact explanation:

```text
Archiving makes this group read-only for future management. Historical relationships and learning records are preserved. Groups cannot be reactivated in the current MVP.
```

Actions:

```text
Cancel
Archive Group
```

Before submit:

```text
Cancel allowed
Escape/back allowed
barrier dismissal allowed
no mutation until explicit Archive Group
```

Cancel restores Archive focus only if that same active Group/control is still current.

---

## 10.6 Archive busy / definite result

While POST or reconciliation is active:

```text
Cancel disabled
Archive disabled
duplicate confirmation suppressed
dialog dismissal blocked
Detail Refresh/Edit/Archive disabled
```

Semantic progress:

```text
Archiving group
Checking current server state
```

For definite non-session failures:

```text
403
422
429
other recognized non-404/non-409 definite failure
```

after response:

- close archive dialog;
- keep Detail only if still confirmed current active Group;
- show safe feedback on Detail;
- restore Archive focus only if active/current action still exists;
- do not auto-retry.

For:

```text
404
409
session failure
unknown result
```

close dialog as reconciliation/transition settles and never restore an obsolete Archive button.

---

# 11. Group Detail Mutation Hooks

Extend the **delivered S04-FE-002 Group Detail controller** narrowly.

Required behavior equivalent to:

```text
replaceFromMutation(selectedGroup, returnedGroup)
markNotFoundFromMutation(selectedGroup)
markErrorFromMutation(selectedGroup, failure)
```

Actual method names may follow the delivered local naming convention.

All hooks require:

```text
current route target matches
current Detail Group is identical to selectedGroup
selected Group ID matches target
current eligible session still matches
```

### `replaceFromMutation`

Additionally require:

```text
returned Group ID matches target
```

Then:

```text
Detail -> confirmed data(returned authoritative Group)
```

### `markNotFoundFromMutation`

```text
invalidate current Detail read generations
discard Group
Detail -> not_found
```

### `markErrorFromMutation`

```text
invalidate current Detail read generations
discard Group
Detail -> error(current-state unavailable)
```

Do not create a second Group Detail cache.

---

# 12. Group-list Stale Integration

Reuse the **delivered S04-FE-002 Group-list retained-state stale API** or its actual equivalent.

Do not create another Group-list cache/stale store.

Convert the current Detail session key to the existing Group-list session-key convention:

```text
same user ID
same exact user object instance identity
same institution ID
```

Preserve retained:

```text
search draft
committed search
status
page
perPage
sort
direction
```

Never optimistically patch:

```text
row values
status
ordering
pagination total
membership counts
```

### Exact stale timing

#### Direct confirmed update/archive success

After strict success validation and current ownership:

```text
mark list stale
```

Then replace Detail.

#### Update/archive unknown outcome

Before authoritative reconciliation GET:

```text
mark list stale
```

because mutation may have committed.

#### Exact `409 business_conflict`

Before authoritative reconciliation GET:

```text
mark list stale
```

because displayed Detail may be stale.

#### Mutation `404`

```text
mark list stale
Detail -> not_found
```

#### Local no-op / local validation

```text
do not mark stale
```

#### Definite `422` / `403` / `429`

```text
do not mark stale
```

unless a later required reconciliation actually reveals current-state divergence.

Invalidate the route-scoped Group-list provider only through the delivered stale/reload convention needed to ensure the next Groups presentation performs an authoritative load.

Do not invalidate Institution Dashboard.

---

# 13. Edit Direct Success

On strict current direct update success:

1. validate success according to Section 7.2;
2. mark Group list stale;
3. replace Detail via safe selected-object mutation hook;
4. close edit dialog;
5. publish live-region Detail feedback:

```text
Group updated successfully.
```

6. restore focus to `Edit` only if returned authoritative Group remains active and current.

Do not patch Group-list row manually.

If safe Detail replacement fails because ownership is stale:

```text
do not publish success feedback
do not close/focus a newer dialog
```

The stale operation simply loses publication authority.

---

# 14. Edit `409 business_conflict`

For exact:

```text
HTTP 409
code = business_conflict
exact error envelope
```

the PATCH is a definite rejection.

Do not replay PATCH.

Flow:

1. mark Group list stale;
2. show busy reconciliation:

```text
Checking current server state
```

3. issue exactly one authoritative current Group Detail GET through the delivered Detail repository;
4. keep the old Group visible only as explicitly non-authoritative checking context;
5. disable all Detail mutation/refresh actions during reconciliation.

### Reconciliation 200 -> archived

Replace Detail with authoritative archived Group.

Close edit dialog.

Show:

```text
Group is archived and can no longer be edited.
```

Detail becomes read-only.

Do not restore Edit focus.

### Reconciliation 200 -> active

Replace Detail with authoritative active Group.

Close edit dialog.

Show:

```text
The group update was not accepted in its current state.
```

A later edit must begin from this newly confirmed Group object.

### Exact 404

```text
mark Detail not_found
close dialog
no stale Group remains
```

### Session failure

```text
discard old Group/action authority
close dialog
auth/session reconciliation
```

### Other reconciliation failure / malformed read

```text
discard old Group
Detail -> error
close dialog
show:
The group update was not accepted. Current server state is unavailable.
```

Recovery is Detail Retry / Back to Groups.

Do not keep previous active Group in normal confirmed `data`.

---

# 15. Update Unknown Outcome

Do not replay PATCH.

Treat result as unknown when commit success cannot be proven, including:

```text
connection interruption/error after dispatch ambiguity
timeout
Dio cancellation while operation still owns publication
HTTP 5xx
unexpected HTTP status
unexpected 2xx other than 200
malformed/unexpected error envelope
unsupported status/code pair
malformed/mismatched 200 success
response transform/parsing failure
unexpected post-dispatch exception
immutable identity mismatch
submitted-field mismatch
```

Flow:

1. retain immutable original operation snapshot;
2. mark Group list stale;
3. set reconciliation busy state;
4. show:

```text
The request result could not be confirmed. Checking the current server state…
```

5. issue exactly one authoritative Group Detail GET;
6. never replay PATCH.

### Reconciliation 200

Strictly validate current Group detail through delivered Detail repository.

Replace Detail with current authoritative Group.

Close edit dialog.

Compare only the fields included in submitted PATCH.

If all submitted fields match:

```text
Current server state includes your requested values, but the update result could not be confirmed.
```

If any differs:

```text
Current server state differs from your requested values. The update result remains unconfirmed.
```

If current Group is archived, Detail is read-only regardless of field comparison.

Neither message is confirmed mutation success/failure.

### Reconciliation exact 404

```text
Detail -> not_found
close dialog
```

### Session failure

```text
discard old Detail/action authority
close dialog
auth/session reconciliation
```

### Other reconciliation failure

```text
discard old Group
Detail -> error
close dialog
show:
The update result could not be confirmed. Current server state is unavailable.
```

A later mutation may begin only after a newly confirmed Detail is loaded.

---

# 16. Archive Direct Success

On strict current direct archive success:

1. validate according to Section 7.3;
2. mark Group list stale;
3. replace Detail with returned authoritative archived Group;
4. close archive dialog;
5. remove Edit/Archive actions;
6. show live-region feedback:

```text
Group archived successfully.
```

7. move focus to the Group Detail heading/read-only surface.

Never calculate `archivedAt` locally.

Do not invalidate Institution Dashboard.

---

# 17. Archive `409 business_conflict`

Current backend archive is idempotent and does not normally return lifecycle 409.

If an exact:

```text
409 business_conflict
```

is received in this endpoint:

- treat POST as definitely rejected;
- do not infer the conflict reason from human message;
- do not replay POST;
- mark Group list stale;
- perform one authoritative Group Detail GET.

During reconciliation old Detail is non-authoritative and mutation/refresh actions are disabled.

### Current authoritative Group archived

Replace Detail, close dialog, make read-only.

Show:

```text
The group is currently archived.
```

Do not claim this POST caused archive.

### Current authoritative Group active

Replace Detail, close dialog.

Show:

```text
The archive request was not accepted in its current state.
```

### 404 / session / other reconciliation failure

Use the same Detail not-found/session/error transitions defined for edit reconciliation.

For other reconciliation failure, show:

```text
The archive request was not accepted. Current server state is unavailable.
```

---

# 18. Archive Unknown Outcome

Even though backend archive is idempotent, this client must not silently replay an uncertain POST.

Unknown includes:

```text
connection interruption/error with dispatch ambiguity
timeout
Dio cancellation while operation owns publication
HTTP 5xx
unexpected HTTP status
unexpected 2xx other than 200
malformed/unexpected error envelope
unsupported status/code pairing
malformed/mismatched 200 success
response transform/parsing failure
unexpected post-dispatch exception
immutable identity mismatch
```

Flow:

1. mark Group list stale;
2. do not replay POST;
3. show reconciliation busy state;
4. issue exactly one authoritative Group Detail GET.

### Current Group archived

Replace Detail with archived authoritative Group.

Close dialog.

Show:

```text
The group is currently archived, but this archive request result could not be confirmed.
```

No confirmed success.

### Current Group active

Replace Detail with active authoritative Group.

Close dialog.

Show:

```text
The group is still active. The archive request result could not be confirmed.
```

No confirmed failure of the original request is inferred beyond current state.

### Exact 404

```text
Detail -> not_found
close dialog
```

### Session failure

```text
discard Detail/action authority
close dialog
auth/session reconciliation
```

### Other reconciliation failure

```text
discard old Group
Detail -> error
close dialog
show:
The archive result could not be confirmed. Current server state is unavailable.
```

---

# 19. Mutation `404`

An exact mutation error:

```text
HTTP 404
code = resource_not_found
exact error envelope
errors = empty
```

must:

1. mark Group list stale;
2. close stale Edit/Archive dialog;
3. call the safe Detail not-found mutation hook;
4. remove old Group from authoritative Detail state;
5. render the exact existing S04-FE-002 privacy-safe not-found UI.

Missing and foreign/scope-hidden Groups remain indistinguishable.

Malformed 404 envelope is unknown outcome and therefore reconciles; it is not direct not-found.

---

# 20. Session Authority Failures

Exact session authority failures:

```text
401 authentication_required

403 password_change_required
403 user_inactive
403 institution_inactive
```

must:

- invalidate Group action publication authority;
- close/dismiss stale action state through normal provider/session transition;
- discard protected Detail state as required by delivered Detail owner;
- use established central auth/session reconciliation;
- never restore action focus into a later session;
- never publish later mutation/reconciliation completion.

`403 forbidden` is not a session-authority failure; it uses safe definite action feedback.

---

# 21. Detail / Action Feedback and Focus

Group Detail gains an action feedback live region above/beside Detail body, following established Institution Admin action pattern.

Feedback must never display:

```text
raw backend message
raw validation strings
Dio exception text
request URL containing private ID
raw JSON
stack trace
SQL
token
institution/user private identifier
```

### Edit success

```text
focus -> Edit
only if same current active Group
```

### Archive success / archived reconciliation

```text
focus -> Group Detail heading/read-only surface
```

### Definite archive failure

```text
focus -> Archive Group
only if same Group remains confirmed active
```

### Stale/404/session/error

```text
no focus restoration to obsolete action
```

### Validation/form-only feedback

```text
first field error -> field focus
otherwise -> feedback focus/live region
```

---

# 22. Security / Tenant / Persistence / Concurrency

Eligible actor remains:

```text
authenticated
role = institution_admin
active user
must_change_password = false
active own institution
desktop surface
```

Mutation target Group UUID does not select tenant scope.

Never send:

```text
institution_id
created_by_user_id
tenant selector
status
archived_at
membership IDs
```

Backend remains authoritative for:

- tenant resolution;
- existence privacy;
- row locking;
- lifecycle state;
- timestamps;
- persistence;
- current membership counts.

Frontend persistence/schema:

```text
N/A
```

Backend concurrency behavior consumed by UI:

```text
archive wins first
    -> later update 409 business_conflict

update wins first
    -> update may succeed
    -> later archive may succeed

two archives
    -> both may return 200
    -> only first changes timestamps
```

Frontend does not implement locks and does not infer serialization order beyond returned/reconciled server state.

---

# 23. Architecture / Placement

Expected new files:

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

May modify only as narrowly required:

```text
frontend/lib/features/institution_admin/application/institution_group_list_controller.dart
frontend/lib/features/institution_admin/application/institution_group_list_state.dart
```

Use the actual delivered S04-FE-002 filenames if they differ.

If FE-002 already provides the required Group-list stale API, reuse it without changing list files unnecessarily.

Do not modify:

```text
frontend/lib/app/router/*
```

No route changes belong to FE-003.

Forbidden:

```text
backend/
docs/
unrelated tasks
unrelated features
pubspec.yaml
pubspec.lock
platform folders
```

Do not:

- call Dio from Widgets/controllers;
- parse JSON in Widgets/controllers;
- create a second Group Detail cache;
- create another Group-list retained store;
- create a separate edit route;
- create a generic action framework for User + Group;
- modify Institution Dashboard.

Any additional file requires concrete in-scope necessity and must be reported.

---

# 24. Acceptance Criteria

- [ ] S04-FE-002 is Accepted / Delivered on synchronized `origin/main` before FE-003 implementation.
- [ ] Active confirmed Group Detail exposes `Edit` and `Archive Group`.
- [ ] Archived Group is read-only with exact indication and no edit/archive/reactivate/delete.
- [ ] Edit is modal; no route changes.
- [ ] Form uses exact normalization/null/multiline/rune-length rules.
- [ ] PATCH contains only normalized changed allowed fields.
- [ ] Local no-op sends zero PATCH/GET, does not mark list stale, keeps dialog open, and clears message after edit change.
- [ ] Update accepts only exact 200 `{data,message}` with exact message and strict Group DTO.
- [ ] Direct update validates route/selected/returned ID, immutable `createdAt`, active lifecycle, and submitted fields.
- [ ] Archive sends zero body bytes and no query.
- [ ] Archive accepts only exact 200 `{data,message}` + immutable identity + archived lifecycle.
- [ ] `ApiErrorCodes.businessConflict` is added/reused exactly.
- [ ] Mutation error envelope and status/code pairs are strict.
- [ ] Mixed 422 known + protocol keys show safe field errors plus form-level protocol feedback.
- [ ] Edit `409 business_conflict` never replays PATCH and reconciles one authoritative Detail GET.
- [ ] Unknown update never replays PATCH and reconciles once.
- [ ] Archive 409/unknown never auto-replays and reconciles once.
- [ ] Reconciliation 200 replaces Detail only through selected-object/session/target ownership.
- [ ] Reconciliation 404 removes stale Group and enters existing not-found.
- [ ] Reconciliation session failure removes stale authority and reconciles auth session.
- [ ] Reconciliation other failure removes old Group and enters Detail error; stale active actions are not shown.
- [ ] Edit recoverable validation/403/429 failures preserve draft and keep dialog open.
- [ ] Archive definite 403/422/429 failure closes confirmation and shows Detail feedback.
- [ ] Detail Refresh/Edit/Archive cannot run concurrently with an open/busy Group action.
- [ ] Group list stale timing matches Section 12 and retained query is preserved.
- [ ] No optimistic list/detail authoritative patch.
- [ ] No Institution Dashboard invalidation.
- [ ] Stale completion cannot publish across selected-object/target/session/institution/device/generation/dispose changes.
- [ ] Focus restoration never targets removed/obsolete controls.
- [ ] No Teacher/Student membership or Parent relationship behavior is introduced.
- [ ] No backend/schema/dependency/route/public API change.
- [ ] Focused verification passes.
- [ ] `git diff --check` passes.
- [ ] Final diff has no unrelated changes.

---

# 25. Focused Tests and Verification

Use exact real delivered Group test filenames. If S04-FE-002 used equivalent names, substitute only those real paths and report the exact command.

## 25.1 Focused command

From repository root:

```powershell
Push-Location frontend

fvm spawn 3.44.7 test `
  test/features/institution_admin/institution_group_mutation_domain_test.dart `
  test/features/institution_admin/institution_group_mutation_dto_test.dart `
  test/features/institution_admin/institution_group_mutation_remote_data_source_test.dart `
  test/features/institution_admin/institution_group_mutation_repository_impl_test.dart `
  test/features/institution_admin/institution_group_action_controller_test.dart `
  test/features/institution_admin/institution_group_detail_controller_test.dart `
  test/features/institution_admin/institution_admin_group_detail_screen_test.dart `
  test/features/institution_admin/institution_group_list_controller_test.dart

Pop-Location
```

Required focused coverage:

### Mutation domain

- active Group form initialization;
- name 160-rune boundary/trim/required;
- level 100-rune boundary;
- subject 160-rune boundary;
- nullable empty -> null;
- spaces-only optional invalid;
- Description multiline internal newline preservation;
- changed-fields-only map;
- null clear;
- unsupported key rejection;
- local normalized no-op;
- no-op message clearing on field change;
- submitted-field matching.

### Mutation DTO/data

Update:

- canonical target guard;
- exact PATCH path;
- exact changed JSON;
- no query;
- no extra body fields;
- followRedirects safe convention;
- HTTP 200 only;
- exact `{data,message}`;
- exact update message;
- strict Group DTO;
- exact definite 401/403/404/409/422/429 envelope;
- non-422 errors require empty errors;
- malformed envelope/status-code pair -> unknown;
- 5xx/connection/timeout/cancel/unexpected 2xx -> unknown.

Archive:

- canonical target guard;
- exact POST path;
- no query;
- no `data` argument / zero request-body bytes;
- HTTP 200 only;
- exact `{data,message}`;
- exact archive message;
- exact definite error classification;
- malformed/unexpected result -> unknown.

### Repository

Update direct success requires:

```text
route == selected ID == returned ID
selected.createdAt == returned.createdAt
active + archivedAt null
submitted fields match
```

Archive direct success requires:

```text
route == selected ID == returned ID
selected.createdAt == returned.createdAt
archived + archivedAt non-null
```

Test immutable identity mismatch -> unknown.

Do not compare untouched mutable fields/counts/updatedAt to pre-mutation snapshot.

### Action controller / Detail integration

- action starts only from exact active confirmed selected Group;
- archived Group cannot begin action;
- one action only;
- Detail Refresh disabled while action open/busy;
- local validation/no-op;
- recoverable edit failures keep draft/dialog state;
- archive definite failure settles/feedback correctly;
- direct update/archive success;
- exact list stale timing;
- 409 update archived/active/404/session/error reconciliation;
- unknown update field-match/differ/archived/404/session/error;
- archive 409 current archived/active/error;
- unknown archive archived/active/404/session/error;
- reconciliation failure discards old Detail Group;
- no mutation replay;
- selected-object replacement invalidates stale action;
- session/target/institution/device/generation/dispose rejection;
- focus-key current/obsolete behavior.

### Widget

- active Edit/Archive;
- archived read-only message;
- Edit dialog field initialization;
- Description Enter/newline;
- validation/no-op focus/live region;
- busy dismissal protection;
- Archive confirmation exact content/actions;
- action feedback;
- 409/unknown checking state visibly non-authoritative;
- actions disabled while action pending;
- dialogs close on terminal/stale transitions;
- correct focus after edit/archive/failure;
- no obsolete focus after archive/not-found/session/error;
- text scale/narrow desktop/long content no overflow.

## 25.2 Directly affected regression

The focused command above must include the delivered FE-002/FE-001 files actually changed by FE-003.

At minimum verify:

```text
S04-FE-002 Group Detail:
initial/load/data/refresh/error/not-found unchanged
target/session stale safety unchanged

S04-FE-001/002 Group list:
retained query preserved
stale marker consumed
authoritative reload on next presentation
no optimistic row/status/order/count mutation

S04-FE-002 Create:
create -> authoritative Detail navigation remains compatible
```

If FE-003 does not modify Create code, do not add the entire create suite merely for breadth.

No Institution User regression is required because User code must not be changed.

## 25.3 Static analysis

```powershell
Push-Location frontend
fvm spawn 3.44.7 analyze
Pop-Location
```

## 25.4 Format check

```powershell
Push-Location frontend

C:\Users\Administrator\fvm\versions\3.44.7\bin\cache\dart-sdk\bin\dart.exe `
  format --output=none --set-exit-if-changed lib test

Pop-Location
```

## 25.5 Manual check

```text
Not required — deterministic domain/data/repository/controller/widget tests cover
this task. Real-stack/Windows E2E belongs to Stage 4 integration/checkpoint workflow.
```

## 25.6 Always

From repository root:

```powershell
git diff --check
```

Then inspect the complete diff for:

- exact FE-003 scope;
- no route change;
- no dashboard change;
- no backend/package/platform/task bookkeeping change;
- strict error envelope;
- `business_conflict` only as stable machine code;
- zero-body archive request;
- no automatic mutation replay;
- no optimistic authoritative Group state;
- reconciliation failure cannot leave stale active Detail/actions;
- list retained query not corrupted;
- no raw backend/error/private data in UI/logs;
- no unrelated refactor/format churn;
- no weakened tests/debug/temp artifacts.

Do **not** run:

```text
full frontend suite
Windows build
broad E2E
Frontend Phase 2
Stage integration
```

for this task.

If implementation necessarily requires unapproved shared scope with material regression risk outside this contract, return `BLOCKED` instead of silently broadening work.

---

# 26. Delivery

Mode:

```text
Implementation + GitHub delivery
```

Branch:

```text
task/s04-fe-003-group-edit-archive
```

Commit:

```text
feat(frontend): add group edit and archive
```

PR:

```text
focused PR to main
```

Task/Stage bookkeeping changes:

```text
None
```

After merge require:

```text
implementation present on origin/main
local main == origin/main
ahead/behind = 0/0
working tree clean
```

If implementation and verification pass but safe delivery cannot complete:

```text
DELIVERY BLOCKED
```

---

# 27. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to rediscover requirements.

| Source/reference | Decision already encoded above |
|---|---|
| Current `InstitutionGroupUpdateRequest` | Exact PATCH keys, partial object, no query, normalization/null/max rules, no empty accepted request |
| Current `UpdateInstitutionGroup` | Tenant-scoped row lock, archived precedence, dirty/no-op semantics, fresh resource |
| Current `InstitutionGroupArchiveRequest` | Archive endpoint request shape; frontend deliberately chooses zero body bytes |
| Current `ArchiveInstitutionGroup` | Idempotent archive, server timestamps, row locking |
| Current `InstitutionGroupLifecycleApiTest` | Archive idempotency, timestamp preservation, race serialization, body/query constraints |
| Current `ApiErrorResponse` | `business_conflict` centralized 409 contract |
| Delivered S04-FE-001 | Strict Group/list/query/session ownership |
| Approved/delivered S04-FE-002 | Detail owner, stale Group-list owner, route/create/detail boundaries |
| Current Institution User mutation/action implementation | Strict mutation envelope, selected-object ownership, reconciliation, stale list/focus pattern |
| `frontend/AGENTS.md` | DTO strictness, mutation uncertainty, no stale authoritative state, cache/invalidation, accessibility |

---

# 28. Codex Final Report

Return concise evidence:

1. **Status:** `ACCEPTED`, `BLOCKED`, or `DELIVERY BLOCKED`.
2. Implementation summary.
3. Changed files and purpose.
4. Acceptance-criteria evidence.
5. Exact focused verification commands/results.
6. Edit normalization/no-op/partial PATCH evidence.
7. Archive zero-body/idempotent-response evidence.
8. Exact mutation error-envelope + `business_conflict` evidence.
9. Immutable Group identity validation evidence.
10. 409 and unknown update reconciliation evidence.
11. Archive 409/unknown reconciliation evidence.
12. Reconciliation failure -> no stale authoritative Detail evidence.
13. Dialog/focus/action transition evidence.
14. Group-list stale/retained-query/no-dashboard evidence.
15. Session/tenant/selected-object/stale-async evidence.
16. `git diff --check` + focused diff/scope self-review.
17. Commit/PR/merge/main-sync evidence.
18. Exact deviations/blockers.

If a required product, architecture, API, security, tenant, lifecycle, concurrency, mutation-outcome, async-ownership, dialog/focus, or UX decision is missing or conflicts with the delivered S04-FE-002 implementation/current source:

```text
BLOCKED
```

Do not invent behavior.
