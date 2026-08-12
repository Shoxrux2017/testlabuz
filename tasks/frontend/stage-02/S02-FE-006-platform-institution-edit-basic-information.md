# Codex Task: Platform Institution Basic-Information Edit Flow

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-FE-006` |
| Status | `Accepted` |
| Approved on | `2026-08-10` |
| Stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Frontend / Platform Owner Institution editing` |
| Priority | `High` |
| Depends on | `S02-FE-005` accepted, delivered, and present on current `origin/main`; accepted `S02-BE-003` Institution update API |
| Sequence next | `S02-FE-007` |
| Repository | `https://github.com/Shoxrux2017/testlabuz.git` |
| Target branch | `task/s02-fe-006-edit-institution` |
| Execution model | One focused implementation task followed by read-only acceptance and safe GitHub delivery |

---

## 2. Goal

Add the real Platform Owner Edit Institution experience backed by:

```text
GET   /api/v1/platform/institutions/{institution}
PATCH /api/v1/platform/institutions/{institution}
```

The accepted result must let an eligible desktop `platform_owner`:

- start editing from the accepted Institution detail screen;
- open the same protected edit flow through a direct URL;
- load the current server-authoritative basic profile before editing;
- edit only the six backend-approved basic-profile fields;
- understand that Institution status is visible context but is not editable in
  this form;
- submit only fields whose normalized values changed;
- clear nullable fields explicitly with JSON `null`;
- receive field-level backend validation safely;
- avoid an empty PATCH when nothing changed;
- prevent duplicate in-flight submissions;
- return to refreshed Institution detail after a confirmed `200`;
- preserve accepted shell, dashboard, list, detail, create, identity, logout,
  auth/password/role/device guards, and account isolation.

The frontend is not authoritative for Institution identity, lifecycle, actor,
settings, user counts, timestamps, tenant data, or persistence. The accepted
backend validates the allowlist and returns the complete current public basic
profile.

This task implements only basic-information editing. It must not implement
activate/deactivate (`S02-FE-007`), Institution Admin management
(`S02-FE-008`–`S02-FE-009`), or Stage-wide E2E closure (`S02-INT-001`).

### Scope boundary

This task owns only:

- one protected edit route:

  ```text
  /platform-owner/institutions/:institutionId/edit
  ```

- one accessible `Edit basic information` affordance on the accepted
  Institution detail screen;
- current-profile loading through the accepted detail endpoint;
- exactly six editable fields:

  ```text
  name
  type
  contact_email
  contact_phone
  address
  description
  ```

- typed edit form, patch request, mutation result, field-error, and view state;
- normalized dirty comparison and changed-fields-only serialization;
- loading, data, not-found, load-error, submitting, validation-error,
  definite-failure, ambiguous-outcome, no-change, and confirmed-success states;
- safe current-session invalidation of detail, list, and dashboard data after
  confirmed success;
- stale request/session/account completion protection;
- focused DTO, repository, controller, widget, router, regression,
  accessibility, and responsive-layout tests;
- truthful Windows desktop smoke verification against the accepted backend.

It does not:

- edit `status` or call activate/deactivate endpoints;
- edit settings, usage counts, Institution Admins, Users, roles, passwords, or
  learning data;
- add list-row editing, bulk edit, autosave, optimistic UI, local persistence,
  offline queue, or automatic retry;
- add `Idempotency-Key`, ETag, `If-Match`, versioning, or a client-side locking
  protocol absent from the accepted backend;
- send unchanged fields merely to construct a full object;
- change backend, database, Docker, CI, packages, lockfiles, or locked
  `docs/01–09`;
- implement `S02-FE-007+`.

---

## 3. Current Accepted Context

Treat current `origin/main` at execution time as implementation truth. This
preparation snapshot exists only to make the contract reviewable; Codex must
independently synchronize and inspect the repository.

Verified preparation baseline:

```text
origin/main Stage 1 closure commit:
b6c840a9dc935f6a9b2a87a63e5fc99352782ed8
```

At execution time, current `origin/main` must additionally contain:

- accepted and delivered `S02-BE-001` through `S02-BE-007`;
- accepted and delivered `S02-FE-001` through `S02-FE-005`;
- truthful Stage 2 index state for those completed tasks.

Accepted frontend foundations provide:

- Flutter, Riverpod, GoRouter, Dio, and secure token storage;
- one configured authenticated API client and typed envelope/failure mapping;
- `/api/v1/auth/me`-restored session authority;
- global `401`, account, and first-login password reconciliation;
- desktop Platform Owner role/device guards and persistent shell;
- Platform dashboard, Institution list, detail route, and create flow;
- typed Institution/status/type models and feature-first
  `features/platform_admin/` conventions;
- account-switch, provider invalidation, request de-duplication, and stale
  session isolation patterns.

Accepted backend `S02-BE-003` provides:

```text
PATCH /api/v1/platform/institutions/{institution}
```

