# Codex Task: Institution User List, Search, Filters, Sorting, and Pagination

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | S03-FE-004 |
| Roadmap stage | Stage 3 — Institution Administration and User Management |
| Area | Frontend |
| Status | Accepted |
| Approved on | 2026-08-13 |
| Direct dependencies | S03-FE-003 and S03-BE-003 |
| Directly blocks | S03-FE-005 and S03-INT-002 |

This task/prompt pair may be prepared before its frontend predecessor is
delivered. Production implementation must not start until both S03-FE-003 and
S03-BE-003 are independently present on origin/main as
Accepted / PASS / Delivered. At preparation time S03-BE-003 is delivered, but
S03-FE-003 is not yet delivered; Phase 0 must re-check the then-current truth
instead of trusting this planning note.

## 2. Goal

Replace only the Institution Admin Users placeholder with a real, read-only,
server-driven desktop list of Teachers, Students, and Parents belonging to the
authenticated Institution.

The screen must support exact search, role/status filters, four approved sort
fields, 20/50/100 page sizes, truthful pagination, safe detail/create
navigation, and complete loading/empty/error/session states for:

~~~text
GET /api/v1/institution/users
~~~

The backend remains authoritative for Institution scope, eligible roles,
status, search, ordering, totals, and returned User data. This task does not
implement User detail data or any mutation.

## 3. Current Context and Important Contract Hazard

S03-BE-003 delivers the exact endpoint and response. Its collection metadata
uses:

~~~json
{
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 20,
      "total": 0,
      "last_page": 1
    }
  }
}
~~~

The current shared frontend ApiPaginationMeta parser expects current_page, not
page. It is incompatible with this endpoint.

S03-FE-004 must therefore create a feature-specific Institution User list
pagination DTO/parser using page. It must not reuse the incompatible shared
parser, reinterpret page as current_page, change the backend contract, or
modify the shared parser and risk Stage 1/2 regressions.

The accepted Platform Institution list is a useful structural reference for
query objects, DTOs, controllers, stale-response protection, desktop tables,
and accessibility. It is not authority for endpoint fields, pagination key
names, search length, debounce duration, session eligibility, or empty-page
behavior.

## 4. Included Scope

- Add feature-local Institution User, page, pagination, query, sort, direction,
  repository, DTO, remote data source, controller, and state types.
- Replace the delivered Users placeholder with the real list screen.
- Use the central authenticated Dio client and failure/session infrastructure.
- Send only the exact accepted query keys and no request body.
- Implement server-side search/filter/sort/pagination orchestration.
- Implement exact 300 ms search debounce, immediate keyboard submission, local
  maximum-length feedback, deduplication, and latest-query-wins behavior.
- Implement one bounded automatic empty-page correction per logical query.
- Retain the same session's list query while navigating to User detail/create,
  but never retain or restore another session/tenant's data.
- Add exact row, pagination, navigation, responsive desktop, keyboard,
  semantics, focus, and non-color status presentation.
- Add focused data/domain/application/widget tests and preserve all regressions.
- Perform only the approved task lifecycle bookkeeping after the read-only
  acceptance gate passes.

## 5. Exact API Request Contract

### 5.1 Endpoint and Transport

Send:

~~~text
GET /api/v1/institution/users
~~~

Requirements:

- use the existing configured authenticated Dio client;
- use Dio queryParameters and never construct a raw query string;
- transmit zero request-body bytes: no data, empty map, JSON null, or form body;
- add no Institution selector in path, query, body, or custom header;
- do not send role values outside teacher, student, and parent;
- do not introduce a feature-specific HTTP client, token store, interceptor, or
  automatic retry policy;
- one controller intent means one logical GET; the already-approved central
  safe-GET transport policy may remain unchanged.

### 5.2 Query Model and Defaults

The only possible query keys are:

~~~text
role
status
search
page
per_page
sort
direction
~~~

Exact UI/domain defaults:

~~~text
role = null                    // All roles
status = null                  // All statuses
search = null                  // Blank
page = 1
per_page = 20
sort = full_name
direction = asc
~~~

Accepted values:

~~~text
role = teacher | student | parent
status = active | inactive
page = integer >= 1
per_page = 20 | 50 | 100
sort = full_name | login_name | created_at | updated_at
direction = asc | desc
~~~

Exact serialization policy:

