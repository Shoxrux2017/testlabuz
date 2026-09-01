# TestLabUz — API Contracts

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-08-08.

This document defines the communication contract between the **TestLabUz Laravel backend** and the **Flutter frontend** for the MVP.

It is based on:

- `01-business-overview.md`
- `02-user-roles.md`
- `03-features.md`
- `04-user-flows.md`
- `05-business-rules.md`
- `06-roadmap.md`
- `07-architecture.md`
- `08-database.md`

The backend is authoritative for:

- Authentication
- Role
- Institution scope
- Group / Student / Parent-child scope
- Task lifecycle
- Attempt availability
- Homework deadline validity
- Blitz availability and timing
- Automatic/manual checking state
- Official task score
- Homework–Blitz comparison
- Final result
- Understanding category
- Result status
- Result visibility eligibility

The Flutter client must **not** independently decide or overwrite those values.

All ten MVP business decisions that previously blocked API details are now approved. This document therefore defines the affected endpoint and payload contracts explicitly rather than keeping provisional decision gates.

This API document remains an implementation draft until the final cross-document consistency audit is completed. No API behavior may contradict `05-business-rules.md`, `07-architecture.md`, or `08-database.md`.

---

# 1. API Contract Overview

## 1.1 Base URL

All MVP client endpoints use:

```text
/api/v1
```

Examples:

```text
POST /api/v1/auth/login
GET  /api/v1/topics
POST /api/v1/homework/{homework}/attempts
```

---

## 1.2 Transport

Production API communication must use:

```text
HTTPS
```

---

## 1.3 Content Types

Default request:

```http
Content-Type: application/json
Accept: application/json
```

File uploads use:

```http
Content-Type: multipart/form-data
Accept: application/json
```

Protected file downloads return the real file content only after backend authorization.

---

## 1.4 Authentication

Protected requests use Laravel Sanctum token authentication.

Header:

```http
Authorization: Bearer <token>
```

The exact token lifecycle may follow the installed Laravel/Sanctum version, but the API contract in this document must remain stable for Flutter.

---

## 1.5 UUID Identifiers

Domain resource IDs are UUID strings.

Example:

```json
{
  "id": "8c6f0a5c-70b8-4f6b-9a62-1a0d725786c1"
}
```

A valid UUID does **not** grant access.

Every resource is still subject to institution, role, and relationship authorization.

---

# 2. General API Conventions

## 2.1 Success Envelope

Single resource:

```json
{
  "data": {
    "id": "8c6f0a5c-70b8-4f6b-9a62-1a0d725786c1",
    "name": "Example"
  }
}
```

Collection:

```json
{
  "data": [
    {
      "id": "8c6f0a5c-70b8-4f6b-9a62-1a0d725786c1",
      "name": "Example"
    }
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 20,
      "total": 1,
      "last_page": 1
    }
  }
}
```

Mutation with useful updated resource:

```json
{
  "data": {
    "...": "..."
  },
  "message": "Updated successfully."
}
```

---

## 2.2 Empty Success

When no resource body is useful:

```http
204 No Content
```

Flutter must not try to decode a JSON body from `204`.

---

## 2.3 Error Envelope

All expected API errors use:

```json
{
  "message": "Human-readable message.",
  "code": "stable_machine_code",
  "errors": {},
  "request_id": "optional-correlation-id"
}
```

`errors` is always an object.

For non-validation errors:

```json
"errors": {}
```

---

## 2.4 Validation Error

HTTP:

```text
422 Unprocessable Entity
```

Example:

```json
{
  "message": "The request contains invalid data.",
  "code": "validation_failed",
  "errors": {
    "title": [
      "The title field is required."
    ],
    "duration_seconds": [
      "The duration must be greater than 0."
    ]
  },
  "request_id": "req_..."
}
```

---

## 2.5 Authentication Error

HTTP:

```text
401 Unauthorized
```

Example:

```json
{
  "message": "Authentication is required.",
  "code": "authentication_required",
  "errors": {},
  "request_id": "req_..."
}
```

Invalid login:

```json
{
  "message": "The provided login credentials are invalid.",
  "code": "invalid_credentials",
  "errors": {},
  "request_id": "req_..."
}
```

---

## 2.6 Authorization Error

HTTP:

```text
403 Forbidden
```

Example:

```json
{
  "message": "You do not have permission to perform this action.",
  "code": "forbidden",
  "errors": {},
  "request_id": "req_..."
}
```

The message must not reveal private information about an inaccessible record.

---

## 2.7 Not Found Within Scope

HTTP:

```text
404 Not Found
```

Use when the resource:

- Does not exist, or
- Exists outside the authenticated user's allowed institution/relationship scope and returning `403` would disclose private existence.

Example:

```json
{
  "message": "The requested resource was not found.",
  "code": "resource_not_found",
  "errors": {},
  "request_id": "req_..."
}
```

---

## 2.8 Business Conflict

HTTP:

```text
409 Conflict
```

Use when request format is valid but current business state blocks the action.

Example:

```json
{
  "message": "This task is closed.",
  "code": "task_closed",
  "errors": {},
  "request_id": "req_..."
}
```

---

## 2.9 Rate Limit

If Laravel/API rate limiting is triggered:

```text
429 Too Many Requests
```

Example:

```json
{
  "message": "Too many requests. Please try again later.",
  "code": "rate_limited",
  "errors": {},
  "request_id": "req_..."
}
```

---

## 2.10 Server Error

Unexpected failures:

```text
500 Internal Server Error
```

Production responses must not expose stack traces or SQL details.

Example:

```json
{
  "message": "An unexpected server error occurred.",
  "code": "server_error",
  "errors": {},
  "request_id": "req_..."
}
```

---

## 2.11 Date/Time Serialization

Server-generated authoritative instants are serialized as RFC 3339 / ISO 8601 UTC timestamps.

Example:

```text
2026-08-07T15:10:32Z
```

Each institution has one IANA timezone, for example:

```text
Asia/Tashkent
```

Teacher-facing educational date/time entry uses the institution timezone.

For user-entered deadline/schedule fields, Flutter sends RFC 3339 with an explicit offset derived from the institution timezone.

Example for `Asia/Tashkent`:

```text
2026-08-10T18:00:00+05:00
```

The backend must:

1. Resolve the authenticated institution timezone.
2. Validate that the submitted local instant/offset is valid for that timezone.
3. Convert it to the authoritative UTC instant for persistence.
4. Return authoritative timestamps in UTC.
5. Return `institution_timezone` where the client needs local display context.

Flutter displays educational deadlines and schedules in the **institution timezone**, not according to an arbitrary device timezone.

Changing the institution timezone later does not rewrite already-stored absolute timestamps.

The device clock and device timezone are never authoritative for Homework deadlines or Blitz timing.

---

## 2.12 Boolean Values

Use JSON booleans:

```json
true
false
```

Do not serialize booleans as:

```text
0 / 1
"true" / "false"
```

in the public API contract.

---

## 2.13 Numeric Scores

API score values use JSON numbers.

The backend stores and calculates scores with higher internal precision. Homework official-score selection, Homework–Blitz difference calculation, threshold comparison, and final-score calculation use the **unrounded internal values**. Understanding-category assignment uses a separate integer `category_score` derived from the final internal score (`.0`–`.5` down, `>.5` up).

User-facing score fields returned for display are rounded to **one decimal place** using standard mathematical rounding.

Example:

```json
{
  "normalized_score": 84.5,
  "display_precision": 1
}
```

A Flutter client must not recompute consistency, `category_score`, category, or the final result from rounded display values. Those fields are server-authoritative.

Question-level awarded points may contain decimal values produced by the approved partial-credit rules.

---

## 2.14 Null

Use JSON `null` when a value genuinely does not exist yet.

Example:

```json
{
  "final_score": null,
  "calculated_at": null
}
```

Do not use `0` to represent a missing score.

---

## 2.15 Client-Supplied Institution ID

For normal institution-owned create/update requests:

```text
institution_id
```

must not be accepted as authoritative ownership from the Flutter client.

The backend derives institution ownership from:

- Authenticated user context
- Authorized parent record
- Explicit platform-level Super Admin target where applicable

---

# 3. Authentication Contract

## 3.1 Login

```text
POST /api/v1/auth/login
```

### Allowed

Public endpoint.

### Request

```json
{
  "login": "teacher01",
  "password": "secret"
}
```

`login` maps to the account's stable authentication identifier (`users.login_name`).

### Success — 200

```json
{
  "data": {
    "token": "plain-text-token-returned-once",
    "token_type": "Bearer",
    "user": {
      "id": "uuid",
      "institution_id": "uuid",
      "role": "teacher",
      "full_name": "Teacher Name",
      "login_name": "teacher01",
      "email": null,
      "phone": null,
      "is_active": true,
      "must_change_password": false
    }
  }
}
```

For Platform Owner:

```json
"institution_id": null
```

### Errors

- `422 validation_failed`
- `401 invalid_credentials`
- `403 user_inactive`
- `403 institution_inactive`

### Rules

- Client cannot choose role.
- Client cannot choose institution.
- Role/institution come from persisted account data.
- Password must never be returned.
- Token must never be logged by Flutter or backend application logs.

---

## 3.2 Logout

```text
POST /api/v1/auth/logout
```

### Allowed

Authenticated users.

### Success

```text
204 No Content
```

### Rules

Revokes the current API token/session according to the approved Sanctum implementation.

---

## 3.3 Current User

```text
GET /api/v1/auth/me
```

### Success — 200

```json
{
  "data": {
    "id": "uuid",
    "institution_id": "uuid",
    "role": "teacher",
    "full_name": "Teacher Name",
    "login_name": "teacher01",
    "email": null,
    "phone": null,
    "is_active": true,
    "must_change_password": false,
    "institution": {
      "id": "uuid",
      "name": "Example School",
      "status": "active",
      "timezone": "Asia/Tashkent"
    }
  }
}
```

Platform Owner:

```json
"institution": null
```

---

## 3.4 Change Password — Technical Authentication Baseline

```text
POST /api/v1/auth/change-password
```

### Allowed

Authenticated users.

### Request

```json
{
  "current_password": "old-password",
  "new_password": "new-password",
  "new_password_confirmation": "new-password"
}
```

`current_password` is always required, including the mandatory first-login change for an administrator-created account. After successful verification and password update, the backend atomically sets `must_change_password = false`.

### Success — 204

```text
No Content
```

### Errors

- `422 validation_failed`
- `409 current_password_invalid`

### Mandatory First-Login Gate

Administrator-created Institution Admin, Teacher, Student, and Parent accounts are persisted with `must_change_password = true`. They may log in, but while the flag is true Laravel allows only:

```text
GET  /api/v1/auth/me
POST /api/v1/auth/change-password
POST /api/v1/auth/logout
```

Normal application endpoints return:

```text
403 password_change_required
```

Flutter must route the user to Change Password but is not the enforcement boundary.

---

# 4. Current User / Session Contract

The Flutter bootstrap flow uses:

```text
GET /api/v1/auth/me
```

to determine:

- Whether authentication is still valid
- Current role
- Institution
- Account status
- Institution status
- Correct application shell

Flutter must not persist role as an independent long-term authority.

Cached role may be used only for temporary UI bootstrap while the server identity is restored.

---

# 5. Error Response Contract

## 5.1 Stable Error Codes

Core MVP machine codes include:

### Authentication / Account

```text
authentication_required
invalid_credentials
user_inactive
institution_inactive
```

### Authorization / Scope

```text
forbidden
resource_not_found
cross_institution_access_denied
group_not_assigned
student_not_assigned
parent_child_relationship_required
```

### Lifecycle / Task

```text
topic_not_editable
task_not_active
task_closed
task_archived
assessment_not_assigned
attempts_exhausted
assessment_has_no_scoreable_points
institution_settings_incomplete
password_change_required
selection_limit_exceeded
official_task_requires_group_assignment
idempotency_key_reused
deadline_passed
blitz_not_active
blitz_time_expired
submission_locked
result_pair_locked
result_pair_not_configured
blitz_attempt_exception_not_allowed
blitz_attempt_exception_already_granted
blitz_normal_attempt_required
```

### Checking / Result

```text
manual_review_incomplete
score_not_ready
official_score_not_ready
result_not_ready
result_closed
result_not_ready_for_closure
official_cohort_mismatch
result_not_visible
student_result_not_released
manual_release_not_allowed
category_configuration_invalid
```

### Files

```text
unsupported_file_type
file_too_large
file_upload_failed
file_not_available
```

### General

```text
validation_failed
business_conflict
rate_limited
server_error
```

Exact error-code additions are allowed only through contract updates.

Flutter must not parse human-readable messages to decide application behavior.

---

# 6. Pagination, Search, Filter, and Sorting Contract

## 6.1 Pagination Query

```text
?page=1&per_page=20
```

Defaults:

```text
page = 1
per_page = 20
```

Maximum MVP page size:

```text
100
```

---

## 6.2 Pagination Response

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

---

## 6.3 Search

Standard free-text query:

```text
?search=keyword
```

Searchable fields depend on the resource.

Search must never bypass authorization scope.

---

## 6.4 Filtering

Use explicit query parameters.

Examples:

```text
?status=active
?role=teacher
?group_id=<uuid>
?topic_id=<uuid>
?result_status=calculated
?category=needs_revision
```

Unknown filters are rejected with:

```text
422 validation_failed
```

---

## 6.5 Sorting

Use:

```text
?sort=created_at&direction=desc
```

Allowed sort fields must be whitelisted per endpoint.

Default direction:

```text
asc
```

unless endpoint documentation states otherwise.

---

# 7. Super Admin Institution APIs

All endpoints in this section require:

```text
role = platform_owner
```

---

## 7.1 Platform Dashboard

```text
GET /api/v1/platform/dashboard
```

### Success

```json
{
  "data": {
    "institutions": {
      "total": 20,
      "active": 18,
      "inactive": 2
    },
    "users": {
      "total": 2800,
      "active": 2720
    },
    "recent_institutions": [
      {
        "id": "uuid",
        "name": "Example School",
        "type": "school",
        "status": "active",
        "created_at": "2026-08-01T10:00:00Z"
      }
    ]
  }
}
```

Exact optional dashboard metrics may evolve without changing core mutation contracts.

---

## 7.2 Institution List

```text
GET /api/v1/platform/institutions
```

### Query

```text
search
status
type
page
per_page
sort
direction
```

### Allowed Sorts

```text
name
created_at
updated_at
status
```

---

## 7.3 Create Institution

```text
POST /api/v1/platform/institutions
```

### Request

```json
{
  "name": "Example School",
  "type": "school",
  "contact_email": "info@example.uz",
  "contact_phone": "+998...",
  "address": "Samarkand",
  "description": "Optional notes",
  "status": "active"
}
```

### Success — 201

```json
{
  "data": {
    "id": "uuid",
    "name": "Example School",
    "type": "school",
    "status": "active",
    "contact_email": "info@example.uz",
    "contact_phone": "+998...",
    "address": "Samarkand",
    "description": "Optional notes",
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-07T15:00:00Z"
  },
  "message": "Institution created successfully."
}
```

### Automatic Settings Initialization

The backend creates the institution settings row in the same business operation with:

```text
timezone = Asia/Tashkent
learning_material_max_mb = 25
student_submission_max_mb = 15
acceptable_score_difference = null
blitz_timer_start_mode = null
student_result_release_mode = null
parent_result_release_mode = null
```

The null educational-policy fields are intentional and are configured later by Institution Admin.

---

## 7.4 Institution Detail

```text
GET /api/v1/platform/institutions/{institution}
```

---

## 7.5 Update Institution

```text
PATCH /api/v1/platform/institutions/{institution}
```

### Request

Only allowed platform-level fields:

```json
{
  "name": "Updated Name",
  "type": "school",
  "contact_email": "updated@example.uz",
  "contact_phone": "+998...",
  "address": "Updated address",
  "description": "Updated description"
}
```

Do not allow direct mutation of educational records through this endpoint.

---

## 7.6 Activate Institution

```text
POST /api/v1/platform/institutions/{institution}/activate
```

### Success — 200

The endpoint is idempotent. If the Institution is inactive, the backend activates it and returns the updated resource. If it is already active, the backend performs no duplicate lifecycle mutation and returns the current active resource with `200`. `institution_already_active` is not an MVP conflict code.

