# Stage 9 Task Index — Checking and Scoring

## 1. Stage Metadata

| Field | Value |
|---|---|
| Roadmap stage | `Stage 9 — Checking and Scoring` (`docs/06-roadmap.md` §14) |
| Stage status | `Implementation in progress` |
| Verification model | `Workflow v3 — Lean Verification + Backend/Frontend Phase 2 + Real-Stack Integration` |
| Decomposition status | `Approved by the Project Owner (2026-09-28)` |
| Planning baseline `origin/main` | `b07bdb14` (Stage 8 closed; `API-FIX-001` merged) |
| Previous Stage | `Stage 8 — Closed / PASS` (`tasks/STAGE_08_CLOSURE_REVIEW.md`) |
| Roles | Claude: contracts, readiness, implementation, review, acceptance, checkpoints, closure. Project Owner: decisions reserved to the owner, merges every PR, manual smoke |
| Current source of truth | GitHub `main`; re-checked before every readiness decision |
| Next permitted gate | `S09-FE-PHASE-2-FIX-001` delivery, then Frontend Phase 2 run #2 verdict, then `S09-INT-001` |

This index is the orchestration map for Stage 9. An implementation contract is self-contained; it
never tells the implementer to read this index or the product documents to discover behavior.

## 2. Stage Goal and Boundary

### Goal

Turn frozen Homework and Blitz Attempts into trustworthy scores: automatic checking with the approved
partial credit, Teacher review of judgment answers, a normalized 0–100 Attempt score, and exactly one
official score for the designated Homework and the designated Blitz of each Student.

### Included

- automatic checking of all nine Question types (`S09-D1`, `S09-D9`);
- Answer and Attempt checking-state transitions;
- checking after every freeze, plus a scheduled sweep that also covers pre-Stage-9 history (`S09-T1`);
- Teacher review queue, submission detail, review and correction (desktop only, `S09-D7`);
- Teacher download of submitted answer files (`S09-T5`);
- exact decimal scoring and normalization (`S09-T3`);
- official Homework score with the “could overtake” wait rule (`S09-D2`);
- official Blitz score with exception withdrawal (`S09-D4`);
- practice tasks checked without an official score (`S09-D6`);
- Homework review deadline as a reminder (`S09-D2`);
- Student view of own Attempt result and feedback under the release mode (`S09-D3`, `S09-D5`);
- carried Stage 8 items `CL-6`, `CL-7`;
- Backend Phase 2, Frontend Phase 2, real-stack integration, closure.

### Excluded

- Homework–Blitz comparison, Topic results, categories, release actions, Parent visibility, result
  closure and the `result_closed` correction guard (Stage 10);
- Teacher review on mobile (`S09-D7`); Blitz review deadline;
- showing correct answers or per-Question points to Students;
- changes to Stage 8 monitoring beyond keeping it compatible (`S09-T6`);
- negative marking, AI or fuzzy checking, appeals, review history table.

## 3. Existing Foundation (planning audit, 2026-09-28)

- `questions.points numeric(14,6)`, `questions.checking_mode automatic|manual`; answer keys in normalized
  child tables (`question_choice_options.is_correct`, `question_true_false_answers.correct_value`,
  `question_short_accepted_answers`, `question_matching_items.match_key`,
  `question_ordering_items.correct_position`, `question_fill_blank_accepted_answers`).
- `attempt_answers.checking_status pending|auto_checked|waiting_for_teacher_review|teacher_checked`,
  `awarded_points numeric(16,8)`, `feedback`, `checked_by_user_id`, `checked_at`.
- `assessment_attempts.status` already allows `waiting_for_teacher_review` and `checked`;
  `earned_points`, `possible_points` (Start snapshot), `normalized_score numeric(12,8)`,
  `scoring_completed_at`, `official_score_eligible`.
- Questions cannot change once any Attempt exists (`TeacherQuestionMutationAccess::lock`), so checking
  reads the live Question configuration; no snapshot is needed.
- Missing: any checking code, `official_task_scores`, Teacher answer-read endpoints, Teacher download
  of Student files (`ProtectedStudentSubmissionAccess` is Student-only), all Stage 9 UI.
- Frontend parsers are strict: they reject unknown keys and require `score_visible = false` and
  monitoring `score = null`. This drives `S09-T8`.

## 4. Project Owner Decisions (2026-09-28)

| ID | Question | Decision |
|---|---|---|
| `S09-D1` | Multiple-choice partial credit (`docs/01:185`, `docs/08:1453` vs `BR-Q-009`) | **A** — `BR-Q-009`: correctly selected / total correct; fix `docs/01` and `docs/08` |
| `S09-D2` | Official Homework score: wait or select and re-select (`docs/06:1676` vs `docs/09:4786-4790`) | **A** — wait only for an Attempt that could still overtake; plus an optional Homework review deadline (“check by”) that is a reminder only and never changes scores |
| `S09-D3` | What the Student sees after checking | **A** — Attempt score and Teacher feedback follow the Institution Student release mode; correct answers never; Parents only after release |
| `S09-D4` | Blitz exception after #1 is scored or official | **A** — the grant withdraws #1's official score; without a checked replacement there is no official Blitz score (Stage 10 Not completed); the grant dialog warns the Teacher |
| `S09-D5` | Blitz score visibility while the Blitz is active | **A** — visible only after the Teacher closes the Blitz, then as `S09-D3` |
| `S09-D6` | Practice (non-official) tasks | **A** — checked and reviewed the same way, no official score; queue filter official/practice, official first |
| `S09-D7` | Review on the Teacher's phone | **A** — desktop only; mobile shows read-only “waiting for review” and “overdue” counts |
| `S09-D8` | Autosave (`INT-D2`) timing | **A** — separate task `FE-UX-001` right after plan approval, before Stage 9 code |
| `S09-D9` | Fill-in-the-blank text comparison | **A** — the `BR-Q-013A` normalization of short answers |
| `S09-D8a` | File answers under autosave (`S07-FE-004` forbade upload on pick) | **A** — upload right after the file is chosen; no Upload button |
| — | Decomposition | **A** — approved as proposed (§7) |

## 5. Technical Decisions (approved with the decomposition)

