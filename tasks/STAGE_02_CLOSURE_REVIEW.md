# Stage 2 Closure Review — Multi-Institution Platform Management

## 1. Closure Metadata

| Field | Value |
|---|---|
| Review ID | `STAGE-02-CLOSURE` |
| Roadmap stage | `Stage 2 — Multi-Institution Platform Management` |
| Review contract status | `Approved` |
| Review mode | `Read-only stage-wide audit → post-PASS closure bookkeeping/delivery` |
| Stage index | `tasks/STAGE_02_TASK_INDEX.md` |
| Required final task | `S02-INT-001 — Stage 2 Windows Real-Stack End-to-End Verification` |
| Required evidence | `tasks/integration/stage-02/S02-INT-001-stage-02-e2e-evidence.md` |
| Proposed verdict | `Stage closed` |

This closure review is approved in advance but remains dormant until every
Stage 2 task, including `S02-INT-001`, is `Accepted`, has review `PASS`, and is
delivered to `origin/main`.

The human-observable Windows smoke is only one input to `S02-INT-001`. A smoke
`PASS` does not by itself activate this closure review. `S02-INT-001` must first
complete its read-only Phase 2 gate, GitHub delivery, merge, synchronization,
and final `ACCEPTED` classification.

This file defines the closure audit. It does not itself mean Stage 2 is closed.

---

## 2. Purpose

Determine from current repository evidence whether Stage 2 is genuinely
complete and may become a stable dependency for Stage 3.

The audit must evaluate Stage 2 as one integrated Platform Owner vertical:

```text
Flutter Windows Platform Owner UI
→ Riverpod session and feature state
→ repository/data-source boundary
→ Dio and typed API failures
→ Laravel /api/v1/platform/**
→ Sanctum and protected middleware
→ PostgreSQL Institution/User/Settings state
```

Individual task acceptance and the final E2E task are strong evidence, but they
do not replace the independent stage-wide contract, scope, delivery, and
Definition-of-Done audit.

The review must detect:

- a missing roadmap acceptance criterion;
- cross-task backend/frontend disagreement;
- accepted implementation that conflicts with locked `docs/01–09`;
- missing server-side authorization or multi-Institution protection;
- unsafe lifecycle, mutation, or stale-session behavior;
- incomplete or unsanitized real-stack evidence;
- an accepted task not actually present on `origin/main`;
- stale task/index/README bookkeeping;
- a regression in Stage 1 authentication, first-login, role, device, or
  session-isolation behavior;
- hidden Stage 3+ implementation or product scope;
- closure bookkeeping that would overstate actual delivery.

---

## 3. Authority and Required Inputs

Codex must read and inspect:

1. root `AGENTS.md`;
2. `backend/AGENTS.md`;
3. `frontend/AGENTS.md`;
4. this complete closure contract and owner-supplied chat execution instruction;
5. locked `docs/01–09` sections governing Stage 1 and Stage 2;
6. `docs/06-roadmap.md` sections:
   - `3. Stage Structure and Definition of Done`;
   - `7. Stage 2 — Multi-Institution Platform Management`;
7. applicable authentication, authorization, Flutter, testing, PostgreSQL,
   and local-runtime sections of `docs/07-architecture.md`;
8. applicable Institution, User, Role, Institution Settings, ownership, and
   history sections of `docs/08-database.md`;
9. applicable authentication, stable-error, Platform dashboard, Institution,
   and Institution Admin sections of `docs/09-api-contracts.md`;
10. `tasks/README.md`;
11. `tasks/STAGE_01_CLOSURE_REVIEW.md` and proof that Stage 1 remains closed;
12. `tasks/STAGE_02_TASK_INDEX.md`;
13. all seventeen Stage 2 task contracts and their final lifecycle records;
14. current accepted backend/frontend code, migrations, config, and tests;
15. current Git history, remote, branch, and worktree state;
16. `S02-INT-001-stage-02-e2e-evidence.md`;
17. the accepted human Windows smoke attestation;
18. current CI/check evidence and task delivery evidence.

Authority order:

```text
locked docs/01–09
→ applicable AGENTS.md
→ truthful Stage 1/Stage 2 control files
→ approved Stage 2 task contracts
→ current accepted origin/main implementation and evidence
→ owner-supplied chat execution instruction
```

Locked documents outrank task files. A prior task `PASS` does not override a
locked contract.

---

## 4. Stage 2 Task Inventory

All seventeen tasks must be `Accepted`, review `PASS`, and delivery `Delivered`
on `origin/main`.

### Backend

```text
S02-BE-001 — Platform Institution List/Detail API
S02-BE-002 — Platform Institution Create API
S02-BE-003 — Platform Institution Update API
S02-BE-004 — Platform Institution Lifecycle and Access Enforcement
S02-BE-005 — Platform Dashboard Aggregate API
S02-BE-006 — Platform Institution Admin List/Create API
S02-BE-007 — Platform Institution Admin Update/Lifecycle API
```

### Frontend

```text
S02-FE-001 — Platform Owner Desktop Shell and Navigation
S02-FE-002 — Platform Dashboard Real Data and States
S02-FE-003 — Platform Institution List/Search/Filters/Pagination
S02-FE-004 — Platform Institution Detail and Basic Usage
S02-FE-005 — Platform Institution Create Form and Mutation
S02-FE-006 — Platform Institution Basic-Information Edit Flow
S02-FE-007 — Platform Institution Lifecycle Actions
S02-FE-008 — Platform Institution Admin List/Create UI
S02-FE-009 — Platform Institution Admin Update/Lifecycle UI
```

