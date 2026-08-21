# Stage 4 Frontend Phase 2 — Read-Only Block Review

## 1. Review Metadata

| Field | Value |
|---|---|
| Stage | `Stage 4 — Groups and User Relationships` |
| Block | Frontend (`S04-FE-001` through `S04-FE-005`) |
| Status | `Prepared — entry gate pending S04-FE-005 delivery` |
| Review mode | `Read-only` |
| Backend checkpoint dependency | Complete Stage 4 Backend Phase 2 = `PASS` |
| Frontend entry gate | `S04-FE-001…005 Accepted / Delivered` on synchronized `origin/main` |
| Audited branch | `main` |
| Required repository state | local `main == origin/main`, ahead/behind `0/0`, clean worktree |
| Stage 4 frontend baseline | `1bc138a29250f575bc000c4be3e22d72f5b68e55` |
| Audited `origin/main` | `<supply exact SHA after S04-FE-005 delivery>` |
| Verdict | `Pending` |
| Verdicts | `PASS` or `NOT ACCEPTED` |
| Next gate after PASS | Stage 4 Integration Planning / Decomposition |

This checkpoint reviews the complete delivered Stage 4 frontend block as one integrated implementation surface.

It does not:

- implement fixes;
- perform GitHub delivery;
- modify task or Stage bookkeeping;
- run real-stack/E2E integration;
- authorize Stage closure.

ChatGPT owns:

- review scope;
- requirements/architecture/API/state/security analysis;
- findings and severity;
- final checkpoint verdict.

Codex may execute only the explicitly assigned read-only commands and collect evidence. Codex must not make missing product, UX, architecture, API, security, tenant, lifecycle, mutation-outcome, cache, or state-ownership decisions.

---

## 2. Preparation Baseline and Current State

The Stage 4 frontend implementation baseline is the first parent of the S04-FE-001 merge:

```text
1bc138a29250f575bc000c4be3e22d72f5b68e55
```

This baseline contains the approved planning package immediately before Stage 4 frontend production implementation began.

At review preparation time:

```text
origin/main:
94cb460012f0c0a84ed586c809a05ee6aec28c73

S04-FE-001:
Accepted / Delivered
PR #89
merge 698b611677522071b6dae547c997c3f1a503d19e

S04-FE-002:
Accepted / Delivered
PR #90
merge d330d693c02a9a8bed043e5628989bbe56979ccf

S04-FE-003:
Accepted / Delivered
PR #91
merge b4e23fc8f230f64b1a7a1160ce93bee904f2d631

S04-FE-004:
Accepted / Delivered
PR #92
merge 0c1ecd80ac3cbb9db1e60582c08ab51dbebb2147

S04-FE-005:
Approved / implementation in progress
```

The final audited `origin/main` SHA must be supplied only after S04-FE-005 is Accepted / Delivered.

Do not begin Phase 2 against the preparation SHA.

---

## 3. Authoritative Inputs and Context Discipline

### 3.1 ChatGPT/reviewer inputs

ChatGPT must re-check and reconcile:

- final current `origin/main`;
- root `AGENTS.md`;
- `frontend/AGENTS.md`;
- `tasks/README.md`;
- `tasks/STAGE_04_TASK_INDEX.md`;
- approved contracts `S04-FE-001` through `S04-FE-005`;
- relevant locked `docs/01–09`;
- current Stage 4 frontend implementation and tests;
- delivery evidence for all five frontend tasks;
- complete Stage 4 Backend Phase 2 PASS evidence;
- previous Stage evidence only where required for regression/dependency review.

GitHub is the source of truth. Do not rely solely on task completion summaries or earlier chat memory.

### 3.2 Codex evidence-collection inputs

Codex may read only:

1. this review contract;
2. root `AGENTS.md`;
3. `frontend/AGENTS.md`;
4. current frontend source/tests/configuration required to inspect the delivered block;
5. files required to run the commands in this contract.

Codex must not reopen:

```text
docs/
roadmap/specifications
previous implementation task contracts
Stage history
task index
checkpoint/closure records
```

to reinterpret requirements.

The review requirements below are already resolved and self-contained for evidence collection.

---

## 4. Entry Conditions

Before any Phase 2 command runs, verify all:

| Condition | Required result |
|---|---|
| Complete Stage 4 Backend Phase 2 | `PASS` |
| `S04-FE-001` | `Accepted / Delivered` |
| `S04-FE-002` | `Accepted / Delivered` |
| `S04-FE-003` | `Accepted / Delivered` |
| `S04-FE-004` | `Accepted / Delivered` |
| `S04-FE-005` | `Accepted / Delivered` |
| All accepted outcomes | Present on `origin/main` |
| Local branch | `main` |
| `local main == origin/main` | Yes |
| Ahead/behind | `0/0` |
| Worktree | Clean |
| Origin | Expected TestLabUz repository |
| FVM Flutter SDK | `3.44.7` available |
| Windows Flutter target/toolchain | Available |

Required preflight from repository root:

```powershell
git remote -v
git switch main
git fetch --prune origin
git branch --show-current
git rev-parse HEAD
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
git status --short
```

Verify the supplied baseline:

```powershell
$Stage4FrontendBaseline = "1bc138a29250f575bc000c4be3e22d72f5b68e55"

git cat-file -e "$Stage4FrontendBaseline^{commit}"
git merge-base --is-ancestor $Stage4FrontendBaseline origin/main
```

ChatGPT/orchestration must provide the exact expected final audited `origin/main` SHA after FE-005 delivery.

If any entry condition fails:

```text
EVIDENCE COLLECTION BLOCKED
```

Stop the checkpoint. Do not assign `PASS`.

---

## 5. Strict Read-Only Boundary

During this checkpoint do not:

- edit, create, rename, or delete tracked repository files;
- run auto-fix formatters;
- run `dart fix`, code generation, or migration/generator commands;
- install or update packages;
- alter `pubspec.yaml` or `pubspec.lock`;
- alter platform files;
- alter application/environment configuration;
- stage, commit, push, merge, or open/update a PR;
- modify task/Stage bookkeeping;
- fix a finding;
- begin Stage integration.

Allowed:

- read-only Git inspection;
- full Flutter test suite;
- Flutter static analysis;
- Dart format check with `--output=none --set-exit-if-changed`;
- Windows debug build;
- read-only source/test inspection;
- generated **ignored** test/build/cache outputs required by Flutter commands.

Do not run:

```text
flutter clean
dart fix
dart format without --output=none
pub upgrade
package update commands
real-stack/E2E integration tests
```

If a command unexpectedly changes a tracked file:

1. stop;
2. preserve evidence;
3. report the changed file;
4. do not silently revert or clean it.

Ignored `.dart_tool/`, `build/`, and equivalent normal Flutter output do not violate the boundary, but final tracked worktree state must remain clean.

---

## 6. Reviewed Delta and Scope

Use:

```powershell
$Stage4FrontendBaseline = "1bc138a29250f575bc000c4be3e22d72f5b68e55"
```

From repository root:

```powershell
git diff --check $Stage4FrontendBaseline origin/main
git diff --name-status $Stage4FrontendBaseline origin/main
git diff --stat $Stage4FrontendBaseline origin/main
git diff $Stage4FrontendBaseline origin/main -- frontend
```

Also inspect Stage 4 planning/review files separately:

```powershell
git diff --name-status $Stage4FrontendBaseline origin/main -- tasks/frontend/stage-04 tasks/STAGE_04_TASK_INDEX.md
```

The Stage 4 frontend **product delta** must be confined to `frontend/`.

Separately approved task/index/runner changes under `tasks/` are orchestration evidence, not frontend product scope.

Blocking unexplained scope includes:

- backend production/test changes caused by frontend tasks;
- locked `docs/01–09` changes;
- package or lock changes without an approved dependency change;
- platform-file changes without an approved platform requirement;
- CI/deployment changes unrelated to Stage 4;
- unrelated feature/refactor/format churn;
- generated or temporary artifacts committed to Git;
- hidden implementation for later Stages;
- duplicate router/client/state/cache architecture.

Review every changed frontend file in the Stage 4 delta.

---

## 7. Audited Frontend Task Inventory

| Task | Approved responsibility |
|---|---|
| `S04-FE-001` | Institution Group navigation and server-driven Group list |
| `S04-FE-002` | Group create and authoritative Group Detail |
| `S04-FE-003` | Group edit and archive lifecycle |
| `S04-FE-004` | Teacher/Student Group membership management |
| `S04-FE-005` | Parent–Student current relationship management |

