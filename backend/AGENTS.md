# TestLabUz Backend — Codex Instructions

## Scope

This file applies to `backend/`.

It supplements the root `AGENTS.md`.

If this file and the root file appear to conflict, follow the stricter rule unless that would contradict the locked `docs/01–09`. Product behavior is always controlled by the locked specifications.

---

# 1. Backend Baseline

Use the architecture defined in `docs/07-architecture.md`:

```text
Laravel REST API
PostgreSQL
Laravel Sanctum
Modular monolith
Private file storage through Laravel filesystem abstraction
```

The backend is authoritative for all business state and security decisions.

Do not move authoritative business logic to Flutter.

---

# 2. Recommended Backend Layering

Use the established responsibility flow:

```text
HTTP Layer
  ↓
Application / Action Layer
  ↓
Domain Rules / Services
  ↓
Persistence / Infrastructure
```

Recommended logical areas:

```text
app/
  Actions/
  Domain/
  Enums/
  Exceptions/
  Http/
    Controllers/Api/V1/
    Middleware/
    Requests/
    Resources/
  Models/
  Policies/
  Services/
  Support/
```

Create directories only when needed by an implemented feature. Do not generate empty architecture for future stages.

---

# 3. Controllers

Controllers must stay thin.

A controller should normally:

1. Receive already validated request data.
2. Resolve authenticated context.
3. Authorize/call one application action.
4. Return a Resource/contract response.

Do not implement complex rules directly in controllers, including:

- Tenant filtering
- Attempt policies
- Timer/deadline rules
- Question scoring
- Official-score selection
- Topic-result calculation
- Category assignment
- File authorization
- Complex lifecycle transitions

---

# 4. Request Validation vs Business Rules

Use Form Requests for request-shape validation:

- Required fields
- Types
- Formats
- UUID syntax
- Allowed enum values
- Simple numeric ranges
- File type/size preconditions

Use Actions/Domain services for stateful business rules:

- User/Institution active state
- Teacher assignment
- Student eligibility
- Parent-child relationship
- Task lifecycle
- Attempt availability
- Deadline/timer authority
- Result closure
- Release policy
- Historical protection

Do not duplicate the same rule in many controllers.

---

# 5. PostgreSQL Rules

Follow `docs/08-database.md`.

Key rules:

- Domain primary keys use UUIDs.
- Stored instants use PostgreSQL `timestamptz`.
- Business statuses use constrained `varchar + CHECK` unless the locked DB contract says otherwise.
- High-risk institution-owned tables carry direct `institution_id`.
- Foreign keys and indexes must follow the locked schema.
- Historical domain relationships default to restrictive deletion.
- Use migrations for every schema change.
- Do not manually mutate production schema as normal workflow.
- Do not add PostgreSQL RLS unless the architecture is explicitly revised; Laravel authorization is the MVP authority.

Do not change a table/column/constraint from `08-database.md` simply because another shape appears easier.

---

# 6. Tenant Scoping

Every institution-owned query must start from trusted authenticated scope.

Unsafe:

```text
Model::find($id)
then trust the record
```

Required concept:

```text
resolve authenticated scope
→ query within institution
→ authorize role/relationship
→ apply lifecycle/business rule
→ read/write
```

Never trust request `institution_id` as ownership authority.

For high-risk creates, derive ownership from:

- Authenticated user
- Authorized parent resource
- Explicit platform-level path/resource

Cross-institution relationship creation must be rejected transactionally.

---

# 7. Authorization

Use Policies and/or focused authorization services consistently.

Apply all relevant checks:

- Authentication
- Active user
- Active institution
- Role capability
- Institution ownership
- Teacher-group relationship
- Student assignment
- Parent-child relationship
- Record lifecycle
- Deadline/time
- Attempts
- View vs edit

Do not treat navigation visibility as security.

When disclosure of resource existence would leak private data, use the scope-safe API behavior required by `09-api-contracts.md`.

---

# 8. Authentication and Password Gate

Use Laravel Sanctum as defined in the locked architecture/API contract.

Administrator-created Institution Admin/Teacher/Student/Parent accounts must require first-login password change.

While:

```text
must_change_password = true
```

normal protected application actions must be blocked except the approved authentication/password-change path.

Do not let a valid token bypass this gate.

---

# 9. Institution Initialization

New Institution safe operational initialization must follow the locked contract:

- Timezone: `Asia/Tashkent`
- Learning-material maximum: 25 MB/file
- Student-submission maximum: 15 MB/file

Institutions may configure lower file limits only.

Do not invent educational-policy defaults for required Institution Admin settings such as:

- Acceptable score-difference threshold
- Blitz timer-start mode
- Student/Parent result release modes
- Numeric understanding-category ranges

