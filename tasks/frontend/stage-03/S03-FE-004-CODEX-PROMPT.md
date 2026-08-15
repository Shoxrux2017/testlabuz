# Codex Execution Prompt — S03-FE-004

Execute only:

~~~text
S03-FE-004 — Institution User List, Search, Filters, Sorting, and Pagination
~~~

Repository:

~~~text
G:\project\testlabuz
~~~

Detailed task:

~~~text
tasks/frontend/stage-03/S03-FE-004-institution-user-list-search-filters-pagination.md
~~~

Branch:

~~~text
task/s03-fe-004-institution-user-list
~~~

## 1. Authority and Entry Gate

Read completely, in this order:

1. root AGENTS.md;
2. frontend/AGENTS.md;
3. the full detailed S03-FE-004 task;
4. tasks/README.md and tasks/STAGE_03_TASK_INDEX.md;
5. accepted S03-INT-001;
6. the exact task-referenced sections of docs/02–09;
7. accepted S03-BE-003 task, implementation, tests, and delivery evidence;
8. delivered S03-FE-001, S03-FE-002, and S03-FE-003 code/tests;
9. accepted Stage 2 Platform Institution list patterns;
10. current frontend code, tests, Git state, and GitHub state.

The pair was prepared before all frontend predecessors were delivered.
Therefore do not trust a planning claim that dependencies are already complete.

Before any implementation, prove on current origin/main that both:

~~~text
S03-FE-003 = Accepted / PASS / Delivered
S03-BE-003 = Accepted / PASS / Delivered
~~~

If either is missing, return a dependency blocker and stop. Do not create the
task branch or edit implementation files.

If task, locked documents, delivered backend, or frontend architecture
conflict, stop and report the exact conflict. Do not invent a reconciliation.

## 2. Phase 0 — Git Preflight

Perform read-only preflight:

- verify the expected GitHub origin; never replace an unexpected remote;
- fetch safely;
- prove local main == origin/main;
- prove the worktree is clean except only owner-prepared S03-FE-004 authority
  files when applicable;
- verify the detailed task status is Approved;
- resolve the actual delivered Users placeholder, route helpers, and existing
  Institution Admin test filenames;
- inspect the current shared ApiPaginationMeta incompatibility;
- inspect relevant Platform list patterns without changing them;
- create/switch to task/s03-fe-004-institution-user-list only after every gate
  passes.

Stop on dirty, divergent, unsafe, conflicting, or missing-dependency state.
Preserve unrelated user work. Do not use destructive cleanup. Do not commit,
push, create a PR, or merge before Phase 2 PASS.

## 3. Phase 1 — Exact Implementation

Replace only the Institution Admin Users placeholder with a server-driven,
read-only desktop list using:

~~~text
GET /api/v1/institution/users
~~~

Required flow:

~~~text
screen/controller
  -> Institution User list repository
  -> Institution User list remote data source
  -> existing configured authenticated Dio client
~~~

Create feature-local domain/query/page/repository, strict DTO/data source,
repository implementation, controller/state, formatters, screen, and focused
tests within the detailed task's allowlist. Reuse core auth/network/router
infrastructure. Do not modify the shared pagination parser, backend, docs,
router topology, shell architecture, Platform feature, or dependencies.

### Exact request

Send one logical GET with zero body bytes and no Institution selector.

Always send:

~~~text
page
per_page
sort
direction
~~~

Send only when selected/non-blank:

~~~text
role = teacher | student | parent
status = active | inactive
search = trimmed non-empty maximum 254
~~~

Defaults:

~~~text
role/status/search = omitted
page = 1
per_page = 20
sort = full_name
direction = asc
~~~

UI page sizes are exactly 20/50/100. Sort fields are exactly full_name,
login_name, created_at, and updated_at. A new sort field uses asc; the selected
field toggles asc/desc. Search/filter/sort/page-size changes reset page to 1.
Previous/Next preserve the rest of the committed query. Clear filters clears
only search/role/status and preserves sort/direction/page size.

