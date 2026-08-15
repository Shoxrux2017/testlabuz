# Codex Task: Institution User Create

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | S03-FE-006 |
| Roadmap stage | Stage 3 — Institution Administration and User Management |
| Area | Frontend |
| Status | Accepted |
| Approved on | 2026-08-13 |
| Contract corrections reviewed | 2026-08-14 |
| Direct dependencies | S03-FE-005 and S03-BE-004 |
| Directly blocks | S03-FE-007 and S03-INT-002 |
| Transitively blocks | S03-FE-008, S03-FE-009, and Stage 3 closure |

S03-FE-004 is a transitive predecessor through S03-FE-005, not an additional
direct dependency of this task.

This task/prompt pair may be prepared before its frontend predecessor is
delivered. Production implementation must not start until both direct
dependencies are independently present on current `origin/main` as
Accepted / PASS / Delivered.

At preparation time S03-BE-004 is delivered, but S03-FE-005 is not delivered.
S03-FE-004 is also not yet delivered. Phase 0 must verify the then-current
repository truth rather than trusting this planning note. Preparing or
approving this pair does not start implementation and does not change the
Stage 3 index status by itself.

## 2. Goal

Replace only the Institution Admin User-create placeholder with an accessible
Windows desktop form that creates exactly one own-Institution Teacher, Student,
or Parent through:

~~~text
POST /api/v1/institution/users
~~~

The feature must preserve backend tenant authority, send the initial password
only in the immediate request, prevent duplicate mutation, strictly confirm the
accepted `201` response before claiming success, invalidate dependent read
data without losing the retained Users query, and replace the create route with
the server-returned User detail route.

If the POST outcome cannot be proven, the feature must never replay the POST,
never claim that the account was created, and never automatically navigate to a
possibly pre-existing matching User.

## 3. Current Context and Compatibility Requirements

### 3.1 Accepted Backend

S03-BE-004 delivers:

~~~text
POST /api/v1/institution/users
~~~

The authenticated Institution Admin's Institution and User ID are the only
tenant and creator authorities. The backend accepts only Teacher, Student, and
Parent creation, hashes the exact password, generates the UUID, creates the
User as active, requires first-login password change, and returns the shared
12-field Institution User resource.

Validation-time and concurrent global `login_name` conflicts return the same
safe `422 validation_failed` field contract. The endpoint has no public
idempotency-key contract and must never be automatically retried by Flutter.

### 3.2 Delivered Frontend Dependencies

S03-FE-001 owns:

- the static `/institution-admin/users/new` route;
- its globally unique route name and helper/constants;
- its declaration before the dynamic detail route;
- the Institution Admin shell/guard and User-create placeholder;
- canonical Users and User-detail navigation helpers.

S03-FE-002 owns the Institution Admin dashboard controller/provider and its
server-backed User totals.

S03-FE-004 owns:

- the exact InstitutionUser domain model and strict shared User parser;
- User role/status/first-login/UTC conventions;
- the exact User-list query/repository/controller and same-session retained
  query behavior;
- Create User navigation and list refresh/stale-response conventions.

S03-FE-005 owns the real server-driven User-detail route and controller. It
loads from the returned route UUID; it must not receive the create response as
authoritative cached detail data.

S03-FE-006 must reuse those delivered contracts. It must not create a second
InstitutionUser model/parser, duplicate the list data source for ordinary list
behavior, pass a password or full create result to the detail route, reset the
same-session retained list query, or reinterpret backend tenant/role rules.

### 3.3 Known Predecessor-Test Impact

Accepted FE001 tests may still assert that the create route renders a static
placeholder and performs no Stage 3 product call. Accepted FE004 tests may
assert that Create User navigates only to that placeholder.

This task intentionally makes those exact assertions obsolete. Phase 1 may
minimally update only the affected FE001 router/shell/create-placeholder tests
and FE004 Create User navigation/list-return tests so they prove the real create
owner while preserving every unrelated route, shell, list, session, and
accessibility assertion.

## 4. Included Scope

- Add one non-secret create form value/input model and exact request model.
- Add a feature-local create repository contract, response DTO, remote data
  source, repository implementation, controller, and explicit state.
- Reuse the exact FE004 InstitutionUser domain model and shared User parser.
- Replace the delivered create placeholder with the real six-field form.
- Implement exact local normalization/validation and safe server field mapping.
- Send one exact JSON POST with no query, tenant, protected, or invented field.
- Prevent duplicate submit and add no mutation auto-retry or idempotency key.
- Strictly confirm exact HTTP status, envelope, message, resource, submitted
  values, and server-derived lifecycle fields before success.
- Clear password/draft, mark Users and the Dashboard's three role totals stale,
  and replace-navigate to the server-returned detail UUID only after confirmed
  success.
- For an unprovable outcome, perform at most one bounded GET-only diagnostic
  lookup, without converting any lookup result into confirmed creation.
- Protect password, session, operation generation, route exit, and stale async
  completions.
- Add focused domain/data/application/widget/router/accessibility/regression
  tests and perform only the approved Phase 0–3 bookkeeping.

## 5. Exact Form Contract

### 5.1 Screen Fields and Initial State

