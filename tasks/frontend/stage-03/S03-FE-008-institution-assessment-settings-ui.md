# Codex Task: Institution Assessment Settings UI

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-FE-008` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Frontend` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Contract corrections reviewed | `2026-08-14` |
| Direct dependencies | `S03-FE-007`, `S03-BE-006` |
| Directly blocks | `S03-FE-009`, `S03-INT-002` |
| Transitively blocks | Stage 3 closure |

This detailed task and its paired execution prompt may be prepared before the
frontend dependency is delivered. Preparation is not implementation.

At contract-review time, current authoritative `origin/main` is:

```text
f32334c649ce222fcad661effa3fec99c7c7ce52
```

On that revision, `S03-BE-006` is `Accepted / PASS / Delivered`, while
`S03-FE-007` and its frontend predecessors are not yet delivered. Phase 0 must
re-check the then-current repository truth. Production implementation is
blocked until both direct dependencies are independently
`Accepted / PASS / Delivered` on current `origin/main`.

## 2. Goal

Replace only the delivered Institution Admin Settings placeholder at:

```text
/institution-admin/settings
```

with a real desktop assessment-settings section that reads and completely
replaces the seven approved own-Institution settings through exactly:

```text
GET /api/v1/institution/settings/assessment
PUT /api/v1/institution/settings/assessment
```

The accepted result must:

- show configured, unconfigured, loading, data, refresh, and safe error states;
- edit all seven settings as one complete representation;
- show fixed attempt rules and platform upload maxima as read-only server facts;
- accept only an exact direct PUT `200` response as proof that this mutation
  request succeeded;
- never optimistically save or automatically replay a PUT;
- use at most one read-only GET after an unprovable PUT outcome and describe it
  only as current server state, never as proof that this PUT caused that state;
- preserve exact decimal value, wire enums, tenant/session isolation, and
  backend-authoritative historical behavior;
- leave a narrow, honest composition point for S03-FE-009 without calling or
  implementing the Understanding Categories API.

Laravel remains authoritative for tenant scope, actor authorization, supported
IANA timezone membership, validation, transaction/locking, complete-replacement
ordering, updater attribution, no-op behavior, persistence, and later dependent
operations. Flutter submits one explicit complete intent and renders returned
public facts.

## 3. Current Context and Compatibility Requirements

### 3.1 Accepted backend authority

Accepted S03-BE-006 provides the exact endpoints and guarantees:

- middleware order:

  ```text
  auth:sanctum
  → active.account
  → password.changed
  → role:institution_admin
  ```

- both operations scope only by the authenticated actor's Institution;
- there is no public settings ID, Institution selector, or updater input;
- GET accepts no query and exactly zero raw request-body bytes;
- PUT requires one JSON object containing exactly all seven required fields;
- PUT serializes concurrent complete replacements under a row lock; the last
  committed complete request wins and no mixed partial state is stored;
- a missing mandatory settings row is an invariant failure and returns safe
  `500 server_error`; the API never creates a row on GET/PUT;
- GET and PUT success contain exactly one top-level key, `data`;
- PUT deliberately returns no mutation `message`;
- fixed attempts and platform maxima are derived read-only facts;
- effective changes apply only according to future dependent backend behavior
  and do not rewrite protected history or absolute stored timestamps.

This frontend must not reinterpret, duplicate, or weaken those guarantees.

### 3.2 Delivered frontend owners

Phase 0 must resolve and reuse the actual delivered paths and contracts:

- S03-FE-001 owns the Institution Admin desktop shell, exact Settings route,
  navigation selection, page title, guards, and current Settings placeholder;
- S03-FE-002 owns Dashboard state and must not be changed or invalidated here;
- S03-FE-003 owns own-Institution profile state;
- S03-FE-004–007 own Institution User list/detail/create/edit/lifecycle state;
- Stage 1 owns auth bootstrap, session generations, logout, global invalidation,
  configured Dio, stable errors, and protected-route behavior.

Do not create a second shell, route family, API client, token/session authority,
global Institution selection, or generic cross-feature mutation framework.

### 3.3 Route and Settings composition

Preserve exactly:

```text
route: /institution-admin/settings
page title: Settings
selected navigation destination: Settings
```

No `/settings/edit`, `/settings/categories`, query-driven tab, or new nested
route is allowed. Replace only the assessment/settings placeholder ownership.

S03-FE-008 establishes one Settings page/composition that contains:

1. the real independent Assessment settings section owned here;
2. an honest non-interactive placeholder such as
   `Understanding categories will be implemented in S03-FE-009.`

The placeholder performs no category request and exposes no fake categories,
ranges, defaults, loading state, or controls. S03-FE-009 will replace only that
independent section and must not couple its state to assessment settings.

## 4. Exact Eligibility and Session Ownership

No settings resource, form, product request, feedback, or old protected value
may render unless the current frontend session is all of:

```text
authenticated
role = institution_admin
must_change_password = false
session User is active according to accepted bootstrap state
session Institution is active according to accepted bootstrap state
non-null current User id
non-null current Institution id
desktop Institution Admin route is eligible
current exact path = /institution-admin/settings
```