Confirm:

- every approved task is present in the delivered frontend;
- no task silently overrides another task contract;
- later tasks reuse delivered owners rather than duplicating them;
- non-goals remain excluded;
- no frontend task modified backend behavior;
- no implementation depends on reading task files at runtime.

---

# 8. Approved Route and Shell Surface

Review exact Stage 4 frontend routes:

```text
/institution-admin/groups
/institution-admin/groups/new
/institution-admin/groups/:groupId
/institution-admin/users/parent-student-connections
```

Required route properties:

### Groups

```text
route names/paths unique
Groups is an Institution Admin primary destination
navigation order:
Dashboard
Users
Groups
Institution
Settings

/groups/new declared before /groups/:groupId
new can never be interpreted as a UUID
detail target uses canonical UUID helper
detail query/fragment direct entry fails safely
```

### Parent–Student connections

```text
static route declared before /institution-admin/users/:userId
static segment can never be interpreted as User UUID
route is protected/static-approved
route is not a primary navigation rail destination
selected shell destination = Users
page title = Parent–Student Connections
```

All Stage 4 frontend routes must remain:

```text
Institution Admin only
desktop only
active User only
must_change_password = false
active matching Institution only
```

Route guards improve UX and do not replace backend authorization.

No Stage 4 list/perspective/anchor/filter/page state may be client-authoritatively derived from unapproved URL query/fragment values.

Review direct-entry behavior and regression to existing User create/detail and Platform Owner routes.

---

# 9. Approved API Consumption Surface

Exactly these 15 Stage 4 backend endpoints are consumed.

## 9.1 Group management — 5

```text
GET    /api/v1/institution/groups
POST   /api/v1/institution/groups
GET    /api/v1/institution/groups/{group}
PATCH  /api/v1/institution/groups/{group}
POST   /api/v1/institution/groups/{group}/archive
```

## 9.2 Group memberships — 6

```text
GET    /api/v1/institution/groups/{group}/teachers
POST   /api/v1/institution/groups/{group}/teachers
DELETE /api/v1/institution/groups/{group}/teachers/{teacher}

GET    /api/v1/institution/groups/{group}/students
POST   /api/v1/institution/groups/{group}/students
DELETE /api/v1/institution/groups/{group}/students/{student}
```

## 9.3 Parent–Student relationships — 4

```text
GET    /api/v1/institution/parents/{parent}/students
GET    /api/v1/institution/students/{student}/parents
POST   /api/v1/institution/parent-student-relationships
DELETE /api/v1/institution/parent-student-relationships/{relationship}
```

Also review reuse of existing:

```text
GET /api/v1/institution/users
```

for typed Parent/Student/Teacher candidate and anchor selection.

No new backend candidate/global relationship endpoint is approved.

Unapproved examples:

```text
/api/v1/institution/parent-student-connections
/api/v1/institution/groups/{group}/membership-history
```

---

# 10. Transport, DTO, and Error Contract Review

Review every Stage 4 remote data source/repository for:

## 10.1 GET

- configured Dio client reused;
- no body/data bytes;
- exact allowed query keys;
- required default query dimensions serialized consistently;
- nullable filters/search omitted rather than sent as invalid values;
- exact success status;
- malformed success -> typed `invalidResponse`;
- strict exact envelope and pagination parsing;
- no raw maps escape into application/presentation.

## 10.2 POST/PATCH

- `application/json` object;
- exact allowed keys;
- no tenant-authority fields;
- exact success statuses/messages;
- strict success DTOs and cross-field/target invariants;
- partial Group PATCH sends only changed normalized fields;
- local Group no-op sends zero mutation request;
- no automatic mutation replay.

## 10.3 DELETE/archive body behavior

- archive and relationship-removal requests follow exact approved zero-body or task-defined shape;
- no accidental `{}`/`null` body where zero body bytes are required;
- exact `204` handling for DELETE;
- meaningful body on `204` is not silently accepted;
- no query parameters.

## 10.4 Stable errors

Review exact machine-code branching:

```text
authentication_required
forbidden
password_change_required
user_inactive
institution_inactive
resource_not_found
business_conflict
validation_failed
rate_limited
```

