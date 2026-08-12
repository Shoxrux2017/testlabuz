# Codex Task: Platform Institution Lifecycle Actions

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-FE-007` |
| Status | `Accepted` |
| Review | `PASS` |
| Delivery | `Delivered` |
| Pull request | `#34` |
| Merge commit | `2f8e902e8073eeec847d8108f7600a486b0302a8` |
| Approved on | `2026-08-10` |
| Stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Frontend / Platform Owner Institution lifecycle` |
| Priority | `High` |
| Depends on | `S02-FE-006` accepted, delivered, and present on current `origin/main`; accepted `S02-BE-004` Institution lifecycle API |
| Sequence next | `S02-FE-008` |
| Repository | `https://github.com/Shoxrux2017/testlabuz.git` |
| Target branch | `task/s02-fe-007-institution-lifecycle` |
| Execution model | One focused implementation task followed by read-only acceptance and safe GitHub delivery |

---

## 2. Goal

Add safe Platform Owner Institution activation and deactivation actions to the
accepted Institution detail experience, backed only by:

```text
POST /api/v1/platform/institutions/{institution}/activate
POST /api/v1/platform/institutions/{institution}/deactivate
```

The accepted result must let an eligible desktop `platform_owner`:

- see the one lifecycle action valid for the currently displayed status;
- understand the effect of activation or deactivation before acting;
- cancel without sending a request;
- explicitly confirm the selected action;
- trigger at most one lifecycle request while that action is in flight;
- receive a server-authoritative result for both real transitions and
  already-current idempotent outcomes;
- remain on the Institution detail page while its current status/profile is
  reconciled from the backend;
- make accepted Institution detail, list, and Platform dashboard data stale
  only for the current authenticated session after a confirmed transition;
- safely check current server status when the POST outcome is uncertain;
- preserve shell, list, detail, create, edit, identity, logout,
  auth/password/role/device guards, and account isolation.

The backend remains authoritative for lifecycle state, timestamps, access
enforcement, data retention, idempotency, authorization, and persistence. The
frontend must not mutate status optimistically, infer access changes from a
button click, or parse a human-readable message to decide business state.

This task implements only Institution lifecycle UI. It must not implement
Institution Admin list/create (`S02-FE-008`), Institution Admin
edit/activate/deactivate (`S02-FE-009`), or Stage-wide real-stack closure
(`S02-INT-001`).

### Scope boundary

This task owns only:

- lifecycle actions on the accepted route:

  ```text
  /platform-owner/institutions/:institutionId
  ```

- status-derived `Activate` or `Deactivate` affordance on Institution detail;
- accessible confirmation dialogs with truthful consequences;
- the two accepted lifecycle POST calls with an empty JSON object;
- typed lifecycle mutation state and response mapping;
- duplicate-trigger and stale-completion protection;
- confirmed-success detail refresh plus current-session list/dashboard
  invalidation;
- safe ambiguous-outcome status reconciliation through the accepted detail
  `GET`;
- focused DTO/repository/controller/widget/regression/accessibility tests;
- truthful Windows desktop smoke verification against the accepted backend.

It does not:

- add lifecycle actions to Dashboard, list rows, navigation, create, or edit;
- add reason, note, confirmation flag, timestamp, status, Institution ID, user,
  or any other client-controlled request field;
- add an `Idempotency-Key`, ETag, `If-Match`, version, or client lock protocol;
- change Institution basic data, settings, Administrators, Users, roles,
  passwords, tokens, educational records, or access middleware;
- revoke sessions, hard-delete data, archive, suspend, bill, notify, email,
  impersonate, or audit;
- add bulk lifecycle, optimistic cache mutation, polling, WebSockets, offline
  queue, or background synchronization;
- change backend, database, Docker, CI, packages, lockfiles, or locked
  `docs/01–09`;
- implement `S02-FE-008+`.

---

## 3. Current Accepted Context

Treat current `origin/main` at execution time as implementation truth. This
preparation snapshot exists only to make the task contract reviewable.

Verified preparation baseline:

```text
origin/main Stage 1 closure commit:
b6c840a9dc935f6a9b2a87a63e5fc99352782ed8
```

At execution time, current `origin/main` must additionally contain:

- accepted and delivered `S02-BE-001` through `S02-BE-007`;
- accepted and delivered `S02-FE-001` through `S02-FE-006`;
- truthful Stage 2 index state for those completed tasks.

Accepted frontend foundations provide:

- Flutter, Riverpod, GoRouter, Dio, and secure token storage;
- one configured authenticated API client and typed envelope/failure mapping;
- `/api/v1/auth/me`-restored session authority;
- global `401`, account, Institution, first-login, role, and device
  reconciliation;
- desktop Platform Owner shell and navigation;
- real dashboard, Institution list, detail, create, and edit flows;
- typed Institution/status/type models and feature-first
  `features/platform_admin/` organization;
