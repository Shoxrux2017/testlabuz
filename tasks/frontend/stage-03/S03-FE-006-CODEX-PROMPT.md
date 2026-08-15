# Codex Execution Prompt — S03-FE-006

Execute only:

~~~text
S03-FE-006 — Institution User Create
~~~

Repository:

~~~text
G:\project\testlabuz
~~~

Detailed task:

~~~text
tasks/frontend/stage-03/S03-FE-006-institution-user-create.md
~~~

Branch:

~~~text
task/s03-fe-006-institution-user-create
~~~

The complete detailed task is authoritative. Read it fully before doing
anything. This prompt controls execution and does not replace the task.

## 1. Authority and Dependency Gate

Read completely, in this order:

1. root `AGENTS.md`;
2. `frontend/AGENTS.md`;
3. this prompt and the complete S03-FE-006 detailed task;
4. `tasks/README.md` and `tasks/STAGE_03_TASK_INDEX.md`;
5. accepted S03-INT-001 task/control record;
6. relevant locked `docs/02` through `docs/09` sections named by the task;
7. accepted S03-BE-004 task, implementation, tests, review, and delivery;
8. delivered S03-FE-001, FE002, FE004, and FE005 code/tests;
9. Stage 2 Platform create flows only as structural/secret-safety reference.

Direct dependencies are exactly:

~~~text
S03-FE-005
S03-BE-004
~~~

S03-FE-004 is a transitive predecessor through FE005, not a third direct
dependency.

At preparation time BE004 was delivered, but FE005 and its frontend
predecessors were not. Do not infer current delivery from this prompt.
Production implementation is blocked unless both direct dependencies are
independently Accepted / PASS / Delivered on current `origin/main`.

If a dependency is missing, stop as `BLOCKED`. If locked documents, accepted
backend, the detailed task, or delivered frontend contracts conflict, stop and
report exact sections. Do not edit, guess, or invent a reconciliation.

## 2. Phase 0 — Read-Only Preflight

Before implementation:

1. Verify the detailed task status is Approved.
2. Verify the expected GitHub origin and fetch safely.
3. Prove local main equals origin/main.
4. Prove FE005 and BE004 are Accepted / PASS / Delivered on that main.
5. Prove delivered FE004 shared User/list contracts exist through the frontend
   dependency chain and agree with FE005.
6. Prove the worktree is clean except only owner-prepared FE006 task/prompt
   files when not yet committed.
7. Resolve the FE001 create route/placeholder/helper/tests, FE002 dashboard
   provider, FE004 model/parser/list/query/retention/stale hook, FE005 detail
   navigation, session patterns, and all affected predecessor tests.
8. Prove which conditional files from the detailed task are necessary.
9. Preserve unrelated user work and stop on dirty/conflicting/unsafe Git state.
10. Only after every gate passes, create/switch to the exact task branch from
    approved current main.

Do not commit, push, create a PR, or merge before Phase 2 PASS.

## 3. Exact Goal

Replace only the Institution Admin create placeholder with a real accessible
Windows desktop form that creates exactly one own-Institution Teacher, Student,
or Parent through:

~~~text
POST /api/v1/institution/users
~~~

Strictly confirm the accepted 201 response before claiming success. Protect the
initial password, prevent duplicate POST, keep tenant/creator/lifecycle backend
authority, invalidate dependent reads without losing the retained Users query,
and replace-navigate by the confirmed server UUID to FE005 detail.

Never automatically retry/replay the POST. A diagnostic GET after an unprovable
outcome can never prove creation or trigger automatic detail navigation.

## 4. Exact Form

Use exactly six fields in this order:

~~~text
Role
Full name
Login name
Email (optional)
Phone (optional)
Initial password
~~~

Initial role is unselected. Exact role mapping:

~~~text
Teacher -> teacher
Student -> student
Parent  -> parent
~~~

Do not offer Platform Owner, Institution Admin, custom roles, permissions,
Groups, or relationships.

Length validation uses Dart Unicode scalar values/runes.

Apply exactly:

- full name: trim; required non-empty; maximum 200;
- login name: trim; required non-empty; maximum 191; backend owns uniqueness;
- email: exact empty field to null; non-empty value is not trimmed/rewritten;
  whitespace invalid; permissive one-@ early validation; maximum 254;
- phone: exact empty field to null; non-empty value trimmed; whitespace-only
  non-empty input invalid; maximum 50 after trim;
- password: exact unmodified string; required; 8 through 255; never trim or
  normalize; obscured by default.

Use every exact local validation message defined by Section 5.2 of the task.
Local validation must not become global login, tenant, or backend authority.

Password field:

- obscure by default;
- visibility toggle, if present, is not another input field;
- disable suggestions/autocorrect and use new-password autofill semantics;
- never put password into helper text, semantics, SnackBars, error summaries,
  state diagnostics, logs, or test output;
- show exact help: `The user must change this password at first login.`

Do not add password confirmation.

## 5. Exact Request

Send exactly:

~~~text
Method: POST
Path: /api/v1/institution/users
Content type: application/json via configured Dio
Query: none
Body: one JSON object
Tenant selector: none
Auth: existing configured client
Idempotency-Key: none
~~~

Always send exactly six keys, including nullable contacts:

~~~json
{
  "role": "teacher",
  "full_name": "Teacher Name",
  "login_name": "teacher01",
  "email": null,
  "phone": "+998901234567",
  "password": "exact-initial-password"
}
~~~

Never send Institution/creator/UUID, active/first-login/lifecycle/timestamps,
password confirmation, permissions, tokens, Institution, relationships,
Groups, settings/categories, learning/results, query keys, or tenant headers.

Use the existing configured Dio client and failure mapper. Add no client, token
store, interceptor, logger, package, idempotency key, retry policy, mutation
queue, or background replay.

After valid local validation starts one POST, disable every form action and
field. Repeated click, Enter, keyboard activation, double-click, rebuild, timer,
or callback sends no second POST. Route exit makes the operation stale; it does
not guarantee server cancellation.

## 6. Exact Confirmed Success

Confirmed success requires HTTP 201 and exactly:

~~~json
{
  "data": {
    "id": "user-uuid",
    "role": "teacher",
    "full_name": "Teacher Name",
    "login_name": "teacher01",
    "email": null,
    "phone": "+998901234567",
    "is_active": true,
    "must_change_password": true,
    "last_login_at": null,
    "deactivated_at": null,
    "created_at": "2026-08-07T15:00:00Z",
    "updated_at": "2026-08-07T15:00:00Z"
  },
  "message": "Institution user created successfully."
}
~~~

Require exactly top-level `data` and `message`, the exact message, and no extra
key. Delegate `data` to the exact FE004 shared 12-field User parser/model. Do not
copy, loosen, coerce, default, or extend the parser.

Before success, compare with the immutable normalized request snapshot:

~~~text
valid canonical response UUID
same role
same normalized full_name
same normalized login_name
same nullable email
same nullable normalized phone
is_active = true
must_change_password = true
last_login_at = null
deactivated_at = null
~~~

Any unexpected 2xx/status, wrong message, malformed/extra/protected resource,
or request/response mismatch is an unprovable outcome. Never claim success or
navigate from it.

Confirmed-current success sequence only:

1. clear password and all drafts;
2. mark FE004 Users stale while preserving the retained same-session query;
3. invalidate FE002 Dashboard data because exactly one Teacher, Student, or
   Parent total has increased;
4. show/announce only `User created successfully.`;
5. replace/go through the delivered named helper to the returned server UUID
   detail route;
6. pass no password/form/DTO/resource as detail authority;
7. let FE005 issue its normal fresh detail GET.

FE002 exposes only three role totals: Teachers, Students, and Parents. Each
total includes active and inactive Users; there is no active/inactive Dashboard
split. Invalidate/refetch the authoritative totals and never invent or
optimistically change an active count.

System back must not reopen a credential-bearing create form.

## 7. Definite Failures

Exact HTTP 422 + `validation_failed` is a definite rejection. Map only:

~~~text
role
full_name
login_name
email
phone
password
~~~

Use safe local field copy. For login use:

~~~text
Review the login name; it may already be in use.
~~~

Unknown/body/query/protected validation keys, missing field errors, or malformed
envelopes become a safe form-level protocol error. Never render raw keys,
messages, or payloads.

For a server 422, retain only non-secret values, clear password, focus the first
invalid field, and require password re-entry for a deliberate new submit.

Classify:

- exact 401/authentication_required: central invalidation, clear everything;
- password-change/User-inactive/Institution-inactive: clear everything and use
  accepted bootstrap/reconciliation;
- exact 403/forbidden: safe non-retryable, retain non-secret values, clear
  password;
- exact 429/rate_limited: safe definite failure, clear password, no timer or
  automatic retry;
- 404 and 409 are not normal BE004 errors and cannot be treated as accepted
  business states.

Use the exact safe copy from the detailed task. Every sent POST requires a new
password before another deliberate submission.

## 8. Unprovable Outcome

After a valid POST begins, classify as unprovable when there is no exact
confirmed success or accepted definite pre-action rejection, including:

- timeout/connection/send/receive/transform/cancel/unknown without a valid
  accepted response;
- HTTP 5xx;
- unexpected 2xx, 404, 409, or other uncontracted status;
- malformed error envelope;
- malformed/mismatched exact-201 body or wrong message.

Then:

- clear password immediately;
- retain only the non-secret immutable snapshot needed for safe state;
- mark Users/dashboard stale while preserving retained query;
- never show success;
- never replay POST automatically or through Retry;
- keep the current outcome screen terminal for submission;
- never automatically open any User detail.

## 9. At-Most-One Diagnostic GET

While the exact same eligible operation/session remains current, perform at
most one GET-only diagnostic through the delivered FE004 list repository:

~~~text
GET /api/v1/institution/users
role = submitted role
search = submitted normalized login_name
page = 1
per_page = 100
sort = login_name
direction = asc
status = omitted
body = zero bytes
tenant selector = none
~~~

Do not call Dio directly from the controller. Reuse FE004 query, repository,
strict collection/parser, client, and session scope.

The diagnostic must not change FE004 visible or retained search/filter/page/
rows state. It performs no second page, correction, Retry, polling, or second
GET and sends no password/create body.

An exact public-field match is only a possible matching account. It could have
existed before the POST or be the subject of a lost duplicate-login 422. It is
never confirmation, success, or automatic detail navigation.

No match, many substring matches, later-page possibility, mismatch, malformed
response, GET error, or stale completion remains inconclusive. Do not retry or
broaden the query.

Exact possible-match UI:

~~~text
Title: Creation outcome unknown
Message: A matching user is visible, but the app cannot confirm that this request created it. Review Users before trying again.
Action: Review Users
~~~

Exact other unknown UI:

~~~text
Title: Creation outcome unknown
Message: The request may have completed. Review Users before trying again.
Action: Review Users
~~~

Review Users uses the canonical helper and does not inject/reset FE004 query.

## 10. Password, Session, and Stale Safety

Allow no product request unless live frontend state is all of:

~~~text
authenticated
user exists
role = institution_admin
user active
must_change_password = false
non-empty institution_id
nested institution exists
nested institution id matches institution_id
institution active
approved desktop surface
~~~

Bind form ownership and every POST/GET/result/invalidation/navigation to:

~~~text
session user id
session User object instance identity
institution id
immutable normalized non-secret snapshot
operation generation
controller not disposed
~~~

Password is never part of Riverpod/domain/state keys or stored snapshots. It
may exist only in the screen controller and ephemeral immediate request object.

Use explicit states equivalent to editing, local validation failure,
submitting, server validation failure, definite failure, reconciling unknown,
unknown possible match, unknown inconclusive, and confirmed
success/navigating.

Required rules:

- local validation sends no request and may keep password locally;
- every completed or abandoned POST clears password;
- Cancel before submit clears all and sends nothing;
- Cancel disabled during submit/reconciliation; route exit disposes and makes
  completions stale;