Confirm:

- no human-readable backend-message branching;
- strict mutation error envelopes;
- raw validation messages are not rendered;
- session-authority errors use central session reconciliation;
- existence-private `404` behavior is preserved;
- uncertain transport/protocol outcomes remain unconfirmed.

No token, raw JSON, URL with private IDs, stack trace, SQL, or internal exception is exposed.

---

# 11. FE-001 — Group Navigation and List Review

Review:

- exact Group resource keys and lifecycle invariant;
- strict UUID/timestamp/count parsing;
- exact list pagination envelope;
- search uses `runes.length`, outer trim, literal special characters;
- 300 ms debounce;
- pending-search interaction with filter/sort/page/refresh;
- invalid-search request blocking;
- deterministic sort/query serialization;
- one bounded page correction;
- independent loading/queryLoading/refreshing/data/empty/error states;
- manual Retry exact failed query;
- same-session retained query/search ownership;
- retained state cleared on account/session/institution/device change;
- stale/superseded/disposed completion rejection;
- no create/detail/mutation implementation leaked into FE-001 beyond later approved integration.

Group list must never be optimistically patched for:

```text
row ordering
pagination total
status
Teacher/Student counts
```

---

# 12. FE-002 — Group Create and Detail Review

## 12.1 Create

Review:

- exact four-field controlled form;
- Unicode-code-point limits;
- optional `null` normalization;
- multiline Description behavior;
- duplicate names allowed;
- exact four-key JSON request;
- exact `201` success and response/request snapshot invariants;
- definite vs uncertain mutation outcomes;
- no automatic POST replay;
- uncertain recovery uses recent active Groups without claiming success;
- Group-list stale ownership preserves retained query;
- no Institution Dashboard invalidation;
- navigation occurs only from current owned confirmed success.

## 12.2 Detail

Review:

- canonical route target;
- exact bodyless/queryless GET;
- returned Group ID matches requested target;
- privacy-safe exact 404;
- malformed 404 is not treated as valid not-found;
- load/refresh/error/not-found transitions;
- failed refresh cannot leave stale Group as current confirmed data;
- session/target/dispose stale completion rejection;
- authoritative counts/timestamps;
- no membership requests in FE-002 responsibility.

---

# 13. FE-003 — Group Edit and Archive Review

Review:

- Edit/Archive available only for confirmed active Group;
- archived Group is read-only;
- edit dialog normalization and changed-fields-only PATCH;
- normalized local no-op produces zero PATCH/GET/list invalidation;
- archive sends exact approved no-body request;
- strict success/error envelopes and immutable Group identity;
- `business_conflict` uses machine code only;
- no automatic PATCH/archive replay;
- `409` and uncertain outcome perform one authoritative reconciliation read;
- failed reconciliation removes stale confirmed active Group/actions;
- list stale marker timing is narrow and retained query is preserved;
- Edit/Archive dialog transition/focus matrix;
- action ownership includes exact selected Group object/session/target/generation;
- stale action cannot close newer dialog, publish feedback, restore obsolete focus, or navigate.

---

# 14. FE-004 — Teacher/Student Group Membership Review

Review:

## 14.1 Lists

- one shared typed Teacher/Student implementation where responsibility matches;
- separate `memberKind` machine values;
- independent Teacher and Student query/read states;
- exact member/list/pagination DTOs;
- archived Group remains readable;
- inactive current members remain visible/removable;
- mutation-induced old rows are explicitly non-authoritative while checking;
- failed reload discards stale rows rather than returning them as confirmed.

## 14.2 Candidate selection

- existing User repository reused;
- fixed role/active-purpose validation;
- wrong-role/inactive mismatch -> invalidResponse;
- no global Users controller/retained-state mutation;
- ordered cross-page selection;
- persistent selected tray permits off-page removal;
- maximum 100;
- no exclusive-Group or must-change-password candidate rule.

## 14.3 Assign/remove

- exact kind-specific POST body;
- strict `200/201` response ordering/ID/resource checks;
- exact zero-body DELETE and strict `204`;
- no mutation replay;
- membership identity includes User ID + `startedAt` + selected object identity;
- removed/reassigned same User cannot receive stale completion/focus;
- authoritative Group Detail count refresh;
- Group-list stale marking preserves query;
- confirmed mutation remains confirmed if later projection reload fails.

