# Codex Task: Identity Persistence Foundation

## 1. Task Metadata

| Field | Value |
|---|---|
| Task ID | `S01-BE-002` |
| Roadmap stage | `Stage 1 — Authentication and Role-Based Entry` |
| Area | `Backend / persistence` |
| Status | `Approved` |
| Depends on | `S01-INT-003 — Local Backend Runtime & PostgreSQL Foundation (Accepted)` |
| Blocks | `S01-BE-003 — Sanctum Authentication & Session API` |

This task is approved for Codex execution.

Codex must still enforce all dependency, Git preflight, scope, testing,
read-only acceptance, and GitHub delivery gates defined below.

## 2. Goal

Implement the exact Stage 1 identity persistence baseline required by the
locked TestLabUz database and authentication contracts, without implementing
authentication endpoints or authorization behavior yet.

The accepted result must provide:

- PostgreSQL migrations for `institutions`, `users`,
  `personal_access_tokens`, and `institution_settings`;
- UUID domain identifiers;
- exact locked institution/user role/status/value constraints;
- the Platform Owner nullable-institution exception;
- reusable Eloquent models and relationships;
- Laravel Sanctum token persistence compatible with UUID users;
- typed PHP enums for persisted identity/settings values where they have a real
  model use;
- safe factories/states for controlled Stage 1 test fixtures;
- PostgreSQL-backed automated tests for database constraints and model
  persistence;
- no login/logout/me/change-password API behavior yet.

This task creates identity **data authority**, not identity **HTTP behavior**.

## 3. Current Context

Repository:

`G:\project\testlabuz`

Approved GitHub remote:

`https://github.com/Shoxrux2017/testlabuz.git`

Required dependency:

`S01-INT-003 = Accepted`

The accepted dependency is expected to provide:

- Laravel 13 backend from `S01-BE-001`;
- Docker-based application runtime;
- PostgreSQL 18.x runtime;
- `testlabuz` development database;
- isolated `testlabuz_testing` automated-test database;
- backend tests executing against PostgreSQL.

Codex must independently verify the actual accepted dependency on
`origin/main`.

The locked Stage 1 plan assigns this task ownership of:

- Institution identity persistence;
- User identity persistence;
- Sanctum token persistence;
- controlled Stage 1 identity fixtures.

Authentication behavior is owned by `S01-BE-003`.

## 4. Locked Persistence Contract

### 4.1 Shared-schema multi-institution model

TestLabUz uses:

```text
One application
+
One shared PostgreSQL schema
+
Institution-owned rows
```

The tenant root is:

`institutions`

Platform-level exception:

```text
platform_owner
→ institution_id = null
```

Every other MVP role:

```text
institution_admin
teacher
student
parent
→ institution_id is required
```

Do not introduce multi-institution membership for one account.

### 4.2 UUID primary keys

Domain tables created in this task use PostgreSQL UUID primary keys.

Required:

- `institutions.id` → UUID primary key;
- `users.id` → UUID primary key.

Use one consistent Laravel/PostgreSQL UUID convention.

The model implementation must be compatible with API UUID strings and future
foreign keys.

Do not use integer/serial IDs for these domain tables.

### 4.3 Authoritative timestamps

Use PostgreSQL timezone-aware timestamps (`timestamptz`) for authoritative
instants represented by Laravel timestamp columns in this identity scope.

This applies to identity timestamps such as:

- `created_at`;
- `updated_at`;
- `last_login_at`;
- `deactivated_at`.

Do not create a second parallel timestamp convention.

## 5. Included Scope

### 5.1 Git / dependency preflight

Before implementation:

1. Read root `AGENTS.md`.
2. Read `backend/AGENTS.md`.
3. Read this complete approved task.
4. Read only the locked specification sections referenced below.
5. Verify `S01-INT-003` is `Accepted`.
6. Verify its accepted implementation is on `origin/main`.
7. Verify the approved remote.
8. Fetch remote state safely.
9. Verify local `main == origin/main`.
10. Verify no unrelated dirty state exists.

Required task branch:

`task/s01-be-002-identity-persistence`