Backend still re-authorizes every request; UI visibility is not security.

Bind every initial GET, Refresh GET, PUT, reconciliation GET, completion, form
snapshot, and feedback event to an immutable operation key containing at least:

```text
session User id
session User object instance identity
session Institution id
session generation
exact Settings route ownership
read or mutation generation
controller not disposed
```

Only the latest operation matching every value may publish. Logout, bootstrap,
same-role account switch, cross-role switch, Institution change, first-login
transition, route exit, provider disposal, or newer operation makes all older
completions stale before they can render or change state.

No Institution ID may come from a form, route/query, local preference, profile
cache, response guess, or manually supplied header.

## 5. Exact GET and Resource Contract

### 5.1 Request

```text
Method: GET
Path: /api/v1/institution/settings/assessment
Query parameters: none
Request body: exactly zero bytes
Institution selector/header: none
Automatic polling: none
```

The data source must omit the Dio `data` argument. It must not send `{}`, JSON
`null`, whitespace, form data, or an empty query map serialized into the URL.
Use only the delivered configured authenticated Dio client and central failure
pipeline.

### 5.2 Success envelope and exact resource

Confirmed GET success requires HTTP `200 OK` and exactly:

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

JSON object key order is not semantically significant, but every object must
have the exact key set. Reject missing or additional top-level, resource, or
nested keys, including `message`, `meta`, `links`, IDs, Institution, updater,
timestamps, relations, and private/protected data.

Exact type/invariant rules:

- `educational_policy_configured` is a JSON boolean;
- `acceptable_score_difference` is null or a finite JSON number, never bool,
  string, locale text, NaN, or infinity; logical value is `0..100` and has no
  more than eight effective fractional decimal places;
- the three mode values are null or exact approved strings from Section 6;
- `timezone` is a non-empty JSON string of at most 64 characters and is not
  silently trimmed, case-folded, or aliased;
- all upload and fixed-attempt values are strict JSON integers, not bool,
  numeric string, or fractional number;
- platform maxima must be exactly `25` and `15`;
- Institution limits must be respectively `1..25` and `1..15`;
- fixed attempt values must be exactly `3`, `1`, and `1`.

The configured flag is true if and only if all four educational-policy values
are non-null:

```text
acceptable_score_difference
blitz_timer_start_mode
student_result_release_mode
parent_result_release_mode
```

A legacy/controlled row may be partially populated. Therefore `false` means at
least one of those four is null; it does not mean all four are null. Preserve
and display every valid non-null value while clearly marking each null value as
`Configuration required`. Never replace a missing value with a guessed default.

An inconsistent flag, invalid nested constant/range, or malformed resource is
a safe protocol/data error. Do not partially publish it.

### 5.3 Load, Retry, and Refresh

- Entering the eligible Settings route issues at most one initial GET for the
  current operation generation; rebuilds do not duplicate it.
- Initial loading displays no old account/Institution settings.
- Initial failure displays a safe non-sensitive error and explicit Retry.
- Retry is a new user read intent and may issue one GET.
- Refresh with a clean view/form issues one new GET and latest read wins.
- If edit mode is dirty, Refresh first requires explicit confirmation to
  discard unsaved draft. Cancel sends no request; confirm discards only the
  local draft and issues one GET.
- During Refresh, current same-session confirmed data may remain visibly marked
  as refreshing; another session's data never remains.
- A malformed, stale, or failed Refresh cannot replace current confirmed data
  with partial/default content.

## 6. Exact Form, Decimal, and Display Contract

### 6.1 View and edit modes

Confirmed data first renders as a read-only summary with one `Edit settings`
action, or `Configure settings` when policy is incomplete. Editing creates a
local draft from the exact current confirmed resource:

- valid non-null policy values are preserved;
- null policy values start visibly empty with `Configuration required`;
- timezone and Institution upload limits use current returned values;
- no field is preselected from a local/device/hardcoded default;
- fixed attempt rules and platform maxima never enter the editable draft.

While editing:

- `Cancel` discards the entire draft and returns to confirmed view without a
  request;
- `Reset` restores the entire draft from the same current confirmed resource,
  clears local/server validation, stays in edit mode, and sends no request;
- a no-change Save sends no PUT, returns to confirmed view, and may announce
  only `No changes to save.`;
- Save always validates and snapshots all seven fields; it never sends partial
  changes;
- while PUT/reconciliation is in progress, all form mutation, Save, Reset,
  Refresh, and duplicate submission controls are disabled;
- leaving the route/logout/session replacement discards the unsaved draft and
  sends no mutation. Do not claim it was saved.

There is no optimistic change to the confirmed server resource.

### 6.2 Exact seven editable fields

```text
acceptable_score_difference
blitz_timer_start_mode
student_result_release_mode
parent_result_release_mode
timezone
learning_material_max_mb
student_submission_max_mb
```

No Institution, settings ID, configured flag, attempt count, platform maximum,
updater, timestamp, category, history, result, file, or derived field is
editable or copied into PUT.

### 6.3 Decimal input and lossless comparison