## 14.4 Cross-action integration

Exactly one Group-scoped action/dialog may own Group Detail:

```text
Edit
Archive
Assign Teachers
Assign Students
Remove Teacher
Remove Student
```

Confirm no provider cycle and no second Group Detail/cache owner.

---

# 15. FE-005 — Parent–Student Relationship Review

## 15.1 Route and User entry

Review static Users-nested route ordering/classification, shell selection/title, direct entry, and responsive Users header action.

## 15.2 Anchor selectors

- Parent/Student bounded single-select pickers;
- all-status anchor eligibility;
- exact fixed-role validation;
- inactive anchors allowed;
- no main Users retained/controller mutation;
- no anchor -> zero relationship GET;
- anchor change/clear invalidates old publication safely.

## 15.3 Relationship projections

- independent `By Parent` / `By Student` state;
- strict current relationship + related User DTO;
- direction/anchor/opposite-user invariants;
- inactive related Users visible/disconnectable;
- no current/history mixing;
- cross-perspective matching-anchor stale marker;
- hidden stale perspective reloads on next switch;
- stale rows never masquerade as confirmed after failed reconciliation.

## 15.4 Connect

- one bounded dialog with independent active Parent/Student selectors;
- exact two-key JSON;
- strict `201/200`;
- no many-to-many restriction;
- strict error envelope;
- recoverable vs terminal dialog transitions;
- no replay;
- unknown Connect recovery uses recent current connections and remains explicitly unconfirmed.

## 15.5 Disconnect

- target is relationship UUID;
- exact relationship identity includes ID/pair/startedAt/object/perspective/anchor;
- strict zero-body `204`;
- history/reconnect semantics;
- no replay;
- stale disconnect cannot affect a newly reconnected row;
- confirmed mutation and subsequent projection-read state remain separate.

No Group, Dashboard, User-list, or User-detail invalidation is approved for Parent–Student mutations.

---

# 16. Architecture and Responsibility Review

Confirm:

- feature-first placement remains coherent;
- data/domain/application/presentation responsibilities are separated;
- Widgets do not call Dio, build API URLs, or parse JSON;
- remote data sources own HTTP construction;
- DTOs own exact transport validation;
- repositories expose typed operations/failures;
- controllers own focused application state and async ownership;
- Widgets own rendering/input/focus/navigation effects only;
- no God controller/screen coordinates unrelated features;
- no duplicate HTTP client, router, state framework, serializer, or cache;
- existing User repository reuse is narrow and typed;
- Group Detail/list owners are reused rather than duplicated;
- Parent–Student relationship code is not forced into Group membership abstractions;
- backend-authoritative business decisions are not recreated in Flutter;
- machine values and display labels are separate;
- no runtime dependency on task/docs files;
- no unnecessary package/generator/platform change exists.

Review large files for mixed responsibilities, not merely line count.

---

# 17. Session, Authorization, Tenant, and Privacy Review

Eligible Stage 4 frontend actor remains exactly:

```text
authenticated
role = institution_admin
active User
must_change_password = false
matching active Institution
desktop surface
```

Review:

- route eligibility;
- provider/controller eligibility;
- current User object-instance/session-key ownership;
- Institution ID ownership;
- account/institution/device change invalidation;
- no prior-session rows, drafts, feedback, dialogs, or focus leak into new session;
- no client-supplied `institution_id`/tenant selector;
- direct UUID never widens backend scope;
- cross-tenant/wrong-role/missing resources use privacy-safe handling;
- UI hiding is not treated as authorization;
- no sensitive field/token/raw transport logging;
- session-authority responses clear protected frontend state.

Any unresolved tenant/privacy/session data leak is P1.

---

# 18. Async Ownership and State-Machine Review

Review all Stage 4 controllers for:

- immutable request/operation snapshots;
- request generation counters or equivalent;
- duplicate request/mutation suppression;
- exact route/target/session/perspective/member/relationship ownership;
- stale success and stale error rejection;
- disposal safety;
- dialog ownership;
- navigation effect ownership;
- focus-restoration ownership;
- no stale feedback in another session/target;
- no old query rows shown as new query data;
- no stale active actions after failed authoritative reconciliation;
- terminal mutation feedback not erased by later projection replacement;
- uncertain outcome never presented as confirmed success/failure;
- retry/manual new submit behavior matches contract;
- no stuck loading/busy/reconciling state.