If the project owner already saved this approved task and its matching
`S01-BE-002-CODEX-PROMPT.md` under `tasks/backend/stage-01/` before execution,
those exact approved preparation files are permitted pre-task additions.

In that case:

- verify they are the only permitted preparation additions;
- do not commit them on `main`;
- create the task branch from synchronized `main` immediately;
- carry them into the task branch;
- perform all implementation/delivery from the task branch.

Any other unexplained modification is a blocker.

### 5.2 Institution enums / value objects

Create only persisted enums that are justified by the locked schema and are
actually used by models/tests.

At minimum:

`InstitutionType`

Exact values:

```text
school
college
lyceum
university
institute
learning_center
training_center
private_education
other
```

`InstitutionStatus`

Exact values:

```text
active
inactive
```

Use string-backed PHP enums if consistent with the accepted backend style.

Do not invent extra institution types/statuses.

### 5.3 User role enum

Create:

`UserRole`

Exact persisted values:

```text
platform_owner
institution_admin
teacher
student
parent
```

No custom roles.
No multi-role array.
No permission table.
No role-management API.

The user model has exactly one primary persisted role.

### 5.4 Institution settings enums

Because `institution_settings` contains locked constrained persisted values,
typed enums may be created and used for model casts for:

`BlitzTimerStartMode`

```text
synchronized
individual
```

`StudentResultReleaseMode`

```text
automatic
manual_teacher
```

`ParentResultReleaseMode`

```text
with_student
manual_teacher
hidden
```

These columns are nullable until explicitly configured later.

Do not introduce an enum/default for
`acceptable_score_difference`.

Do not introduce Homework/Blitz attempt-count settings: those columns are
explicitly absent from the MVP database contract.

### 5.5 `institutions` migration

Create/replace the application migration necessary for the exact locked
`institutions` table.

Columns:

| Column | PostgreSQL/Laravel intent | Null |
|---|---|---:|
| `id` | UUID primary key | no |
| `name` | varchar(200) | no |
| `type` | varchar(40) | no |
| `status` | varchar(20) | no |
| `contact_email` | varchar(254) | yes |
| `contact_phone` | varchar(50) | yes |
| `address` | text | yes |
| `description` | text | yes |
| `created_by_user_id` | UUID | yes |
| `deactivated_at` | timestamptz | yes |
| `created_at` | timestamptz | no |
| `updated_at` | timestamptz | no |

Required database constraints:

```text
name <> ''
```

```text
status in ('active', 'inactive')
```

```text
type in (
  'school',
  'college',
  'lyceum',
  'university',
  'institute',
  'learning_center',
  'training_center',
  'private_education',
  'other'
)
```

Required indexes:

```text
index(status)
index(type)
index(lower(name))
```

Use explicit, readable constraint/index names.

`created_by_user_id` creates a migration-order cycle because users reference
institutions. Follow the locked database guidance:

- create the column in the institutions migration;
- add its FK only after `users` exists, through a later constraint migration;
- FK target: `users.id`;
- historical-safety delete behavior: `RESTRICT`.

Do not invent institution hard-delete behavior/application endpoints.

### 5.6 `users` migration

Replace/adapt the framework default user migration so the final `users` table
matches the locked TestLabUz contract exactly.

Columns:

| Column | PostgreSQL/Laravel intent | Null |
|---|---|---:|
| `id` | UUID primary key | no |
| `institution_id` | UUID FK → institutions.id | yes only for platform owner |
| `role` | varchar(32) | no |
| `full_name` | varchar(200) | no |
| `login_name` | varchar(191) | no |
| `email` | varchar(254) | yes |
| `phone` | varchar(50) | yes |
| `password` | varchar(255) | no |
| `is_active` | boolean | no |
| `must_change_password` | boolean | no |
| `last_login_at` | timestamptz | yes |
| `deactivated_at` | timestamptz | yes |
| `created_by_user_id` | UUID | yes |
| `created_at` | timestamptz | no |
| `updated_at` | timestamptz | no |

Required role constraint:

```text
role in (
  'platform_owner',
  'institution_admin',
  'teacher',
  'student',
  'parent'
)
```

Required role/institution CHECK:

```text
(role = 'platform_owner' and institution_id is null)
OR
(role <> 'platform_owner' and institution_id is not null)
```