- current-session provider invalidation, request-generation, request
  de-duplication, and stale-session isolation patterns.

Accepted backend `S02-BE-004` provides:

```text
POST /api/v1/platform/institutions/{institution}/activate
POST /api/v1/platform/institutions/{institution}/deactivate
```

Both commands:

- are authorized only for an active, password-complete Platform Owner;
- accept a body-less request or an empty JSON object and reject non-empty
  payloads;
- derive target state from the route;
- are idempotent by target state;
- return `200` for a real transition and an already-current no-op;
- perform no duplicate write for the already-current state;
- return the complete current public mutation resource;
- do not require a public `Idempotency-Key`;
- enforce Institution-user access on the backend;
- preserve history, user rows, settings, tokens, and unrelated Institution
  data.

---

## 4. Dependency and Stage-Control Gate

Before implementation, prove from repository evidence:

1. Stage 1 is `Closed` and Stage DoD is `PASS`.
2. `S02-BE-001` through `S02-BE-007` are `Accepted`, reviewed `PASS`,
   delivered, and present on current `origin/main`.
3. `S02-BE-004` exposes the exact two idempotent lifecycle endpoints,
   response/error contract, and PostgreSQL-backed tests required here.
4. `S02-FE-001` owns shell/navigation/role/device/session guards.
5. `S02-FE-002` owns Platform dashboard data/invalidation.
6. `S02-FE-003` owns Institution list data/query state.
7. `S02-FE-004` owns Institution detail route/data/not-found state.
8. `S02-FE-005` create and `S02-FE-006` edit are accepted/delivered and green.
9. `tasks/STAGE_02_TASK_INDEX.md` matches the approved 17-task decomposition.
10. This detailed task exists exactly at:

    ```text
    tasks/frontend/stage-02/S02-FE-007-platform-institution-lifecycle-actions.md
    ```

11. Its status is `Approved`.
12. No conflicting Institution lifecycle UI is already present.

If any dependency is missing, local `main` differs from `origin/main`, or
current evidence materially contradicts this contract, stop and return:

```text
FINAL STATUS: BLOCKED
```

Do not repair predecessor scope, recreate backend behavior, or absorb
`S02-FE-008+`.

This task may update only truthful `S02-FE-007` lifecycle state in the Stage 2
index. It must not create, approve, implement, or state-mutate a later task.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

Before editing:

1. Read root `AGENTS.md`, `frontend/AGENTS.md`, and every nearer instruction
   file completely.
2. Read `tasks/README.md`, `tasks/STAGE_02_TASK_INDEX.md`, and this complete
   task.
3. Read accepted `S02-BE-004` and `S02-FE-001` through `S02-FE-006`
   contracts and delivery evidence.
4. Read only the locked specification sections referenced in Section 12.
5. Inspect the actual router/shell, Institution DTO/domain/repository,
   dashboard/list/detail providers, detail/edit screens, dialog/feedback
   primitives, session generation, API client/failure mapping, and tests.
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

7. Prove `local main == origin/main` and the remote is the approved repository.
8. The worktree must be clean except these exact preparation files, if the
   project owner saved them before execution:

   ```text
   tasks/frontend/stage-02/S02-FE-007-platform-institution-lifecycle-actions.md
   tasks/frontend/stage-02/S02-FE-007-CODEX-PROMPT.md
   ```

9. No other modified, staged, deleted, renamed, or untracked path is allowed.
10. Do not commit the preparation pair directly on `main`.
11. Create/switch to exactly:

    ```text
    task/s02-fe-007-institution-lifecycle
    ```

12. Carry the approved pair onto the task branch and verify `main` was not
    changed.
13. Use repository-pinned Flutter/Dart tooling and accepted backend runtime.
14. Do not commit, push, open a PR, merge, or mark accepted during Phase 1 or
    Phase 2.

### 5.2 Detail-page action placement and status truth

Add lifecycle UI only to the accepted Institution detail page:

```text
/platform-owner/institutions/:institutionId
```

Render exactly one available lifecycle action from the current typed server
status:

| Current server status | Visible action | Target endpoint/state |
|---|---|---|
| `active` | `Deactivate` | `POST .../{id}/deactivate` → `inactive` |
| `inactive` | `Activate` | `POST .../{id}/activate` → `active` |

Requirements:

- keep the existing status badge/text visible and truthful;
- place the action in the existing detail action/header region without
  redesigning the shell;
- use a destructive visual treatment only for `Deactivate`;
- use an accepted primary/positive treatment for `Activate`;
- expose the action only when a valid typed Institution detail is loaded;
- do not infer status from list filters, dashboard counters, route parameters,
  local storage, or previous sessions;
- unknown/invalid server status remains a contract/load failure and must not
  render either lifecycle action;
- do not add action menus or disabled future Admin controls;
- keep `Edit basic information` distinct from lifecycle state;
- do not create a new lifecycle route or leave the detail page for the normal
  action flow;
