# Codex Task: Institution User Edit and Lifecycle UI

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-FE-007` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Frontend` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Contract corrections reviewed | `2026-08-14` |
| Direct dependencies | `S03-FE-006`, `S03-BE-005` |
| Directly blocks | `S03-FE-008`, `S03-INT-002` |
| Transitively blocks | `S03-FE-009` and Stage 3 closure |

This detailed task and its paired execution prompt may be prepared before the
frontend dependency is delivered. Preparation is not implementation.

At contract-review time, current authoritative `origin/main` is:

```text
33deb34cf45578ee0ac351e6cf6ef6e06c5acd4e
```

On that revision, `S03-BE-005` is `Accepted / PASS / Delivered`, while
`S03-FE-006` and its frontend predecessors are not yet delivered. Phase 0 must
re-check the then-current repository truth. Production implementation is
blocked until both direct dependencies are independently
`Accepted / PASS / Delivered` on current `origin/main`.

`S03-FE-005` is a transitive predecessor through `S03-FE-006`; it is not a
third direct dependency.

## 2. Goal

Extend the delivered Institution Admin User detail screen with safe profile
editing and explicit account activation/deactivation for own-Institution
Teachers, Students, and Parents through exactly:

```text
PATCH /api/v1/institution/users/{user}
POST  /api/v1/institution/users/{user}/activate
POST  /api/v1/institution/users/{user}/deactivate
```

The accepted result must:

- edit only `full_name`, `email`, and `phone`;
- send only effective changes and no PATCH for a no-change form;
- require an explicit confirmation for Activate or Deactivate;
- send no lifecycle request body, query, tenant selector, or idempotency key;
- accept only an exact backend-confirmed `200` success response as proof that
  the mutation request succeeded;
- never optimistically change User state or automatically replay a mutation;
- use at most one read-only detail GET after an unprovable outcome;
- describe that GET only as current-state verification, never as proof that
  this client request caused the state;
- keep detail, retained User-list query, Dashboard counts, route target, and
  session state safe across failures, logout, account switch, target change,
  route exit, disposal, and late completions;
- preserve every backend-authoritative tenant, role, lifecycle, token,
  first-login, relationship, and history rule.

Laravel remains authoritative for authorization, target scope, validation,
normalization at persistence, no-op behavior, row locking, timestamps, stored
tokens, login/access enforcement, and history preservation. Flutter submits
one explicit intent and displays returned server facts.

## 3. Current Context and Compatibility Requirements

### 3.1 Accepted backend authority

Accepted `S03-BE-005` provides the three endpoints above and guarantees:

- middleware order:

  ```text
  auth:sanctum
  → active.account
  → password.changed
  → role:institution_admin
  ```

- target scope is the authenticated actor's Institution plus exact roles
  `teacher|student|parent`;
- malformed, unknown, foreign-Institution, Platform Owner, and Institution
  Admin target IDs share scope-safe `404 resource_not_found` behavior;
- PATCH accepts a non-empty JSON object containing only `full_name`, `email`,
  and/or `phone`;
- an exact PATCH no-op performs no User update and preserves `updated_at`;
- lifecycle accepts no body or `{}` and no query, and is idempotent by target
  state;
- update, activate, and deactivate serialize on a fresh scoped PostgreSQL row
  lock;
- stored Sanctum token rows are never changed by lifecycle;
- deactivation blocks login and protected token access through accepted account
  enforcement;
- reactivation creates/restores no token and does not clear
  `must_change_password` or change `last_login_at`;
- successful responses use the unchanged shared 12-field User resource and an
  exact endpoint-specific message.

This frontend task must not reinterpret or duplicate those rules.

### 3.2 Delivered frontend owners

Phase 0 must resolve and reuse the actual delivered paths. The ownership chain
is:

- `S03-FE-001`: Institution Admin desktop shell, canonical User route grammar,
  route helpers, direct-entry guard, and `/users/new` precedence;
- `S03-FE-002`: Dashboard data provider/controller and its three role totals,
  each including active and inactive Users;
- `S03-FE-004`: exact shared Institution User model/parser, list repository,
  retained same-session query, server pagination, stale/refetch hook, and Users
  navigation;
- `S03-FE-005`: real User detail GET, target-scoped controller/state,
  not-found presentation, refresh behavior, and detail screen;
- `S03-FE-006`: create-screen replacement, confirmed-detail navigation, and
  the final delivered list stale hook plus create-specific Dashboard
  invalidation hook.

Do not create a second User model/parser, second API client, second route
family, global selected User, parallel list cache, or alternate session
authority.

### 3.3 Route compatibility

The only approved detail route remains:

```text
/institution-admin/users/:userId
```

The exact target is the already-decoded, FE001-validated canonical UUID-shaped
path parameter owned by FE005. Preserve all FE001/FE005 route behavior:

- `/institution-admin/users/new` remains create and never becomes a detail
  target;
- malformed, noncanonical, encoded-separator, whitespace, empty, extra-path,
  or non-UUID-shaped locations use the accepted FE001 safe fallback;
- such invalid frontend locations build no detail screen and issue no detail or
  mutation request;
- an FE001-valid UUID reaches the backend; unknown, foreign, or disallowed-role
  targets then receive the uniform backend `404 resource_not_found` behavior;
- no route name, path, helper, ordering, grammar, or shell topology changes are
  allowed in this task.

## 4. Included Scope

- Extend the delivered Institution User repository/data source with exact
  update, activate, and deactivate methods.
- Reuse the exact FE004 shared User parser/model for every mutation response
  and reconciliation GET.
- Add focused edit/lifecycle request/value types and a mutation controller/state
  separate from the FE005 read controller where responsibility requires it.
- Add Edit and exactly one state-appropriate lifecycle action to confirmed
  User detail data.
- Add an accessible three-field edit dialog and accessible lifecycle
  confirmation dialog.