Required uniqueness:

```text
unique(login_name)
```

Do **not** enforce phone uniqueness.

Do **not** add email uniqueness unless a locked contract explicitly requires
it. The database document only leaves partial email uniqueness as an optional
future choice.

Required indexes:

```text
index(institution_id, role, is_active)
index(institution_id, lower(full_name))
index(role)
```

`users.institution_id` FK:

```text
→ institutions.id
on delete restrict
```

Use an explicit constraint name.

`users.created_by_user_id` must exist as specified. The locked FK summary does
not explicitly require a self-FK for this column. Do not invent a self-FK in
this task merely because the column contains an actor identifier.

Default/value rules:

- `is_active` defaults to `true`;
- do not use one unsafe blanket database default for
  `must_change_password` if it would make Platform Owner behavior incorrect;
- creation code/factories must set `must_change_password` explicitly according
  to role/context;
- account creation APIs are not implemented here.

Do not retain incompatible default Laravel auth fields such as integer IDs or
the framework's username assumptions if they conflict with this locked schema.

### 5.7 Sanctum `personal_access_tokens`

Sanctum is the approved token persistence mechanism.

Preserve/use Laravel Sanctum's standard table semantics while ensuring its
polymorphic owner key is compatible with UUID `users.id`.

If the Laravel-generated Sanctum migration uses an integer morph key,
adapt it safely to a UUID-compatible morph key.

Requirements:

- token records remain technical authentication data;
- tokens do not store role/institution authority independently of `users`;
- no plaintext token is stored;
- this task does not issue/revoke tokens through product endpoints.

Do not redesign Sanctum's table without a concrete UUID compatibility need.

### 5.8 `institution_settings` migration

Create the exact locked current-settings table.

Primary key / FK:

```text
institution_id uuid
primary key
foreign key → institutions.id
on delete restrict
```

Columns:

| Column | Type / intent | Null |
|---|---|---:|
| `institution_id` | UUID PK + FK | no |
| `acceptable_score_difference` | numeric(12,8) | yes |
| `blitz_timer_start_mode` | varchar(24) | yes |
| `student_result_release_mode` | varchar(30) | yes |
| `parent_result_release_mode` | varchar(30) | yes |
| `timezone` | varchar(64) | no |
| `learning_material_max_mb` | smallint | no |
| `student_submission_max_mb` | smallint | no |
| `updated_by_user_id` | UUID FK → users.id | yes |
| `created_at` | timestamptz | no |
| `updated_at` | timestamptz | no |

Safe operational initial values:

```text
timezone = 'Asia/Tashkent'
learning_material_max_mb = 25
student_submission_max_mb = 15
```

Educational-policy fields intentionally begin `NULL`:

```text
acceptable_score_difference
blitz_timer_start_mode
student_result_release_mode
parent_result_release_mode
```

Required constraints:

```text
acceptable_score_difference is null
OR acceptable_score_difference between 0 and 100
```

```text
blitz_timer_start_mode is null
OR blitz_timer_start_mode in ('synchronized', 'individual')
```

```text
student_result_release_mode is null
OR student_result_release_mode in ('automatic', 'manual_teacher')
```

```text
parent_result_release_mode is null
OR parent_result_release_mode in (
  'with_student',
  'manual_teacher',
  'hidden'
)
```

```text
learning_material_max_mb between 1 and 25
```

```text
student_submission_max_mb between 1 and 15
```

A simple non-empty database constraint for `timezone` is acceptable.

Do not attempt to reproduce the complete IANA timezone database in PostgreSQL.
Application-level timezone validation belongs to later settings-management
behavior when settings are edited.

`updated_by_user_id`:

```text
→ users.id
on delete restrict
```

Use an explicit FK name.

Do not add arbitrary attempt-limit columns.

### 5.9 Eloquent models

Implement the minimum clean Eloquent model foundation required by the schema.

At minimum:

- `Institution`;
- `User`;
- `InstitutionSetting`.

Requirements:

- UUID model behavior is correct;
- role/status/type/settings enum casts are used where appropriate;
- boolean casts:
  - `is_active`;
  - `must_change_password`;