Dependent operations must return the documented validation/business conflict until configuration is complete.

---

# 10. Transactions

Use database transactions for multi-record business actions.

Examples:

- Create/update Assessment + Questions + type configuration
- Snapshot official cohort
- Start Attempt
- Finalize/submit Attempt + Answers + checking state
- Manual review + Attempt score update
- Official-score selection
- Blitz exception grant
- Result calculation + snapshots
- Result closure
- Release mutation where required

A partial write must not leave invalid educational state.

---

# 11. Attempt Rules

## Homework

- Exactly 3 normal attempts.
- No Homework exception.
- Every Attempt is a first-class historical record.
- Official score = highest valid completed normalized score.
- Equal highest-score tie → lowest `attempt_number`.

## Blitz

- Exactly 1 normal attempt.
- Exactly 1 additional Student-specific Teacher-approved exception may be granted.
- Valid reason is required.
- Original interrupted/invalid Attempt remains historical.
- Original affected Attempt is ineligible for official score.
- Valid replacement Attempt becomes official source.
- No task-wide limit increase.

Centralize these policies. Do not scatter attempt-number logic through controllers.

---

# 12. Attempt Concurrency

Starting an Attempt must be atomic.

Protect the unique:

```text
assessment_id + student_id + attempt_number
```

Use transaction/locking/state guards so concurrent requests cannot create duplicate Attempt numbers.

Required Idempotency-Key behavior must also be honored.

---

# 13. Required Public Idempotency Contract

Exactly these five client mutations require:

```http
Idempotency-Key: <client-generated-uuid>
```

1. Start Homework Attempt
2. Start Blitz Attempt
3. Final Attempt Submit
4. Blitz Activate
5. Blitz attempt exception grant

Contract:

- Missing key → `422 validation_failed`
- Same key + same request identity → same logical result
- Same key + materially different request → `409 idempotency_key_reused`

Do not add this public requirement to manual review/result calculation/release unless `09-api-contracts.md` is explicitly revised.

Institution activate/deactivate endpoints are idempotent by state.

---

# 14. Homework Deadline Finalization

Homework deadline is backend-authoritative.

At the authoritative deadline:

1. Block new Attempts.
2. Block further Student writes.
3. Finalize every existing `in_progress` Homework Attempt from saved answers.
4. Score unanswered components as zero.
5. Evaluate saved objective answers normally.
6. Leave answered manual-review Questions pending Teacher review.
7. Set:
   ```text
   finalization_reason = homework_deadline_auto_submit
   ```
8. Keep:
   ```text
   submitted_at = null
   ```
9. Set server:
   ```text
   finalized_at
   ```
10. Do not create Attempt rows for never-started Students.
11. Remove unused remaining Homework attempt availability.
12. After checking completes, keep the finalized Attempt eligible for the standard highest-valid-completed official Homework score resolver.

Laravel Scheduler and request-time reconciliation must call the same idempotent finalization action.

Scheduler delay must not extend Student write eligibility.

At the deadline boundary, exactly one terminal transition must win between Student explicit submit and server finalization.

---

# 15. Teacher Task-Close Finalization

Closing active Homework or Blitz must auto-finalize existing `in_progress` Attempts from saved answers.

Use:

```text
finalization_reason = task_closed_auto_finalize
```

- Unanswered components = zero.
- Saved answers are evaluated normally.
- Manual-review answers remain pending review.
- Never-started Students get no fabricated Attempt.
- Later Student writes are blocked.

Implement task close and finalization transactionally/idempotently.

---

# 16. Blitz Timing

There is one whole-Blitz timer, never a per-question timer.

Institution setting:

```text
synchronized
individual
```

Teacher sets whole-Blitz duration.

## Synchronized

Authoritative end is based on Teacher activation.

## Individual

Authoritative end is based on each Student Attempt start after activation.

Persist/return server-authoritative timing as defined in database/API contracts.

Never trust client device time to authorize writes.

---

# 17. Blitz Timeout

At authoritative timeout:

- Reject later Student edits.
- Auto-finalize saved answers.
- Unanswered components = zero.
- Score saved objective answers normally.
- Keep answered manual-review Questions pending Teacher review.

Timeout reconciliation must be idempotent.

A later explicit submit must not create another logical submission.

---

# 18. Question Checking

Use typed checking services/strategies.

Do not implement one uncontrolled generic JSON scoring function.

Locked rules:

### Single-choice

```text
all-or-nothing
```

### True/false

```text
all-or-nothing
```

### Multiple-choice

- Selection cap = correct-option count.
- Awarded fraction = correctly selected / total correct.

### Matching

```text
correct pairs / total pairs
```

### Ordering

