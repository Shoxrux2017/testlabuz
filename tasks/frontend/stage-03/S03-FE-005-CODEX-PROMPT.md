# Codex Execution Prompt — S03-FE-005

Execute only:

~~~text
S03-FE-005 — Institution User Detail
~~~

Repository:

~~~text
G:\project\testlabuz
~~~

Detailed task:

~~~text
tasks/frontend/stage-03/S03-FE-005-institution-user-detail.md
~~~

Branch:

~~~text
task/s03-fe-005-institution-user-detail
~~~

The complete detailed task is authoritative. Read it fully before doing
anything. This prompt is an execution control, not a substitute for the task.

## 1. Authority and Hard Dependency Gate

Read completely, in this order:

1. root `AGENTS.md`;
2. `frontend/AGENTS.md`;
3. this prompt and the complete S03-FE-005 detailed task;
4. `tasks/README.md` and `tasks/STAGE_03_TASK_INDEX.md`;
5. accepted S03-INT-001 contract/task-control record;
6. relevant `docs/02` through `docs/09` sections named by the task;
7. accepted S03-BE-003 task, implementation, tests, review, and delivery;
8. delivered S03-FE-001 and S03-FE-004 code and tests;
9. accepted Stage 2 Platform detail patterns only as structural reference.

Do not infer that a dependency is delivered from this prepared prompt. At the
time this pair was prepared, S03-BE-003 was delivered but S03-FE-004 was not.
Phase 0 must establish current repository truth.

Production implementation is blocked unless both:

~~~text
S03-BE-003 = Accepted / PASS / Delivered on current origin/main
S03-FE-004 = Accepted / PASS / Delivered on current origin/main
~~~

If either is not independently proven, stop and report `BLOCKED`. Do not create
the branch, edit implementation, change status, commit, push, or create a PR.

If locked documents, the accepted backend, the detailed task, or delivered
frontend dependencies conflict, stop and report the exact conflict. Do not
silently choose or invent a rule.

## 2. Phase 0 — Read-Only Git and Repository Preflight

Before implementation:

1. Verify the detailed task status is `Approved`.
2. Verify the expected GitHub origin and fetch safely.
3. Prove local `main == origin/main`.
4. Prove both direct dependencies are Accepted / PASS / Delivered on that main.
5. Prove the worktree is clean except only owner-prepared S03-FE-005 task/prompt
   files when they are not yet committed.
6. Resolve the delivered FE001 route, decoded `userId`, route helper, direct-entry
   guard, shell, and detail placeholder.
7. Resolve the delivered FE004 InstitutionUser domain model, strict User parser,
   formatters, list navigation, retained-query behavior, session conventions,
   and affected tests.
8. Resolve the accepted BE003 request, exact success/error envelopes, 12-field
   resource, tenant/role scope, and uniform not-found behavior.
9. Identify which conditionally allowed files from the detailed task are
   actually necessary.
10. Preserve unrelated user work and stop on dirty, conflicting, or unsafe Git
    state.
11. Only after all gates pass, create or switch to the exact task branch from
    approved current main.

No commit, push, PR, or merge is allowed before Phase 2 PASS.

## 3. Exact Implementation Goal

Replace only the Institution Admin User-detail placeholder with a real,
read-only Windows desktop screen for one own-Institution Teacher, Student, or
Parent.

Load only through:

~~~text
GET /api/v1/institution/users/{user}
~~~

Implement list-to-detail, direct entry, reload, system/browser back, canonical
Back to Users, strict parsing, public-field display, safe not found, Refresh,
retryable recovery, and complete target/session stale-response isolation.

Do not implement any User mutation or later-stage behavior.

## 4. Route Target and Path Contract

The only target authority is the already-decoded, FE001-validated GoRouter path
parameter:

~~~text
userId
~~~

Never use a list row object, row index, search value, name, login, contact,
query parameter, cached target, or client-provided Institution ID as detail
authority.

Preserve the accepted FE001 detail-route grammar exactly:

~~~text
canonical hyphenated UUID shape
8-4-4-4-12 hexadecimal characters
case-insensitive
~~~

Do not broaden the route helper/classifier to accept arbitrary segments.

Apply these exact rules:

1. Read the decoded route parameter once. Do not decode it again.
2. Do not trim, lowercase, canonicalize, or rewrite it before the request.
3. FE001 rejects missing, empty, whitespace, `new`, non-UUID, incomplete/extra
   UUID, slash/backslash, traversal, control, query/fragment, encoded-separator,
   and extra-path locations before the detail screen is built.
4. Preserve FE001's safe fallback to canonical `/institution-admin`; malformed
   locations send no detail GET and do not become a detail not-found state.
5. If the screen/controller is invoked directly with a missing/noncanonical
   value, fail closed locally and send no request.
6. Every FE001-valid canonical UUID is safely encoded once and sent to backend.
7. Do not perform client-side existence, tenant, role, or active-state lookup.
8. Valid unknown, foreign, Platform Owner, and Institution Admin UUIDs all use
   the same accepted backend `404 resource_not_found` presentation.

BE003 still returns uniform 404 for malformed UUIDs sent by another API client.
The accepted TestLabUz Flutter route does not deliberately send them.

The remote data source receives the decoded FE001-valid canonical UUID and
constructs:

~~~text
/api/v1/institution/users/{Uri.encodeComponent(target)}
~~~

Encode exactly once as one path segment. Valid uppercase/lowercase hexadecimal
UUID forms remain the exact route value and cannot alter path/query/fragment.

The route:

~~~text
/institution-admin/users/new
~~~

must always remain the create placeholder/owner route. It must never construct
the detail screen or send a detail GET. Preserve route names, paths, helpers,
classification, ordering, and shell topology.

## 5. Exact Request Contract

Send:

~~~text
Method: GET
Path: /api/v1/institution/users/{encoded-valid-user-id}
Query: none
Body: zero bytes
Tenant selector: none
Auth: existing configured authenticated Dio client
~~~

Do not send a request body, `{}`, `[]`, JSON null, whitespace, query keys,
Institution ID, role/status fields, include/expand values, tenant-like custom
headers, or list-row data.

Do not add a new client, token handling, interceptor, logger, feature automatic
retry, or transport policy. One initial load, Refresh, or allowed Retry equals
one logical GET, subject only to the accepted central safe-GET behavior.

## 6. Exact Success and Shared User Contract

HTTP 200 must contain exactly one top-level key:

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

There is no success `message`, `meta`, pagination, links, included data, or
relationship. Reject missing, renamed, wrong-type, or extra top-level values.

The detail envelope must delegate `data` to the exact FE004 shared User parser.
Do not copy, loosen, coerce, or default the parser. Reuse the same
InstitutionUser domain model and display formatters.

If the FE004 parser is private inside the list DTO, minimally extract it into
one feature-local shared `institution_user_dto.dart`; make both list and detail
envelopes delegate to it and preserve FE004 behavior/tests exactly. A duplicate
detail parser is forbidden.

The shared resource has exactly these 12 fields:

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

Preserve FE004 strict UUID, eligible-role, string/null, boolean, UTC-with-Z,
lifecycle-consistency, exact-key, and no-trim/no-coercion rules.

Never model, retain, render, navigate with, or feature-log protected/internal
fields, including Institution IDs, creator IDs, passwords, tokens,
permissions, settings, relationships, learning records, answers, scores, or
results.

## 7. Response Target Match

Before accepting HTTP 200:

- the requested FE001-valid route target must parse as a UUID;
- the response `data.id` must represent the same UUID;
- only case differences in a syntactically equivalent UUID are allowed.

A different response UUID is an invalid response. Clear displayed data and show
only the safe non-retryable invalid-response error. Do not redirect, rewrite the
URL, or display a User different from the route target.

## 8. Not Found and Error Contract

Use dedicated not found only for:

- defensive direct screen/controller invocation with a missing/noncanonical
  target, with no request; or