The form contains exactly these six input fields in this order:

1. Role
2. Full name
3. Login name
4. Email (optional)
5. Phone (optional)
6. Initial password

Initial state:

~~~text
role = no selection
full_name = empty
login_name = empty
email = empty
phone = empty
password = empty and obscured
~~~

Do not preselect a role. This prevents an accidental Teacher/Student/Parent
choice from becoming administrator intent.

Role presentation and transport mapping:

| UI label | Request value |
|---|---|
| Teacher | teacher |
| Student | student |
| Parent | parent |

No Platform Owner, Institution Admin, custom role, permission, group, or
relationship option exists.

### 5.2 Exact Normalization and Validation

Validation length uses Unicode scalar values (`String.runes.length`), not
UTF-8 bytes or UTF-16 code units.

Apply exactly:

~~~text
role:
  required; exactly teacher|student|parent

full_name:
  trim leading/trailing whitespace before validation/request
  required non-empty string after trim
  maximum 200 Unicode scalar values after trim

login_name:
  trim leading/trailing whitespace before validation/request
  required non-empty string after trim
  maximum 191 Unicode scalar values after trim
  uniqueness remains backend-authoritative

email:
  optional
  exact empty field maps to JSON null
  a non-empty value is not silently trimmed or rewritten
  leading/trailing or internal whitespace is locally invalid
  permissive one-@ email shape for early UX validation
  maximum 254 Unicode scalar values
  backend email validation remains authoritative

phone:
  optional
  exact empty field maps to JSON null
  a non-empty value is trimmed before validation/request
  whitespace-only non-empty input is locally invalid, not silently accepted
  maximum 50 Unicode scalar values after trim

password:
  required string
  minimum 8 and maximum 255 Unicode scalar values
  never trim, normalize, generate, or modify
  obscure by default
~~~

Exact safe local feedback:

~~~text
Role: Select a role.
Full name empty: Full name is required.
Full name long: Full name must be 200 characters or fewer.
Login name empty: Login name is required.
Login name long: Login name must be 191 characters or fewer.
Email invalid: Enter a valid email address.
Email long: Email must be 254 characters or fewer.
Phone whitespace: Phone must not contain only spaces.
Phone long: Phone must be 50 characters or fewer.
Password empty: Initial password is required.
Password short: Initial password must be at least 8 characters.
Password long: Initial password must be 255 characters or fewer.
~~~

Local validation is early UX only. It must not invent global login-name
availability, tenant authority, or final backend acceptance.

### 5.3 Password Field UX

- use an obscured password field by default;
- if a visibility toggle is provided, it is an action, not a seventh field;
- label it accessibly and expose its current show/hide purpose;
- disable autocorrect and suggestions and use new-password autofill semantics;
- do not copy the password into helper text, semantics, SnackBars, validation
  summaries, state diagnostics, or test failure messages;
- display safe first-login help:

  ~~~text
  The user must change this password at first login.
  ~~~

No password confirmation field is sent or displayed because it is not part of
the accepted endpoint contract.

## 6. Exact Request Contract

### 6.1 Transport

Send exactly:

~~~text
Method: POST
Path: /api/v1/institution/users
Content type: application/json through the configured Dio client
Query: none
Body: one JSON object
Tenant selector: none
Authentication: existing configured authenticated client
Idempotency-Key: none
~~~

The JSON object always contains exactly six keys:

~~~json
{
  "role": "teacher",
  "full_name": "Teacher Name",
  "login_name": "teacher01",
  "email": null,
  "phone": "+998901234567",
  "password": "exact-initial-password"
}
~~~

Email and phone are included as JSON null when their normalized form value is
absent. Do not omit them or send empty strings.

Never send:

~~~text
institution_id
created_by_user_id
id or any UUID
is_active
must_change_password
last_login_at
deactivated_at
created_at or updated_at
password_confirmation
permissions or abilities
token or tokens
institution or creator
groups or relationships
settings or categories
learning, answer, score, result, or report fields
any query parameter or tenant-like custom header
~~~

Use only the existing configured Dio client/failure mapper. Do not add a client,
token store, interceptor, request logger, package, idempotency key, automatic
POST retry, or background mutation queue.

### 6.2 Duplicate-Submit Rule

After valid local validation begins one logical POST:

- disable Role, all text fields, password visibility, Create User, and Cancel
  while the request is in flight;
- announce the submitting state and show deterministic progress;
- repeated click, keyboard activation, Enter, double-click, or rebuild sends no
  second request;
- no timer, transport callback, Retry button, or reconciliation path can replay
  the POST.

System route exit/window close cannot guarantee server cancellation. Disposal
must clear local state and make any completion stale; it must never navigate or
show a result in a later session.

## 7. Exact Confirmed-Success Contract

### 7.1 Status and Envelope

Confirmed success requires HTTP `201 Created` and exactly these top-level keys:

~~~json
{
  "data": {
    "id": "user-uuid",
    "role": "teacher",
    "full_name": "Teacher Name",
    "login_name": "teacher01",
    "email": null,
    "phone": "+998901234567",
    "is_active": true,
    "must_change_password": true,
    "last_login_at": null,
    "deactivated_at": null,
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-07T15:00:00Z"
  },
  "message": "Institution user created successfully."
}
~~~

