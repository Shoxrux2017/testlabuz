# TestLabUz — Architecture

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-08-08.

This document defines the technical architecture for the **TestLabUz MVP**.

It is based on:

- `01-business-overview.md`
- `02-user-roles.md`
- `03-features.md`
- `04-user-flows.md`
- `05-business-rules.md`
- `06-roadmap.md`
- `chatgpt-codex-project-building-system.md`

The approved project workflow uses a **Laravel backend + Flutter frontend** project model. This architecture adopts that model as the implementation baseline.

All ten MVP business decisions that previously blocked the decision-dependent architecture are now approved in `05-business-rules.md` and synchronized in `06-roadmap.md`. This document therefore defines their architectural behavior explicitly rather than leaving them behind decision gates.

`08-database.md` and `09-api-contracts.md` are synchronized with this architecture, and the final cross-document consistency audit has passed. Any later behavioral change must update the affected business, architecture, database, API, roadmap, and test contracts before implementation continues.

---

# 1. Architecture Goals

The TestLabUz architecture must support the following product goals.

## 1.1 Multi-Institution From the Beginning

The system must support many educational institutions inside one platform.

Each institution must have its own:

- Institution Admins
- Teachers
- Students
- Parents
- Groups/classes
- Topics
- Learning materials
- Homework assignments
- Blitz tasks
- Attempts
- Submissions
- Scores
- Results
- Settings
- Reports

Institution data must remain isolated.

---

## 1.2 Topic-Centered Learning

The topic is the central learning context.

The architecture must preserve the relationship:

```text
Institution
  ↓
Group
  ↓
Topic
  ├── Learning Materials
  ├── Homework Tasks (1..n)
  │    └── Exactly one designated result-bearing Homework
  │         ├── Questions
  │         ├── Up to 3 normal Student attempts
  │         └── Official highest valid completed score
  ├── Blitz Tasks (1..n)
  │    └── Exactly one designated result-bearing Blitz
  │         ├── Questions
  │         ├── 1 normal attempt
  │         ├── Optional 1 approved exception attempt
  │         └── Official Blitz score
  └── Topic Result
       ├── Official Homework Score
       ├── Official Blitz Score
       ├── Score Difference
       ├── Final Score
       ├── Consistency
       └── Understanding Category
```

---

## 1.3 Strong Authorization

Authorization must be enforced on the backend.

The client may hide unavailable actions for usability, but UI visibility must never be treated as the security boundary.

Every protected operation must validate all applicable scope rules.

---

## 1.4 Deterministic Result Calculation

The homework–blitz comparison must be implemented as deterministic domain logic.

The result engine must:

- Use only the Topic's designated official Homework and Blitz pair.
- Resolve Homework from the highest valid completed score among the fixed 3 normal Homework attempts.
- Resolve Blitz from the valid normal attempt or the approved replacement exception attempt.
- Normalize both official scores to the same 0–100 scale.
- Keep calculation values unrounded beyond the stored Stage 9 score precision (§16.6).
- Calculate the absolute difference.
- Use the institution's current threshold while the result is open (`S10-D6`).
- Apply the approved average-or-blitz formula.
- Derive integer `category_score` from the exact final score and assign the understanding category from that value.
- Compute an open result live on every read (`S10-T1`); save the calculation method and the rules used only in the closure snapshot (§17.6).
- Keep calculation separate from Student/Parent result visibility.

The final result must not depend on UI-side calculations.

---

## 1.5 Historical Stability

The system must preserve educational history.

Architecture should prefer:

- Active / inactive
- Draft / active / closed / archived
- Immutable submitted attempts
- Read-only closed results

over destructive deletion of records that already participate in historical learning data.

---

## 1.6 Vertical Development

Architecture must support the roadmap strategy:

```text
Backend
+ Desktop/Mobile UI
+ Integration
+ Permissions
+ Tests
= One completed vertical stage
```

The architecture should make it easy for Codex to work on one small capability without needing the full codebase context.

---

# 2. Architecture Baseline

The TestLabUz MVP should use the following baseline.

## 2.1 Backend

**Laravel REST API**

Responsibilities:

- Authentication
- Authorization
- Institution scoping
- Business-rule enforcement
- Validation
- Persistence
- File access
- Assignment checking
- Official Homework/Blitz score resolution
- Blitz timing and timeout enforcement
- Student-specific Blitz attempt exception enforcement
- Final result calculation
- Reports/query aggregation

The backend is the authoritative source for business state.

---

## 2.2 Frontend

**Flutter**

One Flutter project should provide shared application/domain/network infrastructure while supporting role-specific desktop and mobile presentation.

Approved product access:

- Platform Owner / Super Admin → desktop
- Institution Admin → desktop
- Teacher → desktop + mobile
- Student → desktop + mobile
- Parent → mobile

The client must not implement a second independent copy of business rules that can disagree with the backend.

---

## 2.3 API Style

Use a versioned JSON REST API.

Recommended base structure:

```text
/api/v1/...
```

Exact endpoints, request bodies, response envelopes, pagination format, and error payloads belong in:

```text
09-api-contracts.md
```

---

## 2.4 Database

Use a relational database.

**Recommended baseline:** PostgreSQL.

The exact table design, column types, indexes, foreign keys, and constraints belong in:

```text
08-database.md
```

Architecture requirement:

> Institution-owned records must carry or inherit a reliable institution ownership path and must be queryable without crossing institution boundaries.

---

## 2.5 File Storage

Use Laravel's filesystem abstraction.

MVP file categories:

1. Teacher learning materials
2. Student file-based submissions

Required formats:

- PDF
- DOCX
- PPT
- PPTX

Architecture rules:

- Files must be private by default.
- File access must pass authorization.
- Public predictable file URLs must not bypass permissions.
- Storage provider must be replaceable without changing domain rules.
- Development and production may use different storage drivers.

Approved platform hard limits are:

- Teacher learning material: **25 MB per file**
- Student file-based submission: **15 MB per file**

An Institution Admin may configure lower institution limits, but never values above the platform maximums. Flutter may pre-check files for usability, but Laravel remains authoritative.

---

## 2.6 Local Development

Use Docker for backend infrastructure where appropriate while keeping the source code in the project directory on the host machine.

The real Laravel source must not exist only inside a disposable container.

Example logical structure:

```text
testlabuz/
  backend/
  frontend/
  docker/
```

Docker mounts the host backend source into the application container.

---

# 3. High-Level System Context

```text
┌─────────────────────────────────────────────┐
│                 Flutter Client              │
│                                             │
│ Desktop roles:                              │
│ - Super Admin                               │
│ - Institution Admin                         │
│ - Teacher                                   │
│ - Student                                   │
│                                             │
│ Mobile roles:                               │
│ - Teacher                                   │
│ - Student                                   │
│ - Parent                                    │
└──────────────────────┬──────────────────────┘
                       │ HTTPS / JSON API
                       ▼
┌─────────────────────────────────────────────┐
│                  Laravel API                │
│                                             │
│ Authentication                             │
│ Institution Context                        │
│ Authorization Policies                     │
│ Domain Actions / Services                   │
│ Result Engine                               │
│ Report Queries                              │
│ File Authorization                          │
└──────────────┬──────────────────────┬───────┘
               │                      │
               ▼                      ▼
┌───────────────────────┐   ┌───────────────────────┐
│ Relational Database   │   │ Private File Storage  │
│                       │   │                       │
│ Institutions          │   │ Learning materials    │
│ Users / Roles         │   │ Student submissions   │
│ Groups                │   │                       │
│ Topics                │   └───────────────────────┘
│ Tasks                 │
│ Attempts              │
│ Submissions           │
│ Scores                │
│ Results               │
│ Settings              │
└───────────────────────┘
```

---

# 4. Architectural Style

## 4.1 Backend Style

Use a **modular monolith** for the MVP.

Do not start with microservices.

Reasons:

- The core learning workflow is highly connected.
- Transactions span tasks, submissions, scores, and results.
- MVP deployment should remain simple.
- The product is still validating real institutional usage.
- One codebase is easier to test and review stage by stage.

The modular monolith must still preserve clear domain boundaries.

---

## 4.2 Backend Layer Responsibilities

Recommended responsibility split:

```text
HTTP Layer
  ↓
Application / Action Layer
  ↓
Domain Rules / Services
  ↓
Persistence / Infrastructure
```

### HTTP Layer

Responsible for:

- Authentication entry
- Request parsing
- Request validation
- Calling one application action/use case
- Returning API resources
- Mapping expected errors to API responses

Must not contain complex business logic.

### Application / Action Layer

Responsible for use cases such as:

- CreateInstitution
- DeactivateInstitution
- CreateTeacher
- AssignTeacherToGroup
- CreateTopic
- ActivateHomework
- StartHomeworkAttempt
- SubmitHomeworkAttempt
- FinalizeHomeworkAttemptsAtDeadline
- ActivateBlitz
- StartBlitzAttempt
- SubmitBlitzAttempt
- FinalizeTimedOutBlitzAttempt
- FinalizeAttemptsOnTaskClose
- GrantBlitzAttemptException
- ReviewTeacherSubmission
- RepairOfficialTaskScores
- UpdateTopicResultComment
- ReleaseStudentTopicResult (single Student and bulk)
- ReleaseParentTopicResult (single Student and bulk)
- CloseTopicResult (single Student, bulk, and on Topic archive)

Each action should have one clear business purpose.

There is no calculate or recalculate action and no job for Topic results: an open Topic result is computed live by the `TopicResultEngine` on every read (`S10-T1`, §17.1).

Stage 8 Blitz execution/finalization actions do not invoke Stage 9 checking strategies, Teacher review, points, Attempt scoring, or official-score selection. This stays true in Stage 9: the freeze itself does no checking, and Stage 9 checks each frozen Attempt right after the freezing transaction commits (§16.5). Stage 10 owns Homework–Blitz comparison, live Topic results, categories, the Teacher comment, release, closure, the `409 result_closed` guards, and the Homework-before-Blitz work order (`S10-D8`), which adds an official Homework close to `ActivateBlitz` (§15.1) and a submitted-Homework condition to `StartBlitzAttempt` (§14.4). Shared `AssessmentAttempt` persistence does not merge Homework and Blitz lifecycle policies.

### Domain Layer

Responsible for reusable rules such as:

- Institution scope validation
- Task lifecycle transitions
- Fixed Homework/Blitz attempt availability
- Homework execution/finalization separately from later Homework checking/scoring
- Homework deadline/close finalization and answer/file write-versus-freeze serialization
- Student-specific Blitz attempt exceptions
- Blitz activation eligibility, immutable timer-mode snapshot, and deadline resolution
- Blitz timeout/Teacher-close finalization, terminal immutability, and answer/file write-versus-freeze serialization
- Blitz exception eligibility and exclusion of the invalidated Attempt from later official scoring
- Question checking and approved partial credit
- Score normalization
- Official Homework/Blitz score resolution
- Live Topic result computation: side states, result status, Homework–blitz comparison (§17)
- Category-score derivation and understanding-category resolution
- Result closure, the closure snapshot, and the `409 result_closed` guards (§17.8)
- Student/Parent visibility window and release policy (§18.6, §19)
- Homework-before-Blitz work order at official Blitz activation and Start (`S10-D8`)

### Persistence / Infrastructure

Responsible for:

- Eloquent models
- Database queries
- Transactions
- File storage
- Time provider
- External infrastructure adapters if added later

---

## 4.3 Flutter Style

Use a **feature-first layered architecture**.

Recommended logical layers per feature:

```text
presentation/
domain/
data/
```

### Presentation

Responsible for:

- Screens
- Widgets
- Forms
- View state
- User actions
- Loading/error/success display
- Role/device-appropriate presentation

### Domain

Responsible for client-side application models and use-case contracts needed by UI.

It may contain presentation-safe derived logic.

It must not redefine authoritative server business rules such as final result calculation.

### Data

Responsible for:

- DTOs
- API calls
- Serialization
- Repository implementations
- Remote failure mapping

---

# 5. Recommended Project Structure

```text
testlabuz/
  AGENTS.md

  docs/
    01-business-overview.md
    02-user-roles.md
    03-features.md
    04-user-flows.md
    05-business-rules.md
    06-roadmap.md
    07-architecture.md
    08-database.md
    09-api-contracts.md

  tasks/
    backend/
      stage-01/
      stage-02/
      ...
    frontend/
      stage-01/
      stage-02/
      ...
    integration/
      stage-01/
      stage-02/
      ...

  backend/
    AGENTS.md
    app/
    bootstrap/
    config/
    database/
    routes/
    storage/
    tests/
    composer.json

  frontend/
    AGENTS.md
    lib/
    test/
    pubspec.yaml

  docker/
    docker-compose.yml
```

---

# 6. Laravel Backend Structure

A recommended backend structure is:

```text
backend/
  app/
    Actions/
      Auth/
      Institutions/
      Users/
      Groups/
      Topics/
      Materials/
      Homework/
      Blitz/
      Submissions/
      Results/

    Domain/
      Auth/
      Institutions/
      Groups/
      Learning/
      Assessment/
      Results/
      Reports/

    Enums/
    Exceptions/
    Http/
      Controllers/
        Api/
          V1/
      Middleware/
      Requests/
      Resources/

    Models/

    Policies/

    Services/
      Authorization/
      Files/
      Scoring/
      Time/

    Support/

  database/
    factories/
    migrations/
    seeders/

  routes/
    api.php

  tests/
    Feature/
    Unit/
```

This is a logical guide, not a requirement to create empty folders before they are needed.

---

# 7. Backend Coding Rules

## 7.1 Controllers Stay Thin

Controllers should:

1. Receive validated request data.
2. Resolve authenticated context.
3. Call an Action/use case.
4. Return a Resource/response.

Controllers should not directly implement:

- Tenant filtering logic
- Attempt rules
- Score formulas
- Category formulas
- Complex state transitions
- File permission logic

---

## 7.2 Use Form Requests for Input Validation

Use request validation for:

- Required fields
- Data type
- Format
- Simple ranges
- Allowed file type/size
- Basic enum validity

Business rules that depend on persisted state belong in application/domain services.

Example:

```text
Request validation:
duration_seconds must be a positive integer.

Business rule:
Only an authorized Teacher may set the duration for a Blitz in the Teacher's allowed topic/group scope, while the institution timer-start mode remains authoritative.
```

---

## 7.3 Use Policies / Authorization Services

Authorization should combine:

- Role
- Institution
- Group relationship
- Record ownership
- Student ownership
- Parent-child relationship
- Lifecycle status
- Requested action

Do not scatter these checks as unrelated `if` statements throughout controllers.

---

## 7.4 Use Transactions for Multi-Record Business Operations

Database transactions should be used when one business action writes multiple related records.

Examples:

- Create task + questions + options
- Save/replace a Homework answer or file reference under the Attempt editability lock
- Finalize a Homework Attempt from already-committed Student work + lifecycle metadata
- Protected Homework Start/Submit + durable idempotency claim/result
- Automatic checking of one frozen Attempt + Attempt score + official-score resolution (one transaction per Attempt, never the freezing transaction; §16.5)
- Manual review + score update + task score
- Official Blitz activation + close of the active official Homework with its Attempt freezes (`S10-D8`, §15.1)
- Result closure: lock the Student's official Attempts, compute the result live, write the closure snapshot (§17.8)
- Bulk close or bulk release of every eligible result of a Topic (§17.9)
- Topic archive + automatic closure of every terminal Topic result (§17.8)

An official-score change writes no Topic result: an open result is computed live (`S10-T1`).

A partial write must not leave invalid educational state.

---

## 7.5 Domain Exceptions

Expected business-rule failures should use explicit domain/application exceptions.

Examples:

- InstitutionInactive
- UserInactive
- CrossInstitutionAccessDenied
- GroupNotAssigned
- TaskNotAssigned
- TaskNotActive
- AttemptsExhausted
- HomeworkDeadlinePassed
- BlitzNotActive
- BlitzTimeExpired
- BlitzAttemptExceptionAlreadyGranted
- BlitzAttemptExceptionNotAllowed
- ResultBearingTaskLocked
- SubmissionLocked
- AutomaticCheckingPending
- ResultAlreadyClosed (`409 result_closed`)
- ResultNotReady / ResultNotReadyForClosure
- StudentResultNotReleased
- ManualReleaseNotAllowed
- OfficialHomeworkNotActivated
- HomeworkNotSubmitted

`09-api-contracts.md` will map these to stable API responses.

---

# 8. Multi-Institution Architecture

## 8.1 Recommended Tenancy Model

Use a **shared application + shared database schema + institution-owned rows** model for the MVP.

Every institution-level record must either:

- Store `institution_id` directly, or
- Have an unambiguous parent relationship that resolves to exactly one institution.

For high-risk records such as users, groups, topics, tasks, attempts, submissions, files, idempotency records, and results, direct institution ownership is preferred where it improves safe querying and constraints.