### Integration

```text
S02-INT-001 — Stage 2 Windows Real-Stack End-to-End Verification
```

The review must verify that no approved task was skipped, no unresolved task
remains, and no unapproved task was silently inserted to expand Stage 2.

---

## 5. Activation and Git Preflight

Do not begin the audit unless repository evidence proves:

```text
Stage 1 = Closed
all 17 Stage 2 tasks = Accepted / PASS / Delivered
S02-INT-001 accepted result and sanitized evidence are on origin/main
local main == origin/main
working tree clean except the sole owner-prepared closure-review file, when applicable
origin = https://github.com/Shoxrux2017/testlabuz.git
```

No Stage 2 task may remain `Approved`, `In Progress`, `NOT ACCEPTED`,
`DELIVERY BLOCKED`, `Fix Required`, `Not started`, or any equivalent unresolved
state.

Required review branch:

```text
review/stage-02-closure
```

If the owner pre-saved exactly:

```text
tasks/STAGE_02_CLOSURE_REVIEW.md
```

on local `main`, treat only that file as the permitted preparation addition.
Do not commit it on `main`. Create the review branch immediately and carry
it onto it.

If any other dirty or untracked path exists, stop and report exact evidence.
Do not clean, discard, or absorb unrelated user work.

GitHub CLI is not a precondition for branch creation, audit, bookkeeping,
ordinary Git commit, or ordinary `git push`. PR creation may use the available
connector or a manual link after push.

---

## 6. Exact Roadmap Acceptance Matrix

The locked Stage 2 acceptance criterion is:

> A Super Admin can create and control multiple institutions without directly
> participating in their daily teaching workflow.

The review must decompose it and mark every row `PASS`.

| Stage 2 outcome | Required evidence |
|---|---|
| Platform Owner reaches the approved Windows desktop shell. | Stage 1 role/device baseline + Stage 2 route/UI/E2E evidence |
| Dashboard shows real bounded platform data. | API/Flutter tests + real-stack evidence |
| Multiple Institutions can be listed, searched, filtered, sorted, and paginated. | Backend/Flutter coverage + real Windows E2E |
| Institution detail exposes approved basic information and usage counts only. | Response allowlists + UI tests + E2E |
| Platform Owner can create an Institution safely. | Atomic API/settings tests + UI/E2E |
| Platform Owner can edit only allowed basic Institution fields. | Request allowlists + changed-fields-only UI behavior |
| Platform Owner can activate/deactivate without deleting history. | Lifecycle/access/data-retention evidence |
| Institution-user access is blocked while Institution is inactive. | Middleware/API/E2E evidence |
| Reactivation restores only otherwise-eligible access. | Active-user/inactive-user/first-login evidence |
| Platform Owner can list/create/edit/activate/deactivate Institution Admin accounts only in the selected Institution. | API/UI/E2E and tenant-scope evidence |
| New Institution Admin retains mandatory first-login password change. | Auth/API/UI/real-stack evidence |
| Platform routes reject all four Institution roles. | Complete authorization matrix |
| Platform API/UI does not leak learning, credential, creator, settings-policy, token, password, or unrelated tenant data. | Response allowlists, negative tests, scope audit |
| Platform Owner does not change submissions, scores, Teacher content, or daily teaching state. | Route/UI/scope audit |
| No normal hard-delete Institution flow exists in the MVP. | Routes, controllers, UI, tests, history audit |

Any missing or partially verified row blocks closure.

---

## 7. Accepted Stage 2 Public Surface

The stage-wide audit must reconcile the accepted twelve-endpoint surface:

```text
GET   /api/v1/platform/dashboard

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

All remain protected in the accepted middleware order:

```text
auth:sanctum
→ active.account
→ password.changed
→ role:platform_owner
```

The closure audit must verify that no Stage 2 public/debug/test endpoint was
added outside the approved surface and no required endpoint is missing.

---

## 8. Backend and API Contract Audit

Verify current `origin/main`, not only task reports.

### 8.1 Dashboard

Verify:

- Institution totals are server-calculated and internally consistent;
- User totals use accepted account-state semantics;
- recent Institutions are bounded to five and ordered deterministically by
  `created_at DESC, id DESC`;
- empty and partial-empty states are valid;
- no invented billing, health, attention, activity-event, learning, or
  per-role analytics were introduced;
- queries are bounded and avoid unapproved in-memory aggregation/N+1 behavior.

### 8.2 Institution list and detail

Verify:

- strict query allowlist;
- server-side search, status/type filters, approved sorting, directions, and
  pagination;
- approved page-size behavior and backend maximum;
- literal `%` and `_` search behavior;
- response allowlists expose only approved public fields and user counts;
- detail and list agree on status/basic data/count semantics;
- malformed, unknown, and protected query keys fail safely;
- request bodies on GET are rejected where the accepted contract requires it;
- no protected learning data, settings policies, users, creator IDs,
  credentials, or cross-Institution data leak.

### 8.3 Institution creation

Verify:

- exact seven-field create allowlist;
- JSON-body-only validation where accepted;
- UUID and authoritative fields are server-owned;
- Institution creation and default Institution Settings initialization are
  atomic;
- default settings match the locked contract;
- rollback leaves no partial Institution/settings state;
- duplicate and concurrency behavior is safe;
- no admin, token, category, learning, or other Stage 3+ record is implicitly
  created.

### 8.4 Institution update

Verify:

- exact six-field partial-update allowlist;
- status, identity, creator, settings, counts, and lifecycle timestamps cannot
  be changed through the update payload;
- omitted fields remain unchanged;
- nullable fields follow the accepted clearing contract;
- no-op updates preserve accepted timestamp/state behavior;
- validation and not-found paths perform no mutation.

### 8.5 Institution lifecycle

Verify:

- activate/deactivate use command endpoints with empty bodies;
- lifecycle operations are idempotent and concurrency-safe;
- server state is authoritative;
- deactivation never hard-deletes or rewrites Institution/users/settings/
  tokens/history;
- inactive Institution users are blocked by `institution_inactive`;
- reactivation restores access only to individually active, password-eligible,
  correctly authorized users;
- individually inactive users remain `user_inactive`;
- mandatory password-change state remains preserved;
- unrelated Institutions remain unaffected.

### 8.6 Institution Admin management

Verify:

- list/create are scoped by path Institution;
- update/lifecycle accept only actual `institution_admin` targets;
- wrong-role and out-of-scope targets use safe not-found behavior;
- create accepts only `full_name`, `login_name`, `email`, `phone`, `password`;
- update accepts only `full_name`, `email`, `phone`;
- Institution, role, creator, status, password state, and other protected
  fields are server-owned;
- new Admin is active, belongs to the selected Institution, has role
  `institution_admin`, and has `must_change_password = true`;
- login-name and accepted uniqueness/concurrency rules remain enforced;
- lifecycle actions do not reset password, first-login state, last login,
  tokens, role, Institution, or historical rows;
- password values/hashes never appear in responses, logs, evidence, or client
  persistent state.

### 8.7 Stable errors and authorization

Verify accepted envelope/status/machine-code behavior for:

- unauthenticated request;
- inactive user;
- inactive Institution;
- first-login password gate;
- wrong role;
- resource not found;
- validation failure;
- uniqueness/domain conflict;
- rate limit and server/transport failures where applicable.

Human-readable messages must not be parsed as control flow by Flutter.

---

## 9. PostgreSQL and Data-Integrity Audit

Verify the accepted Stage 2 subset against locked database contracts:

- UUID Institutions and Users;
- Institution lifecycle/status fields and timestamps;
- Institution Settings one-to-one ownership and defaults;
- Institution Admin role and Institution ownership;
- globally unique login names and approved nullable contact behavior;
- lifecycle retains historical rows;
- no normal hard-delete path for active historical Institution data;
- activation/deactivation does not bulk-delete tokens or rewrite password
  state;
- list/detail/dashboard counts use correct persisted rows;
- transaction and row-lock behavior is present where accepted;
- no SQLite-only substitute validates PostgreSQL-specific behavior;
- testing uses isolated `testlabuz_testing`, not development data;
- no Stage 3 Teacher/Student/Parent management schema or product behavior was
  added merely to complete Stage 2.

---

## 10. Flutter Architecture and UX Audit

Verify the accepted Windows-only Platform Owner route family:

```text
/platform-owner
/platform-owner/institutions
/platform-owner/institutions/:institutionId
/platform-owner/institutions/:institutionId/edit
```

The shell navigation must contain exactly:

```text
Dashboard
Institutions
```

Institution Admin management remains embedded in Institution detail and must
not introduce an unapproved Stage 2 route.

Verify:

- `/auth/me` and backend middleware remain the authority for role/session;
- no cached role or route state grants Platform access;
- dashboard/list/detail/form states use real repositories and API data;
- loading, empty, partial-empty, error, Retry, and safe not-found states exist;
- list query state is server-driven and stale responses cannot overwrite newer
  search/filter/page state;
- create/edit forms expose only approved fields;
- Institution PATCH and Admin PATCH send changed fields only;
- a no-change edit sends no mutation;
- nullable fields can be cleared according to contract;
- lifecycle commands require confirmation;
- cancellation sends no mutation;
- duplicate in-flight submissions are prevented;
- mutations are not automatically replayed after an unknown outcome;
- confirmed success uses server-authoritative refresh/invalidation;
- no optimistic row, count, or lifecycle patch fabricates success;
- unknown outcomes reconcile with read-only GET when required;
- session, route, Institution, Admin, and action identities isolate stale
  completions;
- logout, account switch, reload, direct URL, and back navigation do not reveal
  previous Platform Owner data;
- keyboard, focus, validation, and safe feedback remain usable on Windows.

---

## 11. Security and Multi-Institution Boundary Audit

Verify:

- all Platform endpoints require authentication;
- active, password-complete Institution Admin, Teacher, Student, and Parent are
  each denied with the accepted wrong-role behavior;
- middleware precedence for inactive user, inactive Institution, mandatory
  password change, and role remains exact;
- Platform Owner has no universal bypass outside approved Platform routes;
- Institution path IDs select resources but never authorize Institution users;
- Institution Admin operations cannot escape the selected Institution;
- direct IDs and malformed targets do not expose protected existence;
- no response exposes password/hash/token/permission/creator/private settings
  or protected learning data;
- no Institution A data appears in an Institution B response or session;
- previous-session responses cannot restore old protected data after logout or
  account switch;
- test fixtures, evidence, logs, screenshots, and tracked files contain no
  credential or private data.

Any tenant leakage, session leakage, secret exposure, unsafe fixture reset, or
authorization bypass is a P1 blocker.

---

## 12. S02-INT-001 Evidence Audit

Inspect the accepted, merged evidence artifact:

```text
tasks/integration/stage-02/S02-INT-001-stage-02-e2e-evidence.md
```

It must be sanitized and prove all four required layers:

```text
A — full backend PostgreSQL regression
B — full Flutter deterministic regression
C — real Flutter Windows → Laravel/Sanctum/PostgreSQL integration
D — human-observable Windows smoke by the Project owner/operator
```

Verify evidence for:

- exact `APP_ENV=testing` and `current_database() = testlabuz_testing` guards;
- wrong-environment, wrong-database, and missing-secret refusal;
- repeatable cleanup limited to `E2E S02` / `e2e_s02_` owned fixtures;
- dashboard, Institution list/detail/create/edit/lifecycle;
- Institution-user blocking/reactivation and data retention;
- Institution Admin list/create/edit/lifecycle and first-login gate;
- wrong-role/unauthenticated/not-found/validation/disclosure matrix;
- session/account-switch isolation;
- runtime restart and persisted state;
- human validation-error recovery;
- human cancel/confirm lifecycle observations;
- logout and absence of protected Platform data;
- complete Phase 2 findings and `PASS`;
- diff, scope, secret, and locked-doc checks;
- accepted commit/PR/merge and final synchronized main.

Evidence must not include:

- passwords or hints;
- bearer tokens, cookies, or secure-storage content;
- password hashes;
- credentials, private keys, DSNs, or full environment dumps;
- sensitive API dumps;
- screenshots containing secrets.

Missing mandatory human smoke or real Windows evidence is a P2 blocker.

---

## 13. Current Quality-Gate Policy

The accepted `S02-INT-001` evidence is intentionally the final implementation
verification input for this closure review.

If all of the following are true:

- `S02-INT-001` is merged and `Accepted / PASS / Delivered`;
- its evidence refers to the accepted commit and final delivered branch state;
- `origin/main` has not received application-code changes after the verified
  Stage 2 candidate, other than truthful delivery/closure preparation;
- evidence is complete, current, sanitized, and internally consistent;

then the closure audit may treat its already-passed expensive backend,
frontend, Windows build, real-stack E2E, restart, and human-smoke runs as
authoritative. Do not repeat the human smoke merely to close the stage.

The closure audit must still perform non-writing current checks:

```text
git status --short
git diff --check
git log/history and accepted-commit reachability audit
closure preparation scope review
locked-doc diff review
secret scan of closure inputs/evidence
```

If `origin/main` application code changed after the verified candidate, the
evidence cannot be mapped to current main, or a genuine contradiction is found,
run the affected current regression/real-stack checks required to resolve the
gap. Do not use stale evidence to manufacture closure.

Any required current test, analysis, format, build, E2E, or security check that
fails blocks closure.

---

## 14. Stage Definition of Done

Evaluate every item from `docs/06-roadmap.md` section `3.2`.

| Definition-of-Done condition | Closure requirement |
|---|---|
| Approved business behavior is implemented. | PASS |
| Required backend/API behavior works. | PASS |
| Required desktop/mobile UI is connected to real data. | PASS for required Windows desktop; mobile marked explicit N/A for Stage 2 Platform Owner |
| No placeholder flow remains for the stage core path. | PASS |
| Required permissions are enforced server-side. | PASS |
| Multi-institution scope is enforced where applicable. | PASS |
| Validation and error behavior are defined. | PASS |
| Automated tests pass. | PASS |
| Static analysis/lint/format checks pass where applicable. | PASS |
| Required manual smoke tests pass. | PASS |
| No blocking regression is introduced into previous stages. | PASS |
| Relevant project documentation is updated. | PASS |
| ChatGPT review finds no unresolved blocker. | PASS |
| Stage is explicitly marked closed before Stage 3 begins. | Done only after audit PASS and closure delivery |

No required row may be waived without an explicit locked-contract reason.

---

## 15. Scope and Regression Audit

Stage 2 must not silently implement Stage 3+.

Block closure for material premature scope such as:

- Institution Admin management of Teacher, Student, or Parent accounts;
- Institution learning-settings editing UI/API;
- Groups or user relationships;
- Topics or learning materials;
- Homework, Blitz, submissions, checking, scores, results, or reports;
- billing, plans, subscriptions, quotas, revenue, or licensing;
- advanced attention, activity, health, audit, or analytics dashboards;
- Institution hard-delete/archive/suspend/merge/transfer/ownership replacement;
- MFA, SSO, advanced sessions, or device management;
- production E2E users, public test server, or debug endpoints.

Also verify Stage 1 authentication, first-login password change, role/device
routing, active-state gates, and session isolation remain green.

Verification-only guarded fixtures/tests/evidence are not product scope creep.

---

## 16. Documentation and Delivery Audit

Before closure `PASS`, verify:

- `tasks/STAGE_02_TASK_INDEX.md` lists exactly the approved 17 tasks;
- every task is `Accepted`;
- every review status is `PASS`;
- every delivery status is `Delivered`;
- all historical `DELIVERY BLOCKED` records remain preserved as history but
  are no longer the current state;
- `S02-INT-001` evidence exists on `origin/main`;
- `tasks/README.md` truthfully identifies the Stage 2 Closure Review as the
  current next gate;
- Stage 2 remains `In Progress` / `Verified, Not Closed` before audit PASS;
- no stale statement says Stage 2 is planned, unverified, already closed, or
  missing decomposition;
- locked `docs/01–09` were not edited merely to record task completion;
- every accepted task result and bookkeeping closure commit is reachable from
  `origin/main`;
- local `main == origin/main` and no accepted work exists only on an unmerged
  branch.

---

## 17. Findings and Severity

Classify findings:

- `P1` — authorization bypass, cross-Institution/session data leakage, secret
  exposure, unsafe/destructive database handling, hard-delete/history loss,
  locked security contract violation, or core real-stack failure;
- `P2` — material API/DB/UI/architecture/test/evidence/manual-smoke/GitHub
  delivery/documentation/scope mismatch;
- `P3` — non-blocking observation or follow-up risk that does not invalidate
  Stage 2.

Any unresolved P1 or P2 means:

```text
VERDICT: FIXES REQUIRED BEFORE CLOSURE
```

Do not repair a finding during this closure audit. Report it, preserve the
read-only state, and stop.

If required specification, dependency, accepted-delivery proof, or environment
cannot be verified:

```text
VERDICT: CLOSURE BLOCKED
```

---

## 18. Strict Read-Only Audit Phase

During the audit Codex must not:

- edit application code, tests, migrations, seeders, config, or dependencies;
- edit accepted task contracts or evidence;
- edit task/index/README lifecycle state;
- edit this closure verdict;
- run a formatter or auto-fix that writes;
- mutate E2E fixtures or databases merely for bookkeeping;
- stage, commit, push, create a PR, or merge;
- create or start Stage 3 work;
- self-fix after findings begin.

Choose exactly one audit verdict:

```text
AUDIT PASS — Stage 2 is ready for closure.
```

```text
FIXES REQUIRED BEFORE CLOSURE
```

```text
CLOSURE BLOCKED BY SPECIFICATION, DEPENDENCY, OR DELIVERY EVIDENCE
```

If the result is not `AUDIT PASS`, stop with no closure modification.

---

## 19. Post-PASS Closure Bookkeeping

Only after the read-only audit returns `AUDIT PASS`:

1. update this closure review with:
   - actual UTC review date;
   - audited `origin/main` commit;
   - complete task/delivery evidence summary;
   - roadmap acceptance matrix;
   - Stage Definition-of-Done matrix;
   - findings grouped P1/P2/P3;
   - final verdict `Stage closed`;
2. update `tasks/STAGE_02_TASK_INDEX.md`:
   - Stage status → `Closed`;
   - Stage closed → `Yes`;
   - closure-review state → `PASS` / delivered only after merge;
   - preserve all 17 task records and historical delivery notes;
3. update `tasks/README.md`:
   - Stage 2 → `Closed`;
   - next gate → `Stage 3 decomposition/planning`;
4. do not modify locked `docs/01–09`;
5. do not modify application code, tests, config, migrations, seeders,
   dependencies, or S02 E2E evidence;
6. do not create or start Stage 3 tasks inside this review.

If application code needs modification, the audit did not truly pass.

---

## 20. Closure GitHub Delivery

After PASS bookkeeping only:

1. run non-writing final checks:
   - `git diff --check`;
   - exact closure-scope review;
   - locked-doc diff review;
   - secret scan;
2. verify no application/test/config/dependency/evidence file changed;
3. stage only approved closure/bookkeeping paths with path-specific `git add`:

```text
tasks/STAGE_02_CLOSURE_REVIEW.md
tasks/STAGE_02_TASK_INDEX.md
tasks/README.md
```

4. never use:

```text
git add .
git add -A
git clean
```

5. create one focused closure commit with exact subject:

```text
docs(stage2): close multi-institution platform management
```

and body:

```text
Review: STAGE-02-CLOSURE
```

6. push without force:

```text
git push --set-upstream origin review/stage-02-closure
```

7. verify the remote branch points exactly to the closure commit;
8. create a PR to `main` through the available connector;
9. if PR creation is unavailable or returns `403`, provide the manual link:

```text
https://github.com/Shoxrux2017/testlabuz/pull/new/review/stage-02-closure
```

and report `FINAL STATUS: DELIVERY BLOCKED` without classifying the audit as a
failure;
10. never bypass branch protection or required checks;
11. merge only when safe and green;
12. synchronize local `main` using safe fast-forward-only operations;
13. verify:
    - closure commit is reachable from `origin/main`;
    - local `main == origin/main`;
    - working tree is clean;
    - Stage 2 closure record is present on `origin/main`.

Stage 2 is not formally closed until closure bookkeeping is merged and final
delivery is verified.

---

## 21. Final Closure States

Return exactly one:

```text
FINAL STATUS: STAGE CLOSED
```

```text
FINAL STATUS: FIXES REQUIRED BEFORE CLOSURE
```

```text
FINAL STATUS: CLOSURE BLOCKED
```

```text
FINAL STATUS: DELIVERY BLOCKED
```

`STAGE CLOSED` is valid only when:

- all 17 tasks are `Accepted / PASS / Delivered`;
- the read-only audit passed with no unresolved P1/P2;
- the exact roadmap acceptance matrix passed;
- the Stage Definition of Done passed;
- closure bookkeeping was committed and merged to `origin/main`;
- local `main == origin/main`;
- the working tree is clean;
- Stage 2 is recorded `Closed / Stage closed: Yes`;
- Stage 3 implementation was not started.

---

## 22. Next Gate

Only after:

```text
FINAL STATUS: STAGE CLOSED
```

Stage 3 becomes eligible for decomposition/planning:

```text
Stage 3 — Institution Administration and User Management
```

Do not automatically create, approve, or implement Stage 3 tasks during this
closure review.

---

## 23. Required Codex Closure Report

Return:

1. exact final status;
2. repository, remote, review branch, local/main/origin hashes, and clean-state
   evidence;
3. all 17 task lifecycle/delivery results;
4. findings ordered P1 → P2 → P3;
5. exact Stage 2 roadmap acceptance matrix;
6. Stage Definition-of-Done matrix;
7. twelve-endpoint API and middleware audit;
8. dashboard aggregate/recent-Institution audit;
9. Institution list/detail/create/update/lifecycle audit;
10. Institution Settings initialization and retention audit;
11. Institution Admin list/create/update/lifecycle and first-login audit;
12. PostgreSQL/data-integrity audit;
13. authorization, middleware precedence, and multi-Institution disclosure
    audit;
14. Flutter route/navigation/data-state/form/mutation/stale-session audit;
15. Stage 1 regression result;
16. `S02-INT-001` automated, real-stack, restart, evidence, and human-smoke
    audit;
17. current quality-gate evidence mapping to audited `origin/main`;
18. scope/Stage 3 exclusion audit;
19. documentation/bookkeeping/history audit;
20. if audit PASS:
    - changed closure files;
    - commit SHA and exact message;
    - remote branch verification;
    - PR and checks;
    - merge commit and parents;
    - final local/main/origin hashes;
    - final clean status;
21. next gate;
22. explicit confirmation:

```text
Stage 3 implementation was NOT started.
```

Do not fix implementation findings inside this closure review.

---

## 24. Completed Closure Review Record

| Field | Result |
|---|---|
| Actual review date | `2026-08-13` |
| Review completed at | `2026-08-13T12:43:27Z` |
| Review branch | `review/stage-02-closure` |
| Audit verdict | `AUDIT PASS — Stage 2 is ready for closure.` |
| Closure verdict | `Stage closed` |
| Audited `origin/main` | `8b43abc614fdd5c66760c4f26f48aab4e8947f9d` |
| Scope | This closure review, the Stage 2 task index, and task README bookkeeping only |

The closure verdict becomes formally delivered only after this bookkeeping is
merged to `origin/main` and the final local/main/origin synchronization checks
pass.

### 24.1 Owner-Authorized Operational Correction

| Check | Result |
|---|---|
| Original closure-contract SHA-256 | `9C9F5F81780420C0A76EF2F2C88208065716833A0CF8EE13FFCF1F61C2F12385` |
| Corrected closure-contract SHA-256 before audit bookkeeping | `F5CBDA07FC3DA097854E51E18F3FA91B58B8023A174068CA9CB6C8C2DF060AA4` |
| Correction scope | `PASS` — only execution-prompt storage references changed |

The correction replaced repository-backed matching-prompt references with the
owner-supplied chat execution instruction, changed preflight wording to the
sole owner-prepared closure-review file, removed the intentionally absent
prompt path from permitted file lists, and made final delivery scope exactly
the three authorized bookkeeping files. No Stage 2 acceptance, security,
quality, audit, or delivery requirement changed.

### 24.2 Git Preflight and Audit State

- Approved origin: `https://github.com/Shoxrux2017/testlabuz.git`.
- Before the renewed audit, local `main`, `origin/main`, and the required
  accepted main all equaled
  `8b43abc614fdd5c66760c4f26f48aab4e8947f9d`.
