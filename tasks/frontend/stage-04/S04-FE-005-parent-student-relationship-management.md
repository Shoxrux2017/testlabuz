# S04-FE-005 — Parent–Student Relationship Management

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S04-FE-005` |
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | `Frontend` |
| Status | `Approved` |
| Review | `Complete` |
| Depends on | `S04-FE-004 Accepted / Delivered` |
| Delivery | `Implementation + GitHub delivery` |

Start implementation only when `S04-FE-004` is present on synchronized `origin/main` as `Accepted / Delivered`.

This is the complete task-specific implementation contract for Codex.

Codex may use only this contract, applicable `AGENTS.md` files, and directly relevant source/tests. Do not read product docs, roadmap, previous/future task contracts, Stage history, checkpoint reviews, or closure reviews to determine implementation behavior.

---

## 2. Goal

Add a dedicated Institution Admin desktop surface for managing **current Parent–Student relationships**.

The Institution Admin must be able to:

```text
inspect a Parent's current Students
inspect a Student's current Parents
search/filter/sort/page each current relationship projection
connect one active Parent with one active Student
disconnect one current relationship
keep viewing/disconnecting current relationships when either connected user later becomes inactive
```

Backend remains authoritative for tenant scope, Parent/Student roles, active-user eligibility for a new connection, current relationship existence/privacy, many-to-many cardinality, idempotency, concurrency/locking, history, and timestamps.

No optimistic authoritative relationship state and no automatic mutation replay are allowed.

---

## 3. Scope

### Included

Frontend route:

```text
/institution-admin/users/parent-student-connections
```

Backend API:

```text
GET    /api/v1/institution/parents/{parent}/students
GET    /api/v1/institution/students/{student}/parents
POST   /api/v1/institution/parent-student-relationships
DELETE /api/v1/institution/parent-student-relationships/{relationship}
```

Reuse the existing typed Institution User list repository for:

```text
Parent anchor selection
Student anchor selection
active Parent connect selection
active Student connect selection
```

Implement:

- Users-nested static route and Users-page entry action;
- `By Parent` and `By Student` current-relationship views;
- all-status anchor pickers;
- active-only connect selectors;
- strict relationship/list/pagination DTOs;
- independent perspective query state;
- connect and disconnect mutations;
- exact definite-error parsing;
- uncertain-outcome handling without replay;
- cross-perspective stale markers;
- mutation-induced `checkingCurrentState`;
- route/session/anchor/perspective/relationship stale-async ownership;
- accessibility, focus, and responsive desktop behavior;
- focused deterministic tests.

### Non-goals

Do **not** implement:

- relationship history UI or ended rows;
- mother/father/guardian/relationship-type semantics;
- primary guardian;
- bulk connect/disconnect;
- Parent/Student account create/edit/lifecycle;
- User Detail navigation from relationship rows;
- Group changes;
- relationship hard delete;
- manual relationship dates;
- global backend relationship list;
- N+1 client aggregation;
- optimistic row insertion/removal;
- automatic POST/DELETE replay;
- Institution User list/detail invalidation;
- Dashboard invalidation;
- backend/schema/API/dependency/platform changes.

---

## 4. Current Architecture Boundary

Reuse:

```text
AppRouteNames / AppRoutePaths
existing Institution Admin GoRouter/Shell
Institution Admin Users screen
InstitutionUser
InstitutionUserListQuery
InstitutionUserListRepository
configured Dio / DioFailureMapper
ApiFailure / ApiErrorCodes
existing auth/session/device eligibility patterns
existing Institution Admin UTC formatting convention
```

Responsibility flow:

```text
Presentation
  -> Application / Riverpod controller
  -> Repository contract
  -> Remote data source / strict DTO
  -> configured Dio
```

Selection controllers may use the User list repository but must not read/mutate the main Users list controller or its retained query store.

Do not force Parent–Student relationships into the S04-FE-004 Group membership abstraction; the identity/history/lifecycle API is different.

---

# 5. Exact Frontend Route Contract

## 5.1 Constants

Add exact route name:

```text
AppRouteNames.institutionAdminParentStudentConnections =
    institution-admin-parent-student-connections
```

Add exact static segment:

```text
AppRoutePaths.institutionAdminParentStudentConnectionsSegment =
    parent-student-connections
```

Add exact path:

```text
AppRoutePaths.institutionAdminParentStudentConnections =
    /institution-admin/users/parent-student-connections
