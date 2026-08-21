# S04-FE-005 — Parent–Student Relationship Management

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S04-FE-005` |
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | `Frontend` |
| Status | `Draft` |
| Review | `Pending` |
| Depends on | `S04-FE-004 Accepted / Delivered` |
| Delivery | `Implementation + GitHub delivery` |

This file is the complete task-specific implementation contract for Codex.

> **Execution gate:** This file is intentionally stored before final review. Codex must not implement this task while `Status = Draft`. ChatGPT/reviewer must complete read-only review, resolve findings, change the task to `Approved`, and deliver that planning update to `main` first.

Codex must use only this contract, applicable `AGENTS.md` files, and directly relevant source/tests. Do not read product docs, roadmap, previous tasks, Stage history, or closure reviews to determine behavior.

---

## 2. Goal

Add a dedicated Institution Admin desktop surface for managing **current Parent–Student connections**.

The feature must let an Institution Admin:

- inspect a Parent's current Students;
- inspect a Student's current Parents;
- search/filter/sort/page those current relationships;
- connect one active Parent with one active Student;
- disconnect one current relationship;
- continue seeing/disconnecting current relationships when either connected user later becomes inactive.

The feature must preserve backend-authoritative tenant scope, role validation, user-active eligibility for new connections, relationship history, and concurrency semantics.

---

## 3. Scope

### Included

Add frontend route:

```text
/institution-admin/users/parent-student-connections
```

Consume exactly:

```text
GET    /api/v1/institution/parents/{parent}/students
GET    /api/v1/institution/students/{student}/parents
POST   /api/v1/institution/parent-student-relationships
DELETE /api/v1/institution/parent-student-relationships/{relationship}
```

Reuse the existing Institution User list API for Parent/Student selection:

```text
GET /api/v1/institution/users
```

Implement:

- Users-nested navigation entry;
- `By Parent` and `By Student` current-connection views;
- all-status anchor selection for inspecting existing relationships;
- active-only Parent/Student selection for creating a connection;
- strict relationship/list/pagination DTOs;
- connect and disconnect mutation flows;
- exact definite-error handling;
- uncertain-outcome handling without automatic mutation replay;
- route/session/tenant/stale-async ownership;
- accessible desktop UI;
- focused deterministic tests.

### Non-goals

Do **not** implement:

- relationship history UI;
- ended relationship list;
- family/kinship types such as mother/father/guardian;
- primary parent/guardian semantics;
- bulk connect/disconnect;
- Parent or Student account creation/edit/lifecycle;
- Parent or Student detail navigation from connection rows;
- Group membership changes;
- Group UI changes;
- relationship hard deletion;
- relationship start/end date editing;
- global backend relationship-list endpoint;
- optimistic relationship state;
- automatic mutation replay;
- backend/schema/API changes;
- dependency/package changes.

---

# 4. Current Implementation Context

Existing Institution Admin Users architecture already provides:

- `/institution-admin/users`;
- `/institution-admin/users/new`;
- `/institution-admin/users/:userId`;
- strict UUID route helpers;
- `InstitutionUser`;
- `InstitutionUserListQuery`;
- typed Institution User list repository;
- server-driven role/status/search/sort/pagination;
- Institution Admin shell/session guards.

S04-FE-001…004 add Group functionality but this task remains owned by the existing `institution_admin` feature. It must not be placed under Group membership abstractions.

Reuse:

```text
Presentation
  -> Application / Riverpod controller
  -> Repository contract
  -> Remote data source / strict DTO
  -> configured Dio
