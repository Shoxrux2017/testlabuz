# Codex Execution Prompt — S03-INT-001

Execute exactly one approved TestLabUz task:

`S03-INT-001 — Stage 3 Contract Alignment and Task Control`

Repository:

`G:\project\testlabuz`

Approved remote:

`https://github.com/Shoxrux2017/testlabuz.git`

Authority detailed task:

`tasks/integration/stage-03/S03-INT-001-stage-03-contract-alignment-task-control.md`

Required task branch:

`task/s03-int-001-stage3-contract-alignment`

Read the detailed task completely before acting. It is the scope authority for
this execution prompt. Locked `docs/01–09` remain authoritative except for the
exact Stage 3 API clarifications explicitly approved in the detailed task.

This task is documentation and stage control only.

Do not implement Laravel or Flutter.
Do not start any other Stage 3 task.
Do not start Stage 4.
Do not run the Stage 3 Closure Review.

---

## Mandatory Authority Order

Read and obey, in order:

1. root `AGENTS.md`;
2. `backend/AGENTS.md`;
3. `frontend/AGENTS.md`;
4. the complete S03-INT-001 detailed task;
5. `tasks/README.md`;
6. `tasks/STAGE_02_TASK_INDEX.md`;
7. `tasks/STAGE_02_CLOSURE_REVIEW.md`;
8. Stage 3 and Stage 4 sections in `docs/06-roadmap.md`;
9. Institution Admin, Institution, User, Settings, category, tenancy,
   authorization, database, and API sections in `docs/01–09`;
10. accepted Stage 2 contracts relevant to Institution/User resources,
    middleware, lifecycle, pagination, Flutter routing, and session isolation;
11. current Laravel/Flutter implementation and tests only as compatibility
    evidence;
12. current Git/GitHub state and `origin/main`.

Do not treat current code as permission to reinterpret the approved contract.

---

## Required Dependency State

Before changing anything, prove:

```text
Stage 1 = Closed / PASS
Stage 2 = Closed / PASS
S02-BE-001 through S02-BE-007 = Accepted / PASS / Delivered
S02-FE-001 through S02-FE-009 = Accepted / PASS / Delivered
S02-INT-001 = Accepted / PASS / Delivered
```

Confirm the closure commit is present on `origin/main` and current local main
can be synchronized safely.

Stop if Stage 2 is unclosed, a predecessor is unaccepted/undelivered, or the
current repository contradicts the task baseline.

---

## Git Preflight

1. Verify repository root and exact approved `origin`.
2. Fetch safely.
3. Verify current branch/base and clean synchronized `main`.
4. Expected planning-time base is:

   ```text
   d3078757f3e753af551b649d808547c463feea59
   ```

   A newer base is allowed only if it is the safe current `origin/main` and no
   contract/dependency contradiction exists.

5. The only allowed owner-prepared additions on `main` are:

   ```text
   tasks/integration/stage-03/S03-INT-001-stage-03-contract-alignment-task-control.md
   tasks/integration/stage-03/S03-INT-001-CODEX-PROMPT.md
   ```

6. Do not commit those files on `main`.
7. Create/switch immediately to:

   `task/s03-int-001-stage3-contract-alignment`

8. Preserve unrelated user work. Stop on unexpected dirty state.
9. Do not commit, push, create a PR, or merge before the read-only gate passes.

Never force-push, rewrite history, use destructive cleanup, bypass checks, or
change global Git configuration.

---

## Implement Only the Approved Contract Alignment

Modify only the approved Stage 3 gaps in `docs/09-api-contracts.md`.

### A. Own Institution Profile

Document:

```text
GET   /api/v1/institution/profile
PATCH /api/v1/institution/profile
```

Required role and ownership:

```text
authenticated role = institution_admin
Institution = authenticated user's institution
no client institution selector
```