Keep `acceptable_score_difference` as validated decimal text/value semantics
until the transport boundary. Accepted user text uses:

```text
ASCII digits
required integer part
optional single ASCII period
one through eight digits after the period when present
no sign, whitespace, comma, grouping separator, exponent, or locale conversion
logical inclusive range 0..100
```

Representative valid values include `0`, `10`, `10.5`, `0.00000001`,
`99.12345678`, and `100.00000000`. Trailing fractional zeroes are not a
separate public value. Nine effective fractional places and silent rounding are
forbidden.

Local validation and equality must use an exact normalized decimal
representation, for example coefficient plus scale after removing insignificant
trailing zeroes. Do not use epsilon/fuzzy equality or display-rounded strings.

The PUT value must be an actual JSON number, never a quoted string. A `double`
may be used only if focused tests prove the actual configured Dio/on-wire JSON
token represents exactly the normalized accepted decimal for all required
boundaries and representative eight-place values without binary artifact or
rounding. Prefer existing repository facilities; add no package and do not
hand-build unsafe JSON. If exact safe serialization/comparison cannot be proved
within the delivered client architecture, stop instead of weakening precision.

### 6.4 Exact modes and user-facing meaning

Wire values remain exact:

```text
blitz_timer_start_mode:
  synchronized
  individual

student_result_release_mode:
  automatic
  manual_teacher

parent_result_release_mode:
  with_student
  manual_teacher
  hidden
```

Use accessible human labels and short descriptions consistent with docs 05:

- synchronized versus per-Student Blitz start; never describe a per-question
  timer;
- automatic versus Teacher-controlled Student result release;
- Parent visibility with Student, Teacher-controlled, or hidden;
- Parent visibility never precedes Student visibility under the locked
  Student-first rule.

Do not alter wire values, silently trim/case-fold them, or invent forbidden
cross-field combinations. Backend accepts the documented modes independently
and remains authoritative for later runtime behavior.

### 6.5 Timezone and upload limits

Timezone local checks require exact non-empty text, maximum 64 characters, no
leading/trailing whitespace, and no fixed numeric offset such as `+05:00`.
Do not trim, alias, case-fold, use device timezone, add a package, or hardcode
an Uzbekistan-only list. The server/runtime IANA database is authoritative for
membership; a server `422` remains possible after valid local representation.

Upload limits are strict base-10 integer inputs:

```text
learning_material_max_mb: 1..25
student_submission_max_mb: 1..15
```

Reject decimal, sign-only, whitespace, bool, numeric-string coercion at the
wire boundary, and values outside the returned validated platform maxima.
Display that `1 MB = 1,048,576 bytes` only as explanatory text; implement no
upload or file revalidation behavior.

### 6.6 Read-only server facts

Display from the strictly parsed resource, never from a second independent
editable/default source:

```text
Homework normal attempts: 3
Blitz normal attempts: 1
Maximum additional exception attempts per Student and Blitz: 1
Platform maximum learning material size: 25 MB
Platform maximum student submission size: 15 MB
```

Institution upload limits remain editable within those maxima. Attempt rules
and platform maxima have no text field, selector, toggle, action, or request
mapping.

## 7. Exact PUT Contract and Direct Success

### 7.1 Request snapshot

One valid Save snapshots the immutable session/operation key and one exact
complete seven-value representation. Send:

```text
Method: PUT
Path: /api/v1/institution/settings/assessment
Content-Type: application/json
Query parameters: none
Institution selector/header: none
Idempotency-Key: none
Automatic retry/replay: none
```

The JSON object contains exactly:

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

All seven fields are required even when only one changed. Do not send null,
only changed fields, a nested `upload_limits`, configured flag, fixed rules,
platform maxima, IDs, updater, timestamps, categories, or unknown keys.

The API has no ETag/version conflict contract. Flutter must not invent
compare-and-swap or merge behavior. A stale editor can completely replace a
newer concurrent representation; show the user the current confirmed values
and offer Refresh, but preserve the accepted server last-complete-commit-wins
contract.

### 7.2 Exact direct success

Mutation-request success is confirmed only when the original PUT returns:

- exact HTTP `200 OK`;
- exactly one top-level key, `data`;
- the exact strict resource from Section 5;
- `educational_policy_configured = true`;
- all seven returned logical values exactly equal the normalized submitted
  snapshot;
- exact fixed attempt rules and platform maxima.

There is no success `message` in the backend response. Missing/extra keys,
unexpected status/redirect, malformed resource, configured false, or any
submitted-value mismatch is not success.

Only after exact direct success and current operation ownership:

1. replace confirmed assessment settings with the exact returned resource;
2. rebuild the draft baseline from that resource and clear dirty/errors;
3. clear the current-session assessment-stale marker;
4. return to confirmed view;
5. announce the local safe message `Assessment settings saved.`

Do not invalidate Dashboard, Institution profile, Users, categories, or other
features. Do not optimistically change fixed/history/later-stage state.

## 8. Mutation Outcome Classification and Read-Only Reconciliation

### 8.1 Direct response is the only causal success proof