- The existing `review/stage-02-closure` branch had no commit absent from
  `origin/main`; it was fast-forwarded only to current `origin/main`.
- Audit `HEAD` equaled current `origin/main`; the corrected closure review was
  the sole untracked path and was unstaged.
- The read-only audit made no edit, stage, commit, push, merge, database
  mutation, test rerun, or Stage 3 change.

### 24.3 Complete Task and Delivery Matrix

| Task | Task status | Review | Delivery |
|---|---|---|---|
| `S02-BE-001` | `Accepted` | `PASS` | `Delivered` |
| `S02-BE-002` | `Accepted` | `PASS` | `Delivered` |
| `S02-BE-003` | `Accepted` | `PASS` | `Delivered` |
| `S02-BE-004` | `Accepted` | `PASS` | `Delivered` |
| `S02-BE-005` | `Accepted` | `PASS` | `Delivered` |
| `S02-BE-006` | `Accepted` | `PASS` | `Delivered` |
| `S02-BE-007` | `Accepted` | `PASS` | `Delivered` |
| `S02-FE-001` | `Accepted` | `PASS` | `Delivered` |
| `S02-FE-002` | `Accepted` | `PASS` | `Delivered` |
| `S02-FE-003` | `Accepted` | `PASS` | `Delivered` |
| `S02-FE-004` | `Accepted` | `PASS` | `Delivered` |
| `S02-FE-005` | `Accepted` | `PASS` | `Delivered` |
| `S02-FE-006` | `Accepted` | `PASS` | `Delivered` |
| `S02-FE-007` | `Accepted` | `PASS` | `Delivered` |
| `S02-FE-008` | `Accepted` | `PASS` | `Delivered` |
| `S02-FE-009` | `Accepted` | `PASS` | `Delivered` |
| `S02-INT-001` | `Accepted` | `PASS` | `Delivered` |

