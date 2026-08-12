# Codex Task: Platform Institution Create Form and Mutation Flow

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S02-FE-005` |
| Status | `Accepted` |
| Approved on | `2026-08-10` |
| Stage | `Stage 2 — Multi-Institution Platform Management` |
| Area | `Frontend / Platform Owner Institution creation` |
| Priority | `High` |
| Depends on | `S02-FE-004` accepted, delivered, and present on current `origin/main`; accepted `S02-BE-002` Institution create API |
| Sequence next | `S02-FE-006` |
| Repository | `https://github.com/Shoxrux2017/testlabuz.git` |
| Target branch | `task/s02-fe-005-create-institution` |
| Execution model | One focused implementation task followed by read-only acceptance and safe GitHub delivery |

---

## 2. Goal

Add the real Platform Owner Create Institution experience backed by:

```text
POST /api/v1/platform/institutions
```

The accepted result must let an eligible desktop `platform_owner`:

- start creation from the accepted Institution list;
- open the same protected create form through a direct URL;
- enter only the seven backend-approved Institution fields;
- understand required fields, exact type/status choices, nullable fields, and
  validation feedback;
- submit one deterministic create mutation without duplicate triggers;
- receive field-level backend validation safely;
- return to a refreshed Institution list after a confirmed `201`;
- open the confirmed created Institution through its server-returned UUID;
- preserve accepted shell, list, detail, dashboard, identity, logout,
  auth/password/role/device guards, and account isolation.

The frontend is not authoritative for UUIDs, actor fields, timestamps,
Institution settings, lifecycle timestamps, role ownership, or persistence.
It sends user intent; the accepted backend creates the Institution and its one
settings row atomically.

This task implements only create-form presentation and the create mutation. It
must not implement edit (`S02-FE-006`), activate/deactivate (`S02-FE-007`),
Institution Admin management (`S02-FE-008`–`S02-FE-009`), or Stage-wide E2E
closure (`S02-INT-001`).

### Scope boundary

This task owns only:

- one static protected create route:

  ```text
  /platform-owner/institutions/new
  ```

- one accessible `Create Institution` affordance on the accepted Institution
  list page;
- typed form, request, response, mutation-result, and field-error models;
- one focused create data-source/repository/controller flow;
- exact client validation that improves UX without replacing backend
  validation;
- loading/submitting, validation-error, definite-failure, ambiguous-outcome,
  and confirmed-success behavior;
- duplicate-submit prevention and stale session-completion protection;
- confirmed-success invalidation of accepted Institution list and dashboard
  data without fake local aggregation;
- focused DTO, repository, controller, widget, router, session, regression,
  accessibility, and responsive-layout tests;
- truthful Windows desktop smoke verification against the accepted backend.

It does not:

- add create as a shell destination or redesign the accepted shell;
- add fields beyond the exact create API request;
- accept or display settings during creation;
- create an Institution Admin or any User;
- generate an Institution UUID client-side;
- add `Idempotency-Key`, automatic mutation retry, background retry, or a
  client-side uniqueness rule;
- inject/reorder a fake row into the accepted server-authoritative list;
- implement edit, lifecycle, Admin, support, billing, license, subscription,
  storage-plan, global-settings, reporting, or learning behavior;
- add packages or change backend, database, Docker, CI, or locked `docs/01–09`.

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
- accepted and delivered `S02-FE-001` Platform Owner shell/navigation;
- accepted and delivered `S02-FE-002` real Platform dashboard;
- accepted and delivered `S02-FE-003` Institution list;
- accepted and delivered `S02-FE-004` Institution detail/basic usage;
- truthful Stage 2 index state for those completed tasks.

Accepted frontend foundations provide:

- Flutter, Riverpod, GoRouter, Dio, and secure token storage;
- one configured authenticated API client and typed envelope/failure mapping;
- `/api/v1/auth/me`-restored session authority;
- global `401`, account, and first-login password reconciliation;
- desktop Platform Owner role/device route guards;
- one persistent shell with Dashboard and Institutions destinations;
- real dashboard, server-authoritative Institution list, and detail route;
- accepted type/status labels and feature-first `features/platform_admin/`
  conventions;
- account-switch and stale-session isolation patterns.

Accepted backend `S02-BE-002` provides:

```text
POST /api/v1/platform/institutions
```

It accepts exactly seven public Institution fields, creates the Institution and
its settings row in one transaction, derives UUID/actor/lifecycle/timestamps
server-side, returns exact `201` data/message, and performs no write on
validation/auth failure. It does not require an `Idempotency-Key` and does not
enforce Institution-name uniqueness.