```

This is frontend-only. Do not invent a backend `/parent-student-connections` endpoint.

## 5.2 Registries/classification

Required:

1. add `institutionAdminParentStudentConnections` exactly once to `AppRoutePaths.protected`;
2. do not add it separately to `AppRoutePaths.all`;
3. do **not** add it to `institutionAdminPrimaryDestinations`;
4. add it to Institution Admin static-approved locations;
5. add exact helper:

```text
isInstitutionAdminParentStudentConnectionsPath(path)
```

which returns true only for the exact canonical path;
6. keep all route names/paths unique.

The segment `parent-student-connections` must never be treated as a User UUID.

## 5.3 GoRouter order

Add exactly one `GoRoute` inside the existing Institution Admin `ShellRoute`.

Relevant order:

```text
/institution-admin/users
/institution-admin/users/new
/institution-admin/users/parent-student-connections
/institution-admin/users/:userId
```

The Parent–Student static route must be declared before dynamic User Detail.

No new ShellRoute/router family.

## 5.4 Shell behavior

For the route:

```text
selected destination = Users
page title = Parent–Student Connections
```

It is not a primary rail destination.

Do not URL-back or parse route query/fragment into:

```text
perspective
anchor
search
status
sort
page
dialog state
```

Keep the current project policy for static Institution Admin query/fragment behavior; this feature simply ignores them.

---

# 6. Users Screen Entry

Add a Users-page header action:

```text
Parent–Student Connections
```

Preserve:

```text
Create User
```

Use the existing responsive `Wrap`/equivalent so the heading and both actions remain usable at supported widths/text scales.

Navigate by named route.

Do not add relationship actions to User Detail.

---

# 7. Page and Perspective State

Heading:

```text
Parent–Student Connections
```

Top action:

```text
Connect Parent and Student
```

Modes:

```text
By Parent
By Student
```

Default:

```text
By Parent
```

By Parent:

```text
anchor = one Parent
GET /institution/parents/{parentId}/students
rows = current Students
```

By Student:

```text
anchor = one Student
GET /institution/students/{studentId}/parents
rows = current Parents
```

Each perspective independently preserves while this route remains mounted:

```text
selected anchor
search draft
committed query
status
page
perPage
sort
direction
projection stale marker
read state
```

Switching views preserves the hidden perspective's state.

No cross-route persistence after leaving this screen.

---

# 8. Anchor Picker

## 8.1 UX

No anchor means no relationship GET.

`Select Parent` / `Select Student` opens a bounded modal picker with:

```text
search
single-select result list
Previous
Next
Cancel
Select
```

No manual UUID entry.

`Select` disabled until one valid item is selected.

After selection show a page-level summary:

```text
Full name
Login name
Active / Inactive
Change
Clear selection
```

`Clear selection`:

```text
invalidate old-anchor reads
clear relationship data
reset relationship query to initial
return perspective to noAnchor
```

Changing anchor:

```text
invalidate old-anchor publication
reset that perspective relationship query
load new anchor current relationships
```

## 8.2 Fixed User queries

Parent anchor:

```text
role = parent
status omitted
sort = full_name
direction = asc
per_page = 20
```

Student anchor:

```text
role = student
status omitted
sort = full_name
direction = asc
per_page = 20
```

Inactive anchors are valid.

`mustChangePassword` is not an anchor-eligibility rule.

## 8.3 Anchor result invariants

After `InstitutionUserListRepository` returns a page:

Parent purpose:

```text
every user.role == parent
```

Student purpose:

```text
every user.role == student
```

Active or inactive is accepted.

Require case-insensitive unique User IDs in the page.

Wrong-role purpose mismatch:

```text
whole selector page -> invalidResponse
```

Do not silently filter it.

## 8.4 Anchor search/page

Search:

```text
trim outer whitespace
blank -> null
max = 254 Unicode code points
measure = value.runes.length
debounce = exactly 300 ms
```

Exact error:

```text
Search must be 254 characters or fewer.
```

Rules:

- valid input restarts debounce;
- Enter/Search commits immediately;
- changed search resets page 1;
- identical normalized query sends no duplicate;
- invalid search sends no GET;
- Previous/Next cannot paginate an invalid search;
- pending different valid search + Previous/Next commits search and loads page 1;
- non-session failure has manual Retry exact failed query;
- no automatic retry.

At most one page correction per logical picker request:

```text
total == 0
  ? 1
  : max(1, min(last_page, requested_page - 1))