Equivalent state rebuilds must not cancel a still-current operation without a contract reason.

---

# 19. Cache, Retention, and Invalidation Review

Review the complete ownership graph:

```text
Group list retained query/search + stale marker
Group Detail route-scoped authoritative resource
Teacher membership route-scoped query/result
Student membership route-scoped query/result
membership candidate dialog-local state
Parent–Student perspective route-local state
Parent/Student selector dialog-local state
main Institution Users retained list state
```

Confirm:

- one owner per authoritative resource/query responsibility;
- no duplicate Group/User/relationship cache;
- Group-list query survives approved mutations;
- Group-list rows/counts are marked stale rather than optimistically patched;
- membership mutation refreshes only relevant membership/Group projections;
- Parent–Student mutations do not invalidate unrelated User/Group/Dashboard state;
- hidden matching Parent–Student perspective becomes stale;
- session/route exit clears state exactly where required;
- candidate/dialog state does not persist globally.

---

# 20. UX, Accessibility, Keyboard, Focus, and Responsiveness Review

Review code and deterministic widget tests for:

- semantic headings;
- associated field errors;
- status text not color-only;
- search keyboard submission;
- sortable-header direction semantics;
- predictable traversal;
- visible/reachable actions;
- Escape/Cancel behavior before mutation;
- dismissal blocking during mutation/reconciliation;
- duplicate submit suppression;
- progress/live-region semantics;
- focus to first invalid field;
- focus restoration only to current exact control/resource identity;
- no focus restoration to archived/not-found/reassigned/disposed controls;
- text scale 2.0 behavior where required;
- supported narrow desktop widths;
- horizontal table scrolling;
- bounded dialogs;
- no RenderFlex overflow;
- long names/descriptions/contact values;
- independent section errors without hiding unrelated content;
- no nested unbounded scroll/focus trap.

A material keyboard/accessibility/responsive failure in an approved core flow is P2.

---

# 21. Test Inventory and Quality Review

Inventory all Stage 4 frontend tests added/modified from the baseline.

Expected responsibility categories:

```text
router and shell
Group domain/query/DTO/list
Group create/detail
Group mutation/action
Group membership domain/DTO/read/candidate/action
Parent–Student domain/DTO/read/selector/action
Institution Admin Group/User screens
```

Test-quality requirements:

- deterministic fake/injected repositories/clients;
- explicit async completion control;
- no real external network;
- no arbitrary sleeps;
- no uncontrolled locale/time;
- strict request/response tests at data-source boundary;
- stale-session/target/perspective/member/relationship completion tests;
- duplicate request/mutation suppression;
- not-found/privacy-safe behavior;
- unknown mutation outcome;
- cache/stale invalidation;
- focus/keyboard/semantics/responsive coverage;
- critical cross-task arbitration;
- no backend business formula duplicated as frontend authority;
- no existing tests weakened merely to pass implementation;
- no skipped critical Stage 4 test.

Blocking weaknesses include missing critical coverage for:

```text
route static/dynamic ordering
session/tenant stale data
mutation uncertainty/no replay
failed reconciliation stale-authority removal
Group action arbitration
cross-perspective stale reload
disconnect/reconnect relationship identity
```

---

# 22. Required Frontend Verification

Run from repository root exactly as below.

## 22.1 SDK

```powershell
Push-Location frontend
fvm spawn 3.44.7 --version
Pop-Location
```

Require Flutter `3.44.7` and its bundled compatible Dart SDK.

## 22.2 Format check

```powershell
Push-Location frontend

C:\Users\Administrator\fvm\versions\3.44.7\bin\cache\dart-sdk\bin\dart.exe `
  format --output=none --set-exit-if-changed lib test integration_test

