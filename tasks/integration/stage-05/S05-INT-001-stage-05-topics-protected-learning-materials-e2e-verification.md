# S05-INT-001 — Stage 5 Topics and Protected Learning Materials Real-Stack E2E Verification

## 1. Metadata and Execution Gate

| Field | Value |
|---|---|
| Task ID | `S05-INT-001` |
| Stage | `Stage 5 — Topics and Learning Materials` |
| Area | `Integration / real-stack E2E` |
| Status | `Approved` |
| Depends on | Stage 5 Backend Phase 2 `PASS`; Stage 5 Frontend Phase 2 `PASS` |
| Planning / readiness baseline | `origin/main = df6d920311305271ab091f0fbd02abd7e05d9cad` |
| Implementation baseline | Exact current `origin/main` SHA supplied by ChatGPT in the Codex execution handoff after this Integration-readiness bookkeeping is merged; no task-file edit is required solely to stamp that SHA |
| Verification model | `Project Workflow v3 — Lean Verification` |
| Codex ownership | Integration assets + focused implementation verification only |
| Real-stack execution | `Project Owner` |
| Native Windows/Android smoke | `Project Owner` |
| Routine Git/GitHub delivery | `Project Owner` |
| Blocks | Stage 5 Closure Review |

This file is the complete task-specific implementation contract. Do not create a
second `CODEX-PROMPT` file.

Before Codex execution, ChatGPT must re-check current `origin/main` after this
Integration-readiness bookkeeping is merged and supply that exact SHA in the
execution handoff. Do not edit this task file solely to stamp the implementation
baseline.

Codex may start only when safe Git preflight proves:

```text
current branch = main
local main == origin/main == supplied implementation baseline
ahead/behind = 0/0
worktree = clean
origin = expected Shoxrux2017/testlabuz repository
```

Codex then creates one focused implementation branch from that exact baseline.

If `origin/main` advances after the implementation baseline is supplied, Codex
must stop and report the new SHA. ChatGPT decides whether the later change is
bookkeeping-only and evidence-safe or whether this contract requires
revalidation.

This task verifies delivered production behavior. It must not repair production
code. If a diagnostic or Project Owner real-stack run exposes a production
defect:

```text
INTEGRATION FINDING
```

Stop the affected scenario, preserve the evidence, and report the exact
production boundary. ChatGPT designs any separate focused production-fix
contract.

Fresh Backend/Frontend Phase 2 evidence remains valid. Do **not** rerun full
backend/frontend suites, full-project analyze/format, standalone Windows/Android
builds, Phase 2, or broad previous-Stage E2E merely because Integration starts.

---

## 2. Goal, Scope, and Non-Goals

### Goal

Prove the complete protected Stage 5 vertical through the real stack:

```text
Flutter Windows
→ production Riverpod/router/repositories/DTOs
→ production configured Dio
→ Laravel/Sanctum
→ PostgreSQL testlabuz_testing
→ Laravel private file storage
```

and verify the required Android/native operating-system boundaries through
Project Owner smoke.

### Included

- real Teacher login and current assigned-Group projection;
- Topic create/read/editability/lifecycle behavior;
- PDF, DOCX, PPT, and PPTX material upload through production multipart Dio;
- unsupported-format, platform-limit, and lower Institution-limit rejection;
- material title update, replace, remove, protected download, Save As, and Open;
- current Student Topic/material access;
- closed/archived historical Student access while current membership remains;
- ended-membership, same-Institution unrelated, cross-Institution, wrong-role,
  unauthenticated, and direct-ID denial;
- archived-Group historical behavior;
- independent PostgreSQL and private-filesystem oracle;
- deterministic rerun-safe fixtures;
- backend stop/start with PostgreSQL and private-file volume preserved;
- fresh Flutter process after backend restart;
- automated Windows E2E;
- Project Owner Windows native picker/save/open smoke;
- Project Owner Android protected download/save/open smoke.

### Non-Goals

- Stage 6+ Homework, Blitz, Questions, Attempts, submissions, checking, scores,
  results, release, or reporting behavior;
- production changes under `backend/app/**` or `frontend/lib/**`;
- API, schema, migration, route, authorization, lifecycle, dependency, package,
  platform, or Docker-repository configuration changes;
- a new E2E framework or reusable cross-Stage abstraction;
- refactoring Stage 2–4 integration assets;
- public file URLs, signed URLs, file conversion, preview, OCR, antivirus, cloud
  storage, or offline behavior;
- full backend/frontend/checkpoint reruns.

No production test-only route, middleware bypass, authentication backdoor,
session injection, or database-write hook is allowed.

---

## 3. Codex Context and Read Boundary

Codex may read only:

1. this approved task;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. `frontend/AGENTS.md`;
5. current source, tests, migrations, configuration, and infrastructure directly
   needed to implement these integration assets;
6. the following existing **source assets only** as read-only implementation
   patterns:

```text
backend/database/seeders/Stage2E2eSeeder.php
backend/database/seeders/Stage3E2eSeeder.php
backend/database/seeders/Stage4E2eSeeder.php

backend/tests/Feature/Seeders/Stage2E2eSeederTest.php
backend/tests/Feature/Seeders/Stage3E2eSeederTest.php
backend/tests/Feature/Seeders/Stage4E2eSeederTest.php

frontend/integration_test/stage2_*
frontend/integration_test/stage3_*
frontend/integration_test/stage4_*
frontend/integration_test/run_stage2_*
frontend/integration_test/run_stage3_*
frontend/integration_test/run_stage4_*
frontend/integration_test/verify_stage2_*
frontend/integration_test/verify_stage3_*
frontend/integration_test/verify_stage4_*
frontend/integration_test/prepare_stage2_*
frontend/integration_test/prepare_stage3_*
frontend/integration_test/prepare_stage4_*
```

Codex must not read product specifications, roadmap files, architecture/database/
API documents, Stage indexes, prior task contracts, Phase 2 reviews, integration
evidence, closure reviews, or files under `tasks/integration/stage-01..04/**` to
rediscover requirements.

Current production boundaries to inspect and reuse include only the directly
relevant parts of:

```text
backend/routes/api.php
backend/app/Actions/Teacher/**
backend/app/Actions/Student/**
backend/app/Actions/Files/DownloadLearningMaterialFile.php
backend/app/Support/Teacher/**
backend/app/Support/Files/**
backend/app/Models/{Topic,LearningMaterial,File,Group,User}.php
backend/app/Http/Requests/Teacher/**
backend/app/Http/Resources/Teacher/**
backend/app/Http/Resources/Student/**
backend/tests/Feature/Teacher/**
backend/tests/Feature/Student/**
backend/tests/Feature/Files/**

frontend/lib/app/**
frontend/lib/core/files/**
frontend/lib/core/network/**
frontend/lib/features/auth/**
frontend/lib/features/teacher/**
frontend/lib/features/student/**
frontend/test/core/files/**
frontend/test/features/teacher/**
frontend/test/features/student/**
```

Existing native-only seams are authoritative:

```text
teacherMaterialFilePickerProvider
localFileActionsProvider
appConfigProvider
```

Production upload/replace must still use real multipart Dio. Protected Save/Open
must still download through the production protected-transfer/Dio path before
the native-only adapter receives bytes.

---

## 4. Dedicated Real-Stack Runtime

### 4.1 Project Owner Provisioning

Project Owner provisions the runtime outside repository changes:

```text
backend container:
testlabuz-stage5-e2e-app

container port:
8000/tcp

API:
http://127.0.0.1:<ApiPort>/api/v1

Laravel:
APP_ENV=testing
APP_DEBUG=false
DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=testlabuz_testing
PRIVATE_FILES_DISK=local

PostgreSQL container:
testlabuz-postgres-1

PostgreSQL image:
postgres:18.4

Docker network:
testlabuz_default

backend source mount:
current repository backend directory
→ /var/www/html
read/write bind mount

private named volume:
testlabuz-stage5-e2e-private-files
→ /var/www/html/storage/app/private
read/write
```