It accepts a non-empty JSON object containing only changed allowed fields,
preserves omitted fields, treats explicit `null` as clearing only nullable
fields, rejects unknown/protected keys, returns exact `200` data/message, and
does not require an `Idempotency-Key`, ETag, or optimistic-lock version.

---

## 4. Dependency and Stage-Control Gate

Before implementation, prove from repository evidence:

1. Stage 1 is `Closed` and Stage DoD is `PASS`.
2. `S02-BE-001` through `S02-BE-007` are `Accepted`, reviewed `PASS`,
   delivered, and present on current `origin/main`.
3. `S02-BE-003` exposes the exact update request/response/error contract in
   this task and its PostgreSQL-backed tests pass.
4. `S02-FE-001` is accepted/delivered and owns shell/navigation/guards.
5. `S02-FE-002` owns dashboard data and invalidation boundaries.
6. `S02-FE-003` owns Institution list/query data.
7. `S02-FE-004` owns Institution detail route/data/not-found behavior.
8. `S02-FE-005` is accepted/delivered and its create flow remains green.
9. `tasks/STAGE_02_TASK_INDEX.md` matches the approved 17-task decomposition.
10. This detailed task exists exactly at:

    ```text
    tasks/frontend/stage-02/S02-FE-006-platform-institution-edit-basic-information.md
    ```

11. Its status is `Approved`.
12. No conflicting edit implementation already exists.

If any dependency is missing, local `main` differs from `origin/main`, or
current evidence materially contradicts this contract, stop and return:

```text
FINAL STATUS: BLOCKED
```

Do not repair predecessor scope, recreate backend behavior, or absorb
`S02-FE-007+`.

This task may update only truthful `S02-FE-006` lifecycle state in the Stage 2
index. It must not create, approve, implement, or state-mutate a later task.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

Before editing:

1. Read root `AGENTS.md`, `frontend/AGENTS.md`, and every nearer instruction
   file completely.
2. Read `tasks/README.md`, `tasks/STAGE_02_TASK_INDEX.md`, and this complete
   task.
3. Read accepted `S02-BE-003` and `S02-FE-001` through `S02-FE-005` contracts
   and delivery evidence.
4. Read only the locked specification sections referenced in Section 12.
5. Inspect actual router, shell, Institution DTOs/repository/providers,
   detail/create screens, form primitives, session generation, API client,
   envelope/failure mapping, and tests.
6. Run:

   ```text
   git fetch origin
   git switch main
   git pull --ff-only origin main
   git status --short
   git rev-parse HEAD
   git rev-parse origin/main
   git remote -v
   ```

7. Confirm local `main == origin/main`, remote is the approved repository, and
   the only permitted worktree changes are these two approved preparation
   files:

   ```text
   tasks/frontend/stage-02/S02-FE-006-platform-institution-edit-basic-information.md
   tasks/frontend/stage-02/S02-FE-006-CODEX-PROMPT.md
   ```

   No other modified, staged, deleted, renamed, or untracked path is allowed.
   Neither preparation file may be committed on `main`.
8. Create/switch to exactly:

   ```text
   task/s02-fe-006-edit-institution
   ```

9. Carry the two approved files to the task branch if needed and prove
   committed `main` was unchanged.
10. Use repository-pinned Flutter/Dart tooling and lockfile.
11. Run relevant pre-existing frontend gates before material edits.
12. Do not commit, push, open a PR, merge, or mark accepted before the
    read-only acceptance gate passes.

Unrelated changes are a blocker. Preserve user work and never reset, discard,
overwrite, or destructively clean it.

### 5.2 Route, detail, and shell integration

Add exactly one protected nested route:

```text
/platform-owner/institutions/:institutionId/edit
```

Requirements:

- define it through accepted route constants/names and GoRouter structure;
- keep it inside the existing Platform Owner shell and guard family;
- keep `Institutions` selected in compact and wide navigation;
- add one obvious keyboard-accessible `Edit basic information` action to the
  accepted Institution detail page;
- do not add edit actions to list rows, Dashboard, sidebar, or create screen;
- preserve direct detail URL, static create route, Dashboard/list/create,
  identity, logout, password, role, device, and session behavior;
- direct edit URL must enforce guards before protected content becomes usable;
- `institutionId` must remain explicit when moving between detail and edit;
- malformed/unknown/inaccessible IDs must use the accepted privacy-safe
  `404 resource_not_found` behavior;
- provide explicit `Cancel` / `Back to institution` behavior;
- if form state is dirty, confirm destructive cancel/back/navigation through
  the accepted focused route/form mechanism; do not create a broad global
  interception framework in this task.

### 5.3 Current-profile loading and initialization

On each edit-route entry, obtain the current basic profile through:

```http
GET /api/v1/platform/institutions/{institutionId}
```

Rules:

- reuse the accepted detail repository/data-source/DTO boundary;
- issue at most one equivalent initial request for one controller generation;
- ordinary rebuilds must not duplicate the request;
- do not make the PATCH request until loading succeeds and the user explicitly
  saves valid changed data;
- initialize the six fields from the typed server resource;
- retain an immutable normalized initial snapshot for dirty comparison;
- show current status only as truthful read-only context outside editable form
  controls; direct status changes belong to `S02-FE-007`;
- do not prefill from list-row data as sole authority;
- do not initialize from another Institution, another session, a static
  singleton, persisted form values, or stale cross-account cache;
- discard late load results after route disposal, logout, account/session
  change, or a newer controller generation.

Required initial states:

```text
loading
data/form ready
resource not found
ordinary load error with Retry
auth/account/password reconciliation
```

Retry is allowed for the read-only GET only. One retry gesture creates one
replacement GET; concurrent equivalent GETs remain de-duplicated.

### 5.4 Exact editable fields and controls

Render exactly six editable fields:

```text
Institution name *
Institution type *
Contact email
Contact phone
Address
Description / notes
```

| UI field | Request key | UI behavior |
|---|---|---|
| Institution name | `name` | Required text; maximum 200; outer-trimmed for comparison/submission; whitespace-only invalid |
| Institution type | `type` | Required allowlisted selector; no arbitrary value |
| Contact email | `contact_email` | Optional email text; maximum 254; empty means `null` when changed from non-null |
| Contact phone | `contact_phone` | Optional text; maximum 50; do not impose E.164-only validation |
| Address | `address` | Optional multiline; do not invent undocumented business maximum |
| Description / notes | `description` | Optional multiline; do not invent undocumented business maximum |

The exact Institution type allowlist is:

```text
school
college
lyceum
university
institute
learning_center
training_center
private_education
other
```

Control rules:

- use typed wire values and clear human labels;
- preserve current valid type selection on initialization;
- do not silently coerce an unknown server enum into `other`; treat it as a
  safe contract/load failure;
- render the current active/inactive status only as a read-only badge/text
  outside the form, with a short explanation that lifecycle is managed
  separately;
- do not render a disabled status selector that looks editable;
- no hidden, advanced, settings, counts, actor, ID, timestamp, Admin, billing,
  plan, license, or learning fields;
- use real labels, required/error semantics, logical focus order, keyboard
  operation, and error associations; placeholder text is not a label;
- preserve Unicode and meaningful multiline content and render safe text only;
- use accepted form/theme primitives where they fit.

### 5.5 Normalization, dirty comparison, and client validation

Create one explicit normalized comparison representation for the initial and
current six-field values.

Normalization:

- `name`: trim outer whitespace; preserve meaningful internal Unicode text;
- `type`: exact typed wire value;
- `contact_email` and `contact_phone`: trim outer whitespace; whitespace-only
  becomes `null`;
- `address` and `description`: whitespace-only becomes `null`; otherwise
  preserve meaningful multiline content and do not collapse/rewrite it;
- do not transliterate, title-case, HTML-transform, or invent uniqueness rules.

Dirty/request rules:

- compare every normalized current value with the normalized initial value;
- a field belongs in PATCH only when its normalized value changed;
- clearing a previously non-null nullable value sends that key as JSON `null`;
- a nullable field that starts and remains null/blank is omitted;
- unchanged `name` and `type` are omitted;
- if no normalized field changed, do not call the API; disable/restrict Save
  and provide accessible `No changes to save` feedback when invoked;
- reverting every edit to its normalized initial value returns to no-change
  state;
- dirty navigation uses the same normalized comparison, not raw controller
  whitespace.

Client validation before PATCH:

- changed/current name must remain non-empty and at most 200 characters;
- type must remain one exact accepted value;
- non-null email must pass accepted email validation aligned with backend and
  be at most 254 characters;
- non-null phone must be a string of at most 50 characters;
- invalid form state issues no request and focuses/announces first invalid
  field through accepted accessibility patterns.

Backend `422 validation_failed` remains authoritative. Map errors for all six
approved keys to fields. Unknown/global validation entries must be shown safely
at form level. Editing one field clears only that field's stale server error.

### 5.6 Exact PATCH request contract

Issue only:

```http
PATCH /api/v1/platform/institutions/{institutionId}
Accept: application/json
Content-Type: application/json
Authorization: Bearer <managed by accepted API client>
```

Example changed-fields request:

```json
{
  "name": "Updated Name",
  "contact_email": "updated@example.uz",
  "description": null
}
```

The request object must be non-empty and may contain only:

```text
name
type
contact_email
contact_phone
address
description
```

Never send:

```text
id
institution_id
status
created_by_user_id
deactivated_at
created_at
updated_at
settings
timezone
learning_material_max_mb
student_submission_max_mb
acceptable_score_difference
blitz_timer_start_mode
student_result_release_mode
parent_result_release_mode
role
users
user_counts
```

Further requirements:

- no query parameters or multipart body;
- no full-resource PUT semantics;
- no client-generated UUID or authority headers;
- no `Idempotency-Key`, ETag, `If-Match`, version, or hidden concurrency token;
- no raw URL/body construction or Dio call in widgets;
- one explicit valid Save gesture creates at most one in-flight PATCH;
- duplicate button/keyboard/double-click/rebuild triggers are blocked;
- no automatic retry at client, repository, controller, or widget level;
- no preliminary uniqueness or status request;
- editing an inactive Institution is allowed, but PATCH must not activate it.

### 5.7 Mutation state and concurrency behavior

Use one typed, session-owned mutation state capable of distinguishing:

```text
ready/unchanged
ready/dirty
submitting
validation failure
definite ordinary failure
ambiguous outcome
confirmed success
```

Rules:

- ordinary rebuilds do not submit, reset, or duplicate loading;
- controls remain visible while submitting; duplicate Save is prevented and
  progress is bounded;
- do not clear the form on validation or definite failure;
- do not optimistically replace list/detail/dashboard data;
- backend has no version/ETag contract; do not invent client conflict
  detection or claim prevention of concurrent last-write behavior;
- changed-fields-only PATCH reduces accidental overwriting of untouched
  fields but is not an optimistic lock;
- discard/ignore stale completion after logout, account/session change, route
  disposal, or newer controller generation;
- stale completion must not navigate, show success, or invalidate another
  session's data;
- no autosave, draft storage, local database, secure-storage form state, or
  cross-session restoration.

### 5.8 Exact success response and typed mapping

Require HTTP `200 OK` and consume:

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Updated Name",
    "type": "school",
    "status": "active",
    "contact_email": "updated@example.uz",
    "contact_phone": "+998...",
    "address": "Updated address",
    "description": null,
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-10T12:00:00Z"
  },
  "message": "Institution updated successfully."
}
```

Typed decoding must require:

- non-empty string `id` and `name`;
- response `id` exactly matching the requested Institution ID;
- one of all nine accepted type values;
- `status = active | inactive`;
- nullable strings for contact/address/description fields;
- valid required RFC3339 `created_at` and `updated_at`;
- exact non-empty success `message` from the envelope.

The response is the complete current public basic profile, not a changed-field
fragment. Ignore additive unknown fields without modeling/rendering protected
data. Reject missing/null/wrong-type/unknown-enum/invalid-time/mismatched-ID
core data as safe contract failure.

A `2xx` response other than exact `200`, or `200` that cannot be safely decoded,
is not confirmed success. Do not parse message text to decide business logic;
valid `200` plus typed data is the authority and message is feedback only.

### 5.9 Confirmed-success invalidation and navigation

Only after current-session exact `200` parsing:

1. prevent any second success transition;
2. mark the edited Institution detail data stale for current session;
3. mark Institution list data stale for current session;
4. mark Platform dashboard data stale for current session;
5. do not issue hidden immediate requests for inactive screens;
6. navigate once to canonical
   `/platform-owner/institutions/{returnedInstitutionId}`;
7. let the now-active accepted detail screen refetch from backend;
8. show one safe success feedback using the accepted message;
9. clear edit-form mutation/error/dirty ownership.

Do not locally patch cached detail/list/dashboard records, reorder/filter/page
rows, or derive counters. A renamed Institution may move or disappear under
the current list query/sort; the frontend must not claim otherwise.

### 5.10 Failure and ambiguous-outcome behavior

Handle failures through accepted typed boundaries:

| Case | Required frontend behavior |
|---|---|
| `401 authentication_required` | Clear protected form/data through accepted session invalidation and route to auth |
| `403 user_inactive` | Reconcile through accepted global account flow; no form success |
| `403 institution_inactive` | Reconcile through accepted global Institution/account flow; no form success |
| `403 password_change_required` | Reconcile to approved password-change flow |
| `403 forbidden` | Safe access-denied behavior; no cross-account state |
| `404 resource_not_found` on GET | Privacy-safe not-found state with Back to Institutions |
| `404 resource_not_found` on PATCH | Stop editing as missing/inaccessible; no success/invalidation |
| `422 validation_failed` | Map six approved keys plus safe form fallback; preserve current values |
| Definite `500 server_error` | Safe failure; no success/navigation/invalidation; preserve values |
| Other definite HTTP failure | Safe form-level failure; no raw body/stack/SQL details |
| PATCH timeout/disconnect after transmission | `Update outcome unknown`; no automatic/one-click repeat |
| `200` with invalid/mismatched response | Outcome unknown because server may have committed |

For an ambiguous PATCH outcome:

- preserve current form values only in the current in-memory session;
- explain that the update may have completed;
- provide `Check institution` to leave edit mode and load canonical detail;
- do not silently resend or offer a one-click mutation retry;
- do not infer success from local form values;
- do not introduce an idempotency or version protocol.

For definite correctable validation/failure responses, the user may explicitly
save again after review/correction. One gesture still equals one request.

### 5.11 Session and account isolation

Load/form/mutation state belongs to authenticated session generation plus
Institution ID.

On logout, invalid-token reconciliation, role/password/device redirect,
account change, or target-route change:

- remove loaded Institution data, fields, initial snapshot, validation errors,
  failure/success/unknown state, and pending navigation ownership;
- cancel requests where supported and ignore every late completion;
- do not display or invalidate data for the previous account/Institution;
- do not persist form values in global singleton, static storage, token store,
  disk cache, or cross-account provider;
- do not allow Platform Owner A's pending edit to appear for Platform Owner B
  or any other role.

Changing directly from Institution A edit URL to Institution B must clear A's
form and initialize only from B's authorized server response.

### 5.12 Architecture and code organization

Follow accepted feature-first layers:

```text
Edit screen/form
  ↓