Pop-Location
```

If `integration_test` is absent in the audited final tree, omit only that path and report the exact command.

The command must modify zero tracked files.

## 22.3 Static analysis

```powershell
Push-Location frontend
fvm spawn 3.44.7 analyze
Pop-Location
```

Require:

```text
exit code 0
no issues
```

## 22.4 Full frontend test suite

```powershell
Push-Location frontend
fvm spawn 3.44.7 test
Pop-Location
```

This is the complete `frontend/test/` regression suite.

Do not run real-stack `integration_test/` here; Stage integration owns real backend/frontend E2E.

Require:

- exit code 0;
- all tests pass;
- no critical skipped/incomplete test;
- exact passed-test count recorded;
- exact duration recorded when available.

Do not silently rerun a failed full suite. Record every run. Narrow diagnostic runs are allowed only to explain a failure and do not erase the original evidence.

## 22.5 Required Windows build

```powershell
Push-Location frontend

fvm spawn 3.44.7 build windows --debug `
  --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1

Pop-Location
```

Require:

- exit code 0;
- Windows debug artifact built successfully;
- no tracked file changed;
- no dependency/platform regeneration committed.

This is build verification only. It is not real-stack/E2E evidence.

## 22.6 Final Git checks

From repository root:

```powershell
$Stage4FrontendBaseline = "1bc138a29250f575bc000c4be3e22d72f5b68e55"

git diff --check $Stage4FrontendBaseline origin/main
git status --short
git rev-parse HEAD
git rev-parse origin/main
git rev-list --left-right --count main...origin/main
```

Require:

```text
diff check PASS
status empty
HEAD == origin/main
ahead/behind 0/0
```

If a full suite, analyzer, formatter, or build failure occurs, preserve exact output and classify whether it is:

```text
candidate implementation defect
pre-existing baseline defect
environment/toolchain blocker
```

Do not claim PASS without sufficient evidence.

---

# 23. Previous-Stage Regression Review

Full frontend suite is primary regression evidence.

Explicitly review shared Stage 4 changes for regressions to:

```text
authentication/bootstrap/login/logout
mandatory password change
role entry routing
unsupported-device routing
Platform Owner routes/screens
Institution Admin dashboard
Institution profile
Institution Users list/detail/create/update/lifecycle
assessment settings
understanding categories
central Dio/failure/session behavior
```

Inspect shared modifications including:

```text
frontend/lib/app/router/app_route_paths.dart
frontend/lib/app/router/app_router.dart
frontend/lib/features/institution_admin/presentation/institution_admin_shell.dart
frontend/lib/features/institution_admin/presentation/institution_admin_users_screen.dart
shared ApiErrorCodes/failure infrastructure
```

Confirm no later Stage 4 task invalidated earlier Stage assumptions.

---

# 24. Findings Severity

Use only:

## `P1`

Security, tenant isolation, protected-data exposure, secret exposure, or core public-contract breach.

Examples:

- stale previous-session tenant data visible;
- foreign/direct identifier widens access;
- token/private payload exposure;
- frontend sends trusted tenant authority;
- core approved route/API contract is materially wrong.

## `P2`

Material functional, architecture, state, routing, lifecycle, mutation-outcome, accessibility, build, or regression defect blocking the checkpoint.

Examples:

- full test/analyze/build failure caused by Stage 4;
- stale async result overwrites current state;
- uncertain mutation shown as confirmed;
- duplicate competing cache/router/client/state owner;
- failed reconciliation leaves stale active actions/data;
- broken route order/direct entry;
- optimistic false authoritative row/count state;
- critical keyboard/focus/overflow failure;
- missing critical test evidence.

## `P3`

Non-blocking maintainability, clarity, or test-quality improvement without current security/contract/functional impact.

Do not invent findings to populate severity.

For every finding record:

```text
ID
severity
concise title
exact file/location
evidence
violated approved behavior
impact
minimal remediation direction
```

---

# 25. Verdict

Use exactly one:

```text
PASS
NOT ACCEPTED
```

## PASS requires

- every entry condition passes;
- complete Stage 4 frontend delta reviewed;
- `P1 = 0`;
- `P2 = 0`;
- full frontend suite passes;
- static analysis passes;
- format check passes;
- Windows build passes;
- no unresolved architecture/API/session/routing/state/cache/accessibility/cross-task conflict;
- required Stage 4 frontend criteria have evidence;
- final repository remains clean/read-only.

P3 may accompany PASS when genuinely non-blocking.

## NOT ACCEPTED

Use when:

- any P1 or P2 exists;
- required verification fails because of candidate implementation;
- a required criterion lacks sufficient evidence;
- entry conditions do not permit a valid review;
- the review cannot establish the required correctness/safety boundary.

Do not fix findings during this checkpoint.

If NOT ACCEPTED:

1. preserve evidence;
2. ChatGPT prepares focused fix contract(s);
3. Codex implements, verifies, and delivers fixes;
4. rerun affected checkpoint checks;
5. obtain PASS before Stage integration planning.

---

# 26. Required Evidence Report From Codex

Codex returns evidence only. ChatGPT assigns findings/severity and final verdict.

Required report:

1. **Repository preflight**
   - branch;
   - local main SHA;
   - origin/main SHA;
   - expected audited SHA match;
   - baseline verification;
   - ahead/behind;
   - clean status;
   - origin identity.

2. **Delta inventory**
   - all changed frontend files from baseline;
   - task/orchestration files separately;
   - unexplained scope, if any;
   - package/lock/platform/backend/docs changes.

3. **Route/shell evidence**
   - all four Stage 4 frontend routes;
   - static/dynamic ordering;
   - approved-location classification;
   - shell destination/title;
   - direct-entry safety.

4. **Architecture/API evidence**
   - feature/layer placement;
   - Dio/DTO/repository/controller boundaries;
   - exact consumed endpoints;
   - no duplicate client/router/cache/state architecture.

5. **State/session/cache evidence**
   - session/target/generation ownership;
   - retained Group query/stale behavior;
   - Group action arbitration;
   - membership projection behavior;
   - Parent–Student cross-perspective behavior;
   - no stale-authoritative state.

6. **Mutation evidence**
   - Group create/edit/archive uncertainty;
   - assignment/remove uncertainty;
   - connect/disconnect uncertainty;
   - no automatic replay;
   - confirmed outcome vs projection-read failure separation.

7. **Security/privacy evidence**
   - no tenant selector;
   - session clearing;
   - existence-private handling;
   - no sensitive/raw error exposure.

8. **Accessibility/responsive evidence**
   - relevant deterministic tests;
   - code-review observations;
   - any unverified surface.

9. **Verification**
   - exact Flutter/Dart commands;
   - exact exit codes;
   - full test totals and duration;
   - skipped tests;
   - analyze result;
   - format result;
   - Windows build result.

10. **Final repository state**
    - diff check;
    - status;
    - HEAD/origin SHA;
    - ahead/behind;
    - explicit statement that no tracked file was modified/staged/committed/pushed/merged.

Codex must not provide the authoritative `PASS`/`NOT ACCEPTED` verdict.

It may finish with:

```text
EVIDENCE COLLECTION COMPLETE
```

or:

```text
EVIDENCE COLLECTION BLOCKED
```

---

# 27. ChatGPT Final Review Record

ChatGPT produces the official checkpoint record in this order:

1. **Verdict:** `PASS` or `NOT ACCEPTED`;
2. findings ordered P1, P2, P3, or explicit `No findings`;
3. audited `origin/main` SHA;
4. frontend baseline SHA;
5. task inventory FE-001…005 and delivery evidence;
6. scope/delta assessment;
7. architecture/responsibility assessment;
8. routing/shell assessment;
9. API/DTO/error/transport assessment;
10. session/security/tenant/privacy assessment;
11. async/state/cache/mutation assessment;
12. accessibility/focus/responsive assessment;
13. previous-Stage regression assessment;
14. exact verification results;
15. final Git cleanliness;
16. next gate.

If PASS, next permitted gate:

```text
Stage 4 Integration Planning / Decomposition
```

Frontend implementation delivery is already complete and must not be repeated.

This checkpoint does not itself authorize Stage closure.

---

# 28. Official Verdict Record

Not populated during preparation.

```text
Verdict: Pending
P1: Pending
P2: Pending
P3: Pending

Audited origin/main:
<pending S04-FE-005 delivery>

Stage 4 frontend baseline:
1bc138a29250f575bc000c4be3e22d72f5b68e55

Full frontend suite:
Pending

Static analysis:
Pending

Format check:
Pending

Windows build:
Pending

Final Git state:
Pending
```

Populate the official record only after:

```text
S04-FE-005 Accepted / Delivered
entry gate PASS
read-only evidence collection complete
ChatGPT final review complete
```
