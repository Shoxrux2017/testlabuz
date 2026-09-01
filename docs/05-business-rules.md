# TestLabUz — Business Rules

## Document Status

**Status:** LOCKED FOR MVP IMPLEMENTATION — final cross-document consistency audit passed on 2026-08-08.

## 1. Business Rules Overview

This document defines the rules that control how **TestLabUz** must behave in the MVP version.

The business overview explains why the product exists. The user-role document explains who uses it. The feature document explains what the platform must provide. The user-flow document explains how users move through the platform. This business-rules document defines the conditions, restrictions, calculations, ownership rules, state transitions, and access boundaries that make those features and flows consistent.

### Rule Language

The following words have specific meanings in this document:

- **Must / must not** — mandatory behavior for the MVP.
- **Should / should not** — strongly recommended behavior that may be refined later without changing the core product logic.
- **May** — optional behavior that is permitted but not required in every situation.
- **Authorized user** — a logged-in user whose role, institution, relationship, permission, and record scope allow the requested action.
- **Assigned student** — a student who receives a topic or task through an assigned group or an allowed direct assignment.
- **Required task** — a homework assignment or blitz task that must be completed for the topic result to be calculated.

### Core Business Principles

**BR-OV-001 — Topic-centered learning**  
The topic is the central business object in the learning-check process. Learning materials, homework, the blitz task, submissions, scores, the final result, and the understanding category must remain connected to the correct topic.

**BR-OV-002 — Homework is not the final proof of understanding**  
A homework score must not, by itself, be treated as the student’s final real understanding result. The system must verify the homework result through a blitz task connected to the same topic.

**BR-OV-003 — Final result uses homework and blitz**  
The final topic result must be based on both the homework score and the blitz score when both required scores are available.

**BR-OV-004 — Multi-institution separation**  
Every institution must operate inside its own data scope. Users and records from one institution must not be exposed to another institution.

**BR-OV-005 — Role and relationship scope**  
Access must depend not only on the user’s role, but also on the user’s institution, assigned group, assigned task, record ownership, teacher-group relationship, student-group relationship, or parent-child relationship.

**BR-OV-006 — Calculation and visibility are separate**  
A result may be calculated but not yet released to a student or parent. Result availability for calculation must not be confused with result visibility.

**BR-OV-007 — Historical records must be preserved**  
Deactivation, closure, or archiving must not erase historical submissions, scores, results, or relationships needed for reports and progress history.

**BR-OV-008 — No automatic accusation**  
A large difference between homework and blitz scores must be shown as an inconsistency, not as proof of cheating. The system may show possible explanations, but the teacher remains responsible for educational interpretation.

**BR-OV-009 — One authoritative score scale**  
Homework scores, blitz scores, acceptable-difference rules, final scores, and understanding-category ranges must use the same comparison scale. For the approved MVP examples and category ranges, this scale is **0–100**. If a task uses raw points, the system must convert the result to the common 0–100 scale before comparison.

**BR-OV-010 — Rule precedence**  
Rules must be applied in the following order:

1. Platform security and institution-separation rules.
2. Role and relationship permissions.
3. Institution-level business settings.
4. Task-specific settings created by an authorized teacher.
5. The student’s current task, attempt, deadline, and status conditions.

A lower-level setting must never bypass a higher-level security or ownership rule.

**BR-OV-011 — Institution and task settings have defined scopes**  
Institution settings control institution-wide rules such as the acceptable homework–blitz score difference, understanding-category ranges, Blitz timer-start mode, result-release modes, institution timezone, and institution-specific upload limits within platform maxima. Teachers may configure only task-level values explicitly allowed by the MVP, such as a homework deadline or the duration of a Blitz task. A task-level setting must never bypass an institution rule, platform maximum, security rule, or ownership rule.

**BR-OV-012 — Server-side enforcement**  
Hiding a button or menu item is not sufficient protection. Every protected action and record request must be validated against the business rules before data is returned or changed.

---

## 2. Institution and Data Separation Rules

### Institution Ownership

**BR-INST-001 — One platform, many institutions**  
The TestLabUz platform may contain many schools, colleges, lyceums, universities, institutes, learning centers, training centers, and other educational institutions.

**BR-INST-002 — One institution workspace**  
Each institution must have its own logical workspace containing its users, groups, topics, materials, tasks, submissions, results, settings, and reports.

**BR-INST-003 — Institution ownership on records**  
Every institution-level record must be connected to exactly one institution. This includes, at minimum:

- Institution Admins
- Teachers
- Students
- Parents
- Groups or classes
- Topics
- Learning materials
- Homework assignments
- Blitz tasks
- Questions
- Attempts
- Submissions
- Uploaded answer files
- Homework scores
- Blitz scores
- Final results
- Understanding categories or category settings
- Institution reports and report summaries

**BR-INST-004 — Platform-level records are exceptions**  
Platform Owner / Super Admin accounts and global platform settings may exist outside one institution. Their platform-level status must not remove the institution ownership of institution data.

**BR-INST-005 — One institution per institution user account in the MVP**  
An Institution Admin, Teacher, Student, or Parent account must belong to one institution in the MVP. A person who participates in different institutions must use separate institution-scoped accounts unless multi-institution accounts are approved in a future version.

### Cross-Institution Restrictions

**BR-INST-006 — No cross-institution access**  
An institution-level user must not view, create, edit, submit, score, download, or report on records belonging to another institution.

**BR-INST-007 — No cross-institution relationships**  
The system must reject relationships between records from different institutions. For example:

- A teacher from Institution A must not be assigned to a group in Institution B.
- A student from Institution A must not be added to a group in Institution B.
- A parent from Institution A must not be connected to a student in Institution B.
- A topic from Institution A must not use a group, task, material, or result from Institution B.

**BR-INST-008 — Filters must not bypass separation**  
Search, filters, pagination, exports, dashboards, and reports must always remain inside the user’s allowed institution scope.

**BR-INST-009 — File addresses do not grant access**  
Knowing or copying a file URL, record identifier, task identifier, or student identifier must not allow access to another institution’s data.

### Institution Status

**BR-INST-010 — Institution status**  
An institution must have an active or inactive status in the MVP.

**BR-INST-011 — Active institution**  
Users of an active institution may use the platform according to their own active status, role, relationships, and permissions.

**BR-INST-012 — Inactive institution**  
When an institution is inactive, its Institution Admins, Teachers, Students, and Parents must not use normal institution functionality.

**BR-INST-013 — Data retention during deactivation**  
Deactivating an institution must not delete, transfer, merge, or reassign its historical data.

**BR-INST-014 — Reactivation**  
When the Super Admin reactivates an institution, its users may regain normal access according to their individual account status and permissions.

**BR-INST-015 — No hard deletion of active historical institutions in the MVP**  
The MVP should use deactivation instead of permanent institution deletion after institution data has been created. This preserves historical and reporting integrity.

### Institution Settings

**BR-INST-016 — Institution-specific settings**  
Each institution has its own learning settings. The platform automatically initializes only safe operational values when the institution is created:

- Institution timezone = `Asia/Tashkent` for the MVP initial setup
- Learning-material upload limit = 25 MB per file
- Student answer-file upload limit = 15 MB per file

The following educational-policy settings start **unconfigured** and must be selected explicitly by the Institution Admin before a dependent learning operation can use them:

- Acceptable Homework–Blitz score difference
- Blitz timer-start mode: synchronized start or individual Student start
- Student result-release mode: automatic or manual Teacher release
- Parent result-visibility mode: with Student release, manual Teacher release, or hidden

Understanding-category integer ranges are also configured by the Institution Admin. Missing educational-policy settings must block only the dependent operation, not unrelated institution management. Homework and Blitz attempt counts are not institution-configurable in the MVP: Homework allows three normal attempts; Blitz allows one normal attempt, with one additional attempt available only through an approved Teacher exception for a valid technical or other valid reason.

**BR-INST-016A — Institution timezone default and control**  
Each institution must have one configured IANA timezone. The MVP initial setup uses `Asia/Tashkent`; the Institution Admin may change it when necessary. A timezone change affects future interpretation/display rules but must not alter the absolute instant of already-created historical deadlines, submissions, Blitz sessions, or results.

**BR-INST-016B — Incomplete educational settings**  
If an educational-policy setting is still unconfigured, the backend must reject only operations that require that setting. For example, an official Blitz cannot be activated without a timer-start mode; an official Topic result cannot be calculated without both an acceptable-difference threshold and a valid complete understanding-category configuration; and a result cannot be released when the applicable release policy is unconfigured. General user/group administration and unrelated draft authoring remain available.

**BR-INST-017 — Setting isolation**  
Changing one institution’s settings must not affect another institution.

**BR-INST-018 — Historical calculation snapshot**  
A final result must retain the institution rules used when that result was calculated. Changing category ranges or the acceptable score difference must not silently rewrite historical closed results.

### Platform Owner / Super Admin Boundaries

**BR-INST-019 — Platform management authority**  
The Super Admin may create institutions, edit basic platform-level institution information, activate or deactivate institutions, view basic platform statistics, and support Institution Admin access.

**BR-INST-020 — Daily learning boundary**  
The Super Admin must not normally edit student answers, teacher-created tasks, homework scores, blitz scores, final results, or understanding categories.

**BR-INST-021 — Support access is exceptional**  
Any institution-level access by the Super Admin must be limited to a valid support, security, or system-management reason. Impersonation tools are outside the MVP.

---

## 3. User and Role Rules

### Approved MVP Roles

**BR-ROLE-001 — Five roles**  
The MVP must support these five roles:

1. Platform Owner / Super Admin
2. Institution Admin
3. Teacher
4. Student
5. Parent

