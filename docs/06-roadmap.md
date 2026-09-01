# TestLabUz — Roadmap

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-08-08.

## Document Purpose

This document defines the recommended development order for the **TestLabUz MVP**.

The roadmap converts the approved business idea, user roles, features, user flows, and business rules into a controlled sequence of implementation stages.

The roadmap does **not** replace:

- `07-architecture.md`
- `08-database.md`
- `09-api-contracts.md`
- Codex task files

Instead, it defines **what should be built first, what depends on what, what each stage must deliver, and when a stage is considered complete**.

The main roadmap principle is:

> **Build TestLabUz vertically, one usable business capability at a time, and do not move forward until the current stage is verified and approved.**

---

# 1. Roadmap Overview

The MVP must prove the central TestLabUz learning-check concept:

1. An institution is created and configured.
2. Institution users and groups are organized.
3. A Teacher creates a topic.
4. The Teacher uploads learning materials.
5. The Teacher creates Homework connected to the Topic and designates one whole-group result-bearing Homework; selected-Student Homework is practice-only.
6. A Student studies the materials and may complete up to three Homework attempts.
7. The system later uses the highest valid completed Homework score as official.
8. The Teacher prepares a short in-class Blitz, sets its duration, and designates one whole-group result-bearing Blitz that shares the official Topic cohort.
9. The Teacher activates the Blitz and the Student completes it under the institution's synchronized or individual timer-start mode.
10. Automatic/manual checking and the approved exception rule produce one official Homework score and one official Blitz score.
11. The system compares the two scores using unrounded values.
12. The system calculates the final Topic result.
13. The system derives integer `category_score` from the final internal score and assigns the understanding category from that value.
14. The Teacher reviews the real learning result.
15. The Student and Parent see allowed results according to the configured release policies.
16. Institution data, group boundaries, submissions, files, and results remain protected.

The MVP is successful only when this complete end-to-end workflow works reliably.

The roadmap is divided into:

- **Stage 0** — planning and technical preparation
- **Stages 1–12** — vertical MVP implementation
- **Stage 13** — complete MVP verification and pilot readiness
- **Post-MVP** — later product evolution

---

# 2. Roadmap Principles

## 2.1 Vertical Development

Development should not follow this pattern:

```text
1. Build the entire backend
2. Build the entire desktop application
3. Build the entire mobile application
4. Integrate everything at the end
```

Instead, each stage should deliver one usable capability across the required layers.

Example:

```text
Stage:
Authentication and Role-Based Entry

Backend / API:
- Login
- Logout
- Account status checks
- Institution status checks
- Role information

Desktop:
- Login flow
- Protected navigation
- Correct dashboard entry

Mobile:
- Login flow for supported mobile roles
- Protected navigation

Integration:
- Real API connection
- Real role routing
- Real permission failures

Verification:
- Automated tests
- Role-by-role smoke test
```

This reduces integration risk and gives a working system after every major stage.

---

## 2.2 One Stage at a Time

A later stage should not be treated as active until the current stage passes its completion gate.

The normal cycle should be:

```text
1. Review stage scope
2. Prepare technical contract
3. Break stage into small Codex tasks
4. Implement backend/API work
5. Implement required desktop/mobile work
6. Integrate real data
7. Test permissions and business rules
8. Run automated checks
9. Run manual smoke test
10. Review with ChatGPT
11. Fix blockers
12. Update project documentation
13. Mark stage closed
14. Continue to the next stage
```

---

## 2.3 Business Rules Are Authoritative

Implementation must follow the approved business rules.

Codex must not silently invent behavior or reopen an approved business decision.

If a new required rule is genuinely undecided, the stage should stop at the planning gate until that new decision is approved. The ten finalized MVP decisions in Stage 0 are not open implementation choices.

---

## 2.4 Security Is Part of Every Stage

Multi-institution separation and role permissions are not a final-stage add-on.

Every stage that introduces new data or actions must also include:

- Institution ownership
- Role permission checks
- Group or relationship scope
- Record ownership
- Protected API behavior
- Protected UI behavior
- Negative authorization tests

Stage 12 performs a complete security verification, but security must already exist throughout Stages 1–11.

---

## 2.5 Historical Data Must Remain Stable

The MVP should prefer:

- Activate / deactivate
- Open / close
- Archive
- Preserve historical submissions and results

over destructive deletion of records that already participate in learning history.

---

## 2.6 Desktop and Mobile Scope Must Follow the Approved Role Model

The MVP device model is:

- **Platform Owner / Super Admin:** desktop
- **Institution Admin:** desktop
- **Teacher:** desktop and mobile
- **Student:** desktop and mobile
- **Parent:** mobile

A stage should implement only the device experience required by the role and workflow.

The MVP should not duplicate every feature on every device.

---

## 2.7 Keep the MVP Focused

The roadmap must prioritize features required to prove the core learning-check model.

The MVP must not expand into unrelated education-platform functionality before the core flow works reliably.

---

# 3. Stage Structure and Definition of Done

Every implementation stage should use the same structure.

## 3.1 Required Stage Definition

Each stage should define:

1. **Goal**
2. **Business value**
3. **Dependencies**
4. **Included scope**
5. **Excluded scope**
6. **Backend/API work**
7. **Desktop work**
8. **Mobile work**
9. **Integration work**
10. **Business-rule enforcement**
11. **Permission and data-separation checks**
12. **Automated tests**
13. **Manual smoke tests**
14. **Documentation updates**
15. **Acceptance criteria**

---

## 3.2 Stage Definition of Done

A stage is complete only when:

- The approved business behavior is implemented.
- Required backend/API behavior works.
- Required desktop/mobile UI is connected to real data.
- No placeholder flow remains for the stage’s core path.
- Required permissions are enforced server-side.
- Multi-institution scope is enforced where applicable.
- Validation and error behavior are defined.
- Automated tests pass.
- Static analysis / linting / formatting checks pass where applicable.
- Required manual smoke tests pass.
- No blocking regression is introduced into previous stages.
- Relevant project documentation is updated.
- ChatGPT review finds no unresolved blocker.
- The stage is explicitly marked closed before the next stage begins.

---

## 3.3 Stage Completion Levels

A stage may temporarily be described as:

### Planned

Business scope is known, but implementation has not started.

### In Progress

Implementation is active.

### Functionally Complete

The primary workflow works, but final verification or documentation is still pending.

### Verified

Automated and manual verification has passed.

### Closed

Implementation, verification, review, and documentation are complete.

Only **Closed** stages should be treated as stable dependencies for later work.

---

# 4. MVP Priorities and Boundaries

## 4.1 Priority 1 — Platform and Institution Foundation

The MVP must first support:

- Authentication
- Five approved roles
- Active/inactive users
- Active/inactive institutions
- Multi-institution data separation
- Institution management
- Institution user management
- Groups and user relationships

Without this foundation, later learning data cannot be safely scoped.

---

## 4.2 Priority 2 — Core Topic Learning Workflow

The next priority is:

- Topics
- Learning materials
- Homework
- Student submissions
- Blitz tasks
- Checking and scoring
- Homework–blitz comparison
- Final result
- Understanding category

This is the main business value of TestLabUz.

---

## 4.3 Priority 3 — Progress Visibility

After the core workflow works, the MVP should provide:

- Teacher progress views
- Student personal progress
- Parent child progress
- Institution summaries
- Basic platform statistics

---

## 4.4 Priority 4 — Verification and Pilot Readiness

Before pilot use, the product must prove:

- Correct permissions
- Institution isolation
- Correct scoring
- Correct state transitions
- Correct timeout/deadline behavior
- Correct file protection
- Stable end-to-end workflows
- Role-appropriate desktop/mobile behavior

---

## 4.5 Explicit MVP Exclusions

The MVP roadmap does not require:

- AI-generated content
- AI checking or recommendations
- Audio/video learning
- Speaking/listening assignments
- Coding assignments
- Group projects
- Peer review
- Plagiarism detection
- Question banks
- Randomized testing
- Advanced anti-cheating
- Device monitoring
- Live classroom competition
- Advanced predictive analytics
- Teacher-performance analytics
- Messaging/chat
- Notifications/reminders
- Payments/subscriptions
- Billing/invoices
- External integrations
- Custom role creation
- Advanced branding
- Offline synchronization
- Gamification
- Certificates
- Complex course builders
- Formal result appeals
- Advanced audit workflows

These belong to Post-MVP planning unless a later approved change explicitly moves them into the MVP.

---

# 5. Stage 0 — Project Preparation and Technical Planning

## Goal

Convert the approved product documents and finalized business decisions into implementation-ready technical contracts before production feature coding begins.

## Business Value

Stage 0 prevents backend, desktop, mobile, database, and Codex tasks from making different assumptions about the same business rule.

## Dependencies

Required synchronized product documents:

- `01-business-overview.md`
- `02-user-roles.md`
- `03-features.md`
- `04-user-flows.md`
- `05-business-rules.md`
- `06-roadmap.md`

## Approved Business-Decision Baseline

The ten previously open MVP decisions are now approved and must be treated as fixed inputs to architecture, database, API, UI, and test design:

1. **Official score across attempts**
   - Homework gives exactly **3 normal attempts**.
   - The official Homework score is the **highest valid completed score** among those attempts.
   - Blitz gives exactly **1 normal attempt**.
   - A valid completed Blitz attempt is the official Blitz score unless an approved technical exception invalidates that attempt and a replacement attempt is used.

2. **Technical-attempt exception**
   - An authorized Teacher may grant exactly **one additional Blitz attempt** to one Student for a valid technical or other approved reason.
   - The Teacher must record a reason.
   - The original interrupted/invalid attempt remains in history and is excluded from official scoring.
   - This exception is Student-specific and does not increase the class-wide limit.
   - No additional Homework exception beyond the three normal attempts is approved for the MVP.

3. **Blitz timer-start mode**
   - The Institution Admin chooses one institution mode: **synchronized** or **individual**.
   - The Teacher configures the whole-Blitz duration.
   - Synchronized mode starts the timer for all assigned Students at Teacher activation.
   - Individual mode starts each Student's timer when that Student starts the attempt after activation.
   - Server time is authoritative.

4. **Blitz timeout**
   - At timeout, the system stops accepting changes and automatically finalizes saved answers.
   - Answers saved before the deadline are evaluated normally.
   - Unanswered questions receive zero.
   - Answers requiring Teacher judgment remain waiting for manual review.
   - Late writes are rejected.

5. **Partial credit**
   - Single-choice and true/false are all-or-nothing.
   - Multiple-choice limits Student selections to the number of correct options and awards partial credit only for correctly selected options / total correct options.
   - Matching uses partial credit per correctly matched pair.
   - Ordering uses partial credit per correctly positioned item.
   - Fill-in-the-blank uses partial credit per correctly completed blank.
   - Short written answers may be automatic or manual according to accepted-answer rules.
   - Open written and file-based answers are Teacher-scored.

6. **Score precision**
   - Calculations use unrounded values.
   - Homework–Blitz difference, threshold evaluation, and final score use unrounded values; understanding-category assignment uses the derived integer `category_score` (`.0`–`.5` down, `>.5` up).
   - User-facing scores display **one decimal place** using standard mathematical rounding.

7. **Result release**
   - Student release mode: `automatic` or `manual_teacher`.
   - Parent visibility mode: `with_student`, `manual_teacher`, or `hidden`.
   - Parent visibility must never begin before Student release.
   - Calculation status and visibility remain separate.

8. **Upload limits**
   - Platform maximum learning-material size: **25 MB per file**.
   - Platform maximum Student submission size: **15 MB per file**.
   - Institutions may configure lower limits, never higher limits.

9. **Timezone**
   - Authoritative timestamps are stored/handled as UTC instants.
   - Each institution has one configurable IANA timezone.
   - `Asia/Tashkent` is the natural default for Uzbekistan institutions.
   - Educational dates are entered/displayed in institution time.
   - Device clocks/timezones cannot extend deadlines or Blitz time.

10. **Official Topic assessment pair**
    - A Topic may contain multiple Homework and Blitz tasks.
    - Exactly **one whole-group Homework and one whole-group Blitz** are designated as the official result-bearing pair for the MVP Topic result; selected-Student tasks are practice-only.
    - Only that pair contributes to the final Topic score and understanding category.
    - The designated pair must belong to the same Topic.
    - The official Homework may be designated before the official Blitz exists. The first activated official task establishes the persisted Topic-group cohort, and the later official task reuses it. Student activity locks the already-designated task/cohort; attaching the previously absent Blitz later completes the pair rather than replacing it.
    - One Student + one Topic produces one final Topic result.

These decisions are no longer implementation choices. Any later change must follow the roadmap change-control process.

### Post-Audit Locked Clarifications

The final consistency audit also locks these implementation requirements:

- New institutions initialize `Asia/Tashkent`, 25 MB learning-material limit, and 15 MB Student-submission limit; threshold/timer/release policies and numeric category ranges have no silent educational default, and only dependent operations are blocked until Institution Admin configuration.
- Administrator-created Institution Admin/Teacher/Student/Parent accounts require mandatory first-login password change; backend blocks normal application actions while `must_change_password = true`.
- Automatic Short Written answers use deterministic normalized exact matching only: Unicode normalization, trim, whitespace collapse, case-insensitive comparison, Uzbek apostrophe normalization, punctuation preserved, no fuzzy/AI matching.
- Draft assessments may have zero points; activation requires server-recalculated `total_possible_points > 0`.
- Highest Homework ties resolve to the earliest tied attempt (`lowest attempt_number`).
- Closing active Homework/Blitz auto-finalizes all in-progress attempts from saved answers with `task_closed_auto_finalize`; unanswered components receive zero and never-started Students get no fake Attempt.
- A Student Topic Result closes only from a terminal calculated or definitive Not completed state; closure is Student+Topic-specific and independent from release.
- Institution activate/deactivate endpoints are idempotent.
- API contracts use normative behavior only; `Idempotency-Key` is required for Homework/Blitz attempt start, final submit, Blitz activation, and Blitz exception grant.

## Included Scope

### Product Contract Review

- Cross-check approved files for contradictions.
- Freeze MVP terminology.
- Freeze role names.
- Freeze lifecycle/status terminology.
- Freeze the fixed Homework and Blitz attempt rules.
- Freeze Blitz timer-start and timeout behavior.
- Freeze partial-credit behavior.
- Freeze the core result formula and score precision rule.
- Freeze Student/Parent release modes.
- Freeze upload limits and timezone behavior.
- Freeze official Homework/Blitz pairing.
- Freeze the five understanding categories.
- Freeze MVP exclusions.

### Technical Documents

Update, synchronize, and approve:

- `07-architecture.md`
- `08-database.md`
- `09-api-contracts.md`

These documents must not retain old decision-gated alternatives after the approved rules are propagated.

### Project Structure

Define:

- Backend project structure
- Desktop/mobile project structure
- Environment strategy
- Configuration strategy
- File-storage strategy
- Authentication strategy
- Authorization strategy
- Error-response strategy
- Testing structure
- CI/check strategy
- Logging strategy
- Seed/demo-data strategy

The exact frameworks and libraries belong in `07-architecture.md`; this roadmap does not silently select them.

### Codex Workflow

Prepare reusable task templates:

```text
tasks/
  backend/
  frontend/
  integration/
```

Each Codex task should contain:

- Goal
- Relevant files
- Requirements
- Business rules
- Acceptance criteria
- Tests
- Explicit non-goals

## Verification

Stage 0 should include a read-only consistency audit across `01` through `09`.

The audit must confirm that:

- No document still describes the ten decisions as unresolved.
- No document still allows arbitrary Homework/Blitz attempt configuration.
- No document still describes per-question Blitz timers as an MVP option.
- Database/API/UI contracts all express the same release, timing, upload, timezone, scoring, and official-pair rules.

## Acceptance Criteria

Stage 0 is complete when:

- All ten business decisions are reflected consistently in `01` through `09`.
- Architecture is approved and no longer decision-gated for these rules.
- Database model is approved and no longer decision-gated for these rules.
- API conventions and affected contracts are approved.
- Project folder structure is approved.
- Authentication and authorization strategy are approved.
- File handling strategy is approved.
- Error and validation conventions are approved.
- Testing approach is approved.
- Codex task format is approved.
- Final cross-document consistency audit passes.
- No unresolved business rule blocks Stage 1.

## Exit Gate

Do not begin Stage 1 production implementation while a required business rule or core contract remains ambiguous or while `07-architecture.md`, `08-database.md`, and `09-api-contracts.md` still conflict with the approved business rules.

---

# 6. Stage 1 — Authentication and Role-Based Entry

## Goal

Allow every approved user type to authenticate securely and enter only the correct part of TestLabUz.

## Business Value

Every later workflow depends on reliable identity, institution status, and role scope.

## Dependencies

- Stage 0 closed
- User/account model approved
- Role model approved
- Institution ownership model approved

## Included Scope

### Backend / API

Implement:

- Login
- Logout
- Current authenticated user/session endpoint
- Active/inactive user check
- Active/inactive institution check
- Role identification
- Institution identity for institution users
- Protected endpoint middleware/policy foundation
- Standard unauthorized/forbidden responses

### Desktop

Support login for:

- Platform Owner / Super Admin
- Institution Admin
- Teacher
- Student

After login, route to the correct role area.

### Mobile

Support login for:

- Teacher
- Student
- Parent

After login, route to the correct mobile role area.

### Role Entry Behavior

The system must distinguish:

- Invalid credentials
- Inactive account
- Inactive institution
- Authenticated but unauthorized action

### Security

- Users must not choose their own role during login.
- Institution context must come from trusted account data.
- Hidden navigation must not replace server-side authorization.
- A user must not open another role’s protected page by direct URL or route.

## Required Tests

At minimum:

- Successful login per role
- Invalid login
- Inactive user denied
- Inactive institution user denied
- Role routing
- Direct restricted route denied
- Cross-role API access denied
- Logout invalidates normal protected access as designed

## Acceptance Criteria

- All five roles can authenticate through their approved device surface.
- Each role reaches the correct entry area.
- Inactive users are blocked.
- Users in inactive institutions are blocked.
- Unauthorized protected pages and endpoints are blocked.
- Previous auth/session state cannot expose another user’s data.

## Excluded Scope

- Advanced session management
- Two-factor authentication
- Device management
- Enterprise identity providers

---

# 7. Stage 2 — Multi-Institution Platform Management

## Goal

Give the Platform Owner / Super Admin basic control over educational institutions.

## Business Value

TestLabUz must support many institutions from the beginning while keeping them logically separate.

## Dependencies

- Stage 1 closed
- Institution data model approved
- Super Admin permissions available

## Included Scope

### Super Admin Desktop Dashboard

Show basic platform information such as:

- Total institutions
- Active institutions
- Inactive institutions
- Basic user totals where approved
- Recent/basic institution activity
- Institutions requiring attention where the data exists

### Institution Management

Implement:

- Institution list
- Search/filter where required
- Institution detail
- Create institution
- Edit allowed basic fields
- Activate institution
- Deactivate institution
- View status
- View basic usage information

### Institution Lifecycle

Rules:

- Deactivation blocks normal institution-user functionality.
- Deactivation does not delete institution data.
- Reactivation restores access according to individual user status.
- Institution historical records remain stable.

### Super Admin Boundary

Super Admin must not normally:

- Change Student submissions
- Change educational scores
- Change Teacher-created learning content
- Replace the Institution Admin
- Replace the Teacher

## Required Tests

- Create institution
- Edit allowed institution data
- Activate/deactivate
- Institution users blocked after deactivation
- Reactivation behavior
- No institution hard-delete of historical active data through normal MVP flow
- Institution list cannot leak protected learning data unnecessarily

## Acceptance Criteria

A Super Admin can create and control multiple institutions without directly participating in their daily teaching workflow.

---

# 8. Stage 3 — Institution Administration and User Management

## Goal

Allow an Institution Admin to set up and maintain users and the approved institution-level learning settings inside one institution.

## Business Value

Teachers, Students, and Parents cannot participate in the learning workflow until the institution can create and manage their accounts safely and define the institution-wide rules used by later Homework, Blitz, result, file, and timezone behavior.

## Dependencies

- Stage 2 closed
- Institution-scoped user model approved
- Role creation rules approved

## Included Scope

### Institution Admin Desktop Dashboard

Provide basic institution overview:

- Teacher count
- Student count
- Parent count
- Basic group/user activity where available

### Institution Profile

Allow Institution Admin to:

- View institution profile
- Edit only approved institution fields

Platform-level fields remain controlled by Super Admin where required.

### Teacher Accounts

Implement:

- List
- Create
- View
- Edit
- Activate
- Deactivate

### Student Accounts

Implement:

- List
- Create
- View
- Edit
- Activate
- Deactivate

### Parent Accounts

Implement:

- List
- Create
- View
- Edit
- Activate
- Deactivate

### Institution Learning Settings

Institution Admin desktop must support:

- Configure acceptable Homework–Blitz score-difference threshold.
- Configure the first four understanding-category score ranges.
- Configure Blitz timer-start mode: `synchronized` or `individual`.
- Configure Student result-release mode: `automatic` or `manual_teacher`.
- Configure Parent result-visibility mode: `with_student`, `manual_teacher`, or `hidden`.
- Configure institution IANA timezone.
- Configure lower institution upload limits, capped by the platform maximums of 25 MB for learning materials and 15 MB for Student submission files.

Rules:

- Homework attempt count is fixed at 3 and is not institution-configurable.
- Blitz normal attempt count is fixed at 1 and is not institution-configurable.
- Parent visibility can never precede Student release.
- Institution timezone changes must not rewrite historical absolute timestamps.
- Setting changes must not silently rewrite closed historical results.

### Account Boundaries

Institution Admin must not:

- Create Super Admin accounts
- Manage another institution
- Complete Student tasks
- Change Student answers
- Manually manipulate final learning results

## Required Tests

- Each user type can be created inside the institution
- Duplicate/invalid data validation
- Cross-institution user lookup blocked
- User deactivation blocks normal login/use
- User reactivation restores allowed access
- Historical records survive deactivation
- Score-difference threshold validation
- Understanding-category range validation
- Blitz timer-start mode validation
- Student release-mode validation
- Parent visibility-mode validation and Student-first hierarchy
- IANA timezone validation
- Institution upload limits cannot exceed platform maximums
- Attempt counts cannot be changed through institution settings

## Acceptance Criteria

An Institution Admin can prepare all three institution user types and all approved institution-level learning settings without leaving the institution scope or changing fixed MVP attempt rules.

---

# 9. Stage 4 — Groups and User Relationships

## Goal

Create the structural relationships required for secure learning delivery.

## Business Value

Topics and tasks must be delivered to the correct Students and managed by the correct Teachers. Parent access must be tied to explicit child relationships.

## Dependencies

- Stage 3 closed
- Teacher, Student, Parent accounts available

## Included Scope

### Group Management

Institution Admin can:

- Create group/class
- View group
- Edit allowed group data
- Activate/use group
- Archive group
- View group members

### Teacher–Group Assignment

Support:

- One Teacher → multiple groups
- One group → one or more Teachers

Rules:

- Teacher must be assigned before managing learning in the group.
- Assignment to Group A must not grant Group B access.
- Removing assignment revokes future management access.
- Historical records remain preserved.

### Student–Group Assignment

Support:

- Student assigned to one or more groups inside the same institution

Rules:

- Group-based learning delivery follows membership.
- Removal blocks future group-based learning access.
- Existing historical work remains preserved.

### Parent–Student Connection

Support:

- One Parent → one Student
- One Parent → multiple Students
- One Student → one or more Parents

Rules:

- Explicit relationship required.
- Relationship must remain in the same institution.
- Removing relationship removes future Parent access without deleting Student data.

## Required Tests

- Valid Teacher/group assignment
- Valid Student/group assignment
- Valid Parent/Student connection
- Cross-institution relationship rejected
- Removed Teacher loses future group access
- Removed Student loses future group delivery
- Removed Parent loses future child progress access
- Direct record IDs do not bypass relationship checks

## Acceptance Criteria

The institution can create the real organizational graph required by all later learning workflows.

---

# 10. Stage 5 — Topics and Learning Materials

## Goal

Allow Teachers to create the central learning object and provide Students with approved study resources.

## Business Value

A TestLabUz learning-check begins with one topic that connects learning materials, homework, blitz, submissions, and results.

## Dependencies

- Stage 4 closed
- Teacher-group authorization works
- Student group access works

## Included Scope

### Topic Management

Teacher desktop must support:

- View assigned groups
- Create topic for assigned group
- Add title
- Add description
- Add subject/learning context
- Add Student instructions
- Add optional lesson date
- Manage topic status
- View topic details
- Edit own eligible topic
- Close topic
- Archive topic

### Topic Lifecycle

Support:

- Draft
- Active
- Closed
- Archived

Rules:

- Draft is not active learning content for Students.
- Active is visible to eligible Students.
- Closed stops new required learning submissions according to connected task rules.
- Archived is historical/read-only.

### Learning Materials

Support upload of:

- PDF
- DOCX
- PPT
- PPTX

Teacher can:

- Upload
- View
- Replace/update current material
- Remove when allowed
- Open/download

Student can:

- Open/download only materials belonging to accessible assigned topics

### File Protection

- Files must not be public by guessed/copied URL.
- File access inherits institution/topic/group authorization.
- Unsupported format rejected.
- Learning materials use a platform hard maximum of **25 MB per file**; an institution may configure a lower effective limit.

### Teacher Mobile

Teacher mobile may provide:

- View assigned groups
- View topic status
- View basic topic information

Complex topic authoring may remain desktop-focused in the MVP.

### Student Desktop and Mobile

Students can:

- View assigned active topics
- Read instructions
- Open/download supported learning materials where device behavior supports it

## Required Tests

- Teacher cannot create topic in unrelated group
- Student cannot see draft topic
- Student sees active assigned topic
- Unrelated Student blocked
- Cross-institution access blocked
- File format validation
- 25 MB platform maximum validation
- Lower institution material limit validation
- Direct file access protection
- Closed/archived behavior
- Historical records preserved