All historical pre-delivery and delivery-blocked entries remain preserved as
history and are not the current lifecycle state.

### 24.4 Renewed Evidence Summary

- All root/backend/frontend instructions, the complete closure contract, all
  17 task records, locked Stage 1/Stage 2 contracts, current implementation,
  tests, evidence, and Git history were inspected.
- The two findings from the historical first closure audit are resolved:
  `S02-INT-001` now has delivery-final evidence for accepted commit
  `4f2c4a16f43a0958312441a9b8b3af6d2c9c84a6`, PR `#40`, merge
  `aa223890c26bb9a5f4704c7d2efe1bd92e7786e8`, bookkeeping commit
  `90d1aaa45c20bdb8068a57f46373b8ce0760b1b5`, PR `#41`, bookkeeping merge
  `f9cb4346fcab1c61f5bb43fdcda9eaedb290ee47`, synchronized main, and current
  `Accepted / PASS / Delivered` state; `tasks/README.md` records the same state
  for all 17 tasks and named this Closure Review as the current gate.
- All Stage 2 implementation and bookkeeping merge parents from PRs `#17`
  through `#42` are reachable from audited `origin/main`.
- No locked `docs/01–09` file changed from the Stage 1 closure baseline through
  audited main.
- No backend, frontend, application, or dependency file changed after the
  verified `S02-INT-001` candidate. Later changes were truthful delivery
  documentation/evidence only.
