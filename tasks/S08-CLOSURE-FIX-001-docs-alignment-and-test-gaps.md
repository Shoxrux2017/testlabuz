# Focused Fix Contract: S08-CLOSURE-FIX-001 — Documentation Alignment and Test Gaps

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S08-CLOSURE-FIX-001` |
| Stage | `Stage 8 — Blitz Task Workflow` |
| Origin | Stage 8 Closure Review, read-only audit on `CLOSURE_AUDITED_MAIN` `1f6333b` — `NOT READY` (closure contract §36) |
| Findings fixed | `CL-1` (P2), `CL-2`, `CL-3`, `CL-4`, `CL-5` (P3) |
| Findings deferred | `CL-6`, `CL-7` (P3), with the rationale in `tasks/STAGE_08_TASK_INDEX.md` §22 |
| Project Owner decision | `CL-D1` = option 4 (Г) (2026-09-28) |
| Area | `docs/04`, `docs/05`, `docs/07`, `docs/08`, `docs/09`; three frontend test files |
| Implementation | Claude |
| Delivery | One PR carrying this contract, the index record and the changes; Project Owner merges |

## 2. Goal

Make `docs/01-09` one consistent contract again and close two frontend test gaps, without changing
production code, so that every Stage 8 product evidence record stays valid.

## 3. Scope

### Included

- `CL-1` (P2): owner decision D3 (`S08-BE-PHASE-2-FIX-002`) reached only `docs/09` §20.3. The Start
  matrices in `docs/04` (Approved exception flow), `docs/05` BR-ATT-004A, `docs/07` §14.4 and
  `docs/08` (Fixed Attempt Rules by Assessment Type) still gave `attempts_exhausted` /
  `attempt_not_editable` for a `timed_out_finalized` target. They now state the `docs/09` §20.3
  matrix, with a dated amendment note.
- `CL-2` (P3): `docs/04` says the Teacher can grant the Student exception on mobile. The approved
  Stage 8 matrix (`S08-FE-006` §4) makes the grant desktop-only. A Stage 8 note is added to both
  places; the product intent of the flow is kept.
- `CL-3` (P3): the open-assessment guard on Topic close/archive (`409 topic_has_open_assessments`,
  from `S06-BE-005`, widened to Blitz by `S08-BE-004` §44) is described in `docs/09` §13.8/§13.9
  and in `docs/05` BR-TOP-009, matching `TeacherTopicOpenAssessmentGuard` and
  `ApiErrorResponse::topicHasOpenAssessments`.
- `CL-4` (P3): a Homework Question-editor test proves the outcome-review action reads
  "Check current Homework", blocks Cancel, and re-reads the Homework exactly once.
- `CL-5` (P3): the Institution Admin and Platform Owner shell tests override the Student Active
  Blitz and Topic repositories, so a Student routed to `/student` never reaches the real network
  client.

### Non-Goals

- No production source change (`backend/`, `frontend/lib`, `docker/`, packages).
- No new business decision: every documentation change restates already-approved behavior.
- `CL-6` and `CL-7` (see §22 of the index).

## 4. Expected Files

```text
docs/04-user-flows.md
docs/05-business-rules.md
docs/07-architecture.md
docs/08-database.md
docs/09-api-contracts.md
frontend/test/features/teacher/teacher_question_editor_test.dart
frontend/test/features/institution_admin/institution_admin_shell_test.dart
frontend/test/features/platform_admin/platform_owner_shell_test.dart
tasks/S08-CLOSURE-FIX-001-docs-alignment-and-test-gaps.md
tasks/STAGE_08_TASK_INDEX.md
```

## 5. Acceptance Criteria

- [ ] No document in `docs/01-09` states `attempts_exhausted` or `attempt_not_editable` for a `timed_out_finalized` Start target outside the D3 exception (`start_normal` with an approved exception).
- [ ] Both mobile passages of `docs/04` state that the Stage 8 grant is desktop-only.
- [ ] `docs/09` §13.8/§13.9 and `docs/05` BR-TOP-009 describe `409 topic_has_open_assessments` exactly as the code behaves (statuses, message, precedence).
- [ ] The new Homework test fails when the Homework binding shows another label or calls another action.
- [ ] Both shell-test `_pumpApp` helpers override `studentBlitzRepositoryProvider` and `studentTopicRepositoryProvider`.
- [ ] No production source change.

## 6. Focused Verification

- `flutter test` on the three changed test files.
- `flutter analyze` and `dart format` on the three changed test files.
- Deliberate breaks of the Homework binding label and action are caught.
- A search of `docs/01-09` for the stale Start matrix finds no remaining statement.
- `git diff --check`.

## 6A. Completion (2026-09-28)

The fresh-context re-verification on `2c68c0b` (PR #283 merged) passed every acceptance criterion
and found two more locations of the same findings, completed under the same owner decision `CL-D1`:
- `CL-2`: `docs/07` §22.4 Teacher Mobile listed the exception grant without the Stage 8 note;
- `CL-3`: the `docs/09` Lifecycle / Task error catalogue did not list `topic_has_open_assessments`.

The `docs/04` mobile note now also names Blitz read, which the approved matrix allows on mobile.

## 7. Evidence Validity

Documentation and test-only changes: every Backend Phase 2, Frontend Phase 2 and `S08-INT-001`
evidence record stays valid (closure contract §30).
