# Codex Task: Stage 3 Contract Alignment and Task Control

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S03-INT-001` |
| Roadmap stage | `Stage 3 — Institution Administration and User Management` |
| Area | `Integration / contract and stage control` |
| Status | `Accepted` |
| Approved on | `2026-08-13` |
| Depends on | `Stage 2 — Closed / PASS; all 17 Stage 2 tasks Accepted / PASS / Delivered` |
| Blocks | `S03-BE-001 through S03-BE-007, S03-FE-001 through S03-FE-009, and S03-INT-002` |

This task and the Stage 3 decomposition were approved by the project owner on
`2026-08-13`. Codex may execute this task only through the required Phase 0–3
workflow below.

## 2. Goal

Remove the remaining contract ambiguity that would otherwise force Stage 3
backend and Flutter tasks to invent Institution Admin behavior, and establish
the approved Stage 3 task-control index.

The observable result is:

1. `docs/09-api-contracts.md` defines exact Institution Admin contracts for:
   - the authenticated Institution's profile;
   - the Stage 3 dashboard user counts;
   - the complete Teacher/Student/Parent User API behavior;
2. Appendix A contains the approved Institution profile endpoints;
3. `tasks/STAGE_03_TASK_INDEX.md` records the approved 18-task decomposition,
   dependencies, boundaries, and closure gate;
4. `tasks/README.md` records Stage 3 as started only after this task is accepted
   and delivered;
5. no Laravel, Flutter, migration, runtime, or Stage 4+ product implementation
   is introduced.

## 3. Current Context

Stage 1 and Stage 2 are closed. Current authoritative `main` at task-planning
time is:

```text
d3078757f3e753af551b649d808547c463feea59
```

Stage 2 delivered the reusable foundation needed by Stage 3:

- Sanctum authentication and current-user bootstrap;
- active-account and active-Institution enforcement;
- mandatory first-login password-change gate;
- authoritative role middleware;
- UUID Institution/User persistence and tenant ownership fields;
- Institution lifecycle behavior;
- Institution Settings persistence and approved enum/value foundations;
- Platform Owner API/resource/request/action conventions;
- Flutter desktop routing, session isolation, shell, repository, mutation,
  stale-response, and error-state patterns.

Stage 3 is specified in `docs/06-roadmap.md`, and most API endpoints already
exist in `docs/09-api-contracts.md`. Three exact contracts are incomplete:

1. Stage 3 requires an Institution Admin to view and edit the own Institution
   profile, but no Institution Admin profile endpoint is listed.
2. Section 31.1 labels the dashboard response as a "Possible MVP summary" and
   includes Group/Learning metrics that belong to later stages and are not yet
   available at the Stage 3 entry point.
3. Section 8 lists Institution User endpoints, but does not define one exact
   public resource, complete list behavior, or complete create/update/lifecycle
   request and response rules needed by Laravel and Flutter.

This task resolves only those gaps using the Stage 3 plan approved by the
project owner. It does not reopen unrelated locked decisions.

## 4. Approved Contract Decisions

These decisions are part of this approved task and must be encoded exactly.

### 4.1 Institution Profile Endpoints

Add:

```text
GET   /api/v1/institution/profile
PATCH /api/v1/institution/profile
```

Both endpoints:

- require authenticated `institution_admin`;
- derive the Institution exclusively from the authenticated user;
- accept no client-supplied `institution_id` or Institution UUID;
- use the normal middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:institution_admin
```

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

`GET` returns `200 OK` with that resource in the normal single-resource
envelope and no `message`. It accepts no query parameters or request body;
either form of extra input returns `422 validation_failed`.

`PATCH` is a partial update. Its strict editable allowlist is:

```text
name
contact_email
contact_phone
address
description
```

The following remain read-only / backend-controlled:

```text
id
type
status
created_by_user_id
deactivated_at
created_at
updated_at
institution settings
user counts
```

`PATCH` rules:

- JSON object body only;
- at least one allowed field must be present;
- `name`: required when present, trimmed, non-empty string, max 200;
- `contact_email`: nullable string, valid email, max 254;
- `contact_phone`: nullable string, max 50;
- `address`: nullable string;
- `description`: nullable string;
- nullable fields may be cleared with explicit JSON `null`;
- unknown/protected JSON keys are rejected with `422 validation_failed`;
- query parameters are rejected with `422 validation_failed`;
- omitted allowed fields retain their values;
- an exact no-op returns `200 OK` with the current resource and does not change
  `updated_at`;
