# Codex Task: Own Institution Profile View and Edit

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-FE-003` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Frontend` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Contract corrections reviewed | `2026-08-14` |
| Depends on | `S03-FE-002` and `S03-BE-002` — each must be `Accepted / PASS / Delivered` before execution |
| Blocks | `S03-FE-004`, `S03-INT-002` |

This task/prompt pair may be prepared before its dependencies are delivered.
Preparation is not implementation: Phase 0 must stop unless every direct
dependency is accepted, reviewed with PASS, and delivered on `origin/main`.

## 2. Goal

Replace only the Institution placeholder at:

```text
/institution-admin/institution
```

with a real, responsive Institution Admin profile screen that:

- loads the authenticated Institution Admin's own Institution from the server;
- displays the approved public profile values;
- edits only the five backend-approved fields;
- never accepts or transmits an Institution/tenant selector;
- prevents duplicate or automatic mutation replay;
- reconciles an uncertain PATCH outcome only through read-only GET requests;
- prevents stale profile data from crossing logout, role, account, Institution,
  route-disposal, or newer-operation boundaries; and
- keeps the accepted Institution Admin shell's displayed Institution name in
  sync only from a verified authoritative profile response.

Exact backend endpoints consumed:

```text
GET   /api/v1/institution/profile
PATCH /api/v1/institution/profile
```

No backend or locked-document change belongs to this task.

## 3. Current Accepted Context

At this task's execution gate:

- Stage 1 and Stage 2 are closed with PASS.
- S03-INT-001 owns the exact Stage 3 profile contract.
- S03-BE-002 delivers the exact own-Institution GET/PATCH API.
- S03-FE-001 delivers the Institution Admin desktop shell, exact route family,
  session/device guards, and static Institution placeholder.
- S03-FE-002 replaces only the Dashboard placeholder and establishes the
  Institution Admin feature/session/data conventions.
- The accepted Dio client already owns `/api/v1`, bearer-token injection,
  error-envelope mapping, and token-version-aware central `401` invalidation.
- `/api/v1/auth/me` remains the session identity authority and supplies the
  Institution name displayed by the shell.
- Accepted Platform Institution detail/edit code is an implementation pattern,
  not this task's tenant, route, field, state, or presentation contract.

Do not copy the Platform Owner route UUID, editable `type`, lifecycle actions,
Institution Admin list, or Platform business behavior into this feature.

## 4. Dependency and Authority Gate

Before Phase 1, prove all of the following on current `origin/main`:

1. Stage 1 and Stage 2 remain `Closed / PASS`.
2. S03-INT-001 is `Accepted / PASS / Delivered`.
3. S03-BE-002 is `Accepted / PASS / Delivered`, and its route/resource/tests
   still match Section 5.
4. S03-FE-001 and S03-FE-002 are each `Accepted / PASS / Delivered`.
5. The real Institution Admin shell, Dashboard, exact Institution route, and
   remaining honest placeholders are present and green.
6. The Stage 3 index and `tasks/README.md` truthfully identify S03-FE-003 as the
   next executable task.
7. This approved task exists exactly at:

   ```text
   tasks/frontend/stage-03/S03-FE-003-own-institution-profile-view-edit.md
   ```

8. Its paired prompt exists exactly at:

   ```text
   tasks/frontend/stage-03/S03-FE-003-CODEX-PROMPT.md
   ```

9. No competing own-Institution profile frontend implementation exists.
10. The current auth/session/router/Dio contracts can satisfy this task inside
    the exact allowlist in Section 15.

Authority order:

1. applicable root and `frontend/AGENTS.md` instructions;
2. locked `docs/01–09` according to their documented authority areas;
3. accepted S03-INT-001 and delivered S03-BE-002 API behavior;
4. this approved detailed task;
5. the paired execution prompt, which invokes but does not redefine the task.

Stop before implementation if a dependency, authority file, API contract,
route/shell boundary, or safe Git condition is missing or contradictory. Do
not repair a locked contract silently in Flutter.

## 5. Exact Backend Contract Consumed

### 5.1 Relative Paths and Requests

The configured Dio base URL already owns `/api/v1`. The data source therefore
uses exactly:

```dart
dio.get<Object?>('/institution/profile')
```

and, for a non-empty changed-fields request only:

```dart
dio.patch<Object?>(
  '/institution/profile',
  data: request.toJson(),
)
```

Both requests use the existing authenticated Dio client. They send:

```text
query parameters: none
route Institution UUID: none
institution_id: none
tenant-selection header: none
manually constructed Authorization header: none
skip-auth option: false/absent
```

GET sends no request body/data. PATCH sends one JSON object containing at least
one and only approved changed field. Never issue PATCH with `{}`.

### 5.2 Exact Public Resource

Both GET and PATCH success contain this complete resource under `data`:

```json
{
  "id": "institution-uuid",
  "name": "Example School",
  "type": "school",
  "status": "active",
  "contact_email": "info@example.uz",
  "contact_phone": "+998...",
  "address": "Samarkand",
  "description": "Optional notes",
  "created_at": "2026-08-07T15:00:00Z",
  "updated_at": "2026-08-07T15:00:00Z"
}
```

Exact required key order is backend evidence; Flutter parsing must not depend
on JSON map iteration order. Required meanings and types:

| Key | Required frontend interpretation |
|---|---|
| `id` | non-empty canonical hyphenated UUID-shaped string; must equal the live authenticated session Institution ID before use/display of any profile data |
| `name` | non-empty string |
| `type` | exactly one value from the type table below |
| `status` | exactly `active` or `inactive` |
| `contact_email` | present nullable string |
| `contact_phone` | present nullable string |
| `address` | present nullable string |
| `description` | present nullable string |
| `created_at` | required valid RFC 3339/ISO 8601 UTC timestamp string |
| `updated_at` | required valid RFC 3339/ISO 8601 UTC timestamp string |

Nullable keys remain required even when their value is JSON `null`. Missing,
wrongly typed, empty required strings, unknown enum values, invalid UUID shape,
or invalid/non-UTC timestamps are invalid responses. Never coerce them into
plausible values.

The accepted UUID shape is exactly:

```text
^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$
```

Accepted authoritative timestamp strings must match a valid calendar instant
in this UTC form (fractional seconds may be present):

```text
yyyy-MM-ddTHH:mm:ss[.fraction]Z
```

Do not accept a non-UTC offset for these server-generated output fields, even
though other user-entered API timestamp contracts may accept explicit offsets.

The exact Institution types and user-visible labels are:

| API value | Label |
|---|---|
| `school` | `School` |
| `college` | `College` |
| `lyceum` | `Lyceum` |
| `university` | `University` |
| `institute` | `Institute` |
| `learning_center` | `Learning center` |
| `training_center` | `Training center` |
| `private_education` | `Private education` |
| `other` | `Other` |