```

---

# 9. Relationship Resource / Identity

List row exact keys:

```text
id
parent_id
student_id
started_at
ended_at
related_user
```

`related_user` exact keys:

```text
id
full_name
login_name
email
phone
is_active
```

No unknown/missing keys.

Rules:

```text
id, parent_id, student_id = canonical hyphen UUID
parent_id != student_id
started_at = valid ISO-8601 UTC ending Z
ended_at = null for current lists
```

Related User:

```text
id = canonical UUID
full_name = non-blank string
login_name = non-blank string
email = nullable string
phone = nullable string
is_active = JSON boolean
```

Do not coerce/trim/default server values.

## 9.1 Direction invariants

By Parent:

```text
relationship.parent_id == selected Parent anchor
related_user.id == relationship.student_id
```

By Student:

```text
relationship.student_id == selected Student anchor
related_user.id == relationship.parent_id
```

Compare UUIDs case-insensitively.

Reject whole page if any row contradicts anchor/direction/opposite-ID invariants.

Reject duplicate relationship IDs case-insensitively.

## 9.2 Disconnect identity

Exact current relationship action identity:

```text
relationship.id
parentId
studentId
startedAt
perspective
selected anchor ID
exact relationship object identity
```

Do not identify a disconnect target only by pair/User/row position.

Disconnect + later reconnect of same pair creates a new current identity and must not receive stale completion/focus from the old relationship.

---

# 10. Relationship List HTTP Contract

By Parent:

```text
GET /institution/parents/{parentId}/students
```

By Student:

```text
GET /institution/students/{studentId}/parents
```

Requirements:

```text
canonical anchor UUID
success = exactly HTTP 200
Dio queryParameters
no data argument
zero request-body bytes
```

Allowed query only:

```text
search
status
page
per_page
sort
direction
```

Defaults:

```text
search = null
status = null
page = 1
per_page = 20
sort = full_name
direction = asc
```

Status:

```text
active
inactive
```

Status applies to related User, not anchor.

Sort:

```text
full_name
started_at
```

Direction:

```text
asc
desc
```

UI page size:

```text
20
50
100
```

Always send:

```text
page
per_page
sort
direction
```

Only send non-null:

```text
search
status
```

Never send blank search, `"all"`, JSON null, unknown keys, tenant selector, or GET body.

---

# 11. Relationship Query Orchestration

Search labels:

```text
By Parent: Search connected students
By Student: Search connected parents
```

Search rules:

```text
trim outer whitespace
blank -> null
max 254 runes
exact 300 ms debounce
literal %, _, ! preserved
changed committed search -> page 1
Enter -> immediate commit
same normalized query -> no duplicate
```

Exact error:

```text
Search must be 254 characters or fewer.
```

Pending different valid draft + Status/Sort/Page size/Refresh:

```text
cancel debounce
commit search into same resulting query
page 1 if search changed
one logical GET
```

Pending different valid draft + Previous/Next:

```text
commit search
load page 1
do not paginate old results
```

Invalid draft blocks:

```text
Search submit
Status
Sort
Page size
Previous
Next
Refresh
```

`Clear filters` remains available.

Status:

```text
All statuses -> null
Active -> active
Inactive -> inactive
```

Status change -> page 1.

Sorting:

```text
Full name -> full_name
Connected -> started_at
different sort -> asc
same sort -> toggle
sort change -> page 1
```

Page size change -> page 1.

Clear filters:

```text
clear searchDraft/search/status/search error
page = 1
preserve perPage/sort/direction
```

Refresh uses exact current committed query; same-query confirmed rows may remain only with explicit refreshing progress.

Retry:

```text
manual
exact failed anchor/query
duplicate protected
no automatic retry
```

Session-authority failures use session reconciliation, not ordinary retryable list error.

---

# 12. Exact List Envelope / Page Correction

Require exactly:

```json
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
```

Reject unknown/missing/renamed envelope/meta/pagination keys.

Pagination integers:

```text
page >= 1 and equals requested page
per_page 1..100 and equals requested perPage
total >= 0
last_page = max(1, ceil(total/per_page))
```

Rows:

```text
count <= per_page
total 0 -> empty + last_page 1
total > 0 -> row count <= total
page > last_page -> only empty data
```

Apply resource/direction uniqueness invariants.

Malformed success -> `invalidResponse`.

At most one automatic correction per logical request:

```text
if empty and requested page > 1:
    target = total == 0
        ? 1
        : max(1, min(last_page, requested_page - 1))
