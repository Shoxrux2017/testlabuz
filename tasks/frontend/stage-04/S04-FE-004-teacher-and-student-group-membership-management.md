# S04-FE-004 — Teacher and Student Group Membership Management

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S04-FE-004` |
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | `Frontend` |
| Status | `Approved` |
| Review | `Complete` |
| Depends on | `S04-FE-003 Accepted / Delivered` |
| Delivery | `Implementation + GitHub delivery` |

Start implementation only when S04-FE-003 is present on synchronized `origin/main` as Accepted / Delivered.

This file is the complete task-specific implementation contract for Codex.

Codex must use only this contract, applicable `AGENTS.md` files, and directly relevant source/tests. Do not read product docs, roadmap, previous/future task contracts, Stage history, checkpoint reviews, or closure reviews to determine behavior.

---

## 2. Goal

Extend the delivered Institution Admin Group Detail screen with complete current Teacher and Student membership management for the selected Group.

The UI must support:

```text
read current Teachers
read current Students
search/filter/sort/page each list independently
assign 1..100 active Teachers
assign 1..100 active Students
remove a current Teacher membership
remove a current Student membership
read archived Group memberships without mutation controls
```

Backend remains authoritative for:

```text
tenant scope
role correctness
new-assignment active-user eligibility
Group archived lifecycle
atomicity
concurrency
membership history
membership timestamps
Group membership counts
```

The frontend must not use optimistic authoritative relationship/count state and must not automatically replay uncertain mutations.

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

For assignment candidate discovery reuse only the existing typed Institution User list repository backed by:

```text
GET /api/v1/institution/users
```

Implement:

- separate Teacher and Student current-membership sections;
- one typed Teacher/Student membership stack where responsibilities are identical;
- strict member/list/query models and DTOs;
- independent membership-list application state;
- assignment candidate controllers/dialogs;
- ordered cross-page selection with persistent selected tray;
- assignment mutation handling for `200`/`201`;
- remove confirmation and `204` handling;
- exact mutation error-envelope parsing;
- Group lifecycle/action arbitration with delivered FE-003;
- authoritative membership/detail reconciliation after mutations;
- Group-list stale marking while preserving retained query;
- session/target/kind/member/action stale-completion safety;
- keyboard/accessibility/responsive behavior;
- focused deterministic tests.

### Non-goals

Do **not** implement:

- Group create/edit/archive behavior changes except narrow action arbitration/integration;
- Group reactivation;
- Parent–Student relationships;
- Teacher/Student account create/edit/lifecycle;
- Teacher/Student User Detail navigation from membership rows;
- historical membership-list UI;
- editing `started_at` or `ended_at`;
- membership hard deletion;
- a server-side candidate endpoint;
- exclusive-group rules;
- optimistic membership row insertion/removal;
- optimistic Group count updates;
- mutation auto-replay;
- global candidate cache;
- a second Institution User repository/client;
- a second Group Detail cache;
- a second Group-list retained store;
- new routes;
- Institution Dashboard invalidation;
- backend/schema/API changes;
- package/dependency/platform changes;
- speculative relationship abstraction for S04-FE-005.

---

## 4. Current Implementation Context

Implementation starts only after S04-FE-003 is Accepted / Delivered.

Reuse delivered ownership boundaries:

```text
InstitutionGroup + strict Group DTO
Group Detail repository/controller/state/screen
Group Detail selected-object/session ownership
FE-003 Group action state/controller
Group-list retained query + stale/reload owner
ApiErrorCodes.businessConflict
configured Dio + DioFailureMapper
InstitutionUser
InstitutionUserListQuery
InstitutionUserListRepository
```

Do **not** reuse the global Institution User list controller/retained state for candidate dialogs.

Candidate discovery is dialog-local application state and must not modify:

```text
Institution Admin Users page query
Institution Admin Users retained search/filter/sort/page
Institution Admin Users controller state
```

Teacher/Student membership endpoints are intentionally symmetric. Use one explicit member-kind abstraction rather than two near-identical stacks.

Do not force Parent–Student relationships into this abstraction.

---

# 5. Member Kind and Resource Contract

## 5.1 Member kind

Use one explicit machine kind:

```text
teacher
student
```

Exact mapping:

| Kind | Endpoint segment | Assignment body key | Candidate User role |
|---|---|---|---|
| Teacher | `teachers` | `teacher_ids` | `teacher` |
| Student | `students` | `student_ids` | `student` |

Do not derive API paths/body keys/roles from localized UI labels.

Required kind-owned presentation values may include:

```text
Teachers / Students
Assign Teachers / Assign Students
Teacher / Student
teacher / student
```

Keep display values separate from machine values.

---

## 5.2 Exact current-member resource

Teacher and Student membership list/assignment responses use exactly:

```text
id
full_name
login_name
email
phone
is_active
started_at
```

Strict rules:

`id`

```text
canonical hyphenated UUID string
```

`full_name`

```text
required non-blank string
```

`login_name`

```text
required non-blank string
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
required valid ISO-8601 UTC timestamp ending in Z
```

Reject:

- missing key;
- unknown key;
- wrong/null type outside contract;
- malformed/noncanonical UUID;
- invalid/non-`Z` timestamp;
- duplicate member IDs within one page/assignment result, case-insensitively.

Do not silently trim/default/coerce returned resource values.

Do not expect/expose:

```text
membership_id
institution_id
role
assigned_by_user_id
ended_at
password
```

### Current-membership identity

For stale action ownership, current membership identity is:

```text
groupId
memberKind
member.id case-insensitively
member.startedAt
exact selected member object identity
```

Do **not** use only User UUID.

Mutable User projection fields are not membership identity:

```text
fullName
loginName
email
phone
isActive
```

A removed-and-later-reassigned same User represents a new current membership because `startedAt` changes.

---

# 6. Group Detail Integration and Group-Scoped Action Arbitration

## 6.1 Sections

No new route.

Extend the existing Group Detail route:

```text
/institution-admin/groups/{groupId}
```

After Group metadata/details render two distinct sections:

```text
Teachers
Students
```

Teacher/Student sections are independent read projections.

Archived Groups:

- membership GET remains allowed;
- lists remain readable;
- no Assign;
- no Remove;
- show exact section read-only text:

```text
Membership changes are unavailable because this group is archived.
```

Do not start membership reads before Group Detail owns a canonical, eligible, confirmed Group.

If Detail becomes:

```text
loading
error
not_found
session-ineligible
```

membership mutation controls are unavailable and membership action publication authority is invalidated.

---

## 6.2 One Group-scoped mutation/dialog at a time

The following are mutually exclusive for one Group Detail:

```text
Edit
Archive Group
Assign Teachers
Assign Students
Remove Teacher
Remove Student
```

At most one Group-scoped mutation/dialog may be open or busy.

### FE-004 may depend one-way on FE-003 action state

Membership action begin must fail when the delivered FE-003 Group action state is not available for a new action.

Avoid a provider dependency cycle:

- FE-004 may read FE-003 action state;
- Group Detail screen may combine FE-003 + FE-004 states into a presentation `canStartGroupMutation`;
- FE-003 controller does not need to depend on FE-004 controller.

### When FE-003 Edit/Archive is open or busy

Disable:

```text
Assign Teachers
Assign Students
all Remove actions
Detail Refresh
```

### When FE-004 Assign/Remove is open or busy

Disable:

```text
Edit
Archive Group
other Assign
all other Remove actions
Detail Refresh
```

Membership list rows may remain visible while mutation is open/busy, but no second mutation starts.

### Detail object replacement

Membership **list reads** are target/session/kind/query owned and must not reset merely because the same Group Detail receives a harmless authoritative object replacement.

Membership **candidate/mutation dialogs** are bound to the exact confirmed Group object used to open them.

If that Group object is replaced, archived, not-found, error, or session ownership changes:

```text
invalidate open membership mutation ownership
close stale picker/remove dialog
clear picker selection
reject later stale mutation completion
```

---

# 7. Current Membership List API

## 7.1 Exact endpoints

Teacher:

```text
GET /institution/groups/{groupId}/teachers
```

Student:

```text
GET /institution/groups/{groupId}/students
```

Requirements:

```text
canonical validated Group UUID
exactly HTTP 200 for success
Dio queryParameters
no data argument
zero request-body bytes
```

No other 2xx is accepted as valid list success.

---

## 7.2 Allowed query and serialization

Allowed query keys only:

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

Status machine values:

```text
active
inactive
```

Allowed sort values:

```text
full_name
started_at
```

Directions:

```text
asc
desc
```

Page-size UI values:

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

Send only when non-null:

```text
search
status
```

Never send:

```text
blank search
"all"
JSON null
current_page
unknown query key
tenant selector
body/data bytes
```

Search/status values belong in `queryParameters`; do not build a raw query string manually.

Teacher and Student query state are independent.

---

## 7.3 Search contract

Labels:

```text
Search teachers
Search students
```

Normalization:

```text
trim outer whitespace
blank normalized -> null / omit query key
preserve case/internal whitespace/punctuation/special characters
```

Search maximum:

```text
254 Unicode code points
Dart: value.runes.length
```

Do not use UTF-8 byte length or UTF-16 code-unit semantics as the contract boundary.

Exact local validation:

```text
Search must be 254 characters or fewer.
```

Debounce:

```text
exactly 300 ms
```

Rules:

1. valid draft change cancels prior debounce and starts 300 ms;
2. after inactivity commit normalized search;
3. changed committed search -> page 1;
4. Enter/Search submit cancels debounce and commits immediately;
5. recommitting identical normalized query sends no duplicate GET;
6. over-length draft cancels debounce and sends no GET.

### Pending valid draft + another action

For:

```text
Status
Sort
Page size
Refresh
```

while a different valid search draft is pending:

1. cancel debounce;
2. commit normalized draft into the same resulting query;
3. use page 1 because search changed;
4. issue only one logical GET.

Do not request old committed search first.

For:

```text
Previous
Next
```

while a different valid search draft is pending:

```text
commit pending search
load page 1
do not paginate old search result
```

### Invalid draft + another action

While over-length local validation exists, these send no GET:

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

---

## 7.4 Filters, sorting, clear, refresh, retry

Status UI:

```text
All statuses -> null
Active       -> active
Inactive     -> inactive
```

Changing status:

```text
page = 1
preserve valid committed/pending-normalized search
preserve perPage/sort/direction
```

Sorting columns:

```text
Full name -> full_name
Assigned  -> started_at
```

Rules:

```text
default = full_name asc
different sort -> asc
same sort -> toggle asc/desc
sort change -> page 1
```

Page size:

```text
20 / 50 / 100
change -> page 1
```

### Clear filters

Clears only:

```text
searchDraft
committed search
status
search validation
```

Resets:

```text
page = 1
```

Preserves:

```text
perPage
sort
direction
```

If already clear and page 1:

```text
no duplicate GET
```

### Refresh

Refresh exact current committed logical query.

If different pending valid search exists, first commit it according to Section 7.3.

Explicit Refresh may retain only same-query current confirmed rows and must expose visible/semantic refreshing state.

### Retry

For non-session read failure:

```text
manual Retry
exact failed committed query
duplicate protected
no automatic retry
```

Session-authority failures use auth/session reconciliation and do not remain as a normal section error with Retry.

---

## 7.5 Exact list envelope

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

Reject unknown/missing/renamed top-level/meta/pagination keys.

Pagination fields are JSON integers:

```text
page >= 1
page == requested page