- Current non-writing Git diff, history, scope, locked-document, reachability,
  and high-confidence secret checks passed. No credential/private-key/DSN
  disclosure was found.

### 24.5 Exact Stage 2 Roadmap Acceptance Matrix

| Stage 2 outcome | Result | Current evidence |
|---|---|---|
| Platform Owner reaches the approved Windows desktop shell. | `PASS` | Stage 1 role/device baseline, Stage 2 router/shell tests, and Windows E2E |
| Dashboard shows real bounded platform data. | `PASS` | Server aggregates, five-row deterministic recent query, Flutter states, and real-stack evidence |
| Multiple Institutions can be listed, searched, filtered, sorted, and paginated. | `PASS` | Backend/Flutter coverage and real Windows E2E |
| Institution detail exposes approved basic information and usage counts only. | `PASS` | Resource allowlists, UI tests, disclosure checks, and E2E |
| Platform Owner can create an Institution safely. | `PASS` | Atomic Institution/settings action, rollback tests, form flow, and E2E |
| Platform Owner can edit only allowed basic Institution fields. | `PASS` | Six-field server allowlist and changed-fields-only Flutter behavior |
| Platform Owner can activate/deactivate without deleting history. | `PASS` | Idempotent locked actions plus access, retention, restart, and E2E evidence |
| Institution-user access is blocked while Institution is inactive. | `PASS` | `institution_inactive` middleware/API/E2E coverage |
| Reactivation restores only otherwise-eligible access. | `PASS` | Active-user, inactive-user, password-gate, and lifecycle coverage |
| Platform Owner can manage Institution Admin accounts only in the selected Institution. | `PASS` | Scoped list/create/update/lifecycle actions, UI flows, negative tests, and E2E |
| New Institution Admin retains mandatory first-login password change. | `PASS` | Server-owned flag, auth gate/change flow, Flutter handling, and real-stack evidence |
| Platform routes reject all four Institution roles. | `PASS` | Complete 48-check wrong-role endpoint matrix |
| Platform API/UI does not leak protected or unrelated tenant data. | `PASS` | Response allowlists, not-found boundaries, session isolation, and disclosure scans |
| Platform Owner does not change daily teaching state. | `PASS` | Production route/UI/scope audit found no learning-workflow mutation surface |
| No normal hard-delete Institution flow exists in the MVP. | `PASS` | Route/action/UI/history inspection and retention tests |

