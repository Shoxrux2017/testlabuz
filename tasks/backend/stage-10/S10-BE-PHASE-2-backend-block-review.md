# Phase 2 Read-Only Block Review — Stage 10 Backend

## 1. Review Metadata

| Field | Value |
|---|---|
| Task ID | `S10-BE-PHASE-2` |
| Stage | `Stage 10 — Final Result and Understanding Assessment` |
| Block | `Backend` (`S10-BE-001` … `S10-BE-004`) plus the Student parser change shipped with `S10-BE-003` |
| Review mode | `Read-only` |
| Review date | `2026-10-03` |
| Stage index | `tasks/STAGE_10_TASK_INDEX.md` |
| Audited `origin/main` | `4356179b91cfced50ede8d81700fb0440df14756` |
| Local `main` / ahead-behind | `4356179` / `0/0`, clean |
| Block diff | `git diff ccab413...4356179 -- backend` (135 files, +8180/−298) and `frontend/lib/features/student/data/dto/student_topic_dto.dart` |
| Review and verification executor | Claude; the full suite ran locally in the project Docker stack |
| Verdict | `PASS` (§8) |

## 2. Entry Conditions

| Condition | Result | Evidence |
|---|---|---|
| Previous checkpoint | Pass | Stage 9 closed (PR #314); `DEP-FIX-001` (PR #315) |
| Stage contract delivered | Pass | `S10-DOC-001` (PR #316, `main` `cc7a05f`) |
| All block tasks accepted | Pass | `S10-BE-001` … `004`, review `PASS` each (index §11) |
| All block tasks delivered | Pass | PRs #317–#320 merged; `main` `4356179` |
| `main == origin/main`, `0/0`, clean tree | Pass | `git rev-parse HEAD origin/main`, `git status` |
| No blocking dependency | Pass | — |

## 3. Review Inputs

`S10-DOC-001`, the four task contracts in `tasks/backend/stage-10/`, the `docs/` sections they cite, the
owner and technical decisions in index §§4-5, root and backend `AGENTS.md`, and the current code and tests.

## 4. Audited Block Inventory

| Task | Delivered outcome | PR / `main` |
|---|---|---|
| `S10-BE-001` | `topic_results`, exact calculator, live cohort reader; `PH2-4` consolidation; `CL9-11` hardening | #317 `f720b8a` |
| `S10-BE-002` | Teacher result list and detail with the visibility state; Teacher comment; `409 result_closed` | #318 `b096f18` |
| `S10-BE-003` | Release (single, bulk; Student, Parent); Student result read; Topic detail `result_status` with the parser; `S10-D4` Stage 9 reads; Parent route group and read | #319 `48a607a` |
| `S10-BE-004` | Close (single, bulk), archive auto-close; `result_closed` guards; `S10-D8` Homework before Blitz; real-concurrency races including `CL9-9` | #320 `4356179` |

Every approved task is represented; no unapproved scope entered the block. No dependency changed. Stage 10
adds one migration (`2026_10_04_000000`), the `parent` route group and no scheduler entry.

## 5. Review Method

Four independent fresh-context reviewers, read-only, with one shared brief (the `tasks/README.md` §9
checklist, the severity model and the accepted decisions):

| Area | Scope |
|---|---|
| A | Foundation: migration and checks, model, calculator and math, live reader, closed snapshot read-back, `PH2-4`, `CL9-11`, the closure writer from the persistence angle |
| B | Teacher surface: routes, requests, resources, list/detail/comment/release/close/archive, visibility rule, lock order, errors |
| C | Student and Parent reads, Topic detail and parser, `S10-D4` changes to every Stage 9 Student read |
| D | Cross-cutting: `S10-D8`, `result_closed` guards, global lock order across every touched writer, routes, error catalogue, deployment, tenant isolation, Stage 1-9 regression, deliberate test updates, seeders, race infrastructure, carried items |

All four reported **P1 = 0, P2 = 0**. Confirmed across the block:

- **Routes:** nine Teacher routes, one Student route and the new `parent` group, each behind
  `auth:sanctum`, `active.account`, `password.changed` and its role. Literal bulk paths come before the
  `{student}` paths. Requests are strict (unknown query keys and bodies are rejected).
- **Persistence:** `topic_results` matches `S10-DOC-001` §10.1. Every check constraint is NULL-safe. Tenant
  foreign keys are `ON DELETE RESTRICT`, with no reference to `official_task_scores` or
  `topic_result_pairs`. No reachable live result can write a snapshot that violates a check. A closed
  snapshot can always be read back, because the pair cannot change after a closure.
- **Computation:** exact D, a half-up 8-decimal final, a `category_score` that rounds `.5` down, and the
  first-match status precedence of `S10-DOC-001` §8.1. Side states, work finished and closable follow
  §§7.2 and 8.3. The reader runs a constant number of queries.
- **Visibility:** the values reach the Student only for an outcome with finished work, either released
  automatically or by the Teacher. The Parent never sees them before the Student, and gets nothing at all
  in hidden or unconfigured mode. D, T, consistency and `category_score` never reach a Student or Parent.
  Under `S10-D4` a manual Topic release opens the official Attempt results and feedback, and practice
  results are visible in every mode.
- **Locks:** Teacher result actions take group → membership → Topic `FOR UPDATE`. Closure then takes the
  official Attempts `FOR SHARE` in id order, and every `topic_results` writer serializes on the Topic.
  Scoring takes the Topic shared, and Starts, grants and activation take it exclusively. The finalizers
  never take the Topic, and their Attempt order matches. No cycle and no lost update was found. Every
  reader-based read outside a Topic-locked transaction runs in one `REPEATABLE READ READ ONLY` snapshot.
- **`S10-D8`:**
  - The draft-Homework check runs after the timer setting and before the cohort lock.
  - The activation closes an active official Homework exactly like a Teacher close, through the shared
    `LockedHomeworkCloser` and with the cohort step's own locks.
  - A first official Blitz Attempt needs the Student's own terminal Homework Attempt.
  - The now unreachable pair-lock write in the Blitz Start was removed.
- **Errors:** seven new `409` codes, each with an exception, a render mapping and an `ApiErrorContractTest`
  case. Messages match `docs/09` §5.1. No internal text leaks.
- **Tenant isolation and existence privacy:** every new query is scoped by Institution. A foreign,
  invisible or non-cohort target returns the same `404` as a nonexistent one.
- **Tests:**
  - Mutation checks killed every planted defect: 5/5, 6/6, 14/14, 15/15.
  - Six real-concurrency races prove each wait with `pg_blocking_pids`.
  - The deliberate `S10-D4`/`S10-D8` test updates keep each test's subject. Blitz-first history is now
    written as rows.
  - One race dataset whose lock wait no longer exists was removed.

## 6. Verification

| Check | Result |
|---|---|
| Full backend suite on `4356179` (`php -d memory_limit=512M vendor/bin/phpunit`) | **3136 tests, 66708 assertions, exit 0** (32 min 33 s). The 2 PHPUnit notices are the known mock notices in `ProtectedLearningMaterialDownloadApiTest`, from before Stage 10 |
| Pint `--test` | `PASS` (900 files) |
| `git diff --check` | Clean |
| Flutter (Student DTO tests, `analyze`, `format`) | Clean in `S10-BE-003`; no frontend file changed since |

Log: `%TEMP%\testlabuz-s10-be-phase2-full-4356179.txt`.

## 7. Findings

P1 = 0, P2 = 0, P3 = 11.

| Id | Area | Finding | Disposition |
|---|---|---|---|
| `A-1` | Tests | No reader test reads back a closed Not completed snapshot that has a ready side | Owner decision (§10) |
| `A-2` | Tests | The reader test covers a missing official row but not a stale row naming another Attempt; no reader-level `waiting_for_settings` case (unit-covered) | Owner decision (§10) |
| `B-1` | Tests | Release rule order is not tested for an already released result whose window reopened, or for a released result after the mode turns automatic (code correct) | Owner decision (§10) |
| `B-2` | Tests | The calculated list item is not asserted in full (Blitz side, comment) | Owner decision (§10) |
| `B-3` | Frontend | The comment limit counts code points (`mb_strlen`, `char_length`); a Dart client must count `runes`, not `String.length` | Frontend plan |
| `C-1` | Tests | No test proves the Student, Parent and Topic-detail reads run inside the read-only snapshot | Owner decision (§10) |
| `C-2` | Tests | Some visibility cases are covered by unit tests only (closed unreleased result, archive-closed without an official Blitz, Parent reading a closed result, Parent 404s in hidden mode) | Owner decision (§10) |
| `D-1` | Docs | `docs/04`, `05`, `06`, `07`, `09` still say the official Blitz Start writes a null pair lock; since `S10-D8` the Homework Start always took it | Stage 10 closure |
| `D-2` | Harness | The historical Stage 8 E2E harness (`Invoke-Stage8BlitzFirst`, the `main` activation closing `official_homework`, `peer` without a Homework) no longer matches `S10-D8`; the Stage 9 harness does. No seeder needed a change (they write history rows), so index §8's "E2E seeders updated" is reworded | Stage 10 closure record; index §8 reworded here |
| `D-3` | Harness | Stage 8/9 seeder cleanup does not delete `topic_results`; Stage 10 writes on those fixtures would block cleanup on `RESTRICT` keys | Stage 10 integration seeder must own `topic_results` |
| `D-4` | Tests | A removed Blitz-first test also asserted that a non-member Student starts from the persisted cohort with unchanged recipients; still exercised, no longer asserted | Owner decision (§10) |

## 8. Verdict

**`PASS`**:
- P1 = 0 and P2 = 0;
- the required full backend suite passes;
- no unresolved architecture, API, database, security, tenant, lifecycle or cross-task conflict remains.

`PASS` applies to `main` `4356179`. Under the approved Stage 10 process, the next step is the report to the
Project Owner, followed by a wait; the frontend plan starts only after the owner's reply.

## 9. Carried Items and Deployment Notes

| Id | Item | Target |
|---|---|---|
| `PH2-10-1` | Deploy the one Stage 10 migration (`topic_results` and the `attempt_answers` non-empty feedback check). Since Stage 9 the only feedback writer maps an empty value to null, so existing rows satisfy the check. Rollback drops both. No scheduler entry, queue or backfill: open results are live | Stage 10 deployment notes (`docs/07` §36) |
| `PH2-10-2` | The `S10-D8` activation warning ("the official Homework will be closed") and the mapping of `official_homework_not_activated`, `homework_not_submitted`, `result_not_ready_for_closure`, `manual_release_not_allowed`, `result_not_ready`, `student_result_not_released` and `result_closed` | Stage 10 frontend plan |
| `B-3`, `D-1`, `D-2`, `D-3` | As §7 | As §7 |
| Test-hardening P3 (`A-1`, `A-2`, `B-1`, `B-2`, `C-1`, `C-2`, `D-4`) | Optional added tests; no production change | Owner decision (§10) |

## 10. Owner Decision Requested

Whether the seven optional test-hardening items run as one small test-only task before the frontend plan,
or are carried to a later stage. The `PASS` does not depend on them.
