# S05-BE-001 — Topic and Learning Material Persistence Foundation

## Task Metadata

| Field | Value |
|---|---|
| Stage | `Stage 5 — Topics and Learning Materials` |
| Area | Backend |
| Status | `Approved` |
| Implementation type | Laravel/PostgreSQL persistence foundation |
| Depends on | Stage 4 closed; Stage 5 decomposition approved |
| Planning baseline | `origin/main` @ `de9a8fee099a2947f6687ee9e6b219e612c93bff` |
| Implementation baseline | `Freeze current origin/main after Stage 5 planning-package delivery and before Codex starts` |
| Verification model | `Workflow v3 — Lean Verification` |
| Delivery owner | `Project Owner` |
| Block checkpoint | Stage 5 Backend Phase 2 after `S05-BE-001…005` are Accepted / Delivered |

---

## 1. Implementation Authority and Required Inputs

This file is the complete implementation contract for `S05-BE-001`.

Codex must read only:

1. this task;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. existing backend source, migrations, factories, and tests directly required
   to implement this task.

Codex must not read product specifications, roadmap files, architecture
documents, API documents, Stage indexes, closure reviews, previous task files,
or Stage history to rediscover or reinterpret requirements.

Before Codex starts, ChatGPT / orchestration must:

- confirm that the Stage 5 planning package has been delivered to `origin/main`;
- confirm this task is the next permitted task;
- freeze the exact current `origin/main` implementation baseline;
- ensure the local worktree is clean and synchronized with that baseline.

Codex validates only repository/worktree compatibility with the provided
baseline and this contract. If the current source materially conflicts with the
contract, stop and report the exact conflict instead of making a product,
schema, security, lifecycle, or architecture decision.

---

## 2. Goal

Create the PostgreSQL and Eloquent persistence foundation for:

- `topics`;
- shared private-file metadata in `files`;
- `learning_materials`.

The result must provide:

- tenant-safe structural storage;
- database-enforced structural lifecycle/file invariants;
- explicit Eloquent models and relationships;
- deterministic factories;
- focused PostgreSQL persistence/schema tests.

This task does not expose HTTP/API behavior and does not perform real file
storage operations.

---

## 3. Included Scope

Implement only:

- one or more new forward-only Stage 5 migrations required by this contract;
- `TopicStatus` string-backed enum;
- `FileCategory` string-backed enum;
- `FileExtension` string-backed enum;
- `Topic`, `File`, and `LearningMaterial` Eloquent models;
- required inverse relationships on existing `Institution`, `Group`, and `User`
  models;
- factories for `Topic`, `File`, and `LearningMaterial`;
- PostgreSQL constraints, restrictive foreign keys, composite tenant support
  keys, uniqueness, and indexes defined below;
- focused schema-inspection, persistence-invariant, and factory/model tests.

The `files` table is the shared MVP structural table for both:

```text
learning_material
student_submission
```

This task creates the complete structural category support now because later
MVP stages use the same table. Stage 5 behavior in this task remains limited to
persistence; no Student-submission API or workflow is implemented.

---

## 4. Explicit Non-Goals

Do not add or change:

- routes;
- controllers;
- Form Requests;
- Resources;
- Actions/use cases;
- policies;
- middleware;
- public API responses;
- Teacher Topic APIs;
- Student Topic APIs;
- Topic lifecycle actions;
- upload/download endpoints;
- `Storage::put`, physical file creation, deletion, move, or streaming;
- MIME/extension agreement validation;
- Institution lower-limit validation;
- Teacher–Group authorization;
- Student–Group authorization;
- Parent file access;
- seed/demo data;
- frontend code;
- new Composer/NPM/Flutter dependencies;
- existing authentication or Stage 1–4 business behavior;
- Stage 6 Homework or later assessment behavior;
- task/Stage bookkeeping, docs, roadmap, or instruction files.

Do not introduce:

- soft deletes;
- PostgreSQL RLS;
- role-checking database triggers;
- generic repository/service frameworks;
- speculative abstractions.

---

## 5. Shared Persistence Conventions

Use the repository’s established Laravel/PostgreSQL conventions.

Required:

- domain IDs use PostgreSQL `uuid`;
- Laravel/lifecycle instants use `timestamp with time zone`;
- `created_at` and `updated_at` are non-null;
- all foreign keys use explicit names;
- all foreign keys in this task use `ON DELETE RESTRICT`;
- institution-owned child references use same-tenant composite foreign keys
  where the target has/receives `(institution_id, id)` uniqueness;
- structural integrity belongs in PostgreSQL where practical;
- contextual role/membership authorization remains application-layer behavior
  for later Stage 5 tasks;