**BR-ROLE-002 — One primary role per account in the MVP**  
Each account must have one primary role in the MVP. Custom roles and user-created permission groups are outside the MVP.

**BR-ROLE-003 — Role assignment by an authorized administrator**  
Users must not assign or change their own role. Roles must be created or assigned by an authorized platform or institution administrator.

### Account Status

**BR-ROLE-004 — Active account required**  
A user must have an active account to log in and use protected platform functionality.

**BR-ROLE-005 — Inactive account restriction**  
An inactive user must not continue normal platform use until an authorized administrator reactivates the account.

**BR-ROLE-006 — Account deactivation preserves history**  
Deactivating a user must not delete topics, tasks, submissions, scores, feedback, results, or relationships needed for historical reporting.

**BR-ROLE-006A — Administrator-created accounts require first-login password change**  
Every Institution Admin, Teacher, Student, or Parent account created by an administrator in the MVP receives an initial password and must be marked `must_change_password = true` by the backend. The creating client must not choose whether this requirement applies.

**BR-ROLE-006B — Restricted access until password change**  
A user with `must_change_password = true` may authenticate but must not use normal application functionality until the initial password is changed. The user must change it through the authenticated password-change flow by providing the current initial password, a new password, and confirmation. After a successful change, the backend sets `must_change_password = false`. Until then, only the minimal identity/onboarding operations needed to view the current account, change the password, or log out are permitted.

### Platform Owner / Super Admin

**BR-ROLE-007 — Super Admin scope**  
The Super Admin manages the platform and institutions, not one institution’s daily classroom process.

**BR-ROLE-008 — Institution Admin management**  
Only a platform-authorized user may create, activate, deactivate, or provide platform-level access support for Institution Admin accounts.

**BR-ROLE-009 — Super Admin prohibited actions**  
The Super Admin must not normally:

- Complete student tasks
- Answer blitz tasks
- Change student submissions
- Change educational scores
- Replace teacher checking
- Edit teacher-created content
- Manage daily classroom work

### Institution Admin

**BR-ROLE-010 — Institution Admin scope**  
An Institution Admin may manage only their own institution.

**BR-ROLE-011 — Institution Admin user management**  
An Institution Admin may create, view, edit, activate, and deactivate Teacher, Student, and Parent accounts inside their institution.

**BR-ROLE-012 — Institution Admin structure management**  
An Institution Admin may manage groups, student-group assignments, teacher-group assignments, parent-student relationships, institution settings, and basic reports.

**BR-ROLE-013 — Institution Admin educational boundary**  
An Institution Admin must not normally complete tasks, answer blitz tasks, change student answers, or manually manipulate learning results.

### Teacher

**BR-ROLE-014 — Teacher assignment scope**  
A Teacher may work only with groups and students assigned to that teacher inside the teacher’s institution.

**BR-ROLE-015 — Teacher content and classroom authority**  
A Teacher may create and manage topics, learning materials, Homework assignments, Blitz tasks, questions, allowed task-level settings, checking, feedback, and results only inside the Teacher’s allowed scope. The Teacher may configure the whole-task duration of a Blitz and may approve one additional Blitz attempt for a specific Student only when the approved exception rules are satisfied.

**BR-ROLE-016 — Teacher result authority**  
A Teacher may score answers that require manual review. The Teacher must not manually override the final result outside the approved homework–blitz calculation process.

**BR-ROLE-017 — Teacher management boundary**  
A Teacher must not manage institutions, Super Admin accounts, Institution Admin accounts, unrelated groups, or another institution’s data.

### Student

**BR-ROLE-018 — Student learning scope**  
A Student may access only assigned topics, materials, homework, active blitz tasks, own submissions, own released scores, own understanding categories, and own progress.

**BR-ROLE-019 — Student prohibited actions**  
A Student must not:

- Create official topics or learning materials
- Create homework or blitz tasks
- Activate blitz tasks
- Check answers
- Change scores or categories
- Manage users, groups, or settings
- View another student’s answers, files, scores, feedback, or progress

### Parent

**BR-ROLE-020 — Parent read-only scope**  
A Parent may view only allowed progress information for explicitly connected children.

**BR-ROLE-021 — Parent prohibited actions**  
A Parent must not:

- Complete homework for a child
- Answer blitz tasks for a child
- Upload assignment answers
- Change submissions, statuses, scores, feedback, or categories
- Manage users, groups, topics, tasks, or institution settings
- View unrelated children or other parents’ information

### Device Rules

**BR-ROLE-022 — Approved device model**  
The MVP device-access model is:

- Platform Owner / Super Admin: desktop
- Institution Admin: desktop
- Teacher: desktop and mobile
- Student: desktop and mobile
- Parent: mobile

**BR-ROLE-023 — Device does not change permission**  
Using a different device must not expand the user’s data or action scope.

---

## 4. Group and User Relationship Rules

### Group Ownership

**BR-REL-001 — Group institution ownership**  
Every group or class must belong to exactly one institution.

**BR-REL-002 — Group status**  
A group may be active or archived in the MVP. An archived group must remain available for authorized historical reporting but must not receive new active learning work.

### Teacher–Group Relationships

**BR-REL-003 — Teacher assignment required**  
A Teacher must be assigned to a group before creating or managing topics, homework, blitz tasks, submissions, or results for that group.

**BR-REL-004 — Many-to-many teacher relationship**  
One Teacher may be assigned to multiple groups, and one group may have one or more Teachers.

**BR-REL-005 — No automatic access to other groups**  
Assignment to one group must not give the Teacher access to another group.

**BR-REL-006 — Teacher removal**  
Removing a Teacher from a group must revoke future management access to that group. Historical records created by the Teacher must remain connected for reporting and traceability.

### Student–Group Relationships

**BR-REL-007 — Student group assignment**  
A Student may belong to one or more groups inside the same institution.

**BR-REL-008 — Group-based delivery**  
A topic or task assigned to a group must be available only to eligible students in that group, subject to topic/task status and any direct assignment restrictions.

**BR-REL-009 — Direct student assignment**  
A Teacher may assign a task directly to selected students only when those students are inside the Teacher’s authorized institution and group scope.

**BR-REL-010 — Student removal**  
Removing a Student from a group must stop future group-based access. Existing submissions and historical results must remain available to authorized users.

### Parent–Student Relationships

**BR-REL-011 — Explicit relationship required**  
A Parent must have an explicit parent-child relationship before viewing a Student’s progress.

**BR-REL-012 — Supported parent-child cardinality**  
The MVP must support:

- One Parent connected to one Student
- One Parent connected to multiple Students
- One Student connected to one or more Parents

**BR-REL-013 — Same-institution relationship**  
A Parent and connected Student must belong to the same institution account scope in the MVP.

**BR-REL-014 — Relationship removal**  
Removing a parent-child relationship must revoke the Parent’s future access to that Student’s progress without deleting the Student’s records.

**BR-REL-015 — Identifier knowledge is insufficient**  
A Parent who knows a Student identifier must still be blocked when no parent-child relationship exists.

### Relationship Integrity

**BR-REL-016 — Relationship validation**  
Every group assignment and parent-child connection must validate that all records belong to the same institution.

**BR-REL-017 — Relationship-based reporting**  
Reports must use current authorized relationships for access while preserving historical record ownership.

**BR-REL-018 — No silent reassignment of historical records**  
Changing a group membership or user relationship must not silently move historical topics, submissions, or results to a different institution or unrelated group.

---

## 5. Topic Rules

### Topic Ownership and Required Context

**BR-TOP-001 — Topic ownership**  
Each topic must belong to exactly one institution, one owning Teacher, and one group or class in the MVP.

**BR-TOP-002 — Authorized creator**  
Only a Teacher assigned to the selected group may create a topic for that group.

**BR-TOP-003 — Topic information**  
A topic must have, at minimum:

- Title
- Institution
- Teacher
- Group or class
- Subject or learning context
- Student instructions or description sufficient to understand the topic
- Topic status

The lesson date may be optional.

**BR-TOP-004 — Topic components and official assessment pair**  
A topic may contain multiple learning materials, multiple Homework assignments, multiple Blitz tasks, and multiple questions inside those tasks. For the MVP final Topic result, exactly one Homework and exactly one Blitz must be designated as the official result-bearing pair. **Both official tasks must use whole-group assignment.** A Homework or Blitz assigned only to selected Students is supplementary/practice work and cannot become result-bearing. Supplementary tasks may target the whole group or selected Students but must not affect the final Topic result or understanding category. The two official relationships do not need to be created at the same time. The Topic may first have only its official Homework designated; the official Blitz relationship is added later to the same Topic result-pair record.

**BR-TOP-004A — Official Topic cohort snapshot**  
The official result-bearing pair uses one common Student cohort. The first activated official whole-group task establishes the common official Student cohort from its persisted recipient snapshot. If the official Homework is the first task, Stage 6 stores that cohort without fabricating a Blitz or Blitz recipient rows. When the official Blitz is later designated or activated, it must use exactly the same cohort. Later Group membership changes do not rewrite the official cohort.

**BR-TOP-005 — Same-topic comparison**  
The homework and Blitz scores used for one final result must belong to the same topic and Student and must come from the topic’s designated official assessment pair.

**BR-TOP-005A — Official pair becomes immutable after activity**  
Before Student activity, the Teacher may replace an official task when the applicable eligibility rules allow it. Student attempt activity locks the already-designated official task/cohort meaning. A previously absent second official task may still be attached later when it satisfies the same Topic and cohort rules; this is completion of the pair, not replacement of locked work.

### Topic Statuses

The topic lifecycle statuses are:

- **Draft** — being prepared and not visible to students.
- **Active** — visible to assigned students and available for the learning process.
- **Closed** — no longer accepts new required task submissions according to its task rules.
- **Archived** — retained for history and reports and no longer actively used.

**BR-TOP-006 — Draft visibility**  
Students and Parents must not access a draft topic as active learning content.

**BR-TOP-007 — Activation requirements**  
Before a topic becomes active, it must have valid ownership, group assignment, student instructions, and the core learning content required for the approved flow. At minimum, the Teacher should prepare learning material and homework before student access.

**BR-TOP-008 — Active topic access**  
Only assigned students and authorized institution users may access an active topic.

**BR-TOP-009 — Closing a topic**  
Closing a topic must block new homework or blitz submissions when the connected task rules no longer permit them. Existing submissions may still be reviewed.

**BR-TOP-010 — Archiving a topic**  
Archiving must preserve materials, tasks, submissions, results, and reports as read-only historical information for authorized users.

**BR-TOP-011 — Status transition integrity**  
A topic with student submissions must not be returned to an editable draft state in a way that changes the meaning of completed work.

### Topic Editing and Deletion

**BR-TOP-012 — Teacher editing scope**  
A Teacher may edit only topics owned by that Teacher and connected to an assigned group.

**BR-TOP-013 — Scoring-impact restriction**  
After a student has started a connected task, the Teacher must not change topic ownership, group, or other scoring-relevant relationships in a way that invalidates existing submissions.

**BR-TOP-014 — Historical preservation**  
A topic with submissions or results must not be permanently deleted in the MVP. It must be closed or archived.

**BR-TOP-015 — Draft deletion**  
A draft topic with no student access, submissions, or results may be deleted by an authorized Teacher if the implementation supports draft deletion.

### Topic Visibility

**BR-TOP-016 — Student visibility**  
A Student may see only topics assigned through an authorized group or direct assignment.

**BR-TOP-017 — Parent visibility**  
A Parent may see only approved progress information for a connected child. Parent access to the topic does not grant task-completion or material-management rights.

**BR-TOP-018 — Admin visibility**  
An Institution Admin may view topic activity inside their institution for management and support but must not normally replace the Teacher’s content-management role.

---

## 6. Learning Material Rules

### Supported Material Types

**BR-MAT-001 — MVP material formats**  
The MVP must support these learning-material formats:

- PDF
- DOCX
- PPT
- PPTX

Audio, video, interactive content, external links, and AI-generated resources are outside the MVP.

**BR-MAT-002 — Topic connection**  
Every learning material must be connected to exactly one topic and inherit that topic’s institution and access scope.

**BR-MAT-003 — Material purpose**  
Learning materials are official resources provided by the Teacher for independent study and preparation for homework and blitz tasks.

### Material Management

**BR-MAT-004 — Authorized upload**  
Only the owning Teacher, or another explicitly authorized user inside the same institution, may upload materials to the topic.

**BR-MAT-005 — Teacher management actions**  
The owning Teacher may:

- Upload a material
- View the material
- Replace or update the current material
- Remove the material when allowed
- Open or download the material

**BR-MAT-006 — Admin boundary**  
Institution Admins may view material activity for support or management. They should not routinely edit Teacher learning content in the MVP.

**BR-MAT-007 — File validation**  
The system must validate at least:

- Supported file format
- Configured maximum file size
- Successful upload completion
- Connection to the correct topic and institution

The platform maximum for one Teacher learning-material file is **25 MB**. An Institution Admin may configure a lower institution limit, but the institution limit must never exceed 25 MB.

**BR-MAT-008 — Unsupported file rejection**  
An unsupported or oversized file must not be attached to a topic, and the system must show a clear error message.

### Material Access

**BR-MAT-009 — Assigned-student access**  
A Student may open or download only materials belonging to an assigned accessible topic.

**BR-MAT-010 — Direct file protection**  
A material file must not be accessible through an unprotected public address that bypasses role, institution, and group checks.

**BR-MAT-011 — Parent scope**  
Parent access in the MVP is focused on progress monitoring. Parents must not manage topic materials. Direct parent access to full learning files is not required unless separately approved.

### Replacement, Removal, and History

**BR-MAT-012 — Replacement behavior**  
Replacing a material changes the current material available for the topic. The system should show the latest update information. Full material version history is outside the MVP.

**BR-MAT-013 — Active-topic caution**  
A Teacher should not replace a material after students have begun the related homework unless the replacement corrects an error or provides necessary clarification.

**BR-MAT-014 — Removal restriction**  
A material must not be removed by an unauthorized user. Removing a material must not delete student submissions or results.

**BR-MAT-015 — Archived topic materials**  
Materials connected to an archived topic must remain available as historical read-only content to authorized users where permitted.

---

## 7. Homework Assignment Rules

### Homework Ownership and Assignment

**BR-HW-001 — Topic connection required**  
Every homework assignment must be connected to a specific topic.

**BR-HW-002 — Ownership**  
Every homework assignment must belong to the same institution, owning Teacher, and group context as its topic.

**BR-HW-003 — Authorized creator**  
Only a Teacher authorized for the topic’s group may create or manage the homework assignment.

**BR-HW-004 — Assigned recipients**  
Supplementary/practice Homework may be assigned to the Topic group or to selected Students inside the Teacher’s authorized group scope. Homework that is part of the official result-bearing pair must use whole-group assignment.

**BR-HW-005 — Official result-bearing Homework**  
A Topic may contain multiple Homework assignments, but exactly one whole-group Homework must be designated as the official result-bearing Homework. Only that Homework’s official Student score is compared with the designated official Blitz score for the final Topic result. A selected-Students Homework is not eligible for official designation.

### Homework Structure

**BR-HW-006 — Required homework information**  
A homework assignment must contain:

- Title
- Topic
- Group or selected students
- Student instructions
- At least one valid question or task item
- Points or score rules
- The fixed MVP attempt rule: three normal attempts
- Status

A deadline may be optional.

**BR-HW-007 — Question composition**  
One homework assignment may contain one or more questions, and each question must use one of the nine supported assignment types.

**BR-HW-008 — Score scale**  
The assignment may use raw points internally, but its final homework score must be converted to the common 0–100 scale before homework–blitz comparison.

### Homework Lifecycle Status

The homework task lifecycle statuses are:

- **Draft**
- **Active**
- **Closed**
- **Archived**

Submission and review statuses are defined separately in Sections 14 and 15.

**BR-HW-009 — Draft homework**  
Draft homework must not be available for student completion.

**BR-HW-010 — Activation validation and scoreable points**  
Homework must not become active until required information, questions, correct-answer data for automatically checked questions, and the fixed three-attempt rule are valid. Draft Homework may temporarily have zero total points, but immediately before activation the backend must recalculate the sum of Question points and require `total_possible_points > 0`. A zero-point Homework cannot become active.

**BR-HW-011 — Active homework**  
Assigned students may start and submit active homework only while deadline, attempt, assignment, and permission rules allow it.

**BR-HW-012 — Closed Homework and in-progress attempts**  
Closing Homework immediately blocks new attempts and further Student answer changes. Every existing `in_progress` attempt must be auto-finalized by the backend using answers saved before closure: answered components are checked normally, unanswered components receive zero, and answered manual-review questions remain Waiting for teacher review. Students who never started do not receive fabricated empty Attempts. Existing submitted/finalized work may still be reviewed, and unused normal attempt capacity becomes unavailable because the Homework is closed. The auto-finalization reason is `task_closed_auto_finalize`.

**BR-HW-013 — Archived homework**  
Archived homework must be retained for history and reports and must not accept new activity.

### Deadlines

**BR-HW-014 — Optional deadline**  
A Teacher may define a homework deadline.

**BR-HW-015 — Deadline visibility**  
The Student must see the deadline before starting the homework.

**BR-HW-016 — Deadline auto-finalization**  
At the authoritative Homework deadline, the backend must immediately block new attempts and further Student answer changes. Every existing `in_progress` Homework Attempt is automatically finalized using the answers saved before the deadline. Answered components are evaluated normally, unanswered components receive zero, and answered manual-review questions remain Waiting for teacher review. A Student who never started does not receive a fabricated empty Attempt. Any unused Homework attempt capacity becomes unavailable after the deadline. The finalization reason is `homework_deadline_auto_submit`. Once this Attempt is fully checked, it remains eligible for normal Homework official-score selection unless another approved validity rule excludes it. Advanced late-submission penalties and post-deadline completion workflows are outside the MVP.

**BR-HW-017 — Deadline boundary and late requests**  
A Student submission or answer-write request is valid only if the backend receives and accepts it before the authoritative deadline. Once deadline auto-finalization wins the state transition, later writes/submits must be rejected as locked/late and must not create a second finalization. Safe retries of the already-finalized logical operation must not duplicate work.

**BR-HW-018 — Authoritative time and institution timezone**  
Deadline validation must use backend-authoritative time. Authoritative timestamps must be stored as UTC instants. Teachers enter educational dates and times in the institution’s configured IANA timezone, and educational schedules are displayed in that institution timezone. A device clock or device timezone must not change the actual deadline. Changing an institution timezone later must not change the absolute instant of an already-created deadline.

### Homework Editing and Integrity

**BR-HW-019 — Pre-attempt editing**  
The Teacher may edit homework content while it is draft and no student attempt has started.

**BR-HW-020 — Lock scoring content after first attempt**  
After any student begins an attempt, the Teacher must not change questions, answer options, correct answers, points, task recipients, or other scoring-relevant rules for that active assignment.

**BR-HW-021 — Safe metadata changes**  
Non-scoring metadata may be corrected only when it does not change the meaning or fairness of existing student work.