The Stage 5 app container must be restartable:

```text
AutoRemove = false
WorkingDir = /var/www/html
```

The named private volume must be distinct from normal development/public storage
and must survive stop/start of only the Stage 5 app container.

Repository `docker/**` files must not change. If the exact runtime cannot be
provisioned safely from the existing local Docker image/network/database without
repository changes, report:

```text
BLOCKED
Environment detail: ENVIRONMENT BLOCKED
```

### 4.2 Runtime Guard Assets

Create:

```text
frontend/integration_test/stage5_runtime_guard.ps1
frontend/integration_test/verify_stage5_runtime_guard.ps1
```

The guard runs before every seed, login, mutation, oracle, or protected request.

It must fail closed unless it proves all of the following.

#### Container and source identity

- exact container name `testlabuz-stage5-e2e-app`;
- exactly one inspected container;
- container is running;
- `AutoRemove = false`;
- working directory is exactly `/var/www/html`;
- exactly one read/write bind mount owns `/var/www/html`;
- the bind source resolves to the current repository `backend` directory;
- exactly one read/write named volume
  `testlabuz-stage5-e2e-private-files` owns
  `/var/www/html/storage/app/private`;
- no second mount aliases the private root;
- the public root is not mounted to the private volume.

#### Network and database identity

- `8000/tcp` is configured and actively published exactly once to
  `127.0.0.1:<ApiPort>`;
- API target is exactly
  `http://127.0.0.1:<ApiPort>/api/v1`;
- no `localhost`, IPv6, wildcard address, userinfo, query, fragment, trailing
  slash, alternate scheme, implicit port, or alternate API version;
- backend and PostgreSQL are both attached to `testlabuz_default`;
- exact PostgreSQL container is `testlabuz-postgres-1`;
- PostgreSQL is running;
- PostgreSQL image is exactly `postgres:18.4`;
- `DB_HOST=postgres`;
- Laravel connection driver and PDO driver are both `pgsql`;
- `current_database() = testlabuz_testing`;
- no current Laravel migration is pending.

#### Laravel and file-storage identity

A Laravel runtime probe must prove:

```text
app()->environment() = testing
config('app.debug') = false
config('database.default') = pgsql
config('filesystems.private_files_disk') = local
config('filesystems.disks.local.driver') = local
config('filesystems.disks.local.root') =
  /var/www/html/storage/app/private
config('filesystems.disks.public.root') =
  /var/www/html/storage/app/public
```

The private and public roots must be different. The selected private disk must
not have public visibility.

The live PHP transport must accept the Stage 5 boundary:

```text
upload_max_filesize >= 26,214,401 bytes
post_max_size > 26,214,401 bytes
```

The current repository runtime normally resolves to `32M` / `40M`; those values
are transport headroom and do not change the 25 MiB application limit.

The guard must perform one unpredictable private-root probe:

```text
write deterministic bytes
read them back
verify SHA-256
delete the probe
verify absence
```

It must leave no probe artifact.

#### HTTP boundary

Unauthenticated:

```text
GET /api/v1/auth/me
Accept: application/json
```

must return exactly:

```text
401
code = authentication_required
errors = {}
```

`request_id` may be present.

### 4.3 Runtime Guard Negative Matrix

`verify_stage5_runtime_guard.ps1` must test pure guard functions plus the actual
approved runtime.

At minimum reject:

- malformed, non-loopback, HTTPS, localhost, IPv6, wildcard, credentialed,
  query/fragment, wrong-path, wrong-port, implicit-port, and trailing-slash API
  targets;
- wrong/missing/stopped/ambiguous backend container;
- `AutoRemove=true`;
- wrong working directory;
- missing/read-only/wrong backend source bind;
- wrong/missing/read-only/duplicate private volume mount;
- private/public root aliasing;
- wrong environment or debug mode;
- wrong database name, Laravel driver, PDO driver, host, or pending migration;
- wrong/missing/stopped PostgreSQL container;
- wrong PostgreSQL image or Docker network;
- wrong private disk, driver, root, or public visibility;
- insufficient PHP upload/post headroom;
- unbound, wildcard-bound, wrong-port, duplicate, or inactive port binding;
- failed private write/read/hash/delete probe;
- wrong `/auth/me` status/envelope.

Never print Docker environment values wholesale. Never print DB passwords,
application secrets, bearer tokens, private storage keys, or raw inspection JSON.

---

## 5. Deterministic Fixtures and Seeder

Create:

```text
backend/database/seeders/Stage5E2eSeeder.php
backend/tests/Feature/Seeders/Stage5E2eSeederTest.php
```

### 5.1 Reserved Namespace

```text
UUID prefix: 05000000-...
login prefix: e2e_s05_
display/title prefix: E2E S05
password environment: STAGE5_E2E_PASSWORD
```

Every fixed row uses an explicit manifest. Prefix matching alone is never
ownership proof.

All fixture Institutions and users are active. All login actors use:

```text
must_change_password = false
```

All Institution timezones are:

```text
Asia/Tashkent
```

Target and Foreign Institution material limits are 25 MiB. Low-limit Institution
material limit is 1 MiB. Every seeded Institution setting is exact:

```text
timezone = Asia/Tashkent
learning_material_max_mb = 25 or 1 as assigned above
student_submission_max_mb = 15
acceptable_score_difference = null
blitz_timer_start_mode = null
student_result_release_mode = null
parent_result_release_mode = null
updated_by_user_id = null
```

No later educational-policy default is invented by this Stage 5 fixture.

### 5.2 Exact Fixture Actors

| Institution | Login | Role | Display name |
|---|---|---|---|
| Target | `e2e_s05_target_admin` | Institution Admin | `E2E S05 Target Admin` |
| Target | `e2e_s05_target_teacher` | Teacher | `E2E S05 Target Teacher` |
| Target | `e2e_s05_target_student` | Student | `E2E S05 Target Student` |
| Target | `e2e_s05_ended_student` | Student | `E2E S05 Ended Student` |
| Target | `e2e_s05_unrelated_teacher` | Teacher | `E2E S05 Unrelated Teacher` |
| Target | `e2e_s05_unrelated_student` | Student | `E2E S05 Unrelated Student` |
| Low-limit | `e2e_s05_low_limit_admin` | Institution Admin | `E2E S05 Low Limit Admin` |
| Low-limit | `e2e_s05_low_limit_teacher` | Teacher | `E2E S05 Low Limit Teacher` |
| Foreign | `e2e_s05_foreign_admin` | Institution Admin | `E2E S05 Foreign Admin` |
| Foreign | `e2e_s05_foreign_teacher` | Teacher | `E2E S05 Foreign Teacher` |
| Foreign | `e2e_s05_foreign_student` | Student | `E2E S05 Foreign Student` |

The respective Institution Admin is the creator/assigner for each seeded Group
and membership.

### 5.3 Exact Fixture Groups and Memberships

**Target Institution**

```text
Group A:
E2E S05 Group A
status = active

Group B:
E2E S05 Group B
status = active

Group C:
E2E S05 Archived Group C
status = archived
```

Memberships:

- target Teacher has one current membership in Group A;
- target Teacher has one current membership in Group C;
- target Student has one current membership in Group A;
- target Student has one current membership in Group C;
- ended Student has one ended historical membership in Group A and no current
  membership there;
- ended Student has one ended historical membership in Group C and no current
  membership there;
- unrelated Teacher has one current membership in Group B;
- unrelated Student has one current membership in Group B;
- target Teacher has no current or historical membership in Group B;
- target Student has no current or historical membership in Group B.

**Low-limit Institution**

```text
E2E S05 Low Limit Group
status = active
```

Low-limit Teacher has one current membership there.

**Foreign Institution**

```text
E2E S05 Foreign Group
status = active
```

Foreign Teacher and Foreign Student each have one current membership there.

