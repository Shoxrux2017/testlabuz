# Codex Task: Platform Institution Admin Update and Lifecycle UI

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-FE-009` |
| Status | `Accepted` |
| Review status | `PASS` |
| Delivery status | `Not started` |
| Approved on | `2026-08-10` |
| Stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Frontend / Platform Owner Institution Admin profile and lifecycle management` |
| Priority | `High` |
| Depends on | `S02-FE-008` accepted, delivered, and present on current `origin/main`; accepted `S02-BE-007` Institution Admin update/lifecycle API |
| Sequence next | `S02-INT-001` |
| Repository | `https://github.com/Shoxrux2017/testlabuz.git` |
| Target branch | `task/s02-fe-009-institution-admin-update-lifecycle` |
| Execution model | One focused implementation task followed by read-only acceptance and safe GitHub delivery |

---

## 2. Goal

Extend the accepted Institution Admin section inside the Platform Owner
Institution detail experience with safe profile-edit and account-lifecycle UI
backed only by:

```text
PATCH /api/v1/platform/institution-admins/{user}
POST  /api/v1/platform/institution-admins/{user}/activate
POST  /api/v1/platform/institution-admins/{user}/deactivate
```

The accepted result must let an eligible desktop `platform_owner`:

- start an action only from an Institution Admin row currently loaded for the
  open Institution;
- edit only `full_name`, `email`, and `phone` in an accessible dialog;
- clear optional contact values intentionally with JSON `null`;
- send only actually changed approved fields and avoid a PATCH when nothing
  changed;
- activate or deactivate the selected Institution Admin only after explicit
  confirmation;
- understand that account activation does not bypass an inactive Institution
  or an unfinished mandatory first-login password change;
- prevent duplicate or conflicting same-screen mutations while one Admin
  action is in flight;
- handle validation, scoped not-found, definite failure, and uncertain network
  outcomes without false success or an automatic duplicate mutation;
- reload backend-authoritative rows and affected counts after confirmed or
  safely reconciled success;
- clear selected Admin/action state on Institution, route, authentication, or
  session-generation change;
- preserve the accepted Platform Owner shell, dashboard, Institution list,
  Institution detail/create/edit/lifecycle, Admin list/create, logout, guards,
  and session isolation.

Laravel remains authoritative for actor authorization, target role and
Institution binding, profile allowlisting, account state, lifecycle timestamp,
first-login state, login eligibility, concurrency, persistence, and public
serialization. Flutter submits explicit user intent and presents current
server facts; it must not become a second account-lifecycle authority.

This task completes the Stage 2 frontend implementation slice. It does not
perform the Stage-wide real-stack verification or close Stage 2; that remains
the separate `S02-INT-001` task.

### Scope boundary

This task owns only:

- row-level Edit and state-appropriate Activate/Deactivate actions inside the
  accepted Institution Admin section at:

  ```text
  /platform-owner/institutions/:institutionId
  ```

- one accessible edit dialog using the selected row's accepted public
  Resource as its initial server snapshot;
- changed-fields-only PATCH mapping for `full_name`, `email`, and `phone`;
- separate explicit lifecycle-confirmation dialogs;
- body-less/empty-object lifecycle POST requests;
- typed parsing of the existing Institution Admin Resource and exact `200`
  success envelopes;
- in-flight action ownership, duplicate prevention, session/route isolation,
  and stale-completion rejection;
- backend refresh/invalidation after confirmed success;
- safe read-only reconciliation after an uncertain mutation outcome;
- focused data/application/presentation/accessibility/regression tests;
- truthful Windows desktop smoke verification against the accepted backend.

It does not:

- add an Institution Admin detail endpoint, route, page, drawer, sidebar item,
  or global selected-Admin state;
- edit `login_name`, role, Institution, password, account state inside the
  profile form, first-login state, creator, login metadata, or timestamps;
- reset/change/reveal/copy/resend/generate a password or credential;
- assign or replace an Institution Admin, change roles, or move an Admin to
  another Institution;
- delete, archive, suspend, lock, merge, impersonate, invite, or bulk-manage
  users;
- manage Teacher, Student, Parent, or Platform Owner accounts;
- mutate an Institution, settings, groups, relationships, learning content,
  submissions, scores, results, or reports;
- add local optimistic lifecycle/profile authority, polling, offline writes,
  automatic mutation retries, or `Idempotency-Key` behavior;
- change backend, database, Docker, packages, lockfiles, CI, or locked
  `docs/01–09`;
- implement or start `S02-INT-001`.

---

## 3. Current Accepted Context

Treat current `origin/main` at execution time as implementation truth. This
preparation snapshot documents the required contract but cannot replace
repository inspection.

Verified preparation baseline:

```text
origin/main Stage 1 closure commit:
b6c840a9dc935f6a9b2a87a63e5fc99352782ed8
```

At execution time, current `origin/main` must additionally contain:

- accepted and delivered `S02-BE-001` through `S02-BE-007`;
- accepted and delivered `S02-FE-001` through `S02-FE-008`;
- truthful Stage 2 index state for those completed tasks.

Accepted frontend foundations provide:

- Flutter, Riverpod, GoRouter, Dio, and secure token storage;
- one configured authenticated API client and typed envelope/failure mapping;
- `/api/v1/auth/me`-restored session authority and session generation;
- global authentication, inactive-account, inactive-Institution,
  first-login, role, device, and logout reconciliation;
- desktop Platform Owner shell with Dashboard and Institutions navigation;
- real dashboard and Institution list/detail/create/edit/lifecycle flows;
- route-scoped Institution detail state and session-scoped invalidation;
- an `Institution administrators` section on the Institution detail route;
- typed Institution Admin query/list/public-resource models;
- server-side Admin search/filter/sort/pagination and safe list states;
- an accepted create dialog, form/failure patterns, duplicate protection, and
  secret-clearing rules;
- feature-first `features/platform_admin/` architecture, responsive tables/
  cards, accepted dialogs/feedback, and test conventions.

Accepted backend `S02-BE-007` provides exactly:

```text
PATCH /api/v1/platform/institution-admins/{user}
POST  /api/v1/platform/institution-admins/{user}/activate
POST  /api/v1/platform/institution-admins/{user}/deactivate
```

It guarantees:

- Platform Owner middleware authorization and scope-safe target eligibility;
- only persisted `role = institution_admin` with a non-null Institution is a
  valid target;
- update allowlisting for `full_name`, `email`, and `phone` only;
- rejection of empty/unknown/protected update input;
- body-less lifecycle commands and idempotent target-state transitions;
- PostgreSQL transaction/row-lock serialization;
- authoritative `is_active`/`deactivated_at` pairs;
- no-op success without timestamp mutation;
- preservation of login, role, Institution, password, first-login state,
  tokens, profile/lifecycle fields outside the action, and historical data;
- reactivation that remains subject to inactive-Institution and first-login
  gates;
- one explicit safe Institution Admin Resource reused by all Admin endpoints;
- exact `200` messages and accepted stable error envelopes.