Required middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:institution_admin
```

Exact profile resource keys, in order:

```text
id
name
type
status
contact_email
contact_phone
address
description
created_at
updated_at
```

Exact PATCH editable keys:

```text
name
contact_email
contact_phone
address
description
```

`type` and `status` are read-only for Institution Admin. Preserve every other
protected field and validation rule from detailed task Section 4.1.

GET returns `200` with the resource and no message. PATCH returns `200` with
the complete resource and exact message:

```text
Institution profile updated successfully.
```

An exact PATCH no-op must not change `updated_at`.

### B. Stage 3 Dashboard

Make Section 31.1 exact, not "possible".

Return exactly three own-Institution total counts:

```text
users.teachers
users.students
users.parents
```

Each number includes active and inactive accounts of that role. Exclude
Institution Admin and Platform Owner. Do not include active-count splits, Group,
or Learning metrics in Stage 3. State that later-stage blocks may be added
additively.

### C. Complete Institution User API

Rename Section 8 and use the exact Section 4.3 order:

```text
8. Institution Admin Profile and User APIs
8.1 Institution Profile
8.2 Shared Institution User Resource
8.3 User List
8.4 Create User
8.5 User Detail
8.6 Update User
8.7 Activate User
8.8 Deactivate User
```

Do not renumber later top-level API sections.

Exact User resource keys, in order:

```text
id
role
full_name
login_name
email
phone
is_active
must_change_password
last_login_at
deactivated_at
created_at
updated_at
```

Use the same resource for list/create/detail/update/activate/deactivate.

Exact list query keys:

```text
role
status
search
page
per_page
sort
direction
```

Exact role/status/default/sort/search/pagination behavior is in detailed task
Section 4.3. `role` omission means all three allowed roles; `status` omission
means both states; trimmed blank `search` means no search and its maximum length
is 254.

Also encode the complete create/detail/update/activate/deactivate contract from
detailed task Sections 4.3.3–4.3.7, including:

- exact input allowlists and field limits;
- strict JSON/query/body rejection;
- server-derived ownership, creator, active, first-login, and timestamp fields;
- global login-name uniqueness and atomic create failure;
- exact success status codes and messages;
- update null/no-op behavior;
- idempotent lifecycle state/timestamp behavior;
- preserved stored tokens/history and active-account access blocking;
- no token creation/deletion/restoration or first-login/password reset;
- strict own-Institution and allowed-role scope-safe lookup.

Do not leave Laravel or Flutter to infer any User mutation behavior.

Exact mutation success results:

```text
create:     201 + Institution user created successfully.
update:     200 + Institution user updated successfully.
activate:   200 + Institution user activated successfully.
deactivate: 200 + Institution user deactivated successfully.
```

Detail returns `200` with the shared User resource and no `message`.

### D. Endpoint Index

Add the profile GET/PATCH endpoints to Appendix A under Institution Admin.
Ensure every new endpoint appears exactly where required and no endpoint is
duplicated inconsistently.

Do not change Settings or Understanding Category contracts.

---

## Create the Stage 3 Task Index

Create:

`tasks/STAGE_03_TASK_INDEX.md`

Use the current Stage index conventions and detailed task Section 5.2.

Record exactly 18 tasks:

```text
S03-INT-001
S03-BE-001 through S03-BE-007
S03-FE-001 through S03-FE-009
S03-INT-002
```

Record the exact order, planned paths, direct dependencies, boundaries, risks,
and closure gate from the detailed task.

Important distinction:

```text
Task/prompt file prepared ≠ implementation started
Task Approved ≠ Accepted
Accepted requires Phase 2 PASS + safe delivery to origin/main
```

At initial Phase 1 creation, record only S03-INT-001 as
`Approved / Not started / Not started`, matching its approved authority file
before the acceptance gate. Record the other 17 planned tasks as
`Draft / Not started / Not started` until each detailed task/prompt pair is
separately reviewed, approved, and placed in the project.

Stage 4 remains blocked until the separate Stage 3 Closure Review is delivered
with:

```text
FINAL STATUS: STAGE CLOSED
```

---

## Allowed Files

During Phase 1, only these files may be created/modified:

```text
docs/09-api-contracts.md
tasks/STAGE_03_TASK_INDEX.md
tasks/integration/stage-03/S03-INT-001-stage-03-contract-alignment-task-control.md
tasks/integration/stage-03/S03-INT-001-CODEX-PROMPT.md
```

After Phase 2 PASS, Phase 3 may additionally modify:

```text
tasks/README.md
```

Do not edit the detailed task or prompt during Phase 1. After Phase 2 PASS, only
the detailed task's explicit status metadata may change; the prompt remains
unchanged. If any authority defect or other correction is discovered, stop with
`NOT ACCEPTED`; do not self-correct the approved pair.

No file under `backend/`, `frontend/`, `docker/`, or `docs/01–08` may change.

---

## Required Documentation Verification

Before Phase 2, prove:

1. Both profile endpoints exist in the normative section and Appendix A.
2. Profile resource and PATCH allowlist are exact.
3. Dashboard contains only the approved three total User count values.
4. User resource contains exactly the approved public keys.
5. User list allowlist/defaults/sorts/literal search/pagination are exact.
6. User create/detail/update/lifecycle validation, no-op/idempotency,
   token/access preservation, resources, statuses, and messages are exact.
7. Cross-Institution selection and disclosure are impossible by contract.
8. Settings/category sections are byte-for-byte unchanged in the diff.
9. `docs/01–08` are unchanged.
10. All 18 Stage 3 tasks and planned paths are present in the index.
11. Dependencies and statuses are internally valid.
12. Stage 3 is not marked closed and Stage 4 is not started.
13. No secret/private/sensitive artifact is present.

Run safe repository-valid commands, including:

```text
git status --short
git diff --check
git diff -- docs/01-business-overview.md docs/02-user-roles.md docs/03-features.md docs/04-user-flows.md docs/05-business-rules.md docs/06-roadmap.md docs/07-architecture.md docs/08-database.md
git diff -- docs/09-api-contracts.md
git diff -- tasks/STAGE_03_TASK_INDEX.md tasks/README.md
rg -n "institution/profile|institution/dashboard|institution/users" docs/09-api-contracts.md
rg -n "S03-(BE|FE|INT)-" tasks/STAGE_03_TASK_INDEX.md
```

Inspect the complete diff including untracked files. Do not run write-format or
auto-fix commands.

Laravel/Flutter test suites are not required because application code is
forbidden. If any application file changes, stop and report scope violation.

---

## Explicit Non-Goals

Do not include:

- any Laravel/Flutter/runtime implementation;
- routes, controllers, requests, actions, resources, models, migrations, UI,
  repositories, providers, or tests;
- Group/relationship behavior from Stage 4;
- Topic/material/Homework/Blitz/result/report behavior;
- Institution Admin account management by Institution Admin;
- Institution lifecycle/type changes by Institution Admin;
- role change, login-name edit, password reset, delete/archive/import/bulk user
  operations;
- Group/Learning dashboard metrics;
- changes to assessment settings or category rules;
- unrelated locked-document edits;
- Stage 3 closure or Stage 4 planning/implementation;
- deployment, CI, dependencies, or refactors.

---

## Mandatory Read-Only Acceptance Gate

After Phase 1 and all non-writing verification, start Phase 2.

Re-read:

- the detailed task and this prompt;
- relevant locked Stage 3 contracts;
- complete diff including untracked files;
- Stage 2 closure/dependency evidence;
- endpoint/resource/query/tenant/index checks;
- scope and sensitive-data checks.

Phase 2 is strictly read-only:

- no edits;
- no auto-fix/write-format;
- no task/status bookkeeping edits;
- no staging;
- no commit;
- no push/PR/merge;
- no self-fixing findings.

Classify P1/P2/P3 exactly as the detailed task requires.

Any unresolved P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop. Do not deliver or start another task.

---

## Post-PASS GitHub Delivery

Only after Phase 2 PASS:

1. prepare only S03-INT-001 as `Accepted` in its task metadata for the delivery
   commit; it becomes authoritative only after successful delivery;
2. prepare its Stage 3 index row as `Accepted / PASS / Delivered` in the
   delivery commit; those values become authoritative only after successful
   merge, main synchronization, and clean verification;
3. update `tasks/README.md` to truthful Stage 3 In Progress state;
4. leave all later implementation tasks Not started;
5. keep Stage 3 not closed and Stage 4 not started;
6. rerun final non-writing diff/scope/secret/consistency checks;
7. stage only approved files;
8. commit:

   ```text
   docs(stage3): align institution administration contracts
   ```

   Body:

   ```text
   Task: S03-INT-001
   ```

9. push `task/s03-int-001-stage3-contract-alignment`;
10. open a PR to `main`;
11. wait for required checks;
12. merge only when safe/green and permitted;
13. synchronize local `main` by fast-forward only;
14. verify local `main == origin/main` and clean status.

Never push the task directly to established `main`, force-push, rewrite
history, bypass checks, modify global Git config, or commit credentials.

If delivery fails after PASS:

```text
FINAL STATUS: DELIVERY BLOCKED
```

If delivery fully succeeds:

```text
FINAL STATUS: ACCEPTED
```

Next implementation gate:

```text
S03-BE-001 — Institution Admin Dashboard API
```

Do not implement it in this task.

---

## Required Final Response

Report:

1. final status;
2. Stage 1/2 dependency and Git preflight evidence;
3. exact profile contract result;
4. exact dashboard contract result;
5. exact complete User API contract result;
6. Stage 3 index 18-task/dependency/path result;
7. changed files;
8. verification commands/results;
9. P1/P2/P3 findings;
10. tenant/security/resource-disclosure evidence;
11. docs 01–08 and settings/category preservation evidence;
12. application/runtime no-change evidence;
13. acceptance checklist summary;
14. commit/branch/PR/checks/merge/hash/clean delivery evidence;
15. manual Laravel/Flutter consumer-read result;
16. blockers/deviations;
17. exact statements:

    ```text
    Stage 3 was NOT marked Closed by this task.
    Stage 4 was NOT started.
    Next implementation gate: S03-BE-001.
    ```
