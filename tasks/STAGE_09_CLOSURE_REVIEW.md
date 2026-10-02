# Stage 9 Closure Review — Checking and Scoring

## 1. Executed Closure Metadata

| Field | Value |
|---|---|
| Review ID | `STAGE-09-CLOSURE` |
| Stage | `Stage 9 — Checking and Scoring` |
| Status | `Completed` |
| Review date | `2026-10-03` |
| Review owner / result | `Claude closure review (closure-review role since 2026-09-23) with three fresh-context reviewers / PASS` |
| Verification model | `Workflow v3 — Lean Verification + Backend/Frontend Phase 2 + Real-Stack Integration` |
| Planning baseline | `b07bdb14` (Stage 8 closed; `API-FIX-001` merged) |
| Read-only audit `origin/main` | `38b10f616f68fbdf2ad056a93c3039c46f6954a9` (clean, ahead/behind `0/0`) |
| Closure PR content | `S09-CLOSURE-FIX-001` (documentation and deployment notes only) + this record + bookkeeping |
| Previous Stage | `Stage 8 — Closed / PASS` |
| Decomposition | `Approved / Delivered` |
| Backend Phase 2 | `PASS` (run #2, `5db50d0`) |
| Frontend Phase 2 | `PASS` (run #2, `ccc1d60`) |
| Integration | `S09-INT-001 — PASS / Accepted` (Windows run on `4224fcf`; Android smoke; index §14) |
| Integration Harness Preflight | `PASS` (#2; #1 `NOT ACCEPTED`, all findings fixed) |
| Integration cleanup | `PASS` |
| Documentation synchronization | `PASS` after `S09-CLOSURE-FIX-001` |
| Open findings | `P1 = 0, P2 = 0` after the fix; P3 fixed or carried with targets (§11) |
| Roadmap acceptance | `PASS` |
| Stage Definition of Done | `PASS` |
| Stage 10 boundary | `PASS` |
| Closure verdict | `STAGE CLOSED` (effective when the closure PR merges) |
| Next permitted gate | The dependency-update task (`S09-CL-D3`), then Stage 10 planning — the Project Owner first decides how Stage 10 is run |

Claude holds the ChatGPT roles (contracts, readiness, review, acceptance, checkpoints and closure) and
the Codex role since 2026-09-23. Delivery stays with the Project Owner, who merges every PR.

## 2. Completed Task Inventory and Delivery

All 27 delivered items reached their required final states (`tasks/STAGE_09_TASK_INDEX.md` §7).

| Order | Task | Final state | Delivery |
|---|---|---|---|
| — | Planning package (index, `FE-UX-001`, `S09-DOC-001` contracts) | Delivered | PR #287, `3ad88fb` |
| 0 | `FE-UX-001` Student answer autosave | Accepted / Delivered | PR #288, `4432f27` |
| 1 | `S09-DOC-001` documentation alignment | Accepted / Delivered | PR #289, `4cff8af` |
| 2 | `S09-BE-001` checking domain | Accepted / Delivered | PR #290, `830b9b1` |
| 3 | `S09-BE-002` scoring persistence, review deadline | Accepted / Delivered | PR #291, `9b772b4` |
| 4a | `S09-BE-003A` checking readiness | Accepted / Delivered | PR #292, `f8bf790` |
| 4b | `S09-BE-003B` checking pipeline | Accepted / Delivered | PR #293, `d324716` |
| 5 | `S09-BE-004` official score resolver | Accepted / Delivered | PR #294, `da53031` |
| 6a | `S09-BE-005A` review queue and detail | Accepted / Delivered | PR #295, `4737ea8` |
| 6b | `S09-BE-005B` review summary, Teacher file download | Accepted / Delivered | PR #296, `06fe754` |
| 7 | `S09-BE-006` review save and correction | Accepted / Delivered | PR #297, `60e62cc` |
| 8a | `S09-BE-007A` Teacher official-score read | Accepted / Delivered | PR #298, `1171e24` |
| 8b | `S09-BE-007B` Student Homework results | Accepted / Delivered | PR #299, `bb6da8b` |
| 8c | `S09-BE-007C` finished Blitz list | Accepted / Delivered | PR #300, `98747ef` |
| 9 | `S09-BE-PHASE-2` (+ `FIX-001`) | PASS | PR #301, `95992d3` |
| 10a | `S09-FE-001A` grant warning, `CL-6`, `CL-7` | Accepted / Delivered | PR #302, `5aaf9a5` |
| 10b | `S09-FE-001B` review deadline | Accepted / Delivered | PR #303, `6ed9b7a` |
| 11a | `S09-FE-002A` review queue | Accepted / Delivered | PR #304, `f3cbefa` |
| 11b | `S09-FE-002B` task review counts | Accepted / Delivered | PR #305, `bf6df48` |
| 12a | `S09-FE-003A` submission detail | Accepted / Delivered | PR #306, `8d401ca` |
| 12b | `S09-FE-003B` review save | Accepted / Delivered | PR #307, `1983fdc` |
| 12c | `S09-FE-003C` official-score panel | Accepted / Delivered | PR #308, `473d8a0` |
| 13a | `S09-FE-004A` Homework results | Accepted / Delivered | PR #309, `c1082e5` |
| 13b | `S09-FE-004B` finished Blitz | Accepted / Delivered | PR #310, `6e58259` |
| 14 | `S09-FE-PHASE-2` (+ `FIX-001`) | PASS | PR #311, `f0259c8` |
| 15 | `S09-INT-001` assets and preflight | PASS / Accepted | PR #312, `4224fcf` |
| 15 | `S09-INT-001` execution record and smoke-prep fix | PASS / Accepted | PR #313, `38b10f6` |

## 3. Closure Entry Verification

Verified on `38b10f6` before the read-only audit:
- branch `main`, `HEAD == origin/main`, ahead/behind `0/0`, clean working tree; every merge above is an ancestor;
- `5db50d0..38b10f6` changes in `backend/` only the Stage 9 seeder, its test and two added lines in
  `StudentHomeworkResultsApiTest`; no file under `backend/app`, `routes`, `database/migrations`, `config`,
  `bootstrap` or the Composer files changed;
- `ccc1d60..38b10f6` changes in `frontend/` only `integration_test/` and one test in
  `student_answer_editor_screen_test.dart` (`ff7e627`, the commit that recorded run #2); no file under
  `frontend/lib`, the pubspec, `android` or `windows` changed;
- `docker/` unchanged.

## 4. Backend Phase 2 Evidence

| Check | Accepted result |
|---|---|
| `S09-BE-PHASE-2` | `PASS` (run #2, 2026-09-30) |
| Audited revision | `5db50d07dd44fc0a94358adef6c3ab4ef310ff9d` |
| `php artisan test` | 2787 passed (62,398 assertions), exit 0 |
| `pint --test` | PASS (815 files) |
| Findings | Run #1 `NOT ACCEPTED` (one stale Stage 8 seeder assertion); five reviewers P1 = 0, P2 = 0, 15 P3; `FIX-001` re-baselined the seeder test and closed the test gaps; `PH2-1`…`PH2-5` carried |
| Validity at closure | Valid: no backend production file changed after `5db50d0` |

## 5. Frontend Phase 2 Evidence

| Check | Accepted result |
|---|---|
| `S09-FE-PHASE-2` | `PASS` (run #2, 2026-10-01) |
| Audited revision | `ccc1d60f7a53283e1d06c9f94df2f01b88b11e0f` |
| `flutter test` | 3788 passed, exit 0 |
| `flutter analyze` | No issues |
| `dart format --set-exit-if-changed lib test` | 893 files, 0 changed |
| Windows and Android debug builds | PASS |
| Findings | Run #1 `NOT ACCEPTED` (P2 `C-1`: related views kept pre-save data); owner decision `S09-FE-PH2-D1`: `FIX-001` fixed the P2 and five user-visible P3; nine P3 and one `FIX-001` review item carried |
| Validity at closure | Valid: after `ccc1d60` only `integration_test/` and one test file changed |

## 6. Integration Evidence

| Item | Result |
|---|---|
| Owner decision `S09-INT-D1` | Claude runs the Windows runner and the API/DB scenarios; the Project Owner performs the Android smoke |
| Assets | PR #312: `Stage9E2eSeeder` (39 tests), guard, DB oracle, API layers, Windows review flow, runner, smoke preparation |
| Harness Preflight #1 | `NOT ACCEPTED` — P2 = 3, P3 = 13, all fixed before PR #312 |
| Harness Preflight #2 | `PASS` — P3 = 4, all fixed |
| Windows run on `4224fcf` (2026-10-02) | PASS — 19/19 steps in 402 s; clean, unchanged checkout; 6/6 UI checkpoints judged by the DB oracle |
| Scenarios | PASS — freeze-trigger checking, Homework overtake wait, Blitz review and exception replacement, manual release hidden, review error contract, scheduled checking (exact counts, half-up `55.55555567`, one repair, `schedule:run`), Teacher file download, Tenant/privacy matrix, Student results, restart persistence |
| Final integration review | PASS — P1 = 0, P2 = 0; three record items applied, one naming fix |
| Harness defect at smoke preparation | `prepare_stage9_manual_smoke.ps1` never parsed; fixed in PR #313 with a parse check of every Stage 9 script; harness-only, Windows evidence valid |

## 7. Android Manual Smoke

Performed by the Project Owner on 2026-10-02 on the emulator `testlabuz_demo` (`emulator-5554`, Android 36;
owner decision `S09-INT-D2`), with a debug APK of the product code of `4224fcf`.

| Smoke | Result | Evidence |
|---|---|---|
| Student results | PASS | Owner: Finished Blitz `Score 75.0` with Teacher feedback; Homework `Official score: 90.0 (Attempt 1)`, `Attempt 1 · Checked · Score 90.0`; feedback under the reviewed Question; no correct answers |
| Teacher mobile | PASS | Owner: no review queue on mobile; read-only `Waiting for review: 1`, `Overdue: 1` |
| Unchanged state | PASS | DB oracle: the prepared Android state, Tenant rows and the sentinel hash were unchanged by the smoke |

Afterwards a demo build for the `:8010` demo stack was reinstalled on the emulator.

## 8. Guarded Cleanup

PASS. After the Windows run and after the Android smoke, the manifest-owned rows and private blobs were removed,
the unrelated sentinels were verified unchanged and then removed, the local fixture and evidence roots were
removed, the manual-smoke marker is gone and the Android reverse mapping was removed. The dedicated
`testlabuz-stage9-e2e-app` container and its private volume remain provisioned, as the integration contract allows.

## 9. Documentation Synchronization

The read-only audit on `38b10f6` (reviewer B, with reviewers A and C) found that `docs/01-09` match the delivered
checking rules, normalization, rounding, states and trigger, lock order, review API and error codes, file download,
review deadline, Student visibility and the finished Blitz list, with these exceptions, all fixed in
`S09-CLOSURE-FIX-001` (`tasks/S09-CLOSURE-FIX-001-documentation-and-deployment-notes.md`):
- `CL9-1` (`PH2-3`): `ready` requires the same Attempt and the same normalized score; the sweep repair condition;
- `CL9-2`: the Stage 9 deployment notes (`docs/07` §36.2), which `PH2-2` and `PH2-5` pointed to;
- `CL9-3`: the official Blitz rule states `S09-D4`;
- `CL9-4`: the "Not completed" rule and an invalidated #1;
- `CL9-5`: the review-queue filters as delivered (`S09-CL-D1`);
- `CL9-6`: stale or imprecise wording in `docs/01`, `02`, `03`, `04`, `05`, `06`, `07`, `09` and `S09-DOC-001`;
- `CL9-7`: the carried items in the roadmap list "Carried from Stage 9".

A fresh-context reviewer verified the changed text against the code and searched `docs/01-09` for remaining
occurrences before the closure PR (§13). Documentation synchronization: `PASS`.

## 10. Roadmap Acceptance and Stage Definition of Done

Reviewer A checked `docs/06-roadmap.md` §14 item by item against code, tests and the integration evidence.

| Closure criterion | Result |
|---|---|
| Required tests (33 items, including all seven automatic checkers, partial credit, the overtake wait, resolver and review races, exception withdrawal, decimal arithmetic, normalization, zero-point and unanswered Questions, Teacher file access, release-mode visibility, the official-score status table, checking after freeze and the sweep, `409 automatic_checking_pending`, Stage 8 compatibility) | `PASS` |
| Included scope (queue, detail, feedback limit, desktop-only review, review deadline, frozen fields kept, practice and invalidated Attempts, Blitz after close, one-decimal display, Student privacy, Stage boundary) | `PASS` |
| Acceptance criteria: one official 0–100 score per required task; manual work pending until reviewed; Stage 7/8 responses unchanged; Students see only what release mode and Blitz status allow | `PASS` |
| Owner decisions `S09-D1`…`S09-D9`, `S09-D8a`; technical decisions `S09-T1`…`S09-T8`; `S09-DOC-001` §§4-14 | `PASS` |
| Permissions and Tenant isolation (reviewer C) | `PASS` |
| Backend–frontend contract agreement for every Stage 9 Teacher and Student response (two key-by-key sweeps) | `PASS` |
| Validation and error behavior | `PASS` |
| No blocking regression; every Stage 7/8 change traces to `S09-T2`, `S09-T6`, `S09-D8` or `S09-T8` | `PASS` |
| Stage Definition of Done (`docs/06` §3.2) | `PASS` |
| Stage 10 boundary: no `topic_results`, release action or `result_closed`; corrections always allowed | `PASS` |

## 11. Final Closure Findings

Three fresh-context reviewers audited `38b10f6`: A (roadmap acceptance and Definition of Done) `PASS`;
B (documentation) P2 = 4; C (security, contracts, carried items) P2 = 2. Two further sweeps compared every Teacher
and Student response with the strict Flutter parsers and found no P1 or P2.

| ID | Severity | Finding | Disposition |
|---|---|---|---|
| `CL9-1` | P2 | `PH2-3` wording in eight places; row 6 promised a repair the sweep does not always make | Fixed — `S09-CLOSURE-FIX-001` |
| `CL9-2` | P2 | Stage 9 deployment notes did not exist (`PH2-2`, `PH2-5`); the Compose stack has no scheduler | Fixed — `docs/07` §36.2 |
| `CL9-3` | P2 | `docs/06` kept #1 official until a replacement existed, against `S09-D4` | Fixed |
| `CL9-4` | P2 | "Not completed" text blocked on review of an invalidated #1 | Fixed |
| `CL9-5` | P2 | Docs promised Topic, group and Student queue filters that the UI lacks | Fixed by `S09-CL-D1` (docs as delivered; filters carried) |
| `CL9-6` | P3 | Stale or imprecise statements (21 from the audit; five mobile review-count sentences found while fixing; ten from fix review #1) | Fixed |
| `CL9-7` | P3 | Carried items not where Stage 10 planning reads them | Fixed — roadmap list |
| `CL9-8` | P3 | Bookkeeping: PR #313 and the stage status | Fixed |
| `CL9-9` | P3 | No real-concurrency backend test of exception grant vs checking, or of the sweep vs a Homework Submit | Carried (`S09-CL-D2`) |
| `CL9-10` | P3 | Under `manual_teacher` the Student sees the Attempt status move to checked while the score is hidden | Carried — decide when designing result release |
| `CL9-11` | P3 | A stored empty feedback string, or Question text of non-ASCII whitespace created through the API, would fail the strict client parsers (no current writer does so) | Carried — hardening |
| `CL9-12` | P3 | The Homework Submit response is re-read after commit, so a sweep inside that window can return `waiting_for_teacher_review` or `checked` instead of `submitted` (same shape; replays already do) | Accepted — documented in `docs/09` §17.13 |
| `CL9-13` | P3 | The Stage 8 E2E harness no longer matches the Stage 9 backend | Accepted — historical, not maintained |
| `CL9-14` | — | `composer audit`: 8 advisories present before Stage 9 (`league/commonmark` 2.9.0 — 5 high, 1 medium; `laravel/framework` 13.24.0 — 1 low; `league/flysystem` 3.35.2 — 1 low); no application code uses Markdown | `S09-CL-D3`: separate dependency-update task right after closure |

Project Owner decisions taken at closure:
- **`S09-CL-D1`**: the documents describe the delivered queue filters; Topic, group and Student filters (already
  accepted by the API) are carried to Stage 10 planning.
- **`S09-CL-D2`**: the carried list is approved with its targets.
- **`S09-CL-D3`**: the dependency advisories are fixed by a separate task right after closure, before Stage 10 code.

Carried items and targets (also in the roadmap list "Carried from Stage 9", `docs/06`):

| Item | Target |
|---|---|
| Review-queue Topic, group and Student filters | Stage 10 planning |
| Real-concurrency tests (`CL9-9`) | Stage 10 planning (backend hardening) |
| Topic-result feedback, Parent-visible feedback flag, `topic_results` reference rule | Stage 10 planning |
| `PH2-4` consolidate the official and visibility rules | Stage 10 planning |
| Status visibility under `manual_teacher` (`CL9-10`) | Stage 10 result-release design |
| Hardening (`CL9-11`) | Stage 10 planning or a polish task |
| Frontend Phase 2 carried P3 (`A-2`, `B-2`…`B-5`, `C-3`, `C-4`, `D-3`, `D-4`, deferred upload during the leave dialog) | Stage 10 planning or a polish task |
| `PH2-1` bound the repair sweep's full-history scan | Stage 13 release readiness |

```text
P1 = 0
P2 = 0 (CL9-1 … CL9-5 fixed before the verdict)
P3 = fixed, carried with targets (S09-CL-D2) or accepted with rationale
```

## 12. Closure Verdict and Evidence Validity

```text
Closure review = PASS
Closure verdict = STAGE CLOSED (when the closure PR merges)
Stage 9 status = Closed / PASS
Next permitted gate = dependency-update task (S09-CL-D3), then Stage 10 planning; the Project Owner said on
                      2026-10-02 that Stage 10 will be run with a different process, so planning starts by asking how
```

Stage 10 implementation is not authorized by this closure.

Backend Phase 2, Frontend Phase 2, the Windows and Android real-stack evidence, the DB oracle and restart
persistence remain valid: after the audited checkpoints only integration assets, documentation, two test files (a two-line
comment in `StudentHomeworkResultsApiTest` and one frontend test) and bookkeeping changed (`tasks/README.md` §12A). No verification rerun is required.

## 13. Closure Delivery and Post-Merge Gate

The closure branch `docs/s09-closure-fix-001` starts from `38b10f6`. It contains only:
- `docs/01`, `02`, `03`, `04`, `05`, `06`, `07`, `08`, `09` — `S09-CLOSURE-FIX-001`;
- `tasks/S09-CLOSURE-FIX-001-documentation-and-deployment-notes.md`;
- `tasks/S09-DOC-001-stage-09-checking-scoring-contract-alignment.md` — the same corrections;
- `tasks/STAGE_09_CLOSURE_REVIEW.md` — this record;
- `tasks/STAGE_09_TASK_INDEX.md`, `tasks/README.md` — final statuses.

Verification: `git diff --check`; the diff touches only `docs/` and `tasks/`; a fresh-context review of the
documentation changes: #1 `NOT ACCEPTED` (P2 = 1, the official Blitz rule in `docs/06` still said Not completed while #2 was pending; P3 = 10), all fixed; #2 `PASS` (P1 = 0, P2 = 0). Claude opens the PR; the Project Owner merges. After the merge:
`main == origin/main`, the merged tree equals the branch tree, and the branch is deleted.