The accepted public Resource is:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "full_name": "Institution Admin",
  "login_name": "admin.school1",
  "email": null,
  "phone": "+998...",
  "is_active": true,
  "must_change_password": true,
  "last_login_at": null,
  "deactivated_at": null,
  "created_at": "2026-08-10T10:00:00Z",
  "updated_at": "2026-08-10T10:00:00Z"
}
```

Do not create a second or broader Admin model for this task.

---

## 4. Dependency and Stage-Control Gate

Before implementation, prove from repository evidence:

1. Stage 1 is `Closed` and Stage DoD is `PASS`.
2. `S02-BE-001` through `S02-BE-007` are `Accepted`, reviewed `PASS`,
   delivered, and present on current `origin/main`.
3. `S02-BE-007` exposes the exact PATCH/activate/deactivate/resource/error/
   lifecycle contracts and PostgreSQL-backed tests required here.
4. `S02-FE-001` through `S02-FE-008` are accepted and delivered, including
   the current Institution detail route, Admin list/create section, query
   controller, action/dialog patterns, and session-scoped invalidation.
5. `tasks/STAGE_02_TASK_INDEX.md` matches the approved 17-task decomposition.
6. This detailed task exists exactly at:

   ```text
   tasks/frontend/stage-02/S02-FE-009-platform-institution-admin-update-lifecycle.md
   ```

7. Its status is `Approved`.
8. No conflicting Admin edit/lifecycle UI already exists.

If a dependency is missing, local `main` differs from `origin/main`, or current
evidence materially contradicts this contract, stop and return:

```text
FINAL STATUS: BLOCKED
```

Do not repair predecessor scope, create missing backend endpoints, reinterpret
locked behavior, or absorb `S02-INT-001`.

This task may update only truthful `S02-FE-009` lifecycle state in the Stage 2
index. It must not create, approve, implement, or state-mutate `S02-INT-001`.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

Before editing:

1. Read root `AGENTS.md`, `frontend/AGENTS.md`, and any nearer instruction file
   completely.
2. Read `tasks/README.md`, `tasks/STAGE_02_TASK_INDEX.md`, and this task.
3. Read accepted `S02-BE-007`, `S02-FE-004`, and `S02-FE-008`, plus only
   predecessor contracts/evidence needed to verify shared providers, guards,
   invalidation, and mutation patterns.
4. Read only the locked specification sections referenced in Section 10.
5. Inspect actual Platform Owner router/shell, Institution detail, Admin list/
   create implementation, Admin DTO/domain/query/controller, endpoint registry,
   configured API client, envelope/failure mapper, session generation,
   dialogs/feedback, responsive presentation, and tests.
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

7. Confirm local `main == origin/main`, the remote is approved, and the only
   permitted worktree changes are exactly these two approved preparation files:

   ```text
   tasks/frontend/stage-02/S02-FE-009-platform-institution-admin-update-lifecycle.md
   tasks/frontend/stage-02/S02-FE-009-CODEX-PROMPT.md
   ```

   No other modified, staged, deleted, renamed, or untracked path is allowed.
   Neither preparation file may be committed on `main`.
8. Create/switch to exactly:

   ```text
   task/s02-fe-009-institution-admin-update-lifecycle
   ```

9. Carry the two approved files to the task branch if needed and prove
   committed `main` was not changed.
10. Use the repository-pinned Flutter/Dart toolchain and lockfile.
11. Run relevant pre-existing frontend gates before material edits.
12. Do not commit, push, open a PR, merge, or mark accepted before Phase 2
    read-only acceptance passes.

Unrelated changes are a blocker. Preserve user work and never reset, discard,
overwrite, or destructively clean it.

### 5.2 Existing route and action placement

Extend only the accepted route:

```text
/platform-owner/institutions/:institutionId
```

Requirements:

- add actions only to Admin rows/cards that came from the currently committed
  server page for the currently open Institution;
- show `Edit` plus exactly one state-appropriate lifecycle action:
  - `Deactivate` when `is_active = true`;
  - `Activate` when `is_active = false`;
- keep the existing Institution basic information, usage, Institution edit/
  lifecycle, Admin query controls, Admin create dialog, navigation, logout,
  guards, loading/error/empty states, and responsive behavior intact;
- do not add a route, route query parameter, Admin detail page, drawer, nested
  shell, navigation destination, or global selected-Admin provider;
- action identity must consist of the current route Institution ID, selected
  Admin ID, selected row's immutable `login_name`, and current auth/session
  generation;
- never accept a user ID from typed text, an editable field, stale global
  selection, or another Institution's cached state;
- do not expose actions before Institution detail and current Admin-list data
  have succeeded;
- list/detail error, not-found, guard, initial-loading, query-loading, global
  empty, filtered-empty, and empty-page states must not expose stale actions;
- changing Institution route, logging out, switching account, invalidating the
  session, or disposing the route clears selected action, dialog form/errors,
  confirmations, in-flight ownership, reconciliation state, and feedback;
- a late completion from the old route/session may be parsed for safe cleanup
  but must not change visible data, close a current dialog, navigate, invalidate
  current-session providers, or show current-session feedback;
- active and inactive Institutions remain manageable by Platform Owner.

### 5.3 Shared typed Resource and action state

Reuse the accepted Institution Admin DTO/domain model. Every PATCH/lifecycle
success must parse the same fields and nullability as list/create:

```text
id                  UUID string
full_name           non-empty string
login_name          non-empty string
email               nullable string
phone               nullable string
is_active           boolean
must_change_password boolean
last_login_at       nullable timestamp
deactivated_at      nullable timestamp
created_at          timestamp
updated_at          timestamp
```

Requirements:

- additive unknown response fields may be ignored;
- missing/invalid core fields, invalid booleans/timestamps, or invalid lifecycle
  pair are safe contract failures; never partially render or apply them;
- require response `data.id` to equal the selected target ID;
- never model/render/log role, `institution_id`, creator, password/hash, tokens,
  permissions, settings, or learning data;
- keep mutation state separate from Admin list-query loading;
- support exactly one Admin mutation owned by the current Institution screen at
  a time; disable all Admin edit/lifecycle submission controls until it settles;
- a single explicit gesture may produce at most one mutation request;
- list GET retries/debounce and mutation ownership must remain independent;
- no optimistic row, count, status, timestamp, sorting, filtering, or pagination
  mutation is allowed.

### 5.4 Exact profile edit dialog

`Edit administrator` opens one accessible dialog from the selected row.

Show immutable context outside editable controls:

```text
Login name
Current account status
Password change required/completed
```

Render only these editable fields:

```text
Full name * → full_name, required, max 200
Email        → email, nullable valid email, max 254
Phone        → phone, nullable non-empty when present, max 50
```

Rules:

- prefill from the selected accepted server Resource snapshot;
- preserve `login_name` exactly as read-only context; do not place it in the
  request body;
- trim approved text according to the accepted form normalization convention;
- empty optional Email/Phone controls serialize as explicit JSON `null` only
  when that differs from the normalized initial server value;
- `full_name` may not become null or empty after trim;
- do not invent email uniqueness, phone E.164, password, username, role,
  Institution, lifecycle, reason, version, ETag, or concurrency fields;
- Cancel, close, or Escape before submission sends no request and clears local
  form/errors/selection;
- while submitting, prevent dialog dismissal that could produce ambiguous
  duplicate intent; provide accessible progress state;
- protect unsaved edits according to the accepted dialog pattern; do not add a
  new application-wide unsaved-changes system;
- do not log form values or include contacts in analytics/diagnostics.

### 5.5 Exact profile PATCH request

Use only:

```http
PATCH /api/v1/platform/institution-admins/{adminId}
Accept: application/json
Content-Type: application/json
Authorization: Bearer <accepted managed client>
```

Send a non-empty object containing only changed approved fields. Examples:

```json
{
  "full_name": "Updated Institution Admin"
}
```

```json
{
  "email": null,
  "phone": "+998..."
}
```

Requirements:

- compare normalized form values with the dialog's immutable initial server
  snapshot;
- include only changed `full_name`, `email`, and/or `phone` keys;
- if there are no effective changes, send no request, keep the user informed,
  and leave server/provider state untouched;
- never send an empty object, scalar/array root, or any protected key;
- protected/forbidden keys include:

  ```text
  id
  user_id
  institution_admin_id
  institution_id
  role
  login_name
  password
  password_confirmation
  is_active
  must_change_password
  last_login_at
  deactivated_at
  created_by_user_id
  created_at
  updated_at
  permissions
  ```

- do not use `Idempotency-Key`, automatic retry, local version, or client
  timestamp;
- use the configured repository/data-source/client path; presentation must not
  call Dio or build raw URLs.

Map `422 validation_failed` field errors only to:

```text
full_name
email
phone
```

Unknown/protected/global validation errors become safe form-level feedback.

### 5.6 Exact profile success behavior

Require `200 OK`:

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "full_name": "Updated Institution Admin",
    "login_name": "admin.school1",
    "email": "admin@example.uz",
    "phone": "+998...",
    "is_active": true,
    "must_change_password": false,
    "last_login_at": null,
    "deactivated_at": null,
    "created_at": "2026-08-10T10:00:00Z",
    "updated_at": "2026-08-10T12:00:00Z"
  },
  "message": "Institution admin updated successfully."
}
```

