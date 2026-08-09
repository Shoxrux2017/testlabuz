# TestLabUz Frontend — Codex Instructions

## Scope

This file applies to `frontend/`.

It supplements the root `AGENTS.md`.

The locked `docs/01–09` define product behavior. Flutter must not reinterpret backend-authoritative rules.

---

# 1. Flutter Baseline

Follow `docs/07-architecture.md`.

Recommended locked baseline:

- Flutter
- Riverpod
- GoRouter
- Dio
- `json_serializable` or equivalent DTO serialization
- Secure platform storage for authentication credentials/tokens where required

Use a feature-first layered structure.

---

# 2. Feature-First Structure

Preferred logical shape:

```text
lib/
  app/
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
    platform_admin/
    institution_admin/
    groups/
    topics/
    materials/
    homework/
    blitz/
    submissions/
    results/
    reports/

  shared/
```

Each feature normally separates:

```text
data/
domain/
presentation/
```

Do not create one giant global:

```text
screens/
services/
models/
```

folder containing unrelated features.

Create only the folders/classes needed for the current task.

---

# 3. Layer Boundaries

## Presentation

Responsible for:

- Screens
- Widgets
- Forms
- Local view state
- User actions
- Loading/error/empty/success presentation

## Domain

Responsible for client-side models/use-case contracts needed by UI.

Do not place authoritative scoring/timing/authorization rules here.

## Data

Responsible for:

- DTOs
- API calls
- Serialization
- Repository implementations
- Remote failure mapping

Presentation code must not call Dio directly.

Required flow:

```text
Screen / Controller / Notifier
  ↓
Repository
  ↓
API data source
  ↓
Dio
```

---

# 4. Backend Authority

Flutter must never be authoritative for:

- Role
- Institution ownership
- Permission
- Attempt availability
- Deadline validity
- Blitz availability
- Blitz timeout
- Official Attempt selection
- Official Homework/Blitz score
- Final score
- Calculation method
- Consistency
- Understanding category
- Result status
- Result closure
- Result release eligibility

Flutter may optimistically improve UX only where that cannot create a business-state decision.

Backend response remains final.

---

# 5. Authentication and Route Guards

Use the authenticated server identity (`/api/v1/auth/me`) as the authoritative session profile.

Do not treat locally cached role as permanent authority.

Route guards should consider:

- Authentication
- Role
- `must_change_password`
- Approved device/shell boundary

Backend still re-authorizes every data request.

---

# 6. Mandatory First-Login Password Change

Administrator-created Institution Admin/Teacher/Student/Parent accounts require password change before normal app use.

If:

```text
must_change_password = true
```

route the user only to the approved password-change/auth flow.

Do not expose normal role navigation as usable.

If backend rejects a stale normal request because password change is required, reconcile frontend state and route accordingly.

---

# 7. Role / Device UX Boundaries

MVP roles:

```text
platform_owner
institution_admin
teacher
student
parent
```

Approved device model:

- Platform Owner: desktop
- Institution Admin: desktop
- Teacher: desktop + mobile
- Student: desktop + mobile
- Parent: mobile

Teacher desktop is the main authoring/review surface.

Teacher mobile is for quick classroom/monitoring workflows such as:

- Assigned Groups
- Topic status
- Homework status
- Blitz activation
- Blitz monitoring
- Basic result review

Do not copy every desktop editor to Teacher mobile unless the task/spec explicitly requires it.

Parent UI is read-only.

---

# 8. API Client

Use one configured API client boundary for:

- Base URL
- Authorization header
- Response decoding
- Failure mapping
- Timeouts
- Safe development logging

Feature repositories must not each recreate auth/header/envelope logic.

Do not log bearer tokens.

---

# 9. API Envelopes and Failures

Follow `docs/09-api-contracts.md`.

Flutter must understand:

- Single-resource `data`
- Collection `data + meta.pagination`
- `204 No Content`
- Error `message`
- Stable machine-readable `code`
- Validation `errors`

Do not parse human-readable `message` to decide business behavior.

Map stable backend codes into typed application failures/state.

Examples include:

```text
validation_failed
authentication_required
invalid_credentials
user_inactive
institution_inactive
forbidden
resource_not_found
group_not_assigned
assessment_not_assigned
attempts_exhausted
deadline_passed
blitz_not_active
blitz_time_expired
submission_locked
manual_review_incomplete
result_closed
result_not_visible
idempotency_key_reused
```

Use the exact contract as source of truth.

---

# 10. Client Ownership Boundary

Do not authoritatively send fields the backend must derive.

Examples:

```text
institution_id
role
created_by_user_id
uploaded_by_user_id
official_homework_score
official_blitz_score
score_difference
final_score
calculation_method
consistency
category_code
result_status
calculated_at
server timer validity
```

