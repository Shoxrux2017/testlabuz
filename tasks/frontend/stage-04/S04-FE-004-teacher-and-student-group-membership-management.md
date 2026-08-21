# S04-FE-004 — Teacher and Student Group Membership Management

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S04-FE-004` |
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | `Frontend` |
| Status | `Draft` |
| Review | `Pending` |
| Depends on | `S04-FE-003 Accepted / Delivered` |
| Delivery | `Implementation + GitHub delivery` |

This file is the complete task-specific implementation contract for Codex.

> **Execution gate:** This file is intentionally stored before final review. Codex must not implement this task while `Status = Draft`. ChatGPT/reviewer must complete read-only review, resolve findings, change the task to `Approved`, and deliver that planning update to `main` first.

Codex must use only this contract, applicable `AGENTS.md` files, and directly relevant source/tests. Do not read product docs, roadmap, previous tasks, Stage history, or closure reviews to determine behavior.

---

## 2. Goal

Extend the existing Institution Admin Group Detail screen with complete current Teacher and Student membership management for the selected Group.

The UI must support:

- reading current Teachers;
- reading current Students;
- searching/filtering/sorting/paginating each membership list;
- assigning one or more active Teachers;
- assigning one or more active Students;
- removing a current Teacher membership;
- removing a current Student membership;
- read-only membership visibility for archived Groups;
- authoritative refresh/reconciliation after every mutation.

Backend-authoritative relationship history, tenant scope, archived lifecycle, inactive-user eligibility, and concurrency must remain server-owned.

---

## 3. Scope

### Included

Consume exactly:

```text
GET    /api/v1/institution/groups/{group}/teachers
POST   /api/v1/institution/groups/{group}/teachers
DELETE /api/v1/institution/groups/{group}/teachers/{teacher}

GET    /api/v1/institution/groups/{group}/students
POST   /api/v1/institution/groups/{group}/students
DELETE /api/v1/institution/groups/{group}/students/{student}
```

Also reuse the existing Institution User list API only for active candidate discovery:

```text
GET /api/v1/institution/users
```

with fixed role/status scope owned by this frontend feature.

Implement:

- current Teacher membership section on Group Detail;
- current Student membership section on Group Detail;
- typed member/list/query models;
- shared Teacher/Student membership read architecture where responsibilities are truly identical;
- assignment picker dialogs;
- multi-select up to 100 users per assignment request;
- remove confirmation dialogs;
- strict response parsing;
- current-list/detail invalidation and reconciliation;
- stale async/session/target/action ownership;
- deterministic focused tests.

### Non-goals

Do **not** implement:

- Group create/edit/archive changes beyond integration required here;
- Parent–Student relationships;
- Teacher or Student account creation/edit/lifecycle;
- historical membership list UI;
- membership start/end date editing;
- membership hard deletion;
- Group reactivation;
- direct Teacher/Student detail navigation from membership rows;
- optimistic list/count patching;
- auto-replay of assignment/removal mutations;
- server-side assignment candidate endpoint;
- backend/schema/API changes;
- dependency/package changes;
- new routes.

---

# 4. Current Implementation Context

S04-FE-001…003 already provide:

- Institution Admin Groups shell/route/list;
- strict Group model/DTO;
- Group Detail route/controller/state/screen;
- Group create;
- Group edit/archive lifecycle;
- Group list retained query state;
- Group action/session/target stale-completion safety;
- `business_conflict` machine-code support.

Reuse existing Stage 3 Institution User list infrastructure for assignment candidate reads:

- `InstitutionUser`;
- `InstitutionUserListQuery`;
- `InstitutionUserListRepository`;
- configured Dio/failure mapping.

Do **not** reuse the global Institution User list controller/retained store for assignment dialogs. Candidate search is a separate route-local/application concern and must not alter the Users management page query state.

Use a focused shared membership abstraction because Teacher and Student membership endpoints have the same public shape and behavior except:

```text
kind/role
endpoint segment
assign body key
messages/labels
```

A reasonable owning domain enum/value is:

```text
teacher
student
```

Do not create two near-identical stacks if one typed Group-membership stack cleanly owns both.

---

# 5. Exact Implementation Contract

## 5.1 Group Detail integration

No new route.

Extend:

```text
/institution-admin/groups/{groupId}
```

After the existing Group metadata/details, render two distinct sections:

```text
Teachers
Students
```

Both current membership lists are readable for:

```text
active Group
archived Group
```

When the Group is active:

```text
Teachers -> show Assign Teachers + per-row Remove
Students -> show Assign Students + per-row Remove
```

When the Group is archived:

- lists remain readable;
- no Assign action;
- no Remove action;
- show section-level read-only text:

```text
Membership changes are unavailable because this group is archived.
```

Do not call membership endpoints before Group Detail has a valid confirmed Group target. If Group Detail becomes not-found/session-ineligible, membership controllers/actions must lose publication authority.

---

## 5.2 Member kind contract

Use one explicit kind abstraction:

```text
teacher
student
```

Mapping:

| Kind | Current-list endpoint | Assign endpoint | Remove endpoint target | Candidate Institution User role |
|---|---|---|---|---|
| Teacher | `/institution/groups/{group}/teachers` | same | `{teacher}` | `teacher` |
| Student | `/institution/groups/{group}/students` | same | `{student}` | `student` |

Request body keys:

```text
Teacher -> teacher_ids
Student -> student_ids
```

Do not derive API machine values from localized/display labels.

---

## 5.3 Exact current-member resource

Teacher and Student list/assign responses use the same exact resource keys:

```text
id
full_name
login_name
email
phone
is_active
started_at
```

Strict DTO rules:

`id`

```text
canonical hyphenated UUID string
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