On a valid current-session/current-route success:

1. validate the envelope, target ID, and Resource invariants;
2. close the edit dialog;
3. clear selected/form/validation/submission state;
4. show one safe success feedback using accepted UI wording; do not use the
   server message as behavior authority;
5. re-fetch the current committed Admin-list query from page authority;
6. use the backend result for row membership/order/content; never patch the
   existing row locally;
7. keep Platform dashboard, Institution list, and Institution detail counts
   unchanged because profile-only fields do not change those aggregates.

If the refreshed current page becomes empty because sort/search/pagination
membership changed, use the accepted empty-page correction once; do not loop.

### 5.7 Lifecycle confirmation and request

Lifecycle actions are separate from the edit form.

For an active target, `Deactivate` confirmation must clearly state:

- the selected login/name context;
- normal protected access will be blocked immediately by account state;
- Institution binding, first-login requirement, credentials, and historical
  data are not deleted or changed;
- the action does not deactivate the Institution or other users.

For an inactive target, `Activate` confirmation must clearly state:

- the selected login/name context;
- activation restores only account active state;
- an inactive Institution still blocks normal access;
- `must_change_password = true` still requires the accepted password-change
  flow;
- the action does not create a session, reset a password, or change role.

Confirmation dialog rules:

- require one explicit confirm gesture;
- Cancel/Escape before confirmation sends no request and clears selection;
- include no reason, force, status selector, timestamp, password, or extra
  fields;
- disable conflicting Admin action controls while submitting;
- do not infer success from button click or HTTP status alone.

Send exactly one state-appropriate request:

```http
POST /api/v1/platform/institution-admins/{adminId}/activate
```

or:

```http
POST /api/v1/platform/institution-admins/{adminId}/deactivate
```

With accepted headers and no body, or one explicit empty JSON object:

```json
{}
```

Choose one project-consistent empty-command representation and test it. Never
send `is_active`, `status`, `reason`, target IDs, Institution, role,
`deactivated_at`, `force`, first-login state, ETag, version, or timestamp.

Do not require `Idempotency-Key` and do not automatically retry the POST.

### 5.8 Exact lifecycle success behavior

Activate transition or backend no-op returns `200` with the current Resource
and exactly:

```text
Institution admin activated successfully.
```

Deactivate transition or backend no-op returns `200` with the current Resource
and exactly:

```text
Institution admin deactivated successfully.
```

Validate that:

```text
activate   → data.is_active = true and data.deactivated_at = null
deactivate → data.is_active = false and data.deactivated_at is non-null
```

On valid current-session/current-route success:

1. validate envelope, target ID, requested final state, and Resource invariants;
2. close confirmation and clear selected/submission state;
3. show one safe state-specific success feedback;
4. re-fetch the visible Admin list from its current committed server query;
5. re-fetch current Institution detail so `users.active` is authoritative;
6. invalidate current-session Platform dashboard and Institution-list data
   because active-user aggregates may have changed;
7. never patch local row/count/status/timestamps or assume the backend performed
   a transition rather than an idempotent no-op.

If an active/inactive filter removes the target, show the normal filtered result
after refresh. Do not force the row to remain visible.

### 5.9 Uncertain mutation outcome and read-only reconciliation

A timeout, connection loss, cancellation after bytes may have been sent, or
other transport outcome where the server result is unknown must not be treated
as definite failure or success.

For PATCH and lifecycle POST:

- never automatically replay the mutation;
- keep the immutable selected target ID/login, submitted desired values/state,
  route Institution ID, and session generation only in transient action state;
- show neutral `Outcome could not be confirmed` feedback without claiming that
  the server did or did not apply the action;
- perform at most one safe read-only reconciliation GET through the accepted
  Admin-list endpoint, without changing the visible committed query:

  ```text
  GET /api/v1/platform/institutions/{currentInstitutionId}/admins
  search=<exact selected login_name>
  page=1
  per_page=100
  sort=login_name
  direction=asc
  ```

- locate the exact target by `id`, not by display text or first result;
- if the exact target is found and all submitted changed profile fields equal
  the current server Resource, treat the requested profile state as achieved,
  then run normal profile success refresh/cleanup with wording based on current
  verified state;
- if the exact target is found in the requested lifecycle state, treat that
  desired state as achieved, then run normal lifecycle refresh/invalidation
  with wording based on current verified state;
- if the target is found but desired state/fields do not match, present current
  server facts and allow a new explicit action only after reconciliation ends;