Reject missing, renamed, wrong-type, or additional top-level keys. The message
must be the exact accepted string. Do not parse a human-readable message to
decide any other business behavior.

### 7.2 Shared User Resource

The response DTO must delegate `data` to the exact shared FE004 parser and
InstitutionUser model. It must not copy, weaken, coerce, default, or add fields.

The resource contains exactly:

~~~text
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
~~~

Preserve all shared UUID, role, strings/nulls, JSON booleans, UTC-with-Z,
lifecycle-consistency, protected-key, and unknown-key rejection rules.

### 7.3 Request/Response Confirmation

Before claiming success, verify the parsed response against the immutable
normalized request snapshot:

~~~text
response.id = valid canonical server UUID
response.role = submitted role
response.full_name = submitted normalized full_name
response.login_name = submitted normalized login_name
response.email = submitted nullable email
response.phone = submitted nullable normalized phone
response.is_active = true
response.must_change_password = true
response.last_login_at = null
response.deactivated_at = null
~~~

The shared parser separately verifies required UTC timestamps and exact keys.

Any other 2xx, malformed envelope/resource, wrong message, protected/extra key,
or request/response mismatch is not confirmed success. Treat it as an
unprovable mutation outcome under Section 9; clear the password, do not
navigate, and do not display the returned User as newly created.

### 7.4 Confirmed Success Sequence

Only after all checks pass and the current operation/session still matches:

1. clear password and every form controller/draft;
2. mark the FE004 Users data stale while preserving the same-session retained
   query;
3. invalidate the FE002 Dashboard because exactly one Teacher, Student, or
   Parent total has increased; the Dashboard has no active/inactive split and
   each role total includes both active and inactive Users;
4. show/announce only this safe local confirmation:

   ~~~text
   User created successfully.
   ~~~

5. replace the create location through the delivered named route/helper with:

   ~~~text
   /institution-admin/users/{server-returned-id}
   ~~~

6. pass only the parsed server UUID to the route helper; pass no password,
   form, list row, DTO, or create response as detail authority;
7. allow FE005 to perform its normal fresh detail GET.

Use replace/go-style navigation so system back does not reopen a form that
contained credentials. Back from detail follows the accepted FE005/FE004
behavior to canonical Users and its retained/refetched query.

## 8. Exact Definite Failure Contract

### 8.1 Validation

An exact valid error envelope with HTTP `422` and code `validation_failed` is a
definite rejection. Map only these known field keys:

~~~text
role
full_name
login_name
email
phone
password
~~~

Use safe local field copy. For `login_name`, use:

~~~text
Review the login name; it may already be in use.
~~~

Unknown validation keys, `body`, query/protected keys, missing field errors, or
malformed envelopes become one safe form-level protocol error; do not render
the raw key/message/payload.

Retain non-secret form values. Because a POST was sent, clear the password and
focus the first invalid field in the six-field order. A deliberate new submit
requires password re-entry.

### 8.2 Authentication, Lifecycle, Authorization, and Rate Limit

- exact `401 authentication_required`: use central invalidation and immediately
  clear form/password/actions;
- `password_change_required`, `user_inactive`, and `institution_inactive`:
  clear form/password and trigger accepted auth bootstrap/reconciliation;
- exact `403 forbidden`: safe non-retryable failure, retain only non-secret
  values, clear password, and reveal no permission/tenant internals;
- exact `429 rate_limited`: safe definite failure, retain only non-secret
  values, clear password, and add no timer/automatic retry;
- every definite response requires a fresh password for another deliberate
  POST.

Safe form-level copy:

~~~text
Forbidden: You do not have permission to create users.
Rate limited: Too many requests. Wait before trying again.
Other definite failure: The user could not be created.
~~~

Do not treat `404` or `409` as normal BE004 business errors. They are not in the
accepted create contract. An unexpected status after the POST began cannot be
used as success and follows the unprovable-outcome safety rule unless a stricter
central transport classification can prove the request never left the client.

## 9. Unprovable Mutation Outcome and Diagnostic GET

### 9.1 What Is Unprovable

Treat the outcome as unprovable after a locally valid POST began when there is
no exact confirmed success or definite accepted pre-action rejection,
including:

- connection/send/receive/transform timeout or connection/unknown/cancelled
  transport failure without a valid accepted response;
- HTTP 5xx, because the action may have committed before response serialization
  failed;
- unexpected 2xx, 404, 409, or other uncontracted status;
- malformed error envelope;
- exact 201 with malformed/extra/mismatched data or wrong message.

For every unprovable outcome:

- clear password immediately;
- retain only non-secret form snapshot required for safe presentation/check;
- mark Users/dashboard data stale without destroying FE004 retained query;
- never show confirmed success;
- never replay the POST automatically or from a Retry action;
- never enable another submit in the current terminal outcome screen;
- never automatically navigate to returned or searched User detail.

### 9.2 At-Most-One Diagnostic Lookup

While the same eligible session/operation is current, the controller may issue
at most one GET-only diagnostic lookup through the delivered FE004 list
repository, using exactly:

~~~text
GET /api/v1/institution/users
role = submitted role
search = submitted normalized login_name
page = 1
per_page = 100
sort = login_name
direction = asc
status = omitted
body = zero bytes
tenant selector = none
~~~

The lookup:

- uses the exact FE004 query, strict collection/shared User parser, repository,
  authenticated client, and session scope;
- does not call Dio from the create controller;
- does not mutate FE004 committed/retained search, filters, page, rows, or
  visible list state;
- performs no page correction, second page, Retry, polling, or second GET;
- sends no password or other create body value;
- compares only parsed own-Institution public fields with the immutable
  non-secret request snapshot.

An exact matching User is only a **possible matching account**. It may have
existed before this POST, including when the lost response was a duplicate
login-name `422`. Therefore even an exact match cannot prove creation, cannot
become success, and cannot trigger automatic detail navigation.

No match, too many substring matches, a match on another page, resource
mismatch, malformed response, GET failure, or stale completion remains
inconclusive. Do not retry or broaden the search.

### 9.3 Exact Outcome-Unknown Presentation

Possible match:

~~~text
Title: Creation outcome unknown
Message: A matching user is visible, but the app cannot confirm that this request created it. Review Users before trying again.
Action: Review Users
~~~

All other unprovable cases:

~~~text
Title: Creation outcome unknown
Message: The request may have completed. Review Users before trying again.
Action: Review Users
~~~

Review Users uses the canonical named route/helper. It does not reset or inject
a search into FE004 retained query. The Users screen reloads according to its
accepted same-session behavior, and the admin may deliberately search/clear
filters there.

Never display the submitted password, raw exception, raw target, raw backend
message/payload, URL, SQL, stack trace, token, Institution ID, or internal
diagnostic reason.

## 10. Controller, Session, and Stale-Completion Safety

### 10.1 Eligibility

No create controller action or product request is allowed unless current
frontend state is all of:

~~~text
authenticated
user exists
user.role = institution_admin
user.is_active = true
user.must_change_password = false
user.institution_id is non-empty
user.institution exists
user.institution.id = user.institution_id
user.institution.status = active
approved desktop surface
~~~

The backend still re-authorizes the request and derives Institution/creator.

### 10.2 Operation Key

Bind form ownership, POST, optional diagnostic GET, state, invalidation, and
navigation to:

~~~text
session user id
session User object instance identity
institution id
immutable normalized non-secret request snapshot
operation generation
controller not disposed
~~~

The password is not part of the stored operation key/state.

Only the latest operation matching every session value may publish field
errors, definite failure, possible match, inconclusive outcome, success, or
navigation.

### 10.3 Required States

Use explicit states equivalent to:

~~~text
editing
local validation failure
submitting
server validation failure
definite non-validation failure
reconciling unknown outcome
unknown outcome with possible match
unknown outcome inconclusive
confirmed success / navigating
~~~

Rules:

- state/domain form values contain only role/full name/login/email/phone;
- password remains only in the screen's password controller and ephemeral
  request argument/object for the immediate POST;
- local validation failure sends no request and may keep the password locally;
- any completed/abandoned POST attempt clears password;
- Cancel before submit sends nothing and clears every draft;
- Cancel is disabled during submit/reconciliation; unavoidable route exit
  disposes state, clears secrets, and makes completions stale;
- logout, bootstrap transition, 401, inactive User/Institution, first-login
  requirement, Institution mismatch, same-role or cross-role account switch,
  route exit, or disposal clears all form/error/result/action state and
  invalidates generation;
- stale POST/GET success, validation, error, or possible-match completion cannot
  show UI, invalidate a later session, or navigate;
- a new session/controller cannot reuse any previous form, password, outcome,
  matching User, or operation generation;
- no global mutable singleton retains create state;
- no success/outcome state survives route disposal as authority.

Mark FE004 Users and the three FE002 Dashboard role totals stale as soon as a
valid POST is about to be sent, or through an equivalent accepted hook that
guarantees the next activation reloads even if the route is disposed before
completion. This must preserve FE004's retained query and must not
optimistically add a row or change any total. The Dashboard has no active/
inactive count split.

If the delivered FE004 controller has no narrow mark-stale/refresh-on-return
hook, this task may add the minimum tested hook inside the Institution Admin
feature. It must preserve query/session semantics and cannot become a list
rewrite.

## 11. Exact Presentation and Navigation

### 11.1 Page Structure

Use:

~~~text
Heading: Create User
Primary action: Create User
Busy label: Creating user
Secondary action: Cancel
First-login help: The user must change this password at first login.
~~~

Cancel before submit clears all fields/password and navigates through the
delivered named helper to:

~~~text
/institution-admin/users
~~~

Do not rely only on `Navigator.pop`, because direct entry may have no useful
in-app history. Normal desktop/system route exit remains safe through disposal.

### 11.2 Form and Error Accessibility

- use Material 3 and the existing Institution Admin shell/theme;
- use correct labels, optional indications, helper/error associations, input
  actions, and role semantics;
- focus the first local/server invalid field in form order after validation;
- announce a concise form-level error summary without reading password content;
- expose busy, outcome-unknown, and safe confirmation through useful live
  semantics without duplicate announcements;