```

Candidate/anchor selection may reuse the existing `InstitutionUserListRepository`, but must use route/dialog-local controllers so the main Users screen retained query state is not changed.

---

# 5. Route and Institution Admin Shell

## 5.1 Route declaration

Add:

```text
AppRouteNames.institutionAdminParentStudentConnections
```

Canonical path:

```text
/institution-admin/users/parent-student-connections
```

Suggested static segment:

```text
parent-student-connections
```

This is a **frontend route only**. Do not invent a matching backend `/parent-student-connections` API.

The static route must be declared/classified so it is never interpreted as:

```text
/institution-admin/users/:userId
```

`parent-student-connections` is not a User UUID.

Update strict Institution Admin approved-location classification.

The route is not a primary shell destination.

Shell behavior:

```text
selected destination = Users
page title = Parent–Student Connections
```

Existing Institution Admin desktop/session guards remain unchanged.

---

## 5.2 Users screen entry point

Add a visible action on the Institution Admin Users screen:

```text
Parent–Student Connections
```

Place it with the existing Users page header actions in a responsive `Wrap`/equivalent so Create User and relationship-management actions do not overflow.

Activating it navigates to:

```text
/institution-admin/users/parent-student-connections
```

Do not add relationship controls to individual User Detail in this task.

---

# 6. Page UX

Heading:

```text
Parent–Student Connections
```

Top-level action:

```text
Connect Parent and Student
```

Provide two view modes:

```text
By Parent
By Student
```

Default:

```text
By Parent
```

These are two perspectives over the same current Parent–Student relationships.

### By Parent

1. select a Parent anchor;
2. read:
   `GET /institution/parents/{parent}/students`;
3. list current related Students.

### By Student

1. select a Student anchor;
2. read:
   `GET /institution/students/{student}/parents`;
3. list current related Parents.

Each perspective owns an independent current anchor + relationship-list query while the route remains mounted.

No cross-route persistence is required after leaving this screen.

---

# 7. Anchor Selection for Current-Relationship Inspection

## 7.1 Why anchor selection is required

Backend provides no global current relationship list.

Therefore the frontend must select an authorized Parent or Student before requesting relationships.

Do not attempt to simulate a global relationship table by enumerating all Users and performing N+1 relationship requests.

---

## 7.2 Anchor selectors

By Parent selector:

```text
Select Parent
```

By Student selector:

```text
Select Student
```

Use the existing Institution User list repository.

### Parent anchor query

Fixed:

```text
role = parent
status = omitted
sort = full_name
direction = asc
per_page = 20
```

### Student anchor query

Fixed:

```text
role = student
status = omitted
sort = full_name
direction = asc
per_page = 20
```

Omitting status is intentional: an inactive Parent or Student may still have current relationships that must remain visible and disconnectable.

Anchor selector supports:

```text
search
page
```

Search:

- max 254 characters;
- trim leading/trailing whitespace;
- blank means no search;
- 300 ms debounce;
- submit commits immediately;
- page resets to 1.

Display each candidate:

```text
Full name
Login name
Active / Inactive
Email/phone
```

Selection is single-select.

Do not mutate the Institution Users page's retained query/controller.

---

## 7.3 Anchor state

When no anchor is selected:

By Parent:

```text
Select a Parent to view current Student connections.
```

By Student:

```text
Select a Student to view current Parent connections.
```

Changing anchor:

- resets that perspective's relationship query to initial defaults;
- invalidates in-flight read publication for the old anchor;
- loads the new anchor's current relationships.

Switching `By Parent` / `By Student` preserves each perspective's currently selected anchor/query while the page remains mounted.

If an anchor-specific relationship endpoint returns exact:

```text
404 resource_not_found
```

clear that anchor after safe reconciliation/feedback:

```text
The selected user is no longer available for relationship management.
```

Do not reveal whether the target was missing, wrong-role, or outside the Institution.

---

# 8. Exact Current Relationship List Resource

Each list row must contain exactly:

```text
id
parent_id
student_id
started_at
ended_at
related_user
```

`related_user` must contain exactly:

```text
id
full_name
login_name
email
phone
is_active
```

## 8.1 Relationship fields

`id`

```text
canonical hyphenated UUID
```

`parent_id`

```text
canonical hyphenated UUID
```

`student_id`

```text
canonical hyphenated UUID
```

Parent and Student IDs must differ.

`started_at`

```text
required valid UTC timestamp ending in Z
```

`ended_at`

For these **current** list endpoints:

```text
must be null
```

A non-null `ended_at` in a successful current-list response is invalid response data.

---

## 8.2 Related User fields

`related_user.id`

```text
canonical hyphenated UUID
```

`full_name`

```text
non-blank string
```

`login_name`

```text
non-blank string
```

`email`

```text
nullable string
```

`phone`

```text
nullable string
```

`is_active`

```text
JSON boolean
```

### Direction invariants

By Parent:

```text
relationship.parent_id == selected Parent ID
related_user.id == relationship.student_id
```

By Student:

```text
relationship.student_id == selected Student ID
related_user.id == relationship.parent_id
```

Reject a page as malformed if direction/anchor invariants contradict the request.

Reject duplicate relationship IDs in one page.

Malformed success responses map to existing local:

```text
invalidResponse
```

handling.

---

# 9. Current Relationship List API

## 9.1 By Parent

```text
GET /institution/parents/{parentId}/students
```

## 9.2 By Student

```text
GET /institution/students/{studentId}/parents
```

No request body.

Allowed query keys:

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

The status filter applies to the **related user**, not the selected anchor.

Allowed sorts:

```text
full_name
started_at
```

Directions:

```text
asc
desc
```

Maximum:

```text
per_page <= 100
```

UI page sizes:

```text
20
50
100
```

No unknown query keys.

---

# 10. Relationship List Query Behavior

Each perspective has independent query state.

## 10.1 Search

By Parent label:

```text
Search connected students
```

By Student label:

```text
Search connected parents
```

Rules:

- max 254 characters;
- trim leading/trailing whitespace;
- blank means omit `search`;
- preserve case/special characters otherwise;
- `%`, `_`, `!` are literal user text;
- 300 ms debounce;
- keyboard submit commits immediately;
- invalid over-length draft sends no request;
- committed search change resets page to 1.

## 10.2 Status filter

```text
All statuses
Active
Inactive
```

This filters current related users by account active state.

Changing filter resets page to 1.

## 10.3 Sorting

Columns:

```text
Full name
Connected
```

Mapping:

```text
Full name -> full_name
Connected -> started_at
```

Rules:

- default Full name ascending;
- different sort => ascending;
- current sort => toggle asc/desc;
- sort change resets page to 1.

## 10.4 Pagination

- Previous / Next;
- page sizes 20/50/100;
- page-size change resets page to 1;
- suppress duplicate same-query requests;
- replacement-query load does not present old rows as current confirmed results;
- explicit Refresh retains current confirmed rows with visible progress;
- after disconnect empties/out-ranges the current page, perform at most one automatic correction to page 1 or valid last_page.

---

# 11. Exact List Envelope

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

Pagination must satisfy the established strict Institution Admin list invariants:

- JSON integers;
- requested page match;
- requested per_page match;
- total >= 0;
- mathematically correct last_page, with 1 when total is 0;
- row count <= per_page;
- zero total has zero rows;
- out-of-range page contains zero rows.

---

# 12. Relationship List UI

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

- full name;
- login name;
- email/phone;
- no contact => `Not provided`;
- `Active` / `Inactive` explicit text, not color-only;
- `started_at` using existing Institution Admin UTC formatting;
- current row always has `ended_at == null`;
- action = `Disconnect`.

Inactive connected users remain visible.

Disconnect remains available even when the selected anchor or related user is inactive.

Do not link rows to User Detail in this task.

---

## 12.1 Empty states

No anchor:

```text
Select a Parent to view current Student connections.
Select a Student to view current Parent connections.
```

Selected anchor, no current connections:

```text
No current Student connections
No current Parent connections
```

Filtered/search empty:

```text
No matching Student connections
No matching Parent connections
```

with:

```text
Clear filters
```

---

## 12.2 Loading/error

Initial:

```text
Loading connections
```

Replacement query:

```text
Loading matching connections
```

Refresh:

- keep current confirmed rows;
- visible/semantic progress.

Error:

```text
Unable to load connections
```

Retry only when allowed by existing safe failure semantics.

---

# 13. Connect Parent and Student Dialog

Open from:

```text
Connect Parent and Student
```

Title:

```text
Connect Parent and Student
```

The dialog contains exactly two independent single-select active-user selectors:

```text
Parent
Student
```

Both must be selected before submit.

Actions:

```text
Cancel
Connect
```

No relationship type/label field.

---

# 14. Connect Candidate Selection

Use existing Institution User list repository with route/dialog-local state.

## 14.1 Parent candidate query

Fixed:

```text
role = parent
status = active
sort = full_name
direction = asc
per_page = 20
```

## 14.2 Student candidate query

Fixed:

```text
role = student
status = active
sort = full_name
direction = asc
per_page = 20
```

Each selector independently supports:

```text
search
page
```

with standard 254-character / 300 ms search behavior.

Only server-returned active Users are selectable.

Candidate may become inactive after loading; frontend does not treat stale `is_active` as authority at mutation time.

Selected user summaries remain visible when candidate search/page changes.

Do not allow manual UUID entry.

Do not persist dialog candidate query/selection after closing.

---

# 15. Exact Connect Request

Endpoint:

```text
POST /institution/parent-student-relationships
```

No query parameters.

Exact JSON keys:

```json
{
  "parent_id": "canonical-parent-uuid",
  "student_id": "canonical-student-uuid"
}
```

Do not send:

```text
institution_id
connected_by_user_id
relationship_id
started_at
ended_at
role
status
relationship_type
```

or any other field.

Parent and Student are exactly the selected typed User IDs.

---

# 16. Connect Success Contract

Confirmed success statuses:

```text
201 Created -> new current relationship created
200 OK      -> same relationship was already current; idempotent no-op
```

Exact envelope:

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

Require exact top-level keys:

```text
data
message
```

Require exact message:

```text
Parent and student connected successfully.
```

Strict mutation resource:

- exact five data keys;
- canonical relationship/parent/student UUIDs;
- returned parent_id equals submitted Parent ID;
- returned student_id equals submitted Student ID;
- valid UTC started_at;
- ended_at must be null.

Do not require a new relationship ID for 201 vs 200 in the frontend; backend status is authoritative.

Do not require user active state in this response because it contains no user resource and an already-current relationship is idempotently valid even if a user became inactive.

---

# 17. Confirmed Connect UI

On confirmed 200/201:

1. close dialog;
2. clear dialog candidate state;
3. switch page to:

```text
By Parent
```

4. select the submitted Parent as the Parent anchor;
5. if that Parent was already the selected Parent, preserve its current relationship query;
6. if it is a new anchor, use initial relationship query;
7. reload that Parent's current Students authoritatively;
8. if the submitted Student is currently selected as the By Student anchor, also mark/reload that perspective;
9. show live-region feedback:

```text
Parent and student connected successfully.
```

Do not insert a relationship row optimistically.

Do not invalidate Institution User list/detail/dashboard: this relationship mutation does not change the current User resource contract or current Institution dashboard user counts.

---

# 18. Connect Definite Failures

Treat mutation failure as definite only for exact expected API error envelopes.

Recognized:

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

## 18.1 422 validation_failed

Normal client state should prevent invalid request shape.

Safe form-level feedback:

```text
The connection request did not match the server contract.
```

Do not display raw backend validation strings.

## 18.2 404 resource_not_found

May represent:

- missing Parent;
- wrong-role Parent;
- foreign Parent;
- missing Student;
- wrong-role Student;
- foreign Student.

Do not identify which target failed.

Close stale dialog, clear selection, and show:

```text
One or both selected users are no longer available for this connection.
```

Candidate data must be reloaded on the next connect attempt.

Do not disclose existence or role beyond current authorized User list reads.

## 18.3 409 business_conflict

For current backend connect behavior, a new relationship is rejected when one or both selected users are inactive. Do not parse backend message text.

Close stale dialog, clear selection, and show:

```text
The connection was not accepted because current user state changed. Review active Parents and Students before trying again.
```

Next connect attempt uses fresh active candidate data.

A repeated request for an already-current pair may still succeed with 200 even if a connected user became inactive; accept the backend result.

## 18.4 Forbidden / rate limit

```text
You do not have permission to manage Parent–Student connections.
Too many requests. Wait before trying again.
```

Session-authority failures follow the existing auth/session reconciliation boundary.

---

# 19. Connect Uncertain Outcome

Do not automatically replay POST.

Treat outcome as unknown when commit success cannot be proven:

- timeout;
- connection interruption after dispatch;
- 5xx;
- malformed/unexpected error envelope;
- unexpected HTTP status;
- malformed 200/201 success;
- wrong message;
- request/returned pair mismatch;
- unexpected post-dispatch exception.

On uncertain connect:

1. close dialog;
2. clear dialog selection/query state;
3. switch to `By Parent`;
4. select the submitted Parent as anchor;
5. reload its current Student connections;
6. reload the submitted Student's perspective too only if that Student is already the active By Student anchor;
7. do not scan all pages or manufacture proof of the mutation;
8. do not replay POST;
9. show:

```text
Connection result could not be confirmed. Current connections were refreshed; review them before trying again.
```

The refreshed list is authoritative current state, but the originating mutation remains unconfirmed.

A new connect requires reopening the dialog and explicitly selecting the pair again.

---

# 20. Disconnect Relationship UX

Every current relationship row has:

```text
Disconnect
```

Use the exact relationship row object from the current list.

Dialog title:

```text
Disconnect Parent and Student?
```

Show both known parties:

- selected anchor summary;
- related user's full name + login name.

Explanation:

```text
Disconnecting ends the current Parent–Student relationship and revokes future relationship-based access. Historical relationship records are preserved. Neither user account is deactivated or deleted.
```

Actions:

```text
Cancel
Disconnect
```

No family type/meaning is implied.

Disconnect is allowed even when either displayed user is inactive.

---

# 21. Exact Disconnect Request

Endpoint:

```text
DELETE /institution/parent-student-relationships/{relationshipId}
```

Target:

```text
relationship.id
```

Do **not** disconnect by Parent ID + Student ID.

Send:

```text
no request body
no query parameters
```

Expected confirmed success:

```text
204 No Content
```

Require no meaningful response body.

Backend semantics:

- current relationship -> sets authoritative `ended_at`;
- already-ended relationship -> idempotent 204;
- historical row remains persisted;
- Parent/Student accounts are unchanged.

Frontend current-list endpoints naturally stop returning ended relationships.

---

# 22. Confirmed Disconnect UI

On confirmed `204`:

1. close dialog;
2. reload the current perspective list using its existing anchor/query;
3. if the opposite perspective is currently anchored to the related user in the same relationship, mark/reload it too;
4. show:

```text
Parent and student disconnected.
```

Do not optimistically delete the row.

If reloaded pagination becomes empty/out-of-range, use the one-time page correction rule.

No Institution User list/detail/dashboard invalidation is required.

---

# 23. Disconnect Definite Failures

Recognized exact error envelopes:

```text
401 authentication_required
403 forbidden
403 password_change_required
403 user_inactive
403 institution_inactive
404 resource_not_found
422 validation_failed
429 rate_limited
```

`409 business_conflict` is not part of the current disconnect business contract. If an exact centralized 409 is unexpectedly received in future/current runtime, treat it as a safe general rejected mutation and do not infer a relationship state from message text.

## 23.1 404 resource_not_found

Relationship ID may be missing/foreign/inaccessible.

Close stale confirmation and reload the current list.

Show:

```text
The selected connection is no longer available.
```

Do not reveal whether a foreign relationship exists.

## 23.2 422

```text
The disconnect request did not match the server contract.
```

## 23.3 Forbidden / rate limit

```text
You do not have permission to manage Parent–Student connections.
Too many requests. Wait before trying again.
```

Session failures use existing auth/session reconciliation.

---

# 24. Disconnect Uncertain Outcome

Do not automatically replay DELETE.

Even though backend disconnect is idempotent, client confirmation requires an observed response.

For timeout/connection/5xx/malformed/unexpected result:

1. close/settle stale confirmation safely;
2. reload current perspective list;
3. reload opposite perspective only if already active for that related user;
4. do not claim confirmed success/failure;
5. do not replay DELETE;
6. show:

```text
Disconnect result could not be confirmed. Current connections were refreshed.
```

If the relationship is absent after refresh, that is authoritative current state, but the originating request remains unconfirmed.

---

# 25. Reconnect / History Boundary

Backend relationship history is preserved:

```text
connect
-> current relationship row