- if target lookup, parsing, session ownership, or reconciliation GET fails, the
  outcome remains unresolved; clear in-flight ownership but do not auto-retry,
  fabricate state, or show success;
- a reconciliation result from an old route/session must be ignored;
- never alter the visible search/filter/sort/page controls for reconciliation.

This GET is state verification, not hidden mutation retry, polling, or a new
Admin detail API.

### 5.10 Failure and auth/session behavior

Preserve centralized code-based outcomes:

```text
401 authentication_required
403 user_inactive
403 institution_inactive
403 password_change_required
403 forbidden
404 resource_not_found
422 validation_failed
429 rate_limited
500 server_error
```

Requirements:

- `401 authentication_required` and accepted invalid-session signals use the
  global auth reconciliation, clear Platform state, and route safely to login;
- current-actor `user_inactive`, `institution_inactive`, and
  `password_change_required` follow existing global session/guard authority;
- `403 forbidden` shows safe permission feedback without revealing target data;
- target `404 resource_not_found` closes the selected action, clears stale
  target/form state, shows safe `Administrator is no longer available`
  feedback, and refreshes the current Admin list; it must not reinterpret the
  Institution itself as missing;
- edit `422` maps only approved field errors and keeps the dialog open;
- lifecycle `422` is a safe request/contract failure and never creates a form;
- `429`, definite `500`, and ordinary definite failures show retry-safe
  feedback but do not auto-retry a mutation;
- malformed success or core DTO contract failure is not success; use safe
  contract-error handling and a read-only refresh where current ownership still
  holds;
- errors never echo private contacts from another target, stack traces, raw
  bodies, SQL, tokens, or protected fields;
- human-readable server messages may be displayed only through accepted safe
  presentation rules and must never drive routing or business decisions.

### 5.11 Architecture and implementation quality

Use the narrowest accepted feature-first architecture:

```text
presentation widget/dialog
→ controller/notifier/use case
→ feature repository
→ API data source
→ configured Dio client
```

Requirements:

- extend existing Admin DTO/domain/repository/controller responsibilities where
  cohesive; do not create parallel network/auth/error systems;
- keep dialog widgets declarative and business/network orchestration outside
  widget build methods;
- use immutable action snapshots and explicit sealed/typed mutation states;
- avoid one giant screen/controller/repository file and extract by durable
  responsibility when accepted file size/complexity guardrails require it;
- add no generic CRUD framework, base repository rewrite, event bus, command
  bus, offline queue, optimistic cache layer, package, or speculative utility;
- localize user-facing strings through the accepted project pattern; no raw
  backend message parsing or hardcoded duplicate labels where shared labels
  already exist;
- preserve accessible focus, labels, keyboard activation, Escape/cancel, error
  announcements, progress semantics, and text-visible status;
- wide table and compact card/list actions must work without page-level
  overflow at `800 × 600` and `1440 × 900`;
- no action may rely on color alone.

### 5.12 Relevant files and responsibility map

Inspect actual accepted paths before choosing exact filenames. Expected areas:

```text
AGENTS.md
frontend/AGENTS.md
tasks/README.md
tasks/STAGE_02_TASK_INDEX.md
tasks/backend/stage-02/S02-BE-007-*.md
tasks/frontend/stage-02/S02-FE-004-*.md
tasks/frontend/stage-02/S02-FE-008-*.md
frontend/lib/features/platform_admin/data/**
frontend/lib/features/platform_admin/domain/**
frontend/lib/features/platform_admin/presentation/**
frontend/lib/core/network/**
frontend/lib/app/router/**
frontend/test/features/platform_admin/**
frontend/test/**
frontend/integration_test/**
```

These are discovery guidance, not permission to create every path or refactor
unrelated code.

The following remain protected:

```text
docs/01–09
backend/**
docker/**
frontend/pubspec.yaml
frontend/pubspec.lock
platform runner/generated files unless a verified task need exists
```

### 5.13 Functional requirements summary

1. Add Edit plus exactly one state-appropriate lifecycle action to current
   Admin rows/cards.
2. Keep actions inside the accepted Institution detail/Admin-list route only.
3. Bind action identity to current route Institution, target row, and session
   generation.
4. Edit only `full_name`, `email`, and `phone`.
5. Send changed fields only; send no PATCH for no effective change.
6. Never send login, password, role, Institution, lifecycle, first-login,
   creator, login metadata, timestamp, or unknown fields.
7. Require explicit lifecycle confirmation and send an empty/body-less POST.
8. Prevent duplicate/conflicting Admin mutations while one is in flight.
9. Parse the exact shared Resource and require the selected target ID.
10. Use backend refresh after success; no optimistic rows/counts/state.
11. Refresh Admin list for edit; refresh Admin list + Institution detail and
    invalidate dashboard/Institution list for lifecycle.
12. Never automatically retry an uncertain PATCH/POST.
13. Reconcile uncertain outcomes once through a non-visible exact-login search
    and exact target-ID match.
14. Clear/ignore all action state and late completions across route/session
    changes.
15. Preserve auth, device, role, first-login, inactive-state, and logout guards.
16. Add no backend/docs/package/lockfile or `S02-INT-001` scope.

---