- logout, bootstrap, 401, inactive User/Institution, first-login requirement,
  Institution mismatch, same-role/cross-role switch, route exit, or disposal
  clears all state/actions and invalidates generation;
- stale POST/GET success/validation/error/match cannot publish, invalidate a
  later session, or navigate;
- no global singleton or disposed-route outcome remains authority.

Guarantee next list/Dashboard activation reloads even when route exit occurs
after POST start. Use the accepted FE004 stale hook that preserves retained
query. If none exists, add only the minimal tested feature-local hook permitted
by the task. Never optimistically add a row or change a Dashboard role total.

## 11. Exact UI and Navigation

Use:

~~~text
Heading: Create User
Primary: Create User
Busy: Creating user
Secondary: Cancel
Help: The user must change this password at first login.
~~~

Cancel before submit clears all and uses the canonical named route/helper to:

~~~text
/institution-admin/users
~~~

Do not rely only on Navigator.pop; direct entry may have no useful app history.

Use existing Material 3 shell/theme. Prove exact labels/order, first-error focus,
concise non-secret error summary, useful busy/unknown/success live semantics,
keyboard operation, visible focus, no color-only meaning, long value/error
wrapping, and no credential in tooltip/semantics.

Prove 800x600, 1440x900, text scale 2.0, scrolling, no overflow, and exact focus
order from Role through actions. Disable conflicting controls during submit and
diagnostic reconciliation.

Do not add edit, activate, deactivate, reset password, role/login update,
invite, bulk, relationship, settings/category, learning, or later-stage action.

## 12. Architecture and File Boundary

Required create flow:

~~~text
create screen/controller
  -> create repository
  -> create remote data source
  -> existing Dio client
~~~

Optional diagnostic flow:

~~~text
create controller
  -> delivered FE004 list repository with exact query
  -> delivered FE004 data source
  -> existing Dio client
~~~

Use only the expected production/test files named in Section 12 of the detailed
task.

Conditionally allowed only when proven necessary:

- minimal FE004 list stale/refresh-on-return hook and exact related tests;
- minimal existing app-router wiring/test update to construct the real create
  screen, without route contract/topology change;
- minimal FE001 create-placeholder/no-request tests made obsolete here;
- minimal FE004 Create User/list-return tests made obsolete here;
- exact FE002 dashboard invalidation and FE005 fresh-detail regression tests
  when exercised by this change.

Preserve every unrelated predecessor assertion and report every conditional
change. Stop if broader production/test work is required.

Do not modify backend, schema, docs, packages, core network/auth, Platform
Admin, route names/paths/helpers/order/classification, shell topology, other
Institution Admin features, or unrelated code. Do not add idempotency
infrastructure, fake API, later mutation, or cleanup.

## 13. Required Tests and Commands

Implement the complete Section 15 matrix, including:

- exact form mapping/normalization/rune boundaries and six-key request;
- password absence from state/logs/semantics and clearing matrix;
- exact 201/envelope/message/shared parser/request-response confirmation;
- every malformed/extra/protected/mismatched success case as unknown;
- exact path/body/no query/no tenant/no idempotency/no retry;
- 401/403/422/429, 5xx, timeout/connection/cancel/unknown/unexpected status;
- complete eligibility, dedup, route exit, disposal, account/session stale cases;
- Users/dashboard stale behavior without retained-query loss/optimism;
- exact one diagnostic GET, every match/no-match/malformed/error/stale case, and
  proof that a pre-existing identical User is never confirmed as created;
- confirmed success clearing/confirmation/returned-UUID navigation/fresh detail;
- direct route, Cancel, system back, list return, exact UI/accessibility/layout;
- narrow predecessor updates and full auth/router/shell/dashboard/profile/list/
  detail/Platform regressions.

Run from `frontend` and observe final status/output:

~~~text
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/features/institution_admin
flutter test test/app/router
flutter test
flutter build windows --debug
~~~