Status labels are:

```text
active   → Active
inactive → Inactive
```

Do not import Platform Admin domain types into the Institution Admin domain.
Use focused Institution profile types even when their enum values currently
match.

### 5.3 GET Success Envelope

GET success is exactly `200 OK` with the normal single-resource envelope:

```json
{
  "data": {
    "id": "institution-uuid",
    "name": "Example School",
    "type": "school",
    "status": "active",
    "contact_email": null,
    "contact_phone": null,
    "address": null,
    "description": null,
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-07T15:00:00Z"
  }
}
```

Use `ApiSuccessEnvelope.fromJson`; require HTTP status `200`. GET does not
require or display a `message`. GET never sends query/body data. An unexpected
successful status or malformed resource is a safe invalid-response load error.

### 5.4 PATCH Input and Success

Strict editable JSON allowlist:

```text
name
contact_email
contact_phone
address
description
```

Never send:

```text
id
institution_id
type
status
created_by_user_id
deactivated_at
created_at
updated_at
settings
timezone
learning_material_max_mb
student_submission_max_mb
acceptable_score_difference
blitz_timer_start_mode
student_result_release_mode
parent_result_release_mode
role
users
user_counts
```

PATCH success is exactly `200 OK`, contains the complete resource from Section
5.2, and contains the exact top-level message:

```text
Institution profile updated successfully.
```

A missing, wrongly typed, or different PATCH success message makes the mutation
response untrustworthy. Because the backend may already have committed, handle
that result as an uncertain mutation outcome under Section 11; do not label it
as an ordinary invalid-response failure and do not replay PATCH.

### 5.5 DTO and Additive-Field Policy

Required response DTO boundaries:

```text
InstitutionProfileDto
InstitutionProfileGetResponseDto
InstitutionProfileUpdateResponseDto
```

They must:

1. parse the accepted envelope through `ApiSuccessEnvelope`;
2. require every resource key/type from Section 5.2;
3. parse exact type/status enums;
4. parse required timestamps and normalize them to Dart UTC `DateTime` values;
5. require the exact PATCH message for a trusted mutation response;
6. expose only the approved resource/domain values; and
7. never expose raw maps, envelope fields, transport objects, or backend
   messages to presentation.

Unknown/additional transport keys are ignored for forward-compatible additive
API evolution, consistent with accepted client DTO patterns. They must never be
copied into domain/state/UI. In particular, an unexpected creator, lifecycle,
settings, counts, User, token, relationship, or learning key must not become
rendered or request-authoritative.

An otherwise valid profile whose `id` does not equal the current eligible
session Institution ID is rejected by the controller before protected profile
state is exposed. A GET mismatch maps to a safe invalid-response load error. A
PATCH success mismatch is an uncertain outcome and follows reconciliation.

## 6. Exact Frontend Architecture

Use the feature-first flow required by `frontend/AGENTS.md`:

```text
InstitutionAdminProfileScreen
  → InstitutionProfileController / InstitutionProfileState
  → InstitutionProfileRepository
  → InstitutionProfileRemoteDataSource
  → authenticated Dio
```

### 6.1 Required Types and Providers

Use these focused types unless a delivered dependency has a direct naming
collision that requires a stop:

```text
InstitutionProfile
InstitutionProfileType
InstitutionProfileStatus
InstitutionProfileEditField
InstitutionProfileEditFormValue
InstitutionProfileEditSnapshot
InstitutionProfileEditValidation
InstitutionProfileUpdateRequest
InstitutionProfileUpdateResult
InstitutionProfileRepository
InstitutionProfileUpdateOutcomeUnknownException
InstitutionProfileDto
InstitutionProfileGetResponseDto
InstitutionProfileUpdateResponseDto
InstitutionProfileRemoteDataSource
InstitutionProfileRepositoryImpl
InstitutionProfileSessionKey
InstitutionProfileViewStatus
InstitutionProfileState
InstitutionProfileController
InstitutionAdminProfileScreen
```

Required providers:

```text
institutionProfileRemoteDataSourceProvider
institutionProfileRepositoryProvider
institutionProfileControllerProvider
```

The controller provider is an `autoDispose` family keyed by the live session
User ID and Institution ID. Neither value is sent to the endpoint.

### 6.2 Responsibility Boundaries

- DTOs own transport parsing only.
- Domain types own immutable profile/form/snapshot/request values and local
  non-authoritative validation/diff behavior.
- The repository exposes typed GET/PATCH operations.
- The data source owns exact Dio calls and transport/outcome classification.
- The controller owns session eligibility, loading/edit state, deduplication,
  operation generations, reconciliation, safe notices, and shell-name sync.
- Widgets render typed state and dispatch explicit user intent only.
- Presentation never calls Dio, parses JSON, inspects raw backend messages, or
  chooses tenant scope.
- No Platform feature is imported as domain/business authority.
- No new package, code generator, HTTP client, cache, service locator, router,
  or state-management mechanism is introduced.

The repository interface exposes exactly these method signatures:

```dart
Future<InstitutionProfile> fetchProfile();
Future<InstitutionProfileUpdateResult> updateProfile(
  InstitutionProfileUpdateRequest request,
);
```

Neither method accepts an Institution ID.

## 7. Session Eligibility and Tenant Safety

The profile controller may request/render only while the live session is all
of:

```text
AuthSessionStatus.authenticated
user != null
user.role == UserRole.institutionAdmin
user.isActive == true
user.mustChangePassword == false
user.institutionId is non-null and non-empty
user.institution != null
user.institution.id == user.institutionId
user.institution.status == 'active'
controller key User ID == user.id
controller key Institution ID == user.institutionId
```

S03-FE-001 remains the route/device/shell authorization authority; this feature
adds defense in depth. Initial, bootstrapping, unauthenticated, authenticating,
bootstrap-failure, wrong-role, inactive User, first-login, missing/mismatched
Institution, inactive Institution, unsupported device, or invalid route context
must produce zero profile requests and expose no profile/form state.

The Institution ID is used only as a local response/session invariant. Never
accept it from route parameters, widget arguments, form values, local
preferences, cached profiles, query, body, or custom headers. Never pass it to
the profile data source.

Every accepted profile response must match the current session Institution ID
before entering visible data/edit/success state or updating the shell name.
Although the DTO parses both contract status enum values, a successful own-
profile response with `status != active` contradicts the active Institution
Admin route. Do not render it: clear feature state and trigger the same current-
session bootstrap reconciliation used for `institution_inactive`.

## 8. Route Ownership, Freshness, and Read States

### 8.1 Route Ownership and Lifetime

- Only `/institution-admin/institution` builds the real profile screen and
  starts its provider.
- Direct/reload-style entry starts one GET for the current eligible session.
- Same-session rebuilds do not start duplicate GET requests.
- Dashboard, Users, User create/detail, and Settings routes issue zero profile
  GET/PATCH requests.