- datetime casts:
  - `last_login_at`;
  - `deactivated_at`;
- `acceptable_score_difference` preserves its database precision;
- relationships reflect real current schema;
- `User` remains Laravel-auth compatible and uses Sanctum `HasApiTokens`;
- password storage remains hash-safe;
- no API serialization contract is implemented here unless needed by model
  tests.

Useful relationships may include:

```text
Institution
  hasMany Users
  hasOne InstitutionSetting
  belongsTo creator User (nullable)

User
  belongsTo Institution (nullable only for platform owner)
  belongsTo creator User where useful

InstitutionSetting
  belongsTo Institution
  belongsTo updater User (nullable)
```

Do not introduce repositories/services merely to wrap trivial Eloquent access.

### 5.10 Factories and controlled Stage 1 fixtures

Create reusable factories/states for persistence and later authentication
tests.

At minimum provide:

`InstitutionFactory`

- active institution default;
- inactive state;
- valid locked type/status values.

`InstitutionSettingFactory`

- safe operational defaults;
- educational-policy fields null by default;
- configurable valid states as needed by tests.

`UserFactory`

Role states:

```text
platformOwner()
institutionAdmin()
teacher()
student()
parent()
```

Additional useful states:

```text
inactive()
mustChangePassword()
withPassword(<plain-test-password>)
```

Rules:

- Platform Owner state has `institution_id = null`.
- Institution role states have an institution.
- Administrator-created Institution Admin/Teacher/Student/Parent factory states
  intended for Stage 1 onboarding should persist
  `must_change_password = true`.
- Do not automatically seed demo users into normal development/production
  databases.
- Do not commit one universal known product password.
- A test-only factory helper may accept a caller-provided plaintext test
  password and hash it.
- Default factories should use safe generated/hashed values where a known
  password is unnecessary.

Do not add Stage 2/3 account-management APIs.

### 5.11 Database seeder boundary

Keep `DatabaseSeeder` safe and minimal.

Do not automatically create:

- Platform Owner credentials;
- Institution Admin credentials;
- Teacher/Student/Parent demo credentials;
- production-like demo institutions.

If an official scaffold contains example/default user seeding, remove or
neutralize it unless it is explicitly required by the locked TestLabUz
contract.

Reusable factories are the controlled Stage 1 fixture mechanism for this task.

A later integration task may deliberately materialize runtime smoke accounts
with separately controlled credentials.

## 6. Migration Order / Cycle Handling

Follow the locked practical dependency order for the subset owned here:

```text
01 institutions
02 users
03 personal_access_tokens
04 institution_settings
```

Then add cyclic actor FKs only when both target tables exist.

At minimum:

```text
institutions.created_by_user_id
→ users.id
on delete restrict
```

must be added in a later constraint migration after `users`.

Do not reorder migrations in a way that creates an unresolved FK cycle.

Do not create future tables.

## 7. Relevant Files

Expected high-value change surface:

| Path | Expected action | Reason |
|---|---|---|
| `backend/app/Enums/*` | Create only actual persisted enums used now | Typed locked values |
| `backend/app/Models/Institution.php` | Create | Institution persistence |
| `backend/app/Models/User.php` | Adapt/replace | Exact TestLabUz auth identity |
| `backend/app/Models/InstitutionSetting.php` | Create | Institution session/settings context |
| `backend/database/migrations/*institutions*.php` | Create | Locked institutions schema |
| `backend/database/migrations/*users*.php` | Adapt/create | Locked users schema |
| `backend/database/migrations/*personal_access_tokens*.php` | Adapt if needed | UUID-compatible Sanctum persistence |
| `backend/database/migrations/*institution_settings*.php` | Create | Locked settings schema |
| `backend/database/migrations/*identity_actor_constraints*.php` | Create if needed | Cycle-safe actor FKs |
| `backend/database/factories/InstitutionFactory.php` | Create | Controlled test fixture |
| `backend/database/factories/UserFactory.php` | Adapt/create | Role/account fixture states |
| `backend/database/factories/InstitutionSettingFactory.php` | Create | Settings fixture |
| `backend/database/seeders/DatabaseSeeder.php` | Remove unsafe example seed behavior if present | No automatic demo credentials |
| `backend/tests/Feature/Persistence/*` | Create | PostgreSQL schema/model constraint tests |
| `tasks/backend/stage-01/S01-BE-002-identity-persistence-foundation.md` | Preserve approved task | Audit trail |
| `tasks/backend/stage-01/S01-BE-002-CODEX-PROMPT.md` | Preserve approved prompt | Manual execution artifact |
| `tasks/STAGE_01_TASK_INDEX.md` | Update lifecycle only | Stage control |