**BR-HW-021 — No hard deletion after activity**  
Homework with attempts, submissions, scores, or results must not be permanently deleted. It must be closed or archived.

### Homework Scoring and Visibility

**BR-HW-022 — Automatic and manual scoring**  
Automatically checkable questions may be scored by the system. Questions requiring judgment must wait for Teacher review.

**BR-HW-023 — Homework score readiness**  
Each completed Homework attempt receives a final normalized score only after all required automatic and manual checking for that attempt is complete. The official Homework score is then selected as the highest valid completed score among the Student’s available attempts.

**BR-HW-024 — Homework is not the final topic result**  
A final homework score must remain separate from the final topic result until the blitz score is available and comparison rules are applied.

**BR-HW-025 — Parent access**  
A Parent may view a connected child’s homework completion status, released score, and released feedback but must not view or edit protected answer content unless separately allowed.

---

## 8. Assignment Type and Checking Rules

### General Question Rules

**BR-Q-001 — Nine supported types**  
The MVP must support:

1. Single-choice test
2. Multiple-choice test
3. True / false question
4. Short written answer
5. Open written answer
6. File-based assignment
7. Matching task
8. Ordering task
9. Fill-in-the-blank task

**BR-Q-002 — One type per question**  
Each question must have one assignment type. A homework or blitz task may contain multiple questions of different supported types.

**BR-Q-003 — Points required**  
Every scored question or task item must have a defined point value or contribute through a defined total-score rule.

**BR-Q-004 — No negative points by default**  
The MVP should not subtract points for an incorrect answer unless a separate negative-marking rule is approved later.

**BR-Q-005 — Mixed checking**  
A task may contain both automatically checked and manually checked questions. The full task score must remain pending until all required manual checking is completed.

### Single-Choice Test

**BR-Q-006 — Single-choice structure**  
A single-choice question must have at least two answer options and exactly one correct option.

**BR-Q-007 — Single-choice checking**  
The system must check the selected option automatically. Single-choice scoring is all-or-nothing: the correct option earns the full question points, and an incorrect or unanswered option earns zero.

### Multiple-Choice Test

**BR-Q-008 — Multiple-choice structure**  
A multiple-choice question must have at least two options and one or more correct options.

**BR-Q-009 — Multiple-choice selection limit and partial credit**  
For a multiple-choice question, the maximum number of options the Student may select equals the number of correct options configured by the Teacher. The Student may select fewer options or none, but must never select more than that maximum. The Student-facing task may expose only the maximum selection count, never which options are correct. Partial credit is based only on correctly selected answers:

```text
fraction = correctly_selected_options / total_correct_options
awarded_points = question_points * fraction
```

Incorrectly selected options receive no credit and do not create an additional negative penalty. An empty answer receives zero. Flutter enforces the selection cap for UX, and the backend enforces it authoritatively.

### True / False

**BR-Q-010 — True / false structure**  
A true / false question must contain one statement and one correct Boolean value.

**BR-Q-011 — True / false checking**  
The system must check the answer automatically. True / false scoring is all-or-nothing: the correct value earns the full question points, and an incorrect or unanswered value earns zero.

### Short Written Answer

**BR-Q-012 — Short-answer modes**  
A short written answer may be:

- Automatically checked when the Teacher defines accepted answers and matching rules.
- Manually checked when judgment or explanation is required.

**BR-Q-013 — Accepted-answer requirement and short-answer scoring**  
If automatic checking is enabled, the Teacher must define at least one accepted answer. An automatically checked short written answer is all-or-nothing: a value matching an accepted answer under the approved text-normalization rules earns the full points, and a non-matching or unanswered value earns zero. If manual checking is used, the Teacher may award any valid score from zero to the question’s maximum points.

**BR-Q-013A — Automatic short-answer normalization**  
For automatic Short Written checking, the Student answer and every Teacher-defined accepted answer must pass the same deterministic normalization pipeline before exact comparison: Unicode NFC normalization, trimming leading/trailing whitespace, collapsing consecutive internal whitespace, Unicode case-fold comparison, and normalization of common Uzbek apostrophe variants. Other punctuation and technical symbols remain significant. The MVP must not use fuzzy matching, spell correction, synonym inference, or AI interpretation. If flexible judgment is needed, the question must use manual checking.

### Open Written Answer

**BR-Q-014 — Manual checking required**  
An open written answer must be checked manually by the Teacher in the MVP.

**BR-Q-015 — Teacher scoring**  
The Teacher must assign a score within the question’s allowed points and may add feedback.

### File-Based Assignment

**BR-Q-016 — MVP answer-file formats**  
File-based answers may use PDF, DOCX, PPT, or PPTX in the MVP.

**BR-Q-017 — File validation, ownership, and size**  
The uploaded file must pass format and size validation and must be connected to the correct Student, attempt, task, topic, group, and institution. The platform maximum for one Student answer file is **15 MB**. An Institution Admin may configure a lower institution limit, but the institution limit must never exceed 15 MB.

**BR-Q-018 — Manual review required**  
File-based answers require Teacher review and scoring in the MVP.

### Matching Task

**BR-Q-019 — Matching structure**  
A matching task must contain valid left-side and right-side items with a defined correct mapping.

**BR-Q-020 — Matching partial-credit checking**  
The system must check matching tasks automatically where the mapping is objective. Each correctly matched pair earns an equal share of the question’s points. Incorrect or missing pairs earn zero for that pair. No negative points are awarded.

### Ordering Task

**BR-Q-021 — Ordering structure**  
An ordering task must contain two or more items and one defined correct order.

**BR-Q-022 — Ordering partial-credit checking**  
The system must check ordering tasks automatically. Each item placed in its exact correct position earns an equal share of the question’s points. An item in the wrong position earns zero for that item. No negative points are awarded.

### Fill-in-the-Blank

**BR-Q-023 — Blank structure**  
Each blank must have one or more Teacher-defined accepted values.

**BR-Q-024 — Fill-in-the-blank partial-credit checking**  
The system must check each objective blank automatically according to the accepted-answer rules. Each correctly completed blank earns an equal share of the question’s points. An incorrect or unanswered blank earns zero for that blank. No negative points are awarded.

### Checking Completion

**BR-Q-025 — Automatic score timing**  
When all questions are automatically checkable, the system may calculate the task score immediately after valid submission.

**BR-Q-026 — Manual-review status**  
When any required answer needs Teacher judgment, the submission must enter **Waiting for teacher review**.

**BR-Q-027 — Final task score**  
A task score must not be treated as final until all required questions have a score.

**BR-Q-028 — Teacher answer boundary**  
The Teacher may score and comment on a Student’s answer but must not rewrite the Student’s submitted answer.

**BR-Q-029 — AI exclusion**  
AI-generated checking, AI-generated scoring, and AI-generated feedback are outside the MVP.

---

## 9. Attempt Rules

### Fixed MVP Attempt Model

**BR-ATT-001 — Homework has three normal attempts**  
Every Homework assignment in the MVP must allow a Student up to **three normal attempts**. Institution Admins and Teachers must not increase or decrease this normal Homework attempt count in the MVP.

**BR-ATT-002 — Homework official score uses the highest valid completed attempt**  
The official Homework score is the highest normalized score among the Student’s valid completed and fully checked Homework attempts. A Student does not need to use all three attempts. If only one or two valid completed attempts exist, the highest score among those completed attempts becomes the official Homework score.

**BR-ATT-003 — No fourth normal Homework attempt**  
After the Student has used three normal Homework attempts, the system must block a fourth normal attempt. The approved MVP does not include a Teacher-granted extra Homework attempt.

**BR-ATT-004 — Blitz has one normal attempt**  
Every Blitz task in the MVP must allow **one normal attempt** per assigned Student.

**BR-ATT-005 — One approved additional Blitz attempt**  
If a Student cannot complete the normal Blitz attempt, or cannot finish it fully, because of a technical problem or another valid reason, an authorized Teacher may approve **one additional Blitz attempt** for that specific Student. A Student must never receive more than one such additional Blitz attempt for the same Blitz task in the MVP.

### Attempt Visibility and Recording

**BR-ATT-006 — Student visibility**  
Before starting a task, the Student must be able to see the applicable attempt information:

- Homework: three normal attempts, attempts already used, and attempts remaining.
- Blitz: one normal attempt, plus whether an additional Teacher-approved exception attempt has been granted.
- Whether another attempt is currently allowed.

**BR-ATT-007 — Attempt ownership**  
Every attempt must belong to exactly one Student and one task and must remain connected to the correct institution, group, topic, and task.

**BR-ATT-008 — Attempt numbering**  
Attempts must be numbered sequentially per Student and task.

**BR-ATT-009 — Attempt history**  
All started/submitted attempts and approved invalidated Blitz attempts must remain in authorized history. A later attempt must not overwrite an earlier attempt.

### Attempt Restrictions

**BR-ATT-010 — No attempt after exhaustion**  
When the Student has used all normal attempts and has no unused approved Blitz exception attempt, the system must block a new attempt.

**BR-ATT-011 — No attempt after closure**  
A Student must not start a new attempt when the task is closed or archived.

**BR-ATT-012 — Deadline and time restrictions**  
A Student must not start or submit a new Homework attempt after the Homework deadline. A Student must not start a Blitz attempt unless the Blitz is active and the applicable timing rules allow it.

**BR-ATT-013 — Assignment required**  
A Student must not use an attempt for a task that is not assigned to that Student.

### Technical Problems and Blitz Exceptions

