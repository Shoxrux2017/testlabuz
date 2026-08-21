# S04-BE-001 — Group and Relationship Persistence Foundation

## Task Metadata

| Field | Value |
|---|---|
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | Backend |
| Status | `Approved` |
| Depends on | Stage 3 closed; Stage 4 decomposition/task index approved |
| Implementation type | Laravel/PostgreSQL persistence foundation |
| Delivery | Implementation + GitHub delivery |
| Planning baseline | `origin/main` @ `ec2141a1e74fdcff51c0e7d8715b5346444403af` (verified 2026-08-21) |
| Implementation gate | Before Codex starts, ChatGPT/orchestration must approve the Stage 4 decomposition, change this task to `Approved`, and freeze the exact current `origin/main` implementation baseline |
| Block checkpoint | Stage 4 Backend Phase 2 Review after all approved Stage 4 backend tasks are `Accepted` and delivered |

## 1. Implementation Authority and Required Inputs

This file is the complete implementation contract for `S04-BE-001`.

Codex must read only:

1. this task;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. existing backend source, migrations, factories, and tests directly required by this task.

Do not read product specifications, roadmap files, architecture documents, API documents, previous tasks, Stage history, task indexes, closure reviews, or unrelated modules to determine what to implement.

Before starting Codex, ChatGPT/orchestration must:

- confirm that Stage 3 Closure is delivered;
- approve the Stage 4 decomposition/task index;
- change this task status from `Draft` to `Approved`;
- provide the exact current `origin/main` implementation baseline commit;
- ensure local `main` is clean and synchronized with that `origin/main` baseline.

Codex validates only that the provided branch/commit matches the current worktree and performs the task Git preflight defined in this contract. Codex must not inspect Stage history or closure evidence itself.

If the repository state materially conflicts with this contract, stop and report the exact conflict. Do not redesign the contract.

## 2. Goal

Create the PostgreSQL and Eloquent persistence foundation for:

- Institution Groups;
- historical Teacher–Group memberships;
- historical Student–Group memberships;
- historical Parent–Student relationships.

The result must provide tenant-safe structural storage, database invariants, explicit Eloquent models/relationships, deterministic factories, and focused persistence tests. It must not expose API behavior or implement relationship-management use cases.

## 3. Included Scope

- Forward-only Stage 4 migrations; do not edit delivered migrations.
- `GroupStatus` enum.
- `Group`, `GroupTeacherMembership`, `GroupStudentMembership`, and `ParentStudentRelationship` models.
- Necessary relationships on `Institution`, `User`, and the new models.
- Factories for the four new models.
- A focused `current` query scope on each historical relationship model.
- PostgreSQL constraints, foreign keys, partial unique indexes, and query indexes defined below.
- Focused PostgreSQL schema, persistence, model, relationship, scope, and factory tests.

## 4. Explicit Non-Goals

Do not add or change:

- routes, controllers, Form Requests, Resources, Actions, policies, middleware, or public API responses;
- Group list/create/detail/update/archive use cases;
- Teacher/Student assignment or removal use cases;
- Parent–Student connection or removal use cases;
- future Topic, Homework, Blitz, reporting, delivery, or progress behavior;
- frontend code;
- seed/demo data;
- dependency packages or lockfiles;
- existing authentication, User lifecycle, institution settings, or category behavior;
- task/Stage bookkeeping, documentation, or instruction files.

Do not add soft deletes. Do not add role-checking triggers, PostgreSQL RLS, generic repository layers, or speculative authorization services.

## 5. Persistence Contract

### 5.1 Shared conventions

- All primary and foreign identifiers use PostgreSQL `uuid`.
- All lifecycle and Laravel timestamps use `timestamp with time zone`.
- `created_at` and `updated_at` are non-null.
- All foreign keys use explicit names and `on delete restrict` behavior.
- Historical relationships are ended with `ended_at`; they are never physically deleted as normal application behavior.
- A relationship is current exactly when `ended_at is null`.
- Role correctness is an application-layer responsibility for later tasks. This task enforces tenant consistency and structural integrity at database level.

### 5.2 `groups`

| Column | Type | Null | Contract |
|---|---|---:|---|
| `id` | uuid | no | Primary key |
| `institution_id` | uuid | no | Tenant owner |
| `name` | varchar(160) | no | Non-empty after PostgreSQL `btrim` |
| `level` | varchar(100) | yes | Optional class/level |
| `subject_direction` | varchar(160) | yes | Optional subject direction |
| `description` | text | yes | Optional |
| `status` | varchar(20) | no | `active` or `archived` |
| `created_by_user_id` | uuid | no | Same-Institution creator |
| `archived_at` | timestamptz | yes | Null for active; non-null for archived |
| `created_at` | timestamptz | no | Laravel timestamp |
| `updated_at` | timestamptz | no | Laravel timestamp |