Exact redundancy choices belong in `08-database.md`.

---

## 8.2 Institution Context

For each authenticated institution user request, the backend must resolve a trusted institution context from the authenticated account.

The client must not be allowed to choose an arbitrary institution by sending:

```text
institution_id = some_other_institution
```

and thereby expand access.

---

## 8.3 Platform-Level Super Admin

Super Admin is platform-scoped.

Super Admin operations must use explicit platform actions. Institution activate/deactivate commands are idempotent: requesting the already-current target state returns the current resource successfully and does not produce a duplicate lifecycle mutation or `already_active`/`already_inactive` conflict.

Avoid making ordinary institution queries automatically unscoped merely because the current user is Super Admin.

The architecture should separate:

```text
Platform administration
```

from:

```text
Institution learning operations
```

This reduces accidental access to daily educational data.

---

## 8.4 Query Scoping

Every institution-level query must be scoped.

Unsafe pattern:

```text
Find Topic by id
then trust it
```

Required conceptual pattern:

```text
Resolve authenticated scope
Find Topic inside allowed institution
Check role/relationship
Check requested action
Return or mutate
```

Direct record IDs must never bypass scoping.

Student Homework/Attempt/Answer/File access starts from the authenticated Institution and Student, then resolves the frozen `assessment_students` recipient, owned Attempt, Assessment, and Question relationships inside that scope. Current Group membership must not replace persisted assignment history. Idempotency lookup is likewise tenant-first and user-first:

```text
institution_id + user_id + operation + idempotency_key
```

The backend must never find a globally matching key first and authorize afterward.

---

## 8.5 Cross-Institution Relationship Validation

On writes, validate that related records share the same institution.

Examples:

```text
Teacher.institution_id == Group.institution_id
Student.institution_id == Group.institution_id
Parent.institution_id == Student.institution_id
Topic.institution_id == Group.institution_id
Homework.institution_id == Topic.institution_id
Blitz.institution_id == Topic.institution_id
Submission.institution_id == Task.institution_id
Result.institution_id == Student.institution_id
```

Database foreign keys and application validation should reinforce each other.

---

# 9. Identity and Authorization Architecture

## 9.1 MVP Roles

Use the five approved primary roles:

```text
platform_owner
institution_admin
teacher
student
parent
```

Exact persisted enum/string values will be finalized in `08-database.md`.

---

## 9.2 One Primary Role Per MVP Account

The MVP should not implement custom user-created roles.

Each account has one primary role.

Permissions are derived from:

```text
Role
+ Institution
+ Relationships
+ Record scope
+ Lifecycle state
```

---

## 9.3 Authentication

Use API authentication suitable for Flutter clients.

Recommended Laravel baseline:

- Laravel Sanctum token-based API authentication

The exact token/session contract must be defined in `09-api-contracts.md`.

Authentication must provide:

- Login
- Logout
- Current user identity
- Role
- Institution context where applicable
- Active/inactive status handling
- Mandatory first-login password-change state for administrator-created accounts

Administrator-created Institution Admin, Teacher, Student, and Parent accounts are created with an initial password and `must_change_password = true`. After login, a backend guard must block normal application actions while that flag remains true. Only the minimum onboarding endpoints needed for `auth/me`, authenticated password change, and logout remain available. A successful password change verifies the current initial password, persists the new hash, and atomically clears the flag. Flutter mirrors this state in routing but is not the security authority.

---

## 9.4 Authorization Layers

Use multiple defensive layers:

### Layer 1 — Authentication

Is there a valid authenticated user?

### Layer 2 — Account / Institution Status

Is the user active?

For institution users, is the institution active?

If `must_change_password = true`, is this request one of the explicitly allowed onboarding/authentication operations?

### Layer 3 — Role Capability

May this role perform this kind of action?

### Layer 4 — Institution Ownership

Does the requested record belong to the user's institution?

### Layer 5 — Relationship Scope

Examples:

- Teacher assigned to Group
- Student assigned to Task
- Parent connected to Student

### Layer 6 — Lifecycle / Business Condition

Examples:

- Task is active
- Attempts remain
- Deadline not passed
- Blitz is active
- Result is not closed

All applicable checks must pass.

---

# 10. Group and Relationship Architecture

Core relationship concepts:

```text
Institution
  ├── Users
  └── Groups
       ├── Teachers
       └── Students

Parent
  ↔
Student
```

Recommended relationship storage:

- Teacher ↔ Group: explicit join relationship
- Student ↔ Group: explicit join relationship
- Parent ↔ Student: explicit join relationship

Do not infer Parent access from matching surname, phone, or other profile data.

Do not infer Teacher access only from subject name.

Authorization must use explicit stored relationships.

---

# 11. Topic and Learning Content Architecture

## 11.1 Topic Aggregate Boundary

Topic is the high-level learning context, but individual tasks and submissions should remain independently queryable entities.

Topic owns/coordinates:

- Metadata
- Group context
- Learning materials
- Multiple Homework tasks
- Multiple Blitz tasks
- Exactly one designated result-bearing Homework relationship
- Exactly one designated result-bearing Blitz relationship
- Topic result context

`topic_result_pairs` is the Topic-level identity of the eventual official Homework–Blitz pair. The aggregate may be persisted in a staged state with the official Homework present and the Blitz reference absent. This allows Stage 6 Homework authoring to establish official Homework/cohort identity without creating a fake Blitz. Stage 8 completes that same row when it exists; a valid official Homework is required, but a pre-existing pair row is not. The canonical result-pair PUT may atomically create one row with required eligible Homework and optional eligible Blitz. It creates no recipient or Attempt merely by designation and introduces no duplicate official flags or pair rows.

Official Blitz designation requires the same Institution/Topic and authorized Teacher scope, whole-group assignment, `draft` or `scheduled` lifecycle, and no Student Attempt. Active/closed/archived or selected-Student practice Blitz cannot be newly designated. PUT omission of `blitz_assessment_id` preserves the persisted Blitz; a supplied value must be a non-null UUID, with no null-clear operation. Before lock an eligible pre-activation Blitz may replace the Blitz side. A locked populated side permits only exact same-target replay. Blitz-only attach/replacement preserves Homework, designation actor/time, cohort, lock and creation history, changing only Blitz identity and `updated_at`; an exact semantic replay performs zero writes. Only a separately permitted Homework replacement owns changes to Homework designation metadata.

Both eventual official tasks must use `assignment_mode = group`; selected-Student assessments are practice-only and are ineligible for official designation. The first activated official whole-group task establishes the common persisted cohort. If an already-active eligible whole-group Homework is designated before any Student Attempt, its existing recipient snapshot becomes that cohort. A later official task must reuse that exact cohort, and a conflicting recipient snapshot is rejected rather than silently rewritten. Later Group membership changes do not mutate the cohort.

The pair lock prevents replacement of already meaningful official work/cohort. It does not prohibit the one-time completion of an absent Blitz side that satisfies the locked Topic/cohort contract. Completion must not clear the lock, replace the official Homework, or change the locked cohort.

Creating the first Attempt for the Homework referenced by `topic_result_pairs.homework_assessment_id` locks that official meaning in the same transaction. The backend resolves and locks the pair in the same Institution/Topic, requires `cohort_snapshotted_at` and the Student's membership in the persisted official Homework recipient cohort, and uses one captured `startedAt` for both the new Attempt and a previously-null pair `locked_at`/`updated_at`. An existing non-null `locked_at` is preserved. The transaction may leave `blitz_assessment_id = null`, must never replace official Homework/cohort identity or create a Blitz, and fails atomically on structural pair/cohort inconsistency rather than repairing or resnapshotting it. Practice Homework attempts do not mutate `topic_result_pairs`.

Before Stage 10 the official Blitz could activate first; since `S10-D8` (§15.1) a draft official Homework blocks the official Blitz activation, so the official Homework establishes the cohort. For that history: if official Blitz activates first, its valid persisted whole-group recipient snapshot establishes the cohort, with `cohort_snapshotted_at` equal to its authoritative activation instant; preserve the Homework ID and create no Homework Attempts. Later official Homework activation reuses that cohort. The first official Blitz Attempt similarly resolves/locks the matching pair, requires its persisted cohort and Student membership, and sets only a null pair `locked_at` to the new Attempt's `startedAt`; an existing lock is preserved. Practice Blitz Start does not mutate the pair. Current account/security checks remain mandatory even for persisted cohort members.

Avoid storing the whole topic workflow in one large serialized JSON field.

---

## 11.2 Topic Lifecycle

Use a dedicated TopicStatus enum/domain concept:

```text
draft
active
closed
archived
```

Transitions should be controlled by actions/services.

Example:

```text
CreateTopic
ActivateTopic
CloseTopic
ArchiveTopic
```

Avoid arbitrary status assignment from the client.

Since Stage 10, `ArchiveTopic` also closes every terminal Topic result of the cohort inside its transaction (`S10-D7`, §17.8); its request, response and conflicts are unchanged. `CloseTopic` closes no result.

---

## 11.3 Learning Material Model

Learning material metadata lives in the database.

File bytes live in private file storage.

The database record should retain enough metadata to authorize and display the file.

Examples of metadata to define later:

- Institution
- Topic
- Owning Teacher
- Original filename
- Stored path/key
- MIME type
- File size
- Created/updated time

Exact schema belongs in `08-database.md`.

---

# 12. Assessment Architecture

Homework and blitz share many question/answer concepts.

The architecture should reuse common assessment components while keeping homework and blitz lifecycle behavior distinct.

Conceptual model:

```text
Assessment Task
  ├── Common metadata
  ├── Questions
  ├── Points
  └── Assignment scope

Homework
  ├── Deadline
  ├── Exactly 3 normal Student attempts
  └── Homework lifecycle rules

Blitz
  ├── Activation
  ├── Whole-task duration
  ├── Institution timer-start mode
  ├── 1 normal Student attempt
  ├── Optional 1 Student-specific approved exception attempt
  └── Classroom lifecycle rules
```

Implementation may use shared services/components without forcing homework and blitz into one indistinguishable database object.

`08-database.md` will decide the table inheritance/composition strategy.

---

# 13. Question Type Architecture

The nine supported types must have explicit typed structures.

Do not store all question behavior in one uncontrolled free-form blob.

Supported types:

```text
single_choice
multiple_choice
true_false
short_written
open_written
file_based
matching
ordering
fill_in_blank
```

Each question type should provide a defined contract for:

- Authoring fields
- Student-answer structure
- Automatic/manual checking mode
- Point calculation
- Validation

---

## 13.1 Auto-Check Strategy

Use a question-checking strategy/service architecture.

Conceptual interface:

```text
QuestionChecker
  check(question, studentAnswer) -> CheckResult
```

Implementations:

```text
SingleChoiceChecker
MultipleChoiceChecker
TrueFalseChecker
ShortWrittenChecker
MatchingChecker
OrderingChecker
FillInBlankChecker
```

Open written, file-based, and `short_written` Questions with `checking_mode = manual` are routed to Teacher review rather than automatic judgment in the MVP. Only `short_written` can be switched to manual checking; every other automatic type is always checked automatically.

For Homework, Stage 7 only persists and freezes Student work with answer checking fields still pending. These checking strategies, awarded points, Teacher review, Attempt scores, and official Homework score resolution are Stage 9 responsibilities.

Stage 9 checks every Question of a frozen Attempt:

- **Unanswered Question** (no `attempt_answers` row): contributes 0. No row is fabricated and no review is required, including for manual Questions. An empty answer cannot exist, because clearing an answer deletes its row.
- **Automatic answer:** the checker stores `awarded_points` and `checking_status = auto_checked`.
- **Manual answer with points > 0:** `checking_status = waiting_for_teacher_review` until Teacher review (§16.9).
- **Zero-point Question:** an automatic answer is checked with 0 points; a manual answer is closed automatically as `auto_checked` with 0 points and never enters the review queue.
- Every automatic result sets `checked_at` to the checking time and leaves `checked_by_user_id` null.

Practice (non-official) tasks and an invalidated Blitz Attempt #1 are checked and reviewed the same way; neither ever produces an official score (§16.8).

---

## 13.2 Approved Partial-Credit Policy

Partial-credit behavior is fixed for the MVP and must be implemented through explicit question-checking strategies rather than UI calculations.

Use a domain policy/service boundary such as:

```text
PartialCreditPolicy
```

Approved behavior:

### Single-choice

- All-or-nothing.
- Correct selected option receives full question points.
- Any other answer receives zero.

### True / false

- All-or-nothing.
- Correct Boolean answer receives full question points.
- Incorrect answer receives zero.

### Multiple-choice

The backend derives:

```text
max_selections = count(correct_options)
```

Student clients may receive `max_selections` but must never receive which options are correct. The Student may select fewer options or none, but never more than the cap. Laravel validates the cap authoritatively even if Flutter is modified.

Scoring uses only correctly selected answers:

```text
fraction = correctly_selected_options / total_correct_options
question_points_awarded = question_max_points * fraction
```

An empty selection earns zero. Incorrect selections earn no credit and create no additional negative penalty; because the total number of selections is capped, selecting a wrong option consumes one available selection opportunity.

### Matching

Award partial credit per correctly matched pair. A pair is correct when the chosen right item has the left item's `match_key`:

```text
fraction = correct_pairs / total_left_items
question_points_awarded = question_max_points * fraction
```

### Ordering

Award partial credit per item placed in its correct position. An item counts only at its exact `correct_position`; both sides are 1-based:

```text
fraction = correctly_positioned_items / total_items
question_points_awarded = question_max_points * fraction
```

### Fill-in-the-blank

Award partial credit per correctly completed blank. A blank is correct when its normalized value equals any normalized accepted answer of that blank, using the same normalization as short written answers (`S09-D9`):

```text
fraction = correct_blanks / total_blanks
question_points_awarded = question_max_points * fraction
```

### Short written answer

- With `checking_mode = automatic`, checking is all-or-nothing: full points when the normalized answer equals any normalized accepted answer; otherwise 0.
- Automatic mode uses deterministic normalized exact matching (`BR-Q-013A`). Both Student text and accepted answers pass the same pipeline, in this order: Unicode NFC → Unicode full case folding (locale-independent) → NFC again → map the apostrophe variants U+0027 `'`, U+0060 `` ` ``, U+00B4 `´`, U+02BB `ʻ`, U+02BC `ʼ`, U+2018 `‘`, U+2019 `’` to U+0027 → replace every run of the Student-answer whitespace set (U+0009–U+000D, U+0020, U+0085, U+00A0, U+1680, U+2000–U+200A, U+2028, U+2029, U+202F, U+205F, U+3000, U+FEFF) with one U+0020 → trim. The results are then compared exactly. Punctuation and other symbols remain significant.
- Fuzzy matching, spell correction, synonym inference, and AI interpretation are not part of the MVP.
- With `checking_mode = manual`, the answer is routed to Teacher review.

Every partial-credit formula above is evaluated in one step as `points × correct / total` with exact decimal arithmetic and stored as described in §16.6; `fraction` is not rounded separately.

### Open written and file-based

- Manual Teacher scoring within the configured maximum points.

The backend is authoritative for all awarded points.

---

# 14. Attempt and Submission Architecture

## 14.1 Attempt Is a First-Class Record

Every Student try must be its own immutable historical attempt after finalization/submission.

Homework execution history and the Homework checking engine are separate boundaries. Stage 7 creates/resumes Attempts, persists typed/file answers, and freezes the already-committed Student work as `submitted`; Stage 9 later checks that frozen history, applies the approved missing-answer-as-zero policy without fabricating answer rows, performs required Teacher review, and computes/selects scores.

Stage 8 likewise produces immutable Blitz execution history as `submitted` or `timed_out_finalized`. Its saved answers remain `checking_status = pending`, with `awarded_points`, `feedback`, `checked_by_user_id`, and `checked_at` null. Stage 8 creates no missing answer rows and does not populate Attempt scores or official scores. Stage 9 owns the later objective checking, manual-review transition, missing-answer/component zero interpretation, scoring and official Blitz score selection.

After Stage 9 checking, answers of a terminal Attempt may be `auto_checked`, `waiting_for_teacher_review` or `teacher_checked`. Student reads and Submit replays of terminal Homework Attempts therefore use the historical answer canonicalization, as Blitz already does, rather than requiring `pending` answers. Replay of a completed Homework or Blitz Submit returns the Attempt in its current status, which may be `waiting_for_teacher_review` or `checked`; all finalization fields are unchanged.

Conceptual structure:

```text
Student
  ↓
Task
  ↓
Attempt #1
  ├── Answers
  ├── Score / review state
  └── Scoring eligibility

Attempt #2
  ├── Answers
  ├── Score / review state
  └── Scoring eligibility