**BR-ATT-014 — Valid exception reasons**  
A Blitz exception may be granted only for a technical problem or another valid reason that prevented the Student from completing the normal Blitz attempt fairly. The exception is not a normal retry for improving a low valid score.

**BR-ATT-015 — Teacher approval and reason required**  
Only an authorized Teacher for the Student’s group/topic may approve the additional Blitz attempt. The Teacher must record a reason for the exception.

**BR-ATT-016 — Invalidated Blitz attempt remains in history**  
When the Teacher approves an exception because the normal Blitz attempt was invalid or interrupted, that attempt must remain in history and must be marked as invalidated by approved exception. It must not contribute to the official Blitz score.

**BR-ATT-017 — Additional Blitz attempt becomes the score source**  
When an approved exception invalidates the normal Blitz attempt, the valid completed additional attempt becomes the official Blitz attempt after all required checking is complete.

### Official Score Selection

**BR-ATT-018 — Exactly one official task score**  
Before Homework–Blitz comparison, the system must identify exactly one official Homework score and exactly one official Blitz score for the Student and topic.

**BR-ATT-019 — Homework selection policy is highest valid score**  
The official Homework score must be selected automatically as the highest normalized score among up to three valid completed Homework attempts. If multiple eligible attempts have exactly the same highest normalized score, the earliest such attempt — the one with the lowest `attempt_number` — becomes `official_attempt_id`. The numeric official score remains the shared highest score.

**BR-ATT-020 — Blitz selection policy is the valid allowed attempt**  
Normally, the Student’s single valid completed Blitz attempt is the official Blitz score. If that normal attempt is invalidated through an approved exception, the valid completed additional attempt is used instead. A valid completed low Blitz score must not be replaced merely to improve the Student’s result.

---

## 10. Blitz Task Rules

### Purpose and Ownership

**BR-BLZ-001 — In-class verification**  
A Blitz task is a short in-class task used to verify the Student’s real understanding of the same topic studied through materials and Homework.

**BR-BLZ-002 — Manual creation in the MVP**  
The Teacher must create Blitz tasks manually. AI-generated Blitz tasks are outside the MVP.

**BR-BLZ-003 — Required connection**  
Every result-bearing Blitz task must be connected to:

- One institution
- One owning Teacher
- The whole Topic group
- One Topic
- The designated official Homework assignment for that Topic

A Blitz assigned only to selected Students may be used for supplementary/practice work but cannot be result-bearing.

**BR-BLZ-004 — Authorized creator**  
Only a Teacher authorized for the group and topic may create or manage the Blitz task.

**BR-BLZ-005 — Official result-bearing Blitz**  
A Topic may contain multiple Blitz tasks, but exactly one **whole-group** Blitz must be designated as the official result-bearing Blitz. Only that Blitz’s official Student score is compared with the designated official Homework score for the final Topic result. A selected-Students Blitz is not eligible for official designation.

### Blitz Structure

**BR-BLZ-006 — Required information**  
A Blitz task must contain:

- Title
- Topic
- Assigned group or Students
- Student instructions
- At least one valid question
- Points or score rules
- One whole-task duration configured by the Teacher
- The institution-defined timer-start mode
- The fixed one-normal-attempt rule
- Status

**BR-BLZ-007 — Supported question types**  
A Blitz task may use the same nine assignment types as Homework.

**BR-BLZ-008 — Fast question types preferred**  
Single-choice, multiple-choice, true / false, short written answer, matching, ordering, and fill-in-the-blank are preferred for the approximately 5–10 minute classroom context. Open written and file-based questions are permitted but less suitable.

### Blitz Lifecycle

The Blitz task lifecycle statuses are:

- **Draft**
- **Scheduled**
- **Active**
- **Closed**
- **Archived**

Review status belongs to each Student submission and is handled separately.

**BR-BLZ-009 — Draft and scheduled restrictions**  
Students must not answer draft or scheduled Blitz tasks before activation.

**BR-BLZ-010 — Teacher activation and scoreable points**  
Only an authorized Teacher may activate the Blitz task during class. Draft/Scheduled Blitz may temporarily have zero total points, but immediately before activation the backend must recalculate Question points and require `total_possible_points > 0`; otherwise activation is rejected.

**BR-BLZ-011 — Active-only answering**  
A Student may start or answer the Blitz only while it is active, assigned, within the applicable timing rule, and within the allowed normal or approved exception attempt.

**BR-BLZ-012 — Closing/archiving and in-progress attempts**  
Closing an active Blitz immediately blocks new attempts and further Student answer changes. Every existing `in_progress` attempt is auto-finalized using saved answers: answered components are evaluated normally, unanswered components receive zero, and answered manual-review questions remain Waiting for teacher review. Students who never started do not receive fabricated empty Attempts. The finalization reason is `task_closed_auto_finalize`. Archived Blitz tasks accept no new activity.

### Whole-Task Duration and Timer-Start Modes

**BR-BLZ-013 — Teacher-configured whole-task duration**  
The Teacher must configure one duration for the entire Blitz task. The MVP does not use separate per-question timers. The intended Blitz activity is approximately 5–10 minutes, but the Teacher may choose an appropriate whole-task duration based on the question count and classroom needs.

**BR-BLZ-014 — Institution-configured timer-start mode**  
Each institution must configure exactly one of these Blitz timer-start modes:

1. **Synchronized start** — the countdown starts for all assigned Students at the moment the Teacher activates the Blitz.
2. **Individual Student start** — Teacher activation makes the Blitz available, but each Student receives the full configured duration beginning when that Student starts the Blitz attempt.

The Institution Admin controls this institution-wide rule. A Teacher must not override the institution timer-start mode for one task.

**BR-BLZ-015 — Synchronized timer calculation**  
In synchronized mode, all Students share the same authoritative activation/end window. A Student who opens the Blitz later receives only the time remaining in that common window.

**BR-BLZ-016 — Individual timer calculation**  
In individual-start mode, each Student’s authoritative end time is based on that Student’s server-recorded attempt start time plus the Teacher-configured Blitz duration.

**BR-BLZ-017 — Backend time is authoritative**  
Blitz timing must use backend-authoritative timestamps and durations. Changing a Student device clock or timezone must not provide more time.

**BR-BLZ-018 — Remaining time visibility**  
The Student must clearly see the remaining time while answering.

### Timeout and Automatic Finalization

**BR-BLZ-019 — Stop editing at timeout**  
When the applicable Blitz timer reaches zero, the system must immediately stop accepting new or changed answers for that attempt.

**BR-BLZ-020 — Automatic timeout finalization**  
At timeout, the system must automatically finalize the Student’s attempt using all answers successfully saved before the authoritative end time. The Student does not need to press Submit after the timer reaches zero.

**BR-BLZ-021 — Unanswered questions receive zero**  
Any Blitz question the Student did not answer before timeout must be treated as unanswered and must receive zero points. For a multi-part question, any unanswered component receives zero according to the approved partial-credit rules.

**BR-BLZ-022 — Answered questions are checked normally**  
Answers saved before timeout must be evaluated normally according to their question type. Automatically checkable answers may be scored immediately. Answers that require Teacher judgment must enter Waiting for teacher review rather than being treated as incorrect merely because automatic scoring is unavailable.

### Monitoring

**BR-BLZ-023 — Teacher monitoring**  
While a Blitz is active, the Teacher may view participation information such as:

- Assigned Student
- Access status
- Started status
- In-progress status
- Submission/finalization status
- Time spent or time remaining where applicable
- Attempt number
- Review status
- Approved exception status
- Technical issue status where available

**BR-BLZ-024 — Monitoring does not change answers**  
Teacher monitoring must not allow the Teacher to answer on behalf of a Student or change the Student’s live answers.

### Checking and Result Use

**BR-BLZ-025 — Automatic and manual checking**  
The same automatic/manual checking and partial-credit rules used for assignment types apply to Blitz submissions.

**BR-BLZ-026 — Blitz score readiness**  
The Blitz score becomes final only after all required automatic and manual checking is complete.

**BR-BLZ-027 — Comparison readiness**  
A final topic calculation must wait until the official Blitz score and official Homework score are both available.

**BR-BLZ-028 — No advanced anti-cheating in the MVP**  
Device monitoring, QR entry, live competition, advanced anti-cheating, adaptive difficulty, and real-time advanced analytics are outside the MVP.

---

## 11. Homework–Blitz Comparison Rules

### Pairing Requirements

**BR-CMP-001 — Correct score pair**  
The system must compare only the official homework score and official blitz score that belong to the same:

- Institution
- Student
- Topic
- Group or assignment scope
- Designated homework assignment
- Designated blitz task

**BR-CMP-002 — Common score scale**  
Both scores must be represented on the same 0–100 scale before comparison.

**BR-CMP-003 — Both scores required**  
The system must not perform the full comparison until both official scores are available.

**BR-CMP-004 — Manual review completion**  
A score waiting for required Teacher review is not available for final comparison.

### Difference Calculation

Let:

- `H` = official homework score on the 0–100 scale
- `B` = official blitz score on the 0–100 scale
- `D` = absolute score difference
- `T` = institution’s acceptable score-difference threshold

The difference is:

```text
D = |H - B|
```

**BR-CMP-005 — Absolute difference**  
The system must use the absolute difference, so the rule works the same whether homework or blitz is higher.

**BR-CMP-006 — Configurable threshold**  
Each institution must be able to define `T`.

**BR-CMP-007 — Close scores**  
Scores are considered close when:

```text
D <= T
```

**BR-CMP-008 — Large difference**  
Scores are considered very different when:

```text
D > T
```

### Consistency Meaning

**BR-CMP-009 — Consistent result**  
When `D <= T`, the system must mark homework and blitz as consistent.

