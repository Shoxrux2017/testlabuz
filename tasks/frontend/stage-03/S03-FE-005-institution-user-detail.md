# Codex Task: Institution User Detail

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | S03-FE-005 |
| Roadmap stage | Stage 3 — Institution Administration and User Management |
| Area | Frontend |
| Status | Accepted |
| Approved on | 2026-08-13 |
| Direct dependencies | S03-FE-004 and S03-BE-003 |
| Directly blocks | S03-FE-006 and S03-INT-002 |
| Transitively blocks | S03-FE-007 through S03-FE-009 and Stage 3 closure |

This task/prompt pair may be prepared before its frontend predecessor is
delivered. Production implementation must not start until both S03-FE-004 and
S03-BE-003 are independently present on origin/main as
Accepted / PASS / Delivered.

At preparation time S03-BE-003 is delivered, but S03-FE-004 is not yet
delivered. Phase 0 must verify the then-current repository truth rather than
trusting this planning note. Preparing or approving this pair does not start
implementation and does not change the Stage 3 index status by itself.

## 2. Goal

Replace only the Institution Admin User-detail placeholder with a real,
read-only Windows desktop screen for one own-Institution Teacher, Student, or
Parent.

The screen loads the route target from the backend through:

~~~text
GET /api/v1/institution/users/{user}
~~~

It must support list-to-detail navigation, direct URL entry, reload, browser/
Windows back behavior, exact shared User parsing, truthful public-field display,
safe scope-indistinguishable not-found handling, manual refresh, retryable-error
recovery, and complete target/session stale-response isolation.

S03-FE-001 remains authoritative for the frontend route's canonical UUID shape.
The backend revalidates that UUID and remains authoritative for target
existence, tenant scope, and eligible role. This task implements no edit or
lifecycle mutation.

## 3. Current Context and Compatibility Requirements

### 3.1 Accepted Backend

S03-BE-003 delivers:

~~~text
GET /api/v1/institution/users/{user}
~~~

The authenticated actor's Institution is the only tenant authority. After
authentication/lifecycle/password/role middleware and exact input validation,
the backend treats these targets identically:

~~~text
malformed UUID
unknown UUID
foreign-Institution UUID
Platform Owner UUID
Institution Admin UUID
~~~

Each returns the same:

~~~text
404 resource_not_found
~~~

A successful target is an own-Institution User whose role is exactly teacher,
student, or parent. The backend executes one scoped User query and returns only
the exact shared 12-field User resource.

### 3.2 Delivered Frontend Dependencies

S03-FE-001 owns the existing shell, exact detail route, decoded userId path
parameter, route helper, direct-entry guard, and User-detail placeholder.
Its accepted route contract allows only one canonical hyphenated UUID-shaped
`userId` (8-4-4-4-12 hexadecimal characters, case-insensitive). Malformed
detail locations are rejected by the route/guard before this screen is built.

S03-FE-004 owns:

- the exact InstitutionUser domain model;
- the strict shared User row DTO/parser;
- User role/status/first-login/UTC formatting conventions;
- list row navigation by parsed server UUID;
- same-session retained list query behavior;
- session eligibility/keying and stale-operation conventions.

S03-FE-005 must reuse those accepted contracts. It must not create a second
different User model/parser/label policy, accept a looser detail resource, pass
an entire list row as detail authority, or reinterpret backend not-found rules.

If the delivered FE004 row parser is private inside its list DTO, this task may
minimally extract it into one shared feature-local InstitutionUserDto file and
make the list/detail envelope DTOs delegate to it. The extraction must preserve
FE004 behavior and tests exactly; duplicating the parser is not acceptable.

### 3.3 Known Predecessor-Test Impact

Accepted FE001 tests may still assert that the detail route renders a
placeholder and performs no Stage 3 API call. Accepted FE004 tests may assert
navigation only to that placeholder.

S03-FE-005 intentionally makes those exact assertions obsolete. Phase 1 may
minimally update only the affected FE001 router/shell/detail-placeholder tests
and FE004 row-navigation tests so they prove the new detail owner while
preserving all unrelated route, shell, list, session, and accessibility
behavior. This narrow regression update is in scope and must not become a broad
test rewrite.

## 4. Included Scope

- Reuse the exact InstitutionUser domain model and strict shared User parser
  delivered by S03-FE-004.