- The provider is `autoDispose`; leaving the Institution route disposes profile
  and draft state.
- Returning after disposal starts one fresh GET.
- There is no cross-route cache, persistence, polling, timer, background
  refresh, stale-while-revalidate, or automatic GET retry.

### 8.2 Exact View Statuses

`InstitutionProfileViewStatus` uses these exact semantic statuses:

```text
initial
loading
data
editing
submitting
validationFailure
mutationFailure
reconciling
confirmedDirectSuccess
unconfirmedCurrentState
outcomeUnknown
loadError
```

Meanings:

- `initial`: no eligible profile request/data.
- `loading`: current initial/Refresh GET; no old profile or form is rendered.
- `data`: one verified current server profile with no mutation-result notice,
  view mode.
- `editing`: verified profile plus editable draft.
- `submitting`: one PATCH in flight; form visible but disabled.
- `validationFailure`: editable draft with local/server field errors.
- `mutationFailure`: definite failure with draft retained and no success claim.
- `reconciling`: PATCH outcome uncertain; one automatic GET in flight; all
  mutation actions disabled.
- `confirmedDirectSuccess`: only the exact trusted direct PATCH response has
  confirmed the request and supplied the complete displayed server profile;
  view mode with the exact success notice.
- `unconfirmedCurrentState`: a valid reconciliation GET published the current
  complete server profile, but the earlier PATCH result remains unconfirmed;
  view mode with the exact neutral notice, never a mutation-success state.
- `outcomeUnknown`: automatic reconciliation failed or could not be trusted;
  no stale profile is presented as current and no PATCH action is available.
- `loadError`: current GET failed; no old profile/form is rendered.

### 8.3 Refresh and Retry

View-mode `Refresh`:

- is available only in verified `data`, `confirmedDirectSuccess`, or
  `unconfirmedCurrentState` state;
- immediately enters `loading`, removes old values/notices, and issues one GET;
- is disabled/absent while a GET/PATCH/reconciliation is in flight; and
- deduplicates repeated click, keyboard, or programmatic intent.

Load-error `Retry`:

- retains the safe error surface;
- sets `isRetryInFlight = true` and changes the button label to `Retrying`;
- issues one GET and rejects duplicate intent; and
- replaces the error only with verified data or the newest safe error.

Outcome-unknown `Reload profile` is an explicit read-only recovery action. Each
user activation may issue one GET; duplicate in-flight activation is ignored.
It never reuses or replays the old PATCH request. A verified reload returns to
current data and permits the user to begin a new edit consciously.

### 8.4 Stale Completion Rejection

Use a monotonically increasing operation generation or equivalently tested
mechanism. A GET, PATCH, automatic reconciliation, or manual recovery
completion may change state/shell only when all remain true:

```text
provider/controller is not disposed
operation generation is current
session User ID matches
session Institution ID matches
session remains fully eligible
response profile ID matches the same Institution ID when applicable
```

Reject both success and failure from an earlier operation after Refresh, Retry,
newer load, logout, global invalidation, password gate, route disposal,
same-role account/Institution switch, cross-role switch, or ProviderScope/router
recreation. Old profile values, drafts, errors, notices, and shell names must
not flash or overwrite the newer context.

## 9. Exact Form and Local Validation Contract

### 9.1 Editable and Read-Only Fields

Editable fields, in exact form order:

```text
name
contact_email
contact_phone
address
description
```

Read-only/backend-controlled:

```text
id
type
status
created_at
updated_at
every non-allowlisted field
```

The UI displays type/status as clear read-only context. It does not render an
ID field or expose a type/status control. Timestamps are display-only.

### 9.2 Form Normalization

`InstitutionProfileEditFormValue.fromProfile(profile)` initializes:

```text
name: exact server string
nullable values: server string or empty form string for null
```

The normalized snapshot/request rules are exact:

- `name`: `trim()`; the trimmed value is used for validation and PATCH;
- `contact_email`: trim leading/trailing whitespace; blank becomes `null`;
- `contact_phone`: trim leading/trailing whitespace; blank becomes `null`;
- `address`: if the whole value is whitespace, normalize to `null`; otherwise
  preserve the entered non-empty string exactly;
- `description`: same rule as address.

Create the baseline snapshot from the initial verified profile through the
same normalization rules. Compare normalized current values to that baseline.
Do not compare raw text-controller identity, widget rebuilds, or a stale prior
profile.

### 9.3 Client Validation

Client validation improves UX but never replaces backend authority:

- name is required after trim and maximum 200 characters;
- contact email is nullable, maximum 254 characters, contains no whitespace,
  and uses the accepted permissive single-`@` client shape;
- contact phone is nullable and maximum 50 characters;
- address and description are nullable strings with no invented client maximum;
- no uniqueness check, Institution lookup, lifecycle decision, or protected
  business validation is invented.

Backend `422 validation_failed` field errors are authoritative. Map only exact
allowed keys to their fields. Unknown/body-level validation entries produce a
safe form-level message and are never discarded silently.

### 9.4 Changed-Fields Request

`InstitutionProfileUpdateRequest` contains an immutable map and rejects any key
outside the five-field allowlist. `toJson()` contains only normalized values
that differ from the normalized baseline:

- unchanged fields are omitted;
- clearing a previously non-null optional field sends explicit JSON `null`;
- no-change submit sends no PATCH, exits edit mode to verified data, and shows
  `No changes to save.`;
- cancel discards the draft, sends no request, and returns to unchanged verified
  data without a success notice;
- form submission while already submitting/reconciling is ignored;
- one user intent produces at most one PATCH.

## 10. Edit and Definite Mutation Behavior

- `Edit profile` starts one inline edit form from the current verified profile
  in `data`, `confirmedDirectSuccess`, or `unconfirmedCurrentState` state.
- Do not use a second route, dialog, drawer, or Platform edit screen.
- Refresh is unavailable while editing.
- Cancel and Save are disabled while PATCH/reconciliation is in flight.
- Local invalid submission sends no PATCH and focuses the first invalid field.
- A definite `422` retains the draft, maps field errors, and focuses the first
  mapped invalid field.
- A definite `forbidden` or `resource_not_found` clears profile/draft content
  and shows the safe non-data error surface; it does not silently mutate auth.
- A definite validation/server/local failure not implying lost access retains
  the draft with safe field/form feedback and never shows success.
- A trusted `200` response requires exact status, envelope/resource, matching
  Institution ID, and exact success message.
- Only trusted direct PATCH success enters `confirmedDirectSuccess`, replaces
  the complete profile atomically with the returned server resource, exits edit
  mode, synchronizes the shell name under Section 12, and shows
  `Institution profile updated.`.
- Never merge the submitted draft into old state as if it were committed.
- Never automatically retry PATCH for any failure.