## Acceptance Criteria

A Teacher can create an active topic with protected study materials, and only eligible Students can access it.

---

# 11. Stage 6 — Homework Assignment Management

## Goal

Allow Teachers to build structured homework connected to a topic.

## Business Value

Homework captures the Student’s home-learning performance, which later becomes the first input to the TestLabUz verification model.

## Dependencies

- Stage 5 closed
- Topic and material access stable
- Fixed Homework attempt rule approved and synchronized
- Partial-credit rules approved and synchronized

## Included Scope

### Homework Builder

Teacher desktop must support:

- Create homework from a topic
- Title
- Description
- Student instructions
- Group or selected Student assignment
- Questions
- Points/score rules
- Fixed 3-attempt Homework rule
- Optional deadline
- Lifecycle status

### Homework Lifecycle

Support:

- Draft
- Active
- Closed
- Archived

### Nine Assignment Types

Implement:

1. Single-choice
2. Multiple-choice
3. True / false
4. Short written answer
5. Open written answer
6. File-based assignment
7. Matching
8. Ordering
9. Fill-in-the-blank

### Question Validation

Examples:

- Single-choice must have exactly one correct option.
- Multiple-choice must have one or more correct options.
- True/false must have one correct Boolean value.
- Auto-checked short answer requires accepted answer(s).
- Matching requires valid pairs/mapping.
- Ordering requires a valid correct order.
- Fill-in-the-blank requires accepted values.
- Open written and file-based answers are manually reviewed in the MVP.

### Attempts

Homework attempt behavior is fixed:

- Every assigned Student receives exactly **3 normal attempts**.
- Institution Admin cannot change this count.
- Teacher cannot override this count.
- Each attempt remains a separate historical record.
- The official Homework score is selected later as the **highest valid completed score** among the three attempts.

The Student-facing execution of these attempts is implemented in Stage 7.

### Deadline

Teacher may set a deadline.

Rules:

- Teacher enters the deadline in the institution timezone.
- Deadline must be visible to Students in institution time.
- Server/UTC time is authoritative for enforcement.
- Device clock/timezone cannot extend the deadline.
- After deadline, new attempts/submissions are blocked according to approved MVP rules.

### Editing Integrity

- Scoring-relevant content can be edited while safe/draft.
- After a Student begins an attempt, scoring-relevant content must be locked.
- Homework with activity should be closed/archived rather than destructively deleted.

### Official Homework Designation

A Topic may contain multiple Homework assignments, but exactly **one whole-group Homework** must be designated as the official result-bearing Homework. Selected-Student Homework is practice-only.

Rules:

- The designated Homework belongs to the Topic; the later designated Blitz must belong to that same Topic.
- Only the designated Homework contributes its official score to the Topic result.
- Once Student attempts begin on the designated Homework, the designation must not be replaced in a way that changes the meaning of existing work.

Stage 6 implements the Homework side of the Topic result pair. The official Homework may be designated before the official Blitz exists. The Topic result-pair persistence therefore permits a null Blitz reference until Stage 8. No placeholder Blitz is created.

## Required Tests

- Builder validation for all nine types
- Question/answer validation
- Points validation
- Fixed 3-attempt rule validation
- Teacher/Admin cannot override Homework attempt count
- Deadline/timezone validation
- Unauthorized group/student assignment blocked
- Scoring content locked after attempt begins
- Official Homework designation locks appropriately after attempts begin
- Draft/active/closed/archived rules
- Common 0–100 normalization contract supported

## Acceptance Criteria

A Teacher can create a valid active homework assignment using every supported MVP question type without violating topic, group, or institution boundaries.

---

# 12. Stage 7 — Student Homework and Submission Flow

## Goal

Allow Students to complete assigned homework and create protected attempt/submission records.

## Business Value

This stage produces the Student’s real home-task data instead of only Teacher-authored content.

## Dependencies

- Stage 6 closed
- Fixed 3-attempt Homework rule available
- Highest-valid-attempt official Homework policy available
- Student file upload limit fixed at 15 MB
- Institution timezone behavior available

## Included Scope

### Student Dashboard / Task Entry

Desktop and mobile should show role-appropriate:

- Assigned topics
- Active homework
- Deadlines
- Three-attempt Homework availability
- Completion status

### Starting an Attempt

Before start, Student sees:

- Instructions
- Total normal Homework attempts = 3
- Current attempt
- Remaining attempts
- Deadline in institution time
- Question/task requirements

System validates:

- Active Student
- Active institution
- Assignment
- Group/direct assignment
- Task status
- Deadline
- Attempt availability

### Answering

Support Student input for all nine assignment types.

Device scope may differ:

- Desktop supports the complete detailed workflow.
- Mobile supports the assignment types approved as practical on mobile.
- Security/business rules remain identical.

### File-Based Submission

Support approved Student answer files:

- PDF
- DOCX
- PPT
- PPTX

Validation includes:

- File format
- Platform hard maximum of **15 MB per submission file**
- Any lower institution submission limit
- Student ownership
- Task ownership
- Institution/group/topic scope

### Submission

A valid final submission records:

- Student
- Institution
- Group
- Topic
- Task
- Attempt number
- Answers
- File references where applicable
- Submission time
- Review/checking status

### Attempt Integrity

- Every assigned Student has exactly **3 normal Homework attempts**.
- Submitted attempts remain historical records.
- A new attempt creates a new attempt record.
- A submitted attempt must not be overwritten.
- A fourth normal Homework attempt must be blocked.
- New attempts are blocked after closure/deadline.
- Homework does not receive the Blitz-specific extra-attempt exception.
- Parent cannot submit for Student.
- Stage 9 later chooses the highest valid completed attempt as the official Homework score.

### Submission Status

Support Student-level states required by the approved business rules, including:

- Not started
- In progress
- Submitted
- Waiting for teacher review
- Checked
- Expired/time ended where applicable
- Not completed

## Required Tests

- Assigned Student can start
- Unassigned Student blocked
- Exactly three normal Homework attempts are available
- Fourth normal Homework attempt is blocked
- Deadline blocks invalid start/submission
- Submitted attempt becomes immutable to Student
- Second attempt creates separate history
- Parent cannot submit
- Cross-institution Student blocked
- 15 MB / lower-institution file validation and protection
- Desktop/mobile permission consistency

## Acceptance Criteria

A Student can complete up to three valid Homework attempts while the system preserves each attempt and enforces deadline, timezone, relationship, institution, and file-limit rules.

---

# 13. Stage 8 — Blitz Task Workflow

## Goal

Implement the central in-class verification mechanism of TestLabUz.

## Business Value

The blitz task provides the controlled in-class result used to verify whether homework performance reflects real topic understanding.

## Dependencies

- Stage 7 closed
- Institution Blitz timer-start mode available
- Whole-Blitz duration contract available
- Timeout auto-finalization contract available
- Fixed 1 normal Blitz attempt rule available
- Student-specific extra-attempt exception contract available

Stage 8 completes the existing Topic result-pair row by filling the official Blitz reference and reusing the official cohort established by the first activated official task.

## Included Scope

### Blitz Builder

Teacher desktop supports:

- Create blitz from topic
- Connect designated homework/result
- Group or selected Student assignment
- Instructions
- Questions
- Points
- Whole-Blitz duration
- Fixed normal-attempt rule
- Status

### Blitz Lifecycle

Support:

- Draft
- Scheduled
- Active
- Closed
- Archived

### Activation

Teacher can:

- Open prepared blitz
- Review settings
- Activate during class
- Close when required

Rules:

- Draft/scheduled Blitz cannot be answered.
- Only assigned Students can participate.
- Teacher activation is required.
- The Institution Admin's timer-start mode is authoritative.
- The Teacher-configured whole-Blitz duration is authoritative.
- Server time is authoritative.
- Normal attempt count is fixed at 1.
- Timeout and Student-specific exception rules are authoritative.

### Student Blitz Entry

Student desktop/mobile can:

- See active eligible blitz
- Open instructions
- See remaining time
- Answer supported questions
- Submit within approved timing rules

### Timer

Support exactly two institution-configurable whole-Blitz start modes:

**Synchronized**

- Teacher activation starts the timer for all assigned Students.
- Effective end time is based on Teacher activation + configured duration.
- A late-opening Student receives only the remaining time.

**Individual**

- Teacher activation makes the Blitz available.
- Each Student's timer starts when that Student starts the attempt.
- Each Student receives the full configured duration.

Shared rules:

- Teacher configures the whole-Blitz duration.
- MVP does not use per-question Blitz timers.
- Server timestamps are authoritative.
- Device clock or timezone cannot extend the allowed time.

### Timeout

When the authoritative timer reaches zero:

- Stop accepting new/changed answers.
- Automatically finalize the saved attempt.
- Evaluate answers saved before the deadline normally.
- Give zero points to unanswered questions.
- Keep answered questions requiring Teacher judgment in `Waiting for teacher review`.
- Reject writes received after the deadline.
- Do not mark the entire attempt wrong merely because manual review remains.

### Student-Specific Blitz Attempt Exception

Normal Blitz behavior is exactly **1 attempt per Student**.

For a valid technical or other approved reason, an authorized Teacher may:

- Grant exactly **one additional Blitz attempt** to one Student.
- Record a required reason.
- Keep the interrupted/invalid original attempt in history.
- Mark that original attempt excluded from official scoring according to the approved exception.
- Allow the replacement valid attempt to become the official Blitz score after checking.

The exception must not increase the attempt limit for other Students or the whole class.

### Teacher Mobile

Teacher mobile should support quick classroom actions such as:

- View prepared/active blitz
- Activate blitz
- Monitor participation
- View basic status

### Teacher Monitoring

Show appropriate live participation data:

- Assigned Student
- Started status
- In-progress/submitted status
- Time spent where available
- Attempt number
- Review status
- Technical issue status where supported

Monitoring must never allow the Teacher to answer on behalf of the Student.

## Required Tests

- Draft blitz inaccessible
- Scheduled blitz inaccessible before activation
- Teacher activation works only in scope
- Unassigned Student blocked
- Synchronized timer-start mode enforced
- Individual timer-start mode enforced
- Teacher-configured duration enforced
- Device clock/timezone cannot extend Blitz
- Timeout auto-finalizes saved answers
- Unanswered questions receive zero
- Manual answers remain waiting for Teacher review after timeout
- Late writes rejected
- Exactly one normal Blitz attempt enforced
- One Student-specific extra attempt can be granted only by authorized Teacher with reason
- More than one extra attempt is blocked
- Invalid original attempt remains in history and is excluded from official scoring
- Teacher monitoring uses only allowed group
- Student cannot edit after final submission/time end
- Cross-institution access blocked
- Mobile/desktop security consistency

## Acceptance Criteria

A Teacher can run a real in-class Blitz using the institution's approved timer-start mode, fixed attempt rules, timeout auto-finalization, and Student-specific technical exception while the system reliably preserves protected submissions.

---

# 14. Stage 9 — Checking and Scoring

## Goal

Convert homework and blitz submissions into one official score for each required task.

## Business Value

The final TestLabUz comparison cannot happen until objective questions and Teacher-reviewed answers produce trustworthy official scores.

## Dependencies

- Stage 8 closed
- Approved partial-credit rules available
- Fixed Homework/Blitz official-score policies available
- Score normalization rule approved

## Included Scope

### Automatic Checking

Support automatic checking using the approved scoring behavior:

- **Single-choice:** all-or-nothing.
- **Multiple-choice:** `max_selections = correct_options_count`; partial credit = correctly selected options / total correct options; empty answer = zero.
- **True / false:** all-or-nothing.
- **Matching:** partial credit per correctly matched pair.
- **Ordering:** partial credit per correctly positioned item.
- **Fill-in-the-blank:** partial credit per correctly completed blank.
- **Short written answer:** automatic only when accepted-answer rules permit; otherwise manual review.

No negative-marking model is required for the MVP.

### Manual Checking

Teacher can review:

- Open written answers
- File-based assignments
- Short written answers requiring judgment
- Any question explicitly configured for manual review

Teacher may:

- View submitted answer/file
- Assign points within allowed limits
- Add feedback
- Save review

Teacher must not:

- Rewrite Student answer content
- Directly manipulate final topic result

### Mixed Tasks

If one task contains automatic and manual questions:

- Automatic parts may be scored immediately.
- Task official score remains pending until all required manual review is complete.

### Official Score Selection

Exactly one official score must be produced for the designated Homework and designated Blitz before Stage 10 comparison.

**Homework**

- Exactly 3 normal attempts are available.
- All valid completed attempt scores remain historical.
- The official Homework score is the **highest valid completed score** among the three attempts.
- If a potentially highest attempt still needs manual review, official selection waits until required checking is complete.

**Blitz**

- Exactly 1 normal attempt is available.
- If that attempt is valid and completed, it is the official Blitz attempt.
- If a Teacher-approved technical exception invalidates the normal attempt, that attempt remains in history but is excluded from official scoring.
- The one permitted replacement attempt becomes the candidate official Blitz attempt after required checking.

Teacher does not manually choose an arbitrary official attempt.

### Common Score Scale

Task score must be normalized to **0–100** before comparison.

Normalization and official-score storage must preserve sufficient precision for Stage 10 to calculate with unrounded values. User-facing display rounding is applied later.

### Review Status

Support:

- Waiting for teacher review
- Checked

where applicable.

## Required Tests

- Single-choice all-or-nothing scoring
- True/false all-or-nothing scoring
- Multiple-choice partial-credit scoring
- Matching partial-credit scoring
- Ordering partial-credit scoring
- Fill-in-the-blank partial-credit scoring
- Manual review path
- Mixed auto/manual task remains pending correctly
- Score limits enforced
- Teacher cannot score unrelated Student
- Teacher cannot rewrite answer
- Homework selects highest valid completed score across exactly three attempts
- Blitz selects normal attempt or approved replacement according to exception state
- Invalid technical Blitz attempt remains historical and excluded
- Teacher cannot arbitrarily select official attempt
- Raw points normalize to 0–100 without premature rounding
- One official Homework score selected
- One official Blitz score selected

## Acceptance Criteria

Every completed required task can produce one official 0–100 score, with manual work clearly pending until Teacher review is complete.

---

# 15. Stage 10 — Final Result and Understanding Assessment

## Goal

Implement the central TestLabUz result-calculation model and separate calculation from visibility.

## Business Value

This stage turns home performance and in-class performance into the Student’s final topic-understanding result.

## Dependencies

- Stage 9 closed
- Acceptable-difference configuration available
- Category ranges available
- Approved unrounded-calculation / one-decimal-display rule available
- Student and Parent result-release modes available
- Official Homework/Blitz pair available

## Included Scope

### Required Inputs

A numeric final topic result requires:

- One official Homework score from the designated result-bearing Homework
- One official Blitz score from the designated result-bearing Blitz
- Both designated tasks belong to the same Topic and Student result context
- Completed required manual review
- Valid acceptable-difference threshold
- Valid category ranges

### Score Comparison

Use:

```text
H = official homework score
B = official blitz score
D = |H - B|
T = institution acceptable difference
```

### Close Scores

```text
If D <= T:
    Final = (H + B) / 2
    Consistency = Consistent
```

### Large Difference

```text
If D > T:
    Final = B
    Consistency = Inconsistent
```

The same rule applies when blitz is higher than homework.

An inconsistent result must not automatically accuse the Student of cheating.

### Score Precision and Display

The calculation pipeline must use unrounded values for:

- Official Homework and Blitz scores after normalization.
- `D = |H - B|`.
- Comparison against `T`.
- Final average when `D <= T`.
- Understanding-category assignment.

User-facing numeric scores are displayed with **one decimal place** using standard mathematical rounding.

Displayed one-decimal rounding is presentation-only. Category selection uses the separate integer `category_score` (`.0`–`.5` down, `>.5` up).

### Understanding Categories

Support:

1. Understood well
2. Partially understood
3. Needs revision
4. Needs teacher support
5. Not completed

Rules:

- First four categories use institution-configured non-overlapping 0–100 ranges.
- **Not completed** is not a numeric score band.
- Waiting for Teacher review is not Not completed.
- Unreleased result is not Not completed.

### Result Status

Support:

- Waiting for homework
- Waiting for blitz task
- Waiting for teacher review
- Calculated
- Not completed
- Closed

### Result Data

Persist enough information to explain the result:

- Official homework score
- Official blitz score
- Difference
- Threshold used
- Calculation method
- Final score
- Consistency
- Category
- Result status
- Visibility state
- Attempt references
- Relevant feedback

### Rule Snapshots

Historical results should preserve the threshold/category logic used when calculated or closed.

Changing institution settings must not silently rewrite closed historical results.

### Result Visibility

Keep calculation status separate from:

- Student visibility
- Parent visibility

Teacher can see assigned result/review state even before release.

**Student release mode**

Institution setting supports exactly:

- `automatic` — fully calculated result becomes visible to the Student automatically.
- `manual_teacher` — fully calculated result remains hidden until the authorized Teacher releases it.

**Parent visibility mode**

Institution setting supports exactly:

- `with_student` — Parent visibility begins automatically after Student release.
- `manual_teacher` — Parent visibility requires a separate Teacher release after Student release.
- `hidden` — Parent does not receive the result.

Rules:

- Parent visibility must never begin before Student release.
- Releasing/hiding a result must not change scores, formula, category, consistency, or calculation status.
- A calculated but unreleased result is not incomplete.

### Result Closure

