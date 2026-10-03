# Stage 10 Task Index — Final Result and Understanding Assessment

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `Stage 10 — Final Result and Understanding Assessment` (`docs/06-roadmap.md` §15) |
| Stage status | `In Progress — backend` |
| Verification model | `Workflow v3 — Lean Verification + Backend/Frontend Phase 2 + Real-Stack Integration`, with the Stage 10 process below |
| Decomposition status | Backend plan `Approved by the Project Owner (2026-10-03)`; frontend plan follows the backend report |
| Planning baseline `origin/main` | `ccab413` (Stage 9 closed; `DEP-FIX-001` merged) |
| Previous Stage | `Stage 9 — Closed / PASS` (`tasks/STAGE_09_CLOSURE_REVIEW.md`) |
| Roles | Claude: contracts, implementation, review, acceptance, checkpoints, **merges each Stage 10 task PR** after review `PASS` and green verification. Project Owner: decisions reserved to the owner, plan approval, review at the backend and frontend boundaries, Android manual smoke |
| Current source of truth | GitHub `main`; re-checked before every contract |

### Stage 10 process (Project Owner, 2026-10-03)

1. Claude writes the backend plan (task list); owner decisions are asked one at a time first.
2. The owner approves the plan; only then are task files created, each in execution order on a fresh
   `main` (`tasks/README.md` §4).
3. Claude implements the tasks one after another: TDD, independent fresh-context review, fixes, PR, and
   Claude merges the PR (never with red tests or an open P1/P2; never force-push or skip hooks).
4. Backend checkpoint (full backend suite + fresh review of the whole Stage 10 backend), then Claude
   reports to the owner and waits.
5. The frontend follows the same way; then real-stack integration, the owner's Android smoke and closure.

## 2. Stage Goal and Boundary

### Goal

Turn the two official task scores into the Student's Topic result — formula, consistency, category,
status, Not completed — that explains itself, is shown to Students and Parents only as the release rules
allow, and is frozen by closure.

### Included

- live Topic result: side states, status precedence, formula, category, Not completed (`S10-T1`, `S10-T3`…`T5`);
- Homework before Blitz: the official Blitz activation closes the official Homework; only Students with a
  submitted Homework start the official Blitz (`S10-D8`);
- Teacher result list and detail, Teacher comment (`S10-D1`);
- Student and Parent visibility with the visibility window (`S10-D2`…`S10-D6`), Attempt-level visibility (`S10-D4`);
- manual release (single and bulk), closure (single, bulk, on Topic archive) when the work is finished (`S10-D7`, `S10-D9`);
- `409 result_closed` guards (`S10-T7`);
- Student Topic-result read, Student Topic detail `result_status`, minimal Parent API (`S10-T8`);
- carried Stage 9 items `PH2-4`, `CL9-9`, `CL9-11` (backend);
- Backend Phase 2, frontend plan and tasks, Frontend Phase 2, real-stack integration, closure.

### Excluded

- Parent screens, children list, dashboards, progress and reports (Stage 11);
- appeals, reopening, hiding a released result, Teacher score override, notifications (post-MVP);
- a rule on the Homework deadline itself (`S10-D8` enforces the order at the Blitz activation instead).

## 3. Existing Foundation (planning audit, 2026-10-03)

