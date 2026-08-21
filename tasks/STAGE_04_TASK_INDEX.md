# Stage 4 Task Index — Groups and User Relationships

## 1. Stage Metadata

| Field | Value |
|---|---|
| Stage | `Stage 4 — Groups and User Relationships` |
| Stage dependency | `Stage 3 — Institution Administration and User Management` is closed |
| Planning state | `S04-BE-005 Approved; Backend Phase 2 rerun required after delivery` |
| Backend implementation | `S04-BE-001…004 Accepted / Delivered; S04-BE-005 is the next authorized implementation task` |
| Frontend decomposition | `Approved` |
| Frontend task files | `Not yet created; will be prepared one task at a time after S04-BE-005 Accepted / Delivered and Backend Phase 2 rerun PASS` |
| Frontend implementation | `Blocked until S04-BE-005 Accepted / Delivered → Backend Phase 2 rerun PASS` |
| Integration | `Not decomposed; planning is not authorized` |
| Stage closure | `Pending` |

This file is the orchestration map for Stage 4.

It records task order, dependencies, block checkpoints, and Stage progression. It is an input for ChatGPT/project orchestration and Stage tracking.

Codex must **not** read this file to determine implementation behavior. Each Codex run receives only the current approved implementation contract, applicable `AGENTS.md` files, and directly relevant source/tests.

---

## 2. Stage Goal

Stage 4 establishes the structural relationships required for secure learning delivery inside one Institution:

- Institution Groups/classes;
- Teacher ↔ Group membership;
- Student ↔ Group membership;
- Parent ↔ Student relationships;
- historical relationship preservation;
- tenant-safe authorization boundaries required by later learning-delivery Stages.

Stage 4 does not implement Topics, Homework, Blitz, learning delivery, scoring, reporting, or progress workflows.

---

## 3. Approved Stage 4 Backend Decomposition

Backend tasks are implemented sequentially.

Only the next dependency-satisfied task is promoted to `Approved`. Future task contracts may already exist as drafts, but Codex must not start them until their dependency and approval gates pass.

| Order | Task ID | Title | Depends on | Current status | Delivery |
|---:|---|---|---|---|---|
| 1 | `S04-BE-001` | Group and Relationship Persistence Foundation | Stage 3 closed; Stage 4 backend decomposition approved | `Accepted / Delivered` | `Implementation + GitHub delivery` |
| 2 | `S04-BE-002` | Institution Group Management API | `S04-BE-001 Accepted + Delivered` | `Accepted / Delivered` | `Implementation + GitHub delivery` |
| 3 | `S04-BE-003` | Teacher and Student Group Membership API | `S04-BE-001 + S04-BE-002 Accepted + Delivered` | `Accepted / Delivered` | `Implementation + GitHub delivery` |
| 4 | `S04-BE-004` | Parent–Student Relationship API | `S04-BE-003 Accepted + Delivered` | `Accepted / Delivered` | `Implementation + GitHub delivery` |
| 5 | `S04-BE-PHASE-2` | Backend Phase 2 Read-Only Block Review | `S04-BE-001…004 Accepted + Delivered` | `Historical PASS for S04-BE-001…004` | `Read-only checkpoint; no delivery` |
| 6 | `S04-BE-005` | Parent–Student Relationship Related-User Summary | `S04-BE-001…004 Accepted / Delivered`; historical Backend Phase 2 `PASS`; Stage 4 frontend decomposition approval | `Approved` | `Implementation + GitHub delivery` |

### Backend dependency chain

```text
Stage 3 Closed
    ↓
S04-BE-001
    ↓ Accepted + Delivered
S04-BE-002
    ↓ Accepted + Delivered
S04-BE-003
    ↓ Accepted + Delivered
S04-BE-004
    ↓ Accepted + Delivered
Backend Phase 2
    ↓ Historical PASS for S04-BE-001…004
S04-BE-005
    ↓ Accepted + Delivered
Backend Phase 2 Rerun
    ↓ PASS
Frontend Implementation Gate
```

---

## 4. Backend Task Contracts

### S04-BE-001 — Group and Relationship Persistence Foundation

Owns:

- `groups`;
- `group_teacher_memberships`;
- `group_student_memberships`;
- `parent_student_relationships`;
- required tenant-supporting constraints/indexes;
- `GroupStatus`;
- Stage 4 persistence models/relationships/factories;
- focused PostgreSQL persistence verification.

Does **not** own public HTTP APIs.

### S04-BE-002 — Institution Group Management API

Owns:

```text
GET    /api/v1/institution/groups
POST   /api/v1/institution/groups
GET    /api/v1/institution/groups/{group}
PATCH  /api/v1/institution/groups/{group}
POST   /api/v1/institution/groups/{group}/archive
```

Owns Group resource/list/create/update/archive behavior, tenant safety, no-op semantics, counts, and Group lifecycle concurrency.

### S04-BE-003 — Teacher and Student Group Membership API

Owns:

```text
GET    /api/v1/institution/groups/{group}/teachers
POST   /api/v1/institution/groups/{group}/teachers
DELETE /api/v1/institution/groups/{group}/teachers/{teacher}

GET    /api/v1/institution/groups/{group}/students
POST   /api/v1/institution/groups/{group}/students
DELETE /api/v1/institution/groups/{group}/students/{student}
```

Locked POST request shapes:

```json
{
  "teacher_ids": ["uuid-1", "uuid-2"]
}
```

```json
{
  "student_ids": ["uuid-1", "uuid-2"]
}
```

Owns bulk-additive assignment, atomicity, idempotency, removal/history semantics, tenant/role safety, Group archive interaction, User lifecycle interaction, and concurrency.

### S04-BE-004 — Parent–Student Relationship API

Owns the locked public endpoints:

```text
GET    /api/v1/institution/parents/{parent}/students
GET    /api/v1/institution/students/{student}/parents
POST   /api/v1/institution/parent-student-relationships
DELETE /api/v1/institution/parent-student-relationships/{relationship}
```

Owns explicit Parent ↔ Student current relationships, public relationship UUID, historical `ended_at` behavior, same-Institution/role enforcement, idempotency, User lifecycle interaction, and deterministic concurrency.

The obsolete route family below is **not** approved:

```text
/api/v1/institution/parent-student-connections
```

### S04-BE-005 — Parent–Student Relationship Related-User Summary

Owns read-response enrichment for the two existing Parent–Student relationship
list endpoints by adding the related User's safe identity summary. It preserves
the existing mutation responses, routes, authorization, validation, lifecycle,
persistence, and bounded-query behavior.

This is the current `Approved` backend implementation task.

---

## 5. Backend Phase 2 Checkpoint

### Historical result for S04-BE-001…004

The Backend Phase 2 review run after the original backend block remains recorded
as:

```text
PASS
```

That historical result covers:

```text
S04-BE-001 = Accepted + Delivered
S04-BE-002 = Accepted + Delivered
S04-BE-003 = Accepted + Delivered
S04-BE-004 = Accepted + Delivered
```

It does not cover the newly approved `S04-BE-005` change.

### Required rerun after S04-BE-005

Backend Phase 2 must be rerun only after:

```text
S04-BE-005 = Accepted + Delivered
local main == origin/main
ahead/behind = 0/0
working tree = clean
```

Backend Phase 2 is strictly read-only.

Required review scope includes:

- complete Stage 4 backend delta;
- full backend regression suite;
- backend format/static checks;
- route/API contract consistency;
- migrations/schema/constraints/indexes;
- tenant isolation and existence privacy;
- authorization/role boundaries;
- query count/N+1 behavior;
- transactions;
- concurrency;
- idempotency;
- lifecycle;
- cross-task interactions;
- previous-Stage regression risk.

Checkpoint verdicts:

```text
PASS
NOT ACCEPTED
```

`PASS` requires:

```text
P1 = 0
P2 = 0
required verification passes
no unresolved architecture/API/database/security/tenant/lifecycle/cross-task conflict
```

If `NOT ACCEPTED`, ChatGPT prepares focused fix contract(s), the fixes are implemented/verified/delivered, and the affected checkpoint is rerun.

Frontend implementation cannot start until `S04-BE-005` is `Accepted / Delivered`
and the required Backend Phase 2 rerun is `PASS`.

---

## 6. Frontend Block

### Current state

```text
Blocked pending S04-BE-005 Accepted / Delivered → Backend Phase 2 rerun PASS.
```

This is an intentional temporary frontend implementation block while the
approved backend follow-up and its checkpoint are pending.

Frontend decomposition is `Approved`. Frontend task files have not yet been
created and will be prepared one task at a time only after:

```text
S04-BE-005 = Accepted / Delivered
→ Backend Phase 2 rerun = PASS
```

Frontend implementation starts only after:

```text
S04-BE-005 = Accepted / Delivered
→ Backend Phase 2 rerun = PASS
```