Only send IDs explicitly allowed by the current endpoint contract.

---

# 11. Student Assessment Security

Student Homework/Blitz payloads must never expose answer-key fields.

Do not expect or render:

```text
is_correct
correct_value
accepted_answers
correct_position
match_key
```

before/while answering.

Do not build UI logic that depends on hidden correct-answer data.

---

# 12. Attempts UX

## Homework

Display the backend-provided effective state for:

- 3 normal attempts
- Used attempts
- Remaining attempts
- Attempt number
- Deadline
- Whether a new Attempt is currently allowed

Official Homework score selection happens on backend:

- Highest valid completed score
- Tie → earliest tied attempt (`lowest attempt_number`)

Flutter must not choose the official Attempt.

## Blitz

Display:

- One normal attempt
- Any backend-authorized Student-specific exception/replacement state
- Current Attempt number
- Current authoritative timer state

Do not create a task-wide “extra attempt” control.

Teacher exception UX, when implemented, must require a reason and use the exact API contract.

---

# 13. Required Idempotency Keys

Flutter must generate/send:

```http
Idempotency-Key: <client-generated-uuid>
```

for exactly the five locked high-risk client mutations:

1. Start Homework Attempt
2. Start Blitz Attempt
3. Final Attempt Submit
4. Blitz Activate
5. Blitz attempt exception grant

Retry rules:

- Retry of the same logical action must reuse the same key.
- A new distinct logical action must use a new key.
- Do not reuse one key with a materially different payload.

Handle:

```text
409 idempotency_key_reused
```

as a contract conflict, not as a generic network error.

---

# 14. Duplicate Mutation Prevention

While a mutation is in flight:

- Disable/restrict duplicate user triggers where appropriate.
- Keep UI state deterministic.
- Do not rely on UI disabling as the backend concurrency guard.

For final submit:

- Do not fire a second logical submit because a response is slow.
- Safe network retry uses the same Idempotency-Key.

---

# 15. Time and Timezone UX

Backend time is authoritative.

Institution has one IANA timezone.

New Institution default:

```text
Asia/Tashkent
```

Educational dates/deadlines are entered/displayed in Institution local time.

Backend stores/validates absolute UTC instants.

Flutter may:

- Convert server timestamps for display.
- Show countdowns.
- Show deadline/schedule forms in Institution local time.

Flutter must not:

- Extend eligibility because device clock is wrong.
- Decide that a late write is valid.
- Assume device timezone equals Institution timezone.

When backend says expired/closed/late, reconcile UI immediately.

---

# 16. Blitz Timer UX

There is one whole-Blitz timer.

No per-question timer exists in the MVP.

Institution mode:

```text
synchronized
individual
```

Teacher configures whole-Blitz duration.

Frontend displays backend-provided authoritative timing.

For synchronized mode, all assigned Students share the activation window.

For individual mode, each Student's timer is based on that Student's Attempt start after activation.

Countdown is a UX projection of server data, not the source of truth.

---

# 17. Timeout / Deadline / Task-Close Reconciliation

Backend may finalize an Attempt because of:

```text
homework_deadline_auto_submit
task_closed_auto_finalize
Blitz timeout finalization
```

Flutter must handle these server transitions even if the screen was open while the transition occurred.

After reconciliation:

- Stop editing.
- Refresh Attempt status.
- Preserve already saved answers as returned by backend.
- Show waiting-for-review if manual answers remain.
- Do not fabricate an explicit Student submission timestamp when `submitted_at` is null.
- Do not create a fake Attempt for never-started Students.

A late explicit submit that receives `submission_locked`/deadline conflict must refresh current server state instead of retrying as a new logical action.

---

# 18. Answer Input Models

Implement typed UI/data models for the nine question types:

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

Do not push unrelated answer types into one uncontrolled `Map<String, dynamic>` through the presentation layer.

DTO boundary may deserialize configuration/payload shapes as needed, but presentation/domain models should remain typed enough to prevent invalid UI behavior.

---

# 19. Multiple-Choice Selection Cap

The backend contract limits Student Multiple-choice selection count to:

```text
number of correct options
```

Student payload must not reveal which options are correct.

API must therefore provide the allowed maximum selection count as non-secret Student-facing configuration when needed by UI.

Do not derive it from hidden `is_correct` values.

Backend remains authoritative if the client submits too many selections.

---

# 20. Short Written UX

Automatic Short Written checking is exact normalized matching on backend.

Do not show fuzzy/AI-match expectations.

Do not normalize in UI in a way that changes the Student's stored answer.

Frontend may trim only where the endpoint/form contract explicitly treats it as input sanitation; the backend checker remains authoritative.

