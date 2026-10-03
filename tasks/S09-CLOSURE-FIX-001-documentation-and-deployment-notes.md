# Closure Fix Contract: S09-CLOSURE-FIX-001 — Documentation Alignment and Stage 9 Deployment Notes

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-CLOSURE-FIX-001` |
| Stage | `Stage 9 — Checking and Scoring` |
| Source | `STAGE_09_CLOSURE_REVIEW` read-only audit on `main` `38b10f6` (three fresh-context reviewers, §11 of the closure record) |
| Owner decisions | `S09-CL-D1` (review-queue filters), `S09-CL-D2` (carried list), `S09-CL-D3` (dependency advisories) |
| Status | `Approved` |
| Production changes | **None**: `docs/01-09`, `tasks/` only |
| Implementation | Claude |
| Delivery | Claude opens the PR together with the closure record; the Project Owner merges |

## 2. Goal

Make `docs/01-09` and the Stage 9 contract state exactly the delivered Stage 9 behavior, write the
Stage 9 deployment notes that `PH2-2` and `PH2-5` point to, and record the carried items where Stage 10
planning reads them.

## 3. Items

| ID | Severity | Change | Files |
|---|---|---|---|
| `CL9-1` | P2 | An official score is `ready` only when the live evaluation is ready with the same Attempt **and the same normalized score**; the sweep repairs a missing or stale row only for a Student with no pending eligible Attempt (`PH2-3`) | `docs/05`, `docs/07`, `docs/08`, `docs/09`, `S09-DOC-001` |
| `CL9-2` | P2 | Stage 9 deployment notes (`PH2-2`, `PH2-5`): migration, dependencies, scheduler on one host (absent from `docker-compose`), terminating-callback checking, the first backfill run, the pre-`BE-004` backlog | `docs/07` §36.2 |
| `CL9-3` | P2 | The official Blitz rule states `S09-D4`: the grant withdraws #1's official score | `docs/06` |
| `CL9-4` | P2 | "Not completed" waits only for review that an official score still waits for; an invalidated #1 never counts | `docs/04`, `docs/05` BR-CAT-011 |
| `CL9-5` | P2 | Review-queue filters as delivered (`S09-CL-D1`) | `docs/02`, `docs/03`, `docs/04` |
| `CL9-6` | P3 | Stale or imprecise Stage 9 wording (sweep scope, Start responses carry `result`, ASCII feedback trimming, class names, Blitz has no overdue count, review deadline set on the detail, monitoring and Submit wording, short-answer switching, fill-in-the-blank normalization, exception status, grant withdrawal, stored precision, autosave, mobile counts, Parent feedback undecided) | `docs/01`, `docs/02`, `docs/03`, `docs/04`, `docs/05`, `docs/06`, `docs/07`, `docs/09`, `S09-DOC-001` |
| `CL9-7` | P3 | Carried items approved by `S09-CL-D2` added to the roadmap's "Carried from Stage 9" list | `docs/06` |
| `CL9-8` | P3 | Stage 9 bookkeeping: PR #313, stage status, closure record | `tasks/STAGE_09_TASK_INDEX.md`, `tasks/README.md`, `tasks/STAGE_09_CLOSURE_REVIEW.md` |

## 4. Non-Goals

- No production code, test, dependency or infrastructure change. The dependency advisories are a separate
  task right after closure (`S09-CL-D3`); adding a scheduler service to the deployment stack is a deployment
  task, not part of Stage 9.
- No new product decision: every sentence states delivered behavior or an owner decision.

## 5. Verification

- `git diff --check`; the diff touches only `docs/` and `tasks/`.
- An independent fresh-context reviewer compares every changed sentence with the delivered code and the
  owner decisions, and searches `docs/01-09` for remaining occurrences of each corrected statement.

## 6. Acceptance Criteria

- [ ] §3 is applied; the reviewer finds P1 = 0 and P2 = 0.
- [ ] The closure record states the verdict and is delivered in the same PR.