- Implement exact request, success, validation, auth, scoped not-found,
  rate-limit, definite-failure, unprovable-outcome, current-state verification,
  cache-stale, and session/target generation behavior.
- Add focused domain, data, application, widget, accessibility, router
  regression, and predecessor regression tests.
- Perform only the approved Phase 0–3 task/index/README bookkeeping.

No backend, schema, locked docs, route topology, shell redesign, package,
password reset, relationship, Group, settings, category, or learning behavior
belongs to this task.

## 5. Exact Eligibility, Target, and Action Ownership

### 5.1 Session eligibility

No edit/lifecycle control or product request is allowed unless current frontend
session state is all of:

```text
authenticated
role = institution_admin
must_change_password = false
session User is active according to accepted bootstrap state
session Institution is active according to accepted bootstrap state
non-null session Institution ID
Institution Admin desktop route is eligible
FE005 detail state contains confirmed data for the exact current route UUID
```

Backend still re-authorizes every request. Route/UI visibility is not security
authority.

### 5.2 Immutable action key

Bind each dialog, request, reconciliation, completion, invalidation, and
feedback event to an immutable key containing at least:

```text
session user id
session User object instance identity
session Institution id
exact decoded route target UUID
selected confirmed User id
mutation kind: edit|activate|deactivate
operation generation
controller not disposed
```

For edit, also snapshot the exact confirmed starting User and normalized
changed-field request. For lifecycle, snapshot the selected User and desired
final active state.

Only the latest operation matching every value may publish state, replace
detail data, mark current-session providers stale, navigate, close a current
dialog, restore focus, or show feedback.

Target identity may come only from the current FE005 confirmed detail resource
whose `id` represents the same UUID as the route target. Follow FE005 equality:
case differences in an otherwise identical canonical UUID are allowed; a
different UUID is rejected. Never take identity from typed text, a list index,
display name, login name, stale global selection, create form, another target,
or an Institution selector.

### 5.3 Action visibility

Confirmed detail data for an eligible Teacher, Student, or Parent shows:

```text
Edit
Deactivate  when is_active = true
Activate    when is_active = false
```

No action appears from initial loading, retryable error, non-retryable error,
not found, invalid-response, stale refresh, invalid route, ineligible session,
or prior-target data.

One edit/lifecycle mutation or its bounded reconciliation owns the detail
screen at a time. While busy, disable every conflicting Edit, Activate,
Deactivate, confirmation, and duplicate-submit intent.

## 6. Exact Shared User Resource and Envelope

Reuse the delivered FE004 parser/model unchanged unless its accepted contract
itself is missing, in which case stop instead of adding a looser parallel
parser.

The resource contains exactly these 12 keys; JSON key order is irrelevant:

```text
id
role
full_name
login_name
email
phone
is_active
must_change_password
last_login_at
deactivated_at
created_at
updated_at
```

Required invariants include:

- canonical valid UUID `id`;
- `role` exactly `teacher|student|parent`;
- non-empty correctly typed `full_name` and `login_name`;
- nullable correctly typed `email`, `phone`, `last_login_at`, and
  `deactivated_at`;
- booleans for `is_active` and `must_change_password`;
- accepted UTC timestamp format for non-null timestamps;
- active means `deactivated_at = null`;
- inactive means `deactivated_at` is non-null;
- no missing, extra, renamed, protected, or unknown resource key.

Never accept, model, render, retain, or log:

```text
institution_id
created_by_user_id
creator
password or password hash
remember token
Sanctum tokens
permissions or abilities
Institution settings
relationships or Groups
learning records, answers, scores, or results
```

Every mutation success must also require `data.id` to represent the same UUID
as both the immutable selected User ID and current route target, allowing only
case differences exactly as FE005 does. A different response target is an
unprovable mutation outcome, never success.

Also require immutable target identity facts `role`, `login_name`, and
`created_at` to equal the selected confirmed snapshot. Do not require other
non-submitted profile/lifecycle/first-login/login-time fields to equal the old
snapshot because a legitimate concurrent server operation may have changed
them before this transaction; validate their types and invariants instead.

## 7. Exact Edit Dialog and Form Contract

### 7.1 Dialog contents

Open `Edit user` only from current confirmed detail data.

Show exactly these editable fields in this order:

```text
Full name *
Email
Phone
```

The already-visible detail may continue to show Role, login name, account
status, and first-login state as read-only information. Do not make them form
controls and do not include them in the request.

Never expose an editable control for:

```text
id
institution_id
role
login_name
password or password confirmation
is_active
must_change_password
last_login_at
deactivated_at
created_by_user_id or creator
created_at or updated_at
token/session/permission data
relationships or Groups
learning data
```

### 7.2 Normalization and local validation

Length checks use Dart Unicode scalar values (`String.runes.length`), not
UTF-8 bytes or UTF-16 code units.

Apply exactly:

```text
full_name:
  trim leading/trailing whitespace before comparison and request
  required non-empty after trim
  maximum 200 Unicode scalar values after trim

email:
  optional/nullable
  exact empty control means intentional null when the initial value was non-null
  exact empty control with initial null is unchanged and omitted
  a non-empty value is not silently trimmed or rewritten
  leading/trailing or internal whitespace is locally invalid
  permissive one-@ shape for early UX validation
  maximum 254 Unicode scalar values
  backend email validation remains authoritative

phone:
  optional/nullable
  exact empty control means intentional null when the initial value was non-null
  exact empty control with initial null is unchanged and omitted
  non-empty value is trimmed before comparison and request
  whitespace-only non-empty input is locally invalid, not converted to null
  maximum 50 Unicode scalar values after trim
```

Use safe local feedback:

```text
Full name empty: Full name is required.
Full name long: Full name must be 200 characters or fewer.
Email invalid: Enter a valid email address.
Email long: Email must be 254 characters or fewer.
Phone whitespace: Phone must not contain only spaces.
Phone long: Phone must be 50 characters or fewer.
```