The locked acceptance criterion passes: a Super Admin can create and control
multiple Institutions without directly participating in their daily teaching
workflow.

### 24.6 Stage Definition of Done

| `docs/06-roadmap.md` section 3.2 condition | Result | Reason |
|---|---|---|
| Approved business behavior is implemented. | `PASS` | All 17 approved task outcomes are accepted, delivered, and covered by the stage-wide evidence. |
| Required backend/API behavior works. | `PASS` | The exact 12-endpoint Laravel surface and stable contracts are implemented and verified. |
| Required desktop/mobile UI is connected to real data. | `PASS` — mobile `N/A` | Platform Owner is Windows desktop-only; required Flutter desktop surfaces use real repositories/API data. |
| No placeholder flow remains for the stage core path. | `PASS` | Dashboard, Institution, lifecycle, and Admin flows are authoritative end to end. |
| Required permissions are enforced server-side. | `PASS` | Authentication, active-state, password, role, ownership, and safe not-found gates are server-enforced. |
| Multi-institution scope is enforced where applicable. | `PASS` | Admin operations are path/target scoped and cross-Institution disclosure is denied. |
| Validation and error behavior are defined. | `PASS` | Strict allowlists and stable status/code/envelope handling exist across API and Flutter. |
| Automated tests pass. | `PASS` | Accepted current evidence records full backend, Flutter, and real-stack regression PASS. |
| Static analysis/lint/format checks pass where applicable. | `PASS` | Accepted current evidence records Pint, Composer validation, Flutter analyze, and format PASS. |
| Required manual smoke tests pass. | `PASS` | Project-owner Windows smoke records all 13 required observations as PASS. |
| No blocking regression is introduced into previous stages. | `PASS` | Stage 1 auth, first-login, role/device, active-state, and session isolation remain green. |
| Relevant project documentation is updated. | `PASS` | This closure change updates only the three authorized bookkeeping documents. |
| ChatGPT review finds no unresolved blocker. | `PASS` | The renewed audit found no unresolved P1/P2. |
| Stage is explicitly marked closed before Stage 3 begins. | `PASS` on delivery | Closure bookkeeping marks Stage 2 closed; formal effect requires merge and final synchronization. |

