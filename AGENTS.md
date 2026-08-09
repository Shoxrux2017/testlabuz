# TestLabUz — Codex Project Instructions

## Scope

This file applies to the entire TestLabUz repository.

More specific instructions may exist in:

- `backend/AGENTS.md`
- `frontend/AGENTS.md`

A nested `AGENTS.md` may add implementation-specific rules for its directory, but it must not override the locked MVP product behavior in `docs/01–09`.

---

# 1. Project Status

The TestLabUz MVP specification set is **LOCKED FOR MVP IMPLEMENTATION**.

The authoritative specification files are:

```text
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
```

The final cross-document audit passed.

There is no remaining business-decision gate in the locked MVP specification.

Codex must implement the approved behavior. Codex must not reopen, reinterpret, simplify, or replace an approved product decision.

---

# 2. Authority and Conflict Rule

Use the project documents for different kinds of truth:

| File | Primary authority |
|---|---|
| `01-business-overview.md` | Product purpose, business idea, MVP direction |
| `02-user-roles.md` | Roles, role boundaries, device access |
| `03-features.md` | Approved MVP feature scope |
| `04-user-flows.md` | User workflows and state progression |
| `05-business-rules.md` | Business conditions, calculations, restrictions |
| `06-roadmap.md` | Development order, stage scope, Definition of Done |
| `07-architecture.md` | Technical architecture and coding boundaries |
| `08-database.md` | Persistence model, constraints, indexes, historical data |
| `09-api-contracts.md` | Exact Laravel ↔ Flutter API contract |

Task files under `tasks/` define **what to implement now**, not new product behavior.

If a task file conflicts with `docs/01–09`:

1. Do not guess.
2. Do not silently follow the task.
3. Report the conflict.
4. Correct the task/specification first.
5. Only then continue implementation.

If two locked documents appear to conflict, stop the affected implementation slice and report the exact conflicting sections. Do not invent a reconciliation in code.

---

# 3. Working Model

The project uses this division of responsibility:

```text
ChatGPT = architect / product analyst / task planner / reviewer
Codex   = implementation worker
```

Codex should receive and execute one small, precise task at a time.

A roadmap stage is **not** one Codex task.

Each implementation task should contain:

- Goal
- Relevant files
- Requirements
- Relevant business rules
- Acceptance criteria
- Tests
- Explicit non-goals

Do not expand the task beyond its declared scope.

---

# 3A. Git and GitHub Workflow Safety

The detailed task lifecycle and delivery workflow is maintained in
`tasks/README.md` and the reusable templates under `tasks/templates/`.

For implementation tasks after the initial empty-repository baseline:

- start from a clean local `main` synchronized with `origin/main`;
- use one task branch per approved task;
- do not commit or push before the read-only acceptance gate passes;
- deliver accepted work through GitHub PR-based delivery when tooling permits;
- mark a task `Accepted` only after the accepted result is on `origin/main`,
  local `main` matches `origin/main`, and the working tree is clean.

Codex must not force-push, rewrite shared history, bypass Git/GitHub checks,
silently replace an unexpected `origin`, modify global Git configuration, or
commit credentials, tokens, private keys, certificates, or environment secrets.

---

# 4. Required Read Order Before a Task

Before changing code:

1. Read this `AGENTS.md`.
2. Read the nearest nested `AGENTS.md` for the code being changed.
3. Read the current task file.
4. Read only the relevant sections of `docs/01–09`.
5. Inspect the existing implementation and tests before editing.
6. Identify affected permissions, tenant scope, lifecycle state, and regression surface.

Do not load or rewrite unrelated modules merely because they are nearby.

---

# 5. Core Architecture

TestLabUz MVP uses:

```text
Laravel modular monolith backend
+
Flutter frontend
+
PostgreSQL
+
REST/JSON API
```

Backend is authoritative for:

- Authentication
- User role
- Institution scope
- Group / Student / Parent-child access
- Lifecycle state
- Attempt availability
- Homework deadlines
- Blitz timing
- Automatic/manual scoring
- Official task scores
- Topic-result calculation
- Understanding category
- Result closure
- Result visibility eligibility

Flutter displays and submits user intent; it does not become a second business-rule engine.

---

# 6. Non-Negotiable Multi-Institution Rules

TestLabUz is multi-institution from the beginning.

Every institution-level operation must preserve strict tenant isolation.

Never allow a client-provided UUID or `institution_id` to expand access.

For protected operations, apply all relevant checks:

1. Authentication
2. User active state
3. Institution active state
4. Role
5. Institution ownership
6. Group relationship
7. Topic / assessment assignment
8. Teacher ownership or assignment
9. Student ownership
10. Parent-child relationship
11. Lifecycle/status
12. Deadline/time/attempt rules
13. View vs edit permission

