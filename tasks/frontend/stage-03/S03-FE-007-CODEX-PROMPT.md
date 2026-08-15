# Codex Execution Prompt — S03-FE-007

Execute only:

```text
S03-FE-007 — Institution User Edit and Lifecycle UI
```

Repository:

```text
G:\project\testlabuz
```

Detailed task:

```text
tasks/frontend/stage-03/S03-FE-007-institution-user-edit-lifecycle.md
```

Branch:

```text
task/s03-fe-007-institution-user-lifecycle
```

The complete detailed task is authoritative. Read it fully before doing
anything. This prompt controls execution and does not replace or shorten the
task.

## 1. Authority and Dependency Gate

Read completely, in this order:

1. root `AGENTS.md`;
2. `frontend/AGENTS.md`;
3. this prompt and the complete S03-FE-007 detailed task;
4. `tasks/README.md` and `tasks/STAGE_03_TASK_INDEX.md`;
5. accepted S03-INT-001 task/control record;
6. relevant locked docs 02–09 sections named by the task;
7. accepted S03-BE-003/004/005 tasks, implementation, tests, review, and
   delivery evidence;
8. delivered S03-FE-001/002/004/005/006 tasks, implementation, tests, and
   delivery evidence;
9. Stage 2 Platform Admin mutation code/tests only as structural reference.

Direct dependencies are exactly:

```text
S03-FE-006
S03-BE-005
```

FE005 is a transitive predecessor through FE006, not a third direct dependency.

At preparation time BE005 was delivered, but FE006 and its frontend
predecessors were not. Do not infer current delivery from this prompt.
Production implementation is blocked unless FE006 and BE005 are independently
`Accepted / PASS / Delivered` on current `origin/main`.

If a dependency is missing, return `FINAL STATUS: BLOCKED`. If locked docs,
accepted backend, the detailed task, or delivered frontend contracts conflict,
stop and report exact sections. Do not edit, guess, repair predecessor scope,
or invent a reconciliation.

## 2. Phase 0 — Strict Read-Only Preflight

Before implementation:

1. Verify the detailed task status is `Approved`.
2. Verify the expected GitHub origin and fetch safely.
3. Prove clean local `main == origin/main`.
4. Prove FE006 and BE005 are Accepted/PASS/Delivered on that main.
5. Prove delivered FE001 route grammar, FE002 Dashboard three-total contract,
   FE004 shared User/list/retained-query/stale hook, FE005 detail/read/not-found
   hook, and FE006 create/navigation/stale behavior exist and agree with the
   task.
6. Prove the worktree is clean except only owner-prepared FE007 task/prompt
   files if not yet committed.
7. Record this prompt's SHA-256 for byte comparison before Phase 3.
8. Resolve actual feature/test paths and affected predecessor tests.
9. Preserve unrelated user work and stop on dirty/conflicting/unsafe Git state.
10. Only after every gate passes, create/switch to the exact task branch from
    approved current main.

Do not commit, push, create a PR, merge, or mark Accepted before Phase 2 PASS.

## 3. Exact Goal and Boundary

Add safe profile Edit and confirmed Activate/Deactivate only to the delivered
Institution Admin User detail screen for own-Institution Teacher, Student, and
Parent resources.

Use exactly:

```text
PATCH /api/v1/institution/users/{user}
POST  /api/v1/institution/users/{user}/activate
POST  /api/v1/institution/users/{user}/deactivate
```

Flutter submits one explicit intent. Backend owns tenant/role authorization,
validation, row locking, no-op, timestamps, stored tokens, login/access,
first-login state, relationships, and history.

Implement no backend/schema/docs/package/core/auth/Platform/router/shell,
password-reset, Group/relationship, settings/category, Learning, Stage 4, or
Stage 3 closure behavior.

## 4. Exact Target, Route, and Session Ownership

The only approved route remains:

```text
/institution-admin/users/:userId
```

The only target is the already-decoded FE001-validated canonical UUID path
parameter representing the same UUID as the current confirmed FE005 detail
resource ID. Allow only hexadecimal case differences exactly as FE005 does;
reject a different UUID.

Preserve exactly:

- `/users/new` remains create and sends no detail/mutation request;
- malformed/noncanonical/encoded-separator/whitespace/extra-path locations use
  FE001 safe fallback, build no detail screen, and send no request;
- an FE001-valid UUID reaches backend scope-safe 404 when unknown, foreign, or
  disallowed-role;
- no route/path/name/helper/order/grammar/shell change.

No control or request is allowed unless current session is authenticated,
active according to accepted bootstrap, role `institution_admin`, password
complete, Institution active/non-null, desktop-route eligible, and FE005 has
current confirmed data.

Bind each action and completion to:

```text
session user id
session User object identity
session Institution id
exact route UUID
confirmed resource id
edit|activate|deactivate kind
operation generation
controller not disposed
```

Only the latest exact key may publish data/error/feedback, replace detail,
invalidate current-session providers, close a current dialog, restore focus, or
navigate. Target change, logout, bootstrap, account/Institution/role switch,
password requirement, route exit, disposal, or newer operation makes every old
PATCH/POST/GET completion stale.

## 5. Exact Shared User Contract

Reuse the exact delivered FE004 shared model/parser. Do not create a second or
looser User model.

The resource has exactly these 12 keys; JSON order is irrelevant:

```text
id, role, full_name, login_name, email, phone, is_active,
must_change_password, last_login_at, deactivated_at, created_at, updated_at
```

Require exact types/nullability, canonical UUID, allowed role, valid UTC
timestamps, and lifecycle pair:

```text
active   -> deactivated_at = null
inactive -> deactivated_at = non-null
```

Reject missing/extra/renamed/protected/unknown keys. Never model/render/log
Institution/creator, password/hash, tokens, permissions, settings,
relationships, Groups, answers, scores, results, or Learning data.

Every mutation response ID must represent the same UUID as both immutable
selected target and route target, allowing only FE005-approved case differences.
Target mismatch is unprovable outcome, never success.

Require immutable `role`, `login_name`, and `created_at` to match the selected
snapshot. Validate other current fields by type/invariant, but do not overwrite
them from the old snapshot or reject legitimate serialized concurrent changes.

## 6. Exact Edit Form

Open `Edit user` only from current confirmed detail. Exactly three editable
fields in this order:

```text
Full name *
Email
Phone
```

No role, login, password, lifecycle, first-login, tenant, creator, timestamp,
token, permission, relationship, Group, or Learning control.

Length uses `String.runes.length`.

Apply exactly:

- full name: trim; required non-empty; maximum 200;
- email: optional; exact empty maps to null only when initial was non-null;
  initial null plus empty is unchanged; non-empty is not trimmed/rewritten;
  whitespace invalid; permissive one-@ early validation; maximum 254;
- phone: optional; exact empty maps to null only when initial was non-null;
  initial null plus empty is unchanged; non-empty is trimmed; whitespace-only
  non-empty invalid; maximum 50 after trim.

Use exact local messages from task Section 7.2. Backend remains authoritative.

Compare normalized draft to immutable initial resource and send only changed
keys. Explicit null clears email/phone. Never send `{}`, unchanged, protected,
or unknown fields.

No effective change:

```text
zero PATCH
dialog remains open
feedback = No user changes to save.
```

Cancel/close/Escape before submit sends nothing, clears action/form/errors,
closes, and restores focus. During submission/reconciliation, block normal
dismissal and all duplicate/conflicting actions; unavoidable route exit makes
completion stale.

## 7. Exact PATCH Request and Confirmed Success

Send exactly:

```text
Method: PATCH
Path: /api/v1/institution/users/{exact-current-uuid}
Content type: application/json
Query: none
Body: non-empty changed-fields object only
Tenant selector/header: none
Idempotency-Key: none
Automatic retry/replay: none
```

Use repository/data source/configured Dio. Widget must not call Dio/build URLs.
One valid explicit intent sends at most one PATCH.

Confirmed edit-request success requires:

```text
HTTP 200 exactly
top-level keys exactly data + message
message exactly Institution user updated successfully.
strict shared 12-field resource
response target represents the same UUID under FE005 case-equivalence rules
role, login_name, and created_at match the selected snapshot
every submitted field equals intended normalized value
valid lifecycle pair
```