### 5.4 Exact Seeded Topics and Files

All seeded materials use small deterministic valid PDF bytes, fixed manifest
UUIDs, fixed server-owned storage keys, canonical PDF metadata, and persisted
lowercase SHA-256.

| Topic | Institution / owner / Group | Initial status | Current seeded material |
|---|---|---|---|
| `E2E S05 Seeded Active Topic` | Target / target Teacher / Group A | `active` | `e2e_s05_seeded_target.pdf` |
| `E2E S05 Seeded Draft Topic` | Target / target Teacher / Group A | `draft` | none required |
| `E2E S05 Unrelated Topic` | Target / unrelated Teacher / Group B | `active` | `e2e_s05_seeded_unrelated.pdf` |
| `E2E S05 Archived Group Topic` | Target / target Teacher / Group C | `active` | `e2e_s05_seeded_archived.pdf` |
| `E2E S05 Low Limit Topic` | Low-limit / low-limit Teacher / low-limit Group | `draft` | none |
| `E2E S05 Foreign Topic` | Foreign / foreign Teacher / foreign Group | `active` | `e2e_s05_seeded_foreign.pdf` |

Every Topic has valid required metadata and `lesson_at = null`.

Deterministic lifecycle consistency is mandatory:

- every seeded `active` Topic has non-null `activated_at`, null `closed_at`, and
  null `archived_at`;
- every seeded `draft` Topic has all lifecycle timestamps null;
- Group C has non-null `archived_at` later than its creation time;
- every current membership has non-null `started_at` and null `ended_at`;
- every ended membership has `ended_at > started_at`;
- the Group C Topic/material timestamps prove they predate Group archival.

The Group C Topic represents content created before the Group was archived.

### 5.5 Automated Transient Password

`run_stage5_windows_e2e.ps1` owns the automated password lifecycle.

At the start of one runner invocation it generates exactly one transient
password in memory:

```powershell
$sharedPassword = 'S05-Aa9-' + [guid]::NewGuid().ToString('N')
```

The same password is used for both Windows test processes and every Stage 5
seeder invocation in that one runner.

The runner must:

- pass it to each seeder invocation only through
  `docker exec -e "STAGE5_E2E_PASSWORD=$sharedPassword"`;
- pass it to each Flutter process only through
  `--dart-define=STAGE5_E2E_PASSWORD=$sharedPassword`;
- never print it or write it into an oracle, fixture manifest, sink record,
  evidence file, command summary, or repository file;
- clear `$sharedPassword` in `finally`.

Flutter reads it only through:

```dart
const String.fromEnvironment('STAGE5_E2E_PASSWORD')
```

and uses it only for normal UI login or the separately authorized direct-probe
login endpoint.

Manual smoke never reuses this password. It prompts independently with
`Read-Host -AsSecureString`.

### 5.6 Dynamic UI-Flow Ownership

The automated UI creates one production-generated Topic with these exact values:

```text
title = E2E S05 UI Topic
subject = E2E S05 Subject
description = E2E S05 integration topic
student_instructions = E2E S05 Student instructions
lesson_at = null
institution_id = Target Institution
teacher_id = target Teacher
group_id = Group A
status in draft|active|closed|archived
```

The following exact automated upload original names are reserved:

```text
e2e_s05_material.pdf
e2e_s05_material.docx
e2e_s05_material.ppt
e2e_s05_material.pptx
e2e_s05_replacement.pdf
e2e_s05_unsupported.txt
e2e_s05_low_limit_over.pdf
e2e_s05_platform_over.pdf
```

The manual Windows picker fixture uses exactly:

```text
e2e_s05_manual_smoke.pdf
```

A production-generated Topic/File/LearningMaterial UUID is E2E-owned only when
the complete connected tuple proves ownership. A title, prefix, filename, or
directory prefix alone is insufficient.

For the automated dynamic Topic:

- zero or one exact Topic candidate is allowed;
- more than one exact candidate is an ownership collision;
- any partially matching candidate with a mismatched Institution, Teacher,
  Group, metadata, or unsupported status is a collision.

A connected LearningMaterial is owned only when:

- it belongs to the proven dynamic Topic;
- its `institution_id` is Target Institution;
- its `teacher_id` is target Teacher;
- its current/removed state is compatible with an interrupted Stage 5 run.

Its connected File is owned only when:

- its `institution_id` is Target Institution;
- `uploaded_by_user_id` is target Teacher;
- category is Learning Material;
- original name is one of the exact automated names above;
- its storage key belongs to exactly:

```text
learning-materials/<target-institution-id>/<dynamic-topic-id>/
```

A manual-smoke extra material attached to `E2E S05 Seeded Active Topic` is owned
only when the full Institution/Teacher/Topic relationship matches and its exact
original name is `e2e_s05_manual_smoke.pdf`.

Before any mutation, validate every fixed and dynamic candidate completely. Any
partial mismatch aborts with a manifest-collision error.

### 5.7 Exact Orphan-Blob Rule

After the dynamic Topic ownership tuple is proven, safe cleanup may inspect only
its exact Topic namespace:

```text
learning-materials/<target-institution-id>/<dynamic-topic-id>/
```

A namespace file is cleanup-owned only when its basename is a canonical
server-generated UUID followed by one lowercase allowed extension:

```text
pdf|docx|ppt|pptx
```

This permits cleanup of an orphan left between storage and DB completion or an
old replacement blob left after DB commit.

An unexpected nested directory, filename shape, extension, symlink-like entry,
or path outside that exact namespace is a collision and must stop cleanup.

The same exact rule applies to a manual-smoke file under the fixed target Topic
namespace, additionally requiring the persisted full ownership tuple when a DB
row exists.

Never scan or delete from a broad `learning-materials/`, Institution-wide, or
prefix-only scope.

### 5.8 Seeder Reset and Creation Algorithm

The seeder must use this order:

1. verify `APP_ENV=testing`, Laravel/PDO `pgsql`, exact
   `testlabuz_testing`, exact configured private disk/root, and required
   transient password;
2. inspect and validate the complete fixed manifest, dynamic Topic lineage,
   manual-smoke extras, owned token rows, and candidate private blobs;
3. perform **no mutation** if any ownership/collision check fails;
4. while the proven DB ownership graph still exists, delete only the validated
   owned/orphan private blobs and verify their absence;
5. if any required blob deletion fails, stop before deleting DB ownership rows;
6. in one DB transaction, delete only owned `personal_access_tokens` and owned
   Stage 5 rows in FK-safe order;
7. if DB reset fails after blob cleanup, stop; the still-identifiable owned DB
   graph is recoverable by the next guarded run and no unrelated row may be
   touched;
8. write deterministic seeded blobs while tracking compensation ownership;
9. in one DB transaction, recreate the fixed Stage 5 manifest;
10. if DB creation fails, remove only newly written seeded blobs;
11. verify every seeded current blob exists and matches persisted SHA-256.

Blob-first reset is intentional: a dynamic production-generated Topic UUID must
remain provably connected to its ownership tuple until all of its exact-namespace
blobs have been removed. Do not commit DB deletion first and leave an
unattributable dynamic orphan on later failure.

The seeder must never:

- truncate;
- reset global sequences;
- disable constraints;
- delete unrelated users, tokens, rows, or files;
- use a broad prefix as ownership;
- write to `storage/app/public`;
- print passwords, tokens, storage keys, or private paths.

On every successful seed:

- owned users have the supplied password hash;
- owned users have `must_change_password=false`;
- owned users have `last_login_at=null`;
- unrelated users/tokens/rows/blobs remain unchanged.

### 5.9 Focused Seeder Test

`Stage5E2eSeederTest` must use an isolated test filesystem root/disk. It must
never write into ordinary repository development private storage.

Required cases:

- non-testing environment refusal;
- non-PostgreSQL Laravel/PDO refusal;
- wrong database refusal;
- missing/blank password refusal;
- wrong private disk/root refusal;
- fixed manifest collision refusal before mutation;
- dynamic Topic partial-collision refusal before mutation;
- dynamic material/file partial-collision refusal;
- unexpected exact-namespace file-shape refusal;
- safe cleanup of an interrupted dynamic UI Topic lineage;
- safe cleanup of an exact orphan replacement/upload blob;
- safe cleanup of the exact manual-smoke extra material;
- owned `personal_access_tokens` removed;
- unrelated users and unrelated tokens preserved;
- unrelated DB rows and unrelated private blobs preserved;
- DB reset failure after validated blob cleanup remains recoverable on the next
  guarded run without claiming unrelated rows;
- DB creation failure compensates newly written seeded blobs;
- two consecutive successful runs produce the same logical fixed baseline;
- every seeded current DB checksum equals the actual seeded blob checksum.

The real runner invokes the guarded seeder twice before product mutations.

---

## 6. Temporary File Fixtures

Do not commit binary fixtures.

Create an optional focused generator only when needed:

```text
frontend/integration_test/stage5_test_files.ps1
```

The runner creates one unpredictable system-temp root and generates:

| Key | Exact original name | Exact requirement |
|---|---|---|
| `pdf` | `e2e_s05_material.pdf` | small valid PDF |
| `docx` | `e2e_s05_material.docx` | small valid DOCX |
| `ppt` | `e2e_s05_material.ppt` | small valid legacy PowerPoint OLE file |
| `pptx` | `e2e_s05_material.pptx` | small valid PPTX |
| `replacement_pdf` | `e2e_s05_replacement.pdf` | different valid PDF bytes |
| `unsupported` | `e2e_s05_unsupported.txt` | unsupported text |
| `low_limit_over` | `e2e_s05_low_limit_over.pdf` | valid PDF, exactly `1,048,577` bytes |
| `platform_over` | `e2e_s05_platform_over.pdf` | valid PDF, exactly `26,214,401` bytes |
| `manual_pdf` | `e2e_s05_manual_smoke.pdf` | small valid PDF for native picker smoke |

DOCX/PPTX/PPT must satisfy the current production content inspector, not only
the filename extension. Reuse current backend test fixture algorithms as an
implementation pattern; do not import backend test code into Flutter runtime.

Create one UTF-8 JSON fixture manifest in system temp:

```json
{
  "version": 1,
  "files": {
    "pdf": {
      "path": "<absolute temp path>",
      "original_name": "e2e_s05_material.pdf",
      "extension": "pdf",
      "mime_type": "application/pdf",
      "size_bytes": 123,
      "sha256": "<lowercase 64 hex>"
    }
  }
}
```

Every listed file requires:

- absolute path inside the one generated temp root;
- exact reserved original name;
- expected extension/MIME;
- exact byte size;
- lowercase SHA-256.

The manifest contains no password, token, DB credential, storage key, or
repository path.

Delete the manifest and every generated fixture in runner/manual-smoke
`finally`. Cleanup failure is a runner failure.

---

## 7. Independent Oracle and Test Inputs

Create:

```text
frontend/integration_test/stage5_oracle.ps1
```

No expected result may be manufactured from the same Stage 5 product endpoint
being tested.

### 7.1 Oracle Source

Use read-only PostgreSQL queries and direct private-volume inspection through the
dedicated backend container. Product APIs are not oracle authority.

The oracle may use a narrowly scoped Laravel tinker probe or PostgreSQL command,
but it must not write product state.

### 7.2 Sanitized Host Oracle

After the second seed and before product mutation, create one unpredictable
system-temp JSON oracle:

```json
{
  "version": 1,
  "logins": {
    "target_teacher": "e2e_s05_target_teacher"
  },
  "ids": {
    "target_institution": "<uuid>",
    "group_a": "<uuid>",
    "group_b": "<uuid>",
    "group_c": "<uuid>",
    "seeded_target_topic": "<uuid>",
    "seeded_draft_topic": "<uuid>",
    "unrelated_topic": "<uuid>",
    "archived_group_topic": "<uuid>",
    "low_limit_topic": "<uuid>",
    "foreign_topic": "<uuid>",
    "unrelated_file": "<uuid>",
    "archived_group_file": "<uuid>",
    "foreign_file": "<uuid>"
  },
  "seeded_sha256": {
    "target_file": "<lowercase 64 hex>"
  }
}
```

The actual oracle must include every fixture actor/resource ID needed by the
scenario and exact synthetic login names. It must not include:

- password or password hash;
- bearer token or token hash;
- DB password;
- private storage disk/key/path;
- unnecessary synthetic contact fields.

The Dart test strictly validates version, exact required keys, UUIDs, login
prefixes, and SHA-256 shapes.

After the mutation process and independent mutation postconditions pass,
`stage5_oracle.ps1` must atomically extend the same sanitized oracle with a
`dynamic` block derived from PostgreSQL/private storage, not from the product
API:

```json
{
  "dynamic": {
    "topic_id": "<uuid>",
    "status": "archived",
    "replacement_material_id": "<uuid>",
    "replacement_file_id": "<uuid>",
    "replacement_sha256": "<lowercase 64 hex>",
    "removed_material_id": "<uuid>",
    "removed_file_id": "<uuid>",
    "remaining_material_ids": ["<uuid>"]
  }
}
```

The update must use write-to-new-file plus atomic replacement in the same temp
directory. The persistence Flutter process starts only after this update is
validated. The dynamic block must not contain storage disk/key/path or tokens.

### 7.3 Runner-to-Dart Contract

Both Windows processes receive exactly:

```text
API_BASE_URL
STAGE5_E2E_PASSWORD
STAGE5_E2E_ORACLE_PATH
STAGE5_E2E_FIXTURE_MANIFEST_PATH
STAGE5_E2E_FILE_SINK_ROOT
```

The paths must resolve under system temp and be validated before use.

The integration test names are exactly:

```text
Stage 5 Topics and protected materials use the real Windows stack

Stage 5 Topic and protected material state persists after backend restart
```

The runner invokes each in a separate Flutter process with `--plain-name`.

### 7.4 DB and Storage Postconditions

The oracle must verify:

- UI-created Topic exact ownership, exact metadata, captured route UUID, status,
  and timestamps;
- required metadata remains unchanged through lifecycle;
- material ordering and title update;
- accepted File canonical original name, MIME, extension, byte size, checksum;
- no storage disk/key/path/checksum leaks through public API projections;
- replacement preserves the same `learning_materials.id`;
- replacement preserves the same `files.id`;
- replacement changes current original name/MIME/extension/size/checksum/storage
  key to the replacement blob;
- the same protected File UUID returns replacement bytes;
- old replacement storage key is no longer current and its blob is absent after
  normal successful cleanup;
- removal keeps the same Material/File rows but sets both `removed_at` values
  non-null using the same transition instant;
- removed protected File UUID returns `404 resource_not_found`;
- removed blob is absent;
- rejected uploads create no new Material/File row and no private blob;
- lifecycle timestamps are monotonic and semantically valid;
- every idempotent same-state lifecycle call preserves `updated_at` and all
  lifecycle timestamps;
- public storage contains no owned Stage 5 blob;
- remaining current private blobs exist and match persisted checksum.

### 7.5 Frozen Unrelated State

Capture a canonical sorted snapshot before mutations and compare after mutation
and after restart.

Frozen scope includes:

- Group B, unrelated Teacher/Student memberships, unrelated Topic/material/File
  rows and blob hash;
- Foreign Institution Group/memberships/Topic/material/File rows and blob hash;
- Low-limit Institution setting, Group, membership, Topic, and absence of new
  material/file/blob;
- unrelated non-Stage-5 sentinel rows/blobs created by the focused seeder test or
  already present in the test database when safely representable.

Explicitly exclude only:

- Target Group A dynamic Topic lineage and seeded draft lifecycle target;
- Target Group C lifecycle target;
- all `personal_access_tokens` rows for E2E actors;
- E2E actor `last_login_at` and the corresponding login-driven `updated_at`;
- target rows intentionally changed by the approved scenarios.

