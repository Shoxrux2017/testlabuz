# Codex Implementation Contract: S06-BE-003 — Teacher Homework Authoring and Recipient Discovery API

## 1. Metadata

| Field | Value |
|---|---|
| Task ID | `S06-BE-003` |
| Stage | `Stage 6 — Homework Assignment Management` |
| Area | `Backend` |
| Status | `Accepted` |
| Delivery | `Delivered — PR #147` |
| Delivered merge | `503f5702b7db536610b2772f2940f32028f8f4af` |
| Acceptance review | `PASS — P1=0, P2=0, P3=0` |
| Implementation type | `Laravel Teacher API + transactional Homework authoring` |
| Depends on | `S06-BE-001`, `S06-BE-002` — both `Accepted / Delivered` before implementation |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |
| Implementation baseline | ChatGPT must re-check/freeze current `origin/main` after dependencies are delivered and immediately before Codex execution |
| Implementation Readiness Gate | `PASS` |
| Verification | `Codex — focused task verification only` |
| Delivery execution | `Project Owner` |

Start only when both dependencies are `Accepted / Delivered`, this task remains `Approved`, ChatGPT has re-checked current `origin/main`, and Git preflight is safe.

This file is the complete task-specific implementation contract. Do not create a duplicate `CODEX-PROMPT` file.

---

## 2. Implementation Authority and Context Discipline

Codex may read only:

1. this contract;
2. root `AGENTS.md`;
3. `backend/AGENTS.md`;
4. delivered S06-BE-001/S06-BE-002 source and focused tests directly needed here;
5. current Teacher Topic/Group request/action/resource patterns directly needed for implementation.

Do not read product docs, roadmap, architecture/database/API docs, previous task files, Stage history, Stage indexes, or closure reviews to determine requirements.

If delivered dependencies materially conflict with the names/invariants below, return `BLOCKED`. Do not redesign them independently.

---

## 3. Goal

Expose the first Teacher Homework authoring surface so an authorized Teacher can:

- discover current eligible Students in an assigned Group;
- list Homework for an authorized Topic;
- create a new draft Homework under an authorized Topic;
- optionally create its initial typed Question set atomically;
- retrieve full authoring detail;
- update Homework metadata, deadline, and assignment scope under editing-integrity rules.

Institution, Teacher, Topic ownership, lifecycle state, fixed attempt count, and total points remain server-authoritative.

---

## 4. Included Endpoints

Implement exactly:

```text
GET   /api/v1/teacher/groups/{group}/students
GET   /api/v1/teacher/topics/{topic}/homework
POST  /api/v1/teacher/topics/{topic}/homework
GET   /api/v1/teacher/homework/{homework}
PATCH /api/v1/teacher/homework/{homework}
```

All stay inside the existing Teacher middleware group:

```text
auth:sanctum
active.account
password.changed
role:teacher
```

---

## 5. Explicit Non-Goals

Do not implement:

- Homework activate/close/archive;
- Question add/update/delete/reorder endpoints;
- official Homework designation or result-pair API;
- Student Homework/Attempt APIs;
- deadline runtime auto-finalization;
- checking/scoring/official score;
- Student submission files;
- Blitz;
- Topic result calculation;
- notifications;
- frontend;
- seed/E2E data;
- docs changes;
- dependency additions;
- task/Stage bookkeeping.

Never accept as writable Homework fields:

```text
institution_id
teacher_id
topic_id
status
activated_at
closed_at
archived_at
total_possible_points
attempt_limit
normal_attempts
official_score_policy
created_at
updated_at
```

---

## 6. Current Implementation Context to Reuse

Preserve current Stage 5 conventions:

- Teacher routes already enforce the Teacher middleware chain above;
- `Topic::visibleToTeacher()` and `TeacherTopicLifecycleAccess` provide privacy-safe Teacher/Topic scope;
- current Teacher authorization requires current `GroupTeacherMembership` (`ended_at IS NULL`);
- `ListTeacherGroups` exposes only active currently assigned Groups;
- current `GroupStudentMembership` uses `ended_at IS NULL` for current membership;
- current Teacher API has no Teacher Group Student roster;
- current mutation requests require an `application/json` object, reject unknown/protected fields and mutation query parameters;
- `InstitutionLessonAt` validates explicit-offset RFC3339 against the authenticated Institution IANA timezone and persists UTC.