- controls are keyboard operable with visible focus;
- Enter from the final field may submit once only when eligible;
- role/status/error meaning is never color-only;
- long values/errors wrap safely and no credential appears in tooltip/semantics.

### 11.3 Desktop Layout

- usable without overflow at 800x600 and 1440x900;
- usable at text scale 2.0;
- vertically scroll when form/error content exceeds viewport;
- keep predictable focus order: Role, Full name, Login name, Email, Phone,
  Initial password, password visibility when present, Cancel, Create User;
- retain clear progress and disabled semantics during submit/reconciliation;
- avoid an excessively wide form on large desktop surfaces.

## 12. Architecture and Exact Change Boundary

Required flow:

~~~text
Institution Admin User-create screen/controller
  -> Institution User-create repository
  -> Institution User-create remote data source
  -> existing configured Dio client
~~~

The optional diagnostic flow is:

~~~text
create controller
  -> delivered FE004 User-list repository with one exact query
  -> delivered FE004 remote data source
  -> existing configured Dio client
~~~

Expected new files:

~~~text
frontend/lib/features/institution_admin/domain/institution_user_create.dart
frontend/lib/features/institution_admin/domain/institution_user_create_repository.dart
frontend/lib/features/institution_admin/data/dto/institution_user_create_dto.dart
frontend/lib/features/institution_admin/data/institution_user_create_remote_data_source.dart
frontend/lib/features/institution_admin/data/institution_user_create_repository_impl.dart
frontend/lib/features/institution_admin/application/institution_user_create_state.dart
frontend/lib/features/institution_admin/application/institution_user_create_controller.dart
~~~

Expected delivered placeholder to modify:

~~~text
frontend/lib/features/institution_admin/presentation/institution_admin_user_create_screen.dart
~~~

If FE001 used a different focused placeholder filename, modify only that
equivalent and report the exact mapping.

Expected focused tests:

~~~text
frontend/test/features/institution_admin/institution_user_create_form_value_test.dart
frontend/test/features/institution_admin/institution_user_create_dto_test.dart
frontend/test/features/institution_admin/institution_user_create_remote_data_source_test.dart
frontend/test/features/institution_admin/institution_user_create_repository_impl_test.dart
frontend/test/features/institution_admin/institution_user_create_controller_test.dart
frontend/test/features/institution_admin/institution_admin_user_create_screen_test.dart
~~~

Conditionally allowed minimal list-stale hook, only if delivered FE004 lacks one:

~~~text
frontend/lib/features/institution_admin/application/institution_user_list_controller.dart
the exact corresponding FE004 controller/list tests
~~~

Conditionally allowed delivered route wiring if the placeholder route does not
already construct the real create screen:

~~~text
frontend/lib/app/router/app_router.dart
the exact existing Institution Admin router test file(s)
~~~

No route name/path/helper/order/classification or shell topology change is
allowed. `app_route_paths.dart` is inspect-and-preserve.

Conditionally allowed predecessor-regression updates made obsolete only by this
task:

~~~text
the exact FE001 create-placeholder/no-Stage-3-request test file(s)
the exact FE004 Create User navigation/list-return test file(s)
the exact FE002 dashboard invalidation regression test when its provider is exercised
the exact FE005 fresh-detail-navigation regression test when necessary
~~~

Each conditional change must be minimal, preserve unrelated assertions, and be
named in the final report. Stop rather than widening scope.

Inspect and reuse but do not modify unless explicitly allowed above:

~~~text
frontend/lib/core/network/
frontend/lib/features/auth/
frontend/lib/features/platform_admin/
other Institution Admin screens/controllers
backend/
docs/01-09
frontend/pubspec.yaml
frontend/pubspec.lock
~~~

No backend/schema/docs/package/core-network/auth/Platform change, new route,
shell redesign, list rewrite, fake API, lifecycle/edit mutation, idempotency
infrastructure, or unrelated cleanup is allowed.

Task lifecycle files allowed only as Section 16 permits:

~~~text
tasks/frontend/stage-03/S03-FE-006-institution-user-create.md
tasks/frontend/stage-03/S03-FE-006-CODEX-PROMPT.md
tasks/STAGE_03_TASK_INDEX.md
tasks/README.md
~~~

## 13. Authoritative References

Read in this order:

1. root `AGENTS.md`;
2. `frontend/AGENTS.md`;
3. this complete detailed task and paired prompt;
4. `tasks/README.md` and `tasks/STAGE_03_TASK_INDEX.md`;
5. accepted S03-INT-001 contract/task-control record;
6. `docs/02-user-roles.md`: Institution Admin and managed roles;
7. `docs/03-features.md` and `docs/04-user-flows.md`: account creation flow;
8. `docs/05-business-rules.md`: tenant, role, lifecycle, first login, secrets;
9. `docs/06-roadmap.md`: Stage 3 scope and Stage 4 exclusion;
10. `docs/07-architecture.md`: Flutter layers, session, mutation, security;
11. `docs/08-database.md`: User fields, limits, global login uniqueness;
12. `docs/09-api-contracts.md`: general envelopes/errors and Sections 8.2/8.3/
    8.4 after S03-INT-001;