- Add one exact detail-envelope DTO around the shared User parser.
- Add a feature-local detail repository contract, remote data source, repository
  implementation, controller, and state.
- Bind loading strictly to the decoded route userId, current session, and
  operation generation.
- Safely construct the backend URL as one encoded path segment.
- Send no query keys, request body, Institution selector, or invented context.
- Render all 12 approved public fields with exact labels/null/timestamp rules.
- Implement initial loading, refreshing data, scope-safe backend not found,
  retryable error, non-retryable error, and defensive local invalid-target
  handling if the screen/controller is ever invoked outside the accepted route.
- Implement canonical Return to Users navigation and preserve normal system/
  browser back behavior.
- Add exact direct-route, encoded-path, target-mismatch, disclosure, stale-state,
  responsive desktop, keyboard, focus, semantics, and regression tests.
- Perform only the approved Phase 0–3 task/index/README bookkeeping.

## 5. Exact Route-Target Contract

### 5.1 Target Authority and FE001 Route Grammar

The only target source is the decoded, FE001-validated GoRouter path parameter:

~~~text
userId
~~~

Never use:

~~~text
list row object as detail authority
search text
row index
full_name
login_name
email
phone
query parameter
client-provided institution_id
cached previous target
~~~

The list may navigate using its parsed server UUID, but the detail screen still
loads from the route and server. It must work identically on direct entry and
reload when no list state exists.

S03-FE-005 must preserve the accepted FE001 route grammar exactly:

~~~text
canonical hyphenated UUID shape
8-4-4-4-12 hexadecimal characters
case-insensitive
~~~

Do not broaden the route helper/classifier to accept arbitrary segments.

### 5.2 Frontend Structure Versus Backend Authority

Apply these exact rules:

1. Read the already-decoded route parameter once; do not manually decode it a
   second time.
2. Do not trim, lowercase, canonicalize, or rewrite the value before request.
3. The FE001 route/helper/guard accepts only the canonical UUID shape above.
4. Missing, empty, whitespace, `new`, non-UUID, incomplete/extra UUID, slash,
   backslash, dot-traversal, control, query/fragment, percent-encoded separator,
   and extra-path locations are not approved detail routes. They resolve through
   FE001's accepted safe fallback to canonical `/institution-admin`, do not
   construct the detail screen, and issue no detail GET.
5. Preserve that route classification and fallback. Do not turn malformed input
   into a backend request or a detail-screen not-found state.
6. If the screen/controller is invoked directly in a unit/widget test or future
   regression with a missing/noncanonical target, fail closed locally, publish
   no User data, and issue no request.
7. Every FE001-valid canonical UUID target is safely encoded once and sent to
   the backend. The backend remains authoritative for existence, tenant, and
   eligible role.
8. Do not perform client-side existence, tenant, role, active-state, or record
   lookup.
9. Valid but unknown, foreign-Institution, Platform Owner, and Institution Admin
   UUIDs all use the same accepted backend `404 resource_not_found` presentation.

The backend itself also returns uniform 404 for malformed UUIDs sent by another
client. That BE003 API guarantee remains unchanged, but the accepted TestLabUz
Flutter route does not deliberately send malformed UUIDs.

The route:

~~~text
/institution-admin/users/new
~~~

must always resolve to the delivered create placeholder/owner route and must
never construct the detail screen or send a detail GET. Route ordering,
classification, direct entry, reload, and selected Users navigation require
regression tests.

### 5.3 Path Construction

The remote data source receives the decoded FE001-valid canonical UUID and
constructs:

~~~text
/api/v1/institution/users/{Uri.encodeComponent(target)}
~~~

Requirements:

- encode exactly once as a path segment;
- never concatenate an unencoded target into a URL;
- the input has already passed FE001 canonical UUID structure validation;
- uppercase/lowercase hexadecimal UUID forms remain the exact route value and
  cannot become query, fragment, or another path component;
- no queryParameters map, even an empty feature map, is required;
- no request data/body argument is sent;
- no Institution ID or tenant-like custom header is sent;
- use only the existing configured authenticated Dio client;
- do not add a feature-specific client, token handling, interceptor, logger, or
  retry policy.

The feature initiates one logical GET per initial load, Refresh, or allowed
Retry. The accepted central safe-GET transport behavior may remain unchanged.

## 6. Exact HTTP and Response Contract

### 6.1 Request