- delivered migrations must not be edited when a forward migration is
  appropriate.

Add any required `(institution_id, id)` composite support unique constraint only
when it does not already exist.

---

## 6. `topics` Persistence Contract

### 6.1 Columns

| Column | Type | Null | Contract |
|---|---|---:|---|
| `id` | uuid | no | Primary key |
| `institution_id` | uuid | no | Tenant owner |
| `group_id` | uuid | no | Same-Institution Group |
| `teacher_id` | uuid | no | Same-Institution owning User; Teacher role validated later |
| `title` | varchar(255) | no | Non-empty after PostgreSQL `btrim` |
| `description` | text | yes | Optional |
| `subject` | varchar(160) | no | Non-empty after `btrim` |
| `student_instructions` | text | no | Non-empty after `btrim` |
| `lesson_at` | timestamptz | yes | Optional authoritative instant |
| `status` | varchar(20) | no | `draft|active|closed|archived` |
| `activated_at` | timestamptz | yes | Lifecycle timestamp |
| `closed_at` | timestamptz | yes | Lifecycle timestamp |
| `archived_at` | timestamptz | yes | Lifecycle timestamp |
| `created_at` | timestamptz | no | Laravel timestamp |
| `updated_at` | timestamptz | no | Laravel timestamp |

### 6.2 Required support key

```text
unique(institution_id, id)
```

Use an explicit stable name, for example:

```text
topics_institution_id_id_unique
```

### 6.3 Required checks

Use explicit named PostgreSQL checks.

Required semantics:

```text
btrim(title) <> ''
btrim(subject) <> ''
btrim(student_instructions) <> ''
status in ('draft', 'active', 'closed', 'archived')
```

Required structural lifecycle consistency:

```text
draft:
  activated_at is null
  closed_at is null
  archived_at is null

active:
  activated_at is not null
  closed_at is null
  archived_at is null

closed:
  activated_at is not null
  closed_at is not null
  archived_at is null

archived:
  archived_at is not null
  AND either:
    activated_at is null and closed_at is null
  OR
    activated_at is not null and closed_at is not null
```

This intentionally allows:

```text
draft → archived
active → closed → archived
```

and structurally rejects an archived row representing direct:

```text
active → archived
```

Required timestamp ordering when those timestamps exist:

```text
activated_at >= created_at
closed_at >= activated_at
archived_at >= created_at
archived_at >= closed_at when closed_at is not null
```

Do not attempt to enforce actor membership/current Group state in PostgreSQL.

### 6.4 Required foreign keys

- `institution_id -> institutions.id`;
- `(institution_id, group_id) -> groups(institution_id, id)`;
- `(institution_id, teacher_id) -> users(institution_id, id)`.

All use `ON DELETE RESTRICT`.

### 6.5 Required indexes

```text
(institution_id, group_id, status)
(institution_id, teacher_id, status)
(institution_id, status, created_at)
(institution_id, lower(title))
```

Use explicit stable index names.

---

## 7. `files` Persistence Contract

`files` stores private file metadata only. File bytes remain outside PostgreSQL.

### 7.1 Columns

| Column | Type | Null | Contract |
|---|---|---:|---|
| `id` | uuid | no | Primary key |
| `institution_id` | uuid | no | Tenant owner |
| `uploaded_by_user_id` | uuid | no | Same-Institution uploader |
| `category` | varchar(32) | no | `learning_material|student_submission` |
| `original_name` | varchar(500) | no | Non-empty after `btrim` |
| `storage_disk` | varchar(100) | no | Non-empty after `btrim` |
| `storage_key` | text | no | Server-generated later; non-empty after `btrim` |
| `mime_type` | varchar(160) | no | Non-empty after `btrim` |
| `extension` | varchar(20) | no | `pdf|docx|ppt|pptx` |
| `size_bytes` | bigint | no | Positive actual uploaded size |
| `checksum_sha256` | char(64) | yes | Optional integrity metadata |
| `removed_at` | timestamptz | yes | Logical removal timestamp |
| `created_at` | timestamptz | no | Laravel timestamp |
| `updated_at` | timestamptz | no | Laravel timestamp |

### 7.2 Required support key

```text
unique(institution_id, id)
```

### 7.3 Required checks

Category:

```text
category in ('learning_material', 'student_submission')
```

Extension:

```text
extension in ('pdf', 'docx', 'ppt', 'pptx')
```

Text fields:

```text
btrim(original_name) <> ''
btrim(storage_disk) <> ''
btrim(storage_key) <> ''
btrim(mime_type) <> ''
```