## 6. Business, Security, and Data-Protection Requirements

Required negative guarantees:

1. Only the accepted active, password-complete desktop Platform Owner session
   can reach and use these controls.
2. Route visibility is never treated as backend authorization.
3. A target must originate from the current Institution-scoped server list.
4. Target ID, role, Institution, login, password, and first-login state cannot
   be changed through profile input.
5. Lifecycle desired state comes from the chosen endpoint, never request data.
6. Activation never implies Institution activation, password completion,
   session creation, or permission elevation.
7. Deactivation never deletes credentials, tokens, Institution binding, or
   historical records.
8. Contacts and names are not written to logs, diagnostics, or unrelated state.
9. Late prior-session/Institution responses cannot expose or modify current UI.
10. A known UUID from another Institution cannot be injected through the UI.
11. No Student answers/submissions, Teacher content, scores, results, groups,
    settings, or reports are read or mutated.
12. Mutation outcome uncertainty never triggers automatic replay.

---

## 7. Explicit Non-Goals

Do not implement:

```text
new Admin route/page/detail endpoint
login_name edit
password reset/change/reveal/copy/resend/generation
role or Institution reassignment
first-login-state mutation
Teacher/Student/Parent/Platform Owner management
bulk edit or bulk lifecycle
delete/archive/suspend/lock/invite/impersonate
audit-log/notification/support-ticket infrastructure
Institution profile/lifecycle/settings mutations
optimistic local row/count/lifecycle authority
automatic mutation retry or offline queue
backend/database/docs/package/lockfile changes
S02-INT-001 implementation or Stage 2 closure
```

---

## 8. Required Tests and Verification

### 8.1 Data and request mapping

Test at minimum:

- PATCH, activate, and deactivate exact endpoint paths;
- update changed-fields-only serialization;
- explicit `null` for cleared optional contacts;
- no request for no effective changes;
- no protected/unknown keys;
- lifecycle body uses the one accepted empty-command representation;
- no `Idempotency-Key` or automatic retry;
- exact shared Resource parsing for null/non-null timestamps and booleans;
- target-ID mismatch and invalid lifecycle pairs fail safely;
- exact success envelope/message parsing without message-driven behavior;
- `422` edit field mapping only for `full_name`, `email`, `phone`.

### 8.2 Controller/state behavior

Test at minimum:

- current route/list row opens the correct edit snapshot;
- normalization and changed-field comparison;
- cancel/no-change/submitting/success/failure states;
- exactly one mutation per explicit gesture;
- all Admin mutation controls disabled while one mutation is owned;
- success refresh/invalidation differences for profile versus lifecycle;
- no local optimistic row/count/status changes;
- target `404` closes stale action and refreshes current list;
- current auth codes delegate to accepted global reconciliation;
- route A → B clears A action and ignores A late completion;
- logout/account switch/session invalidation clears action and ignores late
  mutation/reconciliation results;
- query change while a dialog is open cannot retarget the action;
- disposed controller performs no current UI side effect.

### 8.3 Uncertain-outcome reconciliation

Test at minimum:

- transport uncertainty sends no automatic second PATCH/POST;
- exactly one internal GET uses current Institution, exact selected login,
  page 1, per_page 100, login-name sort ascending, and no visible-query change;
- exact target is selected by ID, not first result;
- matching desired profile fields resolves to achieved state;
- matching desired lifecycle state resolves to achieved state;
- mismatch presents current server state without claiming success;
- target absent, reconciliation error, malformed response, and stale session
  remain unresolved without replay;
- lifecycle reconciliation refreshes/invalidate counts only after desired state
  is verified.

### 8.4 Widget and accessibility behavior

Test at minimum:

- active row shows Edit + Deactivate; inactive row shows Edit + Activate;
- row/card labels include unambiguous selected Admin context;
- edit dialog has only three editable fields and read-only login/status context;
- field validation, form-level validation, no-change feedback, cancel, Escape,
  focus, progress, and duplicate-click behavior;
- activation/deactivation confirmation copy accurately preserves Institution/
  first-login boundaries;
- filtered removal after lifecycle refresh renders normal server list state;
- loading/error/empty/not-found/guard states expose no stale action;
- text status and controls do not rely only on color;
- table/card action layout has no page-level overflow at `800 × 600` and
  `1440 × 900`.

### 8.5 Regression and integration tests

Verify:

- accepted Admin list/search/filter/sort/pagination/create behavior remains;
- Institution detail/edit/lifecycle and user-count behavior remains;
- dashboard and Institution-list invalidation remains session-scoped;
- logout, first-login, inactive-account/Institution, wrong-role, direct-route,
  and unsupported-device guards remain;
- same-role and cross-role account switches expose no stale Admin data/action;
- malformed/error responses never render protected/raw data;
- no backend, docs, package, lockfile, or runner drift.