---

## 7.7 Deactivate Institution

```text
POST /api/v1/platform/institutions/{institution}/deactivate
```

### Success

Returns updated Institution.

### Rule

The endpoint is idempotent. Deactivation:

- Changes `active → inactive` when needed.
- Returns the current inactive resource with `200` if already inactive.
- Does not delete data.
- Blocks normal institution-user access.
- Preserves history.

---

## 7.8 Institution Admin Accounts

### List

```text
GET /api/v1/platform/institutions/{institution}/admins
```

### Create

```text
POST /api/v1/platform/institutions/{institution}/admins
```

Request:

```json
{
  "full_name": "Institution Admin",
  "login_name": "admin.school1",
  "email": null,
  "phone": "+998...",
  "password": "initial-password"
}
```

Backend sets:

```text
role = institution_admin
institution_id = path institution
must_change_password = true
```

### Update

```text
PATCH /api/v1/platform/institution-admins/{user}
```

### Activate

```text
POST /api/v1/platform/institution-admins/{user}/activate
```

### Deactivate

```text
POST /api/v1/platform/institution-admins/{user}/deactivate
```

### Rules

- Target must have `role = institution_admin`.
- Super Admin must not use these endpoints to alter Student learning records.

---

# 8. Institution Admin Profile and User APIs

All endpoints in this section require the middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:institution_admin
```

The backend derives Institution scope exclusively from the authenticated
Institution Admin. No query, body, path, or header value may select or replace
that Institution scope.

---

## 8.1 Institution Profile

```text
GET   /api/v1/institution/profile
PATCH /api/v1/institution/profile
```

Both endpoints operate only on the authenticated Institution Admin's own
Institution. They accept no client-supplied `institution_id` or Institution
UUID.

The exact public Institution profile resource is:

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

`GET /api/v1/institution/profile` accepts no query parameters or request body.
Either form of extra input returns `422 validation_failed`. Success returns
`200 OK` with the complete resource in the normal single-resource envelope and
no `message`.

`PATCH /api/v1/institution/profile` is a partial update. It accepts a JSON
object containing one or more of exactly:

```text
name
contact_email
contact_phone
address
description
```

Validation and update rules:

```text
name: when present, required, trimmed, non-empty string, maximum 200
contact_email: when present, nullable string, valid email when non-null, maximum 254
contact_phone: when present, nullable string, maximum 50
address: when present, nullable string
description: when present, nullable string
```

- Query parameters are rejected with `422 validation_failed`.
- An empty, malformed, scalar, or array JSON body is rejected with
  `422 validation_failed`.
- Unknown and protected JSON keys are rejected with `422 validation_failed`;
  the backend does not ignore them and partially apply allowed fields.
- Omitted allowed fields retain their stored values.
- Explicit JSON `null` clears `contact_email`, `contact_phone`, `address`, or
  `description`; `name` cannot be null.
- `id`, `type`, `status`, `created_by_user_id`, `deactivated_at`, `created_at`,
  `updated_at`, Institution settings, user counts, and every other field are
  read-only/backend-controlled for this endpoint.
- An exact no-op returns `200 OK` with the current resource and does not change
  `updated_at`.
- A real update is atomic and changes no lifecycle state, Institution type,
  settings, users, counts, creator data, or learning records.

PATCH success returns `200 OK`, the complete current profile resource, and:

```text
message = Institution profile updated successfully.
```

---

## 8.2 Shared Institution User Resource

All Institution User operations are scoped to the authenticated Institution
before any filter, lookup, ordering, pagination, or mutation. Eligible target
roles are exactly:

```text
teacher
student
parent
```

A missing User, a User from another Institution, or a User with role
`platform_owner` or `institution_admin` returns the same scope-safe
`404 resource_not_found` response. Client input can never replace the
authenticated Institution scope.

List, create, detail, update, activate, and deactivate use the same exact User
resource:

```json
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
```

The resource never exposes:

```text
institution_id
created_by_user_id
creator resource
password or password hash
remember token
Sanctum token
permissions
Institution settings
relationship graph
learning records, answers, scores, or results
```

The Institution is implicit from authenticated tenant scope. `role` is
included because the shared list contains all three allowed roles.

---

## 8.3 User List

```text
GET /api/v1/institution/users
```

The only accepted query keys are:

```text
role
status
search
page
per_page
sort
direction
```

Rules:

- `role` is an optional single value `teacher|student|parent`; omission
  includes all three allowed roles.
- `status` is an optional single value `active|inactive`; omission includes
  both active and inactive Users.
- `active` maps to `is_active = true`; `inactive` maps to
  `is_active = false`.
- `search` is optional, trimmed, and limited to 254 characters. A blank value
  after trimming behaves as no search filter.
- Search is a case-insensitive literal substring match across `full_name`,
  `login_name`, `email`, and `phone`. `%` and `_` are literal input, not SQL
  wildcard expansion.
- `page` is an integer with minimum 1 and default 1.
- `per_page` is an integer with minimum 1, maximum 100, and default 20.
- `sort` is `full_name|login_name|created_at|updated_at`, with default
  `full_name`.
- `direction` is `asc|desc`, with default `asc`.
- `full_name` and `login_name` ordering is case-insensitive.
- Every sort uses the User UUID as a deterministic tie-break in the same
  direction.
- Unknown query keys, unsupported values, and invalid pagination return
  `422 validation_failed`.
- A request body is rejected with `422 validation_failed`.
- Scope is applied before all filtering, search, ordering, and pagination.

Success returns `200 OK` with shared User resources and the Section 6
pagination envelope. It does not add a success `message`.

---

## 8.4 Create User

```text
POST /api/v1/institution/users
```

The endpoint accepts a JSON object containing exactly:

```text
role
full_name
login_name
email
phone
password
```

Validation:

```text
role: required, one of teacher|student|parent
full_name: required, trimmed, non-empty string, maximum 200
login_name: required, trimmed, non-empty string, maximum 191, globally unique
email: optional, nullable string, valid email when non-null, maximum 254
phone: optional, nullable string, trimmed and non-empty when non-null, maximum 50
password: required string, minimum 8, maximum 255
```

An empty, malformed, scalar, or array JSON body, an unknown/protected key, or
any query parameter returns `422 validation_failed` with no User or token side
effect. A concurrent global `login_name` conflict also returns scope-safe
`422 validation_failed` with `errors.login_name` and no database detail.

The backend atomically derives and persists:

```text
id = server-generated UUID
institution_id = authenticated Institution
created_by_user_id = authenticated Institution Admin
is_active = true
must_change_password = true
last_login_at = null
deactivated_at = null
password = secure Laravel hash of the validated password
created_at and updated_at = server timestamps
```

Creation does not log in the new User, create a Sanctum token, generate or
return a password, create relationships, or alter settings or learning data.

Success returns `201 Created`, the complete shared User resource, and:

```text
message = Institution user created successfully.
```

---

## 8.5 User Detail

```text
GET /api/v1/institution/users/{user}
```

The path UUID is the only accepted input. Query parameters or a request body
return `422 validation_failed`. Success returns `200 OK` with the complete
shared User resource in the normal single-resource envelope and no `message`.

---

## 8.6 Update User

```text
PATCH /api/v1/institution/users/{user}
```

The endpoint accepts a non-empty partial JSON object containing only:

```text
full_name
email
phone
```

Validation:

```text
full_name: when present, required, trimmed, non-empty string, maximum 200
email: when present, nullable string, valid email when non-null, maximum 254
phone: when present, nullable string, trimmed and non-empty when non-null, maximum 50
```

- Omitted fields retain their stored values.
- Explicit JSON `null` clears `email` or `phone`; `full_name` cannot be null.
- Empty, malformed, scalar, or array JSON bodies, unknown/protected keys, and
  query parameters return `422 validation_failed` with no partial mutation.
- `role`, `login_name`, password, Institution, lifecycle state,
  `must_change_password`, creator, token state, and timestamps are not editable.
- An authorized Institution Admin may update an active or inactive eligible
  User.
- An exact no-op returns the current resource without changing `updated_at`.
- A real update is atomic and cannot change lifecycle fields.

Success returns `200 OK`, the complete shared User resource, and:

```text
message = Institution user updated successfully.
```

---

## 8.7 Activate User

```text
POST /api/v1/institution/users/{user}/activate
```

The activate and deactivate endpoints in Sections 8.7 and 8.8 accept either no
body or an empty JSON object `{}`, and no query parameters. A non-empty object,
malformed JSON, scalar/array root, or query parameter returns
`422 validation_failed` with no mutation.

Required lifecycle state machine:

| Endpoint | Current state | Required result |
|---|---|---|
| `activate` | inactive | Set `is_active = true`, clear `deactivated_at`, and advance `updated_at` once |
| `activate` | active | Idempotent `200`; no write and preserve `updated_at` |
| `deactivate` | active | Set `is_active = false`, set `deactivated_at` to authoritative server time, and advance `updated_at` once |
| `deactivate` | inactive | Idempotent `200`; no write and preserve the original `deactivated_at` and `updated_at` |

Real lifecycle transitions are atomic. Concurrent same-target
update/activate/deactivate operations serialize safely so a stale write cannot
overwrite unrelated current profile or lifecycle state.

Lifecycle operations preserve the User's password, `must_change_password`,
`last_login_at`, creator/history, Institution and role, relationships, learning
data, and stored Sanctum tokens. Deactivation immediately blocks new login and
existing-token access through the accepted active-account enforcement. It does
not delete stored tokens. Reactivation does not create, delete, replace, or
restore token records; reset a password; clear `must_change_password`; update
`last_login_at`; or bypass an inactive Institution, role, relationship,
permission, or device gate. A previously stored valid token may resume only
otherwise-authorized access.

Activate success returns `200 OK`, the complete shared User resource, and:

```text
message = Institution user activated successfully.
```

---

## 8.8 Deactivate User

```text
POST /api/v1/institution/users/{user}/deactivate
```

The shared input, state-machine, concurrency, access-enforcement, token, and
history-preservation rules in Section 8.7 apply. Deactivate success returns
`200 OK`, the complete shared User resource, and:

```text
message = Institution user deactivated successfully.
```

---

# 9. Group APIs

Require Institution Admin for mutation.

Teachers/Students may receive group context through role-specific endpoints but cannot mutate Group structure.

---

## 9.1 Group List

```text
GET /api/v1/institution/groups
```

### Query

```text
search
status=active|archived
page
per_page
sort
direction
```

---

## 9.2 Create Group

```text
POST /api/v1/institution/groups
```

### Request

```json
{
  "name": "10-A",
  "level": "Grade 10",
  "subject_direction": "General",
  "description": "Optional"
}
```

Backend sets:

```text
institution_id
created_by_user_id
status = active
```

unless the API explicitly allows initial status.

Baseline:

> Newly created Group starts as `active`.

---

## 9.3 Group Detail

```text
GET /api/v1/institution/groups/{group}
```

Response may include summary counts:

```json
{
  "data": {
    "id": "uuid",
    "name": "10-A",
    "level": "Grade 10",
    "subject_direction": "General",
    "description": null,
    "status": "active",
    "teachers_count": 2,
    "students_count": 25
  }
}
```

---

## 9.4 Update Group

```text
PATCH /api/v1/institution/groups/{group}
```

---

## 9.5 Archive Group

```text
POST /api/v1/institution/groups/{group}/archive
```

### Rule

Archiving must preserve historical memberships, Topics, submissions, and results.

---

# 10. Teacher–Group and Student–Group APIs

## 10.1 Current Teachers in Group

```text
GET /api/v1/institution/groups/{group}/teachers
```

---

## 10.2 Assign Teachers to Group

```text
POST /api/v1/institution/groups/{group}/teachers
```

### Request

```json
{
  "teacher_ids": [
    "uuid-1",
    "uuid-2"
  ]
}
```

### Rules

Each target:

- Same institution
- Active or allowed account state according to management rule
- `role = teacher`

Duplicate active membership must not be created.

---

## 10.3 Remove Teacher From Group

```text
DELETE /api/v1/institution/groups/{group}/teachers/{teacher}
```

### Behavior

Ends current membership by setting relationship end time.

Does not delete historical membership.

---

## 10.4 Current Students in Group

```text
GET /api/v1/institution/groups/{group}/students
```

---

## 10.5 Assign Students to Group

```text
POST /api/v1/institution/groups/{group}/students
```

### Request

```json
{
  "student_ids": [
    "uuid-1",
    "uuid-2"
  ]
}
```

### Rules

Each target:

- Same institution
- `role = student`

---

## 10.6 Remove Student From Group

```text
DELETE /api/v1/institution/groups/{group}/students/{student}
```

Ends the current membership.

Historical task recipient snapshots/submissions/results remain unchanged.

---

# 11. Parent–Student Relationship APIs

Require Institution Admin.

---

## 11.1 Parent Connections

```text
GET /api/v1/institution/parents/{parent}/students
```

---

## 11.2 Student Parents

```text
GET /api/v1/institution/students/{student}/parents
```

---

## 11.3 Create Connection

```text
POST /api/v1/institution/parent-student-relationships
```

### Request

```json
{
  "parent_id": "uuid",
  "student_id": "uuid"
}
```

### Rules

- Same institution
- Parent role required
- Student role required
- Duplicate active relationship rejected/idempotently returned

### Success — 201

```json
{
  "data": {
    "id": "relationship-uuid",
    "parent_id": "uuid",
    "student_id": "uuid",
    "started_at": "2026-08-07T15:00:00Z",
    "ended_at": null
  }
}
```

---

## 11.4 Remove Connection

```text
DELETE /api/v1/institution/parent-student-relationships/{relationship}
```

Ends relationship.

Does not delete historical Student learning records.

---

# 12. Institution Settings APIs

Require:

```text
role = institution_admin
```

All settings apply only to the authenticated Institution Admin's institution.

Homework and Blitz attempt counts are **not configurable** in the MVP.

Fixed rules:

```text
Homework normal attempts = 3
Blitz normal attempts = 1
Blitz additional exception attempts = at most 1 per Student/Blitz
```

## 12.1 Get Assessment Settings

```text
GET /api/v1/institution/settings/assessment
```

### Success — 200

```json
{
  "data": {
    "educational_policy_configured": false,
    "acceptable_score_difference": null,
    "blitz_timer_start_mode": null,
    "student_result_release_mode": null,
    "parent_result_release_mode": null,
    "timezone": "Asia/Tashkent",
    "upload_limits": {
      "learning_material_max_mb": 25,
      "student_submission_max_mb": 15,
      "platform_learning_material_max_mb": 25,
      "platform_student_submission_max_mb": 15
    },
    "fixed_attempt_rules": {
      "homework_normal_attempts": 3,
      "blitz_normal_attempts": 1,
      "blitz_max_additional_exception_attempts": 1
    }
  }
}
```

### Approved Values

`blitz_timer_start_mode`:

```text
synchronized
individual
```

`student_result_release_mode`:

```text
automatic
manual_teacher
```

`parent_result_release_mode`:

```text
with_student
manual_teacher
hidden
```

`timezone` must be a valid supported IANA timezone identifier.

New institutions initialize:

```text
timezone = Asia/Tashkent
learning_material_max_mb = 25
student_submission_max_mb = 15
```

The four educational-policy fields shown above remain `null` until the Institution Admin saves them.

## 12.2 Update Assessment Settings

```text
PUT /api/v1/institution/settings/assessment
```

### Request

This `PUT` is a complete replacement of the assessment-policy settings. On first configuration, all fields shown below are required; the API does not support a partially configured threshold/timer/release policy through this endpoint.

```json
{
  "acceptable_score_difference": 10,
  "blitz_timer_start_mode": "individual",
  "student_result_release_mode": "manual_teacher",
  "parent_result_release_mode": "with_student",
  "timezone": "Asia/Tashkent",
  "learning_material_max_mb": 20,
  "student_submission_max_mb": 10
}
```

### Validation

```text
all request fields are required
acceptable_score_difference between 0 and 100
blitz_timer_start_mode in synchronized|individual
student_result_release_mode in automatic|manual_teacher
parent_result_release_mode in with_student|manual_teacher|hidden
timezone is valid IANA timezone
learning_material_max_mb between 1 and 25
student_submission_max_mb between 1 and 15
```

### Rules

- Institution upload limits may be lower than platform maximums but never higher.
- For API validation, **1 MB = 1,048,576 bytes**.
- Changing `blitz_timer_start_mode` affects future Blitz activations only. An active Blitz uses its activation-time snapshot.
- Changing the timezone affects future local date/time interpretation and display but must not rewrite already-stored absolute instants.
- Changing release settings must not silently rewrite the numeric content of already-calculated results.
- Fixed Homework/Blitz attempt counts are not accepted in this request.
- A dependent operation that needs an unconfigured educational-policy field returns `409 institution_settings_incomplete` with `meta.missing_fields`; unrelated institution management/draft authoring remains available.

### Success — 200

Returns the complete updated settings resource.

---

# 13. Teacher Learning Context and Topic APIs

All endpoints in this section require the middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:teacher
```