Edit controller/notifier
  ↓
Platform Institution repository
  ↓
Platform Institution remote data source
  ↓
Accepted configured Dio client
```

Requirements:

- widgets contain no raw Dio, envelope parsing, arbitrary JSON maps, or
  authorization decisions;
- PATCH serialization is typed, changed-fields-only, and allowlisted;
- reuse accepted detail DTO/domain model when it preserves exact contracts;
- reuse accepted type labels, form primitives, failure mapping, session,
  router, shell, and provider patterns;
- do not duplicate API client/token interceptor/session/router/shell;
- do not create a giant create/edit/lifecycle/Admin controller;
- reuse a genuinely shared six-field form section from create only if it keeps
  create's separate seven-field/request semantics explicit and tests clear;
- use provider overrides/dependency injection in tests; no production fake
  delay, route, response, or environment switch;
- logs must not contain bearer tokens, full request/response bodies, contact
  data, form contents, or secrets.

### 5.13 Expected file surface

Derive exact paths from accepted `origin/main`. A focused change may touch:

```text
frontend/lib/app/router/...
frontend/lib/features/platform_admin/data/...
frontend/lib/features/platform_admin/domain/...
frontend/lib/features/platform_admin/application/...
frontend/lib/features/platform_admin/presentation/institutions/...
frontend/test/features/platform_admin/...
frontend/test/router_... or accepted router test location
tasks/frontend/stage-02/S02-FE-006-...
tasks/STAGE_02_TASK_INDEX.md
```

Do not pre-create every suggested file. Any backend, database, Docker, docs,
CI, package, or lockfile change is outside scope and a blocker.

---

## 6. Required Automated Tests

### 6.1 Load and initialization

- [ ] Direct edit route issues one accepted detail GET per controller generation.
- [ ] Ordinary rebuilds do not duplicate GET.
- [ ] Exact six fields initialize from typed server data.
- [ ] Current status is read-only context and no status form control exists.
- [ ] List-row data is not sole edit authority.
- [ ] Loading, not-found, ordinary error/Retry, and ready states render safely.
- [ ] GET Retry creates one request and concurrent duplicates are blocked.
- [ ] Unknown type/malformed detail response becomes safe contract failure.
- [ ] Institution A state cannot initialize Institution B.

### 6.2 Dirty comparison and request serialization

- [ ] Initial normalized form is unchanged and Save issues no PATCH.
- [ ] Each allowed field changed alone serializes exactly that one key.
- [ ] Multiple changed fields serialize together.
- [ ] Reverted fields are omitted.
- [ ] Clearing each nullable non-null field serializes explicit `null`.
- [ ] Initially null fields left blank are omitted.
- [ ] Name/contact outer whitespace follows exact normalization.
- [ ] Meaningful Unicode/internal/multiline content is preserved.
- [ ] Empty/invalid name, invalid type/email, and overlong fields issue no request.
- [ ] Request never contains status/protected/settings/count/timestamp fields.
- [ ] Request is PATCH to exact ID with no query, idempotency, ETag, or version header.

### 6.3 Response and repository behavior

- [ ] Exact `200` complete resource/message maps through typed boundaries.
- [ ] All nine types and both returned statuses map correctly.
- [ ] Nullable values and RFC3339 timestamps map correctly.
- [ ] Mismatched returned/requested ID is rejected.
- [ ] Missing/wrong/null/unknown core fields are rejected safely.
- [ ] Non-`200` `2xx` is not confirmed success.
- [ ] Additive unknown fields do not expose protected data.
- [ ] `422` errors map to exact fields and safe form fallback.
- [ ] `401`, user/Institution/password, forbidden, not-found, and definite server failures map correctly.
- [ ] No automatic GET/PATCH retry exists except user-triggered read-only GET Retry.

### 6.4 Controller and mutation lifecycle

- [ ] One Save gesture creates one PATCH.
- [ ] Button, Enter, double-click, and rebuild cannot duplicate in-flight PATCH.
- [ ] Validation/definite failure preserves entered values and permits explicit corrected save.
- [ ] Timeout/disconnect and malformed `200` enter unknown outcome with no resend action.
- [ ] `Check institution` leaves edit flow without asserting success.
- [ ] Confirmed success invalidates current-session detail/list/dashboard once.
- [ ] Confirmed success navigates once to returned matching detail ID and shows feedback.
- [ ] No optimistic cache patch, row reorder, or local count/name mutation occurs.
- [ ] Logout/account/route/Institution change discards late load/PATCH completions.

### 6.5 Widget, route, accessibility, and regression

- [ ] Detail exposes exactly one accessible edit action.
- [ ] Edit route coexists with detail and static `new` route.
- [ ] Direct URL preserves auth/password/role/device guards.
- [ ] Institutions navigation remains selected.
- [ ] Six fields have labels, required/error semantics, focus order, and keyboard operation.
- [ ] Dirty cancel/back confirms; unchanged cancel/back does not.
- [ ] Status context is text-visible and not interactive/color-only.
- [ ] `800 × 600` and `1440 × 900` layouts scroll without overflow.
- [ ] Dashboard/list/detail/create/auth/logout regressions remain green.
- [ ] Wrong role/mobile surface cannot use the edit route.
- [ ] No lifecycle/Admin/later-task controls appear.

---

## 7. Quality and Verification Commands

From `frontend/`, use repository-pinned tooling:

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
flutter build windows --debug
flutter build apk --debug
```