```text
correctly positioned items / total items
```

### Fill-in-the-blank

```text
correct blanks / total blanks
```

### Short Written Automatic

Exact normalized matching only:

- Unicode normalize
- Trim
- Collapse whitespace
- Case-insensitive
- Normalize Uzbek apostrophe variants
- Preserve punctuation
- No fuzzy matching
- No AI

### Short Written Manual / Open Written / File-Based

Teacher review assigns points within allowed Question points.

---

# 19. Assessment Activation

Draft Assessment may temporarily have zero scoreable points.

Before Homework/Blitz activation:

1. Recalculate server-side total possible points.
2. Require:
   ```text
   total_possible_points > 0
   ```
3. Validate every Question-type configuration.
4. Validate assignment/cohort rules.
5. Validate required Institution educational configuration.

Do not trust a client-supplied total-points value.

---

# 20. Official Pair and Cohort

A Topic may have many tasks.

Only one whole-group Homework and one whole-group Blitz are the designated result-bearing pair.

Selected-Student tasks are practice-only.

The official cohort:

- Is snapshotted on first official-task activation.
- Is reused by both designated tasks.
- Must not be silently regenerated from later Group membership.
- Must not be replaced with the pair after Student attempt activity begins.

Result calculation consumes only the designated pair.

---

# 21. Scoring and Result Engine

Centralize final calculation in the backend.

Do not calculate final Topic result in controllers, Resources, or reports.

Use unrounded precision for:

- Question points where applicable
- Attempt/task normalized score
- Official task score
- Homework–Blitz difference
- Threshold comparison
- Final score

User-facing display is one decimal.

Understanding category uses integer `category_score`:

- Fraction `.0`–`.5` → down
- Fraction `>.5` → up

Result formula is fixed by root `AGENTS.md` and `05-business-rules.md`.

Do not allow client-supplied:

- Official Homework score
- Official Blitz score
- Difference
- Final score
- Calculation method
- Consistency
- Category
- Result status

---

# 22. Manual Review

Teacher may update only review metadata/score fields allowed by the contract.

Teacher must not rewrite Student answer content.

If any required manual review remains:

- Attempt official score is not ready.
- Topic final numeric result is not ready.

Manual corrections before Result closure must recalculate dependent Attempt/official/result state transactionally.

Closed Topic Result blocks normal review corrections that would alter the result.

---

# 23. Result Closure

A Student+Topic Result can close only if terminal:

- Fully calculated with both official scores, all manual review complete, and no relevant in-progress/pending replacement Attempt; or
- Definitively `not_completed`.

Waiting states cannot close.

After closure:

- Scoring changes blocked.
- Exception grant blocked.
- Pair/cohort change blocked.
- Recalculation blocked.

Release/visibility remains separate as specified.

---

# 24. Result Release

Use the locked Institution policies:

Student:

```text
automatic
manual_teacher
```

Parent:

```text
with_student
manual_teacher
hidden
```

Parent must never become visible before Student.

Release action changes visibility only, never scoring/calculation state.

---

# 25. Files

Use Laravel filesystem abstraction.

Files are private by default.

Supported MVP types:

```text
pdf
docx
ppt
pptx
```

Platform hard maxima:

- Learning material: 25 MB/file
- Student submission: 15 MB/file

Institution may configure lower limits.

Effective limit:

```text
min(platform maximum, institution configured limit)
```

Persist metadata in PostgreSQL and bytes in private storage.

Do not use the original filename as the physical storage key.

Protected download must authorize the connected Topic/Assessment/Student relationship.

---

# 26. API Response Contract

Follow `docs/09-api-contracts.md` exactly.

Do not invent endpoint-specific envelope shapes.

Expected categories:

- `200/201` resource response
- `204` when contract says no content
- `401` unauthenticated
- `403` authorization/account/institution state where specified
- `404` scope-safe not found
- `409` business conflict
- `422` validation
- `429` rate limit
- `500` generic server failure

Stable machine-readable error `code` is part of the contract.

Do not expose stack traces, SQL details, tokens, or private record existence.

---

# 27. Reports

Reports are read/query models.

Do not reimplement Topic-result formulas in report queries.

Prefer reading persisted calculated result state.

Every report filter remains institution/role scoped.

A filter must not reveal data the requester cannot open directly.

---

# 28. Logging

Useful metadata may include:

- Request/correlation ID when configured
- Authenticated user ID
- Institution ID
- Action
- Record IDs
- Error category

Do not log:

- Passwords
- Tokens
- Full private Student answers by default
- Raw uploaded file contents

---

# 29. Tests

Backend unit tests should cover deterministic domain logic such as:

- Question checking
- Short Written normalization
- Homework official-score resolver
- Blitz exception policy
- Timer policy
- Deadline/timeout/task-close finalizers
- Score normalization
- Category-score conversion
- TopicResultEngine
- Release policy
- State transitions

Feature tests should cover:

- Auth/password gate
- API validation
- Authorization
- Cross-institution denial
- Group/Parent relationships
- Task lifecycle
- Attempt lifecycle
- File authorization
- Manual review
- Result visibility
- Reports
- Required Idempotency-Key behavior
- Concurrency-sensitive transitions

For every institution-owned feature, add at least one cross-institution negative test.

---

# 30. Clean Code and Backend Quality Rules

These rules supplement the root Clean Code rules.

## 30.1 Focused Actions and Services

Each Action should represent one clear application use case.

Prefer focused names such as:

```text
StartHomeworkAttempt
FinalizeHomeworkAtDeadline
GrantBlitzAttemptException
CalculateTopicResult
ReleaseTopicResult
```

over broad services such as `AssessmentManager`, `SchoolService`, or `GeneralLearningService` that accumulate unrelated responsibilities.

Domain services may coordinate several technical steps when those steps form one business operation.

## 30.2 Repositories and Queries

Do not create repository abstractions mechanically around every Eloquent model.

Introduce a dedicated query/repository/service abstraction when it provides a real boundary, for example complex reusable scoped queries, domain-specific persistence behavior, multi-write domain persistence, or a testable infrastructure boundary.

Avoid both extremes: Controllers directly owning every query and repository interfaces for every trivial CRUD operation.

## 30.3 Eloquent Scope Safety

Tenant scoping must remain explicit and testable enough that reviewers can verify it.

When creating reusable scopes/query objects, name them according to the access rule, avoid a generic normal-use “without scope” escape hatch, and test cross-Institution denial.

## 30.4 Domain Constants and Enums

Stable machine values such as roles, statuses, finalization reasons, calculation methods, consistency values, and error codes should use focused enums/constants/value objects according to the established Laravel pattern.

Do not repeat raw strings across Controllers/services/tests when one shared domain representation is appropriate. Do not create one giant unrelated constants file.

## 30.5 Database Query Quality

Avoid obvious N+1 query patterns and unnecessary large eager-loaded graphs.

Select/eager-load only the data needed by the use case, use indexes defined in `08-database.md`, and use server-side filtering/sorting/pagination/aggregates for lists and reports.

Performance optimization must never weaken tenant scoping or correctness.

## 30.6 Validation Reuse

Extract reusable validation rules only when the same rule genuinely applies in multiple requests.

Do not copy-paste complex validation/business conditions between Form Requests. Do not move stateful business authorization into generic validators merely to reuse code.

## 30.7 Exception Quality

Use specific expected domain/application exceptions or result types.

Avoid generic known-condition handling such as:

```php
throw new Exception('Something went wrong');
```

Known conditions must map predictably to the stable API error contract.

## 30.8 Test Readability

Tests are production-quality code too.

Prefer descriptive behavior names such as:

```text
teacher_cannot_access_topic_from_another_institution
homework_deadline_finalizes_in_progress_attempt
highest_score_uses_earliest_attempt_when_tied
```

Avoid vague names such as `test1`, `works`, or `topic_test`.

Avoid giant tests that validate unrelated behaviors. Use focused factories/builders/helpers when they improve readability without hiding important scope/state setup.

---

# 31. Backend Completion Checklist

Before completing a backend task:

- [ ] Controller remains thin.
- [ ] Names are specific and domain-aligned.
- [ ] Actions/services have focused responsibilities.
- [ ] Shared domain rules are not duplicated.
- [ ] Stable machine values use the established enum/constant pattern.
- [ ] Query shape avoids obvious N+1 and unnecessary loading.
- [ ] Request validation is separated from business rules.
- [ ] Institution scope is derived server-side.
- [ ] Authorization covers role + relationship + lifecycle.
- [ ] Multi-record writes use appropriate transaction/state guards.
- [ ] Historical records are preserved.
- [ ] Locked attempt/timing/scoring/release rules are unchanged.
- [ ] Required idempotency/concurrency rules are implemented.
- [ ] API envelope/error codes match `09-api-contracts.md`.
- [ ] Database shape/constraints match `08-database.md`.
- [ ] Unit/feature tests cover the change.
- [ ] Cross-institution negative test exists where relevant.
- [ ] Backend tests pass.
- [ ] Configured static/style checks pass.
- [ ] No unrelated refactor or package addition was introduced.

---

# Final Backend Rule

> Laravel is the authoritative enforcement layer. Every write and protected read must remain tenant-safe, state-safe, deterministic, historically traceable, and compliant with the locked database/API/business contracts.
