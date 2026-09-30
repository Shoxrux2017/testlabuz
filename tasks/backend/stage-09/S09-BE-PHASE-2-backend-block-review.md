# Phase 2 Read-Only Block Review — Stage 9 Backend

## 1. Review Metadata

| Field | Value |
|---|---|
| Task ID | `S09-BE-PHASE-2` |
| Stage | `Stage 9 — Checking and Scoring` |
| Block | `Backend` (`S09-BE-001` … `S09-BE-007C`) |
| Review mode | `Read-only` |
| Review date | `2026-09-30` |
| Stage index | `tasks/STAGE_09_TASK_INDEX.md` |
| Audited `origin/main` (run #1) | `98747ef931d0e0625593c2cc3bf9a1459a1cd148` |
| Local `main` / ahead-behind | `98747ef` / `0/0`, clean |
| Block diff | `git diff b07bdb1...98747ef -- backend` (158 files, +10881/−232) |
| Review and verification executor | Claude (reviewer role since 2026-09-23); full suite run locally in the project Docker stack |
| Run #1 verdict | `NOT ACCEPTED` — the full backend suite failed one test (§6); run #2 on the fix: `PASS` (§9, §10) |
| Follow-up | `S09-BE-PHASE-2-FIX-001` (§8) |

## 2. Entry Conditions

| Condition | Result | Evidence |
|---|---|---|
| Previous checkpoint | Pass | Stage 8 closed (PR #285); Stage 9 planning PR #287 |
| All block tasks accepted | Pass | `S09-BE-001` … `007C` accepted in index §11 |
| All block tasks delivered | Pass | PRs #290–#300 merged; `main` `98747ef` |
| `main == origin/main`, `0/0`, clean tree | Pass | `git rev-parse HEAD origin/main`, `git status` |
| No blocking dependency | Pass | — |

## 3. Review Inputs

`S09-DOC-001`, the eleven task contracts in `tasks/backend/stage-09/`, the `docs/` sections they cite,
root and backend `AGENTS.md`, index §11 (accepted decisions), and the current code and tests.

## 4. Audited Block Inventory

| Task | Delivered outcome | PR / `main` |
|---|---|---|
| `S09-BE-001` | Checking domain: automatic checker, text normalization, exact score math | #290 `830b9b1` |
| `S09-BE-002` | Scoring persistence (`official_task_scores`), Homework review deadline | #291 `9b772b4` |
| `S09-BE-003A` | Stage 7/8 reads and timeout rules ready for checked Attempts | #292 `f8bf790` |
| `S09-BE-003B` | Checking after every freeze, `attempts:check-frozen` sweep | #293 `d324716` |
| `S09-BE-004` | Official score resolver, recipient scoring lock, sweep repair | #294 `da53031` |
| `S09-BE-005A` | Teacher review access, submission queue and detail | #295 `4737ea8` |
| `S09-BE-005B` | `review_summary`, Teacher submitted-file download | #296 `06fe754` |
| `S09-BE-006` | Teacher review save and correction | #297 `60e62cc` |
| `S09-BE-007A` | Teacher official-score read, shared reader | #298 `1171e24` |
| `S09-BE-007B` | Student Homework results, feedback, official score | #299 `bb6da8b` |
| `S09-BE-007C` | Student finished-Blitz list | #300 `98747ef` |

Every approved task is represented; no unapproved scope entered the block. The Stage 9 dependency change
only declares two already-installed packages (`brick/math` 0.18.0, `symfony/polyfill-intl-normalizer`
1.38.0) as direct requirements; no installed version changed.

## 5. Review Method

Five independent fresh-context reviewers, read-only, each with the same brief (checklist of
`tasks/README.md` §9, severity model, accepted decisions):

| Area | Scope |
|---|---|
| A | Checking domain, pipeline, persistence, review deadline (`001`, `002`, `003A`, `003B`) |
| B | Official score (`004`, `007A`), grant and Start/Submit integration |
| C | Teacher review surface (`005A`, `005B`, `006`) |
| D | Student result visibility (`007B`, `007C`), Student read paths from `003A`, the `007B` Flutter parsers |
| E | Cross-cutting: routes, lock order across all writers, tenant isolation, error contract, Stage 7/8 regression, migration, architecture |

All five reported **P1 = 0, P2 = 0**. Confirmed across the block:

- **Routes:** six HTTP routes and one scheduled command, all inside the existing role groups
  (`auth:sanctum`, `active.account`, `password.changed`, `role:*`). Literal paths are declared before
  parameter paths. Unknown query keys and GET bodies are rejected, and PUT bodies are strict. There is no
  `PUT …/official-score`.
- **Lock order:** checking, sweep, repair, review and grant follow `S09-DOC-001` §8 (the grant takes a
  superset of it). Every other Stage 7/8 path either serializes at the Topic or locks one Attempt only.
  No cycle was found.
- **Tenant isolation:** every new query, join and eager load is scoped by Institution, and by Student or
  Teacher visibility where the path needs it. A foreign-Institution, invisible, in-progress or
  non-recipient id returns the same 404 as a nonexistent one.
- **Errors:** the only new code is `409 automatic_checking_pending`. No internal text leaks. No
  `LogicException` is reachable on valid data.
- **Stage 7/8 preservation:**
  - Submit responses are unchanged, and timeout rules are keyed on `finalization_reason`.
  - `attempt_answers.updated_at` is never changed by checking or review.
  - The 41 re-baselined Stage 7/8 test files move assertions to the checked state and drop none without
    reason.
- **Migration:** reversible. It has composite tenant foreign keys and the required checks and unique
  keys, and the request-path queries are indexed.
- **Student visibility:** matches `S09-DOC-001` §12. Nothing hidden reaches the Student: correct answers,
  per-answer points, checking status, reviewer identity, unreleased scores or feedback, and other
  Students' data all stay out.

## 6. Verification — Run #1 (`98747ef`)

| Check | Command | Result |
|---|---|---|
| Full backend suite | `docker compose … exec -T app php artisan test` | **FAIL** — 1 failed, 2776 passed (62338 assertions), 2433.57 s, exit 1 |
| Format | `docker compose … exec -T app ./vendor/bin/pint --test` | PASS (815 files) |
| Static analysis | none configured in the repository | N/A |
| Whitespace | `git diff --check b07bdb1...98747ef` | PASS |
| Dependency audit (informational) | `composer audit --locked` | 8 advisories in `laravel/framework`, `league/commonmark`, `league/flysystem`, all present before Stage 9 (versions unchanged since `b07bdb1`) |

The failure is `Tests\Feature\Seeders\Stage8E2eSeederTest::test_scheduler_aggregate_is_the_only_exact_candidate_and_keeps_a_future_replacement`
(line 285): expected `timed_out_finalized`, got `checked`. Since `S09-BE-003B`, the Blitz timeout
reconciler drains the checking queue after each freeze, so the seeded Attempt, which has no answers, is
checked at 0. This is a stale Stage 8 assertion, not a product defect. The per-task regression scopes
never included `tests/Feature/Seeders`.

## 7. Findings

| Id | Sev | Finding | Disposition |
|---|---|---|---|
| `F-1` | Blocking | Full suite: stale Stage 8 seeder assertion (§6) | `FIX-001` item 1 |
| `A-1` / `B-3` / `E-1` | P3 | The repair sweep reads every checked official Attempt every minute. Its pair filter is a correlated `EXISTS` with an `OR` that cannot be hashed | The pair filter is fixed in `FIX-001` item 9. The full-history scan is deferred (§11, `PH2-1`) |
| `A-2` | P3 | At a deployment with unchecked history, a sweep longer than 5 minutes lets runs overlap (`withoutOverlapping(5)`). Safe, but duplicate work | Deployment note (§11, `PH2-2`) |
| `A-3` | P3 | The under-lock status re-check in `CheckFrozenAttempt` is untested | `FIX-001` item 3 |
| `B-1` | P3 | Repair sweep tests miss the Blitz half, the eligible-pending probe and the tie order | `FIX-001` item 4 |
| `B-2` | P3 | `S09-DOC-001` §14 and `docs/09` §24.1: row 2 says "same Attempt" (the code also requires the same score, per `007A` §5.2). Row 6 says "repaired by the next sweep", which is not true while a pending Attempt that cannot overtake exists | Stage 9 closure documentation consistency (§11, `PH2-3`) |
| `C-1` | P3 | Review feedback is trimmed with PHP `trim` (ASCII whitespace), so whitespace made only of Unicode characters is stored | Accepted. It is consistent with every strict request, and the Student parser accepts any non-empty feedback, so nothing breaks. `S09-FE-004` must accept the same |
| `C-2` | P3 | No review test on the official Blitz (normal and exception replacement) | `FIX-001` item 5 |
| `C-3` | P3 | "Status never restricts review" is untested for an archived Topic or task | `FIX-001` item 6 |
| `D-1` | P3 | No test of a visible result on an archived finished Blitz | `FIX-001` item 7 |
| `D-2` | P3 | No Homework test of a classmate's official row and feedback under automatic release | `FIX-001` item 8 |
| `D-3` | P3 | `StudentResultVisibility` leaves the Blitz closed/archived condition to its caller's query | Accepted for Stage 9: the only Blitz caller is `finishedQuery`. Stage 10 must add it to the rule if it adds a Blitz caller (§11, `PH2-4`) |
| `E-2` | P3 | Pre-`BE-004` backlog: the repair skips a Student who has a pending eligible Attempt, even one that cannot overtake | Only affects a database that ran `d324716` without `da53031` with the scheduler on (§11, `PH2-5`) |
| `E-3` | P3 | Official designation, the Blitz counting Attempt, Attempt scoring and "best" selection are each implemented in two or three places, consistent today | Accepted. Consolidate when Stage 10 touches them (§11, `PH2-4`) |
| `E-4` | P3 | `TeacherBlitzCloseApiTest` no longer pins the freeze status that checking rewrites | `FIX-001` item 2 |

## 8. Focused Fix

`tasks/backend/stage-09/S09-BE-PHASE-2-FIX-001-seeder-rebaseline-and-test-gaps.md`, commit `5db50d0` on
`fix/s09-be-phase-2-fix-001`:
- `F-1` re-baseline;
- the missing tests `A-3`, `B-1`, `C-2`, `C-3`, `D-1`, `D-2`, `E-4`;
- the uncorrelated pair filter in the repair sweep.

Each new test was seen failing against its mutation:
- dropping the Blitz half, or the `pending.official_score_eligible` condition, from the repair filter;
- flipping the repair tie order;
- swapping the freeze statuses in `BlitzAttemptFinalizer`;
- removing the under-lock re-check;
- the evaluator using the invalidated #1, or the wrong replacement policy;
- a Topic status filter in `TeacherSubmissionAccess`;
- results only for `closed` Blitz;
- dropping the Student filter from the Homework official-row query.

Focused verification: the seven changed test files pass, 149 tests and 4968 assertions. Pint and
`git diff --check` are clean.

An independent fresh-context review of `5db50d0` found P1 = 0, P2 = 0 and one P3: the classmate test's
mutation detection depends on the classmate's row being stored after the Student's. That order is
deterministic in the fixture, and the test can never fail against correct code; commit `03929b0`
documents the dependency in the test.

## 9. Verification — Run #2 (`5db50d0`)

| Check | Result |
|---|---|
| Full backend suite (`php artisan test`) on `5db50d07dd44fc0a94358adef6c3ab4ef310ff9d` | **PASS** — 2787 passed (62398 assertions), 2321.68 s, exit 0; 10 tests more than run #1 |
| Pint on the changed files; `git diff --check` | PASS |
| Later commits | `03929b0` adds a comment to one test, so the run #2 evidence stays valid |

After the fix PR merges, a post-merge check confirms that the merged tree equals the audited branch
tree (`git diff <branch head> main` is empty).

## 10. Verdict

**`PASS`** (run #2):
- P1 = 0 and P2 = 0;
- the required full backend suite passes;
- no unresolved architecture, API, database, security, tenant, lifecycle or cross-task conflict remains.

The remaining P3 items have the dispositions in §7 and §11. `PASS` applies to `main` once
`S09-BE-PHASE-2-FIX-001` is merged. The next gate is `S09-FE-001`.

## 11. Carried Items and Deployment Notes

| Id | Item | Target |
|---|---|---|
| `PH2-1` | Bound the repair sweep's full-history scan. For example, restrict the per-minute pass to recently scored recipients and run a full pass hourly or nightly. The cost is negligible at pilot scale and grows linearly with history | Before post-pilot scale (Stage 13 release readiness) |
| `PH2-2` | At a deployment with unchecked Stage 7/8 history, the first sweeps check it serially and may overlap after 5 minutes. A fresh pilot database has no such history. Otherwise, let one run finish before enabling the per-minute schedule | Stage 9 deployment notes |
| `PH2-3` | Align `S09-DOC-001` §14 and `docs/09` §24.1 rows 2 and 6 with the code (`B-2`) | Stage 9 closure |
| `PH2-4` | Stage 10: add the Blitz condition to `StudentResultVisibility` before any new Blitz caller (`D-3`), and consolidate the duplicated official rules when touching them (`E-3`) | Stage 10 planning |
| `PH2-5` | Pre-`BE-004` backlog (`E-2`). No production database exists. A local or demo database that ran `main` between `d324716` and `da53031` with the scheduler on can hold Students without a row. For those, run one resolve under `RecipientScoringLock` per official recipient that has a checked eligible Attempt | Stage 9 deployment notes |
| — | `composer audit` advisories, present before Stage 9 | Owner decision (offered earlier as a separate task) |