- HTTP 404 for an FE001-valid UUID with exact stable code
  `resource_not_found` and a valid accepted error envelope.

Use this exact presentation for every accepted unavailable case:

~~~text
Title: User unavailable
Message: This user does not exist or is not available to your account.
Action: Back to Users
~~~

Do not show the attempted target, UUID validity, existence, tenant, role, raw
backend message, or payload. Definitive not found has no Retry or Refresh.

A malformed 404 error envelope or another code is an invalid-response error,
not accepted not found.

Classify other failures exactly:

- HTTP 401 / `authentication_required`: central invalidation; immediately clear
  detail data and actions;
- password-change, User-inactive, or Institution-inactive lifecycle failures:
  clear detail and use accepted auth bootstrap/reconciliation;
- forbidden and validation failure: safe non-retryable error;
- invalid envelope/resource/target mismatch: safe non-retryable invalid-response
  error;
- connection, timeout, server error/5xx, and accepted unknown transient failure:
  retryable with duplicate-protected Retry;
- no feature-level automatic retry.

Generic error copy:

~~~text
Title: Unable to load user details
Message: User details could not be loaded safely.
Actions: Back to Users; Retry only for a classified retryable failure
~~~

Never render or feature-log raw message, validation errors, URL, target,
response body, SQL, stack trace, token, Institution, or exception text.

## 9. Eligibility, State, and Stale Safety

Allow no detail GET unless frontend session state is all of:

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

Bind every operation/result to:

~~~text
session user id
session User object instance identity
institution id
exact decoded route target
operation generation
controller not disposed
~~~

Only the latest operation matching every value may publish.

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

Required behavior:

- one initial load for an eligible target;
- no previous User data during initial or changed-target loading;
- target A to B clears A immediately before requesting B;
- same-role and cross-role account switches clear old data immediately;
- logout, bootstrap, 401, inactive account/Institution, first-login requirement,
  Institution mismatch, disposal, or route exit clears data/actions and
  invalidates generation;
- stale success, 404, error, and Refresh completion cannot publish;
- identical in-flight target/session operations are deduplicated;
- Retry is available only from retryable error and is duplicate-protected;
- Refresh is available only in data state and issues one current-target GET;
- Refresh may retain only current same-target/same-session data with a clear
  busy indication and disabled conflicting controls;
- Refresh success replaces data;
- Refresh 404, 401, target/session change, invalid response, or non-retryable
  failure removes displayed data immediately;
- no detail data survives route disposal or is shared between target IDs;
- returning to a detail route loads fresh server data.

Do not use a FE004 list row as initial authoritative detail data. FE004 alone
owns retained list query state.

## 10. Exact Read-Only UI

Use:

~~~text
Heading: User details
Data-state title: server full_name
Action: Back to Users
Data-state action: Refresh
~~~

Render exactly four sections and all 12 fields:

| Section | Label | Display |
|---|---|---|
| Identity | Full name | Exact `full_name` |
| Identity | Login name | Exact `login_name` |
| Identity | Role | Teacher / Student / Parent |
| Identity | User ID | Exact canonical UUID, read-only/selectable |
| Contact | Email | Exact value or `Not provided` |
| Contact | Phone | Exact value or `Not provided` |
| Account state | Status | Active / Inactive |
| Account state | First login | Password change required / Completed |
| Activity and lifecycle | Last login | UTC timestamp or `Never` |
| Activity and lifecycle | Deactivated | UTC timestamp or `Not deactivated` |
| Activity and lifecycle | Created | UTC timestamp |
| Activity and lifecycle | Updated | UTC timestamp |

Use the FE004 timestamp formatter exactly:

~~~text
YYYY-MM-DD HH:mm UTC
~~~

Do not convert to machine-local or guessed Institution time.

Back to Users must use the delivered named route/helper to canonical:

~~~text
/institution-admin/users
~~~

Do not rely only on `Navigator.pop`; direct entry may have no useful app
history. Preserve normal system/browser back. Do not create list state or rows.