per_page in 1..100
per_page == requested perPage

total >= 0

last_page >= 1
last_page == max(1, ceil(total / per_page))
```

Row invariants:

```text
rows.length <= per_page
total == 0 -> data empty + last_page == 1
total > 0 -> rows.length <= total
page > last_page -> valid only when data empty
no duplicate member IDs in page
```

Do not accept:

```text
numeric strings
doubles
booleans
null pagination
current_page alias
invented/defaulted missing metadata
```

Malformed success maps to:

```text
ApiFailureKind.invalidResponse
```

---

## 7.6 Empty-page correction

A membership logical request gets at most one automatic correction.

When:

```text
data empty
requested page > 1
correction not yet used
```

calculate:

```text
if total == 0:
    target = 1
else:
    target = max(1, min(last_page, requested_page - 1))
```

If target differs:

1. update committed page;
2. mark correction used;
3. issue one corrective GET;
4. preserve search/status/perPage/sort/direction;
5. preserve same request/session/kind ownership.

Never second-correct the same logical request.

Teacher and Student correction budgets are independent.

---

# 8. Membership Section UI

Each section contains:

```text
semantic section heading
optional Assign action
search
status filter
Clear filters
Refresh
current-member table
pagination
section feedback/error
```

Columns for both:

```text
Full name
Login name
Contact
Status
Assigned
Action
```

Display:

```text
email + phone both null -> Not provided
is_active true  -> Active
is_active false -> Inactive
started_at -> YYYY-MM-DD HH:mm UTC
```

Status is visible text, not color-only.

Inactive current members remain visible and removable while Group is active.

Rows do not navigate to User Detail.

### Empty

Global:

```text
No teachers assigned
No students assigned
```

Active Group may include respective Assign action.

Archived Group never offers assignment.

Filtered:

```text
No matching teachers
No matching students
```

with `Clear filters`.

### Section error

```text
Unable to load teachers
Unable to load students
```

Teacher read failure must not hide Group metadata or Student section.

Student read failure must not hide Group metadata or Teacher section.

---

# 9. Candidate Discovery

## 9.1 Existing User repository reuse

Use existing typed:

```text
InstitutionUserListRepository
InstitutionUserListQuery
InstitutionUser
```

Do not call Users API through a new client/repository.

Teacher picker fixed query:

```text
role = teacher
status = active
sort = full_name
direction = asc
per_page = 20
```

Student picker fixed query:

```text
role = student
status = active
sort = full_name
direction = asc
per_page = 20
```

Candidate UI may change only:

```text
search
page
```

Do not mutate/read the main Users page retained controller/store.

Candidate query is destroyed on dialog close.

---

## 9.2 Candidate result invariants

After the existing Institution User repository returns a page, the candidate application boundary must verify the fixed-purpose result.

Teacher picker:

```text
every user.role == teacher
every user.isActive == true
```

Student picker:

```text
every user.role == student
every user.isActive == true
```

Also require:

```text
candidate IDs unique case-insensitively within page
```

If a row violates fixed role/active purpose:

```text
reject whole candidate page as invalidResponse
```

Do not silently filter mismatching rows.

New-assignment candidate eligibility does **not** require:

```text
mustChangePassword == false
absence from other Groups
absence from this Group
```

No exclusive-group rule exists.

A Teacher/Student may belong to multiple Groups simultaneously.

Already-current active Users may appear and may be selected; backend assignment is additive/idempotent.

Exact explanatory text:

```text
Only active users are shown. Users already assigned to this group can be selected safely; duplicate active memberships are not created.
```

---

## 9.3 Candidate query behavior

Candidate search:

```text
max = 254 Unicode code points
value.runes.length
normalize = outer trim
blank = null
debounce = exactly 300 ms
search change = page 1
Enter = immediate commit
```

Over-length exact error:

```text
Search must be 254 characters or fewer.
```

No candidate GET while invalid.

Candidate pagination:

```text
Previous
Next
per_page fixed 20
```

Candidate page correction uses the same one-correction formula as Section 7.6.

Candidate non-session read failure:

- dialog remains open;
- selection tray remains;
- old rows from a different query are not current;
- show safe error;
- Retry exact failed candidate query;
- Cancel remains available.

Session/Group ownership failure closes/invalidates picker through normal state transition.

---

## 9.4 Ordered cross-page selection

Use a controlled ordered typed selection.

Semantic owner may be equivalent to:

```text
LinkedHashMap<lowercase UUID, InstitutionUser>
```

Requirements:

```text
minimum submit = 1
maximum submit = 100
case-insensitive ID uniqueness
preserve exact user selection order
```

IDs may come only from strictly parsed/validated candidate resources.

Selection survives:

```text
candidate search changes
candidate page changes
candidate read failure
```

while the same dialog remains open.

### Persistent selected tray

The dialog must expose all selected users independently of current candidate page/search.

Show:

```text
Selected: N / 100
```

and a bounded selected tray/list containing, for every selection in selection order:

```text
Full name
Login name
Remove from selection
```

The user must be able to deselect an off-page candidate from this tray.

When count = 100:

- unchecked candidates cannot be selected;
- selected items remain deselectable.

No manual UUID entry.

Closing picker destroys:

```text
candidate query
candidate rows
selection
```

---

# 10. Assignment Dialog UX

Teacher:

```text
title = Assign Teachers
submit = Assign Teachers
```

Student:

```text
title = Assign Students
submit = Assign Students
```

Dialog contains:

```text
candidate search
candidate page state
candidate checkboxes
persistent selected tray
selected count
Cancel
Submit
```

Use bounded desktop width/height.

Use one internal scrollable candidate/result region plus bounded selected tray behavior; do not create unbounded nested vertical scroll.

### Before mutation

Cancel/Escape/barrier dismissal allowed.

Cancel:

```text
clear dialog-local candidate query + selection
no mutation
restore Assign focus only if same Group remains confirmed active/current
```

Submit disabled when:

```text
selection empty
candidate/search state invalid for submission
another Group-scoped mutation owns target
mutation busy
```

### During POST/reconciliation

Disable:

```text
candidate search/page
candidate selection
selected tray mutation
Cancel
Submit
Detail Refresh
Edit/Archive
other membership mutations
```

Block:

```text
Escape
back/pop
barrier dismissal
```

Semantic progress:

```text
Assigning teachers
Assigning students
Checking current server state
```

---

# 11. Exact Assignment Request

Teacher:

```text
POST /institution/groups/{groupId}/teachers
```

Body exactly:

```json
{
  "teacher_ids": ["uuid-1", "uuid-2"]
}
```

Student:

```text
POST /institution/groups/{groupId}/students
```

Body exactly:

```json
{
  "student_ids": ["uuid-1", "uuid-2"]
}
```

Transport:

```text
Content-Type = application/json
no query parameters
followRedirects = false where established mutation convention uses it
```

Exactly one allowed body key.

Request array:

```text
length 1..100
canonical UUID strings
distinct case-insensitively
selection order preserved
```

Never send:

```text
wrong-kind body key
both body keys
tenant/institution ID
role/status
membership ID
started_at/ended_at
extra field
query parameter
```

The backend operation is atomic.

Frontend must never present partial assignment success.

---

# 12. Assignment Success

## 12.1 HTTP semantics

Accepted confirmed success:

```text
201 Created -> at least one current membership newly created
200 OK      -> all requested memberships already current / idempotent
```

No other 2xx is valid confirmed success.

Teacher exact message:

```text
Teachers assigned to group successfully.
```

Student exact message:

```text
Students assigned to group successfully.
```

Exact top-level envelope:

```json
{
  "data": [],
  "message": "..."
}
```

No meta and no unknown keys.

Require:

```text
data is array
data.length == submitted ID count
all items strict current-member resources
no duplicate returned IDs
returned IDs match submitted IDs case-insensitively
returned order == submitted order
exact member-kind success message
```

Do **not** require returned `is_active == true`.

An already-current membership may now project an inactive account while still being an idempotent current membership.

Do not patch membership list/counts from response.

---

## 12.2 Confirmed assignment publication

On strict current 200/201:

1. mutation outcome becomes confirmed success;
2. close picker;
3. clear picker query/selection;
4. mark relevant membership projection non-authoritative/stale;
5. mark Group list stale while preserving retained query;
6. publish exact success feedback;
7. after terminal mutation ownership is settled, trigger:
   - authoritative relevant membership GET using existing membership query;
   - authoritative Group Detail refresh for counts;
8. do not optimistically change row/count.

Feedback:

```text
Teachers assigned to group successfully.
Students assigned to group successfully.
```

Confirmed mutation feedback remains true even if a later projection reload fails.

Projection reload failure is a separate read failure.

---

# 13. Exact Mutation Error Envelope

Assignment and Remove may be treated as definite failures only when exact structural envelope and allowed status/code pair match.

Exact envelope:

```json
{
  "message": "non-blank string",
  "code": "non-empty string",
  "errors": {},
  "request_id": "optional non-empty string"
}
```

Required:

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

Rules:

```text
message = non-blank string
code = non-empty string
request_id if present = non-empty string
errors = JSON object
```

Each errors entry:

```text
key = string
value = non-empty array
every item = non-empty string
```

For definite non-422:

```text
errors must be empty
```

Allowed status/code pairs:

```text
401 -> authentication_required