That condition is not yet satisfied. The historical Backend Phase 2 `PASS` for
`S04-BE-001…004` does not authorize frontend implementation after `S04-BE-005`
was added to the backend block.

After the required rerun passes, frontend task files will be prepared one task
at a time. As each task is prepared, this same Task Index can be updated with:

- exact `S04-FE-*` tasks;
- task order;
- dependencies;
- acceptance/delivery states;
- Frontend Phase 2 checkpoint.

---

## 7. Frontend Phase 2

Current state:

```text
Not scheduled — frontend task files have not been created yet.
```

When applicable, Frontend Phase 2 runs only after all approved Stage 4 frontend tasks are `Accepted` and `Delivered`.

It is read-only and must end with:

```text
PASS
NOT ACCEPTED
```

Stage integration cannot begin until the required Backend and Frontend Phase 2 checkpoints are both `PASS`.

---

## 8. Integration

Current state:

```text
Not decomposed; planning is not authorized.
```

Do not create the Stage 4 integration implementation contract before:

```text
Required Backend Phase 2 rerun = PASS
Frontend Phase 2 = PASS
```

The future integration task must verify the real Laravel–Flutter workflow, including relevant authentication/session, tenant isolation, relationship access, API/DTO/error boundaries, and required real-stack/E2E behavior.

This Task Index will be updated with the exact `S04-INT-*` task ID only when integration planning becomes current work.

---

## 9. Stage Closure

Stage 4 may be closed only after:

```text
Backend implementation complete
→ Required Backend Phase 2 rerun PASS
→ Frontend implementation complete
→ Frontend Phase 2 PASS
→ Integration complete
→ Required fixes delivered
→ Stage Closure Review PASS
```

Stage closure must verify:

- every approved Stage 4 task is accepted/delivered;
- required checkpoints are PASS;
- integration is complete;
- required security/tenant verification is complete;
- `origin/main` contains the accepted result;
- local `main == origin/main`;
- ahead/behind is `0/0`;
- working tree is clean;
- no unresolved `P1` or `P2` remains.

---

## 10. Task Lifecycle Rules

Stage 4 task statuses:

| Status | Meaning |
|---|---|
| `Draft` | Contract exists but implementation-readiness/dependency gate is not yet open |
| `Approved` | Current task contract is implementation-ready and approved for Codex |
| `In Progress` | Codex is implementing/verifying |
| `Accepted` | Contract satisfied, focused verification passed, delivery completed, result is on `origin/main`, local main synchronized/clean |
| `Blocked` | Planning/dependency/environment/contract issue prevents safe implementation |
| `Delivery Blocked` | Implementation and required verification passed, but safe GitHub delivery could not complete |

Normal task flow:

```text
Git Preflight
→ Implementation
→ Focused Verification
→ Scope/Diff Self-Check
→ GitHub Delivery
→ Task Acceptance
```

Do not run per-task Phase 2 reviews.

---

## 11. Current Stage 4 Progress

| Item | State |
|---|---|
| Stage 3 dependency | `Satisfied` |
| Stage 4 backend decomposition | `Approved` |
| `S04-BE-001` | `Accepted / Delivered` |
| `S04-BE-002` | `Accepted / Delivered` |
| `S04-BE-003` | `Accepted / Delivered` |
| `S04-BE-004` | `Accepted / Delivered` |
| Historical Backend Phase 2 for `S04-BE-001…004` | `PASS` |
| `S04-BE-005` | `Approved` |
| Required Backend Phase 2 rerun | `Pending S04-BE-005 Accepted / Delivered` |
| Frontend decomposition | `Approved` |
| Frontend task files | `Not yet created; will be prepared one task at a time after S04-BE-005 Accepted / Delivered and Backend Phase 2 rerun PASS` |
| Frontend implementation | `Blocked until S04-BE-005 Accepted / Delivered → Backend Phase 2 rerun PASS` |
| Frontend Phase 2 | `Not scheduled` |
| Integration | `Not decomposed; planning is not authorized` |
| Stage Closure | `Pending` |

---

## 12. Next Permitted Gate

The next permitted gate is:

```text
S04-BE-005 implementation
```

`S04-BE-001…004` remain `Accepted / Delivered`, and their historical Backend
Phase 2 result remains `PASS`. The only currently permitted gate is
`S04-BE-005 implementation`. Frontend implementation remains blocked until
`S04-BE-005 Accepted / Delivered → Backend Phase 2 rerun PASS`. Frontend task
files have not yet been created and will be prepared one task at a time only
after that condition is satisfied. Integration remains unplanned.
