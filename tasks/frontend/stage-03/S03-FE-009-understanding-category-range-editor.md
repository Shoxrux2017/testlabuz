# Codex Task: Understanding Category Range Editor

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-FE-009` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Frontend` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Contract corrections reviewed | `2026-08-14` |
| Direct dependencies | `S03-FE-008`, `S03-BE-007` |
| Directly blocks | `S03-INT-002` |
| Transitively blocks | Stage 3 closure |

This detailed task and its paired execution prompt may be prepared before its
dependencies are delivered. Preparation is not implementation.

At contract-review time, current authoritative `origin/main` is:

```text
f32334c649ce222fcad661effa3fec99c7c7ce52
```

On that revision, Stage 3 is delivered only through S03-BE-006. S03-BE-007 and
S03-FE-008 are not yet delivered, and the current implementation gate is
S03-BE-007. Phase 0 must re-check repository truth at execution time. Production
implementation of S03-FE-009 is blocked until both direct dependencies are
independently `Accepted / PASS / Delivered` on current `origin/main`.

## 2. Goal

Replace only the honest S03-FE-009 placeholder inside the delivered Institution
Admin Settings page at:

```text
/institution-admin/settings
```

with an independent desktop Understanding Categories section that reads the
own-Institution configuration and atomically replaces the complete fixed
five-category set through exactly:

```text
GET /api/v1/institution/understanding-categories
PUT /api/v1/institution/understanding-categories
```

The accepted result must:

- render the exact backend unconfigured or configured state;
- keep five fixed codes, labels, meanings, and orders non-editable;
- allow only the first four inclusive integer min/max ranges to be entered;
- keep `not_completed` permanently non-numeric with null/null bounds;
- validate one complete high-to-low partition of every integer `0..100`;
- send one exact complete canonical five-object replacement;
- accept only an exact direct PUT `200` response as proof that this mutation
  request succeeded;
- never optimistically save or automatically replay a PUT;
- use at most one read-only GET after an unprovable PUT outcome and describe it
  only as current server state, never as proof that this PUT caused that state;
- preserve the delivered Assessment settings section, its draft, requests,
  errors, stale marker, and mutation lifecycle independently;
- preserve session/Institution isolation and historical category snapshots.

Laravel remains authoritative for tenant scope, actor authorization, complete-
set validation, transaction/locking, first configuration, row identity, updater,
timestamps, no-op behavior, concurrency ordering, and later result behavior.
Flutter submits one explicit complete intent and displays public server facts.

## 3. Current Context and Compatibility Requirements

### 3.1 Accepted backend authority

Delivered S03-BE-007 must provide and prove before this task starts:

- middleware order:

  ```text
  auth:sanctum
  → active.account
  → password.changed
  → role:institution_admin
  ```

- tenant scope derives only from the authenticated Institution Admin;
- the existing own-Institution `institution_settings` row is the stable
  PostgreSQL lock target for first configuration and replacement;
- zero stored category rows means unconfigured;
- exactly five complete valid rows means configured;
- any other count or invalid five-row set is a safe invariant `500`, never a
  repair/default/unconfigured response;
- GET accepts no query and exactly zero raw body bytes;
- PUT requires JSON with exactly one root key and exactly five exact-shaped
  category objects;
- complete replacements serialize and never mix competing sets;
- PUT response contains no success `message`;
- category IDs, Institution, updater, timestamps, and relations are private;
- no result/category snapshot/history is recalculated or rewritten.

This frontend must not reinterpret, duplicate, or weaken those guarantees.

### 3.2 Delivered frontend authority

Phase 0 must resolve and reuse the actual delivered paths and contracts:

- S03-FE-001 owns the exact Settings route, title, selected navigation,
  Institution Admin desktop shell, guards, and session-safe route behavior;
- S03-FE-008 owns the Settings page composition and the independent real
  Assessment settings section, including its resource/form/controller,
  assessment-only stale marker, dirty state, errors, PUT lifecycle, and tests;
- S03-FE-008 leaves one honest non-interactive placeholder specifically for
  this Understanding Categories section;
- Stage 1 owns auth bootstrap, session generation, logout, global invalidation,
  configured Dio, stable error mapping, and protected-route behavior.

Do not create a second Settings screen, route, shell, API client, session
authority, tenant selector, or generic cross-feature mutation framework.

### 3.3 Exact composition boundary

Preserve exactly:

```text
route: /institution-admin/settings
page title: Settings
selected navigation destination: Settings
```

No `/settings/categories`, nested route, modal route, query-driven tab, route
name/path/helper/order, or shell topology change is allowed.

Replace only the FE008 category placeholder with the real category section.
The page then has two sibling feature sections:

```text
Assessment settings        — owned by S03-FE-008
Understanding categories  — owned by S03-FE-009
```

Their read, draft, Refresh, validation, error, PUT, reconciliation, busy, and
stale states are independent. Only accepted global auth/session invalidation is
shared.

## 4. Exact Eligibility and Operation Ownership

No category resource, form, product request, feedback, or prior protected value
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

Bind every category initial GET, Retry/Refresh GET, PUT, reconciliation GET,
form snapshot, completion, stale marker, and feedback event to an immutable key
containing at least:

```text
session User id
session User object instance identity
session Institution id
session generation
exact Settings route ownership
category read or mutation generation
category controller not disposed
```

