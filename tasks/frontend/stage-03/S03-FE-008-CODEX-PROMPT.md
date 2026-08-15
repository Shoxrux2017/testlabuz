# Codex Execution Prompt — S03-FE-008

Execute only:

```text
S03-FE-008 — Institution Assessment Settings UI
```

Repository:

```text
G:\project\testlabuz
```

Authoritative task:

```text
tasks/frontend/stage-03/S03-FE-008-institution-assessment-settings-ui.md
```

Required branch:

```text
task/s03-fe-008-assessment-settings
```

Read the detailed task and this prompt completely before acting. Then read all
root/frontend AGENTS instructions, Stage 3 index/README, S03-INT-001, accepted
S03-BE-006, delivered S03-FE-001–007 authority relevant to this feature, locked
docs sections named by the task, and current implementation/tests/Git state.

## Phase 0 — Read-Only Preflight

Before implementation:

1. verify the expected GitHub origin and fetch safely;
2. prove clean local `main == origin/main`;
3. prove this task is `Approved`;
4. prove both direct dependencies, S03-FE-007 and S03-BE-006, are independently
   `Accepted / PASS / Delivered` on that main;
5. prove the delivered exact Settings route/shell/placeholder and central
   session/Dio/error contracts exist;
6. record this prompt's SHA-256 for later byte comparison;
7. resolve exact allowed feature/test files and regressions;
8. prove exact decimal JSON-number transport is possible without rounding, a
   new package, or core-client rewrite;
9. preserve unrelated work and stop on dirty/conflicting/unsafe state;
10. only then create/switch to the exact task branch.

If a direct dependency is missing, return `FINAL STATUS: BLOCKED`. Do not repair
or implement predecessor scope. Do not commit, push, open a PR, merge, or mark
the task Accepted before Phase 2 PASS.

## Implementation Authority

Replace only the FE001 Settings placeholder at:

```text
/institution-admin/settings
```

Preserve the route, `Settings` title/navigation selection, guards, shell, and
all other delivered screens. Create one independent real Assessment settings
section and only an honest non-interactive S03-FE-009 Understanding Categories
placeholder. Make zero category requests and expose no fake category data.

Implement the feature-first path:

```text
presentation
→ focused assessment read/mutation state/controller
→ repository
→ remote data source
→ configured authenticated Dio
```

Widgets must not call Dio, parse JSON, serialize decimal payloads, select a
tenant, classify HTTP outcomes, or own reconciliation.

### Exact GET

```text
GET /api/v1/institution/settings/assessment
query: none
body: exactly zero bytes; omit Dio data
tenant selector/header: none
```

Accept only exact HTTP 200 with one top-level `data` key and exact resource:

```text
educational_policy_configured: bool
acceptable_score_difference: null|finite JSON number 0..100, <=8 effective decimals
blitz_timer_start_mode: null|synchronized|individual
student_result_release_mode: null|automatic|manual_teacher
parent_result_release_mode: null|with_student|manual_teacher|hidden
timezone: non-empty exact string, max 64
upload_limits:
  learning_material_max_mb: int 1..25
  student_submission_max_mb: int 1..15
  platform_learning_material_max_mb: exact int 25
  platform_student_submission_max_mb: exact int 15
fixed_attempt_rules:
  homework_normal_attempts: exact int 3
  blitz_normal_attempts: exact int 1
  blitz_max_additional_exception_attempts: exact int 1
```

Require exact key sets at every level, independent of JSON object order. Reject
missing/extra/private keys, wrong types/ranges/constants, and inconsistent
configured flag. The flag is true iff all four policy fields are non-null.
When false, preserve any valid non-null policy values: a partial legacy row is
allowed. Mark each null field `Configuration required`; invent no defaults.

Initial load/Retry/Refresh use latest-operation/session ownership. A dirty form
requires explicit discard confirmation before Refresh. Never retain another
account's settings.

### Exact form and PUT

Confirmed data has read-only view plus Edit/Configure. Edit exactly seven fields:

```text
acceptable_score_difference
blitz_timer_start_mode
student_result_release_mode
parent_result_release_mode
timezone
learning_material_max_mb
student_submission_max_mb
```

Cancel discards draft; Reset restores current confirmed values while staying in
edit; no-change Save sends no PUT; one PUT may be in flight. Disable conflicting
controls while submitting/reconciling. Leaving route/logout/session replacement
discards draft and sends nothing.

Threshold input is exact ASCII decimal text: required integer part, optional
period plus 1–8 fractional digits, no sign/whitespace/comma/grouping/exponent,
logical 0..100. Normalize without floating epsilon or display rounding. The
actual PUT token must be a JSON number, never a string, and must preserve the
logical value without binary artifact or silent rounding. Test actual configured
Dio/on-wire serialization for boundaries and representative eight-place values.
Stop if this cannot be proved without package/core changes.

Use exact wire enums and accessible human explanations. Do not trim/case-fold.
Timezone local checks cover exact non-empty/max-64/no surrounding whitespace/no
fixed numeric offset; server IANA membership remains authoritative. Do not use
device timezone, add a timezone package, or hardcode Uzbekistan. Upload limits
are strict integers 1..25 and 1..15.