Local validation is early UX only. It does not determine tenant, role,
authorization, concurrency, or backend acceptance.

### 7.3 Changed-field mapping

Compare normalized draft values with the immutable initial confirmed resource.
Build a non-empty JSON object containing only effective changes:

```json
{
  "full_name": "Updated Name"
}
```

or:

```json
{
  "email": null,
  "phone": "+998901234567"
}
```

Rules:

- omitted field preserves server state;
- explicit `null` clears email/phone;
- never send `{}`;
- never send unchanged fields;
- never send a protected/unknown key;
- no effective change sends no PATCH, keeps the dialog open, shows
  `No user changes to save.`, and focuses/announces the form-level feedback;
- Cancel, close, or Escape before submission sends no request, clears local
  form/errors/action ownership, closes the dialog, and restores focus to Edit;
- while a PATCH or reconciliation is in progress, prevent duplicate submit and
  normal dialog dismissal; unavoidable system route exit disposes ownership and
  makes every completion stale.

## 8. Exact PATCH Request and Direct Success

### 8.1 Request

Use the configured authenticated Dio/repository path only:

```text
Method: PATCH
Path: /api/v1/institution/users/{exact-current-user-uuid}
Content type: application/json
Query parameters: none
Body: one non-empty changed-fields JSON object
Institution selector/header: none
Idempotency-Key: none
Automatic retry/replay: none
```

Encode the UUID as one path segment through the delivered endpoint/path
convention. Presentation widgets must not call Dio or construct raw URLs.

One explicit valid submit produces at most one PATCH. Click, Enter, keyboard
activation, double-click, rebuild, callback, timer, refresh, error handler, and
reconciliation must never produce a second PATCH.

### 8.2 Exact direct success

Confirmed edit-request success requires exact HTTP `200 OK` and exactly these
top-level keys:

```json
{
  "data": {
    "id": "user-uuid",
    "role": "teacher",
    "full_name": "Updated Name",
    "login_name": "teacher01",
    "email": null,
    "phone": "+998901234567",
    "is_active": true,
    "must_change_password": true,
    "last_login_at": null,
    "deactivated_at": null,
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-14T08:00:00Z"
  },
  "message": "Institution user updated successfully."
}
```

Require:

- status exactly 200;
- top-level key set exactly `data + message`;
- message exactly `Institution user updated successfully.`;
- the exact shared 12-field resource and no extra/protected key;
- response target represents the same UUID as route/selected target under
  FE005 case-equivalence rules;
- immutable `role`, `login_name`, and `created_at` match the selected snapshot;
- every submitted changed field equals the normalized intended value;
- returned lifecycle pair is internally valid.

Do not use the human-readable message as business authority; exact comparison
is transport-contract validation only.

Any unexpected success status, missing/extra/wrong top-level key, wrong
message, malformed resource, target mismatch, changed-field mismatch, or
invalid lifecycle pair is not confirmed success. Because the PATCH may already
have committed, classify it as an unprovable outcome and follow Section 10.

### 8.3 Confirmed edit-success sequence

Only after exact direct success and current operation/session/target ownership:

1. replace the current FE005 detail resource with the exact returned resource
   through a narrow controller/application hook;
2. mark FE004 Users data stale while preserving its same-session committed
   query, search draft, filters, sorting, page size, and return behavior;
3. do not invalidate FE002 Dashboard because profile-only fields do not change
   its totals;
4. close and clear the edit dialog/action state;
5. show/announce only `User updated successfully.`;
6. restore focus to the current detail action area;
7. allow FE004 to perform its normal authoritative reload and empty-page
   correction when Users is next visible.

Never patch a list row, filter result, sort order, pagination total, or
Dashboard count optimistically.

## 9. Exact Lifecycle Contract

### 9.1 Confirmation

Lifecycle is separate from the edit form.

For an active User, `Deactivate user` confirmation must identify the selected
name/login context and clearly state:

- normal login and protected access will be blocked by account state;
- credentials, Institution binding, relationships, and history are not
  deleted;
- the action does not deactivate the Institution or another User.

For an inactive User, `Activate user` confirmation must identify the selected
name/login context and clearly state:

- activation changes only account active state;
- it does not reset/change a password, clear first-login requirements, create a
  session/token, change role, or bypass an inactive Institution;
- normal sign-in, first-login, Institution, and authorization requirements
  continue to apply.

Rules:

- require one explicit confirmation gesture;
- Cancel/close/Escape before confirmation sends no POST, clears selection, and
  restores focus to the lifecycle action;
- include no reason, status selector, `is_active`, target ID, Institution,
  role, password, first-login field, force flag, timestamp, ETag, or version;
- do not infer success from button click, request start, or HTTP status alone.

### 9.2 Exact request representation

Choose and lock the body-less representation for this task:

```text
Method: POST
Path: /api/v1/institution/users/{exact-current-user-uuid}/activate
  or  /api/v1/institution/users/{exact-current-user-uuid}/deactivate
Query parameters: none
Request body: zero bytes; do not pass data, {}, JSON null, or form data
Institution selector/header: none
Idempotency-Key: none
Automatic retry/replay: none
```

The backend also accepts `{}`, but this frontend task deliberately standardizes
on zero request-body bytes. Tests must prove the data source did not pass a
`data` argument.

One confirm gesture produces at most one state-appropriate POST. Backend
lifecycle idempotency is not permission for Flutter to retry automatically.

### 9.3 Exact direct success

Confirmed lifecycle-request success requires exact HTTP `200 OK`, exactly
`data + message`, the exact shared User resource, exact matching target, and:

```text
activate:
  message = Institution user activated successfully.
  data.is_active = true
  data.deactivated_at = null

deactivate:
  message = Institution user deactivated successfully.
  data.is_active = false
  data.deactivated_at = non-null valid UTC timestamp
```