~~~text
Method: GET
Path: /api/v1/institution/users/{encoded-valid-user-id}
Query: none
Body: zero bytes
Tenant selector: none
Auth: existing configured client
~~~

Do not send:

~~~text
{}
[]
JSON null
whitespace body
data from list row
institution_id
role/status fields
include/expand fields
any query key
~~~

### 6.2 Success Envelope

HTTP 200 contains exactly one top-level key:

~~~json
{
  "data": {
    "id": "user-uuid",
    "role": "teacher",
    "full_name": "Teacher Name",
    "login_name": "teacher01",
    "email": null,
    "phone": "+998...",
    "is_active": true,
    "must_change_password": true,
    "last_login_at": null,
    "deactivated_at": null,
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-07T15:00:00Z"
  }
}
~~~

There is no success:

~~~text
message
meta
pagination
links
included
relationship
~~~

The detail envelope parser must reject a missing/renamed/wrong-type data value
and any unexpected top-level key. It then delegates data to the exact shared
FE004 User parser; it must not duplicate, weaken, coerce, or default it.

### 6.3 Shared User Resource

The reused resource has exactly:

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

It preserves all FE004 strict rules:

- id is a canonical server UUID;
- role is exactly teacher, student, or parent;
- required strings, nullable strings, JSON booleans, and nullable/required UTC
  timestamps have their exact accepted types;
- non-null timestamps are valid UTC values ending in Z;
- active/deactivated lifecycle consistency is exact;
- missing, malformed, unknown, or protected resource keys are rejected;
- values are not trimmed, invented, coerced, or replaced.

The domain and DTO must never model, cache, render, log, or navigate with:

~~~text
institution_id
created_by_user_id
creator
password or password hash
remember token
Sanctum tokens
permissions
Institution settings
relationships
learning records, answers, scores, or results
~~~

### 6.4 Response Target Match

A 200 response must identify the requested target:

- the requested route value must parse as a UUID if the backend returned 200;
- the parsed response User.id must represent the same UUID as the requested
  target, allowing only case differences in a syntactically equivalent UUID;
- a valid but different response UUID is an invalid response;
- target mismatch clears any displayed data and surfaces only the safe
  non-retryable invalid-response error.

Do not silently redirect to the returned ID, rewrite the URL, or display a
different User than the route requested.

## 7. Exact Error and Not-Found Contract

### 7.1 Dedicated Not Found

Use the dedicated not-found presentation only for:

- defensive direct screen/controller invocation with a missing/noncanonical
  target and no request; or
- backend HTTP 404 with stable code resource_not_found for an FE001-valid UUID
  and a valid accepted
  error envelope.

All backend scope-safe cases use identical presentation:

~~~text
Title: User unavailable
Message: This user does not exist or is not available to your account.
Action: Back to Users
~~~

Do not display:

- the attempted target;
- whether the record exists;
- whether it is foreign;
- its actual role or Institution;
- the raw backend message or payload.

A definitive not-found state has no Retry or Refresh button. A user may perform
a normal browser/app reload, but the feature does not encourage repeated
probing. Back to Users always remains available.

HTTP 404 with a missing/malformed error envelope or a different stable code is
an invalid-response error, not an accepted not-found state.

### 7.2 Other Failures

- authentication_required / HTTP 401 uses central invalidation and immediately
  clears all detail data/actions;
- password_change_required, user_inactive, and institution_inactive clear detail
  state and trigger the accepted auth bootstrap/reconciliation path;
- forbidden is a safe non-retryable error and reveals no target/scope reason;
- validation_failed is an unexpected client/protocol defect for this no-input
  GET and is a safe non-retryable error;
- invalid envelope/resource/target mismatch is a safe non-retryable
  invalid-response error;
- connection, timeout, server_error/5xx, and accepted unknown transient failures
  may show duplicate-protected Retry;
- no feature-level automatic retry is added;
- no failure displays or logs raw message, validation errors, URL, target,
  response data, SQL, stack trace, token, Institution, or exception text.

Exact generic presentation:

~~~text
Title: Unable to load user details
Message: User details could not be loaded safely.
Actions: Back to Users; Retry only when failure is classified retryable
~~~

## 8. Controller, State, and Stale-Response Safety

### 8.1 Eligibility

No detail GET is allowed unless current frontend state is all of:

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

The backend still re-authorizes every request and derives tenant scope from the
authenticated actor.

### 8.2 Operation Key