13. accepted S03-BE-004 task, implementation, tests, review, and delivery;
14. delivered S03-FE-001, FE002, FE004, and FE005 code/tests;
15. accepted Stage 2 Platform create patterns only as structural/secret-safety
    reference, not as Institution User contract authority.

If locked documents, accepted backend, this task, or delivered frontend
dependencies conflict, stop and report exact sections. Do not silently choose,
change backend behavior, loosen parsing, or invent a mutation-retry rule.

## 14. Acceptance Criteria

- [ ] Phase 0 proves S03-FE-005 and S03-BE-004 are each
      Accepted / PASS / Delivered on current origin/main.
- [ ] FE004 is treated as a transitive predecessor and its shared contracts are
      present through delivered FE005.
- [ ] Exact six fields/order, empty initial state, no role default, three roles,
      normalization, Unicode limits, nulls, and safe local errors are proven.
- [ ] Password is exact/untrimmed, obscured, absent from state/persistence/logs,
      and cleared at every required boundary.
- [ ] Exact POST path/content type/six-key JSON/no query/no tenant/no protected
      fields/no idempotency key are proven.
- [ ] One valid intent sends one POST; duplicate triggers send no second POST.
- [ ] Exact 201/data+message/shared 12-field parser and submitted/server-derived
      confirmation are required before success.
- [ ] Invalid/mismatched success cannot navigate or claim creation.
- [ ] Exact 422 field mapping, 401/lifecycle bootstrap, forbidden, rate limit,
      unexpected status, 5xx, and malformed response behavior are safe.
- [ ] Every sent POST clears password before another deliberate attempt.
- [ ] No path automatically retries or replays POST.
- [ ] At most one exact GET diagnostic occurs for an unprovable outcome, with no
      body/password/tenant and without changing FE004 retained query/state.
- [ ] A possible matching User remains unconfirmed and never triggers success
      or automatic detail navigation.
- [ ] Unknown outcome has exact safe copy and Review Users only.
- [ ] Eligibility, session object identity, Institution, generation, disposal,
      account switch, logout, 401, route exit, and stale completion are proven.
- [ ] Users and the Dashboard's three role totals are marked stale without
      optimistic row/total mutation or retained-query loss, including route
      exit after POST start; no active/inactive Dashboard count is invented.
- [ ] Confirmed success clears all data, shows safe copy, replace-navigates by
      parsed server UUID, and FE005 performs a fresh GET.
- [ ] Cancel/direct entry/system back and FE004 retained-list return are safe.
- [ ] Compact/wide desktop, text scale 2.0, scrolling, keyboard, focus,
      semantics, live announcements, and non-color states pass.
- [ ] Narrow FE001/FE002/FE004/FE005 regressions are sufficient; full frontend
      suite and Windows build pass.
- [ ] No update/lifecycle/password reset/relationship/settings/learning/Stage 4
      behavior or scope drift exists.

## 15. Required Tests and Verification

### 15.1 Form Value and Request

- no role default and exact role label/code mapping;
- trimming for full name/login/phone and no password mutation;
- exact empty email/phone to null behavior;
- whitespace email/phone rules;
- every required, exact-empty, min/max and max+1 boundary using Unicode scalar
  values, including non-BMP input;
- permissive local email shape without becoming backend authority;
- exact six-key JSON including null contacts and password exact bytes/string;
- no protected/tenant/confirmation/idempotency/extra key;
- equality/copy/state never includes password.

### 15.2 DTO, Remote Data Source, and Repository

- exact 201 with data+exact message and each role/null/contact combination;
- shared FE004 User parser reuse, not copy;
- missing/extra/wrong top-level keys, message, resource keys/types, UUID, role,
  boolean, UTC, lifecycle, protected fields;
- exact submitted field match and server-derived active/first-login/null
  lifecycle confirmation;
- wrong role/name/login/email/phone, inactive, first-login false, non-null last
  login/deactivated, malformed ID, wrong status/message become unknown outcome;
- exact configured Dio POST path, JSON body, no query, no Institution/header,
  no Idempotency-Key, and no automatic retry;
- exact valid 401/403/422/429 mapping;
- 5xx, timeout/connection/cancel/unknown, unexpected status, invalid envelope,
  and response mismatch classification;
- repository mapping does not expose password or raw transport data.

### 15.3 Controller, Session, Invalidation, and Reconciliation

- complete ineligible-session matrix sends no product request;
- one submit and duplicate click/keyboard/Enter/rebuild suppression;
- local validation no request/password wipe behavior;
- every server field and unknown-field form-level mapping/focus order;
- password clearing after every sent POST result and all cancel/session/dispose
  boundaries;
- confirmed success sequence, exact invalidation, retained query preservation,
  safe confirmation, returned-UUID replace navigation, and fresh detail load;
- list/dashboard marked stale even when route exits after POST begins;
- no optimistic list row/count or create-response detail seeding;
- exact one diagnostic GET query and zero POST replay;
- possible exact match, pre-existing identical match, no match, later-page
  possibility, multiple substring rows, mismatch, malformed list, GET failure,
  GET 401, and no second GET/retry;
- possible match never becomes success or auto-navigation;
- stale POST/GET success/validation/error after logout, bootstrap, same-role/
  cross-role switch, Institution change, new controller, route exit, disposal;