- success returns `200 OK`, the complete updated profile resource, and exact
  message `Institution profile updated successfully.`;
- no profile update may alter lifecycle state, Institution type, settings,
  users, counts, creator data, or learning records.

The fields and limits above align with `docs/08-database.md` and the accepted
Stage 2 Institution profile conventions. Removing `type` from the Institution
Admin allowlist is intentional: Institution type remains Platform Owner
controlled.

### 4.2 Stage 3 Institution Dashboard Contract

Replace the optional/possible Section 31.1 Stage 3 response with this exact
minimum contract:

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

- scope is the authenticated Institution only;
- only roles `teacher`, `student`, and `parent` are counted;
- each value is the total number of active and inactive accounts of that role;
- Platform Owner and Institution Admin accounts are excluded;
- Group and Learning metrics are omitted in Stage 3 because their authoritative
  records are delivered by later stages;
- later stages may add Group/Learning dashboard blocks additively without
  changing this Stage 3 `users` contract;
- endpoint accepts no query parameters or body.

### 4.3 Institution User API Contract

Rename Section 8 to:

```text
8. Institution Admin Profile and User APIs
```

Use this exact internal order without renumbering later top-level sections:

```text
8.1 Institution Profile
8.2 Shared Institution User Resource
8.3 User List
8.4 Create User
8.5 User Detail
8.6 Update User
8.7 Activate User
8.8 Deactivate User
```

Section 8.1 contains both profile endpoints from Section 4.1. Sections 8.2–8.8
contain the complete User contract below.

#### 4.3.1 Common Access, Scope, and Resource

All Institution User endpoints require the middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:institution_admin
```

Every list/create/detail/update/lifecycle operation is scoped to the
authenticated Institution before any filter, lookup, or mutation. Eligible
target roles are exactly `teacher`, `student`, and `parent`. A missing User, a
User from another Institution, or a User with a disallowed role returns the
same scope-safe `404 resource_not_found` response. A client-supplied
Institution identifier can never select or replace scope.

Define one exact Institution Admin User resource for Teacher, Student, and
Parent endpoints:

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

The resource must never expose:

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

The Institution is implicit from the authenticated tenant scope. `role` is
included because one list contains all three allowed roles.

#### 4.3.2 User List

Clarify the User list contract:

```text
GET /api/v1/institution/users
```

Accepted query keys:

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

- `role`: optional single value `teacher|student|parent`; when omitted, include
  all three allowed roles;
- `status`: optional single value `active|inactive`; when omitted, include both
  active and inactive accounts;
- `active` maps to `is_active = true`; `inactive` maps to
  `is_active = false`;
- `search`: trimmed, case-insensitive literal substring match across
  `full_name`, `login_name`, `email`, and `phone`; `%` and `_` are literal,
  not wildcard expansion;
- `search` is optional, has a maximum length of 254 characters, and a blank
  value after trimming behaves as no search filter;
- `page`: integer, minimum 1, default 1;
- `per_page`: integer, minimum 1, maximum 100, default 20;
- `sort`: `full_name|login_name|created_at|updated_at`, default `full_name`;
- `direction`: `asc|desc`, default `asc`;
- `full_name` and `login_name` ordering is case-insensitive;
- every ordering has a deterministic UUID tie-break in the same direction;
- unknown query keys and unsupported values return `422 validation_failed`;
- request bodies are rejected with `422 validation_failed`;
- results are always scoped to the authenticated Institution before all
  filters, search, ordering, and pagination;
- list response uses the general pagination contract in Section 6.

#### 4.3.3 Create User

```text
POST /api/v1/institution/users
```

Accept a JSON object body with exactly these allowed keys:

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
full_name: required, trimmed, non-empty string, max 200
login_name: required, trimmed, non-empty string, max 191, globally unique
email: optional, nullable string, valid email when non-null, max 254
phone: optional, nullable string, trimmed/non-empty when non-null, max 50
password: required string, min 8, max 255
```