Every state/result is bound to:

~~~text
session user id
session User object instance identity
institution id
exact decoded route target
operation generation
controller not disposed
~~~

Only the latest operation matching all values may publish data, not found, or
error.

### 8.3 Required States

Use explicit states equivalent to:

~~~text
initial
local unavailable target
loading
data
refreshing same-target data
not found
retryable error
non-retryable error
~~~

Rules:

- initial eligible target schedules exactly one load;
- initial loading shows no previous User data or target-derived actions;
- route target A -> B immediately clears A before B request;
- same-role or cross-role account switch immediately clears the old target;
- logout, bootstrap transition, 401, inactive account/Institution,
  password-change requirement, Institution mismatch, disposal, or route exit
  clears data/actions and invalidates the operation generation;
- stale A success/404/error cannot overwrite current B;
- stale prior-session completion cannot publish into a new session;
- an identical target/session request already in flight is deduplicated;
- Retry is allowed only from retryable error and is duplicate-protected;
- Refresh is allowed only from data and performs one same-target logical GET;
- Refresh may keep only the current same-target/same-session data visible with a
  clear busy indication and conflicting controls disabled;
- Refresh success replaces the resource;
- Refresh 404, 401, target/session switch, invalid response, or non-retryable
  failure immediately removes the previously displayed data;
- no detail data is retained after route disposal or shared between target IDs;
- returning to the same detail route loads fresh server data.

Do not pass a list result into the detail state as initial authoritative data.
The FE004 retained list query remains owned by its list controller and is not
duplicated here.

## 9. Exact Presentation

### 9.1 Page Structure

Use:

~~~text
Heading: User details
Primary title in data state: server full_name
Action: Back to Users
Data-state action: Refresh
~~~

Render four read-only sections:

1. Identity
2. Contact
3. Account state
4. Activity and lifecycle

### 9.2 Exact Fields and Labels

| Section | Label | Source | Display |
|---|---|---|---|
| Identity | Full name | full_name | Exact server string |
| Identity | Login name | login_name | Exact server string |
| Identity | Role | role | Teacher / Student / Parent |
| Identity | User ID | id | Exact canonical UUID, read-only/selectable |
| Contact | Email | email | Exact string or Not provided |
| Contact | Phone | phone | Exact string or Not provided |
| Account state | Status | is_active | Active / Inactive |
| Account state | First login | must_change_password | Password change required / Completed |
| Activity and lifecycle | Last login | last_login_at | UTC timestamp or Never |
| Activity and lifecycle | Deactivated | deactivated_at | UTC timestamp or Not deactivated |
| Activity and lifecycle | Created | created_at | UTC timestamp |
| Activity and lifecycle | Updated | updated_at | UTC timestamp |

Every timestamp uses the same FE004 feature formatter:

~~~text
YYYY-MM-DD HH:mm UTC
~~~

Do not convert to local machine time, guess Institution-local time, or display a
date-only value.

Status, role, and first-login values require text plus appropriate semantics and
non-color indication. Long names, login, contacts, and UUID must wrap, select,
or expose a tooltip/semantics value without overflow or hidden substitution.

### 9.3 Navigation

Back to Users always navigates through the delivered named route/helper to the
canonical:

~~~text
/institution-admin/users
~~~

Do not rely only on Navigator.pop because direct entry may have no useful
in-app history. FE004 decides whether a same-session retained list query is
restored and refetched. S03-FE-005 must not invent list rows or query state.

Normal browser/Windows system back remains truthful:

- list -> detail -> system back returns through normal history;
- direct entry/reload remains inside the eligible shell;
- Back to Users always works even after direct entry;
- target changes update URL, title, state, and request truthfully;
- /users/new remains the create route and selects Users navigation.

### 9.4 Accessibility and Desktop Layout

- Material 3 and existing Institution Admin shell/theme only;
- usable without overflow at 800x600 and 1440x900;
- usable at text scale 2.0 and with long values;
- vertical scrolling when content exceeds viewport;
- predictable focus order: Back, Refresh when present, then selectable/read-only
  content;
- keyboard activation for every action;
- visible focus and appropriate tooltips;
- headings, sections, field labels/values, busy state, not found, and errors have
  useful semantics/live-region behavior;
- status/role/first-login/error meaning is never color-only;
- refreshing content is announced without exposing stale target metadata.

## 10. Architecture and Exact Change Boundary