```

A new attempt must never overwrite an earlier submitted or timed-out attempt.

---

## 14.2 Attempt Service

Centralize attempt rules in an `AttemptService` plus task-specific policies.

Responsibilities:

- Check Student/task assignment.
- Check active user and institution.
- Check task lifecycle.
- Check Homework deadline or Blitz timing.
- Enforce the approved fixed attempt limits.
- Resume the one current `in_progress` Homework Attempt rather than spending another attempt.
- Calculate next attempt number.
- Start attempt.
- Lock/finalize attempt.
- Determine whether another attempt is permitted.
- Preserve attempt history.
- Expose scoring eligibility only to the later owning checking/scoring workflow; for Homework this is Stage 9, never Stage 7.

The service must not accept a client-provided arbitrary attempt limit.

---

## 14.3 Homework Attempt Policy

Homework has exactly **3 normal attempts per Student**.

Use a dedicated policy/resolver boundary such as:

```text
HomeworkAttemptPolicy
OfficialTaskScoreResolver + OfficialScoreEvaluator
```

Rules:

- Normal attempt numbers are 1, 2, and 3.
- A fourth normal Homework attempt is not permitted.
- At most one Attempt may be `in_progress` for one Student/Homework; application locking and a PostgreSQL partial unique index enforce this invariant together.
- Start returns the existing `in_progress` Attempt without consuming capacity, or atomically allocates `max(attempt_number) + 1` when no current Attempt exists and capacity/lifecycle/deadline rules pass.
- Each attempt is stored independently.
- A Stage 7 finalized Attempt is stored as `submitted` and is immutable to the Student.
- Stage 9 chooses the official Homework score as the **highest valid completed score** among eligible Homework attempts and waits only for an Attempt that could still overtake it (`S09-D2`). `OfficialTaskScoreResolver` (through `OfficialScoreEvaluator`) applies this rule to the Student's Attempts of this Homework with `official_score_eligible = true`; `in_progress` Attempts are not considered:
  1. `best` is the `checked` eligible Attempt with the highest stored `normalized_score`; ties go to the lowest `attempt_number`. With no `checked` Attempt the official score is not ready.
  2. Every eligible terminal Attempt that is not `checked` is **pending**. Its upper bound is `(awarded points of its checked answers + full points of its waiting answers) × 100 / possible_points`, rounded as in §16.6; an Attempt not yet automatically checked has upper bound 100.
  3. The official score is not ready while any pending Attempt has an upper bound greater than `best`, or equal to `best` with a lower `attempt_number` than `best`.
  4. Otherwise the official Attempt is `best`, with `selection_policy_code = highest_valid_completed`.
- In Stage 9, an Attempt requiring Teacher review is not fully scored until review is complete: its `earned_points` and `normalized_score` stay null while it waits.
- When a later Attempt becomes pending and could overtake, a ready official score becomes not ready until that Attempt is checked; this is intended. The resolver re-runs on every checking run, review save and correction (§16.8), so a higher checked score or a correction may move the official score to another Attempt. Such a change writes no Topic result: an open Topic result is computed live on its next read (`S10-T1`), and a closed result keeps its closure snapshot (§17.6).
- The Teacher does not manually select the official Homework attempt and does not override the fixed attempt count.

---

## 14.4 Blitz Attempt Policy

Blitz has exactly **1 normal attempt per Student**.

Use a dedicated policy/resolver boundary such as:

```text
BlitzAttemptPolicy
OfficialTaskScoreResolver + OfficialScoreEvaluator
```

Rules:

- The normal Blitz attempt is attempt #1.
- Under normal conditions, no second attempt is available.
- Without an exception, `OfficialTaskScoreResolver` (through `OfficialScoreEvaluator`) makes the official Blitz score ready when Attempt #1 is `checked` (`selection_policy_code = valid_normal_blitz`). The exception case is in §14.5.
- The client cannot request or create an extra attempt by itself.

One Student Start route requires a strict mandatory body with exactly `intent = start_normal`, `intent = resume` plus canonical `attempt_id`, or `intent = start_replacement`. Both Start intents forbid `attempt_id`; missing/empty/malformed bodies, unknown keys/intents and malformed Resume UUIDs return `422 validation_failed`; no query parameters are accepted. The server never reinterprets an intent. Resume targets one exact own Attempt and never creates, switches, or selects a newer Attempt.

Fresh execution requires authenticated active Student, same Institution, persisted `assessment_students` recipient, own Attempt, active Blitz and applicable timer/capacity rules. Tenant scope precedes authorization and resource exposure; a UUID never grants access. Same-Assessment Question/child validation and private-file authorization remain mandatory, and Student resources never expose correct-answer/checking configuration.

Fresh `start_normal` creates unused #1 with `201`, returns the same editable #1 with `200`, reconciles due in-progress #1 then returns `409 blitz_time_expired`, rejects a terminal #1 with `finalization_reason = timeout_auto_submit` without an approved exception with `409 blitz_time_expired`, and rejects any other terminal #1 (or any terminal #1 once an exception is approved) with `409 attempts_exhausted`. Fresh `resume` returns its exact editable target with `200`, reconciles a due in-progress target then returns `409 blitz_time_expired`, rejects a terminal target with `finalization_reason = timeout_auto_submit` with `409 blitz_time_expired` and any other terminal target with `409 attempt_not_editable`, and returns privacy-safe `404 resource_not_found` for a foreign/out-of-scope target. Fresh `start_replacement` creates #2 only with valid unused exception capacity (`201`), returns existing editable #2 (`200`), reconciles due #2 then returns `409 blitz_time_expired`, returns `409 blitz_time_expired` for a terminal #2 with `finalization_reason = timeout_auto_submit`, and returns `409 attempts_exhausted` for any other consumed terminal #2 or structurally valid history without approved capacity. These timeout rules key on `finalization_reason = timeout_auto_submit`, whatever the Attempt's later Stage 9 checking status (`timed_out_finalized`, `waiting_for_teacher_review` or `checked`), so observable responses stay exactly as in Stage 8 (`S09-T2`). An existing invalid exception graph/capacity returns `409 blitz_attempt_exception_not_allowed` under the invariant/public-error split. No return resets `started_at`/`deadline_at`; no intent creates #3, and normal Start never uses replacement capacity. Completed authorized idempotent replay takes precedence as specified in §23.4. Amended 2026-09-28 (`S08-CLOSURE-FIX-001`) to match `docs/09-api-contracts.md` §20.3 (owner decision D3, `S08-BE-PHASE-2-FIX-002`).

Homework before Blitz (`S10-D8`): when a fresh `start_normal` of the official Blitz (the Blitz of the Topic's result pair) would create a new Attempt #1 — after the existing executability checks, and only when the Student has no Attempt #1 — the Student must have at least one terminal (`submitted`, `waiting_for_teacher_review` or `checked`) Attempt of the official Homework; otherwise it returns `409 homework_not_submitted` with no change. A `start_normal` that returns an existing Attempt #1, an idempotent replay, `resume`, `start_replacement` and every practice Blitz are unaffected. A barred Student is Not completed at once when the activation closed the Homework (Homework and Blitz sides `missing`, `missing_component = both`, §17.3); in history from before `S10-D8` with a still-open Homework the result waits for the Homework instead. The Student Blitz read does not announce the bar; the client learns it from the `409`.

---

## 14.5 Student-Specific Blitz Attempt Exception

An authorized Teacher may grant **one additional Blitz attempt** to one specific Student for a valid technical or other approved reason.

Use an explicit application action:

```text
GrantBlitzAttemptException
```

and a domain policy such as:

```text
BlitzAttemptExceptionPolicy
```

Rules:

- Exactly one exception may be granted per Student for that Blitz.
- The Teacher must provide a reason.
- The exception is Student-specific, not task-wide.
- The original interrupted/invalid attempt remains in history.
- The original affected attempt must be marked or linked so it is excluded from official scoring according to the approved exception.
- The additional attempt becomes the only eligible replacement Blitz attempt when validly completed.
- Maximum recorded Blitz attempts for that Student are therefore 2.
- Granting an exception is a protected Teacher action and must be auditable from normal persisted business records.

A new grant requires exactly `BlitzTask.status = active`, same Institution, current authorized Teacher scope, persisted Student recipient, existing normal #1, no prior exception/#2, and a non-empty valid reason for fairness/technical validity rather than score improvement. Draft/scheduled/closed/archived return `409 blitz_attempt_exception_not_allowed`; Teacher Close permanently prevents new grants and cannot be reversed. An elapsed synchronized common end alone does not block a valid grant while active.

Under deterministic locks, a still-editable pre-deadline #1 rejects with `409 blitz_attempt_exception_not_allowed`, with no exception, eligibility change, replacement or synthetic finalization. A due in-progress #1 first uses the shared timeout finalizer at its exact deadline; if all grant preconditions pass, the atomic workflow excludes #1 (`official_score_eligible = false`) and inserts one exception with no replacement yet. An already-terminal #1 preserves its reason/timestamps and all answers/files. No new finalization reason is introduced. Missing #1 returns `409 blitz_normal_attempt_required`; an existing exception returns `409 blitz_attempt_exception_already_granted`.

Granting never creates #2 or allows two simultaneous in-progress Attempts. Only confirmed Student `start_replacement` may create #2. In both timer modes it receives the same full `duration_seconds` from its own canonical server Start; it does not change configured duration, timer snapshot, class activation/common end, or another Student's deadline.

Stage 9 official scoring with an exception (`S09-D4`, `S09-T7`):

- #1 is excluded. The official Blitz score is ready only when replacement #2 exists and is `checked` (`selection_policy_code = approved_blitz_exception_replacement`).
- The grant deletes an existing official Blitz row for that Student inside the grant transaction, under the scoring lock order (§16.7). A timeout performed during the grant is a freezing point, so that #1 is checked after the grant commits (§16.5).
- A Blitz closed before the Student took #2 has no official Blitz score; Stage 10 treats the Student as Not completed (Blitz side `missing`, §17.3), even while #1 still waits for review. A #2 taken before the close becomes official once it is `checked`, even when its review ends after the close. The grant dialog states this consequence to the Teacher.
- The invalidated #1 is checked like any Attempt and may wait for Teacher review, but it is never official and never blocks the official score. The Student-facing status "Invalidated by approved exception" is derived from `official_score_eligible = false`; the stored Attempt status follows normal checking.

Exact database field names/status codes belong in `08-database.md`; the architecture requires preserved history, explicit eligibility/exclusion, actor, reason, and timestamp.

---

## 14.6 Submission Locking and Task-Close Finalization

### Homework execution and freeze

Every Stage 7 Homework finalization path transitions only an `in_progress` Attempt to immutable `submitted` and freezes only previously committed Student work:

```text
explicit Student Submit:
  submitted_at = finalized_at = locked_at = captured server instant
  finalization_reason = student_submit

authoritative Homework deadline:
  submitted_at = null
  finalized_at = locked_at = exact homework_assignments.deadline_at
  finalization_reason = homework_deadline_auto_submit

Teacher close before deadline:
  submitted_at = null
  finalized_at = locked_at = captured close instant
  finalization_reason = task_closed_auto_finalize
```

Since Stage 10, activating the official Blitz closes an active official Homework in the activation transaction exactly like a Teacher close, with `task_closed_auto_finalize` and no recorded actor (`S10-D8`, §15.1).

Teacher close and all still-`in_progress` Attempt transitions commit atomically. At or after the deadline, close first runs the shared deadline reconciliation and preserves the deadline reason/timestamp; it must not rewrite an earlier terminal event. No Attempt or unanswered `attempt_answers` row is fabricated. Saved answers remain pending and Stage 7 writes no awarded points, checking metadata, Attempt score, or official score.

Answer/file mutation and finalization serialize through deterministic relevant Homework/Attempt row locks. Lifecycle, authoritative time, and editability are re-read after locking. If the Student mutation commits first, that committed state is frozen; if finalization commits first, the later mutation makes zero answer/file-domain changes and returns the documented conflict. A rejected file replacement cannot change persisted answer/file identity or content.

### Blitz execution and freeze

Stage 8 finalization transitions only an `in_progress` Blitz Attempt and freezes its exact committed answers/files without checking/scoring:

```text
explicit Student Submit before deadline:
  status = submitted
  submitted_at = finalized_at = locked_at = captured submit instant
  finalization_reason = student_submit

authoritative timeout (server_now >= deadline_at):
  status = timed_out_finalized
  submitted_at = null
  finalized_at = locked_at = exact persisted deadline_at
  finalization_reason = timeout_auto_submit

Teacher close before the Attempt deadline:
  status = submitted
  submitted_at = null
  finalized_at = locked_at = captured closedAt
  finalization_reason = task_closed_auto_finalize