`started_at`

```text
required valid UTC timestamp ending in Z
```

No resource may contain missing/unknown keys.

Do not expect or expose:

```text
membership_id
institution_id
role
assigned_by_user_id
ended_at
password data
```

Reject duplicate member IDs inside one returned page or one assignment success collection.

---

## 5.4 Current membership list API

Teacher:

```text
GET /institution/groups/{groupId}/teachers
```

Student:

```text
GET /institution/groups/{groupId}/students
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

Allowed sorts:

```text
full_name
started_at
```

Direction:

```text
asc
desc
```

Maximum server page size:

```text
100
```

UI page-size options:

```text
20
50
100
```

Both active and inactive current members are included when status is omitted.

Archived Group list reads remain valid and must not be suppressed.

---

## 5.5 Membership list search/filter/sort behavior

Implement independent query state for Teacher and Student lists.

### Search

- labels:
  - `Search teachers`
  - `Search students`
- maximum 254 characters;
- trim leading/trailing whitespace;
- blank after trim means omit `search`;
- preserve case/special characters otherwise;
- `%`, `_`, `!` remain literal user text;
- 300 ms debounce for valid draft;
- keyboard search-submit commits immediately;
- over-length search sends no request;
- changing committed search resets page to 1.

### Status filter

Options:

```text
All statuses
Active
Inactive
```

Changing status resets page to 1.

### Sorting

Sortable columns:

```text
Full name
Assigned
```

Mapping:

```text
Full name -> full_name
Assigned  -> started_at
```

Rules:

- default Full name ascending;
- new sort field begins ascending;
- current sort field toggles asc/desc;
- sort change resets page to 1.

### Pagination

- Previous/Next;
- 20/50/100 page size;
- page-size change resets page to 1;
- suppress duplicate same-query logical requests;
- replacement-query loading does not present old rows as current;
- explicit Refresh retains current confirmed rows with progress;
- after removal causes current page to become empty/out-of-range, perform at most one correction to page 1 or valid `last_page`.

Teacher and Student list query states are independent.

---

## 5.6 Exact list envelope

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

Apply the same strict pagination invariants already used by S04-FE-001:

- JSON integers;
- page >= 1 and equals requested page;
- per_page equals requested page size;
- total >= 0;
- mathematically correct last_page, with 1 for total 0;
- row count <= per_page;
- zero total => zero rows;
- out-of-range page => zero rows.

Malformed success => existing `invalidResponse` failure category.

---

# 6. Current Membership Section UI

Each section contains:

```text
section heading
optional Assign action
search
status filter
clear filters
refresh
current-member table
pagination
```

### Teacher table columns

```text
Full name
Login name
Contact
Status
Assigned
Action
```

### Student table columns

Same:

```text
Full name
Login name
Contact
Status
Assigned
Action
```

Display:

- email/phone both absent -> `Not provided`;
- `Active` / `Inactive` visible as text and not color-only;
- `started_at` using existing Institution Admin UTC presentation convention;
- inactive current members remain visible and removable while Group is active;
- `Remove` action is available regardless of current member account active/inactive state when Group is active.

Rows are not navigable to User Detail in this task.

### Empty states

Global:

```text
No teachers assigned
No students assigned
```

For active Group, global empty may include the respective Assign action.

Filtered:

```text
No matching teachers
No matching students
```

with `Clear filters`.

Archived Group empty states must not offer assignment.

### Error

```text
Unable to load teachers
Unable to load students
```

with Retry when allowed.

---

# 7. Assignment Candidate Discovery

## 7.1 Existing API reuse

Do not add a backend candidate endpoint.

Use existing:

```text
GET /institution/users
```

through the existing typed Institution User list repository.

For Teacher candidate picker, force:

```text
role = teacher
status = active
sort = full_name
direction = asc
```

For Student picker:

```text
role = student
status = active
sort = full_name
direction = asc
```

Candidate query controls may change only:

```text
search
page
```

Use:

```text
per_page = 20
```

for candidate discovery.

Candidate search:

- max 254;
- same 300 ms debounce;
- blank => no search;
- page resets to 1 on search change.

Do not persist candidate query after dialog closes.

Do not reuse or mutate the main Institution Users page retained query/controller.

---

## 7.2 Candidate eligibility presentation

Candidate picker shows only backend-reported active Users of the exact required role.

Display:

```text
Full name
Login name
Email/phone
```

The User may already be a current Group member. The current Institution User API has no authoritative `not_assigned_to_group` filter, and the current member list is paginated.

Therefore:

- do not invent incomplete client-side candidate exclusion;
- do not treat a currently loaded membership page as the complete assignment set;
- already-assigned active Users may appear in candidate results;
- selecting an already-assigned User is valid because backend assignment is additive/idempotent and does not duplicate active membership.

Show concise explanatory text:

```text
Only active users are shown. Users already assigned to this group can be selected safely; duplicate active memberships are not created.
```

Do not expose this as a security claim; backend remains authoritative.

---

## 7.3 Candidate selection

Use a controlled ordered selection of UUIDs.

Rules:

```text
minimum to submit = 1
maximum per request = 100
```

- IDs come only from parsed Institution User resources;
- no duplicate IDs;
- selection survives candidate search/page changes while the dialog remains open;
- show selected count:

```text
Selected: N / 100
```

- when 100 are selected, additional unchecked candidates cannot be selected until another is deselected;
- Submit disabled when selection is empty or a request is active.

Do not allow manual UUID entry.

---

# 8. Assign Dialog UX

Teacher:

```text
title: Assign Teachers
submit: Assign Teachers
```

Student:

```text
title: Assign Students
submit: Assign Students
```

Dialog includes:

- candidate search;
- candidate loading/data/empty/error states;
- checkbox selection;
- selected count;
- Cancel;
- Submit.

While mutation is active/reconciling:

- prevent duplicate submit;
- disable candidate query/selection controls;
- disable Cancel;
- prevent Escape/back/dialog dismissal;
- expose semantic progress.

Progress:

```text
Assigning teachers
Assigning students
Checking current server state
```

Cancel before submit discards dialog-local search/selection state.

---

# 9. Exact assignment request

Teacher:

```text
POST /institution/groups/{groupId}/teachers
```

Body:

```json
{
  "teacher_ids": [
    "uuid-1",
    "uuid-2"
  ]
}
```

Student:

```text
POST /institution/groups/{groupId}/students
```

Body:

```json
{
  "student_ids": [
    "uuid-1",
    "uuid-2"
  ]
}
```

No query parameters.

Rules:

- list length 1..100;
- canonical UUID strings;
- distinct case-insensitively;
- preserve selected order in the request;
- no tenant ID, role, status, membership ID, timestamps, or other fields.

The backend operation is atomic: the frontend must not present partial assignment success.

---

# 10. Assignment success contract

Teacher message:

```text
Teachers assigned to group successfully.
```

Student message:

```text
Students assigned to group successfully.
```

Success HTTP status is:

```text
201 Created -> at least one active membership was newly created
200 OK      -> every requested membership was already current/idempotent
```

Both are confirmed success.

Exact top-level envelope:

```json
{
  "data": [
    {
      "...": "exact current-member resource"
    }
  ],
  "message": "..."
}
```

No pagination meta.

Strictly require:

- exact expected message for member kind;
- data is an array;
- data length equals submitted ID count;
- no duplicate returned IDs;
- returned IDs match submitted IDs in submitted order, case-insensitively;
- each item passes strict current-member DTO parsing.

Do not require returned `is_active == true`: an already-current member may have become inactive before an idempotent assignment request is processed, and backend may return the existing current membership.

Do not patch membership list from this response.

### Confirmed assignment UI

On confirmed 200/201:

1. close assignment dialog;
2. clear dialog selection/query state;
3. mark/reload the relevant current membership list using its existing query;
4. trigger authoritative Group Detail refresh so `teachers_count` / `students_count` update;
5. mark S04-FE-001 Group list stale while preserving its retained query/filter/page state because Group resource counts may have changed;
6. show live-region feedback:

Teacher:

```text
Teachers assigned to group successfully.
```

Student:

```text
Students assigned to group successfully.
```

Do not optimistically change counts or list rows.

---

# 11. Assignment definite failures

A failed mutation is definite only with an exact expected API error envelope.

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

### 422

Local UI should make a normal 422 unlikely. Treat exact 422 as contract/input rejection.

Known selection field:

```text
teacher_ids
student_ids
```

Safe feedback:

```text
The assignment request did not match the server contract.
```

Do not display raw backend validation messages.

Keep dialog open for 422/forbidden/rate-limit definite failures unless session authority is lost.

### 409 business_conflict

Possible authoritative causes include:

- Group became archived;
- a selected non-current User became inactive before assignment.

Do not parse the human-readable backend message to decide which.

On exact 409:

1. close the stale assignment dialog;
2. clear its selection;
3. refresh Group Detail;
4. refresh the relevant membership list;
5. mark Group list stale;
6. show:

```text
Assignment was not accepted because current server state changed. Review the group and active users before trying again.
```

If authoritative Group Detail returns archived, the page naturally becomes membership read-only.

### 404 resource_not_found

Could represent inaccessible/missing Group or one invalid/wrong-role/cross-tenant selected target.

Do not assume which.

On exact 404:

1. close stale picker;
2. perform authoritative Group Detail reconciliation;
3. refresh/mark membership list stale.

If Group Detail is 404:

- move Group Detail into the existing S04-FE-002 not-found state.

If Group still exists:

```text
One or more selected users are no longer available for this assignment.
```

Do not disclose target existence beyond current authorized reads.

### Session failures

Use existing auth/session reconciliation. Stale dialogs/controllers must lose publication authority.

---

# 12. Assignment uncertain outcome

Do not automatically replay POST.

Treat as uncertain when commit success cannot be proven, including:

- connection interruption after dispatch;
- timeout;
- 5xx;
- malformed/unexpected error envelope;
- unexpected status;
- malformed 200/201 success body;
- wrong success message;
- returned ID/resource mismatch;
- unexpected post-dispatch exception.

On uncertain result:

1. close picker and clear its local selection/query state;
2. mark relevant membership list stale and trigger authoritative reload;
3. trigger Group Detail refresh;
4. mark Group list stale;
5. do not attempt to infer success from Group count alone;
6. do not scan all membership pages solely to manufacture confirmed success;
7. do not replay the POST;
8. show:

Teacher:

```text
Teacher assignment result could not be confirmed. Current memberships were refreshed; review them before assigning again.
```

Student:

```text
Student assignment result could not be confirmed. Current memberships were refreshed; review them before assigning again.
```

The refreshed membership list is authoritative current state, but the originating mutation outcome remains unconfirmed.

A new assignment attempt requires reopening the picker and making a new explicit selection.

---

# 13. Remove Membership UX

For an active Group, every current Teacher/Student row has:

```text
Remove
```

Opening Remove requires the exact confirmed current member object from the relevant membership list.

Confirmation title:

Teacher:

```text
Remove teacher from group?
```

Student:

```text
Remove student from group?
```

Show full name + login name.

Explanation:

```text
This ends the current group membership and revokes future group-based access. Historical relationship records and existing learning history are preserved. The user account itself is not deactivated.
```

Actions:

```text
Cancel
Remove
```

While removing/reconciling:

- disable Cancel/Remove;
- prevent dismissal/back;
- announce progress.

Progress:

```text
Removing teacher
Removing student
Checking current server state
```

Inactive current members are removable.

---

# 14. Exact remove request

Teacher:

```text
DELETE /institution/groups/{groupId}/teachers/{teacherId}
```

Student:

```text
DELETE /institution/groups/{groupId}/students/{studentId}
```

Send:

```text
no request body
no query parameters
```

Success:

```text
204 No Content
```

Require no meaningful response body.

Backend semantics:

- current membership -> sets authoritative `ended_at`;
- no current membership -> idempotent 204;
- historical row is preserved;
- User account is unchanged;
- inactive current member may still be removed.

Frontend must not create or display `ended_at` because current-member API excludes historical memberships after removal.

---

# 15. Confirmed remove behavior

On confirmed 204:

1. close confirmation dialog;
2. refresh the relevant current membership list using its existing query;
3. refresh Group Detail counts;
4. mark Group list stale while preserving retained query/filter/page state;
5. show:

Teacher:

```text
Teacher removed from group.
```

Student:

```text
Student removed from group.
```

Do not optimistically delete the row or decrement counts.

If removal makes the current membership page empty/out-of-range, membership list controller applies its one-time page correction after authoritative reload.

---

# 16. Remove definite failures

Recognize only exact envelopes for:

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

### 409 business_conflict

For removal, the meaningful current backend lifecycle cause is archived Group, but do not branch from human message.

Close stale dialog, refresh Group Detail + membership list, mark Group list stale, and show:

```text
Membership removal was not accepted because current server state changed.
```

If Group Detail is now archived, membership controls disappear.

### 404 resource_not_found

Could represent Group or member target resolution.

Reconcile Group Detail.

If Group not found:

- use existing Group not-found state.

If Group remains current:

- reload current membership list;
- show:

```text
The selected membership target is no longer available.
```

### 422

Safe feedback:

```text
The removal request did not match the server contract.
```

### forbidden/rate limit

```text
You do not have permission to change group memberships.
Too many requests. Wait before trying again.
```

Session failures use existing auth reconciliation.

---

# 17. Remove uncertain outcome

Do not automatically replay DELETE, even though backend repeat removal is idempotent.

For timeout/connection/5xx/malformed/unexpected result:

1. close the stale confirmation dialog after reconciliation begins/settles safely;
2. refresh relevant current membership list;
3. refresh Group Detail;
4. mark Group list stale;
5. do not claim confirmed success/failure;
6. do not replay DELETE.

Feedback:

Teacher:

```text
Teacher removal result could not be confirmed. Current memberships were refreshed.
```

Student:

```text
Student removal result could not be confirmed. Current memberships were refreshed.
```

The refreshed list shows authoritative current membership state.

---

# 18. Archived Group behavior and races

Membership GET endpoints are valid for archived Groups.

Therefore an archived Group must still show current Teacher/Student membership history-as-current relationships.

But all mutation controls are absent/disabled.

If Group is archived concurrently after controls were displayed:

- backend assignment/remove may return `409 business_conflict`;
- frontend reconciles Group Detail;
- stale picker/remove dialog closes;
- no mutation auto-replay;
- membership sections become read-only.

If S04-FE-003 archives the Group while membership controllers are active:

- existing member reads may remain/refetch;
- all current membership mutation ownership must invalidate immediately when the confirmed Group object changes to archived.

---

# 19. Membership list application state / stale ownership

Use a family-style controller keyed by:

```text
groupId + memberKind
```

Each list owns:

```text
query
search draft
current result
loading/query-loading/refresh/error/empty/data state
operation generation
eligible session key
target group UUID
member kind
```

Requirements:

- canonical Group UUID required;
- only run while current Group Detail owns a valid confirmed target;
- session = active desktop Institution Admin in active Institution;
- suppress duplicate same-query requests;
- stale superseded query completion cannot publish;
- disposed/old-session/old-institution/old-target completion cannot publish;
- one member kind cannot overwrite the other's state;
- current query survives list refresh/mutations while Group Detail stays mounted;
- no cross-Group retained cache is required after route exit.

If membership GET returns `404 resource_not_found` while Group Detail is still present:

- do not leak tenant/existence information;
- trigger/require authoritative Group Detail reconciliation;
- membership section enters safe unavailable/error state until target status resolves.

Session-authority failures follow existing auth bootstrap/reconciliation.

---

# 20. Candidate picker application state / stale ownership

Use a separate dialog-local/family application controller keyed by:

```text
groupId + memberKind
```

Candidate controller uses existing Institution User repository with fixed:

```text
role = kind
status = active
sort = full_name
direction = asc
per_page = 20
```

It owns:

```text
search draft
page
current candidate result
ordered selected IDs
operation generation
session/target/kind ownership
```

Candidate stale completion must not:

- update a closed picker;
- change selection in a newer picker;
- publish into another Group;
- publish after session/institution/device change;
- publish after Group becomes archived.

Closing picker destroys/clears candidate query and selection.

Do not create another global cache.

---

# 21. Membership mutation ownership

A membership mutation operation must bind to:

```text
eligible session key
authenticated user instance
institution ID
route Group UUID
exact confirmed Group object identity
member kind
operation kind: assign/remove
operation generation
immutable submitted ordered IDs or selected member identity
focus-restoration ownership
```

A completion/reconciliation publishes only while all relevant ownership remains current.

Stale completions must not:

- mutate a newer Group Detail;
- refresh the wrong membership kind;
- close a newer dialog;
- show feedback in another session;
- restore focus to removed/ineligible controls;
- navigate.

Actual Dio cancellation is not required.

---

# 22. Group Detail/count reconciliation

`teachers_count` and `students_count` belong to authoritative Group resource responses.

After any membership mutation that:

- confirms success;
- has uncertain outcome;
- returns 404;
- returns `409 business_conflict`;

trigger an authoritative Group Detail refresh/reconciliation.

Do not manually increment/decrement counts.

If refreshed Group is archived, membership mutation actions disappear.

If refreshed Group is not found, discard membership mutation/action ownership and use Group Detail not-found state.

---

# 23. Group-list stale handling

Membership changes may alter Group resource counts shown in S04-FE-001.

Therefore after mutation/current-state uncertainty:

- mark Group-list data stale;
- preserve retained:
  - search draft;
  - committed search;
  - status filter;
  - sort;
  - direction;
  - page;
  - per_page;
- reload before treating Group-list counts as current.

Do not optimistically patch list counts or ordering.

Pure membership-list read/filter changes do not invalidate Group list.

---

# 24. Candidate/user lifecycle race

Candidate picker intentionally requests only active Users.

A candidate may become inactive after it was loaded.

Backend then atomically rejects assigning a new inactive member using:

```text
409 business_conflict
```

Frontend must not try to pre-authorize from stale candidate state.

On 409:

- no partial success;
- close stale selection;
- refresh current membership/detail state;
- next picker load uses fresh active User state.

A currently assigned User may later become inactive:

- current membership list still displays them;
- membership remains current until removed;
- inactive current member may be removed;
- do not hide inactive current memberships.

---

# 25. Authorization / tenant boundary

Frontend eligible actor:

```text
authenticated
role = institution_admin
active user
must_change_password = false
active own institution
desktop surface
```

Do not send:

```text
institution_id
assigned_by_user_id
role override
status override
started_at
ended_at
membership_id
tenant selector
```

Group/member UUIDs identify requested targets but never expand scope.

Backend remains authoritative for:

- Group tenant scope;
- Teacher/Student role;
- User tenant scope;
- account active eligibility for new assignment;
- archived lifecycle;
- atomicity;
- concurrency;
- relationship history;
- membership timestamps.

Wrong-role, foreign, and missing target resolution remains privacy-safe.

---

# 26. Accessibility / keyboard / focus / responsiveness

Membership sections:

- headings have semantic structure;
- filters/search keyboard reachable;
- sort semantics expose direction;
- loading/refresh states announced;
- status is not color-only;
- tables horizontally scroll instead of overflowing;
- text scaling and supported desktop window resizing do not produce overflow.

Assignment dialog:

- search, candidate checkboxes, Cancel, Submit have predictable traversal;
- selected count announced/readable;
- progress is live-region semantic;
- duplicate submit impossible;
- dialog cannot dismiss during mutation/reconciliation;
- after close, focus returns to Assign action only if Group remains active/current.

Remove dialog:

- focus starts in confirmation content/action order;
- Cancel/Remove keyboard accessible;
- busy state prevents dismissal;
- after confirmed/definite non-lifecycle failure, restore focus to current membership section/row if still present;
- if member disappeared or Group archived, restore focus to section heading/read-only surface instead of obsolete Remove button.

Do not introduce a new design system.

---

# 27. Architecture and Placement

A focused shared implementation is expected, for example:

```text
frontend/lib/features/institution_admin/domain/
  institution_group_membership.dart
  institution_group_membership_list.dart
  institution_group_membership_query.dart
  institution_group_membership_repository.dart
  institution_group_membership_mutation.dart