Required flow:

~~~text
Institution Admin User detail screen/controller
  -> Institution User detail repository
  -> Institution User detail remote data source
  -> existing configured Dio client
~~~

Expected new files:

~~~text
frontend/lib/features/institution_admin/domain/institution_user_detail_repository.dart
frontend/lib/features/institution_admin/data/dto/institution_user_detail_dto.dart
frontend/lib/features/institution_admin/data/institution_user_detail_remote_data_source.dart
frontend/lib/features/institution_admin/data/institution_user_detail_repository_impl.dart
frontend/lib/features/institution_admin/application/institution_user_detail_state.dart
frontend/lib/features/institution_admin/application/institution_user_detail_controller.dart
~~~

Expected delivered placeholder to modify:

~~~text
frontend/lib/features/institution_admin/presentation/institution_admin_user_detail_screen.dart
~~~

Expected focused tests:

~~~text
frontend/test/features/institution_admin/institution_user_detail_dto_test.dart
frontend/test/features/institution_admin/institution_user_detail_remote_data_source_test.dart
frontend/test/features/institution_admin/institution_user_detail_repository_impl_test.dart
frontend/test/features/institution_admin/institution_user_detail_controller_test.dart
frontend/test/features/institution_admin/institution_admin_user_detail_screen_test.dart
~~~

Conditionally allowed minimal shared-parser extraction:

~~~text
frontend/lib/features/institution_admin/data/dto/institution_user_dto.dart
frontend/lib/features/institution_admin/data/dto/institution_user_list_dto.dart
frontend/test/features/institution_admin/institution_user_list_dto_test.dart
~~~

Conditionally allowed delivered route wiring when the placeholder does not
already pass decoded userId into the real screen:

~~~text
frontend/lib/app/router/app_router.dart
the exact existing Institution Admin router test file(s)
~~~

No route name/path/helper/classification or shell topology change is allowed.
app_route_paths.dart is inspect-and-preserve.

Conditionally allowed predecessor-regression updates made obsolete only by this
task:

~~~text
the exact existing FE001 Institution Admin shell/detail-placeholder test file(s)
the exact existing FE004 Users row-navigation/list screen test file(s)
~~~

Each conditional change must be minimal, named in the final report, and preserve
the predecessor's unrelated assertions. If broader production or test changes
are required, stop rather than widening scope.

Inspect and preserve:

~~~text
frontend/lib/core/network/
frontend/lib/features/auth/
frontend/lib/features/platform_admin/
other Institution Admin screens/controllers
backend/
docs/01-09
~~~

No backend/schema/docs/package/core-network/auth/Platform change, route-family
addition, shell redesign, list behavior rewrite, fake API, mutation, or
unrelated cleanup is allowed.

Task lifecycle files allowed only as Section 14 permits:

~~~text
tasks/frontend/stage-03/S03-FE-005-institution-user-detail.md
tasks/frontend/stage-03/S03-FE-005-CODEX-PROMPT.md
tasks/STAGE_03_TASK_INDEX.md
tasks/README.md
~~~

## 11. Authoritative References

Read in this order:

1. root AGENTS.md;
2. frontend/AGENTS.md;
3. this complete detailed task and paired prompt;
4. tasks/README.md and tasks/STAGE_03_TASK_INDEX.md;
5. accepted S03-INT-001 contract/task-control record;
6. docs/02-user-roles.md: Institution Admin and managed roles;
7. docs/03-features.md and docs/04-user-flows.md: User list/view flow;
8. docs/05-business-rules.md: tenant, role, lifecycle, disclosure;
9. docs/06-roadmap.md: Stage 3 scope and Stage 4 exclusion;
10. docs/07-architecture.md: Flutter/API/session/security/testing boundaries;
11. docs/08-database.md: User public fields, UUIDs, timestamps, lifecycle;
12. docs/09-api-contracts.md: general envelopes/errors and Sections 8.2/8.5
    after S03-INT-001;
13. accepted S03-BE-003 task, implementation, tests, review, and delivery;
14. delivered S03-FE-001 and S03-FE-004 code/tests;
15. accepted Stage 2 Platform detail patterns only as structural reference.

If locked documents, accepted backend, this task, or delivered frontend
dependencies conflict, stop and report exact sections. Do not silently choose,
weaken strict parsing, change backend behavior, or invent a frontend rule.

## 12. Acceptance Criteria