```

Teacher close captures one authoritative `closedAt`, stops new Starts/writes, and atomically closes the Blitz with all required finalizations. After relevant locks, already-due Attempts use timeout reason/time first; only still-pre-deadline Attempts use close reason/time. Different individual deadlines and replacement #2 deadlines are evaluated independently. Existing terminal history is preserved. Repeated timeout/close or later Submit never rewrites a committed terminal reason/timestamp. No Attempt for never-started Students or unanswered answer row is fabricated; saved answers remain pending until Stage 9 applies zero/checking/review/scoring rules.

Deterministic relevant Blitz/Attempt row locks serialize typed/file mutation against Submit, timeout and close. Re-read authorization, lifecycle, editability and authoritative time after locking. A mutation committed first is included in the frozen history; finalization committed first means zero later answer/file-domain mutation, including file identity/content replacement. Teacher review in Stage 9 cannot rewrite Student answers.

For both Homework and Blitz, Stage 9 checks a frozen Attempt only after the freezing transaction commits (§16.5). Checking and review never change `finalization_reason`, `submitted_at`, `finalized_at` or `locked_at`.

---

## 14.7 Official Score Boundary

Before Topic comparison, exactly one official score must exist for each designated result-bearing task:

```text
Official Homework score
Official Blitz score
```

The `TopicResultEngine` must consume these official score records/resolutions rather than selecting arbitrary attempt data itself. A side counts as `ready` only through the Stage 9 live read (§16.8); the engine never references `official_task_scores` rows from `topic_results` (`S10-T2`).

---

# 15. Blitz Timing Architecture

Blitz timing is authoritative on the backend.

The Flutter countdown is a presentation of server-defined timing state. Device clock or timezone changes must never extend a Blitz.

The Teacher configures one **whole-Blitz duration** for the task. Per-question timers are not part of the MVP.

---

## 15.1 Institution Timer-Start Mode

An Institution Admin configures the Blitz timer-start mode in `institution_settings.blitz_timer_start_mode`:

```text
synchronized
individual
```

Use a policy boundary such as:

```text
BlitzTimerPolicy
```

At activation the policy copies the current configured mode to immutable `blitz_tasks.timer_start_mode_snapshot`. Later setting changes cannot affect an activated Blitz; Teacher create/update cannot override the mode or fixed attempt count. A null setting blocks activation with `409 institution_settings_incomplete`, but not draft/Question authoring, unrelated Homework/Topic work or administration. `duration_seconds > 0` is one whole-task duration, immutable after activation; the classroom 5–10 minute intent is not a validation maximum.

Only Teacher activation makes eligible draft/scheduled Blitz active; scheduling starts no timer and creates no Attempt/checking/result records. First activation validates content, assignment, at least one valid Question, positive total points/duration, lifecycle, cohort and configured timer mode, then captures one `activatedAt = truncate_to_utc_second(server_now)`. It persists active status, activation time and snapshot atomically without creating Student Attempts. Activation replay/fresh-request behavior is specified in §23.4.

Homework before Blitz (`S10-D8`) applies when the activated Blitz is the Blitz of the Topic's result pair:

- **Draft official Homework.** The activation returns `409 official_homework_not_activated` and changes nothing. The check runs immediately after the existing timer-mode settings check and before the cohort is locked. It reads the Homework status without a row lock: every Homework lifecycle change takes the Topic, which the activation already holds, so the read is stable (locking the Homework row here would put it before its Assessment, against the deadline finalizer's order).
- **Active official Homework.** The activation closes it inside the same transaction exactly like a Teacher Homework close. After all locks it captures one untruncated `closedAt = server_now`; the Blitz `activated_at` is `closedAt` truncated to the UTC second (the `activatedAt` rule above), and the Homework close uses `closedAt` itself, so it never precedes the Homework's own sub-second `activated_at` or an Attempt's `started_at`. The deadline is reconciled first when it has passed (§43A); every still-`in_progress` Attempt is frozen as `submitted` with `finalization_reason = task_closed_auto_finalize` at `closedAt` (§14.6); the Homework gets `status = closed` and `closed_at = closedAt` with no recorded actor; the frozen Attempts are checked after the response, like every other freeze in an HTTP request (§16.5; request-scoped collector, no queued job). Only the Homework's own Attempts are passed to the Homework finalizer (the cohort step returns the Attempts of both official tasks).
- **Closed or archived official Homework.** Left unchanged.
- **Locks.** The close reuses the Homework Assessment, Homework row and Attempt locks that the existing cohort step of the activation already takes; it takes no lock in another order. Every other writer of these Attempts takes the Topic first or locks the Homework Assessment first, so no lock cycle exists.
- **Unchanged.** The response, idempotency and every other activation conflict. A replay never closes anything. Practice Blitz activation is unaffected.

### Synchronized mode

When the Teacher activates the Blitz:

```text
activated_at = activatedAt
synchronized_ends_at = activatedAt + duration_seconds
```

All normal Attempts #1 share `deadline_at = synchronized_ends_at`.

A Student who starts later receives only remaining time. At or after the common end, no normal #1 may be created, including an immediately expired empty Attempt.

### Individual mode

Teacher activation makes the Blitz available but does not start every Student's countdown.

When one Student starts the attempt:

```text
blitz_tasks.synchronized_ends_at = null
attempt.started_at = truncate_to_utc_second(server_now)
attempt.deadline_at = attempt.started_at + blitz_tasks.duration_seconds
```

Each Student receives the full configured duration.

The task may still be closed by the Teacher according to lifecycle rules; closing blocks new Student starts and further writes as defined by the API contract.

For approved replacement #2 in either mode, `started_at = truncate_to_utc_second(server_now)` and `deadline_at = started_at + duration_seconds`. This Student-specific recovery interval may begin after the synchronized common end while the Blitz remains active; it never rewrites or extends `activated_at`, `synchronized_ends_at` or the timer snapshot. Resume preserves every persisted timer value.

---

## 15.2 Authoritative Timing Data

The backend must expose enough timing data for Flutter to render a stable countdown.

Conceptually, Student Blitz state may include:

```text
timer_start_mode_snapshot
duration_seconds
activated_at
started_at
synchronized_ends_at
deadline_at
server_now
remaining_seconds
```

Persist the activation snapshot and effective Attempt `deadline_at`; no hidden timer value may differ from the serialized value. Stage 8 backend execution instants, including activation/end, Attempt start/deadline, timeout timestamps and response `server_now`/`snapshotAt`, are floored to UTC whole seconds before comparison, arithmetic, persistence, projection and serialization, never rounded upward. Wire form is exactly `YYYY-MM-DDTHH:MM:SSZ`, with no fraction/non-UTC offset. `remaining_seconds = max(0, deadline_epoch_second - serverNow_epoch_second)` uses the exact whole-second instants serialized in that response. Device clock/timezone is never an operand; existing Institution-timezone schedule/deadline input rules remain unchanged.

---

## 15.3 Timeout Finalization

Timeout behavior is fixed:

> **At the authoritative deadline, the Student's saved Blitz work is finalized automatically.**

Use an idempotent domain/application action:

```text
FinalizeTimedOutBlitzAttempt
```

Rules:

- At/equal/after the authoritative deadline, reject answer/file mutation using time re-checked after locking.
- Lock the attempt against further Student edits.
- Freeze the exact committed saved answers as `timed_out_finalized`, with `submitted_at = null`, `finalized_at = locked_at = deadline_at`, and `finalization_reason = timeout_auto_submit`.
- Keep saved answers `pending`, with no points/checking metadata or Stage 8 review transition.
- Create no Attempt for a never-started Student and no synthetic unanswered answer row.
- Stage 9 later applies unanswered/component zero, objective checking, manual review, points and official score selection; a saved manual answer is not made wrong merely by timeout.

Relevant Student detail/read, Start/Resume, answer/file, Submit, Teacher close, monitoring and Laravel Scheduler paths reuse this one authoritative finalizer. Every write independently checks time; Scheduler latency never extends eligibility and its processing instant never replaces the persisted deadline. Existing terminal history remains unchanged.

---

## 15.4 Monitoring

Teacher monitoring should use authoritative server state.

It may display:

- Assigned Student
- Not started / in progress / submitted / timed out
- Started timestamp
- Remaining time or effective deadline
- Attempt number
- Work waiting for Teacher review, without a monitoring-made checking-state transition
- Technical exception state

Stage 8 monitoring distinguishes not-started, in-progress, explicit submitted, timeout-finalized and task-close-finalized work. It cannot answer for a Student, rewrite answers, award points, perform checking, create Attempts, extend deadlines, change mode, or expose another Institution. Any required timeout reconciliation reuses the same finalizer.

Stage 9 keeps the monitoring wire format (`S09-T6`): a `checked` Attempt counts as `finalized`, a waiting Attempt as `waiting_for_teacher_review`, and every Student row keeps `score: null` through Stage 9. The Teacher reads scores from the review resources (§16.9).

---

# 16. Scoring Architecture

Stage 9 owns, after the Stage 7/8 freeze: automatic checking; Attempt and Answer checking-state transitions; Teacher manual review and correction; awarded points; Attempt scoring and normalization; official task-score selection and persistence; the Teacher review queue and submission detail; Teacher download of submitted answer files (§27.2); the Homework review deadline; and Student visibility of own results (§18.6). Stage 10 owns Homework–Blitz comparison, live Topic results, categories, the Teacher comment, result release actions, the Stage 10 Student and Parent visibility rules (which replace the Stage 9 Attempt visibility rule, §18.6), result closure, and the `409 result_closed` guards after closure (§17.8). The full MVP scoring pipeline remains:

```text
Question score
  ↓
Task score
  ↓
Official task score
  ↓
Topic result
```

---

## 16.1 Question Score

Each scored question contributes points according to its question-type checking logic (§13.1, §13.2). An automatic answer receives its points in the automatic checking run; a manual answer receives Teacher-awarded points in review (§16.9). An unanswered Question contributes 0 without an answer row.

---

## 16.2 Task Score

Task score combines all scored question points. Stage 9 stores it on the Attempt:

```text
Attempt checked:
  earned_points        = exact sum of the stored awarded_points of the Attempt
  normalized_score     = §16.3
  scoring_completed_at = time of the latest scoring

Attempt waiting_for_teacher_review:
  earned_points = null
  normalized_score = null