## 11. Uncertain PATCH Outcome and Read-Only Reconciliation

### 11.1 Exact Classification

A received backend HTTP error response (`DioExceptionType.badResponse`) maps
through the existing `DioFailureMapper` and is a definite failure for this
accepted backend contract. A bad certificate is a definite local failure.

Treat these active-session PATCH outcomes as uncertain because the server may
have committed before the client lost trustworthy confirmation:

```text
connectionTimeout
sendTimeout
receiveTimeout
transformTimeout
connectionError
cancel, when the current operation is still active
unknown transport error
unexpected 2xx status
malformed/missing PATCH success envelope or resource
wrong/missing PATCH success message
PATCH success profile ID mismatch
```

Cancellation/disposal/newer-operation completions that are already stale are
ignored and do not start reconciliation.

The data source exposes uncertainty through the typed
`InstitutionProfileUpdateOutcomeUnknownException`; it must not reduce it to an
ordinary retryable failure.

### 11.2 One Automatic GET

For one current uncertain PATCH:

1. enter `reconciling` and disable mutation actions;
2. issue at most one automatic repository GET using the exact profile endpoint;
3. require a valid current-session/matching-ID profile;
4. compare only the keys present in the original immutable PATCH request
   against the corresponding normalized values in the fetched profile; and
5. never resend, clone, queue, or recursively invoke PATCH.

Outcomes:

| Reconciliation result | Required state/UI |
|---|---|
| Every intended changed key equals the fetched server value | `unconfirmedCurrentState`; render the fetched complete current profile, sync shell name, and show `Current server profile matches your submitted changes, but this request result could not be confirmed.`; do not show success wording or attribute the values to this PATCH |
| One or more intended keys differ | `unconfirmedCurrentState`; render the fetched complete current profile, sync shell name, and show `Current server profile differs from your submitted changes. This request result could not be confirmed.`; do not claim success or failure; a later edit starts a new request from this new baseline |
| Current-session GET fails, is malformed, has wrong ID, or cannot be trusted | `outcomeUnknown`; show no stale profile as current, show the exact recovery surface from Section 14, and permit only explicit read-only reload/sign-out/navigation |

A later GET proves only current server state. Equality is not proof that this
client PATCH caused those values, and a difference is not proof that it failed;
another authorized update may have occurred. Only the exact direct PATCH
response from Section 5.4 may enter mutation success. Never say `succeeded` or
`failed` in either unconfirmed-current-state notice.

Both valid reconciliation outcomes establish a fresh current-server baseline.
A later edit is allowed only as a new explicit request from that baseline; it
does not retry or continue the earlier PATCH.

A reconciliation completion that became stale is ignored under Section 8.4;
it must not create `outcomeUnknown` in the newer/disposed session.

## 12. Session Reconciliation and Shell-Name Consistency

### 12.1 Central `401`

For `401 authentication_required`, rely on the accepted
`AuthTokenInterceptor` and token-version-aware global invalidation signal.
Immediately remove profile/draft state for that current failure. Do not clear
tokens directly, emit a duplicate invalidation event, or create feature-owned
authentication authority.

### 12.2 Lifecycle and Password Codes

For current-operation stable codes:

```text
password_change_required
user_inactive
institution_inactive
```

remove protected feature state and trigger the existing
`AuthSessionController.bootstrap()` exactly once for reconciliation. Do not
locally invent a role, lifecycle status, password state, or route result.

`forbidden` and `resource_not_found` use safe feature errors; they do not
silently change auth state. An unrecognized `409` or other server code receives
only generic safe failure handling and no invented profile business meaning.

### 12.3 Authoritative Institution Name Sync

The accepted Institution Admin shell displays `user.institution.name` from the
live authenticated session. A verified profile GET, trusted direct PATCH
response, or valid reconciliation GET may therefore update only that cached
display name. Updating the name from a reconciliation GET publishes current
server state only and must not convert the earlier PATCH into success.

Add exactly this narrowly scoped method to `AuthSessionController`:

```dart
bool reconcileInstitutionNameFromServer({
  required String expectedUserId,
  required String expectedInstitutionId,
  required String institutionName,
});
```

It must:

- accepts an expected session User ID, expected Institution ID, and the verified
  server profile name;
- applies only while the current state is an eligible authenticated Institution
  Admin with the same User/Institution IDs and matching nested Institution;
- reconstructs only the immutable cached `AuthInstitution.name` value;
- preserves every other User, Institution, token, auth status, role, lifecycle,
  password, timezone, and session-generation value;
- performs no HTTP/storage/token/router operation;
- returns whether the current session accepted the reconciliation;
- is a no-op without emitting new state when the name already matches; and
- rejects stale/mismatched/noneligible calls without changing state.

The controller calls this method only after the profile ID/session checks pass.
If the session no longer accepts the update, the profile completion is stale
and must not be rendered.

This narrow server-response reconciliation is the only allowed auth-layer
change. Do not add a generic client-owned session editor or call `/auth/me`
after every profile mutation.

## 13. Safe Error and Notice Copy

Never display raw backend `message`, field-map keys outside approved fields,
request IDs, URLs, stack traces, SQL, exceptions, transport objects, response
bodies, tokens, User IDs, or Institution IDs.

### 13.1 Load Error

Exact title:

```text
Profile unavailable
```

Exact safe messages:

| Failure | Message |
|---|---|
| `authentication_required` | `Please sign in again.` |
| `password_change_required` | `Password change is required before profile access.` |
| `user_inactive` | `This account is inactive.` |
| `institution_inactive` | `This institution is inactive.` |
| `forbidden` | `You do not have permission to view this institution profile.` |
| `resource_not_found` | `The institution profile could not be found.` |
| `validation_failed` | `The profile request did not match the API contract.` |
| connection | `Could not reach the server. Check the connection and try again.` |
| timeout | `The profile request timed out.` |
| invalid response | `The server returned an unexpected institution profile response.` |
| cancelled | `The profile request was cancelled.` |
| server/unknown/other | `The institution profile could not be loaded.` |

### 13.2 Definite Mutation Failure

Use field errors when available. Otherwise show one safe form-level message:

| Failure | Message |
|---|---|
| `authentication_required` | `Please sign in again.` |
| `password_change_required` | `Password change is required before profile editing.` |
| `user_inactive` | `This account is inactive.` |
| `institution_inactive` | `This institution is inactive.` |
| `forbidden` | `You do not have permission to edit this institution profile.` |
| `resource_not_found` | `The institution profile could not be found.` |
| validation with no mapped field | `Some submitted profile details need review.` |
| bad certificate | `A secure connection to the server could not be established. No changes were confirmed.` |
| server/unrecognized HTTP error | `The institution profile could not be updated. No changes were confirmed.` |