Do not broaden `Topic::visibleToTeacher()` or former membership access.

---

## 7. Dependency Contracts

S06-BE-001 must already provide:

```text
assessments
homework_assignments
assessment_students
assessment_attempts
App\Models\Assessment
App\Models\HomeworkAssignment
App\Models\AssessmentStudent
App\Models\AssessmentAttempt
```

Homework public identity is the shared Assessment UUID:

```text
assessments.id == homework_assignments.assessment_id
```

Fixed normal Homework attempts are exactly `3`; no configurable attempt-limit field exists.

S06-BE-002 must already provide:

```text
Question + typed child models
QuestionAuthoringLimits
QuestionPositionSetValidator
QuestionConfigurationValidator
```

Nested create must reuse these typed contracts rather than reimplementing nine independent decision trees.

---

# 8. Teacher Group Student Discovery

## 8.1 Endpoint

```text
GET /api/v1/teacher/groups/{group}/students
```

## 8.2 Authorized Group

`{group}` must resolve only when:

- valid UUID;
- same Institution as authenticated Teacher;
- Group `status = active`;
- current `GroupTeacherMembership` for this Teacher with `ended_at IS NULL`.

Malformed, foreign, inactive, or unassigned Group:

```text
404 resource_not_found
```

## 8.3 Eligible Students

Return only users satisfying all:

- same Institution;
- `role = student`;
- `is_active = true`;
- current membership in this Group;
- membership `ended_at IS NULL`.

Former members and inactive Students are excluded.

## 8.4 Query

Allowed only:

```text
search
page
per_page
```

Defaults:

```text
page = 1
per_page = 50
```

Maximum `per_page = 100`.

`search`:

- optional trimmed string;
- max 100 chars;
- empty -> no search;
- literal case-insensitive substring over `full_name` and `login_name`;
- escape `%`, `_`, and SQL LIKE escape characters.

Unknown query -> `422 validation_failed`.

Ordering is fixed:

```text
lower(full_name) ASC
id ASC
```

## 8.5 Resource

Return exactly:

```json
{
  "id": "student-uuid",
  "full_name": "Student Name",
  "login_name": "student01"
}
```

Do not expose email, phone, Institution ID, membership IDs, parent data, role, or password/account metadata.

Use standard pagination envelope.

---

# 9. Homework List for Topic

## 9.1 Endpoint

```text
GET /api/v1/teacher/topics/{topic}/homework
```

Resolve Topic through existing privacy-safe Teacher scope. Read is allowed for Topic statuses:

```text
draft
active
closed
archived
```

Inaccessible Topic -> `404 resource_not_found`.

## 9.2 Query

Allowed:

```text
status
assignment_mode
search
sort
direction
page
per_page
```

Defaults:

```text
sort = created_at
direction = desc
page = 1
per_page = 20
```

Max `per_page = 100`.

Allowed status:

```text
draft active closed archived
```

Allowed assignment mode:

```text
group selected_students
```

Allowed sort:

```text
created_at title deadline_at status
```

Allowed direction:

```text
asc desc
```

`search` is optional, trimmed, max 160, literal case-insensitive title substring.

Unknown query -> `422 validation_failed`.

List only Homework Assessments for this exact Topic, authenticated Institution, and authenticated Teacher.

For nullable deadline sorting use `NULLS LAST` in both directions. Add Assessment `id` as deterministic tie-breaker.

## 9.3 List resource

Each item:

```json
{
  "id": "homework-uuid",
  "topic_id": "topic-uuid",
  "title": "Homework 1",
  "assignment_mode": "group",
  "total_possible_points": 10.0,
  "question_count": 5,
  "deadline_at": "2026-09-10T13:00:00Z",
  "institution_timezone": "Asia/Tashkent",
  "status": "draft",
  "created_at": "2026-09-01T08:00:00Z",
  "updated_at": "2026-09-01T08:00:00Z"
}
```

`deadline_at` may be null. Obtain `question_count` without N+1.

---

# 10. Create Homework

## 10.1 Endpoint

```text
POST /api/v1/teacher/topics/{topic}/homework
```