- [ ] Phase 0 proves S03-FE-004 and S03-BE-003 are each
      Accepted / PASS / Delivered on current origin/main.
- [ ] The decoded FE001-validated canonical UUID route target is the only target
      authority.
- [ ] FE001 canonical UUID grammar/classification/fallback remains unchanged;
      malformed detail locations build no detail screen and send no detail GET.
- [ ] Every FE001-valid canonical UUID is safely encoded and sent once; defensive
      direct invocation with an invalid target fails closed with no request.
- [ ] /users/new never resolves to detail or sends the detail GET.
- [ ] Exact GET path/auth/one encoded segment/no query/zero body/no Institution
      selector are proven.
- [ ] Detail envelope accepts exactly data and delegates to the exact shared
      FE004 User parser.
- [ ] Exact 12-field resource, protected/unknown rejection, UUID/types/nulls/
      booleans/roles/UTC/lifecycle rules remain identical to FE004.
- [ ] A 200 response UUID must match the requested UUID and cannot replace the
      route target.
- [ ] Own eligible active and inactive Users render every approved field
      truthfully.
- [ ] Malformed frontend locations follow FE001's safe canonical-entry fallback;
      valid unknown, foreign, and disallowed-role UUIDs reveal no distinction
      through the accepted backend not-found presentation.
- [ ] Only accepted 404 resource_not_found becomes not found; malformed errors
      do not.
- [ ] Retry appears only for retryable errors; definitive not found,
      forbidden, validation, and invalid-response states are non-retryable.
- [ ] Refresh operates once on current data and clears it immediately on
      404/401/target/session/non-retryable failure.
- [ ] Initial/target-change loading contains no previous User data/actions.
- [ ] Latest target/session/generation wins; stale success/404/error/refresh
      completions cannot publish.
- [ ] Logout, 401, bootstrap, inactive/first-login/Institution changes,
      same-role/cross-role account switches, disposal, and route exit clear data.
- [ ] Detail data is not retained across route disposal or targets.
- [ ] Exact sections, labels, null values, UTC format, technical ID, status,
      role, first-login, and long values render safely.
- [ ] Back to Users works for list navigation and direct entry without inventing
      list state; browser/Windows back/reload remain truthful.
- [ ] No edit/create/activate/deactivate/detail-adjacent mutation or later-stage
      data/control exists.
- [ ] Compact/wide desktop, text scale 2.0, scrolling, keyboard, focus,
      semantics, live regions, tooltips, and non-color states pass.
- [ ] Narrow FE001/FE004 regression updates are sufficient; full frontend suite
      and Windows build pass.
- [ ] No backend/docs/core/auth/Platform/package/route-topology/scope drift.

## 13. Required Tests and Verification

### 13.1 DTO and Repository

- exact data-only envelope with every active/inactive/null/non-null field;
- missing/wrong/extra top-level keys, message/meta/links rejection;
- shared row parser is reused, not copied;
- every FE004 malformed/unknown/protected resource matrix remains green;
- requested/response UUID exact and case-equivalent match;
- different response UUID, malformed resource UUID, role/type/null/timestamp/
  lifecycle errors;
- repository maps exact domain object and preserves typed failures.

### 13.2 Remote Data Source

- exact method and safely encoded single path segment;
- central auth/client/options behavior;
- no queryParameters, query key, body, Institution ID, or tenant header;
- valid uppercase/lowercase canonical UUID values preserve the route target and
  cannot alter path/query/fragment;
- malformed/noncanonical target is blocked by FE001 routing and defensively
  before the data source if invoked directly;
- 200/401/403/404/422/500/timeout/connection/invalid-envelope mapping;
- raw errors/targets are never rendered or feature-logged.

### 13.3 Controller and Session

- ineligible session matrix issues no GET;
- eligible initial target performs one GET;
- initial success, active/inactive/null data, and failure states;
- identical in-flight load/Refresh/Retry deduplication;
- Refresh success/replacement, 404 clear, 401 clear, invalid-response clear,
  retryable/non-retryable failure behavior;
- Retry only from retryable error;
- defensive local missing/noncanonical target no request and safe unavailable
  state;
- every FE001-valid canonical UUID target performs the exact backend request;
- rapid A -> B with stale A success/404/error ignored;
- target change during refresh clears A immediately;
- logout, central 401, bootstrap, inactive, first login, Institution mismatch,
  same-role/cross-role account switch, disposal, route exit;