- always send page, per_page, sort, and direction, including their defaults;
- send role only when a concrete role is selected;
- send status only when a concrete status is selected;
- trim search and send it only when the normalized value is non-empty;
- never send all, blank search, null, an empty string, current_page,
  institution_id, an unknown key, a list/array, or an unsupported enum value;
- preserve literal user characters such as !, %, _, apostrophes, spaces, and
  non-ASCII text; Dio performs URL encoding and the backend performs literal
  search escaping;
- query equality/hash/deduplication use all seven logical values after search
  normalization.

### 5.3 Query Transitions

- Search, role, status, sort-field, sort-direction, and page-size changes reset
  page to 1.
- Previous/Next change only page and preserve every other committed query value.
- Selecting a different sort field sets direction to asc.
- Activating the already-selected sort field toggles asc and desc.
- Clear filters clears only search, role, and status and resets page to 1; it
  preserves the current page size, sort field, and direction.
- Clear filters sends no duplicate request when those three values are already
  clear and page is already 1.
- Refresh reloads exactly the current committed query.
- Retry reloads exactly the failed committed query.
- No client-side filtering, sorting, or slicing of one returned page may
  masquerade as server results.

## 6. Exact Search and Request Orchestration

Search is two-state:

- draft text is exactly what the field currently displays;
- committed search is the normalized value in the server query.

Rules:

1. Normalize by trimming leading/trailing whitespace.
2. Validate the normalized value against the backend maximum of 254 Unicode
   code points (Dart runes), not UTF-8 bytes or UTF-16 code units.
3. A normalized blank becomes null and is omitted.
4. Each valid text change cancels the previous timer and starts exactly 300 ms.
5. At 300 ms of inactivity, commit the normalized value and reset page to 1.
6. Pressing Enter/Search cancels the timer and commits immediately.
7. Recommitting the same normalized query sends no duplicate GET.
8. A normalized value longer than 254 shows safe local feedback, cancels the
   timer, and sends no request.
9. While that local error exists, search submission and query-changing
   filter/sort/page/page-size actions send no GET; Clear filters remains
   available and restores a valid state.
10. If a valid debounce is pending and role/status/sort/page-size/Refresh is
    activated, cancel the timer, include the current normalized draft in the
    same new query, and send only one GET. Because search changed, page is 1.
11. If Previous/Next is activated while a different valid search draft is
    pending, commit the search instead and load page 1; do not navigate within
    results for the old search.
12. Disposal, logout, account switch, or loss of eligibility cancels the timer.

An identical in-flight query is deduplicated. A different query may supersede
an earlier request, but only the latest current-session operation may publish
rows, metadata, empty state, or error.

## 7. Exact Response Contract

### 7.1 Envelope and Feature-Specific Pagination

Success is HTTP 200 with exactly:

~~~json
{
  "data": [],
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 20,
      "total": 0,
      "last_page": 1
    }
  }
}
~~~

The feature-specific parser must require:

- top-level data as a JSON array;
- meta as an object containing pagination;
- page, per_page, total, and last_page as JSON integers, never numeric strings,
  doubles, nulls, or booleans;
- page >= 1;
- per_page in 1..100 and equal to the requested query perPage;
- total >= 0;
- last_page >= 1 and exactly max(1, ceil(total / per_page));
- response page equal to the requested page;
- returned row count <= per_page and <= total when total is non-zero;
- page > last_page is valid only with an empty data array, as specified by
  S03-BE-003;
- total = 0 requires an empty data array and last_page = 1.

Reject missing, renamed, malformed, or contradictory pagination. In particular,
reject current_page in place of page. Do not silently return nullable metadata
or plausible defaults.

The exact locked envelope/resource is deliberate. Reject unknown top-level,
meta, pagination, or row keys so contract drift and accidental protected-field
disclosure cannot be silently accepted.

### 7.2 Exact User Resource

Every item contains exactly these 12 keys; JSON key order is irrelevant:

~~~json
{
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
~~~

Strict parsing rules:

- id is a syntactically valid canonical UUID string;
- role is exactly teacher, student, or parent;
- full_name and login_name are present, non-blank strings;
- email and phone are present and each is null or a string; do not invent a
  stricter contact-value rule than the locked nullable-string contract;
- is_active and must_change_password are JSON booleans;
- last_login_at and deactivated_at are present and null or accepted UTC
  timestamps;
- created_at and updated_at are required accepted UTC timestamps;
- a non-null timestamp must be an ISO-8601 UTC value ending in Z and must parse
  successfully; do not accept a local date or silently convert an offset value;
- an active User requires deactivated_at = null;
- an inactive User requires non-null deactivated_at;
- duplicate User UUIDs within one page are an invalid response;
- do not trim, invent, default, coerce, or replace server resource values.

The domain model contains only the 12 public fields. Never parse into a public
model, cache, render, log, or navigate with:

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

## 8. Exact Empty-Page Correction

The backend intentionally returns 200 with empty data and the requested page
when page is outside the current range. The controller must correct safely:

1. A logical query starts with correctionUsed = false.
2. If a valid response has empty data and requested page > 1, calculate:
   - target page = 1 when total = 0;
   - otherwise target page =
     max(1, min(last_page, requested page - 1)).
3. If target differs from the requested page and correctionUsed is false,
   update committed query.page, mark correctionUsed, and issue exactly one
   corrective GET preserving search/role/status/perPage/sort/direction.
4. The corrective GET is part of the same latest-operation/session guard.
5. Never perform a second automatic correction for that logical query,
   including when the corrective response is empty or the dataset changes
   again.
6. Page 1 never triggers automatic correction.

After the single correction:

- total = 0 on page 1 becomes global empty or filtered empty according to the
  committed search/role/status;
- rows become normal data;
- empty data with total > 0 becomes a safe Empty page state with manual Page 1,
  Previous when valid, Refresh, and no invented rows or totals.

Every new user-initiated search/filter/sort/page-size/page/Refresh/Retry intent
starts a new logical query with its own one-correction maximum. Stale correction
responses cannot publish.

## 9. Session, Tenant, Stale-State, and Error Safety

### 9.1 Eligibility

No list GET is allowed unless current auth state is all of:

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

The request still sends no Institution ID. The backend derives tenant scope
from the authenticated actor.

### 9.2 Session Key and Retention

Use the delivered session convention and bind state/retained query to:

~~~text
session user id
session User object instance identity
institution id
~~~

- Retain only committed query and search draft while the same session navigates
  from Users to its detail/create route and back.
- On return, load the retained query from the server; do not restore cached rows
  as final data.
- Logout, bootstrap transition, same-role account switch, cross-role switch,
  Institution change, inactive state, first-login state, disposal, or central
  invalidation immediately removes rows/actions, clears retained state, cancels
  timers, and invalidates all generations.
- Initial loading for a new session contains no prior-account rows or actions.
- Query changes clear rows that belong to the old query. Refresh may keep only
  current same-session rows visibly marked as refreshing and with conflicting
  controls disabled.

### 9.3 Failure Mapping

- authentication_required / HTTP 401 uses central invalidation and immediately
  clears protected list state;
- password_change_required, user_inactive, and institution_inactive clear the
  list and trigger the accepted auth bootstrap/reconciliation path;
- forbidden, validation_failed, not found, invalid response, timeout,
  connection, and server failures use safe feature state;
- Retry is duplicate-protected and retains the exact failed committed query;
- Refresh is duplicate-protected and performs one current-query logical load;
- no raw backend message, validation payload, URL, SQL, stack trace, tenant/User
  identifier, token, or exception text is rendered or logged;
- no error path navigates to or exposes a User row;
- this read-only feature adds no mutation reconciliation or mutation retry.

## 10. Exact Presentation and Navigation

### 10.1 Toolbar and Actions

The Users screen contains:

- heading Users;
- Create User action;
- search field labelled Search users with visible 254-character validation;
- Role dropdown: All roles, Teacher, Student, Parent;
- Status dropdown: All statuses, Active, Inactive;
- Clear filters action;
- Refresh action;
- page-size selector: 20, 50, 100.

Create User navigates through the delivered named route/helper to:

~~~text
/institution-admin/users/new
~~~

This route may still contain the S03-FE-006 placeholder. S03-FE-004 must not
implement its form or data call.

### 10.2 Exact Table

Use these exact columns:

| Column | Sortable | Display |
|---|---|---|
| Full name | full_name | Server full_name |
| Login name | login_name | Server login_name |
| Role | No | Teacher / Student / Parent |
| Contact | No | Email and phone; Not provided only when both are null |
| Status | No | Active / Inactive with text plus non-color icon/semantics |
| First login | No | Password change required / Completed |
| Created | created_at | UTC as YYYY-MM-DD HH:mm UTC |
| Updated | updated_at | UTC as YYYY-MM-DD HH:mm UTC |

Sortable headers expose current field/direction visibly and semantically.
Selecting a new sortable header uses asc; selecting it again toggles direction.
Role and Status are filters only.

Long names/login/contact values must not overflow. Preserve the exact visible
value through wrapping or tooltip/semantics rather than silently making another
identifier. The desktop table may scroll horizontally, but the whole screen
must remain usable at 800x600, 1440x900, and text scale 2.0 without render
overflow or keyboard traps.

### 10.3 Pagination and Empty/Error States

For a non-empty page show:

~~~text
start-end of total
Page page of last_page
~~~

where start = (page - 1) * per_page + 1 and
end = start + returned row count - 1.

- Previous is enabled only when page > 1 and no conflicting load is active.
- Next is enabled only when page < last_page, rows are present, and no
  conflicting load is active.
- Never invent a total from row count.

Distinct accessible states:

- Initial loading: no stale rows/actions from another session.
- Query loading: no rows from the previous query.
- Refreshing: current same-query rows may remain, clearly marked, with
  conflicting controls disabled.
- Global empty: page 1, total 0, no search/role/status; show Create User.
- Filtered empty: page 1, total 0, any search/role/status; show Clear filters.
- Empty page after the bounded correction: safe manual Page 1/Previous/Refresh.
- Error: safe message and duplicate-protected Retry.
- Data: exact rows, range, page, total, navigation, Refresh, and Create User.

### 10.4 Detail Navigation

Activating a row by pointer or keyboard navigates with the delivered named
route/path helper to:

~~~text
/institution-admin/users/:userId
~~~

Requirements:

- use only the parsed server User.id;
- safely encode/pass the UUID using the delivered route helper;
- never use search text, row index, full_name, login_name, email, or phone as a
  route identifier;
- detail may still be the S03-FE-005 placeholder;
- do not pre-populate invented detail data or call the detail API in this task.

Every actionable control/row requires correct focus order, keyboard activation,
visible focus, tooltip where needed, semantics label/state, and a non-color-only
indication.

## 11. Architecture and Exact Change Boundary

Required flow:

~~~text
Institution Admin Users screen/controller
  -> Institution User list repository
  -> Institution User list remote data source
  -> existing configured Dio client
~~~

Expected feature-local application paths:

~~~text
frontend/lib/features/institution_admin/domain/institution_user.dart
frontend/lib/features/institution_admin/domain/institution_user_list.dart
frontend/lib/features/institution_admin/domain/institution_user_list_query.dart
frontend/lib/features/institution_admin/domain/institution_user_list_repository.dart
frontend/lib/features/institution_admin/data/dto/institution_user_list_dto.dart
frontend/lib/features/institution_admin/data/institution_user_list_remote_data_source.dart
frontend/lib/features/institution_admin/data/institution_user_list_repository_impl.dart
frontend/lib/features/institution_admin/application/institution_user_list_state.dart
frontend/lib/features/institution_admin/application/institution_user_list_controller.dart
frontend/lib/features/institution_admin/presentation/institution_admin_user_formatters.dart
frontend/lib/features/institution_admin/presentation/institution_admin_users_screen.dart
~~~

Focused tests:

~~~text
frontend/test/features/institution_admin/institution_user_list_query_test.dart
frontend/test/features/institution_admin/institution_user_list_dto_test.dart
frontend/test/features/institution_admin/institution_user_list_remote_data_source_test.dart
frontend/test/features/institution_admin/institution_user_list_repository_impl_test.dart
frontend/test/features/institution_admin/institution_user_list_controller_test.dart
frontend/test/features/institution_admin/institution_admin_users_screen_test.dart
~~~

The exact delivered FE001–FE003 filenames may differ from these expected names.
Phase 0 must resolve the actual Users placeholder and existing Institution Admin
test filenames. Only the equivalent existing placeholder/test may be modified,
and the final report must explain the mapping. A material architecture/path
conflict is a stop condition, not permission for broad refactoring.

Inspect and reuse, but do not modify unless this task explicitly requires it:

~~~text
frontend/lib/core/network/
frontend/lib/features/auth/
frontend/lib/app/router/
frontend/lib/features/platform_admin/
backend/
docs/01-09
~~~

No core ApiPaginationMeta change, route topology change, shell redesign,
backend change, package addition, generated fake API, or unrelated cleanup is
allowed.

Task lifecycle files allowed only as Section 15 permits:

~~~text
tasks/frontend/stage-03/S03-FE-004-institution-user-list-search-filters-pagination.md
tasks/frontend/stage-03/S03-FE-004-CODEX-PROMPT.md
tasks/STAGE_03_TASK_INDEX.md
tasks/README.md
~~~

## 12. Authoritative References

Read in this order:

1. root AGENTS.md;
2. frontend/AGENTS.md;
3. this full detailed task and its paired prompt;
4. tasks/README.md and tasks/STAGE_03_TASK_INDEX.md;
5. accepted S03-INT-001 contract/task-control record;
6. docs/02-user-roles.md: Institution Admin and managed roles;
7. docs/03-features.md and docs/04-user-flows.md: Institution User list/view;
8. docs/05-business-rules.md: tenant, roles, access, lifecycle, disclosure;
9. docs/06-roadmap.md: Stage 3 boundary and Stage 4 exclusion;
10. docs/07-architecture.md: Flutter layers, API/session/security/testing;
11. docs/08-database.md: User fields, roles, timestamps, lifecycle;
12. docs/09-api-contracts.md: general envelopes/errors/pagination and the
    Institution User resource/list contract after S03-INT-001;
13. accepted S03-BE-003 implementation, tests, closure/delivery evidence;
14. delivered S03-FE-001–003 code/tests and accepted Stage 2 list patterns.

If the detailed task, delivered implementation, or locked documents conflict,
stop and report the exact conflict. Do not silently choose one or rewrite a
locked contract from frontend code.

## 13. Acceptance Criteria

- [ ] Phase 0 proves both direct dependencies are Accepted / PASS / Delivered.
- [ ] Exactly one endpoint/path/method is used with auth, accepted query, and no
      body or Institution selector.
- [ ] Query defaults, optional/always-sent keys, enum values, trimming, equality,
      reset, page transitions, and Dio encoding are exact.
- [ ] Search uses exactly 300 ms, maximum 254 after trimming, Enter commit,
      pending-action behavior, local error blocking, and duplicate suppression.
- [ ] A feature-specific strict page parser consumes page, not current_page.
- [ ] Exact envelope, pagination invariants, 12-field User resource, UUID,
      booleans, nullable values, roles, UTC timestamps, lifecycle consistency,
      duplicate IDs, and protected/unknown-key rejection are proven.
- [ ] Default, searched, role-filtered, status-filtered, sorted, reversed,
      paged, and page-size results are server-driven and truthful.
- [ ] Exactly one bounded empty-page correction occurs and can never loop.
- [ ] Initial/query loading, refreshing, data, global empty, filtered empty,
      post-correction empty page, and safe error/Retry states are distinct.
- [ ] Range/page/total and Previous/Next states use response metadata exactly.
- [ ] Latest query and session win; stale debounce/request/correction/error
      completions cannot publish.
- [ ] Logout, 401, first-login/inactive/bootstrap transitions, same-role and
      cross-role account switches clear protected rows/actions/retained state.
- [ ] Same-session detail/create round trip retains query but reloads server data.
- [ ] Exact columns/labels/contact/null/status/first-login/UTC displays work.
- [ ] Row/detail and Create User navigation use delivered helpers and safe server
      UUID only.
- [ ] No User mutation/detail call, client-side pseudo-search/sort, protected
      field, tenant selector, raw error, later-stage behavior, or scope drift.
- [ ] Compact/wide desktop, text scale, long content, pointer, keyboard, focus,
      semantics, tooltips, and non-color status pass.
- [ ] Focused and full frontend checks plus Windows build pass.

## 14. Required Tests and Verification

### 14.1 Automated Tests

At minimum cover:

- query initial values, normalization, copy/equality/hash, exact serialization,
  all enum mappings, page resets, page navigation, sort toggle, clear filters,
  and 20/50/100 validation;
- DTO exact success with null/non-null optional values and each role/state;
- missing/wrong/unknown/protected User keys, malformed/noncanonical UUID,
  unsupported role, wrong scalar/boolean/null, invalid UTC/local/offset
  timestamps, lifecycle mismatch, and duplicate IDs;
- exact page envelope using page; explicit rejection of current_page,
  missing/extra/wrong-type/negative/contradictory meta, request echo mismatch,
  last-page formula mismatch, oversized data, and invalid out-of-range rows;
- valid empty out-of-range page acceptance;
- exact Dio GET path, configured client use, query map, encoding of !/%/_/
  apostrophe/non-ASCII text, zero body, no Institution ID, and safe failure map;
- repository DTO-to-domain mapping and invalid-response propagation;
- initial/success/data/global-empty/filtered-empty/error/Retry/Refresh states;
- exact 300 ms debounce, Enter, trim/blank, Unicode-code-point 254/255
  boundaries, pending control action, invalid-search blocking, dedup, and
  cancellation on disposal/session;
- rapid query latest-wins and stale success/error rejection;
- Previous/Next/page size/sort/filter/search transitions and truthful ranges;
- one correction to last/previous/page 1, no second correction, stale correction,
  corrected success, corrected total-zero, and post-correction empty state;
- eligibility matrix, no request for ineligible session, logout, 401, inactive,
  password-change, Institution mismatch, same-role/cross-role account switch;
- retained same-session query on detail/create return and no cross-session reuse;
- exact screen toolbar/table/labels/null/contact/status/first-login/timestamps;
- safe row UUID and Create navigation; no detail API/mutation;
- global/filtered/empty-page/error actions and disabled/loading behavior;
- 800x600, 1440x900, text scale 2.0, long values, horizontal scrolling,
  keyboard/focus/semantics/tooltips/non-color states, and no overflow;
- absence of edit/lifecycle/bulk/import/export and protected-field UI;
- existing Institution Admin shell/dashboard/profile, auth/router, and Platform
  Institution list regressions.

### 14.2 Commands

Run from frontend:

~~~text
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/features/institution_admin
flutter test
flutter build windows --debug
~~~

Also run focused route/shell regression targets resolved from delivered
S03-FE-001–003. Run a tracked-file scope check, credential/secret scan, and
complete diff review. Do not claim a command passed unless its final exit status
and output were observed.

### 14.3 Manual Windows Real-Stack Smoke

When the approved Laravel/PostgreSQL stack and eligible Institution Admin test
session are available, verify:

- default list and exact own-Institution roles;
- search including spaces, %, _, !, apostrophe, and non-ASCII text;
- each role/status filter;
- all sort fields and both directions;
- 20/50/100, Previous/Next, range/page/total, and empty-page correction;
- global/filtered empty and Clear filters;
- Refresh, safe failure, Retry, logout/401 clearing;
- row detail and Create User placeholder navigation, back, and retained query;
- no foreign/disallowed/protected data;
- keyboard operation, focus, compact/wide layout, and text scaling.

If the real stack, Windows runner, seeded edge state, or safe failure injection
is unavailable, report the exact manual item as NOT RUN and why. Never
fabricate smoke evidence or mutate production/shared data merely to prove it.

## 15. Required Workflow and Delivery

Branch:

~~~text
task/s03-fe-004-institution-user-list
~~~

### Phase 0 — Git Preflight

1. Read the paired prompt and all Section 12 authority.
2. Verify this detailed task is Approved.
3. Verify S03-FE-003 and S03-BE-003 are each
   Accepted / PASS / Delivered on origin/main; otherwise stop as BLOCKED.
4. Verify the expected GitHub origin, fetch safely, and prove
   local main == origin/main.
5. Verify a clean worktree except only the owner-prepared S03-FE-004 task/prompt
   when they are not yet committed.
6. Resolve delivered FE001–003 route/screen/test paths and the current shared
   pagination incompatibility without changing files.
7. Create/switch to task/s03-fe-004-institution-user-list from approved main.
8. Preserve unrelated work and stop on dirty/conflicting/unsafe state.
9. Do not commit, push, create a PR, or merge before Phase 2 PASS.

### Phase 1 — Implementation

Implement only Sections 4–11. Modify only the resolved feature-local
application/test allowlist plus:

- the S03-FE-004 index row to
  In Progress / Not started / Not started;
- no other task/index/README acceptance bookkeeping.

Keep this task status Approved and preserve the paired prompt byte-for-byte
before Phase 2. Run Section 14 checks, inspect the complete diff, and do not
stage, commit, push, create a PR, or merge.

### Phase 2 — Read-Only Acceptance Gate

Re-read all authority, the complete result/diff, exact API/query/DTO/pagination/
state/session/navigation/accessibility requirements, tests/build/smoke, scope,
and secrets. Phase 2 is strictly read-only:

~~~text
no edits, auto-fix, or write-format
no task/index/README bookkeeping edits
no staging or commit
no push, PR, or merge
no self-fixing findings
~~~

Classify findings:

- P1: tenant/session/protected-data disclosure, unsafe target navigation,
  destructive Git, secret exposure, or read-only-gate violation;
- P2: material API/query/DTO/page/search/state/error/accessibility/architecture/
  test/workflow mismatch or scope drift;
- P3: non-blocking observation with no correctness, security, evidence, or
  maintainability acceptance impact.

Any unresolved P1 or P2 returns:

~~~text
FINAL STATUS: NOT ACCEPTED
~~~

Stop without delivery and do not start S03-FE-005. Report all P3 findings; P3
alone does not block PASS.

### Phase 3 — Post-Acceptance Git Delivery

Only after Phase 2 PASS:

1. Change only this detailed task status from Approved to Accepted without
   rewriting its approved behavior.
2. Prepare only the S03-FE-004 index row as
   Accepted / PASS / Delivered in the focused delivery commit.
3. Update tasks/README.md truthfully: Stage 3 remains In Progress,
   S03-FE-004 is delivered, and S03-FE-005 is the next implementation gate.
4. Preserve later tasks' truthful states, keep Stage 3 open, and keep Stage 4
   blocked.
5. Preserve the paired prompt byte-for-byte.
6. Re-run final non-writing diff/scope/secret/consistency checks.
7. Stage only approved implementation/tests, the task, unchanged prompt, index,
   and README.
8. Commit:

   ~~~text
   feat(institution): add user management list UI

   Task: S03-FE-004
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

Complete delivery returns:

~~~text
FINAL STATUS: ACCEPTED
~~~

## 16. Explicit Non-Goals

- User detail API consumption or detail presentation.
- User create/edit/activate/deactivate implementation or mutation.
- Password reset, role/login-name edit, delete/archive, bulk selection/action,
  import/export, or account impersonation.
- Institution Admin or Platform Owner targets.
- Institution profile/dashboard/settings/category work.
- Groups, relationships, topics, assessments, attempts, learning, results, or
  Stage 4+ behavior.
- Client-side search/filter/sort of a partial page.
- Backend/schema/docs/core pagination/router/shell redesign.
- New package/dependency or broad Platform code refactor.

## 17. Stop Conditions

Stop and report before expanding scope if:

- either direct dependency is not Accepted / PASS / Delivered;
- locked docs, S03-BE-003, task, or delivered frontend architecture conflict;
- response uses current_page or another shape instead of exact page contract;
- exact tenant/session isolation or stale-response rejection cannot be proven;
- safe server UUID navigation cannot be guaranteed;
- backend, core pagination, router topology, package, or mutation change appears
  necessary;
- required scope exceeds the file boundary materially;
- repository/Git/GitHub state is unsafe;
- any Phase 2 P1/P2 exists.

## 18. Required Codex Final Report

Report:

- FINAL STATUS;
- Phase 0 branch/main/dependency/clean evidence;
- every changed file and layer responsibility;
- exact endpoint, query map/default/transition, no-body/no-Institution evidence;
- search normalization/254/300 ms/Enter/pending/dedup evidence;
- feature-specific page parser and strict User/pagination malformed matrices;
- empty-page correction request sequence and no-loop evidence;
- state/range/pagination/refresh/retry/latest-query evidence;
- session eligibility/retention/logout/401/account-switch/stale evidence;
- exact table/labels/navigation/accessibility/responsive evidence;
- every command, test count/result, Windows build, and truthful smoke status;
- P1/P2/P3 findings, scope/secret checks, and non-goal confirmation;
- PR/merge SHA/local-main/origin-main/clean delivery evidence when applicable.

End with:

~~~text
No User detail data, mutation, protected field, tenant selector, relationship,
settings/category, or Stage 4 behavior was implemented.
Next implementation gate: S03-FE-005.
~~~