Creation is allowed only under authorized Topic status:

```text
draft
active
```

Closed/archived Topic:

```text
409 topic_not_editable
```

A newly created Homework is always draft with all lifecycle timestamps null.

## 10.2 Strict request body

Must be an `application/json` object. Allowed top-level keys only:

```text
title
description
student_instructions
assignment_mode
student_ids
deadline_at
questions
```

Canonical example:

```json
{
  "title": "Homework 1",
  "description": "Optional description",
  "student_instructions": "Answer all questions.",
  "assignment_mode": "group",
  "student_ids": [],
  "deadline_at": "2026-09-10T18:00:00+05:00",
  "questions": []
}
```

No query parameters.

Unknown/protected field -> `422 validation_failed`.

## 10.3 Common validation

`title`:

```text
required JSON string
trim
1..255 chars
```

`description`:

```text
optional JSON string|null
max 10000 chars
```

`student_instructions`:

```text
required JSON string
trim
1..10000 chars
```

`assignment_mode` exact:

```text
group
selected_students
```

`student_ids`:

- required JSON array;
- UUID strings only;
- no duplicates.

`deadline_at`:

- optional nullable JSON string;
- strict explicit-offset RFC3339;
- local wall-clock/offset must match current Institution IANA timezone;
- persist UTC;
- a past deadline is allowed in draft and is rejected only later at activation if still past.

`questions`:

- optional, omitted => `[]`;
- JSON array;
- max delivered `QuestionAuthoringLimits::MAX_QUESTIONS_PER_ASSESSMENT`.

---

# 11. Nested Question Create

Each Question object accepts exactly:

```text
client_key
type
prompt
instructions
points
position
checking_mode
configuration
```

`client_key`:

- required request-only correlation key;
- not persisted as Question identity;
- regex `^[A-Za-z][A-Za-z0-9_-]{0,79}$`;
- unique in the create request.

`prompt`:

- required trimmed non-empty string;
- max delivered `MAX_PROMPT_LENGTH`.

`instructions`:

- optional nullable string;
- if non-null, not whitespace-only;
- max delivered `MAX_INSTRUCTIONS_LENGTH`.

`points`:

- required JSON number, not numeric string;
- finite;
- `0 <= points <= 999999.999999`;
- max 6 fractional digits.

`position`:

- required JSON integer;
- complete set must be exact contiguous `1..N` via delivered `QuestionPositionSetValidator`.

`configuration`:

- required JSON object;
- `{}` allowed only where S06-BE-002 permits empty config;
- JSON array `[]` is not equivalent to `{}`;
- validate type/mode/config using delivered `QuestionConfigurationValidator`.

Persist Question and normalized child rows in the same Homework transaction.

For Matching, generate one server UUID `match_key` per pair; request `client_key` is not answer-key authority.

For File Based, no child row is needed; fixed extensions remain:

```text
pdf docx ppt pptx
```

---

# 12. Server-Derived Total Points

Client cannot write `total_possible_points`.

Create:

```text
App\Domain\Assessment\AssessmentPointMath
```

Required behavior:

- inputs already validated to max 6 decimals;
- convert to integer micro-points (`scale = 6`);
- sum with 64-bit integer arithmetic;
- return canonical scale-6 decimal for persistence;
- no epsilon/fuzzy/binary-float accumulation.

With max 100 Questions and max `999999.999999` each, total remains inside `numeric(14,6)`.

This helper must be reusable by S06-BE-004/S06-BE-005.

---

# 13. Assignment Scope / Recipient Rules

## 13.1 Group draft

For:

```text
assignment_mode = group
```

request must contain exactly:

```json
"student_ids": []
```

A draft Group Homework creates **no** `assessment_students` rows. Group snapshot happens on activation in S06-BE-005.

## 13.2 Selected Students draft

For:

```text
assignment_mode = selected_students
```

`student_ids` must be non-empty.

Every supplied UUID must currently be:

- same Institution;
- role Student;
- active user;
- current member of Topic Group with `ended_at IS NULL`.

Any invalid/ineligible selected ID -> `422 validation_failed` on `student_ids`, without revealing whether it exists elsewhere.

Persist one `assessment_students` row per selected Student:

```text
assignment_source = direct
assigned_at = server now
assigned_by_user_id = authenticated Teacher
```

Selected Homework is practice-only; this task does not designate official Homework and must not accept `is_official`.

---

# 14. Create Transaction and Locking

Creation uses one DB transaction.

Lock/re-check in stable parent order:

1. Topic Group;
2. current Teacher–Group membership;
3. Topic.

For selected assignment, resolve/lock requested Student and current Group membership state before persistence.

Atomically create:

1. Assessment row (`type=homework`);
2. HomeworkAssignment draft row;
3. selected recipient rows when applicable;
4. nested Questions;
5. typed Question child rows;
6. server-derived total points.

Any failure rolls back everything. No partial Homework shell may remain.

---

# 15. Homework Detail

## 15.1 Endpoint

```text
GET /api/v1/teacher/homework/{homework}
```

`{homework}` is Assessment UUID.

Resolve only when all hold:

- `type=homework`;
- same Institution;
- `teacher_id = authenticated Teacher`;
- owning Topic is still visible through current Teacher/Group membership.

Malformed, foreign, other Teacher, inaccessible Topic, or non-Homework Assessment:

```text
404 resource_not_found
```

Eager-load complete authoring detail without N+1:

- HomeworkAssignment;
- Topic identity needed by resource;
- selected recipient IDs when selected mode;
- Questions ordered by position;
- all typed child config needed for serialization.

Do not load Attempt answers.

---

# 16. Full Homework Resource

Exact top-level fields:

```json
{
  "data": {
    "id": "homework-uuid",
    "topic_id": "topic-uuid",
    "title": "Homework 1",
    "description": "Optional description",
    "student_instructions": "Answer all questions.",
    "assignment_mode": "selected_students",
    "student_ids": ["student-uuid"],
    "total_possible_points": 10.0,
    "deadline_at": "2026-09-10T13:00:00Z",
    "institution_timezone": "Asia/Tashkent",
    "status": "draft",
    "attempt_policy": {
      "normal_attempts": 3,
      "official_score_policy": "highest_valid_completed"
    },
    "activated_at": null,
    "closed_at": null,
    "archived_at": null,
    "created_at": "2026-09-01T08:00:00Z",
    "updated_at": "2026-09-01T08:00:00Z",
    "questions": []
  }
}
```

Rules:

- authoritative timestamps UTC RFC3339 `...Z`;
- `institution_timezone` is current Institution timezone;
- selected mode -> persisted selected recipient UUIDs sorted ascending;
- group mode -> `student_ids = []`;
- fixed attempt policy is literal server-owned contract;
- no Institution ID, Teacher ID, attempt limit, or recipient row IDs.

## 16.1 Teacher Question resource

Every Question:

```json
{
  "id": "question-uuid",
  "type": "single_choice",
  "prompt": "Question text",
  "instructions": null,
  "points": 1.0,
  "position": 1,
  "checking_mode": "automatic",
  "configuration": {}
}
```

Reconstruct canonical configuration from normalized rows:

Single/Multiple Choice:

```json
{"options":[{"text":"A","is_correct":true,"position":1}]}
```

True/False:

```json
{"correct_value":true}
```

Short automatic:

```json
{"accepted_answers":["DNS"]}
```

Short manual / Open Written:

```json
{}
```

File Based:

```json
{"allowed_extensions":["pdf","docx","ppt","pptx"]}
```

Matching:

```json
{"pairs":[{"client_key":"server-match-key-uuid","left":"DNS","right":"Domain Name System"}]}
```

Return persisted server `match_key` as Teacher readback `client_key`; it is not separately addressable API authority. Order by left position.

Ordering:

```json
{"items":[{"text":"First","correct_position":1}]}
```

Fill Blank:

```json
{"blanks":[{"key":"host","position":1,"accepted_answers":["domain name"]}]}
```

Do not expose internal child-row UUIDs.

Malformed persisted typed config is an internal integrity failure; do not fabricate missing answer-key data.

---

# 17. Create Success

Success:

```text
201 Created
```

Return full Homework resource with:

```json
{"message":"Homework created successfully."}
```

Use existing Resource `additional()` pattern.

---

# 18. PATCH Homework

## 18.1 Endpoint