```

Preserve search/status/perPage/sort/direction.

Each perspective owns an independent correction budget.

---

# 13. Relationship List State / Cross-Perspective Stale State

Use one focused list abstraction parameterized by:

```text
byParent
byStudent
```

Each perspective owns:

```text
selected anchor
committed query
search draft/error
current result/failure
projection stale flag
operation generation/in-flight query
eligible session key
correction budget
```

Required states:

```text
noAnchor
loading
queryLoading
refreshing
checkingCurrentState
data
globalEmpty
filteredEmpty
emptyPage
error
```

Never request before anchor.

Reject stale query/old anchor/wrong perspective/dispose/session/institution/device completion.

A hidden perspective may be marked stale.

When switching to a stale hidden perspective:

```text
do not present cached rows as current
auto-load its retained anchor/query
show loading/checking until current read settles
```

For Parent P ↔ Student S:

```text
By Parent matching anchor = P
By Student matching anchor = S
```

After a relevant mutation:

```text
current affected perspective -> stale/reload
matching opposite anchor -> stale
unrelated anchors -> unchanged
```

Hidden matching opposite reloads automatically on next switch.

---

# 14. Mutation-Induced `checkingCurrentState`

After a mutation that succeeded or may have committed, affected old rows are no longer authoritative.

While GET reconciliation runs:

```text
old rows may remain visible only with:
Checking current connections
```

Disable relationship mutation/query controls while the active reconciliation owns the page.

Success:

```text
replace with authoritative page
clear stale
```

Read failure:

```text
discard stale rows
perspective -> error
manual Retry exact anchor/query
```

Never restore stale old rows as confirmed after failed reconciliation.

Mutation outcome and projection read outcome are independent:

```text
confirmed mutation remains confirmed even if later GET fails
unknown mutation remains unknown even if current GET succeeds
```

Do not erase already-settled mutation feedback because a projection object is replaced.

---

# 15. Relationship List UI

Structure:

```text
heading + Connect action
By Parent / By Student
selected anchor summary or no-anchor prompt
toolbar
horizontally scrollable table
pagination
feedback/read state
```

No anchor:

```text
Select a Parent to view current Student connections.
Select a Student to view current Parent connections.
```

Columns:

By Parent:

```text
Student
Login name
Contact
Status
Connected
Action
```

By Student:

```text
Parent
Login name
Contact
Status
Connected
Action
```

Display:

```text
email+phone absent -> Not provided
true -> Active
false -> Inactive
started_at -> YYYY-MM-DD HH:mm UTC
```

Inactive current relationships remain visible/disconnectable.

No User Detail links.

Empty:

```text
No current Student connections
No current Parent connections
```

Filtered:

```text
No matching Student connections
No matching Parent connections
```

Error:

```text
Unable to load connections
```

---

# 16. Connect Dialog User Selection

Dialog:

```text
Connect Parent and Student
```

Actions:

```text
Cancel
Connect
```

No family type field.

Own two independent single selections:

```text
Parent
Student
```

Use one bounded dialog, not nested dialogs.

Exact interaction may use `Parent / Student` segmented mode/tabs inside the dialog.

Always show selected summaries for Parent and Student with `Change`/`Clear` until submit.

Each selector owns independent search/page state.

Selected summary persists while that selector search/page changes.

Closing dialog destroys candidate queries/results/selections.

Connect disabled until both selected.

---

# 17. Connect Candidate Fixed Purpose

Reuse `InstitutionUserListRepository`.

Parent:

```text
role = parent
status = active
sort = full_name
direction = asc
per_page = 20
```

Student:

```text
role = student
status = active
sort = full_name
direction = asc
per_page = 20
```

Search/page follow the same 254-rune, 300 ms, Retry and one-correction rules as anchor picker.

After repository read:

Parent page:

```text
every role == parent
every isActive == true
```

Student page:

```text
every role == student
every isActive == true
```

Require unique User IDs case-insensitively.

Wrong-role/inactive fixed-purpose mismatch -> whole page `invalidResponse`, never silent filtering.

Do not require `mustChangePassword == false`.

Do not enforce absence of existing relationships; backend supports many-to-many/idempotency.

---

# 18. Connect Request / Success

Endpoint:

```text
POST /institution/parent-student-relationships
```

Transport:

```text
Content-Type = application/json
no query
followRedirects = false per existing mutation convention
```

Exact body:

```json
{
  "parent_id": "canonical-parent-uuid",
  "student_id": "canonical-student-uuid"
}
```

Exactly two keys.

Never send institution/connected_by/relationship/date/role/status/type/extra fields.

Confirmed statuses:

```text
201 Created -> new current relationship
200 OK -> already-current idempotent relationship
```

No other 2xx confirmed.

Exact response:

```json
{
  "data": {
    "id": "relationship-uuid",
    "parent_id": "parent-uuid",
    "student_id": "student-uuid",
    "started_at": "UTC timestamp",
    "ended_at": null
  },
  "message": "Parent and student connected successfully."
}
```

Exact top-level keys `data,message`; exact five data keys.

Require:

```text
canonical relationship/parent/student UUIDs
returned pair == submitted pair case-insensitively
parent != student
started_at UTC ending Z
ended_at null
exact success message
```

Do not require a new ID based on HTTP 201 vs 200.

Malformed/wrong status/message/pair -> unknown outcome.

---

# 19. Exact Mutation Error Envelope

Definite mutation failure requires exact envelope:

```json
{
  "message": "non-blank string",
  "code": "non-empty string",
  "errors": {},
  "request_id": "optional non-empty string"
}
```

Required keys:

```text
message
code
errors
```

Optional only:

```text
request_id
```

No unknown keys.

Each error field value is a non-empty array of non-empty strings.

Non-422 definite failure requires empty `errors`.

Allowed exact pairs:

```text
401 authentication_required

403 forbidden
403 password_change_required
403 user_inactive
403 institution_inactive

404 resource_not_found

409 business_conflict

422 validation_failed