- session object identity and Institution ID prevent cross-session reuse;
- no retained detail data when leaving and returning.

### 13.4 Screen, Router, and Navigation

- direct eligible detail route, reload/rebuild, URL truth, and selected Users
  destination;
- /users/new resolves create owner and sends no detail GET;
- FE001 canonical UUID acceptance, malformed/empty/reserved/extra target safe
  fallback with no detail screen/GET, and uppercase/lowercase valid UUID routes;
- list row -> server UUID detail -> system back;
- Back to Users from list-origin and direct-entry history;
- FE004 retained query is honored by FE004 only and refetched;
- exact heading, four sections, 12 labels/values, null copy, UTC formatting,
  selectable ID, role/status/first-login text;
- active/inactive and null/non-null lifecycle presentation;
- loading/refreshing/not-found/retryable/non-retryable states and exact actions;
- no raw target/backend message and no protected field/control;
- no edit/create/activate/deactivate action;
- 800x600, 1440x900, text scale 2.0, long names/login/contact/UUID, scrolling,
  no overflow, keyboard/focus/semantics/live-region/tooltips/non-color meaning;
- minimal necessary FE001 placeholder/no-request assertion updates;
- minimal FE004 navigation regression updates;
- full auth/router/shell/dashboard/profile/list/Platform regressions.

### 13.5 Commands

Run from frontend:

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
- tracked-file allowlist/scope check;
- diff review including owner-prepared task/prompt;
- credential/secret scan;
- prompt byte comparison before Phase 3;
- current configured repository quality gates.

Do not claim a command passed unless its final exit status/output was observed.

### 13.6 Manual Windows Real-Stack Smoke

When the approved Laravel/PostgreSQL stack and safe test data are available:

- list -> active detail -> back with retained/refetched list query;
- inactive detail with deactivated timestamp;
- direct known UUID and reload;
- malformed/noncanonical frontend locations returning through FE001's canonical
  safe fallback with no detail GET;
- valid unknown, foreign, Platform Owner, and Institution Admin UUIDs showing
  indistinguishable User unavailable UI;
- /users/new remains create placeholder and issues no detail GET;
- Refresh success and a safely induced retryable failure/Retry when available;
- logout/401 clears detail immediately;
- no protected/foreign/disallowed field leakage;
- compact/wide/text-scale/keyboard/focus/semantics behavior.

If real stack, Windows runner, safe seeded edge target, or failure injection is
unavailable, mark that exact smoke item NOT RUN with reason. Never fabricate
evidence or mutate production/shared data just to prove a case.

## 14. Required Workflow and Delivery

Branch:

~~~text
task/s03-fe-005-institution-user-detail
~~~

### Phase 0 — Git Preflight

1. Read the paired prompt and all Section 11 authority completely.
2. Verify this detailed task is Approved.
3. Verify S03-FE-004 and S03-BE-003 are each
   Accepted / PASS / Delivered on current origin/main; otherwise stop as BLOCKED.
4. Verify the expected GitHub origin, fetch safely, and prove
   local main == origin/main.
5. Verify a clean worktree except only the owner-prepared S03-FE-005 task/prompt
   when they are not yet committed.
6. Resolve delivered FE001/FE004 detail placeholder, route parameter/wiring,
   shared User parser/model/formatter, list retention, and exact affected tests.
7. Prove which conditional files in Section 10 are actually necessary.
8. Create/switch to task/s03-fe-005-institution-user-detail from approved main.
9. Preserve unrelated user work and stop on dirty/conflicting/unsafe state.
10. Do not commit, push, create a PR, or merge before Phase 2 PASS.

### Phase 1 — Implementation

Implement only Sections 4–10.

Before Phase 2:

- update only the S03-FE-005 Stage 3 index row to
  In Progress / Not started / Not started;
- minimally update the directly adjacent Stage index narrative/count/next-gate
  text only where necessary so it does not falsely claim S03-FE-005 remains
  Draft;
- do not change another task's status/review/delivery values;
- keep this detailed task status Approved;
- preserve the paired prompt byte-for-byte;
- do not update tasks/README acceptance/delivery state;
- run every required check and inspect the complete diff;
- do not stage, commit, push, create a PR, or merge.

### Phase 2 — Read-Only Acceptance Gate