| ID | Decision |
|---|---|
| `S09-T1` | Automatic checking runs right after the freezing transaction commits, outside it, plus a scheduled sweep every minute (backfill and retries). Freeze responses do not change |
| `S09-T2` | Stage 8 Blitz rules keyed on status `timed_out_finalized` are keyed on `finalization_reason = timeout_auto_submit`, so error codes do not change after checking |
| `S09-T3` | Exact decimal arithmetic; one rounding (half-up, 8 decimals) when storing; display one decimal |
| `S09-T4` | Review: partial saves allowed; 0..Question points; feedback ≤ 2000 characters; concurrent saves serialize; corrections allowed until Stage 10 adds the closure guard |
| `S09-T5` | A Teacher may download a submitted file only for an accessible submission |
| `S09-T6` | Stage 8 monitoring keeps its wire format; scores are read from the review resources |
| `S09-T7` | An invalidated Blitz #1 is checked for history, never official, never blocking |
| `S09-T8` | A backend change to an existing response ships in the same PR as the frontend parser change that accepts it, so `main` never breaks between PRs |

The exact normative contract for all of the above is `S09-DOC-001` §§4-14.

## 6. Planning Audit — Contradictions and Gaps

| # | Finding | Disposition |
|---|---|---|
| 1 | Multiple-choice formula contradiction | `S09-D1` |
| 2 | Official Homework: wait vs re-select; “potentially highest” undefined | `S09-D2`; rule in `S09-DOC-001` §8 |
| 3 | When automatic checking runs; backfill of Stage 7/8 history | `S09-T1` |
| 4 | Blitz timeout error codes would change once history moves to `checked` | `S09-T2` |
| 5 | Student visibility of scores and feedback | `S09-D3`, `S09-D5` |
| 6 | Where feedback lives (per answer vs Topic result vs Parent-visible flag) | Stage 9: per-answer feedback only; Topic-result feedback and any Parent-visible flag are raised at Stage 10 planning |
| 7 | Monitoring with Stage 9 data | `S09-T6` |
| 8 | Exception granted after #1 is checked or official; #2 never taken | `S09-D4` |
| 9 | Correction closure guard without Stage 10 tables | `S09-DOC-001` §10.6 |
| 10 | Unmapped error codes; review validation undefined | `S09-DOC-001` §§10.5, 13 |
| 11 | Fill-in-the-blank normalization undefined | `S09-D9` |
| 12 | Storage rounding at 8 decimals | `S09-T3` |
| 13 | “Explicitly configured manual” wording; unanswered or empty manual answers | `S09-DOC-001` §5 (only `short_written` can be switched to manual; unanswered = 0; an empty answer cannot exist because clearing deletes the row) |
| 14 | Practice tasks | `S09-D6` |
| 15 | “Invalidated” Student status vs stored status | Derived from `official_score_eligible`; stored status follows normal checking (`S09-T7`) |
| 16 | Review history | Actor fields only (existing `docs/08` decision) |
| 17 | Stale lines (`docs/09:42`, `FINAL_AUDIT_REPORT.md:56-58`, duplicate `BR-HW-021`) | `S09-DOC-001` §3 |
| 18 | Teacher cannot download Student files | `S09-T5` |
| 19 | Strict frontend parsers reject new fields/values | `S09-T8` |

## 7. Approved Task Order and Current Status