**BR-CMP-010 — Inconsistent result**  
When `D > T`, the system must mark homework and blitz as inconsistent.

**BR-CMP-011 — Inconsistency is not an accusation**  
An inconsistent result must not automatically label the Student as cheating. It indicates only that the homework and in-class performance do not match closely.

**BR-CMP-012 — Higher blitz case**  
The same rule must apply when the blitz score is higher than the homework score. Possible explanations may include improvement, a technical homework issue, misunderstanding of the homework, or incomplete home work.

### Examples

**Example A — Close scores**

```text
Homework score: 85
Blitz score: 80
Difference: 5
Acceptable difference: 10
Result consistency: Consistent
```

**Example B — Homework much higher**

```text
Homework score: 95
Blitz score: 55
Difference: 40
Acceptable difference: 10
Result consistency: Inconsistent
```

**Example C — Blitz much higher**

```text
Homework score: 45
Blitz score: 82
Difference: 37
Acceptable difference: 10
Result consistency: Inconsistent
```

### Rule Snapshot and Changes

**BR-CMP-013 — Save threshold used**  
The final result must record the acceptable-difference threshold used for its calculation.

**BR-CMP-014 — No silent historical recalculation**  
Changing the institution threshold must not silently change already closed historical results.

**BR-CMP-015 — Recalculate before closure when inputs change**  
If an authorized correction changes an underlying official homework or blitz score before the final result is closed, the system must recalculate the result using the applicable saved or current rule according to the approved result lifecycle.

---

## 12. Final Result Calculation Rules

### Preconditions

**BR-RES-001 — Required inputs**  
The final numeric topic result requires:

- One official homework score
- One official blitz score
- Completed required manual checking
- A valid institution acceptable-difference threshold
- Valid category ranges

**BR-RES-002 — No final numeric score with missing required work**  
When required homework or blitz is missing, the system must not invent a numeric final score.

### Calculation Formula

When scores are close:

```text
If D <= T:
    Final score = (H + B) / 2
```

When scores are very different:

```text
If D > T:
    Final score = B
```

**BR-RES-003 — Average for close scores**  
When `D <= T`, the system must use the arithmetic average of homework and blitz scores.

**BR-RES-004 — Blitz score for large difference**  
When `D > T`, the system must use the blitz score as the final real result.

**BR-RES-005 — Same rule in both directions**  
The blitz score must be used when the difference is large even when the blitz score is higher than homework.

**BR-RES-006 — No other formula in the MVP**  
Weighted averages, Teacher-selected formulas, AI predictions, and custom formulas beyond the approved rule are outside the MVP.

### Saved Result Data

**BR-RES-007 — Result record contents**  
The final result must retain, at minimum:

- Institution
- Student
- Topic
- Designated homework assignment
- Designated blitz task
- Official homework score
- Official blitz score
- Absolute score difference
- Acceptable-difference threshold used
- Calculation method
- Final score when calculated
- Consistency status
- Understanding category
- Result status
- Visibility state
- Relevant attempt references
- Teacher feedback if available

**BR-RES-008 — Calculation method values**  
The result must identify whether it was produced by:

- Average of homework and blitz
- Blitz score because of a large difference
- Waiting because required input or review is incomplete
- Not completed because required work was not completed

### Manual Corrections and Closure

**BR-RES-009 — No direct final-score manipulation**  
A Teacher must not directly type a different final score that bypasses the approved calculation formula.

**BR-RES-010 — Correct underlying score instead**  
Before result closure, an authorized Teacher may correct a manually reviewed question or task score when the original review was wrong. The system must then recalculate the final result.

**BR-RES-011 — Result closure preconditions and stability**  
A Teacher may close one Student’s Topic Result only when that Student has reached a terminal educational state: either (a) a fully calculated numeric result with both official task scores available, all required manual review complete, and no relevant `in_progress` or pending replacement Blitz attempt; or (b) a definitive **Not completed** outcome after required work can no longer validly be completed. Waiting for Homework, Waiting for Blitz, and Waiting for teacher review cannot be closed. Closure is Student-and-Topic-specific and does not require class-wide tasks to be closed. Result release/visibility is independent and is not a prerequisite for closure. After closure, official scores, manual scoring, Blitz exceptions, result-pair/cohort changes, recalculation, final score, consistency, and category are immutable in the MVP; permitted visibility/release actions remain separate. Formal appeals and post-closure revision workflows are outside the MVP.

**BR-RES-012 — Calculation precision, display rounding, and category score**  
Homework normalization, Blitz normalization, score-difference comparison, threshold evaluation, and final-score calculation use unrounded internal values with no intermediate rounding. User-facing Homework, Blitz, and final scores are displayed rounded to **one decimal place** using standard mathematical rounding. For understanding-category assignment only, the system derives an integer `category_score` from the final internal score: a fractional part from `.0` through `.5` rounds down to the lower integer; a fractional part greater than `.5` rounds up to the next integer. The category is resolved from this integer score, not from the one-decimal display value and not directly from the unrounded decimal score.

### Examples

**Close-score example**

```text
Homework score: 88
Blitz score: 84
Difference: 4
Acceptable difference: 10
Final score: (88 + 84) / 2 = 86
Calculation method: Average
Consistency: Consistent
```

**Large-difference example**

```text
Homework score: 92
Blitz score: 58
Difference: 34
Acceptable difference: 10
Final score: 58
Calculation method: Blitz score
Consistency: Inconsistent
```

---

## 13. Understanding Category Rules

### Approved Categories

**BR-CAT-001 — Five MVP categories**  
The MVP must support:

1. **Understood well**
2. **Partially understood**
3. **Needs revision**
4. **Needs teacher support**
5. **Not completed**

**BR-CAT-002 — Fixed category meaning**  
The meaning of these five categories is fixed in the MVP. Custom category names are future scope.

### Numeric Category Ranges

**BR-CAT-003 — Institution-configured integer ranges**  
Each institution may configure inclusive **integer** score ranges for the first four categories. Category configuration applies to the derived integer `category_score`, not directly to a decimal final score.

**BR-CAT-004 — Full integer coverage**  
The configured ranges must cover every integer from 0 through 100 exactly once, without gaps or overlaps.

**BR-CAT-005 — Ordered ranges**  
Category ranges must remain logically ordered from lowest to highest understanding.

**BR-CAT-006 — Inclusive integer boundaries**  
Range boundaries are inclusive integers. For example:

- 86–100: Understood well
- 66–85: Partially understood
- 50–65: Needs revision
- 0–49: Needs teacher support

These are examples, not mandatory universal ranges.

**BR-CAT-007 — One category per calculated result using `category_score`**  
After the final internal score is calculated, the backend derives exactly one integer `category_score`: fractions `.0` through `.5` round down, while fractions greater than `.5` round up. The category resolver then maps that integer to exactly one configured category range. Example: `85.5 → 85` and `85.6 → 86`.

### Not Completed

**BR-CAT-008 — Not completed is not a numeric score band**  
The **Not completed** category must be based on missing required work, not a low numeric score.

**BR-CAT-009 — Not completed trigger**  
If required homework or blitz was not completed after the applicable attempts, deadline, active period, or task closure, the final topic result may receive **Not completed**.

**BR-CAT-010 — Show missing component**  
The system must show whether the missing component is:

- Homework
- Blitz task
- Both homework and blitz

**BR-CAT-011 — Waiting for review is not Not completed**  
A submission waiting for Teacher review must not receive **Not completed**.

**BR-CAT-012 — Not released is not Not completed**  
A calculated result that has not been released to the Student or Parent must not receive **Not completed** for that reason.

### Category Changes and Visibility

**BR-CAT-013 — Save category rule snapshot**  
The result must retain the category range used when the result was calculated or closed.

**BR-CAT-014 — Future setting changes**  
Changing institution category ranges must apply to future or explicitly recalculated open results, not silently rewrite closed historical results.

**BR-CAT-015 — Teacher visibility**  
The Teacher may view the category for assigned Students when the result is available.

**BR-CAT-016 — Student and Parent visibility**  
Students and Parents may view the category only according to result-visibility rules.

---

## 14. Result Status and Visibility Rules

To avoid ambiguity, TestLabUz must separate four different state types:

1. **Task lifecycle status** — whether a topic, homework, or blitz task is draft, active, closed, or archived.
2. **Submission/review status** — what happened with one Student’s task attempt.
3. **Result calculation status** — whether the final topic result can be calculated.
4. **Result visibility** — whether the calculated or incomplete result is visible to the Student or Parent.

### Task Lifecycle Statuses

**BR-STAT-001 — Topic lifecycle**  
Topic lifecycle: Draft, Active, Closed, Archived.

**BR-STAT-002 — Homework lifecycle**  
Homework lifecycle: Draft, Active, Closed, Archived.

**BR-STAT-003 — Blitz lifecycle**  
Blitz lifecycle: Draft, Scheduled, Active, Closed, Archived.

### Submission and Review Statuses

The MVP may use these Student-level submission statuses:

- Not started
- In progress
- Submitted
- Waiting for teacher review
- Checked
- Invalidated by approved exception (Blitz only)
- Not completed

**BR-STAT-004 — Status belongs to the Student submission**  
Submitted, waiting for review, checked, invalidated-by-exception, and not-completed states must be tracked per Student submission or requirement, not used as a replacement for task lifecycle status. A Blitz timeout does not create an expired attempt; it automatically finalizes the attempt under the approved timeout rule.

### Result Calculation Statuses

The MVP result calculation statuses are:

- **Waiting for homework**
- **Waiting for blitz task**
- **Waiting for teacher review**
- **Calculated**
- **Not completed**
- **Closed**