---

# 21. Score Display

Backend calculation uses unrounded precision.

Frontend display rule:

```text
one decimal place
```

Do not round values before sending them back to any backend calculation endpoint.

Understanding category is returned by backend.

Do not derive category from displayed one-decimal score.

---

# 22. Result State vs Visibility

Keep distinct UI concepts for:

- Result calculation status
- Student visibility
- Parent visibility

A calculated result can be unreleased.

Unreleased is not incomplete.

Waiting for Teacher review is not Not completed.

Student release modes:

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

Do not infer visibility only from `result_status`.

---

# 23. Result Closure UX

A closed Student+Topic Result is read-only for scoring/recalculation flows.

Do not show enabled controls for:

- Score correction
- Blitz exception grant
- Pair/cohort changes
- Recalculation

when backend says Result is closed.

Visibility controls remain separate only where the API contract allows them.

---

# 24. File UX

Supported MVP file types:

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

Flutter may perform an early size/type pre-check for UX.

Backend validation remains authoritative.

Do not expose raw private storage paths/keys.

Use the protected file download API.

---

# 25. Loading / Empty / Error / Success States

Every data-driven screen should have predictable states:

```text
loading
data
empty
error
```

Mutation flows should distinguish:

```text
idle
submitting
success
failure
```

Avoid permanently showing stale optimistic success if backend rejects the mutation.

After state-conflict errors, refresh authoritative server state where appropriate.

---

# 26. Routing

Use GoRouter for declarative role-aware navigation.

Route guards may improve UX, but they do not replace backend authorization.

Direct route entry must handle backend denial safely.

Conceptual role areas:

```text
/auth
/platform-admin/...
/institution-admin/...
/teacher/...
/student/...
/parent/...
```

Exact route strings should follow the implemented frontend contract/task.

---

# 27. State Management

Use Riverpod for dependency injection/application state as defined by architecture.

Keep:

- API client
- repositories
- session state
- feature state

testable and replaceable.

Do not use global mutable singleton state as a shortcut around the architecture.

---

# 28. DTO / Domain Separation

Do not leak raw JSON maps through widgets.

Use DTOs for transport.

Use domain/UI models when API representation and presentation needs differ.

A DTO field may mirror backend values exactly; UI labels/localization should not replace machine codes in domain/network logic.

---

# 29. Reports and Lists

Server-side pagination/filtering is authoritative.

Use:

```text
page
per_page
search
allowed filters
sort
direction
```

only as defined per endpoint.

Do not fetch all institutions/users/topics/submissions/results and filter tenant-sensitive data only in Flutter.

Report filters must be sent to authorized server endpoints.

---

# 30. Parent UI

Parent experience is mobile, read-only, and limited to explicitly connected children.

Do not provide:

- Task submission
- Answer editing
- Score editing
- Topic/task management
- Institution settings

If Parent has multiple children, use the connected-children endpoint and keep each child context explicit.

---

# 31. Teacher UI

Teacher may manage only assigned Groups/Students/Topics.

Desktop is the primary surface for:

- Topic authoring
- Material management
- Homework builder
- Blitz builder
- Manual checking
- Detailed results/reports

Mobile should stay focused on approved quick classroom/monitoring actions.

Do not expose Institution Admin policy settings in Teacher UI.

---

# 32. Student UI

Student may access only:

- Assigned Topics
- Learning materials
- Assigned Homework
- Active/eligible Blitz
- Own Attempts/submissions
- Own allowed/released results
- Own progress

Do not expose another Student's identity/data through list caching, direct-route state, or stale repository responses.

---

# 33. Error UX

Human-readable backend `message` may be displayed when appropriate.

Application branching must use stable error `code`.

Examples:

- `must_change_password`/auth state → route reconciliation
- `deadline_passed` → stop editing and refresh
- `blitz_time_expired` → stop timer/editing and refresh
- `submission_locked` → refresh Attempt
- `attempts_exhausted` → disable new Attempt action
- `result_not_visible` → show appropriate unavailable state
- `resource_not_found` → privacy-safe not-found state

Do not display server stack traces/raw exception text.

---

# 34. Tests

Flutter unit tests should cover relevant:

- DTO serialization/mapping
- Repository failure mapping
- Session/bootstrap
- Role routing
- First-login password gate
- View-state logic
- Idempotency-Key retention for retries
- Timer presentation from server timestamps
- Score one-decimal formatting
- Visibility-state mapping

Widget tests should cover important:

- Loading
- Empty
- Error
- Permission denied
- Form validation
- Mutation in-flight state
- Attempt state
- Timer display
- Result visibility
- Parent/Student read-only boundaries where relevant

