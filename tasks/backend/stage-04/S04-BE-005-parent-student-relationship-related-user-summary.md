# Codex Implementation Contract: S04-BE-005 — Parent–Student Relationship Related-User Summary

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S04-BE-005` |
| Stage | `Stage 4 — Groups and User Relationships` |
| Area | `Backend` |
| Status | `Approved` |
| Baseline | `origin/main` at `61c2b9820ab5de168857351d53502e1df0d5f864` |
| Depends on | `S04-BE-001…004 Accepted / Delivered`; Backend Phase 2 `PASS`; Stage 4 frontend decomposition approval |
| Delivery | `Implementation + GitHub delivery` |

Start only when local `main` is synchronized with the baseline or its exact
approved descendant, ahead/behind is `0/0`, and the worktree is clean.

This is the complete task-specific implementation contract. Do not create a
duplicate `CODEX-PROMPT` file.

---

## 2. Goal

Make both current Parent–Student relationship list endpoints directly usable by
Flutter by returning the related User's safe identity summary in every list
item, without extra per-item HTTP requests and without changing relationship
mutation responses or any authorization, validation, lifecycle, or persistence
behavior.

---

## 3. Scope

### Included

- Enrich only these two existing list responses:

  ```text
  GET /api/v1/institution/parents/{parent}/students
  GET /api/v1/institution/students/{student}/parents
  ```

- Add one exact nested `related_user` object to every list item.
- Reuse the Users join that already owns search, status filtering, and sorting.
- Preserve bounded query count and strict response serialization.
- Add/update focused list tests and directly affected mutation regression tests.

### Non-Goals

- No new route or endpoint.
- No request/query/filter/sort/pagination change.
- No schema, migration, model relationship, factory, seed, or persistence change.
- No Connect/Disconnect, idempotency, locking, concurrency, timestamp, or
  historical-lifecycle change.
- No candidate, bulk, history, self-service, reactivation, or hard-delete API.
- No frontend implementation.
- Do not modify `docs/01–09`, roadmap, architecture documents, Stage history,
  Phase 2 evidence, or unrelated task files in this implementation task.

---

## 4. Current Implementation Context

Inspect only these directly relevant areas and their immediate dependencies:

- `backend/app/Actions/Institution/ListInstitutionParentStudents.php`
- `backend/app/Actions/Institution/ListInstitutionStudentParents.php`
- `backend/app/Http/Resources/Institution/InstitutionParentStudentRelationshipResource.php`
- `backend/app/Http/Resources/Institution/InstitutionParentStudentRelationshipCollection.php`
- the two list Controllers that return this collection;
- `backend/tests/Feature/Institution/InstitutionParentStudentsApiTest.php`
- `backend/tests/Feature/Institution/InstitutionStudentParentsApiTest.php`
- `backend/tests/Feature/Institution/InstitutionParentStudentRelationshipMutationApiTest.php`

Current facts:

- both list Actions already join the related Users table for literal search,
  activity filtering, and deterministic sorting;
- the current collection serializes only relationship fields;
- `InstitutionParentStudentRelationshipResource` is also used by successful
  Connect responses and its exact five-key output must remain unchanged.

Do not read product specifications, roadmap, architecture/database/API
documents, previous tasks, Stage history, or closure reviews to rediscover the
requirements.

---

## 5. Exact Implementation Contract

### 5.1 List Response Shape

Every item returned by either endpoint must contain exactly:

```json
{
  "id": "relationship-uuid",
  "parent_id": "parent-user-uuid",
  "student_id": "student-user-uuid",
  "started_at": "2026-08-21T10:00:00Z",
  "ended_at": null,
  "related_user": {
    "id": "related-user-uuid",
    "full_name": "Related User",
    "login_name": "related.user",
    "email": null,
    "phone": null,
    "is_active": true
  }
}
```

Exact rules:

- top-level keys are exactly `id`, `parent_id`, `student_id`, `started_at`,
  `ended_at`, and `related_user`;
- `related_user` keys are exactly `id`, `full_name`, `login_name`, `email`,
  `phone`, and `is_active`;
- for `parents/{parent}/students`, `related_user` is the joined Student and
  `related_user.id == student_id`;
- for `students/{student}/parents`, `related_user` is the joined Parent and
  `related_user.id == parent_id`;
- `email` and `phone` are nullable JSON strings;
- `is_active` is a JSON boolean;
- relationship timestamps retain the existing whole-second UTC RFC 3339
  contract;
- current list items retain `ended_at = null`;
- do not expose role, Institution ID, connector ID, credentials, password state,
  login history, User timestamps, relationship created/updated timestamps, or
  other internal fields.

The existing collection envelope remains exactly:

```json
{
  "data": [],
  "meta": {
    "pagination": {
      "page": 1,
      "per_page": 20,
      "total": 0,
      "last_page": 1
    }
  }
}
```

### 5.2 Query and Resource Behavior

- Extend each existing joined select with only the safe related-User columns
  needed by `related_user`.
- Alias the related-User columns to one common endpoint-independent attribute
  set so one focused list-item Resource can serialize both endpoints without
  inspecting route names or guessing roles.
- Preserve all existing tenant, path-role, current-relationship, related-role,
  status, literal-search, sort, tiebreaker, and pagination clauses unchanged.
- Preserve response order and pagination metadata.
- Query count must remain constant as page size grows; no per-row User query,
  lazy load, repository loop, or Resource query is allowed.
- A Resource must serialize only already-selected attributes.

Create one focused list-item Resource for the enriched collection. Update the
existing relationship collection to collect that list-item Resource.

Keep `InstitutionParentStudentRelationshipResource` unchanged for Connect
responses.

### 5.3 Mutation Compatibility

These existing successful contracts must remain unchanged:

```text
POST   /api/v1/institution/parent-student-relationships
DELETE /api/v1/institution/parent-student-relationships/{relationship}
```

The successful Connect response `data` keeps exactly:

```text
id
parent_id
student_id
started_at
ended_at
```

It must not gain `related_user`. Connect status selection (`201` first create,
`200` current no-op), Disconnect `204`, locking, idempotency, inactive-User
behavior, and history remain unchanged.

### 5.4 Authorization, Validation, and Errors

Preserve the existing Institution Admin middleware and all current behavior:

- Institution scope derives only from the authenticated actor;
- the path Parent/Student resolves tenant-safely with the exact required role;
- cross-Institution, wrong-role, invalid, and nonexistent path targets remain
  existence-private `404 resource_not_found`;
- accepted query keys, validation, literal search, status filter, sorts,
  direction, pagination, body rejection, and error envelopes do not change;
- inactive related Users remain readable and are represented accurately by
  `related_user.is_active`;
- no new stable error code or endpoint-local error mapping is allowed.

### 5.5 Concurrency and Persistence

N/A — this is a read-response enrichment only. Do not change writes,
transactions, locks, constraints, models, timestamps, or history.

### 5.6 Architecture and Placement

- Actions own tenant-safe joined query construction and selected aliases.
- The new list-item Resource owns exact list serialization only.
- The existing collection owns the existing pagination envelope.
- Controllers stay thin and must not assemble `related_user` manually.
- Models must not gain accessors that hide queries or couple them to this API.
- Do not modify shared middleware, centralized error handling, route structure,
  or unrelated Resources.

---

## 6. Expected Files and Areas

| Path or area | Action | Reason |
|---|---|---|
| `backend/app/Actions/Institution/ListInstitutionParentStudents.php` | Modify | Select safe Student summary aliases |
| `backend/app/Actions/Institution/ListInstitutionStudentParents.php` | Modify | Select safe Parent summary aliases |
| `backend/app/Http/Resources/Institution/InstitutionParentStudentRelationshipListResource.php` | Create | Exact enriched list-item serialization |
| `backend/app/Http/Resources/Institution/InstitutionParentStudentRelationshipCollection.php` | Modify | Use enriched list-item Resource while preserving pagination |
| `backend/tests/Feature/Institution/InstitutionParentStudentsApiTest.php` | Modify | Exact Student summary, privacy, nullability, activity, query-count coverage |
| `backend/tests/Feature/Institution/InstitutionStudentParentsApiTest.php` | Modify | Exact Parent summary and reversed-role coverage |
| `backend/tests/Feature/Institution/InstitutionParentStudentRelationshipMutationApiTest.php` | Inspect/update only if needed | Prove Connect response did not gain `related_user` |

Changes outside these areas require a concrete necessity within scope and must
be reported. Unrelated files must not change.

---

## 7. Acceptance Criteria

- [ ] Both current relationship list endpoints return the exact enriched item.
- [ ] `related_user` is the correct opposite-side User for each endpoint.
- [ ] Nullable contact fields and inactive status serialize exactly.
- [ ] Search/filter/sort/pagination/order behavior is unchanged.
- [ ] List query count remains bounded with multiple rows.
- [ ] No Resource or per-item loop issues database queries.
- [ ] Tenant/role scoping and existence privacy remain unchanged.
- [ ] Connect response remains the exact five-key relationship resource.
- [ ] Connect/Disconnect lifecycle, idempotency, locking, and history are unchanged.
- [ ] No route, schema, error-code, documentation, frontend, or unrelated change is present.
- [ ] Focused verification and delivery complete successfully.

---

## 8. Tests and Proportional Verification

Run from `backend/`:

```bash
./vendor/bin/pint --test