Immutable `role`, `login_name`, and `created_at` must also match the selected
snapshot. Other valid current resource fields may reflect serialized concurrent
server activity and must not be overwritten from the old snapshot.

The response may represent either a real backend transition or an idempotent
no-op caused by fresh concurrent server state. Flutter displays the returned
state and never invents transition/timestamp/token behavior.

An unexpected 2xx/redirect/non-contract status, or a malformed/mismatched
success envelope, message, target, resource, or desired state, is unprovable,
not success. Exact accepted 4xx errors follow Section 11 instead.

### 9.4 Confirmed lifecycle-success sequence

Only after exact direct success and current ownership:

1. replace current FE005 detail with the exact returned resource;
2. mark FE004 Users stale without changing/losing its retained query;
3. leave FE002 Dashboard untouched because activation/deactivation changes no
   Teacher, Student, or Parent total; each total already includes active and
   inactive Users;
4. close/clear confirmation and action state;
5. show/announce the safe state-specific result:

   ```text
   User activated successfully.
   User deactivated successfully.
   ```

6. restore focus to the current detail action area.

Do not optimistically change a row, status, `deactivated_at`, count, filter,
page, or any token/access state.

## 10. Mutation Outcome Classification and Read-Only Verification

### 10.1 Only direct exact response confirms request success

The UI may say the mutation request succeeded only when the original PATCH/POST
returns the exact accepted `200` response defined above.

A later GET cannot prove that this client's mutation caused the observed state:
another authorized administrator or concurrent request could have produced the
same fields/state. Therefore reconciliation may confirm current server facts,
but it must never convert an unprovable mutation into `success`.

### 10.2 Definite pre-action or server rejection

Treat only an exact accepted error response whose semantics prove rejection as
definite failure:

- local validation/no-change/cancel before request: no mutation was sent;
- exact `401 authentication_required`;
- exact actor lifecycle/first-login/permission `403` codes;
- exact `404 resource_not_found`;
- exact `422 validation_failed`;
- exact `429 rate_limited`;
- a future exact documented `409` rejection may be handled safely, but BE005
  currently defines no normal 409 business conflict for these endpoints.

Never branch on human-readable error messages.

### 10.3 Unprovable outcome

After a valid PATCH/POST begins, classify the result as unprovable when exact
accepted success or definite rejection is unavailable, including:

- connection/send/receive/transform timeout;
- connection loss, unknown transport error, or cancellation whose pre-send
  status cannot be proven;
- `500 server_error` or another 5xx, because persistence may have committed
  before response generation failed;
- unexpected 2xx, redirect/non-contract status, or malformed HTTP result after
  the mutation may have reached the server;
- exact 200 with malformed/extra/mismatched envelope, message, resource,
  target, submitted fields, or lifecycle state.

Show neutral feedback such as:

```text
The request result could not be confirmed. Checking the current server state…
```

Never claim that the server did or did not apply the mutation, never replay the
PATCH/POST, and never expose a mutation Retry button.

### 10.4 At most one reconciliation GET

While the same eligible session/target/operation remains current, issue at most
one read-only request through the delivered FE005 detail repository:

```text
Method: GET
Path: /api/v1/institution/users/{same-user-uuid}
Query parameters: none
Request body: zero bytes
Institution selector/header: none
```

This GET:

- reuses the configured client, exact FE005 endpoint, strict envelope, shared
  parser, target equality, scope-safe error mapping, and session guards;
- is part of the mutation controller's bounded verification and must not trigger
  FE005 automatic Retry, polling, or a second GET;
- never triggers a PATCH/POST;
- does not change FE004 visible/retained query;
- remains stale after target/session/route/generation change.

If exact current detail is returned:

- publish it as the current FE005 server resource only when ownership still
  matches;
- for edit, compare the submitted changed fields with current server values;
- for lifecycle, compare current `is_active/deactivated_at` with desired state;
- if they match, say only:

  ```text
  Current server state matches your requested values, but this request result
  could not be confirmed.
  ```

- if they differ, display a neutral summary of current state without exposing
  raw payloads and say the request result remains unconfirmed;
- in both cases, do not enter success state, do not show success wording, and do
  not attribute the state to this mutation.

If the GET returns exact `404 resource_not_found`, transition the current FE005
detail to its existing privacy-safe not-found state. If it fails, is malformed,
or becomes stale, clear busy ownership and retain only safe unresolved feedback.

A later user-initiated FE005 Refresh is a separate read intent. A later mutation
requires reopening the edit/confirmation flow from current confirmed detail;
it is never an automatic retry of the prior action.

### 10.5 Cache safety starts when mutation starts

As soon as a locally valid mutation begins:

- mark FE004 Users stale while preserving retained query state;
- leave FE002 Dashboard untouched for edit, activate, and deactivate;
- do not optimistically change visible data;
- ensure the stale marker survives route disposal so the next eligible view
  reloads authoritative data even if the response was lost or ignored.

The early Users stale marking is required because the mutation may commit after
the screen exits or before an unprovable response. The Dashboard's role totals
include active and inactive Users, so lifecycle changes no Dashboard value and
must issue no invalidation or automatic Dashboard request.

## 11. Exact Error, Auth, and Not-Found Behavior

Use stable status/code pairs and the accepted centralized session/failure
infrastructure.

### 11.1 Authentication and actor state

- exact `401 authentication_required`: bootstrap/invalidate global session,
  clear protected User/action/detail state, and route through accepted auth;
- `user_inactive`, `institution_inactive`, and
  `password_change_required`: clear protected state and use accepted global
  bootstrap/route reconciliation;
- exact `403 forbidden`: safe permission feedback, no target/scope disclosure;
- a stale auth completion cannot affect a newer session.

### 11.2 Target not found

Only exact HTTP 404 plus `resource_not_found` becomes target not found.

For the current target:

1. close/clear action state;
2. clear stale detail data;
3. enter the existing FE005 scope-safe not-found presentation;
4. offer the existing canonical `Back to Users` action;
5. mark Users stale while preserving same-session query;
6. never reveal malformed/unknown/foreign/disallowed-role distinctions, raw
   UUID, backend message, Institution, or role.

Do not automatically redirect to an invented route and do not change FE001
malformed-location fallback.

### 11.3 Validation

For exact PATCH `422 validation_failed`, map only these keys to safe local field
errors:

```text
full_name
email
phone
```

Unknown, protected, body, query, missing-field, or malformed validation entries
become safe form-level protocol feedback. Keep non-secret draft values and
focus/announce the first approved invalid field.

Lifecycle `422` has no field form. Close busy state and show a safe command-
contract failure; do not create fields or retry.

### 11.4 Other failures

- exact `429 rate_limited`: definite safe failure, no countdown or auto-retry;
- exact valid 4xx not otherwise mapped: safe non-success without invented
  business meaning;
- 5xx/transport/malformed success: Section 10 unprovable path;
- never render/log raw server messages, validation payloads, response bodies,
  URLs, UUIDs, contacts, Institution IDs, SQL, stack traces, tokens, or
  protected fields.

## 12. Controller, Detail, List, Dashboard, and Stale-State Rules

Required state families include at least:

```text
idle
editing
lifecycle_confirming
submitting
reconciling_current_state
validation_failure
definite_failure
unconfirmed_current_state
confirmed_direct_success
target_not_found
```

Names may follow the delivered feature convention, but meanings must remain
separate. In particular, `unconfirmed_current_state` is never success.

Required behavior:

- opening a dialog snapshots only current confirmed FE005 data;
- FE005 Refresh/target replacement that changes the owned resource closes a
  pending non-submitted dialog or makes its operation stale; it cannot silently
  retarget the form;
- route target A → B immediately clears A dialog, resource/action authority,
  errors, current-state result, and generation before B can act;
- logout, auth bootstrap, same-role account switch, cross-role switch,
  Institution change, password-change requirement, route exit, or disposal
  clears state and invalidates generation;
- stale PATCH/POST/GET success, 401, 404, 422, error, invalid response, or
  feedback cannot publish into the new target/session;
- an identical current mutation already in flight is deduplicated;
- no action state/resource is retained across route disposal as authority;
- FE004 list stale/refetch preserves its accepted same-session query and owns
  empty-page correction;
- FE002 Dashboard remains untouched for edit, activate, and deactivate;
- direct success may replace FE005 detail from the exact response;
- reconciliation may replace FE005 detail only as current read-only server
  state and never as mutation success;
- no background polling, timer, mutation queue, offline write, or hidden retry.

## 13. Exact Presentation and Accessibility

Institution Admin remains desktop-only for MVP. Preserve the delivered shell,
selected Users navigation, page title, Back to Users behavior, and current
detail responsive layout.

Required UI behavior:

- wide layout and compact desktop/card layout both expose the same safe actions;
- do not rely on row position or color for identity/state;
- labels and confirmation copy identify the selected visible User without
  placing private values into logs/semantics diagnostics;
- every action works by pointer and keyboard;
- visible focus order is predictable;
- Escape/cancel works only before submission/reconciliation as defined above;
- submitting/reconciling state has progress semantics/live announcement and no
  duplicate interactive action;
- field and form errors are programmatically associated and announced;
- status meaning does not rely on color alone;
- long names/login/contact values, `800 × 600`, `1440 × 900`, and text scale
  `2.0` scroll without clipping, overflow, or keyboard trap;
- focus returns to the initiating action when it still exists, otherwise to a
  safe current detail heading/action region;
- raw UUID/error data is not announced.

## 14. Architecture and Exact Change Boundary

Use the delivered feature-first path:

```text
detail screen/dialog
→ focused mutation controller/notifier
→ Institution User repository
→ Institution User remote data source
→ configured authenticated Dio client
```

Widgets must not call Dio, parse JSON, choose tenant scope, or own mutation
reconciliation.

Phase 0 must resolve actual delivered filenames. Expected responsibilities are:

```text
frontend/lib/features/institution_admin/domain/
  delivered Institution User model/repository contracts
  narrow edit request/form value and lifecycle action types

frontend/lib/features/institution_admin/data/
  delivered shared User DTO/parser
  Institution User remote data source/repository implementation
  exact mutation response DTO if the delivered structure uses one

frontend/lib/features/institution_admin/application/
  focused User action controller/state
  narrow FE005 detail replacement/not-found hook
  reuse FE004 list-stale hook; do not call FE002 Dashboard invalidation

frontend/lib/features/institution_admin/presentation/
  delivered User detail screen
  focused edit and lifecycle dialogs/widgets as needed

frontend/test/features/institution_admin/
  focused form/domain/data/controller/widget/accessibility tests
  minimally affected FE002/FE004/FE005/FE006 regression tests

frontend/test/app/router/
  run all; modify only if an existing FE005 action assertion must be updated,
  never to change route behavior
```

Exact new filenames must follow delivered naming and responsibility. Do not
create every illustrative file automatically. Do not place unrelated concerns
in one giant screen/controller/repository file.

Allowed application changes are limited to the delivered Institution Admin
User feature and the narrow FE002/FE004/FE005 hooks already required by this
contract. If those predecessor hooks are missing or incompatible in a way that
requires core/router/shell redesign, stop and report the predecessor conflict.

Inspect but preserve unchanged unless the task's narrow responsibility
explicitly requires otherwise:

```text
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
frontend/lib/core/network/**
frontend/lib/features/auth/**
frontend/lib/features/platform_admin/**
frontend/pubspec.yaml
frontend/pubspec.lock
backend/**
docs/01–09
docker/**
```