---

## 4. Dependency and Stage-Control Gate

Before implementation, prove from repository evidence:

1. Stage 1 is `Closed` and Stage DoD is `PASS`.
2. `S02-BE-001` through `S02-BE-007` are `Accepted`, reviewed `PASS`, delivered,
   and present on current `origin/main`.
3. `S02-BE-002` exposes the exact create request/response/error/transaction
   contract defined below and its PostgreSQL-backed tests pass.
4. `S02-FE-001` is accepted/delivered and owns shell, navigation, guards,
   identity, logout, and account isolation.
5. `S02-FE-002` is accepted/delivered and owns dashboard loading/invalidation
   boundaries.
6. `S02-FE-003` is accepted/delivered and owns the exact Institution list and
   its server-side query state.
7. `S02-FE-004` is accepted/delivered and owns the exact Institution detail
   route and presentation.
8. `tasks/STAGE_02_TASK_INDEX.md` matches the approved 17-task decomposition.
9. This detailed task exists exactly at:

   ```text
   tasks/frontend/stage-02/S02-FE-005-platform-institution-create-form-mutation.md
   ```

10. Its status is `Approved`.
11. Accepted API client, failure, session, router, shell, form/theme, list,
    detail, dashboard, and test foundations are present and passing.
12. No conflicting Create Institution implementation already exists.

If any dependency is missing, local `main` differs from `origin/main`, or
current evidence materially contradicts this contract, stop and return:

```text
FINAL STATUS: BLOCKED
```

Do not repair predecessor scope, recreate the backend, or absorb
`S02-FE-006+`.

This task may update only truthful `S02-FE-005` lifecycle state in the Stage 2
index. It must not create, approve, implement, or state-mutate `S02-FE-006` or
a later task.

---

## 5. Included Scope

### 5.1 Git and runtime preflight

Before editing:

1. Read root `AGENTS.md`, `frontend/AGENTS.md`, and every nearer instruction
   file completely.
2. Read `tasks/README.md`, `tasks/STAGE_02_TASK_INDEX.md`, and this complete
   task.
3. Read accepted `S02-BE-002`, `S02-FE-001`, `S02-FE-002`, `S02-FE-003`, and
   `S02-FE-004` contracts and delivery evidence.