### 13.3 Outcome Unknown

Exact title and message:

```text
Update outcome unknown
The server result could not be verified. Reload the profile before making another change.
```

Exact action:

```text
Reload profile
```

During its GET:

```text
Reloading
```

## 14. Exact Presentation Contract

### 14.1 View Mode

Exact feature heading:

```text
Institution Profile
```

Verified data renders these rows in this order:

```text
Name
Type
Status
Contact email
Contact phone
Address
Description
Created at
Updated at
```

Null optional values render exactly:

```text
Not provided
```

Timestamps render in UTC without a new package:

```text
yyyy-MM-dd HH:mm UTC
```

Example:

```text
2026-08-07 15:00 UTC
```

Do not render the Institution UUID. Do not render creator/deactivation
metadata, settings, counts, Users, tokens, relationships, learning data, raw
type/status values, or hidden debug information.

View mode has exactly these profile-body actions:

```text
Refresh
Edit profile
```

The persistent shell owns navigation and Sign out.

### 14.2 Inline Edit Mode

Use one inline edit form on the same route. It contains:

- read-only `Type` and `Status` context;
- text fields in the exact editable order from Section 9.1;
- multiline controls for Address and Description;
- `Cancel` and `Save changes` actions;
- `Saving` during PATCH; and
- `Verifying` during automatic reconciliation.

No Institution ID, type/status selector, lifecycle action, logo/upload control,
second route, modal dialog, or Platform Owner component belongs here.

### 14.3 Loading and Error

Initial/Refresh loading shows no profile rows/form/notices and exposes the live
semantic label:

```text
Loading institution profile
```

Load error shows only the exact title/message and one `Retry` action. During
Retry its label is `Retrying`. Outcome unknown uses Section 13.3.

### 14.4 Stable Widget Keys

Use these exact public widget keys:

```text
institutionProfileLoading
institutionProfileData
institutionProfileHeading
institutionProfileRefreshButton
institutionProfileEditButton
institutionProfileNameValue
institutionProfileTypeValue
institutionProfileStatusValue
institutionProfileContactEmailValue
institutionProfileContactPhoneValue
institutionProfileAddressValue
institutionProfileDescriptionValue
institutionProfileCreatedAtValue
institutionProfileUpdatedAtValue
institutionProfileNotice
institutionProfileError
institutionProfileErrorMessage
institutionProfileRetryButton
institutionProfileEditForm
institutionProfileNameField
institutionProfileContactEmailField
institutionProfileContactPhoneField
institutionProfileAddressField
institutionProfileDescriptionField
institutionProfileFormError
institutionProfileCancelButton
institutionProfileSaveButton
institutionProfileReconciling
institutionProfileConfirmedDirectSuccess
institutionProfileUnconfirmedCurrentState
institutionProfileOutcomeUnknown
institutionProfileReloadButton
```

### 14.5 Responsive and Accessible Behavior

- Keep the accepted shell/header/navigation visible around every eligible
  feature state.
- Use one scrollable responsive content surface; do not assume all rows or the
  form fit vertically.
- Verify `800×600` and `1440×900` at text scales `1.0` and `2.0`.
- Long names, contacts, address, and description wrap/select safely without
  overflow or accidental horizontal clipping.
- Heading, read-only labels/values, notices, errors, loading/reconciling live
  regions, and buttons are discoverable by accessibility tools.
- Type/status remain understandable without color; color may only supplement
  text.
- Keyboard Tab order follows heading/actions then form order then Cancel/Save.
- Enter/Space activates focused Material actions; normal text-field Enter
  behavior must not create duplicate PATCH requests.
- Local/server validation focuses the first invalid control and exposes its
  error semantically.
- Disabled/in-flight controls remain visibly and semantically disabled.

## 15. Exact Files and Scope

### 15.1 Allowed Application Files

Only these frontend application paths may change:

```text
frontend/lib/app/router/app_router.dart
frontend/lib/features/auth/application/auth_session_controller.dart
frontend/lib/features/institution_admin/domain/institution_profile.dart
frontend/lib/features/institution_admin/domain/institution_profile_update.dart
frontend/lib/features/institution_admin/domain/institution_profile_repository.dart
frontend/lib/features/institution_admin/data/dto/institution_profile_dto.dart
frontend/lib/features/institution_admin/data/institution_profile_remote_data_source.dart
frontend/lib/features/institution_admin/data/institution_profile_repository_impl.dart
frontend/lib/features/institution_admin/application/institution_profile_state.dart
frontend/lib/features/institution_admin/application/institution_profile_controller.dart
frontend/lib/features/institution_admin/presentation/institution_profile_formatters.dart
frontend/lib/features/institution_admin/presentation/institution_admin_profile_screen.dart
frontend/lib/features/institution_admin/presentation/institution_admin_placeholder_screen.dart
```

Exact responsibilities of existing files:

- `app_router.dart`: replace only the Institution child placeholder import/
  builder with `InstitutionAdminProfileScreen`; preserve every route path,
  name, order, guard, shell, and other child.
- `auth_session_controller.dart`: add only the bounded authoritative name-sync
  method from Section 12.3; preserve all auth/network/token/generation behavior.
- `institution_admin_placeholder_screen.dart`: remove only the now-unused
  Institution placeholder class/body; preserve Users/Create/Detail/Settings
  placeholders byte-for-byte except unavoidable formatter changes.

No `app_route_paths.dart`, shell topology, navigation, device guard, or route
constant change is allowed.

### 15.2 Allowed Test Files

Only these frontend test paths may change:

```text
frontend/test/features/auth/auth_session_controller_test.dart
frontend/test/features/institution_admin/institution_profile_dto_test.dart
frontend/test/features/institution_admin/institution_profile_edit_form_value_test.dart
frontend/test/features/institution_admin/institution_profile_remote_data_source_test.dart
frontend/test/features/institution_admin/institution_profile_repository_impl_test.dart
frontend/test/features/institution_admin/institution_profile_controller_test.dart
frontend/test/features/institution_admin/institution_profile_formatters_test.dart
frontend/test/features/institution_admin/institution_admin_profile_screen_test.dart
frontend/test/features/institution_admin/institution_admin_shell_test.dart
frontend/test/router_bootstrap_test.dart
```

The auth test may change only for the new bounded name reconciliation. The last
two route/shell tests may change only to replace the Institution-placeholder/
zero-profile-request assumptions and add required integration regressions.
Preserve every unrelated auth, route, shell, Dashboard, role, device, and
bootstrap assertion.

### 15.3 Bookkeeping Files

Only as Section 22 permits:

```text
tasks/frontend/stage-03/S03-FE-003-own-institution-profile-view-edit.md
tasks/frontend/stage-03/S03-FE-003-CODEX-PROMPT.md
tasks/STAGE_03_TASK_INDEX.md
tasks/README.md
```

