# S05-FE-002 — Teacher Topic Create, Detail, Edit and Lifecycle

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S05-FE-002` |
| Stage | `Stage 5 — Topics and Learning Materials` |
| Area | `Frontend` |
| Status | `Accepted` |
| Depends on | `S05-FE-001 Accepted / Delivered` |
| Planning/readiness baseline | `origin/main @ a407cf9250357f7d4a674da806a52f469476ba51` |
| Implementation baseline | `origin/main @ 36204ebaff2f0084c42b14c4285351091d59fa9f` |
| Backend gate | `S05-BE-001…005 Accepted / Delivered; Backend Phase 2 PASS` |
| Verification model | `Workflow v3 — Lean Verification` |
| Approved new dependency | `timezone: ^0.11.1` |
| Delivery | `Delivered — PR #118` |
| Delivered merge | `cfa6b9cb1981ea5c3e5416cf6e343319718044fb` |
| Acceptance review | `PASS — P1=0, P2=0, P3=0` |

This file is the complete implementation contract for `S05-FE-002`.

Codex must read only:

1. this task;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. directly relevant frontend source/tests needed to implement this task.

Codex must not read product specifications, roadmap files, Stage history,
previous task files, checkpoint reviews, closure reviews, or architecture/API
documents to rediscover requirements.

### Mandatory implementation-entry gate

This contract may be prepared and stored before `S05-FE-001` implementation,
but Codex must **not** implement it until orchestration has confirmed:

```text
S05-FE-001 = Accepted / Delivered
current origin/main re-checked
actual FE-001 Teacher feature/routes/providers/tests inspected
this contract still matches current implementation
clean synchronized local main
```

If the delivered FE-001 implementation materially conflicts with names or
structure assumed by this contract, preserve the behavior below and adapt only
the local implementation wiring. Do not invent product/API/security behavior.

---

## 2. Goal

Extend the Stage 5 Teacher workspace with production-quality Topic authoring and
lifecycle UI.

An authenticated Teacher must be able to:

### Desktop

- create a draft Topic for a currently assigned active Group;
- open Topic detail;
- edit allowed Topic metadata while the backend permits editing;
- activate an eligible draft Topic;
- close an active Topic;
- archive a draft or closed Topic;
- see authoritative server state after every mutation.

### Mobile

- open Topic detail;
- read Topic metadata, Group, lesson time and lifecycle status;
- return to the Teacher workspace.

Mobile does not perform Topic authoring or lifecycle mutations in this task.

The Laravel backend remains authoritative for Institution scope, Teacher
ownership, current Group membership, editability, lifecycle, activation
readiness, and existence privacy.

---

## 3. Scope

### Included

- Teacher Topic create route/screen on desktop.
- Teacher Topic detail route/screen on desktop and mobile.
- Teacher Topic edit route/screen on desktop.
- Topic activation/close/archive controls on desktop.
- Searchable paginated assigned-Group picker for Topic creation.
- Institution-timezone-aware `lesson_at` input/display.
- Strict mutation/detail DTO parsing using the FE-001 Teacher Topic model.
- Form validation and server validation mapping.
- Dirty-form protection.
- Mutation outcome reconciliation.
- FE-001 Topic-list invalidation/stale reconciliation after mutations.
- Existing auth/session/stale-async guarantees.
- Focused tests and directly affected routing regressions.
- Add approved dependency `timezone: ^0.11.1`.

### Explicit non-goals

Do not implement:

- Learning Material list/upload/replace/rename/remove/download/open;
- a material-count API or speculative material cache;
- Student UI;
- Homework or Blitz UI;
- Topic hard delete;
- changing Topic Group after creation;
- changing Topic Teacher or Institution;
- arbitrary client-side status assignment;
- mobile Topic create/edit/lifecycle controls;
- new backend endpoints or backend changes;
- a second router or Teacher shell;
- a second Topic/Group DTO hierarchy if FE-001 already provides one;
- `flutter_timezone`;
- `intl`;
- any package besides the approved `timezone` dependency;
- full frontend regression suite;
- Windows/Android build;
- real-stack/E2E.

---

## 4. Reuse Contract

After FE-001 delivery, reuse its Teacher feature and shared models/data layer.

Expected logical structure:

```text
frontend/lib/features/teacher/
  application/
  data/
  domain/
  presentation/
```

Reuse the existing project infrastructure:

```text
GoRouter
Riverpod
configured Dio client
DioFailureMapper
ApiFailure
ApiRequestException
ApiErrorCodes
AuthSessionController
SessionInvalidationSignal
AppDeviceSurface
```

Reuse FE-001:

```text
Teacher Group model/query/repository/data source
Teacher Topic model/DTO
Teacher Topic-list controller/state/repository where applicable
Teacher session ownership rules
```

Do not duplicate the Group or Topic API layer merely for create/detail/edit.

Mutation/detail responsibilities must still follow:

```text
Presentation
→ Controller / State
→ Repository contract
→ Repository implementation
→ Remote data source
→ configured Dio
```

Widgets must not call Dio directly or parse raw API JSON.

---

# 5. Routing Contract

Keep the existing Teacher workspace route:

```text
/teacher
```

Add canonical routes:

```text
/teacher/topics/new
/teacher/topics/:topicId
/teacher/topics/:topicId/edit
```

Suggested route names:

```text
teacher-topic-create
teacher-topic-detail
teacher-topic-edit
```

Use the existing route registry conventions and globally unique names.

Register `/teacher/topics/new` so that the literal `new` path cannot be consumed
as `:topicId`.

Do not create a new `ShellRoute`.

## 5.1 Route helper and redirect contract

Extend the existing route registry with focused Teacher helpers equivalent to:

```text
teacherTopicsSegment
teacherTopicCreateSegment
teacherTopicEditSegment
teacherTopicIdParameter

isTeacherTopicCreatePath
isTeacherTopicDetailPath
isTeacherTopicEditPath
isTeacherApprovedLocation
isTeacherSegment

teacherTopicDetailLocation
teacherTopicEditLocation
```

The Topic route parameter must be a canonical hyphenated UUID.

The router/auth redirect must recognize valid Teacher child locations rather
than treating every location other than exact `/teacher` as invalid.

Required redirect behavior:

```text
authenticated Teacher + desktop:
  /teacher
  /teacher/topics/new
  /teacher/topics/<uuid>
  /teacher/topics/<uuid>/edit
  → allowed

authenticated Teacher + mobile:
  /teacher
  /teacher/topics/<uuid>
  → allowed

  /teacher/topics/new
  → /teacher

  /teacher/topics/<uuid>/edit
  → /teacher/topics/<uuid>

invalid /teacher child location
invalid Topic UUID
extra child segment
query or fragment on create/detail/edit route
→ /teacher
```

A valid Teacher Topic deep link must be retained safely through auth bootstrap,
using the existing `_keepsLocationDuringBootstrap`/equivalent router mechanism.
Do not reset a valid deep link to `/` merely because session bootstrap is still
running.

An invalid route target must be rejected before a Topic API request is issued.

Register the literal `new` route before/independently from the dynamic Topic ID
route so it cannot be interpreted as an ID.

## 5.2 Device behavior

### Desktop Teacher

```text
/teacher/topics/new           → Topic Create
/teacher/topics/:topicId      → Topic Detail
/teacher/topics/:topicId/edit → Topic Edit
```

### Mobile Teacher

```text
/teacher/topics/:topicId      → Topic Detail
```

Mobile navigation to:

```text
/teacher/topics/new
/teacher/topics/:topicId/edit
```

must resolve safely to the supported Teacher destination:

```text
create attempt → /teacher
edit attempt   → /teacher/topics/:topicId
```

Do not render a transient desktop authoring form on mobile before redirect.

Role/device authorization remains controlled by the existing router/session
model. Viewport width changes layout only; it never grants a role/device
capability.

## 5.3 FE-001 workspace integration

After FE-002 is implemented:

- desktop Teacher workspace exposes an actionable `Create Topic` control;
- Topic cards/rows open Topic Detail on desktop and mobile;
- FE-001 list filters/query behavior otherwise remains unchanged.

---

# 6. Approved Timezone Dependency

Add exactly:

```yaml
timezone: ^0.11.1
```

to normal Flutter dependencies.

Use the package's full bundled IANA database:

```dart
package:timezone/data/latest_all.dart
package:timezone/timezone.dart
```

Do not add `flutter_timezone`. Device timezone is not authoritative.

Time-zone initialization must be idempotent and centralized in a small focused
support/helper used by Teacher Topic date handling. Do not create a general
date/time framework.

The authoritative IANA identifier comes from the current authenticated session:

```text
session.user.institution.timezone
```

If the session timezone cannot be resolved by the bundled database, do not
guess a fallback timezone and do not use the device timezone. Treat Topic
authoring date conversion as unavailable and show a safe error.

Backend validation remains final authority.

## 6.1 Shared Institution-time boundary

Because the already-approved `S05-FE-004` Student experience must display the
same educational timestamps, the timezone database/bootstrap and generic
Institution-time conversion logic are confirmed shared infrastructure, not a
Teacher-only concern.

Create one small focused reusable boundary under a neutral location such as:

```text
frontend/lib/core/time/
  institution_timezone.dart
```

Equivalent focused naming is acceptable.

That shared boundary may own only:

```text
idempotent timezone-data initialization
resolve an IANA location from an authenticated Institution timezone string
UTC instant → Institution-local wall-clock conversion
Institution-local wall-clock → RFC 3339 numeric-offset serialization
DST gap validation needed by the approved contract
```

Teacher-specific form state, validation messages, and Topic authoring remain
inside `features/teacher`.

Do not place the reusable timezone database/conversion implementation only under
`features/teacher`, because FE-004 must reuse it without cross-feature imports or
later extraction.

Do not turn this into a general scheduling/business-time framework.

---

# 7. Institution-Time `lesson_at` Contract

Teacher educational date/time is entered and displayed in the authenticated
Institution timezone.

The server returns Topic `lesson_at` as UTC `...Z`.

The client sends create/edit `lesson_at` as RFC 3339 with an explicit numeric
offset valid for the Institution IANA timezone.

Example:

```text
Institution timezone: Asia/Tashkent
Teacher selects:       2026-08-25 09:00
Request:               2026-08-25T09:00:00+05:00
Server resource:       2026-08-25T04:00:00Z
Display:               2026-08-25 09:00
```

## 7.1 Input UX

Use Flutter's existing date/time selection facilities. No third-party picker is
required.

The form owns either:

```text
lesson_at = null
```

or one complete local wall-clock selection:

```text
date + time
```

Use second:

```text
00
```

for picker-created values.

Provide an explicit Clear action.

## 7.2 Serialization

For a non-null local selection:

1. resolve `session.user.institution.timezone`;
2. construct a `TZDateTime` in that location;
3. verify its resulting local components exactly equal the selected local
   components;
4. if they do not match, the local time is invalid/nonexistent (for example a
   DST spring-forward gap) and must not be submitted;
5. serialize:
   - `YYYY-MM-DD`
   - `T`
   - `HH:mm:ss`
   - exact numeric offset `±HH:mm`.

Never send:

```text
device-local offset
timezone abbreviation
timezone name in lesson_at
UTC Z for Teacher-entered lesson_at
local date-time without offset
```

An ambiguous fall-back wall-clock may use the deterministic valid occurrence
resolved by the approved timezone package; the generated numeric offset must be
sent and the backend revalidates it.

## 7.3 Display / edit loading

For server `lesson_at`:

1. strictly parse the UTC timestamp using the FE-001 Topic DTO;
2. convert that instant into the current Institution IANA timezone;
3. display the Institution-local date/time.

Edit form initialization uses this converted Institution-local wall-clock.

Do not use `DateTime.toLocal()` for educational Topic time.

---

# 8. Topic Create

Endpoint:

```text
POST /teacher/topics
```

Configured Dio base URL already owns `/api/v1`.

Expected success:

```text
201 Created
```

Expected exact top-level success shape:

```json
{
  "data": { "...exact Teacher Topic resource..." },
  "message": "Topic created successfully."
}
```

Any unexpected success status, malformed envelope, malformed Topic resource, or
unexpected success message is not a confirmed create success.

## 8.1 Create payload

Send exactly:

```text
group_id
title
description
subject
student_instructions
lesson_at
```

Recommended normalized JSON shape:

```json
{
  "group_id": "uuid",
  "title": "Internet Basics",
  "description": null,
  "subject": "Informatics",
  "student_instructions": "Study the materials.",
  "lesson_at": "2026-08-25T09:00:00+05:00"
}
```

`lesson_at` may be `null`.

Do not send:

```text
institution_id
teacher_id
status
activated_at
closed_at
archived_at
created_at
updated_at
materials
```

No query parameters.

## 8.2 Local validation

### Group

Required.

Must come from the current assigned active Group picker.

### Title