4. Read only the locked specification sections referenced in Section 12.
5. Inspect actual current router, shell, Institution list/detail, accepted
   form primitives, session providers, API client, envelope/failure mapping,
   platform-admin controllers/models/widgets, and tests.
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
   tasks/frontend/stage-02/S02-FE-005-platform-institution-create-form-mutation.md
   tasks/frontend/stage-02/S02-FE-005-CODEX-PROMPT.md
   ```

   No other modified, staged, deleted, renamed, or untracked path is allowed.
   Neither preparation file may be committed on `main`.
8. Create/switch to exactly:

   ```text
   task/s02-fe-005-create-institution
   ```

9. Carry the two approved files to the task branch if needed and prove
   committed `main` was unchanged.
10. Use repository-pinned Flutter/Dart tooling and lockfile.
11. Run relevant pre-existing frontend gates before material edits.
12. Do not commit, push, open a PR, merge, or mark accepted before the
    read-only acceptance gate passes.

Unrelated changes are a blocker. Preserve user work and never reset, discard,
overwrite, or destructively clean it.

### 5.2 Route, list, and shell integration

Add exactly one static nested route:

```text
route: /platform-owner/institutions/new
```

Requirements:

- define it through accepted route constants/names and GoRouter structure;
- keep it inside the existing Platform Owner shell and guard family;
- ensure the static `new` route is not interpreted as the
  `:institutionId` detail route and `new` is never sent to the backend;
- keep `Institutions` selected in compact and wide navigation;
- preserve Dashboard, list, detail, identity, logout, direct URL/session
  restore, password, role, and desktop-device behavior;
- add one obvious keyboard-accessible `Create Institution` action to the
  accepted Institution-list page header/toolbar;
- do not add create to each row, dashboard, sidebar, or detail screen;
- direct URL access must enforce the same session/role/device gates before the
  form becomes usable;
- provide explicit `Cancel` / `Back to Institutions` behavior;
- when the form is dirty, use one focused confirmation before destructive
  navigation through the form's own cancel/back action; do not build a global
  navigation-interception framework in this task.

### 5.3 Exact form fields and controls

Render one accessible form containing exactly:

```text
Institution name *
Institution type *
Contact email
Contact phone
Address
Description / notes
Status *
```

Field contract:

| UI field | Request key | UI behavior |
|---|---|---|
| Institution name | `name` | Required text; maximum 200 characters; trimmed for submission; whitespace-only invalid |
| Institution type | `type` | Required allowlisted selector; no arbitrary value |
| Contact email | `contact_email` | Optional email text; maximum 254 characters |
| Contact phone | `contact_phone` | Optional text; maximum 50 characters; do not impose E.164-only validation |
| Address | `address` | Optional multiline text; do not invent an undocumented business maximum |
| Description / notes | `description` | Optional multiline text; do not invent an undocumented business maximum |
| Status | `status` | Required allowlisted selector: `active` or `inactive` |

The Institution type allowlist is exactly:

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

- map enum wire values to clear human labels through typed allowlists;
- no initial type/status choice may be silently submitted: the user must make
  each required choice unless the accepted project form convention already
  visibly establishes an approved explicit choice;
- no hidden, disabled, read-only, future, or advanced fields;
- never show/request UUID, creator, Institution Admin, timezone, upload limits,
  educational policies, lifecycle timestamp, user counts, billing, plan, or
  license values;
- use real labels, required semantics, focus order, keyboard operation, and
  error associations; placeholder text is not a label;
- status meaning must be visible in text and not color-only;
- explain briefly that inactive Institutions block normal Institution-user
  access without deleting data; do not imply users are created here;
- preserve Unicode and multiline input; render all values as safe text only;
- use accepted form/theme primitives where they fit instead of creating a
  second design system.

### 5.4 Client validation and normalization

Client validation improves immediacy but never replaces backend authority.

Before a request:

- require a non-empty trimmed name of at most 200 characters;
- require one exact typed Institution type;
- require one exact typed status;
- if contact email is non-empty, apply an accepted email validator aligned
  with the backend and at most 254 characters; do not invent a narrower regex
  that rejects addresses the accepted backend allows;
- if contact phone is non-empty, require a string of at most 50 characters;
- reject invalid control state without issuing a request;
- focus/announce the first invalid field using accepted accessibility
  patterns;
- submit whitespace-only optional values as `null`;
- trim outer whitespace from name and simple contact values;
- preserve meaningful internal whitespace and multiline address/description
  content; do not rewrite, title-case, transliterate, or sanitize into HTML;
- do not add Institution-name/contact uniqueness checks;
- do not use a preliminary list request to decide whether creation is allowed.

Backend `422 validation_failed` remains final. Map returned `errors` for the
seven approved keys to their fields. Unknown/global validation entries must be
shown safely in a form-level error area, not discarded or rendered as raw JSON.
When a user edits a field, clear only that field's stale server error; do not
erase unrelated backend errors or pretend the mutation succeeded.

### 5.5 Exact request contract

Issue only:

```http
POST /api/v1/platform/institutions
Accept: application/json
Content-Type: application/json
Authorization: Bearer <managed by accepted API client>
```

Send exactly one JSON object with all seven keys:

```json
{
  "name": "Example School",
  "type": "school",
  "contact_email": "info@example.uz",
  "contact_phone": "+998...",
  "address": "Samarkand",
  "description": "Optional notes",
  "status": "active"
}
```

Use explicit `null` for empty optional fields. Never send:

```text
id
institution_id
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
user_counts
```

Further requirements:

- no query parameters;
- no multipart/form upload;
- no client-generated UUID;
- no `Idempotency-Key` for this endpoint;
- no custom actor/role/institution headers;
- no raw URL/body construction in widgets;
- no direct Dio call from presentation;
- one user submit gesture creates at most one in-flight request;
- while in flight, duplicate submit through button, keyboard, rebuild, or
  double-click is blocked;
- no automatic retry at Dio, repository, controller, or widget level.

### 5.6 Mutation state and form lifecycle

Use one typed, session-owned mutation state capable of distinguishing:

```text
editing
submitting
validation failure
definite ordinary failure
ambiguous outcome
confirmed success
```

Rules:

- initial form creation performs no API request;
- ordinary rebuilds do not submit or reset fields;
- only an explicit valid submit starts a mutation;
- controls remain visible while submitting; prevent duplicate action and show
  bounded progress;
- do not clear the form on validation or definite failure;
- do not render fake successful data before exact `201` parsing;
- discard/ignore stale completions after logout, account/session change, route
  disposal, or a newer valid controller generation;
- a stale completion must not navigate, show success, invalidate another
  account's data, or repopulate the form;
- no autosave, draft persistence, local database, secure-storage form data, or
  cross-session field retention.

### 5.7 Exact success response and typed mapping

Require HTTP `201 Created` and consume:

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
    "updated_at": "2026-08-07T15:00:00Z"
  },
  "message": "Institution created successfully."
}
```

