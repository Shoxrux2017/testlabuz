# Codex Execution Prompt — S03-FE-009

Execute only:

```text
S03-FE-009 — Understanding Category Range Editor
```

Repository:

```text
G:\project\testlabuz
```

Authoritative task:

```text
tasks/frontend/stage-03/S03-FE-009-understanding-category-range-editor.md
```

Required branch:

```text
task/s03-fe-009-understanding-categories
```

Read the detailed task and this prompt completely before acting. Then read all
root/frontend AGENTS instructions, Stage 3 index/README, S03-INT-001, delivered
S03-BE-007 and S03-FE-001/S03-FE-008 authority, locked docs sections named by
the task, and current implementation/tests/Git state.

## Phase 0 — Read-Only Preflight

Before implementation:

1. verify expected GitHub origin and fetch safely;
2. prove clean local `main == origin/main`;
3. prove this task is `Approved`;
4. prove both direct dependencies, S03-FE-008 and S03-BE-007, are independently
   `Accepted / PASS / Delivered` on that main;
5. prove the delivered exact Settings route/composition/category placeholder,
   Assessment-section independence seam, session/Dio/error/stale contracts, and
   BE007 endpoint implementation/tests exist;
6. record this prompt's SHA-256 for later byte comparison;
7. resolve exact allowed category/composition/test files and regressions;
8. preserve unrelated work and stop on dirty/conflicting/unsafe state;
9. only then create/switch to the exact task branch.

If a direct dependency is missing, return `FINAL STATUS: BLOCKED`. Do not repair
or implement BE007/FE008 scope. Do not commit, push, open a PR, merge, or mark
the task Accepted before Phase 2 PASS.

## Implementation Authority

Replace only the S03-FE-009 placeholder inside the delivered FE008 Settings
composition at:

```text
/institution-admin/settings
```

Preserve the route, title, selected Settings navigation, guards, shell, shared
page scroll, and the complete S03-FE-008 Assessment section. Add no route,
second Settings screen/scaffold, nested tab route, or shell change.

Implement the category feature-first path:

```text
FE008 Settings composition / category section
→ focused category read/mutation state/controller
→ category repository
→ category remote data source
→ configured authenticated Dio
```

Widgets must not call Dio, parse JSON, select tenant, serialize requests,
classify HTTP outcomes, or own reconciliation.

## Fixed Model and Exact GET

Use one focused frontend fixed-category definition:

```text
1 understood_well          / Understood well          / numeric
2 partially_understood     / Partially understood     / numeric
3 needs_revision           / Needs revision           / numeric
4 needs_teacher_support    / Needs teacher support    / numeric
5 not_completed            / Not completed            / null/null
```

Codes, labels, order, and Not completed shape are visible read-only and never
editable. This structure may create empty unconfigured editor rows but must
never invent numeric ranges/defaults or claim configured state.

Send exactly:

```text
GET /api/v1/institution/understanding-categories
query: none
body: exactly zero bytes; omit Dio data
tenant selector/header: none
```

Accept unconfigured only as exact HTTP 200:

```json
{
  "data": [],
  "meta": {
    "configured": false
  }
}
```

Require exactly top-level `data + meta`, exactly empty data, and exactly one
boolean-false meta key. Any missing/extra/wrong value is malformed.

Accept configured only as exact HTTP 200 with exactly one top-level `data` key,
no meta/message/links/pagination, and exactly five items in canonical array
order. Each item has exactly:

```text
code
label
min_score
max_score
sort_order
```

Require exact fixed codes/labels/order, strict JSON integers for first-four
min/max, exact null/null for Not completed, no private/extra keys, each bound
0..100 and min<=max, order-1 max 100, order-4 min 0, and adjacency:

```text
higher.min_score = lower.max_score + 1
```

Thus all integers 0..100 are covered exactly once with no gap, overlap,
reversal, duplicate, missing, unknown, partial, or out-of-order row. A malformed
or corrupt response is an error, never repaired/defaulted/partially published.

Initial category load/Retry/Refresh uses current session/generation ownership.
Category loading/error never hides or clears Assessment state. Dirty category
Refresh requires confirmation to discard only category draft; it never refreshes
or discards Assessment.

## Exact Editor and PUT

Configured state has read-only view plus Edit; unconfigured has Configure and
eight empty numeric fields. Never prefill example/default ranges. Only first-
four min/max are editable. Code, label, sort order, and Not completed null/null
remain fixed.

Accepted numeric text is exactly ASCII `0` or a non-zero digit followed by at
most two digits, logical 0..100. Reject empty, leading-zero multi-digit, sign,
whitespace, decimal, comma, grouping, exponent, locale digit, and out-of-range
text. Serialize actual JSON integers, never strings/doubles.

Validate all eight required values, min<=max, first max 100, fourth min 0,
high-to-low fixed order, adjacency, and exact complete 0..100 coverage. Show
safe field/row and set-level coverage errors. Not completed is not a numeric
band.

Cancel discards category draft; Reset restores current configured values or
clears unconfigured inputs; configured no-change Save sends no PUT. One category
PUT may be in flight and rapid duplicates are blocked. Category busy controls
only category actions; Assessment busy controls only Assessment actions. Route
exit/logout/session replacement discards category draft and sends no mutation.

Send exactly:

```text
PUT /api/v1/institution/understanding-categories
Content-Type: application/json
query: none
tenant selector/header: none
Idempotency-Key: none
automatic retry/replay: none
```

Body has exactly root `categories`; its array has exactly five canonical-order
objects, each with exactly `code`, `min_score`, `max_score`, `sort_order`.
Generate fixed code/order client-side; send null/null for Not completed. Send no
label/meta/configured/ID/Institution/updater/timestamp/color/icon/result/history/
assessment/unknown field. Do not invent ETag/version/merge behavior.

