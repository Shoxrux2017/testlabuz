# S04-FE-002 — Institution Group Create and Detail

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S04-FE-002` |
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | `Frontend` |
| Status | `Approved` |
| Review | `Complete` |
| Depends on | `S04-FE-001 Accepted / Delivered` |
| Delivery | `Implementation + GitHub delivery` |

Start implementation only when S04-FE-001 is present on synchronized `origin/main` as Accepted / Delivered.

This file is the complete task-specific implementation contract for Codex.

Codex must use only this contract, applicable `AGENTS.md` files, and directly relevant source/tests. Do not read product docs, roadmap, previous tasks, Stage history, checkpoint reviews, or closure reviews to determine behavior.

---

## 2. Goal

Extend the Institution Admin Groups experience with:

1. a production-quality **Create Group** flow backed by:

```text
POST /api/v1/institution/groups
```

2. a production-quality **Group Detail** screen backed by:

```text
GET /api/v1/institution/groups/{group}
```

3. navigation from the delivered S04-FE-001 Group list to create/detail routes.

This task does not implement Group edit/archive or membership management.

---

## 3. Scope

### Included

- Add canonical Institution Admin routes:
  - `/institution-admin/groups/new`
  - `/institution-admin/groups/:groupId`
- Add strict route/path helpers and route classification for Group targets.
- Add `Create Group` entry points to the delivered Group list.
- Make existing Group list rows open Group Detail accessibly.
- Implement controlled Create Group form/domain/state/controller/data/repository flow.
- Implement exact create request serialization.
- Implement strict Create Group success/error parsing and uncertain-outcome handling.
- Implement safe `Review recent groups` recovery after uncertain create outcome.
- Implement Group Detail DTO/data/repository/controller/state/screen.
- Reuse the strict Group model/DTO delivered by S04-FE-001.
- Preserve normal retained Group-list query state across create/detail navigation.
- Add narrow Group-list stale/reload integration for confirmed create.
- Add focused deterministic tests and directly affected router/shell/list regressions.

### Non-goals

Do **not** implement:

- Group edit;
- Group archive;
- archive confirmation;
- Group reactivation;
- Teacher membership list/add/remove;
- Student membership list/add/remove;
- Parent–Student relationships;
- optimistic insertion into Group list;
- optimistic Group counts;
- automatic replay/retry of Group creation;
- inference of create success from Group name/search results;
- client-side Group-name uniqueness;
- Institution Dashboard invalidation for Group create;
- Group metrics on Institution Dashboard;
- backend/schema/API changes;
- dependency/package changes;
- platform-file changes;
- a second router, API client, state framework, or cache architecture;
- unrelated refactors of User create/detail/list code.

---

## 4. Current Implementation Context

S04-FE-001 establishes the Group list, strict Group resource DTO/domain model, list query/pagination flow, list controller/state, list screen, Groups route, and Groups shell destination.

Extend the established Institution Admin feature:

```text
frontend/lib/features/institution_admin/
  application/
  data/
  domain/
  presentation/
```

Reuse existing patterns only where they own the same responsibility:

- Institution User create flow:
  - controlled form;
  - strict mutation success parsing;
  - exact definite-error envelope recognition;
  - uncertain mutation outcome;
  - session/operation ownership;
  - success effect from published controller state;
- Institution User detail flow:
  - autoDispose family;
  - canonical local target guard;
  - exact target/response identity;
  - refreshing state;
  - privacy-safe 404 handling;
  - retry classification;
  - session reconciliation;
- Institution Admin router/shell conventions;
- configured Dio client and shared failure/session infrastructure;
- Institution Admin UTC presentation convention.

Do not refactor unrelated User code merely to share superficial implementation.

---

# 5. Exact Implementation Contract

## 5.1 Route names, paths, registries, and order

Add exact route names:

```text
AppRouteNames.institutionAdminGroupCreate =
    institution-admin-group-create

AppRouteNames.institutionAdminGroupDetail =
    institution-admin-group-detail
```

Add exact path constants:

```text
AppRoutePaths.institutionAdminGroupCreateSegment =
    new

AppRoutePaths.institutionAdminGroupIdParameter =
    groupId

AppRoutePaths.institutionAdminGroupCreate =
    /institution-admin/groups/new

AppRoutePaths.institutionAdminGroupDetail =
    /institution-admin/groups/:groupId
```

The Group list route remains:

```text
/institution-admin/groups
```

### Protected / approved location registries

Update the established router registries exactly:

1. Add these route templates exactly once to `AppRoutePaths.protected`:

```text
institutionAdminGroupCreate
institutionAdminGroupDetail
```

2. Do not duplicate them separately in `AppRoutePaths.all`; `all` remains composed from `auth + protected`.

3. Do **not** add create/detail to `institutionAdminPrimaryDestinations`. Only the Groups list is a primary navigation destination.

4. Add the create path to the Institution Admin static-approved location collection.

5. Add Group Detail to `isInstitutionAdminApprovedLocation(...)` through the strict dynamic Group Detail helper.

6. Keep route names and route paths globally unique.

### Strict Group UUID

Use the same canonical hyphenated UUID lexical policy as the delivered Institution User detail route:

```text
8-4-4-4-12 hexadecimal groups
case-insensitive hexadecimal
no leading/trailing whitespace
no slash
no encoded path manipulation
no query/fragment text
```

Add helpers:

```text
isInstitutionAdminGroupCreatePath(path)
isInstitutionAdminGroupDetailPath(path)
institutionAdminGroupDetailLocation(groupId)
```

`isInstitutionAdminGroupDetailPath(...)`:

- requires the exact `/institution-admin/groups/` prefix;
- excludes the static `new` segment;
- accepts one segment only;
- requires a canonical hyphenated UUID;
- does not trim input.

`institutionAdminGroupDetailLocation(groupId)`:

- validates before building;
- throws `ArgumentError` for malformed/noncanonical IDs;
- never accepts `new`;
- URI-encodes the already validated path segment.

### GoRouter declarations

Add exactly one create route and one detail route inside the **existing Institution Admin `ShellRoute`**.

Order:

```text
/institution-admin/groups
/institution-admin/groups/new
/institution-admin/groups/:groupId
```

The static create route must be declared before the dynamic detail route.

Do not create another `ShellRoute`, nested router, or Groups router family.

### Group Detail direct-entry safety

The real router must reject unsafe Group Detail entry before Group Detail data/controller work begins.

For Group Detail:

- query parameters are not allowed;
- fragments are not allowed;
- noncanonical path targets are not allowed.

Extend the established Institution Admin redirect/builder safety pattern so:

```text
valid canonical Group Detail without query/fragment
    -> Group Detail screen