The backend derives Institution scope exclusively from the authenticated Teacher.
Teacher authorization is based on the current Teacher–Group relationship; a
client-supplied Group or Topic UUID never expands that scope.

For new or editable learning content, the Group must be `active`. An existing
Topic whose Group is archived remains preserved. While the owning Teacher still
has a current Teacher–Group membership, the Teacher may read that existing Topic
and may complete its lifecycle through `close` / `archive`, but must not create,
activate, edit, upload, replace, rename, or remove learning content in the
archived Group.

---

## 13.1 Teacher Assigned Group List

```text
GET /api/v1/teacher/groups
```

This is a read-only Teacher learning-context endpoint. It does not grant Group
administration capability.

### Query

The only accepted query keys are:

```text
search
page
per_page
sort
direction
```

Rules:

- Return only Groups from the authenticated Teacher's Institution.
- Require a current Teacher–Group membership (`ended_at is null`).
- Return only Groups whose current status is `active`.
- `search` is optional, trimmed, maximum 254 characters, and is a
  case-insensitive literal substring match across `name`, `level`, and
  `subject_direction`; `%` and `_` are literal input, not wildcard expansion.
- `page` defaults to `1` and must be at least `1`.
- `per_page` defaults to `20`, must be at least `1`, and must not exceed `100`.
- `sort` is `name|level|subject_direction`, default `name`.
- `direction` is `asc|desc`, default `asc`.
- Text sorting is case-insensitive and uses Group UUID as a deterministic
  tie-break in the same direction.
- Unknown query keys or invalid values return `422 validation_failed`.
- A request body is rejected with `422 validation_failed`.

### Success — 200

```json
{
  "data": [
    {
      "id": "group-uuid",
      "name": "9-A",
      "level": "Grade 9",
      "subject_direction": "Informatics",
      "status": "active"
    }
  ],
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 20,
      "total": 1,
      "last_page": 1
    }
  }
}
```

The exact Group resource keys are:

```text
id
name
level
subject_direction
status
```

The response does not expose Institution ownership fields, membership-history
rows, unrelated Teachers/Students, or Institution Admin mutation controls.

---

## 13.2 Teacher Topic Resource and Scope

Teacher Topic list/detail/mutation endpoints use the following public Topic
resource:

```json
{
  "id": "topic-uuid",
  "group": {
    "id": "group-uuid",
    "name": "9-A",
    "level": "Grade 9",
    "subject_direction": "Informatics",
    "status": "active"
  },
  "title": "Internet Basics",
  "description": null,
  "subject": "Informatics",
  "student_instructions": "Study the materials.",
  "lesson_at": null,
  "status": "draft",
  "activated_at": null,
  "closed_at": null,
  "archived_at": null,
  "created_at": "2026-08-22T08:00:00Z",
  "updated_at": "2026-08-22T08:00:00Z"
}
```

The Teacher Topic resource never exposes `institution_id`, raw membership rows,
storage paths, result data, or a client-writable ownership field.

Teacher read access requires:

```text
authenticated Teacher
+ same Institution
+ Topic owned by that Teacher
+ current Teacher–Group membership
```

The Group may already be archived for historical/read-only access. Ending the
Teacher–Group membership revokes future normal Teacher Topic/material access;
historical database ownership remains unchanged.

A missing Topic, foreign-Institution Topic, Topic owned by another Teacher, or
Topic outside the Teacher's current Group relationship returns the same
scope-safe:

```text
404 resource_not_found
```

---

## 13.3 Teacher Topic List

```text
GET /api/v1/teacher/topics
```

### Query

```text
group_id
status
search
page
per_page
sort
direction
```

Rules:

- Return only Topics that satisfy the Teacher read scope from Section 13.2.
- `group_id`, when supplied, must resolve inside that same Teacher scope.
- `status` is `draft|active|closed|archived`.
- `search` is an optional case-insensitive literal substring search over
  Topic title and subject.
- Standard pagination rules from Section 6 apply.
- `sort` is `title|lesson_at|created_at|updated_at`, default `created_at`.
- `direction` is `asc|desc`, default `desc`.
- Every sort uses Topic UUID as a deterministic tie-break in the same direction.
- Unknown filters/query keys are rejected with `422 validation_failed`.
- A request body is rejected with `422 validation_failed`.

Success returns `200 OK`, Topic resources from Section 13.2, and the normal
pagination envelope.

---

## 13.4 Create Topic

```text
POST /api/v1/teacher/topics
```

### Request

The endpoint accepts exactly:

```json
{
  "group_id": "uuid",
  "title": "Internet, IP, DNS and Domain",
  "description": "Topic description",
  "subject": "Informatics",
  "student_instructions": "Study the materials and complete the homework.",
  "lesson_at": null
}
```

Validation:

```text
group_id: required UUID
          must resolve to an active Group in the authenticated Institution
          with a current membership for the authenticated Teacher
title: required, trimmed, non-empty string, maximum 255
description: optional, nullable string
subject: required, trimmed, non-empty string, maximum 160
student_instructions: required, trimmed, non-empty string
lesson_at: optional, nullable RFC 3339 timestamp with explicit offset
           valid for the authenticated Institution timezone
```

- Unknown/protected JSON keys are rejected with `422 validation_failed`.
- Query parameters are rejected with `422 validation_failed`.
- An empty, malformed, scalar, or array JSON root is rejected with
  `422 validation_failed`.
- A missing, foreign-Institution, unrelated, ended-membership, or archived Group
  is scope-safe `404 resource_not_found` for Topic creation.

### Backend Sets

```text
id = server-generated UUID
institution_id = authenticated Teacher Institution
teacher_id = authenticated Teacher
status = draft
activated_at = null
closed_at = null
archived_at = null
```

### Success — 201

Returns the complete Topic resource from Section 13.2 and:

```text
message = Topic created successfully.
```

### Time Rule

If `lesson_at` is supplied, it follows the institution-timezone input contract
from Section 2.11. The backend persists the authoritative instant and returns it
in UTC.

---

## 13.5 Topic Detail

Teacher:

```text
GET /api/v1/teacher/topics/{topic}
```

The path UUID is the only accepted input. Query parameters or a request body
return `422 validation_failed`.

Success returns `200 OK` with the complete Topic resource from Section 13.2 and
no success `message`.

Student equivalent is defined in Section 29.

---

## 13.6 Update Editable Topic Metadata

```text
PATCH /api/v1/teacher/topics/{topic}
```

The endpoint accepts a non-empty partial JSON object containing only:

```text
title
description
subject
student_instructions
lesson_at
```

Example:

```json
{
  "title": "Updated title",
  "description": "Updated description",
  "subject": "Informatics",
  "student_instructions": "Updated instructions",
  "lesson_at": null
}
```

Validation follows the corresponding field rules from Section 13.4.

Rules:

- Topic read/ownership scope from Section 13.2 is required.
- The Topic Group must currently be `active`.
- Topic status must be `draft` or `active`.
- `status`, `group_id`, `teacher_id`, `institution_id`, lifecycle timestamps,
  and every other protected field are rejected, not silently ignored.
- Group/Teacher ownership is never changed by this endpoint.
- Omitted fields retain their stored values.
- Explicit `null` clears `description` or `lesson_at`; required string fields
  cannot be null.
- Query parameters, an empty/malformed/scalar/array body, or unknown keys return
  `422 validation_failed`.
- `closed` and `archived` Topics are read-only and return
  `409 topic_not_editable`.
- If the Group was archived after Topic creation, metadata mutation returns
  `409 topic_not_editable`.
- An exact no-op returns the current Topic resource without changing
  `updated_at`.
- A real update is atomic and changes no ownership or lifecycle state.

Success returns `200 OK`, the complete Topic resource, and:

```text
message = Topic updated successfully.
```

---

## 13.7 Activate Topic

```text
POST /api/v1/teacher/topics/{topic}/activate
```

### Activation Preconditions

For the `draft → active` transition, the backend requires all of the following:

- Teacher read/ownership scope from Section 13.2 still holds.
- The Topic Group is currently `active`.
- The Teacher still has a current membership in that Group.
- Required Topic metadata remains valid.
- The Topic has at least one current, non-removed Learning Material connected to
  a current, non-removed learning-material File record.

Homework is **not** a Topic-activation prerequisite. Homework authoring begins
in the later Homework stage; Topic activation in the Topics/Learning Materials
stage must be independently completable.

On success the backend sets:

```text
status = active
activated_at = authoritative server time
```

and leaves `closed_at` / `archived_at` null.

A repeated activation of an already `active` Topic is idempotent `200`, performs
no duplicate write, and preserves the original lifecycle timestamps and
`updated_at`.

Any other invalid activation transition returns:

```text
409 topic_not_editable
```

Students gain Topic access only after successful activation according to their
own current Group relationship rules.

Success returns `200 OK`, the complete Topic resource, and:

```text
message = Topic activated successfully.
```

---

## 13.8 Close Topic

```text
POST /api/v1/teacher/topics/{topic}/close
```

Required transition:

```text
active → closed
```

Rules:

- Teacher read/ownership scope from Section 13.2 is required.
- A Topic whose Group was archived after activation may still be closed by its
  owning Teacher while the Teacher's membership remains current.
- Closing preserves Topic metadata, materials, and all historical learning data.
- Connected assessment behavior, once implemented, follows the assessment/task
  close contracts; Topic closure does not hard-delete or rewrite history.
- Repeating `close` on an already `closed` Topic is idempotent `200`, performs
  no write, and preserves `closed_at` and `updated_at`.
- `draft` or `archived` → `closed` is rejected with
  `409 topic_not_editable`.

A real close sets:

```text
status = closed
closed_at = authoritative server time
```

Success returns `200 OK`, the complete Topic resource, and:

```text
message = Topic closed successfully.
```

---

## 13.9 Archive Topic

```text
POST /api/v1/teacher/topics/{topic}/archive
```

Allowed real transitions:

```text
draft → archived
closed → archived
```

Rules:

- Teacher read/ownership scope from Section 13.2 is required.
- `active → archived` is not allowed; an active Topic must be closed first.
- `archived` is terminal and historical/read-only.
- Repeating `archive` on an already `archived` Topic is idempotent `200`,
  performs no write, and preserves `archived_at` and `updated_at`.
- Any invalid archive transition returns `409 topic_not_editable`.
- Archiving preserves materials, later tasks, submissions, results, and reports.

A real archive sets:

```text
status = archived
archived_at = authoritative server time
```

Success returns `200 OK`, the complete Topic resource, and:

```text
message = Topic archived successfully.
```

---

## 13.10 Topic Lifecycle Matrix

The public Topic lifecycle is controlled only through the explicit lifecycle
endpoints. `PATCH /api/v1/teacher/topics/{topic}` never accepts arbitrary status
assignment.

| Current state | `activate` | `close` | `archive` |
|---|---|---|---|
| `draft` | `active` | `409 topic_not_editable` | `archived` |
| `active` | idempotent `200` | `closed` | `409 topic_not_editable` |
| `closed` | `409 topic_not_editable` | idempotent `200` | `archived` |
| `archived` | `409 topic_not_editable` | `409 topic_not_editable` | idempotent `200` |

No MVP endpoint returns a Topic to `draft` or reopens an archived Topic.
Lifecycle transitions are atomic and serialize safely so concurrent stale
requests cannot regress lifecycle state or overwrite authoritative timestamps.

---

# 14. Learning Material APIs

All Teacher material endpoints require the same authenticated Teacher scope as
Section 13. A material is authorized through its Topic first; File UUID or
storage metadata never grants access independently.

Supported formats:

```text
PDF
DOCX
PPT
PPTX
```

Platform hard maximum:

```text
25 MB per learning-material file
= 26,214,400 bytes
```

The effective limit is:

```text
min(
  26,214,400 bytes,
  institution.learning_material_max_mb * 1,048,576 bytes
)
```

Flutter may use the server-provided effective limit for UX. Laravel remains
authoritative and revalidates the actual upload.

Material mutation requires:

```text
owning Teacher
+ same Institution
+ current Teacher–Group membership
+ active Group
+ Topic status in draft|active
```

`closed` / `archived` Topics are read-only. If a Group is archived after Topic
creation, existing Topic/material records remain readable under the normal
Teacher/Student read rules, but Teacher material mutations return
`409 topic_not_editable`.

---

## 14.1 Topic Materials

```text
GET /api/v1/teacher/topics/{topic}/materials
```

The Topic must satisfy Teacher read scope from Section 13.2. The Group may be
archived for historical/read-only access while the Teacher membership remains
current.

### Success — 200

```json
{
  "data": [
    {
      "id": "material-uuid",
      "topic_id": "topic-uuid",
      "title": "Lesson slides",
      "file": {
        "id": "file-uuid",
        "original_name": "lesson.pptx",
        "mime_type": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        "extension": "pptx",
        "size_bytes": 1250000
      },
      "created_at": "2026-08-07T15:00:00Z",
      "updated_at": "2026-08-07T15:00:00Z"
    }
  ],
  "meta": {
    "upload": {
      "max_size_bytes": 20971520,
      "platform_max_size_bytes": 26214400,
      "allowed_extensions": [
        "pdf",
        "docx",
        "ppt",
        "pptx"
      ]
    }
  }
}
```

`meta.upload.max_size_bytes` is the current effective Institution limit in
bytes. It may change when Institution settings change and is advisory for
Flutter UX only; upload acceptance always uses the server's current limit at
request time.

`meta.upload.platform_max_size_bytes` is always:

```text
26,214,400
```

Student material listing is exposed through Student Topic APIs.

---

## 14.2 Upload Material

```text
POST /api/v1/teacher/topics/{topic}/materials
```

### Content Type

```text
multipart/form-data
```

### Fields

```text
file
title (optional)
```

Rules:

- Material mutation scope from Section 14 applies.
- `file` is required and must be a successful non-empty upload.
- Extension must be one of `pdf|docx|ppt|pptx`.
- Server-detected file type/MIME must be consistent with an approved file type;
  client filename/extension alone is not trusted.
- Actual byte size must not exceed the effective limit current at request time.
- `title`, when supplied, is nullable/optional display metadata with maximum
  length 255.
- `institution_id`, `topic_id`, `teacher_id`, `uploaded_by_user_id`, storage
  disk/key, file category, MIME, extension, size, checksum, and lifecycle fields
  are backend-controlled and are not accepted as authoritative multipart fields.
- Storage key/path is server-generated and private.
- A failed storage operation must not create a valid material attachment; a
  failed persistence operation must not leave a newly uploaded object treated
  as an attached material.

### Success — 201

```json
{
  "data": {
    "id": "material-uuid",
    "topic_id": "topic-uuid",
    "title": "Lesson slides",
    "file": {
      "id": "file-uuid",
      "original_name": "lesson.pptx",
      "mime_type": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      "extension": "pptx",
      "size_bytes": 1250000
    },
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-07T15:00:00Z"
  }
}
```

### Errors

- `422 unsupported_file_type`
- `422 file_too_large`
- `409 topic_not_editable`
- `500 file_upload_failed` when storage fails unexpectedly and no valid
  attachment is created

For `file_too_large`, the validation response must expose the effective allowed
size in the field message without relying on Flutter to calculate it.

---

## 14.3 Replace Material File

```text
POST /api/v1/teacher/materials/{material}/replace
```

Multipart:

```text
file
```

Rules:

- Material mutation scope from Section 14 applies.
- File type, MIME/type agreement, non-empty upload, and effective-size rules are
  identical to Section 14.2.
- Replacement preserves the `learning_materials` identity.
- The newly accepted file becomes the only current file represented by that
  Material; full material version history is outside the MVP.
- Storage/persistence replacement must not expose an intermediate state where a
  failed replacement destroys the previously valid current material.

Success returns `200 OK`, the current Material resource, and:

```text
message = Learning material replaced successfully.
```

---

## 14.4 Update Material Metadata

```text
PATCH /api/v1/teacher/materials/{material}
```

Request:

```json
{
  "title": "Updated display title"
}
```

Rules:

- Material mutation scope from Section 14 applies.
- The JSON body must contain exactly the `title` field.
- `title` is nullable; JSON `null` clears the optional display title.
- Non-null title must be a string with maximum length 255.
- Unknown/protected keys and query parameters return `422 validation_failed`.
- An exact no-op returns the current resource without changing `updated_at`.

Success returns `200 OK`, the current Material resource, and:

```text
message = Learning material updated successfully.
```

---

## 14.5 Remove Material

```text
DELETE /api/v1/teacher/materials/{material}
```

Rules:

- Material mutation scope from Section 14 applies.
- Removal ends current Topic material availability without deleting the Topic or
  any later Student submission/result history.
- The removed Material/File must no longer be downloadable through the protected
  file endpoint.
- Removal is historical/non-destructive at the domain-record level; full
  material version history is not created.
- Repeating removal against a material that is already outside the Teacher's
  current material scope returns scope-safe `404 resource_not_found` rather than
  exposing removed/private state.

Success:

```text
204 No Content
```

---

# 15. Homework APIs

Homework is represented by the public API resource `homework`.

Internal shared `assessments` persistence must not leak unnecessary database implementation details to Flutter.

---

## 15.1 Homework List for Topic

```text
GET /api/v1/teacher/topics/{topic}/homework
```

---

## 15.2 Create Homework

```text
POST /api/v1/teacher/topics/{topic}/homework
```

### Request

```json
{
  "title": "Homework 1",
  "description": "Optional description",
  "student_instructions": "Answer all questions.",
  "assignment_mode": "group",
  "student_ids": [],
  "deadline_at": "2026-08-10T18:00:00+05:00",
  "questions": [
    {
      "client_key": "q1",
      "type": "single_choice",
      "prompt": "What does DNS do?",
      "instructions": null,
      "points": 1,
      "position": 1,
      "configuration": {
        "options": [
          {
            "text": "Translates domain names to IP addresses",
            "is_correct": true,
            "position": 1
          },
          {
            "text": "Creates hardware",
            "is_correct": false,
            "position": 2
          }
        ]
      }
    }
  ]
}
```

### Assignment Mode

```text
group
selected_students
```

If:

```text
selected_students
```

then `student_ids` must contain eligible Students from the Teacher's authorized Group scope. Such Homework is practice/supplementary only. A Homework can be designated as result-bearing only when `assignment_mode = group`.

### Fixed Homework Attempt Contract

The request does **not** contain `attempt_limit`.

Every assigned Student receives exactly:

```text
3 normal Homework attempts
```

The Homework resource returns:

```json
{
  "attempt_policy": {
    "normal_attempts": 3,
    "official_score_policy": "highest_valid_completed"
  }
}
```

The Teacher and Institution Admin cannot override this count in the MVP.

### Deadline Input

`deadline_at` is optional.

When supplied, it must be RFC 3339 with explicit offset corresponding to the institution timezone. The backend stores the authoritative instant and returns it in UTC plus the institution timezone where useful.

### Homework Deadline Runtime Contract

At the authoritative Homework deadline:

1. New Homework attempts are rejected with `409 deadline_passed`.
2. Further answer writes are rejected after the server deadline transition.
3. Every existing `in_progress` Homework Attempt is automatically finalized from answers already saved on the server.
4. Unanswered Questions/components receive zero.
5. Answered automatic Questions are checked normally.
6. Answered manual-review Questions remain `waiting_for_teacher_review`.
7. The backend sets `finalized_at` and `finalization_reason = homework_deadline_auto_submit`; `submitted_at` remains `null`.
8. Students who never started receive no fabricated Attempt.
9. Any unused remaining normal Homework attempts become unavailable.
10. A Student submit racing with deadline finalization must produce exactly one finalization; safe retries return the same logical result and later incompatible writes/submits return a locked/late conflict.
11. The backend reconciles deadline state before returning/mutating relevant Homework Attempt resources, and the Laravel Scheduler invokes the same idempotent deadline-finalization action server-side. Scheduler delay must never make a post-deadline write valid.
12. Once fully checked, a deadline-auto-finalized Homework Attempt is eligible for the normal highest-valid-completed official-score policy unless another approved validity rule excludes it.

### Deadline-Finalized Attempt Example

```json
{
  "data": {
    "id": "attempt-uuid",
    "attempt_number": 2,
    "status": "checked",
    "submitted_at": null,
    "finalized_at": "2026-08-10T13:00:00Z",
    "finalization_reason": "homework_deadline_auto_submit",
    "checking": {
      "requires_teacher_review": false,
      "completed": true
    },
    "score": {
      "normalized_score": 72.5,
      "visible_to_student": false
    }
  }
}
```

### Success — 201

Returns the full Homework resource in `draft` state.

---

## 15.3 Homework Detail

```text
GET /api/v1/teacher/homework/{homework}
```

---

## 15.4 Update Homework

```text
PATCH /api/v1/teacher/homework/{homework}
```

Allowed only according to editing integrity rules.

Scoring-relevant fields are locked after Student activity begins.

---

## 15.5 Activate Homework

```text
POST /api/v1/teacher/homework/{homework}/activate
```

### Effects

- Validates complete Question configuration.
- Recalculates `total_possible_points` and rejects activation with `409 assessment_has_no_scoreable_points` when the total is `0`.
- For ordinary/practice Homework, resolves/snapshots eligible recipients normally.
- If the designated official Homework activates while `blitz_assessment_id` is null, creates its normal eligible whole-group recipient snapshot and uses that persisted snapshot to establish the official Topic cohort and set `cohort_snapshotted_at`. It does not create a fake Blitz or Blitz recipient rows.
- If `cohort_snapshotted_at` is already non-null, either later official task must use exactly that established persisted cohort.
- If both official tasks exist, `cohort_snapshotted_at` is null, and both tasks are still pre-activation, the first official task to activate—Homework or Blitz—establishes one common cohort from its authoritative first-activation recipient set. Stage 8 activation integration persists or reuses that exact cohort for both official assessments. It must not recalculate the cohort from later/current Group membership, and incompatible existing recipient snapshots are rejected rather than silently rewritten.
- Sets lifecycle active.

---

## 15.6 Close Homework

```text
POST /api/v1/teacher/homework/{homework}/close
```

### Stage 6 Close Boundary

The final MVP contract still requires automatic finalization of `in_progress` Attempts when Homework is closed. Until Stage 7 exposes public Homework Attempt execution and saved-answer persistence, Stage 6 must not fabricate answer finalization. If a structural `in_progress` Attempt exists in Stage 6 test/fixture state, Homework close returns `409 business_conflict`. Stage 7 replaces this temporary safety guard with the approved atomic auto-finalization behavior before public Attempt start is enabled.

### Stage 7+ Behavior

In one authoritative operation the backend:

1. Changes the Homework to closed.
2. Blocks new attempts and further Student answer writes.
3. Auto-finalizes every existing `in_progress` Attempt from answers saved before closure.
4. Sets `finalization_reason = task_closed_auto_finalize`.
5. Gives zero to unanswered components and routes answered manual-review questions to Teacher review.
6. Creates no Attempt for Students who never started.
7. Makes unused Homework attempt capacity unavailable because the task is closed.

---

## 15.7 Archive Homework

```text
POST /api/v1/teacher/homework/{homework}/archive
```

---

# 16. Question and Assignment-Type APIs

The API supports either:

1. Nested Questions during Homework/Blitz creation, or
2. Dedicated Question mutation endpoints while the task remains editable.

The dedicated endpoints are:

```text
POST   /api/v1/teacher/assessments/{assessment}/questions
PATCH  /api/v1/teacher/questions/{question}
DELETE /api/v1/teacher/questions/{question}
POST   /api/v1/teacher/assessments/{assessment}/questions/reorder

GET /api/v1/teacher/topics/{topic}/result-pair
PUT /api/v1/teacher/topics/{topic}/result-pair
```

These endpoints are internal authoring conveniences and apply equally to Homework and Blitz.

---

## 16.1 Common Question Resource

```json
{
  "id": "uuid",
  "type": "single_choice",
  "prompt": "Question text",
  "instructions": null,
  "points": 1,
  "position": 1,
  "checking_mode": "automatic",
  "configuration": {}
}
```

The MVP does **not** expose `time_limit_seconds` on individual questions. Blitz timing applies to the whole Blitz task.

---

## 16.2 Single Choice Configuration

Request:

```json
{
  "type": "single_choice",
  "prompt": "What is DNS?",
  "points": 1,
  "position": 1,
  "configuration": {
    "options": [
      {
        "text": "Option A",
        "is_correct": true,
        "position": 1
      },
      {
        "text": "Option B",
        "is_correct": false,
        "position": 2
      }
    ]
  }
}
```

Rules:

- At least 2 options
- Exactly 1 correct

---

## 16.3 Multiple Choice Configuration

```json
{
  "type": "multiple_choice",
  "prompt": "Select valid protocols.",
  "points": 2,
  "position": 2,
  "configuration": {
    "options": [
      {
        "text": "HTTP",
        "is_correct": true,
        "position": 1
      },
      {
        "text": "DNS",
        "is_correct": true,
        "position": 2
      },
      {
        "text": "Keyboard",
        "is_correct": false,
        "position": 3
      }
    ]
  }
}
```

The backend derives:

```text
max_selections = count(options where is_correct = true)
```

Student-facing Question resources expose `max_selections` but never `is_correct` or correct option identities.

Approved scoring:

```text
ratio = correctly_selected_options / total_correct_options
awarded_points = question.points * ratio
```

An empty selection earns zero. Incorrect selected options earn no credit and no additional negative penalty.

---

## 16.4 True / False Configuration

```json
{
  "type": "true_false",
  "prompt": "An IP address identifies a network endpoint.",
  "points": 1,
  "position": 3,
  "configuration": {
    "correct_value": true
  }
}
```

---

## 16.5 Short Written Answer Configuration

Automatic:

```json
{
  "type": "short_written",
  "prompt": "Write the abbreviation for Domain Name System.",
  "points": 1,
  "position": 4,
  "checking_mode": "automatic",
  "configuration": {
    "accepted_answers": [
      "DNS"
    ]
  }
}
```

Manual:

```json
{
  "type": "short_written",
  "prompt": "Explain DNS in one sentence.",
  "points": 2,
  "position": 4,
  "checking_mode": "manual",
  "configuration": {}
}
```

Automatic Short Written comparison is normalized exact matching. The backend applies the same pipeline to Student text and every accepted answer:

1. Normalize Unicode to NFC.
2. Trim leading/trailing whitespace.
3. Collapse consecutive internal whitespace to one space.
4. Apply Unicode case folding for case-insensitive comparison.
5. Normalize common Uzbek apostrophe variants to one canonical form.
6. Preserve all other punctuation and technical symbols as significant.

The MVP does not use fuzzy matching, spell correction, synonym inference, or AI interpretation.

---

## 16.6 Open Written Answer Configuration

```json
{
  "type": "open_written",
  "prompt": "Explain how DNS lookup works.",
  "points": 5,
  "position": 5,
  "checking_mode": "manual",
  "configuration": {}
}
```

---

## 16.7 File-Based Configuration

```json
{
  "type": "file_based",
  "prompt": "Upload your completed presentation.",
  "points": 10,
  "position": 6,
  "checking_mode": "manual",
  "configuration": {
    "allowed_extensions": [
      "pdf",
      "docx",
      "ppt",
      "pptx"
    ]
  }
}
```

Maximum size is not embedded as an untrusted Teacher choice unless future rules explicitly allow it.

The effective institution Student submission limit applies, capped by the 15 MB platform maximum.

---

## 16.8 Matching Configuration

```json
{
  "type": "matching",
  "prompt": "Match each term to its meaning.",
  "points": 4,
  "position": 7,
  "configuration": {
    "pairs": [
      {
        "client_key": "pair-1",
        "left": "DNS",
        "right": "Domain-name resolution"
      },
      {
        "client_key": "pair-2",
        "left": "IP",
        "right": "Network address"
      }
    ]
  }
}
```

Approved scoring:

```text
ratio = correctly_matched_pairs / total_pairs
awarded_points = question.points * ratio
```

---

## 16.9 Ordering Configuration

```json
{
  "type": "ordering",
  "prompt": "Put the steps in correct order.",
  "points": 4,
  "position": 8,
  "configuration": {
    "items": [
      {
        "text": "Enter domain name",
        "correct_position": 1
      },
      {
        "text": "DNS lookup",
        "correct_position": 2
      },
      {
        "text": "Connect to server",
        "correct_position": 3
      }
    ]
  }
}
```

Approved scoring:

```text
ratio = correctly_positioned_items / total_items
awarded_points = question.points * ratio
```

---

## 16.10 Fill-in-the-Blank Configuration

```json
{
  "type": "fill_in_blank",
  "prompt": "DNS converts {{host}} into an {{address}}.",
  "points": 2,
  "position": 9,
  "configuration": {
    "blanks": [
      {
        "key": "host",
        "position": 1,
        "accepted_answers": [
          "domain name",
          "hostname"
        ]
      },
      {
        "key": "address",
        "position": 2,
        "accepted_answers": [
          "IP address"
        ]
      }
    ]
  }
}
```

---

Approved scoring:

```text
ratio = correctly_completed_blanks / total_blanks
awarded_points = question.points * ratio
```


---

# 17. Student Homework Attempt APIs

All endpoints require:

```text
role = student
```

and assessment assignment to authenticated Student.

---

## 17.1 Student Homework List

```text
GET /api/v1/student/homework
```

### Query

```text
topic_id
status
page
per_page
sort
direction
```

### Student Homework Summary

```json
{
  "id": "homework-uuid",
  "topic": {
    "id": "topic-uuid",
    "title": "Internet Basics"
  },
  "title": "Homework 1",
  "status": "active",
  "deadline_at": "2026-08-10T18:00:00Z",
  "attempts": {
    "allowed": 3,
    "used": 1,
    "remaining": 2,
    "official_score_policy": "highest_valid_completed"
  },
  "my_status": "submitted",
  "score_visible": false
}
```

---

## 17.2 Homework Detail for Student

```text
GET /api/v1/student/homework/{homework}
```

Must hide Teacher-only answer keys/correct-answer configuration.

### Critical Rule

Student payload must **never** include:

```text
is_correct
correct_value
accepted_answers
correct_position
match_key
```

before/while answering.

---

## 17.3 Start Homework Attempt

```text
POST /api/v1/student/homework/{homework}/attempts
```

### Required Header

```http
Idempotency-Key: <client-generated-uuid>
```

If missing, return `422 validation_failed`. A safe retry with the same key and request identity returns the same logical Attempt.

### Success — 201

```json
{
  "data": {
    "id": "attempt-uuid",
    "assessment_id": "homework-uuid",
    "attempt_number": 2,
    "status": "in_progress",
    "started_at": "2026-08-07T15:00:00Z",
    "submitted_at": null,
    "deadline_at": "2026-08-10T18:00:00Z",
    "questions": [
      {
        "id": "question-uuid",
        "type": "single_choice",
        "prompt": "What does DNS do?",
        "points": 1,
        "position": 1,
        "answer_ui": {
          "options": [
            {
              "id": "option-uuid",
              "text": "..."
            }
          ]
        }
      }
    ]
  }
}
```

### Conflicts

- `409 assessment_not_assigned`
- `409 task_not_active`
- `409 attempts_exhausted`
- `409 deadline_passed`

### Fixed Attempt Rules