A later GET can show what the server currently stores, but cannot prove that
this client's PUT caused it. Another authorized Institution Admin or concurrent
request may have stored the same seven values. Therefore a reconciliation GET
must never convert an unprovable PUT into success, even when all values match.

### 8.2 Definite local or server rejection

Treat as definite non-success only when rejection is proven:

- local validation, Cancel, Reset, no-change, or other pre-request action;
- exact `401 authentication_required`;
- exact actor lifecycle/first-login/permission `403` response;
- exact `422 validation_failed`;
- exact `429 rate_limited`;
- another future exact documented 4xx rejection, without inventing business
  meaning. BE006 defines no normal 404 or 409 state for this singleton.

Never branch on human-readable backend messages.

### 8.3 Unprovable outcome

After a valid PUT begins, classify the result as unprovable whenever exact
direct success or definite rejection is unavailable, including:

- send/connect/receive/transform timeout;
- connection loss, unknown transport failure, or cancellation whose pre-send
  status cannot be proven;
- `500 server_error` or another 5xx, because the transaction may have committed
  before the response failed;
- unexpected 2xx, redirect, non-contract status, or malformed HTTP result;
- exact 200 with malformed/extra/mismatched envelope/resource/value/constants.

Immediately mark only current-session assessment settings stale when a valid
PUT starts, so route exit or a lost response forces a later authoritative load.
Show neutral feedback:

```text
The request result could not be confirmed. Checking the current server state…
```

Never say saved/failed-to-save as a causal fact, never show a mutation Retry,
and never replay PUT automatically.

### 8.4 At most one reconciliation GET

While the same session/route/mutation generation remains current, issue at most
one GET using the exact Section 5 request and parser. It is owned by the mutation
operation and must not trigger polling, normal Retry, a second reconciliation,
or any PUT.

If exact current resource is returned:

- publish it as current server state only while ownership remains current;
- clear the assessment-stale marker because current state is now known;
- compare all seven logical normalized values with the submitted snapshot;
- if all match, say only:

  ```text
  Current server settings match your submitted values, but this request result
  could not be confirmed.
  ```

- if any differ, show the newly returned current settings and say only:

  ```text
  Current server settings differ from your submitted values. This request
  result could not be confirmed.
  ```

In both cases remain explicitly unconfirmed: no success state/message,
causation, automatic edit reopening, merge, or replay.

If reconciliation fails, is malformed, or becomes stale, retain no old busy
state and say only that the request result and current server settings could not
be confirmed. Keep the assessment-stale marker so a later user entry/Refresh
loads again. A later user Save is a new explicit intent from current confirmed
data, never a retry of the old request.

## 9. Exact Error and Validation Behavior

Use stable status/code pairs and the delivered centralized failure/session
infrastructure.

- Exact `401 authentication_required`: invalidate/bootstrap global session,
  immediately clear protected settings/draft/feedback, and use accepted routing.
- `user_inactive`, `institution_inactive`, or `password_change_required`:
  clear protected state and use accepted global session reconciliation.
- Exact `403 forbidden`: safe permission feedback with no tenant/internal data.
- Exact GET `422 validation_failed`: safe client/protocol error; GET should have
  sent no body/query. Never invent editable fields from it.
- Exact PUT `422 validation_failed`: map only the seven approved keys to their
  fields. `body`, query, unknown/protected/missing-contract keys, malformed
  entries, or non-field errors become safe form-level protocol feedback.
- Exact `429 rate_limited`: definite safe failure; no countdown, hidden retry,
  or automatic PUT.
- GET 5xx/transport failure: ordinary read error with user Retry.
- PUT 5xx/transport/malformed success: unprovable path from Section 8.
- Missing invariant row is never shown as 404, auto-created, or converted into
  local defaults.

Keep non-secret draft values after a definite PUT validation failure and
focus/announce the first approved invalid field. Never display/log raw response
bodies, server messages, validation payloads, settings values unnecessarily,
URLs, IDs, Institution data, updater, SQL, stack traces, tokens, or credentials.

## 10. State, Concurrency, and Stale-Completion Rules

Required state meanings include at least:

```text
initial_loading
load_error
confirmed_data
refreshing
editing_clean
editing_dirty
local_or_server_validation_failure
submitting
reconciling_current_state
definite_failure
unconfirmed_current_state
confirmed_direct_success
```

Names may follow delivered conventions, but meanings must stay distinct.
`unconfirmed_current_state` is never success.

Required behavior:

- latest initial/Retry/Refresh read wins;
- one PUT is allowed in flight and rapid duplicate Save is deduplicated;
- editing snapshots one confirmed resource and one session generation;
- newer confirmed data cannot silently retarget an old draft;
- logout, account/Institution/role switch, password-change transition, route
  exit, or disposal clears protected resource/draft/errors/feedback immediately;
- stale GET/PUT/reconciliation success, error, 401, 403, 422, or feedback cannot
  publish into a newer session/route/operation;
- a current-session stale marker survives route-level controller disposal after
  PUT start, but is never global authority and never crosses sessions;
- no background polling, timer, offline write, queue, mutation replay, hidden
  refresh, or shared mutable singleton settings resource;