A Student+Topic result may close only when it is terminal: either fully calculated with both official scores, all manual review complete, and no relevant in-progress/pending replacement attempt; or definitively Not completed because required work can no longer validly be completed. Waiting states cannot close. Closure does not require class-wide task closure and does not require Student/Parent release. After closure, scoring, exception grants, pair/cohort changes, and recalculation are blocked; visibility/release remains separate.

Formal appeal/revision workflows are Post-MVP.

## Required Tests

- Close-score formula
- Large-difference formula
- Blitz-higher case
- Missing homework
- Missing blitz
- Waiting for manual review
- Not completed behavior
- Category range boundaries
- Non-overlap validation
- Unrounded difference/threshold behavior
- Category-score conversion boundary behavior (`x.5` down, `>x.5` up)
- One-decimal user-facing display
- Display rounding does not change category
- Visibility does not modify calculation
- Student automatic release
- Student manual Teacher release
- Parent with-Student release
- Parent manual Teacher release
- Parent hidden mode
- Parent can never see result before Student release
- Historical rule snapshot
- Closed result read-only
- Cross-user result access blocked

## Acceptance Criteria

The system can explain exactly how every final topic result was produced and expose it only to authorized users.

---

# 16. Stage 11 — Dashboards, Reports, and Progress Monitoring

## Goal

Make the completed learning workflow understandable and actionable for each role.

## Business Value

TestLabUz is valuable only if Teachers and other authorized users can identify what happened and which Students need support.

## Dependencies

- Stage 10 closed
- Core result/status model stable

## Included Scope

### Super Admin Desktop

Basic platform-level information such as:

- Institution totals
- Active/inactive institutions
- Basic usage/activity summaries

Do not expose unnecessary daily Student answer content.

### Institution Admin Desktop

Basic institution summaries such as:

- Users
- Groups
- Topic activity
- Homework completion
- Blitz completion
- Understanding-category distribution
- Students/groups needing attention
- Pending Teacher review summaries

### Teacher Desktop

Support:

- Teacher dashboard
- Assigned groups
- Active topics
- Homework progress
- Blitz progress
- Pending manual review
- Topic results
- Group results
- Student progress
- Large homework/blitz differences
- Needs revision
- Needs teacher support

### Teacher Mobile

Quick monitoring:

- Groups
- Topic status
- Completion status
- Blitz status
- Basic Student result
- Students needing attention

### Student Desktop and Mobile

Personal-only:

- Assigned topics
- Task status
- Released homework score
- Released blitz score
- Released final result displayed to one decimal place
- Understanding category based on derived integer `category_score`
- Feedback where allowed
- Topics needing revision

### Parent Mobile

Connected-child-only:

- Child selector when multiple children exist
- Topic progress
- Homework completion
- Blitz completion
- Released result according to Parent visibility mode
- Understanding category
- Feedback where allowed
- Needs revision/support

### Filters

Where useful, support basic filtering by:

- Group
- Topic
- Student
- Completion/status
- Understanding category

A filter must never expand authorization scope.

## Required Tests

- Role-specific report scope
- Teacher sees assigned groups only
- Student sees self only
- Parent sees connected child only
- Institution Admin sees own institution only
- Report filters do not bypass permissions
- Hidden/unreleased scores remain hidden where required
- Parent Student-first release hierarchy is preserved
- Displayed scores use one decimal place
- Counts and summaries agree with source records

## Acceptance Criteria

Every approved role receives the minimum useful progress visibility required for the MVP without exposing unauthorized data.

---

# 17. Stage 12 — Security and Data-Separation Verification

## Goal

Perform a dedicated full-system authorization and isolation audit before pilot release.

## Business Value

TestLabUz stores Student educational data across many institutions. A functional feature is not acceptable if it leaks data across institutions, groups, Students, or Parent relationships.

## Dependencies

- Stages 1–11 closed

## Important Principle

Stage 12 is **verification and hardening**, not the first time security is implemented.

Every previous stage must already include authorization.

## Verification Areas

### Authentication

Verify:

- Unauthenticated requests denied
- Inactive users denied
- Inactive-institution users denied

### Institution Isolation

Attempt cross-institution access to:

- Users
- Groups
- Topics
- Materials
- Homework
- Blitz tasks
- Attempts
- Submissions
- Files
- Scores
- Results
- Reports
- Settings

### Teacher Scope

Verify Teacher cannot access:

- Unassigned groups
- Unassigned Students
- Another Teacher’s out-of-scope content
- Another institution

### Student Scope

Verify Student cannot:

- Access another Student’s task
- View another Student’s answers
- View another Student’s scores/results
- Use direct record identifiers to bypass assignment
- Submit after forbidden status/deadline/time/fixed attempt limits
- Gain a fourth normal Homework attempt
- Gain a second Blitz attempt without approved Teacher exception

### Parent Scope

Verify Parent cannot:

- View unrelated Student
- Guess Student ID
- Edit learning data
- Submit tasks
- View hidden results
- View Parent result before Student release
- Access another institution

### File Protection

Verify:

- Learning materials require proper authorization
- Submitted files require proper authorization
- Copied/guessed URLs do not bypass checks

### Reports

Verify:

- Filters cannot expand scope
- Counts do not include unauthorized institutions/groups
- Drill-down links remain protected

### State Protection

Verify:

- Closed/archived records cannot accept forbidden activity
- Submitted attempts are immutable to Student
- Closed results cannot be changed through normal MVP APIs

## Required Test Types

- Automated authorization tests
- Cross-tenant/institution tests
- Negative API tests
- Direct-ID tests
- File-access tests
- Manual role-by-role penetration-style smoke checks within safe application testing

## Acceptance Criteria

No known path allows one institution, Teacher, Student, or Parent to access data outside the approved scope.

Any unresolved critical access-control issue blocks Stage 13.

---

# 18. Stage 13 — End-to-End MVP Verification and Pilot Release

## Goal

Verify the complete TestLabUz MVP as one product and prepare it for controlled real-world use.

## Business Value

Individual stages can pass independently while the complete workflow still fails. The final stage proves that the product solves the original business problem from beginning to end.

## Dependencies

- Stages 0–12 closed
- No critical security blocker
- All approved scoring/timing/release contracts synchronized
- Pilot configuration available

## End-to-End Test Scenario

A complete realistic scenario should include:

1. Super Admin creates Institution A.
2. Super Admin activates Institution A.
3. Institution Admin logs in.
4. Institution Admin creates Teacher.
5. Institution Admin creates Students.
6. Institution Admin creates Parent.
7. Institution Admin creates Group.
8. Institution Admin assigns Teacher to Group.
9. Institution Admin assigns Students to Group.
10. Institution Admin connects Parent to Student.
11. Institution Admin configures acceptable score difference, category ranges, Blitz timer-start mode, Student/Parent release modes, timezone, and allowed lower upload limits.
12. Teacher logs in.
13. Teacher creates Topic.
14. Teacher uploads supported learning material.
15. Teacher creates Homework and designates the result-bearing Homework.
16. Student logs in and studies Topic material.
17. Student completes up to three Homework attempts.
18. System/Teacher scores each attempt using approved automatic/manual and partial-credit rules.
19. System selects the highest valid completed Homework score as official.
20. Teacher creates Blitz, sets whole-Blitz duration, and designates the result-bearing Blitz.
21. Teacher activates Blitz during class.
22. Student joins Blitz according to the institution's synchronized or individual timer-start mode.
23. Server-authoritative timer and timeout auto-finalization work correctly.
24. If testing the exception branch, Teacher grants one Student-specific extra Blitz attempt with a reason and the invalid original remains historical.
25. System/Teacher checks Blitz using approved scoring rules.
26. Official Blitz score is produced.
27. System calculates score difference using unrounded values.
28. System applies average-or-Blitz formula.
29. System derives integer `category_score` and assigns understanding category from it.
30. User-facing score displays use one decimal place.
31. Teacher reviews result.
32. Student result follows the configured automatic/manual release mode.
33. Parent result follows `with_student`, `manual_teacher`, or `hidden` and never appears before Student release.
34. Institution Admin views basic progress summary.
35. Unrelated Institution B user cannot access any Institution A data.

## Verification Categories

### Functional

- All required MVP flows work.

### Business Rules

- Formula and categories are correct using unrounded values.
- Homework 3-attempt / highest-score behavior is correct.
- Blitz 1+1 exception behavior is correct.
- Timer-start and timeout behavior is correct.
- Partial-credit behavior is correct.
- One-decimal display behavior is correct.
- Status behavior is correct.
- Student/Parent visibility behavior is correct.
- Official Homework/Blitz pairing is correct.
- Timezone and file-limit behavior is correct.

### Security

- Stage 12 protections remain green.

### Data Integrity

- Historical attempts remain preserved.
- Closed/archived records remain stable.
- Relationships point to correct institution/group/topic/Student.