frontend/lib/features/institution_admin/data/
  dto/institution_group_membership_dto.dart
  dto/institution_group_membership_list_dto.dart
  dto/institution_group_membership_mutation_dto.dart
  institution_group_membership_remote_data_source.dart
  institution_group_membership_repository_impl.dart

frontend/lib/features/institution_admin/application/
  institution_group_membership_list_controller.dart
  institution_group_membership_list_state.dart
  institution_group_membership_candidate_controller.dart
  institution_group_membership_candidate_state.dart
  institution_group_membership_action_controller.dart
  institution_group_membership_action_state.dart
```

Expected presentation additions/modifications:

```text
frontend/lib/features/institution_admin/presentation/
  institution_admin_group_detail_screen.dart
  optional focused institution_group_membership_section.dart
  optional focused institution_group_membership_dialogs.dart
```

Reuse:

```text
InstitutionUserListRepository
InstitutionUserListQuery
InstitutionUser
Group Detail controller/state
Group list retained state
configured Dio/failure mapper
ApiErrorCodes
```

If prior S04-FE tasks established equivalent filenames/boundaries, extend them rather than duplicating ownership.

Do not:

- call Dio in Widgets;
- parse raw JSON in presentation/controllers;
- create a second Institution User repository/client;
- create a second Group Detail cache;
- create new routes;
- modify backend/docs/packages/platform files;
- build speculative generic relationship infrastructure for S04-FE-005.

S04-FE-005 Parent–Student relationships have a different API resource/lifecycle and must not be forced into this abstraction.

---

# 28. Acceptance Criteria

- [ ] Group Detail shows separate current Teachers and Students sections.
- [ ] Membership GET lists support exact search/status/sort/pagination behavior.
- [ ] Strict current-member DTO and pagination parsing is implemented.
- [ ] Active and inactive current members are visible; status is explicit.
- [ ] Archived Groups keep membership lists readable but have no mutation controls.
- [ ] Active Groups expose Assign Teachers / Assign Students and per-row Remove.
- [ ] Candidate picker reuses existing Institution User repository with fixed role + active status.
- [ ] Candidate picker does not corrupt/replace main Users page retained state.
- [ ] Candidate selection is ordered, distinct, 1..100, and survives search/page changes within the dialog.
- [ ] Already-current active users may safely be submitted; frontend does not invent incomplete candidate exclusion.
- [ ] Assignment request sends only exact `teacher_ids` / `student_ids`.
- [ ] Assignment accepts both 201 newly-created/mixed and 200 fully-idempotent success.
- [ ] Assignment success response is strict and matches submitted IDs.
- [ ] No optimistic membership/count changes occur.
- [ ] Confirmed assignment refreshes membership list + Group Detail + Group-list counts authoritatively.
- [ ] 409 assignment race/state conflict closes stale picker and refreshes current state without message parsing or retry.
- [ ] 404 assignment safely distinguishes only through authorized Group Detail reconciliation, not target existence inference.
- [ ] Unknown assignment never auto-replays and refreshes current authoritative state with unconfirmed feedback.
- [ ] Removal requires confirmation and sends exact bodyless/queryless DELETE.
- [ ] Removal accepts 204 and is represented as history-preserving current-membership end.
- [ ] Inactive current member can be removed.
- [ ] Repeated/already-ended removal remains safely handled as 204.
- [ ] 409/404/unknown removal reconciles current state without auto-replay.
- [ ] Membership mutation ownership rejects stale session/target/kind/Group-object completions.
- [ ] Mutation-induced Group-list stale marking preserves Group list query/filter/page state.
- [ ] Group counts are refreshed from Group Detail, never computed locally.
- [ ] Keyboard/accessibility/focus/overflow requirements are covered.
- [ ] No Parent–Student functionality is introduced.
- [ ] No backend/schema/dependency/public API change.
- [ ] Focused verification passes.
- [ ] `git diff --check` passes.
- [ ] Diff contains no unrelated work.

---

# 29. Focused Tests and Verification

## Required focused coverage

### Member kind/domain/query

- exact teacher/student endpoint/body-key mapping;
- default member query;
- search trim/blank/max;
- active/inactive status;
- sort toggle;
- page/page-size reset;
- separate Teacher/Student query identity.

### Member DTO/list DTO

- valid active member;
- valid inactive member;
- nullable contact;
- exact keys;
- canonical UUID;
- required UTC started_at;
- invalid bool/timestamp/unknown keys;
- duplicate IDs;
- exact pagination and contradictory pagination.

### Membership remote/repository reads

- exact Teacher GET path/query;
- exact Student GET path/query;
- no body;
- strict malformed-response mapping;
- 404/session/failure mapping.

### Membership list controller

- initial load only for valid Group detail/session;
- Teacher/Student state isolation;
- search debounce/filter/sort/pagination;
- refresh retaining confirmed data;
- global/filtered/empty-page/error;
- page correction;
- stale superseded/dispose/session/institution/group-target completion rejection;
- archived Group read works;
- invalid Group target/no valid detail does not publish.

### Candidate controller

- fixed role/status active;
- exact Institution User repository query;
- search/pagination;
- no interaction with Users page retained state;
- ordered cross-page selection;
- max 100;
- duplicate prevention;
- close clears selection/query;
- stale session/group/archive completion rejection.

### Assignment remote/repository

Teacher and Student:

- exact POST path;
- exact body key;
- 1..100 distinct UUIDs;
- no query;
- 201/200 accepted;
- exact message;
- exact returned member resources;
- length/order/ID match;
- 401/403/404/409/422/429 definite mapping;
- timeout/connection/5xx/malformed status/body/message/mismatch -> unknown;
- no auto-replay.

### Assignment action controller

- active Group only;
- archived Group cannot begin;
- duplicate submit suppressed;
- direct success closes picker and invalidates correct list/detail/Group list;
- 409 closes picker + refreshes/reconciles;
- 404 Group gone vs Group current branch through detail GET only;
- uncertain outcome refreshes without claiming success;
- no scanning/paging to manufacture mutation success;
- no replay;
- stale session/target/kind/group-object/dialog ownership rejected.

### Remove remote/repository

Teacher and Student:

- exact DELETE path;
- no body/query;
- exact 204/no content;
- exact definite failures;
- uncertain transport/status handling;
- no replay.

### Remove action controller

- confirmation only for exact current member and active Group;
- inactive current member allowed;
- direct 204 refreshes list/detail/Group list;
- 409 archived race;
- 404 reconciliation;
- unknown outcome refresh/unconfirmed feedback;
- repeated stale/remove target disappearance;
- stale completion/focus ownership.

### Widget tests

Group Detail:

- Teacher + Student sections;
- active Group actions;
- archived read-only sections;
- tables/columns/status/search/filter/sort/pagination;
- empty/filter/error/refresh states;
- Assign picker loading/search/select/pagination/max/busy/error;
- already-current explanatory text;
- remove confirmation/history-preservation copy;
- feedback for success/conflict/unknown;
- controls disappear after archive reconciliation;
- keyboard focus/semantics/text-scale/narrow-desktop overflow.

---

## Focused test command

Run only S04-FE-004 tests and directly modified S04-FE-001…003 Group tests.

Expected command shape:

```powershell
fvm spawn 3.44.7 test `
  test/features/institution_admin/institution_group_membership_domain_test.dart `
  test/features/institution_admin/institution_group_membership_dto_test.dart `
  test/features/institution_admin/institution_group_membership_remote_data_source_test.dart `
  test/features/institution_admin/institution_group_membership_repository_impl_test.dart `
  test/features/institution_admin/institution_group_membership_list_controller_test.dart `
  test/features/institution_admin/institution_group_membership_candidate_controller_test.dart `
  test/features/institution_admin/institution_group_membership_action_controller_test.dart `
  test/features/institution_admin/institution_admin_group_detail_screen_test.dart