```text
trim
required
non-empty
max 255 Unicode code points
```

### Subject

```text
trim
required
non-empty
max 160 Unicode code points
```

### Student instructions

```text
trim
required
non-empty
multiline
```

### Description

```text
optional
multiline
blank after normalization → null
otherwise preserve content
```

### Lesson date/time

Optional.

When non-null it must pass the Institution timezone conversion contract from
Section 7.

Local validation improves UX only. Backend validation remains authoritative.

## 8.3 Assigned Group picker

Do not use a dropdown that assumes all Groups fit in one response.

Implement a single-select searchable paginated picker backed by the FE-001
Teacher Group repository/query.

Use:

```text
GET /teacher/groups
search
page
per_page = 20
sort = name
direction = asc
```

Search behavior reuses FE-001 normalization:

```text
trim
blank → null
max 254 Unicode code points
300 ms debounce
Enter/Search commits immediately
```

Provide Previous/Next pagination.

Selection persists while paging/searching inside the picker.

The selected Group is shown in the create form after picker close.

If submit returns:

```text
404 resource_not_found
```

for a previously selected Group:

- do not disclose why the Group became unavailable;
- clear the selected Group;
- refresh/reopen current assigned Groups safely;
- show:

```text
Selected group is no longer available.
```

Do not automatically submit again.

---

# 9. Create Mutation Outcome Semantics

Create has a server-generated Topic UUID and no idempotency key.

Therefore a request that may have reached the server but whose success cannot be
confirmed must **never be automatically repeated**.

Treat as `outcome unknown` when, after request dispatch, any of these prevents a
trusted result:

- connection interruption;
- timeout;
- unexpected/malformed success response;
- unexpected status/error pairing where commit state cannot be proven;
- other transport ambiguity.

Do not label the create as failed when the server may already have committed it.

Show:

```text
Creation outcome unknown
The Topic creation request may have succeeded. Review recent Topics before creating another Topic.
```

Provide:

```text
Review Topics
```

Recovery behavior:

- preserve the submitted Group ID for recovery context;
- mark FE-001 Topic list authoritative data stale;
- prepare the workspace Topic query for:
  - `group_id = submitted group_id`;
  - `status = draft`;
  - `search = null`;
  - `page = 1`;
  - `per_page = 20`;
  - `sort = created_at`;
  - `direction = desc`;
- navigate to `/teacher`;
- show a one-time non-sensitive recovery notice.

If the Group is no longer readable, FE-001's selected-Group `404`
reconciliation handles that filter safely.

Do not provide a `Retry create` button from the unknown state.

## 9.1 Confirmed create

On confirmed `201`:

- mark/invalidate FE-001 Topic list data;
- navigate to `/teacher/topics/{createdId}`;
- show success feedback once.

Do not append a speculative local list row as authoritative data.

---

# 10. Topic Detail

Endpoint:

```text
GET /teacher/topics/{topicId}
```

Expected success:

```text
200
{
  "data": { "...exact Teacher Topic resource..." }
}
```

Send:

```text
no body
no query parameters
```

Use the FE-001 strict Teacher Topic DTO/domain model.

The requested canonical Topic ID and returned Topic ID must match.

## 10.1 Detail content

Desktop and mobile show at minimum:

```text
title
subject
status
Group name
Group level when present
Group subject direction when present
Group status
description when present
student_instructions
lesson_at in Institution timezone when present
created_at
updated_at
lifecycle timestamps when applicable
```

Do not expose raw UUIDs as primary user-facing labels except where useful for
technical diagnostics is already an approved project pattern. Never expose
Institution/Teacher IDs or storage metadata.

## 10.2 Detail load states

Support:

```text
loading
data
refreshing with existing data retained
not found
error + retry
```

`404 resource_not_found` is a generic unavailable Topic state. Do not explain
whether the Topic is foreign, owned by another Teacher, unassigned, deleted, or
otherwise outside scope.

Session-authority failures use the existing Auth/session reconciliation path.

---

# 11. Topic Edit

Endpoint:

```text
PATCH /teacher/topics/{topicId}
```

Expected success:

```text
200
{
  "data": { "...exact Teacher Topic resource..." },
  "message": "Topic updated successfully."
}
```

No query parameters.

## 11.1 Immutable Group

Topic Group is not editable.

Edit screen shows Group context read-only.

Never send:

```text
group_id
institution_id
teacher_id
status
lifecycle timestamps
```

