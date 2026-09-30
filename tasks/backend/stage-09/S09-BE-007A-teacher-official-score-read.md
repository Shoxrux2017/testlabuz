# Implementation Contract: S09-BE-007A — Teacher Official-Score Read

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-BE-007A` (first part of the planned `S09-BE-007`) |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Backend` (new read-only endpoint; no existing response changes, so no frontend parser change) |
| Status | `Approved` |
| Depends on | `S09-BE-006 — Accepted / Delivered` (PR #297, `main` `60e62cc`) |
| Implementation baseline | `origin/main` `60e62cc` |
| Decisions applied | `S09-D2` (Homework "could overtake" wait), `S09-D4` (Blitz normal/replacement), `S09-D6` (practice tasks never official) |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |
| Blocks | `S09-BE-007B` (Student `score_visible` uses the same readiness check), `S09-FE-003` |

This file is the complete task contract. The split of `S09-BE-007` into `007A` (this task), `007B` (Student
Homework results with the Student parser change) and `007C` (Student finished Blitz list) is recorded in
`tasks/STAGE_09_TASK_INDEX.md`.

## 2. Goal

A Teacher reads the official score of one Student for one Homework or Blitz, or the reason it is not ready.

## 3. Scope

### Included

- `GET /api/v1/teacher/assessments/{assessment}/students/{student}/official-score` (docs/09 §24.1,
  `S09-DOC-001` §14).
- A shared official-score reader (§5.2) that `S09-BE-007B` reuses for Student `score_visible`.
- The Topic-pair check moves out of `OfficialTaskScoreResolver` into a shared class, unchanged in behavior.

### Non-goals

- No Student visibility (`S09-BE-007B`, `S09-BE-007C`); no UI (`S09-FE-003`).
- No change to any existing response, the resolver's decisions, the sweep or any migration.
- No locks. The read runs in one `REPEATABLE READ READ ONLY` snapshot (`StudentBlitzReadSnapshot`, as the
  Teacher Blitz monitoring read): the Blitz evaluation reads the Attempts and the exception in separate
  statements, and a grant or replacement start committed between them would otherwise produce an
  inconsistent graph. Review correction; the first draft read without a snapshot.

## 4. Current Implementation Context

- `OfficialScoreEvaluator::evaluate($assessment, $recipient, $attempts)` returns `OfficialScoreEvaluation`
  (`official`, `policy`, `blocking` ordered by attempt number); `OfficialTaskScoreResolver` persists the
  row and has a private `isOfficial(Assessment)` pair check (`S09-BE-004`).
- `RepairOfficialTaskScores` treats a row as differing when its `official_attempt_id` or
  `normalized_score` differs from the live best Attempt.
- `Topic::visibleToTeacher` is the Teacher Topic access used by `TeacherSubmissionAccess` (`S09-BE-005A`).
- `TeacherSubmissionShowRequest` rejects query parameters and a body; `TeacherSubmissionResource::timestamp`
  formats UTC `Z` timestamps.

## 5. Exact Contract

### 5.1 Access — `404 resource_not_found`

Both ids are UUIDs; the Assessment is in the Teacher's Institution and its Topic is visible to the Teacher
(`Topic::visibleToTeacher`, as §21 Review Access); the Student has a persisted `assessment_students` row for
that Assessment. Topic and task status never restrict the read. Anything else is `404`. The request takes no
query parameters and no body (`422 validation_failed`, checked first).

### 5.2 Reader (`OfficialScoreReader::read(Assessment, AssessmentStudent): OfficialScoreReading`)

Reads the recipient's Attempts, the live evaluation and the persisted row without locks; the caller
provides the snapshot (§3). Then `status` is the first matching row:

| # | Condition | `status` |
|---|---|---|
| 1 | The Assessment is not the Topic pair's Homework or Blitz | `not_applicable` |
| 2 | A row exists, the evaluation is ready, and the row's `official_attempt_id` and `normalized_score` equal the evaluated Attempt's | `ready` |
| 3 | Blitz, an exception exists for the recipient, no terminal Attempt #2, Blitz `active` | `waiting_for_replacement` |
| 4 | Some blocking Attempt is `submitted` or `timed_out_finalized` | `automatic_checking_pending` |
| 5 | Some blocking Attempt is `waiting_for_teacher_review` | `waiting_for_teacher_review` |
| 6 | The evaluation is ready but the row is missing or differs | `automatic_checking_pending` |
| 7 | Anything else | `no_completed_attempt` |

`OfficialScoreReading` carries the status and, only when `ready`, the row and the official Attempt.
The pair check (`OfficialTaskDesignation::isOfficial`) is the resolver's current rule, now shared.

### 5.3 Response — `200`

```json
{
  "data": {
    "assessment_id": "uuid",
    "assessment_type": "homework | blitz",
    "student_id": "uuid",
    "status": "ready",
    "official_attempt_id": "uuid",
    "attempt_number": 2,
    "normalized_score": 87.5,
    "selection_policy_code": "highest_valid_completed",
    "selected_at": "2026-09-30T10:00:00Z"
  }
}
```

Every field except the ids, `assessment_type` and `status` is `null` unless `status = ready`;
`normalized_score` is a JSON number (docs/09 §2.13) and `selected_at` a UTC timestamp.

## 6. Security and Integrity

- Tenant and Topic access are resolved from the authenticated Teacher; the Student id grants nothing by
  itself. The read never writes.

## 7. Tests

`tests/Feature/Teacher/TeacherOfficialScoreApiTest.php`:

- route registered once behind the Teacher gates; 401 and Student 403; query or body `422`.
- `404`: malformed ids, unknown ids, another Institution's Teacher, a Teacher whose membership ended, a
  Student who is not a recipient of this Assessment (including a recipient of another task).
- Every status row: practice Homework (1); Homework ready with policy, attempt number, score and
  `selected_at` (2); Blitz with exception while active, with no #2 and with #2 in progress (3); Homework
  with a submitted or timed-out blocking Attempt (4), also when a waiting one blocks too; waiting Homework
  (5), including a later waiting Attempt that could overtake a checked one; row missing and row differing
  from the live best (6); never started, only in progress, Blitz closed without a replacement (7).
- Blitz ready for a normal #1 (`valid_normal_blitz`) and a replacement #2
  (`approved_blitz_exception_replacement`); a checked but not overtakable later Attempt keeps `ready`.
- An active Blitz without an exception is never `waiting_for_replacement`; a row that differs only in its
  Attempt (equal scores) is not `ready`; a practice task in a Topic whose pair names another task is
  `not_applicable`; an archived Topic still reads.
- The read runs in one repeatable-read read-only snapshot: an exception grant or a replacement start
  committed by another connection between the Attempt read and the exception read is not seen, and the
  response reflects the complete earlier state.
- Not-ready responses carry nulls in every result field; the resolver's existing tests stay green.
- The file uses committed fixtures (`UsesBlitzReadSnapshot`), because the snapshot must be a top-level
  transaction.

## 8. Expected Files

```text
backend/app/Actions/Teacher/ShowTeacherOfficialScore.php
backend/app/Enums/OfficialScoreStatus.php
backend/app/Http/Controllers/Api/V1/Teacher/TeacherOfficialScoreController.php
backend/app/Http/Requests/Teacher/TeacherOfficialScoreShowRequest.php
backend/app/Http/Resources/Teacher/TeacherOfficialScoreResource.php
backend/app/Support/Checking/OfficialScoreReader.php
backend/app/Support/Checking/OfficialScoreReading.php
backend/app/Support/Checking/OfficialTaskDesignation.php
backend/app/Support/Checking/OfficialTaskScoreResolver.php
backend/routes/api.php
backend/tests/Feature/Teacher/TeacherOfficialScoreApiTest.php
tasks/backend/stage-09/S09-BE-007A-teacher-official-score-read.md
tasks/STAGE_09_TASK_INDEX.md
tasks/README.md
```

## 9. Acceptance Criteria

- [ ] §5 is implemented exactly; no existing response changes.
- [ ] The §7 tests pass.
- [ ] The backend Teacher and Checking feature suites pass.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.

## 10. Verification

```text
vendor/bin/phpunit tests/Feature/Teacher/TeacherOfficialScoreApiTest.php
vendor/bin/phpunit tests/Feature/Teacher tests/Feature/Checking
vendor/bin/pint --test <changed PHP files>
git diff --check
```