Only the latest matching operation may publish category state. Logout,
bootstrap, same-role account switch, cross-role switch, Institution change,
first-login transition, route exit, provider disposal, or newer category
operation makes every older completion stale before it can render or mutate
state.

No Institution/category/settings ID may come from form data, route/query,
device/local preference, assessment/profile cache, response guess, or manually
supplied header.

## 5. Exact Fixed Category Model

One focused frontend fixed-category definition is the sole client-side source
for code, exact English label, order, and numeric/non-numeric presentation:

| Order | Code | Fixed label | Editable bounds |
|---:|---|---|---|
| 1 | `understood_well` | `Understood well` | integer min/max |
| 2 | `partially_understood` | `Partially understood` | integer min/max |
| 3 | `needs_revision` | `Needs revision` | integer min/max |
| 4 | `needs_teacher_support` | `Needs teacher support` | integer min/max |
| 5 | `not_completed` | `Not completed` | never; null/null |

Codes, labels, order, and `not_completed` shape are server-fixed and visible as
read-only identity/context. They have no editable text, order drag/drop,
selector, rename, custom label, color, or icon control.

This fixed definition is presentation/request structure, not fake configured
data. It may create empty editor rows after an exact unconfigured response, but
it must never invent numeric ranges or mark the Institution configured.

## 6. Exact GET and Response Contract

### 6.1 Request

```text
Method: GET
Path: /api/v1/institution/understanding-categories
Query parameters: none
Request body: exactly zero bytes
Institution selector/header: none
Automatic polling: none
```

The data source must omit the Dio `data` argument. It must not send `{}`, JSON
`null`, whitespace, form data, or a query map. Use only the delivered configured
authenticated Dio client and central failure pipeline.

### 6.2 Exact unconfigured response

HTTP `200 OK` is unconfigured only when the top-level object contains exactly
`data` and `meta`:

```json
{
  "data": [],
  "meta": {
    "configured": false
  }
}
```

Required invariants:

- `data` is exactly an empty JSON array;
- `meta` is exactly one JSON object with one key;
- `configured` is exactly JSON boolean `false`;
- there are no additional top-level/meta keys or items.

`data: []` without exact meta, `configured: true`, non-empty data with meta, or
any missing/extra/wrong-type value is malformed, not another valid state.

### 6.3 Exact configured response

HTTP `200 OK` is configured only when the top-level object contains exactly one
key, `data`, and its value is an array of exactly five items in canonical order.
There is no `meta`, `message`, `links`, or pagination.

Each item contains exactly:

```text
code
label
min_score
max_score
sort_order
```

JSON object key order is not semantically significant, but the key set is
exact. Array order is significant and must be 1 through 5.

Strict parser/domain validation requires:

- exact five unique codes, labels, and code-to-order mapping from Section 5;
- first four min/max values are strict JSON integers, never bool, numeric
  string, float such as `1.0`, null, or coerced value;
- numeric bounds are within `0..100` with `min_score <= max_score`;
- `not_completed` min/max are exactly JSON null;
- order 1 max is `100` and order 4 min is `0`;
- each adjacent high-to-low pair satisfies:

  ```text
  higher.min_score = lower.max_score + 1
  ```

- therefore every integer `0..100` is covered exactly once without gap,
  overlap, reversal, duplicate, or missing band.

Reject missing/extra/private fields including IDs, Institution, updater,
timestamps, relations, settings, result/history data, counts, colors, icons, or
custom names. A partial, duplicate, unknown, malformed, out-of-order, or invalid
complete set is a safe protocol/data error and is never repaired, defaulted, or
partially published.

### 6.4 Load, Retry, and category Refresh

- Entering the eligible Settings route issues at most one category initial GET
  for the current category generation; rebuilds do not duplicate it.
- Category loading/error never hides, clears, blocks, or changes confirmed
  Assessment settings.
- Initial category loading displays no prior account/Institution category data.
- Initial category failure shows a safe error and category-specific Retry.
- Retry is one new user read intent; latest category read wins.
- Category Refresh with a clean category view/form issues one new GET.
- If the category editor is dirty, category Refresh first requires explicit
  confirmation to discard only the category draft. Cancel sends no request;
  confirm discards only category draft and issues one category GET.
- Category Refresh never discards or refreshes an Assessment draft.
- During category Refresh, current same-session confirmed categories may remain
  visibly marked refreshing; another session's data never remains.
- A malformed, stale, or failed category Refresh cannot replace confirmed data
  with partial/default content.

## 7. Exact Editor and Integer Validation

### 7.1 Configured and unconfigured editing

Configured data first renders read-only with `Edit categories`. Editing copies
the exact current four numeric ranges into a local category draft.

Unconfigured data renders all five fixed rows and `Configuration required`,
with one `Configure categories` action. Its editor:

- starts all eight numeric fields empty;
- keeps fixed code/label/order visible and non-editable;
- keeps `not_completed` visibly non-numeric and non-editable;
- does not insert example/default/recommended range numbers;
- cannot Save until one complete valid partition is entered.

### 7.2 Controls and draft actions

Only these eight text inputs are editable:

```text
understood_well.min_score
understood_well.max_score
partially_understood.min_score
partially_understood.max_score
needs_revision.min_score
needs_revision.max_score
needs_teacher_support.min_score
needs_teacher_support.max_score
```

While editing:

- `Cancel` discards the category draft and returns to current confirmed category
  state without a request;
- `Reset` restores the category draft from current configured values, or clears
  all eight inputs for unconfigured state, stays in edit mode, clears category
  validation, and sends no request;
- a configured no-change Save sends no PUT, returns to confirmed view, and may
  announce only `No changes to save.`;
- Save validates and snapshots the complete five-entry representation;
- while category PUT/reconciliation is active, category fields, Save, Reset,
  Cancel, and category Refresh are disabled;
- category busy state does not disable Assessment fields/actions, and Assessment
  busy state does not disable category fields/actions;
- leaving the route/logout/session replacement discards category draft and
  sends no mutation. Do not claim it was saved.

There is no optimistic update to confirmed category state.

### 7.3 Exact integer text and value rules

Accepted numeric input text uses exactly:

```text
ASCII 0, or a non-zero ASCII digit followed by at most two ASCII digits
no leading zeroes on multi-digit values
no sign, whitespace, decimal point, comma, grouping, exponent, or locale digits
logical inclusive value 0..100
```

Inputs such as `1.0`, `01`, `+1`, `-1`, `1e2`, ` 1`, `1 `, `1,0`, empty, or
non-ASCII digits are invalid. Parse only after lexical validation and serialize
actual JSON integers, never strings or doubles.

Validate all rules together:

- all first-four min/max values are present;
- each is `0..100` and each `min <= max`;
- `understood_well.max = 100`;
- `needs_teacher_support.min = 0`;
- fixed high-to-low order is preserved;
- for every adjacent higher/lower row,
  `higher.min = lower.max + 1`;
- all `101` integer values are covered exactly once;
- `not_completed` remains fixed null/null/order 5.

Show precise field/row errors plus one set-level coverage summary. A valid
summary may state `All integer scores from 0 through 100 are covered exactly
once.` Invalid/incomplete input must never display a valid/configured summary.

Document example ranges are examples only. Never prefill or save them as
universal defaults.

## 8. Exact PUT and Direct Success Contract

### 8.1 Request

One valid category Save snapshots the immutable session/category operation key
and one exact canonical complete set. Send:

```text
Method: PUT
Path: /api/v1/institution/understanding-categories
Content-Type: application/json
Query parameters: none
Institution selector/header: none
Idempotency-Key: none
Automatic retry/replay: none
```

