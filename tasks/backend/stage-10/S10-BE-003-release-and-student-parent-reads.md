# Implementation Contract: S10-BE-003 — Release and Student/Parent Result Reads

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S10-BE-003` |
| Stage | `Stage 10 — Final Result and Understanding Assessment` |
| Area | `Backend + frontend parser` (new endpoints; Student Topic detail `result_status` value; Stage 9 Student result values) |
| Status | `Approved` |
| Depends on | `S10-BE-002` delivered (PR #318, `main` `b096f18`) |
| Implementation baseline | `origin/main` `b096f18` |
| Owner decisions applied | `S10-D2` (what Student/Parent see), `S10-D3` (window), `S10-D4` (Attempt-level release, practice), `S10-D5` (no hide), `S10-D6` (current modes), `S10-D7` (bulk release) |
| Technical decisions applied | `S10-T6` (locks, idempotent release), `S10-T8` (Parent route), `S10-T9` (parser ships with the backend change) |
| Implementation | Claude |
| Delivery | Claude opens the PR and merges it after review `PASS` and green verification |
| Blocks | `S10-BE-004` |

This file is the complete task contract (normative source: `S10-DOC-001` §§11, 12.5, 12.7, 14, 15;
`docs/09` §§17, 20.6, 27, 29.3, 29.5, 30.5).

## 2. Goal

Teachers release Topic results to Students and Parents (one Student or all ready results); Students and
Parents read the Topic result exactly as the visibility rule allows; a manual release also opens the
official Attempt results, and practice results are visible in every mode.

## 3. Scope

### Included

1. Teacher release: single and bulk, Student and Parent (§5.1), three new 409 codes (§5.2).
2. `GET /api/v1/student/topics/{topic}/result` (§5.3); the real `result_status` in `GET /student/topics/{topic}` with the Student parser change (§5.4).
3. Stage 9 Student reads per `S10-D4` (§5.5).
4. The `parent` route group and `GET /api/v1/parent/children/{student}/topics/{topic}/result` (§5.6).

### Non-goals

- Closure, bulk close, archive closure, `result_closed` guards and Homework-before-Blitz (`S10-BE-004`).
- Parent children list, dashboards and screens (Stage 11); any Student/Teacher screen (frontend plan).
- Any change to Teacher endpoints of `S10-BE-002` other than reusing them as release responses.

## 4. Current Implementation Context

- `TopicResultReader` (live results), `TopicResultVisibility::of(view, studentMode, parentMode)`,
  `TeacherTopicResults`, `ShowTeacherTopicResult` (detail in a snapshot), `UpdateTeacherTopicResultComment`
  (Topic lock, then the row) from `S10-BE-001`/`002`.
- Reader-based reads outside a Topic-locked transaction run in `StudentBlitzReadSnapshot::read` (level-0
  `REPEATABLE READ READ ONLY`); a Blitz exception graph read across statements needs it.
- `TeacherTopicLifecycleRequest` accepts an empty body or `{}` and no query parameters.
- `StudentResultVisibility::released(mode)` (automatic only) and `visible(attempt, task, released)`;
  callers `StudentHomeworkResults::apply` (Attempt `student_result`, `student_official_score`) and
  `ListStudentFinishedBlitz` (counting Attempt result and feedback); `OfficialTaskDesignation::officialIds`.
- `ShowStudentTopic` reads the Topic with `visibleToStudent` (current member; active/closed/archived);
  `StudentTopicResource` returns `result_status = waiting_for_homework` and the Student parser
  (`frontend/lib/features/student/data/dto/student_topic_dto.dart`) rejects any other value.
- `UserRole::Parent`, `ParentStudentRelationship::scopeCurrent`, factories `UserFactory::parent`,
  `ParentStudentRelationshipFactory`. No Parent route exists.

## 5. Exact Contract

### 5.1 Teacher release

Routes (Teacher group): `POST topics/{topic}/results/{student}/release/student`,
`POST topics/{topic}/results/{student}/release/parent`, `POST topics/{topic}/results/release/student`,
`POST topics/{topic}/results/release/parent`. Request: `TeacherTopicLifecycleRequest` (empty body or `{}`,
no query). Access as `S10-BE-002` §5.1 (`resolveTopic`; `{student}` UUID of a cohort Student, else `404`).

Transaction: `lockTopic` (group → membership → Topic `FOR UPDATE`); the live result(s) from
`TopicResultReader` inside it (scoring, Starts and grants wait on the Topic); the affected `topic_results`
rows `FOR UPDATE` in id order (missing rows are created); the current modes from `institution_settings`.

Single Student release — first match:

1. Current Student mode is not `manual_teacher` → `409 manual_release_not_allowed`.
2. `student_released_at` is set → `200` (no change).
3. The result is neither terminal nor closed, or the Student's work is not finished → `409 result_not_ready`.
4. Set `student_released_at = now`, `student_released_by_user_id = Teacher` → `200`.

Single Parent release — first match:

1. Current Parent mode is not `manual_teacher` → `409 manual_release_not_allowed`.
2. `parent_released_at` is set → `200` (no change).
3. The values are not visible to the Student now (`TopicResultVisibility`) → `409 student_result_not_released`.
4. Set `parent_released_at`, `parent_released_by_user_id` → `200`.

Single responses (after commit): `200 {"message": "Topic result released to the Student." | "Topic
result released to Parents.", "data": <S10-BE-002 detail>}`. A closed result is released like any other.

Bulk (all cohort Students, one transaction): the mode check fails the whole call with
`409 manual_release_not_allowed`; otherwise each Student follows rules 2-4: rule 2 → `skipped.already_done`,
rule 3 → `skipped.not_ready`, rule 4 → released. Response `200 {"message": "Topic results released to
Students." | "Topic results released to Parents.", "data": {"processed": n, "skipped": {"already_done":
a, "not_ready": b}}}` (all three counts always present).

### 5.2 New 409 codes

| Code | Message |
|---|---|
| `manual_release_not_allowed` | `Manual release is not allowed in the current release mode.` |
| `result_not_ready` | `The result is not ready to be released.` |
| `student_result_not_released` | `The result is not visible to the Student yet.` |

Each: an exception in `App\Exceptions`, an `ApiErrorResponse` method, a render mapping, an
`ApiErrorContractTest` case.

### 5.3 `GET /api/v1/student/topics/{topic}/result`

- Access: UUID; the Topic is in the Student's Institution and active, closed or archived; the Student is a
  current member of its group **or** a persisted recipient of the Topic's official Homework or Blitz;
  otherwise `404`. No query parameters and no body (`422`).
- One snapshot read: `forStudent` null → `{"data": null}`. Otherwise:

```json
{
  "data": {
    "topic_id": "uuid",
    "result_status": "calculated",
    "closed_outcome": null,
    "missing_component": null,
    "visible": true,
    "homework_score": 88,
    "blitz_score": 84,
    "final_score": 86,
    "calculation_method": "average",
    "category": { "code": "understood_well", "label": "Understood well" },
    "teacher_comment": "Revise question 4."
  }
}
```

- `visible` = `TopicResultVisibility::of(...)->studentVisible` with the current modes. When false, every
  value field (`homework_score`, `blitz_score`, `final_score`, `calculation_method`, `category`,
  `teacher_comment`) is null; `result_status`, `closed_outcome` and `missing_component` are always present.
- When visible: each side score when that side is `ready` (else null); `final_score` and
  `calculation_method` for a calculated result (open or closed); `category` the numeric category for
  calculated, Not completed for Not completed; the Teacher comment. Never D, T, consistency or
  `category_score`. Scores are JSON numbers of the stored values.

### 5.4 Student Topic detail

`ShowStudentTopic` reads the Topic, its materials and the Student's result in one snapshot;
`StudentTopicResource` returns `result_status` = the §5.3 status (null when the Student has no result).
Nothing else changes (`homework: []`, `blitz_status: not_available` stay). In the same PR the Student
parser accepts `result_status` ∈ the seven statuses or null and still rejects anything else; parser tests
cover each.

### 5.5 Stage 9 Student reads (`S10-D4`)

New `App\Support\Student\StudentResultRelease::forTasks(User $student, Collection $tasks,
?StudentResultReleaseMode $mode): array<string, bool>`: a practice task → true; an official task → mode is
`automatic`, or the Student's `topic_results` row of that task's Topic has `student_released_at`. Two
queries for any number of tasks. `StudentHomeworkResults` (Attempt `student_result`, answer feedback,
`student_official_score`) and `ListStudentFinishedBlitz` (counting Attempt) pass that per-task value to
`StudentResultVisibility::visible`; `released()` is removed. Response shapes do not change.

### 5.6 Parent

Route group `parent` with `auth:sanctum`, `active.account`, `password.changed`, `role:parent`;
`GET children/{student}/topics/{topic}/result`:

- Access: `{student}` UUID with a current `ParentStudentRelationship` of this Parent in the same
  Institution, and that Student's §5.3 access to the Topic; otherwise `404`. No query or body (`422`).
- `{"data": null}` when the current Parent mode is `hidden` or unconfigured, or the Student has no result.
- Otherwise the §5.3 shape with `visible` = `parentVisible` (values only then).

## 6. Security and Integrity

Release writes are Teacher-scoped and serialize on the Topic row with scoring, Starts, grants and closure.
Students and Parents read only their own (connected) result; access never comes from an identifier alone;
hidden values are never serialized; the Parent never sees answer feedback or Attempt results.

## 7. Tests

- **Release**: every first-match row for both kinds (mode, already released, not ready / Student not
  visible, success with actor and time); a closed result released; the detail returned; bulk counts with a
  mixed cohort and the whole-call mode conflict; other Teacher / outsider / bad id → `404`; strict body.
- **Errors**: the three codes in `ApiErrorContractTest`.
- **Student read**: access (current member, former member still in the cohort, non-member non-recipient
  → `404`, draft Topic → `404`, other Institution → `404`); `data: null` without a cohort; hidden values
  (window not open, manual unreleased, waiting status) and shown values (automatic, released, Not
  completed with one ready side, closed); exact JSON keys; strict query/body.
- **Topic detail**: `result_status` value and null; the parser test for every status, null and an unknown value.
- **Stage 9 reads**: under `manual_teacher` an official Homework/Blitz result and feedback appear only after
  the Topic release; a practice Homework and a practice closed Blitz result appear in `manual_teacher`
  and unconfigured modes; the automatic behavior is unchanged; constant query counts kept.
- **Parent**: current relationship required (ended relationship, other Parent, other Institution →
  `404`); hidden and unconfigured → `data: null`; `with_student` sees after the Student; `manual_teacher`
  only after the Parent release; never values while the Student cannot see them.

## 8. Expected Files

```text
backend/app/Actions/Teacher/ReleaseTeacherTopicResult.php, ReleaseTeacherTopicResults.php (or one action per kind)
backend/app/Actions/Student/ShowStudentTopicResult.php, ShowStudentTopic.php
backend/app/Actions/Parent/ShowParentChildTopicResult.php
backend/app/Http/Controllers/Api/V1/{Teacher/TeacherTopicResultController.php, Student/StudentTopicController.php, Parent/ParentChildTopicResultController.php}
backend/app/Http/Requests/{Student,Parent}/*TopicResult*Request.php
backend/app/Http/Resources/{Student,Parent}/*TopicResult*Resource.php, Student/StudentTopicResource.php
backend/app/Support/Student/StudentResultRelease.php, StudentResultVisibility.php, StudentHomeworkResults.php
backend/app/Actions/Student/ListStudentFinishedBlitz.php
backend/app/Exceptions/*.php, app/Support/ApiErrorResponse.php, bootstrap/app.php, routes/api.php
backend/tests/... ; frontend/lib/features/student/data/dto/student_topic_dto.dart and its test
tasks/backend/stage-10/S10-BE-003-release-and-student-parent-reads.md, tasks/STAGE_10_TASK_INDEX.md
```

## 9. Acceptance Criteria

- [ ] §5.1-§5.6 implemented exactly; existing responses change values only (Stage 9 visibility, Topic
      detail `result_status`), never shapes.
- [ ] Every §7 test group exists and passes; existing suites stay green (deliberate updates: the Student
      Topic detail test asserts the real status and runs on committed fixtures for the snapshot).
- [ ] Independent fresh-context review `PASS` (P1 = 0, P2 = 0).

## 10. Verification

```text
backend: pint --test; phpunit tests/Unit tests/Feature/Results tests/Feature/Teacher tests/Feature/Student tests/Feature/Parent tests/Feature/ApiErrorContractTest.php tests/Feature/Authorization
frontend: flutter test <student topic dto tests>; flutter analyze --no-pub lib/features/student; dart format check
git diff --check
```