```text
PATCH /api/v1/teacher/homework/{homework}
```

Allowed update keys only:

```text
title
description
student_instructions
assignment_mode
student_ids
deadline_at
```

`questions` is not accepted by PATCH; Question mutation belongs to S06-BE-004.

Body must be JSON object, no query parameters, at least one allowed key.

Validate fields with same rules as create and evaluate assignment rules against the resulting complete state.

## 18.2 Closed/archived boundaries

Homework `closed`:

```text
409 task_closed
```

Homework `archived`:

```text
409 task_archived
```

If owning Topic is closed or archived, mutation is blocked:

```text
409 topic_not_editable
```

Read remains allowed.

## 18.3 Draft editing

All allowed fields may change.

Draft group invariant:

```text
student_ids=[]
assessment_students=none
```

Draft selected mode stores exact direct recipient set.

Recipient set changes must be delta-based:

- preserve unchanged rows and `assigned_at`;
- delete only removed rows;
- add only new rows.

Transitions:

```text
group -> selected_students
selected_students -> group
```

are allowed while draft.

If a corrupt/unexpected Attempt already exists for draft Homework, do not delete recipient history; reject fairness-relevant mutation with `409 business_conflict`.

## 18.4 Active before Student activity

For active Homework with zero Attempts, all allowed fields may change.

Recipient snapshot must be synchronized atomically to resulting assignment mode.

Active group mode snapshot = all current active Student users with current Topic-Group membership at update transaction time, rows marked `assignment_source=group`.

Active selected mode = supplied current eligible set, rows marked `assignment_source=direct`.

Preserve unchanged recipient rows where possible; synchronize only delta.

## 18.5 Active after Student activity

If **any** `assessment_attempts` row exists:

Allowed safe metadata only:

```text
title
description
```

Locked fairness-relevant fields:

```text
student_instructions
assignment_mode
student_ids
deadline_at
```

A semantic change to any locked field:

```text
409 business_conflict
```

Do not expose Student/Attempt details.

If a blocked field is supplied but is exactly equal to current authoritative state, treat it as no-op for that field rather than a semantic change.

---

# 19. PATCH Transaction / Concurrency

Use one DB transaction.

Stable lock order:

1. Topic Group;
2. current Teacher–Group membership;
3. Topic;
4. Assessment;
5. HomeworkAssignment;
6. relevant Attempt existence/lock;
7. existing recipient rows;
8. Student/User/current membership rows needed for recipient changes.

Re-check authorization, lifecycle, Attempt existence, and selected eligibility after locks.

Concurrent membership loss must not allow newly ineligible Student assignment.

Concurrent first Attempt versus fairness-relevant edit must serialize so either the edit commits before activity begins or the edit observes activity and is rejected.

No optimistic version field in this task.

---

# 20. No-Op / Timestamp Semantics

If normalized requested state equals current authoritative state:

- return `200 OK` full resource;
- return normal success message;
- do not save Assessment/HomeworkAssignment;
- do not delete/reinsert recipients;
- preserve all `updated_at`;
- preserve recipient `assigned_at`;
- do not touch Questions.

Compare selected recipient IDs as a set, not request order.

Compare deadlines by authoritative UTC instant.

---

# 21. Deadline Timezone Refactor

Do not copy/paste a second independent `InstitutionLessonAt` implementation.

Introduce a reusable internal parser, e.g.:

```text
App\Support\Teacher\InstitutionEducationalDateTime
```

It owns:

- explicit-offset RFC3339 syntax;
- Institution IANA timezone lookup;
- local wall-clock/offset agreement;
- UTC conversion.

Keep existing Stage 5 `InstitutionLessonAt` public behavior exactly unchanged by delegating internally.

Add a Homework wrapper, e.g.:

```text
App\Support\Teacher\InstitutionHomeworkDeadlineAt
```

which reports invalid input on:

```text
errors.deadline_at
```

Invalid deadline -> `422 validation_failed`.

Do not use device timezone.

---

# 22. Homework Access / Application Placement

Add one focused access helper, e.g.:

```text
App\Support\Teacher\TeacherHomeworkAccess
```

Responsibilities only:

- UUID guard;
- privacy-safe Homework resolution;
- enforce Homework type, Institution, Teacher ownership, owning Topic visibility/current membership;
- stable mutation lock/re-resolve support.

No lifecycle transitions inside the access helper.

Expected Actions:

```text
ListTeacherGroupStudents
ListTeacherHomework
CreateTeacherHomework
ShowTeacherHomework
UpdateTeacherHomework
```

A narrow reusable typed writer is allowed/expected:

```text
App\Support\Assessment\QuestionConfigurationWriter
```

It may create normalized typed child rows from already validated config and generate Matching `match_key`. It must not authorize, score, know HTTP, or decide lifecycle.

Use thin controllers. Do not introduce a generic repository/service framework.

---

# 23. Strict Input Rules

Mutation endpoints must:

- require `application/json` media type;
- require JSON object body;
- reject array/scalar/null/empty/malformed bodies;
- reject unknown/protected keys;
- reject query parameters;
- not silently cast boolean/string/numeric mismatches;
- require UUIDs as strings;
- require `student_ids`/`questions` as arrays;
- require nested Question/config entries as JSON objects;
- trim only intended simple human-entered fields such as title, student instructions, Question prompt;
- not silently rewrite accepted-answer/config text.

---

# 24. Error Contract

| Case | Required result |
|---|---|
| Unauthenticated | `401 authentication_required` |
| Password gate | `403 password_change_required` |
| Inaccessible Topic/Homework/Group | `404 resource_not_found` |
| Unknown/protected/invalid input | `422 validation_failed` |
| Ineligible selected Student set | `422 validation_failed` |
| Invalid deadline timezone/offset | `422 validation_failed` |
| Invalid nested Question/config | `422 validation_failed` |
| Closed/archived Topic mutation | `409 topic_not_editable` |
| Closed Homework | `409 task_closed` |
| Archived Homework | `409 task_archived` |
| Fairness-relevant edit after activity | `409 business_conflict` |
| Unexpected failure | safe existing `500 server_error` |

Use existing global envelopes; do not leak SQL, stack traces, or cross-Tenant existence.

---

# 25. Query / Resource Performance

Avoid N+1.

Homework list:

- eager-load HomeworkAssignment;
- use `withCount('questions')` or equivalent;
- resolve Institution timezone once per request.

Homework detail:

- eager-load complete typed Question graph in bounded relation queries;
- selected recipient IDs in one relation query;
- no Attempt answer loading.

Roster:

- one scoped paginated eligible-user/current-membership query;
- no per-Student membership queries.

---

# 26. Expected Files and Areas

| Area | Action |
|---|---|
| `backend/routes/api.php` | Add five Teacher routes only |
| `backend/app/Actions/Teacher/ListTeacherGroupStudents.php` | Create |
| `backend/app/Actions/Teacher/ListTeacherHomework.php` | Create |
| `backend/app/Actions/Teacher/CreateTeacherHomework.php` | Create |
| `backend/app/Actions/Teacher/ShowTeacherHomework.php` | Create |
| `backend/app/Actions/Teacher/UpdateTeacherHomework.php` | Create |
| `backend/app/Support/Teacher/TeacherHomeworkAccess.php` | Create |
| shared Institution educational datetime support | Create/refactor narrowly |
| `backend/app/Support/Teacher/InstitutionLessonAt.php` | Minimal delegation only; preserve Stage 5 contract |
| Homework deadline wrapper | Create |
| `backend/app/Support/Assessment/QuestionConfigurationWriter.php` or equivalent | Create |
| `backend/app/Domain/Assessment/AssessmentPointMath.php` | Create |
| Teacher Homework/roster controllers | Create |
| Teacher Homework/roster Requests | Create |
| Teacher Homework/Question/roster Resources | Create |
| S06-BE-001/S06-BE-002 models | Modify only if narrowly required relation/query helper is missing |
| `backend/tests/Feature/Teacher/TeacherHomeworkAuthoringApiTest.php` | Create |
| `backend/tests/Feature/Teacher/TeacherHomeworkRecipientApiTest.php` | Create |
| `backend/tests/Feature/Teacher/TeacherHomeworkAuthorizationApiTest.php` | Create |
| `backend/tests/Feature/Teacher/TeacherHomeworkConcurrencyTest.php` | Create when concurrency coverage is clearer separately |
| `backend/tests/Unit/Domain/Assessment/AssessmentPointMathTest.php` | Create |