Any unexpected 2xx/redirect/non-contract status or malformed/extra/wrong
success envelope/message/resource, target mismatch, submitted-field mismatch,
or lifecycle mismatch is unprovable because the PATCH may have committed.
Exact accepted 4xx errors follow Section 10 instead.

Only exact direct success may:

1. replace current FE005 detail with returned resource;
2. mark FE004 Users stale while preserving retained query/search/filter/sort/
   page-size state;
3. leave FE002 Dashboard untouched;
4. close/clear dialog;
5. show/announce `User updated successfully.`;
6. restore safe current focus.

Never patch list row/order/filter/page/count optimistically.

## 8. Exact Lifecycle Confirmation and Request

Confirmed active User shows Edit + Deactivate. Confirmed inactive User shows
Edit + Activate. No action in loading/error/not-found/stale/ineligible state.

Deactivate confirmation must say access/login is blocked while credentials,
Institution binding, relationships, and history are not deleted.

Activate confirmation must say only active state changes: no password reset,
first-login clearing, session/token creation, role change, or inactive-
Institution bypass. Normal sign-in and authorization requirements continue.

Cancel/close/Escape before confirm sends zero POST. Include no reason, status,
is_active, IDs, Institution, role, password, first-login, force, timestamp,
ETag, or version.

Send exactly one state-appropriate body-less command:

```text
POST /api/v1/institution/users/{uuid}/activate
or
POST /api/v1/institution/users/{uuid}/deactivate

Query: none
Body: zero bytes; pass no data argument, {}, JSON null, or form data
Tenant selector/header: none
Idempotency-Key: none
Automatic retry/replay: none
```

Backend also accepts `{}`, but FE007 standardizes on zero request-body bytes.
Prove it in data-source tests.

Confirmed lifecycle-request success requires exact 200, exact `data + message`,
strict shared resource, matching target, unchanged immutable
`role/login_name/created_at`, and:

```text
activate:
  message = Institution user activated successfully.
  is_active = true
  deactivated_at = null

deactivate:
  message = Institution user deactivated successfully.
  is_active = false
  deactivated_at = valid non-null UTC timestamp
```

Unexpected 2xx/redirect/non-contract status or malformed/mismatched success
envelope/message/resource/target/desired state is unprovable. Exact accepted
4xx errors follow Section 10.

Exact direct success only:

1. replace current FE005 detail from returned resource;
2. mark FE004 Users stale without losing retained query;
3. leave FE002 Dashboard untouched because activation/deactivation changes no
   role total and each role total includes active and inactive Users;
4. close/clear confirmation;
5. show/announce `User activated successfully.` or
   `User deactivated successfully.`;
6. restore safe current focus.

Never optimistically alter status, deactivated timestamp, list, filter, page,
count, token, or access state.

## 9. Direct-Success-Only and Unprovable Outcomes

Only the original PATCH/POST exact accepted 200 response proves mutation
request success.

A later GET can prove only current server state. It cannot prove this client
request caused that state because another administrator/concurrent operation
may have produced the same values. Never convert reconciliation into success.

Definite no-send/rejection includes only:

- local validation/no-change/cancel before request;
- exact 401/authentication_required;
- exact actor-state/password/forbidden 403 codes;
- exact 404/resource_not_found;
- exact 422/validation_failed;
- exact 429/rate_limited;
- a future exact documented 409 may be generic rejection, but BE005 defines no
  normal 409 for these endpoints.

Never branch on human messages.

After a valid mutation starts, treat as unprovable:

```text
connection/send/receive/transform timeout
connection loss or unknown/cancelled transport without proven pre-send state
500 or another 5xx
unexpected 2xx, redirect/non-contract status, or malformed HTTP result
malformed/extra/mismatched exact-200 response
```

A 5xx is unprovable because persistence may have committed before response
generation failed.

Never automatically replay PATCH/POST and never show a mutation Retry button.

While the same key remains current, issue at most one exact read-only FE005
detail request:

```text
GET /api/v1/institution/users/{same-uuid}
query = none
body = zero bytes
tenant selector = none
```

Reuse FE005 repository, strict envelope/parser/target/error rules. No second
GET, polling, automatic Refresh, or mutation replay. Do not change FE004 visible
or retained query.