- Attempt numbers are limited to `1`, `2`, and `3`.
- A fourth normal Homework attempt is never created.
- Each attempt is a separate immutable historical resource after final submission.
- The backend always resolves the current official Homework score as the highest fully scored, valid, eligible completed attempt. If a later eligible attempt produces a higher score before result closure, the official Homework score and any open dependent Topic result are recalculated.
- If multiple attempts tie exactly for the highest normalized score, the attempt with the **lowest `attempt_number`** is the official attempt reference; Flutter must not choose it.

---

## 17.4 Get Attempt

```text
GET /api/v1/student/attempts/{attempt}
```

Student may view only own Attempt.

---

## 17.5 Save/Replace One Answer While In Progress

```text
PUT /api/v1/student/attempts/{attempt}/answers/{question}
```

Only while Attempt is editable.

---

## 17.6 Single Choice Answer

```json
{
  "type": "single_choice",
  "selected_option_ids": [
    "option-uuid"
  ]
}
```

Exactly one option.

---

## 17.7 Multiple Choice Answer

Student Question payload includes:

```json
{
  "answer_ui": {
    "max_selections": 2
  }
}
```

The response never exposes which options are correct. Answer request:

```json
{
  "type": "multiple_choice",
  "selected_option_ids": [
    "option-uuid-1",
    "option-uuid-2"
  ]
}
```

Laravel requires `selected_option_ids.length <= max_selections`. Exceeding the cap returns `422 selection_limit_exceeded`. An empty array is valid and scores zero.

---

## 17.8 True / False Answer

```json
{
  "type": "true_false",
  "value": true
}
```

---

## 17.9 Short/Open Written Answer

```json
{
  "type": "short_written",
  "text": "DNS"
}
```

or:

```json
{
  "type": "open_written",
  "text": "Longer explanation..."
}
```

---

## 17.10 Matching Answer

```json
{
  "type": "matching",
  "pairs": [
    {
      "left_item_id": "uuid",
      "right_item_id": "uuid"
    }
  ]
}
```

---

## 17.11 Ordering Answer

```json
{
  "type": "ordering",
  "items": [
    {
      "item_id": "uuid",
      "position": 1
    },
    {
      "item_id": "uuid",
      "position": 2
    }
  ]
}
```

---

## 17.12 Fill-in-the-Blank Answer

```json
{
  "type": "fill_in_blank",
  "values": [
    {
      "blank_id": "uuid",
      "text": "domain name"
    }
  ]
}
```

---

## 17.13 Submit Homework Attempt

```text
POST /api/v1/student/attempts/{attempt}/submit
```

### Required Header

For high-risk final submission:

```http
Idempotency-Key: <uuid>
```

### Success — 200

```json
{
  "data": {
    "id": "attempt-uuid",
    "attempt_number": 1,
    "status": "checked",
    "submitted_at": "2026-08-07T15:10:00Z",
    "checking": {
      "requires_teacher_review": false,
      "completed": true
    },
    "score": {
      "normalized_score": 84.5,
      "visible_to_student": false
    }
  },
  "message": "Homework submitted successfully."
}
```

If manual review exists:

```json
{
  "data": {
    "id": "attempt-uuid",
    "status": "waiting_for_teacher_review",
    "submitted_at": "2026-08-07T15:10:00Z",
    "checking": {
      "requires_teacher_review": true,
      "completed": false
    },
    "score": {
      "normalized_score": null,
      "visible_to_student": false
    }
  }
}
```

### Rules

After success:

- Attempt answers are locked from Student editing.
- Automatically checkable answers are checked.
- Manual answers enter review queue.
- A new attempt, while fewer than 3 normal attempts have been used and other rules allow it, is a separate resource.
- Official Homework score selection is server-authoritative and uses `highest_valid_completed`.

---

# 18. Blitz Task APIs

Teacher endpoints require authorized Teacher scope.

The MVP Blitz uses:

- One Teacher-configured **whole-Blitz duration**
- One institution-configured timer-start mode: `synchronized` or `individual`
- Exactly 1 normal Student attempt
- At most 1 additional Student-specific Teacher-approved exception attempt

## 18.1 Teacher Blitz List

```text
GET /api/v1/teacher/blitz
```

### Query

```text
topic_id
group_id
status
page
per_page
```

## 18.2 Create Blitz

```text
POST /api/v1/teacher/topics/{topic}/blitz
```

### Request

```json
{
  "title": "Topic Blitz",
  "description": null,
  "student_instructions": "Answer quickly and independently.",
  "assignment_mode": "group",
  "student_ids": [],
  "duration_seconds": 600,
  "scheduled_at": null,
  "questions": [
    {
      "type": "true_false",
      "prompt": "DNS resolves domain names.",
      "points": 1,
      "position": 1,
      "configuration": {
        "correct_value": true
      }
    }
  ]
}
```

### Rules

- `duration_seconds` is required and must be a positive integer.
- Duration applies to the **whole Blitz**, never to an individual Question.
- `attempt_limit` is not accepted.
- The institution's current `blitz_timer_start_mode` is **not** copied into the task until activation.
- `scheduled_at`, when supplied, follows the institution-timezone input contract.
- `assignment_mode = selected_students` is allowed only for practice/supplementary Blitz; only `group` Blitz may be result-bearing.
- Scheduling does not itself activate the Blitz.

### Success — 201

Returns Blitz in `draft` state and includes:

```json
{
  "attempt_policy": {
    "normal_attempts": 1,
    "max_additional_exception_attempts": 1
  }
}
```

## 18.3 Blitz Detail

```text
GET /api/v1/teacher/blitz/{blitz}
```

The Teacher resource includes:

```json
{
  "duration_seconds": 600,
  "timer_start_mode_snapshot": null,
  "activated_at": null,
  "synchronized_ends_at": null,
  "attempt_policy": {
    "normal_attempts": 1,
    "max_additional_exception_attempts": 1
  }
}
```

After activation, `timer_start_mode_snapshot` is `synchronized` or `individual`.

## 18.4 Update Blitz

```text
PATCH /api/v1/teacher/blitz/{blitz}
```

Allowed only while lifecycle and Student activity permit editing.

Teacher may update the whole-task `duration_seconds` only while the task remains safely editable.

The endpoint must reject:

```text
attempt_limit
question.time_limit_seconds
timer_start_mode
```

as Teacher-configurable fields.

## 18.5 Schedule Blitz

```text
POST /api/v1/teacher/blitz/{blitz}/schedule
```

### Request

```json
{
  "scheduled_at": "2026-08-10T09:00:00+05:00"
}
```

The backend interprets/validates this using the institution timezone and stores the authoritative instant.

Scheduling is preparation only. The Teacher still activates the Blitz during class.

## 18.6 Archive Blitz

```text
POST /api/v1/teacher/blitz/{blitz}/archive
```

Archiving preserves historical attempts, exception records, scores, and Topic results.

---

# 19. Blitz Activation and Monitoring APIs

## 19.1 Activate Blitz

```text
POST /api/v1/teacher/blitz/{blitz}/activate
```

### Required Header

```http
Idempotency-Key: <uuid>
```

### Request

```json
{}
```

The Teacher-configured duration already exists on the Blitz. The Institution Admin's current timer-start mode is snapshotted by the backend at activation.

### Synchronized Mode Success

```json
{
  "data": {
    "id": "blitz-uuid",
    "status": "active",
    "duration_seconds": 600,
    "activated_at": "2026-08-07T15:00:00Z",
    "timing": {
      "mode": "synchronized",
      "synchronized_ends_at": "2026-08-07T15:10:00Z"
    }
  },
  "message": "Blitz task activated successfully."
}
```

### Individual Mode Success

```json
{
  "data": {
    "id": "blitz-uuid",
    "status": "active",
    "duration_seconds": 600,
    "activated_at": "2026-08-07T15:00:00Z",
    "timing": {
      "mode": "individual",
      "synchronized_ends_at": null
    }
  },
  "message": "Blitz task activated successfully."
}
```

### Rules

- If `blitz_timer_start_mode` is null, return `409 institution_settings_incomplete`.
- Recalculate current Question points and return `409 assessment_has_no_scoreable_points` when `total_possible_points = 0`.
- If the Blitz belongs to the official pair, it must have `assignment_mode = group`.
- If `cohort_snapshotted_at` is already non-null, the Blitz recipient snapshot must use exactly that established persisted cohort.
- If both official tasks exist, `cohort_snapshotted_at` is null, and both tasks are still pre-activation, Blitz may itself be the first official task to activate. Its authoritative activation recipient set then establishes the common cohort, and Stage 8 activation integration persists or reuses that exact cohort for both official assessments. Later/current Group membership must not redefine it, and incompatible existing recipient snapshots are rejected rather than silently rewritten.
- `timer_start_mode_snapshot` is copied from the institution setting at activation.
- **Synchronized:** `synchronized_ends_at = activated_at + duration_seconds`.
- **Individual:** each Student receives an attempt-specific deadline when that Student starts.
- The backend clock is authoritative.
- Changing the institution setting after activation does not change the active Blitz.
- Activation is idempotent for a safe retry.

## 19.2 Close Blitz

```text
POST /api/v1/teacher/blitz/{blitz}/close
```

Closing is server-authoritative. In one operation it blocks new starts/writes and auto-finalizes every existing `in_progress` Blitz Attempt using saved answers. The backend sets `finalization_reason = task_closed_auto_finalize`; unanswered components receive zero and answered manual-review questions remain pending Teacher review. Students who never started receive no fabricated Attempt. Historical attempts and exception data are preserved.

## 19.3 Grant One Additional Student Blitz Attempt

```text
POST /api/v1/teacher/blitz/{blitz}/students/{student}/attempt-exception
```

### Required Header

```http
Idempotency-Key: <uuid>
```

### Request

```json
{
  "reason_type": "technical",
  "reason": "The Student's device lost connection and the normal attempt could not be completed properly."
}
```

`reason_type`:

```text
technical
other_valid
```

### Preconditions

The backend verifies:

- Teacher is authorized for the Blitz/Student/Group.
- Blitz belongs to the same institution.
- Student is an assigned Blitz recipient.
- Student already has normal Blitz Attempt #1.
- Attempt #1 is the attempt being excluded because of the approved exception.
- No previous exception exists for this Student/Blitz.
- The result is not closed in a way that forbids the exception.

### Effects

The grant transaction:

1. Creates the exception record.
2. Preserves Attempt #1 in history.
3. Marks Attempt #1 ineligible for official Blitz scoring.
4. Allows exactly one replacement Attempt #2.
5. Does **not** increase the whole class's attempt count.

### Success — 201

```json
{
  "data": {
    "id": "exception-uuid",
    "blitz_id": "blitz-uuid",
    "student_id": "student-uuid",
    "invalidated_attempt_id": "attempt-1-uuid",
    "replacement_attempt_id": null,
    "reason_type": "technical",
    "reason": "The Student's device lost connection and the normal attempt could not be completed properly.",
    "granted_at": "2026-08-07T15:08:00Z",
    "replacement_attempt_available": true
  },
  "message": "One additional Blitz attempt has been granted."
}
```

### Conflicts

Possible stable codes:

```text
blitz_attempt_exception_not_allowed
blitz_attempt_exception_already_granted
blitz_normal_attempt_required
result_closed
```

## 19.4 Blitz Monitoring

```text
GET /api/v1/teacher/blitz/{blitz}/monitoring
```

### Success

```json
{
  "data": {
    "blitz": {
      "id": "uuid",
      "status": "active",
      "duration_seconds": 600,
      "activated_at": "2026-08-07T15:00:00Z",
      "timing": {
        "mode": "synchronized",
        "synchronized_ends_at": "2026-08-07T15:10:00Z",
        "server_now": "2026-08-07T15:04:00Z"
      }
    },
    "summary": {
      "assigned": 25,
      "not_started": 5,
      "in_progress": 8,
      "finalized": 10,
      "waiting_for_teacher_review": 2,
      "attempt_exceptions_granted": 1
    },
    "students": [
      {
        "student": {
          "id": "uuid",
          "full_name": "Student Name"
        },
        "status": "in_progress",
        "attempt_number": 1,
        "started_at": "2026-08-07T15:01:00Z",
        "deadline_at": "2026-08-07T15:10:00Z",
        "remaining_seconds": 360,
        "finalization_reason": null,
        "score": null,
        "attempt_exception": null
      }
    ]
  }
}
```

### Rule

Monitoring is read-only educational monitoring. It must not allow the Teacher to answer on behalf of the Student or mutate live Student answers.

---

# 20. Student Blitz Attempt APIs

Require authenticated Student assigned to the Teacher-activated Blitz.

## 20.1 Active Blitz List

```text
GET /api/v1/student/blitz/active
```

Returns only currently eligible Blitz tasks.

The backend decides whether a Blitz is available.

A synchronized Blitz whose authoritative end time has passed is not startable even if the client UI is stale.

## 20.2 Student Blitz Detail

```text
GET /api/v1/student/blitz/{blitz}
```

Correct-answer configuration must never be returned.

Example:

```json
{
  "data": {
    "id": "blitz-uuid",
    "title": "Topic Blitz",
    "status": "active",
    "duration_seconds": 600,
    "timing": {
      "mode": "synchronized",
      "server_now": "2026-08-07T15:04:00Z",
      "synchronized_ends_at": "2026-08-07T15:10:00Z",
      "remaining_seconds": 360
    },
    "attempts": {
      "normal_attempts": 1,
      "normal_used": 0,
      "additional_exception_granted": false,
      "replacement_attempt_available": false
    }
  }
}
```

For individual mode before the Student starts:

```json
{
  "timing": {
    "mode": "individual",
    "server_now": "2026-08-07T15:04:00Z",
    "synchronized_ends_at": null,
    "remaining_seconds": null
  }
}
```

If the Student is outside authorized scope, use scope-safe `404 resource_not_found`.

If assigned but the Blitz is not answerable, use an appropriate `409`, such as `blitz_not_active`.

## 20.3 Start Blitz Attempt

```text
POST /api/v1/student/blitz/{blitz}/attempts
```

### Required Header

```http
Idempotency-Key: <uuid>
```

### Normal Attempt

Without an exception, only Attempt #1 may be created.

### Replacement Attempt

Attempt #2 may be created only when the backend finds the approved Student-specific exception row and the replacement has not already been used.

No Blitz Attempt #3 may exist.

### Synchronized Mode Success

```json
{
  "data": {
    "id": "attempt-uuid",
    "attempt_number": 1,
    "status": "in_progress",
    "started_at": "2026-08-07T15:04:00Z",
    "deadline_at": "2026-08-07T15:10:00Z",
    "timing": {
      "server_now": "2026-08-07T15:04:00Z",
      "mode": "synchronized",
      "remaining_seconds": 360
    },
    "questions": []
  }
}
```

A late opener receives only the time remaining until the shared synchronized deadline.

### Individual Mode Success

```json
{
  "data": {
    "id": "attempt-uuid",
    "attempt_number": 1,
    "status": "in_progress",
    "started_at": "2026-08-07T15:04:00Z",
    "deadline_at": "2026-08-07T15:14:00Z",
    "timing": {
      "server_now": "2026-08-07T15:04:00Z",
      "mode": "individual",
      "remaining_seconds": 600
    },
    "questions": []
  }
}
```

For individual mode:

```text
deadline_at = started_at + blitz.duration_seconds
```

### Conflicts

Conflict codes:

```text
assessment_not_assigned
blitz_not_active
blitz_time_expired
attempts_exhausted
blitz_attempt_exception_not_allowed
```

## 20.4 Save Blitz Answer

Uses the shared endpoint:

```text
PUT /api/v1/student/attempts/{attempt}/answers/{question}
```

Backend additionally validates:

- Attempt belongs to authenticated Student.
- Attempt is still editable.
- Server time has not passed `deadline_at`.
- Blitz is otherwise in a valid state.

If the authoritative deadline has passed:

```text
409 blitz_time_expired
```

and the backend must reconcile/finalize the timed-out Attempt before returning current state when necessary.

A device clock change must not extend answer time.

## 20.5 Submit Blitz Attempt

```text
POST /api/v1/student/attempts/{attempt}/submit
```

### Required Header

```http
Idempotency-Key: <uuid>
```

If submitted before the deadline:

```text
finalization_reason = student_submit
```

and the Attempt becomes immutable.