- no client-side merge of competing complete replacements;
- direct success represents the state committed by that PUT response; a later
  authorized server replacement becomes visible only through a later read.

## 11. Presentation, Explanation, and Accessibility

Institution Admin remains desktop-only. Preserve the delivered Material 3
shell/header/navigation and make the Settings body independently scrollable.

Required visible explanations, expressed clearly without promising unbuilt
features:

- these settings control future dependent behavior according to backend rules;
- changing timezone does not rewrite already stored absolute timestamps;
- changing timer/release/threshold settings does not rewrite active snapshots,
  calculated/closed results, release history, or category snapshots;
- upload limits do not retroactively revalidate/delete files;
- runtime Learning/Homework/Blitz/result/file/category behavior is implemented
  in later tasks/stages, not here.

Accessibility/responsive requirements:

- usable at `800 × 600` and `1440 × 900`, text scale `1.0` and `2.0`;
- long timezone/error/explanation text wraps or scrolls without overflow;
- logical keyboard focus reaches Edit/Configure, every field/option, Reset,
  Cancel, Save, Retry, and Refresh;
- Enter/Space activate normal controls; visible focus is preserved;
- field labels, required state, errors, configured status, read-only facts,
  progress, and unconfirmed outcome are programmatically announced;
- null policy values are not communicated by color alone;
- enum controls expose selected label and description without exposing wire
  internals as the only understandable text;
- submitting/reconciling has progress/live semantics and no duplicate action;
- focus moves to first invalid field, returns to the initiating control after
  Cancel where possible, and remains safe after refreshed state;
- no raw payload, token, ID, stack, or backend message appears in semantics.

## 12. Architecture and Exact Change Boundary

Use the delivered feature-first direction:

```text
Settings screen/assessment section
→ focused assessment read/mutation controller or notifier
→ assessment settings repository
→ assessment settings remote data source
→ configured authenticated Dio client
```

Widgets must not call Dio, parse JSON, choose tenant scope, serialize decimal
wire payloads, classify HTTP outcomes, or own reconciliation.

Phase 0 must resolve actual delivered filenames. Expected responsibilities are:

```text
frontend/lib/features/institution_admin/domain/
  immutable assessment settings/resource/value/request types
  assessment settings repository contract

frontend/lib/features/institution_admin/data/
  exact strict DTO/parser and request serialization
  remote data source and repository implementation

frontend/lib/features/institution_admin/application/
  session-scoped read/mutation state and controller
  assessment-only stale marker/reconciliation ownership

frontend/lib/features/institution_admin/presentation/
  Settings composition screen
  focused assessment view/form/read-only-facts widgets as needed
  honest S03-FE-009 placeholder only

frontend/test/features/institution_admin/
  focused domain/data/controller/widget/accessibility tests
  narrow FE001–007 regression updates where exact placeholder expectations change

frontend/lib/app/router/app_router.dart
  modify only if the delivered Settings route builder/import must point from
  FE001 placeholder to the real screen; no path/name/guard/order/topology change

frontend/lib/features/institution_admin/presentation/
  remove/stop using only the obsolete Settings placeholder if still present;
  preserve every other delivered screen

frontend/test/app/router/ and frontend/test/router_bootstrap_test.dart
  modify only exact Settings-screen expectations if required; preserve guards
```

Exact filenames must follow the delivered architecture; do not mechanically
create every illustrative file and do not place all responsibilities in one
giant screen/controller/repository file.

Allowed application/test changes are limited to the assessment settings
feature, narrow Settings route builder/obsolete-placeholder replacement, and
directly affected existing tests. Inspect/reuse but otherwise preserve:

```text
frontend/lib/core/network/**
frontend/lib/features/auth/**
frontend/lib/features/platform_admin/**
frontend/lib/features/institution_admin dashboard/profile/users code
frontend/lib/app/router/app_route_paths.dart
frontend/pubspec.yaml
frontend/pubspec.lock
frontend/integration_test/**
backend/**
docs/01–09
docker/**
```

No package, generated plugin, endpoint/client/interceptor/token-store rewrite,
global cache/event bus, generic CRUD framework, router redesign, shell redesign,
or backend/doc/schema change is allowed. Stop if the delivered architecture
cannot support exact decimal transport, session isolation, or stale ownership
within this boundary.

## 13. Authoritative References

Read each selected authority completely before implementation:

1. root `AGENTS.md` and `frontend/AGENTS.md`;
2. this detailed task and paired prompt;
3. `tasks/README.md` and `tasks/STAGE_03_TASK_INDEX.md`;
4. accepted S03-INT-001 contract/control task;
5. accepted S03-BE-006 task, implementation, tests, review, and delivery
   evidence;
6. delivered S03-FE-001 and S03-FE-007 plus all relevant frontend predecessor
   code/tests/contracts;
7. docs 02–04 Institution Admin settings role/features/flow;
8. docs 05 fixed attempts, timer/release, Student-first, upload, timezone,
   preservation, tenant, and history rules;
9. docs 06 Stage 3 scope and later-stage exclusions;
10. docs 07 Flutter layering, session isolation, API client, mutation safety,
    accessibility, and testing;