Run focused edit tests first, then the full suite. Do not skip either build.

From repository root inspect complete staged, unstaged, and untracked scope:

```text
git status --short
git diff --check
git diff --stat
git diff
git diff --cached --check
git diff --cached --stat
git diff --cached
git ls-files --others --exclude-standard
git status --short -- backend docker docs frontend/pubspec.yaml frontend/pubspec.lock
git diff HEAD -- backend docker docs frontend/pubspec.yaml frontend/pubspec.lock
git diff --cached -- backend docker docs frontend/pubspec.yaml frontend/pubspec.lock
```

Open and review every untracked implementation file. Prove absence of:

- secret/token/contact/form/request-body logging;
- backend/docs/database/Docker/CI/package/lockfile drift;
- raw Dio or JSON maps in widgets;
- duplicate router/client/session/form architecture;
- wrong route, full-object PATCH, status/protected fields, empty PATCH;
- automatic PATCH retry, fake concurrency protection, optimistic cache mutation;
- stale Institution/session/account completion leaks;
- lifecycle/Admin/`S02-FE-007+` scope.

---

## 8. Manual Smoke Checklist

Use real Windows app, accepted Laravel/PostgreSQL runtime, and controlled
local/test data. Redact credentials, tokens, and contact data.

### Successful editing

1. Login as active, password-complete Platform Owner on Windows desktop.
2. Open active Institution detail and choose `Edit basic information`.
3. Confirm exact edit route, one current detail GET, six editable fields, and
   read-only status context.
4. Without changes, confirm Save performs no PATCH.
5. Change only name; prove one PATCH containing only `name` and exact `200`.
6. Confirm navigation to refreshed detail, success message, updated server
   value, and unchanged type/contact/address/description/status.
7. Edit multiple fields and clear contact/description; confirm changed keys
   only and explicit JSON nulls.
8. Edit an inactive Institution; confirm profile updates but status remains
   inactive and no lifecycle endpoint is called.
9. Verify list and Dashboard refetch from server when visited; confirm no local
   row/counter patching.
10. Confirm Unicode/multiline preservation and `800 × 600` / `1440 × 900`,
    scrolling, keyboard, focus, errors, and dirty-cancel behavior.

### Failure and isolation

1. Trigger controlled backend `422` for approved fields; confirm precise field
   mapping without raw JSON.
2. Trigger authorized `404` during load and after target removal before PATCH;
   confirm privacy-safe not-found behavior and no success.
3. Trigger definite controlled `500`; confirm values remain and no success,
   navigation, invalidation, or automatic retry.
4. Where safely reproducible, interrupt transport after PATCH and confirm
   `Update outcome unknown`, no resend action, and safe `Check institution`.
   Otherwise report `NOT RUN` with exact reason.
5. Under controlled latency, double-click/press Enter and prove one PATCH.
6. Logout/invalidate session while load or PATCH is pending; confirm late
   completion cannot render, navigate, or invalidate a new session.
7. Switch from Institution A edit URL to Institution B and between Platform
   Owner accounts; confirm no form/data/error leakage.
8. Confirm create, Dashboard, list, detail, auth/logout, guards, and routing
   remain correct and no lifecycle/Admin UI was added.

Report unavailable manual items as `NOT RUN` with exact reason. Never present a
mocked/widget-only check as real-stack smoke.

---

## 9. Acceptance Criteria