429 rate_limited
```

Never branch on backend human message.

Malformed envelope/unsupported pair/transform failure -> uncertain outcome after dispatch.

Connect known 422 fields:

```text
parent_id -> Review the selected Parent.
student_id -> Review the selected Student.
```

If any `body`, query, protected, wrong/unknown key is present, also show:

```text
The connection request did not match the server contract.
```

Empty/unusable 422 errors use the same form-level feedback.

Never render raw validation strings.

---

# 20. Relationship Mutation Arbitration / Dialog Transitions

Only one relationship mutation/dialog at a time:

```text
Connect
Disconnect
```

While an action is open/busy/reconciling disable:

```text
perspective switch
anchor Change/Clear
relationship query controls
Connect
all Disconnect actions
```

### Connect before submit

Allow Cancel/Escape/back/barrier dismissal.

Cancel clears dialog-local state and restores Connect focus only if route/session still current.

### Connect busy

Block dismissal and duplicate submit.

Progress:

```text
Connecting Parent and Student
Checking current connections
```

### Connect recoverable definite failure

For:

```text
422
403 forbidden
429
```

keep dialog open and preserve:

```text
Parent selection/query
Student selection/query
```

Re-enable controls. Later `Connect` is a new explicit POST.

Safe permission/rate messages:

```text
You do not have permission to manage Parent–Student connections.
Too many requests. Wait before trying again.
```

### Connect terminal

For:

```text
404
409
unknown
session loss
route exit
newer ownership
```

close/clear stale dialog. Do not restore obsolete focus.

---

# 21. Confirmed Connect

On strict current 200/201:

1. settle mutation as confirmed;
2. close/clear dialog;
3. publish:

```text
Parent and student connected successfully.
```

4. switch to `By Parent`;
5. set submitted Parent as anchor;
6. same existing Parent anchor -> preserve its relationship query;
7. new Parent anchor -> initial relationship query;
8. mark/reload submitted Parent projection;
9. if retained By Student anchor equals submitted Student, mark that hidden perspective stale;
10. reload hidden opposite only when next shown;
11. no optimistic row insertion.

Do not invalidate Users, Dashboard, Groups.

Confirmed mutation stays confirmed even if the later relationship GET fails.

---

# 22. Connect Definite 404 / 409

### 404

Could be either selected User target.

Do not infer which.

POST is definitely rejected.

Close/clear dialog and show:

```text
One or both selected users are no longer available for this connection.
```

Next Connect uses fresh candidate reads.

No relationship projection reload is required solely to prove this definite failed POST.

### 409 business_conflict

Do not parse human message.

For current backend, this means current user state prevents a new relationship; repeated already-current pair may still be strict 200.

Close/clear dialog and show:

```text
The connection was not accepted because current user state changed. Review active Parents and Students before trying again.
```

Next Connect uses fresh active candidate reads.

No replay.

---

# 23. Unknown Connect Recovery

Never replay POST.

Unknown includes:

```text
connection ambiguity
timeout
Dio cancellation while current operation owns publication
5xx
unexpected status/2xx
malformed error envelope
unsupported status/code pair
malformed success/message/pair
response transform/parsing failure
unexpected post-dispatch exception
```

Exact recovery:

```text
perspective = By Parent
anchor = submitted Parent