If current resource is returned, it may replace current FE005 read state. For
matching submitted fields/desired lifecycle, show only:

```text
Current server state matches your requested values, but this request result
could not be confirmed.
```

Mismatch shows neutral current facts. Both remain
`unconfirmed_current_state`, never success, and never attribute causation.

GET exact 404 enters FE005 privacy-safe not-found. GET error/malformed/stale
clears busy state and retains safe unresolved feedback. A later user Refresh is
a separate read. A later mutation requires a fresh explicit dialog/confirm.

## 10. Cache, Error, and Session Rules

As soon as any locally valid mutation begins:

- mark FE004 Users stale while preserving retained query;
- stale markers survive route disposal;
- change no visible data optimistically.

Leave FE002 Dashboard untouched for edit, activate, and deactivate. Its three
role totals include active and inactive Users, so lifecycle changes no
Dashboard value. Issue no Dashboard invalidation or automatic Dashboard request.

This is required because mutation may commit after route exit or before a lost
response.

Use exact stable code behavior:

- 401 authentication_required → accepted global bootstrap/invalidation;
- user_inactive/institution_inactive/password_change_required → clear protected
  state and accepted global reconciliation;
- 403 forbidden → safe permission feedback;
- exact 404 resource_not_found → clear action/detail, FE005 safe not-found,
  canonical Back to Users, Users stale, no target/scope disclosure;
- PATCH exact 422 → map only full_name/email/phone; unknown/body/query/protected
  errors become safe form-level protocol feedback;
- lifecycle exact 422 → safe command-contract failure, no form/retry;
- exact 429 → safe definite failure, no timer/auto-retry;
- 5xx/transport/malformed success → unprovable path.

Never show/log raw backend message, error map, body, URL, UUID, contact,
Institution ID, SQL, stack, token, password, or protected field.

Required state meanings remain separate:

```text
idle
editing
lifecycle_confirming
submitting
reconciling_current_state
validation_failure
definite_failure
unconfirmed_current_state
confirmed_direct_success
target_not_found
```

Names may follow delivered convention. Unconfirmed state must never be success.

## 11. Presentation, Accessibility, and Architecture

Preserve Institution Admin desktop shell, Users selection, FE005 detail layout,
Back to Users, and responsive behavior.

Require:

- same safe actions in wide and compact desktop layouts;
- pointer and keyboard operation, visible focus, predictable order;
- cancel/Escape only before busy state;
- associated/announced field and form errors;
- progress semantics/live announcement while submitting/reconciling;
- direct success and unconfirmed-current-state wording visibly distinct;
- no status meaning by color alone;
- long values, 800×600, 1440×900, text scale 2.0, scrolling, no overflow/trap;
- focus returns to initiating action or safe current detail region;
- no raw UUID/error data in semantics.

Use exactly:

```text
detail screen/dialog
→ focused mutation controller
→ delivered Institution User repository
→ delivered remote data source
→ configured authenticated Dio
```

Resolve actual delivered filenames. Reuse shared User parser/model, FE004 list
stale hook and FE005 detail replacement/not-found hook. Preserve FE002
Dashboard without calling its invalidation hook. Add only narrow edit/lifecycle
types, controller/state, DTO if the delivered structure needs one, dialogs, and
focused tests.

Do not create giant files or a parallel client/model/repository/cache/session.
No router/core/auth/Platform/backend/docs/package/lockfile change. If delivered
hooks are missing and require redesign, stop as predecessor conflict.

## 12. Required Verification

Implement every test from detailed task Section 17, including:

- rune-based form boundaries, normalization, null clearing, changed-only/no-
  change/cancel;
- exact PATCH and zero-body lifecycle POST paths/body/query/header behavior;
- exact status/envelope/message/resource/target/desired state;
- malformed/extra/protected response and every failure classification;
- complete session eligibility and immutable operation key;
- one mutation, duplicate suppression, zero replay;
- direct success detail/list behavior and zero Dashboard invalidation/request
  calls for edit, activate, and deactivate;
- early Users stale markers surviving route exit;
- every unprovable PATCH/activate/deactivate path with at most one GET and never
  success from matching current state;
- 401/actor-state/403/404/422/429 behavior;
- target/session/account/Institution/route/disposal/newer-operation stale
  completions;
