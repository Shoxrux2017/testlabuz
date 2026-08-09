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
- Keep calculation values unrounded.
- Calculate the absolute difference.
- Use the institution threshold.
- Apply the approved average-or-blitz formula.
- Derive integer `category_score` from the final internal score and assign the understanding category from that value.
- Save the calculation method and rule snapshot.
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
- ActivateBlitz
- StartBlitzAttempt
- SubmitBlitzAttempt
- FinalizeTimedOutBlitzAttempt
- FinalizeAttemptsOnTaskClose
- GrantBlitzAttemptException
- ReviewSubmission
- ResolveOfficialHomeworkScore
- ResolveOfficialBlitzScore
- CalculateTopicResult
- CloseTopicResult
- ReleaseStudentTopicResult
- ReleaseParentTopicResult

Each action should have one clear business purpose.

### Domain Layer

Responsible for reusable rules such as:

- Institution scope validation
- Task lifecycle transitions
- Fixed Homework/Blitz attempt availability
- Student-specific Blitz attempt exceptions
- Blitz timing mode/deadline resolution
- Blitz timeout finalization
- Question checking and approved partial credit
- Score normalization
- Official Homework/Blitz score resolution
- Homework–blitz comparison
- Category-score derivation and understanding-category resolution
- Result closure
- Student/Parent release policy

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
- Submit attempt + answers + file references + status
- Manual review + score update + task score
- Official score update + topic result recalculation
- Final result calculation + rule snapshot

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
- ManualReviewIncomplete
- ResultAlreadyClosed

`09-api-contracts.md` will map these to stable API responses.

---

# 8. Multi-Institution Architecture

## 8.1 Recommended Tenancy Model

Use a **shared application + shared database schema + institution-owned rows** model for the MVP.

Every institution-level record must either:

- Store `institution_id` directly, or
- Have an unambiguous parent relationship that resolves to exactly one institution.

For high-risk records such as users, groups, topics, tasks, attempts, submissions, files, and results, direct institution ownership is preferred where it improves safe querying and constraints.

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

The designated pair is Topic-level for the MVP. Both official tasks must use `assignment_mode = group`; selected-Student assessments are practice-only and are ineligible for official designation. The pair uses one common official Topic cohort. Normally, when the first designated task becomes active, the backend snapshots the current eligible Topic-group Students and creates/reuses that same recipient snapshot for both official assessments. If a whole-group candidate is already active when it is designated and no Student Attempt has begun, pair designation treats that candidate's existing recipient snapshot as the official cohort and copies/validates the same cohort for the paired task. If existing candidate recipient snapshots conflict, designation is rejected until a safe consistent pair can be selected. Later Group membership changes do not mutate the cohort. Once Student attempt activity begins, the pair and cohort are locked.

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

Open written and file-based types return/manual-route rather than automatic judgment in the MVP.

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

Award partial credit per correctly matched pair:

```text
fraction = correct_pairs / total_pairs
question_points_awarded = question_max_points * fraction
```

### Ordering

Award partial credit per item placed in its correct position:

```text
fraction = correctly_positioned_items / total_items
question_points_awarded = question_max_points * fraction
```

### Fill-in-the-blank

Award partial credit per correctly completed blank:

```text
fraction = correct_blanks / total_blanks
question_points_awarded = question_max_points * fraction
```

### Short written answer

- Automatic all-or-nothing checking may be used when accepted-answer rules are defined.
- Automatic mode uses deterministic normalized exact matching. Both Student text and accepted answers pass the same pipeline: Unicode NFC normalization, trim, collapse consecutive whitespace, Unicode case-fold comparison, and normalization of common Uzbek apostrophe variants. Other punctuation and technical symbols remain significant.
- Fuzzy matching, spell correction, synonym inference, and AI interpretation are not part of the MVP.
- Otherwise route to Teacher review.

### Open written and file-based

- Manual Teacher scoring within the configured maximum points.

The backend is authoritative for all awarded points.

---