403 -> forbidden
403 -> password_change_required
403 -> user_inactive
403 -> institution_inactive

404 -> resource_not_found

409 -> business_conflict

422 -> validation_failed

429 -> rate_limited
```

Do not branch on backend human-readable `message`.

Malformed envelope, unsupported pair, unexpected status after dispatch, or transform failure is uncertain mutation outcome.

---

## 13.1 Assignment 422

Known selection key is exactly the current kind's key:

```text
teacher_ids
student_ids
```

Any of these are protocol/unknown for the current request:

```text
body
wrong-kind IDs key
query key
protected key
unknown key
```

Show safe form-level:

```text
The assignment request did not match the server contract.
```

Do not display raw validation strings.

If server errors include current known IDs key plus any protocol/unknown key, the same form-level protocol feedback is required.

Assignment `422`, `403 forbidden`, and `429` are recoverable definite dialog failures:

- dialog stays open;
- candidate query remains;
- selection tray remains;
- controls re-enable;
- feedback live region;
- no automatic retry;
- a later Submit is a new explicit POST.

Session-authority errors close/clear through session transition.

---

# 14. Assignment `409` / `404` / Unknown Reconciliation

## 14.1 `409 business_conflict`

Possible backend state changes include:

```text
Group became archived
new selected User became inactive
```

Do not distinguish via human message.

Flow:

1. mark relevant membership projection stale/non-authoritative;
2. mark Group list stale;
3. close picker and clear its selection/query;
4. publish checking state;
5. authoritative Group Detail reconciliation GET;
6. never replay POST.

During reconciliation, old Group/member projection may be visible only as explicitly non-authoritative and mutation/refresh actions are disabled.

### Detail valid 200 -> archived

Replace Detail authoritative Group.

Membership sections remain readable but read-only.

Reload relevant membership list.

Feedback:

```text
Assignment was not accepted because current server state changed. Review the group and active users before trying again.
```

### Detail valid 200 -> active

Replace/confirm current Group.

Reload relevant membership list.

Same safe feedback.

A later picker begins with fresh active candidates.

### Detail exact 404

```text
whole Group Detail -> existing not_found
clear membership controllers/actions
```

### Detail session failure

```text
clear protected state
auth/session reconciliation
```

### Detail other failure/malformed read

```text
discard stale Group
Detail -> error
no membership mutation controls
```

Do not keep stale active Group as confirmed.

---

## 14.2 Assignment exact `404`

Could represent Group or selected target resolution.

Do not infer target existence.

Flow:

1. mark relevant membership projection stale;
2. mark Group list stale;
3. close picker/clear local state;
4. authoritative Group Detail GET;
5. no POST replay.

If Group Detail exact 404:

```text
Group Detail -> existing not_found
```

If Group Detail valid current Group:

- reload relevant membership list;
- show:

```text
One or more selected users are no longer available for this assignment.
```

If Group Detail session/error:

- use exact session/error transition from Section 14.1.

---

## 14.3 Assignment unknown outcome

Never replay assignment POST.

Unknown includes:

```text
connection interruption/error with dispatch ambiguity
timeout
Dio cancellation while operation owns publication
HTTP 5xx
unexpected status
unexpected 2xx other than 200/201
malformed/unexpected error envelope
unsupported status/code pair
malformed 200/201 body
wrong message
returned ID/resource/order mismatch
response transform/parsing failure
unexpected post-dispatch exception
```

Flow:

1. mutation remains unconfirmed;
2. mark relevant membership projection stale/non-authoritative;
3. mark Group list stale;
4. close picker/clear local query+selection;
5. publish checking state;
6. trigger authoritative relevant membership GET;
7. trigger authoritative Group Detail refresh/reconciliation;
8. do not scan all membership pages to manufacture success;
9. do not infer from Group count;
10. never replay POST.

Neutral feedback:

Teacher:

```text
Teacher assignment result could not be confirmed. Review the current teacher list before assigning again.
```

Student:

```text
Student assignment result could not be confirmed. Review the current student list before assigning again.
```

Do **not** say memberships "were refreshed" unless the read actually succeeded.

Read owners separately show whether authoritative current data loaded successfully.

---

# 15. Remove Membership

## 15.1 Opening Remove

Available only when:

```text
Group confirmed active
membership section has confirmed current row
no Group-scoped action is open/busy
```

Inactive current members are removable.

Bind remove operation to exact membership identity from Section 5.2.

Teacher title:

```text
Remove teacher from group?
```

Student title:

```text
Remove student from group?
```

Show:

```text
full name
login name
```

Exact explanation:

```text
This ends the current group membership and revokes future group-based access. Historical relationship records and existing learning history are preserved. The user account itself is not deactivated.
```

Actions:

```text
Cancel
Remove
```

Before submit:

```text
Cancel/Escape/barrier dismissal allowed
```

Cancel restores same Remove focus only if the exact current membership identity still exists and Group remains active.

---

## 15.2 Exact DELETE

Teacher:

```text
DELETE /institution/groups/{groupId}/teachers/{teacherId}
```

Student:

```text
DELETE /institution/groups/{groupId}/students/{studentId}
```

Requirements:

```text
canonical Group UUID
canonical member User UUID
no query
no data argument
zero request-body bytes
followRedirects = false where established mutation convention uses it
```

Valid confirmed success:

```text
exactly HTTP 204 No Content
```

Accepted transport payload after Dio:

```text
null
or exact empty string
```

Reject as uncertain result if 204 carries meaningful decoded/body content:

```text
{}
[]
non-empty string
number
boolean
```

Unexpected status is not confirmed success.

Backend semantics consumed:

```text
current membership -> authoritative ended_at set
no current membership -> idempotent 204
historical rows preserved
inactive current member removable
User account unchanged
reassignment later creates a new current membership identity
```

Frontend current-member UI never displays `ended_at`.

---

## 15.3 Remove busy state

During DELETE/reconciliation:

```text
Cancel disabled
Remove disabled
dismissal/back blocked
Detail Refresh disabled
Edit/Archive disabled
all Assign/other Remove disabled
```

Semantic progress:

```text
Removing teacher
Removing student
Checking current server state
```

---

## 15.4 Confirmed remove

On strict current 204:

1. mutation outcome confirmed;
2. close confirmation;
3. mark relevant membership projection stale/non-authoritative;
4. mark Group list stale;
5. publish exact feedback;
6. after terminal mutation ownership settles:
   - authoritative relevant membership reload using existing query;
   - authoritative Group Detail refresh for counts.

Feedback:

```text
Teacher removed from group.
Student removed from group.
```

Do not optimistically delete row/decrement count.

If authoritative reload produces empty/out-of-range page, use list one-correction policy.

Confirmed removal remains confirmed even if subsequent projection read fails.

---

# 16. Remove Definite / Unknown Reconciliation

## 16.1 Recoverable definite `403` / `422` / `429`

Exact safe feedback:

```text
forbidden:
You do not have permission to change group memberships.