disconnect
-> same row gets ended_at

later reconnect
-> new relationship row with a new relationship ID
```

Frontend in this task displays **current relationships only**.

Do not:

- query historical rows;
- show prior started/ended periods;
- reuse an old ended relationship ID;
- imply that reconnect restores the old relationship row.

A later successful connect simply appears as a current connection returned by list APIs.

---

# 26. Current Inactive Users

Current Parent–Student relationships survive account deactivation.

Therefore:

- inactive selected anchors are valid for relationship list reads;
- inactive related users remain visible;
- current connections involving inactive users remain disconnectable;
- `Active`/`Inactive` must be displayed clearly.

Creating a **new** relationship requires backend-authoritative active Parent + active Student, which is why connect candidate selectors are active-only.

Do not automatically disconnect relationships when a User becomes inactive.

---

# 27. Relationship List Application State

Use one focused relationship-list abstraction parameterized by perspective:

```text
byParent
byStudent
```

A list instance is keyed/owned by:

```text
perspective
selected anchor UUID
eligible Institution Admin session
authenticated user instance
institution ID
query
operation generation
```

State supports:

```text
noAnchor
loading
queryLoading
refreshing
globalEmpty
filteredEmpty
emptyPage
data
error
```

Requirements:

- canonical anchor UUID;
- no request before an anchor exists;
- suppress duplicate same-query requests;
- stale superseded query cannot publish;
- old anchor completion cannot publish;
- By Parent cannot overwrite By Student state;
- dispose/session/institution/device change invalidates publication;
- same-route perspective switch preserves each perspective's in-memory anchor/query;
- no persistent cache after route exit is required.

Actual Dio cancellation is not required.

---

# 28. Anchor/Candidate Selector State

Implement a focused reusable Institution User selection controller with explicit purpose:

```text
anchorParent
anchorStudent
connectParent
connectStudent
```

Do not introduce a global User selection cache.

Fixed role/status behavior belongs to the controller/query contract, not Widgets.

Stale completion must not:

- update a closed selector;
- replace selection in another selector;
- publish across session/institution/device change;
- corrupt main Institution Users list retained state.

Anchor selection persists while page route remains mounted.

Connect selection is destroyed when dialog closes.

---

# 29. Relationship Mutation Ownership

A connect operation owns:

```text
eligible session key
authenticated user instance
institution ID
selected Parent object/UUID
selected Student object/UUID
operation generation
dialog/focus ownership
```

A disconnect operation owns:

```text
eligible session key
authenticated user instance
institution ID
perspective
selected anchor identity
exact current relationship object
related user identity
relationship UUID
operation generation
dialog/focus ownership
```

Publication is allowed only while ownership remains current.

Reject stale completion after:

- logout/session replacement;
- Institution change;
- desktop eligibility loss;
- route exit;
- newer mutation;
- selected anchor replacement;
- relationship row replacement/removal;
- dialog/controller disposal.

Stale completion must not:

- close a newer dialog;
- change a later anchor;
- show feedback in another session;
- publish into another perspective;
- navigate.

---

# 30. Session / Authorization / Tenant Isolation

Eligible frontend actor:

```text
authenticated
role = institution_admin
active user
must_change_password = false
active own institution
desktop surface
```

The frontend sends no:

```text
institution_id
connected_by_user_id
tenant selector
role override
status override
relationship type
started_at
ended_at
```

Backend remains authoritative for:

- Parent role;
- Student role;
- same-Institution scope;
- user-active eligibility for new connections;
- relationship existence/privacy;
- idempotency;
- locking/concurrency;
- history timestamps.

A UUID obtained elsewhere does not expand scope.

Wrong-role, cross-tenant, missing, and foreign relationship targets must remain existence-private.

Frontend hiding/route guards are UX only.

---

# 31. Accessibility / Keyboard / Focus / Responsiveness

Page:

- route heading semantic;
- `By Parent` / `By Student` keyboard selectable;
- anchor selector keyboard accessible;
- search/filter/sort/pagination controls keyboard reachable;
- sort direction announced;
- Active/Inactive not color-only;
- loading/refresh/error feedback live-region capable;
- tables horizontally scroll instead of overflowing;
- supported desktop resizing/text scaling must not produce RenderFlex overflow.

Connect dialog:

- predictable Parent -> Student -> Cancel -> Connect traversal;
- each selector has accessible selected summary;
- search/page controls usable by keyboard;
- submit disabled until both users selected;
- duplicate submit impossible;
- mutation/reconciliation prevents dismissal;
- busy state announced.

Disconnect dialog:

- relationship parties clearly announced;
- Cancel/Disconnect keyboard reachable;
- busy state prevents dismissal;
- after close, restore focus to the relationship row/action only if it still exists;
- if row disappeared, focus relationship section heading/list surface.

Users header action:

- remains usable with Create User at supported widths/text scales.

Do not introduce a new design system.

---

# 32. Architecture and Placement

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

Focused presentation helpers/dialog files are allowed where they improve responsibility boundaries.

Reuse:

```text
InstitutionUser
InstitutionUserListQuery
InstitutionUserListRepository
configured Dio
DioFailureMapper
ApiFailure / ApiErrorCodes
existing Institution Admin session snapshot/key patterns
existing UTC formatter
```

Do not:

- add Dio calls in Widgets;
- parse JSON in presentation/controllers;
- add a second HTTP client;
- mutate main Users page retained controller/store;
- create a backend-like global relationship aggregation in the client;
- force this Parent–Student API into S04-FE-004 Group membership abstractions;
- create Group changes;
- modify backend/docs/packages/platform folders.

Any extra file requires a concrete in-scope reason and must be reported.

---

# 33. Acceptance Criteria

- [ ] `/institution-admin/users/parent-student-connections` is canonical, approved, selected under Users, and not interpreted as User detail.
- [ ] Users screen exposes `Parent–Student Connections`.
- [ ] Page provides `By Parent` and `By Student` views.
- [ ] All-status Parent/Student anchor selection supports inactive users.
- [ ] No N+1/global relationship enumeration is introduced.
- [ ] By Parent uses only `GET /parents/{parent}/students`.
- [ ] By Student uses only `GET /students/{student}/parents`.
- [ ] Current relationship resource + related_user are parsed strictly.
- [ ] Direction invariants and selected-anchor IDs are validated.
- [ ] Lists support exact search/status/sort/pagination.
- [ ] Current inactive connected users remain visible and disconnectable.
- [ ] Relationship history is not displayed.
- [ ] Connect dialog selects exactly one active Parent and one active Student.
- [ ] Connect sends only `parent_id` + `student_id`.
- [ ] Connect accepts `201` new and `200` already-current success.
- [ ] Connect success resource/message/pair are validated strictly.
- [ ] Connect does not optimistically create rows.
- [ ] 404 connect does not disclose which target failed.
- [ ] 409 connect handles stale inactive-user state without parsing human messages.
- [ ] Unknown connect is not replayed and switches to/refetches authoritative current Parent connections.
- [ ] Disconnect targets exact relationship UUID, not user-pair IDs.
- [ ] Disconnect sends bodyless/queryless DELETE and accepts `204`.
- [ ] Disconnect is UI-allowed even when Parent/Student is inactive.
- [ ] Disconnect does not optimistically remove rows.
- [ ] 404/unknown disconnect reloads current state without existence leakage or auto-replay.
- [ ] Reconnect is treated as a new current relationship; no history restoration semantics are invented.
- [ ] Main Institution Users list retained query state is unaffected by selectors.
- [ ] Session/institution/route/perspective/anchor/mutation stale completions cannot publish.
- [ ] No Group behavior is changed.
- [ ] No backend/schema/dependency/public API change.
- [ ] Keyboard/accessibility/responsive requirements are covered.
- [ ] Focused verification passes.
- [ ] `git diff --check` passes.
- [ ] Diff contains no unrelated work.

---

# 34. Focused Tests and Verification

## Required focused coverage

### Route / shell / Users entry

- exact route name/path/static segment;
- static route cannot be User UUID detail;
- approved-location classification;
- Users shell selection;
- page title;
- role/device/session route guards;
- Users header action navigation/responsiveness.

### Relationship domain/query

- perspective endpoint mapping;
- initial query;
- search trim/blank/max;
- status active/inactive;
- sort toggle;
- page/per-page resets;
- independent perspective query state.

### Relationship DTO/list DTO

- valid By Parent row;
- valid By Student row;
- inactive related user;
- nullable contact;
- exact relationship keys;
- exact related_user keys;
- canonical UUIDs;
- valid started_at;
- current ended_at must be null;
- anchor/direction mismatch rejected;
- related_user/opposite-ID mismatch rejected;
- duplicate relationship IDs rejected;
- exact pagination;
- contradictory pagination rejected.

### Relationship read remote/repository

- exact Parent->Students GET path/query;
- exact Student->Parents GET path/query;
- no GET body;
- strict DTO/domain mapping;
- malformed success -> invalidResponse;
- exact error mapping.

### Relationship list controller

- no anchor => no request;
- all-status anchor may be inactive;
- initial load;
- search/status/sort/pagination;
- refresh;
- global/filter/empty-page/error;
- page correction;
- By Parent/By Student isolation;
- anchor switch stale completion rejection;
- session/institution/device/route dispose rejection;
- 404 anchor clears/unavailable behavior.

### User selection controller

Anchor selectors:

- fixed Parent/Student role;
- status omitted;
- search/page;
- inactive candidates remain selectable;
- no main Users retained-state mutation.

Connect selectors:

- fixed role;
- fixed active status;
- search/page;
- single select;
- selected summary survives candidate paging/search;
- dialog close clears state;
- stale session/dialog completion rejection.

### Connect remote/repository

- exact POST path;
- exact two-key body;
- no query;
- `201` accepted;
- `200` accepted;
- exact message;
- strict five-key relationship resource;
- returned pair must equal submitted pair;
- ended_at null;
- exact definite 401/403/404/409/422/429 mapping;
- timeout/connection/5xx/malformed status/body/message/pair -> unknown;
- no automatic replay.

### Connect action controller

- submit requires active typed Parent + Student selection;
- duplicate submit suppression;
- direct 200/201 success closes dialog;
- success switches to By Parent/submitted Parent and reloads;
- active By Student opposite perspective invalidation when relevant;
- 404 safe generic target feedback;
- 409 current-user-state feedback;
- uncertain outcome switches/reloads without claiming success;
- no replay;
- session/institution/route/newer-operation stale completion rejection.

### Disconnect remote/repository

- exact relationship-ID DELETE path;
- no body/query;
- exact 204/no content;
- exact definite failure mapping;
- unexpected/transport/5xx -> unknown;
- no replay.

### Disconnect action controller

- opens from exact current relationship row;
- inactive parties still allowed;
- direct 204 reloads current list;
- opposite active perspective invalidation when relevant;
- 404 reload + safe unavailable feedback;
- unknown reload + unconfirmed feedback;
- stale row/anchor/perspective/session/route completion rejection;
- page correction after removal.

### Widget

- heading;
- By Parent / By Student controls;
- anchor no-selection states;
- anchor selector active/inactive presentation;
- list toolbar/table/pagination;
- inactive related user;
- Connect dialog Parent/Student selectors;
- Connect busy/error/success/unknown behavior;
- Disconnect confirmation/history-preservation copy;
- no family relationship-type fields;
- no bulk controls;
- no User-detail row navigation;
- keyboard/focus/semantics/text-scale/narrow-desktop overflow.

---

## Focused test command

Run only S04-FE-005 tests and existing Users/router/shell tests directly modified.

Expected command shape:

```powershell
fvm spawn 3.44.7 test `
  test/features/institution_admin/institution_parent_student_relationship_domain_test.dart `
  test/features/institution_admin/institution_parent_student_relationship_dto_test.dart `
  test/features/institution_admin/institution_parent_student_relationship_remote_data_source_test.dart `
  test/features/institution_admin/institution_parent_student_relationship_repository_impl_test.dart `
  test/features/institution_admin/institution_parent_student_relationship_list_controller_test.dart `
  test/features/institution_admin/institution_user_selection_controller_test.dart `
  test/features/institution_admin/institution_parent_student_relationship_action_controller_test.dart `
  test/features/institution_admin/institution_admin_parent_student_connections_screen_test.dart