- [ ] Dependency/Git gate is proven.
- [ ] Work occurs only on `task/s02-fe-006-edit-institution`.
- [ ] Exact protected edit route and one detail affordance exist.
- [ ] Current profile loads once through accepted detail endpoint.
- [ ] Form has exactly six editable fields and status is read-only context.
- [ ] Normalized dirty comparison and changed-fields-only PATCH are exact.
- [ ] Empty PATCH is impossible and clearing nullable fields sends `null`.
- [ ] No status/protected/settings/count/lifecycle field is sent.
- [ ] Exact PATCH has no idempotency/version/ETag/automatic retry.
- [ ] One explicit gesture creates at most one in-flight PATCH.
- [ ] Exact `200` complete resource/message maps through typed boundaries.
- [ ] Returned ID must match requested ID.
- [ ] Load/mutation `404`, `422`, auth, definite failure, and ambiguous outcome
      are safe and tested.
- [ ] Confirmed success invalidates detail/list/dashboard once and returns to
      server-refreshed detail.
- [ ] No optimistic cache mutation or fake concurrency claim exists.
- [ ] Late route/Institution/session/account completion cannot leak or navigate.
- [ ] Accessibility, keyboard, dirty-cancel, and desktop layouts are tested.
- [ ] Shell/Dashboard/list/detail/create/auth/guard regressions remain green.
- [ ] No lifecycle/Admin/later-task behavior exists.
- [ ] No backend/docs/database/Docker/schema/dependency/CI change exists.
- [ ] Focused/full tests, analyze, format, Windows build, and APK build pass.
- [ ] Manual smoke is truthful and sensitive data is redacted.
- [ ] Phase 2 has zero unresolved P1/P2 findings.
- [ ] Final `ACCEPTED` occurs only after PR delivery, merge, and clean sync.

---

## 10. Explicit Non-Goals

- Activate/deactivate Institution UI (`S02-FE-007`).
- Institution Admin list/create (`S02-FE-008`).
- Institution Admin edit/lifecycle (`S02-FE-009`).
- Stage 2 full real-stack verification (`S02-INT-001`).
- Backend update implementation or contract changes.
- Editing status, settings, policies, timezone, limits, users, counts, roles,
  passwords, actor, ID, timestamps, or learning records.
- Edit from list rows, inline editing, bulk edit, clone, import, or wizard.
- Full-resource PUT, optimistic UI, local cache patching, or client counters.
- ETag, `If-Match`, version, locking, or custom conflict protocol.
- `Idempotency-Key`, automatic retry, background resend, offline queue,
  autosave, draft persistence, polling, or WebSocket.
- Mobile/web Platform Owner support.
- Localization/design-system overhaul.
- New packages or backend/database/Docker/docs/CI changes.

---

## 11. Relevant Business and Security Rules

1. Only active, password-complete desktop `platform_owner` may use the flow.
2. Backend auth, authorization, validation, and persistence are authoritative.
3. Platform Owner may edit only basic platform-level Institution information.
4. Institution status changes only through explicit lifecycle actions.
5. Editing inactive Institution basic information must not reactivate it.
6. Omitted PATCH fields remain unchanged; nullable fields clear only through
   explicit changed-key `null`.
7. Client must not send identity, actor, settings, counts, timestamps, Users,
   roles, or learning records.
8. Backend has no uniqueness, ETag, version, or idempotency contract here;
   frontend must not invent one.
9. Navigation visibility is not authorization.
10. Stale protected data must never cross account, session, role, device, or
    Institution boundaries.
11. Errors must branch on stable codes and never expose internal details.
12. Deactivation preserves historical data; this task does not alter lifecycle.

---

## 12. Authoritative References

| Source | Relevant sections | Required use |
|---|---|---|
| `docs/01-business-overview.md` | Multi-institution platform/MVP boundaries | Platform-level purpose and tenant safety |
| `docs/02-user-roles.md` | Platform Owner scope and desktop boundary | Who may edit and what remains prohibited |
| `docs/03-features.md` | Platform Owner features | Edit basic Institution information only |
| `docs/04-user-flows.md` | Platform Owner Institution management flow | Detail-to-edit intent and safe return |
| `docs/05-business-rules.md` | `BR-INST-013`–`021`, `BR-ROLE-007`–`009`, ACL rules | Lifecycle preservation, platform scope, isolation |
| `docs/06-roadmap.md` | Stage 2 included/excluded scope | Exact Stage ownership |
| `docs/07-architecture.md` | Flutter/API/security/state boundaries | Typed layered client and server authority |
| `docs/08-database.md` | Institutions/settings/users relationships | Protected fields/relations and no side effects |
| `docs/09-api-contracts.md` | `2`, `4`, `5`, `7.4`, `7.5`, `12.1`, `33`, `34` | Exact GET/PATCH, errors, security, no invented protocol |
| `AGENTS.md` and `frontend/AGENTS.md` | Applicable full rules | Workflow, typed states, duplicate prevention, delivery |
| accepted `S02-BE-003` | Complete update contract/evidence | Exact allowlist, PATCH semantics, response, errors |
| accepted `S02-FE-001`–`S02-FE-005` | Complete contracts/evidence | Shell, dashboard, list, detail, create, guards, isolation |
| `tasks/STAGE_02_TASK_INDEX.md` | `S02-FE-006` and successors | Exact sequence and non-goals |