```

Also run any existing Group Detail/Group list retained-state test file directly modified by this task.

If earlier tasks used equivalent real filenames, use those established files and report the exact command.

## Directly affected regression

Required:

```text
S04-FE-003 Group Detail/action lifecycle tests affected by membership integration
S04-FE-001 Group-list retained-state tests affected by count invalidation
```

Do not run unrelated Institution User screen/controller suites unless existing Institution User implementation was modified. Reusing the repository contract does not by itself justify changing or broadly retesting unrelated Users UI.

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

- exact task scope;
- no Parent relationship implementation;
- no backend/schema/package/route changes;
- no duplicate network/cache architecture;
- no optimistic relationship/count state;
- no mutation auto-replay;
- correct active/inactive/archived boundaries;
- correct 404 existence privacy;
- correct business_conflict handling without human-message parsing;
- safe stale async/session/group/member-kind publication;
- no weakened tests/debug output/raw exceptions/secrets/temp artifacts.

Do not run the full frontend suite, Windows build, broad E2E, or Frontend Phase 2 in this task. Those belong to the frontend block checkpoint unless a concrete unexpected shared-infrastructure regression risk invalidates this verification scope; report that mismatch instead of silently broadening verification.

---

# 30. Delivery

Future Build Runner/Codex execution:

```text
branch: task/s04-fe-004-group-memberships
commit: feat(frontend): manage group memberships
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

# 31. Codex Completion Report

Return concise evidence:

1. `ACCEPTED`, `BLOCKED`, or `DELIVERY BLOCKED`.
2. Implementation summary.
3. Changed files and purpose.
4. Acceptance-criteria evidence.
5. Exact focused verification commands/results.
6. Teacher/Student read/query evidence.
7. Assignment 200/201/idempotency/atomic-failure/unknown-outcome evidence.
8. Removal 204/history-preserving/unknown-outcome evidence.
9. Archived/inactive/404/business_conflict/tenant evidence.
10. Stale async/session/target/kind/focus ownership evidence.
11. Group Detail/List authoritative count invalidation evidence.
12. `git diff --check` + focused scope/diff self-review.
13. Commit/PR/merge/main-sync evidence.
14. Exact deviations/blockers.

If any product, architecture, API, security, tenant, relationship lifecycle, concurrency, mutation-outcome, async-ownership, or UX decision required by this task is missing or conflicts with current implementation, return `BLOCKED` instead of inventing behavior.