searchDraft = ''
search = null
status = null
page = 1
perPage = preserve current By Parent page-size choice
sort = started_at
direction = desc
```

Then:

1. close/clear dialog;
2. mark submitted Parent projection stale;
3. if retained By Student anchor equals submitted Student, mark it stale;
4. authoritatively load By Parent recovery query;
5. do not scan additional pages;
6. do not infer original success from seeing the pair;
7. do not auto-open a row;
8. no POST replay.

One-time warning:

```text
Connection result remains unconfirmed. Review recent current connections before connecting this pair again.
```

A new Connect is a new explicit operation.

---

# 24. Disconnect Contract

Every confirmed current row has:

```text
Disconnect
```

Allowed even when anchor/related User is inactive.

Dialog title:

```text
Disconnect Parent and Student?
```

Show both parties.

Exact explanation:

```text
Disconnecting ends the current Parent–Student relationship and revokes future relationship-based access. Historical relationship records are preserved. Neither user account is deactivated or deleted.
```

Actions:

```text
Cancel
Disconnect
```

Bind to exact relationship identity from Section 9.2.

Endpoint:

```text
DELETE /institution/parent-student-relationships/{relationshipId}
```

Target only `relationship.id`.

Transport:

```text
canonical relationship UUID
no query
no data argument
zero body bytes
followRedirects = false per mutation convention
```

Confirmed success:

```text
exactly 204 No Content
```

Accepted Dio payload:

```text
null
or exact empty string
```

Any meaningful body (`{}`, `[]`, non-empty string, number, boolean) makes outcome unknown.

No automatic DELETE replay.

---

# 25. Disconnect Dialog / Definite Errors

Before submit:

```text
Cancel/Escape/back/barrier dismissal allowed
```

Busy/reconciling:

```text
Cancel disabled
Disconnect disabled
all relationship navigation/query/mutation controls disabled
dismissal blocked
```

Progress:

```text
Disconnecting Parent and Student
Checking current connections
```

Recoverable definite:

```text
403 forbidden
422 validation_failed
429 rate_limited
```

After response:

- close confirmation;
- do not mark relationship projection stale solely for these definite failed requests;
- show safe page feedback;
- restore same Disconnect focus only if exact relationship identity still exists.

Safe feedback:

```text
You do not have permission to manage Parent–Student connections.
The disconnect request did not match the server contract.
Too many requests. Wait before trying again.
```

No automatic retry.

---

# 26. Confirmed / 404 / 409 / Unknown Disconnect

### Confirmed 204

1. settle mutation confirmed;
2. close dialog;
3. mark current perspective stale;
4. mark matching opposite anchor stale;
5. publish:

```text
Parent and student disconnected.
```

6. reload current perspective exact retained query;
7. hidden matching opposite reloads next switch;
8. no optimistic row removal.

Confirmed result remains confirmed even if later GET fails.

### Exact 404

Do not distinguish missing/foreign/inaccessible relationship.

Close dialog, mark current and matching opposite projection stale, reload current perspective, show:

```text
The selected connection is no longer available.
```

No obsolete row focus.

### Exact 409 business_conflict

Not expected by current disconnect business path, but if received as exact centralized error:

```text
definitely rejected
no human-message interpretation
close dialog
mark affected projections stale
reload current perspective
no replay
```

Show:

```text
The disconnect request was not accepted because current server state changed.
```

### Unknown Disconnect

Unknown includes connection/timeout/cancel/5xx/unexpected status/2xx/malformed envelope/unsupported pair/meaningful 204 body/transform error/post-dispatch exception.

Flow:

```text
close dialog
mark current + matching opposite stale
reload current perspective
hidden opposite reloads next switch
no replay
```

Feedback:

```text
Disconnect result could not be confirmed. Review the current connections.
```

Do not say refresh succeeded before GET succeeds.

---

# 27. Anchor Endpoint 404

For relationship GET exact `404 resource_not_found`:

```text
clear selected anchor
invalidate old-anchor requests
clear relationship rows/query back to initial
return perspective to noAnchor
show:
The selected user is no longer available for relationship management.
```

Do not distinguish missing/wrong-role/foreign.

Malformed 404 -> normal read error/invalidResponse, not anchor-not-found.

---

# 28. Session / Async Ownership

Eligible frontend session:

```text
authenticated
institution_admin
active user
must_change_password = false
matching active institution
desktop
```

List read ownership:

```text
perspective
anchor UUID
session key
query
generation
```

Selector read ownership:

```text
selector purpose
session
query
route/dialog ownership
generation
```

Connect operation owns:

```text
session key
exact AuthUser object instance
institution ID
selected Parent object + ID
selected Student object + ID
generation
dialog/route ownership
```

Disconnect owns:

```text
session key
exact AuthUser object
institution ID
perspective
selected anchor object + ID
exact relationship object
relationship ID + parentId + studentId + startedAt
related User object + ID
generation
dialog/route ownership
```

Reject stale publication after:

```text
session/bootstrap/account/institution/device change
route exit
perspective/anchor replacement
relationship replacement/removal/reconnect
dialog/controller dispose
newer operation
```

A stale completion must not close newer dialog, change later anchor, publish to another perspective/session, restore obsolete focus, or navigate.

Actual Dio cancellation is not required.

Session-authority codes:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

clear relationship publication authority and use existing auth/session reconciliation.

`forbidden` is normal definite permission failure.

---

# 29. Tenant / Privacy / History

Never send:

```text
institution_id
connected_by_user_id
tenant selector
role/status override
relationship type
started_at
ended_at
```

Backend owns role, tenant, current existence, active eligibility for new connect, idempotency, locking/concurrency, and timestamps.

Wrong-role/cross-tenant/missing User and relationship targets remain existence-private.

History boundary:

```text
connect -> current row
disconnect -> row gets ended_at
later reconnect -> new current row/new ID
```

Do not query/show history or imply reconnect restores old row.

---

# 30. Accessibility / Responsiveness

Page:

- semantic heading;
- keyboard perspective switch;
- keyboard anchor Change/Clear;
- keyboard search/filter/sort/pagination;
- sort direction semantics;
- Active/Inactive text, not color-only;
- loading/refresh/checking/error live regions;
- horizontal table scroll;
- no supported desktop/text-scale overflow.

Anchor picker:

- bounded size;
- one controlled result scroll;
- predictable search/results/page/Cancel/Select traversal;
- selected candidate announced;
- inactive status visible.

Connect dialog:

- bounded;
- Parent/Student selector mode reachable;
- selected summaries semantic;
- keyboard searches/pages;
- Connect disabled until both selected;
- busy state live;
- busy dismissal blocked.

Disconnect:

- both parties announced;
- exact relationship focus restoration;
- if row disappeared/reconnected, focus section/list surface instead of obsolete button.

Users header actions remain responsive.

No new design system.

---

# 31. Architecture / Expected Files

Expected new files may include:

```text
frontend/lib/features/institution_admin/domain/
  institution_parent_student_relationship.dart
  institution_parent_student_relationship_list.dart
  institution_parent_student_relationship_query.dart
  institution_parent_student_relationship_repository.dart
  institution_parent_student_relationship_mutation.dart
  institution_user_selection.dart

frontend/lib/features/institution_admin/data/
  dto/institution_parent_student_relationship_dto.dart
  dto/institution_parent_student_relationship_list_dto.dart
  dto/institution_parent_student_relationship_mutation_dto.dart
  institution_parent_student_relationship_remote_data_source.dart
  institution_parent_student_relationship_repository_impl.dart

frontend/lib/features/institution_admin/application/
  institution_parent_student_relationship_list_controller.dart
  institution_parent_student_relationship_list_state.dart
  institution_parent_student_relationship_action_controller.dart
  institution_parent_student_relationship_action_state.dart
  institution_user_selection_controller.dart
  institution_user_selection_state.dart