Task-level route, changed-field serialization, dirty comparison, no-change,
ambiguity, invalidation, navigation, accessibility, and responsive details
narrow implementation ambiguity without changing locked behavior.

---

## 13. Stop Conditions

Stop with `FINAL STATUS: BLOCKED` if:

- Stage 1 or required Stage 2 predecessors are not accepted/delivered;
- `S02-BE-003` endpoint/allowlist/PATCH/response/error contract differs;
- accepted shell/detail/list/dashboard/create/session architecture is missing
  or conflicting;
- Stage 2 index is missing/conflicting;
- local `main` cannot synchronize or origin is unexpected;
- unrelated dirty work exists;
- safe implementation requires backend/docs/database/Docker/CI/package change,
  broad auth/router/network/shell redesign, or later-task scope;
- exact typed changed-fields PATCH, no-change behavior, failure safety, or
  session isolation cannot be preserved;
- a required pre-existing frontend gate fails materially;
- safe work requires destructive Git, force-push, bypass, secret exposure, or
  user-work overwrite.

During Phase 2, unresolved P1/P2 means:

```text
FINAL STATUS: NOT ACCEPTED
```

If Phase 2 passes but delivery cannot finish:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Do not start `S02-FE-007`.

---

## 14. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git preflight

Complete Section 5.1, create/switch to exact task branch, carry the two
approved files, and do not commit/push.

### Phase 1 — Implementation

Implement only `S02-FE-006`. Run focused/full tests, analyze, format, builds,
diff/scope/security review, and manual smoke. Do not commit, push, open a PR,
merge, or mark accepted.

### Phase 2 — Read-only acceptance gate

Re-read this task, instructions, referenced locked sections, predecessors, the
complete staged/unstaged/untracked change set, tests/builds/smoke, exact route,
load/form/request/response evidence, dirty/no-change behavior, failure/
ambiguity/duplicate behavior, invalidation/navigation, and session isolation.

During Phase 2 make no edits; do not auto-fix, format-write, generate, stage,
unstage, commit, push, open/merge a PR, or update lifecycle state.

Severity:

```text
P1 = auth/role/device/session/account-isolation/secret/protected-field issue
P2 = material API/form/state/retry/navigation/architecture/test/build/scope issue
P3 = non-blocking observation
```

PASS requires zero unresolved P1/P2 and complete trustworthy evidence.
Otherwise return `FINAL STATUS: NOT ACCEPTED`, stop, and do not self-fix after
Phase 2 begins.

### Phase 3 — Post-acceptance delivery

Only after Phase 2 PASS:

1. Set this detailed task to `Accepted`.
2. Update only truthful `S02-FE-006` index state to Accepted/review PASS;
   delivery finalizes only after merge.
3. Apply only required task lifecycle bookkeeping.
4. Re-run final tests, builds, diff/scope/package/secret checks.
5. Stage only approved implementation, tests, task, prompt, and truthful index
   files.
6. Commit:

   ```text
   feat(platform): add institution edit flow
   ```

   Body:

   ```text
   Task: S02-FE-006
   ```

7. Push `task/s02-fe-006-edit-institution` to approved origin.
8. Open a PR to `main`; do not bypass checks/protection.
9. Merge only when safe and green.
10. Fast-forward-sync local `main` and prove clean `main == origin/main`.

Only then return:

```text
FINAL STATUS: ACCEPTED
```

Do not create or start `S02-FE-007`.

---

## 15. Required Codex Final Report

Return:

1. Final status and dependency/Git commit evidence.
2. Changed-file summary and exact route/detail-affordance/load evidence.
3. Exact six-field form, read-only status, normalization, dirty/no-change, and
   validation evidence.
4. Exact changed-fields PATCH/no-protected-fields/no-idempotency/version and
   typed `200` evidence.
5. GET/PATCH failures, `422`, ambiguous outcome, duplicate prevention, and
   no-automatic-retry evidence.
6. Confirmed-success detail/list/dashboard invalidation, navigation, feedback,
   and server-refetch evidence.
7. Session/Institution/account/stale-completion isolation evidence.
8. No optimistic cache, lifecycle/Admin/settings/later-scope evidence.
9. Accessibility, keyboard, dirty-cancel, and responsive-layout evidence.
10. Focused/full test, analyze, format, Windows/APK build results.
11. Complete staged/unstaged/untracked diff, package, scope, and secret review.
12. Real manual smoke results with `PASS`/`FAIL`/`NOT RUN` per item.
13. Phase 2 findings by severity and acceptance decision.
14. Final branch, commit, PR, checks, merge, and clean synced-main evidence.

Do not create or start `S02-FE-007`.