Do not exclude arbitrary columns merely to make comparison pass.

### 7.6 Oracle Artifact Cleanup

The host oracle, frozen container snapshot, fixture manifest, and file-sink root
are temporary only. Remove them in `finally`.

No sanitized evidence committed later may contain temp paths or private storage
keys.

---

## 8. Windows Automated E2E Architecture

Create:

```text
frontend/integration_test/stage5_topics_materials_flow_test.dart
frontend/integration_test/run_stage5_windows_e2e.ps1
```

Optional only when it keeps responsibilities focused:

```text
frontend/integration_test/stage5_e2e_support.dart
```

### 8.1 Real Application Construction

Each Windows process must:

1. initialize `IntegrationTestWidgetsFlutterBinding`;
2. validate all compile-time environment values;
3. configure a deterministic desktop view using the established integration-test
   pattern;
4. clear the production secure-storage auth token before application start;
5. construct:

```dart
ProviderScope(
  overrides: [
    appConfigProvider.overrideWithValue(
      AppConfig.fromApiBaseUrl(apiBaseUrl),
    ),
    teacherMaterialFilePickerProvider.overrideWithValue(testPicker),
    localFileActionsProvider.overrideWithValue(testLocalFileActions),
  ],
  child: const TestLabUzApp(),
)
```

No other provider override is allowed.

Do not call `main()` when that would prevent these exact test-owned overrides.
Do not override Dio, repositories, auth/session, router, Topic/material
controllers, transfer service, failure mapping, or authorization state.

### 8.2 Forbidden Product-Flow Shortcuts

- fake/mock HTTP;
- fake repository;
- injected authenticated session;
- extraction/reuse of the app's stored bearer token;
- Flutter-side DB writes;
- direct filesystem reads as download proof;
- production test hooks/routes;
- calling Dio directly from a Widget;
- arbitrary long sleeps;
- relying on uncontrolled device time or locale.

Use bounded waits on observable route, Widget, controller, or persisted
postcondition state.

### 8.3 Test-Only File Picker

The test picker owns a deterministic FIFO queue:

```text
e2e_s05_material.pdf
e2e_s05_material.docx
e2e_s05_material.ppt
e2e_s05_material.pptx
e2e_s05_replacement.pdf
```

For each invocation it returns a production `TeacherMaterialUploadFile` backed
by the validated manifest path/length/read stream.

It must fail the test on:

- unexpected additional picker call;
- wrong queue order;
- path outside fixture temp root;
- manifest/name/size/hash mismatch.

No picker override is used by Project Owner native smoke.

### 8.4 Test-Only Local File Adapter

Override only the platform adapter behind `localFileActionsProvider`.

For each Save/Open operation the adapter must:

- accept only bytes already produced by the production protected-transfer path;
- write a uniquely named copy under `STAGE5_E2E_FILE_SINK_ROOT`;
- for Save, record operation type, filename, MIME, derived extension, byte size,
  and SHA-256; the test correlates it with the currently selected Material/File;
- for Open, additionally record the File UUID and explicit extension supplied by
  the production `LocalFileActions.open` boundary;
- return a non-null save URI for Save;
- return `LocalFileOpenOutcome.opened` for Open;
- never invoke FilePicker, OpenFile, shell execution, or an external application.

The test must invoke Save and Open as two separate production controller
operations. Each operation must visibly enter its production downloading phase
before the adapter is called, and each adapter call must receive independently
validated trusted bytes. No downloaded-byte cache, direct private-volume read,
or reuse of the prior adapter payload may satisfy the second operation.

### 8.5 Direct Probe Client

One test-owned, non-production helper such as `_Stage5ProbeApi` is explicitly
allowed inside the integration test/support file.

It may use the already installed Dio package, but it must be completely separate
from the application's ProviderScope/client/session.

Allowed uses only:

- malicious direct-ID/scope probes;
- wrong-role/unauthenticated probes;
- exact server-side multipart validation probes;
- exact lifecycle negative/idempotency probes;
- narrow API postconditions not exposed as a visible UI state.

It must not replace positive Flutter UI product flows.

For every probe actor:

```text
POST /api/v1/auth/login
Content-Type: application/json
Accept: application/json

{
  "login": "<reserved e2e_s05_* login>",
  "password": "<STAGE5_E2E_PASSWORD>"
}
```

Parse the token only from:

```text
data.token
```

and verify returned actor ID, Institution ID, role, active state, and
`must_change_password=false` against the sanitized oracle before using it.

Use the token only in memory:

```text
Authorization: Bearer <token>
```

Rules:

- never read the Flutter application's secure-storage token;
- never inject a probe token into Flutter state;
- no mock/bypass of `/auth/login`;
- never print, persist, snapshot, or commit a token;
- call real `POST /api/v1/auth/logout` for each probe token when its actor probe
  set finishes;
- clear token variables even when logout fails;
- a logout failure is reported, but no token value is printed.

### 8.6 Session and Token Cleanup

- clear the production secure-storage token before each Windows process;
- product-role changes occur through visible app logout/login;
- finish each successful product process with normal UI logout;
- direct probe tokens use their own real logout;
- the runner/seeder removes only tokens belonging to manifest-owned users before
  the next clean run;
- never delete unrelated tokens.

---

## 9. Automated Scenario Matrix

### A. Teacher Scope and Draft Privacy

Through real Windows UI:

1. login as `e2e_s05_target_teacher`;
2. reach the canonical Teacher workspace;
3. verify Group A is present in the assigned-Groups authoring projection;
4. verify Group B and archived Group C are absent from that authoring projection;
5. create the exact dynamic Topic in Group A through the production form;
6. capture the Topic UUID from the canonical detail route;
7. validate it as a canonical UUID;
8. verify authoritative detail status is `draft`.

Using the real target-Teacher probe token:

```text
POST Topic for Group B -> 404 resource_not_found
POST Topic for Foreign Group -> 404 resource_not_found
```

Assert zero Topic side effects.

Logout through UI, login as `e2e_s05_target_student`, and verify:

- the dynamic draft Topic is absent from list;
- direct navigation to its canonical Student detail route resolves to the
  privacy-safe unavailable/not-found UI;
- direct Student Topic API probe returns `404 resource_not_found`.

### B. Activation Precondition and Four Valid Uploads

Return to target Teacher through normal UI logout/login.

Before any current material:

```text
activate through UI -> failure feedback
direct authoritative response -> 409 topic_not_editable
Topic remains draft
lifecycle timestamps remain null
```

Then use real Teacher UI plus the deterministic picker queue to upload:

```text
PDF
DOCX
PPT
PPTX
```

Every upload must use production multipart Dio and Laravel.

Verify:

- all four current materials appear in authoritative UI order;
- exact current upload capability shows 25 MiB and four extensions;
- independent DB/blob metadata/checksum matches;
- API/UI projections expose none of:
  `storage_disk`, `storage_key`, private path, checksum, public URL, signed URL.

Update the PDF material title through UI to:

```text
E2E S05 PDF Renamed
```

Verify authoritative refresh and persisted title.

### C. Authoritative Server Validation

Client picker/prechecks are not server evidence.

Using the independent authenticated probe client and real multipart endpoints:

```text
target Teacher + dynamic draft Topic:
  e2e_s05_unsupported.txt
  -> 422 unsupported_file_type

target Teacher + dynamic draft Topic:
  e2e_s05_platform_over.pdf
  exact size 26,214,401
  -> 422 file_too_large

low-limit Teacher + E2E S05 Low Limit Topic:
  e2e_s05_low_limit_over.pdf
  exact size 1,048,577
  -> 422 file_too_large
```

For each request independently verify before/after:

- exact error envelope;
- no new File;
- no new LearningMaterial;
- no private blob;
- Topic and existing materials unchanged.

### D. Activation and Protected Student Transfer