Group Detail path with query/fragment
malformed/noncanonical Group target
path manipulation
    -> existing safe Institution Admin routing boundary
    -> no Group Detail provider/data request
```

Do not invent a new error route solely for this task.

### Shell mapping and titles

These locations all select:

```text
InstitutionAdminShellDestination.groups
```

Locations:

```text
/institution-admin/groups
/institution-admin/groups/new
/institution-admin/groups/<valid UUID>
```

Shell titles:

```text
/institution-admin/groups             -> Groups
/institution-admin/groups/new         -> Create Group
/institution-admin/groups/<UUID>      -> Group Details
```

---

## 5.2 Shell navigation during Group create

The existing shell already coordinates busy state for Institution User create. Extend it narrowly for Group create.

Required behavior:

```text
Institution User Create route
    -> watch only InstitutionUserCreateController busy state

Institution Group Create route
    -> watch only InstitutionGroupCreateController route-blocking state

all other Institution Admin routes
    -> do not instantiate/watch either create controller solely for navigation state
```

Group create route blocks conflicting shell navigation while:

```text
submitting
reconciling unknown outcome
terminal unknown outcome awaiting Review recent groups
```

Group create route allows normal shell navigation while:

```text
editing
local validation failure
server validation failure
other definite failure
```

Sign-out/session reconciliation remains governed by existing auth/session behavior and must not be blocked by this feature.

Normal back/pop on the Group Create route is also blocked while the route-blocking create state above is active.

---

## 5.3 S04-FE-001 Group list integration

After this task, the Group list adds:

### Header action

```text
Create Group
```

Navigate by named route to:

```text
/institution-admin/groups/new
```

### Global-empty action

When the authoritative unfiltered Group list is globally empty, show:

```text
Create Group
```

Filtered/search empty remains filter-oriented and keeps:

```text
Clear filters
```

Do not substitute a create-specific empty state for filtered results.

### Row-to-detail navigation

Each existing Group row exposes accessible detail navigation to:

```text
/institution-admin/groups/<group.id>
```

Use the established Institution Admin table convention:

- the primary visible Group name exposes an accessible action/label;
- row activation opens Group Detail;
- keyboard users can activate it;
- assistive technology can discover the detail action.

Do not add:

```text
Edit
Archive
Manage teachers
Manage students
```

to Group list rows.

### Normal retained-query behavior

Opening Create or Detail does not clear normal retained S04-FE-001 state.

For the same eligible session, preserve:

```text
search draft
committed search
status
page
perPage
sort
direction
```

Normal Cancel / Back to Groups restores that retained query and performs the normal authoritative Group-list load.

The uncertain-create recovery in Section 5.12 is the only deliberate exception.

---

## 5.4 Create Group form domain and normalization

Fields, exact order:

```text
Name
Level
Subject direction
Description
```

All text drafts preserve exactly what the user typed until request construction.

Do not silently rewrite case, punctuation, internal whitespace, or internal newlines.

### Length measurement

All defined string maximums are measured in:

```text
Unicode code points
Dart: value.runes.length
```

Do not use UTF-8 byte length or implicit UTF-16 code-unit length as the validation contract.

### Name

Rules:

```text
required
normalize for request = trim leading/trailing whitespace
normalized value must be non-empty
max = 160 Unicode code points after trim
```

Do not lowercase/title-case/collapse internal whitespace.

Safe local messages:

```text
Group name is required.
Group name must be 160 characters or fewer.
```

### Level

Rules:

```text
optional
exact UI draft "" -> JSON null
non-empty draft -> trim for request
spaces-only non-empty draft -> local error
max = 100 Unicode code points after trim
```

Safe local messages:

```text
Level must not contain only spaces.
Level must be 100 characters or fewer.
```

### Subject direction

Rules:

```text
optional
exact UI draft "" -> JSON null
non-empty draft -> trim for request
spaces-only non-empty draft -> local error
max = 160 Unicode code points after trim
```

Safe local messages:

```text
Subject direction must not contain only spaces.
Subject direction must be 160 characters or fewer.
```

### Description

Rules:

```text
optional multiline
no client-defined maximum
exact UI draft "" -> JSON null
non-empty draft -> trim only leading/trailing whitespace
spaces-only non-empty draft -> local error
preserve internal newlines
preserve internal whitespace
preserve punctuation/case
```

Safe local message:

```text
Description must not contain only spaces.
```

Description keyboard behavior:

- Enter inserts a newline;
- Enter in Description does not submit;
- submit is performed by explicit Create Group action or an equivalent dedicated form-submit shortcut that cannot conflict with multiline editing.

### Input-limit presentation

Do not truncate draft input automatically to the backend maximum.

When over a defined maximum:

- retain the user's draft;
- show the local validation error;
- do not submit.

### Duplicate names

Do not perform client-side uniqueness checks.

Multiple Groups with the same normalized name are valid.

---

## 5.5 Exact Create Group request

Use exactly:

```text
POST /institution/groups
```

The configured Dio client owns `/api/v1`, authenticated headers, JSON content type, and standard transport configuration.

No query parameters.

Send exactly one JSON object with exactly these four keys on every create request:

```json
{
  "name": "normalized required string",
  "level": null,
  "subject_direction": null,
  "description": null
}
```

Filled optional fields replace `null` with their normalized string.

Do not omit any of the four allowed keys.

Do not send:

```text
id
institution_id
status
created_by_user_id
teachers_count
students_count
archived_at
created_at
updated_at
unknown key
```

Do not send:

```text
FormData
raw JSON string
array
scalar
empty object
query parameter
tenant header/selector
```

Transport must remain:

```text
Content-Type: application/json
```

No `Idempotency-Key` exists for this endpoint.

One user submit produces at most one POST.

---

## 5.6 Create screen UX and state

Route:

```text
/institution-admin/groups/new
```

Heading:

```text
Create Group
```

Actions:

```text
Cancel
Create Group
```

### Editing / validation

- controlled deterministic form state;
- predictable focus order;
- local validation before transport;
- first invalid field receives focus;
- field errors clear/revalidate according to existing controlled-form conventions;
- duplicate submit is suppressed.

### Cancel

Cancel is available only when Group create route is not in a route-blocking state.

Cancel:

1. clears route-local create state;
2. does not invalidate Group list;
3. preserves normal retained Group-list query;
4. navigates to `/institution-admin/groups`.

No unsaved-changes confirmation is required.

### Submitting

While POST is in flight:

- fields disabled;
- Cancel disabled;
- Create disabled;
- conflicting shell navigation disabled;
- normal back/pop blocked;
- duplicate submit ignored;
- visible + semantic progress:

```text
Creating group
```

Do not use optimistic success.

### Unknown-terminal state

When create outcome becomes unknown:

- hide/disable the editable create form;
- no Retry creation;
- no Submit again;
- no Cancel;
- conflicting shell navigation remains disabled;
- normal back/pop remains blocked;
- only the safe `Review recent groups` recovery action from Section 5.12 is presented, besides auth/session-driven navigation.

---

## 5.7 Exact Create Group success response

Valid create success requires:

```text
HTTP 201 Created
```

No other 2xx is valid success.

Require exact top-level keys:

```json
{
  "data": {
    "...": "exact S04-FE-001 Group resource"
  },
  "message": "Group created successfully."
}
```

No unknown top-level key is allowed.

Require exact message:

```text
Group created successfully.
```

Parse `data` through the strict S04-FE-001 Group DTO.

The returned Group must satisfy the normalized request snapshot:

```text
returned.name == request.name
returned.level == request.level
returned.subject_direction == request.subject_direction
returned.description == request.description
```

And exact create lifecycle invariants:

```text
status == active
teachers_count == 0
students_count == 0
archived_at == null
```

The strict Group DTO already owns:

- exact Group keys;
- canonical UUID;
- UTC `Z` timestamps;
- count types/ranges;
- active/archive invariant.

Any of these makes create outcome **unknown**, not confirmed failure/success:

```text
2xx other than 201
malformed success envelope
unknown/missing success key
wrong success message
malformed Group resource
request/response snapshot mismatch
unexpected Group lifecycle/count values
response transform/parsing failure
```

---

## 5.8 Exact definite-error envelope for Create Group

A failed POST is definite only when the response has both an allowed HTTP status/code pair and an exact error envelope.

Allowed exact error envelope:

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

Only optional key:

```text
request_id
```

No other key is allowed.

Rules:

```text
message = non-blank string
code = non-empty string
request_id, if present = non-empty string
errors = JSON object
```

Each `errors` entry, when present:

```text
key = string
value = non-empty JSON array
every item = non-empty string
```

For definite non-422 responses, `errors` must be empty.

Allowed status/code pairs:

```text
401 -> authentication_required