- central 401/lifecycle reconciliation and no prior-session navigation.

### 15.4 Screen, Router, Accessibility, and Regressions

- direct eligible `/users/new`, reload/rebuild, selected Users destination, and
  exact page title/form;
- exact fields/order/labels/options/help/actions/local/server errors;
- password obscured, accessible toggle when present, no secret in semantics;
- Cancel before submit no request and canonical Users navigation;
- submit busy state, disabled controls, one activation, focus/live semantics;
- confirmed success safe SnackBar/announcement and detail route by server UUID;
- unknown outcome exact two variants and Review Users only;
- no Retry POST or automatic matching-detail action;
- FE004 retained query/refetch and FE002 dashboard refresh behavior;
- FE005 fresh detail GET and no cached create resource authority;
- 800x600, 1440x900, text scale 2.0, long values/errors, scrolling, no overflow,
  keyboard, visible focus, tooltips, semantics, and non-color meaning;
- no edit/activate/deactivate/reset/bulk/import/invite/relationship/settings/
  category/learning controls;
- minimal FE001 placeholder/no-request and FE004 navigation regression updates;
- full auth/router/shell/dashboard/profile/list/detail/Platform regressions.

### 15.5 Commands

Run from `frontend`:

~~~text
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/features/institution_admin
flutter test test/app/router
flutter test
flutter build windows --debug
~~~

Also run:

- focused tests for every conditionally modified predecessor file;
- tracked-file allowlist and complete diff review;
- credential/secret/password-log scan;
- prompt byte comparison before Phase 3;
- current configured repository quality gates.

Do not claim a command passed unless its final exit status/output was observed.

### 15.6 Manual Windows Real-Stack Smoke

With controlled credentials/passwords that are never copied into reports,
logs, screenshots, or task files:

- create one Teacher, Student, and Parent and verify exact detail/first-login;
- cancel before submit and verify zero POST;
- local validation and duplicate global login `422`;
- optional/null contacts and trimmed full/login/phone behavior;
- duplicate-click/Enter protection;
- confirmed success list/dashboard reload and detail route;
- safely induced uncertain response when available, proving zero replay and no
  false success/automatic detail navigation;
- logout/401/account switch clears form/password and blocks stale navigation;
- compact/wide/text-scale/keyboard/focus/semantics behavior;
- no protected/tenant/relationship/later-stage data or controls.

If the real stack, Windows runner, safe unique test login, or failure injection
is unavailable, mark that exact item NOT RUN with reason. Never fabricate
evidence, expose credentials, or create duplicate/shared production data merely
to prove a test.

## 16. Required Workflow and Delivery

Branch:

~~~text
task/s03-fe-006-institution-user-create
~~~

### Phase 0 — Git Preflight

1. Read the paired prompt and all Section 13 authority completely.
2. Verify this detailed task is Approved.
3. Verify S03-FE-005 and S03-BE-004 are each
   Accepted / PASS / Delivered on current origin/main; otherwise stop BLOCKED.
4. Verify delivered FE004 contracts are present through the frontend dependency
   chain and consistent with FE005.
5. Verify the expected GitHub origin, fetch safely, and prove
   local main == origin/main.
6. Verify a clean worktree except only the owner-prepared S03-FE-006 task/prompt
   when they are not yet committed.
7. Resolve delivered create route/placeholder, shared User parser/model,
   list/dashboard providers and retained-query invalidation, detail navigation,
   session patterns, and exact affected predecessor tests.
8. Prove which conditional files in Section 12 are actually necessary.
9. Create/switch to `task/s03-fe-006-institution-user-create` from approved main.
10. Preserve unrelated user work and stop on dirty/conflicting/unsafe state.
11. Do not commit, push, create a PR, or merge before Phase 2 PASS.

### Phase 1 — Implementation

Implement only Sections 4–12.

Before Phase 2:

- update only the S03-FE-006 Stage 3 index row to
  In Progress / Not started / Not started;
- minimally update directly adjacent Stage index narrative/count/next-gate text
  only where necessary so it does not falsely call S03-FE-006 Draft;
- do not change another task's status/review/delivery values;
- keep this detailed task status Approved;
- preserve the paired prompt byte-for-byte;
- do not update `tasks/README.md` acceptance/delivery state;
- run every required check and inspect the complete diff;
- do not stage, commit, push, create a PR, or merge.

### Phase 2 — Read-Only Acceptance Gate

Re-read all authority and review the complete result/diff: form, request,
password, status/envelope/resource confirmation, error/outcome classification,
no replay, diagnostic GET, session/stale safety, invalidation, navigation,
disclosure, accessibility, predecessor regressions, tests/build/smoke, scope,
bookkeeping consistency, and secrets.

Phase 2 is strictly read-only:

~~~text
no edits, auto-fix, or write-format
no task/index/README bookkeeping edits
no staging or commit
no push, PR, or merge
no self-fixing findings
~~~

Classify:

- P1: tenant/session/password/protected-data disclosure, duplicate/destructive
  mutation, false confirmed success, stale cross-session navigation, destructive
  Git, secret exposure, or read-only-gate violation;