### UX

- Non-technical users can understand the main workflow.
- Statuses and errors are understandable.
- Teacher can run blitz without unnecessary classroom friction.
- Student can clearly see timer/attempt state.
- Parent interface remains simple.

### Reliability

- File upload failures are handled.
- Validation failures are handled.
- Network/API errors do not silently corrupt submissions.
- Duplicate requests do not create invalid duplicate business records where the technical contract requires idempotency or guards.

### Performance

Basic MVP workflows should remain usable with representative pilot data.

Exact performance targets should be defined in technical planning if required.

## Pilot Data

Prepare realistic but non-sensitive demo/pilot data:

- At least two institutions for isolation testing
- Multiple Teachers
- Multiple groups
- Multiple Students
- At least one Parent with multiple connected children where supported
- Multiple topics
- All nine assignment types represented
- Automatic and manual checking examples
- Partial-credit examples for multiple-choice, matching, ordering, and fill-in-the-blank
- Three-attempt Homework example where the highest score is not the last attempt
- Normal Blitz example
- Teacher-approved technical Blitz replacement-attempt example
- Synchronized timer example
- Individual timer example
- Timeout auto-finalization example
- Student manual-release example
- Parent hidden/manual/with-Student visibility examples
- Upload-limit boundary examples
- Institution timezone/deadline example
- Consistent score example
- Inconsistent score example
- Missing homework example
- Missing blitz example
- Waiting-for-review example
- Closed historical result example

## Release Gate

The MVP is pilot-ready only when:

- Automated test suite is green.
- Static analysis/lint/format checks are green.
- End-to-end smoke test passes.
- Multi-institution isolation test passes.
- Role access tests pass.
- File-protection tests pass.
- Result-calculation tests pass.
- No unresolved Severity-1/Critical blocker remains.
- No unresolved business-rule ambiguity remains in implemented MVP behavior.
- Deployment/runbook documentation is ready.
- Pilot backup/recovery expectations are defined.
- Product documentation is synchronized with implementation.

## Acceptance Criteria

A real pilot institution can complete the entire approved TestLabUz learning-check process without relying on placeholder features or manual database intervention.

---

# 19. Post-MVP Roadmap

Post-MVP work should be prioritized from real usage, not automatically implemented in the order below.

## 19.1 AI Assistance

Possible future capabilities:

- Generate questions from materials
- Generate homework
- Generate blitz questions
- Topic summaries
- Study notes
- Written-answer assistance
- Feedback suggestions
- Common-mistake analysis
- Revision recommendations

Rule:

> AI should assist Teachers, not silently replace Teacher educational judgment.

---

## 19.2 Audio and Video

Possible future capabilities:

- Audio learning materials
- Video learning materials
- Speaking assignments
- Listening assignments
- Voice responses
- Video responses

---

## 19.3 Advanced Assignment Tools

Possible future capabilities:

- Coding tasks
- Group assignments
- Project work
- Peer review
- Rubrics
- Difficulty levels
- Question banks
- Randomized questions
- Reusable assignment templates
- Plagiarism checking

---

## 19.4 Advanced Blitz

Possible future capabilities:

- Random question selection
- Live classroom session
- Access code / QR entry
- Real-time participation
- Advanced anti-cheating
- Device monitoring
- Adaptive difficulty
- Advanced live analytics

---

## 19.5 Advanced Analytics

Possible future capabilities:

- Long-term Student trends
- Topic difficulty
- Group comparison
- Subject comparison
- At-risk Student detection
- Consistency trends
- Institution performance dashboards
- Download/export
- Weekly summaries

---

## 19.6 Communication and Notifications

Possible future capabilities:

- Teacher–Student comments
- Teacher–Parent messaging
- Announcements
- In-app notifications
- Push notifications
- Email
- SMS
- Telegram

These should remain focused on education workflows rather than turning TestLabUz into a general chat platform.

---

## 19.7 Monetization

Possible future capabilities:

- Institution plans
- Paid tiers
- Paid AI
- Advanced analytics plans
- Storage limits
- Premium support
- Billing
- Invoices
- Custom enterprise licensing

Monetization should follow validated product value.

---

## 19.8 External Integrations

Possible future integrations:

- Google Classroom
- Moodle
- Google Drive
- Microsoft OneDrive
- Calendar systems
- Telegram
- Email/SMS
- Payment systems
- Student information systems

---

## 19.9 Additional Roles and Customization

Possible future roles:

- Institution Owner / Director
- Department Manager
- Group/Class Curator
- Assistant Teacher
- Content Moderator
- Platform Support Agent
- Finance/Billing Manager
- Report Viewer
- Guest/Observer

Possible customization:

- Branding
- Advanced grading
- Custom role permissions
- Custom report formats
- Custom visibility policies

---

## 19.10 Advanced Security

Possible future capabilities:

- Two-factor authentication
- Advanced audit logs
- Session management
- Device management
- Suspicious activity detection
- IP restrictions
- Enterprise identity
- Advanced file scanning

---

## 19.11 Offline and Performance Improvements

Possible future capabilities:

- Offline material access
- Homework drafts
- Auto-save
- Resume after connection loss
- Background upload
- Synchronization
- Large-institution optimization

Blitz offline behavior should be treated separately because blitz tasks are time-sensitive and classroom-controlled.

---

## 19.12 Student Motivation and Content Reuse

Possible future capabilities:

- Badges
- Achievements
- Study streaks
- Certificates
- Personal goals
- Topic templates
- Assignment templates
- Material libraries
- Content search
- Version history
- Reuse across academic periods

---

# 20. Roadmap Dependencies, Risks, and Change Rules

## 20.1 Main Stage Dependency Chain

The default dependency order is:

```text
Stage 0
  ↓
Stage 1 — Authentication
  ↓
Stage 2 — Platform / Institutions
  ↓
Stage 3 — Institution Users
  ↓
Stage 4 — Groups / Relationships
  ↓
Stage 5 — Topics / Materials
  ↓
Stage 6 — Homework Authoring
  ↓
Stage 7 — Student Homework / Submission
  ↓
Stage 8 — Blitz
  ↓
Stage 9 — Checking / Official Scores
  ↓
Stage 10 — Final Result
  ↓
Stage 11 — Reports / Progress
  ↓
Stage 12 — Security Verification
  ↓
Stage 13 — End-to-End / Pilot
```

Some technical subtasks may be prepared earlier, but a later business stage should not be declared complete before its dependencies are stable.

---

## 20.2 Approved Business-Decision Baseline and Change Risk

The ten previously open decisions are now approved and directly affect database, API, UI, and tests:

- Homework = 3 normal attempts; highest valid completed score is official.
- Blitz = 1 normal attempt + at most 1 Student-specific Teacher-approved replacement opportunity for a valid reason.
- Institution timer-start mode = synchronized or individual; Teacher sets whole-Blitz duration.
- Blitz timeout auto-finalizes saved answers; unanswered = zero.
- Approved partial-credit rules apply by question type.
- Internal score calculations are unrounded; user-facing display uses one decimal place.
- Student release = automatic or manual Teacher; Parent = with Student, manual Teacher, or hidden.
- Platform upload maximums = 25 MB learning materials / 15 MB Student submissions; institutions may set lower limits.
- UTC is authoritative; institution IANA timezone controls educational input/display.
- One Topic may have multiple tasks, but exactly one designated Homework + one designated Blitz form the result-bearing pair.

Rule:

> These are fixed MVP contracts. If any of them changes, use the change-control process before implementation or before continuing an affected stage.

---

## 20.3 Multi-Institution Risk

The largest structural risk is accidental cross-institution access.

Every new model/resource should answer:

```text
Which institution owns this record?
Who may access it?
Which relationship gives access?
What happens if a user supplies another institution's record ID?
```

No stage should defer these questions to Stage 12.

---

## 20.4 Status-Model Risk

TestLabUz uses several different state concepts.

Do not collapse them into one generic `status` without a clear model.

The implementation must distinguish:

- Topic/task lifecycle
- Student submission/review state
- Result calculation state
- Result visibility

This distinction is required to avoid errors such as treating an unreleased result as incomplete.

---

## 20.5 Attempt and Scoring Risk

Attempt behavior is fixed, but implementation mistakes can still produce the wrong official score.

Required safeguards:

- Homework must expose exactly 3 normal attempts.
- Official Homework score must be the highest valid completed score, not automatically the latest attempt.
- Blitz must expose exactly 1 normal attempt.
- The one extra Blitz opportunity requires authorized Teacher approval and a reason.
- The invalid/interrupted Blitz attempt must remain historical and be excluded from official scoring.
- Teacher must not arbitrarily choose the official attempt.
- The final Topic calculation must use only the designated official Homework and Blitz pair.
- Partial-credit formulas and 0–100 normalization must be deterministic.
- Rounding must not occur before difference, threshold, final-score, or category calculation.