403 -> forbidden
403 -> password_change_required
403 -> user_inactive
403 -> institution_inactive

422 -> validation_failed

429 -> rate_limited
```

Any other status/code pairing or malformed error envelope is unknown outcome after dispatch.

### 422 safe mapping

Known field keys:

```text
name
level
subject_direction
description
```

Map them only to safe local text:

```text
name              -> Review the group name.
level             -> Review the level.
subject_direction -> Review the subject direction.
description       -> Review the description.
```

Never branch on or display raw backend validation strings.

Protocol/unknown keys include, for example:

```text
body
query key
unknown/protected key
```

Rules:

- known field errors -> show corresponding safe field messages;
- any protocol/unknown key -> also show form-level:

```text
The group could not be created.
```

- empty/unusable 422 field-error set -> show the same form-level message.

### Other definite safe feedback

```text
forbidden:
You do not have permission to create groups.

rate_limited:
Too many requests. Wait before trying again.

other definite safe form failure:
The group could not be created.
```

Session-authority errors use Section 5.11.

A definite create failure does not invalidate Group list state.

---

## 5.9 Unknown create outcome

Group create is non-idempotent and duplicate Group names are allowed.

Never automatically replay POST.

Treat outcome as unknown when dispatch may have reached the server but commit success cannot be proven, including:

```text
connection interruption after dispatch
connection error with ambiguous dispatch state
timeout
Dio cancellation while the operation still owns publication
HTTP 5xx
unexpected HTTP status
unexpected 2xx other than 201
malformed/unexpected error envelope
malformed 201 success envelope
malformed/mismatched Group success resource
response transform/parsing failure
unexpected exception after dispatch
```

Do not search for a same-name Group to infer success.

Do not infer success from:

```text
name
created_at proximity
list count
one matching row
```

Unknown feedback:

```text
Group creation could not be confirmed. The request may have succeeded. Review recent groups before creating another group.
```

Expose exactly one recovery action:

```text
Review recent groups
```

No retry-submit action exists in this terminal state.

---

## 5.10 Create confirmed-success publication and navigation

On a current, owned, strictly confirmed 201 result:

1. publish create-controller state containing the confirmed `groupId`;
2. mark Group-list authoritative rows stale according to Section 5.13;
3. preserve the normal retained Group-list query/search store;
4. do **not** invalidate Institution Dashboard;
5. UI handles the confirmed-success state in a guarded post-frame/effect step:
   - clear visible create text controllers;
   - show success feedback:

```text
Group created successfully.
```

   - navigate by named route to:

```text
/institution-admin/groups/<returned Group UUID>
```

6. the Group Detail route performs its normal authoritative GET;
7. do not seed Group Detail from the POST resource;
8. route exit/autoDispose clears the create provider after the success effect has consumed `groupId`.

Do not clear/reset the confirmed-success state before the current route effect can consume its `groupId`.

A stale success completion must not:

```text
show success
clear a newer form
navigate
mark another session's state
```

---

## 5.11 Create session and async ownership

Bind a create operation to:

```text
authenticated Institution Admin user ID
exact AuthUser object instance identity
institution ID
desktop eligibility
immutable normalized request snapshot
operation generation
current create-route ownership
```

Eligibility:

```text
session authenticated
user exists
role = institution_admin
user active
must_change_password = false
user.institution_id non-empty
user.institution exists
user.institution.id == user.institution_id
institution active
desktop surface
```

Reject stale publication after:

```text
route ownership lost
logout
session/bootstrap replacement
same-role account switch
cross-role switch
institution change
user inactive
must-change-password transition
institution inactive
device/surface eligibility loss
controller dispose
superseding operation generation
```

Actual network cancellation is not required.

Session-authority server responses:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

must:

- clear create publication authority;
- clear protected create state;
- invalidate operation generation;
- use the established auth/session invalidation/bootstrap behavior;
- never show stale mutation success/failure in a later session.

`authentication_required` follows the existing central invalidation path; other authority failures bootstrap/reconcile as established by current Institution Admin flows.

---

## 5.12 Unknown-outcome recovery: Review recent groups

Normal retained Group-list query is deliberately overridden only for this recovery action.

When the current create state is unknown and the user selects:

```text
Review recent groups
```

perform exactly:

```text
searchDraft = ''
search = null
status = active
page = 1
perPage = preserve the user's retained page-size choice
sort = created_at
direction = desc
```

Then:

1. mark Group-list authoritative rows stale;
2. store the recovery query for the same current session;
3. clear route-local create editing state only after recovery intent is committed;
4. navigate to `/institution-admin/groups`;
5. Group list performs an authoritative GET using the recovery query;
6. show one-time accessible warning on the Group list:

```text
Creation result remains unconfirmed. Review recent active groups before creating another group.
```

This recovery does **not** prove create success.

Do not automatically select/open any candidate Group.

After arriving on Group list, normal Group-list interactions resume. If the user intentionally chooses Create Group again, that is a new explicit operation.

Session change clears this recovery warning/query ownership in the same way as other retained Group-list state.

---

## 5.13 Group-list stale/invalidation integration

S04-FE-002 may narrowly extend the delivered S04-FE-001 Group-list controller/state or retained-state owner.

### Confirmed create

Mark current-session Group-list authoritative rows stale.

Preserve:

```text
search draft
committed query
status
page
perPage
sort
direction
```

Do not treat previously loaded rows as authoritative after the create.

Next Groups presentation performs authoritative GET for the retained query.

### Unknown create

Use only the recovery behavior from Section 5.12.

### Cancel / definite failure

Do not invalidate Group list.

Preserve normal retained query unchanged.

### Forbidden shortcuts

Do not:

```text
optimistically insert returned Group into the list
increment pagination total locally
change server ordering locally
seed list from POST result
seed detail from POST result
invalidate/refresh Institution Dashboard
```

If FE-001 names the retained/stale APIs differently, extend that delivered owner rather than creating a parallel Group-list cache.

---

# 6. Group Detail

## 6.1 Exact API contract

Use exactly:

```text
GET /institution/groups/{groupId}
```

Path construction:

```text
canonical validated groupId
Uri.encodeComponent(groupId)
```

No query parameters.

No request body/data argument.

Valid success requires exactly:

```text
HTTP 200 OK
```

No other 2xx is valid success.

Exact success envelope:

```json
{
  "data": {
    "...": "exact S04-FE-001 Group resource"
  }
}
```

No success `message` or unknown top-level key is allowed.

Parse Group through the strict S04-FE-001 Group DTO.

After parsing:

```text
returnedGroup.id equals requested groupId case-insensitively
```

Otherwise map to:

```text
ApiFailureKind.invalidResponse
```

---

## 6.2 Detail 404 privacy contract

Only this is `not_found`:

```text
HTTP 404
code = resource_not_found
exact error envelope
errors = empty object
```

Use the exact error-envelope structural rules from Section 5.8.

The backend intentionally makes these privacy-equivalent:

```text
missing Group
cross-tenant Group
scope-hidden Group
well-formed UUID that does not resolve
```

Frontend presentation for all valid-target exact 404 cases:

```text
Group not found
The requested group is not available.
```

Do not distinguish why the resource was unavailable.

A malformed 404 envelope is:

```text
invalidResponse -> error
```

not `not_found`.

---

## 6.3 Detail target/controller ownership

Use an `autoDispose family`-style controller keyed by `groupId`.

### Router-level guard

Real navigation must already reject malformed/noncanonical detail locations before creating Group Detail screen/provider, as defined in Section 5.1.

### Controller-level defensive guard

Direct controller/widget use still validates `groupId`.

If invalid:

```text
local unavailable/not-found presentation
zero network requests
```

This exists for defensive correctness and deterministic tests; it does not replace router safety.

### Read ownership

Bind reads to:

```text
target Group UUID
session user ID
exact AuthUser instance identity
institution ID
desktop eligibility
operation generation
current target
```

Suppress duplicate same-target in-flight GET.

Reject stale completion after:

```text
target change
superseding refresh/retry
dispose
session/user/institution change
desktop eligibility loss
operation generation change
```

---

## 6.4 Detail states

Required states:

```text
initial
loading
data
refreshing
not_found
error
```

Initial/loading semantic text:

```text
Loading group
```

### Refresh

Refresh is available only from confirmed data and is duplicate-protected.

While refresh is in flight:

- retain the currently confirmed Group visibly;
- expose visible + semantic refreshing progress;
- disable duplicate Refresh.

Refresh result:

```text
200 valid Group
    -> replace with authoritative Group