Direct URLs, filters, pagination, report queries, and file IDs must not bypass these rules.

A record from another institution must not become visible merely because its UUID is known.

---

# 7. Locked MVP Roles and Device Boundaries

The five MVP roles are:

```text
platform_owner
institution_admin
teacher
student
parent
```

Device model:

- Platform Owner / Super Admin: desktop
- Institution Admin: desktop
- Teacher: desktop + mobile
- Student: desktop + mobile
- Parent: mobile

Do not add custom roles or a permission-builder system in the MVP.

Do not reproduce every desktop authoring feature on mobile unless the locked feature/flow contract requires it.

---

# 8. Locked Assessment Rules

## Homework

- Exactly **3 normal Homework attempts**.
- No extra Homework exception is approved for the MVP.
- Official Homework score = **highest valid completed score**.
- If multiple valid completed attempts tie for the highest score, the attempt with the **lowest `attempt_number`** is the official attempt.
- Submitted/finalized attempts remain historical records; never overwrite earlier attempts.

## Blitz

- Exactly **1 normal Blitz attempt**.
- Teacher may grant exactly **1 additional Student-specific Blitz attempt** for a valid technical or other approved reason.
- Reason is required.
- The original interrupted/invalid attempt remains in history.
- The affected original attempt is excluded from official scoring under the approved exception.
- The extra valid attempt becomes the official Blitz score source.
- No task-wide attempt increase is allowed.

---

# 9. Locked Timing and Finalization Rules

## Blitz timing

Institution timer-start mode is:

```text
synchronized
or
individual
```

Teacher configures one **whole-Blitz duration**.

There is no per-question Blitz timer in the MVP.

Server time is authoritative.

### Synchronized mode

All assigned Students use the Teacher activation window.

### Individual mode

Each Student's attempt timer starts when that Student starts the attempt after activation.

## Blitz timeout

At authoritative timeout:

- Stop Student edits.
- Auto-finalize saved answers.
- Unanswered Questions/components receive zero.
- Saved objective answers are evaluated normally.
- Answered manual-review items remain pending Teacher review.
- Late writes are rejected.

## Homework deadline

At authoritative Homework deadline, every existing `in_progress` Homework Attempt is auto-finalized:

- Stop new attempts and further Student writes.
- Saved answers are evaluated normally.
- Unanswered Questions/components receive zero.
- Manual-review answers remain pending Teacher review.
- `finalization_reason = homework_deadline_auto_submit`.
- `submitted_at` remains `null`.
- `finalized_at` records server finalization.
- Never-started Students receive no fabricated Attempt.
- Unused remaining Homework attempts become unavailable.
- A fully checked auto-finalized Attempt remains eligible for normal highest-valid-completed Homework official-score selection.

Scheduler and request-time reconciliation must use the same idempotent server action. Scheduler latency must never extend the authoritative deadline.

## Teacher task close

Closing active Homework/Blitz auto-finalizes existing in-progress Attempts from saved answers:

```text
finalization_reason = task_closed_auto_finalize
```

Unanswered components receive zero.

Never-started Students receive no fake Attempt.

---

# 10. Locked Question Checking Rules

Supported MVP question types:

1. Single-choice
2. Multiple-choice
3. True / false
4. Short written
5. Open written
6. File-based
7. Matching
8. Ordering
9. Fill-in-the-blank

Scoring:

- Single-choice: all-or-nothing.
- True/false: all-or-nothing.
- Multiple-choice:
  - Student selection cap = number of correct options.
  - Credit = correctly selected options / total correct options.
- Matching: credit = correct pairs / total pairs.
- Ordering: credit = correctly positioned items / total items.
- Fill-in-the-blank: credit = correct blanks / total blanks.
- Automatic Short Written: all-or-nothing exact normalized matching.
- Open written: Teacher-assigned points.
- File-based: Teacher-assigned points.

Automatic Short Written normalization is deterministic only:

- Unicode normalization
- Trim leading/trailing whitespace
- Collapse internal whitespace
- Case-insensitive comparison
- Normalize Uzbek apostrophe variants
- Preserve punctuation
- No fuzzy matching
- No AI matching

Draft assessments may have zero points, but activation requires server-recalculated:

```text
total_possible_points > 0
```

---

# 11. Locked Result Calculation Rules

Before comparison, exactly one official score must exist for the designated Homework and designated Blitz.

Scores use a common 0–100 scale.

Let:

```text
H = official Homework score
B = official Blitz score
D = abs(H - B)
T = institution acceptable score difference
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

The same rule applies even when Blitz is higher than Homework.

An inconsistent result is **not** an automatic cheating accusation.

Do not calculate a numeric final result while required manual review is incomplete or a required official score is missing.

---

# 12. Locked Score Precision and Category Rules

- Store and calculate using unrounded precision.
- Threshold comparison uses unrounded values.
- Final score calculation uses unrounded values.
- User-facing numeric scores display **one decimal place**.
- Understanding-category selection uses a separate integer `category_score`.
- Fractional conversion for `category_score`:
  - fractional part `.0` through `.5` → round down
  - fractional part `>.5` → round up

MVP understanding categories:

```text
understood_well
partially_understood
needs_revision
needs_teacher_support
not_completed
```

The first four use Institution-configured complete/non-overlapping score ranges.

`not_completed` is non-numeric and is used for missing required work after valid completion is no longer possible.

Waiting for Teacher review is not `not_completed`.

An unreleased calculated result is not `not_completed`.

---

# 13. Locked Official Topic Pair and Cohort

A Topic may contain multiple Homework tasks and multiple Blitz tasks.

Exactly:

- **1 whole-group Homework**
- **1 whole-group Blitz**

are designated as the official result-bearing pair.

Selected-Student tasks are practice-only.

The designated Homework and Blitz must belong to the same Topic.

The official cohort is snapshotted on first official-task activation and reused for both designated tasks.

Do not replace the official pair/cohort after Student attempt activity begins.

One Student + one Topic produces one final Topic result in the MVP.

---

# 14. Locked Result Release and Closure Rules

Student release modes:

```text
automatic
manual_teacher
```

Parent release modes:

```text
with_student
manual_teacher
hidden
```

Parent visibility must never precede Student visibility.

Calculation state and visibility state are separate.

Releasing/hiding visibility must not change:

- Homework score
- Blitz score
- Difference
- Final score
- Calculation method
- Consistency
- Understanding category

A Student+Topic result may close only from a terminal state:

- Fully calculated with all required review complete and no relevant in-progress/pending replacement attempt, or
- Definitively `not_completed` because required work can no longer validly be completed.

Waiting states cannot close.

Result closure is Student+Topic-specific and does not require class-wide task closure or Student/Parent release.

After result closure, normal scoring changes, exception grants, pair/cohort changes, and recalculation are blocked.

Visibility remains a separate concern.

---

# 15. Locked Institution Initialization and Configuration

New Institution safe operational initialization includes:

- IANA timezone: `Asia/Tashkent`
- Learning-material hard/effective default maximum: 25 MB/file
- Student-submission hard/effective default maximum: 15 MB/file

Platform hard maximums:

```text
Learning material: 25 MB/file
Student submission: 15 MB/file
```

Institution may configure lower limits only.

Educational policy values must not receive silent invented defaults where the locked specification requires Institution Admin configuration, including relevant:

- Acceptable Homework–Blitz threshold
- Timer-start policy
- Result-release policy
- Numeric understanding-category ranges

Dependent operations must remain blocked until required educational settings are configured.

Changing Institution timezone must not change already stored absolute instants.

---

# 16. Mandatory First-Login Password Change

Accounts created by an administrator for:

- Institution Admin
- Teacher
- Student
- Parent

require mandatory first-login password change.

While:

```text
must_change_password = true
```

the backend blocks normal application actions and allows only the approved authentication/password-change path.

Frontend routing must respect this server state.

---

# 17. API Contract Guardrails

Public client API base:

```text
/api/v1
```

Use the exact success/error/pagination contracts in `docs/09-api-contracts.md`.

Flutter must handle stable machine-readable `code` values and must not parse human-readable messages to decide behavior.

Do not accept client ownership fields as authority.

Do not return answer keys/correct-answer configuration in Student assessment payloads.

Required `Idempotency-Key` mutations:

1. Start Homework Attempt
2. Start Blitz Attempt
3. Final Attempt Submit
4. Blitz Activate
5. Blitz attempt exception grant

Missing required key:

```text
422 validation_failed
```

Same key + same request identity:

```text
return the same logical result
```

Same key + materially different request:

```text
409 idempotency_key_reused
```

Institution activate/deactivate commands are idempotent.

Manual review, result-pair updates, result calculation, and release use documented transactional/state guards and do not require the public Idempotency-Key contract in the MVP.

---

# 18. Historical and File Integrity

Preserve history.

Prefer:

- Activate/deactivate
- End relationship with `ended_at`
- Close/archive
- Immutable finalized/submitted Attempts
- Read-only closed Topic Results

Do not hard-delete historical learning records.

Files are private.

A storage key/path is not authorization.

Every file download must resolve the connected resource and re-check relevant Institution/role/relationship scope.

Do not log raw sensitive Student answer content or authentication tokens by default.

---

# 19. Testing Requirements

Every feature slice must include tests appropriate to its behavior.

At minimum, consider:

- Happy path
- Validation
- Authorization
- Cross-institution denial
- Lifecycle/state conflicts
- Concurrency/idempotency where relevant
- Historical preservation
- Regression coverage for affected locked rules

Cross-institution negative tests are mandatory for institution-owned features.

A failed required test/check blocks stage/task closure.

---

# 20. Quality Gates

Backend:

- Run backend tests.
- Run configured static analysis if present.
- Run configured formatting/style checks if present.

Flutter:

```text
flutter analyze
flutter test
```

Also run the repository-configured formatting check.

Do not invent package/tool commands that are not configured in the repository.

Integration:

- Run relevant API/client integration tests.
- Complete the stage/task smoke checklist.

---

# 21. Change-Control Rule

Codex must not change product behavior while implementing a task.

If behavior must change:

1. Stop the affected implementation.
2. Update the relevant locked `docs/01–09` contract first.
3. Re-run affected consistency checks.
4. Update this or nested `AGENTS.md` if architecture/work rules changed.
5. Update task files.
6. Update implementation/tests.
7. Reverify affected completed stages.

The codebase must never become the only place where a product rule exists.

---

# 22. Scope-Control Rules

Codex must not:

- Invent new architecture patterns inside one task.
- Change unrelated modules.
- Bypass tenant scoping.
- Move backend-authoritative business logic into Flutter.
- Change approved business rules.
- Introduce a new package without a task need/review.
- Refactor unrelated code during a focused task.
- Build Post-MVP infrastructure “for later” unless the current task explicitly requires a harmless extension point.

If an unrelated defect is found, report it separately unless it blocks the current task.

---

# 23. Clean Code and Code Quality Rules

These rules apply to all production code in the repository.

They supplement the architecture rules above and do not replace the locked `docs/01–09`.

## 23.1 Naming

Use descriptive names that communicate purpose and use the terminology already defined in `docs/01–09`.

Prefer names such as:

```text
calculateOfficialHomeworkScore()
eligibleStudents
topicResult
attemptLimit
institutionTimezone
```

Avoid vague or temporary production names such as:

```text
data
temp
value2
manager2
doSomething
testFunction
finalData
obj
helper
misc
```

Short names are acceptable only when their meaning is obvious from a very small local scope.

Do not invent alternative names for established domain concepts such as Homework, Blitz, Attempt, Official Task Score, Topic Result, Understanding Category, Institution, and Group.

## 23.2 Single Responsibility

A function, method, class, service, widget, file, or module should have one clear reason to change.

If one unit is simultaneously responsible for unrelated concerns, split it. Responsibilities that should normally remain separate include:

```text
request validation
authorization
domain calculation
database persistence
file storage
API serialization
UI rendering
navigation
error presentation
```

Do not create God classes, God files, or catch-all services. Names such as `CommonService`, `GeneralManager`, `AppHelper`, `Utils`, or `EverythingService` should be treated with caution; prefer focused names and responsibilities.

## 23.3 Function and Class Complexity

Do not use arbitrary line-count limits as a substitute for design judgment.

Refactor when a function/class performs several independent business steps, contains deeply nested logic, mixes unrelated layers, is difficult to test without unrelated setup, or repeatedly changes for unrelated features.

Prefer small, composable operations with meaningful names. Do not split code into meaningless tiny methods only to reduce line count.

## 23.4 DRY Without Premature Abstraction

Do not copy-paste the same business rule into multiple places. A rule with one authoritative meaning should have one authoritative implementation.

Examples include:

- Topic Result formula
- Homework official-score selection
- Blitz exception eligibility
- Tenant-scope checks
- Deadline/timeout finalization
- Short Written normalization
- Category-score conversion

Reuse shared code when the behavior is genuinely the same. Do not create an abstraction only because two small code blocks currently look similar. Prefer temporary duplication over a wrong abstraction when the business concepts are different; refactor once the shared responsibility is stable and clearly named.

## 23.5 No Magic Values

Do not scatter unexplained business, configuration, protocol, or design-system literals through production code.

Examples include:

```text
API base URL
role/status/error codes
file-size limits
timeouts
attempt limits
timezone identifiers
route names
pagination limits
UI spacing/radii/typography tokens
```

Use environment/configuration for deployment values, Institution settings for Institution business configuration, task fields for task-specific configuration, focused enums/constants/value objects for stable machine codes, and design-system tokens for repeated UI design values.

Do not convert every ordinary local literal into a constant; obvious local values are not automatically “magic values”.

## 23.6 Proper File Placement

Place code in the layer/module that owns its responsibility. Do not add logic to a file merely because that file is already open or convenient.

Before adding logic, determine:

```text
Which domain/feature owns this behavior?
Which layer should be authoritative for it?
Does a focused implementation already exist?
```

If it belongs elsewhere, place it there and use the approved dependency boundary.

## 23.7 Avoid Tight Coupling

Modules should depend on clear contracts, not hidden implementation details.

Avoid Widgets knowing raw HTTP mechanics, Controllers knowing UI behavior, Domain services depending on presentation state, report code reimplementing scoring rules, business logic depending directly on environment-specific storage, or one feature reaching into another feature's private internals.

Prefer explicit inputs/outputs and narrow dependencies.

## 23.8 Error Handling

Do not write code that works only on the happy path. Consider relevant invalid input, authorization, missing resource, lifecycle conflict, network/server failure, file failure, concurrency conflict, timeout/deadline, and empty-state behavior.

Do not swallow exceptions silently. Do not use broad catch-all handling that hides programming errors unless the architecture explicitly requires a top-level safety boundary.

## 23.9 Comments and Documentation

Prefer clear code and names over comments that restate what code does.

Useful comments explain why a non-obvious decision exists, a business invariant, a concurrency/idempotency reason, compatibility workaround, or security boundary.

Avoid comments such as `// increment counter` or `// get user`. Keep comments accurate and do not leave large commented-out code blocks; Git history is the source for removed code.