# 14. Attempt and Submission Architecture

## 14.1 Attempt Is a First-Class Record

Every Student try must be its own immutable historical attempt after finalization/submission.

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
- Calculate next attempt number.
- Start attempt.
- Lock/finalize attempt.
- Determine whether another attempt is permitted.
- Preserve attempt history.
- Expose whether an attempt is eligible for official scoring.

The service must not accept a client-provided arbitrary attempt limit.

---

## 14.3 Homework Attempt Policy

Homework has exactly **3 normal attempts per Student**.

Use a dedicated policy/resolver boundary such as:

```text
HomeworkAttemptPolicy
OfficialHomeworkScoreResolver
```

Rules:

- Normal attempt numbers are 1, 2, and 3.
- A fourth normal Homework attempt is not permitted.
- Each attempt is stored independently.
- A submitted attempt is immutable to the Student.
- The official Homework score is the **highest valid completed score** among eligible Homework attempts. If several attempts tie exactly for that highest normalized score, the attempt with the lowest `attempt_number` is the official attempt reference.
- An attempt requiring Teacher review is not fully scored until review is complete.
- Whenever a later eligible attempt produces a higher score before result closure, the official Homework score and any open dependent Topic result must be recalculated through the normal domain workflow.
- The Teacher does not manually select the official Homework attempt and does not override the fixed attempt count.

---

## 14.4 Blitz Attempt Policy

Blitz has exactly **1 normal attempt per Student**.

Use a dedicated policy/resolver boundary such as:

```text
BlitzAttemptPolicy
OfficialBlitzScoreResolver
```

Rules:

- The normal Blitz attempt is attempt #1.
- Under normal conditions, no second attempt is available.
- The valid completed normal attempt is the official Blitz score source after required checking is complete.
- The client cannot request or create an extra attempt by itself.

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

Exact database field names/status codes belong in `08-database.md`; the architecture requires preserved history, explicit eligibility/exclusion, actor, reason, and timestamp.

---

## 14.6 Submission Locking and Task-Close Finalization

After explicit final submission, authoritative Blitz timeout, or Teacher task-close auto-finalization:

- Student answer data becomes immutable for that attempt.
- Teacher may review/score but must not rewrite Student answers.
- A new attempt is possible only when the task is still active and the fixed Homework policy or approved Blitz exception allows it.

When an authorized Teacher closes active Homework or Blitz, the backend must atomically stop new starts/writes and finalize every existing `in_progress` attempt using saved answers. Unanswered components receive zero; manual-review answers remain pending review. Students who never started receive no fabricated Attempt. The finalization reason is `task_closed_auto_finalize`.

---

## 14.7 Official Score Boundary

Before Topic comparison, exactly one official score must exist for each designated result-bearing task:

```text
Official Homework score
Official Blitz score
```

The `TopicResultEngine` must consume these official score records/resolutions rather than selecting arbitrary attempt data itself.

---

# 15. Blitz Timing Architecture

Blitz timing is authoritative on the backend.

The Flutter countdown is a presentation of server-defined timing state. Device clock or timezone changes must never extend a Blitz.

The Teacher configures one **whole-Blitz duration** for the task. Per-question timers are not part of the MVP.

---

## 15.1 Institution Timer-Start Mode

Each institution has exactly one configured Blitz timer-start mode:

```text
synchronized
individual
```

Use a policy boundary such as:

```text
BlitzTimerPolicy
```

The policy reads the institution setting and resolves the authoritative deadline.

### Synchronized mode

When the Teacher activates the Blitz:

```text
activated_at = server_now
ends_at = activated_at + duration
```

All assigned Students share the same deadline.

A Student who opens the Blitz later receives only the remaining time.

### Individual mode

Teacher activation makes the Blitz available but does not start every Student's countdown.

When one Student starts the attempt:

```text
attempt.started_at = server_now
attempt.ends_at = attempt.started_at + blitz.duration
```

Each Student receives the full configured duration.