Show fixed rules `3/1/1` and platform maxima `25/15 MB` from the parsed resource
as read-only facts. Never serialize them.

Send exactly:

```text
PUT /api/v1/institution/settings/assessment
Content-Type: application/json
query: none
tenant selector/header: none
Idempotency-Key: none
body: exactly the seven required top-level fields, complete replacement
automatic retry/replay: none
```

Do not send null, partial/changed-only data, nested upload_limits, configured
flag, fixed/platform fields, IDs, updater, timestamps, or categories.

### Direct success and unprovable outcomes

Only the original PUT's exact `200` response proves this mutation succeeded.
Require exactly top-level `data`, the strict resource, configured true, exact
fixed/max facts, and all seven returned logical values equal to the submitted
snapshot. The backend returns no `message`; use local success text only after
that proof. Then replace confirmed data from the response and clear draft/stale
state. Do not invalidate Dashboard/Profile/Users/categories.

After a valid PUT starts, mark only same-session assessment settings stale.
Transport/timeouts/unknown cancellation, 5xx, unexpected 2xx/redirect/status,
or malformed/mismatched 200 are unprovable. Never say success or causal failure,
never expose mutation Retry, and never replay PUT.

For an unprovable result, while the exact session/route/operation remains
current, perform at most one read-only exact GET. It may publish only current
server state. Even if all seven values match, say explicitly that current values
match but this request result could not be confirmed. A matching GET is never
mutation success because another administrator/concurrent request may have
written the same values. If values differ, report current state differs and the
request remains unconfirmed. GET failure/malformed/stale remains safe. Never
issue a second reconciliation GET or any automatic PUT.

### Errors, session, scope, and UI

Use exact stable status/code pairs and central infrastructure:

- 401/auth and actor-state errors clear protected state through accepted flow;
- 403 is safe permission failure;
- PUT 422 maps only seven approved keys; unknown/body/query/protected entries
  become safe form-level protocol feedback;
- 429 is definite non-success with no automatic retry;
- GET 5xx/transport is a normal read error with user Retry;
- PUT 5xx/transport is unprovable, not definite failure;
- missing invariant row is never local defaults, creation, or 404.

Bind every data/draft/request/completion/feedback/stale marker to current User
id and object identity, Institution id, session generation, exact route,
operation generation, and live controller. Reject stale completions after
logout, bootstrap, account/role/Institution switch, first-login transition,
route exit, disposal, or newer operation. No raw payload/message/ID/token/SQL/
stack/private data may render or log.

Explain future-effect/timezone/history behavior without claiming later Blitz,
result, release, file, or category implementation. Provide compact/wide,
text-scale-2.0, scrolling, keyboard, focus, semantics, live-progress, validation,
null/configured, and distinct unconfirmed-state coverage.

Do not add packages or change backend/schema/docs/core auth/network, route path/
name/topology, shell design, Dashboard/Profile/User behavior, category API,
runtime learning/results/files/history, mobile admin, web admin, Stage 3
integration/closure, or Stage 4 scope.

## Verification and Phase 2

Run every focused matrix and command required by the detailed task, including:

```text
cd frontend
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test test/features/institution_admin
flutter test test/app/router
flutter test
flutter build windows --debug
```

Run focused predecessor regressions, exact request/DTO/decimal on-wire tests,
Git scope/diff checks, `git diff --check`, secret scans, prompt byte comparison,
and controlled real-stack smoke under the detailed task's PASS/NOT RUN rule.
Report every failure truthfully.

During Phase 1, change only the FE008 index row to
`In Progress / Not started / Not started`, keep the task `Approved`, preserve
this prompt byte-for-byte, and do not commit/push.

Phase 2 is strictly read-only: no edits, formatting writes, bookkeeping, staging,
commit, push, PR, merge, or self-fix. Re-read all authority and inspect the full
diff/evidence. Classify P1/P2/P3 exactly as the task requires. Any unresolved P1
or P2 returns:

```text
FINAL STATUS: NOT ACCEPTED
```

Do not deliver and do not start S03-FE-009.

## Phase 3 — Delivery After PASS Only

After Phase 2 PASS with zero unresolved P1/P2:

1. change only this task status to `Accepted`;
2. prepare only FE008 index row as `Accepted / PASS / Delivered`;
3. update README truthfully with FE009 as next gate and Stage 4 blocked;
4. prove this prompt stayed byte-for-byte unchanged;
5. stage only approved FE008 implementation/tests/task/prompt/index/README;
6. commit exactly:

   ```text
   feat(institution): add assessment settings UI

   Task: S03-FE-008
   ```

7. push, open/verify/merge the safe PR, fast-forward local main, and prove
   `local main == origin/main`, clean tree, and accepted commit ancestry.

Phase 2 PASS with incomplete delivery returns
`FINAL STATUS: DELIVERY BLOCKED`. Complete safe delivery returns
`FINAL STATUS: ACCEPTED`.

Return the complete report required by the detailed task and state exactly:

```text
No Understanding Category, editable attempt/platform maximum, runtime Blitz/
result/file/history, Dashboard/Profile/User, backend/schema, mobile-admin, web,
Group/relationship/report/learning, integration/closure, or Stage 4 behavior
was implemented.
Next implementation gate: S03-FE-009.
```