### Timeout Auto-Finalization

If the authoritative deadline is reached before explicit Student submission:

1. The backend stops accepting writes.
2. Saved answers are finalized automatically.
3. `finalization_reason = timeout_auto_submit`.
4. Unanswered Questions receive zero points.
5. Saved answered Questions are evaluated normally.
6. Answered Questions requiring Teacher judgment enter `waiting_for_teacher_review`.
7. The Attempt is not treated as missing merely because the Student did not press Submit.

A later explicit submit against an already timeout-finalized Attempt must not create another submission. A retry with the same idempotency key returns the original finalized logical result. A new incompatible request with a different key returns `409 submission_locked`.

### Timeout-Reconciled Attempt Resource

```json
{
  "data": {
    "id": "attempt-uuid",
    "attempt_number": 1,
    "status": "checked",
    "started_at": "2026-08-07T15:00:00Z",
    "deadline_at": "2026-08-07T15:10:00Z",
    "submitted_at": null,
    "finalized_at": "2026-08-07T15:10:00Z",
    "finalization_reason": "timeout_auto_submit",
    "checking": {
      "requires_teacher_review": false,
      "completed": true
    },
    "score": {
      "normalized_score": 70.0,
      "visible_to_student": false
    }
  }
}
```

If automatic scoring completes immediately and no manual review is required, the finalized Attempt status becomes `checked` while retaining `finalization_reason = timeout_auto_submit`. If manual review remains, `status` becomes `waiting_for_teacher_review` while `finalization_reason` remains `timeout_auto_submit`.

---

# 21. Submission and Answer APIs

The Student-facing canonical resource is:

```text
attempt
```

Teacher-facing review can use:

```text
submission
```

where `submission.id` equals the underlying finalized/pending `assessment_attempt.id`.

---

## 21.1 Teacher Submission Queue

```text
GET /api/v1/teacher/submissions
```

### Query

```text
assessment_id
topic_id
group_id
student_id
checking_status=waiting_for_teacher_review|checked
type=homework|blitz
page
per_page
sort
direction
```

Returns only Students inside Teacher's authorized scope.

---

## 21.2 Submission Detail

```text
GET /api/v1/teacher/submissions/{submission}
```

### Success

May include:

```json
{
  "data": {
    "id": "attempt-uuid",
    "assessment": {
      "id": "uuid",
      "type": "homework",
      "title": "Homework 1"
    },
    "student": {
      "id": "uuid",
      "full_name": "Student Name"
    },
    "attempt_number": 1,
    "status": "waiting_for_teacher_review",
    "answers": [
      {
        "id": "answer-uuid",
        "question": {
          "id": "question-uuid",
          "type": "open_written",
          "prompt": "Explain DNS.",
          "points": 5
        },
        "student_answer": {
          "text": "..."
        },
        "checking_status": "waiting_for_teacher_review",
        "awarded_points": null,
        "feedback": null
      }
    ]
  }
}
```

---

# 22. File Upload and Download APIs

## 22.1 Student File Answer Upload

```text
POST /api/v1/student/attempts/{attempt}/answers/{question}/file
```

### Content Type

```text
multipart/form-data
```

Field:

```text
file
```

### Rules

- Attempt belongs to authenticated Student.
- Attempt is editable.
- Question type is `file_based`.
- File extension is approved.
- File size is within the effective **15 MB (15,728,640 bytes) or lower institution limit**.
- Same institution.
- One active file answer per file-based Answer in MVP.

### Success

```json
{
  "data": {
    "answer_id": "uuid",
    "file": {
      "id": "uuid",
      "original_name": "answer.pdf",
      "extension": "pdf",
      "size_bytes": 250000
    }
  }
}
```

---

## 22.2 Protected File Download

```text
GET /api/v1/files/{file}/download
```

The endpoint accepts only the File UUID path parameter. Query parameters and a
request body are rejected with `422 validation_failed`.

Storage disk, storage key, filesystem path, or a public URL is never accepted as
client authority.

### Learning Material Authorization

For a learning-material File, the backend first resolves the current,
non-removed Learning Material and its Topic inside authenticated Institution
scope.

An authenticated Teacher may download when all are true:

```text
same Institution
+ Topic owned by authenticated Teacher
+ current Teacher–Group membership
+ Material not removed
+ File not removed
```

The Topic may be `draft`, `active`, `closed`, or `archived` for an authorized
Teacher read. Group archival by itself does not destroy historical Topic or
material access; ending the Teacher–Group membership revokes normal future
access.

An authenticated Student may download when all are true:

```text
same Institution
+ current Student–Group membership for the Topic Group
+ Topic status in active|closed|archived
+ Material not removed
+ File not removed
```

A draft Topic never grants Student material access. Group archival prevents new
learning-content creation/activation but does not by itself rewrite or delete an
already accessible historical Topic; current Student membership is still
required.

A missing File, foreign-Institution File, unrelated Topic/Group, ended
membership, draft-only Student target, removed Material, or removed File returns
the same privacy-safe:

```text
404 resource_not_found
```

Parent full learning-material file access is not required in the MVP.
Institution Admin direct full-file access remains unavailable unless a separate,
explicit support/view contract is approved; normal Institution Admin management
visibility does not itself grant binary file download.

### Submitted Answer File Authorization

Submitted-answer File authorization remains defined by its Student Attempt /
Submission scope:

- Submitting Student where rules allow own file viewing.
- Authorized Teacher reviewer.
- Permitted Institution management/support context only when a separate business
  rule explicitly grants that access.

Parent full submitted-file access is not required in the MVP.

### Success — 200

After authorization, return the real binary file body with:

```text
Content-Type = validated stored MIME type
Content-Disposition = attachment using a safely encoded original filename
```

The download response must not expose:

```text
storage_disk
storage_key
physical filesystem path
private bucket/object key
public storage URL
```

If an authorized current File record exists but the backing storage object is
unexpectedly unavailable, use the stable `file_not_available` error without
revealing internal storage paths or provider details.

---

# 23. Automatic and Manual Checking APIs

Automatic checking is internal server behavior triggered by submission.

There is no public endpoint such as:

```text
POST /score-this-answer
```

for Flutter to request arbitrary scoring.

Approved automatic scoring rules are server-owned:

- Single-choice → all-or-nothing.
- True / false → all-or-nothing.
- Multiple-choice → selection cap equals correct-option count; score is correctly selected options / total correct options.
- Matching → proportion of correctly matched pairs.
- Ordering → proportion of correctly positioned items.
- Fill-in-the-blank → proportion of correctly completed blanks.
- Short written automatic mode → all-or-nothing against accepted-answer rules.

Open written, file-based, and manual short-written answers require Teacher judgment.

Flutter must never calculate authoritative awarded points.

---

## 23.1 Manual Review Submission

```text
PUT /api/v1/teacher/submissions/{submission}/review
```

### Request

```json
{
  "answers": [
    {
      "answer_id": "uuid",
      "awarded_points": 4,
      "feedback": "Good explanation."
    },
    {
      "answer_id": "uuid-2",
      "awarded_points": 8.5,
      "feedback": null
    }
  ]
}
```

### Rules

- Teacher must be authorized for Student/Group/Assessment.
- Only manual-review Answers may be scored through this endpoint.
- `awarded_points` must be between `0` and Question `points`.
- Teacher cannot modify Student answer content.
- Review runs in a transaction.
- If all required answers become scored, backend calculates Attempt score.
- Official score selection and Topic result recalculation then follow approved policy.

### Success

```json
{
  "data": {
    "submission_id": "uuid",
    "status": "checked",
    "score": {
      "earned_points": 17.5,
      "possible_points": 20,
      "normalized_score": 87.5
    }
  },
  "message": "Submission review saved successfully."
}
```

---

## 23.2 Correct Manual Review Before Result Closure

Use the same review endpoint while:

- Result is not closed
- Correction is allowed
- Teacher remains authorized

Backend must recalculate dependent Attempt/official score/Topic result as necessary.

If closed:

```text
409 result_closed
```

---

# 24. Official Task Score APIs

Official task score is server-authoritative.

There is **no Teacher endpoint for manually selecting an official attempt** in the MVP.

## 24.1 Teacher Read Official Score

```text
GET /api/v1/teacher/assessments/{assessment}/students/{student}/official-score
```

### Homework Success

```json
{
  "data": {
    "assessment_id": "uuid",
    "assessment_type": "homework",
    "student_id": "uuid",
    "official_attempt_id": "uuid",
    "attempt_number": 2,
    "normalized_score": 87.5,
    "selection_policy_code": "highest_valid_completed",
    "selected_at": "2026-08-07T15:30:00Z"
  }
}
```

Homework resolver:

```text
consider currently completed, eligible, fully scored attempts #1..#3
select highest normalized_score
```

The resolver runs again when another eligible Homework attempt becomes fully scored before result closure. Exact highest-score ties use the lowest `attempt_number` as the official attempt reference and do not require Teacher choice.

### Normal Blitz Success

```json
{
  "data": {
    "assessment_id": "uuid",
    "assessment_type": "blitz",
    "student_id": "uuid",
    "official_attempt_id": "uuid",
    "attempt_number": 1,
    "normalized_score": 82.0,
    "selection_policy_code": "valid_normal_blitz",
    "selected_at": "2026-08-07T15:30:00Z"
  }
}
```

### Blitz With Approved Exception

When Attempt #1 has been excluded by the approved exception and valid replacement Attempt #2 is fully scored:

```json
{
  "data": {
    "assessment_id": "uuid",
    "assessment_type": "blitz",
    "student_id": "uuid",
    "official_attempt_id": "replacement-attempt-uuid",
    "attempt_number": 2,
    "normalized_score": 86.0,
    "selection_policy_code": "approved_blitz_exception_replacement",
    "selected_at": "2026-08-07T15:40:00Z"
  }
}
```

### Rules

`official_attempt_id` must point to a fully scored attempt that:

- Belongs to the same Assessment.
- Belongs to the same Student.
- Belongs to the same institution.
- Is eligible for official scoring.

## 24.2 Student Read Own Official Task Score

The Student receives official Homework/Blitz scores only through Student task/result/progress resources and only when visibility rules allow.

No generic arbitrary Student official-score lookup is required.

## 24.3 No Manual Official-Attempt Mutation

The MVP must **not** implement:

```text
PUT /api/v1/teacher/assessments/{assessment}/students/{student}/official-score
```

The Teacher may correct an underlying manual Question score before result closure. The backend then re-evaluates the official task score deterministically.

---

# 25. Topic Result Pair and Result Calculation APIs

The backend recalculates Topic results automatically when official required scores become available or valid underlying scores change.

Flutter must not send final score/category values.

A Topic may contain multiple Homework and Blitz tasks, but exactly one **whole-group Homework** and exactly one **whole-group Blitz** are designated as the official result-bearing pair. Selected-Student tasks are practice-only and cannot be designated.

## 25.1 Read Topic Result Pair — Teacher

```text
GET /api/v1/teacher/topics/{topic}/result-pair
```

### No Designation Yet

```json
{
  "data": null
}
```

### Existing Stage 6 Pair

```json
{
  "data": {
    "id": "pair-uuid",
    "topic_id": "topic-uuid",
    "homework_assessment_id": "homework-uuid",
    "blitz_assessment_id": null,
    "cohort_snapshotted_at": null,
    "locked_at": null,
    "designated_at": "2026-09-01T09:00:00Z",
    "created_at": "2026-09-01T09:00:00Z",
    "updated_at": "2026-09-01T09:00:00Z"
  }
}
```

`blitz_assessment_id` remains nullable in result-pair read resources until Stage 8 completes the pair.

## 25.2 Set or Replace Official Homework Side — Teacher (Stage 6)

```http
PUT /api/v1/teacher/topics/{topic}/result-pair
Content-Type: application/json
```

### Request

```json
{
  "homework_assessment_id": "homework-uuid"
}
```

### Backend Validation

- The Teacher is authorized for the same Topic/Group.
- The Homework candidate belongs to the same Topic/institution and has type `homework`.
- The candidate has `assignment_mode = group`; a selected-Student Homework returns `409 official_task_requires_group_assignment`.
- The candidate is an eligible draft or active Homework.
- A candidate with existing Student activity cannot newly become official.
- If an eligible active candidate is designated before any Student Attempt, its existing persisted whole-group recipient snapshot establishes the official cohort.
- Exactly one result-pair row exists per Topic after success.
- Before lock, replacement is allowed only when the backend eligibility rules permit it.
- Once official Homework Student activity locks the designation/cohort, replacing the Homework returns `409 result_pair_locked`.
- A same-target PUT is idempotent.
- Stage 6 does not require or accept a Teacher-supplied `blitz_assessment_id`.

### Conflict

```text
409 result_pair_locked
```

A designated result-bearing task must not be replaced after Student attempts have begun in a way that changes the meaning of existing work.

Stage 8 extends and completes this Topic-level contract by filling the previously null official Blitz side. It does not replace the locked Homework side.

## 25.3 Topic Results List — Teacher

```text
GET /api/v1/teacher/topics/{topic}/results
```

### Query

```text
result_status
category
consistency
search
page
per_page
sort
direction
```

### Success Item

Public score fields are server-rounded to one decimal place for display.

```json
{
  "id": "result-uuid",
  "student": {
    "id": "uuid",
    "full_name": "Student Name"
  },
  "result_pair": {
    "id": "pair-uuid",
    "homework_assessment_id": "uuid",
    "blitz_assessment_id": "uuid"
  },
  "homework": {
    "official_attempt_id": "uuid",
    "official_score": 88.0
  },
  "blitz": {
    "official_attempt_id": "uuid",
    "official_score": 84.0
  },
  "score_difference": 4.0,
  "acceptable_difference_used": 10.0,
  "calculation_method": "average",
  "final_score": 86.0,
  "display_precision": 1,
  "consistency": "consistent",
  "category": {
    "code": "understood_well",
    "label": "Understood well"
  },
  "result_status": "calculated",
  "missing_component": null,
  "visibility": {
    "student_release_mode_used": "manual_teacher",
    "student_visible": false,
    "student_visible_at": null,
    "parent_release_mode_used": "with_student",
    "parent_visible": false,
    "parent_visible_at": null
  }
}
```

### Calculation Rule

Internally, using unrounded values:

```text
H = official Homework score
B = official Blitz score
D = abs(H - B)
T = institution acceptable difference
```

If:

```text
D <= T
```

then:

```text
final = (H + B) / 2
consistency = consistent
calculation_method = average
```

If:

```text
D > T
```

then:

```text
final = B
consistency = inconsistent
calculation_method = blitz
```

The backend derives integer `category_score` from the unrounded final value: fractional part `.0` through `.5` rounds down; fractional part greater than `.5` rounds up. Understanding category is resolved from that integer score.

## 25.4 Topic Result Detail — Teacher

```text
GET /api/v1/teacher/topics/{topic}/results/{student}
```

Returns the full explainable result snapshot, including relevant official-attempt references, result-pair identity, release policy snapshots, and Teacher feedback where available.

## 25.5 Recalculate Open Result

```text
POST /api/v1/teacher/topics/{topic}/results/{student}/recalculate
```

### Allowed

Authorized Teacher only.

### Request

```json
{}
```

### Rule

Client cannot supply:

```text
official_homework_score
official_blitz_score
score_difference
final_score
category
consistency
calculation_method
```

The backend recalculates from the current eligible underlying scoring state and approved result pair.

### Conflict

```text
409 result_closed
```

## 25.6 Close Result

```text
POST /api/v1/teacher/topics/{topic}/results/{student}/close
```

### Preconditions

The result must be terminal for this Student+Topic:

- `calculated` with both official task scores, all required manual review complete, no relevant in-progress official Attempt, and no approved replacement Blitz Attempt still pending; **or**
- definitive `not_completed` because required work can no longer validly be completed.

`waiting_for_homework`, `waiting_for_blitz`, and `waiting_for_teacher_review` are rejected with `409 result_not_ready_for_closure`. Closure does not require class-wide task closure and does not require Student/Parent visibility.

After closure:

- Normal scoring correction is blocked.
- New Blitz exception grants for this Student/result are blocked.
- Result-pair/cohort replacement is blocked.
- Recalculation and official-score replacement are blocked.
- Numeric result/category data is read-only in the MVP.
- Visibility/release remains a separate controlled concern.

