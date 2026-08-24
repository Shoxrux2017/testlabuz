# S05-INT-001 — Stage 5 Topics and Protected Learning Materials Real-Stack E2E Verification

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S05-INT-001` |
| Stage | `Stage 5 — Topics and Learning Materials` |
| Area | `Integration / real-stack E2E` |
| Status | `Approved` |
| Depends on | Backend Phase 2 `PASS`; Frontend Phase 2 `PASS` |
| Planning / readiness baseline | `origin/main = df6d920311305271ab091f0fbd02abd7e05d9cad` |
| Implementation baseline | `To be recorded immediately before Codex execution after approved bookkeeping delivery` |
| Blocks | Stage 5 Closure Review |
| Codex | integration assets + focused verification only |
| Real-stack/manual execution | `Project Owner` |
| Git/GitHub delivery | `Project Owner` |

Before Codex execution, ChatGPT must re-check current `origin/main` after the
approved Stage 5 Integration-readiness bookkeeping is delivered. Record that SHA
as the implementation baseline. Codex may start only from that exact
implementation baseline after safe Git preflight.

If `origin/main` advances again after the implementation baseline is recorded,
stop and report the new SHA so ChatGPT can determine whether the change is
bookkeeping-only and evidence-safe or whether the contract must be revalidated.

This task verifies delivered production behavior. It must not repair production
code. If real-stack execution exposes a production defect, report
`INTEGRATION FINDING` and stop the affected scenario. ChatGPT designs any
separate production fix.

Fresh Backend/Frontend Phase 2 PASS evidence is reused. Do **not** rerun full
backend/frontend suites, full-project analyze/format, standalone Windows/Android
builds, Phase 2, or broad previous-Stage E2E merely because Integration starts.

---

## 2. Goal and Boundary

Prove:

```text
Flutter Windows / Android
→ production Riverpod/router/repositories/DTOs
→ production Dio
→ Laravel/Sanctum
→ PostgreSQL testlabuz_testing
→ private Laravel file storage
```

Included:

- Teacher assigned Groups, Topic create/read/lifecycle;
- PDF/DOCX/PPT/PPTX material upload;
- server-side unsupported/size-limit rejection;
- protected Student Topic/material access;
- replace/title update/remove;
- tenant/current-membership/direct-ID security;
- archived-Group historical behavior;
- independent DB/storage oracle;
- backend restart + fresh Flutter process;
- automated Windows E2E;
- Windows native file and Android Student smoke.

Non-goals:

- Stage 6+ Homework/Blitz/Question/Attempt/result behavior;
- production backend/frontend/schema/API/config/dependency changes;
- Docker repository configuration changes;
- broad E2E-framework refactor;
- edits to Stage 2–4 integration assets.

No production test-only route/hook/backdoor is allowed.

---

## 3. Codex Context

Codex may inspect only:

1. root `AGENTS.md`;
2. `backend/AGENTS.md`;
3. `frontend/AGENTS.md`;
4. current source/tests/config directly needed for this integration;
5. existing Stage 2–4 integration assets only as read-only implementation patterns.

Do not read roadmap/docs, Stage history, Phase 2 reviews, closure files, previous
task contracts, or the Stage index to rediscover requirements.

Current production boundaries to reuse include:

```text
backend/routes/api.php
backend/app/Actions/Teacher/**
backend/app/Actions/Student/**
backend/app/Actions/Files/DownloadLearningMaterialFile.php
backend/app/Support/Teacher/TeacherLearningMaterialAccess.php
backend/app/Support/Files/{LearningMaterialFileInspector,PrivateFileStorage,ProtectedLearningMaterialAccess}.php

frontend/lib/features/teacher/**
frontend/lib/features/student/**
frontend/lib/core/files/**
frontend/lib/core/network/**
frontend/lib/app/**
```

Native-only seams already exist:

```text
teacherMaterialFilePickerProvider
localFileActionsProvider
```

Production upload/replace must still use real multipart Dio. Protected
download must still use the production transfer/Dio path.

---

## 4. Dedicated Runtime

Project Owner provisions, outside repository changes:

```text
backend container: testlabuz-stage5-e2e-app
APP_ENV=testing
DB_CONNECTION=pgsql
DB_HOST=postgres
DB_DATABASE=testlabuz_testing

PostgreSQL container: testlabuz-postgres-1
Docker network: testlabuz_default

API: http://127.0.0.1:<ApiPort>/api/v1
PRIVATE_FILES_DISK=local

private volume:
testlabuz-stage5-e2e-private-files
→ /var/www/html/storage/app/private
```

The dedicated private volume must be distinct from normal development/public
storage and survive stop/start of the Stage 5 app container.

If this runtime cannot be provisioned safely without changing `docker/**`,
report `ENVIRONMENT BLOCKED`.

### Runtime guard

Create:

```text
frontend/integration_test/stage5_runtime_guard.ps1
frontend/integration_test/verify_stage5_runtime_guard.ps1
```

Before any seed/login/mutation, the guard must prove:

- exact running backend container;
- API bound exactly once to `127.0.0.1:<ApiPort>`;
- exact loopback `/api/v1` URL;
- `APP_ENV=testing`;
- Laravel + PDO = `pgsql`;
- current DB = `testlabuz_testing`;
- DB host/Postgres container/network are approved;
- configured private disk = `local`;
- exact named volume is mounted at `storage/app/private`;
- private root is writable;
- `/auth/me` exposes the expected protected boundary.

Negative matrix must reject malformed/non-loopback URL, wrong port/binding,
wrong/missing/stopped container, wrong environment/database/driver/DB host,
wrong Postgres/network, wrong/private-public disk, and wrong/missing private
volume mount.

Never print secrets or private storage keys.

---

## 5. Deterministic Fixtures

Create:

```text
backend/database/seeders/Stage5E2eSeeder.php
backend/tests/Feature/Seeders/Stage5E2eSeederTest.php
```

Reserved ownership:

```text
UUID prefix: 05000000-...
login prefix: e2e_s05_
display/title prefix: E2E S05
password env: STAGE5_E2E_PASSWORD
```

Use an explicit manifest; prefix matching alone is not ownership proof.

### Fixture world

**Target Institution — limit 25 MiB**

- Institution Admin;
- target Teacher;
- current Student;
- ended-membership Student;
- unrelated Teacher/Student;
- assigned Active Group A;
- unrelated Active Group B;
- Archived Group C;
- current Teacher→A and Student→A memberships;
- ended Student→A membership;
- current Teacher→C and Student→C memberships;
- seeded active Topic/material in A for smoke/reference;
- seeded active historical Topic/material in archived C;
- optional seeded draft Topic in A for deterministic draft→archive/manual smoke.

**Low-limit Institution — limit 1 MiB**

- Teacher, Active Group, current membership, draft Topic.

**Foreign Institution**

- Teacher, Student, Active Group, current memberships;
- active Topic + current protected material/file.

Seeded materials may use small deterministic valid PDF bytes.

Seeder must:

- require `testing` + PostgreSQL + exact test DB;
- require transient password and set login actors `must_change_password=false`;
- refuse incompatible manifest collisions before mutation;
- reset only manifest-owned Stage 5 rows/blobs in FK-safe order;
- never truncate/global-delete/disable constraints;
- preserve unrelated rows/blobs;
- use only dedicated private storage;
- be repeatable.

Focused seeder test must prove runtime/password refusal, collision refusal,
unrelated DB/blob preservation, safe owned reset, and two-run repeatability.

The real runner runs the guarded seeder twice before product mutations.

---

## 6. Temporary File Fixtures

Do not commit large binaries.

Runner generates only under system temp:

```text
small valid PDF
small valid DOCX
small valid PPT
small valid PPTX
replacement PDF
unsupported TXT
PDF = 1 MiB + 1 byte
PDF = 25 MiB + 1 byte
```

DOCX/PPTX/PPT must satisfy the current production content inspector, not merely
fake the filename extension.

Store expected SHA-256 values in a temporary manifest. Delete all generated
fixtures/manifests in `finally`.

One optional `frontend/integration_test/stage5_test_files.ps1` is allowed only
for deterministic fixture generation.

---

## 7. Independent Oracle

Create:

```text
frontend/integration_test/stage5_oracle.ps1
```

Do not derive expected results from the same Stage 5 product endpoints.

Oracle responsibilities:

**DB**

- capture IDs needed by security probes;
- verify UI-created Topic ownership/status/timestamps;
- verify material/file IDs, metadata, checksum, removed state;
- prove replacement keeps `learning_materials.id`;
- prove rejected uploads create no `files`/`learning_materials` rows;
- prove lifecycle/history persistence.

**Private storage**

- expected current blob exists;
- actual SHA-256 = persisted checksum;
- replacement blob contains replacement bytes;
- superseded/removed blob is absent after normal successful cleanup;
- no Stage 5 private blob is exposed through public storage.

**Frozen foreign/unrelated baseline**

Capture before mutations and compare after mutation and after restart. Exclude
only rows expected to change because of login metadata or explicit target
mutations. Foreign/unrelated Stage 5 rows and protected blob hashes must remain
unchanged.

Any host oracle artifact must live under system temp, contain no password/token
or committed private path/key data, and be removed in `finally`.

---

## 8. Windows Automated E2E

Create:

```text
frontend/integration_test/stage5_topics_materials_flow_test.dart
frontend/integration_test/run_stage5_windows_e2e.ps1
```

Forbidden in product flow:

- fake/mock HTTP/repositories/auth/session;
- injected authenticated session;
- Flutter-side DB writes;
- production test routes/hooks;
- arbitrary long sleeps.

Use bounded waits on observable UI/application state.

### Allowed native-only overrides

Automated E2E may replace only:

1. `teacherMaterialFilePickerProvider` → returns the current deterministic local
   fixture instead of opening native FilePicker.
2. the platform adapter behind `localFileActionsProvider` → deterministic temp
   Save/Open sink instead of native Save dialog/external application.

Everything else remains production. The E2E may construct production
`TestLabUzApp` inside a test-owned `ProviderScope` only to inject production
`AppConfig` plus these native-only overrides.

No override of Dio, repositories, auth/session, Topic/material controllers, or
authorization state.

One optional `stage5_e2e_support.dart` is allowed only for these test-native
adapters/helpers.

---

## 9. Automated Scenario Matrix

### A. Teacher scope + draft

Through real Windows UI:

1. login target Teacher;
2. reach canonical Teacher workspace;
3. Group A visible; unrelated B and archived C unavailable for new authoring;
4. create deterministic Topic in A;
5. authoritative detail shows `draft`.

Using the real Teacher token only for malicious probes:

```text
create Topic in unrelated Group B -> 404 resource_not_found
create Topic in foreign Group -> 404 resource_not_found
```

No row is created.

Login current Student through real UI:

```text
new draft absent from list
direct draft Topic -> 404
```

### B. Activation precondition + valid uploads

Return to Teacher via normal logout/login.

Before material:

```text
activate draft -> 409 topic_not_editable
status remains draft
```

Then upload through real UI + production multipart Dio:

```text
PDF
DOCX
PPT
PPTX
```

Verify UI material projections and independent DB/blob/checksum oracle. API/UI
must not expose storage disk/key/path/checksum.

Update at least one material title through UI.

### C. Server validation probes

Picker/client prechecks are not server evidence. Using real authenticated
multipart API probes:

```text
target Teacher: TXT -> 422 unsupported_file_type
target Teacher: 25 MiB + 1 byte -> 422 file_too_large
low-limit Teacher: 1 MiB + 1 byte -> 422 file_too_large
```

Every rejected request leaves no file/material row or private blob.

### D. Activate + Student protected transfer

Activate Topic through Teacher UI:

```text
draft -> active
activated_at set
```

Login current Student through UI:

- Topic/detail/material metadata visible;
- Save As triggers real protected GET through production Dio/Laravel;
- deterministic local sink bytes/hash match uploaded fixture;
- Open triggers a **new** real protected download and sink verifies
  filename/extension/MIME/hash.

A direct filesystem read must never substitute for protected HTTP download.

### E. Security/direct-ID

Using real actor tokens:

```text
current target Student:
  foreign Topic -> 404
  foreign File -> 404
  unrelated current-membership-excluded File -> 404

ended-membership Student:
  target Topic -> 404
  target File -> 404

foreign Student:
  target Topic -> 404
  target File -> 404

target Teacher:
  foreign File -> 404
  another/unrelated Teacher Topic read/mutation -> 404

Student -> Teacher Stage 5 endpoint -> 403 forbidden
```

Responses must not leak foreign details, storage internals, tokens, SQL, or
stack/internal exception text.

### F. Replace + remove

Teacher replaces one current material through UI with replacement PDF.

Required:

- same `learning_materials.id`;
- current bytes/metadata/checksum become replacement;
- subsequent protected download returns replacement bytes;
- superseded blob is not current and is absent after normal local cleanup.

No public contract is imposed on preserving internal `files.id`.

Teacher removes another material through UI:

- no longer in Student detail;
- old File UUID download -> 404;
- normal local cleanup removes blob;
- Topic/other materials remain.

### G. Lifecycle

Main UI-created Topic:

```text
active -> closed -> archived
```

Verify timestamps/history/read-only behavior.

Current Student may still read/download eligible **closed/archived** Topic
content while current membership exists.

Negative probes:

```text
active -> archived directly -> 409 topic_not_editable
closed -> active -> 409 topic_not_editable
archived -> activate/close -> 409 topic_not_editable
```

Seeded draft Topic:

```text
draft -> archived
archived is terminal
```

### H. Archived Group edge

For seeded Topic/material created before Group C was archived:

Teacher with current membership:

- may read;
- cannot create new Topic in C;
- cannot activate/edit/upload/replace/rename/remove learning content in C;
- may `active -> closed -> archived`.

Current Student membership may read/download eligible Active/Closed/Archived
historical content. Ended membership does not retain future access.

---

## 10. Restart/Persistence

After mutation/security flow:

1. DB/storage postcondition oracle;
2. frozen foreign/unrelated comparison;
3. stop/start only `testlabuz-stage5-e2e-app`;
4. rerun runtime guard;
5. launch a fresh Windows integration-test process;
6. clear local token and login normally;
7. verify persisted state.

Required after restart:

- UI-created Topic remains archived with lifecycle timestamps;
- replacement keeps logical material ID and replacement bytes/checksum;
- removed material stays unavailable;
- remaining protected blobs are readable;
- archived-Group historical state remains;
- current Student historical access still works;
- ended/unrelated/foreign actors remain denied;
- frozen foreign/unrelated DB/blob state remains unchanged.

Do not recreate PostgreSQL or the private-file volume.

Runner executes exactly:

```text
guard
guard negative matrix
seeder twice
temp fixtures
DB/storage oracle + frozen baseline
one Windows mutation/security E2E
postconditions
backend restart + guard
one fresh-process persistence E2E
final postconditions/frozen comparison
temp cleanup
```

Do not rerun the complete runner after PASS.

---

## 11. Android and Native Manual Smoke

No second broad automated Android suite is required. Previously passed Android
build evidence remains valid.

Create:

```text
frontend/integration_test/prepare_stage5_manual_smoke.ps1
```

Support:

```text
-Target Windows|Android
-FlutterExecutable <Flutter 3.44.7>
-ApiPort <loopback port>
-AndroidDeviceId <Android only>
```

The script must run the same guard, prompt for password with
`Read-Host -AsSecureString`, seed Stage 5 fixtures, print login names only,
launch the real app, clear secret variables in `finally`, and for Android manage:

```text
adb reverse tcp:<ApiPort> tcp:<ApiPort>
API_BASE_URL=http://127.0.0.1:<ApiPort>/api/v1
```

Remove `adb reverse` in cleanup.

### Windows Project Owner smoke

- login `e2e_s05_target_teacher`;
- use **real native FilePicker** to upload a valid PDF;
- confirm protected open/download;
- login `e2e_s05_target_student`;
- use **real native Save As**;
- open the real file through the OS;
- confirm no broken navigation/overflow/raw JSON/internal errors/storage paths/
  foreign data.

### Android Project Owner smoke

- login `e2e_s05_target_student`;
- open eligible Topic/material;
- real protected download;
- real native Save;
- real native Open;
- no foreign/unrelated content.

If no Android application can handle an otherwise valid file after successful
handoff to the OS, report `ENVIRONMENT BLOCKED`; do not classify it as a
TestLabUz defect without evidence.

---

## 12. Allowed / Forbidden Files

### Codex-owned files

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

Optional only when required for focused responsibility:

```text
frontend/integration_test/stage5_test_files.ps1
frontend/integration_test/stage5_e2e_support.dart
```

### Forbidden changes

```text
backend/app/**
backend/routes/**
backend/config/**
backend/database/migrations/**
frontend/lib/**
frontend/test/**
frontend/pubspec.yaml
frontend/pubspec.lock
frontend/android/**
frontend/windows/**
docker/**
docs/**
*AGENTS.md
Stage 2–4 integration assets
previous task/review/closure files
this approved task file
STAGE_05_TASK_INDEX.md
```

If a forbidden production/config/schema change is necessary, stop with
`INTEGRATION FINDING`/`BLOCKED`.

No new dependency.

---

## 13. Focused Codex Verification

Codex runs only:

### Seeder

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app `
  php artisan test tests/Feature/Seeders/Stage5E2eSeederTest.php
```

### Pint

```powershell
docker compose --env-file docker/.env -f docker/docker-compose.yml exec -T app `
  ./vendor/bin/pint --test `
  database/seeders/Stage5E2eSeeder.php `
  tests/Feature/Seeders/Stage5E2eSeederTest.php
```

### Dart format

From `frontend/`:

```powershell
fvm dart format --output=none --set-exit-if-changed `
  integration_test/stage5_topics_materials_flow_test.dart
```

Include optional `stage5_e2e_support.dart` if created.

### Focused analyze

From `frontend/`:

```powershell
fvm flutter analyze integration_test/stage5_topics_materials_flow_test.dart
```

Analyze optional Dart support file too if created. Do not run full-project
analyze.

### PowerShell

Parse only new Stage 5 integration `.ps1` files with PowerShell's language parser
and require zero parse errors.

### Always

```powershell
git diff --check
git status --short
```

Diff self-check:

- only allowed integration assets;
- no production/config/dependency change;
- no old E2E edit;
- no binary/temp/generated fixture;
- no password/token/private storage key;
- no weakened test/debug code.

Codex does **not** need to execute the full Windows real-stack runner or manual
smoke. Project Owner owns those heavy checks.

---

## 14. Project Owner Execution, Acceptance and Evidence

After Codex focused PASS, Project Owner provisions the guarded runtime and runs:

```powershell
powershell -ExecutionPolicy Bypass `
  -File frontend/integration_test/run_stage5_windows_e2e.ps1 `
  -FlutterExecutable <Flutter-3.44.7-flutter.bat> `
  -ApiPort <dedicated-loopback-port>
```

Then run required Windows and Android manual smoke.

Automated Integration = PASS only if:

- runtime/guard/seeder/frozen-state safety passes;
- Teacher real UI Topic flow passes;
- Draft invisibility passes;
- all four valid formats pass real multipart upload;
- unsupported/25 MiB/lower-limit server rejections have zero side effects;
- protected Student download bytes/checksum pass;
- tenant/current-membership/direct-ID matrix passes;
- replace preserves Learning Material identity;
- removed File becomes unavailable;
- lifecycle + archived-Group behavior pass;
- DB/private-storage independent oracle passes;
- foreign/unrelated state unchanged;
- backend restart + fresh Flutter process preserve DB/blob behavior;
- cleanup and focused diff hygiene pass;
- no production file changed.

Final `S05-INT-001 Accepted / Delivered` additionally requires:

```text
Windows native file smoke = PASS
Android Student protected file smoke = PASS
all integration findings resolved
accepted integration assets/evidence on origin/main
local main == origin/main
ahead/behind = 0/0
worktree clean
```

Codex does not create final evidence/bookkeeping. After execution, ChatGPT reviews
results; Project Owner may deliver sanitized evidence:

```text
tasks/integration/stage-05/S05-INT-001-stage-05-e2e-evidence.md
```

plus the required Stage index update.

Evidence may record SHA/runtime identities/check results/verdicts, but never
passwords, bearer tokens, token hashes, private storage keys, or temp paths.

Suggested implementation branch/commit:

```text
task/s05-int-001-stage5-real-stack-e2e
test(integration): verify stage 5 real stack
```

Codex does not commit/push/open/merge PRs.

---

## 15. Codex Completion Report

Return:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

If a diagnostic real-stack run reveals production behavior contrary to this
contract, use:

```text
INTEGRATION FINDING
```

Report only:

1. status;
2. changed integration files;
3. focused seeder/Pint/Dart/PowerShell results;
4. `git diff --check`;
5. scope/security self-check;
6. Git state for Project Owner handoff;
7. exact blocker/finding if any.

Do not claim Project Owner runner/manual smoke/delivery/task acceptance unless
that evidence was actually executed and reviewed.