exact 404 resource_not_found
    -> discard prior Group
    -> not_found

session-authority failure
    -> discard prior Group
    -> clear detail authority
    -> auth/session reconciliation

any other failure
    -> discard prior Group
    -> error
```

Do not leave stale Group data presented as confirmed after refresh failure.

### Retry

Retry exists only from `error` when the failure is retryable.

Retry starts a fresh detail load and does not keep failed/stale Group data as authoritative.

Retryable only:

```text
connection
timeout
ApiFailureKind.unknown
server failure with HTTP >= 500
```

Non-retryable:

```text
invalidResponse
validation
forbidden
rate-limit
exact not-found
other non-5xx server failure
```

No automatic retry.

### Session authority

These clear detail authority and use existing auth/session reconciliation:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

---

## 6.5 Detail UI

Route:

```text
/institution-admin/groups/<groupId>
```

Shell title:

```text
Group Details
```

Toolbar actions in this task:

```text
Back to Groups
Refresh
```

Do not show:

```text
Edit
Archive
Reactivate
Manage teachers
Manage students
membership lists
```

Heading after data load may show Group name.

Display authoritative fields:

```text
Name
Status
Level
Subject direction
Description
Teachers
Students
Archived at
Created
Updated
```

Display rules:

```text
status active   -> Active
status archived -> Archived
```

Status must not be color-only.

Nulls:

```text
level             -> Not provided
subject_direction -> Not provided
description       -> Not provided
active archived_at -> —
```

Archived Group displays its archived timestamp.

Teacher/student counts are shown exactly as returned.

All timestamps shown with exact Institution Admin presentation format:

```text
YYYY-MM-DD HH:mm UTC
```

Long name/description/subject values wrap/constrain safely without desktop overflow.

No membership endpoint is called by Group Detail in this task.

---

## 6.6 Back navigation and normal list retention

Actions:

```text
Create Cancel
Group Detail Back to Groups
normal route return
```

navigate to:

```text
/institution-admin/groups
```

and preserve normal same-session Group-list retained query.

Group Detail itself does not invalidate Group list merely by loading/refreshing.

Unknown-create `Review recent groups` uses the deliberate recovery override from Section 5.12.

---

# 7. Accessibility / Keyboard / Responsiveness

## Create

Required:

- deterministic focus traversal;
- labels attached to fields;
- semantic field errors;
- first invalid field focus;
- multiline Description supports Enter/newline;
- duplicate submit impossible;
- visible + semantic submitting progress;
- route-blocking state is semantically apparent;
- Cancel/Create disabled correctly;
- unknown warning is a live region;
- `Review recent groups` is keyboard reachable;
- text scaling and supported desktop widths do not overflow.

## Group list integration

Required:

- Create Group is keyboard reachable;
- global-empty Create Group is discoverable;
- Group name/detail action has accessible semantics;
- keyboard activation opens detail;
- no action relies on color alone.

## Detail

Required:

- Back/Refresh keyboard reachable;
- heading semantic;
- loading/refresh live progress;
- not-found/error readable by assistive technology;
- labels/values usable with text scaling;
- long content wraps;
- narrow supported desktop layout does not RenderFlex overflow.

Do not introduce a new design system or breakpoint architecture.

---

# 8. Security / Tenant Isolation / Persistence

Eligible frontend context remains exactly:

```text
authenticated
role = institution_admin
active user
must_change_password = false
active own institution
desktop surface
```

Create request must never send:

```text
institution_id
created_by_user_id
tenant selector
status override
membership IDs
```

Group Detail UUID is only a requested resource identifier and never expands tenant scope.

Backend remains authoritative for tenant isolation and existence privacy.

UI route guards are UX, not authorization.

Do not add create/detail access to:

```text
Platform Owner
Teacher
Student
Parent
mobile/unsupported Institution Admin surface
```

Persistence/schema:

```text
N/A — frontend task
```

Client-authoritative lifecycle:

```text
N/A — backend owns lifecycle
```

Create idempotency:

```text
No Idempotency-Key contract
No automatic replay
Unknown result remains unconfirmed
```

Optimistic authoritative state:

```text
Not allowed
```

---

# 9. Architecture and Placement

Responsibility flow:

```text
Presentation
  -> Application / Controller
  -> Repository contract
  -> Repository implementation
  -> Remote data source / DTO
  -> configured Dio