- preserve direct URLs, Back, edit route, shell selection, logout, and every
  accepted guard.

### 5.3 Exact confirmation-dialog behavior

No lifecycle POST may occur until the user explicitly confirms a focused
dialog.

The dialog must include:

- exact action title: `Activate institution` or `Deactivate institution`;
- target Institution name as safely rendered text;
- current and target status in human-readable form;
- a concise consequence statement;
- `Cancel` and exact confirm action `Activate` or `Deactivate`;
- accessible dialog semantics, focus placement/trap, keyboard operation, and
  focus restoration according to accepted primitives.

Required consequence meaning:

- Activate: eligible users may use the Institution again according to each
  account's own active state, first-login requirement, role, relationships,
  and permissions.
- Deactivate: Institution Admins, Teachers, Students, and Parents will lose
  normal Institution access; historical data is preserved.

Rules:

- Cancel, Escape, or dialog dismissal before confirmation sends no request;
- no reason, note, password, name re-entry, checkbox, or `force` control;
- do not claim that activation reactivates individually inactive accounts;
- do not claim that deactivation deletes data or revokes stored tokens;
- one detail page may own at most one lifecycle confirmation/submission at a
  time;
- while submitting, keep the dialog/context visible, show bounded progress,
  disable duplicate confirm/dismiss actions that could create ambiguity, and
  prevent Enter/double-click/rebuild duplication;
- after a definite failure or reconciled unchanged state, a new POST requires
  a new explicit confirmation.

### 5.4 Exact request contract

Use exactly one of these endpoints according to the confirmed target state:

```http
POST /api/v1/platform/institutions/{institutionId}/activate
Accept: application/json
Content-Type: application/json
Authorization: Bearer <managed by accepted API client>

{}
```

```http
POST /api/v1/platform/institutions/{institutionId}/deactivate
Accept: application/json
Content-Type: application/json
Authorization: Bearer <managed by accepted API client>

{}
```

Frontend serialization must always send exactly an empty JSON object for a
confirmed command. Never send:

```text
status
is_active
deactivated_at
institution_id
user_id
reason
note
force
confirmed
role
created_by_user_id
settings
```

Also:

- no query parameters, multipart form, PUT/PATCH/DELETE substitute, or generic
  `setStatus` endpoint;
- no client time, device time, UUID authority, or target-state body field;
- no `Idempotency-Key`, ETag, `If-Match`, version, or custom lock header;
- no raw Dio/request construction in widgets;
- one confirmation creates at most one in-flight POST;
- no automatic POST retry in Dio, data source, repository, controller, or UI;
- do not issue a preliminary GET merely to decide whether the explicit
  idempotent endpoint is allowed;
- do not branch on response `message`; branch on typed HTTP/resource state.

The backend may return `200` without a write when another actor already moved
the Institution to the target state. Treat that as a valid, server-confirmed
idempotent success.

### 5.5 Mutation state and duplicate protection

Use one focused, session-owned lifecycle state that can distinguish:

```text
idle
confirming
submitting activate|deactivate
confirmed target state
reconciling current status
definite failure
unknown outcome
```

Requirements:

- source Institution ID, source status, target state, session generation, and
  request generation remain explicit for the operation;
- ordinary rebuilds cannot reopen the dialog or resubmit;
- opening/confirming a second lifecycle action while one is active is blocked;
- source action and keyboard shortcut cannot bypass the in-flight guard;
- no optimistic status badge, list row, dashboard counter, access statement,
  or success toast before a valid backend result;
- a controller failure always leaves UI recoverable and not permanently busy;
- disposing route/dialog or changing account/session makes later completion
  stale, but does not cancel a possibly transmitted server mutation into a
  claimed failure;
- backend state-idempotency permits a future manual repeat, but only after
  current status is reconciled and the user gives a new confirmation;
- do not create a generic cross-feature mutation manager or static global
  in-flight flag.

### 5.6 Exact success response and typed mapping

A real transition and an already-current no-op both require HTTP `200 OK` and
the complete public mutation resource.