```

If actual names differ because the current implementation establishes equivalent files, use those real paths and report the exact command.

## Directly affected regression

Required:

```powershell
fvm spawn 3.44.7 test test/app/router/institution_admin_route_paths_test.dart test/features/institution_admin/institution_admin_shell_test.dart test/features/institution_admin/institution_admin_users_screen_test.dart
```

Also run exact existing Institution User list/query/repository tests only if their production files were changed. Reuse through an unchanged repository contract does not justify broad Users regression.

No Group test suite is required unless Group production code was unexpectedly changed, which this contract does not authorize.

## Static analysis

```powershell
fvm spawn 3.44.7 analyze
```

## Format check

```powershell
C:\Users\Administrator\fvm\versions\3.44.7\bin\cache\dart-sdk\bin\dart.exe format --output=none --set-exit-if-changed lib test
```

## Build

```text
Not required for this task.
```

## Always

```text
git diff --check
```

Then inspect the complete diff for:

- exact S04-FE-005 scope;
- no Group changes;
- no backend/schema/package changes;
- no global N+1 relationship aggregation;
- no family semantics;
- no history/bulk UI;
- no optimistic relationship state;
- no mutation auto-replay;
- exact 404 existence privacy;
- exact active/inactive connect vs current-list boundary;
- no corruption of main Users retained state;
- safe perspective/anchor/session/mutation async ownership;
- no raw errors/JSON/tokens/secrets/debug/temp artifacts.

Do not run the full frontend suite, Windows build, broad E2E, or Frontend Phase 2 in this task. Those belong to the frontend block checkpoint unless a concrete unexpected shared-infrastructure regression risk invalidates this verification scope; report that mismatch instead of silently broadening verification.

---

# 35. Delivery

Future Build Runner/Codex execution:

```text
branch: task/s04-fe-005-parent-student-connections
commit: feat(frontend): manage parent student connections
PR: focused PR to main
```

After merge verify:

```text
local main == origin/main
ahead/behind = 0/0
working tree = clean
```

Do not modify Stage/task bookkeeping during implementation unless the active orchestration step explicitly assigns it.

If implementation/verification passes but safe GitHub delivery cannot complete:

```text
DELIVERY BLOCKED
```

---

# 36. Codex Completion Report

Return concise evidence:

1. `ACCEPTED`, `BLOCKED`, or `DELIVERY BLOCKED`.
2. Implementation summary.
3. Changed files and purpose.
4. Acceptance-criteria evidence.
5. Exact focused verification commands/results.
6. By Parent / By Student list-contract evidence.
7. Inactive current-user visibility/disconnect evidence.
8. Connect 201/200/idempotent/409/404/unknown-outcome evidence.
9. Disconnect 204/history-preserving/404/unknown-outcome evidence.
10. Tenant/existence-privacy/session evidence.
11. Perspective/anchor/dialog/mutation stale-async evidence.
12. Main Users retained-state isolation evidence.
13. `git diff --check` + focused scope/diff self-review.
14. Commit/PR/merge/main-sync evidence.
15. Exact deviations/blockers.

If any product, architecture, API, security, tenant, relationship lifecycle, concurrency, mutation-outcome, async-ownership, or UX decision required by this task is missing or conflicts with current implementation, return `BLOCKED` instead of inventing behavior.