Activate the dynamic Topic through Teacher UI:

```text
draft -> active
activated_at set
```

Immediately call activate again through the direct probe:

```text
200
same Topic status
same activated_at
same updated_at
no write
```

Logout and login as target Student through UI.

Verify:

- Topic appears in list;
- detail/instructions/material metadata appear;
- PDF title is the renamed title;
- Save As performs a real protected GET and the test sink receives the exact PDF
  filename/MIME/extension/bytes/hash;
- Open performs a second real protected GET and the test sink receives the same
  trusted bytes independently.

A direct private-volume read must never substitute for either download.

### E. Security, Tenant, Relationship, and Direct-ID Matrix

Every scoped resource denial must use exact privacy-safe status/code and must not
leak foreign names, IDs beyond the requested locator, storage metadata, SQL,
class names, stack traces, tokens, or internal exception text.

```text
unauthenticated:
  target File download -> 401 authentication_required

target Institution Admin:
  target File download -> 403 forbidden

target Student:
  unrelated Group B Topic -> 404 resource_not_found
  unrelated Group B File -> 404 resource_not_found
  Foreign Topic -> 404 resource_not_found
  Foreign File -> 404 resource_not_found
  Teacher Stage 5 endpoint -> 403 forbidden

unrelated Student:
  target dynamic Topic -> 404 resource_not_found
  target dynamic File -> 404 resource_not_found

ended-membership Student:
  target dynamic Topic -> 404 resource_not_found
  target dynamic File -> 404 resource_not_found
  Group C Topic -> 404 resource_not_found
  Group C File -> 404 resource_not_found

Foreign Student:
  target dynamic Topic -> 404 resource_not_found
  target dynamic File -> 404 resource_not_found

target Teacher:
  unrelated Teacher Group B Topic read -> 404 resource_not_found
  unrelated Teacher Group B Topic mutation -> 404 resource_not_found
  unrelated Teacher Group B File -> 404 resource_not_found
  Foreign Topic -> 404 resource_not_found
  Foreign File -> 404 resource_not_found
```

All negative mutations have zero DB/blob side effects.

### F. Replace, File Identity, and Remove

Return to target Teacher through normal UI.

Replace the PDF material through UI with:

```text
e2e_s05_replacement.pdf
```

Required oracle result:

- same `learning_materials.id`;
- same `files.id`;
- same material title `E2E S05 PDF Renamed`;
- File original name/MIME/extension/size/checksum/storage key now represent the
  replacement PDF;
- the same protected File UUID now downloads replacement bytes;
- old blob is absent after normal post-commit cleanup;
- no extra current Material/File row is created.

Remove the PPT material through UI.

Required result:

- PPT material disappears from current Teacher/Student projections;
- the same Material row remains with non-null `removed_at`;
- the same File row remains with non-null `removed_at`;
- both removal timestamps represent the same removal transition;
- old protected File UUID returns `404 resource_not_found`;
- removed blob is absent;
- Topic and other materials remain intact.

### G. Topic Lifecycle, Read-Only State, and Idempotency

While the dynamic Topic is active:

```text
archive directly -> 409 topic_not_editable
```

Close through Teacher UI:

```text
active -> closed
closed_at set
```

Repeat close through direct API:

```text
200
same closed_at
same updated_at
no write
```

Attempt activate from closed:

```text
409 topic_not_editable
```

Login target Student and prove closed Topic detail/material download remain
available.

Return to Teacher and archive through UI:

```text
closed -> archived
archived_at set
```

For archived Topic:

```text
activate -> 409 topic_not_editable
close -> 409 topic_not_editable
archive again -> 200, no write
```

Verify archived Topic is read-only in Teacher UI. Direct material upload,
replace, title update, and remove each return `409 topic_not_editable` with zero
side effects.

Login target Student and prove archived Topic detail and remaining protected
material download remain available while membership is current.

For `E2E S05 Seeded Draft Topic`, use Teacher UI:

```text
draft -> archived
```

Then repeat archive through direct API and prove idempotent `200` with no
timestamp/write regression.

### H. Archived Group Historical Edge

Use `E2E S05 Archived Group Topic`, whose content existed before Group C became
archived.

The target Teacher has a current Group C membership.

Teacher UI must prove:

- Group C is absent from assigned-Groups authoring projection;
- the historical Group C Topic is visible in Topic list/detail;
- its current material list is readable;
- its protected file is downloadable.

Before lifecycle completion, exact blocked requests are:

```text
POST new Topic for Group C -> 404 resource_not_found

PATCH existing Group C Topic -> 409 topic_not_editable
POST existing Group C Topic /activate -> 409 topic_not_editable

POST material upload -> 409 topic_not_editable
POST material replace -> 409 topic_not_editable
PATCH material title -> 409 topic_not_editable
DELETE material -> 409 topic_not_editable
```

Each rejected mutation preserves all Group C Topic/material/File/blob state.

Before close, target Student must read/download the active historical content.

Target Teacher then performs through UI:

```text
active -> closed
closed -> archived
```

After close, target Student must still read/download. After archive, target
Student must use real UI to read the archived Topic and download its material.

At each state, verify authoritative timestamps/status.

Ended-membership Student receives:

```text
Group C Topic -> 404 resource_not_found
Group C File -> 404 resource_not_found
```

Archived Group status never grants access by itself. Current role, Institution,
ownership, membership, Topic status, and connected Material/File checks remain
mandatory.

---

## 10. Runner, Restart, Persistence, and Cleanup

### 10.1 Exact Windows Test Processes

The mutation/security process uses:

```text
Stage 5 Topics and protected materials use the real Windows stack
```

The persistence process uses:

```text
Stage 5 Topic and protected material state persists after backend restart
```

Each process starts from cleared local auth storage and constructs a new
application root.

### 10.2 Runner Order

`run_stage5_windows_e2e.ps1` executes exactly:

```text
1. validate Flutter executable exists and reports Flutter 3.44.7
2. resolve exact loopback API target
3. run dedicated runtime guard
4. run runtime-guard negative matrix
5. wait boundedly for exact HTTP-ready 401 boundary
6. generate one transient automated password
7. run guarded Stage5E2eSeeder
8. run guarded Stage5E2eSeeder again
9. generate temp file fixtures + validated fixture manifest
10. generate sanitized DB/storage oracle
11. capture frozen unrelated baseline
12. create empty controlled local-file sink root
13. run one Windows mutation/security E2E process
14. run mutation DB/storage postcondition oracle
15. atomically add validated dynamic IDs/hashes to the sanitized host oracle
16. compare frozen unrelated state
17. stop only testlabuz-stage5-e2e-app
18. start only testlabuz-stage5-e2e-app
19. wait boundedly for HTTP readiness
20. rerun the full runtime guard
21. run one fresh Windows persistence E2E process using the updated oracle
22. run persistence DB/storage postcondition oracle
23. compare frozen unrelated state again
24. perform mandatory cleanup
```

Do not recreate or restart:

```text
testlabuz-postgres-1
testlabuz-stage5-e2e-private-files
```

Do not reseed between mutation and persistence processes.

### 10.3 Persistence Requirements

After app-container restart and fresh Flutter process:

- UI-created Topic remains archived with unchanged metadata and lifecycle
  timestamps;
- replacement preserves the same Material and File IDs;
- same File UUID returns replacement bytes/checksum;
- removed material/file remain removed and inaccessible;
- remaining protected blobs exist and are downloadable;
- seeded draft remains archived;
- Group C Topic remains archived and historically accessible to current members;
- current Student historical access remains;
- ended/unrelated/foreign/wrong-role access remains denied;
- frozen unrelated DB/blob state remains unchanged.

### 10.4 Mandatory `finally`

Even after failure, runner cleanup must:

- if the Stage 5 app container exists but is stopped, restart it and wait for
  readiness;
- remove the host oracle;
- remove the fixture manifest and all generated fixtures;
- remove every controlled file-sink artifact and the sink directory;
- remove the container frozen snapshot through the oracle's exact safe path
  guard;