```

### Create domain owns

- form value;
- normalized immutable create snapshot;
- field enum/request-key mapping;
- local validation;
- exact request JSON object;
- unknown-outcome marker/type if needed.

### Create data layer owns

- POST method/path/body;
- exact HTTP status;
- exact success envelope;
- exact definite-error envelope recognition;
- conversion of ambiguous transport/protocol results to unknown outcome.

### Create controller owns

- eligible session;
- mutation generation;
- duplicate suppression;
- field/form safe error publication;
- confirmed success state;
- unknown terminal state;
- Group-list stale/recovery intent;
- no UI navigation side-effect directly if established project pattern publishes state for UI effect.

### Detail data/repository owns

- exact GET transport;
- exact detail envelope;
- strict Group DTO reuse;
- exact 404 recognition;
- target/response identity verification.

### Detail controller owns

- target/session ownership;
- loading/refresh/error/not-found states;
- duplicate suppression;
- stale completion rejection;
- retry classification;
- session reconciliation trigger.

### Widgets own only

- rendering;
- input;
- focus;
- navigation effects from current owned controller state;
- semantics;
- presentation formatting.

No raw Dio/API path/JSON parsing in Widgets.

No dashboard integration is added.

---

# 10. Expected Files / Areas

Reuse delivered S04-FE-001 Group files wherever they already own the responsibility.

Expected new production files may include:

```text
frontend/lib/features/institution_admin/domain/institution_group_create.dart
frontend/lib/features/institution_admin/domain/institution_group_create_repository.dart
frontend/lib/features/institution_admin/domain/institution_group_detail_repository.dart

