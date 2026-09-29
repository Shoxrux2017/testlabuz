# Implementation Contract: S09-BE-002 — Scoring Persistence and Homework Review Deadline

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S09-BE-002` |
| Stage | `Stage 9 — Checking and Scoring` |
| Area | `Backend` + the Teacher Homework parser in the frontend (`S09-T8`) |
| Status | `Approved` |
| Depends on | `S09-BE-001 — Accepted / Delivered` (PR #290, `main` `830b9b1`) |
| Implementation baseline | `origin/main` `830b9b1` (re-checked before implementation) |
| Owner decisions applied | `S09-D2` (optional Homework review deadline, reminder only) |
| Technical decisions applied | `S09-T8` (a backend change to an existing response ships with its parser change) |
| Implementation | Claude |
| Delivery | Claude opens the PR; the Project Owner merges |
| Blocks | `S09-BE-003` |

This file is the complete task contract.

## 2. Goal

Create the Stage 9 official-score storage that the resolver (`S09-BE-004`) will write, and let the Teacher
set an optional Homework review deadline (`review_due_at`) on create, update and a dedicated endpoint that
also works on a closed Homework. The Teacher Homework resource returns the new field, and the frontend
Teacher Homework parser accepts it in the same PR.

## 3. Scope

### Included

- One forward migration: table `official_task_scores`; column `homework_assignments.review_due_at`.
- Model `OfficialTaskScore`, enum `OfficialScoreSelectionPolicy`, factory `OfficialTaskScoreFactory`;
  `HomeworkAssignment` gains the fillable/cast column.
- Teacher Homework create and update accept `review_due_at`; new
  `PUT /api/v1/teacher/homework/{homework}/review-due-at`; the Teacher Homework resource returns
  `review_due_at`.
- Frontend: `TeacherHomeworkDto` reads `review_due_at`; `TeacherHomework.reviewDueAt`. No UI (that is
  `S09-FE-001`).
- `docs/08` §19.1/§25.12 record the constraints this migration adds beyond the documented table
  (`unique(official_attempt_id)`, the institution and selector foreign keys, `selected_by_user_id is null`).

### Non-goals

- No code writes `official_task_scores` rows (the resolver is `S09-BE-004`).
- No `review_summary` (`S09-BE-005`) and no review-queue index: the queue query shape is defined in
  `S09-BE-005`, which adds any supporting index with that query.
- `review_due_at` changes no score, status or official selection; Blitz has no review deadline.
- No Student resource returns `review_due_at`.

## 4. Current Implementation Context

- Tenant-safe foreign keys are composite `(institution_id, x_id) → parent(institution_id, id)` with
  `on delete restrict` (`2026_09_16_000000_create_blitz_persistence_domain_foundation.php`).
- Teacher Homework requests extend `TeacherHomeworkMutationRequest` (strict JSON object, unknown keys and
  query parameters rejected, `COMMON_INPUT_KEYS`, `deadline_at` syntax rule via
  `InstitutionHomeworkDeadlineAt::hasValidSyntax`).
- `InstitutionEducationalDateTime::parse($teacher, $value, $field)` enforces RFC 3339 with the institution
  timezone offset and returns a UTC `CarbonImmutable`; a mismatch is `422` on `$field`.
- `UpdateTeacherHomework`: resolves the Homework privately (`404`), locks Group, Topic, Assessment and
  Homework (`TeacherHomeworkLifecycleAccess::lockHomework`), then `ensureEditable`: closed →
  `409 task_closed`, archived → `409 task_archived`, Topic closed/archived → `409 topic_not_editable`.
  Fairness fields (`student_instructions`, `assignment_mode`, `student_ids`, `deadline_at`) conflict with
  existing Attempts (`409 business_conflict`). A no-change request returns the resource without writing.
- `TeacherHomeworkResource` builds the Teacher Homework resource returned by show, create, update,
  activate, close and archive.
- Frontend: `TeacherHomeworkDto.fromJson` uses `readExactTeacherMap` with `_homeworkKeys`: every key is
  required and unknown keys fail, so the new field must ship with the parser change.
- Tests that assert the current shape and change deliberately:
  `tests/Feature/Persistence/AssessmentHomeworkSchemaInspectionTest.php` (Homework columns; the
  "`official_task_scores` does not exist" assertion), `BlitzPersistenceSchemaInspectionTest.php` (same
  absence assertion), `tests/Feature/Teacher/TeacherHomeworkAuthoringApiTest.php` and
  `tests/Feature/Teacher/TeacherQuestionMutationApiTest.php` (exact Teacher Homework resource keys; Question
  mutations return that resource), and the frontend Teacher Homework JSON fixtures and `TeacherHomework`
  test builders.

## 5. Exact Contract

### 5.1 Migration `2026_09_29_000000_create_stage_9_scoring_persistence_foundation.php`

`official_task_scores`:

| Column | Type | Null |
|---|---|---|
| `id` | uuid, primary key | no |
| `institution_id` | uuid | no |
| `assessment_id` | uuid | no |
| `student_id` | uuid | no |
| `official_attempt_id` | uuid | no |
| `normalized_score` | numeric(12,8) | no |
| `selection_policy_code` | varchar(64) | no |
| `selected_by_user_id` | uuid | yes |
| `selected_at` | timestamptz | no |
| `created_at`, `updated_at` | timestamptz | no |

- `unique(assessment_id, student_id)` named `official_task_scores_assessment_student_unique`;
  `unique(official_attempt_id)` named `official_task_scores_official_attempt_unique`.
- Checks: `normalized_score between 0 and 100`; `selection_policy_code in ('highest_valid_completed',
  'valid_normal_blitz', 'approved_blitz_exception_replacement')`; `selected_by_user_id is null`.
- Foreign keys, all `on delete restrict`: `institution_id → institutions(id)`;
  `(institution_id, assessment_id) → assessments(institution_id, id)`;
  `(institution_id, student_id) → users(institution_id, id)`;
  `(institution_id, official_attempt_id) → assessment_attempts(institution_id, id)`;
  `(institution_id, selected_by_user_id) → users(institution_id, id)`.
- Same Student, same Assessment and pair membership of the official Attempt are enforced by the resolver
  (`S09-BE-004`), not by the schema.

`homework_assignments.review_due_at`: timestamptz, nullable, no default; existing rows stay null.

`down()` drops the column and the table.

### 5.2 Models

- Enum `App\Enums\OfficialScoreSelectionPolicy` (`HighestValidCompleted = 'highest_valid_completed'`,
  `ValidNormalBlitz = 'valid_normal_blitz'`, `ApprovedBlitzExceptionReplacement =
  'approved_blitz_exception_replacement'`) with `values()` like the other enums.
- Model `App\Models\OfficialTaskScore` (`HasUuids`, `HasFactory`), fillable: every column except `id` and
  timestamps; casts `normalized_score` → `decimal:8`, `selection_policy_code` → the enum, `selected_at` →
  `datetime`; relations `institution`, `assessment`, `student`, `officialAttempt`.
- `OfficialTaskScoreFactory`: a checked Homework Attempt of one recipient with
  `highest_valid_completed`, the Attempt's `normalized_score`, `selected_at = now()`.
- `HomeworkAssignment`: `review_due_at` fillable and cast `datetime`.

### 5.3 Teacher Homework create and update

- `review_due_at` joins the accepted keys of both requests: `sometimes`, nullable string, the same RFC 3339
  numeric-offset syntax rule as `deadline_at` with a `review_due_at` message.
- Parsing uses `InstitutionEducationalDateTime::parse($teacher, $value, 'review_due_at')` (institution
  offset required; stored as the UTC instant). `null` clears it. Past values are allowed; there is no
  ordering rule against `deadline_at`.
- Create stores it on the new `homework_assignments` row.
- Update: `review_due_at` is not a fairness field, so existing Attempts do not block it. It follows the
  existing editability: closed → `409 task_closed`, archived → `409 task_archived`, Topic closed/archived →
  `409 topic_not_editable`, in the existing order. A value equal to the stored instant is no change; a
  request whose only field is unchanged writes nothing (existing no-change behavior).
- An update whose only change is `review_due_at` saves just the Homework row, exactly like §5.4: it runs
  no assignment validation and no recipient synchronization (other edits keep the Stage 6 behavior).
- Fractional seconds are accepted by the syntax rule and dropped on storage (second precision), as for
  `deadline_at`.

### 5.4 `PUT /api/v1/teacher/homework/{homework}/review-due-at`

- Route next to the other Teacher Homework routes, same middleware; controller method
  `TeacherHomeworkController::updateReviewDueAt` → Action `SetTeacherHomeworkReviewDueAt`.
- Request `TeacherHomeworkReviewDueAtRequest`: `Content-Type: application/json`; a JSON object with exactly
  the key `review_due_at`, whose value is `null` or a string with the syntax rule above; any query
  parameter, missing key, extra key, other type or non-object body → `422 validation_failed`. No
  `Idempotency-Key` is required or read.
- Action, in one transaction:
  1. resolve the Homework like `UpdateTeacherHomework` (invisible or foreign → `404 resource_not_found`);
  2. lock with `TeacherHomeworkLifecycleAccess::lockHomework` (the Update lock order);
  3. archived Homework → `409 task_archived`; then Topic `closed` or `archived` →
     `409 topic_not_editable`; `draft`, `active` and `closed` Homework are allowed;
  4. parse the value (`review_due_at`, `422` on an offset mismatch) and save it only when the instant
     changes;
  5. return the Teacher Homework resource (`ShowTeacherHomework`), `200`, with
     `"message": "Homework review deadline updated successfully."` like the other Homework mutations.
- Existing Attempts, the result pair and the deadline do not affect it.

### 5.5 Teacher Homework resource

`TeacherHomeworkResource` adds `review_due_at` (UTC `Y-m-d\TH:i:s\Z` or `null`, like `deadline_at`) after
`deadline_at`. Every response that returns this resource carries it. The Teacher Homework list resource and
every Student resource are unchanged.

### 5.6 Frontend parser

- `_homeworkKeys` adds `review_due_at`; `TeacherHomeworkDto` reads it with
  `readTeacherNullableUtcTimestamp` and maps it to a new required `TeacherHomework.reviewDueAt`
  (`DateTime?`).
- The summary DTO and every other parser are unchanged. No widget changes.

## 6. Security

The new endpoint uses the existing Teacher Homework resolution and locks, so Institution, Topic ownership,
Group membership and privacy-safe `404` behave exactly as for Update. Foreign keys keep every official-score
reference inside one Institution.

## 7. Tests

Backend (feature tests, the testing database):

- `tests/Feature/Persistence/ScoringPersistenceSchemaTest.php`: exact `official_task_scores` columns, types,
  nullability, precision; both unique indexes; the three checks (score outside 0–100, unknown policy,
  non-null `selected_by_user_id`); every cross-institution foreign key rejected; restrictive parent
  deletion; the factory row persists; `homework_assignments.review_due_at` is a nullable timestamptz.
- `tests/Feature/Teacher/TeacherHomeworkReviewDueAtApiTest.php`:
  - create with an institution-offset value (stored UTC, returned), with `null`, without the key; a wrong
    offset and bad syntax → `422` on `review_due_at`;
  - update sets and clears it on `draft` and `active` Homework, also with existing Attempts; a wrong offset
    and bad syntax → `422` on `review_due_at`; the same instant writes nothing; a `review_due_at`-only update
    neither adds a Student who joined the Group later nor revalidates a deactivated selected Student;
    closed → `409 task_closed`; archived → `409 task_archived`; closed Topic → `409 topic_not_editable`;
  - `PUT …/review-due-at` sets and clears it on `draft`, `active` and `closed` Homework, also with
    Attempts; archived → `409 task_archived` (also when the Topic is archived); closed or archived Topic →
    `409 topic_not_editable`; strict body (missing key, extra key, number, array, non-JSON, query parameter
    → `422`); a wrong offset is reported on `review_due_at`; the same instant writes nothing; another
    Teacher's Homework, another Institution's Homework and an unknown id → `404`; a Student → the existing
    role rejection; the response is the full Teacher Homework resource with its message.
- `ScoringPersistenceSchemaTest` also asserts the exact definition of every foreign key.
- Deliberate updates: the two schema inspection tests and the exact-key assertions in
  `TeacherHomeworkAuthoringApiTest` and `TeacherQuestionMutationApiTest` (listed in §4).

Frontend: `teacher_homework_dto_test.dart` parses `review_due_at` present and `null` and rejects a
missing key and a non-UTC value; the Teacher Homework JSON fixtures and `TeacherHomework` builders gain
the field.

## 8. Expected Files

```text
backend/database/migrations/2026_09_29_000000_create_stage_9_scoring_persistence_foundation.php
backend/app/Enums/OfficialScoreSelectionPolicy.php
backend/app/Models/OfficialTaskScore.php
backend/app/Models/HomeworkAssignment.php
backend/database/factories/OfficialTaskScoreFactory.php
backend/app/Http/Requests/Teacher/TeacherHomeworkMutationRequest.php
backend/app/Http/Requests/Teacher/TeacherHomeworkCreateRequest.php
backend/app/Http/Requests/Teacher/TeacherHomeworkReviewDueAtRequest.php
backend/app/Actions/Teacher/CreateTeacherHomework.php
backend/app/Actions/Teacher/UpdateTeacherHomework.php
backend/app/Actions/Teacher/SetTeacherHomeworkReviewDueAt.php
backend/app/Http/Controllers/Api/V1/Teacher/TeacherHomeworkController.php
backend/app/Http/Resources/Teacher/TeacherHomeworkResource.php
backend/routes/api.php
backend/tests/Feature/Persistence/ScoringPersistenceSchemaTest.php
backend/tests/Feature/Persistence/AssessmentHomeworkSchemaInspectionTest.php
backend/tests/Feature/Persistence/BlitzPersistenceSchemaInspectionTest.php
backend/tests/Feature/Teacher/TeacherHomeworkReviewDueAtApiTest.php
backend/tests/Feature/Teacher/TeacherHomeworkAuthoringApiTest.php
backend/tests/Feature/Teacher/TeacherQuestionMutationApiTest.php
docs/08-database.md
frontend/lib/features/teacher/data/dto/teacher_homework_dto.dart
frontend/lib/features/teacher/domain/teacher_homework.dart
frontend/test/features/teacher/ (Teacher Homework fixtures, builders and DTO test)
tasks/backend/stage-09/S09-BE-002-scoring-persistence-review-deadline.md
tasks/STAGE_09_TASK_INDEX.md
tasks/README.md
```

## 9. Acceptance Criteria

- [ ] §5 is implemented exactly; `review_due_at` never affects any score, status or selection.
- [ ] The §7 tests pass; the deliberate test updates are only those listed.
- [ ] The frontend accepts the new resource shape; no other response changes.
- [ ] An independent fresh-context review finds P1 = 0, P2 = 0.

## 10. Verification

Backend (app container):

```text
php artisan migrate:fresh --env=testing   (through the test suite's RefreshDatabase)
vendor/bin/phpunit tests/Feature/Persistence tests/Feature/Teacher/TeacherHomeworkReviewDueAtApiTest.php tests/Feature/Teacher/TeacherHomeworkAuthoringApiTest.php tests/Feature/Teacher/TeacherHomeworkLifecycleApiTest.php tests/Feature/Teacher/TeacherQuestionMutationApiTest.php tests/Feature/Teacher/TeacherHomeworkRecipientApiTest.php
vendor/bin/pint --test <changed PHP files>
```

Frontend (`frontend/.fvm/flutter_sdk`):

```text
flutter test test/features/teacher
flutter analyze
dart format --output=none --set-exit-if-changed <changed Dart files>
```

`git diff --check`. The full backend suite is a Backend Phase 2 activity.