Run current repository-configured gates, including at minimum from `frontend/`:

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test integration_test
flutter build windows --debug
```

Use the repository-pinned toolchain and the exact configured commands. Do not
invent unavailable scripts or weaken checks. Run relevant backend regression
only through an already-established project command when required to prove the
real API integration; do not edit backend scope.

---

## 9. Manual Smoke Check

Against the accepted Laravel/PostgreSQL backend and Flutter Windows app:

1. Log in as active, password-complete Platform Owner.
2. Open Institution A and load its Admin section.
3. Edit one Admin's full name and clear one optional contact.
4. Confirm exactly one PATCH, no protected keys, exact `200`, dialog close, and
   server-refreshed row.
5. Reopen Edit and submit no changes; confirm no PATCH.
6. Trigger a validation error and confirm only safe field/form feedback.
7. Deactivate an active Admin after confirmation; confirm one empty POST,
   server-refreshed row/counts, and blocked target normal access.
8. Repeat through a stale-state/no-op scenario and confirm `200` remains safe.
9. Activate the Admin; confirm one empty POST and current server state.
10. With the Institution inactive, confirm Platform Owner can manage the Admin
    but the Admin remains blocked by `institution_inactive` after activation.
11. Confirm `must_change_password = true` remains visible and unchanged.
12. Simulate/observe a transport-uncertain outcome; confirm no automatic replay
    and one read-only reconciliation.
13. Change Institution or logout while an action is pending; confirm no stale
    row, dialog close, feedback, invalidation, or cross-session leak.
14. Verify active/inactive filtered lists, pagination correction, keyboard
    dialogs, `800 × 600`, and `1440 × 900` layouts.
15. Verify Platform Owner wrong-device and other-role direct access remain
    blocked.

Sanitize evidence. Do not record tokens, passwords, private contact values,
raw authorization headers, or sensitive screenshots/logs.

---

## 10. Contract Traceability

Read only relevant locked sections:

| Authority | Relevant contract |
|---|---|
| `docs/02-user-roles.md` §1, §8–9 | Platform Owner support boundary and desktop access |
| `docs/03-features.md` §2, §13 | Institution Admin access support and desktop management UI |
| `docs/04-user-flows.md` §2 | Institution Admin support flow, access restriction, and Platform Owner boundaries |
| `docs/04-user-flows.md` user activation/deactivation flow | Confirmation and account-state behavior |
| `docs/05-business-rules.md` BR-INST-019–021 | Platform support authority and learning-data boundary |
| `docs/05-business-rules.md` BR-ROLE-004–008, BR-ROLE-022–023 | Active account, history, first login, authorized Admin lifecycle, and device scope |
| `docs/07-architecture.md` §8.3, §9 | Explicit platform actions and authorization layers |
| `docs/07-architecture.md` §20.3–20.6 | API/repository/model/state boundaries |
| `docs/07-architecture.md` §21–23, §29, §32, §35 | Navigation, device scope, errors, tests, and security |
| `docs/09-api-contracts.md` §2.3–2.10, §4–5 | Envelopes, validation, auth/session, stable codes |
| `docs/09-api-contracts.md` §7.8 | Exact Institution Admin endpoints and target-role rule |
| `docs/09-api-contracts.md` §33, §36–37 | Authorization/scoping, MVP boundaries, and API DoD |
| Accepted `S02-BE-007` | Exact request/resource/success/failure/lifecycle/concurrency contract |
| Accepted `S02-FE-008` | Existing route, Admin section, query/list/create state, DTO, and isolation patterns |

If any source materially conflicts, stop with exact evidence. Do not change
locked docs inside this task.

---

## 11. Stop Conditions

Stop without implementation and report exact evidence if:

- Stage 1 is not closed or Stage 2 decomposition/index is not truthful;
- required backend/frontend predecessor is not Accepted/delivered on
  `origin/main`;
- exact `S02-BE-007` endpoints/resource/messages differ materially;
- local `main != origin/main`, remote is unexpected, or unrelated worktree
  changes exist;
- applicable instructions/specifications conflict;
- implementation would require backend/database/docs/package/lockfile change;
- current Admin list cannot provide safe route/session/target ownership;
- exact safe uncertain-outcome reconciliation cannot be implemented from the
  accepted list contract;
- required Flutter/Windows/PostgreSQL verification cannot run truthfully;
- a P1/P2 finding, security/tenant/session leak, automatic duplicate mutation,
  or predecessor regression remains;
- safe Git/GitHub delivery cannot complete after acceptance.

Do not bypass a stop condition by weakening tests, widening scope, modifying
predecessors, resetting user work, or declaring success from stale evidence.

---

## 12. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git preflight

Synchronize and verify `main`, approved remote, allowed preparation files, and
dependencies exactly as Section 5.1 requires. Create the exact task branch.

If Phase 0 fails:

```text
FINAL STATUS: BLOCKED
```

### Phase 1 — Implementation

Implement only `S02-FE-009`. Keep changes focused, add required tests, and run
the configured quality/build/integration/smoke checks. Do not commit or push.

### Phase 2 — Read-only acceptance gate

After implementation, stop editing and perform an independent read-only audit
of the complete candidate.

Inspect all candidate changes, including:

```text
git status --short
git diff --check
git diff --stat
git diff
git diff --cached --check
git diff --cached --stat
git diff --cached
git ls-files --others --exclude-standard
```

Also compare the branch with its verified base without assuming uncommitted
work appears in `main...HEAD`.

The audit must verify:

- exact task scope and protected paths;
- route/session/target ownership and stale-completion safety;
- exact edit allowlist and changed-fields-only request;
- exact empty lifecycle requests and confirmation;
- no optimistic authority or automatic mutation replay;
- read-only uncertain-outcome reconciliation semantics;
- exact DTO/envelope/error/auth behavior;
- refresh/invalidation correctness;
- accessibility/responsiveness;
- focused tests and all current quality gates;
- no `S02-INT-001` implementation/state mutation;
- no secret/private-data leakage.

Classify findings:

- `P1` — security, auth, cross-Institution/session leakage, protected-field
  mutation, false success, duplicate mutation, locked-contract violation, or
  failed core acceptance criterion;
- `P2` — material architecture, state, request, error, test, regression,
  delivery, or scope mismatch;
- `P3` — non-blocking observation only.

Any P1/P2 means:

```text
FINAL STATUS: NOT ACCEPTED
```

Return exact evidence and do not commit/push/open a PR.

`PASS` is valid only when no P1/P2 remains and every required check is
truthfully green. Phase 2 `PASS` authorizes Phase 3; it is not yet the final
task status `Accepted`.

### Phase 3 — Post-acceptance Git delivery

Only after Phase 2 `PASS`:

1. Update truthful `S02-FE-009` task/review/index lifecycle records only.
2. Do not create or state-mutate `S02-INT-001`.
3. Re-run affected format/tests/diff/secret/scope checks after bookkeeping.
4. Stage only task-scope code/tests and truthful workflow files.
5. Create one focused commit.

Preferred subject:

```text
feat(frontend): manage institution admin lifecycle
```

Suggested body:

```text
Task: S02-FE-009
Review: PASS
```

6. Push the exact task branch without force.
7. Open a PR to `main`; wait for required checks.
8. Merge only when safe and required checks pass.
9. Synchronize local `main` with `origin/main`.
10. Verify final commit reachability, local/main equality, clean tree, and
    truthful `Accepted`/delivery state.

If implementation passes but safe delivery cannot complete:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Do not call the task Accepted until the accepted result is on `origin/main`,
local `main == origin/main`, and the working tree is clean.

---

## 13. Acceptance Criteria

The task is accepted only when all are true:

1. `S02-FE-009` dependencies and exact branch/preflight are proven.
2. Existing Admin rows/cards expose Edit and one state-appropriate lifecycle
   action only.
3. Actions remain bound to current Institution route, selected target, and
   session generation.
4. Edit dialog exposes only three editable fields and read-only login/status/
   first-login context.
5. PATCH contains only changed `full_name`/`email`/`phone`; no-change sends no
   request.
6. Lifecycle requires confirmation and sends exactly one empty/body-less POST.
7. Protected identity, role, Institution, password, lifecycle/profile fields,
   creator, metadata, and timestamps are never client-mutated.
8. Exact shared Resource and selected target ID are validated on success.
9. Duplicate/conflicting Admin mutations are blocked.
10. No optimistic row/count/status/timestamp mutation exists.
11. Edit and lifecycle refresh/invalidation behavior matches Sections 5.6/5.8.
12. Uncertain outcomes never auto-replay and use at most one safe internal
    reconciliation GET without changing visible query state.
13. Route/session changes clear action state and ignore late completions.
14. Stable error/auth/session codes use accepted handling and reveal no private
    data.
15. Accessibility and `800 × 600` / `1440 × 900` responsive behavior pass.
16. Focused tests, full Flutter tests, analyze, format, Windows build, relevant
    integration, and manual smoke pass.
17. No backend/database/docs/package/lockfile/runner or unrelated drift exists.
18. Phase 2 read-only audit has no P1/P2 finding.
19. Accepted commit is merged to `origin/main`; local `main` matches and is
    clean.
20. `S02-FE-009` alone is truthfully `Accepted`; `S02-INT-001` was not started.

---

## 14. Required Final Report

Return:

1. **Final status** — exactly one:
   - `ACCEPTED`
   - `NOT ACCEPTED`
   - `BLOCKED`
   - `DELIVERY BLOCKED`
2. **Preflight evidence**:
   - repository/remote;
   - task branch;
   - starting local/main and `origin/main` hashes;
   - dependency/index/task-status proof;
   - initial worktree scope.
3. **Changed files** and responsibility of each.
4. **Implemented behavior**:
   - edit action/dialog/request;
   - lifecycle confirmations/requests;
   - refresh/invalidation;
   - uncertain-outcome reconciliation;
   - session/route isolation.
5. **Exact API evidence** for all three endpoints, bodies, success Resource,
   and error mapping.
6. **Security and protected-field evidence**.
7. **Automated check results** with exact commands and counts.
8. **Windows real-stack smoke result** and sanitized evidence.
9. **Read-only acceptance findings** ordered P1 → P2 → P3.
10. If delivered:
    - commit hash/subject;
    - PR reference;
    - checks/merge result;
    - final local/main and `origin/main` hashes;
    - clean working-tree proof.
11. **Scope confirmation**:
    - no backend/database/docs/package/lockfile changes;
    - no Admin password/role/Institution management;
    - no optimistic/automatic mutation replay;
    - `S02-INT-001` was not created or started.
12. **Next gate**:

    ```text
    S02-INT-001 — Full real-stack Stage 2 end-to-end verification on Windows
    ```