Re-read all authority and review the complete result/diff, target/route/
request/envelope/resource/session/state/error/not-found/navigation/disclosure/
accessibility behavior, predecessor regressions, tests/build/smoke, scope,
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

- P1: tenant/session/protected-data disclosure, target confusion, unsafe route/
  navigation, destructive Git, secret exposure, or read-only-gate violation;
- P2: material endpoint/path/input/envelope/resource/UUID/state/error/not-found/
  accessibility/architecture/test/workflow mismatch, stale-state gap, regression,
  or scope drift;
- P3: non-blocking observation without correctness, security, evidence, or
  maintainability acceptance impact.

Any unresolved P1 or P2 returns:

~~~text
FINAL STATUS: NOT ACCEPTED
~~~

Stop without delivery and do not start S03-FE-006. Report all P3 findings; P3
alone does not block PASS.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 PASS with no unresolved P1/P2:

1. Change only this detailed task status from Approved to Accepted without
   rewriting approved behavior.
2. Prepare the S03-FE-005 index row as
   Accepted / PASS / Delivered and update only directly related narrative/count/
   next-gate consistency.
3. Update tasks/README.md truthfully: Stage 3 remains In Progress,
   S03-FE-005 is delivered, and S03-FE-006 is the next implementation gate.
4. Preserve every later task's truthful state, keep Stage 3 open, and keep
   Stage 4 blocked.
5. Preserve the paired prompt byte-for-byte.
6. Re-run final non-writing diff/scope/secret/prompt/consistency checks.
7. Stage only approved implementation/tests, this task, unchanged prompt,
   Stage index, and README.
8. Commit:

   ~~~text
   feat(institution): add user detail UI

   Task: S03-FE-005
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

## 15. Explicit Non-Goals

- User edit, create, activate, deactivate, password reset, delete, archive,
  role/login-name change, bulk action, import/export, or impersonation.
- Fetching/displaying relationships, Groups, Topics, learning, attempts,
  submissions, answers, scores, results, reports, settings, or categories.
- Managing Platform Owner or Institution Admin target accounts.
- Trusting/caching a list row as detail authority.
- Client-side tenant/role/existence authority or different foreign-target copy.
- New route family/path/helper, shell redesign, mobile Institution Admin UI.
- Backend/schema/docs/core-network/auth/Platform/package changes.
- Broad FE001/FE004 refactor or unrelated cleanup.
- Stage 4+ behavior.

## 16. Stop Conditions

Stop and report before expanding scope if:

- either direct dependency is not Accepted / PASS / Delivered;
- locked docs, accepted S03-BE-003, this task, or delivered FE001/FE004 conflict;
- the shared FE004 User parser cannot be reused/extracted without material list
  behavior change;
- exact target encoding/match or scope-safe not-found behavior cannot be proven;
- stale target/session data cannot be eliminated;
- backend, new route topology/helper, package, core/auth/Platform, mutation, or
  broad predecessor rewrite appears necessary;
- required changes materially exceed Section 10;
- full regression requires unrelated correction;
- repository/Git/GitHub state is unsafe;
- any Phase 2 P1/P2 exists.

## 17. Required Codex Final Report

Report:

- FINAL STATUS;
- Phase 0 origin/main/branch/dependency/clean evidence;
- every changed file and layer responsibility, including each conditional file;
- exact FE001-validated route-target source, malformed-location fallback,
  valid-UUID encoding, and /users/new proof;
- exact GET path/auth/no-query/zero-body/no-Institution evidence;
- shared parser reuse/extraction and exact data-only/12-field/target-match proof;
- 404 uniformity, retryability classification, safe copy, and raw-data absence;
- state/Refresh/Retry/dedup/latest-target/session/disposal evidence;
- all 12 field labels/nulls/UTC/status/role/first-login/technical-ID evidence;
- list/direct/reload/system-back/Back-to-Users navigation evidence;
- responsive/keyboard/focus/semantics/live-region/non-color evidence;
- predecessor regression updates and preserved assertions;
- every command, test count/result, Windows build, and truthful smoke status;
- P1/P2/P3 findings, scope/secret/prompt/bookkeeping checks, and non-goals;
- PR/merge SHA/local-main/origin-main/clean delivery evidence when applicable.

End with:

~~~text
No User mutation, client tenant authority, protected data, relationship,
settings/category, learning, or Stage 4 behavior was implemented.
Next implementation gate: S03-FE-006.
~~~