validation_failed:
The removal request did not match the server contract.

rate_limited:
Too many requests. Wait before trying again.
```

After response:

- close confirmation;
- do not mark list/detail stale solely for these definite no-mutation failures;
- show feedback in relevant membership section/Detail;
- restore focus to same Remove action only if:
  - Group still confirmed active;
  - exact membership identity is still current;
  - session/target ownership remains current.

No automatic DELETE retry.

---

## 16.2 Remove `409 business_conflict`

Do not infer conflict reason from backend message.

Flow:

1. mark relevant membership projection stale;
2. mark Group list stale;
3. close dialog;
4. authoritative Group Detail GET;
5. never replay DELETE.

If Detail archived:

- replace authoritative Detail;
- membership sections read-only;
- reload relevant list;
- show:

```text
Membership removal was not accepted because current server state changed.
```

If Detail active:

- replace/confirm Detail;
- reload relevant list;
- same feedback.

404/session/error use the same whole-Detail transitions as assignment reconciliation.

Do not restore obsolete Remove focus.

---

## 16.3 Remove exact `404`

Could represent Group/member target resolution.

Flow:

1. mark relevant list stale;
2. mark Group list stale;
3. close dialog;
4. authoritative Group Detail GET.

If Group not found:

```text
Group Detail -> existing not_found
```

If Group valid current:

- reload relevant membership list;
- show:

```text
The selected membership target is no longer available.
```

Do not disclose why.

Session/error -> existing safe transitions.

---

## 16.4 Remove unknown outcome

Never replay DELETE, even though backend repeat removal is idempotent.

Unknown includes:

```text
connection interruption/error
timeout
Dio cancellation while current operation owns publication
HTTP 5xx
unexpected status
unexpected 2xx
malformed/unexpected error envelope
unsupported status/code pair
204 with meaningful body
response transform failure
unexpected post-dispatch exception
```

Flow:

1. mark relevant membership projection stale;
2. mark Group list stale;
3. close confirmation;
4. authoritative relevant membership reload;
5. authoritative Group Detail refresh/reconciliation;
6. no full-page scanning to prove original outcome;
7. no replay.

Neutral feedback:

```text
Teacher removal result could not be confirmed. Review the current teacher list.