Use Dio queryParameters. Preserve literal !, %, _, apostrophe, spaces, and
non-ASCII input. Never build a raw query string, send current_page, all, blank,
null, institution_id, an unknown key, or client-side partial-page
filtering/sorting.

### Exact search orchestration

- keep draft text separate from committed normalized search;
- trim before blank/max validation;
- maximum is 254 Unicode code points after trimming (Dart runes, not bytes or
  UTF-16 code units);
- debounce exactly 300 ms;
- Enter/Search commits immediately and cancels the timer;
- duplicate normalized query sends no duplicate GET;
- 255+ shows local safe error and sends nothing;
- while invalid, query-changing controls send nothing except Clear filters;
- a valid pending search plus filter/sort/page-size/Refresh commits both in one
  page-1 GET;
- Previous/Next with a different pending valid search commits search to page 1;
- cancel timer on disposal/session loss;
- identical in-flight query is deduplicated;
- latest query/session/generation wins over stale success or failure.

### Exact response parser

Do not reuse current core ApiPaginationMeta: it expects current_page and is
incompatible.

Create a feature-specific strict parser for:

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

Require exact top-level/meta/pagination/resource keys and types. Pagination:

- page >= 1 and equals requested page;
- per_page 1..100 and equals requested perPage;
- total >= 0;
- last_page = max(1, ceil(total/per_page));
- rows <= per_page and consistent with total;
- total 0 means empty data and last_page 1;
- page > last_page is valid only with empty data;
- current_page is invalid here.

Parse each User with exactly:

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

Require canonical UUID, exact eligible role, non-blank required strings,
nullable contact strings, JSON booleans, required/present nullable UTC
timestamps ending in Z, active/deactivated lifecycle consistency, and no
duplicate page IDs. Reject malformed, missing, unknown, or protected fields.
Never coerce or default malformed data.

Never model/render/cache/log:

~~~text
institution_id
created_by_user_id
creator
credentials/tokens
permissions
settings
relationships
learning/answer/score/result data
~~~

### Exact bounded empty-page correction

For one logical query, allow at most one automatic correction:

- only when valid response data is empty and requested page > 1;
- target page 1 when total = 0;
- otherwise target = max(1, min(last_page, requested page - 1));
- preserve every other committed query field;
- update committed page and issue one corrective GET;
- never correct twice or loop;
- stale correction cannot publish;
- page 1 never auto-corrects;
- if the corrected result still has total > 0 but no rows, show safe Empty page
  with manual Page 1/Previous/Refresh.

### Session and failures

Send no GET unless the current session is authenticated, active
institution_admin, password change is not required, institution_id is non-empty,
nested Institution exists/matches/is active, and the surface is approved
desktop.

Key retained/in-flight state by session user id + User object instance identity
+ Institution id. Retain only query/search draft across same-session
detail/create navigation, then reload from server on return. Never retain final
rows. Logout, bootstrap transition, 401, inactivity, first-login, Institution
change, same-role/cross-role switch, disposal, or loss of eligibility clears
rows/actions/retained query/timers and invalidates stale operations.

Use central 401 invalidation. Reconcile password_change_required, user_inactive,
and institution_inactive through the accepted auth path. Show safe error state
for forbidden/validation/not-found/invalid-response/timeout/connection/server
failures. Retry/Refresh are duplicate-protected. Never show/log raw server
message, payload, URL, SQL, stack, identifier, or token.

### Exact UI

Toolbar:

~~~text
Users
Create User
Search users
Role: All roles / Teacher / Student / Parent
Status: All statuses / Active / Inactive
Clear filters
Refresh
Page size: 20 / 50 / 100
~~~

Exact table:

~~~text
Full name    sortable full_name
Login name   sortable login_name
Role
Contact
Status
First login
Created      sortable created_at
Updated      sortable updated_at
~~~