---

# 26. Understanding Category APIs

## 26.1 Get Institution Categories

```text
GET /api/v1/institution/understanding-categories
```

### Allowed

Institution Admin.

Teacher may receive category definitions through Teacher settings/report resources where needed, but does not manage them.

### Success

If category ranges have not yet been configured for a new Institution, return:

```json
{
  "data": [],
  "meta": {
    "configured": false
  }
}
```

After configuration, return:

```json
{
  "data": [
    {
      "code": "understood_well",
      "label": "Understood well",
      "min_score": 86,
      "max_score": 100,
      "sort_order": 1
    },
    {
      "code": "not_completed",
      "label": "Not completed",
      "min_score": null,
      "max_score": null,
      "sort_order": 5
    }
  ]
}
```

---

## 26.2 Update Institution Categories

```text
PUT /api/v1/institution/understanding-categories
```

### Request

```json
{
  "categories": [
    {
      "code": "understood_well",
      "min_score": 86,
      "max_score": 100,
      "sort_order": 1
    },
    {
      "code": "partially_understood",
      "min_score": 66,
      "max_score": 85,
      "sort_order": 2
    },
    {
      "code": "needs_revision",
      "min_score": 50,
      "max_score": 65,
      "sort_order": 3
    },
    {
      "code": "needs_teacher_support",
      "min_score": 0,
      "max_score": 49,
      "sort_order": 4
    },
    {
      "code": "not_completed",
      "min_score": null,
      "max_score": null,
      "sort_order": 5
    }
  ]
}
```

### Validation

Backend validates entire set transactionally:

- Exactly approved codes
- Numeric categories cover 0–100
- No gaps
- No overlaps
- Logical ordering
- Not completed remains non-numeric

Historical closed results are not silently recalculated. Range values are inclusive integers covering every integer 0–100 exactly once. Category assignment first derives `category_score` from the internal final score (`.0`–`.5` down, `>.5` up) and then applies these ranges. The first successful `PUT` creates the complete configured category set transactionally. Topic result calculation is blocked with `409 category_configuration_invalid` until a valid complete set exists.

---

# 27. Result Release and Visibility APIs

Calculation and release are separate.

Institution settings:

```text
student_result_release_mode = automatic | manual_teacher
parent_result_release_mode = with_student | manual_teacher | hidden
```

A Parent must never receive a result before the Student result is released.

## 27.1 Read Visibility

Teacher result endpoints include:

```json
{
  "visibility": {
    "student_release_mode_used": "manual_teacher",
    "student_visible": false,
    "student_visible_at": null,
    "parent_release_mode_used": "with_student",
    "parent_visible": false,
    "parent_visible_at": null
  }
}
```

Release actions change visibility only.

They must not change:

- Homework score
- Blitz score
- Difference
- Calculation method
- Final score
- Category
- Consistency
- Result calculation status

## 27.2 Automatic Student Release

When the result snapshot uses:

```text
student_result_release_mode = automatic
```

the backend sets Student visibility when:

- Required Homework official score exists.
- Required Blitz official score exists.
- All required Teacher review is complete.
- Final result is calculated.

No Teacher release call is required.

If Parent mode is `with_student`, Parent visibility begins at the same release event.

## 27.3 Manual Student Release

When the result snapshot uses:

```text
student_result_release_mode = manual_teacher
```

the authorized Teacher uses:

```text
POST /api/v1/teacher/topics/{topic}/results/{student}/release/student
```

### Request

```json
{}
```

### Preconditions

- Result is calculated.
- Teacher is authorized.
- Student is not already visible, unless handled idempotently.

### Success

Returns updated Topic result visibility.

If Parent mode is `with_student`, Parent visibility is also activated by this same Student release.

## 27.4 Manual Parent Release

Only when the result snapshot uses:

```text
parent_result_release_mode = manual_teacher
```

the authorized Teacher uses:

```text
POST /api/v1/teacher/topics/{topic}/results/{student}/release/parent
```

### Preconditions

- Student result is already visible.
- Parent mode is `manual_teacher`.
- Teacher is authorized.

### Rule

If Student visibility does not yet exist:

```text
409 business_conflict
```

with a specific code such as:

```text
student_result_not_released
```

If Parent mode is `hidden`, manual Parent release is not allowed.

When Parent visibility is active, the result is visible to all currently authorized Parents connected to that Student; the result row does not create a separate release state per Parent.

## 27.5 Parent Mode `with_student`

No separate Parent release endpoint call is required.

Parent visibility begins when Student visibility begins.

## 27.6 Parent Mode `hidden`

`parent_visible_at` remains null.

Parent progress APIs may still show non-result progress information allowed by the product, but must not expose the hidden Topic score/category.

## 27.7 No Unrelease Endpoint

The MVP does not define reversing a released result.

Do **not** implement an unrelease/hide-after-release endpoint unless a later approved business rule introduces it.

---

# 28. Teacher Progress and Report APIs

Require Teacher and authorized scope.

---

## 28.1 Teacher Dashboard

```text
GET /api/v1/teacher/dashboard
```

Possible MVP response:

```json
{
  "data": {
    "assigned_groups": 4,
    "active_topics": 8,
    "active_homework": 6,
    "upcoming_or_active_blitz": 3,
    "waiting_for_teacher_review": 12,
    "needs_revision": 18,
    "needs_teacher_support": 6,
    "large_score_differences": 7
  }
}
```

---

## 28.2 Group Progress

```text
GET /api/v1/teacher/groups/{group}/progress
```

### Query

```text
topic_id
result_status
category
page
per_page
```

---

## 28.3 Topic Progress

Canonical detailed result endpoint:

```text
GET /api/v1/teacher/topics/{topic}/results
```

No second duplicate formula should exist in a report service.

---

## 28.4 Student Progress

```text
GET /api/v1/teacher/students/{student}/progress
```

### Rule

Student must belong to an active/current or historically authorized Teacher Group context according to report access policy.

Baseline for daily Teacher access:

> Teacher sees Students in currently assigned Groups.

Historical/report expansion beyond current relationship should be explicitly defined before implementation if required.

---

# 29. Student Progress APIs

Require Student.

---

## 29.1 Student Dashboard

```text
GET /api/v1/student/dashboard
```

Returns:

- Assigned Topics
- Active Homework
- Deadlines
- Attempts
- Active Blitz
- Waiting review
- Released results
- Topics needing revision/support

Only own data.

---

## 29.2 Student Topic List

```text
GET /api/v1/student/topics
```

### Query

```text
status
search
page
per_page
```

Only assigned accessible Topics.

---

## 29.3 Student Topic Detail

```text
GET /api/v1/student/topics/{topic}
```

### Success

```json
{
  "data": {
    "id": "uuid",
    "title": "Internet Basics",
    "description": "...",
    "subject": "Informatics",
    "student_instructions": "...",
    "status": "active",
    "materials": [
      {
        "id": "material-uuid",
        "title": "Lesson slides",
        "file": {
          "id": "file-uuid",
          "original_name": "lesson.pptx",
          "extension": "pptx",
          "size_bytes": 1000000
        }
      }
    ],
    "homework": [],
    "blitz_status": "not_available",
    "result_status": "waiting_for_homework"
  }
}
```

No correct answer keys.

---

## 29.4 Student Progress

```text
GET /api/v1/student/progress
```

### Query

```text
result_status
category
page
per_page
```

---

## 29.5 Student Topic Result

```text
GET /api/v1/student/topics/{topic}/result
```

### If Not Released

The API returns allowed progress/calculation status while withholding all unreleased score/category data.

```json
{
  "data": {
    "topic_id": "uuid",
    "result_status": "calculated",
    "visible": false,
    "homework_score": null,
    "blitz_score": null,
    "final_score": null,
    "category": null
  }
}
```

### If Released

```json
{
  "data": {
    "topic_id": "uuid",
    "result_status": "calculated",
    "visible": true,
    "homework_score": 88.0,
    "blitz_score": 84.0,
    "final_score": 86.0,
    "display_precision": 1,
    "consistency": "consistent",
    "category": {
      "code": "understood_well",
      "label": "Understood well"
    }
  }
}
```

Scores are presentation-rounded to one decimal place. The client must not recalculate category/consistency from these display values.

The backend applies the institution's Student release mode.

Normative behavior:

> Return allowed progress/status without unreleased score data. Hidden scores/categories must not be serialized to the Student.

---

# 30. Parent Progress APIs

Require Parent.

All Student references must be active Parent-child relationships.

---

## 30.1 Connected Children

```text
GET /api/v1/parent/children
```

### Success

```json
{
  "data": [
    {
      "id": "student-uuid",
      "full_name": "Student Name"
    }
  ]
}
```

---

## 30.2 Child Dashboard

```text
GET /api/v1/parent/children/{student}/dashboard
```

Shows only allowed progress.

---

## 30.3 Child Progress

```text
GET /api/v1/parent/children/{student}/progress
```

### Query

```text
result_status
category
page
per_page
```

---

## 30.4 Child Topic Progress

```text
GET /api/v1/parent/children/{student}/topics/{topic}
```

Returns:

- Topic title
- Homework completion
- Blitz completion
- Allowed released scores
- Final result only when Parent visibility is active
- Category only when Parent visibility is active
- Teacher feedback only when visible/available

The backend enforces the result's Parent release-mode snapshot:

```text
with_student
manual_teacher
hidden
```

A Parent must never receive the Topic result before the Student result is released.

Parent must never receive Student-edit controls.

---

# 31. Institution Report APIs

Require Institution Admin.

---

## 31.1 Institution Dashboard

```text
GET /api/v1/institution/dashboard
```

The endpoint accepts no query parameters or request body. Either form of extra
input returns `422 validation_failed`. Scope is always the authenticated
Institution Admin's own Institution.

The exact Stage 3 response is:

```json
{
  "data": {
    "users": {
      "teachers": 30,
      "students": 600,
      "parents": 450
    }
  }
}
```

Counting rules:

- Count only own-Institution Users with role `teacher`, `student`, or `parent`.
- Each value is the total of active and inactive accounts for that role.
- Exclude Institution Admin and Platform Owner accounts.
- Stage 3 includes no active-count split, Group metrics, or Learning metrics.
- Later stages may add Group or Learning dashboard blocks additively without
  changing this Stage 3 `users` contract.

---

## 31.2 Institution Progress Report

```text
GET /api/v1/institution/reports/progress
```

### Query

```text
group_id
teacher_id
topic_id
student_id
result_status
category
page
per_page
```

### Rules

- Own institution only
- Report filter cannot expand scope
- Institution Admin receives management/progress data
- Endpoint must not expose unnecessary protected Student answer content

---

# 32. Platform Statistics APIs

Require Platform Owner.

---

## 32.1 Platform Statistics

```text
GET /api/v1/platform/statistics
```

May include:

- Institution counts
- Active/inactive institution counts
- User totals
- Basic activity summary

Must not become a backdoor for raw daily Student answers/results.

Advanced analytics is Post-MVP.

---

# 33. Authorization and Tenant-Scoping Contract

This section is mandatory for every implementation task.

---

## 33.1 Server Scope Order

For protected requests, backend checks all applicable:

1. Authentication
2. User active state
3. Institution active state
4. Role
5. Institution ownership
6. Group relationship
7. Topic/Assessment assignment
8. Teacher ownership/assignment
9. Student ownership
10. Parent-child relationship
11. Lifecycle/status
12. Deadline/time/attempt rules
13. View vs edit permission

---

## 33.2 Client Must Not Set Ownership

Reject/ignore ownership fields that must be server-derived.

Examples:

```text
institution_id
teacher_id
student_id (when authenticated Student is owner)
created_by_user_id
uploaded_by_user_id
official score
final score
category
result consistency
```

Path/resource relationships may contain Student IDs only where the authenticated role is authorized to target that Student.

---

## 33.3 Cross-Institution Resource IDs

If a user supplies a UUID from another institution, the API must not return the other institution's private metadata.

Use scope-safe:

```text
404 resource_not_found
```

or `403` only when disclosure does not create a privacy issue.

---

## 33.4 Teacher Scope

Teacher Topic/material reads require:

```text
teacher.institution_id == resource.institution_id
+ resource is owned/authorized for that Teacher
+ current Teacher–Group membership
```

For creation, activation, metadata editing, and learning-material mutation, the
Group must additionally be `active`. An archived Group cannot receive new or
changed active learning content. Existing Topic/material records remain
preserved; while the Teacher membership remains current, the owning Teacher may
read them and may perform only the Topic `close` / `archive` lifecycle actions
explicitly allowed by Section 13.

Ending the Teacher–Group membership revokes future normal Teacher learning
access without reassigning or deleting historical records.

---

## 33.5 Student Scope

Student attempts require:

- Authenticated Student owns target recipient
- Assessment assigned to Student
- Task in valid lifecycle
- Fixed attempt rule permits a new Attempt
- Required Student-specific Blitz exception exists for Blitz Attempt #2
- Deadline/time is valid

---

## 33.6 Parent Scope

Parent read requires current explicit:

```text
parent_student_relationship
```

Knowing Student UUID is insufficient.

---

## 33.7 File Scope

File endpoint authorization must resolve the connected resource first.

Never authorize merely because:

```text
file.id exists
```

---

# 34. Idempotency and Concurrency Rules

## 34.1 Idempotency Header

The following client mutations **require**:

```http
Idempotency-Key: <client-generated-uuid>
```

- Start Homework Attempt
- Start Blitz Attempt
- Final Attempt Submit
- Blitz Activate
- Blitz attempt exception grant

Missing header → `422 validation_failed`. The same key with the same request identity returns the same logical result. Reusing the same key with a materially different request returns `409 idempotency_key_reused`. Manual review, result-pair updates, result calculation, and release use their documented transactional/state guards and do not require this header in the MVP.

The persistence mechanism is internal infrastructure and must not change this public contract.

---

## 34.2 Double Submit

If the same Attempt is already submitted:

- Same idempotency key → return original successful result
- Different new request after lock → `409 submission_locked`

---

## 34.3 Double Blitz Activation

Activation is idempotent when the Blitz is already active.

Do not create a second independent active session accidentally.

---

## 34.4 Attempt Number Race

Backend must atomically calculate/create the next Attempt number.

Two simultaneous requests must not create duplicate:

```text
assessment_id + student_id + attempt_number
```

---

## 34.5 Review Concurrency

Manual review update must validate current state.

If result/submission changed incompatibly, return:

```text
409 business_conflict
```

with a more specific machine code where defined.

---

# 35. Resolved MVP Business Decisions in the API Contract

The ten previously decision-gated areas are now fixed API contracts.

## DEC-01 — Official Score Across Multiple Attempts

Homework:

```text
3 normal attempts
official = highest valid completed score
selection_policy_code = highest_valid_completed
```

Blitz:

```text
1 normal attempt
official = valid normal attempt #1
```

When the approved exception replaces invalid normal Attempt #1:

```text
replacement Attempt #2 becomes official
selection_policy_code = approved_blitz_exception_replacement
```

There is no Teacher-selected official-attempt endpoint.

## DEC-02 — Technical Attempt Exception

The Teacher may grant exactly one additional Blitz attempt to one Student with a required reason.

Endpoint:

```text
POST /api/v1/teacher/blitz/{blitz}/students/{student}/attempt-exception
```

The original attempt remains historical and becomes ineligible for official scoring.

## DEC-03 — Blitz Timer Start Mode

Institution setting:

```text
synchronized
individual
```

Teacher configures one whole-Blitz `duration_seconds`.

No per-question timers exist in the MVP.

## DEC-04 — Blitz Timeout Behavior

At the authoritative Attempt deadline:

- Saved work is auto-finalized.
- Further answer writes are rejected.
- Unanswered Questions receive zero.
- Saved answers are checked normally.
- Manual answers remain waiting for Teacher review.
- `finalization_reason = timeout_auto_submit`.

## DEC-05 — Partial Credit

Server scoring:

- Multiple-choice → selection cap = correct-option count; score = correctly selected options / total correct options; empty = zero.
- Matching → correct pairs / total pairs.
- Ordering → correctly positioned items / total items.
- Fill-in-the-blank → correct blanks / total blanks.
- Single-choice and true/false → all-or-nothing.
- Manual answer types → Teacher-awarded points within limits.