Do not calculate the Homework–Blitz result from an arbitrary attempt or supplementary task.

---

## 20.6 Content Editing Risk

After Students begin work:

- Do not silently change scoring questions.
- Do not silently change points.
- Do not silently change correct answers.
- Do not overwrite submitted attempts.

Use stable records and controlled status transitions.

---

## 20.7 Scope-Creep Rule

A new feature should not automatically enter the current stage.

When a new idea appears:

1. Record the request.
2. Determine whether it is required for the core MVP workflow.
3. Identify affected business rules.
4. Identify affected roadmap stages.
5. Estimate whether it changes architecture/database/API contracts.
6. Decide explicitly:
   - Add to current MVP
   - Add to later MVP stage
   - Move to Post-MVP
7. Update documentation before implementation.

---

## 20.8 Change-Control Rule

If an approved business rule changes after implementation begins:

1. Update the source business document.
2. Update `05-business-rules.md`.
3. Reassess `06-roadmap.md`.
4. Update architecture if affected.
5. Update database contract if affected.
6. Update API contract if affected.
7. Update tests.
8. Create a focused migration/refactor task.
9. Reverify affected completed stages.

Do not allow the codebase to become the only place where a changed business rule exists.

---

## 20.9 Stage Regression Rule

When a later stage changes behavior used by an earlier stage:

- Run regression tests for the earlier stage.
- Repeat relevant manual smoke tests.
- Reopen the earlier stage if the change invalidates its previous completion criteria.

---

## 20.10 Codex Task Granularity

A roadmap stage is **not** one Codex task.

Each stage should be divided into small, reviewable tasks.

Example:

```text
Stage 6 — Homework Assignment Management

Task 6.1
Backend homework domain foundation

Task 6.2
Homework API list/detail

Task 6.3
Homework create/update lifecycle

Task 6.4
Question model foundation

Task 6.5
Single-choice + true/false support

Task 6.6
Multiple-choice support

Task 6.7
Written-answer support

Task 6.8
File-based support

Task 6.9
Matching / ordering / fill-in-the-blank

Task 6.10
Desktop assignment builder

Task 6.11
Integration and validation

Task 6.12
Stage verification and handoff
```

The exact task breakdown should be created only after the stage’s architecture/API contract is clear.

---

# Final MVP Completion Definition

The TestLabUz MVP is complete when all of the following are true:

1. The platform supports multiple isolated institutions.
2. The five approved roles work.
3. User and institution activation/deactivation works.
4. Institution Admins can organize users and groups.
5. Teacher-group, Student-group, and Parent-child relationships work.
6. Institution Admin can configure the approved score-difference threshold and category ranges.
7. Institution Admin can choose synchronized or individual Blitz timer-start mode.
8. Institution Admin can configure Student release as automatic or manual Teacher release.
9. Institution Admin can configure Parent visibility as with Student, manual Teacher release, or hidden.
10. Institution Admin can configure a valid IANA timezone.
11. Institution Admin can configure lower upload limits without exceeding platform maximums.
12. Teachers can create Topics for assigned groups.
13. A Topic may contain multiple Homework/Blitz tasks, but exactly one whole-group Homework and one whole-group Blitz are the designated result-bearing pair; selected-Student tasks are practice-only.
14. The official cohort is snapshotted on first official-task activation, reused by both tasks, and the pair/cohort cannot be changed improperly after Student attempt activity begins.
15. Teachers can upload PDF, DOCX, PPT, and PPTX learning materials.
16. Learning materials enforce the 25 MB platform maximum and any lower institution limit.
17. Students can access only assigned Topic materials.
18. Teachers can create Homework with all nine approved assignment types.
19. Every assigned Student receives exactly 3 normal Homework attempts.
20. A fourth normal Homework attempt is blocked.
21. Each Homework attempt is preserved separately.
22. Official Homework score is the highest valid completed score among the three attempts.
23. Teachers can create and activate time-limited Blitz tasks.
24. Teacher sets whole-Blitz duration.
25. Synchronized timer mode works correctly.
26. Individual timer mode works correctly.
27. Server time is authoritative and device clock/timezone cannot extend time.
28. Every Student normally receives exactly 1 Blitz attempt.
29. An authorized Teacher can grant at most one Student-specific additional Blitz attempt for a valid reason.
30. The technical-exception reason is recorded, the original attempt remains historical, and the invalid attempt is excluded from official scoring.
31. Timeout automatically finalizes saved Blitz answers.
32. Unanswered Blitz questions receive zero at timeout.
33. Manual-review answers remain waiting for Teacher review after timeout.
34. Late Blitz writes are rejected.
35. Student submission files enforce the 15 MB platform maximum and any lower institution limit.
36. Single-choice and true/false all-or-nothing scoring works.
37. Multiple-choice enforces the server-authoritative selection cap and awards credit only for correctly selected answers / total correct answers.
38. Matching partial credit works per correct pair.
39. Ordering partial credit works per correctly positioned item.
40. Fill-in-the-blank partial credit works per correctly completed blank.
41. Manual Teacher checking works where judgment is required.
42. Teacher cannot rewrite Student answers or directly override the final Topic formula.
43. Both official task scores use the common 0–100 comparison scale.
44. The system calculates the absolute score difference using unrounded values.
45. Institution threshold determines consistent vs. inconsistent.
46. Close scores produce the arithmetic average using unrounded values.
47. Large differences use the Blitz score.
48. Inconsistency is not automatically treated as cheating.
49. Understanding category is selected from the derived integer `category_score` where `.0`–`.5` rounds down and `>.5` rounds up.
50. User-facing scores display one decimal place.
51. Missing required work is handled without inventing a numeric score.
52. Waiting for review is separate from Not completed.
53. Result visibility is separate from calculation status.
54. Student automatic and manual-Teacher release modes work.
55. Parent with-Student, manual-Teacher, and hidden modes work.
56. Parent never receives a result before Student release.
57. Teachers can review complete result details.
58. Students can view only their own released results.
59. Parents can view only connected-child results when allowed.
60. Institution Admins can view basic institution progress.
61. Super Admins can view basic platform/institution information.
62. Authoritative UTC timestamps and institution-time display/deadlines work consistently.
63. Changing institution timezone does not rewrite historical absolute timestamps.
64. Submitted attempts and historical results remain preserved.
65. Closed/archived records behave correctly.
66. File access is protected.
67. Report filters do not bypass permissions.
68. Cross-institution access is blocked.
69. Cross-group and cross-relationship access is blocked.
70. Desktop/mobile access matches the approved role model.
71. Automated tests pass.
72. Manual end-to-end verification passes.
73. No unresolved core business-rule ambiguity remains in implemented MVP behavior.
74. Product and technical documentation are synchronized with implementation.
75. The product is ready for controlled pilot use.
76. New-institution incomplete educational settings block only dependent operations.
77. Administrator-created accounts cannot use normal app functionality before mandatory password change.
78. Assessment activation with zero total possible points is rejected.
79. Automatic Short Written normalization behaves deterministically and preserves punctuation/technical symbols.
80. Highest Homework score ties choose the earliest tied attempt reference.
81. Closing active Homework/Blitz auto-finalizes existing in-progress Attempts with `task_closed_auto_finalize`.
82. Result closure preconditions reject waiting/in-progress/pending-review states.
83. Institution lifecycle endpoints are idempotent.
84. Required high-risk API mutations enforce `Idempotency-Key`.
85. At an authoritative Homework deadline, every in-progress Homework Attempt is auto-finalized from saved answers with unanswered components scored zero.
86. Homework deadline finalization records `homework_deadline_auto_submit`, rejects late writes/submits, creates no fabricated Attempt for never-started Students, and removes unused remaining attempt availability.

---

# Second-Audit Homework Deadline Decision — Resolved

The final second-audit blocker is resolved. At the authoritative Homework deadline, every existing `in_progress` Homework Attempt is auto-finalized from saved answers. Unanswered components receive zero, manual-review components remain pending review, never-started Students receive no fabricated Attempt, unused remaining attempts become unavailable, and the finalization reason is `homework_deadline_auto_submit`. Late writes and submissions are rejected after the server-authoritative deadline transition.

No business-decision gate from either audit remains open. The next step is the final read-only cross-document consistency audit.

---

# MVP Specification Lock and Next Implementation Step

`01–09` are now synchronized and the final read-only cross-document consistency audit has passed. The MVP specification set is locked. Next:

1. Prepare `AGENTS.md`.
2. Prepare reusable `tasks/backend`, `tasks/frontend`, and `tasks/integration` structure.
3. Close Stage 0.
4. Convert Stage 1 into small, precise Codex task files.
5. Implement and verify one task/stage slice at a time.

The development principle remains:

> **ChatGPT manages product logic, architecture, planning, task decomposition, and review. Codex implements one small, precise, verified task at a time.**