Labels:

~~~text
Teacher / Student / Parent
Active / Inactive
Password change required / Completed
Not provided when both email and phone are null
YYYY-MM-DD HH:mm UTC
~~~

Show truthful start-end of total and Page page of last_page. Previous/Next
enablement uses returned metadata. Implement distinct initial loading, query
loading, refreshing, data, global empty, filtered empty, post-correction empty
page, and safe error/Retry states.

Create navigates through the delivered route helper to
/institution-admin/users/new. Row pointer/keyboard activation navigates through
the delivered helper using only parsed server UUID to
/institution-admin/users/:userId. Do not call detail API or implement detail/
create/mutation behavior.

Support 800x600, 1440x900, text scale 2.0, long content, horizontal table
scrolling without overflow, pointer, keyboard, visible focus, semantics,
tooltips, and non-color status/sort/selection indication.

### Phase 1 bookkeeping

Change only the S03-FE-004 Stage 3 index row to:

~~~text
In Progress / Not started / Not started
~~~

Keep the detailed task Approved and preserve this prompt byte-for-byte. Do not
update acceptance/delivery/README state before Phase 2. Do not stage or commit.

## 4. Required Verification

Implement every automated matrix in detailed task Section 14, including:

- query serialization/transitions/search boundaries/debounce/dedup;
- exact User/page DTO success and malformed/unknown/protected matrices;
- explicit page success and current_page rejection;
- exact Dio path/query/auth/options/zero-body/no-Institution evidence;
- controller states, rapid queries, stale rejection, bounded correction;
- session eligibility/retention/logout/401/account switches;
- UI labels/columns/ranges/empty/error/navigation/accessibility/layout;
- no detail API, mutation, protected fields, client pseudo-filter/sort;
- Institution Admin/auth/router/Platform regressions.

Run from frontend:

~~~text
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/features/institution_admin
flutter test
flutter build windows --debug
~~~

Run the resolved focused FE001–003 route/shell tests, tracked-file scope check,
secret scan, and complete diff review. Perform the detailed task's manual
Windows real-stack smoke when safely available. Mark unavailable smoke items
NOT RUN with the exact reason; never fabricate evidence.

## 5. Phase 2 — Strictly Read-Only Acceptance

After Phase 1, review the complete result against every detailed-task
requirement. Phase 2 permits:

~~~text
no edits or auto-fix/write-format
no bookkeeping changes
no staging or commit
no push, PR, or merge
no self-fixing findings
~~~

Classify P1/P2/P3 exactly as the detailed task defines. Any unresolved P1 or P2
returns:

~~~text
FINAL STATUS: NOT ACCEPTED
~~~

Stop without delivery and do not start S03-FE-005.

## 6. Phase 3 — Delivery Only After PASS

After Phase 2 PASS only:

- change this detailed task from Approved to Accepted without changing behavior;
- prepare only the S03-FE-004 index row as Accepted / PASS / Delivered;
- update tasks/README.md truthfully with S03-FE-005 as next gate;
- keep Stage 3 open and Stage 4 blocked;
- preserve this execution prompt byte-for-byte;
- stage only approved implementation/tests/task/prompt/index/README files;
- commit exactly:

~~~text
feat(institution): add user management list UI

Task: S03-FE-004
~~~

Push the exact branch, create a PR to main, verify base/head/diff/green checks,
merge only when safe, fast-forward local main, and prove:

~~~text
local main == origin/main
git status --short is empty
~~~

Phase 2 PASS but incomplete safe delivery:

~~~text
FINAL STATUS: DELIVERY BLOCKED
~~~

Complete verified delivery:

~~~text
FINAL STATUS: ACCEPTED
~~~

Return the full evidence required by detailed task Section 18 and end with:

~~~text
No User detail data, mutation, protected field, tenant selector, relationship,
settings/category, or Stage 4 behavior was implemented.
Next implementation gate: S03-FE-005.
~~~