frontend/lib/features/institution_admin/data/dto/institution_group_create_dto.dart
frontend/lib/features/institution_admin/data/dto/institution_group_detail_dto.dart
frontend/lib/features/institution_admin/data/institution_group_create_remote_data_source.dart
frontend/lib/features/institution_admin/data/institution_group_create_repository_impl.dart
frontend/lib/features/institution_admin/data/institution_group_detail_remote_data_source.dart
frontend/lib/features/institution_admin/data/institution_group_detail_repository_impl.dart

frontend/lib/features/institution_admin/application/institution_group_create_controller.dart
frontend/lib/features/institution_admin/application/institution_group_create_state.dart
frontend/lib/features/institution_admin/application/institution_group_detail_controller.dart
frontend/lib/features/institution_admin/application/institution_group_detail_state.dart

frontend/lib/features/institution_admin/presentation/institution_admin_group_create_screen.dart
frontend/lib/features/institution_admin/presentation/institution_admin_group_detail_screen.dart
frontend/lib/features/institution_admin/presentation/institution_admin_group_formatters.dart
```

Modify as required:

```text
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
frontend/lib/features/institution_admin/presentation/institution_admin_shell.dart
frontend/lib/features/institution_admin/presentation/institution_admin_groups_screen.dart

frontend/lib/features/institution_admin/application/institution_group_list_controller.dart
frontend/lib/features/institution_admin/application/institution_group_list_state.dart
```

If S04-FE-001 delivered equivalent filenames/placement with different names, extend those actual files instead of duplicating them.

Do not refactor `institution_admin_user_formatters.dart` into shared infrastructure merely to format Group timestamps. A small Group-local formatter is allowed when needed.

Expected focused tests:

```text
frontend/test/features/institution_admin/institution_group_create_domain_test.dart
frontend/test/features/institution_admin/institution_group_create_dto_test.dart
frontend/test/features/institution_admin/institution_group_create_remote_data_source_test.dart
frontend/test/features/institution_admin/institution_group_create_repository_impl_test.dart
frontend/test/features/institution_admin/institution_group_create_controller_test.dart

frontend/test/features/institution_admin/institution_group_detail_dto_test.dart
frontend/test/features/institution_admin/institution_group_detail_remote_data_source_test.dart
frontend/test/features/institution_admin/institution_group_detail_repository_impl_test.dart
frontend/test/features/institution_admin/institution_group_detail_controller_test.dart