php artisan test \
  tests/Feature/Institution/InstitutionParentStudentsApiTest.php \
  tests/Feature/Institution/InstitutionStudentParentsApiTest.php \
  tests/Feature/Institution/InstitutionParentStudentRelationshipMutationApiTest.php
```

Required focused coverage:

- exact full JSON keys for both list directions;
- correct `related_user.id` cross-field relationship;
- nullable `email`/`phone` and boolean `is_active`;
- inactive related User remains listed;
- search, status, sorting, pagination, and deterministic order remain valid;
- multi-row list query count remains constant;
- cross-tenant/wrong-role/not-found behavior remains private;
- Connect `201` and idempotent `200` responses do not contain `related_user`.

Then from repository root:

```bash
git diff --check
git status --short
```

Perform the focused scope/diff self-review required by root/backend
`AGENTS.md`.

Do not run the full backend suite in this task. After this task is Accepted and
Delivered, Stage 4 Backend Phase 2 must be rerun as a separate read-only
checkpoint before any frontend implementation begins.

Manual smoke is not required; exact feature tests own this API-only change.

---

## 9. Stop Conditions

Stop and report `BLOCKED` instead of inventing a solution if:

- the current implementation materially differs from the context above;
- the response cannot be enriched without a per-row query;
- the change requires schema, route, mutation, authorization, validation,
  lifecycle, error-code, or shared-infrastructure changes;
- the Connect response cannot remain unchanged;
- unrelated user work overlaps the task and cannot be preserved safely;
- required tooling or focused tests are unavailable;
- a required focused check fails outside this task's scope.

---

## 10. GitHub Delivery and Acceptance

After implementation, focused verification, `git diff --check`, and complete
focused self-review pass:

1. stage only task-owned files;
2. inspect the staged diff and secret/safety state;
3. create one focused commit;
4. push one task branch;
5. open a Pull Request to `main`;
6. merge only when required checks pass and merge is permitted;
7. fetch and synchronize local `main`;
8. verify local `main == origin/main`, ahead/behind `0/0`, and clean worktree.

Suggested branch:

```text
feat/s04-be-005-relationship-related-user-summary
```

Suggested commit:

```text
feat(stage4): expose related users in relationship lists
```

Do not update task/Stage bookkeeping, rerun Backend Phase 2, or begin frontend
implementation inside this implementation task.

If implementation and verification pass but safe delivery cannot complete,
report `DELIVERY BLOCKED`.

The task may report `ACCEPTED` only when the delivered result is on
`origin/main` and the final synchronization checks pass.

---

## 11. Codex Final Report

Return:

1. **Status:** `ACCEPTED`, `BLOCKED`, or `DELIVERY BLOCKED`.
2. Implementation summary.
3. Changed files and purpose.
4. Acceptance criteria evidence.
5. Exact verification commands and results.
6. Tenant/privacy/query-count and mutation-compatibility evidence.
7. Scope/diff and `git diff --check` evidence.
8. Commit/PR/merge/final Git synchronization evidence.
9. Exact deviations or blockers.

Do not repeat this contract. Do not start Backend Phase 2 or frontend work.