## Direct Success and Unprovable Outcomes

Only the original PUT's exact `200` response proves this mutation succeeded.
Require exactly top-level `data`, strict configured collection, canonical order,
fixed labels/types/invariants, and every returned code/range/order equal to the
submitted snapshot. Backend returns no message/meta. Only then replace category
state from response, clear category draft/stale state, and show local
`Understanding categories saved.` Never change/invalidate Assessment,
Dashboard, Profile, Users, results, or history.

After valid category PUT starts, mark only same-session category data stale.
Transport/timeouts/unknown cancellation, 5xx, unexpected 2xx/redirect/status,
or malformed/mismatched 200 are unprovable. Never say success or causal failure,
show mutation Retry, or replay PUT.

For an unprovable result, while exact session/route/category operation remains
current, perform at most one exact read-only category GET. It publishes only
current server categories:

- configured exact match: say current categories match submitted ranges, but
  this request result could not be confirmed;
- configured difference: say current categories differ and the request result
  could not be confirmed;
- exact unconfigured: say current categories are not configured and the request
  result could not be confirmed;
- malformed/error/stale: current categories and request remain unconfirmed.

No case becomes mutation success. Another administrator/concurrent request may
have written an identical set. Never issue a second reconciliation GET,
Assessment Refresh, automatic merge, or PUT replay.

## Errors, Independence, Session, and UI

Use exact status/code pairs and central infrastructure:

- 401/auth and actor-state errors clear both protected Settings sections through
  accepted global session flow;
- 403 is safe permission failure;
- GET 422 is category client/protocol error;
- PUT 422 `categories` maps set-level; canonical indices 0..3 min/max may map to
  visible inputs; code/order/index-4/unknown/body/query/protected errors become
  safe form-level protocol feedback;
- 429 is definite non-success with no automatic retry;
- GET 5xx/transport is normal category read error with user Retry;
- PUT 5xx/transport is unprovable;
- corrupt/missing-invariant state is never unconfigured/default/404/repair UI;
- later result-time `409 category_configuration_invalid` is out of scope.

Bind category resource/draft/request/completion/feedback/stale marker to current
User id and object identity, Institution id, session generation, exact Settings
route, category operation generation, and live controller. Reject all stale
effects after logout, bootstrap, account/role/Institution switch, first-login
transition, route exit, disposal, or newer operation. Never render/log raw
payload/message/ID/token/SQL/stack/private data.

Category and Assessment load/draft/error/Refresh/PUT/reconciliation/busy/stale
states remain independent. A failure or rebuild in one cannot erase the other.
Each section deduplicates only its own mutation. Only global auth invalidation
clears both. Do not modify FE008 assessment domain/data/application contracts.

Explain that ranges apply to backend-derived integer `category_score` from
unrounded final score (`.0`–`.5` down, `>.5` up), without calculating it. Explain
Not completed means missing required work, not low score/waiting review/hidden
result. Changes affect future or explicitly recalculated eligible open results
and never silently rewrite calculated/closed snapshots. Implement no result
behavior.

Provide shared-page compact/wide scrolling, text-scale-2.0, keyboard, visible
focus, semantics, live progress, field/set errors, coverage summary,
configured/unconfigured, Not completed, and distinct unconfirmed-state tests.

Do not add packages or change backend/schema/docs/core auth/network, router,
shell, Assessment contract, Dashboard/Profile/Users, result engine/history,
groups/relationships/reports/learning, mobile/web admin, S03-INT-002, closure,
or Stage 4 scope.

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

Run focused FE008/route/session regressions, exact envelope/request/integer/set/
independence tests, Git scope/diff checks, `git diff --check`, secret scans,
prompt byte comparison, and controlled real-stack smoke under the detailed
task's PASS/NOT RUN rule. Report every failure truthfully.

During Phase 1, change only the FE009 index row to
`In Progress / Not started / Not started`, keep task `Approved`, preserve this
prompt byte-for-byte, and do not commit/push.

Phase 2 is strictly read-only: no edits, formatting writes, bookkeeping,
staging, commit, push, PR, merge, or self-fix. Re-read all authority and inspect
the complete diff/evidence. Classify P1/P2/P3 exactly as the task requires. Any
unresolved P1 or P2 returns:

```text
FINAL STATUS: NOT ACCEPTED
```

Do not deliver and do not start S03-INT-002.

## Phase 3 — Delivery After PASS Only

After Phase 2 PASS with zero unresolved P1/P2:

1. change only this task status to `Accepted`;
2. prepare only FE009 index row as `Accepted / PASS / Delivered`;
3. update README truthfully with S03-INT-002 as next gate and Stage 4 blocked;
4. prove this prompt stayed byte-for-byte unchanged;
5. stage only approved FE009 implementation/tests/task/prompt/index/README;
6. commit exactly:

   ```text
   feat(institution): add understanding category editor

   Task: S03-FE-009
   ```

7. push, open/verify/merge the safe PR, fast-forward local main, and prove
   `local main == origin/main`, clean tree, and accepted commit ancestry.

Phase 2 PASS with incomplete delivery returns
`FINAL STATUS: DELIVERY BLOCKED`. Complete safe delivery returns
`FINAL STATUS: ACCEPTED`.

Return the complete report required by the detailed task and state exactly:

```text
No custom/default/decimal category, editable Not completed, result calculation/
assignment/recalculation/release/history, Assessment contract, Dashboard/Profile/
User, backend/schema, mobile-admin, web, Group/relationship/report/learning,
S03-INT-002, closure, or Stage 4 behavior was implemented.
Next implementation gate: S03-INT-002.
```