### 24.7 API, Backend, PostgreSQL, and Security Audit

- The production public Platform surface contains exactly the accepted 12
  endpoints below `/api/v1/platform`; no debug/test/Stage 3 route exists.
- Every endpoint has middleware in the accepted order:
  `auth:sanctum → active.account → password.changed → role:platform_owner`.
- Dashboard counts are server-calculated; recent Institutions are limited to
  five by `created_at DESC, id DESC`; queries are bounded and avoid N+1 reads.
- Institution list/detail use strict query rules, literal wildcard search,
  approved filter/sort/pagination behavior, public response allowlists, and
  scope-safe not-found behavior.
- Institution create/update/lifecycle use exact request allowlists, server-owned
  identity/state, atomic default-settings initialization, row locks where
  required, idempotent commands, and history-preserving transitions.
- New settings use `Asia/Tashkent`, `25 MB`, and `15 MB`; the four educational
  policy values remain unconfigured (`null`). Lifecycle preserves settings.
- Institution Admin list/create/update/lifecycle remain Institution-scoped;
  role, Institution, active/first-login state, and credentials are protected.
- PostgreSQL UUIDs, `timestamptz`, check/foreign-key/unique constraints,
  one-to-one settings ownership, transactions, and row locks match the locked
  subset. No SQLite substitute or destructive reset supports the accepted
  evidence.
- Unauthenticated, inactive-user, inactive-Institution, password-gated,
  wrong-role, validation, conflict, and not-found precedence is covered.
  Responses do not disclose credentials, tokens, creator IDs, private settings,
  learning data, or unrelated Institution data.

### 24.8 Flutter and Session Audit

- `/auth/me` and backend middleware remain role/session authority; cached route
  state cannot grant Platform access.
- The Windows Platform Owner shell has exactly `Dashboard` and `Institutions`
  navigation. Approved dashboard, Institution list/create/detail/edit/lifecycle,
  and embedded Admin management use repositories and typed API models.
- Loading, empty/partial-empty, error/Retry, validation, safe not-found,
  confirmation/cancel, and keyboard/focus paths are implemented and tested.
- List generations and session/user/Institution/Admin/action identities prevent
  stale completion from replacing newer state or exposing a previous session.
- Forms expose only approved fields; PATCH requests send changed fields only;
  no-change edits and cancelled actions send no mutation; duplicate in-flight
  submissions are blocked.
- Unknown mutation outcomes are not replayed automatically or fabricated
  optimistically; required lifecycle/Admin cases reconcile through read-only
  authoritative GETs. Password input is transient and explicitly wiped.

### 24.9 Stage 1 Regression, S02-INT-001, and Quality Evidence

- Stage 1 remains closed. Authentication, mandatory first-login password
  change, role/device routing, active-state gates, logout/account switching,
  and stale-session isolation remain covered by current tests and Stage 2 E2E.
- `S02-INT-001` evidence proves all four required layers: full Laravel against
  PostgreSQL, full deterministic Flutter regression, real Flutter Windows to
  Laravel/Sanctum/PostgreSQL integration, and Project-owner observable smoke.
- Runtime guards require loopback, `APP_ENV=testing`, and
  `current_database() = testlabuz_testing`; wrong environment/database and
  missing secrets fail closed. Owned fixtures are repeatable and isolated.
- Real-stack mutation, authorization/disclosure, persistence after backend and
  Windows-process restart, account switching, and all 13 human smoke groups
  passed.

| Accepted quality evidence | Result |
|---|---|
| `php artisan test` in the Docker PostgreSQL runtime | `PASS` — 146 tests, 6,709 assertions |
| `vendor/bin/pint --test` | `PASS` — 121 files |
| `composer validate --strict` | `PASS` |
| `flutter analyze` | `PASS` — no issues |
| `flutter test` | `PASS` — 389 tests |
| Dart format check | `PASS` — 158 files, zero changed |
| `flutter build windows --debug` | `PASS` |
| Real Windows E2E and restart verification | `PASS` |
| Project-owner human Windows smoke | `PASS` — 13 of 13 groups |

These expensive checks were not rerun during closure because no application or
dependency file changed after their verified candidate and no contradiction
was found.

### 24.10 Findings

| Severity | Result |
|---|---|
| `P1` | None. |
| `P2` | None. Both historical first-audit P2 documentation findings are resolved. |
| `P3` | The Stage 1 closure's historical non-blocking observation remains: a bare unauthenticated `/api/v1/auth/me` request without the locked `Accept: application/json` default may follow Laravel's redirect path. All supported API/Flutter/E2E requests send the required header; no Stage 2 closure impact was found. |

### 24.11 Scope, History, and Final Audit Verdict

- No Teacher/Student/Parent management, Groups, learning settings UI, Topics,
  materials, assessments, results, reports, billing, advanced session, public
  debug/E2E, or other Stage 3+ production scope was found.
- Stage 3 task files, routes, schemas, and implementation were not created.
- No application code, tests, config, migrations, dependencies, S02 evidence,
  or locked docs were modified by closure bookkeeping.
- Closure bookkeeping is limited to
  `tasks/STAGE_02_CLOSURE_REVIEW.md`,
  `tasks/STAGE_02_TASK_INDEX.md`, and `tasks/README.md`.

```text
AUDIT PASS — Stage 2 is ready for closure.
```

```text
Stage 3 implementation was NOT started.
```