Also run every focused test for conditional predecessor changes, tracked-file
allowlist/scope review, complete diff review, credential/secret/password-log
scan, prompt byte comparison, and current configured quality gates.

Record unavailable real-stack/Windows/failure-injection smoke items as NOT RUN
with exact reason. Never fabricate evidence or expose credentials.

## 14. Phase 1 Bookkeeping

Before Phase 2:

1. Change only the FE006 Stage index row to
   In Progress / Not started / Not started.
2. Minimally correct directly adjacent Stage index narrative/count/next-gate
   text so it does not still call FE006 Draft.
3. Do not change another task's status/review/delivery.
4. Keep this detailed task Approved.
5. Preserve this prompt byte-for-byte.
6. Do not update README acceptance/delivery state.
7. Run all checks and inspect complete diff.
8. Do not stage, commit, push, create a PR, or merge.

## 15. Phase 2 — Strictly Read-Only Acceptance Gate

Re-read authority and review the complete result/diff: form, request, password,
status/envelope/resource confirmation, failures, unknown outcome, no replay,
diagnostic GET, session/stale isolation, invalidation, navigation, disclosure,
accessibility, regressions, commands/build/smoke, scope, bookkeeping, secrets.

Phase 2 permits:

~~~text
no edits, auto-fix, or write-format
no task/index/README changes
no staging or commit
no push, PR, or merge
no self-fixing findings
~~~

Classify every finding as P1/P2/P3 by the detailed task. Any unresolved P1 or
P2 requires:

~~~text
FINAL STATUS: NOT ACCEPTED
~~~

Stop without delivery and do not start FE007. Report every P3; P3 alone does
not block PASS.

## 16. Phase 3 — Post-Acceptance Delivery

Only after Phase 2 PASS with no unresolved P1/P2:

1. Change only this task status from Approved to Accepted without rewriting
   approved behavior.
2. Set only FE006 index row to Accepted / PASS / Delivered and update directly
   related count/narrative/next-gate consistency.
3. Update `tasks/README.md`: Stage 3 remains In Progress, FE006 is delivered,
   and FE007 is next.
4. Keep later tasks truthful, Stage 3 open, and Stage 4 blocked.
5. Preserve this prompt byte-for-byte.
6. Re-run final non-writing diff/scope/secret/prompt/consistency checks.
7. Stage only approved implementation/tests, task, unchanged prompt, index, and
   README.
8. Commit exactly:

   ~~~text
   feat(institution): add user creation UI

   Task: S03-FE-006
   ~~~

9. Push the exact branch, create a PR to main, verify base/head/diff/checks, and
   merge only when safe/green/permitted.
10. Fast-forward local main and prove local main equals origin/main with a clean
    worktree.

Phase 2 PASS but incomplete verified delivery requires:

~~~text
FINAL STATUS: DELIVERY BLOCKED
~~~

Complete verified delivery requires:

~~~text
FINAL STATUS: ACCEPTED
~~~

## 17. Stop Conditions

Stop before widening scope if a direct dependency is not delivered, authority
conflicts, shared User/list contracts cannot be reused, retained query cannot be
preserved, password/no-replay/response-confirmation/stale navigation cannot be
proven, backend/core/auth/package/route/idempotency/later-mutation change appears
necessary, broader predecessor rewrite is required, Git/GitHub is unsafe, or
Phase 2 has any P1/P2.

## 18. Required Final Report

Return every item required by Section 19 of the detailed task, including final
status, Phase 0 evidence, every changed/conditional file, form/request/password,
exact confirmation, failure/unknown classification, zero replay, diagnostic
GET and no false success, session/stale/invalidation, retained query, confirmed
navigation, accessibility, regressions, commands/build/smoke, P1/P2/P3, scope/
secret/prompt/bookkeeping, PR/merge/main/clean evidence.

End exactly with:

~~~text
No User edit/lifecycle/password reset, client tenant authority, mutation replay,
false reconciliation success, protected data, relationship, settings/category,
learning, or Stage 4 behavior was implemented.
Next implementation gate: S03-FE-007.
~~~