## 11.2 Editable fields

Only:

```text
title
description
subject
student_instructions
lesson_at
```

Reuse create validation/normalization rules.

## 11.3 Dirty snapshot

Build an initial normalized edit snapshot from authoritative Topic detail.

`Save` sends only fields whose normalized values differ from that snapshot.

If no normalized field changed:

```text
do not send PATCH
show a small "No changes to save." notice
```

Clearing:

```text
description → send null when previously non-null/nonblank
lesson_at   → send null when previously non-null
```

Do not send an empty `{}` PATCH.

## 11.4 Edit availability in UI

Desktop Edit action is shown only when the current detail resource indicates:

```text
Group status = active
Topic status = draft OR active
```

This is a usability projection only.

Backend remains authoritative and may still return:

```text
409 topic_not_editable
```

if state changed concurrently.

Closed/archived Topics and Topics in archived Groups are read-only.

Mobile never shows Edit.

## 11.5 Dirty navigation protection

When edit form is dirty and no confirmed success has completed, attempts to
leave the edit route must ask:

```text
Discard unsaved Topic changes?
```

Actions:

```text
Keep editing
Discard
```

Do not block navigation when the form is clean.

While a submit or outcome-reconciliation operation owns the route, prevent
duplicate submit and unsafe navigation according to existing route-blocking
patterns.

---

# 12. Edit Error and Reconciliation

## 12.1 Validation

For:

```text
422 validation_failed
```

map known server fields to their form fields:

```text
title
description
subject
student_instructions
lesson_at
```

Use safe frontend text. Do not surface raw Laravel messages as application
behavior.

Unknown validation keys produce a generic form-level review error.

Focus the first invalid field using existing project accessibility patterns.

## 12.2 Topic no longer editable

For:

```text
409 topic_not_editable
```

do not guess the cause.

Fetch authoritative Topic detail once.

If detail succeeds:

- preserve the user's unsaved draft in memory for reference;
- disable further Save while the authoritative state is not editable;
- show:

```text
This Topic is no longer editable. Review its current server state.
```

Provide `Review Topic` / back-to-detail action.

Do not silently discard the local draft before the Teacher chooses to leave.

If detail becomes `404`, use the generic unavailable Topic state.

## 12.3 Unknown update outcome

Do not automatically repeat PATCH after an ambiguous result.

Because Topic ID is known, reconcile first with:

```text
GET /teacher/topics/{topicId}
```

Compare only the fields sent in the PATCH.

Comparison rules:

- `title`, `subject`, `student_instructions` compare to their normalized trimmed
  submitted values;
- `description` compares to normalized nullable submitted value;
- `lesson_at` compares by authoritative instant, not request string formatting.

If all changed fields match current server state:

```text
treat update as reconciled success
```

Otherwise:

- replace authoritative detail with the fetched current server resource;
- preserve the user's attempted draft separately;
- show that the update result could not be confirmed;
- do not claim failure or success;
- allow the Teacher to review current state.

If reconciliation GET itself cannot complete, remain in an `outcome unknown`
state with:

```text
Check current Topic
```

This action repeats the GET reconciliation, not PATCH.

---

# 13. Topic Lifecycle

Use only:

```text
POST /teacher/topics/{topicId}/activate
POST /teacher/topics/{topicId}/close
POST /teacher/topics/{topicId}/archive
```

Send:

```text
no body
no query parameters
```

Do not send `{}` unless the current Dio abstraction requires a body to issue
POST; preferred implementation sends no body bytes.

Expected success:

```text
200
{
  "data": { "...exact Teacher Topic resource..." },
  "message": "<exact endpoint success message>"
}
```

Expected messages:

```text
Topic activated successfully.
Topic closed successfully.
Topic archived successfully.
```

Unexpected success payload/status/message is not a confirmed mutation result.

## 13.1 Desktop action matrix

Render actions from the currently loaded resource:

| Group status | Topic status | Actions |
|---|---|---|
| `active` | `draft` | `Edit`, `Activate`, `Archive` |
| `active` | `active` | `Edit`, `Close` |
| `active` | `closed` | `Archive` |
| `active` | `archived` | none |
| `archived` | `draft` | `Archive` |
| `archived` | `active` | `Close` |
| `archived` | `closed` | `Archive` |
| `archived` | `archived` | none |

This matrix is presentation guidance only. Never bypass backend lifecycle
validation.