- active/inactive actions, dialogs, protected-control absence, accessibility,
  responsive layout, FE001 route, FE004 list, FE005 detail, FE006 create,
  auth/shell/Dashboard/profile, and Platform regressions.

Run from `frontend/`:

```text
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/features/institution_admin
flutter test test/app/router
flutter test
flutter build windows --debug
```

Run focused predecessor tests resolved in Phase 0, `git diff --check`,
non-writing scope/diff checks, repository secret checks, and prompt byte
comparison. Run the controlled real-stack smoke from task Section 17.6 and
report PASS/FAIL/NOT RUN truthfully under its exact blocking rule.

Any required failure blocks acceptance.

## 13. Phase 1 — Implementation Rules

Implement only the detailed task's allowed Institution Admin User feature and
narrow predecessor hooks/tests.

During Phase 1:

- set only FE007 index row to
  `In Progress / Not started / Not started`;
- keep detailed task `Approved`;
- preserve this prompt byte-for-byte;
- run all required checks/smoke;
- inspect complete diff;
- do not commit or push.

## 14. Phase 2 — Strict Read-Only Acceptance Gate

Re-read authority and review complete dependency/diff/code/test evidence for:

```text
target/route/session ownership
form and changed JSON
exact PATCH/zero-body POST
strict 200/envelope/message/resource/target/state
direct-success-only rule
zero optimistic state and zero mutation replay
one GET/current-state-only reconciliation
auth/error/not-found behavior
early Users stale hook and Dashboard preservation
stale target/session/disposal isolation
accessibility/responsive behavior
scope/secrets/workflow/bookkeeping
```

Phase 2 permits no edit, formatter write, task/index/README change, staging,
commit, push, PR, merge, or self-fix.

Classify:

- P1: tenant/session/protected/password/token disclosure, target confusion,
  stale cross-session action, duplicate/destructive mutation, secret/unsafe Git,
  or read-only violation;
- P2: material contract/state/error/reconciliation/invalidation/accessibility/
  test/workflow mismatch, false success, replay, stale gap, regression, scope;
- P3: non-blocking observation only.

Any unresolved P1/P2:

```text
FINAL STATUS: NOT ACCEPTED
```

Stop without delivery and do not start FE008.

## 15. Phase 3 — Post-Acceptance Delivery

Only after Phase 2 PASS:

1. Change detailed task status only from Approved to Accepted.
2. Prepare only FE007 index row as Accepted/PASS/Delivered in delivery commit.
3. Update README truthfully: Stage 3 In Progress, FE007 delivered, FE008 next.
4. Keep later tasks truthful, Stage 3 open, Stage 4 blocked.
5. Prove this prompt byte-for-byte unchanged.
6. Run final non-writing scope/secret/diff/consistency checks.
7. Stage only approved implementation/tests, task, unchanged prompt, index,
   README.
8. Commit exactly:

   ```text
   feat(institution): add user edit and lifecycle UI

   Task: S03-FE-007
   ```

9. Push exact branch, create PR to main, verify base/head/diff/checks, safely
   merge when permitted.
10. Fast-forward local main and prove local main equals origin/main, accepted
    commit is an ancestor, and tree is clean.

Phase 2 PASS but incomplete delivery:

```text
FINAL STATUS: DELIVERY BLOCKED
```

Complete delivery:

```text
FINAL STATUS: ACCEPTED
```

## 16. Required Final Report

Return all evidence required by detailed task Section 21: final status,
preflight/dependencies, changed files/layers, target/session key, edit/form/
request, lifecycle confirmation/zero-body request, exact direct success,
unprovable/one-GET/no-success-from-GET behavior, errors, detail/list stale/update
and Dashboard non-invalidation behavior, stale completion/security/protected-
data/accessibility,
commands/build/smoke/regressions, P1/P2/P3, scope/secrets/bookkeeping, prompt
hash, commit/PR/merge/final equality/clean state.

State exactly:

```text
No role/login/password/first-login/token, Institution Admin/Platform Owner,
delete/bulk, relationship/Group, settings/category, backend/schema, or Learning
behavior was implemented.
Next implementation gate: S03-FE-008.
```