Size:

```text
size_bytes > 0
```

Platform hard maxima:

```text
(category = 'learning_material' and size_bytes <= 26214400)
OR
(category = 'student_submission' and size_bytes <= 15728640)
```

Removal ordering:

```text
removed_at is null OR removed_at >= created_at
```

If `checksum_sha256` is non-null, require exactly 64 lowercase/uppercase
hexadecimal characters. Do not require the checksum to be present.

### 7.4 Required uniqueness

```text
unique(storage_disk, storage_key)
```

### 7.5 Required foreign keys

- `institution_id -> institutions.id`;
- `(institution_id, uploaded_by_user_id) -> users(institution_id, id)`.

All use `ON DELETE RESTRICT`.

### 7.6 Required indexes

```text
(institution_id, category, created_at)
(uploaded_by_user_id)
```

### 7.7 Deliberately application-layer later

This task must not implement:

- MIME ↔ extension agreement;
- real MIME detection;
- Institution lower upload limit;
- file-byte existence;
- storage operation consistency.

Those belong to `S05-BE-003`.

---

## 8. `learning_materials` Persistence Contract

### 8.1 Columns

| Column | Type | Null | Contract |
|---|---|---:|---|
| `id` | uuid | no | Primary key |
| `institution_id` | uuid | no | Tenant owner |
| `topic_id` | uuid | no | Same-Institution Topic |
| `file_id` | uuid | no | Same-Institution File |
| `teacher_id` | uuid | no | Same-Institution owning/uploading User |
| `title` | varchar(255) | yes | Optional non-empty label when present |
| `position` | integer | no | Default `0`, non-negative |
| `removed_at` | timestamptz | yes | Logical removal timestamp |
| `created_at` | timestamptz | no | Laravel timestamp |
| `updated_at` | timestamptz | no | Laravel timestamp |

### 8.2 Required support key

```text
unique(institution_id, id)
```

### 8.3 Required checks

```text
title is null OR btrim(title) <> ''
position >= 0
removed_at is null OR removed_at >= created_at
```

### 8.4 Required uniqueness

A File belongs to at most one Learning Material:

```text
unique(file_id)
```

### 8.5 Required foreign keys

- `institution_id -> institutions.id`;
- `(institution_id, topic_id) -> topics(institution_id, id)`;
- `(institution_id, file_id) -> files(institution_id, id)`;
- `(institution_id, teacher_id) -> users(institution_id, id)`.

All use `ON DELETE RESTRICT`.

### 8.6 Required index

```text
(institution_id, topic_id, removed_at)
```

Replacement semantics are not implemented here. This table shape only enables a
later authorized replacement operation to preserve `learning_materials.id`.

---

## 9. Enum Contract

Add string-backed enums following the existing project enum style and include a
`values(): array` helper when consistent with current enums.

### 9.1 `TopicStatus`

Exactly:

```text
Draft = 'draft'
Active = 'active'
Closed = 'closed'
Archived = 'archived'
```

### 9.2 `FileCategory`

Exactly:

```text
LearningMaterial = 'learning_material'
StudentSubmission = 'student_submission'
```

### 9.3 `FileExtension`

Exactly:

```text
Pdf = 'pdf'
Docx = 'docx'
Ppt = 'ppt'
Pptx = 'pptx'
```

Do not introduce enums for MIME types or storage disks.

---

## 10. Eloquent Model Contract

Add:

```text
App\Models\Topic
App\Models\File
App\Models\LearningMaterial
```

Each new model must:

- use the existing UUID model convention;
- use the existing factory convention;
- declare explicit writable attributes;
- cast stable machine values to the approved enums;
- cast lifecycle timestamps to datetime;
- contain relationships/query representation only;
- contain no authorization, HTTP, storage operations, lifecycle actions, or
  hidden workflow decisions.

### 10.1 `Topic`

Required casts:

- `status -> TopicStatus`;
- `lesson_at`;
- `activated_at`;
- `closed_at`;
- `archived_at`.

Required relationships:

- `institution`;
- `group`;
- `teacher`;
- `learningMaterials`.

### 10.2 `File`

Required casts:

- `category -> FileCategory`;
- `extension -> FileExtension`;
- `size_bytes -> integer`;
- `removed_at`.

Required relationships:

- `institution`;
- `uploader` through `uploaded_by_user_id`;
- `learningMaterial` as the one material allowed by `unique(file_id)`.

Do not expose storage behavior through model methods.

### 10.3 `LearningMaterial`

Required casts:

- `position -> integer`;
- `removed_at`.

Required relationships:

- `institution`;
- `topic`;
- `file`;
- `teacher`.

### 10.4 Required inverse relationships on existing models

`Institution`:

```text
topics
files
learningMaterials
```

`Group`:

```text
topics
```

`User`:

```text
teacherTopics
uploadedFiles
learningMaterials
```

Do not add speculative convenience relationships or `BelongsToMany` shortcuts.

---

## 11. Factory Contract

Add:

```text
TopicFactory
FileFactory
LearningMaterialFactory
```

Factories must create structurally valid same-Institution graphs by default.

### 11.1 `TopicFactory`

Default:

```text
status = draft
activated_at = null
closed_at = null
archived_at = null
same-Institution Group
same-Institution Teacher user
non-empty title/subject/student_instructions
```

Required states:

```text
active()
closed()
archivedFromDraft()
archivedFromClosed()
```

Each state must produce timestamps consistent with the database checks.

### 11.2 `FileFactory`

Default:

```text
category = learning_material
extension = one allowed learning-material extension
same-Institution uploader
size_bytes > 0 and <= 25 MiB
removed_at = null
unique storage key
```

Required states:

```text
studentSubmission()
removed()
```

`studentSubmission()` must produce size within the 15 MiB platform maximum.

Do not attempt MIME detection in a factory. Use deterministic MIME values that
match the factory’s chosen extension for valid fixtures.

### 11.3 `LearningMaterialFactory`

Default:

```text
same-Institution Topic
same-Institution Teacher
same-Institution learning_material File
position = 0
removed_at = null
```

Required state:

```text
removed()
```

### 11.4 Override safety

Explicit same-Institution overrides supplied by tests must remain intact.
Factories must not silently replace explicitly supplied `institution_id`,
`group_id`, `teacher_id`, `topic_id`, `file_id`, or uploader IDs with unrelated
default models.

---

## 12. Migration Safety and Rollback

- Add forward-only migration(s); do not edit delivered migrations.
- Preserve all Stage 1–4 rows and constraints.
- Use PostgreSQL-compatible SQL.
- Use explicit stable constraint/index names.
- Create support unique keys before composite foreign keys that reference them.
- Rollback must drop `learning_materials` before `files`/`topics`.
- Rollback must not remove Stage 4 `users(institution_id, id)` or
  `groups(institution_id, id)` support constraints if those already existed
  before this task.
- Do not manually mutate a shared database outside migrations/tests.
- No real private file bytes are created by the migration or tests.

---

## 13. Required Focused Tests

Add exactly these focused persistence test files:

```text
backend/tests/Feature/Persistence/TopicLearningMaterialSchemaInspectionTest.php
backend/tests/Feature/Persistence/TopicLearningMaterialPersistenceTest.php
backend/tests/Feature/Persistence/TopicLearningMaterialFactoryModelTest.php
```

### 13.1 Schema inspection

Verify:

- all three tables exist;
- every required column exists;
- UUID, varchar/text, bigint/integer, char, and timestamptz types;
- exact nullability and relevant maximum lengths;
- named checks;
- named restrictive foreign keys;
- composite support unique constraints;
- `unique(storage_disk, storage_key)`;
- `unique(file_id)`;
- required query/expression indexes.

### 13.2 Persistence invariants

Verify valid records persist and PostgreSQL rejects:

#### Topic

- blank title;
- blank subject;
- blank student instructions;
- invalid status;
- lifecycle timestamp/status mismatches;
- invalid lifecycle time ordering;
- cross-Institution Group;
- cross-Institution Teacher.

Verify all valid structural states persist:

```text
draft
active
closed
archived from draft
archived from closed
```

#### File

Verify:

- both allowed categories persist structurally;
- all four allowed extensions persist;
- invalid category rejected;
- invalid extension rejected;
- blank original/storage-disk/storage-key/MIME rejected;
- `size_bytes <= 0` rejected;
- learning material above `26,214,400` bytes rejected;
- Student submission above `15,728,640` bytes rejected;
- exact platform maxima accepted;
- duplicate `(storage_disk, storage_key)` rejected;
- invalid checksum format rejected when checksum is present;
- `removed_at < created_at` rejected;
- cross-Institution uploader rejected.

#### Learning Material

Verify:

- valid row persists;
- negative `position` rejected;
- blank non-null title rejected;
- duplicate `file_id` rejected;
- `removed_at < created_at` rejected;
- cross-Institution Topic rejected;
- cross-Institution File rejected;
- cross-Institution Teacher rejected.

#### Restrictive history

Verify referenced Topic/File/LearningMaterial/Group/User/Institution rows cannot
be destructively deleted while restrictive Stage 5 references exist.