- clear password and all in-memory probe-token variables;
- leave PostgreSQL and the private named volume intact;
- leave no `adb reverse`;
- print no secret.

Cleanup must use exact system-temp filename/path guards. A cleanup failure makes
the runner fail.

After an automated PASS, do not rerun the complete runner merely for
reassurance. After a real finding/fix, rerun enough to prove the complete final
scenario; because the first failed run may not reach later phases, this normally
means one clean full runner execution.

---

## 11. Project Owner Native Windows and Android Smoke

Create:

```text
frontend/integration_test/prepare_stage5_manual_smoke.ps1
```

Parameters:

```powershell
[ValidateSet('Windows', 'Android')]
-Target

-FlutterExecutable <path to Flutter 3.44.7 flutter.bat>
-ApiPort <dedicated loopback port>
-AndroidDeviceId <required only for Android>
```

The script must:

- run the same full Stage 5 runtime guard;
- verify Flutter reports version `3.44.7`;
- prompt with `Read-Host -AsSecureString`;
- convert the secure value only for the seed/run boundary;
- zero/free the BSTR, dispose `SecureString`, and clear plaintext variables in
  `finally`;
- run the guarded Stage 5 seeder;
- generate `e2e_s05_manual_smoke.pdf` under one guarded temp root for Windows;
- print synthetic login names and the picker fixture path only;
- never print the password/token/storage key;
- launch the real application with only `API_BASE_URL`;
- delete the manual temp fixture in `finally`.

### 11.1 Windows Command

From repository root:

```powershell
powershell -ExecutionPolicy Bypass `
  -File frontend/integration_test/prepare_stage5_manual_smoke.ps1 `
  -Target Windows `
  -FlutterExecutable <Flutter-3.44.7-flutter.bat> `
  -ApiPort <dedicated-loopback-port>
```

Project Owner verifies:

1. login `e2e_s05_target_teacher`;
2. open `E2E S05 Seeded Active Topic`;
3. use the **real native FilePicker** to select the exact generated
   `e2e_s05_manual_smoke.pdf`;
4. verify authoritative upload projection;
5. use real protected Open/Save behavior as Teacher where exposed;
6. logout and login `e2e_s05_target_student`;
7. open the seeded active Topic;
8. use **real native Save As**;
9. use **real external Open**;
10. verify correct bytes/filename and no raw JSON, stack trace, overflow, broken
    navigation, storage path/key, or foreign/unrelated content.

### 11.2 Android Command

Before launch, the script must verify the supplied device ID identifies exactly
one online authorized device and use `adb -s <AndroidDeviceId>` for every ADB
operation.

From repository root:

```powershell
powershell -ExecutionPolicy Bypass `
  -File frontend/integration_test/prepare_stage5_manual_smoke.ps1 `
  -Target Android `
  -FlutterExecutable <Flutter-3.44.7-flutter.bat> `
  -ApiPort <dedicated-loopback-port> `
  -AndroidDeviceId <device-id>
```

The script manages:

```text
adb -s <device-id> reverse tcp:<ApiPort> tcp:<ApiPort>
API_BASE_URL=http://127.0.0.1:<ApiPort>/api/v1
```

and removes that exact reverse mapping in `finally`.

Project Owner verifies:

1. login `e2e_s05_target_student`;
2. open `E2E S05 Seeded Active Topic`;
3. see material metadata;
4. perform real protected download;
5. perform real native Save;
6. perform real native Open;
7. see no foreign/unrelated content or internal error output.

If protected download succeeds and TestLabUz hands a valid file to Android but
no installed application supports that file type, report:

```text
BLOCKED
Environment detail: ENVIRONMENT BLOCKED
```

Do not classify it as a TestLabUz defect without contrary evidence.

---

## 12. Allowed and Forbidden Files

### 12.1 Codex-Owned Files

Create/modify only:

```text
backend/database/seeders/Stage5E2eSeeder.php
backend/tests/Feature/Seeders/Stage5E2eSeederTest.php