Use the existing Material 3 shell/theme. Prove 800x600, 1440x900, text scale
2.0, long values, scrolling, no overflow, keyboard activation, visible focus,
predictable order, tooltips, selectable/read-only content, useful semantics/live
regions, and non-color-only role/status/first-login/error meaning.

Do not add edit, create, activate, deactivate, delete, reset-password, role,
login-name, or other mutation controls.

## 11. Architecture and Change Boundary

Required flow:

~~~text
detail screen/controller
  -> detail repository
  -> detail remote data source
  -> existing configured Dio client
~~~

Expected new production files are the detail repository contract, exact detail
DTO, remote data source, repository implementation, state, and controller named
in the detailed task. Modify the delivered detail placeholder screen.

Conditionally allowed only when proven necessary:

- minimal shared parser extraction and corresponding FE004 list DTO/test update;
- minimal existing router wiring/test update to pass decoded `userId` into the
  real screen, without changing route contract/topology;
- minimal FE001 shell/router/detail-placeholder tests whose no-request or
  placeholder assertions this task intentionally makes obsolete;
- minimal FE004 row-navigation/list tests whose placeholder assertion this
  task intentionally makes obsolete.

Preserve every unrelated predecessor assertion. Name every conditional change
and why it was necessary in the final report. Stop if broader production or
test changes are needed.

Do not change backend, schema, docs, packages, core network/auth, Platform
Admin, route families/helpers, shell topology, list behavior, or unrelated
code. Do not add fake APIs, mutations, settings/categories, learning/results,
or Stage 4 behavior.

## 12. Required Tests

Implement the complete detailed-task matrix, including:

- exact data-only envelope and strict 12-field shared-parser reuse;
- extra/missing/wrong keys, protected keys, UUID, role/type/null/UTC/lifecycle;
- requested/response UUID equality and case equivalence;
- mismatched response ID rejection;
- exact encoded GET path, no query/body/tenant selector, central client;
- valid uppercase/lowercase canonical UUID path cases;
- FE001 malformed/empty/reserved/extra detail-location fallback with no detail
  screen/GET, plus defensive direct invalid-target no-request cases;
- accepted and malformed 404, 401, 403, 422, 5xx, timeout, connection, invalid
  response mappings;
- eligibility/session matrix, deduplication, Refresh and Retry rules;
- A-to-B, session/account/bootstrap/logout/401/disposal/route-exit stale cases;
- direct entry, reload, URL truth, `/users/new`, list-to-detail, system back,
  canonical Back to Users, and FE004 retained-list ownership;
- exact headings, four sections, 12 labels/values, null copy, UTC, selectable ID,
  active/inactive and lifecycle presentation;
- loading, refreshing, not-found, retryable, and non-retryable states/actions;
- no protected/raw data and no mutation controls;
- compact/wide/text-scale/long-content/scroll/keyboard/focus/semantics/live
  region/tooltips/non-color behavior;
- narrow FE001/FE004 updates and full auth/router/shell/dashboard/profile/list/
  Platform regressions.

Run from `frontend` and observe every final exit status:

~~~text
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/features/institution_admin
flutter test test/app/router
flutter test
flutter build windows --debug
~~~

Also run every focused test for conditionally changed predecessor files,
tracked-file allowlist/scope review, complete diff review, secret scan, prompt
byte comparison, and current configured repository quality gates.

Do not claim a command passed unless its final output and exit status were
observed. Record unavailable real-stack/Windows smoke items as `NOT RUN` with
the exact reason; never fabricate evidence or modify shared/production data.

## 13. Phase 1 Bookkeeping

Implement only the approved task scope. Before Phase 2:

1. Change only the S03-FE-005 Stage index row to
   `In Progress / Not started / Not started`.
2. Minimally correct only directly adjacent Stage index narrative, count, and
   next-gate text if needed so it does not still call S03-FE-005 Draft.