frontend/test/features/institution_admin/institution_admin_group_create_screen_test.dart
frontend/test/features/institution_admin/institution_admin_group_detail_screen_test.dart
frontend/test/features/institution_admin/institution_admin_groups_screen_test.dart
```

Directly affected router/shell tests:

```text
frontend/test/app/router/institution_admin_route_paths_test.dart
frontend/test/features/institution_admin/institution_admin_shell_test.dart
```

Changes outside these areas require a concrete in-scope necessity and must be reported.

Forbidden:

```text
backend/
docs/
unrelated task files
unrelated features
pubspec.yaml
pubspec.lock
frontend/android/
frontend/ios/
frontend/windows/
frontend/linux/
frontend/macos/
frontend/web/
```

---

# 11. Acceptance Criteria

- [ ] S04-FE-001 is Accepted / Delivered on synchronized `origin/main` before implementation starts.
- [ ] Exact create/detail route names, constants, templates, helpers, registries, and GoRoutes are implemented.
- [ ] Static `new` precedes dynamic detail and can never be treated as a UUID.
- [ ] Group Detail query/fragment/malformed direct entry cannot instantiate Detail data work.
- [ ] List/create/detail all select Groups shell destination with exact page titles.
- [ ] Group Create route disables conflicting shell navigation/back while route-blocking create states are active without breaking User Create behavior.
- [ ] Group list exposes Create Group in header/global-empty and accessible row detail navigation.
- [ ] Normal list retained query survives create/detail navigation.
- [ ] Name/Level/Subject limits use Unicode code points and exact normalization.
- [ ] Optional empty/spaces-only behavior matches contract.
- [ ] Description is multiline and preserves internal newlines/whitespace.
- [ ] Create sends exact four-key JSON object, no query, no tenant/protected fields.
- [ ] Duplicate Group names are never rejected locally.
- [ ] Only exact 201 `{data,message}` + snapshot/lifecycle invariants is confirmed create success.
- [ ] Exact definite-error envelope/status-code pairing is enforced.
- [ ] Mixed 422 known/protocol fields map safely.
- [ ] Ambiguous create outcomes never replay and expose only Review recent groups.
- [ ] Unknown recovery loads page 1 active Groups sorted `created_at desc` and remains explicitly unconfirmed.
- [ ] Confirmed create marks Group list stale without changing retained query and without dashboard invalidation.
- [ ] Cancel/definite failure do not invalidate Group list.
- [ ] Success state is consumed safely before create-provider reset and navigates to authoritative Detail GET.
- [ ] Detail sends exact bodyless/queryless GET and accepts only HTTP 200.
- [ ] Detail exact `{data}` parsing and requested-ID identity are enforced.
- [ ] Only exact 404 `resource_not_found` becomes privacy-safe not-found.
- [ ] Malformed 404 is invalidResponse/error.
- [ ] Detail refresh failures discard stale prior Group according to exact failure rules.
- [ ] Stale create/detail completions cannot publish across route/session/institution/device/target boundaries.
- [ ] No edit/archive/reactivate/membership behavior is introduced.
- [ ] Exact UTC presentation is `YYYY-MM-DD HH:mm UTC`.
- [ ] Accessibility/keyboard/responsive requirements pass.
- [ ] No backend/schema/dependency/dashboard/public API change.
- [ ] Focused verification and directly affected regressions pass.
- [ ] `git diff --check` passes.
- [ ] Final diff contains no unrelated work.

---

# 12. Tests and Verification

Run Flutter/Dart commands from `frontend/`.

## 12.1 Focused tests

From repository root:

```powershell
Push-Location frontend

fvm spawn 3.44.7 test `
  test/features/institution_admin/institution_group_create_domain_test.dart `
  test/features/institution_admin/institution_group_create_dto_test.dart `
  test/features/institution_admin/institution_group_create_remote_data_source_test.dart `
  test/features/institution_admin/institution_group_create_repository_impl_test.dart `
  test/features/institution_admin/institution_group_create_controller_test.dart `
  test/features/institution_admin/institution_group_detail_dto_test.dart `
  test/features/institution_admin/institution_group_detail_remote_data_source_test.dart `
  test/features/institution_admin/institution_group_detail_repository_impl_test.dart `
  test/features/institution_admin/institution_group_detail_controller_test.dart `
  test/features/institution_admin/institution_admin_group_create_screen_test.dart `
  test/features/institution_admin/institution_admin_group_detail_screen_test.dart `
  test/features/institution_admin/institution_admin_groups_screen_test.dart

Pop-Location
```

If S04-FE-001 delivered equivalent test responsibilities under slightly different filenames, use the real delivered paths rather than creating duplicates solely to satisfy names; report the exact focused command.

Required focused coverage includes:

### Routes/shell

- exact names/segments/templates/parameter;
- protected/static/dynamic approved-location classification;
- `new` before dynamic detail;
- valid lower/upper canonical UUIDs;
- malformed/whitespace/slash/query/fragment/path-manipulation rejection;
- Groups selected destination/title for list/create/detail;
- Group Create route-blocking state disables shell navigation;
- editing/definite-failure re-enable navigation;
- existing User Create busy behavior remains unchanged.

### Create domain/request

- default form;
- name trim/required/160 rune boundary;
- level 100-rune boundary;
- subject 160-rune boundary;
- empty optional -> null;
- spaces-only optional error;
- multiline Description preserves internal newlines;
- exact four-key request JSON;
- duplicate names allowed.

### Create DTO/data/repository

- exact POST path;
- exact JSON object;
- no query;
- exact 201 only;
- exact `{data,message}`;
- exact message;
- strict Group DTO reuse;
- snapshot/status/count/archive invariants;
- exact definite error envelope;
- exact status/code pair rules;
- mixed 422 safe mapping inputs;
- connection/timeout/cancel/5xx/unexpected status/malformed response -> unknown;
- malformed/mismatched 201 -> unknown;
- no automatic replay.

### Create controller/UI

- eligibility/session ownership;
- first invalid field;
- duplicate submit suppression;
- route-blocking states;
- confirmed-success publication before navigation effect;
- no dashboard invalidation;
- confirmed list stale retention;
- unknown terminal warning;
- Review recent groups exact recovery query;
- recovery one-time warning;
- no retry-submit in unknown state;
- stale route/session/institution/device completion rejection.

### Detail DTO/data/repository

- canonical target validation;
- exact GET path;
- no query/body;
- HTTP 200 only;
- exact `{data}`;
- strict Group DTO;
- returned ID matches requested ID;
- exact 404 resource_not_found recognition;
- malformed 404 -> invalidResponse;
- malformed success -> invalidResponse.

### Detail controller/UI

- invalid direct controller ID -> zero network;
- initial/load/data;
- refresh retains data only while request active;
- successful refresh replacement;
- refresh 404 discards data -> not_found;
- refresh session failure discards data -> reconcile;
- refresh other error discards data -> error;
- duplicate request suppression;
- retry classification;
- stale target/session/institution/device/dispose rejection;
- exact fields/counts/timestamps/null display;
- no edit/archive/membership actions;
- accessibility/text scale/overflow.

## 12.2 Directly affected regression

From repository root:

```powershell
Push-Location frontend