Do not modify locked `docs/01–09`.

Do not modify `frontend/`.

Do not add new Docker services.

## 8. Authoritative Specification References

| Document | Exact section | Requirement used |
|---|---|---|
| `docs/05-business-rules.md` | `2. Institution / Multi-Tenant Rules` | One institution per institution account, inactive status, safe settings defaults |
| `docs/05-business-rules.md` | `3. User and Role Rules` | Five roles, one primary role, active accounts, first-login flag for admin-created accounts |
| `docs/06-roadmap.md` | `6. Stage 1 — Authentication and Role-Based Entry` | Role/institution identity is required before Stage 1 auth |
| `docs/07-architecture.md` | `9. Identity and Authorization Architecture` | Five persisted roles, Sanctum, one role, trusted institution context, first-login state |
| `docs/08-database.md` | `1. Database Overview` | PostgreSQL shared-schema multi-institution model |
| `docs/08-database.md` | `2. Database Design Principles` | UUIDs, timestamptz, constrained varchar business enums, direct institution ownership |
| `docs/08-database.md` | `3. Multi-Institution / Tenant Model` | Platform Owner nullable-institution exception |
| `docs/08-database.md` | `4. Institutions` | Exact institutions columns/types/statuses/indexes/deletion rule |
| `docs/08-database.md` | `5. Users and Roles` | Exact users columns/roles/constraints/indexes and Sanctum table |
| `docs/08-database.md` | `8. Institution Settings` | Exact settings schema/defaults/null educational-policy fields/constraints |
| `docs/08-database.md` | `25. Foreign Keys and Referential Integrity` | Explicit FKs, cycle handling, `RESTRICT` historical safety |
| `docs/08-database.md` | `Recommended Migration Order` | institutions → users → tokens → settings |
| `docs/09-api-contracts.md` | `3. Authentication Contract` | `login_name`, role/institution/user fields, first-login flag that future auth API must expose |
| `docs/09-api-contracts.md` | `4. Current User / Session Contract` | `/auth/me` will need institution name/status/timezone |
| `backend/AGENTS.md` | Database/model/migration/testing/security rules | Backend implementation quality |
| `AGENTS.md` | Current task/Git workflow | Branch, acceptance, delivery, scope rules |
| `tasks/STAGE_01_TASK_INDEX.md` | `S01-BE-002` row and verification map | Approved stage decomposition |

## 9. Security / Tenant Rules

Even though request authorization is deferred, persistence must make unsafe
identity states difficult or impossible.

Required:

- only `platform_owner` may have null institution;
- `platform_owner` must not point to an institution;
- every other role must point to one valid institution;
- role values are database-constrained;
- institution status/type values are database-constrained;
- `login_name` is globally unique;
- plaintext passwords are never persisted;
- Sanctum records do not independently own role/institution authority;
- deletion of referenced institutions/users is restricted where required;
- no cross-institution relationship tables are created yet;
- no application endpoint trusts client-supplied role/institution because no
  such endpoint exists yet.

Do not weaken these database constraints to make factories/tests easier.

## 10. Requirements

### 10.1 Functional Requirements

1. `S01-INT-003` is independently verified as `Accepted`.
2. Work occurs on `task/s01-be-002-identity-persistence`.
3. All migrations run successfully against fresh PostgreSQL
   `testlabuz_testing`.