The task may still be closed by the Teacher according to lifecycle rules; closing blocks new Student starts and further writes as defined by the API contract.

---

## 15.2 Authoritative Timing Data

The backend must expose enough timing data for Flutter to render a stable countdown.

Conceptually, Student Blitz state may include:

```text
timer_start_mode
duration_seconds
activated_at
started_at
ends_at
server_now
remaining_seconds
```

Not every field must be persisted if it can be derived safely; exact database/API representation belongs in `08-database.md` and `09-api-contracts.md`.

---

## 15.3 Timeout Finalization

Timeout behavior is fixed:

> **At the authoritative deadline, the Student's saved Blitz work is finalized automatically.**

Use an idempotent domain/application action:

```text
FinalizeTimedOutBlitzAttempt
```

Rules:

- Reject answer writes received after the authoritative deadline.
- Lock the attempt against further Student edits.
- Preserve answers saved before the deadline.
- Treat unanswered questions as zero points.
- Automatically check objective answers.
- Keep answered questions requiring Teacher judgment in `waiting_for_teacher_review`.
- Do not mark an answered manual-review item incorrect merely because review is pending.
- Produce the official Blitz score only after all required manual review is complete.

The backend should reconcile timeout state whenever a timed Blitz is accessed or mutated. A scheduler may invoke the same idempotent finalization action where operationally useful, but correctness must not depend on trusting the client countdown.

---

## 15.4 Monitoring

Teacher monitoring should use authoritative server state.

It may display:

- Assigned Student
- Not started / in progress / submitted / timed out
- Started timestamp
- Remaining time or effective deadline
- Attempt number
- Review state
- Technical exception state

Monitoring must never allow the Teacher to answer on behalf of the Student.

---

# 16. Scoring Architecture

Scoring has three layers.

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

Each scored question contributes points according to its question-type checking logic.

---

## 16.2 Task Score

Task score combines all scored question points.

If required manual review remains:

```text
Task score = pending
```

Do not treat a partial auto-score as the final official task score.

---

## 16.3 Score Normalization

Before homework/blitz comparison:

```text
Normalized Score = 0–100
```

The normalization algorithm should be deterministic.

Example conceptual formula:

```text
normalized = earned_points / total_possible_points * 100
```

Draft assessments may temporarily have `total_possible_points = 0` during authoring. Immediately before Homework or Blitz activation, the backend recalculates total points from current Questions and requires `total_possible_points > 0`; a zero-point assessment cannot become active. Normalization is executed only with a positive denominator.

Do not round before threshold comparison or final-score calculation. Category assignment uses the separate integer category-score conversion defined below.

---

## 16.4 Official Task Scores

Exactly one official 0–100 score is resolved for each designated result-bearing task:

### Homework

```text
official_homework_score =
highest valid completed score among up to 3 normal Homework attempts
```

### Blitz

```text
official_blitz_score =
valid completed normal Blitz attempt
or
valid completed Teacher-approved exception attempt when an exception replaces the interrupted/invalid normal attempt
```

These official scores are the only task scores consumed by the `TopicResultEngine`.

Official-score resolution must preserve the source attempt reference and scoring eligibility history.

---

# 17. Topic Result Engine

Create a dedicated backend domain service:

```text
TopicResultEngine
```

It must be the authoritative implementation of final topic result calculation.

---

## 17.1 Inputs

Conceptual input:

```text
student
topic
designated_homework
designated_blitz
official_homework_score
official_blitz_score
institution_threshold
institution_category_ranges
rule_snapshot
```

---

## 17.2 Comparison