An empty, malformed, scalar, or array JSON body, an unknown/protected key, or
any query parameter returns `422 validation_failed` with no User/token side
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
```

Creation must not log the new User in, create a Sanctum token, generate or
return a password, create relationships, or alter settings/learning data.

Success is `201 Created` with the complete shared User resource and:

```text
message = Institution user created successfully.
```

#### 4.3.4 User Detail

```text
GET /api/v1/institution/users/{user}
```

The path UUID is the only accepted input. Query parameters or a request body
return `422 validation_failed`. Success is `200 OK` with the complete shared
User resource in the normal single-resource envelope and no mutation.

#### 4.3.5 Update User

```text
PATCH /api/v1/institution/users/{user}
```

Accept a non-empty partial JSON object with only:

```text
full_name
email
phone
```

Validation:

```text
full_name: when present, required, trimmed, non-empty string, max 200
email: optional, nullable string, valid email when non-null, max 254
phone: optional, nullable string, trimmed/non-empty when non-null, max 50
```

Omitted fields retain their values; explicit JSON `null` clears `email` or
`phone`. Empty/malformed/non-object bodies, unknown/protected keys, and query
parameters return `422 validation_failed` and apply no partial mutation. An
exact no-op returns the current resource without changing `updated_at`.
An authorized Institution Admin may update either an active or inactive
eligible target. The update is atomic and cannot change lifecycle fields.

Success is `200 OK` with the complete shared User resource and:

```text
message = Institution user updated successfully.
```

#### 4.3.6 Activate and Deactivate User

```text
POST /api/v1/institution/users/{user}/activate
POST /api/v1/institution/users/{user}/deactivate
```

Lifecycle commands accept either no body or an empty JSON object `{}` and no
query parameters. Any non-empty object, malformed JSON, scalar/array root, or
query parameter returns `422 validation_failed` with no mutation.

Required state transitions:

| Endpoint | Current state | Required result |
|---|---|---|
| `activate` | inactive | Set `is_active = true`, clear `deactivated_at`, and advance `updated_at` once |
| `activate` | active | Idempotent `200`; no write and preserve `updated_at` |
| `deactivate` | active | Set `is_active = false`, set `deactivated_at` to authoritative server time, and advance `updated_at` once |
| `deactivate` | inactive | Idempotent `200`; no write and preserve original `deactivated_at` and `updated_at` |

Real lifecycle transitions are atomic. Concurrent same-target update/activate/
deactivate operations must serialize safely so a stale write cannot overwrite
unrelated profile or lifecycle state.

Deactivation immediately blocks new login and existing-token access through
the accepted active-account middleware. It does not delete stored Sanctum
tokens, password state, first-login state, creator/history, relationships, or
learning data. Reactivation does not create or restore a token, reset a
password, clear `must_change_password`, update `last_login_at`, or bypass an
inactive Institution/role/permission gate. A previously stored valid token may
resume only otherwise-authorized access, matching the accepted Stage 2 account
lifecycle convention.

Activate success returns `200 OK`, the complete shared User resource, and:

```text
message = Institution user activated successfully.
```

Deactivate success returns `200 OK`, the complete shared User resource, and:

```text
message = Institution user deactivated successfully.
```

#### 4.3.7 Protected Behavior and Preservation

Explicitly preserve:

- Institution Admin cannot create or query `platform_owner` or
  `institution_admin` through these endpoints;
- create derives `institution_id`, `created_by_user_id`, and
  `must_change_password = true` server-side;
- normal update permits only `full_name`, `email`, and `phone`;
- role, login name, password, Institution, active state, first-login state,
  creator, and token state are not editable through normal update;
- lifecycle uses the explicit activate/deactivate endpoints;
- lifecycle operations preserve password/first-login state, stored tokens, and
  historical records;
- direct unknown, foreign-Institution, or disallowed-role targets use the
  scope-safe not-found behavior.

## 5. Included Scope

### 5.1 Locked API contract clarification

Modify only the necessary parts of `docs/09-api-contracts.md` to:

- add the Institution profile GET/PATCH contract;
- make the Institution dashboard Stage 3 response exact;
- define the shared Institution User resource;
- complete the User list, detail, create, update, activate, and deactivate
  contracts;
- add the two Institution profile endpoints to Appendix A;
- keep numbering/headings and endpoint index internally consistent.

This is an explicitly approved contract-clarification task. It may modify the
otherwise locked API document only within the exact decisions in Section 4.

### 5.2 Stage 3 task index

Create `tasks/STAGE_03_TASK_INDEX.md` and record this approved order:

| Order | Task ID | Area | Outcome | Direct dependencies |
|---:|---|---|---|---|
| 1 | `S03-INT-001` | Integration | Stage 3 contract alignment and task control | Stage 2 closed |
| 2 | `S03-BE-001` | Backend | Institution Admin dashboard API | `S03-INT-001` |
| 3 | `S03-BE-002` | Backend | Own Institution profile GET/PATCH API | `S03-BE-001` |
| 4 | `S03-BE-003` | Backend | Institution User list/detail API | `S03-BE-002` |
| 5 | `S03-BE-004` | Backend | Teacher/Student/Parent create API | `S03-BE-003` |
| 6 | `S03-BE-005` | Backend | Institution User update and lifecycle API | `S03-BE-004` |
| 7 | `S03-BE-006` | Backend | Assessment settings GET/PUT API | `S03-BE-005` |
| 8 | `S03-BE-007` | Backend | Understanding-category persistence and API | `S03-BE-006` |
| 9 | `S03-FE-001` | Frontend | Institution Admin desktop shell/navigation | `S03-BE-007` |
| 10 | `S03-FE-002` | Frontend | Institution dashboard real-data UI | `S03-FE-001`, `S03-BE-001` |
| 11 | `S03-FE-003` | Frontend | Institution profile view/edit UI | `S03-FE-002`, `S03-BE-002` |
| 12 | `S03-FE-004` | Frontend | User list/search/filter/sort/pagination UI | `S03-FE-003`, `S03-BE-003` |
| 13 | `S03-FE-005` | Frontend | Institution User detail UI | `S03-FE-004`, `S03-BE-003` |
| 14 | `S03-FE-006` | Frontend | Teacher/Student/Parent create UI | `S03-FE-005`, `S03-BE-004` |
| 15 | `S03-FE-007` | Frontend | Institution User edit/lifecycle UI | `S03-FE-006`, `S03-BE-005` |
| 16 | `S03-FE-008` | Frontend | Assessment settings UI | `S03-FE-007`, `S03-BE-006` |
| 17 | `S03-FE-009` | Frontend | Understanding-category range editor | `S03-FE-008`, `S03-BE-007` |
| 18 | `S03-INT-002` | Integration | Stage 3 Windows real-stack E2E verification | All Stage 3 backend/frontend tasks |

The index must state:

- decomposition approved on `2026-08-13`;
- production implementation remains sequential and acceptance-gated;
- detailed task/prompt files may be prepared without waiting for predecessor
  delivery, but a task may be executed only after all its dependencies are
  `Accepted / PASS / Delivered`;
- Stage 4 is blocked until a separate Stage 3 Closure Review returns and is
  delivered as `FINAL STATUS: STAGE CLOSED`;
- the closure review is separate from the 18 implementation tasks.

At initial creation during Phase 1, record `S03-INT-001` as
`Approved / Not started / Not started`, matching its approved authority file
before the acceptance gate. The other rows point to their planned paths and
remain `Draft / Not started / Not started` until each detailed task/prompt pair
is separately reviewed, approved, and placed in the project.
Approval of the Stage 3 decomposition does not falsely claim that an absent
detailed task file is ready for execution.

After Phase 2 PASS, Phase 3 prepares the `S03-INT-001` row as
`Accepted / PASS / Delivered` in the delivery commit. Those values become
authoritative only if that commit is merged to `origin/main`, local `main` is
synchronized, and the working tree is clean. If delivery fails, the final task
result is `DELIVERY BLOCKED`, not `ACCEPTED`.

### 5.3 Task README bookkeeping

After the read-only gate passes, Phase 3 may update `tasks/README.md` to:

- record Stage 3 as `In Progress`;
- state `S03-INT-001` is accepted and delivered only after delivery completes;
- name `S03-BE-001` as the next implementation gate;
- preserve Stage 1 and Stage 2 closure facts;
- preserve the prohibition on Stage 4 implementation.

Do not prematurely claim Stage 3 implementation or closure.

## 6. Relevant Files

| File or directory | Expected action | Reason |
|---|---|---|
| `AGENTS.md` | Read and preserve | Repository authority and locked-doc change control |
| `backend/AGENTS.md` | Read and preserve | Later backend contract consumers |
| `frontend/AGENTS.md` | Read and preserve | Later Flutter contract consumers |
| `docs/01–08` | Read relevant sections and preserve | Cross-document authority; no changes in this task |
| `docs/09-api-contracts.md` | Modify only approved sections | Close the Stage 3 profile, dashboard, and complete User API gaps |
| `tasks/README.md` | Modify only after Phase 2 PASS | Record truthful Stage 3 gate |
| `tasks/STAGE_02_TASK_INDEX.md` | Inspect and preserve | Prove Stage 2 dependency closure |
| `tasks/STAGE_02_CLOSURE_REVIEW.md` | Inspect and preserve | Stage 2 closure authority |
| `tasks/STAGE_03_TASK_INDEX.md` | Create | Approved Stage 3 decomposition/control record |
| `tasks/templates/STAGE_TASK_INDEX_TEMPLATE.md` | Inspect and preserve | Index structure/status vocabulary |
| `tasks/integration/stage-03/S03-INT-001-stage-03-contract-alignment-task-control.md` | Preserve; status bookkeeping only after PASS | Current authority task |
| `tasks/integration/stage-03/S03-INT-001-CODEX-PROMPT.md` | Preserve | Current execution prompt |
| `backend/` | Inspect only | Confirm contracts are implementable; no code changes |
| `frontend/` | Inspect only | Confirm contracts are consumable; no code changes |

Changes outside this list require a clear necessity within the approved scope
and must be reported. No application/runtime file may change.

## 7. Authoritative Specification References

| Document | Exact section | Requirement used by this task |
|---|---|---|
| `docs/02-user-roles.md` | `2. Institution Admin` | Own-Institution authority and account boundaries |
| `docs/03-features.md` | Institution Admin features | Dashboard, own profile, user management, settings |
| `docs/04-user-flows.md` | Institution Admin flow | Desktop administration sequence and allowed actions |
| `docs/05-business-rules.md` | Institution, role, account, tenant, lifecycle, and settings rules | Scope and backend authority |
| `docs/06-roadmap.md` | `8. Stage 3 — Institution Administration and User Management` | Stage goal, included scope, tests, acceptance criteria |
| `docs/06-roadmap.md` | `9. Stage 4 — Groups and User Relationships` | Explicit adjacent-stage exclusion |
| `docs/07-architecture.md` | API, authorization, tenancy, Flutter, testing sections | Layer and security constraints |
| `docs/08-database.md` | `4. Institutions`, `5. Users and Roles`, Institution Settings | Exact persistent fields and limits |
| `docs/09-api-contracts.md` | Sections `1–8`, `12`, `26`, `31`, `33`, Appendix A | API conventions and Stage 3 endpoints |
| `tasks/README.md` | Entire file | Lifecycle, phases, delivery, and status vocabulary |
| `AGENTS.md` | Applicable locked-doc, scope, review, and delivery rules | Repository-wide execution authority |

## 8. Relevant Business and Security Rules

- Institution Admin acts only inside the authenticated user's Institution.
- Client-provided identifiers never expand Institution scope.
- Platform Owner and Institution Admin account creation are outside the
  Institution User endpoints.
- Institution Admin cannot change Institution lifecycle or type.
- User role change is not part of normal MVP edit behavior.
- Deactivation preserves historical data and blocks normal use.
- Dashboard data must be server-authoritative and tenant-scoped.
- Stage 3 must not invent Group or Learning analytics before their owning
  stages deliver authoritative records.
- Passwords, password hashes, tokens, creator identity, and protected learning
  data must never appear in these resources.
- API errors, UTC timestamps, pagination, and scope-safe not-found behavior use
  existing general contracts.

## 9. Requirements

### 9.1 Documentation Requirements

1. Make the Section 4 decisions explicit and normative.
2. Use existing contract terminology and envelope/error conventions.
3. Remove or replace ambiguous "possible" wording only for the Stage 3
   dashboard contract.
4. Keep later Group/Learning dashboard evolution explicitly additive.
5. Do not alter existing Institution Settings or Understanding Category
   contracts.
6. Do not renumber unrelated API sections unnecessarily.
7. Keep Appendix A synchronized with the new profile endpoints.
8. Ensure no endpoint permits an Institution ID/UUID ownership override.
9. Ensure Laravel requests/resources/actions and Flutter repositories can be
   built without guessing list/detail/create/update/lifecycle behavior.

### 9.2 Stage Index Requirements

1. Use valid task/review/delivery statuses from `tasks/README.md`.
2. Record all 18 tasks in the approved decomposition and their direct
   dependencies exactly.
3. Point to these planned paths:

```text
tasks/integration/stage-03/S03-INT-001-stage-03-contract-alignment-task-control.md
tasks/backend/stage-03/S03-BE-001-institution-admin-dashboard-api.md
tasks/backend/stage-03/S03-BE-002-own-institution-profile-api.md
tasks/backend/stage-03/S03-BE-003-institution-user-list-detail-api.md
tasks/backend/stage-03/S03-BE-004-institution-user-create-api.md
tasks/backend/stage-03/S03-BE-005-institution-user-update-lifecycle-api.md
tasks/backend/stage-03/S03-BE-006-institution-assessment-settings-api.md
tasks/backend/stage-03/S03-BE-007-understanding-category-persistence-api.md
tasks/frontend/stage-03/S03-FE-001-institution-admin-desktop-shell-navigation.md
tasks/frontend/stage-03/S03-FE-002-institution-dashboard-real-data-states.md
tasks/frontend/stage-03/S03-FE-003-own-institution-profile-view-edit.md
tasks/frontend/stage-03/S03-FE-004-institution-user-list-search-filters-pagination.md
tasks/frontend/stage-03/S03-FE-005-institution-user-detail.md
tasks/frontend/stage-03/S03-FE-006-institution-user-create.md
tasks/frontend/stage-03/S03-FE-007-institution-user-edit-lifecycle.md
tasks/frontend/stage-03/S03-FE-008-institution-assessment-settings-ui.md
tasks/frontend/stage-03/S03-FE-009-understanding-category-range-editor.md
tasks/integration/stage-03/S03-INT-002-stage-03-windows-real-stack-e2e-verification.md
```

4. State that paired execution prompts are preparation artifacts, not evidence
   of implementation or acceptance.
5. Preserve the separate Stage 3 Closure Review requirement.

### 9.3 Architecture and Organization

- This is documentation/control work only.
- Keep the API document as the one normative source for exact HTTP behavior.
- Keep the stage index as workflow/dependency control, not product authority.
- Do not duplicate large API examples into the index.
- Do not create speculative endpoints, schemas, roles, dashboard metrics, or
  later-stage behaviors.

### 9.4 Authorization, Tenant Isolation, and Disclosure

The clarified contract must make all of these testable:

- unauthenticated access fails with `401`;
- wrong-role access fails with `403` after normal middleware precedence;
- inactive account/Institution and password-change gates remain authoritative;
- own-Institution profile and users succeed for eligible Institution Admin;
- no request can select another Institution;
- direct unknown, foreign-Institution, and disallowed-role User targets are
  indistinguishable through the approved scope-safe not-found contract;
- dashboard, profile, list, search, sort, and pagination cannot leak another
  Institution's records or counts;
- resources exclude secrets and unnecessary protected data.

### 9.5 Validation and Error Alignment

- Reuse `validation_failed` for malformed/unknown/protected input.
- Reuse current general `401`, `403`, `404`, and `409` contracts.
- No new stable error code is needed by this clarification.
- GET profile/dashboard/User list/User detail rejects request bodies as
  specified.
- Profile PATCH and User create/update accept JSON object bodies and reject
  query override attempts.
- User activate/deactivate accepts only no body or `{}` and rejects all query
  parameters and non-empty/malformed/non-object bodies.
- Empty/malformed/non-object bodies are unambiguously invalid where a body is
  required.

## 10. Acceptance Criteria

- [ ] `docs/09-api-contracts.md` contains both Institution profile endpoints.
- [ ] Profile resource, editable allowlist, validation, protected fields,
      tenant derivation, and response behavior match Section 4.1 exactly.
- [ ] Section 31.1 defines exactly three own-Institution
      Teacher/Student/Parent total counts without active splits or Stage 4+
      metrics.
- [ ] Section 8 defines one exact User resource for list/create/detail/update/
      activate/deactivate.
- [ ] User list query allowlist, defaults, literal search, allowed sorts,
      deterministic order, pagination, and rejection behavior are exact.
- [ ] User create/update validation, protected keys, server-derived fields,
      exact messages, and atomic failure behavior are exact.
- [ ] User activate/deactivate input, idempotency, timestamps, token/access,
      reactivation, history preservation, resources, and messages are exact.
- [ ] User resource excludes Institution ID, creator data, secrets, tokens,
      settings, relationships, and learning data.
- [ ] Appendix A contains GET/PATCH Institution profile endpoints exactly once.
- [ ] Existing assessment-settings and understanding-category contracts remain
      unchanged.
- [ ] `tasks/STAGE_03_TASK_INDEX.md` records all 18 tasks in the approved
      decomposition, planned paths, dependencies, truthful statuses, and
      closure rules.
- [ ] The index distinguishes task-file preparation from implementation and
      acceptance.
- [ ] `tasks/README.md` is updated truthfully only after PASS/delivery.
- [ ] No Laravel, Flutter, migration, dependency, Docker, CI, or runtime file
      changes.
- [ ] No Stage 4+ implementation or product behavior is added.
- [ ] No unrelated locked contract is changed.
- [ ] No credentials, tokens, secrets, or private data are introduced.

## 11. Tests and Verification

### 11.1 Documentation and Consistency Checks

- [ ] Search the final API document for every new endpoint and confirm Appendix
      A alignment.
- [ ] Confirm profile protected fields are not present in the PATCH allowlist.
- [ ] Confirm the dashboard response contains only Stage 3 User metrics.
- [ ] Confirm the User resource field list is exact and has no sensitive data.
- [ ] Confirm Section 8 endpoint list remains complete.
- [ ] Confirm Sections 12 and 26 have no diff.
- [ ] Confirm `docs/01–08` have no diff.
- [ ] Confirm all 18 index task IDs, paths, order, and dependencies.
- [ ] Confirm every status value is valid under `tasks/README.md`.

### 11.2 Safe Commands

Run repository-valid non-mutating equivalents of:

```text
git status --short
git diff --check
git diff -- docs/01-business-overview.md docs/02-user-roles.md docs/03-features.md docs/04-user-flows.md docs/05-business-rules.md docs/06-roadmap.md docs/07-architecture.md docs/08-database.md
git diff -- docs/09-api-contracts.md
git diff -- tasks/STAGE_03_TASK_INDEX.md tasks/README.md
rg -n "institution/profile|institution/dashboard|institution/users" docs/09-api-contracts.md
rg -n "S03-(BE|FE|INT)-" tasks/STAGE_03_TASK_INDEX.md
```

Also inspect the complete diff including untracked files and run the repository
secret/sensitive-data checks required by `AGENTS.md`.

No Laravel/Flutter test suite is required because application code cannot
change. If any application/runtime file changes unexpectedly, stop instead of
using passing tests to justify scope expansion.

### 11.3 Manual Review

Read the final changed API sections as a Laravel implementer and as a Flutter
implementer. Confirm each can answer without inference:

1. Which endpoint is called?
2. Which role and Institution are used?
3. Which input keys are allowed?
4. Which output keys and exact success messages are returned?
5. Which search/filter/sort/pagination defaults apply?
6. Which create/update/lifecycle validation and no-op rules apply?
7. Which protected data must not appear?
8. Which later-stage metrics are absent?

Record PASS/FAIL truthfully in the final report.

## 12. Explicit Non-Goals

- Laravel controllers, requests, actions, services, resources, routes, models,
  migrations, seeders, or tests.
- Flutter models, repositories, providers, routes, screens, widgets, or tests.
- Any API endpoint implementation.
- Groups/classes or Teacher–Group/Student–Group assignment.
- Parent–Student relationships.
- Topics, materials, Homework, Blitz, attempts, answers, scoring, results,
  reports, notifications, billing, analytics, or deployment.
- Institution Admin account management by Institution Admin.
- User role change, login-name edit, password reset, hard delete, archive,
  suspend, import/export, or bulk operations.
- Institution type/status/lifecycle changes by Institution Admin.
- Group/Learning dashboard metrics in Stage 3.
- Changes to assessment-settings/category business rules.
- Stage 3 implementation beyond documentation/control artifacts.
- Stage 3 Closure Review or Stage 4 decomposition/implementation.
- Reformatting or rewriting unrelated locked documentation.

## 13. Stop Conditions

Stop and report before changing files if:

- current `origin/main` is not safely synchronized or Stage 2 is no longer
  closed/delivered;
- the project-owner-provided task/prompt files conflict with current main;
- any Section 4 decision contradicts `docs/01–08` or accepted Stage 2
  persistence behavior;
- a clarified resource needs a field not present in approved persistence;
- correct alignment requires changing assessment/category/scoring/relationship
  behavior;
- a dependency or task-path conflict exists;
- application/runtime changes appear necessary;
- safe completion requires guessing new product behavior, destructive Git,
  force-push, history rewrite, check bypass, or material scope expansion.

Report the exact conflict. Do not silently broaden the task.

## 14. Execution and Acceptance Workflow

### Phase 0 — Git Preflight

1. Read the authority files in the paired execution prompt order.
2. Verify the task status is `Approved`.
3. Verify Stage 2 closure and all 17 predecessor delivery states.
4. Verify approved remote:

   ```text
   https://github.com/Shoxrux2017/testlabuz.git
   ```

5. Fetch safely and verify local `main == origin/main` with no unexpected
   changes.
6. The only allowed owner-prepared untracked files on `main` are this detailed
   task and its paired prompt.
7. Create/switch to:

   ```text
   task/s03-int-001-stage3-contract-alignment
   ```

8. Preserve unrelated user work. Stop on any unsafe state.
9. Do not commit, push, open a PR, or merge before Phase 2 PASS.

### Phase 1 — Implementation

Implement only Sections 4 and 5.

Before Phase 2:

- inspect every intended file and complete diff;
- run documentation consistency and secret/scope checks;
- prove application/runtime files did not change;
- do not commit or push.

### Phase 2 — Read-Only Acceptance Gate

Re-read this complete task, the relevant locked sections, and the complete
working-tree diff.

During Phase 2:

- make no file changes;
- run no write-format/fix command;
- make no Git configuration changes;
- do not stage additional changes;
- do not commit, push, open a PR, or merge;
- do not self-fix findings.

Classify findings:

- `P1`: authorization/tenant/secret/destructive Git or material contract
  corruption;
- `P2`: missing/ambiguous requirement, wrong task index, scope drift, or
  consumer-blocking inconsistency;
- `P3`: non-blocking observation.

Any unresolved P1/P2 results in:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop. Do not deliver or begin `S03-BE-001`.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 PASS.

1. Prepare only `S03-INT-001` as `Accepted` in its task metadata for the
   delivery commit; it becomes authoritative only after successful delivery.
2. Prepare `Accepted / PASS / Delivered` in the Stage 3 index for the same
   delivery commit; never report final `ACCEPTED` before merge and verification.
3. Update `tasks/README.md` with the truthful Stage 3 state and next gate.
4. Keep all later task implementations `Not started` and Stage 3 not closed.
5. Re-run final non-writing diff, scope, sensitive-data, and consistency checks.
6. Stage only approved task files, API contract, Stage 3 index, and README.
7. Create one focused commit:

   ```text
   docs(stage3): align institution administration contracts
   ```

   Body:

   ```text
   Task: S03-INT-001
   ```

8. Push `task/s03-int-001-stage3-contract-alignment`.
9. Open a Pull Request to `main`.
10. Merge only when required checks are safe/green and merge is permitted.
11. Synchronize local `main` by fast-forward only.
12. Verify local `main == origin/main` and clean working tree.

If the gate passed but safe GitHub delivery cannot finish:

```text
FINAL STATUS: DELIVERY BLOCKED
```

If delivery completes:

```text
FINAL STATUS: ACCEPTED
```

The next implementation gate is `S03-BE-001`. Do not implement it in this
task.

## 15. Required Codex Final Report

Return:

1. **Final status** — exactly `ACCEPTED`, `NOT ACCEPTED`, or
   `DELIVERY BLOCKED`.
2. **Phase 0 evidence** — Stage 2 closure, dependency, remote, base hash,
   branch, and safety state.
3. **Implementation summary** — exact contracts and control artifacts changed.
4. **Changed files** — every path and reason.
5. **Contract matrix** — profile, dashboard, and complete User API PASS/FAIL.
6. **Index matrix** — all 18 tasks/order/dependencies/path/status validation.
7. **Acceptance criteria** — PASS/FAIL evidence for every criterion.
8. **Read-only gate findings** — P1/P2/P3 list or no blocking/material
   findings.
9. **Scope and locked-doc evidence** — unchanged docs 01–08, settings/category
   sections, application/runtime paths, and Stage 4+ boundary.
10. **Security/tenant evidence** — ownership derivation, role gates, resource
    exclusions, and secret scan.
11. **Verification commands** — exact commands and results.
12. **Git delivery evidence** — commit, branch, PR, checks, merge hash,
    local/remote equality, and clean status.
13. **Manual consumer review** — Laravel and Flutter implementability PASS/FAIL.
14. **Remaining risks/deviations/blockers**.
15. Explicit statements:

    ```text
    Stage 3 was NOT marked Closed by this task.
    Stage 4 was NOT started.
    Next implementation gate: S03-BE-001.
    ```