4. `institutions` exactly matches the locked identity subset.
5. `users` exactly matches the locked identity subset.
6. UUID primary keys are used for domain identity.
7. All five exact user role values are supported.
8. Role/institution CHECK is enforced by PostgreSQL.
9. `login_name` is globally unique.
10. Phone uniqueness is not imposed.
11. No unapproved email uniqueness is imposed.
12. Institution type/status constraints are enforced.
13. Required institution/user indexes exist, including expression indexes.
14. `personal_access_tokens` works with UUID users.
15. `institution_settings` exact schema exists.
16. Safe operational settings defaults are available.
17. Educational-policy settings are null by default.
18. Attempt-count settings are absent.
19. Required settings range/value constraints are enforced.
20. Required explicit FKs use historical-safety `RESTRICT`.
21. Cycle-safe institution creator FK is added after users exist.
22. Eloquent models persist/read the exact schema cleanly.
23. User model is Sanctum-compatible.
24. Controlled factories cover all five roles plus active/inactive states.
25. No automatic demo credentials are seeded.
26. No login/logout/me/change-password endpoint is created.
27. No active-user/institution request middleware is created.
28. No role authorization policy/middleware is created.
29. Full backend tests pass against PostgreSQL.
30. Pint and Composer validation remain green.
31. Locked docs/frontend remain unchanged.

### 10.2 Non-functional Quality Requirements

- Migration names/order are deterministic and reviewable.
- Every added DB CHECK/FK/index has a stable explicit name where Laravel/
  PostgreSQL supports it.
- Avoid DB raw SQL except where PostgreSQL-specific CHECK/expression-index
  behavior cannot be expressed clearly/safely through Schema Builder.
- PostgreSQL-specific SQL must be centralized in migrations, readable, and
  covered by tests.
- Models do not contain authentication HTTP logic.
- Factories do not hide invalid cross-tenant states through after-create hacks.
- Tests assert real PostgreSQL constraint behavior rather than only model
  validation.

## 11. Required Tests and Verification

### 11.1 Git / dependency preflight

Run safe equivalents:

```text
git rev-parse --show-toplevel
git status --short
git branch --show-current
git remote -v
git fetch origin
git rev-parse main
git rev-parse origin/main
```

Verify `S01-INT-003` accepted state from repository evidence.

### 11.2 Fresh database migration proof

Using the accepted Docker/PostgreSQL test runtime, prove migrations work from
an empty isolated test database.

Use an equivalent safe process such as:

```text
php artisan migrate:fresh --env=testing
```

or the repository's accepted PostgreSQL test command.

The command must target `testlabuz_testing`, never the normal development DB.

Before destructive database operations, independently prove current database is
the testing database.

### 11.3 Schema / constraint tests

Add PostgreSQL-backed tests covering at minimum:

#### Institutions

- generated IDs are UUIDs;
- valid type/status persist;
- invalid status rejected by DB;
- invalid type rejected by DB;
- empty institution name rejected by DB;
- required settings relationship can exist;
- referenced institution cannot be deleted when historical-safety FK makes it
  restricted.

#### Users

- UUID user persists;
- all five roles can persist in valid institution state;
- `platform_owner + institution_id null` succeeds;
- `platform_owner + institution_id non-null` is rejected;
- institution role + valid institution succeeds;
- institution role + null institution is rejected;
- invalid role is rejected;
- duplicate `login_name` is rejected;
- same/null phone values are not incorrectly globally unique;
- password stored in test fixture is hashed, not plaintext;
- `is_active` cast behaves as boolean;
- `must_change_password` cast behaves as boolean.

#### Sanctum

Without adding product auth endpoints:

- create a valid user;
- call the model's Sanctum token-creation primitive;
- confirm token persistence succeeds for UUID user;
- confirm token row links to the UUID user;
- confirm persisted token value is not the returned plaintext token;
- cleanly revoke/delete test token through Sanctum/model primitive where useful.

#### Institution settings

- one settings row per institution;
- PK/FK is institution UUID;
- default/safe timezone is `Asia/Tashkent`;
- default upload limits are 25 and 15;
- educational-policy fields can be null;
- score difference below 0/above 100 rejected;
- invalid timer mode rejected;
- invalid Student release mode rejected;
- invalid Parent release mode rejected;
- upload limits outside locked ranges rejected;
- no attempt-limit columns exist.

#### Foreign keys