All values in the comparison use **unrounded internal precision**.

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
method = average
```

If:

```text
D > T
```

then:

```text
final_score = B
consistency = inconsistent
method = blitz
```

---

## 17.3 Missing Work

If required homework/blitz work has not produced an official score:

- Do not invent a numeric final score.
- Determine correct waiting/not-completed state.
- Preserve which component is missing.

---

## 17.4 Manual Review

If one required task still requires Teacher review:

```text
result_status = waiting_for_teacher_review
```

Do not calculate the final numeric result yet.

---

## 17.5 Category Resolver

Use a separate domain component:

```text
UnderstandingCategoryResolver
```

Responsibilities:

- Derive integer `category_score` from the final internal score: fractional part `.0` through `.5` rounds down; fractional part greater than `.5` rounds up.
- Validate institution ranges as inclusive integer bands.
- Ensure every integer 0–100 is covered exactly once.
- Prevent gaps and overlaps.
- Resolve exactly one numeric category from `category_score`.
- Keep Not completed separate from numeric categories.

---

## 17.6 Result Snapshot

Every calculated/closed result must retain the business inputs necessary to explain it later.

At minimum:

- Homework score
- Blitz score
- Difference
- Threshold used
- Calculation method
- Final score
- Consistency
- Category
- Category/range snapshot
- Official attempt references
- Calculation timestamp/version where required

Changing institution settings must not silently rewrite closed historical results.

---

## 17.7 Score Precision and Display Policy

Use an explicit component such as:

```text
ScorePrecisionPolicy
```

Approved behavior:

- Preserve sufficient decimal precision for question, task, official-score, difference, and final-result calculations.
- Do **not** round Homework or Blitz scores before `D = abs(H - B)`.
- Do **not** alter the authoritative final internal score for calculation history. Derive a separate integer `category_score` only for category resolution using `.0`–`.5` down and `>.5` up.
- User-facing numeric scores are displayed with **one decimal place** using standard mathematical rounding.
- API/database contracts must distinguish authoritative stored/calculation precision from presentation formatting.
- Reports must use the same display policy while aggregations remain based on authoritative values.

---

## 17.8 Result Closure Policy

Use an explicit domain policy/action boundary such as:

```text
TopicResultClosurePolicy
CloseTopicResult
```

A Student+Topic result may close only from a terminal educational state:

1. `calculated`, with both official scores present, all required manual review complete, no relevant in-progress official attempt, and no approved replacement Blitz attempt still pending; or
2. definitive `not_completed`, after required work can no longer validly be completed.

Waiting states cannot close. Closure is per Student+Topic and does not require class-wide Homework/Blitz closure. Result release is independent and may occur before or after closure according to institution policy. After closure, manual score correction, additional Blitz exception grant, official pair/cohort changes, official-score replacement, recalculation, final score, consistency, and category are immutable in the MVP.

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

`timed_out_finalized` is an architectural concept, not necessarily the final persisted enum name. It means the authoritative Blitz deadline ended, saved work was finalized, and the attempt is no longer editable. It must not be treated as an unsubmitted `expired` attempt.

For an approved technical Blitz exception, the original affected attempt additionally needs explicit scoring-eligibility/exclusion metadata and a link/reason context sufficient for history.

Exact persistence representation belongs in `08-database.md`.

---

## 18.5 Topic Result Status

```text
waiting_for_homework
waiting_for_blitz
waiting_for_teacher_review
calculated
not_completed
closed
```

---

## 18.6 Result Visibility

Visibility is independent from result calculation status.

The architecture must support institution-level release configuration and separate Student/Parent visibility state.

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

At persistence level, the system should be able to determine at least:

```text
student_visible_at
parent_visible_at
```

or equivalent visibility state.

A Parent result must never become visible before the Student result is visible.

Exact schema belongs in `08-database.md`.

---

# 19. Result Release Architecture

Result calculation and result release are separate capabilities.

Use explicit release orchestration such as:

```text
ResultReleasePolicy
ReleaseStudentTopicResult
ReleaseParentTopicResult
```

Release must not recalculate or change:

- Homework score
- Blitz score
- Difference
- Final score
- Category
- Consistency

It changes visibility only.

---

## 19.1 Student Release

Institution setting:

```text
student_result_release_mode =
automatic | manual_teacher
```

### Automatic

When the Topic result reaches `calculated` and all required review is complete:

```text
student_visible_at = server_now
```

or equivalent visibility state is applied automatically.

### Manual Teacher release

The result may be fully calculated while hidden from the Student.

An authorized Teacher explicitly releases it.

The Teacher may release only results inside the Teacher's assigned scope.

---

## 19.2 Parent Release

Institution setting:

```text
parent_result_release_mode =
with_student | manual_teacher | hidden
```

### With Student

When the Student result becomes visible, the connected Parent result becomes visible automatically.

### Manual Teacher release

The Parent remains unable to see the result after Student release until an authorized Teacher explicitly releases Parent visibility.

Parent release must be rejected while the Student result is still hidden.

### Hidden

No Parent result visibility is created for the Topic result.

---

## 19.3 Release Invariants

- Parent visibility can never precede Student visibility.
- Releasing/hiding access does not alter calculation state.
- Release actions must be idempotent.
- Parent access still requires an active Parent–Student relationship and normal authorization.
- Institution setting changes must not silently mutate already closed historical result calculations; exact visibility migration behavior belongs in the API/database contract.

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
- Manual checking
- Detailed results
- Reports

---

## 22.4 Teacher Mobile

Quick classroom/monitoring surface:

- Assigned groups
- Topic status
- Homework status
- Blitz activation
- Blitz monitoring
- Student-specific Blitz exception grant where authorized
- Basic result review
- Student/Parent release actions where institution policy requires Teacher action

Do not attempt to reproduce every desktop authoring feature in the MVP mobile UI.

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
- Feedback where allowed

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
- Blitz attempt-exception eligibility
- Deadline validity
- Blitz availability
- Blitz effective deadline / timeout
- Official Homework/Blitz score
- Result formula
- Category
- Result status
- Student/Parent visibility eligibility

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

A safe retry with the same key/request identity returns the same logical result. Other concurrent mutations such as manual review and result calculation use transactional state/version guards; they do not invent a second public idempotency contract unless `09-api-contracts.md` explicitly adds one.

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
- Official Homework score: highest valid completed score.
- Blitz: exactly 1 normal attempt.
- Official Blitz score: the valid completed Blitz attempt, except when an approved exception replaces an interrupted/invalid normal attempt.

Architecture:

- `HomeworkAttemptPolicy`
- `OfficialHomeworkScoreResolver`
- `BlitzAttemptPolicy`
- `OfficialBlitzScoreResolver`

---

## DEC-02 — Technical Attempt Exception

**Approved**

- Teacher may grant exactly 1 additional Blitz attempt to one Student.
- Valid technical or other approved reason is required.
- Original interrupted/invalid attempt remains in history.
- Original affected attempt is excluded from official scoring under the exception.
- Extra valid attempt becomes the official Blitz score source.
- No task-wide attempt increase.

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

- Synchronized: `ends_at = activated_at + duration`
- Individual: `attempt.ends_at = attempt.started_at + duration`

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
- unanswered questions = zero
- evaluate saved objective answers normally
- answered manual-review questions remain waiting for Teacher review
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
- Fill-in-the-blank: fraction of correct blanks
- Short written: auto all-or-nothing when accepted-answer rules permit, otherwise Teacher review
- Open written/file-based: Teacher-assigned points

Architecture:

- typed question checkers
- `PartialCreditPolicy`
- backend-authoritative point calculation

---

## DEC-06 — Score Precision / Rounding

**Approved**

- Store/calculate with unrounded precision.
- Threshold comparison uses unrounded values.
- Final calculation uses unrounded values.
- Understanding category uses the derived integer `category_score`.
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

Architecture:

- `ResultReleasePolicy`
- separate Student/Parent visibility state
- explicit Teacher release actions where required

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
- The official cohort is snapshotted on first official-task activation, reused for both tasks, and the pair/cohort must not be replaced after Student attempt activity begins.
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

On institution creation, only safe operational values are initialized automatically: `timezone = Asia/Tashkent`, learning-material limit = 25 MB, Student-submission limit = 15 MB. Threshold, Blitz timer-start mode, Student release mode, and Parent visibility mode remain unconfigured until Institution Admin selection. Numeric understanding-category ranges also have no silent default; the Institution Admin must save one complete valid integer range set before Topic result calculation can finish. Missing policy values block only the dependent operation.

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
student_visible_at
parent_visible_at
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

Reports should read already-calculated domain state where possible.

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
- Which Teacher reviewed a manual answer
- Which designated Homework/Blitz pair produced the Result
- Which timer-start mode/duration governed a Blitz
- Which rules produced the Result

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
- Result calculation while review changes
- Homework attempt start at deadline boundary
- Result-bearing designation/cohort lock while an attempt starts
- Teacher task close racing with Student answer/save/submit
- Result close racing with manual review or exception grant

Use:

- Database transactions
- Unique constraints
- State precondition checks
- Row locking where needed
- Idempotency/duplicate guards where appropriate

Exact implementation belongs in database/API contracts.

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
- Laravel Scheduler/cron for authoritative Homework-deadline and Blitz-timeout reconciliation
- Optional queue worker only if a later approved feature needs asynchronous job processing

MVP core workflows should not require a complex distributed platform.

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
- Historical result rule snapshots
- Vertical stage-based delivery

## Approved Decision-Dependent Architecture

- Homework: exactly 3 normal attempts; highest valid completed score is official
- Blitz: 1 normal attempt; one Student-specific Teacher-approved exception attempt
- Institution Blitz timer mode: synchronized or individual
- Teacher-configured whole-Blitz duration
- Server-authoritative timeout auto-finalization
- Approved partial-credit rules with Multiple-choice selection cap
- Unrounded internal calculations; one-decimal user display; integer category-score conversion
- Institution-configured Student/Parent release modes
- 25 MB learning-material and 15 MB Student-submission hard limits
- UTC authoritative timestamps + institution IANA timezone
- Multiple tasks per Topic with exactly one whole-group official Homework/Blitz pair and one snapshotted official cohort

The original ten architecture-affecting MVP business decisions and all post-audit clarifications are resolved. The final read-only cross-document consistency audit passed; this architecture is locked for MVP implementation.

Post-audit architecture also fixes mandatory first-login password gating, incomplete institution-setting prerequisites, activation `total_possible_points > 0`, deterministic automatic Short Written normalization, earliest-attempt Homework tie-breaking, task-close auto-finalization, result-closure preconditions, idempotent institution lifecycle commands, and required idempotency headers for the five high-risk client mutations.

---

# 43A. Homework Deadline Finalization Architecture

The `AttemptService` owns the authoritative Homework deadline transition. When backend time reaches a Homework deadline, it must atomically prevent new attempts and further Student answer writes, identify existing `in_progress` Homework Attempts, and finalize each from its saved answer state. Unanswered components receive zero, automatic components are checked normally, and answered manual-review components enter the normal review pipeline. No Attempt is fabricated for a Student who never started, and unused normal-attempt capacity is no longer available after the deadline.

Use one idempotent application action such as `FinalizeHomeworkAttemptsAtDeadline`. The backend invokes/reconciles this action when expired Homework/Attempts are accessed or mutated, and the Laravel Scheduler invokes the same action server-side so finalization does not depend on Student/Teacher traffic. Exact write eligibility is always checked against authoritative server time, so scheduler execution latency can never extend the deadline.

The finalization metadata is:

```text
finalized_at = authoritative Homework deadline/reconciliation instant
finalization_reason = homework_deadline_auto_submit
locked_at = finalized_at
```

`submitted_at` remains null for this path because the Student did not explicitly submit. The Attempt may then be `checked` or `waiting_for_teacher_review` according to checking readiness. Concurrency/state-precondition logic must ensure a Student submit arriving at the deadline boundary and the deadline finalizer cannot both finalize the Attempt; exactly one terminal transition wins, safe retries are idempotent, and later incompatible writes return the appropriate locked/late conflict.

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