### 15.4 Inspect and Preserve

Inspect/reuse but do not modify:

```text
frontend/lib/core/network/**
frontend/lib/core/storage/**
frontend/lib/features/auth/domain/**
frontend/lib/features/auth/data/**
frontend/lib/features/platform_admin/**
frontend/lib/features/institution_admin/presentation/institution_admin_shell.dart
frontend/lib/features/institution_admin/domain/institution_dashboard.dart
frontend/lib/features/institution_admin/data/institution_dashboard_remote_data_source.dart
frontend/lib/features/institution_admin/application/institution_dashboard_controller.dart
frontend/lib/app/router/app_route_paths.dart
frontend/test/app/router/institution_admin_route_paths_test.dart
frontend/test/features/platform_admin/**
frontend/pubspec.yaml
frontend/pubspec.lock
frontend/integration_test/**
backend/**
docker/**
docs/**
```

No other application, test, generated, package, backend, Docker, docs, task, or
workflow path may change. Stop instead of widening scope silently.

## 16. Authoritative References

| Source | Exact area | Requirement |
|---|---|---|
| `docs/02-user-roles.md` | `2. Institution Admin` | Own-Institution desktop authority |
| `docs/03-features.md` | `3. Institution Admin Features` | Basic Institution profile management |
| `docs/04-user-flows.md` | Institution Admin flow | View/edit workflow inside own Institution |
| `docs/05-business-rules.md` | tenant, role, account, lifecycle, server authority | No cross-Institution/client tenant authority |
| `docs/06-roadmap.md` | `8. Stage 3`; `9. Stage 4` | Current scope and later-stage exclusions |
| `docs/07-architecture.md` | Flutter/API/session/tenancy/testing | Layered Riverpod/Dio/server-authoritative client |
| `docs/08-database.md` | Institutions table | Field types, nullability, and limits |
| `docs/09-api-contracts.md` | general envelopes/errors/time; Section `8.1 Institution Profile` | Exact GET/PATCH contract |
| accepted `S03-INT-001` | Stage 3 contract alignment | Narrow Institution Admin profile boundary |
| accepted S03-BE-002 and implementation/tests | own-profile API | Delivered transport/validation/no-op/security behavior |
| accepted S03-FE-001/002 and implementation/tests | shell/routes/session/data precedent | Exact route ownership and Institution Admin frontend context |
| accepted Platform Institution detail/edit implementation/tests | pattern only | Safe DTO/form/error/testing precedent without Platform behavior |
| `frontend/AGENTS.md` | complete applicable file | Layering, quality, package, and test rules |
| `tasks/STAGE_03_TASK_INDEX.md`, `tasks/README.md` | lifecycle/dependencies | Sequential gate and truthful delivery |

If these appear to conflict, stop and report the exact sections. Do not change
locked docs, backend behavior, or accepted predecessors to make this task pass.

## 17. Acceptance Criteria

- [ ] All direct dependencies are proven `Accepted / PASS / Delivered` before
      implementation.
- [ ] Only `/institution-admin/institution` owns the real profile provider and
      requests.
- [ ] GET/PATCH use exact relative paths, authenticated Dio, no query/body on
      GET, no tenant input, and one non-empty changed-fields body on PATCH.
- [ ] DTOs require every approved resource type/value/timestamp and exact PATCH
      message while ignoring but never exposing additive keys.
- [ ] A response Institution ID must match the live session Institution before
      any protected state or shell-name update.
- [ ] Exactly five fields are editable; ID/type/status/timestamps and all other
      fields are never sent.
- [ ] Exact local normalization, validation, null clearing, diff, cancel, and
      no-change/no-PATCH behavior are proven.
- [ ] One active submit produces at most one PATCH and all mutation controls are
      disabled during submit/reconciliation.
- [ ] Trusted success renders only complete returned server state and exact safe
      success notice.
- [ ] No PATCH is automatically retried.
- [ ] Every uncertain outcome starts at most one automatic read-only GET and
      follows exact equal-unconfirmed/different-unconfirmed/unknown behavior
      without replay; only the exact direct PATCH response confirms success.
- [ ] Initial, loading, data, editing, validation, definite failure,
      reconciling, confirmed direct success, unconfirmed current state, outcome
      unknown, Retry, Refresh, and recovery states are deterministic and
      accessible.
- [ ] Provider disposal, generation checks, session eligibility, central 401,
      lifecycle bootstrap, and response-ID checks prevent stale/cross-account
      disclosure.
- [ ] Verified profile responses synchronize only the same live session's
      cached Institution name; all other auth state is preserved.
- [ ] Shell name updates after a verified server name change without extra
      `/auth/me`, duplicate profile GET, route reset, or draft loss.
- [ ] Exact visible labels, null/timestamp formatting, notices, messages, keys,
      responsive layout, keyboard, focus, and semantics are proven.
- [ ] Institution UUID, raw errors, protected/later-stage data, Platform
      controls, and Institution selector never appear.
- [ ] S03-FE-001/002, all Stage 1/2 auth/router/Platform behavior, and Windows
      build remain green.
- [ ] Only exact allowlisted paths change; no package/backend/docs/later-stage
      drift exists.
- [ ] Phase 2 has zero unresolved P1/P2 before delivery.

## 18. Required Automated Tests

### 18.1 DTO Matrix

Prove:

- exact GET and PATCH envelopes/resources;
- all nine Institution type values and both statuses;
- every nullable field as string and null while remaining present;
- required non-empty ID/name and canonical UUID shape;
- required valid UTC timestamp strings normalized to UTC;
- each missing required key and every wrong/null non-nullable type;
- invalid/unknown enum, malformed UUID, malformed/non-UTC timestamp;
- exact PATCH message required;
- wrong/missing PATCH message is surfaced as mutation uncertainty by the data
  source, not ordinary success;
- additive top-level/resource protected keys do not enter domain/UI; and
- malformed envelope/data/list/scalar/null input maps safely.

### 18.2 Form, Diff, and Request

Prove:

- profile-to-form initialization including all nulls;
- exact normalization for name, contact values, address, and description;
- name blank/max boundary and email/phone boundaries;
- backend remains authority beyond local validation;
- each independent change and all combined changes;
- unchanged fields omitted;
- nullable clear emits explicit null;
- non-empty multiline values are preserved exactly;
- immutable allowlist rejects unsupported/protected keys;
- no-change request is empty and cannot reach data source; and
- snapshots/equality do not retain stale prior-profile state.

### 18.3 Remote Data Source and Repository

Prove exact GET:

```text
method = GET
relative path = /institution/profile
query = absent
data/body = absent
custom tenant/header = absent
skip-auth = absent
```

Prove exact PATCH:

```text
method = PATCH
relative path = /institution/profile
query = absent
data = exact non-empty changed-fields map
Institution ID = absent from path/query/body/header
duplicate call = absent
```