- invalid `users.institution_id` rejected;
- invalid `institution_settings.institution_id` rejected;
- invalid `institution_settings.updated_by_user_id` rejected;
- institution creator FK behaves after users exist.

Do not add future Group/Topic/Assessment tables for tests.

### 11.4 Model / factory tests

Verify:

- role/status/type enum casting;
- user role factory states create valid institution ownership;
- Platform Owner factory state does not silently create an institution;
- onboarding institution-user factory state has
  `must_change_password = true`;
- inactive states work;
- known test password helper hashes caller-provided value;
- DatabaseSeeder does not create demo credentials by default.

### 11.5 Full backend quality gates

Run inside the accepted PostgreSQL runtime:

```text
php artisan test
vendor/bin/pint --test
composer validate --strict
```

Run any additional mandatory backend checks established by accepted earlier
tasks.

If `composer audit` is part of the accepted baseline and network is available,
run/report it without changing unrelated dependencies.

### 11.6 Schema inspection

Use PostgreSQL/Laravel inspection to verify actual database types and
constraints, not only migration source text.

Evidence should include:

- UUID PK types;
- `timestamptz` identity timestamps;
- role/institution CHECK;
- enum-like CHECK constraints;
- required unique/index definitions;
- settings PK/FKs;
- UUID-compatible Sanctum morph key.

Do not dump password hashes or token values into the report.

### 11.7 Scope / secret checks

Before acceptance gate:

```text
git status --short
git diff --check
git diff main...HEAD -- docs
git diff main...HEAD -- frontend
git diff main...HEAD -- docker
```

`docker/` should not change unless an unavoidable test-runtime correction is
required by a discovered defect in accepted `S01-INT-003`; if so, stop rather
than silently expanding this task.

Scan tracked/staged changes for:

- `.env`;
- plaintext passwords;
- tokens;
- API keys;
- certificates/private keys;
- generated secrets.

Do not print any secret value.

## 12. Manual Smoke Check

Using the accepted PostgreSQL runtime:

1. Start the local backend/database runtime if not already running.
2. Fresh-migrate only the isolated test database.
3. Create an active institution through a factory/test command.
4. Create one valid user of each role.
5. Confirm Platform Owner has null institution.
6. Confirm other four roles resolve to an institution.
7. Create institution settings and verify timezone/default upload limits.
8. Create a Sanctum token through model primitive and verify UUID token
   persistence.
9. Confirm no authentication HTTP route had to be added.
10. Stop/leave runtime according to accepted local-development procedure.

Do not create persistent shared demo credentials.

## 13. Explicit Non-Goals

- Login API.
- Logout API.
- `/auth/me`.
- Change-password API.
- API token issuance endpoint.
- API token revocation endpoint.
- Active-user request guard.
- Active-institution request guard.
- First-login password-change middleware.
- Role authorization policies.
- Institution CRUD API/UI.
- User CRUD API/UI.
- Groups.
- Teacher/student group memberships.
- Parent-student relationships.
- Topics/materials/assessments.
- Institution understanding-category table.
- Educational setting editing services/API.
- Runtime smoke-account seeder with shared credentials.
- Flutter.
- CI.
- New Docker services.
- Production deployment.

## 14. Stop Conditions

Stop and report instead of improvising if:

- `S01-INT-003` is not `Accepted`;
- accepted PostgreSQL test runtime is unavailable/broken;
- local `main` cannot safely synchronize with `origin/main`;
- unrelated dirty state exists;
- approved task branch cannot be created safely;
- current accepted Laravel/Sanctum structure differs materially from the
  assumptions needed for UUID adaptation;
- implementing the exact locked schema requires changing `docs/01–09`;
- a migration-order cycle cannot be solved using the locked later-constraint
  strategy;
- an exact required DB constraint is ambiguous in the locked database doc;
- a correct solution requires Stage 2/3 institution/user management behavior;
- a correct solution requires auth endpoint behavior from `S01-BE-003`;
- a correct solution requires role middleware from `S01-BE-005`;
- a secret/credential would need to be committed;
- safe completion requires destructive Git operations, force-push, history
  rewrite, check bypass, or material scope expansion.

Do not weaken constraints or invent missing product behavior to avoid a stop
condition.