frontend/lib/features/institution_admin/presentation/
  institution_admin_parent_student_connections_screen.dart
```

Expected modifications:

```text
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
frontend/lib/features/institution_admin/presentation/institution_admin_shell.dart
frontend/lib/features/institution_admin/presentation/institution_admin_users_screen.dart
```

Focused presentation helpers/dialogs are allowed.

Do not:

- add Dio to Widgets/controllers;
- parse JSON in presentation/controllers;
- create second User repository/client;
- mutate main Users retained state;
- create global relationship aggregation;
- force this into Group membership abstractions;
- change Group code;
- change backend/docs/packages/platform files.

Any additional file requires a concrete in-scope reason and must be reported.

---

# 32. Acceptance Criteria

- [ ] S04-FE-004 is Accepted / Delivered on synchronized `origin/main` before implementation.
- [ ] Exact static route name/segment/path/registries/order are implemented.
- [ ] Static route precedes User Detail and is never interpreted as UUID.
- [ ] Shell selects Users and title is `Parent–Student Connections`.
- [ ] No feature state is URL-backed.
- [ ] Users page exposes responsive Parent–Student Connections action.
- [ ] By Parent / By Student preserve independent in-memory anchor/query state.
- [ ] No anchor produces zero relationship requests.
- [ ] Anchor pickers are bounded all-status role-specific single-select pickers.
- [ ] Wrong-role anchor results are invalidResponse; inactive anchors remain valid.
- [ ] Anchor selector search/debounce/retry/correction is exact.
- [ ] Relationship resource/list envelope/direction/anchor invariants are strict.
- [ ] Relationship identity prevents stale disconnect/reconnect confusion.
- [ ] Relationship GET uses exact query/no body and accepts only 200.
- [ ] Relationship search pending/invalid/clear/retry/correction behavior is exact.
- [ ] Inactive current related users remain visible/disconnectable.
- [ ] Connect uses one bounded dialog with independent active Parent/Student selectors.
- [ ] Connect selectors reject wrong-role/inactive fixed-purpose mismatches.
- [ ] Connect sends exact two-key JSON/no query.
- [ ] Connect accepts strict 201/200 success.
- [ ] Exact mutation error envelope/status-code pairs are enforced.
- [ ] Connect recoverable 422/403/429 preserves dialog selections/query.
- [ ] Connect 404/409 closes stale dialog without target/message inference or replay.
- [ ] Unknown connect uses exact recent-current recovery query and stays unconfirmed.
- [ ] Disconnect targets exact relationship UUID, not User pair.
- [ ] DELETE uses zero body/query and strict 204 null/empty payload.
- [ ] Disconnect recoverable 403/422/429 is definite and does not stale projections.
- [ ] Disconnect 404/409/unknown reloads current state without replay/existence leakage.
- [ ] Only one relationship mutation/dialog may own the page.
- [ ] Mutation busy state blocks perspective/anchor/query/other mutation changes.
- [ ] Matching hidden opposite perspective is marked stale and reloads on next switch.
- [ ] Mutation-induced old rows are explicitly checking/non-authoritative.
- [ ] Failed reconciliation discards stale rows.
- [ ] Confirmed mutation remains confirmed despite later read failure.
- [ ] Unknown feedback never falsely claims refresh success.
- [ ] Anchor list exact 404 clears anchor privately.
- [ ] Main Institution Users retained/controller state is untouched.
- [ ] No User/Dashboard/Group invalidation.
- [ ] Session/tenant/privacy/stale-async/focus rules hold.
- [ ] Keyboard/accessibility/responsive tests pass.
- [ ] No backend/schema/dependency/public API change.
- [ ] Focused verification passes.
- [ ] `git diff --check` passes.
- [ ] Final diff is in scope.

---

# 33. Focused Tests and Verification

Use real existing filenames if an equivalent delivered test has a different name. Do not create duplicate tests only to satisfy an expected filename.

From repository root:

```powershell
Push-Location frontend

fvm spawn 3.44.7 test `
  test/features/institution_admin/institution_parent_student_relationship_domain_test.dart `
  test/features/institution_admin/institution_parent_student_relationship_dto_test.dart `
  test/features/institution_admin/institution_parent_student_relationship_list_dto_test.dart `
  test/features/institution_admin/institution_parent_student_relationship_remote_data_source_test.dart `
  test/features/institution_admin/institution_parent_student_relationship_repository_impl_test.dart `
  test/features/institution_admin/institution_parent_student_relationship_list_controller_test.dart `
  test/features/institution_admin/institution_user_selection_controller_test.dart `
  test/features/institution_admin/institution_parent_student_relationship_action_controller_test.dart `
  test/features/institution_admin/institution_admin_parent_student_connections_screen_test.dart `
  test/app/router/institution_admin_route_paths_test.dart `
  test/features/institution_admin/institution_admin_shell_test.dart `
  test/features/institution_admin/institution_admin_users_screen_test.dart