11. docs 08 settings persistence/precision/invariant fields;
12. docs 09 Sections 1–3, Section 12, and error registry;
13. accepted Platform/frontend mutation patterns only as structural reference,
    never as authority for a different envelope or false reconciliation success.

Locked docs and accepted backend/predecessor contracts outrank implementation
convenience. Stop and report any material conflict.

## 14. Acceptance Criteria

- [ ] Phase 0 proves FE007 and BE006 are independently
      `Accepted / PASS / Delivered` on current `origin/main`.
- [ ] Exact FE001 Settings route/title/selection/guards remain unchanged and
      only its placeholder is replaced.
- [ ] One independent assessment section exists; category behavior remains an
      honest no-request FE009 placeholder.
- [ ] GET uses exact path, zero body, no query/tenant input, configured Dio, and
      one current-session request generation.
- [ ] Exact only-`data` envelope, resource/nested key sets, types, configured
      iff rule, constants, ranges, and no-private-field rules are enforced.
- [ ] Partially populated unconfigured resources preserve every valid non-null
      value and invent no defaults.
- [ ] Form contains exactly seven editable settings and no protected/derived/
      fixed/category control.
- [ ] Decimal grammar, range, eight-place maximum, exact normalization, actual
      JSON-number serialization, and no-rounding proof are complete.
- [ ] Exact modes/timezone/upload constraints and user-facing meanings are
      correct without hardcoded timezone membership or silent normalization.
- [ ] Cancel, Reset, dirty Refresh confirmation, no-change Save, one in-flight
      PUT, and duplicate protection have exact request counts.
- [ ] PUT sends exactly all seven top-level keys with no query/tenant/
      idempotency/protected/nested/fixed/platform data.
- [ ] Only exact direct PUT 200 + strict matching resource confirms success;
      backend message is neither expected nor invented.
- [ ] PUT start marks assessment-only current-session state stale; exact direct
      success replaces it from response without unrelated invalidation.
- [ ] Transport/5xx/unexpected/malformed/mismatched outcomes never claim success
      or failure as causal fact and never replay PUT.
- [ ] At most one GET publishes only current server state; equal values remain
      explicitly unconfirmed and never become mutation success.
- [ ] Exact 401/actor-state/403/422/429/read error/unprovable PUT behavior is
      session-safe and never exposes raw/private data.
- [ ] Logout/account/Institution/role/route/disposal/new-generation rejects all
      stale data, draft, completion, feedback, and stale-marker authority.
- [ ] Fixed attempts/platform maxima are visible/read-only and historical/future
      explanations do not claim later behavior is implemented.
- [ ] Compact/wide, text scale, keyboard, focus, semantics, error, progress,
      null/configured, and unconfirmed states are accessible.
- [ ] Focused/full frontend regressions and Windows debug build pass.
- [ ] Phase 2 is strictly read-only and delivery/bookkeeping occurs only after
      PASS with zero unresolved P1/P2.

## 15. Tests and Verification

### 15.1 Domain, DTO, and request tests

Test at minimum:

- exact configured and fully/partially/unconfigured resources;
- exact top-level/resource/nested key sets independent of key order;
- every missing/extra/private key and wrong null/bool/string/int/double type;
- configured flag true/false inconsistency;
- exact fixed values `3/1/1`, platform maxima `25/15`, Institution limit
  boundaries, and contradictions;
- threshold JSON integer/double boundaries, effective 1–8 places, trailing-zero
  equivalence, 9-place/malformed/out-of-range/non-finite/string/bool failures;
- every valid/invalid/case/whitespace/null enum form;
- timezone type/nonempty/length/whitespace/fixed-offset representation while
  proving no hardcoded Uzbekistan/device-timezone authority;
- GET exact method/path and absence of `data`, query, tenant, and retry;
- PUT exact method/path/content type and exact seven-key body;
- actual configured Dio/on-wire threshold token is a JSON number and logically
  equals required 0/100/one-place/eight-place values without silent rounding;
- no fixed/platform/configured/ID/updater/timestamp/category key can serialize.

### 15.2 Controller and outcome tests

Test at minimum:

- one initial GET despite rebuilds; latest Retry/Refresh wins;
- initial failure/Retry and refresh-with-current-data behavior;
- partial unconfigured draft preservation and no default invention;
- Cancel/Reset/no-change/dirty Refresh confirm/cancel request counts;
- local validation, exact seven-field snapshot, one PUT, rapid duplicate Save;
- exact direct success resource/value/configured checks and local success copy;
- every definite 401/403/422/429 path and field/form mapping;
- transport/send/receive/transform/cancel, 5xx, unexpected 2xx/status, malformed
  and mismatched 200 all enter unprovable state;
- unprovable outcome issues zero or one reconciliation GET, never two and never
  another PUT;
- reconciliation exact-equal, different, malformed, error, 401, and stale paths
  use current-state-only wording and never success;
- assessment stale marker begins at PUT start, survives route disposal for the
  same session, clears on exact current read/success, and never crosses session;
- logout, bootstrap, same-role/cross-role switch, Institution change, route
  exit, disposal, and newer operation reject every stale completion/feedback.