Activate example:

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Example School",
    "type": "school",
    "status": "active",
    "contact_email": "info@example.uz",
    "contact_phone": "+998...",
    "address": "Samarkand",
    "description": "Optional notes",
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-10T12:00:00Z"
  },
  "message": "Institution activated successfully."
}
```

Deactivate example:

```json
{
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Example School",
    "type": "school",
    "status": "inactive",
    "contact_email": "info@example.uz",
    "contact_phone": "+998...",
    "address": "Samarkand",
    "description": "Optional notes",
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-10T12:00:00Z"
  },
  "message": "Institution deactivated successfully."
}
```

Typed decoding must require:

- non-empty string `id` and `name`;
- returned `id` exactly matching the requested Institution ID;
- all nine accepted Institution `type` values;
- `status` exactly equal to the confirmed target state;
- nullable strings for contact/address/description;
- valid required RFC 3339 `created_at` and `updated_at`;
- a non-empty success `message`.

The exact backend messages above may be displayed safely, but control flow
must not parse them. Ignore additive unknown fields without modeling protected
data. Do not model or expose `created_by_user_id`, creator, `deactivated_at`,
settings, counts, users, tokens, or learning data.

Missing/wrong core fields, mismatched ID, wrong target status, invalid time,
non-`200` `2xx`, or malformed `200` is not confirmed success because the
server may still have committed the transition. Route it to unknown-outcome
reconciliation.

### 5.7 Confirmed-success refresh and invalidation

Only after a valid current-session `200` response:

1. close/resolve the confirmation UI once;
2. retain the validated response as truthful transitional evidence;
3. invalidate the current Institution detail provider once;
4. invalidate Institution list/query caches once for the current session;
5. invalidate Platform dashboard data once for the current session;
6. let the visible detail page immediately refetch through the accepted
   `GET /api/v1/platform/institutions/{institutionId}` path;
7. do not trigger hidden off-screen list/dashboard requests;
8. show one safe success feedback only for the current session;
9. render the refreshed server status/action when the GET completes.

Do not:

- navigate away from detail on normal success;
- mutate cached list rows or dashboard counters locally;
- derive active/inactive totals;
- claim Institution-user access from frontend state;
- invalidate another account/session's providers;
- loop refreshes when providers rebuild;
- hide a confirmed transition merely because the follow-up GET fails.

If the confirmation POST is valid but the detail refresh fails, show the
server-confirmed target status as bounded transitional data plus a safe
`Refresh details` error/action. A refresh retry performs only the read-only
GET, never another POST.

### 5.8 Failure and ambiguous-outcome behavior

Use stable backend codes and accepted global reconciliation:

| Result | Required frontend behavior |
|---|---|
| `401 authentication_required` | Invalidate/reconcile session through accepted auth flow; no protected stale content |
| `403 user_inactive` | Accepted global account reconciliation |
| `403 institution_inactive` | Accepted global Institution/account reconciliation when applicable |
| `403 password_change_required` | Accepted password-change reconciliation |
| `403 forbidden` | Safe denied state/feedback; no success or protected leakage |
| `404 resource_not_found` | Privacy-safe detail not-found state; no success |
| `422 validation_failed` | Safe command error; no field mapping because request has no business fields; report contract mismatch in diagnostics without raw internals |
| `409` or undocumented lifecycle conflict | Do not invent already-active/inactive behavior; reconcile current detail and surface safe contract failure |
| definite `500 server_error` or other definite HTTP failure | Safe failure; no success/invalidation; a future attempt needs new confirmation |
| transport timeout/disconnect after submission may have started | Unknown outcome; never claim success/failure and never auto-repeat POST |
| malformed/mismatched/wrong-status `200` | Unknown outcome; transition may have committed |

Unknown-outcome reconciliation:

1. dismiss/replace submitting progress with `Checking current status…`;
2. issue at most one immediate read-only detail GET for the current generation;
3. if GET returns the target status, show truthful `Current server status is
   active|inactive`, invalidate current-session list/dashboard data, and do not
   repeat POST;
4. if GET returns the original/opposite status, render that truthful status and
   allow a future action only through a new confirmation;
5. if GET also fails or is malformed, show `Lifecycle outcome is unknown` with
   `Check status`; that action performs only one replacement GET;
6. never expose a direct one-click POST retry from unknown-outcome state;
7. never infer success from the local action, old cache, message text, or
   absence of an error.

Retry rules:

- a read-only status check may be retried one gesture at a time;
- no automatic lifecycle POST retry;
- an explicit future POST is safe because the backend is state-idempotent, but
  it requires refreshed status and a new confirmation;
- do not attach a public idempotency key to either endpoint.

### 5.9 Session, account, and Institution isolation

Capture and verify the accepted session/account generation and target
Institution ID for every load/mutation/reconciliation completion.

A completion from an old route, target, logout, account switch, role/password
change, device-gate change, or provider generation must not:

- render protected Institution data;
- close a new session's dialog;
- show success/error in a new account;
- navigate;
- invalidate/refetch another session's detail/list/dashboard;
- enable an action for another Institution;
- reuse old request state.

On session invalidation, clear lifecycle UI state and protected detail data
through accepted mechanisms. Do not persist lifecycle state in secure storage,
local database, static fields, or cross-account caches.

The frontend must never expose or operate on another Institution because an ID
was copied, a late response arrived, or a provider key was incomplete.

### 5.10 Architecture and code organization

Use the accepted dependency direction:

```text
Institution detail action/dialog
→ focused lifecycle controller/notifier
→ Platform Institution repository
→ remote data source
→ accepted configured Dio client
```

Requirements:

- reuse the accepted Institution DTO/domain model and exact status enum;
- add focused activate/deactivate repository operations rather than a generic
  request taking arbitrary status/path/body;
- keep HTTP paths, empty-body serialization, envelope decoding, and failure
  mapping outside widgets;
- keep confirmation presentation and user interaction outside data sources;
- keep controller responsible for operation state, duplicate prevention,
  session generation, reconciliation, and invalidation orchestration;
- reuse accepted dialogs, feedback, status badges, buttons, providers, and
  failure components where their contracts fit;
- avoid a giant create/edit/lifecycle/Admin controller or speculative generic
  mutation framework;
- do not duplicate API client, auth/session store, router, Institution model,
  or cache family;
- do not add packages, production test hooks, broad refactors, or dead future
  abstractions.

### 5.11 Expected file surface

Inspect actual accepted paths before editing. Expected relevant areas include:

| Area | Expected reason |
|---|---|
| `frontend/lib/features/platform_admin/data/**` | Two exact repository/data-source lifecycle commands and typed mapping |
| `frontend/lib/features/platform_admin/domain/**` | Reuse Institution/status; focused result only if needed |
| `frontend/lib/features/platform_admin/presentation/**` | Detail action, confirmation, lifecycle state/reconciliation |
| `frontend/lib/core/network/**` | Inspect/reuse only; modify only for a proven task-local defect |
| `frontend/lib/core/auth/**` | Inspect/reuse global reconciliation; avoid redesign |
| `frontend/test/features/platform_admin/**` | Repository/controller/widget/lifecycle tests |
| existing auth/router/shell tests | Focused regression updates only if required |
| task/prompt/index files | Truthful lifecycle bookkeeping only after Phase 2 PASS |

Do not modify:

```text
backend/**
docker/**
docs/**
frontend/pubspec.yaml
frontend/pubspec.lock
```

If correct implementation requires one of those changes, stop as `BLOCKED`
unless the conflict can be resolved entirely inside this approved frontend
scope without altering the locked contract.

---

## 6. Required Automated Tests

### 6.1 Detail action and confirmation

Test at minimum:

1. Loaded `active` detail shows only `Deactivate`.
2. Loaded `inactive` detail shows only `Activate`.
3. Loading/error/not-found/unknown status exposes no lifecycle request action.
4. Action appears only on detail, not Dashboard/list/create/edit/navigation.
5. Each dialog shows correct title, Institution name, current/target state,
   consequence, Cancel, and confirm action.
6. Cancel/Escape/dismiss sends no request and restores focus safely.
7. Activation does not promise reactivation of inactive users.
8. Deactivation states access restriction and data retention truthfully.

### 6.2 Request and repository contract

Test both actions:

1. Exact POST path and method.
2. Exactly `{}` request body.
3. No query, `Idempotency-Key`, ETag/version, custom authority, or protected
   request field.
4. Accepted configured authenticated client is used.
5. Exact `200` envelope/resource mapping for transition and no-op fixtures.
6. Returned ID mismatch, wrong status, missing/wrong field, invalid enum/time,
   malformed JSON, and non-`200` `2xx` are not confirmed success.
7. Additive unknown response fields do not create protected domain fields.
8. Human `message` is not used for lifecycle branching.

### 6.3 Controller and concurrency behavior

Test at minimum:

1. One confirm creates one request.
2. Double-click, Enter repeat, source action, dialog repeat, and rebuild cannot
   duplicate an in-flight request.
3. Only one target/action is active at a time.
4. Valid no-op `200` is handled as confirmed success.
5. Submitting always resolves to recoverable non-busy UI.
6. Definite failure sends no automatic retry and requires new confirmation.
7. Timeout/disconnect and malformed/wrong-status `200` enter unknown outcome.
8. Unknown outcome issues at most one immediate detail GET.
9. Reconciled target state sends no second POST.
10. Reconciled original state requires new confirmation before a future POST.
11. Failed reconciliation exposes GET-only `Check status`.
12. No direct lifecycle POST retry exists in unknown-outcome UI.

### 6.4 Refresh, invalidation, and isolation

Test at minimum:

1. Valid current-session `200` invalidates target detail, list query family,
   and dashboard exactly once.
2. Only visible detail refetches immediately; list/dashboard do not make hidden
   requests.
3. Refreshed status changes the available action correctly.
4. Follow-up detail GET failure preserves bounded confirmed target evidence and
   offers GET-only refresh.
5. Ambiguous reconciliation to target invalidates list/dashboard without
   claiming the POST caused the state.
6. Reconciliation to original state does not show success.
7. Logout/account/session/role/password/device/route/target change discards
   late POST and GET presentation effects.
8. Stale completion cannot invalidate, navigate, notify, or expose another
   session/Institution.

### 6.5 Failure, widget, accessibility, and regression

Test at minimum:

- accepted `401`, `403` codes, `404`, `422`, `409`, `500`, ordinary HTTP,
  transport, and malformed-success behavior;
- no raw error, SQL, request header/body, token, or hidden data rendering;
- keyboard-only action/dialog flow, focus restoration, semantic labels, and
  disabled/progress announcement;
- no overflow or inaccessible confirmation/action at `800 × 600` and
  `1440 × 900` logical desktop viewports;
- Dashboard/list/detail/create/edit, direct routes, shell navigation, auth,
  password change, role/device guards, identity, and logout regressions;
- no Institution Admin or later-task UI.

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

Run focused lifecycle tests before the full suite. Do not skip either required
build. If repository scripts wrap these commands, use and report the accepted
equivalents.

From repository root inspect all tracked, staged, and untracked work:

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

`git diff main...HEAD` is not sufficient before the implementation commit
because it omits working-tree and untracked files. Open every untracked file.

Verify no:

- secret/token/contact/request-body logging;
- dependency or lockfile drift;
- raw Dio call or JSON parsing in widgets;
- non-empty lifecycle body or protected field;
- wrong endpoint/target state;
- `Idempotency-Key`/version/ETag invention;
- duplicate or automatic POST retry;
- optimistic status/count/access mutation;
- message-string business branching;
- stale-session or cross-Institution completion leak;
- hidden off-screen refresh loop;
- backend/docs/package change;
- `S02-FE-008+` scope.

Any required check not run must be reported `NOT RUN` with exact reason. Source
inspection alone is not equivalent to a passing test/build/smoke check.

---

## 8. Manual Smoke Checklist

Use the real Windows desktop Flutter app against the accepted local
PostgreSQL-backed Laravel API with controlled non-production fixtures.

### Deactivate and reconcile

1. Sign in as an active, password-complete Platform Owner.
2. Open one active Institution detail directly and from the list.
3. Verify only `Deactivate` is available and status is active.
4. Open the dialog; verify Institution name, restriction warning, retention
   statement, Cancel, and Deactivate.
5. Cancel once and prove no request/status change.
6. Confirm deactivation and attempt double-click/Enter repeat while slow;
   prove one POST only and bounded progress.
7. Verify exact confirmed `200`, one feedback, visible-detail refresh, inactive
   status, and only `Activate` action.
8. Return to list and Dashboard and verify server-refreshed status/counts with
   current filters/pagination preserved according to accepted flows.
9. Verify a target-Institution user's new login and existing-token normal
   access are blocked by backend `institution_inactive`; do not inspect or log
   credentials/tokens.

### Activate and individual eligibility

10. Open Activate dialog and verify the eligibility wording does not promise
    activation of individually inactive accounts.
11. Confirm activation; prove one POST and refreshed active detail.
12. Verify list/dashboard refresh from backend.
13. Verify an individually active Institution user is eligible again while an
    individually inactive user remains blocked by backend rules.

### Failure and isolation

14. Verify `404` target behavior is privacy-safe.
15. Verify one definite API failure shows safe recoverable UI and no success.
16. Simulate/observe an ambiguous transmitted outcome safely; verify no second
    POST, GET status reconciliation, and truthful current-status result.
17. Verify failed status check exposes GET-only `Check status`.
18. Change/logout account or navigate during an in-flight controlled request;
    verify late completion does not affect the new session/Institution.
19. Verify direct URL, edit, Back, shell, logout, password/role/device guards,
    and `800 × 600` / `1440 × 900` layouts remain usable.

Use redacted evidence only. Do not use production data or print passwords,
bearer tokens, secrets, private contact data, or full sensitive payloads.

---

## 9. Acceptance Criteria

- [ ] `S02-FE-007` began only after every required predecessor was accepted
  and delivered on synchronized `origin/main`.
- [ ] Active detail shows only Deactivate; inactive detail shows only Activate.
- [ ] Lifecycle actions exist only on Institution detail.
- [ ] Each action requires an accessible, truthful confirmation dialog.
- [ ] Cancel/dismiss sends no request.
- [ ] Each confirmed command sends exactly one POST with exactly `{}`.
- [ ] No protected fields, query, `Idempotency-Key`, ETag, version, or custom
  lifecycle authority is sent.
- [ ] Duplicate triggers and automatic POST retry are prevented.
- [ ] Exact typed `200` transition and no-op results are accepted only when ID
  and target status match.
- [ ] Success control flow does not parse the human message.
- [ ] No optimistic status, count, or access mutation exists.
- [ ] Confirmed success invalidates detail/list/dashboard once for the current
  session and immediately refreshes only visible detail.
- [ ] Follow-up detail refresh failure preserves confirmed server evidence and
  provides GET-only retry.
- [ ] Ambiguous outcomes never claim success/failure or repeat POST
  automatically; current status is reconciled through GET.
- [ ] `401`/`403`/`404`/`422`/`409`/`500`/transport/malformed responses are
  handled safely.
- [ ] Stale route/session/account/Institution completions cannot render,
  notify, invalidate, refetch, or navigate in a new context.
- [ ] Backend lifecycle/access/data-retention authority is not duplicated in
  Flutter.
- [ ] Focused and full tests, analyze, format, Windows build, APK build, scope,
  security, and real smoke checks pass or are truthfully reported.
- [ ] No backend/docs/package/later-task or unrelated change exists.
- [ ] Phase 2 is read-only and has zero unresolved P1/P2 findings.
- [ ] Accepted result is delivered through the approved branch/PR/merge flow
  and local clean `main == origin/main`.

---

## 10. Explicit Non-Goals

Do not implement:

- Institution Admin list/create (`S02-FE-008`);
- Institution Admin edit/lifecycle (`S02-FE-009`);
- Stage 2 integration closure (`S02-INT-001`);
- lifecycle actions outside Institution detail;
- list-row, Dashboard, sidebar, bulk, inline, create, or edit lifecycle UI;
- Institution settings, policy, usage, Administrator/User, role, password,
  token, learning-content, score, or report mutations;
- reason/note/force/name-confirmation fields;
- hard delete, archive, suspend, billing, license, support, notifications,
  email, audit log, or impersonation;
- optimistic status/list/dashboard mutation or local count calculation;
- automatic/background POST retry, polling, WebSocket, offline queue, or local
  persistence;
- public idempotency keys, ETags, versions, locks, or conflict protocols;
- backend/database/Docker/CI/package/locked-doc changes;
- mobile/web Platform Owner support or shell redesign;
- broad refactors or speculative abstractions.

---

## 11. Relevant Business and Security Rules

1. Only authenticated, active, password-complete desktop `platform_owner` may
   reach and use these UI actions; backend authorization remains mandatory.
2. Navigation visibility is not authorization.
3. Institution status is exactly `active|inactive` in the MVP.
4. Lifecycle actions are explicit and state-idempotent on the backend.
5. Inactive Institution users cannot use normal Institution functionality.
6. Reactivation restores eligibility only according to each user's own account
   state, first-login gate, role, relationships, and permissions.
7. Deactivation preserves Institution/user/history/settings/token data and
   does not perform hard deletion.
8. The client sends no lifecycle authority beyond the explicit endpoint.
9. Backend response and subsequent GET are authoritative; device/local state
   is not.
10. Human-readable messages may be shown but never parsed for business logic.
11. Protected data must not cross account/session/role/device/Institution
    boundaries through cache, late async completion, or direct IDs.
12. One confirmed gesture creates at most one in-flight mutation.

---

## 12. Authoritative References

| Source | Exact section | Binding requirement |
|---|---|---|
| `docs/01-business-overview.md` | User Groups; MVP Scope; Multi-Institution Model | Platform Owner manages Institution lifecycle on desktop without daily learning control |
| `docs/02-user-roles.md` | Platform Owner / Super Admin | Platform-scoped Institution control and prohibited daily-learning actions |
| `docs/03-features.md` | Institution Management; Platform Owner Features | View status and activate/deactivate Institutions |
| `docs/04-user-flows.md` | Activate Institution Flow; Deactivate Institution Flow; Institution Activation and Deactivation Flow | Detail-page action, confirmation, access effect, restoration, and retention |
| `docs/05-business-rules.md` | `BR-INST-010`–`BR-INST-015`; `BR-ROLE-004`–`BR-ROLE-009`; `BR-ACL-001`–`BR-ACL-005` | Two states, access restriction, reactivation eligibility, preservation, role/security boundary |
| `docs/06-roadmap.md` | Stage 2 — Multi-Institution Platform Management; Institution Lifecycle | Required lifecycle UI/result and stage boundary |
| `docs/07-architecture.md` | Platform-Level Super Admin; Account / Institution Status; frontend boundaries | Explicit idempotent platform actions and backend authority |
| `docs/08-database.md` | Institutions; Users and Roles; deletion/retention rules | Server-owned status/timestamp and historical preservation |
| `docs/09-api-contracts.md` | `7.6 Activate Institution`; `7.7 Deactivate Institution`; common envelopes/errors | Exact POST endpoints, `200`, idempotent behavior, and public resource |
| `AGENTS.md` | API contracts; idempotency; code quality; security/testing | No invented protocol, correct layering, full gates |
| `frontend/AGENTS.md` | Backend Authority; Authentication and Route Guards; Duplicate Mutation Prevention; Loading/Empty/Error/Success; Error UX | Typed server authority, in-flight guard, state/error/session safety |
| Accepted `S02-BE-004` | Complete contract/evidence | Exact body, response, state idempotency, access and retention semantics |
| Accepted `S02-FE-001`–`S02-FE-006` | Complete contracts/evidence | Shell, dashboard/list/detail/create/edit, invalidation, guards, isolation |
| `tasks/STAGE_02_TASK_INDEX.md` | `S02-FE-007` and successors | Exact sequence and non-goals |

Authority order:

```text
locked docs/01–09
→ applicable AGENTS.md
→ tasks/README.md and truthful Stage 2 index
→ this approved detailed task
→ accepted backend/frontend predecessor contracts
→ current accepted origin/main patterns
→ execution prompt
```

Task-level dialog wording, empty-object serialization, state machine,
duplicate protection, refresh/invalidation, ambiguous-outcome reconciliation,
and accessibility details narrow implementation ambiguity without changing
locked behavior.

---

## 13. Stop Conditions

Stop with `FINAL STATUS: BLOCKED` if:

- Stage 1 or required Stage 2 predecessors are not accepted/delivered;
- `S02-BE-004` endpoint/body/response/idempotency/error contract differs;
- accepted detail/list/dashboard/session architecture is missing or conflicts;
- Stage 2 index is missing/conflicting;
- local `main` cannot synchronize or origin is unexpected;
- unrelated dirty work exists;
- safe implementation requires backend/docs/database/Docker/CI/package change,
  broad auth/router/network/shell redesign, or later-task scope;
- exact empty-object POST, confirmation, duplicate prevention, response
  validation, refresh, ambiguity handling, or session isolation cannot be
  preserved;
- a required pre-existing frontend gate fails materially;
- safe work requires destructive Git, force-push, bypass, secret exposure, or
  overwrite of user work.

During Phase 2, unresolved P1/P2 means:

```text
FINAL STATUS: NOT ACCEPTED
```

If Phase 2 passes but delivery cannot finish:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Do not start `S02-FE-008`.

---

## 14. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git preflight

Complete Section 5.1, create/switch to the exact task branch, carry the two
approved files, and do not commit/push.

### Phase 1 — Implementation

Implement only `S02-FE-007`. Run focused/full tests, analyze, format, both
builds, complete diff/scope/security review, and real smoke. Do not commit,
push, open a PR, merge, or mark accepted.

### Phase 2 — Read-only acceptance gate

Re-read authorities, predecessors, the complete staged/unstaged/untracked
change set, tests/builds/smoke, action/dialog/request/response/state evidence,
duplicate/retry behavior, refresh/invalidation, ambiguous reconciliation, and
session/Institution isolation.

During Phase 2 make no edits; do not auto-fix, format-write, generate, stage,
unstage, commit, push, open/merge a PR, or update lifecycle state.

Severity:

```text
P1 = auth/role/device/session/Institution-isolation/secret/protected-field issue
P2 = material API/dialog/state/retry/refresh/architecture/test/build/scope issue
P3 = non-blocking observation
```

PASS requires zero unresolved P1/P2 and complete trustworthy evidence.
Otherwise return `FINAL STATUS: NOT ACCEPTED`, stop, and do not self-fix after
Phase 2 begins.

### Phase 3 — Post-acceptance delivery

Only after Phase 2 PASS:

1. Set this detailed task to `Accepted`.
2. Update only truthful `S02-FE-007` index state to Accepted/review PASS;
   delivery finalizes only after merge.
3. Apply only required task lifecycle bookkeeping.
4. Re-run final tests, builds, diff/scope/package/secret checks.
5. Stage only approved implementation, tests, task, prompt, and truthful index
   files.
6. Commit:

   ```text
   feat(platform): add institution lifecycle actions
   ```

   Body:

   ```text
   Task: S02-FE-007
   ```

7. Push `task/s02-fe-007-institution-lifecycle` to approved origin.
8. Open a PR to `main`; do not bypass checks/protection.
9. Merge only when safe and green.
10. Fast-forward-sync local `main` and prove clean `main == origin/main`.

Only then return:

```text
FINAL STATUS: ACCEPTED
```

Do not create or start `S02-FE-008`.

---

## 15. Required Codex Final Report

Return:

1. Final status and dependency/Git commit evidence.
2. Changed-file summary and exact detail-only action/status evidence.
3. Confirmation wording, accessibility, Cancel, and one-confirm behavior.
4. Exact activate/deactivate POST, `{}` body, and absence of protected fields,
   query, idempotency/version headers, and automatic retry.
5. Typed `200` transition/no-op, ID/target-status validation, and no
   message-string branching evidence.
6. In-flight duplicate protection and recoverable mutation-state evidence.
7. Confirmed-success detail/list/dashboard invalidation, visible-detail
   refresh, no hidden request, and feedback evidence.
8. `401`/`403`/`404`/`422`/`409`/`500`/transport/malformed response evidence.
9. Ambiguous-outcome GET reconciliation and no second POST evidence.
10. Session/account/route/target-Institution stale-completion isolation.
11. No optimistic cache/count/access, Admin/settings/later-scope evidence.
12. Focused/full tests, analyze, format, Windows/APK build results.
13. Complete staged/unstaged/untracked diff, package, scope, and secret review.
14. Real manual smoke results with `PASS`/`FAIL`/`NOT RUN` per item.
15. Phase 2 findings by severity and acceptance decision.
16. Final branch, commit, PR, checks, merge, and clean synchronized-main
    evidence.

Do not create or start `S02-FE-008`.