| Order | Task ID | Area | Outcome | Depends on | Readiness | Delivery | Contract |
|---|---|---|---|---|---|---|---|
| `0` | `FE-UX-001` | Frontend (platform) | Student answer autosave; no Save button; no jump to Question 1 | Decomposition approved | `Approved` (revalidated on `main` `3ad88fb`) | Accepted — delivered (PR #288, `main` `4432f27`) | `tasks/frontend/FE-UX-001-student-answer-autosave.md` |
| `1` | `S09-DOC-001` | Documentation | `docs/01-09` aligned to `S09-D*`/`S09-T*` | `FE-UX-001` delivered | `Approved` (revalidated on `main` `4432f27`) | Accepted — delivered (PR #289, `main` `4cff8af`) | `tasks/S09-DOC-001-stage-09-checking-scoring-contract-alignment.md` |
| `2` | `S09-BE-001` | Backend | Checking domain: the seven automatic checkers, checking route, text normalizer, exact decimal score arithmetic; `brick/math` and the NFC polyfill declared as direct dependencies | `DOC-001` | `Approved` (on `main` `4cff8af`) | Accepted — delivered (PR #290, `main` `830b9b1`) | `tasks/backend/stage-09/S09-BE-001-checking-domain.md` |
| `3` | `S09-BE-002` | Backend + FE parser | `official_task_scores`, `review_due_at` (+ Teacher Homework create/update and the review-due-at endpoint) | `BE-001` | `Approved` (on `main` `830b9b1`) | Accepted — delivered (PR #291, `main` `9b772b4`) | `tasks/backend/stage-09/S09-BE-002-scoring-persistence-review-deadline.md` |
| `4a` | `S09-BE-003A` | Backend | Checking readiness: `S09-T2` timeout rekey, historical Homework reads (no checking yet) | `BE-002` | `Approved` (on `main` `9b772b4`) | Delivered (PR #292, `main` `f8bf790`) | `tasks/backend/stage-09/S09-BE-003A-checking-readiness.md` |
| `4b` | `S09-BE-003B` | Backend | Automatic checking pipeline, post-freeze trigger, minute sweep, deliberate Stage 7/8 test updates | `BE-003A` | `Approved` (on `main` `f8bf790`) | Delivered (PR #293, `main` `d324716`) | `tasks/backend/stage-09/S09-BE-003B-checking-pipeline.md` |
| `5` | `S09-BE-004` | Backend | Official score resolver (Homework, Blitz, grant withdrawal, sweep repair) | `BE-003B` | `Approved` (on `main` `d324716`) | Delivered (PR #294, `main` `da53031`) | `tasks/backend/stage-09/S09-BE-004-official-score-resolver.md` |
| `6a` | `S09-BE-005A` | Backend | Review access rule, submission queue (existing indexes suffice), submission detail | `BE-004` | `Approved` (on `main` `da53031`) | Delivered (PR #295, `main` `4737ea8`) | `tasks/backend/stage-09/S09-BE-005A-review-queue-and-detail.md` |
| `6b` | `S09-BE-005B` | Backend + FE parser | `review_summary` on Teacher task details, Teacher submitted-file download | `BE-005A` | `Approved` (on `main` `4737ea8`) | Delivered (PR #296, `main` `06fe754`) | `tasks/backend/stage-09/S09-BE-005B-review-summary-and-file-download.md` |
| `7` | `S09-BE-006` | Backend | Review save and correction, recalculation | `BE-005A` | `Approved` (on `main` `06fe754`) | Delivered (PR #297, `main` `60e62cc`) | `tasks/backend/stage-09/S09-BE-006-review-save-and-correction.md` |
| `8a` | `S09-BE-007A` | Backend | Teacher official-score read; shared official-score reader | `BE-006` | `Approved` (on `main` `60e62cc`) | Delivered (PR #298, `main` `1171e24`) | `tasks/backend/stage-09/S09-BE-007A-teacher-official-score-read.md` |
| `8b` | `S09-BE-007B` | Backend + FE parser | Student Homework `result`, answer `feedback`, `attempt_results`, `score_visible`/`official_score` | `BE-007A` | `Approved` (on `main` `1171e24`) | Delivered (PR #299, `main` `bb6da8b`) | `tasks/backend/stage-09/S09-BE-007B-student-homework-results.md` |
| `8c` | `S09-BE-007C` | Backend | `GET /student/blitz/finished` with the counting Attempt's result and feedback | `BE-007A` | `Approved` (on `main` `bb6da8b`) | Delivered (PR #300, `main` `98747ef`) | `tasks/backend/stage-09/S09-BE-007C-student-finished-blitz.md` |
| `9` | `S09-BE-PHASE-2` | Backend review | Full Stage 9 backend review + full backend suite | `BE-001…007C` | Executed record | `PASS` — run #1 `NOT ACCEPTED` (`98747ef`); run #2 `PASS` (`5db50d0`); delivered (PR #301, `main` `95992d3`) | `tasks/backend/stage-09/S09-BE-PHASE-2-backend-block-review.md` |
| `9a` | `S09-BE-PHASE-2-FIX-001` | Backend fix | Stage 8 seeder test re-baseline, Phase 2 test gaps, repair pair filter | Phase 2 run #1 | `Approved` (on `main` `98747ef`) | Delivered (PR #301, `main` `95992d3`) | `tasks/backend/stage-09/S09-BE-PHASE-2-FIX-001-seeder-rebaseline-and-test-gaps.md` |
| `10a` | `S09-FE-001A` | Frontend | Exception-grant warning, `CL-6`, `CL-7` | Backend Phase 2 PASS | `Approved` (on `main` `95992d3`) | Delivered (PR #302, `main` `5aaf9a5`) | `tasks/frontend/stage-09/S09-FE-001A-grant-warning-cl6-cl7.md` |
| `10b` | `S09-FE-001B` | Frontend | Homework review deadline: display and set/clear on the Homework detail | `FE-001A` | `Approved` (on `main` `5aaf9a5`) | Delivered (PR #303, `main` `6ed9b7a`) | `tasks/frontend/stage-09/S09-FE-001B-homework-review-deadline.md` |
| `11a` | `S09-FE-002A` | Frontend | Desktop review queue `/teacher/reviews`: filters, sort, pages | `FE-001B` | `Approved` (on `main` `6ed9b7a`) | Delivered (PR #304, `main` `f3cbefa`) | `tasks/frontend/stage-09/S09-FE-002A-review-queue.md` |
| `11b` | `S09-FE-002B` | Frontend | Task review counts on Homework/Blitz detail (all surfaces); task-scoped desktop queue | `FE-002A` | `Approved` (on `main` `f3cbefa`) | Delivered (PR #305, `main` `bf6df48`) | `tasks/frontend/stage-09/S09-FE-002B-task-review-counts.md` |
| `12a` | `S09-FE-003A` | Frontend | Desktop submission detail (every Question and answer), Teacher file download | `FE-002B` | `Approved` (on `main` `bf6df48`) | Delivered (PR #306, `main` `8d401ca`) | `tasks/frontend/stage-09/S09-FE-003A-submission-detail.md` |
| `12b` | `S09-FE-003B` | Frontend | Review save and correction (points, feedback) | `FE-003A` | `Approved` (on `main` `8d401ca`) | Delivered (PR #307, `main` `1983fdc`) | `tasks/frontend/stage-09/S09-FE-003B-review-save.md` |
| `12c` | `S09-FE-003C` | Frontend | Official-score panel on the submission | `FE-003B` | `Approved` (on `main` `1983fdc`) | Delivered (PR #308, `main` `473d8a0`) | `tasks/frontend/stage-09/S09-FE-003C-official-score-panel.md` |
| `13a` | `S09-FE-004A` | Frontend | Student Homework results: official score, Attempt results, Teacher feedback | `FE-003C` | `Approved` (on `main` `473d8a0`) | Delivered (PR #309, `main` `c1082e5`) | `tasks/frontend/stage-09/S09-FE-004A-homework-results.md` |
| `13b` | `S09-FE-004B` | Frontend | Finished Blitz list with results (`GET /student/blitz/finished`) | `FE-004A` | `Approved` (on `main` `c1082e5`) | Delivered (PR #310, `main` `6e58259`) | `tasks/frontend/stage-09/S09-FE-004B-finished-blitz.md` |
| `14` | `S09-FE-PHASE-2` | Frontend review | Full Stage 9 frontend review + full verification | `FE-001…004` | Executed record | Run #1 `NOT ACCEPTED` (`6e58259`, one P2); run #2 pending on `FIX-001` | `tasks/frontend/stage-09/S09-FE-PHASE-2-frontend-block-review.md` |
| `14a` | `S09-FE-PHASE-2-FIX-001` | Frontend fix | Related-view refresh after a review save (P2) and five user-visible P3 defects (`S09-FE-PH2-D1`) | Phase 2 run #1 | `Approved` (on `main` `6e58259`) | Implemented — PR open | `tasks/frontend/stage-09/S09-FE-PHASE-2-FIX-001-related-refresh-and-ux-defects.md` |
| `15` | `S09-INT-001` | Integration | Real-stack Windows + Android: checking, review, official scores, visibility, files, security | Both Phase 2 PASS | Not written | Not started | `tasks/integration/stage-09/` |
| `16` | `STAGE_09_CLOSURE_REVIEW` | Closure | Stage-wide review and closure | `INT-001` PASS | Not written | Not started | `tasks/STAGE_09_CLOSURE_REVIEW.md` |

Detailed contracts for rows 2-16 are written in execution order, each after re-checking `main`.
Only a row whose readiness is `Approved` may be implemented.

## 8. Task Intent Notes

- **`FE-UX-001`** is platform work outside the Stage count (like `API-FIX-001`). It changes closed
  Stage 7/8 Student screens deliberately (`S09-D8`) and updates `BR-SUB-004` and `docs/06` §19.11.
- **`S09-BE-001`** is pure domain code with unit tests for every roadmap scoring test; no persistence
  or API.
- **`S09-BE-002`** includes the Teacher Homework API field and the Teacher Homework parser change
  (`S09-T8`); no UI.
- **`S09-BE-003`** (delivered as `S09-BE-003A` readiness + `S09-BE-003B` pipeline) changes the Stage 7/8
  freeze paths only by adding the post-commit checking trigger
  (`app()->terminating`, not a queued job), rekeys the Stage 8 Start/Resume and Submit timeout rules
  (`S09-T2`), and switches Homework Student reads and Submit replays to the historical answer
  canonicalization (today they fail on non-`pending` answers). It uses the `S09-DOC-001` §8 lock order
  (parents shared → recipient → Attempts → answers → official row), which serializes with
  `UpdateTeacherHomework` and `SetTeacherTopicResultPair` instead of deadlocking. The trigger is one
  request-scoped collector with a single terminating callback that drains its ids. Because checking now runs
  at the end of every freezing request, the Stage 7/8 feature tests that assert an unchecked state after an
  HTTP or console freeze (for example `StudentHomeworkAttemptSubmitIdempotencyTest`,
  `StudentHomeworkAttemptSubmitLifecycleTest`, `StudentBlitzAttemptSubmitApiTest`,
  `ReconcileHomeworkDeadlinesCommandTest`, `ReconcileBlitzTimeoutsCommandTest`) are updated deliberately and
  listed in the contract: their assertions on frozen fields stay; assertions that answers or Attempts stay
  unchecked become the Stage 9 checked state. Query-count assertions are re-baselined only where the new
  checking queries appear. No test switch disables the trigger. It must verify that Submit replay and
  Student reads of `waiting_for_teacher_review`/`checked` Attempts are accepted by the current frontend; any
  needed parser change ships with it.
- Checking (`S09-BE-003B`) and review (`S09-BE-006`) never change `attempt_answers.updated_at`: Student
  reads return it as the time of the Student's last save, so a checking or review write that bumped it
  would change a Stage 7/8 response and reveal when checking happened. Write with the query builder or
  `withoutTimestamps`, and test with time moved forward.
- **`S09-BE-004`** also changes the Stage 8 exception grant (withdrawal in the same transaction).
- **`S09-BE-005B`** adds `review_summary` to Teacher Homework/Blitz details with the parser change.
- **`S09-BE-007`** adds Student `result`, answer `feedback`, `score_visible`/`official_score` with the
  Student parser change; display comes in `S09-FE-004`.
- **Frontend tasks** follow the existing desktop/mobile gates (`app_device_surface.dart`,
  `_TeacherDestinationGate`): review screens are desktop-only.

## 9. Checkpoints

- **Backend Phase 2** (`tasks/README.md` §9): fresh-context review of all Stage 9 backend changes and
  the full backend suite (`memory_limit` 512M, about 30 minutes).
- **Frontend Phase 2** (§10): fresh-context review, full `flutter test`, analyze, format check,
  Windows and Android debug builds.
- **Integration** (§12): guarded real-stack run on Windows plus Android manual smoke by the Project
  Owner, covering automatic checking through the scheduler, review, official selection including an
  exception, both release modes, Teacher file download, and Tenant/privacy checks.
- **Closure** (§13): Stage-wide review, documentation consistency, deferred-item dispositions.

## 10. Carried and Deferred Items

| Item | Source | Stage 9 disposition |
|---|---|---|
| `CL-6` `authorityStateAtStart` typed `Object` | Stage 8 closure (`CL-D1`) | `S09-FE-001A` |
| `CL-7` Homework activation lacks `official_cohort_mismatch` | Stage 8 closure (`CL-D1`) | `S09-FE-001A` |
| `INT-D2` autosave | Stage 8 integration | `FE-UX-001` (`S09-D8`) |
| Topic-result feedback, Parent-visible feedback flag | Planning audit #6 | Stage 10 planning |
| `topic_results.official_homework_score_id`/`official_blitz_score_id` default to `ON DELETE RESTRICT` (`docs/08` §§25.13-25.14), while Stage 9 deletes `official_task_scores` rows (exception grant; score no longer ready); a tenant-safe composite reference also needs `unique(institution_id, id)` on `official_task_scores`, which Stage 9 does not add | `S09-DOC-001`, `S09-BE-002` | Stage 10 planning: decide the reference rule before `topic_results` exists |
| `PH2-1` bound the repair sweep's full-history per-minute scan | `S09-BE-PHASE-2` | Before post-pilot scale (Stage 13 release readiness) |
| `PH2-2` first sweeps over unchecked Stage 7/8 history may overlap after 5 minutes | `S09-BE-PHASE-2` | Stage 9 deployment notes |
| `PH2-3` `S09-DOC-001` §14 / `docs/09` §24.1 rows 2 and 6 wording | `S09-BE-PHASE-2` | Stage 9 closure |
| `PH2-4` Blitz condition inside `StudentResultVisibility`; consolidate duplicated official rules | `S09-BE-PHASE-2` | Stage 10 planning |
| `PH2-5` pre-`BE-004` backlog (databases that ran `d324716` without `da53031`): one-off resolve | `S09-BE-PHASE-2` | Stage 9 deployment notes |
| `FE-PH2` carried P3 (`S09-FE-PH2-D1`): `A-2` autosave focus/pause widget tests; `B-2` archived message shown twice; `B-3` unreachable 500 test; `B-4` date-picker year range; `B-5` import order; `C-3` review validation announcement and focus; `C-4` detail screen size and controller boilerplate; `D-3` role test on review paths; `D-4` duplicated `scoreVisible` | `S09-FE-PHASE-2` §7 | Stage 10 planning or a later polish task |

## 11. Current Stage State

- 2026-09-28: planning audit done; owner decisions `S09-D1`…`D9` and the decomposition approved.
- Planning package (this index, `FE-UX-001`, `S09-DOC-001`) delivered by the `docs/stage9-planning` PR.
- Planning package merged (PR #287, `main` `3ad88fb`).
- `FE-UX-001` readiness revalidated on `3ad88fb` (no Student screen change since the contract); implemented on
  `feat/fe-ux-001-student-answer-autosave`; PR open. Next after merge: `S09-DOC-001`.
- 2026-09-29: `FE-UX-001` accepted and delivered (PR #288, `main` `4432f27`) after two independent
  fresh-context reviews (all findings fixed with failing-first tests); merged by the Project Owner.
- `S09-DOC-001` readiness revalidated on `4432f27`: its dependency is delivered and the documents changed
  since the planning baseline only in the `FE-UX-001` autosave lines. Implementation in progress on
  `docs/s09-doc-001-checking-scoring-alignment`.
- `S09-DOC-001` implemented; the independent fresh-context review found P1 = 0, P2 = 1, P3 = 8, all fixed and
  re-verified (final P1 = 0, P2 = 0). PR open. Next after merge: `S09-BE-001` contract and readiness.
- `S09-DOC-001` accepted and delivered (PR #289, `main` `4cff8af`).
- `S09-BE-001` contract written and approved on `4cff8af`; implemented on `feat/s09-be-001-checking-domain`.
  Independent fresh-context review: P1 = 1, P2 = 4, P3 = 6, all fixed with tests and mutation checks;
  re-verification P1 = 0, P2 = 0 (three new P3 also fixed). PR open.
- `S09-BE-001` accepted and delivered (PR #290, `main` `830b9b1`).
- `S09-BE-002` contract written and approved on `830b9b1`; the review-queue index moves to `S09-BE-005`,
  where the queue query shape is defined. Implemented on `feat/s09-be-002-scoring-persistence-review-deadline`.
  Independent review: P1 = 0, P2 = 2 (a `review_due_at`-only PATCH re-synchronized recipients; update-path
  parsing untested), P3 = 6; fixed with tests, except the optional strict-request noise item (kept: it only
  adds messages to already-rejected requests).
- `S09-BE-002` accepted and delivered (PR #291, `main` `9b772b4`).
- `S09-BE-003` is split: `S09-BE-003A` makes Stage 7/8 reads and timeout rules ready for checked Attempts
  (no status or answer changes); `S09-BE-003B` adds the checking pipeline, trigger, sweep and the deliberate
  Stage 7/8 test updates. `S09-BE-003A` approved on `9b772b4` and implemented.
  Independent review: P1 = 0, P2 = 3, P3 = 4. Fixed: the Blitz Start timeout re-read after its commit now
  reads under a shared Attempt lock and, when Stage 9 already checked the Attempt, through a timeout re-read
  proof (a PostgreSQL trigger test reproduces the race); exception-first ordering, replacement timeout and
  pending-metadata tests added. Carried to `S09-BE-003B` and `S09-BE-006`: checking and review keep
  `attempt_answers.updated_at` unchanged (the Student sees it as the answer's last save). Re-verification:
  P1 = 0, P2 = 0; its two new P3 (accept every finalization reason in the re-read proof; tie intent to the
  Attempt number) are fixed.
- `S09-BE-003A` accepted and delivered (PR #292, `main` `f8bf790`).
- `S09-BE-003B` contract written and approved on `f8bf790`; no frontend change (every Student read and replay
  already accepts checked Attempts). Implemented on `feat/s09-be-003b-checking-pipeline`: 27 Stage 7/8 test
  files deliberately re-baselined to the checked state (listed in the PR). Independent review: P1 = 0,
  P2 = 1 (zero credit untested for most automatic types, including a `false` true/false key), P3 = 6; all
  fixed with tests except the sweep/Homework-Submit re-read window, documented in the PR (Student reads
  accept checked Attempts). Re-verification: P1 = 0, P2 = 0, no new P3; its carried P3 is fixed.
- `S09-BE-003B` accepted and delivered (PR #293, `main` `d324716`).
- `S09-BE-004` contract written and approved on `d324716`. The sweep repair follows the documented narrow
  rule (`docs/05` BR-ATT-021, `docs/07` §16.5, `docs/08` §19): a Student with a `checked` eligible Attempt
  and no pending eligible Attempt whose row is missing or stale. Implemented on
  `feat/s09-be-004-official-score-resolver`; no Stage 7/8 test needed a change. Independent review: P1 = 0,
  P2 = 0, P3 = 6; the four test/code P3 are fixed; the sweep's full-history scan cost and the pre-`BE-004`
  backlog (Students checked by `BE-003B` alone whose pending Attempt cannot overtake) are recorded for Backend
  Phase 2 and the Stage 9 deployment.
- `S09-BE-004` accepted and delivered (PR #294, `main` `da53031`).
- `S09-BE-005` is split: `S09-BE-005A` (review access, submission queue and detail; new read-only endpoints,
  no parser change) and `S09-BE-005B` (`review_summary` on the Teacher Homework and Blitz resources with the
  Teacher parser change, and the Teacher submitted-file download). The queue needs no new index: the existing
  `assessment_attempts(institution_id, assessment_id, status)` and `attempt_answers(attempt_id, question_id)`
  indexes serve it. `S09-BE-005A` approved on `da53031`. Review correction applied in `005A`: the submission
  detail's Question configuration also carries the ids that the Student answer value refers to (options,
  matching items, ordering items, blanks), otherwise the Teacher cannot tell what the Student chose;
  `docs/09` §21.2 and `S09-DOC-001` §10.3 updated. Independent review: P1 = 0, P2 = 4 (the answer ids above;
  missing tests for a mismatched recipient row and a foreign-Institution detail; the `official` subquery not
  keyed by Topic), P3 = 8; all fixed except a declined read snapshot for the detail. Re-verification: P1 = 0,
  P2 = 0; its five P3 are fixed.
- `S09-BE-005A` accepted and delivered (PR #295, `main` `4737ea8`).
- `S09-BE-005B` contract written and approved on `4737ea8`. Implemented on
  `feat/s09-be-005b-review-summary-file-download` with the Flutter Teacher parser change (`S09-T8`). Independent
  review: P1 = 0, P2 = 1 (the Teacher download path was not tested directly), P3 = 7; all fixed except a
  shared download helper that would touch the Student path. Re-verification: P1 = 0, P2 = 0, P3 = 0.
- `S09-BE-005B` accepted and delivered (PR #296, `main` `06fe754`).
- `S09-BE-006` contract written and approved on `06fe754`. Implemented on
  `feat/s09-be-006-review-save-correction`. Independent review: P1 = 0, P2 = 1 (no test proved that access,
  state and items are evaluated again under the scoring locks), P3 = 5; all fixed (the new test was
  mutation-checked against each removed re-check). Re-verification: P1 = 0, P2 = 0, P3 = 0.
- `S09-BE-006` accepted and delivered (PR #297, `main` `60e62cc`).
- `S09-BE-007` is split: `S09-BE-007A` (Teacher official-score read and the shared reader that `007B`
  reuses; new endpoint, no parser change), `S09-BE-007B` (Student Homework `result`, answer `feedback`,
  `attempt_results`, `score_visible`/`official_score`: existing Student responses change, so the Student
  parser change ships with it) and `S09-BE-007C` (`GET /student/blitz/finished`: new endpoint, parsed in
  `S09-FE-004`). `S09-BE-007A` approved on `60e62cc`; a `ready` read requires the row to match the live
  best Attempt on both id and score (the sweep's definition of a differing row). Review correction: the
  read runs in one repeatable-read snapshot, because a grant or replacement start committed between the
  Blitz Attempt and exception reads made the evaluator fail. Independent review: P1 = 0, P2 = 2 (that
  race; no test of an active Blitz without an exception), P3 = 3 (attempt-only differing row, practice task
  beside a designated pair, archived Topic); all fixed and mutation-checked. Re-verification: P1 = 0,
  P2 = 0, P3 = 0.
- `S09-BE-007A` accepted and delivered (PR #298, `main` `1171e24`).
- `S09-BE-007B` contract written and approved on `1171e24`: the Student Homework list reads official
  scores in a constant number of queries (the evaluator reuses preloaded answers), Blitz and `PUT` answer
  responses keep their shape, and Start responses gain `result` because they share the Attempt resource.
  Implemented with the Student parser change. Independent review: P1 = 0, P2 = 1 (a missing stored row was
  not isolated from a not-ready evaluation), P3 = 7; all fixed and mutation-checked. Review correction: the
  parser accepts any non-empty feedback, because the server trims only ASCII whitespace and a Unicode-only
  feedback would otherwise fail the Student read. Re-verification: P1 = 0, P2 = 0, P3 = 1 (fixed).
- `S09-BE-007B` accepted and delivered (PR #299, `main` `bb6da8b`).
- `S09-BE-007C` contract written and approved on `bb6da8b`: a finished Blitz cannot gain an exception or an
  Attempt, so the list reads without a snapshot; the release mode and the visible feedback are read once
  per page. Independent review: P1 = 0, P2 = 1 (no test of a classmate's data on the same Blitz), P3 = 5;
  all fixed and mutation-checked. Review correction: the Attempt visibility rule is one shared class
  (`StudentResultVisibility`) for `007B` and `007C`. Re-verification: P1 = 0, P2 = 0. PR open.
- `S09-BE-007C` accepted and delivered (PR #300, `main` `98747ef`). All backend tasks are delivered.
- 2026-09-30: `S09-BE-PHASE-2` on `98747ef`: five independent fresh-context reviewers (checking, official
  score, Teacher review, Student visibility, cross-cutting) found P1 = 0, P2 = 0 and 15 P3 findings.
  Pint (815 files) and `git diff --check` passed. Full suite run #1: 1 failed, 2776 passed. The failure was
  a stale Stage 8 seeder assertion that expected an unchecked timeout after `S09-BE-003B`. Run #1
  verdict: `NOT ACCEPTED`.
- `S09-BE-PHASE-2-FIX-001`:
  - re-baselines the seeder test;
  - adds the seven missing tests the review asked for, each seen failing against its mutation;
  - makes the repair sweep's pair filter an uncorrelated row-value set.
  Independent review: P1 = 0, P2 = 0, P3 = 1 (fixed). Full suite run #2 on `5db50d0`: 2787 passed
  (62398 assertions), exit 0. Backend Phase 2: `PASS` once the fix PR merges. The remaining P3 items are
  recorded as `PH2-1`…`PH2-5` (§10). PR open.
- `S09-BE-PHASE-2` and `S09-BE-PHASE-2-FIX-001` delivered (PR #301, `main` `95992d3`); the merged tree equals
  the audited branch tree, so Backend Phase 2 is `PASS` on `main`.
- `S09-FE-001` is split:
  - `S09-FE-001A`: the exception-grant warning (`S09-D4`), `CL-6` and `CL-7`. These are small changes that need
    no new API.
  - `S09-FE-001B`: the Homework review deadline UI.
  `S09-FE-001A` approved on `95992d3` and implemented. The grant dialog always shows the official-score
  warning, headed by its condition ("If this is the Topic's official Blitz:"), because monitoring does not
  know whether the Blitz is official. Independent review: P1 = 0, P2 = 0, P3 = 4, all fixed:
  - the condition now heads every consequence, and the text names the Teacher review;
  - a one-line doc comment;
  - `FE-002` now depends on `FE-001B`;
  - the close and archive sets are pinned against the new code. PR open.
- `S09-FE-001A` accepted and delivered (PR #302, `main` `5aaf9a5`).
- `S09-FE-001B` contract written and approved on `5aaf9a5`, then implemented.
  - Design: the dedicated `PUT …/review-due-at` endpoint is the single editing path, for every state
    except archived. The Homework create and edit forms stay unchanged.
  - Display: the Summary row shows the review deadline on every surface.
  - Editing: set and clear are desktop-only, in a section that mirrors the official-Homework section's
    route lease and reconcile pattern.
  - Independent review: P1 = 0, P2 = 1 (the lease test held only the section's own lease), P3 = 4. All are
    fixed and mutation-checked: a local picker error is shown first, `task_archived` is announced in a
    SnackBar, and stale-detail and list-refresh tests were added.
  - PR open.
- `S09-FE-001B` accepted and delivered (PR #303, `main` `6ed9b7a`).
- `S09-FE-002` is split:
  - `S09-FE-002A`: the desktop review queue at `/teacher/reviews`. It lives on its own path, because
    every Teacher route sends a query string back to `/teacher`.
  - `S09-FE-002B`: the task review counts on the Homework and Blitz detail (every surface,
    `S09-D7`) and a task-scoped desktop queue reached from them.
- `S09-FE-002A` contract approved on `6ed9b7a`, then implemented.
  - The default filter is `Waiting for review`, in the recommended order: official first, then
    overdue.
  - Rows are display-only until `S09-FE-003`.
  - Independent review: P1 = 0, P2 = 1, P3 = 4. The P2 was in the contract: the score must be shown with
    one decimal, half-up (`S09-T3`). It is fixed with a shared formatter that `S09-FE-004` reuses. The P3
    items are fixed too: paging on an emptied later page, the singular `answer`, and the missing tests.
    Every fix is mutation-checked.
  - PR open.
- `S09-FE-002A` accepted and delivered (PR #304, `main` `f3cbefa`).
- `S09-FE-002B` contract approved on `f3cbefa`, then implemented.
  - A `Review` counts card sits on the Homework and Blitz detail on every surface. Blitz shows no overdue
    count.
  - The desktop `Open review queue` button opens the nested paths `…/homework/{id}/reviews` and
    `…/blitz/{id}/reviews`. Mobile is sent to the task detail.
  - The queue controller is now a family keyed by `TeacherReviewQueueScope`. A task scope sends
    `topic_id` and `assessment_id`, and hides the task filter.
  - Independent review: P1 = 0, P2 = 2, P3 = 5, all fixed and mutation-checked.
    - The new button broke the Stage 8 "no filled button on an Active Blitz" test. It is now an outlined
      button, like `Monitor`, so the Stage 8 test is unchanged.
    - The mobile test now asserts the counts themselves.
    - Tests were added for fragments, malformed entries, Blitz back navigation, the lease precondition
      and route names.
  - PR open.
- `S09-FE-002B` accepted and delivered (PR #305, `main` `bf6df48`).
- `S09-FE-003` is split:
  - `S09-FE-003A`: the submission detail and the file download;
  - `S09-FE-003B`: review save and correction;
  - `S09-FE-003C`: the official score.
- `S09-FE-003A` contract approved on `bf6df48`, then implemented.
  - Route `/teacher/reviews/{submissionId}`. Rows in both queues push it, so back returns to the queue they
    came from with its page kept.
  - A strict parser covers all nine Question types, with the answer-referenced ids, the null rules for
    each status and the answers' consistency with the submission.
  - Submitted files download through the protected `/files/{id}/download`.
  - The queue row and the detail header share `TeacherSubmissionSummary`.
  - Independent review: P1 = 0, P2 = 3, P3 = 4, all fixed and mutation-checked.
    - Blank keys that differ only by case were rejected.
    - The DTO and screen tests were incomplete.
    - The DTO now also rejects review statuses on automatic Questions and pending answers in a waiting
      submission.
    - Student matches follow the configured order.
    - Tests cover a session change.
    - `FE-004` now depends on `FE-003C`.
  - Re-verification: P1 = 0, P2 = 0; two new P3 test gaps fixed and mutation-checked.
  - PR open.
- `S09-FE-003A` accepted and delivered (PR #306, `main` `8d401ca`).
- `S09-FE-003B` contract approved on `8d401ca`, then implemented.
  - Each waiting or reviewed answer gets a points field and a feedback field. One `Save review` sends
    every changed answer to `PUT /teacher/submissions/{id}/review`.
  - The request holds absolute values, so an unconfirmed save is reconciled with one `GET` and may be
    sent again.
  - A confirmed save refreshes the review queues and the task detail that are still mounted.
  - Back with unsaved changes asks before leaving; refresh keeps typed values.
  - Independent review: P1 = 0, P2 = 0, P3 = 7.
    - A save's outcome is now decided before it is published.
    - A reconcile that does not confirm the save also refreshes the related views.
    - Tests were added for the remaining gaps.
    - All fixes are mutation-checked.
  - PR open.
- `S09-FE-003B` accepted and delivered (PR #307, `main` `1983fdc`).
- `S09-FE-003C` contract approved on `1983fdc`, then implemented.
  - An `Official score` card under the submission header reads
    `GET /teacher/assessments/{a}/students/{s}/official-score`, with a strict parser for the ready/null rule
    and the policy of each task type.
  - It shows the score with one decimal, its Attempt and policy, and the selection time, or why there
    is no official score yet.
  - The screen's refresh button and every review save that may have committed also refresh it.
  - Independent review: P1 = 0, P2 = 1, P3 = 3, all fixed and mutation-checked.
    - A refresh during a load was ignored, so a score read before a confirmed save could be shown as current.
      A refresh now replaces a load in flight.
    - The panel shows progress while it refreshes; tests were added for the remaining gaps.
  - PR open.
- `S09-FE-003C` accepted and delivered (PR #308, `main` `473d8a0`). `S09-FE-003` is complete.
- `S09-FE-004` is split:
  - `S09-FE-004A`: Student Homework results (display only; the parsers shipped with `S09-BE-007B`);
  - `S09-FE-004B`: the finished Blitz list (`GET /student/blitz/finished`, new parser and section).
- `S09-FE-004A` contract approved on `473d8a0`, then implemented.
  - The Homework list shows a released official score.
  - The Homework detail gets a `Results` card: the official score and each finished Attempt with its
    own score or `Result not available yet`, each one openable.
  - A finished Attempt shows its result and the Teacher's feedback under each answer.
  - Independent review: P1 = 0, P2 = 0, P3 = 5, all fixed and mutation-checked.
    - Open recreates the retained Attempt route providers, like Resume.
    - Open is disabled while a Start is in flight.
    - The feedback key uses the raw Question id.
    - Tests were hardened.
  - Re-verification: P1 = 0, P2 = 0; two new P3 test gaps fixed and mutation-checked.
  - PR open.
- `S09-FE-004A` accepted and delivered (PR #309, `main` `c1082e5`).
- `S09-FE-004B` contract approved on `c1082e5`, then implemented.
  - A `Finished Blitz` section sits on the Student workspace between `Active Blitz` and My Topics, five
    per page.
  - Each card shows the released score, `Result not available yet`, or why no Attempt counts, plus the
    invalidated first Attempt and the Teacher's feedback.
  - A strict parser checks the counting Attempt against the exception, the release rule and the
    feedback order. The Blitz topic reader is now shared (`readStudentBlitzTopic`).
  - Independent review: P1 = 0, P2 = 0, P3 = 7, all fixed and mutation-checked.
    - The pagination is validated before any arithmetic.
    - Feedback positions must strictly ascend; `closed_at` is required for archived tasks too.
    - Retry repeats a failed page change on the asked page.
    - The close time has the time-zone fallback.
    - `readStudentBool` is shared; tests were hardened.
  - Re-verification: P1 = 0, P2 = 0; one new P3 test gap fixed and mutation-checked.
  - PR open.
- `S09-FE-004B` accepted and delivered (PR #310, `main` `6e58259`). Every planned Stage 9 frontend task is
  delivered.
- 2026-10-01: `S09-FE-PHASE-2` run #1 on `6e58259`.
  - Four independent fresh-context reviewers: Student side, Teacher task pages, Teacher review surface,
    cross-cutting.
  - Full `flutter test` 3774 passed; `flutter analyze` and the format gate clean; Windows and Android debug
    builds succeed.
  - Findings: P2 = 1, P3 = 15 distinct. The P2: a related-view refresh after a review save was dropped while
    that view was loading, so the queues and the task counts could show pre-save data as current.
  - Verdict: `NOT ACCEPTED`.
  - Owner decision `S09-FE-PH2-D1`: fix the P2 with the five P3 findings that a user can see; carry the
    rest (§10).
- `S09-FE-PHASE-2-FIX-001` approved on `6e58259`, then implemented.
  - `refreshAfterReview` on the review queue and the Homework and Blitz details replaces a load in flight.
  - A 404 while reconciling the review deadline releases the route.
  - A Homework file chosen during a refresh is kept and uploaded once the Attempt is current.
  - A Submit flush cancelled from the leave dialog shows no false "not saved".
  - Only save messages that need attention are live regions.
  - The review bar wraps at large text.
  - PR open.

## 12. Independent Planning Review (2026-09-28)

A fresh-context read-only review of this package (index, `FE-UX-001`, `S09-DOC-001`) against the docs and
the code found P1 = 2, P2 = 10, P3 = 14. Claude verified the P1/P2 claims in the code before changing the
package. All are resolved in the contracts:

| Finding | Resolution |
|---|---|
| P1-1 Official-score resolver race between two writers for one Student | `S09-DOC-001` §8 Serialization: recipient-first lock order for every writer; sweep re-resolves |
| P1-2 Homework Student reads/replays fail once answers leave `pending` | `S09-DOC-001` §9 Historical reads; `S09-BE-003` scope |
| P2-1 No Student read path for a closed Blitz | `S09-DOC-001` §12 `GET /student/blitz/finished`; invalidated #1 shows no score |
| P2-2 Answer mutation wrongly listed as status-keyed | Removed; only Start/Resume and Submit are rekeyed (§9) |
| P2-3 Post-commit mechanism and decimal library undecided | `app()->terminating` + sweep (§7); `brick/math` and the NFC polyfill as direct dependencies, no `bcmath` (§6) |
| P2-4 Official-score status precedence; stale row window | §14 precedence table; reads use a live evaluation (§8) |
| P2-5 Review PUT validation order, required keys, float points | §10.5 evaluation order; both keys required; `null` clears feedback; Question-points number rule |
| P2-6 Acceptance contradicted the scope | §17 lists every deliberate Stage 6/7/8 edit |
| P2-7 Flush definition (blockers, keystrokes during flush, endless wait) | `FE-UX-001` §5.8 read-only flush with stop rules and `Cancel`; explicit blockers |
| P2-8 Text save and upload overlap rejected by the token check | `FE-UX-001` §5.3 read token vs publication token |
| P2-9 Refresh and recovery disturb typing | `FE-UX-001` §5.2 drafts never overwritten; §5.4 content stays mounted during a same-Attempt refresh |
| P2-10 Blitz leave warnings would disappear | `FE-UX-001` §5.9 keeps every Blitz dialog except the unsaved one's trigger |
| P3 items | Upper-bound rounding, flapping note, whitespace set, queue filter semantics, review-deadline endpoint and rules, practice-task release note for Stage 10, JSON number rule, restated audit items, no `fake_async`, expected files, context line fixes, status precedence, recovery stop conditions — all applied |

Re-review (same reviewer, 2026-09-28): P1 = 0, P2 = 4, P3 = 9, all resolved:

| Finding | Resolution |
|---|---|
| P2-A Recipient-first order would deadlock with the Teacher Homework update and pair designation | `S09-DOC-001` §8: parents (shared) first, then recipient; pair read without a lock |
| P2-B Terminating callbacks re-run on later requests; Stage 7/8 tests assert unchecked state | Request-scoped collector (`S09-DOC-001` §7); deliberate test updates listed in the `S09-BE-003` note (§8) |
| P2-C Keeping every draft would send stale values over another device's save | `FE-UX-001` §5.2: clean drafts adopt server values; only dirty drafts are kept |
| P2-D A rejected file would block Submit with no way out | `FE-UX-001` §5.7: rejected files are dropped with their error; retryable failures get `Cancel` |
| P3 items | Pair read unlocked, sweep repair limited, re-evaluation under locks, blocking definition and anomaly row, finished-Blitz scope and `attempt_exception`, invalidated label in the queue, review-due-at endpoint details, child-controller tokens, failed-refresh banner, `Leave Blitz` flush — all applied |

Targeted final check of P2-A…P2-D: all resolved; no new P1/P2; two wording P3s applied.

## 13. Change Log

| Date | Change |
|---|---|
| 2026-09-28 | Index created: owner decisions, technical decisions, planning audit, approved task order |
| 2026-09-28 | Independent planning review applied (§12); owner decision `S09-D8a` |
| 2026-09-29 | `FE-UX-001` accepted and delivered (PR #288); `S09-DOC-001` readiness approved on `4432f27` |
| 2026-09-29 | `S09-DOC-001` accepted and delivered (PR #289); `S09-BE-001` contract approved on `4cff8af` |
| 2026-09-29 | `S09-BE-001` delivered (PR #290); `S09-BE-002` approved on `830b9b1`; review-queue index moved to `S09-BE-005` |
| 2026-09-29 | `S09-BE-002` delivered (PR #291); `S09-BE-003` split into `003A` (readiness) and `003B` (pipeline) |
| 2026-09-30 | `S09-BE-003A` delivered (PR #292); `S09-BE-003B` approved on `f8bf790` |
| 2026-09-30 | `S09-BE-003B` delivered (PR #293); `S09-BE-004` approved on `d324716` |
| 2026-09-30 | `S09-BE-004` delivered (PR #294); `S09-BE-005` split into `005A`/`005B`; `005A` approved on `da53031` |
| 2026-09-30 | `S09-BE-005A` delivered (PR #295); `S09-BE-005B` approved on `4737ea8` |
| 2026-09-30 | `S09-BE-005B` delivered (PR #296); `S09-BE-006` approved on `06fe754` |
| 2026-09-30 | `S09-BE-006` delivered (PR #297); `S09-BE-007` split into `007A`/`007B`/`007C`; `007A` approved on `60e62cc` |
| 2026-09-30 | `S09-BE-007A` delivered (PR #298); `S09-BE-007B` approved on `1171e24` |
| 2026-09-30 | `S09-BE-007B` delivered (PR #299); `S09-BE-007C` approved on `bb6da8b` |
| 2026-09-30 | `S09-BE-007C` delivered (PR #300); `S09-BE-PHASE-2` run #1 `NOT ACCEPTED`; `S09-BE-PHASE-2-FIX-001` approved on `98747ef`; run #2 `PASS` |
| 2026-10-01 | Backend Phase 2 `PASS` delivered (PR #301); `S09-FE-001` split into `001A`/`001B`; `001A` approved on `95992d3` |
| 2026-10-01 | `S09-FE-001A` delivered (PR #302); `S09-FE-001B` approved on `5aaf9a5` |
| 2026-10-01 | `S09-FE-001B` delivered (PR #303); `S09-FE-002` split into `002A`/`002B`; `002A` approved on `6ed9b7a` |
| 2026-10-01 | `S09-FE-002A` delivered (PR #304); `S09-FE-002B` approved on `f3cbefa` |
| 2026-10-01 | `S09-FE-002B` delivered (PR #305); `S09-FE-003` split into `003A`/`003B`/`003C`; `003A` approved on `bf6df48` |
| 2026-10-01 | `S09-FE-003A` delivered (PR #306); `S09-FE-003B` approved on `8d401ca` |
| 2026-10-01 | `S09-FE-003B` delivered (PR #307); `S09-FE-003C` approved on `1983fdc` |
| 2026-10-01 | `S09-FE-003C` delivered (PR #308); `S09-FE-004` split into `004A`/`004B`; `004A` approved on `473d8a0` |
| 2026-10-01 | `S09-FE-004A` delivered (PR #309); `S09-FE-004B` approved on `c1082e5` |