## 23.10 Dead Code and Temporary Workarounds

Do not leave unused imports/classes/functions, old alternative implementations, debug prints, placeholder production branches, or TODOs that hide incomplete acceptance criteria.

A temporary workaround is acceptable only when required to unblock correct scoped behavior, clearly documented, compliant with locked business/security rules, and followed by a task when necessary.

## 23.11 Reuse Existing Project Patterns

Before creating a new service, repository, helper, validator, formatter, widget, API client, or state abstraction, inspect the project for the established pattern.

Extend an existing pattern when it owns the same responsibility. Do not introduce competing architectural styles for one feature.

## 23.12 Code Review Standard

Passing tests is necessary but not sufficient. Review must also verify that code is in the correct layer/module, names match domain terminology, responsibilities are focused, important rules are not duplicated, magic business/configuration values were not introduced, coupling remains controlled, error paths are handled, abstractions are justified, and existing abstractions are reused appropriately.

The target standard is:

> **Clean, maintainable, production-ready code with clear architecture, proper separation of concerns, focused responsibilities, and business logic that follows the locked TestLabUz contracts.**

---

# 24. Explicit MVP Non-Goals

Do not build MVP production subsystems for:

- AI generation/checking/recommendations
- Audio/video processing
- Speaking/listening assignments
- Coding tasks
- Group projects / peer review
- Plagiarism detection
- Question-bank/random-test systems
- Advanced anti-cheating/device monitoring
- Live classroom competition
- Predictive analytics
- Teacher-performance analytics
- Chat/messaging
- Notifications/reminders
- Billing/subscriptions/invoices
- External integrations
- Custom-role/permission builder
- Offline synchronization
- Gamification/certificates
- Formal result appeals
- Data warehouse / BI pipeline

---

# 25. Task Completion Checklist

Before reporting a task complete:

- [ ] Scope matches the task and no unrelated refactor was introduced.
- [ ] Naming is descriptive and follows locked domain terminology.
- [ ] Functions/classes/files have focused responsibilities.
- [ ] No important business rule was duplicated.
- [ ] No unjustified magic values or catch-all helpers were introduced.
- [ ] Relevant `docs/01–09` contracts were followed.
- [ ] Relevant root/local `AGENTS.md` rules were followed.
- [ ] Tenant ownership and role/relationship authorization were enforced.
- [ ] Server-authoritative business logic remained on the backend.
- [ ] Required lifecycle/state guards were implemented.
- [ ] Required validation/error contracts were implemented.
- [ ] Concurrency/idempotency requirements were covered where relevant.
- [ ] Automated tests were added/updated and pass.
- [ ] Cross-institution negative tests exist where relevant.
- [ ] Required static/format checks pass.
- [ ] Relevant smoke test passed.
- [ ] No locked product behavior was changed.
- [ ] Documentation/task handoff is updated when required.

---

# Final Rule

> Implement the locked TestLabUz MVP exactly as specified. Keep changes small, tenant-safe, backend-authoritative, testable, and traceable to the current task and `docs/01–09`.