Student removal result could not be confirmed. Review the current student list.
```

Do not claim the refresh succeeded when it did not.

---

# 17. Mutation-Induced Read Reconciliation

## 17.1 Relevant membership projection

After any mutation that:

```text
confirmed success
may have committed
returned 404
returned 409
```

the relevant membership rows from before the mutation are not authoritative.

While authoritative reload is in flight, old same-query rows may remain visible only with explicit non-authoritative state:

```text
Checking current teachers
Checking current students
```

During this state:

```text
Assign disabled
Remove disabled
membership query controls may be disabled until current result settles
```

If reload succeeds:

```text
replace with authoritative current page
```

If reload fails:

```text
discard stale rows
section -> error
manual Retry exact current query
```

Do not leave old rows as normal data.

Teacher projection failure does not corrupt Student projection and vice versa.

---

## 17.2 Group Detail counts

`teachers_count` and `students_count` come only from authoritative Group Detail resource.

Never increment/decrement locally.

After a membership mutation that succeeded or may have committed:

```text
trigger authoritative Detail refresh/reconciliation
```

If Detail becomes:

```text
archived -> mutation controls disappear
not_found -> membership owners clear
session loss -> protected state clears
error -> stale Group/actions not shown
```

---

## 17.3 Terminal feedback ordering

Do not let authoritative Detail object replacement erase already-settled mutation feedback.

Required logical ordering:

1. establish current mutation terminal outcome (`confirmed`, `definite`, or `unconfirmed`);
2. close/settle dialog ownership;
3. publish safe terminal feedback;
4. release dialog-bound selected Group/member ownership;
5. start authoritative membership/detail projection reads;
6. later Group object replacement cannot be mistaken for invalidating a still-in-flight mutation that already settled.

Stale **in-flight** operations still lose publication authority immediately.

---

# 18. Membership List Application State

Use family-style controller keyed by:

```text
groupId + memberKind
```

Each list owns:

```text
committed query
search draft
search validation
confirmed current page
failure
load presentation
operation generation
in-flight logical query
eligible session key
Group target
member kind
one-correction budget
```

Required states:

```text
initial
loading
queryLoading
refreshing
data
globalEmpty
filteredEmpty
emptyPage
checkingCurrentState
error
```

Requirements:

- canonical Group target;
- active eligible desktop Institution Admin session;
- starts only while Group Detail owns valid confirmed target;
- archived Group read allowed;
- duplicate identical in-flight read suppressed;
- newer query supersedes older;
- stale success/error rejected;
- dispose/session/institution/target/kind completion rejected;
- Teacher cannot overwrite Student;
- query survives mutation reload while Detail remains;
- no cross-route/cross-Group retained cache required.

Membership GET exact 404 while Detail exists:

```text
section -> safe unavailable/checking
authoritative Group Detail reconciliation required
do not infer tenant/target existence
```

Session authority errors use existing auth/session reconciliation.

---

# 19. Candidate Picker Application State

Use separate family/dialog controller keyed by:

```text
groupId + memberKind
```

It owns:

```text
fixed role/status/sort/perPage purpose
search draft
committed search
page
candidate result
candidate read failure
ordered selected typed snapshots
operation generation
session/target/kind ownership
exact selected Group object identity
```

Candidate stale completion must not:

```text
update closed dialog
replace newer query
change newer selection
publish into another Group/kind
publish after session/institution/device loss
publish after exact selected Group object is replaced
publish after Group becomes archived
```

No global candidate cache.

---

# 20. Membership Mutation Ownership

Use focused action controller/state keyed by Group route target.

Operation owns:

```text
eligible session key
authenticated user ID
exact AuthUser instance identity
institution ID
route Group UUID
exact confirmed selected Group object identity
member kind
operation kind = assign | remove
operation generation
focus-restoration key
```

Assign additionally owns:

```text
immutable ordered submitted UUID list
selected candidate snapshots
```

Remove additionally owns:

```text
exact selected current member object identity
member.id
member.startedAt
```

Publication requires all current ownership.

Reject stale completion after:

```text
session/account/institution/device change
route target change
selected Group object replacement
Group becomes archived
selected membership object replacement/reassignment
provider/dialog dispose
newer operation generation
```

A stale completion must not:

```text
replace Group Detail
refresh wrong member kind
close newer dialog
show feedback in another session
restore obsolete focus
navigate
```

Actual Dio cancellation is not required.

---

# 21. Candidate / Account Lifecycle Rules

Candidate read requests only active users of correct role.

New membership eligibility is ultimately backend-authoritative:

```text
same Institution
correct Teacher/Student role
is_active = true
```

Do not add a frontend rule requiring:

```text
must_change_password = false
no other Group memberships
not already current in this Group
```

A candidate may become inactive after load.

Backend may then return:

```text
409 business_conflict
```

No partial assignment.

Currently assigned User may later become inactive:

- remains current;
- remains visible in current membership list;
- can be removed;
- do not hide it.

No exclusive-group warning/removal.

---

# 22. Authorization / Tenant / Relationship History

Eligible frontend actor:

```text
authenticated
role = institution_admin
active user
must_change_password = false
active own institution
desktop surface
```

Never send:

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

Group/member UUIDs are resource identifiers only and never expand tenant scope.

Backend remains authoritative for:

```text
Group tenant
User tenant
User role
new-assignment active eligibility
Group archived lifecycle
atomicity
locking/concurrency
history
started_at/ended_at
membership counts
```

Wrong-role, foreign, missing targets remain privacy-safe.

Frontend does not display membership history rows in this task.

---

# 23. Accessibility / Keyboard / Responsiveness

## Sections

- semantic Teachers/Students headings;
- keyboard-reachable search/filter/sort/pagination/actions;
- sortable header semantics expose direction;
- loading/refresh/checking/error announcements;
- active/inactive status is text;
- tables horizontally scroll rather than overflow;
- page-level vertical scrolling remains bounded and usable;
- text scaling and supported desktop resizing do not overflow.

Each section table should use its own horizontal scroll surface rather than an unbounded nested vertical list.

## Assignment dialog

- predictable traversal;
- candidate checkboxes labelled;
- selected tray reachable;
- off-page selected user can be removed;
- selected count announced;
- errors/live progress announced;
- max-100 state understandable;
- Cancel/Submit semantics clear;
- no dismissal while busy/reconciling;
- bounded dialog dimensions;
- focus returns to Assign only if same active Group/action remains.

## Remove dialog

- confirmation content/actions have predictable focus;
- Cancel/Remove keyboard accessible;
- dismissal blocked while busy/reconciling;
- exact member identity controls focus restoration;
- if membership disappeared/reassigned or Group archived, focus section heading/read-only surface rather than obsolete Remove button.

Do not introduce a new design system.

---

# 24. Architecture and Placement

Expected new files may include:

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

Expected presentation modification/addition:

```text
frontend/lib/features/institution_admin/presentation/
  institution_admin_group_detail_screen.dart
  optional institution_group_membership_section.dart
  optional institution_group_membership_dialogs.dart