## DEC-06 — Score Precision

Backend calculation uses unrounded internal precision.

Public display score fields use:

```text
1 decimal place
```

Category assignment uses integer `category_score` derived from the unrounded final score (`.0`–`.5` down, `>.5` up).

## DEC-07 — Result Release

Student mode:

```text
automatic
manual_teacher
```

Parent mode:

```text
with_student
manual_teacher
hidden
```

Parent visibility never precedes Student visibility.

## DEC-08 — Upload Limits

Platform maximums:

```text
Learning material: 25 MB
Student submission: 15 MB
```

Institution may configure lower limits.

## DEC-09 — Timezone

- Institution has one IANA timezone.
- User-entered education times are interpreted in that timezone.
- API time input uses RFC3339 with explicit offset.
- Backend persists authoritative UTC instants.
- Device clock/timezone cannot change deadlines or Blitz timing.

## DEC-10 — Result-Bearing Task Pair

A Topic may contain multiple Homework and Blitz tasks, but exactly one whole-group Homework + one whole-group Blitz form the eventual official result-bearing pair; selected-Student tasks are practice-only and both official tasks share one snapshotted Topic cohort. The Stage 6 PUT designates only the Homework side and persists a null Blitz reference; Stage 8 completes the same row with the official Blitz.

Teacher API:

```text
GET /api/v1/teacher/topics/{topic}/result-pair
PUT /api/v1/teacher/topics/{topic}/result-pair
```

Once Student activity locks the pair, replacement is rejected.

---

## Post-Audit Locked API Behaviors

- New-institution educational-policy settings may be null until Institution Admin setup; dependent operations return `institution_settings_incomplete`.
- Administrator-created users have mandatory first-login password change enforced by Laravel.
- Assessment activation rejects zero total points with `assessment_has_no_scoreable_points`.
- Multiple-choice selection overflow returns `selection_limit_exceeded`.
- Automatic Short Written checking is deterministic normalized exact matching.
- Homework highest-score ties select the lowest `attempt_number`.
- Teacher task close auto-finalizes in-progress Attempts with `task_closed_auto_finalize`.
- Homework deadline auto-finalizes in-progress Homework Attempts with `homework_deadline_auto_submit`.
- Topic Result close enforces terminal-state preconditions.
- Institution activate/deactivate are idempotent and do not use already-active/inactive conflicts.
- High-risk idempotency headers are required exactly where Section 34.1 specifies.

---

# 36. MVP API Scope

## 36.1 Included Endpoint Groups

MVP includes API support for:

1. Authentication
2. Current user/session
3. Super Admin dashboard
4. Institution management
5. Institution Admin management
6. Institution user management
7. Groups
8. Teacher-group relationships
9. Student-group relationships
10. Parent-student relationships
11. Institution assessment/timing/release/timezone/upload settings
12. Understanding categories
13. Teacher assigned Groups and Topics
14. Learning Materials
15. Homework authoring
16. Nine Question types
17. Student Homework attempts
18. Student Answers
19. Student file submissions
20. Blitz authoring
21. Blitz scheduling
22. Blitz activation
23. Blitz monitoring
24. Student Blitz attempts
25. Student-specific Blitz attempt exception
26. Automatic checking
27. Manual Teacher checking
28. Official task scores
29. Topic result-pair designation
30. Topic result calculation
31. Topic result status
32. Student and Parent result visibility/release
33. Teacher dashboard/progress
34. Student dashboard/progress
35. Parent child/progress
36. Institution dashboard/report
37. Platform basic statistics
38. Protected file download

---

## 36.2 Explicitly Excluded From MVP API

Do not create MVP endpoints for:

- AI generation
- AI checking
- AI recommendations
- Audio/video processing
- Speaking/listening tasks
- Coding tasks
- Group projects
- Peer review
- Plagiarism detection
- Advanced question bank
- Random test generation
- Advanced anti-cheating
- Device monitoring
- Live classroom competition
- Chat
- Messaging
- Notifications
- Billing/subscriptions
- Invoices
- External integrations
- Custom roles
- Permission builder
- Offline synchronization
- Gamification
- Certificates
- Formal result appeals
- Advanced audit report UI

---

# 36A. Homework Deadline API Decision — Resolved

The public API now has one deterministic Homework deadline contract. An already `in_progress` Homework Attempt is auto-finalized from saved server state at the authoritative deadline. The resource records `finalized_at`, `finalization_reason = homework_deadline_auto_submit`, and `submitted_at = null`; unanswered components receive zero, manual-review components remain pending, and no empty Attempt is created for a never-started Student. After the deadline, new attempts return `409 deadline_passed`, late answer/final-submit mutations are rejected, and concurrent/retried finalization is protected so only one logical finalization occurs.

---

# 37. API Definition of Done

`09-api-contracts.md` is **locked for MVP implementation** because the final cross-document audit confirmed all of the following:

1. Base URL/versioning is approved.
2. JSON success envelope is approved.
3. Error envelope and HTTP status mapping are approved.
4. Sanctum authentication contract is approved.
5. Login identifier contract is approved.
6. Pagination/search/filter rules are approved.
7. Platform Institution APIs are approved.
8. Platform Institution Admin APIs are approved.
9. Institution user APIs are approved.
10. Group APIs are approved.
11. Teacher/Student Group relationship APIs are approved.
12. Parent–Student relationship APIs are approved.
13. Institution settings APIs expose threshold, Blitz timer-start mode, release modes, timezone, and effective upload limits.
14. Teacher assigned-Group read and Topic APIs, including the controlled Topic lifecycle, are approved.
15. Learning Material APIs expose the effective upload capability, enforce the 25 MB platform maximum/lower institution limit, and use protected file access.
16. Homework APIs expose the fixed 3-attempt policy and do not accept `attempt_limit`.
17. Nine Question payloads are approved.
18. Approved partial-credit behavior is defined.
19. Student Homework Attempt APIs enforce attempts 1–3.
20. Answer payloads are approved.
21. Student file-answer API enforces the 15 MB platform maximum and lower institution limit.
22. Blitz authoring uses whole-task `duration_seconds`.
23. Blitz activation snapshots synchronized/individual timer mode.
24. Student Blitz Attempt API enforces normal Attempt #1 and exception-only Attempt #2.
25. Timeout auto-finalization behavior is defined.
26. Teacher Blitz attempt-exception endpoint is approved.
27. Manual review API is approved.
28. Official task-score contract uses deterministic approved policies.
29. Topic result-pair GET/PUT contract is approved.
30. Topic result calculation uses unrounded server values.
31. Public score display precision is one decimal and category assignment uses the approved integer `category_score`.
32. Understanding-category API uses inclusive integer ranges without gaps/overlaps.
33. Student release modes are implemented.
34. Parent visibility modes are implemented.
35. Parent cannot receive a result before Student release.
36. Teacher progress APIs are approved.
37. Student progress APIs are approved.
38. Parent progress APIs are approved.
39. Institution report APIs are approved.
40. Platform statistics API is approved.
41. Time input/output contract is aligned with institution IANA timezone + UTC storage.
42. Tenant-scoping behavior is approved.
43. Stable error codes are approved.
44. Required Idempotency-Key mutations and concurrency rules are approved and unambiguous.
45. No endpoint permits Flutter to override backend-authoritative final scoring.
46. No endpoint accepts `institution_id` as an unsafe ownership override.
47. No resource can be accessed across institution scope through direct UUIDs.
48. Every write endpoint has defined validation and business-conflict behavior.
49. No decision-gated, alternative, preferred, or unresolved MVP behavior remains in contract-critical sections.
50. No API rule contradicts `05-business-rules.md`.
51. No API rule contradicts `07-architecture.md`.
52. No API field contradicts the decision-resolved persistence model in `08-database.md`.
53. Flutter repositories can be implemented directly from the contract without guessing backend behavior.
54. Laravel controllers/requests/resources can be implemented directly from the contract without inventing product behavior.
55. Codex implementation tasks can reference exact endpoint sections and acceptance criteria.

The final cross-document consistency audit has passed. This API contract is **locked for MVP implementation**.

---

# Appendix A — Main Endpoint Index

## Authentication

```text
POST /api/v1/auth/login
POST /api/v1/auth/logout
GET  /api/v1/auth/me
POST /api/v1/auth/change-password
```

## Platform Owner

```text
GET   /api/v1/platform/dashboard
GET   /api/v1/platform/statistics

GET   /api/v1/platform/institutions
POST  /api/v1/platform/institutions
GET   /api/v1/platform/institutions/{institution}
PATCH /api/v1/platform/institutions/{institution}
POST  /api/v1/platform/institutions/{institution}/activate
POST  /api/v1/platform/institutions/{institution}/deactivate

GET   /api/v1/platform/institutions/{institution}/admins
POST  /api/v1/platform/institutions/{institution}/admins
PATCH /api/v1/platform/institution-admins/{user}
POST  /api/v1/platform/institution-admins/{user}/activate
POST  /api/v1/platform/institution-admins/{user}/deactivate
```

## Institution Admin

```text
GET   /api/v1/institution/dashboard

GET   /api/v1/institution/profile
PATCH /api/v1/institution/profile

GET   /api/v1/institution/users
POST  /api/v1/institution/users
GET   /api/v1/institution/users/{user}
PATCH /api/v1/institution/users/{user}
POST  /api/v1/institution/users/{user}/activate
POST  /api/v1/institution/users/{user}/deactivate

GET   /api/v1/institution/groups
POST  /api/v1/institution/groups
GET   /api/v1/institution/groups/{group}
PATCH /api/v1/institution/groups/{group}
POST  /api/v1/institution/groups/{group}/archive

GET    /api/v1/institution/groups/{group}/teachers
POST   /api/v1/institution/groups/{group}/teachers
DELETE /api/v1/institution/groups/{group}/teachers/{teacher}

GET    /api/v1/institution/groups/{group}/students
POST   /api/v1/institution/groups/{group}/students
DELETE /api/v1/institution/groups/{group}/students/{student}

GET    /api/v1/institution/parents/{parent}/students
GET    /api/v1/institution/students/{student}/parents
POST   /api/v1/institution/parent-student-relationships
DELETE /api/v1/institution/parent-student-relationships/{relationship}

GET /api/v1/institution/settings/assessment
PUT /api/v1/institution/settings/assessment

GET /api/v1/institution/understanding-categories
PUT /api/v1/institution/understanding-categories

GET /api/v1/institution/reports/progress
```

## Teacher Groups / Topics / Materials

```text
GET   /api/v1/teacher/groups

GET   /api/v1/teacher/topics
POST  /api/v1/teacher/topics
GET   /api/v1/teacher/topics/{topic}
PATCH /api/v1/teacher/topics/{topic}
POST  /api/v1/teacher/topics/{topic}/activate
POST  /api/v1/teacher/topics/{topic}/close
POST  /api/v1/teacher/topics/{topic}/archive

GET    /api/v1/teacher/topics/{topic}/materials
POST   /api/v1/teacher/topics/{topic}/materials
PATCH  /api/v1/teacher/materials/{material}
POST   /api/v1/teacher/materials/{material}/replace
DELETE /api/v1/teacher/materials/{material}
```

## Teacher Homework / Questions

```text
GET   /api/v1/teacher/topics/{topic}/homework
POST  /api/v1/teacher/topics/{topic}/homework
GET   /api/v1/teacher/homework/{homework}
PATCH /api/v1/teacher/homework/{homework}
POST  /api/v1/teacher/homework/{homework}/activate
POST  /api/v1/teacher/homework/{homework}/close
POST  /api/v1/teacher/homework/{homework}/archive

POST   /api/v1/teacher/assessments/{assessment}/questions
PATCH  /api/v1/teacher/questions/{question}
DELETE /api/v1/teacher/questions/{question}
POST   /api/v1/teacher/assessments/{assessment}/questions/reorder
```

## Student Homework / Answers

```text
GET  /api/v1/student/homework
GET  /api/v1/student/homework/{homework}
POST /api/v1/student/homework/{homework}/attempts

GET  /api/v1/student/attempts/{attempt}
PUT  /api/v1/student/attempts/{attempt}/answers/{question}
POST /api/v1/student/attempts/{attempt}/answers/{question}/file
POST /api/v1/student/attempts/{attempt}/submit
```

## Teacher Blitz

```text
GET   /api/v1/teacher/blitz
POST  /api/v1/teacher/topics/{topic}/blitz
GET   /api/v1/teacher/blitz/{blitz}
PATCH /api/v1/teacher/blitz/{blitz}
POST  /api/v1/teacher/blitz/{blitz}/schedule
POST  /api/v1/teacher/blitz/{blitz}/activate
POST  /api/v1/teacher/blitz/{blitz}/close
POST  /api/v1/teacher/blitz/{blitz}/archive
GET   /api/v1/teacher/blitz/{blitz}/monitoring
POST  /api/v1/teacher/blitz/{blitz}/students/{student}/attempt-exception
```

## Student Blitz

```text
GET  /api/v1/student/blitz/active
GET  /api/v1/student/blitz/{blitz}
POST /api/v1/student/blitz/{blitz}/attempts
```

Student Blitz Answers use shared Student Attempt endpoints.

## Teacher Checking / Results

```text
GET /api/v1/teacher/submissions
GET /api/v1/teacher/submissions/{submission}
PUT /api/v1/teacher/submissions/{submission}/review

GET /api/v1/teacher/assessments/{assessment}/students/{student}/official-score

GET /api/v1/teacher/topics/{topic}/result-pair
PUT /api/v1/teacher/topics/{topic}/result-pair

GET  /api/v1/teacher/topics/{topic}/results
GET  /api/v1/teacher/topics/{topic}/results/{student}
POST /api/v1/teacher/topics/{topic}/results/{student}/recalculate
POST /api/v1/teacher/topics/{topic}/results/{student}/close

POST /api/v1/teacher/topics/{topic}/results/{student}/release/student
POST /api/v1/teacher/topics/{topic}/results/{student}/release/parent
```

## Teacher Reports

```text
GET /api/v1/teacher/dashboard
GET /api/v1/teacher/groups/{group}/progress
GET /api/v1/teacher/students/{student}/progress
```

## Student Progress

```text
GET /api/v1/student/dashboard
GET /api/v1/student/topics
GET /api/v1/student/topics/{topic}
GET /api/v1/student/progress
GET /api/v1/student/topics/{topic}/result
```

## Parent Progress

```text
GET /api/v1/parent/children
GET /api/v1/parent/children/{student}/dashboard
GET /api/v1/parent/children/{student}/progress
GET /api/v1/parent/children/{student}/topics/{topic}
```

## Protected Files

```text
GET /api/v1/files/{file}/download
```

---

# Appendix B — Resource Naming Rules

Use consistent snake_case JSON fields:

```text
institution_id
group_id
topic_id
student_id
attempt_number
normalized_score
result_status
student_visible_at
```

Use plural resource collections:

```text
institutions
users
groups
topics
materials
questions
attempts
results
```

Use explicit action endpoints for lifecycle transitions:

```text
/activate
/deactivate
/close
/archive
/recalculate
/release/student
/release/parent
/attempt-exception
```

Do not encode actions as ambiguous query parameters.

---

# Appendix C — Client Trust Boundary

Flutter may send:

- User-entered content
- Selected allowed IDs
- Answers
- File uploads
- Search/filter/sort inputs
- Explicit authorized commands such as activate/submit/release

Flutter must not authoritatively send:

```text
institution_id
role
is_authorized
official_attempt_id as a client-selected authority
official_homework_score
official_blitz_score
score_difference
final_score
consistency
category_code
result_status
calculated_at
student_visible_at
parent_visible_at
server timer validity
```

The backend derives or validates all authoritative fields.

---

# Final API Principle

> **The TestLabUz API must expose one stable, role-scoped contract between Flutter and Laravel while keeping the Laravel backend authoritative for institution isolation, permissions, task state, attempt rules, Blitz timing, scoring, result calculation, categories, and visibility. A client-supplied UUID or value must never bypass the business rules that connect Institution → Group → Topic → Assessment → Student Attempt → Official Score → Official Topic Pair → Topic Result.**