Also prove:

- GET success/repository domain mapping;
- trusted PATCH success/result mapping;
- empty PATCH rejected locally with zero network request;
- GET Dio/format errors map through accepted failure boundaries;
- PATCH `badResponse`/bad-certificate definite mapping;
- every uncertain Dio type, unexpected 2xx, and malformed resource/message
  maps to the typed unknown-outcome exception;
- the controller routes a trusted-shape PATCH profile-ID mismatch through the
  same uncertain-outcome reconciliation path;
- no automatic retry/replay occurs; and
- raw backend data/message never reaches presentation.

### 18.4 Controller, Session, and Reconciliation

Prove:

- eligible direct load once and same-session rebuild deduplication;
- exact ineligible-session matrix produces zero requests/state disclosure;
- verified matching-ID load, Refresh, Retry, and explicit unknown recovery;
- a successful response with inactive Institution status is not rendered and
  triggers current-session lifecycle bootstrap reconciliation;
- leaving/disposal and returning produces a fresh GET;
- non-Institution routes produce zero profile requests;
- load failure hides prior data and Retry deduplicates;
- edit/cancel/no-change/local validation/server validation behavior;
- each allowed single/combined/null-clear PATCH body;
- submit duplicate protection and disabled mutation controls;
- trusted success replaces the entire profile, not local draft merge;
- definite 401/403/404/422/server/bad-certificate handling;
- stable lifecycle/password codes reconcile only the current session;
- no feature-owned token clearing or duplicate 401 invalidation;
- every uncertain class starts exactly one automatic GET and zero PATCH replay;
- reconciliation equal compares only changed keys, publishes current server
  state, and remains unconfirmed with no success wording;
- reconciliation different publishes current server state and remains
  unconfirmed without a success/failure misstatement;
- reconciliation error/malformed/wrong-ID produces locked outcome-unknown;
- manual reload is GET-only, deduplicated, and creates a new baseline;
- stale success/failure/reconciliation/recovery after newer operation, logout,
  account/tenant/role switch, or disposal cannot update state/shell;
- matching response ID required for all visible data; and
- unknown `409`/stable code receives safe generic handling only.

### 18.5 Auth Session Name Reconciliation

Extend the existing auth controller tests narrowly to prove:

- matching eligible Institution Admin updates only nested Institution name;
- all User and Institution fields except name remain byte/value-equivalent;
- auth status, token/storage calls, controller generation, and routing are not
  changed;
- same-name input emits no unnecessary state;
- wrong User ID, wrong Institution ID, missing/mismatched nested Institution,
  wrong role, inactive/first-login/non-auth state are no-ops;
- stale prior-account response cannot rename a newer same-role session; and
- profile controller does not render success when the live session rejects
  reconciliation.

### 18.6 Widget, Route, Accessibility, and Regression

Prove:

- exact route replaces only the Institution placeholder;
- all other Institution Admin routes remain their accepted real/placeholder
  destinations and issue zero profile requests;
- exact loading/data/error/retry/edit/submitting/reconciling/confirmed-direct-
  success/unconfirmed-current-state/outcome-unknown widgets, labels, notices,
  actions, and keys;
- all visible field order/labels/type/status/null/timestamp values;
- UUID/protected/raw fields and type/status edit/lifecycle controls absent;
- local/server errors, first invalid focus, cancel, no-change, Save/Saving, and
  disabled semantics;
- successful name update immediately changes the shell's Institution label
  without route reset, extra auth GET, or duplicate profile GET;
- `800×600` and `1440×900`, text scales `1.0`/`2.0`, long/null/multiline data,
  keyboard Tab/Enter/Space, focus, live regions, non-color status, and no
  overflow/exceptions;
- direct entry, navigation away/back, logout, global invalidation, same-role
  Institution switch, cross-role switch, and stale result isolation; and
- full Dashboard, shell, auth/router, Platform Institution edit, and bootstrap
  regressions remain green.

### 18.7 Quality Gates

From `frontend/`, run current repository-valid equivalents of:

```text
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/features/institution_admin
flutter test test/features/auth/auth_session_controller_test.dart
flutter test
flutter build windows --debug
```

Run any additional configured frontend/static/security checks required by
`frontend/AGENTS.md`. Formatting during Phase 1 is allowed; the shown command
is the final no-write format verification. Any required failure blocks PASS.

### 18.8 Scope, Secret, and Diff Verification

Before Phase 2 and again before delivery, prove:

- changed paths are a subset of Section 15 plus allowed bookkeeping;
- the approved task behavior and paired prompt did not drift during Phase 1;
- no generated/package/backend/docs/later-task file changed;
- no secret, token, credential, certificate, private environment value, or
  sensitive response fixture entered the diff;
- no raw User/Institution UUID is exposed by production UI/logging; and
- the complete diff, including owner-prepared task/prompt, was reviewed.

## 19. Manual Windows Real-Stack Smoke

Using the controlled real Laravel/PostgreSQL stack and a desktop Institution
Admin account:

1. Open `/institution-admin/institution` directly and verify one own-profile
   GET and matching shell/profile Institution name.
2. Refresh and verify current server data replaces the view.
3. Enter edit mode, cancel, and prove no PATCH.
4. Submit unchanged normalized values and prove no PATCH plus exact notice.
5. Change the Institution name and one contact field; verify one PATCH, exact
   committed values after reload, and immediate shell-name sync.
6. Clear email/phone/address/description with blank form input and verify JSON
   null persistence.
7. Trigger safe client and backend validation and verify focus/copy/no partial
   success.
8. Verify type/status/ID/settings are not editable or sent.
9. Navigate Dashboard/Users/Settings and back; verify no cross-route request or
   stale profile retention.
10. Logout/account-switch and verify old Institution profile/name never flashes.

Use automated controlled Dio tests for uncertainty/reconciliation paths that
cannot safely be induced against the real stack.

If the controlled stack is available, smoke must PASS. A smoke `FAIL` blocks
acceptance. `NOT RUN` is non-blocking only when the environment is genuinely
unavailable, the exact reason is reported, and all equivalent automated
contract/mutation/session/UI tests pass. Do not use `NOT RUN` to hide a startup,
configuration, routing, or implementation failure.

## 20. Explicit Non-Goals

- Institution type/status/lifecycle mutation.
- Institution selection, switching, route UUID, or tenant header.
- Platform Owner Institution refactor or shared cross-role profile domain.
- Institution settings or understanding-category editing.
- Teacher/Student/Parent list/detail/create/edit/lifecycle work.
- Institution Admin/Platform Owner account management.
- Logo, file, media, import/export, delete, archive, billing, audit, or support.
- Groups, relationships, topics, assessments, answers, scores, results, reports,
  or later-stage learning behavior.