```

Narrow integration modifications are allowed as required:

```text
delivered FE-003 Group action state/presentation
delivered Group Detail controller/state
delivered Group-list retained stale owner
frontend/lib/core/network/api_error_codes.dart only if required machine code is not already present
```

The purpose of any FE-003 modification is only:

```text
cross-action gating
safe shared Group Detail integration
```

Do not add/change FE-003 lifecycle business rules.

Reuse:

```text
InstitutionUserListRepository
InstitutionUserListQuery
InstitutionUser
Group Detail owner
Group-list stale owner
configured Dio/failure mapping
ApiErrorCodes
```

Do not:

- call Dio from Widgets/controllers;
- parse raw JSON in presentation/controllers;
- create a second User repository/client;
- create a second Group Detail cache;
- create a second Group-list retained store;
- create new routes;
- change Dashboard;
- create generic Parent–Student relationship infrastructure;
- modify backend/docs/packages/platform files.

Forbidden:

```text
backend/
docs/
tasks unrelated to active implementation bookkeeping
frontend/lib/app/router/
pubspec.yaml
pubspec.lock
platform directories
```

Any extra file requires concrete in-scope necessity and must be reported.

---

# 25. Acceptance Criteria

- [ ] S04-FE-003 is Accepted / Delivered on synchronized `origin/main` before implementation starts.
- [ ] Group Detail contains independent Teacher and Student current-membership sections.
- [ ] Archived Group lists remain readable and all membership mutations disappear.
- [ ] Member kind maps exact endpoint/body-key/candidate role values.
- [ ] Current-member DTO is exact and strict.
- [ ] Remove ownership uses member ID + `startedAt` + selected object identity.
- [ ] Membership GET sends exact query, zero body bytes, and accepts only HTTP 200.
- [ ] Membership search uses `runes.length`, exact 300 ms debounce, pending-draft orchestration, invalid-draft blocking, clear/retry semantics.
- [ ] Teacher/Student list query/correction state is independent.
- [ ] Exact membership list envelope/pagination is enforced.
- [ ] Candidate picker reuses existing Institution User repository without touching Users retained/controller state.
- [ ] Candidate result rejects wrong role/inactive purpose mismatch as invalidResponse.
- [ ] No exclusive-group or must-change-password candidate rule is invented.
- [ ] Candidate selection is ordered/distinct/case-insensitive, max 100, and survives page/search.
- [ ] Persistent selected tray allows off-page deselection.
- [ ] Assignment request sends exactly one kind-specific ID key and no query/tenant fields.
- [ ] Assignment accepts strict 200/201 success and exact returned ordered IDs/resources.
- [ ] Assignment error envelope/status-code pairs are strict.
- [ ] Assignment recoverable 422/403/429 keeps picker/query/selection.
- [ ] Assignment 409/404/unknown never replays and reconciles through authorized current reads.
- [ ] Unknown assignment feedback does not claim projection refresh succeeded.
- [ ] DELETE sends zero body bytes/no query and accepts only exact 204 with null/empty transport payload.
- [ ] Remove recoverable 403/422/429 uses exact safe feedback.
- [ ] Remove 409/404/unknown never replays and reconciles.
- [ ] Only one Group-scoped mutation/dialog can exist across FE-003 + FE-004 actions.
- [ ] Detail Refresh is disabled during open/busy Group mutation state.
- [ ] Candidate/mutation dialogs invalidate on selected Group object replacement/archive/session loss.
- [ ] Mutation-induced old membership rows are explicitly non-authoritative while checking and discarded on read error.
- [ ] Projection reload failure does not rewrite a confirmed mutation outcome.
- [ ] Group counts are refreshed only from authoritative Group Detail.
- [ ] Group-list stale owner preserves retained query and is reused, not duplicated.
- [ ] No optimistic row/order/page/count mutation.
- [ ] No Dashboard invalidation.
- [ ] No Parent–Student behavior.
- [ ] Session/tenant/privacy boundaries are preserved.
- [ ] Keyboard/focus/accessibility/responsive requirements pass.
- [ ] No backend/schema/dependency/route/public API change.
- [ ] Focused verification passes.
- [ ] `git diff --check` passes.
- [ ] Final diff contains no unrelated work.

---

# 26. Focused Tests and Verification

Use the actual delivered FE-003/FE-002 filenames when they differ from expected names below. Do not create duplicate tests solely to satisfy a filename.

## 26.1 Focused command

From repository root:

```powershell
Push-Location frontend