Do not test Teacher/Student HTTP authorization in this task.

### 13.3 Models, relationships, casts, factories

Verify:

- UUID generation;
- enum casts;
- datetime casts;
- all required relationships and inverse relationships;
- valid default same-Institution graphs;
- all required factory states;
- explicit same-Institution overrides are preserved;
- no factory produces an invalid lifecycle or platform-size state.

---

## 14. Proportional Verification

Run from `backend/`.

### 14.1 Formatter

```bash
./vendor/bin/pint --test
```

### 14.2 New focused Stage 5 persistence tests

```bash
php artisan test \
  tests/Feature/Persistence/TopicLearningMaterialSchemaInspectionTest.php \
  tests/Feature/Persistence/TopicLearningMaterialPersistenceTest.php \
  tests/Feature/Persistence/TopicLearningMaterialFactoryModelTest.php
```

### 14.3 Directly affected Stage 4 persistence regression

```bash
php artisan test \
  tests/Feature/Persistence/GroupRelationshipSchemaInspectionTest.php \
  tests/Feature/Persistence/GroupRelationshipPersistenceTest.php \
  tests/Feature/Persistence/GroupRelationshipFactoryModelTest.php
```

Do not run the full backend suite for this implementation task. Full backend
regression belongs to Stage 5 Backend Phase 2 after `S05-BE-001…005`.

### 14.4 Repository checks

From repository root:

```bash
git diff --check
git status --short
```

Then inspect the complete task diff and perform the focused scope/security
self-review required by root/backend `AGENTS.md`.

---

## 15. Acceptance Criteria

`S05-BE-001` is implementation-complete only when all are true:

1. `topics`, `files`, and `learning_materials` exist with the exact approved
   structural columns/types/nullability.
2. Topic structural lifecycle checks accept only the approved persisted states.
3. Cross-Institution Group/Teacher/File/Topic/Uploader references are rejected
   structurally by PostgreSQL.
4. `files` supports exactly the two approved structural categories and four
   approved extensions.
5. PostgreSQL enforces positive size and the 25 MiB / 15 MiB platform maxima.
6. `(storage_disk, storage_key)` is unique.
7. one File cannot back multiple Learning Materials.
8. required query/support indexes exist.
9. all new foreign keys are restrictive.
10. `Topic`, `File`, and `LearningMaterial` models expose only the required
    casts/relationships and no workflow/storage behavior.
11. factories create deterministic valid same-Institution graphs and valid
    lifecycle states.
12. the three new focused test files pass.
13. the directly affected Stage 4 persistence regression tests pass.
14. Pint passes.
15. `git diff --check` passes.
16. no API, storage-transfer, authorization use case, frontend code, dependency,
    seed data, later-Stage behavior, docs, or unrelated refactor is introduced.

---

## 16. Focused Self-Review Checklist

Before reporting completion, Codex must confirm:

- migration changes are forward-only and rollback-safe;
- no existing Stage 1–4 migration was edited;
- every institution-owned relationship has the required tenant-safe structural
  reference;
- every foreign key uses `ON DELETE RESTRICT`;
- lifecycle checks do not accidentally permit `active → archived` structural
  state;
- platform hard maxima use exact byte values:
  - learning material `26214400`;
  - Student submission `15728640`;
- application-only rules were not incorrectly pushed into database triggers;
- no file bytes/storage actions were implemented;
- Models contain no authorization/lifecycle workflow logic;
- factories do not silently replace explicit fixture relationships;
- no unrelated file changed.

---

## 17. Delivery and Completion Report

Routine Git/GitHub delivery is owned by the Project Owner under Workflow v3.

Codex must not create a PR or merge unless explicitly instructed outside this
contract.

Codex’s final report must include:

```text
S05-BE-001 IMPLEMENTATION COMPLETE
```

and summarize:

- changed production files;
- changed test files;
- migration/schema additions;
- exact verification commands and results;
- `git diff --check` result;
- focused diff/self-review result;
- any implementation-contract conflict or remaining blocker.

If any required verification fails, report the task as not complete and include
the exact failing command/test. Do not broaden verification into a full backend
suite as a substitute for fixing a focused failure.

---

# Final Implementation Rule

> Implement only the Stage 5 Topic / shared File metadata / Learning Material
> persistence foundation defined here. PostgreSQL owns structural tenant and
> lifecycle/file invariants; later Stage 5 tasks own Teacher/Student
> authorization, real file storage, MIME validation, lower Institution upload
> limits, HTTP behavior, and lifecycle use cases.