Required constraints and indexes:

- `groups_name_not_empty_check`: `btrim(name) <> ''`.
- `groups_status_check`: status is `active` or `archived`.
- `groups_status_archived_at_check`: active requires `archived_at is null`; archived requires `archived_at is not null`.
- FK `groups_institution_id_foreign`: `institution_id -> institutions.id`.
- Same-tenant composite FK `groups_institution_creator_foreign`: `(institution_id, created_by_user_id) -> users(institution_id, id)`.
- Unique constraint `groups_institution_id_id_unique` on `(institution_id, id)` for composite references.
- Index `groups_institution_status_index` on `(institution_id, status)`.
- Expression index `groups_institution_lower_name_index` on `(institution_id, lower(name))`.

Group names are intentionally not unique. Identical names are valid across institutions and inside the same institution, including across time.

### 5.3 `group_teacher_memberships`

| Column | Type | Null | Contract |
|---|---|---:|---|
| `id` | uuid | no | Primary key |
| `institution_id` | uuid | no | Tenant owner |
| `group_id` | uuid | no | Same-Institution Group |
| `teacher_id` | uuid | no | Same-Institution User; role checked later |
| `assigned_by_user_id` | uuid | no | Same-Institution assigning actor |
| `started_at` | timestamptz | no | Membership start |
| `ended_at` | timestamptz | yes | Null means current |
| `created_at` | timestamptz | no | Laravel timestamp |
| `updated_at` | timestamptz | no | Laravel timestamp |

Required constraints and indexes:

- FK `group_teacher_memberships_institution_id_foreign`: `institution_id -> institutions.id`.
- Same-tenant composite FK `group_teacher_memberships_group_tenant_foreign`: `(institution_id, group_id) -> groups(institution_id, id)`.
- Same-tenant composite FK `group_teacher_memberships_teacher_tenant_foreign`: `(institution_id, teacher_id) -> users(institution_id, id)`.
- Same-tenant composite FK `group_teacher_memberships_assigned_by_tenant_foreign`: `(institution_id, assigned_by_user_id) -> users(institution_id, id)`.
- Temporal check `group_teacher_memberships_time_order_check`: `ended_at is null or ended_at >= started_at`.
- Partial unique index `group_teacher_memberships_current_unique`: `(group_id, teacher_id) where ended_at is null`.
- Index `group_teacher_memberships_institution_teacher_ended_index`: `(institution_id, teacher_id, ended_at)`.
- Index `group_teacher_memberships_institution_group_ended_index`: `(institution_id, group_id, ended_at)`.

### 5.4 `group_student_memberships`

Use the same contract as Teacher membership with these target fields:

- `student_id` instead of `teacher_id`;
- FK `group_student_memberships_institution_id_foreign`: `institution_id -> institutions.id`;
- composite FK `group_student_memberships_group_tenant_foreign`: `(institution_id, group_id) -> groups(institution_id, id)`;
- composite FK `group_student_memberships_student_tenant_foreign`: `(institution_id, student_id) -> users(institution_id, id)`;
- composite FK `group_student_memberships_assigned_by_tenant_foreign`: `(institution_id, assigned_by_user_id) -> users(institution_id, id)`;
- temporal check `group_student_memberships_time_order_check`;
- partial unique index `group_student_memberships_current_unique`: `(group_id, student_id) where ended_at is null`;
- index `group_student_memberships_institution_student_ended_index`: `(institution_id, student_id, ended_at)`;
- index `group_student_memberships_institution_group_ended_index`: `(institution_id, group_id, ended_at)`.

All other columns, temporal behavior, actor scoping, timestamps, and restrictive foreign-key rules match `group_teacher_memberships`.

### 5.5 `parent_student_relationships`

| Column | Type | Null | Contract |
|---|---|---:|---|
| `id` | uuid | no | Primary key |
| `institution_id` | uuid | no | Tenant owner |
| `parent_id` | uuid | no | Same-Institution User; role checked later |
| `student_id` | uuid | no | Same-Institution User; role checked later |
| `connected_by_user_id` | uuid | no | Same-Institution connecting actor |
| `started_at` | timestamptz | no | Relationship start |
| `ended_at` | timestamptz | yes | Null means current |
| `created_at` | timestamptz | no | Laravel timestamp |
| `updated_at` | timestamptz | no | Laravel timestamp |

Required constraints and indexes:

- FK `parent_student_relationships_institution_id_foreign`: `institution_id -> institutions.id`.
- Composite FK `parent_student_relationships_parent_tenant_foreign`: `(institution_id, parent_id) -> users(institution_id, id)`.
- Composite FK `parent_student_relationships_student_tenant_foreign`: `(institution_id, student_id) -> users(institution_id, id)`.
- Composite FK `parent_student_relationships_connected_by_tenant_foreign`: `(institution_id, connected_by_user_id) -> users(institution_id, id)`.
- Temporal check `parent_student_relationships_time_order_check`: `ended_at is null or ended_at >= started_at`.
- Partial unique index `parent_student_relationships_current_unique`: `(parent_id, student_id) where ended_at is null`.
- Index `parent_student_relationships_institution_parent_ended_index`: `(institution_id, parent_id, ended_at)`.
- Index `parent_student_relationships_institution_student_ended_index`: `(institution_id, student_id, ended_at)`.

### 5.6 Composite User tenant key

Add the unique constraint `users_institution_id_id_unique` on `(institution_id, id)`, making `users(institution_id, id)` the exact composite foreign-key target.

Requirements:

- Preserve all existing User rows and behavior.
- Do not change the existing UUID primary key or role/institution check.
- Platform Owner rows with `institution_id = null` remain valid.
- Rollback must remove Stage 4 relationship tables before removing `users_institution_id_id_unique`.

## 6. Eloquent Contract

### 6.1 Enum

Add string-backed `GroupStatus` with exactly:

```text
active
archived
```

### 6.2 Models

Each new model must:

- use UUIDs and the existing factory convention;
- declare explicit writable attributes;
- cast lifecycle timestamps to datetime;
- cast `Group.status` to `GroupStatus`;
- expose only relationships it actually owns;
- avoid hidden queries, lifecycle decisions, authorization, or workflow behavior.

Required relationships:

- `Institution -> groups`.
- `Group -> institution`, `creator`, `teacherMemberships`, `studentMemberships`.
- `GroupTeacherMembership -> institution`, `group`, `teacher`, `assigner`.
- `GroupStudentMembership -> institution`, `group`, `student`, `assigner`.
- `ParentStudentRelationship -> institution`, `parent`, `student`, `connector`.
- `User -> teacherGroupMemberships` through `teacher_id`.
- `User -> studentGroupMemberships` through `student_id`.
- `User -> parentStudentRelationships` through `parent_id`.
- `User -> studentParentRelationships` through `student_id`.

Do not add actor-side inverse relationships for `created_by_user_id`, `assigned_by_user_id`, or `connected_by_user_id` in this task. The new models still expose their required `creator`, `assigner`, and `connector` `BelongsTo` relationships.

Do not add `BelongsToMany` shortcuts that hide historical relationship rows.

### 6.3 Current scope

Each historical relationship model must provide a focused Eloquent `current` scope equivalent to:

```text
where ended_at is null
```

Do not embed active-user, active-group, authorization, or tenant decisions into this scope.

### 6.4 Factories

Factories must create valid same-Institution records by default.

Required behavior:

- Group factory defaults to an active Group with `archived_at = null` and a same-Institution Institution Admin creator.
- An archived Group factory state sets both `status = archived` and a non-null `archived_at`.
- Teacher/Student membership factories create the correct User role, same-Institution Group, and same-Institution Institution Admin assigner.
- Parent–Student factory creates the correct roles and same-Institution connector.
- Relationship factories default to current and provide an ended/historical state with valid temporal ordering.
- Explicit model overrides used by tests must remain possible without factories silently replacing them.

## 7. Migration Safety

- Use new forward migrations only.
- Preserve all existing rows.
- Use PostgreSQL-compatible SQL and explicit constraint/index names.
- Creation order must satisfy referenced composite keys and foreign keys.
- Rollback order must drop Parent/Student and Group membership tables before Groups and before the User composite support key.
- Do not weaken or remove an existing constraint or index.
- Do not manually mutate a shared database outside migrations/tests.

## 8. Required Focused Tests

Add exactly these focused test files following the existing PostgreSQL persistence-test style:

- `tests/Feature/Persistence/GroupRelationshipSchemaInspectionTest.php`
- `tests/Feature/Persistence/GroupRelationshipPersistenceTest.php`
- `tests/Feature/Persistence/GroupRelationshipFactoryModelTest.php`

### Schema inspection

Verify:

- every new table and required column exists;
- UUID and timestamptz types;
- exact nullability;
- named check/foreign-key constraints;
- composite support keys;
- partial unique and query indexes.

### Persistence invariants

Verify:

- valid Group and all three relationship types persist;
- same Group name is allowed twice inside one Institution and across Institutions;
- invalid/blank Group name, invalid status, and inconsistent `status/archived_at` are rejected;
- cross-Institution creator, Group, Teacher, Student, Parent, assigner, and connector combinations are rejected by PostgreSQL;
- a second current row for the same pair is rejected;
- multiple ended historical rows are allowed;
- a new current row is allowed after the previous row is ended;
- `ended_at < started_at` is rejected;
- restrictive foreign keys preserve referenced history.

### Models, relationships, scopes, and factories

Verify:

- UUID generation and enum/datetime casts;
- required forward and inverse relationships;
- `current` excludes ended rows;
- default factories always produce same-Institution, role-correct valid records;
- archived/ended factory states satisfy database invariants;
- explicit same-Institution model overrides remain intact and are not silently replaced by factory defaults.

Do not test API or later application-role validation in this task.

## 9. Proportional Verification

Run these exact commands from `backend/`:

```bash
./vendor/bin/pint --test

php artisan test \
  tests/Feature/Persistence/GroupRelationshipSchemaInspectionTest.php \
  tests/Feature/Persistence/GroupRelationshipPersistenceTest.php \
  tests/Feature/Persistence/GroupRelationshipFactoryModelTest.php

php artisan test \
  tests/Feature/Persistence/IdentitySchemaInspectionTest.php \
  tests/Feature/Persistence/InstitutionPersistenceTest.php \
  tests/Feature/Persistence/UserPersistenceTest.php \
  tests/Feature/Persistence/UserFactoryModelTest.php
```

Then run from the repository root:

```bash
git diff --check
git status --short
```

After the commands, inspect the complete task diff and perform the focused scope/security self-review required by the applicable `AGENTS.md` files.

Do not run the full backend suite in this task. It belongs to the Stage 4 Backend Checkpoint unless a concrete directly affected failure requires a narrowly justified additional regression test.

## 10. Acceptance Criteria

This task is implementation-complete only when:

- all four tables and the User composite tenant key match this contract;
- PostgreSQL prevents cross-Institution relationship rows and duplicate current pairs;
- historical periods remain representable without deletion;
- Eloquent models, casts, relationships, scopes, and factories are focused and correct;
- existing User/Institution persistence behavior remains unchanged;
- all required focused verification passes;
- no API, frontend, unrelated refactor, dependency, documentation, or Stage bookkeeping change is present.

Task implementation and focused checks alone do not constitute task acceptance until approved GitHub delivery is complete. `S04-BE-001` becomes `Accepted` when this contract is satisfied, the required focused verification passes, the focused task change is delivered to `origin/main`, local `main == origin/main`, ahead/behind is `0/0`, and the worktree is clean.

The later Stage 4 Backend Phase 2 checkpoint reviews the combined backend block after all approved backend tasks are already `Accepted` and delivered. Phase 2 is not a prerequisite for individual task acceptance; if it finds a cross-task defect, resolve it through a focused fix task and re-run the affected checkpoint.

## 11. Stop Conditions

Stop and report instead of inventing a solution if:

- Stage 4 decomposition/task index is not approved, this task is not `Approved`, or the frozen implementation baseline commit was not provided or does not match the current worktree;
- root `AGENTS.md` or `backend/AGENTS.md` is missing, materially conflicts with this contract, or cannot be applied;
- existing schema/data makes a required constraint unsafe and the conflict is not resolved by this contract;
- the repository already contains materially different Group/relationship persistence;
- a required change would alter public API, existing product behavior, or another Stage;
- pre-existing work overlaps this task and cannot be safely preserved;
- PostgreSQL tooling or the configured test database is unavailable;
- a required focused check fails and cannot be corrected within this contract.

## 12. Completion Report

Return a concise evidence-based report containing:

- implementation summary;
- changed files and their purpose;
- migrations, constraints, and indexes added;
- exact verification commands and results;
- confirmation that non-goals remained excluded;
- deviations, pre-existing failures, or blockers;
- current Git status.

Delivery mode for this task is `Implementation + GitHub delivery`. After implementation and all required focused checks pass, Codex must:

1. stage only task-owned implementation/test files;
2. create one focused commit;
3. push the task branch;
4. open or update a Pull Request to `main`;
5. merge only when required checks pass and merge is permitted by the active workflow;
6. fetch and synchronize local `main`;
7. verify local `main == origin/main`, ahead/behind `0/0`, and a clean worktree.

If safe delivery cannot complete, return `DELIVERY BLOCKED`. Do not modify task/Stage bookkeeping or begin `S04-BE-002` unless separately assigned.