fvm spawn 3.44.7 test `
  test/app/router/institution_admin_route_paths_test.dart `
  test/features/institution_admin/institution_admin_shell_test.dart

Pop-Location
```

Also include the actual delivered S04-FE-001 Group query/controller/list focused test files in the focused command if FE-002 modifies them for stale/recovery behavior.

Required regression evidence:

- S04-FE-001 search/filter/sort/page behavior remains intact;
- normal retained query still works;
- confirmed create stale reload does not alter retained query;
- unknown recovery uses only its deliberate recent-active query override;
- route registries stay unique/consistent;
- User create/detail routes remain unchanged;
- User Create shell busy lock still works.

## 12.3 Static analysis

```powershell
Push-Location frontend
fvm spawn 3.44.7 analyze
Pop-Location
```

## 12.4 Format check

```powershell
Push-Location frontend

C:\Users\Administrator\fvm\versions\3.44.7\bin\cache\dart-sdk\bin\dart.exe `
  format --output=none --set-exit-if-changed lib test

Pop-Location
```

## 12.5 Manual check

```text
Not required — deterministic router/domain/data/controller/widget tests cover this
task. Real-stack/Windows E2E belongs to Stage 4 integration/checkpoint workflow.
```

## 12.6 Always

From repository root:

```powershell
git diff --check
```

Then inspect the complete diff for:

- exact FE-002 scope;
- no dashboard invalidation;
- exact route ordering/classification;
- no raw JSON/Dio in Widgets;
- no optimistic authoritative Group state;
- no automatic create replay;
- unknown-outcome recovery remains explicitly unconfirmed;
- Group-list retained state is not corrupted;
- detail target identity and privacy-safe 404 are strict;
- stale async/session/route/target completion cannot publish;
- no unrelated refactor/format churn;
- no weakened tests;
- no debug output/secrets/temp artifacts.

Do **not** run:

```text
full frontend test suite
Windows build
broad E2E
Frontend Phase 2
Stage integration
```

for this implementation task.

If implementation necessarily requires unapproved shared scope with material regression risk outside this contract, return `BLOCKED` instead of silently broadening work.

---

# 13. Delivery

Mode:

```text
Implementation + GitHub delivery
```

Branch:

```text
task/s04-fe-002-group-create-detail
```

Commit:

```text
feat(frontend): add group create and detail
```

PR:

```text
focused PR to main
```

Allowed task/Stage bookkeeping changes:

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

If implementation and required verification pass but safe GitHub delivery cannot complete:

```text
DELIVERY BLOCKED
```

---

# 14. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to rediscover or reinterpret requirements.

| Source/reference | Decision already encoded above |
|---|---|
| Current Stage 4 Group routes/controller | Exact POST/GET endpoints and auth middleware boundary |
| Current `InstitutionGroupCreateRequest` | Four allowed fields, JSON object, no query, trimming, nullable/empty/max rules |
| Current `CreateInstitutionGroup` | Tenant/creator/status/archive authority and zero initial membership counts |
| Current `InstitutionGroupResource` | Exact public Group resource and UTC timestamp shape |
| Current Group backend tests | Duplicate-name behavior, exact create response, strict transport, privacy-safe detail 404 |
| Current Institution Dashboard action/domain | Dashboard contains only teacher/student/parent counts; Group create must not invalidate it |
| Delivered S04-FE-001 contract/implementation | Group list/read model, retained query, strict Group DTO, Groups shell destination |
| Current Institution User create flow | Exact error envelope, unknown mutation outcome, session ownership, UI success-effect pattern |
| Current Institution User detail flow | Family target ownership, exact 404, retry classification, target-response identity |
| Current router/shell | Existing Institution Admin route registries, dynamic-route safety, create busy-navigation pattern |
| `frontend/AGENTS.md` | Feature-first placement, DTO strictness, mutation uncertainty, stale async, accessibility |

---

# 15. Codex Final Report

Return concise evidence:

1. **Status:** `ACCEPTED`, `BLOCKED`, or `DELIVERY BLOCKED`.
2. Implementation summary.
3. Changed files and purpose.
4. Acceptance-criteria evidence.
5. Exact focused verification commands/results.
6. Route-registry/order/query-fragment/shell-busy evidence.
7. Create request/DTO/error-envelope evidence.
8. Unknown-outcome/no-replay/recent-group-recovery evidence.
9. Group-list stale/retained-query/no-dashboard evidence.
10. Detail exact-GET/target-identity/privacy-safe-404/refresh evidence.
11. Session/tenant/stale-async evidence.
12. Accessibility/responsive evidence.
13. `git diff --check` + focused scope/diff self-review.
14. Commit/PR/merge/main-sync evidence.
15. Exact deviations/blockers.

If any required product, architecture, API, security, tenant, lifecycle, routing, mutation-outcome, async-ownership, or UX decision is missing or conflicts with the delivered S04-FE-001 implementation/current source, return:

```text
BLOCKED
```

instead of inventing behavior.
