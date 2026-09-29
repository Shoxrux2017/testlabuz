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
| Next permitted gate | `S09-DOC-001` delivery, then `S09-BE-001` readiness |

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
| `1` | `S09-DOC-001` | Documentation | `docs/01-09` aligned to `S09-D*`/`S09-T*` | `FE-UX-001` delivered | `Approved` (revalidated on `main` `4432f27`) | In progress — `docs/s09-doc-001-checking-scoring-alignment` | `tasks/S09-DOC-001-stage-09-checking-scoring-contract-alignment.md` |
| `2` | `S09-BE-001` | Backend | Checking domain: nine type checkers, text normalizer, exact partial credit, normalization; `brick/math` and the NFC polyfill declared as direct dependencies | `DOC-001` | Not written | Not started | `tasks/backend/stage-09/` |
| `3` | `S09-BE-002` | Backend + FE parser | `official_task_scores`, `review_due_at` (+ Teacher Homework create/update and the review-due-at endpoint), review-queue index | `BE-001` | Not written | Not started | `tasks/backend/stage-09/` |
| `4` | `S09-BE-003` | Backend (+ FE parser if needed) | Automatic checking pipeline, post-freeze trigger, minute sweep, `S09-T2` rekey, historical Homework reads | `BE-002` | Not written | Not started | `tasks/backend/stage-09/` |
| `5` | `S09-BE-004` | Backend | Official score resolver (Homework, Blitz, grant withdrawal) | `BE-003` | Not written | Not started | `tasks/backend/stage-09/` |
| `6` | `S09-BE-005` | Backend + FE parser | Review queue, submission detail, `review_summary`, Teacher file download | `BE-004` | Not written | Not started | `tasks/backend/stage-09/` |
| `7` | `S09-BE-006` | Backend | Review save and correction, recalculation | `BE-005` | Not written | Not started | `tasks/backend/stage-09/` |
| `8` | `S09-BE-007` | Backend + FE parser | Official-score read; Student `result`, `feedback`, `attempt_results`, `official_score`; `GET /student/blitz/finished` | `BE-006` | Not written | Not started | `tasks/backend/stage-09/` |
| `9` | `S09-BE-PHASE-2` | Backend review | Full Stage 9 backend review + full backend suite | `BE-001…007` | Not written | Not started | `tasks/backend/stage-09/` |
| `10` | `S09-FE-001` | Frontend | Review deadline field, exception-grant warning, `CL-6`, `CL-7` | Backend Phase 2 PASS | Not written | Not started | `tasks/frontend/stage-09/` |
| `11` | `S09-FE-002` | Frontend | Desktop review queue; mobile counts | `FE-001` | Not written | Not started | `tasks/frontend/stage-09/` |
| `12` | `S09-FE-003` | Frontend | Desktop submission review, file download, correction, official score | `FE-002` | Not written | Not started | `tasks/frontend/stage-09/` |
| `13` | `S09-FE-004` | Frontend | Student Homework results and official score; finished Blitz list with results | `FE-003` | Not written | Not started | `tasks/frontend/stage-09/` |
| `14` | `S09-FE-PHASE-2` | Frontend review | Full Stage 9 frontend review + full verification | `FE-001…004` | Not written | Not started | `tasks/frontend/stage-09/` |
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
- **`S09-BE-003`** changes the Stage 7/8 freeze paths only by adding the post-commit checking trigger
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
- **`S09-BE-004`** also changes the Stage 8 exception grant (withdrawal in the same transaction).
- **`S09-BE-005`** adds `review_summary` to Teacher Homework/Blitz details with the parser change.
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
| `CL-6` `authorityStateAtStart` typed `Object` | Stage 8 closure (`CL-D1`) | `S09-FE-001` |
| `CL-7` Homework activation lacks `official_cohort_mismatch` | Stage 8 closure (`CL-D1`) | `S09-FE-001` |
| `INT-D2` autosave | Stage 8 integration | `FE-UX-001` (`S09-D8`) |
| Topic-result feedback, Parent-visible feedback flag | Planning audit #6 | Stage 10 planning |
| `topic_results.official_homework_score_id`/`official_blitz_score_id` default to `ON DELETE RESTRICT` (`docs/08` §§25.13-25.14), while Stage 9 deletes `official_task_scores` rows (exception grant; score no longer ready) | `S09-DOC-001` implementation | Stage 10 planning: decide the reference rule before `topic_results` exists |

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