fvm spawn 3.44.7 test `
  test/features/institution_admin/institution_group_membership_domain_test.dart `
  test/features/institution_admin/institution_group_membership_dto_test.dart `
  test/features/institution_admin/institution_group_membership_list_dto_test.dart `
  test/features/institution_admin/institution_group_membership_remote_data_source_test.dart `
  test/features/institution_admin/institution_group_membership_repository_impl_test.dart `
  test/features/institution_admin/institution_group_membership_list_controller_test.dart `
  test/features/institution_admin/institution_group_membership_candidate_controller_test.dart `
  test/features/institution_admin/institution_group_membership_action_controller_test.dart `
  test/features/institution_admin/institution_admin_group_detail_screen_test.dart `
  test/features/institution_admin/institution_group_detail_controller_test.dart `
  test/features/institution_admin/institution_group_list_controller_test.dart

Pop-Location
```

Required focused coverage:

### Domain/query/member identity

- teacher/student mapping;
- exact list/mutation path/body-key mapping;
- list default query;
- rune search validation;
- search pending/invalid behavior;
- status/sort/page/perPage;
- distinct Teacher/Student query identity;
- member identity includes `startedAt`;
- assignment ordered ID validation 1..100;
- case-insensitive duplicate rejection.

### Member/list DTO

- active/inactive member;
- nullable contact;
- exact keys/types;
- canonical UUID;
- UTC startedAt;
- duplicate IDs;
- exact pagination;
- malformed contradictions.

### Membership read data/repository

- exact Teacher/Student GET paths;
- always/optional query serialization;
- zero body;
- 200 only;
- strict malformed response;
- 404/session mapping.

### Membership list controller

- eligible Detail/session start;
- archived read allowed;
- Teacher/Student isolation;
- exact debounce pending-draft orchestration;
- invalid draft action blocking;
- clear/retry;
- sort/pagination/page size;
- one page correction;
- refresh;
- mutation-induced checkingCurrentState;
- checking read failure discards stale rows;
- stale query/dispose/session/institution/target/kind rejection;
- Detail not-found/session/error propagation.

### Candidate controller

- fixed role/status/sort/perPage;
- exact Institution User repository query;
- wrong-role/inactive returned row -> invalidResponse;
- no Users controller/retained-state interaction;
- exact 300 ms search;
- Retry/page correction;
- ordered cross-page selection;
- persistent selected tray;
- off-page deselection;
- max 100;
- duplicate prevention;
- candidate error preserves selection;
- close clears query/selection;
- selected Group object/session/archive stale rejection.

### Assignment data/repository

Teacher + Student:

- exact POST path/body key;
- content JSON;
- no query;
- 1..100 ordered distinct IDs;
- 200/201 only;
- exact message;
- exact array length/order/IDs;
- inactive returned current member accepted;
- exact 401/403/404/409/422/429 envelope;
- malformed/pair mismatch/cancel/timeout/connection/5xx/unexpected 2xx/body/message/order -> unknown;
- no replay.

### Assignment controller

- only active exact selected Group;
- FE-003 action arbitration;
- duplicate action suppression;
- recoverable 422/403/429 keeps picker state;
- direct success settles feedback then starts projection reads;
- 409 current archived/active/404/session/error;
- 404 Group gone vs Group current branch;
- unknown does not scan pages/claim success;
- unknown neutral feedback;
- list/detail/Group-list stale timing;
- projection error does not undo confirmed mutation;
- stale selected Group/session/kind/generation/dialog completion rejected.

### Remove data/repository/controller