No package, API client, interceptor, endpoint registry rewrite, token store,
logger, global cache/event bus, CRUD framework, command bus, offline queue, or
new route is allowed.

## 15. Authoritative References

Read only the relevant sections, but read each selected authority completely:

1. root `AGENTS.md`;
2. `frontend/AGENTS.md`;
3. this detailed task and paired prompt;
4. `tasks/README.md`;
5. `tasks/STAGE_03_TASK_INDEX.md`;
6. accepted `S03-INT-001` contract/control task;
7. accepted `S03-BE-003`, `S03-BE-004`, and `S03-BE-005` tasks,
   implementation, tests, review, and delivery evidence;
8. delivered `S03-FE-001`, `S03-FE-002`, `S03-FE-004`, `S03-FE-005`, and
   `S03-FE-006` task/code/test evidence;
9. docs 02–04: Institution Admin own-Institution User management and desktop
   flows;
10. docs 05: tenant, lifecycle, access, and history preservation;
11. docs 06: Stage 3 account scope and exclusions;
12. docs 07: Flutter layers, session isolation, mutation safety, API client,
    accessibility, and testing;
13. docs 08: exact User fields/nullability/timestamps;
14. docs 09 Sections 1–8 and errors: exact resource, PATCH, lifecycle, and
    envelope contracts;
15. accepted Stage 2 Platform Admin mutation code/tests only as a structural
    reference, not as authority for target routes/resources or the corrected
    unprovable-outcome wording.

Authority order remains locked docs/accepted backend and predecessor contracts
over implementation convenience. Stop on a material conflict; do not silently
invent behavior.

## 16. Acceptance Criteria

- [ ] Phase 0 proves both direct dependencies, FE006 and BE005, are independently
      `Accepted / PASS / Delivered` on current `origin/main`.
- [ ] FE005's current canonical route UUID and confirmed resource are the only
      target authority; invalid frontend routes issue no product request.
- [ ] Controls exist only for an eligible current Institution Admin session and
      current confirmed Teacher/Student/Parent detail.
- [ ] Edit exposes only full_name/email/phone with exact normalization, rune
      limits, validation, null clearing, and changed-field mapping.
- [ ] Cancel/Escape/no-change sends no PATCH; one valid intent sends one PATCH.
- [ ] PATCH path/content type/body/no-query/no-tenant/no-protected/no-
      Idempotency-Key behavior is exact.
- [ ] Active shows Deactivate; inactive shows Activate; confirmation copy and
      cancel behavior are exact.
- [ ] Lifecycle sends exactly one state-appropriate zero-body POST with no
      query/data/idempotency key.
- [ ] Direct success requires exact 200, exact `data + message`, exact message,
      shared strict 12-field resource, matching target, and intended result.
- [ ] Exact direct success updates current detail from returned resource, marks
      Users stale, and leaves Dashboard untouched for every action.
- [ ] No optimistic detail/list/count/status/timestamp/token update exists.
- [ ] No automatic mutation retry/replay exists anywhere.
- [ ] 5xx, transport uncertainty, and malformed/mismatched success remain
      unprovable and issue at most one exact detail GET.
- [ ] Reconciliation GET may publish current server state but can never claim
      that this mutation succeeded or caused the state.
- [ ] Users is marked stale at every valid mutation start, including route exit
      or lost completion; Dashboard is never invalidated by edit, activate, or
      deactivate.
- [ ] Exact 401/actor-state/403/404/422/429 behavior is code-based and safe.
- [ ] Exact target 404 enters FE005 privacy-safe not-found behavior without
      route/scope disclosure.
- [ ] Session User identity, Institution, route target, mutation kind,
      generation, disposal, account switch, and stale completion protections
      are proven.
- [ ] Stored tokens, password, first-login, role/login, Institution,
      relationships, history, and learning data have no frontend mutation
      control or request field.
- [ ] Dialogs/actions pass compact/wide, text-scale, keyboard, focus, semantics,
      progress/live-region, scrolling, and non-color tests.
- [ ] Full frontend/router/predecessor regression and Windows build pass.
- [ ] No backend/docs/schema/package/core/auth/Platform/route/later-stage scope
      is introduced.
- [ ] Phase 2 is strictly read-only and delivery/bookkeeping occurs only after
      PASS.

## 17. Required Tests and Verification

### 17.1 Form and domain tests

Test at minimum:

- initial values from confirmed detail;
- full-name trim/empty/200/201 and Unicode scalar counting;
- email null/unchanged/clear/exact non-empty/whitespace/shape/254/255;
- phone null/unchanged/clear/trim/whitespace/50/51;
- changed one/two/all fields and exact JSON values;
- unchanged normalized values produce no PATCH object/request;
- protected fields cannot enter the form or request;
- lifecycle action maps active→deactivate and inactive→activate only.

### 17.2 DTO, data source, and repository tests

Test at minimum:

- exact PATCH/activate/deactivate methods and one encoded UUID path segment;
- PATCH JSON content type, changed keys only, no query/tenant/protected/header/
  idempotency field;
- lifecycle passes no `data` argument and zero body bytes, no query/tenant/
  idempotency field;
- exact 200 `data + message`, endpoint message, shared 12-field parser, nulls,
  booleans, timestamps, roles, and lifecycle pairs;
- missing/extra/wrong top-level keys, wrong message, malformed/protected/extra
  resource keys, invalid UUID/role/timestamp/types, target mismatch, changed-
  field mismatch, immutable identity mismatch, and desired-state mismatch
  become unprovable;
- exact error-envelope mapping for 401, actor 403 codes, forbidden, 404, 422,
  429, 500, connection, all Dio timeout kinds, cancellation, invalid response,
  and unknown error;
- 5xx/transport/malformed success never becomes definite success and never
  replays a mutation;
- repository never exposes raw JSON/Dio/password/token/Institution data.

### 17.3 Controller and stale-state tests

Test at minimum:

- complete eligible/ineligible session matrix and zero request when ineligible;
- actions only from exact current confirmed route/detail target;
- one submit/confirm and duplicate click/Enter/keyboard/rebuild suppression;
- all conflicting actions disabled through submit and reconciliation;
- direct exact edit/lifecycle success replaces current detail correctly;
- edit and lifecycle mark Users stale only; Dashboard invalidation/request count
  remains zero;
- stale markers occur at request start and survive route disposal;
- FE004 retained query/search/filter/sort/page-size behavior is preserved;
- direct success never patches list rows/counts optimistically;
- exact 422 approved-field mapping and unknown validation fallback;
- exact 404 clears detail/action and enters FE005 not-found;
- auth/session codes invoke accepted bootstrap and clear protected data;
- each PATCH/activate/deactivate unprovable case sends zero replay and at most
  one exact FE005 GET;
- matching edit fields/current lifecycle state produces
  `unconfirmed_current_state`, never success;
- mismatch, GET 404, GET error, malformed GET, and stale GET remain safe;
- no second GET, polling, automatic Refresh, or hidden mutation retry;
- rapid target A→B, FE005 refresh replacement, logout, bootstrap, same-role/
  cross-role account switch, Institution change, route exit, disposal, and
  newer operation reject every stale completion/feedback/invalidation.

### 17.4 Widget, router, accessibility, and regression tests

Test at minimum:

- confirmed active detail shows Edit + Deactivate; inactive shows Edit +
  Activate;
- loading/error/not-found/ineligible/stale states show no action;
- edit dialog has exactly three editable fields and no protected control;
- local/server validation, no-change feedback, cancel, Escape, submit progress,
  duplicate prevention, and focus restoration;
- activation/deactivation confirmation accurately describes consequences and
  sends nothing on cancel/Escape;
- direct success and unconfirmed-current-state wording are visibly distinct;
- no raw UUID/backend message/payload/contact diagnostic appears;
- FE005 not-found and Back to Users behavior;
- `/users/new` and malformed-location FE001/FE005 regressions issue no detail/
  mutation request;
- same-session Users return preserves query and reloads authoritative data;
- Dashboard is not invalidated or automatically refreshed by edit, activate, or
  deactivate;
- `800 × 600`, `1440 × 900`, text scale 2.0, long values, scrolling, pointer,
  keyboard, visible focus, semantics, progress/live announcements, tooltips,
  and non-color meaning;
- full auth/router/shell/dashboard/profile/list/detail/create and Platform
  mutation regressions.

### 17.5 Required commands

From `frontend/`, run repository-valid equivalents of:

```text
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/features/institution_admin
flutter test test/app/router
flutter test
flutter build windows --debug
```

Run focused predecessor tests resolved in Phase 0. Also run non-writing Git
diff/scope checks, `git diff --check`, secret/credential scans using repository
conventions, and byte comparison proving the paired prompt stayed unchanged
before Phase 3.

Any required failure blocks acceptance. Do not omit a failed command from the
report or call a command PASS when it did not run.

### 17.6 Manual controlled real-stack smoke

Using non-recorded controlled credentials on the real Windows/Laravel/
PostgreSQL stack when available:

1. Open active and inactive Teacher/Student/Parent detail targets directly and
   from the retained Users list.
2. Edit one field, multiple fields, clear contacts, cancel, and submit no
   changes; verify exact requests and fresh list/detail state.
3. Cancel Deactivate, then confirm it; verify target login/protected access is
   blocked while history and stored token records remain backend-preserved.
4. Repeat/refetch state safely, activate, and verify first-login/password/token
   behavior was not reset or bypassed.
5. Verify active/inactive filters, retained query, page correction, and that
   Dashboard totals remain unchanged with no lifecycle-triggered invalidation
   or request.
6. Verify scope-safe unknown/foreign/disallowed target behavior without
   disclosure.
7. Safely induce or simulate a lost response when possible; prove no mutation
   replay and that current-state verification never says the action succeeded.
8. Verify logout/account switch/route exit, compact/wide layout, text scale,
   keyboard, focus, and semantics.

If the controlled stack is available, smoke must PASS. A smoke FAIL blocks
acceptance. `NOT RUN` is non-blocking only when the environment is genuinely
unavailable, the exact reason is reported, and equivalent automated contract/
session/stale/no-replay evidence passes. Never use `NOT RUN` to hide an
implementation or startup failure.

## 18. Required Workflow and Delivery

Branch:

```text
task/s03-fe-007-institution-user-lifecycle
```

### Phase 0 — Read-Only Git Preflight

1. Read the paired prompt and this detailed task completely.
2. Verify this task status is `Approved`.
3. Verify expected GitHub origin and fetch safely.
4. Prove clean local `main == origin/main`.
5. Prove FE006 and BE005 are independently
   `Accepted / PASS / Delivered` on that main.
6. Prove delivered FE001/002/004/005/006 contracts, code, tests, hooks, and
   route behavior exist and agree with this task.
7. Verify the working tree is clean except only the owner-prepared FE007 task
   and prompt if they are not yet committed.
8. Record the paired prompt SHA-256 for later byte comparison.
9. Resolve exact feature/test paths and every conditional predecessor test.
10. Preserve unrelated user work and stop on dirty/conflicting/unsafe state.
11. Only after all gates pass, create/switch from approved current main to the
    exact task branch.
12. Do not commit, push, open a PR, merge, or mark Accepted before Phase 2 PASS.

If a direct dependency is missing, return `FINAL STATUS: BLOCKED`. Do not start
implementation or repair predecessor scope inside FE007.

### Phase 1 — Implementation

Implement only this task and the narrow files allowed by Section 14.

During Phase 1:

- change only the FE007 row in `tasks/STAGE_03_TASK_INDEX.md` to
  `In Progress / Not started / Not started`;