### 15.3 Widget, router, accessibility, and regression tests

Test at minimum:

- exact `/institution-admin/settings` route, Settings title/selection, direct
  entry, shell guard, rebuild, logout, and back/navigation regression;
- Settings placeholder is gone; assessment section and honest no-request FE009
  placeholder render independently;
- loading/error/Retry/Refresh/configured/partial-unconfigured/edit/read-only
  facts/local+server errors/direct-success/unconfirmed states;
- exactly seven editable controls and absence of editable fixed/platform/
  Institution/updater/category controls;
- human mode descriptions, Student-first statement, MB/time/history text;
- dirty Refresh confirmation, Cancel, Reset, no-change, progress, duplicate
  prevention, and safe route exit;
- direct-success and equal reconciliation wording are visibly/semantically
  distinct;
- `800 × 600`, `1440 × 900`, text scale 2.0, long timezone/error text,
  scrolling, pointer, keyboard, visible focus, semantics, live announcements,
  and non-color status meaning;
- zero category request and no Dashboard/Profile/User invalidation;
- full auth/router/shell/dashboard/profile/User and Platform regressions.

### 15.4 Required commands

From `frontend/`, run repository-valid equivalents of:

```text
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/features/institution_admin
flutter test test/app/router
flutter test
flutter build windows --debug
```

Run focused predecessor tests resolved in Phase 0. Also run non-writing Git
scope/diff checks, `git diff --check`, repository-convention secret/credential
scans, and a byte comparison proving the paired prompt stayed unchanged before
Phase 3.

Any required failure blocks acceptance. Do not omit a failed command or call a
command PASS when it did not run.

### 15.5 Controlled real-stack smoke

Using non-recorded controlled Institution Admin credentials on the real
Windows/Laravel/PostgreSQL stack when available:

1. Load a new unconfigured row and verify exact null/default/fixed/max facts.
2. Load a controlled partially populated row and verify preserved values plus
   required missing fields without invented defaults.
3. Save representative valid modes/timezone/upload values and an eight-place
   threshold; reload and verify exact persisted logical values.
4. Cancel, Reset, submit no changes, and cancel dirty Refresh; verify request
   counts.
5. Submit local-invalid and server-unsupported timezone/boundary cases; verify
   no partial mutation and safe field errors.
6. Use another Institution Admin and another Institution to verify actor/session
   isolation and complete-replacement current state.
7. Safely induce/simulate a lost PUT response; prove zero replay and that the
   reconciliation GET never says this PUT succeeded, even on exact match.
8. Verify logout/account switch/route exit, compact/wide layout, text scale,
   keyboard, focus, and no category call.
9. Verify history/absolute timestamps/files/categories/results are not changed
   by this frontend operation beyond accepted backend behavior.

If the controlled stack is available, smoke must PASS. A smoke FAIL blocks
acceptance. `NOT RUN` is non-blocking only when the environment is genuinely
unavailable, the exact reason is reported, and equivalent automated contract/
session/precision/no-replay evidence passes. Never use `NOT RUN` to hide an
implementation or startup failure.

## 16. Required Workflow and Delivery

Branch:

```text
task/s03-fe-008-assessment-settings
```

### Phase 0 — Read-Only Git and Authority Preflight

1. Read the paired prompt and this detailed task completely.
2. Read root/frontend `AGENTS.md`, task index/README, S03-INT-001, accepted
   BE006, delivered FE001–007 authority, referenced locked docs, and current
   relevant implementation/tests.
3. Verify this task is `Approved` and record the paired prompt SHA-256.
4. Verify the expected GitHub origin and fetch safely.
5. Prove clean local `main == origin/main`.
6. Prove FE007 and BE006 are independently
   `Accepted / PASS / Delivered` on that current main.
7. Prove delivered Settings route/placeholder/session/client/test contracts
   exist and agree with this task.
8. Verify the working tree is clean except only owner-prepared FE008 task/prompt
   if not yet committed; preserve unrelated user work.
9. Resolve exact feature/test files and conditional predecessor regressions.
10. Prove safe exact decimal JSON-number serialization is possible without a
    package/core-client rewrite.
11. Only after every gate passes, create/switch from approved current main to
    the exact task branch.
12. Do not commit, push, open a PR, merge, or mark Accepted before Phase 2 PASS.

If either dependency is missing, return `FINAL STATUS: BLOCKED`. Do not start
implementation or repair predecessor scope inside FE008.

### Phase 1 — Implementation

Implement only this task and the narrow files allowed by Section 12.

During Phase 1:

- change only the FE008 row in `tasks/STAGE_03_TASK_INDEX.md` to
  `In Progress / Not started / Not started`;
- keep this task status `Approved`;
- preserve the paired prompt byte-for-byte;
- run all Section 15 checks and controlled smoke rule;
- inspect the complete diff, including owner-prepared task/prompt;
- do not commit or push.

### Phase 2 — Strictly Read-Only Acceptance Gate

Re-read all authority and inspect the complete implementation/diff plus exact
route/eligibility/session/resource/form/decimal/wire/envelope/direct-success/
no-replay/reconciliation/error/stale/history/accessibility/test/build/smoke/
scope/secret/bookkeeping evidence.

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