```

If required manual review remains, the Attempt is `waiting_for_teacher_review` and its task score is pending. Do not treat a partial auto-score as the final official task score. The automatic run sets the Attempt to `checked` when it leaves no waiting answer and otherwise to `waiting_for_teacher_review`; the review of the last waiting answer moves it to `checked`; a correction recalculates a `checked` Attempt (§18.4).

---

## 16.3 Score Normalization

Before homework/blitz comparison:

```text
Normalized Score = 0–100
```

The normalization algorithm is deterministic:

```text
normalized_score = earned_points × 100 / possible_points
```

`possible_points` is the Attempt snapshot taken at Start and is always positive. The result is stored rounded as defined in §16.6.

Draft assessments may temporarily have `total_possible_points = 0` during authoring. Immediately before Homework or Blitz activation, the backend recalculates total points from current Questions and requires `total_possible_points > 0`; a zero-point assessment cannot become active. Normalization is executed only with a positive denominator.

Apart from the one storage rounding in §16.6, do not round before threshold comparison or final-score calculation. Category assignment uses the separate integer category-score conversion defined below.

---

## 16.4 Official Task Scores

Exactly one official 0–100 score is resolved for each designated result-bearing task:

### Homework

```text
official_homework_score =
highest valid completed score among up to 3 normal Homework attempts,
waiting only for an Attempt that could still overtake it (§14.3)
```

### Blitz

```text
official_blitz_score =
checked normal Blitz attempt #1 when no exception exists
or
checked Teacher-approved replacement #2 when an exception replaces the interrupted/invalid normal attempt (§14.5)
```

These official scores are the only task scores consumed by the `TopicResultEngine`.

Official-score resolution must preserve the source attempt reference and scoring eligibility history.

`official_task_scores` (`08-database.md` §19.1) is created in Stage 9 and holds rows only for the Homework and the Blitz referenced by the Topic result pair. A row exists exactly while the official score is ready. `selected_by_user_id` is always null; `selected_at` is set when the row is created or when its `official_attempt_id` or `normalized_score` changes. Practice tasks are checked and reviewed like official tasks but never have an official score.

---

## 16.5 Checking Trigger

Stage 9 checking starts right after a freeze commits, outside the freezing transaction, so freeze responses do not change (`S09-T1`). The freeze itself does no checking.

Freezing points: Homework Submit, Homework deadline reconciliation and Homework Teacher close; Blitz Submit, Blitz timeout reconciliation, Blitz Teacher close, and the timeout performed during a Blitz exception grant. Since Stage 10 the official Blitz activation that closes the official Homework (`S10-D8`, §15.1) is a freezing point too.

- **HTTP request.** One request-scoped collector gathers the ids of the Attempts the request froze. It registers its `app()->terminating(...)` callback only once per collector instance (a flag) and drains its id list on each run, so nothing is checked twice on later requests: Laravel keeps terminating callbacks, and in tests also scoped instances, for the application's lifetime. The callback runs after the response is built. The trigger is not a queued job, because with `QUEUE_CONNECTION=sync` a job would run inline and leak into the freeze response.
- **Console command.** Deadline and timeout reconciliation check each frozen Attempt after the reconciliation transaction commits.
- **Isolation.** Each Attempt is checked in its own transaction. A failure is logged and never propagates; it never rolls back or alters the freeze and never changes the freeze response.
- **Sweep.** A scheduled command runs every minute without overlap. It checks every Attempt still in `submitted` or `timed_out_finalized`, which also covers history frozen before Stage 9, isolating failures per Attempt. It also re-runs the official resolver (§16.8) for official-task Students that have a `checked` eligible Attempt and no pending eligible Attempt but whose official row is missing or differs from the live evaluation; such a state should not exist, and the sweep repairs it. The Laravel Scheduler is already required for Stage 7/8 deadline and timeout reconciliation (§36.1); the integration harness must run it.
- **Idempotency.** Checking takes the §16.7 locks and acts only on Attempts in `submitted` or `timed_out_finalized`, so a repeated or concurrent run does nothing.

---

## 16.6 Arithmetic and Precision

`S09-T3` fixes the scoring arithmetic:

- No binary floating point is used in any scoring calculation. The backend uses `brick/math` (`BigDecimal`), declared as a direct dependency of `backend/composer.json` (locked at `0.18.0`). `bcmath` must not be used, because the Docker image does not install it.
- Text normalization (§13.2) uses `Normalizer` from `symfony/polyfill-intl-normalizer` for NFC, also declared as a direct dependency at its locked version, and `mb_convert_case(..., MB_CASE_FOLD)` for case folding.
- A partial-credit Question is computed in one step, `points × correct / total`, rounded half-up to 8 decimal places for `attempt_answers.awarded_points`. A fully correct answer always stores exactly `points`, so `earned_points ≤ possible_points` always holds.
- `earned_points` is the exact sum of the stored `awarded_points` of the Attempt.
- `normalized_score = earned_points × 100 / possible_points`, rounded half-up to 8 decimal places.
- Official selection, ties and every later comparison use the stored `normalized_score` values; any bound compared with them (§14.3) is rounded the same way first.
- API scores are JSON numbers converted from the stored decimal; clients never calculate with them. Display uses one decimal place with standard half-up rounding.
- Teacher-awarded points (§16.9) follow the Question `points` number rule (`AssessmentPointMath::normalize`: shortest JSON representation, at most 6 fractional digits).

---

## 16.7 Scoring Serialization and Lock Order

Every transaction that may change an official score (automatic checking, review save, correction, Blitz exception grant, and the sweep's re-resolve) locks in this order:

```text
Topic (shared) → Assessment (shared) → Homework/Blitz task row (shared)
→ the Student's assessment_students recipient row (FOR UPDATE)
→ the Student's Attempt rows of that Assessment (FOR UPDATE) → answer rows → official row
```

- The resolver reads the Student's Attempts of that Assessment only under the recipient lock, so two writers for one Student and Assessment never decide concurrently.
- The parent chain comes first because the Teacher Homework update (`UpdateTeacherHomework`), the pair designation (`SetTeacherTopicResultPair`) and the Blitz exception grant lock Group, Teacher membership, Topic, Assessment and task rows `FOR UPDATE` first, and only then Attempts and recipients. Taking the same parents first makes scoring serialize with them instead of deadlocking. The Stage 7/8 Start, Submit, answer, deadline, timeout, close and grant paths already take the parents first. Stage 10 Teacher result actions follow the same parent-first rule (§17.9).
- `topic_result_pairs` is read without a row lock: the designation cannot change once Attempts exist, and Blitz Start locks the pair before the recipient, so locking it after the recipient would invert that order.

---

## 16.8 Official-Score Resolver and Live Evaluation

`OfficialTaskScoreResolver`, with `OfficialScoreEvaluator` applying the Homework rule (§14.3) and the Blitz rules (§14.4, §14.5), runs inside every automatic checking run, review save, correction and exception grant for an official task, and in the sweep (§16.5). It creates, replaces or deletes the `official_task_scores` row so that a row exists exactly while the official score is ready. Reads go through `OfficialScoreReader`.

Between a freeze and its checking run, the row can still show the previous result. Therefore no read trusts the row alone: the official-score read's `ready` status and the Student `score_visible` flag (§18.6) require the row **and** a live evaluation of the Homework rule (§14.3, steps 1-3) or the Blitz rules that is ready with the same Attempt and the same normalized score. The Teacher official-score read (`09-api-contracts.md`) derives its status from the row and the same live evaluation. The Stage 10 side states (§17.3) and result closure (§17.8) use the same live read.

---

## 16.9 Teacher Review and Correction

`ReviewTeacherSubmission` saves Teacher points and feedback for the manual answers of one submission (`S09-D6`, `S09-D7`, `S09-T4`):

- **Access.** A submission is a terminal Attempt (`submitted`, `timed_out_finalized`, `waiting_for_teacher_review`, `checked`) of a Homework or Blitz whose Topic is visible to the Teacher (same Institution, `topics.teacher_id`, current Teacher–Group membership) and whose Student is a persisted recipient. Anything else, including an `in_progress` Attempt, is a privacy-safe `404 resource_not_found`. Topic, Homework and Blitz status (active, closed, archived) do not restrict review.
- **State.** A submission still in `submitted` or `timed_out_finalized` returns `409 automatic_checking_pending`.
- **Transaction.** After request validation, one transaction takes the §16.7 locks, evaluates access, state and items again under the locks, and only then writes `awarded_points`, `feedback`, `checking_status = teacher_checked`, `checked_by_user_id` and `checked_at` (server now) for each item, recalculates the Attempt (§16.2) and runs the resolver (§16.8).
- **Partial and concurrent review.** A subset of the manual answers may be saved. Concurrent reviews of one submission serialize on the locks; each answer keeps the last committed value. Review uses no `Idempotency-Key`.
- **Correction.** The same action on `teacher_checked` answers keeps the Attempt `checked`, recalculates it and re-resolves the official score, which may move to another Attempt. Stage 9 has no closure guard, so a correction is always allowed. Stage 10 adds `409 result_closed`: on an Attempt of the Topic's official Homework or Blitz of a Student whose Topic result is closed, any item naming a `teacher_checked` answer fails the whole request. The check runs inside the scoring-lock transaction, after the re-checked `automatic_checking_pending` state and before the item re-validation and any write; a request with invalid items still gets the existing pre-transaction `422` first. A first review of a still-waiting answer stays allowed (§17.8). Practice tasks are never affected.
- **History.** Only the last reviewer and time are kept, in `checked_by_user_id` and `checked_at`; there is no review history table in the MVP.
- **Homework review deadline.** `homework_assignments.review_due_at` is a reminder only: it never changes scores, statuses or official selection. Blitz has none.
- **Device.** Review is desktop-only in the UI; the API does not check the device. Teacher mobile shows only read-only waiting-for-review and overdue counts (§22.4).

Exact request, response and error shapes belong in `09-api-contracts.md`.

---

# 17. Topic Result Engine

Stage 10 turns the two official task scores into the Student's Topic result. It applies the owner decisions `S10-D1`…`S10-D9` and the technical decisions `S10-T1`…`S10-T9` (`tasks/S10-DOC-001-stage-10-topic-results-contract-alignment.md`).

Create a dedicated backend domain service:

```text
TopicResultEngine
```

It must be the authoritative implementation of the Topic result: side states, result status, final score, consistency, and category. Teacher, Student and Parent result reads, release and closure decisions, and later reports all use it; no other code repeats the formula.

---

## 17.1 Inputs and Live Computation

An open (not closed) Topic result is computed live on every read from the current state (`S10-T1`). It is not stored, no job or Scheduler entry computes it in advance, and no action or endpoint stores a computed open result. A closed result is read from its closure snapshot (§17.6) and is never computed again.

Conceptual input of the live computation:

```text
student
topic
official pair (topic_result_pairs: official Homework, optional official Blitz)
official cohort (persisted recipients of the official tasks)
live official-score status of each side (§16.8)
lifecycle, deadline and the Student's Attempts of each official task
institution's current acceptable_score_difference (T)
institution's current understanding-category set
topic_results row, when one exists (comment, release facts, closure snapshot)
```

- A Topic has Topic results only after its official cohort is established (`cohort_snapshotted_at` is set). The cohort is the set of persisted recipients (`assessment_students`) of the official Homework and the official Blitz; the existing cohort rule keeps both sets identical once both have recipients. Group membership changes after the snapshot never change the cohort.
- `topic_results` stores only what cannot be derived: the Teacher comment (`S10-D1`), the Teacher release facts (`student_released_at`/`by`, `parent_released_at`/`by`) and the closure snapshot. One row per Topic and Student is created on the first write for that pair (comment, release or closure); an open result without a row is fully described by the live computation.
- `topic_results` never references `official_task_scores`, whose rows the resolver deletes and re-inserts, nor `topic_result_pairs` (`S10-T2`). The closure snapshot keeps the official Attempt ids with tenant-safe references to `assessment_attempts`, which are never deleted. Exact columns and constraints belong in `08-database.md`.
- Reads take no locks and compute inside one `REPEATABLE READ READ ONLY` snapshot (§17.9).

---

## 17.2 Comparison

For a `calculated` result (§17.4), H and B are the stored 8-decimal official scores (§16.6) and T is the Institution's current acceptable difference (`S10-D6`). All values use exact decimals without further rounding (`S10-T5`):

```text
H = official homework score
B = official blitz score
D = abs(H - B)
T = acceptable difference
```

If:

```text
D <= T
```

then:

```text
final_score = (H + B) / 2
consistency = consistent
calculation_method = average
```

If:

```text
D > T
```

then:

```text
final_score = B
consistency = inconsistent
calculation_method = blitz
```

- `final_score` is exact (an average can need nine decimals) and is stored and serialized half-up to 8 decimal places.
- `calculation_method` has exactly two values, `average` and `blitz`. Waiting and Not completed live in the result status, never in the method.
- The same rule applies whichever score is higher; an inconsistent result is never presented as an accusation.

---

## 17.3 Side States

Each side (Homework, Blitz) of one cohort Student has exactly one state (`S10-T3`). The official-score status is the Stage 9 live read (§16.8): `ready` only while the stored official row matches the live evaluation.

Homework side — first match:

| # | Condition | Side state |
|---|---|---|
| 1 | Official score status `ready` | `ready` (value H, official Attempt) |
| 2 | Status `waiting_for_teacher_review` | `waiting_for_teacher_review` |
| 3 | Status `automatic_checking_pending` | `checking` |
| 4 | The official Homework was never activated | `not_activated` |
| 5 | The Student has an `in_progress` Attempt | `open` |
| 6 | The Homework is active, has no deadline or `server_now < deadline_at`, and the Student has fewer than three Attempts | `open` |
| 7 | Otherwise (closed or archived, deadline passed, no checked or pending Attempt) | `missing` |

Blitz side — first match:

| # | Condition | Side state |
|---|---|---|
| 1 | The pair has no Blitz | `not_designated` |
| 2 | Official score status `ready` | `ready` (value B, official Attempt) |
| 3 | Status `waiting_for_teacher_review` | `waiting_for_teacher_review` |
| 4 | Status `automatic_checking_pending` | `checking` |
| 5 | Status `waiting_for_replacement` | `open` |
| 6 | The official Blitz was never activated (draft, scheduled, or archived before activation) | `not_activated` |
| 7 | The Blitz is active, the Student has no Blitz Attempt and the Homework side is `missing` (the Student can no longer get the submitted Homework that `S10-D8` requires to start, §14.4) | `missing` |
| 8 | The Blitz is active | `open` |
| 9 | Otherwise (closed or archived after activation; never started, or an exception without a taken replacement — even while #1 waits for review) | `missing` |

- A side that waits for checking or Teacher review is never `missing`.
- A side the Teacher never designated or never activated is never `missing`: the result waits.
- No numeric final score is invented for a side that is not `ready`.

---

## 17.4 Result Status

Open results — first match (`S10-T3`, `S10-T4`):

| # | Condition | `result_status` |
|---|---|---|
| 1 | Some side is `missing` | `not_completed`; `missing_component` = `homework`, `blitz` or `both` (the sides that are `missing` now) |
| 2 | Both sides `ready`, and the Institution has a threshold T and a valid complete category set | `calculated` |
| 3 | Both sides `ready`, threshold or category set missing | `waiting_for_settings` |
| 4 | Homework side `not_activated`, `open` or `checking` | `waiting_for_homework` |
| 5 | Blitz side `not_designated`, `not_activated`, `open` or `checking` | `waiting_for_blitz` |
| 6 | Otherwise (a side `waiting_for_teacher_review`) | `waiting_for_teacher_review` |

- `missing_component` is null for every other status. A `not_completed` result can still change its `missing_component` (for example `homework` → `both`) until it is closed.
- Review alone never makes a result Not completed. A result is Not completed only because some side is `missing`, even while the other side is still open or waits for review.
- D, T, consistency, `calculation_method`, `final_score` and `category_score` exist only for `calculated` (open or closed). The category is the numeric category for `calculated`, `not_completed` for Not completed, and none otherwise.

A closed result has `result_status = closed` and `closed_outcome` = `calculated` or `not_completed` (null for open results); all its values come from the closure snapshot (§17.6).

Terms:

- **Terminal**: open `calculated` or open `not_completed`.
- **Work finished** (per Student; the `S10-D3` visibility window): the official Blitz was activated and is closed or archived; the official Homework is closed or archived, or has `deadline_at <= server_now`, or the Student has used all three Attempts; and the Student has no `in_progress` Attempt on either official task. A Topic without an official Blitz never has finished work for visibility. A deadline moved later or removed (allowed only while the Homework has no Attempts, so only in history from before `S10-D8`) closes the window again for an open result; a result closed by the Teacher (`closure_reason = teacher`) always counts as finished (its work was finished at closure); a result closed at Topic archive counts as finished by the rule above (at archive no Attempt is in progress and every task is closed or archived, so only a Topic without an activated official Blitz stays unfinished, and its values stay hidden, §17.8, §18.6).
- **Closable** (`S10-D9`): terminal, and either the Student's work is finished or the Topic is being archived (§17.8).
- Waiting for review, waiting for settings and not released are never Not completed.

---

## 17.5 Category Resolver

Use a separate domain component:

```text
UnderstandingCategoryResolver
```

Responsibilities:

- Derive integer `category_score` from the exact final score: fractional part `.0` through `.5` rounds down; fractional part greater than `.5` rounds up (85.5 → 85, 85.50000001 → 86).
- Validate institution ranges as inclusive integer bands.
- Ensure every integer 0–100 is covered exactly once.
- Prevent gaps and overlaps.
- Resolve exactly one numeric category from `category_score`, using the Institution's current category set for an open result (`S10-D6`).
- Treat a stored set that fails the set validator as missing (`waiting_for_settings`, §17.4).
- Keep Not completed separate from numeric categories.

---

## 17.6 Closure Snapshot

An open result is explained by its current inputs (§17.1). Closing writes, from the live computation inside the closure transaction:

- `closed_at`, `closed_by_user_id` (the closing or archiving Teacher), `closure_reason` (`teacher` or `topic_archived`), `closed_outcome`, `missing_component`
- the pair's Homework and Blitz assessment ids and both side states
- the official Attempt ids and scores of the `ready` sides
- for `calculated`: D, the threshold T used, calculation method, consistency, final score, `category_score`, category, and the category range used

After closure the closure and comment columns never change (`S10-T7`, `S10-D6`); the release columns can still be set, because release stays separate from closure. A closed result never reads current settings again, so changing institution settings never rewrites it.

---

## 17.7 Score Precision and Display Policy

Use an explicit component such as:

```text
ScorePrecisionPolicy
```

Approved behavior:

- Preserve sufficient decimal precision for question, task, official-score, difference, and final-result calculations. Stage 9 stores awarded points and normalized scores rounded half-up to 8 decimal places (§16.6); calculations never round these stored values again.
- Do **not** round the stored Homework or Blitz scores further before `D = abs(H - B)` or the comparison with T.
- The final score is computed exactly and stored and serialized half-up to 8 decimal places (`S10-T5`). Derive the separate integer `category_score` from the exact final score using `.0`–`.5` down and `>.5` up.
- User-facing numeric scores are displayed by the client with **one decimal place** using standard mathematical rounding; display rounding never changes the category. The Teacher sees D and T with one decimal like every score, so equal-looking D and T with `inconsistent` are possible and correct (T allows 8 decimals).
- API/database contracts must distinguish authoritative stored/calculation precision from presentation formatting.
- Reports must use the same display policy while aggregations remain based on authoritative values.

---

## 17.8 Result Closure Policy

Use an explicit domain policy/action boundary such as:

```text
TopicResultClosurePolicy
CloseTopicResult
```

A Student+Topic result may close only when it is closable (`S10-D9`, §17.4): terminal (open `calculated` or open `not_completed`) and either the Student's work is finished — the moment the result can become visible (`S10-D3`); with `S10-D8` that is, for everyone, right after the official Blitz closes — or the Topic is being archived. Waiting results cannot close. Closure is never reopened in the MVP; appeals are Post-MVP.

- **Single close.** Already closed: success with the closed result and no change. Not closable: `409 result_not_ready_for_closure`. Otherwise write the snapshot (§17.6) with `closure_reason = teacher`.
- **Bulk close** (`S10-D7`). Applies the single rule to every cohort Student in one transaction and reports how many results it processed and how many it skipped as already closed or not ready.
- **Topic archive** (`S10-D7`). `ArchiveTopic` closes every terminal result of the cohort inside its transaction with `closure_reason = topic_archived` and `closed_by_user_id` = the archiving Teacher; waiting results stay open, and `CloseTopic` closes no result. At archive every task is closed or archived and the Topic can no longer change, so no further work is possible even without an official Blitz; the values of such a result stay hidden (§18.6). This is a deliberate change to the Stage 5 archive behavior.
- **Live re-check.** Closure computes terminal state, finished work and the snapshot inside its transaction from one consistent view, after the §17.9 locks, with the §16.8 live read rather than the official row alone.
- **Release.** Release is independent from closure; a closed result can still be released (§19).

What closure blocks — `409 result_closed` (`S10-T7`), for a Student whose Topic result is closed:

- a review correction on an Attempt of the Topic's official Homework or Blitz (§16.9);
- a Teacher comment edit, even with an unchanged value, checked before the no-op check;
- a Start of the official Homework, after the existing lifecycle, deadline and attempt-count conflicts. It is reachable only in history from before `S10-D8`: a Homework with no Attempt at all whose deadline a Teacher moved later.

Closure needs finished work (`S10-D9`) — the official Blitz is closed — or the Topic is archived, so a Blitz Start, an exception grant and a pair change (already refused by `result_pair_locked`/`topic_not_editable`) cannot happen after closure and get no `result_closed` guard. Idempotent replays of an earlier successful request keep returning the stored response. Practice tasks are never affected.

Still allowed after closure: a first review of a still-waiting answer. For a `calculated` closure no pending Attempt could overtake, so that review cannot change the official score. For a `not_completed` closure the snapshot holds only the sides that were `ready`; a later first review may still complete the other side's official score in `official_task_scores` (Stage 9 views show it), but it never changes the closed snapshot. Automatic checking and the sweep keep running unchanged; nothing they do can change a closed result's snapshot.

---

## 17.9 Teacher Result Actions and Lock Order

Teacher result actions are: the result list and detail, the comment (`S10-D1`), Student and Parent release (single Student and bulk, §19), close (single Student and bulk, §17.8), and the closure inside `ArchiveTopic`.

- **Access** (`S10-T6`). The Topic's Teacher only: the Teacher owns the Topic and is a current Teacher of its group (the review access rule, §16.9); otherwise a privacy-safe `404`. A Student outside the cohort is `404`. Topic and task status never restrict these actions. The API does not check the device; the screens follow `S10-FE-D1` (release on desktop and mobile; comment and closure on desktop only).
- **Comment** (`S10-D1`). One optional Teacher comment per Student result, at most 2000 characters after leading and trailing Unicode whitespace is trimmed; an empty value is stored as null, never as an empty string. It may be changed in every status until closure; afterwards `409 result_closed` (§17.8). The Student sees it with the visible values, the Parent only when the values are visible to the Parent; answer feedback stays Student-only.
- **Idempotency.** Close and release are idempotent by state: an already-done single action succeeds without a change. Bulk actions apply the single-Student rule to every cohort Student in one transaction and report processed and skipped counts; a release mode that forbids the release fails the whole bulk call with `409 manual_release_not_allowed`. They use no `Idempotency-Key`.
- **Lock order.** Teacher result actions (comment, release, close, bulk, archive) lock group → Teacher membership → Topic `FOR UPDATE` (the Topic lifecycle order), then the `topic_results` rows they write. This serializes them with scoring (checking, review and sweep repair take the Topic `FOR SHARE` first, §16.7), with Student Starts and the exception grant (they take the Topic `FOR UPDATE` first), and with Submit and answer saves (they take it shared).
- **Closure Attempt locks.** The Homework deadline and Blitz timeout finalizers lock the Assessment and then the Attempts and never the Topic. Closure (single, bulk and on archive) therefore additionally locks the official Attempt rows of every affected Student `FOR SHARE` in one query ordered by Attempt id — one global order, also across Students in a bulk close — after the Topic and before evaluating; terminal state, finished work and the snapshot then come from one consistent view.
- **No cycle.** No path locks the Topic and then a group or a Teacher membership (the activation snapshot locks Student memberships after the Topic, which no Teacher result action locks), so no lock cycle exists.
- **Reads.** Result reads take no locks and compute inside one `REPEATABLE READ READ ONLY` snapshot.

---

# 18. State Architecture

TestLabUz must not use one generic `status` concept for unrelated states.

Use distinct types.

---

## 18.1 Topic Lifecycle

```text
draft
active
closed
archived
```

---

## 18.2 Homework Lifecycle

```text
draft
active
closed
archived
```

---

## 18.3 Blitz Lifecycle

```text
draft
scheduled
active
closed
archived
```

---

## 18.4 Student Attempt / Submission Status

Conceptually, the MVP must distinguish:

```text
not_started
in_progress
submitted
timed_out_finalized
waiting_for_teacher_review
checked
not_completed
```

`timed_out_finalized` is the persisted Stage 8 timeout state in the shared Attempt enum. It means the authoritative Blitz deadline ended, committed saved work was frozen, and the Attempt is no longer editable. It is neither missing/abandoned work nor proof of completed checking/scoring.

Lifecycle ownership is explicit:

```text
Stage 7 Homework execution: in_progress -> submitted
Stage 9 Homework checking:  submitted -> waiting_for_teacher_review / checked
Stage 8 Blitz execution:    in_progress -> submitted / timed_out_finalized
Stage 9 Blitz checking:     frozen execution -> waiting_for_teacher_review / checked
```

For Homework, `submitted` means frozen Student work awaiting later checking; it does not imply explicit Student Submit or completed scoring. Only explicit Student Submit sets `submitted_at`.

Stage 9 checking-state transitions (`S09-T1`):

```text
Answer checking_status:
  pending → auto_checked                          (automatic types; zero-point manual answers)
  pending → waiting_for_teacher_review            (manual answer with a row and points > 0)
  waiting_for_teacher_review → teacher_checked    (Teacher review)
  teacher_checked → teacher_checked               (Teacher correction)

Attempt status:
  submitted | timed_out_finalized
    → checked                     (automatic run leaves no waiting answer)
    → waiting_for_teacher_review  (at least one waiting answer)
  waiting_for_teacher_review → checked   (last waiting answer reviewed)
  checked → checked                      (correction recalculates)
```

On `checked`, `earned_points`, `normalized_score` and `scoring_completed_at` (time of the latest scoring) are set; while the Attempt waits, `earned_points` and `normalized_score` stay null. `finalization_reason`, `submitted_at`, `finalized_at` and `locked_at` never change. After checking, a timed-out Blitz Attempt is no longer `timed_out_finalized`; rules that must still recognize the timeout key on `finalization_reason = timeout_auto_submit` (§14.4, §23.4).

For an approved technical Blitz exception, the original affected attempt additionally needs explicit scoring-eligibility/exclusion metadata and a link/reason context sufficient for history.

Exact persistence representation belongs in `08-database.md`.

---

## 18.5 Topic Result Status

```text
waiting_for_homework
waiting_for_blitz
waiting_for_teacher_review
waiting_for_settings
calculated
not_completed
closed
```

`not_completed` carries `missing_component` (`homework`, `blitz` or `both`); `closed` carries `closed_outcome` (`calculated` or `not_completed`). Open statuses are computed live with the precedence in §17.4 from the side states in §17.3.

---

## 18.6 Result Visibility

Visibility is independent from result calculation status. It is derived at read time from the current Institution release modes, the `S10-D3` visibility window and the Teacher release facts stored on `topic_results` (`student_released_at`, `parent_released_at`). There is no other per-result visibility state and no release-mode snapshot (`S10-D6`).

Institution settings:

```text
student_result_release_mode:
- automatic
- manual_teacher