frontend/integration_test/stage5_topics_materials_flow_test.dart
frontend/integration_test/run_stage5_windows_e2e.ps1
frontend/integration_test/stage5_runtime_guard.ps1
frontend/integration_test/verify_stage5_runtime_guard.ps1
frontend/integration_test/stage5_oracle.ps1
frontend/integration_test/prepare_stage5_manual_smoke.ps1
```

Optional only for a focused responsibility:

```text
frontend/integration_test/stage5_test_files.ps1
frontend/integration_test/stage5_e2e_support.dart
```

No other new helper is allowed without reporting the exact necessity.

### 12.2 Forbidden Changes

```text
backend/app/**
backend/bootstrap/**
backend/routes/**
backend/config/**
backend/database/migrations/**
backend/composer.json
backend/composer.lock

frontend/lib/**
frontend/test/**
frontend/pubspec.yaml
frontend/pubspec.lock
frontend/android/**
frontend/windows/**
frontend/ios/**
frontend/linux/**
frontend/macos/**
frontend/web/**

docker/**
docs/**
*AGENTS.md

frontend/integration_test/stage1_*
frontend/integration_test/stage2_*
frontend/integration_test/stage3_*
frontend/integration_test/stage4_*
frontend/integration_test/run_stage2_*
frontend/integration_test/run_stage3_*
frontend/integration_test/run_stage4_*
frontend/integration_test/verify_stage2_*
frontend/integration_test/verify_stage3_*
frontend/integration_test/verify_stage4_*
frontend/integration_test/prepare_stage2_*
frontend/integration_test/prepare_stage3_*
frontend/integration_test/prepare_stage4_*

tasks/**
```

The current approved task file and Stage index are read-only during Codex
implementation.

Do not commit generated fixtures, downloaded files, temp manifests, oracle
snapshots, evidence secrets, build output, or local runtime files.

No new package or dependency.

If implementation requires a forbidden production/config/schema/dependency file,
return `BLOCKED` and report `INTEGRATION FINDING` when the reason is a production
defect.

---

## 13. Focused Codex Verification

Codex runs only the following focused checks.

### 13.1 Seeder Test

From repository root:

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app `
  php artisan test tests/Feature/Seeders/Stage5E2eSeederTest.php
```

### 13.2 Focused Pint

From repository root:

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app `
  ./vendor/bin/pint --test `
  database/seeders/Stage5E2eSeeder.php `
  tests/Feature/Seeders/Stage5E2eSeederTest.php
```

### 13.3 Focused Dart Format

From `frontend/`:

```powershell
$dartFiles = @(
  'integration_test/stage5_topics_materials_flow_test.dart'
)
if (Test-Path 'integration_test/stage5_e2e_support.dart') {
  $dartFiles += 'integration_test/stage5_e2e_support.dart'
}
fvm dart format --output=none --set-exit-if-changed @dartFiles
```

### 13.4 Focused Flutter Analyze

From `frontend/`:

```powershell
$dartFiles = @(
  'integration_test/stage5_topics_materials_flow_test.dart'
)
if (Test-Path 'integration_test/stage5_e2e_support.dart') {
  $dartFiles += 'integration_test/stage5_e2e_support.dart'
}
fvm flutter analyze @dartFiles
```

Do not run full-project analyze.

### 13.5 PowerShell Parse Check

From repository root:

```powershell
$stage5Scripts = Get-ChildItem frontend/integration_test -File |
  Where-Object {
    $_.Name -match '^(run_stage5_|stage5_|verify_stage5_|prepare_stage5_).*\.ps1$'
  }

if ($stage5Scripts.Count -lt 5) {
  throw 'Expected Stage 5 integration PowerShell assets are missing.'
}

$parseErrors = @()
foreach ($script in $stage5Scripts) {
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile(
    $script.FullName,
    [ref] $tokens,
    [ref] $errors
  ) | Out-Null
  $parseErrors += @($errors)
}

if ($parseErrors.Count -ne 0) {
  $parseErrors | Format-List
  throw 'Stage 5 integration PowerShell parse check failed.'
}
```

### 13.6 Always

```powershell
git diff --check
git status --short
git diff --name-only
```

Then inspect the complete diff and verify:

- only allowed integration assets changed;
- no production/config/schema/dependency/platform/task file changed;
- no old integration asset changed;
- no binary/temp/generated/downloaded file is tracked;
- no password, token, DB credential, private storage key, or private path is
  present;
- no test was weakened;
- no debug/TODO/incomplete acceptance code remains;
- implementation follows the exact fixture, runtime, oracle, security, and
  cleanup contract.

Codex does **not** execute the complete Windows real-stack runner, native smoke,
full suites, full builds, or Phase 2. Project Owner owns those heavy checks.

Narrow diagnostic commands are allowed only to understand a concrete focused
failure. Do not silently broaden verification.

---

## 14. Delivery and Project Owner Execution

### 14.1 Integration Asset Delivery

After Codex reports `IMPLEMENTATION COMPLETE`, Project Owner:

1. reviews the complete allowed-file diff;
2. reruns any focused command whose evidence is missing;
3. stages only task-owned integration assets;
4. performs secret and staged-diff checks;
5. commits and opens one focused PR;
6. merges only after review;
7. synchronizes local `main` with `origin/main`.

Suggested branch/commit:

```text
task/s05-int-001-stage5-real-stack-e2e
test(integration): verify stage 5 real stack
```

Merging integration assets does **not** by itself make `S05-INT-001` Accepted.
The task remains in progress until automated and native evidence passes.

### 14.2 Automated Execution

After integration assets are present on synchronized `main`, Project Owner
provisions the exact guarded runtime and runs from repository root:

```powershell
powershell -ExecutionPolicy Bypass `
  -File frontend/integration_test/run_stage5_windows_e2e.ps1 `
  -FlutterExecutable <Flutter-3.44.7-flutter.bat> `
  -ApiPort <dedicated-loopback-port>
```

Record the exact execution `origin/main` SHA and sanitized PASS/failure labels.

### 14.3 Evidence and Final Bookkeeping

After automated and native smoke:

1. ChatGPT reviews the actual results and any finding;
2. production defects receive separate focused fix contracts;
3. Project Owner reruns only the materially invalidated integration surface,
   while the complete final scenario must eventually pass;
4. Project Owner may add sanitized evidence:

```text
tasks/integration/stage-05/S05-INT-001-stage-05-e2e-evidence.md
```

5. update `tasks/STAGE_05_TASK_INDEX.md`;
6. deliver evidence/bookkeeping through a separate focused PR.

Evidence may record SHAs, sanitized runtime identities, command results, scenario
verdicts, and manual-smoke verdicts. It must never contain passwords, bearer
tokens, token hashes, DB credentials, private storage keys, or temp paths.

Final acceptance requires:

```text
accepted integration assets and evidence on origin/main
local main == origin/main
ahead/behind = 0/0
worktree clean
```

Codex must not commit, push, create/merge a PR, edit task bookkeeping, or claim
delivery/acceptance.

---

## 15. Acceptance Criteria

### 15.1 Codex Implementation-Complete Gate

- [ ] Only allowed integration assets changed.
- [ ] Dedicated runtime guard and negative matrix implement every exact runtime,
      database, mount, private-storage, PHP-limit, and HTTP-boundary rule.
- [ ] Seeder manifest is deterministic, collision-safe, rerun-safe, token-safe,
      DB/blob-consistent, and independently focused-tested.
- [ ] Dynamic UI and manual-smoke cleanup uses full connected ownership and exact
      namespace rules.
- [ ] Temp PDF/DOCX/PPT/PPTX/oversize fixture generation is deterministic and
      commits no binary.
- [ ] Oracle is independent from product endpoints and exposes no secret/private
      storage metadata.
- [ ] Two exact Windows integration-test processes are implemented.
- [ ] Only AppConfig, picker, and local native adapter are overridden.
- [ ] Positive flows use the production app/repositories/Dio/auth/session.
- [ ] Direct probe client is isolated and used only for approved negative/
      validation/idempotency probes.
- [ ] Runner restart/persistence and mandatory cleanup are fail-closed.
- [ ] Manual Windows/Android preparation is secret-safe and manages ADB cleanup.
- [ ] Focused seeder test, Pint, Dart format/analyze, and PowerShell parse checks
      pass.
- [ ] `git diff --check` passes.
- [ ] No production, schema, config, dependency, platform, docs, task, or prior
      integration file changed.

### 15.2 Automated Integration PASS

- [ ] Exact dedicated runtime and negative guard matrix pass.
- [ ] Seeder passes twice consecutively.
- [ ] Teacher UI sees only Group A for new authoring.
- [ ] Same-Institution unrelated and cross-Institution Topic creation return
      privacy-safe `404`.
- [ ] Dynamic Topic is created through real UI and Draft is hidden from Student.
- [ ] Activation without material returns `409 topic_not_editable`.
- [ ] PDF/DOCX/PPT/PPTX upload through real multipart Dio succeeds.
- [ ] Unsupported, 25 MiB + 1 byte, and 1 MiB + 1 byte requests return the exact
      server errors with zero DB/blob side effects.
- [ ] Topic activation and same-state activation idempotency pass.
- [ ] Student real UI sees eligible material metadata.
- [ ] Save and Open each perform an independent real protected download and exact
      byte/hash verification.
- [ ] Unauthenticated, wrong-role, ended-membership, unrelated, foreign, and
      direct-ID matrix passes without leakage.
- [ ] Replace preserves both LearningMaterial ID and File ID and the same File
      UUID returns replacement bytes.
- [ ] Superseded blob is absent after successful replacement.
- [ ] Remove preserves historical rows, marks Material/File removed, makes the
      File UUID unavailable, and removes the blob.
- [ ] Active→Closed→Archived, Draft→Archived, negative transitions, and
      same-state no-write behavior pass.
- [ ] Closed/Archived current-Student historical access passes.
- [ ] Archived Group C authoring/mutation denial and historical lifecycle/access
      pass.
- [ ] Independent DB/private-storage oracle passes.
- [ ] Frozen unrelated/foreign/low-limit state remains unchanged.
- [ ] Backend restart preserves PostgreSQL and private blobs.
- [ ] Fresh Flutter persistence process proves final state and denial matrix.
- [ ] Mandatory temp/container cleanup passes.
- [ ] No production file changed.

### 15.3 Final `S05-INT-001 Accepted / Delivered`

```text
Automated Windows real-stack Integration = PASS
Windows native picker/save/open smoke = PASS
Android Student protected download/save/open smoke = PASS
all INTEGRATION FINDING items resolved through separate focused fixes
valid prior Backend/Frontend Phase 2 evidence retained or minimally reverified
sanitized integration evidence delivered
current origin/main contains the accepted result
local main == origin/main
ahead/behind = 0/0
worktree clean
```

Stage 5 Closure Review remains blocked until all of the above is true.

---

## 16. Codex Completion Report

Return exactly one implementation status:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

If a diagnostic real-stack run exposes production behavior contrary to this
contract, return:

```text
BLOCKED
INTEGRATION FINDING: <exact production defect and affected scenario>
```

If the local runtime cannot satisfy the exact guarded environment without
repository changes, return:

```text
BLOCKED
Environment detail: ENVIRONMENT BLOCKED
```

Report only:

1. status;
2. concise implementation result;
3. changed file → purpose;
4. focused verification command → result;
5. security/tenant/secret-handling evidence;
6. `git diff --check` and scope/diff evidence;
7. current Git branch/status for Project Owner handoff;
8. exact deviations, blockers, or finding.

Do not claim:

```text
Project Owner runner PASS
manual smoke PASS
Delivered
Accepted
```

unless those steps were explicitly assigned to and actually executed by the
reporting actor.