- P2: material form/request/envelope/resource/confirmation/error/reconciliation/
  invalidation/navigation/accessibility/architecture/test/workflow mismatch,
  mutation replay, stale-state gap, regression, or scope drift;
- P3: non-blocking observation without correctness, security, evidence, or
  maintainability acceptance impact.

Any unresolved P1 or P2 returns:

~~~text
FINAL STATUS: NOT ACCEPTED
~~~

Stop without delivery and do not start S03-FE-007. Report all P3 findings; P3
alone does not block PASS.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 PASS with no unresolved P1/P2:

1. Change only this detailed task status from Approved to Accepted without
   rewriting approved behavior.
2. Prepare only the S03-FE-006 index row as Accepted / PASS / Delivered and
   update directly related narrative/count/next-gate consistency.
3. Update `tasks/README.md` truthfully: Stage 3 remains In Progress,
   S03-FE-006 is delivered, and S03-FE-007 is the next implementation gate.
4. Preserve every later task's truthful state, keep Stage 3 open, and keep
   Stage 4 blocked.
5. Preserve the paired prompt byte-for-byte.
6. Re-run final non-writing diff/scope/secret/prompt/consistency checks.
7. Stage only approved implementation/tests, this task, unchanged prompt,
   Stage index, and README.
8. Commit:

   ~~~text
   feat(institution): add user creation UI

   Task: S03-FE-006
   ~~~

9. Push the exact branch, open a PR to main, verify base/head/diff/checks, and
   merge only when safe/green and permitted.
10. Fast-forward local main and prove local main == origin/main with a clean
    worktree.

The prepared Accepted / PASS / Delivered values become authoritative only after
the delivery commit is merged and equality/clean verification passes.

Phase 2 PASS but incomplete safe delivery returns:

~~~text
FINAL STATUS: DELIVERY BLOCKED
~~~

Complete verified delivery returns:

~~~text
FINAL STATUS: ACCEPTED
~~~

## 17. Explicit Non-Goals

- User edit, activate, deactivate, delete, archive, password reset, role/login
  change, bulk action, import/export, invitation, credential delivery, or
  impersonation.
- Institution Admin or Platform Owner creation.
- Group/Teacher/Student/Parent relationships or assignments.
- Institution profile/settings, categories, topics, materials, Homework,
  Blitz, attempts, answers, scores, results, reports, or Stage 4+ behavior.
- Client-generated User UUID, tenant/creator/lifecycle/first-login authority.
- Idempotency-Key, automatic POST retry/replay, offline/background mutation.
- Treating diagnostic lookup as proof of creation.
- Passing create response/list row as detail authority.
- New route family/path/helper, shell redesign, mobile Institution Admin UI.
- Backend/schema/docs/core-network/auth/Platform/package changes.
- Broad predecessor refactor or unrelated cleanup.

## 18. Stop Conditions

Stop and report before expanding scope if:

- either direct dependency is not Accepted / PASS / Delivered;
- locked docs, accepted S03-BE-004, this task, or delivered frontend contracts
  conflict;
- the shared FE004 User parser or FE004 list repository cannot be reused;
- a safe list-stale hook cannot preserve the retained query;
- exact response confirmation, password non-retention, no-replay behavior, or
  stale session/navigation isolation cannot be proven;
- backend, route contract/topology/helper, package, core/auth/Platform,
  idempotency infrastructure, or later mutation change appears necessary;
- required changes materially exceed Section 12;
- full regression requires unrelated correction;
- repository/Git/GitHub state is unsafe;
- any Phase 2 P1/P2 exists.

## 19. Required Codex Final Report

Report:

- FINAL STATUS;
- Phase 0 origin/main/branch/dependency/clean evidence;
- every changed file/layer and each conditional-file justification;
- exact form order/default/normalization/Unicode/null/local-validation evidence;
- password location, request-only lifetime, clearing matrix, and no-log proof;
- exact POST/path/six-key body/no-query/no-tenant/no-protected/no-idempotency;
- exact 201/envelope/message/shared parser/request-response/lifecycle proof;
- definite failure and unprovable-outcome classification;
- zero POST replay and exact at-most-one diagnostic GET evidence;
- proof that possible match never becomes success/automatic detail navigation;
- session eligibility/key/dedup/latest-generation/disposal/stale evidence;
- Users/dashboard stale hook, retained-query preservation, and no optimistic
  row/count evidence;
- confirmed-success clearing/confirmation/returned-UUID replace navigation and
  FE005 fresh-detail proof;
- Cancel/direct entry/back/list-return/navigation evidence;
- responsive/keyboard/focus/semantics/live-region/non-color evidence;
- predecessor regression updates and preserved assertions;
- every command/test count/result, Windows build, and truthful smoke status;
- P1/P2/P3 findings, scope/secret/prompt/bookkeeping/non-goal checks;
- PR/merge SHA/local-main/origin-main/clean delivery evidence when applicable.

End with:

~~~text
No User edit/lifecycle/password reset, client tenant authority, mutation replay,
false reconciliation success, protected data, relationship, settings/category,
learning, or Stage 4 behavior was implemented.
Next implementation gate: S03-FE-007.
~~~