Pop-Location
```

Required focused coverage:

```text
route static order/classification/shell title/Users entry
anchor all-status role invariants/search/page/correction
connect active role invariants and selector isolation
no main Users retained-state mutation
relationship query/search pending/invalid/clear/retry/correction
strict list/resource/direction/pagination parsing
cross-perspective stale reload
checkingCurrentState + failed reconciliation drops stale rows
connect exact 201/200/error/unknown recovery/no replay
disconnect exact identity/204/body/error/unknown/no replay
disconnect/reconnect new identity stale safety
session/tenant/privacy/route/perspective/anchor ownership
focus/keyboard/semantics/text scale/desktop overflow
```

Directly affected regression is already included for:

```text
institution_admin_route_paths_test
institution_admin_shell_test
institution_admin_users_screen_test
```

Run Institution User list/query/repository tests only if their production files are modified. Reusing an unchanged repository does not justify broad User regressions.

No Group tests are required because Group production changes are not authorized.

Static:

```powershell
Push-Location frontend
fvm spawn 3.44.7 analyze
Pop-Location
```

Format:

```powershell
Push-Location frontend

C:\Users\Administrator\fvm\versions\3.44.7\bin\cache\dart-sdk\bin\dart.exe `
  format --output=none --set-exit-if-changed lib test

Pop-Location
```

Manual:

```text
Not required — deterministic route/domain/data/repository/controller/widget tests
cover this task. Real-stack/Windows E2E belongs to Stage integration/checkpoint.
```

Always:

```powershell
git diff --check
```

Focused diff review must confirm:

```text
no Group/backend/package/platform changes
static route before User Detail
no global N+1 relationship aggregation
no family/history/bulk semantics
no optimistic state
no mutation replay
exact GET/POST/DELETE transport
strict 404/privacy/business_conflict handling
all-status anchors vs active-only connect
main Users retained state untouched
cross-perspective stale semantics
unknown connect recovery never claims success
disconnect/reconnect identity safety
no stale rows after failed reconciliation
no raw exception/JSON/token/private data
no weakened tests/debug/temp artifacts
```

Do **not** run full frontend suite, Windows build, broad E2E, Frontend Phase 2, or Stage integration for this task.

If implementation requires unapproved shared scope:

```text
BLOCKED
```

instead of silently broadening work.

---

# 34. Delivery

Branch:

```text
task/s04-fe-005-parent-student-connections
```

Commit:

```text
feat(frontend): manage parent student connections
```

PR:

```text
focused PR to main
```

Task/Stage bookkeeping:

```text
None
```

After merge require:

```text
implementation on origin/main
local main == origin/main
ahead/behind = 0/0
working tree clean
```

Verification pass but delivery failure:

```text
DELIVERY BLOCKED
```

---

# 35. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to reinterpret requirements.

| Source/reference | Decision already encoded |
|---|---|
| Parent→Students / Student→Parents controllers | exact anchor-based current relationship GET APIs |
| Parent/Student list requests/actions | query bounds, current-only relationships, all-status anchors, related-user filters |
| Relationship list resource/collection | exact row + related_user + pagination contract |
| Connect request/controller/action | exact two-key POST, 201/200 idempotency, locked role/tenant/active rules |
| Disconnect request/controller/action | relationship-ID DELETE, zero body/query, 204 history-preserving idempotency |
| Mutation/list API tests | strict transport, privacy-equivalent 404s, inactive-current behavior, reconnect new ID |
| Concurrency tests | duplicate connect/disconnect and connect/disconnect/user-deactivation ordering |
| Institution User list repository/query | selector reads without new API or Users-state mutation |
| Current route/shell/Users screen | static route ordering and Users destination/header integration |
| Delivered FE-001…003 | Institution Admin route/session/failure patterns |
| Approved/delivered FE-004 | fixed-purpose User selector patterns only; no abstraction reuse |
| `frontend/AGENTS.md` | strict DTOs, stale async, no false authoritative state, focus/accessibility |

---

# 36. Codex Final Report

Return:

1. `ACCEPTED`, `BLOCKED`, or `DELIVERY BLOCKED`.
2. Implementation summary.
3. Changed files/purpose.
4. Acceptance evidence.
5. Exact verification commands/results.
6. Route/static-order/shell/Users-entry evidence.
7. Anchor fixed-role/all-status/no-Users-state-corruption evidence.
8. By Parent/By Student query/DTO/pagination/cross-stale evidence.
9. Connect active-selection + 201/200/error/unknown recovery/no-replay evidence.
10. Disconnect identity + 204/error/reconnect/no-replay evidence.
11. Projection checking/read-failure/confirmed-vs-read-state evidence.
12. Tenant/404 privacy/session/stale-async evidence.
13. Accessibility/focus/responsive evidence.
14. `git diff --check` + focused scope review.
15. Commit/PR/merge/main-sync evidence.
16. Exact deviations/blockers.

If any required product, architecture, API, security, tenant, lifecycle, concurrency, selector, routing, cross-perspective, mutation-outcome, async-ownership, reconciliation, focus, or UX decision is missing/conflicting:

```text
BLOCKED
```

Do not invent behavior.