**BR-STAT-005 — Waiting for homework**  
Use this status while required homework or its official score is not yet available and the task may still be completed or reviewed.

**BR-STAT-006 — Waiting for blitz task**  
Use this status while the required blitz or its official score is not yet available and the task may still be completed or reviewed.

**BR-STAT-007 — Waiting for teacher review**  
Use this status when submitted homework or blitz answers still require manual scoring.

**BR-STAT-008 — Calculated**  
Use this status after both official scores are available, the formula has been applied, and a category has been assigned.

**BR-STAT-009 — Not completed**  
Use this status when required work was not completed and the applicable completion window has ended.

**BR-STAT-010 — Closed**  
Use this status when the final result is finalized and no further changes are permitted in the MVP.

### Visibility State

**BR-STAT-011 — Visibility is independent**  
A result’s calculation status and visibility must be stored and evaluated separately.

**BR-STAT-012 — Teacher access**  
The authorized Teacher must be able to view calculation and review statuses for assigned Students even when the result is not released.

**BR-STAT-013 — Student result-release modes**  
Each institution must configure one Student result-release mode:

- **Automatic** — the Student’s result becomes visible automatically after the result is fully calculated and all required checking is complete.
- **Manual Teacher release** — the result may be fully calculated and visible to the Teacher, but remains hidden from the Student until an authorized Teacher releases it.

**BR-STAT-014 — Parent result-visibility modes**  
Each institution must configure one Parent result-visibility mode:

- **With Student release** — a connected Parent receives access automatically when the Student result is released.
- **Manual Teacher release** — the Parent remains unable to see the result until an authorized Teacher releases it to Parents.
- **Hidden** — Parents do not receive the result.

**BR-STAT-015 — Parent cannot receive a result before the Student**  
A Parent result must never become visible before that Student’s result has been released to the Student, regardless of the Parent visibility mode.

**BR-STAT-016 — Separate Student and Parent visibility**  
Student visibility and Parent visibility must be stored/evaluated separately so the institution’s approved modes can be enforced.

**BR-STAT-017 — Non-release does not change result**  
Hiding or releasing a result must not change the scores, formula, category, consistency, or calculation status.

**BR-STAT-018 — Incomplete-status visibility**  
The system may show allowed progress statuses such as waiting for review or not completed without exposing unreleased scores.

**BR-STAT-019 — Teacher release authority**  
When the institution uses a manual release mode, only an authorized Teacher for the relevant Topic/Student may perform the release action. Institution configuration determines whether manual release is required for Students and/or Parents.

---

## 15. Submission and Editing Rules

### Starting and Saving Work

**BR-SUB-001 — Own-task submission only**  
A Student may start or submit only a task assigned to that Student.

**BR-SUB-002 — Valid active context required**  
The task, Student account, and institution must be active, and deadline/time/attempt rules must permit the action.

**BR-SUB-003 — One Student owns the attempt**  
An attempt and submission must be permanently connected to the authenticated Student. Another Student or Parent must not submit on that Student’s behalf.

**BR-SUB-004 — In-progress saving is optional**  
The platform may save in-progress answers when supported. Auto-save and offline drafts are not mandatory MVP requirements.

### Final Submission

**BR-SUB-005 — Explicit submission and authoritative auto-finalization**  
For Homework, the Student may explicitly submit an in-progress Attempt before the deadline; if the authoritative Homework deadline arrives first, the backend automatically finalizes the saved Attempt according to the Homework deadline rules. For Blitz, the Student may explicitly submit before time expires; if the timer reaches zero first, the backend automatically finalizes the saved Attempt according to the Blitz timeout rules.

**BR-SUB-006 — Submission validation**  
Before accepting a final submission, the system must validate:

- Student assignment
- Task status
- Attempt availability
- Deadline or blitz time
- Required answers where applicable
- File type and size where applicable
- Institution and group scope

**BR-SUB-007 — Record submission information**  
A valid submission must record:

- Student
- Institution
- Group
- Topic
- Task
- Attempt number
- Answers and file references
- Submission time
- Checking status
- Score when available
- Teacher feedback when added

**BR-SUB-008 — Final submission locks the attempt**  
After final submission, the Student must not change that attempt’s answers.

**BR-SUB-009 — New attempt is separate**  
When another attempt is allowed, it must create a separate attempt record rather than modifying the previous submitted attempt.

### Editing Restrictions

**BR-SUB-010 — No editing after limits end**  
A Student must not change answers after:

- Final submission
- Task closure
- Homework deadline
- Blitz timeout
- Attempt exhaustion
- Result closure

**BR-SUB-011 — Teacher must not rewrite answers**  
A Teacher may score and comment on submitted answers but must not alter the Student’s answer content.

**BR-SUB-012 — Parent read-only**  
A Parent must not edit or submit any Student learning data.

**BR-SUB-013 — Admin boundary**  
Institution Admins and Super Admins must not normally edit Student submissions.

### File Submissions

**BR-SUB-014 — File ownership**  
A submitted file must belong to the Student’s specific attempt and must not be reused as another Student’s submission without a new authorized upload.

**BR-SUB-015 — Failed or oversized upload**  
A file upload that fails validation, exceeds the effective institution/platform limit, or does not complete successfully must not be treated as a valid submitted answer. The platform maximum for one Student answer file is 15 MB, and an institution may configure only a lower limit.

**BR-SUB-016 — Protected file retrieval**  
Only the submitting Student and authorized Teacher or permitted institution users may access the submitted file. Parent access is limited to allowed progress information unless file viewing is separately approved.

### Retention and Deactivation

**BR-SUB-017 — Preserve submitted work**  
Submitted attempts and final scores must not be deleted merely because a Student, Teacher, group, or institution is later deactivated or archived.

**BR-SUB-018 — No destructive cleanup in the MVP**  
Permanent deletion of submitted attempts, checked answers, or final results is outside the normal MVP workflow.

---

## 16. Access and Permission Rules

### Authentication and Base Access

**BR-ACL-001 — Authentication required**  
Protected platform data and actions require an authenticated account.

**BR-ACL-002 — Active user and institution required**  
The system must verify both user status and institution status before allowing institution functionality.

**BR-ACL-003 — Role identification**  
After login, the system must identify the user’s role and open only the appropriate role interface.

**BR-ACL-004 — Navigation is not authorization**  
Hidden navigation, buttons, or screens must not replace server-side permission checks.

### Scope Checks

For every protected request, the system must check, where applicable:

1. Authentication
2. Active user status
3. Active institution status
4. User role
5. Institution ownership
6. Group relationship
7. Topic/task assignment
8. Teacher ownership or assignment
9. Student ownership
10. Parent-child relationship
11. Record lifecycle status
12. Deadline, time, and attempt rules
13. View or edit permission

**BR-ACL-005 — All applicable checks required**  
The action may proceed only when all applicable checks pass.

### Role Access Matrix

| Area | Super Admin | Institution Admin | Teacher | Student | Parent |
|---|---|---|---|---|---|
| Platform institutions | Manage | No | No | No | No |
| Own institution profile | Platform support | Manage allowed fields | View if needed | No | No |
| Teacher/Student/Parent accounts | Platform support boundary | Manage own institution | No | No | No |
| Groups | Platform overview only | Manage own institution | View assigned | View own membership context | View child context only |
| Topics | No routine editing | View institution activity | Manage own assigned topics | View assigned | View child progress if allowed |
| Learning materials | No routine editing | Support/view boundary | Manage own topic files | View assigned | Not required in MVP |
| Homework | No routine editing | Overview only | Create/manage/check assigned | Complete assigned | View child progress if allowed |
| Blitz | No routine editing | Overview only | Create/activate/check assigned | Complete active assigned | View child result if allowed |
| Submissions | No routine editing | Summary/management boundary | Review assigned | View own | Progress only |
| Scores/results | Platform statistics | Institution summaries | View assigned and score manual work | View own if released | View child if allowed |
| Institution settings | Global platform settings only | Manage own institution | Task-level settings only | No | No |

### View and Edit Separation

**BR-ACL-006 — View does not imply edit**  
Permission to view a record must not automatically grant permission to edit it.

**BR-ACL-007 — Parent view-only**  
Parent access is read-only in the MVP.

**BR-ACL-008 — Student own-data restriction**  
A Student may view only their own submissions and released results.

**BR-ACL-009 — Teacher assigned-data restriction**  
A Teacher may view and manage only assigned groups, students, topics, tasks, and results.

**BR-ACL-010 — Institution Admin scope**  
An Institution Admin may manage users and structure only inside their institution and may view institution-level progress summaries.

### Protected Actions

Specific permission checks must protect at least:

- Creating and editing users
- Activating and deactivating users
- Creating and editing groups
- Assigning students to groups
- Assigning Teachers to groups
- Connecting Parents to Students
- Creating and editing topics
- Uploading, replacing, and removing materials
- Creating and editing homework
- Creating and editing blitz tasks
- Activating and closing blitz tasks
- Starting and submitting attempts
- Checking manual answers
- Assigning scores and feedback
- Approving one additional Blitz attempt for a valid exception and recording its reason
- Configuring the institution Blitz timer-start mode
- Configuring acceptable score difference
- Configuring category ranges
- Configuring Student result-release mode
- Configuring Parent result-visibility mode
- Configuring institution timezone
- Configuring lower institution upload limits within platform maxima
- Releasing results when the configured mode requires Teacher release
- Viewing reports
- Activating and deactivating institutions

**BR-ACL-011 — No cross-scope record IDs**  
A valid record identifier must not grant access when the user lacks the required institution or relationship scope.

**BR-ACL-012 — Report filters remain restricted**  
A report filter must not reveal data the user could not access directly.