Do not duplicate backend result formulas in Flutter tests.

Test that UI trusts backend result/category rather than recomputing it.

---

# 35. Required Flutter Quality Gates

Run:

```text
flutter analyze
flutter test
```

Run the repository-configured formatting check.

Do not invent or add a formatter/linter package merely to satisfy a task unless the task/architecture explicitly requires it.

A failed required check blocks completion.

---

# 36. Package Rule

Do not add a Flutter package unless the current task genuinely needs it and the change is reviewed against architecture.

Prefer existing project infrastructure.

Do not introduce a second competing:

- Router
- State-management framework
- HTTP client
- Serialization approach

inside a focused feature task.

---

# 37. Clean Code and Frontend Quality Rules

These rules supplement the root Clean Code rules.

## 37.1 Widget Responsibility

A Widget should primarily describe presentation and user interaction.

Do not place raw Dio calls, tenant authorization logic, official scoring logic, API JSON parsing, complex cross-feature orchestration, or persistent-storage implementation details in Widgets.

Extract focused Widgets when a screen becomes difficult to understand, but do not split every few lines into unnecessary components.

## 37.2 Avoid God Notifiers / Controllers

Riverpod Notifiers/Controllers should manage one feature/use-case state boundary.

Do not create one global controller that manages unrelated auth, topics, Homework, Blitz, results, and reports. Keep state close to the owning feature.

## 37.3 UI Constants and Design Tokens

Do not scatter repeated colors, spacing, radii, text sizes, durations, and breakpoints through Widgets when they are part of the shared design language.

Use the project theme/design-system/token location. A one-off layout value may stay local when it has no reusable design meaning.

Do not hardcode API URLs or backend machine codes in Widgets.

## 37.4 Reusable Widgets

Create reusable Widgets for genuinely repeated UI behavior/patterns.

Do not build one giant universal Widget with many flags for unrelated screens. Prefer focused components with clear inputs. Keep feature-specific UI inside its feature unless it is truly shared.

## 37.5 DTO and State Naming

Name DTOs, domain models, providers, notifiers, and states according to the represented feature.

Prefer:

```text
TopicDto
TopicRepository
StudentHomeworkState
BlitzAttemptNotifier
TopicResultViewModel
```

Avoid vague names such as `DataModel`, `CommonState`, `MainProvider`, `Manager`, or `ApiHelper2`.

## 37.6 Async State Quality

Async flows must handle initial loading, refresh, empty data, mutation in progress, server validation failure, business conflict, auth/session invalidation, and retry/reconciliation where allowed.

Do not leave UI permanently disabled/spinning after an exception. Do not catch and discard backend failures.

## 37.7 Formatting and Display Logic

Presentation formatting may live in focused formatter/view-model helpers.

Valid presentation logic includes one-decimal score formatting, localized date display, and human-readable status labels.

Do not move backend-authoritative calculations into formatters. Invalid examples include recalculating Topic final score, selecting official Attempt, or independently deriving Understanding Category.

## 37.8 Frontend Test Readability

Name tests by behavior.

Prefer:

```text
shows_error_when_homework_attempts_are_exhausted
routes_to_password_change_when_required
does_not_render_parent_result_before_student_visibility
```

Avoid vague test names. Keep reusable setup explicit enough that role, scope, and state remain understandable.

---

# 38. Frontend Completion Checklist

Before completing a frontend task:

- [ ] Feature follows `data/domain/presentation` boundaries where applicable.
- [ ] Names are specific and feature/domain-aligned.
- [ ] Widgets/Notifiers have focused responsibilities.
- [ ] Repeated design values use established theme/tokens where appropriate.
- [ ] No giant catch-all Widget/provider/helper was introduced.
- [ ] Widgets do not call Dio directly.
- [ ] Server remains authoritative for security/business logic.
- [ ] Correct role/device boundary is respected.
- [ ] `must_change_password` gating is respected where relevant.
- [ ] Student payloads do not expose answer keys.
- [ ] Required Idempotency-Key behavior is implemented where relevant.
- [ ] Timer/deadline UX uses server-authoritative data.
- [ ] Scores display one decimal without client category recomputation.
- [ ] Result calculation state and visibility are kept separate.
- [ ] Error branching uses stable backend codes.
- [ ] Loading/empty/error/mutation states are handled.
- [ ] DTO/domain mapping is typed and tested.
- [ ] Relevant widget/unit tests pass.
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] Formatting check passes.
- [ ] No unrelated refactor/package addition was introduced.

---

# Final Frontend Rule

> Flutter is the role-appropriate user interface over the locked Laravel contract. Keep it typed, feature-scoped, server-authoritative, retry-safe, privacy-safe, and free of duplicated backend business logic.
