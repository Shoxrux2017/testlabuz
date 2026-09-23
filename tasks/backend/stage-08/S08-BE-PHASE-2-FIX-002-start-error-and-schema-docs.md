# Focused Fix Contract: S08-BE-PHASE-2-FIX-002 — Start Error Contract and Schema Docs

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-BE-PHASE-2-FIX-002` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Origin | `S08-BE-PHASE-2` run #1 on audited `main` `232ebcd` — `NOT ACCEPTED` |
| Findings fixed | `P2-2` (documentation side), `P3-7` (documentation part), `D1` schema note |
| Project Owner decisions | `D3 = B`, `D5 = A`, `D1 = A` (2026-09-23) |
| Area | Documentation / contract alignment only |
| Delivery | Same docs PR that records Phase 2 run #1 |

## 2. Goal

Align the authoritative Stage 8 documents with Project Owner decisions so that implementation and
contract agree, without changing production code.

## 3. Scope

### Included

1. `D3`: a Blitz Attempt already terminal with status `timed_out_finalized` answers
   `409 blitz_time_expired` on `resume` (exact target), `start_normal` (#1, when no approved
   exception exists) and `start_replacement` (#2). Other terminal states keep
   `attempt_not_editable` / `attempts_exhausted`. `start_normal` with an approved exception keeps
   `attempts_exhausted` for any terminal #1. This is the delivered behavior of
   `StartStudentBlitzAttempt.php:112-134`.
   - `tasks/S08-DOC-001-stage-08-blitz-execution-contract-alignment.md` §13.9 `start_normal`,
     `resume`, `start_replacement` tables and the "Section 13.9 Start matrix is authoritative"
     summary table, with a dated amendment note.
   - `docs/09-api-contracts.md` Student Blitz Start matrix rows.
2. `P3-7` documentation part: `blitz_tasks.scheduled_at` is `timestamptz(6)` (migration
   `2026_09_16_000100_preserve_blitz_scheduled_at_microseconds`) in `docs/08-database.md`.
3. `D1` schema note: `question_matching_items.id` and `question_ordering_items.id` are random
   version-4 UUIDs by design (Students receive them; time-ordered IDs would reveal the key), an
   explicit exception to the one-convention UUID rule in `docs/08-database.md` §UUID.

### Non-Goals

- No production code or test change (behavior already delivered; tests in `FIX-001`).
- Historical task contracts (`S08-BE-005`, `S08-BE-007`, `S08-BE-009`) are audit evidence and
  are not rewritten; the DOC-001 amendment note states that it supersedes them on this point.

## 4. Acceptance Criteria

- [ ] DOC-001 §13.9 and docs/09 state the same matrix as the delivered code for every
      timeout-finalized terminal case, and nowhere claim `attempts_exhausted` /
      `attempt_not_editable` for a timeout-finalized target.
- [ ] The amendment note names the decision, the date and the rationale (one situation, one code,
      independent of Scheduler timing; Stage 7 `deadline_passed` precedent).
- [ ] docs/08 records `scheduled_at` precision and the v4 identifier exception.
- [ ] `git diff --check` passes; no file outside the three documents plus Stage bookkeeping.