- keep this task status `Approved`;
- preserve the paired prompt byte-for-byte;
- run all Section 17 checks and controlled smoke rule;
- inspect the complete diff, including owner-prepared task/prompt;
- do not commit or push.

### Phase 2 — Strictly Read-Only Acceptance Gate

Re-read all authority and inspect the complete result/diff, dependency proof,
target/route/session ownership, form/request/envelope/resource/message,
direct-success proof, no-replay, current-state-only reconciliation,
error/auth/not-found behavior, Users stale and Dashboard preservation,
accessibility,
tests/build/smoke, scope, secrets, and bookkeeping.

Phase 2 is strictly read-only:

```text
no edits
no auto-fix or write-format command
no task/index/README bookkeeping edit
no staging or commit
no push, PR, or merge
no self-fixing finding
```

Classify findings:

- `P1`: tenant/session/protected-data/password/token disclosure, target
  confusion, stale cross-session action, duplicate/destructive mutation,
  unsafe Git, secret exposure, or read-only-gate violation;
- `P2`: material route/form/request/envelope/resource/message/state/error/
  reconciliation/invalidation/accessibility/test/workflow mismatch, false
  success, mutation replay, stale-state gap, regression, or scope drift;
- `P3`: non-blocking observation with no correctness/security/evidence impact.

Any unresolved P1 or P2 returns:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start FE008. Report every P3; P3 alone does
not block acceptance.

### Phase 3 — Post-Acceptance Git Delivery

Only after Phase 2 PASS with no unresolved P1/P2:

1. Change only this task metadata status from `Approved` to `Accepted`; do not
   rewrite approved behavior.
2. Prepare only the FE007 Stage 3 index row as
   `Accepted / PASS / Delivered` in the delivery commit.
3. Update `tasks/README.md` truthfully: Stage 3 remains `In Progress`, FE007 is
   delivered, and FE008 is the next implementation gate.
4. Preserve every later task's truthful status and keep Stage 4 blocked.
5. Prove the paired prompt is byte-for-byte unchanged from Phase 0.
6. Re-run final non-writing diff, scope, secret, and consistency checks.
7. Stage only approved FE007 implementation/tests, this task, its unchanged
   prompt, `tasks/STAGE_03_TASK_INDEX.md`, and `tasks/README.md`.
8. Commit exactly:

   ```text
   feat(institution): add user edit and lifecycle UI

   Task: S03-FE-007
   ```

9. Push the exact branch, open a PR to `main`, verify base/head/diff/checks, and
   merge only when safe and permitted.
10. Fast-forward local main and prove:

    ```text
    local main == origin/main
    working tree clean
    accepted commit is an ancestor of main
    ```

Prepared Accepted/PASS/Delivered values become authoritative only after merge
and final equality/clean verification.

Phase 2 PASS but incomplete safe delivery returns:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Complete delivery returns:

```text
FINAL STATUS: ACCEPTED
```

## 19. Explicit Non-Goals

- Role, login name, password, first-login, Institution, creator, token,
  permission, or timestamp editing.
- Password reset/change/reveal/copy/resend/generation.
- Token create/delete/revoke/restore/rotation or session management.
- Institution Admin or Platform Owner target management.
- Delete, archive, suspend, transfer, merge, invite, impersonate, or bulk User
  operations.
- Group/relationship creation/removal or Stage 4 behavior.
- Settings/categories/reports or FE008/FE009 implementation.
- Learning content, Homework, Blitz, attempts, answers, scores, results, files,
  or history mutation.
- Optimistic cache authority, polling, mutation retry/replay, offline queue, or
  `Idempotency-Key`.
- Backend, database, schema, docs, package/lockfile, core network/auth, Platform
  feature, router topology/helper, shell, mobile Institution Admin, CI, or
  deployment changes.
- Stage 3 integration/closure or Stage 4 start.

## 20. Stop Conditions

Stop and report without expanding scope if:

- FE006 or BE005 is not Accepted/PASS/Delivered;
- delivered FE001/004/005/006 route, parser, repository, retained-query, detail,
  or stale-hook contract materially conflicts with this task;
- exact backend request/resource/message/error behavior differs from accepted
  BE005/docs 09;
- target/session/Institution/generation isolation cannot be proven;
- preventing duplicate mutation or automatic replay cannot be proven;
- reconciliation would need to claim causation/success from a GET;
- safe early Users stale marking cannot survive route disposal;
- protected fields, token/password behavior, new schema/package/route/core
  rewrite, or later-stage scope is required;
- unrelated user work or unsafe Git state exists;
- any required check fails;
- Phase 2 finds an unresolved P1/P2.

## 21. Required Codex Final Report

Report:

- final status;
- Phase 0 origin/main/branch/dependency/clean/prompt-hash evidence;
- every changed file and its responsibility;
- exact target/session/action ownership;
- edit fields, normalization, validation, changed JSON, no-change/cancel proof;
- exact PATCH and zero-body lifecycle POST proof;
- exact 200/envelope/message/shared-resource/target/desired-state proof;
- direct-success-only rule, no optimistic state, and zero mutation replay;
- every unprovable case and at-most-one GET/current-state-only wording proof;
- 401/actor-state/403/404/422/429/5xx/transport behavior;
- detail/list stale/update behavior, Dashboard non-invalidation, and retained-
  query preservation;
- stale session/target/route/disposal/account-switch evidence;
- protected-field/password/token/relationship/history/disclosure evidence;
- accessibility/responsive evidence;
- every command and exact result, build, smoke, regressions, scope/secrets;
- P1/P2/P3 findings;
- task/index/README/prompt-byte bookkeeping;
- commit, PR, merge, final local/remote equality, and clean tree.

State explicitly:

```text
No role/login/password/first-login/token, Institution Admin/Platform Owner,
delete/bulk, relationship/Group, settings/category, backend/schema, or Learning
behavior was implemented.
Next implementation gate: S03-FE-008.
```