**BR-ACL-013 — File access uses the same scope**  
Learning materials and submitted files must use the same institution, group, topic, Student, and relationship checks as their connected records.

### Permission Denial

**BR-ACL-014 — Block unauthorized action**  
When a check fails, the system must not return protected data or perform the requested change.

**BR-ACL-015 — Clear messages**  
The system should show a clear message such as:

- “You do not have permission to access this page.”
- “This group is not assigned to you.”
- “This task is not assigned to you.”
- “This blitz task is not active.”
- “This task is closed.”
- “You have used all attempts.”
- “This Student is not connected to your account.”
- “You cannot access data from another institution.”
- “This result is not available yet.”
- “Your account is inactive.”
- “Your institution is inactive.”

**BR-ACL-016 — Do not expose private details**  
A denial message must not reveal private information about a record the user is not allowed to know exists.

### Device Consistency

**BR-ACL-017 — Same security on every device**  
Desktop and mobile may show different role-appropriate features, but they must apply the same access boundaries.

### MVP Security Boundary

**BR-ACL-018 — Advanced security outside MVP**  
Custom roles, two-factor authentication, device management, IP restrictions, enterprise identity, advanced session controls, suspicious-activity detection, advanced file scanning, impersonation, and detailed audit analytics are outside the MVP.

---

## 17. MVP Business Rule Scope

### Rules Included in the MVP

The MVP business-rule scope must include:

1. Five approved roles.
2. Active and inactive users.
3. Active and inactive institutions.
4. Multi-institution data separation.
5. Group-based Teacher and Student access.
6. Parent-child relationship access.
7. Topic ownership and lifecycle.
8. PDF, DOCX, PPT, and PPTX learning materials.
9. Multiple Homework/Blitz tasks may exist per Topic, but exactly one whole-group Homework + one whole-group Blitz form the official result-bearing pair; selected-Student tasks are practice-only and both official tasks share one snapshotted Topic cohort.
10. Nine supported assignment types.
11. Automatic checking where the answer is objective.
12. Manual Teacher checking where judgment is required.
13. Exactly three normal Homework attempts, with the highest valid completed score becoming official.
14. Exactly one normal Blitz attempt, plus at most one Teacher-approved additional attempt for a valid technical or other valid reason.
15. Optional Homework deadlines.
16. Manual Teacher creation of Blitz tasks.
17. Teacher-controlled Blitz activation and Teacher-configured whole-task duration.
18. Institution-configured synchronized or individual Student Blitz timer-start mode.
19. Automatic Blitz finalization at timeout with unanswered questions receiving zero.
20. Recording one official Homework score and one official Blitz score.
21. Partial-credit scoring for multiple-choice, matching, ordering, and fill-in-the-blank according to the approved rules.
22. Automatic/manual scoring for the remaining supported question types according to the approved rules.
23. Absolute Homework–Blitz score difference using unrounded internal values.
24. Institution-configured acceptable score difference.
25. Average score when results are close.
26. Blitz score when the difference is large.
27. One-decimal user-facing score display, unrounded calculation logic, and integer `category_score` category resolution.
28. Consistency and inconsistency labels without automatic accusations.
29. Five understanding categories.
30. Institution-configured inclusive integer category ranges.
31. A non-numeric **Not completed** category for missing required work.
32. Separate task, submission, result, and visibility states.
33. Institution-configured Student release mode: automatic or manual Teacher release.
34. Institution-configured Parent visibility mode: with Student release, manual Teacher release, or hidden.
35. Teacher result review and release actions where configured.
36. Platform upload maxima of 25 MB for learning materials and 15 MB for Student answer files, with institutions allowed to configure lower limits.
37. UTC authoritative timestamps with one configurable IANA timezone per institution.
38. Basic institution and group progress summaries.
39. Server-side role and record-scope permission checks.
40. Historical preservation through closure, archiving, deactivation, and invalidated Blitz-attempt history.

### Rules Excluded from the MVP

The MVP must not require business rules for:

- AI-generated content or checking
- Audio or video materials and answers
- Speaking or listening tasks
- Coding assignments
- Group projects or peer review
- Plagiarism detection
- Advanced rubrics
- Question banks and random question generation
- Advanced anti-cheating or device monitoring
- Live classroom competition
- Predictive analytics
- Teacher-performance analysis
- Communication or chat
- Notifications and reminders
- Billing, subscriptions, invoices, or paid plans
- External integrations
- Custom role creation
- Complex institution branding
- Advanced audit workflows
- Offline synchronization
- Gamification or certificates
- Complex course-builder logic
- Formal result appeals or approval chains

### Resolved MVP Business Decisions

The previously open MVP decisions are now approved and are mandatory:

1. **Homework attempts and official score** — Homework allows exactly three normal attempts. The highest valid completed, fully checked normalized score becomes the official Homework score.
2. **Blitz attempts and exception** — Blitz allows exactly one normal attempt. For a valid technical or other valid reason, an authorized Teacher may grant one additional attempt to that Student, must record a reason, and the invalidated original attempt remains in history but is excluded from scoring.
3. **Blitz timer-start mode** — Each institution selects synchronized start or individual Student start. The Teacher configures one whole-task duration; there are no per-question timers in the MVP.
4. **Blitz timeout** — At the authoritative timeout, the attempt is automatically finalized with saved answers. Unanswered questions/components receive zero; answered manual-review questions wait for Teacher review.
5. **Partial credit** — Multiple-choice limits Student selections to the number of correct options and awards credit only for correctly selected answers; matching uses correct pairs; ordering uses correctly positioned items; fill-in-the-blank uses correctly completed blanks. Single-choice, true/false, and automatically checked short answers are all-or-nothing. Manual written/file answers are scored by the Teacher within allowed points.
6. **Score precision, display, and category rounding** — Homework/Blitz comparison and final-score calculation use unrounded internal values. User-facing scores display one decimal place. Category assignment uses the derived integer `category_score`: `.0`–`.5` rounds down and `>.5` rounds up.
7. **Result release** — Student mode is either automatic or manual Teacher release. Parent mode is with Student release, manual Teacher release, or hidden. A Parent must never receive the result before the Student.
8. **Upload limits** — Platform maximum is 25 MB per learning-material file and 15 MB per Student answer file. Institutions may configure lower, never higher, limits.
9. **Timezone** — Authoritative instants are stored as UTC. Each institution uses one configurable IANA timezone for educational date/time entry and display; device time does not control validity, and timezone changes do not alter historical absolute instants.
10. **Result-bearing tasks** — A Topic may contain multiple Homework and Blitz tasks, but exactly one whole-group Homework + one whole-group Blitz form the eventual official result-bearing pair. Selected-Student tasks are practice-only. The first activated official task establishes the persisted official cohort, and the later task reuses it. Student activity locks the already-designated task/cohort; attaching a previously absent official Blitz completes the pair and is not replacement.

These decisions are no longer implementation choices. Backend, frontend, database, API contracts, tests, and Codex tasks must implement them consistently.

### Post-Audit MVP Rules

The final cross-document audit added the following mandatory clarifications:

1. Automatic Short Written checking uses deterministic normalized exact matching: Unicode NFC normalization, trim, collapsed whitespace, Unicode case-fold comparison, and normalized Uzbek apostrophe variants; punctuation/technical symbols remain significant and fuzzy/AI matching is excluded.
2. Draft assessments may have zero total points, but Homework/Blitz activation requires a backend-recalculated `total_possible_points > 0`.
3. If highest Homework scores tie exactly, the lowest `attempt_number` is the official attempt reference.
4. Closing an active Homework or Blitz auto-finalizes every existing in-progress attempt with reason `task_closed_auto_finalize`; unanswered components receive zero and no fake Attempts are created for Students who never started.
5. Administrator-created accounts require first-login password change and normal application access is blocked until the change succeeds.
6. Result closure requires a terminal Student+Topic state and remains independent from visibility/release.

### Second-Audit Homework Deadline Decision — Resolved

The final post-audit deadline rule is approved: an `in_progress` Homework Attempt is auto-finalized at the authoritative Homework deadline using saved answers. Unanswered components receive zero, answered automatic components are checked normally, answered manual-review components remain pending Teacher review, Students who never started receive no fabricated Attempt, and unused remaining Homework attempts become unavailable. The backend records `homework_deadline_auto_submit` and rejects later answer/submission mutations after finalization. No Homework-deadline behavior remains open.

### MVP Rule Success Criteria

The business rules are successfully implemented when:

1. Every institution’s data remains isolated.
2. Every user stays within the correct role and relationship scope.
3. Teachers can manage learning only for assigned groups.
4. Students can access and complete only assigned tasks.
5. Parents can view only connected children.
6. Topics connect materials, homework, blitz, and results correctly.
7. Task and submission statuses do not conflict.
8. Automatic and manual checking produce one official score per required task.
9. The system waits when manual checking is unfinished.
10. Missing required work never creates an invented final score.
11. The homework–blitz difference is calculated correctly.
12. The correct average-or-blitz formula is applied.
13. The final result records its calculation method and rule snapshot.
14. **Not completed** is used only for missing required work, not for waiting review or hidden results.
15. Calculated results can remain unreleased without becoming incomplete.
16. Historical records remain stable after deactivation, closure, or archiving.
17. Unauthorized direct links, filters, and record identifiers remain blocked.
18. The complete rules are understandable enough to convert into architecture, database constraints, API contracts, tests, and precise Codex tasks.

The main business-rule principle is:

> **TestLabUz must measure topic understanding through a controlled comparison of home performance and in-class blitz performance while preserving fairness, role boundaries, institution privacy, and clear result meaning.**