Mobile shows no lifecycle actions.

## 13.2 Confirmation dialogs

Every real lifecycle action requires confirmation before dispatch.

### Activate

Title:

```text
Activate Topic?
```

Explain succinctly:

- the Topic becomes active learning content for authorized Students;
- activation requires valid Topic metadata and at least one current Learning
  Material;
- backend makes the final readiness decision.

Do not fetch material list in FE-002 merely to enable/disable Activate.

### Close

Title:

```text
Close Topic?
```

Explain that the Topic leaves active use and metadata editing becomes
unavailable according to server lifecycle rules.

### Archive

Title:

```text
Archive Topic?
```

Explain that archived Topic content is retained as historical read-only data.

Do not present destructive-delete wording.

## 13.3 `409 topic_not_editable`

On any lifecycle `409 topic_not_editable`:

- do not parse the human message to infer a cause;
- fetch current Topic detail;
- show a safe notice that the action is not available in current server state;
- render controls from the refreshed resource.

For failed activation, safe UX may mention the documented readiness categories:

```text
Activation was not available. Check the current Topic state, active Group
context, required Topic information, and that at least one current Learning
Material exists.
```

Do not claim which exact condition failed.

---

# 14. Lifecycle Unknown Outcome Reconciliation

Never blindly repeat a lifecycle POST after an ambiguous transport/result
failure.

Reconcile first:

```text
GET /teacher/topics/{topicId}
```

Expected target states:

```text
activate → active
close    → closed
archive  → archived
```

If current authoritative Topic has the expected target status:

```text
treat as reconciled success
```

Otherwise:

- update UI to the current authoritative Topic;
- show that the requested action could not be confirmed;
- do not claim success;
- do not repeat the mutation automatically.

If reconciliation GET cannot complete, remain `outcome unknown` and expose:

```text
Check current Topic
```

which retries only the GET.

After confirmed/reconciled lifecycle success:

- use returned/fetched Topic as detail authority;
- invalidate/mark FE-001 Topic list stale;
- show success feedback once.

---

# 15. Detail and Mutation State Ownership

Use focused Riverpod state/controllers rather than one monolithic Teacher
controller.

A reasonable split is:

```text
Topic detail controller keyed by Topic ID/session
Topic create controller
Topic edit controller keyed by Topic ID/session
Topic lifecycle action controller keyed by Topic ID/session
Create Group picker controller
```

Equivalent focused decomposition is allowed if it preserves these boundaries.

Every async controller must bind publication to:

```text
authenticated Teacher user ID
current AuthUser instance/session identity
Institution ID
AppDeviceSurface
route/target Topic ID where applicable
latest logical operation generation
```

Create/edit are desktop-eligible only.

Detail is desktop/mobile-eligible.

A stale completion must not:

- replace a different Topic detail;
- write into a replacement auth session;
- show a Snackbar after route/session loss;
- navigate after route ownership was lost;
- close a newer confirmation dialog;
- mutate FE-001 retained list state for the wrong session.

Cancel/invalidate owned operations when the provider/route/session becomes
ineligible.

---

# 16. Session and Security Behavior

Eligible Teacher session requires:

```text
authenticated
role = teacher
user active
must_change_password = false
non-empty institution_id
user.institution.id == user.institution_id
institution.status = active
supported Teacher device surface
```

Authoring operations additionally require desktop.

For these server codes:

```text
authentication_required
password_change_required
user_inactive
institution_inactive
```

clear task-owned protected state immediately and use the existing auth/session
reconciliation/bootstrap behavior.

`authentication_required` continues through the existing session invalidation
signal.

`403 forbidden` is a safe permission error; it does not change client-side role
authority.

`404 resource_not_found` never reveals whether an inaccessible record exists.

The client never sends:

```text
institution_id
teacher_id
role
membership ID
```

as authority.

Knowing a Topic or Group UUID never grants access.

---

# 17. Shared Error-Code Update

Add the backend-delivered stable machine code to the frontend core registry:

```dart
topicNotEditable = 'topic_not_editable'
```

Do not add speculative future Stage 6+ codes in this task.

Use machine codes/statuses for application behavior.

Do not parse backend human-readable messages to decide lifecycle or
authorization behavior.

---

# 18. Presentation Contract

## 18.1 Desktop create/edit

Use the existing Material form style and project patterns:

- constrained readable width;
- responsive Wrap for action rows;
- keyboard traversal;
- focus first validation error;
- multiline fields for description/instructions;
- no horizontal page overflow;
- progress semantics during submission/reconciliation;
- safe dirty-form confirmation.

## 18.2 Desktop detail

Show Topic identity/status prominently and Group context clearly.

Actions appear in one responsive Wrap and are disabled while a conflicting
operation is in flight.

Do not show material management controls yet.

A small informational note may state:

```text
Learning Materials are required before Topic activation.
```

Do not add a placeholder Material screen/button.

## 18.3 Mobile detail

Use one-column scrollable cards/sections.

Show the same read information but no:

```text
Create
Edit
Activate
Close
Archive
```

No horizontal scrolling should be required at representative phone widths.

---

# 19. FE-001 State Reconciliation

Do not directly mutate FE-001 Topic list rows as if local data were
authoritative.

After confirmed create/update/lifecycle:

```text
mark/invalidate Topic list authoritative data
preserve list query when safe
refresh when the workspace next owns the list
```

For confirmed create, navigating directly to created Topic Detail is allowed.

For update/lifecycle, remain on Topic Detail with the authoritative returned
resource.

For create outcome-unknown recovery, use the recovery query defined in Section
9.

When a Topic becomes outside current readable scope and detail returns `404`,
remove/clear any retained Topic-detail state and return safely to `/teacher`.

---

# 20. Acceptance Criteria

The task is Accepted only when all are true:

- FE-001 is already Accepted / Delivered on the implementation baseline.
- Desktop `/teacher` exposes a working Create Topic action.
- Desktop create uses a searchable paginated assigned-Group picker.
- Create sends only the exact approved POST fields.
- Create always produces server-authoritative draft behavior.
- Ambiguous create is never automatically repeated.
- Confirmed create navigates to real Topic Detail.
- Topic Detail works on desktop and mobile.
- Valid Teacher Topic deep links survive auth bootstrap; invalid Teacher child routes/query/fragment are rejected before API dispatch.
- Detail uses tenant/Teacher/current-membership-safe backend data only.
- `lesson_at` is displayed in Institution timezone, never arbitrary device time.
- `timezone ^0.11.1` is the only new package.
- `latest_all` IANA data is used.
- Desktop Edit never permits Group reassignment.
- Edit sends only changed approved metadata fields.
- Exact no-change edit sends no PATCH.
- Dirty edit navigation is protected.
- Closed/archived/archived-Group Topic is read-only in UI.
- `topic_not_editable` is handled by machine code and server-state refresh.
- Activate/Close/Archive use only their dedicated endpoints.
- Lifecycle UI matrix matches the backend contract.
- Mobile exposes no Topic authoring/lifecycle actions.
- Activation does not pull FE-003 Material management into this task.
- Mutation responses reconcile FE-001 Topic list safely.
- Unknown update/lifecycle outcomes reconcile with GET before any retry.
- No stale async completion can publish across route/session/Topic ownership.
- No backend/schema/API changes.
- No FE-003 material implementation.
- Focused tests and directly affected regressions pass.
- `git diff --check` passes.
- Final diff contains no unrelated work.

---

# 21. Required Focused Tests

Add/extend tests under:

```text
frontend/test/features/teacher/
```

Exact filenames may follow delivered FE-001 naming, but cover the following.

## 21.1 Timezone helper

Test:

- `Asia/Tashkent` local selection → correct `+05:00` request;
- UTC resource → correct Institution-local display;
- `America/New_York` summer → `-04:00`;
- winter → `-05:00`;
- DST nonexistent local time is rejected instead of silently shifted;
- null lesson time;
- unknown Institution timezone does not fall back to device timezone;
- RFC 3339 output includes seconds and numeric offset.

Tests must not depend on the machine timezone.

## 21.2 Create domain/data/controller

Test:

- exact payload normalization;
- title/subject limits;
- required instructions;
- blank description → null;
- strict `201 data + message`;
- malformed success → outcome unknown;
- exact definite validation/auth/forbidden/rate-limit failures;
- transport ambiguity → outcome unknown and no automatic repeat;
- selected Group `404` clears stale selection safely;
- confirmed create invalidates Topic list and yields created ID;
- recovery prepares draft/recent Group-filtered Topic query;
- stale session/route completion cannot navigate/publish.

## 21.3 Group picker

Test:

- initial page/search/pagination;
- 300 ms search debounce;
- 254 code-point validation;
- selection persists across page/search;
- only active Teacher Groups are accepted as picker results;
- stale/session responses cannot publish.

## 21.4 Detail

Test:

- exact GET path/no body/no query;
- strict Topic resource reuse;
- requested ID must match returned ID;
- desktop/mobile eligibility;
- loading/refresh/error/not-found states;
- session-authority reconciliation;
- Institution-time lesson display.

## 21.5 Edit

Test:

- Group is immutable/read-only;
- form initializes from authoritative detail;
- only changed fields serialize;
- clearing description/lesson sends null;
- unchanged normalized form sends no PATCH;
- server validation maps to fields;
- dirty navigation guard;
- confirmed update updates detail and invalidates list;
- `409 topic_not_editable` reconciles current state without guessing cause;
- ambiguous PATCH reconciles with GET;
- matching fetched changed fields → reconciled success;
- mismatching state → unconfirmed/current-state UX;
- reconciliation failure does not repeat PATCH.

## 21.6 Lifecycle

Test action matrix for active and archived Group states.

Test:

- confirmation required;
- no body/query;
- exact endpoint path;
- strict success status/resource/message;
- `topic_not_editable` refreshes current state;
- activate target reconciliation;
- close target reconciliation;
- archive target reconciliation;
- unknown result never automatically repeats POST;
- detail/list use authoritative returned state;
- mobile has no lifecycle controls.

## 21.7 Routing/presentation

Test:

- `/teacher/topics/new` desktop only;
- `/teacher/topics/:id` desktop/mobile;
- `/teacher/topics/:id/edit` desktop only;
- literal `new` is not interpreted as Topic ID;
- FE-001 Topic card opens detail;
- mobile create/edit attempts redirect safely;
- valid Teacher detail/create/edit routes are recognized by auth redirect on the correct surface;
- invalid Teacher Topic UUID/extra segment/query/fragment falls back safely without Topic API dispatch;
- valid Teacher Topic deep link is retained through auth bootstrap;
- desktop forms remain usable at narrow desktop layout;
- mobile detail has no horizontal overflow at representative phone width/text
  scale;
- existing Teacher role/device entry remains unchanged.

---

# 22. Verification Scope

Use the project Flutter SDK:

```text
3.44.7
```

Run from repository root.

Focused Teacher tests:

```powershell
Push-Location frontend
fvm spawn 3.44.7 test test/features/teacher
Pop-Location
```

Run the directly affected router/entry regression tests based on the actual
delivered FE-001 files. At minimum include the existing bootstrap/entry routing
coverage that owns Teacher desktop/mobile routing.

Static analysis:

```powershell
Push-Location frontend
fvm spawn 3.44.7 analyze
Pop-Location
```

Format check:

```powershell
Push-Location frontend

C:\Users\Administrator\fvm\versions\3.44.7\bin\cache\dart-sdk\bin\dart.exe `
  format --output=none --set-exit-if-changed lib test

Pop-Location
```

Always:

```powershell
git diff --check
```

Then perform a focused diff/scope self-review for:

```text
FE-002 only
one approved timezone dependency only
no backend changes
no FE-003 material management
exact Topic endpoints/payloads
Group immutable after creation
Institution timezone not device timezone
shared timezone support lives in a neutral reusable boundary
Teacher child-route/deep-link guards are explicit
outcome-unknown safety
session/stale ownership
desktop/mobile boundary
no unrelated refactor
```

Do **not** run for this task:

```text
full frontend suite
Windows build
Android build
broad integration/E2E
backend test suite
```

Those belong to Stage block checkpoints/integration unless a concrete
task-specific regression requires escalation.

---

# 23. Codex Implementation Report

Return a compact report containing:

1. implementation baseline SHA and confirmation `S05-FE-001 Accepted / Delivered`;
2. implementation summary;
3. changed files;
4. approved dependency change;
5. routes added/changed;
6. exact API operations implemented;
7. timezone serialization/display behavior;
8. create/edit/lifecycle reconciliation behavior;
9. desktop/mobile behavior;
10. tests added/updated;
11. exact verification commands/results;
12. `git diff --check`;
13. focused diff/scope self-review;
14. deviations/blockers.

Do not commit, push, create/merge a PR, or perform Stage bookkeeping unless the
Project Owner separately instructs that delivery step.