- `P1`: tenant/session/protected-data/credential/token disclosure, cross-account
  stale state, duplicate/destructive mutation, unsafe Git, secret exposure, or
  read-only-gate violation;
- `P2`: material API/resource/type/decimal/form/state/error/direct-success/
  reconciliation/accessibility/test/workflow mismatch, false success, mutation
  replay, regression, or scope drift;
- `P3`: non-blocking observation with no correctness, security, required
  evidence, or maintainability-acceptance impact.

Any unresolved P1 or P2 returns:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start FE009. Report every P3; P3 alone does
not block acceptance.

### Phase 3 — Post-Acceptance Git Delivery

Only after Phase 2 PASS with no unresolved P1/P2:

1. Change only this task metadata status from `Approved` to `Accepted`; do not
   rewrite approved behavior.
2. Prepare only the FE008 Stage 3 index row as
   `Accepted / PASS / Delivered` in the delivery commit.
3. Update `tasks/README.md` truthfully: Stage 3 remains `In Progress`, FE008 is
   delivered, and FE009 is the next implementation gate.
4. Preserve every later task's truthful status and keep Stage 4 blocked.
5. Prove the paired prompt is byte-for-byte unchanged from Phase 0.
6. Re-run final non-writing diff, scope, secret, and consistency checks.
7. Stage only approved FE008 implementation/tests, this task, its unchanged
   prompt, `tasks/STAGE_03_TASK_INDEX.md`, and `tasks/README.md`.
8. Commit exactly:

   ```text
   feat(institution): add assessment settings UI

   Task: S03-FE-008
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

## 17. Explicit Non-Goals

- Understanding Category GET/PUT, models, ranges, defaults, editor, or fake
  production data; S03-FE-009 owns them.
- Editable attempt rules or platform upload maxima.
- Partial PATCH-style settings update, ETag/version/conflict merge, settings
  history, audit/version screen, or cross-Institution selector.
- Runtime Blitz activation/timing, Student/Parent result release, calculation,
  recalculation, category assignment, file upload/validation/deletion, or
  `institution_settings_incomplete` enforcement in later operations.
- Rewriting active snapshots, calculated/closed results, release/category
  snapshots, files, historical rows, or absolute timestamps.
- Dashboard/Profile/User invalidation or changes.
- Groups, relationships, reports, learning content, Teacher/Student/Parent
  product UI, mobile Institution Admin, or web Institution Admin.
- Optimistic save, polling, offline write, mutation retry/replay, queue, or
  `Idempotency-Key`.
- Backend, database, schema, locked docs, package/lockfile, core network/auth,
  Platform feature, router topology/path/helper, shell redesign, CI, or deploy.
- Stage 3 integration/closure or Stage 4 start.

## 18. Stop Conditions

Stop and report without widening scope if:

- FE007 or BE006 is not Accepted/PASS/Delivered;
- delivered FE001 Settings route/shell or Stage 1 session/client contracts
  materially conflict with this task;
- accepted BE006/docs 09 request/resource/error behavior differs materially;
- exact decimal validation, JSON-number serialization, or logical comparison
  cannot be proved without rounding/new package/core rewrite;
- session/Institution/generation isolation or duplicate prevention cannot be
  proved;
- a reconciliation GET would need to claim mutation success/causation;
- safe assessment-only stale marking cannot survive route disposal;
- category/runtime/history/backend/schema/package/new-route scope is required;
- unrelated user work or unsafe Git state exists;
- any required test/build/check/smoke fails;
- Phase 2 finds an unresolved P1/P2.

## 19. Required Codex Final Report

Report:

- final status;
- Phase 0 origin/main/branch/dependency/clean/prompt-hash evidence;
- every changed file and responsibility;
- exact route/shell/session eligibility and no-category-call proof;
- exact GET request/envelope/resource/types/configured/partial-state proof;
- exact seven fields, decimal normalization/on-wire numeric proof, modes,
  timezone, upload limits, fixed/max facts, and validation evidence;
- Cancel/Reset/no-change/dirty Refresh/duplicate request counts;
- exact PUT body and direct-200-only success proof;
- all unprovable cases, assessment-stale behavior, at-most-one GET, current-
  state-only wording, and zero replay proof;
- 401/actor-state/403/422/429/GET error/PUT 5xx behavior;
- logout/account/Institution/role/route/disposal/new-generation evidence;
- historical/later-scope/non-disclosure evidence;
- accessibility/responsive evidence;
- every command and exact result, build, smoke, regressions, scope/secrets;
- P1/P2/P3 findings;
- task/index/README/prompt-byte bookkeeping;
- commit, PR, merge, final local/remote equality, and clean tree.

State explicitly:

```text
No Understanding Category, editable attempt/platform maximum, runtime Blitz/
result/file/history, Dashboard/Profile/User, backend/schema, mobile-admin, web,
Group/relationship/report/learning, integration/closure, or Stage 4 behavior
was implemented.
Next implementation gate: S03-FE-009.
```