parent_result_release_mode:
- with_student
- manual_teacher
- hidden
```

A calculated result may remain invisible without becoming incomplete.

### Topic result — Student

The Student always sees the status (`result_status`, `closed_outcome`, `missing_component`). The values — H, B, final score, calculation method, category and the Teacher comment — are visible when all hold:

```text
result is terminal or closed
+ the Student's work is finished (§17.4)
+ (student_result_release_mode = automatic  or  topic_results.student_released_at is set)
```

In `automatic` mode the values become visible by themselves at that moment; in `manual_teacher` mode the Teacher's release becomes available at that moment (`S10-D3`). A Student who finishes the Blitz early never sees a score before the Blitz closes. An unconfigured Student mode shows no values. The Student and the Parent never see the consistency label, D, T or `category_score`; the calculation method is shown only as one neutral line on how the final score was formed (`S10-D2`).

### Topic result — Parent

The Parent sees result information only for a Student with a current Parent–Student relationship. With `parent_result_release_mode = hidden`, or while it is unconfigured, the Parent receives no result information at all, not even the status (`S10-T8`). Otherwise the status is visible, and the values (as for the Student, including the Teacher comment) are visible when:

```text
the values are visible to the Student
+ (parent mode = with_student  or  (parent mode = manual_teacher and topic_results.parent_released_at is set))
```

Parent values therefore never become visible before the Student's. The Parent never sees answer feedback (`S10-D1`). Stage 10 exposes this through one Parent result read; Parent screens are Stage 11.

### Attempt results

Stage 9 derived Attempt result visibility at read time from the `automatic` mode only (`S09-D3`, `S09-D5`). Stage 10 replaces that rule (`S10-D4`). An Attempt result (normalized score and answer feedback) is visible to its Student when all hold:

```text
attempt.status = checked
+ attempt.official_score_eligible = true
+ (Homework) or (Blitz with status closed or archived)
+ (practice task) or (student mode = automatic) or (the Student's Topic result has student_released_at)
```

A manual Topic release therefore also makes that Student's official Homework and Blitz Attempt results and answer feedback visible. Practice task results are not governed by the release mode: they are visible after checking in every mode (a practice Blitz after it closes). The Student Homework `official_score` and `score_visible` follow the same release condition: `score_visible` is true exactly when the Homework is the official one, its official score is ready by the §16.8 live evaluation, and the mode is `automatic` or the Student's Topic result has `student_released_at`. The Attempt status `checked` stays visible without a score in manual mode (`BR-STAT-018`). Every Stage 9 response keeps its shape; only which values are visible changes.

An invalidated Blitz #1 never shows a score; the Student sees it as invalidated. Answer feedback is shown only when the result is visible. A Student never receives correct answers, answer keys, per-Question awarded points, per-answer checking status, reviewer identity or `review_due_at`. Exact Student and Parent fields belong in `09-api-contracts.md`.

---

# 19. Result Release Architecture

Result calculation and result release are separate capabilities.

Use explicit release orchestration such as:

```text
ResultReleasePolicy
ReleaseStudentTopicResult
ReleaseParentTopicResult
```

Release must not change:

- Homework score
- Blitz score
- Difference
- Final score
- Category
- Consistency
- Result status

It records a Teacher release fact only; visibility then follows §18.6.

---

## 19.1 Student Release

Institution setting:

```text
student_result_release_mode =
automatic | manual_teacher
```

### Automatic

No Teacher action and no write: the values become visible by themselves once the result is terminal or closed and the Student's work is finished (§18.6).

### Manual Teacher release

The result may be fully calculated while its values are not visible to the Student. An authorized Teacher (§17.9) releases it once the visibility window is open; the release sets `student_released_at` and its actor. First match:

1. The current Student mode is not `manual_teacher` → `409 manual_release_not_allowed`.
2. Already released → success without a change.
3. The result is neither terminal nor closed, or the Student's work is not finished → `409 result_not_ready`.
4. Otherwise record the release.

The release also makes that Student's official Homework and Blitz Attempt results and answer feedback visible (`S10-D4`). A closed result is released like any other.

---

## 19.2 Parent Release

Institution setting:

```text
parent_result_release_mode =
with_student | manual_teacher | hidden
```

### With Student

The Parent sees the values exactly when the Student sees them; no Teacher action is needed.

### Manual Teacher release

The Parent sees the status but not the values until an authorized Teacher releases them; the release sets `parent_released_at` and its actor. First match:

1. The current Parent mode is not `manual_teacher` → `409 manual_release_not_allowed`.
2. Already released to Parents → success without a change.
3. The values are not visible to the Student now (§18.6) → `409 student_result_not_released`.
4. Otherwise record the release.

### Hidden

The Parent receives no result information at all, not even the status. The same applies while the Parent mode is unconfigured.

---

## 19.3 Bulk Release

`S10-D7` adds "release all ready to Students" and "release to Parents all results visible to Students". Each applies the single-Student rule to every cohort Student in one transaction and reports how many results it processed and how many it skipped as already released or not ready. A mode that forbids the release fails the whole call with `409 manual_release_not_allowed`.

---

## 19.4 Release Invariants

- Parent values can never become visible before the Student's.
- Release never alters calculation state, values or status.
- Release actions are idempotent (§17.9).
- Parent access still requires a current Parent–Student relationship and normal authorization.
- A released result stays released (`S10-D5`). After a Teacher correction the Student and the Parent see the new values at once; if the result falls back to a waiting status they see that status without values, and then the new result without a new release. The MVP has no hide or unrelease action.
- A release-mode change acts on every result immediately; Teacher releases already made stay (`S10-D6`). For example, after a change from `automatic` to `manual_teacher` the Student no longer sees values that were visible only through the automatic mode until the Teacher releases them.
- Institution setting changes never rewrite closed results (§17.6).

---

# 20. Flutter Application Architecture

## 20.1 Recommended Flutter Technical Baseline

Recommended libraries:

- **Riverpod** — dependency injection and application state
- **GoRouter** — declarative navigation and route guards
- **Dio** — HTTP client
- **json_serializable** or equivalent — DTO serialization
- Secure platform storage for authentication credentials/tokens where required

These are technical architecture choices and may be changed only through an explicit architecture revision before implementation is locked.

---

## 20.2 Flutter Folder Structure

```text
frontend/
  lib/
    app/
      app.dart
      bootstrap.dart

    core/
      config/
      auth/
      network/
      routing/
      errors/
      storage/
      time/
      ui/
      utils/

    features/
      auth/
        data/
        domain/
        presentation/

      platform_admin/
        data/
        domain/
        presentation/

      institution_admin/
        data/
        domain/
        presentation/

      groups/
        data/
        domain/
        presentation/

      topics/
        data/
        domain/
        presentation/

      materials/
        data/
        domain/
        presentation/

      homework/
        data/
        domain/
        presentation/

      blitz/
        data/
        domain/
        presentation/

      submissions/
        data/
        domain/
        presentation/

      results/
        data/
        domain/
        presentation/

      reports/
        data/
        domain/
        presentation/

    shared/
      widgets/
      models/

  test/
```

Do not create one giant `screens/`, `services/`, or `models/` folder containing unrelated features.

---

## 20.3 API Client Boundary

Use one configured API client layer.

Responsibilities:

- Base URL
- Authentication headers
- Standard API decoding
- Failure mapping
- Request timeout configuration
- Logging safe metadata in development
- Retry only where explicitly safe

Feature repositories must not each reinvent authentication and response parsing.

---

## 20.4 Repository Boundary

Presentation code should not call Dio directly.

Conceptual flow:

```text
Screen / Controller / Notifier
  ↓
Feature Repository
  ↓
API Data Source
  ↓
Dio
```

---

## 20.5 Client Models

Separate:

```text
API DTO
```

from:

```text
Domain/UI Model
```

when API representation and UI needs differ.

Do not leak raw JSON maps throughout the presentation layer.

---

## 20.6 Loading / Empty / Error / Success States

Every data-driven screen should define predictable states.

At minimum:

```text
loading
data
empty
error
```

Mutation flows should define:

```text
idle
submitting
success
failure
```

Prevent duplicate submissions while a mutation is in flight.

---

# 21. Flutter Navigation Architecture

Navigation must be role-aware.

Conceptual route areas:

```text
/auth

/platform-admin/...

/institution-admin/...

/teacher/...

/student/...

/parent/...
```

The exact URL/route strings belong in frontend implementation contracts.

---

## 21.1 Route Guards

Route guard logic should consider:

- Authentication
- Role
- Device capability where applicable

The backend still remains authoritative for data access.

A protected route cannot rely only on hidden navigation.

---

## 21.2 Desktop Shells

Desktop should provide role-appropriate management shells.

Likely shell categories:

```text
Platform Admin Shell
Institution Admin Shell
Teacher Desktop Shell
Student Desktop Shell
```

---

## 21.3 Mobile Shells

Mobile should provide:

```text
Teacher Mobile Shell
Student Mobile Shell
Parent Mobile Shell
```

The same account must retain the same backend authorization scope regardless of shell/device.

---

# 22. Role/Device Feature Boundary

## 22.1 Platform Owner / Super Admin

Desktop only in MVP.

Primary capabilities:

- Platform dashboard
- Institutions
- Institution details
- Institution lifecycle
- Basic platform settings/statistics

No routine daily learning editing.

---

## 22.2 Institution Admin

Desktop only in MVP.

Primary capabilities:

- Institution dashboard
- Users
- Groups
- Relationships
- Acceptable score-difference threshold
- Understanding-category ranges
- Blitz timer-start mode
- Student/Parent result-release modes
- Institution timezone
- Lower institution upload limits
- Basic reports

---

## 22.3 Teacher Desktop

Primary authoring/review surface:

- Topics
- Materials
- Homework builder
- Blitz builder
- Manual checking and correction (Stage 9 submission review is desktop-only, `S09-D7`)
- Detailed results
- Reports

---

## 22.4 Teacher Mobile

Quick classroom/monitoring surface:

- Assigned groups
- Topic status
- Homework status
- Blitz activation (activating the official Blitz closes the official Homework, `S10-D8`, §15.1)
- Blitz monitoring
- Student-specific Blitz exception grant where authorized (desktop-only in Stage 8, `S08-FE-006` §4; not yet delivered on mobile)
- Read-only review counts (waiting counts on Homework and Blitz details; overdue counts on Homework details); Stage 9 submission review and correction are not available on mobile (`S09-D7`)
- Basic result review
- Student/Parent release actions where institution policy requires Teacher action

Do not attempt to reproduce every desktop authoring feature in the MVP mobile UI.

Stage 10 Teacher result actions (comment, release, close; single Student and bulk) are device-agnostic at the API (§17.9). Per `S10-FE-D1` the Teacher views results and releases them (single and bulk) on desktop and mobile; the comment and closure are desktop-only.

---

## 22.5 Student Desktop

Best for:

- Large materials
- Written assignments
- File submissions
- Detailed progress

---

## 22.6 Student Mobile

Best for:

- Quick topic access
- Simple assignments
- Blitz participation
- Result/progress viewing

---

## 22.7 Parent Mobile

Read-only monitoring:

- Child selection
- Topic progress
- Completion
- Released results
- Understanding categories
- The Teacher's Topic-result comment with visible result values (`S10-D1`); never answer feedback

Stage 10 adds only the Parent result read (`S10-T8`, §18.6); Parent screens are Stage 11.

---

# 23. API Boundary Principles

Detailed contracts belong in `09-api-contracts.md`.

Architecture-level rules:

## 23.1 Versioning

Use:

```text
/api/v1
```

for MVP public client API.

---

## 23.2 Server Authority

The backend must calculate/decide:

- Authorization
- Fixed attempt availability
- Homework Attempt editability and authoritative deadline reconciliation
- Blitz attempt-exception eligibility
- Deadline validity
- Blitz availability
- Blitz effective deadline / timeout
- Official Homework/Blitz score
- Result formula
- Category
- Side states and result status
- Finished work, closability and Student/Parent visibility eligibility

The client may display these results but must not be authoritative.

---

## 23.3 Validation Errors

API contracts must distinguish:

- Validation failure
- Authentication failure
- Authorization failure
- Not found inside allowed scope
- Business conflict/state failure
- Server failure

Exact HTTP status and response envelope are defined in `09-api-contracts.md`.

---

## 23.4 Idempotency / Duplicate Mutation Protection

High-risk client mutations use one normative idempotency contract. `Idempotency-Key` is required for:

- Start Homework Attempt
- Start Blitz Attempt
- Final Attempt submission
- Blitz activation
- Granting a Student-specific Blitz attempt exception

A safe retry with the same key/request identity returns the same logical result. Other concurrent mutations such as manual review and Stage 10 result actions use transactional state/version guards (Stage 9 review saves serialize on the §16.7 lock order; Stage 10 comment, release and close serialize on the §17.9 lock order and are idempotent by state; none takes an `Idempotency-Key`); they do not invent a second public idempotency contract unless `09-api-contracts.md` explicitly adds one.

Stage 8 reuses durable `idempotency_records` with exactly `student.blitz.attempt.start`, `student.blitz.attempt.submit`, `teacher.blitz.activate`, and `teacher.blitz.attempt_exception.grant`. Blitz Submit never substitutes a generic Assessment operation or merges with unchanged `student.homework.attempt.submit`. Answer PUT, file mutation, Teacher Close, schedule, archive and result-pair PUT gain no key requirement. Replay always requires current authorization.

All three Blitz Start intents use `student.blitz.attempt.start`; fingerprint identity contains the lowercase authorized route Blitz UUID, exact submitted intent and lowercase validated `attempt_id` only for Resume, never derived mode/deadline/server time/Attempt number/lifecycle/exception availability. Authorized completed same-key/same-fingerprint replay precedes fresh-state decisions and returns the same logical Attempt with the original semantic `201` (created) or `200` (existing), without timer/history churn. Later lifecycle transitions do not reinterpret intent; replacement requires a new request/key with `start_replacement`. Changed Blitz/intent/Resume target with the same key returns `409 idempotency_key_reused` without domain mutation.

For activation, authorized completed same-key replay with valid persisted activation evidence and valid result metadata returns `200` with the current resource for active/closed/archived; closed/archived confirms historical activation without reopening. A completed-success record pointing to draft/scheduled, or missing/invalid activation evidence/result metadata, fails closed as an internal integrity inconsistency. Fresh/new-key active activation returns naturally idempotent `200` and may complete the new claim to that Blitz. Both success paths perform zero activation-domain mutation: no rewrite of activation, snapshot, common end, recipients, cohort or pair identity/lock, and no official Homework close (`S10-D8`). Fresh closed/archived requests return respectively `409 task_closed`/`409 task_archived`, with no successful claim; first eligible draft/scheduled activation follows §15.1.

Blitz Submit uses the shared submit route with `student.blitz.attempt.submit`. A new request finding due in-progress work commits timeout reconciliation, returns `409 blitz_time_expired`, and leaves neither a new successful Submit result nor an incomplete claim. New requests for a terminal Attempt with `finalization_reason = timeout_auto_submit`, whatever its later checking status, also return `409 blitz_time_expired`; all other terminal execution/checking history returns `409 attempt_not_editable`. A completed successful same-key Submit replays `200` if the original `student_submit` reason, non-null `submitted_at` and matching finalized/locked times remain, including later Stage 9 review/checked states, without exposing checking/score metadata.

Homework Start and final Submit use durable PostgreSQL records, with operation codes `student.homework.attempt.start` and `student.homework.attempt.submit`; process/request/Flutter/cache-only timing state is insufficient. The lookup and unique scope is authenticated `institution_id + user_id + operation + idempotency_key`. A deterministic fingerprint covers the operation, authenticated Institution/User, route target UUIDs, and normalized semantic body fields, never secrets, Authorization tokens, or the key itself. Same scope/key/fingerprint replays the original logical resource and successful semantic HTTP status without a second mutation; different-fingerprint reuse returns `409 idempotency_key_reused` with no domain mutation. Authorization and tenant/assignment/ownership checks always remain mandatory. Completed records are not automatically expired or deleted in the MVP.

A successful protected Homework Start/Submit and its completed claim/result commit atomically through conflict-safe PostgreSQL claiming. Neither a successful mutation without its result nor a deliberately incomplete claim may commit. When a new late Start/Submit discovers under locks that the Homework deadline is reached, required deadline reconciliation must still commit while the request returns the documented failure, normally `409 deadline_passed`; the operation leaves neither a new completed success record nor a new incomplete claim. Reconcile before acquiring a new claim, or remove only that newly acquired incomplete claim and surface failure after the reconciliation transaction commits. Never delete a previously completed record. A valid replay of a completed pre-deadline success may still return that prior success because it performs no new mutation.

---

## 23.5 Pagination

Lists that may grow must support server-side pagination.

Examples:

- Institutions
- Users
- Groups
- Topics
- Assignments
- Submissions
- Results

Exact pagination contract belongs in `09-api-contracts.md`.

---

# 24. Resolved MVP Business Decisions

All ten architecture-affecting business decisions are approved. They are no longer implementation gates.

Codex, database design, and API design must implement these decisions as fixed MVP contracts unless a later documented change explicitly revises them.

## DEC-01 — Official Score Across Attempts

**Approved**

- Homework: exactly 3 normal attempts.
- Official Homework score: highest valid completed score, waiting only for an Attempt that could still overtake it (§14.3).
- Blitz: exactly 1 normal attempt.
- Official Blitz score: the checked valid normal attempt #1; an approved exception invalidates #1 and withdraws its official score, and replacement #2 becomes official once it is checked (§14.4, §14.5).

Architecture:

- `HomeworkAttemptPolicy`
- `OfficialTaskScoreResolver` with `OfficialScoreEvaluator` (Homework rule), reads through `OfficialScoreReader`
- `BlitzAttemptPolicy`
- `OfficialTaskScoreResolver` with `OfficialScoreEvaluator` (Blitz rules), reads through `OfficialScoreReader`

---

## DEC-02 — Technical Attempt Exception

**Approved**

- Teacher may grant exactly 1 additional Blitz attempt to one Student.
- Valid technical or other approved reason is required.
- Original interrupted/invalid attempt remains in history.
- Original affected attempt is excluded from official scoring under the exception.
- Stage 9 later uses the eligible valid replacement as the potential official Blitz score source; the grant withdraws an existing official Blitz score, and until the replacement is checked there is no official Blitz score (§14.5).
- No task-wide attempt increase.

New grants require active Blitz, existing terminal or canonically timeout-reconciled #1, no earlier exception/#2 and the §14.5 authorization/reason rules. Pre-deadline editable #1 and draft/scheduled/closed/archived reject; Teacher Close permanently blocks new grants. An elapsed synchronized end alone does not block a valid active grant. Granting preserves #1 and creates no #2.

Architecture:

- `GrantBlitzAttemptException`
- `BlitzAttemptExceptionPolicy`
- explicit history/eligibility metadata
- Teacher authorization and reason persistence

---

## DEC-03 — Blitz Timer Start Mode

**Approved**

Institution setting:

```text
synchronized | individual
```

Teacher configures whole-Blitz duration.

- Activation freezes `timer_start_mode_snapshot`; later Institution changes cannot affect it.
- Synchronized normal #1: `deadline_at = synchronized_ends_at = activated_at + duration_seconds`.
- Individual normal #1: `deadline_at = started_at + duration_seconds`.
- Replacement #2 in either mode: `deadline_at = started_at + duration_seconds`, preserving the class-wide window.
- Execution timing uses the canonical UTC whole-second policy in §15.2.

No per-question timer in the MVP.

Architecture:

- `BlitzTimerPolicy`
- institution timer mode
- task duration
- authoritative server timestamps

---

## DEC-04 — Blitz Timeout Behavior

**Approved**

At timeout:

- stop Student edits
- auto-finalize saved answers
- persist `timed_out_finalized + timeout_auto_submit` at exact `deadline_at`
- keep saved answers pending without checking/scoring or fabricated answer rows
- Stage 9 later applies unanswered zero, objective checking, manual review and scoring
- late writes are rejected

Architecture:

- `FinalizeTimedOutBlitzAttempt`
- idempotent timeout reconciliation
- authoritative backend deadline

---

## DEC-05 — Partial Credit

**Approved**

- Single-choice: all-or-nothing
- True/false: all-or-nothing
- Multiple-choice: selection cap equals correct-option count; fraction of correctly selected options / total correct options
- Matching: fraction of correct pairs
- Ordering: fraction of correctly positioned items
- Fill-in-the-blank: fraction of correct blanks, compared with the short-answer normalization
- Short written: automatic all-or-nothing normalized match with `checking_mode = automatic`, Teacher review with `checking_mode = manual`; only short written can be switched to manual checking
- Open written/file-based: Teacher-assigned points

Architecture:

- typed question checkers
- `PartialCreditPolicy`
- backend-authoritative point calculation

---

## DEC-06 — Score Precision / Rounding

**Approved**

- Calculate with exact decimals; no binary floating point.
- Store Question awarded points and Attempt normalized scores rounded half-up to 8 decimal places (§16.6); calculations never round these stored values again.
- Official selection, threshold comparison and final calculation use the stored scores without further rounding.
- The exact final score is stored and serialized half-up to 8 decimal places (`S10-T5`).
- Understanding category uses the integer `category_score` derived from the exact final score.
- User-facing scores display one decimal place.

Architecture:

- `ScorePrecisionPolicy`
- sufficient database numeric precision
- API/UI presentation rule

---

## DEC-07 — Result Release

**Approved**

Student modes:

```text
automatic
manual_teacher
```

Parent modes:

```text
with_student
manual_teacher
hidden
```

Parent visibility never precedes Student visibility.

Stage 10 refines the release (`S10-D3`…`S10-D6`): values become visible only once the Student's work is finished (the official Blitz is closed or archived and the official Homework can no longer be submitted); a manual release also unlocks the official Attempt results; a released result is never hidden again; mode changes act immediately while Teacher releases stay; `hidden` gives the Parent no result information.

Architecture:

- `ResultReleasePolicy`
- visibility derived at read time from the current modes, the visibility window and stored Teacher release facts (§18.6)
- explicit Teacher release actions where required, single Student and bulk (§19)

---

## DEC-08 — Upload Limits

**Approved**

Platform hard maximums:

```text
learning material: 25 MB/file
Student submission: 15 MB/file
```

Institution may configure lower limits only.

Architecture:

- backend authoritative validation
- optional Flutter pre-check
- effective limit = min(platform hard maximum, institution configured limit)

---

## DEC-09 — Timezone

**Approved**

- Store authoritative timestamps as UTC instants.
- Each institution has one IANA timezone.
- `Asia/Tashkent` is the natural default for Uzbekistan institutions.
- Educational dates/deadlines are entered and displayed in institution local time.
- Backend converts/validates against authoritative UTC instants.
- Device clock/timezone cannot change deadlines.
- Changing institution timezone does not change already stored absolute instants.

Architecture:

- backend `Clock`
- institution timezone setting
- explicit local-time parsing/conversion boundary

---

## DEC-10 — Result-Bearing Task Pair

**Approved**

- A Topic may contain multiple Homework tasks and multiple Blitz tasks.
- Exactly one whole-group Homework and exactly one whole-group Blitz are designated as the official result-bearing pair; selected-Student tasks are practice-only.
- The designated pair is used for the Topic result.
- The designated Homework and Blitz must belong to the same Topic.
- The official Homework may be designated before the official Blitz exists. First official-task activation establishes the persisted cohort, and the later official task reuses it. Student activity locks the already-designated task/cohort; one-time completion of the absent Blitz side is not replacement.
- One Student + one Topic produces one final Topic result in the MVP.

Architecture:

- Topic-level designated Homework/Blitz relationships
- result engine consumes only the designated pair
- lifecycle guard for designation changes

---

# 25. Configuration Architecture

Separate configuration into three levels.

## 25.1 Platform Configuration

Examples:

- Environment
- API URL
- Storage driver
- **Hard learning-material limit: 25 MB/file**
- **Hard Student-submission limit: 15 MB/file**
- Logging
- Security configuration
- Default institution timezone seed/config where appropriate

Platform hard limits are technical/business safety ceilings and cannot be increased by Institution Admins.

---

## 25.2 Institution Business Settings

Institution business settings include:

- Acceptable Homework–Blitz difference threshold
- Inclusive integer understanding-category ranges
- Blitz timer-start mode: `synchronized | individual`
- Student result-release mode: `automatic | manual_teacher`
- Parent result-release mode: `with_student | manual_teacher | hidden`
- Institution IANA timezone
- Learning-material upload limit
- Student-submission upload limit

On institution creation, only safe operational values are initialized automatically: `timezone = Asia/Tashkent`, learning-material limit = 25 MB, Student-submission limit = 15 MB. Threshold, Blitz timer-start mode, Student release mode, and Parent visibility mode remain unconfigured until Institution Admin selection. Numeric understanding-category ranges also have no silent default; the Institution Admin must save one complete valid integer range set before a Topic result can be `calculated`. Missing policy values block only the dependent operation.

Stage 10 use of these settings (`S10-D6`, `S10-T4`):

- A result whose two official scores are ready while the threshold or a valid complete category set is missing has status `waiting_for_settings`; it is never Not completed.
- Every open result uses the current threshold and category ranges on its next read; a closed result never changes. The settings endpoints keep their contracts.
- A release-mode change acts on every result immediately; Teacher releases already made stay. No per-result rule or mode snapshot exists before closure.
- An unconfigured Student release mode shows no result values; an unconfigured Parent mode gives the Parent no result information, as `hidden` does (§18.6).

These values belong to institution data, not environment variables. The institution does **not** configure arbitrary Homework or Blitz attempt counts in the MVP.

---

## 25.3 Task-Specific Settings

Approved task-specific settings include:

- Homework deadline
- Blitz whole-task duration
- Group or selected Students for practice assessments
- Question points
- Official result-bearing designation only for whole-group assessments

Task-specific settings must never bypass platform security, institution ownership, fixed attempt rules, or institution-level timer/release policies.

---

# 26. Time Architecture

Use a backend time abstraction/service for all authoritative business time.

Conceptual service:

```text
Clock
  nowUtc()
```

Use it for:

- Homework deadlines
- Blitz activation
- Individual Blitz attempt start
- Blitz timeout
- Submission time
- Result timestamps
- Visibility release timestamps
- Attempt-exception timestamps
- Audit/history timestamps

This improves deterministic testing.

---

## 26.1 UTC Storage

Authoritative instants must be stored/handled as UTC.

Examples:

```text
deadline_at
activated_at
attempt_started_at
ends_at
submitted_at
student_released_at
parent_released_at
closed_at
```

Exact database types belong in `08-database.md`.

---

## 26.2 Institution Timezone

Each institution has one IANA timezone identifier.

Examples:

```text
Asia/Tashkent
Asia/Almaty
Europe/London
America/New_York
```

For Uzbekistan institutions, `Asia/Tashkent` is the natural default.

Teachers enter educational dates/times in the institution timezone. The backend interprets them in that timezone and converts them to authoritative UTC instants.

Flutter displays educational scheduling in the institution timezone so Teacher and Students see the same classroom/deadline interpretation.

Device clock/timezone is never authoritative.

---

## 26.3 Timezone Changes

Changing the institution timezone must not alter previously stored absolute instants.

The same historical deadline/activation/submission instant remains fixed in UTC.

A timezone change affects how the instant is presented and how future local date/time input is interpreted.

---

# 27. File Architecture

## 27.1 File Separation

Store file metadata in the relational database.

Store file bytes in file storage.

Do not store large document bytes directly in ordinary domain table columns.

---

## 27.2 Authorized Download Flow

Conceptual flow:

```text
Authenticated user
  ↓
Request file by record id
  ↓
Backend resolves file metadata
  ↓
Check institution
  ↓
Check role
  ↓
Check topic/task/student relationship
  ↓
Return protected file response / signed access
```

Exact delivery method belongs in deployment/API design.

Stage 9 Teacher access to submitted files (`S09-T5`): the protected download also authorizes a Teacher for a `student_submission` File whose answer belongs to a submission the Teacher may review (§16.9 access). Files of `in_progress` Attempts stay Student-only. Everything else stays a privacy-safe `404 resource_not_found`.

---

## 27.3 File Naming

Do not rely on original client filename as the physical storage key.

Preserve original filename as metadata for display.

Use server-generated storage identifiers/paths.

---

## 27.4 Upload Limit Enforcement

Effective upload limits are:

```text
learning_material_limit =
min(25 MB, institution_learning_material_limit if configured)

student_submission_limit =
min(15 MB, institution_student_submission_limit if configured)
```

Rules:

- Laravel performs authoritative validation.
- Flutter should show the effective limit and may reject an obviously oversized file before upload.
- Failed, unsupported, or oversized uploads must not create a valid material/submission attachment.
- Reverse proxy/web-server upload limits must be configured high enough to permit valid platform requests while still respecting backend rules.

---

# 28. Reporting Architecture

MVP reports are query/read models, not a separate analytics system.

Use optimized server-side queries for:

- Platform summaries
- Institution summaries
- Group progress
- Topic progress
- Student progress
- Parent child progress

Do not duplicate authoritative result formulas inside report code.

Reports read Topic results through the same `TopicResultEngine`: the live computation for open results and the closure snapshot for closed results (§17.1, §17.6).

---

## 28.1 Report Authorization

Filtering must be applied after/with scope enforcement.

Unsafe:

```text
Teacher sends group_id
server trusts group_id
```

Required:

```text
Teacher sends group_id
server verifies teacher-group assignment
server queries allowed group data
```

---

## 28.2 Advanced Analytics

Out of MVP:

- Prediction
- AI recommendations
- Cross-institution benchmarking
- Teacher-performance analytics
- Data warehouse
- BI pipeline

The MVP should not introduce a separate analytics database unless later usage justifies it.

---

# 29. Error Handling Architecture

Use consistent error classes across backend and Flutter.

Conceptual backend categories:

```text
Validation
Unauthenticated
Forbidden
NotFoundWithinScope
BusinessConflict
ServerError
```

Flutter should map API failures into stable application failures rather than displaying raw server exceptions.

---

## 29.1 Privacy-Aware Errors

Do not reveal whether an unauthorized private record exists.

Example:

Instead of:

```text
Student 842 belongs to Institution B.
```

return a generic scope-safe error.

---

# 30. Logging Architecture

Backend logs should help diagnose failures without exposing sensitive educational content unnecessarily.

Log useful metadata such as:

- Request correlation ID where implemented
- Authenticated user ID
- Institution ID
- Action
- Record identifiers
- Error category

Avoid logging:

- Passwords
- Authentication tokens
- Full private Student answers by default
- Raw sensitive uploaded file contents

---

# 31. Audit Boundary

Advanced audit-reporting UI is outside the MVP.

However, normal persisted business records must retain enough ownership/timestamp information for traceability.

Examples:

- Who created Topic
- Who created Homework
- Who activated Blitz
- Which Student submitted or timed out on an Attempt
- Which Teacher granted a Blitz attempt exception and the recorded reason
- Which Teacher last reviewed a manual answer, and when (`checked_by_user_id`, `checked_at`; no review history table in the MVP)
- Which designated Homework/Blitz pair produced a closed Result (closure snapshot, §17.6)
- Which timer-start mode/duration governed a Blitz
- Which rules produced a closed Result (threshold and category range in the closure snapshot)
- Which Teacher released or closed a Topic result, and when; who last changed the Teacher comment, and when

Whether a separate full `audit_logs` domain is needed in MVP should be decided during `08-database.md` based on required traceability.

---

# 32. Testing Architecture

Testing is part of architecture, not a final cleanup step.

## 32.1 Backend Unit Tests

Use for deterministic domain logic:

- Score normalization
- Question checking
- Approved partial-credit behavior including Multiple-choice selection cap
- Fixed Homework attempt policy
- Blitz attempt policy and exception policy
- Blitz timer/deadline resolution
- Blitz timeout finalization
- Official Homework/Blitz score resolvers
- Result engine
- Category-score conversion and category resolver boundary tests
- State transitions
- Score precision/display policy
- Result release policy

---

## 32.2 Backend Feature Tests

Use for:

- Authentication
- Authorization
- API validation
- Institution isolation
- Group scoping
- Parent-child scoping
- Task lifecycle
- Submission lifecycle
- Official result-bearing pair locking
- File authorization and 25 MB / 15 MB limits
- Manual review
- Student-specific Blitz attempt exception
- Timeout auto-finalization
- Result visibility/release modes
- Upload-limit enforcement
- Institution-timezone conversion
- Reports

---

## 32.3 Cross-Institution Negative Tests

For every institution-owned feature, include at least one test showing that a user from another institution cannot access or mutate the record.

This is a mandatory architecture rule.

---

## 32.4 Flutter Unit Tests

Use for:

- DTO mapping
- Repository failure mapping
- View-state logic
- Timer presentation logic for synchronized/individual modes
- One-decimal score presentation
- Role routing logic
- Institution-timezone display formatting

Do not duplicate backend result-formula authority in Flutter tests.

---

## 32.5 Flutter Widget Tests

Use for important states:

- Loading
- Error
- Empty
- Permission denied
- Form validation
- Submission in progress
- Timer display
- Result visibility

---

## 32.6 Integration / Smoke Tests

Each roadmap stage should have a real end-to-end smoke path.

Stage 13 must test the complete Teacher → Student → Blitz → Result → Parent workflow.

---

# 33. Concurrency and Integrity

Some workflows may receive competing requests.

Examples:

- Double submit
- Double Blitz activation
- Double Student attempt start
- Two requests granting the same Blitz exception
- Timeout finalization racing with explicit Student submit
- Two Teacher review saves
- Topic result read while review, checking or a lifecycle change commits
- Homework attempt start at deadline boundary
- Result-bearing designation/cohort lock while an attempt starts
- Teacher task close racing with Student answer/save/submit
- Result close racing with manual review, automatic checking, the sweep, a Student Start, an exception grant, or a deadline/timeout finalizer
- Official Blitz activation closing the official Homework while Students save, submit or start Homework Attempts

Use:

- Database transactions
- Unique constraints
- State precondition checks
- Row locking where needed
- Idempotency/duplicate guards where appropriate

Exact implementation belongs in database/API contracts.

For Homework, transactions acquire deterministic relevant row locks, then re-read lifecycle, authoritative time, assignment/ownership, and Attempt editability. Submit, deadline reconciliation/Scheduler, and Teacher close may yield exactly one transition from `in_progress`; the first valid semantic event preserves its reason/timestamps and later reconciliation is a no-op. At a reached deadline, `homework_deadline_auto_submit` with the exact deadline instant wins. Answer/file write versus freeze has only two outcomes: the mutation commits before freeze and is included, or freeze commits first and the mutation makes zero answer/file-domain changes. Application locking remains mandatory even where partial uniqueness protects the one-`in_progress` invariant.

Blitz uses its own lifecycle policy with the same transaction, deterministic-lock, locked re-read and authoritative-time re-check requirements. Only `in_progress` may transition; at/equal/after the effective Attempt deadline, timeout reason and exact deadline win over close/late Submit. Close and its required finalizations commit atomically. Start, official pair lock, exception grant and finalization cannot race into duplicate Attempts, two in-progress Attempts, redefined cohort or rewritten terminal history. File replacement rejected after freeze cannot change persisted file identity/content.

Stage 9 scoring writers (automatic checking, the sweep, review save, correction and exception grant) all take the §16.7 lock order. Two writers for one Student and Assessment therefore never decide the official score concurrently, concurrent review saves keep the last committed value per answer, and checking acts only on `submitted`/`timed_out_finalized` Attempts, so a duplicate run is a no-op.

Stage 10 resolves the result races with the §17.9 lock order (`S10-T6`): Teacher result actions take group → Teacher membership → Topic `FOR UPDATE` first and so serialize with scoring, Starts and exception grants; closure also locks the affected official Attempts `FOR SHARE` in one global Attempt-id order, so it serializes with the deadline and timeout finalizers and evaluates terminal state, finished work and the snapshot from one consistent view. A result read computes inside one `REPEATABLE READ READ ONLY` snapshot and never sees a half-committed change. The official Blitz activation closes the official Homework under the Homework Assessment, Homework and Attempt locks its cohort step already takes, in no other order (`S10-D8`, §15.1); every other writer of these Attempts takes the Topic first or locks the Homework Assessment first, so no lock cycle exists and the Homework write-versus-freeze rules above apply unchanged. Close and release are idempotent by state, so a duplicate request changes nothing.

---

# 34. Performance Architecture

The MVP should optimize correctness first but avoid obvious scaling traps.

Use:

- Pagination
- Indexed foreign keys
- Indexed institution ownership
- Indexed common filter/status fields
- Eager loading where appropriate
- Aggregate queries for dashboards
- Avoid N+1 query patterns
- Avoid loading full answer/file history for summary lists

Exact indexes belong in `08-database.md`.

---

# 35. Security Architecture

## 35.1 Transport

Production API traffic must use HTTPS.

---

## 35.2 Passwords

Passwords must use Laravel-supported secure hashing.

Never store plaintext passwords.

---

## 35.3 Tokens

Authentication tokens must not be written to application logs.

Flutter must store sensitive credentials/tokens using secure platform storage.

---

## 35.4 Server-Side Authorization

Every protected read/write must be authorized on the server.

---

## 35.5 File Security

Uploaded files are private.

The server controls retrieval.

---

## 35.6 Mass Assignment

Do not accept client-controlled ownership fields blindly.

Examples that must be server-derived/validated:

- Institution ownership
- Student ownership
- Teacher ownership
- Group relationship
- Result calculation fields
- Official score
- Understanding category

---

## 35.7 Client Trust Boundary

Never trust the Flutter client to authoritatively provide:

- User role
- Institution scope
- Official score
- Final score
- Category
- Permission
- Submission owner
- Timer validity
- Timer-start mode
- Extra-attempt eligibility
- Result visibility eligibility

These must be server-derived or server-validated.

---

# 36. Deployment Architecture

MVP should support separate environments:

```text
local
testing
staging
production
```

At minimum:

- Local development should be reproducible.
- Testing should use isolated test data.
- Staging should be safe for end-to-end verification.
- Production credentials/storage/database must be isolated.

Do not reuse production secrets in source control.

---

## 36.1 Backend Deployment Units

Conceptually:

- Laravel application
- Relational database
- Private file storage
- Web server/runtime
- Laravel Scheduler/cron for authoritative Homework-deadline and Blitz-timeout reconciliation and the Stage 9 every-minute checking sweep (§16.5)
- Optional queue worker only if a later approved feature needs asynchronous job processing; Stage 9 checking uses no queue

MVP core workflows should not require a complex distributed platform.

---

## 36.2 Checking and Scoring Operations (Stage 9)

Deploying Stage 9 requires:

- **Migration.** Run `2026_09_29_000000_create_stage_9_scoring_persistence_foundation`. It creates `official_task_scores` and adds `homework_assignments.review_due_at`; its `down` drops both.
- **Dependencies.** Run `composer install`: `brick/math` and `symfony/polyfill-intl-normalizer` are direct dependencies of `backend/composer.json` (§16.6). The PHP runtime needs `mbstring` (`MB_CASE_FOLD`); `bcmath` is not needed.
- **Scheduler.** The Laravel Scheduler must run every minute on exactly one host; the schedule does not use `onOneServer`. `routes/console.php` schedules `homework:reconcile-deadlines`, `blitz:reconcile-timeouts` and `attempts:check-frozen`, each `everyMinute()->withoutOverlapping(5)`. Without the Scheduler a failed checking run is never retried and history frozen before Stage 9 is never checked.
- **No scheduler in the repository Compose file.** In `docker/docker-compose.yml` the `app` service runs only `php artisan serve`, next to `postgres`; there is no scheduler service. A deployment must add one. This gap predates Stage 9.
- **No queue worker.** Checking runs in a terminating callback after the response (§16.5), not in a queue. On a SAPI without early response flush this adds latency to the freezing request, never content.
- **First run over existing history (PH2-2).** When the database holds unchecked Stage 7/8 history, run `php artisan attempts:check-frozen` once to completion before enabling the schedule, because `withoutOverlapping(5)` lets a long first run overlap the next one after 5 minutes.
- **Databases between S09-BE-003B and S09-BE-004 (PH2-5).** A database that ran `d324716` (S09-BE-003B) without `da53031` (S09-BE-004) may hold Students whose official score was never resolved. The repair step of `attempts:check-frozen` (§16.5) resolves those with no pending eligible Attempt; any other is resolved by the next checking run, review save or correction of that Student's Attempts.
- **Known deployments.** No production database exists yet. The local demo database (`testlabuz_demo`) is the only known deployment, and it is a demo.

---

## 36.3 Topic Result Operations (Stage 10)

Deploying Stage 10 requires:

- **Migration.** One migration creates `topic_results` and adds the `attempt_answers` check `feedback is null or feedback <> ''` (`CL9-11`); its rollback drops both.
- **Routes.** The new `parent` route group (one Parent result read, §18.6).
- **No Scheduler entry, queue or backfill.** Open Topic results are computed live (`S10-T1`), so existing history needs no data step; the Stage 9 Scheduler entries (§36.2) are unchanged.

---

# 37. Database Migration Rules

All schema changes must use version-controlled migrations.

Do not manually change production schema as the normal workflow.

Migrations should:

- Preserve existing data
- Add constraints safely
- Avoid destructive changes without explicit review
- Be tested against representative data when risky

Exact schema is defined in `08-database.md`.

---

# 38. Seed and Demo Data Architecture

Provide controlled development/demo seed data.

Recommended seed scenario:

```text
Platform Owner
Institution A
Institution B

Institution A:
- Institution Admin
- 2 Teachers
- 2 Groups
- Multiple Students
- Parent with connected child/children
- Topics
- Homework
- Blitz
- Different result cases

Institution B:
- Separate users/groups
```

Use this to verify tenant separation.

Include examples for:

- Consistent result
- Inconsistent result
- Waiting for review
- Not completed
- Homework with 3 attempts where the highest score is official
- Blitz with normal single attempt
- Blitz with approved technical exception and replacement attempt
- Synchronized Blitz timer example
- Individual Blitz timer example
- Timeout auto-finalization with unanswered questions
- Partial-credit examples
- Automatic Student release
- Manual Student release
- Parent `with_student`, `manual_teacher`, and `hidden` visibility examples
- Parent with multiple children
- Teacher assigned to multiple groups

Do not use real sensitive Student data in development/demo seeders.

---

# 39. CI and Quality Gates

Every merge/stage closure should run appropriate automated quality checks.

Backend:

- Tests
- Static analysis if configured
- Formatting/style checks if configured

Flutter:

- `flutter analyze`
- Formatting check
- `flutter test`

Integration:

- Critical API/client tests
- Stage smoke checklist

A failed required check blocks stage closure.

---

# 40. Codex Architecture Rules

Codex should receive only the technical context needed for the current task.

A task should reference:

- This architecture
- Relevant business rules
- Relevant API/database contract sections
- Relevant stage
- Exact files
- Acceptance criteria
- Tests
- Explicit non-goals

Codex must not:

- Invent new architecture patterns inside one task
- Change unrelated modules
- Bypass tenant scoping
- Move business logic into Flutter
- Change approved business rules
- Introduce a new package without need/review
- Refactor unrelated code during a focused task

---

# 41. Architecture Change Rules

If a technical decision changes:

1. Update this file.
2. Identify affected database sections.
3. Identify affected API sections.
4. Identify affected roadmap stages.
5. Update relevant `AGENTS.md`.
6. Update tests.
7. Create a focused migration/refactor task.
8. Reverify affected completed stages.

The codebase must not become the only place where architecture decisions exist.

---

# 42. Explicit MVP Non-Architecture

Do not architect production subsystems for features excluded from MVP unless they are needed as harmless extension points.

Do not build now:

- AI service layer
- Video pipeline
- Audio processing
- Chat service
- Notification microservice
- Billing service
- Data warehouse
- Recommendation engine
- Anti-cheating device monitoring
- Offline synchronization engine
- Complex custom-role engine
- External LMS integration bus

Extension points are acceptable.

Unused infrastructure is not.

---

# 43. Architecture Decision Summary

## Adopted Baseline

- Laravel backend
- Flutter frontend
- REST/JSON API
- Modular monolith
- Relational database
- Recommended PostgreSQL baseline
- Private file storage abstraction
- Shared application/shared-schema multi-institution model
- Backend-authoritative business rules
- Explicit institution scoping
- Fixed five-role MVP
- Feature-first Flutter architecture
- Recommended Riverpod + GoRouter + Dio baseline
- Separate task/submission/result/visibility state models
- First-class attempt history
- Dedicated `TopicResultEngine`
- Deterministic 0–100 comparison
- Live open Topic results and frozen closure snapshots
- Vertical stage-based delivery

## Approved Decision-Dependent Architecture

- Homework: Stage 7 executes/finalizes exactly 3 normal attempts; Stage 9 later selects the highest valid completed score as official, waiting only for an Attempt that could still overtake it
- Blitz: 1 normal attempt; one Student-specific Teacher-approved exception attempt
- Institution Blitz timer mode: synchronized or individual
- Teacher-configured whole-Blitz duration
- Server-authoritative timeout auto-finalization
- Approved partial-credit rules with Multiple-choice selection cap
- Exact decimal calculations with one half-up 8-decimal storage rounding of awarded points and normalized scores, and of the exact final score; one-decimal user display; integer category-score conversion
- Institution-configured Student/Parent release modes
- 25 MB learning-material and 15 MB Student-submission hard limits
- UTC authoritative timestamps + institution IANA timezone
- Multiple tasks per Topic with exactly one whole-group official Homework/Blitz pair and one snapshotted official cohort

The original ten architecture-affecting MVP business decisions and all post-audit clarifications are resolved. The final read-only cross-document consistency audit passed; this architecture is locked for MVP implementation.

Post-audit architecture also fixes mandatory first-login password gating, incomplete institution-setting prerequisites, activation `total_possible_points > 0`, deterministic automatic Short Written normalization, earliest-attempt Homework tie-breaking, task-close auto-finalization, result-closure preconditions, idempotent institution lifecycle commands, and required idempotency headers for the five high-risk client mutations. Stage 7 locks the Homework execution/freeze boundary; Stage 8 locks the Blitz execution/finalization boundary. Stage 9 later owns checking/scoring for both, triggered right after each freeze commits (§16.5).

---

# 43A. Homework Deadline Finalization Architecture

The `AttemptService` owns one authoritative reusable transition such as `FinalizeHomeworkAttemptsAtDeadline`. It is invoked for relevant Student Homework/Attempt reads, Attempt Start, typed/file answer mutation, final Submit, Teacher close when the deadline may have passed, and Laravel Scheduler. Every write independently enforces `server_now < deadline_at`; device time and Scheduler latency never extend eligibility.

At `server_now >= deadline_at`, the action creates no Attempt for a never-started Student, makes unused capacity unavailable, and transitions only existing `in_progress` Homework Attempts from their already-committed saved state. It neither fabricates unanswered answer rows nor performs Stage 9 checking/scoring; Stage 9 checks the frozen Attempts after the reconciliation transaction commits (§16.5).

The finalization metadata is:

```text
status = submitted
submitted_at = null
finalized_at = exact homework_assignments.deadline_at
finalization_reason = homework_deadline_auto_submit
locked_at = exact homework_assignments.deadline_at
```

Transactions lock relevant Homework/Attempt rows deterministically, re-read state and authoritative time, transition only from `in_progress`, and preserve an already committed finalization reason/timestamps. A Student Submit validly committed before deadline remains `student_submit`; when the deadline is reached under the lock, `homework_deadline_auto_submit` wins; a valid pre-deadline Teacher close committed first remains `task_closed_auto_finalize`. Repeated reconciliation performs no write after finalization.

The same lock boundary serializes answer/file mutation versus finalization: a mutation committed first is included in frozen history, while finalization committed first makes the later mutation return the lifecycle/deadline/editability conflict with zero answer/file-domain mutation. A late idempotency-protected Start/Submit must allow required deadline reconciliation to commit while returning its failure and leaving no new completed or incomplete claim, as defined in Section 23.4.

---

# 44. Architecture Definition of Done

`07-architecture.md` can be treated as **decision-resolved and ready for downstream contract synchronization** when:

1. Laravel + Flutter baseline is approved.
2. Relational database engine is approved.
3. Multi-institution shared-schema model is approved.
4. Authentication method is approved.
5. Flutter state/network/router baseline is approved.
6. All ten business decisions are represented as fixed architecture rules.
7. Domain module boundaries are accepted.
8. Attempt, timer, scoring, release, and timezone policies match `05-business-rules.md`.
9. Status separation is accepted.
10. File-storage and file-limit models are accepted.
11. Testing and security rules are accepted.
12. No architecture rule contradicts `05-business-rules.md` or `06-roadmap.md`.
13. `08-database.md` can be synchronized without inventing business behavior.
14. `09-api-contracts.md` can be synchronized without inventing business behavior.

The previous business decision gates are resolved, `08-database.md` and `09-api-contracts.md` are synchronized, and the full `01–09` cross-document audit has passed. This architecture is locked for MVP implementation.

---

# 45. Next Technical Documents

After this decision-resolved architecture update:

```text
08-database.md
```

should define:

- Tables
- Columns
- Foreign keys
- Join tables
- Enums
- Constraints
- Indexes
- Soft-delete/archive strategy
- Institution ownership fields
- Attempt/submission structures
- Result snapshots

Then:

```text
09-api-contracts.md
```

should define:

- Endpoints
- HTTP methods
- Request bodies
- Response bodies
- Pagination
- Validation errors
- Authorization errors
- Business-conflict errors
- File upload/download contracts
- Attempt contracts
- Blitz timing contracts
- Result/release contracts

`08-database.md` and `09-api-contracts.md` are synchronized and the final cross-document consistency audit has passed. Roadmap stages may now be decomposed into precise Codex implementation tasks.

---

# Final Architecture Principle

> **TestLabUz should be implemented as a Laravel modular monolith with a Flutter client, with the backend serving as the authoritative source for institution scope, permissions, task state, scoring, and final learning results. Every learning record must remain inside the correct institution and relationship scope, and every result must remain explainable from preserved homework, blitz, rule, and attempt data.**