- exact DELETE path;
- zero body/no query;
- exact 204 null/empty payload;
- 204 meaningful body -> unknown;
- exact definite errors;
- no replay;
- inactive current member allowed;
- exact member identity includes startedAt/object;
- direct 204;
- recoverable 403/422/429;
- 409/404/unknown reconciliation;
- removed/reassigned same UUID does not restore obsolete focus/publish stale completion.

### Widget

- Teacher/Student independent sections;
- exact columns/status/timestamp;
- archived read-only;
- active Group actions;
- FE-003/FE-004 mutual action gating;
- Detail Refresh gating;
- global/filtered/error/refresh/checking states;
- candidate dialog fixed role explanation;
- search/pagination;
- selected tray/off-page deselection/max 100;
- candidate error preserves selection;
- busy dismissal protection;
- remove confirmation copy;
- success/definite/conflict/unknown feedback;
- projection reload error;
- archive reconciliation removes actions;
- focus restoration identity;
- semantics/text scale/narrow desktop/long data overflow.

## 26.2 Directly affected regression

The focused command must include actual delivered files directly changed by FE-004.

Required regression areas:

```text
S04-FE-003:
Edit/Archive action behavior
single Group-scoped mutation arbitration
archive -> membership read-only
Detail mutation/reconciliation/error/not-found
focus ownership

S04-FE-002:
Group Detail initial/data/refresh/error/not-found
create -> authoritative Detail route compatibility

S04-FE-001/002:
Group-list retained query
stale marker consumption
authoritative reload
no optimistic counts/order/page
```

Do not run unrelated Institution User UI/controller suites unless production User implementation is changed, which this contract does not authorize.

Candidate controller focused tests must prove Users retained/controller state is untouched.

## 26.3 Static analysis

```powershell
Push-Location frontend
fvm spawn 3.44.7 analyze
Pop-Location
```

## 26.4 Format check

```powershell
Push-Location frontend

C:\Users\Administrator\fvm\versions\3.44.7\bin\cache\dart-sdk\bin\dart.exe `
  format --output=none --set-exit-if-changed lib test

Pop-Location
```

## 26.5 Manual check

```text
Not required — deterministic domain/data/repository/controller/widget tests cover
this task. Real-stack/Windows E2E belongs to the Stage integration/checkpoint workflow.
```

## 26.6 Always

From repository root:

```powershell
git diff --check
```

Then inspect the complete diff for:

- exact FE-004 scope;
- no Parent–Student implementation;
- no route/dashboard/backend/package/platform changes;
- one shared Teacher/Student membership architecture, not duplicate stacks;
- no second User/Group cache/client;
- exact GET/POST/DELETE transport;
- exact mutation error envelope;
- no mutation replay;
- no optimistic relationship/count state;
- no exclusive-group rule;
- correct active/inactive/archived boundaries;
- exact 404 privacy;
- business_conflict without human-message branching;
- FE-003/FE-004 action arbitration without provider cycle;
- stale member identity includes startedAt;
- reconciliation failure cannot leave old rows/Group as confirmed;
- no raw exception/JSON/token/private data;
- no weakened tests/debug/temp artifacts.

Do **not** run:

```text
full frontend suite
Windows build
broad E2E
Frontend Phase 2
Stage integration
```

for this task.

If implementation necessarily requires unapproved shared scope with material regression risk, return `BLOCKED` instead of silently broadening implementation/verification.

---

# 27. Delivery

Mode:

```text
Implementation + GitHub delivery
```

Branch:

```text
task/s04-fe-004-group-memberships
```

Commit:

```text
feat(frontend): manage group memberships
```

PR:

```text
focused PR to main
```

Task/Stage bookkeeping changes:

```text
None
```

After merge require:

```text
implementation present on origin/main
local main == origin/main
ahead/behind = 0/0
working tree clean
```

If implementation/verification passes but safe GitHub delivery cannot complete:

```text
DELIVERY BLOCKED
```

---

# 28. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to rediscover/reinterpret requirements.

| Source/reference | Decision already encoded above |
|---|---|
| Teacher/Student membership controllers | Exact GET/POST/DELETE endpoint families and 200/201/204 response semantics |
| Teacher/Student index requests | Exact list query keys, status/sort/page bounds, body rejection |
| Teacher/Student assign requests | Exact one-key JSON body, 1..100 IDs, UUID/case-insensitive duplicate rules, no query |
| Teacher/Student remove requests | Zero-body/query request contract |
| Membership resources/collections | Exact member resource and pagination response |
| Membership assign/remove actions | Tenant/role/active/archive/current/history/atomic behavior |
| Membership API/concurrency tests | Idempotency, race serialization, inactive current-member behavior, multi-Group membership |
| Existing Institution User list repository/query | Candidate discovery without new API/client; fixed role/status purpose |
| Delivered S04-FE-001/002 | Group list/query/stale owner, Detail owner, counts authority |
| Approved/delivered S04-FE-003 | Edit/archive lifecycle action owner and `business_conflict`/selected-object patterns |
| `frontend/AGENTS.md` | strict DTOs, no stale authoritative data, mutation uncertainty, cache/invalidation, accessibility |

---

# 29. Codex Final Report

Return concise evidence:

1. **Status:** `ACCEPTED`, `BLOCKED`, or `DELIVERY BLOCKED`.
2. Implementation summary.
3. Changed files and purpose.
4. Acceptance-criteria evidence.
5. Exact focused verification commands/results.
6. Teacher/Student list transport/query/debounce/correction evidence.
7. Candidate fixed-role/invariant/selection-tray/no-Users-state-corruption evidence.
8. Assignment 200/201/exact-response/error/unknown/no-replay evidence.
9. Remove 204/zero-body/member-identity/history/no-replay evidence.
10. FE-003/FE-004 Group-scoped action arbitration evidence.
11. 409/404/session/unknown authoritative reconciliation evidence.
12. Projection reload + confirmed mutation independence evidence.
13. Group Detail count + Group-list stale/retained-query/no-dashboard evidence.
14. Session/tenant/privacy/stale-async/focus evidence.
15. Accessibility/responsive evidence.
16. `git diff --check` + focused diff/scope self-review.
17. Commit/PR/merge/main-sync evidence.
18. Exact deviations/blockers.

If a required product, architecture, API, security, tenant, relationship lifecycle, concurrency, mutation-outcome, action-arbitration, async-ownership, reconciliation, focus, or UX decision is missing or conflicts with delivered FE-003/current source:

```text
BLOCKED
```

Do not invent behavior.