3. Do not change another task's status, review, or delivery values.
4. Keep the detailed task status `Approved`.
5. Preserve this paired prompt byte-for-byte.
6. Do not update README acceptance/delivery state.
7. Run all checks and inspect the complete diff.
8. Do not stage, commit, push, create a PR, or merge.

## 14. Phase 2 — Strictly Read-Only Acceptance Gate

Re-read authority and review the complete result and diff: target, route,
request, envelope, resource, UUID match, session, stale state, errors, not found,
navigation, disclosure, accessibility, predecessor regressions, commands,
build/smoke, scope, bookkeeping consistency, and secrets.

Phase 2 permits:

~~~text
no edits, auto-fix, or write-format
no task/index/README changes
no staging or commit
no push, PR, or merge
no self-fixing findings
~~~

Classify all findings as P1, P2, or P3 according to the detailed task.

Any unresolved P1 or P2 requires:

~~~text
FINAL STATUS: NOT ACCEPTED
~~~

Stop without delivery. Do not start S03-FE-006. Report every P3; P3 alone does
not block PASS.

## 15. Phase 3 — Post-Acceptance Delivery

Only after Phase 2 PASS with no unresolved P1/P2:

1. Change only this task status from Approved to Accepted without rewriting the
   approved behavior.
2. Set only the S03-FE-005 index row to Accepted / PASS / Delivered and update
   directly related count/narrative/next-gate consistency.
3. Update `tasks/README.md` truthfully: Stage 3 remains In Progress,
   S03-FE-005 is delivered, and S03-FE-006 is next.
4. Keep later tasks truthful, Stage 3 open, and Stage 4 blocked.
5. Preserve this prompt byte-for-byte.
6. Re-run final non-writing diff/scope/secret/prompt/consistency checks.
7. Stage only approved implementation/tests, task, unchanged prompt, index, and
   README.
8. Commit exactly:

   ~~~text
   feat(institution): add user detail UI

   Task: S03-FE-005
   ~~~

9. Push the exact branch, create a PR to main, verify base/head/diff/checks, and
   merge only when safe, green, and permitted.
10. Fast-forward local main and prove local main equals origin/main with a clean
    worktree.

Phase 2 PASS but incomplete verified delivery requires:

~~~text
FINAL STATUS: DELIVERY BLOCKED
~~~

Complete verified delivery requires:

~~~text
FINAL STATUS: ACCEPTED
~~~

## 16. Stop Conditions

Stop before widening scope if a dependency is not delivered, authority
conflicts, the shared parser cannot be safely reused/extracted, route encoding
or UUID match cannot be proven, uniform not found or stale isolation cannot be
proven, broader predecessor rewrites are required, backend/core/auth/package/
route-topology/mutation work appears necessary, Git/GitHub is unsafe, or Phase
2 has any P1/P2.

## 17. Required Final Report

Return all evidence required by Section 17 of the detailed task, including:

- final status and Phase 0 dependency/origin/branch/clean proof;
- every changed file and conditional-file justification;
- FE001-validated route source, malformed-location fallback, valid-UUID
  one-time encoding, and `/users/new`;
- exact GET/no-query/zero-body/no-tenant evidence;
- shared parser, exact envelope/resource, protected-key, and UUID-match proof;
- safe 404/error/retryability and absence of raw disclosure;
- state/dedup/Refresh/Retry/latest-target/session/disposal proof;
- exact 12-field UI, null/UTC/status/role/first-login/ID evidence;
- direct/list/reload/system-back/Back-to-Users navigation;
- responsive, keyboard, focus, semantics, live-region, and non-color evidence;
- predecessor regressions and preserved assertions;
- every command/result, Windows build, and truthful smoke status;
- P1/P2/P3, scope, secret, prompt, and bookkeeping results;
- PR, merge SHA, main equality, and clean-delivery proof when applicable.

End exactly with:

~~~text
No User mutation, client tenant authority, protected data, relationship,
settings/category, learning, or Stage 4 behavior was implemented.
Next implementation gate: S03-FE-006.
~~~