Do not modify docs, frontend, seeders, dependencies, bookkeeping, or unrelated code.

---

# 27. Acceptance Criteria

- [x] Teacher roster returns only current active eligible Students of an authorized active Group.
- [x] Foreign/inactive/unassigned Groups and former/inactive Students cannot be exposed.
- [x] Topic Homework list is tenant/Teacher/Topic scoped, paginated, searchable/filterable/sortable, deterministic, and N+1 safe.
- [x] Teacher can create draft Homework under own draft/active Topic.
- [x] Closed/archived Topic blocks create.
- [x] Strict payload rejects protected ownership/lifecycle/attempt/total fields.
- [x] Group draft requires empty `student_ids` and creates no recipient rows.
- [x] Selected draft requires current eligible Students and persists direct recipient rows.
- [x] Cross-Tenant/ineligible selected IDs cannot expand scope.
- [x] Deadline validates Institution timezone/offset and persists UTC; past draft deadline is allowed.
- [x] Nested create supports all nine S06-BE-002 Question types and zero Questions.
- [x] Invalid nested config rolls back the entire Homework create.
- [x] Matching generates server `match_key`.
- [x] Total points are server-derived with exact scale-6 math.
- [x] Full resource returns fixed attempt policy `3` / `highest_valid_completed`.
- [x] Teacher Question resource reconstructs canonical config without child-row IDs.
- [x] PATCH does not accept Question edits.
- [x] Draft PATCH supports metadata/assignment/deadline changes.
- [x] Active/no-Attempt PATCH safely supports pre-activity recipient/deadline/instruction changes.
- [x] Any Attempt locks fairness-relevant active fields but title/description remain safe metadata.
- [x] Closed/archived Homework is read-only.
- [x] Closed/archived Topic blocks Homework mutation.
- [x] No-op PATCH preserves timestamps and unchanged recipient rows.
- [x] Concurrent membership loss and concurrent first Attempt are handled safely.
- [x] Stage 5 lesson-at behavior remains unchanged after parser refactor.
- [x] No lifecycle endpoints, Student Attempt APIs, scoring, official designation, Blitz, frontend, docs, seeders, dependencies, or unrelated refactor enters scope.
- [x] Focused tests pass.
- [x] Pint passes.
- [x] `git diff --check` passes.

---

# 28. Focused Tests and Verification

Run from `backend/`.

Do not run the full backend suite; that belongs to Stage 6 Backend Phase 2.

## 28.1 New tests

```bash
php artisan test \
  tests/Feature/Teacher/TeacherHomeworkAuthoringApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkRecipientApiTest.php \
  tests/Feature/Teacher/TeacherHomeworkAuthorizationApiTest.php
```

If concurrency is separate:

```bash
php artisan test tests/Feature/Teacher/TeacherHomeworkConcurrencyTest.php
```

Required cases include:

- roster authorization/current Student eligibility/search/pagination/privacy;
- list filters/search/sort/pagination and foreign scope;
- own/foreign/other-Teacher/non-Homework detail;
- minimal empty draft create;
- group and selected recipient create;
- invalid selected IDs;
- draft/active Topic allowed; closed/archived blocked;
- strict request body/query/protected keys;
- deadline valid/mismatch/past-draft behavior;
- parameterized initial create across all nine Question types;
- invalid Question rollback;
- duplicate question key/position errors;
- server-derived total points;
- draft recipient transitions and delta preservation;
- active/no-attempt recipient synchronization;
- active/with-attempt lock rules;
- closed/archived boundaries;
- no-op timestamp preservation;
- `questions` rejected by PATCH.

## 28.2 Point math

```bash
php artisan test tests/Unit/Domain/Assessment/AssessmentPointMathTest.php
```

Cover integer, 1–6 decimals, `0.1 + 0.2`, zero, and max safe aggregate without binary-float drift.

## 28.3 Dependency regression

Run delivered S06-BE-001 focused persistence tests:

```bash
php artisan test \
  tests/Feature/Persistence/AssessmentHomeworkSchemaInspectionTest.php \
  tests/Feature/Persistence/AssessmentHomeworkPersistenceTest.php \
  tests/Feature/Persistence/AssessmentHomeworkFactoryModelTest.php
```

Run delivered S06-BE-002 focused persistence/domain tests:

```bash
php artisan test \
  tests/Feature/Persistence/QuestionSchemaInspectionTest.php \
  tests/Feature/Persistence/QuestionPersistenceTest.php \
  tests/Feature/Persistence/QuestionFactoryModelTest.php \
  tests/Unit/Domain/Assessment/QuestionConfigurationValidatorTest.php \
  tests/Unit/Domain/Assessment/QuestionPositionSetValidatorTest.php
```

Because `InstitutionLessonAt` may delegate to shared support, run:

```bash
php artisan test tests/Feature/Teacher/TeacherTopicMutationApiTest.php
```

## 28.4 Format / Always

```bash
./vendor/bin/pint --test
git diff --check
```

Then focused diff self-check:

- only task-owned API/support/tests changed;
- no delivered migration rewritten;
- no Stage 5 authorization/timezone behavior weakened;
- no lifecycle/Student Attempt/scoring/result-pair/Blitz code;
- no N+1 loop or cross-Tenant direct-ID lookup;
- no mass assignment of protected fields;
- no test weakening/debug/secrets/temp artifacts/unrelated churn.

Project Owner manual check:

```text
Not required at task level — backend API behavior is covered by focused tests.
Real-stack Teacher builder smoke belongs to S06-INT-001.
```

---

# 29. Delivery

Delivery owner:

```text
Project Owner
```

Suggested:

```text
Branch: feat/s06-be-003-homework-authoring-api
Commit: feat(stage6): add teacher homework authoring api
PR base: main
```

Codex must not commit, push, open/merge PR, modify this task, or update bookkeeping.

Task acceptance occurs only after approved delivery is on `origin/main`, local `main == origin/main`, ahead/behind `0/0`, and worktree clean.

## 29.1 Accepted Delivery Evidence

- Delivered through PR #147; merge `503f5702b7db536610b2772f2940f32028f8f4af`.
- Independent final review: `PASS — P1=0, P2=0, P3=0`.
- Focused verification: 75 tests passed with 1,785 assertions; Pint PASS; `git diff --check` PASS.
- Delivery scope: exactly 38 backend files.
- Acceptance preflight: local `main == origin/main`, ahead/behind `0/0`, worktree clean.

---

# 30. Planning Provenance

For ChatGPT/reviewer traceability only. Codex must not open these sources to rediscover requirements.

| Source/reference | Decision encoded above |
|---|---|
| Approved Stage 6 decomposition | BE-003 owns Teacher Homework list/create/detail/update + recipient discovery |
| Stage 6 assignment rules | Group/selected behavior; selected practice-only; fixed three attempts |
| Stage 6 deadline rules | Institution timezone input/display; server UTC authority |
| Editing integrity | fairness-relevant fields lock after any Student activity |
| Current Teacher Topic implementation | privacy-safe Topic scope and current Teacher membership |
| Current Teacher Group implementation | active currently assigned Groups only |
| Current `InstitutionLessonAt` | strict explicit-offset/IANA validation reused through shared parser |
| S06-BE-001 | Assessment/Homework/recipient/Attempt persistence |
| S06-BE-002 | typed Question persistence/validation/limits |
| Planning baseline | `origin/main @ d1678b42009287a56c0b31a053e54109406feb8b` |

---

# 31. Codex Final Report

Return:

```text
IMPLEMENTATION COMPLETE
BLOCKED
```

Report:

1. Status.
2. Implementation result.
3. Changed files → purpose.
4. Acceptance criteria evidence.
5. Focused verification commands/results.
6. Authorization/tenant evidence.
7. Recipient/editing-integrity evidence.
8. Timezone/no-op/concurrency evidence.
9. Scope/diff and `git diff --check`.
10. Project Owner delivery handoff + Git state.
11. Deviations/blockers.

Do not output task `Accepted` and do not paste large successful logs.

If a required product/API/database/security/tenant/lifecycle/validation/concurrency decision is missing or conflicts with delivered dependencies/current source, return `BLOCKED` rather than deciding independently.