Typed decoding must require:

- non-empty string `id` and `name`;
- one of all nine accepted type values;
- `status = active | inactive`;
- nullable string `contact_email`, `contact_phone`, `address`, `description`;
- valid required RFC3339 `created_at` and `updated_at`;
- exact non-empty success `message` from the envelope;
- no `user_counts`, settings, actor, deactivation, User, token, or learning
  model in the create result.

Ignore additive unknown fields without rendering/modeling protected data.
Reject missing/null/wrong-type/unknown-enum/invalid-time core fields as a safe
contract failure. A `2xx` response that is not the exact accepted `201`, or a
`201` response that cannot be safely decoded, is not confirmed success.

Do not parse the human-readable success message to decide business behavior.
The `201` plus valid typed data is the success authority; the message is safe
feedback only.

### 5.8 Confirmed-success navigation and invalidation

Only after current-session exact `201` parsing:

1. prevent any second success transition;
2. invalidate the accepted Institution-list data for the current session;
3. invalidate the accepted Platform dashboard data for the current session;
4. do not issue hidden immediate requests for screens that are not active;
5. navigate to canonical `/platform-owner/institutions`;
6. retain the accepted list query state when it still belongs to the current
   session; otherwise use its canonical initial query;
7. let the accepted list refetch from the server;
8. show one safe success feedback using the accepted message;
9. provide a `View institution` action using only the server-returned UUID and
   the accepted detail route.

Do not locally inject, sort, filter, paginate, or count the created resource as
authoritative list/dashboard data. A current filter/page may legitimately hide
the new row; the success feedback and direct detail action must remain honest.
Do not claim the row is on the visible page when it is not.

### 5.9 Failure and ambiguous-outcome behavior

Handle stable failures through the accepted typed failure boundary:

| Case | Required frontend behavior |
|---|---|
| `401 authentication_required` | Clear protected form/data through accepted session invalidation and route to auth |
| `403 user_inactive` | Reconcile account state through accepted global flow; no form success |
| `403 password_change_required` | Reconcile to approved password-change flow; no form success |
| `403 forbidden` | Safe access-denied behavior; retain no cross-account protected state |
| `422 validation_failed` | Map approved keys to field errors plus safe form-level fallback; preserve entered data |
| Definite backend `500 server_error` | Safe failure; backend contract guarantees rollback; no success/navigation/invalidation |
| Other definite HTTP failure | Safe form-level failure; no raw body/stack/SQL details |
| Transport timeout/disconnect after mutation may have left the client | `Submission outcome unknown`; no automatic or one-click resend |
| `201` with invalid/missing response data | Treat outcome as unknown because server may have committed; no false success or automatic resend |

For an ambiguous outcome:

- preserve entered values only in the current in-memory form;
- explain that the request may have completed and duplicate Institution names
  are permitted;
- provide a safe `Check Institutions` / return-to-list action;
- do not expose a `Retry` action that automatically repeats the same mutation;
- do not automatically inspect list results and infer identity by name;
- do not generate a new hidden idempotency mechanism;
- never label the operation failed or successful without server authority.

For definite correctable validation/failure responses, the user may explicitly
submit again after correction/review. Even then, one gesture equals one request
and no automatic retry is allowed.

### 5.10 Session and account isolation

The form/mutation state belongs to the authenticated session generation.

On logout, invalid-token reconciliation, role/password/device redirect, or
account change:

- remove entered fields, validation errors, failure/success/unknown state, and
  pending navigation ownership;
- cancel requests where supported and ignore every late completion;
- do not show Institution data/message from the previous session;
- do not invalidate or refresh providers owned by a new session;
- do not persist form fields in a global singleton, static variable, token
  store, disk cache, or cross-account provider.

Platform Owner A's pending create state must never appear for Platform Owner B
or any other role after logout/login.

### 5.11 Architecture and code organization

Follow accepted feature-first layers:

```text
Create screen/form
  ↓
Create controller/notifier
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
- DTO/request serialization is typed and allowlisted;
- domain/application state does not depend on raw response maps;
- repository/data source reuse accepted platform-admin boundaries where that
  preserves focused responsibilities;
- do not duplicate the API client, token interceptor, session controller,
  router, shell, failure mapper, type/status enums, or form system;
- do not force unrelated list/detail/dashboard classes into one giant file;
- avoid broad abstractions for future edit/Admin forms not implemented here;
- use dependency injection/provider overrides for tests; no production
  test-only route, delay, fake response, or environment switch;
- logs must not contain bearer tokens, full request bodies, contact details,
  raw backend bodies, or secrets.

### 5.12 Expected file surface

Derive exact paths from accepted `origin/main`. A focused change may touch:

```text
frontend/lib/app/router/...
frontend/lib/features/platform_admin/data/...
frontend/lib/features/platform_admin/domain/...
frontend/lib/features/platform_admin/application/...
frontend/lib/features/platform_admin/presentation/institutions/...
frontend/test/features/platform_admin/...
frontend/test/router_... or accepted router test location
tasks/frontend/stage-02/S02-FE-005-...
tasks/STAGE_02_TASK_INDEX.md
```

Do not pre-create every suggested file. Reuse accepted patterns and keep each
responsibility focused. Any backend, database, Docker, docs, CI, package, or
lockfile change is outside scope and a blocker unless only an unchanged
generated platform file is proved irrelevant and not delivered.

---

## 6. Required Automated Tests

### 6.1 Form/request mapping

Test at minimum:

- exact nine type and two status allowlists;
- required name/type/status validation;
- name trimming, whitespace-only rejection, and 200-character boundary;
- email valid/invalid and 254-character boundary;
- phone 50-character boundary without E.164-only restriction;
- optional empty/whitespace-only values serialize as `null`;
- meaningful Unicode/multiline content is preserved safely;
- request JSON has exactly seven keys and no protected/settings fields;
- no `Idempotency-Key`, query, multipart body, client UUID, or authority field.

### 6.2 Response DTO and repository

Test at minimum:

- exact `201` response parses to typed result/message;
- all nine types, both statuses, and nullable optional fields;
- required IDs/names/timestamps and unknown enum/type/time failures;
- additive unknown response fields are ignored without entering presentation;
- `200`/other `2xx` is not accepted as exact create success;
- one repository call produces one exact POST request;
- accepted stable failures map through existing typed failure rules;
- `201` decode/contract failure maps to ambiguous outcome, not safe retry.

### 6.3 Controller and mutation lifecycle

Test at minimum:

- initial state sends no request;
- invalid local form sends no request;
- one valid submit sends exactly one request;
- double-click/keyboard/rebuild/in-flight resubmit cannot duplicate;
- field-level `422` mapping and per-field stale-error clearing;
- definite error preserves form and performs no success invalidation/navigation;
- transport ambiguity exposes no automatic resend;
- exact success invalidates current-session list/dashboard once and navigates
  once;
- late completion after dispose/logout/account change is ignored;
- one session cannot receive another session's form/error/success state.

### 6.4 Widget, route, and accessibility

Test at minimum:

- exact static route and direct protected entry;
- `new` is never treated as detail `institutionId`;
- one list-header `Create Institution` affordance;
- exact seven fields and absence of prohibited/future fields;
- keyboard traversal, labels, required/error semantics, focus, and progress;
- local validation and backend field errors;
- submit disabled/guarded during in-flight request;
- dirty cancel/back confirmation and clean cancel behavior;
- confirmed success feedback plus `View institution` action;
- ambiguous-outcome copy/actions without resend button;
- no overflow at `800 × 600` and `1440 × 900`; constrained height scrolls;
- server/form text is safe and no raw JSON appears.

### 6.5 Regression and guards

Prove:

- Dashboard, Institution list, search/filter/sort/pagination, and detail remain
  accepted;
- list state is invalidated/refetched, not locally rewritten;
- Dashboard invalidation does not create hidden polling/request loops;
- shell selection, identity, logout, and direct URLs remain accepted;
- auth, active-account, password, role, desktop-device, and session guards
  remain accepted;
- non-Platform Owner roles cannot use the create route/form;
- no edit/lifecycle/Admin/later-task controls or API calls exist;
- full pre-existing frontend suite remains green.

Use deterministic fakes/provider overrides only in tests. Do not add
production-code test seams that alter behavior.

---

## 7. Quality and Verification Commands

From `frontend/`, use repository-pinned commands/wrappers and report exact
results:

```text
flutter pub get
flutter analyze
flutter test
dart format --output=none --set-exit-if-changed lib test
flutter build windows --debug
flutter build apk --debug
```

Run focused tests first, then the full suite. Do not silently skip either
build.

Before Phase 2, from repository root run:

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

Open every untracked implementation file. Inspect complete staged, unstaged,
and untracked changes for:

- secrets, tokens, credentials, contact/request-body logging, `.env`, or
  private URLs;
- raw Dio/JSON/maps in widgets;
- duplicate API client, auth, router, shell, session, failure, or enum layers;
- wrong route ordering or `new` sent as an Institution ID;
- extra request/response fields or client authority;
- automatic mutation retry, duplicate submit, unsafe ambiguity handling;
- fake/local Institution list/dashboard aggregation;
- stale session/account completion or provider leakage;
- edit/lifecycle/Admin/later-task UI or calls;
- dependency/generated/lockfile drift;
- backend/database/Docker/docs/CI or unrelated refactors.

---

## 8. Manual Smoke Checklist

Use real Windows app, accepted Laravel/PostgreSQL runtime, and controlled
local/test data. Redact credentials/tokens/contact data.

### Confirmed creation

1. Login as an active, password-complete Platform Owner on Windows desktop.
2. Open the accepted Institution list and use `Create Institution`.
3. Confirm exact static route, shell selection, seven fields, no advanced or
   settings/Admin fields, and keyboard/focus behavior.
4. Submit empty/invalid required fields and invalid email; confirm no request
   and accessible field feedback.
5. Create one active Institution with all optional fields, Unicode, and
   multiline text; prove one exact POST and one `201`.
6. Confirm return to list, safe success message, server-backed list refresh,
   and `View institution` opens the accepted detail route with the returned ID.
7. Compare created detail values with the exact response; confirm no fake user
   counts/settings appear in create feedback.
8. Create one inactive Institution with all optional fields empty; confirm
   request nulls, inactive status, and successful server-backed list/detail.
9. Confirm list filters/pages are not silently rewritten or locally injected;
   when the current query hides the new item, feedback remains truthful.
10. Revisit Dashboard and confirm its data refetches from the server rather
    than using a locally incremented count.
11. Verify `800 × 600` and `1440 × 900`, scrolling, keyboard submit, double
    click, and screen-reader semantics.

### Validation, failure, and isolation

1. Produce controlled backend `422` errors for required/invalid fields and
   confirm exact field mapping without raw JSON.
2. Trigger a definite controlled `500 server_error`; confirm no success,
   navigation, fake row, or automatic retry and that form values remain.
3. Where safely reproducible without production hooks, interrupt transport
   after submit and confirm `Submission outcome unknown`, no resend button,
   and safe return to list. Otherwise report `NOT RUN` with reason.
4. Submit once under controlled latency, double-click/press Enter, and prove
   one request.
5. Logout or invalidate token while form is open/submitting; confirm protected
   form/error/result is removed and late completion cannot navigate.
6. Login as another Platform Owner and then another role; confirm no prior
   form values/errors/success appear and direct route guards remain correct.
7. Confirm accepted Dashboard/list/detail behaviors and no edit/lifecycle/Admin
   actions were added.

Report unavailable manual items as `NOT RUN` with exact reason. Never claim a
mocked/widget-only check as real-stack smoke.

---

## 9. Acceptance Criteria

- [ ] Dependency/Git gate is proven.
- [ ] Work occurs only on `task/s02-fe-005-create-institution`.
- [ ] Exact static protected route and one list affordance exist.
- [ ] Route cannot collide with `:institutionId`; direct URL guards work.
- [ ] Form contains exactly seven approved fields and exact enum choices.
- [ ] Client validation improves UX without replacing backend authority.
- [ ] Exact POST object contains seven keys and no client authority/settings.
- [ ] No `Idempotency-Key` or automatic mutation retry exists.
- [ ] One explicit gesture creates at most one in-flight request.
- [ ] Exact `201` data/message map through typed boundaries.
- [ ] `422`, auth, definite failure, and ambiguous outcome are safe and tested.
- [ ] Confirmed success invalidates current-session list/dashboard once,
      returns to list, and offers the real detail transition.
- [ ] No fake/local row/count/uniqueness decision exists.
- [ ] Late route/session/account completions cannot leak or navigate.
- [ ] Accessibility, keyboard, dirty-cancel, and desktop layouts are tested.
- [ ] Shell, Dashboard, list, detail, auth, role, device, and session regressions
      remain green.
- [ ] No edit/lifecycle/Admin/later-task behavior exists.
- [ ] No backend/docs/database/Docker/schema/dependency/CI change exists.
- [ ] Focused/full tests, analyze, format, Windows build, and APK build pass.
- [ ] Manual smoke is truthful and secrets/contact details are redacted.
- [ ] Phase 2 has zero unresolved P1/P2 findings.
- [ ] Final `ACCEPTED` occurs only after PR delivery, merge, and clean sync.

---

## 10. Explicit Non-Goals

- Edit Institution form/mutation (`S02-FE-006`).
- Activate/deactivate Institution UI (`S02-FE-007`).
- Institution Admin list/create (`S02-FE-008`).
- Institution Admin edit/lifecycle (`S02-FE-009`).
- Stage 2 full real-stack verification (`S02-INT-001`).
- Backend create implementation or contract changes.
- Institution settings/category/policy setup.
- Initial Institution Admin/User creation.
- Billing, subscriptions, licenses, storage plans, support/issues.
- New shell destination, shell redesign, dashboard quick-action expansion, or
  row-level create controls.
- Edit/clone/import/bulk-create/wizard/template flows.
- Client Institution UUID, client actor/role ownership, or uniqueness checks.
- Local list injection, optimistic count increment, or local sorting/paging.
- Autosave, draft persistence, offline queue, background retry, polling,
  WebSocket, cache, or cross-session form restore.
- `Idempotency-Key` or custom mutation-deduplication protocol.
- Mobile/web Platform Owner support.
- Localization/design-system overhaul.
- New packages or backend/database/Docker/docs/CI changes.

---

## 11. Relevant Business and Security Rules

1. Only an active, password-complete desktop `platform_owner` may use the
   create flow.
2. Backend authentication/authorization and validation remain authoritative.
3. Client sends only the seven public fields; UUID, actor, lifecycle timestamp,
   settings, and timestamps are server-derived.
4. Backend creates Institution and settings atomically; frontend never claims
   partial success.
5. Initial status is exactly active or inactive and must be visible user intent.
6. Inactive preserves data and blocks normal Institution-user functionality.
7. New settings are server-initialized; the form must not expose them.
8. No Institution Admin/User/category/content/result is created here.
9. Institution names/contact values are not client-authoritative uniqueness
   keys.
10. Create Institution is not one of the five locked idempotency-key mutations.
11. Ambiguous transport/response outcomes must not be auto-retried because a
    duplicate logical Institution may be created legitimately.
12. Only valid typed `201` confirms success.
13. Stable error codes/field maps, not human error messages, drive behavior.
14. Confirmed success invalidation is session-scoped and server-backed.
15. Platform Owner daily-learning/settings/Admin boundaries remain unchanged.
16. Form and response text are handled as safe text and sensitive request data
    is not logged.

---

## 12. Authoritative References

| Source | Exact section | Requirement |
|---|---|---|
| `docs/01-business-overview.md` | Multi-Institution foundation; approved roles/devices; Platform Owner overview; Institution initialization | Platform-level creation, desktop boundary, settings remain server/institution controlled |
| `docs/02-user-roles.md` | `1. Platform Owner / Super Admin`; role/device boundaries | Create authority without daily-learning interference |
| `docs/03-features.md` | `2. Platform Owner / Super Admin Features`; role/device UI section | Create Institution desktop screen and simple platform management scope |
| `docs/04-user-flows.md` | `2. Platform Owner / Super Admin Flow`; `Create Institution Flow`; boundaries | List → create form → validate → create → list/detail continuation; simple MVP form |
| `docs/05-business-rules.md` | `BR-INST-001`–`BR-INST-021`; applicable role/access rules | Tenant root, initial status/settings, lifecycle preservation, authority/boundary |
| `docs/06-roadmap.md` | `2.6`; `7. Stage 2`; Institution Management; required tests/acceptance | Create Institution is Stage 2 desktop scope |
| `docs/07-architecture.md` | `20`, `21`, `22.1`, `23`, `29`, `32.4`–`32.6`, `35` | Flutter layers, protected routes, typed API/errors/state, tests, security |
| `docs/08-database.md` | Institutions; Institution Settings; security/isolation | Server-owned UUID/actor/lifecycle/settings and exact field boundaries |
| `docs/09-api-contracts.md` | `2`, `4`, `5`, `7.3`, `12.1`, `33`, `34` | Exact endpoint/request/`201`/message/defaults/errors/security/no idempotency key |
| `AGENTS.md` and `frontend/AGENTS.md` | Applicable full rules | Workflow, typed layers/forms/states, duplicate mutation prevention, safe delivery |
| accepted `S02-BE-002` | Complete create contract/evidence | Exact validation, transaction, request, response, errors, rollback |
| accepted `S02-FE-001` | Complete contract/evidence | Shell, route family, guards, identity, logout, isolation |
| accepted `S02-FE-002` | Complete contract/evidence | Dashboard architecture and safe invalidation |
| accepted `S02-FE-003` | Complete contract/evidence | Server-authoritative list/query state and create entry point |
| accepted `S02-FE-004` | Complete contract/evidence | Static/dynamic route coexistence and created-resource detail destination |
| `tasks/STAGE_02_TASK_INDEX.md` | `S02-FE-005` and successors | Exact sequence and non-goals |

Task-level route, explicit required-choice behavior, field-error mapping,
duplicate-submit prevention, ambiguity handling, invalidation, navigation,
accessibility, and responsive details narrow implementation ambiguity without
changing locked product/backend behavior.

---

## 13. Stop Conditions

Stop with `FINAL STATUS: BLOCKED` if:

- Stage 1 or required Stage 2 predecessors are not accepted/delivered;
- `S02-BE-002` endpoint/request/response/error/transaction contract differs
  materially;
- accepted shell/list/detail/dashboard/session architecture is absent or
  conflicting;
- Stage 2 index is missing/conflicting;
- local `main` cannot synchronize or `origin` is unexpected;
- unrelated dirty work exists;
- accepted client/form/failure/test foundations are missing/broken;
- static create route cannot coexist safely with detail route;
- locked docs conflict;
- safe implementation requires package, backend/docs/database/Docker/CI change,
  broad router/auth/network/shell redesign, or later-task scope;
- exact typed request/response, ambiguity safety, duplicate prevention, or
  account isolation cannot be preserved;
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

Do not start `S02-FE-006`.

---

## 14. Execution, Acceptance, and GitHub Delivery

### Phase 0 — Git preflight

Complete Section 5.1, create/switch to exact task branch, carry the two
approved files, and do not commit/push.

### Phase 1 — Implementation

Implement only `S02-FE-005`. Run focused/full tests, analyze, format, builds,
diff/scope/security review, and manual smoke. Do not commit, push, open a PR,
merge, or mark accepted.

### Phase 2 — Read-only acceptance gate

Re-read this task, instructions, referenced locked sections, predecessors, the
complete staged/unstaged/untracked change set, tests/builds/smoke, exact route,
form, request/response evidence, validation/failure/ambiguity behavior,
invalidation/navigation, and session/account isolation.

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
2. Update only truthful `S02-FE-005` index state to Accepted/review PASS;
   delivery finalizes only after merge.
3. Apply only required task lifecycle bookkeeping.
4. Re-run final tests, builds, diff/scope/package/secret checks.
5. Stage only approved implementation, tests, task, prompt, and truthful index
   files.
6. Commit:

   ```text
   feat(platform): add institution creation flow
   ```

   Body:

   ```text
   Task: S02-FE-005
   ```

7. Push `task/s02-fe-005-create-institution` to approved origin.
8. Open a PR to `main`; do not bypass checks/protection.
9. Merge only when safe and green.
10. Fast-forward-sync local `main` and prove clean `main == origin/main`.

Only then return:

```text
FINAL STATUS: ACCEPTED
```

Do not create or start `S02-FE-006`.

---

## 15. Required Codex Final Report

Return:

1. Final status and dependency/Git commit evidence.
2. Changed-file summary and exact route/list-affordance evidence.
3. Exact seven-field form, validation, request DTO/serialization evidence.
4. Exact POST/no-idempotency/no-authority and `201` typed-result evidence.
5. `422`, auth, definite failure, ambiguous outcome, and duplicate-submit
   evidence.
6. Confirmed-success list/dashboard invalidation, navigation, feedback, and
   detail-action evidence.
7. Session/account/stale-completion isolation evidence.
8. No fake list/count/uniqueness/settings/Admin/edit/lifecycle/later-scope
   evidence.
9. Accessibility, keyboard, dirty-cancel, and responsive-layout evidence.
10. Focused/full tests, analyze, format, Windows/APK builds.
11. Diff/scope/package/secret/untracked checks.
12. Manual smoke and exact `NOT RUN` items.
13. Phase 2 findings/decision.
14. Commit/branch/PR/merge/final-sync evidence.
15. Remaining blockers/deviations.

Do not create or start `S02-FE-006`.