The root contains exactly one key, `categories`. Its array contains exactly five
objects in canonical order. Each object contains exactly four keys:

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
      "min_score": 66,
      "max_score": 85,
      "sort_order": 2
    },
    {
      "code": "needs_revision",
      "min_score": 50,
      "max_score": 65,
      "sort_order": 3
    },
    {
      "code": "needs_teacher_support",
      "min_score": 0,
      "max_score": 49,
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

The numbers are an example only. Codes and sort orders come from the fixed
definition, never editable inputs. Do not send label, configured/meta, IDs,
Institution, updater, timestamps, color/icon/name, category score, result,
history, assessment settings, or unknown fields.

The API has no ETag/version conflict or idempotency contract. Do not invent
compare-and-swap, merge, or client conflict resolution. A stale editor may be
replaced by the last complete server transaction; offer current data/Refresh
but preserve accepted last-complete-commit-wins behavior.

### 8.2 Exact direct success

Mutation-request success is confirmed only when the original PUT returns:

- exact HTTP `200 OK`;
- exactly one top-level key, `data`;
- the exact configured collection from Section 6.3;
- exact canonical five-item order, keys, codes, labels, integer/null types, and
  complete-set invariants;
- every returned code/range/order logical value exactly equals the submitted
  snapshot.

The backend response has no success `message` or `meta`. Missing/extra keys,
unexpected status/redirect, malformed collection, or submitted-value mismatch
is not success.

Only after exact direct success and current category operation ownership:

1. replace confirmed category state with the exact returned collection;
2. rebuild the category draft baseline and clear category dirty/errors;
3. clear only the current-session category stale marker;
4. return the category section to confirmed view;
5. announce the local safe message `Understanding categories saved.`

Do not modify/invalidate Assessment settings, Dashboard, Profile, Users, result,
history, or another feature.

## 9. Mutation Outcome Classification and Read-Only Reconciliation

### 9.1 Direct response is the only causal success proof

A later GET can show current server categories, but it cannot prove that this
client's PUT caused them. Another eligible Institution Admin or concurrent
request may have stored the same complete set. Therefore reconciliation never
converts an unprovable PUT into success, even on an exact match.

### 9.2 Definite local or server rejection

Treat as definite non-success only when rejection is proven:

- local validation, Cancel, Reset, no-change, or another pre-request action;
- exact `401 authentication_required`;
- exact actor lifecycle/first-login/permission `403` response;
- exact `422 validation_failed`;
- exact `429 rate_limited`;
- another future exact documented 4xx rejection without invented business
  meaning. BE007 defines no normal 404 or 409 for these category endpoints.

The later `409 category_configuration_invalid` belongs to dependent Topic
result calculation, not GET/PUT category management. Never implement or expect
it here. Never branch on human-readable backend messages.

### 9.3 Unprovable PUT outcome

After a valid PUT begins, classify the result as unprovable whenever exact
direct success or definite rejection is unavailable, including:

- send/connect/receive/transform timeout;
- connection loss, unknown transport failure, or cancellation whose pre-send
  status cannot be proven;
- `500 server_error` or another 5xx, because a transaction may have committed
  before response delivery failed;
- unexpected 2xx, redirect, non-contract status, or malformed HTTP result;
- exact 200 with malformed/extra/mismatched envelope/item/set/value.

Immediately mark only current-session category data stale when valid PUT starts,
so route exit or a lost response forces a later authoritative category load.
Show neutral feedback:

```text
The request result could not be confirmed. Checking current server categories…
```

Never say saved/failed-to-save as a causal fact, never show a mutation Retry,
and never replay PUT automatically.

### 9.4 At most one reconciliation GET

While the same session/route/category mutation generation remains current,
issue at most one GET using the exact Section 6 request/parser. It belongs to
the category mutation controller and must not trigger polling, normal Retry, a
second reconciliation, Assessment Refresh, or any PUT.

If the GET returns an exact configured collection:

- publish it only as current category server state while ownership matches;
- clear the category stale marker because current state is known;
- compare all five canonical code/range/order values with the submitted set;
- exact match says only:

  ```text
  Current server categories match your submitted ranges, but this request
  result could not be confirmed.
  ```

- any difference says only:

  ```text
  Current server categories differ from your submitted ranges. This request
  result could not be confirmed.
  ```

If the GET returns the exact unconfigured response, publish current
unconfigured state, clear the category stale marker, and say only:

```text
Current server categories are not configured. This request result could not be
confirmed.
```

Every case remains explicitly unconfirmed: no success wording/state,
causation, auto-merge, edit reopening, or replay.

If reconciliation fails, is malformed, or becomes stale, clear category busy
ownership and say only that the request result/current categories could not be
confirmed. Keep the category stale marker so a later user entry/Refresh reloads.
A later Save is a new explicit intent from current confirmed category state,
never a retry of the prior request.

## 10. Exact Error and Validation Behavior

Use stable status/code pairs and the delivered centralized session/failure
infrastructure.

- Exact `401 authentication_required`: invalidate/bootstrap global session and
  immediately clear both protected Settings sections through accepted behavior.
- `user_inactive`, `institution_inactive`, or `password_change_required`:
  clear protected state and use accepted global session reconciliation.
- Exact `403 forbidden`: safe permission feedback with no tenant/internal data.
- Exact GET `422 validation_failed`: category client/protocol error because GET
  should send no input; do not invent form fields from it.
- Exact PUT `422 validation_failed` mapping:
  - `categories` becomes a safe set-level error;
  - known canonical `categories.<0..3>.min_score|max_score` may map to the
    corresponding visible input because the client sends canonical order;
  - `categories.4.min_score|max_score`, code/order errors, unknown index/key,
    body/query/protected/root errors, or malformed entries become safe form-
    level protocol feedback because those values are non-editable/client-owned;
- Exact `429 rate_limited`: definite safe failure, no countdown or auto-retry;
- GET 5xx/transport: ordinary category load error with user category Retry;
- PUT 5xx/transport/malformed success: Section 9 unprovable path;
- missing settings lock row or corrupt stored set is never shown as
  unconfigured, 404, defaults, or repair controls.

Keep non-secret numeric draft after definite PUT validation failure and
focus/announce the first approved invalid input or set summary. Never display/
log raw response bodies, server messages, validation payloads, category ranges
unnecessarily, URLs, IDs, Institution/updater data, SQL, stack traces, tokens,
or credentials.

## 11. Independent Section, Concurrency, and Stale-State Rules

Required category state meanings include at least:

```text
initial_loading
load_error
unconfigured_confirmed
configured_confirmed
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

Names may follow delivered conventions, but meanings remain distinct.
`unconfirmed_current_state` is never success.

Category and Assessment behavior:

- category initial/Retry/Refresh can run independently of Assessment reads;
- category failure never erases/hides Assessment data or draft;
- Assessment failure never erases/hides category data or draft;
- category Refresh affects only category state;
- category Save/Reset/Cancel/validation affects only category state;
- each section deduplicates only its own mutation; a category busy state does
  not globally disable Assessment and vice versa;
- if independent valid Assessment and category PUTs overlap, client state stays
  separate and the backend owns safe serialization; Flutter does not merge or
  reorder server transactions;
- assessment/category stale markers are separate and session-scoped;
- only central auth/session invalidation clears both sections together;
- page/widget rebuilds must not recreate providers or discard either current
  same-session draft;
- route exit disposes/clears protected presentation state for both according to
  their owners, while each same-session mutation-start stale marker survives as
  required for later reload;
- no category completion/error/feedback may publish through the assessment
  controller or vice versa.

General category stale behavior:

- latest category initial/Retry/Refresh read wins;
- one category PUT in flight; rapid duplicate category Save is deduplicated;
- edit snapshots one confirmed category state and session generation;
- newer category confirmed data cannot silently retarget an old category draft;
- logout, account/Institution/role switch, password-change transition, route
  exit, or disposal clears category resource/draft/error/feedback immediately;
- stale category GET/PUT/reconciliation success, error, 401, 403, 422, or
  feedback cannot publish into a newer session/route/operation;
- category stale marker survives category controller disposal only for the same
  eligible session and never becomes cross-session/global authority;
- no polling, timer, offline write, queue, mutation replay, hidden Refresh,
  global selected category, or client merge of competing complete sets;
- direct success is that PUT response's committed set; later server replacement
  appears only through a later read.

## 12. Presentation, Meaning, History, and Accessibility

Institution Admin remains desktop-only. Preserve the FE008 Settings composition
and use one shared page scroll strategy without nested-scroll overflow or a
second page scaffold/header.

Required user-facing meaning:

- the first four rows are inclusive integer ranges for a backend-derived
  `category_score`, not direct decimal final-score bands;
- the backend derives that integer from the unrounded internal final score:
  fractions `.0` through `.5` round down and fractions greater than `.5` round
  up; this task explains but does not calculate it;
- `Not completed` has no numeric range and represents missing required work,
  not a low score, waiting Teacher review, or unreleased result;
- range changes are available only to future or later explicitly recalculated
  eligible open results according to backend rules;
- already calculated/closed category code/range snapshots are not silently
  rewritten;
- no result calculation/recalculation/assignment/history behavior is claimed
  as implemented by this frontend task.

Accessibility/responsive requirements:

- at `1440 × 900`, a readable fixed-order table/grid may be used;
- at `800 × 600`, use scrollable cards/rows without horizontal overflow;
- text scale `1.0` and `2.0` works at both required sizes;
- long labels/errors/explanations wrap or scroll without clipping;
- logical keyboard focus reaches category Edit/Configure, all eight fields,
  Reset, Cancel, Save, Retry, and Refresh without trapping Assessment focus;
- Enter/Space activate normal controls; visible focus is preserved;
- labels, fixed codes/order, required/error state, `not_completed`, configured
  state, coverage summary, progress, and unconfirmed outcome are announced;
- invalid/valid range meaning does not rely on color alone;
- submitting/reconciling has live progress semantics and no duplicate action;
- focus moves to first invalid category field or set summary and returns to the
  category initiating control after Cancel where possible;
- raw payload, token, private ID, stack, or backend message is not announced.

## 13. Architecture and Exact Change Boundary

Use the delivered feature-first direction:

```text
FE008 Settings composition / category section
→ focused category read/mutation controller or notifier
→ understanding category repository
→ understanding category remote data source
→ configured authenticated Dio client
```

Widgets must not call Dio, parse JSON, choose tenant scope, map HTTP errors,
serialize request objects, or own reconciliation.

Phase 0 must resolve actual delivered filenames. Expected responsibilities are:

```text
frontend/lib/features/institution_admin/domain/
  fixed category definition and immutable category/configuration/request types
  pure complete-set validator/value helpers
  category repository contract

frontend/lib/features/institution_admin/data/
  exact configured/unconfigured envelope and item DTO/parser
  exact canonical request serialization
  category remote data source/repository implementation

frontend/lib/features/institution_admin/application/
  category-only session-scoped read/mutation state/controller
  category-only stale marker and bounded reconciliation

frontend/lib/features/institution_admin/presentation/
  replace only FE008 category placeholder with focused section/editor widgets
  preserve Assessment section and shared Settings composition

frontend/test/features/institution_admin/
  focused category domain/data/controller/widget/accessibility tests
  narrow FE008 Settings independence/composition regressions

frontend/test/app/router/ and frontend/test/router_bootstrap_test.dart
  run all; modify only if an exact placeholder expectation must become the real
  section, never to change route behavior
```

Exact filenames must follow the delivered architecture. Do not mechanically
create every illustrative file and do not put all DTO/domain/controller/form/
composition responsibilities in one giant file.

Allowed application/test changes are limited to the category feature, narrow
replacement of the FE008 category placeholder/composition seam, and directly
affected tests. The FE008 assessment domain/data/application implementation
must remain unchanged unless a minimal presentation-only composition import/
slot adjustment is strictly required; stop on any need to change its contract.

Inspect/reuse but otherwise preserve:

```text
frontend/lib/app/router/**
frontend/lib/core/network/**
frontend/lib/features/auth/**
frontend/lib/features/platform_admin/**
frontend/lib/features/institution_admin dashboard/profile/users code
frontend/lib/features/institution_admin assessment domain/data/application code
frontend/pubspec.yaml
frontend/pubspec.lock
frontend/integration_test/**
backend/**
docs/01–09
docker/**
```

No package, generated plugin, API client/interceptor/token-store rewrite,
global cache/event bus, generic CRUD framework, new route, shell redesign,
backend/doc/schema change, or result engine is allowed.

## 14. Authoritative References

Read each selected authority completely before implementation:

1. root `AGENTS.md` and `frontend/AGENTS.md`;
2. this detailed task and paired prompt;
3. `tasks/README.md` and `tasks/STAGE_03_TASK_INDEX.md`;
4. accepted S03-INT-001 contract/control task;
5. delivered S03-BE-007 task, implementation, tests, review, and delivery
   evidence;
6. delivered S03-FE-001 and S03-FE-008 plus relevant Stage 1/frontend
   predecessor code/tests/contracts;
7. docs 01/03 product/category meaning;
8. docs 02/04 Institution Admin authority and Settings flow;
9. docs 05 BR-CAT-001–016 plus tenant/settings/history rules;
10. docs 06 Stage 3 scope and later-stage exclusions;
11. docs 07 Flutter layering, session isolation, API client, mutation safety,
    accessibility, and testing;
12. docs 08 Section 8.2 and category snapshot/history rules;
13. docs 09 Sections 1–3, Section 26, and error registry;
14. accepted frontend mutation patterns only as structural references, never as
    authority for another envelope or false reconciliation success.

Locked docs and delivered backend/predecessor contracts outrank implementation
convenience. Stop and report any material conflict.

## 15. Acceptance Criteria

- [ ] Phase 0 proves S03-FE-008 and S03-BE-007 independently
      `Accepted / PASS / Delivered` on current `origin/main`.
- [ ] Exact FE001 route/title/navigation/guards and FE008 Settings composition/
      Assessment section remain intact; only category placeholder is replaced.
- [ ] Category and Assessment loads/drafts/errors/Refresh/mutations/stale state
      remain independently truthful, with only global auth invalidation shared.
- [ ] GET uses exact path, zero body, no query/tenant input, configured Dio, and
      one current-session category request generation.
- [ ] Exact unconfigured `data=[] + meta.configured=false` envelope and exact
      configured only-`data` envelope are distinguished strictly.
- [ ] Configured parsing enforces exact five canonical items, keys, fixed codes/
      labels/order, strict integer/null types, complete partition, and no private
      or additional fields.
- [ ] Unconfigured editor builds only empty fixed rows and invents no numeric
      defaults or configured state.
- [ ] Only eight first-four min/max inputs are editable; codes/labels/order and
      `not_completed` null/null are immutable.
- [ ] Integer lexical/value validation, min/max, endpoints, adjacency, no-gap/
      overlap, high-to-low order, and exact `0..100` coverage are enforced.
- [ ] Cancel, Reset, dirty category Refresh confirmation, configured no-change,
      one category PUT, and duplicate protection have exact request counts.
- [ ] PUT sends exactly root `categories` plus five canonical exact-four-key
      objects with no query/tenant/idempotency/private/label/assessment fields.
- [ ] Only exact direct PUT 200 + strict matching configured collection confirms
      success; backend message/meta is neither expected nor invented.
- [ ] PUT start marks only category state stale; direct success replaces only
      category state and performs no unrelated invalidation.
- [ ] Transport/5xx/unexpected/malformed/mismatched outcomes never claim causal
      success/failure and never replay PUT.
- [ ] At most one category GET publishes only current configured/unconfigured
      state; exact match remains explicitly unconfirmed.
- [ ] Exact 401/actor-state/403/422/429/read error/unprovable PUT behavior is
      session-safe and never exposes raw/private data.
- [ ] Logout/account/Institution/role/route/disposal/new-generation rejects all
      stale category data/draft/completion/feedback/stale-marker authority.
- [ ] Integer category-score rounding and `not_completed`/history explanations
      are accurate without implementing result behavior.
- [ ] Compact/wide, text scale, keyboard, focus, semantics, coverage/error,
      progress, configured/unconfigured, and unconfirmed states are accessible.
- [ ] Focused/full frontend regressions and Windows debug build pass.
- [ ] Phase 2 is strictly read-only and delivery/bookkeeping occurs only after
      PASS with zero unresolved P1/P2.

## 16. Tests and Verification

### 16.1 Domain, DTO, and request tests

Test at minimum:

- exact unconfigured envelope and every missing/extra/wrong-type/meta variant;
- configured envelope with only data and rejection of any meta/message/links;
- exact five item key sets independent of object key order, but exact canonical
  array order;
- every wrong/missing/extra/private item/root key, fixed label/code/order
  mismatch, duplicate/missing/unknown code, partial/wrong-count collection;
- strict integer versus float/string/bool/null types and `not_completed` shape;
- valid boundary/single-point/wide partitions and arbitrary valid range values;
- first max not 100, last min not 0, min>max, gap, overlap, reversal,
  out-of-range, adjacency, and incomplete coverage failures;
- pure client validator performs no I/O and invents no defaults;
- integer text grammar for 0, 100 and representative values plus empty, leading
  zero, sign, whitespace, decimal, comma, exponent, locale digit, and >100;
- GET exact method/path and absence of Dio data/query/tenant/retry;
- PUT exact method/path/content type/root/array/item keys/canonical order and
  actual JSON integer/null types;
- no label/meta/configured/ID/Institution/updater/timestamp/result/assessment
  field can serialize.

### 16.2 Controller and outcome tests

Test at minimum:

- one category initial GET despite page rebuilds; latest Retry/Refresh wins;
- unconfigured empty draft, configured draft, and no default invention;
- Cancel/Reset/no-change/dirty category Refresh confirm/cancel request counts;
- local row/set validation, exact complete snapshot, one PUT, rapid duplicate;
- exact direct success envelope/set/value checks and local success copy;
- exact 401/actor-state/403/422/429 classification and field/set/protocol mapping;
- transport/send/receive/transform/cancel, 5xx, unexpected 2xx/status, malformed
  and mismatched 200 all enter unprovable state;
- unprovable outcome issues zero or one category GET, never two, never an
  Assessment GET, and never another PUT;
- reconciliation configured-equal/configured-different/unconfigured/malformed/
  error/401/stale cases use current-state-only wording and never success;
- category stale marker starts at PUT, survives same-session route disposal,
  clears on exact current read/direct success, and never crosses sessions;
- logout, bootstrap, same-role/cross-role account switch, Institution change,
  route exit, disposal, and newer operation reject stale completion/feedback.

### 16.3 Independence, widget, accessibility, and regression tests

Test at minimum:

- exact Settings route/title/selection/direct entry/shell guards remain;
- FE009 placeholder is gone and real category section appears without a new
  route/scaffold;
- category initial load/error/Retry/Refresh never removes confirmed/dirty/
  submitting/unconfirmed Assessment state;
- Assessment load/error/Refresh/mutation never removes category confirmed/
  dirty/submitting/unconfirmed state;
- independent per-section PUT busy/duplicate controls and separate stale hooks;
- global 401/logout correctly clears both protected sections;
- category loading/error/unconfigured/configured/edit/validation/direct-success/
  unconfirmed/read-only `not_completed` states;
- exactly eight editable fields and no editable code/label/order/not_completed/
  tenant/assessment control;
- coverage summary, category-score rounding, missing-work/history explanation;
- configured no-change, Cancel, Reset, dirty Refresh, progress, duplicate, and
  safe route exit;
- direct success and equal reconciliation wording are visibly/semantically
  distinct;
- `800 × 600`, `1440 × 900`, text scale 2.0, long labels/errors, shared page
  scrolling, pointer, keyboard, visible focus, semantics, live announcements,
  and non-color meaning;
- full auth/router/shell/dashboard/profile/User/Assessment and Platform
  regressions.

### 16.4 Required commands

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

Run focused FE008/route/session regressions resolved in Phase 0. Also run
non-writing Git scope/diff checks, `git diff --check`, repository-convention
secret/credential scans, and byte comparison proving the paired prompt stayed
unchanged before Phase 3.

Any required failure blocks acceptance. Do not omit a failed command or call a
command PASS when it did not run.

### 16.5 Controlled real-stack smoke

Using non-recorded controlled Institution Admin credentials on the real
Windows/Laravel/PostgreSQL stack when available:

1. Load exact unconfigured categories and verify empty inputs/no defaults while
   Assessment remains usable.
2. Enter/save one valid partition, reload, and verify canonical exact values.
3. Cancel, Reset, submit no changes, cancel dirty category Refresh, and verify
   exact category/assessment request counts.
4. Submit local-invalid and controlled server-invalid gap/overlap/type/protected
   cases; verify no partial change and safe row/set errors.
5. Save a different valid complete partition and verify full replacement;
   no Assessment value/draft is changed.
6. Use another Institution Admin and another Institution to verify session/
   tenant isolation and current complete state.
7. Safely induce/simulate a lost PUT response; prove zero replay and that the
   single category GET never says this PUT succeeded, even on exact match.
8. Verify corrupt/invariant safe error when controlled setup permits; no repair
   or default appears.
9. Verify logout/account switch/route exit, compact/wide layout, text scale,
   keyboard, focus, and shared page scrolling.
10. Verify existing result/category snapshots and unrelated rows remain
    unchanged beyond accepted backend behavior.

If the controlled stack is available, smoke must PASS. A smoke FAIL blocks
acceptance. `NOT RUN` is non-blocking only when the environment is genuinely
unavailable, the exact reason is reported, and equivalent automated contract/
session/atomicity/no-replay/independence evidence passes. Never use `NOT RUN` to
hide an implementation or startup failure.

## 17. Required Workflow and Delivery

Branch:

```text
task/s03-fe-009-understanding-categories
```

### Phase 0 — Read-Only Git and Authority Preflight

1. Read the paired prompt and this detailed task completely.
2. Read root/frontend `AGENTS.md`, task index/README, S03-INT-001, delivered
   BE007/FE001/FE008 authority, referenced locked docs, and current relevant
   implementation/tests.
3. Verify this task is `Approved` and record the paired prompt SHA-256.
4. Verify expected GitHub origin and fetch safely.
5. Prove clean local `main == origin/main`.
6. Prove S03-BE-007 and S03-FE-008 independently
   `Accepted / PASS / Delivered` on that current main.
7. Prove delivered Settings composition/category placeholder, Assessment
   independence seam, session/client/stale/test contracts agree with this task.
8. Verify the tree is clean except only owner-prepared FE009 task/prompt if not
   yet committed; preserve unrelated user work.
9. Resolve exact category/composition/test files and predecessor regressions.
10. Only after every gate passes, create/switch from approved current main to
    the exact task branch.
11. Do not commit, push, open a PR, merge, or mark Accepted before Phase 2 PASS.

If either direct dependency is missing, return `FINAL STATUS: BLOCKED`. Do not
start implementation or repair BE007/FE008 scope inside FE009.

### Phase 1 — Implementation

Implement only this task and the narrow files allowed by Section 13.

During Phase 1:

- change only the FE009 row in `tasks/STAGE_03_TASK_INDEX.md` to
  `In Progress / Not started / Not started`;
- keep this task status `Approved`;
- preserve the paired prompt byte-for-byte;
- run all Section 16 checks and controlled smoke rule;
- inspect the complete diff including owner-prepared task/prompt;
- do not commit or push.

### Phase 2 — Strictly Read-Only Acceptance Gate

Re-read all authority and inspect the complete implementation/diff plus exact
route/composition/eligibility/session/fixed-model/envelopes/types/editor/
integer/set/PUT/direct-success/no-replay/reconciliation/errors/section-
independence/stale/history/accessibility/test/build/smoke/scope/secret/
bookkeeping evidence.

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
- `P2`: material API/envelope/model/type/integer/set/editor/state/error/direct-
  success/reconciliation/section-independence/accessibility/test/workflow
  mismatch, false success, mutation replay, regression, or scope drift;
- `P3`: non-blocking observation with no correctness, security, required
  evidence, or maintainability-acceptance impact.

Any unresolved P1 or P2 returns:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start S03-INT-002. Report every P3; P3 alone
does not block acceptance.

### Phase 3 — Post-Acceptance Git Delivery

Only after Phase 2 PASS with no unresolved P1/P2:

1. Change only this task metadata status from `Approved` to `Accepted`; do not
   rewrite approved behavior.
2. Prepare only the FE009 Stage 3 index row as
   `Accepted / PASS / Delivered` in the delivery commit.
3. Update `tasks/README.md` truthfully: Stage 3 remains `In Progress`, FE009 is
   delivered, and S03-INT-002 is the next implementation gate.
4. Preserve S03-INT-002 truthful status and keep Stage 4 blocked.
5. Prove the paired prompt is byte-for-byte unchanged from Phase 0.
6. Re-run final non-writing diff, scope, secret, and consistency checks.
7. Stage only approved FE009 implementation/tests, this task, its unchanged
   prompt, `tasks/STAGE_03_TASK_INDEX.md`, and `tasks/README.md`.
8. Commit exactly:

   ```text
   feat(institution): add understanding category editor

   Task: S03-FE-009
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

## 18. Explicit Non-Goals

- Custom category code/name/label/color/icon/order/count or decimal ranges.
- Editable `not_completed`, numeric Not completed band, or default/recommended
  range seeding.
- Partial category PATCH, delete/create/reorder UI, bulk import/export, ETag/
  version merge, settings history, or cross-Institution selector.
- Topic result calculation, category-score derivation, category assignment,
  recalculation, release, visibility, snapshot creation, or history rewrite.
- Implementing `409 category_configuration_invalid` in later dependent flows.
- Assessment settings contract/data/application/UI changes beyond the narrow
  FE008 presentation composition seam.
- Dashboard/Profile/User invalidation or changes.
- Groups, relationships, reports, learning content, Teacher/Student/Parent
  product UI, mobile Institution Admin, or web Institution Admin.
- Optimistic save, polling, offline write, mutation retry/replay, queue, or
  `Idempotency-Key`.
- Backend, database, schema, locked docs, package/lockfile, core network/auth,
  Platform feature, router, shell redesign, CI, or deployment.
- S03-INT-002 implementation, Stage 3 closure, or Stage 4 start.

## 19. Stop Conditions

Stop and report without widening scope if:

- S03-FE-008 or S03-BE-007 is not Accepted/PASS/Delivered;
- delivered FE008 composition/Assessment state or BE007 API differs materially
  from this task;
- exact configured/unconfigured envelope or strict integer/set contract cannot
  be represented safely;
- session/Institution/generation isolation, independent section state,
  category-only stale marker, or duplicate prevention cannot be proved;
- reconciliation would need to claim mutation success/causation;
- category work requires assessment domain/data/application changes, new route,
  package/core rewrite, backend/schema/docs, result/history, or later scope;
- unrelated user work or unsafe Git state exists;
- any required test/build/check/smoke fails;
- Phase 2 finds an unresolved P1/P2.

## 20. Required Codex Final Report

Report:

- final status;
- Phase 0 origin/main/branch/dependency/clean/prompt-hash evidence;
- every changed file and responsibility;
- exact route/Settings composition/session eligibility and FE008 preservation;
- exact GET request and configured/unconfigured envelope/type/set proof;
- fixed category model, empty unconfigured draft, integer grammar, complete
  partition, coverage, `not_completed`, and no-default proof;
- Cancel/Reset/no-change/dirty Refresh/duplicate request counts;
- exact canonical PUT and direct-200-only success proof;
- all unprovable cases, category-stale behavior, at-most-one GET/current-state-
  only wording, and zero replay proof;
- 401/actor-state/403/422/429/GET error/PUT 5xx behavior;
- category/Assessment state independence and logout/account/Institution/role/
  route/disposal/new-generation evidence;
- category-score/Not completed/history/non-disclosure evidence;
- accessibility/responsive/shared-scroll evidence;
- every command and exact result, build, smoke, regressions, scope/secrets;
- P1/P2/P3 findings;
- task/index/README/prompt-byte bookkeeping;
- commit, PR, merge, final local/remote equality, and clean tree.

State explicitly:

```text
No custom/default/decimal category, editable Not completed, result calculation/
assignment/recalculation/release/history, Assessment contract, Dashboard/Profile/
User, backend/schema, mobile-admin, web, Group/relationship/report/learning,
S03-INT-002, closure, or Stage 4 behavior was implemented.
Next implementation gate: S03-INT-002.
```