- Backend, database, Docker, dependency, CI, or locked-doc changes.
- Optimistic locking, idempotency keys, background sync, offline cache, polling,
  or automatic mutation retry.
- Full generic auth-session editing; only Section 12.3 is allowed.

## 21. Stop Conditions

Stop and report before unsafe work if any of these occurs:

- a direct dependency is not `Accepted / PASS / Delivered`;
- task/prompt/index/README authority is missing, stale, or contradictory;
- current backend route/resource/message differs from Section 5;
- safe own-Institution response matching cannot be proven;
- a protected field or tenant selector appears necessary;
- a trusted PATCH success cannot be distinguished from uncertain completion;
- uncertainty cannot be handled without mutation replay;
- same-session shell-name reconciliation cannot be bounded safely;
- stale/profile disclosure cannot be prevented inside the allowlist;
- implementation requires a route-path, package, backend, docs, schema,
  Platform, Dashboard, later-stage, or non-allowlisted application change;
- Git worktree/remote/branch/history is unsafe or ambiguous;
- a secret/sensitive artifact is discovered in scope; or
- Phase 2 finds any unresolved P1/P2.

Do not widen scope, reinterpret the contract, self-approve a finding, or start
S03-FE-004 as a workaround.

## 22. Required Workflow and Delivery

### Phase 0 — Git and Authority Preflight

1. Read root `AGENTS.md`, `frontend/AGENTS.md`, this task, paired prompt,
   `tasks/README.md`, Stage 3 index, S03-INT-001, relevant locked docs, accepted
   dependencies, current implementation/tests, and Git state completely.
2. Verify this task is `Approved` and the paired prompt is present.
3. Record SHA-256 of this approved task and prompt before editing code.
4. Prove every Section 4 dependency/status/implementation on `origin/main`.
5. Verify exact approved `origin`, fetch safely, and prove
   `local main == origin/main` at the intended base commit.
6. Verify the tree is clean except only the owner-prepared S03-FE-003 task and
   paired prompt when they have not yet been committed.
7. Create/switch to:

   ```text
   task/s03-fe-003-own-institution-profile
   ```

8. Preserve unrelated user work and stop on any dirty/conflicting state.
9. Do not commit, stage for delivery, push, create a PR, or merge before Phase 2
   PASS.

### Phase 1 — Implementation and Writable Verification

Implement only this task. Only Section 15 application/test paths may change.

During Phase 1 only, update the S03-FE-003 Stage 3 index row to:

```text
Task status = In Progress
Review status = Not started
Delivery status = Not started
```

Keep this detailed task `Approved`, keep its paired prompt byte-for-byte
unchanged, and keep `tasks/README.md` on its truthful pre-acceptance gate.

Run formatter/fixes only in Phase 1, then all automated checks, manual smoke,
scope/secret checks, and complete-diff review. Do not commit or push.

### Phase 2 — Strictly Read-Only Acceptance Gate

Re-read all authority and inspect the complete diff, code, tests, request logs,
state transitions, uncertain-outcome evidence, session/shell reconciliation,
quality gates, smoke result, scope, secrets, and bookkeeping.

Phase 2 is strictly read-only:

```text
no edits
no formatter or auto-fix
no generated writes
no task/index/README status edits
no staging or commit
no push, PR, merge, or tag
no self-fixing findings
```

Classify every finding:

- `P1`: tenant/cross-account disclosure, protected data/secret exposure,
  destructive Git behavior, mutation replay, or read-only-gate violation;
- `P2`: material endpoint/resource/form/diff/state/error/reconciliation/session/
  shell/UI/accessibility mismatch, missing required test/evidence, scope drift,
  or workflow/bookkeeping inconsistency;
- `P3`: non-blocking observation that does not affect correctness, security,
  required evidence, or maintainability acceptance.

Any unresolved P1/P2 results in:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start S03-FE-004. Report all P3 findings; P3
alone does not block acceptance.

### Phase 3 — Post-Acceptance GitHub Delivery

Run only after Phase 2 PASS with zero unresolved P1/P2.

1. Change only this detailed task's metadata status from `Approved` to
   `Accepted`; do not rewrite approved behavior.
2. Change only the S03-FE-003 index row to
   `Accepted / PASS / Delivered` in the focused delivery commit.
3. Update `tasks/README.md` truthfully: Stage 3 remains `In Progress`,
   S03-FE-003 is delivered, and S03-FE-004 is the next implementation gate.
4. Preserve all later rows truthfully; do not mark S03-FE-004 accepted or
   started.
5. Preserve the paired prompt byte-for-byte and verify its Phase 0 SHA-256.
6. Keep Stage 3 open and Stage 4 not started.
7. Re-run final non-writing diff/scope/secret/status consistency checks.
8. Stage only the allowed implementation/test files, this task, unchanged
   prompt, Stage 3 index, and `tasks/README.md`.
9. Commit exactly:

   ```text
   feat(institution): add own profile UI

   Task: S03-FE-003
   ```

10. Push the exact task branch without force and open a focused PR to `main`.
11. Verify PR base/head, commits, changed-file allowlist, title/body, checks,
    reviews/comments, and mergeability. Do not bypass required checks.
12. Merge only the reviewed head using the repository-approved normal merge
    commit flow; do not squash, rebase, force-push, or rewrite shared history.
13. Fetch safely, update local `main` non-destructively, and prove:

    ```text
    implementation commit is an ancestor of origin/main
    merge commit has the expected parents
    local main == origin/main
    working tree is clean
    delivered task/index/README statuses are truthful
    Stage 3 remains In Progress
    Stage 4 remains not started
    ```

If Phase 2 passes but commit/push/PR/check/merge/sync verification cannot safely
finish, report:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Do not claim Accepted and do not start S03-FE-004.

After complete verified delivery, report:

```text
FINAL STATUS: ACCEPTED
```

## 23. Required Final Report

Report:

- Phase 0 base/origin/branch/dependency/task-prompt SHA evidence;
- exact changed files and layer responsibilities;
- exact GET/PATCH request evidence and absence of tenant input;
- resource/DTO/envelope/message/ID/timestamp evidence;
- form validation/normalization/diff/null/no-change/cancel evidence;
- trusted/definite/uncertain outcome and one-GET/no-replay evidence;
- stale/session/401/lifecycle/shell-name reconciliation evidence;
- exact UI/responsive/keyboard/focus/semantics evidence;
- focused/full test, analyze, format, build, security, and smoke results;
- Phase 2 P1/P2/P3 findings;
- scope/secret/task-prompt integrity evidence;
- commit/PR/check/merge/local-main/origin-main/clean-tree evidence; and
- one exact final status: `NOT ACCEPTED`, `DELIVERY BLOCKED`, or `ACCEPTED`.

Only after complete delivery state:

```text
Next implementation gate: S03-FE-004.
```