- `institution_settings`: `acceptable_score_difference numeric(12,8)`, `student_result_release_mode`,
  `parent_result_release_mode` (null until the Admin's first full `PUT`; never null again).
- `institution_understanding_categories` with the full-partition validator
  (`UnderstandingCategorySetValidator`); empty until the first `PUT`.
- `topic_result_pairs` (`cohort_snapshotted_at`, `locked_at`); `official_task_scores` (rows deleted and
  re-inserted by the resolver; no `unique(institution_id, id)`).
- Stage 9 live official-score read (`OfficialScoreReader`, `OfficialScoreEvaluator`) and
  `StudentResultVisibility` (Blitz condition left to callers — `PH2-4`).
- No `topic_results`, no release or closure, no `result_closed`, no Parent routes; Student Topic detail
  returns a fixed `result_status = waiting_for_homework` that the Student parser enforces.

## 4. Project Owner Decisions (2026-10-03)

| ID | Question | Decision |
|---|---|---|
| `S10-D1` | Topic-result feedback and the Parent-visible flag (`BR-RES-007`, `BR-HW-025`, `docs/04` Teacher Feedback Viewing Flow) | **A** — one optional Teacher comment per Student result; Parent sees it with Parent visibility; no flag; answer feedback stays Student-only |
| `S10-D2` | What the Student and the Parent see (`docs/02:454` vs `docs/04:1548`) | **A** — H, B, final, category, status, comment and a neutral calculation-method line; no consistency, D or T |
| `S10-D3` | Automatic release while the official Blitz is still active (`BR-STAT-013` vs `S09-D5`) | **C2** — visible only when the Blitz is closed and the Homework can no longer be submitted; same gate for manual release |
| `S10-D4` | What a manual release unlocks; practice tasks under `manual_teacher` | **A** — official Attempt results and answer feedback; practice results visible after checking in every mode |
| `S10-D5` | A released result that changes later; hide (`BR-STAT-017` vs `docs/09` §27.7) | **A** — stays released, new values shown at once; no hide |
| `S10-D6` | Settings changes and open results (`BR-CAT-014` vs `BR-CMP-015` vs `docs/06:1936`) | **A** — open results use current settings; closed frozen; mode changes act at once, Teacher releases stay |
| `S10-D7` | Single vs bulk close/release; automatic closure | **A** — bulk actions with skip counts; archiving a Topic closes terminal results |
| `S10-D8` | Contract review: closure could cut off a Student's remaining Homework attempts; the owner's rule “Homework before Blitz” | Activating the official Blitz closes the official Homework; only Students with a submitted Homework Attempt start the official Blitz (others Not completed); no activation while the official Homework is a draft; practice Blitz and #2 unaffected |
| `S10-D9` | When a result can be closed (`BR-RES-011` allowed closure before the tasks end) | Only when the Student's work is finished (the `S10-D3` moment) |
| — | Backend plan | Approved as proposed (§7) |

## 5. Technical Decisions (approved with the plan)

| ID | Decision |
|---|---|
| `S10-T1` | Open results computed live on read; `topic_results` stores comment, releases, closure snapshot; no Scheduler entry |
| `S10-T2` | No reference to `official_task_scores`; snapshot keeps official Attempt ids (tenant FKs to `assessment_attempts`) |
| `S10-T3` | Not completed as soon as one side can no longer be completed; never-designated/never-activated sides wait; precedence Homework → Blitz → review |
| `S10-T4` | Scores ready but threshold or category set missing → `waiting_for_settings` |
| `S10-T5` | Exact decimals; final half-up 8 decimals; `category_score` from the exact final; clients display one decimal |
| `S10-T6` | Topic Teacher access (review rule); Teacher result actions lock group → membership → Topic first; idempotent close/release |
| `S10-T7` | After closure: corrections, comment edit and the official Homework Start → `409 result_closed` (Blitz Start, grant and pair change cannot happen after closure, `S10-D9`); first review allowed |
| `S10-T8` | Parent route group with one result read; `hidden` → no result information; screens in Stage 11 |
| `S10-T9` | Backend change to an existing response ships with the frontend parser change (`S09-T8`) |

The normative contract for all of the above is `S10-DOC-001` §§5-18.

## 6. Planning Audit — Contradictions and Gaps

| # | Finding | Disposition |
|---|---|---|
| 1 | Topic-result feedback undecided; `BR-HW-025` and `docs/09` §§25.4, 30.4 assume it | `S10-D1` |
| 2 | Consistency shown to the Student in `docs/02` only | `S10-D2` |
| 3 | Automatic release reveals B while the Blitz is active | `S10-D3` |
| 4 | Practice results and official Attempt results under `manual_teacher` | `S10-D4` |
| 5 | Hide vs no-unrelease; released result that changes | `S10-D5` |
| 6 | Three rules for settings changes; release-mode snapshots | `S10-D6` |
| 7 | Per-Student-only actions; archived results not read-only | `S10-D7` |
| 8 | RESTRICT FK to rows the resolver deletes; no Attempt references in `docs/08` | `S10-T2` |
| 9 | No trigger for lifecycle- and time-driven status changes of stored results | `S10-T1` |
| 10 | Status precedence, Not completed rules, never-designated Blitz | `S10-T3` |
| 11 | No status for “scores ready, settings missing” | `S10-T4` |
| 12 | `final` can need nine decimals; server vs client rounding | `S10-T5` |
| 13 | Closure races (`docs/07` §33) and lock order across two tasks | `S10-T6` |
| 14 | What closure blocks (only corrections vs scoring, Starts, grants, pair) | `S10-T7` |
| 15 | Parent API vs Stage 11 Parent mobile | `S10-T8` |
| 16 | `Closed` status loses the terminal outcome | `closed_outcome` (`S10-DOC-001` §8.2) |
| 17 | Four calculation methods vs two | Two (`S10-DOC-001` §9) |
| 18 | “All manual review” vs “required review” at closure | Closable rule (`S10-DOC-001` §8.3) |
| 19 | Release error codes undefined; `result_not_visible`, `category_configuration_invalid` unused | `S10-DOC-001` §15 |
| 20 | Student Topic detail `result_status` hard-coded and enforced by the parser | `S10-DOC-001` §14.2 with `S10-T9` |
| 21 | Contract review #1: closure before the tasks end cut off remaining attempts; “Homework before Blitz” not enforced | `S10-D8`, `S10-D9` |
| 22 | Contract review #2: Topic archive without an official Blitz (`S10-D7` closes terminal results, `S10-D9` needs finished work) | At archive no further work is possible, so archive closes every terminal result (both decisions hold); values stay hidden without an official Blitz (`S10-DOC-001` §8.3) |

## 7. Approved Task Order and Current Status

| Order | Task ID | Area | Outcome | Depends on | Readiness | Delivery | Contract |
|---|---|---|---|---|---|---|---|
| `0` | `S10-DOC-001` | Documentation | `docs/01-09` aligned to `S10-D*`/`S10-T*`; this index | Plan approved | `Approved` (on `main` `ccab413`) | Accepted — delivered (PR #316, `main` `cc7a05f`) | `tasks/S10-DOC-001-stage-10-topic-results-contract-alignment.md` |
| `1` | `S10-BE-001` | Backend | Result foundation: `PH2-4` consolidation, `CL9-11` hardening, `topic_results`, calculator, live cohort evaluator (no API) | `DOC-001` | `Approved` (on `main` `cc7a05f`) | Review `PASS`; PR open | `tasks/backend/stage-10/S10-BE-001-topic-result-foundation.md` |
| `2` | `S10-BE-002` | Backend | Teacher result list and detail with the visibility state (the Student/Parent visibility rule), Teacher comment | `BE-001` | `Draft` | Not started | written before implementation |
| `3` | `S10-BE-003` | Backend + FE parser | Release (single, bulk), Student result read, Student Topic detail `result_status`, Stage 9 Student reads per `S10-D4`, Parent route group and read | `BE-002` | `Draft` | Not started | written before implementation |
| `4` | `S10-BE-004` | Backend | Closure and work order: close (single, bulk, Topic archive), `result_closed` guards, Homework before Blitz (`S10-D8`), real-concurrency tests (closure races, `CL9-9`) | `BE-003` | `Draft` | Not started | written before implementation |
| `5` | `S10-BE-PHASE-2` | Backend checkpoint | Full backend suite + fresh review of all Stage 10 backend; then report to the owner and wait | `BE-001…004` | `Draft` | Not started | executed record |
| — | Frontend plan | Frontend | Planned after the owner reviews the backend report | Owner review | — | — | — |

Only a row whose readiness is `Approved` may be implemented.

## 8. Task Intent Notes

- **`S10-BE-001`** changes no response: `StudentResultVisibility` takes the Blitz condition inside and
  the duplicated official rules are consolidated with identical Stage 9 behavior; every `S10-D4`
  behavior change (official release, practice tasks in every mode) ships in `S10-BE-003`.
- **`S10-BE-003`** changes the Student Topic detail `result_status` with the Student parser change in the
  same PR (`S10-T9`); other Stage 9 Student responses change values, not shapes.
- **`S10-BE-004`** adds `409 result_closed` to existing Teacher and Student actions and the `S10-D8`
  behavior to the Stage 8 Blitz activation and Start (`official_homework_not_activated`,
  `homework_not_submitted`). Stage 8/9 tests and E2E seeders that activate an official Blitz while the
  official Homework is open, or start it without a submitted Homework, are updated deliberately and listed
  in its contract. The frontend maps the new codes and shows the activation warning in the frontend plan.

## 9. Checkpoints

- **Backend Phase 2** (`tasks/README.md` §9): fresh-context review of all Stage 10 backend changes and the
  full backend suite (`memory_limit` 512M, about 40 minutes); report to the owner.
- **Frontend Phase 2** (§10), **Integration** (§12), **Closure** (§13): as Stage 9.

## 10. Carried and Deferred Items

| Item | Source | Stage 10 disposition |
|---|---|---|
| Topic-result feedback, Parent flag | Stage 9 planning audit #6 | `S10-D1` |
| `topic_results` reference rule | `S09-BE-002` | `S10-T2` |
| Review-queue Topic, group, Student filters | `CL9-5`, `S09-CL-D1` | Stage 10 frontend plan |
| `CL9-9` real-concurrency tests | Stage 9 closure | `S10-BE-004` |
| `PH2-4` official and visibility rule consolidation | `S09-BE-PHASE-2` | `S10-BE-001` |
| `CL9-10` status visible under `manual_teacher` | Stage 9 closure | Accepted (`BR-STAT-018`) |
| `CL9-11` hardening | Stage 9 closure | `S10-BE-001` |
| `FE-PH2` carried P3 | `S09-FE-PHASE-2` | Stage 10 frontend plan |
| `PH2-1` sweep scan bound | `S09-BE-PHASE-2` | Stage 13 release readiness |

## 11. Current Stage State

- 2026-10-03: planning audit (three read-only surveys: business documents, `docs/07-09`, backend code);
  owner decisions `S10-D1`…`S10-D7`; backend plan approved.
- 2026-10-03: `S10-DOC-001` contract review #1 `NOT ACCEPTED` (P2 = 6, P3 = 9); technical findings fixed;
  owner decisions `S10-D8`, `S10-D9` taken on the closure finding.
- 2026-10-03: contract review #2 `NOT ACCEPTED` (P2 = 3, P3 = 7): Homework close actor and timestamp
  precision, archive without an official Blitz, lock and guard positions; all fixed.
- 2026-10-03: contract review #3 `NOT ACCEPTED` (P2 = 1: archive-closed results without an official Blitz
  must stay unfinished; P3 = 4); all fixed. The contract fixes are mechanical; the documentation review
  checks the final text.
- 2026-10-03: `docs/01-09` aligned by five editors (one per document group) from a shared brief. Documentation
  review #1 (three reviewers: 01-03+05+06, 07-09, 04 + cross-document rules) `NOT ACCEPTED` (P1 = 4,
  P2 = 21); all fixed by three editors. Confirming re-check #2: P1 = 0, P2 = 2 (one wording defect,
  "queued" Homework-close checking, in `docs/04`), P3 = 4; all applied verbatim → `PASS`.
- 2026-10-03: `S10-BE-001` implemented (TDD; reader mutation check 5/5 killed). Review #1 `NOT ACCEPTED`
  (P2 = 3: NULL-passing migration checks, Homework PATCH blank title 500 now 422, missing CL9-11 cases;
  P3 = 6); all fixed. Review #2 `PASS` (one optional P3 applied). Focused suites (`tests/Unit`,
  `Feature/Results`, `Persistence`, `Checking`, `Teacher`, `Student`, `Seeders`): 2687 passed.

## 12. Change Log

- 2026-10-03: index created with `S10-DOC-001`.