## 15. Execution, Acceptance, and GitHub Delivery Workflow

### Phase 0 — Git Preflight

1. Complete Section 5.1.
2. Verify PostgreSQL test runtime.
3. Create/switch to:
   `task/s01-be-002-identity-persistence`.
4. Ensure the approved task and matching Codex prompt exist on the task branch.
5. Update only the `S01-BE-002` Stage 1 index row to `Approved` if the repository
   workflow requires lifecycle materialization.
6. Do not commit or push.

### Phase 1 — Implementation

Implement only this task.

Run:

- fresh PostgreSQL migration proof;
- persistence/constraint tests;
- Sanctum UUID persistence tests;
- factory/model tests;
- full backend tests;
- Pint;
- Composer validation;
- schema inspection;
- secret/scope checks.

Do not commit/push.

### Phase 2 — Read-Only Acceptance Gate

Re-read:

- complete `S01-BE-002`;
- root/backend `AGENTS.md`;
- referenced locked contracts;
- full task-branch diff;
- actual PostgreSQL schema evidence;
- all test/quality results.

During Phase 2:

- no file edits;
- no automated fixes;
- no new staging;
- no commit;
- no push;
- no merge.

Classify review findings:

- `P1` — blocks acceptance/security/data-integrity issue;
- `P2` — material contract/architecture/test mismatch;
- `P3` — non-blocking observation.

If any blocking/material finding remains:

```text
FINAL STATUS: NOT ACCEPTED
```

Return findings/evidence and stop.

Do not self-fix after Phase 2 starts.

### Phase 3 — Post-Acceptance Git Delivery

Run only after Phase 2 passes.

1. Change this task status to `Accepted`.
2. Update `tasks/STAGE_01_TASK_INDEX.md`:
   - Task status `Accepted`;
   - Review status `PASS`;
   - Delivery status finalized after merge.
3. Re-run final:
   - `git diff --check`;
   - secret scan;
   - locked docs/frontend/docker scope checks.
4. Stage only approved task changes.
5. Create one focused commit.

Preferred commit subject:

`feat(identity): add persistence foundation`

Commit body:

`Task: S01-BE-002`

6. Push task branch to `origin`.
7. Open PR to `main` when authenticated GitHub tooling permits.
8. Do not bypass protection/checks.
9. Merge only when safely mergeable and required checks pass.
10. Delete remote task branch after successful merge if normal policy/tooling
    permits.
11. Synchronize local `main` from `origin/main` with fast-forward-safe
    operations.
12. Verify:
    - local `main == origin/main`;
    - working tree clean;
    - accepted task/index bookkeeping exists on `origin/main`.

If review passed but safe GitHub delivery cannot complete:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Do not start `S01-BE-003`.

If everything succeeds:

```text
FINAL STATUS: ACCEPTED
```

## 16. Required Codex Final Report

Return:

1. **Final status** — exactly one:
   - `ACCEPTED`
   - `NOT ACCEPTED`
   - `DELIVERY BLOCKED`
2. **Dependency/Git preflight evidence**.
3. **Implementation summary**.
4. **Changed files** grouped by:
   - enums/models;
   - migrations/constraints;
   - factories/seed boundary;
   - tests;
   - task bookkeeping.
5. **Schema evidence**:
   - migration order;
   - UUID PKs;
   - `timestamptz`;
   - exact constraints/indexes;
   - FKs;
   - Sanctum UUID token key.
6. **Tenant/role integrity evidence**.
7. **Factory/fixture evidence** without exposing passwords.
8. **Acceptance gate findings**.
9. **Acceptance criteria** PASS/FAIL individually.
10. **Tests/quality gates** exact commands/results.
11. **Security evidence**:
    - hashed password behavior;
    - token persistence;
    - no secrets/demo credentials.
12. **Scope confirmation** — no auth endpoints/role middleware/Stage 2+ behavior.
13. **GitHub delivery evidence**:
    - commit hash/subject;
    - pushed branch;
    - PR reference if available;
    - merge result;
    - local `main` hash;
    - `origin/main` hash;
    - final clean state.
14. **Manual smoke status**.
15. **Remaining blockers/deviations**.

Do not start `S01-BE-003`.
